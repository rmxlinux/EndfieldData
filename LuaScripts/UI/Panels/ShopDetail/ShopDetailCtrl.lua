
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ShopDetail

















ShopDetailCtrl = HL.Class('ShopDetailCtrl', uiCtrl.UICtrl)







ShopDetailCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BUY_ITEM_SUCC] = 'OnBuyItemSucc',
    [MessageConst.ON_SHOP_GOODS_CONDITION_REFRESH] = '_OnCloseShopDetailPanel',
    [MessageConst.ON_SHOP_REFRESH] = '_OnShopRefresh',
    [MessageConst.ON_CLOSE_SHOP_DETAIL_PANEL] = '_OnCloseShopDetailPanel'
}


ShopDetailCtrl.m_info = HL.Field(HL.Any)


ShopDetailCtrl.m_itemId = HL.Field(HL.String) << ""


ShopDetailCtrl.m_moneyId = HL.Field(HL.String) << ""


ShopDetailCtrl.m_realPrice = HL.Field(HL.Number) << 0


ShopDetailCtrl.m_bundleCount = HL.Field(HL.Number) << 0





ShopDetailCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self.view.closeButton.onClick:AddListener(function()
       self:PlayAnimationOutWithCallback(function()
           self:TryClose()
       end)
    end)
    self.m_info = arg
    self.view.numeberTxt.text = 1

    local goodsId = arg.goodsTemplateId
    local goodsTableData = Tables.shopGoodsTable:GetValue(goodsId)
    local moneyId = goodsTableData.moneyId
    self.m_moneyId = moneyId

    local realPrice = 1
    if arg.discount and arg.discount < 1 then
        self.view.discountTag.gameObject:SetActive(true)
        self.view.originalCostTxt.gameObject:SetActive(true)
        local discountTxt = string.format("-%d<size=60%%>%%</size>", math.floor((1 - arg.discount) * 100 + 0.5))
        self.view.discountTagLuaReference.discountShadowTxt.text = discountTxt
        self.view.discountTagLuaReference.discountTxt.text = discountTxt
        self.view.originalCostTxt.text = goodsTableData.price
        realPrice = CashShopUtils.GetDisplayPrice(goodsTableData.price, arg.discount)
        self.view.costTxt.text = realPrice
    else
        self.view.discountTag.gameObject:SetActive(false)
        self.view.costTxt.gameObject:SetActiveIfNecessary(true)
        self.view.originalCostTxt.gameObject:SetActive(false)
        self.view.costTxt.text = goodsTableData.price
        realPrice = goodsTableData.price
    end
    self.m_realPrice = realPrice

    local itemId = nil
    local itemData = nil
    local isBox = false
    if string.isEmpty(goodsTableData.rewardId) then
        local weaponPool = Tables.gachaWeaponPoolTable[goodsTableData.weaponGachaPoolId]
        local weaponId = weaponPool.upWeaponIds[0]
        itemId = weaponId
        local _, weaponItemCfg = Tables.itemTable:TryGetValue(weaponId)
        self.m_bundleCount = 1
        self.view.amountNumNode.gameObject:SetActive(false)
        self.view.amountTxt.text = string.format("×%s", 1)
        self.view.nameTxt.text = weaponPool.name
        itemData = weaponItemCfg
        isBox = true
    else
        local displayItem = UIUtils.getRewardFirstItem(goodsTableData.rewardId)
        itemId = displayItem.id
        self.m_bundleCount = displayItem.count
        if displayItem.count > 1 then
            self.view.amountNumNode.gameObject:SetActive(true)
            self.view.amountTxt.text = string.format("×%s", displayItem.count)
        else
            self.view.amountNumNode.gameObject:SetActive(false)
        end
        itemData = Tables.itemTable[itemId]
        self.view.nameTxt.text = itemData.name
    end
    self.m_itemId = itemId
    local haveItemCount = Utils.getItemCount(itemId)
    self.view.detailBtn.onClick:AddListener(function()
        if itemData.type == GEnums.ItemType.Weapon then
            WikiUtils.showWeaponPreview({ weaponId = self.m_itemId })
        elseif itemData.type == GEnums.ItemType.Char then
            local info = GameInstance.player.charBag:CreateClientPerfectGachaPoolCharInfo(itemId)
            local charInstIdList = {}
            table.insert(charInstIdList, info.instId)
            if not info then
                return
            end
            CharInfoUtils.openCharInfoBestWay({
                initCharInfo = {
                    instId = info.instId,
                    templateId = itemId,
                    charInstIdList = charInstIdList,
                },
                onClose = function()
                    GameInstance.player.charBag:ClearAllClientCharAndItemData()
                end,
            })
        else
            Notify(MessageConst.SHOW_ITEM_TIPS, {
                itemId = itemId,
                transform = self.view.detailBtn.transform,
                onClose = function()
                    self:_OnHideItemTips()
                end,
            })
            self:_OnShowItemTips()
            self.view.starGroup.gameObject:SetActive(false)
        end
    end)
    UIUtils.setItemRarityImage(self.view.rarityLine, itemData.rarity)

    self.view.ownNumberTxt.text = haveItemCount
    local itemTypeName = UIUtils.getItemTypeName(self.m_itemId)
    self.view.subTitleTxt.text = itemTypeName
    self.view.descTxt.text = itemData.desc
    self.view.descTxt02.text = itemData.decoDesc

    
    UIUtils.displayGiftItemTags(self.view.collectionTagNode, self.m_itemId)
    self.view.giftFeatureTagsNode:InitGiftFeatureTagsNode(self.m_itemId)

    self.view.moneyCell:InitMoneyCell(self.m_moneyId)
    self:_OnShopRefresh()

    GameInstance.player.shopSystem:SetSingleGoodsIdSee(goodsId)
