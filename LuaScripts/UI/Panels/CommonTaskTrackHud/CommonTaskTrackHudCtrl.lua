
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonTaskTrackHud

local Phase = {
    Normal = 1, 
    Fail = 2, 
    CompleteMainGoal = 3, 
    CompleteAllGoal = 4, 
}

local Category2CommonTaskQueueKey = {
    ["world_energy_point_small"] = "ForceClearTrackHud",
    ["world_energy_point"] = "ForceClearTrackHud",
}

local CONTENT_SCROLL_FADE_ANIM = "commontasktrackhud_contentscrollfade"
local CONTENT_REFRESH_ANIM = "commontasktrackhud_contentrefresh"
local TITLE_SCROLL_FADE_ANIM = "commontasktrackhud_titlescrollfade"
local TITLE_FINISH_ANIM = "titlefinish_in"
local TITLE_FAIL_ANIM = "titlefail_in"

local CONTENT_ARROW_IN = "commontasktrackhud_arrowbottom_in"
local CONTENT_ARROW_OUT = "commontasktrackhud_arrowbottom_out"

local BTN_FOLD_ANIM_FOLD = "tasktrackhud_btnfold_fold"
local BTN_FOLD_ANIM_UNFOLD = "tasktrackhud_btnfold_unfold"

local STAGE_TEXT_FORMAT = "%d/%d"













































































CommonTaskTrackHudCtrl = HL.Class('CommonTaskTrackHudCtrl', uiCtrl.UICtrl)



CommonTaskTrackHudCtrl.m_mainGoalCellCache = HL.Field(HL.Forward("UIListCache"))


CommonTaskTrackHudCtrl.m_extraGoalCellCache = HL.Field(HL.Forward("UIListCache"))


CommonTaskTrackHudCtrl.m_curPhase = HL.Field(HL.Number) << Phase.Normal


CommonTaskTrackHudCtrl.m_subGameId = HL.Field(HL.String) << ""


CommonTaskTrackHudCtrl.m_subGameData = HL.Field(CS.Beyond.Gameplay.Core.SubGameInstanceData)


CommonTaskTrackHudCtrl.m_isShowCustomTask = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.m_originalAnchoredPos = HL.Field(Vector2)


CommonTaskTrackHudCtrl.m_quitBtnVisible = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.m_resetBtnVisible = HL.Field(HL.Boolean) << false




CommonTaskTrackHudCtrl.m_contentShowingFinish = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.m_contentShowingCor = HL.Field(HL.Thread)


CommonTaskTrackHudCtrl.m_subGameStateChangeCor = HL.Field(HL.Thread)


CommonTaskTrackHudCtrl.m_contentShowing = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.taskGoalShowing = HL.Field(HL.Boolean) << false






CommonTaskTrackHudCtrl.m_canScrollContent = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.m_showArrow = HL.Field(HL.Boolean) << true


CommonTaskTrackHudCtrl.m_canFold = HL.Field(HL.Boolean) << false


CommonTaskTrackHudCtrl.m_isFold = HL.Field(HL.Boolean) << true


CommonTaskTrackHudCtrl.m_scrollState = HL.Field(HL.Number) << -1


CommonTaskTrackHudCtrl.m_rectFoldHeight = HL.Field(HL.Number) << 0


CommonTaskTrackHudCtrl.m_rectUnfoldHeight = HL.Field(HL.Number) << 0


CommonTaskTrackHudCtrl.m_tween = HL.Field(HL.Any)




CommonTaskTrackHudCtrl.m_canFoldThresholdOffsetY = HL.Field(HL.Number) << -1








CommonTaskTrackHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_SUB_GAME_FINISH_STATE_CHANGE] = "OnSubGameFinishStateChange", 
    [MessageConst.ON_SUB_GAME_STAGE_CHANGE] = "OnSubGameStageChange", 
    [MessageConst.ON_SCRIPT_TASK_CHANGE] = "OnTrackingTaskChange", 

    [MessageConst.ON_SUB_GAME_RESET] = "OnSubGameReset",

    [MessageConst.ON_HUD_BTN_VISIBLE_CHANGE] = "OnHudBtnVisibleChange",
}







CommonTaskTrackHudCtrl.OnOpenSubGameTrackings = HL.StaticMethod(HL.Any) << function(args)
    local doAction = function()
        
        local trackHudCtrl = UIManager:AutoOpen(PanelId.CommonTaskTrackHud)
        trackHudCtrl:InitSubGameTrack(args)
        trackHudCtrl:OnSubGameFinishStateChange(args)
        trackHudCtrl:PlayAnimationIn()

        local opened, missionHudCtrl = UIManager:IsOpen(PanelId.MissionHud)
        if not opened then
            return
        end

        if UIManager:IsShow(PanelId.MissionHud) and not missionHudCtrl:IsPlayingAnimationOut() then
            missionHudCtrl:PlayAnimationOutAndClose()
        else
            missionHudCtrl:Close()
        end
    end

    local interruptAction = function()
        UIManager:Close(PanelId.MissionHud)
    end

    local subGameId = unpack(args)
    local gameMechanicData = Tables.gameMechanicTable[subGameId]
    local queueKey = Category2CommonTaskQueueKey[gameMechanicData.gameCategory]
    if string.isEmpty(queueKey) then
        LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHud", doAction, interruptAction)
    else
        LuaSystemManager.commonTaskTrackSystem:AddRequest(queueKey, doAction, interruptAction)
    end
