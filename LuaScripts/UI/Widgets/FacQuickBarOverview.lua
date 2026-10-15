local QuickBarItemType = FacConst.QuickBarItemType

local FacQuickBarBase = require_ex("UI/Widgets/FacQuickBarBase")




FacQuickBarOverview = HL.Class("FacQuickBarOverview", FacQuickBarBase)

FacQuickBarOverview._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_QUICK_BAR_CHANGED, function()
        self:_OnQuickBarChanged()
    end)
    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function(...)
        self:_OnItemCountChanged(...)
    end)
    self:RegisterMessage(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, function(...)
        self:_OnToggleFacTopView(...)
    end)
    self:RegisterMessage(MessageConst.TOGGLE_HIDE_FAC_TOP_VIEW_RIGHT_SIDE_UI, function(...)
        self:_ToggleHideFacTopViewRightSideUi(...)
    end)
end

FacQuickBarOverview._OnInitFacQuickBar = HL.Override(HL.Table) << function(self, args)
    self.view.collapseBtn.onClick:RemoveAllListeners()
    self.view.collapseBtn.onClick:AddListener(function()
        self:Deactivate()
    end)
    self.view.expandBtn.onClick:RemoveAllListeners()
    self.view.expandBtn.onClick:AddListener(function()
        self:Activate()
    end)
    if DeviceInfo.usingController then
        self:GetUICtrl():BindInputPlayerAction("common_cancel", function()
            self:Deactivate()
        end, self.view.buildNode.groupId)
    end

    self.m_typeCells = self.m_typeCells or UIUtils.genCellCache(self.view.typeCell)

    self.m_getItemCell = self.m_getItemCell or UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:RemoveAllListeners()
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getItemCell(obj), LuaIndex(csIndex))
    end)
    self.view.scrollListScrollRect.onOverScrollEffect:RemoveAllListeners()
    self.view.scrollListScrollRect.onOverScrollEffect:AddListener(function(isNext)
        self:_OnOverScrollList(isNext)
    end)

    self:_InitFilters()

    self.view.beltNode.item:InitItem({ id = FacConst.BELT_ITEM_ID }, function()
        self:_OnClickBelt()
    end)
    self.view.beltNode.item:OpenLongPressTips()
    self.view.pipeNode.item:InitItem({ id = FacConst.PIPE_ITEM_ID }, function()
        self:_OnClickPipe()
    end)
    self.view.pipeNode.item:OpenLongPressTips()

    self.view.facQuickBarClearDropZone:InitFacQuickBarClearDropZone()
end

FacQuickBarOverview._OnEnable = HL.Override() << function(self)
    self.view.facQuickBarClearDropZone.gameObject:SetActive(false)
end

FacQuickBarOverview.RefreshFacQuickBar = HL.Override() << function(self)
    self:_RefreshTypeList()
    self:_RefreshRightSide()
end




FacQuickBarOverview._OnActivate = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    local fastMode = args and args.fastMode
    if fastMode then
        self.view.animationWrapper:SampleToInAnimationEnd()
    else
        self.view.animationWrapper:PlayInAnimation()
    end

    if DeviceInfo.usingController then
        
        Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
            panelId = self:GetUICtrl().panelId,
            isGroup = true,
            id = self.view.inputBindingGroupMonoTarget.groupId,
            rectTransform = self.view.buildNode.transform,
            noHighlight = true,
        })

        
        self.view.scrollList:SetTop(false)
        local firstCell = self.m_getItemCell(1)
        if firstCell then
            self:SetNaviTarget(firstCell.button)
        end
    end

    self.view.buildNode.enabled = true
end

FacQuickBarOverview._OnDeactivate = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    local fastMode = args and args.fastMode
    if fastMode then
        self.view.animationWrapper:SampleToOutAnimationEnd()
    else
        self.view.animationWrapper:PlayOutAnimation()
    end

    if DeviceInfo.usingController then
        
        Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.inputBindingGroupMonoTarget.groupId)
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.container)
    end

    self.view.buildNode.enabled = not DeviceInfo.usingController
end























FacQuickBarOverview.m_typeInfos = HL.Field(HL.Table) 

FacQuickBarOverview._InitTypeInfos = HL.Method() << function(self)
    local typeInfos = {}

    table.insert(typeInfos, self:_BuildCustomTypeInfo())
    table.insert(typeInfos, self:_BuildLogisticTypeInfo())

    local typeInfoMap = self:_BuildBuildingTypeInfoMap()
    local soilTypeInfo = typeInfoMap["soil"]
    typeInfoMap["soil"] = nil 

    for _, typeInfo in pairs(typeInfoMap) do
        table.insert(typeInfos, typeInfo)
    end

    table.sort(typeInfos, Utils.genSortFunction({ "priority" }))

    if soilTypeInfo then
        table.insert(typeInfos, soilTypeInfo)
        self.m_soilTypeIndex = #typeInfos
    else
        self.m_soilTypeIndex = nil
    end

    self.m_typeInfos = typeInfos