end




ShopDetailCtrl._OnShopRefresh = HL.Method() << function(self)
    local arg = self.m_info
    local shopSystem = GameInstance.player.shopSystem

    local itemData = Tables.itemTable[self.m_itemId]
    local goodsId = arg.goodsTemplateId
    local goodsTableData = Tables.shopGoodsTable:GetValue(goodsId)
    local haveItemCount = Utils.getItemCount(self.m_itemId)

    local moneyItemData = Tables.itemTable:GetValue(self.m_moneyId)
    self.view.costIconImg1:LoadSprite(UIConst.UI_SPRITE_WALLET, moneyItemData.iconId)
    self.view.costIconImg2:LoadSprite(UIConst.UI_SPRITE_WALLET, moneyItemData.iconId)
    self.view.costIconImg3:LoadSprite(UIConst.UI_SPRITE_WALLET, moneyItemData.iconId)
    self.view.costMoneyTxt2.text = string.format(Language.LUA_SHOP_BUY_MONEY_NOT_ENOUGH, moneyItemData.name)
    self.view.costMoneyTxt1.text = moneyItemData.name

    local remainCount = shopSystem:GetRemainCountByGoodsId(arg.shopId, arg.goodsId)
    local unlock = shopSystem:CheckGoodsUnlocked(arg.goodsId)
    local haveMoney = Utils.getItemCount(self.m_moneyId)
    local maxBuy = math.floor(haveMoney / self.m_realPrice)
    maxBuy = math.max(maxBuy, 1)
    maxBuy = math.min(maxBuy, 99)
    maxBuy = math.min(maxBuy, remainCount == -1 and 99 or remainCount)
    if haveMoney >= self.m_realPrice and (remainCount > 0 or remainCount == -1) then
        self.view.btnCommonYellow.onClick:AddListener(function()
            self:_OnClickConfirm()
        end)
        self.view.numberSelector.gameObject:SetActive(unlock)
        self.view.commonStateController:SetState("normal")
        self.view.bottomNode:SetState("normal")
        self.view.amountNode:SetState("normal")
    else
        self.view.numberSelector.gameObject:SetActive(false)
        self.view.commonStateController:SetState("nomoney")
        self.view.bottomNode:SetState("nomoney")
        self.view.amountNode:SetState("nomoney")
        if self.m_moneyId == Tables.globalConst.gachaWeaponItemId then
            self.view.btnCommon.onClick:RemoveAllListeners()
            self.view.btnCommon.onClick:AddListener(function()
                UIManager:Open(PanelId.GachaWeaponInsufficient)
            end)
            self.view.bottomNode:SetState("exchange")
        end
    end

    self.view.numberSelector:InitNumberSelector(1, 1, maxBuy, function(newNum)
        self.view.numeberTxt.text = math.floor(newNum)
        self.view.costTotalTxt.text = math.floor(newNum * self.m_realPrice)
    end)

    self.view.lock.gameObject:SetActive(not unlock)
    self.view.lockTxt.text = nil
    if remainCount == 1 then
        self.view.numberSelector.gameObject:SetActive(false)
    end
    self.view.common.gameObject:SetActive(unlock)
    if remainCount == 0 then
        self.view.numberSelector.gameObject:SetActive(false)

        local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        local next = nil
        if goodsTableData.limitCountRefreshType == GEnums.ShopFrequencyLimitType.Daily then
            next = Utils.getNextCommonServerRefreshTime()
        end

        if goodsTableData.limitCountRefreshType == GEnums.ShopFrequencyLimitType.Weekly then
            next = Utils.getNextWeeklyServerRefreshTime()
        end
        if goodsTableData.limitCountRefreshType == GEnums.ShopFrequencyLimitType.Monthly then
            next = Utils.getNextMonthlyServerRefreshTime()
        end

        if next then
            local diff = next - curTime
            self.view.replenishTxt.text = string.format(Language.LUA_SHOP_GOODS_SOLD_OUT_WITH_TIME, UIUtils.getLeftTime(diff))
            self.view.amountNode:SetState("replensh")
        else
            self.view.emptyTxt.text = Language.LUA_SHOP_GOODS_SOLD_OUT
            self.view.amountNode:SetState("empty")
        end
        self.view.bottomNode:SetState("lock")
    end
    self.view.soldOut.gameObject:SetActive(remainCount == 0)


    if not unlock then
        self.view.lockTxt.text = goodsTableData.lockDesc
        self.view.amountNode:SetState("lock")
        self.view.bottomNode:SetState("lock")
        self.view.numberSelector.gameObject:SetActive(false)
    end
    local isCompositeItem = not string.isEmpty(itemData.iconCompositeId)
    if itemData.type == GEnums.ItemType.Weapon then
        self.view.itemIconImg2.gameObject:SetActive(false)
        self.view.itemIconImg2Lock.gameObject:SetActive(false)
        if not self.view.lock.gameObject.activeSelf and remainCount ~= 0 then
            self.view.itemWeaponIcon.gameObject:SetActive(true)
            self.view.weaponIconImg:LoadSprite(UIConst.UI_SPRITE_GACHA_WEAPON, itemData.iconId)
        else
            self.view.weaponIconImgLock.gameObject:SetActive(true)
            self.view.itemWeaponIconLock.gameObject:SetActive(true)
            self.view.weaponIconImgLock:LoadSprite(UIConst.UI_SPRITE_GACHA_WEAPON, itemData.iconId)
        end
        self.view.starGroup:InitStarGroup(itemData.rarity)
        self.view.ownNumber.gameObject:SetActive(false)
        
        self.view.itemIcon.view.gameObject:SetActive(false)
        self.view.itemIconLock.view.gameObject:SetActive(false)
    else
        self.view.itemWeaponIcon.gameObject:SetActive(false)
        self.view.weaponIconImgLock.gameObject:SetActive(false)
        local isUnlockState = not self.view.lock.gameObject.activeSelf and remainCount ~= 0
        if isUnlockState then
            self.view.itemIconImg2.gameObject:SetActive(false)
            self.view.itemIconImg2Lock.gameObject:SetActive(false)
            self.view.itemIcon.view.gameObject:SetActive(true)
            self.view.itemIconLock.view.gameObject:SetActive(false)
            self.view.itemIcon:InitItemIcon(self.m_itemId, true)
        else
            self.view.itemIconImg2.gameObject:SetActive(false)
            self.view.itemIconImg2Lock.gameObject:SetActive(false)
            self.view.itemIcon.view.gameObject:SetActive(false)
            self.view.itemIconLock.view.gameObject:SetActive(true)
            self.view.itemIconLock:InitItemIcon(self.m_itemId, true)
        end
        if itemData.type == GEnums.ItemType.Char then
            self.view.starGroup:InitStarGroup(itemData.rarity)
            self.view.ownNumber.gameObject:SetActive(false)
        else
            self.view.starGroup.gameObject:SetActive(false)
            self.view.ownNumber.gameObject:SetActive(true)
            self.view.ownNumberTxt.text = haveItemCount
        end
        
    end

    self.view.inventoryTagTxt01.text = remainCount == -1 and "∞" or remainCount

    if remainCount == 0 then
        self.view.inventoryTagTxt01.color = self.view.config.INVENTORY_RED_COLOR
    else
        self.view.inventoryTagTxt01.color = self.view.config.INVENTORY_NORMAL_COLOR
    end

    local leftTime = shopSystem:GetWeaponGoodsTimeLimit(arg)
    if leftTime == -1 and arg.closeTimeStamp ~= 0 then
        leftTime = arg.closeTimeStamp - DateTimeUtils.GetCurrentTimestampBySeconds() + 1
    end
    if leftTime == -1 then
        leftTime = DomainShopUtils.getNextServerRefreshTimeLeftSecByType(goodsTableData.limitCountRefreshType)
    end
    if leftTime > -1 then
        self.view.tagTime.gameObject:SetActive(true)
        self.view.timeGreen.gameObject:SetActive(false)
        self.view.timeYellow.gameObject:SetActive(false)
        self.view.timeRed.gameObject:SetActive(false)
        local leftTimeStr = UIUtils.getShortLeftTime(leftTime)
        if leftTime >= 3600 * 24 * 3 then
            self.view.timeGreen.gameObject:SetActive(true)
            self.view.timeGreenText.text = leftTimeStr
        elseif leftTime < 3600 * 24 * 3 and leftTime > 3600 * 24 then
            self.view.timeYellow.gameObject:SetActive(true)
            self.view.timeYellowText.text = leftTimeStr
        else
            self.view.timeRed.gameObject:SetActive(true)
            self.view.timeRedText.text = leftTimeStr
        end
    else
        self.view.tagTime.gameObject:SetActive(false)
    end
