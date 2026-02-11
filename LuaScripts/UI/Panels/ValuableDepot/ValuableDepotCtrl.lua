local ItemType2DepotConfig = {
    [GEnums.ItemValuableDepotType.SpecialItem] = {
        infoProcessFuncName = "processItemDefault",
        isUnlocked = true,
        getSortOptions = function()
            return {
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
                    keys = { "sortId1", "sortId2", "rarity", "id" },
                },
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_RARITY,
                    keys = { "rarity", "sortId1", "sortId2", "id" },
                },
            }
        end,
        isNormalDestroy = true,
        infoStateName = "default",
    },
    [GEnums.ItemValuableDepotType.CommercialItem] = {
        infoProcessFuncName = "processItemDefault",
        isUnlocked = true,
        getSortOptions = function()
            return {
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
                    keys = { "sortId1", "sortId2", "rarity", "id" },
                },
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_RARITY,
                    keys = { "rarity", "sortId1", "sortId2", "id" },
                },
            }
        end,
        extraDisplayInfoFuncName = "displayCommercialItemInfo",
        infoStateName = "default",
        tabRedDotName = "ValuableDepotTabCommercialItem",
    },
    [GEnums.ItemValuableDepotType.MissionItem] = {
        infoProcessFuncName = "processItemDefault",
        isUnlocked = true,
        getSortOptions = function()
            return {
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
                    keys = { "newOrder", "sortId1", "sortId2", "id" },
                }
            }
        end,
        infoStateName = "default",
    },
    [GEnums.ItemValuableDepotType.Weapon] = {
        infoProcessFuncName = "processWeapon",
        systemUnlockType = GEnums.UnlockSystemType.Weapon,
        getSortOptions = function()
            return UIConst.WEAPON_SORT_OPTION
        end,
        contentFilterOptionFuncName = "generateConfig_DEPOT_WEAPON",
        extraDisplayInfoFuncName = "displayWeaponInfo",
        infoStateName = "weapon",
    },
    [GEnums.ItemValuableDepotType.WeaponGem] = {
        infoProcessFuncName = "processWeaponGem",
        systemUnlockType = GEnums.UnlockSystemType.Weapon,
        getSortOptions = function()
            return UIConst.WEAPON_GEM_SORT_OPTION
        end,
        contentFilterOptionFuncName = "generateConfig_DEPOT_GEM",
        extraDisplayInfoFuncName = "displayWeaponGemInfo",
        destroyFilterOptionFuncName = "generateConfig_DEPOT_GEM_DESTROY",
        infoStateName = "weaponGem",
        isGemDestroy = true,
    },
    [GEnums.ItemValuableDepotType.Equip] = {
        infoProcessFuncName = "processEquip",
        systemUnlockType = GEnums.UnlockSystemType.Equip,
        getSortOptions = function()
            return {
                {
                    name = Language.LUA_DEPOT_SORT_OPTION_RARITY,
                    keys = { "rarity", "minWearLv", "equipEnhanceLevel", "sortId1", "sortId2", "id" },
                },
            }
        end,
        contentFilterOptionFuncName = "generateConfig_DEPOT_EQUIP",
        destroyFilterOptionFuncName = "generateConfig_DEPOT_EQUIP_DESTROY",
        isEquipDestroy = true,
        extraDisplayInfoFuncName = "displayEquipInfo",
        infoStateName = "equip",
    },
}
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget

local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ValuableDepot






















































































ValuableDepotCtrl = HL.Class('ValuableDepotCtrl', uiCtrl.UICtrl)


local inventorySystem = GameInstance.player.inventory








ValuableDepotCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_VALUABLE_DEPOT_CHANGED] = 'OnValuableDepotChanged',
    [MessageConst.ON_ITEM_LOCKED_STATE_CHANGED] = 'OnItemLockedStateChanged',
    [MessageConst.ON_EQUIP_RECYCLE] = 'OnEquipRecycle',
    [MessageConst.ON_GEM_DISMANTLE] = 'OnGemDismantle',
    [MessageConst.ON_LT_ITEM_EXPIRE] = 'OnLTItemExpire',
    [MessageConst.ON_LT_ITEM_EXPIRE_CONFIRM_RSP] = 'ShowLTItemExpirePopup',
    [MessageConst.ON_USE_ITEM] = 'OnUseItem',
    [MessageConst.ON_BATTLE_PASS_TICKET_REWARD] = 'OnBPTicketReward',
}


ValuableDepotCtrl.m_curTabIndex = HL.Field(HL.Number) << 1


ValuableDepotCtrl.m_curItemIndex = HL.Field(HL.Number) << 1


ValuableDepotCtrl.m_inDestroyMode = HL.Field(HL.Boolean) << false


ValuableDepotCtrl.m_tabCells = HL.Field(HL.Forward('UIListCache'))


ValuableDepotCtrl.m_tabsInfo = HL.Field(HL.Table)


ValuableDepotCtrl.m_curTabAllItemList = HL.Field(HL.Table) 


ValuableDepotCtrl.m_curShowItemList = HL.Field(HL.Table) 


ValuableDepotCtrl.m_curShowCount = HL.Field(HL.Number) << 0


ValuableDepotCtrl.m_curContentFilterConfigs = HL.Field(HL.Table)


ValuableDepotCtrl.m_curDestroyFilterConfigs = HL.Field(HL.Table)


ValuableDepotCtrl.m_getItemCell = HL.Field(HL.Function)


ValuableDepotCtrl.m_selectItemInfoWhenHide = HL.Field(HL.Table)


ValuableDepotCtrl.m_selectTabInfoWhenHide = HL.Field(HL.Table)


ValuableDepotCtrl.m_oriPaddingBottom = HL.Field(HL.Number) << 0


ValuableDepotCtrl.m_getPreviewItemCell = HL.Field(HL.Function)








ValuableDepotCtrl.OnCreate = HL.Override(HL.Any) << function(self, itemId)
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.ValuableDepot)
    end)
    self:BindInputPlayerAction("common_open_valuable_depot", function()
        PhaseManager:PopPhase(PhaseId.ValuableDepot)
    end, self.view.btnClose.groupId)

    self.m_readItemIds = {}
    self.m_readItemInstIds = {}

    self.m_getItemCell = UIUtils.genCachedCellFunction(self.view.itemScrollList)
    self.view.itemScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getItemCell(obj), LuaIndex(csIndex))
    end)
    self.view.itemScrollList.onSelectedCell:AddListener(function(obj, csIndex)
        self:_OnClickItem(LuaIndex(csIndex), nil, true)
    end)
    self.view.itemScrollList.getCurSelectedIndex = function()
        return CSIndex(self.m_curItemIndex)
    end
    self.m_oriPaddingBottom = self.view.itemScrollList:GetPadding().bottom

    self.view.itemInfoNode.wikiBtn.onClick:AddListener(function()
        self:_ShowWiki()
    end)

    self.view.bottomNode.btnGemEnhance.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.GemEnhance)
    end)
    self.view.bottomNode.btnEquipTech.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.EquipTech, { isEnhance = true })
    end)

    self.m_tabCells = UIUtils.genCellCache(self.view.tabs.tabCell)

    self:_InitController()
    self:_InitDepotConfigs()
    self:_InitDestroyNode()

    self:_RefreshTabsInfo(itemId)
end



ValuableDepotCtrl.OnAnimationInFinished = HL.Override() << function(self)
    self:CheckLTItemExpire()
end



ValuableDepotCtrl.OnShow = HL.Override() << function(self)
    if self.m_selectItemInfoWhenHide and self.m_selectTabInfoWhenHide then
        self:_RecollectItemBundles(self.m_selectTabInfoWhenHide.type)
        self:_RefreshTabsInfo(self.m_selectItemInfoWhenHide.id, self.m_selectItemInfoWhenHide.instId)
    end
end



ValuableDepotCtrl.OnHide = HL.Override() << function(self)
    local curSelectItemInfo = self.m_curShowItemList[self.m_curItemIndex]
    if curSelectItemInfo then
        self.m_selectItemInfoWhenHide = curSelectItemInfo
    end

    local curSelectTabInfo = self.m_tabsInfo[self.m_curTabIndex]
    if curSelectTabInfo then
        self.m_selectTabInfoWhenHide = curSelectTabInfo
    end

    if self.m_inDestroyMode then
        self:_ToggleDestroyMode(false, true)
    end
end



ValuableDepotCtrl.OnClose = HL.Override() << function(self)
    self:_ReadCurShowingItems()
end







ValuableDepotCtrl._InitDepotConfigs = HL.Method() << function(self)
    for _, config in pairs(ItemType2DepotConfig) do
        if config.contentFilterOptionFuncName then
            config.contentFilterOptions = FilterUtils[config.contentFilterOptionFuncName]()
        end
        if config.destroyFilterOptionFuncName then
            config.destroyFilterOptions = FilterUtils[config.destroyFilterOptionFuncName]()
        end
    end
end





