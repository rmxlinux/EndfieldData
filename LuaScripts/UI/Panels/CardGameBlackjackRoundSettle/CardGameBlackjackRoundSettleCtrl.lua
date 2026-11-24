local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')
local PANEL_ID = PanelId.CardGameBlackjackRoundSettle
local DEFAULT_BUSINESS_CARD_TOPIC_ID = "business_card_topic_normal_2"

CardGameBlackjackRoundSettleCtrl = HL.Class('CardGameBlackjackRoundSettleCtrl', uiCtrl.UICtrl)







CardGameBlackjackRoundSettleCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED] = '_OnPlayRoomInfoChanged',
}


CardGameBlackjackRoundSettleCtrl.m_arg = HL.Field(HL.Any)
CardGameBlackjackRoundSettleCtrl.m_playerRankCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackRoundSettleCtrl.m_animQueue = HL.Field(CardGameAnimQueue)




CardGameBlackjackRoundSettleCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_InitUI()
    self:RefreshRankUI(arg)
    self:PlaySettleAndRankAni(self.m_arg)
end

CardGameBlackjackRoundSettleCtrl._InitUI = HL.Method() << function(self)
    self.m_playerRankCellCache = UIUtils.genCellCache(self.view.rankNode.playerRankCell)
    self.m_animQueue = CardGameAnimQueue()
end


CardGameBlackjackRoundSettleCtrl.PlaySettleAndRankAni = HL.Method(HL.Any) << function(self, arg)
    local queue = self.m_animQueue
    local config = self.view.config
    queue:Enqueue(function(finish)
        self:_WaitSettleAni(config.START_SETTLE_ANI_TIME, finish)
    end)
    queue:Enqueue(function(finish)
        self:_PlayPlayerRankCellInAni(finish)
    end)
    
    if self:_HasExtraPointSettleAni(arg.settleInfos) then
        queue:Enqueue(function(finish)
            self:_PlayExtraPointAddAni(finish)
        end)
        queue:Enqueue(function(finish)
            self:_WaitSettleAni(config.SETTLE_ANI_WAIT_TIME, finish)
        end)
    end
    
    queue:Enqueue(function(finish)
        self:_PlayHpSettleAni(finish)
    end)
    queue:Enqueue(function(finish)
        self:_WaitSettleAni(config.SETTLE_ANI_WAIT_TIME, finish)
    end)
    
    queue:Enqueue(function(finish)
        self:_PlayMoneyChangeAni()
        self:_RefreshFinalPhaseState(arg)
        CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.StartRoundSettle)
        self:StartCountDown(config.FINISH_RANK_PHASE_WAIT_TIME, function()
            Notify(MessageConst.HIDE_ITEM_TIPS)
            self:PlayAnimationOutWithCallback(function()
                if self.m_arg.roundSettleFinish then
                    self.m_arg.roundSettleFinish()
                end
            end)
        end)
        finish()
    end)
end



