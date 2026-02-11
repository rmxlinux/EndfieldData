local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')











CashShopItem = HL.Class('CashShopItem', UIWidgetBase)


CashShopItem.m_info = HL.Field(HL.Any)


CashShopItem.m_isBox = HL.Field(HL.Boolean) << false


CashShopItem.m_hideRemainCount = HL.Field(HL.Boolean) << false


CashShopItem.m_hideNew = HL.Field(HL.Boolean) << false




CashShopItem._OnFirstTimeInit = HL.Override() << function(self)
    self.view.click.onClick:AddListener(function()
        if self.m_isBox then
            
            if not PhaseManager:CheckCanOpenPhase(PhaseId.GachaWeaponPool, {goodsData = self.m_info}, true) then
                logger.info("CashShopItem: CheckCanOpenPhase(PhaseId.GachaWeaponPool) false")
                return
            end
            PhaseManager:OpenPhase(PhaseId.GachaWeaponPool, {goodsData = self.m_info})
        else
            local uiCtrl = self:GetUICtrl()
            CashShopUtils.OpenShopDetailPanel(self.m_info, uiCtrl)
        end
    end)
    self:RegisterMessage(MessageConst.ON_WALLET_CHANGED, function(msgArg)
        self:UpdateMoney()
    end)
    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function(msgArg)
        self:UpdateMoney()
    end)
    self:RegisterMessage(MessageConst.ON_SHOP_FREQUENCY_LIMIT_CHANGE, function(msgArg)
        self:UpdateMoney()
    end)
    self:RegisterMessage(MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED, function(msgArg)
        self:_UpdateGuarantee()
    end)
    self:RegisterMessage(MessageConst.ON_SHOP_GOODS_SEE_GOODS_INFO_CHANGE, function(msgArg)
        self:_RefreshTag()
    end)
end




CashShopItem.UpdateMoney = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local goodsTableData = Tables.shopGoodsTable[self.m_info.goodsTemplateId]
    local moneyId = goodsTableData.moneyId
    local haveMoney = Utils.getItemCount(moneyId)
    local info = self.m_info
    local realPrice = 0
    local gachaWeaponGoodsCostInfo = CashShopUtils.TryGetBuyGachaWeaponGoodsCostInfo(info.shopId, info.goodsTemplateId)
    if gachaWeaponGoodsCostInfo and gachaWeaponGoodsCostInfo.ticketEnough then
        if not self.view.originalCostNode then
            logger.error("商品类型为为武器卡池，但ui prefab缺少originalPriceNode组件，将导致无法正确显示消耗抽卡券！")
        else
            self.view.originalCostNode.gameObject:SetActive(true)
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(false)
            end
            self.view.iconMoneyImg:LoadSprite(UIConst.UI_SPRITE_WALLET, gachaWeaponGoodsCostInfo.costTicketId)
            self.view.numberMoneyTxt.text = math.floor(gachaWeaponGoodsCostInfo.costTicketCount)
            self.view.numberMoneyTxt.color = self.view.config.WHITE_COLOR
            self.view.originalCostNode.originalCostImg:LoadSprite(UIConst.UI_SPRITE_WALLET, gachaWeaponGoodsCostInfo.costMoneyId)
            self.view.originalCostNode.originalCostNumTxt.text = gachaWeaponGoodsCostInfo.costMoneyCount
            self.view.moneyPriceMultiplyTxt.gameObject:SetActive(true)
        end
    else
        if gachaWeaponGoodsCostInfo and gachaWeaponGoodsCostInfo.costTicketId then
            self.view.iconMoneyImg:LoadSprite(UIConst.UI_SPRITE_WALLET, gachaWeaponGoodsCostInfo.costMoneyId)
        end
        if self.view.originalCostNode then
            self.view.originalCostNode.gameObject:SetActive(false)
        end
        if self.view.moneyPriceMultiplyTxt then
            self.view.moneyPriceMultiplyTxt.gameObject:SetActive(false)
        end
        if info.discount and info.discount < 1 then
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(true)
            end
            if self.view.bottomLayout then
                self.view.bottomLayout:SetState("Price")
            elseif self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.gameObject:SetActiveIfNecessary(true)
            end
            realPrice = CashShopUtils.GetDisplayPrice(goodsTableData.price, info.discount)
            self.view.numberMoneyTxt.text = realPrice
            if self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.text = goodsTableData.price
            end
            if self.view.deco then
                self.view.deco.gameObject:SetActive(false)
            end
        else
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(false)
            end
            if self.view.bottomLayout then
                self.view.bottomLayout:SetState("empty")
            elseif self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.gameObject:SetActiveIfNecessary(false)
            end
            self.view.numberMoneyTxt.text = goodsTableData.price
            realPrice = goodsTableData.price
            if self.view.deco then
                self.view.deco.gameObject:SetActive(true)
            end
        end
        
        if realPrice > haveMoney then
            self.view.numberMoneyTxt.color = self.view.config.RED_COLOR
        else
            self.view.numberMoneyTxt.color = self.view.config.WHITE_COLOR
        end
    end

    local shopSystem = GameInstance.player.shopSystem
    local remainCount = shopSystem:GetRemainCountByGoodsId(info.shopId, info.goodsId)
    if self.view.stateController then
        if remainCount == 0 then
            self.view.stateController:SetState("SoldOutNode")
        else
            self.view.stateController:SetState("Normal")
        end
    elseif self.view.soldOutNode then
        self.view.soldOutNode.gameObject:SetActive(remainCount == 0)
    end

    self:_RefreshTag()