end


FacQuickBarOverview._CreateTypeInfo = HL.Method(HL.String, HL.Opt(HL.Boolean)).Return(HL.Table) << function(self, typeId, noFilter)
    local typeData = Tables.factoryQuickBarTypeTable:GetValue(typeId)
    local typeInfo = {
        data = typeData,
        priority = typeData.priority,
        showingItems = {},
    } 

    if noFilter then
        typeInfo.noFilter = true
    else
        typeInfo.allItems = {}
    end

    return typeInfo
end


FacQuickBarOverview._BuildCustomTypeInfo = HL.Method().Return(HL.Table) << function(self)
    local quickBarType = GEnums.FCQuickBarType.Inner
    local chapterInfo = GameInstance.player.remoteFactory.core:GetCurrentChapterInfo()
    local quickBarItems = chapterInfo:GetQuickBar(quickBarType) 

    local typeInfo = self:_CreateTypeInfo("custom", true)
    for _, itemId in pairs(quickBarItems) do
        local itemInfo = {
            itemId = itemId,
            isCustomQuickBarItem = true,
        } 
        if not string.isEmpty(itemId) then
            local buildingData = FactoryUtils.getItemBuildingData(itemId)
            if buildingData then
                itemInfo.type = QuickBarItemType.Building
            else
                itemInfo.type = QuickBarItemType.Logistic
            end
        end
        table.insert(typeInfo.showingItems, itemInfo)
    end
    return typeInfo
end


FacQuickBarOverview._BuildLogisticTypeInfo = HL.Method().Return(HL.Table) << function(self)
    local domainId = FactoryUtils.getCurAndAutoTransferBlackBoxToDomainId()
    local typeInfo = self:_CreateTypeInfo("logistic")

    if FactoryUtils.canShowBelt() then
        self:_AppendBeltItemInfos(typeInfo)
    end
    if FactoryUtils.canShowPipe() then
        self:_AppendPipeItemInfos(typeInfo)
    end

    
    local filteredItems = {}
    for _, itemInfo in ipairs(typeInfo.allItems) do
        if not FactoryUtils.isSkipBuildingInvalidInDomain(itemInfo.id, domainId) then
            table.insert(filteredItems, itemInfo)
        end
    end
    typeInfo.allItems = filteredItems

    local hasItem
    for _, itemInfo in ipairs(typeInfo.allItems) do
        hasItem = true
        local itemData = Tables.itemTable[itemInfo.itemId]
        itemInfo.rarity = itemData.rarity
        itemInfo.sortId1 = itemData.sortId1
        itemInfo.sortId2 = itemData.sortId2
    end
    if not hasItem then
        return nil
    end
    return typeInfo
end


FacQuickBarOverview._AppendBeltItemInfos = HL.Method(HL.Table) << function(self, typeInfo)
    local domainId = FactoryUtils.getCurAndAutoTransferBlackBoxToDomainId()

    for id, data in pairs(Tables.factoryGridBeltTable) do
        if id ~= FacConst.BELT_ID and FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.beltData.itemId,
                type = QuickBarItemType.Belt,
                data = data.beltData,
                conveySpeed = 1000000 / data.beltData.msPerRound,
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryBoxValveTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.gridUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.gridUnitData,
                conveySpeed = 1000000 / data.gridUnitData.msPerRound,
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryGridConnecterTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.gridUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.gridUnitData,
                conveySpeed = 1000000 / data.gridUnitData.msPerRound,
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryGridRouterTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.gridUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.gridUnitData,
                conveySpeed = 1000000 / data.gridUnitData.msPerRound,
            }
            table.insert(typeInfo.allItems, item)
        end
    end
end


FacQuickBarOverview._AppendPipeItemInfos = HL.Method(HL.Table) << function(self, typeInfo)
    local domainId = FactoryUtils.getCurAndAutoTransferBlackBoxToDomainId()

    for id, data in pairs(Tables.factoryLiquidPipeTable) do
        if id ~= FacConst.PIPE_ID and FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.pipeData.itemId,
                type = QuickBarItemType.Belt,
                data = data.pipeData,
                conveySpeed = 1000000 / data.pipeData.msPerRound,
                recommendDomains = FactoryUtils.GetAllowPipeDoaminList(),
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryFluidValveTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                itemId = data.liquidUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.liquidUnitData,
                conveySpeed = 1000000 / data.liquidUnitData.msPerRound,
                recommendDomains = FactoryUtils.GetAllowPipeDoaminList(),
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryLiquidConnectorTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                liquidUnitId = id,
                itemId = data.liquidUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.liquidUnitData,
                conveySpeed = 1000000 / data.liquidUnitData.msPerRound,
                recommendDomains = FactoryUtils.GetAllowPipeDoaminList(),
            }
            table.insert(typeInfo.allItems, item)
        end
    end
    for id, data in pairs(Tables.factoryLiquidRouterTable) do
        if FactoryUtils.isLogisticUnlocked(id, domainId) then
            local item = {
                id = id,
                liquidUnitId = id,
                itemId = data.liquidUnitData.itemId,
                type = QuickBarItemType.Logistic,
                data = data.liquidUnitData,
                conveySpeed = 1000000 / data.liquidUnitData.msPerRound,
                recommendDomains = FactoryUtils.GetAllowPipeDoaminList(),
            }
            table.insert(typeInfo.allItems, item)
        end
    end
