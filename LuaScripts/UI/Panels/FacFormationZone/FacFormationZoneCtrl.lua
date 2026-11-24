local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

local FormationZoneRuntimeState = CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationZoneRuntimeState
local FormationStakeSlotListType = CS.System.Collections.Generic.List(
    CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationStakeSlot)
local FormationZoneAffectedItemListType = CS.System.Collections.Generic.List(
    CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationZoneAffectedItemInfo)

FacFormationZoneCtrl = HL.Class('FacFormationZoneCtrl', uiCtrl.UICtrl)

FacFormationZoneCtrl.m_formationZoneInfo = HL.Field(HL.Any)
FacFormationZoneCtrl.m_formationZoneCube = HL.Field(HL.Any)
FacFormationZoneCtrl.m_formationZoneChapterId = HL.Field(HL.Number) << -1
FacFormationZoneCtrl.m_formationZoneMapId = HL.Field(HL.Number) << -1
FacFormationZoneCtrl.m_stakeSlots = HL.Field(HL.Any)
FacFormationZoneCtrl.m_affectedItemInfos = HL.Field(HL.Any)
FacFormationZoneCtrl.m_wholeItemCells = HL.Field(HL.Forward("UIListCache"))
FacFormationZoneCtrl.m_updateThread = HL.Field(HL.Thread)
FacFormationZoneCtrl.m_progressInterval = HL.Field(HL.Number) << 0
FacFormationZoneCtrl.m_lastActiveEffectTime = HL.Field(HL.Number) << -1

FacFormationZoneCtrl.s_messages = HL.StaticField(HL.Table) << {
}

FacFormationZoneCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    
    self.m_formationZoneCube = arg.cube
    self.m_formationZoneChapterId = arg.chapterId
    self.m_formationZoneMapId = arg.mapId
    self.m_stakeSlots = FormationStakeSlotListType()
    self.m_affectedItemInfos = FormationZoneAffectedItemListType()
    self.m_wholeItemCells = UIUtils.genCellCache(self.view.rightNode.wholeItemCell)
    self.m_progressInterval = Tables.factoryConst.facFormationEffectInterval * 0.001
    
    self.view.rightNode.facProgressNode:InitFacProgressNode(
        self.m_progressInterval, self.m_progressInterval, nil, nil, nil, self.m_progressInterval)

    self:BindInputPlayerAction("common_cancel", function()
        self.m_phase:CloseSelf()
    end)

    self.view.leftNode.detailsBtn.onClick:AddListener(function()
        self:_OpenFormationFormula()
    end)
    self.view.rightNode.previewBtn.onClick:AddListener(function()
        self:_OpenFormationFormula(false)
    end)

    
    
    self.view.controllerHintPlaceholder = self.view.buildingCommon.view.controllerHintPlaceholder
    self.view.buildingCommon.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self.view.rightNode.wholeItems.getDefaultSelectableFunc = function()
        if self.m_wholeItemCells:GetCount() <= 0 then
            return nil
        end
        return self.m_wholeItemCells:GetItem(1).view.button
    end
end

FacFormationZoneCtrl.OnShow = HL.Override() << function(self)
    self.m_updateThread = self:_ClearCoroutine(self.m_updateThread)
    
    self.m_lastActiveEffectTime = Time.time
    self.view.rightNode.animationWrapper:PlayLoopAnimation()
    self:_RefreshStaticContent()
    local formationFormulaRecovered = false
    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            if not self:_TryRefreshFormationZoneInfo() then
                
                coroutine.waitCondition(function()
                    if PhaseManager.m_curState ~= Const.PhaseState.Idle
                        or self.m_phase.state ~= PhaseConst.EPhaseState.Activated then
                        return false
                    end
                    if Utils.getCurrentChapterId() ~= self.m_formationZoneChapterId
                        or GameWorld.worldInfo.curMapId ~= self.m_formationZoneMapId then
                        return true
                    end
                    local query = GameInstance.remoteFactoryManager.formationZoneQuery
                    return query.currentChapterId == self.m_formationZoneChapterId
                        and query.currentMapId == self.m_formationZoneMapId
                end)
                if not self:_TryRefreshFormationZoneInfo() then
                    self.m_phase:ExitSelfFast()
                    return
                end
            end
            
            if not formationFormulaRecovered then
                formationFormulaRecovered = self.m_phase:_TryRecoverFormationPanel()
            end
            self:_RefreshDynamicContent()
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
        end
    end)
end

FacFormationZoneCtrl.OnHide = HL.Override() << function(self)
    
    self.m_updateThread = self:_ClearCoroutine(self.m_updateThread)
    self.view.rightNode.animationWrapper:ClearTween(false)
end

FacFormationZoneCtrl.OnClose = HL.Override() << function(self)
    
    self.m_updateThread = self:_ClearCoroutine(self.m_updateThread)
    self.view.rightNode.animationWrapper:ClearTween(false)