ValuableDepotCtrl._RefreshTabsInfo = HL.Method(HL.Opt(HL.String, HL.Any)) << function(self, itemId, instId)
    local tabInfos = {}
    for _, v in pairs(Tables.valuableDepot) do
        if not v.isHidden and self:_CheckIfTabUnlocked(v.type) then
            local depotConfig = ItemType2DepotConfig[v.type]
            table.insert(tabInfos, {
                type = v.type, 
                data = v,
                name = v.name,
                sortId = v.sortId,
                icon = v.icon,
                redDot = depotConfig.tabRedDotName,
            })
        end
    end
    table.sort(tabInfos, Utils.genSortFunction({ "sortId" }, true))
    self.m_tabsInfo = tabInfos

    if itemId then
        local vType = Utils.getItemValuableDepotType(itemId)
        for k, v in ipairs(tabInfos) do
            if v.type == vType then
                self.m_curTabIndex = k
                break
            end
        end
    end

    self.m_tabCells:Refresh(#tabInfos, function(cell, index)
        local info = tabInfos[index]
        UIUtils.setTabIcons(cell, UIConst.UI_SPRITE_INVENTORY, info.icon)
        cell.toggle.onValueChanged:RemoveAllListeners()
        cell.toggle.isOn = index == self.m_curTabIndex
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                if self.m_curTabIndex == index then
                    return
                end
                self:_ReadCurShowingItems()
                self:_OnClickTab(index)
            end
        end)
        cell.gameObject.name = "Tab-" .. info.type:GetHashCode()
        
        if string.isEmpty(info.redDot) then
            cell.redDot:InitRedDot("ValuableDepotTabCommon", info.type)
        else
            cell.redDot:InitRedDot(info.redDot)
        end
    end)
    self:_OnClickTab(self.m_curTabIndex, itemId, instId)
end






ValuableDepotCtrl._OnClickTab = HL.Method(HL.Number, HL.Opt(HL.String, HL.Any)) << function(self, index, itemId, instId)
    local info = self.m_tabsInfo[index]
    self.m_curTabIndex = index
    self.m_curContentFilterConfigs = {}
    self.m_curDestroyFilterConfigs = {}

    local depotConfig = ItemType2DepotConfig[info.type]
    self.view.bottomNode.filterBtn.gameObject:SetActive(
        depotConfig.contentFilterOptions and next(depotConfig.contentFilterOptions) ~= nil and not DeviceInfo.usingController)
    self.view.bottomNode.filterBtn:InitFilterBtn({
        tagGroups = depotConfig.contentFilterOptions,
        selectedTags = self.m_curContentFilterConfigs,
        onConfirm = function(tags)
            self.m_curContentFilterConfigs = tags
            self.m_curItemIndex = 1
            self:_ApplyFilter()
            self:_ApplySort(self.view.bottomNode.sortNode:GetCurSortData(), self.view.bottomNode.sortNode.isIncremental)
            self:_SetSelectedIndex()
            self:_RefreshItemList(true)
        end,
        getResultCount = function(tags)
            return self:_GetContentFilterResultCount(tags)
        end,
        sortNodeWidget = self.view.bottomNode.sortNode,
    })
    self.view.bottomNode.sortNode:InitSortNode(depotConfig.getSortOptions(), function(optData, isIncremental)
        self:_ApplySort(optData, isIncremental)
        self:_SetSelectedIndex()
        self:_RefreshItemList(true)
    end, 0, nil, true, self.view.bottomNode.filterBtn)

    local isGemEnhanceBtnVisible = info.type == GEnums.ItemValuableDepotType.WeaponGem and
        Utils.isSystemUnlocked(GEnums.UnlockSystemType.GemEnhance)
    self.view.bottomNode.btnGemEnhance.gameObject:SetActive(isGemEnhanceBtnVisible)
    local isEquipTechBtnVisible = info.type == GEnums.ItemValuableDepotType.Equip and
        Utils.isSystemUnlocked(GEnums.UnlockSystemType.EquipProduce) and
        Utils.isSystemUnlocked(GEnums.UnlockSystemType.EquipEnhance)
    self.view.bottomNode.btnEquipTech.gameObject:SetActive(isEquipTechBtnVisible)
    local isRecycleBtnVisible = depotConfig.isEquipDestroy or depotConfig.isGemDestroy
    self.view.bottomNode.desEquipBtn.gameObject:SetActive(isRecycleBtnVisible)
    self.view.bottomNode.destroyBtn.gameObject:SetActive(depotConfig.isNormalDestroy)

    self:_RecollectItemBundles(info.type)

    self.view.tabTitleTxt.text = info.name
    self.view.capacityTxt.text = string.format(Language.LUA_DEPOT_CAPACITY, #self.m_curTabAllItemList, info.data.gridLimit)

    if self.m_inDestroyMode then
        self.m_curItemIndex = -1
    else
        self:_SetSelectedIndex(itemId, instId)
    end

    self:_RefreshItemList(true, true)
end




ValuableDepotCtrl._RecollectItemBundles = HL.Method(HL.Any) << function(self, itemType)
    local allItems = self:_GetAllItemBundlesInDepot(itemType)
    self.m_curTabAllItemList = allItems

    self:_ApplyFilter()
    self:_ApplySort(self.view.bottomNode.sortNode:GetCurSortData(), self.view.bottomNode.sortNode.isIncremental)
end





ValuableDepotCtrl._SetSelectedIndex = HL.Method(HL.Opt(HL.Any, HL.Any)) << function(self, itemId, instId)
    if itemId then
        for k, v in ipairs(self.m_curShowItemList) do
            if v.id == itemId and (not instId or v.instId == instId) then
                self.m_curItemIndex = k
                break
            end
        end
    else
        if InputManagerInst.virtualMouseIconVisible then
            self.m_curItemIndex = -1
        else
            self.m_curItemIndex = math.min(1, self.m_curShowCount)
        end
    end
end





ValuableDepotCtrl._GetAllItemBundlesInDepot = HL.Method(HL.Opt(HL.Userdata, HL.Table)).Return(HL.Table) << function(self, depotType, rst)
    rst = rst or {}
    local depot = GameInstance.player.inventory.valuableDepots[depotType]:GetOrFallback(Utils.getCurrentScope())
    local depotConfig = ItemType2DepotConfig[depotType]
    local infoProcessFunc = FilterUtils[depotConfig.infoProcessFuncName]

    for id, bundle in cs_pairs(depot.normalItems) do
        local info = infoProcessFunc(id)
        if info then
            info.count = bundle.count
            table.insert(rst, info)
        end
    end
    for instId, bundle in cs_pairs(depot.instItems) do
        local info = infoProcessFunc(bundle.id, instId)
        if info then
            info.count = bundle.count
            table.insert(rst, info)
        end
    end
    return rst
end





ValuableDepotCtrl._ApplySort = HL.Method(HL.Table, HL.Boolean) << function(self, option, isIncremental)
    local curSelectItemInfo = self.m_curShowItemList[self.m_curItemIndex]
    table.sort(self.m_curTabAllItemList, Utils.genSortFunction(option.keys, isIncremental))
    table.sort(self.m_curShowItemList, Utils.genSortFunction(option.keys, isIncremental))
    for k, v in ipairs(self.m_curShowItemList) do
        if v == curSelectItemInfo then
            self.m_curItemIndex = k
            break
        end
    end
end



ValuableDepotCtrl._ApplyFilter = HL.Method() << function(self)
    local curTabAllItemList = self.m_curTabAllItemList
    local curFilterConfigs = self.m_curContentFilterConfigs

    if (not curFilterConfigs) or (not next(curFilterConfigs)) then
        self.m_curShowItemList = curTabAllItemList
        self.m_curShowCount = #curTabAllItemList
        return
    end

    local filteredItemList = {}
    for _, itemInfo in pairs(curTabAllItemList) do
        if FilterUtils.checkIfPassFilter(itemInfo, curFilterConfigs) then
            table.insert(filteredItemList, itemInfo)
        end
    end
    self.m_curShowItemList = filteredItemList
    self.m_curShowCount = #filteredItemList
end




ValuableDepotCtrl._GetContentFilterResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if not tags or not next(tags) then
        return
    end
    local count = 0
    for itemIndex, itemInfo in pairs(self.m_curTabAllItemList) do
        if FilterUtils.checkIfPassFilter(itemInfo, tags) then
            count = count + 1
        end
    end
    return count
end





ValuableDepotCtrl._RefreshItemList = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, noRead, setTop)
    logger.info("_RefreshItemList")
    local count = #self.m_curShowItemList
    local isEmpty = count == 0
    self.view.itemScrollList:UpdateCount(count, setTop == true)
    self.view.emptyNode.gameObject:SetActive(isEmpty)
    self.view.itemScrollList.gameObject:SetActive(not isEmpty)
    self.view.itemInfoNode.gameObject:SetActive(not isEmpty)
    if isEmpty then
        self.view.itemInfoNode.animation:SampleToOutAnimationEnd()
    else
        self.view.itemInfoNode.animation:SampleToInAnimationEnd()
    end
    if not isEmpty then
        if self.m_inDestroyMode then
            self:_OnClickItem(-1)
        else
            self:_OnClickItem(self.m_curItemIndex, noRead)
        end
    end
    if DeviceInfo.usingController and isEmpty then
        self.view.itemListNaviGroup:SetLayerSelectedTarget(nil, false)
    end
end





ValuableDepotCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local info = self.m_curShowItemList[index]
    local isEquip = info.data.type == GEnums.ItemType.Equip
    cell:InitItem(info, function()
        self:_OnClickItem(index)
    end)
    if DeviceInfo.usingController then
        cell:SetEnableHoverTips(false)
    end

    local isSelected = index == self.m_curItemIndex
    cell:SetSelected(isSelected and not DeviceInfo.usingController)
    if isSelected and cell.view.button ~= InputManagerInst.controllerNaviManager.curTarget then
        UIUtils.setAsNaviTargetInSilentModeIfNecessary(self.view.itemListNaviGroup, cell.view.button)
    end

    cell.view.imageCharMask.gameObject:SetActive(isEquip)
    if isEquip then
        local equipDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Equip]:GetOrFallback(Utils.getCurrentScope())
        local equipInstDict = equipDepot.instItems
        local _, equipInst = equipInstDict:TryGetValue(info.instId)
        local equippedCardInstId = equipInst.instData.equippedCharServerId
        local isEquipped = equippedCardInstId and equippedCardInstId > 0
        cell.view.count.gameObject:SetActive(false) 
        cell.view.imageCharMask.gameObject:SetActive(isEquipped)
        if isEquipped then
            local charEntityInfo = CharInfoUtils.getPlayerCharInfoByInstId(equippedCardInstId)
            local charTemplateId = charEntityInfo.templateId
            local spriteName = UIConst.UI_CHAR_HEAD_PREFIX .. charTemplateId
            cell.view.imageChar:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD, spriteName)
        end
    end

    local isWeapon = info.data.type == GEnums.ItemType.Weapon
    if isWeapon then
        local weaponDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Weapon]:GetOrFallback(Utils.getCurrentScope())
        local weaponInstDict = weaponDepot.instItems
        local _, weaponInst = weaponInstDict:TryGetValue(info.instId)
        local equippedCardInstId = weaponInst.instData.equippedCharServerId
        local isEquipped = equippedCardInstId and equippedCardInstId > 0
        cell.view.count.gameObject:SetActive(false) 
        cell.view.imageCharMask.gameObject:SetActive(isEquipped)
        if isEquipped then
            local charEntityInfo = CharInfoUtils.getPlayerCharInfoByInstId(equippedCardInstId)
            local charTemplateId = charEntityInfo.templateId
            local spriteName = UIConst.UI_CHAR_HEAD_PREFIX .. charTemplateId
            cell.view.imageChar:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD, spriteName)
        end
    end

    local isWeaponGem = info.data.type == GEnums.ItemType.WeaponGem
    local isWeaponGemEquipped = false
    if isWeaponGem then
        local weaponGemDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.WeaponGem]:GetOrFallback(Utils.getCurrentScope())
        local weaponGemInstDict = weaponGemDepot.instItems
        local _, weaponGemInst = weaponGemInstDict:TryGetValue(info.instId)
        isWeaponGemEquipped = weaponGemInst.instData.weaponInstId > 0
    end
    cell.view.gemEquipped.gameObject:SetActive(isWeaponGemEquipped)

    cell.gameObject.name = "Item-" .. info.id
    
    if info.data.valuableDepotRedDot then
        cell:UpdateRedDot("ValuableDepotItem", info.id)
    else
        cell:UpdateRedDot()
    end
    self:_UpdateItemBlockMask(cell, info)
    cell.view.button:ChangeActionOnSetNaviTarget(self.m_inDestroyMode and ActionOnSetNaviTarget.PressConfirmTriggerOnClick or ActionOnSetNaviTarget.AutoTriggerOnClick)
    cell.view.button.onHoverChange:RemoveAllListeners()
    cell.view.button.onHoverChange:AddListener(function(isHover)
        if isHover and DeviceInfo.usingController and self.m_inDestroyMode then
            self:_OnClickItem(index, nil, true)
        end
    end)

    if cell.redDot.curIsActive then
        if info.instId then
            self.m_readItemInstIds[info.instId] = true
        else
            self.m_readItemIds[info.id] = true
        end
    end

    if not self.m_inDestroyMode then
        cell.view.multiSelectMark.gameObject:SetActive(false)
        cell.view.redMultiSelectMark.gameObject:SetActive(false)
        return
    end
    self:_UpdateItemCellDestroySelectPart(index, cell)
end






ValuableDepotCtrl._OnClickItem = HL.Method(HL.Number, HL.Opt(HL.Boolean, HL.Boolean)) << function(self, index, noRead, justNavi)
    if not noRead then
        self:_ReadItem(self.m_curItemIndex)
    end

    local cell = self.m_getItemCell(self.m_curItemIndex)
    if cell then
        cell:SetSelected(false)
    end

    local isSame = self.m_curItemIndex == index

    self.m_curItemIndex = index
    if index > 0 then
        cell = self.m_getItemCell(self.m_curItemIndex)
        if cell then
            cell:SetSelected(true and not DeviceInfo.usingController)
            if DeviceInfo.usingController then
                InputManagerInst.controllerNaviManager:SetTarget(cell.view.button)
            end
        end
        if self.m_inDestroyMode then
            self:_ClickItemInDestroyMode(index, justNavi)
        end
    end

    self:_RefreshItemInfo(isSame)

    if index <= 0 then
        return
    end

    if not noRead then
        self:_ReadItem(index)
    end

    
    local info = self.m_curShowItemList[index]
    local id = info.id
    if Tables.itemTable:TryGetValue(id) and Tables.itemTable[id].valuableDepotRedDot then
        RedDotUtils.setNewObtainedImportantValuableDepotItem(id, false)
    end
end




ValuableDepotCtrl._AutoFillDestroyList = HL.Method(HL.Number) << function(self, tabIndex)
    self.m_destroyInfo[tabIndex] = {}
    self.m_destroyCount = 0

    local curFilterConfigs = self.m_curDestroyFilterConfigs
    if not curFilterConfigs or not next(curFilterConfigs) then
        return
    end

    local showItemList = self.m_curShowItemList
    local inventory = GameInstance.player.inventory
    local scope = Utils.getCurrentScope()
    local isLack = false
    for itemIndex, itemInfo in pairs(showItemList) do
        if self.m_destroyCount >= UIConst.DEPOT_DESTROY_MAX_COUNT then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_DEPOT_DES_AUTO_FILL_REACH_MAX)
            if isLack then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_DEPOT_DES_AUTO_FILL_HAS_LACK)
            end
            return
        end
        if FilterUtils.checkIfPassFilter(itemInfo, curFilterConfigs) then
            if not inventory:CanDestroyItem(scope, itemInfo.id) or inventory:IsEquipped(scope, itemInfo.id, itemInfo.instId) or inventory:IsItemLocked(scope, itemInfo.id, itemInfo.instId) then
                isLack = true
            else
                self:_MarkItemDestroy(itemIndex)
            end
        end
    end
    if isLack then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_DEPOT_DES_AUTO_FILL_HAS_LACK)
    end
end




ValuableDepotCtrl._GetAutoFillDestroyResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if not tags or not next(tags) then
        return
    end
    local count = 0
    for itemIndex, itemInfo in pairs(self.m_curShowItemList) do
        
        
        
        if FilterUtils.checkIfPassFilter(itemInfo, tags) then
            count = count + 1
        end
    end
    return count
end




ValuableDepotCtrl._RefreshItemInfo = HL.Method(HL.Boolean) << function(self, noAnimation)
    local node = self.view.itemInfoNode
    if self.m_curItemIndex < 0 then
        if noAnimation then
            node.animation:SampleToOutAnimationEnd()
            node.content.gameObject:SetActive(false)
            node.emptyNode.gameObject:SetActive(true)
        else
            node.animation:PlayOutAnimation(function()
                node.content.gameObject:SetActive(false)
                node.emptyNode.gameObject:SetActive(true)
            end)
        end
        return
    elseif self.m_curItemIndex == 0 then
        
        node.animation:SampleToOutAnimationEnd()
        node.content.gameObject:SetActive(false)
        node.emptyNode.gameObject:SetActive(true)
        return
    end
    node.content.gameObject:SetActive(true)
    node.emptyNode.gameObject:SetActive(false)
    if not noAnimation then
        node.animation:SampleToOutAnimationEnd()
        node.animation:PlayInAnimation()
    end
    local info = self.m_curShowItemList[self.m_curItemIndex]
    UIUtils.displayItemBasicInfos(node, self.loader, info.id, info.instId)
    node.itemDescNode:InitItemDescNode(info.id)

    self.view.itemInfoNode.wikiBtn.gameObject:SetActive(WikiUtils.canShowWikiEntry(info.id))

    local depotConfig = ItemType2DepotConfig[self.m_tabsInfo[self.m_curTabIndex].type]
    node.stateCtrl:SetState(depotConfig.infoStateName)
    if depotConfig.extraDisplayInfoFuncName then
        UIUtils[depotConfig.extraDisplayInfoFuncName](node, self.loader, info.id, info.instId)
    end

    local canJump, jumpFunction = self:_CheckIfCanJump(info.id, info.data.type, info.instId or 0)
    self.view.itemInfoNode.jumpBtn.gameObject:SetActive(canJump)
    self.view.itemInfoNode.jumpBtn.onClick:RemoveAllListeners()
    self.view.itemInfoNode.jumpBtn.onClick:AddListener(function()
        jumpFunction(self, info.id, info.instId or 0)
    end)
    node.itemObtainWays:InitItemObtainWays(info.id, info.instId)
    local isLockToggleVisible = self.view.itemInfoNode.lockToggle:InitLockToggle(info.id, info.instId or 0)
    local isTrashToggleVisible = self.view.itemInfoNode.trashToggle:InitTrashToggle(info.id, info.instId or 0)
    local isItemFlagNaviGroupVisible = isLockToggleVisible and isTrashToggleVisible
    InputManagerInst:ToggleBinding(self.m_lockToggleBindingId, isLockToggleVisible and not isItemFlagNaviGroupVisible)
    self.view.itemInfoNode.itemFlagNaviGroup.enabled = isItemFlagNaviGroupVisible
    self.view.itemInfoNode.itemFlagControllerFocusHintNode.gameObject:SetActive(isItemFlagNaviGroupVisible)
    self.view.itemInfoNode.lockToggleKeyHint.gameObject:SetActive(not isItemFlagNaviGroupVisible)

    if DeviceInfo.usingController and node.itemObtainWays.view.selectableNaviGroup.IsTopLayer then
        
        node.itemObtainWays.view.selectableNaviGroup:ManuallyStopFocus()
    else
        self.view.itemInfoNode.detailScroll:ScrollTo(Vector2(0, 0), false)
    end

    local canUse, useFunc = self:_CheckIfCanUse(info.id, info.instId or 0)
    self.view.itemInfoNode.useBtn.gameObject:SetActive(canUse)
    self.view.itemInfoNode.useBtn.onClick:RemoveAllListeners()
    self.view.itemInfoNode.useBtn.onClick:AddListener(function()
        useFunc(self, info.id)
    end)

    local showTips, tipText = self:_CheckIfShowTips(info.id)
    self.view.itemInfoNode.promptNode.gameObject:SetActive(showTips)
    if showTips then
        self.view.itemInfoNode.promptTxt:SetAndResolveTextStyle(tipText)
    end
    
    self.view.itemInfoNode.tipsLimitedTimeNode:InitTipsLimitedTimeNode(info.id, info.instId or 0)
    
    UIUtils.displayGiftItemTags(self.view.itemInfoNode.collectionTagNode, info.id)
    self.view.itemInfoNode.giftFeatureTagsNode:InitGiftFeatureTagsNode(info.id)
