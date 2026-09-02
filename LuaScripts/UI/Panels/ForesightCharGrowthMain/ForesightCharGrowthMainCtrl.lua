local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local ForesightCharGrowthDetailCtrl = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCtrl').ForesightCharGrowthDetailCtrl
local PhaseForesightCharGrowth = require_ex('Phase/ForesightCharGrowth/PhaseForesightCharGrowth').PhaseForesightCharGrowth
local function appendUniqueGroupId(groupIds, groupId)
    if not groupId or groupId <= 0 then
        return
    end
    for _, id in ipairs(groupIds) do
        if id == groupId then
            return
        end
    end
    groupIds[#groupIds + 1] = groupId
end








ForesightCharGrowthMainCtrl = HL.Class('ForesightCharGrowthMainCtrl', uiCtrl.UICtrl)
ForesightCharGrowthMainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CHAR_CULTIVATE_PRIORITY_CHANGED] = '_HandleCharCultivatePriorityChanged',
    [MessageConst.ON_INPUT_DEVICE_TYPE_CHANGED] = '_OnInputDeviceTypeChanged',
}
ForesightCharGrowthMainCtrl.m_getCharHeadCell = HL.Field(HL.Function)
ForesightCharGrowthMainCtrl.m_getGroupTitleCell = HL.Field(HL.Function)
ForesightCharGrowthMainCtrl.m_args = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_gachaPreviewList = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_charInfoList = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_filteredCharList = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_charId2finishStageId = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_filterTags = HL.Field(HL.Table)

ForesightCharGrowthMainCtrl.m_selectedChar = HL.Field(HL.Table)
ForesightCharGrowthMainCtrl.m_detailCtrl = HL.Field(HL.Forward('ForesightCharGrowthDetailCtrl'))
ForesightCharGrowthMainCtrl.m_detailView = HL.Field(HL.Table)

ForesightCharGrowthMainCtrl.m_pendingNaviCsIndex = HL.Field(HL.Number) << -1

ForesightCharGrowthMainCtrl.m_frozenListScrollY = HL.Field(HL.Number) << -1

ForesightCharGrowthMainCtrl.m_refreshingControllerHints = HL.Field(HL.Boolean) << false
ForesightCharGrowthMainCtrl.m_itemTipsHidesControllerHint = HL.Field(HL.Boolean) << false

ForesightCharGrowthMainCtrl.m_charViewTime = HL.Field(HL.Number) << 0
ForesightCharGrowthMainCtrl.m_charViewType = HL.Field(HL.Number) << 1

ForesightCharGrowthMainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_args = arg or {}
    self.m_gachaPreviewList = {}
    self.m_charId2finishStageId = {}
    self.m_selectedChar = {}
    self.m_filterTags = self.m_args.filterTags and lume.deepCopy(self.m_args.filterTags) or nil
    self:_ApplySelectionFromArg(self.m_args)

    local groupScrollList = self.view.charScrollList
    self.m_getCharHeadCell = UIUtils.genCachedCellFunction(groupScrollList, function(object)
        return UIWidgetManager:Wrap(object)
    end)
    self.m_getGroupTitleCell = UIUtils.genCachedCellFunction(groupScrollList, function(object)
        return Utils.wrapLuaNode(object)
    end, true)
    self.view.btnBack.onClick:AddListener(function() self:_OnBackBtnClick() end)
    self:_InitFilterNode()
    self:_InitSortNode(self.m_args.sortIsIncremental == true, self.m_args.sortSelectedIndex and CSIndex(self.m_args.sortSelectedIndex) or nil)

    groupScrollList.onUpdateCell:AddListener(function(object, csIndex) self:_UpdateGroupScrollListCell(object, csIndex) end)
    groupScrollList.onUpdateGroupTitle:AddListener(function(object, csIndex) self:_OnUpdateGroupTitle(object, csIndex) end)
    groupScrollList.getCellCountInGroup = function(groupCSIndex)
        local groupLua = LuaIndex(groupCSIndex)
        if groupLua == 1 then
            return #(self.m_gachaPreviewList or {})
        end
        if groupLua == 2 then
            return #(self.m_filteredCharList or {})
        end
        return 0
    end
    groupScrollList.getGroupTitleSize = function(groupCSIndex)
        local groupLua = LuaIndex(groupCSIndex)
        if groupLua == 1 and #(self.m_gachaPreviewList or {}) == 0 then
            return 80
        end
        if groupLua == 2 and #(self.m_filteredCharList or {}) == 0 and not self.view.emptyNode.gameObject.activeSelf then
            return 0
        end
        return 48
    end
    groupScrollList.getCurSelectedIndex = function() return self:_GetSelectedGlobalCellCsIndex() end
    local detailRoot = self.view.charGrowthDetailRoot
    self.m_detailView = detailRoot and Utils.bindLuaRef(detailRoot) or nil
    self.m_detailCtrl = ForesightCharGrowthDetailCtrl(PhaseForesightCharGrowth.Get(), self.m_detailView)
    self.m_detailCtrl.m_loadGameObject = function(path) return self:LoadGameObject(path) end
    self.m_detailCtrl:Init()
    local detailCtrl = self.m_detailCtrl
    detailCtrl.m_setNaviTarget = function(selectable)
        if selectable then
            self:SetNaviTarget(selectable)
        end
    end
    detailCtrl.m_refreshControllerHints = function(hideForItemTips)
        if hideForItemTips == true then
            if not DeviceInfo.usingController then
                return
            end
            self.m_itemTipsHidesControllerHint = true
            Notify(MessageConst.HIDE_CONTROLLER_HINT, { panelId = self.panelId })
            Notify(MessageConst.HIDE_CONTROLLER_HINT, { panelId = PanelId.FakeControllerSmallMenu })
            return
        end
        if hideForItemTips == false then
            if not DeviceInfo.usingController or UIManager:IsShow(PanelId.ItemTips) then
                return
            end
            self.m_itemTipsHidesControllerHint = false
        end
        self:_RefreshControllerHints()
    end
    detailCtrl.m_getNaviLeftTarget = function() return self:_GetCharListLeftNaviTarget() end
    detailCtrl.m_getIsCharListFocused = function()
        local scrollRect = self.view.charScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        local panelGroup = scrollRect and scrollRect.naviGroup
        local cur = InputManagerInst.controllerNaviManager.curTarget
        return cur and cur.naviGroup and panelGroup and cur.naviGroup == panelGroup
    end
    local rewardsCellHelper = detailCtrl.m_rewardsCellHelper
    rewardsCellHelper.m_getNaviLeftTarget = detailCtrl.m_getNaviLeftTarget
    rewardsCellHelper.m_setNaviTarget = detailCtrl.m_setNaviTarget
    if self.view.walletBarPlaceholder then
        self.view.walletBarPlaceholder.gameObject:SetActive(false)
    end
