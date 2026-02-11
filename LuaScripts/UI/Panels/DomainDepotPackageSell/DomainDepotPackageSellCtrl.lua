local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainDepotPackageSell












DomainDepotPackageSellCtrl = HL.Class('DomainDepotPackageSellCtrl', uiCtrl.UICtrl)


DomainDepotPackageSellCtrl.m_buyerInfos = HL.Field(HL.Table)


DomainDepotPackageSellCtrl.GetCell = HL.Field(HL.Function)


DomainDepotPackageSellCtrl.m_selectId = HL.Field(HL.String) << ""


DomainDepotPackageSellCtrl.m_domainDepotId = HL.Field(HL.String) << ""






DomainDepotPackageSellCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





DomainDepotPackageSellCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.closeBtn.onClick:RemoveAllListeners()
    self.view.closeBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_SELL_PANEL)
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.view.confirmBtn.onClick:RemoveAllListeners()
    self.view.confirmBtn.onClick:AddListener(function()
        if self.m_selectId == nil or self.m_selectId == "" then
            logger.error("DomainDepotPackageSellCtrl.OnCreate: No buyer selected")
            return
        end

        if GameInstance.player.domainDepotSystem.m_currAcceptedRemoteDeliver ~= nil or GameInstance.player.domainDepotSystem.deliverInstId ~= 0 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_DOMAIN_DEPOT_CANNOT_DELIVER_TIP)
            return
        end

        GameInstance.player.domainDepotSystem:SendRequestDomainDepotDeliver(self.m_domainDepotId, self.m_selectId)
    end)

    if arg == nil or arg.domainDepotId == nil then
        logger.error("DomainDepotPackageSellCtrl.OnCreate: Missing domainDepotId in arg")
        return
    end

    self.m_domainDepotId = arg.domainDepotId

    local moneyId, maxCount = DomainDepotUtils.GetMoneyId(self.m_domainDepotId)
    self.view.domainTopMoneyTitle:InitDomainTopMoneyTitle(moneyId, maxCount)
    local moneyData = Tables.itemTable:GetValue(moneyId)
    self.view.iconMoney:LoadSprite(UIConst.UI_SPRITE_WALLET, moneyData.iconId)

    self.m_buyerInfos = DomainDepotUtils.GetBuyerInfo(self.m_domainDepotId)
    
    self.m_selectId = self.m_buyerInfos[1].id

    local deliverInfo = GameInstance.player.domainDepotSystem:GetDomainDepotDeliverInfoByDepotId(self.m_domainDepotId)

    local packConfig = Tables.domainDepotDeliverPackTypeTable:GetValue(deliverInfo.deliverPackType)
    local itemConfig = Tables.domainDepotDeliverItemTypeTable:GetValue(deliverInfo.itemType)
    self.view.titleTxt:CombineStringWithLanguageSpilt(packConfig.deliveryDesc, itemConfig.deliveryDesc)

    self.view.valueTxt.text = deliverInfo.originalPrice

    self.GetCell = UIUtils.genCachedCellFunction(self.view.goodsScrollView)

    self.view.goodsScrollView.onUpdateCell:RemoveAllListeners()
    self.view.goodsScrollView.onUpdateCell:AddListener(function(object, index)
        local cell = self.GetCell(object)
        cell:InitDomainDepotPriceListCell(self.m_domainDepotId, self.m_buyerInfos[LuaIndex(index)], function(info)
            self.m_selectId = info.id
            self:OnCellChange()
        end)
    end)

    DomainDepotUtils.UpdateReduceView(self.view.packageDamageReasonView,GameInstance.player.domainDepotSystem:GetDomainDepotDeliverItemType(self.m_domainDepotId))

    self.view.goodsScrollView:UpdateCount(4, true)

    self.view.goodsScrollViewSelectableNaviGroup:NaviToThisGroup()
    self:OnCellChange()

    if GameInstance.player.domainDepotSystem.deliverInstId ~= 0 then
        self.view.lockedRoot.gameObject:SetActiveIfNecessary(true)
        self.view.taskRoot.gameObject:SetActiveIfNecessary(false)
        self.view.confirmBtn.gameObject:SetActiveIfNecessary(false)
    else
        self.view.lockedRoot.gameObject:SetActiveIfNecessary(false)
        self.view.taskRoot.gameObject:SetActiveIfNecessary(true)
        self.view.confirmBtn.gameObject:SetActiveIfNecessary(true)
    end
end



DomainDepotPackageSellCtrl.OnCellChange = HL.Method() << function(self)
    
    for i = 1, 4 do
        local fCell = self:_GetCellByIndex(i)
        if fCell then
            fCell:SetCellState(fCell.m_info and fCell.m_info.id == self.m_selectId)
            if fCell.m_info and fCell.m_info.id == self.m_selectId then
                self.view.incomeNumTxt.text = math.floor(fCell.m_info.reward.count * Tables.domainDepotConst.depositRatio / 100)
            end
        end
    end
end



DomainDepotPackageSellCtrl.OnSelectBuyerEnd = HL.Method() << function(self)
    
    
    
    
end




DomainDepotPackageSellCtrl._GetCellByIndex = HL.Method(HL.Number).Return(HL.Forward("DomainDepotPriceListCell")) << function(self, cellIndex)
    local go = self.view.goodsScrollView:Get(CSIndex(cellIndex))
    local cell = nil
    if go then
        cell = self.GetCell(go)
    end

    return cell
end



DomainDepotPackageSellCtrl.OnShow = HL.Override() << function(self)
    self.view.goodsScrollViewSelectableNaviGroup:NaviToThisGroup()
end








HL.Commit(DomainDepotPackageSellCtrl)
