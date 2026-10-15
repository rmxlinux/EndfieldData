local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local InnUtils = require_ex('Common/Utils/InnUtils')

InnRecipeOverviewCell = HL.Class('InnRecipeOverviewCell', UIWidgetBase)

InnRecipeOverviewCell.m_ingredientCache = HL.Field(HL.Forward("UIListCache")) << nil

InnRecipeOverviewCell.m_affixTagCache = HL.Field(HL.Forward("UIListCache")) << nil

InnRecipeOverviewCell.m_dish = HL.Field(HL.Userdata) << nil

InnRecipeOverviewCell.m_args = HL.Field(HL.Table) << nil

InnRecipeOverviewCell.m_ingredientBundles = HL.Field(HL.Table) << nil

InnRecipeOverviewCell.m_locked = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_showIngredient = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_isDrink = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_isIngredientInited = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_isTagInited = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_empty = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_emptyLocked = HL.Field(HL.Boolean) << false

InnRecipeOverviewCell.m_kitchenId = HL.Field(HL.Number) << 0


InnRecipeOverviewCell.m_tagUpCounts = HL.Field(HL.Table) << nil
















InnRecipeOverviewCell.InitInnRecipeOverviewCell = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    self.m_dish = nil
    self.m_args = nil
    self.m_ingredientBundles = nil
    self.m_isDrink = false
    self.m_isIngredientInited = false
    self.m_isTagInited = false
    self.m_empty = false
    self.m_emptyLocked = false
    self.m_kitchenId = args.kitchenId or 0
    self.m_tagUpCounts = args.tagUpCounts

    if self.view.normalStateBtn then
        self.view.normalStateBtn.onClick:RemoveAllListeners()
    end
    if self.view.tipsButton then
        self.view.tipsButton.onClick:RemoveAllListeners()
    end
    if self.view.tipsBtnController then
        self.view.tipsBtnController.onClick:RemoveAllListeners()
    end

    self.view.stateController:SetState("UnSelected")
    local itemId = args.itemId or ""
    local isDrink = false
    local dishOrDrink = nil
    local hasDish, dish = Tables.innDishTable:TryGetValue(itemId)
    if hasDish and dish then
        dishOrDrink = dish
    else
        local hasDrink, drink = Tables.innDrinkTable:TryGetValue(itemId)
        if hasDrink and drink then
            dishOrDrink = drink
            isDrink = true
        end
    end

    if not dishOrDrink then
        logger.error("[InnRecipeOverviewCell] innDishTable/innDrinkTable 无菜品或饮品: " .. tostring(itemId))
        return
    end

    self.view.gameObject.name = itemId
    self.m_dish = dishOrDrink
    self.m_args = args
    self.m_isDrink = isDrink
    self.m_showIngredient = (not isDrink) and (args.showIngredient == true)
    self.m_ingredientBundles = isDrink and {} or self:_BuildIngredientBundles(dishOrDrink)

    self.view.demandTagNode.gameObject:SetActive(self.m_args.showDemandTag == true)
    self.view.topicTagNode.gameObject:SetActive(false)

    local _, itemData = Tables.itemTable:TryGetValue(itemId)
    if self.view.nameTxt then
        self.view.nameTxt.text = (itemData and itemData.name) or ""
    end
    if self.view.sellingPriceNumTxt then
        self.view.sellingPriceNumTxt.text = dishOrDrink.price ~= nil and tostring(dishOrDrink.price) or ""
    end

    if self.view.costTimeNode then
        self.view.costTimeNode.gameObject:SetActive(not isDrink)
    end
    self:_RefreshCookTime()

    self:_RefreshCountDisplay()

    if self.view.normalStateBtn then
        if args.onClickCallback then
            self.view.normalStateBtn.onClick:AddListener(function()
                local isCountZero
                if self.m_args.infinityMode then
                    isCountZero = false
                elseif self.m_isDrink then
                    isCountZero = self:_GetIngredientCount(itemId) <= 0
                else
                    isCountZero = self:_ComputeCraftableCount(self.m_ingredientBundles) <= 0
                end
                args.onClickCallback(itemId, isCountZero)
            end)
        end
    end

    if self.view.itemIcon then
        self.view.itemIcon:InitItemIcon(itemId, true)
    end
    if self.view.rarityLine then
        self.view.rarityLine.color = UIUtils.getItemRarityColor(Tables.itemTable[itemId].rarity)
    end

    local showTips = function()
        Notify(MessageConst.SHOW_ITEM_TIPS, {
            itemId = itemId,
            transform = self.view.transform,
            posType = self.m_args.isItemTipsLeft and UIConst.UI_TIPS_POS_TYPE.LeftTop or UIConst.UI_TIPS_POS_TYPE.RightTop,
            isSideTips = true,
            onClose = function()
                if NotNull(self.view.gameObject) then
                    self.view.itemSelectedBG.gameObject:SetActive(false)
                end
            end,
        })
        self.view.itemSelectedBG.gameObject:SetActive(true)
    end
    if self.view.tipsButton then
        self.view.tipsButton.onClick:AddListener(function()
            showTips()
        end)
    end
    if self.view.tipsBtnController then
        self.view.tipsBtnController.onClick:AddListener(function()
            showTips()
        end)
    end
    if args.locked then
        self.m_locked = true
        self.view.stateController:SetState("Locked")
        if self.view.lockTxt then
            self.view.lockTxt.text = args.unlockText or ""
        end
    else
        self.m_locked = false
        self:_ApplyIngredientOrTagLayout()
	end

    if self.view.btnMinus then
        self.view.btnMinus.onClick:RemoveAllListeners()
        self.view.btnMinus.onClick:AddListener(function()
            if args.onDeleteClick then
                args.onDeleteClick()
            end
        end)
    end

    self.view.itemSelectedBG.gameObject:SetActive(false)
    self:_RefreshNaviTargetEnabled()
    if DeviceInfo.usingController then
        self:_InitController()
    end