end

ForesightCharGrowthMainCtrl.OnShow = HL.Override() << function(self)
    RedDotUtils.setForesightCharGrowthEntryRead()
    if self.m_args and self.m_args.growthListFocused
        and self.m_args.growthScrollLuaIndex and self.m_args.growthScrollLuaIndex > 0 then
        self.m_detailCtrl.m_pendingGrowthScrollLuaIndex = math.floor(self.m_args.growthScrollLuaIndex)
    end
    self.m_detailCtrl:SetPanelActive(true)
    self.m_detailCtrl:OnShow()
    self:_WireControllerThreeBlockNav()
    self:_OnPanelBecameVisible()
    if self.m_detailCtrl.m_prevTabIndex == 0 then
        self.m_detailCtrl:_LogCultiOverviewTabChange(0)
    end
    self.m_charViewTime = Time.realtimeSinceStartup
    self.m_charViewType = 1
end

ForesightCharGrowthMainCtrl._LogCultiOverviewCharView = HL.Method(HL.Table, HL.Boolean) << function(self, info, exit)
    if not info then
        return
    end
    local now = Time.realtimeSinceStartup
    local stayTime = now - self.m_charViewTime
    self.m_charViewTime = now
    local charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned")
    local poolStatus
    if info.previewTag == "rerun" then
        poolStatus = "rerun"
    elseif info.previewTag == "replica" then
        poolStatus = "replica"
    elseif info.isInCurGachaPool == true or info.previewTag == "current" then
        poolStatus = "current"
    elseif info.isForesight then
        poolStatus = "preview"
    else
        poolStatus = "none"
        for _, poolCfg in pairs(Tables.gachaCharPoolTable) do
            local upCharIds = poolCfg.upCharIds
            if upCharIds then
                for i = 0, upCharIds.Count - 1 do
                    if upCharIds[i] == info.templateId then
                        poolStatus = "expired"
                        break
                    end
                end
                if poolStatus == "expired" then
                    break
                end
            end
        end
    end
    EventLogManagerInst:GameEvent_CultiOverviewCharView(
        info.templateId, self.m_charViewType, exit, stayTime, charStatus, poolStatus)
end

ForesightCharGrowthMainCtrl.OnClose = HL.Override() << function(self)
    self:_LogCultiOverviewCharView(self:_GetSelectedCharInfo(), true)
    self:_ClearRegisters()
end

ForesightCharGrowthMainCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.QUICK_HIDE_FULL_SCREEN_SCENE_BLUR)
    if self.m_detailCtrl then
        local state = self.m_detailCtrl:GetRecoverStateArg()
        if DeviceInfo.usingController and not UIManager.m_isHotSwitching and not state.growthListFocused then
            local scrollList = self.m_detailCtrl.m_view.contentScrollList
            local naviGroup = self.m_detailCtrl:_GetDetailNaviGroup()
            local layerGroup = naviGroup and naviGroup:GetLayerGroup()
            if layerGroup and InputManagerInst.controllerNaviManager:IsLayerInStack(layerGroup)
                and naviGroup.LayerSelectedTarget then
                local csIndex = scrollList:GetNaviManagerTargetIndex()
                if csIndex >= 0 then
                    state.growthScrollLuaIndex = LuaIndex(csIndex)
                    state.growthListFocused = true
                end
            end
        end
        self.m_args = self.m_args or {}
        self.m_args.growthScrollLuaIndex = state.growthScrollLuaIndex
        self.m_args.growthListFocused = state.growthListFocused
        self.m_detailCtrl:SetPanelActive(false)
    end
    if self.view.walletBarPlaceholder then
        self.view.walletBarPlaceholder.gameObject:SetActive(false)
    end
end

ForesightCharGrowthMainCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    if arg then
        self.m_args = arg
        if arg.filterTags ~= nil then
            self.m_filterTags = lume.deepCopy(arg.filterTags)
        end
        self:_ApplySelectionFromArg(arg)
        self:_SyncSortFilterUIFromArgs()
    end
    local recoverArg = arg or self.m_args
    if recoverArg and recoverArg.growthListFocused
        and recoverArg.growthScrollLuaIndex and recoverArg.growthScrollLuaIndex > 0 then
        self.m_detailCtrl.m_pendingGrowthScrollLuaIndex = math.floor(recoverArg.growthScrollLuaIndex)
    end
    self.m_detailCtrl:SetPanelActive(true)
    self:_OnPanelBecameVisible(arg)
end

ForesightCharGrowthMainCtrl._RefreshWalletBarPlaceholder = HL.Method() << function(self)
    local placeholder = self.view.walletBarPlaceholder
    if not placeholder then
        return
    end
    
    local wrapper = self.animationWrapper
    local animState = CS.Beyond.UI.UIConst.AnimationState
    if wrapper and wrapper:IsStarted() and wrapper.curState == animState.In then
        wrapper:SkipInAnimation()
    end
    if not placeholder.gameObject.activeSelf then
        placeholder.gameObject:SetActive(true)
    end
    placeholder:InitWalletBarPlaceholder({
        Tables.dungeonConst.doubleStaminaTicketItemId,
        Tables.dungeonConst.staminaItemId,
    })
end

ForesightCharGrowthMainCtrl._OnPanelBecameVisible = HL.Method(HL.Opt(HL.Table)) << function(self, detailArg)
    local hasGrowthScrollRecover = (detailArg and detailArg.growthScrollLuaIndex and detailArg.growthScrollLuaIndex > 0) or (self.m_args and self.m_args.growthScrollLuaIndex and self.m_args.growthScrollLuaIndex > 0)
    self:_RefreshWalletBarPlaceholder()
    self:_Refresh(detailArg)
    if DeviceInfo.usingController then
        if self.m_detailCtrl.m_pendingGrowthScrollLuaIndex > 0 then self.m_detailCtrl:_TryApplyPendingGrowthScrollNavi() end
        if self.m_detailCtrl.m_pendingGrowthScrollLuaIndex < 1 then
            if not hasGrowthScrollRecover then
                if InputManagerInst.controllerNaviManager.curTarget then self:ClearNaviTarget() end
                self:_RestoreControllerFocusToCharList()
            elseif not InputManagerInst.controllerNaviManager.curTarget then
                self:_RestoreControllerFocusToCharList()
            end
        end
        self:_RefreshControllerHints()
    end
end

