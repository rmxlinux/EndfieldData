local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')
local CardGameSceneBlackjack = require_ex('LuaSystem/CardGame/CardGameSceneBlackjack').CardGameSceneBlackjack
CardGameBlackjackSystem = HL.Class('CardGameBlackjackSystem', LuaSystemBase.LuaSystemBase)





local HUD_PANEL_ID = PanelId.CardGameBlackjackHud
local SHOP_SELECT_PANEL_ID = PanelId.CardGameBlackjackShopSelect
local ROUND_SETTLE_PANEL_ID = PanelId.CardGameBlackjackRoundSettle
local FINAL_SETTLE_PHASE_ID = PhaseId.CardGameBlackjackFinalSettle
local FINAL_SETTLE_RANK_PHASE_ID = PhaseId.CardGameBlackjackFinalSettleRank



local CardChangeType = CS.Beyond.GEnums.BlackJackCardGameCardChangeType
local CardSuit = CS.Beyond.GEnums.BlackJackCardGameCardSuit
local CardEnhance = CS.Beyond.GEnums.BlackJackCardGameCardEnhance
local ChooseAttributeType = CS.Beyond.GEnums.BlackJackCardGameChooseAttributeType
local NotifyType = CS.Proto.SCD_BLACKJACK_V1D7_NOTIFY_TYPE
local OpType = CS.Proto.BLACKJACK_V1D7_OP_TYPE
local MutationType = CS.Beyond.Gameplay.BlackjackMutationType
local ListTarget = CS.Beyond.Gameplay.BlackjackListTarget
local OrderedChangeType = CS.Proto.BLACKJACK_V1D7_ORDERED_COLLECTION_CHANGE_TYPE
local EffectKind = CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind

local CLIENT_PHASE = CardGameBlackjackUtils.CLIENT_PHASE
local BATTLE_SUB_PHASE = CardGameBlackjackUtils.BATTLE_SUB_PHASE


local QUEUE_PAUSE_KEY = {
    
    Hud = "Hud",
    Guide = "Guide",
    
    
    PhaseEntering = "PhaseEntering",
    
    ForceLeave = "ForceLeave",
}



local CATCH_UP_NOTIFY_TYPES = {
    [NotifyType.DeterminePickCard] = true,
    [NotifyType.StartShopPhase] = true,
    [NotifyType.ChooseDestroyCard] = true,
    [NotifyType.ChoosePreviewCard] = true,
    [NotifyType.StartGameRound] = true,
    [NotifyType.EndRoundSettlePhase] = true,
}

local CATCH_UP_MIN_PENDING_COUNT = 25


local START_PRESENTATION_FORBID_HOTSWAP_KEY = "CardGameBlackjack.StartPresentation"





local NOTIFY_TYPE_TO_CHOOSE_KEY = {
    [NotifyType.DeterminePickCard] = CardGameBlackjackUtils.CHOOSE_KEY.Pick,
    
    [NotifyType.PostWaitingChooseCard] = CardGameBlackjackUtils.CHOOSE_KEY.Pick,
    
    [NotifyType.StartShopPhase] = CardGameBlackjackUtils.CHOOSE_KEY.Shop,
    
    [NotifyType.ChooseInitialRelic] = CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic,
    [NotifyType.ChooseCardModify] = CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard,
    [NotifyType.ChooseCardGain] = CardGameBlackjackUtils.CHOOSE_KEY.GainCard,
    [NotifyType.ChooseAttribute] = CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr,
    [NotifyType.ChoosePreviewCard] = CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard,
    [NotifyType.ChooseDestroyCard] = CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard,
}


local EFFECT_KIND_TO_CHOOSE_KEY = {
    [CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseDraw] = CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard,
    [CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseAttribute] = CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr,
    [CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseWhetherDiscard] = CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard,
}





local CHOOSE_META = {
    [CardGameBlackjackUtils.CHOOSE_KEY.Pick] = {
        opType = OpType.DeterminePickCard,
        oneShot = false,
        
        acceptRebind = { [NotifyType.PostWaitingChooseCard] = true },
        onOpen = "_OpenPickCardWindow",
        onClose = "_ClosePickCardWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.Shop] = {
        
        oneShot = false,
        onOpen = "_OpenShopWindow",
        onClose = "_CloseShopWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic] = {
        
        
        
        oneShot = false,
        acceptRebind = { [NotifyType.ChooseInitialRelic] = true },
        onOpen = "_OpenInitialRelicWindow",
        onClose = "_CloseInitialRelicWindow",
        onRebind = "_RebindInitialRelicWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard] = {
        opType = OpType.ChooseCardModify,
        oneShot = true,
        onOpen = "_OpenChangeCardWindow",
        onClose = "_CloseChangeCardWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.GainCard] = {
        opType = OpType.ChooseCardGain,
        oneShot = true,
        onOpen = "_OpenGainCardWindow",
        onClose = "_CloseGainCardWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr] = {
        opType = OpType.ChooseAttribute,
        oneShot = true,
        onOpen = "_OpenChooseAttributeWindow",
        onClose = "_CloseChooseAttributeWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard] = {
        opType = OpType.ChoosePreviewCard,
        oneShot = true,
        onOpen = "_OpenPreviewCardWindow",
        onClose = "_ClosePreviewCardWindow",
    },
    [CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard] = {
        opType = OpType.ChooseDestroyCard,
        oneShot = true,
        onOpen = "_OpenDestroyCardWindow",
        onClose = "_CloseDestroyCardWindow",
    },
}





local OP_RESULT_HANDLERS = {
    [OpType.DeterminePickCard] = "_OnPickCardResult",
    [OpType.BuyGoods] = "_OnShopBuyGoodsResult",
    [OpType.SetShopItemPin] = "_OnShopSetPinResult",
    [OpType.RefreshShop] = "_OnShopRefreshShopResult",
    [OpType.RefreshInitialRelic] = "_OnInitialRelicRefreshResult",
    [OpType.FinishShop] = "_OnShopFinishResult",
    [OpType.ChooseInitialRelic] = "_OnInitialRelicChooseResult",
    [OpType.ChooseCardModify] = "_OnChangeCardModifyResult",
    [OpType.ChooseCardGain] = "_OnGainCardResult",
    [OpType.ChooseAttribute] = "_OnChooseAttributeResult",
    [OpType.ChoosePreviewCard] = "_OnPreviewCardResult",
    [OpType.ChooseDestroyCard] = "_OnDestroyCardResult",
}










CardGameBlackjackSystem.m_roomData = HL.Field(HL.Any)


CardGameBlackjackSystem.m_inGame = HL.Field(HL.Boolean) << false

CardGameBlackjackSystem.isHudReady = HL.Field(HL.Boolean) << false


CardGameBlackjackSystem.m_enteringPhases = HL.Field(HL.Table) << function() return {} end


CardGameBlackjackSystem.m_hudSeatNaviAllowed = HL.Field(HL.Boolean) << false


CardGameBlackjackSystem.m_isStartPresentationPlaying = HL.Field(HL.Boolean) << false







CardGameBlackjackSystem.m_effectReportInfo = HL.Field(HL.Table)


CardGameBlackjackSystem.m_effectReportShowCardMemberId = HL.Field(HL.Any)


CardGameBlackjackSystem.scene = HL.Field(HL.Forward("CardGameSceneBlackjack"))


CardGameBlackjackSystem.m_gameplayMsgGroup = HL.Field(HL.Table)


CardGameBlackjackSystem.m_isLeaveByPlayer = HL.Field(HL.Boolean) << false

CardGameBlackjackSystem.m_leaveRoomType = HL.Field(HL.Number) << 0


CardGameBlackjackSystem.m_forceLeaveUpdateKey = HL.Field(HL.Number) << -1


CardGameBlackjackSystem.m_deferExitHudUpdateKey = HL.Field(HL.Number) << -1
CardGameBlackjackSystem.m_deferExitHudStartTime = HL.Field(HL.Number) << 0

CardGameBlackjackSystem.m_isDeferExitHudTimeoutReported = HL.Field(HL.Boolean) << false







CardGameBlackjackSystem.m_seatMembers = HL.Field(HL.Table)


CardGameBlackjackSystem.m_seatToHudSeat = HL.Field(HL.Table)


CardGameBlackjackSystem.m_memberIdToHudSeat = HL.Field(HL.Table)



CardGameBlackjackSystem.m_hudShownPoints = HL.Field(HL.Table)












CardGameBlackjackSystem.m_mirrorMembers = HL.Field(HL.Table)

CardGameBlackjackSystem.m_mirrorGlobal = HL.Field(HL.Any)












CardGameBlackjackSystem.m_notifyQueue = HL.Field(CardGameAnimQueue)

CardGameBlackjackSystem.m_notifyEnqueueIndex = HL.Field(HL.Number) << 0

CardGameBlackjackSystem.m_catchUpIndex = HL.Field(HL.Number) << 0

CardGameBlackjackSystem.m_selfPickResult = HL.Field(HL.Any)






CardGameBlackjackSystem.m_clientPhase = HL.Field(HL.String) << CLIENT_PHASE.WaitStart

CardGameBlackjackSystem.m_battleSubPhase = HL.Field(HL.String) << BATTLE_SUB_PHASE.None


CardGameBlackjackSystem.m_pickShownMembers = HL.Field(HL.Table) << function() return {} end


CardGameBlackjackSystem.m_isHpHintShow = HL.Field(HL.Boolean) << false


CardGameBlackjackSystem.m_isHudPickTipsShow = HL.Field(HL.Boolean) << false




CardGameBlackjackSystem.m_eliminatedSettleInfos = HL.Field(HL.Table)



CardGameBlackjackSystem.m_finalSettlements = HL.Field(HL.Table)


CardGameBlackjackSystem.m_finalSettleArg = HL.Field(HL.Any)




CardGameBlackjackSystem.m_selfEliminatedResult = HL.Field(HL.Table)




CardGameBlackjackSystem.m_selfMaxRoundScore = HL.Field(HL.Number) << 0



CardGameBlackjackSystem.m_earlyLeaveSettleArg = HL.Field(HL.Table)


CardGameBlackjackSystem.m_isFinalMusicPlayed = HL.Field(HL.Boolean) << false






CardGameBlackjackSystem.m_seatDeckUids = HL.Field(HL.Table)


CardGameBlackjackSystem.m_seatDeckUidCounter = HL.Field(HL.Table)


CardGameBlackjackSystem.m_aniQueue = HL.Field(CardGameAnimQueue)

CardGameBlackjackSystem.m_effectQueue = HL.Field(CardGameAnimQueue)

CardGameBlackjackSystem.m_dealAniUpdateKey = HL.Field(HL.Number) << -1
CardGameBlackjackSystem.m_aniWaitTimer = HL.Field(HL.Number) << -1





CardGameBlackjackSystem.m_countDownTimer = HL.Field(HL.Number) << -1
CardGameBlackjackSystem.m_countDownEndTime = HL.Field(HL.Number) << 0
CardGameBlackjackSystem.m_countDownTotal = HL.Field(HL.Number) << 0

CardGameBlackjackSystem.m_countDownLastSecond = HL.Field(HL.Number) << -1


CardGameBlackjackSystem.m_countDownPausedAccum = HL.Field(HL.Number) << 0
CardGameBlackjackSystem.m_countDownPauseStart = HL.Field(HL.Number) << -1




CardGameBlackjackSystem.m_spectateCountDown = HL.Field(HL.Table)








CardGameBlackjackSystem.m_pendingOpType = HL.Field(HL.Any) << OpType.None

CardGameBlackjackSystem.m_pendingOpArg = HL.Field(HL.Any)














CardGameBlackjackSystem.m_chooseStack = HL.Field(HL.Table)




CardGameBlackjackSystem.m_chooseTrigger = HL.Field(HL.Table)




CardGameBlackjackSystem.m_otherChoosing = HL.Field(HL.Table)

CardGameBlackjackSystem.m_otherChoosingTimer = HL.Field(HL.Number) << -1



CardGameBlackjackSystem.m_gainCardPackIcon = HL.Field(HL.Any)


CardGameBlackjackSystem.opTypeToChooseKey = HL.Field(HL.Table)



local EMOJI_CD_TICK = 1
CardGameBlackjackSystem.sendEmojiCdTime = HL.Field(HL.Number) << -1
CardGameBlackjackSystem.m_sendEmojiCdEndTime = HL.Field(HL.Number) << 0
CardGameBlackjackSystem.m_sendEmojiCdTimer = HL.Field(HL.Number) << -1



CardGameBlackjackSystem.isPauseByGuide = HL.Field(HL.Boolean) << false




local ROUND_SETTLE_END_WAIT_CLOSE_TIME = 3
CardGameBlackjackSystem.m_roundSettleEndWaitTimer = HL.Field(HL.Number) << -1






CardGameBlackjackSystem.CardGameBlackjackSystem = HL.Constructor() << function(self)
end


CardGameBlackjackSystem.OnInit = HL.Override() << function(self)
    self.m_gameplayMsgGroup = {}
    self.m_notifyQueue = CardGameAnimQueue()
    self.m_aniQueue = CardGameAnimQueue()
    self.m_effectQueue = CardGameAnimQueue()
    self:_ClearSeatData()
    self:_ClearRuntimeState()
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_CREATE, function(arg)
        self:_InitGameSystem(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_SUCCESS_ANIM_OUT_FINISH, function(arg)
        self:_OpenGameHud(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_LEAVE, function(arg)
        self:_OnPlayRoomMemberLeave(arg)
    end)
    
    self.opTypeToChooseKey = {}
    for key, meta in pairs(CHOOSE_META) do
        if meta.opType ~= nil then
            self.opTypeToChooseKey[meta.opType] = key
        end
    end
end

CardGameBlackjackSystem.OnRelease = HL.Override() << function(self)
    self:_UnregisterGameplayMessages()
    self:_CloseHud()
    if self.scene then
        self.scene:Unload()
        self.scene = nil
    end
    self:_ClearSeatData()
    self:_ClearRuntimeState()
    self.m_roomData = nil
    self.m_inGame = false
end







CardGameBlackjackSystem._OnPlayRoomMemberLeave = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    
    local memberId, isSelf = unpack(arg)
    if isSelf then
        self:_OnPlayRoomLeave()
    end
end


CardGameBlackjackSystem._OnPlayRoomLeave = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame then
        return
    end

    
    
    
    
    if not self.m_isLeaveByPlayer and self.m_finalSettlements ~= nil then
        self.m_inGame = false
        return
    end

    
    if self.m_isLeaveByPlayer and self.m_earlyLeaveSettleArg ~= nil then
        self:_OpenEarlyLeaveFinalSettle()
        return
    end

    self:_StopGame()
end




CardGameBlackjackSystem._OnPlayRoomNeedLeave = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local reason = unpack(arg)
    if reason == CS.Proto.MULTIPLAYER_PLAY_ROOM_LEAVE_REASON.GameEnded then
        return
    end
    if self.m_forceLeaveUpdateKey > 0 then
        return
    end

    logger.info("CardGameBlackjackSystem 服务端要求离开局内房，强制收拢, reason=" .. tostring(reason))
    
    self.m_inGame = false
    self.m_notifyQueue:Pause(QUEUE_PAUSE_KEY.ForceLeave)
    self:_TryForceLeavePlayRoom()
end


CardGameBlackjackSystem._TryForceLeavePlayRoom = HL.Method() << function(self)
    if self:IsPhaseEntering() or PhaseManager:IsInPhaseTransition() then
        if self.m_forceLeaveUpdateKey < 0 then
            self.m_forceLeaveUpdateKey = LuaUpdate:Add("Tick", function()
                self:_TryForceLeavePlayRoom()
            end)
        end
        return
    end

    self:_ClearForceLeaveUpdate()
    
    Notify(MessageConst.HIDE_POP_UP)
    self.m_leaveRoomType = MultiplayerConst.EPlayRoomReturn.Main
    self:_StopGame()
end

CardGameBlackjackSystem._ClearForceLeaveUpdate = HL.Method() << function(self)
    if self.m_forceLeaveUpdateKey > 0 then
        LuaUpdate:Remove(self.m_forceLeaveUpdateKey)
    end
    self.m_forceLeaveUpdateKey = -1
end







CardGameBlackjackSystem._InitGameSystem = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local gameType = unpack(arg)
    if gameType ~= CS.Beyond.GEnums.RoomGameType.CardgameBlackJackV1d7 then
        return
    end

    local roomData = GameInstance.player.multiplayerPlayRoomSystem.blackjackRoom
    if roomData == nil then
        logger.error("CardGameBlackjackSystem._InitGameSystem: blackjackRoom is nil")
        return
    end

    
    GameInstance.player.friendSystem:SyncBlackList()

    self.m_roomData = roomData
    self:_BuildSeatData()
    
    self:_ResetMirrorFromRoomData()

    
    if self.m_inGame then
        self:_RebuildDeckVisual(false)
        self:_RefreshHud()
        self:_SetHudSeatNaviAllowed(true)
        self:_SetStartPresentationPlaying(false)
        return
    end

    self.m_inGame = true
    
    self.m_notifyQueue:Pause(QUEUE_PAUSE_KEY.Hud)
    self:_SetClientPhase(CLIENT_PHASE.WaitStart)
    self:_RegisterGameplayMessages()
    self.scene = CardGameSceneBlackjack()
    self.scene:Init(self:_BuildSeatChars())
end


CardGameBlackjackSystem._OpenGameHud = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local gameType = unpack(arg)
    if gameType ~= CS.Beyond.GEnums.RoomGameType.CardgameBlackJackV1d7 then
        return
    end
    if not self.m_inGame then
        return
    end
    if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackHud) then
        return
    end

    self:_OpenHud()
    self:_RefreshHud()
end

CardGameBlackjackSystem._StopGame = HL.Method() << function(self)
    self.m_inGame = false
    
    
    self.m_notifyQueue:Clear(false, false)
    self.m_aniQueue:Clear(false, false)
    self.m_effectQueue:Clear(false, false)
    
    self:CancelPauseByGuide()
    self:_UnregisterGameplayMessages()
    
    self:_ClearChooseStack(true)
    self:_CloseRoundSettle(true)
    self:_CloseFinalSettleRank()
    self:_CloseFinalSettle()
    
    self:_CloseHud()
    if self.scene then
        self.scene:Unload()
        self.scene = nil
    end
    self:_ClearSeatData()
    self:_ClearRuntimeState()
    LuaSystemManager.cardGameSystem:StopGame()
    self.m_roomData = nil
    
    GameInstance.player.multiplayerPlayRoomSystem:ClearRoom()
    LuaSystemManager.cardGameSystem:ClearPokerPool()

    Notify(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_RETURN, self.m_leaveRoomType)
end


CardGameBlackjackSystem._RegisterGameplayMessages = HL.Method() << function(self)
    MessageManager:Register(MessageConst.ON_BLACKJACK_NOTIFY, function(arg)
        self:_OnBlackjackNotify(arg)
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.ON_BLACKJACK_OP_RESULT, function(arg)
        self:_OnBlackjackOpResult(arg)
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_OP_ERROR, function(arg)
        self:_OnPlayRoomOpError(arg)
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED, function()
        self:_RefreshHudAIIcons()
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.ON_MULTIPLAYER_ROOM_EMOJI_NOTIFY, function(arg)
        self:_OnRoomEmojiNotify(arg)
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.SET_PAUSE_CARD_GAME_BY_GUIDE, function(arg)
        self:SetPauseByGuide(arg)
    end, self.m_gameplayMsgGroup)
    MessageManager:Register(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_NEED_LEAVE, function(arg)
        self:_OnPlayRoomNeedLeave(arg)
    end, self.m_gameplayMsgGroup)
end

CardGameBlackjackSystem._UnregisterGameplayMessages = HL.Method() << function(self)
    MessageManager:UnregisterAll(self.m_gameplayMsgGroup)
end



CardGameBlackjackSystem._ClearRuntimeState = HL.Method() << function(self)
    
    self.m_chooseStack = {}
    self.m_chooseTrigger = {}
    self:_ResetOtherChoosingData()
    self:_ClearDealAniUpdate()
    self:_ClearForceLeaveUpdate()
    self.m_notifyQueue:Clear(false, false)
    self.m_aniQueue:Clear(false, false)
    self.m_effectQueue:Clear(false, false)
    self.m_catchUpIndex = 0
    self.m_aniQueue:SetSkipNormal(false)
    self.m_enteringPhases = {}
    self.m_notifyQueue:Resume(QUEUE_PAUSE_KEY.PhaseEntering)
    self.m_notifyQueue:Resume(QUEUE_PAUSE_KEY.ForceLeave)
    self.m_spectateCountDown = nil
    self:_ResetCountDownData()
    TimerManager:ClearAllTimer(self)
    self.m_selfPickResult = nil
    self.m_gainCardPackIcon = nil
    self.m_mirrorMembers = {}
    self.m_mirrorGlobal = nil
    self.m_seatDeckUids = {}
    self.m_seatDeckUidCounter = {}
    
    self.m_pendingOpType = OpType.None
    self.m_pendingOpArg = nil
    self.m_clientPhase = CLIENT_PHASE.WaitStart
    self.m_battleSubPhase = BATTLE_SUB_PHASE.None
    self.m_pickShownMembers = {}
    self.m_isHpHintShow = false
    self.m_isHudPickTipsShow = false
    self.m_eliminatedSettleInfos = {}
    self.m_finalSettlements = nil
    self.m_finalSettleArg = nil
    self.m_selfEliminatedResult = nil
    self.m_selfMaxRoundScore = 0
    self.m_earlyLeaveSettleArg = nil
    self.m_isFinalMusicPlayed = false
    self.m_effectReportInfo = nil
    self.m_effectReportShowCardMemberId = nil
    self.m_isLeaveByPlayer = false
    self.sendEmojiCdTime = -1
    self.m_sendEmojiCdEndTime = 0
    self.m_sendEmojiCdTimer = -1
    self.m_roundSettleEndWaitTimer = -1
    self.m_hudSeatNaviAllowed = false
    self.m_isStartPresentationPlaying = false
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(START_PRESENTATION_FORBID_HOTSWAP_KEY, false)
end

CardGameBlackjackSystem._SetClientPhase = HL.Method(HL.String) << function(self, phase)
    if self.m_clientPhase == phase then
        return
    end
    logger.info("CardGameBlackjackSystem 客户端阶段切换", self.m_clientPhase, "->", phase)
    self.m_clientPhase = phase
    if phase ~= CLIENT_PHASE.Battle then
        local oldSubPhase = self.m_battleSubPhase
        self.m_battleSubPhase = BATTLE_SUB_PHASE.None
        
        if phase ~= CLIENT_PHASE.RoundSettle then
            self.m_pickShownMembers = {}
        end
        if oldSubPhase == BATTLE_SUB_PHASE.ShowCard then
            self:_OnLeaveShowCardSubPhase()
        end
    end
    if phase == CLIENT_PHASE.Shop then
        
        self:_ClearEffectReportInfoAndNotifyHide()
    end
    if phase == CLIENT_PHASE.RoundSettle
        or phase == CLIENT_PHASE.FinalSettle
        or phase == CLIENT_PHASE.Shop
    then
        self:_ClosePlayerGameInfo()
    end
    self:_RefreshHudTitleRoundAndTurn()
    self:_RefreshHudTableTips()
    self:_NotifyPlayerGameInfoCountDownState()
    self:_RefreshHudPointInfoStates()
    self:_RefreshHudPlayerOptInfos()
    
    self:_RefreshHudSelfHandZoneCardMaxTips()
    self:_RefreshHudHandHover()
end


CardGameBlackjackSystem._SetBattleSubPhase = HL.Method(HL.String) << function(self, subPhase)
    if self.m_battleSubPhase == subPhase or self.m_clientPhase ~= CLIENT_PHASE.Battle then
        return
    end
    logger.info("CardGameBlackjackSystem 战斗子阶段切换", self.m_battleSubPhase, "->", subPhase)
    local oldSubPhase = self.m_battleSubPhase
    self.m_battleSubPhase = subPhase
    if subPhase == BATTLE_SUB_PHASE.WaitPick then
        self.m_pickShownMembers = {}
    end
    if oldSubPhase == BATTLE_SUB_PHASE.ShowCard then
        self:_OnLeaveShowCardSubPhase()
    end
    self:_RefreshHudPointInfoStates()
    self:_RefreshHudTableTips()
    self:_NotifyPlayerGameInfoCountDownState()
    self:_RefreshHudPlayerOptInfos()
end


CardGameBlackjackSystem._MarkMemberPickShown = HL.Method(HL.Any) << function(self, memberId)
    if self.m_pickShownMembers[memberId] or self.m_battleSubPhase ~= BATTLE_SUB_PHASE.ShowCard then
        return
    end
    self.m_pickShownMembers[memberId] = true
    self:_RefreshHudPlayerOptInfoByMemberId(memberId)
end


CardGameBlackjackSystem.GetClientPhase = HL.Method().Return(HL.String) << function(self)
    return self.m_clientPhase
end

CardGameBlackjackSystem.GetBattleSubPhase = HL.Method().Return(HL.String) << function(self)
    return self.m_battleSubPhase
end


CardGameBlackjackSystem.IsMemberPickShown = HL.Method(HL.Any).Return(HL.Boolean) << function(self, memberId)
    return self.m_pickShownMembers[memberId] == true
end

CardGameBlackjackSystem.GetEffectReportInfo = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    return self.m_effectReportInfo
end



CardGameBlackjackSystem.RequestLeavePlayRoom = HL.Method(HL.Boolean, HL.Opt(HL.Number))
    << function(self, needConfirm, leaveRoomType)
    if leaveRoomType == nil then
        leaveRoomType = MultiplayerConst.EPlayRoomReturn.Main
    end
    if not needConfirm then
        self:_InnerRequestLeavePlayRoom(leaveRoomType)
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_MULTIPLAYER_PLAY_ROOM_LEAVE_CONFIRM,
        onConfirm = function()
            self:_InnerRequestLeavePlayRoom(leaveRoomType)
        end,
    })
end

CardGameBlackjackSystem._InnerRequestLeavePlayRoom = HL.Method(HL.Number) << function(self, leaveRoomType)
    if self:IsPhaseEntering() then
        return
    end
    self.m_leaveRoomType = leaveRoomType
    if not self.m_inGame then
        
        self:_StopGame()
        return
    end
    
    self.m_isLeaveByPlayer = true
    self.m_earlyLeaveSettleArg = self:_BuildEarlyLeaveFinalSettleArg()
    GameInstance.player.multiplayerPlayRoomSystem:SendLeavePlayRoom()
end






CardGameBlackjackSystem._IsWaitingOpResult = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_pendingOpType ~= OpType.None
end


CardGameBlackjackSystem._IsCurWaitingOp = HL.Method(HL.Any).Return(HL.Boolean) << function(self, opType)
    return self.m_pendingOpType == opType
end






CardGameBlackjackSystem._SendOp = HL.Method(HL.Any, HL.Function, HL.Opt(HL.Any)).Return(HL.Boolean)
        << function(self, opType, sendFn, arg)
    if self.m_roomData == nil then
        return false
    end
    if self:_IsWaitingOpResult() then
        logger.info("CardGameBlackjackSystem 上一条 OP 还没回包，本次不发, pending=" .. tostring(self.m_pendingOpType)
                            .. ", opType=" .. tostring(opType))
        return false
    end
    if self:IsPhaseEntering() then
        logger.info("CardGameBlackjackSystem Phase 入场中，本次不发, opType=" .. tostring(opType))
        return false
    end

    local lastOpSeqId = self.m_roomData.blackjackOpSeqId
    sendFn()
    if self.m_roomData.blackjackOpSeqId == lastOpSeqId then
        logger.error("CardGameBlackjackSystem OP 没发出去, opType=" .. tostring(opType))
        return false
    end

    self.m_pendingOpType = opType
    self.m_pendingOpArg = arg
    return true
end



CardGameBlackjackSystem._TakePendingOp = HL.Method(HL.Any).Return(HL.Boolean, HL.Opt(HL.Any)) << function(self, opType)
    if not self:_IsWaitingOpResult() or not self:_IsCurWaitingOp(opType) then
        return false, nil
    end

    local arg = self.m_pendingOpArg
    self.m_pendingOpType = OpType.None
    self.m_pendingOpArg = nil
    return true, arg
end

CardGameBlackjackSystem._OnPlayRoomOpError = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self:_IsWaitingOpResult() then
        return
    end

    local pendingOpType = self.m_pendingOpType
    local errCode = unpack(arg)
    self:_TakePendingOp(pendingOpType)
    logger.error("CardGameBlackjackSystem OP 被房间层拒绝，清空 pendingOp, opType="
                         .. tostring(pendingOpType) .. ", errCode=" .. tostring(errCode))
end









CardGameBlackjackSystem._OpenPhaseWithEnterGate = HL.Method(HL.Number, HL.Table).Return(HL.Boolean)
        << function(self, phaseId, arg)
    
    self.m_enteringPhases[phaseId] = true
    self.m_notifyQueue:Pause(QUEUE_PAUSE_KEY.PhaseEntering)
    
    local ok = PhaseManager:OpenPhase(phaseId, arg, function()
        self:_OnPhaseEntered(phaseId)
    end, true)
    if not ok then
        self:_OnPhaseEntered(phaseId)
    end
    return ok
end

CardGameBlackjackSystem._OnPhaseEntered = HL.Method(HL.Number) << function(self, phaseId)
    self.m_enteringPhases[phaseId] = nil
    if not self:IsPhaseEntering() then
        self.m_notifyQueue:Resume(QUEUE_PAUSE_KEY.PhaseEntering)
    end
end


CardGameBlackjackSystem.IsPhaseEntering = HL.Method().Return(HL.Boolean) << function(self)
    return next(self.m_enteringPhases) ~= nil
end






CardGameBlackjackSystem._OnBlackjackNotify = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame or self.m_roomData == nil then
        return
    end

    local _, seqId = unpack(arg)
    local batch = self.m_roomData:GetPendingPresentation(seqId)
    if batch == nil then
        logger.error("CardGameBlackjackSystem._OnBlackjackNotify: 取不到演出条目, seqId=" .. tostring(seqId))
        return
    end

    self.m_notifyEnqueueIndex = self.m_notifyEnqueueIndex + 1
    local item = {
        seqId = seqId,
        batch = batch,
        
        
        recvTime = self:_GetCountDownNow(),
        queueIndex = self.m_notifyEnqueueIndex,
    }

    
    self:_BuildPresentationData(item)

    
    
    
    if batch.notifyType == NotifyType.EndGameSettlePhase then
        self:_SnapshotFinalSettlements()
    end

    
    
    if batch.notifyType == NotifyType.ChooseInitialRelic and self.m_clientPhase == CLIENT_PHASE.Dealing then
        self:_FastForwardPresentation()
    end

    if CATCH_UP_NOTIFY_TYPES[batch.notifyType]
            and self.m_notifyQueue:GetPendingCount() >= CATCH_UP_MIN_PENDING_COUNT then
        self:_StartCatchUp(item)
    end

    self.m_notifyQueue:Enqueue(function(finish)
        self:_PlayBatch(item, finish)
    end)
end



CardGameBlackjackSystem._OnBlackjackOpResult = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame or self.m_roomData == nil then
        return
    end

    local opType, _, errCode = unpack(arg)
    
    local isMine, opArg = self:_TakePendingOp(opType)
    if isMine then
        local handler = OP_RESULT_HANDLERS[opType]
        if handler ~= nil then
            self[handler](self, opArg, errCode)
        end
    end

    
    local chooseKey = self.opTypeToChooseKey[opType]
    if chooseKey ~= nil and CHOOSE_META[chooseKey].oneShot
            and (errCode == 0 or errCode == CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER) then
        self:_PopChooseFrom(chooseKey)
    end
end



