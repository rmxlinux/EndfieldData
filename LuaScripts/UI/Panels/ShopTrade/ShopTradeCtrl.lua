local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ShopTrade
local PHASE_ID = PhaseId.ShopTrade

local shopSystem = GameInstance.player.shopSystem






















































































ShopTradeCtrl = HL.Class('ShopTradeCtrl', uiCtrl.UICtrl)







ShopTradeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BUY_ITEM_SUCC] = '_OnBuyItemSuccess',
    [MessageConst.ON_SELL_ITEM_SUCC] = '_OnSellItemSuccess',
    [MessageConst.ON_SHOP_REFRESH] = '_OnShopRefresh',
    [MessageConst.ON_FRIEND_SHOP_INFO_SYNC] = '_OnFriendShopRefresh',
}



ShopTradeCtrl.m_isLocalShop = HL.Field(HL.Boolean) << false


ShopTradeCtrl.m_showFriendRecord = HL.Field(HL.Boolean) << false


ShopTradeCtrl.m_goodsTagCellCache = HL.Field(HL.Forward("UIListCache"))


ShopTradeCtrl.m_getGoodsGroupCellFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_goodsGroupSortFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_goodsSortFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_soldOutGoodsSortFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_goodsFriendSortFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_myPositionGoodsSortFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_bindIdPreTab = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_bindIdNextTab = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_waitAutoScrollTagListTime = HL.Field(HL.Number) << -1




ShopTradeCtrl.m_domainId = HL.Field(HL.String) << ""


ShopTradeCtrl.m_onCloseCallBack = HL.Field(HL.Function)


ShopTradeCtrl.m_domainInfo = HL.Field(HL.Table)


ShopTradeCtrl.m_localShopInfo = HL.Field(HL.Table)


ShopTradeCtrl.m_isSelectCommonShop = HL.Field(HL.Boolean) << true


ShopTradeCtrl.m_curSelectTagIndex = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_curNaviLocalGoodsIndex = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_isNaviTag = HL.Field(HL.Boolean) << false


ShopTradeCtrl.m_bindIdFocus = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_bindIdStopFocus = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_commonShopRefreshGoodsSearchMap = HL.Field(HL.Table)


ShopTradeCtrl._updateLimitCountTimeKey = HL.Field(HL.Number) << 0


ShopTradeCtrl._nextUpdateLimitCountTime = HL.Field(HL.Number) << 0




ShopTradeCtrl.m_friendRoleId = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_friendShopInfoList = HL.Field(HL.Table)


ShopTradeCtrl.m_friendTabCellCache = HL.Field(HL.Forward("UIListCache"))


ShopTradeCtrl.m_curSelectFriendShopIndex = HL.Field(HL.Number) << 0


ShopTradeCtrl.m_nextRefreshTs = HL.Field(HL.Number) << 0




ShopTradeCtrl.m_getBulkSellGoodsCellFunc = HL.Field(HL.Function)


ShopTradeCtrl.m_onClickBulkSellGoods = HL.Field(HL.Function)


ShopTradeCtrl.m_onSelectorNumberChanged = HL.Field(HL.Function)


ShopTradeCtrl.m_bulkSellInfo = HL.Field(HL.Table)


ShopTradeCtrl.m_waitBulkSellResp = HL.Field(HL.Boolean) << false







ShopTradeCtrl.OpenDomainFriendShop = HL.StaticMethod(HL.Any) << function(arg)
    if arg == nil then
        return
    end
    local roleId = unpack(arg)
    if roleId == nil then
        return
    end
    DomainShopUtils.openDomainFriendShop(roleId)
end



ShopTradeCtrl.OpenDomainShop = HL.StaticMethod(HL.Table) << function(args)
    local domainId = unpack(args)
    PhaseManager:OpenPhase(PHASE_ID, { domainId = domainId, showFriendRecord = true })
end







ShopTradeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self:_InitData(arg)
    self:_UpdateData()
    self:_RefreshAllUI()
    self:_BindingControllerOperate()

    self:_StartUpdate(function(deltaTime)
        
        if not self.m_isLocalShop then
            local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
            if curTs >= self.m_nextRefreshTs then
                self.m_nextRefreshTs = Utils.getNextCommonServerRefreshTime()
                GameInstance.player.shopSystem:SendQueryFriendShop(self.m_friendRoleId, DomainShopUtils.getAllLocalUnlockRandomShopIds())
                UIManager:Close(PanelId.ShopTradeItem)
            end
        end
        
        if DeviceInfo.usingController then
            return  
        end
        if self.m_waitAutoScrollTagListTime < 0 then
            return
        end
        if self.m_waitAutoScrollTagListTime >= 1 then
            local showRange = self.view.goodsNode.goodsGroupList:GetShowRange()
            local csIndex = math.floor((showRange.x + showRange.y) / 2)
            local newIndex = LuaIndex(csIndex)
            if self.m_curSelectTagIndex ~= newIndex then
                self:_OnChangeSelectTagUI(newIndex)
            end
            self.m_waitAutoScrollTagListTime = -1
        else
            self.m_waitAutoScrollTagListTime = self.m_waitAutoScrollTagListTime + deltaTime
        end
    end)
    
    self.m_nextRefreshTs = Utils.getNextCommonServerRefreshTime()
end



ShopTradeCtrl.OnClose = HL.Override() << function(self)
    local succ, level = GameUtil.SpaceshipUtils.TryGetSpaceshipLevel()
    if succ then
        level:TriggerDomainSellStatus()
    end
    shopSystem:SetGoodsIdSee()
    
    local isOpen, _ = PhaseManager:IsOpen(PhaseId.Dialog)
    if isOpen then
        Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 0 })
    end
    self._updateLimitCountTimeKey = LuaUpdate:Remove(self._updateLimitCountTimeKey)
end



ShopTradeCtrl.OnAnimationInFinished = HL.Override() << function(self)
    self:_NotifyClientCondition()
end






ShopTradeCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_domainId = arg.domainId or ""
    self.m_onCloseCallBack = arg.onCloseCB
    self.m_friendRoleId = arg.friendRoleId or 0
    self.m_showFriendRecord = (arg.showFriendRecord == true) or Utils.isInSpaceShip()
    self.m_isLocalShop = not string.isEmpty(self.m_domainId)
    
    if self.m_isLocalShop then
        
        local _, domainCfg = Tables.domainDataTable:TryGetValue(self.m_domainId)
        local moneyId = domainCfg.domainGoldItemId
        local moneyItemCfg = Utils.tryGetTableCfg(Tables.itemTable, moneyId)
        self.m_domainInfo = {
            moneyId = moneyId,
            moneyIcon = moneyItemCfg and moneyItemCfg.iconId or "",
            shopGroupId = domainCfg.domainShopGroupId,
        }
        
        local shopGroupId = self.m_domainInfo.shopGroupId
        local _, shopGroupCfg = Tables.shopGroupTable:TryGetValue(shopGroupId)
        local _, domainShopGroupCfg = Tables.shopGroupDomainTable:TryGetValue(shopGroupId)
        local commonShopId, randomShopId
        for _, shopId in pairs(shopGroupCfg.shopIds) do
            local _, shopCfg = Tables.shopTable:TryGetValue(shopId)
            if shopCfg.shopRefreshType == GEnums.ShopRefreshType.None then
                commonShopId = shopId
            elseif shopCfg.shopRefreshType == GEnums.ShopRefreshType.RefreshRandom then
                randomShopId = shopId
            end
        end
        
        self.m_localShopInfo = {
            commonShopInfo = {
                shopId = commonShopId,
            },
            randomShopInfo = {
                shopId = randomShopId,
            },
            myPositionGoodsGroup = ShopTradeCtrl._CreateGoodsGroup(Tables.shopDomainConst.goodsTagIdMyPosition),
            soldOutGoodsGroup = ShopTradeCtrl._CreateGoodsGroup(Tables.shopDomainConst.goodsTagIdSoldOut),
            
            bgImg = domainShopGroupCfg.bgImg,
            icon = shopGroupCfg.icon,
        }
    else
        
    end
    
    self.m_onClickBulkSellGoods = function(luaIndex)
        self:_OnSelectBulkSellGoods(luaIndex)
    end
    self.m_onSelectorNumberChanged = function(curNumber, isChangeByBtn)
        self:_OnChangeBulkSellSelectCount(lume.round(curNumber), not isChangeByBtn)
    end
    
    self.m_goodsGroupSortFunc = Utils.genSortFunction({ "sortId" }, true)
    
    
    
    
    
    
    self.m_goodsSortFunc = Utils.genSortFunction({ "remainLimitSort", "sortId", "raritySort", "priceRatioSort", "goodsId" }, true)
    
    
    
    
    
    
    
    self.m_soldOutGoodsSortFunc = Utils.genSortFunction({ "refreshTypeSort", "tagSort", "sortId", "raritySort", "priceRatioSort", "goodsId" }, true)
    
    
    
    
    
    
    self.m_goodsFriendSortFunc = Utils.genSortFunction({ "hasPosition", "sortId", "raritySort", "priceRatioSort", "goodsId" }, true)
    
    
    
    
    
    self.m_myPositionGoodsSortFunc = Utils.genSortFunction({ "sortId", "raritySort", "profitRatioSort", "goodsId" }, true)