end


FacQuickBarOverview._BuildBuildingTypeInfoMap = HL.Method().Return(HL.Table) << function(self)
    local inventory = GameInstance.player.inventory
    local domainId = FactoryUtils.getCurAndAutoTransferBlackBoxToDomainId()
    local facRegion = GameInstance.player.factoryRegionManager.currentRegion

    local typeInfoMap = {} 
    for buildingId, buildingData in pairs(Tables.factoryBuildingTable) do
        local typeId = buildingData.quickBarType
        if string.isEmpty(typeId) then
            goto continue 
        end
        if not facRegion:IsInsideRegion(buildingData.quickBarFacRegionTypeFlags) then
            goto continue 
        end
        local itemData = FactoryUtils.getBuildingItemData(buildingId)
        if not inventory:IsItemFound(itemData.id) then
            goto continue 
        end
        if FactoryUtils.isSkipBuildingInvalidInDomain(buildingId, domainId) then
            goto continue 
        end

        local typeInfo = typeInfoMap[typeId]
        if not typeInfo then
            typeInfo = self:_CreateTypeInfo(typeId)
            typeInfoMap[typeId] = typeInfo
        end
        local itemInfo = {
            id = buildingId,
            itemId = itemData.id,
            type = QuickBarItemType.Building,
            rarity = itemData.rarity,
            sortId1 = itemData.sortId1,
            sortId2 = itemData.sortId2,
        } 
        FactoryUtils.addBuildingDomainSortFilterInfo(itemInfo, buildingData, domainId)
        table.insert(typeInfo.allItems, itemInfo)
        :: continue ::
    end
    return typeInfoMap
end






FacQuickBarOverview.m_typeCells = HL.Field(HL.Forward('UIListCache'))

FacQuickBarOverview.m_selectedTypeIndex = HL.Field(HL.Number) << 1

FacQuickBarOverview.m_soilTypeIndex = HL.Field(HL.Any) 

FacQuickBarOverview._RefreshTypeList = HL.Method() << function(self)
    self:_InitTypeInfos()

    local count = #self.m_typeInfos
    self.m_selectedTypeIndex = math.min(math.max(self.m_selectedTypeIndex, 1), count)

    local countInCache = count - 1 - (self.m_soilTypeIndex and 1 or 0)
    self.m_typeCells:Refresh(countInCache, function(cell, cellIndex)
        self:_UpdateTypeCell(cell, cellIndex + 1)
    end)
    if self.m_soilTypeIndex then
        self.view.soilTypeCell.gameObject:SetActive(true)
        local childCount = self.view.typeList.transform.childCount
        self.view.soilTypeCell.transform:SetSiblingIndex(childCount - 1)
        self:_UpdateTypeCell(self.view.soilTypeCell, self.m_soilTypeIndex)
    else
        self.view.soilTypeCell.gameObject:SetActive(false)
    end
    self:_UpdateTypeCell(self.view.customTypeCell, 1) 

    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.typeList.transform)
    local bgNode = self.view.typeNodeBG.transform
    local offsetMin, offsetMax = bgNode.offsetMin, bgNode.offsetMax
    offsetMin.x = self.view.customTypeCell.transform.rect.width 
    offsetMax.x = self.m_soilTypeIndex and -self.view.soilTypeCell.transform.rect.width or 0 
    bgNode.offsetMin, bgNode.offsetMax = offsetMin, offsetMax

    self:_OnClickType(self.m_selectedTypeIndex)
end

FacQuickBarOverview._UpdateTypeCell = HL.Method(HL.Table, HL.Number) << function(self, cell, typeIndex)
    local typeInfo = self.m_typeInfos[typeIndex]
    cell.icon:LoadSprite(typeInfo.data.icon)
    cell.iconShadow:LoadSprite(string.format("%s_shadow", typeInfo.data.icon))
    cell.text.text = typeInfo.data.name
    cell.gameObject.name = "TypeTabCell_" .. typeInfo.data.id

    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.isOn = typeIndex == self.m_selectedTypeIndex
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_OnClickType(typeIndex)
            if DeviceInfo.usingController then
                local firstCell = self.m_getItemCell(1)
                if firstCell then
                    self:SetNaviTarget(firstCell.button)
                end
            end
        end
    end)
