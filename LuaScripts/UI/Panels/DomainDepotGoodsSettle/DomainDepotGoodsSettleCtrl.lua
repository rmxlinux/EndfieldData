local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainDepotGoodsSettle






DomainDepotGoodsSettleCtrl = HL.Class('DomainDepotGoodsSettleCtrl', uiCtrl.UICtrl)


DomainDepotGoodsSettleCtrl.m_domainDepotId = HL.Field(HL.String) << ""


DomainDepotGoodsSettleCtrl.m_deliverInstId = HL.Field(HL.Number) << 0






DomainDepotGoodsSettleCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





DomainDepotGoodsSettleCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.bgBtn.onClick:RemoveAllListeners()
    self.view.bgBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_SETTLE_PANEL)
    end)

    if arg == nil or arg.deliverInstId == nil then
        logger.error("DomainDepotGoodsSettleCtrl.OnCreate: Missing deliverInstId in arg")
        return
    end
    self.m_deliverInstId = arg.deliverInstId
    local deliverInfo = GameInstance.player.domainDepotSystem:GetDomainDepotDeliverInfoByInstId(self.m_deliverInstId)
    self.m_domainDepotId = deliverInfo.domainDepotId
    DomainDepotUtils.UpdateReduceView(self.view.packageDamageReasonView, deliverInfo.itemType)

    local deposit = DomainDepotUtils.GetDomainDepotDeposit(self.m_deliverInstId)
    self.view.bottomStateNode:SetState(arg.stateName)
    self.view.item:InitItem({ id = DomainDepotUtils.GetMoneyId(self.m_domainDepotId), count = deposit }, true)
    
    
    
    
    
    
    self.view.bgBtn.gameObject:SetActive(true)
end


HL.Commit(DomainDepotGoodsSettleCtrl)