ForesightCharGrowthMainCtrl._OnInputDeviceTypeChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if not self:IsShow() then
        return
    end
    if self.view.sortNode then
        self.view.sortNode:UpdateDeviceState()
    end
    self:_RefreshVisibleCellsDeviceState()
    self.m_detailCtrl:RefreshRewardRowControllerState()
    self:_SyncDetailToSelection(self.m_detailCtrl:GetRecoverStateArg(), true)
    if DeviceInfo.usingController then
        if self.view.tabRow and self.m_detailCtrl.m_isPanelActive then
            InputManagerInst:ToggleGroup(self.view.tabRow.groupId, true)
        end
        self:_WireControllerThreeBlockNav()
        if self.m_detailCtrl.m_pendingGrowthScrollLuaIndex > 0 then
            self.m_detailCtrl:_TryApplyPendingGrowthScrollNavi()
        end
        if self.m_detailCtrl.m_pendingGrowthScrollLuaIndex < 1 and not InputManagerInst.controllerNaviManager.curTarget then
            self:_RestoreControllerFocusToCharList()
        end
    else
        if self.view.tabRow then
            InputManagerInst:ToggleGroup(self.view.tabRow.groupId, false)
        end
        self:_UnwireControllerThreeBlockNav()
        self.m_pendingNaviCsIndex = -1
        self:ClearNaviTarget()
    end
end


ForesightCharGrowthMainCtrl._RequestControllerNaviToSelected = HL.Method() << function(self)
    if not DeviceInfo.usingController or not self:IsShow() then
        self.m_pendingNaviCsIndex = -1
        return
    end
    local csIndex = self:_GetSelectedGlobalCellCsIndex()
    local groupScrollList = self.view.charScrollList
    if csIndex < 0 or not groupScrollList then
        self.m_pendingNaviCsIndex = -1
        return
    end
    self.m_pendingNaviCsIndex = csIndex
    if not self:_TryApplyPendingControllerNavi() then
        self:_ScrollCharListToSelectedIfNeeded()
        self:_TryApplyPendingControllerNavi()
    end
end

ForesightCharGrowthMainCtrl._TryApplyPendingControllerNavi = HL.Method().Return(HL.Boolean) << function(self)
    local csIndex = self.m_pendingNaviCsIndex
    if csIndex < 0 then
        return false
    end
    local go = self.view.charScrollList:Get(csIndex)
    if not go then
        return false
    end
    local cell = self.m_getCharHeadCell(go)
    if not cell or not cell.view or not cell.view.button then
        return false
    end
    self.m_pendingNaviCsIndex = -1
    self:SetNaviTarget(cell.view.button)
    return true
end


ForesightCharGrowthMainCtrl._ScrollCharListToSelectedIfNeeded = HL.Method(HL.Opt(HL.Boolean, HL.Number)) << function(self, refreshList, targetCsIndex)
    local list = self.view.charScrollList
    if not list then return end
    if refreshList then list:UpdateGroup(2, -1) end
    local csIndex = targetCsIndex
    if csIndex == nil then csIndex = self:_GetSelectedGlobalCellCsIndex() end
    if csIndex < 0 or list:Get(csIndex) then return end
    list:ScrollToIndex(csIndex, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Bottom)
end

ForesightCharGrowthMainCtrl._ClearRegisters = HL.Method() << function(self)
    if self.m_detailCtrl then
        self.m_detailCtrl:SetPanelActive(false)
        self.m_detailCtrl:OnClose()
    end
    self:_UnwireControllerThreeBlockNav()
    if self.view.tabRow then
        InputManagerInst:ToggleGroup(self.view.tabRow.groupId, false)
    end
    self:_CleanupInputForHotSwitch()
    local groupScrollList = self.view.charScrollList
    if groupScrollList then
        groupScrollList.onUpdateCell:RemoveAllListeners()
        groupScrollList.onUpdateGroupTitle:RemoveAllListeners()
        groupScrollList.getCellCountInGroup = nil
        groupScrollList.getGroupTitleSize = nil
        groupScrollList.getCurSelectedIndex = nil
        if groupScrollList.ClearComponent then
            groupScrollList:ClearComponent()
        end
    end
end

ForesightCharGrowthMainCtrl._GetSelectedCharInfo = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local region = self:_GetActiveSelectionRegion()
    if not region then
        return nil
    end
    local selected = self.m_selectedChar[region]
    if not selected or not selected.templateId then
        return nil
    end
    return self:_FindCharInfoInRegion(region, selected.templateId)
end



ForesightCharGrowthMainCtrl._GetBackCharTemplateId = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    return self.m_args.backCharTemplateId or self.m_args.selectedCharTemplateId
end

ForesightCharGrowthMainCtrl.GetCurStateArg = HL.Method().Return(HL.Table) << function(self)
    local arg = {}
    arg.backCharTemplateId = self:_GetBackCharTemplateId()
    if self.view.sortNode then
        arg.sortSelectedIndex = self.view.sortNode:GetCurSelectedIndex()
        arg.sortIsIncremental = self.view.sortNode.isIncremental
    end
    arg.filterTags = self.m_filterTags and lume.deepCopy(self.m_filterTags) or self.m_filterTags
    local selectedChar = self.m_selectedChar
    local selected = selectedChar and (selectedChar.gacha or selectedChar.list)
    if selected and selected.templateId then
        if selectedChar.gacha then
            arg.selectedGachaCharTemplateId = selected.templateId
        else
            arg.selectedCharTemplateId = selected.templateId
        end
    end
    local detailState = self.m_detailCtrl:GetRecoverStateArg()
    arg.growthTabIndex = detailState.growthTabIndex
    arg.weaponRecommendView = detailState.weaponRecommendView
    arg.growthScrollLuaIndex = detailState.growthScrollLuaIndex
    arg.growthListFocused = detailState.growthListFocused
    arg.resetSelection = nil
    local isOpen, ctrl = UIManager:IsOpen(PanelId.PreciousItemObtain)
    if isOpen and ctrl:IsShow() then
        arg.preciousItemObtainArgs = ctrl:GetCurPhaseStateArg()
    end
    isOpen, ctrl = UIManager:IsOpen(PanelId.GemTagObtain)
    if isOpen and ctrl:IsShow() then
        arg.gemTagObtainArgs = ctrl:GetCurPhaseStateArg()
    end
    return arg
end

ForesightCharGrowthMainCtrl._RestoreControllerFocusToCharList = HL.Method() << function(self)
    if not DeviceInfo.usingController or not self:IsShow() then
        return
    end
    local detailCtrl = self.m_detailCtrl
    if detailCtrl then
        detailCtrl.m_pendingGrowthScrollLuaIndex = 0
    end
    self:_RequestControllerNaviToSelected()
end



