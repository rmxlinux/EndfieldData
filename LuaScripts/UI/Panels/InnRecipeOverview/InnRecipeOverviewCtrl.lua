local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local InnUtils = require_ex('Common/Utils/InnUtils')
local PANEL_ID = PanelId.InnRecipeOverview
local PHASE_ID = PhaseId.InnRecipeOverview

local SORT_OPTIONS = {
    {
        name = Language.LUA_INN_RECIPE_OVERVIEW_SORT_DEFAULT,
        keys = { "unlockSort", "categorySortId", "rarity", "price" },
        reverseKeys = { "unlockSortReverse", "categorySortId", "rarity", "price" },
    },
    {
        name = Language.LUA_INN_RECIPE_OVERVIEW_SORT_PRICE,
        keys = { "unlockSort", "price", "rarity", "id" },
        reverseKeys = { "unlockSortReverse", "price", "rarity", "id" },
    },
    {
        name = Language.LUA_INN_RECIPE_OVERVIEW_SORT_RARITY,
        keys = { "unlockSort", "rarity", "price", "id" },
        reverseKeys = { "unlockSortReverse", "rarity", "price", "id" },
    },
}


InnRecipeOverviewCtrl = HL.Class('InnRecipeOverviewCtrl', uiCtrl.UICtrl)

InnRecipeOverviewCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.GUIDE_INN_TOGGLE_RECIPE_INGREDIENT] = '_OnGuideToggleRecipeIngredient',
}

InnRecipeOverviewCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnRecipeOverviewCtrl.m_categories = HL.Field(HL.Table)

InnRecipeOverviewCtrl.m_curTabIndex = HL.Field(HL.Number) << 1

InnRecipeOverviewCtrl.m_allRecipes = HL.Field(HL.Table)

InnRecipeOverviewCtrl.m_filteredRecipes = HL.Field(HL.Table)

InnRecipeOverviewCtrl.m_tabCellCachePC = HL.Field(HL.Forward("UIListCache"))

InnRecipeOverviewCtrl.m_tabCellCacheMobile = HL.Field(HL.Forward("UIListCache"))

InnRecipeOverviewCtrl.m_getCell = HL.Field(HL.Function)

InnRecipeOverviewCtrl.m_sortData = HL.Field(HL.Table)

InnRecipeOverviewCtrl.m_sortIncremental = HL.Field(HL.Boolean) << true

InnRecipeOverviewCtrl.m_showIngredient = HL.Field(HL.Boolean) << false

InnRecipeOverviewCtrl.m_filterTags = HL.Field(HL.Table)

InnRecipeOverviewCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_filterTags = {}

    self.view.btnClose.onClick:AddListener(function()
        Notify(MessageConst.HIDE_ITEM_TIPS)
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.m_tabCellCachePC = UIUtils.genCellCache(self.view.tabsPC.tabCell)
    self.m_tabCellCacheMobile = UIUtils.genCellCache(self.view.tabsMobile.tabCell)

    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
    self.view.scrollList.getCellName = function(csIndex)
        local recipeInfo = self.m_filteredRecipes and self.m_filteredRecipes[LuaIndex(csIndex)]
        return recipeInfo and recipeInfo.id or "RecipeCell"
    end
    self.view.scrollList:UpdateCount(0)

    self.m_showIngredient = (arg and arg.showIngredient) == true
    self.view.showIngredientToggle:InitCommonToggle(function(isOn)
        self.m_showIngredient = isOn
        Notify(MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT, isOn)
    end, self.m_showIngredient, true)

    self:_InitFilter()

    self.view.sortNodeUp:InitSortNode(SORT_OPTIONS, function(optData, isIncremental)
        self.m_sortData = optData
        self.m_sortIncremental = isIncremental
        self:_FilterByCategory()
        self:_ApplyFilter()
        self:_ApplySort()
        self:_RefreshList(true)
    end, 0, false, true, self.view.filterBtn)
    self.m_sortData = self.view.sortNodeUp:GetCurSortData()
    self.m_sortIncremental = self.view.sortNodeUp.isIncremental

    self:_BuildCategories()
    self:_BuildAllRecipes()

    local defaultTabIndex = 1
    if arg and arg.tabIndex then
        defaultTabIndex = arg.tabIndex
    end
    self.m_curTabIndex = defaultTabIndex

    self:_InitRedDot()

    self:_RefreshTabs()
    self:_FilterByCategory()
    self:_ApplyFilter()
    self:_ApplySort()
    self:_RefreshList()
end

InnRecipeOverviewCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return { tabIndex = self.m_curTabIndex, showIngredient = self.m_showIngredient }
end




InnRecipeOverviewCtrl._BuildCategories = HL.Method() << function(self)
    local drinkCatId = Tables.innManagementConst.drinkCategory or ""
    local cats = {}
    for catId, catData in pairs(Tables.innDishCategoryTable) do
        if catId ~= drinkCatId then
            cats[#cats + 1] = {
                id = catId,
                name = catData.name,
                iconId = catData.iconId,
                sortId = catData.sortId or 0,
            }
        end
    end
    table.sort(cats, Utils.genSortFunction({ "sortId", "id" }, true))

    table.insert(cats, 1, {
        id = "",
        name = Language.LUA_INN_RECIPE_OVERVIEW_TAB_ALL,
        iconId = "inn_recipe_type_all",
        sortId = -1,
    })
    self.m_categories = cats
end

InnRecipeOverviewCtrl._BuildAllRecipes = HL.Method() << function(self)
    local recipes = {}
    local innLevel = self.m_innSystem.innLevel
    local obtained = 0

    for dishId, dishData in pairs(Tables.innDishTable) do
        local dishUnlockLevel = dishData.unlockLevel or 0
        if dishUnlockLevel == 0 and not string.isEmpty(dishData.unlockTopicId or "") then
            local hasTopic, topicData = Tables.innTopicTable:TryGetValue(dishData.unlockTopicId)
            if hasTopic and topicData then
                dishUnlockLevel = topicData.unlockLevel or 0
            end
        end
        local isUnlocked = self.m_innSystem:IsDishUnlocked(dishId)
        if dishUnlockLevel > 0 and innLevel >= dishUnlockLevel or isUnlocked then
            local hasItem, itemData = Tables.itemTable:TryGetValue(dishId)
            local rarity = (itemData and itemData.rarity) or 0
            local recipeId = dishData.recipeId or ""
            if isUnlocked then
                obtained = obtained + 1
            end
            local catSortId = 0
            if not string.isEmpty(dishData.category or "") then
                local hasCat, catData = Tables.innDishCategoryTable:TryGetValue(dishData.category)
                if hasCat and catData then
                    catSortId = catData.sortId or 0
                end
            end
            recipes[#recipes + 1] = {
                id = dishId,
                recipeId = recipeId,
                category = dishData.category or "",
                price = dishData.price or 0,
                sortId = (itemData and itemData.sortId1) or 0,
                rarity = rarity,
                affix = dishData.affix,
                ingredient = dishData.ingredient,
                ingredientNum = dishData.ingredientNum,
                unlockTopicId = dishData.unlockTopicId or "",
                unlockTopicStarNum = dishData.unlockTopicStarNum or 0,
                unlockSort = isUnlocked and 0 or 1,
                unlockSortReverse = isUnlocked and 1 or 0,
                categorySortId = catSortId,
                raritySort = -rarity,
            }
        end
    end

    self.m_allRecipes = recipes

    self.view.getNumTxt.text = string.format(Language.LUA_INN_RECIPE_OVERVIEW_COUNT, obtained, #recipes)
end






InnRecipeOverviewCtrl._InitFilter = HL.Method() << function(self)
    if not self.view.filterBtn then
        return
    end

    local tagGroups = {}

    local rarityGroup = { title = Language.LUA_INN_RECIPE_OVERVIEW_FILTER_RARITY, tags = {} }
    for _, star in ipairs({ 2, 3, 4, 5 }) do
        rarityGroup.tags[#rarityGroup.tags + 1] = {
            id = "rarity_" .. star,
            name = string.format(Language.LUA_INN_RECIPE_OVERVIEW_FILTER_STAR, star),
            filterType = "rarity",
            value = star,
        }
    end
    tagGroups[#tagGroups + 1] = rarityGroup

    local craftableGroup = { title = Language.LUA_INN_RECIPE_OVERVIEW_FILTER_STOCK, tags = {} }
    craftableGroup.tags[#craftableGroup.tags + 1] = {
        id = "craftable",
        name = Language.LUA_INN_RECIPE_OVERVIEW_FILTER_CRAFTABLE,
        filterType = "craftable",
        value = true,
    }
    tagGroups[#tagGroups + 1] = craftableGroup

    local affixGroup = { title = Language.LUA_INN_RECIPE_OVERVIEW_FILTER_AFFIX, tags = {} }
    for affixId, affixData in pairs(Tables.innAffixTable) do
        if affixData.isFixed then
            affixGroup.tags[#affixGroup.tags + 1] = {
                id = "affix_" .. affixId,
                name = affixData.name,
                filterType = "affix",
                value = affixId,
                sortId = affixData.sortId or 0,
            }
        end
    end
    table.sort(affixGroup.tags, Utils.genSortFunction({ "sortId", "id" }, true))
    tagGroups[#tagGroups + 1] = affixGroup

    self.view.filterBtn:InitFilterBtn({
        tagGroups = tagGroups,
        selectedTags = self.m_filterTags,
        onConfirm = function(tags)
            self.m_filterTags = tags
            self:_FilterByCategory()
            self:_ApplyFilter()
            self:_ApplySort()
            self:_RefreshList(true)
        end,
        getResultCount = function(tags)
            return self:_GetFilteredCount(tags)
        end,
        sortNodeWidget = self.view.sortNodeUp,
    })
end

InnRecipeOverviewCtrl._ApplyFilter = HL.Method() << function(self)
    if not self.m_filterTags or #self.m_filterTags == 0 then
        return
    end

    local raritySet = {}
    local affixSet = {}
    local requireCraftable = false

    for _, tag in ipairs(self.m_filterTags) do
        if tag.filterType == "rarity" then
            raritySet[tag.value] = true
        elseif tag.filterType == "craftable" then
            requireCraftable = true
        elseif tag.filterType == "affix" then
            affixSet[tag.value] = true
        end
    end

    local hasRarityFilter = next(raritySet) ~= nil
    local hasAffixFilter = next(affixSet) ~= nil

    local result = {}
    for _, r in ipairs(self.m_filteredRecipes) do
        local pass = true
        if hasRarityFilter and not raritySet[r.rarity] then
            pass = false
        end
        if pass and hasAffixFilter then
            local matched = false
            if r.affix then
                for _, aId in pairs(r.affix) do
                    if affixSet[aId] then
                        matched = true
                        break
                    end
                end
            end
            if not matched then
                pass = false
            end
        end
        if pass and requireCraftable then
            if self:_ComputeCraftableCount(r) <= 0 then
                pass = false
            end
        end
        if pass then
            result[#result + 1] = r
        end
    end
    self.m_filteredRecipes = result
end

InnRecipeOverviewCtrl._GetFilteredCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    local raritySet = {}
    local affixSet = {}
    local requireCraftable = false

    for _, tag in ipairs(tags) do
        if tag.filterType == "rarity" then
            raritySet[tag.value] = true
        elseif tag.filterType == "craftable" then
            requireCraftable = true
        elseif tag.filterType == "affix" then
            affixSet[tag.value] = true
        end
    end

    local hasRarityFilter = next(raritySet) ~= nil
    local hasAffixFilter = next(affixSet) ~= nil
    local count = 0

    local catInfo = self.m_categories[self.m_curTabIndex]
    local catId = catInfo and catInfo.id or ""
    local source = self.m_allRecipes

    for _, r in ipairs(source) do
        if not string.isEmpty(catId) and r.category ~= catId then
            goto continue
        end
        if hasRarityFilter and not raritySet[r.rarity] then
            goto continue
        end
        if hasAffixFilter then
            local matched = false
            if r.affix then
                for _, aId in pairs(r.affix) do
                    if affixSet[aId] then
                        matched = true
                        break
                    end
                end
            end
            if not matched then
                goto continue
            end
        end
        if requireCraftable then
            if self:_ComputeCraftableCount(r) <= 0 then
                goto continue
            end
        end
        count = count + 1
        ::continue::
    end
    return count
end

InnRecipeOverviewCtrl._ComputeCraftableCount = HL.Method(HL.Table).Return(HL.Number) << function(self, recipe)
    local ingredient = recipe.ingredient
    local ingredientNum = recipe.ingredientNum
    if not ingredient or #ingredient == 0 then
        return 0
    end
    local minBatches = math.huge
    for i, itemId in pairs(ingredient) do
        if itemId and not string.isEmpty(itemId) then
            local need = (ingredientNum and ingredientNum[i]) or 1
            if need <= 0 then
                need = 1
            end
            local have = InnUtils.getIngredientCount(itemId)
            local batches = have // need
            if batches < minBatches then
                minBatches = batches
            end
        end
    end
    if minBatches == math.huge then
        return 0
    end
    return minBatches
end









InnRecipeOverviewCtrl._FilterByCategory = HL.Method() << function(self)
    local catInfo = self.m_categories[self.m_curTabIndex]
    local catId = catInfo and catInfo.id or ""

    if string.isEmpty(catId) then
        self.m_filteredRecipes = lume.clone(self.m_allRecipes)
    else
        local filtered = {}
        for _, r in ipairs(self.m_allRecipes) do
            if r.category == catId then
                filtered[#filtered + 1] = r
            end
        end
        self.m_filteredRecipes = filtered
    end
end

InnRecipeOverviewCtrl._ApplySort = HL.Method() << function(self)
    if not self.m_filteredRecipes then
        return
    end
    local sortData = self.m_sortData
    if not sortData then
        return
    end
    local keys = self.m_sortIncremental and sortData.keys or (sortData.reverseKeys or sortData.keys)
    if keys then
        table.sort(self.m_filteredRecipes, Utils.genSortFunction(keys, self.m_sortIncremental))
    end
end

InnRecipeOverviewCtrl._RefreshTabs = HL.Method() << function(self)
    local cats = self.m_categories
    local count = #cats

    self.m_tabCellCachePC:Refresh(count, function(cell, index)
        self:_SetupTabCell(cell, index)
    end)
    self.m_tabCellCacheMobile:Refresh(count, function(cell, index)
        self:_SetupTabCellMobile(cell, index)
    end)
end

InnRecipeOverviewCtrl._SetupTabCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local catInfo = self.m_categories[index]
    if not string.isEmpty(catInfo.iconId) then
        cell.selectedIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, catInfo.iconId)
        cell.defaultIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, catInfo.iconId)
    end
    if cell.selectText then
        cell.selectText.text = catInfo.name or ""
    end
    if cell.defaultText then
        cell.defaultText.text = catInfo.name or ""
    end
    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.isOn = (index == self.m_curTabIndex)
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_OnTabClicked(index)
        end
    end)
end

InnRecipeOverviewCtrl._SetupTabCellMobile = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local catInfo = self.m_categories[index]
    if cell.selectText then
        cell.selectText.text = catInfo.name or ""
    end
    if cell.defaultText then
        cell.defaultText.text = catInfo.name or ""
    end
    if not string.isEmpty(catInfo.iconId) then
        cell.selectedIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, catInfo.iconId)
        cell.defaultIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, catInfo.iconId)
    end
    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.isOn = (index == self.m_curTabIndex)
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_OnTabClicked(index)
        end
    end)
end

InnRecipeOverviewCtrl._OnTabClicked = HL.Method(HL.Number) << function(self, index)
    if index == self.m_curTabIndex then
        return
    end
    self.m_curTabIndex = index
    self:_SyncTabSelection()
    self:_FilterByCategory()
    self:_ApplyFilter()
    self:_ApplySort()
    self:_RefreshList(true)
    self.view.listNodeAni:Stop()
    self.view.listNodeAni:Play("innrecipeoverview_list_in")
end

InnRecipeOverviewCtrl._SyncTabSelection = HL.Method() << function(self)
    self.m_tabCellCachePC:Update(function(cell, index)
        cell.toggle.isOn = (index == self.m_curTabIndex)
    end)
    self.m_tabCellCacheMobile:Update(function(cell, index)
        cell.toggle.isOn = (index == self.m_curTabIndex)
    end)
end






InnRecipeOverviewCtrl._RefreshList = HL.Method(HL.Opt(HL.Boolean)) << function(self, setTop)
    local count = self.m_filteredRecipes and #self.m_filteredRecipes or 0
    if setTop then
        self.view.scrollList:UpdateCount(count, true, false, false, true)
    else
        self.view.scrollList:UpdateCount(count)
    end
    local state = 'Normal'
    if count == 0 then
        state = self:_GetFilteredCount({}) > 0 and 'EmptyFilter' or 'Empty'
    end
    self.view.listNodeStateCtrl:SetState(state)
    if count > 0 and DeviceInfo.usingController then
        self:SetNaviTarget(self.m_getCell(1).view.naviTarget)
    end
end

InnRecipeOverviewCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local recipeInfo = self.m_filteredRecipes[luaIndex]
    if not recipeInfo then
        return
    end
    local topicId = (self.m_innSystem and self.m_innSystem.gameSetting) and self.m_innSystem.gameSetting.topicId or ""
    local isUnlocked = self.m_innSystem:IsDishUnlocked(recipeInfo.id)
    local unlockText = ""
    if not isUnlocked and not string.isEmpty(recipeInfo.unlockTopicId) then
        local hasTopicData, topicData = Tables.innTopicTable:TryGetValue(recipeInfo.unlockTopicId)
        local topicName = (hasTopicData and topicData) and topicData.name or ""
        unlockText = string.format(Language.LUA_INN_RECIPE_OVERVIEW_UNLOCK_CONDITION, topicName, recipeInfo.unlockTopicStarNum)
    end
    cell:InitInnRecipeOverviewCell({
        itemId = recipeInfo.id,
        showDemandTag = false,
        showTopicTag = true,
        topicId = topicId,
        showIngredient = self.m_showIngredient,
        locked = not isUnlocked,
        unlockText = unlockText,
    })
    
    UIUtils.sortRowCellsForOverflow(self.view.scrollList, luaIndex, true)

    if cell.view.redDot then
        cell.view.redDot:InitRedDot("InnRecipeSingle", recipeInfo.id, nil, self.view.redDotScrollRect)
    end
end






InnRecipeOverviewCtrl._InitRedDot = HL.Method() << function(self)
    if self.view.redDotScrollRect then
        self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
            return self:_GetRedDotStateAt(csIndex)
        end
    end
end

InnRecipeOverviewCtrl._GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, csIndex)
    local data = self.m_filteredRecipes[LuaIndex(csIndex)]
    if not data then
        return 0
    end
    local hasRedDot, redDotType = RedDotManager:GetRedDotState("InnRecipeSingle", data.id)
    if hasRedDot then
        return redDotType
    end
    return 0
end






InnRecipeOverviewCtrl._OnItemCountChanged = HL.Method(HL.Any) << function(self, arg)
    self:_FilterByCategory()
    self:_ApplyFilter()
    self:_ApplySort()
    self:_RefreshList()
end

InnRecipeOverviewCtrl._OnGuideToggleRecipeIngredient = HL.Method(HL.Table) << function(self, args)
    local isOn = unpack(args) == true
    if self.m_showIngredient == isOn then
        return
    end
    self.view.showIngredientToggle:SetValue(isOn)
end



InnRecipeOverviewCtrl.OnClose = HL.Override() << function(self)
    RedDotUtils.markAllUnlockedInnRecipesRead()
end

HL.Commit(InnRecipeOverviewCtrl)
