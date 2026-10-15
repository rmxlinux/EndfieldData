local QuickBarItemType = FacConst.QuickBarItemType

local FacQuickBarBase = require_ex("UI/Widgets/FacQuickBarBase")





FacQuickBarCustom = HL.Class("FacQuickBarCustom", FacQuickBarBase)











FacQuickBarCustom._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function(...)
        self:_OnItemCountChanged(...)
    end)
    self:RegisterMessage(MessageConst.ON_QUICK_BAR_CHANGED, function()
        self:_OnQuickBarChanged()
    end)
    self:RegisterMessage(MessageConst.ON_SET_IN_SAFE_ZONE, function(...)
        self:_OnSetInSafeZone(...)
    end)

    self:RegisterMessage(MessageConst.ON_START_UI_DRAG, function(...)
        self:_OnOtherStartDragItem(...)
    end)
    self:RegisterMessage(MessageConst.ON_END_UI_DRAG, function(...)
        self:_OnOtherEndDragItem(...)
    end)

    self:RegisterMessage(MessageConst.FAC_ON_BELT_UNLOCKED, function()
        self:_OnBeltUnlocked()
    end)
    self:RegisterMessage(MessageConst.FAC_ON_PIPE_UNLOCKED, function()
        self:_OnPipeUnlocked()
    end)

    self:RegisterMessage(MessageConst.START_SET_BUILDING_ON_FAC_QUICK_BAR, function(...)
        self:_StartSetBuildingOnFacQuickBar(...)
    end)
    self:RegisterMessage(MessageConst.START_SWITCH_SLOT_ON_FAC_QUICK_BAR, function(...)
        self:_StartSwitchSlotOnFacQuickBar(...)
    end)

    self:RegisterMessage(MessageConst.QUICK_DROP_TO_FAC_QUICK_BAR, function(...)
        self:_OnQuickDropItemToQuickBar(...)
    end)

    self:RegisterMessage(MessageConst.ON_NEW_SCOPE_INFO_RECEIVED, function()
        self:_OnNewScopeInfoReceived()
    end)
    self:RegisterMessage(MessageConst.ON_CHANGE_SPACESHIP_DOMAIN_ID, function()
        self:_OnQuickBarChanged()
    end)

    self.m_typeCells = UIUtils.genCellCache(self.view.typeCell)
    self.m_itemCells = UIUtils.genCellCache(self.view.itemSlot)

    self:_InitLogisticNode(self.view.beltNode, FacConst.BELT_ITEM_ID, function()
        Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.BELT_ID })
    end)
    self:_InitLogisticNode(self.view.pipeNode, FacConst.PIPE_ITEM_ID, function()
        Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.PIPE_ID })
    end)

    self:_InitController()
end

FacQuickBarCustom._OnInitFacQuickBar = HL.Override(HL.Table) << function(self, args)
    local showBuildBtn = self.m_args.showBuildBtn
        and (GameInstance.mode.modeType == GEnums.GameModeType.Default or Utils.isInBlackbox())
        and Utils.isSystemUnlocked(GEnums.UnlockSystemType.FacHub)
    self.view.buildBtn.gameObject:SetActive(showBuildBtn)
    self.view.buildBtn.onClick:RemoveAllListeners()
    if showBuildBtn then
        self.view.buildBtn.onClick:AddListener(function()
            Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, showLastType = true })
        end)
    end

    self.view.facQuickBarClearDropZone:InitFacQuickBarClearDropZone()
end

FacQuickBarCustom._OnEnable = HL.Override() << function(self)
    self.view.dropHint.gameObject:SetActive(false)
    self.view.facQuickBarClearDropZone.gameObject:SetActive(false)
end

FacQuickBarCustom.RefreshFacQuickBar = HL.Override() << function(self)
    self:_RefreshTypeList()
    self:_RefreshRightSide(true)
    self:_RefreshControllerSetting()
end




FacQuickBarCustom._OnActivate = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    if not DeviceInfo.usingController then
        return
    end

    self:_ToggleCellActionOnSetNaviTarget(false)

    local naviGroup = self.m_args.naviGroup
    local curTarget = naviGroup.lastFocusNaviTarget
    if curTarget and not curTarget.gameObject.activeInHierarchy then
        naviGroup:ClearLastFocusNaviTarget()
    end
    naviGroup:ManuallyFocus()
end

FacQuickBarCustom._OnDeactivate = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    if not DeviceInfo.usingController then
        return
    end

    if not string.isEmpty(self.m_curSettingBuildingItemId) then
        self:_ExitSetBuilding()
    end

    
    
    self:_ToggleCellActionOnSetNaviTarget(true)

    if self.m_args.useActiveAction then
        
        
        
        
        
        
        self.m_args.naviGroup:ManuallyStopFocus()
    end
end



















FacQuickBarCustom.m_typeInfos = HL.Field(HL.Table) 

