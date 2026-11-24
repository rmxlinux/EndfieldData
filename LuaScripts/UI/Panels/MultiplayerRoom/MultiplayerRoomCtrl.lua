local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerRoom
local PHASE_ID = PhaseId.MultiplayerRoom
local BLOCK_OBTAIN_WAYS_JUMP_KEY = "MultiplayerRoomCtrl"

local CLICK_ACTION_BY_STATE = {
    [MultiplayerConst.EClickState.Start] = "multiplayer_room_start_game",
    [MultiplayerConst.EClickState.StartMatch] = "multiplayer_room_start_match",
    [MultiplayerConst.EClickState.WaitReady] = "multiplayer_room_start_match",
    [MultiplayerConst.EClickState.Ready] = "multiplayer_room_ready",
}
local CANCEL_ACTION_BY_STATE = {
    [MultiplayerConst.EClickState.GetReady] = "multiplayer_room_cancel_ready",
    [MultiplayerConst.EClickState.Matching] = "multiplayer_room_cancel_match",
}

local REMIND_SHOW_SECONDS = 3
local NOTICE_PANEL_ID = PanelId.MultiplayerRoomNotice

local LEAVE_REASON_KICK = CS.Proto.MULTIPLAYER_MATCH_ROOM_LEAVE_REASON.Kick
local LEAVE_REASON_ROOM_CLOSED = CS.Proto.MULTIPLAYER_MATCH_ROOM_LEAVE_REASON.RoomClosed

local function getNowSec()
    return DateTimeUtils.GetCurrentTimestampBySeconds()
end


MultiplayerRoomCtrl = HL.Class('MultiplayerRoomCtrl', uiCtrl.UICtrl)


MultiplayerRoomCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_CREATE_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_JOIN_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_READY_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_UNREADY_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_START_MATCH_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_STOP_MATCH_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_START_PLAY_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_KICK_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_RECONNECT_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_BIZ_OP_RSP] = '_OnRoomOpRsp',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_PLAYER_JOINED_NOTIFY] = '_OnPlayerJoined',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_PLAYER_LEFT_NOTIFY] = '_OnPlayerLeft',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_PLAYER_UPDATED_NOTIFY] = '_OnRoomUpdated',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_PLAYER_BECAME_READY_NOTIFY] = '_OnPlayerBecameReady',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_STATE_UPDATED_NOTIFY] = '_OnRoomStateUpdated',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_FULL_SYNC_NOTIFY] = '_OnRoomStateUpdated',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_BIZ_DATA_UPDATED_NOTIFY] = '_OnRoomUpdated',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_STATE_QUERY_RSP] = '_OnRoomUpdated',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_HOST_CHANGED_NOTIFY] = '_OnHostChanged',
    [MessageConst.ON_MULTIPLAYER_MATCH_ROOM_LEFT] = '_OnMatchRoomLeft',
    [MessageConst.ON_MULTIPLAYER_ROOM_REMIND_READY_NOTIFY] = '_OnRemindReadyNotify',
    [MessageConst.ON_MULTIPLAYER_CARD_GAME_SET_CHAR_RSP] = '_RefreshCharHeadIcon',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_RETURN] = '_OnPlayRoomReturn',
}

MultiplayerRoomCtrl.m_gameBackground = HL.Field(CS.UnityEngine.GameObject)

MultiplayerRoomCtrl.m_clickState = HL.Field(HL.String) << ""
MultiplayerRoomCtrl.m_stateEnterTime = HL.Field(HL.Number) << 0
MultiplayerRoomCtrl.m_cancelCoroutine = HL.Field(HL.Thread)
MultiplayerRoomCtrl.m_cancelLocked = HL.Field(HL.Boolean) << false
MultiplayerRoomCtrl.m_remindTimerId = HL.Field(HL.Number) << -1


