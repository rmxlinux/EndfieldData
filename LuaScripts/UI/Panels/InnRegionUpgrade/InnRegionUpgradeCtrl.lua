local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRegionUpgrade
local PHASE_ID = PhaseId.InnRegionUpgrade

local INN_CURRENCY_WALLET_ICON = "item_inn_currency_icon"
local EXPANSION_DEFAULT_CAMERA_KEY = "expansion_default"

local EXPANSION_FIELD_TYPE_MAP = {
    { field = "addFoodTraySize", type = GEnums.InnManagementExpansionType.FoodTraySize },
    { field = "addKitchenNum", type = GEnums.InnManagementExpansionType.KitchenNum },
    { field = "addKitchenQueueSize", type = GEnums.InnManagementExpansionType.KitchenQueueSize },
    { field = "addKitchenCharNum", type = GEnums.InnManagementExpansionType.KitchenCharNum },
    { field = "addServingCounterSize", type = GEnums.InnManagementExpansionType.ServingCounterSize },
}

InnRegionUpgradeCtrl = HL.Class('InnRegionUpgradeCtrl', uiCtrl.UICtrl)

InnRegionUpgradeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WALLET_CHANGED] = '_OnWalletChanged',
    [MessageConst.ON_INN_UNLOCK_EXTEND_ENTRY] = '_OnExpansionUnlocked',
}

InnRegionUpgradeCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnRegionUpgradeCtrl.m_purchaseEnabled = HL.Field(HL.Boolean) << true

InnRegionUpgradeCtrl.m_selectItemId = HL.Field(HL.String) << ""

InnRegionUpgradeCtrl.m_currencyItemId = HL.Field(HL.String) << ""


InnRegionUpgradeCtrl.m_currencyItemSprite = HL.Field(HL.Userdata)

InnRegionUpgradeCtrl.m_currencyItemName = HL.Field(HL.String) << ""

InnRegionUpgradeCtrl.m_currencyCount = HL.Field(HL.Number) << -1

InnRegionUpgradeCtrl.m_isAllPurchased = HL.Field(HL.Boolean) << false

InnRegionUpgradeCtrl.m_expansionDataList = HL.Field(HL.Table)

InnRegionUpgradeCtrl.m_expansionDataGetter = HL.Field(HL.Table)

InnRegionUpgradeCtrl.m_getExpansionCell = HL.Field(HL.Function)

InnRegionUpgradeCtrl.m_buildCells = HL.Field(HL.Forward('UIListCache'))

InnRegionUpgradeCtrl.m_purchasedAnimTimer = HL.Field(HL.Number) << -1

InnRegionUpgradeCtrl.m_pendingPopupArg = HL.Field(HL.Table)

InnRegionUpgradeCtrl.m_camCfgs = HL.Field(HL.Userdata)

InnRegionUpgradeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_purchaseEnabled = true
    self.m_camCfgs = arg and arg.camCfgs

    self.view.btnClose.onClick:AddListener(function()
        if not PhaseManager:CanPopPhase(PHASE_ID) then
            return
        end
        self.view.luaPanel:BlockAllInput()
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.btnNode.purchaseBtn.onClick:AddListener(function()
        self:_OnPurchaseSelectedItem()
    end)

    self:_InitCurrencyItem()
    self:_InitExpansionList()

    self:_TryRecoverState(arg)
    self:_InitController()
end

InnRegionUpgradeCtrl.OnClose = HL.Override() << function(self)
    self:_ClearPurchasedAnimTimer()
end

InnRegionUpgradeCtrl.OnPhaseExit = HL.Method(HL.Boolean) << function(self, fastMode)
    self:_ClearPurchasedAnimTimer()
    if InputManagerInst.inChangingInputDevice then
        return
    end
    self:_BlendOutCamera(fastMode)
end





InnRegionUpgradeCtrl._InitCurrencyItem = HL.Method() << function(self)
    self.m_currencyItemId = "item_inn_gold"
    local itemData = Tables.itemTable:GetValue(self.m_currencyItemId)
    self.m_currencyItemName = itemData.name
    self.m_currencyItemSprite = self:LoadSprite(UIConst.UI_SPRITE_WALLET, INN_CURRENCY_WALLET_ICON)

    self:_UpdateCurrencyCount()

    self.view.walletBarPlaceholder:InitWalletBarPlaceholder({ self.m_currencyItemId })
end

InnRegionUpgradeCtrl._InitExpansionList = HL.Method() << function(self)
    self.m_getExpansionCell = UIUtils.genCachedCellFunction(self.view.expasionList)
    self.view.expasionList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getExpansionCell(obj)
        local index = LuaIndex(csIndex)
        local data = self.m_expansionDataList[index]
        if data then
            self:_RefreshExpansionCell(cell, data)
        end
    end)

    self.m_buildCells = UIUtils.genCellCache(self.view.buildCell)

    self.view.leftNode.gameObject:SetActive(false)

    self:_UpdateAndRefreshAllItems()
    self:_RefreshBtnNodeState()
