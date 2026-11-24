local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local luaLoader = require_ex('Common/Utils/LuaResourceLoader')
local CardGameCard = require_ex('LuaSystem/CardGame/CardGameCard')
local CardGameRegion = require_ex('LuaSystem/CardGame/CardGameRegion')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')

local POKER_PREFAB_PATH = "Assets/Beyond/DynamicAssets/Gameplay/CardGame/Prefabs/CardGamePoker.prefab"
local POKER_POOL_ROOT_NAME = "PokerObjPoolRoot"

CardGameSystem = HL.Class('CardGameSystem', LuaSystemBase.LuaSystemBase)

CardGameSystem.m_resourceLoader = HL.Field(HL.Forward("LuaResourceLoader"))

CardGameSystem.m_pokerPrefab = HL.Field(HL.Any)

CardGameSystem.m_poolRoot = HL.Field(Transform)



CardGameSystem.m_freeList = HL.Field(HL.Table)


CardGameSystem.m_regions = HL.Field(HL.Table)


CardGameSystem.m_allCards = HL.Field(HL.Table)



CardGameSystem.isClientInGame = HL.Field(HL.Boolean) << false


CardGameSystem.isServerInGame = HL.Field(HL.Boolean) << false


CardGameSystem.isEnterFromMatchRoom = HL.Field(HL.Boolean) << false


CardGameSystem.m_gameId = HL.Field(HL.String) << ""


CardGameSystem.m_isGuideAccepted = HL.Field(HL.Boolean) << false



CardGameSystem.CardGameSystem = HL.Constructor() << function(self)
end

CardGameSystem.OnInit = HL.Override() << function(self)
    self.m_resourceLoader = luaLoader.LuaResourceLoader()
    self.m_pokerPrefab = self.m_resourceLoader:LoadGameObject(POKER_PREFAB_PATH)
    self:_EnsurePoolRoot()
    self.m_freeList = {}
    self.m_regions = {}
    self.m_allCards = {}

    
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_ENTER_PLAY_ROOM, function(arg)
        local enterPlayRoomInfo = unpack(arg)
        local gameId = enterPlayRoomInfo.gameId
        self.m_gameId = gameId
        self.isServerInGame = true
        self.isEnterFromMatchRoom = GameInstance.player.multiplayerMatchSystem.isInMatchRoom
        self:TryAcceptGuide(gameId)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_LEAVE, function(arg)
        local _, isSelf, gameIdNum = unpack(arg)
        if not isSelf then
            return
        end
        local found, gameId = CS.Beyond.Cfg.Tables.roomGameIdToStr:TryGetValue(gameIdNum)
        if found then
            self.m_gameId = gameId
        end
        self.isServerInGame = false
        self:_TryOnBothLeave()
    end)
    
end

CardGameSystem.OnRelease = HL.Override() << function(self)
    self:ClearRuntimeCards()
    self:ClearPokerPool()
    self.m_regions = {}
    self.m_pokerPrefab = nil
    if NotNull(self.m_poolRoot) then
        GameObject.Destroy(self.m_poolRoot.gameObject)
    end
    self.m_poolRoot = nil
    if self.m_resourceLoader then
        self.m_resourceLoader:DisposeAllHandles()
        self.m_resourceLoader = nil
    end
end






CardGameSystem.StartGame = HL.Method() << function(self)
    self.isClientInGame = true
    Notify(MessageConst.ON_CARD_GAME_START)
end



CardGameSystem.StopGame = HL.Method() << function(self)
    self.isClientInGame = false
    self:_TryOnBothLeave()
    AudioAdapter.PostEvent("Au_UI_Event_CardGameExit")
end


CardGameSystem._TryOnBothLeave = HL.Method() << function(self)
    if self.isClientInGame or self.isServerInGame then
        return
    end
    self.isEnterFromMatchRoom = false
    self:StopGuide()
end