end



ShopTradeCtrl._UpdateData = HL.Method() << function(self)
    self.m_commonShopRefreshGoodsSearchMap = {}
    if self.m_isLocalShop then
        
        self:_UpdateCommonShopData()
        self:_UpdateRandomShopData()
    else
        
        
        local shopData = shopSystem:GetFriendShopData(self.m_friendRoleId)
        self.m_friendShopInfoList = {}
        for shopId, goodsMap in cs_pairs(shopData.shopGoodsDic) do
            local domainId = DomainShopUtils.getDomainIdByDomainShopId(shopId)
            local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
            local hasData = GameInstance.player.domainDevelopmentSystem.domainDevDataDic:TryGetValue(domainId)
            if hasCfg and hasData then
                local moneyId = domainCfg.domainGoldItemId
                local moneyItemCfg = Utils.tryGetTableCfg(Tables.itemTable, moneyId)
                
                local shopInfo = {
                    shopId = shopId,
                    domainId = domainId,
                    domainName = domainCfg.domainName,
                    domainIcon = domainCfg.domainIcon,
                    moneyId = domainCfg.domainGoldItemId,
                    moneyIcon = moneyItemCfg and moneyItemCfg.iconId or "",
                    myPositionGoodsGroup = ShopTradeCtrl._CreateGoodsGroup(Tables.shopDomainConst.goodsTagIdMyPosition),

                    sortId = domainCfg.sortId,
                }
                self:_UpdateFriendShopData(shopInfo, goodsMap)
                table.insert(self.m_friendShopInfoList, shopInfo)
            end
        end
        table.sort(self.m_friendShopInfoList, function(a, b)
            return a.sortId < b.sortId
        end)
    end
end



ShopTradeCtrl._CreateGoodsGroup = HL.StaticMethod(HL.String).Return(HL.Table) << function(tagId)
    local _, tagCfg = Tables.shopGoodsTagTable:TryGetValue(tagId)
    local goodsGroup = {
        tagId = tagId,
        tagName = tagCfg.tagName,
        tagIcon = tagCfg.tagIcon,
        goodsList = {},
        
        sortId = tagCfg.sortId,
    }
    return goodsGroup
end




ShopTradeCtrl._UpdateCommonShopData = HL.Method() << function(self)
    local shopInfo = self.m_localShopInfo.commonShopInfo
    local shopId = shopInfo.shopId
    shopInfo.goodsGroupDic = {}
    shopInfo.goodsGroupList = {}
    local soldOutGoodsGroup = self.m_localShopInfo.soldOutGoodsGroup
    soldOutGoodsGroup.goodsList = {}
    local shopData = shopSystem:GetShopData(shopId)
    if not shopSystem:CheckShopUnlocked(shopId) then
        return
    end
    
    for _, goodsData in cs_pairs(shopData.goodList) do
        local goodsTplId = goodsData.goodsTemplateId
        local goodsId = goodsData.goodsId
        local _, goodsCfg = Tables.shopGoodsTable:TryGetValue(goodsTplId)
        local tagId = goodsCfg.goodsTagId
        local unlock = shopSystem:CheckGoodsUnlocked(goodsId)
        if unlock or goodsCfg.isShowWhenLock then
            
            local goodsGroup = shopInfo.goodsGroupDic[tagId]
            if goodsGroup == nil then
                goodsGroup = ShopTradeCtrl._CreateGoodsGroup(tagId)
                shopInfo.goodsGroupDic[tagId] = goodsGroup
            end
            
            local itemBundle = UIUtils.getRewardFirstItem(goodsCfg.rewardId)
            local itemId = itemBundle.id
            local hasCfg, itemCfg = Tables.itemTable:TryGetValue(itemId)
            if not hasCfg then
                logger.error("itemTable表数据缺失，itemId为：", itemId)
            else
                local remainLimitCount = shopSystem:GetRemainCountByGoodsId(shopId, goodsTplId)
                local discount = 1 - goodsData.discount
                local refreshType = goodsCfg.limitCountRefreshType
                local isSoldOut = remainLimitCount <= 0
                local goodsInfo = {
                    
                    shopId = shopId,
                    goodsId = goodsId,
                    
                    originPrice = goodsCfg.price,
                    discount = discount,
                    curPrice = CashShopUtils.GetDisplayPrice(goodsCfg.price, goodsData.discount),
                    remainLimitCount = remainLimitCount,
                    refreshType = refreshType,
                    
                    itemId = itemId,
                    itemName = itemCfg.name,
                    itemCount = Utils.getItemCount(itemId, true, true),
                    itemBundleCount = itemBundle.count,
                    itemIcon = itemCfg.iconId,
                    itemRarity = itemCfg.rarity,
                    moneyId = self.m_domainInfo.moneyId,
                    moneyIcon = self.m_domainInfo.moneyIcon,
                    
                    refreshTypeSort = refreshType == GEnums.ShopFrequencyLimitType.Forever and 999 or refreshType:GetHashCode(),
                    remainLimitSort = remainLimitCount == 0 and 1 or 0,
                    raritySort = -itemCfg.rarity,
                    priceRatioSort = -discount,
                    sortId = goodsCfg.sortId,
                }
                if isSoldOut then
                    goodsInfo.tagSort = goodsGroup.sortId
                    table.insert(soldOutGoodsGroup.goodsList, goodsInfo)
                else
                    table.insert(goodsGroup.goodsList, goodsInfo)
                end
            end
        end
    end
    
    for _, goodsGroup in pairs(shopInfo.goodsGroupDic) do
        if #goodsGroup.goodsList > 0 then
            table.insert(shopInfo.goodsGroupList, goodsGroup)
        end
    end
    table.sort(shopInfo.goodsGroupList, self.m_goodsGroupSortFunc)
    
    local groupIndex = 1
    for _, goodsGroup in pairs(shopInfo.goodsGroupList) do
        table.sort(goodsGroup.goodsList, self.m_goodsSortFunc)
        local goodsIndex = 1
        for _, goodsInfo in pairs(goodsGroup.goodsList) do
            self.m_commonShopRefreshGoodsSearchMap[goodsInfo.goodsId] = {
                goodsInfo = goodsInfo,
                groupIndex = groupIndex,
                goodsIndex = goodsIndex,
            }
            goodsIndex = goodsIndex + 1
        end
        groupIndex = groupIndex + 1
    end
    
    if #soldOutGoodsGroup.goodsList > 0 then
        table.insert(shopInfo.goodsGroupList, soldOutGoodsGroup)
        table.sort(soldOutGoodsGroup.goodsList, self.m_soldOutGoodsSortFunc)
    end
end





