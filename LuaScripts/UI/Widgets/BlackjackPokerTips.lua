local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

BlackjackPokerTips = HL.Class('BlackjackPokerTips', UIWidgetBase)






BlackjackPokerTips._OnFirstTimeInit = HL.Override() << function(self)
end

BlackjackPokerTips.InitBlackjackPokerTips = HL.Method() << function(self)
    self:_FirstTimeInit()
    self.view.autoCloseArea:ChangeEnableCloseActionOnController(true)
    self.view.gameObject:SetActive(false)
end






BlackjackPokerTips.ShowPokerTips = HL.Method(HL.Any, HL.Any, HL.Boolean, HL.Opt(HL.Function, HL.Any)) << function(self, pokerCell, pokerInfo, hideRealRank, onClose, targetScreenRect)
    local view = self.view
    if view.gameObject.activeSelf then
        view.autoCloseArea:CloseSelf()
    end
    view.autoCloseArea:OpenSelf()

    
    
    view.rankImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_RANK, "icon_rank_" .. pokerInfo.rank)
    view.suitImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_SUIT, "icon_suit_" .. CS.Beyond.Gameplay.CardGameUtils.GetSuitNameByInt(pokerInfo.suit))
    local suitColor
    if pokerInfo.suit == CS.Beyond.Gameplay.PokerSuit.Hearts:ToInt() or
        pokerInfo.suit == CS.Beyond.Gameplay.PokerSuit.Diamonds:ToInt()
    then
        suitColor = UIUtils.getColorByString(Tables.cardGameConst.redSuitColor)
    else
        suitColor = UIUtils.getColorByString(Tables.cardGameConst.blackSuitColor)
    end
    view.rankImg.color = suitColor
    view.suitImg.color = suitColor
    
    if pokerInfo.rank == 1 then
        view.cardRankTypeState:SetState("Empty")
    elseif pokerInfo.rank <= 10 then
        view.cardRankTypeState:SetState("NumberCard")
    else
        view.cardRankTypeState:SetState("FaceCard")
    end
    view.cardRankTxt.text = (pokerInfo.rank == 1) and string.format(Language.LUA_COMMON_CURNUM_SLASH_MAXNUM, 1, 11) or pokerInfo.rank
    
    if pokerInfo.rank == 1 and not hideRealRank and pokerInfo.realRank then
        view.realRankNode.gameObject:SetActive(true)
        view.realRankTxt.text = pokerInfo.realRank
    else
        view.realRankNode.gameObject:SetActive(false)
    end
    
    local cardEnhanceNode = view.cardEnhanceNode
    if pokerInfo.enhance ~= GEnums.BlackJackCardGameCardEnhance.None:ToInt() then
        cardEnhanceNode.gameObject:SetActive(true)
        local _, enhanceCfg = Tables.cardGameCardEnhanceTable:TryGetValue(pokerInfo.enhance)
        if enhanceCfg then
            cardEnhanceNode.nameTxt.text = string.format(Language.LUA_CARD_GAME_BLACKJACK_CARD_ENHANCE_TITLE_PREFIX, enhanceCfg.name)
            cardEnhanceNode.descTxt:SetAndResolveTextStyle(enhanceCfg.desc)
            cardEnhanceNode.iconImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_CHANGE, enhanceCfg.icon)
        else
            logger.error("找不到卡牌强化效果对应表数据：" .. pokerInfo.enhance)
        end
    else
        cardEnhanceNode.gameObject:SetActive(false)
    end
    
    if pokerInfo.isInHandZone then
        view.cardState:SetState("InHandZone")
    elseif pokerInfo.isDelete then
        view.cardState:SetState("Delete")
    else
        view.cardState:SetState("None")
    end
    view.temporaryFlagNode.gameObject:SetActive(pokerInfo.isTemporary)

    
    local panelCtrl = self:GetUICtrl()
    if targetScreenRect then
        UIUtils.updateTipsPositionWithScreenRect(view.rectTransform, targetScreenRect, panelCtrl.view.rectTransform, panelCtrl.uiCamera, UIConst.UI_TIPS_POS_TYPE.DailyAbsentRightTop)
    else
        UIUtils.updateTipsPosition(view.rectTransform, pokerCell.transform, panelCtrl.view.rectTransform, panelCtrl.uiCamera, UIConst.UI_TIPS_POS_TYPE.DailyAbsentRightTop)
    end
    view.autoCloseArea.tmpSafeArea = pokerCell.transform
    view.autoCloseArea.onTriggerAutoClose:RemoveAllListeners()
    view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        if onClose then
            onClose()
        end
    end)
    
end


BlackjackPokerTips.HidePokerTips = HL.Method() << function(self)
    if not self.view.gameObject.activeSelf then
        return
    end
    self.view.autoCloseArea:TryCloseSelf()
end


HL.Commit(BlackjackPokerTips)
return BlackjackPokerTips