MultiplayerRoomCtrl.OnCreateRoomRsp = HL.StaticMethod(HL.Any) << function(args)
    local errcode = unpack(args)
    if errcode ~= 0 then
        return
    end
    UIManager:Close(PanelId.MultiplayerEnterRoom)
    if UIManager:IsOpen(PANEL_ID) then
        return
    end
    if PhaseManager:GetTopPhaseId() == PhaseId.MultiplayerMatch then
        PhaseManager:ExitPhaseFast(PhaseId.MultiplayerMatch)
    end
    PhaseManager:OpenPhase(PHASE_ID, nil, nil, true)
end

MultiplayerRoomCtrl.OnJoinRoomRsp = HL.StaticMethod(HL.Any) << function(args)
    local errcode = unpack(args)
    if errcode ~= 0 then
        return
    end
    UIManager:Close(PanelId.MultiplayerEnterRoom)
    if UIManager:IsOpen(PANEL_ID) then
        return
    end
    
    if not PhaseManager:IsOpen(PhaseId.MultiplayerMain) then
        PhaseManager:OpenPhaseFast(PhaseId.MultiplayerMain)
    end
    PhaseManager:OpenPhase(PHASE_ID, nil, nil, true)
end

MultiplayerRoomCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room == nil then
        logger.error("[MultiplayerRoomCtrl] matchRoom 为空，关闭 Phase")
        PhaseManager:ExitPhaseFast(PHASE_ID)
        return
    end

    UIManager:ToggleBlockObtainWaysJump(BLOCK_OBTAIN_WAYS_JUMP_KEY, true)

    local hasInvitation, invitationCtrl = UIManager:IsOpen(PanelId.MultiplayerRoomInvitation)
    if hasInvitation then
        invitationCtrl:PlayAnimationOutAndClose()
    end
    self:_InitUI()
    self:_RefreshAll()
    self:_SetDefaultNaviTarget()
    self:_StartStateTick()
    LuaSystemManager.ps5MultiplayerSystem:TryShowPSOnlyNotice()
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
    if arg and arg.recoverState then
        self.view.roomContent.view.emojiNode:RecoverState(arg.recoverState.emojiNode)
    end
end


MultiplayerRoomCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        recoverState = {
            emojiNode = self.view.roomContent.view.emojiNode:GetRecoverState(),
        },
    }
end



MultiplayerRoomCtrl._InitUI = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.btnBack.onClick:AddListener(function()
        self:_OnBtnBackClick()
    end)
    self.view.helpBtn.onClick:AddListener(function()
        self:_OnHelpBtnClick()
    end)
    local click = self.view.clickStateNode
    click.clickBtn.onClick:AddListener(function()
        self:_OnClickBtnClick()
    end)
    click.cancelBtn.onClick:AddListener(function()
        self:_OnCancelBtnClick()
    end)
    self.view.charBtn.onClick:AddListener(function()
        MultiplayerUtils.openCharSelect()
    end)

    self.view.roomContent:InitMultiplayerRoomContent()
    self:_SetHintNodeActive(false)
end

MultiplayerRoomCtrl._SetDefaultNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    local target = self.view.roomContent:GetFirstPlayerCellNaviTarget()
    if target ~= nil then
        self:SetNaviTarget(target)
    end
end

MultiplayerRoomCtrl.OnClose = HL.Override() << function(self)
    UIManager:ToggleBlockObtainWaysJump(BLOCK_OBTAIN_WAYS_JUMP_KEY, false)
    MultiplayerUtils.clearGameBackground(self.m_gameBackground)
    self.m_gameBackground = nil
    LuaSystemManager.ps5MultiplayerSystem:TryClosePSOnlyNotice()
    self:_StopRemindDisplay()
end

MultiplayerRoomCtrl._OnBtnBackClick = HL.Method() << function(self)
    local content = self:_IsMatching()
        and Language.LUA_MULTIPLAYER_ROOM_LEAVE_CONFIRM_MATCHING
        or Language.LUA_MULTIPLAYER_ROOM_LEAVE_CONFIRM
    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        onConfirm = function()
            GameInstance.player.multiplayerMatchSystem:Leave()
        end,
    })