end




ValuableDepotCtrl._CheckIfTabUnlocked = HL.Method(HL.Userdata).Return(HL.Boolean) << function(self, itemType)
    local depotConfig = ItemType2DepotConfig[itemType]
    if depotConfig.isUnlocked ~= nil then
        return depotConfig.isUnlocked
    end

    if depotConfig.systemUnlockType then
        return Utils.isSystemUnlocked(depotConfig.systemUnlockType)
    end

    return false
end




ValuableDepotCtrl.OnValuableDepotChanged = HL.Method(HL.Table) << function(self, args)
    local depotType = unpack(args)
    if depotType ~= self.m_tabsInfo[self.m_curTabIndex].type then
        return
    end

    
    local currentSelectedItem = nil
    if self.m_curItemIndex > 0 and self.m_curShowItemList[self.m_curItemIndex] then
        currentSelectedItem = {
            id = self.m_curShowItemList[self.m_curItemIndex].id,
            instId = self.m_curShowItemList[self.m_curItemIndex].instId
        }
    end

    
    self:_OnClickTab(self.m_curTabIndex)

    if currentSelectedItem then
        
        local foundIndex = 0
        for i, item in ipairs(self.m_curShowItemList) do
            if item.id == currentSelectedItem.id and
                (not currentSelectedItem.instId or item.instId == currentSelectedItem.instId) then
                foundIndex = i
                break
            end
        end

        
        if foundIndex > 0 then
            self.m_curItemIndex = foundIndex
            self:_RefreshItemList(true)
        end
    end
end



ValuableDepotCtrl._ShowWiki = HL.Method() << function(self)
    local itemInfo = self.m_curShowItemList[self.m_curItemIndex]
    if itemInfo and itemInfo.id then
        Notify(MessageConst.SHOW_WIKI_ENTRY, { itemId = itemInfo.id })
    end
end






ValuableDepotCtrl.m_destroyCount = HL.Field(HL.Number) << 0


ValuableDepotCtrl.m_destroyInfo = HL.Field(HL.Table) 


ValuableDepotCtrl.m_getExpandItemCell = HL.Field(HL.Function)


ValuableDepotCtrl.m_destroyExpandItemList = HL.Field(HL.Table)


ValuableDepotCtrl.m_destroyCountItemRealId = HL.Field(HL.String) << ""




ValuableDepotCtrl._InitDestroyNode = HL.Method() << function(self)
    self.view.bottomNode.destroyBtn.onClick:AddListener(function()
        self:_ToggleDestroyMode(true, false)
    end)
    self.view.bottomNode.desEquipBtn.onClick:AddListener(function()
        self:_ToggleDestroyMode(true, false)
    end)

    local node = self.view.destroyNode
    self.view.animation:SampleToOutAnimationEnd()
    self.view.destroyNode.hintTxtNode.gameObject:SetActive(true)

    node.backBtn.onClick:AddListener(function()
        self:_ToggleDestroyMode(false, false)
    end)
    node.normalRightNode.confirmBtn.onClick:AddListener(function()
        self:_ConfirmDestroy()
    end)
    node.equipRightNode.confirmBtn.onClick:AddListener(function()
        self:_ConfirmDestroy()
    end)
    node.expandToggle.isOn = false
    node.expandToggle.onValueChanged:AddListener(function(isOn)
        self:_ToggleDestroySelectExpand(isOn)
    end)
    node.closeExpandBtn.onClick:AddListener(function()
        node.expandToggle.isOn = false
    end)

    self.m_getExpandItemCell = UIUtils.genCachedCellFunction(node.selectScrollList)
    node.selectScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateExpandCell(self.m_getExpandItemCell(obj), LuaIndex(csIndex))
    end)

    self.m_destroyInfo = {}
end





ValuableDepotCtrl._UpdateItemBlockMask = HL.Method(HL.Any, HL.Table) << function(self, cell, info)
    local showMask = false
    local inventory = GameInstance.player.inventory
    if self.m_inDestroyMode then
        if info.instId then
            showMask = not inventory:CanDestroyItem(Utils.getCurrentScope(), info.id, info.instId)
        else
            showMask = not inventory:CanDestroyItem(Utils.getCurrentScope(), info.id)
        end

        
        if info.data.type == GEnums.ItemType.WeaponGem then
            showMask = not inventory:CanDestroyItem(Utils.getCurrentScope(), info.id) or
                inventory:IsEquipped(Utils.getCurrentScope(), info.id, info.instId)
        end

        local desInfo = self.m_destroyInfo[self.m_curTabIndex][info.realId]
        cell.view.button.customBindingViewLabelText = desInfo and Language.LUA_VALUABLE_DEPOT_DESTROY_UNSELECT_KEY_HINT
            or Language.LUA_VALUABLE_DEPOT_DESTROY_SELECT_KEY_HINT
    else
        cell.view.button.customBindingViewLabelText = ''
    end
    cell.view.blockMask.gameObject:SetActiveIfNecessary(showMask)
end





ValuableDepotCtrl._ToggleDestroyMode = HL.Method(HL.Boolean, HL.Boolean) << function(self, active, noAnimation)
    local node = self.view.destroyNode
    local infos = self.m_tabsInfo[self.m_curTabIndex]
    local depotConfig = ItemType2DepotConfig[infos.type]

    self.view.topNode.tabsPCInputBindingGroup.enabled = not active
    if DeviceInfo.usingController then
        self.view.itemInfoNode.detailScrollInputBindingGroupMonoTarget.enabled = not active
    end

    if active then
        node.quickInputBtn.onClick:RemoveAllListeners()
        if depotConfig.destroyFilterOptions then
            node.quickInputBtn.gameObject:SetActive(true)
            node.quickInputBtn.onClick:AddListener(function()
                Notify(MessageConst.SHOW_COMMON_FILTER, {
                    tagGroups = depotConfig.destroyFilterOptions,
                    selectedTags = self.m_curDestroyFilterConfigs,
                    onConfirm = function(tags)
                        self.m_curDestroyFilterConfigs = tags
                        self:_AutoFillDestroyList(self.m_curTabIndex)
                        self:_RefreshItemList(true)
                        self:_UpdateDestroySelectTotalCount()
                    end,
                    getResultCount = function(tags)
                        return self:_GetAutoFillDestroyResultCount(tags)
                    end,
                })
            end)
        else
            node.quickInputBtn.gameObject:SetActive(false)
        end
        if depotConfig.isNormalDestroy then
            node.simpleStateController:SetState("Normal")
            node.rightNode = node.normalRightNode
        elseif depotConfig.isEquipDestroy then
            node.simpleStateController:SetState("Equip")
            node.rightNode = node.equipRightNode
        elseif depotConfig.isGemDestroy then
            node.simpleStateController:SetState("Gem")
            node.rightNode = node.equipRightNode
        end

        if noAnimation then
            self.view.animation:SampleToInAnimationEnd()
        else
            self.view.animation:PlayInAnimation()
        end
    else
        if noAnimation then
            self.view.animation:SampleToOutAnimationEnd()
        else
            self.view.animation:PlayOutAnimation()
        end
    end

    self.m_tabCells:Update(function(cell, index)
        cell.toggle.interactable = not active
        cell.canvasGroup.alpha = (not active or index == self.m_curTabIndex) and 1 or 0.3
    end)

    self.m_inDestroyMode = active

    if not active then
        local desInfos = self.m_destroyInfo[self.m_curTabIndex]
        self.m_destroyInfo = {}
        for realId, info in pairs(desInfos) do
            local k, v = self:_GetIndexFromRealId(realId)
            if k then
                self:_UpdateItemCellDestroySelectPart(k)
            end
        end
        if self.m_curItemIndex <= 0 then
            self:_OnClickItem(math.min(1, self.m_curShowCount))
        end
        self.view.walletBarPlaceholder.gameObject:SetActive(true)
        node.backBtn.gameObject:SetActive(true)
    else
        self.m_destroyInfo = {}
        for k = 1, #self.m_tabsInfo do
            self.m_destroyInfo[k] = {}
        end
        self.m_destroyCount = 0
        self:_UpdateDestroySelectTotalCount(true)
        if not DeviceInfo.usingController then
            self:_OnClickItem(-1)
        end
    end

    
    for k = 1, self.view.itemScrollList.count do
        local cell = self.m_getItemCell(k)
        if cell then
            local info = self.m_curShowItemList[k]
            self:_UpdateItemBlockMask(cell, info)
            cell.view.button:ChangeActionOnSetNaviTarget(
                active and ActionOnSetNaviTarget.PressConfirmTriggerOnClick or ActionOnSetNaviTarget.AutoTriggerOnClick)
        end
    end

    self:_ToggleDestroySelectExpand(false, true)

    self.view.itemScrollList:SetPaddingBottom(active and self.m_oriPaddingBottom + 150 or self.m_oriPaddingBottom)
