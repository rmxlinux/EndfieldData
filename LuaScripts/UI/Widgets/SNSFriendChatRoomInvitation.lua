local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

SNSFriendChatRoomInvitation = HL.Class('SNSFriendChatRoomInvitation', UIWidgetBase)

SNSFriendChatRoomInvitation.m_message = HL.Field(HL.Any)

SNSFriendChatRoomInvitation.m_isJoinable = HL.Field(HL.Boolean) << false

local NORMAL_STATE = "Normal"
local INVALID_STATE = "Invalid"
local LOADING_STATE = "Loading"


SNSFriendChatRoomInvitation._OnFirstTimeInit = HL.Override() << function(self)
    self.view.clickBtn.onClick:AddListener(function()
        self:_OnClick()
    end)
end

SNSFriendChatRoomInvitation.InitSNSFriendChatRoomInvitation = HL.Method(HL.Any) << function(self, message)
    self:_FirstTimeInit()
    self:UpdateRoomInvitationShow(message)
end

SNSFriendChatRoomInvitation.UpdateRoomInvitationShow = HL.Method(HL.Any) << function(self, message)
    self.m_message = message
    local gameData = Tables.multiplayerGameCenterTable[message.roomGameId]
    self.view.descTxt.text = gameData.gameName

    self.m_isJoinable = message.roomStateQueried
        and message.isMatchRoom
        and message.roomState ~= CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Invalid
        and message.roomState ~= CS.Proto.MULTIPLAYER_MATCH_ROOM_STATE.Closed
    local state = self.m_isJoinable and NORMAL_STATE or INVALID_STATE
    if message.isMatchRoom and not message.roomStateQueried then
        state = LOADING_STATE
    end
    self.view.nodeState:SetState(state)

    local iconName = gameData.gameInvitationCardIconName
    if string.isEmpty(iconName) then
        self.view.gameIcon.sprite = nil
    else
        local suffix = state == NORMAL_STATE and "_1" or "_2"
        self.view.gameIcon:LoadSprite(UIConst.UI_SPRITE_MULTIPLAYER, iconName .. suffix)
    end
end

SNSFriendChatRoomInvitation.CheckCanJumpIn = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_message ~= nil and (not self.m_message.isMatchRoom or self.m_message.roomStateQueried)
end

SNSFriendChatRoomInvitation.SetTargetNode = HL.Method() << function(self)
    self:SetNaviTarget(self.view.clickBtn)
end

SNSFriendChatRoomInvitation._OnClick = HL.Method() << function(self)
    if not self:CheckCanJumpIn() then
        return
    end

    if not self.m_isJoinable then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ROOM_INVALID_TOAST)
        return
    end

    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(self.m_message.roomGameId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_MATCH_ROOM_GAME_NOT_AVAILABLE_TOAST)
        return
    end

    MultiplayerUtils.enterRoomByInvitation(self.m_message.roomStrId)
end

HL.Commit(SNSFriendChatRoomInvitation)
return SNSFriendChatRoomInvitation

