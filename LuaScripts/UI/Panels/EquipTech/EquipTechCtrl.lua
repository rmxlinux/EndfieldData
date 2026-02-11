
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.EquipTech
local PHASE_ID = PhaseId.EquipTech










































































EquipTechCtrl = HL.Class('EquipTechCtrl', uiCtrl.UICtrl)



local STATE_NAME = {
    PRODUCE = "produce",
    ENHANCE_TARGET = "enhanceTarget",
    ENHANCE_MATERIAL = "enhanceMaterial",
}

local EQUIP_SLOT_TAB_CONFIG = {
    [1] = {
        partType = nil,
    },
    [2] = {
        partType = GEnums.PartType.Body,
    },
    [3] = {
        partType = GEnums.PartType.Hand,
    },
    [4] = {
        partType = GEnums.PartType.EDC,
    },
}

local GO_TO_TEXT_KEY = {
    [GEnums.EquipFormulaUnlockType.EquipFormulaChest] = "LUA_EQUIP_FORMULA_SOURCE_CHEST",
    [GEnums.EquipFormulaUnlockType.DomainShop] = "LUA_EQUIP_FORMULA_SOURCE_SHOP",
}








EquipTechCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_EQUIP_PRODUCE] = '_OnEquipProduce',
    [MessageConst.ON_EQUIP_ENHANCE] = '_OnEquipEnhance',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = '_OnItemChanged',
    [MessageConst.ON_WALLET_CHANGED] = '_OnItemChanged',
    [MessageConst.GUIDE_EQUIP_PRODUCE_SCROLL_TO_ITEM] = '_OnGuideEquipProduceScrollToItem',
}


EquipTechCtrl.m_equipTechSystem = HL.Field(HL.Userdata)


EquipTechCtrl.m_fromDialog = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_jumpEquipId = HL.Field(HL.String) << ""


EquipTechCtrl.m_jumpFormulaId = HL.Field(HL.String) << ""


EquipTechCtrl.m_jumpMaterialEquipId = HL.Field(HL.String) << ""













EquipTechCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_equipTechSystem = GameInstance.player.equipTechSystem

    self.m_fromDialog = arg ~= nil and arg.fromDialog == true

    self:_InitAction()
    self:_InitController()

    if arg ~= nil and arg.isEnhance then
        self.m_jumpEquipId = string.isEmpty(arg.equipId) and "" or arg.equipId
        self.m_jumpMaterialEquipId = string.isEmpty(arg.materialEquipId) and "" or arg.materialEquipId
        self:_EnterEnhanceTarget()
        self.view.commonBg.tabEnhanceNode.toggle:SetIsOnWithoutNotify(true)
    else
        self.m_isInitClickProduceEquip = true
        if arg and not string.isEmpty(arg.formulaId) then
            self.m_jumpFormulaId = arg.formulaId
        end
        self:_EnterProduce()
    end
end



EquipTechCtrl.OnClose = HL.Override() << function(self)
    self:_SendFormulaRead()
end




EquipTechCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    
    self:_EnterProduce()
end







EquipTechCtrl._InitAction = HL.Method() << function(self)
    self:BindInputPlayerAction("equip_tech_close", function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.topBar.btnClose.onClick:AddListener(function()
        if self.m_fromDialog then
            self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 0 })
        else
            PhaseManager:PopPhase(PHASE_ID)
        end
    end)
    self.view.topBar.btnBack.onClick:AddListener(function()
        self.view.middleBar.enhanceAttrNode.animationWrapper:PlayOutAnimation()
        self.view.middleBar.bottomNode.animationWrapper:PlayOutAnimation()
        self.view.middleBar.materialContent.animationWrapper:PlayOutAnimation()
        self.view.selectMaterials.animationWrapper:PlayOutAnimation(function()
            self:_BackToEnhanceTarget()
        end)
    end)
    self.view.topBar.btnHelp.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, "equip_enhance")
    end)

    self.view.commonBg.tabSuitNode.redDot:InitRedDot("EquipProducer", true)
    self.view.commonBg.tabPartsNode.redDot:InitRedDot("EquipProducer", false)

    self.view.commonBg.tabSuitNode.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self.m_playAnimProduceList = true
            self:_EnterSuitProduce()
        end
    end)
    self.view.commonBg.tabPartsNode.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self.m_playAnimProduceList = true
            self:_EnterPartsProduce()
        end
    end)
    self.view.commonBg.tabEnhanceNode.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_EnterEnhanceTarget()
        end
    end)

    self.view.rightProduceNode.bottomNode.btnMake.onClick:AddListener(function()
        self.m_equipTechSystem:ProduceEquip(self.m_selectedProduceItemInfo.equipFormulaData.formulaId)
    end)
    self.view.rightProduceNode.bottomNode.gotoNode.buttonGoto.onClick:AddListener(function()
        if not self.m_selectedProduceItemInfo or not self.m_selectedProduceItemInfo.equipFormulaData then
            logger.error("EquipTechCtrl->_OnProduceGotoClicked: No selected item info available.")
            return
        end

        local equipFormulaData = self.m_selectedProduceItemInfo.equipFormulaData
        local uniqueKey = equipFormulaData.unlockKey
        if string.isEmpty(uniqueKey) then
            logger.error("EquipTechCtrl->_OnProduceGotoClicked: Unique key is empty for formulaId: " .. equipFormulaData.formulaId)
            return
        end
        local markType
        if equipFormulaData.unlockType == GEnums.EquipFormulaUnlockType.EquipFormulaChest then
            markType = GEnums.MarkType.EquipFormulaChest
        elseif equipFormulaData.unlockType == GEnums.EquipFormulaUnlockType.DomainShop then
            markType = GEnums.MarkType.DomainShop
        end
        if markType then
            local found, instId = GameInstance.player.mapManager:GetMapMarkInstId(markType, uniqueKey)
            if found then
                MapUtils.openMap(instId)
            else
                logger.error("EquipTechCtrl->_OnProduceGotoClicked: Failed to find mark with type: " .. tostring(markType) .. " and unique key: " .. uniqueKey)
            end
        else
            logger.error("EquipTechCtrl->_OnProduceGotoClicked: Invalid unlock type: " .. tostring(equipFormulaData.unlockType))
        end
    end)
    self.view.commonBg.tabSuitNode.gameObject:SetActive(EquipTechUtils.hasVisibleSuitEquipPack())
    self.view.commonBg.tabEnhanceNode.gameObject:SetActive(Utils.isSystemUnlocked(GEnums.UnlockSystemType.EquipEnhance))
end



