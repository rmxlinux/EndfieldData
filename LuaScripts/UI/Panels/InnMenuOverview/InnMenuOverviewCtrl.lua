local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnMenuOverview
local PHASE_ID = PhaseId.InnMenuOverview

local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE

local TAB_DISH = 1
local TAB_DRINK = 2


InnMenuOverviewCtrl = HL.Class('InnMenuOverviewCtrl', uiCtrl.UICtrl)

InnMenuOverviewCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.GUIDE_INN_TOGGLE_RECIPE_INGREDIENT] = '_OnGuideToggleRecipeIngredient',
}



InnMenuOverviewCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnMenuOverviewCtrl.m_topicId = HL.Field(HL.String) << ''
InnMenuOverviewCtrl.m_curTab = HL.Field(HL.Number) << TAB_DISH
InnMenuOverviewCtrl.m_dishIds = HL.Field(HL.Table)
InnMenuOverviewCtrl.m_drinkIds = HL.Field(HL.Table)
InnMenuOverviewCtrl.m_showIngredient = HL.Field(HL.Boolean) << false
InnMenuOverviewCtrl.m_getCell = HL.Field(HL.Function)



InnMenuOverviewCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_dishIds = {}
    self.m_drinkIds = {}
    self.m_curTab = TAB_DISH
    self.m_showIngredient = false

    if arg then
        if arg.tabIndex == TAB_DISH or arg.tabIndex == TAB_DRINK then
            self.m_curTab = arg.tabIndex
        end
        if arg.showIngredient ~= nil then
            self.m_showIngredient = arg.showIngredient
        end
    end

    self:_LoadMenuItems()

    self:_InitTopNode()
    self:_InitTabs()
    self:_InitShowToggle()
    self:_InitScrollList()

    self:_InitController()

    self:_SwitchTab(self.m_curTab, true)
end

InnMenuOverviewCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        tabIndex = self.m_curTab,
        showIngredient = self.m_showIngredient,
    }
end




