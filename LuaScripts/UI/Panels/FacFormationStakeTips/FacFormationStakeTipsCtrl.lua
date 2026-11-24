local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacFormationStakeTips

local FormationZoneTypes = CS.Beyond.Gameplay.Factory.FormationZoneTypes
local FormationZoneRuntimeState = CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationZoneRuntimeState
local FormationStakeSlotListType = CS.System.Collections.Generic.List(
    CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationStakeSlot)

FacFormationStakeTipsCtrl = HL.Class('FacFormationStakeTipsCtrl', uiCtrl.UICtrl)

FacFormationStakeTipsCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FormationStake)
FacFormationStakeTipsCtrl.m_unitId = HL.Field(HL.Any)
FacFormationStakeTipsCtrl.m_csSlotIndex = HL.Field(HL.Number) << -1
FacFormationStakeTipsCtrl.m_stakeSlots = HL.Field(HL.Any)
FacFormationStakeTipsCtrl.m_formationCells = HL.Field(HL.Forward('UIListCache'))
FacFormationStakeTipsCtrl.m_formationZoneData = HL.Field(HL.Any)

FacFormationStakeTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
}

FacFormationStakeTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    self.m_csSlotIndex = arg.csSlotIndex
    self.m_unitId = CS.Beyond.Gameplay.Factory.ExternalPortal.GetUnitId(Utils.getCurrentChapterId(), self.m_uiInfo.nodeId)
    self.m_stakeSlots = FormationStakeSlotListType()
    self.m_formationCells = UIUtils.genCellCache(self.view.formationCell, function(item)
        return item.transform:GetComponent("UIStateController")
    end)

    local closeFunc = function()
        if self:IsPlayingAnimationOut() then
            return
        end
        self:PlayAnimationOutAndClose()
    end

    self.view.closeMaskBtn.onClick:RemoveAllListeners()
    self.view.closeMaskBtn.onClick:AddListener(closeFunc)
    self.view.content.onTriggerAutoClose:RemoveAllListeners()
    self.view.content.onTriggerAutoClose:AddListener(closeFunc)
    self.view.detailsBtn.onClick:RemoveAllListeners()
    self.view.detailsBtn.onClick:AddListener(function()
        self:_OpenFormationFormula()
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:BindInputPlayerAction("common_cancel", closeFunc)
    self:_RefreshContent()
    UIUtils.updateTipsPosition(self.view.content.transform, arg.transform, self.view.rectTransform, self.uiCamera,
        UIConst.UI_TIPS_POS_TYPE.FacFormationStakeTips, nil,
        self.view.config.TIPS_X_OFFSET, self.view.config.TIPS_Y_OFFSET)
end

FacFormationStakeTipsCtrl.ShowFacFormationStakeTips = HL.StaticMethod(HL.Table) << function(args)
    UIManager:AutoOpen(PANEL_ID, args)
end

FacFormationStakeTipsCtrl._RefreshContent = HL.Method() << function(self)
    local zoneQuery = GameInstance.remoteFactoryManager.formationZoneQuery
    local hasZone, zone = zoneQuery:TryGetZoneForStake(self.m_unitId, self.m_csSlotIndex)
    if hasZone and zone.runtimeState ~= FormationZoneRuntimeState.UNSELECTED then
        self.m_formationZoneData = zone
        zoneQuery:QueryFormationStakeSlotsInZone(zone.cube, self.m_stakeSlots)
    else
        self.m_formationZoneData = nil
        self.m_stakeSlots:Clear()
    end

    local sortedSlots = {}
    for i = 0, self.m_stakeSlots.Count - 1 do
        local slot = self.m_stakeSlots[i]
        table.insert(sortedSlots, {
            slot = slot,
            sortIndex = FactoryUtils.getFormationStakeSlotSortIndex(slot),
            originalIndex = i,
            isSelf = slot.unitId == self.m_unitId and slot.slotIndex == self.m_csSlotIndex,
        })
    end
    for i = self.m_stakeSlots.Count + 1, FactoryUtils.FORMATION_STAKE_SLOT_COUNT do
        table.insert(sortedSlots, {
            sortIndex = FactoryUtils.getFormationStakeSlotSortIndex(),
            originalIndex = i,
            isSelf = false,
        })
    end
    table.sort(sortedSlots, function(a, b)
        if a.isSelf ~= b.isSelf then
            return a.isSelf
        end
        if a.sortIndex == b.sortIndex then
            return a.originalIndex < b.originalIndex
        end
        return a.sortIndex < b.sortIndex
    end)

    self.m_formationCells:Refresh(#sortedSlots, function(cell, index)
        local slot = sortedSlots[index].slot
        cell:SetState(FactoryUtils.getFormationStakeSlotCellState(slot))
        if slot ~= nil and slot.unitId == self.m_unitId and slot.slotIndex == self.m_csSlotIndex then
            cell:SetState(FactoryUtils.FORMATION_STAKE_SLOT_CELL_STATE_SELECT)
        end
    end)

    for i = 1, FactoryUtils.FORMATION_STAKE_SLOT_COUNT do
        local node = self.view["facMagicNode" .. i]
        local slot = sortedSlots[i].slot
        if slot == nil then
            node:InitFacMagicNodeByEmpty()
        else
            node:InitFacMagicNodeByInst({ slot = slot })
        end
    end

    if self.m_formationZoneData == nil or self.m_formationZoneData.resolvedType == FormationZoneTypes.NONE then
        self.view.facMagicRightNode:InitFacMagicNodeByEmpty()
        return
    end
    self.view.facMagicRightNode:InitFacMagicNodeByInst({
        formationId = FactoryUtils.FORMATION_ID_BY_ZONE_TYPE[self.m_formationZoneData.resolvedType],
        runtimeState = self.m_formationZoneData.runtimeState,
        level = self.m_formationZoneData.level,
    })
end

FacFormationStakeTipsCtrl._OpenFormationFormula = HL.Method() << function(self)
    local formationList = self.m_uiInfo.formationStake.selectedFormations
    local selectedFormation = {}
    local effectForamtion = {}
    local zoneQuery = GameInstance.remoteFactoryManager.formationZoneQuery
    for i = 0, formationList.Count - 1 do
        selectedFormation[formationList[i]] = true
        local hasZone, zone = zoneQuery:TryGetZoneForStake(self.m_unitId, i)
        if hasZone and zone.resolvedType ~= FormationZoneTypes.NONE then
            effectForamtion[FacConst.FAC_FORMATION_ZONE_TYPE_TO_ID[zone.resolvedType]] = zone.level
        end
    end
    UIManager:AutoOpen(PanelId.FormationFormula, {
        buildingId = self.m_uiInfo.buildingId,
        selectedFormation = selectedFormation,
        effectForamtion = effectForamtion,
        nodeHandler = self.m_uiInfo.nodeHandler,
    })
    self:PlayAnimationOutAndClose()
end

HL.Commit(FacFormationStakeTipsCtrl)