end




ShopDetailCtrl._OnClickConfirm = HL.Method() << function(self)
    local buyCount = self.view.numberSelector.curNumber
    local info = self.m_info

    
    local inventorySystem = GameInstance.player.inventory
    if inventorySystem:IsPlaceInBag(self.m_itemId) then
        
        local itemTableData = Tables.itemTable[self.m_itemId]
        local stackCount = itemTableData.maxBackpackStackCount

        local totalCount = self.m_bundleCount * buyCount

        local itemBag = inventorySystem.itemBag:GetOrFallback(Utils.getCurrentScope())
        local emptySlotCount = itemBag.slotCount - itemBag:GetUsedSlotCount()
        local sameItemCount = itemBag:GetCount(self.m_itemId)
        local itemSlotCount = math.ceil(sameItemCount / stackCount)

        local capacity
        if itemSlotCount > 0 then
            capacity = (emptySlotCount + itemSlotCount) * stackCount - sameItemCount
        else
            capacity = stackCount * emptySlotCount
        end

        if capacity < totalCount then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SHOP_BACKPACK_FULL)
            return
        end
    end

    GameInstance.player.shopSystem:BuyGoods(info.shopId, info.goodsId, buyCount)
end




ShopDetailCtrl.OnBuyItemSucc = HL.Method(HL.Any) << function(self, arg)
    local info = self.m_info
    local goodsTableData = Tables.shopGoodsTable:GetValue(info.goodsTemplateId)
    local displayItem = UIUtils.getRewardFirstItem(goodsTableData.rewardId)
    local itemId = displayItem.id
    local itemData = Tables.itemTable[itemId]
    local allDisplayItems = UIUtils.getRewardItems(goodsTableData.rewardId)
    local items = {}

    for i = 1, #allDisplayItems do
        local displayItem = allDisplayItems[i]
        local itemId = displayItem.id
        local itemData = Tables.itemTable[itemId]
        local totalCount = displayItem.count * self.view.numberSelector.curNumber
        if itemData.maxStackCount <= 1 and Utils.isItemInstType(itemId) then
            for i = 1, totalCount do
                local item = {
                    id = displayItem.id,
                    count = 1,
                    type = itemData.type,
                }
                table.insert(items, item)
            end
        else
            local item = {
                id = displayItem.id,
                count = totalCount,
            }
            table.insert(items, item)
        end
    end

    if itemData.type == GEnums.ItemType.Char then
        local rewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(CS.Beyond.GEnums.RewardSourceType.Shop)
        Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
            title = Language.LUA_BUY_ITEM_SUCC_TITLE,
            icon = "icon_common_rewards",
            items = items,
            chars = rewardPack.chars,
            onComplete = function()
                Notify(MessageConst.AFTER_ON_BUY_ITEM_SUCC)
            end,
        })

    elseif itemData.type == GEnums.ItemType.Weapon then
        local weapons = {}
        local weapon = {}
        weapon.weaponId = itemId
        weapon.rarity = Tables.itemTable:GetValue(itemId).rarity
        
        
        weapon.items = {}
        for _, item in pairs(items) do
            if item.type ~= GEnums.ItemType.Weapon then
                table.insert(weapon.items, item)
            end
        end
        
        weapon.isNew = Utils.getItemCount(itemId) == 0
        table.insert(weapons, weapon)
        local onComplete = function()
            Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
                title = Language.LUA_BUY_ITEM_SUCC_TITLE,
                icon = "icon_common_rewards",
                items = items,
            })
            Notify(MessageConst.AFTER_ON_BUY_ITEM_SUCC)
        end
        PhaseManager:OpenPhaseFast(PhaseId.GachaWeapon, {
            weapons = weapons,
            onComplete = onComplete,
        })
    else
        Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
            title = Language.LUA_BUY_ITEM_SUCC_TITLE,
            icon = "icon_common_rewards",
            items = items,
            onComplete = function()
                Notify(MessageConst.AFTER_ON_BUY_ITEM_SUCC)
            end,
        })
    end
    self:TryClose()