end


InnRecipeOverviewCell._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function()
        if self:_RefreshIngredientBundleCounts() and self.m_isIngredientInited then
            self:_RefreshIngredientCells()
        end
        self:_RefreshCountDisplay()
    end)
    self:RegisterMessage(MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT, function(showIngredient)
        self:SetShowIngredient(showIngredient == true)
    end)
    self:RegisterMessage(MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED, function()
        if DeviceInfo.usingController then
            self:_InitController()
        else
            InputManagerInst:ToggleGroup(self.view.inputGroup.groupId, true)
        end
    end)
    self:RegisterMessage(MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE, function()
        self.view.itemNaviGroup:ManuallyStopFocus()
    end)
end

InnRecipeOverviewCell._InitController = HL.Method() << function(self)
    self.view.tipsBtnController.onIsNaviTargetChanged = function(isTarget)
        self.view.itemSelectedBG.gameObject:SetActive(isTarget)
    end
end

InnRecipeOverviewCell._RefreshCountDisplay = HL.Method() << function(self)
    if not self.m_dish or not self.view.craftableTxt then
        return
    end
    if self.m_args.infinityMode then
        local fmt = self.m_isDrink and Language.LUA_INN_RECIPE_OVERVIEW_STOCK_FORMAT or Language.LUA_INN_RECIPE_OVERVIEW_CRAFTABLE_FORMAT
        self.view.craftableTxt.text = UIUtils.setCountColor(string.format(fmt, "∞"), false)
    elseif self.m_isDrink then
        local stock = self:_GetIngredientCount(self.m_args.itemId)
        self.view.craftableTxt.text = UIUtils.setCountColor(string.format(Language.LUA_INN_RECIPE_OVERVIEW_STOCK_FORMAT, stock), stock <= 0)
    else
        local craftable = self:_ComputeCraftableCount(self.m_ingredientBundles)
        self.view.craftableTxt.text = UIUtils.setCountColor(string.format(Language.LUA_INN_RECIPE_OVERVIEW_CRAFTABLE_FORMAT, craftable), craftable <= 0)
    end
end


InnRecipeOverviewCell._RefreshCookTime = HL.Method() << function(self)
    if self.m_isDrink or not self.view.timeTxt or not self.m_dish then
        return
    end
    local itemId = (self.m_args and self.m_args.itemId) or ""
    local seconds
    if self.m_kitchenId and self.m_kitchenId > 0 then
        seconds = InnUtils.getDishRealCookSeconds(self.m_kitchenId, itemId)
    else
        seconds = self.m_dish.timeCost or 0
    end
    self.view.timeTxt.text = tostring(seconds) .. "s"
