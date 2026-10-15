local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnFoodTray = HL.Class('InnFoodTray', UIWidgetBase)

local Mode = InnConst.INN_FOOD_TRAY_MODE




InnFoodTray.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnFoodTray.m_args = HL.Field(HL.Table) << nil

InnFoodTray.m_mode = HL.Field(HL.Number) << Mode.Normal

InnFoodTray.m_trayCellCache = HL.Field(HL.Forward("UIListCache")) << nil


InnFoodTray.m_servingCounterInstIdStack = HL.Field(HL.Table) << nil


InnFoodTray.m_currentServingCounterId = HL.Field(HL.Number) << 0


InnFoodTray.m_barCounterInstIdStack = HL.Field(HL.Table) << nil

InnFoodTray.m_manualFocusBindingId = HL.Field(HL.Number) << -1

InnFoodTray.m_manualUnFocusBindingId = HL.Field(HL.Number) << -1

InnFoodTray.m_nextFoodBindingId = HL.Field(HL.Number) << -1

InnFoodTray.m_previousFoodBindingId = HL.Field(HL.Number) << -1

InnFoodTray.m_isReplacingDrink = HL.Field(HL.Boolean) << false

InnFoodTray.m_replacingItemId = HL.Field(HL.String) << ""



InnFoodTray._OnFirstTimeInit = HL.Override() << function(self)
    self.m_servingCounterInstIdStack = {}
    self.m_barCounterInstIdStack = {}
    self.m_currentServingCounterId = 0
    self.m_mode = Mode.Normal

    self:RegisterMessage(MessageConst.ON_INN_FOOD_TRAY_CHANGED, function()
        self:_RefreshTrayCells()
        if self.m_isReplacingDrink then
            self:StopReplaceDrink()
        end
    end)
    self:RegisterMessage(MessageConst.ON_INN_HELD_FOOD_TRAY_SLOT_CHANGED, function()
        self:_UpdateSwitchKeyHintVisibility()
        self:_UpdateActiveKeyHintVisibility()
        self:_ApplyHoldNodes()
        self:_ApplyTags()
    end)
    self:RegisterMessage(MessageConst.ON_INN_ENTER_SERVING_COUNTER, function(args)
        self:_OnEnterServingCounter(args)
    end)
    self:RegisterMessage(MessageConst.ON_INN_EXIT_SERVING_COUNTER, function(args)
        self:_OnExitServingCounter(args)
    end)
    self:RegisterMessage(MessageConst.ON_INN_ENTER_BAR_COUNTER, function(args)
        self:_OnEnterBarCounter(args)
    end)
    self:RegisterMessage(MessageConst.ON_INN_EXIT_BAR_COUNTER, function(args)
        self:_OnExitBarCounter(args)
    end)
    self:RegisterMessage(MessageConst.ON_INN_SERVING_COUNTER_CHANGED, function()
        self:_RefreshMode()
    end)


    self.view.selectableNaviGroup.onIsTopLayerChanged:AddListener(function(isTopLayer)
        self:_OnIsTopLayerChanged(isTopLayer)
    end)
    self.view.selectableNaviGroup.getDefaultSelectableFunc = function()
        return self:_GetDefaultSelectable()
    end
    if self.m_mode ~= Mode.Drink then
        self.m_manualFocusBindingId = self:BindInputPlayerAction("fac_activate_quick_bar", function()
            if self:GetHeldFood() == nil then
                return
            end
            self.view.selectableNaviGroup:ClearLastFocusNaviTarget()
            self.view.selectableNaviGroup:ManuallyFocus()
        end)
        self.m_manualUnFocusBindingId = self:BindInputPlayerAction("fac_deactivate_quick_bar", function()
            self.view.selectableNaviGroup:ManuallyStopFocus()
        end)
        self.m_nextFoodBindingId = self:BindInputPlayerAction("inn_food_tray_next_food", function()
            self:_SwitchHeldFoodByStep(1)
        end)
        self.m_previousFoodBindingId = self:BindInputPlayerAction("inn_food_tray_previous_food", function()
            self:_SwitchHeldFoodByStep(-1)
        end)
    end
end

