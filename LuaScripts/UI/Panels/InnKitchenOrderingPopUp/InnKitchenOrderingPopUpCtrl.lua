local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnKitchenOrderingPopUp

InnKitchenOrderingPopUpCtrl = HL.Class('InnKitchenOrderingPopUpCtrl', uiCtrl.UICtrl)

InnKitchenOrderingPopUpCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnKitchenOrderingPopUpCtrl.m_tabCells = HL.Field(HL.Forward('UIListCache'))

InnKitchenOrderingPopUpCtrl.m_tabTagCaches = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_tabQueueStateCaches = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_menuItems = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_getRecipeCell = HL.Field(HL.Function)

InnKitchenOrderingPopUpCtrl.m_showIngredient = HL.Field(HL.Boolean) << false

InnKitchenOrderingPopUpCtrl.m_curKitchenId = HL.Field(HL.Number) << 1

InnKitchenOrderingPopUpCtrl.m_sortedKitchenSettings = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_categoryTagCache = HL.Field(HL.Any) << nil

InnKitchenOrderingPopUpCtrl.m_affixTagCache = HL.Field(HL.Any) << nil


InnKitchenOrderingPopUpCtrl.m_kitchenTagUpCounts = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_cachedKitchenState = HL.Field(CS.Beyond.Gameplay.InnSystem.KitchenState)

InnKitchenOrderingPopUpCtrl.m_kitchenProgressCoroutine = HL.Field(HL.Thread) << nil


InnKitchenOrderingPopUpCtrl.m_speedBoostCache = HL.Field(HL.Table)


InnKitchenOrderingPopUpCtrl.m_dishDemand = HL.Field(HL.Table)

InnKitchenOrderingPopUpCtrl.m_deskStateCellCache = HL.Field(HL.Forward("UIListCache"))

InnKitchenOrderingPopUpCtrl.m_soldOutTipsState = HL.Field(HL.String) << ""

InnKitchenOrderingPopUpCtrl.m_soldOutTipsPendingTimerId = HL.Field(HL.Number) << -1





InnKitchenOrderingPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_KITCHEN_STATE_CHANGED] = '_OnKitchenStateChanged',
    [MessageConst.ON_INN_GUEST_STATE_CHANGED] = '_OnDishDemandSourceChanged',
    [MessageConst.ON_INN_GUEST_QUEUE_CHANGED] = '_OnDishDemandSourceChanged',
    [MessageConst.ON_INN_DESK_STATE_CHANGED] = '_OnDishDemandSourceChanged',
    [MessageConst.ON_INN_SERVING_COUNTER_CHANGED] = '_OnRemainingDishSourceChanged',
    [MessageConst.ON_INN_FOOD_TRAY_CHANGED] = '_OnRemainingDishSourceChanged',
    [MessageConst.ON_INN_IN_RUSH_CHANGED] = '_OnInRushChanged',
    [MessageConst.ON_INN_GAME_TIME_WRAP_UP_CHANGED] = '_OnGameTimeWrapUpChanged',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = '_OnItemCountChanged',
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnChangeInputDeviceTypeFinished',
    [MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE] = '_OnConfirmChangeInputDeviceType',
}


InnKitchenOrderingPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_tabCells = UIUtils.genCellCache(self.view.tabs.tabCell)
    self.m_tabTagCaches = {}
    self.m_tabQueueStateCaches = {}
    self.m_speedBoostCache = {}
    self:_BuildSortedKitchenSettings()
    self:_NormalizeCurKitchenId()
    self.m_menuItems = {}
    self.m_getRecipeCell = UIUtils.genCachedCellFunction(self.view.recipeList)
    self.view.recipeList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateRecipeCell(self.m_getRecipeCell(obj), LuaIndex(csIndex))
    end)
    self.view.innCountDown:InitInnCountDown()
    self:_InitAction()
    self:_InitDeskStates()
    self:_RefreshKitchenTabs()
    self:_RefreshKitchenInfo()
    self:_RefreshRecipeList()
    self:_RefreshSoldOutTips()
    self:BindInputPlayerAction("inn_open_kitchen", function()
        self:_HideAndShowMainHud()
    end)
    self:InitController()  