FacQuickBarCustom._InitTypeInfos = HL.Method() << function(self)
    local fcType = GEnums.FCQuickBarType.Inner
    local quickBarItems = FactoryUtils.getQuickBar(fcType)
    if not quickBarItems then
        self:_RefreshRightSide(false)
        return
    end

    local typeInfos = {}

    local typeData = Tables.factoryQuickBarTypeTable:GetValue("custom")
    local typeInfo = {
        data = typeData,
        priority = typeData.priority,
        fcType = fcType,
        items = {},
        canDrop = true,
    } 

    for _, itemId in pairs(quickBarItems) do
        local info = {
            itemId = itemId,
            isCustomQuickBarItem = true,
        } 

        if not string.isEmpty(itemId) then
            local buildingData = FactoryUtils.getItemBuildingData(itemId)
            if buildingData then
                info.type = QuickBarItemType.Building
                info.onlyShowOnMain = buildingData.onlyShowOnMain
            else
                info.type = QuickBarItemType.Logistic
                if FacConst.FLUID_LOGISTIC_ITEMS[itemId] then
                    info.onlyShowOnMain = false
                else
                    info.onlyShowOnMain = true
                end
            end
        end
        table.insert(typeInfo.items, info)
    end
    table.insert(typeInfos, typeInfo)

    table.sort(typeInfos, Utils.genSortFunction({ "priority" }))

    self.m_typeInfos = typeInfos
end






FacQuickBarCustom.m_typeCells = HL.Field(HL.Forward("UIListCache"))

FacQuickBarCustom.m_selectedTypeIndex = HL.Field(HL.Number) << 1

FacQuickBarCustom._RefreshTypeList = HL.Method() << function(self)
    self:_InitTypeInfos()

    local count = #self.m_typeInfos
    self.m_selectedTypeIndex = math.min(math.max(self.m_selectedTypeIndex, 1), count)

    self.m_typeCells:Refresh(count, function(cell, index)
        local info = self.m_typeInfos[index]

        local name = info.data.name
        cell.default.icon:LoadSprite(info.data.icon)
        cell.default.nameTxt.text = name
        cell.selected.icon:LoadSprite(info.data.icon)
        cell.selected.nameTxt.text = name

        cell.toggle.onValueChanged:RemoveAllListeners()
        cell.toggle.isOn = index == self.m_selectedTypeIndex
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                self:_OnClickType(index)
            end
        end)

        cell.gameObject.name = "TypeTabCell_" .. info.data.id
    end)

    self:_OnClickType(self.m_selectedTypeIndex)
end

FacQuickBarCustom._OnClickType = HL.Method(HL.Number) << function(self, index)
    self.m_selectedTypeIndex = index
    self:_RefreshItemList()
end






FacQuickBarCustom.m_itemCells = HL.Field(HL.Forward("UIListCache"))

FacQuickBarCustom._RefreshItemList = HL.Method() << function(self)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemCount = #typeInfo.items
    self.m_itemCells:Refresh(itemCount, function(cell, index)
        self:_UpdateCell(cell, index)
    end)
end