ShopTradeCtrl._UpdateRandomShopData = HL.Method() << function(self)
    local shopInfo = self.m_localShopInfo.randomShopInfo
    local shopId = shopInfo.shopId
    local myPositionGroup = self.m_localShopInfo.myPositionGoodsGroup
    myPositionGroup.totalPrice = 0
    myPositionGroup.totalTodayPrice = 0
    myPositionGroup.totalProfit = 0
    myPositionGroup.totalProfitRatio = 0
    shopInfo.goodsGroupDic = {}
    shopInfo.goodsGroupList = {}
    myPositionGroup.goodsList = {}
    if not shopSystem:CheckShopUnlocked(shopId) then
        return
    end
    
    local shopData = shopSystem:GetShopData(shopId)
    shopInfo.remainLimitCount = shopSystem:GetRemainLimitCountByShopId(shopId)
    
    
    for _, goodsData in cs_pairs(shopData.goodList) do
        local goodsTplId = goodsData.goodsTemplateId
        local goodsId = goodsData.goodsId
        local _, goodsCfg = Tables.shopGoodsTable:TryGetValue(goodsTplId)
        local unlock = shopSystem:CheckGoodsUnlocked(goodsId)
        if unlock or goodsCfg.isShowWhenLock then
            local tagId = goodsCfg.goodsTagId
            
            local goodsGroup = shopInfo.goodsGroupDic[tagId]
            if goodsGroup == nil then
                goodsGroup = ShopTradeCtrl._CreateGoodsGroup(tagId)
                shopInfo.goodsGroupDic[tagId] = goodsGroup
                table.insert(shopInfo.goodsGroupList, goodsGroup)
            end
            
            
            local itemBundle = UIUtils.getRewardFirstItem(goodsCfg.rewardId)
            local itemId = itemBundle.id
            local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
            
            
            local randomGoodsData = goodsData.domainRandomGoodsData
            local originPrice = goodsCfg.randomGoodsStandardPrice
            local todayPrice = randomGoodsData.historyPrice[0]
            local avgPrice = randomGoodsData.avgPrice
            local profit = todayPrice - avgPrice
            local priceDiffRatio = lume.round((todayPrice - originPrice) * 100 / originPrice, 0.1)
            local remainLimitCount = shopSystem:GetRemainCountByGoodsId(shopId, goodsTplId)
            local profitRatio = avgPrice == 0 and 0 or lume.round(profit * 100 / avgPrice, 0.1)
            
            local goodsInfo = {
                
                shopId = shopId,
                goodsId = goodsId,
                
                originPrice = originPrice,
                todayPrice = todayPrice,
                priceDiffRatio = priceDiffRatio,
                remainLimitCount = remainLimitCount,
                refreshType = goodsCfg.limitCountRefreshType,
                
                itemId = itemId,
                itemName = itemCfg.name,
                itemCount = randomGoodsData.quantity,
                itemBundleCount = itemBundle.count,
                itemIcon = itemCfg.iconId,
                itemRarity = itemCfg.rarity,
                moneyId = self.m_domainInfo.moneyId,
                moneyIcon = self.m_domainInfo.moneyIcon,
                
                positionAvgPrice = avgPrice,
                profit = profit,
                profitRatio = profitRatio,
                
                remainLimitSort = remainLimitCount == 0 and 1 or 0,
                raritySort = -itemCfg.rarity,
                priceRatioSort = -priceDiffRatio,
                profitRatioSort = -profitRatio,
                sortId = goodsCfg.sortId,
            }
            table.insert(goodsGroup.goodsList, goodsInfo)
            
            if goodsInfo.itemCount > 0 then
                table.insert(myPositionGroup.goodsList, goodsInfo)
                myPositionGroup.totalPrice = myPositionGroup.totalPrice + goodsInfo.positionAvgPrice * goodsInfo.itemCount
                myPositionGroup.totalTodayPrice = myPositionGroup.totalTodayPrice + goodsInfo.todayPrice * goodsInfo.itemCount
            end
        end
    end
    myPositionGroup.totalProfit = myPositionGroup.totalTodayPrice - myPositionGroup.totalPrice
    myPositionGroup.totalProfitRatio = myPositionGroup.totalProfit == 0 and 0 or
        lume.round(myPositionGroup.totalProfit * 100 / myPositionGroup.totalPrice, 0.1)
    
    table.sort(shopInfo.goodsGroupList, self.m_goodsGroupSortFunc)
    
    for _, goodsGroup in pairs(shopInfo.goodsGroupList) do
        table.sort(goodsGroup.goodsList, self.m_goodsSortFunc)
    end
    
    table.sort(myPositionGroup.goodsList, self.m_myPositionGoodsSortFunc)
end







ShopTradeCtrl._UpdateFriendShopData = HL.Method(HL.Table, HL.Any) << function(self, shopInfo, goodsMap)
    local shopId = shopInfo.shopId
    local myPositionGroup = shopInfo.myPositionGoodsGroup
    shopInfo.goodsGroupDic = {}
    shopInfo.goodsGroupList = {}
    myPositionGroup.goodsList = {}
    myPositionGroup.totalPrice = 0
    myPositionGroup.totalTodayPrice = 0
    myPositionGroup.totalProfit = 0
    myPositionGroup.totalProfitRatio = 0
    
    for goodsId, friendGoodsData in cs_pairs(goodsMap) do
        local unlock = shopSystem:CheckGoodsUnlocked(goodsId)
        if unlock then
            local goodsData = shopSystem:GetShopGoodsData(shopId, goodsId)
            local randomGoodsData = goodsData.domainRandomGoodsData
            local goodsTplId = friendGoodsData.goodsTemplateId
            local _, goodsCfg = Tables.shopGoodsTable:TryGetValue(goodsTplId)
            
            local tagId = goodsCfg.goodsTagId
            local goodsGroup = shopInfo.goodsGroupDic[tagId]
            if goodsGroup == nil then
                goodsGroup = ShopTradeCtrl._CreateGoodsGroup(tagId)
                shopInfo.goodsGroupDic[tagId] = goodsGroup
                table.insert(shopInfo.goodsGroupList, goodsGroup)
            end
            
            
            local itemBundle = UIUtils.getRewardFirstItem(goodsCfg.rewardId)
            local itemId = itemBundle.id
            local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
            
            local originPrice = goodsCfg.randomGoodsStandardPrice
            local todayPrice = friendGoodsData.historyPrice[0]
            local avgPrice = randomGoodsData.avgPrice
            local profit = todayPrice - avgPrice
            local priceDiffRatio = lume.round((todayPrice - originPrice) * 100 / originPrice, 0.1)
            local profitRatio = avgPrice == 0 and 0 or lume.round(profit * 100 / avgPrice, 0.1)
            local goodsInfo = {
                
                shopId = shopId,
                goodsId = goodsId,
                friendGoodsData = friendGoodsData,
                
                originPrice = originPrice,
                todayPrice = todayPrice,
                priceDiffRatio = priceDiffRatio,
                
                itemId = itemId,
                itemName = itemCfg.name,
                itemCount = randomGoodsData.quantity,
                itemBundleCount = itemBundle.count,
                itemIcon = itemCfg.iconId,
                itemRarity = itemCfg.rarity,
                moneyId = shopInfo.moneyId,
                moneyIcon = shopInfo.moneyIcon,
                
                positionAvgPrice = avgPrice,
                profit = profit,
                profitRatio = profitRatio,
                
                hasPosition = randomGoodsData.quantity > 0 and 0 or 1,
                raritySort = -itemCfg.rarity,
                priceRatioSort = -priceDiffRatio,
                profitRatioSort = -profitRatio,
                sortId = goodsCfg.sortId,
            }
            table.insert(goodsGroup.goodsList, goodsInfo)
            
            if goodsInfo.itemCount > 0 then
                table.insert(myPositionGroup.goodsList, goodsInfo)
                myPositionGroup.totalPrice = myPositionGroup.totalPrice + goodsInfo.positionAvgPrice * goodsInfo.itemCount
                myPositionGroup.totalTodayPrice = myPositionGroup.totalTodayPrice + goodsInfo.todayPrice * goodsInfo.itemCount
            end
        end
    end
    myPositionGroup.totalProfit = myPositionGroup.totalTodayPrice - myPositionGroup.totalPrice
    myPositionGroup.totalProfitRatio = myPositionGroup.totalProfit == 0 and 0 or
        lume.round(myPositionGroup.totalProfit * 100 / myPositionGroup.totalPrice, 0.1)
    
    table.sort(shopInfo.goodsGroupList, self.m_goodsGroupSortFunc)
    
    for _, goodsGroup in pairs(shopInfo.goodsGroupList) do
        table.sort(goodsGroup.goodsList, self.m_goodsFriendSortFunc)
    end
    
    table.sort(myPositionGroup.goodsList, self.m_myPositionGoodsSortFunc)
end





ShopTradeCtrl._UpdateBulkSellData = HL.Method() << function(self)
    local myPositionGroup
    local moneyId
    local moneyIcon
    if self.m_isLocalShop then
        
        myPositionGroup = self.m_localShopInfo.myPositionGoodsGroup
        moneyId = self.m_domainInfo.moneyId
        moneyIcon = self.m_domainInfo.moneyIcon
    else
        
        local shopInfo = self.m_friendShopInfoList[self.m_curSelectFriendShopIndex]
        myPositionGroup = shopInfo.myPositionGoodsGroup
        moneyId = shopInfo.moneyId
        moneyIcon = shopInfo.moneyIcon
    end
    self.m_bulkSellInfo = {
        goodsList = myPositionGroup.goodsList,
        profitInfo = {
            moneyId = moneyId,
            moneyIcon = moneyIcon,
            moneyCount = myPositionGroup.totalPrice,
            profit = myPositionGroup.totalProfit,
            profitRatio = myPositionGroup.totalProfitRatio,
        },
        selectCountList = {},
        totalReward = 0,
        curFocusGoodsIndex = 0,
    }
end







