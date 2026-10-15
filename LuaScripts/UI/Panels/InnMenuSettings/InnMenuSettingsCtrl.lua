local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local InnUtils = require_ex('Common/Utils/InnUtils')
local PANEL_ID = PanelId.InnMenuSettings
local PHASE_ID = PhaseId.InnMenuSettings

local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel

local TAB_KIND_ALL = 'all'
local TAB_KIND_CATEGORY = 'category'
local TAB_KIND_DRINK = 'drink'

local SORT_DEFAULT = 1
local SORT_RARITY = 2
local SORT_PRICE = 3
local SORT_CRAFTABLE = 4

local EXPEND_CELL_IN_ANIM_INTERVAL = 0.01


InnMenuSettingsCtrl = HL.Class('InnMenuSettingsCtrl', uiCtrl.UICtrl)



InnMenuSettingsCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnMenuSettingsCtrl.m_topicId = HL.Field(HL.String) << ''
InnMenuSettingsCtrl.m_hasTopicReq = HL.Field(HL.Boolean) << false

InnMenuSettingsCtrl.m_unlockedDishIds = HL.Field(HL.Table)
InnMenuSettingsCtrl.m_unlockedDrinkIds = HL.Field(HL.Table)

InnMenuSettingsCtrl.m_itemConfigById = HL.Field(HL.Table)

InnMenuSettingsCtrl.m_isDrinkById = HL.Field(HL.Table)



InnMenuSettingsCtrl.m_tabList = HL.Field(HL.Table)
InnMenuSettingsCtrl.m_currentTab = HL.Field(HL.Table)
InnMenuSettingsCtrl.m_isDrinkTabActive = HL.Field(HL.Boolean) << false


InnMenuSettingsCtrl.m_selectedDishes = HL.Field(HL.Table)
InnMenuSettingsCtrl.m_selectedDrinks = HL.Field(HL.Table)

InnMenuSettingsCtrl.m_sortMode = HL.Field(HL.Number) << SORT_DEFAULT
InnMenuSettingsCtrl.m_isIncremental = HL.Field(HL.Boolean) << false
InnMenuSettingsCtrl.m_selectedFilterTags = HL.Field(HL.Table)
InnMenuSettingsCtrl.m_showIngredient = HL.Field(HL.Boolean) << false


InnMenuSettingsCtrl.m_displayItemIds = HL.Field(HL.Table)


InnMenuSettingsCtrl.m_levelDishTypeMin = HL.Field(HL.Number) << 0
InnMenuSettingsCtrl.m_levelDishMin = HL.Field(HL.Number) << 0
InnMenuSettingsCtrl.m_levelDrinkMin = HL.Field(HL.Number) << 0


InnMenuSettingsCtrl.m_tabCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_levelReqCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_topicReqCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_categoryTagCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_affixTagCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_dishExpendDishCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_drinkExpendDrinkCache = HL.Field(HL.Forward('UIListCache'))
InnMenuSettingsCtrl.m_getScrollCell = HL.Field(HL.Function)
InnMenuSettingsCtrl.m_expendCellAnimCor = HL.Field(HL.Thread)



InnMenuSettingsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT] = '_OnInnRecipeOverviewShowIngredient',
    [MessageConst.GUIDE_INN_TOGGLE_RECIPE_INGREDIENT] = '_OnGuideToggleRecipeIngredient',
    [MessageConst.ON_INN_DAILY_FASHION_CHANGED] = '_OnInnDailyFashionChanged',
}



InnMenuSettingsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_topicId = (arg and arg.topicId) or ''
    self.m_sortMode = (arg and arg.sortMode) or SORT_DEFAULT
    self.m_isIncremental = (arg and arg.isIncremental) == true
    self.m_selectedFilterTags = (arg and arg.filterTags) or {}
    self.m_showIngredient = (arg and arg.showIngredient) == true
    self.m_displayItemIds = {}
    self.m_selectedDishes = {}
    self.m_selectedDrinks = {}
    self.m_itemConfigById = {}
    self.m_isDrinkById = {}

    if self.m_innSystem then
        self.m_innSystem:TryAutoFillMenuItems(self.m_topicId)
    end

    self:_BuildStaticData()
    self:_LoadSelectedFromPending()

    self:_InitTopNode()
    self:_InitTopicBar()
    self:_InitLeftNode()
    self:_InitRightNode()
    self:_InitBottomNode()

    self:_RestoreActiveTab(arg)

    self:_InitController()

    if arg and arg.startConfirmOpen then
        self:_TryRecoverStartConfirm()
    end
end

InnMenuSettingsCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local tabIndex = 1
    if not self.m_isDrinkTabActive and self.m_currentTab then
        for i, tab in ipairs(self.m_tabList) do
            if tab == self.m_currentTab then
                tabIndex = i
                break
            end
        end
    end
    
    local startConfirmOpen = UIManager:IsOpen(PanelId.InnStartConfirm)
    return {
        topicId = self.m_topicId,
        sortMode = self.m_sortMode,
        isIncremental = self.m_isIncremental,
        filterTags = self.m_selectedFilterTags,
        showIngredient = self.m_showIngredient,
        isDrinkTab = self.m_isDrinkTabActive,
        tabIndex = tabIndex,
        startConfirmOpen = startConfirmOpen,
    }
end





