local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local StateGraph = require_ex('LuaSystem/CardGame/Doudizhu/Flow/DoudizhuStateGraph')
local FlowDefine = require_ex('LuaSystem/CardGame/Doudizhu/Flow/DoudizhuFlowDefine')
local PresentationRunner = require_ex('LuaSystem/CardGame/Doudizhu/DoudizhuPresentationRunner')
local HintSolver = require_ex('LuaSystem/CardGame/Doudizhu/DoudizhuHintSolver')
local CardGameSceneDoudizhu = require_ex('LuaSystem/CardGame/CardGameSceneDoudizhu').CardGameSceneDoudizhu

local PHASE_ID = PhaseId.CardGameDoudizhuHud
local DOUDIZHU_GAME_TYPE = CS.Beyond.GEnums.RoomGameType.CardgameDoudizhuV1d7
local MAX_SEAT_COUNT = 3










local CARD_REGION_DECK = "doudizhuDeck"
local HUD_SEAT = { 
    Self = 1,
    Left = 2,
    Right = 3,
}


local HUD_SEAT_TO_SERVER_OFFSET = {
    [HUD_SEAT.Self] = 0,
    [HUD_SEAT.Left] = 1,
    [HUD_SEAT.Right] = -1,
}

local CARD_REGION_PLAYER_HAND_IDS = {
    [HUD_SEAT.Self] = "doudizhuHand_self",
    [HUD_SEAT.Left] = "doudizhuHand_left",
    [HUD_SEAT.Right] = "doudizhuHand_right",
}

local CARD_REGION_PLAYER_PLAY_IDS = {
    [HUD_SEAT.Self] = "doudizhuPlay_self",
    [HUD_SEAT.Left] = "doudizhuPlay_left",
    [HUD_SEAT.Right] = "doudizhuPlay_right",
}

local HAND_PLACEHOLDER_UID_BASE = -10000 
local HAND_PLACEHOLDER_UID_SEAT_STRIDE = 100 
local BOTTOM_VISUAL_UID_BASE = -20000 
local BOTTOM_HAND_PREVIEW_UID_BASE = -30000 

local CARD_HANDOFF_ZONE_BOTTOM = "Bottom"

local PHASE_READY_WATCHDOG_SECONDS = 20

local DEAL_PERFORM_FORBID_HOTSWAP_KEY = "CardGameDoudizhu.DealPerform"

local SETTLEMENT_TOAST_FORBID_HOTSWAP_KEY = "CardGameDoudizhu.SettlementToast"

local EMOJI_CD_TICK = 1

local PresentationType = CS.Beyond.Gameplay.DoudizhuPresentationType
local UInt32List = CS.System.Collections.Generic.List(CS.System.UInt32)
local Int32List = CS.System.Collections.Generic.List(CS.System.Int32)
local FLOW_STATE = StateGraph.State
local HSM_TRIGGER = StateGraph.Trigger

local HUD_COMMAND_KIND = {
    Rebuild = "Rebuild",
    Deal = "Deal",
    TurnChanged = "TurnChanged",
    BidResult = "BidResult",
    BottomRevealed = "BottomRevealed",
    PlayCards = "PlayCards",
    Pass = "Pass",
    Settlement = "Settlement",
}

CardGameDoudizhuSystem = HL.Class('CardGameDoudizhuSystem', LuaSystemBase.LuaSystemBase)

CardGameDoudizhuSystem.State = HL.StaticField(HL.Table) << FLOW_STATE
CardGameDoudizhuSystem.Trigger = HL.StaticField(HL.Table) << HSM_TRIGGER
CardGameDoudizhuSystem.HudCommandKind = HL.StaticField(HL.Table) << HUD_COMMAND_KIND
CardGameDoudizhuSystem.PlaySelectionResult = HL.StaticField(HL.Table) << HintSolver.SelectionResult




CardGameDoudizhuSystem.m_roomData = HL.Field(HL.Any)
CardGameDoudizhuSystem.m_inGame = HL.Field(HL.Boolean) << false 
CardGameDoudizhuSystem.m_phaseReady = HL.Field(HL.Boolean) << false 
CardGameDoudizhuSystem.m_phaseActive = HL.Field(HL.Boolean) << false 
CardGameDoudizhuSystem.m_headlessPresentation = HL.Field(HL.Boolean) << false
CardGameDoudizhuSystem.m_phaseReadyWatchdogTimer = HL.Field(HL.Number) << -1



CardGameDoudizhuSystem.m_seatMembers = HL.Field(HL.Table)

CardGameDoudizhuSystem.m_actualSeatToHudSeat = HL.Field(HL.Table)
CardGameDoudizhuSystem.m_memberIdToHudSeat = HL.Field(HL.Table)

CardGameDoudizhuSystem.m_stateGraph = HL.Field(HL.Any)
CardGameDoudizhuSystem.m_presentationRunner = HL.Field(HL.Any)


CardGameDoudizhuSystem.m_operationDeadlineTimer = HL.Field(HL.Number) << -1



CardGameDoudizhuSystem.m_hudOwner = HL.Field(HL.Any)

CardGameDoudizhuSystem.m_clientFlowBlocked = HL.Field(HL.Boolean) << false
CardGameDoudizhuSystem.m_sendEmojiCdEndTime = HL.Field(HL.Number) << 0
CardGameDoudizhuSystem.m_sendEmojiCdTimer = HL.Field(HL.Number) << -1

CardGameDoudizhuSystem.m_finalSettleArg = HL.Field(HL.Table)

CardGameDoudizhuSystem.m_isLeaveByPlayer = HL.Field(HL.Boolean) << false
CardGameDoudizhuSystem.m_leaveRoomType = HL.Field(HL.Number) << 0

CardGameDoudizhuSystem.m_forceLeaveUpdateKey = HL.Field(HL.Number) << -1

CardGameDoudizhuSystem.m_isFinalMusicPlayed = HL.Field(HL.Boolean) << false

CardGameDoudizhuSystem.m_bidStartHudSeat = HL.Field(HL.Number) << 0

CardGameDoudizhuSystem.m_dealtCardCounts = HL.Field(HL.Table)


CardGameDoudizhuSystem.isPauseByGuide = HL.Field(HL.Boolean) << false

CardGameDoudizhuSystem.m_countDownPausedAccumMs = HL.Field(HL.Number) << 0
CardGameDoudizhuSystem.m_countDownPauseStartMs = HL.Field(HL.Number) << -1

CardGameDoudizhuSystem.m_countDownDeadlineMs = HL.Field(HL.Number) << 0



CardGameDoudizhuSystem.scene = HL.Field(HL.Forward("CardGameSceneDoudizhu"))





CardGameDoudizhuSystem.CardGameDoudizhuSystem = HL.Constructor() << function(self)
end