end

InnKitchenOrderingPopUpCtrl.OnClose = HL.Override() << function(self)
    self.m_soldOutTipsPendingTimerId = self:_ClearTimer(self.m_soldOutTipsPendingTimerId)
    if self.m_kitchenProgressCoroutine then
        self.m_kitchenProgressCoroutine = self:_ClearCoroutine(self.m_kitchenProgressCoroutine)
    end
end

InnKitchenOrderingPopUpCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.ON_INN_HIDE_MAIN_HUD)
    local firstKitchen = self.m_sortedKitchenSettings[1]
    if firstKitchen then
        self:SelectKitchenTab(firstKitchen.id)
    end
    self:_RefreshSoldOutTips()
    if DeviceInfo.usingController then
        self:_SetFirstScrollNaviTarget()
    end
end

InnKitchenOrderingPopUpCtrl.SelectKitchenTab = HL.Method(HL.Number) << function(self, kitchenId)
    local tabIndex = self:_GetKitchenTabIndex(kitchenId)
    local cell = tabIndex > 0 and self.m_tabCells:GetItem(tabIndex) or nil
    if cell and cell.toggle then
        cell.toggle.isOn = true
    end
end

InnKitchenOrderingPopUpCtrl._BuildSortedKitchenSettings = HL.Method() << function(self)
    local list = {}
    local settings = self.m_innSystem.gameSetting and self.m_innSystem.gameSetting.kitchenSettings
    if settings and settings.Count > 0 then
        for i = 0, settings.Count - 1 do
            local ks = settings[i]
            if ks then
                list[#list + 1] = ks
            end
        end
    end
    table.sort(list, function(a, b)
        return a.id < b.id
    end)
    self.m_sortedKitchenSettings = list
end


InnKitchenOrderingPopUpCtrl._GetKitchenTabIndex = HL.Method(HL.Number).Return(HL.Number) << function(self, kitchenId)
    for index, ks in ipairs(self.m_sortedKitchenSettings) do
        if ks.id == kitchenId then
            return index
        end
    end
    return 0
end

InnKitchenOrderingPopUpCtrl._InitAction = HL.Method() << function(self)
    self.view.closeButton.onClick:AddListener(function()
        self:_HideAndShowMainHud()
    end)
    self.view.showIngredientToggle:InitCommonToggle(function(isOn)
        self.m_showIngredient = isOn
        Notify(MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT, isOn)
    end, false, true)
    local skillDetailBtn = self.view.leftNode and self.view.leftNode.skillDetailBtn
    if skillDetailBtn then
        skillDetailBtn.onClick:AddListener(function()
            UIManager:Open(PanelId.InnKitchenAdditionDetails, { kitchenId = self:_GetCurrentKitchenId() })
        end)
    end
end

InnKitchenOrderingPopUpCtrl._InitDeskStates = HL.Method() << function(self)
    self.m_deskStateCellCache = self.m_deskStateCellCache or UIUtils.genCellCache(self.view.innDeskStateCell)
    self.m_deskStateCellCache:Refresh(self.m_innSystem.deskNum, function(cell, index)
        cell:InitInnDeskStateCell({ deskId = index })
    end)
end

InnKitchenOrderingPopUpCtrl._HideAndShowMainHud = HL.Method() << function(self)
    self:PlayAnimationOutAndHide()
    Notify(MessageConst.ON_INN_SHOW_MAIN_HUD)
end



InnKitchenOrderingPopUpCtrl._NormalizeCurKitchenId = HL.Method() << function(self)
    if InnUtils.findKitchenSetting(self.m_curKitchenId) ~= nil then
        return
    end
    local firstKitchen = self.m_sortedKitchenSettings[1]
    if firstKitchen then
        self.m_curKitchenId = firstKitchen.id
    end
end

InnKitchenOrderingPopUpCtrl._RefreshKitchenTabs = HL.Method() << function(self)
    local topicId = self.m_innSystem.gameSetting.topicId
    self:_BuildSortedKitchenSettings()
    local kitchenSettings = self.m_sortedKitchenSettings
    local kitchenCount = #kitchenSettings
    self.view.keyHintLeft.gameObject:SetActive(kitchenCount > 1)
    self.view.keyHintRight.gameObject:SetActive(kitchenCount > 1)

    self.m_tabCells:Refresh(kitchenCount, function(cell, index)
        local kitchenId = kitchenSettings[index].id
        if cell.tabNameTxt then
            cell.tabNameTxt.text = Language[string.format("LUA_INN_KITCHEN_NAME_%d", kitchenId)]
        end
        local catRows, affRows = InnUtils.getKitchenSkillTagRows(kitchenId, topicId)
        local merged = lume.concat(catRows, affRows)
        if cell.innItemTag then
            if not self.m_tabTagCaches[index] then
                self.m_tabTagCaches[index] = UIUtils.genCellCache(cell.innItemTag)
            end
            self.m_tabTagCaches[index]:Refresh(#merged, function(tagCell, tagIndex)
                
                local tagArgs = merged[tagIndex].args
                tagArgs.isHot = false
                tagCell:InitInnItemTag(tagArgs)
            end)
        end
        if cell.toggle then
            cell.toggle.onValueChanged:RemoveAllListeners()
            cell.toggle.isOn = (kitchenId == self.m_curKitchenId)
            cell.toggle.onValueChanged:AddListener(function(isOn)
                if isOn then
                    if self.m_curKitchenId == kitchenId then
                        return
                    end
                    self.m_curKitchenId = kitchenId
                    self:_RefreshKitchenInfo()
                    self:_RefreshAllRecipeCookTime()
                    self:_RefreshAllRecipeTagUpCounts()
                end
            end)
        end
        self:_RefreshTabQueueState(cell, index, kitchenId)
    end)
end

InnKitchenOrderingPopUpCtrl._GetKitchenQueueFilledCount = HL.Method(HL.Number).Return(HL.Number) << function(self, kitchenId)
    local gs = self.m_innSystem.gameState
    if not (gs and gs.kitchenStates) then
        return 0
    end
    local hasState, st = gs.kitchenStates:TryGetValue(kitchenId)
    if not (hasState and st) then
        return 0
    end
    local filled = 0
    if not string.isEmpty(st.cookingFoodItemId) then
        filled = filled + 1
    end
    if st.waitingFoodItemIds then
        filled = filled + st.waitingFoodItemIds.Count
    end
    return filled
end

InnKitchenOrderingPopUpCtrl._RefreshTabQueueState = HL.Method(HL.Any, HL.Number, HL.Number) << function(self, cell, index, kitchenId)
    if not cell or not cell.foodQueueStateCell then
        return
    end
    if not self.m_tabQueueStateCaches[index] then
        self.m_tabQueueStateCaches[index] = UIUtils.genCellCache(cell.foodQueueStateCell)
    end
    local filled = self:_GetKitchenQueueFilledCount(kitchenId)
    local queueSize = self.m_innSystem.kitchenQueueSize
    self.m_tabQueueStateCaches[index]:Refresh(queueSize, function(stateCell, stateIndex)
        if stateCell.stateController then
            stateCell.stateController:SetState(stateIndex <= filled and "Queue" or "Empty")
        end
    end)
end

InnKitchenOrderingPopUpCtrl._RefreshAllTabQueueStates = HL.Method() << function(self)
    local kitchenSettings = self.m_sortedKitchenSettings
    if kitchenSettings == nil or #kitchenSettings == 0 then
        return
    end
    local count = self.m_tabCells:GetCount()
    for index = 1, count do
        local cell = self.m_tabCells:GetItem(index)
        local setting = kitchenSettings[index]
        if cell and setting then
            self:_RefreshTabQueueState(cell, index, setting.id)
        end
    end
end

InnKitchenOrderingPopUpCtrl._GetCurrentKitchenId = HL.Method().Return(HL.Number) << function(self)
    local id = self.m_curKitchenId
    if id and id > 0 and InnUtils.findKitchenSetting(id) ~= nil then
        return id
    end
    return 0
end

InnKitchenOrderingPopUpCtrl._GetUnlockedKitchenCharSlotNum = HL.Method().Return(HL.Number) << function(self)
    return self.m_innSystem.kitchenCharSlotNum
end

InnKitchenOrderingPopUpCtrl._RefreshKitchenInfo = HL.Method() << function(self)
    self:_RefreshKitchenChars()
    self:_RefreshKitchenSkillTags()
    self:_RefreshKitchenFoodQueue()
    self:_RefreshRareRate()
end

InnKitchenOrderingPopUpCtrl._RefreshKitchenChars = HL.Method() << function(self)
    local kitchenId = self:_GetCurrentKitchenId()
    local kitchenSetting = InnUtils.findKitchenSetting(kitchenId)
    local charStrIds = InnUtils.kitchenCharStringIds(kitchenSetting)
    local unlockedSlots = self:_GetUnlockedKitchenCharSlotNum()
    local leftNode = self.view.leftNode
    local cells = { leftNode.kitchenCharCell01, leftNode.kitchenCharCell02 }
    for i, cell in ipairs(cells) do
        if not cell or not cell.stateController then
            goto continue
        end
        if i > unlockedSlots then
            cell.stateController:SetState("Lock")
        elseif charStrIds[i] and not string.isEmpty(charStrIds[i]) then
            cell.stateController:SetState("Char")
            local charId = charStrIds[i]
            if cell.charImg then
                local spriteName = UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. charId
                cell.charImg:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, spriteName)
            end
            local hasTag, tagData = Tables.characterTagTable:TryGetValue(charId)
            if hasTag and tagData and cell.nameTxt then
                cell.nameTxt.text = tagData.innNickname or ""
            end
        else
            cell.stateController:SetState("Blank")
        end
        ::continue::
    end
