local CardGameSceneBase = require_ex('LuaSystem/CardGame/CardGameSceneBase').CardGameSceneBase
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')

CardGameSceneBlackjack = HL.Class('CardGameSceneBlackjack', CardGameSceneBase)



CardGameSceneBlackjack.m_hpCellsCacheList = HL.Field(HL.Table)
CardGameSceneBlackjack.m_cardAniUpdateKey = HL.Field(HL.Number) << -1
CardGameSceneBlackjack.m_cardChangeAniTimer = HL.Field(HL.Number) << -1
CardGameSceneBlackjack.m_cardChangeAniEntries = HL.Field(HL.Table)
CardGameSceneBlackjack.m_cardChangeAniNowCardInfos = HL.Field(HL.Table)
CardGameSceneBlackjack.m_cardChangeAniQueue = HL.Field(CardGameAnimQueue)
CardGameSceneBlackjack.m_cardReplaceAniPreEntries = HL.Field(HL.Table)
CardGameSceneBlackjack.m_cardReplaceAniNowEntries = HL.Field(HL.Table)
CardGameSceneBlackjack.m_warmVfxControllers = HL.Field(HL.Table)
CardGameSceneBlackjack.m_hudMainAniQueue = HL.Field(CardGameAnimQueue)
CardGameSceneBlackjack.m_hudMainAniUpdateKey = HL.Field(HL.Number) << -1




CardGameSceneBlackjack.CardGameSceneBlackjack = HL.Constructor() << function(self)
    CardGameSceneBlackjack.SuperConstructor(self)
end

CardGameSceneBlackjack.GetScenePrefabName = HL.Override().Return(HL.String) << function(self)
    return "CardGameRoom_Blackjack"
end

CardGameSceneBlackjack.GetMaxSeatCount = HL.Override().Return(HL.Number) << function(self)
    return CardGameBlackjackUtils.MAX_SEAT_COUNT
end

CardGameSceneBlackjack.GetHudSeatToSceneSeat = HL.Override().Return(HL.Table) << function(self)
    return { 1, 2, 3, 4 }
end

CardGameSceneBlackjack.InitCharModels = HL.Override() << function(self)
    self:_ReleaseCharModels()
    for hudSeat = 1, self:GetMaxSeatCount() do
        local seatChar = self.seatChars[hudSeat]
        local charId = (seatChar and seatChar.charId) or ""
        self:CreateCharOnHudSeat(hudSeat, charId, seatChar and seatChar.showPotentialFx)
    end
end

CardGameSceneBlackjack.InitRegions = HL.Override() << function(self)
    local emptyRoot = self.sceneRoot.view.emptyRoot
    LuaSystemManager.cardGameSystem:RegisterRegion(CardGameBlackjackUtils.CARD_REGION_DECK, emptyRoot.tableCenterRoot)

    for i = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        
        local handRegion = LuaSystemManager.cardGameSystem:RegisterRegion(
                CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. i, emptyRoot[CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. i])
        handRegion:SetRelayoutShiftedCards(true)
        local deckRegion = LuaSystemManager.cardGameSystem:RegisterRegion(
                CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. i, emptyRoot[CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. i])
        deckRegion:SetRelayoutShiftedCards(true)
    end

    local cardAniNode = emptyRoot.cardAniNode
    
    local cardAniNodeGo = cardAniNode.gameObject or cardAniNode
    cardAniNodeGo:SetLayerRecursive(UIConst.WORLD_UI_LAYER)
    local cardChangeAniNode = cardAniNode.cardChangeAniNode
    LuaSystemManager.cardGameSystem:RegisterRegion(
        CardGameBlackjackUtils.CARD_REGION_CARD_CHANGE_ANI, cardChangeAniNode.cardLayout)
    cardChangeAniNode.gameObject:SetActive(false)
    local cardReplaceAniNode = cardAniNode.cardReplaceAniNode
    LuaSystemManager.cardGameSystem:RegisterRegion(
        CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_PRE, cardReplaceAniNode.preCardLayout)
    LuaSystemManager.cardGameSystem:RegisterRegion(
        CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_NOW, cardReplaceAniNode.nowCardLayout)
    cardReplaceAniNode.gameObject:SetActive(false)

    self:_InitCardAni()
    self:_InitHpCells()
end

CardGameSceneBlackjack._OnUnload = HL.Override() << function(self)
    self.m_hudMainAniUpdateKey = self:_RemoveUpdate(self.m_hudMainAniUpdateKey)
    if self.m_hudMainAniQueue then
        self.m_hudMainAniQueue:Clear()
    end
    self:StopCardChangeAni()
    self:StopCardReplaceAni()
    self:_ReleaseCardVfxWarm()
end



CardGameSceneBlackjack._InitHpCells = HL.Method() << function(self)
    self.m_hpCellsCacheList = {}
    for i = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        
        local relicInfoNode = self.hudMain.relicInfoNode["relicInfo_" .. i]
        self.m_hpCellsCacheList[i] = UIUtils.genCellCache(relicInfoNode.hpCell)
    end