CardGameBlackjackSystem._PlayBatch = HL.Method(HL.Table, HL.Function) << function(self, item, finish)
    if item.queueIndex == self.m_catchUpIndex then
        
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            if item.queueIndex == self.m_catchUpIndex then
                self.m_catchUpIndex = 0
                self.m_aniQueue:SetSkipNormal(false)
            end
        end)
    end
    self:_PlayNotifyPresentation(item, function()
        
        
        
        self:_NotifyPresentationDone(item.seqId)
        finish()
    end)
end


CardGameBlackjackSystem._NotifyPresentationDone = HL.Method(HL.Any) << function(self, seqId)
    if seqId == nil or self.m_roomData == nil then
        return
    end
    GameInstance.player.multiplayerPlayRoomSystem:NotifyBlackjackPresentationDone(seqId)
end




CardGameBlackjackSystem._EnqueueAnim = HL.Method(HL.Function, HL.Opt(HL.Function, HL.Function))
        << function(self, play, onInterrupt, onFinally)
    local queue = self.m_aniQueue
    queue:Enqueue(function(finish)
        play(finish)
    end)
    if onInterrupt ~= nil then
        queue:EnqueueOnlyInterruptAction(onInterrupt)
    end
    if onFinally ~= nil then
        queue:EnqueueFinallyAction(onFinally)
    end
end

CardGameBlackjackSystem._StartAniWait = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean))
        << function(self, duration, finish, unscaled)
    self.m_aniWaitTimer = self:_StartTimer(duration, function()
        self.m_aniWaitTimer = -1
        finish()
    end, unscaled)
end

CardGameBlackjackSystem._StopAniWait = HL.Method() << function(self)
    self.m_aniWaitTimer = self:_ClearTimer(self.m_aniWaitTimer)
end




CardGameBlackjackSystem._FastForwardPresentation = HL.Method() << function(self)
    self.m_aniQueue:Clear(true, true)
end



CardGameBlackjackSystem._StartCatchUp = HL.Method(HL.Table) << function(self, item)
    logger.info("CardGameBlackjackSystem 积压追进度, notifyType=" .. tostring(item.batch.notifyType)
            .. ", seqId=" .. tostring(item.seqId) .. ", pending=" .. tostring(self.m_notifyQueue:GetPendingCount()))
    self.m_catchUpIndex = item.queueIndex
    self.m_aniQueue:SetSkipNormal(true)
    self:_FastForwardPresentation()
end







CardGameBlackjackSystem._PushChoose = HL.Method(HL.String, HL.Table).Return(HL.Table)
        << function(self, key, item)
    local entry = {
        key = key,
        item = item,
        deadline = self:_CalcChooseDeadline(item),
        
        total = (item.batch.responseTimeoutMs or 0) / 1000,
        opened = false,
        ui = {},
    }
    table.insert(self.m_chooseStack, entry)
    return entry
end


CardGameBlackjackSystem.FindChoose = HL.Method(HL.String).Return(HL.Opt(HL.Table)) << function(self, key)
    for i = #self.m_chooseStack, 1, -1 do
        if self.m_chooseStack[i].key == key then
            return self.m_chooseStack[i]
        end
    end
    return nil
end


CardGameBlackjackSystem.GetChooseTopKey = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    local top = self.m_chooseStack[#self.m_chooseStack]
    return top ~= nil and top.key or nil
end



CardGameBlackjackSystem._GetActiveChoose = HL.Method(HL.String).Return(HL.Opt(HL.Table))
        << function(self, key)
    local top = self.m_chooseStack[#self.m_chooseStack]
    if top ~= nil and top.key == key then
        return top
    end

    logger.error("CardGameBlackjackSystem 越层操作被拒, want=" .. tostring(key)
            .. ", top=" .. tostring(top and top.key))
    return nil
end



CardGameBlackjackSystem._PopChooseFrom = HL.Method(HL.String) << function(self, key)
    local from = nil
    for i = 1, #self.m_chooseStack do
        if self.m_chooseStack[i].key == key then
            from = i
            break
        end
    end
    if from == nil then
        
        logger.info("CardGameBlackjackSystem 选择项已不在栈上，忽略, key=" .. tostring(key))
        return
    end

    for i = #self.m_chooseStack, from, -1 do
        local entry = table.remove(self.m_chooseStack, i)
        if entry.opened then
            self[CHOOSE_META[entry.key].onClose](self, entry)
        end
    end

    self:_RefreshCountDown()
end


CardGameBlackjackSystem._ClearChooseStack = HL.Method(HL.Opt(HL.Boolean)) << function(self, isExitFast)
    for i = #self.m_chooseStack, 1, -1 do
        local entry = table.remove(self.m_chooseStack, i)
        if entry.opened then
            self[CHOOSE_META[entry.key].onClose](self, entry, isExitFast)
        end
    end
    self.m_chooseTrigger = {}
    self.m_spectateCountDown = nil
    self:_RefreshCountDown()
end



CardGameBlackjackSystem._RebindChoose = HL.Method(HL.Table, HL.Table) << function(self, entry, item)
    entry.item = item
    entry.deadline = self:_CalcChooseDeadline(item) or entry.deadline
    if entry.total <= 0 then
        entry.total = (item.batch.responseTimeoutMs or 0) / 1000
    end
    local meta = CHOOSE_META[entry.key]
    if entry.opened and meta.onRebind ~= nil then
        self[meta.onRebind](self, entry)
    end
    self:_RefreshCountDown()
end









CardGameBlackjackSystem._OpenChooseByNotify = HL.Method(HL.String, HL.Table) << function(self, key, item)
    local meta = CHOOSE_META[key]

    
    local exist = self:FindChoose(key)
    if exist ~= nil and meta.acceptRebind ~= nil and meta.acceptRebind[item.batch.notifyType] then
        self:_RebindChoose(exist, item)
        return
    end

    
    local entry = self:_PushChoose(key, item)
    entry.source = self.m_chooseTrigger[key]    
    self.m_chooseTrigger[key] = nil

    
    
    
    
    if self[meta.onOpen](self, entry) == false then
        if self.m_chooseStack[#self.m_chooseStack] == entry then
            table.remove(self.m_chooseStack)
        end
        
        self:_RefreshCountDown()
        return
    end

    entry.opened = true
    self:_RefreshCountDown()
end



CardGameBlackjackSystem._RecordChooseSourceByEffect = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local kind = payload ~= nil and payload.kind or nil
    local key = kind ~= nil and EFFECT_KIND_TO_CHOOSE_KEY[kind] or nil
    if key == nil then
        return
    end

    self.m_chooseTrigger[key] = {
        memberId = effect.targetMemberId,
        isRelicSource = effect.isRelicSource,
        relicId = effect.sourceRelicId,
        sourceCard = effect.sourceCard,
        effect = effect,
    }
end








CardGameBlackjackSystem._PlayNotifyPresentation = HL.Method(HL.Table, HL.Function) << function(self, item, onDone)
    local notifyType = item.batch.notifyType

    
    
    if notifyType == NotifyType.EffectTrigger then
        self:_PlayEffects(item, function()
            self.m_aniQueue:EnqueueFinallyAction(function()
                self:_ApplyBatchData(item)
            end)
            onDone()
        end)
        return
    end

    
    
    local chooseKey = NOTIFY_TYPE_TO_CHOOSE_KEY[notifyType]
    if chooseKey ~= nil and notifyType ~= NotifyType.ChooseInitialRelic then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_OpenChooseByNotify(chooseKey, item)
        onDone()
        return
    end

    
    
    if notifyType == NotifyType.StartGame then
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            self:_RefreshHud()
            local hudCtrl = self:_GetHudCtrl()
            if hudCtrl then
                hudCtrl:ShowTableInfoCountDown(false)
                hudCtrl:ShowTableInfoCenterArrow(false)
            end
        end)
        self:_PlayStartGamePresentation(onDone)

    elseif notifyType == NotifyType.StartGameRound then
        if self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic) ~= nil then
            self:_PopChooseFrom(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
        end
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            self:_RefreshHud()
        end)
        self:_CloseRoundSettle(true)    
        self:_PlayRoundStartPresentation(onDone)

    elseif notifyType == NotifyType.EndGameRound then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_SetClientPhase(CLIENT_PHASE.RoundEndWait)
        self:_PlayRoundEndCollectPresentation(onDone)

    elseif notifyType == NotifyType.StartGameTurn then
        
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            local hudCtrl = self:_GetHudCtrl()
            if hudCtrl then
                hudCtrl:RefreshTitleRoundAndTurn()
            end
            self:_SetBattleSubPhase(BATTLE_SUB_PHASE.WaitPick)
        end)
        self:_ClearSpectateCountDown()
        self.m_selfPickResult = nil
        
        if self:GetGameTurn() == 1 then
            onDone()
        else
            self:_PlayStartGameTurnReport(onDone)
        end

    elseif notifyType == NotifyType.DeterminePickCardResult then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            onDone()
        end)
        if self:_IsSelfMemberId(item.batch.targetMemberId) then
            self:_PopChooseFrom(CardGameBlackjackUtils.CHOOSE_KEY.Pick)
        end

    elseif notifyType == NotifyType.ChooseInitialRelic then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        
        
        if self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic) ~= nil then
            self:_OpenChooseByNotify(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic, item)
            onDone()
        else
            self:_PlayChooseInitialRelicReportThenOpenWindow(item, onDone)
        end

    elseif notifyType == NotifyType.EndShopPhase then
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        
        self:_FastForwardPresentation()
        
        self:_PopChooseFrom(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
        
        self:_ClearSpectateCountDown()
        onDone()

    elseif notifyType == NotifyType.MemberChosenDone then
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        
        self:_RefreshHudPlayerOptInfoByMemberId(item.batch.targetMemberId)
        self:_RefreshHudTableTips()
        
        self:_RefreshShopPlayerStates()
        onDone()

    elseif notifyType == NotifyType.StartShowCardPhase then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_SetBattleSubPhase(BATTLE_SUB_PHASE.ShowCard)
        
        self:_ClearSpectateCountDown()
        self:_PlayStartShowCardReport(onDone)

    elseif notifyType == NotifyType.PreShowCard then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_PlayPreShowCardPresentation(item, onDone)

    elseif notifyType == NotifyType.ShowCard then
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_PlayShowCardPresentation(item, onDone)

    elseif notifyType == NotifyType.EndShowCardPhase then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            self:_ClearEffectReportInfoAndNotifyHide()
            self:_SetBattleSubPhase(BATTLE_SUB_PHASE.None)
            CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.ShowCardEnd)
            onDone()
        end)

    elseif notifyType == NotifyType.StartRoundSettlePhase then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_ClearSpectateCountDown()
        self:_PlayRoundSettleTurnReport(onDone)
        self:_SetClientPhase(CLIENT_PHASE.RoundSettle)

    elseif notifyType == NotifyType.EndRoundSettlePhase then
        
        self:_PlayRoundSettlePresentation(item, onDone)

    elseif notifyType == NotifyType.StartGameSettlePhase then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_CloseRoundSettle(true)
        self:_SetClientPhase(CLIENT_PHASE.FinalSettle)
        self:_SetHpHintShow(false)
        onDone()

    elseif notifyType == NotifyType.EndGameSettlePhase then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
        end)
        self:_PlayFinalSettlePresentation(onDone)

    elseif notifyType == NotifyType.SituationUpdate then
        
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            self:_RefreshShopMainDisplay()
            
            if self.m_clientPhase == CLIENT_PHASE.ShopWait then
                self:_RefreshHudDeckForShopWait()
            end
            onDone()
        end)
        self:_RefreshShopMainOnSituationUpdate()

    elseif notifyType == NotifyType.ShowCardResolved then
        if self.m_effectReportShowCardMemberId == item.batch.targetMemberId then
            self.m_effectReportShowCardMemberId = nil
        end
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            local hudSeat = self.m_memberIdToHudSeat[item.batch.targetMemberId]
            local mirror = hudSeat and self:_GetSeatMirror(hudSeat) or nil
            if mirror ~= nil then
                self:_RefreshHudPointInfoPoint(hudSeat, mirror.points, mirror.scoreCap)
                self:_RefreshHudPointInfoStates(true)
                self:_RefreshHudPlayerOptInfo(hudSeat)
                self:_RefreshHudCardDeckCount(hudSeat)
            end
        end)
        onDone()

    else
        
        
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            onDone()
        end)
    end
end



CardGameBlackjackSystem._PlayRoundReport = HL.Method().Return(HL.Boolean) << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return false
    end

    ctrl:SetRoundReport(self:GetGameRound())
    self.m_aniQueue:Enqueue(function(finish)
        ctrl:PlayRoundReport(finish)
    end)
    return true
end

CardGameBlackjackSystem._PlayStartGameTurnReport = HL.Method(HL.Function) << function(self, onDone)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        onDone()
        return
    end

    local dealerMemberId = self.m_mirrorGlobal and self.m_mirrorGlobal.dealerMemberId or 0
    local startSeatIndex = self:_GetActualSeatIndexByMemberId(dealerMemberId)
    if startSeatIndex <= 0 then
        
        startSeatIndex = 1
    end
    ctrl:RefreshTurnReportStartGameTurn(self:GetGameTurn() - 1, startSeatIndex)
    self:_EnqueueAnim(function(finish)
        ctrl:PlayTurnReport(finish)
    end, function()
        self:_StopTurnReport()
    end, onDone)
end

CardGameBlackjackSystem._PlayRoundSettleTurnReport = HL.Method(HL.Function) << function(self, onDone)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        onDone()
        return
    end

    ctrl:RefreshTurnReportRoundSettle()
    self:_EnqueueAnim(function(finish)
        ctrl:PlayTurnReport(finish)
    end, function()
        self:_StopTurnReport()
    end, onDone)
end

CardGameBlackjackSystem._StopTurnReport = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:StopTurnReport()
    end
end

CardGameBlackjackSystem._PlayStartGamePresentation = HL.Method(HL.Function) << function(self, onDone)
    self:_SetHudSeatNaviAllowed(false)
    self:_SetStartPresentationPlaying(true)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        self:_PlayDealPresentation(onDone)
        return
    end

    self:_SetClientPhase(CLIENT_PHASE.Dealing)
    for hudSeat = 1, self:_GetSeatCount() do
        ctrl:InitRandomSeat(hudSeat, self:_BuildRandomSeatPlayerInfo(hudSeat))
    end
    self.m_aniQueue:Enqueue(function(finish)
        ctrl:PlayRandomSeatAni(self:_GetDealerHudSeat(), finish)
    end)
    self:_PlayDealPresentation(onDone, true)
end

CardGameBlackjackSystem._PlayStartShowCardReport = HL.Method(HL.Function) << function(self, onDone)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        onDone()
        return
    end

    ctrl:RefreshTurnReportStartShowCard(self:GetGameTurn() - 1)
    self:_EnqueueAnim(function(finish)
        ctrl:PlayTurnReport(finish)
    end, function()
        self:_StopTurnReport()
    end, onDone)
end


CardGameBlackjackSystem._PlayPreShowCardPresentation = HL.Method(HL.Table, HL.Function) << function(self, item, onDone)
    local batch = item.batch
    local memberId = batch.targetMemberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    if hudSeat ~= nil then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_MarkMemberPickShown(memberId)
            self:_ShowHudCenterArrow(hudSeat)
        end)
    end
    self:_ShowPickCardEffectReport(memberId, false)  
    onDone()
end


CardGameBlackjackSystem._PlayShowCardPresentation = HL.Method(HL.Table, HL.Function) << function(self, item, onDone)
    local batch = item.batch
    local hudSeat = self.m_memberIdToHudSeat[batch.targetMemberId]
    if hudSeat == nil then
        onDone()
        return
    end
    if self.scene then
        self.scene:TriggerCharRaiseHand(hudSeat)
    end
    local queue = self.m_aniQueue
    queue:Enqueue(function(finish)
        self:_StartAniWait(0.1, finish)
    end)
    queue:Enqueue(function(finish)
        self:_DrawTopCardToHand(hudSeat, batch.shownCard, finish)
    end)
    queue:EnqueueOnlyInterruptAction(function()
        self:_StopAniWait()
        self:_RebuildDeckVisual(false)
    end)
    queue:EnqueueFinallyAction(function()
        self:_RefreshHudCardDeckCount(hudSeat)
        onDone()
    end)
end










CardGameBlackjackSystem._PlayEffects = HL.Method(HL.Table, HL.Function) << function(self, item, onDone)
    local queue = self.m_effectQueue
    local effects = item.batch.effects
    if effects ~= nil then
        for i = 0, effects.Count - 1 do
            local effect = effects[i]
            local effectData = item.effectData[i + 1]
            queue:Enqueue(function(qFinish)
                self:_PlayEffectPayload(effect, effectData, item.recvTime, qFinish)
            end)
        end
    end

    
    queue:EnqueueFinallyAction(function()
        onDone()
    end)
end





CardGameBlackjackSystem._PlayEffectPayload = HL.Method(HL.Any, HL.Table, HL.Number, HL.Function)
        << function(self, effect, effectData, recvTime, onDone)
    if self.m_clientPhase == CLIENT_PHASE.RoundEndWait then
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyEffectDisplay(effect, effectData, true)
            self:_OnEffectDisplayApplied(effect, effectData, true)
        end)
        onDone()
        return
    end

    
    local isShop = self:_IsShopMainPhase()

    
    if isShop then
        self:_RecordChooseSourceByEffect(effect)
    end

    
    local payload = effect.payload
    if payload ~= nil and not (isShop and not self:_IsSelfMemberId(effect.targetMemberId)) then
        self:_TryShowRelicEffectReport(effect)
        local kind = payload.kind
        if kind == EffectKind.ModScoreCap then
            self:_PlayEffectPayloadModScoreCap(effect)
        elseif kind == EffectKind.ModPoints then
            self:_PlayEffectPayloadModPoints(effect)
        elseif kind == EffectKind.ModSettleScore then
            self:_PlayEffectPayloadModSettleScore(effect)
        elseif kind == EffectKind.ModGold then
            self:_PlayEffectPayloadModGold(effect)
        elseif kind == EffectKind.ModHP then
            self:_PlayEffectPayloadModHP(effect)
        elseif kind == EffectKind.DiscardCard then
            self:_PlayEffectPayloadRemoveCard(effect, effectData)
        elseif kind == EffectKind.ModRelicSlotCap then
            
        elseif kind == EffectKind.DisableGoldGain then
            
        elseif kind == EffectKind.SetCardRank then
            self:_PlayEffectPayloadSetCardRank(effect, effectData)
        elseif kind == EffectKind.SetCardSuit then
            self:_PlayEffectPayloadSetCardSuit(effect, effectData)
        elseif kind == EffectKind.ApplyEnhance then
            self:_PlayEffectPayloadApplyEnhance(effect, effectData)
        elseif kind == EffectKind.RemoveCard then
            self:_PlayEffectPayloadRemoveCard(effect, effectData)
        elseif kind == EffectKind.CreateCard then
            self:_PlayEffectPayloadCreateCard(effect, effectData)
        elseif kind == EffectKind.CloneCard then
            self:_PlayEffectPayloadCreateCard(effect, effectData)
        elseif kind == EffectKind.ChooseDraw then
            self:_PlayEffectPayloadChooseDraw(effect, recvTime)
        elseif kind == EffectKind.SetHandCap then
            
        elseif kind == EffectKind.SubPointsByCap then
            self:_PlayEffectPayloadModPoints(effect)    
        elseif kind == EffectKind.FuseUnenhancedNumbers then
            self:_PlayEffectPayloadFuseUnenhancedNumbers(effect)
        elseif kind == EffectKind.ChooseWhetherDiscard then
            self:_PlayEffectPayloadChooseWhetherDiscard(effect, recvTime)
        elseif kind == EffectKind.ChooseAttribute then
            
        elseif kind == EffectKind.ChooseDrawResult then
            self:_PlayEffectPayloadChooseDrawResult(effect)
        elseif kind == EffectKind.PlayerStopDraw then
            self:_PlayEffectPayloadPlayerStopDraw(effect)
        elseif kind == EffectKind.ChooseWhetherDiscardResult then
            self:_PlayEffectPayloadChooseWhetherDiscardResult(effect)
        end
    end

    
    self.m_aniQueue:EnqueueFinallyAction(function()
        self:_ApplyEffectDisplay(effect, effectData, isShop)
        self:_OnEffectDisplayApplied(effect, effectData, isShop)
    end)

    
    if isShop then
        onDone()
    else
        self.m_aniQueue:EnqueueFinallyAction(onDone)
    end
end


CardGameBlackjackSystem._OnEffectDisplayApplied = HL.Method(HL.Any, HL.Table, HL.Boolean)
        << function(self, effect, effectData, isShop)
    self:_RefreshHudPointInfoStates(true)
    
    self:_RefreshHudPlayerOptInfoByMemberId(effect.targetMemberId)

    
    local payload = effect.payload
    local kind = payload ~= nil and payload.kind or nil
    if kind == EffectKind.RemoveCard or kind == EffectKind.DiscardCard
            or kind == EffectKind.CreateCard or kind == EffectKind.CloneCard
            or kind == EffectKind.FuseUnenhancedNumbers then
        self:_RefreshDeckCardNum(effect.targetMemberId)
    elseif kind == EffectKind.SetHandCap then
        self:_RefreshSelfHandCapTips(effect.targetMemberId)
    elseif kind == EffectKind.ModRelicSlotCap then
        if self:_IsSelfMemberId(effect.targetMemberId) then
            self:_RefreshShopMainAuthority()
        end
    end

    if isShop then
        self:_HideEffectReportAfterPayloadIfNeed(effect)
        self:_SyncEffectForHudInShop(effect, effectData)
        return
    end

    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    if payload == nil or hudSeat == nil then
        return
    end
    if kind == EffectKind.RemoveCard or kind == EffectKind.DiscardCard then
        if effectData.handCard ~= nil then
            if hudSeat == 1 then
                self:_RefreshHudSelfHandZoneCardMaxTips()
            end
            
            self:_RefreshHudHandHover()
        elseif effectData.deckCard ~= nil and (effectData.deckRemovedUid == nil
                or self:_IsSeatDeckCardInRegion(hudSeat, effectData.deckRemovedUid)) then
            
            self:_ResyncSeatDeckVisual(hudSeat)
        end
    elseif kind == EffectKind.CreateCard or kind == EffectKind.CloneCard then
        if payload.card.hasIngameDeckIdx and not self:_IsSeatDeckCardInRegion(hudSeat, effectData.deckInsertUid) then
            
            self:_ResyncSeatDeckVisual(hudSeat)
        end
    elseif kind == EffectKind.ApplyEnhance then
        if effectData.handCard == nil and effectData.deckCard ~= nil and payload.hasIngameDeckIdx then
            local uids = self.m_seatDeckUids[hudSeat]
            local uid = uids ~= nil and uids[payload.ingameDeckIdx + 1] or nil
            local cardSystem = LuaSystemManager.cardGameSystem
            if uid ~= nil and cardSystem ~= nil then
                cardSystem:SetCardStyle(uid, CardGameUtils.GetCardStyleByEnhance(payload.value))
            else
                logger.error("CardGameBlackjackSystem._OnEffectDisplayApplied: ApplyEnhance 找不到牌堆占位牌, hudSeat="
                        .. tostring(hudSeat) .. ", ingameDeckIdx=" .. tostring(payload.ingameDeckIdx))
                self:_ResyncSeatDeckVisual(hudSeat)
            end
        end
    elseif kind == EffectKind.FuseUnenhancedNumbers then
        self:_SyncFuseSeatDeckVisual(hudSeat, payload, effectData)
    end
end


CardGameBlackjackSystem._SyncEffectForHudInShop = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    if payload == nil or hudSeat == nil then
        return
    end

    local kind = payload.kind
    if kind == EffectKind.ModScoreCap then
        self:_RefreshModScoreCapForHud(hudSeat, payload.after)
        return
    elseif kind == EffectKind.ModSettleScore then
        self:_RefreshModSettleScoreForHud(hudSeat, payload.after)
        return
    elseif kind == EffectKind.ModGold then
        
        if hudSeat == 1 then
            self:_RefreshModGoldForHud(hudSeat, payload.after)
        end
        return
    elseif kind == EffectKind.ModHP then
        self:_RefreshModHPForHud(hudSeat, payload.after)
        return
    elseif kind == EffectKind.ModPoints or kind == EffectKind.SubPointsByCap then
        self:_RefreshModPointsForHud(hudSeat, payload.after)
        return
    end

    local isHand = effectData.handCard ~= nil
    local isDeck = effectData.deckCard ~= nil
    if kind == EffectKind.CreateCard or kind == EffectKind.CloneCard then
        isDeck = payload.card.hasIngameDeckIdx
    elseif kind == EffectKind.FuseUnenhancedNumbers then
        for _, source in pairs(effectData.fuseSources or {}) do
            isHand = isHand or source.handCard ~= nil
            isDeck = isDeck or source.deckCard ~= nil
        end
        isDeck = isDeck or (payload.hasResultCard and payload.resultCard.hasIngameDeckIdx)
    elseif kind == EffectKind.SetCardRank or kind == EffectKind.SetCardSuit then
        
        isDeck = false
    elseif kind ~= EffectKind.RemoveCard and kind ~= EffectKind.DiscardCard and kind ~= EffectKind.ApplyEnhance then
        return
    end

    
    local useSortedDeck = self.m_clientPhase == CLIENT_PHASE.ShopWait
    if useSortedDeck and kind ~= EffectKind.SetCardRank and kind ~= EffectKind.SetCardSuit then
        isDeck = true
    end

    if isHand then
        self:_ResyncSeatHandVisual(hudSeat)
    end
    if isDeck then
        self:_ResyncSeatDeckVisual(hudSeat, useSortedDeck)
    end
end



CardGameBlackjackSystem._PlayEffectPayloadModScoreCap = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    local valueChangeType = payload.delta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    local deltaValue = math.abs(payload.delta)
    local finalValue = payload.after

    if not self:_IsShopMainPhase() then
        self:_PlayModScoreCapForHud(hudSeat, valueChangeType, deltaValue, finalValue)
        return
    end

    if self:_IsSelfMemberId(effect.targetMemberId) then
        self:_PlayModScoreCapForShop(valueChangeType, deltaValue, finalValue)
    end
end

