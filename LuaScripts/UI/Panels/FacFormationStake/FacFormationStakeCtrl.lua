local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacFormationStake

local BUILDING_ID_MAGIC_SPAWNER_1 = "magic_spawner_1"
local BUILDING_ID_MAGIC_SPAWNER_2 = "magic_spawner_2"

local SMART_ALERT_FUNCTION_NAME_LIST = {
    "_CheckAlertFormationStakeInputInvalidGasCondition",
    "_CheckAlertActivatorCostInsufficientCondition",
}

local SLOT_STATE_TOP = "Top"
local SLOT_STATE_MIDDLE = "Middle"
local SLOT_STATE_BOTTOM = "Bottom"

local DECO_STATE = {
    NotActivated = "NotActivated",
    Available = "Available",
    Closed = "Closed",
    NoElectricity = "NoElectricity",
    NoNetWork = "NoNetWork",
}

local CONTENT_STATE_BY_BUILDING_ID = {
    [BUILDING_ID_MAGIC_SPAWNER_1] = BUILDING_ID_MAGIC_SPAWNER_1,
    [BUILDING_ID_MAGIC_SPAWNER_2] = BUILDING_ID_MAGIC_SPAWNER_2,
}

FacFormationStakeCtrl = HL.Class('FacFormationStakeCtrl', uiCtrl.UICtrl)

FacFormationStakeCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FormationStake)

FacFormationStakeCtrl.m_nodeId = HL.Field(HL.Number) << -1

FacFormationStakeCtrl.m_buildingId = HL.Field(HL.String) << ""

FacFormationStakeCtrl.m_updateThread = HL.Field(HL.Thread)





FacFormationStakeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.FAC_REFRESH_FORMATION_STAKE] = '_OnRefreshFormationStake',
}


FacFormationStakeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    self.m_nodeId = self.m_uiInfo.nodeId
    self.m_buildingId = self.m_uiInfo.buildingId

    self.view.buildingCommon:InitBuildingCommon(self.m_uiInfo, {
        smartAlertFuncNameList = SMART_ALERT_FUNCTION_NAME_LIST,
        targetCtrlInstance = self,
        onStateChanged = function(state)
            local animName = state == GEnums.FacBuildingState.Normal and "facformationstakeglow_in01" or "facformationstakeglow_default01"
            for i = 1, 3 do
                local animation = self.view["decoLine0" .. i .. "Animation"]
                if animation.curStateName ~= animName then
                    animation:PlayWithTween(animName)
                end
            end
            local glowAnimName = state == GEnums.FacBuildingState.Normal and "facformationstakeglow_in" or "facformationstakeglow_default"
            for i = 1, 2 do
                local animation = self.view["facFormationStakeNode0" .. i].view.glowAnimation
                if animation.curStateName ~= glowAnimName then
                    animation:PlayWithTween(glowAnimName)
                end
            end
        end,
    })
    self.view.facCachePipe:InitFacCachePipe(self.m_uiInfo, {
        useSinglePipe = true,
    })

    self:_InitFormula()
    self:_RefreshContent()
    
    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            local curConsumeCount = 0
            if self.m_uiInfo.activatorCost ~= nil then
                curConsumeCount = self.m_uiInfo.activatorCost.currentBufCnt * FacConst.FAC_RECENT_10S_COUNT_TO_MINUTE_RATE_SCALE
            end
            self.view.activatorPointer:RefreshConsumePointer(curConsumeCount)
            self.view.averageFlowNumTxt.text = curConsumeCount
        end
    end)

    if DeviceInfo.usingController then
        self:SetNaviTarget(self.view.facFormationStakeNode01.view.facMagicNodeDescribe.view.button)
    end
    
    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_nodeId)
end

FacFormationStakeCtrl.OnClose = HL.Override() << function(self)
    self.view.buildingCommon:ClearSmartAlertUpdate()
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_nodeId)
end

