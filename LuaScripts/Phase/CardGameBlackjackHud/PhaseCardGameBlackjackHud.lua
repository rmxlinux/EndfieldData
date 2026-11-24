local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.CardGameBlackjackHud

PhaseCardGameBlackjackHud = HL.Class('PhaseCardGameBlackjackHud', phaseBase.PhaseBase)




PhaseCardGameBlackjackHud.s_messages = HL.StaticField(HL.Table) << {
    
}

PhaseCardGameBlackjackHud.m_hudPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseCardGameBlackjackHud.Open = HL.StaticMethod(HL.Opt(HL.Table)) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg)
end



PhaseCardGameBlackjackHud._OnInit = HL.Override() << function(self)
    PhaseCardGameBlackjackHud.Super._OnInit(self)
end




PhaseCardGameBlackjackHud.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseCardGameBlackjackHud._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local scene = LuaSystemManager.cardGameBlackjackSystem.scene
    if scene and not string.isEmpty(scene.uiSceneId) then
        UISceneManager:Activate(scene.uiSceneId)
    end
end

PhaseCardGameBlackjackHud._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseCardGameBlackjackHud._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseCardGameBlackjackHud._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end






PhaseCardGameBlackjackHud._InitAllPhaseItems = HL.Override() << function(self)
    PhaseCardGameBlackjackHud.Super._InitAllPhaseItems(self)
    self.m_hudPanel = self:_GetPanelPhaseItem(PanelId.CardGameBlackjackHud)
end

PhaseCardGameBlackjackHud._OnActivated = HL.Override() << function(self)
    
    UIManager:Hide(PanelId.Touch)
end

PhaseCardGameBlackjackHud._OnDeActivated = HL.Override() << function(self)
end

PhaseCardGameBlackjackHud._OnDestroy = HL.Override() << function(self)
    UIManager:Show(PanelId.Touch)
    PhaseCardGameBlackjackHud.Super._OnDestroy(self)
end

PhaseCardGameBlackjackHud.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = PhaseCardGameBlackjackHud.Super.GetCurStateArg(self)
    arg.recoverState = self.m_hudPanel.uiCtrl:GetRecoverStateArg()
    return arg
end



HL.Commit(PhaseCardGameBlackjackHud)
