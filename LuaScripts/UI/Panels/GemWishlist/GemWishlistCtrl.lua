local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GemWishlist
local PHASE_ID = PhaseId.GemWishlist
GemWishlistCtrl = HL.Class('GemWishlistCtrl', uiCtrl.UICtrl)


local WeaponState = {
    Init = 1, 
    Max = 2,  
    Gem = 3,  
}

local SAVE_CLICK_CD = 1































GemWishlistCtrl.m_allWeaponList = HL.Field(HL.Table)



GemWishlistCtrl.m_allForesightWeaponList = HL.Field(HL.Table)



GemWishlistCtrl.m_displayWeaponList = HL.Field(HL.Table)



GemWishlistCtrl.m_displayForesightWeaponList = HL.Field(HL.Table)



GemWishlistCtrl.m_weaponInfoMap = HL.Field(HL.Table)


GemWishlistCtrl.m_selectedWeaponId = HL.Field(HL.String) << ""


GemWishlistCtrl.m_checkedWeapons = HL.Field(HL.Table)


GemWishlistCtrl.m_savedCheckedWeapons = HL.Field(HL.Table)


GemWishlistCtrl.m_filterConfigs = HL.Field(HL.Table)


GemWishlistCtrl.m_filterOptions = HL.Field(HL.Table)


GemWishlistCtrl.m_maxCheckCount = HL.Field(HL.Number) << 5


GemWishlistCtrl.m_haveInitNaviTarget = HL.Field(HL.Boolean) << false


GemWishlistCtrl.m_toggleCheckBindingId = HL.Field(HL.Number) << -1


GemWishlistCtrl.m_curWeaponState = HL.Field(HL.Number) << WeaponState.Init


GemWishlistCtrl.m_nextSaveClickTime = HL.Field(HL.Number) << 0


GemWishlistCtrl.m_getCellFunc = HL.Field(HL.Function)


GemWishlistCtrl.m_getTitleCellFunc = HL.Field(HL.Function)





GemWishlistCtrl.s_messages = HL.StaticField(HL.Table) << {
}


GemWishlistCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData()

    
    local recoverState = arg and arg.displayWeaponIds and arg or nil
    if recoverState then
        self.m_checkedWeapons = recoverState.checkedWeapons or {}
        self.m_filterConfigs = recoverState.filterConfigs or {}
        self.m_selectedWeaponId = recoverState.selectedWeaponId or ""
        local displayList = {}
        for _, id in ipairs(recoverState.displayWeaponIds) do
            local info = self.m_weaponInfoMap[id]
            if info then
                table.insert(displayList, info)
            end
        end
        if #displayList > 0 then
            self.m_displayWeaponList = displayList
        end
        local foresightDisplayList = {}
        for _, id in ipairs(recoverState.foresightDisplayWeaponIds or {}) do
            local info = self:GetInfoByWeaponId(id)
            if info and info.isForesight then
                table.insert(foresightDisplayList, info)
            end
        end
        if #foresightDisplayList > 0 then
            self.m_displayForesightWeaponList = foresightDisplayList
        end
        local ws = recoverState.weaponState
        if type(ws) == "number" and ws >= WeaponState.Init and ws <= WeaponState.Gem then
            self.m_curWeaponState = ws
        end
    end

    self:_BindUI()

    if recoverState then
        self:_SyncSelectionAfterListChange()
    else
        self:_RefreshUI(true)
    end
end