FacFormationStakeCtrl._InitFormula = HL.Method() << function(self)
    self.view.previewBtn.onClick:AddListener(function()
        local formationList = self.m_uiInfo.formationStake.selectedFormations
        local selectedFormation = {}
        local effectForamtion = {}
        local zoneQuery = GameInstance.remoteFactoryManager.formationZoneQuery
        local unitId = CS.Beyond.Gameplay.Factory.ExternalPortal.GetUnitId(Utils.getCurrentChapterId(), self.m_nodeId)
        for i = 0, formationList.Count - 1 do
            selectedFormation[formationList[i]] = true
            local hasZone, zone = zoneQuery:TryGetZoneForStake(unitId, i)
            if hasZone and zone.resolvedType ~= CS.Beyond.Gameplay.Factory.FormationZoneTypes.NONE then
                effectForamtion[FacConst.FAC_FORMATION_ZONE_TYPE_TO_ID[zone.resolvedType]] = zone.level
            end
        end
        UIManager:AutoOpen(PanelId.FormationFormula, {
            buildingId = self.m_buildingId,
            selectedFormation = selectedFormation,
            effectForamtion = effectForamtion,
            nodeHandler = self.m_uiInfo.nodeHandler,
        })
    end)
    self.view.previewBtn.onIsNaviTargetChanged = function(isTarget)
        self.view.hideRoot.gameObject:SetActiveIfNecessary(not isTarget)
    end
end

FacFormationStakeCtrl._RefreshContent = HL.Method() << function(self)
    self:_RefreshCommonContent()

    if self.m_buildingId == BUILDING_ID_MAGIC_SPAWNER_1 then
        self:_RefreshMagicSpawner1Content()
    elseif self.m_buildingId == BUILDING_ID_MAGIC_SPAWNER_2 then
        self:_RefreshMagicSpawner2Content()
    end

end

FacFormationStakeCtrl._RefreshCommonContent = HL.Method() << function(self)
    local contentState = CONTENT_STATE_BY_BUILDING_ID[self.m_buildingId]
    if contentState ~= nil then
        self.view.content:SetState(contentState)
    end

    local formationStakeCfg = Tables.factoryFormationStakeTable:GetValue(self.m_buildingId)
    local consumeItemCfg = Tables.itemTable:GetValue(formationStakeCfg.consumeItem)
    self.view.provideTxt.text = string.format(Language.LUA_FAC_FORMATION_STAKE_PROVIDE_FORMAT, consumeItemCfg.name)
    local miniFlowCount = formationStakeCfg.consumeRate
    local maxFlowCount = formationStakeCfg.consumeRateUpperLimit
    self.view.miniFlowNumTxt.text = miniFlowCount
    self.view.consumeMax.text = maxFlowCount
    self.view.consumeBar.fillAmount = miniFlowCount / maxFlowCount

    local curConsumeCount = 0
    if self.m_uiInfo.activatorCost ~= nil then
        curConsumeCount = self.m_uiInfo.activatorCost.currentBufCnt * FacConst.FAC_RECENT_10S_COUNT_TO_MINUTE_RATE_SCALE
    end
    self.view.averageFlowNumTxt.text = curConsumeCount
    self.view.activatorPointer:InitActivatorPointer(maxFlowCount, curConsumeCount)

    self.view.item.gameObject:SetActiveIfNecessary(true)
    self.view.consumeMax.gameObject:SetActiveIfNecessary(true)
    self.view.emptyState.gameObject:SetActiveIfNecessary(false)
    self.view.item:InitItem({ id = formationStakeCfg.consumeItem }, function()
        if DeviceInfo.usingController then
            self.view.item:ShowActionMenu()
            return
        end
        self.view.item:SetSelected(true)
        self.view.item:ShowTips(nil, function()
            self.view.item:SetSelected(false)
        end)
    end)
    self.view.item.actionMenuArgs = {}
    InputManagerInst:SetBindingText(self.view.item.view.button.hoverConfirmBindingId, Language["key_hint_item_open_action_menu"])
    self.view.item:AddHoverBinding("show_item_tips", function()
        self.view.item:ShowTips()
    end)
end

FacFormationStakeCtrl._RefreshConsumeDecoState = HL.Method(HL.Any, HL.Any) << function(self, decoStateController, buildingState)
    if buildingState == GEnums.FacBuildingState.NoPower then
        decoStateController:SetState(DECO_STATE.NoElectricity)
    elseif buildingState == GEnums.FacBuildingState.NotInPowerNet then
        decoStateController:SetState(DECO_STATE.NoNetWork)
    elseif buildingState == GEnums.FacBuildingState.Closed then
        decoStateController:SetState(DECO_STATE.Closed)
    elseif buildingState == GEnums.FacBuildingState.Inactive then
        decoStateController:SetState(DECO_STATE.NotActivated)
    else
        decoStateController:SetState(DECO_STATE.Available)
    end
