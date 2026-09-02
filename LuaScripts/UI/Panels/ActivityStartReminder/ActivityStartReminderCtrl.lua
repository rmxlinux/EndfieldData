local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityStartReminder
ActivityStartReminderCtrl = HL.Class('ActivityStartReminderCtrl', uiCtrl.UICtrl)


ActivityStartReminderCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnExternalRefresh',
    [MessageConst.ON_SYSTEM_UNLOCK_CHANGED] = '_OnExternalRefresh',
    [MessageConst.ON_ACTIVITY_NEW_DAY] = '_OnExternalRefresh',
    
    
    [MessageConst.ON_UNREAD_ACTIVITY_PUSH] = '_OnExternalRefresh',
    [MessageConst.ON_IN_MAIN_HUD_CHANGED] = '_OnExternalRefresh',
    
    [MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_BEGIN] = '_OnBlackScreenBegin',
    [MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_END] = '_OnExternalRefresh',
    
    [MessageConst.ACTIVITY_DEBUG_SHOW_BUBBLE] = '_OnDebugForceShowBubble',
    [MessageConst.ON_SCREEN_SIZE_CHANGED] = '_OnScreenSizeChanged',
    
    [MessageConst.ON_UI_PANEL_CLOSED] = '_OnUIPanelClosed',
}

ActivityStartReminderCtrl.s_activityBubbleScrollTextMaxUtf8Len = HL.StaticField(HL.Number) << 21
ActivityStartReminderCtrl.s_activityBubbleScrollMaxWidth = HL.StaticField(HL.Number) << 360

ActivityStartReminderCtrl.s_bubbleDisappearTime = HL.StaticField(HL.Number) << 8
ActivityStartReminderCtrl.s_bubbleScrollPreWaitTime = HL.StaticField(HL.Number) << 2
ActivityStartReminderCtrl.s_bubbleScrollPostWaitTime = HL.StaticField(HL.Number) << 1

ActivityStartReminderCtrl.s_posSyncMaxFrames = HL.StaticField(HL.Number) << 300
ActivityStartReminderCtrl.s_posStableThreshold = HL.StaticField(HL.Number) << 5
ActivityStartReminderCtrl.s_posStableSqrEpsilon = HL.StaticField(HL.Number) << 0.01
ActivityStartReminderCtrl.s_pendingInitCheckInterval = HL.StaticField(HL.Number) << 0.5


ActivityStartReminderCtrl.s_legacyMigrationDone = HL.StaticField(HL.Boolean) << false
ActivityStartReminderCtrl.s_legacyMigrationFlagKey = HL.StaticField(HL.String) << "activity_push_legacy_bubble_migrated_v1"

ActivityStartReminderCtrl.s_legacyBubbleClientDataKeyPrefix = HL.StaticField(HL.String) << "new_activity_bubble_key_"

ActivityStartReminderCtrl.m_activityBubbleIndex = HL.Field(HL.Number) << -1
ActivityStartReminderCtrl.m_showingActivityId = HL.Field(HL.String) << ""
ActivityStartReminderCtrl.m_showingPushId = HL.Field(HL.String) << ""

ActivityStartReminderCtrl.m_pendingRefreshTimerId = HL.Field(HL.Number) << -1

ActivityStartReminderCtrl.m_nextActivationTimerId = HL.Field(HL.Number) << -1

ActivityStartReminderCtrl.m_pendingInitTimerId = HL.Field(HL.Number) << -1

ActivityStartReminderCtrl.m_debugBubbleSeq = HL.Field(HL.Number) << -1

ActivityStartReminderCtrl.m_posSyncCoroutine = HL.Field(HL.Thread)
ActivityStartReminderCtrl.m_dismissCoroutine = HL.Field(HL.Thread)
ActivityStartReminderCtrl.m_visibilityWatcherCoroutine = HL.Field(HL.Thread)

ActivityStartReminderCtrl.m_layoutElementCache = HL.Field(HL.Userdata)


ActivityStartReminderCtrl.m_animationWrapperCache = HL.Field(CS.Beyond.UI.UIAnimationWrapper)


ActivityStartReminderCtrl.m_bubbleShowToken = HL.Field(HL.Number) << 0



ActivityStartReminderCtrl.m_optimisticReadPushIds = HL.Field(HL.Table)




ActivityStartReminderCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.activityStartReminderNode.gameObject:SetActive(false)
    self:_OnExternalRefresh()
end

ActivityStartReminderCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if self.m_activityBubbleIndex ~= -1 then
        return
    end
    
    self:_OnExternalRefresh()
end