end

FacFormationZoneCtrl.ShowFacFormationZone = HL.StaticMethod(HL.Any) << function(formationZoneInfo)
    Notify(MessageConst.FAC_OPEN_FORMATION_ZONE_PANEL, formationZoneInfo)
end

FacFormationZoneCtrl._RefreshStaticContent = HL.Method() << function(self)
    local buildingCommonView = self.view.buildingCommon.view
    buildingCommonView.closeButton.onClick:RemoveAllListeners()
    buildingCommonView.closeButton.onClick:AddListener(function()
        self.m_phase:CloseSelf()
    end)
    buildingCommonView.wikiButton.onClick:RemoveAllListeners()
    buildingCommonView.wikiButton.gameObject:SetActiveIfNecessary(false)
end

FacFormationZoneCtrl._TryRefreshFormationZoneInfo = HL.Method().Return(HL.Boolean) << function(self)
    if Utils.getCurrentChapterId() ~= self.m_formationZoneChapterId
        or GameWorld.worldInfo.curMapId ~= self.m_formationZoneMapId then
        return false
    end
    local query = GameInstance.remoteFactoryManager.formationZoneQuery
    if query.currentChapterId ~= self.m_formationZoneChapterId or query.currentMapId ~= self.m_formationZoneMapId then
        return false
    end
    local success, info = query:TryGetFormationZoneInteractInfoByCube(self.m_formationZoneCube)
    if not success then
        return false
    end
    self.m_formationZoneInfo = info
    return true
end

FacFormationZoneCtrl._RefreshDynamicContent = HL.Method() << function(self)
    local cfg = Tables.factoryFormationTable:GetValue(self.m_formationZoneInfo.formationId)
    local levelCfg = Tables.factoryFormationLevelTable:GetValue(
        self.m_formationZoneInfo.formationId).levels[self.m_formationZoneInfo.data.level]
    local buildingCommonView = self.view.buildingCommon.view
    buildingCommonView.machineDescNode.gameObject:SetActiveIfNecessary(true)
    buildingCommonView.descText.text = cfg.desc
    buildingCommonView.machineName.text = levelCfg.name
    buildingCommonView.machineIcon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON, cfg.machineIcon)

    local leftNode = self.view.leftNode
    leftNode.facMagicNode:InitFacMagicNodeByInst({
        formationId = self.m_formationZoneInfo.formationId,
        runtimeState = self.m_formationZoneInfo.data.runtimeState,
        level = self.m_formationZoneInfo.data.level,
    })
    leftNode.formationTxt.text = string.format(Language.LUA_FAC_FORMATION_ZONE_LEVEL_NAME_FORMAT, levelCfg.name)
    self:_RefreshStakeSlots()

    local rightNode = self.view.rightNode
    rightNode.stateController:SetState(FactoryUtils.FORMATION_STATE_BY_ZONE_TYPE[self.m_formationZoneInfo.data.resolvedType])
    local isRunning = self.m_formationZoneInfo.data.runtimeState == FormationZoneRuntimeState.NORMAL
    rightNode.numb.gameObject:SetActiveIfNecessary(isRunning)
    rightNode.facStateNode.gameObject:SetActiveIfNecessary(not isRunning)
    if not isRunning then
        rightNode.facStateNode.stateTxt.text = Language.LUA_FAC_FORMATION_ZONE_INACTIVE_STATE
    end
    self:_RefreshAffectedItems()
    self:_RefreshProbability()
    local hasPlayed, startTime = GameInstance.remoteFactoryManager.visual.formationZoneEffectManager:TryGetFormationActiveEffectTime(
        self.m_formationZoneInfo.data.cube)
    if hasPlayed and startTime > self.m_lastActiveEffectTime then
        self.m_lastActiveEffectTime = startTime
        if self.m_affectedItemInfos.Count > 0 then
            rightNode.animationWrapper:PlayInAnimation()
        end
    end

    local factoryManager = GameInstance.remoteFactoryManager
    local chapterInfo = factoryManager.system.core:GetChapterInfoById(self.m_formationZoneChapterId)
    
    local currentProgress = math.min(math.max(
        (factoryManager.timer.serverTime - chapterInfo.blackboard.formationLastEffectiveTs) * 0.001,
        0), self.m_progressInterval)
    rightNode.facProgressNode:UpdateProgress(currentProgress)
    rightNode.timeTxt.text = string.format(Language["LUA_FAC_PROGRESS_TEXT"], math.ceil(self.m_progressInterval - currentProgress))
end

FacFormationZoneCtrl._RefreshStakeSlots = HL.Method() << function(self)
    local query = GameInstance.remoteFactoryManager.formationZoneQuery
    query:QueryFormationStakeSlotsInZone(self.m_formationZoneInfo.data.cube, self.m_stakeSlots)
    for i = 1, 4 do
        self:_RefreshStakeSlotNode(self.view.leftNode["facMagicNode" .. i], i - 1)
    end
