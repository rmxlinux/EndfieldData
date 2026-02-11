local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GachaWeaponPool
































GachaWeaponPoolCtrl = HL.Class('GachaWeaponPoolCtrl', uiCtrl.UICtrl)







GachaWeaponPoolCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_GACHA_SUCC] = 'OnGachaSucc',
    [MessageConst.ON_WALLET_CHANGED] = 'OnWalletChanged',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = 'OnWalletChanged',
    [MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED] = 'OnGachaPoolRoleDataChanged',
    [MessageConst.ON_SHOP_GOODS_CONDITION_REFRESH] = 'CloseSelf',
    
    [MessageConst.GACHA_WEAPON_POOL_ADD_SHOW_REWARD] = 'AddQueueReward',
    [MessageConst.ON_ONE_GACHA_WEAPON_POOL_REWARD_FINISHED] = 'OnOneQueueRewardFinished',
}



GachaWeaponPoolCtrl.m_goodsData = HL.Field(CS.Beyond.Gameplay.ShopSystem.GoodsData)


GachaWeaponPoolCtrl.m_poolId = HL.Field(HL.String) << ""


GachaWeaponPoolCtrl.m_price = HL.Field(HL.Number) << 0


GachaWeaponPoolCtrl.m_itemNoUpCache = HL.Field(HL.Forward('UIListCache'))


GachaWeaponPoolCtrl.m_moneyCellCache = HL.Field(HL.Forward('UIListCache'))


GachaWeaponPoolCtrl.m_createdWeaponInsts = HL.Field(HL.Table)


GachaWeaponPoolCtrl.m_isRequesting = HL.Field(HL.Boolean) << false


GachaWeaponPoolCtrl.m_gachaFlowCoroutine = HL.Field(HL.Thread)


GachaWeaponPoolCtrl.m_loopRewardItemUIList = HL.Field(HL.Table)


GachaWeaponPoolCtrl.m_gachaWeaponGoodsCostInfo = HL.Field(HL.Table)




GachaWeaponPoolCtrl.CloseSelf = HL.Method() << function(self)
    if PhaseManager:GetTopPhaseId() ~= PhaseId.GachaWeaponPool then
        return
    end
    PhaseManager:PopPhase(PhaseId.GachaWeaponPool)
end




GachaWeaponPoolCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    local goodsData = arg.goodsData
    self.m_goodsData = goodsData 
    local goodsTemplate = goodsData.goodsTemplateId
    local shopGoodsData = Tables.shopGoodsTable:GetValue(goodsTemplate)
    self.m_poolId = shopGoodsData.weaponGachaPoolId
    self.m_price = shopGoodsData.price

    self.m_createdWeaponInsts = {}
    self.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.GachaWeaponPool)
    end)
    self.view.gachaBtn.onClick:AddListener(function()
        self:_OnGachaBtnClick()
    end)
    self.view.detailTipsBtn.gameObject:SetActive(not GameInstance.player.gameSettingSystem.forbiddenWebView)
    self.view.tipsDetailBtn.interactable = not GameInstance.player.gameSettingSystem.forbiddenWebView
    self.view.detailTipsBtn.onClick:AddListener(function()
        CS.Beyond.SDK.SDKUtils.OpenHGWebPortalSDK("gacha_weapon", string.format("{\"pool_id\":\"%s\"}", self.m_poolId), nil)
    end)
    self.view.tipsDetailBtn.onClick:AddListener(function()
        CS.Beyond.SDK.SDKUtils.OpenHGWebPortalSDK("gacha_weapon", string.format("{\"pool_id\":\"%s\"}", self.m_poolId), nil)
    end)
    self.view.noMoneyBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.GachaWeaponInsufficient)
    end)
    self.m_itemNoUpCache = UIUtils.genCellCache(self.view.itemNoUp)
    self.m_moneyCellCache = UIUtils.genCellCache(self.view.moneyCell)

    self.m_loopRewardItemUIList = {}
    table.insert(self.m_loopRewardItemUIList, self.view.guaranteeRewardNode.loopRewardItem1)
    table.insert(self.m_loopRewardItemUIList, self.view.guaranteeRewardNode.loopRewardItem2)

    self.m_showRewardFuncQueue = require_ex("Common/Utils/DataStructure/Queue")()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.weaponShowMessageNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if isFocused then
            InputManagerInst.controllerNaviManager:SetTarget(self.view.itemUp.view.button)
        end
    end)

    self:_InitData()
