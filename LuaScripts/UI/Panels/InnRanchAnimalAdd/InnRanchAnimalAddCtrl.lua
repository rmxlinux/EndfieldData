local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRanchAnimalAdd
local PHASE_ID = PhaseId.InnRanchAnimalAdd
local FISHPOND_GROUP_STYLE = "Pond"
local CORRAL_CELL_STATE = "Corral"
local FISHPOND_CELL_STATE = "Fishpond"
InnRanchAnimalAddCtrl = HL.Class('InnRanchAnimalAddCtrl', uiCtrl.UICtrl)







InnRanchAnimalAddCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_RANCH_ANIMAL_UPDATED] = '_OnRanchAnimalUpdated',
}
InnRanchAnimalAddCtrl.m_ranchId = HL.Field(HL.String) << ""
InnRanchAnimalAddCtrl.m_stableGroupId = HL.Field(HL.Number) << -1
InnRanchAnimalAddCtrl.m_stableId = HL.Field(HL.String) << ""
InnRanchAnimalAddCtrl.m_currentFeedAnimalId = HL.Field(HL.String) << ""
InnRanchAnimalAddCtrl.m_availableAnimals = HL.Field(HL.Table)
InnRanchAnimalAddCtrl.m_getCellFunc = HL.Field(HL.Function)
InnRanchAnimalAddCtrl.m_selectedCellIndex = HL.Field(HL.Number) << -1
InnRanchAnimalAddCtrl.m_pendingAnimalId = HL.Field(HL.String) << ""


InnRanchAnimalAddCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_pendingAnimalId = ""
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs(true)
end

InnRanchAnimalAddCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_ranchId = arg.ranchId
    self.m_stableGroupId = arg.stableGroupId
    self.m_stableId = arg.stableId
    self.m_currentFeedAnimalId = arg.currentFeedAnimalId or ""
    self.m_availableAnimals = {}
    for _, data in pairs(Tables.innRanchAnimalTable) do
        for _, stableId in pairs(data.stableGroupIds) do
            if stableId == self.m_stableGroupId then
                table.insert(self.m_availableAnimals, data)
                break
            end
        end
    end
    table.sort(self.m_availableAnimals, Utils.genSortFunction({"sortId"}, true))
    for i = 1, #self.m_availableAnimals do
        if self.m_availableAnimals[i].animalId ~= self.m_currentFeedAnimalId then
            self.m_selectedCellIndex = i
            break
        end
    end
end

InnRanchAnimalAddCtrl._InitUI = HL.Method() << function(self)
    self.view.cancelButton.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.confirmButton.onClick:AddListener(function()
        if PhaseManager:IsInPhaseTransition() then
            return
        end
        local animalData = self.m_availableAnimals[self.m_selectedCellIndex]
        if not animalData then
            return
        end
        self.m_pendingAnimalId = animalData.animalId
        GameInstance.player.ranchSystem:SendRanchAnimalApply(self.m_ranchId, self.m_stableId, self.m_pendingAnimalId)
    end)
    self.view.animalScrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_UpdateAnimalCell(go, csIndex)
    end)
    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.animalScrollList)
    if DeviceInfo.usingController then
        self.view.naviGroup.onDefaultNaviFailed:RemoveAllListeners()
        self.view.naviGroup.onDefaultNaviFailed:AddListener(function(dir)
            self:_OnAnimalListNaviFailed(dir)
        end)
    end
end

InnRanchAnimalAddCtrl._OnRanchAnimalUpdated = HL.Method(HL.Any) << function(self, arg)
    local stableId = unpack(arg)
    if stableId ~= self.m_stableId or string.isEmpty(self.m_pendingAnimalId) then
        return
    end
    local hasAnimal, animalData = GameInstance.player.ranchSystem:GetStableAnimal(self.m_ranchId, self.m_stableId)
    
    if not hasAnimal or animalData.animalId ~= self.m_pendingAnimalId then
        return
    end
    if not PhaseManager:PopPhase(PHASE_ID) then
        return
    end
    self.m_pendingAnimalId = ""
    
    if not string.isEmpty(self.m_currentFeedAnimalId) then
        local domainId = Utils.getCurDomainId()
        local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
        local domainName = domainCfg.domainName
        Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_RANCH_ANIMAL_REPLACE_SUCCESS_TOAST, domainName))
    end
end