end

FacFormationZoneCtrl._RefreshStakeSlotNode = HL.Method(HL.Any, HL.Number) << function(self, node, csIndex)
    if csIndex >= self.m_stakeSlots.Count then
        node:InitFacMagicNodeByEmpty()
        return
    end

    node:InitFacMagicNodeByInst({
        slot = self.m_stakeSlots[csIndex],
    })
end

FacFormationZoneCtrl._RefreshAffectedItems = HL.Method() << function(self)
    local query = GameInstance.remoteFactoryManager.formationZoneQuery
    query:FillFormationZoneAffectedItems(self.m_formationZoneInfo.data.cube, self.m_affectedItemInfos)
    if self.m_affectedItemInfos.Count == 0 then
        self.view.rightNode.wholeItems.gameObject:SetActiveIfNecessary(false)
        self.m_wholeItemCells:Refresh(0, function() end)
        return
    end

    self.m_wholeItemCells:Refresh(self.m_affectedItemInfos.Count, function(cell, index)
        local itemInfo = self.m_affectedItemInfos[index - 1]
        cell:InitItem({ id = itemInfo.itemId, count = itemInfo.count }, true)
        if DeviceInfo.usingController then
            cell:SetExtraInfo({
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
                tipsPosTransform = self.view.rightNode.wholeItems.transform,
                isSideTips = true,
            })
            cell:SetEnableHoverTips(false)
        end
    end)
    self.view.rightNode.wholeItems.gameObject:SetActiveIfNecessary(true)
end

FacFormationZoneCtrl._RefreshProbability = HL.Method() << function(self)
    local chance = FactoryUtils.getFormationTransferChance(
        self.m_formationZoneInfo.formationId, self.m_formationZoneInfo.data.level)
    if chance == nil then
        self.view.leftNode.probabilityTxt.text = Language.LUA_FAC_FORMATION_ZONE_PROBABILITY_EMPTY
        return
    end
    self.view.leftNode.probabilityTxt.text = FactoryUtils.getFormationChanceText(chance)
end

FacFormationZoneCtrl.TryPrepareFormationFormulaRecover = HL.Method(HL.Table).Return(HL.Boolean) << function(self, formulaArg)
    if not self:_TryRefreshFormationZoneInfo() then
        return false
    end
    local query = GameInstance.remoteFactoryManager.formationZoneQuery
    query:QueryFormationStakeSlotsInZone(self.m_formationZoneInfo.data.cube, self.m_stakeSlots)
    local nodeHandler
    for i = 0, self.m_stakeSlots.Count - 1 do
        local slot = self.m_stakeSlots[i]
        local handler = FactoryUtils.getBuildingNodeHandler(slot.unitId.factoryUnitId, slot.unitId.mapId)
        if handler then
            nodeHandler = handler
            break
        end
    end
    
    formulaArg.nodeHandler = nodeHandler
    return true
end

FacFormationZoneCtrl._OpenFormationFormula = HL.Method(HL.Opt(HL.Boolean)) << function(self, genTab)
    if not self:_TryRefreshFormationZoneInfo() then
        return
    end
    local query = GameInstance.remoteFactoryManager.formationZoneQuery
    query:QueryFormationStakeSlotsInZone(self.m_formationZoneInfo.data.cube, self.m_stakeSlots)

    local selectedFormation = {}
    local buildingId = ""
    local nodeHandler
    for i = 0, self.m_stakeSlots.Count - 1 do
        local slot = self.m_stakeSlots[i]
        local formationId = FactoryUtils.FORMATION_ID_BY_ZONE_TYPE[slot.selectedType]
        if formationId then
            selectedFormation[formationId] = true
        end
        if string.isEmpty(buildingId) then
            local handler = FactoryUtils.getBuildingNodeHandler(slot.unitId.factoryUnitId, slot.unitId.mapId)
            if handler then
                buildingId = handler.templateId
                nodeHandler = handler
            end
        end
    end
    if string.isEmpty(buildingId) then
        buildingId = FactoryUtils.findFormationStakeBuilding(self.m_formationZoneInfo.formationId) or ""
    end
    if string.isEmpty(buildingId) then
        return
    end

    local effectForamtion = {}
    if not string.isEmpty(self.m_formationZoneInfo.formationId) then
        effectForamtion[self.m_formationZoneInfo.formationId] = self.m_formationZoneInfo.data.level
    end

    UIManager:AutoOpen(PanelId.FormationFormula, {
        buildingId = buildingId,
        selectedFormation = selectedFormation,
        effectForamtion = effectForamtion,
        genTab = genTab,
        nodeHandler = nodeHandler,
    })
end

HL.Commit(FacFormationZoneCtrl)
