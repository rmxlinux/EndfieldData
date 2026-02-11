
local QuickBarItemType = FacConst.QuickBarItemType

local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacTopView






































































FacTopViewCtrl = HL.Class('FacTopViewCtrl', uiCtrl.UICtrl)






FacTopViewCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BUILD_MODE_CHANGE] = 'OnBuildModeChange',
    [MessageConst.BEFORE_ENTER_BUILD_MODE] = 'BeforeEnterBuildMode',
    [MessageConst.ON_FAC_DESTROY_MODE_CHANGE] = 'OnFacDestroyModeChange',
    [MessageConst.BEFORE_ENTER_DESTROY_MODE] = 'BeforeEnterDestroyMode',

    [MessageConst.ON_TOGGLE_QUICK_BAR_CONTROLLER] = 'OnToggleQuickBarController',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = 'OnItemCountChanged',
    [MessageConst.TOGGLE_HIDE_FAC_TOP_VIEW_RIGHT_SIDE_UI] = 'ToggleHideFacTopViewRightSideUi',

    [MessageConst.ON_QUICK_BAR_CHANGED] = 'OnQuickBarChanged',
}



FacTopViewCtrl.m_onDrag = HL.Field(HL.Function)


FacTopViewCtrl.m_typeCells = HL.Field(HL.Forward('UIListCache'))


FacTopViewCtrl.m_getItemCell = HL.Field(HL.Function)


FacTopViewCtrl.m_isCollapsed = HL.Field(HL.Boolean) << false





FacTopViewCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_onDrag = function(eventData)
        self:_OnDrag(eventData)
    end

    self.m_typeCells = UIUtils.genCellCache(self.view.typeCell)

    self.view.rotBtn.onClick:AddListener(function()
        LuaSystemManager.factory:RotateTopViewCam()
    end)
    self.view.collapseBtn.onClick:AddListener(function()
        self:_ToggleContent(false)
    end)
    self.view.expandBtn.onClick:AddListener(function()
        self:_ToggleContent(true)
    end)

    self.view.beltNode.item:InitItem({ id = FacConst.BELT_ITEM_ID }, function()
        self:_OnClickBelt()
    end)
    self.view.beltNode.item:OpenLongPressTips()
    self.view.pipeNode.item:InitItem({ id = FacConst.PIPE_ITEM_ID }, function()
        self:_OnClickPipe()
    end)
    self.view.pipeNode.item:OpenLongPressTips()

    self.m_getItemCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getItemCell(obj), LuaIndex(csIndex))
    end)

    self.view.scrollListScrollRect.onOverScrollEffect:AddListener(function(isNext)
        self:_OnOverScrollList(isNext)
    end)

    UIUtils.bindInputPlayerAction("fac_top_view_rot_cam", function()
        LuaSystemManager.factory:RotateTopViewCam()
    end, self.view.main.groupId)
    if DeviceInfo.usingKeyboard then
        UIUtils.bindInputPlayerAction("fac_open_devices_list", function()
            Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT)
        end, self.view.main.groupId)
        UIUtils.bindInputPlayerAction("fac_open_blueprint", function()
            PhaseManager:OpenPhase(PhaseId.FacBlueprint)
        end, self.view.main.groupId)
    elseif DeviceInfo.usingController then
        UIUtils.bindInputPlayerAction("fac_top_view_enter_batch_mode_ct", function()
            Notify(MessageConst.FAC_ENTER_DESTROY_MODE)
        end, self.view.main.groupId)
        self:BindInputPlayerAction("fac_top_view_ct_scale_cam", function()
            self:_OnControllerZoomCamera()
        end)
        self.view.startBuildBtn.onClick:AddListener(function()
            if self.m_isCollapsed then
                self:_ToggleContent(true)
            end
        end)
        UIUtils.bindInputPlayerAction("common_cancel", function()
            if not self.m_isCollapsed then
                self:_ToggleContent(false)
            end
        end, self.view.buildNode.groupId)

        UIUtils.bindInputPlayerAction("fac_top_view_open_building_menu", function()
            self:_ControllerOpenCurBuildingMenu()
        end, self.view.main.groupId)
        UIUtils.bindInputPlayerAction("fac_top_view_open_building_panel", function()
            self:_ControllerOpenCurBuildingPanel()
        end, self.view.main.groupId)
    end

    
    
    
    self.view.topViewToggle.isOn = true
    self.view.topViewToggle.checkIsValueValid = function(isOn)
        if not isOn then
            Notify(MessageConst.FAC_TOGGLE_TOP_VIEW, isOn)
            return false 
        end
        return true
    end

    self:_InitFilters()
    self:_InitKeyHints()
    self.view.facQuickBarClearDropZone:InitFacQuickBarClearDropZone()
end



FacTopViewCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegister()
    
    self.view.mouseHoverHint.gameObject:SetActive(false)
    self.view.controllerMouseHoverHint.gameObject:SetActive(false)

    if DeviceInfo.usingController then
        self.m_isCollapsed = false 
        self:_RefreshTypes()
        self:_ToggleContent(false, true)
        InputManagerInst:SetCustomControllerMouse(self.view.controllerMouse.transform, self.uiCamera)
        self.view.controllerMouse.gameObject:SetActive(true)
    else
        self:_RefreshTypes()
        self:_ToggleContent(true, true)
        self.view.controllerMouse.gameObject:SetActive(false)
    end
    self.view.facQuickBarClearDropZone.gameObject:SetActive(false)
end



FacTopViewCtrl.OnHide = HL.Override() << function(self)
    self:_ClearRegister()
    InputManagerInst:SetCustomControllerMouse(nil, nil)
    if not self.m_isCollapsed then
        self:_ToggleContent(false, true)
    end
end



FacTopViewCtrl.OnClose = HL.Override() << function(self)
    self:_ClearRegister()
    if LuaSystemManager.factory.inTopView then
        LuaSystemManager.factory:ToggleTopView(false, true)
    end
    self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:RecoverScreen(self.m_clearScreenKeyForControllerExpandBuildNode)
end




FacTopViewCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not DeviceInfo.usingTouch then
        
        self.view.keyHintNode.gameObject:SetActive(active)
    end
end



