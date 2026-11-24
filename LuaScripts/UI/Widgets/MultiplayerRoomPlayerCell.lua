local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


MultiplayerRoomPlayerCell = HL.Class('MultiplayerRoomPlayerCell', UIWidgetBase)

MultiplayerRoomPlayerCell.m_args = HL.Field(HL.Table)
MultiplayerRoomPlayerCell.m_roleId = HL.Field(HL.Any)


MultiplayerRoomPlayerCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.inviteBtn.onClick:RemoveAllListeners()
    self.view.inviteBtn.onClick:AddListener(function()
        if self.m_args and self.m_args.inviteFunc then
            self.m_args.inviteFunc()
        end
    end)

    self.view.kickBtn.onClick:RemoveAllListeners()
    self.view.kickBtn.onClick:AddListener(function()
        if self.m_args and self.m_args.kickFunc then
            self.m_args.kickFunc()
        end
    end)
end


MultiplayerRoomPlayerCell.InitMultiplayerRoomPlayerCell = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()
    self.m_args = args

    local newRoleId = args.briefData and args.briefData.roleId or nil
    local roleChanged = self.m_roleId ~= newRoleId
    self.m_roleId = newRoleId

    
    if args.nodeState then
        self.view.nodeState:SetState(args.nodeState)
    end
    if args.ownerState then
        self.view.nodeState:SetState(args.ownerState)
    end
    if args.selfState then
        self.view.nodeState:SetState(args.selfState)
    end
    self:_RefreshActionButtons()
    self:_RefreshPlayerCell()
    self:_RefreshHeadIcon()
    if roleChanged or newRoleId == nil then
        self:SetEmoji(nil)
    end
end

MultiplayerRoomPlayerCell.GetRoleId = HL.Method().Return(HL.Any) << function(self)
    return self.m_roleId
end


MultiplayerRoomPlayerCell._RefreshPlayerCell = HL.Method() << function(self)
    local briefData = self.m_args and self.m_args.briefData or nil
    if briefData == nil then
        return
    end

    local roleId = briefData.roleId
    local success, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
    if not success then
        return
    end
    local playerClickFunc = self.m_args.playerClickFunc
    self.view.playerCell:InitMultiplayerPlayerCell(roleId, friendInfo, playerClickFunc, playerClickFunc)
end


MultiplayerRoomPlayerCell._RefreshHeadIcon = HL.Method() << function(self)
    local briefData = self.m_args and self.m_args.briefData or nil
    MultiplayerUtils.refreshCharHeadIcon(self.view.headIcon, MultiplayerUtils.getMemberDisplayCharTemplateId(briefData))
end

MultiplayerRoomPlayerCell.SetNodeState = HL.Method(HL.String) << function(self, state)
    self.view.nodeState:SetState(state)
    
    self:_RefreshActionButtons()
    self:_RefreshHeadIcon()
end

MultiplayerRoomPlayerCell._RefreshActionButtons = HL.Method() << function(self)
    local args = self.m_args
    self.view.inviteBtn.gameObject:SetActiveIfNecessary(args ~= nil and args.inviteFunc ~= nil)
    self.view.kickBtn.gameObject:SetActiveIfNecessary(args ~= nil and args.kickFunc ~= nil)
end



MultiplayerRoomPlayerCell.SetEmoji = HL.Method(HL.Opt(HL.String)) << function(self, emoji)
    local emojiNode = self.view.emojiNode
    if string.isEmpty(emoji) then
        emojiNode:Clear()
        return
    end

    emojiNode:Init(emoji)
    emojiNode:Play(MultiplayerUtils.getMemberDisplayCharTemplateId(self.m_args.briefData))
end

HL.Commit(MultiplayerRoomPlayerCell)
return MultiplayerRoomPlayerCell