end



CommonTaskTrackHudCtrl.OnCloseSubGameTrack = HL.StaticMethod(HL.Table) << function(args)
    local isReset = unpack(args)
    local action = function()
        
        local trackOpened, trackHudCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
        if trackOpened then
            trackHudCtrl:StopSubGameTrack(isReset)
        else
            
            Notify(MessageConst.ON_DEACTIVATE_COMMON_TASK_TRACK_HUD, { isReset })
        end
    end
    if isReset then
        action()
    else
        LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHud", function()
            action()
        end)
    end
end


CommonTaskTrackHudCtrl.OnOpenLevelScriptCustomTask = HL.StaticMethod() << function()
    local doAction = function()
        
        local trackHudCtrl = UIManager:AutoOpen(PanelId.CommonTaskTrackHud)
        trackHudCtrl:InitCustomTaskTrack()
        trackHudCtrl:OnSubGameFinishStateChange({"", Phase.Normal})
        trackHudCtrl:PlayAnimationIn()

        local opened, missionHudCtrl = UIManager:IsOpen(PanelId.MissionHud)
        if not opened then
            return
        end

        if UIManager:IsShow(PanelId.MissionHud) and not missionHudCtrl:IsPlayingAnimationOut() then
            missionHudCtrl:PlayAnimationOutAndClose()
        else
            missionHudCtrl:Close()
        end
    end

    local interruptAction = function()
        UIManager:Close(PanelId.MissionHud)
    end

    
    if GameInstance.mode.modeType == GEnums.GameModeType.WorldChallenge then
        local gameMechanicData = Tables.gameMechanicTable[GameWorld.worldInfo.curSubGameId]
        if gameMechanicData.gameCategory == "world_energy_point_small" then
            LuaSystemManager.commonTaskTrackSystem:AddRequest("ForceClearTrackHud", doAction, interruptAction)
        end
    else
        LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHud", doAction, interruptAction)
    end
end


CommonTaskTrackHudCtrl.OnCloseLevelScriptCustomTask = HL.StaticMethod() << function()
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHud", function()
        local trackOpened, trackHudCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
        if trackOpened then
            trackHudCtrl:StopCustomTaskTrack()
        end
    end)
end



CommonTaskTrackHudCtrl.OnDeactivateCommonTaskTrackHud = HL.StaticMethod(HL.Table) << function(args)
    local ignoreCloseAnim = unpack(args)
    local opened, commonTaskTrackCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
    if opened then
        if UIManager:IsShow(PanelId.CommonTaskTrackHud) and not ignoreCloseAnim then
            commonTaskTrackCtrl:PlayAnimationOutAndClose()
        else
            commonTaskTrackCtrl:Close()
        end
    end

    if Utils.needMissionHud() then
        local ctrl = UIManager:AutoOpen(PanelId.MissionHud)
        ctrl:PlayAnimationIn()
    end
end







CommonTaskTrackHudCtrl.InitSubGameTrack = HL.Method(HL.Any) << function(self, args)
    local subGameId = unpack(args)
    if not self:_LoadSubGameData(subGameId) then
        return
    end

    self.m_subGameId = subGameId
    self.m_isShowCustomTask = false
    self.m_contentShowingFinish = false

    if DeviceInfo.usingTouch then
        local succ, gameMechanicData = Tables.gameMechanicTable:TryGetValue(subGameId)
        if succ and string.find(gameMechanicData.gameCategory, "dungeon") then
            
            self.m_isFold = false
        end
    end

    self:RefreshAll()
end




CommonTaskTrackHudCtrl.StopSubGameTrack = HL.Method(HL.Boolean) << function(self, isReset)
    self.m_subGameId = ""
    self.m_subGameData = nil
    if self.m_isShowCustomTask then
        self:RefreshAll()
    else
        Notify(MessageConst.ON_DEACTIVATE_COMMON_TASK_TRACK_HUD, { isReset })
    end
end



CommonTaskTrackHudCtrl.InitCustomTaskTrack = HL.Method() << function(self)
    self.m_isShowCustomTask = true
    self.m_contentShowingFinish = false
    self:RefreshAll()
end



CommonTaskTrackHudCtrl.StopCustomTaskTrack = HL.Method() << function(self)
    self.m_isShowCustomTask = false
    if self.m_subGameId ~= "" then
        self:RefreshAll()
    else
        Notify(MessageConst.ON_DEACTIVATE_COMMON_TASK_TRACK_HUD, { true })
    end
end





CommonTaskTrackHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)

    self.m_mainGoalCellCache = UIUtils.genCellCache(self.view.mainGoalCell)
    self.m_extraGoalCellCache = UIUtils.genCellCache(self.view.extraGoalCell)
    self.m_originalAnchoredPos = self.view.main.anchoredPosition

    self.view.btnReset.onClick:AddListener(function()
        self:_OnBtnResetClick()
    end)

    self.view.btnStop.onClick:AddListener(function()
        self:_OnBtnStopClick()
    end)

    if DeviceInfo.usingTouch then
        self.view.contentScrollView.onValueChanged:AddListener(function(normalizedPosition)
            self:_OnScrollValueChanged(normalizedPosition)
        end)

        self.view.contentScrollView.OnScrollStart:AddListener(function(normalizedPosition)
            self:_OnScrollStateChanged(true)
        end)

        self.view.contentScrollView.OnScrollEnd:AddListener(function(normalizedPosition)
            self:_OnScrollStateChanged(false)
        end)

        self.view.btnFold.onClick:AddListener(function()
            self:_OnBtnFoldClick()
        end)
    end
end



CommonTaskTrackHudCtrl.OnClose = HL.Override() << function(self)
    if self.m_contentShowingCor then
        self.m_contentShowingCor = self:_ClearCoroutine(self.m_contentShowingCor)
    end
    self.m_contentShowingFinish = true

    if self.m_subGameStateChangeCor then
        self.m_subGameStateChangeCor = self:_ClearCoroutine(self.m_subGameStateChangeCor)
    end
    self.m_contentShowing = false
end



CommonTaskTrackHudCtrl.OnShow = HL.Override() << function(self)
    
    self:_AdaptByDevice()
end



CommonTaskTrackHudCtrl.RefreshAll = HL.Method() << function(self)
    if self.m_isShowCustomTask then
        self:_RefreshCustomTaskTrack()
    else
        self:_RefreshSubGameTrack()
    end

    
    
    if self.m_contentShowingCor then
        self.m_contentShowingCor = self:_ClearCoroutine(self.m_contentShowingCor)
    end

    local wrapper = self.animationWrapper
    wrapper:SampleClip(CONTENT_REFRESH_ANIM, 1)
    wrapper:PlayInAnimation()

    self:_AdaptByDevice()
end



CommonTaskTrackHudCtrl._AdaptByDevice = HL.Method() << function(self)
    self:_AdaptWidth()

    local deviceAdapterParams = {
        headNode = self.view.titleNode,
        objectiveContent = self.view.content,
        contentScrollView = self.view.contentScrollView,
        verticalLayoutGroup = self.view.panelVerticalLayoutGroup,
        rectTransform = self.view.panel,
        arrowBottomNode = self.view.arrowBottomNode,
    }

    local ignoreScrollMask, scrollState, rectFoldHeight, rectUnfoldHeight = UIUtils.commonAdaptHudTrackV2(deviceAdapterParams,
                                                                                                      self.view.config,
                                                                                                      self.m_canFoldThresholdOffsetY)
    self.m_scrollState = scrollState
    self.m_rectFoldHeight = rectFoldHeight
    self.m_rectUnfoldHeight = rectUnfoldHeight
    self.m_canFold = scrollState ~= UIConst.TRACK_HUD_SCROLL_STATE.AlwaysCantScroll
    
    if not self.m_canFold then
        self.m_isFold = true
    end

    self.m_canScrollContent = self:_GetCanScrollState()
    self.m_showArrow = self.m_canScrollContent

    local width = self.view.panel.rect.width
    local defaultRectHeight = self.m_isFold and rectFoldHeight or rectUnfoldHeight
    local percent = self.m_isFold and 1 or 0
    self.view.panel.sizeDelta = Vector2(width, defaultRectHeight)
    self.view.btnFoldAnimationWrapper:SampleClip(BTN_FOLD_ANIM_FOLD, percent)

    self.view.contentScrollView:ScrollTo(Vector2(0, 1), true)
    
    
    self.view.scrollViewImage.raycastTarget = self.m_canScrollContent

    self.view.scrollViewRectMask2D.enabled = not ignoreScrollMask

    self.view.btnFold.gameObject:SetActiveIfNecessary(self.m_canFold)

    self:_UpdateScrollContentWightsState(true)
end




CommonTaskTrackHudCtrl._UpdateScrollContentWightsState = HL.Method(HL.Boolean) << function(self, ignoreAnim)
    self.view.scrollbarNode.gameObject:SetActiveIfNecessary(not self.m_isFold and self.m_scrollState == UIConst.TRACK_HUD_SCROLL_STATE.AlwaysCanScroll)
    if ignoreAnim then
        self.view.arrowBottomNode.gameObject:SetActiveIfNecessary(self.m_canScrollContent)
        if self.m_canScrollContent then
            self.view.arrowBottomNode:SampleClip(CONTENT_ARROW_IN, 1)
        else
            self.view.arrowBottomNode:SampleClip(CONTENT_ARROW_OUT, 1)
        end
    else
        if self.m_canScrollContent and not self.view.arrowBottomNode.gameObject.activeInHierarchy then
            self.view.arrowBottomNode.gameObject:SetActiveIfNecessary(true)
            self.view.arrowBottomNode:Play(CONTENT_ARROW_IN)
        elseif not self.m_canScrollContent and self.view.arrowBottomNode.gameObject.activeInHierarchy then
            self.view.arrowBottomNode:Play(CONTENT_ARROW_OUT, function()
                self.view.arrowBottomNode.gameObject:SetActiveIfNecessary(false)
            end)
        end
    end