end

MultiplayerRoomCtrl._OnClickBtnClick = HL.Method() << function(self)
    local state = self.m_clickState
    if state == MultiplayerConst.EClickState.Start then
        GameInstance.player.multiplayerMatchSystem:StartPlay()
    elseif state == MultiplayerConst.EClickState.StartMatch then
        GameInstance.player.multiplayerMatchSystem:StartMatch()
    elseif state == MultiplayerConst.EClickState.Ready then
        GameInstance.player.multiplayerMatchSystem:Ready()
    end
end

MultiplayerRoomCtrl._OnCancelBtnClick = HL.Method() << function(self)
    local state = self.m_clickState
    if state == MultiplayerConst.EClickState.GetReady then
        GameInstance.player.multiplayerMatchSystem:Unready()
    elseif state == MultiplayerConst.EClickState.Matching then
        GameInstance.player.multiplayerMatchSystem:StopMatch()
    end
end


MultiplayerRoomCtrl._OnHelpBtnClick = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    local found, data = Tables.multiplayerGameCenterTable:TryGetValue(room and room.gameId or "")
    local introKey = found and data.introKey or ""
    Notify(MessageConst.SHOW_INTRO, introKey)
end

MultiplayerRoomCtrl._OnPlayRoomReturn = HL.Method(HL.Opt(HL.Number)) << function(self, returnTarget)
    if returnTarget ~= MultiplayerConst.EPlayRoomReturn.RoomMatch then
        return
    end
    if MultiplayerUtils.checkAllGamesClosed() then
        return
    end
    if not GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        PhaseManager:ExitPhaseFast(PHASE_ID)
    end
end





MultiplayerRoomCtrl._OnRoomOpRsp = HL.Method(HL.Any) << function(self, args)
    local errcode = unpack(args)
    if errcode ~= 0 then
        return
    end
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room ~= nil then
        self:_RefreshRoom(room.state, room.state)
    end
end

MultiplayerRoomCtrl._OnRoomUpdated = HL.Method(HL.Any) << function(self, args)
    local prevState, curState = unpack(args)
    self:_RefreshRoom(prevState, curState)
end


MultiplayerRoomCtrl._OnRoomStateUpdated = HL.Method(HL.Any) << function(self, args)
    local prevState, curState, updateReason = unpack(args)
    self:_RefreshRoom(prevState, curState, updateReason)
    local matching = CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if prevState ~= matching and curState == matching and room ~= nil and not room.isSelfHost then
        self:_TryShowToast(Language.LUA_MULTIPLAYER_ROOM_HOST_START_MATCH_TOAST)
    end
end


MultiplayerRoomCtrl._RefreshRoom = HL.Method(HL.Any, HL.Any, HL.Opt(HL.Any)) << function(self, prevState, curState, updateReason)
    local matching = CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching
    if prevState == matching and curState ~= matching then
        self:_EnterCancelState(updateReason)
    end
    if curState == matching
        or curState == CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Closed then
        if not LuaSystemManager.cardGameSystem.isClientInGame then
            PhaseManager:ExitPhaseFastTo(PHASE_ID)
        end
    end

    self.view.roomContent:RefreshFromMatchRoom()
    self:_RefreshGameInfo()

    if not self.m_cancelLocked then
        self:_RefreshClickStateFromRoom()
    end
    
    self:_RefreshCharBtnEnabled()
end

MultiplayerRoomCtrl._OnMatchRoomLeft = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    local reason = args and unpack(args) or nil
    if reason == LEAVE_REASON_KICK then
        self:_TryShowToast(Language.LUA_MULTIPLAYER_ROOM_KICKED_TOAST)
    elseif reason == LEAVE_REASON_ROOM_CLOSED then
        self:_TryShowToast(Language.LUA_MULTIPLAYER_ROOM_CLOSED_TOAST)
    end
    self:_StopRemindDisplay()
    self:_StartCoroutine(function()
        while PhaseManager:IsInPhaseTransition() do
            coroutine.step()
        end
        if not LuaSystemManager.cardGameSystem.isClientInGame then
            
            PhaseManager:ExitPhaseFastTo(PHASE_ID)
            MultiplayerUtils.closeMatchOverlayPanels(true)
        end
        
        PhaseManager:ExitPhaseFast(PHASE_ID)
    end)
