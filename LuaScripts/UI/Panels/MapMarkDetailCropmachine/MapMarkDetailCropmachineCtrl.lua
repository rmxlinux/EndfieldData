local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailCropmachine

MapMarkDetailCropmachineCtrl = HL.Class('MapMarkDetailCropmachineCtrl', uiCtrl.UICtrl)

local StatusType = {
    AutoSeed = 1,  
    AutoHarvest = 2,  
    CellEnough = 3,  
    AllEnough = 4,  
    None = 5,  
}

local FeatureType = {
    Harvest = "autoHarvest",
}






MapMarkDetailCropmachineCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FARM_TERMINAL_DATA_CHANGED] = '_OnFarmTerminalDataChanged',
}













MapMarkDetailCropmachineCtrl.m_markInstId = HL.Field(HL.String) << ""


MapMarkDetailCropmachineCtrl.m_viewModel = HL.Field(HL.Table)

MapMarkDetailCropmachineCtrl.m_itemCellCache = HL.Field(HL.Any)




MapMarkDetailCropmachineCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    if not self:_InitData(arg) then
        return
    end
    self:_InitUI()
    self:_RefreshUI()
end












MapMarkDetailCropmachineCtrl._InitData = HL.Method(HL.Any).Return(HL.Boolean) << function(self, arg)
    if arg == nil or string.isEmpty(arg.markInstId) then
        logger.error("[MapMarkDetailCropmachineCtrl] no markInstId in arg")
        return false
    end

    self.m_markInstId = arg.markInstId
    local getRuntimeDataSuccess, markRuntimeData =
        GameInstance.player.mapManager:GetMarkInstRuntimeData(self.m_markInstId)
    if not getRuntimeDataSuccess then
        logger.error("[MapMarkDetailCropmachineCtrl] failed to get mark runtime data: ", self.m_markInstId)
        return false
    end

    local detail = markRuntimeData.detail
    local id = detail and detail.systemInstId
    if string.isEmpty(id) then
        logger.error("[MapMarkDetailCropmachineCtrl] no systemInstId in mark detail: ", self.m_markInstId)
        return false
    end

    local _, cfg = Tables.soilMgrTable:TryGetValue(id)
    if not cfg then
        logger.error("[MapMarkDetailCropmachineCtrl] no table cfg for id: ", id)
        return false
    end

    self.m_viewModel = {
        id = id,
        title = cfg.clientShowName,
        currLevel = 0,
        maxLevel = 0,
        isMaxLevel = false,
        depotItemDataList = {},
        depotCapacity = 0,
        isAutoHarvestUnlocked = false,
        descList = {},
        statusType = StatusType.None,
    }
    for _, desc in pairs(cfg.descList) do
        if not string.isEmpty(desc) then
            table.insert(self.m_viewModel.descList, desc)
        end
    end

    self.m_viewModel.currLevel = self:_GetFarmTerminalSystem():GetTerminalLevel(id)
    for _, levelData in pairs(cfg.levelList) do
        if levelData.level > self.m_viewModel.maxLevel then
            self.m_viewModel.maxLevel = levelData.level
        end
        if levelData.level == self.m_viewModel.currLevel then
            self.m_viewModel.depotCapacity = levelData.depotCapacity
            self.m_viewModel.isAutoHarvestUnlocked = levelData[FeatureType.Harvest] == true
        end
    end
    self.m_viewModel.isMaxLevel = self.m_viewModel.currLevel == self.m_viewModel.maxLevel
    self.m_viewModel.depotItemDataList = self:_GetDepotItemDataListFromSystem(id)
    self.m_viewModel.statusType = self:_GetStatusType()
    return true
end

MapMarkDetailCropmachineCtrl._GetFarmTerminalSystem = HL.Method().Return(HL.Userdata) << function(self)
    return GameInstance.player.farmTerminalSystem
end

MapMarkDetailCropmachineCtrl._GetDepotItemDataListFromSystem = HL.Method(HL.String).Return(HL.Table) << function(self, id)
    local depotItemDataList = {}
    local csDepotItemDataList = self:_GetFarmTerminalSystem():GetDepotItemDataList(id)
    if csDepotItemDataList == nil then
        return depotItemDataList
    end

    for i = 0, csDepotItemDataList.Count - 1 do
        local itemData = csDepotItemDataList[i]
        table.insert(depotItemDataList, {
            index = itemData.index,
            itemId = itemData.itemId,
            count = itemData.count,
        })
    end
    return depotItemDataList
end

MapMarkDetailCropmachineCtrl._GetLevelDataInCfg = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, level)
    local _, cfg = Tables.soilMgrTable:TryGetValue(self.m_viewModel.id)
    for _, levelData in pairs(cfg.levelList) do
        if levelData.level == level then
            return levelData
        end
    end
    return nil
end