CardGameDoudizhuSystem.OnInit = HL.Override() << function(self)
    self.m_presentationRunner = PresentationRunner(self)
    self.m_stateGraph = StateGraph.Graph()
    self:_ClearSeatData()
    self:_ClearRuntimeState()

    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_CREATE, function(arg)
        self:_InitGameSystem(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_SUCCESS_ANIM_OUT_FINISH, function(arg)
        self:_OpenGameHud(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_LEAVE, function(arg)
        
        local memberId, isSelf = unpack(arg)
        if isSelf then
            self:_OnPlayRoomLeave()
        end
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_NEED_LEAVE, function(arg)
        self:_OnPlayRoomNeedLeave(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED, function()
        self:_OnPlayRoomInfoChanged()
    end)
    self:RegisterMessage(MessageConst.ON_DOUDIZHU_NOTIFY, function(arg)
        self:_OnDoudizhuNotify(arg)
    end)
    self:RegisterMessage(MessageConst.ON_DOUDIZHU_OP_RESULT, function(arg)
        self:_OnDoudizhuOpResult(arg)
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_ROOM_EMOJI_NOTIFY, function(arg)
        self:_OnRoomEmojiNotify(arg)
    end)
    self:RegisterMessage(MessageConst.SET_PAUSE_CARD_GAME_BY_GUIDE, function(arg)
        self:SetPauseByGuide(arg)
    end)
    self:RegisterMessage(MessageConst.SET_DOUDIZHU_GUIDE_HAND_RANGE, function(arg)
        self:_SetGuideHandRange(arg)
    end)
    self:RegisterMessage(MessageConst.SET_DOUDIZHU_HAND_CARDS_SELECTED_BY_GUIDE, function(arg)
        self:_SetHandCardsSelectedByGuide(arg)
    end)
    self:RegisterMessage(MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED, function()
        self:_SyncSelfHandRegionLayout()
    end)
end

CardGameDoudizhuSystem.OnRelease = HL.Override() << function(self)
    self.m_phaseReady = false
    self.m_phaseActive = false
    self.m_presentationRunner:CancelActive(false, "Release")
    self:_CloseFinalSettleRank()
    self:_ClosePlayerGameInfo()
    self:DetachHud()
    self:_ClosePhase()
    if self.scene then
        self.scene:Unload()
        self.scene = nil
    end
    self:_ClearSeatData()
    self:_ClearRuntimeState()
    self.m_roomData = nil
end





CardGameDoudizhuSystem._OnPlayRoomLeave = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame then
        return
    end

    
    
    if not self.m_isLeaveByPlayer and self.m_finalSettleArg ~= nil then
        self.m_inGame = false
        return
    end

    self:_StopGame()
end




CardGameDoudizhuSystem._OnPlayRoomNeedLeave = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    
    if self.m_roomData == nil then
        return
    end
    local reason = unpack(arg)
    if reason == CS.Proto.MULTIPLAYER_PLAY_ROOM_LEAVE_REASON.GameEnded then
        return
    end
    if self.m_forceLeaveUpdateKey > 0 then
        return
    end

    logger.info("[斗地主] 服务端要求离开局内房，强制收拢, reason=" .. tostring(reason))
    
    self.m_inGame = false
    self.m_clientFlowBlocked = true
    self:_TryForceLeavePlayRoom()
end


CardGameDoudizhuSystem._TryForceLeavePlayRoom = HL.Method() << function(self)
    if PhaseManager:IsInPhaseTransition() then
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

CardGameDoudizhuSystem._ClearForceLeaveUpdate = HL.Method() << function(self)
    if self.m_forceLeaveUpdateKey > 0 then
        LuaUpdate:Remove(self.m_forceLeaveUpdateKey)
    end
    self.m_forceLeaveUpdateKey = -1
end


CardGameDoudizhuSystem._OnPlayRoomInfoChanged = HL.Method() << function(self)
    if not self.m_inGame then
        return
    end
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    for _, seat in pairs(self.m_seatMembers) do
        local briefMember = playRoomSystem:GetBriefMemberByMemberId(seat.memberId)
        if briefMember ~= nil then
            seat.briefData = briefMember.briefData
        end
    end
    self:_RefreshHudByState("PlayRoomInfoChanged")
    local ctrl = self:_GetPlayerGameInfoCtrl()
    if not ctrl then
        return
    end
    local hudSeat = ctrl:GetHudSeat()
    local seat = self.m_seatMembers[hudSeat]
    local briefMember = playRoomSystem:GetBriefMemberByMemberId(seat.memberId)
    
    local player = briefMember ~= nil and self:_BuildPlayerSnapshot(hudSeat) or nil
    ctrl:RefreshPlayerSocialInfo(player)
end



CardGameDoudizhuSystem._InitGameSystem = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local gameType = arg and unpack(arg)
    if gameType ~= DOUDIZHU_GAME_TYPE then
        return
    end

    local roomData = GameInstance.player.multiplayerPlayRoomSystem.doudizhuRoom
    if roomData == nil then
        self:_ReportClientFlowError("收到斗地主 CREATE 时房间权威数据不存在")
        return
    end

    
    GameInstance.player.friendSystem:SyncBlackList()

    local wasInGame = self.m_inGame
    self.m_presentationRunner:Reset("PlayRoomCreate")
    self.m_finalSettleArg = nil
    self.m_bidStartHudSeat = 0
    self:_ClosePlayerGameInfo()
    self.m_roomData = roomData
    self.m_inGame = true
    self:_SyncCountDownDeadline()
    
    self.m_clientFlowBlocked = false
    
    self:_ClearOperationDeadline()
    if not self:_DispatchStateTrigger(
            wasInGame and HSM_TRIGGER.RecoveryRequired or HSM_TRIGGER.EnterRoom,
            wasInGame and "PlayRoomResync" or "PlayRoomCreate") then
        self:_ReportClientFlowError("启动牌局时状态转换被拒绝")
        return
    end
    if wasInGame then
        
        self:_RefreshHudByState("Recovering", { reason = "PlayRoomResync" })
    end
    
    
    if not self:_BuildSeatData() then
        self:_ReportClientFlowError("三人座位映射不完整")
        return
    end
    if not self:_ValidateAuthoritySnapshot() then
        self:_ReportClientFlowError("服务器权威快照校验失败")
        return
    end
    local pendingBatches = {}
    for _, batch in cs_pairs(roomData.pendingPresentations) do
        pendingBatches[#pendingBatches + 1] = batch
    end
    table.sort(pendingBatches, function(a, b) return a.localEventId < b.localEventId end)
    self.m_presentationRunner:SetPending(pendingBatches)
    if not wasInGame then
        if not self:_DispatchStateTrigger(HSM_TRIGGER.RoomReady, "SeatDataReady") then
            self:_ReportClientFlowError("房间就绪状态转换被拒绝")
            return
        end
    end
    local reusePhase = wasInGame and PhaseManager:IsOpenAndValid(PHASE_ID)
    if not reusePhase then
        self.m_phaseReady = false
        self.m_phaseActive = false
        self.m_headlessPresentation = false
        self.m_phaseReadyWatchdogTimer = -1
    end
    local syncReason = wasInGame and "PlayRoomResync" or "PlayRoomCreate"
    if not self:_SyncStateFromAuthority(syncReason) then
        self:_ReportClientFlowError("状态图拒绝服务器权威快照")
        return
    end
    local didRebuild = false
    if reusePhase then
        local ok
        ok, didRebuild = self:_TryRebuildCardVisual("服务器全量数据落地后重建牌桌失败")
        if not ok then
            return
        end
    end
    if not didRebuild then
        self:_RefreshHudByState(syncReason)
    end
    if not reusePhase then
        if self.scene then
            self.scene:Unload()
            self.scene = nil
        end
        self.scene = CardGameSceneDoudizhu()
        self.scene:Init(self:_BuildSeatChars())
    end
    self.m_presentationRunner:TryPlayNext()
end


CardGameDoudizhuSystem._OpenGameHud = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local gameType = arg and unpack(arg)
    if gameType ~= DOUDIZHU_GAME_TYPE then
        return
    end
    if not self.m_inGame or self.m_clientFlowBlocked then
        return
    end
    if PhaseManager:IsOpenAndValid(PHASE_ID) then
        return
    end

    self:_OpenPhase()
end

CardGameDoudizhuSystem._StopGame = HL.Method() << function(self)
    local leaveRoomType = self.m_leaveRoomType
    self.m_phaseReady = false
    self.m_phaseActive = false
    self:_ClearOperationDeadline()
    self:_DispatchStateTrigger(HSM_TRIGGER.LeaveRoom, "PlayRoomLeave")
    
    self.m_presentationRunner:CancelActive(false, "PlayRoomLeave")
    self:_ClosePlayerGameInfo()
    self:DetachHud()
    self:_ClosePhase()
    if self.scene then
        self.scene:Unload()
        self.scene = nil
    end
    self:_ClearSeatData()
    self:_ClearRuntimeState()
    self.m_roomData = nil
    
    GameInstance.player.multiplayerPlayRoomSystem:ClearRoom()
    self:_CloseFinalSettleRank()
    LuaSystemManager.cardGameSystem:StopGame()
    if leaveRoomType ~= 0 then
        Notify(MessageConst.ON_MULTIPLAYER_PLAY_ROOM_RETURN, leaveRoomType)
    end
end

CardGameDoudizhuSystem._ClearRuntimeState = HL.Method() << function(self)
    TimerManager:ClearAllTimer(self)
    self:_ClearForceLeaveUpdate()
    self.m_presentationRunner:Reset("ClearRuntime")
    self:_SetDealPerformForbidHotswap(false)
    self:_SetSettlementToastForbidHotswap(false)
    self:_ClearOperationDeadline()
    self.m_phaseReady = false
    self.m_phaseActive = false
    self.m_clientFlowBlocked = false
    self.m_sendEmojiCdEndTime = 0
    self.m_sendEmojiCdTimer = -1
    self.m_finalSettleArg = nil
    self.m_isLeaveByPlayer = false
    self.m_leaveRoomType = 0
    self.m_isFinalMusicPlayed = false
    self.m_bidStartHudSeat = 0
    self.m_dealtCardCounts = nil
    self.isPauseByGuide = false
    self.m_countDownPausedAccumMs = 0
    self.m_countDownPauseStartMs = -1
    self.m_countDownDeadlineMs = 0
    if self.m_stateGraph ~= nil then
        self.m_stateGraph:Reset("ClearRuntime")
    end
end






CardGameDoudizhuSystem.CanConsumePresentations = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_roomData ~= nil and not self.m_clientFlowBlocked and not self.isPauseByGuide
            and (self.m_headlessPresentation or self.m_phaseReady )
end


CardGameDoudizhuSystem.ShouldFastForwardPresentation = HL.Method(HL.Any).Return(HL.Boolean) << function(self, batch)
    return self.m_headlessPresentation 
end


CardGameDoudizhuSystem.CanFastForwardOnNewEvent = HL.Method().Return(HL.Boolean) << function(self)
    return not self:_IsNewbieGuideRoom()
end

CardGameDoudizhuSystem.ShouldFinishDealBeforePresentation = HL.Method(HL.Any).Return(HL.Boolean) << function(self, batch)
    return self.m_phaseReady  and not self.m_headlessPresentation
            and self.m_roomData.phase == CS.Proto.DDZ_PHASE.Bid
            and (batch.type == PresentationType.BidTurn or batch.type == PresentationType.BidResult)
end

CardGameDoudizhuSystem.RebuildPresentation = HL.Method() << function(self)
    if not self.m_phaseReady then
        return
    end
    
    if self.m_headlessPresentation and not self:_HasCardRegions() then
        return
    end
    if not self:_RebuildCardVisual(true) then
        logger.error("[斗地主] 斗地主表现终态重建失败")
    end
end

CardGameDoudizhuSystem.OnOnePresentationFinished = HL.Method(HL.Table).Return(HL.Boolean) << function(self, item)
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    if playRoomSystem.doudizhuRoom == self.m_roomData then
        if not playRoomSystem:NotifyDoudizhuPresentationDone(item.localEventId) then
            return false
        end
    elseif self.m_inGame or item.batch.type ~= PresentationType.Settle then
        return false
    end
    
    if item.batch.type == PresentationType.Settle then
        self:_CompleteFinalSettlePresentation(item.hudCommand.finalSettleArg)
    end
    return true
end

CardGameDoudizhuSystem.OnPresentationQueueAllDone = HL.Method() << function(self)
    
    
    self:_RefreshOperationDeadline()
    self:_RefreshHudByState("PresentationQueueIdle")
end





CardGameDoudizhuSystem._OnDoudizhuNotify = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local localEventId = arg and unpack(arg)
    local batch = self.m_roomData and self.m_roomData:GetPendingPresentation(localEventId) or nil
    self:_SyncCountDownDeadline()
    if batch ~= nil and batch.type == PresentationType.Deal then
        self.m_finalSettleArg = nil
    end
    
    if batch ~= nil then
        self:_RefreshPlayerGameInfo()
    end
    if batch ~= nil and batch.type == PresentationType.Settle then
        
        self.m_finalSettleArg = self:_BuildFinalSettleArg(batch.settlement)
    end
    
    if batch ~= nil and not self.m_isFinalMusicPlayed and batch.type == PresentationType.PlayAction
            and batch.remainCount <= 5 then
        self.m_isFinalMusicPlayed = true
        AudioManager.PostEvent("au_music_gambling_v1d7_doudizhu_final")
    end
    
    if batch ~= nil and self.m_inGame and batch.isServerAutoAction then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CARD_GAME_DOUDIZHU_PLAY_TIMEOUT_TOAST)
    end
    self:_ClearOperationDeadline()
    if batch ~= nil and self.m_inGame then
        self.m_presentationRunner:Enqueue(batch)
    end
end

CardGameDoudizhuSystem._OnDoudizhuOpResult = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame then
        return
    end
    local seqId, opType, retCode = unpack(arg)
    
    if retCode ~= CS.Proto.DDZ_OP_RET_CODE.DdzOpRetOk then
        logger.error(string.format("[斗地主][操作] 请求被拒绝：操作=%s，返回码=%s，序号=%s", tostring(opType), tostring(retCode), tostring(seqId)))
    end
    self:_RefreshOperationDeadline()
    self:_RefreshHudByState("OperationResult")
end







CardGameDoudizhuSystem._CanOperateWindow = HL.Method(HL.Any, HL.String, HL.Opt(HL.Boolean)).Return(HL.Boolean)
        << function(self, requiredPhase, requiredFlowState, ignorePhaseActive)
    local room = self.m_roomData
    return room ~= nil
            and self.m_inGame
            and self.m_phaseReady
            and (self.m_phaseActive or ignorePhaseActive == true)
            and not self.m_headlessPresentation
            and room.phase == requiredPhase
            and self:GetFlowState() == requiredFlowState
            and room.turnMemberId == room.selfMemberId
            and room.currentTurnSeqId ~= 0
            and not room.hasPendingOperation 
            and not self.m_clientFlowBlocked
            and not self:_IsOperationWindowExpired()
            and not self.m_presentationRunner:IsBusy() 
end

CardGameDoudizhuSystem._SendBidOperation = HL.Method(HL.Boolean, HL.Any).Return(HL.Boolean) << function(self, bid, seqId)
    local submitted = GameInstance.player.multiplayerPlayRoomSystem:SendDoudizhuBid(bid, seqId)
    if submitted then
        self:_ClearOperationDeadline()
        self:_RefreshHudByState("OperationSubmitted")
    end
    return submitted
end

CardGameDoudizhuSystem._SendPlayOperation = HL.Method(HL.Any, HL.Any, HL.Any).Return(HL.Boolean) << function(self, instIds, pattern, seqId)
    local submitted = GameInstance.player.multiplayerPlayRoomSystem:SendDoudizhuPlay(instIds, seqId, pattern)
    if submitted then
        self:_ClearOperationDeadline()
        self:_RefreshHudByState("OperationSubmitted")
    end
    return submitted
end

CardGameDoudizhuSystem._SendPassOperation = HL.Method(HL.Any).Return(HL.Boolean) << function(self, seqId)
    local submitted = GameInstance.player.multiplayerPlayRoomSystem:SendDoudizhuPass(seqId)
    if submitted then
        self:_ClearOperationDeadline()
        self:_RefreshHudByState("OperationSubmitted")
    end
    return submitted
end

CardGameDoudizhuSystem._IsOperationWindowExpired = HL.Method().Return(HL.Boolean) << function(self)
    local room = self.m_roomData
    local deadlineMs = room and room.deadlineMs or 0
    return deadlineMs > 0 and self:GetCountDownNowMs() >= deadlineMs
end

CardGameDoudizhuSystem._ClearOperationDeadline = HL.Method() << function(self)
    if self.m_operationDeadlineTimer ~= nil and self.m_operationDeadlineTimer >= 0 then
        self.m_operationDeadlineTimer = self:_ClearTimer(self.m_operationDeadlineTimer)
    else
        self.m_operationDeadlineTimer = -1
    end
end

CardGameDoudizhuSystem._RefreshOperationDeadline = HL.Method() << function(self)
    self:_ClearOperationDeadline()
    
    if self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Bid, FLOW_STATE.Bidding, true)
            or self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Play, FLOW_STATE.Playing, true) then
        self:_ScheduleOperationDeadline()
    end
end

CardGameDoudizhuSystem._ScheduleOperationDeadline = HL.Method() << function(self)
    self:_ClearOperationDeadline()
    
    if self.isPauseByGuide then
        return
    end
    local room = self.m_roomData
    if room == nil or room.currentTurnSeqId == 0 or room.deadlineMs <= 0 then
        return
    end
    local windowSeqId = room.currentTurnSeqId
    local remainingMs = room.deadlineMs - self:GetCountDownNowMs()
    if remainingMs <= 0 then
        self:NotifyActionDeadlineExpired(windowSeqId)
        return
    end
    self.m_operationDeadlineTimer = self:_StartTimer(remainingMs / 1000, function()
        self.m_operationDeadlineTimer = -1
        self:NotifyActionDeadlineExpired(windowSeqId)
    end, true)
end








CardGameDoudizhuSystem._StartPresentationTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean)).Return(HL.Number) << function(self, duration, action, unscaled)
    return self.m_presentationRunner:StartTimer(duration, action, unscaled)
end


CardGameDoudizhuSystem._PlayDefaultPresentationEffect = HL.Method(HL.Any, HL.Table, HL.Function).Return(HL.Opt(HL.Function))
        << function(self, batch, hudCommand, onDone)
    local presentationType = batch.type
    if presentationType == PresentationType.Deal then
        return self:_PlayDealPresentation(hudCommand, onDone)
    elseif presentationType == PresentationType.Bottom then
        return self:_PlayBottomPresentation(hudCommand, onDone)
    elseif presentationType == PresentationType.PlayAction then
        return self:_PlayCardsPresentation(batch, onDone)
    elseif presentationType == PresentationType.Pass then
        self:_PlayPassPresentation(batch, onDone)
    elseif presentationType == PresentationType.PlayTurn then
        self:_PlayTurnPresentation(batch, onDone)
    elseif presentationType == PresentationType.Settle then
        self:_RebuildCardVisual()
        onDone()
    else
        onDone()
    end
end


CardGameDoudizhuSystem._ShouldHoldUndealtVisual = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_presentationRunner:HasPendingDeal() or self.m_stateGraph:IsIn(FLOW_STATE.WaitingStart)
end



CardGameDoudizhuSystem._ValidatePresentationCardIds = HL.Method(HL.Any, HL.Opt(HL.Number))
        .Return(HL.Boolean) << function(self, source, expectedCount)
    local instIds = self:_CopyCSList(source)
    if expectedCount ~= nil and #instIds ~= expectedCount then
        return false
    end
    local seen = {}
    for _, instId in ipairs(instIds) do
        local cardData = self.m_roomData and self.m_roomData:GetDoudizhuCard(instId) or nil
        if instId == 0 or seen[instId] or cardData == nil or not cardData.isValid then
            return false
        end
        seen[instId] = true
    end
    return true
end

