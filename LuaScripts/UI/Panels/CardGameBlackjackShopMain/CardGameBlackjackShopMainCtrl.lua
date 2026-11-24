local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')
local PANEL_ID = PanelId.CardGameBlackjackShopMain

CardGameBlackjackShopMainCtrl = HL.Class('CardGameBlackjackShopMainCtrl', uiCtrl.UICtrl)







CardGameBlackjackShopMainCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



CardGameBlackjackShopMainCtrl.m_hpCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopMainCtrl.m_relicCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopMainCtrl.m_cardChangePokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopMainCtrl.m_cardReplacePrePokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopMainCtrl.m_cardReplaceNowPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopMainCtrl.m_cardAniUpdateKey = HL.Field(HL.Number) << -1
CardGameBlackjackShopMainCtrl.m_cardAniQueue = HL.Field(CardGameAnimQueue)
CardGameBlackjackShopMainCtrl.m_uiAniQueue = HL.Field(CardGameAnimQueue)

CardGameBlackjackShopMainCtrl.m_isChooseMode = HL.Field(HL.Boolean) << false

CardGameBlackjackShopMainCtrl.m_chooseModeKey = HL.Field(HL.String) << ""

CardGameBlackjackShopMainCtrl.m_relicUsedSlotNum = HL.Field(HL.Number) << 0
CardGameBlackjackShopMainCtrl.m_relicPreviewGainIndex = HL.Field(HL.Number) << 0
CardGameBlackjackShopMainCtrl.m_relicPreviewInsertIndex = HL.Field(HL.Number) << 0

CardGameBlackjackShopMainCtrl.m_remainMoney = HL.Field(HL.Number) << 0
CardGameBlackjackShopMainCtrl.m_refreshCost = HL.Field(HL.Number) << 0

CardGameBlackjackShopMainCtrl.m_refreshClickProtectEndTime = HL.Field(HL.Number) << 0





CardGameBlackjackShopMainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self:_RefreshAllUI()
    
    if LuaSystemManager.cardGameBlackjackSystem:GetClientPhase() == CardGameBlackjackUtils.CLIENT_PHASE.Shop
            and not InputManagerInst.inChangingInputDevice then
        AudioManager.PostEvent("au_music_gambling_v1d7_blackjack_store")
    end
end

CardGameBlackjackShopMainCtrl._InitUI = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    
    
    self.view.exitShopBtn.onClick:AddListener(function()
        system:OnShopMainExitShop()
    end)
    
    self.view.titleNode.helpBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, CardGameBlackjackUtils.INTRO_KEY)
    end)
    
    self.view.skipBtn.onClick:AddListener(function()
        system:_OnShopMainSkip()
    end)
    
    self.view.refreshBtnNode.button.onClick:AddListener(function()
        self:_OnClickRefreshBtn()
    end)
    
    self.view.btnOpNode.confirmBtn.onClick:AddListener(function()
        if self.m_isChooseMode then
            system:OnShopMainChooseConfirm()
        elseif DeviceInfo.usingController then
            system:OnShopMainExitShop()
        else
            system:OnShopMainBuySelected()
        end
    end)
    self.view.btnOpNode.selectBtn.onClick:AddListener(function()
        system:_OnShopMainConfirm()
    end)
    self.view.titleNode.exitBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:RequestLeavePlayRoom(true)
    end)
    
    self.view.relicListNode.button.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenSelfPlayerGameInfo(CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic)
    end)
    self.view.relicBtn2.onClick:AddListener(function()
        
        LuaSystemManager.cardGameBlackjackSystem:OpenSelfPlayerGameInfo(CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic)
    end)
    self.view.deckNode.button.onClick:AddListener(function()
        LuaSystemManager.cardGameBlackjackSystem:OpenSelfPlayerGameInfo(CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck)
    end)
    

    
    self.m_hpCellCache = UIUtils.genCellCache(self.view.hpNode.hpCell)
    self.m_relicCellCache = UIUtils.genCellCache(self.view.relicListNode.relicsCell)
    self.m_cardChangePokerCellCache = UIUtils.genCellCache(self.view.deckNode.cardChangeAniNode.pokerCell)
    self.m_cardReplacePrePokerCellCache = UIUtils.genCellCache(self.view.deckNode.cardReplaceAniNode.prePokerCell)
    self.m_cardReplaceNowPokerCellCache = UIUtils.genCellCache(self.view.deckNode.cardReplaceAniNode.nowPokerCell)
    

    
    self:ExitChooseMode()
    self:SetCountDown(1, 1)
    self.view.effectReportNode:InitCardGameEffectReport()
    self.view.deckNode.cardChangeAniNode.cardChangeTipsNode:InitCardChangeTipsNode()
    self.m_cardAniQueue = CardGameAnimQueue()
    self.m_uiAniQueue = CardGameAnimQueue()
    