end

FacFormationStakeCtrl._RefreshMagicSpawner1Content = HL.Method() << function(self)
    local formationId = self:_GetSelectedFormationId(0)
    self:_RefreshFormationNode(self.view.facFormationStakeNode01, 0, formationId, SLOT_STATE_MIDDLE)
    local buildingState = FactoryUtils.getBuildingStateType(self.m_nodeId)
    self:_RefreshConsumeDecoState(self.view.consumeDecoStateRight, buildingState)
    self.view.consumeDecoStateBottom.gameObject:SetActiveIfNecessary(false)
    self.view.facFormationStakeNode02.gameObject:SetActiveIfNecessary(false)
end

FacFormationStakeCtrl._RefreshMagicSpawner2Content = HL.Method() << function(self)
    local topFormationId = self:_GetSelectedFormationId(0)
    self:_RefreshFormationNode(self.view.facFormationStakeNode01, 0, topFormationId, SLOT_STATE_TOP)
    local buildingState = FactoryUtils.getBuildingStateType(self.m_nodeId)
    self:_RefreshConsumeDecoState(self.view.consumeDecoStateRight, buildingState)

    local bottomFormationId = self:_GetSelectedFormationId(1)
    self:_RefreshFormationNode(self.view.facFormationStakeNode02, 1, bottomFormationId, SLOT_STATE_BOTTOM)
    self:_RefreshConsumeDecoState(self.view.consumeDecoStateBottom, buildingState)
end

FacFormationStakeCtrl._OnRefreshFormationStake = HL.Method() << function(self)
    self:_RefreshContent()
end

FacFormationStakeCtrl._GetSelectedFormationId = HL.Method(HL.Number).Return(HL.String) << function(self, csSlotIndex)
    local formationStake = self.m_uiInfo.formationStake
    local selectedFormations = formationStake.selectedFormations
    if csSlotIndex >= selectedFormations.Count then
        return ""
    end

    return selectedFormations[csSlotIndex]
end

FacFormationStakeCtrl._RefreshFormationNode = HL.Method(HL.Any, HL.Number, HL.String, HL.String) << function(self, node, csSlotIndex, formationId, slotState)
    if node == nil then
        return
    end

    node:RefreshFacFormationStakeNode(self.m_uiInfo, csSlotIndex, formationId, slotState)
end

FacFormationStakeCtrl._CheckAlertFormationStakeInputInvalidGasCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Inactive then
        return false
    end

    local activatorCost = self.m_uiInfo.activatorCost
    if activatorCost == nil or activatorCost.currentBufCnt ~= 0 then
        return false
    end

    
    local inPipeInfoList = FactoryUtils.getBuildingPortState(self.m_nodeId, true)
    if inPipeInfoList == nil or inPipeInfoList[1] == nil or not inPipeInfoList[1].isBlock then
        return false
    end

    local checkOpen = DeviceInfo.usingController and
        self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
    return true, {
        condition = GEnums.FacSmartAlertType.FormationStakeInputInvalidGas,
        targetTransform = self.view.facCachePipe.view.singleInCell.rectTransform,
        defaultOpen = checkOpen,
    }
end

FacFormationStakeCtrl._CheckAlertActivatorCostInsufficientCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Inactive then
        return false
    end

    local activatorCost = self.m_uiInfo.activatorCost
    if activatorCost == nil then
        return false
    end

    local formationStakeCfg = Tables.factoryFormationStakeTable:GetValue(self.m_buildingId)
    local currentFlow = activatorCost.currentBufCnt * FacConst.FAC_RECENT_10S_COUNT_TO_MINUTE_RATE_SCALE
    if currentFlow >= formationStakeCfg.consumeRate then
        return false
    end

    local consumeItemCfg = Tables.itemTable:GetValue(formationStakeCfg.consumeItem)
    local checkOpen = DeviceInfo.usingController and
        self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
    return true, {
        condition = GEnums.FacSmartAlertType.ActivatorCostInsufficient,
        targetTransform = self.view.item.transform,
        args = { consumeItemCfg.name },
        defaultOpen = checkOpen,
    }
end

HL.Commit(FacFormationStakeCtrl)
