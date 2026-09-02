
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityCenter
local PHASE_ID = PhaseId.ActivityCenter


local GROUP_TIMED = "timed"
local GROUP_REGULAR = "regular"
local GROUP_KEYS = { GROUP_TIMED, GROUP_REGULAR }

local GROUP_VIEW_KEY = {
    [GROUP_TIMED] = "groupTimed",
    [GROUP_REGULAR] = "groupRegular",
}


local DEFAULT_TAB_NORMAL_STATE = "normal"
local DEFAULT_TAB_SELECTED_STATE = "selected"

local TAB_END_NORMAL_STATE = "NrlHint"
local TAB_END_SELECTED_STATE = "SelHint"


ActivityCenterCtrl = HL.Class('ActivityCenterCtrl', uiCtrl.UICtrl)





ActivityCenterCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdated',
    [MessageConst.ON_ACTIVITY_NEW_DAY] = '_OnActivityNewDay',
    [MessageConst.ON_ACTIVITY_NAVI_FAILED] = 'OnActivityNaviFailed',
    [MessageConst.ON_ACTIVITY_CENTER_BACK_TO_TOP] = '_OnBackToTop',
    [MessageConst.ON_UNREAD_ACTIVITY_PUSH] = '_OnServerUnreadActivityPush',
}

ActivityCenterCtrl.s_debugDelay = HL.StaticField(HL.Number) << -1

ActivityCenterCtrl.m_selectedPanel = HL.Field(HL.Any)

ActivityCenterCtrl.m_fromDialog = HL.Field(HL.Boolean) << false


ActivityCenterCtrl.m_groupActivities = HL.Field(HL.Table)


ActivityCenterCtrl.m_groupActivityDict = HL.Field(HL.Table)


ActivityCenterCtrl.m_groupTabCells = HL.Field(HL.Any)


ActivityCenterCtrl.m_groupCells = HL.Field(HL.Any)


ActivityCenterCtrl.m_groupSelectedIndex = HL.Field(HL.Table)


ActivityCenterCtrl.m_expandedGroup = HL.Field(HL.String) << ""

ActivityCenterCtrl.m_activityId = HL.Field(HL.String) << ""

ActivityCenterCtrl.m_initialActivityId = HL.Field(HL.String) << ""

ActivityCenterCtrl.m_enterType = HL.Field(HL.String) << ""


ActivityCenterCtrl.m_optimisticReadPushIds = HL.Field(HL.Table)




ActivityCenterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    
    
    
    self:_InitInfoAndButtons(arg)
    self:_RefreshTabList()
    self:_InitController()
    if not string.isEmpty(self.m_initialActivityId) then
        Canvas.ForceUpdateCanvases() 
    end
    self:GoToActivity(self.m_initialActivityId)
end

ActivityCenterCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshControllerInputState()
end

ActivityCenterCtrl.OnHide = HL.Override() << function(self)
    if self.m_phase then
        self.m_phase:_ClearCoroutine(self.m_phase.m_delayShowActivityCo)
    end
end

ActivityCenterCtrl.OnClose = HL.Override() << function(self)
    
    GameInstance.player.activitySystem:ClearInviteBackCodeCache()
end

ActivityCenterCtrl._InitInfoAndButtons = HL.Method(HL.Table) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self:BindInputPlayerAction("activity_center_f7_close", function()
        self:_Close()
    end)

    
    self.m_groupTabCells = {}
    self.m_groupCells = {}
    self.m_groupSelectedIndex = {}
    self.m_groupActivities = {}
    self.m_groupActivityDict = {}
    for _, group in ipairs(GROUP_KEYS) do
        local groupView = self:_GetGroupView(group)
        self.m_groupTabCells[group] = UIUtils.genCellCache(groupView.tabCell)
        self.m_groupCells[group] = {}
        self.m_groupSelectedIndex[group] = 0
        self.m_groupActivities[group] = {}
        local capturedGroup = group
        groupView.headerBtn.onClick:RemoveAllListeners()
        groupView.headerBtn.onClick:AddListener(function()
            self:_OnHeaderClicked(capturedGroup)
        end)
    end

    self.m_initialActivityId = (arg and arg.gotoCenter) and arg.activityId or ""
    self.m_enterType = arg and arg.openFrom or "SomewhereElse"
end

ActivityCenterCtrl._InitController = HL.Method() << function(self)
    if DeviceInfo.usingController then
        for _, group in ipairs(GROUP_KEYS) do
            local groupView = self:_GetGroupView(group)
            if groupView and not IsNull(groupView.tabScrollRectNaviGroup) then
                groupView.tabScrollRectNaviGroup.onIsTopLayerChanged:RemoveAllListeners()
                
                groupView.tabScrollRectNaviGroup.onIsTopLayerChanged:AddListener(function()
                    self:_RefreshControllerInputState()
                end)
            end
        end
        if self:_GetExpandedActivityCount() > 0 and not self.m_initialActivityId then
            self:_SetNaviTarget(self.m_expandedGroup, 1)
        end
    end
