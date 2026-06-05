
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Snapshot















PhaseSnapshot = HL.Class('PhaseSnapshot', phaseBase.PhaseBase)






PhaseSnapshot.s_messages = HL.StaticField(HL.Table) << {
    
}



PhaseSnapshot.snapshotPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseSnapshot.snapshotCameraPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseSnapshot.snapshotJoystickPanel = HL.Field(HL.Forward("PhasePanelItem"))









PhaseSnapshot.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseSnapshot._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if not self.arg then
        self.arg = {}
    elseif type(self.arg) ~= "table" then
        
        self.arg = {
            identifyGroupId = self.arg.identifyGroupId,
            focus = self.arg.focus,
            thirdPerson = self.arg.thirdPerson,
            camInitRotate = self.arg.camInitRotate,
            forbidMoveOrRotateCam = self.arg.forbidMoveOrRotateCam,
            isFromInteractive = self.arg.isFromInteractive,
            onOpenCallBack = self.arg.onOpenCallBack,
        }
    end
    
    self.snapshotCameraPanel = self:CreatePhasePanelItem(PanelId.SnapshotCamera)
    self.snapshotPanel = self:CreatePhasePanelItem(PanelId.Snapshot, self.arg)
    self.snapshotJoystickPanel = self:CreatePhasePanelItem(PanelId.SnapshotJoystick)
    if self.snapshotPanel and self.snapshotPanel.uiCtrl and self.snapshotPanel.uiCtrl._SyncJoystickForbidState then
        self.snapshotPanel.uiCtrl:_SyncJoystickForbidState()
    end
end





PhaseSnapshot._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseSnapshot._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseSnapshot._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end









PhaseSnapshot._OnInit = HL.Override() << function(self)
    PhaseSnapshot.Super._OnInit(self)
end



PhaseSnapshot._OnActivated = HL.Override() << function(self)
end



PhaseSnapshot._OnDeActivated = HL.Override() << function(self)
end



PhaseSnapshot._OnDestroy = HL.Override() << function(self)
    PhaseSnapshot.Super._OnDestroy(self)
end



PhaseSnapshot.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = lume.deepCopy(self.arg or {})
    if self.snapshotPanel and self.snapshotPanel.uiCtrl and self.snapshotPanel.uiCtrl._CollectResumeState then
        arg.resumeState = self.snapshotPanel.uiCtrl:_CollectResumeState()
    end
    return arg
end




HL.Commit(PhaseSnapshot)