end





ValuableDepotCtrl._ClickItemInDestroyMode = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, index, fromNavigation)
    local node = self.view.destroyNode
    local itemInfo = self.m_curShowItemList[index]
    local realId = itemInfo.realId

    if self.m_destroyInfo[self.m_curTabIndex][realId] then
        if not fromNavigation then
            
            self.m_destroyInfo[self.m_curTabIndex][realId] = nil
            self.m_destroyCount = self.m_destroyCount - 1

            self:_UpdateItemCellDestroySelectPart(index)
            self:_SetDestroyCountTarget("")
        else
            self:_SetDestroyCountTarget(realId)
        end
    else
        if not fromNavigation then
            local inventory = GameInstance.player.inventory
            local scope = Utils.getCurrentScope()
            if not inventory:CanDestroyItem(scope, itemInfo.id) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_ITEM_CANT_DESTROY_BECAUSE_TYPE)
                self:_SetDestroyCountTarget("")
            elseif inventory:IsEquipped(scope, itemInfo.id, itemInfo.instId) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_ITEM_CANT_DESTROY_BECAUSE_USING)
                self:_SetDestroyCountTarget("")
            elseif inventory:IsItemLocked(scope, itemInfo.id, itemInfo.instId) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_ITEM_CANT_DESTROY_BECAUSE_LOCK)
                self:_SetDestroyCountTarget("")
            elseif self.m_destroyCount >= UIConst.DEPOT_DESTROY_MAX_COUNT then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_ITEM_CANT_DESTROY_BECAUSE_SELECTED_MAX)
                self:_SetDestroyCountTarget("")
            else
                self.m_destroyInfo[self.m_curTabIndex][realId] = {
                    realId = itemInfo.realId,
                    id = itemInfo.id,
                    instId = itemInfo.instId,
                    count = itemInfo.count,
                    selectCount = itemInfo.count,
                }
                self.m_destroyCount = self.m_destroyCount + 1

                self:_UpdateItemCellDestroySelectPart(index)
                self:_UpdateItemCountInExpandList(realId)
                self:_SetDestroyCountTarget(realId)
            end
        else
            self:_SetDestroyCountTarget("")
        end
    end

    if not fromNavigation then
        self:_UpdateDestroySelectTotalCount()
    end
end




ValuableDepotCtrl._MarkItemDestroy = HL.Method(HL.Number) << function(self, index)
    local node = self.view.destroyNode
    local itemInfo = self.m_curShowItemList[index]
    local realId = itemInfo.realId

    local inventory = GameInstance.player.inventory
    local scope = Utils.getCurrentScope()
    if not inventory:CanDestroyItem(scope, itemInfo.id) then
        return
    end
    if inventory:IsEquipped(scope, itemInfo.id, itemInfo.instId) then
        return
    end
    if inventory:IsItemLocked(scope, itemInfo.id, itemInfo.instId) then
        return
    end
    if self.m_destroyCount >= UIConst.DEPOT_DESTROY_MAX_COUNT then
        return
    end

    self.m_destroyInfo[self.m_curTabIndex][realId] = {
        realId = itemInfo.realId,
        id = itemInfo.id,
        instId = itemInfo.instId,
        count = itemInfo.count,
        selectCount = itemInfo.count,
    }
    self.m_destroyCount = self.m_destroyCount + 1
end




ValuableDepotCtrl._SetDestroyCountTarget = HL.Method(HL.String) << function(self, realId)
    local desInfo
    local index = self:_GetIndexFromRealId(realId)
    if index then
        desInfo = self.m_destroyInfo[self.m_curTabIndex][realId]
    else
        for _, infos in ipairs(self.m_destroyInfo) do
            for k, v in pairs(infos) do
                if k == realId then
                    desInfo = v
                    break
                end
            end
            if desInfo then
                break
            end
        end
    end
    if not desInfo then
        
        realId = ""
    end

    local oldIsEmpty = string.isEmpty(self.m_destroyCountItemRealId)
    local newIsEmpty = string.isEmpty(realId)
    self.m_destroyCountItemRealId = realId
    local node = self.view.destroyNode
    if newIsEmpty then
        node.numberSelector.gameObject:SetActive(false)
        return
    end

    if desInfo.instId then
        node.numberSelector.gameObject:SetActive(false)
    else
        node.numberSelector.gameObject:SetActive(true)
        node.numberSelector:InitNumberSelector(desInfo.selectCount, 1, desInfo.count, function(newCount)
            self:_OnChangeItemDestroyCount(realId, newCount)
        end)
    end
end




ValuableDepotCtrl._GetIndexFromRealId = HL.Method(HL.String).Return(HL.Opt(HL.Number, HL.Table)) << function(self, realId)
    for k, v in ipairs(self.m_curShowItemList) do
        if v.realId == realId then
            return k, v
        end
    end
end






ValuableDepotCtrl._UpdateItemCellDestroySelectPart = HL.Method(HL.Opt(HL.Number, HL.Userdata, HL.Table)) << function(self, index, cell, desExpandInfo)
    if not cell then
        cell = self.m_getItemCell(index)
        if not cell then
            return
        end
    end

    local desInfo, itemInfo
    if index then
        itemInfo = self.m_curShowItemList[index]
        desInfo = self.m_inDestroyMode and self.m_destroyInfo[self.m_curTabIndex][itemInfo.realId]
    elseif desExpandInfo then
        desInfo = self.m_destroyInfo[desExpandInfo.tabIndex][desExpandInfo.realId]
    end

    if desInfo then
        if itemInfo then
            cell.view.count.text = string.format("<color=#%s>%s</color>/%s", UIConst.COUNT_RED_COLOR_STR, UIUtils.getNumString(desInfo.selectCount), UIUtils.getNumString(itemInfo.count))
        else
            
            cell.view.count.text = string.format(UIConst.COLOR_STRING_FORMAT, UIConst.COUNT_RED_COLOR_STR, UIUtils.getNumString(desInfo.selectCount))
        end
        if not desExpandInfo then
            InputManagerInst:SetBindingText(cell.view.button.hoverConfirmBindingId, Language.LUA_VALUABLE_DEPOT_DESTROY_UNSELECT_KEY_HINT)
        end
    else
        cell:UpdateCount(itemInfo.count)
        if not desExpandInfo then
            InputManagerInst:SetBindingText(cell.view.button.hoverConfirmBindingId, Language.LUA_VALUABLE_DEPOT_DESTROY_SELECT_KEY_HINT)
        end
    end

    if itemInfo then
        local depotConfig = ItemType2DepotConfig[self.m_tabsInfo[self.m_curTabIndex].type]
        local mark = (depotConfig.isEquipDestroy or depotConfig.isGemDestroy) and cell.view.multiSelectMark or cell.view.redMultiSelectMark
        if desInfo then
            mark.gameObject:SetActive(true)
        else
            mark.gameObject:SetActive(false)
        end
    end 
end





ValuableDepotCtrl._OnChangeItemDestroyCount = HL.Method(HL.String, HL.Number) << function(self, realId, newCount)
    for _, infos in ipairs(self.m_destroyInfo) do
        for k, v in pairs(infos) do
            if k == realId then
                v.selectCount = newCount
            end
        end
    end
    local index = self:_GetIndexFromRealId(realId)
    if index then
        self:_UpdateItemCellDestroySelectPart(index) 
    end
    self:_UpdateItemCountInExpandList(realId) 
end




ValuableDepotCtrl._UpdateItemCountInExpandList = HL.Method(HL.String) << function(self, realId)
    if not self.view.destroyNode.expandToggle.isOn then
        return
    end
    for k, v in ipairs(self.m_destroyExpandItemList) do
        if v.realId == realId then
            local expandCell = self.m_getExpandItemCell(k)
            if expandCell then
                self:_UpdateItemCellDestroySelectPart(nil, expandCell, v)
            end
            return
        end
    end