ActivityStartReminderCtrl.OnClose = HL.Override() << function(self)
    self.m_pendingRefreshTimerId = self:_ClearTimer(self.m_pendingRefreshTimerId)
    self.m_nextActivationTimerId = self:_ClearTimer(self.m_nextActivationTimerId)
    self:_StopPendingInitTimer()
    self:_StopPosSyncCoroutine()
    self:_StopDismissCoroutine()
    self:_StopVisibilityWatcherCoroutine()
end






ActivityStartReminderCtrl._CanProcessBubbleRefresh = HL.Method().Return(HL.Boolean) << function(self)
    if not GameWorld.worldInfo.inMainHud then
        return false
    end
    if not UIManager:IsShow(PANEL_ID) then
        return false
    end
    if IsNull(self.view.gameObject) then
        return false
    end
    return true
end

ActivityStartReminderCtrl._IsBubbleCoroutineValid = HL.Method(HL.Number).Return(HL.Boolean) << function(self, bubbleIndex)
    if IsNull(self.view.gameObject) then return false end
    return self.m_activityBubbleIndex == bubbleIndex
end


ActivityStartReminderCtrl._GetMainHudActivityBtn = HL.Method().Return(HL.Any) << function(self)
    local isOpen, mainHudCtrl = UIManager:IsOpen(PanelId.MainHud)
    if not isOpen or not mainHudCtrl then return nil end
    local btn = mainHudCtrl.view.topRightBtns and mainHudCtrl.view.topRightBtns.activityBtn
    if not btn or IsNull(btn) or IsNull(btn.gameObject) then return nil end
    return btn
end



ActivityStartReminderCtrl._IsMainHudActivityBtnVisible = HL.Method().Return(HL.Boolean) << function(self)
    local btn = self:_GetMainHudActivityBtn()
    if not btn then return false end
    if not btn.gameObject.activeInHierarchy then return false end
    local s = btn.transform.lossyScale
    return s.x >= 0.001 and s.y >= 0.001
end


ActivityStartReminderCtrl._ExtractPushIDFromArgs = HL.Method(HL.Opt(HL.Any)).Return(HL.Opt(HL.String)) << function(self, args)
    if not args then return nil end
    local pushID
    if type(args) == "table" then
        pushID = args[1]
    elseif type(args) == "string" then
        pushID = args
    end
    if not pushID or string.isEmpty(pushID) then return nil end
    return pushID
end


ActivityStartReminderCtrl._GetBubblePushData = HL.Method(HL.String).Return(HL.Opt(HL.Any)) << function(self, pushID)
    if not Tables.activityPushBubbleTable then return nil end
    local has, pushData = Tables.activityPushBubbleTable:TryGetValue(pushID)
    if not has or not pushData then return nil end
    if pushData.pushType ~= "Bubble" then return nil end
    return pushData
end






ActivityStartReminderCtrl._StopPosSyncCoroutine = HL.Method() << function(self)
    if self.m_posSyncCoroutine then
        self.m_posSyncCoroutine = self:_ClearCoroutine(self.m_posSyncCoroutine)
    end
end

ActivityStartReminderCtrl._StopDismissCoroutine = HL.Method() << function(self)
    if self.m_dismissCoroutine then
        self.m_dismissCoroutine = self:_ClearCoroutine(self.m_dismissCoroutine)
    end
end

ActivityStartReminderCtrl._StopVisibilityWatcherCoroutine = HL.Method() << function(self)
    if self.m_visibilityWatcherCoroutine then
        self.m_visibilityWatcherCoroutine = self:_ClearCoroutine(self.m_visibilityWatcherCoroutine)
    end
end

ActivityStartReminderCtrl._StopPendingInitTimer = HL.Method() << function(self)
    if self.m_pendingInitTimerId > 0 then
        self.m_pendingInitTimerId = self:_ClearTimer(self.m_pendingInitTimerId)
    end
end