FacTopViewCtrl.OnQuickBarChanged = HL.Method() << function(self)
    if self:IsHide() then
        return
    end
    self.m_typeInfos[1] = self:_GenCustomTypeInfo()
    self:_RefreshItemList()
end



FacTopViewCtrl.m_controllerNaviInfo = HL.Field(HL.Table)



FacTopViewCtrl._RecordControllerNaviInfo = HL.Method() << function(self)
    self.m_controllerNaviInfo = nil
    if not DeviceInfo.usingController or self.m_isCollapsed then
        return
    end
    local tInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    self.m_controllerNaviInfo = {
        typeIndex = self.m_selectedTypeIndex,
    }
    
    local target = self.view.container.LayerSelectedTarget
    if target then
        for k, _ in pairs(tInfo.showingItems) do
            local cell = self.m_getItemCell(k)
            if cell and cell.button == target then
                self.m_controllerNaviInfo.itemIndex = k
                break
            end
        end
    end
end




FacTopViewCtrl._TryRecoverNaviInfo = HL.Method(HL.Boolean) << function(self, isRecover)
    if not DeviceInfo.usingController then
        return
    end
    if not isRecover then
        self:_ToggleContent(false, true)
        return
    end
    if not self.m_controllerNaviInfo then
        return
    end
    self.m_selectedTypeIndex = self.m_controllerNaviInfo.typeIndex
    self:_RefreshTypes()
    
    self.view.scrollList:ScrollToIndex(CSIndex(self.m_controllerNaviInfo.itemIndex), true)
    InputManagerInst.controllerNaviManager:SetTarget(self.m_getItemCell(self.m_controllerNaviInfo.itemIndex).button)
    self.m_controllerNaviInfo = nil
end






FacTopViewCtrl.OnToggleFacTopView = HL.StaticMethod(HL.Boolean) << function(active)
    if active then
        local self = UIManager:AutoOpen(PANEL_ID)
        self:_OnToggleFacTopView(true)
    else
        local _, self = UIManager:IsOpen(PANEL_ID)
        if self then
            self:_OnToggleFacTopView(false)
        end
    end
end




FacTopViewCtrl._OnToggleFacTopView = HL.Method(HL.Boolean) << function(self, active)
    if active then
        self:_ClearScreen()
        UIManager:AutoOpen(PanelId.FacTopViewBuildingInfo) 
        self.view.controllerMouse.anchoredPosition = Vector2.zero
        Notify(MessageConst.FAC_TOGGLE_TOP_VIEW_BUILDING_INFO, true)
    else
        if self.m_hideKey ~= -1 then
            self:Hide()
            self:_RecoverScreen()
            Notify(MessageConst.FAC_TOGGLE_TOP_VIEW_BUILDING_INFO, false)
        end
    end
    
    self.view.topViewToggle:SetIsOnWithoutNotify(true)
    self:_ResetFilters()
end




FacTopViewCtrl.OnFacDestroyModeChange = HL.Method(HL.Boolean) << function(self, inDestroyMode)
    self.view.main.gameObject:SetActive(not inDestroyMode)
    self:PlayAnimationIn()
    self:_TryRecoverNaviInfo(not inDestroyMode)
end




FacTopViewCtrl.OnBuildModeChange = HL.Method(HL.Number) << function(self, mode)
    local inBuild = mode ~= FacConst.FAC_BUILD_MODE.Normal
    self.view.main.gameObject:SetActive(not inBuild)
    if (mode == FacConst.FAC_BUILD_MODE.Building or mode == FacConst.FAC_BUILD_MODE.Blueprint) and not FactoryUtils.isMovingBuilding() then
        self.view.controllerMouse.anchoredPosition = Vector2.zero
    end
    if self:IsHide() then
        return
    end
    self:PlayAnimationIn()
    self:_TryRecoverNaviInfo(not inBuild)
end




FacTopViewCtrl.BeforeEnterBuildMode = HL.Method(HL.Boolean) << function(self, skipMainHudAnim)
    self:_RecordControllerNaviInfo()
    self:PlayAnimationOutWithCallback()
end



FacTopViewCtrl.BeforeEnterDestroyMode = HL.Method() << function(self)
    self:_RecordControllerNaviInfo()
    self:PlayAnimationOutWithCallback()
end




FacTopViewCtrl.OnToggleQuickBarController = HL.Method(HL.Boolean) << function(self, active)
    self:ChangePanelCfg("virtualMouseMode", active and Types.EPanelMouseMode.ForceHide or Types.EPanelMouseMode.NeedShow)
end




FacTopViewCtrl.OnItemCountChanged = HL.Method(HL.Table) << function(self, args)
    if self:IsHide() then
        return
    end
    local itemId2DiffCount = unpack(args)
    local showingItems = self.m_typeInfos[self.m_selectedTypeIndex].showingItems
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local info = showingItems[LuaIndex(csIndex)]
        if itemId2DiffCount:ContainsKey(info.itemId) then
            local cell = self.m_getItemCell(obj)
            local count = Utils.getItemCount(info.itemId)
            cell.item:UpdateCount(count)
        end
    end)
end







FacTopViewCtrl.m_hideKey = HL.Field(HL.Number) << -1



FacTopViewCtrl._ClearScreen = HL.Method() << function(self)
    if self.m_hideKey ~= -1 then
        return
    end
    local exceptedPanels = {
        PANEL_ID,
        PanelId.MainHud,
        PanelId.FacMain,
        PanelId.LevelCamera,
        PanelId.FacMiniPowerHud,
        PanelId.FacHudBottomMask,
        PanelId.FacBuildMode,
        PanelId.FacDestroyMode,
        PanelId.FacBuildingInteract,
        PanelId.CommonItemToast,
        PanelId.CommonNewToast,
        PanelId.CommonHudToast,
        PanelId.GeneralTracker,
        PanelId.Radio,
        PanelId.MiniMap,
        PanelId.MissionHud,
        PanelId.MissionHudMini,
        PanelId.CommonTaskTrackHud,
        PanelId.BlackBoxDiffBtn,
        PanelId.FacTopViewBuildingInfo,
        PanelId.FacMainRight,
    }
    if not DeviceInfo.usingTouch then
        table.insert(exceptedPanels, PanelId.Joystick)
    end
    self.m_hideKey = UIManager:ClearScreen(exceptedPanels)