ShopTradeCtrl._InitUI = HL.Method() << function(self)
    
    self.view.domainTopMoneyTitle.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
        if self.m_onCloseCallBack then
            self.m_onCloseCallBack()
            self.m_onCloseCallBack = nil
        end
    end)
    self.view.goodsNode.bulkSellBtn.onClick:AddListener(function()
        self:_ShowBulkSellNode(true)
        self:_UpdateBulkSellData()
        self:_RefreshBulkSellUI()
    end)
    self.m_goodsTagCellCache = UIUtils.genCellCache(self.view.goodsNode.goodsTagCell)
    self.m_getGoodsGroupCellFunc = UIUtils.genCachedCellFunction(self.view.goodsNode.goodsGroupList)
    self.view.goodsNode.goodsGroupList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getGoodsGroupCellFunc(obj)
        self:_OnRefreshGoodsGroupCell(cell, LuaIndex(csIndex))
    end)
    
    local preActionId = self.view.tabNode.previousKeyHint.actionId
    local nextActionId = self.view.tabNode.nextKeyHint.actionId
    self.m_bindIdPreTab = UIUtils.bindInputPlayerAction(preActionId, function()
        if self.m_isLocalShop then
            local hasRandomTab = #self.m_localShopInfo.randomShopInfo.goodsGroupList > 0
            if not hasRandomTab then
                return  
            end
            self:_OnChangeSelectLocalShop(not self.m_isSelectCommonShop)
            AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
            self:_NotifyClientCondition()
        else
            local count = #self.m_friendShopInfoList
            local newIndex = (self.m_curSelectFriendShopIndex + count - 2) % count + 1
            if newIndex ~= self.m_curSelectFriendShopIndex then
                self:_OnChangeSelectFriendShop(newIndex)
                AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    self.m_bindIdNextTab = UIUtils.bindInputPlayerAction(nextActionId, function()
        if self.m_isLocalShop then
            local hasRandomTab = #self.m_localShopInfo.randomShopInfo.goodsGroupList > 0
            if not hasRandomTab then
                return  
            end
            self:_OnChangeSelectLocalShop(not self.m_isSelectCommonShop)
            AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
            self:_NotifyClientCondition()
        else
            local count = #self.m_friendShopInfoList
            local newIndex = self.m_curSelectFriendShopIndex % count + 1
            if newIndex ~= self.m_curSelectFriendShopIndex then
                self:_OnChangeSelectFriendShop(newIndex)
                AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    
    self.view.tabNode.shopCommonTab.selectBtn.onClick:AddListener(function()
        if self.m_isSelectCommonShop == false then
            self:_OnChangeSelectLocalShop(true)
            self:_NotifyClientCondition()
        end
    end)
    self.view.tabNode.shopRandomTab.selectBtn.onClick:AddListener(function()
        if self.m_isSelectCommonShop == true then
            self:_OnChangeSelectLocalShop(false)
            self:_NotifyClientCondition()
        end
    end)
    
    self.m_friendTabCellCache = UIUtils.genCellCache(self.view.tabNode.shopFriendTabCell)
    self.view.tabNode.friendRecordBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.SpaceshipSalesRecords)
    end)
    
    local bulkSellNode = self.view.bulkSellNode
    bulkSellNode.closeBtn.onClick:AddListener(function()
        self:_ShowBulkSellNode(false)
    end)
    bulkSellNode.confirmBtn.onClick:AddListener(function()
        self:_OnConfirmBulkSellGoods()
    end)
    self.m_getBulkSellGoodsCellFunc = UIUtils.genCachedCellFunction(bulkSellNode.goodsList)
    bulkSellNode.goodsList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getBulkSellGoodsCellFunc(obj)
        self:_OnRefreshBulkSellGoodsCell(cell, LuaIndex(csIndex))
    end)
    self:_ShowBulkSellNode(false)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



ShopTradeCtrl._BindingControllerOperate = HL.Method() << function(self)
    
    if not self.m_isLocalShop then
        return
    end
    UIUtils.bindInputPlayerAction("shop_domain_navigation_4_dir_up_no_hint", function()
        local curTagIndex = self.m_curSelectTagIndex
        if self.m_isNaviTag then
            if curTagIndex <= 1 then
                return
            end
            
            local newIndex = curTagIndex - 1
            local tagCell = self.m_goodsTagCellCache:Get(newIndex)
            InputManagerInst.controllerNaviManager:SetTarget(tagCell.tagBtn)
            InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, false)
        else
            
            local goodsGroupCell = self.m_getGoodsGroupCellFunc(curTagIndex)
            if goodsGroupCell then
                
                local gridLayout = goodsGroupCell.view.goodsListGridLayout
                local lineMaxCellCount = self:_GetGridLayoutGroupHorizontalMaxCellCount(gridLayout)
                local newIndex = self.m_curNaviLocalGoodsIndex - lineMaxCellCount 
                if newIndex <= 0 then
                    
                    if curTagIndex > 1 then
                        local newTagIndex = curTagIndex - 1
                        goodsGroupCell = self.m_getGoodsGroupCellFunc(newTagIndex)
                        if not goodsGroupCell then
                            return
                        end
                        local preGroupTotalCellCount = goodsGroupCell.m_goodsCellCache:GetCount()
                        if not goodsGroupCell or preGroupTotalCellCount < 1 then
                            return
                        end
                        local indexInThisLine = (self.m_curNaviLocalGoodsIndex - 1) % lineMaxCellCount + 1
                        local preGroupListLineCount = math.floor(preGroupTotalCellCount / lineMaxCellCount) + 1
                        local preGroupLastLineCellCount = preGroupTotalCellCount % lineMaxCellCount
                        local preGroupPreLastLineTotalCellCount = (preGroupListLineCount - 1) * lineMaxCellCount
                        newIndex = math.min(preGroupPreLastLineTotalCellCount + indexInThisLine, preGroupPreLastLineTotalCellCount + preGroupLastLineCellCount)
                        self:_OnChangeSelectTagUI(newTagIndex)
                    else
                        return
                    end
                end
                
                local goodsCell = goodsGroupCell.m_goodsCellCache:Get(newIndex)
                if goodsCell then
                    self.m_curNaviLocalGoodsIndex = newIndex
                    InputManagerInst.controllerNaviManager:SetTarget(goodsCell.view.selectBtn)
                end
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    UIUtils.bindInputPlayerAction("shop_domain_navigation_4_dir_down", function()
        local curTagIndex = self.m_curSelectTagIndex
        if self.m_isNaviTag then
            if curTagIndex >= self.m_goodsTagCellCache:GetCount() then
                return
            end
            
            local newIndex = curTagIndex + 1
            local tagCell = self.m_goodsTagCellCache:Get(newIndex)
            InputManagerInst.controllerNaviManager:SetTarget(tagCell.tagBtn)
            InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, false)
        else
            
            local goodsGroupCell = self.m_getGoodsGroupCellFunc(curTagIndex)
            if goodsGroupCell then
                
                local gridLayout = goodsGroupCell.view.goodsListGridLayout
                local lineMaxCellCount = self:_GetGridLayoutGroupHorizontalMaxCellCount(gridLayout)
                local newIndex = self.m_curNaviLocalGoodsIndex + lineMaxCellCount 
                local curGroupTotalCellCount = goodsGroupCell.m_goodsCellCache:GetCount()
                if newIndex > curGroupTotalCellCount then
                    
                    local curGroupLastLineCellCount = curGroupTotalCellCount % lineMaxCellCount
                    local isNotLastLine = (self.m_curNaviLocalGoodsIndex + curGroupLastLineCellCount) <= curGroupTotalCellCount
                    if isNotLastLine then
                        newIndex = curGroupTotalCellCount
                    end
                end
                if newIndex > goodsGroupCell.m_goodsCellCache:GetCount() then
                    
                    if curTagIndex < self.m_goodsTagCellCache:GetCount() then
                        local newTagIndex = curTagIndex + 1
                        goodsGroupCell = self.m_getGoodsGroupCellFunc(newTagIndex)
                        if not goodsGroupCell then
                            return
                        end
                        local nextGroupTotalGoodsCount = goodsGroupCell.m_goodsCellCache:GetCount()
                        if not goodsGroupCell or nextGroupTotalGoodsCount < 1 then
                            return
                        end
                        
                        local indexInThisLine = (self.m_curNaviLocalGoodsIndex - 1) % lineMaxCellCount + 1
                        newIndex = math.min(indexInThisLine, nextGroupTotalGoodsCount)
                        self:_OnChangeSelectTagUI(newTagIndex)
                    else
                        return
                    end
                end
                
                local goodsCell = goodsGroupCell.m_goodsCellCache:Get(newIndex)
                if goodsCell then
                    self.m_curNaviLocalGoodsIndex = newIndex
                    InputManagerInst.controllerNaviManager:SetTarget(goodsCell.view.selectBtn)
                end
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    UIUtils.bindInputPlayerAction("shop_domain_navigation_4_dir_left", function()
        if not self.m_isNaviTag then
            local goodsGroupCell = self.m_getGoodsGroupCellFunc(self.m_curSelectTagIndex)
            if not goodsGroupCell then
                return
            end
            
            
            local gridLayout = goodsGroupCell.view.goodsListGridLayout
            local isLeftmost = (self.m_curNaviLocalGoodsIndex - 1) % self:_GetGridLayoutGroupHorizontalMaxCellCount(gridLayout) == 0
            if isLeftmost then
                
                self:_LocalShopStopFocusGoods()
            else
                
                local newIndex = self.m_curNaviLocalGoodsIndex - 1 
                if newIndex <= 0 then
                    
                    return
                end
                
                local goodsCell = goodsGroupCell.m_goodsCellCache:Get(newIndex)
                if goodsCell then
                    self.m_curNaviLocalGoodsIndex = newIndex
                    InputManagerInst.controllerNaviManager:SetTarget(goodsCell.view.selectBtn)
                end
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    UIUtils.bindInputPlayerAction("shop_domain_navigation_4_dir_right", function()
        if self.m_isNaviTag then
            
            self:_LocalShopFocusGoods()
        else
            
            local goodsGroupCell = self.m_getGoodsGroupCellFunc(self.m_curSelectTagIndex)
            if not goodsGroupCell then
                return
            end
            
            local newIndex = self.m_curNaviLocalGoodsIndex + 1 
            if newIndex > goodsGroupCell.m_goodsCellCache:GetCount() then
                
                return
            end
            
            local goodsCell = goodsGroupCell.m_goodsCellCache:Get(newIndex)
            if goodsCell then
                self.m_curNaviLocalGoodsIndex = newIndex
                InputManagerInst.controllerNaviManager:SetTarget(goodsCell.view.selectBtn)
            end
        end
    end, self.view.goodsNode.inputGroup.groupId)
    self.m_bindIdFocus = UIUtils.bindInputPlayerAction("shop_domain_manual_focus", function()
        if self.m_isNaviTag then
            self:_LocalShopFocusGoods()
        end
    end, self.view.goodsNode.inputGroup.groupId)
    self.m_bindIdStopFocus = UIUtils.bindInputPlayerAction("common_stop_focus", function()
        if not self.m_isNaviTag then
            self:_LocalShopStopFocusGoods()
        end
    end, self.view.goodsNode.inputGroup.groupId)
    InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, false)