end

InnRegionUpgradeCtrl._TryRecoverState = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local selectedItemId = arg and arg.selectedItemId
    if selectedItemId and not string.isEmpty(selectedItemId) then
        local itemData = self.m_expansionDataGetter[selectedItemId]
        if itemData ~= nil and not itemData.isPurchased then
            self:_SelectExpansionCell(selectedItemId)
        end
    else
        self:_BlendToCamera(EXPANSION_DEFAULT_CAMERA_KEY)
    end
end






InnRegionUpgradeCtrl._OnWalletChanged = HL.Method(HL.Any) << function(self, eventArgs)
    local changeId = unpack(eventArgs)
    if changeId ~= self.m_currencyItemId then
        return
    end

    self:_UpdateCurrencyCount()
    self:_RefreshAllCellsCurrencyColor()
    self:_RefreshBtnNodeState()
end

InnRegionUpgradeCtrl._OnPurchaseSelectedItem = HL.Method() << function(self)
    if string.isEmpty(self.m_selectItemId) or not self.m_purchaseEnabled then
        return
    end

    local data = self.m_expansionDataGetter[self.m_selectItemId]
    if data == nil or data.isLocked or data.isPurchased then
        return
    end

    if self.m_currencyCount < data.cost then
        return
    end

    self.m_purchaseEnabled = false

    self.m_pendingPopupArg = {
        name = data.name,
        desc = data.desc,
        buildInfoList = self:_GetExpansionBuildInfo(data),
    }

    UIUtils.PlayAnimationAndToggleActive(self.view.mainAnim, false, function()
        if DeviceInfo.usingController then
            self:ClearNaviTarget()
        end
    end)

    self.view.luaPanel:BlockAllInput()
    self.m_innSystem:SendUnlockExtendEntry(self.m_selectItemId)
end

InnRegionUpgradeCtrl._OnExpansionUnlocked = HL.Method(HL.Any) << function(self, eventArgs)
    self:_UpdateAndRefreshAllItems()

    local duration = self.view.config.REGION_UPGRADE_BLENDING_DURATION + self.view.config.REGION_UPGRADE_BLENDING_END_DELAY_DURATION
    self:_ClearPurchasedAnimTimer()
    self.m_purchasedAnimTimer = self:_StartTimer(duration, function()
        self:_ClearPurchasedAnimTimer()

        local onRecover = function()
            UIUtils.PlayAnimationAndToggleActive(self.view.mainAnim, true)
            self.m_purchaseEnabled = true
            self.view.luaPanel:RecoverAllInput()
            self:_SelectExpansionCell()
            self:_FindFirstItemToSelectInController()
        end

        if self.m_pendingPopupArg then
            self.m_pendingPopupArg.onClose = onRecover
            UIManager:AutoOpen(PanelId.InnRegionUpgradePopup, self.m_pendingPopupArg)
            self.m_pendingPopupArg = nil
        else
            onRecover()
        end
    end)
end






InnRegionUpgradeCtrl._UpdateCurrencyCount = HL.Method() << function(self)
    self.m_currencyCount = Utils.getItemCount(self.m_currencyItemId)
end

InnRegionUpgradeCtrl._UpdateAndRefreshAllItems = HL.Method() << function(self)
    self:_UpdateExpansionDataList()
    self:_RefreshExpansionCells()
    self:_RefreshAllCellsCurrencyColor()
end