ActivityStartReminderCtrl._SyncPositionToActivityBtn = HL.Method() << function(self)
    local isOpen, mainHudCtrl = UIManager:IsOpen(PanelId.MainHud)
    if not isOpen or not mainHudCtrl then
        return
    end
    local refNode = mainHudCtrl.view.topRightBtns and mainHudCtrl.view.topRightBtns.activityStartReminderNodePos
    if not refNode or IsNull(refNode) then
       return
    end
    local node = self.view.activityStartReminderNodePos
    if IsNull(node) then
       return
    end

    node.position = refNode.position

    self:_StopPosSyncCoroutine()
    self.m_posSyncCoroutine = self:_StartCoroutine(function()
        local frameCount = 0
        local stableCount = 0
        local maxFrames = ActivityStartReminderCtrl.s_posSyncMaxFrames
        local stableThreshold = ActivityStartReminderCtrl.s_posStableThreshold
        local sqrEpsilon = ActivityStartReminderCtrl.s_posStableSqrEpsilon
        local lastPos = refNode.position

        while frameCount < maxFrames do
            coroutine.step()
            frameCount = frameCount + 1
            if IsNull(self.view.gameObject) or IsNull(node) then
                break
            end
            local stillOpen, hud = UIManager:IsOpen(PanelId.MainHud)
            if not stillOpen or not hud then
                break
            end
            local stillRef = hud.view.topRightBtns and hud.view.topRightBtns.activityStartReminderNodePos
            if not stillRef or IsNull(stillRef) then
                break
            end
            local curPos = stillRef.position
            node.position = curPos

            local diff = curPos - lastPos
            if diff.sqrMagnitude < sqrEpsilon then
                stableCount = stableCount + 1
                if stableCount >= stableThreshold then
                    break
                end
            else
                stableCount = 0
            end
            lastPos = curPos
        end
        self.m_posSyncCoroutine = nil
    end)
end






ActivityStartReminderCtrl._GetActivityBubbleAnimationWrapper = HL.Method().Return(CS.Beyond.UI.UIAnimationWrapper) << function(self)
    if self.m_animationWrapperCache and not IsNull(self.m_animationWrapperCache) then
        return self.m_animationWrapperCache
    end
    local node = self.view.activityStartReminderNode
    if not node or IsNull(node.gameObject) then
        return nil
    end
    self.m_animationWrapperCache = node.gameObject:GetComponent(typeof(CS.Beyond.UI.UIAnimationWrapper))
    return self.m_animationWrapperCache
end

ActivityStartReminderCtrl._ApplyBubbleVisual = HL.Method(HL.String, HL.String) << function(self, bubbleType, bubbleText)
    self:_SyncPositionToActivityBtn()
    local node = self.view.activityStartReminderNode
    local wasActive = node.gameObject.activeSelf
    node.gameObject:SetActive(true)
    self.m_bubbleShowToken = self.m_bubbleShowToken + 1
    
    if wasActive then
        local wrapper = self:_GetActivityBubbleAnimationWrapper()
        if wrapper and not IsNull(wrapper) and wrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
            wrapper:ClearTween(false)
            wrapper:PlayInAnimation()
        end
    end
    if not string.isEmpty(bubbleType) then
        self.view.activityStartReminderNodeStateController:SetState(bubbleType)
    end
    self.view.activityStartReminderNode.reminderContentTxt.text = bubbleText
end


ActivityStartReminderCtrl._HideBubbleNodeWithOutAnimation = HL.Method() << function(self)
    local node = self.view.activityStartReminderNode
    if IsNull(node) or IsNull(node.gameObject) then
        return
    end
    if not node.gameObject.activeSelf then
        return
    end
    local wrapper = self:_GetActivityBubbleAnimationWrapper()
    if not wrapper or IsNull(wrapper) then
        self:_SafeDeactivateBubbleNode()
        return
    end
    local token = self.m_bubbleShowToken
    wrapper:PlayOutAnimation(function()
        if IsNull(node) or IsNull(node.gameObject) then
            return
        end
        if self.m_bubbleShowToken ~= token then
            return
        end
        self:_SafeDeactivateBubbleNode()
    end)
end


ActivityStartReminderCtrl._SafeDeactivateBubbleNode = HL.Method() << function(self)
    local node = self.view.activityStartReminderNode
    if IsNull(node) then
        return
    end
    if not node.gameObject.activeSelf then
        return
    end
    local anim = self:_GetActivityBubbleAnimationWrapper()
    if not IsNull(anim) and anim.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
        return
    end
    node.gameObject:SetActive(false)
end

ActivityStartReminderCtrl._DismissBubbleAndMarkRead = HL.Method(HL.Opt(HL.Any)) << function(self, markReadIds)
    self:_StopDismissCoroutine()
    self:_StopVisibilityWatcherCoroutine()
    self.m_activityBubbleIndex = -1
    if markReadIds and #markReadIds > 0 then
        GameInstance.player.activitySystem:MarkActivityPushReadBatch(markReadIds)
    end
    self:_ResetActivityBubbleScrollText()
    self:_HideBubbleNodeWithOutAnimation()
    self.m_showingActivityId = ""
    self.m_showingPushId = ""
end