end



FacTopViewCtrl._RecoverScreen = HL.Method() << function(self)
    self.m_hideKey = UIManager:RecoverScreen(self.m_hideKey)
end



FacTopViewCtrl._AddRegister = HL.Method() << function(self)
    local touchPanel = UIManager.commonTouchPanel
    touchPanel.onDrag:AddListener(self.m_onDrag)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
    self.m_updateKey = LuaUpdate:Add("TailTick", function()
        self:_TailUpdate()
    end)
end



FacTopViewCtrl._ClearRegister = HL.Method() << function(self)
    local touchPanel = UIManager.commonTouchPanel
    touchPanel.onDrag:RemoveListener(self.m_onDrag)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
end




FacTopViewCtrl._OnDrag = HL.Method(HL.Userdata) << function(self, eventData)
    if InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1) then
        
        return
    end
    if LuaSystemManager.factory.inDragSelectBatchMode and not InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse2) then
        
        return
    end
    if DeviceInfo.usingKeyboard then
        local isOpen, ctrl = UIManager:IsOpen(PanelId.FacBuildMode)
        if isOpen then
            if ctrl.m_buildingNodeId and not InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse2) then
                
                return
            end
        end
    end

    self:_Move(eventData.delta * -self.view.config.MOVE_SPD_ON_DRAG)
end




FacTopViewCtrl._Move = HL.Method(Vector2) << function(self, dir)
    LuaSystemManager.factory:MoveTopViewCamTarget(dir)
end




FacTopViewCtrl._MoveMouse = HL.Method(Vector2) << function(self, dir)
    
    local cam = CameraManager.mainCamera
    local curMousePos = InputManager.mousePosition
    local camRay = cam:ScreenPointToRay(curMousePos)
    local _, worldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(camRay)
    local camTrans = cam.transform
    local realDir = dir.x * camTrans.right + dir.y * camTrans.up
    realDir.y = 0
    worldPos = worldPos + realDir.normalized * dir.magnitude
    local targetScreenPos = cam:WorldToScreenPoint(worldPos)
    InputManager.SetMousePos(targetScreenPos:XY())
end


FacTopViewCtrl.m_updateKey = HL.Field(HL.Number) << -1



FacTopViewCtrl._TailUpdate = HL.Method() << function(self)
    
    
    if IsNull(self.view.transform) then
        return
    end

    if DeviceInfo.usingKeyboard then
        self:_UpdateMouseHintStates()
    elseif DeviceInfo.usingController then
        if not self.m_isCollapsed then
            return
        end
        if LuaSystemManager.factory.topViewControllerMouseMoveTargetChanged then
            LuaSystemManager.factory.topViewControllerMouseMoveTargetChanged = false
            local mouseWorldPos = LuaSystemManager.factory.topViewControllerMouseMoveTarget.position

            
            local curScreenWorldRect = CSFactoryUtil.GetCurScreenWorldRect(CSFactoryUtil.Padding(150, 290, 250, 150)) 
            mouseWorldPos.x = lume.clamp(mouseWorldPos.x, curScreenWorldRect.xMin, curScreenWorldRect.xMax)
            mouseWorldPos.z = lume.clamp(mouseWorldPos.z, curScreenWorldRect.yMin, curScreenWorldRect.yMax)
            LuaSystemManager.factory.topViewControllerMouseMoveTarget.position = mouseWorldPos

            local screenPos = CameraManager.mainCamera:WorldToScreenPoint(mouseWorldPos):XY()
            local screenSize = Vector2(Screen.width, Screen.height)
            local newPos = (screenPos - screenSize / 2) / Screen.width * self.view.rectTransform.rect.width
            self.view.controllerMouse.anchoredPosition = newPos
        end
        self:_UpdateControllerMouseHintStates()
    end
end







FacTopViewCtrl.m_typeInfos = HL.Field(HL.Table)


FacTopViewCtrl.m_selectedTypeIndex = HL.Field(HL.Number) << 1



FacTopViewCtrl._InitInfos = HL.Method() << function(self)
    local typeInfos = {}
    self.view.beltNode.gameObject:SetActive(GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedBelt)
    self.view.pipeNode.gameObject:SetActive(FactoryUtils.canShowPipe())

    table.insert(typeInfos, self:_GenCustomTypeInfo())

    local inventory = GameInstance.player.inventory
    local curDomainId = Utils.getCurDomainId()
    local tInfosDic = {
        ["logistic"] = self:_GetLogisticInfos()
    }
    for id, data in pairs(Tables.factoryBuildingTable) do
        local typeId = data.quickBarType
        if not string.isEmpty(typeId) then
            local itemData = FactoryUtils.getBuildingItemData(id)
            if inventory:IsItemFound(itemData.id) then
                local tInfo = tInfosDic[typeId]
                if not tInfo then
                    local typeData = Tables.factoryQuickBarTypeTable:GetValue(typeId)
                    tInfo = {
                        data = typeData,
                        priority = typeData.priority,
                        allItems = {},
                        showingItems = {},
                    }
                    tInfosDic[typeId] = tInfo
                end
                if tInfo then
                    local info = {
                        id = id,
                        itemId = itemData.id,
                        rarity = itemData.rarity,
                        sortId1 = itemData.sortId1,
                        sortId2 = itemData.sortId2,
                        type = QuickBarItemType.Building,
                    }
                    FactoryUtils.addBuildingDomainSortFilterInfo(info, data, curDomainId)
                    table.insert(tInfo.allItems, info)
                end
            end
        end
    end
    for _, info in pairs(tInfosDic) do
        table.insert(typeInfos, info)
    end

    table.sort(typeInfos, Utils.genSortFunction({ "priority" }))
    self.m_typeInfos = typeInfos
end



