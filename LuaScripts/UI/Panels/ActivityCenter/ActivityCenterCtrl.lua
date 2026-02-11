
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityCenter
local PHASE_ID = PhaseId.ActivityCenter


































ActivityCenterCtrl = HL.Class('ActivityCenterCtrl', uiCtrl.UICtrl)






ActivityCenterCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdated',
    [MessageConst.ON_ACTIVITY_NAVI_FAILED] = 'OnActivityNaviFailed',
}


ActivityCenterCtrl.m_selectedPanel = HL.Field(HL.Any)


ActivityCenterCtrl.m_fromDialog = HL.Field(HL.Boolean) << false


ActivityCenterCtrl.m_allActivities = HL.Field(HL.Table)


ActivityCenterCtrl.m_selectedTabIndex = HL.Field(HL.Number) << 0


ActivityCenterCtrl.m_activityDict = HL.Field(HL.Table)


ActivityCenterCtrl.m_tabCells = HL.Field(HL.Any)


ActivityCenterCtrl.m_cells = HL.Field(HL.Any)


ActivityCenterCtrl.m_activityId = HL.Field(HL.String) << ""


ActivityCenterCtrl.m_initialActivityId = HL.Field(HL.String) << ""


ActivityCenterCtrl.m_enterType = HL.Field(HL.String) << ""







ActivityCenterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitInfoAndButtons(arg)
    self:_RefreshTabList()
    self:_InitController()
    self:_Debug()
    self:GoToActivity(self.m_initialActivityId)
    self:_InitDecoArrow()
end



ActivityCenterCtrl._InitDecoArrow = HL.Method() << function(self)
    self:_StartCoroutine(function()
        while true do
            coroutine.step()
            
            local _,final = self:_GetShowingCellStartEnd()
            self.view.decoArrow.gameObject:SetActive(final < #self.m_allActivities)

            
            local moreActivityData = {}
            for i = final + 1, #self.m_allActivities do
                table.insert(moreActivityData, self.m_allActivities[i].activityData)
            end
            self.view.redDotArrow:InitRedDot("ActivityTableMore", moreActivityData)
        end
    end)
end




ActivityCenterCtrl._InitInfoAndButtons = HL.Method(HL.Table) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.doubleF7CloseBtn.onClick:AddListener(function()
        self:_Close()
    end)
    self.m_tabCells = UIUtils.genCellCache(self.view.tabCell)
    self.m_initialActivityId = (arg and arg.gotoCenter) and arg.activityId or ""
    self.m_enterType = arg and arg.openFrom or "SomewhereElse"
end



ActivityCenterCtrl._InitController = HL.Method() << function(self)
    if DeviceInfo.usingController then
        if #self.m_allActivities > 0 and not self.m_initialActivityId then
            self:_SetNaviTarget(1)
        end
    end
end




ActivityCenterCtrl.OnActivityNaviFailed = HL.Method(HL.Userdata) << function(self, dir)
    if dir == Unity.UI.NaviDirection.Down then
        self:_SetNaviTarget(1)
    elseif dir == Unity.UI.NaviDirection.Up then
        self:_SetNaviTarget(#self.m_allActivities)
    end
end



ActivityCenterCtrl._Debug = HL.Method() << function(self)
    if BEYOND_DEBUG_COMMAND then
        
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.Z, function()
            UIManager:Open(PanelId.StaminaPotion,"item_ap_feed_in")
        end, nil, nil, self.view.inputGroup.groupId)
        
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.X, function()
            PhaseManager:OpenPhaseFast(PhaseId.ActivityPopup)
        end, nil, nil, self.view.inputGroup.groupId)
        
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.C, function()
            PhaseManager:OpenPhase(PhaseId.HighDifficultyMainHud,{})
        end, nil, nil, self.view.inputGroup.groupId)

        
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.Y, function()
            UIManager:Open(PanelId.ActivityRewardRegistrationPopup,{})
        end, nil, nil, self.view.inputGroup.groupId)
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.U, function()
            UIManager:Open(PanelId.ActivityCharSignCommonPopUp,{
                activityId = "activity_checkin_agline",
            })
        end, nil, nil, self.view.inputGroup.groupId)
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.I, function()
            UIManager:Open(PanelId.ActivityCharSignCommonPopUp,{
                activityId = "activity_checkin_yvonne",
            })
        end, nil, nil, self.view.inputGroup.groupId)
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.O, function()
            UIManager:Open(PanelId.ActivityCharSignCommonPopUp,{
                activityId = "activity_checkin_laevat",
            })
        end, nil, nil, self.view.inputGroup.groupId)
        UIUtils.bindInputEvent(CS.Beyond.Input.KeyboardKeyCode.P, function()
            UIManager:Open(PanelId.ActivityCharSignCommonPopUp,{
                activityId = "activity_checkin_v1d0_end",
            })
        end, nil, nil, self.view.inputGroup.groupId)
    end