CardGameDoudizhuSystem._ValidateAuthoritySnapshot = HL.Method().Return(HL.Boolean) << function(self)
    local room = self.m_roomData
    local phase = room and room.phase or CS.Proto.DDZ_PHASE.Invalid
    local phaseValid = phase == CS.Proto.DDZ_PHASE.WaitingStart
            or phase == CS.Proto.DDZ_PHASE.Deal
            or phase == CS.Proto.DDZ_PHASE.Bid
            or phase == CS.Proto.DDZ_PHASE.Play
            or phase == CS.Proto.DDZ_PHASE.Settle
    local selfMember = room and room:GetDoudizhuSelfMember() or nil
    if not phaseValid or selfMember == nil
            or selfMember.handCardsInstIds.Count ~= selfMember.handCardsCount
            or not self:_ValidatePresentationCardIds(
                    selfMember.handCardsInstIds, selfMember.handCardsCount) then
        return false
    end
    local bottomCount = room.bottomInstIds.Count
    if bottomCount ~= 0 and bottomCount ~= 3 then
        return false
    end
    if bottomCount == 3 and not self:_ValidatePresentationCardIds(room.bottomInstIds, 3) then
        return false
    end
    local lastAction = room.lastAction
    if lastAction ~= nil and lastAction.memberId ~= 0
            and (self.m_memberIdToHudSeat[lastAction.memberId] == nil
                or lastAction.cardInstIds.Count <= 0
                or not self:_ValidatePresentationCardIds(lastAction.cardInstIds)) then
        return false
    end
    return (room.landlordMemberId == 0
                or self.m_memberIdToHudSeat[room.landlordMemberId] ~= nil)
            and (room.turnMemberId == 0
                or self.m_memberIdToHudSeat[room.turnMemberId] ~= nil)
end


CardGameDoudizhuSystem._ValidatePresentationBatch = HL.Method(HL.Any).Return(HL.Boolean)
        << function(self, batch)
    if batch == nil or self.m_roomData == nil then
        return false
    end
    local presentationType = batch.type
    local requiresMember = presentationType == PresentationType.BidTurn
            or presentationType == PresentationType.BidResult
            or presentationType == PresentationType.PlayTurn
            or presentationType == PresentationType.PlayAction
            or presentationType == PresentationType.Pass
    if requiresMember and (batch.memberId == 0
            or self.m_memberIdToHudSeat[batch.memberId] == nil) then
        return false
    end

    if presentationType == PresentationType.Deal then
        for hudSeat = 1, MAX_SEAT_COUNT do
            if self.m_seatMembers[hudSeat] == nil
                    or self:_GetAuthorityMemberByHudSeat(hudSeat) == nil then
                return false
            end
        end
        return batch.remainCount > 0 and batch.remainCount <= 20
                and self.m_memberIdToHudSeat[batch.memberId] == HUD_SEAT.Self
                and self.m_actualSeatToHudSeat[batch.seatId] == HUD_SEAT.Self
                and self:_ValidatePresentationCardIds(batch.cardInstIds, batch.remainCount)
    elseif presentationType == PresentationType.Bottom then
        return self.m_memberIdToHudSeat[batch.landlordMemberId] ~= nil
                and self:_ValidatePresentationCardIds(batch.bottomInstIds, 3)
    elseif presentationType == PresentationType.PlayAction then
        return batch.cardInstIds ~= nil and batch.cardInstIds.Count > 0
                and self:_ValidatePresentationCardIds(batch.cardInstIds)
    end
    return true
end

CardGameDoudizhuSystem._PrepareFlowForPresentation = HL.Method(HL.Any).Return(HL.Boolean) << function(self, batch)
    if self.m_clientFlowBlocked or not self:_ValidatePresentationBatch(batch) then
        logger.error(string.format(
                "[斗地主][表现] 表现快照校验失败：类型=%s，协议序号=%s",
                tostring(batch and batch.type or nil), tostring(batch and batch.seqId or nil)))
        return false
    end
    return self.m_stateGraph:DispatchPresentation(batch)
end

CardGameDoudizhuSystem._SyncStateFromAuthority = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, reason, context)
    if not self.m_stateGraph:IsIn(FLOW_STATE.Recovering) then
        if not self:_DispatchStateTrigger(HSM_TRIGGER.FullSync, reason .. "Begin", context) then
            logger.error("[斗地主][流程] 收到全量数据后无法进入 Recovering：" .. tostring(reason))
            return false
        end
    end
    local applied = self.m_stateGraph:ApplyAuthoritySnapshot(self.m_roomData.phase, { reason = reason, context = context })
    if not applied then
        return false
    end
    self.m_clientFlowBlocked = false
    self:_RefreshOperationDeadline()
    logger.info(string.format("[斗地主][数据] 全量数据对齐完成：服务端阶段=%s，客户端阶段=%s",
            tostring(self.m_roomData and self.m_roomData.phase or nil),
            tostring(self:GetFlowState())))
    return true
end

CardGameDoudizhuSystem._DispatchStateTrigger = HL.Method(HL.String, HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, triggerId, reason, context)
    if self.m_stateGraph == nil then
        return false
    end
    local payload = {}
    if type(context) == "table" then
        for key, value in pairs(context) do
            payload[key] = value
        end
    end
    payload.reason = reason
    payload.context = context
    local handled = self.m_stateGraph:Dispatch(triggerId, payload)
    if not handled then
        logger.error(string.format("[斗地主][流程] 状态图拒绝 Trigger：当前阶段=%s，Trigger=%s，原因=%s",
                tostring(self:GetFlowState()), tostring(triggerId), tostring(reason)))
    end
    return handled
end

CardGameDoudizhuSystem._ReportClientFlowError = HL.Method(HL.String, HL.Opt(HL.Any))
        << function(self, reason, context)
    local detail = type(context) == "table" and context or {}
    local errorText = type(context) == "table" and context.error or context
    logger.error(string.format(
            "[斗地主][客户端流程错误] 本地流程已阻断，不会自动请求 FullSync；请在开发期间修复。"
                    .. "原因=%s，本地事件=%s，阶段=%s，协议序号=%s，操作=%s，返回码=%s，错误=%s",
            tostring(reason), tostring(detail.localEventId), tostring(detail.stage),
            tostring(detail.seqId), tostring(detail.opType), tostring(detail.retCode),
            tostring(errorText)))

    local firstError = not self.m_clientFlowBlocked
    self.m_clientFlowBlocked = true
    self:_ClearOperationDeadline()
    if firstError then
        
        self.m_presentationRunner:Reset("ClientFlowBlocked:" .. reason)
    end
    self:_RefreshHudByState("ClientFlowBlocked", context)
end


CardGameDoudizhuSystem._TryRebuildCardVisual = HL.Method(HL.String, HL.Opt(HL.Boolean))
        .Return(HL.Boolean, HL.Boolean) << function(self, reason, ignoreDealPresentationGate)
    local ok, result = xpcall(function()
        return self:_RebuildCardVisual(ignoreDealPresentationGate)
    end, debug.traceback)
    if not ok then
        self:_ReportClientFlowError(reason, {
            stage = "RebuildCardVisual",
            error = result,
        })
        return false, false
    end
    return true, result
end