FacTopViewCtrl._GenCustomTypeInfo = HL.Method().Return(HL.Table) << function(self)
    local fcType = GEnums.FCQuickBarType.Inner
    local curChapterInfo = GameInstance.player.remoteFactory.core:GetCurrentChapterInfo()
    local quickBarList = curChapterInfo:GetQuickBar(fcType) 

    local typeData = Tables.factoryQuickBarTypeTable:GetValue("custom")
    local typeInfo = {
        data = typeData,
        priority = typeData.priority,
        noFilter = true,
        showingItems = {},
    }
    for _, id in pairs(quickBarList) do
        local info = {
            itemId = id,
            isCustomQuickBarItem = true,
        }
        if not string.isEmpty(id) then
            local buildingData = FactoryUtils.getItemBuildingData(id)
            if buildingData then
                info.type = QuickBarItemType.Building
            else
                info.type = QuickBarItemType.Logistic
            end
        end
        table.insert(typeInfo.showingItems, info)
    end
    return typeInfo
end




FacTopViewCtrl._GetLogisticInfos = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local typeData = Tables.factoryQuickBarTypeTable:GetValue("logistic")

    local typeInfo = {
        data = typeData,
        priority = typeData.priority,
        allItems = {},
        showingItems = {},
    }
    if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedBelt then
        for id, data in pairs(Tables.factoryGridBeltTable) do
            if id ~= FacConst.BELT_ID then
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

        if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedValve then
            for id, data in pairs(Tables.FactoryBoxValveTable) do
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

    if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedBridge then
        for id, data in pairs(Tables.factoryGridConnecterTable) do
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
        local unlockType = FacConst.LOGISTIC_UNLOCK_SYSTEM_MAP[id]
        local unlocked = false
        if unlockType == GEnums.UnlockSystemType.FacMerger then
            unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedConverger
        elseif unlockType == GEnums.UnlockSystemType.FacSplitter then
            unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedSplitter
        elseif unlockType == GEnums.UnlockSystemType.FacValve then
            unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedValve
        end
        if unlocked then
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

    
    if FactoryUtils.isDomainSupportPipe() then
        if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipe then
            for id, data in pairs(Tables.factoryLiquidPipeTable) do
                if id ~= FacConst.PIPE_ID then
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
            if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipeValve then
                for id, data in pairs(Tables.factoryFluidValveTable) do
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
        end
        if GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipeConnector then
            for id, data in pairs(Tables.factoryLiquidConnectorTable) do
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
            local unlockType = FacConst.LOGISTIC_UNLOCK_SYSTEM_MAP[id]
            local unlocked = false
            if unlockType == GEnums.UnlockSystemType.FacPipeConverger then
                unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipeConverger
            elseif unlockType == GEnums.UnlockSystemType.FacPipeSplitter then
                unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipeSplitter
            elseif unlockType == GEnums.UnlockSystemType.FacPipeValve then
                unlocked = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipeValve
            end
            if unlocked then
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

    local hasItem
    for _, v in ipairs(typeInfo.allItems) do
        hasItem = true
        local itemData = Tables.itemTable[v.itemId]
        v.rarity = itemData.rarity
        v.sortId1 = itemData.sortId1
        v.sortId2 = itemData.sortId2
    end
    if not hasItem then
        return nil
    end
    return typeInfo
end



FacTopViewCtrl._RefreshTypes = HL.Method() << function(self)
    self:_InitInfos()
    local count = #self.m_typeInfos
    self.m_selectedTypeIndex = math.min(math.max(self.m_selectedTypeIndex, 1), count)
    self.m_typeCells:Refresh(count - 1, function(cell, cellIndex)
        self:_UpdateTypeCell(cell, cellIndex + 1)
    end)
    self:_UpdateTypeCell(self.view.customTypeCell, 1) 

    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.typeList.transform)
    local bgWidth = self.view.typeList.transform.rect.width - self.view.customTypeCell.transform.rect.width
    self.view.typeNodeBG.transform.sizeDelta = Vector2(bgWidth, self.view.typeNodeBG.transform.sizeDelta.y)

    self:_OnClickType(self.m_selectedTypeIndex)
end





FacTopViewCtrl._UpdateTypeCell = HL.Method(HL.Table, HL.Number) << function(self, cell, tabIndex)
    local info = self.m_typeInfos[tabIndex]
    cell.icon:LoadSprite(info.data.icon)
    cell.iconShadow:LoadSprite(string.format("%s_shadow", info.data.icon))
    cell.text.text = info.data.name
    cell.gameObject.name = "TypeTabCell_" .. info.data.id

    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.isOn = tabIndex == self.m_selectedTypeIndex
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_OnClickType(tabIndex)
            if DeviceInfo.usingController then
                InputManagerInst.controllerNaviManager:SetTarget(self.m_getItemCell(1).button)
            end
        end
    end)
end





FacTopViewCtrl._OnClickType = HL.Method(HL.Number) << function(self, index)
    self.m_selectedTypeIndex = index
    local tInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    self:_ApplyFilter()
    self:_RefreshItemList(true)
    self.view.filterNode.gameObject:SetActive(not tInfo.noFilter)
    if self.m_isCollapsed then
        self:_ToggleContent(true)
    end

    
    local countInCache = self.m_typeCells:GetCount()
    self.m_typeCells:Update(function(cell, cellIndex)
        local tabIndex = cellIndex + 1
        cell.rightLine.gameObject:SetActive((tabIndex < index - 1) or (tabIndex > index and cellIndex ~= countInCache))
    end)

    self.view.scrollListLeftArrow.transform.localScale = index > 1 and Vector3.one or Vector3.zero
    self.view.scrollListRightArrow.transform.localScale = index < (countInCache + 1) and Vector3.one or Vector3.zero
end




FacTopViewCtrl._OnOverScrollList = HL.Method(HL.Boolean) << function(self, isNext)
    if not UIUtils.isScreenPosInRectTransform(InputManager.mousePosition, self.view.scrollList.transform, self.uiCamera) then
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
    else
        self.m_typeCells:Get(newIndex - 1).toggle.isOn = true
    end
    GameInstance.mobileMotionManager:PostEventCommonShort()
end




FacTopViewCtrl._RefreshItemList = HL.Method(HL.Opt(HL.Boolean)) << function(self, toTop)
    local tInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local count = tInfo and #tInfo.showingItems or 0
    self.view.scrollList:UpdateCount(count, toTop == true)
    self.view.scrollListEmptyNode.gameObject:SetActive(count == 0)
end