GemWishlistCtrl._BindUI = HL.Method() << function(self)
    self.view.commonTopTitleNode.btnClose.onClick:RemoveAllListeners()
    self.view.commonTopTitleNode.btnClose.onClick:AddListener(function()
        self:_OnCloseBtnClick()
    end)

    
    self.view.commonTopTitleNode.commonMoreToggle:InitCommonToggleGroup({
        toggleDataList = {
            { name = Language.ui_CharInfo_init },
            { name = Language.ui_CharInfo_max_level },
            { name = Language.ui_WikiWeapon_gem_equiped },
        },
        onToggleIsOn = function(index)
            self:_RefreshWeaponState(index)
        end,
        defaultIndex = self.m_curWeaponState,
        defaultNotCall = true,
    })

    
    self.view.contentNode.itemInfoNode.wikiBtn.onClick:RemoveAllListeners()
    self.view.contentNode.itemInfoNode.wikiBtn.onClick:AddListener(function()
        if self.m_selectedWeaponId and self.m_selectedWeaponId ~= "" then
            Notify(MessageConst.SHOW_WIKI_ENTRY, { itemId = self.m_selectedWeaponId })
        end
    end)

    
    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.contentNode.scrollGroupList)
    self.m_getTitleCellFunc = UIUtils.genCachedCellFunction(self.view.contentNode.scrollGroupList, nil, true)

    
    self.view.contentNode.scrollGroupList.getCellCountInGroup = function(groupCSIndex)
        local luaIndex = LuaIndex(groupCSIndex)
        if self:_GetScrollGroupCount() == 1 then
            return #self.m_displayWeaponList
        else
            if luaIndex == 1 then
                return #self.m_displayForesightWeaponList
            else
                return #self.m_displayWeaponList
            end
        end
    end

    
    self.view.contentNode.scrollGroupList.onUpdateGroupTitle:RemoveAllListeners()
    self.view.contentNode.scrollGroupList.onUpdateGroupTitle:AddListener(function(titleGo, groupIndex)
        local titleCell = self.m_getTitleCellFunc(titleGo)
        local luaIndex = LuaIndex(groupIndex)
        self:_SetupUIScrollGroupTitle(titleCell, luaIndex)
    end)

    
    self.view.contentNode.scrollGroupList.onUpdateCell:RemoveAllListeners()
    self.view.contentNode.scrollGroupList.onUpdateCell:AddListener(function(cellGo, cellIndex)
        local cell = self.m_getCellFunc(cellGo)
        local luaIndex = LuaIndex(cellIndex)
        local firstGroupCount = #self.m_displayForesightWeaponList
        local groupIndex = 1
        if luaIndex > firstGroupCount then
            groupIndex = 2
            luaIndex = luaIndex - firstGroupCount
        end
        self:_SetupUIScrollGroupCell(cell, groupIndex, luaIndex)
    end)

    self.m_filterOptions = FilterUtils.generateConfig_DEPOT_WEAPON()
    
    for _, group in ipairs(self.m_filterOptions) do
        if group.tags then
            for i = #group.tags, 1, -1 do
                local tag = group.tags[i]
                if tag.groupType == "WeaponRarity" and tag.param == 3 then
                    table.remove(group.tags, i)
                end
            end
        end
    end
    self.view.bottomNode.filterBtn:InitFilterBtn({
        tagGroups = self.m_filterOptions,
        selectedTags = self.m_filterConfigs or {},
        onConfirm = function(tags)
            self:_OnFilterBtnClick(tags)
        end,
        getResultCount = function(tags)
            return self:_GetFilterResultCount(tags)
        end,
    })

    self.view.bottomNode.cancelSelectBtn.onClick:RemoveAllListeners()
    self.view.bottomNode.cancelSelectBtn.onClick:AddListener(function()
        self:_OnReset()
    end)

    self.view.bottomNode.saveBtn.onClick:RemoveAllListeners()
    self.view.bottomNode.saveBtn.onClick:AddListener(function()
        self:_OnSave()
    end)

    self.view.bottomNode.functionBtn.onClick:RemoveAllListeners()
    self.view.bottomNode.functionBtn.onClick:AddListener(function()
        self:_OnFillUpClick()
    end)

    if DeviceInfo.usingController then
        self.m_toggleCheckBindingId = self:BindInputPlayerAction("gem_wishlist_select_cell", function()
            self:_OnControllerToggleCheck()
        end, self.view.inputGroup.groupId)
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:_RefreshControllerToggleHint()
end


