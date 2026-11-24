local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local FormationZoneTypes = CS.Beyond.Gameplay.Factory.FormationZoneTypes
local FormationZoneRuntimeState = CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationZoneRuntimeState
local FormationStakeSlotListType = CS.System.Collections.Generic.List(
    CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationStakeSlot)

local STATE_DESCRIBE = "Describe"
local STATE_SHOW = "Show"

FacFormationStakeNode = HL.Class('FacFormationStakeNode', UIWidgetBase)

FacFormationStakeNode.m_stakeSlots = HL.Field(HL.Any)
FacFormationStakeNode.m_formationCells = HL.Field(HL.Forward('UIListCache'))
FacFormationStakeNode.m_formationLevel = HL.Field(HL.Number) << 0
FacFormationStakeNode.m_formationZoneData = HL.Field(HL.Any)
FacFormationStakeNode.m_describeShowTipsBindingId = HL.Field(HL.Number) << -1
FacFormationStakeNode.m_showShowTipsBindingId = HL.Field(HL.Number) << -1

FacFormationStakeNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.checkBtn.onIsNaviTargetChanged = function(isTarget)
        self.view.hideRoot.gameObject:SetActiveIfNecessary(not isTarget)
    end
end

FacFormationStakeNode.RefreshFacFormationStakeNode = HL.Method(HL.Any, HL.Number, HL.String, HL.String) << function(self, uiInfo, csSlotIndex, formationId, slotState)
    self:_FirstTimeInit()
    self.m_stakeSlots = self.m_stakeSlots or FormationStakeSlotListType()
    self.m_formationCells = self.m_formationCells or UIUtils.genCellCache(self.view.formationCell)

    local unitId = CS.Beyond.Gameplay.Factory.ExternalPortal.GetUnitId(Utils.getCurrentChapterId(), uiInfo.nodeId)
    self.m_stakeSlots:Clear()
    self.m_formationLevel = 0
    self.m_formationZoneData = nil
    if not string.isEmpty(formationId) then
        local zoneQuery = GameInstance.remoteFactoryManager.formationZoneQuery
        local hasZone, zone = zoneQuery:TryGetZoneForStake(unitId, csSlotIndex)
        if hasZone and zone.runtimeState ~= FormationZoneRuntimeState.UNSELECTED then
            self.m_formationLevel = zone.level
            self.m_formationZoneData = zone
            zoneQuery:QueryFormationStakeSlotsInZone(zone.cube, self.m_stakeSlots)
        end
    end
    self.view.stateController:SetState(self:_GetFormationNodeState(formationId))
    local selectedSlot
    for i = 0, self.m_stakeSlots.Count - 1 do
        local slot = self.m_stakeSlots[i]
        if slot.unitId == unitId and slot.slotIndex == csSlotIndex then
            selectedSlot = slot
            break
        end
    end
    
    local isActive = selectedSlot ~= nil and selectedSlot.countsForLevel
        and selectedSlot.stakeState == GEnums.FacBuildingState.Normal
        and self.m_formationZoneData.runtimeState == FormationZoneRuntimeState.NORMAL
    local animName = isActive and "facformationnode_loop" or "facformationnode_default"
    if self.view.formationAnimation.curStateName ~= animName then
        self.view.formationAnimation:PlayWithTween(animName)
    end

    local predefinedParam = uiInfo.nodeHandler.predefinedParam
    local formationStake = predefinedParam and predefinedParam.formationStake
    local slots = formationStake and formationStake.slots
    local predefinedSlot = slots and csSlotIndex < slots.Count and slots[csSlotIndex]
    if predefinedSlot and predefinedSlot.isLocked then
        self.view.facMagicNodeDescribe:InitFacMagicNodeByLockTableId(formationId, true)
    else
        self.view.facMagicNodeDescribe:InitFacMagicNodeByInst({
            slot = selectedSlot,
            formationId = formationId,
            level = 1,
        }, true)
    end
    local zoneInst
    if self.m_formationZoneData ~= nil and self.m_formationZoneData.resolvedType ~= FormationZoneTypes.NONE then
        zoneInst = {
            formationId = FactoryUtils.FORMATION_ID_BY_ZONE_TYPE[self.m_formationZoneData.resolvedType],
            runtimeState = self.m_formationZoneData.runtimeState,
            level = self.m_formationLevel,
        }
    end
    self.view.facMagicNodeShow:InitFacMagicNodeByInst(zoneInst, true)
    
    local selectHint = string.isEmpty(formationId) and Language.LUA_FAC_FORMATION_STAKE_SELECT_HINT
        or Language.LUA_FAC_FORMATION_STAKE_CHANGE_HINT
    self.view.facMagicNodeDescribe.view.button.customBindingViewLabelText = selectHint
    self.view.facMagicNodeShow.view.button.customBindingViewLabelText = selectHint
    self:_RefreshFormationCells(unitId, csSlotIndex)
    self:_BindOpenSelectPanel(self.view.facMagicNodeDescribe, uiInfo, slotState, csSlotIndex)
    self:_BindOpenSelectPanel(self.view.facMagicNodeShow, uiInfo, slotState, csSlotIndex)
    self.view.checkBtn.onClick:RemoveAllListeners()
    local showTips = function()
        UIManager:AutoOpen(PanelId.FacFormationStakeTips, {
            uiInfo = uiInfo,
            csSlotIndex = csSlotIndex,
            transform = self.view.checkBtn.transform,
        })
    end
    self.view.checkBtn.onClick:AddListener(showTips)
    
    InputManagerInst:DeleteBinding(self.m_describeShowTipsBindingId)
    InputManagerInst:DeleteBinding(self.m_showShowTipsBindingId)
    self.m_describeShowTipsBindingId = -1
    self.m_showShowTipsBindingId = -1
    if self.view.checkBtn.gameObject.activeInHierarchy then
        self.m_describeShowTipsBindingId = InputManagerInst:CreateBindingByActionId(
            "fac_formation_stake_show_stacking_tips", showTips, self.view.facMagicNodeDescribe.view.button.hoverBindingGroupId)
        self.m_showShowTipsBindingId = InputManagerInst:CreateBindingByActionId(
            "fac_formation_stake_show_stacking_tips", showTips, self.view.facMagicNodeShow.view.button.hoverBindingGroupId)
        InputManagerInst:SetBindingView(self.m_describeShowTipsBindingId, self.view.checkBtn)
        InputManagerInst:SetBindingView(self.m_showShowTipsBindingId, self.view.checkBtn)
    end