FacQuickBarCustom._UpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemInfo = typeInfo.items[index]
    local itemId = itemInfo.itemId
    local isEmpty = string.isEmpty(itemId)

    local count, materialEnough
    local isBuilding = itemInfo.type == QuickBarItemType.Building
    if isBuilding then
        count = isEmpty and 0 or Utils.getItemCount(itemId, true, true)
        if count == 0 and not isEmpty then
            materialEnough = FactoryUtils.checkBuildingMaterialEnough(itemId)
        end
    end

    local useActiveAction = self.m_args.useActiveAction
    local itemCell = cell.view.item 
    itemCell.m_enableHoverTips = DeviceInfo.usingKeyboard or not useActiveAction
    local showCount
    if isBuilding and count > 0 then
        showCount = count
    end
    cell:InitItemSlot({
        id = itemId,
        count = showCount,
    }, function()
        if DeviceInfo.usingController then
            if not useActiveAction then
                if string.isEmpty(self.m_curSettingBuildingItemId) then
                    
                    itemCell:ShowActionMenu(false, UIConst.UI_TIPS_POS_TYPE.RightDown)
                else
                    self:_OnClickItem(index)
                end
            end
        else
            self:_OnClickItem(index)
        end
    end, nil, true)
    if not isBuilding or count > 0 or materialEnough then
        cell.item:SetIconTransparent(UIConst.ITEM_EXIST_TRANSPARENCY)
    else
        cell.item:SetIconTransparent(UIConst.ITEM_MISSING_TRANSPARENCY)
    end

    if itemCell.customShowTipsFunc == nil then
        itemCell.customShowTipsFunc = function()
            if not string.isEmpty(self.m_curSettingBuildingItemId) then
                self.view.setBuildingHint.gameObject:SetActive(false)
            end
        end
        itemCell.customHideTipsFunc = function()
            if self.m_isDestroyed or IsNull(self.m_args.naviGroup) then
                return
            end
            if not string.isEmpty(self.m_curSettingBuildingItemId) then
                self.view.setBuildingHint.gameObject:SetActive(true)
            end
            if useActiveAction then
                local keyCode = InputManagerInst:GetActionGamepadKeyCode("fac_activate_quick_bar", false, true);
                if not InputManagerInst:GetKey(keyCode) then
                    self:Deactivate()
                end
            end
        end
    end
    if string.isEmpty(self.m_curSettingBuildingItemId) then
        itemCell:AddHoverBinding("fac_quick_bar_controller_build", function()
            self:_OnClickItem(index)
        end)
    end

    if cell.view.setBuildingHint then
        
        if string.isEmpty(self.m_curSettingBuildingItemId) and self.m_switchSlotFromIndex < 0 then
            cell.view.setBuildingHint.gameObject:SetActive(false)
        else
            cell.view.setBuildingHint.gameObject:SetActive(itemCell.view.button.isNaviTarget)
            itemCell.view.button.onHoverChange:AddListener(function(isHover)
                cell.view.setBuildingHint.gameObject:SetActive(isHover and not (string.isEmpty(self.m_curSettingBuildingItemId) and self.m_switchSlotFromIndex < 0))
            end)
        end
    end

    itemCell.canPlace = true
    if isEmpty or count == 0 then
        itemCell.canPlace = false
    end
    itemCell.actionMenuArgs = {
        source = UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar,
        canSwitch = self.m_args.controllerSwitchArgs ~= nil,
        fromIndex = index,
    }

    cell.item.view.button.onDoubleClick:RemoveAllListeners()
    if isBuilding then
        local isSkipBuilding = FactoryUtils.isSkipBuildingInvalidInDomainByItemId(itemId)
        local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
        
        local hasSoilManualCraft, soilManualCraftId = false, nil
        if FactoryUtils.isSoilBuildingItem(itemId) then
            hasSoilManualCraft, soilManualCraftId = Tables.factoryManualCraftOutcomeToIdTable:TryGetValue(itemId)
        end
        if isSkipBuilding then
            
            cell.item.view.button.onDoubleClick:AddListener(function()
                if count == 0 then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_SKIP_BUILDING_CANNOT_CRAFT_IN_DOMAIN)
                end
            end)
        elseif hasCraft then
            cell.item.view.button.onDoubleClick:AddListener(function()
                if count == 0 then
                    Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
                end
            end)
        elseif FactoryUtils.isDecoBuildingItem(itemId) then
            cell.item.view.button.onDoubleClick:AddListener(function()
                if count == 0 then
                    Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, selectedId = itemId })
                end
            end)
        elseif hasSoilManualCraft then
            
            cell.item.view.button.onDoubleClick:AddListener(function()
                if count == 0 then
                    PhaseManager:OpenPhase(PhaseId.ManualCraft, { jumpId = soilManualCraftId })
                end
            end)
        end
    end

    cell.item.view.nameNode.gameObject:SetActive(false)
    if cell.view.hoverKeyHint then
        cell.view.hoverKeyHint.gameObject:SetActive(false)
    end

    cell.item.view.button.onIsNaviTargetChanged = function(active)
        if active then
            self.m_currentNaviIndex = index
            self:_RefreshCellHoverBinding(cell, index)
        end

        
        local showHoverHint = useActiveAction and active
        cell.item.view.nameNode.gameObject:SetActive(showHoverHint)
        if cell.view.hoverKeyHint then
            cell.view.hoverKeyHint.gameObject:SetActive(showHoverHint)
        end

        if cell.view.setBuildingHint then
            
            local inSetting = not string.isEmpty(self.m_curSettingBuildingItemId) or self.m_switchSlotFromIndex > 0
            cell.view.setBuildingHint.gameObject:SetActive(inSetting and active)
        end
    end
    self:_RefreshCellHoverBinding(cell, index)

    local actionId = "fac_use_quick_item_" .. index
    cell.item.view.button.onClick:ChangeBindingPlayerAction(actionId)

    cell.gameObject.name = "Item_" .. (isEmpty and index or itemId)

    if not isEmpty then
        local data = Tables.itemTable:GetValue(itemId)
        if itemInfo.isCustomQuickBarItem then
            UIUtils.initUIDragHelper(cell.view.dragItem, {
                source = UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar,
                type = data.type,
                csIndex = CSIndex(index),
                itemId = itemId,
                onEndDrag = function(enterObj, enterDrop, eventData)
                    self:_OnQuickBarEndDrag(index, enterObj, enterDrop, eventData)
                end,
                onDropTargetChanged = function(enterObj, dropHelper)
                    local dragObj = cell.view.dragItem.curDragObj
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
        else
            UIUtils.initUIDragHelper(cell.view.dragItem, {
                source = UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar,
                type = data.type,
                itemId = itemId,
                onEndDrag = function(enterObj, enterDrop, eventData)
                    self:_OnQuickBarEndDrag(index, enterObj, enterDrop, eventData)
                end
            })
        end

        if DeviceInfo.usingController then
            cell:InitPressDrag()
        else
            cell.item:OpenLongPressTips()
        end
    end
    if itemInfo.isCustomQuickBarItem then
        cell.view.dropItem.enabled = true
        UIUtils.initUIDropHelper(cell.view.dropItem, {
            acceptTypes = UIConst.FACTORY_QUICK_BAR_DROP_ACCEPT_INFO,
            onDropItem = function(eventData, dragHelper)
                self:_OnDropItem(index, dragHelper)
            end,
        })
    else
        cell.view.dropItem.enabled = false
    end

    if DeviceInfo.usingController then
        cell.item:SetExtraInfo({
            tipsPosTransform = cell.view.controllerTipsRect,
        })
    end

    cell.item.view.nameNode.gameObject:SetActive(false)
end

FacQuickBarCustom._RefreshCellHoverBinding = HL.Method(HL.Forward("ItemSlot"), HL.Number) << function(self, cell, index)
    local button = cell.item.view.button
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemInfo = typeInfo.items[index]
    local itemId = itemInfo.itemId
    local isEmpty = string.isEmpty(itemId)
    local count
    if itemInfo.type == QuickBarItemType.Building then
        count = isEmpty and 0 or Utils.getItemCount(itemId, true, true)
    end

    if not string.isEmpty(self.m_curSettingBuildingItemId) then
        InputManagerInst:ToggleBinding(button.hoverConfirmBindingId, false)
        InputManagerInst:SetBindingText(button.hoverConfirmBindingId, nil)
        return
    end

    if self.m_args.controllerSwitchArgs ~= nil then
        if self.m_switchSlotFromIndex > 0 or isEmpty then
            InputManagerInst:ToggleBinding(button.hoverConfirmBindingId, false)
        end
        InputManagerInst:SetBindingText(button.hoverConfirmBindingId, Language["key_hint_item_open_action_menu"])
        return
    end

    if isEmpty or count == 0 then
        InputManagerInst:ToggleBinding(button.hoverConfirmBindingId, false)
        return
    end

    InputManagerInst:SetBindingText(button.hoverConfirmBindingId, Language.LUA_ITEM_ACTION_PLACE)
end

FacQuickBarCustom._OnClickItem = HL.Method(HL.Number, HL.Opt(Vector2)) << function(self, index, mousePosition)
    self:_BuildItem(index, mousePosition)
end

FacQuickBarCustom._BuildItem = HL.Method(HL.Number, HL.Opt(Vector2)) << function(self, index, mousePosition)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local itemInfo = typeInfo.items[index]
    local itemId = itemInfo.itemId
    if not itemInfo or string.isEmpty(itemId) then
        return
    end

    if itemInfo.onlyShowOnMain then
        if not Utils.isInFacMainRegion() then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_CANT_BUILD_IN_NOT_MAIN_REGION)
            return
        end
    end

    local isBuilding = itemInfo.type == QuickBarItemType.Building
    if isBuilding then
        local count = Utils.getItemCount(itemId, true, true)
        if count > 0 then
            Notify(MessageConst.FAC_ENTER_BUILDING_MODE, {
                itemId = itemId,
                initMousePos = mousePosition,
            })
        else
            local materialEnough = FactoryUtils.checkBuildingMaterialEnough(itemId)
            if materialEnough then
                Notify(MessageConst.FAC_ENTER_BUILDING_MODE, {
                    itemId = itemId,
                    initMousePos = mousePosition,
                })
                return
            end

            if not FactoryUtils.canConsumeMaterialToPlaceBuilding() then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
            elseif FactoryUtils.isSkipUnlockedBuildingByItemId(itemId) then
                
                Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
            else
                local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
                local showJumpToast = hasCraft and not DeviceInfo.usingController
                local isDecoBuilding = FactoryUtils.isDecoBuildingItem(itemId)
                local hasSoilManualCraft = FactoryUtils.isSoilBuildingItem(itemId)
                    and Tables.factoryManualCraftOutcomeToIdTable:TryGetValue(itemId)
                local text = DeviceInfo.usingTouch and Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_TOUCH or Language.LUA_FAC_QUICK_BAR_COUNT_ZERO
                if isDecoBuilding then
                    showJumpToast = not DeviceInfo.usingController
                    text = DeviceInfo.usingTouch and Language.LUA_FAC_QUICK_BAR_DECO_COUNT_ZERO_TOUCH or Language.LUA_FAC_QUICK_BAR_DECO_COUNT_ZERO
                elseif hasSoilManualCraft then
                    
                    showJumpToast = not DeviceInfo.usingController
                    text = DeviceInfo.usingTouch and Language.LUA_FAC_QUICK_BAR_SOIL_COUNT_ZERO_TOUCH or Language.LUA_FAC_QUICK_BAR_SOIL_COUNT_ZERO
                end
                Notify(MessageConst.SHOW_TOAST, showJumpToast and text or Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
            end
        end
    else
        if itemInfo.type == QuickBarItemType.Belt then
            Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = itemInfo.id })
        elseif itemInfo.type == QuickBarItemType.Logistic then
            Notify(MessageConst.FAC_ENTER_LOGISTIC_MODE, { itemId = itemInfo.itemId })
        end
    end