CardGameSystem._EnsurePoolRoot = HL.Method() << function(self)
    if NotNull(self.m_poolRoot) then
        return
    end
    local go = GameObject(POKER_POOL_ROOT_NAME)
    GameObject.DontDestroyOnLoad(go)
    self.m_poolRoot = go.transform
end

CardGameSystem._CreatePoker = HL.Method().Return(GameObject) << function(self)
    local go = GameObject.Instantiate(self.m_pokerPrefab, self.m_poolRoot)
    go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
    go:SetActive(false)
    return go
end


CardGameSystem.InitPokerPool = HL.Method(HL.Number) << function(self, count)
    if count < 0 then
        logger.error("CardGameSystem.InitPokerPool: count < 0, count=" .. tostring(count))
        return
    end
    if IsNull(self.m_pokerPrefab) then
        logger.error("CardGameSystem.InitPokerPool: poker prefab is null")
        return
    end
    self:_EnsurePoolRoot()

    while #self.m_freeList > count do
        local go = table.remove(self.m_freeList)
        if NotNull(go) then
            GameObject.Destroy(go)
        end
    end
    while #self.m_freeList < count do
        table.insert(self.m_freeList, self:_CreatePoker())
    end
end


CardGameSystem.ClearPokerPool = HL.Method() << function(self)
    if not self.m_freeList then
        return
    end
    for i = 1, #self.m_freeList do
        local go = self.m_freeList[i]
        if NotNull(go) then
            GameObject.Destroy(go)
        end
    end
    self.m_freeList = {}
end


CardGameSystem._ReturnFreeToPool = HL.Method() << function(self)
    self:_EnsurePoolRoot()
    for i = 1, #self.m_freeList do
        local go = self.m_freeList[i]
        if NotNull(go) then
            go.transform:SetParent(self.m_poolRoot, false)
        end
    end
end

CardGameSystem.AllocPoker = HL.Method().Return(GameObject) << function(self)
    local go
    if #self.m_freeList > 0 then
        go = table.remove(self.m_freeList)
    else
        if IsNull(self.m_pokerPrefab) then
            logger.error("CardGameSystem.AllocPoker: poker prefab is null")
            return nil
        end
        self:_EnsurePoolRoot()
        go = self:_CreatePoker()
    end
    if NotNull(go) then
        go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
        local visual = go:GetComponent(typeof(CS.Beyond.UI.CardGamePokerVisual))
        if visual then
            visual:KillAnim(false, false)
            visual:ResetInteractionState()
        end
        go:SetActive(true)
    end
    return go
end

CardGameSystem.Recycle = HL.Method(GameObject) << function(self, go)
    if IsNull(go) then
        return
    end
    local visual = go:GetComponent(typeof(CS.Beyond.UI.CardGamePokerVisual))
    if visual then
        visual:KillAnim(false, false)
        visual:ResetInteractionState()
    end
    go:SetActive(false)
    table.insert(self.m_freeList, go)
end








CardGameSystem.RegisterRegion = HL.Method(HL.String, HL.Any).Return(HL.Any) << function(self, id, layout)
    if string.isEmpty(id) then
        error("CardGameSystem.RegisterRegion: id 不能为空")
    end

    local region = CardGameRegion(id, self:_ResolveRegionLayout("RegisterRegion", id, layout))
    self.m_regions[id] = region
    return region
end



CardGameSystem.RebindRegionLayout = HL.Method(HL.String, HL.Any).Return(HL.Boolean) << function(self, id, layout)
    local region = self.m_regions[id]
    if not region then
        logger.error("CardGameSystem.RebindRegionLayout: 找不到区域, regionId=" .. tostring(id))
        return false
    end
    layout = self:_ResolveRegionLayout("RebindRegionLayout", id, layout)
    if region:GetLayout() == layout then
        return false
    end
    region:RebindLayout(layout)
    return true
end