InnFoodTray.InitInnFoodTray = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    self.m_args = args or {}
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_mode = (self.m_args.isPickUpDrink == true) and Mode.Drink or Mode.Normal
    self:_RefreshTrayCells()
    self:_UpdateSwitchKeyHintVisibility()

    self.view.barNodeSimpleActiveAnimationHelper.enabled = DeviceInfo.usingController and self.m_mode ~= Mode.Drink
    self:_UpdateActiveKeyHintVisibility()

    self.view.putBackHint.gameObject:SetActive(false)
end

InnFoodTray._OnCreate = HL.Override() << function(self)
    if self.m_mode ~= Mode.Drink then
        Notify(MessageConst.DISABLE_BATTLE_INDICATOR_CONTROLLER, {true, "InnFoodTray"})   
    end
end

InnFoodTray._OnDestroy = HL.Override() << function(self)
    if self.m_mode ~= Mode.Drink then
        Notify(MessageConst.DISABLE_BATTLE_INDICATOR_CONTROLLER, {false, "InnFoodTray"})
    end
end

InnFoodTray.GetHeldFood = HL.Method().Return(HL.Userdata) << function(self)
    if not self.m_innSystem then
        return nil
    end
    return self.m_innSystem:GetHeldFood()
end

InnFoodTray.GetHeldSlotIndex = HL.Method().Return(HL.Number) << function(self)
    local gs = self.m_innSystem and self.m_innSystem.gameState
    return gs and gs.heldFoodTraySlot or 0
end

InnFoodTray._GetFoodAtSlot = HL.Method(HL.Number).Return(HL.Userdata) << function(self, slotIndex)
    local gs = self.m_innSystem and self.m_innSystem.gameState
    if not gs or not gs.foodTrayFoodIds or not gs.foods then
        return nil
    end
    local hasFoodId, foodId = gs.foodTrayFoodIds:TryGetValue(slotIndex)
    if not hasFoodId then
        return nil
    end
    local hasFood, food = gs.foods:TryGetValue(foodId)
    if not hasFood then
        return nil
    end
    return food
end

InnFoodTray._UpdateSwitchKeyHintVisibility = HL.Method() << function(self)
    local unlockedSize = self.m_innSystem and self.m_innSystem.foodTraySize or 0
    local enable = self.m_mode ~= Mode.Drink and unlockedSize > 1 and self:GetHeldSlotIndex() > 0 and 
        (not self.view.selectableNaviGroup.IsTopLayer or not DeviceInfo.usingController)
    InputManagerInst:ToggleBinding(self.m_nextFoodBindingId, enable)
    InputManagerInst:ToggleBinding(self.m_previousFoodBindingId, enable)
    self.view.switchKeyHint.gameObject:SetActive(enable)
end

InnFoodTray._UpdateActiveKeyHintVisibility = HL.Method() << function(self)
    if self.m_mode ~= Mode.Drink then
        self.view.activeKeyHint.gameObject:SetActive(DeviceInfo.usingController and 
            not self.view.selectableNaviGroup.IsTopLayer and 
            self:GetHeldSlotIndex() > 0)
    end
end





InnFoodTray._ComputeCounterMode = HL.Method().Return(HL.Number) << function(self)
    if self.m_currentServingCounterId > 0 then
        if self:_CurrentCounterHasFood() then
            return Mode.PickUpDish
        end
        return Mode.PutBackDish
    end
    if self.m_barCounterInstIdStack and #self.m_barCounterInstIdStack > 0 then
        return Mode.PutBackDrink
    end
    return Mode.Normal
end

InnFoodTray._CurrentCounterHasFood = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_currentServingCounterId <= 0 then
        return false
    end
    local gs = self.m_innSystem and self.m_innSystem.gameState
    if not gs or not gs.servingCounterFoodIds or not gs.foods then
        return false
    end
    local hasFoodId, foodId = gs.servingCounterFoodIds:TryGetValue(self.m_currentServingCounterId)
    if not hasFoodId then
        return false
    end
    local hasFood, food = gs.foods:TryGetValue(foodId)
    if not hasFood or not food or string.isEmpty(food.itemId) then
        return false
    end
    return true
end

InnFoodTray._RefreshMode = HL.Method() << function(self)
    if self.m_mode == Mode.Drink then
        return
    end
    local newMode = self:_ComputeCounterMode()
    if newMode == self.m_mode then
        return
    end
    self.m_mode = newMode
    self:_ApplyTags()
end