end



ActivityCenterCtrl._RefreshControllerInputState = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    local groupView = self:_GetGroupView(self.m_expandedGroup)
    if not groupView or IsNull(groupView.tabScrollRectNaviGroup) then
        return
    end
    local naviManager = InputManagerInst.controllerNaviManager
    
    if not naviManager:IsLayerInStack(groupView.tabScrollRectNaviGroup) then
        return
    end
    self.view.inputGroup.enabled = groupView.tabScrollRectNaviGroup.IsTopLayer
end

ActivityCenterCtrl.OnActivityNaviFailed = HL.Method(HL.Userdata) << function(self, dir)
    if self.m_expandedGroup == "" then
        return
    end
    local count = #self.m_groupActivities[self.m_expandedGroup]
    if count <= 0 then
        return
    end
    if dir == Unity.UI.NaviDirection.Down then
        self:_SetNaviTarget(self.m_expandedGroup, 1)
    elseif dir == Unity.UI.NaviDirection.Up then
        self:_SetNaviTarget(self.m_expandedGroup, count)
    end
end




ActivityCenterCtrl._GetGroupView = HL.Method(HL.String).Return(HL.Any) << function(self, group)
    local viewKey = GROUP_VIEW_KEY[group]
    return viewKey and self.view[viewKey] or nil
end

ActivityCenterCtrl._GetExpandedActivityCount = HL.Method().Return(HL.Number) << function(self)
    if self.m_expandedGroup == "" then
        return 0
    end
    return #self.m_groupActivities[self.m_expandedGroup]
end

ActivityCenterCtrl._GetTotalActivityCount = HL.Method().Return(HL.Number) << function(self)
    local total = 0
    for _, group in ipairs(GROUP_KEYS) do
        total = total + #self.m_groupActivities[group]
    end
    return total
end