end



CommonTaskTrackHudCtrl._AdaptWidth = HL.Method() << function(self)
    local rectName = "RectTransform"

    
    
    local mainTitleRect = self.view.titleDefaultTxt:GetComponent(rectName)
    LayoutRebuilder.ForceRebuildLayoutImmediate(mainTitleRect)
    
    local defaultScheduleTextWid = self.view.scheduleNode.gameObject.activeInHierarchy and 116 or 0

    local finishScheduleTextRect = self.view.finishScheduleText:GetComponent(rectName)
    LayoutRebuilder.ForceRebuildLayoutImmediate(finishScheduleTextRect)
    local finishScheduleTextWid = finishScheduleTextRect.rect.width

    local failScheduleTextRect = self.view.failScheduleText:GetComponent(rectName)
    LayoutRebuilder.ForceRebuildLayoutImmediate(failScheduleTextRect)
    local failScheduleTextWid = failScheduleTextRect.rect.width
    local mainTitleWidth = mainTitleRect.anchoredPosition.x + mainTitleRect.rect.width +
            self.view.config.SPACING_BETWEEN_TITLE_SCHEDULE + math.max(defaultScheduleTextWid, finishScheduleTextWid, failScheduleTextWid)

    
    local fitterMode = CS.UnityEngine.UI.ContentSizeFitter.FitMode

    
    
    local failReasonLayoutGroup = self.view.failReasonRoot:GetComponent("HorizontalLayoutGroup")
    if self.view.failReasonRoot.gameObject.activeInHierarchy then
        failReasonLayoutGroup.childControlWidth = true
    end

    
    
    local contentSizeFitter = self.view.content:GetComponent("ContentSizeFitter")
    
    contentSizeFitter.horizontalFit = fitterMode.PreferredSize
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.content)
    local contentWidth = self.view.content.rect.width

    
    local extraGoalTitleWidth = 0
    if self.view.extraGoalRoot.gameObject.activeInHierarchy then
        
        local vlg = self.view.goalRoot:GetComponent("VerticalLayoutGroup")
        
        local rect = self.view.extraGoalTitleText:GetComponent(rectName)
        LayoutRebuilder.ForceRebuildLayoutImmediate(rect)
        extraGoalTitleWidth = vlg.padding.left + rect.anchoredPosition.x + rect.rect.width
    end

    logger.warn(string.format("CommonTaskTrackHud contentWidth:%f, mainTitleWidth:%f,extraGoalTitleWidth:%f",
                              contentWidth, mainTitleWidth, extraGoalTitleWidth))
    local maxWidth = math.max(contentWidth, mainTitleWidth, extraGoalTitleWidth)
    local perfectWidth = lume.clamp(maxWidth, self.view.config.MIN_WIDTH, self.view.config.MAX_WIDTH)

    
    if self.view.failReasonRoot.gameObject.activeInHierarchy then
        failReasonLayoutGroup.childControlWidth = false
        local failReasonRect = self.view.failReason:GetComponent(rectName)
        failReasonRect.sizeDelta = Vector2(perfectWidth - failReasonRect.anchoredPosition.x - 87 ,
                                           failReasonRect.sizeDelta.y)
    end
    contentSizeFitter.horizontalFit = fitterMode.Unconstrained
    local contentHeight = self.view.content.rect.height
    self.view.content.sizeDelta = Vector2(perfectWidth, contentHeight)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.content)

    local height = self.view.panel.rect.height
    self.view.panel.sizeDelta = Vector2(perfectWidth, height)
end



CommonTaskTrackHudCtrl._OnBtnFoldClick = HL.Method() << function(self)
    local config = self.view.config
    if self.m_isFold then
        
        self.view.btnFoldAnimationWrapper:Play(BTN_FOLD_ANIM_UNFOLD)
        self.m_isFold = false

        
        self.m_tween = DOTween.To(function()
            return self.view.panel.sizeDelta
        end, function(value)
            self.view.panel.sizeDelta = value
        end, Vector2(self.view.panel.sizeDelta.x, self.m_rectUnfoldHeight), config.FOLD_TIME):SetEase(config.FOLD_ANIM_CURVE)
    else
        
        self.view.btnFoldAnimationWrapper:Play(BTN_FOLD_ANIM_FOLD)
        self.m_isFold = true

        
        self.m_tween = DOTween.To(function()
            return self.view.panel.sizeDelta
        end, function(value)
            self.view.panel.sizeDelta = value
        end, Vector2(self.view.panel.sizeDelta.x, self.m_rectFoldHeight), config.UNFOLD_TIME):SetEase(config.UNFOLD_ANIM_CURVE)
    end

    
    self.m_canScrollContent = self:_GetCanScrollState()
    self.view.contentScrollView:ScrollTo(Vector2(0, 1), true)
    
    self.view.scrollViewImage.raycastTarget = self.m_canScrollContent

    self.m_tween:OnComplete(function()
        self:_UpdateScrollContentWightsState(false)
    end)