CardGameBlackjackRoundSettleCtrl.RefreshRankUI = HL.Method(HL.Any) << function(self, arg)
    
    local rankNode = self.view.rankNode
    local selfSettleInfo = arg.selfSettleInfo   
    
    CardGameBlackjackUtils.InitGoldMoneyCell(rankNode.moneyCell, selfSettleInfo.moneyNum - selfSettleInfo.moneyDelta)
    rankNode.moneyValueChangeTipsNode.gameObject:SetActive(false)
    rankNode.roundTitleTxt.text = string.format(Language.LUA_CARD_GAME_BLACKJACK_ROUND_SETTLE_TITLE, arg.curRound)
    rankNode.phaseStateNode:SetState("Settling")
    
    self:_SortSettleInfosForFinal(arg.settleInfos)
    self.m_playerRankCellCache:Refresh(#arg.settleInfos, function(cell, index)
        local playerSettleInfo = arg.settleInfos[index]
        cell.gameObject.name = string.format("GuideSettle_%d", index)
        cell.temp_settleInfo = playerSettleInfo
        
        cell.animationWrapper:SampleToInAnimationBegin()
        local isGameOutBefore = self:_IsGameOutBefore(playerSettleInfo)
        
        cell.gameState:SetState(isGameOutBefore and "GameOut" or "Settling")
        
        cell.rankTxt.text = playerSettleInfo.displayRank
        cell.rankSuffixTxt.text = CardGameUtils.GetOrdinalSuffix(playerSettleInfo.displayRank)
        
        cell.pointTxt.text = playerSettleInfo.point
        if self:_NeedPlayExtraPointAni(playerSettleInfo) then
            cell.extraPointTxt.text = CardGameUtils.GetNumDeltaText(playerSettleInfo.extraPoint)
            cell.gameState:SetState("ShowExtraPoint")
        else
            cell.gameState:SetState("HideExtraPoint")
        end
        
        local handZoneCardInfos = playerSettleInfo.handZoneCardInfos
        if cell.temp_pokerCellCache == nil then
            cell.temp_pokerCellCache = UIUtils.genCellCache(cell.pokerCell)
        end
        cell.temp_pokerCellCache:Refresh(#handZoneCardInfos, function(pokerCell, pokerCellIndex)
            local pokerInfo = handZoneCardInfos[pokerCellIndex]
            pokerCell:SetCardSuitRankStyle(pokerInfo.suit, pokerInfo.rank, pokerInfo.style)
        end)
        
        local playerInfoCell = cell.playerInfoCell
        playerInfoCell.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, playerSettleInfo.seatIndex))
        
        local hpBefore = self:_GetHpBeforeSettle(playerSettleInfo)
        playerInfoCell.curHpTxt.text = hpBefore
        playerInfoCell.maxHpTxt.text = "/" .. playerSettleInfo.maxHp
        playerInfoCell.stateController:SetState("HideHpDelta")
        if playerInfoCell.temp_hpCellCache == nil then
            playerInfoCell.temp_hpCellCache = UIUtils.genCellCache(playerInfoCell.hpCell)
        end
        playerInfoCell.temp_hpCellCache:Refresh(playerSettleInfo.maxHp, function(hpCell, hpIndex)
            
            hpCell.stateController:SetState((hpIndex > (playerSettleInfo.maxHp - hpBefore)) and "Normal" or "Empty")
        end)
        
        cell.moneyDeltaTxt.text = CardGameUtils.GetNumDeltaText(playerSettleInfo.moneyDelta)
        self:_RefreshPlayerInfoUIBasic(playerInfoCell, playerSettleInfo)
        
        local topicId = playerSettleInfo.displayInfo.cardTopicId
        cell.themeImg:LoadSprite(UIConst.UI_BUSINESS_CARD_ICON_PATH,
                string.isEmpty(topicId) and DEFAULT_BUSINESS_CARD_TOPIC_ID or topicId)
    end)
end


CardGameBlackjackRoundSettleCtrl._RefreshFinalPhaseState = HL.Method(HL.Any) << function(self, arg)
    local rankNode = self.view.rankNode
    local showExitBtn = false
    if arg.isGameOver then
        
        rankNode.phaseStateNode:SetState("Final")
    elseif arg.isWatch then
        
        rankNode.phaseStateNode:SetState("Watch")
        showExitBtn = true
    else
        
        rankNode.phaseStateNode:SetState("Shop")
    end
    rankNode.exitBtn.onClick:RemoveAllListeners()
    if showExitBtn then
        rankNode.exitBtn.onClick:AddListener(function()
            LuaSystemManager.cardGameBlackjackSystem:RequestLeavePlayRoom(true)
        end)
    end
    rankNode.phaseStateNode:SetState(showExitBtn and "ShowExitBtn" or "HideExitBtn")
end



CardGameBlackjackRoundSettleCtrl._RefreshPlayerInfoUIBasic = HL.Method(HL.Any, HL.Any) << function(self, playerInfoNode, playerSettleInfo)
    self:_RefreshPlayerTag(playerInfoNode, playerSettleInfo)
    
    CardGameUtils.InitCommonPlayerHead(playerInfoNode.playerHead, playerSettleInfo.displayInfo)
    local playerHead = playerInfoNode.playerHead
    if playerSettleInfo.displayInfo.isAI then
        playerHead.view.levelTag.gameObject:SetActiveIfNecessary(false)
        playerHead.view.seasonTag.gameObject:SetActiveIfNecessary(false)
        playerHead.view.lineImage.gameObject:SetActiveIfNecessary(false)
    else
        playerHead:UpdateActivityState()
    end
end


CardGameBlackjackRoundSettleCtrl._RefreshPlayerTag = HL.Method(HL.Any, HL.Table) << function(self, playerInfoNode, playerSettleInfo)
    if playerSettleInfo.isSelf then
        playerInfoNode.stateController:SetState("Self")
    elseif CardGameUtils.IsMemberShowAI(playerSettleInfo.memberId) then
        playerInfoNode.stateController:SetState("Ai")
    else
        playerInfoNode.stateController:SetState("None")
    end