end

InnKitchenOrderingPopUpCtrl._RefreshKitchenSkillTags = HL.Method() << function(self)
    local kitchenId = self:_GetCurrentKitchenId()
    local topicId = self.m_innSystem.gameSetting.topicId or ""
    local catRows, affRows = InnUtils.getKitchenSkillTagRows(kitchenId, topicId)
    local leftNode = self.view.leftNode

    local upCounts = {}
    for _, row in ipairs(catRows) do
        upCounts[row.tagId] = row.args.upCount
    end
    for _, row in ipairs(affRows) do
        upCounts[row.tagId] = row.args.upCount
    end
    self.m_kitchenTagUpCounts = upCounts

    if leftNode.innItemTagCategory and not self.m_categoryTagCache then
        self.m_categoryTagCache = UIUtils.genCellCache(leftNode.innItemTagCategory)
    end
    if leftNode.innItemTagAffix and not self.m_affixTagCache then
        self.m_affixTagCache = UIUtils.genCellCache(leftNode.innItemTagAffix)
    end
    if self.m_categoryTagCache then
        self.m_categoryTagCache:Refresh(#catRows, function(cell, index)
            cell:InitInnItemTag(catRows[index].args)
        end)
    end
    if self.m_affixTagCache then
        self.m_affixTagCache:Refresh(#affRows, function(cell, index)
            cell:InitInnItemTag(affRows[index].args)
        end)
    end