end






ActivityCenterCtrl._RefreshTabList = HL.Method() << function(self)
    
    local lastCount = 0
    local lastActivityId
    if self.m_allActivities then
        lastCount = #self.m_allActivities
        if lastCount > 0 then
            lastActivityId = self.m_allActivities[self.m_selectedTabIndex].id
        end
    end

    
    self.m_allActivities = {}
    local activities = GameInstance.player.activitySystem:GetAllActivities()

    
    for _, activity in cs_pairs(activities) do
        local _, activityData = Tables.activityTable:TryGetValue(activity.id)
        if activityData then
            table.insert(self.m_allActivities, {
                id = activity.id,
                sortId = -activityData.sortId,
                activity = activity,
                activityData = activityData,
                completed = activity.isCompleted and 1 or 0,
                type = activityData.type,
                status = activity.status,
            })
        end
    end
    table.sort(self.m_allActivities, Utils.genSortFunction({"completed","sortId", "id"}, true))

    
    self.m_activityDict = {}
    for index = 1,#self.m_allActivities do
        local activity = self.m_allActivities[index]
        self.m_activityDict[activity.id] = {
            type = activity.type,
            index = index,
        }
    end

    
    self.m_cells = {}
    self.m_tabCells:Refresh(#self.m_allActivities, function(cell, index)
        self:_OnUpdateCell(cell, index)
    end)
    if self.m_selectedTabIndex == 0 then
        
        if #self.m_allActivities > 0 then
            ActivityUtils.GameEventLogActivityEnter(self.m_enterType, not string.isEmpty(self.m_initialActivityId) and self.m_initialActivityId or self.m_allActivities[1].id)
            self:_OnTabClicked(1)
        end
    else
        
        self:GoToActivity(lastActivityId)
    end
end





ActivityCenterCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    self.m_cells[index] = cell
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:_OnTabClicked(index)
    end)
    self:_SetTabCellSelected(cell, index == self.m_selectedTabIndex)
    local activityData = self.m_allActivities[index].activityData

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

        
        local redDotName = ActivityUtils.getActivityRedDotName(activityData.id)
        if not string.isEmpty(redDotName) then
            innerCell.redDot:InitRedDot(redDotName,activityData.id)
        else
            innerCell.redDot.gameObject:SetActive(false)
        end

        
        local activity = GameInstance.player.activitySystem:GetActivity(activityData.id)
        innerCell.completedIconNode.gameObject:SetActive(activity.isCompleted)
    end
end





ActivityCenterCtrl._OnTabClicked = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, index, forceRefresh)
    
    if #self.m_allActivities == 0 then
        self:_OnActivityDisabled()
        return
    end

    
    if self.m_selectedTabIndex == index and not forceRefresh then
        return
    end

    local lastSelectedCell = self:_GetCell(self.m_selectedTabIndex)
    if lastSelectedCell then
        self:_SetTabCellSelected(lastSelectedCell, false)
    end
    self.m_selectedTabIndex = index
    local selectedCell = self:_GetCell(index)
    if selectedCell then
        self:_SetTabCellSelected(selectedCell, true)
    end

    
    local id = self.m_allActivities[index].id
    ActivityUtils.GameEventLogActivityVisit(id, "ActivityTabCellButton", "visit_center")

    
    if ActivityUtils.isNewActivity(id) then
        ActivityUtils.setFalseNewActivity(id)
    end
    
    if ActivityUtils.isNewUnlockActivity(id) then
        ActivityUtils.setFalseNewUnlockActivity(id)
    end
    
    if ActivityUtils.isNewActivityBubble(id) and self.m_allActivities[index].activity.isUnlocked then
        ActivityUtils.setFalseNewActivityBubble(id)
    end

    
    if self.m_activityId == id then
        return
    end

    
    self.m_activityId = id
    Notify(MessageConst.SHOW_ACTIVITY_PANEL, {
        activityId = id,
        controllerHintPlaceholder = self.view.controllerHintPlaceholder,
        groupId = self.view.inputBindingGroupMonoTarget.groupId,
        naviGroup = self.view.tabScrollRectSelectableNaviGroup,
        getReturnTargetFunc = function()
            return self:_GetCell(self.m_activityDict[id].index).button
        end,
        btnClose = self.view.btnClose,
    })