end




ValuableDepotCtrl._UpdateDestroySelectTotalCount = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local node = self.view.destroyNode
    node.selectCountTxt.text = string.format(Language.LUA_DEPOT_DESTROY_COUNT, self.m_destroyCount, UIConst.DEPOT_DESTROY_MAX_COUNT)
    local showBtn = self.m_destroyCount > 0
    local rightNode = node.rightNode
    if not rightNode.animationWrapper then
        rightNode.confirmBtn.gameObject:SetActive(showBtn)
        rightNode.disabledBtn.gameObject:SetActive(not showBtn)
    else
        rightNode.disabledBtn.gameObject:SetActive(not showBtn)
        if isInit then
            rightNode.previewNode.gameObject:SetActive(showBtn)
            rightNode.confirmBtn.gameObject:SetActive(showBtn)
        elseif showBtn ~= rightNode.previewNode.gameObject.activeSelf then
            
            rightNode.previewNode.gameObject:SetActive(true)
            rightNode.confirmBtn.gameObject:SetActive(true)
            if showBtn then
                rightNode.animationWrapper:PlayInAnimation(function()
                    rightNode.previewNode.gameObject:SetActive(showBtn)
                    rightNode.confirmBtn.gameObject:SetActive(showBtn)
                end)
            else
                rightNode.animationWrapper:PlayOutAnimation(function()
                    rightNode.previewNode.gameObject:SetActive(showBtn)
                    rightNode.confirmBtn.gameObject:SetActive(showBtn)
                end)
            end
        end
        if showBtn then
            self.m_getPreviewItemCell = self.m_getPreviewItemCell or UIUtils.genCachedCellFunction(rightNode.previewItemScrollList)
            local depotConfig = ItemType2DepotConfig[self.m_tabsInfo[self.m_curTabIndex].type]
            local previewItems
            if depotConfig.isEquipDestroy then
                previewItems = self:_GetDesEquipReturnItems(self.m_curTabIndex)
            elseif depotConfig.isGemDestroy then
                previewItems = self:_GetDesGemReturnItems(self.m_curTabIndex)
            end
            rightNode.previewItemScrollList.onUpdateCell:RemoveAllListeners()
            rightNode.previewItemScrollList.onUpdateCell:AddListener(function(obj, csIndex)
                local cell = self.m_getPreviewItemCell(obj)
                cell:InitItem(previewItems[LuaIndex(csIndex)], true)
                cell:SetExtraInfo({
                    isSideTips = DeviceInfo.usingController,
                })
                if DeviceInfo.usingController then
                    cell:SetEnableHoverTips(false)
                end
            end)
            local previewItemCount = previewItems and #previewItems or 0
            rightNode.previewItemScrollList:UpdateCount(previewItemCount)
        end
    end
end




ValuableDepotCtrl._GetDesEquipReturnItems = HL.Method(HL.Number).Return(HL.Table) << function(self, tabIndex)
    local itemMap = {}
    local ratio = Tables.equipTechConst.equipRecycleRatio
    local destroyItemInfos = self.m_destroyInfo[tabIndex]
    for _, info in pairs(destroyItemInfos) do
        local formulaId = Tables.equipFormulaReverseTable[info.id]
        local formulaData = Tables.equipFormulaTable[formulaId]
        
        if formulaData.costItemId.Count > 0 then
            local itemId = formulaData.costItemId[0]
            local itemCount = formulaData.costItemNum[0]
            if itemMap[itemId] then
                itemMap[itemId] = itemMap[itemId] + itemCount
            else
                itemMap[itemId] = itemCount
            end
        end
    end
    local items = {}
    for itemId, count in pairs(itemMap) do
        count = count * ratio
        if count > 0 then
            table.insert(items, { id = itemId, count = count })
        end
    end
    return items
end




ValuableDepotCtrl._GetDesGemReturnItems = HL.Method(HL.Number).Return(HL.Table) << function(self, tabIndex)
    local itemMap = {}
    local destroyItemInfos = self.m_destroyInfo[tabIndex]
    for _, info in pairs(destroyItemInfos) do
        local _, itemData = Tables.itemTable:TryGetValue(info.id)
        local gemInst = CharInfoUtils.getGemByInstId(info.instId)
        if itemData and gemInst and not string.isEmpty(gemInst.domainId) then
            local _, gemDismantleData = Tables.gemDismantleTable:TryGetValue(itemData.rarity)
            if gemDismantleData then
                local _, gemDismantleDomainData = gemDismantleData.list:TryGetValue(gemInst.domainId)
                if gemDismantleDomainData then
                    if itemMap[gemDismantleDomainData.itemId] then
                        itemMap[gemDismantleDomainData.itemId] = itemMap[gemDismantleDomainData.itemId] + gemDismantleDomainData.itemNum
                    else
                        itemMap[gemDismantleDomainData.itemId] = gemDismantleDomainData.itemNum
                    end
                    if itemMap[gemDismantleDomainData.goldId] then
                        itemMap[gemDismantleDomainData.goldId] = itemMap[gemDismantleDomainData.goldId] + gemDismantleDomainData.goldNum
                    else
                        itemMap[gemDismantleDomainData.goldId] = gemDismantleDomainData.goldNum
                    end
                end
            end
        end
    end
    local items = {}
    for itemId, count in pairs(itemMap) do
        if count > 0 then
            table.insert(items, { id = itemId, count = count })
        end
    end
    return items
end





ValuableDepotCtrl._ToggleDestroySelectExpand = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, active, fastMode)
    self.view.walletBarPlaceholder.gameObject:SetActive(not active)

    local node = self.view.destroyNode
    local info = self.m_tabsInfo[self.m_curTabIndex]
    local depotConfig = ItemType2DepotConfig[info.type]

    node.backBtn.gameObject:SetActive(not active)
    node.hintTxtNode.gameObject:SetActive(not active)
    node.quickInputBtn.gameObject:SetActive(depotConfig.destroyFilterOptions and not active)

    if active then
        node.selectInfoNode.gameObject:SetActive(true)
    elseif fastMode then
        node.selectInfoNode.gameObject:SetActive(false)
    else
        node.selectInfoNode:PlayOutAnimation(function()
            node.selectInfoNode.gameObject:SetActive(false)
        end)
    end

    if DeviceInfo.usingController then
        node.expandToggle.enabled = not active
        node.equipRightNode.focusKeyHint:SetActionId(active and "" or "valuable_depot_focus_item")
    end

    if not active and self.m_inDestroyMode then
        self.m_destroyExpandItemList = {}
        self:_SetDestroyCountTarget(info and info.realId or "")
        return
    end

    self:_RefreshDestroySelectExpandList()
    if active then
        local cell = self.m_getExpandItemCell(1)
        if cell then
            InputManagerInst.controllerNaviManager:SetTarget(cell.view.button)
            self:_SetDestroyCountTarget(self.m_destroyExpandItemList[1].realId)
        else
            
            InputManagerInst.controllerNaviManager:SetTarget(node.itemCell.view.button)
        end
    end
end




ValuableDepotCtrl._RefreshDestroySelectExpandList = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAnim)
    local node = self.view.destroyNode
    self.m_destroyExpandItemList = {}
    for tabIndex, infos in ipairs(self.m_destroyInfo) do
        local needFindIndex = tabIndex == self.m_curTabIndex
        for realId, _ in pairs(infos) do
            if needFindIndex then
                local k, v = self:_GetIndexFromRealId(realId)
                if k then
                    table.insert(self.m_destroyExpandItemList, {
                        tabIndex = tabIndex,
                        index = k,
                        realId = realId,
                    })
                end
            else
                table.insert(self.m_destroyExpandItemList, {
                    tabIndex = tabIndex,
                    realId = realId,
                })
            end
        end
    end
    table.sort(self.m_destroyExpandItemList, Utils.genSortFunction({ "index" }, true))
    node.selectScrollList:UpdateCount(#self.m_destroyExpandItemList, false, false, false, skipAnim == true)
    self:_SetDestroyCountTarget("")
end





ValuableDepotCtrl._OnUpdateExpandCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local info = self.m_destroyExpandItemList[index]
    local realId = info.realId
    local desInfo = self.m_destroyInfo[info.tabIndex][info.realId]
    cell:InitItem(desInfo, function()
        self:_SetDestroyCountTarget(realId)
        if not DeviceInfo.usingController then
            cell:ShowTips({
                safeArea = self.view.destroyNode.numberSelector.rectTransform,
                padding = { bottom = self.view.destroyNode.bottomNode.transform.rect.size.y + 20 },
                isSideTips = true,
            }, function()
                if self.m_destroyCountItemRealId == realId then
                    self:_SetDestroyCountTarget("")
                end
            end)
        end
    end)

    if DeviceInfo.usingController then
        cell:AddHoverBinding("inv_depot_cancel_des_select", function()
            self:_OnClickExpandItemDelBtn(index)
        end)
    end

    cell.view.deleteBtn.onClick:RemoveAllListeners()
    cell.view.deleteBtn.onClick:AddListener(function()
        self:_OnClickExpandItemDelBtn(index)
    end)
    self:_UpdateItemCellDestroySelectPart(nil, cell, info)
    cell.view.button.clickHintTextId = "virtual_mouse_hint_item_tips"
    cell.view.deleteBtn.gameObject:SetActive(true)
end




ValuableDepotCtrl._OnClickExpandItemDelBtn = HL.Method(HL.Number) << function(self, index)
    local info = self.m_destroyExpandItemList[index]
    if info.index then
        self:_ClickItemInDestroyMode(info.index)
    else
        self.m_destroyInfo[info.tabIndex][info.realId] = nil
        self.m_destroyCount = self.m_destroyCount - 1
        self:_UpdateDestroySelectTotalCount()
        self:_SetDestroyCountTarget("")
    end
    self:_RefreshDestroySelectExpandList(true)
    if info.index == self.m_curItemIndex then
        self:_OnClickItem(-1)
    end
    if DeviceInfo.usingController then
        local curCount = #self.m_destroyExpandItemList
        if curCount > 0 then
            local newTargetIndex = index
            if newTargetIndex > curCount then
                newTargetIndex = index - 1
                if newTargetIndex > 0 then
                    self.view.destroyNode.selectScrollList:ScrollToIndex(newTargetIndex, true)
                    local cell = self.m_getExpandItemCell(newTargetIndex)
                    if cell then
                        InputManagerInst.controllerNaviManager:SetTarget(cell.view.button)
                    end
                end
            end
        end
    end
end




ValuableDepotCtrl.OnEquipRecycle = HL.Method(HL.Table) << function(self, arg)
    Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_RECYCLE_SUCC)