end

InnKitchenOrderingPopUpCtrl._SyncKitchenStateCache = HL.Method() << function(self)
    self.m_cachedKitchenState = nil
    local gs = self.m_innSystem.gameState
    if gs and gs.kitchenStates then
        local kitchenId = self:_GetCurrentKitchenId()
        local hasState, st = gs.kitchenStates:TryGetValue(kitchenId)
        if hasState then
            self.m_cachedKitchenState = st
        end
    end
end



InnKitchenOrderingPopUpCtrl._GetCachedSpeedBoost = HL.Method(HL.Number, HL.String).Return(HL.Number) << function(self, kitchenId, itemId)
    if not kitchenId or kitchenId <= 0 or string.isEmpty(itemId) then
        return 0
    end
    local byDish = self.m_speedBoostCache[kitchenId]
    if not byDish then
        byDish = {}
        self.m_speedBoostCache[kitchenId] = byDish
    end
    local boost = byDish[itemId]
    if not boost then
        boost = InnUtils.getKitchenSpeedBoost(kitchenId, itemId)
        byDish[itemId] = boost
    end
    return boost
end

InnKitchenOrderingPopUpCtrl._GetCookElapsedMs = HL.Method(CS.Beyond.Gameplay.InnSystem.KitchenState).Return(HL.Number) << function(self, kitchenState)
    if not kitchenState or string.isEmpty(kitchenState.cookingFoodItemId) then
        return 0
    end
    local boost = self:_GetCachedSpeedBoost(kitchenState.id, kitchenState.cookingFoodItemId)
    return self.m_innSystem:GetKitchenRealtimeElapsedMs(kitchenState, boost)