end






FacQuickBarCustom._OnOtherStartDragItem = HL.Method(HL.Forward("UIDragHelper")) << function(self, dragHelper)
    if self:GetUICtrl():IsHide() then
        return
    end
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    if not typeInfo.canDrop then
        return
    end
    if not dragHelper.cantDrop and UIUtils.isTypeDropValid(dragHelper, UIConst.FACTORY_QUICK_BAR_DROP_ACCEPT_INFO) then
        if dragHelper.source ~= UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar then
            self.view.dropHint.gameObject:SetActive(true)
            self.view.dropHint.transform:SetAsLastSibling()
        end
    else
        self.view.cantDropHint.gameObject:SetActive(true)
        if string.isEmpty(dragHelper.cantDropText) then
            self.view.cantDropText.text = Language["ui_fac_quick_bar_notport"]
        else
            self.view.cantDropText.text = dragHelper.cantDropText
        end
        self.view.cantDropHint.transform:SetAsLastSibling()
    end
    self.view.beltNode.notDropHint.gameObject:SetActive(true)
    self.view.pipeNode.notDropHint.gameObject:SetActive(true)
end

FacQuickBarCustom._OnOtherEndDragItem = HL.Method(HL.Forward("UIDragHelper")) << function(self, dragHelper)
    if not dragHelper.cantDrop and UIUtils.isTypeDropValid(dragHelper, UIConst.FACTORY_QUICK_BAR_DROP_ACCEPT_INFO) then
        self.view.dropHint.gameObject:SetActive(false)
    else
        self.view.cantDropHint.gameObject:SetActive(false)
    end
    self.view.beltNode.notDropHint.gameObject:SetActive(false)
    self.view.pipeNode.notDropHint.gameObject:SetActive(false)