end


CardGameBlackjackRoundSettleCtrl._RefreshPlayerTagsByMemberId = HL.Method(HL.Opt(HL.Any)) << function(self, memberId)
    local cache = self.m_playerRankCellCache
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        local info = cell.temp_settleInfo
        if info and (memberId == nil or info.memberId == memberId) then
            self:_RefreshPlayerTag(cell.playerInfoCell, info)
        end
    end
end

CardGameBlackjackRoundSettleCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    self:_RefreshPlayerTagsByMemberId(unpack(arg))
end

CardGameBlackjackRoundSettleCtrl._OnPlayRoomInfoChanged = HL.Method() << function(self)
    self:_RefreshPlayerTagsByMemberId()
end


CardGameBlackjackRoundSettleCtrl._GetSettleSortGroup = HL.Method(HL.Table).Return(HL.Number) << function(self, info)
    if self:_IsGameOutBefore(info) then
        return 2
    end
    if info.isBust then
        return 1
    end
    return 0
end


CardGameBlackjackRoundSettleCtrl._IsGameOutBefore = HL.Method(HL.Table).Return(HL.Boolean) << function(self, info)
    local curRound = self.m_arg.curRound
    return info.gameOutRound ~= 0 and info.gameOutRound < curRound
end


CardGameBlackjackRoundSettleCtrl._SortSettleInfosForFinal = HL.Method(HL.Table) << function(self, settleInfos)
    table.sort(settleInfos, function(a, b)
        local groupA = self:_GetSettleSortGroup(a)
        local groupB = self:_GetSettleSortGroup(b)
        if groupA ~= groupB then
            return groupA < groupB
        end
        if groupA == 2 then
            return a.memberId < b.memberId
        end
        if a.displayRank ~= b.displayRank then
            return a.displayRank < b.displayRank
        end
        local finalPointA = a.point + a.extraPoint
        local finalPointB = b.point + b.extraPoint
        if finalPointA ~= finalPointB then
            return finalPointA > finalPointB
        end
        return a.memberId < b.memberId
    end)
end


CardGameBlackjackRoundSettleCtrl._NeedPlayExtraPointAni = HL.Method(HL.Table).Return(HL.Boolean) << function(self, info)
    return self:_GetSettleSortGroup(info) == 0 and (info.extraPoint or 0) ~= 0
end


CardGameBlackjackRoundSettleCtrl._GetHpBeforeSettle = HL.Method(HL.Table).Return(HL.Number) << function(self, info)
    return math.min(info.hp + info.hpDelta, info.maxHp)
end

CardGameBlackjackRoundSettleCtrl._HasExtraPointSettleAni = HL.Method(HL.Table).Return(HL.Boolean) << function(self, settleInfos)
    for i = 1, #settleInfos do
        if self:_NeedPlayExtraPointAni(settleInfos[i]) then
            return true
        end
    end
    return false
end



CardGameBlackjackRoundSettleCtrl._WaitSettleAni = HL.Method(HL.Number, HL.Function) << function(self, duration, nextFn)
    if duration <= 0 then
        nextFn()
        return
    end
    local elapsed = 0
    local updateKey = -1
    updateKey = self:_StartUpdate(function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < duration then
            return
        end
        self:_RemoveUpdate(updateKey)
        nextFn()
    end)
end


CardGameBlackjackRoundSettleCtrl._PlayPlayerRankCellInAni = HL.Method(HL.Function) << function(self, finish)
    local cache = self.m_playerRankCellCache
    local count = cache:GetCount()
    if count <= 0 then
        finish()
        return
    end
    local interval = self.view.config.PLAYER_RANK_CELL_IN_INTERVAL
    for i = 1, count do
        local cell = cache:Get(i)
        local onPlayEnd = i == count and finish or nil
        self:_StartTimer((i - 1) * interval, function()
            cell.animationWrapper:PlayInAnimation(onPlayEnd)
        end)
    end
end


