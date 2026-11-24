


local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')


local SHUFFLE_LAUNCH_INTERVAL = 0.15

local SHUFFLE_OUT_DISTANCE_MIN = 0.3
local SHUFFLE_OUT_DISTANCE_MAX = 0.5
local SHUFFLE_OUT_LIFT = 0.04

CardGameRegion = HL.Class('CardGameRegion')



CardGameRegion.m_id = HL.Field(HL.String) << ""
CardGameRegion.m_root = HL.Field(Transform)
CardGameRegion.m_layout = HL.Field(CS.Beyond.UI.CardGamePokerLayout)
CardGameRegion.m_cards = HL.Field(HL.Table)

CardGameRegion.m_shuffleQueue = HL.Field(CardGameAnimQueue)
CardGameRegion.m_shuffleIntervalTimer = HL.Field(HL.Number) << -1

CardGameRegion.m_shuffleFlyingCount = HL.Field(HL.Number) << 0
CardGameRegion.m_onShuffleCardsBack = HL.Field(HL.Function)

CardGameRegion.m_relayoutShiftedCards = HL.Field(HL.Boolean) << false





CardGameRegion.CardGameRegion = HL.Constructor(HL.String, CS.Beyond.UI.CardGamePokerLayout) << function(self, id, layout)
    self.m_id = id
    self.m_layout = layout
    self.m_root = layout.transform
    self.m_cards = {}
    self.m_shuffleQueue = CardGameAnimQueue()
end






CardGameRegion.Relayout = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Table) << function(self, useAnim)
    return self:_RelayoutInternal(useAnim == true, nil)
end



CardGameRegion.RebindLayout = HL.Method(CS.Beyond.UI.CardGamePokerLayout) << function(self, layout)
    self.m_layout = layout
    self.m_root = layout.transform
    layout:ClearCache()
    
    for _, card in ipairs(self.m_cards) do
        card.transform:SetParent(self.m_root, true)
    end
    self:_RelayoutInternal(false, nil)
end

CardGameRegion.SetRelayoutShiftedCards = HL.Method(HL.Boolean) << function(self, enable)
    self.m_relayoutShiftedCards = enable
end



CardGameRegion._RelayoutInternal = HL.Method(HL.Boolean, HL.Any, HL.Opt(HL.Number)).Return(HL.Table)
        << function(self, useAnim, skipCard, shiftFrom)
    if IsNull(self.m_layout) then
        logger.error("CardGameRegion.Relayout: region 没有布局, id=" .. tostring(self.m_id))
        return {}
    end
    local changedIndices = self:_UpdatePoses(1)
    for i = 1, #changedIndices do
        self:_MoveCardAtIndexToPose(changedIndices[i], useAnim, skipCard)
    end
    if self.m_relayoutShiftedCards and shiftFrom ~= nil then
        
        local changedPos = 1
        for cardIndex = math.max(shiftFrom, 1), #self.m_cards do
            while changedIndices[changedPos] ~= nil and changedIndices[changedPos] < cardIndex do
                changedPos = changedPos + 1
            end
            if changedIndices[changedPos] ~= cardIndex then
                self:_MoveCardAtIndexToPose(cardIndex, useAnim, skipCard)
            end
        end
    end
    return changedIndices
end

CardGameRegion._MoveCardAtIndexToPose = HL.Method(HL.Number, HL.Boolean, HL.Any)
        << function(self, cardIndex, useAnim, skipCard)
    local card = self.m_cards[cardIndex]
    local pose = self:GetPose(cardIndex)
    if card and card ~= skipCard and pose then
        if useAnim == true then
            card:PlayMoveToPose(pose, nil, false)
        else
            card:ApplyPose(pose)
        end
    end
end







CardGameRegion.AddCard = HL.Method(HL.Any, HL.Opt(HL.Number, HL.Boolean, HL.Boolean)).Return(HL.Table, HL.Number) << function(self, card, index, useAnim, relayoutAddedCard)
    if not card then
        logger.error("CardGameRegion.AddCard: card is nil, regionId=" .. tostring(self.m_id))
        return {}, 0
    end
    local insertIndex = self:_InsertCard(card, index)
    local skipCard = nil
    if relayoutAddedCard == false then
        skipCard = card
    end
    self:_RelayoutInternal(useAnim == true, skipCard, insertIndex)
    return self:GetPose(insertIndex), insertIndex
