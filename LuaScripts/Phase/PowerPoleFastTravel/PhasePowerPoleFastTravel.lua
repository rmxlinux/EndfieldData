local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.PowerPoleFastTravel














PhasePowerPoleFastTravel = HL.Class('PhasePowerPoleFastTravel', phaseBase.PhaseBase)

local ReservePanelIds = {  
    PanelId.Joystick,
    PanelId.LevelCamera,
    PanelId.GeneralTracker,
    PanelId.WeeklyRaidTaskTrackHud,
    PanelId.MiniMap,
}


PhasePowerPoleFastTravel.m_fastTravelPanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhasePowerPoleFastTravel.m_currentLogicId = HL.Field(HL.Any) << 0






PhasePowerPoleFastTravel.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.TRAVEL_POLE_ENTER_TRAVEL_MODE] = { '_OnEnterPowerPoleFastTravelMode', false },
}




PhasePowerPoleFastTravel._OnInit = HL.Override() << function(self)
    PhasePowerPoleFastTravel.Super._OnInit(self)
end









PhasePowerPoleFastTravel.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        if anotherPhaseId == PhaseId.Level then
            Notify(MessageConst.SET_PHASE_LEVEL_TRANSITION_RESERVE_PANELS, ReservePanelIds)
        end
    end
end





PhasePowerPoleFastTravel._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)

end





PhasePowerPoleFastTravel._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhasePowerPoleFastTravel._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhasePowerPoleFastTravel._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args) end








PhasePowerPoleFastTravel._OnActivated = HL.Override() << function(self)
    if GameWorld.gameMechManager.travelPoleBrain:CanOpenMiniMap() then
        self.arg[1] = self.m_currentLogicId or self.arg[1]  
    end
   self.m_fastTravelPanelItem = self:CreatePhasePanelItem(PanelId.PowerPoleFastTravel, self.arg)
   GameWorld.gameMechManager.travelPoleBrain:OnPanelOpened(self.arg[1])
end



PhasePowerPoleFastTravel._OnDeActivated = HL.Override() << function(self)
    self:RemovePhasePanelItem(self.m_fastTravelPanelItem)
    self.m_fastTravelPanelItem = nil
end



PhasePowerPoleFastTravel._OnDestroy = HL.Override() << function(self)
    PhasePowerPoleFastTravel.Super._OnDestroy(self)
end





PhasePowerPoleFastTravel._OnEnterPowerPoleFastTravelMode = HL.StaticMethod(HL.Table) << function(args)
    local logicId, openFailedCallback = unpack(args)
    if PhaseManager:GetTopPhaseId() ~= PhaseId.Level then
        openFailedCallback()
        return
    end

    local openSuccess = PhaseManager:OpenPhase(PhaseId.PowerPoleFastTravel, args)
    if not openSuccess then
        openFailedCallback()
    end
end



PhasePowerPoleFastTravel.SaveCurrentLogicId = HL.Method() << function(self)
    if self.m_fastTravelPanelItem and self.m_fastTravelPanelItem.uiCtrl then
        self.m_currentLogicId = self.m_fastTravelPanelItem.uiCtrl.m_currentLogicId
    else
        self.m_currentLogicId = nil
    end
end

HL.Commit(PhasePowerPoleFastTravel)