end

CardGameSceneBlackjack.RefreshPlayerHpNum = HL.Method(HL.Number, HL.Number) << function(self, hudSeatIndex, curHp)
    local maxHp = Tables.cardGameBlackjackConst.initialHp
    local hpCellCache = self.m_hpCellsCacheList[hudSeatIndex]
    hpCellCache:Refresh(maxHp, function(cell, index)
        cell.stateController:SetState(index <= curHp and "Normal" or "Empty")
    end)
end


CardGameSceneBlackjack.PlayPlayerHpChangeAni = HL.Method(HL.Number, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, hudSeatIndex, beforeHp, afterHp, onPlayEnd)
    local maxHp = Tables.cardGameBlackjackConst.initialHp
    beforeHp = lume.clamp(beforeHp, 0, maxHp)
    afterHp = lume.clamp(afterHp, 0, maxHp)
    local hpCellCache = self.m_hpCellsCacheList[hudSeatIndex]
    if afterHp >= beforeHp then
        CardGameBlackjackUtils.PlayHpCellsChangeAni(hpCellCache, beforeHp + 1, afterHp, true, onPlayEnd)
    else
        CardGameBlackjackUtils.PlayHpCellsChangeAni(hpCellCache, afterHp + 1, beforeHp, false, onPlayEnd)
    end
end




CardGameSceneBlackjack._InitCardAni = HL.Method() << function(self)
    self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode.cardChangeTipsNode:InitCardChangeTipsNode()
    self.m_cardChangeAniQueue = CardGameAnimQueue()
    self.m_hudMainAniQueue = CardGameAnimQueue()
    self:_InitCardVfxWarm()
end




CardGameSceneBlackjack._InitCardVfxWarm = HL.Method() << function(self)
    self:_ReleaseCardVfxWarm()
    self.m_warmVfxControllers = {}
    local effectManager = GameInstance.effectManager
    for _, vfxName in pairs(CardGameUtils.CardEffectVFXName) do
        local controller = effectManager:CreateVFXController(vfxName)
        if controller ~= nil then
            table.insert(self.m_warmVfxControllers, controller)
        end
    end
end

CardGameSceneBlackjack._ReleaseCardVfxWarm = HL.Method() << function(self)
    local controllers = self.m_warmVfxControllers
    self.m_warmVfxControllers = nil
    if controllers == nil then
        return
    end
    local effectManager = GameInstance.effectManager
    for index = 1, #controllers do
        effectManager:RecycleVFX(controllers[index])
    end
end



CardGameSceneBlackjack.PlayTableInfoChangeCurPointNum = HL.Method(HL.Number, HL.Number, HL.Number, HL.Number, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, hudSeatIndex, valueChangeType, value, fromPoint, toPoint, maxPoint, onPlayEnd)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    local queue = self.m_hudMainAniQueue
    queue:Enqueue(function(finish)
        self:PlayChangeValueTips(pointInfo.curPointChangeTipsNode, valueChangeType, value, finish)
    end)
    queue:Enqueue(function(finish)
        AudioAdapter.PostEvent("Au_UI_Event_CambleCount")
        local duration = 0.5
        local elapsed = 0
        self.m_hudMainAniUpdateKey = self:_StartUpdate(function(deltaTime)
            elapsed = math.min(elapsed + deltaTime, duration)
            local curPoint = lume.lerp(fromPoint, toPoint, elapsed / duration)
            self:_RefreshTableInfoPointInfoPoint(pointInfo, curPoint, maxPoint)
            if elapsed >= duration then
                self.m_hudMainAniUpdateKey = self:_RemoveUpdate(self.m_hudMainAniUpdateKey)
                finish()
            end
        end)
    end)
    if onPlayEnd then
        queue:EnqueueFinallyAction(onPlayEnd)
    end
end


CardGameSceneBlackjack._RefreshTableInfoPointInfoPoint = HL.Method(HL.Any, HL.Number, HL.Number)
    << function(self, pointInfo, curPoint, maxPoint)
    pointInfo.curPointTxt.text = math.floor(curPoint)
    local progress = 0
    if maxPoint > 0 then
        progress = math.min(math.max(curPoint / maxPoint, 0), 1)
    end
    pointInfo.pointProgressBar.fillAmount = progress
end