end



GachaWeaponPoolCtrl.OnShow = HL.Override() << function(self)
    GameInstance.player.shopSystem:SetSingleGoodsIdSee(self.m_goodsData.goodsId)
    
    local time = Time.unscaledTime
    self.loader:LoadGameObjectAsync("Assets/Beyond/DynamicAssets/Gameplay/Prefabs/Gacha/GachaWeaponPreheat.prefab", function()
        logger.info("GachaOutside 预载完成", Time.unscaledTime - time)
    end)

    if not self.m_isRequesting then
        self:CheckAndShowSpecialRewardPopup()
        self:_TryShowQueueReward()
    end
end



GachaWeaponPoolCtrl._InitData = HL.Method() << function(self)
    
    local poolInfo = GameInstance.player.gacha.poolInfos:get_Item(self.m_poolId)
    local poolData = poolInfo.data

    self:OnWalletChanged()
    self.view.priceIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, self.m_gachaWeaponGoodsCostInfo.costMoneyId)
    self.view.priceNumTxt.text = self.m_gachaWeaponGoodsCostInfo.costMoneyCount
    self.view.originalCostTxt.text = self.m_gachaWeaponGoodsCostInfo.costMoneyCount
    if not string.isEmpty(self.m_gachaWeaponGoodsCostInfo.costTicketId) then
        self.view.ticketIcon:LoadSprite(UIConst.UI_SPRITE_WALLET, self.m_gachaWeaponGoodsCostInfo.costTicketId)
        self.view.ticketCostNumTxt.text = self.m_gachaWeaponGoodsCostInfo.costTicketCount
    end

    
    local upWeaponId = poolData.upWeaponIds[0]
    local weaponItemCfg = Tables.itemTable:GetValue(upWeaponId)
    self.view.weaponIconImg:LoadSprite(UIConst.UI_SPRITE_ITEM, weaponItemCfg.iconId)

    self.view.weaponNameTxt.text = poolData.name
    
    self:_UpdateRemainingTime()
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.COMMON_UI_TIME_UPDATE_INTERVAL)
            self:_UpdateRemainingTime()
        end
    end)
    
    self.view.itemUp:InitItem({ id = upWeaponId, forceHidePotentialStar = true }, function()
        CashShopUtils.ShowWikiWeaponPreview(self.m_poolId, upWeaponId)
    end)
    local contentData = Tables.gachaWeaponPoolContentTable[self.m_poolId]
    local items = {}
    for _, v in pairs(contentData.list) do
        if v.starLevel == 6 and v.itemId ~= upWeaponId then
            table.insert(items, { id = v.itemId, forceHidePotentialStar = true })
        end
    end
    self.m_itemNoUpCache:Refresh(#items, function(cell, index)
        cell:InitItem(items[index], function()
            CashShopUtils.ShowWikiWeaponPreview(self.m_poolId, items[index].id)
        end)
    end)

    
    local gachaTypeCfg = Tables.gachaWeaponPoolTypeTable[poolData.type]
    
    local greyTxt6 = string.format(
        gachaTypeCfg.softGuarantee - poolInfo.softGuaranteeProgress > 10 and Language.LUA_GACHA_WEAPON_POOL_DESC_STAR_6 or Language.LUA_GACHA_WEAPON_POOL_DESC_STAR_6_CURR,
        math.ceil((gachaTypeCfg.softGuarantee - poolInfo.softGuaranteeProgress) / 10))
    self.view.greyTxt:SetAndResolveTextStyle(greyTxt6)
    
    local guaranteeRewardNode = self.view.guaranteeRewardNode
    local showHardGuarantee = poolInfo.upGotCount <= 0 and poolInfo.hardGuaranteeProgress <= gachaTypeCfg.hardGuarantee
    if showHardGuarantee then
        guaranteeRewardNode.hardGuaranteeNode.gameObject:SetActive(true)
        guaranteeRewardNode.upWeaponNameTxt.text = weaponItemCfg.name
        guaranteeRewardNode.upWeaponIconImg:LoadSprite(UIConst.UI_SPRITE_ITEM, weaponItemCfg.iconId)
        local weaponCfg = Tables.weaponBasicTable[upWeaponId]
        local weaponTypeIconName = UIConst.WEAPON_EXHIBIT_WEAPON_TYPE_ICON_PREFIX .. weaponCfg.weaponType:ToInt()
        guaranteeRewardNode.upWeaponTypeIconImg:LoadSprite(UIConst.UI_SPRITE_WEAPON_EXHIBIT, weaponTypeIconName)
        local hardGuaranteeDesc = string.format(Language.LUA_GACHA_WEAPON_POOL_DESC_UP, math.ceil((gachaTypeCfg.hardGuarantee - poolInfo.hardGuaranteeProgress) / 10), weaponItemCfg.name)
        guaranteeRewardNode.hardGuaranteeTxt:SetAndResolveTextStyle(hardGuaranteeDesc)
        guaranteeRewardNode.hardGuaranteeBtn.onClick:RemoveAllListeners()
        guaranteeRewardNode.hardGuaranteeBtn.onClick:AddListener(function()
            CashShopUtils.ShowWikiWeaponPreview(self.m_poolId, upWeaponId)
        end)
    else
        guaranteeRewardNode.hardGuaranteeNode.gameObject:SetActive(false)
    end
    
    if not showHardGuarantee then
        guaranteeRewardNode.loopRewardNode.gameObject:SetActive(true)
        local loopRewardInfos = CashShopUtils.GetGachaWeaponLoopRewardInfo(self.m_poolId)
        local loopRewardInfoCount = loopRewardInfos and #loopRewardInfos or 0
        if loopRewardInfoCount > 0 then
            guaranteeRewardNode.gameObject:SetActive(true)
            local itemUICount = #self.m_loopRewardItemUIList
            for i = 1, itemUICount do
                
                local itemUI = self.m_loopRewardItemUIList[i]
                if i > loopRewardInfoCount then
                    itemUI.gameObject:SetActive(false)
                else
                    
                    local info = loopRewardInfos[i]
                    itemUI.gameObject:SetActive(true)
                    itemUI.item:InitItem({ id = info.itemId, count = 1 }, function()
                        if info.isWeaponItemCase then
                            UIManager:Open(PanelId.BattlePassWeaponCase, { itemId = info.itemId, isPreview = true })
                        else
                            CashShopUtils.ShowWikiWeaponPreview(self.m_poolId, info.itemId)
                        end
                    end)
                    itemUI.pullCountTxt:SetAndResolveTextStyle(string.format(Language.LUA_GACHA_WEAPON_LOOP_REWARD_NEED_PULL_COUNT, info.remainNeedPullCount))
                    itemUI.nameTxt:SetAndResolveTextStyle(string.format(Language.LUA_GACHA_WEAPON_LOOP_REWARD_GET_REWARD_NAME, info.name))
                    
                    local tagName
                    if info.isWeaponItemCase then
                        tagName = Language.LUA_GACHA_WEAPON_LOOP_REWARD_BOX_TAG
                    else
                        tagName = info.loopRewardTagName
                    end
                    itemUI.tagTxt.text = tagName
                end
            end
        else
            guaranteeRewardNode.gameObject:SetActive(false)
        end
    else
        guaranteeRewardNode.loopRewardNode.gameObject:SetActive(false)
    end

    self:_InitRewardQueueConfigs()