end

FacQuickBarCustom._OnDropItem = HL.Method(HL.Number, HL.Forward("UIDragHelper")) << function(self, index, dragHelper)
    local csIndex = CSIndex(index)
    local source = dragHelper.source
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    if source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar then
        
        local fromCSIndex = dragHelper.info.csIndex
        FactoryUtils.MoveQuickBar(typeInfo.fcType, fromCSIndex, csIndex)
        UIUtils.playItemDropAudio(dragHelper:GetId())
        AudioAdapter.PostEvent("au_ui_common_put_down")
    elseif not dragHelper.cantDrop then
        
        local itemId = dragHelper:GetId()
        FactoryUtils.SetQuickBar(typeInfo.fcType, csIndex, itemId)
        UIUtils.playItemDropAudio(dragHelper:GetId())
        AudioAdapter.PostEvent("au_ui_common_put_down")
    end
end

FacQuickBarCustom._OnQuickBarEndDrag = HL.Method(HL.Number, HL.Opt(HL.Userdata, HL.Forward("UIDropHelper"), HL.Any)) << function(self, index, enterObj, enterDrop, eventData)
    if not eventData then
        return
    end
    
    
    if self:GetUICtrl():IsHide() then
        return
    end
    if enterDrop then
        return
    end
    if enterObj ~= UIManager.commonTouchPanel.gameObject then
        return
    end
    
    self:_OnClickItem(index, eventData.position)
end


FacQuickBarCustom.CancelDragging = HL.Method() << function(self)
    if not self.m_itemCells then
        return
    end
    local count = self.m_itemCells:GetCount()
    for index = 1, count do
        local cell = self.m_itemCells:GetItem(index)
        local dragItem = cell and cell.view and cell.view.dragItem
        if dragItem and dragItem.inDragging then
            dragItem:OnEndDrag(nil)
        end
    end
end

FacQuickBarCustom._OnQuickDropItemToQuickBar = HL.Method(HL.Any) << function(self, itemId)
    if type(itemId) == "table" then
        itemId = unpack(itemId)
    end
    local targetIndex
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    for i, itemInfo in ipairs(typeInfo.items) do
        if itemInfo.itemId == itemId then
            return
        end
        if targetIndex == nil and string.isEmpty(itemInfo.itemId) then
            targetIndex = i
        end
    end
    if targetIndex == nil then
        return
    end

    local success, itemData = Tables.itemTable:TryGetValue(itemId)
    if not success then
        return
    end
    local findType = false
    for _, t in ipairs(UIConst.FACTORY_QUICK_BAR_DROP_ACCEPT_INFO.types) do
        if t == itemData.type then
            findType = true
            break
        end
    end
    if not findType then
        return
    end

    local csIndex = CSIndex(targetIndex)
    FactoryUtils.SetQuickBar(typeInfo.fcType, csIndex, itemId)
