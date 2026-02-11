local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')












CashShopItemTag = HL.Class('CashShopItemTag', UIWidgetBase)




CashShopItemTag._OnFirstTimeInit = HL.Override() << function(self)

end


CashShopItemTag.m_goodsData = HL.Field(HL.Any)


CashShopItemTag.m_arg = HL.Field(HL.Any)


CashShopItemTag.m_targetTime = HL.Field(HL.Number) << 0




CashShopItemTag.InitCashShopItemTag = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()

    self.m_arg = arg

    if arg.isShop then
        local goodsData = arg.goodsData
        self.m_goodsData = goodsData
        local hideRemainCount = arg.hideRemainCount
        self:_SetupUIShopGoods(goodsData, hideRemainCount)
    end

    if arg.isCashShop then
        self:_SetupUICashShopGoods(arg.shopGoodsInfo)
    end
end






CashShopItemTag._SetupUIShopGoods = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, goodsData, hideRemainCount)
    self:_SetAllTagInactive()

    local goodsTemplateId = goodsData.goodsTemplateId
    local hasCfg, goodsCfg = Tables.shopGoodsTable:TryGetValue(goodsTemplateId)
    local isGachaGoodsAndHideLeftTime = false
    if hasCfg and not string.isEmpty(goodsCfg.weaponGachaPoolId) then
        local isRealTime, _ = CashShopUtils.GetGachaWeaponPoolCloseTimeInfo(goodsCfg.weaponGachaPoolId)
        isGachaGoodsAndHideLeftTime = not isRealTime
    end
    
    if isGachaGoodsAndHideLeftTime then
        self.view.tagTime.gameObject:SetActive(false)
    else
        local leftTime = GameInstance.player.shopSystem:GetWeaponGoodsTimeLimit(goodsData)
        if leftTime > -1 then
            self.view.tagTime.gameObject:SetActive(true)
            self:UpdateTime()
            self:_StartCoroutine(function()
                coroutine.wait(1)
                self:UpdateTime()
            end)
        else
            
            leftTime = goodsData.closeTimeStamp - DateTimeUtils.GetCurrentTimestampBySeconds()
            if leftTime > 0 then
                self.view.tagTime.gameObject:SetActive(true)
                self.m_targetTime = goodsData.closeTimeStamp
                self:UpdateTime()
                self:_StartCoroutine(function()
                    coroutine.wait(1)
                    self:UpdateTime()
                end)
            else
                self.view.tagTime.gameObject:SetActive(false)
            end
        end
    end

    local limitBuy = GameInstance.player.shopSystem:GetRemainCountByGoodsId(goodsData.shopId, goodsTemplateId)
    self.view.tagRestriction.shopRestrictionText.text = Language.ui_shop_token_stock
    if limitBuy > 0 then
        self.view.tagRestriction.gameObject:SetActive(true)
        self.view.tagRestriction.shopRestrictionNumText.text = limitBuy
    elseif limitBuy ==-1 then
        self.view.tagRestriction.gameObject:SetActive(true)
        self.view.tagRestriction.shopRestrictionNumText.text = "∞"
    else
        self.view.tagRestriction.gameObject:SetActive(false)
    end
    if hideRemainCount then  
        self.view.tagRestriction.gameObject:SetActive(false)
    end

    if goodsData.discount and goodsData.discount < 1 then
        self.view.tagDiscount.gameObject:SetActive(true)
        self.view.tagDiscount.txtDiscount.text = string.format("-%d", math.floor((1 - goodsData.discount) * 100 + 0.5))
    else
        self.view.tagDiscount.gameObject:SetActive(false)
    end

    local isNew = GameInstance.player.shopSystem:IsNewGoodsId(self.m_goodsData.goodsId)
    local hideNew = self.m_arg.hideNew or false
    self.view.newNode.gameObject:SetActive(isNew and not hideNew)
end





