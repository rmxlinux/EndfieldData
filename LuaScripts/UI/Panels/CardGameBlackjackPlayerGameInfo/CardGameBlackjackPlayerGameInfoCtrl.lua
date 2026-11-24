local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackPlayerGameInfo
local PHASE_ID = PhaseId.CardGameBlackjackPlayerGameInfo
CardGameBlackjackPlayerGameInfoCtrl = HL.Class('CardGameBlackjackPlayerGameInfoCtrl', uiCtrl.UICtrl)







CardGameBlackjackPlayerGameInfoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED] = '_OnPlayRoomInfoChanged',
}



CardGameBlackjackPlayerGameInfoCtrl.m_arg = HL.Field(HL.Any)
CardGameBlackjackPlayerGameInfoCtrl.m_hpCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_relicCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_handZonePokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_spadesPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_diamondsPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_clubsPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackPlayerGameInfoCtrl.m_heartsPokerCellCache = HL.Field(HL.Forward("UIListCache"))

CardGameBlackjackPlayerGameInfoCtrl.m_isPokerTipsFollowNavi = HL.Field(HL.Boolean) << false





CardGameBlackjackPlayerGameInfoCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_InitUI()
    self:RefreshBasicGameInfo(arg)
    self:SetCanShowHandZonePage(arg.canShowHandZone)
    if arg.defaultPage then
        self:OpenPage(arg.defaultPage)
    end
    UIUtils.bindHyperlinkPopup(self, "BlackjackRelic", self.view.inputGroup.groupId)
    
    self:RefreshCountDownState()
    local system = LuaSystemManager.cardGameBlackjackSystem
    if system:IsCountDownRunning() then
        self:SetCountDown(system:GetCountDownRemain(), system:GetCountDownTotal())
    end
end

CardGameBlackjackPlayerGameInfoCtrl._InitUI = HL.Method() << function(self)
    local view = self.view
    view.pokerTips:InitBlackjackPokerTips()
    
    view.titleNode.closeBtn.onClick:AddListener(function()
        if not PhaseManager:PopPhase(PHASE_ID) then
            PhaseManager:ExitPhaseFast(PHASE_ID)
        end
    end)
    
    view.relicTabToggle.isOn = false
    view.handZoneTabToggle.isOn = false
    view.cardDeckTabToggle.isOn = false
    
    view.relicTabToggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:HidePokerTips()
            self:ShowRelicPage()
            self:RefreshRelicPage(self.m_arg)
        end
    end)
    view.handZoneTabToggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:HidePokerTips()
            self:ShowHandZonePage()
            self:RefreshHandZonePage(self.m_arg)
        end
    end)
    view.cardDeckTabToggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:HidePokerTips()
            self:ShowCardDeckPage()
            self:RefreshCardDeckPage(self.m_arg)
        end
    end)
    self:ShowCountDown(false)
    
    self.m_hpCellCache = UIUtils.genCellCache(self.view.gameInfoNode.hpCell)
    self.m_relicCellCache = UIUtils.genCellCache(self.view.relicPageNode.relicCell)
    self.m_handZonePokerCellCache = UIUtils.genCellCache(self.view.handZonePageNode.pokerCell)
    self.m_spadesPokerCellCache = UIUtils.genCellCache(self.view.cardDeckPageNode.spadesPokerCell)
    self.m_diamondsPokerCellCache = UIUtils.genCellCache(self.view.cardDeckPageNode.diamondsPokerCell)
    self.m_clubsPokerCellCache = UIUtils.genCellCache(self.view.cardDeckPageNode.clubsPokerCell)
    self.m_heartsPokerCellCache = UIUtils.genCellCache(self.view.cardDeckPageNode.heartsPokerCell)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end


CardGameBlackjackPlayerGameInfoCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = lume.clone(self.m_arg)
    local view = self.view
    local pageType = CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType
    if view.relicTabToggle.isOn then
        arg.defaultPage = pageType.Relic
    elseif view.handZoneTabToggle.isOn then
        arg.defaultPage = pageType.HandZone
    elseif view.cardDeckTabToggle.isOn then
        arg.defaultPage = pageType.CardDeck
    end
    return arg
end


CardGameBlackjackPlayerGameInfoCtrl.OpenPage = HL.Method(HL.Number) << function(self, pageType)
    local view = self.view
    if pageType == CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic then
        view.relicTabToggle.isOn = true
    elseif pageType == CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.HandZone then
        view.handZoneTabToggle.isOn = true
    else
        view.cardDeckTabToggle.isOn = true
    end
end