ActivityCenterCtrl._RefreshTabList = HL.Method() << function(self)
    
    local lastActivityId
    if self.m_expandedGroup ~= "" then
        local list = self.m_groupActivities[self.m_expandedGroup]
        local idx = self.m_groupSelectedIndex[self.m_expandedGroup]
        if list and idx and list[idx] then
            lastActivityId = list[idx].id
        end
    end

    
    for _, group in ipairs(GROUP_KEYS) do
        self.m_groupActivities[group] = {}
    end
    self.m_groupActivityDict = {}

    local activities = GameInstance.player.activitySystem:GetAllActivities()
    for _, activity in cs_pairs(activities) do
        local _, activityData = Tables.activityTable:TryGetValue(activity.id)
        if activityData then
            local group = (activity.endTime and activity.endTime > 0 or activityData.isRecommend) and GROUP_TIMED or GROUP_REGULAR
            
            
            
            local tabPush, allActives = self:_PickActiveTabPush(activity.id, activity)
            local normalState, selectedState = self:_ResolveTabCellStateNames(tabPush, activity)
            table.insert(self.m_groupActivities[group], {
                id = activity.id,
                sortId = -activityData.sortId,
                activity = activity,
                activityData = activityData,
                completed = activity:GetCompleteSortId(),
                type = activityData.type,
                status = activity.status,
                
                placeAtBottom = activity.placeAtBottom,
                normalState = normalState,
                selectedState = selectedState,
                tabPush = tabPush, 
                tabPushAllActives = allActives, 
            })
        end
    end

    
    
    
    
    do
        local activitySystem = GameInstance.player.activitySystem
        for _, g in ipairs(GROUP_KEYS) do
            for _, entry in ipairs(self.m_groupActivities[g]) do
                local tabPush = entry.tabPush
                if tabPush
                    and tabPush.tabType == "End"
                    and not string.isEmpty(tabPush.pushID)
                    and not activitySystem:IsActivityPushRead(tabPush.pushID)
                    and ActivityUtils.isActivityEndTabRedDotSeen(tabPush.pushID)
                then
                    ActivityUtils.clearActivityEndTabRedDotSeen(tabPush.pushID)
                end
            end
        end
    end

    
    for _, group in ipairs(GROUP_KEYS) do
        local list = self.m_groupActivities[group]
        table.sort(list, Utils.genSortFunction({"completed","sortId", "id"}, true))
        for index = 1, #list do
            self.m_groupActivityDict[list[index].id] = {
                group = group,
                index = index,
            }
        end
        
        if self.m_groupSelectedIndex[group] > #list then
            self.m_groupSelectedIndex[group] = 0
        end
    end

    
    for _, group in ipairs(GROUP_KEYS) do
        self.m_groupCells[group] = {}
        local capturedGroup = group
        self.m_groupTabCells[group]:Refresh(#self.m_groupActivities[group], function(cell, index)
            self:_OnUpdateCellInGroup(capturedGroup, cell, index)
        end)
        self:_GetGroupView(group).redDot:InitRedDot("ActivityTableMore", self.m_groupActivities[group])
    end

    
    
    for _, group in ipairs(GROUP_KEYS) do
        for _, info in ipairs(self.m_groupActivities[group]) do
            if info.activity.isCompleted then
                if ActivityUtils.isNewActivity(info.id) then
                    ActivityUtils.setFalseNewActivity(info.id)
                end
                if ActivityUtils.isNewUnlockActivity(info.id) then
                    ActivityUtils.setFalseNewUnlockActivity(info.id)
                end
            end
        end
    end

    
    self:_RefreshGroupVisibility()

    if self.m_expandedGroup == "" then
        
        if self:_GetTotalActivityCount() > 0 then
            
            local defaultGroup = (#self.m_groupActivities[GROUP_TIMED] > 0) and GROUP_TIMED or GROUP_REGULAR
            local targetActivityId = not string.isEmpty(self.m_initialActivityId) and self.m_initialActivityId or self.m_groupActivities[defaultGroup][1].id
            ActivityUtils.GameEventLogActivityEnter(self.m_enterType, targetActivityId)
            
            local targetGroup = defaultGroup
            local targetIndex = 1
            if not string.isEmpty(self.m_initialActivityId) and self.m_groupActivityDict[self.m_initialActivityId] then
                targetGroup = self.m_groupActivityDict[self.m_initialActivityId].group
                targetIndex = self.m_groupActivityDict[self.m_initialActivityId].index or 1
            end
            self:_ShowGroup(targetGroup)
            self:_OnTabClicked(targetGroup, targetIndex, true, nil, true)
        end
    else
        
        self:GoToActivity(lastActivityId)
    end
end

ActivityCenterCtrl._OnUpdateCellInGroup = HL.Method(HL.String, HL.Any, HL.Number) << function(self, group, cell, index)
    self.m_groupCells[group][index] = cell
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:_OnTabClicked(group, index, nil, DeviceInfo.usingController)
    end)
    self:_SetTabCellSelected(cell, index == self.m_groupSelectedIndex[group], group, index)
    local entry = self.m_groupActivities[group][index]
    local activityData = entry.activityData

    local nodes = {
        cell.selectNode,
        cell.normalNode,
    }
    for i = 1, #nodes do
        local innerCell = nodes[i]
        innerCell.txtName.text = activityData.name
        if activityData.tabImg ~= "" then
            if activityData.tabImgGender then
                local suffix = Utils.getPlayerGender() == CS.Proto.GENDER.GenMale and "_boy" or "_girl"
                innerCell.tabImg:LoadSprite(UIConst.UI_SPRITE_ACTIVITY,activityData.tabImg .. suffix)
            else
                innerCell.tabImg:LoadSprite(UIConst.UI_SPRITE_ACTIVITY,activityData.tabImg)
            end
        end

        
        if activityData.tabImgColor then
            local suc, color = CS.UnityEngine.ColorUtility.TryParseHtmlString(activityData.tabImgColor)
            if suc then
                innerCell.selectedBg.color = color
                innerCell.decoLine.color = color
                innerCell.decoArrow.color = color
            end
        end

        
        local activity = GameInstance.player.activitySystem:GetActivity(activityData.id)
        innerCell.completedIconNode.gameObject:SetActive(activity.isCompleted or activity.placeAtBottom)
    end

    
    
    
    
    
    self:_RefreshTabPriorityIndicators(group, cell, entry)

    
    
    
    
    self:_RefreshTabEndCountDown(cell, entry)
end