EquipTechCtrl._EnterProduce = HL.Method() << function(self)
    local jumpSuccess = false
    if not string.isEmpty(self.m_jumpFormulaId) then
        local _, formulaData = Tables.equipFormulaTable:TryGetValue(self.m_jumpFormulaId)
        if formulaData then
            local _, equipPackData = Tables.equipPackTable:TryGetValue(formulaData.packId)
            if equipPackData then
                if equipPackData.isSuit and self.view.commonBg.tabSuitNode.gameObject.activeSelf then
                    self:_EnterSuitProduce()
                    self.view.commonBg.tabSuitNode.toggle:SetIsOnWithoutNotify(true)
                    jumpSuccess = true
                else
                    self:_EnterPartsProduce()
                    self.view.commonBg.tabPartsNode.toggle:SetIsOnWithoutNotify(true)
                    jumpSuccess = true
                end
            else
                logger.error("EquipTechCtrl->_EnterProduce: No equip pack data found for packId: " .. formulaData.packId)
            end
        else
            logger.error("EquipTechCtrl->_EnterProduce: No formula data found for formulaId: " .. self.m_jumpFormulaId)
        end
        self.m_jumpFormulaId = ""
    end

    if not jumpSuccess then
        if self.view.commonBg.tabSuitNode.gameObject.activeSelf then
            self:_EnterSuitProduce()
            self.view.commonBg.tabSuitNode.toggle:SetIsOnWithoutNotify(true)
        else
            self:_EnterPartsProduce()
            self.view.commonBg.tabPartsNode.toggle:SetIsOnWithoutNotify(true)
        end
    end
end




EquipTechCtrl._OnGuideEquipProduceScrollToItem = HL.Method(HL.Table) << function(self, args)
    local itemId = unpack(args)
    local _, formulaId = Tables.equipFormulaReverseTable:TryGetValue(itemId)
    if formulaId then
        self.m_jumpFormulaId = formulaId
        self:_RefreshProduceList()
    end
end






EquipTechCtrl.m_getEquipPackCell = HL.Field(HL.Function)


EquipTechCtrl.m_equipPackDataList = HL.Field(HL.Table)


EquipTechCtrl.m_filteredEquipPackDataList = HL.Field(HL.Table)


EquipTechCtrl.m_selectedProduceFilterTags = HL.Field(HL.Table)


EquipTechCtrl.m_selectedProduceItemInfo = HL.Field(HL.Table)


EquipTechCtrl.m_selectedProduceItemCell = HL.Field(HL.Userdata)


EquipTechCtrl.m_costItemCellCache = HL.Field(HL.Forward("UIListCache"))


EquipTechCtrl.m_playAnimProduceList = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_isInitClickProduceEquip = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_jumpFormulaCell = HL.Field(HL.Any)



EquipTechCtrl._EnterSuitProduce = HL.Method() << function(self)
    self:_SendFormulaRead()
    self.view.stateController:SetState(STATE_NAME.PRODUCE)
    self.m_equipPackDataList = EquipTechUtils.getUnlockedEquipPackList(true)
    self.m_filteredEquipPackDataList = self.m_equipPackDataList
    self:_ClearProduceEquipSelection()
    self:_InitProduceList()
end



EquipTechCtrl._EnterPartsProduce = HL.Method() << function(self)
    self:_SendFormulaRead()
    self.view.stateController:SetState(STATE_NAME.PRODUCE)
    self.m_equipPackDataList = EquipTechUtils.getUnlockedEquipPackList(false)
    self.m_filteredEquipPackDataList = self.m_equipPackDataList
    self:_ClearProduceEquipSelection()
    self:_InitProduceList()
end





EquipTechCtrl._RefreshProducePackRedDot = HL.Method(HL.String, HL.Boolean) << function(self, packId, active)
    for _, packData in ipairs(self.m_equipPackDataList) do
        if packData.equipPackData.packId == packId then
            packData.hasRedDot = active
            break
        end
    end
end



EquipTechCtrl._InitProduceList = HL.Method() << function(self)
    if not self.m_getEquipPackCell then
        self.m_getEquipPackCell = UIUtils.genCachedCellFunction(self.view.leftBarProduce.itemList)
        self.view.leftBarProduce.itemList.onUpdateCell:AddListener(function(object, csIndex)
            local cell = self.m_getEquipPackCell(object)
            local packData = self.m_filteredEquipPackDataList[LuaIndex(csIndex)]
            self:_UpdateProducePackCell(cell, packData, csIndex)
            cell.gameObject.name = packData.equipPackData.packId
        end)
        self.view.leftBarProduce.redDotScrollRect.getRedDotStateAt = function(index)
            return self:_GetEquipPackRedDotStateAt(index)
        end

        
        local filterArgs = {
            tagGroups = FilterUtils.generateConfig_EQUIP_PRODUCE(),
            selectedTags = self.m_selectedProduceFilterTags,
            onConfirm = function(selectedTags)
                self.m_selectedProduceFilterTags = selectedTags
                self:_ApplyProduceFilterOption(selectedTags)
                local sortNode = self.view.leftBarProduce.sortNode
                self:_ApplyProduceSortOption(sortNode:GetCurSortData(), sortNode.isIncremental)
                self:_RefreshProduceList()
            end,
            getResultCount = function(selectedTags)
                return self:_GetProduceFilterResultCount(selectedTags)
            end,
            sortNodeWidget = self.view.leftBarProduce.sortNode,
        }
        self.view.leftBarProduce.filterBtn:InitFilterBtn(filterArgs)

        self.view.leftBarProduce.sortNode:InitSortNode(EquipTechConst.EQUIP_PRODUCE_PACK_SORT_OPTION, function(sortOption, isIncremental)
            self:_ApplyProduceSortOption(sortOption, isIncremental)
            self:_RefreshProduceList()
        end, nil, nil, true, self.view.leftBarProduce.filterBtn)
    end

    self:_ApplyProduceFilterOption(self.m_selectedProduceFilterTags)
    local sortNode = self.view.leftBarProduce.sortNode
    self:_ApplyProduceSortOption(sortNode:GetCurSortData(), sortNode.isIncremental)
    self:_RefreshProduceList()
end





EquipTechCtrl._ApplyProduceSortOption = HL.Method(HL.Table, HL.Boolean) << function(self, sortOption, isIncremental)
    local sortFunc = Utils.genSortFunction(sortOption.keys, isIncremental)
    table.sort(self.m_filteredEquipPackDataList, sortFunc)
end




EquipTechCtrl._ApplyProduceFilterOption = HL.Method(HL.Opt(HL.Table)) << function(self, tagInfoList)
    if not tagInfoList or not next(tagInfoList) then
        self.m_filteredEquipPackDataList = self.m_equipPackDataList
    else
        self.m_filteredEquipPackDataList = {}
        for _, packData in ipairs(self.m_equipPackDataList) do
            local equipList = {}
            for _, itemInfo in ipairs(packData.equipList) do
                if FilterUtils.checkIfPassFilter(itemInfo, tagInfoList) then
                    table.insert(equipList, itemInfo)
                end
            end
            if #equipList > 0 then
                
                local newPackData = {
                    equipPackData = packData.equipPackData,
                    sortId = packData.equipPackData.sortId,
                    isExpanded = true,
                    equipList = equipList,
                }
                table.insert(self.m_filteredEquipPackDataList, newPackData)
            end
        end
    end
end




EquipTechCtrl._GetProduceFilterResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tagInfoList)
    local count = 0
    for _, packData in ipairs(self.m_equipPackDataList) do
        for _, itemInfo in ipairs(packData.equipList) do
            if FilterUtils.checkIfPassFilter(itemInfo, tagInfoList) then
                count = count + 1
            end
        end
    end
    return count