CardGameSystem._ResolveRegionLayout = HL.Method(HL.String, HL.String, HL.Any).Return(CS.Beyond.UI.CardGamePokerLayout)
        << function(self, caller, id, layout)
    if IsNull(layout) then
        error("CardGameSystem." .. caller .. ": layout 为空, id=" .. tostring(id))
    end

    local layoutType = typeof(CS.Beyond.UI.CardGamePokerLayout)
    local receivedType = layout:GetType()
    if receivedType ~= layoutType then
        local ok
        ok, layout = layout:TryGetComponent(layoutType)
        if not ok or IsNull(layout) then
            error("CardGameSystem." .. caller .. ": 需要 CardGamePokerLayout, id=" .. tostring(id)
                    .. ", type=" .. tostring(receivedType))
        end
    end
    return layout
end



CardGameSystem.GetRegion = HL.Method(HL.String).Return(HL.Opt(HL.Any)) << function(self, id)
    return self.m_regions[id]
end


CardGameSystem.ClearRegions = HL.Method() << function(self)
    self:ClearRuntimeCards()
    self:_ReturnFreeToPool()
    self.m_regions = {}
end







CardGameSystem.CreateCard = HL.Method(HL.String, HL.Number).Return(HL.Any) << function(self, regionId, uid)
    local region = self.m_regions[regionId]
    if not region then
        logger.error("CardGameSystem.CreateCard: 找不到区域, regionId=" .. tostring(regionId))
        return nil
    end
    if self.m_allCards[uid] then
        logger.error("CardGameSystem.CreateCard: uid 已存在, uid=" .. tostring(uid))
        return self.m_allCards[uid]
    end

    local card = self:_CreateRuntimeCard(uid, false)
    region:AddCard(card, nil, false)
    return card
end


CardGameSystem.CreateDetachedCard = HL.Method(HL.Number, HL.Opt(HL.Boolean))
        .Return(HL.Opt(HL.Any)) << function(self, uid, faceUp)
    if self.m_allCards[uid] ~= nil then
        logger.error("CardGameSystem.CreateDetachedCard: uid 已存在, uid=" .. tostring(uid))
        return nil
    end
    return self:_CreateRuntimeCard(uid, faceUp == true)
end


CardGameSystem._CreateRuntimeCard = HL.Method(HL.Number, HL.Boolean).Return(HL.Any) << function(self, uid, faceUp)
    local go = self:AllocPoker()
    if IsNull(go) then
        return nil
    end
    local card = CardGameCard(uid, go)
    card:SetFace(faceUp)
    self.m_allCards[card.uid] = card
    return card
end



CardGameSystem.GetRuntimeCard = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, uid)
    return self.m_allCards[uid]
end



CardGameSystem.SetRuntimeCardVisible = HL.Method(HL.Number, HL.Boolean).Return(HL.Boolean)
        << function(self, uid, visible)
    local card = self.m_allCards[uid]
    if card == nil or IsNull(card.go) then
        return false
    end
    card.go:SetActive(visible)
    return true
end



CardGameSystem.DetachCardFromRegion = HL.Method(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Opt(HL.Any)) << function(self, uid, useAnim)
    local card = self.m_allCards[uid]
    if card == nil then
        logger.error("CardGameSystem.DetachCardFromRegion: 找不到牌, uid=" .. tostring(uid))
        return nil
    end
    if string.isEmpty(card.regionId) then
        return card
    end
    local region = self.m_regions[card.regionId]
    if region == nil or not region:RemoveCard(card, useAnim == true) then
        logger.error("CardGameSystem.DetachCardFromRegion: 从区域移除失败, uid=" .. tostring(uid)
                .. ", regionId=" .. tostring(card.regionId))
        return nil
    end
    return card
end