end








ShopDetailCtrl.TryClose = HL.Method() << function(self)
    if self.m_phase then
        self.m_phase:RemovePhasePanelItemById(PANEL_ID)
    else
        self:Close()
    end
end



ShopDetailCtrl._OnCloseShopDetailPanel = HL.Method() << function(self)
    if self:IsPlayingAnimationOut() then
        return
    end
    self:TryClose()
end



ShopDetailCtrl._OnShowItemTips = HL.Method() << function(self)
    self:_SetNumberSelectorKeyHint(false)
end



ShopDetailCtrl._OnHideItemTips = HL.Method() << function(self)
    self:_SetNumberSelectorKeyHint(true)
end




ShopDetailCtrl._SetNumberSelectorKeyHint = HL.Method(HL.Boolean) << function(self, active)
    if not DeviceInfo.usingController then
        return
    end
    
    local state = active and CS.Beyond.UI.CustomUIStyle.OverrideValidState.None
        or CS.Beyond.UI.CustomUIStyle.OverrideValidState.ForceNotValid
    self.view.numberSelector.view.addButton.transform:Find("KeyHint"):GetComponent("CustomUIStyle").overrideValidState = state
    self.view.numberSelector.view.reduceButton.transform:Find("KeyHint"):GetComponent("CustomUIStyle").overrideValidState = state
end

HL.Commit(ShopDetailCtrl)
