local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PHASE_ID = PhaseId.InventoryMushroom

InventoryMushroomCtrl = HL.Class('InventoryMushroomCtrl', uiCtrl.UICtrl)


InventoryMushroomCtrl.s_messages = HL.StaticField(HL.Table) << {}

InventoryMushroomCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local closeFunc = function()
        self:_Close()
    end
    self.view.closeBtn.onClick:AddListener(closeFunc)
    self:BindInputPlayerAction("close_inventory", closeFunc)
    self:BindInputPlayerAction("common_cancel", closeFunc)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

InventoryMushroomCtrl._Close = HL.Method() << function(self)
    if PhaseManager:GetTopPhaseId() == PHASE_ID then
        PhaseManager:PopPhase(PHASE_ID)
    else
        self:Close()
    end
end

HL.Commit(InventoryMushroomCtrl)