end

InnKitchenOrderingPopUpCtrl._ApplyFoodCell = HL.Method(HL.Any, HL.Opt(HL.Table)) << function(self, cell, slot)
    if not cell or not cell.stateController then
        return
    end
    if cell.btnMinus then
        cell.btnMinus.onClick:RemoveAllListeners()
    end
    if not slot or string.isEmpty(slot.itemId) then
        cell.stateController:SetState("EmptyState")
        return
    end
    if slot.isCooking then
        cell.stateController:SetState("MakeState")
        self:_RefreshCookingCellProgress()
    else
        cell.stateController:SetState("WaitState")
    end
    if cell.itemIcon then
        cell.itemIcon:InitItemIcon(slot.itemId)
    end
    if cell.btnMinus then
        local kitchenId = self:_GetCurrentKitchenId()
        local isCooking = slot.isCooking and true or false
        local waitQueueIndex = slot.waitQueueIndex or 0
        cell.btnMinus.onClick:AddListener(function()
            self.m_innSystem:SendCancelOrder(kitchenId, isCooking, waitQueueIndex)
        end)
    end
end

InnKitchenOrderingPopUpCtrl._RefreshKitchenFoodQueue = HL.Method() << function(self)
    self:_SyncKitchenStateCache()
    local kitchenState = self.m_cachedKitchenState
    local leftNode = self.view.leftNode

    local unlockedQueueSize = self.m_innSystem.kitchenQueueSize
    if leftNode.foodQueueStateCtrl then
        leftNode.foodQueueStateCtrl:SetState(string.format("Queue%d", unlockedQueueSize))
    end

    local slots = {}
    local hasCookingFood = kitchenState and not string.isEmpty(kitchenState.cookingFoodItemId)
    if hasCookingFood then
        slots[#slots + 1] = {
            itemId = kitchenState.cookingFoodItemId,
            isCooking = true,
            elapsedMs = self:_GetCookElapsedMs(kitchenState),
        }
    end
    if kitchenState and kitchenState.waitingFoodItemIds then
        for i = 0, kitchenState.waitingFoodItemIds.Count - 1 do
            local itemId = kitchenState.waitingFoodItemIds[i]
            if itemId and not string.isEmpty(itemId) then
                slots[#slots + 1] = {
                    itemId = itemId,
                    isCooking = false,
                    waitQueueIndex = i,
                }
            end
        end
    end

    if leftNode.foodQueueStateCtrl then
        local isBlocked = kitchenState and kitchenState.isBlocked or false
        leftNode.foodQueueStateCtrl:SetState(isBlocked and "Block" or "Normal")
    end

    local cells = {
        leftNode.foodQueueCell01,
        leftNode.foodQueueCell02,
        leftNode.foodQueueCell03,
    }
    for i = 1, #cells do
        self:_ApplyFoodCell(cells[i], slots[i])
    end

    self:_EnsureKitchenProgressCoroutine()