end



GachaWeaponPoolCtrl._UpdateRemainingTime = HL.Method() << function(self)
    local isRealTime, resultValue = CashShopUtils.GetGachaWeaponPoolCloseTimeInfo(self.m_poolId)
    if isRealTime then
        local endTime = resultValue
        if endTime > 0 then
            local leftTime = endTime - DateTimeUtils.GetCurrentTimestampBySeconds()

            if leftTime > 3600 * 24 * 3 then
                self.view.timeGreen.gameObject:SetActive(true)
                self.view.timeYellow.gameObject:SetActive(false)
                self.view.timeRed.gameObject:SetActive(false)
            elseif leftTime <= 3600 * 24 * 3 and leftTime > 3600 * 24 then
                self.view.timeGreen.gameObject:SetActive(false)
                self.view.timeYellow.gameObject:SetActive(true)
                self.view.timeRed.gameObject:SetActive(false)
            else
                self.view.timeGreen.gameObject:SetActive(false)
                self.view.timeYellow.gameObject:SetActive(false)
                self.view.timeRed.gameObject:SetActive(true)
            end
            local leftTimeStr = UIUtils.getShortLeftTime(leftTime)
            self.view.timeRedText.text = leftTimeStr
            self.view.timeGreenText.text = leftTimeStr
            self.view.timeYellowText.text = leftTimeStr
        else
            self.view.timeGreen.gameObject:SetActive(false)
            self.view.timeYellow.gameObject:SetActive(false)
            self.view.timeRed.gameObject:SetActive(false)
        end
    else
        self.view.timeGreen.gameObject:SetActive(true)
        self.view.timeYellow.gameObject:SetActive(false)
        self.view.timeRed.gameObject:SetActive(false)
        self.view.timeGreenText.text = string.format(Language.LUA_GACHA_WEAPON_POOL_REMAIN_INDEX_COUNT_DOWN, resultValue)
    end