end



EquipTechCtrl._RefreshProduceList = HL.Method() << function(self)
    local count = #self.m_filteredEquipPackDataList
    local jumpIndex
    if self.m_jumpFormulaId then
        for i, packData in pairs(self.m_filteredEquipPackDataList) do
            for j, itemInfo in pairs(packData.equipList) do
                if itemInfo.equipFormulaData.formulaId == self.m_jumpFormulaId then
                    jumpIndex = i
                    break
                end
            end
        end
    end

    if jumpIndex then
        self.view.leftBarProduce.itemList:UpdateCount(count, CSIndex(jumpIndex), true, false, true)
    else
        self.view.leftBarProduce.itemList:UpdateCount(count, true, true)
    end

    self.view.leftBarProduce.emptyNode.gameObject:SetActive(count == 0)
    if self.m_playAnimProduceList then
        self.view.leftBarProduce.animationWrapper:ClearTween(false)
        self.view.leftBarProduce.animationWrapper:PlayInAnimation()
    end

    if self.m_jumpFormulaCell then
        local scrollRect = self.view.leftBarProduce.itemList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        scrollRect:AutoScrollToRectTransform(self.m_jumpFormulaCell.transform, true)
        if DeviceInfo.usingController then
            InputManagerInst.controllerNaviManager:SetTarget(self.m_jumpFormulaCell.view.button)
        else
            self.m_jumpFormulaCell.view.button.onClick:Invoke()
        end
        self.view.rightProduceNode.emptyNode.gameObject:SetActive(false)
        self.m_jumpFormulaCell = nil
    elseif count > 0 then
        local firstPackCell = self.m_getEquipPackCell(self.view.leftBarProduce.itemList:Get(0))
        local firstEquipCell = firstPackCell.itemCache:Get(1)
        if DeviceInfo.usingController then
            InputManagerInst.controllerNaviManager:SetTarget(firstEquipCell.view.button)
        else
            firstEquipCell.view.button.onClick:Invoke()
        end
        self.view.rightProduceNode.emptyNode.gameObject:SetActive(false)
    end

    self.m_playAnimProduceList = false
end






EquipTechCtrl._UpdateProducePackCell = HL.Method(HL.Table, HL.Table, HL.Number) << function(self, cell, packData, packCsIndex)
    cell.nameText.text = packData.equipPackData.name
    local hasIcon = not string.isEmpty(packData.equipPackData.iconId)
    cell.decoImg.gameObject:SetActive(hasIcon)
    if hasIcon then
        cell.decoImg:LoadSprite(UIConst.UI_SPRITE_EQUIPMENT_LOGO_BIG_WHITE, packData.equipPackData.iconId)
    end
    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn ~= packData.isExpanded then
            packData.isExpanded = isOn
            self.view.leftBarProduce.itemList:Toggle(packCsIndex)
        end
    end)
    cell.toggle.isOn = packData.isExpanded
    local packId = packData.equipPackData.packId
    cell.redDot:InitRedDot("EquipPack", packId, function(redDot, active, rdType)
        redDot.view.allNew.gameObject:SetActive(active and rdType == EquipTechConst.EQUIP_PRODUCE_PACK_RED_DOT_TYPE.AllNew)
        redDot.view.partialNew.gameObject:SetActive(active and rdType == EquipTechConst.EQUIP_PRODUCE_PACK_RED_DOT_TYPE.PartialNew)
        self:_RefreshProducePackRedDot(packId, active)
    end, self.view.leftBarProduce.redDotScrollRect)

    if cell.itemCache == nil then
        cell.itemCache = UIUtils.genCellCache(cell.itemBigBlack)
    end
    cell.itemCache:Refresh(#packData.equipList, function(itemCell, index)
        local itemInfo = packData.equipList[index]
        self:_UpdateProduceEquipCell(itemInfo, itemCell)
    end)
end





EquipTechCtrl._UpdateProduceEquipCell = HL.Method(HL.Table, HL.Userdata) << function(self, itemInfo, itemCell)
    itemCell.view.gameObject.name = itemInfo.id
    itemCell:InitItem({ id = itemInfo.id} , function()
        self:_OnProduceItemClicked(itemCell, itemInfo, true)
    end)
    itemCell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
    if DeviceInfo.usingController then
        itemCell:SetEnableHoverTips(false)
    end
    local isSelected = self.m_selectedProduceItemInfo == itemInfo
    itemCell:SetSelected(isSelected)
    itemCell.redDot = itemCell.view.redDot
    itemCell:UpdateRedDot("EquipFormula", itemInfo.equipFormulaData.formulaId)
    itemCell.view.disableMark.gameObject:SetActive(not itemInfo.isUnlocked)
    if isSelected then
        self.m_selectedProduceItemCell = itemCell
    end

    local formulaId = itemInfo.equipFormulaData.formulaId
    if self.m_equipTechSystem:IsFormulaUnread(formulaId) then
        self.m_readFormulas = self.m_readFormulas or {}
        self.m_readFormulas[formulaId] = true
    end
    if itemInfo.equipFormulaData.isNew and not self.m_equipTechSystem:IsNewVersionFormulaRead(formulaId) then
        self.m_readNewVersionFormulas = self.m_readNewVersionFormulas or {}
        self.m_readNewVersionFormulas[formulaId] = true
    end
    if not string.isEmpty(self.m_jumpFormulaId) and self.m_jumpFormulaId == formulaId then
        self.m_jumpFormulaCell = itemCell
    end
end






EquipTechCtrl._OnProduceItemClicked = HL.Method(HL.Userdata, HL.Table, HL.Opt(HL.Boolean)) << function(self, itemCell, itemInfo, playAnim)
    if self.m_selectedProduceItemInfo == itemInfo then
        return
    end
    self.m_selectedProduceItemInfo = itemInfo

    if self.m_selectedProduceItemCell then
        self.m_selectedProduceItemCell:SetSelected(false)
    end
    self.m_selectedProduceItemCell = itemCell
    self.m_selectedProduceItemCell:SetSelected(true)

    local formulaId = itemInfo.equipFormulaData.formulaId
    if self.m_equipTechSystem:IsFormulaUnread(formulaId) then
        self.m_equipTechSystem:SetFormulaRead({ formulaId })
    end
    if itemInfo.equipFormulaData.isNew and not self.m_equipTechSystem:IsNewVersionFormulaRead(formulaId) then
        self.m_equipTechSystem:SetNewVersionFormulaRead({ formulaId })
    end

    if playAnim and not self.m_isInitClickProduceEquip then
        self.view.middleBar.produceContent.animationWrapper:ClearTween(false)
        self.view.middleBar.produceContent.animationWrapper:PlayOutAnimation(function()
            self:_RefreshProduceEquipInfo(itemInfo)
            self.view.middleBar.produceContent.animationWrapper:PlayInAnimation()
            self.view.rightProduceNode.animationWrapper:ClearTween(false)
            self.view.rightProduceNode.animationWrapper:Play("equiptech_content_right_switch")
            self.view.middleBar.centerItem.animationWrapper:ClearTween(false)
            self.view.middleBar.centerItem.animationWrapper:PlayInAnimation()
        end)
        if not self.m_playAnimProduceList then
            AudioAdapter.PostEvent("Au_UI_Toast_SelectEquipMotion")
        end
    else
        self:_RefreshProduceEquipInfo(itemInfo)
    end
    self.m_isInitClickProduceEquip = false