end






FacQuickBarCustom._RefreshRightSide = HL.Method(HL.Boolean) << function(self, active)
    local isInSettlementDefenseDefending = Utils.isInSettlementDefenseDefending()
    local showBelt = active and self.m_args.showBelt and not isInSettlementDefenseDefending and FactoryUtils.canShowBelt()
    self.view.beltNode.gameObject:SetActive(showBelt)
    local showPipe = active and self.m_args.showPipe and not isInSettlementDefenseDefending and FactoryUtils.canShowPipe()
    self.view.pipeNode.gameObject:SetActive(showPipe)
    self.view.decoLine.gameObject:SetActive(showBelt or showPipe)
end

FacQuickBarCustom._InitLogisticNode = HL.Method(HL.Table, HL.String, HL.Function) << function(self, node, itemId, onClick)
    node.notDropHint.gameObject:SetActive(false)

    local item = node.item 
    item:SetEnableHoverTips(DeviceInfo.usingKeyboard)
    item:InitItem({ id = itemId }, onClick)
    item:AddHoverBinding("fac_quick_bar_controller_build", onClick)
    item:OpenLongPressTips()
    item.canPlace = true
    item.actionMenuArgs = {
        source = UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar,
    }

    if node.itemDragHandler then
        node.itemDragHandler.onDrag:AddListener(function(eventData)
            Notify(MessageConst.MOVE_LEVEL_CAMERA, eventData.delta)
        end)
    end

    local btn = item.view.button
    btn.onHoverChange:AddListener(function(isHover)
        if DeviceInfo.usingController then
            node.keyHint.gameObject:SetActive(not isHover)
            item.view.nameNode.gameObject:SetActive(isHover)
            node.hoverKeyHint.gameObject:SetActive(isHover)
        end
    end)
    item.view.nameNode.gameObject:SetActive(false)
    if node.hoverKeyHint then
        node.hoverKeyHint.gameObject:SetActive(false)
    end
end

FacQuickBarCustom._OnBeltUnlocked = HL.Method() << function(self)
    if self:GetUICtrl():IsHide() then
        return
    end
    self:_RefreshRightSide(true)
end

FacQuickBarCustom._OnPipeUnlocked = HL.Method() << function(self)
    if self:GetUICtrl():IsHide() then
        return
    end
    self:_RefreshRightSide(true)
end






FacQuickBarCustom._OnQuickBarChanged = HL.Method() << function(self)
    if not self.m_args then
        return 
    end
    if self:GetUICtrl():IsHide() then
        return
    end
    self:RefreshFacQuickBar()
end

FacQuickBarCustom._OnSetInSafeZone = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self:GetUICtrl():IsHide() then
        return
    end
    self:RefreshFacQuickBar()
end

FacQuickBarCustom._OnItemCountChanged = HL.Method(HL.Table) << function(self, args)
    if self:GetUICtrl():IsHide() then
        return
    end

    local itemId2DiffCount = unpack(args)
    local items = self.m_typeInfos[self.m_selectedTypeIndex].items
    for k, v in ipairs(items) do
        if itemId2DiffCount:ContainsKey(v.itemId) then
            local cell = self.m_itemCells:GetItem(k)
            local count = Utils.getItemCount(v.itemId, true, true)
            local isBuilding = v.type == QuickBarItemType.Building
            local materialEnough
            
            
            local showCount
            if isBuilding and count > 0 then
                showCount = count
            end
            if isBuilding and count == 0 then
                materialEnough = FactoryUtils.checkBuildingMaterialEnough(v.itemId)
            end
            cell.item:UpdateCount(showCount)
            if not isBuilding or count > 0 or materialEnough then
                cell.item:SetIconTransparent(UIConst.ITEM_EXIST_TRANSPARENCY)
            else
                cell.item:SetIconTransparent(UIConst.ITEM_MISSING_TRANSPARENCY)
            end
            cell.item.canPlace = count > 0
        end
    end
end

FacQuickBarCustom._OnNewScopeInfoReceived = HL.Method() << function(self)
    self:RefreshFacQuickBar()
end






FacQuickBarCustom.m_setBuildingBindingGroupId = HL.Field(HL.Number) << -1

FacQuickBarCustom.m_isSetSlot = HL.Field(HL.Boolean) << false

FacQuickBarCustom._InitSetBindings = HL.Method() << function(self)
    self.m_setBuildingBindingGroupId = InputManagerInst:CreateGroup(self.m_args.inputBindingGroup.groupId)
    self:GetUICtrl():BindInputPlayerAction("common_confirm", function()
        self:_OnConfirmSetInController()
    end, self.m_setBuildingBindingGroupId)
    self:GetUICtrl():BindInputPlayerAction("common_back", function()
        self:_OnCancelSetInController()
    end, self.m_setBuildingBindingGroupId)
    InputManagerInst:ToggleGroup(self.m_setBuildingBindingGroupId, false)
