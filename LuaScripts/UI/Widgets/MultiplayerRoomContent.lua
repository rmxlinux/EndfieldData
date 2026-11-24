local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local NUM_STATE_NORMAL = "Normal"
local NUM_STATE_MATCH = "Match"


local BTN_STATE_NORMAL = "Normal"
local BTN_STATE_CLICK = "Click"
local BTN_STATE_TIME = "Time"
local BTN_STATE_DISABLED = "Disabled"


local REMIND_CD_SECONDS = 15
local EMOJI_CD_SECONDS = 3

local CLIENT_DATA_CATEGORY = "Multiplayer"
local CLIENT_DATA_KICK_HIDE_TODAY = "MULTIPLAYER_ROOM_KICK_CONFIRM_DAILY"

local function getNowSec()
    return DateTimeUtils.GetCurrentTimestampBySeconds()
end

local READY_STATE_MATCHING = CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Matching
local ROOM_STATE_JOINABLE = CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Joinable
local ROOM_STATE_IN_GAME = CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.InGame


MultiplayerRoomContent = HL.Class('MultiplayerRoomContent', UIWidgetBase)

MultiplayerRoomContent.m_playerCellCache = HL.Field(HL.Forward("UIListCache"))
MultiplayerRoomContent.m_roomStrId = HL.Field(HL.String) << ""
MultiplayerRoomContent.m_remindCdEndTime = HL.Field(HL.Number) << 0
MultiplayerRoomContent.m_emojiCdEndTime = HL.Field(HL.Number) << 0

MultiplayerRoomContent._OnFirstTimeInit = HL.Override() << function(self)
    self.m_playerCellCache = UIUtils.genCellCache(self.view.roomPlayerCell)

    
    self.view.remindBtn.button.onClick:RemoveAllListeners()
    self.view.remindBtn.button.onClick:AddListener(function()
        self:_OnRemindBtnClick()
    end)

    self.view.emojiNode.gameObject:SetActiveIfNecessary(false)
    self.view.emojiBtn.button.onClick:RemoveAllListeners()
    self.view.emojiBtn.button.onClick:AddListener(function()
        self:_OnEmojiBtnClick()
    end)

    self:RegisterMessage(MessageConst.ON_FRIEND_BUSINESS_INFO_CHANGE, function()
        self:RefreshFromMatchRoom()
    end)

    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_ROOM_EMOJI_NOTIFY, function(arg)
        self:_OnRoomEmojiNotify(arg)
    end)

    self.view.copyBtn.onClick:RemoveAllListeners()
    self.view.copyBtn.onClick:AddListener(function()
        self:_OnCopyBtnClick()
    end)

    self:_SetBtnCdActive(self.view.remindBtn, false)
    self:_SetBtnCdActive(self.view.emojiBtn, false)
    self:_StartCdTick()
end


MultiplayerRoomContent._OnCopyBtnClick = HL.Method() << function(self)
    local text = string.trim(self.view.roomCodeTxt.text or "")
    Unity.GUIUtility.systemCopyBuffer = text
    Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ROOM_CODE_COPY_SUCCESS)
end


MultiplayerRoomContent.InitMultiplayerRoomContent = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()
    self:RefreshFromMatchRoom()
end

MultiplayerRoomContent._OnRemindBtnClick = HL.Method() << function(self)
    if string.isEmpty(self.m_roomStrId) then
        return
    end
    
    if self.m_remindCdEndTime > 0 then
        return
    end
    GameInstance.player.multiplayerGameCenterSystem:RemindReady(self.m_roomStrId)
    self.m_remindCdEndTime = self:_StartBtnCd(self.view.remindBtn, REMIND_CD_SECONDS)
end

MultiplayerRoomContent._OnEmojiBtnClick = HL.Method() << function(self)
    local go = self.view.emojiNode.gameObject
    self.view.emojiNode:SetEmojiNodeActive(not go.activeSelf)
end

MultiplayerRoomContent._OpenFriendInvite = HL.Method() << function(self)
    if FriendUtils.isPsnPlatform() then
        GameInstance.player.friendSystem:SetQueryPsnBlockRelation(true)
    end
    PhaseManager:GoToPhase(PhaseId.Friend, {
        panelId = PanelId.FriendList,
        needClose = true,
        needTab = false,
        stateName = "RoomInvite",
        cellStateName = "Invite",
        title = Language.LUA_CLUE_SCHEDULE_INVITE_FRIEND_PANEL_TITLE,
        businessCardMoreActionArgs = {
            ignoreFriendCommunication = true,
        },
        sentInviteTargets = {},
    })
end

MultiplayerRoomContent.GetFirstPlayerCellNaviTarget = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local cell = self.m_playerCellCache and self.m_playerCellCache:GetItem(1) or nil
    return cell and cell.view.multiplayerRoomPlayerCell or nil
end