CardGameSystem.RecycleDetachedCard = HL.Method(HL.Number).Return(HL.Boolean) << function(self, uid)
    local card = self.m_allCards[uid]
    if card == nil then
        return true
    end
    if not string.isEmpty(card.regionId) then
        logger.error("CardGameSystem.RecycleDetachedCard: 牌仍属于区域, uid="
                .. tostring(uid) .. ", regionId=" .. tostring(card.regionId))
        return false
    end
    card:KillAnim(false, false)
    self.m_allCards[uid] = nil
    if card.go ~= nil then
        self:Recycle(card.go)
    end
    return true
end



CardGameSystem.AttachDetachedCardToRegion = HL.Method(HL.Number, HL.String, HL.Opt(HL.Number, HL.Boolean)).Return(HL.Opt(HL.Table)) << function(self, uid, toRegionId, toIndex, relayoutOthersUseAnim)
    local card = self.m_allCards[uid]
    local region = self.m_regions[toRegionId]
    if card == nil or region == nil then
        logger.error("CardGameSystem.AttachDetachedCardToRegion: 牌或区域不存在, uid="
                .. tostring(uid) .. ", regionId=" .. tostring(toRegionId))
        return nil
    end
    if not string.isEmpty(card.regionId) then
        logger.error("CardGameSystem.AttachDetachedCardToRegion: 牌仍属于区域, uid="
                .. tostring(uid) .. ", regionId=" .. tostring(card.regionId))
        return nil
    end
    local targetPose = region:AddCard(card, toIndex, relayoutOthersUseAnim == true, false)
    return targetPose
end



CardGameSystem.MoveCardByUidToPose = HL.Method(HL.Number, HL.Table, HL.Opt(HL.Boolean, HL.Boolean, HL.Boolean, HL.Function)).Return(HL.Boolean)
    << function(self, uid, pose, finalFaceUp, useAnim, useLift, onComplete)
    local card = self.m_allCards[uid]
    if card == nil or pose == nil or IsNull(pose.root) then
        logger.error("CardGameSystem.MoveCardByUidToPose: 牌或 pose 无效, uid=" .. tostring(uid))
        if onComplete ~= nil then
            onComplete()
        end
        return false
    end

    if useAnim == false then
        if finalFaceUp ~= nil then
            card:SetFace(finalFaceUp)
        end
        card:ApplyPose(pose)
        if onComplete ~= nil then
            onComplete()
        end
        return true
    end

    if finalFaceUp == nil then
        card:PlayMoveToPose(pose, onComplete, useLift == true)
    else
        card:PlayMoveFlipToPose(pose, finalFaceUp, onComplete, useLift == true)
    end
    return true
end



CardGameSystem.SetCardData = HL.Method(HL.Number, HL.Number, HL.Number, HL.Opt(HL.Boolean)) << function(self, uid, suit, rank, faceUp)
    local card = self.m_allCards[uid]
    if not card then
        logger.error("CardGameSystem.SetCardData: 找不到牌, uid=" .. tostring(uid))
        return
    end
    card:SetCardData(suit, rank)
    if faceUp ~= nil then
        card:SetFace(faceUp)
    end
end





CardGameSystem.ReplaceCardUid = HL.Method(HL.Number, HL.Number).Return(HL.Boolean) << function(self, oldUid, newUid)
    if oldUid == newUid then
        return true
    end
    local card = self.m_allCards[oldUid]
    if not card then
        logger.error("CardGameSystem.ReplaceCardUid: 找不到牌, oldUid=" .. tostring(oldUid))
        return false
    end
    if self.m_allCards[newUid] then
        logger.error("CardGameSystem.ReplaceCardUid: newUid 已被占用, newUid=" .. tostring(newUid))
        return false
    end

    self.m_allCards[oldUid] = nil
    card.uid = newUid
    self.m_allCards[newUid] = card
    return true
end



CardGameSystem.SetCardStyle = HL.Method(HL.Number, HL.String) << function(self, uid, style)
    local card = self.m_allCards[uid]
    if not card then
        logger.error("CardGameSystem.SetCardStyle: 找不到牌, uid=" .. tostring(uid))
        return
    end
    card:SetCardStyle(style)
