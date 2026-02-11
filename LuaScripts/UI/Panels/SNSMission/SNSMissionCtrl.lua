local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SNSMission

local MissionImportanceCfg = {
    [GEnums.MissionImportance.Low] = "ui_mis_importance_3",
    [GEnums.MissionImportance.Mid] = "ui_mis_importance_2",
    [GEnums.MissionImportance.High] = "ui_mis_importance_1",
}

local MissionViewTypeCfg = {
    [GEnums.MissionViewType.MissionViewMain] = "ui_mis_panel_tab_main_new",
    [GEnums.MissionViewType.MissionViewDiscovery] = "ui_mis_panel_tab_discovery",
    [GEnums.MissionViewType.MissionViewSide] = "ui_mis_panel_tab_side",
    [GEnums.MissionViewType.MissionViewActivity] = "ui_mis_panel_tab_activity",
    [GEnums.MissionViewType.MissionViewOther] = "ui_mis_panel_tab_other",
}



























SNSMissionCtrl = HL.Class('SNSMissionCtrl', uiCtrl.UICtrl)


SNSMissionCtrl.m_filterMissionRelatedDialogInfos = HL.Field(HL.Table)


SNSMissionCtrl.m_genMissionDialogCellFunc = HL.Field(HL.Function)


SNSMissionCtrl.m_curSelectDialogId = HL.Field(HL.String) << ""


SNSMissionCtrl.m_dialogId2LuaIndex = HL.Field(HL.Table)


SNSMissionCtrl.m_cachedSelectedTags = HL.Field(HL.Table)


SNSMissionCtrl.m_filterArgs = HL.Field(HL.Table)






SNSMissionCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





SNSMissionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_genMissionDialogCellFunc = UIUtils.genCachedCellFunction(self.view.missionDialogCellScrollList)

    self.view.missionDialogCellScrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_OnUpdateMissionDialogCell(go, csIndex)
    end)

    self.view.btnCommonFilter.button.onClick:AddListener(function()
        self:_OnBtnFilterClick()
    end)

    self:_InitData(arg)
    self:_InitFilterArgs()

    self:_UpdateFilterMissionRelatedDialogInfos({})
    self:_RefreshMissionRelatedDialogList()

    self:_RefreshContent()
    self:_RefreshNaviTarget()
end











SNSMissionCtrl._InitData = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    local dialogId = arg and arg.dialogId
    if not string.isEmpty(dialogId) and Tables.sNSDialogTable:ContainsKey(dialogId) then
        self.m_curSelectDialogId = dialogId
    end
end



SNSMissionCtrl._RefreshContent = HL.Method() << function(self)
    local hasSelectDialog = not string.isEmpty(self.m_curSelectDialogId)
    if hasSelectDialog then
        local dialogId = self.m_curSelectDialogId
        local chatId = Tables.sNSDialogTable[dialogId].chatId
        GameInstance.player.sns:ReadDialog(dialogId)
        self.view.snsDialogContentCore:InitSNSDialogContentCore(chatId, dialogId)
    end
    self.view.nonSelected.gameObject:SetActive(not hasSelectDialog)
    self.view.selected.gameObject:SetActive(hasSelectDialog)
end





SNSMissionCtrl._OnUpdateMissionDialogCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    
    local cell = self.m_genMissionDialogCellFunc(go)
    local luaIndex = LuaIndex(csIndex)
    local info = self.m_filterMissionRelatedDialogInfos[luaIndex]
    local dialogId = info.dialogId
    self.m_dialogId2LuaIndex[dialogId] = luaIndex

    cell:InitSNSMissionRelatedDialogCell(info.dialogId, function(chatId, dialogId)
        self:_OnClickMissionDialogCell(chatId, dialogId)
    end)
    cell:SetSelected(self.m_curSelectDialogId == dialogId)
    cell.gameObject.name = dialogId

    cell.view.btnClick.onIsNaviTargetChanged = function(isTarget, isGroupChanged)
        if isTarget then
            self.m_focusCellCSIndex = csIndex
        end
    end
end



SNSMissionCtrl._RefreshMissionRelatedDialogList = HL.Method() << function(self)
    local hasResult = #self.m_filterMissionRelatedDialogInfos > 0
    self.view.missionDialogCellScrollList.gameObject:SetActive(hasResult)
    self.view.nonResult.gameObject:SetActive(not hasResult)

    local findTargetLuaIndex
    for luaIndex, info in ipairs(self.m_filterMissionRelatedDialogInfos) do
        if info.dialogId == self.m_curSelectDialogId then
            findTargetLuaIndex = luaIndex
            break
        end
    end

    if findTargetLuaIndex == nil then
        findTargetLuaIndex = 1
        self.m_curSelectDialogId = ""
    end

    self.m_dialogId2LuaIndex = {}
    local count = #self.m_filterMissionRelatedDialogInfos
    self.view.missionDialogCellScrollList:UpdateCount(count, CSIndex(findTargetLuaIndex))