MapMarkDetailCropmachineCtrl._GetStatusType = HL.Method().Return(HL.Number) << function(self)
    if self.m_viewModel.currLevel == 0 then
        return StatusType.None
    end

    if self.m_viewModel.depotCapacity > 0 and
        #self.m_viewModel.depotItemDataList >= self.m_viewModel.depotCapacity then
        local itemLimit = Tables.factorySoilConst.SoilMgrDepotItemLimit
        for _, itemData in ipairs(self.m_viewModel.depotItemDataList) do
            if itemData.count < itemLimit then
                return StatusType.CellEnough
            end
        end
        return StatusType.AllEnough
    end

    if self.m_viewModel.isAutoHarvestUnlocked then
        return StatusType.AutoHarvest
    end
    return StatusType.AutoSeed
end

MapMarkDetailCropmachineCtrl._InitUI = HL.Method() << function(self)
    self.view.storeBtn.onClick:AddListener(function()
        self:_OnSaveBtnClick()
    end)
    self.m_itemCellCache = UIUtils.genCellCache(self.view.cropLayout.itemCell)

    local descText = #self.m_viewModel.descList > 0 and table.concat(self.m_viewModel.descList, "\n") or nil
    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon({
        markInstId = self.m_markInstId,
        titleText = self.m_viewModel.title,
        descText = descText,
        bigBtnActive = true,
    })
end





MapMarkDetailCropmachineCtrl._RefreshUI = HL.Method() << function(self)
    self:_RefreshDepotFocusBinding()

    local stateController = self.view.mapMarkDetailCommonStateController
    if self.m_viewModel.currLevel == 0 then
        stateController:SetState("NotActivated")
        self.view.cropLayout.gameObject:SetActive(false)
        self.view.storeBtn.gameObject:SetActive(false)
        self.m_itemCellCache:Refresh(0)
        return
    end

    stateController:SetState("Activation")
    self.view.lvStateNode:SetState(self.m_viewModel.isMaxLevel and "Max" or "Nrl")
    self.view.lvNumTxt.text = tostring(self.m_viewModel.currLevel)

    if self.m_viewModel.statusType == StatusType.AutoSeed then
        stateController:SetState("Seedlings")
    elseif self.m_viewModel.statusType == StatusType.AutoHarvest then
        stateController:SetState("Harvest")
    elseif self.m_viewModel.statusType == StatusType.CellEnough then
        stateController:SetState("NoStored")
    elseif self.m_viewModel.statusType == StatusType.AllEnough then
        stateController:SetState("Full")
    end

    local canShowDepot = self.m_viewModel.isAutoHarvestUnlocked and self.m_viewModel.depotCapacity > 0
    self.view.cropLayout.gameObject:SetActive(canShowDepot)
    self.view.storeBtn.gameObject:SetActive(canShowDepot)
    if canShowDepot then
        self:_RefreshDepotItem()
    else
        self.m_itemCellCache:Refresh(0)
    end
end

MapMarkDetailCropmachineCtrl._RefreshDepotFocusBinding = HL.Method() << function(self)
    
    local naviGroup = self.view.cropLayout.gameObject:GetComponent("UISelectableNaviGroup")
    local canFocus = self.m_viewModel.currLevel > 0 and
        self.m_viewModel.isAutoHarvestUnlocked and
        self.m_viewModel.depotCapacity > 0 and
        #self.m_viewModel.depotItemDataList > 0
    if not canFocus and naviGroup.IsTopLayer then
        naviGroup:ManuallyStopFocus()
    end
    InputManagerInst:ToggleBinding(naviGroup.FocusBindingId, canFocus and not naviGroup.IsTopLayer)
end

MapMarkDetailCropmachineCtrl._RefreshDepotItem = HL.Method() << function(self)
    self.m_itemCellCache:Refresh(self.m_viewModel.depotCapacity, function(cell, index)
        local itemData = self.m_viewModel.depotItemDataList[index]
        
        local itemSmall = Utils.wrapLuaNode(cell.itemSmall.gameObject)
        if itemData then
            itemSmall.gameObject:SetActive(true)
            cell.bgEmpty.gameObject:SetActive(false)
            itemSmall:InitItem({ id = itemData.itemId, count = itemData.count }, true)
            itemSmall:SetExtraInfo({
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                tipsPosTransform = self.view.cropLayout.transform,
                isSideTips = true,
            })
        else
            itemSmall.gameObject:SetActive(false)
            cell.bgEmpty.gameObject:SetActive(true)
        end
    end)
end





MapMarkDetailCropmachineCtrl._OnFarmTerminalDataChanged = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    if not string.isEmpty(id) and id ~= self.m_viewModel.id then
        return
    end

    if self:_InitData({ markInstId = self.m_markInstId }) then
        self:_RefreshUI()
    end
end

MapMarkDetailCropmachineCtrl._OnSaveBtnClick = HL.Method() << function(self)
    if #self.m_viewModel.depotItemDataList == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_FARM_TERMINAL_SAVE_ON_EMPTY)
        return
    end

    self:_GetFarmTerminalSystem():SendTransportDepotToFactory(self.m_viewModel.id)
end



HL.Commit(MapMarkDetailCropmachineCtrl)