CardGameBlackjackPlayerGameInfoCtrl.RefreshBasicGameInfo = HL.Method(HL.Any) << function(self, gameInfo)
    self:RefreshPlayerBasicInfo(gameInfo.playerBasicInfo)
    self:RefreshGameInfoHp(gameInfo.curHp, gameInfo.maxHp)
    self:RefreshGameInfoMoneyNum(gameInfo.curMoney)
    self:RefreshGameInfoPointNum(gameInfo.curPoint, gameInfo.maxPoint)
    self:RefreshGameInfoExtraPointNum(gameInfo.extraPoint)
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshPlayerBasicInfo = HL.Method(HL.Any) << function(self, playerBasicInfo)
    local playerMsgNode = self.view.playerMsgNode
    playerMsgNode.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, playerBasicInfo.seatIndex))
    self.view.gameInfoNode.isSelfFlagIcon.gameObject:SetActive(playerBasicInfo.isSelf)
    self:_RefreshPlayerAIState(playerBasicInfo)
    CardGameUtils.InitCardGameMultiplayerPlayerCell(playerMsgNode.multiplayerPlayerCell, playerBasicInfo, "CardGameBlackjackPlayerGameInfo")
    
    self:_BindPlayerCellHidePokerTips()
end



CardGameBlackjackPlayerGameInfoCtrl._BindPlayerCellHidePokerTips = HL.Method() << function(self)
    local playerCellView = self.view.playerMsgNode.multiplayerPlayerCell.view
    local hidePokerTips = function()
        self:HidePokerTips()
    end
    playerCellView.button.onClick:AddListener(hidePokerTips)
    playerCellView.playerHead.view.playerHeadBtn.onClick:AddListener(hidePokerTips)
end

CardGameBlackjackPlayerGameInfoCtrl._RefreshPlayerAIState = HL.Method(HL.Any) << function(self, playerBasicInfo)
    local stateController = self.view.playerMsgNode.stateController
    if playerBasicInfo.isSelf then
        stateController:SetState("Self")
    elseif CardGameUtils.IsMemberShowAI(playerBasicInfo.memberId) then
        stateController:SetState("Ai")
    else
        stateController:SetState("None")
    end
end

CardGameBlackjackPlayerGameInfoCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    local playerBasicInfo = self.m_arg.playerBasicInfo
    if playerBasicInfo.memberId == unpack(arg) then
        self:_RefreshPlayerAIState(playerBasicInfo)
    end
end


CardGameBlackjackPlayerGameInfoCtrl._OnPlayRoomInfoChanged = HL.Method() << function(self)
    self:_RefreshPlayerAIState(self.m_arg.playerBasicInfo)
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshGameInfoHp = HL.Method(HL.Number, HL.Number) << function(self, curHp, maxHp)
    local gameInfoNode = self.view.gameInfoNode
    gameInfoNode.curHpNumTxt.text = curHp
    gameInfoNode.maxHpNumTxt.text = "/" .. maxHp
    self.m_hpCellCache:Refresh(maxHp, function(cell, index)
        
        cell.stateController:SetState(index > (maxHp - curHp) and "Normal" or "Empty")
    end)
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshGameInfoMoneyNum = HL.Method(HL.Number) << function(self, num)
    self.view.gameInfoNode.moneyNumTxt.text = num
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshGameInfoPointNum = HL.Method(HL.Number, HL.Number) << function(self, curNum, maxNum)
    local pointNode = self.view.gameInfoNode.pointNode
    pointNode.curPointNumTxt.text = curNum
    pointNode.maxPointNumTxt.text = maxNum
    
    if LuaSystemManager.cardGameBlackjackSystem:GetClientPhase() ~= CardGameBlackjackUtils.CLIENT_PHASE.Battle
            or self.m_arg.isGameOut then
        pointNode.stateController:SetState("NoPoint")
        pointNode.stateController:SetState("NotBust")
        return
    end
    pointNode.stateController:SetState(curNum <= 0 and "NoPoint" or "HasPoint")
    pointNode.stateController:SetState(curNum > maxNum and "IsBust" or "NotBust")
end


CardGameBlackjackPlayerGameInfoCtrl.RefreshGameInfoPointState = HL.Method() << function(self)
    self:RefreshGameInfoPointNum(self.m_arg.curPoint, self.m_arg.maxPoint)
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshGameInfoExtraPointNum = HL.Method(HL.Number) << function(self, num)
    local pointNode = self.view.gameInfoNode.pointNode
    pointNode.extraPointNumTxt.text = CardGameUtils.GetNumDeltaText(num)
    pointNode.stateController:SetState(num <= 0 and "HasExtraPoint" or "NoExtraPoint")