FacTopViewCtrl._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    local tInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    local info = tInfo.showingItems[index]
    local itemId = info.itemId
    local isEmpty = string.isEmpty(itemId)

    cell.gameObject.name = "Item_" .. (isEmpty and index or itemId)

    cell.button.onClick:RemoveAllListeners()
    cell.button.onLongPress:RemoveAllListeners()
    cell.dragItem.enabled = not isEmpty
    cell.dragItem:ClearEvents()
    cell.content.gameObject:SetActive(not isEmpty)
    cell.emptyNode.gameObject:SetActive(isEmpty)

    if info.isCustomQuickBarItem then
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

    local count
    if info.type == QuickBarItemType.Building then
        count = isEmpty and 0 or Utils.getItemCount(itemId)
    end 

    cell.item:InitItem({ id = itemId, count = count })
    cell.typeIcon:LoadSprite(tInfo.data.icon)

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

    local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
    if hasCraft then
        if DeviceInfo.usingController then
            InputManagerInst:CreateBindingByActionId("fac_quick_bar_controller_craft", function()
                Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { selectedId = itemId })
            end, cell.button.hoverBindingGroupId)
        else
            cell.button.onDoubleClick:AddListener(function()
                if Utils.getItemCount(itemId) == 0 then
                    Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { selectedId = itemId })
                end
            end)
        end
    end
    if DeviceInfo.usingController then
        cell.controllerKeyHint:SetActionId((hasCraft and count == 0) and "fac_quick_bar_controller_craft" or "fac_quick_bar_controller_build_top_view")
        cell.controllerKeyHint.gameObject:SetActive(cell.button.isNaviTarget)
    end

    local itemData = Tables.itemTable:GetValue(itemId)
    cell.name.text = itemData.name
    UIUtils.initUIDragHelper(cell.dragItem, {
        source = info.isCustomQuickBarItem and UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar or UIConst.UI_DRAG_DROP_SOURCE_TYPE.BuildModeSelect,
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
            if not info.isCustomQuickBarItem then
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






FacTopViewCtrl._OnQuickBarBeginDrag = HL.Method(HL.Number, HL.Opt(HL.Userdata, HL.Forward('UIDropHelper'))) << function(self, index, enterObj, enterDropHelper)
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local cell = self.m_getItemCell(obj)
        cell.button.animator:SetBool("IgnoreHighlight", true)
    end)
    self.view.clearDropZoneRoot.gameObject:SetActive(false)
end




FacTopViewCtrl._OnQuickBarDrag = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    local mousePos = eventData.position
    local inScrollRect = CS.Beyond.UI.UIUtils.IsScreenPosInRectTransform(mousePos, self.view.scrollList.transform, self.uiCamera)
    self.view.clearDropZoneRoot.gameObject:SetActive(not inScrollRect)
end







FacTopViewCtrl._OnQuickBarEndDrag = HL.Method(HL.Number, HL.Opt(HL.Userdata, HL.Forward('UIDropHelper'), HL.Any)) << function(self, index, enterObj, enterDrop, eventData)
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






FacTopViewCtrl._ToggleContent = HL.Method(HL.Boolean, HL.Opt(HL.Boolean, HL.Boolean)) << function(self, active, fastMode, isToBuildOrDesMode)
    self.m_isCollapsed = not active
    local ani = self.view.bottomNode
    if fastMode then
        if active then
            ani:SampleToInAnimationEnd()
        else
            ani:SampleToOutAnimationEnd()
        end
    else
        if active then
            ani:PlayInAnimation()
        else
            ani:PlayOutAnimation()
        end
    end
    if DeviceInfo.usingController then
        self.view.controllerMouse.gameObject:SetActive(not active)
        self.view.controllerMouseHoverHint.gameObject:SetActive(not active and self.m_lastMouseHintContent ~= nil)
        self.view.topViewToggle.gameObject:SetActive(not active)
        if active then
            
            Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                panelId = PANEL_ID,
                isGroup = true,
                id = self.view.bottomNodeInputBindingGroupMonoTarget.groupId,
                rectTransform = self.view.buildNode.transform,
                noHighlight = true,
            })
            
            self.view.scrollList:SetTop(false)
            InputManagerInst.controllerNaviManager:SetTarget(self.m_getItemCell(1).button)
            self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:ClearScreen({
                PANEL_ID, PanelId.FacTopViewBuildingInfo, PanelId.FacTopViewLowerCfg,
                PanelId.FacBuildMode, PanelId.FacDestroyMode, PanelId.CommonTaskTrackHud,
            })
        else
            Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.bottomNodeInputBindingGroupMonoTarget.groupId)
            InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.container)
            if isToBuildOrDesMode then
                
                self:_StartTimer(0, function()
                    self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:RecoverScreen(self.m_clearScreenKeyForControllerExpandBuildNode)
                end)
            else
                self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:RecoverScreen(self.m_clearScreenKeyForControllerExpandBuildNode)
            end
        end
        if fastMode then
            self.view.startBuildBtn.gameObject:SetActive(not active)
        else
            UIUtils.PlayAnimationAndToggleActive(self.view.startBuildBtnAnimationWrapper, not active)
        end
    end
    self.view.buildNode.enabled = active or not DeviceInfo.usingController
end


FacTopViewCtrl.m_clearScreenKeyForControllerExpandBuildNode = HL.Field(HL.Number) << -1





FacTopViewCtrl._OnClickItemCell = HL.Method(HL.Number, HL.Opt(Vector2)) << function(self, index, mousePosition)
    local info = self.m_typeInfos[self.m_selectedTypeIndex].showingItems[index]
    if info.type == QuickBarItemType.Building then
        local itemId = info.itemId
        local count, backpackCount = Utils.getItemCount(itemId)
        if count == 0 then
            local hasCraft = Tables.FactoryItemAsHubCraftOutcomeTable:TryGetValue(itemId)
            if hasCraft then
                if DeviceInfo.usingController then
                    Notify(MessageConst.SHOW_TOAST, InputManager.ParseTextActionId(Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_CT))
                else
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO)
                end
            else
                Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_QUICK_BAR_COUNT_ZERO_NO_JUMP)
            end
            return
        end
        Notify(MessageConst.FAC_ENTER_BUILDING_MODE, {
            itemId = itemId,
            initMousePos = mousePosition,
        })
    elseif info.type == QuickBarItemType.Belt then
        Notify(MessageConst.FAC_ENTER_BELT_MODE, {
            beltId = info.id,
            initMousePos = mousePosition,
        })
    elseif info.type == QuickBarItemType.Logistic then
        Notify(MessageConst.FAC_ENTER_LOGISTIC_MODE, {
            itemId = info.itemId,
            initMousePos = mousePosition,
        })
    end