InnFoodTray._ApplyHoldNodes = HL.Method() << function(self)
    if not self.m_trayCellCache then
        return
    end
    local gs = self.m_innSystem and self.m_innSystem.gameState
    local heldSlot = gs and gs.heldFoodTraySlot or 0
    local hasHeldFood = self:GetHeldFood() ~= nil
    self.m_trayCellCache:Update(function(cell, index)
        cell:SetHoldNodeActive(hasHeldFood and index == heldSlot, true)
    end)
end





InnFoodTray._RefreshTrayCells = HL.Method() << function(self)
    if not self.view.trayCell or not self.view.container then
        return
    end

    
    if self.m_mode ~= Mode.Drink then
        self.m_mode = self:_ComputeCounterMode()
    end

    local totalSize = self.m_innSystem.foodTrayMaxSize
    local unlockedSize = self.m_innSystem.foodTraySize

    local mode = self.m_mode
    local drinkType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink
    local gs = self.m_innSystem.gameState
    local heldSlot = gs and gs.heldFoodTraySlot or 0

    self.m_trayCellCache = self.m_trayCellCache
        or UIUtils.genCellCache(self.view.trayCell, nil, self.view.container)
    self.m_trayCellCache:Refresh(totalSize, function(cell, index)
        local isLocked = index > unlockedSize
        local food = self:_GetFoodAtSlot(index)
        local hasFood = food ~= nil
        local isDrink = hasFood and food.foodType == drinkType
        local showPutBack = mode == Mode.Drink and isDrink

        local onClick
        if mode == Mode.Drink then
            onClick = function(clickedFood)
                if hasFood and not isDrink then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DRINK_COUNTER_PUT_BACK_DISH_TOAST)         
                    return
                end
                if showPutBack then
                    self:_OnReturnDrinkClick(clickedFood, index)
                end
            end
        elseif hasFood and not isLocked then
            onClick = function()
                self:_OnSwitchHeldClick(index)
            end
        end

        local cellActionId
        if mode ~= Mode.Drink and unlockedSize > 1 then
            cellActionId = "inn_food_tray_item_" .. index
        end
        cell:InitInnTrayCell({
            food = food,
            isLocked = isLocked,
            onClick = onClick,
            actionId = cellActionId,
            isDishBlack = mode == Mode.Drink and hasFood and not isDrink,
        })
        cell:SetPutBackNodeActive(showPutBack)
        cell:SetHoldNodeActive(hasFood and index == heldSlot)

        if mode == Mode.Drink then
            local actionId
            if showPutBack then
                actionId = "inn_put_back_drink"
            else
                actionId = "inn_put_back_drink_invalid"
            end
            if cell.hoverBindingGroupId > 0 then
                InputManagerInst:DeleteBinding(cell.hoverBindingGroupId)
            end
            cell.hoverBindingGroupId = InputManagerInst:CreateBindingByActionId(actionId, function()
                onClick(food)
            end, cell.view.trayBtn.hoverBindingGroupId)

            cell.view.trayBtn.onIsNaviTargetChanged = function(isNaviTarget)
                self.view.putBackHint.gameObject:SetActive(DeviceInfo.usingController and isDrink and isNaviTarget)
                if self.m_isReplacingDrink then
                    self.m_trayCellCache:Update(function(cell, index)
                        cell:SetInTagActive(cell.view.trayBtn.isNaviTarget)
                    end)
                end
            end
            if cell.view.trayBtn.isNaviTarget then
                self.view.putBackHint.gameObject:SetActive(DeviceInfo.usingController and isDrink)
            end
        end
    end)

    self:_ApplyTags()
end

InnFoodTray._ApplyTags = HL.Method() << function(self)
    if not self.m_trayCellCache then
        return
    end
    local mode = self.m_mode
    local unlockedSize = self.m_innSystem and self.m_innSystem.foodTraySize or 0

    local inTagSlotIndex = 0
    if (mode == Mode.PickUpDish or mode == Mode.Drink) and not self.view.selectableNaviGroup.IsTopLayer then
        for i = 1, unlockedSize do
            if self:_GetFoodAtSlot(i) == nil then
                inTagSlotIndex = i
                break
            end
        end
    end

    
    local heldSlot = (self.m_innSystem and self.m_innSystem.gameState and self.m_innSystem.gameState.heldFoodTraySlot) or 0
    local outTagSlotIndex = 0
    if heldSlot > 0 and not self.view.selectableNaviGroup.IsTopLayer then
        local heldFood = self:_GetFoodAtSlot(heldSlot)
        local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
        if heldFood then
            local canPutBackDish = mode == Mode.PutBackDish and heldFood.foodType == FOOD_TYPE.FoodTypeDish
            local canPutBackDrink = mode == Mode.PutBackDrink and heldFood.foodType == FOOD_TYPE.FoodTypeDrink
            if canPutBackDish or canPutBackDrink then
                outTagSlotIndex = heldSlot
            end
        end
    end

    self.m_trayCellCache:Update(function(cell, index)
        cell:SetInTagActive(index == inTagSlotIndex)
        cell:SetOutTagActive(index == outTagSlotIndex)
    end)
