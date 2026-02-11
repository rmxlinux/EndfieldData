
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GachaWeaponInsufficient




GachaWeaponInsufficientCtrl = HL.Class('GachaWeaponInsufficientCtrl', uiCtrl.UICtrl)







GachaWeaponInsufficientCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





GachaWeaponInsufficientCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.mask.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.confirmButton.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.exploreEntranceBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        PhaseManager:GoToPhase(PhaseId.GachaPool)
    end)
    self.view.battlePassEntranceBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        PhaseManager:GoToPhase(PhaseId.BattlePass)
    end)
    self.view.giftPackEntranceBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        PhaseManager:GoToPhase(PhaseId.CashShop, {
            shopGroupId = CashShopConst.CashShopCategoryType.Pack,
            cashShopId = Tables.CashShopConst.WeaponCashShopId,
        })
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
        self.view.inputGroup.groupId,
    })
end











HL.Commit(GachaWeaponInsufficientCtrl)