end

CardGameBlackjackShopMainCtrl.OnClose = HL.Override() << function(self)
    self:StopUiValueChangeAni()
    self:StopCardChangeAni()
    self:StopCardReplaceAni()
    Notify(MessageConst.HIDE_ITEM_TIPS)
end

CardGameBlackjackShopMainCtrl._RefreshAllUI = HL.Method() << function(self)
    local info = LuaSystemManager.cardGameBlackjackSystem:BuildShopMainView()
    if info == nil then
        return
    end
    self:SetShopModeUiState(false)
    self:SetShopState(info.isInitialRelic)
    self:RefreshBtnOpNode()
    self:RefreshRoundNum(info.roundNum)
    self:RefreshRemainMoneyNum(info.gold)
    self:RefreshRefreshNeedMoneyNum(info.refreshCost)
    self:RefreshDeckCardNum(info.deckCardNum)
    self:RefreshMaxPointNum(info.outScoreCap)
    self:RefreshExtraPointNum(info.outAdditionalPoints)
    self:RefreshHpNum(info.hp, info.maxHp)
    self:RefreshRelicList(info.relicInfos, info.maxRelicSlotNum, info.extraRelicNum)
    self:RefreshRelicPreview(info.relicPreviewType)
    if info.countDownRemain ~= nil and info.countDownTotal ~= nil then
        self:SetCountDown(info.countDownRemain, info.countDownTotal)
    end
end



CardGameBlackjackShopMainCtrl.RefreshRoundNum = HL.Method(HL.Number) << function(self, roundNum)
    self.view.titleNode.roundInfoTxt.text = string.format(Language.LUA_CARD_GAME_BLACKJACK_HUD_TITLE_ROUND, roundNum)
end


CardGameBlackjackShopMainCtrl.SetCountDown = HL.Method(HL.Number, HL.Number) << function(self, remainTime, maxTime)
    local countDownNode = self.view.countDownNode
    countDownNode.timeTxt.text = tostring(math.floor(remainTime))

    local progress = 0
    if maxTime > 0 then
        progress = math.min(math.max(remainTime / maxTime, 0), 1)
    end
    countDownNode.countDownBar.fillAmount = progress
    countDownNode.stateController:SetState(remainTime >= CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME and "White" or "Red")
end


CardGameBlackjackShopMainCtrl.SetShopState = HL.Method(HL.Boolean) << function(self, isChooseInitRelic)
    self.view.stateController:SetState(isChooseInitRelic and "ChooseInitRelic" or "Shop")
end

CardGameBlackjackShopMainCtrl.RefreshRemainMoneyNum = HL.Method(HL.Number) << function(self, num)
    CardGameBlackjackUtils.InitGoldMoneyCell(self.view.titleNode.moneyCell, num)
    self.m_remainMoney = num
    self:_RefreshRefreshBtnMoneyState()
end

CardGameBlackjackShopMainCtrl.RefreshRefreshNeedMoneyNum = HL.Method(HL.Number) << function(self, num)
    self.view.refreshBtnNode.refreshNeedMoneyNumTxt.text = num
    self.m_refreshCost = num
    self:_RefreshRefreshBtnMoneyState()
