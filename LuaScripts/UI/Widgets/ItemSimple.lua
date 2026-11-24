local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ItemSimple = HL.Class('ItemSimple', UIWidgetBase)


ItemSimple._OnFirstTimeInit = HL.Override() << function(self)
end

ItemSimple.InitItemSimple = HL.Method(HL.String, HL.Number, HL.Opt(HL.Number)) << function(self, itemId, itemCount, prob)
    self:_FirstTimeInit()
    local data = Tables.itemTable[itemId]
    self.view.icon:InitItemIcon(data.id)
    local rarityColor = UIUtils.getItemRarityColor(data.rarity)
    self.view.rarityLine.color = rarityColor
    self.view.count.text = UIUtils.getNumString(itemCount)
    if prob and prob > 0 then
        self.view.probTag.gameObject:SetActiveIfNecessary(true)
        self.view.probNum.text = string.format(Language.LUA_ITEM_PROBABILITY_PERCENT_FORMAT, prob)
    else
        self.view.probTag.gameObject:SetActiveIfNecessary(false)
    end
end

HL.Commit(ItemSimple)
return ItemSimple