end



SNSMissionCtrl._RefreshNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local findTargetLuaIndex
    for luaIndex, info in ipairs(self.m_filterMissionRelatedDialogInfos) do
        if info.dialogId == self.m_curSelectDialogId then
            findTargetLuaIndex = luaIndex
            break
        end
    end

    findTargetLuaIndex = findTargetLuaIndex or 1

    
    local cell = self.m_genMissionDialogCellFunc(findTargetLuaIndex)
    UIUtils.setAsNaviTarget(cell and cell.view.btnClick)
end





SNSMissionCtrl._OnClickMissionDialogCell = HL.Method(HL.String, HL.String) << function(self, chatId, dialogId)
    if self.m_curSelectDialogId == dialogId then
        return
    end
    local preDialogId = self.m_curSelectDialogId
    self.m_curSelectDialogId = dialogId

    
    local preCell = self.m_genMissionDialogCellFunc(self.m_dialogId2LuaIndex[preDialogId])
    if preCell then
        preCell:SetSelected(false)
    end
    
    local curCell = self.m_genMissionDialogCellFunc(self.m_dialogId2LuaIndex[dialogId])
    curCell:SetSelected(true)

    self:_RefreshContent()
end



SNSMissionCtrl._InitFilterArgs = HL.Method() << function(self)
    local filterArgs = {}
    filterArgs.tagGroups = {}

    local missionImportanceFilter = {}
    missionImportanceFilter.title = Language.LUA_MISSION_FILTER_IMPORTANCE_TITLE
    missionImportanceFilter.tags = {}
    for importanceType, nameLangKey in pairs(MissionImportanceCfg) do
        table.insert(missionImportanceFilter.tags, {
            importanceType = importanceType,
            name = Language[nameLangKey],
            order = importanceType:GetHashCode()
        })
    end
    table.sort(missionImportanceFilter.tags, Utils.genSortFunction({"order"}, true))
    table.insert(filterArgs.tagGroups, missionImportanceFilter)

    local missionTypeFilter = {}
    missionTypeFilter.title = Language.LUA_MISSION_FILTER_VIEW_TYPE_TITLE
    missionTypeFilter.tags = {}
    for viewType, nameLangKey in pairs(MissionViewTypeCfg) do
        table.insert(missionTypeFilter.tags, {
            viewType = viewType,
            name = Language[nameLangKey],
            order = viewType:GetHashCode()
        })
    end
    table.sort(missionTypeFilter.tags, Utils.genSortFunction({"order"}, true))
    table.insert(filterArgs.tagGroups, missionTypeFilter)

    local dialogReadFilter = {}
    dialogReadFilter.title = Language.LUA_COMMON_FILTER_END_STATE_TITLE
    dialogReadFilter.tags = { { name = Language.LUA_COMMON_FILTER_END_STATE_NO, endState = false },
                              { name = Language.LUA_COMMON_FILTER_END_STATE_YES, endState = true } }
    table.insert(filterArgs.tagGroups, dialogReadFilter)

    filterArgs.onConfirm = function(selectedTags)
        self:_OnFilterConfirm(selectedTags)
    end

    self.m_filterArgs = filterArgs
end




SNSMissionCtrl._OnFilterConfirm = HL.Method(HL.Table) << function(self, selectedTags)
    selectedTags = selectedTags or {}
    self.m_cachedSelectedTags = selectedTags
    self.m_curSelectDialogId = ""

    local hasFilter = #selectedTags > 0
    self.view.btnCommonFilter.normalNode.gameObject:SetActiveIfNecessary(not hasFilter)
    self.view.btnCommonFilter.existNode.gameObject:SetActiveIfNecessary(hasFilter)
    self.view.snsDialogContentCore:ClearAsyncHandler()

    self:_UpdateFilterMissionRelatedDialogInfos(selectedTags)
    self:_RefreshMissionRelatedDialogList()
    self:_RefreshContent()

    self:_ManuallyResetControllerState()
    self:_RefreshNaviTarget()
end