end



CardGameBlackjackPlayerGameInfoCtrl.ShowRelicPage = HL.Method() << function(self)
    self.view.mainState:SetState("RelicPage")
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshRelicPage = HL.Method(HL.Any) << function(self, arg)
    local relicPageNode = self.view.relicPageNode
    relicPageNode.relicNumTxt.text = string.format("%d/%d", arg.relicNum - arg.extraRelicNum, arg.maxRelicNum - arg.extraRelicNum)
    relicPageNode.curExtraRelicNumTxt.text = arg.extraRelicNum
    relicPageNode.extraRelicNumNode.gameObject:SetActive(arg.extraRelicNum > 0)
    self.m_relicCellCache:Refresh(arg.maxRelicNum, function(cell, index)
        if index > arg.relicNum then
            cell.stateController:SetState("Empty")
            return
        end
        cell.stateController:SetState("Normal")
        local relicInfo = arg.relicInfos[index]  
        cell.nameTxt.text = relicInfo.name
        cell.descTxt.text = relicInfo.desc
        cell.rarityColorGroup.color = UIUtils.getItemRarityColor(relicInfo.rarity)
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC, relicInfo.icon)
        cell.stateController:SetState(relicInfo.isExtraRelic and "IsExtra" or "NotExtra")
    end)
    self:_SetNaviToFirstRelic()
end




CardGameBlackjackPlayerGameInfoCtrl.SetCanShowHandZonePage = HL.Method(HL.Boolean) << function(self, canShow)
    self.view.handZoneTabToggle.gameObject:SetActive(canShow)
end

CardGameBlackjackPlayerGameInfoCtrl.ShowHandZonePage = HL.Method() << function(self)
    self.view.mainState:SetState("HanZonePage")
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshHandZonePage = HL.Method(HL.Any) << function(self, arg)
    local handZonePageNode = self.view.handZonePageNode
    local pokerCount = #arg.handZonePokerInfos
    handZonePageNode.pokerNumTxt.text = string.format(Language.LUA_COMMON_CURNUM_SLASH_MAXNUM, pokerCount, arg.maxHandZoneCount)
    self.m_handZonePokerCellCache:Refresh(pokerCount, function(cell, index)
        local pokerInfo = arg.handZonePokerInfos[index]
        cell.pokerNode:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
        
        cell.stateController:SetState("NotDelete")
        cell.stateController:SetState("NotHandZone")    
        cell.stateController:SetState(pokerInfo.isTemporary and "IsTemporary" or "NotTemporary")
        
        self:_BindPokerCell(cell, pokerInfo, false)
    end)
    self:_SetNaviToFirstPokerCell(self.m_handZonePokerCellCache)
end



CardGameBlackjackPlayerGameInfoCtrl.ShowCardDeckPage = HL.Method() << function(self)
    self.view.mainState:SetState("CardDeckPage")
end

CardGameBlackjackPlayerGameInfoCtrl.RefreshCardDeckPage = HL.Method(HL.Any) << function(self, arg)
    local cardDeckPageNode = self.view.cardDeckPageNode
    local deckPokerInfos = arg.deckPokerInfos
    
    cardDeckPageNode.totalCardNumTxt.text = deckPokerInfos.totalCardNum
    cardDeckPageNode.temporaryCardNumTxt.text = deckPokerInfos.temporaryCardNum
    cardDeckPageNode.temporaryCardNode.gameObject:SetActive(deckPokerInfos.temporaryCardNum > 0)
    
    for i = 1, 4 do
        local suitName = CS.Beyond.Gameplay.CardGameUtils.GetSuitNameByInt(i)
        local pokerInfos = deckPokerInfos[suitName .. "PokerInfos"]
        local pokerCount = #pokerInfos
        cardDeckPageNode[suitName .. "CardNumTxt"].text = pokerCount
        
        local cellCache = self[string.format("m_%sPokerCellCache", suitName)]
        local guideRankCounts = {}
        cellCache:Refresh(pokerCount, function(cell, index)
            local pokerInfo = pokerInfos[index]
            local rankIndex = (guideRankCounts[pokerInfo.rank] or 0) + 1
            guideRankCounts[pokerInfo.rank] = rankIndex
            cell.gameObject.name = string.format("GuidePoker_%d_%d", pokerInfo.rank, rankIndex)
            cell.pokerNode:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
            
            cell.stateController:SetState(pokerInfo.isDelete and "IsDelete" or "NotDelete")
            cell.stateController:SetState(pokerInfo.isInHandZone and "InHandZone" or "NotHandZone")    
            cell.stateController:SetState(pokerInfo.isTemporary and "IsTemporary" or "NotTemporary")
            
            self:_BindPokerCell(cell, pokerInfo, true)
        end)
    end
    self:_SetNaviToFirstCardDeckPoker()