CardGameBlackjackSystem._PlayModScoreCapForHud = HL.Method(HL.Number, HL.Any, HL.Number, HL.Number)
    << function(self, hudSeat, valueChangeType, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            scene:PlayTableInfoChangeMaxPointNum(hudSeat, valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModScoreCapForHud(hudSeat, finalValue)
    end, function()
        self:_RefreshModScoreCapForHud(hudSeat, finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModScoreCapForHud = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, finalValue)
    local curPoint = self:_GetHudShownPoints(hudSeat)
    self:_RefreshHudPointInfoPoint(hudSeat, curPoint, finalValue)
end

CardGameBlackjackSystem._PlayModScoreCapForShop = HL.Method(HL.Any, HL.Number, HL.Number)
    << function(self, valueChangeType, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayChangeMaxPointNum(valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModScoreCapForShop(finalValue)
    end, function()
        self:_RefreshModScoreCapForShop(finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModScoreCapForShop = HL.Method(HL.Number) << function(self, finalValue)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:RefreshMaxPointNum(finalValue)
    end
end





CardGameBlackjackSystem._PlayEffectPayloadModSettleScore = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    local valueChangeType = payload.delta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    local deltaValue = math.abs(payload.delta)
    local finalValue = payload.after
    local beforeValue = payload.before

    if not self:_IsShopMainPhase() then
        self:_PlayModSettleScoreForHud(hudSeat, valueChangeType, beforeValue, deltaValue, finalValue)
        return
    end

    if self:_IsSelfMemberId(effect.targetMemberId) then
        self:_PlayModSettleScoreForShop(valueChangeType, deltaValue, finalValue)
    end
end

CardGameBlackjackSystem._PlayModSettleScoreForHud = HL.Method(HL.Number, HL.Any, HL.Number, HL.Number, HL.Number)
    << function(self, hudSeat, valueChangeType, beforeValue, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetHudCtrl()
        if ctrl then
            ctrl:RefreshTableInfoPointInfoExtraPoint(hudSeat, beforeValue)
            ctrl:ShowTableInfoPointInfoExtraPoint(hudSeat, true)
        end
        local scene = self.scene
        if scene then
            scene:PlayTableInfoChangeExtraPointNum(hudSeat, valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModSettleScoreForHud(hudSeat, finalValue)
    end, function()
        self:_RefreshModSettleScoreForHud(hudSeat, finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModSettleScoreForHud = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, finalValue)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshTableInfoPointInfoExtraPoint(hudSeat, finalValue)
        ctrl:ShowTableInfoPointInfoExtraPoint(hudSeat, finalValue ~= 0)
    end
end

CardGameBlackjackSystem._PlayModSettleScoreForShop = HL.Method(HL.Any, HL.Number, HL.Number)
    << function(self, valueChangeType, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayChangeExtraPointNum(valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModSettleScoreForShop(finalValue)
    end, function()
        self:_RefreshModSettleScoreForShop(finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModSettleScoreForShop = HL.Method(HL.Number) << function(self, finalValue)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:RefreshExtraPointNum(finalValue)
    end
end





CardGameBlackjackSystem._PlayEffectPayloadModGold = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    local valueChangeType = payload.delta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    local deltaValue = math.abs(payload.delta)
    local finalValue = payload.after

    if not self:_IsShopMainPhase() then
        self:_PlayModGoldForHud(hudSeat, valueChangeType, deltaValue, finalValue)
        return
    end

    if self:_IsSelfMemberId(effect.targetMemberId) then
        self:_PlayModGoldForShop(valueChangeType, deltaValue, finalValue)
    end
end

CardGameBlackjackSystem._PlayModGoldForHud = HL.Method(HL.Number, HL.Any, HL.Number, HL.Number)
    << function(self, hudSeat, valueChangeType, deltaValue, finalValue)
    if hudSeat ~= 1 then
        
        return
    end
    
    self:_EnqueueAnim(function(finish)
        local hud = self:_GetHudCtrl()
        if hud then
            hud:PlayPlayerInfoChangeMoneyNum(valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModGoldForHud(hudSeat, finalValue)
    end, function()
        self:_RefreshModGoldForHud(hudSeat, finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModGoldForHud = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, finalValue)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshSelfMoneyNum(finalValue)
    end
end

CardGameBlackjackSystem._PlayModGoldForShop = HL.Method(HL.Any, HL.Number, HL.Number)
    << function(self, valueChangeType, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayChangeRemainMoneyNum(valueChangeType, deltaValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModGoldForShop(finalValue)
    end, function()
        self:_RefreshModGoldForShop(finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModGoldForShop = HL.Method(HL.Number) << function(self, finalValue)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:RefreshRemainMoneyNum(finalValue)
    end
end





CardGameBlackjackSystem._PlayEffectPayloadModHP = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    local valueChangeType = payload.delta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    local deltaValue = math.abs(payload.delta)
    local finalValue = payload.after
    local beforeValue = payload.before

    if not self:_IsShopMainPhase() then
        self:_PlayModHPForHud(hudSeat, beforeValue, finalValue)
        return
    end

    if self:_IsSelfMemberId(effect.targetMemberId) then
        self:_PlayModHPForShop(valueChangeType, deltaValue, beforeValue, finalValue)
    end
end

CardGameBlackjackSystem._PlayModHPForHud = HL.Method(HL.Number, HL.Number, HL.Number)
    << function(self, hudSeat, beforeValue, finalValue)
    
    self:_EnqueueAnim(function(finish)
        self:_RefreshModHPForHud(hudSeat, finalValue)
        local scene = self.scene
        if scene then
            scene:PlayPlayerHpChangeAni(hudSeat, beforeValue, finalValue, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModHPForHud(hudSeat, finalValue)
    end, function()
        self:_RefreshModHPForHud(hudSeat, finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModHPForHud = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, finalValue)
    local scene = self.scene
    if scene then
        scene:RefreshPlayerHpNum(hudSeat, finalValue)
    end
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        self:_RefreshHudPlayerGameSign(hudSeat, finalValue)
    end
end

CardGameBlackjackSystem._PlayModHPForShop = HL.Method(HL.Any, HL.Number, HL.Number, HL.Number)
    << function(self, valueChangeType, deltaValue, beforeValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayChangeHpNum(valueChangeType, deltaValue, function()
                ctrl:PlayHpChangeAni(beforeValue, finalValue, Tables.cardGameBlackjackConst.initialHp, finish)
            end)
        else
            finish()
        end
    end, function()
        self:_RefreshModHPForShop(finalValue)
    end, function()
        self:_RefreshModHPForShop(finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModHPForShop = HL.Method(HL.Number) << function(self, finalValue)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:RefreshHpNum(finalValue, Tables.cardGameBlackjackConst.initialHp)
    end
end





CardGameBlackjackSystem._PlayEffectPayloadModPoints = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local hudSeat = self.m_memberIdToHudSeat[effect.targetMemberId]
    local valueChangeType = payload.delta > 0 and CardGameUtils.ValueChangeType.Add or CardGameUtils.ValueChangeType.Sub
    local deltaValue = math.abs(payload.delta)
    local finalValue = payload.after

    
    if self:_IsShopMainPhase() then
        return
    end
    self:_PlayModPointsForHud(hudSeat, valueChangeType, deltaValue, finalValue)
end

CardGameBlackjackSystem._PlayModPointsForHud = HL.Method(HL.Number, HL.Any, HL.Number, HL.Number)
    << function(self, hudSeat, valueChangeType, deltaValue, finalValue)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            local fromPoint, maxPoint = self:_GetHudShownPoints(hudSeat)
            scene:PlayTableInfoChangeCurPointNum(hudSeat, valueChangeType, deltaValue, fromPoint, finalValue, maxPoint, finish)
        else
            finish()
        end
    end, function()
        self:_RefreshModPointsForHud(hudSeat, finalValue)
    end, function()
        self:_RefreshModPointsForHud(hudSeat, finalValue)
    end)
end

CardGameBlackjackSystem._RefreshModPointsForHud = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, finalValue)
    local _, maxPoint = self:_GetHudShownPoints(hudSeat)
    self:_RefreshHudPointInfoPoint(hudSeat, finalValue, maxPoint)
end





CardGameBlackjackSystem._BuildSetCardRankPlayArgs = HL.Method(HL.Any, HL.Any).Return(HL.Opt(HL.Table, HL.Table, HL.Table))
    << function(self, payload, card)
    local oldRank = card.rank
    local newRank = payload.value
    local valueChangeType
    local rankValue
    valueChangeType = CardGameUtils.ValueChangeType.ChangeTo
    rankValue = newRank
    local style = CardGameUtils.GetCardStyleByEnhance(card.enhance)
    local changeInfo = {
        cardChangeType = CardChangeType.Rank,
        valueChangeType = valueChangeType,
        rank = rankValue,
    }
    local preCardInfos = {
        { uid = card.id, suit = card.suit, rank = oldRank, style = style },
    }
    local nowCardInfos = {
        { suit = card.suit, rank = newRank, style = style },
    }
    return changeInfo, preCardInfos, nowCardInfos
end

CardGameBlackjackSystem._PlayEffectPayloadSetCardRank = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]

    if not self:_IsShopMainPhase() then
        local isFromHandZone = effectData.handCard ~= nil
        local card = effectData.handCard or effectData.deckCard
        if card == nil then
            return
        end
        local changeInfo, preCardInfos, nowCardInfos = self:_BuildSetCardRankPlayArgs(payload, card)
        
        self:_PlaySetCardRankForHud(hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
        return
    end

    local sortedCard = effectData.sortedCard
    if sortedCard == nil then
        return
    end
    local changeInfo, preCardInfos, nowCardInfos = self:_BuildSetCardRankPlayArgs(payload, sortedCard)
    self:_PlaySetCardRankForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackSystem._PlaySetCardRankForHud = HL.Method(HL.Number, HL.Boolean, HL.Table, HL.Table, HL.Table)
    << function(self, hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            scene:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, hudSeat, isFromHandZone, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptSetCardRankForHud()
    end)
end

CardGameBlackjackSystem._InterruptSetCardRankForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardChangeAni()
    end
end

CardGameBlackjackSystem._PlaySetCardRankForShop = HL.Method(HL.Table, HL.Table, HL.Table)
    << function(self, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptSetCardRankForShop()
    end)
end

CardGameBlackjackSystem._InterruptSetCardRankForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardChangeAni()
    end
end





CardGameBlackjackSystem._BuildFuseUnenhancedNumbersPlayArgs = HL.Method(HL.Any).Return(HL.Opt(HL.Table, HL.Table))
    << function(self, payload)
    local preCardInfos = {}
    local cards = payload ~= nil and payload.cards or nil
    if cards ~= nil then
        for i = 0, cards.Count - 1 do
            local card = cards[i]
            preCardInfos[#preCardInfos + 1] = {
                uid = card.id,
                suit = card.suit,
                rank = card.rank,
                style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
            }
        end
    end

    local nowCardInfos = {}
    if payload ~= nil and payload.hasResultCard then
        local card = payload.resultCard
        nowCardInfos[1] = {
            uid = card.id,
            suit = card.suit,
            rank = card.rank,
            style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
        }
    end
    return preCardInfos, nowCardInfos
end

CardGameBlackjackSystem._PlayEffectPayloadFuseUnenhancedNumbers = HL.Method(HL.Any) << function(self, effect)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local preCardInfos, nowCardInfos = self:_BuildFuseUnenhancedNumbersPlayArgs(payload)

    if not self:_IsShopMainPhase() then
        local hudSeat = self.m_memberIdToHudSeat[memberId]
        if hudSeat == nil then
            return
        end
        self:_PlayFuseUnenhancedNumbersForHud(hudSeat, preCardInfos, nowCardInfos)
        return
    end

    self:_PlayFuseUnenhancedNumbersForShop(preCardInfos, nowCardInfos)
end

CardGameBlackjackSystem._PlayFuseUnenhancedNumbersForHud = HL.Method(HL.Number, HL.Table, HL.Table)
    << function(self, hudSeat, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            scene:PlayCardReplaceAni(preCardInfos, nowCardInfos, hudSeat, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptFuseUnenhancedNumbersForHud()
    end)
end

CardGameBlackjackSystem._InterruptFuseUnenhancedNumbersForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardReplaceAni()
    end
end

CardGameBlackjackSystem._PlayFuseUnenhancedNumbersForShop = HL.Method(HL.Table, HL.Table)
    << function(self, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardReplaceAni(preCardInfos, nowCardInfos, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptFuseUnenhancedNumbersForShop()
    end)
end

CardGameBlackjackSystem._InterruptFuseUnenhancedNumbersForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardReplaceAni()
    end
end





CardGameBlackjackSystem._BuildSetCardSuitPlayArgs = HL.Method(HL.Any, HL.Any).Return(HL.Opt(HL.Table, HL.Table, HL.Table))
    << function(self, payload, card)
    local oldSuit = card.suit
    local newSuit = payload.value
    local style = CardGameUtils.GetCardStyleByEnhance(card.enhance)
    local changeInfo = {
        cardChangeType = CardChangeType.Suit,
        suit = CardSuit.__CastFrom(newSuit),
    }
    local preCardInfos = {
        { uid = card.id, suit = oldSuit, rank = card.rank, style = style },
    }
    local nowCardInfos = {
        { suit = newSuit, rank = card.rank, style = style },
    }
    return changeInfo, preCardInfos, nowCardInfos
end

CardGameBlackjackSystem._PlayEffectPayloadSetCardSuit = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]

    if not self:_IsShopMainPhase() then
        local isFromHandZone = effectData.handCard ~= nil
        local card = effectData.handCard or effectData.deckCard
        if card == nil then
            return
        end
        local changeInfo, preCardInfos, nowCardInfos = self:_BuildSetCardSuitPlayArgs(payload, card)
        
        self:_PlaySetCardSuitForHud(hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
        return
    end

    local sortedCard = effectData.sortedCard
    if sortedCard == nil then
        return
    end
    local changeInfo, preCardInfos, nowCardInfos = self:_BuildSetCardSuitPlayArgs(payload, sortedCard)
    self:_PlaySetCardSuitForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackSystem._PlaySetCardSuitForHud = HL.Method(HL.Number, HL.Boolean, HL.Table, HL.Table, HL.Table)
    << function(self, hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            scene:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, hudSeat, isFromHandZone, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptSetCardSuitForHud()
    end)
end

CardGameBlackjackSystem._InterruptSetCardSuitForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardChangeAni()
    end
end

CardGameBlackjackSystem._PlaySetCardSuitForShop = HL.Method(HL.Table, HL.Table, HL.Table)
    << function(self, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptSetCardSuitForShop()
    end)
end

CardGameBlackjackSystem._InterruptSetCardSuitForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardChangeAni()
    end
end





CardGameBlackjackSystem._BuildApplyEnhancePlayArgs = HL.Method(HL.Any, HL.Any).Return(HL.Opt(HL.Table, HL.Table, HL.Table))
    << function(self, payload, card)
    local oldEnhance = card.enhance
    local newEnhance = payload.value
    local preStyle = CardGameUtils.GetCardStyleByEnhance(oldEnhance)
    local nowStyle = CardGameUtils.GetCardStyleByEnhance(newEnhance)
    local changeInfo = {
        cardChangeType = CardChangeType.Enhance,
        enhance = CardEnhance.__CastFrom(newEnhance),
    }
    local preCardInfos = {
        { uid = card.id, suit = card.suit, rank = card.rank, style = preStyle },
    }
    local nowCardInfos = {
        { suit = card.suit, rank = card.rank, style = nowStyle },
    }
    return changeInfo, preCardInfos, nowCardInfos
end


CardGameBlackjackSystem._PlayEffectPayloadApplyEnhance = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]

    if not self:_IsShopMainPhase() then
        local isFromHandZone = effectData.handCard ~= nil
        local card = effectData.handCard or effectData.deckCard
        if card == nil then
            return
        end
        local changeInfo, preCardInfos, nowCardInfos = self:_BuildApplyEnhancePlayArgs(payload, card)
        
        self:_PlayApplyEnhanceForHud(hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
        return
    end

    local sortedCard = effectData.sortedCard
    if sortedCard == nil then
        return
    end
    local changeInfo, preCardInfos, nowCardInfos = self:_BuildApplyEnhancePlayArgs(payload, sortedCard)
    self:_PlayApplyEnhanceForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackSystem._PlayApplyEnhanceForHud = HL.Method(HL.Number, HL.Boolean, HL.Table, HL.Table, HL.Table)
    << function(self, hudSeat, isFromHandZone, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            scene:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, hudSeat, isFromHandZone, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptApplyEnhanceForHud()
    end)
end

CardGameBlackjackSystem._InterruptApplyEnhanceForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardChangeAni()
    end
end

CardGameBlackjackSystem._PlayApplyEnhanceForShop = HL.Method(HL.Table, HL.Table, HL.Table)
    << function(self, changeInfo, preCardInfos, nowCardInfos)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardChangeAni(changeInfo, preCardInfos, nowCardInfos, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptApplyEnhanceForShop()
    end)
end

CardGameBlackjackSystem._InterruptApplyEnhanceForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardChangeAni()
    end
end





CardGameBlackjackSystem._BuildRemoveCardPlayArgs = HL.Method(HL.Any).Return(HL.Opt(HL.Table))
    << function(self, card)
    return {
        uid = card.id,
        suit = card.suit,
        rank = card.rank,
        style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
    }
end


CardGameBlackjackSystem._PlayEffectPayloadRemoveCard = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local card = payload ~= nil and payload.card or nil
    local hudSeat = self.m_memberIdToHudSeat[memberId]

    if card == nil then
        return
    end

    local cardInfo = self:_BuildRemoveCardPlayArgs(card)

    if not self:_IsShopMainPhase() then
        local isFromHandZone = effectData.handCard ~= nil
        if (not isFromHandZone and effectData.deckCard == nil) or hudSeat == nil then
            return
        end
        if not isFromHandZone and not card.hasIngameDeckIdx then
            
            logger.error("CardGameBlackjackSystem._PlayEffectPayloadRemoveCard: 牌堆删牌没有 ingame_deck_idx, cardId="
                    .. tostring(card.id))
            return
        end
        local deckDrawIndex = isFromHandZone and 0 or card.ingameDeckIdx + 1
        self:_PlayRemoveCardForHud(hudSeat, isFromHandZone, cardInfo, deckDrawIndex, effectData)
        return
    end

    self:_PlayRemoveCardForShop(cardInfo)
end



CardGameBlackjackSystem._PlayRemoveCardForHud = HL.Method(HL.Number, HL.Boolean, HL.Table, HL.Number, HL.Table)
    << function(self, hudSeat, isFromHandZone, cardInfo, deckDrawIndex, effectData)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            local deckUid = nil
            if not isFromHandZone then
                local uids = self.m_seatDeckUids[hudSeat]
                if uids ~= nil and deckDrawIndex >= 1 and deckDrawIndex <= #uids then
                    deckUid = table.remove(uids, deckDrawIndex)
                    effectData.deckRemovedUid = deckUid
                else
                    logger.error("CardGameBlackjackSystem._PlayRemoveCardForHud: 牌堆下标越界, hudSeat="
                            .. tostring(hudSeat) .. ", drawIndex=" .. tostring(deckDrawIndex))
                end
            end
            scene:PlayCardDeleteAni(cardInfo, hudSeat, isFromHandZone, deckUid, finish)
            if isFromHandZone then
                
                local ctrl = self:_GetHudCtrl()
                if ctrl then
                    ctrl:OnHandCardRemoved(cardInfo.uid)
                end
                self:_RefreshHudHandHover()
            end
        else
            finish()
        end
    end, function()
        self:_InterruptRemoveCardForHud()
    end)
end

CardGameBlackjackSystem._InterruptRemoveCardForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardChangeAni()
    end
end

CardGameBlackjackSystem._PlayRemoveCardForShop = HL.Method(HL.Table) << function(self, cardInfo)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardDeleteAni(cardInfo, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptRemoveCardForShop()
    end)
end

CardGameBlackjackSystem._InterruptRemoveCardForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardChangeAni()
    end
end





CardGameBlackjackSystem._BuildCreateCardPlayArgs = HL.Method(HL.Any).Return(HL.Opt(HL.Table))
    << function(self, card)
    return {
        uid = card.id,
        suit = card.suit,
        rank = card.rank,
        style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
    }
end



CardGameBlackjackSystem._PlayEffectPayloadCreateCard = HL.Method(HL.Any, HL.Table) << function(self, effect, effectData)
    local payload = effect.payload
    local memberId = effect.targetMemberId
    local card = payload ~= nil and payload.card or nil
    local hudSeat = self.m_memberIdToHudSeat[memberId]

    if card == nil then
        return
    end

    local cardInfo = self:_BuildCreateCardPlayArgs(card)

    if not self:_IsShopMainPhase() then
        if hudSeat == nil then
            return
        end
        local deckDrawIndex = card.hasIngameDeckIdx and card.ingameDeckIdx + 1 or 0
        self:_PlayCreateCardForHud(hudSeat, cardInfo, deckDrawIndex, effectData)
        return
    end

    self:_PlayCreateCardForShop(cardInfo)
end



CardGameBlackjackSystem._PlayCreateCardForHud = HL.Method(HL.Number, HL.Table, HL.Number, HL.Table)
    << function(self, hudSeat, cardInfo, deckDrawIndex, effectData)
    self:_EnqueueAnim(function(finish)
        local scene = self.scene
        if scene then
            local deckInsert = nil
            if deckDrawIndex > 0 then
                deckInsert = self:_InsertSeatDeckUid(hudSeat, deckDrawIndex)
                if deckInsert ~= nil then
                    deckInsert.style = cardInfo.style
                    effectData.deckInsertUid = deckInsert.uid
                end
            end
            scene:PlayCardCreateAni(cardInfo, hudSeat, deckInsert, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptCreateCardForHud()
    end)
end

CardGameBlackjackSystem._InterruptCreateCardForHud = HL.Method() << function(self)
    if self.scene then
        self.scene:StopCardChangeAni()
    end
end

CardGameBlackjackSystem._PlayCreateCardForShop = HL.Method(HL.Table) << function(self, cardInfo)
    self:_EnqueueAnim(function(finish)
        local ctrl = self:_GetShopMainCtrl()
        if ctrl then
            ctrl:PlayCardCreateAni(cardInfo, finish)
        else
            finish()
        end
    end, function()
        self:_InterruptCreateCardForShop()
    end)
end

CardGameBlackjackSystem._InterruptCreateCardForShop = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl then
        ctrl:StopCardChangeAni()
    end
end





CardGameBlackjackSystem._PlayEffectPayloadChooseDraw = HL.Method(HL.Any, HL.Number) << function(self, effect, recvTime)
    
    self:_BindEffectReportToChoose(effect)
    self:_SetOtherChoosing(effect, recvTime)
end

CardGameBlackjackSystem._PlayEffectPayloadChooseDrawResult = HL.Method(HL.Any) << function(self, effect)
    self:_ClearOtherChoosing(effect)
    self:_ClearChooseEffectReport(effect, CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard)
    self:_CloseSelfChooseByResultEffect(effect, CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard)
end




CardGameBlackjackSystem._PlayEffectPayloadChooseWhetherDiscard = HL.Method(HL.Any, HL.Number) << function(self, effect, recvTime)
    self:_ShowDiscardChooseEffectReport(effect)
    self:_SetOtherChoosing(effect, recvTime)
end

CardGameBlackjackSystem._PlayEffectPayloadChooseWhetherDiscardResult = HL.Method(HL.Any) << function(self, effect)
    self:_ClearOtherChoosing(effect)
    self:_ClearChooseEffectReport(effect, CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard)
    self:_CloseSelfChooseByResultEffect(effect, CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard)
end


CardGameBlackjackSystem._CloseSelfChooseByResultEffect = HL.Method(HL.Any, HL.String) << function(self, effect, chooseKey)
    
    if not self:_IsSelfMemberId(effect.targetMemberId) or self:FindChoose(chooseKey) == nil then
        return
    end
    self:_PopChooseFrom(chooseKey)
end






CardGameBlackjackSystem._SetOtherChoosing = HL.Method(HL.Any, HL.Number) << function(self, effect, recvTime)
    local memberId = effect.targetMemberId
    if self:_IsSelfMemberId(memberId) then
        return
    end
    local payload = effect.payload
    local total = (payload.selectionTimeoutMs or 0) / 1000
    self.m_otherChoosing = {
        key = EFFECT_KIND_TO_CHOOSE_KEY[payload.kind],
        memberId = memberId,
        deadline = total > 0 and recvTime + total or nil,
        total = total,
    }
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:OpenHudChooseOtherPlayer(self:BuildHudChooseOtherPlayerView())
    end
    if total > 0 and self.m_otherChoosingTimer < 0 then
        self.m_otherChoosingTimer = LuaUpdate:Add("Tick", function()
            self:_TickOtherChoosing()
        end)
    end
    self:_TickOtherChoosing()
end


CardGameBlackjackSystem._ClearOtherChoosing = HL.Method(HL.Any) << function(self, effect)
    local info = self.m_otherChoosing
    if info == nil then
        return
    end
    if info.memberId ~= effect.targetMemberId then
        logger.error("CardGameBlackjackSystem 其他玩家选择结果对不上, choosing=" .. tostring(info.memberId)
                .. ", result=" .. tostring(effect.targetMemberId))
    end
    self:_StopOtherChoosing()
end

CardGameBlackjackSystem._StopOtherChoosing = HL.Method() << function(self)
    self:_ResetOtherChoosingData()
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:CloseHudChooseOtherPlayer()
    end
end

CardGameBlackjackSystem._ResetOtherChoosingData = HL.Method() << function(self)
    self.m_otherChoosing = nil
    if self.m_otherChoosingTimer > 0 then
        self.m_otherChoosingTimer = LuaUpdate:Remove(self.m_otherChoosingTimer)
    end
end


CardGameBlackjackSystem._TickOtherChoosing = HL.Method() << function(self)
    local info = self.m_otherChoosing
    local ctrl = self:_GetHudCtrl()
    if info == nil or ctrl == nil then
        return
    end
    local remain = info.deadline ~= nil and math.max(info.deadline - self:_GetCountDownNow(), 0) or 0
    ctrl:RefreshHudChooseCountDownOtherPlayer(remain, info.total)
end


CardGameBlackjackSystem.BuildHudChooseOtherPlayerView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local info = self.m_otherChoosing
    if info == nil then
        return nil
    end
    return {
        chooseKey = info.key,
        total = info.total,
    }
end





CardGameBlackjackSystem._PlayEffectPayloadPlayerStopDraw = HL.Method(HL.Any) << function(self, effect)
    local memberId = effect.targetMemberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    if hudSeat ~= nil then
        
        self:_ShowHudCenterArrow(hudSeat)
    end
    if self.scene then
        self.scene:TriggerCharRaiseHand(hudSeat)
    end
    self:_ShowPickCardEffectReport(memberId, true)
    self:_EnqueueAnim(function(finish)
        self:_RefreshHudPlayerOptInfo(hudSeat)
        self:_StartAniWait(0.5, finish)
    end, function()
        self:_StopAniWait()
    end, function()
        if self.m_effectReportShowCardMemberId == memberId then
            self.m_effectReportShowCardMemberId = nil
        end
    end)
end








CardGameBlackjackSystem._GetEffectReportSourceMemberId = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    if self:_IsShopMainPhase() then
        return self.m_roomData.selfMemberId
    end
    return self.m_effectReportShowCardMemberId
end


CardGameBlackjackSystem._GetOrRebuildEffectReportInfo = HL.Method(HL.Any).Return(HL.Table) << function(self, memberId)
    local sourceMemberId = self:_GetEffectReportSourceMemberId()
    local info = self.m_effectReportInfo
    if info == nil or info.sourceMemberId ~= sourceMemberId then
        info = {
            sourceMemberId = sourceMemberId,
        }
        self.m_effectReportInfo = info
    end
    info.memberId = memberId
    return info
end


CardGameBlackjackSystem._ShowPickCardEffectReport = HL.Method(HL.Any, HL.Boolean) << function(self, memberId, isStopPick)
    self.m_effectReportShowCardMemberId = memberId
    self.m_effectReportInfo = {
        sourceMemberId = memberId,
        memberId = memberId,
        pickCardInfo = self:_BuildEffectReportArgPickCardInfo(memberId, isStopPick),
        relicInfo = nil,
    }
    Notify(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT)
end


CardGameBlackjackSystem._ShowDiscardChooseEffectReport = HL.Method(HL.Any) << function(self, effect)
    local memberId = effect.targetMemberId
    local pickCardInfo = self:_BuildEffectReportArgPickCardInfo(memberId, false)
    local effectInfo = self:_BuildEffectReportArgEffectInfo(
            CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.DiscardCard)
    pickCardInfo.effectList = { effectInfo }
    local info = self:_GetOrRebuildEffectReportInfo(memberId)
    info.pickCardInfo = pickCardInfo
    info.relicInfo = nil
    info.chooseKey = EFFECT_KIND_TO_CHOOSE_KEY[effect.payload.kind]
    Notify(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT)
end


CardGameBlackjackSystem._BindEffectReportToChoose = HL.Method(HL.Any) << function(self, effect)
    local info = self.m_effectReportInfo
    if info == nil or info.memberId ~= effect.targetMemberId then
        return
    end
    info.chooseKey = EFFECT_KIND_TO_CHOOSE_KEY[effect.payload.kind]
end


CardGameBlackjackSystem._ClearChooseEffectReport = HL.Method(HL.Any, HL.String) << function(self, effect, chooseKey)
    local info = self.m_effectReportInfo
    if info == nil or info.chooseKey ~= chooseKey or info.memberId ~= effect.targetMemberId then
        return
    end
    self:_ClearEffectReportInfoAndNotifyHide()
end



CardGameBlackjackSystem._TryShowRelicEffectReport = HL.Method(HL.Any) << function(self, effect)
    if not effect.isRelicSource then
        return
    end
    if self:_IsShopMainPhase() and not self:_IsSelfMemberId(effect.targetMemberId) then
        return
    end
    local effectInfo = self:_BuildEffectReportArgEffectInfo(effect.payload.kind, effect.payload)
    if effectInfo == nil then
        return
    end

    local relicId = effect.sourceRelicId
    local info = self:_GetOrRebuildEffectReportInfo(effect.targetMemberId)
    if info.relicInfo == nil or info.relicInfo.relicId ~= relicId then
        info.relicInfo = self:_BuildEffectReportArgRelicInfo(relicId)
        table.insert(info.relicInfo.effectList, effectInfo)
        Notify(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT)
        return
    end

    table.insert(info.relicInfo.effectList, effectInfo)
    Notify(MessageConst.CARD_GAME_BLACKJACK_UPDATE_EFFECT_REPORT)
end

CardGameBlackjackSystem._ClearEffectReportInfoAndNotifyHide = HL.Method() << function(self)
    self.m_effectReportInfo = nil
    Notify(MessageConst.CARD_GAME_BLACKJACK_HIDE_EFFECT_REPORT)
end

CardGameBlackjackSystem._HideEffectReportIfShop = HL.Method() << function(self)
    if self:_IsShopMainPhase() then
        self:_ClearEffectReportInfoAndNotifyHide()
    end
end


CardGameBlackjackSystem._HideEffectReportAfterPayloadIfNeed = HL.Method(HL.Any) << function(self, effect)
    if not self:_IsSelfMemberId(effect.targetMemberId) then
        return
    end
    local payload = effect.payload
    if payload == nil then
        return
    end
    local kind = payload.kind
    if kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseDraw
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseWhetherDiscard
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ChooseAttribute
    then
        return
    end
    self:_HideEffectReportIfShop()
end


CardGameBlackjackSystem._BuildEffectReportArgPickCardInfo = HL.Method(HL.Any, HL.Boolean).Return(HL.Table)
    << function(self, memberId, isStopPick)
    return {
        seatIndex = self:_GetActualSeatIndexByMemberId(memberId),
        isSelf = self:_IsSelfMemberId(memberId),
        isStopPick = isStopPick,
        
        isFirstTurn = self:GetGameTurn() == 1,
    }
end

CardGameBlackjackSystem._BuildEffectReportArgRelicInfo = HL.Method(HL.Any).Return(HL.Table)
    << function(self, relicId)
    local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(relicId)
    if relicCfg == nil then
        logger.error("CardGameBlackjackSystem 找不到relic对应表数据, relicId=" .. tostring(relicId))
        return {
            relicId = relicId,
            relicIcon = "",
            relicName = "",
            effectList = {},
        }
    end
    return {
        relicId = relicId,
        relicIcon = relicCfg.relicIcon,
        relicName = relicCfg.relicName,
        effectList = {},
    }
end


CardGameBlackjackSystem._BuildEffectReportArgEffectInfo = HL.Method(HL.Any, HL.Opt(HL.Any)).Return(HL.Opt(HL.Table))
    << function(self, kind, payload)
    local _, cfg = Tables.cardGameBlackjackEffectTable:TryGetValue(kind)
    if not cfg then
        
        logger.info("构建effect report arg时发现没有实现的类型：" .. tostring(kind))
        return nil
    end
    local arg = {
        effectIcon = cfg.icon,
        effectDesc = cfg.desc,
    }
    if payload == nil then
        return arg
    end
    
    if kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModScoreCap
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModPoints
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModSettleScore
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModGold
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModHP
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.ModRelicSlotCap
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.SetHandCap
        or kind == CS.Beyond.GEnums.BlackJackCardGameChangePerformanceEffectKind.SubPointsByCap
    then
        
        arg.effectDesc = string.format(arg.effectDesc, CardGameUtils.GetNumDeltaText(payload.delta))
    elseif kind == EffectKind.ApplyEnhance then
        
        local enhanceIcon = CardGameBlackjackUtils.ENHANCE_EFFECT_REPORT_ICON[payload.value]
        if enhanceIcon then
            arg.effectIcon = enhanceIcon
        end
    end
    return arg
end







CardGameBlackjackSystem._ResetMirrorFromRoomData = HL.Method() << function(self)
    self.m_mirrorMembers = {}
    self.m_mirrorGlobal = CS.Beyond.Gameplay.BlackjackGlobalState()
    self.m_mirrorGlobal:CopyFrom(self.m_roomData.globalState)

    
    for hudSeat = 1, #self.m_seatMembers do
        local memberId = self.m_seatMembers[hudSeat].memberId
        local found, memberData = self.m_roomData.members:TryGetValue(memberId)
        if found then
            self:_GetMirrorMember(memberId):CopyFrom(memberData)
        end
    end
end


CardGameBlackjackSystem._GetMirrorMember = HL.Method(HL.Any).Return(HL.Any) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    if mirror == nil then
        mirror = CS.Beyond.Gameplay.BlackjackMemberData()
        mirror.memberId = memberId
        self.m_mirrorMembers[memberId] = mirror
    end
    return mirror
end


CardGameBlackjackSystem._GetMemberCardList = HL.Method(HL.Any, HL.Any).Return(HL.Any) << function(self, member, target)
    if target == ListTarget.ShownDeck then
        return member.shownDeck
    elseif target == ListTarget.RemainingDeckSorted then
        return member.remainingDeckSorted
    elseif target == ListTarget.DiscardedDeck then
        return member.discardedDeck
    elseif target == ListTarget.SortedDeck then
        return member.sortedDeck
    end
    return nil
end


CardGameBlackjackSystem._FindCardIndexById = HL.Method(HL.Any, HL.Number).Return(HL.Number) << function(self, list, cardId)
    for i = 0, list.Count - 1 do
        if list[i].id == cardId then
            return i
        end
    end
    return -1
end




CardGameBlackjackSystem._BuildPresentationData = HL.Method(HL.Table) << function(self, item)
    local batch = item.batch
    local workings = {}
    local preStates = batch.preStates
    for i = 0, preStates.Count - 1 do
        local working = preStates[i]
        workings[working.memberId] = working
    end

    item.effectData = {}
    local effects = batch.effects
    if effects ~= nil then
        for i = 0, effects.Count - 1 do
            local effect = effects[i]
            local memberId = effect.targetMemberId
            local working = workings[memberId]
            
            local effectData = self:_LookupEffectCards(effect, working)
            local patch = self:_BuildDisplayPatch(memberId, effect.mutations, working)
            if effect.alignTo ~= nil then
                if working ~= nil then
                    working:CopyGroupsFrom(effect.alignTo, effect.alignGroups)
                end
                patch.alignTo = effect.alignTo
                patch.alignGroups = effect.alignGroups
            end
            effectData.patch = patch
            item.effectData[i + 1] = effectData
        end
    end

    item.batchPatch = nil
    if batch.mutations.Count > 0 then
        item.batchPatch = self:_BuildDisplayPatch(batch.targetMemberId, batch.mutations, workings[batch.targetMemberId])
    end
end



CardGameBlackjackSystem._LookupEffectCards = HL.Method(HL.Any, HL.Any).Return(HL.Table) << function(self, effect, working)
    local effectData = {}
    local payload = effect.payload
    if payload == nil or working == nil then
        return effectData
    end

    local kind = payload.kind
    local cardId = nil
    if kind == EffectKind.SetCardRank or kind == EffectKind.SetCardSuit or kind == EffectKind.ApplyEnhance then
        cardId = payload.targetCardId
    elseif kind == EffectKind.RemoveCard or kind == EffectKind.DiscardCard
            or kind == EffectKind.CreateCard or kind == EffectKind.CloneCard then
        cardId = payload.card.id
    elseif kind == EffectKind.FuseUnenhancedNumbers then
        local fuseSources = {}
        local cards = payload.cards
        for j = 0, cards.Count - 1 do
            local sourceId = cards[j].id
            fuseSources[j + 1] = {
                handCard = self:_FindCardDeckById(working.shownDeck, sourceId),
                deckCard = self:_FindCardDeckById(working.remainingDeckSorted, sourceId),
                sortedCard = self:_FindCardDeckById(working.sortedDeck, sourceId),
            }
        end
        effectData.fuseSources = fuseSources
    end

    if cardId ~= nil then
        effectData.handCard = self:_FindCardDeckById(working.shownDeck, cardId)
        effectData.deckCard = self:_FindCardDeckById(working.remainingDeckSorted, cardId)
        effectData.sortedCard = self:_FindCardDeckById(working.sortedDeck, cardId)
    end
    return effectData
end










CardGameBlackjackSystem._BuildDisplayPatch = HL.Method(HL.Any, HL.Any, HL.Any).Return(HL.Table)
        << function(self, memberId, mutations, working)
    local patch = { memberId = memberId, ops = {} }
    if mutations == nil or mutations.Count <= 0 then
        return patch
    end
    if working == nil then
        logger.error("CardGameBlackjackSystem._BuildDisplayPatch: 有 mutation 但没有通知前状态, memberId=" .. tostring(memberId))
        return patch
    end

    local ops = patch.ops
    local isBacksideChanged = false
    for i = 0, mutations.Count - 1 do
        local mutation = mutations[i]
        local mutationType = mutation.mutationType
        if mutationType == MutationType.OrderedCard then
            local op = self:_BuildCardOrderedOp(mutation, working)
            if op ~= nil then
                ops[#ops + 1] = op
            end
        elseif mutationType == MutationType.OrderedInt then
            isBacksideChanged = true
        else
            ops[#ops + 1] = { type = "mutation", mutation = mutation }
        end
        if not mutation:Apply(working) then
            logger.error("CardGameBlackjackSystem._BuildDisplayPatch: 应用失败, memberId=" .. tostring(memberId)
                    .. ", mutationType=" .. tostring(mutationType))
            
            break
        end
    end

    if isBacksideChanged then
        local values = {}
        local backside = working.deckBackside
        for i = 0, backside.Count - 1 do
            values[i + 1] = backside[i]
        end
        ops[#ops + 1] = { type = "backside", values = values }
    end
    return patch
end


CardGameBlackjackSystem._BuildCardOrderedOp = HL.Method(HL.Any, HL.Any).Return(HL.Opt(HL.Table))
        << function(self, mutation, working)
    local target = mutation.target
    local changeType = mutation.changeType
    local index = mutation.index
    if changeType == OrderedChangeType.Add then
        return { type = "cardInsert", target = target, index = index, card = mutation.card }
    end

    local list = self:_GetMemberCardList(working, target)
    if list == nil or index >= list.Count then
        logger.error("CardGameBlackjackSystem._BuildCardOrderedOp: 下标越界, target=" .. tostring(target)
                .. ", index=" .. tostring(index))
        return nil
    end
    local oldId = list[index].id
    if changeType == OrderedChangeType.Delete then
        return { type = "cardRemove", target = target, id = oldId }
    elseif changeType == OrderedChangeType.Change then
        return { type = "cardReplace", target = target, oldId = oldId, card = mutation.card }
    end
    return nil
end


CardGameBlackjackSystem._ApplyDisplayPatch = HL.Method(HL.Opt(HL.Table)) << function(self, patch)
    if patch == nil or (#patch.ops <= 0 and patch.alignTo == nil) then
        return
    end

    local display = self:_GetMirrorMember(patch.memberId)
    for _, op in ipairs(patch.ops) do
        local opType = op.type
        if opType == "mutation" then
            if not op.mutation:Apply(display) then
                logger.error("CardGameBlackjackSystem._ApplyDisplayPatch: 应用失败, memberId=" .. tostring(patch.memberId)
                        .. ", mutationType=" .. tostring(op.mutation.mutationType))
            end
        elseif opType == "backside" then
            local backside = display.deckBackside
            backside:Clear()
            for _, value in ipairs(op.values) do
                backside:Add(value)
            end
        else
            local list = self:_GetMemberCardList(display, op.target)
            if list == nil then
                logger.error("CardGameBlackjackSystem._ApplyDisplayPatch: 不是卡牌集合, target=" .. tostring(op.target))
            elseif opType == "cardInsert" then
                if self:_FindCardIndexById(list, op.card.id) < 0 then
                    list:Insert(math.min(op.index, list.Count), op.card)
                end
            elseif opType == "cardRemove" then
                local index = self:_FindCardIndexById(list, op.id)
                if index >= 0 then
                    list:RemoveAt(index)
                end
            elseif opType == "cardReplace" then
                local index = self:_FindCardIndexById(list, op.oldId)
                if index >= 0 then
                    list:RemoveAt(index)
                    list:Insert(index, op.card)
                else
                    logger.warn("CardGameBlackjackSystem._ApplyDisplayPatch: cardReplace 找不到旧牌, target="
                            .. tostring(op.target) .. ", oldId=" .. tostring(op.oldId))
                end
            end
        end
    end

    if patch.alignTo ~= nil then
        display:CopyGroupsFrom(patch.alignTo, patch.alignGroups)
    end
end

CardGameBlackjackSystem._ApplyEffectDisplay = HL.Method(HL.Any, HL.Table, HL.Boolean) << function(self, effect, effectData, isShop)
    
    
    
    if not isShop then
        self:_RecordChooseSourceByEffect(effect)
    end
    self:_ApplyDisplayPatch(effectData.patch)
end



CardGameBlackjackSystem._ApplyBatchData = HL.Method(HL.Table) << function(self, item)
    local batch = item.batch
    self:_ApplyDisplayPatch(item.batchPatch)

    local groupMembers = batch.alignGroupMembers
    for i = 0, groupMembers.Count - 1 do
        local align = groupMembers[i]
        self:_GetMirrorMember(align.snapshot.memberId):CopyGroupsFrom(align.snapshot, align.groups)
    end

    if batch.finalGlobalState ~= nil then
        if self.m_mirrorGlobal == nil then
            self.m_mirrorGlobal = CS.Beyond.Gameplay.BlackjackGlobalState()
        end
        self.m_mirrorGlobal:CopyFrom(batch.finalGlobalState)
    end
end

CardGameBlackjackSystem.GetGameRound = HL.Method().Return(HL.Number) << function(self)
    return self.m_mirrorGlobal and self.m_mirrorGlobal.gameRound or 0
end

CardGameBlackjackSystem.GetGameTurn = HL.Method().Return(HL.Number) << function(self)
    return self.m_mirrorGlobal and self.m_mirrorGlobal.gameTurn or 0
end





CardGameBlackjackSystem._TriggerSelfBoardgameVoice = HL.Method(HL.String) << function(self, voiceType)
    local briefData = self.m_seatMembers and self.m_seatMembers[1] and self.m_seatMembers[1].briefData
    CardGameUtils.TriggerVoice(voiceType, briefData and briefData.charId)
end





CardGameBlackjackSystem._PlayDealPresentation = HL.Method(HL.Function, HL.Opt(HL.Boolean))
        << function(self, onDone, hasSeatAni)
    self:_SetClientPhase(CLIENT_PHASE.Dealing)

    local seatBacksides = self:_CollectSeatBacksides()
    local seatRealCards = nil
    if seatBacksides == nil then
        
        logger.error("CardGameBlackjackSystem._PlayDealPresentation: 拿不到 deckBackside，跳过发牌表演")
    else
        seatRealCards = self:_CollectSeatRealCards()
        if seatRealCards == nil then
            logger.error("CardGameBlackjackSystem._PlayDealPresentation: 拿不到 remainingDeckSorted，跳过发牌表演")
        end
    end
    local canDeal = seatRealCards ~= nil and self:_HasCardRegions()
    if not canDeal and not hasSeatAni then
        self:_SetHudSeatNaviAllowed(true)
        self:_SetStartPresentationPlaying(false)
        onDone()
        return
    end

    self:_ShowHudCardDeck(false)
    local queue = self.m_aniQueue
    if canDeal then
        self:_EnqueueDealSteps(seatBacksides, seatRealCards)
    end
    
    queue:EnqueueOnlyInterruptAction(function()
        self:_StopRandomSeatAni()
        if canDeal then
            self:_RebuildDeckVisual(false)
        end
    end)
    queue:EnqueueFinallyAction(function()
        self:_ClearDealAniUpdate()
        self:_ShowHudCardDeck(true)
        self:_SetHudSeatNaviAllowed(true)
        self:_SetStartPresentationPlaying(false)
        CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.StartGameDealEnd)
        onDone()
    end)
end

CardGameBlackjackSystem._ShowHudCardDeck = HL.Method(HL.Boolean) << function(self, isShow)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:ShowTableInfoCardDeck(isShow)
    end
end

CardGameBlackjackSystem._StopRandomSeatAni = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:StopRandomSeatAni()
    end
    self:_ClearDealAniUpdate()
end




CardGameBlackjackSystem._EnqueueDealSteps = HL.Method(HL.Table, HL.Table) << function(self, seatBacksides, seatRealCards)
    local dealQueue = self:_BuildDealQueue(seatRealCards)
    local queue = self.m_aniQueue
    
    queue:Enqueue(function(qFinish)
        self:_BuildSeatDeckUids(seatBacksides)
        local cardSystem = LuaSystemManager.cardGameSystem
        cardSystem:ClearRuntimeCards()
        
        self:_TriggerSelfBoardgameVoice(CardGameUtils.VoiceType.Start)
        for i = #dealQueue, 1, -1 do
            local entry = dealQueue[i]
            cardSystem:CreateCard(CardGameBlackjackUtils.CARD_REGION_DECK, entry.uid)
            cardSystem:SetPokerData(entry.uid, entry.suit, entry.rank,
                    CardGameUtils.GetCardStyleByEnhance(entry.enhance), false)
        end
        cardSystem:RelayoutRegion(CardGameBlackjackUtils.CARD_REGION_DECK, false)
        AudioAdapter.PostEvent("Au_UI_Event_Card21Dealing")
        self:_PlayDealCardsByTick(dealQueue, qFinish)
    end)
    local maxHandCount = 0
    for hudSeat = 1, self:_GetSeatCount() do
        maxHandCount = math.max(maxHandCount, #(seatRealCards[hudSeat] or {}))
    end
    
    self:_EnqueueHandCardsLiftFlipSteps(maxHandCount)
    
    queue:Enqueue(function(qFinish)
        self:_WaitDealPresentation(self:_GetSceneConfig().DEAL_SEE_WAIT_TIME, qFinish)
    end)
    
    self:_EnqueueHandCardsDropFlipSteps(maxHandCount)
    
    queue:Enqueue(function(qFinish)
        self:_PlayAllHandsGatherToStack(qFinish)
    end)
    
    queue:Enqueue(function(qFinish)
        self:_PlayAllHandsFlyToDecks(qFinish)
    end)
    
    queue:Enqueue(function(qFinish)
        self:_SnapDealCardsToBacksideDecks()
        qFinish()
    end)
    
    queue:Enqueue(function(qFinish)
        self:_PlayDeckShuffle(qFinish)
    end)
end

CardGameBlackjackSystem._ClearDealAniUpdate = HL.Method() << function(self)
    if self.m_dealAniUpdateKey and self.m_dealAniUpdateKey > 0 then
        self.m_dealAniUpdateKey = LuaUpdate:Remove(self.m_dealAniUpdateKey)
    end
end


CardGameBlackjackSystem._PlayDealCardsByTick = HL.Method(HL.Table, HL.Function)
        << function(self, dealQueue, finish)
    if dealQueue == nil or #dealQueue <= 0 then
        finish()
        return
    end

    local index = 1
    local pendingAnims = 1
    local launchedAll = false
    local function tryFinish()
        if launchedAll and pendingAnims <= 0 then
            self:_ClearDealAniUpdate()
            finish()
        end
    end
    local function onCardArrived()
        pendingAnims = pendingAnims - 1
        tryFinish()
    end

    local interval = self:_GetSceneConfig().DEAL_INTERVAL
    local elapsed = interval
    self.m_dealAniUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        elapsed = elapsed + deltaTime
        while elapsed >= interval and index <= #dealQueue do
            elapsed = elapsed - interval
            
            if index > #dealQueue then
                break
            end
            local entry = dealQueue[index]
            index = index + 1
            local cardSystem = LuaSystemManager.cardGameSystem
            local deckRegion = cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_DECK)
            if deckRegion == nil or deckRegion:GetCardCount() <= 0 or cardSystem:GetRuntimeCard(entry.uid) == nil then
                return
            end
            pendingAnims = pendingAnims + 1
            
            cardSystem:MoveCardByUidToRegion(entry.uid,
                CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. entry.hudSeat,
                nil, false, true, onCardArrived)
        end
        if index > #dealQueue then
            launchedAll = true
            self:_ClearDealAniUpdate()
            pendingAnims = pendingAnims - 1
            tryFinish()
        end
    end)
end


CardGameBlackjackSystem._WaitDealPresentation = HL.Method(HL.Number, HL.Function)
        << function(self, duration, nextFn)
    if duration <= 0 then
        nextFn()
        return
    end
    local elapsed = 0
    self.m_dealAniUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < duration then
            return
        end
        self:_ClearDealAniUpdate()
        nextFn()
    end)
end





CardGameBlackjackSystem._EnqueueHandCardsLiftFlipSteps = HL.Method(HL.Number) << function(self, maxHandCount)
    local queue = self.m_aniQueue
    for step = 1, maxHandCount do
        queue:Enqueue(function(qFinish)
            self:_PlayHandCardsLiftFlipStep(step, step == maxHandCount, qFinish)
        end)
    end
end


CardGameBlackjackSystem._EnqueueHandCardsDropFlipSteps = HL.Method(HL.Number) << function(self, maxHandCount)
    local queue = self.m_aniQueue
    for step = 1, maxHandCount do
        queue:Enqueue(function(qFinish)
            self:_PlayHandCardsDropFlipStep(step, step == maxHandCount, qFinish)
        end)
    end
end


CardGameBlackjackSystem._PlayHandCardsLiftFlipStep = HL.Method(HL.Number, HL.Boolean, HL.Function)
        << function(self, step, isLastStep, finish)
    local cardSystem = LuaSystemManager.cardGameSystem
    local liftOffset = Vector3(0, self:_GetSceneConfig().DEAL_FLIP_LIFT_HEIGHT, 0)
    local moves = {}
    for hudSeat = 1, self:_GetSeatCount() do
        local region = cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)
        if region ~= nil then
            local cardIndex = region:GetCardCount() - step + 1
            local card = cardIndex >= 1 and region:GetCardAtIndex(cardIndex) or nil
            local pose = card ~= nil and region:GetPose(cardIndex) or nil
            if pose ~= nil then
                moves[#moves + 1] = {
                    card = card,
                    pose = {
                        root = pose.root,
                        localPosition = pose.localPosition + liftOffset,
                        localEulerAngles = pose.localEulerAngles,
                        localScale = pose.localScale,
                    },
                }
            elseif card ~= nil then
                card:SetFace(true)
            end
        end
    end
    self:_PlayDealCardMoves(moves, isLastStep, finish, true)
end


CardGameBlackjackSystem._PlayHandCardsDropFlipStep = HL.Method(HL.Number, HL.Boolean, HL.Function)
        << function(self, step, isLastStep, finish)
    local cardSystem = LuaSystemManager.cardGameSystem
    local moves = {}
    for hudSeat = 1, self:_GetSeatCount() do
        local region = cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)
        if region ~= nil and step <= region:GetCardCount() then
            local card = region:GetCardAtIndex(step)
            local pose = card ~= nil and region:GetPose(step) or nil
            if pose ~= nil then
                moves[#moves + 1] = { card = card, pose = pose }
            elseif card ~= nil then
                card:SetFace(false)
            end
        end
    end
    self:_PlayDealCardMoves(moves, isLastStep, finish, false)
end




CardGameBlackjackSystem._PlayDealCardMoves = HL.Method(HL.Table, HL.Boolean, HL.Function, HL.Opt(HL.Boolean))
        << function(self, moves, waitAnim, finish, faceUp)
    local duration = self:_GetSceneConfig().DEAL_FLIP_MOVE_DURATION
    for i = 1, #moves do
        local move = moves[i]
        local onComplete = waitAnim and i == #moves and finish or nil
        if faceUp == nil then
            move.card:PlayMoveToPose(move.pose, onComplete, false, duration)
        else
            move.card:PlayMoveFlipToPose(move.pose, faceUp, onComplete, false, duration)
        end
    end
    if not waitAnim then
        self:_WaitDealPresentation(self:_GetSceneConfig().DEAL_FLIP_INTERVAL, finish)
    elseif #moves <= 0 then
        finish()
    end
end


CardGameBlackjackSystem._PlayAllHandsGatherToStack = HL.Method(HL.Function) << function(self, finish)
    local pending = 1
    local function endOne()
        pending = pending - 1
        if pending <= 0 then
            finish()
        end
    end
    for hudSeat = 1, self:_GetSeatCount() do
        local region = LuaSystemManager.cardGameSystem:GetRegion(
                CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)
        if region ~= nil then
            for cardIndex = 1, region:GetCardCount() do
                local card = region:GetCardAtIndex(cardIndex)
                local pose = region:GetGatherStackPose(cardIndex)
                if card ~= nil and pose ~= nil then
                    pending = pending + 1
                    card:PlayMoveToPose(pose, endOne, false)
                end
            end
        end
    end
    endOne()
end


CardGameBlackjackSystem._PlayAllHandsFlyToDecks = HL.Method(HL.Function) << function(self, finish)
    local cardSystem = LuaSystemManager.cardGameSystem
    local pending = 1
    local function endOne()
        pending = pending - 1
        if pending <= 0 then
            finish()
        end
    end
    for hudSeat = 1, self:_GetSeatCount() do
        local handRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
        local deckRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
        local uidList = self:_GetRegionUidList(handRegionId)
        if #uidList > 0 then
            pending = pending + 1
            if not cardSystem:MoveCardsByUidToRegion(uidList, deckRegionId, false, true, endOne) then
                endOne()
            end
        end
    end
    endOne()
end



CardGameBlackjackSystem._SnapDealCardsToBacksideDecks = HL.Method() << function(self)
    if not self:_HasCardRegions() then
        return
    end
    local seatBacksides = self:_CollectSeatBacksides()
    if seatBacksides == nil then
        return
    end
    self:_BuildSeatDeckUids(seatBacksides)

    local cardSystem = LuaSystemManager.cardGameSystem
    for hudSeat = 1, self:_GetSeatCount() do
        local handRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
        local deckRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
        if cardSystem:GetRegion(handRegionId) ~= nil then
            cardSystem:RecycleRegionCards(handRegionId)
        end
        if cardSystem:GetRegion(deckRegionId) ~= nil then
            cardSystem:RecycleRegionCards(deckRegionId)
        end

        local backside = seatBacksides[hudSeat] or {}
        local drawIndexByUid = self:_BuildDrawIndexByUid(self.m_seatDeckUids[hudSeat])
        local regionOrder = self:_BuildRegionOrderByDrawOrder(self.m_seatDeckUids[hudSeat]) or {}
        regionOrder = self:_BuildDeckShuffleStartOrder(regionOrder)
        for i = 1, #regionOrder do
            local uid = regionOrder[i]
            local drawIndex = drawIndexByUid[uid]
            cardSystem:CreateCard(deckRegionId, uid)
            cardSystem:SetCardStyle(uid, CardGameUtils.GetCardStyleByEnhance(backside[drawIndex]))
        end
        cardSystem:RelayoutRegion(deckRegionId, false)
    end
end


CardGameBlackjackSystem._GetRegionUidList = HL.Method(HL.String).Return(HL.Table) << function(self, regionId)
    local uidList = {}
    local region = LuaSystemManager.cardGameSystem:GetRegion(regionId)
    if region == nil then
        return uidList
    end
    for cardIndex = 1, region:GetCardCount() do
        local card = region:GetCardAtIndex(cardIndex)
        if card ~= nil then
            uidList[#uidList + 1] = card.uid
        end
    end
    return uidList
end


CardGameBlackjackSystem._MoveAllHandCardsToDecks = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    for hudSeat = 1, self:_GetSeatCount() do
        local handRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
        local deckRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
        local handRegion = cardSystem:GetRegion(handRegionId)
        while handRegion ~= nil and handRegion:GetCardCount() > 0 do
            cardSystem:MoveCardAtIndexToRegion(handRegionId, handRegion:GetCardCount(), deckRegionId, nil, false, false)
        end
    end
    self:_RefreshHudHandHover()
end

CardGameBlackjackSystem._ClearAllHandCards = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        return
    end
    for hudSeat = 1, self:_GetSeatCount() do
        local handRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
        if cardSystem:GetRegion(handRegionId) ~= nil then
            cardSystem:RecycleRegionCards(handRegionId)
        end
    end
    self:_RefreshHudHandHover()
end


CardGameBlackjackSystem._PlayDeckShuffle = HL.Method(HL.Function) << function(self, finish)
    local cardSystem = LuaSystemManager.cardGameSystem
    local pending = 1
    local function endOne()
        pending = pending - 1
        if pending <= 0 then
            finish()
        end
    end
    for hudSeat = 1, self:_GetSeatCount() do
        local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
        local region = cardSystem:GetRegion(regionId)
        local targetOrder = self:_BuildRegionOrderByDrawOrder(self.m_seatDeckUids[hudSeat])
        if region ~= nil and targetOrder ~= nil and #targetOrder > 1 and region:GetCardCount() == #targetOrder
                and not self:_IsEliminatedDeckCleared(self:_GetSeatMirror(hudSeat)) then
            pending = pending + 1
            cardSystem:PlayShuffleByUidList(regionId, {}, targetOrder, self:_GetSceneConfig().DECK_SHUFFLE_DURATION, endOne)
        end
    end
    if pending > 1 then
        AudioAdapter.PostEvent("Au_UI_Event_Card21Shuffling")
    end
    endOne()
end



CardGameBlackjackSystem._PlayRoundStartPresentation = HL.Method(HL.Function) << function(self, onDone)
    self:_SetClientPhase(CLIENT_PHASE.Battle)
    local hasReport = self:_PlayRoundReport()
    self:_PlayRoundStartCardPresentation(onDone, hasReport)
    
    if self:GetCurRoundHpLoss() ~= nil then
        self:_SetHpHintShow(true)
    end
end


CardGameBlackjackSystem.GetCurRoundHpLoss = HL.Method().Return(HL.Opt(HL.Number)) << function(self)
    local round = self:GetGameRound()
    if round <= 0 then
        return nil
    end
    local _, cfg = Tables.cardGameBlackjackRoundSettleTable:TryGetValue(round)
    if not cfg then
        return nil
    end
    local _, rankCfg = cfg.rankMap:TryGetValue(0) 
    if not rankCfg then
        return nil
    end
    return rankCfg.hpLoss
end

CardGameBlackjackSystem.IsHpHintShow = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isHpHintShow
end


CardGameBlackjackSystem._SetHpHintShow = HL.Method(HL.Boolean) << function(self, isShow)
    self.m_isHpHintShow = isShow
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end
    if isShow then
        local hpLoss = self:GetCurRoundHpLoss()
        if hpLoss then
            ctrl:RefreshHpHintNode(hpLoss)
        end
    end
    ctrl:ShowHpHintNode(isShow)
end




CardGameBlackjackSystem._PlayRoundStartCardPresentation = HL.Method(HL.Function, HL.Opt(HL.Boolean))
        << function(self, onDone, hasReport)
    local seatBacksides = self:_CollectSeatBacksides()
    local hasCardData = seatBacksides ~= nil and self:_HasCardRegions()
    if not hasCardData then
        logger.error("CardGameBlackjackSystem._PlayRoundStartPresentation: 拿不到 deckBackside，跳过洗牌表演")
    else
        self:_BuildSeatDeckUids(seatBacksides)
    end
    
    local playCards = hasCardData and self:GetGameRound() > 1

    if not hasReport then
        if not hasCardData then
            self:_ClearAllHandCards()
        end
        if not playCards then
            onDone()
            return
        end
    end

    local queue = self.m_aniQueue
    if playCards then
        queue:Enqueue(function(finish)
            self:_RebuildDeckVisual(true)
            self:_PlayDeckShuffle(finish)
        end)
    elseif not hasCardData then
        queue:Enqueue(function(finish)
            self:_ClearAllHandCards()
            finish()
        end)
    end
    queue:EnqueueOnlyInterruptAction(function()
        self:_StopRoundReport()
        if playCards then
            self:_RebuildDeckVisual(false)
        end
    end)
    queue:EnqueueFinallyAction(function()
        onDone()
    end)
end


CardGameBlackjackSystem._PlayRoundEndCollectPresentation = HL.Method(HL.Function) << function(self, onDone)
    if not self:_HasCardRegions() then
        onDone()
        return
    end
    self:_EnqueueAnim(function(finish)
        self:_MoveAllHandCardsToDecks()
        finish()
    end, nil, onDone)
end

CardGameBlackjackSystem._StopRoundReport = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:StopRoundReport()
    end
end



CardGameBlackjackSystem._RebuildDeckVisual = HL.Method(HL.Opt(HL.Boolean)) << function(self, randomOrder)
    if not self:_HasCardRegions() then
        return
    end
    local seatBacksides = self:_CollectSeatBacksides()
    if seatBacksides == nil then
        return
    end
    self:_BuildSeatDeckUids(seatBacksides)

    local cardSystem = LuaSystemManager.cardGameSystem
    cardSystem:ClearRuntimeCards()
    for hudSeat = 1, self:_GetSeatCount() do
        local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
        local backside = seatBacksides[hudSeat] or {}
        local drawIndexByUid = self:_BuildDrawIndexByUid(self.m_seatDeckUids[hudSeat])
        local regionOrder = self:_BuildRegionOrderByDrawOrder(self.m_seatDeckUids[hudSeat]) or {}
        
        if randomOrder == true and not self:_IsEliminatedDeckCleared(self:_GetSeatMirror(hudSeat)) then
            regionOrder = self:_BuildDeckShuffleStartOrder(regionOrder)
        end

        for i = 1, #regionOrder do
            local uid = regionOrder[i]
            
            local drawIndex = drawIndexByUid[uid]
            cardSystem:CreateCard(regionId, uid)
            cardSystem:SetCardStyle(uid, CardGameUtils.GetCardStyleByEnhance(backside[drawIndex]))
        end
        cardSystem:RelayoutRegion(regionId, false)
    end

    
    self:_RebuildShownCards()
end


CardGameBlackjackSystem._RebuildShownCards = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    for hudSeat = 1, self:_GetSeatCount() do
        local mirror = self:_GetSeatMirror(hudSeat)
        if mirror ~= nil then
            local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
            local shownDeck = mirror.shownDeck
            for i = 0, shownDeck.Count - 1 do
                local card = shownDeck[i]
                cardSystem:CreateCard(regionId, card.id)
                cardSystem:SetPokerData(card.id, card.suit, card.rank, CardGameUtils.GetCardStyleByEnhance(card.enhance), true)
            end
            cardSystem:RelayoutRegion(regionId, false)
        end
    end
    self:_RefreshHudSelfHandZoneCardMaxTips()
    self:_RefreshHudHandHover()
end


CardGameBlackjackSystem._DrawTopCardToHand = HL.Method(HL.Number, HL.Any, HL.Function)
        << function(self, hudSeat, cardData, finish)
    local cardSystem = LuaSystemManager.cardGameSystem
    local deckRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
    local handRegionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
    local deckRegion = cardSystem:GetRegion(deckRegionId)
    local drawOrder = self.m_seatDeckUids[hudSeat]

    if deckRegion == nil or drawOrder == nil or #drawOrder <= 0 or deckRegion:GetCardCount() <= 0 then
        logger.error("CardGameBlackjackSystem._DrawTopCardToHand: 牌堆区没有牌, hudSeat=" .. tostring(hudSeat))
        finish()
        return
    end

    
    
    local drawIndex = 1
    if cardData.hasIngameDeckIdx then
        if cardData.ingameDeckIdx + 1 <= #drawOrder then
            drawIndex = cardData.ingameDeckIdx + 1
        else
            logger.error("CardGameBlackjackSystem._DrawTopCardToHand: ingameDeckIdx 越界，退回堆顶, hudSeat=" .. tostring(hudSeat)
                    .. ", idx=" .. tostring(cardData.ingameDeckIdx) .. ", count=" .. tostring(#drawOrder))
        end
    end
    local placeholderUid = table.remove(drawOrder, drawIndex)
    if not cardSystem:ReplaceCardUid(placeholderUid, cardData.id) then
        finish()
        return
    end

    cardSystem:SetPokerData(cardData.id, cardData.suit, cardData.rank, CardGameUtils.GetCardStyleByEnhance(cardData.enhance))
    AudioAdapter.PostEvent("Au_UI_Event_CardDraw")
    cardSystem:MoveCardByUidToRegion(cardData.id, handRegionId, nil, true, true,
            function()
                if hudSeat == 1 then
                    self:_RefreshHudSelfHandZoneCardMaxTips()
                end
                self:_RefreshHudHandHover()
                finish()
            end)
end



CardGameBlackjackSystem._GetSceneConfig = HL.Method().Return(HL.Any) << function(self)
    return self.scene.sceneRoot.view.config
end

CardGameBlackjackSystem._HasCardRegions = HL.Method().Return(HL.Boolean) << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    return cardSystem ~= nil and cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_DECK) ~= nil
end


CardGameBlackjackSystem._CollectSeatBacksides = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local seatCount = self:_GetSeatCount()
    if seatCount <= 0 then
        return nil
    end

    local result = {}
    for hudSeat = 1, seatCount do
        local list = {}
        local mirror = self:_GetSeatMirror(hudSeat)
        if mirror ~= nil and mirror.deckBackside.Count > 0 then
            for i = 0, mirror.deckBackside.Count - 1 do
                list[i + 1] = mirror.deckBackside[i]
            end
        elseif self:_IsEliminatedDeckCleared(mirror) then
            local sortedDeck = mirror.sortedDeck
            for i = 0, sortedDeck.Count - 1 do
                list[i + 1] = sortedDeck[i].enhance
            end
        end

        result[hudSeat] = list
    end
    return result
end



CardGameBlackjackSystem._IsEliminatedDeckCleared = HL.Method(HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, mirror)
    return mirror ~= nil and mirror.hp <= 0 and mirror.deckBackside.Count <= 0 and mirror.sortedDeck.Count > 0
end



CardGameBlackjackSystem._GetSeatDeckCount = HL.Method(HL.Any).Return(HL.Number) << function(self, mirror)
    if self.m_clientPhase == CLIENT_PHASE.ShopWait or self:_IsEliminatedDeckCleared(mirror) then
        return mirror.sortedDeck.Count
    end
    return mirror.remainingCards
end



CardGameBlackjackSystem._CollectSeatRealCards = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local seatCount = self:_GetSeatCount()
    if seatCount <= 0 then
        return nil
    end

    local result = {}
    local hasReal = false
    for hudSeat = 1, seatCount do
        local list = {}
        local mirror = self:_GetSeatMirror(hudSeat)
        local remaining = mirror and mirror.remainingDeckSorted
        if remaining == nil or remaining.Count <= 0 then
            remaining = mirror and mirror.sortedDeck
        end
        if remaining ~= nil then
            for i = 0, remaining.Count - 1 do
                list[i + 1] = remaining[i]
            end
        end
        if #list > 0 then
            hasReal = true
        end
        result[hudSeat] = list
    end
    if not hasReal then
        return nil
    end
    return result
end


CardGameBlackjackSystem._BuildSeatDeckUids = HL.Method(HL.Table) << function(self, seatBacksides)
    self.m_seatDeckUids = {}
    self.m_seatDeckUidCounter = {}
    for hudSeat, backside in pairs(seatBacksides) do
        self.m_seatDeckUidCounter[hudSeat] = 0
        local uids = {}
        for i = 1, #backside do
            local uid = self:_AllocSeatDeckUid(hudSeat)
            if uid == nil then
                break
            end
            uids[i] = uid
        end
        self.m_seatDeckUids[hudSeat] = uids
    end
end


CardGameBlackjackSystem._AllocSeatDeckUid = HL.Method(HL.Number).Return(HL.Opt(HL.Number)) << function(self, hudSeat)
    local counter = (self.m_seatDeckUidCounter[hudSeat] or 0) + 1
    if counter >= CardGameBlackjackUtils.PLACEHOLDER_UID_SEAT_STRIDE then
        logger.error("CardGameBlackjackSystem._AllocSeatDeckUid: 占位 uid 计数用完, hudSeat=" .. tostring(hudSeat))
        return nil
    end
    self.m_seatDeckUidCounter[hudSeat] = counter
    return CardGameBlackjackUtils.PLACEHOLDER_UID_BASE + hudSeat * CardGameBlackjackUtils.PLACEHOLDER_UID_SEAT_STRIDE + counter
end

CardGameBlackjackSystem._BuildDrawIndexByUid = HL.Method(HL.Opt(HL.Table)).Return(HL.Table) << function(self, drawOrder)
    local result = {}
    for drawIndex, uid in ipairs(drawOrder or {}) do
        result[uid] = drawIndex
    end
    return result
end


CardGameBlackjackSystem._InsertSeatDeckUid = HL.Method(HL.Number, HL.Number).Return(HL.Opt(HL.Table))
        << function(self, hudSeat, drawIndex)
    local drawOrder = self.m_seatDeckUids[hudSeat]
    if drawOrder == nil or drawIndex < 1 or drawIndex > #drawOrder + 1 then
        logger.error("CardGameBlackjackSystem._InsertSeatDeckUid: 牌堆下标越界, hudSeat=" .. tostring(hudSeat)
                .. ", drawIndex=" .. tostring(drawIndex))
        return nil
    end
    local uid = self:_AllocSeatDeckUid(hudSeat)
    if uid == nil then
        return nil
    end
    table.insert(drawOrder, drawIndex, uid)
    return {
        uid = uid,
        regionIndex = #drawOrder - drawIndex + 1,
    }
end

CardGameBlackjackSystem._IsSeatDeckCardInRegion = HL.Method(HL.Number, HL.Opt(HL.Number)).Return(HL.Boolean)
        << function(self, hudSeat, uid)
    if uid == nil then
        return false
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    local card = cardSystem and cardSystem:GetRuntimeCard(uid)
    return card ~= nil and card.regionId == CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
end



CardGameBlackjackSystem._SyncFuseSeatDeckVisual = HL.Method(HL.Number, HL.Any, HL.Table)
        << function(self, hudSeat, payload, effectData)
    if not self:_HasCardRegions() then
        return
    end
    local drawOrder = self.m_seatDeckUids[hudSeat]
    local mirror = self:_GetSeatMirror(hudSeat)
    if drawOrder == nil or mirror == nil then
        return
    end

    local isValid = true
    local sourceIdxs = {}
    local fuseSources = effectData.fuseSources or {}
    local cards = payload.cards
    for j = 0, cards.Count - 1 do
        local source = fuseSources[j + 1]
        if source ~= nil and source.handCard == nil and source.deckCard ~= nil then
            local card = cards[j]
            if card.hasIngameDeckIdx then
                sourceIdxs[#sourceIdxs + 1] = card.ingameDeckIdx
            else
                isValid = false
            end
        end
    end
    table.sort(sourceIdxs, function(a, b)
        return a > b
    end)
    local count = #drawOrder
    for i, idx in ipairs(sourceIdxs) do
        if idx + 1 > count or (i > 1 and idx == sourceIdxs[i - 1]) then
            isValid = false
        end
    end
    local resultCard = payload.hasResultCard and payload.resultCard or nil
    local hasResultIdx = resultCard ~= nil and resultCard.hasIngameDeckIdx
    local countAfterRemove = count - #sourceIdxs
    if hasResultIdx and resultCard.ingameDeckIdx + 1 > countAfterRemove + 1 then
        isValid = false
    end
    if countAfterRemove + (hasResultIdx and 1 or 0) ~= mirror.deckBackside.Count then
        isValid = false
    end
    if not isValid then
        logger.error("CardGameBlackjackSystem._SyncFuseSeatDeckVisual: 下标校验失败，整牌堆兜底重建, hudSeat=" .. tostring(hudSeat))
        self:_ResyncSeatDeckVisual(hudSeat)
        return
    end

    local cardSystem = LuaSystemManager.cardGameSystem
    for _, idx in ipairs(sourceIdxs) do
        local uid = table.remove(drawOrder, idx + 1)
        cardSystem:RecycleCardByUid(uid, true)
    end
    if not hasResultIdx then
        return
    end

    local deckInsert = self:_InsertSeatDeckUid(hudSeat, resultCard.ingameDeckIdx + 1)
    local uid = deckInsert and deckInsert.uid
    if uid == nil or cardSystem:CreateDetachedCard(uid, false) == nil then
        self:_ResyncSeatDeckVisual(hudSeat)
        return
    end
    cardSystem:SetCardStyle(uid, CardGameUtils.GetCardStyleByEnhance(resultCard.enhance))
    local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
    local pose = cardSystem:AttachDetachedCardToRegion(uid, regionId, deckInsert.regionIndex, true)
    if pose ~= nil then
        
        cardSystem:MoveCardByUidToPose(uid, pose, false, false)
    end
end




CardGameBlackjackSystem._ResyncSeatDeckVisual = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, hudSeat, useSortedDeck)
    if not self:_HasCardRegions() then
        return
    end
    local mirror = self:_GetSeatMirror(hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
    local region = cardSystem:GetRegion(regionId)
    if mirror == nil or region == nil then
        return
    end

    local backside = mirror.deckBackside
    local sortedDeck = mirror.sortedDeck
    local targetCount = useSortedDeck and sortedDeck.Count or backside.Count
    while region:GetCardCount() > targetCount do
        cardSystem:RecycleCardByUid(region:GetCardAtIndex(1).uid, false)
    end
    while region:GetCardCount() < targetCount do
        local uid = self:_AllocSeatDeckUid(hudSeat)
        if uid == nil then
            break
        end
        cardSystem:CreateCard(regionId, uid)
    end

    local regionCount = region:GetCardCount()
    local drawOrder = {}
    for regionIndex = 1, regionCount do
        local drawIndex = regionCount - regionIndex + 1
        local uid = region:GetCardAtIndex(regionIndex).uid
        drawOrder[drawIndex] = uid
        local enhance = useSortedDeck and sortedDeck[drawIndex - 1].enhance or backside[drawIndex - 1]
        cardSystem:SetCardStyle(uid, CardGameUtils.GetCardStyleByEnhance(enhance))
    end
    self.m_seatDeckUids[hudSeat] = drawOrder
end


CardGameBlackjackSystem._ResyncSeatHandVisual = HL.Method(HL.Number) << function(self, hudSeat)
    if not self:_HasCardRegions() then
        return
    end
    local mirror = self:_GetSeatMirror(hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
    local region = cardSystem:GetRegion(regionId)
    if mirror == nil or region == nil then
        return
    end

    local shownDeck = mirror.shownDeck
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        for regionIndex = 1, region:GetCardCount() do
            local uid = region:GetCardAtIndex(regionIndex).uid
            if self:_FindCardDeckById(shownDeck, uid) == nil then
                
                ctrl:OnHandCardRemoved(uid)
            end
        end
    end

    cardSystem:RecycleRegionCards(regionId)
    for i = 0, shownDeck.Count - 1 do
        local card = shownDeck[i]
        cardSystem:CreateCard(regionId, card.id)
        cardSystem:SetPokerData(card.id, card.suit, card.rank, CardGameUtils.GetCardStyleByEnhance(card.enhance), true)
    end
    cardSystem:RelayoutRegion(regionId, false)
    if hudSeat == 1 then
        self:_RefreshHudSelfHandZoneCardMaxTips()
    end
    self:_RefreshHudHandHover()
end



CardGameBlackjackSystem._BuildRegionOrderByDrawOrder = HL.Method(HL.Opt(HL.Table)).Return(HL.Opt(HL.Table))
        << function(self, drawOrder)
    if drawOrder == nil then
        return nil
    end
    local result = {}
    for i = #drawOrder, 1, -1 do
        result[#result + 1] = drawOrder[i]
    end
    return result
end



CardGameBlackjackSystem._BuildDealQueue = HL.Method(HL.Table).Return(HL.Table) << function(self, seatRealCards)
    local shuffledPerSeat = {}
    local maxCount = 0
    for hudSeat = 1, self:_GetSeatCount() do
        local cards = self:_ShuffleCopy(seatRealCards[hudSeat] or {})
        shuffledPerSeat[hudSeat] = cards
        maxCount = math.max(maxCount, #cards)
    end

    local queue = {}
    for i = 1, maxCount do
        for hudSeat = 1, self:_GetSeatCount() do
            local card = shuffledPerSeat[hudSeat][i]
            if card ~= nil then
                queue[#queue + 1] = {
                    hudSeat = hudSeat,
                    uid = card.id,
                    suit = card.suit,
                    rank = card.rank,
                    enhance = card.enhance,
                }
            end
        end
    end
    return queue
end


CardGameBlackjackSystem._ShuffleCopy = HL.Method(HL.Table).Return(HL.Table) << function(self, list)
    local result = {}
    for i = 1, #list do
        result[i] = list[i]
    end
    for i = #result, 2, -1 do
        local j = math.random(1, i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end


CardGameBlackjackSystem._GetDeckShuffleCount = HL.Method(HL.Number).Return(HL.Number) << function(self, cardCount)
    if cardCount <= 1 then
        return 0
    end
    if cardCount <= 5 then
        return cardCount
    end
    return math.floor(9 * math.log(cardCount - 1, 10))
end




CardGameBlackjackSystem._BuildDeckShuffleStartOrder = HL.Method(HL.Table).Return(HL.Table) << function(self, targetOrder)
    local result = {}
    local cardCount = #targetOrder
    for i = 1, cardCount do
        result[i] = targetOrder[i]
    end
    local shuffleCount = self:_GetDeckShuffleCount(cardCount)
    if shuffleCount < 2 then
        return result
    end

    local positions = {}
    for bucket = 0, shuffleCount - 1 do
        local lo = math.floor(bucket * cardCount / shuffleCount) + 1
        local hi = math.floor((bucket + 1) * cardCount / shuffleCount)
        positions[#positions + 1] = math.random(lo, hi)
    end

    local uids = {}
    for i = 1, shuffleCount do
        uids[i] = targetOrder[positions[i]]
    end
    for i = shuffleCount, 2, -1 do
        local j = math.random(1, i - 1)
        uids[i], uids[j] = uids[j], uids[i]
    end
    for i = 1, shuffleCount do
        result[positions[i]] = uids[i]
    end
    return result
end








CardGameBlackjackSystem._OpenPickCardWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    local chooseData = entry.item.batch.chooseData
    
    
    if chooseData == nil or chooseData.pickForced then
        
        
        self:_KeepSpectateCountDown(entry)
        self:_SetHudPickEmpty(false)
        return false
    end

    self:_SetHudPickChoosing()
    CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.ChoosePickCardStart)
    return true
end



CardGameBlackjackSystem.OnPlayerPickCard = HL.Method(HL.Boolean) << function(self, pick)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Pick)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end

    local seqId = entry.item.seqId
    self:_SendOp(OpType.DeterminePickCard, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackDeterminePickCard(pick, seqId)
    end, pick)
end



CardGameBlackjackSystem._OnPickCardResult = HL.Method(HL.Opt(HL.Any, HL.Number)) << function(self, opArg, errCode)
    if errCode ~= 0 or self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Pick) == nil then
        return
    end
    self.m_selfPickResult = opArg
    self:_SetHudPickSelected(opArg)
    self:_RefreshHudPlayerOptInfo(1)
    self:_RefreshHudTableTips()
end


CardGameBlackjackSystem._ClosePickCardWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    self:_SetHudPickEmpty(not isExitFast)
    self.m_selfPickResult = nil
    
    self:_RefreshHudPlayerOptInfo(1)
end






CardGameBlackjackSystem.GetShopUIChoose = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    for i = #self.m_chooseStack, 1, -1 do
        local entry = self.m_chooseStack[i]
        if entry.key == CardGameBlackjackUtils.CHOOSE_KEY.Shop or entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic then
            return entry
        end
    end
    return nil
end


CardGameBlackjackSystem._IsShopMainPhase = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_clientPhase == CLIENT_PHASE.Shop
        or self.m_clientPhase == CLIENT_PHASE.InitialRelic
        or self.m_clientPhase == CLIENT_PHASE.ShopWait
end





CardGameBlackjackSystem._CloseShopPhaseUI = HL.Method(HL.String, HL.String, HL.Opt(HL.Boolean))
        << function(self, ownPhase, closedPhase, isExitFast)
    
    self:_FastForwardPresentation()
    if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackShopMain) then
        
        
        if isExitFast or not PhaseManager:PopPhase(PhaseId.CardGameBlackjackShopMain) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackShopMain)
        end
    end
    if self.m_clientPhase == ownPhase then
        self:_SetClientPhase(closedPhase)
    end
end





CardGameBlackjackSystem._BuildShopMainInfo = HL.Method(HL.Boolean).Return(HL.Table)
        << function(self, isInitialRelic)
    local info = self:_BuildShopMainDisplayInfo()
    local selfMember = self.m_roomData and self.m_roomData:GetBlackjackSelfMember()
    local relicInfos = {}
    local extraRelicNum = 0
    if selfMember ~= nil then
        relicInfos = self:_BuildRelicDisplayList(selfMember)
        for i = 1, #relicInfos do
            if relicInfos[i].isExtraRelic then
                extraRelicNum = extraRelicNum + 1
            end
        end
    end
    
    local refreshCost = 0
    if not isInitialRelic and self.m_roomData ~= nil then
        refreshCost = self.m_roomData.shop.refreshCost
    end

    info.isInitialRelic = isInitialRelic
    info.refreshCost = refreshCost
    info.relicInfos = relicInfos
    info.maxRelicSlotNum = (selfMember and selfMember.relicSlotMaxLimit or 0) + extraRelicNum
    info.extraRelicNum = extraRelicNum
    info.relicPreviewType = self:_CalcShopRelicPreviewType()
    return info
end

CardGameBlackjackSystem._BuildShopMainDisplayInfo = HL.Method().Return(HL.Table) << function(self)
    local mirror = self:_GetSeatMirror(1)
    return {
        roundNum = self:GetGameRound(),
        gold = mirror and mirror.gold or 0,
        deckCardNum = mirror and mirror.sortedDeck.Count or 0,
        outScoreCap = mirror and mirror.outScoreCap or 0,
        outAdditionalPoints = mirror and mirror.outAdditionalPoints or 0,
        hp = mirror and mirror.hp or 0,
        maxHp = Tables.cardGameBlackjackConst.initialHp,
    }
end



CardGameBlackjackSystem._CalcShopRelicPreviewType = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    local index = entry ~= nil and entry.ui.selectedIndex or 0
    if index <= 0 then
        return nil
    end
    local shopItem = entry.ui.slots[index].shopItem
    if not CardGameBlackjackUtils.IsBlackjackRelicShopGoodsType(shopItem.slotType) then
        return nil
    end
    local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(shopItem.itemId)
    if relicCfg.occupySlotCount == 0 then
        return CardGameBlackjackUtils.RelicPreviewType.Insert
    end
    local selfMember = self.m_roomData ~= nil and self.m_roomData:GetBlackjackSelfMember() or nil
    if selfMember ~= nil and selfMember.relicSlotUsedLimit < selfMember.relicSlotMaxLimit then
        return CardGameBlackjackUtils.RelicPreviewType.GainSlot
    end
    return nil
end


CardGameBlackjackSystem._RefreshShopMainRelicPreview = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl ~= nil then
        ctrl:RefreshRelicPreview(self:_CalcShopRelicPreviewType())
    end
end

CardGameBlackjackSystem._RefreshShopMainInfo = HL.Method() << function(self)
    
    self:_RefreshShopMainDisplay()
    self:_RefreshShopMainAuthority()
end

CardGameBlackjackSystem._RefreshShopMainDisplay = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if self:GetShopUIChoose() == nil or ctrl == nil then
        return
    end

    local info = self:_BuildShopMainDisplayInfo()
    ctrl:RefreshRoundNum(info.roundNum)
    ctrl:RefreshRemainMoneyNum(info.gold)
    ctrl:RefreshDeckCardNum(info.deckCardNum)
    ctrl:RefreshMaxPointNum(info.outScoreCap)
    ctrl:RefreshExtraPointNum(info.outAdditionalPoints)
    ctrl:RefreshHpNum(info.hp, info.maxHp)
end

CardGameBlackjackSystem._RefreshShopMainAuthority = HL.Method() << function(self)
    local entry = self:GetShopUIChoose()
    local ctrl = self:_GetShopMainCtrl()
    if entry == nil or ctrl == nil then
        return
    end

    local info = self:_BuildShopMainInfo(entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    self:_RefreshShopMainBtnOpNode()
    ctrl:RefreshRefreshNeedMoneyNum(info.refreshCost)
    ctrl:RefreshRelicList(info.relicInfos, info.maxRelicSlotNum, info.extraRelicNum)
    ctrl:RefreshRelicPreview(info.relicPreviewType)
end



CardGameBlackjackSystem._RefreshShopMainBtnOpNode = HL.Method() << function(self)
    local ctrl = self:_GetShopMainCtrl()
    if ctrl ~= nil then
        ctrl:RefreshBtnOpNode()
    end
end


CardGameBlackjackSystem.GetShopSelectedBuyState = HL.Method(HL.Table).Return(HL.Opt(HL.String)) << function(self, entry)
    local index = entry.ui.selectedIndex or 0
    if index <= 0 then
        return nil
    end
    if entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic then
        return CardGameBlackjackUtils.ShopItemBuyState.Gain
    end
    local shopItem = entry.ui.slots[index].shopItem
    local selfMember = self.m_roomData ~= nil and self.m_roomData:GetBlackjackSelfMember() or nil
    if selfMember == nil then
        return nil
    end
    return self:_CalcShopItemBuyState(shopItem, selfMember)
end




CardGameBlackjackSystem._OnShopMainConfirm = HL.Method() << function(self)
    local topKey = self:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.Shop then
        self:_OnShopFinish()
    else
        self:OnShopMainChooseConfirm()
    end
end


CardGameBlackjackSystem.OnShopMainChooseConfirm = HL.Method() << function(self)
    local topKey = self:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard then
        self:_OnChangeCardConfirm()
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.GainCard then
        self:_OnGainCardConfirm()
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr then
        self:_SendChooseAttribute()
    end
end


CardGameBlackjackSystem.OnShopMainExitShop = HL.Method() << function(self)
    if self:GetChooseTopKey() == CardGameBlackjackUtils.CHOOSE_KEY.Shop then
        self:_OnShopFinish()
    end
end


CardGameBlackjackSystem.OnShopMainBuySelected = HL.Method() << function(self)
    if self:GetChooseTopKey() ~= CardGameBlackjackUtils.CHOOSE_KEY.Shop then
        return
    end
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil then
        return
    end
    if self:GetShopSelectedBuyState(entry) ~= CardGameBlackjackUtils.ShopItemBuyState.Buy then
        return
    end
    self:_OnShopBuy(entry.ui.selectedIndex)
end



CardGameBlackjackSystem._CalcShopSlotSelectTarget = HL.Method(HL.Table, HL.Number, HL.Opt(HL.Boolean)).Return(HL.Number)
        << function(self, entry, index, isSelect)
    local curIndex = entry.ui.selectedIndex
    if isSelect == nil then
        return curIndex == index and 0 or index
    elseif isSelect then
        return index
    else
        return curIndex == index and 0 or curIndex
    end
end



CardGameBlackjackSystem._SetShopSlotSelected = HL.Method(HL.Table, HL.Number) << function(self, entry, index)
    local oldIndex = entry.ui.selectedIndex
    if oldIndex == index then
        return
    end
    entry.ui.selectedIndex = index
    
    self:_RefreshShopMainBtnOpNode()
    self:_RefreshShopMainRelicPreview()

    local ctrl = self:_GetShopSelectCtrl()
    if ctrl == nil then
        return
    end

    
    local oldCell = oldIndex > 0 and ctrl:GetItemCell(oldIndex) or nil
    if oldCell ~= nil then
        oldCell:SetSelectState(false, true)
    end
    local newCell = index > 0 and ctrl:GetItemCell(index) or nil
    if newCell ~= nil then
        newCell:SetSelectState(true, true)
    end
end



CardGameBlackjackSystem._OnShopMainSkip = HL.Method() << function(self)
    local topKey = self:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard then
        self:_SendChangeCardModify(true)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.GainCard then
        self:_SendGainCard(true)
    end
end




CardGameBlackjackSystem._RefreshShopMainOnSituationUpdate = HL.Method() << function(self)
    if not self:_IsShopMainPhase() then
        return
    end
    self:_RefreshShopMainAuthority()
    self:_RefreshShopItemCells()
end





CardGameBlackjackSystem._BuildShopPlayerInfos = HL.Method().Return(HL.Table) << function(self)
    local seatMemberIds = self.m_mirrorGlobal and self.m_mirrorGlobal.seatMemberIds or nil
    local seatCount = seatMemberIds and seatMemberIds.Count or 0
    local infos = {}
    for i = 0, seatCount - 1 do
        local memberId = seatMemberIds[i]
        local info = self:_BuildMemberDisplayInfo(memberId)
        info.memberId = memberId
        info.seatIndex = i + 1
        info.state = self:_GetShopPlayerState(memberId)
        info.isSelf = self:_IsSelfMemberId(memberId)
        infos[i + 1] = info
    end
    return infos
end


CardGameBlackjackSystem._GetShopPlayerState = HL.Method(HL.Any).Return(HL.String) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    if mirror ~= nil and mirror.hp <= 0 then
        return "Off"
    elseif self:IsMemberChosenDone(memberId) then
        return "Ready"
    end
    return "Wait"
end



CardGameBlackjackSystem._RefreshShopPlayerStates = HL.Method() << function(self)
    if self:GetShopUIChoose() == nil then
        return
    end
    local ctrl = self:_GetShopSelectCtrl()
    if ctrl == nil then
        return
    end
    local seatMemberIds = self.m_mirrorGlobal and self.m_mirrorGlobal.seatMemberIds or nil
    local seatCount = seatMemberIds and seatMemberIds.Count or 0
    for i = 0, seatCount - 1 do
        ctrl:RefreshPlayerState(i + 1, self:_GetShopPlayerState(seatMemberIds[i]))
    end
end







CardGameBlackjackSystem._PlayChooseInitialRelicReportThenOpenWindow = HL.Method(HL.Table, HL.Function)
        << function(self, item, onDone)
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl == nil then
        self:_OpenChooseByNotify(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic, item)
        onDone()
        return
    end
    self:_EnqueueAnim(function(finish)
        hudCtrl:PlayChooseInitialRelicReport(finish)
    end, function()
        local ctrl = self:_GetHudCtrl()
        if ctrl then
            ctrl:StopChooseInitialRelicReport()
        end
    end, function()
        self:_OpenChooseByNotify(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic, item)
        onDone()
    end)
end




CardGameBlackjackSystem._OpenInitialRelicWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    if self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop) ~= nil then
        
        logger.error("CardGameBlackjackSystem._OpenInitialRelicWindow: 商店窗口还在栈上")
    end

    self:_SetClientPhase(CLIENT_PHASE.InitialRelic)
    entry.ui.selectedIndex = 0
    
    entry.ui.chosen = false

    if not self:_OpenPhaseWithEnterGate(PhaseId.CardGameBlackjackShopMain, {}) then
        self:_SetClientPhase(CLIENT_PHASE.Idle)
        return false
    end
    return true
end




CardGameBlackjackSystem._RebindInitialRelicWindow = HL.Method(HL.Table) << function(self, entry)
    self:_RefreshInitialRelicItemList()
end




CardGameBlackjackSystem._CloseInitialRelicWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    self:_CloseShopPhaseUI(CLIENT_PHASE.InitialRelic, CLIENT_PHASE.Idle, isExitFast)
end


CardGameBlackjackSystem.BuildShopMainView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local entry = self:GetShopUIChoose()
    if entry == nil then
        return nil
    end
    return self:_BuildShopMainInfo(entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
end


CardGameBlackjackSystem.BuildShopSelectView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local entry = self:GetShopUIChoose()
    if entry == nil then
        return nil
    end

    local isInitialRelic = entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic
    local items
    if isInitialRelic then
        items = self:_SyncInitialRelicItems(entry)
    else
        self:_SyncShopSlots(entry)
        items = self:_BuildShopItems(entry)
    end
    if entry.ui.selectedIndex > #items then
        entry.ui.selectedIndex = 0
    end

    return {
        isChooseInitRelic = isInitialRelic,
        items = items,
        selectedIndex = entry.ui.selectedIndex,
        playerInfos = self:_BuildShopPlayerInfos(),
    }
end



CardGameBlackjackSystem.OnShopItemSelect = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, index, isSelect)
    local entry = self:GetShopUIChoose()
    if entry == nil then
        return
    end
    
    if isSelect ~= nil and self:GetChooseTopKey() ~= entry.key then
        return
    end
    if entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic then
        self:_OnInitialRelicSelect(index, isSelect)
    else
        self:_OnShopSelect(index, isSelect)
    end
end

CardGameBlackjackSystem.OnShopItemBuy = HL.Method(HL.Number) << function(self, index)
    local entry = self:GetShopUIChoose()
    if entry == nil then
        return
    end
    if entry.key == CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic then
        self:_OnInitialRelicChoose(index)
    else
        self:_OnShopBuy(index)
    end
end

CardGameBlackjackSystem.OnShopItemRefresh = HL.Method(HL.Number) << function(self, index)
    self:_OnInitialRelicRefreshItem(index)
end

CardGameBlackjackSystem.OnShopItemPin = HL.Method(HL.Number) << function(self, index)
    self:_OnShopPinItem(index)
end




CardGameBlackjackSystem._BuildInitialRelicItems = HL.Method(HL.Table).Return(HL.Table, HL.Table, HL.Table)
        << function(self, entry)
    local items = {}
    local candidates = {}
    local slotIndexes = {}

    
    
    
    local choice = self.m_roomData.initialRelicChoice
    local slots = choice.slots
    if slots.Count > 0 then
        for i = 0, slots.Count - 1 do
            local slot = slots[i]
            local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(slot.relicId)
            items[i + 1] = {
                isRelic = true,
                name = relicCfg.relicName,
                desc = relicCfg.relicDesc,
                icon = relicCfg.relicIcon,
                rarity = relicCfg.rarity,
                isExtraRelic = relicCfg.occupySlotCount == 0,
                
                canRefresh = slot.refreshUsed < choice.refreshLimit,
                isPin = false,
                hasPrice = false,
                buyState = CardGameBlackjackUtils.ShopItemBuyState.Gain,
            }
            candidates[i + 1] = slot.relicId
            slotIndexes[i + 1] = slot.slotIndex
        end
        return items, candidates, slotIndexes
    end

    local chooseData = entry.item.batch.chooseData
    local relicIds = chooseData ~= nil and chooseData.relicIds or nil
    for i = 0, (relicIds ~= nil and relicIds.Count or 0) - 1 do
        local relicId = relicIds[i]
        local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(relicId)
        items[i + 1] = {
            isRelic = true,
            name = relicCfg.relicName,
            desc = relicCfg.relicDesc,
            icon = relicCfg.relicIcon,
            rarity = relicCfg.rarity,
            isExtraRelic = relicCfg.occupySlotCount == 0,
            canRefresh = false,
            isPin = false,
            hasPrice = false,
            buyState = CardGameBlackjackUtils.ShopItemBuyState.Gain,
        }
        candidates[i + 1] = relicId
    end
    return items, candidates, slotIndexes
end



CardGameBlackjackSystem._OnInitialRelicSelect = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, index, isSelect)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil then
        return
    end
    self:_SetShopSlotSelected(entry, self:_CalcShopSlotSelectTarget(entry, index, isSelect))
end



CardGameBlackjackSystem._OnInitialRelicChoose = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil or entry.ui.chosen or self:_IsWaitingOpResult() then
        return
    end
    local candidate = entry.ui.candidates[index]
    if candidate == nil then
        return
    end
    local seqId = entry.item.seqId

    self:_SendOp(OpType.ChooseInitialRelic, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChooseInitialRelic(candidate, seqId)
    end)
end




CardGameBlackjackSystem._OnInitialRelicChooseResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 选初始遗物被拒绝, errCode=" .. tostring(errCode))
        return
    end

    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil then
        return
    end
    entry.ui.chosen = true
end



CardGameBlackjackSystem._OnInitialRelicRefreshItem = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil or entry.ui.chosen then
        return
    end
    local slotIndex = entry.ui.slotIndexes[index]
    local seqId = entry.item.seqId
    if slotIndex == nil then
        return
    end
    
    if not self.m_roomData.initialRelicChoice:CanRefreshSlot(slotIndex) then
        return
    end

    
    self:_SendOp(OpType.RefreshInitialRelic, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackRefreshInitialRelic(slotIndex, seqId)
    end, index)
end





CardGameBlackjackSystem._OnInitialRelicRefreshResult = HL.Method(HL.Number, HL.Number)
        << function(self, index, errCode)
    if errCode ~= 0 then
        logger.info("CardGameBlackjackSystem 刷新初始遗物候选被拒绝, index=" .. tostring(index)
                .. ", errCode=" .. tostring(errCode))
        return
    end

    self:_RefreshInitialRelicItemCell(index)
end



CardGameBlackjackSystem._SyncInitialRelicItems = HL.Method(HL.Table).Return(HL.Table) << function(self, entry)
    local items, candidates, slotIndexes = self:_BuildInitialRelicItems(entry)
    entry.ui.candidates = candidates
    entry.ui.slotIndexes = slotIndexes
    return items
end


CardGameBlackjackSystem._RefreshInitialRelicItemList = HL.Method() << function(self)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil or not entry.opened then
        return
    end
    local items = self:_SyncInitialRelicItems(entry)
    entry.ui.selectedIndex = 0

    local ctrl = self:_GetShopSelectCtrl()
    if ctrl == nil then
        return
    end
    ctrl:RefreshItemList(items, entry.ui.selectedIndex)
end


CardGameBlackjackSystem._RefreshInitialRelicItemCell = HL.Method(HL.Number) << function(self, index)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.InitialRelic)
    if entry == nil or not entry.opened then
        return
    end
    local items = self:_SyncInitialRelicItems(entry)
    if entry.ui.selectedIndex == index then
        entry.ui.selectedIndex = 0
    end

    local ctrl = self:_GetShopSelectCtrl()
    local item = items[index]
    if ctrl == nil or item == nil then
        return
    end
    ctrl:RefreshItemCell(index, item, entry.ui.selectedIndex == index)
end





CardGameBlackjackSystem._OpenShopWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    
    self.m_spectateCountDown = nil
    if self.m_effectReportInfo ~= nil then
        
        self:_ClearEffectReportInfoAndNotifyHide()
    end
    
    if self:IsSelfGameOut() then
        self:_CloseRoundSettle(true)
        self:_KeepSpectateCountDown(entry)
        self:_SetClientPhase(CLIENT_PHASE.ShopWait)
        return false
    end
    self:_SetClientPhase(CLIENT_PHASE.Shop)
    entry.ui.selectedIndex = 0
    self:_ResetShopSlots(entry)

    self:_CloseRoundSettle(true)
    if not self:_OpenPhaseWithEnterGate(PhaseId.CardGameBlackjackShopMain, {}) then
        
        self:_KeepSpectateCountDown(entry)
        self:_SetClientPhase(CLIENT_PHASE.ShopWait)
        return false
    end
    return true
end



CardGameBlackjackSystem._CloseShopWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    
    self:_CloseShopPhaseUI(CLIENT_PHASE.Shop, CLIENT_PHASE.ShopWait, isExitFast)
    
    if self.m_inGame then
        AudioManager.PostEvent(self.m_isFinalMusicPlayed
                and "au_music_gambling_v1d7_blackjack_final"
                or "au_music_gambling_v1d7_blackjack_normal")
    end
end


CardGameBlackjackSystem._ResetShopSlots = HL.Method(HL.Table) << function(self, entry)
    local slots = {}
    local shopItems = self.m_roomData.shop.items
    for i = 0, shopItems.Count - 1 do
        slots[i + 1] = { shopItem = shopItems[i], isEmpty = false }
    end
    entry.ui.slots = slots
end


CardGameBlackjackSystem._SyncShopSlots = HL.Method(HL.Table) << function(self, entry)
    local latestById = {}
    local shopItems = self.m_roomData.shop.items
    for i = 0, shopItems.Count - 1 do
        latestById[shopItems[i].shelfItemId] = shopItems[i]
    end
    for index, slot in ipairs(entry.ui.slots) do
        local latest = latestById[slot.shopItem.shelfItemId]
        if latest ~= nil then
            slot.shopItem = latest
        elseif not slot.isEmpty then
            slot.isEmpty = true
            if entry.ui.selectedIndex == index then
                entry.ui.selectedIndex = 0
            end
        end
    end
end


CardGameBlackjackSystem._BuildShopItems = HL.Method(HL.Table).Return(HL.Table) << function(self, entry)
    local items = {}
    local selfMember = self.m_roomData:GetBlackjackSelfMember()
    for index, slot in ipairs(entry.ui.slots) do
        local shopItem = slot.shopItem
        local buyState = self:_CalcShopItemBuyState(shopItem, selfMember)
        if CardGameBlackjackUtils.IsBlackjackRelicShopGoodsType(shopItem.slotType) then
            local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(shopItem.itemId)
            items[index] = {
                isRelic = true,
                name = relicCfg.relicName,
                desc = relicCfg.relicDesc,
                icon = relicCfg.relicIcon,
                rarity = relicCfg.rarity,
                isExtraRelic = relicCfg.occupySlotCount == 0,
                
                canRefresh = false,
                isPin = shopItem.pinned,
                hasPrice = true,
                buyState = buyState,
                curPrice = shopItem.finalPrice,
                originPrice = shopItem.originalPrice,
                isEmpty = slot.isEmpty,
            }
        else
            local shopGoodsCfg = CardGameBlackjackUtils.GetBlackjackShopGoodsCfgByIntId(shopItem.goodsId)
            items[index] = {
                isRelic = false,
                name = shopGoodsCfg.name,
                desc = shopGoodsCfg.desc,
                icon = shopGoodsCfg.icon,
                isPin = shopItem.pinned,
                buyState = buyState,
                curPrice = shopItem.finalPrice,
                originPrice = shopItem.originalPrice,
                isEmpty = slot.isEmpty,
            }
        end
    end
    return items
end


CardGameBlackjackSystem._OnShopSelect = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, index, isSelect)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or entry.ui.slots[index].isEmpty then
        return
    end
    self:_SetShopSlotSelected(entry, self:_CalcShopSlotSelectTarget(entry, index, isSelect))
end


CardGameBlackjackSystem._OnShopBuy = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or entry.ui.slots[index].isEmpty then
        return
    end
    local candidate = entry.ui.slots[index].shopItem
    local seqId = entry.item.seqId
    if not CardGameBlackjackUtils.IsBlackjackRelicShopGoodsType(candidate.slotType) then
        local shopGoodsCfg = CardGameBlackjackUtils.GetBlackjackShopGoodsCfgByIntId(candidate.goodsId)
        self.m_gainCardPackIcon = shopGoodsCfg and shopGoodsCfg.icon or nil
    end

    
    
    self:_SendOp(OpType.BuyGoods, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackBuyGoods(candidate, seqId)
    end, index)
end



CardGameBlackjackSystem._OnShopBuyGoodsResult = HL.Method(HL.Number, HL.Number) << function(self, index, errCode)
    if errCode ~= 0 then
        logger.info("CardGameBlackjackSystem 购买被拒绝, index=" .. tostring(index)
                .. ", errCode=" .. tostring(errCode))
        self.m_gainCardPackIcon = nil
        return
    end
    self:_RefreshShopItemCells()
    CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.ShopByOneGoods)
end


CardGameBlackjackSystem._CalcShopItemBuyState = HL.Method(HL.Any, HL.Any).Return(HL.String)
        << function(self, shopItem, selfMember)
    
    local moneyEnough = selfMember.gold >= shopItem.finalPrice
    if not moneyEnough then
        return CardGameBlackjackUtils.ShopItemBuyState.NoMoney
    end
    
    if CardGameBlackjackUtils.IsBlackjackRelicShopGoodsType(shopItem.slotType) then
        local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(shopItem.itemId)
        if relicCfg.occupySlotCount > 0 and selfMember.relicSlotUsedLimit >= selfMember.relicSlotMaxLimit then
            return CardGameBlackjackUtils.ShopItemBuyState.Max
        end
    end
    
    return CardGameBlackjackUtils.ShopItemBuyState.Buy
end



CardGameBlackjackSystem._RefreshShopItemCells = HL.Method() << function(self)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or not entry.opened then
        return
    end
    local oldSelectedIndex = entry.ui.selectedIndex
    self:_SyncShopSlots(entry)
    if entry.ui.selectedIndex ~= oldSelectedIndex then
        self:_RefreshShopMainRelicPreview()
    end
    
    self:_RefreshShopMainBtnOpNode()

    local ctrl = self:_GetShopSelectCtrl()
    if ctrl == nil then
        return
    end
    local selfMember = self.m_roomData:GetBlackjackSelfMember()
    for index, slot in ipairs(entry.ui.slots) do
        local cell = ctrl:GetItemCell(index)
        local shopItem = slot.shopItem
        if slot.isEmpty then
            cell:SetSelectState(false)
            cell:SetEmptyState(true)
        else
            cell:RefreshPrice(shopItem.finalPrice, shopItem.originalPrice)
            cell:SetPinState(shopItem.pinned)
            cell:SetBuyState(self:_CalcShopItemBuyState(shopItem, selfMember))
        end
    end
end



CardGameBlackjackSystem._OnShopPinItem = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or entry.ui.slots[index].isEmpty then
        return
    end
    local candidate = entry.ui.slots[index].shopItem
    local seqId = entry.item.seqId

    local pinned = not candidate.pinned
    self:_SendOp(OpType.SetShopItemPin, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackSetShopItemPin(candidate, pinned, seqId)
    end, index)
end

CardGameBlackjackSystem._OnShopSetPinResult = HL.Method(HL.Number, HL.Number) << function(self, index, errCode)
    if errCode ~= 0 then
        logger.info("CardGameBlackjackSystem pin 被拒绝, index=" .. tostring(index)
                .. ", errCode=" .. tostring(errCode))
        return
    end
    self:_RefreshShopItemCells()
end



CardGameBlackjackSystem._OnShopRefreshShop = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil then
        return
    end
    local seqId = entry.item.seqId

    local selfMember = self.m_roomData:GetBlackjackSelfMember()
    if selfMember == nil then
        return
    end
    if selfMember.gold < self.m_roomData.shop.refreshCost then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CARD_GAME_SHOP_REFRESH_NO_MONEY)
        return
    end

    self:_SendOp(OpType.RefreshShop, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackRefreshShop(seqId)
    end)
end



CardGameBlackjackSystem._OnShopRefreshShopResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 then
        logger.info("CardGameBlackjackSystem 刷新货架被拒绝, errCode=" .. tostring(errCode))
        return
    end

    self:_RefreshShopItemList(true)
    self:_RefreshShopMainInfo()
end



CardGameBlackjackSystem._RefreshShopItemList = HL.Method(HL.Opt(HL.Boolean)) << function(self, isRefreshShop)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or not entry.opened then
        return
    end
    self:_ResetShopSlots(entry)
    local ctrl = self:_GetShopSelectCtrl()
    
    local naviIndex = ctrl ~= nil and ctrl:GetNaviTargetItemIndex() or 0
    if naviIndex > #entry.ui.slots then
        naviIndex = 0
    end
    entry.ui.selectedIndex = naviIndex
    self:_RefreshShopMainRelicPreview()

    if ctrl == nil then
        return
    end
    ctrl:RefreshItemList(self:_BuildShopItems(entry), entry.ui.selectedIndex, isRefreshShop)
end



CardGameBlackjackSystem._OnShopFinish = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end

    local seqId = entry.item.seqId
    self:_SendOp(OpType.FinishShop, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackFinishShop(seqId)
    end)
end



CardGameBlackjackSystem._OnShopFinishResult = HL.Method(HL.Opt(HL.Any, HL.Number)) << function(self, opArg, errCode)
    if errCode ~= 0 then
        logger.info("CardGameBlackjackSystem 结束购物被拒绝, errCode=" .. tostring(errCode))
        return
    end
    
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    if entry ~= nil then
        self:_KeepSpectateCountDown(entry)
    end
    self:_PopChooseFrom(CardGameBlackjackUtils.CHOOSE_KEY.Shop)
    
    if entry ~= nil and self.m_clientPhase == CLIENT_PHASE.ShopWait then
        self:_RefreshHudForShopWait()
    end
end




CardGameBlackjackSystem._RefreshHudForShopWait = HL.Method() << function(self)
    self:_RefreshHudDeckForShopWait()
    local mirror = self:_GetSeatMirror(1)
    if mirror == nil then
        return
    end
    self:_RefreshModGoldForHud(1, mirror.gold)
    self:_RefreshModHPForHud(1, mirror.hp)
end


CardGameBlackjackSystem._RefreshHudDeckForShopWait = HL.Method() << function(self)
    for hudSeat = 1, self:_GetSeatCount() do
        self:_RefreshHudCardDeckCount(hudSeat)
        self:_ResyncSeatDeckVisual(hudSeat, true)
    end
end







CardGameBlackjackSystem._OpenChangeCardWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    local phase = self:_GetShopPhase()
    if phase == nil then
        
        
        logger.error("CardGameBlackjackSystem._OpenChangeCardWindow: 商店 Phase 不在，本条选择放弃开窗")
        return false
    end

    
    entry.ui.selectedEffectIndex = 1
    entry.ui.selectedCardIndex = 0

    phase:OpenShopChangeCardPanel(nil)
    self:_RefreshShopMainBtnOpNode()

    return true
end



CardGameBlackjackSystem._CloseChangeCardWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    local phase = self:_GetShopPhase()
    if phase ~= nil then
        phase:CloseShopChangeCardPanel()
    end
    self:_RefreshShopMainBtnOpNode()
end


CardGameBlackjackSystem.BuildChangeCardView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard)
    if entry == nil then
        return nil
    end
    local chooseData = entry.item.batch.chooseData
    return {
        changeTypeInfos = self:_BuildChangeCardTypeInfos(chooseData),
        pokerInfo = self:_BuildPokerDisplayInfos(self:_BuildChooseCardList(chooseData)),
        selectedEffectIndex = entry.ui.selectedEffectIndex or 1,
        selectedCardIndex = entry.ui.selectedCardIndex or 0,
    }
end



CardGameBlackjackSystem._GetChooseCard = HL.Method(HL.Table, HL.Number).Return(HL.Opt(HL.Any))
        << function(self, entry, index)
    local chooseData = entry.item.batch.chooseData
    local cards = chooseData ~= nil and chooseData.cards or nil
    if cards == nil or index <= 0 or index > cards.Count then
        return nil
    end
    return cards[index - 1]
end


CardGameBlackjackSystem._GetChangeCardEffectId = HL.Method(HL.Table, HL.Number).Return(HL.Opt(HL.Number))
        << function(self, entry, index)
    local chooseData = entry.item.batch.chooseData
    local effectIds = chooseData ~= nil and chooseData.modifyEffectIds or nil
    if effectIds == nil or index <= 0 or index > effectIds.Count then
        return nil
    end
    return effectIds[index - 1]
end


CardGameBlackjackSystem._BuildChooseCardList = HL.Method(HL.Opt(HL.Any)).Return(HL.Table)
        << function(self, chooseData)
    local result = {}
    local cards = chooseData ~= nil and chooseData.cards or nil
    if cards == nil then
        return result
    end
    for i = 0, cards.Count - 1 do
        result[i + 1] = cards[i]
    end
    return result
end

CardGameBlackjackSystem._BuildChangeCardTypeInfos = HL.Method(HL.Opt(HL.Any)).Return(HL.Table)
        << function(self, chooseData)
    local infos = {}
    local effectIds = chooseData ~= nil and chooseData.modifyEffectIds or nil
    if effectIds == nil then
        return infos
    end
    for i = 0, effectIds.Count - 1 do
        local cfg = CardGameBlackjackUtils.GetBlackjackCardChangeCfgByIntId(effectIds[i])
        infos[i + 1] = {
            icon = cfg and cfg.icon or "",
            name = cfg and cfg.name or "",
            desc = cfg and cfg.desc or "",
        }
    end
    return infos
end


CardGameBlackjackSystem._BuildPokerDisplayInfos = HL.Method(HL.Table).Return(HL.Table) << function(self, cards)
    local infos = {}
    for i = 1, #cards do
        local card = cards[i]
        infos[i] = {
            suit = card.suit,
            rank = card.rank,
            style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
        }
    end
    return infos
end

CardGameBlackjackSystem._OnChangeCardSelectEffect = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard)
    if entry == nil or self:_GetChangeCardEffectId(entry, index) == nil then
        return
    end
    entry.ui.selectedEffectIndex = index
    self:_RefreshShopMainBtnOpNode()
end


CardGameBlackjackSystem._OnChangeCardSelectCard = HL.Method(HL.Number) << function(self, index)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard)
    if entry == nil then
        return
    end
    if index ~= 0 and self:_GetChooseCard(entry, index) == nil then
        return
    end
    entry.ui.selectedCardIndex = index
    self:_RefreshShopMainBtnOpNode()
end



CardGameBlackjackSystem.IsChangeCardSelectionRedundant = HL.Method(HL.Table).Return(HL.Boolean)
        << function(self, entry)
    local card = self:_GetChooseCard(entry, entry.ui.selectedCardIndex)
    local effectId = self:_GetChangeCardEffectId(entry, entry.ui.selectedEffectIndex)
    if card == nil or effectId == nil then
        return false
    end
    local cfg = CardGameBlackjackUtils.GetBlackjackCardChangeCfgByIntId(effectId)
    if cfg == nil then
        return false
    end

    local changeType = cfg.cardChangeType
    if changeType == CardChangeType.Rank then
        return card.rank == cfg.rank
    elseif changeType == CardChangeType.Suit then
        return CardSuit.__CastFrom(card.suit) == cfg.suit
    elseif changeType == CardChangeType.Enhance then
        return CardEnhance.__CastFrom(card.enhance) == cfg.enhanceType
    end
    
    return false
end


CardGameBlackjackSystem._OnChangeCardConfirm = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard)
    if entry == nil or entry.ui.selectedCardIndex <= 0 or self:IsChangeCardSelectionRedundant(entry) then
        return
    end
    self:_SendChangeCardModify(false)
end



CardGameBlackjackSystem._SendChangeCardModify = HL.Method(HL.Boolean) << function(self, skip)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end

    local effectId = 0
    local cardId = 0
    if not skip then
        effectId = self:_GetChangeCardEffectId(entry, entry.ui.selectedEffectIndex) or 0
        local card = self:_GetChooseCard(entry, entry.ui.selectedCardIndex)
        cardId = card and card.id or 0
        if effectId == 0 or cardId == 0 then
            return
        end
    end

    local seqId = entry.item.seqId
    self:_SendOp(OpType.ChooseCardModify, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChooseCardModify(effectId, cardId, seqId, skip)
    end)
end



CardGameBlackjackSystem._OnChangeCardModifyResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 卡牌变化被拒绝, errCode=" .. tostring(errCode))
        self:_RefreshShopMainBtnOpNode()
    end
end







CardGameBlackjackSystem._OpenGainCardWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    local phase = self:_GetShopPhase()
    if phase == nil then
        
        
        logger.error("CardGameBlackjackSystem._OpenGainCardWindow: 商店 Phase 不在，本条选择放弃开窗")
        return false
    end

    entry.ui.selectedIndexes = {}

    phase:OpenCardPackPanel(nil)
    self:_RefreshShopMainBtnOpNode()
    return true
end



CardGameBlackjackSystem._CloseGainCardWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    self.m_gainCardPackIcon = nil
    local phase = self:_GetShopPhase()
    if phase ~= nil then
        phase:CloseCardPackPanel()
    end
    self:_RefreshShopMainBtnOpNode()
end


CardGameBlackjackSystem.GetGainCardMaxSelectNum = HL.Method(HL.Table).Return(HL.Number) << function(self, entry)
    local chooseData = entry.item.batch.chooseData
    return chooseData ~= nil and chooseData.cardGainMaxCount or 0
end


CardGameBlackjackSystem.BuildGainCardView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.GainCard)
    if entry == nil then
        return nil
    end
    local maxSelectNum = self:GetGainCardMaxSelectNum(entry)
    return {
        desc = string.format(Language.LUA_CARD_GAME_BLACKJACK_GAIN_CARD_DESC, maxSelectNum),
        maxSelectNum = maxSelectNum,
        pokerInfo = self:_BuildPokerDisplayInfos(self:_BuildChooseCardList(entry.item.batch.chooseData)),
        selectedIndexes = entry.ui.selectedIndexes or {},
        cardPackIcon = self.m_gainCardPackIcon,
    }
end


CardGameBlackjackSystem._OnGainCardSelectCard = HL.Method(HL.Number, HL.Boolean) << function(self, index, isSelect)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.GainCard)
    if entry == nil or self:_GetChooseCard(entry, index) == nil then
        return
    end

    local selected = entry.ui.selectedIndexes
    for i = 1, #selected do
        if selected[i] == index then
            if not isSelect then
                table.remove(selected, i)
            end
            self:_RefreshShopMainBtnOpNode()
            return
        end
    end
    if isSelect then
        table.insert(selected, index)
    end
    self:_RefreshShopMainBtnOpNode()
end


CardGameBlackjackSystem._OnGainCardConfirm = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.GainCard)
    if entry == nil then
        return
    end
    local selectNum = #entry.ui.selectedIndexes
    if selectNum <= 0 or selectNum > self:GetGainCardMaxSelectNum(entry) then
        return
    end
    self:_SendGainCard(false)
end



CardGameBlackjackSystem._SendGainCard = HL.Method(HL.Boolean) << function(self, skip)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.GainCard)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end

    local cardIds = {}
    if not skip then
        for _, index in ipairs(entry.ui.selectedIndexes) do
            local card = self:_GetChooseCard(entry, index)
            if card ~= nil and card.id ~= 0 then
                table.insert(cardIds, card.id)
            end
        end
        if #cardIds == 0 then
            return
        end
    end

    
    local seqId = entry.item.seqId
    self:_SendOp(OpType.ChooseCardGain, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChooseCardGain(cardIds, seqId)
    end)
end



CardGameBlackjackSystem._OnGainCardResult = HL.Method(HL.Opt(HL.Any, HL.Number)) << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 开卡包选牌被拒绝, errCode=" .. tostring(errCode))
        self:_RefreshShopMainBtnOpNode()
    end
end






CardGameBlackjackSystem._OpenChooseAttributeWindow = HL.Method(HL.Table).Return(HL.Boolean)
        << function(self, entry)
    local attribute = self:_GetChooseAttributeType(entry)
    if attribute ~= ChooseAttributeType.Suit:ToInt() then
        logger.error("CardGameBlackjackSystem._OpenChooseAttributeWindow: 目前只支持花色，跳过开窗, attribute="
                .. tostring(attribute))
        return false
    end
    local phase = self:_GetShopPhase()
    if phase == nil then
        
        
        logger.error("CardGameBlackjackSystem._OpenChooseAttributeWindow: 商店 Phase ���在，本条选择放弃开窗")
        return false
    end

    entry.ui.selectedSuit = 0

    phase:OpenSelectChangePanel(nil)
    self:_RefreshShopMainBtnOpNode()
    return true
end



CardGameBlackjackSystem._CloseChooseAttributeWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    local phase = self:_GetShopPhase()
    if phase ~= nil then
        phase:CloseSelectChangePanel()
    end
    self:_RefreshShopMainBtnOpNode()

    self:_HideEffectReportIfShop()
end


CardGameBlackjackSystem._GetChooseAttributeType = HL.Method(HL.Table).Return(HL.Number) << function(self, entry)
    local chooseData = entry.item.batch.chooseData
    return chooseData ~= nil and chooseData.attribute or 0
end


CardGameBlackjackSystem.BuildSelectChangeView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if self:GetChooseTopKey() ~= CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr then
        return nil
    end
    local entry = self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr)
    if entry == nil then
        return nil
    end
    return {
        chooseType = ChooseAttributeType.__CastFrom(self:_GetChooseAttributeType(entry)),
        selectedSuit = entry.ui.selectedSuit or 0,
    }
end


CardGameBlackjackSystem._OnChooseAttributeSelectSuit = HL.Method(CardSuit) << function(self, suit)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr)
    if entry == nil then
        return
    end
    entry.ui.selectedSuit = suit:ToInt()
    self:_RefreshShopMainBtnOpNode()
end


CardGameBlackjackSystem._SendChooseAttribute = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end
    local value = entry.ui.selectedSuit
    if value <= 0 then
        return
    end
    local attribute = self:_GetChooseAttributeType(entry)

    
    local seqId = entry.item.seqId
    self:_SendOp(OpType.ChooseAttribute, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChooseAttribute(attribute, value, seqId)
    end)
end


CardGameBlackjackSystem._OnChooseAttributeResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 选属性被拒绝, errCode=" .. tostring(errCode))
        self:_RefreshShopMainBtnOpNode()
    end
end


CardGameBlackjackSystem.GetLastAppliedChooseSuit = HL.Method().Return(HL.Number) << function(self)
    local roomData = self.m_roomData
    if roomData == nil or roomData.lastChooseAttribute ~= ChooseAttributeType.Suit:ToInt() then
        return 0
    end
    return roomData.lastChooseAttributeValue
end




CardGameBlackjackSystem.GetSelfDeckSuitCounts = HL.Method().Return(HL.Table) << function(self)
    local counts = {}
    for suit = 1, 4 do
        counts[suit] = 0
    end
    local selfMember = self.m_roomData ~= nil and self.m_roomData:GetBlackjackSelfMember() or nil
    if selfMember == nil then
        return counts
    end

    
    local countedIds = {}
    local addDeck = function(deck)
        for i = 0, (deck and deck.Count or 0) - 1 do
            local card = deck[i]
            local suit = card.suit
            if counts[suit] ~= nil and not countedIds[card.id] then
                countedIds[card.id] = true
                counts[suit] = counts[suit] + 1
            end
        end
    end
    if self.m_clientPhase == CLIENT_PHASE.Battle then
        addDeck(selfMember.remainingDeckSorted)
        addDeck(selfMember.shownDeck)
    else
        addDeck(selfMember.sortedDeck)
    end
    return counts
end





local HUD_CHOOSE_KEYS = {
    [CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard] = true,
    [CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard] = true,
}


CardGameBlackjackSystem._GetHudChooseEntry = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    for i = #self.m_chooseStack, 1, -1 do
        local entry = self.m_chooseStack[i]
        if HUD_CHOOSE_KEYS[entry.key] then
            return entry
        end
    end
    return nil
end

CardGameBlackjackSystem._BuildHudChooseView = HL.Method(HL.Table).Return(HL.Table) << function(self, entry)
    return {
        chooseKey = entry.key,
        cardInfos = self:_BuildPokerDisplayInfos(self:_BuildChooseCardList(entry.item.batch.chooseData)),
        selectedIndex = entry.ui.selectedIndex,
    }
end


CardGameBlackjackSystem.BuildHudChooseSelfPlayerView = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local entry = self:_GetHudChooseEntry()
    if entry == nil then
        return nil
    end
    return self:_BuildHudChooseView(entry)
end


CardGameBlackjackSystem._OpenHudChooseSelfPlayer = HL.Method(HL.Table) << function(self, entry)
    entry.ui.selectedIndex = 0
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:OpenHudChooseSelfPlayer(self:_BuildHudChooseView(entry), true)
    end
end

CardGameBlackjackSystem._CloseHudChooseSelfPlayer = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:CloseHudChooseSelfPlayer()
    end
end


CardGameBlackjackSystem.OnHudChooseSelectCard = HL.Method(HL.Number) << function(self, index)
    
    if self:_IsCurWaitingOp(OpType.ChoosePreviewCard) then
        return
    end
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard)
    if entry == nil or self:_GetChooseCard(entry, index) == nil then
        return
    end
    local oldIndex = entry.ui.selectedIndex
    if oldIndex == index then
        return
    end
    entry.ui.selectedIndex = index
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:RefreshHudChooseSelectedCard(oldIndex, index)
    end
end

CardGameBlackjackSystem.OnHudChooseConfirm = HL.Method() << function(self)
    local topKey = self:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard then
        self:_SendChoosePreviewCard()
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard then
        
        self:_SendChooseDestroyCard(false)
    end
end


CardGameBlackjackSystem.OnHudChooseCancel = HL.Method() << function(self)
    if self:GetChooseTopKey() == CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard then
        self:_SendChooseDestroyCard(true)
    end
end






CardGameBlackjackSystem._OpenPreviewCardWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    if self:_GetChooseCard(entry, 1) == nil then
        
        logger.error("CardGameBlackjackSystem._OpenPreviewCardWindow: 候选牌为空，跳过开窗")
        return false
    end

    self:_OpenHudChooseSelfPlayer(entry)
    return true
end


CardGameBlackjackSystem._ClosePreviewCardWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    self:_CloseHudChooseSelfPlayer()
    self:_HideEffectReportIfShop()
end


CardGameBlackjackSystem._SendChoosePreviewCard = HL.Method() << function(self)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end
    local card = self:_GetChooseCard(entry, entry.ui.selectedIndex)
    if card == nil then
        return
    end

    
    local seqId = entry.item.seqId
    self:_SendOp(OpType.ChoosePreviewCard, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChoosePreviewCard(card.id, seqId)
    end)
end



CardGameBlackjackSystem._OnPreviewCardResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 观星选牌被拒绝, errCode=" .. tostring(errCode))
        return
    end
end







CardGameBlackjackSystem._OpenDestroyCardWindow = HL.Method(HL.Table).Return(HL.Boolean) << function(self, entry)
    if self:_GetChooseCard(entry, 1) == nil then
        
        
        logger.error("CardGameBlackjackSystem._OpenDestroyCardWindow: 没有下发候选牌，跳过开窗")
        return false
    end

    self:_OpenHudChooseSelfPlayer(entry)
    return true
end


CardGameBlackjackSystem._CloseDestroyCardWindow = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, entry, isExitFast)
    self:_CloseHudChooseSelfPlayer()
end


CardGameBlackjackSystem._SendChooseDestroyCard = HL.Method(HL.Boolean) << function(self, destroy)
    local entry = self:_GetActiveChoose(CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard)
    if entry == nil or self:_IsWaitingOpResult() then
        return
    end

    
    local seqId = entry.item.seqId
    self:_SendOp(OpType.ChooseDestroyCard, function()
        GameInstance.player.multiplayerPlayRoomSystem:SendBlackjackChooseDestroyCard(destroy, seqId)
    end)
end


CardGameBlackjackSystem._OnDestroyCardResult = HL.Method(HL.Opt(HL.Any, HL.Number))
        << function(self, opArg, errCode)
    if errCode ~= 0 and errCode ~= CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER then
        logger.info("CardGameBlackjackSystem 弃置回溯牌被拒绝, errCode=" .. tostring(errCode))
    end
end






CardGameBlackjackSystem._PlayRoundSettlePresentation = HL.Method(HL.Table, HL.Function) << function(self, item, onDone)
    local arg = self:_BuildRoundSettleArg()
    if arg == nil then
        logger.error("CardGameBlackjackSystem._PlayRoundSettlePresentation: 拿不到本轮结算数据，跳过结算界面")
        self.m_aniQueue:EnqueueFinallyAction(function()
            self:_ApplyBatchData(item)
            self:_RefreshHudAfterRoundSettle()
            self:_EndRoundSettlePhase()
            onDone()
        end)
        return
    end

    self.m_aniQueue:Enqueue(function(finish)
        arg.roundSettleFinish = function()
            
            
            if arg.isWatch and not arg.isGameOver then
                self:_CloseRoundSettle(true)
            else
                self:_StartRoundSettleEndWaitTimer()
            end
            finish()
        end
        UIManager:Open(ROUND_SETTLE_PANEL_ID, arg)
    end)
    self.m_aniQueue:EnqueueFinallyAction(function()
        self:_ApplyBatchData(item)
        self:_RefreshHudAfterRoundSettle()
        self:_EndRoundSettlePhase()
        onDone()
    end)
end


CardGameBlackjackSystem._EndRoundSettlePhase = HL.Method() << function(self)
    if self.m_clientPhase == CLIENT_PHASE.RoundSettle then
        self:_SetClientPhase(CLIENT_PHASE.RoundEndWait)
    end
end



CardGameBlackjackSystem._StartRoundSettleEndWaitTimer = HL.Method() << function(self)
    self.m_roundSettleEndWaitTimer = self:_ClearTimer(self.m_roundSettleEndWaitTimer)
    if self:_IsNewbieGuideRoom() then
        return
    end
    self.m_roundSettleEndWaitTimer = self:_StartTimer(ROUND_SETTLE_END_WAIT_CLOSE_TIME, function()
        self.m_roundSettleEndWaitTimer = -1
        self:_CloseRoundSettle(true)
    end, true)
end


CardGameBlackjackSystem._RefreshHudAfterRoundSettle = HL.Method() << function(self)
    for hudSeat = 1, self:_GetSeatCount() do
        local mirror = self:_GetSeatMirror(hudSeat)
        if mirror ~= nil then
            self:_RefreshModHPForHud(hudSeat, mirror.hp)
        end
    end
    self:_RefreshHudPointInfoStates()
    self:_RefreshHudPlayerOptInfos()
end


CardGameBlackjackSystem._CloseRoundSettle = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAni)
    self.m_roundSettleEndWaitTimer = self:_ClearTimer(self.m_roundSettleEndWaitTimer)
    local isOpen, ctrl = UIManager:IsOpen(ROUND_SETTLE_PANEL_ID)
    if not isOpen then
        return
    end
    if skipAni then
        UIManager:Close(ROUND_SETTLE_PANEL_ID)
    else
        ctrl:PlayAnimationOutAndClose()
    end
end





CardGameBlackjackSystem._BuildRoundSettleArg = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local roomData = self.m_roomData
    local settlements = roomData and roomData.roundSettlements or nil
    if settlements == nil or settlements.Count <= 0 then
        return nil
    end

    local curRound = self:GetGameRound()
    local settleInfos = {}
    local infoByMemberId = {}
    local aliveCount = 0
    for i = 0, settlements.Count - 1 do
        local settlement = settlements[i]
        local memberId = settlement.memberId
        local info = self:_BuildRoundSettleInfo(settlement)
        settleInfos[#settleInfos + 1] = info
        infoByMemberId[memberId] = info
        if info.isSelf then
            self:_RecordSelfMaxRoundScore(settlement)
        end
        if info.gameOutRound == 0 then
            aliveCount = aliveCount + 1
        end
        
        if info.gameOutRound == curRound then
            self.m_eliminatedSettleInfos[memberId] = self:_BuildEliminatedSettleInfo(info)
        end
    end

    
    for memberId, info in pairs(self.m_eliminatedSettleInfos) do
        if infoByMemberId[memberId] == nil then
            settleInfos[#settleInfos + 1] = info
            infoByMemberId[memberId] = info
        end
    end

    
    local selfSettleInfo = infoByMemberId[roomData.selfMemberId]
    if selfSettleInfo == nil then
        logger.error("CardGameBlackjackSystem._BuildRoundSettleArg: 结算数据里没有自己")
        return nil
    end

    
    if selfSettleInfo.gameOutRound == curRound then
        self.m_selfEliminatedResult = {
            rank = aliveCount + 1,
            gold = selfSettleInfo.moneyNum,
        }
    end

    local isGameOver = self:_IsGameOverAfterRoundSettle(aliveCount)
    
    if not self.m_isFinalMusicPlayed and aliveCount == 2 and not isGameOver then
        self.m_isFinalMusicPlayed = true
        AudioManager.PostEvent("au_music_gambling_v1d7_blackjack_final")
    end

    return {
        curRound = curRound,
        settleInfos = settleInfos,
        
        selfSettleInfo = selfSettleInfo,
        
        isWatch = selfSettleInfo.gameOutRound ~= 0,
        isGameOver = isGameOver,
    }
end

CardGameBlackjackSystem._BuildRoundSettleInfo = HL.Method(HL.Any).Return(HL.Table) << function(self, settlement)
    local memberId = settlement.memberId
    local rank = settlement.rank == 0 and CardGameBlackjackUtils.MAX_SEAT_COUNT or settlement.rank   
    local displayInfo = self:_BuildMemberDisplayInfo(memberId)
    local point = settlement.points
    if not settlement.isBust then
        
        point = point - settlement.additionalPoints
    end
    return {
        seatIndex = self:_GetActualSeatIndexByMemberId(memberId),
        memberId = memberId,
        nickname = displayInfo.nickname,
        displayInfo = displayInfo,
        isSelf = self:_IsSelfMemberId(memberId),
        isAi = displayInfo.isAI,
        
        rank = rank,
        displayRank = rank,
        
        point = point,
        extraPoint = settlement.additionalPoints,
        isBust = settlement.isBust,
        
        gameOutRound = settlement.eliminatedRound,
        
        hp = settlement.hp,
        maxHp = Tables.cardGameBlackjackConst.initialHp,
        
        hpDelta = math.abs(settlement.hpDelta),
        moneyNum = settlement.gold,
        moneyDelta = settlement.goldDelta,
        handZoneCardInfos = self:_BuildRoundSettleHandCardInfos(memberId),
    }
end


CardGameBlackjackSystem._RecordSelfMaxRoundScore = HL.Method(HL.Any) << function(self, settlement)
    if settlement.isBust or settlement.resultKind == CS.Proto.BLACKJACK_V1D7_ROUND_SETTLEMENT_RESULT_KIND.Bust then
        return
    end
    self.m_selfMaxRoundScore = math.max(self.m_selfMaxRoundScore, settlement.points)
end



CardGameBlackjackSystem._BuildEliminatedSettleInfo = HL.Method(HL.Table).Return(HL.Table) << function(self, info)
    local archived = {}
    for key, value in pairs(info) do
        archived[key] = value
    end
    
    archived.rank = CardGameBlackjackUtils.ELIMINATED_SORT_RANK
    archived.displayRank = CardGameBlackjackUtils.MAX_SEAT_COUNT
    
    archived.hpDelta = 0
    archived.moneyDelta = 0
    return archived
end


CardGameBlackjackSystem._SortSettleCardList = HL.Method(HL.Table).Return(HL.Table) << function(self, cards)
    table.sort(cards, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.suit ~= b.suit then
            return a.suit < b.suit
        end
        return a.enhance < b.enhance
    end)
    return cards
end


CardGameBlackjackSystem._BuildRoundSettleHandCardInfos = HL.Method(HL.Any).Return(HL.Table) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    local shownDeck = mirror and mirror.shownDeck or nil
    local cards = {}
    for i = 0, (shownDeck and shownDeck.Count or 0) - 1 do
        cards[i + 1] = shownDeck[i]
    end
    return self:_BuildPokerDisplayInfos(self:_SortSettleCardList(cards))
end



CardGameBlackjackSystem._IsGameOverAfterRoundSettle = HL.Method(HL.Number).Return(HL.Boolean) << function(self, aliveCount)
    local gamePhase = self.m_mirrorGlobal and self.m_mirrorGlobal.gamePhase or nil
    if gamePhase == CS.Proto.BLACKJACK_V1D7_GAME_PHASE.FinalSettlement
            or gamePhase == CS.Proto.BLACKJACK_V1D7_GAME_PHASE.GameOver then
        return true
    end
    return aliveCount <= 1
end







CardGameBlackjackSystem._PlayFinalSettlePresentation = HL.Method(HL.Function) << function(self, onDone)
    local arg = self:_BuildFinalSettleArg()
    if arg == nil then
        logger.error("CardGameBlackjackSystem._PlayFinalSettlePresentation: 拿不到终局结算数据，跳过结算界面")
        onDone()
        return
    end

    self.m_finalSettleArg = arg
    self:_OpenPhaseWithEnterGate(FINAL_SETTLE_PHASE_ID, arg)
    onDone()
end




CardGameBlackjackSystem._BuildEarlyLeaveFinalSettleArg = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local result = self.m_selfEliminatedResult
    if result == nil or self.m_finalSettlements ~= nil or self.m_roomData == nil then
        return nil
    end

    local selfSettleInfo = self:_BuildFinalSettleInfo({
        memberId = self.m_roomData.selfMemberId,
        rank = result.rank,
        gold = result.gold,
        isSelf = true,
    })
    return {
        settleInfos = { selfSettleInfo },
        selfSettleInfo = selfSettleInfo,
        
        isEarlyLeave = true,
    }
end



CardGameBlackjackSystem._OpenEarlyLeaveFinalSettle = HL.Method() << function(self)
    local arg = self.m_earlyLeaveSettleArg
    self.m_earlyLeaveSettleArg = nil
    self.m_inGame = false
    self.m_notifyQueue:Clear(false, false)
    self.m_aniQueue:Clear(false, false)
    self.m_effectQueue:Clear(false, false)
    
    self:CancelPauseByGuide()
    self:_UnregisterGameplayMessages()
    self:_ClearChooseStack()
    self:_StopOtherChoosing()
    self:_ClearDealAniUpdate()
    self:_CloseRoundSettle(true)
    self:_ClosePlayerGameInfo()
    if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackShopMain) then
        PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackShopMain)
    end
    self:_OpenPhaseWithEnterGate(FINAL_SETTLE_PHASE_ID, arg)
end

CardGameBlackjackSystem._CloseFinalSettle = HL.Method() << function(self)
    if not PhaseManager:IsOpenAndValid(FINAL_SETTLE_PHASE_ID) then
        return
    end
    PhaseManager:ExitPhaseFast(FINAL_SETTLE_PHASE_ID)
end




CardGameBlackjackSystem._SnapshotFinalSettlements = HL.Method() << function(self)
    local roomData = self.m_roomData
    local settlements = roomData and roomData.finalSettlements or nil
    local count = settlements and settlements.Count or 0
    if count <= 0 then
        logger.error("CardGameBlackjackSystem._SnapshotFinalSettlements: 终局结算通知里没有结算数据")
        return
    end

    local snapshot = {}
    for i = 0, count - 1 do
        local settlement = settlements[i]
        snapshot[i + 1] = {
            memberId = settlement.memberId,
            rank = settlement.rank,
            gold = settlement.gold,
            
            isSelf = settlement.memberId == roomData.selfMemberId,
        }
    end
    self.m_finalSettlements = snapshot
end



CardGameBlackjackSystem._BuildFinalSettleArg = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local settlements = self.m_finalSettlements
    if settlements == nil or #settlements <= 0 then
        return nil
    end

    
    local settleInfos = {}
    local selfSettleInfo = nil
    for i = 1, #settlements do
        local settlement = settlements[i]
        local info = self:_BuildFinalSettleInfo(settlement)
        settleInfos[i] = info
        if settlement.isSelf then
            selfSettleInfo = info
        end
    end
    if selfSettleInfo == nil then
        logger.error("CardGameBlackjackSystem._BuildFinalSettleArg: 结算数据里没有自己")
        return nil
    end

    return {
        settleInfos = settleInfos,
        
        selfSettleInfo = selfSettleInfo,
    }
end


CardGameBlackjackSystem._BuildFinalSettleInfo = HL.Method(HL.Table).Return(HL.Table) << function(self, settlement)
    local memberId = settlement.memberId
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    local seat = hudSeat and self.m_seatMembers[hudSeat] or nil
    local briefData = seat and seat.briefData or nil
    local mirror = self.m_mirrorMembers[memberId]

    local relicInfos = mirror ~= nil and self:_BuildRelicDisplayList(mirror) or {}
    local extraRelicNum = 0
    for i = 1, #relicInfos do
        if relicInfos[i].isExtraRelic then
            extraRelicNum = extraRelicNum + 1
        end
    end

    local socialInfo = self:_BuildFinalSettleSocialInfo(memberId, settlement.isSelf)
    
    local displayInfo = self:_BuildMemberDisplayInfo(memberId)
    return {
        seatIndex = self:_GetActualSeatIndexByMemberId(memberId),
        nickname = displayInfo.nickname,
        displayInfo = displayInfo,
        charId = MultiplayerUtils.getMemberDisplayCharTemplateId(briefData) or "",
        
        roleId = socialInfo.roleId,
        
        isSelf = socialInfo.isSelf,
        isAI = socialInfo.isAI,
        isFriend = socialInfo.isFriend,
        isFriendRequestSent = socialInfo.isFriendRequestSent,
        canAddFriend = socialInfo.canAddFriend,
        rank = settlement.rank,
        moneyNum = settlement.gold,
        
        maxRoundScore = settlement.isSelf and self.m_selfMaxRoundScore or 0,
        relicInfos = relicInfos,
        
        relicSlotMaxLimit = (mirror and mirror.relicSlotMaxLimit or 0) + extraRelicNum,
        
        cardInfos = self:_BuildFinalSettleCardInfos(mirror),
    }
end



CardGameBlackjackSystem._BuildFinalSettleSocialInfo = HL.Method(HL.Any, HL.Boolean).Return(HL.Table)
        << function(self, memberId, isSelf)
    local briefData = self:_GetSeatBriefData(memberId)
    local isAI = briefData ~= nil and not string.isEmpty(briefData.npcTplId)
    local roleId = briefData ~= nil and briefData.roleId or 0
    local social = CardGameUtils.QueryPlayerSocialFlags({
        isSelf = isSelf,
        isAI = isAI,
        roleId = roleId,
    })

    return {
        roleId = roleId,
        isSelf = isSelf,
        isAI = isAI,
        isFriend = social.isFriend,
        isFriendRequestSent = social.isFriendRequestSent,
        
        canAddFriend = social.canAddFriend,
    }
end




CardGameBlackjackSystem._RefreshFinalSettleSocialStates = HL.Method(HL.Table) << function(self, arg)
    local settleInfos = arg.settleInfos
    for i = 1, #settleInfos do
        local info = settleInfos[i]
        local social = CardGameUtils.QueryPlayerSocialFlags(info)
        info.isFriend = social.isFriend
        info.isFriendRequestSent = social.isFriendRequestSent
        info.canAddFriend = social.canAddFriend
    end
end

CardGameBlackjackSystem._BuildFinalSettleCardInfos = HL.Method(HL.Opt(HL.Any)).Return(HL.Table) << function(self, mirror)
    local sortedDeck = mirror and mirror.sortedDeck or nil
    local cards = {}
    for i = 0, (sortedDeck and sortedDeck.Count or 0) - 1 do
        cards[i + 1] = sortedDeck[i]
    end
    return self:_BuildPokerDisplayInfos(self:_SortSettleCardList(cards))
end




CardGameBlackjackSystem.OpenFinalSettleRank = HL.Method() << function(self)
    local arg = self.m_finalSettleArg
    if arg == nil then
        logger.error("CardGameBlackjackSystem.OpenFinalSettleRank: 拿不到终局结算数据，跳过排名界面")
        return
    end
    self:_RefreshFinalSettleSocialStates(arg)
    self:_OpenPhaseWithEnterGate(FINAL_SETTLE_RANK_PHASE_ID, arg)
end


CardGameBlackjackSystem._CloseFinalSettleRank = HL.Method() << function(self)
    if not PhaseManager:IsOpenAndValid(FINAL_SETTLE_RANK_PHASE_ID) then
        return
    end
    PhaseManager:ExitPhaseFast(FINAL_SETTLE_RANK_PHASE_ID)
end




CardGameBlackjackSystem.RequestAddFriend = HL.Method(HL.Number).Return(HL.Boolean) << function(self, seatIndex)
    local roleId = self:_GetRoleIdBySeatIndex(seatIndex)
    if roleId == nil or roleId == 0 then
        logger.error("CardGameBlackjackSystem.RequestAddFriend: 取不到 roleId, seatIndex=" .. tostring(seatIndex))
        return false
    end

    
    return CardGameUtils.RequestAddFriend(roleId, "CardGameBlackjackFinalSettleRank", PhaseManager:GetPhaseName(PhaseId.CardGameBlackjackHud))
end


CardGameBlackjackSystem._GetRoleIdBySeatIndex = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, seatIndex)
    local hudSeat = self.m_seatToHudSeat[seatIndex]
    local seat = hudSeat and self.m_seatMembers[hudSeat] or nil
    local briefData = seat and seat.briefData or nil
    return briefData and briefData.roleId or nil
end








CardGameBlackjackSystem._CalcChooseDeadline = HL.Method(HL.Table).Return(HL.Opt(HL.Number))
        << function(self, item)
    local timeoutMs = item.batch.responseTimeoutMs
    if timeoutMs == nil or timeoutMs <= 0 then
        return nil
    end
    return item.recvTime + timeoutMs / 1000
end



CardGameBlackjackSystem._GetChooseDeadline = HL.Method().Return(HL.Number, HL.Number) << function(self)
    local result = 0
    local total = 0
    for i = 1, #self.m_chooseStack do
        local entry = self.m_chooseStack[i]
        local deadline = entry.deadline
        if deadline ~= nil and (result <= 0 or deadline < result) then
            result = deadline
            total = entry.total
        end
    end
    return result, total
end




CardGameBlackjackSystem._RefreshCountDown = HL.Method() << function(self)
    local deadline, total = self:_GetChooseDeadline()
    if deadline <= 0 and self.m_spectateCountDown ~= nil then
        deadline, total = self.m_spectateCountDown.deadline, self.m_spectateCountDown.total
    end
    if deadline <= 0 then
        self:_StopCountDown()
        return
    end

    if self.m_countDownEndTime > 0 and deadline > self.m_countDownEndTime + 0.1 then
        
        
        logger.error("CardGameBlackjackSystem 倒计时截止时间被延后, old=" .. tostring(self.m_countDownEndTime)
                .. ", new=" .. tostring(deadline))
    end

    self.m_countDownTotal = total
    self.m_countDownEndTime = deadline
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:ShowTableInfoCountDown(true)
    end
    self:_NotifyPlayerGameInfoCountDownState()
    self:_StartCountDownUpdateIfNeeded()
    self:_TickCountDown()
end


CardGameBlackjackSystem._KeepSpectateCountDown = HL.Method(HL.Table) << function(self, entry)
    if entry.deadline == nil then
        return
    end
    self.m_spectateCountDown = { deadline = entry.deadline, total = entry.total }
end


CardGameBlackjackSystem._ClearSpectateCountDown = HL.Method() << function(self)
    if self.m_spectateCountDown == nil then
        return
    end
    self.m_spectateCountDown = nil
    self:_RefreshCountDown()
end


CardGameBlackjackSystem.IsSpectateCountDown = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_spectateCountDown ~= nil and #self.m_chooseStack == 0
end

CardGameBlackjackSystem._StartCountDownUpdateIfNeeded = HL.Method() << function(self)
    if self.m_countDownEndTime <= 0 or self.m_countDownTimer > 0 then
        return
    end
    self.m_countDownTimer = LuaUpdate:Add("Tick", function()
        self:_TickCountDown()
    end)
end

CardGameBlackjackSystem._TickCountDown = HL.Method() << function(self)
    if self.m_countDownEndTime <= 0 then
        return
    end

    
    
    
    local remain = math.max(self.m_countDownEndTime - self:_GetCountDownNow(), 0)
    self:_SetCountDownUI(remain, self.m_countDownTotal)
    self:_RefreshHudPlayerOptInfo(1)
    self:_TryPlayCountDownWarningAudio(remain)
end


CardGameBlackjackSystem._TryPlayCountDownWarningAudio = HL.Method(HL.Number) << function(self, remain)
    local curSecond = math.floor(remain)
    local lastSecond = self.m_countDownLastSecond
    self.m_countDownLastSecond = curSecond
    if lastSecond >= 0 and curSecond < lastSecond
            and curSecond < CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME then
        AudioAdapter.PostEvent("Au_UI_Event_CardGameCountDown")
    end
end

CardGameBlackjackSystem._StopCountDown = HL.Method() << function(self)
    self:_ResetCountDownData()
    self:_SetCountDownUI(0, 0)
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:ShowTableInfoCountDown(false)
    end
    self:_RefreshHudTableTips()
    self:_NotifyPlayerGameInfoCountDownState()
end


CardGameBlackjackSystem._ResetCountDownData = HL.Method() << function(self)
    if self.m_countDownTimer > 0 then
        self.m_countDownTimer = LuaUpdate:Remove(self.m_countDownTimer)
    end
    self.m_countDownEndTime = 0
    self.m_countDownTotal = 0
    self.m_countDownLastSecond = -1
end


CardGameBlackjackSystem.GetCountDownRemain = HL.Method().Return(HL.Number) << function(self)
    if self.m_countDownEndTime <= 0 then
        return 0
    end
    return math.max(self.m_countDownEndTime - self:_GetCountDownNow(), 0)
end


CardGameBlackjackSystem.IsCountDownRunning = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_countDownEndTime > 0
end

CardGameBlackjackSystem.GetCountDownTotal = HL.Method().Return(HL.Number) << function(self)
    return self.m_countDownTotal
end


CardGameBlackjackSystem._GetCountDownNow = HL.Method().Return(HL.Number) << function(self)
    local now = self.m_countDownPauseStart >= 0 and self.m_countDownPauseStart or Time.unscaledTime
    return now - self.m_countDownPausedAccum
end


CardGameBlackjackSystem._SetCountDownUI = HL.Method(HL.Number, HL.Number) << function(self, remain, total)
    
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:SetTableInfoCountDownProgress(remain, total)
        if self:_GetHudChooseEntry() ~= nil then
            hudCtrl:RefreshHudChooseCountDownSelfPlayer(remain, total)
        end
    end
    self:_RefreshHudTableTips()
    
    local shopCtrl = self:_GetShopMainCtrl()
    if shopCtrl then
        shopCtrl:SetCountDown(remain, total)
    end
    
    local playerGameInfoCtrl = self:_GetPlayerGameInfoCtrl()
    if playerGameInfoCtrl ~= nil then
        playerGameInfoCtrl:SetCountDown(remain, total)
    end
end


CardGameBlackjackSystem._NotifyPlayerGameInfoCountDownState = HL.Method() << function(self)
    local ctrl = self:_GetPlayerGameInfoCtrl()
    if ctrl ~= nil then
        ctrl:RefreshCountDownState()
    end
end





CardGameBlackjackSystem._OpenHud = HL.Method() << function(self)
    PhaseManager:OpenPhase(PhaseId.CardGameBlackjackHud, {
        
        onPickCard = function(pick)
            self:OnPlayerPickCard(pick)
        end
    })
end



CardGameBlackjackSystem.OnHudReady = HL.Method() << function(self)
    if self.isHudReady then
        return
    end
    self.isHudReady = true

    self:_RefreshHudPlayerBasicInfo()
    self:_RefreshHudSelfHandZoneCardMaxTips()
    AudioManager.PostEvent("au_music_gambling_v1d7_blackjack_normal")
    self.m_notifyQueue:Resume(QUEUE_PAUSE_KEY.Hud)
    LuaSystemManager.cardGameSystem:StartGame()
end


CardGameBlackjackSystem._CloseHud = HL.Method() << function(self)
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:DetachScene()
    end

    local isOpen = PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackHud)
    if not isOpen then
        return
    end

    if not PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackHud) then
        self:_DeferExitHud()
    end
    self.isHudReady = false
    self.m_notifyQueue:Pause(QUEUE_PAUSE_KEY.Hud)
end


CardGameBlackjackSystem._DeferExitHud = HL.Method() << function(self)
    if self.m_deferExitHudUpdateKey > 0 then
        return
    end
    self.m_deferExitHudStartTime = Time.unscaledTime
    self.m_isDeferExitHudTimeoutReported = false
    self.m_deferExitHudUpdateKey = LuaUpdate:Add("Tick", function()
        self:_TryDeferExitHud()
    end)
end

CardGameBlackjackSystem._TryDeferExitHud = HL.Method() << function(self)
    if not PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackHud) then
        self:_ClearDeferExitHudUpdate()
        return
    end
    
    if not PhaseManager:IsInPhaseTransition() and PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackHud) then
        self:_ClearDeferExitHudUpdate()
        return
    end
    
    if not self.m_isDeferExitHudTimeoutReported and Time.unscaledTime - self.m_deferExitHudStartTime > 5 then
        self.m_isDeferExitHudTimeoutReported = true
        logger.error("CardGameBlackjackSystem HUD 补关超时，转场一直没结束, topPhase="
                .. PhaseManager:GetTopPhaseName()
                .. ", inTransition=" .. tostring(PhaseManager:IsInPhaseTransition()))
    end