end




ShopTradeCtrl._GetGridLayoutGroupHorizontalMaxCellCount = HL.Method(CS.UnityEngine.UI.GridLayoutGroup).Return(HL.Number) << function(self, gridLayout)
    
    local rectTransform = gridLayout.transform
    
    local availableWidth = rectTransform.rect.width - gridLayout.padding.left - gridLayout.padding.right;
    
    local totalWidthPerCell = gridLayout.cellSize.x + gridLayout.spacing.x;
    
    local cellsPerRow = math.floor((availableWidth + gridLayout.spacing.x) / totalWidthPerCell);
    
    return math.max(1, cellsPerRow);
end



ShopTradeCtrl._LocalShopFocusGoods = HL.Method() << function(self)
    local goodsGroupCell = self.m_getGoodsGroupCellFunc(self.m_curSelectTagIndex)
    if goodsGroupCell.m_goodsCellCache:GetCount() <= 0 then
        
        local newTagIndex = self.m_curSelectTagIndex + 1
        goodsGroupCell = self.m_getGoodsGroupCellFunc(newTagIndex)
        self:_OnChangeSelectTagUI(newTagIndex)
    end
    if goodsGroupCell then
        
        local goodsCell = goodsGroupCell.m_goodsCellCache:Get(1)
        if goodsCell then
            self.m_curNaviLocalGoodsIndex = 1
            InputManagerInst.controllerNaviManager:SetTarget(goodsCell.view.selectBtn)
            self.m_isNaviTag = false
            InputManagerInst:ToggleBinding(self.m_bindIdFocus, false)
            InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, true)
        end
    end
end



ShopTradeCtrl._LocalShopStopFocusGoods = HL.Method() << function(self)
    self.m_isNaviTag = true
    local tagCell = self.m_goodsTagCellCache:Get(self.m_curSelectTagIndex)
    InputManagerInst.controllerNaviManager:SetTarget(tagCell.tagBtn)
    InputManagerInst:ToggleBinding(self.m_bindIdFocus, true)
    InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, false)
end



ShopTradeCtrl._RefreshAllUI = HL.Method() << function(self)
    if self.m_isLocalShop then
        self.view.shopStateCtrl:SetState("LocalShop")
        self:_RefreshLocalShopTabUI()
        self:_OnChangeSelectLocalShop(true, true)
        local tabNode = self.view.tabNode
        tabNode.titleBgImg:LoadSprite(UIConst.UI_SPRITE_SHOP_TRADE_AREA_BG, self.m_localShopInfo.bgImg)
        if not string.isEmpty(self.m_localShopInfo.icon) and #self.m_localShopInfo.icon > 0 and not self.m_showFriendRecord then
            tabNode.locationIconImg.gameObject:SetActive(true)
            tabNode.locationIconImg:LoadSprite(UIConst.UI_SPRITE_SHOP_TRADE_AREA_ICON, self.m_localShopInfo.icon)
        else
            tabNode.locationIconImg.gameObject:SetActive(false)
        end

        tabNode.friendRecordBtn.gameObject:SetActive(self.m_showFriendRecord)
        
        self.view.goodsNode.goodsGroupList.onEndDrag:RemoveAllListeners()
        self.view.goodsNode.goodsGroupList.onEndDrag:AddListener(function()
            self.m_waitAutoScrollTagListTime = 0
        end)
        local domainInfo = self.m_domainInfo
        self:_RefreshTitleMoneyUI(self.m_domainId, domainInfo.moneyId)
    else
        self.view.shopStateCtrl:SetState("FriendShop")
        local shopCount = #self.m_friendShopInfoList
        
        self.m_friendTabCellCache:Refresh(shopCount, function(cell, luaIndex)
            self:_OnUpdateFriendTabCell(cell, luaIndex)
        end)
        self.view.tabNode.previousKeyHintParent.gameObject:SetActive(shopCount > 1)
        self.view.tabNode.nextKeyHintParent.gameObject:SetActive(shopCount > 1)
        self.view.tabNode.friendPreviousKeyHint.gameObject:SetActive(shopCount > 1)
        self.view.tabNode.friendNextKeyHint.gameObject:SetActive(shopCount > 1)
        
        self:_OnChangeSelectFriendShop(1)
    end
end





ShopTradeCtrl._RefreshTitleMoneyUI = HL.Method(HL.String, HL.String) << function(self, domainId, moneyId)
    local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    local _, domainDevData = GameInstance.player.domainDevelopmentSystem.domainDevDataDic:TryGetValue(domainId)
    local maxCount = domainDevData.curLevelData.moneyLimit
    self.view.domainTopMoneyTitle:InitDomainTopMoneyTitle(moneyId, maxCount)
    if self.m_isLocalShop then
        self.view.domainTopMoneyTitle.view.titleTxt.text = string.format(Language.LUA_DOMAIN_SHOP_TITLE, domainCfg.domainName)
    else
        self.view.domainTopMoneyTitle.view.titleTxt.text = Language.LUA_DOMAIN_SHOP_FRIEND_TITLE
    end
end





ShopTradeCtrl._OnRefreshGoodsGroupCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    cell:InitShopTradeGoodsGroupCell()
    cell.gameObject.name = "GoodsGroupCell_" .. luaIndex
    if self.m_isLocalShop then
        if self.m_isSelectCommonShop then
            self:_RefreshGoodsGroupCellCommonMode(cell, luaIndex)
        else
            self:_RefreshGoodsGroupCellRandomMode(cell, luaIndex)
        end
    else
        self:_RefreshGoodsGroupCellFriendMode(cell, luaIndex)
    end
end





