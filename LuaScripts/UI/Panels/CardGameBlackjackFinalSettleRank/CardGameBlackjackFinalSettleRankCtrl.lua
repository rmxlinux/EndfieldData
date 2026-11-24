local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackFinalSettleRank
local PHASE_ID = PhaseId.CardGameBlackjackFinalSettleRank

CardGameBlackjackFinalSettleRankCtrl = HL.Class('CardGameBlackjackFinalSettleRankCtrl', uiCtrl.UICtrl)







CardGameBlackjackFinalSettleRankCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CardGameBlackjackFinalSettleRankCtrl.m_arg = HL.Field(HL.Any)
CardGameBlackjackFinalSettleRankCtrl.m_playerRankingCellCache = HL.Field(HL.Forward("UIListCache"))




CardGameBlackjackFinalSettleRankCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_InitUI()
    self:_RefreshAllUI(arg)
    
    if not PhaseManager.isRecovering then
        self:_PlayPlayerRankingCellInAni()
    end
end

CardGameBlackjackFinalSettleRankCtrl._InitUI = HL.Method() << function(self)
    local view = self.view
    
    view.backBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
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
    
    self.m_playerRankingCellCache = UIUtils.genCellCache(view.playerRankingCell)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

CardGameBlackjackFinalSettleRankCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local cell = self.m_playerRankingCellCache:Get(1)
    if cell then
        self:SetNaviTarget(cell.naviDeco)
    end
end

CardGameBlackjackFinalSettleRankCtrl._RefreshAllUI = HL.Method(HL.Any) << function(self, arg)
    self.m_playerRankingCellCache:Refresh(#arg.settleInfos, function(cell, index)
        self:_RefreshPlayerRankingCell(cell, index)
    end)
end




CardGameBlackjackFinalSettleRankCtrl._PlayPlayerRankingCellInAni = HL.Method() << function(self)
    local cache = self.m_playerRankingCellCache
    local interval = self.view.config.CELL_IN_INTERVAL
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        cell.animationWrapper:SampleToInAnimationBegin()
        self:_StartTimer((i - 1) * interval, function()
            cell.animationWrapper:PlayInAnimation()
        end)
    end
end

CardGameBlackjackFinalSettleRankCtrl._RefreshPlayerRankingCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local playerSettleInfo = self.m_arg.settleInfos[index]
    
    
    cell.rankTxt.text = playerSettleInfo.rank
    cell.rankSuffixTxt.text = CardGameUtils.GetOrdinalSuffix(playerSettleInfo.rank)
    
    local relicSlotMaxLimit = playerSettleInfo.relicSlotMaxLimit
    local curUsedSlotNum = #playerSettleInfo.relicInfos
    if cell.temp_relicCellCache == nil then
        cell.temp_relicCellCache = UIUtils.genCellCache(cell.relicsCell)
    end
    cell.temp_relicCellCache:Refresh(relicSlotMaxLimit, function(relicCell, relicIndex)
        if relicIndex > curUsedSlotNum then
            relicCell.stateController:SetState("EmptySlot")
        else
            local relicInfo = playerSettleInfo.relicInfos[relicIndex]
            relicCell.relicImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC_SMALL, relicInfo.relicIcon)
            relicCell.stateController:SetState(relicInfo.isExtraRelic and "ExtraRelic" or "NormalRelic")
        end
        relicCell.stateController:SetState("HideInsertFlag")
    end)
    cell.relicRegionBtn.onClick:RemoveAllListeners()
    cell.relicRegionBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfo(playerSettleInfo.seatIndex,
                CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic)
    end)
    
    local cardCount = #playerSettleInfo.cardInfos
    cell.cardNumTxt.text = cardCount
    if cell.temp_pokerCellCache == nil then
        cell.temp_pokerCellCache = UIUtils.genCellCache(cell.pokerCell)
    end
    cell.temp_pokerCellCache:Refresh(cardCount, function(pokerCell, pokerCellIndex)
        local pokerInfo = playerSettleInfo.cardInfos[pokerCellIndex]
        pokerCell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
    end)
    cell.cardRegionBtn.onClick:RemoveAllListeners()
    cell.cardRegionBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfo(playerSettleInfo.seatIndex,
                CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck)
    end)
    
    cell.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, playerSettleInfo.seatIndex))
    
    cell.charImg:LoadSprite(UIConst.UI_SPRITE_GACHA_CHAR, playerSettleInfo.charId)
    
    local social = CardGameUtils.QueryPlayerSocialFlags(playerSettleInfo)
    if playerSettleInfo.isSelf then
        cell.cellState:SetState("SelfFlag")
    elseif social.isFriend then
        cell.cellState:SetState("FriendFlag")
    else
        cell.cellState:SetState("NoFlag")
    end
    
    cell.addFriendBtn.onClick:RemoveAllListeners()
    if social.canAddFriend then
        
        cell.cellState:SetState(social.isFriendRequestSent and "AppliedAddFriend" or "CanAddFriend")
        cell.addFriendBtn.onClick:AddListener(function()
            if LuaSystemManager.cardGameBlackjackSystem:RequestAddFriend(playerSettleInfo.seatIndex) then
                cell.cellState:SetState("AppliedAddFriend")
            end
        end)
    else
        cell.cellState:SetState("NoAddFriend")
    end
    CardGameUtils.InitCardGameMultiplayerPlayerCell(cell.multiplayerPlayerCell, playerSettleInfo, "CardGameBlackjackFinalSettleRank")
end

CardGameBlackjackFinalSettleRankCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_arg
end


HL.Commit(CardGameBlackjackFinalSettleRankCtrl)
