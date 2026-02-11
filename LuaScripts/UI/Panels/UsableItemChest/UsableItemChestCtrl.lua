
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.UsableItemChest
local PHASE_ID = PhaseId.UsableItemChest
local ITEM_BTN_ANIM_UNSELECTED = "usable_item_chest_item_unselected"
local ITEM_BTN_ANIM_SELECTED = "usable_item_chest_item_selected"
local ITEM_BTN_ANIM_DISABLED = "usable_item_chest_item_disabled"
local RANDOM_TEXT = "ui_usableitemchestpanel_random_info"
local ITEM_SLOT_DISABLED = 1
local ITEM_SLOT_SELECTED = 2
local ITEM_SLOT_UNSELECTED = 3























UsableItemChestCtrl = HL.Class('UsableItemChestCtrl', uiCtrl.UICtrl)







UsableItemChestCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SC_OPEN_USABLE_ITEM_CHEST] = '_OnSCOpenInventoryChest',
}


UsableItemChestCtrl.m_itemId = HL.Field(HL.String) << ""


UsableItemChestCtrl.m_chestData = HL.Field(HL.Any)


UsableItemChestCtrl.m_optionsCount = HL.Field(HL.Number) << 0


UsableItemChestCtrl.m_chosenRewardIds = HL.Field(HL.Table)


UsableItemChestCtrl.m_itemSlotConditions = HL.Field(HL.Table)


UsableItemChestCtrl.m_chosenRewardsCount = HL.Field(HL.Number) << 0


UsableItemChestCtrl.m_maxChosenRewardCount = HL.Field(HL.Number) << 0


UsableItemChestCtrl.m_chooseItemPageBuild = HL.Field(HL.Boolean) << false


UsableItemChestCtrl.m_firstRandomItemId = HL.Field(HL.String) << ""





UsableItemChestCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.UsableItemChest)
    end)

    self.m_itemId = args.itemId
    local getUsableItemChestInfo, usableItemChestData = Tables.usableItemChestTable:TryGetValue(self.m_itemId)
    if not getUsableItemChestInfo then
        logger.error("未成功获取到可使用物品箱数据" .. self.m_itemId)
        return
    end
    self.m_chestData = usableItemChestData

    self.m_chosenRewardIds = {}
    self.m_itemSlotConditions = {}

    self:_FillLeftBigItem()
    local chestCount = Utils.getItemCount(self.m_itemId, true, true)
    self.view.numberSelector:InitNumberSelector(1, 1, chestCount, function()
        self:_OnNumberChange()
    end)


    local type = usableItemChestData.type
    if type == GEnums.ItemCaseType.SelfSelected then
        self.view.titleText.text = Language.LUA_USABLE_ITEM_CHEST_TITLE_SELECT
        self:_OpenChooseItemPage()
        self.view.chooseItemPageRoot.naviGroup:NaviToThisGroup()
    elseif type == GEnums.ItemCaseType.Random then
        self.view.titleText.text = Language.LUA_USABLE_ITEM_CHEST_TITLE_RANDOM
        self:_OpenRandomChestPanel()
        
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder(
        { self.view.inputGroup.groupId })
end



UsableItemChestCtrl._OnNumberChange = HL.Method() << function(self)
    if self.m_chestData.type ~= GEnums.ItemCaseType.SelfSelected then
        return
    end
    if not self.view.chooseChestCountPageRoot.gameObject.activeInHierarchy then
        return
    end

    local chestCount = self.view.numberSelector.curNumber
    local panel = self.view.chooseChestCountPageRoot

    local displayBigItemList = {}
    for rewardId, noUseValue in pairs(self.m_chosenRewardIds) do
        local itemInfoPack = self:_GetItemInfoFromRewardId(rewardId)
        itemInfoPack[1].count = itemInfoPack[1].count * chestCount
        table.insert(displayBigItemList, itemInfoPack)
    end

    local chosenItemCount = #displayBigItemList
    if chosenItemCount < 3 then
        chosenItemCount = 3
    end

    panel.m_cellCache:Refresh(chosenItemCount, function(bigItemCell, index)
        local itemInfoPack = displayBigItemList[index]
        if itemInfoPack ~= nil then
            bigItemCell.itemBig.gameObject:SetActive(true)
            bigItemCell.emptyStateRoot.gameObject:SetActive(false)
            bigItemCell.itemBig:InitItem(itemInfoPack[1], true)
            bigItemCell.itemBig:SetExtraInfo({
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,  
                tipsPosTransform = bigItemCell.itemBig.transform,  
                isSideTips = DeviceInfo.usingController,
            })
            local count = itemInfoPack[1].count
            if count > 1 then
                bigItemCell.itemBig.view.countNode.gameObject:SetActive(true)
                bigItemCell.itemBig.view.count.gameObject:SetActive(true)
                bigItemCell.itemBig.view.count.text = tostring(count)
            end
        else
            bigItemCell.itemBig.gameObject:SetActive(false)
            bigItemCell.emptyStateRoot.gameObject:SetActive(true)
        end
    end)