ShopTradeCtrl._OnRefreshGoodsTagCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local groupInfo
    local isLastIndex = false
    if self.m_isSelectCommonShop then
        groupInfo = self.m_localShopInfo.commonShopInfo.goodsGroupList[luaIndex]
        isLastIndex = #self.m_localShopInfo.commonShopInfo.goodsGroupList == luaIndex
    else
        if luaIndex == 1 then
            groupInfo = self.m_localShopInfo.myPositionGoodsGroup
        else
            groupInfo = self.m_localShopInfo.randomShopInfo.goodsGroupList[luaIndex - 1]
            isLastIndex = #self.m_localShopInfo.randomShopInfo.goodsGroupList == luaIndex - 1
        end
    end
    cell.connectLineImg.enabled = not isLastIndex
    cell.tagIconImg:LoadSprite(UIConst.UI_SPRITE_SHOP_TAG_ICON, groupInfo.tagIcon)
    cell.animationWrapper:ClearTween()
    cell.animationWrapper:Play(self.m_curSelectTagIndex == luaIndex and "shoptrade_goodstagcell_select" or "shoptrade_goodstagcell_noselect")
    cell.tagBtn.onClick:RemoveAllListeners()
    cell.tagBtn.onClick:AddListener(function()
        self:_OnClickGoodsTagCell(luaIndex)
    end)
    cell.tagBtn.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            self:_OnClickGoodsTagCell(luaIndex)
        end
    end
    
    cell.gameObject.name = "tag_" .. groupInfo.tagId
end




ShopTradeCtrl._OnClickGoodsTagCell = HL.Method(HL.Number) << function(self, luaIndex)
    if self.m_curSelectTagIndex ~= luaIndex then
        self:_OnChangeSelectTagUI(luaIndex)
        self.view.goodsNode.goodsGroupList:ScrollToIndex(CSIndex(luaIndex), true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
    end
end




ShopTradeCtrl._RefreshLocalShopTabUI = HL.Method() << function(self)
    local randomTab = self.view.tabNode.shopRandomTab
    local hasRandomTab = #self.m_localShopInfo.randomShopInfo.goodsGroupList > 0
    self.view.tabNode.previousKeyHintParent.gameObject:SetActive(hasRandomTab)
    self.view.tabNode.nextKeyHintParent.gameObject:SetActive(hasRandomTab)
    if not hasRandomTab then
        randomTab.gameObject:SetActive(false)
    else
        randomTab.gameObject:SetActive(true)
        
        local profitRatio = self.m_localShopInfo.myPositionGoodsGroup.totalProfitRatio
        local stateName = DomainShopUtils.getProfitArrowStateName(profitRatio)
        randomTab.profitTxt.text = math.abs(profitRatio)
        randomTab.profitArrowStateCtrl:SetState(stateName)
        local count = #self.m_localShopInfo.myPositionGoodsGroup.goodsList
        randomTab.profitLossInfo.gameObject:SetActive(count > 0)
    end
end




ShopTradeCtrl._RefreshLocalShopGoodsUI = HL.Method(HL.Boolean) << function(self, isChangeTab)
    local count
    local isCommonShop = self.m_isSelectCommonShop
    self.view.goodsNode.remainLimitCountNode.gameObject:SetActive(false)
    self._updateLimitCountTimeKey = LuaUpdate:Remove(self._updateLimitCountTimeKey)
    if isCommonShop then
        count = #self.m_localShopInfo.commonShopInfo.goodsGroupList
    else
        count = #self.m_localShopInfo.randomShopInfo.goodsGroupList + 1
        self:_RefreshLimitCount()
        self._updateLimitCountTimeKey = LuaUpdate:Add("LateTick", function(deltaTime)
            if self._nextUpdateLimitCountTime <= Time.time then
                self._nextUpdateLimitCountTime = Time.time + 1
                self:_RefreshLimitCount()
            end
        end)
    end
    local hasPosition = #self.m_localShopInfo.myPositionGoodsGroup.goodsList > 0
    self.view.goodsNode.bulkSellBtnNode.gameObject:SetActive(not isCommonShop and hasPosition)
    self.view.goodsNode.goodsGroupList:UpdateCount(count, isChangeTab)
    if isChangeTab then
        self.m_curSelectTagIndex = 1
    end
    
    self.m_goodsTagCellCache:Refresh(count, function(cell, luaIndex)
        self:_OnRefreshGoodsTagCell(cell, luaIndex)
    end)
end





ShopTradeCtrl._RefreshLocalShopTabAni = HL.Method(HL.Boolean, HL.Boolean) << function(self, isCommonShop, isReset)
    if isReset then
        self.view.tabNode.shopCommonTab.animationWrapper:Play(isCommonShop and "shopmarkettab_in" or "shopmarkettab_reset")
        self.view.tabNode.shopRandomTab.animationWrapper:Play(not isCommonShop and "shopmarkettab_in" or "shopmarkettab_reset")
    else
        self.view.tabNode.shopCommonTab.animationWrapper:Play(isCommonShop and "shopmarkettab_in" or "shopmarkettab_out")
        self.view.tabNode.shopRandomTab.animationWrapper:Play(not isCommonShop and "shopmarkettab_in" or "shopmarkettab_out")
    end
end






ShopTradeCtrl._RefreshGoodsGroupCellCommonMode = HL.Method(HL.Forward("ShopTradeGoodsGroupCell"), HL.Number) << function(self, cell, luaIndex)
    local groupInfo = self.m_localShopInfo.commonShopInfo.goodsGroupList[luaIndex]
    cell:SetTitleCommonUI(groupInfo.tagName, groupInfo.tagIcon, false)
    cell.view.groupStateCtrl:SetState("Normal")
    
    cell.m_goodsCellCache:Refresh(#groupInfo.goodsList, function(goodsCell, index)
        local goodsInfo = groupInfo.goodsList[index]
        goodsCell:InitShopTradeGoodsCellCommonMode(goodsInfo)
        goodsCell.gameObject.name = "GoodsCell_" .. index
    end)
end







ShopTradeCtrl._RefreshGoodsGroupCellRandomMode = HL.Method(HL.Forward("ShopTradeGoodsGroupCell"), HL.Number) << function(self, cell, luaIndex)
    
    local groupInfo
    if luaIndex == 1 then
        groupInfo = self.m_localShopInfo.myPositionGoodsGroup
        cell:SetTitleCommonUI(groupInfo.tagName, groupInfo.tagIcon, true)
        local goodsCount = #groupInfo.goodsList
        if goodsCount <= 0 then
            cell.view.groupStateCtrl:SetState("EmptyPosition")
            cell.m_goodsCellCache:Refresh(0)
        else
            cell.view.groupStateCtrl:SetState("HasPosition")
            
            local profitInfo = {
                moneyIcon = self.m_domainInfo.moneyIcon,
                moneyCount = self.m_localShopInfo.myPositionGoodsGroup.totalPrice,
                profit = self.m_localShopInfo.myPositionGoodsGroup.totalProfit,
                profitRatio = self.m_localShopInfo.myPositionGoodsGroup.totalProfitRatio,
            }
            DomainShopUtils.refreshTotalMyPositionDetail(cell.view.myPositionDetail, profitInfo)
            
            cell.m_goodsCellCache:Refresh(goodsCount, function(goodsCell, index)
                local goodsInfo = groupInfo.goodsList[index]
                goodsCell:InitShopTradeGoodsCellRandomMode(goodsInfo, true)
                goodsCell.gameObject.name = "GoodsCell_" .. index
            end)
        end
    else
        groupInfo = self.m_localShopInfo.randomShopInfo.goodsGroupList[luaIndex - 1]
        cell:SetTitleCommonUI(groupInfo.tagName, groupInfo.tagIcon, false)
        cell.view.groupStateCtrl:SetState("Normal")
        
        local goodsCount = #groupInfo.goodsList
        cell.m_goodsCellCache:Refresh(goodsCount, function(goodsCell, index)
            local goodsInfo = groupInfo.goodsList[index]
            goodsCell:InitShopTradeGoodsCellRandomMode(goodsInfo, false)
            goodsCell.gameObject.name = "GoodsCell_" .. index
        end)
    end
end



ShopTradeCtrl._RefreshLimitCount = HL.Method() << function(self)
    self.view.goodsNode.remainLimitCountNode.gameObject:SetActive(true)
    local shopId = self.m_localShopInfo.randomShopInfo.shopId
    local shopGroupId = shopSystem:GetShopGroupIdByShopId(shopId)
    local groupData = shopSystem:GetShopGroupData(shopGroupId)
    local remainLimitCount = self.m_localShopInfo.randomShopInfo.remainLimitCount
    local limitUpCount = groupData.domainChannelData.buyRandomGoodsLimitUpCount
    local maxLimitCount = groupData.domainChannelData.buyRandomGoodsLimitCount
    local limitCountNode = self.view.goodsNode.remainLimitCountNode
    limitCountNode.limitCountTxt.text = remainLimitCount .. "/" .. maxLimitCount
    
    local diff = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(GEnums.ShopFrequencyLimitType.Daily)
    if diff >= 0 then
        limitCountNode.refreshCountdown.gameObject:SetActive(true)
        limitCountNode.refreshTimeTxt.text = string.format(Language.LUA_TRADE_ITEM_REFRESH_LEFT_TIME, UIUtils.getShortLeftTime(diff))
        limitCountNode.refreshCountTxt.text = string.format("+%d", limitUpCount)
        
        local willOverflow = (remainLimitCount + limitUpCount) > maxLimitCount
        limitCountNode.refreshCountdownState:SetState(willOverflow and "Overflow" or "Normal")
    else
        limitCountNode.refreshCountdown.gameObject:SetActive(false)
    end
end









ShopTradeCtrl._OnUpdateFriendTabCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local info = self.m_friendShopInfoList[luaIndex]
    cell.tabNameTxt.text = info.domainName
    cell.tabIconImg:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT, info.domainIcon)
    cell.tabBigIconImg:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT_ICON_BIG, info.domainIcon)
    cell.animationWrapper:Play("friendmarkettab_reset")
    
    cell.selectBtn.onClick:RemoveAllListeners()
    cell.selectBtn.onClick:AddListener(function()
        if self.m_curSelectFriendShopIndex ~= luaIndex then
            self:_OnChangeSelectFriendShop(luaIndex)
        end
    end)