InnMenuOverviewCtrl._LoadMenuItems = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    self.m_topicId = (pending and pending.topicId) or ''

    local menuItems = pending and pending.menuItems
    if not menuItems then
        return
    end
    for i = 0, menuItems.Count - 1 do
        local mi = menuItems[i]
        if mi and not string.isEmpty(mi.itemId) then
            if mi.foodType == FOOD_TYPE.FoodTypeDish then
                self.m_dishIds[#self.m_dishIds + 1] = mi.itemId
            elseif mi.foodType == FOOD_TYPE.FoodTypeDrink then
                self.m_drinkIds[#self.m_drinkIds + 1] = mi.itemId
            end
        end
    end
end





InnMenuOverviewCtrl._InitTopNode = HL.Method() << function(self)
    self.view.topNode.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
end

InnMenuOverviewCtrl._InitTabs = HL.Method() << function(self)
    self:_BindTabToggle(self.view.tabs.dishTab, TAB_DISH)
    self:_BindTabToggle(self.view.tabs.drinkTab, TAB_DRINK)
end

InnMenuOverviewCtrl._BindTabToggle = HL.Method(HL.Any, HL.Number) << function(self, tabCell, tabKind)
    if not tabCell or not tabCell.toggle then
        return
    end
    tabCell.toggle.onValueChanged:RemoveAllListeners()
    tabCell.toggle:SetIsOnWithoutNotify(self.m_curTab == tabKind)
    tabCell.toggle.onValueChanged:AddListener(function(on)
        if on then
            self:_SwitchTab(tabKind, false)
        end
    end)
end

InnMenuOverviewCtrl._InitShowToggle = HL.Method() << function(self)
    if not self.view.showToggle then
        return
    end
    self.view.showToggle:InitCommonToggle(function(isOn)
        self.m_showIngredient = isOn
        self:_RefreshVisibleCellsShowIngredient()
    end, self.m_showIngredient, true)
end

InnMenuOverviewCtrl._OnGuideToggleRecipeIngredient = HL.Method(HL.Table) << function(self, args)
    local isOn = unpack(args) == true
    if not self.view.showToggle or self.m_showIngredient == isOn then
        return
    end
    self.view.showToggle:SetValue(isOn)
end

InnMenuOverviewCtrl._RefreshVisibleCellsShowIngredient = HL.Method() << function(self)
    if not self.m_getCell then
        return
    end
    local list = self.view.scrollList
    local showIngredient = self.m_showIngredient and self.m_curTab == TAB_DISH
    for i = 1, self:_GetMaxNum() do
        local obj = list:Get(CSIndex(i))
        if obj then
            local cell = self.m_getCell(obj)
            if cell then
                cell:SetShowIngredient(showIngredient)
            end
        end
    end
end

InnMenuOverviewCtrl._InitScrollList = HL.Method() << function(self)
    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
end





InnMenuOverviewCtrl._SwitchTab = HL.Method(HL.Number, HL.Boolean) << function(self, tabKind, force)
    if not force and tabKind == self.m_curTab then
        return
    end
    self.m_curTab = tabKind

    
    if self.view.showToggle and self.view.showToggle.gameObject then
        self.view.showToggle.gameObject:SetActive(tabKind == TAB_DISH)
    end

    self:_RefreshList()
    self:_SetMenuFirstNaviTarget()
end

InnMenuOverviewCtrl._CurrentList = HL.Method().Return(HL.Table) << function(self)
    return self.m_curTab == TAB_DRINK and self.m_drinkIds or self.m_dishIds
end

InnMenuOverviewCtrl._GetMaxNum = HL.Method().Return(HL.Number) << function(self)
    if not self.m_innSystem then
        return 0
    end
    if self.m_curTab == TAB_DRINK then
        return self.m_innSystem.menuDrinkMaxNum or 0
    end
    return self.m_innSystem.menuDishMaxNum or 0
end

InnMenuOverviewCtrl._GetUnlockedNum = HL.Method().Return(HL.Number) << function(self)
    if not self.m_innSystem then
        return 0
    end
    if self.m_curTab == TAB_DRINK then
        return self.m_innSystem.menuDrinkNum or 0
    end
    return self.m_innSystem.menuDishNum or 0
end

InnMenuOverviewCtrl._RefreshList = HL.Method() << function(self)
    local list = self:_CurrentList()
    local count = #list
    local hasAny = count > 0

    if self.view.emptyNode then
        self.view.emptyNode.gameObject:SetActive(not hasAny)
    end
    if not hasAny and self.view.emptyText then
        self.view.emptyText.text = (self.m_curTab == TAB_DRINK)
            and Language.LUA_INN_MENU_OVERVIEW_EMPTY_DRINK
            or Language.LUA_INN_MENU_OVERVIEW_EMPTY_DISH
    end

    self.view.scrollList:UpdateCount(hasAny and self:_GetMaxNum() or 0, true)
end

InnMenuOverviewCtrl._SetMenuFirstNaviTarget = HL.Method() << function(self)
    local firstObj = self.view.scrollList:Get(CSIndex(1))
    if not firstObj then 
        return 
    end
    local cell = self.m_getCell(firstObj)
    if not cell then 
        return 
    end
    self:ClearNaviTarget()
    self:SetNaviTarget(cell.view.naviTarget)
end

InnMenuOverviewCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    if not cell then
        return
    end
    local list = self:_CurrentList()
    local itemId = list[luaIndex]

    
    if not itemId or string.isEmpty(itemId) then
        local unlocked = self:_GetUnlockedNum()
        local maxNum = self:_GetMaxNum()
        if luaIndex <= unlocked then
            cell:SetEmpty()
        elseif luaIndex <= maxNum then
            cell:SetEmptyLocked()
        end
        return
    end

    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    local infinityMode = pending and pending.softOpening or false

    cell:InitInnRecipeOverviewCell({
        itemId = itemId,
        showDemandTag = false,
        showTopicTag = false,
        topicId = self.m_topicId,
        showIngredient = self.m_showIngredient and self.m_curTab == TAB_DISH,
        infinityMode = infinityMode,
        isItemTipsLeft = luaIndex % 2 == 1,
    })
    cell:SetTopicTagActive(InnUtils.itemSatisfiesAnyTopicReq(itemId, self.m_topicId))
end





InnMenuOverviewCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



HL.Commit(InnMenuOverviewCtrl)
