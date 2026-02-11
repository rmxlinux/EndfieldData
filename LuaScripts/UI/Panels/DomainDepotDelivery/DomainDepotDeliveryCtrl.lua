local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainDepotDelivery








DomainDepotDeliveryCtrl = HL.Class('DomainDepotDeliveryCtrl', uiCtrl.UICtrl)


DomainDepotDeliveryCtrl.m_getCellFunc = HL.Field(HL.Function)






DomainDepotDeliveryCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DOMAIN_DEPOT_DELIVERY_SYNC] = 'OnSync',
}





DomainDepotDeliveryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.refreshBtn.onClick:RemoveAllListeners()
    self.view.refreshBtn.onClick:AddListener(function()
        GameInstance.player.domainDepotSystem:SendSyncDomainDepotDeliverDelegate()
        self.view.refreshBtn.gameObject:SetActive(false)
        self.view.countTimeNode.gameObject:SetActive(true)
        self.view.countDownText:InitCountDownText(5 + DateTimeUtils.GetCurrentTimestampBySeconds(), function()
            self.view.refreshBtn.gameObject:SetActive(true)
            self.view.countTimeNode.gameObject:SetActive(false)
        end, function(sec)
            return UIUtils.getSecondsLeftTime(sec) .. Language.LUA_DOMAIN_DEPOT_DELIVERY_REFRESH_COUNTDOWN
        end)
    end)

    GameInstance.player.domainDepotSystem:SendSyncDomainDepotDeliverDelegate()

    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:RemoveAllListeners()
    self.view.scrollList.onUpdateCell:AddListener(function(object, index)
        local cell = self.m_getCellFunc(object)
        cell:InitDomainDepotDeliveryCell(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList[index])
    end)

    
    self.view.times1Txt.text = GameInstance.player.domainDepotSystem.dailyTakeDelegateCount
    self.view.times1Txt.color = GameInstance.player.domainDepotSystem.dailyTakeDelegateCount == 3 and self.view.config.FULL_COLOR or self.view.config.NORMAL_COLOR
    self.view.times2Txt.text = Tables.domainDepotConst.dailyTakeDelegateCount
    for i = 1, Tables.domainDepotConst.dailyTakeDelegateCount do
        self.view['state' .. i]:SetState(GameInstance.player.domainDepotSystem.dailyTakeDelegateCount == 3 and "red" or i <= GameInstance.player.domainDepotSystem.dailyTakeDelegateCount and "have" or "use")
    end

    self.view.tipsButton.onClick:RemoveAllListeners()
    self.view.tipsButton.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "domain_depot_delivery")
    end)

    
end



DomainDepotDeliveryCtrl.OnSync = HL.Method() << function(self)
    self.view.times1Txt.text = GameInstance.player.domainDepotSystem.dailyTakeDelegateCount
    self.view.scrollList:UpdateCount(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count)
    self.view.selectableNaviGroup:NaviToThisGroup()
    self.view.emptyNode.gameObject:SetActive(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count == 0)
end



DomainDepotDeliveryCtrl.OnShow = HL.Override() << function(self)
    if GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count ~= 0 then
        self:OnSync()
    end
end




DomainDepotDeliveryCtrl.OnHide = HL.Override() << function(self)
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local cell = self.m_getCellFunc(obj)
        cell.view.animationWrapper:PlayOutAnimation()
    end)
end




HL.Commit(DomainDepotDeliveryCtrl)