InnRegionUpgradeCtrl._UpdateExpansionDataList = HL.Method() << function(self)
    self.m_expansionDataList = {}
    self.m_expansionDataGetter = {}
    self.m_isAllPurchased = true

    for id, tableData in pairs(Tables.innExpansionTable) do
        local isPurchased = self.m_innSystem:IsExtendEntryUnlocked(id)
        local isLevelLocked = not isPurchased and self.m_innSystem.innLevel < tableData.unlockLevel
        local prerequisiteId = tableData.prerequisiteId
        local isPrerequisiteLocked = false
        if not isPurchased and not string.isEmpty(prerequisiteId) then
            isPrerequisiteLocked = not self.m_innSystem:IsExtendEntryUnlocked(prerequisiteId)
        end
        local isLocked = isLevelLocked or isPrerequisiteLocked
        local data = {
            id = id,
            name = tableData.name,
            desc = tableData.desc,
            cost = tableData.cost,
            unlockLevel = tableData.unlockLevel,
            sortId = tableData.sortId,
            prerequisiteId = prerequisiteId,
            isLevelLocked = isLevelLocked,
            isPrerequisiteLocked = isPrerequisiteLocked,
            cameraKey = tableData.cameraKey,
            addFoodTraySize = tableData.addFoodTraySize,
            addKitchenNum = tableData.addKitchenNum,
            addKitchenQueueSize = tableData.addKitchenQueueSize,
            addKitchenCharNum = tableData.addKitchenCharNum,
            addServingCounterSize = tableData.addServingCounterSize,
            isPurchased = isPurchased,
            isLocked = isLocked,
            isPurchasedSort = isPurchased and 1 or 0,
            isLockedSort = isLocked and 1 or 0,
        }
        table.insert(self.m_expansionDataList, data)
        self.m_expansionDataGetter[id] = data

        if not isPurchased then
            self.m_isAllPurchased = false
        end
    end

    local sortFunc = Utils.genSortFunction({ "isLockedSort", "isPurchasedSort", "sortId"}, true)
    table.sort(self.m_expansionDataList, sortFunc)
end

