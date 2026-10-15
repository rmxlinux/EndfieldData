local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')





InnDishIcon = HL.Class('InnDishIcon', UIWidgetBase)


InnDishIcon._OnFirstTimeInit = HL.Override() << function(self)
    
end

InnDishIcon.InitInnDishIcon = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    local itemId = args.itemId
    local isRare = args.isRare == true

    if self.view.itemIcon then
        self.view.itemIcon:InitItemIcon(itemId)
    end

    self.view.stateController:SetState(isRare and "Rare" or "Normal")
    self.view.arrowImage.gameObject:SetActive(false)
end

InnDishIcon.SetArrowVisible = HL.Method(HL.Boolean) << function(self, visible)
    self.view.arrowImage.gameObject:SetActive(visible)
end

HL.Commit(InnDishIcon)
return InnDishIcon