end



GachaWeaponPoolCtrl._OnGachaBtnClick = HL.Method() << function(self)
    if self.m_isRequesting or self.m_gachaWeaponGoodsCostInfo == nil then
        return
    end
    if self.m_gachaWeaponGoodsCostInfo.ticketEnough then
        GameInstance.player.shopSystem:BuyGoods(self.m_goodsData.shopId, self.m_goodsData.goodsId, 1, true)
    elseif self.m_gachaWeaponGoodsCostInfo.moneyEnough then
        GameInstance.player.shopSystem:BuyGoods(self.m_goodsData.shopId, self.m_goodsData.goodsId, 1)
    else
        return
    end
    self.m_isRequesting = true
end




GachaWeaponPoolCtrl.OnWalletChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self.m_gachaWeaponGoodsCostInfo = CashShopUtils.TryGetBuyGachaWeaponGoodsCostInfo(self.m_goodsData.shopId, self.m_goodsData.goodsId)
    local costTicketId = self.m_gachaWeaponGoodsCostInfo.costTicketId
    local costTicketCount = self.m_gachaWeaponGoodsCostInfo.costTicketCount
    local costMoneyId = self.m_gachaWeaponGoodsCostInfo.costMoneyId
    local costMoneyCount = self.m_gachaWeaponGoodsCostInfo.costMoneyCount
    if self.m_gachaWeaponGoodsCostInfo.ticketEnough then
        self.view.normalType.gameObject:SetActive(true)
        self.view.disableType.gameObject:SetActive(false)
        self.view.ticketNode.gameObject:SetActive(true)
        self.view.originalCostTxt.gameObject:SetActive(true)
        self.view.priceNumTxt.gameObject:SetActive(false)
        self.view.normalNumTxt.text = 1
        self.view.normalCostIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, costTicketId)
        self.view.normalCostTxt.text = costTicketCount
        self.view.normalMultiplyTxt.gameObject:SetActive(true)

        self.view.gachaBtn.gameObject:SetActive(true)
        self.view.noMoneyType.gameObject:SetActive(false)
    elseif self.m_gachaWeaponGoodsCostInfo.moneyEnough then
        self.view.normalType.gameObject:SetActive(true)
        self.view.disableType.gameObject:SetActive(false)
        self.view.ticketNode.gameObject:SetActive(false)
        self.view.originalCostTxt.gameObject:SetActive(false)
        self.view.priceNumTxt.gameObject:SetActive(true)
        self.view.normalMultiplyTxt.gameObject:SetActive(false)
        self.view.normalNumTxt.text = 1
        self.view.normalCostIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, costMoneyId)
        self.view.normalCostTxt.text = costMoneyCount

        self.view.gachaBtn.gameObject:SetActive(true)
        self.view.noMoneyType.gameObject:SetActive(false)
    else
        self.view.normalType.gameObject:SetActive(false)
        self.view.disableType.gameObject:SetActive(true)
        self.view.ticketNode.gameObject:SetActive(false)
        self.view.originalCostTxt.gameObject:SetActive(false)
        self.view.priceNumTxt.gameObject:SetActive(true)
        self.view.normalMultiplyTxt.gameObject:SetActive(false)
        self.view.disableNumTxt.text = 1
        self.view.disableCostIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, costMoneyId)
        self.view.disableCostTxt.text = costMoneyCount

        self.view.gachaBtn.gameObject:SetActive(false)
        self.view.noMoneyType.gameObject:SetActive(true)
        self.view.noMoneyTxt.text = string.format(Language.LUA_GACHA_WEAPON_POOL_NO_MONEY, UIConst.UI_SPRITE_WALLET, costMoneyId)
    end

    
    if self.m_gachaWeaponGoodsCostInfo.ticketEnough then
        self.m_moneyCellCache:Refresh(2, function(cell, tabIndex)
            if tabIndex == 1 then
                cell:InitMoneyCell(costTicketId)
            else
                cell:InitMoneyCell(Tables.globalConst.gachaWeaponItemId)
            end
        end)
    else
        self.m_moneyCellCache:Refresh(1, function(cell, tabIndex)
            cell:InitMoneyCell(Tables.globalConst.gachaWeaponItemId)
        end)
    end