ActivityStartReminderCtrl._GetActivityBubbleLayoutElement = HL.Method().Return(HL.Userdata) << function(self)
    if self.m_layoutElementCache and not IsNull(self.m_layoutElementCache) then
        return self.m_layoutElementCache
    end
    local node = self.view.activityStartReminderNode
    if not node or not node.reminderContentTxt or IsNull(node.reminderContentTxt.gameObject) then
        return nil
    end
    self.m_layoutElementCache = node.reminderContentTxt.gameObject:GetComponent("LayoutElement")
    return self.m_layoutElementCache
end

ActivityStartReminderCtrl._EnsureHorizontalLayoutGroupChildControlWidth = HL.Method() << function(self)
    local node = self.view.activityStartReminderNode
    local horizontalLayoutGroup = node.horizontalLayoutGroup or node.gameObject:GetComponent("HorizontalLayoutGroup")
    if not horizontalLayoutGroup then
        return
    end
    if not horizontalLayoutGroup.childControlWidth then
        horizontalLayoutGroup.childControlWidth = true
    end
end

ActivityStartReminderCtrl._ResetActivityBubbleScrollText = HL.Method() << function(self)
    local scrollText = self.view.activityStartReminderNode.reminderContentTxtScrollText
    if not scrollText then
        return
    end
    scrollText.enabled = false
end

ActivityStartReminderCtrl._MeasureScrollNeed = HL.Method(HL.Any, HL.Any, HL.Any, HL.Boolean, HL.Number).Return(HL.Boolean, HL.Number) << function(self, node, scrollText, layoutElement, useStaticWidth, maxWidth)
    if layoutElement and not IsNull(layoutElement) then
        layoutElement.preferredWidth = useStaticWidth and -1 or maxWidth
    end
    if not IsNull(node.gameObject) and node.transform then
        CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(node.transform)
    end
    scrollText.enabled = true
    scrollText:ResetTextScroll()
    local scrollDuration = scrollText:GetSingleScrollDuration()
    scrollText.enabled = false
    return scrollDuration > 0, scrollDuration
end

ActivityStartReminderCtrl._PrepareActivityBubbleText = HL.Method(HL.String).Return(HL.Boolean, HL.Number) << function(self, bubbleText)
    local node = self.view.activityStartReminderNode
    node.reminderContentTxt.text = bubbleText
    local scrollText = node.reminderContentTxtScrollText
    local layoutElement = self:_GetActivityBubbleLayoutElement()

    self:_EnsureHorizontalLayoutGroupChildControlWidth()

    if not scrollText or string.isEmpty(bubbleText) then
        self:_ResetActivityBubbleScrollText()
        return false, 0
    end

    local utf8Len = string.utf8len(bubbleText)
    local useStaticWidth = utf8Len <= ActivityStartReminderCtrl.s_activityBubbleScrollTextMaxUtf8Len
    local maxWidth = ActivityStartReminderCtrl.s_activityBubbleScrollMaxWidth

    local needScroll, scrollDuration = self:_MeasureScrollNeed(node, scrollText, layoutElement, useStaticWidth, maxWidth)

    
    if useStaticWidth and needScroll then
        needScroll, scrollDuration = self:_MeasureScrollNeed(node, scrollText, layoutElement, false, maxWidth)
    end

    if not needScroll then
        self:_ResetActivityBubbleScrollText()
    end
    return needScroll, scrollDuration
end

ActivityStartReminderCtrl._PlayActivityBubbleScrollText = HL.Method().Return(HL.Number) << function(self)
    local node = self.view.activityStartReminderNode
    local scrollText = node.reminderContentTxtScrollText
    if not scrollText then
        return 0
    end
    if not IsNull(node.gameObject) and node.transform then
        CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(node.transform)
    end
    scrollText.enabled = true
    scrollText:ResetTextScroll()
    return scrollText:GetSingleScrollDuration()
end

ActivityStartReminderCtrl._StopActivityBubbleScrollAtCurrentPos = HL.Method() << function(self)
    local scrollText = self.view.activityStartReminderNode.reminderContentTxtScrollText
    if not scrollText then
        return
    end
    scrollText.enabled = false
end






