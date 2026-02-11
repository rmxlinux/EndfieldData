
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ShopGiftPackEmpty

local MONTHLY_PASS_CASHSHOPID = "MCard"
local NORMAL_CASHSHOP_GIFTPACK_PANEL_ID = PanelId.ShopPackage
local ALL_SHOP_ID = "All" 


local USE_CASH_SHOP_IDS ={
    MCard = 1,
    Seasonal_Rec_pack = 2,
    Permanent_pack = 3,
    Newbie_pack = 4,
    SP_weapon_supply = 5,
}































ShopGiftPackEmptyCtrl = HL.Class('ShopGiftPackEmptyCtrl', uiCtrl.UICtrl)


ShopGiftPackEmptyCtrl.m_tabDataList = HL.Field(HL.Table)


ShopGiftPackEmptyCtrl.m_currTabCashShopId = HL.Field(HL.String) << ""



ShopGiftPackEmptyCtrl.m_isControllerTarget = HL.Field(HL.Boolean) << false



ShopGiftPackEmptyCtrl.m_allGiftPackGoodsByGroup = HL.Field(HL.Table)


ShopGiftPackEmptyCtrl.m_getTabCellFunc = HL.Field(HL.Function)


ShopGiftPackEmptyCtrl.m_needNaviGoodsId = HL.Field(HL.String) << ""



ShopGiftPackEmptyCtrl.m_isInTabClickFunc = HL.Field(HL.Boolean) << false



ShopGiftPackEmptyCtrl.m_haveSeenGoodsId = HL.Field(HL.Table)






ShopGiftPackEmptyCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SDK_PRODUCT_INFO_UPDATE] = '_OnSdkProductInfoUpdate',
    [MessageConst.ON_CASH_SHOP_PLATFORM_DATA_REFRESH] = '_OnCashShopPlatformDataRefresh',
    [MessageConst.CASH_SHOP_NEW_OPEN_GOODS] = '_OnCashShopNewOpenGoods',
    [MessageConst.ON_READ_CASH_SHOP_GOODS] = '_OnReadCashShopGoods',
}





ShopGiftPackEmptyCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_phase = arg.phase

    self.m_phase:ShowPsStore()

    self.m_getTabCellFunc = UIUtils.genCachedCellFunction(self.view.cashShopVerticalTabList.scrollList)
    self.view.cashShopVerticalTabList.scrollList.onUpdateCell:AddListener(function(obj, index)
        local cell = self.m_getTabCellFunc(obj)
        local tabData = self.m_tabDataList[LuaIndex(index)]
        cell.cellNameTxt.text = tabData.name
        cell.cellNameShadownTxt.text = tabData.Name
        cell.toggle.onValueChanged:RemoveAllListeners()
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                self:_OnTabClick(tabData, true)
            end
        end)

        cell.stateController:SetState("NOIcon")

        self:_SetupTabTag(cell, tabData)
    end)

    self.m_haveSeenGoodsId = {}

    self:_InitShortCut()

    self:_InitData()
    self:_RefreshUI()

    if arg ~= nil and arg.cashShopId ~= nil then
        self:ChooseTabByCashShopId(arg.cashShopId, nil, true)
    else
        if string.isEmpty(self.m_currTabCashShopId) then
            self:_SetTabByIndex(1, nil, true)
        end
    end
end





ShopGiftPackEmptyCtrl._SetupTabTag = HL.Method(HL.Any, HL.Table) << function(self, cell, tabData)
    
    
    local goodsIds = {}
    for _, cashGoodsInfo in ipairs(tabData.cashGoodsInfos) do
        table.insert(goodsIds, cashGoodsInfo.goodsId)
    end
    local isNew = CashShopUtils.CheckCashShopNewCashGoodsRedDot(goodsIds)
    cell.cellTagNode.tagNew.gameObject:SetActive(isNew)
    
    if isNew then
        return
    end
    local tagList = tabData.tagList
    local tagRoot = cell.cellTagNode
    for _, tagId in pairs(tagList) do
        local tagData = Tables.CashShopGiftPackTagTable[tagId]
        local style = tagData.style
        local value = tagData.value
        local tagCell = tagRoot[style]
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




