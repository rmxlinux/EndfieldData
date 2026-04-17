
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.SpaceshipControlCenter



PhaseSpaceshipControlCenter = HL.Class('PhaseSpaceshipControlCenter', phaseBase.PhaseBase)






PhaseSpaceshipControlCenter.s_messages = HL.StaticField(HL.Table) << {

}



PhaseSpaceshipControlCenter._OnActivated = HL.Override() << function(self)
    local controllerPanel = self.m_panel2Item[PanelId.SpaceshipControlCenter].uiCtrl
    controllerPanel.view.ssBacklogNode:InitSSBacklogNode()
    if not InputManagerInst.controllerNaviManager.curTarget then
        controllerPanel:SetNaviTarget()
    end
end


HL.Commit(PhaseSpaceshipControlCenter)