CardGameBlackjackRoundSettleCtrl._PlayExtraPointAddAni = HL.Method(HL.Function) << function(self, finish)
    local cache = self.m_playerRankCellCache
    local duration = self.view.config.EXTRA_POINT_ADD_ANI_DURATION
    local items = {}
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        local info = cell.temp_settleInfo
        if info and self:_NeedPlayExtraPointAni(info) then
            items[#items + 1] = {
                cell = cell,
                startPoint = info.point,
                finalPoint = info.point + info.extraPoint,
            }
        end
    end
    if #items <= 0 then
        finish()
        return
    end
    local function applyPoint(t)
        for i = 1, #items do
            local item = items[i]
            local value = item.startPoint + (item.finalPoint - item.startPoint) * t
            item.cell.pointTxt.text = lume.round(value)
        end
    end
    local function onEnd()
        for i = 1, #items do
            local item = items[i]
            item.cell.pointTxt.text = item.finalPoint
            item.cell.extraPointAniWrapper:PlayOutAnimation()
        end
        finish()
    end
    if duration <= 0 then
        onEnd()
        return
    end
    local elapsed = 0
    local updateKey = -1
    updateKey = self:_StartUpdate(function(deltaTime)
        elapsed = elapsed + deltaTime
        local t = math.min(elapsed / duration, 1)
        applyPoint(t)
        if t >= 1 then
            self:_RemoveUpdate(updateKey)
            onEnd()
        end
    end)
end



CardGameBlackjackRoundSettleCtrl._PlayHpSettleAni = HL.Method(HL.Function) << function(self, finish)
    local hasRegisteredFinish = false
    local cache = self.m_playerRankCellCache
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        local info = cell.temp_settleInfo
        if not self:_IsGameOutBefore(info) then
            local isNewGameOut = info.gameOutRound ~= 0
            if isNewGameOut and info.isBust then
                cell.gameState:SetState("BustAndNewGameOut")
            elseif isNewGameOut then
                cell.gameState:SetState("NewGameOut")
            elseif info.isBust then
                cell.gameState:SetState("Bust")
            else
                cell.gameState:SetState("Normal")
            end
            local playerInfoCell = cell.playerInfoCell
            playerInfoCell.curHpTxt.text = info.hp
            if info.hpDelta == 0 then
                playerInfoCell.stateController:SetState("NoHpDelta")
            else
                playerInfoCell.stateController:SetState("SubHpDelta")
                playerInfoCell.hpDeltaTxt.text = "-" .. info.hpDelta
            end
            
            local hpCellCache = playerInfoCell.temp_hpCellCache
            local lostStart = info.maxHp - self:_GetHpBeforeSettle(info) + 1
            local lostEnd = info.maxHp - info.hp
            for hpIndex = lostStart, lostEnd do
                local hpCell = hpCellCache:Get(hpIndex)
                hpCell.stateController:SetState("Empty")
                if hasRegisteredFinish then
                    hpCell.animationWrapper:PlayOutAnimation()
                else
                    hasRegisteredFinish = true
                    hpCell.animationWrapper:PlayOutAnimation(finish)
                end
            end
        end
    end
    if not hasRegisteredFinish then
        finish()
    end
end


CardGameBlackjackRoundSettleCtrl._PlayMoneyChangeAni = HL.Method() << function(self)
    local rankNode = self.view.rankNode
    local selfSettleInfo = self.m_arg.selfSettleInfo
    local moneyDelta = selfSettleInfo.moneyDelta
    if moneyDelta == 0 then
        return
    end
    local valueChangeType = moneyDelta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    CardGameBlackjackUtils.PlayChangeValueTips(self, rankNode.moneyValueChangeTipsNode, valueChangeType, math.abs(moneyDelta), function()
        CardGameBlackjackUtils.InitGoldMoneyCell(rankNode.moneyCell, selfSettleInfo.moneyNum)
    end)
end



CardGameBlackjackRoundSettleCtrl.StartCountDown = HL.Method(HL.Number, HL.Function) << function(self, duration, onFinish)
    local rankNode = self.view.rankNode
    
    local countDownTxt = rankNode.countDownText.view.text
    local lastShownSecond = math.floor(duration)
    countDownTxt.text = lastShownSecond
    local tickId = 0
    tickId = self:_StartUpdate(function(deltaTime)
        if LuaSystemManager.cardGameBlackjackSystem.isPauseByGuide then
            return
        end
        duration = math.max(0, duration - deltaTime)
        local shownSecond = math.floor(duration)  
        countDownTxt.text = shownSecond
        
        if shownSecond < lastShownSecond then
            lastShownSecond = shownSecond
            AudioAdapter.PostEvent("Au_UI_Toast_TickDown_OS")
        end
        if duration <= 0 then
            self:_RemoveUpdate(tickId)
            if onFinish then
                onFinish()
            end
        end
    end)
end


HL.Commit(CardGameBlackjackRoundSettleCtrl)