ForesightCharGrowthMainCtrl._Refresh = HL.Method(HL.Opt(HL.Table)) << function(self, detailArg)
    local phase = PhaseForesightCharGrowth.Get()
    local bundle = phase:GetCharListBundle()
    self.m_gachaPreviewList = bundle.gachaPreviewList
    self.m_charInfoList = bundle.charInfoList
    self.m_charId2finishStageId = {}
    local ok, cfg = Tables.foresightGrowthConfigTable:TryGetValue("StageId2ShowIcon")
    if ok and cfg.arr.Count > 0 then
        local stageList = phase:GetCultivateStageIdList()
        for _, info in ipairs(self.m_charInfoList) do
            if info.isOwned then
                local stageId = phase:GetCharFinishedCultivateStageId(info.templateId, stageList)
                if stageId > 0 then
                    self.m_charId2finishStageId[info.templateId] = stageId
                end
            end
        end
    end

    self:_FilterCharList()
    local sortNode = self.view.sortNode
    if sortNode and sortNode.m_sortOptions then
        local optData = sortNode:GetCurSortData()
        self:_ResortCharListsAfterPinChanged(sortNode.isIncremental and optData.keys or optData.reverseKeys, sortNode.isIncremental)
    else
        self:_FinalizeSelection()
        if not sortNode then self:_ScrollCharListToSelectedIfNeeded(true) end
    end
    self:_SyncDetailToSelection(detailArg or self.m_args, true)
end


ForesightCharGrowthMainCtrl._ResortCharListsAfterPinChanged = HL.Method(HL.Table, HL.Boolean) << function(self, keys, isIncremental)
    local sortFn = Utils.genSortFunction(keys, isIncremental)
    self.m_charInfoList = self:_LayeredSort(self.m_charInfoList, sortFn)
    self.m_filteredCharList = self.m_filterTags == nil and self.m_charInfoList or self:_LayeredSort(self.m_filteredCharList, sortFn)
    self:_FinalizeSelection()
    self:_ScrollCharListToSelectedIfNeeded(true)
    if DeviceInfo.usingController then
        self:_RestoreControllerFocusToCharList()
    end
end

ForesightCharGrowthMainCtrl._OnClickGroupCell = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, csIndex, enterDetail)
    local resolved = self:_ResolveCellFromGlobalCsIndex(csIndex)
    if not resolved then
        return
    end
    local prevRegion = self:_GetActiveSelectionRegion()
    local prevInfo = prevRegion and self.m_selectedChar[prevRegion]
    local prevTemplateId = prevInfo and prevInfo.templateId
    if prevRegion ~= resolved.region or prevTemplateId ~= resolved.info.templateId then
        self:_LogCultiOverviewCharView(prevInfo, false)
        self.m_charViewType = 2
    end
    self.m_selectedChar = {[resolved.region] = { templateId = resolved.info.templateId, instId = resolved.info.instId }}
    if prevRegion and prevTemplateId then
        self:_UpdateCellSelectionVisual(prevRegion, prevTemplateId)
    end
    self:_UpdateCellSelectionVisual(resolved.region, resolved.info.templateId)
    self:_SyncDetailToSelection()
    if enterDetail and DeviceInfo.usingController then
        local header = self.m_detailCtrl:_GetDetailHeaderNaviSelectable()
        local contentRect = self.m_detailCtrl.m_view.contentScrollList.gameObject:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        local keepY = contentRect and contentRect.verticalNormalizedPosition
        if header and header.gameObject and header.gameObject.activeInHierarchy then self:SetNaviTarget(header) end
        if contentRect and keepY ~= nil then contentRect:KillScrollTween(); contentRect.verticalNormalizedPosition = keepY end
    end
end




ForesightCharGrowthMainCtrl._SyncDetailToSelection = HL.Method(HL.Opt(HL.Table, HL.Boolean)) << function(self, detailArg, forceRefresh)
    local info = self:_GetSelectedCharInfo()
    if not info then
        return
    end
    if not forceRefresh then
        local restoreTab = detailArg and detailArg.growthTabIndex ~= nil
        if not restoreTab and self.m_detailCtrl.m_displayTemplateId == info.templateId then
            return
        end
    end
    self.m_detailCtrl:Refresh(info, detailArg)
end




ForesightCharGrowthMainCtrl._HandleCharCultivatePriorityChanged = HL.Method() << function(self)
    local scrollList = self.view.charScrollList
    if not scrollList then return end
    local phase = PhaseForesightCharGrowth.Get()
    local total = #(self.m_gachaPreviewList or {}) + #(self.m_filteredCharList or {})
    for luaIndex = 1, total do
        local go = scrollList:Get(CSIndex(luaIndex))
        if go then
            local resolved = self:_ResolveCellFromGlobalCsIndex(CSIndex(luaIndex))
            local info = resolved and resolved.info
            local cell = info and self.m_getCharHeadCell(go)
            local pinnedNode = cell and cell.view and cell.view.pinnedNode
            if resolved.region == "list" and pinnedNode and pinnedNode.gameObject and info.templateId and not info.isForesight then
                pinnedNode.gameObject:SetActive(phase:IsCharPinned(info.templateId))
            end
        end
    end
end

ForesightCharGrowthMainCtrl._OnSortChanged = HL.Method(HL.Table, HL.Boolean) << function(self, optData, isIncremental)
    if not self.m_charInfoList then
        return
    end
    local keys = isIncremental and optData.keys or optData.reverseKeys
    self:_ResortCharListsAfterPinChanged(keys, isIncremental)
    self:_SyncDetailToSelection()
end

ForesightCharGrowthMainCtrl._OnFilterConfirm = HL.Method(HL.Any) << function(self, tags)
    self.m_filterTags = tags
    self:_FilterCharList()
    self:_OnSortChanged(self.view.sortNode:GetCurSortData(), self.view.sortNode.isIncremental)
end




ForesightCharGrowthMainCtrl._TryCloseBlockingOverlayPanel = HL.Method().Return(HL.Boolean) << function(self)
    if self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder() then
        return false
    end
    local _, _, topCtrl = UIManager:_FindTopPanelProperty(function(cfg, ctrl)
        if ctrl:GetBlockKeyboardEvent() and ctrl:IsShow() then
            return true
        end
    end)
    if not topCtrl or topCtrl == self then
        return false
    end
    if topCtrl.PlayAnimationOutAndClose then
        topCtrl:PlayAnimationOutAndClose()
        return true
    end
    return false
end

ForesightCharGrowthMainCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
end