end




ShopTradeCtrl._RefreshFriendShopGoodsUI = HL.Method(HL.Boolean) << function(self, isInit)
    
    local shopInfo = self.m_friendShopInfoList[self.m_curSelectFriendShopIndex]
    local count = #shopInfo.goodsGroupList
    self.view.goodsNode.goodsGroupList:UpdateCount(count, isInit)
    
    local hasPosition = #shopInfo.myPositionGoodsGroup.goodsList > 0
    self.view.goodsNode.bulkSellBtnNode.gameObject:SetActive(hasPosition)
    
    local groupObj = self.view.goodsNode.goodsGroupList:Get(0)
    
    local groupCell = self.m_getGoodsGroupCellFunc(groupObj)
    if groupCell then
        local cell = groupCell.m_goodsCellCache:Get(1)
        if cell then
            InputManagerInst.controllerNaviManager:SetTarget(cell.view.selectBtn)
        end
    end
end





ShopTradeCtrl._RefreshGoodsGroupCellFriendMode = HL.Method(HL.Forward("ShopTradeGoodsGroupCell"), HL.Number) << function(self, cell, luaIndex)
    local shopInfo = self.m_friendShopInfoList[self.m_curSelectFriendShopIndex]
    local groupInfo = shopInfo.goodsGroupList[luaIndex]
    
    cell:SetTitleCommonUI(groupInfo.tagName, groupInfo.tagIcon, luaIndex == 1)
    
    cell.view.groupStateCtrl:SetState("HasPosition")
    local profitInfo = {
        moneyIcon = shopInfo.moneyIcon,
        moneyCount = shopInfo.myPositionGoodsGroup.totalPrice,
        profit = shopInfo.myPositionGoodsGroup.totalProfit,
        profitRatio = shopInfo.myPositionGoodsGroup.totalProfitRatio,
    }
    DomainShopUtils.refreshTotalMyPositionDetail(cell.view.myPositionDetail, profitInfo)
    
    local goodsCount = #groupInfo.goodsList
    cell.m_goodsCellCache:Refresh(goodsCount, function(goodsCell, index)
        local goodsInfo = groupInfo.goodsList[index]
        goodsCell:InitShopTradeGoodsCellFriendMode(goodsInfo)
        goodsCell.gameObject.name = "GoodsCell_" .. index
    end)
end





ShopTradeCtrl._RefreshBulkSellUI = HL.Method() << function(self)
    
    local bulkSellNode = self.view.bulkSellNode
    DomainShopUtils.refreshTotalMyPositionDetail(bulkSellNode.myPositionDetail, self.m_bulkSellInfo.profitInfo)
    
    local goodsCount = #self.m_bulkSellInfo.goodsList
    bulkSellNode.goodsList:UpdateCount(goodsCount, true)
    
    self:_RefreshBulkSellSelectState()
    local obj = bulkSellNode.goodsList:Get(0)
    local cell = self.m_getBulkSellGoodsCellFunc(obj)
    if cell then
        InputManagerInst.controllerNaviManager:SetTarget(cell.view.selectBtn)
    end
end




ShopTradeCtrl._OnSelectBulkSellGoods = HL.Method(HL.Number) << function(self, luaIndex)
    local bulkInfo = self.m_bulkSellInfo
    local oldIndex = bulkInfo.curFocusGoodsIndex
    local oldObj = self.view.bulkSellNode.goodsList:Get(CSIndex(oldIndex))
    local newObj = self.view.bulkSellNode.goodsList:Get(CSIndex(luaIndex))
    
    local oldCell = self.m_getBulkSellGoodsCellFunc(oldObj)
    
    local newCell = self.m_getBulkSellGoodsCellFunc(newObj)
    
    if oldIndex == luaIndex then
        
        bulkInfo.curFocusGoodsIndex = 0
        local count = bulkInfo.selectCountList[oldIndex]
        local reward = bulkInfo.goodsList[oldIndex].todayPrice * count
        bulkInfo.totalReward = bulkInfo.totalReward - reward
        bulkInfo.selectCountList[oldIndex] = nil
        if oldCell then
            oldCell:SetSelectCount(0)
            oldCell:SetSelectState(false)
        end
    else
        
        bulkInfo.curFocusGoodsIndex = luaIndex
        local curCount = bulkInfo.selectCountList[luaIndex]
        if curCount == nil then
            
            curCount = 1
            bulkInfo.selectCountList[luaIndex] = 1
            bulkInfo.totalReward = bulkInfo.totalReward + bulkInfo.goodsList[luaIndex].todayPrice
        end
        if oldCell then
            oldCell:SetSelectState(false)
        end
        if newCell then
            newCell:SetSelectCount(curCount)
            newCell:SetSelectState(true)
        end
    end
    
    self.view.bulkSellNode.goodsList:ScrollToIndex(CSIndex(luaIndex))
    self:_RefreshBulkSellSelectState()
end



ShopTradeCtrl._RefreshBulkSellSelectState = HL.Method() << function(self)
    local bulkSellNode = self.view.bulkSellNode
    local curIndex = self.m_bulkSellInfo.curFocusGoodsIndex
    if curIndex == 0 then
        bulkSellNode.selectStateCtrl:SetState("noSelect")
        return
    end
    
    bulkSellNode.selectStateCtrl:SetState("hasSelect")
    local goodsInfo = self.m_bulkSellInfo.goodsList[curIndex]
    bulkSellNode.goodsName.text = goodsInfo.itemName
    bulkSellNode.avgPriceTxt.text = goodsInfo.positionAvgPrice
    bulkSellNode.curPriceTxt.text = goodsInfo.todayPrice
    bulkSellNode.curPriceRatioTxt.text = goodsInfo.profitRatio
    bulkSellNode.profitArrowStateCtrl:SetState(DomainShopUtils.getProfitArrowStateName(goodsInfo.profitRatio))
    bulkSellNode.moneyIcon1:LoadSprite(UIConst.UI_SPRITE_WALLET, goodsInfo.moneyIcon)
    bulkSellNode.moneyIcon2:LoadSprite(UIConst.UI_SPRITE_WALLET, goodsInfo.moneyIcon)
    bulkSellNode.moneyIcon3:LoadSprite(UIConst.UI_SPRITE_WALLET, goodsInfo.moneyIcon)
    
    bulkSellNode.totalRewardMoneyTxt.text = self.m_bulkSellInfo.totalReward
    local selectCount = self.m_bulkSellInfo.selectCountList[curIndex]
    bulkSellNode.numberSelector:InitNumberSelector(selectCount, 1, goodsInfo.itemCount, self.m_onSelectorNumberChanged)
end





ShopTradeCtrl._OnRefreshBulkSellGoodsCell = HL.Method(HL.Forward("ShopTradeGoodsCell"), HL.Number) << function(self, cell, luaIndex)
    local info = self.m_bulkSellInfo.goodsList[luaIndex]
    cell:InitShopTradeGoodsCellBulkSellMode(info, luaIndex, self.m_onClickBulkSellGoods)
    cell.gameObject.name = "GoodsCell_" .. luaIndex
end