GemWishlistCtrl._InitData = HL.Method() << function(self)
    self.m_maxCheckCount = self.view.config.MAX_SELECT_NUM

    self.m_checkedWeapons = {}
    self.m_savedCheckedWeapons = {}
    self.m_filterConfigs = {}
    self.m_allWeaponList = {}
    self.m_allForesightWeaponList = {}
    self.m_weaponInfoMap = {}

    for weaponId, weaponCfg in pairs(Tables.weaponBasicTable) do
        local hasValue, itemCfg = Tables.itemTable:TryGetValue(weaponId)
        
        if hasValue and itemCfg.rarity > 3 then
            
            local weaponItemInfo = {
                id = weaponId,
                count = 0,
                forceHidePotentialStar = true,
                isEquipped = false,
                isOwned = false,
                equippedSort = 0,
                ownedSort = 0,
                rarity = itemCfg.rarity,
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
                weaponType = weaponCfg.weaponType,
                isForesight = false,
            }
            table.insert(self.m_allWeaponList, weaponItemInfo)
            self.m_weaponInfoMap[weaponId] = weaponItemInfo
        end
    end

    local weaponDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Weapon]:GetOrFallback(Utils.getCurrentScope())
    local weaponInstDict = weaponDepot.instItems
    for instId, instItemBundle in cs_pairs(weaponInstDict) do
        local weaponItemInfo = self.m_weaponInfoMap[instItemBundle.id]
        if weaponItemInfo then
            weaponItemInfo.isOwned = true
            weaponItemInfo.ownedSort = 1
            local equippedCardInstId = instItemBundle.instData.equippedCharServerId
            local isEquipped = equippedCardInstId and equippedCardInstId > 0
            if isEquipped then
                weaponItemInfo.isEquipped = true
                weaponItemInfo.equippedSort = 1
            end
        end
    end

    
    local sortId = 100
    for weaponId, weaponCfg in pairs(Tables.foresightWeaponGemwishlistTable) do
        
        if not self.m_weaponInfoMap[weaponId] then
            local extra = self:_BuildForesightWeaponExtra(weaponId, weaponCfg)
            local weaponItemInfo = {
                id = weaponId,
                count = 0,
                forceHidePotentialStar = true,
                isEquipped = false,
                isOwned = false,
                equippedSort = 0,
                ownedSort = 0,
                rarity = extra.rarity,
                sortId1 = sortId,
                sortId2 = 0,
                weaponType = extra.weaponType,
                isForesight = true,
                extra = extra,
            }
            table.insert(self.m_allForesightWeaponList, weaponItemInfo)
            self.m_weaponInfoMap[weaponId] = weaponItemInfo
        else
            logger.info(string.format("[gemwishlist] %s 已被排除", weaponId))
        end
        sortId = sortId - 1  
    end

    
    table.sort(self.m_allWeaponList, Utils.genSortFunction({ "rarity", "equippedSort", "ownedSort", "sortId1", "sortId2", "id" }))
    table.sort(self.m_allForesightWeaponList, Utils.genSortFunction({ "rarity", "equippedSort", "ownedSort", "sortId1", "sortId2", "id" }))

    local serverWishList = GameInstance.player.inventory.weaponGemWishList
    for _, weaponId in pairs(serverWishList) do
        if self.m_weaponInfoMap[weaponId] then
            self.m_checkedWeapons[weaponId] = true
            self.m_savedCheckedWeapons[weaponId] = true
        end
    end

    self:_BuildDisplayList()
    self:_InitCurrSelectedIfNil()
end


GemWishlistCtrl._BuildDisplayList = HL.Method() << function(self)
    local hasFilter = self.m_filterConfigs and next(self.m_filterConfigs)
    if not hasFilter then
        self.m_displayWeaponList = self.m_allWeaponList
        self.m_displayForesightWeaponList = self.m_allForesightWeaponList
        return
    end

    local displayList = {}
    for _, info in ipairs(self.m_allWeaponList) do
        if self.m_checkedWeapons[info.id] then
            table.insert(displayList, info)
        else
            local filterInfo = info 
            if FilterUtils.checkIfPassFilter(filterInfo, self.m_filterConfigs) then
                table.insert(displayList, info)
            end
        end
    end
    self.m_displayWeaponList = displayList

    local displayForesightList = {}
    for _, info in ipairs(self.m_allForesightWeaponList) do
        if self.m_checkedWeapons[info.id] then
            table.insert(displayForesightList, info)
        else
            local filterInfo = info 
            if FilterUtils.checkIfPassFilter(filterInfo, self.m_filterConfigs) then
                table.insert(displayForesightList, info)
            end
        end
    end
    self.m_displayForesightWeaponList = displayForesightList
end

GemWishlistCtrl._InitCurrSelectedIfNil = HL.Method() << function(self)
    if not string.isEmpty(self.m_selectedWeaponId) then
        return
    end
    if #self.m_displayForesightWeaponList > 0 then
        self.m_selectedWeaponId = self.m_displayForesightWeaponList[1].id
    elseif #self.m_displayWeaponList > 0 then
        self.m_selectedWeaponId = self.m_displayWeaponList[1].id
    end
end






GemWishlistCtrl._OnCloseBtnClick = HL.Method() << function(self)
    if not self:_IsDirty() then
        PhaseManager:PopPhase(PhaseId.GemWishlist)
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_GEM_WISHLIST_QUIT_NO_SAVE_CONFIRM,
        onConfirm = function()
            PhaseManager:PopPhase(PhaseId.GemWishlist)
        end,
    })
end


GemWishlistCtrl._OnSave = HL.Method() << function(self)
    local curTime = CS.UnityEngine.Time.unscaledTime
    if curTime < self.m_nextSaveClickTime then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FRIEND_TOAST_SWITCH_STRANGER_CD)
        return
    end
    self.m_nextSaveClickTime = curTime + SAVE_CLICK_CD

    local weaponIds = {}
    for id in pairs(self.m_checkedWeapons) do
        table.insert(weaponIds, id)
    end
    GameInstance.player.inventory:SetWeaponGemWishList(weaponIds)
    self.m_savedCheckedWeapons = {}
    for id in pairs(self.m_checkedWeapons) do
        self.m_savedCheckedWeapons[id] = true
    end
    Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_WISHLIST_SAVE_TOAST)