end

FacFormationStakeNode._OnDestroy = HL.Override() << function(self)
    InputManagerInst:DeleteBinding(self.m_describeShowTipsBindingId)
    InputManagerInst:DeleteBinding(self.m_showShowTipsBindingId)
end

FacFormationStakeNode._BindOpenSelectPanel = HL.Method(HL.Any, HL.Any, HL.String, HL.Number) << function(self, node, uiInfo, slotState, csSlotIndex)
    if node == nil then
        return
    end

    node:SetFacMagicNodeButtonCallbacks(function()
        
        local predefinedParam = uiInfo.nodeHandler.predefinedParam
        local formationStake = predefinedParam and predefinedParam.formationStake
        local slots = formationStake and formationStake.slots
        local slot = slots and csSlotIndex < slots.Count and slots[csSlotIndex]
        if slot and slot.isLocked then
            local formationCfg = Tables.factoryFormationTable:GetValue(slot.selectedFormationId)
            local formationName = string.format(Language.LUA_FAC_FORMATION_BASE_NAME_FORMAT, formationCfg.attrName)
            Notify(MessageConst.SHOW_TOAST,
                string.format(Language.LUA_FAC_FORMATION_STAKE_LOCKED_TOAST_FORMAT, formationName))
            return
        end

        UIManager:AutoOpen(PanelId.FacFormationStakeSelect, {
            slotState = slotState,
            uiInfo = uiInfo,
        })
    end)
end

FacFormationStakeNode._GetFormationNodeState = HL.Method(HL.String).Return(HL.String) << function(self, formationId)
    if string.isEmpty(formationId) then
        return STATE_DESCRIBE
    end

    if self.m_formationZoneData == nil then
        return STATE_DESCRIBE
    end

    local formationCount = 0
    for i = 0, self.m_stakeSlots.Count - 1 do
        if self.m_stakeSlots[i].selectedType ~= FormationZoneTypes.NONE then
            formationCount = formationCount + 1
        end
    end
    return formationCount > 1 and STATE_SHOW or STATE_DESCRIBE
end

FacFormationStakeNode._RefreshFormationCells = HL.Method(HL.Any, HL.Number) << function(self, unitId, csSlotIndex)
    local sortedSlots = {}
    for i = 0, self.m_stakeSlots.Count - 1 do
        local slot = self.m_stakeSlots[i]
        table.insert(sortedSlots, {
            slot = slot,
            sortIndex = FactoryUtils.getFormationStakeSlotSortIndex(slot),
            originalIndex = i,
        })
    end
    for i = self.m_stakeSlots.Count + 1, FactoryUtils.FORMATION_STAKE_SLOT_COUNT do
        table.insert(sortedSlots, {
            sortIndex = FactoryUtils.getFormationStakeSlotSortIndex(),
            originalIndex = i,
        })
    end
    table.sort(sortedSlots, function(a, b)
        if a.sortIndex == b.sortIndex then
            return a.originalIndex < b.originalIndex
        end
        return a.sortIndex < b.sortIndex
    end)

    self.m_formationCells:Refresh(#sortedSlots, function(cell, index)
        local slot = sortedSlots[index].slot
        local animation = cell.animationWrapper
        local isActive = slot ~= nil and slot.selectedType ~= FormationZoneTypes.NONE
            and slot.countsForLevel and slot.stakeState == GEnums.FacBuildingState.Normal
        if not isActive then
            
            animation:SampleClip("facformationnode_loop01", 0)
        end
        cell.stateController:SetState(FactoryUtils.getFormationStakeSlotCellState(slot))
        if slot ~= nil and slot.unitId == unitId and slot.slotIndex == csSlotIndex then
            cell.stateController:SetState(FactoryUtils.FORMATION_STAKE_SLOT_CELL_STATE_SELECT)
        end
        if isActive and animation.curStateName ~= "facformationnode_loop01" then
            local startPlayTime = (#sortedSlots - index) * self.view.config.FORMATION_CELL_ANIM_OFFSET_PERCENT
                * animation:GetClipLength("facformationnode_loop01")
            animation:PlayWithTween("facformationnode_loop01", nil, CS.Beyond.UI.UIConst.AnimationState.Others, startPlayTime)
        end
    end)
end

HL.Commit(FacFormationStakeNode)
return FacFormationStakeNode