end





InnFoodTray._OnSwitchHeldClick = HL.Method(HL.Number) << function(self, slotIndex)
    if not self.m_innSystem then
        return
    end
    local gs = self.m_innSystem.gameState
    local currentSlot = gs and gs.heldFoodTraySlot or 0
    if slotIndex == currentSlot then
        return
    end
    if self:_GetFoodAtSlot(slotIndex) == nil then
        return
    end
    self.m_innSystem:SetHeldFoodTraySlot(slotIndex)
end

InnFoodTray._SwitchHeldFoodByStep = HL.Method(HL.Number) << function(self, step)
    if not self.m_innSystem then
        return
    end

    if self.m_mode == Mode.Drink then
        return
    end

    
    local slots = {}
    local unlockedSize = self.m_innSystem.foodTraySize
    for i = 1, unlockedSize do
        if self:_GetFoodAtSlot(i) ~= nil then
            slots[#slots + 1] = i
        end
    end
    if #slots == 0 then
        return
    end

    
    local cur = self:GetHeldSlotIndex()
    local curIdx = nil
    for i, s in ipairs(slots) do
        if s == cur then
            curIdx = i
            break
        end
    end
    local nextIdx
    if curIdx == nil then
        nextIdx = step > 0 and 1 or #slots
    else
        nextIdx = ((curIdx - 1 + step) % #slots) + 1
    end

    local target = slots[nextIdx]
    if target == cur then
        return
    end
    AudioAdapter.PostEvent("Au_UI_Button_Reset")
    self.m_innSystem:SetHeldFoodTraySlot(target)
end

InnFoodTray._OnReturnDrinkClick = HL.Method(HL.Userdata, HL.Number) << function(self, food, slotIndex)
    if not food or not self.m_innSystem then
        return
    end
    local drinkType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink
    if food.foodType ~= drinkType then
        return
    end
    if self.m_isReplacingDrink and slotIndex then
        self.m_innSystem:SendPickUpDrink(self.m_replacingItemId, slotIndex)
    else
        self.m_innSystem:SendReturnDrink({ food.id })
    end
end






InnFoodTray._PushInstId = HL.Method(HL.Table, HL.String) << function(self, stack, instId)
    for i = #stack, 1, -1 do
        if stack[i] == instId then
            table.remove(stack, i)
        end
    end
    table.insert(stack, instId)
end


InnFoodTray._RemoveInstId = HL.Method(HL.Table, HL.String) << function(self, stack, instId)
    for i = #stack, 1, -1 do
        if stack[i] == instId then
            table.remove(stack, i)
            break
        end
    end
end


InnFoodTray._OnEnterServingCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end
    self:_PushInstId(self.m_servingCounterInstIdStack, instId)
    self:_RefreshCurrentServingCounterId()
    self:_RefreshMode()
end


InnFoodTray._OnExitServingCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end
    self:_RemoveInstId(self.m_servingCounterInstIdStack, instId)
    self:_RefreshCurrentServingCounterId()
    self:_RefreshMode()
end


InnFoodTray._OnEnterBarCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end
    self:_PushInstId(self.m_barCounterInstIdStack, instId)
    self:_RefreshMode()
end


InnFoodTray._OnExitBarCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end
    self:_RemoveInstId(self.m_barCounterInstIdStack, instId)
    self:_RefreshMode()
end


InnFoodTray._RefreshCurrentServingCounterId = HL.Method() << function(self)
    local topInstId = self.m_servingCounterInstIdStack[#self.m_servingCounterInstIdStack]
    if topInstId and self.m_innSystem then
        self.m_currentServingCounterId = self.m_innSystem:GetServingCounterIdByKey(topInstId)
    else
        self.m_currentServingCounterId = 0
    end
end





InnFoodTray._OnIsTopLayerChanged = HL.Method(HL.Boolean) << function(self, isTopLayer)
    self:_ApplyTags()
    if self.m_mode == Mode.Drink then
        self.view.putBackHint.gameObject:SetActive(DeviceInfo.usingController and self.m_mode == Mode.Drink and isTopLayer)
        self:_UpdatePutBackTxt()
    else
        self:_UpdateSwitchKeyHintVisibility()
        self:_UpdateActiveKeyHintVisibility()
        self.view.barNodeSimpleActiveAnimationHelper.isActive = isTopLayer
        Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { "innFoodTray", isTopLayer })
        local isOpen, jsPanelCtrl = UIManager:IsOpen(PanelId.Joystick)
        if isOpen then
            local jsGroupId = jsPanelCtrl.view.joystick.groupId
            if isTopLayer then
                InputManagerInst:ChangeParent(true, jsGroupId, self.view.inputGroup.groupId)
            else
                InputManagerInst:ChangeParent(true, jsGroupId, jsPanelCtrl.view.inputGroup.groupId)
            end
        end
    end
end
InnFoodTray._GetDefaultSelectable = HL.Method().Return(HL.Any) << function(self)
    if self.m_mode == Mode.Drink then
        if not self.m_trayCellCache then
            return nil
        end
        local drinkType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink
        local totalSize = self.m_innSystem and self.m_innSystem.foodTrayMaxSize or 0
        
        for i = 1, totalSize do
            local food = self:_GetFoodAtSlot(i)
            if food and food.foodType == drinkType then
                local cell = self.m_trayCellCache:GetItem(i)
                if cell then
                    return cell.view.trayBtn
                end
            end
        end
        
        local firstCell = self.m_trayCellCache:GetItem(1)
        if firstCell then
            return firstCell.view.trayBtn
        end
        return nil
    else
        local cell = self.m_trayCellCache:GetItem(self:GetHeldSlotIndex())
        if cell then
            return cell.view.trayBtn
        end
        return nil
    end
end

InnFoodTray._IsTrayAllDish = HL.Method().Return(HL.Boolean) << function(self)
    local unlockedSize = self.m_innSystem and self.m_innSystem.foodTraySize or 0
    if unlockedSize <= 0 then
        return false
    end
    local dishType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish
    for i = 1, unlockedSize do
        local food = self:_GetFoodAtSlot(i)
        if not food or food.foodType ~= dishType then
            return false
        end
    end
    return true
end

InnFoodTray.StartReplaceDrink = HL.Method(HL.String) << function(self, itemId)
    if self:_IsTrayAllDish() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DRINK_TRAY_FULL)
        return
    end
    self.m_isReplacingDrink = true
    self.m_replacingItemId = itemId
    self.view.selectableNaviGroup:ManuallyFocus()
    self:_UpdatePutBackTxt()
end

InnFoodTray.StopReplaceDrink = HL.Method() << function(self)
    self.m_isReplacingDrink = false
    self.view.selectableNaviGroup:ManuallyStopFocus()
    self:_UpdatePutBackTxt()
end

InnFoodTray._UpdatePutBackTxt = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    self.view.putBackTxt.text = self.m_isReplacingDrink and Language.ui_inn_replace_drink or Language.ui_inn_put_back_drink
end

InnFoodTray.OnChangeInputDeviceTypeFinished = HL.Method(HL.Any) << function(self, args)
    self.view.barNodeSimpleActiveAnimationHelper.enabled = DeviceInfo.usingController and self.m_mode ~= Mode.Drink
    self:_UpdateActiveKeyHintVisibility()
    if self.m_mode ~= Mode.Drink then
        Notify(MessageConst.DISABLE_BATTLE_INDICATOR_CONTROLLER, {true, "InnFoodTray"})   
    end
    self.view.selectableNaviGroup:ManuallyRefreshRelatedBindingGroups()
    self.view.selectableNaviGroup:RefreshFocusBindings()
end

InnFoodTray.OnConfirmChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    self.view.selectableNaviGroup:ManuallyStopFocus()
end



HL.Commit(InnFoodTray)
return InnFoodTray