end


GemWishlistCtrl._OnReset = HL.Method() << function(self)
    self.m_checkedWeapons = {}
    self:_RefreshUI()
end


GemWishlistCtrl._OnFillUpClick = HL.Method() << function(self)
    local checkedCount = self:_GetCheckedCount()
    if checkedCount >= self.m_maxCheckCount then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_WISHLIST_MAX_TOAST)
        return
    end

    local function fillUpFromList(displayList)
        for _, info in ipairs(displayList) do
            if checkedCount >= self.m_maxCheckCount then
                break
            end
            if not self.m_checkedWeapons[info.id] then
                self.m_checkedWeapons[info.id] = true
                checkedCount = checkedCount + 1
            end
        end
    end
    fillUpFromList(self.m_displayForesightWeaponList)
    fillUpFromList(self.m_displayWeaponList)

    self:_RefreshUI()
end


GemWishlistCtrl._OnClickWeapon = HL.Method(HL.Any) << function(self, info)
    
    info = info

    if not info then
        return
    end

    self.m_selectedWeaponId = info.id

    
    

    if not DeviceInfo.usingController then
        if self.m_checkedWeapons[info.id] then
            self.m_checkedWeapons[info.id] = nil
        else
            if self:_GetCheckedCount() >= self.m_maxCheckCount then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_WISHLIST_MAX_TOAST)
            else
                self.m_checkedWeapons[info.id] = true
            end
        end
    end

    self:_RefreshUI()
end


GemWishlistCtrl._OnControllerToggleCheck = HL.Method() << function(self)
    if not self.m_selectedWeaponId or self.m_selectedWeaponId == "" then
        return
    end

    if self.m_checkedWeapons[self.m_selectedWeaponId] then
        self.m_checkedWeapons[self.m_selectedWeaponId] = nil
    else
        if self:_GetCheckedCount() >= self.m_maxCheckCount then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_WISHLIST_MAX_TOAST)
            return
        end
        self.m_checkedWeapons[self.m_selectedWeaponId] = true
    end

    self:_RefreshUI()
end


GemWishlistCtrl._OnFilterBtnClick = HL.Method(HL.Table) << function(self, tags)
    if not self:_CheckTagsIsDirty(tags) then
        return
    end

    self.m_filterConfigs = tags
    self:_BuildDisplayList()
    
    local v, k = lume.match(self.m_displayForesightWeaponList, function(info)
        return info.id == self.m_selectedWeaponId
    end)
    if v == nil then
        v, k = lume.match(self.m_displayWeaponList, function(info)
            return info.id == self.m_selectedWeaponId
        end)
    end
    if v == nil then
        self.m_selectedWeaponId = ""
        self:_InitCurrSelectedIfNil()
    end

    self:_SyncSelectionAfterListChange()
end





GemWishlistCtrl.CheckAllWeapons = HL.Method() << function(self)
    for _, info in ipairs(self.m_displayWeaponList) do
        self.m_checkedWeapons[info.id] = true
    end
    self:_RefreshUI()
end







GemWishlistCtrl._RefreshUI = HL.Method(HL.Opt(HL.Boolean)) << function(self, setTop)
    if setTop == nil then
        setTop = false
    end
    self.view.contentNode.scrollGroupList:UpdateGroup(self:_GetScrollGroupCount(), setTop)
    self:_RefreshSelectCountTxt()
    self:_RefreshItemInfo()
    self:_RefreshControllerToggleHint()
end


GemWishlistCtrl._GetScrollGroupCount = HL.Method().Return(HL.Number) << function(self)
    if #self.m_displayForesightWeaponList == 0 then
        return 1
    else
        return 2
    end
end


GemWishlistCtrl._SetupUIScrollGroupTitle = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    
    cell = cell
    if self:_GetScrollGroupCount() == 1 then
        cell.titleText.gameObject:SetActive(false)
    else
        if index == 1 then
            cell.titleText.gameObject:SetActive(true)
        else
            cell.titleText.gameObject:SetActive(false)
        end
    end
end



GemWishlistCtrl._SetupUIScrollGroupCell = HL.Method(HL.Table, HL.Number, HL.Number) << function(self, cell, groupIndex, index)
    self:_SetupUIScrollGroupCellCore(cell, groupIndex,  index)

    if not self.m_haveInitNaviTarget and DeviceInfo.usingController then
        self.m_haveInitNaviTarget = true
        self:SetNaviTarget(cell.itemBig.view.button)
    end
end


