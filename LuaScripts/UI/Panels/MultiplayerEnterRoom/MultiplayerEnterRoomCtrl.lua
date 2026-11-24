local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerEnterRoom


MultiplayerEnterRoomCtrl = HL.Class('MultiplayerEnterRoomCtrl', uiCtrl.UICtrl)






MultiplayerEnterRoomCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_UI_PHASE_OPENED] = '_OnPhaseOpened',
}


MultiplayerEnterRoomCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local roomCode = arg and arg.roomCode
    self:_InitUI()
    
    self.view.multiplayerEnterRoomNode:InitMultiplayerEnterRoomNode({
        roomCode = roomCode,
        onCreateClick = function()
            self:_OnCreateClick()
        end,
    })
    self:_InitController()
    LuaSystemManager.ps5MultiplayerSystem:TryShowPSOnlyNotice()
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
end

MultiplayerEnterRoomCtrl.OnClose = HL.Override() << function(self)
    LuaSystemManager.ps5MultiplayerSystem:TryClosePSOnlyNotice()
end


MultiplayerEnterRoomCtrl.GetRecoverState = HL.Method().Return(HL.Table) << function(self)
    local node = self.view.multiplayerEnterRoomNode
    return {
        roomCode = node:GetRoomCode(),
    }
end



MultiplayerEnterRoomCtrl._InitUI = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.closeBtn.onClick:AddListener(function()
        self:_CloseSelf()
    end)
    self.view.hotArea.onClick:AddListener(function()
        self:_CloseSelf()
    end)
end

MultiplayerEnterRoomCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local node = self.view.multiplayerEnterRoomNode
    local naviTarget = string.isEmpty(node.view.inputField.text) and node.view.createRoom or node.view.joinRoom
    self:SetNaviTarget(naviTarget)
end

MultiplayerEnterRoomCtrl._CloseSelf = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end


MultiplayerEnterRoomCtrl._OnPhaseOpened = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if PhaseManager:GetTopPhaseId() ~= PhaseId.MultiplayerMain then
        self:Close()
    end
end


MultiplayerEnterRoomCtrl._OnCreateClick = HL.Method() << function(self)
    local opened = PhaseManager:OpenPhase(PhaseId.MultiplayerMatch, {
        mode = MultiplayerConst.EMatchMode.CreateRoom,
    })
    if opened then
        self:Close()
    end
end



HL.Commit(MultiplayerEnterRoomCtrl)
