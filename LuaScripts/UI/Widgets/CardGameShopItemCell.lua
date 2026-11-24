local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

CardGameShopItemCell = HL.Class('CardGameShopItemCell', UIWidgetBase)

CardGameShopItemCell.m_arg = HL.Field(HL.Any)


CardGameShopItemCell._OnFirstTimeInit = HL.Override() << function(self)
    local view = self.view
    view.button.onClick:RemoveAllListeners()
    view.button.onClick:AddListener(function()
        self:_OnClickItem()
    end)
    
    view.buyBtn.onClick:RemoveAllListeners()
    view.buyBtn.onClick:AddListener(function()
        self:_OnClickBuy()
    end)
    
    view.refreshBtn.onClick:RemoveAllListeners()
    view.refreshBtn.onClick:AddListener(function()
        self:_OnClickRefresh()
    end)
    
    view.pinBtn.onClick:RemoveAllListeners()
    view.pinBtn.onClick:AddListener(function()
        self:_OnClickPin()
    end)
    if DeviceInfo.usingController then
        view.naviDeco.onIsNaviTargetChanged = function(isTarget)
            self:_OnClickItem(isTarget)
        end
    else
        view.naviDeco.onIsNaviTargetChanged = nil
    end
end

CardGameShopItemCell.InitShopItemRelic = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()
    self.m_arg = arg
    local view = self.view
    view.infoState:SetState("IsRelic")
    self:SetEmptyState(false)
    self:SetSelectState(false)
    view.nameTxt.text = self.m_arg.name
    view.descTxt.text = self.m_arg.desc
    view.iconImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC, self.m_arg.icon)
    view.extraNode.gameObject:SetActive(self.m_arg.isExtraRelic == true)
    
    view.rarityImg.color = UIUtils.getItemRarityColor(self.m_arg.rarity)
    self:SetCanRefreshState(self.m_arg.canRefresh)
    self:SetPinState(self.m_arg.isPin)
    self:SetHasPriceState(self.m_arg.hasPrice)
    self:SetBuyState(self.m_arg.buyState)
    if self.m_arg.hasPrice then
        self:RefreshPrice(self.m_arg.curPrice, self.m_arg.originPrice)
    end
end

CardGameShopItemCell.InitShopItemCardPack = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()
    self.m_arg = arg
    local view = self.view
    view.infoState:SetState("IsPack")
    self:SetEmptyState(false)
    self:SetSelectState(false)
    view.nameTxt.text = self.m_arg.name
    view.descTxt:SetAndResolveTextStyle(self.m_arg.desc)
    view.iconImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_PACK_SMALL, self.m_arg.icon)
    view.extraNode.gameObject:SetActive(false)
    
    self:SetCanRefreshState(false)
    self:SetPinState(self.m_arg.isPin)
    self:SetHasPriceState(true)
    self:SetBuyState(self.m_arg.buyState)
    self:RefreshPrice(self.m_arg.curPrice, self.m_arg.originPrice)
end


CardGameShopItemCell.RefreshPrice = HL.Method(HL.Number, HL.Number) << function(self, curPrice, originPrice)
    local discountRate = originPrice ~= 0 and math.ceil((curPrice - originPrice) / originPrice * 100) or 0
    local view = self.view
    view.infoState:SetState(discountRate ~= 0 and "HasDiscount" or "NoDiscount")
    view.curPriceTxt.text = curPrice
    view.originPriceTxt.text = originPrice
    view.discountTxt.text = CardGameUtils.GetNumDeltaText(discountRate)
end







CardGameShopItemCell.SetBuyState = HL.Method(HL.String) << function(self, state)
    self.view.buyBtnState:SetState(state)
    self.view.priceNodeState:SetState(state == "NoMoney" and "MoneyNotEnough" or "MoneyEnough")
    self.view.touchPcSelectNodeStateCtrl:SetState(state)
end


CardGameShopItemCell.SetPinState = HL.Method(HL.Boolean) << function(self, isPin)
    self.view.infoState:SetState(isPin and "IsPin" or "NotPin")
    self.view.pinBtn.customBindingViewLabelText = isPin and Language.LUA_CARD_GAME_BLACKJACK_SHOP_SELECT_UNLOCK
        or Language.ui_card_game_blackjack_shop_select_lock
end

CardGameShopItemCell.SetHasPriceState = HL.Method(HL.Boolean) << function(self, hasPrice)
    self.view.infoState:SetState(hasPrice and "HasPrice" or "NoPrice")   
end


CardGameShopItemCell.SetCanRefreshState = HL.Method(HL.Boolean) << function(self, canRefresh)
    self.view.infoState:SetState(canRefresh and "CanRefresh" or "NoRefresh")    
end


CardGameShopItemCell.SetSelectState = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, select, playAni)
    local selectStateName = DeviceInfo.usingController and "Selected" or "TouchPcSelected"
    self.view.stateController:SetState(select and selectStateName or "UnSelected")
    if playAni then
        if select then
            self.view.animationWrapper:PlayInAnimation()
        else
            self.view.animationWrapper:PlayOutAnimation()
        end
    end
end


CardGameShopItemCell.SetEmptyState = HL.Method(HL.Boolean) << function(self, isEmpty)
    self.view.stateController:SetState(isEmpty and "Empty" or "NotEmpty")
end




CardGameShopItemCell.PlayRefreshAni = HL.Method() << function(self)
    self.view.animationWrapper:Play("itemcell_refresh_in")
end


CardGameShopItemCell.ResetInfoScroll = HL.Method() << function(self)
    self.view.infoScrollList:StopMovement()
    self.view.infoScrollList.verticalNormalizedPosition = 1
end





CardGameShopItemCell._OnClickItem = HL.Method(HL.Opt(HL.Boolean)) << function(self, isSelect)
    self.m_arg.onClickItem(isSelect)
end


CardGameShopItemCell._OnClickBuy = HL.Method() << function(self)
    self.m_arg.onClickBuy()
end


CardGameShopItemCell._OnClickRefresh = HL.Method() << function(self)
    self.m_arg.onClickRefresh()
end


CardGameShopItemCell._OnClickPin = HL.Method() << function(self)
    self.m_arg.onClickPin()
end


HL.Commit(CardGameShopItemCell)
return CardGameShopItemCell