ShopGiftPackEmptyCtrl._InitShortCut = HL.Method() << function(self)
    self:BindInputPlayerAction("cashshop_giftpack_goto_right", function()
        self:_OnGoRight()
    end, self.view.cashShopVerticalTabList.groupTarget.groupId)

    self:BindInputPlayerAction("cashshop_giftpack_goto_right_2", function()
        self:_OnGoRight()
    end, self.view.cashShopVerticalTabList.groupTarget.groupId)
end



ShopGiftPackEmptyCtrl._InitData = HL.Method() << function(self)
    self.m_allGiftPackGoodsByGroup = CashShopUtils.GetAllGiftPackGoodsByGroup()
    self.m_tabDataList = {}
    
    local cashShopTabList = {}
    local monthlyPassShopGoodsInfo = nil 
    local allCashGoodsInfos = {}
    for _, groupData in ipairs(self.m_allGiftPackGoodsByGroup) do
        local cashShopId = groupData.cashShopId
        local cashGoodsInfos = {}
        for _, goodsInfo in ipairs(groupData.goodsInfos) do
            local info = goodsInfo
            local _, goodsDataCfg = Tables.GiftpackCashShopGoodsDataTable:TryGetValue(info.goodsId)
            info.cashShopPriority = groupData.clientShowData.priority    
            info.isMonthlyPass = cashShopId == MONTHLY_PASS_CASHSHOPID   
            info.priority = goodsDataCfg and goodsDataCfg.priority or 100
            info.cashShopId = groupData.cashShopId
            info.cashShopDynamicPriority = groupData.clientShowData.dynamicPriority  
            info.dynamicTag = goodsDataCfg.dynamicTag
            info.dynamicPriority = goodsDataCfg.dynamicPriority
            local canBuy = CashShopUtils.CheckCanBuyCashShopGoods(info.goodsId)
            info.soldOutSortValue = canBuy and 0 or 1
            
            table.insert(cashGoodsInfos, info)
            table.insert(allCashGoodsInfos, info)
            if cashShopId == MONTHLY_PASS_CASHSHOPID then
                monthlyPassShopGoodsInfo = info
            end
        end
        
        local haveCfgTabData, cfgTabData = Tables.CashshopShopTabDataTable:TryGetValue(cashShopId)
        local tagList = {}
        if haveCfgTabData then
            for _, tag in pairs(cfgTabData.tagList) do
                table.insert(tagList, tag)
            end
        end
        
        local tabData = {
            cashShopId = cashShopId,
            priority = groupData.clientShowData.priority,
            isMonthlyPass = cashShopId == MONTHLY_PASS_CASHSHOPID,  
            name = groupData.clientShowData.shopName,
            cashGoodsInfos = cashGoodsInfos,
            clientShowData = groupData.clientShowData,
            tagList = tagList,
        }
        table.insert(cashShopTabList, tabData)
    end
    
    local haveCfgTabData, cfgTabData = Tables.CashshopShopTabDataTable:TryGetValue(ALL_SHOP_ID)
    local tagList = {}
    if haveCfgTabData then
        for _, tag in pairs(cfgTabData.tagList) do
            table.insert(tagList, tag)
        end
    end
    local allTabData = {
        cashShopId = ALL_SHOP_ID,
        priority = 0,  
        isMonthlyPass = false,
        name = Language.LUA_CASH_SHOP_GIFTPACK_ALL_TAB_NAME,
        cashGoodsInfos = allCashGoodsInfos,
        tagList = tagList,
    }
    table.insert(cashShopTabList, allTabData)
    
    for _, tabData in ipairs(cashShopTabList) do
        if tabData.isMonthlyPass then
            
            tabData.allSoldOut = not CashShopUtils.CheckCanBuyMonthlyPass()
        else
            local soldOutCount = 0
            for _, goodsInfo in ipairs(tabData.cashGoodsInfos) do
                local goodsId = goodsInfo.goodsId
                local limitGoodsData = GameInstance.player.cashShopSystem:GetPlatformLimitGoodsData(goodsId)
                if limitGoodsData ~= nil and limitGoodsData.limitType == CS.Beyond.Gameplay.CashShopSystem.EPlatformLimitGoodsType.Common then
                    local limitCount = limitGoodsData.limitCount
                    local purchaseCount = limitGoodsData.purchaseCount
                    if limitCount <= purchaseCount then
                        soldOutCount = soldOutCount + 1
                    end
                end
            end
            tabData.allSoldOut = soldOutCount == #tabData.cashGoodsInfos
        end
        
        if tabData.allSoldOut and tabData.clientShowData and tabData.clientShowData.setBottomWhenAllSoldOut then
            tabData.soldOutSortValue = 1
        else
            tabData.soldOutSortValue = 0
        end
    end
    
    table.sort(cashShopTabList, Utils.genSortFunction({ "soldOutSortValue", "priority" }, true))
    self.m_tabDataList = cashShopTabList