end



FacTopViewCtrl._OnClickPipe = HL.Method() << function(self)
    Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.PIPE_ID })
end



FacTopViewCtrl._OnClickBelt = HL.Method() << function(self)
    Notify(MessageConst.FAC_ENTER_BELT_MODE, { beltId = FacConst.BELT_ID })
end







FacTopViewCtrl.m_filterInfos = HL.Field(HL.Table)


FacTopViewCtrl.m_selectedFilters = HL.Field(HL.Table)


FacTopViewCtrl.m_filterCells = HL.Field(HL.Forward('UIListCache'))



FacTopViewCtrl._InitFilters = HL.Method() << function(self)
    self.m_filterInfos = {}
    self.m_selectedFilters = {}

    local mapManager = GameInstance.player.mapManager
    for _, domainData in pairs(Tables.domainDataTable) do
        local isDomainUnlocked = false
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
    node.filterBtn.onClick:AddListener(function()
        self:_ToggleFilterList(true)
    end)
    node.filteredBtn.onClick:AddListener(function()
        self:_ToggleFilterList(true)
    end)
    node.confirmBtn.onClick:AddListener(function()
        self:_ToggleFilterList(false)
    end)
    node.list.onTriggerAutoClose:AddListener(function()
        self:_ToggleFilterList(false)
    end)
    self:_ToggleFilterList(false, true)
    node.controllerHintPlaceholder:InitControllerHintPlaceholder({node.listInputBindingGroupMonoTarget.groupId})

    self.m_filterCells = UIUtils.genCellCache(node.optionCell)
    self.m_filterCells:Refresh(#self.m_filterInfos, function(cell, index)
        local info = self.m_filterInfos[index]
        cell.name.text = info.name
        cell.icon:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT, info.icon)
        cell.toggle.isOn = false
        cell.toggle.onValueChanged:AddListener(function(isOn)
            if isOn then
                self.m_selectedFilters[info.id] = true
            else
                self.m_selectedFilters[info.id] = nil
            end
            self:_ApplyFilter()
            self:_RefreshItemList(true)
        end)
    end)
end



FacTopViewCtrl._ResetFilters = HL.Method() << function(self)
    self.m_selectedFilters = {}
    self.m_filterCells:Update(function(cell, index)
        cell.toggle:SetIsOnWithoutNotify(false)
    end)
    self:_UpdateFilterIcon()
end





FacTopViewCtrl._ToggleFilterList = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, active, skipAni)
    local node = self.view.filterNode
    if skipAni then
        node.list.gameObject:SetActive(active)
    else
        UIUtils.PlayAnimationAndToggleActive(node.listAnimationWrapper, active)
    end
    self:_UpdateFilterIcon(active)
    if DeviceInfo.usingController then
        if active then
            node.listSelectableNaviGroup:ManuallyFocus()
        else
            
            local cell = self.m_getItemCell(1)
            if cell then
                InputManagerInst.controllerNaviManager:SetTarget(cell.button)
            end
            node.listSelectableNaviGroup:ManuallyStopFocus()
        end
    end
end




FacTopViewCtrl._UpdateFilterIcon = HL.Method(HL.Opt(HL.Boolean)) << function(self, active)
    local node = self.view.filterNode
    if active == nil then
        active = node.list.gameObject.activeInHierarchy
    end
    node.confirmBtn.gameObject:SetActive(active)
    node.filterBtn.gameObject:SetActive(not active and not next(self.m_selectedFilters))
    node.filteredBtn.gameObject:SetActive(not active and next(self.m_selectedFilters) ~= nil)
end



FacTopViewCtrl._ApplyFilter = HL.Method() << function(self)
    local tInfo = self.m_typeInfos[self.m_selectedTypeIndex]
    if tInfo.noFilter then
        return
    end
    local hasFilter = next(self.m_selectedFilters) ~= nil
    tInfo.showingItems = {}
    for _, v in ipairs(tInfo.allItems) do
        if hasFilter then
            if v.recommendDomains and next(v.recommendDomains) then
                for _, domainId in ipairs(v.recommendDomains) do
                    if self.m_selectedFilters[domainId] then
                        table.insert(tInfo.showingItems, v)
                        break
                    end
                end
            else
                table.insert(tInfo.showingItems, v)
            end
        else
            table.insert(tInfo.showingItems, v)
        end
    end
    table.sort(tInfo.showingItems, Utils.genSortFunction({ "domainReverseSort", "sortId1", "sortId2", "rarity" }, true))
end






local MouseHints = {
    building = {
        normal = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_BUILDING",
        des = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_BUILDING_DES",
    },
    pending = {
        normal = "LUA_FAC_TOP_VIEW_MOUSE_HOVER_HINT_PENDING",
        des = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_BUILDING_DES",
    },
    belt = {
        normal = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_LOGISTIC",
        des = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_BELT_DES",
    },
    logistic = {
        normal = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_LOGISTIC",
        des = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_BUILDING_DES",
    },
    pipe = {
        normal = "FAC_TOP_VIEW_MOUSE_HOVER_HINT_LOGISTIC",
        des = "LUA_FAC_TOP_VIEW_MOUSE_HOVER_HINT_PIPE_DES",
    },
}

