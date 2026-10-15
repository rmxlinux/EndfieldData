local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')








InnTrayCell = HL.Class('InnTrayCell', UIWidgetBase)

InnTrayCell.hoverBindingGroupId = HL.Field(HL.Number) << -1


InnTrayCell._OnFirstTimeInit = HL.Override() << function(self)

end

InnTrayCell.InitInnTrayCell = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    local food = args.food
    local isLocked = args.isLocked == true
    local hasFood = food ~= nil and not string.isEmpty(food.itemId)

    local state
    if isLocked then
        state = "Locked"
    elseif not hasFood then
        state = "Empty"
    elseif args.isDishBlack then
        state = "DishesBlack"
    else
        state = "Normal"
    end
    self.view.stateController:SetState(state)

    if hasFood and self.view.itemIcon then
        self.view.itemIcon:InitItemIcon(food.itemId)
    end

    if self.view.rareTag then
        self.view.rareTag.gameObject:SetActive(hasFood and food.isRare == true)
    end

    self:SetPutBackNodeActive(false)
    self:SetHoldNodeActive(false)
    self:SetInTagActive(false)
    self:SetOutTagActive(false)

    if self.view.trayBtn then
        self.view.trayBtn.onClick:RemoveAllListeners()
        if args.onClick then
            self.view.trayBtn.onClick:AddListener(function()
                args.onClick(food)
            end)
        end
        if args.actionId then
            self.view.trayBtn.onClick:ChangeBindingPlayerAction(args.actionId)
        else
            self.view.trayBtn.onClick:StopUseBinding()
        end
    end
end

InnTrayCell.SetPutBackNodeActive = HL.Method(HL.Boolean) << function(self, visible)
    if self.view.putBackNode then
        self.view.putBackNode.gameObject:SetActive(visible)
    end
end

InnTrayCell.SetHoldNodeActive = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, visible, playIn)
    if not self.view.holdNode then
        return
    end
    local wasActive = self.view.holdNode.gameObject.activeSelf
    self.view.holdNode.gameObject:SetActive(visible)
    if visible and playIn and not wasActive and self.view.holdNodeAnimationWrapper then
        self.view.holdNodeAnimationWrapper:PlayInAnimation()
    end
end

InnTrayCell.SetInTagActive = HL.Method(HL.Boolean) << function(self, visible)
    if self.view.inTag then
        self.view.inTag.gameObject:SetActive(visible)
    end
end

InnTrayCell.SetOutTagActive = HL.Method(HL.Boolean) << function(self, visible)
    if self.view.outTag then
        self.view.outTag.gameObject:SetActive(visible)
    end
end

HL.Commit(InnTrayCell)
return InnTrayCell