end



CardGameRegion.AddCards = HL.Method(HL.Table, HL.Opt(HL.Boolean, HL.Boolean)).Return(HL.Opt(HL.Table)) << function(self, cards, useAnim, relayoutAddedCards)
    if IsNull(self.m_layout) or cards == nil or #cards <= 0 then
        return nil
    end
    local addedSet = {}
    for _, card in ipairs(cards) do
        if card == nil or not string.isEmpty(card.regionId) or addedSet[card] then
            logger.error("CardGameRegion.AddCards: invalid detached card, regionId=" .. tostring(self.m_id))
            return nil
        end
        addedSet[card] = true
    end
    for _, card in ipairs(cards) do
        self.m_cards[#self.m_cards + 1] = card
    end
    self:_RefreshCardIndices()

    local changedIndices = self:_UpdatePoses(1)
    for _, cardIndex in ipairs(changedIndices) do
        local card = self.m_cards[cardIndex]
        if card ~= nil and (relayoutAddedCards == true or not addedSet[card]) then
            local pose = self:GetPose(cardIndex)
            if useAnim == true then
                card:PlayMoveToPose(pose, nil, false)
            else
                card:ApplyPose(pose)
            end
        end
    end

    local poses = {}
    for index, card in ipairs(cards) do
        poses[index] = self:GetPose(card.indexInRegion)
    end
    return poses
end


CardGameRegion.RemoveCards = HL.Method(HL.Table, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, cards, useAnim)
    if cards == nil or #cards <= 0 then
        return false
    end
    local removeSet = {}
    for _, card in ipairs(cards) do
        if card == nil or card.regionId ~= self.m_id or removeSet[card] then
            return false
        end
        removeSet[card] = true
    end
    local minRemovedIndex = nil
    for index = #self.m_cards, 1, -1 do
        local card = self.m_cards[index]
        if removeSet[card] then
            table.remove(self.m_cards, index)
            card.regionId = ""
            card.indexInRegion = 0
            card:SetInteractionSortingOrder(0)
            minRemovedIndex = index
        end
    end
    self:_RefreshCardIndices()
    self:_RelayoutInternal(useAnim == true, nil, minRemovedIndex)
    return true
end


CardGameRegion.RemoveCard = HL.Method(HL.Any, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, card, useAnim)
    if not card then
        return false
    end
    for i = #self.m_cards, 1, -1 do
        if self.m_cards[i] == card then
            table.remove(self.m_cards, i)
            card.regionId = ""
            card.indexInRegion = 0
            card:SetInteractionSortingOrder(0)
            self:_RefreshCardIndices()
            self:_RelayoutInternal(useAnim == true, nil, i)
            return true
        end
    end
    return false
end


CardGameRegion.GetCardAtIndex = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, index)
    if index < 1 or index > #self.m_cards then
        return nil
    end
    return self.m_cards[index]
end

CardGameRegion.GetRoot = HL.Method().Return(Transform) << function(self)
    return self.m_root
end


CardGameRegion.GetLayout = HL.Method().Return(CS.Beyond.UI.CardGamePokerLayout) << function(self)
    return self.m_layout
end


CardGameRegion.GetPose = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, index)
    if IsNull(self.m_layout) then
        return nil
    end
    local ok, pose = self.m_layout:TryGetPose(index)
    if not ok then
        return nil
    end
    return self:_PoseToLuaTable(pose)
end