end







ActivityCenterCtrl.GoToActivity = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, activityId, forceRefresh)
    local index
    if not string.isEmpty(activityId) and self.m_activityDict[activityId] then
        index = self.m_activityDict[activityId].index or 1
    else
        index = 1
    end
    self:_OnTabClicked(index, forceRefresh)
    local cell = self:_GetCell(index)
    if cell then
        self.view.tabScrollRect:ScrollToNaviTarget(cell.button)
    end
    self:_SetNaviTarget(index)
end



ActivityCenterCtrl._GetShowingCellStartEnd = HL.Method().Return(HL.Number,HL.Number) << function(self)
    local redDotSize = self.view.tabCell.selectNode.redDot.rectTransform.rect.height
    local totalCount = #self.m_allActivities

    local low, high = 1, totalCount
    local start = totalCount
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local cell = self:_GetCell(mid)
        local top = -self.view.contentRectTransform.anchoredPosition.y - cell.gameObject:GetComponent("RectTransform").anchoredPosition.y - self.view.tabCellRectTransform.rect.height / 2 - redDotSize / 2
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
        local cell = self:_GetCell(mid)
        local top = -self.view.contentRectTransform.anchoredPosition.y - cell.gameObject:GetComponent("RectTransform").anchoredPosition.y - self.view.tabCellRectTransform.rect.height / 2 - redDotSize / 2

        if top < self.view.tabScrollRectRectTransform.rect.height then
            final = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return start, final
end




ActivityCenterCtrl._GetCell = HL.Method(HL.Number).Return(HL.Any) << function(self, index)
    local target
    self.m_tabCells:Refresh(#self.m_allActivities, function(cell, tabIndex)
        if index == tabIndex then
            target = cell
        end
    end)
    return target
end




ActivityCenterCtrl._SetNaviTarget = HL.Method(HL.Number) << function(self, index)
    local cell = self:_GetCell(index)
    if DeviceInfo.usingController and cell then
        self.view.tabScrollRect:ScrollToNaviTarget(cell.button)
        UIUtils.setAsNaviTarget(cell.button)
    end
end





ActivityCenterCtrl._SetTabCellSelected = HL.Method(HL.Table, HL.Boolean) << function(self, tabCell, isSelected)
    tabCell.stateController:SetState(isSelected and "selected" or "normal")
end



ActivityCenterCtrl._Close = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end




ActivityCenterCtrl.OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    local activity = GameInstance.player.activitySystem:GetActivity(id)

    
    if not activity then
        self:_OnActivityDisabled()
        return
    end

    
    if not self.m_activityDict[id] then
        self:_RefreshTabList()
        return
    end

    
    if activity.status ~= self.m_allActivities[self.m_activityDict[id].index].status then
        self:_RefreshTabCompleteState()
        return
    end
end



ActivityCenterCtrl._RefreshTabCompleteState = HL.Method() << function(self)
    self.m_tabCells:Refresh(#self.m_allActivities, function(cell, index)
        local activityData = self.m_allActivities[index].activityData
        local activity = GameInstance.player.activitySystem:GetActivity(activityData.id)
        cell.selectNode.completedIconNode.gameObject:SetActive(activity.isCompleted)
        cell.normalNode.completedIconNode.gameObject:SetActive(activity.isCompleted)
    end)
end



ActivityCenterCtrl._IsActivityChanged = HL.Method().Return(HL.Boolean) << function(self)
    local old = self.m_activityDict
    local new = {}
    local activities = GameInstance.player.activitySystem:GetAllActivities()
    for _, activity in cs_pairs(activities) do
        new[activity.id] = true
    end
    for key, _ in pairs(new) do
        if old[key] == nil then
            return true
        end
    end
    for key, _ in pairs(old) do
        if new[key] == nil then
            return true
        end
    end
    return false
end



ActivityCenterCtrl._OnActivityDisabled = HL.Method() << function(self)
    GameInstance.player.guide:OnActivityDisabled()
    Notify(MessageConst.SHOW_POP_UP,{
        content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU,
        hideCancel = true,
        onConfirm = function()
            PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
        end
    })
end




ActivityCenterCtrl.OnPhaseRefresh = HL.Override(HL.Any) << function(self, arg)
    self:GoToActivity(arg and arg.gotoCenter and arg.activityId, true)
end


HL.Commit(ActivityCenterCtrl)