end

MultiplayerRoomCtrl._RefreshAll = HL.Method() << function(self)
    self.view.roomContent:RefreshFromMatchRoom()
    self:_RefreshGameInfo()
    self:_RefreshClickStateFromRoom()
    self:_RefreshCharHeadIcon()
    self:_RefreshCharBtnEnabled()
end

MultiplayerRoomCtrl._RefreshCharHeadIcon = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    MultiplayerUtils.refreshCharHeadIcon(self.view.headIcon, MultiplayerUtils.getSelfDisplayCharTemplateId())
end

MultiplayerRoomCtrl._RefreshCharBtnEnabled = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    local memberReady = self.m_clickState == MultiplayerConst.EClickState.GetReady
    if room ~= nil and not room.isSelfHost then
        local localPlayer = self:_EvalRoomReady(room)
        memberReady = memberReady or (localPlayer ~= nil
            and localPlayer.readyState == CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Ready)
    end
    self.view.charBtn.enabled = not self:_IsMatching() and not memberReady
end

MultiplayerRoomCtrl._IsMatching = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_clickState == MultiplayerConst.EClickState.Matching then
        return true
    end
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    return room ~= nil and room.state == CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching
end

MultiplayerRoomCtrl._RefreshGameInfo = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    local gameId = room and room.gameId or ""
    local found, data = Tables.multiplayerGameCenterTable:TryGetValue(gameId)
    self.m_gameBackground = MultiplayerUtils.refreshGameBackground(self, self.view.deployNode,
        self.m_gameBackground, found and data.gameRoomBgName or "")
    self.view.gameInfoNode:InitMultiplayerGameInfoNode({
        gameId = gameId,
    })
end

MultiplayerRoomCtrl._RefreshClickStateFromRoom = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room == nil then
        return
    end

    local localPlayer, isHost, allReady, isFull = self:_EvalRoomReady(room)
    
    if localPlayer == nil then
        return
    end

    if room.state == CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching then
        self:_SetClickState(MultiplayerConst.EClickState.Matching, isHost)
        return
    end

    if isHost then
        if allReady and isFull then
            self:_SetClickState(MultiplayerConst.EClickState.Start, true)
        elseif allReady then
            self:_SetClickState(MultiplayerConst.EClickState.StartMatch, true)
        else
            self:_SetClickState(MultiplayerConst.EClickState.WaitReady, true)
        end
        return
    end

    if localPlayer.readyState == CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Ready then
        self:_SetClickState(MultiplayerConst.EClickState.GetReady, false)
    else
        self:_SetClickState(MultiplayerConst.EClickState.Ready, false)
    end
end

MultiplayerRoomCtrl._EvalRoomReady = HL.Method(HL.Any).Return(HL.Any, HL.Boolean, HL.Boolean, HL.Boolean)
    << function(self, room)
    local localRoleId = GameInstance.player.roleId
    local localPlayer = nil
    local isHost = room.isSelfHost == true
    local allReady = true
    local players = room.players
    local memberCount = 0
    if players ~= nil then
        memberCount = players.Count
        for i = 0, players.Count - 1 do
            local p = players[i]
            if p ~= nil then
                if p.roleId == localRoleId then
                    localPlayer = p
                end
                if p.readyState ~= CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Ready then
                    allReady = false
                end
            end
        end
    end

    local maxCount = 0
    local gameId = room.gameId or ""
    if not string.isEmpty(gameId) then
        local found, data = Tables.multiplayerGameCenterTable:TryGetValue(gameId)
        if found and data ~= nil then
            maxCount = data.roomMaxPlayerNum or 0
        end
    end
    local isFull = maxCount > 0 and memberCount >= maxCount
    return localPlayer, isHost, allReady, isFull