end




ValuableDepotCtrl.OnGemDismantle = HL.Method(HL.Table) << function(self, args)
    local refundItems, refundMoney = unpack(args)
    local items = {}
    for _, itemInfo in cs_pairs(refundItems) do
        table.insert(items, {
            id = itemInfo.Id,
            count = itemInfo.Count,
        })
    end
    for _, itemInfo in cs_pairs(refundMoney) do
        table.insert(items, {
            id = itemInfo.Id,
            count = itemInfo.Count,
        })
    end

    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        icon = "icon_recycle_rewards",
        title = Language.LUA_GEM_DISMANTLE_RESULT_TITLE,
        items = items,
    })
end



ValuableDepotCtrl._ConfirmDestroy = HL.Method() << function(self)
    local items = {}
    local itemDelInfo = {}
    local instDelInfo = {}
    for tabIndex, infos in pairs(self.m_destroyInfo) do
        itemDelInfo[tabIndex] = {}
        instDelInfo[tabIndex] = {}
        for _, info in pairs(infos) do
            if info.instId and info.instId > 0 then
                table.insert(instDelInfo[tabIndex], info.instId)
            else
                itemDelInfo[tabIndex][info.id] = info.selectCount
            end
            table.insert(items, {
                id = info.id,
                count = info.selectCount,
                instId = info.instId,
            })
        end
    end
    table.sort(items, Utils.genSortFunction({ "id" }, true))

    local depotConfig = ItemType2DepotConfig[self.m_tabsInfo[self.m_curTabIndex].type]
    if depotConfig.isEquipDestroy then
        UIManager:Open(PanelId.DesEquipPopUp, {
            items = items,
            returnItems = self:_GetDesEquipReturnItems(self.m_curTabIndex),
            onConfirm = function()
                GameInstance.player.inventory:RecycleEquip(instDelInfo[self.m_curTabIndex])
                self:_ToggleDestroyMode(false, false)
            end,
        })
    elseif depotConfig.isGemDestroy then
        UIManager:Open(PanelId.DesEquipPopUp, {
            items = items,
            returnItems = self:_GetDesGemReturnItems(self.m_curTabIndex),
            onConfirm = function()
                GameInstance.player.inventory:RecycleGem(instDelInfo[self.m_curTabIndex])
                self:_ToggleDestroyMode(false, false)
            end,
        })
    else
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_DESTROY_ITEM_CONFIRM_TEXT,
            warningContent = Language.LUA_DESTROY_ITEM_CONFIRM_WARNING_TEXT,
            items = items,
            onConfirm = function()
                for tabIndex, tabInfo in ipairs(self.m_tabsInfo) do
                    local itemInfos = itemDelInfo[tabIndex]
                    local instIds = instDelInfo[tabIndex]
                    if next(itemInfos) or next(instIds) then
                        GameInstance.player.inventory:DestroyInDepot(Utils.getCurrentScope(), tabInfo.type, itemInfos, instIds)
                    end
                end
                self:_ToggleDestroyMode(false, false)
            end,
        })
    end
end




ValuableDepotCtrl.OnItemLockedStateChanged = HL.Method(HL.Table) << function(self, args)
    if not self.m_inDestroyMode then
        return
    end
    local id, instId, isLocked = unpack(args)
    local itemInfo = self.m_curShowItemList[self.m_curItemIndex]
    if itemInfo and itemInfo.id == id and itemInfo.instId == instId then
        local cell = self.m_getItemCell(self.m_curItemIndex)
        if cell then
            self:_UpdateItemBlockMask(cell, itemInfo)
        end
        self:_ClickItemInDestroyMode(self.m_curItemIndex)
    end
end









ValuableDepotCtrl._JumpToWeaponGem = HL.Method(HL.String, HL.Number) << function(self, gemTemplateId, gemInstId)
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst then
        return
    end

    local attachedWeaponInstId = gemInst.weaponInstId
    if not attachedWeaponInstId then
        return
    end

    local weaponInst = CharInfoUtils.getWeaponByInstId(attachedWeaponInstId)
    if not weaponInst then
        return
    end

    local fadeTimeBoth = UIConst.CHAR_INFO_TRANSITION_BLACK_SCREEN_DURATION
    local dynamicFadeData = UIUtils.genDynamicBlackScreenMaskData("ValuableDepot->WeaponInfo", fadeTimeBoth, fadeTimeBoth, function()
        self.view.itemScrollList:UpdateCount(0)
        CharInfoUtils.openWeaponInfoBestWay({
            weaponTemplateId = weaponInst.templateId,
            weaponInstId = weaponInst.instId,
            pageType = UIConst.WEAPON_EXHIBIT_PAGE_TYPE.GEM
        })
    end)
    GameAction.ShowBlackScreen(dynamicFadeData)
end





ValuableDepotCtrl._JumpToWeapon = HL.Method(HL.String, HL.Number) << function(self, weaponTemplateId, weaponInstId)
    local fadeTimeBoth = UIConst.CHAR_INFO_TRANSITION_BLACK_SCREEN_DURATION
    local dynamicFadeData = UIUtils.genDynamicBlackScreenMaskData("ValuableDepot->WeaponInfo", fadeTimeBoth, fadeTimeBoth, function()

        CharInfoUtils.openWeaponInfoBestWay({
            weaponTemplateId = weaponTemplateId,
            weaponInstId = weaponInstId,
        })

        self.view.itemScrollList:UpdateCount(0)

    end)
    dynamicFadeData.notHideCursor = true
    GameAction.ShowBlackScreen(dynamicFadeData)
end






ValuableDepotCtrl._CheckIfCanJump = HL.Method(HL.String, HL.Userdata, HL.Opt(HL.Number)).Return(HL.Boolean, HL.Opt(HL.Function)) << function(self, itemId, itemType, instId)
    if not instId or instId <= 0 then
        return false
    end

    local isWeapon = itemType == GEnums.ItemType.Weapon
    if isWeapon then
        return true, self._JumpToWeapon
    end

    local isWeaponGem = itemType == GEnums.ItemType.WeaponGem
    if not isWeaponGem then
        return false
    end

    local gemInst = CharInfoUtils.getGemByInstId(instId)
    if not gemInst then
        return false
    end

    local weaponInstId = gemInst.weaponInstId
    if not weaponInstId or weaponInstId <= 0 then
        return false
    end

    return true, self._JumpToWeaponGem
end





ValuableDepotCtrl._CheckIfCanUse = HL.Method(HL.String, HL.Int).Return(HL.Boolean, HL.Opt(HL.Function)) << function(self, itemId, instId)
    local _, itemData = Tables.itemTable:TryGetValue(itemId)
    local itemType = itemData.type
    
    if itemType == GEnums.ItemType.APItem or itemType == GEnums.ItemType.APLimitItem then
        return true, function()
            UIManager:Open(PanelId.StaminaPopUp, { itemId = itemId, instId = instId })
        end
    end
    
    if itemType == GEnums.ItemType.APFeedIn then
        return true, function()
            UIManager:Open(PanelId.StaminaPotion, itemId)
        end
    end
    
    if itemType == GEnums.ItemType.ItemCase then
        local useFunc = function()
            local isBPChest = false
            local _, chestData = Tables.usableItemChestTable:TryGetValue(itemId)
            if chestData and chestData.type == GEnums.ItemCaseType.SelfSelectedBP then
                isBPChest = true
            end
            if isBPChest then
                UIManager:Open(PanelId.BattlePassWeaponCase, { itemId = itemId })
            else
                PhaseManager:OpenPhase(PhaseId.UsableItemChest, { itemId = itemId })
            end
        end
        return true, useFunc
    end
    
    if itemType == GEnums.ItemType.MapDetector then
        local state = false
        local useFunc = function()
            UIManager:Open(PanelId.MapDetectPopUp, itemId)
        end
        if not GameWorld.mapRegionManager:IsUnlockAllMistMapInLevel(GameWorld.worldInfo.curLevelId) then
            state = false
        else
            state = true
        end
        return state, useFunc
    end
    
    if itemType == GEnums.ItemType.GemLockedTermBox then
        local useFunc = function()
            UIManager:Open(PanelId.GemCustomizationBox, itemId)
        end
        return true, useFunc
    end
    
    if itemType == GEnums.ItemType.MonthlycardItem then
        local useFunc = function()
            CashShopUtils.TryUseMonthlyItem(itemId, instId)
        end
        return true, useFunc
    end
    
    if itemType == GEnums.ItemType.BPTicketLTItem then
        local canUse, cantReason = BattlePassUtils.CheckBattlePassItemCanUse(itemId)
        if not canUse then
            return false
        end
        local useFunc = function()
            BattlePassUtils.TryUseBattlePassItem(itemId, instId)
        end
        return true, useFunc
    end
    
    return false