end

FacQuickBarOverview._OnClickType = HL.Method(HL.Number) << function(self, index)
    self.m_selectedTypeIndex = index
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    self:_ApplyFilters()
    self:_RefreshItemList(true)
    self.view.filterNode.gameObject:SetActive(not typeInfo.noFilter)

    
    local countInCache = self.m_typeCells:GetCount()
    self.m_typeCells:Update(function(cell, cellIndex)
        local tabIndex = cellIndex + 1
        cell.rightLine.gameObject:SetActive((tabIndex < index - 1) or (tabIndex > index and cellIndex ~= countInCache))
    end)

    local totalCount = countInCache + 1 + (self.m_soilTypeIndex and 1 or 0)
    self.view.scrollListLeftArrow.transform.localScale = index > 1 and Vector3.one or Vector3.zero
    self.view.scrollListRightArrow.transform.localScale = index < totalCount and Vector3.one or Vector3.zero
end






FacQuickBarOverview.m_getItemCell = HL.Field(HL.Function)

FacQuickBarOverview._RefreshItemList = HL.Method(HL.Opt(HL.Boolean)) << function(self, toTop)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemCount = typeInfo and #typeInfo.showingItems or 0
    self.view.scrollList:UpdateCount(itemCount, toTop == true)
    self.view.scrollListEmptyNode.gameObject:SetActive(itemCount == 0)
end