end



CardGameBlackjackPlayerGameInfoCtrl._SetNaviToFirstRelic = HL.Method() << function(self)
    local navi
    if self.m_relicCellCache:GetCount() >= 1 then
        local cell = self.m_relicCellCache:GetItem(1)
        navi = cell and cell.naviDeco
    end
    self:_SetNaviToSelectable(navi)
end

CardGameBlackjackPlayerGameInfoCtrl._SetNaviToFirstPokerCell = HL.Method(HL.Opt(HL.Any)) << function(self, cellCache)
    local navi
    if cellCache ~= nil and cellCache:GetCount() >= 1 then
        local cell = cellCache:GetItem(1)
        navi = cell and cell.button
    end
    self:_SetNaviToSelectable(navi)
end


CardGameBlackjackPlayerGameInfoCtrl._SetNaviToFirstCardDeckPoker = HL.Method() << function(self)
    local suitOrder = { "spades", "diamonds", "clubs", "hearts" }
    for _, suitName in ipairs(suitOrder) do
        local cellCache = self[string.format("m_%sPokerCellCache", suitName)]
        if cellCache and cellCache:GetCount() >= 1 then
            self:_SetNaviToFirstPokerCell(cellCache)
            return
        end
    end
    self:ClearNaviTarget()
end

CardGameBlackjackPlayerGameInfoCtrl._SetNaviToSelectable = HL.Method(HL.Opt(HL.Any)) << function(self, selectable)
    if selectable ~= nil and not IsNull(selectable) then
        self:SetNaviTarget(selectable)
        return
    end
    self:ClearNaviTarget()
end



CardGameBlackjackPlayerGameInfoCtrl.ShowCountDown = HL.Method(HL.Boolean) << function(self, isShow)
    self.view.countDownNode.gameObject:SetActive(isShow)
end

CardGameBlackjackPlayerGameInfoCtrl.SetCountDown = HL.Method(HL.Number, HL.Number) << function(self, remainTime, maxTime)
    local countDownNode = self.view.countDownNode
    countDownNode.timeTxt.text = tostring(math.floor(remainTime))

    local progress = 0
    if maxTime > 0 then
        progress = math.min(math.max(remainTime / maxTime, 0), 1)
    end
    countDownNode.countDownBar.fillAmount = progress
    countDownNode.stateController:SetState(remainTime >= CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME and "White" or "Red")
end


CardGameBlackjackPlayerGameInfoCtrl.RefreshCountDownState = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local stateController = self.view.countDownNode.stateController
    if system:IsCountDownRunning() then
        self:ShowCountDown(true)
        stateController:SetState("Normal")
    elseif system:GetClientPhase() == CardGameBlackjackUtils.CLIENT_PHASE.Battle
            and system:GetBattleSubPhase() == CardGameBlackjackUtils.BATTLE_SUB_PHASE.ShowCard then
        self:ShowCountDown(true)
        stateController:SetState("ShowCard")
    else
        self:ShowCountDown(false)
    end
end




CardGameBlackjackPlayerGameInfoCtrl._BindPokerCell = HL.Method(HL.Any, HL.Any, HL.Boolean) << function(self, cell, pokerInfo, hideRealRank)
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:ShowPokerTips(cell, pokerInfo, hideRealRank)
    end)
    cell.button.onIsNaviTargetChanged = function(isTarget, isGroupChanged, isOnNaviTargetEnabledAgain)
        if isTarget and not isOnNaviTargetEnabledAgain and self.m_isPokerTipsFollowNavi then
            self:ShowPokerTips(cell, pokerInfo, hideRealRank)
        end
    end
end

CardGameBlackjackPlayerGameInfoCtrl.ShowPokerTips = HL.Method(HL.Any, HL.Any, HL.Boolean) << function(self, pokerCell, pokerInfo, hideRealRank)
    
    self.view.pokerTips:ShowPokerTips(pokerCell, pokerInfo, hideRealRank, function()
        self.m_isPokerTipsFollowNavi = false
        if not IsNull(pokerCell) then
            pokerCell.stateController:SetState("Unselect")
        end
    end)
    pokerCell.stateController:SetState("Select")
    self.m_isPokerTipsFollowNavi = true
end

CardGameBlackjackPlayerGameInfoCtrl.HidePokerTips = HL.Method() << function(self)
    self.view.pokerTips:HidePokerTips()
end


HL.Commit(CardGameBlackjackPlayerGameInfoCtrl)