end




GachaWeaponPoolCtrl.OnGachaSucc = HL.Method(HL.Table) << function(self, arg)
    self:OnWalletChanged()
    
    local msg = unpack(arg)
    if msg.GachaPoolId ~= self.m_poolId then
        return
    end

    local weapons = {}
    for k = 0, msg.FinalResults.Count - 1 do
        local v = msg.FinalResults[k]
        local weaponId = msg.OriResultIds[k]
        local items = {}
        for kk = 0, v.RewardIds.Count - 1 do
            local rewardId = v.RewardIds[kk]
            UIUtils.getRewardItems(rewardId, items)
        end
        local itemCfg = Tables.itemTable:GetValue(weaponId)
        table.insert(weapons, {
            weaponId = weaponId,
            isNew = v.IsNew,
            items = items,
            rarity = itemCfg.rarity,
        })
    end
    logger.info("OnGachaSucc", weapons)
    LuaSystemManager.gachaSystem:UpdateGachaWeaponSettingState()

    Notify(MessageConst.ON_DISABLE_ACHIEVEMENT_TOAST, UIConst.ACHIEVEMENT_TOAST_DISABLE_KEY.GachaWeapon)
    
    self.m_gachaFlowCoroutine = self:_ClearCoroutine(self.m_gachaFlowCoroutine)
    self.m_gachaFlowCoroutine = self:_StartCoroutine(function()
        
        Notify(MessageConst.QUICK_HIDE_FULL_SCREEN_SCENE_BLUR)
        
        self.view.blackMask.gameObject:SetActive(true)
        coroutine.waitAsyncRequest(function(onComplete)
            PhaseManager:OpenPhaseFast(PhaseId.GachaWeaponPreheat, {
                weapons = weapons,
                onComplete = onComplete
            })
        end)
        coroutine.waitAsyncRequest(function(onComplete)
            PhaseManager:OpenPhaseFast(PhaseId.GachaWeapon, {
                weapons = weapons,
                onComplete = onComplete
            })
        end)
        
        table.sort(weapons, function(a, b)
            if a.rarity ~= b.rarity then
                return a.rarity < b.rarity
            end
            if a.weaponId ~= b.weaponId then
                return a.weaponId < b.weaponId
            end
            if a.isNew == b.isNew then
                return false
            end
            return b.isNew
        end)
        Notify(MessageConst.ON_ENABLE_ACHIEVEMENT_TOAST, UIConst.ACHIEVEMENT_TOAST_DISABLE_KEY.GachaWeapon)
        coroutine.waitAsyncRequest(function(onComplete)
            PhaseManager:OpenPhaseFast(PhaseId.GachaWeaponResult, {
                weapons = weapons,
                onComplete = onComplete
            })
        end)
        self.view.blackMask.gameObject:SetActive(false)

        local getItems = {}
        local otherItemDict = {}
        
        for _, weapon in ipairs(weapons) do
            table.insert(getItems, { id = weapon.weaponId, count = 1 })
            for _, item in ipairs(weapon.items) do
                otherItemDict[item.id] = (otherItemDict[item.id] or 0) + item.count
            end
        end
        
        local otherItems = {}
        for k, v in pairs(otherItemDict) do
            local data = Tables.itemTable[k]
            table.insert(otherItems, {
                id = k,
                count = v,
                sortId1 = data.sortId1,
                sortId2 = data.sortId2,
                rarity = data.rarity,
            })
        end
        table.sort(otherItems, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
        for _, v in ipairs(otherItems) do
            table.insert(getItems, v)
        end

        local notifyShowRewardArg = {
            queueRewardType = "GachaResultReward",
            showRewardFunc = function()
                Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
                    items = getItems,
                    onComplete = function()
                        Notify(MessageConst.ON_ONE_GACHA_WEAPON_POOL_REWARD_FINISHED)
                    end,
                })
            end
        }
        Notify(MessageConst.GACHA_WEAPON_POOL_ADD_SHOW_REWARD, notifyShowRewardArg)
        CashShopUtils.TryOpenSpecialGiftPopup()
        self.m_isRequesting = false
    end)
    