FacQuickBarOverview._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemInfo = typeInfo.showingItems[index]
    local itemId = itemInfo.itemId
    local isEmpty = string.isEmpty(itemId)

    cell.gameObject.name = "Item_" .. (isEmpty and index or itemId)

    cell.button.onClick:RemoveAllListeners()
    cell.button.onLongPress:RemoveAllListeners()
    cell.dragItem.enabled = not isEmpty
    cell.dragItem:ClearEvents()
    cell.content.gameObject:SetActive(not isEmpty)
    cell.emptyNode.gameObject:SetActive(isEmpty)

    if itemInfo.isCustomQuickBarItem then
        local actionId = "fac_use_quick_item_" .. index
        cell.button.onClick:ChangeBindingPlayerAction(actionId)
    else
        cell.button.onClick:StopUseBinding()
    end

    cell.button.onDoubleClick:RemoveAllListeners()
    if isEmpty then
        cell.button.onClick:RemoveAllListeners()
        cell.button.onLongPress:RemoveAllListeners()
        InputManagerInst:DeleteInGroup(cell.button.hoverBindingGroupId)
        if DeviceInfo.usingController then
            cell.controllerKeyHint:SetActionId("")
            cell.controllerKeyHint.gameObject:SetActive(cell.button.isNaviTarget)
        end
        return
    end

    local isBuilding = itemInfo.type == QuickBarItemType.Building
    local count, materialEnough
    if isBuilding then
        count = isEmpty and 0 or Utils.getItemCount(itemId, true, true)
        if count == 0 and not isEmpty then
            materialEnough = FactoryUtils.checkBuildingMaterialEnough(itemId)
        end
    end 

    local showCount
    if isBuilding and count > 0 then
        showCount = count
    end
    cell.item:InitItem({ id = itemId, count = showCount })
    if not isBuilding or count > 0 or materialEnough then
        cell.item:SetIconTransparent(UIConst.ITEM_EXIST_TRANSPARENCY)
    else
        cell.item:SetIconTransparent(UIConst.ITEM_MISSING_TRANSPARENCY)
    end
    cell.typeIcon:LoadSprite(typeInfo.data.icon)

    InputManagerInst:DeleteInGroup(cell.button.hoverBindingGroupId)
    InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_build_top_view", function()
        self:_OnClickItemCell(index)
    end, cell.button.hoverBindingGroupId)
    InputManagerInst:CreateBindingByActionId("show_item_tips", function()
        cell.item:ShowTips()
    end, cell.button.hoverBindingGroupId)

    cell.button.onClick:AddListener(function()
        if not isEmpty then
            self:_OnClickItemCell(index)
        end
    end)
    cell.button.onLongPress:AddListener(function()
        if not isEmpty then
            cell.item:ShowTips()
        end
    end)

    local isSkipBuilding = FactoryUtils.isSkipUnlockedBuildingByItemId(itemId)
    local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
    
    local hasSoilManualCraft, soilManualCraftId = false, nil
    if FactoryUtils.isSoilBuildingItem(itemId) then
        hasSoilManualCraft, soilManualCraftId = Tables.factoryManualCraftOutcomeToIdTable:TryGetValue(itemId)
    end
    if isSkipBuilding then
        
        if DeviceInfo.usingController then
            InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_craft", function()
                if Utils.getItemCount(itemId, true, true) == 0 then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_SKIP_BUILDING_CANNOT_CRAFT_IN_DOMAIN)
                end
            end, cell.button.hoverBindingGroupId)
        else
            cell.button.onDoubleClick:AddListener(function()
                if Utils.getItemCount(itemId, true, true) == 0 then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_SKIP_BUILDING_CANNOT_CRAFT_IN_DOMAIN)
                end
            end)
        end
    elseif hasCraft then
        if DeviceInfo.usingController then
            InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_craft", function()
                Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
            end, cell.button.hoverBindingGroupId)
        else
            cell.button.onDoubleClick:AddListener(function()
                if Utils.getItemCount(itemId, true, true) == 0 then
                    Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
                end
            end)
        end
    elseif FactoryUtils.isDecoBuildingItem(itemId) then
        InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_craft", function()
            if Utils.getItemCount(itemId, true, true) == 0 then
                Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
            end
        end, cell.button.hoverBindingGroupId)
        cell.button.onDoubleClick:AddListener(function()
            if Utils.getItemCount(itemId, true, true) == 0 then
                Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
            end
        end)
    elseif hasSoilManualCraft then
        
        if DeviceInfo.usingController then
            InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_craft", function()
                if Utils.getItemCount(itemId, true, true) == 0 then
                    PhaseManager:OpenPhase(PhaseId.ManualCraft, { jumpId = soilManualCraftId })
                end
            end, cell.button.hoverBindingGroupId)
        else
            cell.button.onDoubleClick:AddListener(function()
                if Utils.getItemCount(itemId, true, true) == 0 then
                    PhaseManager:OpenPhase(PhaseId.ManualCraft, { jumpId = soilManualCraftId })
                end
            end)
        end
    end
    if DeviceInfo.usingController then
        local showCraftHint = not isSkipBuilding and (hasCraft or hasSoilManualCraft) and count == 0 and not materialEnough
        cell.controllerKeyHint:SetActionId(showCraftHint and "fac_quick_bar_controller_craft" or "fac_quick_bar_controller_build_top_view")
        cell.controllerKeyHint.gameObject:SetActive(cell.button.isNaviTarget)
    end

    local itemData = Tables.itemTable:GetValue(itemId)
    cell.name.text = itemData.name
    UIUtils.initUIDragHelper(cell.dragItem, {
        source = itemInfo.isCustomQuickBarItem and UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar or UIConst.UI_DRAG_DROP_SOURCE_TYPE.BuildModeSelect,
        type = itemData.type,
        itemId = itemId,
        csIndex = CSIndex(index),
        onBeginDrag = function(enterObj, enterDropHelper)
            self:_OnQuickBarBeginDrag(index, enterObj, enterDropHelper)
        end,
        onDrag = function(eventData)
            self:_OnQuickBarDrag(eventData)
        end,
        onEndDrag = function(enterObj, enterDrop, eventData)
            self:_OnQuickBarEndDrag(index, enterObj, enterDrop, eventData)
        end,
        onDropTargetChanged = function(enterObj, dropHelper)
            if not itemInfo.isCustomQuickBarItem then
                return
            end
            local dragObj = cell.dragItem.curDragObj
            if not dragObj then
                return
            end
            local dragItem = dragObj:GetComponent("LuaUIWidget").table[1]
            if not dropHelper or not dropHelper.info.isQuickBarClearDropZone then
                dragItem.view.clearNode.gameObject:SetActive(false)
                return
            end
            dragItem.view.clearNode.gameObject:SetActive(true)
        end,
    })
    cell.dragItem.onUpdateDragObject:AddListener(function(dragObj)
        local dragItem = UIWidgetManager:Wrap(dragObj)
        dragItem:InitItem({ id = itemId })
    end)
end

FacQuickBarOverview._OnOverScrollList = HL.Method(HL.Boolean) << function(self, isNext)
    if not UIUtils.isScreenPosInRectTransform(InputManager.mousePosition, self.view.scrollList.transform, self:GetUICtrl().uiCamera) then
        return
    end

    if isNext and self.m_selectedTypeIndex == #self.m_typeInfos then
        return
    end
    if not isNext and self.m_selectedTypeIndex == 1 then
        return
    end
    local newIndex = self.m_selectedTypeIndex + (isNext and 1 or -1)
    if newIndex == 1 then
        self.view.customTypeCell.toggle.isOn = true
    elseif newIndex == self.m_soilTypeIndex then
        self.view.soilTypeCell.toggle.isOn = true
    else
        self.m_typeCells:Get(newIndex - 1).toggle.isOn = true
    end
    GameInstance.mobileMotionManager:PostEventCommonShort()
end