InnMenuSettingsCtrl._BuildStaticData = HL.Method() << function(self)
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local levelData
    if self.m_innSystem then
        local hasLv, lv = Tables.innLevelTable:TryGetValue(innLevel)
        if hasLv then
            levelData = lv
        end
    end
    self.m_levelDishTypeMin = (levelData and levelData.menuDishTypeNumMin) or 0
    self.m_levelDishMin = (levelData and levelData.menuDishNumRange and levelData.menuDishNumRange.Count > 0)
        and levelData.menuDishNumRange[0] or 0
    self.m_levelDrinkMin = (levelData and levelData.menuDrinkNumRange and levelData.menuDrinkNumRange.Count > 0)
        and levelData.menuDrinkNumRange[0] or 0

    
    local dishIds = {}
    if self.m_innSystem and self.m_innSystem.unlockedDishIds then
        for _, dishId in pairs(self.m_innSystem.unlockedDishIds) do
            local hasDish, dishData = Tables.innDishTable:TryGetValue(dishId)
            if hasDish and dishData then
                dishIds[#dishIds + 1] = dishId
                self.m_itemConfigById[dishId] = dishData
                self.m_isDrinkById[dishId] = false
            end
        end
    end
    self.m_unlockedDishIds = dishIds

    
    local drinkIds = {}
    for drinkId, drinkData in pairs(Tables.innDrinkTable) do
        if drinkData and (drinkData.unlockLevel or 0) <= innLevel and drinkId ~= Tables.innManagementConst.infiniteDrinkItemId then
            drinkIds[#drinkIds + 1] = drinkId
            self.m_itemConfigById[drinkId] = drinkData
            self.m_isDrinkById[drinkId] = true
        end
    end
    self.m_unlockedDrinkIds = drinkIds

    
    local drinkCategory = Tables.innManagementConst and Tables.innManagementConst.drinkCategory or ''
    local categories = {}
    for catId, catData in pairs(Tables.innDishCategoryTable) do
        if catData and catId ~= drinkCategory then
            categories[#categories + 1] = { id = catId, data = catData, sortId = catData.sortId or 0 }
        end
    end
    table.sort(categories, function(a, b)
        if a.sortId ~= b.sortId then
            return a.sortId < b.sortId
        end
        return tostring(a.id) < tostring(b.id)
    end)

    local tabList = {
        { kind = TAB_KIND_ALL },
    }
    for _, c in ipairs(categories) do
        tabList[#tabList + 1] = { kind = TAB_KIND_CATEGORY, categoryId = c.id, categoryData = c.data }
    end
    self.m_tabList = tabList
end

InnMenuSettingsCtrl._LoadSelectedFromPending = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    local menuItems = pending and pending.menuItems
    if not menuItems then
        return
    end
    local dishKnown, drinkKnown = {}, {}
    for _, id in ipairs(self.m_unlockedDishIds) do dishKnown[id] = true end
    for _, id in ipairs(self.m_unlockedDrinkIds) do drinkKnown[id] = true end

    
    local checkStock = not pending.softOpening
    local removedAny = false
    for i = 0, menuItems.Count - 1 do
        local mi = menuItems[i]
        if mi and not string.isEmpty(mi.itemId) then
            if mi.foodType == FOOD_TYPE.FoodTypeDish then
                if dishKnown[mi.itemId] then
                    if checkStock and self:_GetItemCraftable(mi.itemId) <= 0 then
                        removedAny = true
                    else
                        self.m_selectedDishes[#self.m_selectedDishes + 1] = mi.itemId
                    end
                end
            elseif mi.foodType == FOOD_TYPE.FoodTypeDrink then
                if drinkKnown[mi.itemId] then
                    if checkStock and self:_GetItemCraftable(mi.itemId) <= 0 then
                        removedAny = true
                    else
                        self.m_selectedDrinks[#self.m_selectedDrinks + 1] = mi.itemId
                    end
                end
            end
        end
    end
    if removedAny then
        self:_WritebackToPending()
    end
end

InnMenuSettingsCtrl._WritebackToPending = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if not pending or not pending.menuItems then
        return
    end
    local menuItems = pending.menuItems
    menuItems:Clear()
    for _, itemId in ipairs(self.m_selectedDishes) do
        local mi = CS.Beyond.Gameplay.InnSystem.MenuItem()
        mi.foodType = FOOD_TYPE.FoodTypeDish
        mi.itemId = itemId
        menuItems:Add(mi)
    end
    for _, itemId in ipairs(self.m_selectedDrinks) do
        local mi = CS.Beyond.Gameplay.InnSystem.MenuItem()
        mi.foodType = FOOD_TYPE.FoodTypeDrink
        mi.itemId = itemId
        menuItems:Add(mi)
    end
end





InnMenuSettingsCtrl._InitTopNode = HL.Method() << function(self)
    self.view.topNode.btnBack.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
end

InnMenuSettingsCtrl._InitTopicBar = HL.Method() << function(self)
    if self.view.topicNode and self.view.topicNode.InitInnTopicBar then
        self.view.topicNode:InitInnTopicBar(self.m_topicId or '')
    end
end





InnMenuSettingsCtrl._InitLeftNode = HL.Method() << function(self)
    local left = self.view.leftNode

    
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    left.innLevelRequirementsCell.titleTxt.text =
        string.format(Language.LUA_INN_MENU_SETTINGS_LEVEL_REQ_TITLE, innLevel)
    self.m_levelReqCache = self.m_levelReqCache or
        UIUtils.genCellCache(left.innLevelRequirementsCell.taskDetailsCell)

    
    local hasTopic, topicData = false, nil
    if not string.isEmpty(self.m_topicId) then
        hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
    end
    local isPrivateChef = hasTopic and topicData ~= nil and topicData.topicType == GEnums.InnTopicType.PrivateChef
    self.m_hasTopicReq = hasTopic and topicData ~= nil and topicData.requirementList.Count > 0
    left.topicRecipeRequirementsCell.gameObject:SetActive(self.m_hasTopicReq)
    if hasTopic and topicData then
        left.topicRecipeRequirementsCell.titleTxt.text = Language.LUA_INN_MENU_SETTINGS_TOPIC_REQ_TITLE
        self.m_topicReqCache = self.m_topicReqCache or
            UIUtils.genCellCache(left.topicRecipeRequirementsCell.taskDetailsCell)
    end

    left.requirementsNodeState:SetState(isPrivateChef and 'PrivateChef' or 'Normal')

    
    local isFashion = not hasTopic or isPrivateChef
    if isFashion then
        self.view.leftNode.topicTitleState.gameObject:SetActive(self.m_innSystem.innLevel >= Tables.innManagementConst.fashionUnlockLevel)
    end
    self.view.leftNode.topicTitleState:SetState((hasTopic and not isPrivateChef) and 'Topic' or 'Fashion')
    self.m_categoryTagCache = self.m_categoryTagCache or UIUtils.genCellCache(left.innItemTagCategory)
    self.m_affixTagCache = self.m_affixTagCache or UIUtils.genCellCache(left.innItemTagAffix)
    self:_RefreshHotTags()

    self:_RefreshLevelReqList()
    self:_RefreshTopicReqList()

    
    local hasTopicObjective = hasTopic and topicData ~= nil and not string.isEmpty(topicData.objectiveConditionId)
    self.view.leftNode.topicObjectiveNode.gameObject:SetActiveIfNecessary(hasTopicObjective)
    if hasTopicObjective then
        self.view.leftNode.topicObjectiveTxt:SetAndResolveTextStyle(topicData.objectiveDesc)
    end
end

InnMenuSettingsCtrl._RefreshHotTags = HL.Method() << function(self)
    local catList, affixList = nil, nil
    if string.isEmpty(self.m_topicId) then
        catList = GameInstance.player.innSystem.dailyCategoryIds
        affixList = GameInstance.player.innSystem.dailyAffixIds
    else
        local hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
        if hasTopic and topicData then
            if topicData.topicType == GEnums.InnTopicType.PrivateChef then
                catList = GameInstance.player.innSystem.privateChefDailyCategoryIds
                affixList = GameInstance.player.innSystem.privateChefDailyAffixIds
            else
                catList = topicData.hotCategory
                affixList = topicData.hotAffix
            end
        end
    end
    local catCount = (catList and catList.Count) or 0
    local affCount = (affixList and affixList.Count) or 0

    self.view.leftNode.categoryNode.gameObject:SetActiveIfNecessary(catCount > 0)
    self.m_categoryTagCache:Refresh(catCount, function(cell, index)
        cell:InitInnItemTag({
            tagId = catList[index - 1],
            isHot = false,
            upCount = 0,
        })
    end)
    self.view.leftNode.affixNode.gameObject:SetActiveIfNecessary(affCount > 0)
    self.m_affixTagCache:Refresh(affCount, function(cell, index)
        cell:InitInnItemTag({
            tagId = affixList[index - 1],
            isHot = false,
            upCount = 0,
        })
    end)
end

InnMenuSettingsCtrl._RefreshLevelReqList = HL.Method() << function(self)
    if not self.m_levelReqCache then
        return
    end

    
    local catSet = {}
    for _, dishId in ipairs(self.m_selectedDishes) do
        local cfg = self.m_itemConfigById[dishId]
        if cfg and cfg.category and not string.isEmpty(cfg.category) then
            catSet[cfg.category] = true
        end
    end
    local distinctCatCount = 0
    for _ in pairs(catSet) do
        distinctCatCount = distinctCatCount + 1
    end

    local rows = {
        {
            text = string.format(Language.LUA_INN_MENU_SETTINGS_REQ_DISH_TYPE, self.m_levelDishTypeMin),
            complete = distinctCatCount >= self.m_levelDishTypeMin,
        },
        {
            text = string.format(Language.LUA_INN_MENU_SETTINGS_REQ_DISH_DRINK,
                self.m_levelDishMin, self.m_levelDrinkMin),
            complete = #self.m_selectedDishes >= self.m_levelDishMin
                and #self.m_selectedDrinks >= self.m_levelDrinkMin,
        },
    }
    self.m_levelReqCache:Refresh(#rows, function(cell, index)
        local row = rows[index]
        cell.taskTxt:SetAndResolveTextStyle(row.text)
        cell.stateController:SetState(row.complete and 'Complete' or 'Warning')
    end)
end

InnMenuSettingsCtrl._RefreshTopicReqList = HL.Method() << function(self)
    if not self.m_topicReqCache then
        return
    end
    local hasTopic, topicData = false, nil
    if not string.isEmpty(self.m_topicId) then
        hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
    end
    if not hasTopic or not topicData then
        self.m_topicReqCache:Refresh(0)
        return
    end
    local requirementList = topicData.requirementList
    local reqCount = (requirementList and requirementList.Count) or 0
    if reqCount == 0 then
        self.m_topicReqCache:Refresh(0)
        return
    end

    local texts = {}
    self.m_topicReqCache:Refresh(1, function(cell, index)
        cell.taskTxt:SetAndResolveTextStyle(topicData.requirementDesc or '')
        texts[#texts + 1] = {
            text = topicData.requirementDesc or '',
            uiText = cell.taskTxt,
        }
        cell.stateController:SetState(self:_IsAllTopicReqMet() and 'Complete' or 'Warning')
    end)
    self.view.leftNode.itemRichText:InitItemRichText({
        texts = texts,
        posType = UIConst.UI_TIPS_POS_TYPE.RightTop,
        tipTransform = self.view.leftNode.itemRichText.transform,
        keyHintText = Language.LUA_INN_MENU_SETTINGS_TOPIC_REQ_TITLE,
        enableNavi = true,
    })
end

InnMenuSettingsCtrl._IsAllTopicReqMet = HL.Method().Return(HL.Boolean) << function(self)
    if string.isEmpty(self.m_topicId) then
        return true
    end
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
    if not hasTopic or not topicData or not topicData.requirementList then
        return true
    end
    local list = topicData.requirementList
    local nums = topicData.requirementNum
    for i = 0, list.Count - 1 do
        local reqId = list[i]
        local need = (nums and i < nums.Count) and nums[i] or 0
        if reqId and not string.isEmpty(reqId) and need > 0 then
            if self:_CountPerfectHits(reqId) < need then
                return false
            end
        end
    end
    return true
end

InnMenuSettingsCtrl._CountPerfectHits = HL.Method(HL.String).Return(HL.Number) << function(self, requirementId)
    if string.isEmpty(requirementId) then
        return 0
    end
    local n = 0
    for _, dishId in ipairs(self.m_selectedDishes) do
        if CS.Beyond.Gameplay.InnSystem.GetRequirementMatch(dishId, requirementId) == MATCH_LEVEL.Perfect then
            n = n + 1
        end
    end
    for _, drinkId in ipairs(self.m_selectedDrinks) do
        if CS.Beyond.Gameplay.InnSystem.GetRequirementMatch(drinkId, requirementId) == MATCH_LEVEL.Perfect then
            n = n + 1
        end
    end
    return n
end





InnMenuSettingsCtrl._InitRightNode = HL.Method() << function(self)
    local right = self.view.rightNode

    
    self.m_tabCache = self.m_tabCache or UIUtils.genCellCache(right.tabs.tabCell)
    self.m_currentTab = self.m_tabList[1]
    self:_RefreshTabs()
    self:_InitDrinkTabCell()

    
    local sortOptions = {
        { name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT, sortMode = SORT_DEFAULT },
        { name = Language.LUA_INN_MENU_SETTINGS_SORT_RARITY, sortMode = SORT_RARITY },
        { name = Language.LUA_INN_MENU_SETTINGS_SORT_PRICE, sortMode = SORT_PRICE },
        { name = Language.LUA_INN_MENU_SETTINGS_SORT_CRAFTABLE, sortMode = SORT_CRAFTABLE },
    }
    local sortCSIndex = 0
    for i, opt in ipairs(sortOptions) do
        if opt.sortMode == self.m_sortMode then
            sortCSIndex = i - 1
            break
        end
    end
    right.sortNodeUp:InitSortNode(sortOptions, function(optData, isIncremental)
        local changed = (optData and optData.sortMode ~= self.m_sortMode) or (isIncremental ~= self.m_isIncremental)
        if optData then
            self.m_sortMode = optData.sortMode or SORT_DEFAULT
        end
        self.m_isIncremental = isIncremental
        self:_RebuildDisplayItems()
        self:_RefreshScrollList()
        if changed then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_MENU_SETTINGS_TOAST_SORT_APPLIED)
        end
    end, sortCSIndex, self.m_isIncremental, true, right.filterBtn)

    
    right.filterBtn:InitFilterBtn({
        tagGroups = FilterUtils.generateConfig_INN_MENU_RECIPE(self.m_hasTopicReq, not self.m_innSystem.gameSetting.softOpening),
        selectedTags = self.m_selectedFilterTags,
        onConfirm = function(selectedTags)
            self.m_selectedFilterTags = selectedTags or {}
            self:_RebuildDisplayItems()
            self:_RefreshScrollList()
            if next(self.m_selectedFilterTags) ~= nil then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_MENU_SETTINGS_TOAST_FILTER_APPLIED)    
            end
        end,
        getResultCount = function(selectedTags)
            local old = self.m_selectedFilterTags
            self.m_selectedFilterTags = selectedTags or {}
            local n = self:_CountCandidatesAfterFilter()
            self.m_selectedFilterTags = old
            return n
        end,
        sortNodeWidget = right.sortNodeUp,
    })

    right.ingredientToggle:InitCommonToggle(function(isOn)
        self.m_showIngredient = isOn
        Notify(MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT, isOn)
    end, self.m_showIngredient, true)

    
    self.m_getScrollCell = UIUtils.genCachedCellFunction(right.scrollList)
    right.scrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateScrollCell(self.m_getScrollCell(object), LuaIndex(csIndex))
    end)
end

InnMenuSettingsCtrl._RefreshTabs = HL.Method() << function(self)
    self.m_tabCache:Refresh(#self.m_tabList, function(cell, index)
        local tab = self.m_tabList[index]
        self:_InitNormalTabCell(cell, tab)
    end)
end

InnMenuSettingsCtrl._InitNormalTabCell = HL.Method(HL.Any, HL.Table) << function(self, cell, tab)
    local labelText = ''
    local iconId = ''
    if tab.kind == TAB_KIND_ALL then
        labelText = Language.LUA_INN_MENU_SETTINGS_TAB_ALL_DISH
        iconId = ''
    elseif tab.kind == TAB_KIND_CATEGORY then
        labelText = (tab.categoryData and tab.categoryData.name) or tab.categoryId
        iconId = (tab.categoryData and tab.categoryData.iconId) or ''
    end
    if cell.norTabTxt then
        cell.norTabTxt.text = labelText
    end

    local hasIcon = not string.isEmpty(iconId)
    if cell.defaultIcon then
        if hasIcon then
            cell.defaultIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, iconId)
        end
    end
    if cell.selectedIcon then
        if hasIcon then
            cell.selectedIcon:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, iconId)
        end
    end

    if cell.toggle then
        cell.toggle.onValueChanged:RemoveAllListeners()
        local isOn = (not self.m_isDrinkTabActive) and self.m_currentTab == tab
        cell.toggle:SetIsOnWithoutNotify(isOn)
        cell.toggle.onValueChanged:AddListener(function(on)
            if on then
                self:_SwitchTab(tab, false, false)
            end
        end)
    end
end

InnMenuSettingsCtrl._InitDrinkTabCell = HL.Method() << function(self)
    local drinkCell = self.view.rightNode.tabs.drinkTabCell
    if drinkCell.norTabTxt then
        drinkCell.norTabTxt.text = Language.LUA_INN_MENU_SETTINGS_TAB_DRINK
    end
    if drinkCell.toggle then
        drinkCell.toggle.onValueChanged:RemoveAllListeners()
        drinkCell.toggle:SetIsOnWithoutNotify(self.m_isDrinkTabActive)
        drinkCell.toggle.onValueChanged:AddListener(function(on)
            if on then
                self:_SwitchTab(nil, true, false)
            end
        end)
    end
end

InnMenuSettingsCtrl._SwitchTab = HL.Method(HL.Opt(HL.Table, HL.Boolean, HL.Boolean)) <<
function(self, tab, isDrink, force)
    local nextIsDrink = isDrink == true
    local prevIsDrink = self.m_isDrinkTabActive
    local prevTab = self.m_currentTab

    if not nextIsDrink then
        tab = tab or self.m_tabList[1]
    end

    if not force and nextIsDrink == prevIsDrink and tab == prevTab then
        return
    end

    self.m_isDrinkTabActive = nextIsDrink
    self.m_currentTab = nextIsDrink and nil or tab

    
    if self.view.rightNode.ingredientToggle and self.view.rightNode.ingredientToggle.gameObject then
        self.view.rightNode.ingredientToggle.gameObject:SetActive(not nextIsDrink)
    end

    
    if self.view.bottomNode.menuNode then
        self.view.bottomNode.menuNode:SetState(nextIsDrink and 'Drink' or 'Dish')
    end
    if nextIsDrink ~= prevIsDrink then
        if nextIsDrink then
            self:_SetMenuDrinkNaviTarget(true)
        else
            self:_SetMenuDishNaviTarget(true)
        end
    end

    self:_RebuildDisplayItems()
    self:_RefreshScrollList()

    if nextIsDrink ~= prevIsDrink then
        self:_PlayExpendCellsInAnim(nextIsDrink)
    end
end

InnMenuSettingsCtrl._RestoreActiveTab = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if arg and arg.isDrinkTab == true then
        self.view.rightNode.tabs.drinkTabCell.toggle:SetIsOnWithoutNotify(true)
        self:_SwitchTab(nil, true, true)
        return
    end

    local tabIndex = (arg and arg.tabIndex) or 1
    local tabCell = self.m_tabCache:Get(tabIndex)
    if tabCell and tabCell.toggle then
        tabCell.toggle:SetIsOnWithoutNotify(true)
    end
    self:_SwitchTab(self.m_tabList[tabIndex], false, true)
end






InnMenuSettingsCtrl._BuildBaseCandidateIds = HL.Method().Return(HL.Table) << function(self)
    local list = {}
    if self.m_isDrinkTabActive then
        for _, id in ipairs(self.m_unlockedDrinkIds) do
            list[#list + 1] = id
        end
    else
        local tab = self.m_currentTab
        if tab and tab.kind == TAB_KIND_CATEGORY then
            for _, id in ipairs(self.m_unlockedDishIds) do
                local cfg = self.m_itemConfigById[id]
                if cfg and cfg.category == tab.categoryId then
                    list[#list + 1] = id
                end
            end
        else
            for _, id in ipairs(self.m_unlockedDishIds) do
                list[#list + 1] = id
            end
        end
    end
    return list
end

InnMenuSettingsCtrl._IsItemSelected = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    local pool = self.m_isDrinkById[itemId] and self.m_selectedDrinks or self.m_selectedDishes
    for _, id in ipairs(pool) do
        if id == itemId then
            return true
        end
    end
    return false
end

InnMenuSettingsCtrl._RebuildDisplayItems = HL.Method() << function(self)
    
    
    local selectionOrderById = {}
    for i, id in ipairs(self.m_selectedDishes) do
        selectionOrderById[id] = i
    end
    for i, id in ipairs(self.m_selectedDrinks) do
        selectionOrderById[id] = i
    end

    
    local selectedInfos = {}
    local unselectedInfos = {}
    for _, id in ipairs(self:_BuildBaseCandidateIds()) do
        local selOrder = selectionOrderById[id]
        if selOrder then
            selectedInfos[#selectedInfos + 1] = {
                id = id,
                selectionOrder = selOrder,
            }
        elseif self:_PassesFilter(id) then
            unselectedInfos[#unselectedInfos + 1] = {
                id = id,
                sortKey = self:_GetSortKey(id),
                sortId2 = self:_GetItemSortId2(id),
            }
        end
    end

    
    table.sort(selectedInfos, Utils.genSortFunction({ 'selectionOrder' }, true))

    
    local keyList = (self.m_sortMode == SORT_DEFAULT)
        and { 'sortKey', 'sortId2', 'id' }
        or { 'sortKey', 'id' }
    table.sort(unselectedInfos, Utils.genSortFunction(keyList, self.m_isIncremental))

    local out = {}
    for _, info in ipairs(selectedInfos) do
        out[#out + 1] = info.id
    end
    for _, info in ipairs(unselectedInfos) do
        out[#out + 1] = info.id
    end
    self.m_displayItemIds = out
end

InnMenuSettingsCtrl._GetItemSortId2 = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    local hasItem, itemData = Tables.itemTable:TryGetValue(itemId)
    return (hasItem and itemData and itemData.sortId2) or 0
end

InnMenuSettingsCtrl._GetItemRarity = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    local hasItem, itemData = Tables.itemTable:TryGetValue(itemId)
    return (hasItem and itemData and itemData.rarity) or 0
end

InnMenuSettingsCtrl._GetItemPrice = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    local cfg = self.m_itemConfigById[itemId]
    return (cfg and cfg.price) or 0
end

InnMenuSettingsCtrl._GetItemCraftable = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    if not GameInstance.player or not GameInstance.player.inventory then
        return 0
    end
    if self.m_isDrinkById[itemId] then
        return InnUtils.getIngredientCount(itemId)
    end
    local cfg = self.m_itemConfigById[itemId]
    if not cfg or not cfg.ingredient or cfg.ingredient.Count == 0 then
        return 0
    end
    local minBatches = math.huge
    for i = 0, cfg.ingredient.Count - 1 do
        local ingId = cfg.ingredient[i]
        if not string.isEmpty(ingId) then
            local need = (cfg.ingredientNum and i < cfg.ingredientNum.Count) and cfg.ingredientNum[i] or 1
            if need <= 0 then need = 1 end
            local have = InnUtils.getIngredientCount(ingId)
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

InnMenuSettingsCtrl._GetSortKey = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    local mode = self.m_sortMode
    if mode == SORT_RARITY then
        return self:_GetItemRarity(itemId)
    elseif mode == SORT_PRICE then
        return self:_GetItemPrice(itemId)
    elseif mode == SORT_CRAFTABLE then
        return self:_GetItemCraftable(itemId)
    end
    
    return self:_GetItemHotTagCount(itemId)
end

InnMenuSettingsCtrl._GetItemHotTagCount = HL.Method(HL.String).Return(HL.Number) << function(self, itemId)
    local cfg = self.m_itemConfigById[itemId]
    if not cfg then
        return 0
    end
    local n = 0
    local isDrink = self.m_isDrinkById[itemId]
    local categoryId = isDrink and (Tables.innManagementConst and Tables.innManagementConst.drinkCategory or '')
        or cfg.category
    if categoryId and InnUtils.isItemTagTopicHot(self.m_topicId, categoryId) then
        n = n + 1
    end
    local affixes = cfg.affix
    if affixes then
        for i = 0, affixes.Count - 1 do
            local tagId = affixes[i]
            if tagId and not string.isEmpty(tagId) and InnUtils.isItemTagTopicHot(self.m_topicId, tagId) then
                n = n + 1
            end
        end
    end
    return n
end

InnMenuSettingsCtrl._RefreshScrollList = HL.Method() << function(self)
    local hasAny = self.m_displayItemIds and #self.m_displayItemIds > 0
    if self.view.rightNode.stateController then
        local state = 'Normal'
        if not hasAny then
            state = #self:_BuildBaseCandidateIds() > 0 and 'EmptyFilter' or 'Empty'
        end
        self.view.rightNode.stateController:SetState(state)
    end
    self.view.rightNode.scrollList:UpdateCount(hasAny and #self.m_displayItemIds or 0, true)
    self:_SetFirstScrollNaviTarget()
end

InnMenuSettingsCtrl._OnUpdateScrollCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    if not cell then return end
    local itemId = self.m_displayItemIds[luaIndex]
    if not itemId then return end
    local isSelected = self:_IsItemSelected(itemId)
    local isDrink = self.m_isDrinkById[itemId]
    cell:InitInnRecipeOverviewCell({
        itemId = itemId,
        showDemandTag = false,
        showTopicTag = false,
        topicId = self.m_topicId,
        showIngredient = self.m_showIngredient and not isDrink,
        onClickCallback = function()
            self:_OnRecipeCellClicked(itemId)
        end,
        onDeleteClick = function()
            self:_OnRecipeCellClicked(itemId)
        end,
        infinityMode = self.m_innSystem.gameSetting.softOpening,
        isItemTipsLeft = luaIndex % 2 == 0,
    })
    cell:SetSelected(isSelected)
    cell:SetTopicTagActive(InnUtils.itemSatisfiesAnyTopicReq(itemId, self.m_topicId))
end

InnMenuSettingsCtrl._RefreshVisibleCellsSelected = HL.Method(HL.Opt(HL.String)) << function(self, playAnimItemId)
    if not self.m_getScrollCell then return end
    local list = self.view.rightNode.scrollList
    local count = #self.m_displayItemIds
    for i = 1, count do
        local obj = list:Get(CSIndex(i))
        if obj then
            local cell = self.m_getScrollCell(obj)
            if cell then
                local itemId = self.m_displayItemIds[i]
                if itemId then
                    cell:SetSelected(self:_IsItemSelected(itemId), itemId == playAnimItemId)
                end
            end
        end
    end
end

InnMenuSettingsCtrl._SetFirstScrollNaviTarget = HL.Method() << function(self)
    if not self.m_getScrollCell then return end
    if self.view.bottomNode.naviGroup.IsTopLayer then
        return
    end
    local firstObj = self.view.rightNode.scrollList:Get(CSIndex(1))
    if not firstObj then return end
    local cell = self.m_getScrollCell(firstObj)
    if cell and cell.view and cell.view.naviTarget then
        self:SetNaviTarget(cell.view.naviTarget)
    end
end

InnMenuSettingsCtrl._OnInnRecipeOverviewShowIngredient = HL.Method(HL.Boolean) << function(self, showIngredient)
    if self.m_showIngredient == showIngredient then
        return
    end
    self.m_showIngredient = showIngredient
    self.view.rightNode.ingredientToggle:SetValue(showIngredient)
end

InnMenuSettingsCtrl._OnGuideToggleRecipeIngredient = HL.Method(HL.Table) << function(self, args)
    local isOn = unpack(args) == true
    Notify(MessageConst.ON_INN_RECIPE_OVERVIEW_SHOW_INGREDIENT, isOn)
end

InnMenuSettingsCtrl._OnInnDailyFashionChanged = HL.Method() << function(self)
    if not self:IsShow() or not InnUtils.isTopicUsingDailyFashion(self.m_topicId) then
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_INN_DAILY_FASHION_REFRESHED_POPUP,
        hideCancel = true,
        onConfirm = function()
            InnUtils.exitToTopicSelectionOrLevel()
        end,
    })
end






InnMenuSettingsCtrl._BuildItemFilterInfo = HL.Method(HL.String).Return(HL.Table) << function(self, itemId)
    return FilterUtils.processInnRecipe(
        itemId,
        self.m_itemConfigById[itemId],
        self.m_isDrinkById[itemId] == true,
        self.m_topicId)
end

InnMenuSettingsCtrl._PassesFilter = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    local tags = self.m_selectedFilterTags
    if not tags or #tags == 0 then
        return true
    end
    return FilterUtils.checkIfPassFilter(self:_BuildItemFilterInfo(itemId), tags)
end

InnMenuSettingsCtrl._CountCandidatesAfterFilter = HL.Method().Return(HL.Number) << function(self)
    local candidates = self:_BuildBaseCandidateIds()
    local n = 0
    for _, id in ipairs(candidates) do
        if self:_IsItemSelected(id) or self:_PassesFilter(id) then
            n = n + 1
        end
    end
    return n
end





InnMenuSettingsCtrl._OnRecipeCellClicked = HL.Method(HL.String) << function(self, itemId)
    local isDrink = self.m_isDrinkById[itemId]
    local pool = isDrink and self.m_selectedDrinks or self.m_selectedDishes
    local foundIndex
    for i, id in ipairs(pool) do
        if id == itemId then
            foundIndex = i
            break
        end
    end

    if foundIndex then
        table.remove(pool, foundIndex)
    else
        
        if not self.m_innSystem.gameSetting.softOpening and self:_GetItemCraftable(itemId) <= 0 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_MENU_SETTINGS_TOAST_ITEM_INSUFFICIENT)
            return
        end
        local maxNum = isDrink and (self.m_innSystem.menuDrinkNum or 0) or (self.m_innSystem.menuDishNum or 0)
        if #pool >= maxNum then
            Notify(MessageConst.SHOW_TOAST,
                isDrink and Language.LUA_INN_MENU_SETTINGS_TOAST_DRINK_FULL
                    or Language.LUA_INN_MENU_SETTINGS_TOAST_DISH_FULL)
            return
        end
        pool[#pool + 1] = itemId
    end

    self:_WritebackToPending()

    
    self:_RefreshVisibleCellsSelected(itemId)
    self:_RefreshLevelReqList()
    self:_RefreshTopicReqList()
    local addedItemId = (not foundIndex) and itemId or nil
    self:_RefreshBottomNode(addedItemId)
end

InnMenuSettingsCtrl._DeleteSelectedAt = HL.Method(HL.Boolean, HL.Number) << function(self, isDrink, index)
    local pool = isDrink and self.m_selectedDrinks or self.m_selectedDishes
    if index < 1 or index > #pool then return end
    table.remove(pool, index)
    self:_WritebackToPending()
    self:_RebuildDisplayItems()
    self:_RefreshScrollList()
    self:_RefreshLevelReqList()
    self:_RefreshTopicReqList()
    self:_RefreshBottomNode()
end





InnMenuSettingsCtrl._InitBottomNode = HL.Method() << function(self)
    local bottom = self.view.bottomNode

    bottom.startOperatingBtn.onClick:AddListener(function()
        self:_OnClickStartOperating()
    end)

    if bottom.recipeBtn then
        bottom.recipeBtn.onClick:AddListener(function()
            PhaseManager:OpenPhase(PhaseId.InnMenuOverview, {
                showIngredient = self.m_showIngredient,
            })
            self.view.bottomNode.naviGroup:ManuallyStopFocus()
        end)
    end

    
    self.m_dishExpendDishCache = UIUtils.genCellCache(bottom.dishExpendNode.innDishRecipeCell)
    self.m_drinkExpendDrinkCache = UIUtils.genCellCache(bottom.drinkExpendNode.innDrinkRecipeCell)

    
    self:_BindExpendStatusButtons(bottom.dishExpendNode)
    self:_BindExpendStatusButtons(bottom.drinkExpendNode)

    self:_RefreshBottomNode()
end

InnMenuSettingsCtrl._OnClickStartOperating = HL.Method() << function(self)
    if not self:_IsAllRequirementsMet() then
        return
    end
    if not self.m_innSystem then
        return
    end

    if not self.m_innSystem.gameSetting.softOpening then
        local minCount = (Tables.innManagementConst and Tables.innManagementConst.recipeRecommendMinCraftCount) or 0
        local insufficientItems = self:_CollectInsufficientItems(minCount)
        if #insufficientItems > 0 then
            self:_OpenStartConfirm(minCount, insufficientItems)
            return
        end
    end

    self:_DoStartGame()
end

InnMenuSettingsCtrl._OpenStartConfirm = HL.Method(HL.Number, HL.Table) << function(self, minCount, insufficientItems)
    UIManager:Open(PanelId.InnStartConfirm, {
        titleTxt = string.format(Language.LUA_INN_START_CONFIRM_INSUFFICIENT_TITLE, minCount),
        items = insufficientItems,
        onConfirm = function()
            self:_DoStartGame()
        end,
    })
end

InnMenuSettingsCtrl._CollectInsufficientItems = HL.Method(HL.Number).Return(HL.Table) << function(self, minCount)
    local result = {}
    local function collect(pool, isDrink)
        for _, itemId in ipairs(pool) do
            local count = self:_GetItemCraftable(itemId)
            if count < minCount then
                result[#result + 1] = {
                    id = itemId,
                    count = count,
                    isDrink = isDrink,
                }
            end
        end
    end
    collect(self.m_selectedDishes, false)
    collect(self.m_selectedDrinks, true)
    return result
end

InnMenuSettingsCtrl._DoStartGame = HL.Method() << function(self)
    if self.m_innSystem then
        self.m_innSystem:SendStartGame()
    end
end

InnMenuSettingsCtrl._BindExpendStatusButtons = HL.Method(HL.Any) << function(self, expendNode)
    local function toggleDishDrinkTab()
        if self.m_isDrinkTabActive then
            self.m_tabCache:Get(1).toggle.isOn = true
        else
            self.view.rightNode.tabs.drinkTabCell.toggle.isOn = true
        end
    end
    if expendNode.dishNode and expendNode.dishNode.button then
        expendNode.dishNode.button.onClick:RemoveAllListeners()
        expendNode.dishNode.button.onClick:AddListener(toggleDishDrinkTab)
    end
    if expendNode.drinkNode and expendNode.drinkNode.button then
        expendNode.drinkNode.button.onClick:RemoveAllListeners()
        expendNode.drinkNode.button.onClick:AddListener(toggleDishDrinkTab)
    end
end

InnMenuSettingsCtrl._SetMenuDishNaviTarget = HL.Method(HL.Boolean) << function(self, isFirst)
    if not self.view.bottomNode.naviGroup.IsTopLayer then
        return
    end
    local index = isFirst and self.m_dishExpendDishCache:GetCount() or 1
    local firstDishCell = self.m_dishExpendDishCache:Get(index)
    if firstDishCell then
        self:SetNaviTarget(firstDishCell.view.naviTarget)
    end
end

InnMenuSettingsCtrl._SetMenuDrinkNaviTarget = HL.Method(HL.Boolean) << function(self, isFirst)
    if not self.view.bottomNode.naviGroup.IsTopLayer then
        return
    end
    local index = isFirst and self.m_drinkExpendDrinkCache:GetCount() or 1
    local firstDrinkCell = self.m_drinkExpendDrinkCache:Get(index)
    if firstDrinkCell then
        self:SetNaviTarget(firstDrinkCell.view.naviTarget)
    end
end

InnMenuSettingsCtrl._RefreshBottomNode = HL.Method(HL.Opt(HL.String)) << function(self, playAnimItemId)
    local bottom = self.view.bottomNode
    local dishMax = (self.m_innSystem and self.m_innSystem.menuDishMaxNum) or 0
    local drinkMax = (self.m_innSystem and self.m_innSystem.menuDrinkMaxNum) or 0
    local dishUnlocked = (self.m_innSystem and self.m_innSystem.menuDishNum) or 0
    local drinkUnlocked = (self.m_innSystem and self.m_innSystem.menuDrinkNum) or 0

    
    self.m_dishExpendDishCache:Refresh(dishMax, function(cell, index)
        self:_InitRecipeCell(cell, false, dishMax - index + 1, dishUnlocked, playAnimItemId)
    end)
    
    self.m_drinkExpendDrinkCache:Refresh(drinkMax, function(cell, index)
        self:_InitRecipeCell(cell, true, drinkMax - index + 1, drinkUnlocked, playAnimItemId)
    end)

    
    self:_RefreshExpendStatusCells(bottom.dishExpendNode, dishUnlocked, drinkUnlocked)
    self:_RefreshExpendStatusCells(bottom.drinkExpendNode, dishUnlocked, drinkUnlocked)

    
    bottom.stateController:SetState(self:_IsAllRequirementsMet() and 'Normal' or 'Lock')
end

InnMenuSettingsCtrl._InitRecipeCell = HL.Method(HL.Any, HL.Boolean, HL.Number, HL.Number, HL.Opt(HL.String)) <<
function(self, cell, isDrink, index, unlockedNum, playAnimItemId)
    local pool = isDrink and self.m_selectedDrinks or self.m_selectedDishes
    local isLocked = index > unlockedNum
    local itemId = (not isLocked) and pool[index] or ''
    cell:InitInnRecipeCell({
        itemId = itemId or '',
        isLocked = isLocked,
        onDeleteClick = function()
            self:_DeleteSelectedAt(isDrink, index)
        end,
    })
    cell.gameObject.name = "Recipe" .. index
    if isDrink then
        cell.view.btnMinus.customBindingViewLabelText = Language.key_hint_inn_menu_delete_drink
    end

    if playAnimItemId and itemId == playAnimItemId and cell.view.animationWrapper then
        cell.view.animationWrapper:PlayInAnimation()
    end
end

InnMenuSettingsCtrl._PlayExpendCellsInAnim = HL.Method(HL.Boolean) << function(self, isDrink)
    if self.m_expendCellAnimCor then
        self.m_expendCellAnimCor = self:_ClearCoroutine(self.m_expendCellAnimCor)
    end
    local cache = isDrink and self.m_drinkExpendDrinkCache or self.m_dishExpendDishCache
    local count = cache:GetCount()
    if count <= 0 then
        return
    end
    for i = 1, count do
        local cell = cache:Get(i)
        if cell and cell.view.animationWrapper then
            cell.view.animationWrapper:SampleToInAnimationBegin()
        end
    end
    self.m_expendCellAnimCor = self:_StartCoroutine(function()
        for i = count, 1, -1 do
            local cell = cache:Get(i)
            if cell and cell.view.animationWrapper then
                cell.view.animationWrapper:PlayInAnimation()
            end
            if i > 1 then
                coroutine.wait(EXPEND_CELL_IN_ANIM_INTERVAL)
            end
        end
        self.m_expendCellAnimCor = nil
    end)
end

InnMenuSettingsCtrl._RefreshExpendStatusCells = HL.Method(HL.Any, HL.Number, HL.Number) <<
function(self, expendNode, dishUnlocked, drinkUnlocked)
    if expendNode.dishNode then
        local dishCur = #self.m_selectedDishes
        if expendNode.dishNode.expendNumTxt then
            expendNode.dishNode.expendNumTxt.text =
                string.format("%d/%d", dishCur, dishUnlocked)
        end
        if expendNode.dishNode.stateController then
            expendNode.dishNode.stateController:SetState(
                dishCur < self.m_levelDishMin and 'Red' or 'Normal')
        end
    end
    if expendNode.drinkNode then
        local drinkCur = #self.m_selectedDrinks
        if expendNode.drinkNode.expendNumTxt then
            expendNode.drinkNode.expendNumTxt.text =
                string.format("%d/%d", drinkCur, drinkUnlocked)
        end
        if expendNode.drinkNode.stateController then
            expendNode.drinkNode.stateController:SetState(
                drinkCur < self.m_levelDrinkMin and 'Red' or 'Normal')
        end
    end
end

InnMenuSettingsCtrl._IsAllRequirementsMet = HL.Method().Return(HL.Boolean) << function(self)
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
    local isPrivateChef = hasTopic and topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef

    if not isPrivateChef then
        
        local catSet = {}
        for _, dishId in ipairs(self.m_selectedDishes) do
            local cfg = self.m_itemConfigById[dishId]
            if cfg and cfg.category and not string.isEmpty(cfg.category) then
                catSet[cfg.category] = true
            end
        end
        local distinctCatCount = 0
        for _ in pairs(catSet) do distinctCatCount = distinctCatCount + 1 end
        if distinctCatCount < self.m_levelDishTypeMin then return false end

        
        if #self.m_selectedDishes < self.m_levelDishMin then return false end
        if #self.m_selectedDrinks < self.m_levelDrinkMin then return false end
    end

    
    if not self:_IsAllTopicReqMet() then
        return false
    end

    return true
end





InnMenuSettingsCtrl._RefreshExpendStatusButtonsInputParent = HL.Method(HL.Boolean) << function(self, isFocused)
    if not DeviceInfo.usingController then
        return
    end
    local bottom = self.view.bottomNode
    local parentGroupId = isFocused and bottom.menuNodeInputBindingGroupMonoTarget.groupId or self.view.inputGroup.groupId
    for _, expendNode in ipairs({ bottom.dishExpendNode, bottom.drinkExpendNode }) do
        for _, node in ipairs({ expendNode.dishNode, expendNode.drinkNode }) do
            if node and node.button then
                InputManagerInst:ChangeParent(true, node.button.groupId, parentGroupId)
            end
        end
    end
end

InnMenuSettingsCtrl._InitController = HL.Method() << function(self)
    self:_RefreshExpendStatusButtonsInputParent(false)
    self.view.bottomNode.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self:_RefreshExpendStatusButtonsInputParent(isFocused)
        if isFocused then
            if self.m_isDrinkTabActive then
                self:_SetMenuDrinkNaviTarget(true)
            else
                self:_SetMenuDishNaviTarget(true)
            end
        end
    end)
    self.view.bottomNode.naviGroup.onDefaultNaviFailed:AddListener(function(dir)
        if dir == Unity.UI.NaviDirection.Right then
            if not self.m_isDrinkTabActive then
                self.view.rightNode.tabs.drinkTabCell.toggle.isOn = true
            end
        elseif dir == Unity.UI.NaviDirection.Left then
            if self.m_isDrinkTabActive then
                self.m_tabCache:Get(1).toggle.isOn = true
                self:_SetMenuDishNaviTarget(false)
            end
        end
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnMenuSettingsCtrl._TryRecoverStartConfirm = HL.Method() << function(self)
    if not self.m_innSystem then
        return
    end
    if not self:_IsAllRequirementsMet() then
        return
    end
    local minCount = (Tables.innManagementConst and Tables.innManagementConst.recipeRecommendMinCraftCount) or 0
    local insufficientItems = self:_CollectInsufficientItems(minCount)
    if #insufficientItems == 0 then
        return
    end
    self:_OpenStartConfirm(minCount, insufficientItems)
end



HL.Commit(InnMenuSettingsCtrl)