CardGameRegion.GetGatherStackPose = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, index)
    if IsNull(self.m_layout) or self.m_layout.layoutData == nil then
        return nil
    end
    local layoutData = self.m_layout.layoutData
    if self.m_layout.layoutType == CS.Beyond.UI.CardGamePokerLayout.ELayoutType.Hand then
        return self:_PoseToLuaTable(layoutData:BuildShuffleGatherPose(self.m_root, index))
    end
    local stackOffset = layoutData.stackOffset or Vector3.zero
    local basePosition = layoutData.basePosition or Vector3.zero
    local baseEuler = layoutData.baseEuler or Vector3.zero
    local baseScale = layoutData.baseScale or Vector3.one
    return {
        root = self.m_root,
        localPosition = basePosition + stackOffset * (index - 1),
        localEulerAngles = baseEuler,
        localScale = baseScale,
    }
end



CardGameRegion.RemoveAtIndex = HL.Method(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Opt(HL.Any)) << function(self, index, useAnim)
    if index < 1 or index > #self.m_cards then
        return nil
    end
    local card = table.remove(self.m_cards, index)
    if card then
        card.regionId = ""
        card.indexInRegion = 0
        card:SetInteractionSortingOrder(0)
        self:_RefreshCardIndices()
        self:_RelayoutInternal(useAnim == true, nil, index)
    end
    return card
end


