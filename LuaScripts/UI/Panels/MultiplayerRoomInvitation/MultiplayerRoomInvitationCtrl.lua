local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerRoomInvitation
local CANCEL_REQUEST_TIMEOUT_SECONDS = 10
local INVITATION_BASE_PANEL_IDS = {
    PanelId.MultiplayerMain,
    PanelId.MultiplayerMatch,
    PanelId.MultiplayerEnterRoom,
}


MultiplayerRoomInvitationCtrl = HL.Class('MultiplayerRoomInvitationCtrl', uiCtrl.UICtrl)

MultiplayerRoomInvitationCtrl.m_chatRoleId = HL.Field(HL.Number) << 0

MultiplayerRoomInvitationCtrl.m_pendingChatRoleId = HL.Field(HL.Number) << 0

MultiplayerRoomInvitationCtrl.m_waitingCancel = HL.Field(HL.Boolean) << false

MultiplayerRoomInvitationCtrl.m_cancelTimeoutTimerId = HL.Field(HL.Number) << -1

MultiplayerRoomInvitationCtrl.m_foldCoroutine = HL.Field(HL.Thread)






MultiplayerRoomInvitationCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_QUICK_MATCH_CANCEL_RSP] = '_OnQuickMatchCancelRsp',
    [MessageConst.ON_MULTIPLAYER_ENTER_PLAY_ROOM] = '_CloseSelf',
    [MessageConst.ON_UI_PHASE_OPENED] = '_OnTopPhaseChanged',
    [MessageConst.ON_UI_PHASE_EXITED] = '_OnTopPhaseChanged',
    [MessageConst.ON_BLOCK_KEYBOARD_EVENT_PANEL_ORDER_CHANGED] = '_OnPanelOrderChanged',
}


MultiplayerRoomInvitationCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:UpdateChatRoleId(arg)
    self.view.inviteBtn.onClick:AddListener(function()
        self:_OnInviteBtnClick()
    end)
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
end

MultiplayerRoomInvitationCtrl.UpdateChatRoleId = HL.Method(HL.Any) << function(self, chatRoleId)
    self.m_chatRoleId = chatRoleId
    self.m_foldCoroutine = self:_ClearCoroutine(self.m_foldCoroutine)
    if not self:IsPlayingAnimationIn() then
        self.animationWrapper:PlayInAnimation()
    end
    self.m_foldCoroutine = self:_StartCoroutine(function()
        while self:IsPlayingAnimationIn() do
            coroutine.step()
        end
        local foldTime = DateTimeUtils.GetCurrentTimestampByMilliseconds() / 1000 + self.view.config.SHOW_DURATION
        while DateTimeUtils.GetCurrentTimestampByMilliseconds() / 1000 < foldTime do
            coroutine.step()
        end
        self.m_foldCoroutine = nil
        self.animationWrapper:PlayWithTween("multiplayerroominvitation_fold")
    end)
end

MultiplayerRoomInvitationCtrl.PlayAnimationOut = HL.Override(HL.Opt(HL.Number)) << function(self, outCompleteActionType)
    self.m_foldCoroutine = self:_ClearCoroutine(self.m_foldCoroutine)
    MultiplayerRoomInvitationCtrl.Super.PlayAnimationOut(self, outCompleteActionType)
end

MultiplayerRoomInvitationCtrl._OnInviteBtnClick = HL.Method() << function(self)
    if self.m_waitingCancel then
        return
    end
    if not MultiplayerUtils.canShowRoomInvitationNotice() then
        self:_CloseSelf()
        return
    end

    local status = GameInstance.player.multiplayerMatchSystem.quickStatus
    if status.isMatching then
        self.m_waitingCancel = true
        self.m_pendingChatRoleId = self.m_chatRoleId
        GameInstance.player.multiplayerMatchSystem:SendQuickMatchCancelReq()
        self.m_cancelTimeoutTimerId = self:_StartTimer(CANCEL_REQUEST_TIMEOUT_SECONDS, function()
            self.m_waitingCancel = false
            self.m_pendingChatRoleId = 0
            self.m_cancelTimeoutTimerId = -1
        end, true)
        return
    end

    self:_OpenFriendChat(self.m_chatRoleId)
end

MultiplayerRoomInvitationCtrl._OnQuickMatchCancelRsp = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if not self.m_waitingCancel then
        return
    end

    if self.m_cancelTimeoutTimerId >= 0 then
        self.m_cancelTimeoutTimerId = self:_ClearTimer(self.m_cancelTimeoutTimerId)
    end
    local chatRoleId = self.m_pendingChatRoleId
    self.m_waitingCancel = false
    self.m_pendingChatRoleId = 0
    Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_QUICK_MATCH_CANCELLED_TOAST)
    self:_OpenFriendChat(chatRoleId)
end

MultiplayerRoomInvitationCtrl._OpenFriendChat = HL.Method(HL.Number) << function(self, chatRoleId)
    PhaseManager:OpenPhase(PhaseId.SNS, {
        roleId = chatRoleId,
    })
end

MultiplayerRoomInvitationCtrl._OnTopPhaseChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if not MultiplayerUtils.canShowRoomInvitationNotice() then
        self:_CloseSelf()
    else
        self:_OnPanelOrderChanged()
    end
end

MultiplayerRoomInvitationCtrl._OnPanelOrderChanged = HL.Method() << function(self)
    if not MultiplayerUtils.canShowRoomInvitationNotice() then
        return
    end

    local order = self:GetSortingOrder()
    for _, panelId in ipairs(INVITATION_BASE_PANEL_IDS) do
        if UIManager:IsShow(panelId) and UIManager:GetPanelOrder(panelId) > order then
            
            self:ToTop()
            return
        end
    end
end

MultiplayerRoomInvitationCtrl._CloseSelf = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:PlayAnimationOutAndClose()
end

HL.Commit(MultiplayerRoomInvitationCtrl)