ActivityCenterCtrl._OnTabClicked = HL.Method(HL.String, HL.Number, HL.Opt(HL.Boolean, HL.Boolean, HL.Boolean)) << function(self, group, index, forceRefresh, isFromNavi, isInit)
    
    if self:_GetTotalActivityCount() == 0 then
        ActivityUtils.backToMainHud(true)
        return
    end

    if not self.m_groupActivities[group] or #self.m_groupActivities[group] == 0 then
        return
    end

    
    if not isInit and GameInstance.player.guide.isInForceGuide then
        local isSameTab = (group == self.m_expandedGroup and index == self.m_groupSelectedIndex[group])
        if not isSameTab then
            return
        end
    end

    
    if group ~= self.m_expandedGroup then
        self:_ShowGroup(group)
    end

    
    if self.m_groupSelectedIndex[group] == index and not forceRefresh then
        return
    end

    local lastSelectedCell = self:_GetCell(group, self.m_groupSelectedIndex[group])
    if lastSelectedCell then
        self:_SetTabCellSelected(lastSelectedCell, false, group, self.m_groupSelectedIndex[group])
    end
    self.m_groupSelectedIndex[group] = index
    local selectedCell = self:_GetCell(group, index)
    if selectedCell then
        self:_SetTabCellSelected(selectedCell, true, group, index)
    end    
    if DeviceInfo.usingController then
        self:_SetNaviTarget(group, index)
    end

    
    local entry = self.m_groupActivities[group][index]
    local id = entry.id
    ActivityUtils.GameEventLogActivityVisit(id, "ActivityTabCellButton", "visit_center")

    
    local tabPush = entry and entry.tabPush
    if tabPush
        and tabPush.tabType == "Update"
        and not string.isEmpty(tabPush.pushID)
        and ActivityUtils.isTabPushConditionSatisfied(tabPush.pushID, entry and entry.activity)
        and not GameInstance.player.activitySystem:IsActivityPushRead(tabPush.pushID)
    then
        local clickedCell = self:_GetCell(group, index)
        if clickedCell and clickedCell.normalNode and not IsNull(clickedCell.normalNode.updateNode) then
            self:_MarkPushReadOptimistic(tabPush, entry)
            clickedCell.normalNode.updateNode.gameObject:SetActive(false)
        end
    end

    if entry.activity then
        local bubbleReadIds = self:_CollectActivityUnreadBubblePushIds(id, entry.activity)
        self:_MarkPushIdsReadOptimistic(bubbleReadIds)
    end

    if tabPush
        and tabPush.tabType == "End"
        and not string.isEmpty(tabPush.pushID)
        and ActivityUtils.isTabPushConditionSatisfied(tabPush.pushID, entry and entry.activity)
    then
        if not ActivityUtils.isActivityEndTabRedDotSeen(tabPush.pushID) then
            ActivityUtils.setActivityEndTabRedDotSeen(tabPush.pushID)
        end
        if not GameInstance.player.activitySystem:IsActivityPushRead(tabPush.pushID) then
            self:_MarkPushReadOptimistic(tabPush, entry)
        end
    end

    if ActivityUtils.isNewActivity(id) then
        ActivityUtils.setFalseNewActivity(id)
    end
    if ActivityUtils.isNewUnlockActivity(id) then
        ActivityUtils.setFalseNewUnlockActivity(id)
    end
    if ActivityUtils.isNewActivityBubble(id) and entry.activity.isUnlocked then
        ActivityUtils.setFalseNewActivityBubble(id)
    end
    local pushPopupId = ActivityUtils.getActivityPushPopupId(id)
    if pushPopupId and not GameInstance.player.activitySystem:IsActivityPushRead(pushPopupId) then
        GameInstance.player.activitySystem:MarkActivityPushReadOne(pushPopupId)
    end

    
    local _clickedCell = self:_GetCell(group, index)
    if _clickedCell then
        for _, _innerCell in ipairs({ _clickedCell.selectNode, _clickedCell.normalNode }) do
            if _innerCell and _innerCell.redDot then
                self:_ApplyRedDotPriority(_innerCell.redDot, entry)
            end
        end
    end

    if self.m_activityId == id then
        return
    end

    
    self.m_activityId = id
    local groupView = self:_GetGroupView(group)
    local msg = isFromNavi and MessageConst.SHOW_ACTIVITY_PANEL_FROM_NAVI or MessageConst.SHOW_ACTIVITY_PANEL
    Notify(msg, {
        activityId = id,
        controllerHintPlaceholder = self.view.controllerHintPlaceholder,
        groupId = self.view.inputBindingGroupMonoTarget.groupId,
        naviGroup = groupView.tabScrollRectNaviGroup,
        getReturnTargetFunc = function()
            local info = self.m_groupActivityDict[id]
            if not info then return nil end
            local cell = self:_GetCell(info.group, info.index)
            return cell and cell.button or nil
        end,
        delay = ActivityCenterCtrl.s_debugDelay >= 0 and ActivityCenterCtrl.s_debugDelay or self.view.config.SHOW_ACTIVITY_FROM_NAVI_DELAY,
        isInit = isInit or false,
    })
end

ActivityCenterCtrl._OnHeaderClicked = HL.Method(HL.String) << function(self, group)
    
    if group == self.m_expandedGroup then
        return
    end
    
    if GameInstance.player.guide.isInForceGuide then
        return
    end
    
    if not self.m_groupActivities[group] or #self.m_groupActivities[group] == 0 then
        return
    end
    self:_ShowGroup(group)
    
    self:_OnTabClicked(group, 1, true)
    
    self:_ScrollGroupToCell(group, 1)
end


ActivityCenterCtrl._ScrollGroupToCell = HL.Method(HL.String, HL.Number) << function(self, group, index)
    local groupView = self:_GetGroupView(group)
    if not groupView or IsNull(groupView.tabScrollRectScrollRect) then
        return
    end
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.contentRectTransform)
    local cell = self:_GetCell(group, index)
    if cell and not IsNull(cell.button) then
        
        groupView.tabScrollRectScrollRect:AutoScrollToRectTransform(cell.button.transform, true)
    end