end



CommonTaskTrackHudCtrl._GetCanScrollState = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_scrollState == UIConst.TRACK_HUD_SCROLL_STATE.AlwaysCanScroll and not self.m_isFold
end



CommonTaskTrackHudCtrl._RefreshSubGameTrack = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local mainTask = trackingMgr.mainTask
    local goalCount = mainTask ~= nil and mainTask.objectives.Length or 0
    local extraTask = trackingMgr.extraTask
    local extraGoalCount = extraTask ~= nil and extraTask.objectives.Length or 0

    local hasGoal = goalCount > 0 or extraGoalCount > 0
    self.view.goalRoot.gameObject:SetActive(hasGoal)
    self.view.failReasonRoot.gameObject:SetActive(not hasGoal)

    self.view.mainGoalRoot.gameObject:SetActive(goalCount > 0)
    self.m_mainGoalCellCache:Refresh(goalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Main)
    end)

    self.view.extraGoalRoot.gameObject:SetActive(extraGoalCount > 0)
    self.m_extraGoalCellCache:Refresh(extraGoalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Extra)
    end)

    self.m_quitBtnVisible = self.m_subGameData.canQuit
    self.view.btnStop.gameObject:SetActiveIfNecessary(self.m_subGameData.canQuit)
    self.view.btnStopTxt:SetAndResolveTextStyle(self.m_subGameData.resetBtnName:GetText())

    local success, gameMechanicData = Tables.gameMechanicTable:TryGetValue(self.m_subGameId)
    if success then
        local gameMechanicCategoryData = Tables.gameMechanicCategoryTable[gameMechanicData.gameCategory]
        self.view.btnReset.gameObject:SetActiveIfNecessary(gameMechanicCategoryData.canReChallenge)
        self.m_resetBtnVisible = gameMechanicCategoryData.canReChallenge
    end

    self.view.btnNode.gameObject:SetActiveIfNecessary(self.m_quitBtnVisible or self.m_resetBtnVisible)

    local title
    
    if mainTask ~= nil then
        title = mainTask:GetTaskTitle()
    end
    
    if string.isEmpty(title) then
        title = success and gameMechanicData.gameName
    end
    self:_ProcessTitle(title)
    self:_ProcessTitleIcon()
    self:_UpdateSubGameStage()
end



CommonTaskTrackHudCtrl._RefreshCustomTaskTrack = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local customTask = trackingMgr.customTask
    local goalCount = customTask ~= nil and customTask.objectives.Length or 0

    self.view.goalRoot.gameObject:SetActive(goalCount > 0)
    self.view.failReasonRoot.gameObject:SetActive(false)

    self.view.mainGoalRoot.gameObject:SetActive(goalCount > 0)
    self.m_mainGoalCellCache:Refresh(goalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Custom)
    end)

    self.view.extraGoalRoot.gameObject:SetActive(false)
    self.m_extraGoalCellCache:Refresh(0)

    self.view.btnNode.gameObject:SetActive(false)

    
    if customTask ~= nil then
        local title = customTask:GetTaskTitle()
        self:_ProcessTitle(title)
    end

    self:_UpdateSubGameStage()
end



CommonTaskTrackHudCtrl._RefreshMainTask = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local mainTask = trackingMgr.mainTask
    local goalCount = mainTask ~= nil and mainTask.objectives.Length or 0
    self.view.mainGoalRoot.gameObject:SetActive(goalCount > 0)
    self.m_mainGoalCellCache:Refresh(goalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Main)
    end)
end



CommonTaskTrackHudCtrl._RefreshExtraTask = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local extraTask = trackingMgr.extraTask
    local extraGoalCount = extraTask ~= nil and extraTask.objectives.Length or 0
    self.view.extraGoalRoot.gameObject:SetActive(extraGoalCount > 0)
    self.m_extraGoalCellCache:Refresh(extraGoalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Extra)
    end)
end



CommonTaskTrackHudCtrl._RefreshCustomTask = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local customTask = trackingMgr.customTask
    local goalCount = customTask ~= nil and customTask.objectives.Length or 0
    self.view.goalRoot.gameObject:SetActive(goalCount > 0)
    self.view.failReasonRoot.gameObject:SetActive(false)

    self.view.mainGoalRoot.gameObject:SetActive(goalCount > 0)
    self.m_mainGoalCellCache:Refresh(goalCount, function(cell, index)
        cell:InitCommonTaskGoalCell(index, CS.Beyond.Gameplay.LevelScriptTaskType.Custom)
    end)
end