end


CardGameSystem.SetPokerData = HL.Method(HL.Number, HL.Number, HL.Number, HL.String, HL.Opt(HL.Boolean))
        << function(self, uid, suit, rank, style, faceUp)
    local card = self.m_allCards[uid]
    if not card then
        logger.error("CardGameSystem.SetPokerData: 找不到牌, uid=" .. tostring(uid))
        return
    end
    card:SetPokerData(suit, rank, style)
    if faceUp ~= nil then
        card:SetFace(faceUp)
    end
end


CardGameSystem.ClearRuntimeCards = HL.Method() << function(self)
    for _, card in pairs(self.m_allCards or {}) do
        if card then
            card:KillAnim(false, false)
            if card.go then
                self:Recycle(card.go)
            end
        end
    end
    self.m_allCards = {}
    for _, region in pairs(self.m_regions or {}) do
        region:ClearCards()
    end
end



CardGameSystem.RecycleRegionCards = HL.Method(HL.String).Return(HL.Boolean) << function(self, regionId)
    local region = self.m_regions[regionId]
    if not region then
        logger.error("CardGameSystem.RecycleRegionCards: 找不到区域, regionId=" .. tostring(regionId))
        return false
    end

    while region:GetCardCount() > 0 do
        local card = region:RemoveAtIndex(region:GetCardCount(), false)
        if card == nil then
            logger.error("CardGameSystem.RecycleRegionCards: 区域牌列表异常, regionId=" .. tostring(regionId))
            return false
        end
        card:KillAnim(false, false)
        self.m_allCards[card.uid] = nil
        if card.go then
            self:Recycle(card.go)
        end
    end
    return true
end




CardGameSystem.RecycleCardByUid = HL.Method(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Boolean)
        << function(self, uid, relayoutUseAnim)
    local card = self.m_allCards[uid]
    if card == nil then
        logger.error("CardGameSystem.RecycleCardByUid: 找不到牌, uid=" .. tostring(uid))
        return false
    end

    if not string.isEmpty(card.regionId) then
        local region = self.m_regions[card.regionId]
        if region == nil or not region:RemoveCard(card, relayoutUseAnim == true) then
            logger.error("CardGameSystem.RecycleCardByUid: 从区域移除失败, uid=" .. tostring(uid)
                    .. ", regionId=" .. tostring(card.regionId))
            return false
        end
    end

    card:KillAnim(false, false)
    self.m_allCards[uid] = nil
    if card.go then
        self:Recycle(card.go)
    end
    return true
end


CardGameSystem.PlayHandGatherThenSortByUidList = HL.Method(HL.String, HL.Table, HL.Table,
        HL.Boolean, HL.Number, HL.Number, HL.Function)
        << function(self, regionId, addedUidList, finalUidList, finalFaceUp,
        gatherDuration, spreadDuration, onComplete)
    local region = self.m_regions[regionId]
    if region == nil then
        error("CardGameSystem.PlayHandGatherThenSortByUidList: missing region, regionId="
                .. regionId)
    end
    local addedCards = {}
    for index, uid in ipairs(addedUidList) do
        local card = self.m_allCards[uid]
        if card == nil then
            error("CardGameSystem.PlayHandGatherThenSortByUidList: missing card, uid="
                    .. tostring(uid))
        end
        addedCards[index] = card
    end
    region:PlayGatherThenSortByUidList(addedCards, finalUidList, finalFaceUp,
            gatherDuration, spreadDuration, onComplete)
end