end

ActivityCenterCtrl._ShowGroup = HL.Method(HL.String) << function(self, group)
    self.m_expandedGroup = group
    for _, key in ipairs(GROUP_KEYS) do
        local groupView = self:_GetGroupView(key)
        if groupView then
            local isExpanded = (key == group)
            
            if not IsNull(groupView.tabScrollRect) then
                groupView.tabScrollRect.gameObject:SetActive(isExpanded)
            end
            
            if not IsNull(groupView.layoutElement) then
                groupView.layoutElement.flexibleHeight = isExpanded and 1 or 0
            end
            
            if not IsNull(groupView.headerStateController) then
                groupView.headerStateController:SetState(isExpanded and "Show" or "Hide")
            end
            
            if DeviceInfo.usingController and not isExpanded then
                InputManagerInst.controllerNaviManager:TryRemoveLayer(groupView.tabScrollRectNaviGroup)
            end
        end
    end
    
    if not IsNull(self.view.animationWrapper) then
        self.view.animationWrapper:PlayInAnimation()
    end
    
    self:_RefreshControllerInputState()
end



ActivityCenterCtrl.GoToActivity = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, activityId, forceRefresh)
    if self:_GetTotalActivityCount() == 0 then
        return
    end

    local targetGroup, targetIndex
    if not string.isEmpty(activityId) and self.m_groupActivityDict[activityId] then
        targetGroup = self.m_groupActivityDict[activityId].group
        targetIndex = self.m_groupActivityDict[activityId].index or 1
    else
        
        targetGroup = self.m_expandedGroup
        if targetGroup == "" or #self.m_groupActivities[targetGroup] == 0 then
            targetGroup = (#self.m_groupActivities[GROUP_TIMED] > 0) and GROUP_TIMED or GROUP_REGULAR
        end
        targetIndex = 1
    end

    if DeviceInfo.usingController then
        for _, group in ipairs(GROUP_KEYS) do
            local groupView = self:_GetGroupView(group)
            if groupView then
                InputManagerInst.controllerNaviManager:TryRemoveLayer(groupView.tabScrollRectNaviGroup)
            end
        end
    end

    if targetGroup ~= self.m_expandedGroup then
        self:_ShowGroup(targetGroup)
    end
    self:_OnTabClicked(targetGroup, targetIndex, forceRefresh)
    self:_ScrollGroupToCell(targetGroup, targetIndex)
    self:_SetNaviTarget(targetGroup, targetIndex)
    
    self:_RefreshControllerInputState()
end

ActivityCenterCtrl._GetShowingCellStartEnd = HL.Method().Return(HL.Number,HL.Number) << function(self)
    local group = self.m_expandedGroup
    if group == "" then
        return 1, 0
    end
    local groupView = self:_GetGroupView(group)
    if not groupView then
        return 1, 0
    end
    local templateCell = groupView.tabCell
    local redDotSize = templateCell.selectNode.redDot.rectTransform.rect.height
    local totalCount = #self.m_groupActivities[group]
    if totalCount <= 0 then
        return 1, 0
    end

    local scrollRectHeight = groupView.tabScrollRect.rect.height
    local cellHeight = templateCell.rectTransform.rect.height
    local contentY = -groupView.content.anchoredPosition.y

    local low, high = 1, totalCount
    local start = totalCount
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local cell = self:_GetCell(group, mid)
        if not cell then break end
        local top = contentY - cell.gameObject:GetComponent("RectTransform").anchoredPosition.y - cellHeight / 2 - redDotSize / 2
        local bottom = top + redDotSize

        if bottom > 0 then
            start = mid
            high = mid - 1
        else
            low = mid + 1
        end
    end

    low, high = 1, totalCount
    local final = 1
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local cell = self:_GetCell(group, mid)
        if not cell then break end
        local top = contentY - cell.gameObject:GetComponent("RectTransform").anchoredPosition.y - cellHeight / 2 - redDotSize / 2

        if top < scrollRectHeight then
            final = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return start, final
end

ActivityCenterCtrl._GetCell = HL.Method(HL.String, HL.Number).Return(HL.Any) << function(self, group, index)
    if not self.m_groupTabCells[group] then
        return nil
    end
    local target
    self.m_groupTabCells[group]:Refresh(#self.m_groupActivities[group], function(cell, tabIndex)
        if index == tabIndex then
            target = cell
        end
    end)
    return target
end

ActivityCenterCtrl._SetNaviTarget = HL.Method(HL.String, HL.Number) << function(self, group, index)
    local groupView = self:_GetGroupView(group)
    if not groupView then return end
    local cell = self:_GetCell(group, index)
    if DeviceInfo.usingController and cell and not IsNull(cell.button) then
        if not IsNull(groupView.tabScrollRectScrollRect) then
            groupView.tabScrollRectScrollRect:ScrollToNaviTarget(cell.button)
        end
        self:SetNaviTarget(cell.button)
    end
end

ActivityCenterCtrl._SetTabCellSelected = HL.Method(HL.Table, HL.Boolean, HL.Opt(HL.String, HL.Number)) << function(self, tabCell, isSelected, group, index)
    local normalState = DEFAULT_TAB_NORMAL_STATE
    local selectedState = DEFAULT_TAB_SELECTED_STATE
    if group and index and self.m_groupActivities[group] and self.m_groupActivities[group][index] then
        local entry = self.m_groupActivities[group][index]
        normalState = entry.normalState or DEFAULT_TAB_NORMAL_STATE
        selectedState = entry.selectedState or DEFAULT_TAB_SELECTED_STATE
    end
    tabCell.stateController:SetState(isSelected and selectedState or normalState)
end


ActivityCenterCtrl._MarkPushIdsReadOptimistic = HL.Method(HL.Table) << function(self, pushIds)
    if #pushIds <= 0 then
        return
    end
    if not self.m_optimisticReadPushIds then
        self.m_optimisticReadPushIds = {}
    end
    for _, pushID in ipairs(pushIds) do
        self.m_optimisticReadPushIds[pushID] = true
    end
    GameInstance.player.activitySystem:MarkActivityPushReadBatch(pushIds)
end


ActivityCenterCtrl._MarkPushReadOptimistic = HL.Method(HL.Any, HL.Table) << function(self, tabPush, entry)
    local markReadIds = self:_CollectTabBatchReadIds(tabPush, entry)
    self:_MarkPushIdsReadOptimistic(markReadIds)
end

ActivityCenterCtrl._Close = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end

ActivityCenterCtrl.OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    local activity = GameInstance.player.activitySystem:GetActivity(id)

    
    if not activity then
        ActivityUtils.backToMainHud(true, id)
        return
    end

    
    if not self.m_groupActivityDict[id] then
        self:_RefreshTabList()
        return
    end

    
    local info = self.m_groupActivityDict[id]
    local data = self.m_groupActivities[info.group][info.index]
    if data and (activity.status ~= data.status or activity.placeAtBottom ~= data.placeAtBottom) then
        data.status = activity.status
        data.placeAtBottom = activity.placeAtBottom
        self:_RefreshTabCompleteState(info.group)
        return
    end
end

ActivityCenterCtrl._RefreshTabCompleteState = HL.Method(HL.String) << function(self, group)
    self.m_groupTabCells[group]:Refresh(#self.m_groupActivities[group], function(cell, index)
        local activityData = self.m_groupActivities[group][index].activityData
        local activity = GameInstance.player.activitySystem:GetActivity(activityData.id)
        if activity then
            local showComplete = activity.isCompleted or activity.placeAtBottom
            cell.selectNode.completedIconNode.gameObject:SetActive(showComplete)
            cell.normalNode.completedIconNode.gameObject:SetActive(showComplete)
        end
    end)
end

ActivityCenterCtrl._RefreshGroupVisibility = HL.Method() << function(self)
    local hasTimed = #self.m_groupActivities[GROUP_TIMED] > 0
    local hasRegular = #self.m_groupActivities[GROUP_REGULAR] > 0

    
    self:_GetGroupView(GROUP_TIMED).gameObject:SetActive(hasTimed)
    self:_GetGroupView(GROUP_REGULAR).gameObject:SetActive(hasRegular)

    if not hasTimed and not hasRegular then
        ActivityUtils.backToMainHud(true)
        return
    end

    
    if self.m_expandedGroup ~= "" and #self.m_groupActivities[self.m_expandedGroup] == 0 then
        local fallback = hasTimed and GROUP_TIMED or GROUP_REGULAR
        self:_ShowGroup(fallback)
        self:_OnTabClicked(fallback, 1, true)
    end
end

ActivityCenterCtrl._IsActivityChanged = HL.Method().Return(HL.Boolean) << function(self)
    local newSet = {}
    local activities = GameInstance.player.activitySystem:GetAllActivities()
    for _, activity in cs_pairs(activities) do
        newSet[activity.id] = true
    end
    for key, _ in pairs(newSet) do
        if self.m_groupActivityDict[key] == nil then
            return true
        end
    end
    for key, _ in pairs(self.m_groupActivityDict) do
        if newSet[key] == nil then
            return true
        end
    end
    return false
end

ActivityCenterCtrl.OnPhaseRefresh = HL.Override(HL.Any) << function(self, arg)
    self:GoToActivity(arg and arg.gotoCenter and arg.activityId, true)
end

ActivityCenterCtrl._OnBackToTop = HL.Method() << function(self)
    
    if UIManager:IsInternalHidden(PANEL_ID) then
        return
    end
    self.view.animationWrapper:PlayInAnimation()
    for _, group in ipairs(GROUP_KEYS) do
        for _, cell in pairs(self.m_groupCells[group]) do
            cell.normalNode.animationWrapper:PlayInAnimation()
            cell.selectNode.animationWrapper:PlayInAnimation()
        end
    end
end


ActivityCenterCtrl._OnActivityNewDay = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    local visibleActivityId = self.m_activityId
    self:_RefreshTabList()

    
    local info = self.m_groupActivityDict[visibleActivityId]
    local entry = info and self.m_groupActivities[info.group][info.index]
    if entry and entry.tabPush and entry.tabPush.tabType == "End" then
        self:_OnTabClicked(info.group, info.index, true)
    end
end


ActivityCenterCtrl._OnServerUnreadActivityPush = HL.Method() << function(self)
    self.m_optimisticReadPushIds = {}
    self:_RefreshTabList()
end








ActivityCenterCtrl._GetTabPushActivationOrder = HL.Method(HL.Any, HL.Any).Return(HL.Number) << function(self, pushData, activity)
    return pushData.bubbleSortId or 0
end






ActivityCenterCtrl._CollectActivityUnreadBubblePushIds = HL.Method(HL.String, HL.Any).Return(HL.Table) << function(self, activityId, activity)
    local result = {}
    if not Tables.activityPushBubbleTable or not activity then
        return result
    end
    local activitySystem = GameInstance.player.activitySystem
    
    local optimisticRead = self.m_optimisticReadPushIds
    local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    local curWeekday = Utils.getServerWeekdayISOAt4AM()
    for _, pushData in pairs(Tables.activityPushBubbleTable) do
        if pushData.activityId == activityId
            and pushData.pushType == "Bubble"
            and not string.isEmpty(pushData.pushID)
            and ActivityUtils.isTabPushActivated(pushData, activity, curTs, curWeekday)
            and ActivityUtils.isTabPushConditionSatisfied(pushData.pushID, activity)
            and not activitySystem:IsActivityPushRead(pushData.pushID)
            and not (optimisticRead and optimisticRead[pushData.pushID])
        then
            table.insert(result, pushData.pushID)
        end
    end
    return result
end




ActivityCenterCtrl._GatherActiveTabPushes = HL.Method(HL.String, HL.Any).Return(HL.Any) << function(self, activityId, activity)
    local result = {}
    if not Tables.activityPushBubbleTable or not activity then
        return result
    end
    local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    
    local curWeekday = Utils.getServerWeekdayISOAt4AM()
    for _, pushData in pairs(Tables.activityPushBubbleTable) do
        if pushData.activityId == activityId
            and pushData.pushType == "Tab"
            and ActivityUtils.isTabPushActivated(pushData, activity, curTs, curWeekday)
        then
            table.insert(result, {
                pushData = pushData,
                activationOrder = self:_GetTabPushActivationOrder(pushData, activity),
            })
        end
    end
    return result
end






ActivityCenterCtrl._PickActiveTabPush = HL.Method(HL.String, HL.Any).Return(HL.Opt(HL.Any, HL.Any)) << function(self, activityId, activity)
    if not activity then
        return nil, {}
    end
    local actives = self:_GatherActiveTabPushes(activityId, activity)
    if #actives == 0 then
        return nil, actives
    end
    local best = nil
    for _, c in ipairs(actives) do
        if not best or c.activationOrder < best.activationOrder then
            best = c
        end
    end
    return best and best.pushData or nil, actives
end


ActivityCenterCtrl._ResolveTabCellStateNames = HL.Method(HL.Opt(HL.Any, HL.Any)).Return(HL.String, HL.String) << function(self, tabPush, activity)
    if tabPush and tabPush.tabType == "End" and activity
        and not activity.isCompleted
        and not activity.placeAtBottom
    then
        local endTime = ActivityUtils.getServerPushActivityEndTime(tabPush, activity)
        if not endTime then
            if tabPush.isWeeklyRefresh then
                endTime = Utils.getNextWeeklyServerRefreshTime()
            else
                endTime = activity.endTime or 0
            end
        end
        if endTime and endTime > 0 and endTime > DateTimeUtils.GetCurrentTimestampBySeconds() then
            return TAB_END_NORMAL_STATE, TAB_END_SELECTED_STATE
        end
    end
    return DEFAULT_TAB_NORMAL_STATE, DEFAULT_TAB_SELECTED_STATE
end


ActivityCenterCtrl._RefreshTabUpdateNode = HL.Method(HL.Any, HL.Table) << function(self, cell, entry)
    if IsNull(cell) or not cell.normalNode or IsNull(cell.normalNode.updateNode) then
        return
    end
    local hasNew, hasUpdate = self:_GetTabIndicatorPriority(entry)
    cell.normalNode.updateNode.gameObject:SetActive(hasUpdate and not hasNew)
end


ActivityCenterCtrl._GetTabIndicatorPriority = HL.Method(HL.Table).Return(HL.Boolean, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, entry)
    local activityData = entry and entry.activityData
    if not activityData then
        return false, false, false, false
    end
    return ActivityUtils.getActivityCenterTabState(activityData.id)
end


ActivityCenterCtrl._RefreshTabPriorityIndicators = HL.Method(HL.String, HL.Any, HL.Table) << function(self, group, cell, entry)
    if IsNull(cell) or not entry then
        return
    end
    local activityData = entry.activityData
    local activity = entry.activity
    if not activityData or not activity then
        return
    end
    local groupView = self:_GetGroupView(group)

    local redDotName = ActivityUtils.getActivityRedDotName(activityData.id)
    local nodes = { cell.selectNode, cell.normalNode }
    for _, innerCell in ipairs(nodes) do
        if innerCell and innerCell.redDot then
            if not activity.isCompleted and not activity.placeAtBottom and not string.isEmpty(redDotName) then
                innerCell.redDot:InitRedDot(redDotName, activityData.id, function(rd)
                    self:_ApplyRedDotPriority(rd, entry)
                end, groupView and groupView.redDotScrollRect or nil)
                if groupView and not IsNull(groupView.redDotScrollRect) then
                    groupView.redDotScrollRect.gameObject:SetActive(true)
                end
                self:_ApplyRedDotPriority(innerCell.redDot, entry)
            else
                innerCell.redDot.gameObject:SetActive(false)
            end
        end
    end

    self:_RefreshTabUpdateNode(cell, entry)
end


ActivityCenterCtrl._ApplyRedDotPriority = HL.Method(HL.Any, HL.Table) << function(self, redDot, entry)
    if not redDot or IsNull(redDot.gameObject) then
        return
    end
    local hasNew, hasUpdate, hasNormal, hasEndOnce = self:_GetTabIndicatorPriority(entry)
    local showNew = hasNew
    local showNormal = (not hasNew) and (not hasUpdate) and (hasNormal or hasEndOnce)
    local active = showNew or showNormal

    if redDot.view.content and not IsNull(redDot.view.content.gameObject) then
        redDot.view.content.gameObject:SetActive(active)
    end
    if not active then
        return
    end
    if redDot.view.new and not IsNull(redDot.view.new.gameObject) then
        redDot.view.new.gameObject:SetActiveIfNecessary(showNew)
    end
    if redDot.view.normal and not IsNull(redDot.view.normal.gameObject) then
        redDot.view.normal.gameObject:SetActiveIfNecessary(showNormal)
    end
end





ActivityCenterCtrl._CollectTabBatchReadIds = HL.Method(HL.Any, HL.Table).Return(HL.Any) << function(self, currentTabPush, entry)
    local result = {}
    if not currentTabPush then
        return result
    end
    local activitySystem = GameInstance.player.activitySystem
    
    local optimisticRead = self.m_optimisticReadPushIds
    
    if not (optimisticRead and optimisticRead[currentTabPush.pushID]) then
        table.insert(result, currentTabPush.pushID)
    end
    local actives = entry and entry.tabPushAllActives
    if not actives then
        return result
    end
    local curOrder = self:_GetTabPushActivationOrder(currentTabPush, entry.activity)
    for _, info in ipairs(actives) do
        local p = info.pushData
        if p.pushID ~= currentTabPush.pushID
            and info.activationOrder > curOrder
            and not activitySystem:IsActivityPushRead(p.pushID)
            and not (optimisticRead and optimisticRead[p.pushID])
        then
            table.insert(result, p.pushID)
        end
    end
    return result
end


ActivityCenterCtrl._RefreshTabEndCountDown = HL.Method(HL.Any, HL.Table) << function(self, cell, entry)
    local countDownText = cell and cell.countDownText
    if not countDownText then
        return
    end
    local tabPush = entry and entry.tabPush
    local activity = entry and entry.activity
    local needCountDown = tabPush
        and tabPush.tabType == "End"
        and activity
        and not activity.isCompleted
        
        
        and not activity.placeAtBottom
    if needCountDown then
        
        
        
        
        local endTime = ActivityUtils.getServerPushActivityEndTime(tabPush, activity)
        if not endTime then
            if tabPush.isWeeklyRefresh then
                endTime = Utils.getNextWeeklyServerRefreshTime()
            else
                endTime = activity.endTime or 0
            end
        end

        
        
        
        
        local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        if endTime <= curTime then
            countDownText:StopCountDown()
            countDownText.gameObject:SetActive(false)
            return
        end

        countDownText.gameObject:SetActive(true)
        countDownText:InitCountDownText(endTime, function()
            
            
            if self and self.m_groupActivities then
                self:_RefreshTabList()
            end
        end)
    else
        countDownText:StopCountDown()
        countDownText.gameObject:SetActive(false)
    end
end


HL.Commit(ActivityCenterCtrl)