end

local KITCHEN_COOK_PROGRESS_TICK_SEC = 0.1

InnKitchenOrderingPopUpCtrl._RefreshCookingCellProgress = HL.Method() << function(self)
    local kitchenState = self.m_cachedKitchenState
    if not kitchenState or string.isEmpty(kitchenState.cookingFoodItemId) then
        return
    end
    local cell = self.view.leftNode.foodQueueCell01
    if not cell or not cell.sliderImg then
        return
    end
    local itemId = kitchenState.cookingFoodItemId
    local total = InnUtils.getDishCookTotalMs(itemId)
    local elapsed = self:_GetCookElapsedMs(kitchenState)
    
    
    local boost = self:_GetCachedSpeedBoost(kitchenState.id, itemId)
    local remainingMs = self.m_innSystem:GetKitchenRealtimeRemainingMs(kitchenState, total, boost)
    cell.countDownNumTxt.text = string.format("%ds", math.ceil(remainingMs / 1000))
    if total > 0 then
        cell.sliderImg.fillAmount = math.max(0, math.min(1, elapsed / total))
    end
end

InnKitchenOrderingPopUpCtrl._EnsureKitchenProgressCoroutine = HL.Method() << function(self)
    local kitchenState = self.m_cachedKitchenState
    local isCooking = kitchenState ~= nil and not string.isEmpty(kitchenState.cookingFoodItemId)
    if not isCooking then
        if self.m_kitchenProgressCoroutine then
            self.m_kitchenProgressCoroutine = self:_ClearCoroutine(self.m_kitchenProgressCoroutine)
        end
        return
    end
    if self.m_kitchenProgressCoroutine then
        return
    end
    self.m_kitchenProgressCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(KITCHEN_COOK_PROGRESS_TICK_SEC)
            local ks = self.m_cachedKitchenState
            if not ks or string.isEmpty(ks.cookingFoodItemId) then
                break
            end
            local gs = self.m_innSystem and self.m_innSystem.gameState or nil
            if not (gs and gs.isPaused) then
                self:_RefreshCookingCellProgress()
            end
        end
        self.m_kitchenProgressCoroutine = nil
    end)
end

InnKitchenOrderingPopUpCtrl._RefreshRareRate = HL.Method() << function(self)
    local kitchenId = self:_GetCurrentKitchenId()
    local rareRate = InnUtils.getKitchenRareRate(kitchenId)
    local leftNode = self.view.leftNode
    if leftNode.rareNumTxt then
        leftNode.rareNumTxt.text = string.format("%.0f%%", rareRate * 100)
    end
end

InnKitchenOrderingPopUpCtrl._OnKitchenStateChanged = HL.Method(HL.Any) << function(self, args)
    local kitchenId = unpack(args)
    if kitchenId == self:_GetCurrentKitchenId() then
        self:_RefreshKitchenFoodQueue()
    end
    self:_OnDishDemandSourceChanged(nil)
    self:_RefreshAllTabQueueStates()
    self:_ScheduleRefreshSoldOutTips()
end

InnKitchenOrderingPopUpCtrl._RebuildDishDemandMap = HL.Method() << function(self)
    self.m_dishDemand = InnUtils.buildFoodDemandMap(self.m_innSystem, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish)
end



InnKitchenOrderingPopUpCtrl._RefreshAllRecipeDemandTags = HL.Method() << function(self)
    if not self.m_menuItems or not self.m_getRecipeCell then
        return
    end
    local maxNum = self.m_innSystem.menuDishMaxNum
    for i = 1, maxNum do
        local item = self.m_menuItems[i]
        if item then
            local cell = self.m_getRecipeCell(i)
            if cell then
                local demand = (self.m_dishDemand and self.m_dishDemand[item.itemId]) or 0
                cell:SetDemandTagActive(demand > 0)
            end
        end
    end
end