end





MultiplayerRoomCtrl._TryShowToast = HL.Method(HL.String) << function(self, content)
    if LuaSystemManager.cardGameSystem.isClientInGame then
        return
    end
    Notify(MessageConst.SHOW_TOAST, content)
end


MultiplayerRoomCtrl._OnPlayerJoined = HL.Method(HL.Any) << function(self, args)
    self:_OnRoomUpdated(args)
    local _, _, roleId = unpack(args)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    
    if room ~= nil and room.isSelfHost and roleId == GameInstance.player.roleId then
        return
    end
    self:_TryShowToast(
        string.format(Language.LUA_MULTIPLAYER_ROOM_PLAYER_ENTER_TOAST, self:_GetNicknameByRoleId(roleId)))
end

MultiplayerRoomCtrl._OnPlayerLeft = HL.Method(HL.Any) << function(self, args)
    self:_OnRoomUpdated(args)
    local _, _, _, wasHost, nickname = unpack(args)
    
    local textKey = wasHost and Language.LUA_MULTIPLAYER_ROOM_HOST_LEAVE_TOAST
        or Language.LUA_MULTIPLAYER_ROOM_PLAYER_LEAVE_TOAST
    self:_TryShowToast(string.format(textKey, nickname))
end


MultiplayerRoomCtrl._OnPlayerBecameReady = HL.Method(HL.Any) << function(self, args)
    local roleId = unpack(args)
    if roleId == GameInstance.player.roleId then
        self:_TryShowToast(Language.LUA_MULTIPLAYER_ROOM_PLAYER_READY_SELF_TOAST)
    else
        self:_TryShowToast(
            string.format(Language.LUA_MULTIPLAYER_ROOM_PLAYER_READY_TOAST, self:_GetNicknameByRoleId(roleId)))
    end
end


MultiplayerRoomCtrl._OnHostChanged = HL.Method(HL.Any) << function(self, args)
    local curHostRoleId = unpack(args)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room ~= nil and room.isSelfHost then
        self:_TryShowToast(Language.LUA_MULTIPLAYER_ROOM_HOST_CHANGED_SELF_TOAST)
    else
        self:_TryShowToast(
            string.format(Language.LUA_MULTIPLAYER_ROOM_HOST_CHANGED_TOAST, self:_GetNicknameByRoleId(curHostRoleId)))
    end
end

MultiplayerRoomCtrl._GetNicknameByRoleId = HL.Method(HL.Any).Return(HL.String) << function(self, roleId)
    if roleId ~= nil then
        local success, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
        if success and friendInfo ~= nil and friendInfo.name ~= nil then
            return friendInfo.name
        end
    end
    logger.warn("[MultiplayerRoomCtrl] 查不到玩家昵称 roleId=", roleId)
    return ""
end





MultiplayerRoomCtrl._OnRemindReadyNotify = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if LuaSystemManager.cardGameSystem.isClientInGame then
        return
    end
    local roomStrId = unpack(args or {})
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room == nil or roomStrId ~= (room.roomStrId or "") then
        return
    end

    local isOpen, noticeCtrl = UIManager:IsOpen(NOTICE_PANEL_ID)
    
    if isOpen and noticeCtrl:IsPlayingAnimationOut() then
        noticeCtrl:Close()
    end
    UIManager:AutoOpen(NOTICE_PANEL_ID)

    self:_SetHintNodeActive(self.m_clickState == MultiplayerConst.EClickState.Ready)
    self:_RestartRemindTimer()
end

MultiplayerRoomCtrl._RestartRemindTimer = HL.Method() << function(self)
    if self.m_remindTimerId >= 0 then
        self.m_remindTimerId = self:_ClearTimer(self.m_remindTimerId)
    end
    local timerId
    timerId = self:_StartTimer(REMIND_SHOW_SECONDS, function()
        if self.m_remindTimerId ~= timerId then
            return
        end
        self.m_remindTimerId = -1
        self:_StopRemindDisplay()
    end, true)
    self.m_remindTimerId = timerId
