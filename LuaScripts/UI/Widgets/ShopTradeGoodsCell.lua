local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
























ShopTradeGoodsCell = HL.Class('ShopTradeGoodsCell', UIWidgetBase)


local refreshTimeInterval = 1


ShopTradeGoodsCell.m_info = HL.Field(HL.Table)


ShopTradeGoodsCell.m_tickKey = HL.Field(HL.Number) << -1


ShopTradeGoodsCell.m_nextRefreshTime = HL.Field(HL.Number) << 0






ShopTradeGoodsCell._OnFirstTimeInit = HL.Override() << function(self)
end



ShopTradeGoodsCell._OnEnable = HL.Override() << function(self)
    self.view.animationWrapper:PlayInAnimation()
    self:_StartTickRefreshTime()
end



ShopTradeGoodsCell._OnDisable = HL.Override() << function(self)
    self.view.animationWrapper:PlayOutAnimation()
    self:_EndTickRefreshTime()
end



ShopTradeGoodsCell._OnDestroy = HL.Override() << function(self)
    self.view.animationWrapper:ClearTween(false)
    self:_EndTickRefreshTime()
end





ShopTradeGoodsCell.InitShopTradeGoodsCellCommonMode = HL.Method(HL.Table) << function(self, info)
    self.m_info = info
    self:_FirstTimeInit()
    self.view.redDot:InitRedDot("ShopSeeGoodsInfo", { goodsId = info.goodsId })
    self:_UpdateReadInfo(info.goodsId)
    local leftSec = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(info.refreshType)
    
    self.view.basicStateCtrl:SetState("Common")
    self.view.selectCountStateCtrl:SetState("NoSelectCount")
    self.view.priceStateCtrl:SetState(info.discount == 0 and "Normal" or "HasDiscount")
    self:SetSelectState(false)
    
    self:_RefreshNextRefreshTime(leftSec)
    self:_RefreshRemainLimitCount(info.remainLimitCount)
    self:_RefreshItemUI(info)
    local discountTxt = string.format("-%.0f", info.discount * 100)
    self.view.discountTxt.text = discountTxt
    self.view.discountShadowTxt.text = discountTxt
    self.view.currentPriceTxt.text = UIUtils.getNumString(info.curPrice, true)
    self.view.originalPriceTxt.text = UIUtils.getNumString(info.originPrice, true)
    
    self.view.selectBtn.onClick:RemoveAllListeners()
    self.view.selectBtn.onClick:AddListener(function()
        local goodsData = GameInstance.player.shopSystem:GetShopGoodsData(info.shopId, info.goodsId)
        local uiCtrl = self:GetUICtrl()
        CashShopUtils.OpenShopDetailPanel(goodsData, uiCtrl)
    end)
    self.view.animationWrapper:PlayInAnimation()
end





ShopTradeGoodsCell.InitShopTradeGoodsCellRandomMode = HL.Method(HL.Table, HL.Boolean) << function(self, info, isMyPositionMode)
    self.m_info = info
    self:_FirstTimeInit()
    self.view.redDot:InitRedDot("ShopSeeGoodsInfo", { goodsId = info.goodsId })
    self:_UpdateReadInfo(info.goodsId)
    local curPrice
    local profitRatio
    local basicStateName
    if isMyPositionMode then
        basicStateName = "RandomMyPosition"
        curPrice = info.positionAvgPrice
        profitRatio = info.profitRatio
        self.view.refreshTimeStateCtrl:SetState("None")
    else
        basicStateName = "Random"
        curPrice = info.todayPrice
        profitRatio = info.priceDiffRatio
        local leftSec = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(info.refreshType)
        self:_RefreshNextRefreshTime(leftSec)
    end
    
    self.view.basicStateCtrl:SetState(basicStateName)
    self.view.selectCountStateCtrl:SetState("NoSelectCount")
    self.view.priceStateCtrl:SetState("Normal")
    self:SetSelectState(false)
    
    self:_RefreshRemainLimitCount(info.remainLimitCount)
    self:_RefreshItemUI(info)
    self:_RefreshProfitRatioUI(profitRatio)
    self.view.currentPriceTxt.text = UIUtils.getNumString(curPrice, true)
    
    self.view.selectBtn.onClick:RemoveAllListeners()
    self.view.selectBtn.onClick:AddListener(function()
        local goodsData = GameInstance.player.shopSystem:GetShopGoodsData(info.shopId, info.goodsId)
        UIManager:Open(PanelId.ShopTradeItem, {
            goodsData = goodsData,
            isDefaultSell = isMyPositionMode,
        })
    end)
    self.view.animationWrapper:PlayInAnimation()
end




