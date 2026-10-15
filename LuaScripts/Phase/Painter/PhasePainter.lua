
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Painter
PhasePainter = HL.Class('PhasePainter', phaseBase.PhaseBase)





PhasePainter.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.OPEN_PAINTER_PANEL] = { '_OnStartPaint', false },

    [MessageConst.ON_PAINTING_SCROLL_SCREEN_EFFECT_FADE_IN_FINISH] = { '_OnScrollFadeFinish', true },
}


PhasePainter._OnStartPaint = HL.StaticMethod(HL.Any) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg)
    AudioManager.PostEvent("au_switch_int_rtpc_ink_state_in")
end



PhasePainter._OnInit = HL.Override() << function(self)
    PhasePainter.Super._OnInit(self)
end

PhasePainter._OnScrollFadeFinish = HL.Method(HL.Any) << function(self, arg)
    local comp, isEnter, isFadeIn = unpack(arg)
    if not isEnter then
        PhaseManager:PopPhase(PHASE_ID)
        AudioManager.PostEvent("au_switch_int_rtpc_ink_state_out")
    end
end




PhasePainter.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhasePainter._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)

end

PhasePainter._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)

end

PhasePainter._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhasePainter._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end






PhasePainter._OnActivated = HL.Override() << function(self)
    UIManager:Open(PanelId.Painter, self.arg)
end

PhasePainter._OnDeActivated = HL.Override() << function(self)
    local _, ctrl = UIManager:IsOpen(PanelId.Painter)
    
    if ctrl and not InputManagerInst.inChangingInputDevice then
        ctrl:PlayAnimationOutAndClose()
    else
        UIManager:Close(PanelId.Painter)
    end
end

PhasePainter._OnDestroy = HL.Override() << function(self)
    PhasePainter.Super._OnDestroy(self)
end



PhasePainter.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = self.arg and lume.deepCopy(self.arg) or {}
    arg.phase = nil
    return arg
end


HL.Commit(PhasePainter)