ShopTradeCtrl._OnChangeSelectLocalShop = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isCommonShop, isInit)
    shopSystem:SetGoodsIdSee()
    
    self.m_isSelectCommonShop = isCommonShop
    if isCommonShop then
        self.view.goodsNode.stateController:SetState("ShopCommon")
        self:_UpdateCommonShopData()
    else
        self.view.goodsNode.stateController:SetState("ShopRandom")
        self:_UpdateRandomShopData()
    end
    
    self:_RefreshLocalShopGoodsUI(true)
    self:_RefreshLocalShopTabAni(isCommonShop, not not isInit)
    local cell = self.m_goodsTagCellCache:Get(self.m_curSelectTagIndex)
    if cell then
        InputManagerInst.controllerNaviManager:SetTarget(cell.tagBtn)
        InputManagerInst:ToggleBinding(self.m_bindIdStopFocus, false)
        self.m_isNaviTag = true
    end
end




ShopTradeCtrl._OnChangeSelectTagUI = HL.Method(HL.Number) << function(self, newIndex)
    local oldIndex = self.m_curSelectTagIndex
    self.m_curSelectTagIndex = newIndex
    local oldCell = self.m_goodsTagCellCache:Get(oldIndex)
    if oldCell then
        oldCell.animationWrapper:Play("shoptrade_goodstagcell_noselect")
    end
    local newCell = self.m_goodsTagCellCache:Get(newIndex)
    if newCell then
        newCell.animationWrapper:Play("shoptrade_goodstagcell_select")
    end
end




ShopTradeCtrl._OnChangeSelectFriendShop = HL.Method(HL.Number) << function(self, luaIndex)
    
    local oldIndex = self.m_curSelectFriendShopIndex
    self.m_curSelectFriendShopIndex = luaIndex
    
    local oldCell = self.m_friendTabCellCache:Get(oldIndex)
    if oldCell then
        oldCell.animationWrapper:Play("friendmarkettab_out")
    end
    local newCell = self.m_friendTabCellCache:Get(luaIndex)
    if newCell then
        newCell.animationWrapper:Play("friendmarkettab_in")
    end
    
    local shopInfo = self.m_friendShopInfoList[luaIndex]
    self:_RefreshFriendShopGoodsUI(true)
    
    self:_RefreshTitleMoneyUI(shopInfo.domainId, shopInfo.moneyId)
end





ShopTradeCtrl._OnChangeBulkSellSelectCount = HL.Method(HL.Number, HL.Boolean) << function(self, curNumber, changeFromCode)
    local bulkInfo = self.m_bulkSellInfo
    local curIndex = bulkInfo.curFocusGoodsIndex
    local goodsInfo = bulkInfo.goodsList[curIndex]
    local oldCount = bulkInfo.selectCountList[curIndex]
    
    if oldCount == nil then
        oldCount = 0
        bulkInfo.selectCountList[curIndex] = 0
    end
    local countDiff = curNumber - oldCount
    bulkInfo.selectCountList[curIndex] = curNumber
    bulkInfo.totalReward = bulkInfo.totalReward + goodsInfo.todayPrice * countDiff
    
    self.view.bulkSellNode.totalRewardMoneyTxt.text = bulkInfo.totalReward
    if changeFromCode then
        self.view.bulkSellNode.numberSelector:RefreshNumber(
            curNumber,
            1,
            goodsInfo.itemCount
        )
    end
    local obj = self.view.bulkSellNode.goodsList:Get(CSIndex(curIndex))
    
    local cell = self.m_getBulkSellGoodsCellFunc(obj)
    if cell then
        cell:SetSelectCount(curNumber)
    end
end



ShopTradeCtrl._OnConfirmBulkSellGoods = HL.Method() << function(self)
    if self.m_waitBulkSellResp then
        return
    end
    local roleId
    local shopId
    local isSellLocal
    if self.m_isLocalShop then
        roleId = GameInstance.player.roleId
        shopId = self.m_localShopInfo.randomShopInfo.shopId
        isSellLocal = true
    else
        roleId = self.m_friendRoleId
        shopId = self.m_friendShopInfoList[self.m_curSelectFriendShopIndex].shopId
        isSellLocal = false
    end
    
    local goodsIds = {}
    local goodsCountList = {}
    for index, count in pairs(self.m_bulkSellInfo.selectCountList) do
        table.insert(goodsIds, self.m_bulkSellInfo.goodsList[index].goodsId)
        table.insert(goodsCountList, count)
    end
    
    local success = shopSystem:SendSellGoods(roleId, shopId, goodsIds, goodsCountList, isSellLocal)
    if success then
        self.m_waitBulkSellResp = true
    end
end




ShopTradeCtrl._OnBuyItemSuccess = HL.Method(HL.Any) << function(self, msg)
    shopSystem:SetGoodsIdSee()
    if self.m_isLocalShop then
        if self.m_isSelectCommonShop then
            self:_RefreshSingleGoods(msg)
        else
            self:_UpdateData()
            self:_RefreshLocalShopGoodsUI(false)
            self:_RefreshLocalShopTabUI()
        end
    else
        self:_UpdateData()
        self:_RefreshFriendShopGoodsUI(false)
    end
end




ShopTradeCtrl._RefreshSingleGoods = HL.Method(HL.Any) << function(self, msg)
    local unpackMsg = unpack(msg)
    local goodsId = unpackMsg.GoodsId
    
    local searchInfo = self.m_commonShopRefreshGoodsSearchMap[goodsId]
    local goodsInfo = searchInfo.goodsInfo
    local _, goodsCfg = Tables.shopGoodsTable:TryGetValue(goodsId)
    local itemBundle = UIUtils.getRewardFirstItem(goodsCfg.rewardId)
    local itemId = itemBundle.id
    goodsInfo.remainLimitCount = shopSystem:GetRemainCountByGoodsId(unpackMsg.ShopId, goodsId)
    goodsInfo.itemCount = Utils.getItemCount(itemId, true, true)
    goodsInfo.remainLimitSort = goodsInfo.remainLimitCount == 0 and 1 or 0
    
    local goodsGroupCell = self.m_getGoodsGroupCellFunc(searchInfo.groupIndex)
    if goodsGroupCell then
        local goodsCell = goodsGroupCell.m_goodsCellCache:Get(searchInfo.goodsIndex)
        if goodsCell then
            goodsCell:InitShopTradeGoodsCellCommonMode(goodsInfo)
        end
    end
end




ShopTradeCtrl._OnSellItemSuccess = HL.Method(HL.Any) << function(self, msg)
    shopSystem:SetGoodsIdSee()
    if self.m_waitBulkSellResp then
        self.m_waitBulkSellResp = false
        self:_ShowBulkSellNode(false)
        local items = {
            {
                id = self.m_bulkSellInfo.profitInfo.moneyId,
                count = self.m_bulkSellInfo.totalReward,
            }
        }
        
        Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
            title = Language.LUA_SELL_ITEM_SUCC_TITLE,
            icon = "icon_common_rewards",
            items = items,
            onComplete = function()
                Notify(MessageConst.AFTER_ON_BUY_ITEM_SUCC)
            end,
        })
    end
    self:_UpdateData()
    if self.m_isLocalShop then
        self:_RefreshLocalShopGoodsUI(false)
        self:_RefreshLocalShopTabUI()
        self:_NotifyClientCondition()
    else
        self:_RefreshFriendShopGoodsUI(false)
    end
end



ShopTradeCtrl._OnShopRefresh = HL.Method() << function(self)
    if self.m_isLocalShop then
        shopSystem:SetGoodsIdSee()
        self:_UpdateData()
        self:_RefreshAllUI()
    	self:_NotifyClientCondition()
    end
end



ShopTradeCtrl._OnFriendShopRefresh = HL.Method() << function(self)
    if not self.m_isLocalShop then
        shopSystem:SetGoodsIdSee()
        self:_UpdateData()
        self:_RefreshAllUI()
    end
end




ShopTradeCtrl._ShowBulkSellNode = HL.Method(HL.Boolean) << function(self, isShow)
    self.view.bulkSellNode.gameObject:SetActive(isShow)
    InputManagerInst:ToggleGroup(self.view.goodsNode.inputGroup.groupId, not isShow)
    AudioManager.PostEvent(isShow and "Au_UI_Popup_Common_Large_Open" or "Au_UI_Popup_Common_Large_Close")
end




ShopTradeCtrl._UpdateReadInfo = HL.Method(HL.String) << function(self, goodsId)
    shopSystem:RecordSeeGoodsId(goodsId)
end



ShopTradeCtrl._NotifyClientCondition = HL.Method() << function(self)
    local hasSoldOutGroup = self.m_isLocalShop and self.m_isSelectCommonShop and #self.m_localShopInfo.soldOutGoodsGroup.goodsList > 0
    CS.Beyond.Gameplay.Conditions.CheckDomainShopPanelHasSoldOutGroup.Trigger(hasSoldOutGroup)
end



HL.Commit(ShopTradeCtrl)
