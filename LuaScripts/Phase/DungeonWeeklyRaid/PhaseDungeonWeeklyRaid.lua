
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.DungeonWeeklyRaid

















PhaseDungeonWeeklyRaid = HL.Class('PhaseDungeonWeeklyRaid', phaseBase.PhaseBase)


PhaseDungeonWeeklyRaid.m_panelStack = HL.Field(HL.Forward("Stack"))






PhaseDungeonWeeklyRaid.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INTERACT_WEEK_RAID_ENTRY] = { "_OnInteractWeekRaidEntry", false },
    [MessageConst.ON_WEEKLY_RAID_ENTER] = { "_OnWeekRaidGameEntry", false },
    [MessageConst.ON_WEEKLY_RAID_QUIT] = { "_OnWeekRaidGameQuit", false },
}


PhaseDungeonWeeklyRaid._OnInteractWeekRaidEntry = HL.StaticMethod() << function()
    PhaseManager:OpenPhase(PhaseId.CharFormation, { weekRaidArg = {} })
end


PhaseDungeonWeeklyRaid._OnWeekRaidGameEntry = HL.StaticMethod() << function()
    UIManager:ToggleBlockObtainWaysJump("WeeklyRaidGame", true, true)
end


PhaseDungeonWeeklyRaid._OnWeekRaidGameQuit = HL.StaticMethod() << function()
    UIManager:ToggleBlockObtainWaysJump("WeeklyRaidGame", false, true)
end




PhaseDungeonWeeklyRaid._OnInit = HL.Override() << function(self)
    self.m_panelStack = require_ex("Common/Utils/DataStructure/Stack")()
    PhaseDungeonWeeklyRaid.Super._OnInit(self)
end









PhaseDungeonWeeklyRaid.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseDungeonWeeklyRaid._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local panelId = PanelId.RaidMain
    if self.arg then
        if self.arg.strPanelId then
            panelId = PanelId[self.arg.strPanelId]
        elseif self.arg.panelId then
            panelId = self.arg.panelId
        end
    end
    self:TryOpenPanel(panelId, self.arg)
end





PhaseDungeonWeeklyRaid._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDungeonWeeklyRaid._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDungeonWeeklyRaid._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end







PhaseDungeonWeeklyRaid.TryOpenPanel = HL.Method(HL.Number, HL.Opt(HL.Table)) << function(self, panelId, args)
    if self.m_panelStack:Contains(panelId) then
        logger.warning("PhaseDungeonWeeklyRaid.TryOpenPanel: 面板已打开，无需重复打开，panelId: " .. tostring(panelId))
        return
    end
    self:CreateOrShowPhasePanelItem(panelId, args)
    self.m_panelStack:Push(panelId)
end



PhaseDungeonWeeklyRaid.TryCloseTopPanel = HL.Method() << function(self)
    if self.m_panelStack:Count() == 1 then
        PhaseManager:PopPhase(PHASE_ID)
        local panelId = self.m_panelStack:Pop()
        Notify(MessageConst.DIALOG_CLOSE_UI, {panelId, PHASE_ID, 0})
        return
    end

    local panelId = self.m_panelStack:Pop()
    local phaseItem = self:_GetPanelPhaseItem(panelId)
    if phaseItem then
        phaseItem.uiCtrl:PlayAnimationOutWithCallback(function()
            self:RemovePhasePanelItem(phaseItem)
        end)
    end
end





PhaseDungeonWeeklyRaid._OnActivated = HL.Override() << function(self)
end



PhaseDungeonWeeklyRaid._OnDeActivated = HL.Override() << function(self)
end



PhaseDungeonWeeklyRaid._OnDestroy = HL.Override() << function(self)
    PhaseDungeonWeeklyRaid.Super._OnDestroy(self)
end




HL.Commit(PhaseDungeonWeeklyRaid)