end

CardGameBlackjackShopMainCtrl._RefreshRefreshBtnMoneyState = HL.Method() << function(self)
    local isEnough = self.m_remainMoney >= self.m_refreshCost
    self.view.refreshBtnNode.stateController:SetState(isEnough and "moneyEnough" or "moneyNotEnough")
end

CardGameBlackjackShopMainCtrl._OnClickRefreshBtn = HL.Method() << function(self)
    local now = Time.unscaledTime
    if now < self.m_refreshClickProtectEndTime then
        return
    end
    self.m_refreshClickProtectEndTime = now + self.view.config.REFRESH_CLICK_PROTECT_DURATION
    LuaSystemManager.cardGameBlackjackSystem:_OnShopRefreshShop()
end

CardGameBlackjackShopMainCtrl.RefreshMaxPointNum = HL.Method(HL.Number) << function(self, num)
    self.view.maxPointNode.numTxt.text = num
end

CardGameBlackjackShopMainCtrl.RefreshExtraPointNum = HL.Method(HL.Number) << function(self, num)
    self.view.extraPointNode.numTxt.text = num
end

CardGameBlackjackShopMainCtrl.RefreshHpNum = HL.Method(HL.Number, HL.Number) << function(self, curHp, maxHp)
    self.view.hpNode.curHpTxt.text = curHp
    self.view.hpNode.maxHpTxt.text = maxHp
    self.m_hpCellCache:Refresh(maxHp, function(cell, index)
        
        cell.stateController:SetState(index > (maxHp - curHp) and "Normal" or "Empty")
    end)
end


CardGameBlackjackShopMainCtrl.PlayHpChangeAni = HL.Method(HL.Number, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, beforeHp, afterHp, maxHp, onPlayEnd)
    self:RefreshHpNum(afterHp, maxHp)
    beforeHp = lume.clamp(beforeHp, 0, maxHp)
    afterHp = lume.clamp(afterHp, 0, maxHp)
    if afterHp >= beforeHp then
        CardGameBlackjackUtils.PlayHpCellsChangeAni(self.m_hpCellCache, maxHp - afterHp + 1, maxHp - beforeHp, true, onPlayEnd)
    else
        CardGameBlackjackUtils.PlayHpCellsChangeAni(self.m_hpCellCache, maxHp - beforeHp + 1, maxHp - afterHp, false, onPlayEnd)
    end
end


CardGameBlackjackShopMainCtrl.RefreshRelicList = HL.Method(HL.Any, HL.Number, HL.Number) << function(self, relicInfos, maxSlotNum, extraRelicNum)
    local curUsedSlotNum = #relicInfos
    local relicListNode = self.view.relicListNode
    relicListNode.curNumTxt.text = curUsedSlotNum - extraRelicNum
    relicListNode.maxNumTxt.text = maxSlotNum - extraRelicNum
    relicListNode.extraRelicNumTxt.text = extraRelicNum
    relicListNode.extraRelicNumNode.gameObject:SetActive(extraRelicNum > 0)
    
    self.m_relicUsedSlotNum = curUsedSlotNum
    self.m_relicPreviewGainIndex = 0
    self.m_relicPreviewInsertIndex = 0
    self.m_relicCellCache:Refresh(maxSlotNum, function(cell, index)
        if index > curUsedSlotNum then
            self:SetRelicCellState(cell, "EmptySlot")
        else
            local relicInfo = relicInfos[index]
            cell.relicImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC_SMALL, relicInfo.relicIcon)
            self:SetRelicCellState(cell, relicInfo.isExtraRelic and "ExtraRelic" or "NormalRelic")
        end
        self:SetRelicCellState(cell, "HideInsertFlag")
    end)
end