ShopTradeGoodsCell.InitShopTradeGoodsCellFriendMode = HL.Method(HL.Table) << function(self, info)
    self.m_info = info
    self:_FirstTimeInit()
    self.view.redDot:InitRedDot("ShopSeeGoodsInfo", { goodsId = info.goodsId })
    self:_UpdateReadInfo(info.goodsId)
    
    self.view.basicStateCtrl:SetState("RandomMyPosition")
    self.view.selectCountStateCtrl:SetState("NoSelectCount")
    self.view.priceStateCtrl:SetState("Normal")
    self.view.refreshTimeStateCtrl:SetState("None")
    self:SetSelectState(false)
    
    self:_RefreshRemainLimitCount(-1)
    self:_RefreshItemUI(info)
    self:_RefreshProfitRatioUI(info.priceDiffRatio)
    self.view.currentPriceTxt.text = UIUtils.getNumString(info.todayPrice, true)
    
    self.view.selectBtn.onClick:RemoveAllListeners()
    self.view.selectBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.ShopTradeItem, {
            goodsData = info.friendGoodsData,
            isSellOnly = true,
        })
    end)
    self.view.animationWrapper:PlayInAnimation()
end






ShopTradeGoodsCell.InitShopTradeGoodsCellBulkSellMode = HL.Method(HL.Table, HL.Number, HL.Function) << function(self, info, luaIndex, onClick)
    self.m_info = info
    self:_FirstTimeInit()
    self.view.redDot:InitRedDot("ShopSeeGoodsInfo", { goodsId = info.goodsId })
    self:_UpdateReadInfo(info.goodsId)
    
    self.view.basicStateCtrl:SetState("RandomMyPosition")
    self.view.selectCountStateCtrl:SetState("NoSelectCount")
    self.view.priceStateCtrl:SetState("Normal")
    self.view.refreshTimeStateCtrl:SetState("None")
    self:SetSelectState(false)
    
    self:SetNameBgVisible(false)
    self:_RefreshRemainLimitCount(-1)
    self:_RefreshItemUI(info)
    self:_RefreshProfitRatioUI(info.profitRatio)
    self.view.currentPriceTxt.text = UIUtils.getNumString(info.todayPrice, true)
    
    self.view.selectBtn.onClick:RemoveAllListeners()
    self.view.selectBtn.onClick:AddListener(function()
        onClick(luaIndex)
    end)
    InputManagerInst:SetBindingText(self.view.selectBtn.hoverConfirmBindingId, Language.LUA_DOMAIN_SHOP_BULK_SELL_CONFIRM_CELL_KEY_HINT)
    self.view.animationWrapper:PlayInAnimation()
end






ShopTradeGoodsCell.InitCommonShopGoodsCellCommonMode = HL.Method(HL.Table) << function(self, info)
    
    self:_FirstTimeInit()
    self.m_info = info
    self.view.redDot:InitRedDot("ShopSeeGoodsInfo", { goodsId = info.goodsId })
    self:_UpdateReadInfo(info.goodsId)
    local leftSec = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(info.refreshType)
    
    self.view.basicStateCtrl:SetState("Common")
    self.view.selectCountStateCtrl:SetState("NoSelectCount")
    self.view.priceStateCtrl:SetState(info.discount == 0 and "Normal" or "HasDiscount")
    self.view.lockState:SetState(info.isLocked and "Lock" or "NotLock")
    self:SetSelectState(false)
    
    self:_RefreshNextRefreshTime(leftSec)
    self:_RefreshRemainLimitCount(info.remainLimitCount)
    self:_RefreshItemUI(info)
    self:SetNameBgVisible(false)
    local discountTxt = string.format("-%.0f", info.discount * 100)
    self.view.discountTxt.text = discountTxt
    self.view.discountShadowTxt.text = discountTxt
    self.view.currentPriceTxt.text = UIUtils.getNumString(info.curPrice, true)
    self.view.originalPriceTxt.text = UIUtils.getNumString(info.originPrice, true)
    
    self.view.selectBtn.onClick:RemoveAllListeners()
    self.view.selectBtn.onClick:AddListener(function()
        local goodsData = GameInstance.player.shopSystem:GetShopGoodsData(info.shopId, info.goodsId)
        CashShopUtils.OpenShopDetailPanel(goodsData)
    end)
    InputManagerInst:SetBindingText(self.view.selectBtn.hoverConfirmBindingId, Language.LUA_SHOP_SELECT_ITEM)
    if info.refreshTag == "normal" then
        self.view.animationWrapper:PlayInAnimation()
    end
end







ShopTradeGoodsCell._StartTickRefreshTime = HL.Method() << function(self)
    self.m_tickKey = LuaUpdate:Remove(self.m_tickKey)
    self.m_tickKey = LuaUpdate:Add("LateTick", function(deltaTime)
        if not self.m_info then
            return
        end
        if Time.time >= self.m_nextRefreshTime then
            self.m_nextRefreshTime = Time.time + refreshTimeInterval
            local leftSec = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(self.m_info.refreshType)
            self:_RefreshNextRefreshTime(leftSec)
        end
    end)