MultiplayerRoomContent._OnRoomEmojiNotify = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    local roomStrId, senderRoleId, emojiId = unpack(args or {})
    if roomStrId ~= self.m_roomStrId then
        return
    end
    if string.isEmpty(emojiId) or senderRoleId == nil then
        return
    end

    local count = self.m_playerCellCache and self.m_playerCellCache:GetCount() or 0
    for i = 1, count do
        local cell = self.m_playerCellCache:GetItem(i)
        if cell and cell:GetRoleId() == senderRoleId then
            cell:SetEmoji(emojiId)
            return
        end
    end
end



MultiplayerRoomContent._OnEmojiSent = HL.Method() << function(self)
    self.m_emojiCdEndTime = self:_StartBtnCd(self.view.emojiBtn, EMOJI_CD_SECONDS)
end

MultiplayerRoomContent._StartBtnCd = HL.Method(HL.Any, HL.Number).Return(HL.Number) << function(self, btn, cdSeconds)
    self:_SetBtnCdActive(btn, true)
    btn.numTxt.text = string.format("%ds", cdSeconds)
    return getNowSec() + cdSeconds
end


MultiplayerRoomContent._SetBtnCdActive = HL.Method(HL.Any, HL.Boolean) << function(self, btn, active)
    btn.nodeState:SetState(active and BTN_STATE_TIME or BTN_STATE_NORMAL)
    btn.button.interactable = not active
end

MultiplayerRoomContent._StartCdTick = HL.Method() << function(self)
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            local remindCdEndTime = self:_TickBtnCd(self.view.remindBtn, self.m_remindCdEndTime)
            if self.m_remindCdEndTime ~= remindCdEndTime then
                self.m_remindCdEndTime = remindCdEndTime
                self:_RefreshRemindBtn()
            end
            self.m_emojiCdEndTime = self:_TickBtnCd(self.view.emojiBtn, self.m_emojiCdEndTime)
        end
    end)
end


MultiplayerRoomContent._TickBtnCd = HL.Method(HL.Any, HL.Number).Return(HL.Number) << function(self, btn, endTime)
    if endTime <= 0 then
        return 0
    end
    local remain = endTime - getNowSec()
    if remain > 0 then
        btn.numTxt.text = string.format("%ds", math.ceil(remain))
        return endTime
    end
    self:_SetBtnCdActive(btn, false)
    return 0
end



MultiplayerRoomContent.RefreshFromMatchRoom = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    if room == nil then
        self.m_roomStrId = ""
        self.view.emojiNode:InitMultiplayerEmojiNode({ roomStrId = "" })
        self.view.roomCodeTxt.text = ""
        self.view.playerNumTxt.text = "0/0"
        self.view.numState:SetState(NUM_STATE_NORMAL)
        self.view.remindBtn.gameObject:SetActiveIfNecessary(false)
        if self.m_playerCellCache then
            self.m_playerCellCache:Refresh(0)
        end
        return
    end

    self.m_roomStrId = room.roomStrId or ""
    self.view.emojiNode:InitMultiplayerEmojiNode({
        roomStrId = self.m_roomStrId,
        onEmojiSent = function()
            self:_OnEmojiSent()
        end,
        onActiveChanged = function(active)
            if self.m_emojiCdEndTime <= 0 then
                self.view.emojiBtn.nodeState:SetState(active and BTN_STATE_CLICK or BTN_STATE_NORMAL)
            end
        end,
    })
    self.view.roomCodeTxt.text = room.roomShowCode or ""

    local maxCount = self:_GetRoomMaxPlayerNum(room.gameId or "")
    local curCount = room.memberCount or 0
    if curCount <= 0 and room.players ~= nil then
        curCount = room.players.Count
    end
    self.view.playerNumTxt.text = string.format("%d/%d", curCount, maxCount)

    local isMatching = room.state == CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching
    local showInvite = room.state == ROOM_STATE_JOINABLE or room.state == ROOM_STATE_IN_GAME
    self.view.numState:SetState(isMatching and NUM_STATE_MATCH or NUM_STATE_NORMAL)

    local sorted = self:_BuildSortedPlayers(room)
    local localRoleId = GameInstance.player.roleId
    local localIsHost = room.isSelfHost == true
    self:_RefreshRemindBtn()

    self.m_playerCellCache:Refresh(maxCount, function(cell, luaIndex)
        local player = sorted[luaIndex]
        if player == nil then
            cell:InitMultiplayerRoomPlayerCell({
                nodeState = isMatching and MultiplayerConst.EPlayerCellState.Match
                    or MultiplayerConst.EPlayerCellState.Add,
                ownerState = MultiplayerConst.EPlayerCellState.NotOwner,
                selfState = MultiplayerConst.EPlayerCellState.Other,
                inviteFunc = showInvite and function()
                    self:_OpenFriendInvite()
                end,
            })
            return
        end

        local briefData = player.briefData
        local isSelf = player.roleId == localRoleId
        local kickFunc = nil
        if localIsHost and not isSelf and not isMatching then
            kickFunc = function()
                self:_TryKickPlayer(player)
            end
        end

        cell:InitMultiplayerRoomPlayerCell({
            briefData = briefData,
            playerClickFunc = function()
                MultiplayerUtils.openBusinessCard(player.roleId)
            end,
            nodeState = self:_ResolveSeatState(player, player.roleId == room.hostRoleId),
            ownerState = player.roleId == room.hostRoleId and MultiplayerConst.EPlayerCellState.Owner
                or MultiplayerConst.EPlayerCellState.NotOwner,
            selfState = isSelf and MultiplayerConst.EPlayerCellState.Myself
                or MultiplayerConst.EPlayerCellState.Other,
            kickFunc = kickFunc,
        })
    end)
