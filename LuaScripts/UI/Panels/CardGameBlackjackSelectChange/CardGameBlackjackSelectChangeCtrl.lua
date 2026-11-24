local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackSelectChange



CardGameBlackjackSelectChangeCtrl = HL.Class('CardGameBlackjackSelectChangeCtrl', uiCtrl.UICtrl)







CardGameBlackjackSelectChangeCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CardGameBlackjackSelectChangeCtrl.m_arg = HL.Field(HL.Table)
CardGameBlackjackSelectChangeCtrl.m_suitPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackSelectChangeCtrl.m_deckSuitCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackSelectChangeCtrl.m_rankPokerCellList = HL.Field(HL.Table)

CardGameBlackjackSelectChangeCtrl.m_curSelectSuit = HL.Field(GEnums.BlackJackCardGameCardSuit)




CardGameBlackjackSelectChangeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    
    local view = LuaSystemManager.cardGameBlackjackSystem:BuildSelectChangeView()
    if view == nil then
        view = arg or {}
    end
    self.m_arg = view
    local suit = self.m_arg.selectedSuit or 0
    self.m_curSelectSuit = GEnums.BlackJackCardGameCardSuit.__CastFrom(suit)
    if self.m_arg.chooseType ~= nil then
        self:RefreshAllUI(self.m_arg)
    end
end

CardGameBlackjackSelectChangeCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local cell = self.m_suitPokerCellCache:Get(1)
    if cell then
        self:SetNaviTarget(cell.naviDeco)
    end
end

CardGameBlackjackSelectChangeCtrl._InitUI = HL.Method() << function(self)
    self.m_suitPokerCellCache = UIUtils.genCellCache(self.view.selectSuitNode.pokerCell)
    self.m_deckSuitCellCache = UIUtils.genCellCache(self.view.selectDeckPokerNode.deckSuitCell)
    self.m_rankPokerCellList = {}
    for i = 1, 13 do
        self.m_rankPokerCellList[i] = self.view.selectRankNode["pokerCell" .. i]
    end
    
    self.m_curSelectSuit = GEnums.BlackJackCardGameCardSuit.None
end

CardGameBlackjackSelectChangeCtrl.RefreshAllUI = HL.Method(HL.Any) << function(self, arg)
    local chooseType = arg.chooseType
    self:SetSelectState(chooseType)
    if chooseType == GEnums.BlackJackCardGameChooseAttributeType.Suit then
        self:RefreshSelectSuitAllUI(arg)
    end
end





CardGameBlackjackSelectChangeCtrl.SetSelectState = HL.Method(GEnums.BlackJackCardGameChooseAttributeType) << function(self, type)
    if type == GEnums.BlackJackCardGameChooseAttributeType.Suit then
        self.view.mainState:SetState("SelectSuit")
    else
        
        
        
    end
end


CardGameBlackjackSelectChangeCtrl.RefreshTipsText = HL.Method(HL.String) << function(self, tipsText)
    self.view.tipsTxt.text = tipsText
end




local SUIT_DISPLAY_ORDER = {
    GEnums.BlackJackCardGameCardSuit.Spades,
    GEnums.BlackJackCardGameCardSuit.Hearts,
    GEnums.BlackJackCardGameCardSuit.Clubs,
    GEnums.BlackJackCardGameCardSuit.Diamonds,
}

CardGameBlackjackSelectChangeCtrl.RefreshSelectSuitAllUI = HL.Method(HL.Any) << function(self, arg)
    self.m_suitPokerCellCache:Refresh(#SUIT_DISPLAY_ORDER, function(cell, index)
        local suitType = SUIT_DISPLAY_ORDER[index]
        CardGameBlackjackUtils.SetPokerCellSelectState(cell, suitType == self.m_curSelectSuit, false)
        
        cell.poker:SetCardSuitRankStyle(suitType:ToInt(), 0, CardGameUtils.GetCardStyleByEnhance(1))
        cell.button.onClick:RemoveAllListeners()
        cell.button.onClick:AddListener(function()
            if suitType == self.m_curSelectSuit then
                
                self.m_curSelectSuit = GEnums.BlackJackCardGameCardSuit.None
                CardGameBlackjackUtils.SetPokerCellSelectState(cell, false, true)
                LuaSystemManager.cardGameBlackjackSystem:_OnChooseAttributeSelectSuit(self.m_curSelectSuit)
                return
            end
            
            for oldIndex, oldSuit in ipairs(SUIT_DISPLAY_ORDER) do
                if oldSuit == self.m_curSelectSuit then
                    local oldCell = self.m_suitPokerCellCache:Get(oldIndex)
                    if oldCell then
                        CardGameBlackjackUtils.SetPokerCellSelectState(oldCell, false, true)
                    end
                    break
                end
            end
            
            self.m_curSelectSuit = suitType
            CardGameBlackjackUtils.SetPokerCellSelectState(cell, true, true)
            LuaSystemManager.cardGameBlackjackSystem:_OnChooseAttributeSelectSuit(suitType)
        end)
    end)
    
    CardGameBlackjackUtils.SetCardDeckSuitCountTxt(self.view.cardDeckSuitCountTxt)
    
    local lastSuitName = CardGameBlackjackUtils.GetSuitDisplayName(
        LuaSystemManager.cardGameBlackjackSystem:GetLastAppliedChooseSuit())
    local hasLastSuit = not string.isEmpty(lastSuitName)
    self.view.tipsNode.gameObject:SetActive(hasLastSuit)
    if hasLastSuit then
        self:RefreshTipsText(string.format(Language.LUA_CARD_GAME_BLACKJACK_PRE_SELECT_CHANGE, lastSuitName))
    end
end












HL.Commit(CardGameBlackjackSelectChangeCtrl)