InnRegionUpgradeCtrl._RefreshExpansionCells = HL.Method() << function(self)
    self.view.expasionList:UpdateCount(#self.m_expansionDataList)
end

InnRegionUpgradeCtrl._RefreshExpansionCell = HL.Method(HL.Table, HL.Table) << function(self, cell, data)
    cell.nameTxt.text = data.name
    cell.namePurchasedTxt.text = data.name
    cell.currencyIcon.sprite = self.m_currencyItemSprite
    cell.purchaseCostTxt.text = tostring(data.cost)

    if data.isPurchased then
        cell.itemStateController:SetState("Purchased")
    elseif data.isLocked then
        cell.itemStateController:SetState("Locked")
        if data.isLevelLocked then
            cell.lockTxt.text = string.format(Language.LUA_INN_UPGRADE_LOCK_LEVEL_HINT, data.unlockLevel)
        else
            local prereqData = self.m_expansionDataGetter[data.prerequisiteId]
            local prereqName = prereqData and prereqData.name or data.prerequisiteId
            cell.lockTxt.text = string.format(Language.LUA_INN_UPGRADE_PREREQUISITE_HINT, prereqName)
        end
    else
        cell.itemStateController:SetState("Normal")
    end

    local isSelected = self.m_selectItemId == data.id
    cell.selectStateController:SetState(isSelected and "Selected" or "Unselected")
    cell.animationWrapper:PlayWithTween(isSelected and "upgrade_cell_selected" or "upgrade_cell_default")

    local purchaseValid = not data.isPurchased and not data.isLocked and data.cost <= self.m_currencyCount
    cell.purchaseCostTxt.color = purchaseValid and
        self.view.config.PURCHASE_COST_NORMAL_COLOR or
        self.view.config.PURCHASE_COST_NOT_ENOUGH_COLOR

    cell.button.onClick:RemoveAllListeners()
    if not data.isPurchased and not data.isLocked then
        cell.button.onClick:AddListener(function()
            if self.m_selectItemId == data.id then
                return
            end
            self:_SelectExpansionCell(data.id)
        end)
        cell.button.enabled = true
    else
        cell.button.enabled = false
    end

    cell.gameObject.name = data.id
end

InnRegionUpgradeCtrl._RefreshAllCellsCurrencyColor = HL.Method() << function(self)
    self.view.expasionList:UpdateCount(#self.m_expansionDataList)
end

InnRegionUpgradeCtrl._RefreshBuildDetails = HL.Method() << function(self)
    self.view.leftNode.gameObject:SetActive(false)

    if string.isEmpty(self.m_selectItemId) then
        return
    end

    local data = self.m_expansionDataGetter[self.m_selectItemId]
    if data == nil then
        return
    end

    local buildInfoList = self:_GetExpansionBuildInfo(data)
    if #buildInfoList <= 0 then
        return
    end

    self.m_buildCells:Refresh(#buildInfoList, function(cell, index)
        local info = buildInfoList[index]
        cell.titleTxt.text = info.name
        cell.contentTxt.text = info.desc
        cell.oldTxt.text = tostring(info.oldValue)
        cell.newText.text = tostring(info.newValue)
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_INN_REGION_UPGRADE, info.icon)
    end)

    self.view.leftNode.gameObject:SetActive(true)
end

InnRegionUpgradeCtrl._RefreshBtnNodeState = HL.Method() << function(self)
    local btnNode = self.view.btnNode
    if self.m_isAllPurchased then
        btnNode.stateController:SetState("AllPurchased")
        return
    end

    if string.isEmpty(self.m_selectItemId) then
        btnNode.stateController:SetState("Unselected")
        return
    end

    local data = self.m_expansionDataGetter[self.m_selectItemId]
    if data.isLocked then
        btnNode.stateController:SetState("Locked")
        return
    end

    if self.m_currencyCount >= data.cost then
        btnNode.stateController:SetState("Normal")
    else
        btnNode.stateController:SetState("NotEnoughCurrency")
        btnNode.currencyTxt:SetAndResolveTextStyle(string.format(
            Language.LUA_INN_UPGRADE_CURRENCY_NOT_ENOUGH_HINT_TEXT,
            INN_CURRENCY_WALLET_ICON,
            self.m_currencyItemName))
    end
end






InnRegionUpgradeCtrl._GetExpansionBuildInfo = HL.Method(HL.Table).Return(HL.Table) << function(self, data)
    local buildInfoList = {}

    for _, mapping in ipairs(EXPANSION_FIELD_TYPE_MAP) do
        local addValue = data[mapping.field]
        if addValue and addValue > 0 then
            local funcSuccess, funcData = Tables.innExpansionFuncTable:TryGetValue(mapping.type)
            if funcSuccess then
                local currentValue = self:_GetCurrentCapacity(mapping.type)
                table.insert(buildInfoList, {
                    name = funcData.name,
                    desc = funcData.desc,
                    icon = funcData.icon,
                    oldValue = currentValue,
                    newValue = currentValue + addValue,
                })
            end
        end
    end

    return buildInfoList
end

InnRegionUpgradeCtrl._GetCurrentCapacity = HL.Method(GEnums.InnManagementExpansionType).Return(HL.Number) << function(self, expansionType)
    local inn = self.m_innSystem

    if expansionType == GEnums.InnManagementExpansionType.FoodTraySize then
        return inn.foodTraySize
    elseif expansionType == GEnums.InnManagementExpansionType.KitchenNum then
        return inn.kitchenNum
    elseif expansionType == GEnums.InnManagementExpansionType.KitchenCharNum then
        return inn.kitchenCharSlotNum
    elseif expansionType == GEnums.InnManagementExpansionType.ServingCounterSize then
        return inn.servingCounterSize
    elseif expansionType == GEnums.InnManagementExpansionType.KitchenQueueSize then
        local queueSize = Tables.innManagementConst.initKitchenQueueSize
        for _, expData in pairs(Tables.innExpansionTable) do
            if inn:IsExtendEntryUnlocked(expData.id) then
                queueSize = queueSize + expData.addKitchenQueueSize
            end
        end
        return queueSize
    end

    return 0
end






InnRegionUpgradeCtrl._GetVisibleCell = HL.Method(HL.String).Return(HL.Opt(HL.Table)) << function(self, dataId)
    for i, data in ipairs(self.m_expansionDataList) do
        if data.id == dataId then
            local obj = self.view.expasionList:Get(CSIndex(i))
            if obj then
                return self.m_getExpansionCell(obj)
            end
            return nil
        end
    end
    return nil
end

InnRegionUpgradeCtrl._SelectExpansionCell = HL.Method(HL.Opt(HL.String)) << function(self, selectItemId)
    selectItemId = selectItemId or ""

    local lastCell = self:_GetVisibleCell(self.m_selectItemId)
    if lastCell then
        lastCell.selectStateController:SetState("Unselected")
        lastCell.animationWrapper:PlayWithTween("upgrade_cell_default")
    end

    local currCell = self:_GetVisibleCell(selectItemId)
    if currCell then
        currCell.selectStateController:SetState("Selected")
        currCell.animationWrapper:PlayWithTween("upgrade_cell_selected")
        self:SetNaviTarget(currCell.button)
    end

    self.m_selectItemId = selectItemId

    self:_RefreshBtnNodeState()
    self:_RefreshBuildDetails()

    if string.isEmpty(self.m_selectItemId) then
        self:_BlendToCamera(EXPANSION_DEFAULT_CAMERA_KEY)
        self:SetNaviTarget(nil)
    else
        local data = self.m_expansionDataGetter[self.m_selectItemId]
        if data and not string.isEmpty(data.cameraKey) then
            self:_BlendToCamera(data.cameraKey)
        end
    end
end

InnRegionUpgradeCtrl.GetSelectItemId = HL.Method().Return(HL.String) << function(self)
    return self.m_selectItemId
end

InnRegionUpgradeCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        selectedItemId = self.m_selectItemId,
        camCfgs = self.m_camCfgs,
    }