end


InnRecipeOverviewCell.RefreshCookTime = HL.Method(HL.Number) << function(self, kitchenId)
    self.m_kitchenId = kitchenId or 0
    self:_RefreshCookTime()
end

InnRecipeOverviewCell._RefreshIngredientCells = HL.Method() << function(self)
    if not self.m_dish or not self.view.itemIngredient or not self.view.ingredientNode then
        return
    end
    self.m_ingredientCache = self.m_ingredientCache or UIUtils.genCellCache(self.view.itemIngredient, nil, self.view.ingredientNode)
    self.m_ingredientCache:Refresh(#self.m_ingredientBundles, function(cell, index)
        cell:InitItem(self.m_ingredientBundles[index], true)
        cell:SetExtraInfo({
            tipsPosType = self.m_args.isItemTipsLeft and UIConst.UI_TIPS_POS_TYPE.LeftTop or UIConst.UI_TIPS_POS_TYPE.RightTop,
            tipsPosTransform = self.view.transform,
            isSideTips = true,
        })
        cell.view.gameObject.name = tostring(self.m_ingredientBundles[index].id)
    end)
end

InnRecipeOverviewCell._RefreshTagSection = HL.Method() << function(self)
    if not self.m_dish then
        return
    end
    local topicId = self.m_args.topicId or ""

    local showCategory = false
    if self.view.innItemTagCategory and self.view.innItemTagCategory.InitInnItemTag then
        local catId = self.m_isDrink and Tables.innManagementConst.drinkCategory or self.m_dish.category
        if catId and not string.isEmpty(catId) then
            showCategory = true
            self.view.innItemTagCategory.gameObject:SetActive(true)
            self.view.innItemTagCategory:InitInnItemTag({
                tagId = catId,
                isHot = InnUtils.isItemTagTopicHot(topicId, catId),
                upCount = self:_GetTagUpCount(catId),
            })
        else
            self.view.innItemTagCategory.gameObject:SetActive(false)
        end
    end

    local affixArgs = self:_BuildAffixTagArgs(self.m_dish, topicId)
    if self.view.innItemTagAffix then
        self.m_affixTagCache = self.m_affixTagCache or UIUtils.genCellCache(self.view.innItemTagAffix)
        self.m_affixTagCache:Refresh(#affixArgs, function(cell, index)
            cell:InitInnItemTag(affixArgs[index])
        end)
    end
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.affix)
end

InnRecipeOverviewCell._ApplyIngredientOrTagLayout = HL.Method() << function(self)
    local showIngredient = self.m_showIngredient and not self.m_isDrink
    self.view.stateController:SetState(showIngredient and "NormalIngredient" or "NormalTag")
    if showIngredient then
        if not self.m_isIngredientInited then
            self:_RefreshIngredientCells()
            self.m_isIngredientInited = true
        end
    else
        if not self.m_isTagInited then
            self:_RefreshTagSection()
            self.m_isTagInited = true
        end
    end
end