end



EquipTechCtrl._ClearProduceEquipSelection = HL.Method() << function(self)
    if self.m_selectedProduceItemCell then
        self.m_selectedProduceItemCell:SetSelected(false)
        self.m_selectedProduceItemCell = nil
    end
    self:_RefreshProduceEquipInfo(nil)
end




EquipTechCtrl._RefreshProduceEquipInfo = HL.Method(HL.Table) << function(self, itemInfo)
    self.m_selectedProduceItemInfo = itemInfo
    local isEmpty = itemInfo == nil
    self.view.middleBar.centerItem.gameObject:SetActive(not isEmpty)
    self.view.middleBar.produceContent.equipInfo.gameObject:SetActive(not isEmpty)
    self.view.middleBar.produceContent.formulaNode.gameObject:SetActive(not isEmpty)
    self.view.rightProduceNode.emptyNode.gameObject:SetActive(isEmpty)
    self.view.rightProduceNode.equipDetails.gameObject:SetActive(not isEmpty)
    self.view.rightProduceNode.bottomNode.gameObject:SetActive(not isEmpty)
    if isEmpty then
        return
    end

    self.view.middleBar.centerItem.imgEquip:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, itemInfo.data.iconId)
    self.view.middleBar.centerItem.commonStorageNodeNew:InitStorageNode((Utils.getItemCount(itemInfo.id, true, true)))
    self.view.middleBar.produceContent.equipInfo:InitEquipTechEquipInfo(itemInfo.id)
    self.view.middleBar.produceContent.formulaNode.emptyState.gameObject:SetActive(not itemInfo.isUnlocked)
    local isCostEnough = true
    if not self.m_costItemCellCache then
        self.m_costItemCellCache = UIUtils.genCellCache(self.view.middleBar.produceContent.formulaNode.costItemCell)
    end
    local costItemCount = itemInfo.isUnlocked and #itemInfo.equipFormulaData.costItemId or 0
    self.m_costItemCellCache:Refresh(costItemCount, function(cell, luaIndex)
        local csIndex = CSIndex(luaIndex)
        local costItemId = itemInfo.equipFormulaData.costItemId[csIndex]
        local costItemNum = itemInfo.equipFormulaData.costItemNum[csIndex]
        cell.gameObject.name = costItemId
        cell.item:InitItem({ id = costItemId, count = costItemNum }, true)
        cell.item:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
        if DeviceInfo.usingController then
            cell.item:SetEnableHoverTips(false)
        end
        local ownItemNum = Utils.getItemCount(costItemId, true, true)
        local isLack = ownItemNum < costItemNum
        cell.item:UpdateCountSimple(costItemNum, isLack)
        cell.ownCountTxt.text = UIUtils.setCountColor(tostring(ownItemNum), isLack)
        if isLack then
            isCostEnough = false
        end
    end)
    self.view.middleBar.produceContent.formulaNode.naviGroup.enabled = itemInfo.isUnlocked
    self.view.middleBar.produceContent.formulaNode.controllerFocusHintNode.gameObject:SetActive(itemInfo.isUnlocked)

    self.view.rightProduceNode.equipDetails.weaponAttributeNode:InitEquipAttributeNodeByTemplateId(itemInfo.id)
    self.view.rightProduceNode.equipDetails.equipSuitNode:InitEquipSuitNode(itemInfo.id)

    local bottomNodeView = self.view.rightProduceNode.bottomNode
    bottomNodeView.gameObject:SetAllChildrenActiveIfNecessary(false)
    if itemInfo.isUnlocked then
        if isCostEnough then
            bottomNodeView.btnMake.gameObject:SetActive(true)
        else
            bottomNodeView.shortageTip.gameObject:SetActive(true)
        end
    else
        if itemInfo.equipFormulaData.unlockType == GEnums.EquipFormulaUnlockType.AdventureLevel then
            bottomNodeView.levelTip.gameObject:SetActive(true)
            bottomNodeView.levelTip.txtTargetLv.text = string.format(Language.LUA_EQUIP_PRODUCE_ADVENTURE_LEVEL_LOCKED_FORMAT,
                itemInfo.equipFormulaData.unlockValue)
            bottomNodeView.levelTip.txtCurrentLv.text = string.format(Language.LUA_EQUIP_PRODUCE_ADVENTURE_LEVEL_FORMAT,
                GameInstance.player.adventure.adventureLevelData.lv)
        elseif GO_TO_TEXT_KEY[itemInfo.equipFormulaData.unlockType] then
            bottomNodeView.gotoNode.textName.text = Language[GO_TO_TEXT_KEY[itemInfo.equipFormulaData.unlockType]]
            bottomNodeView.gotoNode.gameObject:SetActive(true)
        end
    end
end




EquipTechCtrl._OnEquipProduce = HL.Method(HL.Table) << function(self, args)
    local formulaId, equipInstId = unpack(args)
    
    local equipFormulaData = Tables.equipFormulaTable[formulaId]
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        title = Language.LUA_EQUIP_PRODUCE_SUCCESS_TITLE,
        items = { { id = equipFormulaData.outcomeEquipId, count = 1 } },
    })
    self:_RefreshProduceEquipInfo(self.m_selectedProduceItemInfo)
end




EquipTechCtrl._OnItemChanged = HL.Method(HL.Table) << function(self, args)
    if self.m_selectedProduceItemInfo then
        self:_RefreshProduceEquipInfo(self.m_selectedProduceItemInfo)
    end
    if self.view.stateController.currentStateName == STATE_NAME.ENHANCE_MATERIAL then
        self:_RefreshEnhanceCostItem()
    end
end




EquipTechCtrl._GetEquipPackRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, index)
    local luaIndex = LuaIndex(index)
    if luaIndex < 1 or luaIndex > #self.m_filteredEquipPackDataList then
        return 0
    end
    local packData = self.m_filteredEquipPackDataList[luaIndex]
    if not packData then
        return 0
    end
    local hasRedDot, redDotType = RedDotManager:GetRedDotState("EquipPack", packData.equipPackData.packId)
    if hasRedDot then
        if redDotType == UIConst.RED_DOT_TYPE.Normal then
            return redDotType
        else
            return UIConst.RED_DOT_TYPE.New
        end
    else
        return 0
    end
end






EquipTechCtrl.m_isEquipSlotTabInited = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_partType = HL.Field(HL.Any)


EquipTechCtrl.m_selectedEnhanceEquipItemInfo = HL.Field(HL.Table)


EquipTechCtrl.m_selectedEnhanceEquipInstId = HL.Field(HL.Number) << 0


EquipTechCtrl.m_selectedAttrShowInfoList = HL.Field(HL.Table)


EquipTechCtrl.m_enhanceAttrCellCache = HL.Field(HL.Forward("UIListCache"))