end

CardGameBlackjackSystem._ClearDeferExitHudUpdate = HL.Method() << function(self)
    if self.m_deferExitHudUpdateKey > 0 then
        LuaUpdate:Remove(self.m_deferExitHudUpdateKey)
    end
    self.m_deferExitHudUpdateKey = -1
end

CardGameBlackjackSystem._GetHudCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(HUD_PANEL_ID)
    if not isOpen then
        return nil
    end
    return ctrl
end

CardGameBlackjackSystem._SetHudSeatNaviAllowed = HL.Method(HL.Boolean) << function(self, allowed)
    if self.m_hudSeatNaviAllowed == allowed then
        return
    end
    self.m_hudSeatNaviAllowed = allowed
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshHudSeatNavi()
    end
end

CardGameBlackjackSystem._SetStartPresentationPlaying = HL.Method(HL.Boolean) << function(self, isPlaying)
    if self.m_isStartPresentationPlaying == isPlaying then
        return
    end
    self.m_isStartPresentationPlaying = isPlaying
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(START_PRESENTATION_FORBID_HOTSWAP_KEY, isPlaying)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshStartPresentationNodes()
    end
end

CardGameBlackjackSystem._GetShopMainCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if not isOpen then
        return nil
    end
    return ctrl
end


CardGameBlackjackSystem._GetShopPhase = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, phase = PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackShopMain)
    if not isOpen then
        return nil
    end
    return phase