CashShopItemTag._SetupUICashShopGoods = HL.Method(HL.Any) << function(self, goodsInfo)
    self:_SetAllTagInactive()

    local goodsId = goodsInfo.goodsId
    local goodsData = goodsInfo.goodsData
    
    local closeTimeStamp = goodsData.closeTimeStamp
    self.m_targetTime = closeTimeStamp
    local leftTime = closeTimeStamp - DateTimeUtils.GetCurrentTimestampBySeconds()
    local hideTime = self.m_arg.hideTime or false
    if closeTimeStamp ~= 0 and leftTime > -1 and not hideTime then
        self.view.tagTime.gameObject:SetActive(true)
        self:UpdateTimeByTargetTs()
        self:_StartCoroutine(function()
            coroutine.wait(1)
            self:UpdateTimeByTargetTs()
        end)
    else
        self.view.tagTime.gameObject:SetActive(false)
    end

    
    local haveRestriction = false
    local limitGoodsData = GameInstance.player.cashShopSystem:GetPlatformLimitGoodsData(goodsId)
    local hideRestriction = self.m_arg.hideRestriction or false
    if limitGoodsData ~= nil and
        limitGoodsData.limitType == CS.Beyond.Gameplay.CashShopSystem.EPlatformLimitGoodsType.Common and
        not hideRestriction then
        local _, cfg = Tables.giftpackCashShopGoodsDataTable:TryGetValue(goodsId)
        local limitCount = limitGoodsData.limitCount
        local purchaseCount = limitGoodsData.purchaseCount
        local remain = limitCount - purchaseCount
        if cfg ~= nil then
            local text = CashShopUtils.GetRestrictionTagTextByLimitType(cfg.availRefresh)
            self.view.tagRestriction.shopRestrictionText.text = text
        end
        self.view.tagRestriction.shopRestrictionNumText.text = remain
        haveRestriction = true
    end
    self.view.tagRestriction.gameObject:SetActive(haveRestriction)

    
    self.view.tagDiscount.gameObject:SetActive(false)

    
    local succ, giftpackGoodsData = Tables.GiftpackCashShopGoodsDataTable:TryGetValue(goodsId)
    if succ then
        local tagList = giftpackGoodsData.tagList
        for _, tagId in pairs(tagList) do
            local tagData = Tables.CashShopGiftPackTagTable[tagId]
            local style = tagData.style
            local value = tagData.value
            local tagCell = self.view[style]
            if tagCell ~= nil then
                tagCell.gameObject:SetActive(true)
                
                local haveValue = not string.isEmpty(value)
                local tagText = tagCell.tagText
                local line = tagCell.lineImg
                if tagText ~= nil then
                    tagText.gameObject:SetActive(haveValue)
                    tagText.text = value
                end
                if line ~= nil then
                    line.gameObject:SetActive(haveValue)
                end
            end
        end
    end

    
    local isNew = GameInstance.player.cashShopSystem:IsNewGoods(goodsId)
    self.view.newNode.gameObject:SetActive(isNew)
end



CashShopItemTag.UpdateTime = HL.Method() << function(self)
    local goodsData = self.m_goodsData
    local leftTime = GameInstance.player.shopSystem:GetWeaponGoodsTimeLimit(goodsData)
    if leftTime <= -1 and self.m_targetTime ~= 0 then
        leftTime = self.m_targetTime - DateTimeUtils.GetCurrentTimestampBySeconds()
    end

    if leftTime > -1 then
        local stateName
        if leftTime > 3600 * 24 * 3 then   
            stateName = "Green"
        elseif leftTime <= 3600 * 24 * 3 and leftTime > 3600 * 24 then   
            stateName = "Yellow"
        else
            stateName = "Red"
        end
        self.view.tagTime.stateController:SetState(stateName)
        self.view.tagTime.txtTime.text = UIUtils.getShortLeftTime(leftTime)
    else
        self.view.tagTime.gameObject:SetActive(false)
    end
end



CashShopItemTag.UpdateTimeByTargetTs = HL.Method() << function(self)
    local closeTimeStamp = self.m_targetTime
    local leftTime = closeTimeStamp - DateTimeUtils.GetCurrentTimestampBySeconds()
    if leftTime > -1 then
        local stateName
        if leftTime > 3600 * 24 * 3 then   
            stateName = "Green"
        elseif leftTime <= 3600 * 24 * 3 and leftTime > 3600 * 24 then   
            stateName = "Yellow"
        else
            stateName = "Red"
        end
        self.view.tagTime.stateController:SetState(stateName)
        self.view.tagTime.txtTime.text = UIUtils.getShortLeftTime(leftTime)
    else
        self.view.tagTime.gameObject:SetActive(false)
    end
end



CashShopItemTag._SetAllTagInactive = HL.Method() << function(self)
    local left = self.view.tagLeft.transform
    local right = self.view.tagRight.transform
    for i = 0, left.childCount - 1 do
        left:GetChild(i).gameObject:SetActive(false)
    end
    for i = 0, right.childCount - 1 do
        right:GetChild(i).gameObject:SetActive(false)
    end
end

HL.Commit(CashShopItemTag)
return CashShopItemTag