end



GachaWeaponPoolCtrl.OnGachaPoolRoleDataChanged = HL.Method() << function(self)
    self:_InitData()
end




GachaWeaponPoolCtrl._ShowPerfectWeaponPreview = HL.Method(HL.String) << function(self, weaponId)
    local weaponInst
    if self.m_createdWeaponInsts[weaponId] ~= nil then
        weaponInst = self.m_createdWeaponInsts[weaponId]
    else
        weaponInst = GameInstance.player.charBag:CreateClientPerfectGachaPoolWeaponWithoutGem(weaponId)
        self.m_createdWeaponInsts[weaponId] = weaponInst
    end

    if PhaseManager:CheckCanOpenPhase(PhaseId.WeaponInfo, nil, true) == false then
        return
    end

    if PhaseManager:CheckIsInTransition() then
        return
    end

    local fadeTimeBoth = UIConst.CHAR_INFO_TRANSITION_BLACK_SCREEN_DURATION
    local dynamicFadeData = UIUtils.genDynamicBlackScreenMaskData("GachaWeaponPool->WeaponInfo", fadeTimeBoth, fadeTimeBoth, function()
        
        PhaseManager:OpenPhase(PhaseId.WeaponInfo, {
            weaponTemplateId = weaponId,
            weaponInstId = weaponInst.instId,
            isFocusJump = true,
        })
    end)
    GameAction.ShowBlackScreen(dynamicFadeData)
