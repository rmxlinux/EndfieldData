
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Snapshot











PhaseSnapshot = HL.Class('PhaseSnapshot', phaseBase.PhaseBase)






PhaseSnapshot.s_messages = HL.StaticField(HL.Table) << {
    
}





PhaseSnapshot._OnInit = HL.Override() << function(self)
    PhaseSnapshot.Super._OnInit(self)
end









PhaseSnapshot.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseSnapshot._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    
    local snapshotCameraCtrl = UIManager:Open(PanelId.SnapshotCamera)
    local arg = {
        cameCtrl = snapshotCameraCtrl,
    }
    if self.arg then
        arg.identifyGroupId = self.arg.identifyGroupId
        arg.focus = self.arg.focus
        arg.thirdPerson = self.arg.thirdPerson
        arg.camInitRotate = self.arg.camInitRotate
        arg.forbidMoveOrRotateCam = self.arg.forbidMoveOrRotateCam
        arg.onOpenCallBack = self.arg.onOpenCallBack
    end
    UIManager:Open(PanelId.Snapshot, arg)
    UIManager:Open(PanelId.SnapshotJoystick, snapshotCameraCtrl)
end





PhaseSnapshot._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    UIManager:Close(PanelId.Snapshot)
    UIManager:Close(PanelId.SnapshotJoystick)
    UIManager:Close(PanelId.SnapshotCamera)
end





PhaseSnapshot._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseSnapshot._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end








PhaseSnapshot._OnActivated = HL.Override() << function(self)
end



PhaseSnapshot._OnDeActivated = HL.Override() << function(self)
end



PhaseSnapshot._OnDestroy = HL.Override() << function(self)
    PhaseSnapshot.Super._OnDestroy(self)
end




HL.Commit(PhaseSnapshot)