CardGameDoudizhuSystem._CopyCSList = HL.Method(HL.Any).Return(HL.Table) << function(self, source)
    local result = {}
    if source == nil then
        return result
    end
    for index = 0, source.Count - 1 do
        result[#result + 1] = source[index]
    end
    return result
end

CardGameDoudizhuSystem._CopyLuaArray = HL.Method(HL.Opt(HL.Table)).Return(HL.Table) << function(self, source)
    local result = {}
    for index, value in ipairs(source or {}) do
        result[index] = value
    end
    return result
end




CardGameDoudizhuSystem._TriggerSelfBoardgameVoice = HL.Method(HL.String) << function(self, voiceType)
    local briefData = self.m_seatMembers and self.m_seatMembers[HUD_SEAT.Self] and self.m_seatMembers[HUD_SEAT.Self].briefData
    CardGameUtils.TriggerVoice(voiceType, briefData and briefData.charId)
end

CardGameDoudizhuSystem._SetDealPerformForbidHotswap = HL.Method(HL.Boolean) << function(self, forbid)
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(DEAL_PERFORM_FORBID_HOTSWAP_KEY, forbid)
end

CardGameDoudizhuSystem._SetSettlementToastForbidHotswap = HL.Method(HL.Boolean) << function(self, forbid)
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(SETTLEMENT_TOAST_FORBID_HOTSWAP_KEY, forbid)
end

CardGameDoudizhuSystem._ClearPlayRegions = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    for hudSeat = 1, MAX_SEAT_COUNT do
        local regionId = CARD_REGION_PLAYER_PLAY_IDS[hudSeat]
        if cardSystem:GetRegion(regionId) ~= nil then
            cardSystem:RecycleRegionCards(regionId)
        end
    end
end

CardGameDoudizhuSystem._PlayDealPresentation = HL.Method(HL.Table, HL.Function).Return(HL.Opt(HL.Function)) << function(self, hudCommand, onDone)
    local cardSystem = LuaSystemManager.cardGameSystem
    self:_PrepareHudCardHandoff(hudCommand)
    cardSystem:ClearRuntimeCards()
    
    if not hudCommand.isRedeal then
        self:_TriggerSelfBoardgameVoice(CardGameUtils.VoiceType.Start)
    end
    local cardsPerSeat = {}
    local handShuffleOrders = {}
    for hudSeat = 1, MAX_SEAT_COUNT do
        local member = self:_GetAuthorityMemberByHudSeat(hudSeat)
        local entries = {}
        local finalOrder = {}
        if member ~= nil and member.isSelf then
            finalOrder = self:_SortHandInstIds(self:_CopyCSList(member.handCardsInstIds))
            for _, instId in ipairs(self:_ShuffleHandInstIds(finalOrder)) do
                entries[#entries + 1] = { uid = instId, faceUp = true }
            end
        elseif member ~= nil then
            for index = 1, member.handCardsCount do
                local uid = self:_MakeHandPlaceholderUid(hudSeat, index)
                entries[#entries + 1] = {
                    uid = uid,
                    faceUp = false,
                }
                finalOrder[#finalOrder + 1] = uid
            end
        end
        cardsPerSeat[hudSeat] = entries
        handShuffleOrders[hudSeat] = finalOrder
    end

    local dealQueue = {}
    for cardIndex = 1, 20 do
        local added = false
        for hudSeat = 1, MAX_SEAT_COUNT do
            local entry = cardsPerSeat[hudSeat][cardIndex]
            if entry ~= nil then
                entry.hudSeat = hudSeat
                dealQueue[#dealQueue + 1] = entry
                added = true
            end
        end
        if not added then
            break
        end
    end

    for index = #dealQueue, 1, -1 do
        local entry = dealQueue[index]
        cardSystem:CreateCard(CARD_REGION_DECK, entry.uid)
        if entry.faceUp then
            self:_SetVisualCardFace(entry.uid, entry.uid, false)
        end
    end
    for index = 1, 3 do
        cardSystem:CreateCard(CARD_REGION_DECK, BOTTOM_VISUAL_UID_BASE - index)
    end
    cardSystem:RelayoutRegion(CARD_REGION_DECK, false)

    if not self:_PrepareDealTargets(cardsPerSeat, dealQueue) then
        logger.error("斗地主发牌表现目标不完整")
    end

    local dealState = {
        cancelled = false,
        pendingMoveCount = 0,
        allScheduled = false,
        completed = false,
        cardIntervalSeconds = Tables.LandLoardConst.dealCardIntervalMs / 1000,
    }
    local hudOwner = self.m_hudOwner
    self:_SetDealPerformForbidHotswap(true)
    local finish = function()
        self:_SetDealPerformForbidHotswap(false)
        self.m_dealtCardCounts = nil
        onDone()
    end
    local cancel = function(applyFinal)
        dealState.cancelled = true
        self:_SetDealPerformForbidHotswap(false)
        self.m_dealtCardCounts = nil
        if hudOwner ~= nil then
            hudOwner:PlaySeatIntro(false)
        end
    end
    dealState.onAllCardsComplete = function()
        if dealState.cancelled then
            return
        end
        self:_PlayInitialHandShuffle(handShuffleOrders, dealState, function()
            if dealState.cancelled then
                return
            end
            self:_PlayBottomDealToHud(dealState, finish)
        end)
    end
    if hudCommand.isRedeal or hudOwner == nil then
        AudioAdapter.PostEvent("Au_UI_Event_Card3Dealing")
        self:_ScheduleDealCard(dealQueue, 1, dealState)
        return cancel
    end

    local seatIntroPlayers = {}
    for hudSeat = 1, MAX_SEAT_COUNT do
        local info = self:_BuildMemberDisplayInfo(self.m_seatMembers[hudSeat].memberId)
        info.seatIndex = hudCommand.viewModel.seats[hudSeat].serverSeatId
        seatIntroPlayers[hudSeat] = info
    end
    
    hudOwner:PlaySeatIntro(true, seatIntroPlayers, self.m_actualSeatToHudSeat[1], function()
        if dealState.cancelled then
            return
        end
        AudioAdapter.PostEvent("Au_UI_Event_Card3Dealing")
        self:_ScheduleDealCard(dealQueue, 1, dealState)
    end)
    return cancel
end



CardGameDoudizhuSystem._PrepareDealTargets = HL.Method(HL.Table, HL.Table).Return(HL.Boolean)
        << function(self, cardsPerSeat, dealQueue)
    local cardSystem = LuaSystemManager.cardGameSystem
    local deckRegion = cardSystem:GetRegion(CARD_REGION_DECK)
    local allCards = {}
    for _, entry in ipairs(dealQueue) do
        local card = cardSystem:GetRuntimeCard(entry.uid)
        if card == nil or card.regionId ~= CARD_REGION_DECK then
            return false
        end
        allCards[#allCards + 1] = card
    end
    if #allCards > 0 and not deckRegion:RemoveCards(allCards, false) then
        return false
    end

    for hudSeat = 1, MAX_SEAT_COUNT do
        local entries = cardsPerSeat[hudSeat]
        if #entries > 0 then
            local cards = {}
            for _, entry in ipairs(entries) do
                cards[#cards + 1] = cardSystem:GetRuntimeCard(entry.uid)
            end
            local handRegion = cardSystem:GetRegion(CARD_REGION_PLAYER_HAND_IDS[hudSeat])
            local targetPoses = handRegion ~= nil and handRegion:AddCards(cards, false, false) or nil
            if targetPoses == nil or #targetPoses ~= #entries then
                return false
            end
            for index, entry in ipairs(entries) do
                entry.targetPose = targetPoses[index]
            end
        end
    end
    return true
end


CardGameDoudizhuSystem._AddDealtCardCount = HL.Method(HL.Number) << function(self, hudSeat)
    local counts = self.m_dealtCardCounts
    if counts == nil then
        return
    end
    counts[hudSeat] = (counts[hudSeat] or 0) + 1
    if self.m_hudOwner ~= nil then
        self.m_hudOwner:SetSeatHandCardCount(hudSeat, counts[hudSeat])
    end
end

CardGameDoudizhuSystem._ScheduleDealCard = HL.Method(HL.Table, HL.Number, HL.Table)
        << function(self, dealQueue, index, dealState)
    local tryComplete = function()
        if dealState.cancelled or dealState.completed or not dealState.allScheduled
                or dealState.pendingMoveCount > 0 then
            return
        end
        dealState.completed = true
        dealState.onAllCardsComplete()
    end
    if index > #dealQueue then
        dealState.allScheduled = true
        tryComplete()
        return
    end
    local entry = dealQueue[index]
    dealState.pendingMoveCount = dealState.pendingMoveCount + 1
    LuaSystemManager.cardGameSystem:MoveCardByUidToPose(
            entry.uid, entry.targetPose, entry.faceUp, true, true, function()
        if dealState.cancelled then
            return
        end
        self:_AddDealtCardCount(entry.hudSeat)
        dealState.pendingMoveCount = dealState.pendingMoveCount - 1
        tryComplete()
    end)
    if index < #dealQueue then
        self:_StartPresentationTimer(dealState.cardIntervalSeconds, function()
            if not dealState.cancelled then
                self:_ScheduleDealCard(dealQueue, index + 1, dealState)
            end
        end, true)
    else
        dealState.allScheduled = true
        tryComplete()
    end
end


CardGameDoudizhuSystem._PlayInitialHandShuffle = HL.Method(HL.Table, HL.Table, HL.Function)
        << function(self, handShuffleOrders, dealState, onDone)
    local pendingCount = MAX_SEAT_COUNT
    local finishOne = function()
        if dealState.cancelled then
            
            self:_RebuildCardVisual(true)
            return
        end
        pendingCount = pendingCount - 1
        if pendingCount <= 0 then
            onDone()
        end
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    local landlordConst = Tables.LandLoardConst
    for hudSeat = 1, MAX_SEAT_COUNT do
        cardSystem:PlayHandGatherThenSortByUidList(
                CARD_REGION_PLAYER_HAND_IDS[hudSeat], {}, handShuffleOrders[hudSeat],
                hudSeat == HUD_SEAT.Self,
                landlordConst.handShuffleGatherDurationMs / 1000,
                landlordConst.handShuffleSpreadDurationMs / 1000, finishOne)
    end
end


CardGameDoudizhuSystem._PlayBottomDealToHud = HL.Method(HL.Table, HL.Function)
        << function(self, dealState, finish)
    if dealState.cancelled then
        return
    end
    if self.m_hudOwner ~= nil then
        self.m_hudOwner:PrepareBottomCardDeal()
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    local targetPoses = {}
    for index = 1, 3 do
        local visualUid = BOTTOM_VISUAL_UID_BASE - index
        targetPoses[index] = self:_ResolveHudCardHandoffPose(
                CARD_HANDOFF_ZONE_BOTTOM, visualUid, index, visualUid)
        if targetPoses[index] == nil then
            logger.warn(string.format("[斗地主][底牌] 飞入目标无效，跳过本次飞牌：槽位=%d，HUD存在=%s",
                    index, tostring(self.m_hudOwner ~= nil)))
            
            for cleanupIndex = 1, 3 do
                local pendingUid = BOTTOM_VISUAL_UID_BASE - cleanupIndex
                if cardSystem:GetRuntimeCard(pendingUid) ~= nil then
                    if not cardSystem:RecycleCardByUid(pendingUid, false) then
                        self:_ReportClientFlowError("顶部地主牌临时实体回收失败", {
                            visualUid = pendingUid,
                        })
                        return
                    end
                end
            end
            finish()
            return
        end
    end

    local bottomDealIntervalSeconds = Tables.LandLoardConst.bottomDealIntervalMs / 1000
    local pending = 3
    local finishScheduled = false
    local scheduleFinish = function()
        if dealState.cancelled or finishScheduled then
            return
        end
        finishScheduled = true
        finish()
    end
    local launch
    launch = function(index)
        if dealState.cancelled or index > 3 then
            return
        end
        local visualUid = BOTTOM_VISUAL_UID_BASE - index
        if cardSystem:DetachCardFromRegion(visualUid, true) == nil then
            pending = pending - 1
        else
            cardSystem:MoveCardByUidToPose(visualUid, targetPoses[index], false, true, true, function()
                if dealState.cancelled then
                    self:_RebuildCardVisual(true)
                    return
                end
                self:_SetHudCardHandoffVisible(
                        CARD_HANDOFF_ZONE_BOTTOM, visualUid, index, true, false)
                if not cardSystem:RecycleDetachedCard(visualUid) then
                    self:_ReportClientFlowError("顶部地主牌临时实体回收失败", {
                        visualUid = visualUid,
                    })
                    return
                end
                pending = pending - 1
                if pending <= 0 then
                    scheduleFinish()
                end
            end)
        end
        if index < 3 then
            self:_StartPresentationTimer(bottomDealIntervalSeconds, function()
                if not dealState.cancelled then
                    launch(index + 1)
                end
            end, true)
        elseif pending <= 0 then
            scheduleFinish()
        end
    end
    launch(1)
end


CardGameDoudizhuSystem._PlayBottomPresentation = HL.Method(HL.Table, HL.Function).Return(HL.Opt(HL.Function)) << function(self, hudCommand, onDone)
    local bottomInstIds = hudCommand.bottomInstIds
    local bottomCards = hudCommand.bottomCards
    local landlordHudSeat = hudCommand.landlordHudSeat
    self:_PrepareHudCardHandoff(hudCommand)

    local cardSystem = LuaSystemManager.cardGameSystem
    local landlordMember = self:_GetAuthorityMemberByHudSeat(landlordHudSeat)
    local isSelfLandlord = landlordMember.isSelf
    local handRegionId = CARD_REGION_PLAYER_HAND_IDS[landlordHudSeat]
    local handRegion = cardSystem:GetRegion(handRegionId)
    local addedUids = {}
    for index, instId in ipairs(bottomInstIds) do
        local runtimeUid = isSelfLandlord and instId or BOTTOM_HAND_PREVIEW_UID_BASE - index
        local card = cardSystem:CreateDetachedCard(runtimeUid, isSelfLandlord)
        self:_SetVisualCardFace(runtimeUid, instId, isSelfLandlord)
        self:_SetHudCardHandoffVisible(CARD_HANDOFF_ZONE_BOTTOM,
                instId, index, true, true, bottomCards[index])
        addedUids[index] = runtimeUid
    end

    local finalOrder = {}
    if isSelfLandlord then
        finalOrder = self:_SortHandInstIds(self:_CopyCSList(landlordMember.handCardsInstIds))
    else
        for index = 1, handRegion:GetCardCount() do
            finalOrder[#finalOrder + 1] = handRegion:GetCardAtIndex(index).uid
        end
        for _, uid in ipairs(addedUids) do
            finalOrder[#finalOrder + 1] = uid
        end
    end

    local presentationState = { cancelled = false }
    local finish = onDone
    local cancel = function(applyFinal)
        presentationState.cancelled = true
    end
    for index, uid in ipairs(addedUids) do
        local previewPose = handRegion:BuildAddedCardPreviewPose(index, #addedUids)
        cardSystem:SetRuntimeCardVisible(uid, false)
        cardSystem:MoveCardByUidToPose(uid, previewPose, nil, false, false)
        cardSystem:SetRuntimeCardVisible(uid, true)
    end

    
    local landlordConst = Tables.LandLoardConst
    self:_StartPresentationTimer(landlordConst.bottomRevealHoldMs / 1000, function()
        if presentationState.cancelled then
            return
        end
        AudioAdapter.PostEvent("Au_UI_Event_Card3Shuffling")
        cardSystem:PlayHandGatherThenSortByUidList(
                handRegionId, addedUids, finalOrder, isSelfLandlord,
                landlordConst.handShuffleGatherDurationMs / 1000,
                landlordConst.handShuffleSpreadDurationMs / 1000, function()
                    if presentationState.cancelled then
                        return
                    end
                    finish()
                end)
    end, true)
    return cancel
end


CardGameDoudizhuSystem._PlayTurnPresentation = HL.Method(HL.Any, HL.Function) << function(self, batch, onDone)
    if batch.startsNewRound then
        self:_ClearPlayRegions()
        onDone()
        return
    end

    local hudSeat = self.m_memberIdToHudSeat[batch.memberId]
    LuaSystemManager.cardGameSystem:RecycleRegionCards(CARD_REGION_PLAYER_PLAY_IDS[hudSeat])
    onDone()
end

CardGameDoudizhuSystem._PlayCardsPresentation = HL.Method(HL.Any, HL.Function).Return(HL.Opt(HL.Function)) << function(self, batch, onDone)
    local hudSeat = self.m_memberIdToHudSeat[batch.memberId]
    local cardInstIds = self:_SortPlayedInstIds(
            self:_CopyCSList(batch.cardInstIds), batch.pattern)
    local cardSystem = LuaSystemManager.cardGameSystem
    local playRegionId = CARD_REGION_PLAYER_PLAY_IDS[hudSeat]
    
    cardSystem:RecycleRegionCards(playRegionId)
    local handRegion = cardSystem:GetRegion(CARD_REGION_PLAYER_HAND_IDS[hudSeat])
    if handRegion:GetCardCount() < #cardInstIds then
        logger.error("[斗地主] 斗地主出牌表现的手牌数量不足")
    end

    local presentationState = { cancelled = false }
    local finish = onDone
    local cancel = function(applyFinal)
        presentationState.cancelled = true
    end
    local member = self.m_roomData:GetDoudizhuMember(batch.memberId)
    local isSelfMember = member.isSelf
    if not isSelfMember then
        local handCount = handRegion:GetCardCount()
        for index, instId in ipairs(cardInstIds) do
            local sourceCard = handRegion:GetCardAtIndex(handCount - index + 1)
            if not cardSystem:ReplaceCardUid(sourceCard.uid, instId) then
                logger.error("[斗地主] 斗地主出牌表现替换牌实例失败")
            end
            self:_SetVisualCardFace(instId, instId, false)
        end
    else
        for _, instId in ipairs(cardInstIds) do
            self:_SetVisualCardFace(instId, instId, true)
        end
    end
    local onMoveDone = function()
        if presentationState.cancelled then
            return
        end
        finish()
    end
    AudioAdapter.PostEvent("Au_UI_Event_CardPlay")
    if not cardSystem:MoveCardsByUidToRegion(cardInstIds,
            CARD_REGION_PLAYER_PLAY_IDS[hudSeat], true, true, onMoveDone) then
        logger.error("[斗地主] 斗地主出牌表现移动牌实例失败")
    end
    return cancel
end

CardGameDoudizhuSystem._PlayPassPresentation = HL.Method(HL.Any, HL.Function) << function(self, batch, onDone)
    local hudSeat = self.m_memberIdToHudSeat[batch.memberId]
    LuaSystemManager.cardGameSystem:RecycleRegionCards(CARD_REGION_PLAYER_PLAY_IDS[hudSeat])
    onDone()
end


CardGameDoudizhuSystem._RebuildCardVisual = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Boolean)
        << function(self, ignoreDealPresentationGate)
    if not self.m_phaseReady or self.m_roomData == nil then
        return false
    end
    if self.m_headlessPresentation and not self:_HasCardRegions() then
        return false
    end

    local cardSystem = LuaSystemManager.cardGameSystem
    cardSystem:ClearRuntimeCards()
    
    if not ignoreDealPresentationGate and self:_ShouldHoldUndealtVisual() then
        return false
    end
    
    for hudSeat = 1, MAX_SEAT_COUNT do
        local member = self:_GetAuthorityMemberByHudSeat(hudSeat)
        local regionId = CARD_REGION_PLAYER_HAND_IDS[hudSeat] 
        if member ~= nil and member.isSelf then 
            for _, instId in ipairs(self:_SortHandInstIds(self:_CopyCSList(member.handCardsInstIds))) do
                cardSystem:CreateCard(regionId, instId)
                self:_SetVisualCardFace(instId, instId, true)
            end
        elseif member ~= nil then 
            for index = 1, member.handCardsCount do
                cardSystem:CreateCard(regionId, self:_MakeHandPlaceholderUid(hudSeat, index))
            end
        end
        cardSystem:RelayoutRegion(regionId, false)
    end
    
    local showBottomBack = self.m_roomData.bottomInstIds.Count <= 0
            and self.m_roomData.landlordMemberId == 0
            and (self.m_roomData.phase == CS.Proto.DDZ_PHASE.Deal
                or self.m_roomData.phase == CS.Proto.DDZ_PHASE.Bid)
    
    local lastAction = self.m_roomData.lastAction
    if lastAction ~= nil and lastAction.memberId ~= 0 and lastAction.cardInstIds.Count > 0 then
        local hudSeat = self.m_memberIdToHudSeat[lastAction.memberId]
        if hudSeat ~= nil then
            local regionId = CARD_REGION_PLAYER_PLAY_IDS[hudSeat]
            for _, instId in ipairs(self:_SortPlayedInstIds(self:_CopyCSList(lastAction.cardInstIds),
                    lastAction.pattern)) do
                cardSystem:CreateCard(regionId, instId)
                self:_SetVisualCardFace(instId, instId, true)
            end
            cardSystem:RelayoutRegion(regionId, false)
        end
    end
    
    self:_RefreshHudByState("CardVisualRebuild", {
        kind = HUD_COMMAND_KIND.Rebuild,
        showBottomBack = showBottomBack
    })
    return true
end

CardGameDoudizhuSystem._SetVisualCardFace = HL.Method(HL.Number, HL.Any, HL.Boolean)
        << function(self, visualUid, instId, faceUp)
    local cardData = self.m_roomData and self.m_roomData:GetDoudizhuCard(instId) or nil
    if cardData == nil or not cardData.isValid then
        return
    end
    local pokerSuit = cardData.pokerSuit:GetHashCode()
    local pokerRank = cardData.pokerRank:GetHashCode()
    LuaSystemManager.cardGameSystem:SetCardData(visualUid, pokerSuit, pokerRank, faceUp)
end

CardGameDoudizhuSystem._HasCardRegions = HL.Method().Return(HL.Boolean) << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil or cardSystem:GetRegion(CARD_REGION_DECK) == nil then
        return false
    end
    for hudSeat = 1, MAX_SEAT_COUNT do
        if cardSystem:GetRegion(CARD_REGION_PLAYER_HAND_IDS[hudSeat]) == nil
                or cardSystem:GetRegion(CARD_REGION_PLAYER_PLAY_IDS[hudSeat]) == nil then
            return false
        end
    end
    return true
end


CardGameDoudizhuSystem._MakeHandPlaceholderUid = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, hudSeat, index)
    return HAND_PLACEHOLDER_UID_BASE - hudSeat * HAND_PLACEHOLDER_UID_SEAT_STRIDE - index
end


CardGameDoudizhuSystem._ShuffleHandInstIds = HL.Method(HL.Table).Return(HL.Table)
        << function(self, source)
    local result = self:_CopyLuaArray(source)
    for index = #result, 2, -1 do
        local swapIndex = math.random(index)
        result[index], result[swapIndex] = result[swapIndex], result[index]
    end
    if #result > 1 then
        local unchanged = true
        for index, instId in ipairs(result) do
            if instId ~= source[index] then
                unchanged = false
                break
            end
        end
        if unchanged then
            result[1], result[2] = result[2], result[1]
        end
    end
    return result
end


CardGameDoudizhuSystem._SortHandInstIds = HL.Method(HL.Table).Return(HL.Table) << function(self, source)
    table.sort(source, function(a, b)
        local cardA = self.m_roomData and self.m_roomData:GetDoudizhuCard(a) or nil
        local cardB = self.m_roomData and self.m_roomData:GetDoudizhuCard(b) or nil
        if cardA == nil or cardB == nil then
            return a > b
        end
        local suitA = cardA.suit:GetHashCode()
        local suitB = cardB.suit:GetHashCode()
        local rankA = cardA.rank:GetHashCode()
        local rankB = cardB.rank:GetHashCode()
        local valueA = suitA == 5 and 100 + rankA or rankA
        local valueB = suitB == 5 and 100 + rankB or rankB
        if valueA == valueB then
            return suitA > suitB
        end
        return valueA > valueB
    end)
    return source
end


CardGameDoudizhuSystem._SortPlayedInstIds = HL.Method(HL.Table, HL.Any).Return(HL.Table)
        << function(self, source, pattern)
    local cards = {}
    for index, instId in ipairs(source) do
        local card = self:_BuildHintCardData(instId)
        if card == nil then
            return self:_SortHandInstIds(source)
        end
        cards[index] = card
    end
    local patternId = pattern ~= nil and pattern:GetHashCode() or HintSolver.Pattern.None
    local sorted = HintSolver.SortPlayedInstIds(cards, patternId)
    if #sorted ~= #source then
        return self:_SortHandInstIds(source)
    end
    return sorted
end


CardGameDoudizhuSystem._BuildHintCardData = HL.Method(HL.Number).Return(HL.Opt(HL.Table))
        << function(self, instId)
    local cardData = self.m_roomData and self.m_roomData:GetDoudizhuCard(instId) or nil
    if cardData == nil or not cardData.isValid then
        return nil
    end
    return {
        instId = instId,
        rank = cardData.rank:GetHashCode(),
        suit = cardData.suit:GetHashCode(),
    }
end





CardGameDoudizhuSystem._OpenPhase = HL.Method() << function(self)
    self:_StartPhaseReadyWatchdog()
    PhaseManager:OpenPhase(PHASE_ID, {
        onPhaseReady = function()
            self:_OnPhaseReady()
        end,
        onPhaseActivated = function()
            self:_OnPhaseActivated()
        end,
        onPhaseDeactivated = function()
            self:_OnPhaseDeactivated()
        end,
    })
end

CardGameDoudizhuSystem._OnPhaseReady = HL.Method() << function(self)
    if not self.m_inGame then
        return
    end
    self:_ClearPhaseReadyWatchdog()
    
    local isHotSwitchReady = self.m_phaseReady and InputManagerInst.inChangingInputDevice
    self.m_headlessPresentation = false
    self.m_phaseReady = true
    self.m_phaseActive = true
    local runnerSnapshot = self.m_presentationRunner:GetSnapshot()
    logger.info(string.format("[斗地主][场景] 牌桌场景准备完成：客户端阶段=%s，服务端阶段=%s，待播放表现=%d，发牌表现待完成=%s",
            tostring(self:GetFlowState()),tostring(self.m_roomData and self.m_roomData.phase or nil),runnerSnapshot.queuedCount, tostring(self.m_presentationRunner:HasPendingDeal())))
    if self:IsInState(FLOW_STATE.Dealing) and not self.m_presentationRunner:HasPendingDeal()
            and runnerSnapshot.queuedCount == 0
            and runnerSnapshot.playingItem == nil then
        logger.info("[斗地主][发牌] 当前处于发牌阶段且没有待播发牌；按 FullSync 恢复语义直接重建权威终态")
    elseif self:_ShouldHoldUndealtVisual() then
        logger.info("[斗地主][发牌] 首局/重新发牌表现尚未完成，暂时隐藏 FullSync 中已落地的最终手牌")
    end
    self:_RefreshOperationDeadline()
    local ok, didRebuild = self:_TryRebuildCardVisual("牌桌场景准备完成后重建牌桌失败")
    if not ok then
        return
    end
    if not didRebuild then
        self:_RefreshHudByState("PhaseReady")
    end
    if not isHotSwitchReady then
        AudioManager.PostEvent("au_music_gambling_v1d7_doudizhu_normal")
    end
    self.m_presentationRunner:TryPlayNext()
    LuaSystemManager.cardGameSystem:StartGame()
end

CardGameDoudizhuSystem._OnPhaseActivated = HL.Method() << function(self)
    if self.m_roomData == nil or not self.m_phaseReady then
        return
    end
    self.m_headlessPresentation = false
    self.m_phaseActive = true
    self:_RefreshOperationDeadline()
    
    
    
    
    
    
        self:_RefreshHudByState("PhaseActivated")
    
    self.m_presentationRunner:TryPlayNext()
end

CardGameDoudizhuSystem._OnPhaseDeactivated = HL.Method() << function(self)
    if self.m_roomData == nil or not self.m_phaseReady then
        return
    end
    self.m_phaseActive = false
    
    self:_RefreshOperationDeadline()
    
    
    
    
end

CardGameDoudizhuSystem._ClosePhase = HL.Method() << function(self)
    self:_ClearPhaseReadyWatchdog()
    if PhaseManager:IsOpenAndValid(PHASE_ID) then
        PhaseManager:ExitPhaseFast(PHASE_ID)
    end
    self.m_phaseReady = false
    self.m_phaseActive = false
    self.m_headlessPresentation = false
end

CardGameDoudizhuSystem._StartPhaseReadyWatchdog = HL.Method() << function(self)
    self:_ClearPhaseReadyWatchdog()
    self.m_phaseReadyWatchdogTimer = self:_StartTimer(PHASE_READY_WATCHDOG_SECONDS, function()
        self.m_phaseReadyWatchdogTimer = -1
        if not self.m_inGame or self.m_phaseReady then
            return
        end
        logger.error("Doudizhu Phase ready watchdog: fallback to headless semantic drain")
        self.m_headlessPresentation = true
        self:_ClearOperationDeadline()
        self.m_presentationRunner:MarkQueuedFastForward()
        self.m_presentationRunner:TryPlayNext()
    end, true)
end

CardGameDoudizhuSystem._ClearPhaseReadyWatchdog = HL.Method() << function(self)
    if self.m_phaseReadyWatchdogTimer ~= nil and self.m_phaseReadyWatchdogTimer > 0 then
        self.m_phaseReadyWatchdogTimer = self:_ClearTimer(self.m_phaseReadyWatchdogTimer)
    end
    self.m_phaseReadyWatchdogTimer = -1
end

CardGameDoudizhuSystem._BuildSeatData = HL.Method().Return(HL.Boolean) << function(self)
    self:_ClearSeatData()
    local serverSeatToMember = {}
    local selfServerSeatId = 0
    for memberId, memberData in cs_pairs(self.m_roomData.members) do
        local serverSeatId = memberData.seatId
        serverSeatToMember[serverSeatId] = memberId
        if memberData.isSelf and serverSeatId >= 1 and serverSeatId <= MAX_SEAT_COUNT then
            selfServerSeatId = serverSeatId
        end
    end
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    local mappedSeatCount = 0
    for hudSeat = 1, MAX_SEAT_COUNT do
        local serverSeatOffset = HUD_SEAT_TO_SERVER_OFFSET[hudSeat]
        local serverSeatId = (selfServerSeatId - 1 + serverSeatOffset) % MAX_SEAT_COUNT + 1
        local memberId = serverSeatToMember[serverSeatId]
        if memberId ~= nil then
            local briefMember = playRoomSystem:GetBriefMemberByMemberId(memberId)
            self.m_seatMembers[hudSeat] = {
                memberId = memberId,
                serverSeatId = serverSeatId,
                briefData = briefMember and briefMember.briefData or nil,
            }
            self.m_actualSeatToHudSeat[serverSeatId] = hudSeat
            self.m_memberIdToHudSeat[memberId] = hudSeat
            mappedSeatCount = mappedSeatCount + 1
            logger.info(string.format("[斗地主][座位] memberId=%s serverSeatId=%d -> hudSeat=%d",
                    tostring(memberId), serverSeatId, hudSeat))
        end
    end
    if mappedSeatCount ~= MAX_SEAT_COUNT then
        logger.error(string.format(
                "CardGameDoudizhuSystem._BuildSeatData: incomplete seat mapping, expected=%d actual=%d",
                MAX_SEAT_COUNT, mappedSeatCount))
        self:_ClearSeatData()
        return false
    end
    return true
end

CardGameDoudizhuSystem._ClearSeatData = HL.Method() << function(self)
    self.m_seatMembers = {}
    self.m_actualSeatToHudSeat = {}
    self.m_memberIdToHudSeat = {}
end

CardGameDoudizhuSystem._BuildSeatChars = HL.Method().Return(HL.Table) << function(self)
    local result = {}
    for hudSeat = 1, MAX_SEAT_COUNT do
        local seat = self.m_seatMembers[hudSeat]
        local briefData = seat and seat.briefData
        result[hudSeat] = {
            charId = MultiplayerUtils.getMemberDisplayCharTemplateId(briefData) or "",
            showPotentialFx = briefData ~= nil and briefData.hasFullPotentialFx,
        }
    end
    return result
end

CardGameDoudizhuSystem._GetMemberDisplayName = HL.Method(HL.Any).Return(HL.String) << function(self, memberId)
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    local seat = hudSeat and self.m_seatMembers[hudSeat]
    local briefData = seat and seat.briefData
    if briefData ~= nil and not string.isEmpty(briefData.npcTplId) then
        return Tables.multiplayerNpcPoolInfoTable:GetValue(briefData.npcTplId).nickname
    end
    if briefData ~= nil and briefData.roleId ~= 0 then
        local found, playerInfo = GameInstance.player.friendSystem:TryGetFriendInfo(briefData.roleId)
        if found and playerInfo ~= nil and not string.isEmpty(playerInfo.name) then
            return playerInfo.name
        end
    end
    return string.format("玩家%d", seat and seat.serverSeatId or 0)
end


CardGameDoudizhuSystem.GetHudSeatByMemberId = HL.Method(HL.Any).Return(HL.Opt(HL.Number)) << function(self, memberId)
    return self.m_memberIdToHudSeat[memberId]
end

CardGameDoudizhuSystem._GetAuthorityMemberByHudSeat = HL.Method(HL.Number).Return(HL.Opt(HL.Any))
        << function(self, hudSeat)
    local seat = self.m_seatMembers[hudSeat]
    if seat == nil or self.m_roomData == nil then
        return nil
    end
    return self.m_roomData:GetDoudizhuMember(seat.memberId)
end




CardGameDoudizhuSystem._BuildMemberDisplayInfo = HL.Method(HL.Any).Return(HL.Table) << function(self, memberId)
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    local seat = hudSeat and self.m_seatMembers[hudSeat] or nil
    local info = {
        isAI = not string.isEmpty(seat.briefData.npcTplId),
        roleId = 0,
        nickname = "",
        signature = "",
        avatarIcon = "",
        avatarFrameIcon = "",
        cardTopicId = "",
        adventureLevel = 0,
        psName = "",
    }
    local avatarId 
    local avatarFrameId 
    if info.isAI then
        local found, npcCfg = Tables.multiplayerNpcPoolInfoTable:TryGetValue(seat.briefData.npcTplId)
        if not found then
            logger.error("CardGameDoudizhuSystem._BuildMemberDisplayInfo: NPC 池里没这个模板, npcTplId=" .. seat.briefData.npcTplId)
            return info
        end
        info.nickname = npcCfg.nickname
        info.signature = npcCfg.signature
        info.cardTopicId = npcCfg.cardTopicId
        avatarId = npcCfg.avatarId
        avatarFrameId = npcCfg.avatarFrameId
    else
        local found, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(seat.briefData.roleId)
        if not found then
            logger.error("CardGameDoudizhuSystem._BuildMemberDisplayInfo: 取不到玩家信息, roleId=" .. tostring(seat.briefData.roleId))
            return info
        end
        info.roleId = seat.briefData.roleId
        info.friendInfo = friendInfo
        info.nickname = friendInfo.name
        info.signature = friendInfo.signature
        info.cardTopicId = friendInfo.businessCardTopicId or ""
        info.adventureLevel = friendInfo.adventureLevel
        info.psName = friendInfo.psName
        avatarId = friendInfo.userAvatarId
        avatarFrameId = friendInfo.userAvatarFrameId
    end
    if not string.isEmpty(avatarId) then
        info.avatarIcon = Tables.userAvatarTable:GetValue(avatarId).icon
    end
    if not string.isEmpty(avatarFrameId) then
        info.avatarFrameIcon = Tables.userAvatarTableFrame:GetValue(avatarFrameId).icon
    end
    return info
end


CardGameDoudizhuSystem._BuildPlayerSnapshot = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Table) << function(self, hudSeat, overrideRoleId)
    local seat = self.m_seatMembers[hudSeat]
    local displayInfo = self:_BuildMemberDisplayInfo(seat.memberId)
    local roleId = overrideRoleId ~= nil and overrideRoleId ~= 0 and overrideRoleId
            or displayInfo.roleId or 0
    return {
        memberId = seat.memberId,
        seatIndex = seat.serverSeatId,
        roleId = roleId,
        isSelf = hudSeat == HUD_SEAT.Self,
        isAI = displayInfo.isAI,
        charId = MultiplayerUtils.getMemberDisplayCharTemplateId(seat.briefData),
        displayInfo = displayInfo,
    }
end


CardGameDoudizhuSystem.QueryPlayerSocialFlags = HL.Method(HL.Table).Return(HL.Table) << function(self, player)
    return CardGameUtils.QueryPlayerSocialFlags(player)
end

CardGameDoudizhuSystem._BuildPlayerGameInfoArg = HL.Method(HL.Number).Return(HL.Table) << function(self, hudSeat)
    local room = self.m_roomData
    local seat = self.m_seatMembers[hudSeat]
    local member = self:_GetAuthorityMemberByHudSeat(hudSeat)
    local camp = CS.Proto.DDZ_CAMP.None
    if room.landlordMemberId ~= 0 then
        camp = seat.memberId == room.landlordMemberId
                and CS.Proto.DDZ_CAMP.Landlord or CS.Proto.DDZ_CAMP.Farmer
    end
    local bottomCards = {}
    if camp == CS.Proto.DDZ_CAMP.Landlord then
        local bottomInstIds = self:_CopyCSList(room.bottomInstIds)
        bottomCards = self:_BuildCardViewDataList(bottomInstIds)
    end

    return {
        hudSeat = hudSeat,
        player = self:_BuildPlayerSnapshot(hudSeat),
        camp = camp,
        handCardsCount = member.handCardsCount,
        bottomCards = bottomCards,
    }
end

CardGameDoudizhuSystem.OpenPlayerGameInfoByHudSeat = HL.Method(HL.Number) << function(self, hudSeat)
    if not self.m_inGame or not self.m_phaseReady or not self.m_phaseActive
            or self.m_presentationRunner:IsBusy() then
        return
    end
    PhaseManager:OpenPhase(PhaseId.CardGameLandlordPlayerGameInfo,
            self:_BuildPlayerGameInfoArg(hudSeat), function()
                
                self:_RefreshPlayerGameInfo()
            end)
end

CardGameDoudizhuSystem._ClosePlayerGameInfo = HL.Method() << function(self)
    if PhaseManager:IsOpenAndValid(PhaseId.CardGameLandlordPlayerGameInfo) then
        PhaseManager:ExitPhaseFast(PhaseId.CardGameLandlordPlayerGameInfo)
    end
end

CardGameDoudizhuSystem._GetPlayerGameInfoCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PanelId.CardGameLandlordPlayerGameInfo)
    return isOpen and ctrl or nil
end

CardGameDoudizhuSystem._RefreshPlayerGameInfo = HL.Method() << function(self)
    local ctrl = self:_GetPlayerGameInfoCtrl()
    if ctrl ~= nil then
        ctrl:RefreshPlayerGameInfo(self:_BuildPlayerGameInfoArg(ctrl:GetHudSeat()))
    end
end


CardGameDoudizhuSystem._BuildFinalSettleArg = HL.Method(HL.Any).Return(HL.Table) << function(self, settlement)
    local playerInfos = {}
    local selfInfo
    for index = 0, settlement.members.Count - 1 do
        local settleMember = settlement.members[index]
        local hudSeat = self.m_memberIdToHudSeat[settleMember.memberId]
        local player = self:_BuildPlayerSnapshot(hudSeat, settleMember.roleId)
        player.camp = settleMember.camp
        player.rank = settleMember.rank
        player.isWinner = settleMember.isWinner
        playerInfos[#playerInfos + 1] = player
        if player.isSelf then
            selfInfo = player
        end
    end
    
    local winnerCamp = settlement.winnerCamp
    table.sort(playerInfos, function(a, b)
        if a.camp ~= b.camp then
            return a.camp == winnerCamp
        end
        if a.isSelf ~= b.isSelf then
            return a.isSelf
        end
        return a.seatIndex < b.seatIndex
    end)
    return {
        winnerCamp = settlement.winnerCamp,
        selfInfo = selfInfo,
        playerInfos = playerInfos,
    }
end


CardGameDoudizhuSystem._CompleteFinalSettlePresentation = HL.Method(HL.Table) << function(self, arg)
    if UIManager:IsOpen(PanelId.CardGameLandlordFinalSettleRank) then
        return
    end
    UIManager:Open(PanelId.CardGameLandlordFinalSettleRank, arg)
end

CardGameDoudizhuSystem._CloseFinalSettleRank = HL.Method() << function(self)
    if UIManager:IsOpen(PanelId.CardGameLandlordFinalSettleRank) then
        UIManager:Close(PanelId.CardGameLandlordFinalSettleRank)
    end
end

CardGameDoudizhuSystem._InnerRequestLeavePlayRoom = HL.Method(HL.Number) << function(self, leaveRoomType)
    self.m_leaveRoomType = leaveRoomType
    if not self.m_inGame then
        
        self:_StopGame()
        return
    end
    self.m_isLeaveByPlayer = true
    GameInstance.player.multiplayerPlayRoomSystem:SendLeavePlayRoom()
end

CardGameDoudizhuSystem.ReturnFromFinalSettle = HL.Method(HL.Number) << function(self, returnTarget)
    self:_InnerRequestLeavePlayRoom(returnTarget)
end

CardGameDoudizhuSystem.RequestAddFriend = HL.Method(HL.Any, HL.String).Return(HL.Boolean) << function(self, roleId, sourcePanelId)
    return CardGameUtils.RequestAddFriend(roleId, sourcePanelId, PhaseManager:GetPhaseName(PHASE_ID))
end








CardGameDoudizhuSystem._PrepareHudCardHandoff = HL.Method(HL.Table) << function(self, request)
    local owner = self.m_hudOwner
    if owner == nil then
        return
    end
    local ok, err = xpcall(function()
        owner:PrepareCardHandoff(request)
    end, debug.traceback)
    if not ok then
        logger.error("Doudizhu HUD PrepareCardHandoff failed: " .. tostring(err))
    end
end


CardGameDoudizhuSystem._ResolveHudCardHandoffPose = HL.Method(HL.String, HL.Any,HL.Opt(HL.Number, HL.Number)).Return(HL.Opt(HL.Table))
        << function(self, zone, uid, index, visualUid)
    local runtimeUid = visualUid or uid
    local card = LuaSystemManager.cardGameSystem:GetRuntimeCard(runtimeUid)
    local owner = self.m_hudOwner
    local ok, alignedPose = xpcall(function()
        return owner:ResolveCardHandoffPose({
            zone = zone,
            uid = uid,
            index = index,
            visualUid = runtimeUid,
            cardTransform = card.transform,
        })
    end, debug.traceback)
    if not ok then
        logger.error("Doudizhu HUD ResolveCardHandoffPose failed: " .. tostring(alignedPose))
        return nil
    end
    if alignedPose == nil or IsNull(alignedPose.root) then
        return nil
    end
    
    return {
        root = alignedPose.root,
        localPosition = alignedPose.localPosition,
        localEulerAngles = alignedPose.localEulerAngles,
        localScale = alignedPose.localScale,
    }
end

CardGameDoudizhuSystem._SetHudCardHandoffVisible = HL.Method(HL.String, HL.Any, HL.Opt(HL.Number, HL.Boolean, HL.Boolean, HL.Table))
        .Return(HL.Boolean) << function(self, zone, uid, index, visible, faceUp, cardData)
    local owner = self.m_hudOwner
    if owner == nil then
        return false
    end
    local ok, handled = xpcall(function()
        return owner:SetCardHandoffVisible({
            zone = zone,
            uid = uid,
            index = index,
            visible = visible == true,
            faceUp = faceUp == true,
            cardData = cardData,
        })
    end, debug.traceback)
    if not ok then
        logger.error("Doudizhu HUD SetCardHandoffVisible failed: " .. tostring(handled))
        return false
    end
    return handled == true
end


CardGameDoudizhuSystem.AttachHud = HL.Method(HL.Any).Return(HL.Boolean) << function(self, owner)
    self.m_hudOwner = owner
    local emojiCdRemain = self:_GetEmojiCdRemain()
    self:_SetEmojiCdUI(emojiCdRemain > 0, emojiCdRemain)
    if self.m_phaseReady and self:_HasCardRegions() then
        local room = self.m_roomData
        local showBottomBack = not self:_ShouldHoldUndealtVisual() and room ~= nil and room.bottomInstIds.Count <= 0
                and room.landlordMemberId == 0
                and (room.phase == CS.Proto.DDZ_PHASE.Deal or room.phase == CS.Proto.DDZ_PHASE.Bid)
        self:_RefreshHudByState("HudAttached", {
            kind = HUD_COMMAND_KIND.Rebuild,
            showBottomBack = showBottomBack,
        })
    else
        self:_RefreshHudByState("HudAttached")
    end
    return true
end

CardGameDoudizhuSystem.DetachHud = HL.Method(HL.Opt(HL.Any)) << function(self, owner)
    if self.m_hudOwner == nil then
        return
    end
    if owner ~= nil and owner ~= self.m_hudOwner then
        return
    end

    
    self.m_hudOwner:PlaySeatIntro(false)
    
    self.m_hudOwner = nil
    
    if self.m_presentationRunner:IsBusy() then
        self.m_presentationRunner:FastForwardCurrent("HudDetached")
    end
    self:_RestoreSelfHand3DAfterHudDetach()
end



CardGameDoudizhuSystem._RefreshHudByState = HL.Method(HL.String, HL.Opt(HL.Any, HL.Table))
        << function(self, reason, context, viewModel)
    
    if context ~= nil and context.kind == HUD_COMMAND_KIND.Settlement then
        self.m_finalSettleArg = context.finalSettleArg
    end
    local owner = self.m_hudOwner
    if owner == nil then
        return
    end
    
    owner:RefreshHud(viewModel or self:_BuildHudViewModel(), context)
end


CardGameDoudizhuSystem._PlayHudProgressToast = HL.Method(HL.Table) << function(self, command)
    local owner = self.m_hudOwner
    if owner == nil then
        return
    end
    local ok, err = xpcall(function()
        owner:PlayProgressToast(command)
    end, debug.traceback)
    if not ok then
        logger.error("Doudizhu HUD PlayProgressToast failed: " .. tostring(err))
    end
end



CardGameDoudizhuSystem._PlayHudCommand = HL.Method(HL.Table, HL.Function).Return(HL.Opt(HL.Function)) << function(self, command, onDone)
    if self.m_hudOwner == nil then
        onDone()
        return nil
    end
    if command.kind ~= HUD_COMMAND_KIND.Settlement then
        return self.m_hudOwner:PlayHudCommand(command, onDone)
    end
    self:_SetSettlementToastForbidHotswap(true)
    local cancel = self.m_hudOwner:PlayHudCommand(command, function()
        self:_SetSettlementToastForbidHotswap(false)
        onDone()
    end)
    return function(applyFinal)
        self:_SetSettlementToastForbidHotswap(false)
        if cancel ~= nil then
            cancel(applyFinal)
        end
    end
end



CardGameDoudizhuSystem._BuildHudCommand = HL.Method(HL.Table, HL.String).Return(HL.Table)
        << function(self, item, flowStateBefore)
    local batch = item.batch
    local kind = HUD_COMMAND_KIND.TurnChanged
    if batch.type == PresentationType.Deal then
        kind = HUD_COMMAND_KIND.Deal
    elseif batch.type == PresentationType.BidResult then
        kind = HUD_COMMAND_KIND.BidResult
    elseif batch.type == PresentationType.Bottom then
        kind = HUD_COMMAND_KIND.BottomRevealed
    elseif batch.type == PresentationType.PlayAction then
        kind = HUD_COMMAND_KIND.PlayCards
    elseif batch.type == PresentationType.Pass then
        kind = HUD_COMMAND_KIND.Pass
    elseif batch.type == PresentationType.Settle then
        kind = HUD_COMMAND_KIND.Settlement
    end
    
    local bottomInstIds
    local bottomCards
    local finalSettleArg
    if kind == HUD_COMMAND_KIND.BottomRevealed then
        bottomInstIds = self:_CopyCSList(batch.bottomInstIds)
        bottomCards = self:_BuildCardViewDataList(bottomInstIds)
    elseif kind == HUD_COMMAND_KIND.Settlement then
        finalSettleArg = self.m_finalSettleArg or self:_BuildFinalSettleArg(batch.settlement)
    end
    
    if batch.type == PresentationType.Deal then
        self.m_bidStartHudSeat = 0
        
        self.m_dealtCardCounts = not item.fastForward and { 0, 0, 0 } or nil
    elseif batch.type == PresentationType.BidTurn and batch.startsNewRound then
        self.m_bidStartHudSeat = self.m_memberIdToHudSeat[batch.memberId] or 0
    end

    return {
        kind = kind,
        localEventId = item.localEventId,
        presentationType = batch.type,
        hudSeat = self.m_memberIdToHudSeat[batch.memberId] or 0,
        action = batch.action,
        bidRound = batch.bidRound,
        hasPriorPositiveBidInRound = batch.hasPriorPositiveBidInRound,
        startsNewRound = batch.startsNewRound,
        isFirstBidTurnAfterRedeal = batch.isFirstBidTurnAfterRedeal,
        startsPlaying = flowStateBefore == FLOW_STATE.Bidding and self:GetFlowState() == FLOW_STATE.Playing, 
        landlordHudSeat = self.m_memberIdToHudSeat[batch.landlordMemberId] or 0,
        pattern = batch.pattern,
        remainCount = batch.remainCount, 
        bottomInstIds = bottomInstIds,
        bottomCards = bottomCards,
        finalSettleArg = finalSettleArg,
        fastForward = item.fastForward == true,
        isRedeal = batch.isRedeal,
        viewModel = self:_BuildHudViewModel(),
    }
end

CardGameDoudizhuSystem._BuildHudViewModel = HL.Method().Return(HL.Table) << function(self)
    local room = self.m_roomData
    local flowState = self:GetFlowState()
    local holdUndealtVisual = self:_ShouldHoldUndealtVisual()
    
    local hideControllerHints = room == nil or flowState == FLOW_STATE.WaitingStart
    if room ~= nil then
        for _, presentation in cs_pairs(room.pendingPresentations) do
            if presentation.type == PresentationType.Deal and not presentation.isRedeal then
                hideControllerHints = true
                break
            end
        end
    end
    local bottomInstIds = room and self:_CopyCSList(room.bottomInstIds) or {}
    local settlement = room ~= nil and room.phase == CS.Proto.DDZ_PHASE.Settle
            and room.settlement ~= nil and room.settlement.members ~= nil
            and room.settlement.members.Count > 0 and room.settlement or nil
    local selfMember = self:_GetAuthorityMemberByHudSeat(HUD_SEAT.Self)
    local selfHandInstIds = {}
    if not holdUndealtVisual and selfMember ~= nil and selfMember.isSelf then
        selfHandInstIds = self:_SortHandInstIds(self:_CopyCSList(selfMember.handCardsInstIds))
    end
    
    local canBid = self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Bid, FLOW_STATE.Bidding, true)
    local canPlay = self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Play, FLOW_STATE.Playing, true)
    local canRequestPass = canPlay and room ~= nil and room.canPass
    local hasPlayableResponse = not (canPlay and canRequestPass)
            or self:HasPlayableResponse(selfHandInstIds)
    local model = {
        inGame = self.m_inGame,
        phaseReady = self.m_phaseReady,
        phaseActive = self.m_phaseActive,
        headlessPresentation = self.m_headlessPresentation,
        hideControllerHints = hideControllerHints,
        presentationBusy = self.m_presentationRunner ~= nil and self.m_presentationRunner:IsBusy(),
        flowState = flowState,
        turnHudSeat = self:GetTurnHudSeat(),
        landlordHudSeat = room
                and (self.m_memberIdToHudSeat[room.landlordMemberId] or 0) or 0,
        bidStartHudSeat = flowState == FLOW_STATE.Bidding and self.m_bidStartHudSeat or 0,

        deadlineMs = room and room.deadlineMs or 0,
        windowSeqId = room and room.currentTurnSeqId or 0, 
        canBid = canBid,
        canPlay = canPlay,
        canRequestPass = canRequestPass,
        hasPlayableResponse = hasPlayableResponse,
        operationPending = self:IsOperationPending(),
        isRecovering = flowState == FLOW_STATE.Recovering,
        hasClientFlowError = self.m_clientFlowBlocked,
        bottomInstIds = bottomInstIds,
        bottomCards = self:_BuildCardViewDataList(bottomInstIds),
        settlementWinnerCamp = settlement and settlement.winnerCamp or nil,
        seats = {},
    }
    
    for hudSeat = 1, MAX_SEAT_COUNT do
        local seat = self.m_seatMembers[hudSeat]
        if seat ~= nil then
            local member = hudSeat == HUD_SEAT.Self and selfMember
                    or self:_GetAuthorityMemberByHudSeat(hudSeat)
            local handCardsCount = member and member.handCardsCount or 0
            if holdUndealtVisual and self.m_dealtCardCounts ~= nil then
                handCardsCount = self.m_dealtCardCounts[hudSeat] or 0
            end
            local seatModel = {
                serverSeatId = seat.serverSeatId,
                isLandlord = room ~= nil and seat.memberId == room.landlordMemberId,
                handCardsCount = handCardsCount,
                displayInfo = self:_BuildMemberDisplayInfo(seat.memberId),
                nickname = self:_GetMemberDisplayName(seat.memberId),
            }
            if hudSeat ~= HUD_SEAT.Self then
                seatModel.memberId = seat.memberId
            elseif member ~= nil and member.isSelf then
                seatModel.handCardsInstIds = selfHandInstIds
            end
            model.seats[hudSeat] = seatModel
        end
    end
    return model
end




CardGameDoudizhuSystem._SyncSelfHandRegionLayout = HL.Method() << function(self)
    if self.scene == nil or not self:_HasCardRegions() then
        return
    end
    if self.scene:SyncSelfHandRegionLayout() and self.m_hudOwner ~= nil then
        self.m_hudOwner:OnSelfHandRegionRebound()
    end
end


CardGameDoudizhuSystem._RestoreSelfHand3DAfterHudDetach = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil or not self:_HasCardRegions() then
        return
    end

    local handRegionId = CARD_REGION_PLAYER_HAND_IDS[HUD_SEAT.Self]
    local handRegion = cardSystem:GetRegion(handRegionId)
    if handRegion ~= nil then
        cardSystem:RelayoutRegion(handRegionId, false)
        for index = 1, handRegion:GetCardCount() do
            local card = handRegion:GetCardAtIndex(index)
            if card ~= nil then
                cardSystem:SetRuntimeCardVisible(card.uid, true)
            end
        end
    end
end

CardGameDoudizhuSystem._BuildCardViewData = HL.Method(HL.Any).Return(HL.Opt(HL.Table)) << function(self, instId)
    local cardData = self.m_roomData and self.m_roomData:GetDoudizhuCard(instId) or nil
    if cardData == nil or not cardData.isValid then
        return nil
    end
    local pokerSuit = cardData.pokerSuit:GetHashCode()
    local pokerRank = cardData.pokerRank:GetHashCode()
    return {
        instId = instId,
        suit = pokerSuit,
        rank = pokerRank,
        pokerSuit = pokerSuit,
        pokerRank = pokerRank,
        style = "None",
    }
end


CardGameDoudizhuSystem._BuildCardViewDataList = HL.Method(HL.Table).Return(HL.Table)
        << function(self, instIds)
    local result = {}
    for index, instId in ipairs(instIds) do
        local cardData = self:_BuildCardViewData(instId)
        result[index] = cardData
    end
    return result
end





CardGameDoudizhuSystem.GetEmojiRoomStrId = HL.Method().Return(HL.String) << function(self)
    local playRoomSystem = GameInstance.player.multiplayerPlayRoomSystem
    return playRoomSystem and playRoomSystem.roomStrId or ""
end

CardGameDoudizhuSystem.IsEmojiInCd = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_sendEmojiCdEndTime > Time.unscaledTime
end

CardGameDoudizhuSystem.StartEmojiCd = HL.Method() << function(self)
    self.m_sendEmojiCdEndTime = Time.unscaledTime + MultiplayerConst.EMOJI_CD_TIME
    self:_TickEmojiCd()
end

CardGameDoudizhuSystem._GetEmojiCdRemain = HL.Method().Return(HL.Number) << function(self)
    if self.m_sendEmojiCdEndTime <= 0 then
        return 0
    end
    return math.max(self.m_sendEmojiCdEndTime - Time.unscaledTime, 0)
end

CardGameDoudizhuSystem._TickEmojiCd = HL.Method() << function(self)
    local remain = self:_GetEmojiCdRemain()
    self:_SetEmojiCdUI(remain > 0, remain)
    if self.m_sendEmojiCdTimer > 0 then
        self.m_sendEmojiCdTimer = self:_ClearTimer(self.m_sendEmojiCdTimer)
    end
    if remain > 0 then
        self.m_sendEmojiCdTimer = self:_StartTimer(math.min(EMOJI_CD_TICK, remain), function()
            self:_TickEmojiCd()
        end, true)
    else
        self.m_sendEmojiCdEndTime = 0
        self.m_sendEmojiCdTimer = -1
    end
end

CardGameDoudizhuSystem._SetEmojiCdUI = HL.Method(HL.Boolean, HL.Number) << function(self, inCd, cdTime)
    if self.m_hudOwner == nil then
        return
    end
    self.m_hudOwner:SetEmojiCdState(inCd)
    self.m_hudOwner:RefreshEmojiCd(cdTime)
end

CardGameDoudizhuSystem._OnRoomEmojiNotify = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    if not self.m_inGame then
        return
    end
    local roomStrId, senderRoleId, emojiId = unpack(arg or {})
    if roomStrId ~= self:GetEmojiRoomStrId()
            or senderRoleId == nil or string.isEmpty(emojiId) then
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

CardGameDoudizhuSystem._PlayEmojiByMemberId = HL.Method(HL.Any, HL.String, HL.Opt(HL.String))
        << function(self, memberId, emojiId, charId)
    local hudSeat = self.m_memberIdToHudSeat[memberId]
    if hudSeat == nil or self.m_hudOwner == nil then
        return
    end
    self.m_hudOwner:PlayEmojiBySeatIndex(hudSeat, emojiId, charId)
end



CardGameDoudizhuSystem.SetPauseByGuide = HL.Method(HL.Any) << function(self, arg)
    local isPause = unpack(arg)
    if not self.m_inGame or not GameInstance.player.multiplayerPlayRoomSystem.inRoom then
        return
    end
    
    if isPause and not self:_IsNewbieGuideRoom() then
        logger.error("CardGameDoudizhuSystem 非新手引导房不响应引导暂停")
        return
    end
    if isPause then
        self:StartPauseByGuide()
    else
        self:CancelPauseByGuide()
    end
end

CardGameDoudizhuSystem.StartPauseByGuide = HL.Method() << function(self)
    if self.isPauseByGuide then
        return
    end
    self.isPauseByGuide = true
    
    self.m_countDownPauseStartMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
    self:_ClearOperationDeadline()
end

CardGameDoudizhuSystem.CancelPauseByGuide = HL.Method() << function(self)
    if not self.isPauseByGuide then
        return
    end
    self.isPauseByGuide = false
    
    self.m_countDownPausedAccumMs = self.m_countDownPausedAccumMs
            + DateTimeUtils.GetCurrentTimestampByMilliseconds() - self.m_countDownPauseStartMs
    self.m_countDownPauseStartMs = -1
    self:_RefreshOperationDeadline()
    self:_RefreshHudByState("GuidePauseCanceled")
    self.m_presentationRunner:TryPlayNext()
end



CardGameDoudizhuSystem.GetCountDownNowMs = HL.Method().Return(HL.Number) << function(self)
    local now = self.m_countDownPauseStartMs >= 0 and self.m_countDownPauseStartMs
            or DateTimeUtils.GetCurrentTimestampByMilliseconds()
    return now - self.m_countDownPausedAccumMs
end



CardGameDoudizhuSystem._SyncCountDownDeadline = HL.Method() << function(self)
    local deadlineMs = self.m_roomData and self.m_roomData.deadlineMs or 0
    if deadlineMs == self.m_countDownDeadlineMs then
        return
    end
    self.m_countDownDeadlineMs = deadlineMs
    self.m_countDownPausedAccumMs = 0
    if self.m_countDownPauseStartMs >= 0 then
        self.m_countDownPauseStartMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
    end
end

CardGameDoudizhuSystem._IsNewbieGuideRoom = HL.Method().Return(HL.Boolean) << function(self)
    local enterPlayRoomInfo = GameInstance.player.multiplayerMatchSystem.enterPlayRoom
    return enterPlayRoomInfo ~= nil and enterPlayRoomInfo.playRoomKind
            == CS.Beyond.Gameplay.MultiplayerMatchSystem.PlayRoomKind.NewbieGuide
end



CardGameDoudizhuSystem.TriggerPhaseEventForGuide = HL.Method(HL.Any) << function(self, batch)
    local condition = CS.Beyond.Gameplay.Conditions.OnCardGameDoudizhuPhaseEventForGuide
    local eventTypes = condition.DoudizhuPhaseEventTypeForGuide
    local presentationType = batch.type
    local round, hudSeat, eventType
    if presentationType == PresentationType.Deal then
        round, hudSeat, eventType = 0, -1, eventTypes.DealEnd
    elseif presentationType == PresentationType.Bottom then
        
        round = self.m_roomData and self.m_roomData.bidRound or 0
        hudSeat = self.m_memberIdToHudSeat[batch.landlordMemberId] or -1
        eventType = eventTypes.LandlordRevealed
    elseif presentationType == PresentationType.BidTurn then
        round, eventType = batch.bidRound, eventTypes.BidTurnStart
        hudSeat = self.m_memberIdToHudSeat[batch.memberId] or -1
    elseif presentationType == PresentationType.PlayTurn then
        round, eventType = batch.playRound, eventTypes.PlayTurnStart
        hudSeat = self.m_memberIdToHudSeat[batch.memberId] or -1
    elseif presentationType == PresentationType.PlayAction or presentationType == PresentationType.Pass then
        round, eventType = batch.playRound, eventTypes.PlayActionEnd
        hudSeat = self.m_memberIdToHudSeat[batch.memberId] or -1
    else
        return
    end
    condition.Trigger(round, hudSeat, eventType)
end


CardGameDoudizhuSystem._SetGuideHandRange = HL.Method(HL.Any) << function(self, arg)
    local fromIndex, toIndex, isShow = unpack(arg)
    if self.m_hudOwner == nil then
        logger.error("[斗地主][引导] HUD 未挂载，无法设置手牌高亮区间")
        return
    end
    self.m_hudOwner:SetGuideHandRange(fromIndex, toIndex, isShow == true)
end



CardGameDoudizhuSystem._SetHandCardsSelectedByGuide = HL.Method(HL.Any) << function(self, arg)
    local rawIndices, isSelect = unpack(arg)
    if self.m_hudOwner == nil then
        logger.error("[斗地主][引导] HUD 未挂载，无法引导选牌")
        return
    end
    local indices = {}
    if type(rawIndices) == "table" then
        indices = rawIndices
    elseif rawIndices ~= nil then
        for i = 0, rawIndices.Count - 1 do
            indices[#indices + 1] = rawIndices[i]
        end
    end
    self.m_hudOwner:SetSelfHandCardsSelectedByGuide(indices, isSelect)
end




CardGameDoudizhuSystem.GetFlowState = HL.Method().Return(HL.String) << function(self)
    if self.m_stateGraph == nil then
        return FLOW_STATE.Inactive
    end
    return self.m_stateGraph:GetState()
end

CardGameDoudizhuSystem.IsInState = HL.Method(HL.String).Return(HL.Boolean) << function(self, stateId)
    return self.m_stateGraph ~= nil and self.m_stateGraph:IsIn(stateId)
end


CardGameDoudizhuSystem.GetTurnHudSeat = HL.Method().Return(HL.Number) << function(self)
    return self.m_roomData ~= nil
            and (self.m_memberIdToHudSeat[self.m_roomData.turnMemberId] or 0) or 0
end


CardGameDoudizhuSystem.GetSelfHandCards = HL.Method().Return(HL.Table) << function(self)
    local member = self.m_roomData and self.m_roomData:GetDoudizhuSelfMember() or nil
    if member == nil then
        return {}
    end
    return self:_SortHandInstIds(self:_CopyCSList(member.handCardsInstIds))
end


CardGameDoudizhuSystem.GetDisplaySelfHandCards = HL.Method().Return(HL.Table) << function(self)
    if self:_ShouldHoldUndealtVisual() then
        return {}
    end
    local member = self.m_roomData and self.m_roomData:GetDoudizhuSelfMember() or nil
    if member == nil then
        return {}
    end
    return self:_SortHandInstIds(self:_CopyCSList(member.handCardsInstIds))
end



CardGameDoudizhuSystem.GetPlayHintCandidates = HL.Method().Return(HL.Table) << function(self)
    if not self:CanPlay() or self.m_roomData == nil then
        return {}
    end

    local handCards = {}
    for _, instId in ipairs(self:GetDisplaySelfHandCards()) do
        local card = self:_BuildHintCardData(instId)
        if card == nil then
            logger.error(string.format("[斗地主][提示] 手牌牌面无效，无法生成提示：instId=%s", tostring(instId)))
            return {}
        end
        handCards[#handCards + 1] = card
    end

    local targetAction = nil
    if self.m_roomData.canPass then
        targetAction = self:_BuildFollowTargetAction()
        if targetAction == nil then
            return {}
        end
    end

    return HintSolver.BuildCandidates(handCards, targetAction)
end


CardGameDoudizhuSystem._BuildFollowTargetAction = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local lastAction = self.m_roomData.lastAction
    if lastAction == nil or lastAction.memberId == 0 or lastAction.cardInstIds.Count <= 0 then
        logger.error("[斗地主][提示] 当前是跟牌窗口，但服务端权威数据中没有上一手有效出牌")
        return nil
    end
    local patternId = lastAction.pattern:GetHashCode()
    if patternId == HintSolver.Pattern.None then
        logger.error("[斗地主][提示] 上一手缺少服务端认定牌型，无法安全生成跟牌提示")
        return nil
    end
    local targetCards = {}
    for _, instId in ipairs(self:_CopyCSList(lastAction.cardInstIds)) do
        local card = self:_BuildHintCardData(instId)
        if card == nil then
            logger.error(string.format("[斗地主][提示] 上一手牌面无效：instId=%s", tostring(instId)))
            return nil
        end
        targetCards[#targetCards + 1] = card
    end
    return {
        patternId = patternId,
        cards = targetCards,
    }
end


CardGameDoudizhuSystem.GetPlaySelectionResult = HL.Method(HL.Opt(HL.Table)).Return(HL.String)
        << function(self, instIds)
    if not self:CanPlay() or instIds == nil or #instIds <= 0 then
        return HintSolver.SelectionResult.Empty
    end

    local selectedCards = {}
    for _, instId in ipairs(instIds) do
        local card = self:_BuildHintCardData(instId)
        if card == nil then
            return HintSolver.SelectionResult.InvalidPattern
        end
        selectedCards[#selectedCards + 1] = card
    end

    local targetAction = nil
    if self.m_roomData.canPass then
        targetAction = self:_BuildFollowTargetAction()
        if targetAction == nil then
            return HintSolver.SelectionResult.CannotBeat
        end
    end
    local result = HintSolver.EvaluateSelection(selectedCards, targetAction)
    return result
end



CardGameDoudizhuSystem.HasPlayableResponse = HL.Method(HL.Opt(HL.Table)).Return(HL.Boolean)
        << function(self, handInstIds)
    
    if not self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Play, FLOW_STATE.Playing, true)
            or self.m_roomData == nil or not self.m_roomData.canPass then
        return true
    end

    local targetAction = self:_BuildFollowTargetAction()
    if targetAction == nil then
        return true
    end
    local handCards = {}
    for _, instId in ipairs(handInstIds or self:GetDisplaySelfHandCards()) do
        local card = self:_BuildHintCardData(instId)
        if card == nil then
            return true
        end
        handCards[#handCards + 1] = card
    end
    if #HintSolver.BuildCandidates(handCards, targetAction) > 0 then
        return true
    end
    return HintSolver.HasPotentialResponse(handCards, targetAction)
end


CardGameDoudizhuSystem.GetNextPlayHint = HL.Method(HL.Opt(HL.Table)).Return(HL.Opt(HL.Table))
        << function(self, currentInstIds)
    local candidates = self:GetPlayHintCandidates()
    local candidate, index = HintSolver.FindNextCandidate(candidates, currentInstIds or {})
    if candidate == nil then
        return nil
    end
    return {
        instIds = self:_CopyLuaArray(candidate.instIds),
        patternId = candidate.patternId,
        mainRank = candidate.mainRank,
        index = index,
        count = #candidates,
    }
end





CardGameDoudizhuSystem.RefreshSelfHandLayout = HL.Method(HL.Table, HL.Table, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, handInstIds, selectedSet, useAnim)
    local cardSystem = LuaSystemManager.cardGameSystem
    local handRegionId = CARD_REGION_PLAYER_HAND_IDS[HUD_SEAT.Self]
    local handRegion = cardSystem:GetRegion(handRegionId)
    if handRegion == nil then
        return false
    end

    local selectedIndices = Int32List()
    for index, instId in ipairs(handInstIds) do
        if selectedSet[instId] then
            selectedIndices:Add(index)
        end
    end
    local layout = handRegion:GetLayout()
    layout.layoutData:SetSelectedIndices(selectedIndices)
    local changedSet = {}
    local changedIndices = layout:UpdatePoses(#handInstIds, 1)
    for i = 0, changedIndices.Count - 1 do
        changedSet[changedIndices[i]] = true
    end
    
    
    for index, instId in ipairs(handInstIds) do
        local card = cardSystem:GetRuntimeCard(instId)
        
        if card and card.regionId == handRegionId and (changedSet[index] or card.indexInRegion ~= index) then
            local pose = handRegion:GetPose(index)
            if pose then
                if useAnim == true then
                    card:PlayMoveToPose(pose, nil, false)
                else
                    card:ApplyPose(pose)
                end
            end
        end
    end
    return true
end

CardGameDoudizhuSystem.IsOperationPending = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_roomData ~= nil and self.m_roomData.hasPendingOperation
end

CardGameDoudizhuSystem.CanBid = HL.Method().Return(HL.Boolean) << function(self)
    return self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Bid, FLOW_STATE.Bidding)
end

CardGameDoudizhuSystem.CanPlay = HL.Method().Return(HL.Boolean) << function(self)
    return self:_CanOperateWindow(CS.Proto.DDZ_PHASE.Play, FLOW_STATE.Playing)
end

CardGameDoudizhuSystem.CanPass = HL.Method().Return(HL.Boolean) << function(self)
    local room = self.m_roomData
    return self:CanPlay() and room ~= nil and room.canPass
end



CardGameDoudizhuSystem.NotifyActionDeadlineExpired = HL.Method(HL.Any).Return(HL.Boolean) << function(self, windowSeqId)
    local room = self.m_roomData
    if room == nil or room.currentTurnSeqId ~= windowSeqId or not self:_IsOperationWindowExpired() then
        return false
    end
    self:_ClearOperationDeadline()
    
    self:_RefreshHudByState("DeadlineExpired")
    return true
end

CardGameDoudizhuSystem.RequestBid = HL.Method(HL.Boolean).Return(HL.Boolean) << function(self, bid)
    if not self:CanBid() then
        return false
    end
    local room = self.m_roomData
    return self:_SendBidOperation(bid, room.currentTurnSeqId)
end

CardGameDoudizhuSystem.RequestLeaveRoom = HL.Method().Return(HL.Boolean) << function(self)
    self:_InnerRequestLeavePlayRoom(MultiplayerConst.EPlayRoomReturn.Main)
    return true
end

CardGameDoudizhuSystem.RequestPlay = HL.Method(HL.Table, HL.Opt(CS.Proto.DDZ_PATTERN)).Return(HL.Boolean) << function(self, instIds, pattern)
    if not self:CanPlay() or instIds == nil or #instIds <= 0 or #instIds > 20 then
        return false
    end

    local selfMember = self.m_roomData:GetDoudizhuSelfMember()
    if selfMember == nil then
        return false
    end
    local owned = {}
    for index = 0, selfMember.handCardsInstIds.Count - 1 do
        owned[selfMember.handCardsInstIds[index]] = true
    end

    local selected = {}
    local csInstIds = UInt32List()
    for _, instId in ipairs(instIds) do
        if selected[instId] or not owned[instId] then
            return false
        end
        selected[instId] = true
        csInstIds:Add(instId)
    end

    local room = self.m_roomData
    return self:_SendPlayOperation(csInstIds, pattern or CS.Proto.DDZ_PATTERN.None,
            room.currentTurnSeqId)
end

CardGameDoudizhuSystem.RequestPass = HL.Method().Return(HL.Boolean) << function(self)
    if not self:CanPass() then
        return false
    end
    local room = self.m_roomData
    return self:_SendPassOperation(room.currentTurnSeqId)
end



HL.Commit(CardGameDoudizhuSystem)
return CardGameDoudizhuSystem