end



UsableItemChestCtrl._OpenRandomChestPanel = HL.Method() << function(self)
    self.view.randomChestPageRoot.youWillGetOneItemText:SetAndResolveTextStyle(Language.ui_usableitemchestpanel_random_info)
    self.view.randomChestPageRoot.gameObject:SetActive(true)
    self.view.chooseChestCountPageRoot.gameObject:SetActive(false)
    self.view.chooseItemPageRoot.gameObject:SetActive(false)
    self.view.numberSelectorRoot.gameObject:SetActive(true)

    self.view.btnBack.gameObject:SetActive(false)
    self.view.btnClose.gameObject:SetActive(true)

    self.view.emptyButtonNotChooseEnough.gameObject:SetActive(false)
    self.view.btnConfirmText.text = Language.LUA_USABLE_ITEM_CHEST_CONFIRM_OPEN
    self.view.btnConfirmXText.text = Language.LUA_USABLE_ITEM_CHEST_CONFIRM_OPEN

    self.view.btnConfirm.onClick:AddListener(function()
        self:_DoSendReqToServerRandomChest()
    end)
    self.view.btnConfirmX.onClick:AddListener(function()
        self:_DoSendReqToServerRandomChest()
    end)

    local panel = self.view.randomChestPageRoot
    panel.m_cellCache = UIUtils.genCellCache(panel.singleItem)

    local count = self.m_chestData.randomChestItemIds.Count
    if count ~= self.m_chestData.randomChestItemCounts.Count then
        logger.error("随机可使用物品箱的展示信息配置错误！ " .. self.m_itemId)
        return
    end

    local itemInitInfoList = {}
    for i = 1, count do
        local itemId = self.m_chestData.randomChestItemIds[CSIndex(i)]
        local itemCount = self.m_chestData.randomChestItemCounts[CSIndex(i)]
        local _, itemData = Tables.itemTable:TryGetValue(itemId)

        table.insert(itemInitInfoList, {
            id = itemId,
            count = itemCount,
            rarity = itemData.rarity,
            type = itemData.type:ToInt(),
            name = itemData.name,
        })
    end
    table.sort(itemInitInfoList, Utils.genSortFunction({"rarity", "type", "id"}, false))

    panel.m_cellCache:Refresh(count, function(itemCell, index)
        local infoPack = itemInitInfoList[index]
        local initItemInfo = {id = infoPack.id}
        itemCell.item:InitItem(initItemInfo, true)
        itemCell.numberText.text = tostring(infoPack.count)
        itemCell.itemNameText.text = infoPack.name
        if index == 1 then
            self.m_firstRandomItemId = infoPack.id
        end
    end)

    
    self.view.btnConfirmX.gameObject:SetActive(count == 1)
    self.view.btnConfirm.gameObject:SetActive(count ~= 1)
end