CardGameSystem.PlayShuffleByUidList = HL.Method(HL.String, HL.Table, HL.Table, HL.Number, HL.Opt(HL.Function)) << function(self, regionId, oldUidList, newUidList, duration, onComplete)
    local region = self.m_regions[regionId]
    if not region then
        logger.error("CardGameSystem.PlayShuffleByUidList: 找不到区域, regionId=" .. tostring(regionId))
        if onComplete then
            onComplete()
        end
        return
    end

    region:PlayShuffleByUidList(newUidList, duration, function()
        if onComplete then
            onComplete()
        end
    end)
end







CardGameSystem.RelayoutRegion = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, regionId, useAnim)
    local region = self.m_regions[regionId]
    if not region then
        logger.error("CardGameSystem.RelayoutRegion: 找不到区域, regionId=" .. tostring(regionId))
        return
    end
    region:Relayout(useAnim == true)
end







CardGameSystem.MoveTopCardToRegion = HL.Method(HL.String, HL.String, HL.Boolean, HL.Opt(HL.Boolean, HL.Function)) << function(self, fromRegionId, toRegionId, finalFaceUp, useAnim, onComplete)
    local fromRegion = self.m_regions[fromRegionId]
    local toRegion = self.m_regions[toRegionId]
    if not fromRegion or not toRegion then
        logger.error("CardGameSystem.MoveTopCardToRegion: 区域不存在, from=" .. tostring(fromRegionId) .. ", to=" .. tostring(toRegionId))
        if onComplete then
            onComplete()
        end
        return
    end

    local card = fromRegion:RemoveTop(true)
    if not card then
        logger.error("CardGameSystem.MoveTopCardToRegion: 源区域没有牌, from=" .. tostring(fromRegionId))
        if onComplete then
            onComplete()
        end
        return
    end

    local targetPose = toRegion:AddCard(card, nil, useAnim ~= false, false)
    local finish = function()
        if onComplete then
            onComplete()
        end
    end

    local useLift = fromRegionId ~= toRegionId
    if useAnim == false then
        card:SetFace(finalFaceUp)
        card:ApplyPose(targetPose)
        finish()
    else
        
        card:PlayMoveFlipToPose(targetPose, finalFaceUp, finish, useLift)
    end
end




CardGameSystem.MoveCardAtIndexToRegion = HL.Method(HL.String, HL.Number, HL.String, HL.Opt(HL.Number, HL.Boolean, HL.Boolean, HL.Function))
    << function(self, fromRegionId, fromIndex, toRegionId, toIndex, finalFaceUp, useAnim, onComplete)
    local fromRegion = self.m_regions[fromRegionId]
    local toRegion = self.m_regions[toRegionId]
    if not fromRegion or not toRegion then
        logger.error("CardGameSystem.MoveCardAtIndexToRegion: 区域不存在, from=" .. tostring(fromRegionId) .. ", to=" .. tostring(toRegionId))
        if onComplete then
            onComplete()
        end
        return
    end

    local card = fromRegion:RemoveAtIndex(fromIndex, true)
    if not card then
        logger.error("CardGameSystem.MoveCardAtIndexToRegion: 源区域 index 没有牌, from=" .. tostring(fromRegionId) .. ", index=" .. tostring(fromIndex))
        if onComplete then
            onComplete()
        end
        return
    end

    local maxInsertIndex = toRegion:GetCardCount() + 1
    local insertIndex = toIndex or maxInsertIndex
    insertIndex = lume.clamp(insertIndex, 1, maxInsertIndex)
    local targetPose
    targetPose, insertIndex = toRegion:AddCard(card, insertIndex, useAnim ~= false, false)
    local faceUp = finalFaceUp
    if faceUp == nil then
        faceUp = card.faceUp
    end

    local finish = function()
        if onComplete then
            onComplete()
        end
    end

    local useLift = fromRegionId ~= toRegionId
    if useAnim == false then
        card:SetFace(faceUp)
        card:ApplyPose(targetPose)
        finish()
    else
        
        card:PlayMoveFlipToPose(targetPose, faceUp, finish, useLift)
    end
end