end

CardGameBlackjackSystem._GetShopSelectCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(SHOP_SELECT_PANEL_ID)
    if not isOpen then
        return nil
    end
    return ctrl
end

CardGameBlackjackSystem._RefreshHudPlayerBasicInfo = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end

    for hudSeat = 1, self:_GetSeatCount() do
        ctrl:RefreshPlayerInfoBasicUI(hudSeat, self:_BuildPlayerBasicInfo(hudSeat))
    end
end


CardGameBlackjackSystem._RefreshHud = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end

    ctrl:RefreshTitleRoundAndTurn()

    for hudSeat = 1, self:_GetSeatCount() do
        local mirror = self:_GetSeatMirror(hudSeat)
        if mirror ~= nil then
            ctrl:RefreshTableInfoCardDeckCount(hudSeat, self:_GetSeatDeckCount(mirror))
            self:_RefreshHudPointInfoPoint(hudSeat, mirror.points, mirror.scoreCap)
            ctrl:RefreshTableInfoPointInfoExtraPoint(hudSeat, mirror.additionalPoints)
            ctrl:ShowTableInfoPointInfoExtraPoint(hudSeat, mirror.additionalPoints ~= 0)
            if hudSeat == 1 then
                ctrl:RefreshSelfMoneyNum(mirror.gold)
            end
            if self.scene then
                self.scene:RefreshPlayerHpNum(hudSeat, mirror.hp)
            end
        end
    end
    self:_RefreshHudTableTips()
    self:_RefreshHudPointInfoStates()
    self:_RefreshHudPlayerOptInfos()
    self:_RefreshHudGameSigns()
    self:_RefreshHudAIIcons()
