
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.DomainMain
PhaseDomainMain = HL.Class('PhaseDomainMain', phaseBase.PhaseBase)







PhaseDomainMain.s_messages = HL.StaticField(HL.Table) << {
    
}


PhaseDomainMain._OnInit = HL.Override() << function(self)
    PhaseDomainMain.Super._OnInit(self)
end




PhaseDomainMain._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDomainMain._OnRefresh = HL.Override() << function(self)
end

PhaseDomainMain._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDomainMain._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDomainMain.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseDomainMain._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDomainMain.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if self.panels[1] ~= nil then
        local panelId = self.panels[1]
        if self.m_panel2Item[panelId] ~= nil then
            
            local uiCtrl = self.m_panel2Item[panelId].uiCtrl
            local arg = uiCtrl:GetCurPhaseStateArg()
            return arg
        end
    end
    return nil
end






PhaseDomainMain._OnActivated = HL.Override() << function(self)
end

PhaseDomainMain._OnDeActivated = HL.Override() << function(self)
end

PhaseDomainMain._OnDestroy = HL.Override() << function(self)
    PhaseDomainMain.Super._OnDestroy(self)
end




HL.Commit(PhaseDomainMain)