CardGameBlackjackShopMainCtrl.RefreshRelicPreview = HL.Method(HL.Opt(HL.String)) << function(self, previewType)
    local cellCount = self.m_relicCellCache:GetCount()
    local gainIndex = 0
    local insertIndex = 0
    if previewType == CardGameBlackjackUtils.RelicPreviewType.GainSlot then
        gainIndex = self.m_relicUsedSlotNum + 1
    elseif previewType == CardGameBlackjackUtils.RelicPreviewType.Insert then
        
        insertIndex = math.max(self.m_relicUsedSlotNum, 1)
    end
    if gainIndex > cellCount then
        gainIndex = 0
    end
    if insertIndex > cellCount then
        insertIndex = 0
    end

    local oldGainIndex = self.m_relicPreviewGainIndex
    if gainIndex ~= oldGainIndex then
        
        local oldCell = oldGainIndex > 0 and self.m_relicCellCache:Get(oldGainIndex) or nil
        if oldCell ~= nil then
            self:SetRelicCellState(oldCell, "EmptySlot")
        end
        local newCell = gainIndex > 0 and self.m_relicCellCache:Get(gainIndex) or nil
        if newCell ~= nil then
            self:SetRelicCellState(newCell, "GainRelicSlot")
        end
        self.m_relicPreviewGainIndex = gainIndex
    end

    local oldInsertIndex = self.m_relicPreviewInsertIndex
    if insertIndex ~= oldInsertIndex then
        local oldCell = oldInsertIndex > 0 and self.m_relicCellCache:Get(oldInsertIndex) or nil
        if oldCell ~= nil then
            self:SetRelicCellState(oldCell, "HideInsertFlag")
        end
        local newCell = insertIndex > 0 and self.m_relicCellCache:Get(insertIndex) or nil
        if newCell ~= nil then
            self:SetRelicCellState(newCell, "ShowInsertFlag")
        end
        self.m_relicPreviewInsertIndex = insertIndex
    end
end









CardGameBlackjackShopMainCtrl.SetRelicCellState = HL.Method(HL.Any, HL.String) << function(self, cell, state)
    cell.stateController:SetState(state)
end


CardGameBlackjackShopMainCtrl.RefreshDeckCardNum = HL.Method(HL.Number) << function(self, num)
    self.view.deckNode.deckCardNumTxt.text = num
end





















CardGameBlackjackShopMainCtrl.SetBtnOpNodeState = HL.Method(HL.String) << function(self, state)
    self.view.btnOpNode.stateController:SetState(state)
end


CardGameBlackjackShopMainCtrl.RefreshBtnOpNodeCurSelectNum = HL.Method(HL.Number) << function(self, num)
    self.view.btnOpNode.curSelectNumTxt.text = num
end


CardGameBlackjackShopMainCtrl.RefreshBtnOpNodeMaxSelectNum = HL.Method(HL.Number) << function(self, num)
    self.view.btnOpNode.maxSelectNumTxt.text = num
end

CardGameBlackjackShopMainCtrl.SetShopModeUiState = HL.Method(HL.Boolean) << function(self, isChooseMode)
    if isChooseMode then
        self.view.stateController:SetState("ChooseMode")
    else
        self.view.stateController:SetState(DeviceInfo.usingController and "BuyGoodsGamepadMode" or "BuyGoodsMode")
    end
end