end


MultiplayerRoomContent._GetRoomMaxPlayerNum = HL.Method(HL.String).Return(HL.Number) << function(self, gameId)
    if string.isEmpty(gameId) then
        return 0
    end
    local found, data = Tables.multiplayerGameCenterTable:TryGetValue(gameId)
    if found and data ~= nil then
        return data.roomMaxPlayerNum or 0
    end
    return 0
end


MultiplayerRoomContent._BuildSortedPlayers = HL.Method(HL.Any).Return(HL.Table) << function(self, room)
    local result = {}
    local players = room.players
    if players == nil then
        return result
    end

    local host = nil
    local others = {}
    for i = 0, players.Count - 1 do
        local p = players[i]
        if p ~= nil then
            if p.roleId == room.hostRoleId then
                host = p
            else
                table.insert(others, p)
            end
        end
    end

    if host ~= nil then
        table.insert(result, host)
    end
    for _, p in ipairs(others) do
        table.insert(result, p)
    end
    return result
end

MultiplayerRoomContent._RefreshRemindBtn = HL.Method() << function(self)
    local room = GameInstance.player.multiplayerMatchSystem.matchRoom
    local showRemind = room ~= nil and room.isSelfHost
        and room.state ~= CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Matching
    self.view.remindBtn.gameObject:SetActiveIfNecessary(showRemind)
    local canRemind = showRemind and room.memberCount > 1
        and not self:_AreAllPlayersReady(self:_BuildSortedPlayers(room))
    local inCd = self.m_remindCdEndTime > 0
    local state = inCd and BTN_STATE_TIME or (canRemind and BTN_STATE_NORMAL or BTN_STATE_DISABLED)
    self.view.remindBtn.nodeState:SetState(state, false)
    self.view.remindBtn.button.interactable = canRemind and not inCd
end

MultiplayerRoomContent._AreAllPlayersReady = HL.Method(HL.Table).Return(HL.Boolean) << function(self, sorted)
    if sorted == nil or #sorted == 0 then
        return true
    end
    for _, p in ipairs(sorted) do
        if p.readyState ~= CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Ready then
            return false
        end
    end
    return true
end

MultiplayerRoomContent._ResolveSeatState = HL.Method(HL.Any, HL.Boolean).Return(HL.String) << function(self, player, isHost)
    local brief = player.briefData
    if brief ~= nil and brief.isDisconnected then
        return MultiplayerConst.EPlayerCellState.Miss
    end

    local readyState = player.readyState
    if readyState == CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.InGame then
        return MultiplayerConst.EPlayerCellState.InGame
    end
    if isHost or readyState == CS.Proto.MULTIPLAYER_MATCH_ROOM_PLAYER_READY_STATE.Ready
        or readyState == READY_STATE_MATCHING then
        return MultiplayerConst.EPlayerCellState.Ready
    end
    return MultiplayerConst.EPlayerCellState.Wait
end

MultiplayerRoomContent._TryKickPlayer = HL.Method(HL.Any) << function(self, player)
    local _, hideToday = ClientDataManagerInst:GetBool(
        CLIENT_DATA_KICK_HIDE_TODAY, false, false, CLIENT_DATA_CATEGORY)
    if hideToday then
        GameInstance.player.multiplayerMatchSystem:Kick(player.roleId)
        return
    end

    self:_ShowKickConfirm(player)
end

MultiplayerRoomContent._ShowKickConfirm = HL.Method(HL.Any) << function(self, player)
    local nickname = ""
    local roleId = player.roleId
    if roleId ~= nil then
        local success, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
        if success and friendInfo ~= nil and friendInfo.name ~= nil then
            nickname = friendInfo.name
        end
    end
    local closuresIsOn = false
    Notify(MessageConst.SHOW_POP_UP, {
        content = string.format(Language.LUA_MULTIPLAYER_ROOM_KICK_CONFIRM, nickname),
        toggle = {
            isOn = false,
            onValueChanged = function(isOn)
                closuresIsOn = isOn
            end,
            toggleText = Language.LUA_MULTIPLAYER_ROOM_NO_TIP_TODAY,
        },
        onConfirm = function()
            ClientDataManagerInst:SetBool(
                CLIENT_DATA_KICK_HIDE_TODAY, closuresIsOn, false,
                CLIENT_DATA_CATEGORY,
                EClientDataTimeValidType.CurrentDayUntil4AM)
            GameInstance.player.multiplayerMatchSystem:Kick(player.roleId)
        end,
    })
end

HL.Commit(MultiplayerRoomContent)
return MultiplayerRoomContent