GemWishlistCtrl._SetupUIScrollGroupCellCore = HL.Method(HL.Any, HL.Number, HL.Number) << function(self, cell, groupIndex, luaIndex)
    local info
    if self:_GetScrollGroupCount() == 1 then
        info = self.m_displayWeaponList[luaIndex]
    else
        info = groupIndex == 1 and self.m_displayForesightWeaponList[luaIndex] or self.m_displayWeaponList[luaIndex]
    end

    if not info then
        return
    end

    if info.isForesight then
        self:_SetupForesightWeaponCell(cell, info)
    else
        cell.itemBig:InitItem(info, function()
            self:_OnClickWeapon(info)
        end)
    end

    if info.isForesight then
        cell.extraTag:SetState("Preview")
    elseif info.isEquipped then
        cell.extraTag:SetState("Equipped")
    elseif info.isOwned then
        cell.extraTag:SetState("Owned")
    else
        cell.extraTag:SetState("Empty")
    end

    local isSelected = info.id == self.m_selectedWeaponId
    cell.itemBig:SetSelected(isSelected)

    local isChecked = self.m_checkedWeapons[info.id] == true
    cell.multiSelectMark.gameObject:SetActive(isChecked)
end


GemWishlistCtrl._SetupForesightWeaponCell = HL.Method(HL.Any, HL.Any) << function(self, cell, info)
    
    local extra = info.extra
    local item = cell.itemBig
    item:InitItem(nil, function()
        self:_OnClickWeapon(info)
    end, nil, true)
    item.id = info.id
    item.count = info.count
    item.view.content.gameObject:SetActive(true)
    item.view.button.enabled = true
    item.view.button.onClick:RemoveAllListeners()
    item.view.button.onClick:AddListener(function()
        self:_OnClickWeapon(info)
    end)

    item.view.name.text = extra.name
    if item.view.nameScrollText then
        item.view.nameScrollText:ForceUpdate()
    end
    item.view.count.gameObject:SetActive(false)

    item.view.icon.showRarity = true
    item.view.icon.view.icon:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, extra.iconId)
    if item.view.icon.view.bg then
        item.view.icon.view.bg.gameObject:SetActive(false)
    end
    if item.view.icon.view.mark then
        item.view.icon.view.mark.gameObject:SetActive(false)
    end

    local isMaxRarity = extra.rarity == UIConst.ITEM_MAX_RARITY
    item.view.simpleStateController:SetState(isMaxRarity and "6Star" or "Normal")
    if item.view.rarityLine then
        local rarityColor = UIUtils.getItemRarityColor(extra.rarity)
        item.view.rarityLine.color = rarityColor
        if item.view.rarityLight and not isMaxRarity then
            item.view.rarityLight.color = rarityColor
        end
    end
end


GemWishlistCtrl._RefreshItemInfo = HL.Method() << function(self)
    local node = self.view.contentNode.itemInfoNode
    
    local info = self:GetInfoByWeaponId(self.m_selectedWeaponId)
    if not self.m_selectedWeaponId or self.m_selectedWeaponId == "" or info == nil then
        node.gameObject:SetActive(false)
        return
    end
    node.gameObject:SetActive(true)

    if info.isForesight then
        self:_SetupItemInfoManuel(node, info)
    else
        self.view.commonTopTitleNode.commonMoreToggle.view.gameObject:SetActive(true)
        UIUtils.displayItemBasicInfos(node, self.loader, self.m_selectedWeaponId, nil)
        node.itemDescNode:InitItemDescNode(self.m_selectedWeaponId)
        node.stateCtrl:SetState("weapon")
        self:_RefreshWeaponState(self.m_curWeaponState)
        node.itemObtainWays:InitItemObtainWays(self.m_selectedWeaponId, nil)
        node.lockToggle.gameObject:SetActive(false)
        node.trashToggle.gameObject:SetActive(false)
        node.wikiBtn.gameObject:SetActive(WikiUtils.canShowWikiEntry(self.m_selectedWeaponId))
    end

    
    self.view.contentNode.itemInfoNode.content.transform:Find("BasicInfoNode/AnimationNode/Potential").gameObject:SetActive(not info.isForesight)
    local skillCount = self.view.contentNode.itemInfoNode.weaponSkillNode.m_weaponSkillCellCache:GetCount()
    for i = 1, skillCount do
        local skillCell = self.view.contentNode.itemInfoNode.weaponSkillNode.m_weaponSkillCellCache:Get(i)
        skillCell.view.desc.gameObject:SetActive(not info.isForesight)
    end
end