ForesightCharGrowthMainCtrl._OnBackBtnClick = HL.Method() << function(self)
    if self:_TryCloseBlockingOverlayPanel() then
        return
    end
    local commonTipsCtrl = UIManager:AutoOpen(PanelId.CommonTips)
    local hasCommonTips = commonTipsCtrl and commonTipsCtrl.view.main.gameObject.activeSelf
    if UIManager:IsShow(PanelId.ItemTips) or hasCommonTips then
        if UIManager:IsShow(PanelId.ItemTips) then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
        if hasCommonTips then
            self.m_detailCtrl.m_rewardsCellHelper:HideCommonTipsIfVisible()
        end
        return
    end
    if DeviceInfo.usingController then
        local scrollRect = self.view.charScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        local panelGroup = scrollRect and scrollRect.naviGroup
        local cur = InputManagerInst.controllerNaviManager.curTarget
        if cur and panelGroup and cur.naviGroup ~= panelGroup then
            self:_RequestControllerNaviToSelected()
            return
        end
    end
    Notify(MessageConst.CHAR_INFO_PAUSE_ANIMATOR, false)
    Notify(MessageConst.QUICK_HIDE_FULL_SCREEN_SCENE_BLUR)
    local _, charInfoPhase = PhaseManager:IsOpen(PhaseId.CharInfo)
    local targetCharInfo
    local backCharTemplateId = self:_GetBackCharTemplateId()
    if charInfoPhase.m_charInfoList then
        for _, charInfo in ipairs(charInfoPhase.m_charInfoList) do
            if charInfo.templateId == backCharTemplateId then
                targetCharInfo = charInfo
                break
            end
        end
    end
    
    local curCharInfo = charInfoPhase.m_charInfo
    targetCharInfo = targetCharInfo or curCharInfo
    local isSameChar = targetCharInfo ~= nil and curCharInfo ~= nil and curCharInfo.instId == targetCharInfo.instId
    local isInOverview = charInfoPhase.m_curPage == UIConst.CHAR_INFO_PAGE_TYPE.OVERVIEW
    if targetCharInfo and not (isSameChar and isInOverview) then
        Notify(MessageConst.CHAR_INFO_JUMP_PAGE, {
            pageType = UIConst.CHAR_INFO_PAGE_TYPE.OVERVIEW,
            charInfo = targetCharInfo,
        })
    end
    self:PlayAnimationOutWithCallback(function()
        local isOpen, charInfoPhase = PhaseManager:IsOpen(PhaseId.CharInfo)
        if isOpen and charInfoPhase then
            charInfoPhase:CloseCharInfoPanel(PanelId.ForesightCharGrowthMain)
        else
            UIManager:Close(PanelId.ForesightCharGrowthMain)
        end
    end)
end



ForesightCharGrowthMainCtrl._UpdateCellSelectionVisual = HL.Method(HL.String, HL.String) << function(self, region, templateId)
    if not region or not templateId then
        return
    end
    local csIndex = self:_GetGlobalCellCsIndex(region, templateId)
    if csIndex < 0 then
        return
    end
    local go = self.view.charScrollList:Get(csIndex)
    if not go then
        return
    end
    local cell = self.m_getCharHeadCell(go)
    if cell and cell.view.selectedBG then
        cell.view.selectedBG.gameObject:SetActive(self:_IsRegionCellSelected(region, templateId))
    end
end

ForesightCharGrowthMainCtrl._OnUpdateGroupTitle = HL.Method(HL.Userdata, HL.Number) << function(self, object, groupCsIndex)
    local groupLua = LuaIndex(groupCsIndex)
    local cell = self.m_getGroupTitleCell(object)
    if not cell or not cell.titleTxt then
        return
    end
    if groupLua == 1 then
        if #(self.m_gachaPreviewList or {}) == 0 then
            cell.titleTxt.text = Language.LUA_FORESIGHT_GACHA_SECTION_TITLE .. "\n" .. Language.LUA_FORESIGHT_GACHA_SECTION_EMPTY
        else
            cell.titleTxt.text = Language.LUA_FORESIGHT_GACHA_SECTION_TITLE
        end
        return
    end
    if groupLua == 2 then
        cell.titleTxt.text = Language.LUA_FORESIGHT_ALL_CHAR_SECTION_TITLE
        local showTitle = #(self.m_filteredCharList or {}) > 0 or self.view.emptyNode.gameObject.activeSelf
        for i = 0, object.transform.childCount - 1 do
            object.transform:GetChild(i).gameObject:SetActive(showTitle)
        end
    end
end

ForesightCharGrowthMainCtrl._UpdateGroupScrollListCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, csIndex)
    local resolved = self:_ResolveCellFromGlobalCsIndex(csIndex)
    if not resolved then
        return
    end
    local region = resolved.region
    local info = resolved.info
    local cell = self.m_getCharHeadCell(object)
    self:_InitListCell(cell, info, region, function()
        self:_OnClickGroupCell(csIndex, true)
    end)
    local button = cell.view.button
    if button then
        button.onIsNaviTargetChanged = function(isTarget)
            if not DeviceInfo.usingController then
                return
            end
            if isTarget then
                self.m_detailCtrl.m_rewardsCellHelper:HideCommonTipsIfVisible()
                self:_OnClickGroupCell(csIndex)
            end
            self:_RefreshControllerHints()
        end
        button.customNaviTargetInDirFunc = function(dir)
            if dir == CS.UnityEngine.UI.NaviDirection.Right then
                return self:_GetCellButtonByGlobalCsIndex(csIndex + 1)
            end
        end
    end

    local isSelected = self:_IsRegionCellSelected(region, info.templateId)
    if cell.view.selectedBG then
        cell.view.selectedBG.gameObject:SetActive(isSelected)
    end
    if self.m_pendingNaviCsIndex >= 0 then
        self:_TryApplyPendingControllerNavi()
    end
end

ForesightCharGrowthMainCtrl._ResolveCellFromGlobalCsIndex = HL.Method(HL.Number).Return(HL.Table) << function(self, csIndex)
    local globalLua = LuaIndex(csIndex)
    local gachaCount = #(self.m_gachaPreviewList or {})
    if globalLua <= gachaCount then
        local info = self.m_gachaPreviewList[globalLua]
        if info then
            return { region = "gacha", info = info }
        end
        return nil
    end
    local listLua = globalLua - gachaCount
    local info = self.m_filteredCharList[listLua]
    if info then
        return { region = "list", info = info }
    end
    return nil
end

ForesightCharGrowthMainCtrl._GetGlobalCellCsIndex = HL.Method(HL.String, HL.String).Return(HL.Number) << function(self, region, templateId)
    if not templateId then
        return -1
    end
    if region == "gacha" then
        for k, info in ipairs(self.m_gachaPreviewList or {}) do
            if info.templateId == templateId then
                return CSIndex(k)
            end
        end
        return -1
    end
    if region == "list" then
        local gachaCount = #(self.m_gachaPreviewList or {})
        for k, info in ipairs(self.m_filteredCharList or {}) do
            if info.templateId == templateId then
                return CSIndex(gachaCount + k)
            end
        end
    end
    return -1
end

ForesightCharGrowthMainCtrl._GetSelectedGlobalCellCsIndex = HL.Method().Return(HL.Number) << function(self)
    local region = self:_GetActiveSelectionRegion()
    if not region then
        return -1
    end
    local selected = self.m_selectedChar[region]
    if not selected or not selected.templateId then
        return -1
    end
    return self:_GetGlobalCellCsIndex(region, selected.templateId)
end