end



ShopTradeGoodsCell._EndTickRefreshTime = HL.Method() << function(self)
    self.m_tickKey = LuaUpdate:Remove(self.m_tickKey)
end




ShopTradeGoodsCell._RefreshNextRefreshTime = HL.Method(HL.Number) << function(self, leftSec)
    self.view.refreshTimeTxt.text = UIUtils.getShortLeftTime(leftSec)
    if leftSec <= 0 then
        self.view.refreshTimeStateCtrl:SetState("None")
    elseif leftSec <= Const.SEC_PER_DAY then
        self.view.refreshTimeStateCtrl:SetState("StrongWarning")
    elseif leftSec <= (Const.SEC_PER_DAY * 3) then
        self.view.refreshTimeStateCtrl:SetState("Warning")
    else
        self.view.refreshTimeStateCtrl:SetState("Normal")
    end
end




ShopTradeGoodsCell._RefreshRemainLimitCount = HL.Method(HL.Number) << function(self, remainLimitCount)
    if remainLimitCount < 0 then
        self.view.limitNumberNode.gameObject:SetActive(false)
        self.view.sellOutStateCtrl:SetState("NotSellOut")
    else
        self.view.limitNumberNode.gameObject:SetActive(true)
        self.view.limitCountTxt.text = remainLimitCount
        if remainLimitCount == 0 then
            self.view.limitCountTxt.color = self.view.config.INVENTORY_RED_COLOR
        else
            self.view.limitCountTxt.color = self.view.config.INVENTORY_NORMAL_COLOR
        end

        self.view.sellOutStateCtrl:SetState(remainLimitCount == 0 and "SellOut" or "NotSellOut")
    end
end




ShopTradeGoodsCell._RefreshProfitRatioUI = HL.Method(HL.Number) << function(self, ratio)
    self.view.profitRatioTxt.text = math.abs(ratio)
    self.view.profitArrowStateCtrl:SetState(DomainShopUtils.getProfitArrowStateName(ratio))
end




ShopTradeGoodsCell._RefreshItemUI = HL.Method(HL.Table) << function(self, info)
    self.view.itemIcon:InitItemIcon(info.itemId, true)
    self.view.bundleCountTxt.text = UIUtils.getNumString(info.itemBundleCount)
    if info.itemBundleCount > 1 then
        self.view.propsNumberNode.gameObject:SetActive(true)
    else
        self.view.propsNumberNode.gameObject:SetActive(false)
    end

    self.view.myPositionCountTxt.text = UIUtils.getNumString(info.itemCount)
    self.view.moneyIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, info.moneyIcon)
    self.view.rarityImg.color = UIUtils.getItemRarityColor(info.itemRarity)
    self.view.itemNameTxt.text = info.itemName
end




ShopTradeGoodsCell.SetSelectCount = HL.Method(HL.Number) << function(self, count)
    
    if count == 0 then
        self.view.selectCountStateCtrl:SetState("NoSelectCount")
    else
        self.view.selectCountStateCtrl:SetState("HasSelectCount")
        self.view.selectCountTxt.text = count
    end
end




ShopTradeGoodsCell._UpdateReadInfo = HL.Method(HL.String) << function(self, goodsId)
    GameInstance.player.shopSystem:RecordSeeGoodsId(goodsId)
end




ShopTradeGoodsCell.SetNameBgVisible = HL.Method(HL.Boolean) << function(self, visible)
    self.view.nameBg.gameObject:SetActive(visible)
end




ShopTradeGoodsCell.SetSelectState = HL.Method(HL.Boolean) << function(self, isSelect)
    if isSelect then
        self.view.selectStateCtrl:SetState("Select")
        if self.view.selectCountStateCtrl.currentStateName == "NoSelectCount" then
            InputManagerInst:SetBindingText(self.view.selectBtn.hoverConfirmBindingId, Language.LUA_DOMAIN_SHOP_BULK_SELL_CONFIRM_CELL_KEY_HINT)
        else
            InputManagerInst:SetBindingText(self.view.selectBtn.hoverConfirmBindingId, Language.LUA_DOMAIN_SHOP_BULK_SELL_CANCEL_CELL_KEY_HINT)
        end
    else
        self.view.selectStateCtrl:SetState("UnSelect")
        InputManagerInst:SetBindingText(self.view.selectBtn.hoverConfirmBindingId, Language.LUA_DOMAIN_SHOP_BULK_SELL_CONFIRM_CELL_KEY_HINT)
    end
end


HL.Commit(ShopTradeGoodsCell)
return ShopTradeGoodsCell