SNSMissionCtrl._UpdateFilterMissionRelatedDialogInfos = HL.Method(HL.Table) << function(self, selectedTags)
    local sns = GameInstance.player.sns
    local missionRelatedDialogInfos = {}
    local missionRelatedSNSDialogIds = sns.missionRelatedSNSDialogIds
    local missionSys = GameInstance.player.mission
    local dialogInfoDic = sns.dialogInfoDic

    for _, dialogId in pairs(missionRelatedSNSDialogIds) do

        
        local importanceMatch = true
        local hasImportanceTag = false
        local viewTypeMatch = true
        local hasViewTypeTag = false
        local readMatch = true
        local hasReadTag = false

        local missionId = Tables.sNSDialogTable[dialogId].relatedMissionId
        local missionMetaAsset = missionSys:GetMissionMetaAsset(missionId)
        local dialogInfo = dialogInfoDic:get_Item(dialogId)

        local importanceType = missionMetaAsset.missionImportance
        local viewType = missionMetaAsset.viewType

        for _, tag in ipairs(selectedTags) do
            if tag.importanceType ~= nil then
                importanceMatch = false
                hasImportanceTag = true
            end
            if hasImportanceTag then
                importanceMatch = importanceMatch or importanceType == tag.importanceType
            end

            if tag.viewType ~= nil then
                viewTypeMatch = false
                hasViewTypeTag = true
            end
            if hasViewTypeTag then
                viewTypeMatch = viewTypeMatch or viewType == tag.viewType
            end

            if tag.endState ~= nil then
                readMatch = false
                hasReadTag = true
            end
            if hasReadTag then
                readMatch = readMatch or dialogInfo.isEnd == tag.endState
            end
        end

        if importanceMatch and viewTypeMatch and readMatch then
            table.insert(missionRelatedDialogInfos, {
                dialogId = dialogId,
                missionId = missionId,

                isReadSort = dialogInfo.isRead and 0 or 1,
                isEndSort = dialogInfo.isEnd and 0 or 1,
                importance = importanceType:GetHashCode() * -1,
                viewType = viewType:GetHashCode() * -1,
                timestamp = dialogInfo.timestamp,
            })
        end

    end

    table.sort(missionRelatedDialogInfos,
               Utils.genSortFunction({ "isReadSort", "isEndSort", "importance", "viewType" }))

    self.m_filterMissionRelatedDialogInfos = missionRelatedDialogInfos
end



SNSMissionCtrl._OnBtnFilterClick = HL.Method() << function(self)
    self.m_filterArgs.selectedTags = self.m_cachedSelectedTags
    self:Notify(MessageConst.SHOW_COMMON_FILTER, self.m_filterArgs)
end



SNSMissionCtrl.GetPanelType = HL.Method().Return(HL.Number) << function(self)
    return SNSUtils.PanelType.FullScreenPanel
end




SNSMissionCtrl.m_focusCellCSIndex = HL.Field(HL.Number) << -1




SNSMissionCtrl.OnContentCoreFocus = HL.Method(HL.Boolean) << function(self, isOn)
    self.m_phase:OnSNSBarkerContentCoreFocus(isOn)
end



SNSMissionCtrl.ReturnToFocusCell = HL.Method() << function(self)
    
    local cell = self.m_genMissionDialogCellFunc(LuaIndex(self.m_focusCellCSIndex))
    UIUtils.setAsNaviTarget(cell.view.btnClick)
end



SNSMissionCtrl.TryContinueDialog = HL.Method() << function(self)
    self:_RefreshContent()
end




SNSMissionCtrl.OnSwitchOn = HL.Method(HL.Boolean) << function(self, isOn)
    if not isOn then
        self.view.snsDialogContentCore:ClearAsyncHandler()
        return
    end

    ClientDataManagerInst:SetBool(SNSUtils.MISSION_TAB_READ, true, false, SNSUtils.SNS_CATEGORY, true)
    Notify(MessageConst.ON_SNS_MISSION_TAB_READ_STATE_CHANGE)

    if not DeviceInfo.usingController then
        return
    end

    
    local cell = self.m_genMissionDialogCellFunc(LuaIndex(self.m_focusCellCSIndex))
    if cell then
        UIUtils.setAsNaviTarget(cell.view.btnClick)
    end

    
    local phase = self.m_phase
    phase:ToggleBasicPanelCloseBtn(true)
end



SNSMissionCtrl._ManuallyResetControllerState = HL.Method() << function(self)
    self.view.snsDialogContentCore:ToggleContentCoreFocusable(false)
end



HL.Commit(SNSMissionCtrl)