FacQuickBarOverview._OnQuickBarBeginDrag = HL.Method(HL.Number, HL.Opt(HL.Userdata, HL.Forward('UIDropHelper'))) << function(self, index, enterObj, enterDropHelper)
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local cell = self.m_getItemCell(obj)
        cell.button.animator:SetBool("IgnoreHighlight", true)
    end)
    self.view.clearDropZoneRoot.gameObject:SetActive(false)
end

FacQuickBarOverview._OnQuickBarDrag = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    local mousePos = eventData.position
    local inScrollRect = CS.Beyond.UI.UIUtils.IsScreenPosInRectTransform(mousePos, self.view.scrollList.transform, self:GetUICtrl().uiCamera)
    self.view.clearDropZoneRoot.gameObject:SetActive(not inScrollRect)
end

FacQuickBarOverview._OnQuickBarEndDrag = HL.Method(HL.Number, HL.Opt(HL.Userdata, HL.Forward('UIDropHelper'), HL.Any)) << function(self, index, enterObj, enterDrop, eventData)
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local cell = self.m_getItemCell(obj)
        cell.button.animator:SetBool("IgnoreHighlight", false)
    end)
    if not eventData then
        return
    end
    if enterDrop then
        return
    end
    if enterObj ~= UIManager.commonTouchPanel.gameObject then
        return
    end
    
    self:_OnClickItemCell(index, eventData.position)
end

FacQuickBarOverview._OnClickItemCell = HL.Method(HL.Number, HL.Opt(Vector2)) << function(self, index, mousePosition)
    local itemInfo = self.m_typeInfos[self.m_selectedTypeIndex].showingItems[index]
    if itemInfo.type == QuickBarItemType.Building then
        local itemId = itemInfo.itemId
        local count = Utils.getItemCount(itemId, true, true)
        if count == 0 then
            local materialEnough = FactoryUtils.checkBuildingMaterialEnough(itemId)
            if not materialEnough then
                if not FactoryUtils.canConsumeMaterialToPlaceBuilding() then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
                elseif FactoryUtils.isSkipUnlockedBuildingByItemId(itemId) then
                    
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
                else
                    local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
                    if hasCraft then
                        if DeviceInfo.usingController then
                            Notify(MessageConst.SHOW_TOAST, InputManager.ParseTextActionId(Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_CT))
                        elseif DeviceInfo.usingTouch then
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_TOUCH)
                        else
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO)
                        end
                    elseif FactoryUtils.isDecoBuildingItem(itemId) then
                        if DeviceInfo.usingController then
                            Notify(MessageConst.SHOW_TOAST, InputManager.ParseTextActionId(Language.LUA_FAC_QUICK_BAR_DECO_COUNT_ZERO_CT))
                        elseif DeviceInfo.usingTouch then
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_DECO_COUNT_ZERO_TOUCH)
                        else
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_DECO_COUNT_ZERO)
                        end
                    elseif FactoryUtils.isSoilBuildingItem(itemId) and Tables.factoryManualCraftOutcomeToIdTable:TryGetValue(itemId) then
                        
                        if DeviceInfo.usingController then
                            Notify(MessageConst.SHOW_TOAST, InputManager.ParseTextActionId(Language.LUA_FAC_QUICK_BAR_SOIL_COUNT_ZERO_CT))
                        elseif DeviceInfo.usingTouch then
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_SOIL_COUNT_ZERO_TOUCH)
                        else
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_SOIL_COUNT_ZERO)
                        end
                    else
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
                    end
                end
                return
            end
        end
        Notify(MessageConst.FAC_ENTER_BUILDING_MODE, {
            itemId = itemId,
            initMousePos = mousePosition,
        })
    elseif itemInfo.type == QuickBarItemType.Belt then
        Notify(MessageConst.FAC_ENTER_BELT_MODE, {
            beltId = itemInfo.id,
            initMousePos = mousePosition,
        })
    elseif itemInfo.type == QuickBarItemType.Logistic then
        Notify(MessageConst.FAC_ENTER_LOGISTIC_MODE, {
            itemId = itemInfo.itemId,
            initMousePos = mousePosition,
        })
    end
end






FacQuickBarOverview.m_filterInfos = HL.Field(HL.Table)

FacQuickBarOverview.m_selectedFilters = HL.Field(HL.Table)

FacQuickBarOverview.m_filterCells = HL.Field(HL.Forward('UIListCache'))