EquipTechCtrl.m_selectedAttrShowInfoIndex = HL.Field(HL.Number) << 0


EquipTechCtrl.m_enhanceTargetTypeCellCache = HL.Field(HL.Forward("UIListCache"))


EquipTechCtrl.m_firstCanEnhancedAttrCell = HL.Field(HL.Table)



EquipTechCtrl._EnterEnhanceTarget = HL.Method() << function(self)
    self:_ClearProduceEquipSelection()
    self.m_selectedEnhanceEquipInstId = 0
    self:_SendFormulaRead()
    self.view.stateController:SetState(STATE_NAME.ENHANCE_TARGET)
    self.view.leftBarEnhance.layoutElement.ignoreLayout = false

    self.view.middleBar.centerItem.btnExplain.gameObject:SetActive(true)

    self:_InitEquipSlotTab()
    local firstSlotTabToggle = self.m_enhanceTargetTypeCellCache:GetItem(1).toggle
    if firstSlotTabToggle.isOn then
        self.m_partType = EQUIP_SLOT_TAB_CONFIG[1].partType
        self:_RefreshEnhanceTargetList()
    else
        firstSlotTabToggle.isOn = true
    end
end



EquipTechCtrl._InitEquipSlotTab = HL.Method() << function(self)
    if self.m_isEquipSlotTabInited then
        return
    end

    local tabCellCache = UIUtils.genCellCache(self.view.leftBarEnhance.typesNode.typeCell)
    tabCellCache:Refresh(#EQUIP_SLOT_TAB_CONFIG, function(cell, index)
        local config = EQUIP_SLOT_TAB_CONFIG[index]
        if config.partType then
            local iconName = UIConst.EQUIP_TYPE_TO_ICON_NAME[config.partType]
            cell.dimIcon:LoadSprite(UIConst.UI_SPRITE_EQUIP, iconName)
            cell.lightIcon:LoadSprite(UIConst.UI_SPRITE_EQUIP, iconName)
        end
        cell.toggle.onValueChanged:RemoveAllListeners()
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                self.m_partType = config.partType
                self:_RefreshEnhanceTargetList()
            end
        end)
    end)
    self.m_enhanceTargetTypeCellCache = tabCellCache
    self.m_isEquipSlotTabInited = true
end



EquipTechCtrl._RefreshEnhanceTargetList = HL.Method() << function(self)
    local jumpEquipId = self.m_jumpEquipId
    self.m_jumpEquipId = ""
    
    local itemListArgs = {
        listType = UIConst.COMMON_ITEM_LIST_TYPE.EQUIP_TECH_EQUIP_ENHANCE,
        onClickItem = function(args)
            self.m_selectedEnhanceEquipItemInfo = args.itemInfo
            if args.realClick then
                self.view.topNode.animationWrapper:ClearTween(false)
                self.view.topNode.animationWrapper:PlayOutAnimation(function()
                    self.view.topNode.animationWrapper:PlayInAnimation()
                end)
                self.view.rightBarEnhanceAttr.animationWrapper:ClearTween(false)
                self.view.rightBarEnhanceAttr.animationWrapper:PlayOutAnimation(function()
                    self:_RefreshEnhancedEquip()
                    self.view.rightBarEnhanceAttr.animationWrapper:PlayInAnimation()
                end)
            else
                self:_RefreshEnhancedEquip()
            end
        end,
        onFilterNone = function()
            self.m_selectedEnhanceEquipItemInfo = nil
            self:_RefreshEnhancedEquip()
        end,
        setItemSelected = function(cell, isSelected)
            cell.stateController:SetState(isSelected and "selected" or "normal")
        end,
        getItemBtn = function(cell)
            return cell.btn
        end,
        refreshItemAddOn = function(cell, itemInfo)
            cell.gameObject.name = "TargetCell" .. tostring(itemInfo.indexId)
            
            if itemInfo.id == jumpEquipId then
                cell.gameObject.name = itemInfo.id
            end
            cell.equipEnhanceLevelCellCache = cell.equipEnhanceLevelCellCache or UIUtils.genCellCache(cell.equipEnhanceLevelNode)
            cell.equipEnhanceLevelCellCache:Refresh(#itemInfo.equipData.displayAttrModifiers, function(enhanceLevelCell, index)
                local attrMod = itemInfo.equipData.displayAttrModifiers[CSIndex(index)]
                enhanceLevelCell:InitEquipEnhanceLevelNode({
                    equipInstId = itemInfo.instId,
                    attrIndex = attrMod.enhancedAttrIndex,
                })
            end)

            cell.equipItem:InitEquipItem({
                equipInstId = itemInfo.instId,
                noInitItem = true,
                itemInteractable = false,
            })
        end,
        filter_equipType = self.m_partType,
        defaultSelectedIndex = 1,
        selectedIndexId = self.m_selectedEnhanceEquipInstId,
        selectedItemId = jumpEquipId,
    }
    self.view.leftBarEnhance.commonItemList:InitCommonItemList(itemListArgs)
end