CardGameSceneBlackjack.PlayTableInfoChangeMaxPointNum = HL.Method(HL.Number, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, hudSeatIndex, valueChangeType, value, onPlayEnd)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    self:PlayChangeValueTips(pointInfo.maxPointChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameSceneBlackjack.PlayTableInfoChangeExtraPointNum = HL.Method(HL.Number, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, hudSeatIndex, valueChangeType, value, onPlayEnd)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    self:PlayChangeValueTips(pointInfo.extraPointChangeTipsNode, valueChangeType, value, onPlayEnd)
end

CardGameSceneBlackjack.PlayChangeValueTips = HL.Method(HL.Any, HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeTips, valueChangeType, value, onPlayEnd)
    CardGameBlackjackUtils.PlayChangeValueTips(self, valueChangeTips, valueChangeType, value, onPlayEnd)
end

CardGameSceneBlackjack.TriggerCharRaiseHand = HL.Method(HL.Number) << function(self, hudSeat)
    local charItem = self.charItems[hudSeat]
    if not charItem or not charItem.animator then
        logger.error(string.format("CardGameSceneBlackjack.TriggerCharRaiseHand: char animator missing, index=%d", hudSeat))
        return
    end
    charItem.animator:SetTrigger("TriggerRaiseHand")
end

CardGameSceneBlackjack._GetPointInfo = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, index)
    if index < 1 or index > CardGameBlackjackUtils.MAX_SEAT_COUNT then
        logger.error(string.format("CardGameSceneBlackjack._GetPointInfo: invalid index=%d", index))
        return nil
    end
    return self.hudMain.tableInfoNode["pointInfo_" .. index]
end




