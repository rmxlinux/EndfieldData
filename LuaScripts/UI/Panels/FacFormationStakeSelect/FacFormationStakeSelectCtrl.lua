local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacFormationStakeSelect

local BUILDING_ID_MAGIC_SPAWNER_1 = "magic_spawner_1"
local BUILDING_ID_MAGIC_SPAWNER_2 = "magic_spawner_2"

local SLOT_STATE = {
    Top = "Top",
    Middle = "Middle",
    Bottom = "Bottom",
}

local DECO_STATE = {
    NotActivated = "NotActivated",
    Available = "Available",
    Closed = "Closed",
    NoElectricity = "NoElectricity",
    NoNetWork = "NoNetWork",
}

FacFormationStakeSelectCtrl = HL.Class('FacFormationStakeSelectCtrl', uiCtrl.UICtrl)

FacFormationStakeSelectCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FormationStake)

FacFormationStakeSelectCtrl.m_slotState = HL.Field(HL.String) << ""

FacFormationStakeSelectCtrl.m_csSlotIndex = HL.Field(HL.Number) << -1

FacFormationStakeSelectCtrl.m_nodeId = HL.Field(HL.Number) << -1

FacFormationStakeSelectCtrl.m_buildingId = HL.Field(HL.String) << ""

FacFormationStakeSelectCtrl.m_originalFormationId = HL.Field(HL.String) << ""

FacFormationStakeSelectCtrl.m_selectedFormationId = HL.Field(HL.String) << ""

FacFormationStakeSelectCtrl.s_messages = HL.StaticField(HL.Table) << {
}








FacFormationStakeSelectCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    self.m_slotState = arg.slotState
    self.m_nodeId = self.m_uiInfo.nodeId
    self.m_buildingId = self.m_uiInfo.buildingId
    self.m_csSlotIndex = self:_ResolveSlotIndex()
    self.m_originalFormationId = self:_GetSelectedFormationIdFromUIInfo()
    self.m_selectedFormationId = self.m_originalFormationId
    if arg.selectedFormationId ~= nil then
        self.m_selectedFormationId = arg.selectedFormationId
    end
    self.view.main:SetState(self.m_slotState)

    self:_InitButtonEvents()
    self:_RefreshSelectableFormationNodes()
    self:_RefreshSelectedMagicNode()
    self:_RefreshConsumeDecoState()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

FacFormationStakeSelectCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        slotState = self.m_slotState,
        selectedFormationId = self.m_selectedFormationId,
    }
end

FacFormationStakeSelectCtrl._ResolveSlotIndex = HL.Method().Return(HL.Number) << function(self)
    if self.m_buildingId == BUILDING_ID_MAGIC_SPAWNER_2 and self.m_slotState == SLOT_STATE.Bottom then
        return 1
    end

    return 0
end

FacFormationStakeSelectCtrl._InitButtonEvents = HL.Method() << function(self)
    self.view.closeBtn.onClick:RemoveAllListeners()
    self.view.closeBtn.onClick:AddListener(function()
        if self:IsPlayingAnimationOut() then
            return
        end
        self:PlayAnimationOutAndClose()
    end)

    self.view.clearBtn.onClick:RemoveAllListeners()
    self.view.clearBtn.onClick:AddListener(function()
        self.m_selectedFormationId = ""
        self.view.facFormationStakeSelectNode01.selectedBG.gameObject:SetActiveIfNecessary(false)
        self.view.facFormationStakeSelectNode02.selectedBG.gameObject:SetActiveIfNecessary(false)
        self:_RefreshSelectedMagicNode()
    end)

    self.view.confirmBtn.onClick:RemoveAllListeners()
    self.view.confirmBtn.onClick:AddListener(function()
        self:_OnClickConfirmBtn()
    end)
end

FacFormationStakeSelectCtrl._GetSelectedFormationIdFromUIInfo = HL.Method().Return(HL.String) << function(self)
    local formationStake = self.m_uiInfo.formationStake
    local selectedFormations = formationStake.selectedFormations
    if self.m_csSlotIndex < selectedFormations.Count then
        return selectedFormations[self.m_csSlotIndex]
    end

    return ""
end

FacFormationStakeSelectCtrl._RefreshSelectedMagicNode = HL.Method() << function(self)
    local magicNode = self:_GetMagicNode()
    if string.isEmpty(self.m_selectedFormationId) then
        magicNode:InitFacMagicNodeByEmpty()
    else
        magicNode:InitFacMagicNodeByTableId(self.m_selectedFormationId)
    end

    
    for _, node in ipairs({ self.view.facFormationStakeSelectNode01, self.view.facFormationStakeSelectNode02 }) do
        if node.gameObject.activeSelf then
            node.button:ChangeActionOnSetNaviTarget(node.selectedBG.gameObject.activeSelf and
                CS.Beyond.Input.ActionOnSetNaviTarget.None or CS.Beyond.Input.ActionOnSetNaviTarget.PressConfirmTriggerOnClick)
            InputManagerInst:SetBindingText(node.button.hoverConfirmBindingId, string.isEmpty(self.m_selectedFormationId) and
                Language["key_hint_magic_spawner_select"] or Language.LUA_FAC_FORMATION_STAKE_CHANGE_HINT)
        end
    end
end