InnKitchenOrderingPopUpCtrl._OnDishDemandSourceChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_RebuildDishDemandMap()
    self:_RefreshAllRecipeDemandTags()
end


InnKitchenOrderingPopUpCtrl._OnRemainingDishSourceChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_OnDishDemandSourceChanged(nil)
    self:_ScheduleRefreshSoldOutTips()
end

InnKitchenOrderingPopUpCtrl._OnItemCountChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_ScheduleRefreshSoldOutTips()
end

InnKitchenOrderingPopUpCtrl._OnGameTimeWrapUpChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_ScheduleRefreshSoldOutTips()
end

InnKitchenOrderingPopUpCtrl._ScheduleRefreshSoldOutTips = HL.Method() << function(self)
    if self.m_soldOutTipsPendingTimerId ~= -1 then
        return
    end
    self.m_soldOutTipsPendingTimerId = TimerManager:StartFrameTimer(2, function()
        self.m_soldOutTipsPendingTimerId = -1
        self:_RefreshSoldOutTips()
    end, self)
end

InnKitchenOrderingPopUpCtrl._RefreshSoldOutTips = HL.Method() << function(self)
    local node = self.view.timeReminderNode
    if not node then
        return
    end
    local state = InnUtils.getDishSoldOutTipsState(self.m_innSystem)
    self.m_soldOutTipsState = state or ""
    node.gameObject:SetActiveIfNecessary(state ~= nil)
    if state then
        node:SetState(state)
    end
end

InnKitchenOrderingPopUpCtrl._RefreshAllRecipeCookTime = HL.Method() << function(self)
    if not self.m_menuItems or not self.m_getRecipeCell then
        return
    end
    local kitchenId = self:_GetCurrentKitchenId()
    local maxNum = self.m_innSystem.menuDishMaxNum
    for i = 1, maxNum do
        local item = self.m_menuItems[i]
        if item then
            local cell = self.m_getRecipeCell(i)
            if cell then
                cell:RefreshCookTime(kitchenId)
            end
        end
    end
end

InnKitchenOrderingPopUpCtrl._RefreshAllRecipeTagUpCounts = HL.Method() << function(self)
    if not self.m_menuItems or not self.m_getRecipeCell then
        return
    end
    local maxNum = self.m_innSystem.menuDishMaxNum
    for i = 1, maxNum do
        local item = self.m_menuItems[i]
        if item then
            local cell = self.m_getRecipeCell(i)
            if cell then
                cell:SetTagUpCounts(self.m_kitchenTagUpCounts)
            end
        end
    end
end

InnKitchenOrderingPopUpCtrl._OnInRushChanged = HL.Method(HL.Any) << function(self, _args)
    self:_RefreshAllRecipeCookTime()
end