CardGameBlackjackShopMainCtrl._PlayUiChangeValueTips = HL.Method(HL.Any, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, tipsNode, valueChangeType, value, onPlayEnd)
    local queue = self.m_uiAniQueue
    queue:Enqueue(function(finish)
        CardGameBlackjackUtils.PlayChangeValueTips(self, tipsNode, valueChangeType, value, finish)
    end)
    queue:EnqueueFinallyAction(function()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end

CardGameBlackjackShopMainCtrl.PlayChangeMaxPointNum = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeType, value, onPlayEnd)
    self:_PlayUiChangeValueTips(self.view.maxPointNode.valueChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameBlackjackShopMainCtrl.PlayChangeExtraPointNum = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeType, value, onPlayEnd)
    self:_PlayUiChangeValueTips(self.view.extraPointNode.valueChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameBlackjackShopMainCtrl.PlayChangeRemainMoneyNum = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeType, value, onPlayEnd)
    self:_PlayUiChangeValueTips(self.view.titleNode.moneyCell.view.moneyChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameBlackjackShopMainCtrl.PlayChangeHpNum = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeType, value, onPlayEnd)
    self:_PlayUiChangeValueTips(self.view.hpNode.hpChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameBlackjackShopMainCtrl.StopUiValueChangeAni = HL.Method() << function(self)
    if self.m_uiAniQueue then
        self.m_uiAniQueue:Clear()
    end
end




CardGameBlackjackShopMainCtrl.PlayCardChangeAni = HL.Method(HL.Table, HL.Table, HL.Table, HL.Opt(HL.Function))
    << function(self, changeInfo, preCardInfos, nowCardInfos, onPlayEnd)
    local cardCount = #preCardInfos
    if cardCount <= 0 then
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end

    local queue = self.m_cardAniQueue
    queue:Enqueue(function(finish)
        local deckNode = self.view.deckNode
        local aniNode = deckNode.cardChangeAniNode
        local iconDeckRect = deckNode.iconDeck.rectTransform
        aniNode.gameObject:SetActive(true)
        
        self.m_cardChangePokerCellCache:Refresh(cardCount, function(cell, index)
            local pokerInfo = preCardInfos[index]
            cell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
            cell:SetPokerMoveRootPos(iconDeckRect, Vector2.zero)
            cell:SetFace(false)
        end)
        aniNode.cardChangeTipsNode.gameObject:SetActive(true)
        aniNode.cardChangeTipsNode:RefreshCardChangeTips(changeInfo)
        finish()
    end)
    
    queue:Enqueue(function(finish)
        
        AudioAdapter.PostEvent("Au_UI_Event_CardSpecialChange")
        self:_PlayCardChangeFlyToLayout(finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlipToNow(nowCardInfos, finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyBackToDeck(finish)
    end)
    
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardChangeAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end



CardGameBlackjackShopMainCtrl._PlayCardChangeFlyCards = HL.Method(HL.Any, HL.Boolean, HL.Opt(HL.Function))
    << function(self, cache, toDeck, onPlayEnd)
    local cardCount = cache:GetCount()
    if cardCount <= 0 then
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    local remain = cardCount
    local function onOneEnd()
        remain = remain - 1
        if remain <= 0 and onPlayEnd then
            onPlayEnd()
        end
    end
    local iconDeckRect = self.view.deckNode.iconDeck.rectTransform
    for index = 1, cardCount do
        local cell = cache:Get(index)
        cell:PlayPokerFaceFlipAni(toDeck)
        if toDeck then
            cell:PlayMovePokerRootTo(iconDeckRect, Vector2.zero, onOneEnd)
        else
            cell:PlayMovePokerRootTo(cell.view.rectTransform, Vector2.zero, onOneEnd)
        end
    end
end

CardGameBlackjackShopMainCtrl._PlayCardChangeFlyToLayout = HL.Method(HL.Function) << function(self, onPlayEnd)
    self:_PlayCardChangeFlyCards(self.m_cardChangePokerCellCache, false, onPlayEnd)
end

CardGameBlackjackShopMainCtrl._PlayCardChangeFlyBackToDeck = HL.Method(HL.Function) << function(self, onPlayEnd)
    self:_PlayCardChangeFlyCards(self.m_cardChangePokerCellCache, true, onPlayEnd)
end


CardGameBlackjackShopMainCtrl._PlayCardChangeFlipToNow = HL.Method(HL.Table, HL.Function) << function(self, nowCardInfos, onPlayEnd)
    local cache = self.m_cardChangePokerCellCache
    local cardCount = cache:GetCount()
    if cardCount <= 0 then
        onPlayEnd()
        return
    end
    local remain = cardCount
    local function onOneEnd()
        remain = remain - 1
        if remain <= 0 then
            onPlayEnd()
        end
    end
    for index = 1, cardCount do
        local cell = cache:Get(index)
        local pokerInfo = nowCardInfos[index]
        if pokerInfo then
            cell:PlayPokerChangeFlipAni(pokerInfo.suit, pokerInfo.rank, pokerInfo.style, onOneEnd)
        else
            onOneEnd()
        end
    end
end


CardGameBlackjackShopMainCtrl._WaitCardChangeAniSee = HL.Method(HL.Function) << function(self, nextFn)
    local elapsed = 0
    self.m_cardAniUpdateKey = self:_StartUpdate(function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < CardGameBlackjackUtils.CARD_ANI_SEE_WAIT_TIME then
            return
        end
        self.m_cardAniUpdateKey = self:_RemoveUpdate(self.m_cardAniUpdateKey)
        nextFn()
    end)
end


CardGameBlackjackShopMainCtrl._ResetPokerCellPos = HL.Method(HL.Any) << function(self, cache)
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        cell:SetPokerMoveRootPos(cell.view.rectTransform, Vector2.zero)
    end
end


CardGameBlackjackShopMainCtrl._InvokeCardChangeAniPlayEnd = HL.Method() << function(self)
    local cache = self.m_cardChangePokerCellCache
    self.view.deckNode.cardChangeAniNode.gameObject:SetActive(false)
    self:_ResetPokerCellPos(cache)
    cache:Refresh(0)
end

CardGameBlackjackShopMainCtrl.StopCardChangeAni = HL.Method() << function(self)
    
    self.m_cardAniUpdateKey = self:_RemoveUpdate(self.m_cardAniUpdateKey)
    local cache = self.m_cardChangePokerCellCache
    for i = 1, cache:GetCount() do
        cache:Get(i):ClearAni()
    end
    self.view.deckNode.cardChangeAniNode.gameObject:SetActive(false)
    self:_ResetPokerCellPos(cache)
    cache:Refresh(0)
    if self.m_cardAniQueue then
        self.m_cardAniQueue:Clear()
    end
end




CardGameBlackjackShopMainCtrl.PlayCardReplaceAni = HL.Method(HL.Table, HL.Table, HL.Opt(HL.Function))
    << function(self, preCardInfos, nowCardInfos, onPlayEnd)
    local preCount = #preCardInfos
    local nowCount = #nowCardInfos
    if preCount + nowCount <= 0 then
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end

    local queue = self.m_cardAniQueue
    queue:Enqueue(function(finish)
        local deckNode = self.view.deckNode
        local aniNode = deckNode.cardReplaceAniNode
        local iconDeckRect = deckNode.iconDeck.rectTransform
        aniNode.gameObject:SetActive(true)
        aniNode.arrow.gameObject:SetActive(false)
        aniNode.nowCardList.gameObject:SetActive(false)
        aniNode.preCardList.gameObject:SetActive(true)
        
        self.m_cardReplacePrePokerCellCache:Refresh(preCount, function(cell, index)
            local pokerInfo = preCardInfos[index]
            cell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
            cell:SetPokerMoveRootPos(iconDeckRect, Vector2.zero)
            cell:SetFace(false)
        end)
        
        self.m_cardReplaceNowPokerCellCache:Refresh(nowCount, function(cell, index)
            local pokerInfo = nowCardInfos[index]
            cell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
            cell:SetPokerMoveRootPos(cell.view.rectTransform, Vector2.zero)
            cell:SetFace(true)
        end)
        finish()
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyCards(self.m_cardReplacePrePokerCellCache, false, finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        local aniNode = self.view.deckNode.cardReplaceAniNode
        aniNode.arrow.gameObject:SetActive(true)
        aniNode.nowCardList.gameObject:SetActive(true)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        local aniNode = self.view.deckNode.cardReplaceAniNode
        aniNode.arrow.gameObject:SetActive(false)
        aniNode.preCardList.gameObject:SetActive(false)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyCards(self.m_cardReplaceNowPokerCellCache, true, finish)
    end)
    
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardReplaceAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end


CardGameBlackjackShopMainCtrl._InvokeCardReplaceAniPlayEnd = HL.Method() << function(self)
    local preCache = self.m_cardReplacePrePokerCellCache
    local nowCache = self.m_cardReplaceNowPokerCellCache
    local aniNode = self.view.deckNode.cardReplaceAniNode
    aniNode.arrow.gameObject:SetActive(true)
    aniNode.nowCardList.gameObject:SetActive(true)
    aniNode.preCardList.gameObject:SetActive(true)
    aniNode.gameObject:SetActive(false)
    self:_ResetPokerCellPos(preCache)
    self:_ResetPokerCellPos(nowCache)
    preCache:Refresh(0)
    nowCache:Refresh(0)
end

CardGameBlackjackShopMainCtrl.StopCardReplaceAni = HL.Method() << function(self)
    
    self.m_cardAniUpdateKey = self:_RemoveUpdate(self.m_cardAniUpdateKey)
    local preCache = self.m_cardReplacePrePokerCellCache
    for i = 1, preCache:GetCount() do
        preCache:Get(i):ClearAni()
    end
    local nowCache = self.m_cardReplaceNowPokerCellCache
    for i = 1, nowCache:GetCount() do
        nowCache:Get(i):ClearAni()
    end
    local aniNode = self.view.deckNode.cardReplaceAniNode
    aniNode.arrow.gameObject:SetActive(true)
    aniNode.nowCardList.gameObject:SetActive(true)
    aniNode.preCardList.gameObject:SetActive(true)
    aniNode.gameObject:SetActive(false)
    self:_ResetPokerCellPos(preCache)
    self:_ResetPokerCellPos(nowCache)
    preCache:Refresh(0)
    nowCache:Refresh(0)
    if self.m_cardAniQueue then
        self.m_cardAniQueue:Clear()
    end
end



CardGameBlackjackShopMainCtrl.PlayCardCreateAni = HL.Method(HL.Table, HL.Opt(HL.Function)) << function(self, cardInfo, onPlayEnd)
    local queue = self.m_cardAniQueue
    queue:Enqueue(function(finish)
        local deckNode = self.view.deckNode
        local aniNode = deckNode.cardChangeAniNode
        aniNode.gameObject:SetActive(true)
        aniNode.cardChangeTipsNode.gameObject:SetActive(false)
        
        self.m_cardChangePokerCellCache:Refresh(1, function(cell, index)
            cell:SetCardSuitRankStyle(cardInfo.suit, cardInfo.rank, cardInfo.style)
            cell:SetPokerMoveRootPos(cell.view.rectTransform, Vector2.zero)
            cell:SetFace(true)
        end)
        finish()
    end)
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyBackToDeck(finish)
    end)
    
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardChangeAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end



CardGameBlackjackShopMainCtrl.PlayCardDeleteAni = HL.Method(HL.Table, HL.Opt(HL.Function)) << function(self, cardInfo, onPlayEnd)
    local queue = self.m_cardAniQueue
    queue:Enqueue(function(finish)
        local deckNode = self.view.deckNode
        local aniNode = deckNode.cardChangeAniNode
        local iconDeckRect = deckNode.iconDeck.rectTransform
        aniNode.gameObject:SetActive(true)
        aniNode.cardChangeTipsNode.gameObject:SetActive(true)
        aniNode.cardChangeTipsNode:RefreshCardChangeTips({
            cardChangeType = GEnums.BlackJackCardGameCardChangeType.Delete
        })
        
        self.m_cardChangePokerCellCache:Refresh(1, function(cell, index)
            cell:SetCardSuitRankStyle(cardInfo.suit, cardInfo.rank, cardInfo.style)
            cell:SetPokerMoveRootPos(iconDeckRect, Vector2.zero)
            cell:SetFace(false)
        end)
        finish()
    end)
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyToLayout(finish)
    end)
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardChangeAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end





CardGameBlackjackShopMainCtrl.RefreshBtnOpNode = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local topKey = system:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard then
        local entry = system:FindChoose(topKey)
        
        local hasCard = (entry.ui.selectedCardIndex or 0) > 0
        local isRedundant = hasCard and system:IsChangeCardSelectionRedundant(entry)
        if self.m_chooseModeKey ~= topKey then
            self:EnterChooseMode(topKey, 1, false, true)
        end
        self:RefreshChooseState(hasCard and not isRedundant, isRedundant)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.GainCard then
        local entry = system:FindChoose(topKey)
        
        local selectNum = entry.ui.selectedIndexes ~= nil and #entry.ui.selectedIndexes or 0
        local maxSelectNum = system:GetGainCardMaxSelectNum(entry)
        if self.m_chooseModeKey ~= topKey then
            self:EnterChooseMode(topKey, maxSelectNum, true, true)
        end
        self:RefreshChooseState(selectNum > 0 and selectNum <= maxSelectNum, false)
        self:RefreshBtnOpNodeCurSelectNum(selectNum)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr then
        local entry = system:FindChoose(topKey)
        
        if self.m_chooseModeKey ~= topKey then
            self:EnterChooseMode(topKey, 1, false, false)
        end
        self:RefreshChooseState((entry.ui.selectedSuit or 0) > 0, false)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.Shop or topKey == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic then
        if self.m_isChooseMode then
            self:ExitChooseMode()
        end
        self:SetShopBtnMode(topKey == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic,
                system:GetShopSelectedBuyState(system:FindChoose(topKey)))
    end
end



CardGameBlackjackShopMainCtrl.SetShopBtnMode = HL.Method(HL.Boolean, HL.Opt(HL.String))
        << function(self, isChooseInitRelic, selectedBuyState)
    if isChooseInitRelic then
        self:SetBtnOpNodeState("WaitReady")
    elseif DeviceInfo.usingController then
        self:SetBtnOpNodeState("ExitShopState")
    elseif selectedBuyState == nil then
        self:SetBtnOpNodeState("NoChooseState")
    elseif selectedBuyState == CardGameBlackjackUtils.ShopItemBuyState.Buy then
        self:SetBtnOpNodeState("BuyState")
    else
        self:SetBtnOpNodeState("DisableBuyState")
    end
end




CardGameBlackjackShopMainCtrl.EnterChooseMode = HL.Method(HL.String, HL.Number, HL.Boolean, HL.Boolean)
        << function(self, chooseKey, maxSelectNum, isMultiSelect, canSkip)
    self.m_isChooseMode = true
    self.m_chooseModeKey = chooseKey
    self:SetShopModeUiState(true)
    
    self.view.skipBtn.gameObject:SetActive(canSkip)
    self:SetBtnOpNodeState(isMultiSelect and "MultiSelectState" or "SingleSelectState")
    if isMultiSelect then
        self:RefreshBtnOpNodeMaxSelectNum(maxSelectNum)
        self:RefreshBtnOpNodeCurSelectNum(0)
    end
    
    self:RefreshChooseState(false, false)
end



CardGameBlackjackShopMainCtrl.ExitChooseMode = HL.Method() << function(self)
    self.m_isChooseMode = false
    self.m_chooseModeKey = ""
    self:SetShopModeUiState(false)
    self:SetBtnOpNodeState("HideCanNotChooseFlag")
    self:SetBtnOpNodeState("SingleSelectState")
end



CardGameBlackjackShopMainCtrl.RefreshChooseState = HL.Method(HL.Boolean, HL.Boolean) << function(self, canConfirm, canNotChoose)
    self:SetBtnOpNodeState(canConfirm and "ChooseState" or "DisableChooseState")
    self:SetBtnOpNodeState(canNotChoose and "ShowCanNotChooseFlag" or "HideCanNotChooseFlag")
end


HL.Commit(CardGameBlackjackShopMainCtrl)