ActivityStartReminderCtrl._StartActivityBubbleDismissCoroutine = HL.Method(HL.Number, HL.String, HL.Opt(HL.Any)) << function(self, bubbleIndex, bubbleText, markReadIds)
    local needScroll, scrollDuration = self:_PrepareActivityBubbleText(bubbleText)
    local disappearTime = ActivityStartReminderCtrl.s_bubbleDisappearTime
    local showToken = self.m_bubbleShowToken

    self:_StopDismissCoroutine()
    self.m_dismissCoroutine = self:_StartCoroutine(function()
        if needScroll then
            coroutine.wait(ActivityStartReminderCtrl.s_bubbleScrollPreWaitTime)
            if self.m_activityBubbleIndex ~= bubbleIndex or self.m_bubbleShowToken ~= showToken then
                self.m_dismissCoroutine = nil
                return
            end
            scrollDuration = self:_PlayActivityBubbleScrollText()
            if scrollDuration > 0 then
                coroutine.wait(scrollDuration)
            end
            if self.m_activityBubbleIndex ~= bubbleIndex or self.m_bubbleShowToken ~= showToken then
                self.m_dismissCoroutine = nil
                return
            end
            self:_StopActivityBubbleScrollAtCurrentPos()
            coroutine.wait(ActivityStartReminderCtrl.s_bubbleScrollPostWaitTime)
        else
            coroutine.wait(disappearTime)
        end
        if self.m_activityBubbleIndex == bubbleIndex and self.m_bubbleShowToken == showToken then
            if markReadIds and #markReadIds > 0 then
                GameInstance.player.activitySystem:MarkActivityPushReadBatch(markReadIds)
            end
            self:_ResetActivityBubbleScrollText()
            self:_HideBubbleNodeWithOutAnimation()
            self.m_showingActivityId = ""
            self.m_showingPushId = ""
            self.m_activityBubbleIndex = -1
        end
        self.m_dismissCoroutine = nil
    end)
end


ActivityStartReminderCtrl._StartActivityBtnVisibilityWatcher = HL.Method(HL.Number, HL.Opt(HL.Any)) << function(self, bubbleIndex, markReadIds)
    local showToken = self.m_bubbleShowToken
    self:_StopVisibilityWatcherCoroutine()
    self.m_visibilityWatcherCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            if self.m_activityBubbleIndex ~= bubbleIndex or self.m_bubbleShowToken ~= showToken then
                break
            end
            if IsNull(self.view.gameObject) then
                break
            end
            if not self:_IsMainHudActivityBtnVisible() then
                if markReadIds and #markReadIds > 0 then
                    GameInstance.player.activitySystem:MarkActivityPushReadBatch(markReadIds)
                end
                self:_ResetActivityBubbleScrollText()
                self:_HideBubbleNodeWithOutAnimation()
                self.m_showingActivityId = ""
                self.m_showingPushId = ""
                break
            end
        end
        self.m_visibilityWatcherCoroutine = nil
    end)
end


ActivityStartReminderCtrl._StartPendingInitTimer = HL.Method() << function(self)
    self:_StopPendingInitTimer()
    self.m_pendingInitTimerId = self:_StartTimer(ActivityStartReminderCtrl.s_pendingInitCheckInterval, function()
        self.m_pendingInitTimerId = -1
        self:_CheckPendingInit()
    end)
end

ActivityStartReminderCtrl._CheckPendingInit = HL.Method() << function(self)
    if IsNull(self.view.gameObject) then
        return
    end
    
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Activity) then
        return
    end
    if self:_IsMainHudActivityBtnVisible() then
        self:_InitActivityBubbles()
        return
    end
    self:_StartPendingInitTimer()
end








ActivityStartReminderCtrl._FormatBubbleText = HL.Method(HL.Any, HL.Any, HL.String).Return(HL.String) << function(self, pushData, activity, bubbleText)
    if string.isEmpty(bubbleText) then
        return bubbleText or ""
    end
    if not string.find(bubbleText, "%s", 1, true) then
        return bubbleText
    end
    local endTime = ActivityUtils.getServerPushActivityEndTime(pushData, activity)
    if not endTime or endTime <= 0 then
        if pushData and pushData.isWeeklyRefresh then
            endTime = Utils.getNextWeeklyServerRefreshTime()
        else
            endTime = (activity and activity.endTime) or 0
        end
    end
    local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    local leftSec = (endTime > 0) and (endTime - curTs) or 0
    if leftSec < 0 then
        leftSec = 0
    end
    local leftTimeStr = UIUtils.getLeftTime(leftSec)
    local ok, formatted = pcall(string.format, bubbleText, leftTimeStr)
    if ok then
        return formatted
    end
    return bubbleText
end


ActivityStartReminderCtrl._CollectBatchReadIds = HL.Method(HL.Any, HL.Any).Return(HL.Any) << function(self, currentPush, candidates)
    local result = {}
    table.insert(result, currentPush.pushID)
    for _, c in ipairs(candidates) do
        if c.pushID ~= currentPush.pushID
            and c.activityId == currentPush.activityId
            and c.activationOrder > currentPush.activationOrder
            and not self:_IsPushReadOptimistic(c.pushID)
        then
            table.insert(result, c.pushID)
        end
    end
    return result
