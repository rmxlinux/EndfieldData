local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

CardChangeTipsNode = HL.Class('CardChangeTipsNode', UIWidgetBase)






CardChangeTipsNode._OnFirstTimeInit = HL.Override() << function(self)
    self:_InitUI()
end

CardChangeTipsNode._InitUI = HL.Method() << function(self)
end

CardChangeTipsNode.InitCardChangeTipsNode = HL.Method() << function(self)
    self:_FirstTimeInit()
end



CardChangeTipsNode.SetRankChange = HL.Method(HL.Number, HL.Number) << function(self, valueChangeType, value)
    local view = self.view
    if valueChangeType == CardGameUtils.ValueChangeType.Add then
        view.stateController:SetState("RankAdd")
        view.pointNumTxt.text = "+" .. value
    elseif valueChangeType == CardGameUtils.ValueChangeType.Sub then
        view.stateController:SetState("RankSub")
        view.pointNumTxt.text = "-" .. value
    else
        view.stateController:SetState("RankChangeTo")
        view.pointNumTxt.text = value
    end
end

CardChangeTipsNode.SetSuitChange = HL.Method(GEnums.BlackJackCardGameCardSuit) << function(self, suit)
    local view = self.view
    view.stateController:SetState("SuitChange")
    if suit == GEnums.BlackJackCardGameCardSuit.Hearts then
        view.suitChangeState:SetState("Hearts")
    elseif suit == GEnums.BlackJackCardGameCardSuit.Spades then
        view.suitChangeState:SetState("Spades")
    elseif suit == GEnums.BlackJackCardGameCardSuit.Clubs then
        view.suitChangeState:SetState("Clubs")
    elseif suit == GEnums.BlackJackCardGameCardSuit.Diamonds then
        view.suitChangeState:SetState("Diamonds")
    end
end






CardChangeTipsNode.SetEnhanceChange = HL.Method(HL.String) << function(self, enhanceState)
    local view = self.view
    view.stateController:SetState("EnhanceChange")
    view.enhanceChangeState:SetState(enhanceState)
end

CardChangeTipsNode.SetDelete = HL.Method() << function(self)
    self.view.stateController:SetState("Delete")
end

CardChangeTipsNode.RefreshCardChangeTips = HL.Method(HL.Table) << function(self, changeInfo)
    local changeType = changeInfo.cardChangeType
    if changeType == GEnums.BlackJackCardGameCardChangeType.Rank then
        self:SetRankChange(changeInfo.valueChangeType, changeInfo.rank)
    elseif changeType == GEnums.BlackJackCardGameCardChangeType.Suit then
        self:SetSuitChange(changeInfo.suit)
    elseif changeType == GEnums.BlackJackCardGameCardChangeType.Enhance then
        self:SetEnhanceChange(CardGameUtils.GetCardStyleByEnhance(changeInfo.enhance:ToInt()))
    else
        self:SetDelete()
    end
end


HL.Commit(CardChangeTipsNode)
return CardChangeTipsNode

