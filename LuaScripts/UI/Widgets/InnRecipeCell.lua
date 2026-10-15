local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnRecipeCell = HL.Class('InnRecipeCell', UIWidgetBase)


InnRecipeCell._OnFirstTimeInit = HL.Override() << function(self)
    
end






InnRecipeCell.InitInnRecipeCell = HL.Method(HL.Table) << function(self, arg)
    self:_FirstTimeInit()

    if arg.isLocked then
        self.view.stateController:SetState("Locked")
        return
    end
    
    if string.isEmpty(arg.itemId) then
        self.view.stateController:SetState("Empty")
        return
    end

    self.view.stateController:SetState("Normal")
    self.view.icon:InitItemIcon(arg.itemId)
    self.view.btnMinus.onClick:RemoveAllListeners()
    self.view.btnMinus.onClick:AddListener(function()
        if arg.onDeleteClick then
            arg.onDeleteClick()
        end
    end)
    local price = 0
    local _, dish = Tables.innDishTable:TryGetValue(arg.itemId)
    if dish then
        price = dish.price
    end
    local _, drink = Tables.innDrinkTable:TryGetValue(arg.itemId)
    if drink then
        price = drink.price
    end
    local hasCategory, categoryData = false, nil
    if dish and not string.isEmpty(dish.category) then
        hasCategory, categoryData = Tables.innDishCategoryTable:TryGetValue(dish.category)
    end
    self.view.imgCategory.gameObject:SetActive(hasCategory == true)
    if hasCategory then
        self.view.imgCategory:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TYPE, categoryData.richTextIconId)
    end
    self.view.count.text = tostring(price)
    self.view.rarityLine.color = UIUtils.getItemRarityColor(Tables.itemTable[arg.itemId].rarity)
end

HL.Commit(InnRecipeCell)
return InnRecipeCell