end

FacQuickBarCustom._OnConfirmSetInController = HL.Method() << function(self)
    AudioAdapter.PostEvent("Au_UI_Item_Put_Producer")
    if self.m_isSetSlot then
        self:_OnConfirmSwitchSlot()
    else
        self:_SetBuildingOnFacQuickBar()
    end
end

FacQuickBarCustom._OnCancelSetInController = HL.Method() << function(self)
    if self.m_isSetSlot then
        self:_OnCancelSwitchSlot()
    else
        self:_ExitSetBuilding()
    end
end

FacQuickBarCustom._OnEnterSetModeInController = HL.Method(HL.Table) << function(self, args)
    
    self:_DetachStaleNaviLayerIfNeeded()

    UIUtils.changeAndTrySetNaviBindingType(self.m_args.naviGroup, CS.UnityEngine.UI.NavigationBindingType.HorizontalOnly)
    InputManagerInst:ToggleGroup(self.m_setBuildingBindingGroupId, true)
    InputManagerInst:ToggleGroup(self.view.buildBtnInputBindingGroup.groupId, false)

    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
        panelId = self:GetPanelId(),
        isGroup = true,
        id = self.m_args.inputBindingGroup.groupId,
        hintPlaceholder = self.m_args.controllerSwitchArgs.hintPlaceholder,
        rectTransform = self.view.rectTransform,
        noHighlight = true,
    })

    self:_RefreshTypeList()
end

FacQuickBarCustom._OnExitSetModeInController = HL.Method(HL.Boolean) << function(self, removeLayer)
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.m_args.inputBindingGroup.groupId)
    if removeLayer then
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.m_args.naviGroup)
    end
    InputManagerInst:ToggleGroup(self.m_setBuildingBindingGroupId, false)
    InputManagerInst:ToggleGroup(self.view.buildBtnInputBindingGroup.groupId, true)
    UIUtils.changeAndTrySetNaviBindingType(self.m_args.naviGroup, CS.UnityEngine.UI.NavigationBindingType.AllDirections)
end

FacQuickBarCustom.m_curSettingBuildingItemId = HL.Field(HL.String) << ""

FacQuickBarCustom._StartSetBuildingOnFacQuickBar = HL.Method(HL.Table) << function(self, args)
    local itemId = args.itemId
    self.m_curSettingBuildingItemId = itemId
    self.view.setBuildingHint.gameObject:SetActive(true)
    self.m_isSetSlot = false

    self:_OnEnterSetModeInController(args)

    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    for k, v in ipairs(typeInfo.items) do
        if v.itemId == itemId then
            local cell = self.m_itemCells:Get(k)
            cell:SetAsNaviTarget()
            return
        end
    end

    local selectable = self:_GetDefaultSelectable()
    self:SetNaviTarget(selectable)
end

FacQuickBarCustom._SetBuildingOnFacQuickBar = HL.Method() << function(self)
    if string.isEmpty(self.m_curSettingBuildingItemId) then
        
        
        
        
        return
    end

    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    GameInstance.player.remoteFactory:SendSetQuickBar(typeInfo.fcType, 0, CSIndex(self.m_currentNaviIndex), self.m_curSettingBuildingItemId)
    self:_ExitSetBuilding()
end

FacQuickBarCustom._ExitSetBuilding = HL.Method() << function(self)
    self:_OnExitSetModeInController(true)

    self.m_curSettingBuildingItemId = ""
    self.view.setBuildingHint.gameObject:SetActive(false)
    self:_RefreshTypeList()
end

FacQuickBarCustom.m_switchSlotFromIndex = HL.Field(HL.Number) << -1

FacQuickBarCustom._StartSwitchSlotOnFacQuickBar = HL.Method(HL.Table) << function(self, args)
    self.m_isSetSlot = true
    self.m_switchSlotFromIndex = args.fromIndex

    self:_OnEnterSetModeInController(args)

    
    local fromCell = self.m_itemCells:GetItem(self.m_switchSlotFromIndex)
    fromCell.item.view.button.enabled = false
    fromCell.item:SetSelected(true)
    
    local initNaviCell = self.m_itemCells:GetItem(self.m_switchSlotFromIndex ~= 1 and 1 or 2)
    initNaviCell.item:SetAsNaviTarget()
end

FacQuickBarCustom._ExitSwitchSlot = HL.Method(HL.Boolean) << function(self, isConfirm)
    self:_OnExitSetModeInController(false)

    local fromCell = self.m_itemCells:GetItem(self.m_switchSlotFromIndex)
    self.m_switchSlotFromIndex = -1
    
    fromCell.item.view.button.enabled = true
    fromCell.item:SetSelected(false)
    if isConfirm then
        
        local currCell = self.m_itemCells:GetItem(self.m_currentNaviIndex)
        InputManagerInst:ToggleBinding(currCell.item.view.button.hoverConfirmBindingId, true)
    else
        self:SetNaviTarget(fromCell.item.view.button)
        InputManagerInst:ToggleBinding(fromCell.item.view.button.hoverConfirmBindingId, true)
    end