CardGameSystem.MoveCardByUidToRegion = HL.Method(HL.Number, HL.String, HL.Opt(HL.Number, HL.Boolean, HL.Boolean, HL.Function))
        << function(self, uid, toRegionId, toIndex, finalFaceUp, useAnim, onComplete)
    local card = self.m_allCards[uid]
    if not card then
        logger.error("CardGameSystem.MoveCardByUidToRegion: 找不到牌, uid=" .. tostring(uid))
        if onComplete then
            onComplete()
        end
        return
    end
    if string.isEmpty(card.regionId) then
        logger.error("CardGameSystem.MoveCardByUidToRegion: 牌不在任何区域, uid=" .. tostring(uid))
        if onComplete then
            onComplete()
        end
        return
    end
    self:MoveCardAtIndexToRegion(card.regionId, card.indexInRegion, toRegionId, toIndex, finalFaceUp, useAnim, onComplete)
end



CardGameSystem.MoveCardsByUidToRegion = HL.Method(HL.Table, HL.String, HL.Opt(HL.Boolean, HL.Boolean, HL.Function)).Return(HL.Boolean)
        << function(self, uidList, toRegionId, finalFaceUp, useAnim, onComplete)
    local toRegion = self.m_regions[toRegionId]
    if toRegion == nil or uidList == nil or #uidList <= 0 then
        return false
    end

    local cards = {}
    local uidSet = {}
    local sourceGroups = {}
    for _, uid in ipairs(uidList) do
        local card = self.m_allCards[uid]
        if card == nil or string.isEmpty(card.regionId) or uidSet[uid]
                or card.regionId == toRegionId then
            return false
        end
        uidSet[uid] = true
        cards[#cards + 1] = card
        local group = sourceGroups[card.regionId]
        if group == nil then
            group = { region = self.m_regions[card.regionId], cards = {} }
            sourceGroups[card.regionId] = group
        end
        if group.region == nil then
            return false
        end
        group.cards[#group.cards + 1] = card
    end

    for _, group in pairs(sourceGroups) do
        if not group.region:RemoveCards(group.cards, useAnim ~= false) then
            return false
        end
    end
    local targetPoses = toRegion:AddCards(cards, useAnim ~= false, false)
    if targetPoses == nil then
        return false
    end

    local pending = #cards
    local finishOne = function()
        pending = pending - 1
        if pending <= 0 and onComplete ~= nil then
            onComplete()
        end
    end
    for index, card in ipairs(cards) do
        local faceUp = finalFaceUp
        if faceUp == nil then
            faceUp = card.faceUp
        end
        if useAnim == false then
            card:SetFace(faceUp)
            card:ApplyPose(targetPoses[index])
            finishOne()
        else
            card:PlayMoveFlipToPose(targetPoses[index], faceUp, finishOne, true)
        end
    end
    return true
end






CardGameSystem.TryAcceptGuide = HL.Method(HL.String) << function(self, gameId)
    local enterPlayRoomInfo = GameInstance.player.multiplayerMatchSystem.enterPlayRoom
    if enterPlayRoomInfo == nil or enterPlayRoomInfo.playRoomKind
            ~= CS.Beyond.Gameplay.MultiplayerMatchSystem.PlayRoomKind.NewbieGuide then
        return
    end
    if MultiplayerUtils.isNewbieGuideDone(gameId) then
        return
    end
    GameInstance.player.guide:AcceptGameplayGuide(gameId)
    self.m_isGuideAccepted = true
end



CardGameSystem.StopGuide = HL.Method() << function(self)
    if not self.m_isGuideAccepted or string.isEmpty(self.m_gameId) then
        self.m_gameId = ""
        return
    end
    GameInstance.player.guide:StopGameplayGuide(self.m_gameId)
    self.m_gameId = ""
    self.m_isGuideAccepted = false
end



HL.Commit(CardGameSystem)
return CardGameSystem