ForesightCharGrowthMainCtrl._GetCharListLeftNaviTarget = HL.Method().Return(HL.Opt(HL.Any))
    << function(self)
    local csIndex = self:_GetSelectedGlobalCellCsIndex()
    if csIndex >= 0 then
        local button = self:_GetCellButtonByGlobalCsIndex(csIndex, false)
        if button then
            return button
        end
    end
    local total = #(self.m_gachaPreviewList or {}) + #(self.m_filteredCharList or {})
    for luaIndex = 1, total do
        local visibleButton = self:_GetCellButtonByGlobalCsIndex(CSIndex(luaIndex), false)
        if visibleButton then
            return visibleButton
        end
    end
    return nil
end

ForesightCharGrowthMainCtrl._UnwireControllerThreeBlockNav = HL.Method() << function(self)
    local headerSelectable = self.m_detailCtrl:_GetDetailHeaderNaviSelectable()
    if not headerSelectable then
        return
    end
    if headerSelectable.onGroupSetAsNaviTarget then
        headerSelectable.onGroupSetAsNaviTarget:RemoveAllListeners()
    end
    headerSelectable.customNaviTargetInDirFunc = nil
end

ForesightCharGrowthMainCtrl._OnHeaderNaviTargetChanged = HL.Method(HL.Boolean) << function(self, isTarget)
    if not DeviceInfo.usingController then
        return
    end
    if isTarget then
        self.m_detailCtrl.m_rewardsCellHelper:HideCommonTipsIfVisible()
        local scrollRect = self.view.charScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        if scrollRect then
            self.m_frozenListScrollY = scrollRect.verticalNormalizedPosition
        end
        
        local frozenY = self.m_frozenListScrollY
        if frozenY >= 0 then
            self.m_frozenListScrollY = -1
            if scrollRect then
                scrollRect:KillScrollTween()
                scrollRect.verticalNormalizedPosition = frozenY
            end
        end
    end
    self:_RefreshControllerHints()
end


ForesightCharGrowthMainCtrl._WireControllerThreeBlockNav = HL.Method() << function(self)
    local detailCtrl = self.m_detailCtrl
    local detailGroup = detailCtrl:_GetDetailNaviGroup()
    if detailGroup then
        detailGroup.isIsolate = true
    end
    self:_UnwireControllerThreeBlockNav()
    if not DeviceInfo.usingController then
        return
    end
    local headerSelectable = detailCtrl:_GetDetailHeaderNaviSelectable()
    if not headerSelectable then
        return
    end
    headerSelectable.banExplicitOnRight = true
    headerSelectable.banExplicitOnLeft = true
    headerSelectable.customNaviTargetInDirFunc = function(dir)
        if dir == CS.UnityEngine.UI.NaviDirection.Right then
            return nil
        end
        if dir == CS.UnityEngine.UI.NaviDirection.Down then
            return detailCtrl:_GetScrollRowNaviTargetAt(LuaIndex(detailCtrl.m_view.contentScrollList:GetShowingCellsIndexRange()))
        end
        if dir == CS.UnityEngine.UI.NaviDirection.Left then
            return self:_GetCharListLeftNaviTarget()
        end
        return nil
    end
    headerSelectable.onGroupSetAsNaviTarget:AddListener(function(isTarget)
        self:_OnHeaderNaviTargetChanged(isTarget)
    end)
end

ForesightCharGrowthMainCtrl._SetupListCellControllerInput = HL.Method(HL.Any) << function(self, button)
    if not button then
        return
    end
    button.enableControllerNavi = true
    button:ChangeActionOnSetNaviTarget(CS.Beyond.Input.ActionOnSetNaviTarget.None)
    if DeviceInfo.usingController then
        button:ChangeActionOnSetNaviTarget(CS.Beyond.Input.ActionOnSetNaviTarget.PressConfirmTriggerOnClick)
        button.hintTextId = "key_hint_common_confirm"
    else
        button.hintTextId = ""
    end
    button.clickHintTextId = ""
end

ForesightCharGrowthMainCtrl._GetCellButtonByGlobalCsIndex = HL.Method(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Opt(HL.Any))
    << function(self, csIndex, scrollIfNeeded)
    local groupScrollList = self.view.charScrollList
    if not groupScrollList then
        return nil
    end
    local go = groupScrollList:Get(csIndex)
    if not go and scrollIfNeeded then
        self:_ScrollCharListToSelectedIfNeeded(false, csIndex)
        go = groupScrollList:Get(csIndex)
    end
    if not go then
        return nil
    end
    local cell = self.m_getCharHeadCell(go)
    if cell and cell.view and cell.view.button then
        return cell.view.button
    end
    return nil
end

ForesightCharGrowthMainCtrl._RefreshVisibleCellsDeviceState = HL.Method() << function(self)
    local scrollList = self.view.charScrollList
    if not scrollList then
        return
    end
    local total = #(self.m_gachaPreviewList or {}) + #(self.m_filteredCharList or {})
    for luaIndex = 1, total do
        local go = scrollList:Get(CSIndex(luaIndex))
        if go then
            local cell = self.m_getCharHeadCell(go)
            if cell and cell.view.button then
                self:_SetupListCellControllerInput(cell.view.button)
            end
        end
    end
end

ForesightCharGrowthMainCtrl._BuildMainControllerHintGroupIds = HL.Method().Return(HL.Table) << function(self)
    local groupIds = {}
    local detailCtrl = self.m_detailCtrl
    if not DeviceInfo.usingController or not self.m_detailCtrl.m_isPanelActive then
        return groupIds
    end
    local tabRowGroupId = self.view.tabRow and self.view.tabRow.groupId or -1
    appendUniqueGroupId(groupIds, tabRowGroupId)
    local detailView = detailCtrl.m_view
    local headerGroupId = detailView and detailView.headerInputGroup and detailView.headerInputGroup.groupId or -1
    appendUniqueGroupId(groupIds, headerGroupId)
    local listGroupId = self.view.inputBindingGroupMonoTarget and self.view.inputBindingGroupMonoTarget.groupId or -1
    local scrollRect = self.view.charScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    local panelGroup = scrollRect and scrollRect.naviGroup
    local cur = InputManagerInst.controllerNaviManager.curTarget
    local header = detailCtrl:_GetDetailHeaderNaviSelectable()
    local onLeftList = cur and panelGroup and cur.naviGroup == panelGroup
    if onLeftList then
        self.view.btnBack.hintTextId = "key_hint_common_cancel"
        appendUniqueGroupId(groupIds, listGroupId)
        appendUniqueGroupId(groupIds, self.view.btnBack.groupId)
    else
        self.view.btnBack.hintTextId = "key_hint_common_back"
        appendUniqueGroupId(groupIds, self.view.btnBack.groupId)
        if cur and cur ~= header then
            for _, id in ipairs(detailCtrl:_GetContentFocusHintGroupIds()) do
                appendUniqueGroupId(groupIds, id)
            end
        end
    end
    return groupIds