end






InnRegionUpgradeCtrl._ClearPurchasedAnimTimer = HL.Method() << function(self)
    if self.m_purchasedAnimTimer <= 0 then
        return
    end
    self.m_purchasedAnimTimer = self:_ClearTimer(self.m_purchasedAnimTimer)
end






InnRegionUpgradeCtrl._BlendToCamera = HL.Method(HL.String) << function(self, cameraKey)
    if not self.m_camCfgs then
        return
    end
    local success, cfg = self.m_camCfgs:TryGetValue(cameraKey)
    if success and cfg then
        GameAction.BlendToRelativeCamera(cfg)
    end
end

InnRegionUpgradeCtrl._BlendOutCamera = HL.Method(HL.Boolean) << function(self, fastMode)
    if not self.m_camCfgs then
        return
    end
    CameraUtils.DoCommonTempBlendOut(fastMode and 0 or 0.5)
end






InnRegionUpgradeCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    if DeviceInfo.usingController then
        self.view.naviGroup.onDefaultNaviFailed:RemoveAllListeners()
        self.view.naviGroup.onDefaultNaviFailed:AddListener(function(dir)
            self:_OnExpansionListNaviFailed(dir)
        end)
    end
    self:_FindFirstItemToSelectInController()
end

InnRegionUpgradeCtrl._OnExpansionListNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    if not DeviceInfo.usingController then
        return
    end
    local naviDirection = CS.UnityEngine.UI.NaviDirection
    if dir ~= naviDirection.Up and dir ~= naviDirection.Down then
        return
    end
    local currentTarget = InputManagerInst.controllerNaviManager.curTarget
    if not currentTarget then
        return
    end

    
    local firstIndex, lastIndex, currentIndex
    local scrollList = self.view.expasionList
    for index, data in ipairs(self.m_expansionDataList) do
        if not data.isPurchased and not data.isLocked then
            firstIndex = firstIndex or index
            lastIndex = index
            local obj = scrollList:Get(CSIndex(index))
            local cell = obj and self.m_getExpansionCell(obj)
            if cell and currentTarget == cell.button then
                currentIndex = index
            end
        end
    end
    if not firstIndex or firstIndex == lastIndex then
        return
    end
    local targetIndex
    if dir == naviDirection.Up and currentIndex == firstIndex then
        targetIndex = lastIndex
    elseif dir == naviDirection.Down and currentIndex == lastIndex then
        targetIndex = firstIndex
    else
        return
    end

    
    if not scrollList:Get(CSIndex(targetIndex)) then
        InputManagerInst.controllerNaviManager:ClearTargetForListWrap()
    end
    scrollList:ScrollToIndex(CSIndex(targetIndex), true)
    local obj = scrollList:Get(CSIndex(targetIndex))
    local cell = obj and self.m_getExpansionCell(obj)
    local target = cell and cell.button
    if target and target.enableControllerNavi and target:IsActive() and target:IsInteractable() then
        self:SetNaviTarget(target)
    end
end

InnRegionUpgradeCtrl._FindFirstItemToSelectInController = HL.Method() << function(self)
    local selectedCell = self:_GetVisibleCell(self.m_selectItemId)
    if selectedCell then
        self:SetNaviTarget(selectedCell.button)
        return
    end

    for i, data in ipairs(self.m_expansionDataList) do
        if not data.isPurchased and not data.isLocked then
            local obj = self.view.expasionList:Get(CSIndex(i))
            if obj then
                local cell = self.m_getExpansionCell(obj)
                self:SetNaviTarget(cell.button)
            end
            return
        end
    end
end




HL.Commit(InnRegionUpgradeCtrl)