end






CashShopItem.InitCashShopItem = HL.Method(HL.Any, HL.Opt(HL.Boolean, HL.Boolean))
    << function(self, info, hideRemainCount, hideNew)
    self.m_info = info
    self:_FirstTimeInit()
    local shopSystem = GameInstance.player.shopSystem

    self.m_hideRemainCount = hideRemainCount or false
    self.m_hideNew = hideNew or false
    self:_RefreshTag()

    local goodsId = info.goodsId
    
    local goodsTableData = Tables.shopGoodsTable[info.goodsTemplateId]
    local moneyId = goodsTableData.moneyId
    
    local gachaWeaponGoodsCostInfo = CashShopUtils.TryGetBuyGachaWeaponGoodsCostInfo(info.shopId, info.goodsTemplateId)
    if gachaWeaponGoodsCostInfo and gachaWeaponGoodsCostInfo.ticketEnough then
        if not self.view.originalCostNode then
            logger.error("商品类型为为武器卡池，但ui prefab缺少originalPriceNode组件，将导致无法正确显示消耗抽卡券！")
        else
            self.view.originalCostNode.gameObject:SetActive(true)
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(false)
            end
            self.view.iconMoneyImg:LoadSprite(UIConst.UI_SPRITE_WALLET, gachaWeaponGoodsCostInfo.costTicketId)
            self.view.numberMoneyTxt.text = math.floor(gachaWeaponGoodsCostInfo.costTicketCount)
            self.view.numberMoneyTxt.color = self.view.config.WHITE_COLOR
            self.view.originalCostNode.originalCostImg:LoadSprite(UIConst.UI_SPRITE_WALLET, gachaWeaponGoodsCostInfo.costMoneyId)
            self.view.originalCostNode.originalCostNumTxt.text = gachaWeaponGoodsCostInfo.costMoneyCount
            self.view.moneyPriceMultiplyTxt.gameObject:SetActive(true)
        end
    else
        if self.view.originalCostNode then
            self.view.originalCostNode.gameObject:SetActive(false)
        end
        if self.view.moneyPriceMultiplyTxt then
            self.view.moneyPriceMultiplyTxt.gameObject:SetActive(false)
        end
        local haveMoney = Utils.getItemCount(moneyId)
        local realPrice = 0
        if info.discount and info.discount < 1 then
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(true)
            end
            if self.view.bottomLayout then
                self.view.bottomLayout:SetState("Price")
            elseif self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.gameObject:SetActiveIfNecessary(true)
            end
            realPrice = CashShopUtils.GetDisplayPrice(goodsTableData.price, info.discount)
            self.view.numberMoneyTxt.text = realPrice
            if self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.text = goodsTableData.price
            end
            if self.view.deco then
                self.view.deco.gameObject:SetActive(false)
            end
        else
            if self.view.moneyDecPriceItem then
                self.view.moneyDecPriceItem.gameObject:SetActive(false)
            end
            if self.view.bottomLayout then
                self.view.bottomLayout:SetState("empty")
            elseif self.view.numberMoneyGreyTxt then
                self.view.numberMoneyGreyTxt.gameObject:SetActiveIfNecessary(false)
            end
            self.view.numberMoneyTxt.text = goodsTableData.price
            realPrice = goodsTableData.price
            if self.view.deco then
                self.view.deco.gameObject:SetActive(true)
            end
        end

        if realPrice > haveMoney then
            self.view.numberMoneyTxt.color = self.view.config.RED_COLOR
        else
            self.view.numberMoneyTxt.color = self.view.config.WHITE_COLOR
        end

        local moneyItemData = Tables.itemTable:GetValue(moneyId)
        self.view.iconMoneyImg:LoadSprite(UIConst.UI_SPRITE_WALLET, moneyItemData.iconId)
    end
    
    local remainCount = shopSystem:GetRemainCountByGoodsId(info.shopId, goodsId)

    local itemId = nil
    local count = 0
    local itemData
    if string.isEmpty(goodsTableData.rewardId) then
        local weaponPool = Tables.gachaWeaponPoolTable[goodsTableData.weaponGachaPoolId]
        local weaponId = weaponPool.upWeaponIds[0]
        local _, weaponItemCfg = Tables.itemTable:TryGetValue(weaponId)
        itemId = weaponId
        if self.view.titleTxt then
            self.view.titleTxt.text = string.format(Language.LUA_SHOP_WEAPON_UP_TITLE,weaponItemCfg.name)
        end
        itemData = weaponItemCfg
        count = 1
        local rarity = weaponItemCfg.rarity

        
        if self.view.randomWeaponsTxt then
            self.view.randomWeaponsTxt.text = weaponPool.name
        end
        if self.view.itemIcon then
            self.view.itemIcon.icon:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, weaponPool.upWeaponIcon)
        end
        if self.view.multipleNumTxt then
            self.view.multipleNumTxt.text = 10  
        end
        if self.view.weaponLevelLayout then
            UIUtils.childrenArrayActive(self.view.weaponLevelLayout, rarity)
        end
        self.m_isBox = true
        self:_UpdateGuarantee()
    else
        local displayItem = UIUtils.getRewardFirstItem(goodsTableData.rewardId)
        itemId = displayItem.id
        count = displayItem.count
        

        local unlock = shopSystem:CheckGoodsUnlocked(goodsId)
        local stateCtrl = self.view.stateController
        if stateCtrl then
            if not unlock then
                stateCtrl:SetState("LockNode")
            elseif remainCount == 0 then
                stateCtrl:SetState("SoldOutNode")
            else
                stateCtrl:SetState("Normal")
            end
        elseif self.view.soldOutNode then
            self.view.soldOutNode.gameObject:SetActive(remainCount == 0)
        end

        _, itemData = Tables.itemTable:TryGetValue(itemId)
        if itemData == nil then
            logger.error(string.format("商店 %s 商品 %s 对应物品 %s 不存在", goodsTableData.shopId, goodsId, itemId))
            return
        end

        if self.view.rarityLineImg then
            UIUtils.setItemRarityImage(self.view.rarityLineImg, itemData.rarity)
            UIUtils.setItemRarityImage(self.view.rarityLineImg02, itemData.rarity)
        end

        self.view.image:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, itemData.iconId)
        self.view.randomWeaponsTxt.text = itemData.name

        if self.view.rarityLineImg then
            UIUtils.setItemRarityImage(self.view.rarityLineImg, itemData.rarity)
            UIUtils.setItemRarityImage(self.view.rarityLineImg02, itemData.rarity)
        end
    end

    if count ~= nil and count > 1 and self.view.numberTxt then
        self.view.numberTxt.text = "× " .. count
        self.view.number.gameObject:SetActiveIfNecessary(true)
    elseif self.view.numberTxt then
        self.view.number.gameObject:SetActiveIfNecessary(false)
    end
    if self.view.weaponDeco and itemData then
        self.view.weaponDeco.gameObject:SetActive(itemData.type == GEnums.ItemType.Weapon)
    end
end



CashShopItem._UpdateGuarantee = HL.Method() << function(self)
    if not self.m_isBox then
        return
    end

    local goodsTableData = Tables.shopGoodsTable[self.m_info.goodsTemplateId]
    local remainMustUp = CashShopUtils.GetRemainPoolGotCount(goodsTableData.weaponGachaPoolId)
    if self.view.guaranteeTextLayout then
        self.view.guaranteeTextLayout.guaranteeNumTxt.text = remainMustUp
        self.view.guaranteeTextLayout.guaranteeNumTxt.gameObject:SetActive(remainMustUp > 0)
        self.view.guaranteeTextLayout.guaranteeTxt.gameObject:SetActive(remainMustUp > 0)
        self.view.guaranteeTextLayout.restrictNode.gameObject:SetActive(remainMustUp > 0)
    end
end



CashShopItem._RefreshTag = HL.Method() << function(self)
    if self.view.cashShopItemTag then
        self.view.cashShopItemTag:InitCashShopItemTag({
            isShop = true,
            goodsData = self.m_info,
            hideRemainCount = self.m_hideRemainCount,
            hideNew = self.m_hideNew,
        })
    end
end

HL.Commit(CashShopItem)
return CashShopItem

