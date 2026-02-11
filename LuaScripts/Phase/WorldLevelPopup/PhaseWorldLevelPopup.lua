local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.WorldLevelPopup















PhaseWorldLevelPopup = HL.Class('PhaseWorldLevelPopup', phaseBase.PhaseBase)






PhaseWorldLevelPopup.s_messages = HL.StaticField(HL.Table) << {
    
}


PhaseWorldLevelPopup.m_worldLevelPopup = HL.Field(HL.Forward("PhasePanelItem"))


PhaseWorldLevelPopup.m_worldLevelPreview = HL.Field(HL.Forward("PhasePanelItem"))




PhaseWorldLevelPopup._OnInit = HL.Override() << function(self)
    PhaseWorldLevelPopup.Super._OnInit(self)
end



PhaseWorldLevelPopup.OpenWorldLevelPopup = HL.Method() << function(self)
    self:RemovePhasePanelItemById(PanelId.WorldLevelTipsPopup)
    if self.m_worldLevelPopup == nil then
        self.m_worldLevelPopup = self:CreatePhasePanelItem(PanelId.WorldLevelPopup, { isUp = not GameInstance.player.adventure.isCurWorldLvMax })
    end
    self.m_worldLevelPopup.uiCtrl:Show()
end







PhaseWorldLevelPopup.OpenWorldLevelPreview = HL.Method(HL.Boolean, HL.Number, HL.Number, HL.Any) << function(self, isUp, lastLevel, currentLevel, textKeyTable)
    self:RemovePhasePanelItemById(PanelId.WorldLevelPopup)
    
    
    
    
end








PhaseWorldLevelPopup.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseWorldLevelPopup._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseWorldLevelPopup._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseWorldLevelPopup._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseWorldLevelPopup._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end








PhaseWorldLevelPopup._OnActivated = HL.Override() << function(self)
end



PhaseWorldLevelPopup._OnDeActivated = HL.Override() << function(self)
end



PhaseWorldLevelPopup._OnDestroy = HL.Override() << function(self)
    PhaseWorldLevelPopup.Super._OnDestroy(self)
end




HL.Commit(PhaseWorldLevelPopup)