local ControllerMouseHints = {
    normal = { "fac_top_view_open_building_menu", "fac_top_view_open_building_panel" },

    
    batchSelect = { "fac_batch_select", },
    batchSelectBeltOrPipe = { "fac_batch_select", "fac_batch_select_single_grid" },

    
    newBuilding = { "fac_build_confirm_in_top_view", "fac_build_continuous_confirm", "fac_rotate_device", "fac_build_cancel", },
    newBuildingCantRotate = { "fac_build_confirm_in_top_view", "fac_build_continuous_confirm", "fac_build_cancel", },
    oldBuilding = { "fac_build_confirm_in_top_view", "fac_rotate_device", "fac_build_mode_delete", "fac_build_cancel", },
    oldBuildingCantDes = { "fac_build_confirm_in_top_view", "fac_rotate_device", "fac_build_cancel", },
    beltStart = { "fac_build_confirm_belt_start_in_top_view", "fac_build_rotate_belt", "fac_build_cancel", },
    beltEnd = { "fac_build_confirm_belt_end_in_top_view", "fac_build_rotate_belt", "fac_build_cancel", },
    pipeStart = { "fac_build_confirm_belt_start_in_top_view", "fac_build_rotate_pipe", "fac_build_cancel", },
    pipeEnd = { "fac_build_confirm_belt_end_in_top_view", "fac_build_rotate_pipe", "fac_build_cancel", },
    blueprint = { "fac_build_confirm_in_top_view", "fac_rotate_device", "fac_build_cancel", },
}


FacTopViewCtrl.m_lastMouseHintContent = HL.Field(HL.Any)


FacTopViewCtrl.m_controllerMouseHoverHintCells = HL.Field(HL.Forward('UIListCache'))



FacTopViewCtrl._UpdateMouseHintStates = HL.Method() << function(self)
    
    local ctrl = LuaSystemManager.factory.interactPanelCtrl
    local content
    if UIManager.commonTouchPanel.isPointerEntered and not ctrl:IsDraggingInBatchMode() then
        if ctrl.m_interactPipeNodeId then
            if FactoryUtils.isPendingBuildingNode(ctrl.m_interactPipeNodeId) then
                content = MouseHints.pending
            else
                content = MouseHints.pipe
            end
        elseif ctrl.m_interactFacNodeId then
            if FactoryUtils.isPendingBuildingNode(ctrl.m_interactFacNodeId) or not FactoryUtils.canMoveBuilding(ctrl.m_interactFacNodeId) then
                content = MouseHints.pending
            else
                if ctrl.m_interactFacNodeIdIsBuilding then
                    content = MouseHints.building
                else
                    content = MouseHints.logistic
                end
            end
        elseif ctrl.m_interactLogisticPos then
            local succ, nodeId, unitIndex = GameInstance.remoteFactoryManager:TrySampleConveyor(ctrl.m_interactLogisticPos)
            if FactoryUtils.isPendingBuildingNode(nodeId) then
                content = MouseHints.pending
            else
                content = MouseHints.belt
            end
        end
        if content then
            content = LuaSystemManager.factory.inDestroyMode and content.des or content.normal
        end
    end
    if content ~= self.m_lastMouseHintContent then
        self.m_lastMouseHintContent = content
        if content then
            self.view.mouseHoverHint.gameObject:SetActiveIfNecessary(true)
            self.view.mouseHoverHint.text.text = Language[content]
        else
            self.view.mouseHoverHint.gameObject:SetActiveIfNecessary(false)
        end
    end
end



FacTopViewCtrl._UpdateControllerMouseHintStates = HL.Method() << function(self)
    
    local ctrl = LuaSystemManager.factory.interactPanelCtrl
    local actionIds
    if LuaSystemManager.factory.inDestroyMode then
        
        if not ctrl:IsDraggingInBatchMode() then
            if ctrl.m_interactLogisticPos or ctrl.m_interactPipeNodeId then
                local nodeId, _
                if ctrl.m_interactLogisticPos then
                    _, nodeId, _ = GameInstance.remoteFactoryManager:TrySampleConveyor(ctrl.m_interactLogisticPos)
                else
                    nodeId = ctrl.m_interactPipeNodeId
                end
                if FactoryUtils.isPendingBuildingNode(nodeId) then
                    actionIds = ControllerMouseHints.batchSelect
                else
                    actionIds = ControllerMouseHints.batchSelectBeltOrPipe
                end
            elseif ctrl.m_interactFacNodeId then
                actionIds = ControllerMouseHints.batchSelect
            end
        end
    else
        local _, buildModeCtrl = UIManager:IsOpen(PanelId.FacBuildMode)
        if buildModeCtrl and buildModeCtrl.m_mode ~= FacConst.FAC_BUILD_MODE.Normal then
            
            local mode = buildModeCtrl.m_mode
            if mode == FacConst.FAC_BUILD_MODE.Building then
                if buildModeCtrl.m_buildingNodeId then
                    actionIds = FactoryUtils.canDelBuilding(buildModeCtrl.m_buildingNodeId) and ControllerMouseHints.oldBuilding or ControllerMouseHints.oldBuildingCantDes
                else
                    actionIds = ControllerMouseHints.newBuilding
                end
            elseif mode == FacConst.FAC_BUILD_MODE.Logistic then
                if buildModeCtrl:_CanRotate() then
                    actionIds = ControllerMouseHints.newBuilding
                else
                    actionIds = ControllerMouseHints.newBuildingCantRotate
                end
            elseif mode == FacConst.FAC_BUILD_MODE.Belt then
                local isPipe = buildModeCtrl:_IsPipe()
                local hasStart = GameInstance.remoteFactoryManager.interact.currentConveyorMode.hasStart
                if isPipe then
                    actionIds = hasStart and ControllerMouseHints.pipeEnd or ControllerMouseHints.pipeStart
                else
                    actionIds = hasStart and ControllerMouseHints.beltEnd or ControllerMouseHints.beltStart
                end
            elseif mode == FacConst.FAC_BUILD_MODE.Blueprint then
                actionIds = ControllerMouseHints.blueprint
            end
        else
            
            if ctrl.m_interactFacNodeId or ctrl.m_interactLogisticPos or ctrl.m_interactPipeNodeId then
                actionIds = ControllerMouseHints.normal
            end
        end
    end
    self:_RefreshControllerMouseHints(actionIds)
end




