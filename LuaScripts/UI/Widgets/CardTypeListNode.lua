local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local DISPLAY_STATE = {
    [CS.Beyond.GEnums.CardDisplayType.OneGroup] = "OneGroup",
    [CS.Beyond.GEnums.CardDisplayType.TwoGroup] = "TwoAddGroup",
    [CS.Beyond.GEnums.CardDisplayType.OneGroupContinue] = "OneAndMore",
}

local SUIT_VALUE = {
    pokerSuitHearts = CS.Beyond.Gameplay.PokerSuit.Hearts:GetHashCode(),
    pokerSuitSpades = CS.Beyond.Gameplay.PokerSuit.Spades:GetHashCode(),
    pokerSuitDiamonds = CS.Beyond.Gameplay.PokerSuit.Diamonds:GetHashCode(),
    pokerSuitClubs = CS.Beyond.Gameplay.PokerSuit.Clubs:GetHashCode(),
    pokerSuitLittleJoker = CS.Beyond.Gameplay.PokerSuit.LittleJoker:GetHashCode(),
    pokerSuitBigJoker = CS.Beyond.Gameplay.PokerSuit.BigJoker:GetHashCode(),
}

CardTypeListNode = HL.Class('CardTypeListNode', UIWidgetBase)

CardTypeListNode.m_openButton = HL.Field(CS.Beyond.UI.UIButton)
CardTypeListNode.m_patternCellCache = HL.Field(HL.Any)
CardTypeListNode.m_onActiveChanged = HL.Field(HL.Function)

CardTypeListNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self.m_patternCellCache = UIUtils.genCellCache(
            self.view.patternCellTemplate, nil, self.view.patternListNode)
    self.m_openButton.onClick:AddListener(function()
        self:Toggle()
    end)
    self.view.titleNode.closeBtn.onClick:AddListener(function()
        self:Hide()
    end)
    self.gameObject:SetActive(false)
end

CardTypeListNode.InitCardTypeListNode = HL.Method(CS.Beyond.UI.UIButton, HL.Function) << function(self, openButton, onActiveChanged)
    self.m_openButton = openButton
    self.m_onActiveChanged = onActiveChanged
    self:_FirstTimeInit()
end

CardTypeListNode.Toggle = HL.Method() << function(self)
    if self.gameObject.activeSelf then
        self:Hide()
    else
        self:Show()
    end
end

CardTypeListNode.Show = HL.Method() << function(self)
    if self.gameObject.activeSelf then
        return
    end
    self.gameObject:SetActive(true)
    self.m_onActiveChanged(true)
    self:_RefreshPatternList()
    
    if DeviceInfo.usingController then
        self.view.naviGroup:ManuallyFocus()
    end
    self.view.animationWrapper:PlayInAnimation()
end

CardTypeListNode.Hide = HL.Method() << function(self)
    if not self.gameObject.activeSelf then
        return
    end
    self.view.naviGroup:ManuallyStopFocus()
    self.m_onActiveChanged(false)
    self.view.animationWrapper:PlayOutAnimation(function()
        self.gameObject:SetActive(false)
    end)
end

CardTypeListNode._RefreshPatternList = HL.Method() << function(self)
    local patternConfigs = {}
    for _, config in pairs(Tables.cardGameDoudizhuCardTypeTable) do
        patternConfigs[#patternConfigs + 1] = config
    end
    table.sort(patternConfigs, function(a, b)
        return a.cardTypeId < b.cardTypeId
    end)
    self.m_patternCellCache:Refresh(#patternConfigs, function(cell, index)
        self:_RefreshPatternCell(cell, patternConfigs[index])
    end)
end

CardTypeListNode._RefreshPatternCell = HL.Method(HL.Table, HL.Any) << function(self, cell, config)
    cell.patternTitleTxt.text = config.cardTypeName
    cell.patternDetailsTxt.text = config.cardTypeDesc

    local stateName = DISPLAY_STATE[config.cardDisplayType]
    local cardLayout = cell.cardLayout
    cardLayout.stateController:SetState(stateName)

    if cell.temp_firstCardCache == nil then
        cell.temp_firstCardCache = UIUtils.genCellCache(cardLayout.cardCellFirstTemplate)
        cell.temp_secondCardCache = UIUtils.genCellCache(cardLayout.cardCellSecondTemplate)
    end
    local firstCards = self:_ParseCardCombine(config.cardCombine1, config.cardTypeId, "cardCombine1")
    local secondCards = self:_ParseCardCombine(config.cardCombine2, config.cardTypeId, "cardCombine2")
    self:_RefreshCardGroup(cell.temp_firstCardCache, firstCards)
    self:_RefreshCardGroup(cell.temp_secondCardCache, secondCards)
end

CardTypeListNode._ParseCardCombine = HL.Method(HL.Any, HL.String, HL.String)
        .Return(HL.Table) << function(self, combine, cardTypeId, fieldName)
    if combine.Count <= 0 then
        return {}
    end

    local rawCards = combine[0]
    if string.isEmpty(rawCards) then
        return {}
    end
    local cards = {}
    for _, cardKey in ipairs(string.split(rawCards, ";")) do
        
        local suitKey, rankText = string.match(cardKey, "^(pokerSuit%a+)_(%d+)$")
        local suit = suitKey and SUIT_VALUE[suitKey] or nil
        local rank = tonumber(rankText)
        cards[#cards + 1] = {
            suit = suit,
            rank = rank,
        }
    end
    return cards
end

CardTypeListNode._RefreshCardGroup = HL.Method(HL.Any, HL.Table) << function(self, cardCache, cards)
    cardCache:Refresh(#cards, function(card, index)
        local cardData = cards[index]
        card:InitCardGame2DPoker(index)
        card:SetCardStyle(CardGameUtils.GetCardStyleByEnhance(1))
        card:SetCardSuitRank(cardData.suit, cardData.rank)
        card:SetPokerContentVisible(true)
        card:SetFace(true)
    end)
end

HL.Commit(CardTypeListNode)
return CardTypeListNode