end


ActivityStartReminderCtrl._IsPushReadOptimistic = HL.Method(HL.String).Return(HL.Boolean) << function(self, pushID)
    if self.m_optimisticReadPushIds and self.m_optimisticReadPushIds[pushID] then
        return true
    end
    return GameInstance.player.activitySystem:IsActivityPushRead(pushID)
end



ActivityStartReminderCtrl._EvaluateSinglePush = HL.Method(HL.Any, HL.Any, HL.Number, HL.Number).Return(HL.Any, HL.Any) << function(self, pushData, activity, curTs, curWeekday)
    local realEndTime = ActivityUtils.getServerPushActivityEndTime(pushData, activity)
    if realEndTime and curTs >= realEndTime then
        return nil, nil
    end
    if activity.isCompleted then
        return nil, nil
    end
    if activity.placeAtBottom then
        return nil, nil
    end

    if pushData.isWeeklyRefresh then
        if curWeekday < (pushData.pushInWeekday or 0) then
            return nil, nil
        end
        if not ActivityUtils.isTabPushConditionSatisfied(pushData.pushID) then
            return nil, nil
        end
    else
        local offsetHours = ActivityUtils.getServerPushOffsetHours(pushData)
        local activationTime = (activity.startTime or 0) + offsetHours * Const.SEC_PER_HOUR
        if curTs < activationTime then
            return nil, activationTime
        end
        if not ActivityUtils.isTabPushConditionSatisfied(pushData.pushID) then
            return nil, nil
        end
    end

    local activationOrder = pushData.bubbleSortId or 0
    local _, activityData = Tables.activityTable:TryGetValue(pushData.activityId)
    local activitySortId = (activityData and activityData.sortId) or 0
    local candidate = {
        pushID = pushData.pushID,
        activityId = pushData.activityId,
        bubbleType = pushData.bubbleType,
        bubbleText = self:_FormatBubbleText(pushData, activity, pushData.bubbleText),
        activitySortId = activitySortId,
        bubbleSortId = pushData.bubbleSortId or 0,
        activationOrder = activationOrder,
    }
    return candidate, nil
end








ActivityStartReminderCtrl._TryMigrateLegacyBubbleReads = HL.Method() << function(self)
    if ActivityStartReminderCtrl.s_legacyMigrationDone then
        return
    end
    if ClientDataManagerInst:GetBool(ActivityStartReminderCtrl.s_legacyMigrationFlagKey, false) then
        ActivityStartReminderCtrl.s_legacyMigrationDone = true
        return
    end
    if not Tables.activityPushBubbleTable then
        return
    end

    local activitySystem = GameInstance.player.activitySystem
    if not activitySystem then
        return
    end
    local keyPrefix = ActivityStartReminderCtrl.s_legacyBubbleClientDataKeyPrefix

    local activityRealIdToLegacyRead = {}
    local toReportPushIds = {}
    for _, pushData in pairs(Tables.activityPushBubbleTable) do
        if pushData.pushType ~= "Bubble" or string.isEmpty(pushData.activityId) then
            goto continue
        end
        local realId = ActivityUtils.getResetableActivityRealId(pushData.activityId)
        local cached = activityRealIdToLegacyRead[realId]
        if cached == nil then
            cached = ClientDataManagerInst:GetBool(keyPrefix .. realId, false)
            activityRealIdToLegacyRead[realId] = cached
        end
        if cached and not activitySystem:IsActivityPushRead(pushData.pushID) then
            table.insert(toReportPushIds, pushData.pushID)
        end
        ::continue::
    end

    if #toReportPushIds > 0 then
        activitySystem:MarkActivityPushReadBatch(toReportPushIds)
        
        if not self.m_optimisticReadPushIds then
            self.m_optimisticReadPushIds = {}
        end
        for _, pushID in ipairs(toReportPushIds) do
            self.m_optimisticReadPushIds[pushID] = true
        end
    end

    ClientDataManagerInst:SetBool(ActivityStartReminderCtrl.s_legacyMigrationFlagKey, true, false, ClientDataManagerInst.defaultCategory) 
    ActivityStartReminderCtrl.s_legacyMigrationDone = true
end