CardGameRegion.RemoveTop = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Opt(HL.Any)) << function(self, useAnim)
    local card = self.m_cards[#self.m_cards]
    if card then
        table.remove(self.m_cards, #self.m_cards)
        card.regionId = ""
        card.indexInRegion = 0
        card:SetInteractionSortingOrder(0)
        self:_RefreshCardIndices()
        self:Relayout(useAnim == true)
    end
    return card
end


CardGameRegion.PeekTop = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_cards[#self.m_cards]
end


CardGameRegion.GetCardCount = HL.Method().Return(HL.Number) << function(self)
    return #self.m_cards
end


CardGameRegion.ClearCards = HL.Method() << function(self)
    self:_StopShuffle()
    for i = 1, #self.m_cards do
        self.m_cards[i] = nil
    end
    if not IsNull(self.m_layout) then
        self.m_layout:ClearCache()
    end
end






CardGameRegion.BuildAddedCardPreviewPose = HL.Method(HL.Number, HL.Number).Return(HL.Table)
        << function(self, index, cardCount)
    return self:_PoseToLuaTable(self.m_layout.layoutData:BuildAddedCardPreviewPose(self.m_root, index, cardCount))
end


CardGameRegion.PlayGatherThenSortByUidList = HL.Method(HL.Table, HL.Table, HL.Boolean,
        HL.Number, HL.Number, HL.Function)
        << function(self, addedCards, uidList, finalFaceUp,
        gatherDuration, spreadDuration, onComplete)
    local finalCardCount = #self.m_cards + #addedCards
    if #uidList ~= finalCardCount then
        error("CardGameRegion.PlayGatherThenSortByUidList: uid 数量不匹配, regionId="
                .. self.m_id .. ", expected=" .. tostring(finalCardCount)
                .. ", actual=" .. tostring(#uidList))
    end

    local uidToCard = {}
    for _, card in ipairs(self.m_cards) do
        if card.regionId ~= self.m_id or uidToCard[card.uid] ~= nil then
            error("CardGameRegion.PlayGatherThenSortByUidList: 当前区域牌非法, regionId="
                    .. self.m_id .. ", uid=" .. tostring(card.uid))
        end
        uidToCard[card.uid] = card
    end
    for _, card in ipairs(addedCards) do
        if not string.isEmpty(card.regionId) or uidToCard[card.uid] ~= nil then
            error("CardGameRegion.PlayGatherThenSortByUidList: 新增牌不是 detached 或 uid 重复, regionId="
                    .. self.m_id .. ", uid=" .. tostring(card.uid))
        end
        uidToCard[card.uid] = card
    end

    local finalIndexByUid = {}
    for index, uid in ipairs(uidList) do
        if uidToCard[uid] == nil or finalIndexByUid[uid] ~= nil then
            error("CardGameRegion.PlayGatherThenSortByUidList: 最终顺序包含未知或重复 uid, regionId="
                    .. self.m_id .. ", uid=" .. tostring(uid))
        end
        finalIndexByUid[uid] = index
    end

    for _, card in ipairs(addedCards) do
        self.m_cards[#self.m_cards + 1] = card
        card.regionId = self.m_id
    end
    self:_RefreshCardIndices()

    if finalCardCount <= 0 then
        onComplete()
        return
    end

    local playSpread = function()
        local reorderedCards = {}
        for index, uid in ipairs(uidList) do
            reorderedCards[index] = uidToCard[uid]
        end
        self.m_cards = reorderedCards
        self:_RefreshCardIndices()
        self:_UpdatePoses(1)

        local pendingCount = finalCardCount
        local finishOne = function()
            pendingCount = pendingCount - 1
            if pendingCount <= 0 then
                onComplete()
            end
        end
        for index, card in ipairs(self.m_cards) do
            card:PlayMoveToPose(self:GetPose(index),
                    finishOne, false, spreadDuration)
        end
    end

    local pendingGatherCount = finalCardCount
    local finishGatherOne = function()
        pendingGatherCount = pendingGatherCount - 1
        if pendingGatherCount <= 0 then
            playSpread()
        end
    end
    for _, card in ipairs(self.m_cards) do
        local gatherPose = self:_PoseToLuaTable(self.m_layout.layoutData:BuildShuffleGatherPose(
                self.m_root, finalIndexByUid[card.uid]))
        card:PlayMoveFlipToPose(gatherPose, finalFaceUp,
                finishGatherOne, false, gatherDuration)
    end
end



CardGameRegion.PlayShuffleByUidList = HL.Method(HL.Table, HL.Opt(HL.Number, HL.Function)) << function(self, uidList, duration, onComplete)
    local movedIndices = self:_ApplyShuffleOrderByUidList(uidList)

    if #self.m_cards <= 0 or not movedIndices or #movedIndices <= 0 then
        if onComplete then
            onComplete()
        end
        return
    end

    local queue = self.m_shuffleQueue
    local lastOrder = #movedIndices
    for order, cardIndex in ipairs(movedIndices) do
        local card = self.m_cards[cardIndex]
        local finalPose = self:GetPose(cardIndex)
        queue:Enqueue(function(finish)
            self:_PlayShuffleCardOutAndBack(card, finalPose)
            if order < lastOrder then
                self:_WaitShuffleLaunchInterval(finish)
            else
                finish()
            end
        end)
    end
    queue:Enqueue(function(finish)
        self:_WaitShuffleCardsBack(finish)
    end)
    if onComplete then
        queue:EnqueueFinallyAction(onComplete)
    end
end


CardGameRegion._PlayShuffleCardOutAndBack = HL.Method(HL.Any, HL.Table) << function(self, card, finalPose)
    self.m_shuffleFlyingCount = self.m_shuffleFlyingCount + 1
    card:PlayMoveToPose(self:_RandomShuffleOutPose(finalPose), function()
        card:PlayMoveToPose(finalPose, function()
            self:_OnShuffleCardBack()
        end, false)
    end, false)
end

CardGameRegion._OnShuffleCardBack = HL.Method() << function(self)
    self.m_shuffleFlyingCount = math.max(0, self.m_shuffleFlyingCount - 1)
    if self.m_shuffleFlyingCount > 0 or self.m_onShuffleCardsBack == nil then
        return
    end
    local onBack = self.m_onShuffleCardsBack
    self.m_onShuffleCardsBack = nil
    onBack()
end

CardGameRegion._WaitShuffleLaunchInterval = HL.Method(HL.Function) << function(self, finish)
    self.m_shuffleIntervalTimer = TimerManager:StartTimer(SHUFFLE_LAUNCH_INTERVAL, function()
        self.m_shuffleIntervalTimer = -1
        finish()
    end, false, self)
end

CardGameRegion._WaitShuffleCardsBack = HL.Method(HL.Function) << function(self, finish)
    if self.m_shuffleFlyingCount <= 0 then
        finish()
        return
    end
    self.m_onShuffleCardsBack = finish
end


CardGameRegion._StopShuffle = HL.Method() << function(self)
    self.m_shuffleQueue:Clear(false, false)
    if self.m_shuffleIntervalTimer >= 0 then
        TimerManager:ClearTimer(self.m_shuffleIntervalTimer)
        self.m_shuffleIntervalTimer = -1
    end
    self.m_shuffleFlyingCount = 0
    self.m_onShuffleCardsBack = nil
end


CardGameRegion._ApplyShuffleOrderByUidList = HL.Method(HL.Table).Return(HL.Opt(HL.Table)) << function(self, uidList)
    if #uidList ~= #self.m_cards then
        logger.error("CardGameRegion._ApplyShuffleOrderByUidList: uid 数量不匹配, regionId=" .. tostring(self.m_id))
        return nil
    end

    local shuffleMovedIndices = {}
    local uidToCard = {}
    for i = 1, #self.m_cards do
        local card = self.m_cards[i]
        if card then
            uidToCard[card.uid] = card
        end
    end
    for i = 1, #uidList do
        local uid = uidList[i]
        local card = uidToCard[uid]
        if not card then
            logger.error("CardGameRegion._ApplyShuffleOrderByUidList: uid 不在当前区域或重复, regionId=" .. tostring(self.m_id) .. ", uid=" .. tostring(uid))
            return nil
        end
        if card.indexInRegion ~= i then
            shuffleMovedIndices[#shuffleMovedIndices + 1] = i
        end
        self.m_cards[i] = card
        uidToCard[uid] = nil
    end
    self:_RefreshCardIndices()
    local movedSet = {}
    for _, index in ipairs(shuffleMovedIndices) do
        movedSet[index] = true
    end
    for _, index in ipairs(self:_UpdatePoses(1)) do
        if not movedSet[index] then
            shuffleMovedIndices[#shuffleMovedIndices + 1] = index
            movedSet[index] = true
        end
    end
    return shuffleMovedIndices
end



CardGameRegion._RandomShuffleOutPose = HL.Method(HL.Table).Return(HL.Table) << function(self, finalPose)
    local angle = math.random() * math.pi * 2
    local distance = SHUFFLE_OUT_DISTANCE_MIN + (SHUFFLE_OUT_DISTANCE_MAX - SHUFFLE_OUT_DISTANCE_MIN) * math.random()
    local pose = {}
    pose.root = finalPose.root
    pose.localPosition = finalPose.localPosition
            + Vector3(math.cos(angle) * distance, SHUFFLE_OUT_LIFT, math.sin(angle) * distance)
    pose.localEulerAngles = finalPose.localEulerAngles + Vector3(0, math.random(-25, 25), 0)
    pose.localScale = finalPose.localScale
    return pose
end






CardGameRegion._InsertCard = HL.Method(HL.Any, HL.Opt(HL.Number)).Return(HL.Number) << function(self, card, index)
    local maxInsertIndex = #self.m_cards + 1
    local insertIndex = index or maxInsertIndex
    insertIndex = lume.clamp(insertIndex, 1, maxInsertIndex)
    table.insert(self.m_cards, insertIndex, card)
    self:_RefreshCardIndices()
    return insertIndex
end


CardGameRegion._RefreshCardIndices = HL.Method() << function(self)
    for i = 1, #self.m_cards do
        local card = self.m_cards[i]
        card.regionId = self.m_id
        card.indexInRegion = i
        card:SetInteractionSortingOrder(i)
    end
end


CardGameRegion._UpdatePoses = HL.Method(HL.Opt(HL.Number)).Return(HL.Table) << function(self, startIndex)
    local changedIndices = {}
    if IsNull(self.m_layout) then
        return changedIndices
    end
    local csList = self.m_layout:UpdatePoses(#self.m_cards, startIndex or 1)
    if csList == nil then
        return changedIndices
    end
    for i = 0, csList.Count - 1 do
        changedIndices[#changedIndices + 1] = csList[i]
    end
    return changedIndices
end

CardGameRegion._PoseToLuaTable = HL.Method(HL.Any).Return(HL.Opt(HL.Table)) << function(self, pose)
    if pose == nil then
        return nil
    end
    return {
        root = pose.root,
        localPosition = pose.localPosition,
        localEulerAngles = pose.localEulerAngles,
        localScale = pose.localScale,
    }
end



HL.Commit(CardGameRegion)
return CardGameRegion