EquipTechCtrl._RefreshEnhancedEquip = HL.Method() << function(self)
    local isEmpty = self.m_selectedEnhanceEquipItemInfo == nil
    self.m_selectedEnhanceEquipInstId = isEmpty and 0 or self.m_selectedEnhanceEquipItemInfo.instId
    self.view.middleBar.centerItem.gameObject:SetActive(true)
    self.view.middleBar.centerItem.emptyState.gameObject:SetActive(isEmpty)
    self.view.middleBar.centerItem.imgEquip.gameObject:SetActive(not isEmpty)
    local showBtnExplain = not isEmpty and (self.view.stateController.currentStateName == STATE_NAME.ENHANCE_TARGET or not DeviceInfo.usingController)
    self.view.middleBar.centerItem.btnExplain.gameObject:SetActive(showBtnExplain)
    self.view.topNode.gameObject:SetActive(not isEmpty)
    self.view.rightBarEnhanceAttr.emptyNode.gameObject:SetActive(isEmpty)
    self.view.rightBarEnhanceAttr.attrNode.gameObject:SetActive(not isEmpty)
    self.view.middleBar.targetContent.equipInfo.gameObject:SetActive(not isEmpty)
    self.view.middleBar.targetContent.txtEquip.gameObject:SetActive(not isEmpty)
    if isEmpty then
        return
    end

    local equipInstData = EquipTechUtils.getEquipInstData(self.m_selectedEnhanceEquipInstId)

    local _, itemData = Tables.itemTable:TryGetValue(self.m_selectedEnhanceEquipItemInfo.id)
    if itemData then
        self.view.middleBar.centerItem.imgEquip:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, itemData.iconId)
    end
    self.view.middleBar.targetContent.equipInfo:InitEquipTechEquipInfo(self.m_selectedEnhanceEquipItemInfo.id)
    self.view.middleBar.materialContent.equipInfo:InitEquipTechEquipInfo(self.m_selectedEnhanceEquipItemInfo.id)
    self.view.middleBar.centerItem.btnExplain.onClick:RemoveAllListeners()
    self.view.middleBar.centerItem.btnExplain.onClick:AddListener(function()
        self:_SetCenterEquipSelected(true)
        Notify(MessageConst.SHOW_ITEM_TIPS, {
            itemId = self.m_selectedEnhanceEquipItemInfo.id,
            instId = self.m_selectedEnhanceEquipInstId,
            transform = self.view.middleBar.centerItem.imgEquip.transform,
            posType = UIConst.UI_TIPS_POS_TYPE.RightMid,
            onClose = function()
                if self.m_isClosed then
                    return
                end
                self:_SetCenterEquipSelected(false)
            end
        })
    end)

    local _, primaryAttrs, nonPrimaryAttrs = CharInfoUtils.getEquipShowAttributes(self.m_selectedEnhanceEquipInstId)
    self.m_selectedAttrShowInfoList = lume.concat(primaryAttrs, nonPrimaryAttrs)
    local attrCount = self.m_selectedAttrShowInfoList and #self.m_selectedAttrShowInfoList or 0
    self.m_firstCanEnhancedAttrCell = nil
    self.m_enhanceAttrCellCache = self.m_enhanceAttrCellCache or UIUtils.genCellCache(self.view.rightBarEnhanceAttr.enhanceAttrCell)
    self.m_enhanceAttrCellCache:Refresh(attrCount, function(cell, luaIndex)
        cell.gameObject.name = tostring(luaIndex)
        local attrShowInfo = self.m_selectedAttrShowInfoList[luaIndex]
        local isEnhanced = equipInstData:IsAttrEnhanced(attrShowInfo.enhancedAttrIndex)
        local isMaxEnhanced = equipInstData:IsAttrMaxEnhanced(attrShowInfo.enhancedAttrIndex)
        cell.stateController:SetState(isMaxEnhanced and "max" or "normal")
        cell.txtName.text = attrShowInfo.showName
        cell.txtValue.text = EquipTechUtils.getAttrShowValueText(attrShowInfo)
        local color = isEnhanced and self.view.config.COLOR_ENHANCED or self.view.config.COLOR_NORMAL
        cell.txtName.color = color
        cell.txtValue.color = color
        cell.equipEnhanceLevelNode:InitEquipEnhanceLevelNode({
            equipInstId = self.m_selectedEnhanceEquipInstId,
            attrIndex = attrShowInfo.enhancedAttrIndex,
        })
        cell.btnEnhance.onClick:RemoveAllListeners()
        if not isMaxEnhanced then
            cell.btnEnhance.onClick:AddListener(function()
                self.m_selectedAttrShowInfoIndex = luaIndex
                self.m_lastEnhanceAttrCell = cell
                self:_EnterEnhanceMaterial()
            end)
            if not self.m_firstCanEnhancedAttrCell then
                self.m_firstCanEnhancedAttrCell = cell
            end
        end
    end)

    self.view.topNode.txtCount.text = string.format("%d/%d", equipInstData:GetEnhanceLevel(),
        attrCount * Tables.equipConst.maxAttrEnhanceLevel)
end




EquipTechCtrl._SetCenterEquipSelected = HL.Method(HL.Boolean) << function(self, isSelected)
    self.view.middleBar.centerItem.btnExplain.gameObject:SetActive(not isSelected and
        (self.view.stateController.currentStateName == STATE_NAME.ENHANCE_TARGET or
            self.view.stateController.currentStateName == STATE_NAME.ENHANCE_MATERIAL))
    self.view.middleBar.centerItem.selectedBG.gameObject:SetActive(isSelected)
end






EquipTechCtrl.m_enhanceMaterialInstId = HL.Field(HL.Number) << -1


EquipTechCtrl.m_enhanceMaterialItemInfo = HL.Field(HL.Table)


EquipTechCtrl.m_nextLevelAttrShowValue = HL.Field(HL.String) << ""


EquipTechCtrl.m_isCostItemCountEnough = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_lastEnhanceAttrCell = HL.Field(HL.Table)


EquipTechCtrl.m_isEnhanceMaterialItemTipsMode = HL.Field(HL.Boolean) << false


EquipTechCtrl.m_closeEnhanceMaterialItemTipsBindingId = HL.Field(HL.Number) << 0



EquipTechCtrl._BackToEnhanceTarget = HL.Method() << function(self)
    self.view.stateController:SetState(STATE_NAME.ENHANCE_TARGET)
    self.view.leftBarEnhance.layoutElement.ignoreLayout = false
    self.view.rightBarEnhanceAttr.naviGroup:ManuallyFocus()
    if self.m_lastEnhanceAttrCell then
        local naviTarget
        if self.m_lastEnhanceAttrCell.btnEnhance.gameObject.activeInHierarchy then
            naviTarget = self.m_lastEnhanceAttrCell.btnEnhance
        else
            naviTarget = self.m_lastEnhanceAttrCell.accomplishNode
        end
        UIUtils.setAsNaviTarget(naviTarget)
        self.m_lastEnhanceAttrCell = nil
    end
end



EquipTechCtrl._EnterEnhanceMaterial = HL.Method() << function(self)
    self.view.stateController:SetState(STATE_NAME.ENHANCE_MATERIAL)
    self.view.leftBarEnhance.gameObject:SetActive(true)
    self.view.leftBarEnhance.layoutElement.ignoreLayout = true
    self.view.leftBarEnhance.animationWrapper:SampleToInAnimationEnd()
    self:_RefreshEnhanceMaterial(nil)
    self:_RefreshEnhanceMaterialList()
    self.view.middleBar.bottomNode.btnMake.onClick:RemoveAllListeners()
    self.view.middleBar.bottomNode.btnMake.onClick:AddListener(function()
        self:_OnEnhanceClicked()
    end)
    self.view.middleBar.centerItem.btnExplain.gameObject:SetActive(not DeviceInfo.usingController)
    self.view.middleBar.centerBg:PlayInAnimation()
end