end


CardGameBlackjackSystem._RefreshHudSelfHandZoneCardMaxTips = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end

    local selfMirror = self:_GetSeatMirror(1)
    local handCap = selfMirror and selfMirror.handCap or 0
    local shownDeck = selfMirror and selfMirror.shownDeck or nil
    local shownCount = shownDeck and shownDeck.Count or 0
    if self:_IsInBattlePhase() and handCap > 0 and shownCount >= handCap then
        ctrl:ShowSelfHandZoneCardMaxTips(handCap)
    else
        ctrl:HideSelfHandZoneCardMaxTips()
    end
end


CardGameBlackjackSystem._RefreshHudHandHover = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshHandHover()
    end
end


CardGameBlackjackSystem._CanShowHandPokerTips = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_clientPhase ~= CLIENT_PHASE.Dealing and self:_IsInBattlePhase()
end


CardGameBlackjackSystem.GetHandCardCountByHudSeat = HL.Method(HL.Number).Return(HL.Number) << function(self, hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        return 0
    end
    local region = cardSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)
    return region and region:GetCardCount() or 0
end


CardGameBlackjackSystem.GetHandPokerTipsUids = HL.Method().Return(HL.Table, HL.Table) << function(self)
    local uids = {}
    local hudSeats = {}
    if not self:_CanShowHandPokerTips() then
        return uids, hudSeats
    end
    for hudSeat = 1, self:_GetSeatCount() do
        for _, uid in ipairs(self:_GetRegionUidList(CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat)) do
            uids[#uids + 1] = uid
            hudSeats[#hudSeats + 1] = hudSeat
        end
    end
    return uids, hudSeats
end


CardGameBlackjackSystem.GetHandPokerInfo = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, uid)
    for hudSeat = 1, self:_GetSeatCount() do
        local mirror = self:_GetSeatMirror(hudSeat)
        local shownDeck = mirror and mirror.shownDeck or nil
        for i = 0, (shownDeck and shownDeck.Count or 0) - 1 do
            local card = shownDeck[i]
            if card.id == uid then
                return self:_BuildPlayerGameInfoPokerInfo(card, true, false)
            end
        end
    end
    return nil
end


CardGameBlackjackSystem._RefreshHudPointInfoPoint = HL.Method(HL.Number, HL.Number, HL.Number)
    << function(self, hudSeat, curPoint, maxPoint)
    if self.m_hudShownPoints == nil then
        self.m_hudShownPoints = {}
    end
    self.m_hudShownPoints[hudSeat] = { curPoint = curPoint, maxPoint = maxPoint }
    local ctrl = self:_GetHudCtrl()
    if ctrl then
        ctrl:RefreshTableInfoPointInfoPoint(hudSeat, curPoint, maxPoint)
    end
end


CardGameBlackjackSystem._GetHudShownPoints = HL.Method(HL.Number).Return(HL.Number, HL.Number) << function(self, hudSeat)
    local shown = self.m_hudShownPoints and self.m_hudShownPoints[hudSeat]
    if shown then
        return shown.curPoint, shown.maxPoint
    end
    local mirror = self:_GetSeatMirror(hudSeat)
    if mirror then
        return mirror.points, mirror.scoreCap
    end
    return 0, 0
end

CardGameBlackjackSystem._RefreshHudCardDeckCount = HL.Method(HL.Number) << function(self, hudSeat)
    local ctrl = self:_GetHudCtrl()
    local mirror = self:_GetSeatMirror(hudSeat)
    if ctrl == nil or mirror == nil then
        return
    end

    ctrl:RefreshTableInfoCardDeckCount(hudSeat, self:_GetSeatDeckCount(mirror))
end


CardGameBlackjackSystem._RefreshDeckCardNum = HL.Method(HL.Number) << function(self, memberId)
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    if hudSeat ~= nil then
        self:_RefreshHudCardDeckCount(hudSeat)
    end
    if not self:_IsSelfMemberId(memberId) then
        return
    end
    local shopCtrl = self:_GetShopMainCtrl()
    local mirror = self:_GetSeatMirror(1)
    if shopCtrl ~= nil and mirror ~= nil then
        shopCtrl:RefreshDeckCardNum(mirror.sortedDeck.Count)
    end
end


CardGameBlackjackSystem._RefreshSelfHandCapTips = HL.Method(HL.Number) << function(self, memberId)
    if not self:_IsSelfMemberId(memberId) then
        return
    end
    self:_RefreshHudSelfHandZoneCardMaxTips()
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil and self.m_isHudPickTipsShow then
        self:RefreshHudPickTips(ctrl)
    end
end


CardGameBlackjackSystem._RefreshHudPointInfoStates = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAudio)
    for hudSeat = 1, self:_GetSeatCount() do
        self:_RefreshHudPointInfoState(hudSeat, playAudio)
    end