GemWishlistCtrl._SetupItemInfoManuel = HL.Method(HL.Any, HL.Any) << function(self, node, info)
    
    local extra = info.extra
    if not extra then
        return
    end

    node.itemNameTxt.text = extra.name
    node.itemIcon.view.gameObject:SetActive(true)
    node.itemIcon.showRarity = true
    node.itemIcon.view.icon:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, extra.iconId)
    if node.itemIcon.view.bg then
        node.itemIcon.view.bg.gameObject:SetActive(false)
    end
    if node.itemIcon.view.mark then
        node.itemIcon.view.mark.gameObject:SetActive(false)
    end
    node.itemTypeTxt.text = extra.typeName
    UIUtils.setItemRarityImage(node.rarityLine, extra.rarity)

    local descView = node.itemDescNode.view
    descView.defaultDesc:SetAndResolveTextStyle(extra.desc)
    descView.defaultDesc.gameObject:SetActive(true)
    descView.decoSplitLine.gameObject:SetActive(false)
    descView.tacticalItemTitle.gameObject:SetActive(false)
    descView.tacticalItemDesc.gameObject:SetActive(false)
    descView.equipItemTitle.gameObject:SetActive(false)
    descView.equipItemDesc.gameObject:SetActive(false)
    descView.decoDesc.gameObject:SetActive(true)
    descView.decoDesc.text = ""

    node.stateCtrl:SetState("weapon")
    self.view.commonTopTitleNode.commonMoreToggle.view.gameObject:SetActive(false)
    self:_RefreshForesightWeaponState(node, info, self.m_curWeaponState)

    node.itemObtainWays.view.gameObject:SetActive(false)
    node.lockToggle.gameObject:SetActive(false)
    node.trashToggle.gameObject:SetActive(false)
    node.wikiBtn.gameObject:SetActive(false)
end


GemWishlistCtrl._RefreshForesightWeaponState = HL.Method(HL.Any, HL.Any, HL.Number) << function(self, node, info, weaponState)
    
    local extra = info.extra
    if not extra then
        return
    end

    node.starGroup:InitStarGroup(extra.rarity)
    node.potentialStar.view.gameObject:SetActive(false)
    node.tipWeaponLevelNode.view.gameObject:SetActive(false)
    self:_RefreshForesightWeaponAttributes(node.weaponAttributeNode, extra.attributes)
    self:_RefreshForesightWeaponSkills(node.weaponSkillNode, extra.skills)
    node.weaponGemSlimNode.view.gameObject:SetActive(false)
    if node.equippedNode then
        node.equippedNode.gameObject:SetActive(false)
    end
end


GemWishlistCtrl._RefreshForesightWeaponAttributes = HL.Method(HL.Any, HL.Table) << function(self, weaponAttributeNode, attributes)
    weaponAttributeNode:_FirstTimeInit()
    weaponAttributeNode.m_subAttributeCellCache:Refresh(0, nil)
    weaponAttributeNode.m_extraAttributeCellCache:Refresh(0, nil)
    weaponAttributeNode.m_mainAttributeCellCache:Refresh(0, nil)
end


GemWishlistCtrl._RefreshForesightWeaponSkills = HL.Method(HL.Any, HL.Table) << function(self, weaponSkillNode, skills)
    weaponSkillNode:_FirstTimeInit()
    weaponSkillNode.m_weaponSkillCellCache:Refresh(#skills, function(cell, index)
        
        local skillInfo = skills[index]
        cell:_FirstTimeInit()
        cell.view.gameObject:SetActive(true)
        cell.view.name.text = skillInfo.name
        cell.view.progressText.text = ""
        self:_SetWeaponSkillCellProgressNodeVisible(cell, false)
        cell.m_skillNotchCellCache:Refresh(0, nil)
        cell.view.stateController:SetState("normal")
        if cell.view.recommendImg then
            cell.view.recommendImg.gameObject:SetActive(false)
        end
    end)
end

GemWishlistCtrl._SetWeaponSkillProgressNodeVisible = HL.Method(HL.Any, HL.Boolean) << function(self, weaponSkillNode, visible)
    if not weaponSkillNode.m_weaponSkillCellCache then
        return
    end
    for index = 1, weaponSkillNode.m_weaponSkillCellCache:GetCount() do
        local cell = weaponSkillNode.m_weaponSkillCellCache:GetItem(index)
        if cell then
            self:_SetWeaponSkillCellProgressNodeVisible(cell, visible)
        end
    end
end

GemWishlistCtrl._SetWeaponSkillCellProgressNodeVisible = HL.Method(HL.Any, HL.Boolean) << function(self, cell, visible)
    if cell.view.progressText and cell.view.progressText.transform and cell.view.progressText.transform.parent then
        cell.view.progressText.transform.parent.gameObject:SetActive(visible)
    end
end





GemWishlistCtrl.GetInfoByWeaponId = HL.Method(HL.String).Return(HL.Opt(HL.Any)) << function(self, weaponId)
    local v, k = lume.match(self.m_allForesightWeaponList, function(info)
        return info.id == weaponId
    end)
    if v then
        return v
    end

    v, k = lume.match(self.m_allWeaponList, function(info)
        return info.id == weaponId
    end)
    return v