FacTopViewCtrl._RefreshControllerMouseHints = HL.Method(HL.Opt(HL.Table)) << function(self, actionIds)
    if actionIds == self.m_lastMouseHintContent then
        return
    end
    self.m_lastMouseHintContent = actionIds
    if not actionIds then
        self.view.controllerMouseHoverHint.gameObject:SetActiveIfNecessary(false)
        return
    end
    self.view.controllerMouseHoverHint.gameObject:SetActiveIfNecessary(true)
    if not self.m_controllerMouseHoverHintCells then
        self.m_controllerMouseHoverHintCells = UIUtils.genCellCache(self.view.controllerMouseHoverHint.keyHint)
    end
    self.m_controllerMouseHoverHintCells:Refresh(#actionIds, function(cell, index)
        local id = actionIds[index]
        cell.actionKeyHint:SetActionId(id)
        cell.gameObject.name = "KeyHint-" .. id
    end)
end








FacTopViewCtrl._InitKeyHints = HL.Method() << function(self)
    if DeviceInfo.usingTouch then
        self.view.keyHintNode.gameObject:SetActive(false)
        return
    end
    local actionNames
    if DeviceInfo.usingController then
        actionNames = {
            "fac_top_view_ct_move",
            "fac_top_view_ct_move_cam",
            "fac_top_view_ct_scale_cam",
            "fac_top_view_rot_cam",
            "fac_top_view_enter_batch_mode_ct",
        }
    elseif DeviceInfo.usingKeyboard then
        actionNames = {
            "fac_top_view_rot_cam",
        }
    end
    local keyHintCells = UIUtils.genCellCache(self.view.keyHintCell)
    keyHintCells:Refresh(#actionNames, function(cell, index)
        local actionId = actionNames[index]
        cell.actionKeyHint:SetActionId(actionId)
        cell.gameObject.name = "KeyHint-" .. actionId
    end)
    self.view.keyHintNode.gameObject:SetActive(true)
end








FacTopViewCtrl._OnControllerZoomCamera = HL.Method() << function(self)
    local delta = InputManagerInst:GetGamepadStickValue(false).y * self.view.config.CONTROLLER_ZOOM_CAMERA_SPD * -Time.deltaTime
    Notify(MessageConst.ZOOM_LEVEL_CAMERA, delta)
end



FacTopViewCtrl._ControllerOpenCurBuildingPanel = HL.Method() << function(self)
    
    
    local _, facInteract = UIManager:IsOpen(PanelId.FacBuildingInteract)
    facInteract:_OnClickScreen(nil)
end



FacTopViewCtrl._ControllerOpenCurBuildingMenu = HL.Method() << function(self)
    
    
    local _, facInteract = UIManager:IsOpen(PanelId.FacBuildingInteract)

    local hasTarget
    local actions = {}
    table.insert(actions, {
        objName = "Open",
        text = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_OPEN,
        action = function()
            self:_ControllerOpenCurBuildingPanel()
        end,
    })
    if facInteract.m_interactFacNodeId and not facInteract.m_interactPipeNodeId then
        hasTarget = true
        local nodeId = facInteract.m_interactFacNodeId
        if facInteract.m_interactFacNodeIdIsBuilding then
            if FactoryUtils.canMoveBuilding(nodeId) then
                table.insert(actions, {
                    objName = "Move",
                    text = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_MOVE,
                    action = function()
                        Notify(MessageConst.FAC_ENTER_BUILDING_MODE, { nodeId = nodeId })
                    end,
                })
            end
        end
        if FactoryUtils.canDelBuilding(nodeId) then
            table.insert(actions, {
                objName = "Del",
                text = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL,
                action = function()
                    FactoryUtils.delBuilding(nodeId)
                end,
            })
        end
    else
        local nodeId, unitIndex
        if facInteract.m_interactPipeNodeId then
            hasTarget = true
            nodeId = facInteract.m_interactPipeNodeId
            unitIndex = facInteract.m_interactPipeUnitIndex
        elseif facInteract.m_interactLogisticPos then
            hasTarget = true
            _, nodeId, unitIndex = GameInstance.remoteFactoryManager:TrySampleConveyor(facInteract.m_interactLogisticPos)
        end
        if nodeId and FactoryUtils.canDelBuilding(nodeId) then
            table.insert(actions, {
                objName = "DelWhole",
                text = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL_WHOLE,
                action = function()
                    GameInstance.player.remoteFactory.core:Message_OpDismantle(Utils.getCurrentChapterId(), nodeId)
                end,
            })
            table.insert(actions, {
                objName = "DelOneGrid",
                text = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL_ONE_GRID,
                action = function()
                    GameInstance.remoteFactoryManager:DismantleUnitFromConveyor(Utils.getCurrentChapterId(), nodeId, unitIndex)
                end,
            })
        end
    end
    if not hasTarget then
        return
    end

    local effect = facInteract.m_hoverInteractHighlightEffect
    local posList = {
        effect.corner1.transform.position,
        effect.corner2.transform.position,
        effect.corner3.transform.position,
        effect.corner4.transform.position,
    }
    
    local min = effect.corner1.transform.position
    local max = effect.corner1.transform.position
    for _, v in ipairs(posList) do
        min.x = math.min(min.x, v.x)
        min.y = math.min(min.y, v.y)
        min.z = math.min(min.z, v.z)

        max.x = math.max(max.x, v.x)
        max.y = math.max(max.y, v.y)
        max.z = math.max(max.z, v.z)
    end
    min = CameraManager.mainCamera:WorldToScreenPoint(min)
    max = CameraManager.mainCamera:WorldToScreenPoint(max)
    
    local size = max - min
    size.x = math.abs(size.x)
    size.y = math.abs(size.y)
    min.x = math.min(min.x, max.x)
    min.y = math.min(min.y, max.y)
    max = min + size
    local targetScreenRect = Unity.Rect(min.x, Screen.height - (min.y + size.y), size.x, size.y)

    Notify(MessageConst.SHOW_NAVI_TARGET_ACTION_MENU, {
        targetScreenRect = targetScreenRect, 
        actions = actions,
        
        
        noMask = false,
        
    })
end




FacTopViewCtrl.ToggleHideFacTopViewRightSideUi = HL.Method(HL.Boolean) << function(self, isHide)
    self.view.rightSideNode.gameObject:SetActive(not isHide)
    if DeviceInfo.usingController then
        self.view.controllerMouse.gameObject:SetActive(not isHide)
        self.view.controllerMouseHoverHint.gameObject:SetActive(not isHide and self.m_lastMouseHintContent ~= nil)
    end
end




HL.Commit(FacTopViewCtrl)