UsableItemChestCtrl._OpenChooseItemPage = HL.Method() << function(self)
    self.view.randomChestPageRoot.gameObject:SetActive(false)
    self.view.chooseChestCountPageRoot.gameObject:SetActive(false)
    self.view.chooseItemPageRoot.gameObject:SetActive(true)
    if self.m_chooseItemPageBuild == false then
        self:_BuildChooseItemPage()
    end

    self.view.btnConfirm.onClick:RemoveAllListeners()
    self.view.btnConfirm.onClick:AddListener(function()
        self:_OpenChooseChestCountPage()
    end)
    self.view.btnConfirmText.text = Language.LUA_USABLE_ITEM_CHEST_CONFIRM_CHOOSE

    self.view.btnClose.gameObject:SetActive(true)
    self.view.btnBack.gameObject:SetActive(false)
    self.view.numberSelectorRoot.gameObject:SetActive(false)

    self:_RefreshSelectItemPage()
end



UsableItemChestCtrl._BuildChooseItemPage = HL.Method() << function(self)
    self.m_chooseItemPageBuild = true
    self.m_chosenRewardIds = {}
    local panel = self.view.chooseItemPageRoot
    panel.m_cellCache = UIUtils.genCellCache(panel.singleItem)

    local itemChestData = self.m_chestData
    local canSelectCount = itemChestData.selectedCount
    self.m_maxChosenRewardCount = canSelectCount
    panel.tellYouChooseItemText.text = string.format(Language.LUA_USABLE_ITEM_CHEST_CHOOSE_FROM_LIST, canSelectCount)

    local rewardIdCount = itemChestData.rewardIdList.Count
    self.m_optionsCount = rewardIdCount

    panel.m_cellCache:Refresh(rewardIdCount, function(itemCell, index)
        local rewardId = itemChestData.rewardIdList[CSIndex(index)]
        itemCell.rewardId = rewardId
        local rewardTable = self:_GetItemInfoFromRewardId(rewardId)
        if #rewardTable ~= 1 then
            logger.error("可使用物品箱填入的rewardId不满足内有且仅有一个物品 " .. rewardId)
            return
        end
        local itemId = rewardTable[1].id
        local _, itemData = Tables.itemTable:TryGetValue(itemId)
        local initItemTable = {id = itemId}
        itemCell.item:InitItem(initItemTable, true)
        local itemCount = Utils.getItemCount(itemId, true, true)
        local isGold = itemData and itemData.type == GEnums.ItemType.Gold
        itemCell.haveCountText.text = UIUtils.getNumString(itemCount, isGold)
        itemCell.numberText.text = tostring(rewardTable[1].count)
        local _, insideItemData = Tables.itemTable:TryGetValue(itemId)
        itemCell.nameText.text = insideItemData.name

        itemCell.button.onClick:AddListener(function()
            local isChosen = (self.m_chosenRewardIds[rewardId] ~= nil)
            if isChosen then
                self.m_chosenRewardIds[rewardId] = nil
                self.m_chosenRewardsCount = self.m_chosenRewardsCount - 1
            else
                
                local chosenCountFull = (self.m_chosenRewardsCount == self.m_maxChosenRewardCount)
                if chosenCountFull then
                    return
                end
                self.m_chosenRewardIds[rewardId] = true
                self.m_chosenRewardsCount = self.m_chosenRewardsCount + 1
            end
            self:_RefreshSelectItemPage()
        end)

        
        local bindingId = InputManagerInst:CreateBindingByActionId(
            "show_item_tips",
            function()
                itemCell.item:ShowTips()
            end,
            itemCell.button.hoverBindingGroupId)
        InputManagerInst:SetBindingText(
            bindingId,
            InputManagerInst:GetActionText("show_item_tips"))
    end)
end