end

CardGameBlackjackSystem._RefreshHudPointInfoState = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, hudSeat, playAudio)
    local ctrl = self:_GetHudCtrl()
    local seat = self.m_seatMembers[hudSeat]
    if ctrl == nil or seat == nil then
        return
    end

    local mirror = self.m_mirrorMembers[seat.memberId]
    
    local isGuideOpening = self.isPauseByGuide and hudSeat == 1 and self:GetGameRound() == 0 and self:GetGameTurn() == 0
    
    local isShowPhase = self:_IsInBattlePhase() or self.m_clientPhase == CLIENT_PHASE.RoundSettle
    local isShow = (isShowPhase or isGuideOpening) and mirror ~= nil and mirror.hp > 0
    ctrl:ShowTableInfoPointInfo(hudSeat, isShow)
    if not isShow then
        return
    end

    if mirror.isBust then
        ctrl:SetTableInfoPointInfoState(hudSeat, "PointBust", playAudio)
    elseif mirror.points == mirror.scoreCap then
        ctrl:SetTableInfoPointInfoState(hudSeat, "PointFull", playAudio)
    else
        ctrl:SetTableInfoPointInfoState(hudSeat, "PointNormal", playAudio)
    end
end

CardGameBlackjackSystem._RefreshHudPlayerOptInfos = HL.Method() << function(self)
    for hudSeat = 1, self:_GetSeatCount() do
        self:_RefreshHudPlayerOptInfo(hudSeat)
    end
end

CardGameBlackjackSystem._RefreshHudPlayerOptInfo = HL.Method(HL.Number) << function(self, hudSeat)
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:RefreshPlayerInfoOptInfoBySeat(hudSeat)
    end
end


CardGameBlackjackSystem._RefreshHudPlayerOptInfoByMemberId = HL.Method(HL.Any) << function(self, memberId)
    local hudSeat = memberId ~= nil and self.m_memberIdToHudSeat[memberId] or nil
    if hudSeat ~= nil then
        self:_RefreshHudPlayerOptInfo(hudSeat)
    end
end


CardGameBlackjackSystem.IsMemberChosenDone = HL.Method(HL.Any).Return(HL.Boolean) << function(self, memberId)
    local chosenDoneMembers = self.m_roomData and self.m_roomData.chosenDoneMembers or nil
    return chosenDoneMembers ~= nil and chosenDoneMembers:Contains(memberId)
end


CardGameBlackjackSystem.IsAllAliveMembersChosenDone = HL.Method().Return(HL.Boolean) << function(self)
    for hudSeat = 1, self:_GetSeatCount() do
        local mirror = self:_GetSeatMirror(hudSeat)
        if mirror ~= nil and mirror.hp > 0 and not self:IsMemberChosenDone(self.m_seatMembers[hudSeat].memberId) then
            return false
        end
    end
    return true