CardGameSceneBlackjack.PlayCardChangeAni = HL.Method(HL.Table, HL.Table, HL.Table, HL.Number, HL.Boolean, HL.Opt(HL.Function))
    << function(self, changeInfo, preCardInfos, nowCardInfos, hudSeat, isFromHandZone, onPlayEnd)
    self:StopCardChangeAni()
    self.m_cardChangeAniNowCardInfos = nowCardInfos
    local aniNode = self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode
    aniNode.gameObject:SetActive(true)
    aniNode.cardChangeTipsNode.gameObject:SetActive(true)
    aniNode.cardChangeTipsNode:RefreshCardChangeTips(changeInfo)
    local cardCount = #preCardInfos
    if cardCount <= 0 then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    self:_AlignCardAniNodeToZone(aniNode, hudSeat, isFromHandZone)

    local cardSystem = LuaSystemManager.cardGameSystem
    
    local aniPoses = self:_GetCardChangeAniPoses(cardCount)
    if cardSystem == nil or aniPoses == nil then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    local queue = self.m_cardChangeAniQueue
    if isFromHandZone then
        
        local entries = self:_CollectHandZoneChangeAniEntries(preCardInfos, aniPoses, hudSeat)
        if entries == nil then
            self:StopCardChangeAni()
            if onPlayEnd then
                onPlayEnd()
            end
            return
        end
        self.m_cardChangeAniEntries = entries
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlyToLayout(self.m_cardChangeAniEntries, nil, finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_WaitCardChangeAniSee(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlipToNow(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_WaitCardChangeAniSee(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlyBack(self.m_cardChangeAniEntries, nil, finish)
        end)
        
        queue:EnqueueFinallyAction(function()
            self:_InvokeCardChangeAniPlayEnd()
            if onPlayEnd then
                onPlayEnd()
            end
        end)
    else
        
        local entries = self:_CreateDeckZoneChangeAniEntries(preCardInfos, aniPoses, hudSeat)
        if entries == nil then
            self:StopCardChangeAni()
            if onPlayEnd then
                onPlayEnd()
            end
            return
        end
        self.m_cardChangeAniEntries = entries
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlyToLayout(self.m_cardChangeAniEntries, true, finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_WaitCardChangeAniSee(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlipToNow(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_WaitCardChangeAniSee(finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlyBack(self.m_cardChangeAniEntries, false, finish)
        end)
        
        queue:Enqueue(function(finish)
            self:_RecycleCardChangeAniTempCards(finish)
        end)
        
        queue:EnqueueFinallyAction(function()
            self:_InvokeCardChangeAniPlayEnd()
            if onPlayEnd then
                onPlayEnd()
            end
        end)
    end
end

CardGameSceneBlackjack.StopCardChangeAni = HL.Method() << function(self)
    
    self.m_cardAniUpdateKey = self:_RemoveUpdate(self.m_cardAniUpdateKey)
    self.m_cardChangeAniTimer = self:_ClearTimer(self.m_cardChangeAniTimer)
    local cardSystem = LuaSystemManager.cardGameSystem
    local entries = self.m_cardChangeAniEntries or {}
    local nowCardInfos = self.m_cardChangeAniNowCardInfos or {}
    for index = 1, #entries do
        local entry = entries[index]
        local card = cardSystem and cardSystem:GetRuntimeCard(entry.uid)
        if card then
            card:KillAnim(false, false)
        end
        if entry.deckInsert ~= nil then
            
            if card then
                self:_SnapCardCreateToDeck(entry)
            end
        elseif entry.isTemp then
            if card then
                card:ResetVfx()
            end
            if cardSystem then
                cardSystem:RecycleDetachedCard(entry.uid)
            end
        else
            if card and nowCardInfos[index] then
                local nowInfo = nowCardInfos[index]
                cardSystem:SetPokerData(entry.uid, nowInfo.suit, nowInfo.rank, nowInfo.style, true)
            end
            if card and entry.originPose then
                card:ApplyPose(entry.originPose)
            end
        end
    end
    self.m_cardChangeAniEntries = {}
    self.m_cardChangeAniNowCardInfos = nil
    local cardChangeAniGo = self.sceneRoot and self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode.gameObject
    if NotNull(cardChangeAniGo) then
        cardChangeAniGo:SetActive(false)
    end
    if self.m_cardChangeAniQueue then
        self.m_cardChangeAniQueue:Clear()
    end
end




CardGameSceneBlackjack.PlayCardReplaceAni = HL.Method(HL.Table, HL.Table, HL.Number, HL.Opt(HL.Function))
    << function(self, preCardInfos, nowCardInfos, hudSeat, onPlayEnd)
    self:StopCardReplaceAni()
    local aniNode = self.sceneRoot.view.emptyRoot.cardAniNode.cardReplaceAniNode
    aniNode.gameObject:SetActive(true)
    aniNode.arrow.gameObject:SetActive(false)
    aniNode.nowCardLayout.gameObject:SetActive(false)
    aniNode.preCardLayout.gameObject:SetActive(true)
    self:_AlignCardAniNodeToZone(aniNode, hudSeat, false)

    local preCount = #preCardInfos
    local nowCount = #nowCardInfos
    if preCount + nowCount <= 0 then
        self:StopCardReplaceAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end

    local prePoses = self:_GetCardAniLayoutPoses(CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_PRE, preCount)
    local nowPoses = self:_GetCardAniLayoutPoses(CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_NOW, nowCount)
    if (preCount > 0 and prePoses == nil) or (nowCount > 0 and nowPoses == nil) then
        self:StopCardReplaceAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end

    local preEntries = self:_CreateDeckZoneChangeAniEntries(preCardInfos, prePoses or {}, hudSeat)
    local nowEntries = self:_CreateDeckZoneChangeAniEntries(
        nowCardInfos, nowPoses or {}, hudSeat, true, true, CardGameBlackjackUtils.CARD_CHANGE_ANI_TEMP_UID_BASE + 1000)
    if (preCount > 0 and preEntries == nil) or (nowCount > 0 and nowEntries == nil) then
        if preEntries then
            self.m_cardReplaceAniPreEntries = preEntries
        end
        if nowEntries then
            self.m_cardReplaceAniNowEntries = nowEntries
        end
        self:StopCardReplaceAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    self.m_cardReplaceAniPreEntries = preEntries or {}
    self.m_cardReplaceAniNowEntries = nowEntries or {}

    local queue = self.m_cardChangeAniQueue
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyToLayout(self.m_cardReplaceAniPreEntries, true, finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        aniNode.arrow.gameObject:SetActive(true)
        aniNode.nowCardLayout.gameObject:SetActive(true)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        aniNode.arrow.gameObject:SetActive(false)
        aniNode.preCardLayout.gameObject:SetActive(false)
        self:_WaitCardChangeAniSee(finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyBack(self.m_cardReplaceAniNowEntries, false, finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_RecycleAniTempEntries(self.m_cardReplaceAniPreEntries or {})
        self:_RecycleAniTempEntries(self.m_cardReplaceAniNowEntries or {}, finish)
    end)
    
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardReplaceAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end


CardGameSceneBlackjack._InvokeCardReplaceAniPlayEnd = HL.Method() << function(self)
    local aniNode = self.sceneRoot and self.sceneRoot.view.emptyRoot and self.sceneRoot.view.emptyRoot.cardAniNode.cardReplaceAniNode
    if aniNode and NotNull(aniNode.gameObject) then
        aniNode.arrow.gameObject:SetActive(true)
        aniNode.nowCardLayout.gameObject:SetActive(true)
        aniNode.preCardLayout.gameObject:SetActive(true)
        aniNode.gameObject:SetActive(false)
    end
    self.m_cardReplaceAniPreEntries = {}
    self.m_cardReplaceAniNowEntries = {}
end

CardGameSceneBlackjack.StopCardReplaceAni = HL.Method() << function(self)
    
    self.m_cardAniUpdateKey = self:_RemoveUpdate(self.m_cardAniUpdateKey)
    local cardSystem = LuaSystemManager.cardGameSystem
    local function stopEntries(entries)
        entries = entries or {}
        for index = 1, #entries do
            local entry = entries[index]
            local card = cardSystem and cardSystem:GetRuntimeCard(entry.uid)
            if card then
                card:KillAnim(false, false)
            end
            if entry.isTemp and cardSystem then
                cardSystem:RecycleDetachedCard(entry.uid)
            end
        end
    end
    stopEntries(self.m_cardReplaceAniPreEntries)
    stopEntries(self.m_cardReplaceAniNowEntries)
    self.m_cardReplaceAniPreEntries = {}
    self.m_cardReplaceAniNowEntries = {}
    local aniNode = self.sceneRoot and self.sceneRoot.view.emptyRoot and self.sceneRoot.view.emptyRoot.cardAniNode.cardReplaceAniNode
    if aniNode and NotNull(aniNode.gameObject) then
        aniNode.arrow.gameObject:SetActive(true)
        aniNode.nowCardLayout.gameObject:SetActive(true)
        aniNode.preCardLayout.gameObject:SetActive(true)
        aniNode.gameObject:SetActive(false)
    end
    if self.m_cardChangeAniQueue then
        self.m_cardChangeAniQueue:Clear()
    end
end






CardGameSceneBlackjack.PlayCardCreateAni = HL.Method(HL.Table, HL.Number, HL.Opt(HL.Table, HL.Function))
    << function(self, cardInfo, hudSeat, deckInsert, onPlayEnd)
    self:StopCardChangeAni()
    local aniNode = self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode
    aniNode.gameObject:SetActive(true)
    aniNode.cardChangeTipsNode.gameObject:SetActive(false)
    self:_AlignCardAniNodeToZone(aniNode, hudSeat, false)

    local aniPoses = self:_GetCardChangeAniPoses(1)
    if aniPoses == nil then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    local entries = self:_CreateCardCreateAniEntries(cardInfo, aniPoses, hudSeat, deckInsert)
    if entries == nil then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    self.m_cardChangeAniEntries = entries

    local queue = self.m_cardChangeAniQueue
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    if deckInsert ~= nil then
        
        queue:Enqueue(function(finish)
            self:_PlayCardCreateFlyToDeck(self.m_cardChangeAniEntries[1], finish)
        end)
    else
        queue:Enqueue(function(finish)
            self:_PlayCardChangeFlyBack(self.m_cardChangeAniEntries, false, finish)
        end)
        queue:Enqueue(function(finish)
            self:_RecycleCardChangeAniTempCards(finish)
        end)
    end
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardChangeAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end




CardGameSceneBlackjack.PlayCardDeleteAni = HL.Method(HL.Table, HL.Number, HL.Boolean, HL.Opt(HL.Number, HL.Function))
    << function(self, cardInfo, hudSeat, isFromHandZone, deckUid, onPlayEnd)
    self:StopCardChangeAni()
    local aniNode = self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode
    aniNode.gameObject:SetActive(true)
    aniNode.cardChangeTipsNode.gameObject:SetActive(true)
    aniNode.cardChangeTipsNode:RefreshCardChangeTips({
        cardChangeType = GEnums.BlackJackCardGameCardChangeType.Delete
    })
    self:_AlignCardAniNodeToZone(aniNode, hudSeat, isFromHandZone)

    local aniPoses = self:_GetCardChangeAniPoses(1)
    if aniPoses == nil then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    local entries
    if isFromHandZone then
        entries = self:_CollectHandZoneChangeAniEntries({ cardInfo }, aniPoses, hudSeat)
    elseif deckUid ~= nil then
        entries = self:_CollectDeckCardDeleteAniEntries(deckUid, aniPoses, hudSeat)
    else
        logger.error(string.format("CardGameSceneBlackjack.PlayCardDeleteAni: deckUid missing, hudSeat=%d", hudSeat))
    end
    if entries == nil then
        self:StopCardChangeAni()
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    
    
    local cardSystem = LuaSystemManager.cardGameSystem
    for index = 1, #entries do
        local entry = entries[index]
        if cardSystem then
            cardSystem:SetPokerData(entry.uid, cardInfo.suit, cardInfo.rank, cardInfo.style)
            cardSystem:DetachCardFromRegion(entry.uid, isFromHandZone)
        end
        entry.isTemp = true
    end
    self.m_cardChangeAniEntries = entries

    local flyFaceUp
    if not isFromHandZone then
        flyFaceUp = true
    end
    local queue = self.m_cardChangeAniQueue
    
    queue:Enqueue(function(finish)
        self:_PlayCardChangeFlyToLayout(self.m_cardChangeAniEntries, flyFaceUp, finish)
    end)
    queue:Enqueue(function(finish)
        self:_WaitCardChangeAniSee(finish)
    end)
    queue:Enqueue(function(finish)
        self:_PlayCardDeleteVfx(finish)
    end)
    queue:Enqueue(function(finish)
        self:_RecycleCardChangeAniTempCards(finish)
    end)
    queue:EnqueueFinallyAction(function()
        self:_InvokeCardChangeAniPlayEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end





CardGameSceneBlackjack._AlignCardAniNodeToZone = HL.Method(HL.Any, HL.Number, HL.Boolean)
    << function(self, aniNode, hudSeat, isFromHandZone)
    local regionPrefix = isFromHandZone and CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX
        or CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX
    local cardSystem = LuaSystemManager.cardGameSystem
    local region = cardSystem and cardSystem:GetRegion(regionPrefix .. hudSeat)
    local target = region:GetRoot()
    local aniTrans = aniNode.transform
    local aniPos = aniTrans.position
    local targetPos = target.position
    aniTrans.position = Vector3(targetPos.x, aniPos.y, targetPos.z)
    local aniEuler = aniTrans.eulerAngles
    local targetEuler = target.eulerAngles
    aniTrans.eulerAngles = Vector3(aniEuler.x, targetEuler.y, aniEuler.z)
end


CardGameSceneBlackjack._CollectHandZoneChangeAniEntries = HL.Method(HL.Table, HL.Table, HL.Number).Return(HL.Opt(HL.Table))
    << function(self, preCardInfos, aniPoses, hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    local handRegion = cardSystem and cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)
    if handRegion == nil then
        logger.error(string.format("CardGameSceneBlackjack._CollectHandZoneChangeAniEntries: hand region missing, hudSeat=%d", hudSeat))
        return nil
    end
    local entries = {}
    for index = 1, #preCardInfos do
        local uid = preCardInfos[index].uid
        local card = uid and cardSystem:GetRuntimeCard(uid)
        if card == nil then
            logger.error(string.format("CardGameSceneBlackjack._CollectHandZoneChangeAniEntries: hand card missing, uid=%s", tostring(uid)))
            return nil
        end
        local originPose = handRegion:GetPose(card.indexInRegion)
        if originPose == nil then
            logger.error(string.format("CardGameSceneBlackjack._CollectHandZoneChangeAniEntries: hand pose missing, uid=%s, index=%d", tostring(uid), card.indexInRegion))
            return nil
        end
        entries[index] = {
            uid = uid,
            originPose = originPose,
            aniPose = aniPoses[index],
            isTemp = false,
        }
    end
    return entries
end



CardGameSceneBlackjack._CreateDeckZoneChangeAniEntries = HL.Method(HL.Table, HL.Table, HL.Number, HL.Opt(HL.Boolean, HL.Boolean, HL.Number)).Return(HL.Opt(HL.Table))
    << function(self, preCardInfos, aniPoses, hudSeat, faceUp, placeAtAniPose, uidBase)
    local originPose = self:_GetCardDeckZeroPose(hudSeat)
    if originPose == nil then
        return nil
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        return nil
    end
    local useFaceUp = faceUp == true
    local useAniPose = placeAtAniPose == true
    local base = uidBase or CardGameBlackjackUtils.CARD_CHANGE_ANI_TEMP_UID_BASE
    local entries = {}
    for index = 1, #preCardInfos do
        local preInfo = preCardInfos[index]
        local uid = base + index
        cardSystem:RecycleDetachedCard(uid)
        local card = cardSystem:CreateDetachedCard(uid, useFaceUp)
        if card == nil then
            logger.error(string.format("CardGameSceneBlackjack._CreateDeckZoneChangeAniEntries: create temp card failed, uid=%d", uid))
            for createdIndex = 1, #entries do
                cardSystem:RecycleDetachedCard(entries[createdIndex].uid)
            end
            return nil
        end
        cardSystem:SetPokerData(uid, preInfo.suit, preInfo.rank, preInfo.style, useFaceUp)
        local startPose = useAniPose and aniPoses[index] or originPose
        if startPose == nil then
            logger.error(string.format("CardGameSceneBlackjack._CreateDeckZoneChangeAniEntries: start pose missing, index=%d", index))
            cardSystem:RecycleDetachedCard(uid)
            for createdIndex = 1, #entries do
                cardSystem:RecycleDetachedCard(entries[createdIndex].uid)
            end
            return nil
        end
        card:ApplyPose(startPose)
        entries[index] = {
            uid = uid,
            originPose = originPose,
            aniPose = aniPoses[index],
            isTemp = true,
        }
    end
    return entries
end



CardGameSceneBlackjack._CreateCardCreateAniEntries = HL.Method(HL.Table, HL.Table, HL.Number, HL.Opt(HL.Table)).Return(HL.Opt(HL.Table))
    << function(self, cardInfo, aniPoses, hudSeat, deckInsert)
    if aniPoses == nil or aniPoses[1] == nil then
        return nil
    end
    local originPose = self:_GetCardDeckZeroPose(hudSeat)
    if originPose == nil then
        return nil
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        return nil
    end
    local uid = deckInsert ~= nil and deckInsert.uid or CardGameBlackjackUtils.CARD_CHANGE_ANI_TEMP_UID_BASE + 1
    if deckInsert == nil then
        cardSystem:RecycleDetachedCard(uid)
    end
    local card = cardSystem:CreateDetachedCard(uid, true)
    if card == nil then
        logger.error(string.format("CardGameSceneBlackjack._CreateCardCreateAniEntries: create temp card failed, uid=%d", uid))
        return nil
    end
    cardSystem:SetPokerData(uid, cardInfo.suit, cardInfo.rank, cardInfo.style, true)
    card:ApplyPose(aniPoses[1])
    return {
        {
            uid = uid,
            originPose = originPose,
            aniPose = aniPoses[1],
            isTemp = deckInsert == nil,
            deckInsert = deckInsert,
            hudSeat = hudSeat,
        },
    }
end


CardGameSceneBlackjack._PlayCardCreateFlyToDeck = HL.Method(HL.Table, HL.Function) << function(self, entry, onPlayEnd)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        onPlayEnd()
        return
    end
    local deckInsert = entry.deckInsert
    cardSystem:SetCardStyle(entry.uid, deckInsert.style)
    local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. entry.hudSeat
    local pose = cardSystem:AttachDetachedCardToRegion(entry.uid, regionId, deckInsert.regionIndex, true)
    entry.isAttached = pose ~= nil
    entry.targetPose = pose
    if pose == nil then
        onPlayEnd()
        return
    end
    cardSystem:MoveCardByUidToPose(entry.uid, pose, false, true, true, onPlayEnd)
end


CardGameSceneBlackjack._SnapCardCreateToDeck = HL.Method(HL.Table) << function(self, entry)
    local cardSystem = LuaSystemManager.cardGameSystem
    local card = cardSystem and cardSystem:GetRuntimeCard(entry.uid)
    if card == nil then
        return
    end
    if not entry.isAttached then
        local deckInsert = entry.deckInsert
        cardSystem:SetCardStyle(entry.uid, deckInsert.style)
        local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. entry.hudSeat
        entry.targetPose = cardSystem:AttachDetachedCardToRegion(entry.uid, regionId, deckInsert.regionIndex, false)
        entry.isAttached = entry.targetPose ~= nil
    end
    if entry.targetPose ~= nil then
        card:SetFace(false)
        card:ApplyPose(entry.targetPose)
    end
end


CardGameSceneBlackjack._CollectDeckCardDeleteAniEntries = HL.Method(HL.Number, HL.Table, HL.Number).Return(HL.Opt(HL.Table))
    << function(self, deckUid, aniPoses, hudSeat)
    if aniPoses == nil or aniPoses[1] == nil then
        return nil
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    local deckRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
    local deckRegion = cardSystem and cardSystem:GetRegion(deckRegionId)
    if deckRegion == nil then
        logger.error(string.format("CardGameSceneBlackjack._CollectDeckCardDeleteAniEntries: deck region missing, hudSeat=%d", hudSeat))
        return nil
    end
    local card = cardSystem:GetRuntimeCard(deckUid)
    if card == nil or card.regionId ~= deckRegionId then
        logger.error(string.format("CardGameSceneBlackjack._CollectDeckCardDeleteAniEntries: deck card missing, uid=%s, hudSeat=%d", tostring(deckUid), hudSeat))
        return nil
    end
    local originPose = deckRegion:GetPose(card.indexInRegion)
    if originPose == nil then
        logger.error(string.format("CardGameSceneBlackjack._CollectDeckCardDeleteAniEntries: deck pose missing, uid=%s", tostring(card.uid)))
        return nil
    end
    return {
        {
            uid = card.uid,
            originPose = originPose,
            aniPose = aniPoses[1],
            isTemp = false,
        },
    }
end


CardGameSceneBlackjack._PlayCardChangeFlyCards = HL.Method(HL.Table, HL.String, HL.Opt(HL.Boolean, HL.Function))
    << function(self, entries, poseKey, finalFaceUp, onPlayEnd)
    local cardCount = entries and #entries or 0
    if cardCount <= 0 then
        if onPlayEnd then
            onPlayEnd()
        end
        return
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
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
    for index = 1, cardCount do
        local entry = entries[index]
        cardSystem:MoveCardByUidToPose(entry.uid, entry[poseKey], finalFaceUp, true, true, onOneEnd)
    end
end


CardGameSceneBlackjack._PlayCardChangeFlyToLayout = HL.Method(HL.Table, HL.Opt(HL.Boolean, HL.Function))
    << function(self, entries, finalFaceUp, onPlayEnd)
    self:_PlayCardChangeFlyCards(entries, "aniPose", finalFaceUp, onPlayEnd)
end


CardGameSceneBlackjack._PlayCardChangeFlyBack = HL.Method(HL.Table, HL.Opt(HL.Boolean, HL.Function))
    << function(self, entries, finalFaceUp, onPlayEnd)
    self:_PlayCardChangeFlyCards(entries, "originPose", finalFaceUp, onPlayEnd)
end


CardGameSceneBlackjack._RecycleAniTempEntries = HL.Method(HL.Table, HL.Opt(HL.Function))
    << function(self, entries, onPlayEnd)
    local cardSystem = LuaSystemManager.cardGameSystem
    entries = entries or {}
    for index = 1, #entries do
        local entry = entries[index]
        if entry.isTemp and cardSystem then
            local card = cardSystem:GetRuntimeCard(entry.uid)
            if card then
                card:ResetVfx()
            end
            cardSystem:RecycleDetachedCard(entry.uid)
        end
    end
    if onPlayEnd then
        onPlayEnd()
    end
end


CardGameSceneBlackjack._RecycleCardChangeAniTempCards = HL.Method(HL.Opt(HL.Function))
    << function(self, onPlayEnd)
    self:_RecycleAniTempEntries(self.m_cardChangeAniEntries or {}, onPlayEnd)
end


CardGameSceneBlackjack._InvokeCardChangeAniPlayEnd = HL.Method() << function(self)
    if self.sceneRoot and self.sceneRoot.view.emptyRoot then
        self.sceneRoot.view.emptyRoot.cardAniNode.cardChangeAniNode.gameObject:SetActive(false)
    end
    self.m_cardChangeAniEntries = {}
    self.m_cardChangeAniNowCardInfos = nil
end


CardGameSceneBlackjack._PlayCardChangeFlipToNow = HL.Method(HL.Function) << function(self, onPlayEnd)
    local entries = self.m_cardChangeAniEntries or {}
    local nowCardInfos = self.m_cardChangeAniNowCardInfos or {}
    local cardCount = #entries
    if cardCount <= 0 then
        onPlayEnd()
        return
    end

    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
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
    
    AudioAdapter.PostEvent("Au_UI_Event_CardFlip")
    for index = 1, cardCount do
        local entry = entries[index]
        local nowInfo = nowCardInfos[index]
        local card = cardSystem:GetRuntimeCard(entry.uid)
        if card == nil then
            onOneEnd()
        else
            card:PlayRotate(Vector3(0, 180, 0), function()
                if nowInfo then
                    cardSystem:SetPokerData(entry.uid, nowInfo.suit, nowInfo.rank, nowInfo.style)
                end
                card:PlayRotate(Vector3(0, -180, 0), onOneEnd)
            end)
        end
    end
end


CardGameSceneBlackjack._PlayCardDeleteVfx = HL.Method(HL.Function) << function(self, nextFn)
    local cardSystem = LuaSystemManager.cardGameSystem
    local entries = self.m_cardChangeAniEntries
    local vfxName = CardGameUtils.CardEffectVFXName.Delete
    local duration = 0
    AudioAdapter.PostEvent("Au_UI_Event_Card21Delete")
    if cardSystem and entries then
        for index = 1, #entries do
            local card = cardSystem:GetRuntimeCard(entries[index].uid)
            if card then
                card:PlayVfx(vfxName)
                local startTime = card:GetVfxStartTime(vfxName)
                if startTime > duration then
                    duration = startTime
                end
            end
        end
    end
    if duration <= 0 then
        nextFn()
        return
    end
    self.m_cardChangeAniTimer = self:_StartTimer(duration, function()
        self.m_cardChangeAniTimer = -1
        nextFn()
    end)
end


CardGameSceneBlackjack._WaitCardChangeAniSee = HL.Method(HL.Function) << function(self, nextFn)
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


CardGameSceneBlackjack._GetCardAniLayoutPoses = HL.Method(HL.String, HL.Number).Return(HL.Opt(HL.Table))
    << function(self, regionId, cardCount)
    if cardCount <= 0 then
        return {}
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    local region = cardSystem and cardSystem:GetRegion(regionId)
    if region == nil then
        logger.error(string.format("CardGameSceneBlackjack._GetCardAniLayoutPoses: region not registered, regionId=%s", regionId))
        return nil
    end
    region:GetLayout():UpdatePoses(cardCount)
    local poses = {}
    for index = 1, cardCount do
        poses[index] = region:GetPose(index)
        if poses[index] == nil then
            logger.error(string.format("CardGameSceneBlackjack._GetCardAniLayoutPoses: missing pose, regionId=%s, index=%d", regionId, index))
            return nil
        end
    end
    return poses
end


CardGameSceneBlackjack._GetCardChangeAniPoses = HL.Method(HL.Number).Return(HL.Opt(HL.Table))
    << function(self, cardCount)
    return self:_GetCardAniLayoutPoses(CardGameBlackjackUtils.CARD_REGION_CARD_CHANGE_ANI, cardCount)
end


CardGameSceneBlackjack._GetCardDeckZeroPose = HL.Method(HL.Number).Return(HL.Opt(HL.Table))
    << function(self, hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    local region = cardSystem and cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat)
    if region == nil then
        logger.error(string.format("CardGameSceneBlackjack._GetCardDeckZeroPose: deck region missing, hudSeat=%d", hudSeat))
        return nil
    end
    local pose = region:GetPose(1)
    if pose ~= nil then
        pose.localPosition = Vector3.zero
        return pose
    end
    return {
        root = region:GetRoot(),
        localPosition = Vector3.zero,
        localEulerAngles = Vector3.zero,
        localScale = Vector3.one,
    }
end




HL.Commit(CardGameSceneBlackjack)