end


GemWishlistCtrl._BuildForesightWeaponExtra = HL.Method(HL.String, HL.Any).Return(HL.Table) << function(self, weaponId, weaponCfg)
    
    weaponCfg = weaponCfg
    local weaponType = weaponCfg.wpnType
    local weaponTypeInt = weaponType and weaponType:ToInt() or 0
    local typeName = Language[string.format("LUA_WEAPON_TYPE_%d", weaponTypeInt)] or ""
    local skills = {}
    local skillIds = weaponCfg.skIds or {}
    local skillNames = weaponCfg.skNames or {}
    for index, skillId in pairs(skillIds) do
        
        local skillInfo = {
            id = skillId,
            name = skillNames[index] or "",
        }
        table.insert(skills, skillInfo)
    end

    
    local extra = {
        weaponId = weaponId,
        name = weaponCfg.name or "",
        rarity = weaponCfg.rarity,
        iconId = weaponCfg.iconId or "",
        weaponType = weaponType,
        typeName = typeName,
        skills = skills,
    }
    return extra
end


GemWishlistCtrl._SyncSelectionAfterListChange = HL.Method() << function(self)
    local targetIndex = nil
    for i, info in ipairs(self.m_displayForesightWeaponList) do
        if info.id == self.m_selectedWeaponId then
            targetIndex = i
            break
        end
    end
    if targetIndex == nil then
        targetIndex = #self.m_displayForesightWeaponList
        for i, info in ipairs(self.m_displayWeaponList) do
            if info.id == self.m_selectedWeaponId then
                targetIndex = targetIndex + i
                break
            end
        end
    end

    
    
    
    
    
    
    
    

    self:_RefreshUI()

    if targetIndex then
        self.view.contentNode.scrollGroupList:ScrollToIndex(CSIndex(targetIndex), true)
        if DeviceInfo.usingController then
            local cell = self.m_getCellFunc(targetIndex)
            if cell then
                self:SetNaviTarget(cell.itemBig.view.button)
            end
        end
    end
end


GemWishlistCtrl._GetWeaponShowData = HL.Method(HL.String, HL.Number).Return(HL.Table) << function(self, templateId, weaponState)
    local maxLevel, initMaxLevel, breakThroughCount, maxBreakthroughLevel, maxRefineLevel = 0, 0, 0, 0, 0

    local _, weaponBasicData = Tables.weaponBasicTable:TryGetValue(templateId)
    if weaponBasicData then
        maxLevel = weaponBasicData.maxLv
        local _, weaponBreakThroughDetailList = Tables.weaponBreakThroughTemplateTable:TryGetValue(weaponBasicData.breakthroughTemplateId)
        if weaponBreakThroughDetailList then
            breakThroughCount = #weaponBreakThroughDetailList.list
            if breakThroughCount > 1 then
                initMaxLevel = weaponBreakThroughDetailList.list[1].breakthroughLv
                maxBreakthroughLevel = breakThroughCount - 1
            end
        end
        local _, weaponTalentDetailList = Tables.weaponTalentTemplateTable:TryGetValue(weaponBasicData.talentTemplateId)
        if weaponTalentDetailList then
            maxRefineLevel = #weaponTalentDetailList.list
        end
    end

    local isMaxLevel = weaponState ~= WeaponState.Init
    return {
        templateId = templateId,
        level = isMaxLevel and maxLevel or 1,
        maxLevel = isMaxLevel and maxLevel or initMaxLevel,
        breakthroughLevel = isMaxLevel and maxBreakthroughLevel or 0,
        maxBreakthroughLevel = maxBreakthroughLevel,
        refineLevel = isMaxLevel and maxRefineLevel or 0,
    }
end