FacQuickBarOverview._InitFilters = HL.Method() << function(self)
    self.m_filterInfos = {}
    self.m_selectedFilters = self.m_selectedFilters or {}

    local mapManager = GameInstance.player.mapManager
    for _, domainData in pairs(Tables.domainDataTable) do
        local isDomainUnlocked = true 
        for _, levelId in pairs(domainData.levelGroup) do
            if mapManager:IsLevelUnlocked(levelId) then
                isDomainUnlocked = true
                break
            end
        end
        if isDomainUnlocked then
            table.insert(self.m_filterInfos, {
                id = domainData.domainId,
                name = domainData.domainName,
                sortId = domainData.sortId,
                icon = domainData.domainIcon
            })
        end
    end
    table.sort(self.m_filterInfos, Utils.genSortFunction({ "sortId" }, true))

    local node = self.view.filterNode
    node.filterBtn.onClick:RemoveAllListeners()
    node.filterBtn.onClick:AddListener(function()
        self:_ToggleFilterList(true)
    end)
    node.filteredBtn.onClick:RemoveAllListeners()
    node.filteredBtn.onClick:AddListener(function()
        self:_ToggleFilterList(true)
    end)
    node.confirmBtn.onClick:RemoveAllListeners()
    node.confirmBtn.onClick:AddListener(function()
        self:_ToggleFilterList(false)
    end)
    node.list.onTriggerAutoClose:RemoveAllListeners()
    node.list.onTriggerAutoClose:AddListener(function()
        self:_ToggleFilterList(false)
    end)
    self:_ToggleFilterList(false, true)
    node.controllerHintPlaceholder:InitControllerHintPlaceholder({ node.listInputBindingGroupMonoTarget.groupId })

    self.m_filterCells = self.m_filterCells or UIUtils.genCellCache(node.optionCell)
    self.m_filterCells:Refresh(#self.m_filterInfos, function(cell, index)
        local info = self.m_filterInfos[index]
        cell.name.text = info.name
        cell.icon:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT, info.icon)
        cell.toggle:SetIsOnWithoutNotify(self.m_selectedFilters[info.id] == true)
        cell.toggle.onValueChanged:RemoveAllListeners()
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                self.m_selectedFilters[info.id] = true
            else
                self.m_selectedFilters[info.id] = nil
            end
            self:_ApplyFilters()
            self:_RefreshItemList(true)
        end)
    end)
end

FacQuickBarOverview._UpdateFilterCellStates = HL.Method() << function(self)
    self.m_filterCells:Update(function(cell, index)
        local info = self.m_filterInfos[index]
        cell.toggle:SetIsOnWithoutNotify(self.m_selectedFilters[info.id] == true)
    end)
    self:_UpdateFilterIcon()
end

FacQuickBarOverview._ToggleFilterList = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, active, skipAni)
    local node = self.view.filterNode
    if skipAni then
        node.list.gameObject:SetActive(active)
    else
        UIUtils.PlayAnimationAndToggleActive(node.listAnimationWrapper, active)
    end
    self:_UpdateFilterIcon(active)
    if DeviceInfo.usingController and self:IsActive() then
        if active then
            node.listSelectableNaviGroup:ManuallyFocus()
        else
            
            local cell = self.m_getItemCell(1)
            if cell then
                self:SetNaviTarget(cell.button)
            end
            node.listSelectableNaviGroup:ManuallyStopFocus()
        end
    end
end

FacQuickBarOverview._UpdateFilterIcon = HL.Method(HL.Opt(HL.Boolean)) << function(self, active)
    local node = self.view.filterNode
    if active == nil then
        active = node.list.gameObject.activeInHierarchy
    end
    node.confirmBtn.gameObject:SetActive(active)
    node.filterBtn.gameObject:SetActive(not active and not next(self.m_selectedFilters))
    node.filteredBtn.gameObject:SetActive(not active and next(self.m_selectedFilters) ~= nil)
end

FacQuickBarOverview._ApplyFilters = HL.Method() << function(self)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    if typeInfo.noFilter then
        return
    end
    local hasFilter = next(self.m_selectedFilters) ~= nil
    typeInfo.showingItems = {}
    for _, v in ipairs(typeInfo.allItems) do
        if hasFilter then
            if v.recommendDomains and next(v.recommendDomains) then
                for _, domainId in ipairs(v.recommendDomains) do
                    if self.m_selectedFilters[domainId] then
                        table.insert(typeInfo.showingItems, v)
                        break
                    end
                end
            else
                table.insert(typeInfo.showingItems, v)
            end
        else
            table.insert(typeInfo.showingItems, v)
        end
    end
    table.sort(typeInfo.showingItems, Utils.genSortFunction({ "domainReverseSort", "sortId1", "sortId2", "rarity" }, true))
end

FacQuickBarOverview._ResetFilters = HL.Method() << function(self)
    self.m_selectedFilters = {}
    self:_UpdateFilterCellStates()
end






FacQuickBarOverview._RefreshRightSide = HL.Method() << function(self)
    self.view.beltNode.gameObject:SetActive(FactoryUtils.canShowBelt())
    self.view.pipeNode.gameObject:SetActive(FactoryUtils.canShowPipe())
end

FacQuickBarOverview._OnClickBelt = HL.Method() << function(self)
    Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.BELT_ID })