end



ShopGiftPackEmptyCtrl._RefreshUI = HL.Method() << function(self)
    self.view.cashShopVerticalTabList.scrollList:UpdateCount(#self.m_tabDataList)
end



ShopGiftPackEmptyCtrl._UpdateTabList = HL.Method() << function(self)
    self.view.cashShopVerticalTabList.scrollList:UpdateShowingCells(function(index, obj)
        local cell = self.m_getTabCellFunc(obj)
        local tabData = self.m_tabDataList[LuaIndex(index)]

        self:_SetupTabTag(cell, tabData)
    end)
end






ShopGiftPackEmptyCtrl._SetTabByIndex = HL.Method(HL.Int, HL.Opt(HL.Boolean, HL.Boolean))
    << function(self, index, naviTarget, onCreate)
    if naviTarget == nil then
        naviTarget = true  
    end
    if #self.m_tabDataList >= index then
        local obj = self.view.cashShopVerticalTabList.scrollList:Get(CSIndex(index))
        local cell = self.m_getTabCellFunc(obj)
        self.m_isControllerTarget = true
        cell.toggle:SetIsOnWithoutNotify(true)
        self:_OnTabClick(self.m_tabDataList[index], false, onCreate)
        if naviTarget then
            UIUtils.setAsNaviTarget(cell.toggle)
        end
    end
end







ShopGiftPackEmptyCtrl._OnTabClick = HL.Method(HL.Table, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, tabData, userClick, onCreate)
    if self.m_currTabCashShopId == tabData.cashShopId then
        logger.info("click same tab")
        return
    end

    if self.m_isInTabClickFunc then
        return
    end
    self.m_isInTabClickFunc = true

    
    if userClick and not string.isEmpty(self.m_currTabCashShopId) then
        local currTabData = self:_GetTabDataByCashShopId(self.m_currTabCashShopId)
        if self.m_currTabCashShopId == MONTHLY_PASS_CASHSHOPID then
            
            local goodsIds = {}
            for _, info in ipairs(currTabData.cashGoodsInfos) do
                table.insert(goodsIds, info.goodsId)
            end
            GameInstance.player.cashShopSystem:ReadCashGoods(goodsIds)
        else
            if self.m_phase.m_panel2Item[PanelId.ShopPackage] ~= nil then
                local packageCtrl = self.m_phase.m_panel2Item[PanelId.ShopPackage].uiCtrl
                
                packageCtrl:UpdateSeeGoods(self.m_haveSeenGoodsId)
                GameInstance.player.cashShopSystem:ReadCashGoods(self.m_haveSeenGoodsId)
            end
        end
        self.m_haveSeenGoodsId = {}
    end
    
    if self.m_currTabCashShopId == MONTHLY_PASS_CASHSHOPID then
        self.m_phase:RemovePhasePanelItemByIdWrapper(PanelId.ShopMonthlyPass)
        self.m_phase:RemovePhasePanelItemByIdWrapper(PanelId.ShopMonthlyPass3D)
    else
        self.m_phase:RemovePhasePanelItemByIdWrapper(NORMAL_CASHSHOP_GIFTPACK_PANEL_ID)
    end
    
    if tabData.cashShopId == MONTHLY_PASS_CASHSHOPID then
        self.m_phase:CreateOrShowPhasePanelItemWrapper(PanelId.ShopMonthlyPass,
            {
                isRecommend = false,
                goodsId = tabData.cashGoodsInfos[1].goodsId,
                cashShopId = tabData.cashShopId,
            })
        self.m_phase:CreateOrShowPhasePanelItemWrapper(PanelId.ShopMonthlyPass3D,
            {
                isDailyPopup = false,
            })
    else
        
        if tabData.cashShopId == Tables.cashShopConst.SpecialGiftPackShopId then
            CashShopUtils.TryCloseSpecialGiftPopup()
        end
        self.m_phase:CreateOrShowPhasePanelItemWrapper(NORMAL_CASHSHOP_GIFTPACK_PANEL_ID,
            {
                tabData = tabData,
                phase = self.m_phase,
                emptyCtrl = self,
                naviGoodsId = self.m_needNaviGoodsId,
                playAnimationIn = onCreate and true or false,
            })
        self.m_needNaviGoodsId = ""
    end

    if self.m_phase.m_needGameEvent then
        self.m_phase.m_needGameEvent = false
        EventLogManagerInst:GameEvent_ShopEnter(
            self.m_phase.m_enterButton,
            self.m_phase.m_enterPanel,
            tabData.cashShopId,
            CashShopConst.CashShopCategoryType.Pack,
            ""
        )
    else
        EventLogManagerInst:GameEvent_ShopPageView(
            tabData.cashShopId,
            CashShopConst.CashShopCategoryType.Pack,
            ""
        )
    end

    self.m_currTabCashShopId = tabData.cashShopId
    UIManager:SetTopOrder(PanelId.CashShop)
    UIManager:SetTopOrder(PanelId.ShopGiftPackEmpty)

    Notify(MessageConst.ON_CASH_SHOP_PACK_SET_TOP)

    
    if UIManager:IsShow(PanelId.RewardsPopUpForSystem) then
        UIManager:SetTopOrder(PanelId.RewardsPopUpForSystem)
    end

    self.m_isInTabClickFunc = false
end




ShopGiftPackEmptyCtrl._GetTabDataByCashShopId = HL.Method(HL.String).Return(HL.Any) << function(self, cashShopId)
    for _, tabData in ipairs(self.m_tabDataList) do
        if tabData.cashShopId == cashShopId then
            return tabData
        end
    end
    return nil
end






ShopGiftPackEmptyCtrl.ChooseTabByGoodsId = HL.Method(HL.String, HL.Boolean).Return(HL.String)
    << function(self, goodsId, openDetailPanel)
    
    local foundTabData = nil
    local foundTabIndex = 0
    for i = 2, #self.m_tabDataList do
        local tabData = self.m_tabDataList[i]
        local cashGoodsInfos = tabData.cashGoodsInfos
        for _, cashGoodsInfo in ipairs(cashGoodsInfos) do
            if cashGoodsInfo.goodsId == goodsId then
                foundTabData = tabData
                foundTabIndex = i
                break
            end
        end
        if foundTabData ~= nil then
            break
        end
    end
    
    if foundTabData ~= nil then
        self:_SetTabByIndex(foundTabIndex)
        if openDetailPanel then
            if foundTabData.isMonthlyPass then
                
                CashShopUtils.TryBuyMonthlyPass(goodsId, foundTabData.cashShopId)
            else
                local foundInfo = lume.match(foundTabData.cashGoodsInfos, function(info)
                    return info.goodsId == goodsId
                end)
                UIManager:Open(PanelId.ShopGiftPackDetails, {
                    goodsId = goodsId,
                    goodsInfo = foundInfo,
                })
            end
        end
        return foundTabData.cashShopId
    end
    return ""
end






ShopGiftPackEmptyCtrl.ChooseTabByCashShopId = HL.Method(HL.String, HL.Opt(HL.Boolean, HL.Boolean))
    << function(self, cashShopId, naviTarget, onCreate)
    local foundTabData = nil
    local foundTabIndex = 0
    for i = 2, #self.m_tabDataList do
        local tabData = self.m_tabDataList[i]
        if tabData.cashShopId == cashShopId then
            foundTabData = tabData
            foundTabIndex = i
            break
        end
        if foundTabData ~= nil then
            break
        end
    end
    
    if foundTabData ~= nil then
        self:_SetTabByIndex(foundTabIndex, naviTarget, onCreate)
    else
        
        self:_SetTabByIndex(1, naviTarget, onCreate)
    end
end



ShopGiftPackEmptyCtrl._OnReceiveRefreshMsg = HL.Method() << function(self)
    logger.info("ShopGiftPackEmptyCtrl: 收到msg，刷新页面")

    local topPhaseId = PhaseManager:GetTopPhaseId()
    if topPhaseId ~= PhaseId.CashShop then
        logger.info("PhaseId.CashShop 不是最上层的phase, 不刷新")
        return
    end

    self:_InitData()
    self:_RefreshUI()

    if self.m_phase.m_panel2Item[PanelId.ShopPackage] ~= nil then
        local packageCtrl = self.m_phase.m_panel2Item[PanelId.ShopPackage].uiCtrl
        
        local goodsId = packageCtrl:GetCurrNaviGoodsId()
        self.m_needNaviGoodsId = goodsId
        InputManagerInst:ToggleGroup(self.view.cashShopVerticalTabList.groupTarget.groupId, false)
        
        packageCtrl:UpdateSeeGoods(self.m_haveSeenGoodsId)
    else
        self.m_needNaviGoodsId = ""
    end

    local prevCashShopId = self.m_currTabCashShopId
    self.m_currTabCashShopId = ""
    if not string.isEmpty(prevCashShopId) then
        
        self:ChooseTabByCashShopId(prevCashShopId, string.isEmpty(self.m_needNaviGoodsId))
    end
    if string.isEmpty(self.m_currTabCashShopId) then
        self:_SetTabByIndex(1)
    end
end



ShopGiftPackEmptyCtrl._OnGoRight = HL.Method() << function(self)
    
    if self.m_phase.m_panel2Item[PanelId.ShopPackage] then
        logger.info("ShopGiftPackEmptyCtrl: _OnGoRight 被触发")
        InputManagerInst:ToggleGroup(self.view.cashShopVerticalTabList.groupTarget.groupId, false)
        local rightCtrl = self.m_phase.m_panel2Item[PanelId.ShopPackage].uiCtrl
        local succ = rightCtrl:TargetFirstCell()
        if not succ then
            InputManagerInst:ToggleGroup(self.view.cashShopVerticalTabList.groupTarget.groupId, true)
        end
    end

end



ShopGiftPackEmptyCtrl.NaviTargetCurrTab = HL.Method() << function(self)
    logger.info("ShopGiftPackEmptyCtrl: NaviTargetCurrTab")
    InputManagerInst:ToggleGroup(self.view.cashShopVerticalTabList.groupTarget.groupId, true)

    local foundTabData = nil
    local foundTabIndex = 0
    for i = 1, #self.m_tabDataList do
        local tabData = self.m_tabDataList[i]
        if tabData.cashShopId == self.m_currTabCashShopId then
            foundTabData = tabData
            foundTabIndex = i
            break
        end
        if foundTabData ~= nil then
            break
        end
    end
    
    if foundTabData ~= nil then
        local obj = self.view.cashShopVerticalTabList.scrollList:Get(CSIndex(foundTabIndex))
        local cell = self.m_getTabCellFunc(obj)
        UIUtils.setAsNaviTarget(cell.toggle)
    end
end




ShopGiftPackEmptyCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.CASH_SHOP_SHOW_WALLET_BAR, {
        moneyIds = {Tables.globalConst.originiumItemId, Tables.globalConst.diamondItemId},
    })
end






ShopGiftPackEmptyCtrl.OnClose = HL.Override() << function(self)
end








ShopGiftPackEmptyCtrl._OnSdkProductInfoUpdate = HL.Method() << function(self)
    self:_OnReceiveRefreshMsg()
end



ShopGiftPackEmptyCtrl._OnCashShopPlatformDataRefresh = HL.Method() << function(self)
    self:_OnReceiveRefreshMsg()
end



ShopGiftPackEmptyCtrl._OnCashShopNewOpenGoods = HL.Method() << function(self)
    self:_OnReceiveRefreshMsg()
end



ShopGiftPackEmptyCtrl._OnReadCashShopGoods = HL.Method() << function(self)
    self:_UpdateTabList()
end



HL.Commit(ShopGiftPackEmptyCtrl)