InnKitchenOrderingPopUpCtrl._RefreshRecipeList = HL.Method() << function(self)
    local menuItems = self.m_innSystem.gameSetting.menuItems
    local dishType = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish
    local list = {}
    if menuItems and menuItems.Count > 0 then
        for i = 0, menuItems.Count - 1 do
            local mi = menuItems[i]
            if mi.foodType == dishType then
                list[#list + 1] = { itemId = mi.itemId }
            end
        end
    end
    self.m_menuItems = list
    self:_RebuildDishDemandMap()
    self.view.recipeList:UpdateCount(self.m_innSystem.menuDishMaxNum)
end

InnKitchenOrderingPopUpCtrl._OnUpdateRecipeCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local item = self.m_menuItems[index]
    if not item then
        if index <= self.m_innSystem.menuDishNum then
            cell:SetEmpty()
        elseif index <= self.m_innSystem.menuDishMaxNum then
            cell:SetEmptyLocked()
        end
        return
    end
    local topicId = self.m_innSystem.gameSetting.topicId
    local demand = (self.m_dishDemand and self.m_dishDemand[item.itemId]) or 0
    cell:InitInnRecipeOverviewCell({
        itemId = item.itemId,
        showDemandTag = demand > 0,
        showTopicTag = false,
        topicId = topicId,
        kitchenId = self:_GetCurrentKitchenId(),
        tagUpCounts = self.m_kitchenTagUpCounts,
        showIngredient = self.m_showIngredient,
        onClickCallback = function(itemId, isCountZero)
            if isCountZero then
                
                if string.isEmpty(self.m_soldOutTipsState) then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_KITCHEN_ORDER_NO_INGREDIENT)
                end
                return
            end
            self:_SyncKitchenStateCache()
            local ks = self.m_cachedKitchenState
            local queueCount = 0
            if ks then
                if not string.isEmpty(ks.cookingFoodItemId) then
                    queueCount = queueCount + 1
                end
                if ks.waitingFoodItemIds then
                    queueCount = queueCount + ks.waitingFoodItemIds.Count
                end
            end
            if queueCount >= self.m_innSystem.kitchenQueueSize then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_KITCHEN_ORDER_QUEUE_FULL)
                return
            end
            local kitchenId = self:_GetCurrentKitchenId()
            self.m_innSystem:SendOrderFood(kitchenId, { itemId })
        end,
        infinityMode = self.m_innSystem.gameSetting.softOpening,
        isItemTipsLeft = index % 2 == 0,
    })
end

InnKitchenOrderingPopUpCtrl.InitController = HL.Method() << function(self)
    self.view.leftNode.queueNaviRoot.getDefaultSelectableFunc = function()
        local leftNode = self.view.leftNode
        local cells = {
            leftNode.foodQueueCell03,
            leftNode.foodQueueCell02,
            leftNode.foodQueueCell01,
        }
        for i = 1, #cells do
            local cell = cells[i]
            if cell and cell.gameObject.activeSelf and cell.stateController.currentStateName ~="EmptyState" then
                return cell.naviTarget
            end
        end
        return nil
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnKitchenOrderingPopUpCtrl._SetFirstScrollNaviTarget = HL.Method() << function(self)
    local firstObj = self.view.recipeList:Get(CSIndex(1))
    if not firstObj then 
        return 
    end
    local cell = self.m_getRecipeCell(firstObj)
    if cell and cell.view and cell.view.naviTarget then
        self:SetNaviTarget(cell.view.naviTarget)
    end
end

InnKitchenOrderingPopUpCtrl._OnChangeInputDeviceTypeFinished = HL.Method(HL.Any) << function(self, args)
    local inputType = args.inputType
    local isController = inputType == DeviceInfo.InputType.Controller
    if isController then
        self:InitController()
        if self:IsShow() then
            self:_SetFirstScrollNaviTarget()
        end
    end

    local leftNode = self.view.leftNode
    local cells = {
        leftNode.foodQueueCell03,
        leftNode.foodQueueCell02,
        leftNode.foodQueueCell01,
    }
    for i = 1, #cells do
        local cell = cells[i]
        if cell then
            cell.naviTarget.enabled = isController
            InputManagerInst:ToggleGroup(cell.inputGroup.groupId, not isController)
        end
    end

    self.view.leftNode.queueNaviRoot:ManuallyRefreshRelatedBindingGroups()
    self.view.leftNode.queueNaviRoot:RefreshFocusBindings()

    self.view.innDeskStateCell.gameObject:SetActive(false)
    if DeviceInfo.isMobile then
        self.m_deskStateCellCache:ClearAll()
        self.m_deskStateCellCache = nil   
        self:_InitDeskStates()
    end

    local maxNum = self.m_innSystem.menuDishMaxNum
    for i = 1, maxNum do
        local item = self.m_menuItems[i]
        if item then
            local cell = self.m_getRecipeCell(i)
            if cell then
                cell:OnChangeInputDeviceTypeFinished()
            end
        end
    end
end

InnKitchenOrderingPopUpCtrl._OnConfirmChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    self.view.leftNode.queueNaviRoot:ManuallyStopFocus()
end

HL.Commit(InnKitchenOrderingPopUpCtrl)