end

FacQuickBarOverview._OnClickPipe = HL.Method() << function(self)
    Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.PIPE_ID })
end






FacQuickBarOverview._OnQuickBarChanged = HL.Method() << function(self)
    if self:GetUICtrl():IsHide() then
        return
    end
    self.m_typeInfos[1] = self:_BuildCustomTypeInfo()
    self:_RefreshItemList()
end

FacQuickBarOverview._OnItemCountChanged = HL.Method(HL.Table) << function(self, args)
    if self:GetUICtrl():IsHide() or not self.m_typeInfos then
        return
    end

    local itemId2DiffCount = unpack(args)
    local showingItems = self.m_typeInfos[self.m_selectedTypeIndex].showingItems
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local itemInfo = showingItems[LuaIndex(csIndex)]
        if itemId2DiffCount:ContainsKey(itemInfo.itemId) then
            local cell = self.m_getItemCell(obj)
            local count = Utils.getItemCount(itemInfo.itemId, true, true)
            local materialEnough = false
            if count == 0 then
                count = nil
                materialEnough = FactoryUtils.checkBuildingMaterialEnough(itemInfo.itemId)
            end
            cell.item:UpdateCount(count)
            if count or materialEnough then
                cell.item:SetIconTransparent(UIConst.ITEM_EXIST_TRANSPARENCY)
            else
                cell.item:SetIconTransparent(UIConst.ITEM_MISSING_TRANSPARENCY)
            end
        end
    end)
end

FacQuickBarOverview._OnToggleFacTopView = HL.Method(HL.Boolean) << function(self, active)
    self:_ResetFilters()
end

FacQuickBarOverview._ToggleHideFacTopViewRightSideUi = HL.Method(HL.Boolean) << function(self, isHide)
    self.view.rightSideNode.gameObject:SetActive(not isHide)
end






FacQuickBarOverview.RecordControllerNaviInfo = HL.Override(HL.Table) << function(self, controllerNaviInfo)
    controllerNaviInfo.isActive = self.m_isActive
    controllerNaviInfo.typeIndex = self.m_selectedTypeIndex

    local layerSelectedTarget = self.view.container.LayerSelectedTarget
    if layerSelectedTarget then
        local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
        for i, _ in ipairs(typeInfo.showingItems) do
            local cell = self.m_getItemCell(i)
            if cell and cell.button == layerSelectedTarget then
                controllerNaviInfo.itemIndex = i
                break
            end
        end
    end
end

FacQuickBarOverview.TryRecoverControllerNaviInfo = HL.Override(HL.Table) << function(self, controllerNaviInfo)
    local itemIndex = controllerNaviInfo.itemIndex
    if not itemIndex then
        return
    end

    if controllerNaviInfo.isActive then
        self:Activate()
    end

    self.m_selectedTypeIndex = controllerNaviInfo.typeIndex
    self:_RefreshTypeList()

    self.view.scrollList:ScrollToIndex(CSIndex(itemIndex), true)
    self:SetNaviTarget(self.m_getItemCell(itemIndex).button)
end






FacQuickBarOverview.ExtractHotSwitchRuntimeState = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local state = {
        typeCells = self.m_typeCells,
        filterCells = self.m_filterCells,
        selectedTypeIndex = self.m_selectedTypeIndex,
        selectedFilters = self.m_selectedFilters,
    }
    return state
end

FacQuickBarOverview.RestoreHotSwitchRuntimeState = HL.Override(HL.Opt(HL.Table)) << function(self, state)
    if not state then
        return
    end

    self.m_typeCells = state.typeCells
    self.m_filterCells = state.filterCells
    self.m_selectedTypeIndex = state.selectedTypeIndex
    self.m_selectedFilters = state.selectedFilters
end






FacQuickBarOverview.GetCurStateArg = HL.Override(HL.Table) << function(self, arg)
    arg.selectedTypeIndex = self.m_selectedTypeIndex
    arg.selectedFilters = self.m_selectedFilters
end

FacQuickBarOverview.RecoverStateOnChangeDevice = HL.Override(HL.Table) << function(self, arg)
    self.m_selectedFilters = arg.selectedFilters
    self:_UpdateFilterCellStates()

    local selectedTypeIndex = arg.selectedTypeIndex
    local tabCell
    if selectedTypeIndex == 1 then
        tabCell = self.view.customTypeCell
    elseif selectedTypeIndex == self.m_soilTypeIndex then
        tabCell = self.view.soilTypeCell
    else
        tabCell = self.m_typeCells:Get(selectedTypeIndex - 1)
    end
    tabCell.toggle:SetIsOnWithoutNotify(true) 
    self:_OnClickType(selectedTypeIndex)
end




HL.Commit(FacQuickBarOverview)
return FacQuickBarOverview