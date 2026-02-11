local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.FacBuildListSelect












PhaseFacBuildListSelect = HL.Class('PhaseFacBuildListSelect', phaseBase.PhaseBase)

local ReservePanelIds = {  
    PanelId.FacQuickBar,
    PanelId.FacHudBottomMask,
}






PhaseFacBuildListSelect.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.OPEN_FAC_BUILD_MODE_SELECT] = { '_OnOpenFacBuildModeSelect', false },
}




PhaseFacBuildListSelect._OnInit = HL.Override() << function(self)
    PhaseFacBuildListSelect.Super._OnInit(self)
end









PhaseFacBuildListSelect.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        if anotherPhaseId == PhaseId.Level then
            Notify(MessageConst.SET_PHASE_LEVEL_TRANSITION_RESERVE_PANELS, ReservePanelIds)
        end
    end
end





PhaseFacBuildListSelect._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFacBuildListSelect._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFacBuildListSelect._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFacBuildListSelect._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args) end








PhaseFacBuildListSelect._OnActivated = HL.Override() << function(self)
end



PhaseFacBuildListSelect._OnDeActivated = HL.Override() << function(self)
end



PhaseFacBuildListSelect._OnDestroy = HL.Override() << function(self)
    PhaseFacBuildListSelect.Super._OnDestroy(self)
end





PhaseFacBuildListSelect._OnOpenFacBuildModeSelect = HL.StaticMethod(HL.Opt(HL.Any)) << function(arg)
    if PhaseManager:CheckCanOpenPhaseAndToast(PHASE_ID, arg) then
        PhaseManager:OpenPhase(PHASE_ID, arg)
    end
end

HL.Commit(PhaseFacBuildListSelect)