ActivityStartReminderCtrl._CollectBubbleCandidates = HL.Method(HL.Number, HL.Number).Return(HL.Table, HL.Opt(HL.Number)) << function(self, curTs, curWeekday)
    local activitySystem = GameInstance.player.activitySystem
    local allCandidates = {}
    local nextActivationTs = nil

    for _, pushData in pairs(Tables.activityPushBubbleTable) do
        if pushData.pushType ~= "Bubble" then goto continue end
        local activity = activitySystem:GetActivity(pushData.activityId)
        if not activity then
            goto continue
        end
        if not activity.isUnlocked then
            goto continue
        end

        local candidate, pendingActivationTime = self:_EvaluateSinglePush(pushData, activity, curTs, curWeekday)
        if candidate then
            table.insert(allCandidates, candidate)
        elseif pendingActivationTime and (not nextActivationTs or pendingActivationTime < nextActivationTs) then
            nextActivationTs = pendingActivationTime
        end
        ::continue::
    end

    return allCandidates, nextActivationTs
end



ActivityStartReminderCtrl._DeduplicateAndSortCandidates = HL.Method(HL.Table).Return(HL.Table) << function(self, allCandidates)
    local bestByGroup = {}
    for _, c in ipairs(allCandidates) do
        local key = c.activityId
        local cur = bestByGroup[key]
        if not cur or c.activationOrder < cur.activationOrder then
            bestByGroup[key] = c
        end
    end

    local candidates = {}
    for _, c in pairs(bestByGroup) do
        table.insert(candidates, c)
    end

    table.sort(candidates, function(a, b)
        if a.activitySortId ~= b.activitySortId then
            return a.activitySortId > b.activitySortId
        end
        if a.bubbleSortId ~= b.bubbleSortId then
            return a.bubbleSortId < b.bubbleSortId
        end
        return a.pushID < b.pushID
    end)

    return candidates
end


ActivityStartReminderCtrl._ScheduleNextActivationTimer = HL.Method(HL.Number, HL.Number) << function(self, nextActivationTs, curTs)
    local delay = nextActivationTs - curTs
    if delay > 0 then
        self.m_nextActivationTimerId = self:_StartTimer(delay, function()
            self.m_nextActivationTimerId = -1
            if IsNull(self.view.gameObject) then
                return
            end
            self:_OnExternalRefresh()
        end)
    end
end


ActivityStartReminderCtrl._TryShowDebugBubble = HL.Method(HL.Table).Return(HL.Boolean) << function(self, candidates)
    if not BEYOND_DEBUG_COMMAND then
        return false
    end
    local debugActivityId = ActivityUtils.getDebugActivityBubbleId()
    if string.isEmpty(debugActivityId) then
        return false
    end
    local debugCandidate = nil
    for _, c in ipairs(candidates) do
        if c.activityId == debugActivityId then
            debugCandidate = c
            break
        end
    end
    if not debugCandidate then
        return false
    end
    self.m_activityBubbleIndex = -1
    self.m_showingActivityId = debugCandidate.activityId or ""
    self.m_showingPushId = debugCandidate.pushID or ""
    self:_ApplyBubbleVisual(debugCandidate.bubbleType, debugCandidate.bubbleText)
    self:_StartActivityBubbleDismissCoroutine(-1, debugCandidate.bubbleText, nil)
    return true
end


ActivityStartReminderCtrl._TryShowFirstUnreadCandidate = HL.Method(HL.Table, HL.Table) << function(self, candidates, allCandidates)
    for index = 1, #candidates do
        local c = candidates[index]
        local isRead = self:_IsPushReadOptimistic(c.pushID)
        local textEmpty = string.isEmpty(c.bubbleText)
        if not isRead and not textEmpty then
            self.m_activityBubbleIndex = index
            self.m_showingActivityId = c.activityId or ""
            self.m_showingPushId = c.pushID or ""
            local markReadIds = self:_CollectBatchReadIds(c, allCandidates)
            self:_ApplyBubbleVisual(c.bubbleType, c.bubbleText)
            self:_StartActivityBubbleDismissCoroutine(index, c.bubbleText, markReadIds)
            self:_StartActivityBtnVisibilityWatcher(index, markReadIds)
            return
        end
    end
    self:_ResetActivityBubbleScrollText()
    self:_HideBubbleNodeWithOutAnimation()
end