end

FacQuickBarCustom._OnConfirmSwitchSlot = HL.Method() << function(self)
    local typeInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    GameInstance.player.remoteFactory:SendMoveQuickBar(typeInfo.fcType, 0, CSIndex(self.m_switchSlotFromIndex), CSIndex(self.m_currentNaviIndex))
    self:_ExitSwitchSlot(true)
end

FacQuickBarCustom._OnCancelSwitchSlot = HL.Method() << function(self)
    self:_ExitSwitchSlot(false)
end






FacQuickBarCustom.m_currentNaviIndex = HL.Field(HL.Number) << -1

FacQuickBarCustom.m_lastCellsActionOnSetNaviTarget = HL.Field(HL.Table)

FacQuickBarCustom._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local naviGroup = self.m_args.naviGroup
    naviGroup.getDefaultSelectableFunc = function()
        return self:_GetDefaultSelectable()
    end
    naviGroup.onDefaultNaviFailed:AddListener(function(dir)
        self:_OnDefaultNaviFailed(dir)
    end)
    naviGroup.onIsTopLayerChanged:AddListener(function(isTopLayer)
        self:_OnIsTopLayerChanged(isTopLayer)
    end)

    self:_InitSetBindings()
end

FacQuickBarCustom._GetDefaultSelectable = HL.Method().Return(HL.Userdata) << function(self)
    if not self.m_itemCells then
        return nil
    end
    local firstCell = self.m_itemCells:Get(1)
    if not firstCell then
        return nil
    end
    return firstCell.item.view.button
end

FacQuickBarCustom._DetachStaleNaviLayerIfNeeded = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    local naviGroup = self.m_args.naviGroup
    if IsNull(naviGroup) then
        return
    end
    local naviMgr = InputManagerInst.controllerNaviManager
    if naviMgr:IsLayerInStack(naviGroup) and not naviMgr:IsTopLayer(naviGroup) then
        naviMgr:TryRemoveLayer(naviGroup)
    end
end

FacQuickBarCustom._OnDefaultNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    if not string.isEmpty(self.m_curSettingBuildingItemId) then
        return
    end
    if dir == Unity.UI.NaviDirection.Up and not self.m_args.useActiveAction then
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.m_args.naviGroup)
    end
end

FacQuickBarCustom._OnIsTopLayerChanged = HL.Method(HL.Boolean) << function(self, isTopLayer)
    if self.m_args.useActiveAction then
        self.view.simpleActiveAnimationHelper.isActive = isTopLayer
        self.view.activeKeyHint.gameObject:SetActive(not isTopLayer)
    end

    local onIsTopLayerChanged = self.m_args.onIsTopLayerChanged
    if onIsTopLayerChanged then
        onIsTopLayerChanged(isTopLayer)
    end
end

FacQuickBarCustom._ToggleCellActionOnSetNaviTarget = HL.Method(HL.Boolean) << function(self, active)
    if not active or self.m_lastCellsActionOnSetNaviTarget == nil or next(self.m_lastCellsActionOnSetNaviTarget) == nil then
        self.m_lastCellsActionOnSetNaviTarget = {}
        for index = 1, self.m_itemCells:GetCount() do
            local cell = self.m_itemCells:GetItem(index)
            self.m_lastCellsActionOnSetNaviTarget[index] = cell.item.view.button.actionOnSetNaviTarget
        end
    end

    for index = 1, self.m_itemCells:GetCount() do
        local cell = self.m_itemCells:GetItem(index)
        local action = active and self.m_lastCellsActionOnSetNaviTarget[index] or CS.Beyond.Input.ActionOnSetNaviTarget.None
        cell.item.view.button:ChangeActionOnSetNaviTarget(action)
    end
end

FacQuickBarCustom._RefreshControllerSetting = HL.Method() << function(self)
    if DeviceInfo.usingTouch then
        return
    end

    local useActiveAction = DeviceInfo.usingController and self.m_args.useActiveAction
    self.view.simpleActiveAnimationHelper.enabled = useActiveAction
    if not useActiveAction then
        self.view.animation:Play("facquickbar_default")
    end
    self.view.activeKeyHint.gameObject:SetActive(useActiveAction)

    local naviType = useActiveAction and CS.UnityEngine.UI.NavigationBindingType.RightJsHorizontalOnly or CS.UnityEngine.UI.NavigationBindingType.AllDirections
    UIUtils.changeAndTrySetNaviBindingType(self.m_args.naviGroup, naviType)
end




HL.Commit(FacQuickBarCustom)
return FacQuickBarCustom