UsableItemChestCtrl._RefreshSelectItemPage = HL.Method() << function(self)
    local chosenCountFull = (self.m_chosenRewardsCount == self.m_maxChosenRewardCount)
    self.view.chooseItemPageRoot.m_cellCache:Update(function(itemCell, index)
        local rewardId = itemCell.rewardId
        if self.m_chosenRewardIds[rewardId] ~= nil then
            if self.m_itemSlotConditions[index] ~= ITEM_SLOT_SELECTED then
                itemCell.animationWrapper:Play(ITEM_BTN_ANIM_SELECTED)
                itemCell.button.customBindingViewLabelText = Language["key_hint_usable_item_no_select_item"]
                self.m_itemSlotConditions[index] = ITEM_SLOT_SELECTED
            end
        else
            local notChosenAnim
            if chosenCountFull then
                if self.m_itemSlotConditions[index] ~= ITEM_SLOT_DISABLED then
                    notChosenAnim = ITEM_BTN_ANIM_DISABLED
                    self.m_itemSlotConditions[index] = ITEM_SLOT_DISABLED
                end
            else
                if self.m_itemSlotConditions[index] ~= ITEM_SLOT_UNSELECTED then
                    notChosenAnim = ITEM_BTN_ANIM_UNSELECTED
                    self.m_itemSlotConditions[index] = ITEM_SLOT_UNSELECTED
                end
            end
            if notChosenAnim ~= nil then
                itemCell.animationWrapper:Play(notChosenAnim)
                itemCell.button.customBindingViewLabelText = Language["key_hint_usable_item_select_item"]
            end
        end
    end)
    local targetLanguage
    if chosenCountFull then
        targetLanguage = Language.LUA_USABLE_ITEM_CHEST_CHOOSE_NUMBER_FULL
    else
        targetLanguage = Language.LUA_USABLE_ITEM_CHEST_CHOOSE_NUMBER_NOT_FULL
    end
    self.view.chooseItemPageRoot.chosenNumberProgressText.text =
        string.format(targetLanguage, self.m_chosenRewardsCount, self.m_maxChosenRewardCount)
    self.view.emptyButtonNotChooseEnough.gameObject:SetActive(not chosenCountFull)
    self.view.btnConfirm.gameObject:SetActive(chosenCountFull)
    self.view.btnConfirmX.gameObject:SetActive(false)
end



UsableItemChestCtrl._OpenChooseChestCountPage = HL.Method() << function(self)
    
    local chosenCountFull = (self.m_chosenRewardsCount == self.m_maxChosenRewardCount)

    if not chosenCountFull then
        logger.error("没选满，但是进入了选箱子界面，寄")
    end

    self.view.randomChestPageRoot.gameObject:SetActive(false)
    self.view.chooseItemPageRoot.gameObject:SetActive(false)
    self.view.chooseChestCountPageRoot.gameObject:SetActive(true)
    self.view.numberSelectorRoot.gameObject:SetActive(true)
    self.view.emptyButtonNotChooseEnough.gameObject:SetActive(false)

    self.view.btnBack.gameObject:SetActive(true)
    self.view.btnClose.gameObject:SetActive(false)
    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        self:_OpenChooseItemPage()
        self.view.chooseItemPageRoot.animationWrapper:PlayInAnimation();
    end)

    self.view.btnConfirm.gameObject:SetActive(false)
    self.view.btnConfirmX.gameObject:SetActive(true)

    self.view.btnConfirmX.onClick:RemoveAllListeners()
    self.view.btnConfirmX.onClick:AddListener(function()
        self:_DoSendReqToServerChoosableChest()
    end)
    self.view.btnConfirmXText.text = Language.LUA_USABLE_ITEM_CHEST_CONFIRM_OPEN

    local panel = self.view.chooseChestCountPageRoot
    if panel.m_cellCache == nil then
        panel.m_cellCache = UIUtils.genCellCache(panel.bigItemCell)
    end

    local displayBigItemList = {}
    for rewardId, noUseValue in pairs(self.m_chosenRewardIds) do
        local itemInfoPack = self:_GetItemInfoFromRewardId(rewardId)
        table.insert(displayBigItemList, itemInfoPack)
    end

    local chosenItemCount = #displayBigItemList
    if chosenItemCount < 3 then
        chosenItemCount = 3
    end

    panel.m_cellCache:Refresh(chosenItemCount, function(bigItemCell, index)
        local itemInfoPack = displayBigItemList[index]
        if itemInfoPack ~= nil then
            bigItemCell.itemBig.gameObject:SetActive(true)
            bigItemCell.emptyStateRoot.gameObject:SetActive(false)
            bigItemCell.itemBig:InitItem(itemInfoPack[1], true)

            
            
            
            
            
            
            
            
        else
            bigItemCell.itemBig.gameObject:SetActive(false)
            bigItemCell.emptyStateRoot.gameObject:SetActive(true)
        end
    end)
    self:_OnNumberChange()

    
    local naviGroup = panel.popNode
    naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)  
            self.view.numberSelector.view.reduceBtnKeyHint.gameObject:SetActive(true)
            self.view.numberSelector.view.addBtnKeyHint.gameObject:SetActive(true)
        else
            
            self.view.numberSelector.view.reduceBtnKeyHint.gameObject:SetActive(false)
            self.view.numberSelector.view.addBtnKeyHint.gameObject:SetActive(false)
        end
    end)