GemWishlistCtrl._RefreshWeaponState = HL.Method(HL.Number) << function(self, weaponState)
    self.m_curWeaponState = weaponState
    if not self.m_selectedWeaponId or self.m_selectedWeaponId == "" then
        return
    end

    local node = self.view.contentNode.itemInfoNode
    local templateId = self.m_selectedWeaponId
    local info = self:GetInfoByWeaponId(templateId)
    if info and info.isForesight then
        self:_RefreshForesightWeaponState(node, info, weaponState)
        return
    end

    local itemData = Tables.itemTable[templateId]
    local showData = self:_GetWeaponShowData(templateId, weaponState)
    local isMax = weaponState ~= WeaponState.Init
    local isGemMax = weaponState == WeaponState.Gem

    node.starGroup:InitStarGroup(itemData.rarity)
    node.potentialStar.view.gameObject:SetActive(true)
    node.tipWeaponLevelNode.view.gameObject:SetActive(true)
    node.potentialStar:InitWeaponPotentialStar(showData.refineLevel)
    if node.potentialStar.view.breakthroughBg then
        node.potentialStar.view.breakthroughBg.gameObject:SetActive(not isMax)
    end
    node.tipWeaponLevelNode:InitTipWeaponLevelNodeNoInst(showData.level, showData.maxLevel, showData.breakthroughLevel, showData.maxBreakthroughLevel)
    node.weaponAttributeNode:InitWeaponAttributeNodeByTemplateId(templateId, isMax)
    self:_SetWeaponSkillProgressNodeVisible(node.weaponSkillNode, true)
    node.weaponSkillNode:InitWeaponSkillNodeByTemplateId(templateId, showData.breakthroughLevel, showData.refineLevel, isGemMax)

    local gemInst
    if isGemMax then
        gemInst = CS.Beyond.Gameplay.InventorySystem.CreateWeaponPerfectGemInst(templateId)
    end
    node.weaponGemSlimNode.view.gameObject:SetActive(true)
    node.weaponGemSlimNode:InitWeaponGemSlimeNodeByInst(gemInst)

    if node.equippedNode then
        node.equippedNode.gameObject:SetActive(false)
    end
end


GemWishlistCtrl._RefreshSelectCountTxt = HL.Method() << function(self)
    self.view.bottomNode.selectCountTxt.text = self:_GetCheckedCount() .. "/" .. self.m_maxCheckCount
end


GemWishlistCtrl._RefreshControllerToggleHint = HL.Method() << function(self)
    if not DeviceInfo.usingController or self.m_toggleCheckBindingId < 0 then
        return
    end

    local bindingText = ""
    if self.m_selectedWeaponId and self.m_selectedWeaponId ~= "" then
        bindingText = self.m_checkedWeapons[self.m_selectedWeaponId]
            and Language.key_hint_common_unselect
            or Language.key_hint_common_select
    end
    InputManagerInst:SetBindingText(self.m_toggleCheckBindingId, bindingText)
end


GemWishlistCtrl._GetCheckedCount = HL.Method().Return(HL.Number) << function(self)
    local count = 0
    for _ in pairs(self.m_checkedWeapons) do
        count = count + 1
    end
    return count
end


GemWishlistCtrl._GetFilterResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if not tags or not next(tags) then
        return #self.m_allWeaponList + #self.m_allForesightWeaponList
    end
    local count = 0
    for _, info in ipairs(self.m_allWeaponList) do
        local filterInfo = info 
        if self.m_checkedWeapons[info.id] or FilterUtils.checkIfPassFilter(filterInfo, tags) then
            count = count + 1
        end
    end
    for _, info in ipairs(self.m_allForesightWeaponList) do
        local filterInfo = info 
        if self.m_checkedWeapons[info.id] or FilterUtils.checkIfPassFilter(filterInfo, tags) then
            count = count + 1
        end
    end
    return count
end


GemWishlistCtrl._IsDirty = HL.Method().Return(HL.Boolean) << function(self)
    local savedCount = 0
    for id in pairs(self.m_savedCheckedWeapons) do
        savedCount = savedCount + 1
        if not self.m_checkedWeapons[id] then
            return true
        end
    end
    return savedCount ~= self:_GetCheckedCount()
end

GemWishlistCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local displayWeaponIds = {}
    for _, info in ipairs(self.m_displayWeaponList) do
        table.insert(displayWeaponIds, info.id)
    end
    local foresightDisplayWeaponIds = {}
    for _, info in ipairs(self.m_displayForesightWeaponList) do
        table.insert(foresightDisplayWeaponIds, info.id)
    end
    return {
        selectedWeaponId = self.m_selectedWeaponId,
        checkedWeapons = lume.deepCopy(self.m_checkedWeapons),
        filterConfigs = lume.deepCopy(self.m_filterConfigs),
        displayWeaponIds = displayWeaponIds,
        foresightDisplayWeaponIds = foresightDisplayWeaponIds,
        weaponState = self.m_curWeaponState,
    }
end

GemWishlistCtrl._CheckTagsIsDirty = HL.Method(HL.Table).Return(HL.Boolean) << function(self, tags)
    tags = tags or {}
    local filterConfigs = self.m_filterConfigs or {}
    if #filterConfigs ~= #tags then
        return true
    end

    for _, tag in ipairs(tags) do
        local hasSameTag = lume.match(filterConfigs, function(filterConfig)
            return filterConfig.groupType == tag.groupType and filterConfig.name == tag.name
        end) ~= nil
        if not hasSameTag then
            return true
        end
    end

    return false
end



HL.Commit(GemWishlistCtrl)