end




ValuableDepotCtrl._CheckIfShowTips = HL.Method(HL.String).Return(HL.Boolean, HL.Opt(HL.String)) << function(self, itemId)
    local _, itemData = Tables.itemTable:TryGetValue(itemId)
    if itemData.type == GEnums.ItemType.MapDetector then
        local state = false
        local text = ""
        if not GameWorld.mapRegionManager:IsUnlockAllMistMapInLevel(GameWorld.worldInfo.curLevelId) then
            state = true
            text = Language.LUA_MAP_USE_DETECT_MIST_LOCKED_TOAST
        end
        return state, text
    end

    if itemData.type == GEnums.ItemType.BPTicketLTItem then
        local canUse, cantReason = BattlePassUtils.CheckBattlePassItemCanUse(itemId)
        if not canUse then
            return true, cantReason
        end
    end

    return false
end




ValuableDepotCtrl._UpdateDecoIcons = HL.Method(HL.Opt(HL.String)) << function(self, id)
    if not id or string.isEmpty(id) then
        return
    end

    local data = Tables.itemTable:GetValue(id)
    self.view.icon:LoadSprite(self.view.config.USE_BIG_ICON and UIConst.UI_SPRITE_ITEM_BIG or UIConst.UI_SPRITE_ITEM, data.iconId)
end








ValuableDepotCtrl._ReadItem = HL.Method(HL.Number) << function(self, index)
    if index <= 0 then
        return
    end
    local info = self.m_curShowItemList[index]
    if info.instId then
        GameInstance.player.inventory:ReadNewItem(info.id, info.instId)
    else
        GameInstance.player.inventory:ReadNewItem(info.id)
    end
end


ValuableDepotCtrl.m_readItemIds = HL.Field(HL.Table)


ValuableDepotCtrl.m_readItemInstIds = HL.Field(HL.Table)



ValuableDepotCtrl._ReadCurShowingItems = HL.Method() << function(self)
    local tabInfo = self.m_tabsInfo[self.m_curTabIndex]
    if not tabInfo then
        return
    end

    if not next(self.m_readItemIds) and not next(self.m_readItemInstIds) then
        return
    end

    local itemIds = {}
    for k, _ in pairs(self.m_readItemIds) do
        table.insert(itemIds, k)
    end
    self.m_readItemIds = {}

    local instIds = {}
    for k, _ in pairs(self.m_readItemInstIds) do
        table.insert(instIds, k)
    end
    self.m_readItemInstIds = {}

    GameInstance.player.inventory:ReadNewItems(itemIds, tabInfo.type, instIds)
end




ValuableDepotCtrl.CheckLTItemExpire = HL.Method() << function(self)
    if inventorySystem.waitConfirmExpireLTItemDict.Count <= 0 then
        return
    end
    
    local recordIds = {}
    for recordId, _ in cs_pairs(inventorySystem.waitConfirmExpireLTItemDict) do
        table.insert(recordIds, recordId)
    end
    inventorySystem:SendConfirmLTItemsExpireReq(recordIds)
end




ValuableDepotCtrl.OnLTItemExpire = HL.Method(HL.Any) << function(self, arg)
    local recordId = unpack(arg)
    inventorySystem:SendConfirmLTItemsExpireReq({ recordId })
end




ValuableDepotCtrl.OnUseItem = HL.Method(HL.Any) << function(self, arg)
    local itemId, result = unpack(arg)
    local _, itemData = Tables.itemTable:TryGetValue(itemId)
    local itemType = itemData.type
    if itemType == GEnums.ItemType.MonthlycardItem then
        Notify(MessageConst.SHOW_CASH_SHOP_TOAST,
            { text = Language.LUA_CASHSHOP_MONTHLYCARD_ON_USE_ITEM_SUCC})
    elseif itemType == GEnums.ItemType.BPTicketLTItem then
        if UIManager:IsOpen(PanelId.RewardsPopUpForSystem) then
            self.m_bpTicketItemId = itemId
            return
        end
        self:TryPopupBp(itemId)
    end
end




ValuableDepotCtrl.m_bpTicketItemId = HL.Field(HL.String) << ''




ValuableDepotCtrl.OnBPTicketReward = HL.Method(HL.Any) << function(self, args)
    local bundles = unpack(args)
    local rewardPanelArg = {
        items = bundles,
        onComplete = function()
            local bpTicketItemId = self.m_bpTicketItemId
            self.m_bpTicketItemId = ''
            if not string.isEmpty(bpTicketItemId) then
                self:TryPopupBp(bpTicketItemId)
            end
        end,
    }
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, rewardPanelArg)
end




ValuableDepotCtrl.TryPopupBp = HL.Method(HL.String) << function(self, itemId)
    local hasTrack, trackType = BattlePassUtils.GetBattlePassTicketTrackType(itemId)
    if not hasTrack or trackType == nil then
        return
    end
    BattlePassUtils.ShowTrackReward(trackType, false, nil, function()
        local phaseArg = {
            panelId = 'BattlePassPlan',
        }
        if hasTrack then
            phaseArg.panelArgs = {
                showTrackUnlockType = trackType,
            }
        end
        PhaseManager:GoToPhase(PhaseId.BattlePass, phaseArg)
    end)
end





ValuableDepotCtrl.ShowLTItemExpirePopup = HL.Method(HL.Any) << function(self, arg)
    local itemInfos = {}
    local itemInfoMap = {}  
    local recordIds = unpack(arg)
    local idCount = recordIds.Count - 1
    for i = 0, idCount do
        local recordId = recordIds[i]
        local hasValue, itemBundleList = inventorySystem.waitConfirmExpireLTItemDict:TryGetValue(recordId)
        if hasValue then
            local itemListMaxIndex = itemBundleList.Count - 1
            for i = 0, itemListMaxIndex do
                local itemBundle = itemBundleList[i]
                local itemId = itemBundle.Id
                local itemCount = itemBundle.Count
                local itemInfo = itemInfoMap[itemId]
                if itemInfo == nil then
                    local itemCfg = Tables.itemTable[itemId]
                    itemInfo = {
                        id = itemId,
                        count = itemCount,
                        
                        sortId1 = itemCfg.sortId1,
                        sortId2 = itemCfg.sortId2,
                    }
                    itemInfoMap[itemId] = itemInfo
                    table.insert(itemInfos, itemInfo)
                else
                    itemInfo.count = itemInfo.count + itemCount
                end
            end
        else
            logger.error("过期物品Record数据丢失！RecordId：" .. recordId)
        end
    end
    table.sort(itemInfos, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_LIMIT_ITEM_EXPIRE_POPUP_TITLE,
        items = itemInfos,
        hideCancel = true,
    })
end







ValuableDepotCtrl.m_lockToggleBindingId = HL.Field(HL.Number) << -1



ValuableDepotCtrl._InitController = HL.Method() << function(self)
    self.view.walletBarPlaceholder:InitWalletBarPlaceholder(JsonConst.VALUABLE_DEPOT_MONEY_IDS)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.m_lockToggleBindingId = self:BindInputPlayerAction("item_lock_toggle", function()
        self.view.itemInfoNode.lockToggle.view.toggle.isOn = not self.view.itemInfoNode.lockToggle.view.toggle.isOn
    end)

    self.view.itemInfoNode.itemFlagNaviGroup.onIsTopLayerChanged:AddListener(function(isTopLayer)
        self.view.itemInfoNode.itemFlagControllerFocusHintNode.gameObject:SetActive(not isTopLayer)
    end)
    self.view.destroyNode.equipRightNode.previewItemNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    self.view.itemListNaviGroup.onIsTopLayerChanged:AddListener(function(isTopLayer)
        local selectedCell = self.m_getItemCell(self.view.itemScrollList:Get(CSIndex(self.m_curItemIndex)))
        if selectedCell then
            selectedCell:SetSelected(not isTopLayer)
        end
    end)
    UIUtils.bindHyperlinkPopup(self, "ValuableDepot", self.view.inputGroup.groupId)
end








ValuableDepotCtrl.OnItemCountChanged = HL.StaticMethod(HL.Table) << function(args)
    
    if args == nil then
        return
    end
    local itemDict = unpack(args)
    if itemDict.Count == 0 then
        return
    end
    for id, diffCount in cs_pairs(itemDict) do
        if Tables.itemTable:TryGetValue(id) and Tables.itemTable[id].valuableDepotRedDot and diffCount > 0 then
            RedDotUtils.setNewObtainedImportantValuableDepotItem(id, true)
        end
    end
end
HL.Commit(ValuableDepotCtrl)