EquipTechCtrl._RefreshEnhanceMaterialList = HL.Method() << function(self)
    local jumpEquipId = self.m_jumpMaterialEquipId
    self.m_jumpMaterialEquipId = ""

    local _, primaryAttrs, nonPrimaryAttrs = CharInfoUtils.getEquipTemplateShowAttributes(self.m_selectedEnhanceEquipItemInfo.id)
    local selectedTemplateAttrShowInfoList = lume.concat(primaryAttrs, nonPrimaryAttrs)

    
    local itemListArgs = {
        listType = UIConst.COMMON_ITEM_LIST_TYPE.EQUIP_TECH_EQUIP_ENHANCE_MATERIALS,
        onClickItem = function(args)
            self:_RefreshEnhanceMaterial(args.itemInfo)
        end,
        onFilterNone = function()
            self:_RefreshEnhanceMaterial(nil)
        end,
        setItemSelected = function(cell, isSelected)
            cell.stateController:SetState(isSelected and "selected" or "normal")
        end,
        getItemBtn = function(cell)
            return cell.btn
        end,
        
        refreshItemAddOn = function(cell, itemInfo)
            cell.gameObject.name = "MaterialCell" .. tostring(itemInfo.indexId)
            
            if itemInfo.id == jumpEquipId and itemInfo.equipInstData.equippedCharServerId == 0 then
                cell.gameObject.name = itemInfo.id
            end
            cell.equipItem:InitEquipItem({
                equipInstId = itemInfo.instId,
                noInitItem = true,
                itemInteractable = false,
            })
            cell.btnSymbol.onClick:RemoveAllListeners()
            cell.btnSymbol.onClick:AddListener(function()
                if DeviceInfo.usingController then
                    self.m_isEnhanceMaterialItemTipsMode = true
                    self.m_closeEnhanceMaterialItemTipsBindingId = self:BindInputPlayerAction(
                        "common_cancel_no_hint", function()
                            self:_CloseEnhanceMaterialItemTips()
                        end, self.view.selectMaterials.itemListInputGroup.groupId)
                    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                        panelId = PANEL_ID,
                        isGroup = true,
                        id = self.view.selectMaterials.itemListInputGroup.groupId,
                        rectTransform = self.view.selectMaterials.commonItemList.rectTransform,
                        noHighlight = true,
                    })
                end
                self:_ShowEnhanceMaterialItemTips(itemInfo)
            end)
            cell.txtNormal.gameObject:SetActive(itemInfo.equipEnhanceSuccessProb == EquipTechConst.EEquipEnhanceSuccessProb.Normal)
            cell.txtHigh.gameObject:SetActive(itemInfo.equipEnhanceSuccessProb == EquipTechConst.EEquipEnhanceSuccessProb.High)
            if DeviceInfo.usingController then
                InputManagerInst:ToggleGroup(cell.btnSymbol.groupId, false)
            end
        end,
        onItemIsNaviTargetChanged = function(cell, itemInfo, isTarget)
            InputManagerInst:ToggleGroup(cell.btnSymbol.groupId, isTarget)
            if isTarget and self.m_isEnhanceMaterialItemTipsMode then
                self:_ShowEnhanceMaterialItemTips(itemInfo)
            end
        end,
        filter_equipType = self.m_selectedEnhanceEquipItemInfo.partType,
        attrShowInfo = selectedTemplateAttrShowInfoList[self.m_selectedAttrShowInfoIndex],
        equipInstId = self.m_selectedEnhanceEquipInstId,
        defaultSelectedIndex = DeviceInfo.usingController and 1 or nil,
        selectedItemId = jumpEquipId,
        keepSelectionOnSort = true,
    }
    self.view.selectMaterials.commonItemList:InitCommonItemList(itemListArgs)
end




EquipTechCtrl._ShowEnhanceMaterialItemTips = HL.Method(HL.Table) << function(self, itemInfo)
    Notify(MessageConst.SHOW_ITEM_TIPS, {
        itemId = itemInfo.id,
        instId = itemInfo.instId,
        transform = self.view.selectMaterials.itemTipsPos,
        posType = UIConst.UI_TIPS_POS_TYPE.RightTop,
        isSideTips = DeviceInfo.usingController,
    })
end



EquipTechCtrl._CloseEnhanceMaterialItemTips = HL.Method() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    self.m_isEnhanceMaterialItemTipsMode = false
    self:DeleteInputBinding(self.m_closeEnhanceMaterialItemTipsBindingId)
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.selectMaterials.itemListInputGroup.groupId)
end




EquipTechCtrl._RefreshEnhanceMaterial = HL.Method(HL.Table) << function(self, itemInfo)
    self.m_enhanceMaterialItemInfo = itemInfo
    local isEmpty = itemInfo == nil
    self.m_enhanceMaterialInstId = isEmpty and 0 or itemInfo.instId
    local attrShowInfo = self.m_selectedAttrShowInfoList[self.m_selectedAttrShowInfoIndex]
    self.view.selectMaterials.selectedEquip:InitEquipItem({
        equipInstId = self.m_enhanceMaterialInstId,
        itemInteractable = true,
    })
    self.view.middleBar.enhanceAttrNode.txtName.text = attrShowInfo.showName
    self.view.middleBar.enhanceAttrNode.equipEnhanceLevelNode:InitEquipEnhanceLevelNode({
        equipInstId = self.m_selectedEnhanceEquipInstId,
        attrIndex = attrShowInfo.enhancedAttrIndex,
        showNextLevel = not isEmpty,
    })
    self.view.middleBar.enhanceAttrNode.txtBefore.text = EquipTechUtils.getAttrShowValueText(attrShowInfo)

    self.view.middleBar.enhanceAttrNode.imgArrow.gameObject:SetActive(not isEmpty)
    self.view.middleBar.enhanceAttrNode.txtAfter.gameObject:SetActive(not isEmpty)
    self.m_nextLevelAttrShowValue = EquipTechUtils.getAttrShowValueText(attrShowInfo, true, self.m_selectedEnhanceEquipInstId)
    self.view.middleBar.enhanceAttrNode.txtAfter.text = self.m_nextLevelAttrShowValue

    
    local successRationNode = self.view.middleBar.enhanceAttrNode.successRationNode
    local enhanceLevel = self.m_selectedEnhanceEquipItemInfo.equipInstData:GetAttrEnhanceLevel(attrShowInfo.enhancedAttrIndex)
    local nextEnhanceLevel = enhanceLevel + 1
    local canEnhance = enhanceLevel < Tables.equipConst.maxAttrEnhanceLevel
    successRationNode.gameObject:SetActive(canEnhance)
    if canEnhance then
        successRationNode.txtHigh.gameObject:SetActive(not isEmpty and itemInfo.equipEnhanceSuccessProb == EquipTechConst.EEquipEnhanceSuccessProb.High)
        successRationNode.txtNormal.gameObject:SetActive(not isEmpty and itemInfo.equipEnhanceSuccessProb == EquipTechConst.EEquipEnhanceSuccessProb.Normal)
        successRationNode.txtEmpty.gameObject:SetActive(isEmpty)

        local failedCount = self.m_selectedEnhanceEquipItemInfo.equipInstData:GetEnhanceFailedTimes(attrShowInfo.enhancedAttrIndex, nextEnhanceLevel)
        local maxFailedCount
        if not string.isEmpty(attrShowInfo.enhanceGuaranteeTimesRuleId) then
            local _, ruleData = Tables.equipEnhanceGuaranteeTimesRuleTable:TryGetValue(attrShowInfo.enhanceGuaranteeTimesRuleId)
            if ruleData then
                maxFailedCount = ruleData[string.format("GuaranteeTimes%d", nextEnhanceLevel)]
            end
        end
        if maxFailedCount then
            local isMustEnhance = failedCount >= maxFailedCount
            successRationNode.successNode.gameObject:SetActive(isMustEnhance)
            successRationNode.numberTxt.text = string.format("%d/%d", failedCount, maxFailedCount)
            successRationNode.sliderImg.fillAmount = failedCount / maxFailedCount
            if not isEmpty and isMustEnhance then
                AudioAdapter.PostEvent("Au_UI_Event_EquipForgMS")
            end
        else
            logger.error("EquipTechCtrl._RefreshEnhanceMaterial: maxFailedCount not found for ruleId: " ..
                tostring(attrShowInfo.enhanceGuaranteeTimesRuleId) .. ", nextEnhanceLevel: " .. tostring(nextEnhanceLevel))
        end
    end

    self.view.middleBar.bottomNode.btnMake.gameObject:SetActive(not isEmpty)
    self.view.middleBar.bottomNode.emptyState.gameObject:SetActive(isEmpty)
    self:_RefreshEnhanceCostItem()
