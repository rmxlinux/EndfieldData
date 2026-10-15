local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnDrinkMenuPopUp

InnDrinkMenuPopUpCtrl = HL.Class('InnDrinkMenuPopUpCtrl', uiCtrl.UICtrl)

InnDrinkMenuPopUpCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnDrinkMenuPopUpCtrl.m_drinkItems = HL.Field(HL.Table)

InnDrinkMenuPopUpCtrl.m_getDrinkCell = HL.Field(HL.Function)


InnDrinkMenuPopUpCtrl.m_drinkDemand = HL.Field(HL.Table)





InnDrinkMenuPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_GUEST_STATE_CHANGED] = '_OnDrinkDemandSourceChanged',
    [MessageConst.ON_INN_GUEST_QUEUE_CHANGED] = '_OnDrinkDemandSourceChanged',
    [MessageConst.ON_INN_DESK_STATE_CHANGED] = '_OnDrinkDemandSourceChanged',
    [MessageConst.ON_INN_SERVING_COUNTER_CHANGED] = '_OnDrinkDemandSourceChanged',
    [MessageConst.ON_INN_FOOD_TRAY_CHANGED] = '_OnDrinkDemandSourceChanged',
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnChangeInputDeviceTypeFinished',
    [MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE] = '_OnConfirmChangeInputDeviceType',
}


InnDrinkMenuPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_drinkItems = {}
    self.m_getDrinkCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateDrinkCell(self.m_getDrinkCell(obj), LuaIndex(csIndex))
    end)
    self.view.closeButton.onClick:AddListener(function()
        self:_HideAndShowMainHud()
    end)
    self:BindInputPlayerAction("inn_open_kitchen", function()
        self:_HideAndShowMainHud()
    end)
    self.view.innFoodTray:InitInnFoodTray({ isPickUpDrink = true })
    self.view.innCountDown:InitInnCountDown()
    self:_InitWaterNode()
    self:_RefreshDrinkList()
    self:_InitController()
end

InnDrinkMenuPopUpCtrl._InitWaterNode = HL.Method() << function(self)
    local waterItemId = Tables.innManagementConst.infiniteDrinkItemId
    local waterNode = self.view.waterNode
    waterNode.itemIcon:InitItemIcon(waterItemId, true)
    local hasDrink, drinkData = Tables.innDrinkTable:TryGetValue(waterItemId)
    waterNode.sellingPriceNumTxt.text = (hasDrink and drinkData.price ~= nil) and tostring(drinkData.price) or ""
    waterNode.btn.onClick:AddListener(function()
        
        self:_TryPickUpDrink(waterItemId)
    end)
end


InnDrinkMenuPopUpCtrl._TryPickUpDrink = HL.Method(HL.String) << function(self, itemId)
    if self.m_innSystem:IsFoodTrayFull() then
        if DeviceInfo.usingController then
            self.view.innFoodTray:StartReplaceDrink(itemId)
        else
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DRINK_TRAY_FULL)
        end
        return
    end
    self.m_innSystem:SendPickUpDrink(itemId)
end

InnDrinkMenuPopUpCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.ON_INN_HIDE_MAIN_HUD)
    if DeviceInfo.usingController then
        self:_SetFirstCellNaviTarget()
    end
end

InnDrinkMenuPopUpCtrl._RebuildDrinkDemandMap = HL.Method() << function(self)
    self.m_drinkDemand = InnUtils.buildFoodDemandMap(self.m_innSystem, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink)
end



InnDrinkMenuPopUpCtrl._RefreshAllDrinkDemandTags = HL.Method() << function(self)
    if not self.m_drinkItems or not self.m_getDrinkCell then
        return
    end
    local maxNum = self.m_innSystem.menuDrinkMaxNum
    for i = 1, maxNum do
        local item = self.m_drinkItems[i]
        if item then
            local cell = self.m_getDrinkCell(i)
            if cell then
                local demand = (self.m_drinkDemand and self.m_drinkDemand[item.itemId]) or 0
                cell:SetDemandTagActive(demand > 0)
            end
        end
    end
end


InnDrinkMenuPopUpCtrl._OnDrinkDemandSourceChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_RebuildDrinkDemandMap()
    self:_RefreshAllDrinkDemandTags()
end

InnDrinkMenuPopUpCtrl._RefreshDrinkList = HL.Method() << function(self)
    local menuItems = self.m_innSystem.gameSetting.menuItems
    local drinkType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink
    local list = {}
    if menuItems and menuItems.Count > 0 then
        for i = 0, menuItems.Count - 1 do
            local mi = menuItems[i]
            if mi.foodType == drinkType then
                list[#list + 1] = { itemId = mi.itemId }
            end
        end
    end
    self.m_drinkItems = list
    self:_RebuildDrinkDemandMap()
    self.view.scrollList:UpdateCount(self.m_innSystem.menuDrinkMaxNum)
end

InnDrinkMenuPopUpCtrl._OnUpdateDrinkCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local item = self.m_drinkItems[index]
    if not item then
        if index <= self.m_innSystem.menuDrinkNum then
            cell:SetEmpty()
        elseif index <= self.m_innSystem.menuDrinkMaxNum then
            cell:SetEmptyLocked()
        end
        return
    end
    local topicId = self.m_innSystem.gameSetting.topicId
    local demand = (self.m_drinkDemand and self.m_drinkDemand[item.itemId]) or 0
    cell:InitInnRecipeOverviewCell({
        itemId = item.itemId,
        showDemandTag = demand > 0,
        showTopicTag = false,
        topicId = topicId,
        showIngredient = false,
        onClickCallback = function(itemId, isCountZero)
            if isCountZero then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DRINK_NO_STOCK)
                return
            end
            self:_TryPickUpDrink(itemId)
        end,
        infinityMode = self.m_innSystem.gameSetting.softOpening,
        isItemTipsLeft = index % 2 == 0,
    })
end

InnDrinkMenuPopUpCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

InnDrinkMenuPopUpCtrl._OnChangeInputDeviceTypeFinished = HL.Method(HL.Any) << function(self, args)
    local inputType = args.inputType
    if inputType == DeviceInfo.InputType.Controller then
        self:_InitController()
        if self:IsShow() then
            self:_SetFirstCellNaviTarget()
        end
    end
    self.view.innFoodTray:OnChangeInputDeviceTypeFinished(args)
    local maxNum = self.m_innSystem.menuDrinkMaxNum
    for i = 1, maxNum do
        local item = self.m_drinkItems[i]
        if item then
            local cell = self.m_getDrinkCell(i)
            if cell then
                cell:OnChangeInputDeviceTypeFinished()
            end
        end
    end
end

InnDrinkMenuPopUpCtrl._OnConfirmChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    self.view.innFoodTray:OnConfirmChangeInputDeviceType(args)
end

InnDrinkMenuPopUpCtrl._SetFirstCellNaviTarget = HL.Method() << function(self)
    local firstCell = self.m_getDrinkCell(self.view.scrollList:Get(0))
    if firstCell then
        self:SetNaviTarget(firstCell.view.naviTarget)
    end
end

InnDrinkMenuPopUpCtrl._HideAndShowMainHud = HL.Method() << function(self)
    self:PlayAnimationOutAndHide()
    Notify(MessageConst.ON_INN_SHOW_MAIN_HUD)
end

HL.Commit(InnDrinkMenuPopUpCtrl)