end



GachaWeaponPoolCtrl.OnClose = HL.Override() << function(self)
    self.m_createdWeaponInsts = {}
    self.m_gachaFlowCoroutine = self:_ClearCoroutine(self.m_gachaFlowCoroutine)
    CashShopUtils.TryFadeSpecialGiftPopup()
end



GachaWeaponPoolCtrl.m_showRewardFuncQueue = HL.Field(HL.Forward("Queue"))


GachaWeaponPoolCtrl.m_queueRewardConfigs = HL.Field(HL.Table)


GachaWeaponPoolCtrl.m_curIsShowReward = HL.Field(HL.Boolean) << false



GachaWeaponPoolCtrl._InitRewardQueueConfigs = HL.Method() << function(self)
    self.m_queueRewardConfigs = {
        GachaResultReward = {
            order = -100,
        },
        LoopRewardReward = {
            order = 10,
        },
    }
end




GachaWeaponPoolCtrl.AddQueueReward = HL.Method(HL.Table) << function(self, arg)
    logger.info("GachaWeaponPoolCtrl.AddQueueReward：" .. arg.queueRewardType)
    self.m_showRewardFuncQueue:Push({
        order = self.m_queueRewardConfigs[arg.queueRewardType].order,
        showRewardFunc = arg.showRewardFunc
    })
    self.m_showRewardFuncQueue:Sort(function(x, y)
        return x.order < y.order
    end)
end



GachaWeaponPoolCtrl._TryShowQueueReward = HL.Method() << function(self)
    if self.m_showRewardFuncQueue:Count() > 0 and not self.m_curIsShowReward then
        self.m_curIsShowReward = true
        local queueData = self.m_showRewardFuncQueue:Pop()
        queueData.showRewardFunc()
    end
end



GachaWeaponPoolCtrl.OnOneQueueRewardFinished = HL.Method() << function(self)
    self.m_curIsShowReward = false
    self:_TryShowQueueReward()
end



GachaWeaponPoolCtrl.CheckAndShowSpecialRewardPopup = HL.Method() << function(self)
    
    local csGachaSystem = GameInstance.player.gacha
    
    local _, poolInfo = csGachaSystem.poolInfos:TryGetValue(self.m_poolId)
    if not poolInfo or poolInfo.allLoopCumulateRewardIsCheck then
        return
    end
    local poolCfg = Tables.gachaWeaponPoolTable[self.m_poolId]
    local loopRewardInfoCount = poolCfg.intervalAutoRewardIds.Count
    
    for loopRound, isCheck in pairs(poolInfo.roleDataMsg.IntervalAutoRewardCheckMap) do
        if not isCheck then
            local roundRewardIndex = (loopRound - 1) % loopRewardInfoCount
            local rewardId = poolCfg.intervalAutoRewardIds[roundRewardIndex]
            local items = UIUtils.getRewardItems(rewardId)
            local arg = {
                queueRewardType = "LoopRewardReward",
                showRewardFunc = function()
                    UIManager:AutoOpen(PanelId.GachaWeaponExtraRewardPopup, {
                        itemId = items[1].id,
                        poolId = self.m_poolId,
                        onComplete = function()
                            csGachaSystem:SendConfirmRewardReq(
                                self.m_poolId, CS.Proto.GACHA_CONFIRM_REWARD_TYPE.GcrtIntervalReward, { loopRound }, GEnums.GachaType.Weapon
                            )
                            Notify(MessageConst.ON_ONE_GACHA_WEAPON_POOL_REWARD_FINISHED)
                        end,
                    })
                end
            }
            Notify(MessageConst.GACHA_WEAPON_POOL_ADD_SHOW_REWARD, arg)
        end
    end
end

HL.Commit(GachaWeaponPoolCtrl)