end

MultiplayerRoomCtrl._StopRemindDisplay = HL.Method() << function(self)
    if self.m_remindTimerId >= 0 then
        self.m_remindTimerId = self:_ClearTimer(self.m_remindTimerId)
    end
    self:_SetHintNodeActive(false)
    local isOpen, noticeCtrl = UIManager:IsOpen(NOTICE_PANEL_ID)
    if isOpen then
        noticeCtrl:PlayAnimationOutAndClose()
    end
end

MultiplayerRoomCtrl._SetHintNodeActive = HL.Method(HL.Boolean) << function(self, active)
    self.view.hintNode.gameObject:SetActiveIfNecessary(active)
end





MultiplayerRoomCtrl._EnterCancelState = HL.Method(HL.Opt(HL.Any)) << function(self, updateReason)
    local reason = CS.Proto.SCD_MULTIPLAYER_MATCH_ROOM_STATE_UPDATE_REASON
    
    local interrupted = updateReason == reason.Leave or updateReason == reason.Kick
        or updateReason == reason.Offline or updateReason == reason.LostHeartbeat
    local state = interrupted and MultiplayerConst.EClickState.Offline or MultiplayerConst.EClickState.Cancel
    self.m_cancelLocked = true
    self:_SetClickState(state, false)
end


MultiplayerRoomCtrl._SetClickState = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, state, isHost)
    if self.m_cancelCoroutine then
        self.m_cancelCoroutine = self:_ClearCoroutine(self.m_cancelCoroutine)
    end
    self.m_clickState = state
    self.m_stateEnterTime = getNowSec()

    local click = self.view.clickStateNode
    self.view.layoutNode:SetState(state)

    local clickActionId = CLICK_ACTION_BY_STATE[state]
    if clickActionId ~= nil and click.clickBtn.onClick:GetActionId() ~= clickActionId then
        click.clickBtn.onClick:ChangeBindingPlayerAction(clickActionId)
    end
    local cancelActionId = CANCEL_ACTION_BY_STATE[state]
    if cancelActionId ~= nil and click.cancelBtn.onClick:GetActionId() ~= cancelActionId then
        click.cancelBtn.onClick:ChangeBindingPlayerAction(cancelActionId)
    end

    if state == MultiplayerConst.EClickState.GetReady then
        click.cancelBtn.gameObject:SetActiveIfNecessary(true)
    elseif state == MultiplayerConst.EClickState.Matching then
        click.matchingTimeTxt.text = UIUtils.getLeftTimeToSecond(0)
        click.cancelBtn.gameObject:SetActiveIfNecessary(isHost == true)
    elseif state == MultiplayerConst.EClickState.Cancel or state == MultiplayerConst.EClickState.Offline then
        
        
        local endTime = Time.realtimeSinceStartup + click.cancelLight:GetClip("click_cancellight_in").length
        self.m_cancelCoroutine = self:_StartCoroutine(function()
            while Time.realtimeSinceStartup < endTime do
                coroutine.step()
            end
            
            coroutine.waitForRenderDone()
            self.m_cancelCoroutine = nil
            self.m_cancelLocked = false
            self:_RefreshClickStateFromRoom()
        end)
    end

    self:_RefreshCharBtnEnabled()
end

MultiplayerRoomCtrl._StartStateTick = HL.Method() << function(self)
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_TickState()
        end
    end)
end

MultiplayerRoomCtrl._TickState = HL.Method() << function(self)
    local elapsed = getNowSec() - self.m_stateEnterTime
    local state = self.m_clickState

    if state == MultiplayerConst.EClickState.Matching then
        self.view.clickStateNode.matchingTimeTxt.text = UIUtils.getLeftTimeToSecond(elapsed)
    end
end



HL.Commit(MultiplayerRoomCtrl)