CommonTaskTrackHudCtrl.OnSubGameStageChange = HL.Method() << function(self)
    self:_ToggleBtnVisible(false)
    self.m_subGameStateChangeCor = self:_StartCoroutine(function()
        while true do
            
            if not self.taskGoalShowing then
                break
            end
            coroutine.step()
        end
        local wrapper = self.animationWrapper
        self.m_contentShowing = true
        local scrollFadeTime = wrapper:GetClipLength(CONTENT_SCROLL_FADE_ANIM)
        wrapper:Play(CONTENT_SCROLL_FADE_ANIM)
        coroutine.wait(scrollFadeTime)

        self.m_contentShowing = false
        self:_UpdateSubGameStage()
        local contentRefreshTime = wrapper:GetClipLength(CONTENT_REFRESH_ANIM)
        wrapper:Play(CONTENT_REFRESH_ANIM)
        coroutine.wait(contentRefreshTime)
        self:_ToggleBtnVisible(true)

        Notify(MessageConst.ON_SUB_GAME_STAGE_CHANGE_FINISH)
    end)
end




CommonTaskTrackHudCtrl.OnTrackingTaskChange = HL.Method(HL.Any) << function(self, args)
    self:_StartCoroutine(function()
        while true do
            
            
            if not self.taskGoalShowing and not self.m_contentShowing then
                break
            end
            coroutine.step()
        end
        local taskType = unpack(args)
        if taskType == CS.Beyond.Gameplay.LevelScriptTaskType.Main then
            self:_RefreshMainTask()
        elseif taskType == CS.Beyond.Gameplay.LevelScriptTaskType.Extra then
            self:_RefreshExtraTask()
        elseif taskType == CS.Beyond.Gameplay.LevelScriptTaskType.Custom then
            self:_RefreshCustomTask()
        end

        self:_AdaptByDevice()
    end)
end




CommonTaskTrackHudCtrl.OnSubGameFinishStateChange = HL.Method(HL.Any) << function(self, args)
    local subGameId, phase = unpack(args)
    if phase == Phase.Normal then
        self:_ToggleTitleState(phase)
    elseif phase == Phase.Fail then
        if self.m_subGameData.modeType ~= GEnums.GameModeType.Blackbox then
            LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHudShowEndEffect", function()
                self:_DoFailContentShowing(phase)
            end, function()
                self:Close()
            end)
        else
            self:_RefreshFailInfo()
            self:_ManuSetFailState()
            self:_ToggleTitleState(phase)
            self.view.titleFail:Play(TITLE_FAIL_ANIM)

            self:_AdaptByDevice()
        end
    else
        if self.m_curPhase ~= Phase.CompleteMainGoal and self.m_curPhase ~= Phase.CompleteAllGoal then
            if self.m_subGameData.modeType ~= GEnums.GameModeType.Blackbox then
                LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackHudShowEndEffect", function()
                    self:_DoSuccContentShowing(phase)
                end, function()
                    self:Close()
                end)
            else
                self:_ToggleTitleState(phase)
                self.view.titleFinish:Play(TITLE_FINISH_ANIM)
            end
        end

    end

    self.m_curPhase = phase
end




CommonTaskTrackHudCtrl._DoFailContentShowing = HL.Method(HL.Number) << function(self, phase)
    self:_ToggleBtnVisible(false)
    self:_ManuSetFailState()
    AudioAdapter.PostEvent("Au_UI_Mission_Step_Fail")
    self.m_contentShowingFinish = false
    self.m_contentShowingCor = self:_StartCoroutine(function()
        while true do
            
            if not self.taskGoalShowing then
                break
            end
            coroutine.step()
        end
        local wrapper = self.animationWrapper
        local contentScrollFadeTime = wrapper:GetClipLength(CONTENT_SCROLL_FADE_ANIM)
        wrapper:Play(CONTENT_SCROLL_FADE_ANIM)
        coroutine.wait(contentScrollFadeTime)

        Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackHudShowEndEffect")
        AudioAdapter.PostEvent("Au_UI_Mission_Fail")
        self:_RefreshFailInfo()
        self:_ToggleTitleState(phase)
        local titleFail = self.view.titleFail
        local titleStateTime = titleFail:GetClipLength(TITLE_FAIL_ANIM)
        titleFail:Play(TITLE_FAIL_ANIM)
        coroutine.wait(titleStateTime)

        local titleScrollFadeTime = wrapper:GetClipLength(TITLE_SCROLL_FADE_ANIM)
        wrapper:Play(TITLE_SCROLL_FADE_ANIM)
        coroutine.wait(titleScrollFadeTime)

        self.m_contentShowingFinish = true
        self:Close()
    end)
end




