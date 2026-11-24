local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackFinalSettle

CardGameBlackjackFinalSettleCtrl = HL.Class('CardGameBlackjackFinalSettleCtrl', uiCtrl.UICtrl)







CardGameBlackjackFinalSettleCtrl.s_messages = HL.StaticField(HL.Table) << {
}


CardGameBlackjackFinalSettleCtrl.m_arg = HL.Field(HL.Any)
CardGameBlackjackFinalSettleCtrl.m_relicCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackFinalSettleCtrl.m_pokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackFinalSettleCtrl.m_isReturnMatchRoom = HL.Field(HL.Boolean) << false

CardGameBlackjackFinalSettleCtrl.m_hasPlayedVictoryVoice = HL.Field(HL.Boolean) << false




CardGameBlackjackFinalSettleCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_InitUI()
    self:_RefreshAllUI(arg)
    
    if InputManagerInst.inChangingInputDevice then
        self.m_hasPlayedVictoryVoice = true
    else
        AudioManager.PostEvent("au_music_gambling_v1d7_blackjack_score")
    end
end

CardGameBlackjackFinalSettleCtrl.OnShow = HL.Override() << function(self)
    if self.m_hasPlayedVictoryVoice then
        return
    end
    local selfSettleInfo = self.m_arg and self.m_arg.selfSettleInfo
    
    if selfSettleInfo == nil or selfSettleInfo.rank ~= 1 then
        return
    end
    self.m_hasPlayedVictoryVoice = true
    self:_StartTimer(self.view.config.VOICE_DELAY, function()
        CardGameUtils.TriggerVoice(CardGameUtils.VoiceType.Victory, selfSettleInfo.charId)
    end)
end

CardGameBlackjackFinalSettleCtrl._InitUI = HL.Method() << function(self)
    local view = self.view
    
    view.exitBtn.onClick:AddListener(function()
        self:_OnClickExitBtn()
    end)
    local restoreShareState = function()
        local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
        if isOpen then
            ctrl.view.stateController:SetState("NoShare")
        end
    end
    view.stateController:SetState("NoShare")
    view.shareBtn.onClick:AddListener(function()
        view.stateController:SetState("Share")
        Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
            type = "Normal",
            onCaptureEnd = restoreShareState,
            onClose = restoreShareState,
        })
    end)
    view.rankingsBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenFinalSettleRank()
    end)
    view.returnLobbyBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:RequestLeavePlayRoom(false)
    end)
    
    view.gameInfoNode.relicRegionBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenSelfPlayerGameInfo(CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic)
    end)
    view.gameInfoNode.cardRegionBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenSelfPlayerGameInfo(CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck)
    end)
    
    self.m_relicCellCache = UIUtils.genCellCache(self.view.gameInfoNode.relicCell)
    self.m_pokerCellCache = UIUtils.genCellCache(self.view.gameInfoNode.pokerCell)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end


CardGameBlackjackFinalSettleCtrl._RefreshExitButtonState = HL.Method() << function(self)
    self.m_isReturnMatchRoom = false
    if not LuaSystemManager.cardGameSystem.isEnterFromMatchRoom then
        self.view.exitBtnState:SetState("Again")
    elseif GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        self.m_isReturnMatchRoom = true
        self.view.exitBtnState:SetState("ReturnMatchRoom")
    else
        self.view.exitBtnState:SetState("ReturnLobby")
    end
end


CardGameBlackjackFinalSettleCtrl._OnClickExitBtn = HL.Method() << function(self)
    local blackjackSystem = LuaSystemManager.cardGameBlackjackSystem
    if not LuaSystemManager.cardGameSystem.isEnterFromMatchRoom then
        blackjackSystem:RequestLeavePlayRoom(false, MultiplayerConst.EPlayRoomReturn.QuickMatch)
        return
    end
    if GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        blackjackSystem:RequestLeavePlayRoom(false, MultiplayerConst.EPlayRoomReturn.RoomMatch)
        return
    end
    if self.m_isReturnMatchRoom then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ROOM_CLOSED_TOAST)
    end
    blackjackSystem:RequestLeavePlayRoom(false, MultiplayerConst.EPlayRoomReturn.Main)
end

CardGameBlackjackFinalSettleCtrl._RefreshAllUI = HL.Method(HL.Any) << function(self, arg)
    local gameInfoNode = self.view.gameInfoNode
    local selfSettleInfo = arg.selfSettleInfo  
    
    self:_RefreshExitButtonState()
    
    self.view.rankingsBtn.gameObject:SetActive(not arg.isEarlyLeave)
    
    gameInfoNode.rankTxt.text = selfSettleInfo.rank
    gameInfoNode.rankSuffixTxt.text = CardGameUtils.GetOrdinalSuffix(selfSettleInfo.rank)
    
    gameInfoNode.highestScoreTxt.text = selfSettleInfo.maxRoundScore
    
    local relicSlotMaxLimit = selfSettleInfo.relicSlotMaxLimit
    local curUsedSlotNum = #selfSettleInfo.relicInfos
    self.m_relicCellCache:Refresh(relicSlotMaxLimit, function(relicCell, relicIndex)
        if relicIndex > curUsedSlotNum then
            relicCell.stateController:SetState("EmptySlot")
        else
            local relicInfo = selfSettleInfo.relicInfos[relicIndex]
            relicCell.relicImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC_SMALL, relicInfo.relicIcon)
            relicCell.stateController:SetState(relicInfo.isExtraRelic and "ExtraRelic" or "NormalRelic")
        end
        relicCell.stateController:SetState("HideInsertFlag")
    end)
    
    local cardCount = #selfSettleInfo.cardInfos
    gameInfoNode.cardNumTxt.text = cardCount
    self.m_pokerCellCache:Refresh(cardCount, function(pokerCell, pokerCellIndex)
        local pokerInfo = selfSettleInfo.cardInfos[pokerCellIndex]
        pokerCell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
    end)
    
    self.view.charImg:LoadSprite(UIConst.UI_SPRITE_CHAR_PORTRAIT, selfSettleInfo.charId)
    gameInfoNode.charHeadIcon.headIconImg:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. selfSettleInfo.charId)
    CardGameUtils.InitCardGameMultiplayerPlayerCell(gameInfoNode.playerInfoNode, selfSettleInfo, "CardGameBlackjackFinalSettle")
end

CardGameBlackjackFinalSettleCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_arg
end


HL.Commit(CardGameBlackjackFinalSettleCtrl)