end

ForesightCharGrowthMainCtrl._RefreshControllerHints = HL.Method() << function(self)
    if not DeviceInfo.usingController or self.m_refreshingControllerHints then
        return
    end
    if self.m_itemTipsHidesControllerHint then
        return
    end
    if self.view.tabRow and self.m_detailCtrl.m_isPanelActive then
        InputManagerInst:ToggleGroup(self.view.tabRow.groupId, true)
    end
    self.m_refreshingControllerHints = true
    local placeholder = self.view.controllerHintPlaceholder
    if placeholder then
        placeholder:InitControllerHintPlaceholder(self:_BuildMainControllerHintGroupIds())
    end
    self.m_refreshingControllerHints = false
end



ForesightCharGrowthMainCtrl._InitSortNode = HL.Method(HL.Boolean, HL.Opt(HL.Number)) << function(self, isIncremental, csSortIndex)
    if not self.view.sortNode then
        return
    end
    local sortOption = {
        {
            name = Language.LUA_CHAR_SORT_1,
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "level", "rarity", "sortOrder", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "level", "rarity", "sortOrder", "templateId" },
        },
        {
            name = Language.LUA_CHAR_SORT_2,
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "ownTime", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "ownTime", "templateId" },
        },
        {
            name = Language.LUA_CHAR_SORT_3,
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "rarity", "level", "sortOrder", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "rarity", "level", "sortOrder", "templateId" },
        },
    }
    self.view.sortNode:InitSortNode(sortOption, function(optData, incremental)
        self:_OnSortChanged(optData, incremental)
    end, csSortIndex, isIncremental, true, self.view.filterBtn)
end

ForesightCharGrowthMainCtrl._InitFilterNode = HL.Method() << function(self)
    if not self.view.filterBtn then
        return
    end
    self.view.filterBtn:InitFilterBtn({
        tagGroups = FilterUtils.generateConfig_CHAR_FORMATION(),
        onConfirm = function(tags)
            self:_OnFilterConfirm(tags)
        end,
        selectedTags = self.m_filterTags,
        getResultCount = function(tags)
            return self:_FilterBtnGetResCount(tags)
        end,
        sortNodeWidget = self.view.sortNode,
    })
end

ForesightCharGrowthMainCtrl._FilterCharList = HL.Method() << function(self)
    if not self.m_charInfoList then
        return
    end
    if self.m_filterTags == nil then
        self.m_filteredCharList = self.m_charInfoList
    else
        local phase = PhaseForesightCharGrowth.Get()
        self.m_filteredCharList = {}
        for _, charInfo in ipairs(self.m_charInfoList) do
            if phase:IsCharPinned(charInfo.templateId) or self:_CharMatchesFilterTags(charInfo.templateId, self.m_filterTags) then
                table.insert(self.m_filteredCharList, charInfo)
            end
        end
    end
    local hasListChars = #self.m_filteredCharList > 0
    self.view.emptyNode.gameObject:SetActive(not hasListChars)
    if not hasListChars then
        self.view.charScrollList:UpdateGroup(2, -1)
        local emptyRt = self.view.emptyNode.transform
        CS.UnityEngine.Canvas.ForceUpdateCanvases()
        local containerH = self.view.container.rect.height
        if self.view.charScrollList.transform.rect.height - containerH - 30 <= 0 then
            self.view.emptyNode.gameObject:SetActive(false)
            self.view.charScrollList:UpdateGroup(2, -1, false, false, true)
        else
            emptyRt.anchorMin = Vector2(0, 0)
            emptyRt.anchorMax = Vector2(1, 1)
            emptyRt.offsetMin = Vector2(emptyRt.offsetMin.x, 30)
            emptyRt.offsetMax = Vector2(emptyRt.offsetMax.x, -containerH)
        end
    end
    local scrollRect = self.view.charScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    if scrollRect then
        scrollRect.vertical = not self.view.emptyNode.gameObject.activeSelf
        scrollRect.disableScroll = self.view.emptyNode.gameObject.activeSelf
    end
end

ForesightCharGrowthMainCtrl._FilterBtnGetResCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if tags == nil or #tags == 0 or not self.m_charInfoList then
        return 0
    end
    local count = 0
    for _, charInfo in ipairs(self.m_charInfoList) do
        if self:_CharMatchesFilterTags(charInfo.templateId, tags) then
            count = count + 1
        end
    end
    return count
end



ForesightCharGrowthMainCtrl._ApplySelectionFromArg = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    arg = arg or {}
    if arg.resetSelection then
        self.m_selectedChar = {}
        self.m_frozenListScrollY = -1
        self.m_args.resetSelection = nil
    elseif arg.selectedGachaCharTemplateId then
        self.m_selectedChar = {["gacha"] = { templateId = arg.selectedGachaCharTemplateId }}
    elseif arg.selectedCharTemplateId then
        self.m_selectedChar = {["list"] = { templateId = arg.selectedCharTemplateId }}
    end
end

ForesightCharGrowthMainCtrl._GetActiveSelectionRegion = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    local s = self.m_selectedChar
    if s and s.gacha then
        return "gacha"
    end
    if s and s.list then
        return "list"
    end
end

ForesightCharGrowthMainCtrl._IsRegionCellSelected = HL.Method(HL.String, HL.String).Return(HL.Boolean) << function(self, region, templateId)
    local selected = self.m_selectedChar and self.m_selectedChar[region]
    return selected ~= nil and selected.templateId == templateId
end

ForesightCharGrowthMainCtrl._FindCharInfoInRegion = HL.Method(HL.String, HL.String).Return(HL.Table) << function(self, region, templateId)
    local sourceList = region == "gacha" and self.m_gachaPreviewList or self.m_filteredCharList
    for _, info in ipairs(sourceList or {}) do
        if info.templateId == templateId then
            return info
        end
    end
    return nil
end

ForesightCharGrowthMainCtrl._FinalizeSelection = HL.Method() << function(self)
    local state = self.m_selectedChar
    local region = self:_GetActiveSelectionRegion()
    if region then
        local selected = state[region]
        local info = self:_FindCharInfoInRegion(region, selected.templateId)
        if info then
            selected.instId = info.instId
            return
        end
        state[region] = nil
    end
    if self.m_filteredCharList and #self.m_filteredCharList > 0 then
        local info = self.m_filteredCharList[1]
        state.list = { templateId = info.templateId, instId = info.instId }
        state.gacha = nil
        return
    end
    if self.m_gachaPreviewList and #self.m_gachaPreviewList > 0 then
        local info = self.m_gachaPreviewList[1]
        state.gacha = { templateId = info.templateId, instId = info.instId }
        state.list = nil
        return
    end
    state.gacha = nil
    state.list = nil
end