CommonTaskTrackHudCtrl._DoSuccContentShowing = HL.Method(HL.Number) << function(self, phase)
    self:_ToggleBtnVisible(false)
    self.m_contentShowingFinish = false
    self.m_contentShowingCor = self:_StartCoroutine( function()
        while true do
            
            if not self.taskGoalShowing then
                break
            end
            coroutine.step()
        end

        local wrapper = self.animationWrapper
        local contentScrollFadeTime = wrapper:GetClipLength(CONTENT_SCROLL_FADE_ANIM)
        wrapper:Play(CONTENT_SCROLL_FADE_ANIM)
        coroutine.wait(contentScrollFadeTime)

        Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackHudShowEndEffect")
        AudioAdapter.PostEvent("Au_UI_Mission_Complete")
        self:_ToggleTitleState(phase)
        local titleFinish = self.view.titleFinish
        local titleStateTime = titleFinish:GetClipLength(TITLE_FINISH_ANIM)
        titleFinish:Play(TITLE_FINISH_ANIM)
        coroutine.wait(titleStateTime)

        local titleScrollFadeTime = wrapper:GetClipLength(TITLE_SCROLL_FADE_ANIM)
        wrapper:Play(TITLE_SCROLL_FADE_ANIM)
        coroutine.wait(titleScrollFadeTime)

        self.m_contentShowingFinish = true
        self:Close()
    end)
end



CommonTaskTrackHudCtrl._ManuSetFailState = HL.Method() << function(self)
    
    self.m_mainGoalCellCache:Update(function(goalCell, _)
        goalCell:TrySetStateFail()
    end)

    
    self.m_extraGoalCellCache:Update(function(goalCell, _)
        goalCell:TrySetStateFail()
    end)
end




CommonTaskTrackHudCtrl._ToggleTitleState = HL.Method(HL.Number) << function(self, phase)
    
    if self.m_isClosed then
        return
    end
    self.view.titleDefault.gameObject:SetActive(phase == Phase.Normal)
    self.view.titleFail.gameObject:SetActive(phase == Phase.Fail)
    self.view.titleFinish.gameObject:SetActive(phase == Phase.CompleteMainGoal or phase == Phase.CompleteAllGoal)
end



CommonTaskTrackHudCtrl._UpdateSubGameStage = HL.Method() << function(self)
    local content = ""
    if (not self.m_isShowCustomTask and GameWorld.worldInfo.subGame ~= nil) and
            not self.m_subGameData.hideStageProgress then
        local game = GameWorld.worldInfo.subGame
        local maxStage = game.maxStage
        if maxStage > 1 then
            local stage = game.stage
            content = string.format(STAGE_TEXT_FORMAT, stage, maxStage)
        end
    end
    local hasContent = not string.isEmpty(content)
    self.view.scheduleNode.gameObject:SetActiveIfNecessary(hasContent)
    self.view.scheduleText:SetAndResolveTextStyle(content)
end



CommonTaskTrackHudCtrl._RefreshFailInfo = HL.Method() << function(self)
    local failInfo = self.m_subGameData.failInfo:GetText()
    self.view.goalRoot.gameObject:SetActive(false)
    self.view.failReasonRoot.gameObject:SetActive(true)
    self.view.failReason:SetAndResolveTextStyle(failInfo)
end




CommonTaskTrackHudCtrl._ProcessTitle = HL.Method(HL.String) << function(self, title)
    self.view.titleDefaultTxt:SetAndResolveTextStyle(title)
    self.view.titleFailTxt:SetAndResolveTextStyle(title)
    self.view.titleFinishTxt:SetAndResolveTextStyle(title)
end



CommonTaskTrackHudCtrl._ProcessTitleIcon = HL.Method() << function(self)
    local success, gameTblData = Tables.gameMechanicTable:TryGetValue(self.m_subGameId)
    local gameTypeData = success and Tables.gameMechanicCategoryTable[gameTblData.gameCategory] or {}

    local iconName = gameTypeData.icon
    local iconBgName = gameTypeData.iconBg

    if not string.isEmpty(iconName) then
        self.view.defaultIcon:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconName)
        self.view.finishIcon:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconName)
        self.view.failIcon:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconName)
    end

    local hasIconBgName = not string.isEmpty(iconBgName)
    self.view.defaultIconBg.gameObject:SetActiveIfNecessary(hasIconBgName)
    self.view.finishIconBg.gameObject:SetActiveIfNecessary(hasIconBgName)
    self.view.failIconBg.gameObject:SetActiveIfNecessary(hasIconBgName)
    if hasIconBgName then
        self.view.defaultIconBg:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconBgName)
        self.view.finishIconBg:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconBgName)
        self.view.failIconBg:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, iconBgName)
    end
end



CommonTaskTrackHudCtrl._OnBtnResetClick = HL.Method() << function(self)
    if self.m_subGameData.modeType == GEnums.GameModeType.Dungeon then
        local gameMechanicCfg = Tables.gameMechanicTable[self.m_subGameId]
        local dungeonTypeCfg = Tables.dungeonTypeTable[gameMechanicCfg.gameCategory]
        self:_ShowConfirmPopup(dungeonTypeCfg.resetConfirmText, function()
            GameWorld.worldInfo.subGame:SendReStart()
        end)
    elseif self.m_subGameData.modeType == GEnums.GameModeType.WorldChallenge then
        logger.error("world challenge cannot reset")
    end
end



