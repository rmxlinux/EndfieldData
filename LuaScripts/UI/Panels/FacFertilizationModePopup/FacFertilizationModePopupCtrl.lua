local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacFertilizationModePopup

local ModeCellType = {
    EnableTeammateFertilize = 1,
    TeammateFertilizeSameSoil = 2,
}

local ModeCellConfig = {
    [ModeCellType.EnableTeammateFertilize] = {
        title = Language.LUA_FAC_FERTILIZATION_SUPPORT_SETTING_TITLE_1,
        desc = Language.LUA_FAC_FERTILIZATION_SUPPORT_SETTING_DESC_1,
    },
    [ModeCellType.TeammateFertilizeSameSoil] = {
        title = Language.LUA_FAC_FERTILIZATION_SUPPORT_SETTING_TITLE_2,
        desc = Language.LUA_FAC_FERTILIZATION_SUPPORT_SETTING_DESC_2,
    },
}

FacFertilizationModePopupCtrl = HL.Class('FacFertilizationModePopupCtrl', uiCtrl.UICtrl)

FacFertilizationModePopupCtrl.m_arg = HL.Field(HL.Any)

FacFertilizationModePopupCtrl.m_cellCache = HL.Field(HL.Any)

FacFertilizationModePopupCtrl.m_haveSetNaviTarget = HL.Field(HL.Boolean) << false






FacFertilizationModePopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


FacFertilizationModePopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_BindUI()
    self:_SetupUI()
end








FacFertilizationModePopupCtrl._BindUI = HL.Method() << function(self)
    self.view.mask.onClick:AddListener(function()
        self:PlayAnimationOut()
    end)
    self.view.closeButton.onClick:AddListener(function()
        self:PlayAnimationOut()
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.m_cellCache = UIUtils.genCellCache(self.view.itemList)
end

FacFertilizationModePopupCtrl._SetupUI = HL.Method() << function(self)
    self.m_cellCache:Refresh(2, function(cell, luaIndex)
        cell.gameObject.name = tostring(luaIndex)
        local config = ModeCellConfig[luaIndex]
        cell.titleTxt.text = config.title
        cell.toggleWhite.onValueChanged:RemoveAllListeners()
        if luaIndex == ModeCellType.EnableTeammateFertilize then
            local desc = string.format(config.desc, self:_GetFertilizationName())
            cell.descTxt.text = desc
            cell.toggleWhite:SetIsOnWithoutNotify(FactoryUtils.isEnableTeammateFertilize())
            cell.toggleWhite.onValueChanged:AddListener(function(isOn)
                local sameSoil = isOn and FactoryUtils.isTeammateFertilizeSameSoil() or false
                FactoryUtils.setTeammateAutoSoilData(isOn, sameSoil)
                self:_RefreshSameSoilToggleDisplay(isOn, sameSoil)
            end)
        elseif luaIndex == ModeCellType.TeammateFertilizeSameSoil then
            local desc = string.format(config.desc, self:_GetBuildingName())
            cell.descTxt.text = desc
            cell.toggleWhite.onValueChanged:AddListener(function(isOn)
                local isEnableTeammateFertilize = FactoryUtils.isEnableTeammateFertilize()
                FactoryUtils.setTeammateAutoSoilData(isEnableTeammateFertilize, isOn)
                self:_RefreshSameSoilToggleDisplay(isEnableTeammateFertilize, isOn)
            end)
        end
        
        if luaIndex == 1 and not self.m_haveSetNaviTarget then
            self.m_haveSetNaviTarget = true
            self:SetNaviTarget(cell.naviDecorator)
        end
    end)
    self:_RefreshSameSoilToggleDisplay()
end

FacFertilizationModePopupCtrl._RefreshSameSoilToggleDisplay = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, overrideEnableTeammateFertilize, overrideTeammateFertilizeSameSoil)
    local cell = self.m_cellCache:GetItem(ModeCellType.TeammateFertilizeSameSoil)
    if not cell then
        return
    end
    local isEnableTeammateFertilize = overrideEnableTeammateFertilize
    if isEnableTeammateFertilize == nil then
        isEnableTeammateFertilize = FactoryUtils.isEnableTeammateFertilize()
    end
    local isTeammateFertilizeSameSoil = overrideTeammateFertilizeSameSoil
    if isTeammateFertilizeSameSoil == nil then
        isTeammateFertilizeSameSoil = FactoryUtils.isTeammateFertilizeSameSoil()
    end
    cell.toggleWhite.interactable = isEnableTeammateFertilize
    cell.toggleWhite:SetIsOnWithoutNotify(isTeammateFertilizeSameSoil)
    cell.bgLockMask.gameObject:SetActive(not isEnableTeammateFertilize)
    
    
    local naviDecorator = cell.naviDecorator
    naviDecorator.interactable = isEnableTeammateFertilize
end


FacFertilizationModePopupCtrl._GetFertilizationName = HL.Method().Return(HL.String) << function(self)
    local succ, cfg = Tables.itemTable:TryGetValue(self.m_arg.itemId)
    if succ and cfg then
        return cfg.name
    end
    return ""
end


FacFertilizationModePopupCtrl._GetBuildingName = HL.Method().Return(HL.String) << function(self)
    local nodeId = self.m_arg.nodeId
    local buildingSyncNode = FactoryUtils.getBuildingNodeHandler(nodeId)
    local buildingId = buildingSyncNode.templateId
    local buildingData = Tables.factoryBuildingTable[buildingId]
    local buildingName = buildingData.name
    return buildingName
end

HL.Commit(FacFertilizationModePopupCtrl)
