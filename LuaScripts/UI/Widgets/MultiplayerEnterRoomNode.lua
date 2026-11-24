local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


MultiplayerEnterRoomNode = HL.Class('MultiplayerEnterRoomNode', UIWidgetBase)

MultiplayerEnterRoomNode.m_args = HL.Field(HL.Table)


MultiplayerEnterRoomNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.createBtn.onClick:RemoveAllListeners()
    self.view.createBtn.onClick:AddListener(function()
        self:_OnCreateBtnClick()
    end)

    self.view.joinBtn.onClick:RemoveAllListeners()
    self.view.joinBtn.onClick:AddListener(function()
        self:_OnJoinBtnClick()
    end)

    self.view.pasteBtn.onClick:RemoveAllListeners()
    self.view.pasteBtn.onClick:AddListener(function()
        self:_OnPasteBtnClick()
    end)

    self.view.clearBtn.onClick:RemoveAllListeners()
    self.view.clearBtn.onClick:AddListener(function()
        self:_OnClearBtnClick()
    end)

    self.view.inputField.onValueChanged:AddListener(function(_)
        local inputField = self.view.inputField
        local roomCode = string.gsub(inputField.text, "[ \t\n\r]", "")
        inputField:SetTextWithoutNotify(roomCode)
        self:_RefreshInputButtons()
    end)
end


MultiplayerEnterRoomNode.InitMultiplayerEnterRoomNode = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    self.m_args = args

    local roomCode = args.roomCode
    if roomCode ~= nil then
        self.view.inputField.text = roomCode
    end
    self:_RefreshInputButtons()
end


MultiplayerEnterRoomNode.GetRoomCode = HL.Method().Return(HL.String) << function(self)
    local roomShowCode, _ = string.trim(self.view.inputField.text or "")
    return roomShowCode
end

MultiplayerEnterRoomNode._RefreshInputButtons = HL.Method() << function(self)
    local hasText = not string.isEmpty(self.view.inputField.text)
    self.view.clearBtn.gameObject:SetActiveIfNecessary(hasText)
    self.view.pasteBtn.gameObject:SetActiveIfNecessary(not hasText and UIUtils.supportsSystemCopyBuffer())
end

MultiplayerEnterRoomNode._OnCreateBtnClick = HL.Method() << function(self)
    local args = self.m_args
    if args == nil or args.onCreateClick == nil then
        logger.error("[MultiplayerEnterRoomNode] onCreateClick 为空，拒绝 Create")
        return
    end
    args.onCreateClick()
end

MultiplayerEnterRoomNode._OnJoinBtnClick = HL.Method() << function(self)
    local roomCode = self:GetRoomCode()
    if string.isEmpty(roomCode) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ENTER_ROOM_CODE_EMPTY)
        return
    end
    
    GameInstance.player.multiplayerMatchSystem:Join(roomCode)
end


MultiplayerEnterRoomNode._OnPasteBtnClick = HL.Method() << function(self)
    local text = Unity.GUIUtility.systemCopyBuffer or ""
    if string.isEmpty(text) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ENTER_ROOM_PASTE_EMPTY)
        return
    end
    self.view.inputField.text = text
end

MultiplayerEnterRoomNode._OnClearBtnClick = HL.Method() << function(self)
    self.view.inputField.text = ""
end

HL.Commit(MultiplayerEnterRoomNode)
return MultiplayerEnterRoomNode