CommonTaskTrackHudCtrl._OnBtnStopClick = HL.Method() << function(self)
    if self.m_subGameData.modeType == GEnums.GameModeType.Dungeon then
        logger.error("dungeon cannot click stop btn")
    elseif self.m_subGameData.modeType == GEnums.GameModeType.WorldChallenge then
        self:_ShowConfirmPopup(Language.LUA_COMMON_TASK_TRACK_STOP_WORLD_CHALLENGE, function()
            GameWorld.worldInfo.subGame:SendQuit()
        end)
    end

end




CommonTaskTrackHudCtrl._OnScrollValueChanged = HL.Method(Vector2) << function(self, normalizedPosition)
    if not self.m_canScrollContent then
        return
    end

    local bottom = normalizedPosition.y < 0
    if bottom and self.m_showArrow then
        self.m_showArrow = false
        self.view.arrowBottomNode:Play(CONTENT_ARROW_OUT, function()
            self.view.arrowBottomNode.gameObject:SetActiveIfNecessary(false)
        end)
    elseif not bottom and not self.m_showArrow then
        self.m_showArrow = true
        self.view.arrowBottomNode.gameObject:SetActiveIfNecessary(true)
        self.view.arrowBottomNode:Play(CONTENT_ARROW_IN)
    end
end




CommonTaskTrackHudCtrl._OnScrollStateChanged = HL.Method(HL.Boolean) << function(self, isStartScroll)
    self.view.maskImg.gameObject:SetActiveIfNecessary(isStartScroll)
end





CommonTaskTrackHudCtrl._ShowConfirmPopup = HL.Method(HL.String, HL.Function) << function(self, content, confirmFunc)
    if not string.isEmpty(GameInstance.player.systemActionConflictManager.curProcessingSystemAction) then
        logger.warn("CommonTaskTrackHudCtrl._ShowConfirmPopup systemConflict:", GameInstance.player.systemActionConflictManager:GetCurProcessingSystemActionInfo(), "SubGameId:", self.m_subGameId)
        return
    end

    self:Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        onConfirm = function()
            confirmFunc()
        end,
        freezeWorld = true,
        pauseGame = true,
        interrupt = {
            interruptMessage = { MessageConst.ON_SUB_GAME_QUIT, MessageConst.SHOW_DEATH_INFO },
        }
    })
end




CommonTaskTrackHudCtrl._LoadSubGameData = HL.Method(HL.Any).Return(HL.Boolean) << function(self, instId)
    local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(instId)
    if success then
        self.m_subGameData = subGameData
    end

    return success
end




CommonTaskTrackHudCtrl._ToggleBtnVisible = HL.Method(HL.Boolean) << function(self, isOn)
    self.view.btnReset.gameObject:SetActiveIfNecessary(isOn and self.m_resetBtnVisible)
    self.view.btnStop.gameObject:SetActiveIfNecessary(isOn and self.m_quitBtnVisible)
end




CommonTaskTrackHudCtrl.OnHudBtnVisibleChange = HL.Method(HL.Any) << function(self, arg)
    local isOn = unpack(arg)
    self:_ToggleBtnVisible(isOn)
end



CommonTaskTrackHudCtrl.OnSubGameReset = HL.Method() << function(self)
    self.m_subGameId = ""
    self.m_subGameData = nil

    self:_ToggleBtnVisible(false)
    self:ToggleResetBtnLoopHint(false)
end










CommonTaskTrackHudCtrl.AddPositionOffset = HL.Method(Vector2, HL.Boolean) << function(self, offset, needMobileAdapter)
    if offset == nil then
        return
    end
    local anchoredPosition = self.view.main.anchoredPosition
    self.view.main.anchoredPosition = anchoredPosition + offset

    self.m_canFoldThresholdOffsetY = needMobileAdapter and offset.y or 0
end



CommonTaskTrackHudCtrl.ClearPositionOffset = HL.Method() << function(self)
    self.view.main.anchoredPosition = self.m_originalAnchoredPos
end



CommonTaskTrackHudCtrl.GetContentBottomFollowNode = HL.Method().Return(RectTransform) << function(self)
    return self.view.bottomFollowNode
end



CommonTaskTrackHudCtrl.GetContentTopFollowNode = HL.Method().Return(RectTransform) << function(self)
    return self.view.topFollowNode
end



CommonTaskTrackHudCtrl.GetResetBtnRect = HL.Method().Return(RectTransform) << function(self)
    
    return self.view.btnResetPosition
end



CommonTaskTrackHudCtrl.HideBottomNode = HL.Method() << function(self)
    self.view.btnNode.gameObject:SetActiveIfNecessary(false)

    self:_AdaptByDevice()
end





CommonTaskTrackHudCtrl.GetResetBtnFollowerRect = HL.Method().Return(RectTransform) << function(self)
    
    return self.view.btnResetFollower
end




CommonTaskTrackHudCtrl.ToggleResetBtnLoopHint = HL.Method(HL.Boolean) << function(self, isOn)
    if self.view.resetBtnLoopHint then
        self.view.resetBtnLoopHint.gameObject:SetActive(isOn)
    end
end

HL.Commit(CommonTaskTrackHudCtrl)