ForesightCharGrowthMainCtrl._SyncSortFilterUIFromArgs = HL.Method() << function(self)
    local arg = self.m_args
    if not arg or (arg.sortSelectedIndex == nil and arg.filterTags == nil) then
        return
    end
    local sortNode = self.view.sortNode
    if sortNode and arg.sortSelectedIndex ~= nil
        and sortNode.m_sortOptions and sortNode.view and sortNode.view.mobilePCNode
        and sortNode.view.mobilePCNode.dropDown then
        local optionCount = #sortNode.m_sortOptions
        if optionCount > 0 then
            local sortSelectedIndex = math.max(1, math.min(arg.sortSelectedIndex, optionCount))
            sortNode.isIncremental = arg.sortIsIncremental == true
            sortNode:RefreshIncremental()
            sortNode.view.mobilePCNode.dropDown:SetSelected(CSIndex(sortSelectedIndex), true, false)
        end
    end
    if self.view.filterBtn and self.view.filterBtn.m_args and self.m_filterTags ~= nil then
        self.view.filterBtn.m_args.selectedTags = lume.deepCopy(self.m_filterTags)
        if self.view.filterBtn.m_args.onConfirm then
            self.view.filterBtn.m_args.onConfirm(self.m_filterTags)
        else
            self.view.filterBtn:_UpdateState(self.m_filterTags)
        end
    elseif sortNode then
        sortNode:OnSortChanged()
    end
    if sortNode then
        sortNode:UpdateDeviceState()
    end
end

ForesightCharGrowthMainCtrl._LayeredSort = HL.Method(HL.Table, HL.Function).Return(HL.Table) << function(self, sourceList, sortFn)
    local phase = PhaseForesightCharGrowth.Get()
    local buckets = { {}, {}, {}, {} }
    for _, item in ipairs(sourceList or {}) do
        local isPinned = item.templateId and not item.isForesight and phase:IsCharPinned(item.templateId)
        local bucketIndex
        if isPinned then
            bucketIndex = item.isOwned and 1 or 2
        else
            bucketIndex = item.isOwned and 3 or 4
        end
        table.insert(buckets[bucketIndex], item)
    end
    local result = {}
    for i = 1, 4 do
        table.sort(buckets[i], sortFn)
        for _, item in ipairs(buckets[i]) do
            table.insert(result, item)
        end
    end
    return result
end


ForesightCharGrowthMainCtrl._CharMatchesFilterTags = HL.Method(HL.String, HL.Table).Return(HL.Boolean) << function(self, templateId, tags)
    local tagsByFuncName = {}
    for _, tag in ipairs(tags) do
        local list = tagsByFuncName[tag.funcName]
        if not list then
            list = {}
            tagsByFuncName[tag.funcName] = list
        end
        table.insert(list, tag)
    end
    for funcName, tagList in pairs(tagsByFuncName) do
        local passOne = false
        for _, tag in ipairs(tagList) do
            if FilterUtils[funcName](templateId, tag.param) then
                passOne = true
                break
            end
        end
        if not passOne then
            return false
        end
    end
    return true
end

ForesightCharGrowthMainCtrl._BuildCharHeadCellExtraParams = HL.Method(HL.Table).Return(HL.Table) << function(self, info)
    local growthLabelState
    if info.isForesight == true then
        local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(info.templateId)
        growthLabelState = (ok and not string.isEmpty(cfg.activityId)) and "PreActivity" or "Preview"
    elseif info.previewTag == "activity" then
        growthLabelState = "Activity"
    elseif info.previewTag == "replica" then
        growthLabelState = "NoPreview"
    elseif info.previewTag == "rerun" then
        growthLabelState = "Reissue"
    elseif info.isInCurGachaPool == true or info.previewTag == "current" then
        growthLabelState = "Current"
    end
    if growthLabelState == "Preview" or growthLabelState == "NoPreview" then
        local poolId = PhaseForesightCharGrowth.Get():FindCharGachaPoolId(info.templateId)
        if not string.isEmpty(poolId) then
            local ok, poolCfg = Tables.gachaCharPoolTable:TryGetValue(poolId)
            growthLabelState = (ok and poolCfg.type == GEnums.CharacterGachaPoolType.Rerun) and "Reissue" or "Current"
        end
    end
    local showPinned = info.isForesight ~= true
        and not string.isEmpty(info.templateId)
        and PhaseForesightCharGrowth.Get():IsCharPinned(info.templateId)
    return {
        source = "ForesightCharGrowthMain",
        growthLabelState = growthLabelState,
        showPinned = showPinned,
        showNotOwn = info.isOwned ~= true,
    }
end

ForesightCharGrowthMainCtrl._InitListCell = HL.Method(HL.Forward("CharFormationHeadCell"), HL.Table, HL.String, HL.Opt(HL.Function)) << function(self, cell, info, region, onClick)
    local view = cell.view
    local templateId = info.templateId
    local isForesight = info.isForesight == true
    local characterData
    if isForesight then
        local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(templateId)
        if ok then
            characterData = cfg
        end
    end
    if not characterData then
        characterData = Tables.characterTable:GetValue(templateId)
    end
    local level = info.level or 1
    local instId = (not isForesight) and info.isOwned and info.instId or nil
    view.imageChar:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. templateId)
    view.charElementIcon:InitCharTypeIcon(characterData.charTypeId)
    view.imagePro:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, CharInfoUtils.getCharProfessionIconName(characterData.profession, true))
    local rarityColor = UIUtils.getCharRarityColor(isForesight and (info.rarity or 6) or characterData.rarity)
    if rarityColor then
        view.rarityColor.color = rarityColor
    end
    view.textLv.text = string.format("%02d", level)
    if instId then
        view.simplePotentialStar:InitCharSimplePotentialStar(instId)
    else
        view.simplePotentialStar:InitWeaponSimplePotentialStar(-1)
    end
    view.button.onClick:RemoveAllListeners()
    view.button.onClick:AddListener(function()
        if onClick then
            onClick()
        end
    end)
    self:_SetupListCellControllerInput(view.button)

    local extra = self:_BuildCharHeadCellExtraParams(info)
    if region == "list" then
        extra.growthLabelState = nil
        local stageId = self.m_charId2finishStageId[templateId]
        local labelState = stageId and PhaseForesightCharGrowth.Get():GetCultivateStageIconState(stageId) or nil
        local labelImg = view.labelImg
        if labelImg then
            local showLabel = not string.isEmpty(labelState)
            labelImg.gameObject:SetActive(showLabel)
            if showLabel and labelImg.SetState then
                labelImg:SetState(labelState)
            end
        end
    else
        extra.showPinned = false
        if view.labelImg then
            view.labelImg.gameObject:SetActive(false)
        end
    end
    cell:RefreshForesightCharGrowthMainExtra(extra)
end


HL.Commit(ForesightCharGrowthMainCtrl)