InnRanchAnimalAddCtrl._OnAnimalListNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    if not DeviceInfo.usingController then
        return
    end
    local naviDirection = CS.UnityEngine.UI.NaviDirection
    if dir ~= naviDirection.Left and dir ~= naviDirection.Right then
        return
    end
    local currentTarget = InputManagerInst.controllerNaviManager.curTarget
    if not currentTarget then
        return
    end

    
    local firstIndex, lastIndex, currentIndex
    local scrollList = self.view.animalScrollList
    for index, data in ipairs(self.m_availableAnimals) do
        if data.animalId ~= self.m_currentFeedAnimalId then
            firstIndex = firstIndex or index
            lastIndex = index
            local obj = scrollList:Get(CSIndex(index))
            local cell = obj and self.m_getCellFunc(obj)
            if cell and currentTarget == cell.button then
                currentIndex = index
            end
        end
    end
    if not firstIndex or firstIndex == lastIndex then
        return
    end
    local targetIndex
    if dir == naviDirection.Left and currentIndex == firstIndex then
        targetIndex = lastIndex
    elseif dir == naviDirection.Right and currentIndex == lastIndex then
        targetIndex = firstIndex
    else
        return
    end

    local obj = scrollList:Get(CSIndex(targetIndex))
    local cell = obj and self.m_getCellFunc(obj)
    local target = cell and cell.button
    if target and target.enableControllerNavi and target:IsActive() and target:IsInteractable() then
        self:SetNaviTarget(target)
    end
end

InnRanchAnimalAddCtrl._RefreshAllUIs = HL.Method(HL.Boolean) << function(self, isInit)
    self.view.animalScrollList:UpdateCount(#self.m_availableAnimals)
    if isInit then
        if DeviceInfo.usingController then
            local selectedCell = self.m_getCellFunc(self.m_selectedCellIndex)
            if selectedCell then
                self:SetNaviTarget(selectedCell.button)
            end
            self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
        end
    end
end

InnRanchAnimalAddCtrl._UpdateAnimalCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getCellFunc(go)
    local index = LuaIndex(csIndex)
    local animalData = self.m_availableAnimals[index]
    cell.gameObject.name = "AnimalCell_" .. index
    cell.iconAnimal:LoadSprite(UIConst.UI_SPRITE_INN_RANCH_ANIMAL, animalData.icon)
    cell.animalNameTxt.text = animalData.name
    local hasLow, lowProductCfg = Tables.itemTable:TryGetValue(animalData.lowLevelProd)
    local hasHigh, highProductCfg = Tables.itemTable:TryGetValue(animalData.highLevelProd)
    cell.productionLowCell.gameObject:SetActive(hasLow)
    cell.productionHighCell.gameObject:SetActive(hasHigh)
    if hasLow then
        cell.productionLowCell.icon:LoadSprite(UIConst.UI_SPRITE_ITEM, lowProductCfg.iconId)
        cell.productionLowCell.productNameText.text = lowProductCfg.name
        UIUtils.setItemRarityImage(cell.productionLowCell.decoQualityImg, lowProductCfg.rarity)
    end
    if hasHigh then
        cell.productionHighCell.icon:LoadSprite(UIConst.UI_SPRITE_ITEM, highProductCfg.iconId)
        cell.productionHighCell.productNameText.text = highProductCfg.name
        UIUtils.setItemRarityImage(cell.productionHighCell.decoQualityImg, highProductCfg.rarity)
    end

    self:_UpdateAnimalCellSelectedState(cell, index)
    if animalData.animalId == self.m_currentFeedAnimalId then
        cell.stateController:SetState("CurrentFeed")
        cell.button.interactable = false
    else
        cell.stateController:SetState("UnCurrentFeed")
        cell.button.interactable = true
        cell.button.onClick:RemoveAllListeners()
        cell.button.onClick:AddListener(function()
            self:_ChangeCellSelectedState(index, true)
        end)
    end
end

InnRanchAnimalAddCtrl._UpdateAnimalCellSelectedState = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local isSelected = self.m_selectedCellIndex == index
    cell.stateController:SetState(isSelected and "Select" or "Normal")
    local stableGroupCfg = Tables.innRanchStableGroupTable:GetValue(self.m_stableGroupId)
    local styleState = stableGroupCfg.style == FISHPOND_GROUP_STYLE and FISHPOND_CELL_STATE or CORRAL_CELL_STATE
    cell.stateController:SetState(styleState)
end

InnRanchAnimalAddCtrl._ChangeCellSelectedState = HL.Method(HL.Number, HL.Boolean) << function(self, index, isSelected)
    if self.m_selectedCellIndex == index then
        return
    end
    self.m_selectedCellIndex = index
    self.view.animalScrollList:UpdateShowingCells(function(csIndex, go)
        local cell = self.m_getCellFunc(go)
        local index = LuaIndex(csIndex)
        self:_UpdateAnimalCellSelectedState(cell, index)
    end)
end

HL.Commit(InnRanchAnimalAddCtrl)
