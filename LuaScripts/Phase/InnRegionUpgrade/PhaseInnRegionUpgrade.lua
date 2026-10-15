local phaseBase = require_ex('Phase/Core/PhaseBase')
local PANEL_ID = PanelId.InnRegionUpgrade

PhaseInnRegionUpgrade = HL.Class('PhaseInnRegionUpgrade', phaseBase.PhaseBase)

PhaseInnRegionUpgrade.s_messages = HL.StaticField(HL.Table) << {}

PhaseInnRegionUpgrade._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl:OnPhaseExit(fastMode)
    end
end

PhaseInnRegionUpgrade.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        local arg = ctrl:GetCurPhaseStateArg()
        if arg ~= nil then
            return lume.deepCopy(arg)
        end
    end
    return PhaseInnRegionUpgrade.Super.GetCurStateArg(self)
end

HL.Commit(PhaseInnRegionUpgrade)