ActivityStartReminderCtrl._InitActivityBubbles = HL.Method() << function(self)
    self.m_showingActivityId = ""
    self.m_showingPushId = ""
    self.m_nextActivationTimerId = self:_ClearTimer(self.m_nextActivationTimerId)

    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Activity) then
        self:_StopPendingInitTimer()
        return
    end
    if not GameWorld.worldInfo.inMainHud then
        return
    end
    if NarrativeUtils.inBlackScreen then
        return
    end
    if not self:_IsMainHudActivityBtnVisible() then
        self:_StartPendingInitTimer()
        return
    end
    if not Tables.activityPushBubbleTable then
        return
    end
    self:_StopPendingInitTimer()
    self:_TryMigrateLegacyBubbleReads()

    local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    local curWeekday = Utils.getServerWeekdayISOAt4AM()

    local allCandidates, nextActivationTs = self:_CollectBubbleCandidates(curTs, curWeekday)

    if nextActivationTs then
        self:_ScheduleNextActivationTimer(nextActivationTs, curTs)
    end

    local candidates = self:_DeduplicateAndSortCandidates(allCandidates)

    if self:_TryShowDebugBubble(candidates) then
        return
    end

    self:_TryShowFirstUnreadCandidate(candidates, allCandidates)
end






ActivityStartReminderCtrl._OnExternalRefresh = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if not self:_CanProcessBubbleRefresh() then
        return
    end
    
    if self.m_activityBubbleIndex ~= -1 then
        local showingPushRead = not string.isEmpty(self.m_showingPushId) and self:_IsPushReadOptimistic(self.m_showingPushId)
        if not string.isEmpty(self.m_showingPushId) and not showingPushRead then
            self:_SyncPositionToActivityBtn()
            return
        end
        if not IsNull(self.view.activityStartReminderNode)
            and self.view.activityStartReminderNode.gameObject.activeSelf then
            self:_SyncPositionToActivityBtn()
        end
        self.m_activityBubbleIndex = -1
        self.m_pendingRefreshTimerId = self:_ClearTimer(self.m_pendingRefreshTimerId)
        self:_SafeDeactivateBubbleNode()
        self:_InitActivityBubbles()
        return
    end
    
    if self.m_pendingInitTimerId > 0 then
        self:_StopPendingInitTimer()
        self:_CheckPendingInit()
        return
    end
    if self.m_pendingRefreshTimerId and self.m_pendingRefreshTimerId > 0 then
        return
    end
    
    self.m_pendingRefreshTimerId = self:_StartTimer(0, function()
        self.m_pendingRefreshTimerId = -1
        if not self:_CanProcessBubbleRefresh() then
            return
        end
        self:_InitActivityBubbles()
    end)
end


ActivityStartReminderCtrl._OnBlackScreenBegin = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:_HideBubbleNodeWithOutAnimation()
end


ActivityStartReminderCtrl._OnDebugForceShowBubble = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if not BEYOND_DEBUG_COMMAND then
        return
    end
    local pushID = self:_ExtractPushIDFromArgs(args)
    if not pushID then
        return
    end
    if IsNull(self.view.gameObject) then
        return
    end
    local pushData = self:_GetBubblePushData(pushID)
    if not pushData then
        return
    end
    if not self:_IsMainHudActivityBtnVisible() then
        return
    end
    if self.m_activityBubbleIndex ~= -1 then
        return
    end

    local activity = GameInstance.player.activitySystem:GetActivity(pushData.activityId)
    local bubbleText = self:_FormatBubbleText(pushData, activity, pushData.bubbleText)

    
    self.m_pendingRefreshTimerId = self:_ClearTimer(self.m_pendingRefreshTimerId)
    self.m_debugBubbleSeq = self.m_debugBubbleSeq - 1
    local seq = self.m_debugBubbleSeq
    self.m_activityBubbleIndex = seq
    self.m_showingActivityId = pushData.activityId or ""
    self.m_showingPushId = pushData.pushID or ""

    self:_ApplyBubbleVisual(pushData.bubbleType, bubbleText)
    self:_StartActivityBubbleDismissCoroutine(seq, bubbleText, nil)
    self:_StartActivityBtnVisibilityWatcher(seq, nil)
end

ActivityStartReminderCtrl._OnScreenSizeChanged = HL.Method() << function(self)
    if IsNull(self.view.activityStartReminderNode) then
        return
    end
    if not self.view.activityStartReminderNode.gameObject.activeSelf then
        return
    end
    self:_SyncPositionToActivityBtn()
end

ActivityStartReminderCtrl._OnUIPanelClosed = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if not self:_CanProcessBubbleRefresh() then
        return
    end
    if self.m_activityBubbleIndex == -1 then
        return
    end
    if IsNull(self.view.activityStartReminderNode) then
        return
    end
    if not self.view.activityStartReminderNode.gameObject.activeSelf then
        return
    end
    self:_SyncPositionToActivityBtn()
end






ActivityStartReminderCtrl.GetShowingActivityId = HL.Method().Return(HL.String) << function(self)
    return self.m_showingActivityId or ""
end



HL.Commit(ActivityStartReminderCtrl)