FacFormationStakeSelectCtrl._RefreshSelectableFormationNodes = HL.Method() << function(self)
    local inBlackbox = Utils.isInBlackbox()
    local formationStakeCfg = Tables.factoryFormationStakeTable:GetValue(self.m_buildingId)
    local selectableFormationIds
    if inBlackbox then
        local predefinedParam = self.m_uiInfo.nodeHandler.predefinedParam
        local formationStake = predefinedParam and predefinedParam.formationStake
        selectableFormationIds = formationStake and formationStake.selectableFormationIds
    else
        selectableFormationIds = formationStakeCfg.selectableFormationIds
    end

    local unlockedFormationIds = {}
    if selectableFormationIds == nil then
        self:_RefreshSelectableFormationNode(self.view.facFormationStakeSelectNode01, "")
        self:_RefreshSelectableFormationNode(self.view.facFormationStakeSelectNode02, "")
        return
    end
    for index = 0, selectableFormationIds.Count - 1 do
        local formationId = selectableFormationIds[index]
        local isSelectable
        if inBlackbox then
            
            isSelectable = lume.find(formationStakeCfg.selectableFormationIds, formationId) ~= nil
        else
            isSelectable = FactoryUtils.isFormationUnlockTechUnlocked(formationId)
        end
        if isSelectable then
            table.insert(unlockedFormationIds, formationId)
        end
    end
    self:_RefreshSelectableFormationNode(self.view.facFormationStakeSelectNode01, unlockedFormationIds[1] or "")
    self:_RefreshSelectableFormationNode(self.view.facFormationStakeSelectNode02, unlockedFormationIds[2] or "")
end

FacFormationStakeSelectCtrl._RefreshSelectableFormationNode = HL.Method(HL.Any, HL.String) << function(self, node, formationId)
    local hasFormation = not string.isEmpty(formationId)
    node.gameObject:SetActiveIfNecessary(hasFormation)
    node.selectedBG.gameObject:SetActiveIfNecessary(hasFormation and formationId == self.m_selectedFormationId)
    if not hasFormation then
        return
    end

    node.stateController:SetState("Nrl")
    node.facMagicNode03:InitFacMagicNodeByTableId(formationId)

    local hasCfg, cfg = Tables.factoryFormationTable:TryGetValue(formationId)
    if hasCfg then
        node.nameTxt.text = cfg.name
        node.infoTxt.text = cfg.desc
    else
        node.nameTxt.text = ""
        node.infoTxt.text = ""
    end

    node.button.onClick:RemoveAllListeners()
    node.button.onClick:AddListener(function()
        self.m_selectedFormationId = formationId
        self.view.facFormationStakeSelectNode01.selectedBG.gameObject:SetActiveIfNecessary(node == self.view.facFormationStakeSelectNode01)
        self.view.facFormationStakeSelectNode02.selectedBG.gameObject:SetActiveIfNecessary(node == self.view.facFormationStakeSelectNode02)
        self:_RefreshSelectedMagicNode()
    end)
end

FacFormationStakeSelectCtrl._OnClickConfirmBtn = HL.Method() << function(self)
    if self.m_selectedFormationId == self.m_originalFormationId then
        self:PlayAnimationOutAndClose()
        return
    end

    self.m_uiInfo.sender:Message_OpSetFormation(Utils.getCurrentChapterId(), self.m_nodeId, self.m_csSlotIndex, self.m_selectedFormationId, function(_, opRet)
        if opRet.RetCode ~= CS.Proto.FACTORY_OP_RET_CODE.Ok then
            return
        end

        if not UIManager:IsOpen(PANEL_ID) then
            return
        end

        self.m_uiInfo:Update()
        Notify(MessageConst.FAC_REFRESH_FORMATION_STAKE)
        self:PlayAnimationOutAndClose()
    end)
end

FacFormationStakeSelectCtrl._RefreshConsumeDecoState = HL.Method() << function(self)
    local isBottomSlot = self.m_slotState == SLOT_STATE.Bottom
    self.view.consumeDecoStateRight.gameObject:SetActiveIfNecessary(not isBottomSlot)
    self.view.consumeDecoStateBottom.gameObject:SetActiveIfNecessary(isBottomSlot)

    local decoStateController = self:_GetConsumeDecoStateController()
    local buildingState = FactoryUtils.getBuildingStateType(self.m_nodeId)
    if buildingState == GEnums.FacBuildingState.NoPower then
        decoStateController:SetState(DECO_STATE.NoElectricity)
    elseif buildingState == GEnums.FacBuildingState.NotInPowerNet then
        decoStateController:SetState(DECO_STATE.NoNetWork)
    elseif buildingState == GEnums.FacBuildingState.Closed then
        decoStateController:SetState(DECO_STATE.Closed)
    elseif buildingState == GEnums.FacBuildingState.InActive then
        decoStateController:SetState(DECO_STATE.NotActivated)
    else
        decoStateController:SetState(DECO_STATE.Available)
    end
end

FacFormationStakeSelectCtrl._GetConsumeDecoStateController = HL.Method().Return(HL.Any) << function(self)
    if self.m_slotState == SLOT_STATE.Bottom then
        return self.view.consumeDecoStateBottom
    end

    return self.view.consumeDecoStateRight
end

FacFormationStakeSelectCtrl._GetMagicNode = HL.Method().Return(HL.Any) << function(self)
    if self.m_slotState == SLOT_STATE.Top then
        return self.view.facMagicNode01
    elseif self.m_slotState == SLOT_STATE.Bottom then
        return self.view.facMagicNode02
    end

    return self.view.facMagicNode03
end

HL.Commit(FacFormationStakeSelectCtrl)