InnRecipeOverviewCell._BuildIngredientBundles = HL.Method(HL.Any).Return(HL.Table) << function(self, dish)
    local rows = {}
    local nums = dish.ingredientNum
    for i, id in pairs(dish.ingredient or {}) do
        if id and not string.isEmpty(id) then
            local c = 1
            if nums then
                c = nums[i] or 1
            end
            rows[#rows + 1] = { id = id, count = c, isLack = not self.m_args.infinityMode and self:_GetIngredientCount(id) < c }
        end
    end
    return rows
end

InnRecipeOverviewCell._GetIngredientCount = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    return InnUtils.getIngredientCount(itemId)
end

InnRecipeOverviewCell._RefreshIngredientBundleCounts = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_ingredientBundles or #self.m_ingredientBundles == 0 or self.m_args.infinityMode then
        return false
    end
    local isChanged = false
    for _, b in ipairs(self.m_ingredientBundles) do
        local isLack = self:_GetIngredientCount(b.id) < b.count
        if b.isLack ~= isLack then
            b.isLack = isLack
            isChanged = true
        end
    end
    return isChanged
end

InnRecipeOverviewCell._ComputeCraftableCount = HL.Method(HL.Table).Return(HL.Number) << function(self, bundles)
    if not bundles or #bundles == 0 then
        return 0
    end
    if not GameInstance.player or not GameInstance.player.inventory then
        return 0
    end
    local minBatches = math.huge
    for _, b in ipairs(bundles) do
        local need = b.count or 1
        if need <= 0 then
            need = 1
        end
        local have = self:_GetIngredientCount(b.id)
        local batches = have // need
        if batches < minBatches then
            minBatches = batches
        end
    end
    if minBatches == math.huge then
        return 0
    end
    return minBatches
end

InnRecipeOverviewCell._BuildAffixTagArgs = HL.Method(HL.Any, HL.String).Return(HL.Table) << function(self, dish, topicId)
    local out = {}
    for _, affixTagId in pairs(dish.affix or {}) do
        if affixTagId and not string.isEmpty(affixTagId) then
            out[#out + 1] =
            {
                tagId = affixTagId,
                isHot = InnUtils.isItemTagTopicHot(topicId, affixTagId),
                upCount = self:_GetTagUpCount(affixTagId),
            }
        end
    end
    return out
end

InnRecipeOverviewCell._GetTagUpCount = HL.Method(HL.String).Return(HL.Number) << function(self, tagId)
    return (self.m_tagUpCounts and self.m_tagUpCounts[tagId]) or 0
end

InnRecipeOverviewCell.SetTagUpCounts = HL.Method(HL.Opt(HL.Table)) << function(self, tagUpCounts)
    self.m_tagUpCounts = tagUpCounts
    if self.m_isTagInited then
        self:_RefreshTagSection()
    end
end

InnRecipeOverviewCell.SetShowIngredient = HL.Method(HL.Boolean) << function(self, showIngredient)
    if self.m_isDrink or self.m_locked or self.m_empty or self.m_emptyLocked then
        return
    end
    self.m_showIngredient = showIngredient
    self:_ApplyIngredientOrTagLayout()
end

InnRecipeOverviewCell.SetDemandTagActive = HL.Method(HL.Boolean) << function(self, active)
    self.view.demandTagNode.gameObject:SetActive(active)
end

InnRecipeOverviewCell.SetTopicTagActive = HL.Method(HL.Boolean) << function(self, active)
    self.view.topicTagNode.gameObject:SetActive(active)
end

InnRecipeOverviewCell.SetSelected = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, selected, playAnim)
    self.view.stateController:SetState(selected and "Selected" or "UnSelected")
    local hintText = selected and Language.key_hint_menu_item_unselect or (self.m_isDrink and Language.key_hint_menu_drink_select or Language.key_hint_menu_dish_select)
    self.view.normalStateBtn.customBindingViewLabelText = hintText
    if selected and playAnim then
        self.view.selectedBG:PlayInAnimation()
    end
end

InnRecipeOverviewCell.SetEmpty = HL.Method() << function(self)
    self.m_empty = true
    self.view.gameObject.name = "Empty"
    self.view.stateController:SetState("Empty")
    self:_RefreshNaviTargetEnabled()
end

InnRecipeOverviewCell.SetEmptyLocked = HL.Method() << function(self)
    self.m_emptyLocked = true
    self.view.gameObject.name = "EmptyLocked"
    self.view.stateController:SetState("EmptyLocked")
    self:_RefreshNaviTargetEnabled()
end

InnRecipeOverviewCell._RefreshNaviTargetEnabled = HL.Method() << function(self)
    self.view.naviTarget.enabled = DeviceInfo.usingController and not self.m_empty and not self.m_emptyLocked
end

InnRecipeOverviewCell.OnChangeInputDeviceTypeFinished = HL.Method() << function(self)
    self:_RefreshNaviTargetEnabled()
    self.view.tipsBtnController.gameObject:SetActive(DeviceInfo.usingController)
    if DeviceInfo.usingController then
        InputManagerInst:ToggleGroup(self.view.inputGroup.groupId, self.view.naviTarget.isNaviTarget)
    else
        InputManagerInst:ToggleGroup(self.view.inputGroup.groupId, true)
    end
    self.view.itemNaviGroup:ManuallyRefreshRelatedBindingGroups()
    self.view.itemNaviGroup:RefreshFocusBindings()
end

HL.Commit(InnRecipeOverviewCell)
return InnRecipeOverviewCell