end


CardGameBlackjackSystem.TryGetPickResult = HL.Method(HL.Any).Return(HL.Boolean, HL.Boolean) << function(self, memberId)
    local pickResults = self.m_roomData and self.m_roomData.pickResults or nil
    if pickResults == nil then
        return false, false
    end
    local found, pick = pickResults:TryGetValue(memberId)
    return found, pick == true
end


CardGameBlackjackSystem.IsMemberPickChosen = HL.Method(HL.Any).Return(HL.Boolean) << function(self, memberId)
    if self:IsMemberChosenDone(memberId) or self:TryGetPickResult(memberId) then
        return true
    end
    return self.m_selfPickResult ~= nil and self:_IsSelfMemberId(memberId)
end


CardGameBlackjackSystem.IsSelfPickChoosing = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_roomData == nil or self:FindChoose(CardGameBlackjackUtils.CHOOSE_KEY.Pick) == nil then
        return false
    end
    return not self:IsMemberPickChosen(self.m_roomData.selfMemberId)
end

CardGameBlackjackSystem._RefreshHudGameSigns = HL.Method() << function(self)
    for hudSeat = 1, self:_GetSeatCount() do
        self:_RefreshHudPlayerGameSign(hudSeat)
    end
end

CardGameBlackjackSystem._RefreshHudPlayerGameSign = HL.Method(HL.Number, HL.Opt(HL.Number)) << function(self, hudSeat, hp)
    local ctrl = self:_GetHudCtrl()
    local seat = self.m_seatMembers[hudSeat]
    if ctrl == nil or seat == nil then
        return
    end

    local memberId = seat.memberId
    local curHp = hp
    if curHp == nil then
        local mirror = self.m_mirrorMembers[memberId]
        curHp = mirror and mirror.hp or nil
    end
    local isGameOut = curHp == nil or curHp <= 0
    if hudSeat == 1 then
        ctrl:RefreshPlayerInfoSelfIsWatch(isGameOut)
    end

    local dealerMemberId = self.m_mirrorGlobal and self.m_mirrorGlobal.dealerMemberId or 0
    if dealerMemberId ~= 0 and memberId == dealerMemberId then
        ctrl:RefreshPlayerInfoGameSign(hudSeat, "StartFlag")
        ctrl:ShowPlayerInfoGameSign(hudSeat, true)
        return
    end

    if isGameOut then
        ctrl:RefreshPlayerInfoGameSign(hudSeat, "Watch")
        ctrl:ShowPlayerInfoGameSign(hudSeat, true)
    else
        ctrl:ShowPlayerInfoGameSign(hudSeat, false)
    end
end

CardGameBlackjackSystem._RefreshHudAIIcons = HL.Method() << function(self)
    for hudSeat = 2, self:_GetSeatCount() do
        self:_RefreshHudPlayerAIIcon(hudSeat)
    end
end

CardGameBlackjackSystem._RefreshHudPlayerAIIcon = HL.Method(HL.Number) << function(self, hudSeat)
    local ctrl = self:_GetHudCtrl()
    local seat = self.m_seatMembers[hudSeat]
    if ctrl == nil or seat == nil then
        return
    end

    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    local briefMember = playRoomSystem:GetBriefMemberByMemberId(seat.memberId)
    if briefMember ~= nil then
        seat.briefData = briefMember.briefData
    end
    ctrl:ShowOtherPlayerInfoAIIcon(hudSeat, CardGameUtils.IsMemberShowAI(seat.memberId))
end

CardGameBlackjackSystem._ShowHudCenterArrow = HL.Method(HL.Number) << function(self, hudSeat)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil or self.m_battleSubPhase ~= BATTLE_SUB_PHASE.ShowCard then
        return
    end

    ctrl:ShowTableInfoCenterArrow(true, hudSeat)
end

CardGameBlackjackSystem._OnLeaveShowCardSubPhase = HL.Method() << function(self)
    self.m_effectReportShowCardMemberId = nil
    
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:ShowTableInfoCenterArrow(false)
    end
end

CardGameBlackjackSystem._RefreshHudTitleRoundAndTurn = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:RefreshTitleRoundAndTurn()
    end
end

CardGameBlackjackSystem._RefreshHudTableTips = HL.Method() << function(self)
    local ctrl = self:_GetHudCtrl()
    if ctrl ~= nil then
        ctrl:RefreshTableInfoTableTips()
    end
end


CardGameBlackjackSystem._SetHudPickEmpty = HL.Method(HL.Boolean) << function(self, playAni)
    self.m_isHudPickTipsShow = false
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end
    ctrl:ShowOptInfoPickCardBtnTipsNode(false)
    ctrl:SetOptInfoBtnsEmpty(playAni)
end

CardGameBlackjackSystem._SetHudPickChoosing = HL.Method() << function(self)
    self.m_isHudPickTipsShow = true
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end
    ctrl:SetOptInfoBtnsSelectable(true)
    ctrl:ShowOptInfoPickCardBtnTipsNode(true)
    self:RefreshHudPickTips(ctrl)
end

CardGameBlackjackSystem.IsHudPickTipsShow = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isHudPickTipsShow
end


CardGameBlackjackSystem.GetSelfGold = HL.Method().Return(HL.Opt(HL.Number)) << function(self)
    local selfMirror = self:_GetSeatMirror(1)
    return selfMirror and selfMirror.gold or nil
end

CardGameBlackjackSystem._SetHudPickSelected = HL.Method(HL.Boolean) << function(self, pick)
    local ctrl = self:_GetHudCtrl()
    if ctrl == nil then
        return
    end
    
    ctrl:SetOptInfoBtnsPicked(pick)
end

CardGameBlackjackSystem.RefreshHudPickTips = HL.Method(HL.Any) << function(self, ctrl)
    local selfMirror = self:_GetSeatMirror(1)
    if selfMirror == nil then
        ctrl:RefreshOptInfoTipsBustProbability(0)
        return
    end

    local remainingDeck = selfMirror.remainingDeckSorted
    local remainingCount = remainingDeck and remainingDeck.Count or 0
    if remainingCount <= 0 then
        ctrl:RefreshOptInfoTipsNoCards()
        return
    end

    local shownDeck = selfMirror.shownDeck
    local shownCount = shownDeck and shownDeck.Count or 0
    if selfMirror.handCap > 0 and shownCount >= selfMirror.handCap then
        ctrl:RefreshOptInfoTipsFullCards()
        return
    end

    ctrl:RefreshOptInfoTipsBustProbability(self:_CalcSelfBustProbability())
end

CardGameBlackjackSystem._CalcSelfBustProbability = HL.Method().Return(HL.Number) << function(self)
    local selfMirror = self:_GetSeatMirror(1)
    if selfMirror == nil then
        return 0
    end

    local remainingDeck = selfMirror.remainingDeckSorted
    local remainingCount = remainingDeck and remainingDeck.Count or 0
    if remainingCount <= 0 then
        return 0
    end

    local curPoint = selfMirror.points
    local bustCount = 0
    for i = 0, remainingCount - 1 do
        local card = remainingDeck[i]
        if card ~= nil and curPoint + math.min(card.rank, 10) > selfMirror.scoreCap then
            bustCount = bustCount + 1
        end
    end
    return math.floor(bustCount * 100 / remainingCount + 0.5)
end

CardGameBlackjackSystem._BuildRelicDisplayList = HL.Method(HL.Any).Return(HL.Table) << function(self, mirror)
    local result = {}
    local relics = mirror.relics
    if relics == nil then
        return result
    end

    for i = 0, relics.Count - 1 do
        local relic = relics[i]
        local hasId, relicId = CS.Beyond.Cfg.Tables.blackjackRelicIdToStr:TryGetValue(relic.relicId)
        if hasId then
            local _, relicCfg = Tables.cardGameRelicInfoTable:TryGetValue(relicId)
            result[#result + 1] = {
                relicId = relicId,
                relicIcon = relicCfg.relicIcon,
                isExtraRelic = relicCfg.occupySlotCount == 0,
            }
        end
    end
    return result
end








CardGameBlackjackSystem._BuildSeatData = HL.Method() << function(self)
    self:_ClearSeatData()

    local roomData = self.m_roomData
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    local seatMemberIds = roomData.globalState.seatMemberIds
    local seatCount = seatMemberIds and seatMemberIds.Count or 0
    if seatCount <= 0 then
        logger.error("CardGameBlackjackSystem._BuildSeatData: seatMemberIds is empty")
        return
    end

    local selfSeatIndex = 0
    for i = 0, seatCount - 1 do
        if seatMemberIds[i] == roomData.selfMemberId then
            selfSeatIndex = i
            break
        end
    end

    
    local count = math.min(seatCount, CardGameBlackjackUtils.MAX_SEAT_COUNT)
    for hudSeat = 1, count do
        local offset = hudSeat - 1
        local seatIndex = (selfSeatIndex + offset) % seatCount
        local memberId = seatMemberIds[seatIndex]
        local briefMember = playRoomSystem:GetBriefMemberByMemberId(memberId)
        local found, memberData = roomData.members:TryGetValue(memberId)

        self.m_seatMembers[hudSeat] = {
            memberId = memberId,
            briefData = briefMember and briefMember.briefData or nil,
            memberData = found and memberData or nil,
        }
        self.m_seatToHudSeat[seatIndex + 1] = hudSeat
        self.m_memberIdToHudSeat[memberId] = hudSeat
    end
end

CardGameBlackjackSystem._ClearSeatData = HL.Method() << function(self)
    self.m_seatMembers = {}
    self.m_seatToHudSeat = {}
    self.m_memberIdToHudSeat = {}
    self.m_hudShownPoints = {}
end

CardGameBlackjackSystem._GetSeatCount = HL.Method().Return(HL.Number) << function(self)
    return #self.m_seatMembers
end

CardGameBlackjackSystem._GetActualSeatIndexByMemberId = HL.Method(HL.Any).Return(HL.Number) << function(self, memberId)
    local seatMemberIds = self.m_mirrorGlobal and self.m_mirrorGlobal.seatMemberIds or nil
    local seatCount = seatMemberIds and seatMemberIds.Count or 0
    for i = 0, seatCount - 1 do
        if seatMemberIds[i] == memberId then
            return i + 1
        end
    end
    return 0
end

CardGameBlackjackSystem._GetDealerHudSeat = HL.Method().Return(HL.Number) << function(self)
    local dealerMemberId = self.m_mirrorGlobal and self.m_mirrorGlobal.dealerMemberId or 0
    return self.m_memberIdToHudSeat[dealerMemberId] or 1
end


CardGameBlackjackSystem._GetSeatMirror = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, hudSeat)
    local seat = self.m_seatMembers[hudSeat]
    if seat == nil then
        return nil
    end
    return self.m_mirrorMembers[seat.memberId]
end



CardGameBlackjackSystem.GetSeatMirror = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, hudSeat)
    return self:_GetSeatMirror(hudSeat)
end



CardGameBlackjackSystem._BuildSeatChars = HL.Method().Return(HL.Table) << function(self)
    local seatChars = {}
    for i = 1, #self.m_seatMembers do
        local briefData = self.m_seatMembers[i].briefData
        seatChars[i] = {
            charId = MultiplayerUtils.getMemberDisplayCharTemplateId(briefData) or "",
            showPotentialFx = briefData ~= nil and briefData.hasFullPotentialFx,
        }
    end
    return seatChars
end

CardGameBlackjackSystem._BuildPlayerBasicInfo = HL.Method(HL.Number).Return(HL.Table) << function(self, hudSeat)
    local memberId = self.m_seatMembers[hudSeat].memberId
    local actualSeatIndex = self:_GetActualSeatIndexByMemberId(memberId)

    local info = self:_BuildMemberDisplayInfo(memberId)
    info.seatIndex = actualSeatIndex > 0 and actualSeatIndex or hudSeat
    return info
end


CardGameBlackjackSystem.GetHudSeatByMemberId = HL.Method(HL.Any).Return(HL.Opt(HL.Number)) << function(self, memberId)
    return self.m_memberIdToHudSeat[memberId]
end


CardGameBlackjackSystem.GetMemberIdByHudSeat = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, hudSeat)
    local seat = self.m_seatMembers and self.m_seatMembers[hudSeat]
    return seat and seat.memberId or nil
end


CardGameBlackjackSystem.IsSelfGameOut = HL.Method().Return(HL.Boolean) << function(self)
    local mirror = self:_GetSeatMirror(1)
    return mirror == nil or mirror.hp <= 0
end


CardGameBlackjackSystem.BuildPlayerBasicInfoByHudSeat = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, hudSeat)
    if self.m_seatMembers == nil or self.m_seatMembers[hudSeat] == nil then
        return nil
    end
    return self:_BuildPlayerBasicInfo(hudSeat)
end

CardGameBlackjackSystem._BuildRandomSeatPlayerInfo = HL.Method(HL.Number).Return(HL.Table) << function(self, hudSeat)
    local memberId = self.m_seatMembers[hudSeat].memberId
    local actualSeatIndex = self:_GetActualSeatIndexByMemberId(memberId)
    local displayInfo = self:_BuildMemberDisplayInfo(memberId)
    return {
        seatIndex = actualSeatIndex > 0 and actualSeatIndex or hudSeat,
        isSelf = hudSeat == 1,
        isAI = displayInfo.isAI,
        roleId = displayInfo.roleId,
        displayInfo = displayInfo,
    }
end

CardGameBlackjackSystem._GetMemberDisplayName = HL.Method(HL.Any).Return(HL.String) << function(self, memberId)
    return self:_BuildMemberDisplayInfo(memberId).nickname
end








CardGameBlackjackSystem._BuildMemberDisplayInfo = HL.Method(HL.Any).Return(HL.Table) << function(self, memberId)
    local info = {
        isAI = false,
        roleId = 0,
        
        nickname = "",
        signature = "",
        avatarIcon = "",
        avatarFrameIcon = "",
        cardTopicId = "",
        adventureLevel = 0,
        psName = "",
    }

    local briefData = self:_GetSeatBriefData(memberId)
    if briefData == nil then
        return info
    end

    local avatarId, avatarFrameId
    info.isAI = not string.isEmpty(briefData.npcTplId)
    if info.isAI then
        local found, npcCfg = Tables.multiplayerNpcPoolInfoTable:TryGetValue(briefData.npcTplId)
        if not found then
            logger.error("CardGameBlackjackSystem._BuildMemberDisplayInfo: NPC 池里没这个模板, npcTplId=" .. briefData.npcTplId)
            return info
        end
        info.nickname = npcCfg.nickname
        info.signature = npcCfg.signature
        info.cardTopicId = npcCfg.cardTopicId
        avatarId, avatarFrameId = npcCfg.avatarId, npcCfg.avatarFrameId
    else
        local found, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(briefData.roleId)
        if not found then
            logger.error("CardGameBlackjackSystem._BuildMemberDisplayInfo: 取不到玩家信息, roleId=" .. tostring(briefData.roleId))
            return info
        end
        info.roleId = briefData.roleId
        info.friendInfo = friendInfo
        info.nickname = friendInfo.name
        info.signature = friendInfo.signature
        
        info.cardTopicId = friendInfo.businessCardTopicId or ""
        info.adventureLevel = friendInfo.adventureLevel
        info.psName = friendInfo.psName
        avatarId, avatarFrameId = friendInfo.userAvatarId, friendInfo.userAvatarFrameId
    end

    if not string.isEmpty(avatarId) then
        info.avatarIcon = Tables.userAvatarTable:GetValue(avatarId).icon
    end
    if not string.isEmpty(avatarFrameId) then
        info.avatarFrameIcon = Tables.userAvatarTableFrame:GetValue(avatarFrameId).icon
    end
    return info
end






CardGameBlackjackSystem.OpenPlayerGameInfo = HL.Method(HL.Number, HL.Number) << function(self, seatIndex, defaultPage)
    self:_OpenPlayerGameInfo(seatIndex, defaultPage)
end


CardGameBlackjackSystem.OpenPlayerGameInfoByHudSeat = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, defaultPage)
    local seat = self.m_seatMembers[hudSeat]
    if seat == nil then
        return
    end
    self:_OpenPlayerGameInfo(self:_GetActualSeatIndexByMemberId(seat.memberId), defaultPage)
end


CardGameBlackjackSystem.OpenSelfPlayerGameInfo = HL.Method(HL.Number) << function(self, defaultPage)
    self:OpenPlayerGameInfoByHudSeat(1, defaultPage)
end


CardGameBlackjackSystem._IsInBattlePhase = HL.Method().Return(HL.Boolean) << function(self)
    local globalState = self.m_mirrorGlobal
    if globalState == nil or globalState.gamePhase ~= CS.Proto.BLACKJACK_V1D7_GAME_PHASE.InRound then
        return false
    end
    local roundPhase = globalState.roundPhase
    return roundPhase == CS.Proto.BLACKJACK_V1D7_ROUND_PHASE.FirstTurn
            or roundPhase == CS.Proto.BLACKJACK_V1D7_ROUND_PHASE.NormalTurn
            or roundPhase == CS.Proto.BLACKJACK_V1D7_ROUND_PHASE.ShowCard
end


CardGameBlackjackSystem._OpenPlayerGameInfo = HL.Method(HL.Number, HL.Number) << function(self, seatIndex, defaultPage)
    
    if self.m_clientPhase == CLIENT_PHASE.Dealing and not self.isPauseByGuide then
        return
    end

    
    local canShowHandZone = self:_IsInBattlePhase()
    if not canShowHandZone and defaultPage == CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.HandZone then
        defaultPage = CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck
    end

    local hudSeat = self.m_seatToHudSeat[seatIndex]
    local arg = hudSeat and self:_BuildPlayerGameInfoArg(hudSeat) or nil
    if arg == nil then
        logger.error("CardGameBlackjackSystem._OpenPlayerGameInfo: 取不到座位数据, seatIndex=" .. tostring(seatIndex))
        return
    end

    arg.canShowHandZone = canShowHandZone
    arg.defaultPage = defaultPage
    PhaseManager:OpenPhaseFast(PhaseId.CardGameBlackjackPlayerGameInfo, arg)
end

CardGameBlackjackSystem._ClosePlayerGameInfo = HL.Method() << function(self)
    if not PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackPlayerGameInfo) then
        return
    end
    PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackPlayerGameInfo)
end

CardGameBlackjackSystem._GetPlayerGameInfoCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PanelId.CardGameBlackjackPlayerGameInfo)
    if not isOpen then
        return nil
    end
    return ctrl
end

CardGameBlackjackSystem._BuildPlayerGameInfoArg = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, hudSeat)
    local seat = self.m_seatMembers[hudSeat]
    local mirror = self:_GetSeatMirror(hudSeat)
    if seat == nil or mirror == nil then
        return nil
    end

    local relicInfos, extraRelicNum = self:_BuildPlayerGameInfoRelicInfos(mirror)
    local displayInfo = self:_BuildMemberDisplayInfo(seat.memberId)
    return {
        playerBasicInfo = {
            memberId = seat.memberId,
            seatIndex = self:_GetActualSeatIndexByMemberId(seat.memberId),
            nickname = displayInfo.nickname,
            displayInfo = displayInfo,
            isSelf = hudSeat == 1,
            isAI = displayInfo.isAI,
            roleId = displayInfo.roleId,
        },
        
        curHp = mirror.hp,
        maxHp = Tables.cardGameBlackjackConst.initialHp,
        curMoney = mirror.gold,
        curPoint = mirror.points,
        maxPoint = mirror.scoreCap,
        isGameOut = mirror.hp <= 0,
        extraPoint = mirror.additionalPoints,
        
        relicInfos = relicInfos,
        relicNum = #relicInfos,
        extraRelicNum = extraRelicNum,
        maxRelicNum = mirror.relicSlotMaxLimit + extraRelicNum,
        
        handZonePokerInfos = self:_BuildPlayerGameInfoHandZonePokerInfos(mirror),
        maxHandZoneCount = mirror.handCap,
        
        deckPokerInfos = self:_BuildPlayerGameInfoDeckPokerInfos(mirror),
    }
end

CardGameBlackjackSystem._BuildPlayerGameInfoRelicInfos = HL.Method(HL.Any).Return(HL.Table, HL.Number)
        << function(self, mirror)
    local infos = {}
    local extraRelicNum = 0
    local relics = mirror.relics
    for i = 0, (relics and relics.Count or 0) - 1 do
        local relicCfg = CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId(relics[i].relicId)
        local isExtraRelic = relicCfg.occupySlotCount == 0
        if isExtraRelic then
            extraRelicNum = extraRelicNum + 1
        end
        infos[i + 1] = {
            name = relicCfg.relicName,
            desc = relicCfg.relicDesc,
            icon = relicCfg.relicIcon,
            rarity = relicCfg.rarity,
            isExtraRelic = isExtraRelic,
        }
    end
    return infos, extraRelicNum
end


CardGameBlackjackSystem._BuildPlayerGameInfoPokerInfo = HL.Method(HL.Any, HL.Boolean, HL.Boolean).Return(HL.Table)
        << function(self, card, isInHandZone, isDelete)
    return {
        suit = card.suit,
        rank = card.rank,
        style = CardGameUtils.GetCardStyleByEnhance(card.enhance),
        enhance = card.enhance,
        
        realRank = card.realRank,
        
        isTemporary = card.oriId == 0,
        isInHandZone = isInHandZone,
        isDelete = isDelete,
    }
end

CardGameBlackjackSystem._BuildPlayerGameInfoHandZonePokerInfos = HL.Method(HL.Any).Return(HL.Table)
        << function(self, mirror)
    local infos = {}
    local shownDeck = mirror.shownDeck
    for i = 0, (shownDeck and shownDeck.Count or 0) - 1 do
        infos[i + 1] = self:_BuildPlayerGameInfoPokerInfo(shownDeck[i], true, false)
    end
    return infos
end




CardGameBlackjackSystem._BuildPlayerGameInfoDeckPokerInfos = HL.Method(HL.Any).Return(HL.Table)
        << function(self, mirror)
    local result = {
        totalCardNum = 0,
        temporaryCardNum = 0,
    }
    for suit = 1, 4 do
        local suitName = CS.Beyond.Gameplay.CardGameUtils.GetSuitNameByInt(suit)
        result[suitName .. "PokerInfos"] = {}
    end

    local addCard = function(card, isInHandZone, isDelete)
        local info = self:_BuildPlayerGameInfoPokerInfo(card, isInHandZone, isDelete)
        local suitName = CS.Beyond.Gameplay.CardGameUtils.GetSuitNameByInt(info.suit)
        local infos = result[suitName .. "PokerInfos"]
        if infos == nil then
            logger.error("CardGameBlackjackSystem 牌库里出现了非四花色的牌, suit=" .. tostring(info.suit))
            return
        end
        infos[#infos + 1] = info
        result.totalCardNum = result.totalCardNum + 1
        if info.isTemporary then
            result.temporaryCardNum = result.temporaryCardNum + 1
        end
    end

    
    
    if self.m_clientPhase ~= CLIENT_PHASE.Battle or self:_IsEliminatedDeckCleared(mirror) then
        local sortedDeck = mirror.sortedDeck
        for i = 0, (sortedDeck and sortedDeck.Count or 0) - 1 do
            addCard(sortedDeck[i], false, false)
        end
    else
        
        local shownIds = {}
        local shownDeck = mirror.shownDeck
        for i = 0, (shownDeck and shownDeck.Count or 0) - 1 do
            local card = shownDeck[i]
            shownIds[card.id] = true
            addCard(card, true, false)
        end
        local remainingDeck = mirror.remainingDeckSorted
        for i = 0, (remainingDeck and remainingDeck.Count or 0) - 1 do
            local card = remainingDeck[i]
            if not shownIds[card.id] then
                addCard(card, false, false)
            end
        end
        local discardedDeck = mirror.discardedDeck
        for i = 0, (discardedDeck and discardedDeck.Count or 0) - 1 do
            addCard(discardedDeck[i], false, true)
        end
    end

    
    local getSortGroup = function(info)
        if info.isDelete then
            return 3
        end
        if info.isInHandZone then
            return 2
        end
        return 1
    end
    for suit = 1, 4 do
        local suitName = CS.Beyond.Gameplay.CardGameUtils.GetSuitNameByInt(suit)
        table.sort(result[suitName .. "PokerInfos"], function(a, b)
            local groupA, groupB = getSortGroup(a), getSortGroup(b)
            if groupA ~= groupB then
                return groupA < groupB
            end
            if a.enhance ~= b.enhance then
                return a.enhance < b.enhance
            end
            return a.rank < b.rank
        end)
    end
    return result
end



CardGameBlackjackSystem.GetEmojiRoomStrId = HL.Method().Return(HL.String) << function(self)
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    return playRoomSystem and playRoomSystem.roomStrId or ""
end

CardGameBlackjackSystem.IsEmojiInCd = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_sendEmojiCdEndTime > Time.unscaledTime
end

CardGameBlackjackSystem.StartEmojiCd = HL.Method() << function(self)
    self.m_sendEmojiCdEndTime = Time.unscaledTime + MultiplayerConst.EMOJI_CD_TIME
    self:_TickEmojiCd()
end

CardGameBlackjackSystem._GetEmojiCdRemain = HL.Method().Return(HL.Number) << function(self)
    if self.m_sendEmojiCdEndTime <= 0 then
        return 0
    end
    return math.max(self.m_sendEmojiCdEndTime - Time.unscaledTime, 0)
end

CardGameBlackjackSystem._TickEmojiCd = HL.Method() << function(self)
    local remain = self:_GetEmojiCdRemain()
    self.sendEmojiCdTime = remain
    self:_SetEmojiCdUI(remain > 0, remain)
    if self.m_sendEmojiCdTimer and self.m_sendEmojiCdTimer > 0 then
        self.m_sendEmojiCdTimer = self:_ClearTimer(self.m_sendEmojiCdTimer)
    end
    if remain > 0 then
        self.m_sendEmojiCdTimer = self:_StartTimer(EMOJI_CD_TICK, function()
            self:_TickEmojiCd()
        end, true)
    else
        self.m_sendEmojiCdEndTime = 0
        self.m_sendEmojiCdTimer = -1
    end
end

CardGameBlackjackSystem._SetEmojiCdUI = HL.Method(HL.Boolean, HL.Number) << function(self, inCd, cdTime)
    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:SetEmojiCdState(inCd)
        hudCtrl:RefreshEmojiCd(cdTime)
    end
    local shopSelectCtrl = self:_GetShopSelectCtrl()
    if shopSelectCtrl then
        shopSelectCtrl:SetEmojiCdState(inCd)
        shopSelectCtrl:RefreshEmojiCd(cdTime)
    end
end

CardGameBlackjackSystem._OnRoomEmojiNotify = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local roomStrId, senderRoleId, emojiId = unpack(arg or {})
    if roomStrId ~= self:GetEmojiRoomStrId() then
        return
    end
    if senderRoleId == nil or string.isEmpty(emojiId) then
        return
    end

    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    local briefMember = playRoomSystem:GetBriefMemberByRoleId(senderRoleId)
    if briefMember == nil then
        return
    end
    local charId = MultiplayerUtils.getMemberDisplayCharTemplateId(briefMember.briefData)
    self:_PlayEmojiByMemberId(briefMember.memberId, emojiId, charId)
end

CardGameBlackjackSystem._PlayEmojiByMemberId = HL.Method(HL.Any, HL.String, HL.Opt(HL.String))
        << function(self, memberId, emojiId, charId)
    
    local shopSelectCtrl = self:_GetShopSelectCtrl()
    if shopSelectCtrl then
        local actualSeatIndex = self:_GetActualSeatIndexByMemberId(memberId)
        if actualSeatIndex > 0 then
            shopSelectCtrl:PlayEmojiBySeatIndex(actualSeatIndex, emojiId, charId)
            return
        end
    end

    local hudSeat = self.m_memberIdToHudSeat[memberId]
    if hudSeat == nil then
        return
    end

    local hudCtrl = self:_GetHudCtrl()
    if hudCtrl then
        hudCtrl:PlayEmojiBySeatIndex(hudSeat, emojiId, charId)
    end
end



CardGameBlackjackSystem.SetPauseByGuide = HL.Method(HL.Any) << function(self, arg)
    local isPause = unpack(arg)
    if not GameInstance.player.multiplayerPlayRoomSystem.inRoom then
        return
    end
    
    if isPause and not self:_IsNewbieGuideRoom() then
        logger.error("CardGameBlackjackSystem 非新手引导房不响应引导暂停")
        return
    end
    if isPause then
        self:StartPauseByGuide()
    else
        self:CancelPauseByGuide()
    end
end

CardGameBlackjackSystem._IsNewbieGuideRoom = HL.Method().Return(HL.Boolean) << function(self)
    local enterPlayRoomInfo = GameInstance.player.multiplayerMatchSystem.enterPlayRoom
    return enterPlayRoomInfo ~= nil
        and enterPlayRoomInfo.playRoomKind == CS.Beyond.Gameplay.MultiplayerMatchSystem.PlayRoomKind.NewbieGuide
end

CardGameBlackjackSystem.StartPauseByGuide = HL.Method() << function(self)
    self.isPauseByGuide = true
    self.m_notifyQueue:Pause(QUEUE_PAUSE_KEY.Guide)
    self.m_effectQueue:Pause(QUEUE_PAUSE_KEY.Guide)
    self.m_aniQueue:Pause(QUEUE_PAUSE_KEY.Guide)
    
    self:_RefreshHudPointInfoStates()
    
    if self.m_countDownPauseStart < 0 then
        self.m_countDownPauseStart = Time.unscaledTime
    end
end

CardGameBlackjackSystem.CancelPauseByGuide = HL.Method() << function(self)
    local wasPaused = self.isPauseByGuide
    self.isPauseByGuide = false
    if wasPaused then
        self:_RefreshHudPointInfoStates()
    end
    
    
    if self.m_countDownPauseStart >= 0 then
        self.m_countDownPausedAccum = self.m_countDownPausedAccum + Time.unscaledTime - self.m_countDownPauseStart
        self.m_countDownPauseStart = -1
    end
    self.m_aniQueue:Resume(QUEUE_PAUSE_KEY.Guide)
    self.m_effectQueue:Resume(QUEUE_PAUSE_KEY.Guide)
    self.m_notifyQueue:Resume(QUEUE_PAUSE_KEY.Guide)
end



CardGameBlackjackSystem._IsSelfMemberId = HL.Method(HL.Number).Return(HL.Boolean) << function(self, memberId)
    return memberId == self.m_roomData.selfMemberId
end



CardGameBlackjackSystem._GetSeatBriefData = HL.Method(HL.Any).Return(HL.Opt(HL.Any)) << function(self, memberId)
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    local seat = hudSeat and self.m_seatMembers[hudSeat] or nil
    return seat and seat.briefData or nil
end

CardGameBlackjackSystem._GetSortedDeck = HL.Method(HL.Any).Return(HL.Opt(HL.Any)) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    return mirror and mirror.sortedDeck or nil
end

CardGameBlackjackSystem._GetShownDeck = HL.Method(HL.Any).Return(HL.Opt(HL.Any)) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    return mirror and mirror.shownDeck or nil
end

CardGameBlackjackSystem._GetRemainingDeckSorted = HL.Method(HL.Any).Return(HL.Opt(HL.Any)) << function(self, memberId)
    local mirror = self.m_mirrorMembers[memberId]
    return mirror and mirror.remainingDeckSorted or nil
end

CardGameBlackjackSystem._FindCardDeckById = HL.Method(HL.Any, HL.Any).Return(HL.Opt(HL.Any))
    << function(self, deck, cardId)
    if deck == nil or cardId == nil or cardId == 0 then
        return nil
    end
    for i = 0, deck.Count - 1 do
        local card = deck[i]
        if card.id == cardId then
            return card
        end
    end
    return nil
end



HL.Commit(CardGameBlackjackSystem)
return CardGameBlackjackSystem