end



UsableItemChestCtrl._DoSendReqToServerChoosableChest = HL.Method() << function(self)
    local chosenCountFull = (self.m_chosenRewardsCount == self.m_maxChosenRewardCount)

    if not chosenCountFull then
        logger.error("没选满，但是试图发REQ，寄")
    end
    local rewardIdList = {}

    for rewardId, noUseValue in pairs(self.m_chosenRewardIds) do
        table.insert(rewardIdList, rewardId)
    end
    local chestCount = self.view.numberSelector.curNumber
    GameInstance.player.inventory:OpenUsableItemChest(self.m_itemId, chestCount, rewardIdList)
end



UsableItemChestCtrl._DoSendReqToServerRandomChest = HL.Method() << function(self)
    local chestCount = self.view.numberSelector.curNumber
    GameInstance.player.inventory:OpenUsableItemChest(self.m_itemId, chestCount, {})
end




UsableItemChestCtrl._OnSCOpenInventoryChest = HL.Method(HL.Table) << function(self, args)

    local openCount = args[1]
    if openCount == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_USABLE_ITEM_CHEST_OPEN_FAILED)
        return
    end

    PhaseManager:ExitPhaseFast(PhaseId.UsableItemChest)
    if openCount ~= self.view.numberSelector.curNumber then
        local toast = string.format(Language.LUA_USABLE_ITEM_CHEST_OPEN_PARTLY_SUCCESS, openCount)
        Notify(MessageConst.SHOW_TOAST, toast)
    end
    local rewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(CS.Beyond.GEnums.RewardSourceType.ItemCase)
    local items = {}
    local chars = nil
    if rewardPack and rewardPack.rewardSourceType == CS.Beyond.GEnums.RewardSourceType.ItemCase then
        for _, itemBundle in pairs(rewardPack.itemBundleList) do
            local _, itemData = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemData then
                local putInside = false
                for i = 1, #items do
                    if items[i].id == itemData.id and itemBundle.instId == 0 then
                        items[i].count = items[i].count + itemBundle.count
                        putInside = true
                        break
                    end
                end

                if not putInside then
                    table.insert(items, {id = itemBundle.id,
                                         count = itemBundle.count,
                                         instData = itemBundle.instData,
                                         instId = itemBundle.instId,
                                         rarity = itemData.rarity,
                                         type = itemData.type:ToInt()})
                end
            end
        end
        table.sort(items, Utils.genSortFunction({"rarity", "type", "id"}, false))
        
        chars = rewardPack.chars
    end
    local rewardPanelArgs = {}
    rewardPanelArgs.items = items
    rewardPanelArgs.chars = chars
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, rewardPanelArgs)
end




UsableItemChestCtrl._GetItemInfoFromRewardId = HL.Method(HL.String).Return(HL.Table) << function(self, rewardId)
    local findReward, rewardData = Tables.rewardTable:TryGetValue(rewardId or "")
    local ret = {}
    if findReward then
        for _, itemBundle in pairs(rewardData.itemBundles) do
            table.insert(ret, {
                id = itemBundle.id,
                count = itemBundle.count,
            })
        end
    end

    return ret
end



UsableItemChestCtrl._FillLeftBigItem = HL.Method() << function(self)
    local _, itemData = Tables.itemTable:TryGetValue(self.m_itemId)
    self.view.itemIconBig:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, itemData.iconId)
    self.view.chestNameText.text = itemData.name
    local chestCount = Utils.getItemCount(self.m_itemId, true, true)
    self.view.chestCountText.text = tostring(chestCount)
end

HL.Commit(UsableItemChestCtrl)