end



EquipTechCtrl._RefreshEnhanceCostItem = HL.Method() << function(self)
    self.view.middleBar.bottomNode.btnIcon.onClick:RemoveAllListeners()
    self.m_isCostItemCountEnough = false
    local itemCount = 0
    local costItemCount = 0
    local _, costData = Tables.equipEnhanceCostTable:TryGetValue(self.m_selectedEnhanceEquipItemInfo.equipData.domainId)
    if costData then
        local _, costItemData = Tables.itemTable:TryGetValue(costData.consumeItemId)
        if costItemData then
            itemCount = Utils.getItemCount(costItemData.id)
            costItemCount = costData.consumeItemCnt
            self.m_isCostItemCountEnough = itemCount >= costItemCount
            self.view.middleBar.bottomNode.imgIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, costItemData.iconId)
            self.view.middleBar.bottomNode.btnIcon.onClick:AddListener(function()
                Notify(MessageConst.SHOW_ITEM_TIPS, {
                    itemId = costItemData.id,
                    transform = self.view.middleBar.bottomNode.itemTipsPos,
                    posType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                    isSideTips = DeviceInfo.usingController,
                })
            end)
        else
            logger.error("EquipTechCtrl._RefreshEnhanceMaterial: costItemData not found for itemId: " .. costData.consumeItemId)
        end
    else
        logger.error("EquipTechCtrl._RefreshEnhanceMaterial: costData not found for domainId: " .. self.m_selectedEnhanceEquipItemInfo.equipData.domainId)
    end
    self.view.middleBar.bottomNode.textExpend.color = isEmpty and self.view.config.COST_EMPTY_COLOR or self.view.config.COST_ENOUGH_COLOR
    self.view.middleBar.bottomNode.txtCost.color = isEmpty and self.view.config.COST_EMPTY_COLOR or
        (self.m_isCostItemCountEnough and self.view.config.COST_ENOUGH_COLOR or self.view.config.COST_NOT_ENOUGH_COLOR)
    self.view.middleBar.bottomNode.txtCost.text = isEmpty and
        string.format("--/%d", costItemCount) or string.format("%d/%d", itemCount, costItemCount)
end



EquipTechCtrl._OnEnhanceClicked = HL.Method() << function(self)
    if self.m_selectedEnhanceEquipInstId == 0 or self.m_enhanceMaterialInstId == 0 then
        return
    end

    if not self.m_isCostItemCountEnough then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_ENHANCE_MATERIAL_NOT_ENOUGH)
        return
    end

    
    local enhanceMaterialEquipInstData = CharInfoUtils.getEquipByInstId(self.m_enhanceMaterialInstId)
    local needConfirm = false
    local confirmContent = ""
    if enhanceMaterialEquipInstData:IsEnhanced() then
        confirmContent = Language.LUA_EQUIP_ENHANCE_MATERIAL_POPUP_TITLE
        needConfirm = true
    end
    if enhanceMaterialEquipInstData.equippedCharServerId > 0 then
        confirmContent = Language.LUA_EQUIP_ENHANCE_MATERIAL_EQUIPPED_POPUP_TITLE
        needConfirm = true
    end
    if needConfirm then
        Notify(MessageConst.SHOW_POP_UP, {
            content = confirmContent,
            equipInstId = self.m_enhanceMaterialInstId,
            onConfirm = function()
                self:_EnhanceEquip()
            end,
        })
    else
        self:_EnhanceEquip()
    end
end



EquipTechCtrl._EnhanceEquip = HL.Method() << function(self)
    local attrIndex = self.m_selectedAttrShowInfoList[self.m_selectedAttrShowInfoIndex].enhancedAttrIndex
    self.m_equipTechSystem:EnhanceEquip(self.m_selectedEnhanceEquipInstId, self.m_enhanceMaterialInstId, attrIndex)
end




EquipTechCtrl._OnEquipEnhance = HL.Method(HL.Table) << function(self, args)
    local equipInstId, enhancedAttrIndex = unpack(args)
    local attrShowInfo = self.m_selectedAttrShowInfoList[self.m_selectedAttrShowInfoIndex]
    if equipInstId ~= self.m_selectedEnhanceEquipInstId then
        return
    end

    
    local resultArgs = {
        isSuccessful = enhancedAttrIndex > 0,
        equipInstId = equipInstId,
        attrShowInfo = attrShowInfo,
        nextLevelAttrShowValue = self.m_nextLevelAttrShowValue,
        closeCallback = function()
            self:_RefreshEnhancedEquip()
            self:_RefreshEnhanceTargetList()
            self:_RefreshEnhanceMaterialList()
            if not DeviceInfo.usingController then
                self:_RefreshEnhanceMaterial(nil)
            end

            local equipInstData = EquipTechUtils.getEquipInstData(equipInstId)
            if equipInstData:IsAttrMaxEnhanced(attrShowInfo.enhancedAttrIndex) then
                self:_BackToEnhanceTarget()
            end
        end
    }
    UIManager:Open(PanelId.EquipEnhanceResult, resultArgs)
end







EquipTechCtrl.m_readNewVersionFormulas = HL.Field(HL.Table)


EquipTechCtrl.m_readFormulas = HL.Field(HL.Table)



EquipTechCtrl._SendFormulaRead = HL.Method() << function(self)
    if self.m_readNewVersionFormulas then
        local readFormulaIdList = {}
        for formulaId, _ in pairs(self.m_readNewVersionFormulas) do
            table.insert(readFormulaIdList, formulaId)
        end
        if #readFormulaIdList > 0 then
            self.m_equipTechSystem:SetNewVersionFormulaRead(readFormulaIdList)
        end
        self.m_readNewVersionFormulas = nil
    end

    if self.m_readFormulas then
        local readFormulaIdList = {}
        for formulaId, _ in pairs(self.m_readFormulas) do
            table.insert(readFormulaIdList, formulaId)
        end
        if #readFormulaIdList > 0 then
            self.m_equipTechSystem:SetFormulaRead(readFormulaIdList)
        end
        self.m_readFormulas = nil
    end
end







EquipTechCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.view.middleBar.produceContent.formulaNode.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.view.middleBar.produceContent.formulaNode.controllerFocusHintNode.gameObject:SetActive(not isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    self.view.rightBarEnhanceAttr.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.view.commonBg.tabInputGroup.enabled = not isFocused
        self.view.leftBarEnhance.inputGroup.enabled = not isFocused
    end)
    self.view.middleBar.bottomNode.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    self.view.rightBarEnhanceAttr.naviGroup.getDefaultSelectableFunc = function()
        if self.m_firstCanEnhancedAttrCell then
            return self.m_firstCanEnhancedAttrCell.btnEnhance
        end
        return nil
    end
    UIUtils.bindHyperlinkPopup(self, "EquipTech", self.view.inputGroup.groupId)
end



HL.Commit(EquipTechCtrl)
