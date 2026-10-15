local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacTopView
local TARGET_TYPE_NAME = {
    [FacConst.FAC_INTERACT_TARGET_TYPE.Building] = "building",
    [FacConst.FAC_INTERACT_TARGET_TYPE.Logistic] = "logistic",
    [FacConst.FAC_INTERACT_TARGET_TYPE.Pipe] = "pipe",
    [FacConst.FAC_INTERACT_TARGET_TYPE.Belt] = "belt",
}
FacTopViewCtrl = HL.Class('FacTopViewCtrl', uiCtrl.UICtrl)





FacTopViewCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BUILD_MODE_CHANGE] = 'OnBuildModeChange',
    [MessageConst.BEFORE_ENTER_BUILD_MODE] = 'BeforeEnterBuildMode',
    [MessageConst.ON_FAC_DESTROY_MODE_CHANGE] = 'OnFacDestroyModeChange',
    [MessageConst.BEFORE_ENTER_DESTROY_MODE] = 'BeforeEnterDestroyMode',

    [MessageConst.ON_TOGGLE_QUICK_BAR_CONTROLLER] = 'OnToggleQuickBarController',
    [MessageConst.TOGGLE_HIDE_FAC_TOP_VIEW_RIGHT_SIDE_UI] = 'ToggleHideFacTopViewRightSideUi',

    [MessageConst.ON_FAC_SIMPLE_FIGURE_MODE_CHANGE] = 'OnFacSimpleFigureModeChange',

    [MessageConst.FAC_TOPVIEW_SHOW_MULTI_TARGET_MENU] = '_ShowMultiTargetMenu',
    [MessageConst.FAC_TOPVIEW_HIDE_MULTI_TARGET_MENU] = '_HideMultiTargetMenu',
}


FacTopViewCtrl.m_facHudPanelConfig = HL.Field(HL.Table)

FacTopViewCtrl.m_onDrag = HL.Field(HL.Function)

FacTopViewCtrl.m_quickBarHost = HL.Field(HL.Forward("UIWidgetHost"))

FacTopViewCtrl.m_quickBar = HL.Field(HL.Forward("FacQuickBarBase"))

FacTopViewCtrl.m_escExitBindingId = HL.Field(HL.Number) << -1

FacTopViewCtrl.m_keyHintCells = HL.Field(HL.Forward('UIListCache'))

FacTopViewCtrl.m_multiTargetCells = HL.Field(HL.Forward('UIListCache'))

FacTopViewCtrl.m_menuHoverEffect = HL.Field(HL.Table)

FacTopViewCtrl.m_multiTargetMenuGridPos = HL.Field(HL.Any)



FacTopViewCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_UpdateFacHudConfig()

    self.m_onDrag = function(eventData)
        self:_OnDrag(eventData)
    end

    self:_InitQuickBar()

    self.view.rotBtn.onClick:AddListener(function()
        LuaSystemManager.factory:RotateTopViewCam()
    end)

    if self.view.hidePipeToggle then
        self.view.hidePipeToggle.toggle.onValueChanged:AddListener(function(isOn)
            local fac = LuaSystemManager.factory
            if isOn then
                fac:SetSimpleFigureMode(FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure)
            elseif fac.simpleFigureMode == FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure then
                fac:SetSimpleFigureMode(FacConst.SIMPLE_FIGURE_MODE.None)
            end
        end)
    end

    self:BindInputPlayerAction("fac_top_view_rot_cam", function()
        LuaSystemManager.factory:RotateTopViewCam()
    end, self.view.main.groupId)
    if DeviceInfo.usingKeyboard then
        self:BindInputPlayerAction("fac_open_devices_list", function()
            Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = false, showLastType = true })
        end, self.view.main.groupId)
        self:BindInputPlayerAction("fac_open_blueprint", function()
            PhaseManager:OpenPhase(PhaseId.FacBlueprint)
        end, self.view.main.groupId)
        self.m_escExitBindingId = self:BindInputPlayerAction("fac_exit_top_view_mode_pc_esc", function()
            
            if GameSettingUtils.GetSettingValueBool(GameSettingConst.SETTING_ID_FAC_TOP_VIEW_ESC_EXIT) and InputManagerInst:IsBindingEnabled(self.view.topViewToggle.toggleBindingId) then
                Notify(MessageConst.FAC_TOGGLE_TOP_VIEW, false)
            end
        end, self.view.main.groupId)
    elseif DeviceInfo.usingController then
        self:BindInputPlayerAction("fac_top_view_enter_batch_mode_ct", function()
            Notify(MessageConst.FAC_ENTER_DESTROY_MODE)
        end, self.view.main.groupId)
        self:BindInputPlayerAction("fac_top_view_ct_scale_cam", function()
            self:_OnControllerZoomCamera()
        end)
        self.view.startBuildBtn.onClick:AddListener(function()
            self:_ToggleContent(true)
        end)

        self:BindInputPlayerAction("fac_top_view_open_building_menu", function()
            self:_ControllerOpenCurBuildingMenu()
        end, self.view.main.groupId)
        self:BindInputPlayerAction("fac_top_view_open_building_panel", function()
            self:_ControllerOpenCurBuildingPanel()
        end, self.view.main.groupId)
        self:BindInputPlayerAction("fac_top_view_move_building", function()
            self:_ControllerMoveCurBuilding()
        end, self.view.main.groupId)
    end

    
    
    
    self.view.topViewToggle.isOn = true
    self.view.topViewToggle.checkIsValueValid = function(isOn)
        if not isOn then
            Notify(MessageConst.FAC_TOGGLE_TOP_VIEW, false)
            return false 
        end
        return true
    end

    self:_InitKeyHints()

    self.m_multiTargetCells = self.m_multiTargetCells or UIUtils.genCellCache(self.view.multiTargetMenuNode.btnCell)
    self.view.multiTargetMenuNode.content.onTriggerAutoClose:AddListener(function()
        self:_HideMultiTargetMenu()
    end)
    self.view.multiTargetMenuNode.gameObject:SetActive(false)

    if not self.m_menuHoverEffect then
        local prefab = self.loader:LoadGameObject(FacConst.BUILDING_INTERACT_HOVER_INDICATOR_PATH)
        self.m_menuHoverEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_menuHoverEffect.gameObject.name = "MenuHoverEffect"
        self.m_menuHoverEffect.gameObject:SetActive(false)
    end
end

FacTopViewCtrl._UpdateFacHudConfig = HL.Method() << function(self)
    self.m_facHudPanelConfig = LuaSystemManager.factoryHud:GetFacHudPanelConfig(PANEL_ID)
end

FacTopViewCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegister()
    
    self.view.mouseHoverHint.gameObject:SetActive(false)
    self.view.controllerMouseHoverHint.gameObject:SetActive(false)

    self.m_quickBar:RefreshFacQuickBar()
    if DeviceInfo.usingController then
        self:_ToggleContent(false, true)
        InputManagerInst:SetCustomControllerMouse(self.view.controllerMouse.transform, self.uiCamera)
        self.view.controllerMouse.gameObject:SetActive(true)
        self:_TryRecoverNaviInfo(true)
    else
        self:_ToggleContent(true, true)
        self.view.controllerMouse.gameObject:SetActive(false)
    end
    self:_SyncHidePipeToggleFromFacSystem()
end

FacTopViewCtrl.OnFacSimpleFigureModeChange = HL.Method(HL.Opt(HL.Number)) << function(self, mode)
    self:_SyncHidePipeToggleFromFacSystem()
end

FacTopViewCtrl._SyncHidePipeToggleFromFacSystem = HL.Method() << function(self)
    if not self.view.hidePipeToggle then
        return
    end
    local show = FactoryUtils.canShowPipe()
    self.view.hidePipeToggle.gameObject:SetActive(show)
    if not show then
        return
    end
    local on = LuaSystemManager.factory.simpleFigureMode == FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure
    self.view.hidePipeToggle.toggle:SetIsOnWithoutNotify(on)
end

FacTopViewCtrl.OnHide = HL.Override() << function(self)
    self:_RecordControllerNaviInfo()
    self:_ClearRegister()
    self:_HideMultiTargetMenu()
    InputManagerInst:SetCustomControllerMouse(nil, nil)
    self:_ToggleContent(false, true)
end

FacTopViewCtrl.OnClose = HL.Override() << function(self)
    self:_ClearRegister()
    if LuaSystemManager.factory.inTopView then
        LuaSystemManager.factory:ToggleTopView(false, true)
    end
    self:_RecoverScreen()
    self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:RecoverScreen(self.m_clearScreenKeyForControllerExpandBuildNode)
end

FacTopViewCtrl.ExtractHotSwitchRuntimeState = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if not self.m_quickBarHost and
        not self.m_multiTargetCells and
        not self.m_keyHintCells and
        not self.m_controllerMouseHoverHintCells and
        not self.m_menuHoverEffect then
        return nil
    end

    local state = {
        quickBarHost = self.m_quickBarHost,
        quickBarHostState = self.m_quickBarHost and self.m_quickBarHost:ExtractHotSwitchRuntimeState(),
        multiTargetCells = self.m_multiTargetCells,
        keyHintCells = self.m_keyHintCells,
        controllerMouseHoverHintCells = self.m_controllerMouseHoverHintCells,
        menuHoverEffect = self.m_menuHoverEffect,
    }

    self.m_quickBarHost = nil
    self.m_multiTargetCells = nil
    self.m_keyHintCells = nil
    self.m_controllerMouseHoverHintCells = nil
    self.m_menuHoverEffect = nil

    return state
end

FacTopViewCtrl.RestoreHotSwitchRuntimeState = HL.Override(HL.Opt(HL.Any)) << function(self, state)
    if not state then
        return
    end

    self.m_quickBarHost = state.quickBarHost
    if self.m_quickBarHost then
        self.m_quickBarHost:SetCtrl(self)
        self.m_quickBarHost:RestoreHotSwitchRuntimeState(state.quickBarHostState)
    end
    self.m_multiTargetCells = state.multiTargetCells
    self.m_keyHintCells = state.keyHintCells
    self.m_controllerMouseHoverHintCells = state.controllerMouseHoverHintCells
    self.m_menuHoverEffect = state.menuHoverEffect
end

FacTopViewCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not DeviceInfo.usingTouch then
        
        self.view.keyHintNode.gameObject:SetActive(active)
    end
end

FacTopViewCtrl.m_controllerNaviInfo = HL.Field(HL.Table)

FacTopViewCtrl._RecordControllerNaviInfo = HL.Method() << function(self)
    self.m_controllerNaviInfo = nil
    if not DeviceInfo.usingController or not self.m_quickBar:IsActive() then
        return
    end
    self.m_controllerNaviInfo = {}
    self.m_quickBar:RecordControllerNaviInfo(self.m_controllerNaviInfo)
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
    self.m_quickBar:TryRecoverControllerNaviInfo(self.m_controllerNaviInfo)
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

FacTopViewCtrl.RecoverControllerMouseOnChangeDevice = HL.Method(Vector3) << function(self, mouseWorldPos)
    if not DeviceInfo.usingController then
        return
    end
    self:_SetControllerMouseWorldPos(mouseWorldPos)
end

FacTopViewCtrl._SetControllerMouseWorldPos = HL.Method(Vector3) << function(self, mouseWorldPos)
    local curScreenWorldRect = CSFactoryUtil.GetCurScreenWorldRect(FacConst.FAC_TOP_VIEW_CONTROLLER_MOUSE_PADDING)
    mouseWorldPos.x = lume.clamp(mouseWorldPos.x, curScreenWorldRect.xMin, curScreenWorldRect.xMax)
    mouseWorldPos.z = lume.clamp(mouseWorldPos.z, curScreenWorldRect.yMin, curScreenWorldRect.yMax)
    LuaSystemManager.factory.topViewControllerMouseMoveTarget.position = mouseWorldPos
    LuaSystemManager.factory.topViewControllerMouseMoveTargetChanged = true

    local screenPos = CameraManager.mainCamera:WorldToScreenPoint(mouseWorldPos):XY()
    local screenSize = Vector2(Screen.width, Screen.height)
    local newPos = (screenPos - screenSize / 2) / Screen.width * self.view.rectTransform.rect.width
    self.view.controllerMouse.anchoredPosition = newPos
end

FacTopViewCtrl.BeforeEnterBuildMode = HL.Method(HL.Boolean) << function(self, skipMainHudAnim)
    self:_HideMultiTargetMenu()
    self:_RecordControllerNaviInfo()
    self:PlayAnimationOutWithCallback()

    
    
    self.view.controllerMouseHoverHint.gameObject:SetActive(false)
end

FacTopViewCtrl.BeforeEnterDestroyMode = HL.Method() << function(self)
    self:_HideMultiTargetMenu()
    self:_RecordControllerNaviInfo()
    self:PlayAnimationOutWithCallback()
end

FacTopViewCtrl.OnToggleQuickBarController = HL.Method(HL.Boolean) << function(self, active)
    self:ChangePanelCfg("virtualMouseMode", active and Types.EPanelMouseMode.ForceHide or Types.EPanelMouseMode.NeedShow)
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
        PanelId.FacTopHud,
        PanelId.FacHudBottomMask,
        PanelId.FacPowerPoleTravelHint,
        PanelId.FacPowerPoleAutoConnectHint,
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
        PanelId.SNSHud,
        PanelId.CommonTaskTrackHud,
        PanelId.BlackBoxDiffBtn,
        PanelId.FacTopViewBuildingInfo,
        PanelId.FacMainRight,
        PanelId.InnRecipeHud,
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
        if LuaSystemManager.factory:GetMovingBuildingNodeId() and not InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse2) then
            
            return
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
    if not CS.UnityEngine.Application.isFocused then return end

    if DeviceInfo.usingKeyboard then
        self:_UpdateMouseHintStates()
    elseif DeviceInfo.usingController then
        if self.m_quickBar:IsActive() then
            return
        end
        if LuaSystemManager.factory.topViewControllerMouseMoveTargetChanged then
            LuaSystemManager.factory.topViewControllerMouseMoveTargetChanged = false
            local mouseWorldPos = LuaSystemManager.factory.topViewControllerMouseMoveTarget.position

            
            local curScreenWorldRect = CSFactoryUtil.GetCurScreenWorldRect(FacConst.FAC_TOP_VIEW_CONTROLLER_MOUSE_PADDING)
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






FacTopViewCtrl._InitQuickBar = HL.Method() << function(self)
    if not self.m_quickBarHost then
        self.m_quickBarHost = UIUtils.initWidgetHost(self, self.view.main.transform)
    end

    local quickBarConfig = self.m_facHudPanelConfig.quickBar
    local quickBar = self.m_quickBarHost:Load(quickBarConfig.prefabPath)
    if self.m_quickBar == quickBar then
        return
    end

    self.m_quickBar = quickBar
    self.m_quickBar.view.gameObject.name = "BottomNode" 

    local quickBarArgs = {
        onActiveStateChange = function(...)
            self:_OnQuickBarActiveChange(...)
        end,
    } 
    self.m_quickBar:InitFacQuickBar(quickBarArgs)
end

FacTopViewCtrl._ToggleContent = HL.Method(HL.Boolean, HL.Opt(HL.Boolean, HL.Boolean)) << function(self, active, fastMode, isToBuildOrDesMode)
    local args = {
        fastMode = fastMode,
        isToBuildOrDesMode = isToBuildOrDesMode,
    }
    if active then
        self.m_quickBar:Activate(args)
    else
        self.m_quickBar:Deactivate(args)
    end
end

FacTopViewCtrl._OnQuickBarActiveChange = HL.Method(HL.Boolean, HL.Opt(HL.Any)) << function(self, active, args)
    local fastMode = args and args.fastMode
    local isToBuildOrDesMode = args and args.isToBuildOrDesMode

    if DeviceInfo.usingController then
        self.view.controllerMouse.gameObject:SetActive(not active)
        self.view.controllerMouseHoverHint.gameObject:SetActive(not active and self.m_lastMouseHintContent ~= nil)
        self.view.topViewToggle.gameObject:SetActive(not active)
        self.view.hidePipeToggle.gameObject:SetActive(FactoryUtils.canShowPipe() and not active)
        if active then
            self.m_clearScreenKeyForControllerExpandBuildNode = UIManager:ClearScreen({
                PANEL_ID, PanelId.FacTopViewBuildingInfo, PanelId.FacTopViewLowerCfg,
                PanelId.FacBuildMode, PanelId.FacDestroyMode, PanelId.CommonTaskTrackHud,
                PanelId.FacPowerPoleLinkingLabel, PanelId.FacPowerPoleTravelHint,
                PanelId.FacPowerPoleAutoConnectHint,
            })
        else
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
end

FacTopViewCtrl.m_clearScreenKeyForControllerExpandBuildNode = HL.Field(HL.Number) << -1






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
    multiTarget = {
        normal = "LUA_FAC_TOP_VIEW_MOUSE_HOVER_HINT_MULTI_TARGET",
    },
}

local ControllerMouseHints = {
    normal = { "fac_top_view_open_building_menu", "fac_top_view_move_building", "fac_top_view_open_building_panel" },
    normalNoMove = { "fac_top_view_open_building_menu", "fac_top_view_open_building_panel" },

    
    batchSelect = { "fac_batch_select", },
    batchSelectBeltOrPipe = { "fac_batch_select", "fac_batch_select_single_grid" },

    
    newBuilding = { "fac_build_confirm_in_top_view", "fac_build_continuous_confirm", "fac_rotate_device", "fac_build_cancel", },
    newBuildingCantRotate = { "fac_build_confirm_in_top_view", "fac_build_continuous_confirm", "fac_build_cancel", },
    oldBuilding = { "fac_build_confirm_in_top_view", "fac_rotate_device", "fac_build_mode_delete_in_top_view", "fac_build_cancel", },
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
    local output = LuaSystemManager.factoryInteract:GetCurrentTargetOutput()
    local content
    if self:_IsHoveringMultiTargetMenuGrid() then
        content = nil
    elseif UIManager.commonTouchPanel.isPointerEntered
            and not LuaSystemManager.factoryInteract:IsDraggingInBatchMode() then
        local targetCount = 0
        local pipe = output and output.pipe
        if pipe then
            targetCount = targetCount + 1
            if FactoryUtils.isPendingBuildingNode(pipe.nodeId) then
                content = MouseHints.pending
            else
                content = MouseHints.pipe
            end
        end
        local building = output and output.building
        if building then
            targetCount = targetCount + 1
            if FactoryUtils.isPendingBuildingNode(building.nodeId)
                    or not FactoryUtils.canMoveBuilding(building.nodeId) then
                content = content or MouseHints.pending
            else
                if building.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
                    content = content or MouseHints.building
                else
                    content = content or MouseHints.logistic
                end
            end
        end
        local overlapBuildings = output and output.overlapBuildings
        if overlapBuildings then
            
            targetCount = targetCount + #overlapBuildings
        end
        local belt = output and output.belt
        if belt then
            targetCount = targetCount + 1
            if FactoryUtils.isPendingBuildingNode(belt.nodeId) then
                content = content or MouseHints.pending
            else
                content = content or MouseHints.belt
            end
        end
        if targetCount > 1 and not LuaSystemManager.factory.inDestroyMode then
            content = MouseHints.multiTarget
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
    local output = LuaSystemManager.factoryInteract:GetCurrentTargetOutput()
    if self:_IsMultiTargetMenuShowing() then
        self:_RefreshControllerMouseHints(nil)
        return
    end
    local actionIds
    if LuaSystemManager.factory.inDestroyMode then
        
        if not LuaSystemManager.factoryInteract:IsDraggingInBatchMode() then
            local belt = output and output.belt
            local pipe = output and output.pipe
            local building = output and output.building
            if belt or pipe then
                local nodeId = belt and belt.nodeId or pipe.nodeId
                if FactoryUtils.isPendingBuildingNode(nodeId) then
                    actionIds = ControllerMouseHints.batchSelect
                else
                    actionIds = ControllerMouseHints.batchSelectBeltOrPipe
                end
            elseif building then
                actionIds = ControllerMouseHints.batchSelect
            end
        end
    else
        local mode = LuaSystemManager.factory:GetBuildMode()
        if mode ~= FacConst.FAC_BUILD_MODE.Normal then
            
            if mode == FacConst.FAC_BUILD_MODE.Building then
                local movingNodeId = LuaSystemManager.factory:GetMovingBuildingNodeId()
                if movingNodeId then
                    actionIds = FactoryUtils.canDelBuilding(movingNodeId) and ControllerMouseHints.oldBuilding or ControllerMouseHints.oldBuildingCantDes
                else
                    actionIds = ControllerMouseHints.newBuilding
                end
            elseif mode == FacConst.FAC_BUILD_MODE.Logistic then
                if LuaSystemManager.factory:CanRotateInBuildMode() then
                    actionIds = ControllerMouseHints.newBuilding
                else
                    actionIds = ControllerMouseHints.newBuildingCantRotate
                end
            elseif mode == FacConst.FAC_BUILD_MODE.Belt then
                local isPipe = LuaSystemManager.factory:IsBuildingPipeInBuildMode()
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
            
            local building = output and output.building
            if building or output and (output.belt or output.pipe) then
                if building and building.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building
                        and FactoryUtils.canMoveBuilding(building.nodeId) then
                    actionIds = ControllerMouseHints.normal
                else
                    actionIds = ControllerMouseHints.normalNoMove
                end
            end
        end
    end
    self:_RefreshControllerMouseHints(actionIds)
    if actionIds then
        self:_UpdateControllerOpenDetailHint()
    end
end




FacTopViewCtrl._UpdateControllerOpenDetailHint = HL.Method() << function(self)
    local cells = self.m_controllerMouseHoverHintCells
    if not cells then
        return
    end
    local count = cells:GetCount()
    if count == 0 then
        return
    end
    
    local cell = cells:GetItem(count)
    if not cell or cell.gameObject.name ~= "KeyHint-fac_top_view_open_building_panel" then
        return
    end
    local output = LuaSystemManager.factoryInteract:GetCurrentTargetOutput()
    local liveCount = 0
    if output and output.pipe then liveCount = liveCount + 1 end
    if output and output.building then liveCount = liveCount + 1 end
    if output and output.overlapBuildings then liveCount = liveCount + #output.overlapBuildings end
    if output and output.belt then liveCount = liveCount + 1 end
    if liveCount > 1 then
        local targets = self:_CollectControllerTargets()
        if #targets > 1 then
            cell.actionKeyHint:SetText(string.format(Language.LUA_FAC_TOP_VIEW_CONTROLLER_OPEN_DETAIL_FORMAT, targets[1].name))
            return
        end
    end
    cell.actionKeyHint:SetText(cell.actionKeyHint:GetTextStr())
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
    self.m_keyHintCells = self.m_keyHintCells or UIUtils.genCellCache(self.view.keyHintCell)
    self.m_keyHintCells:Refresh(#actionNames, function(cell, index)
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
    
    local targets = self:_CollectControllerTargets()
    if #targets == 0 then
        return
    end
    local actions = {}
    self:_AddControllerMenuActionsForTarget(actions, targets[1], false)
    actions[1].action()
end



FacTopViewCtrl._CollectControllerTargets = HL.Method().Return(HL.Table) << function(self)
    local presentationModel = LuaSystemManager.factoryInteract:GetCurrentPresentationModel()
    local targetSet = presentationModel and presentationModel.resolvedTargetSet
    if not targetSet then
        return {}
    end

    local targets = {}
    
    
    local chapterId = Utils.getCurrentChapterId()
    local seenPendingSlotIds = {}

    local pipe = targetSet.pipe
    if pipe then
        local pipeNodeId = pipe.nodeId
        local pipePendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, pipeNodeId)
        local isPendingPipe = pipePendingSlotId > 0
        if not isPendingPipe or not seenPendingSlotIds[pipePendingSlotId] then
            if isPendingPipe then
                seenPendingSlotIds[pipePendingSlotId] = true
            end
            table.insert(targets, {
                type = FacConst.FAC_INTERACT_TARGET_TYPE.Pipe,
                sortBase = 100,
                name = isPendingPipe
                    and FactoryUtils.getPendingSlotName(pipePendingSlotId)
                    or Language.LUA_FAC_PIPE_INTERACT_OPTION,
                nodeId = pipeNodeId,
                unitIndex = pipe.unitIndex,
            })
        end
    end
    local building = targetSet.building
    if building then
        local nodeId = building.nodeId
        local buildingPendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, nodeId)
        local isPendingBuilding = buildingPendingSlotId > 0
        if isPendingBuilding then
            
            if not seenPendingSlotIds[buildingPendingSlotId] then
                seenPendingSlotIds[buildingPendingSlotId] = true
                table.insert(targets, {
                    type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                    sortBase = 200,
                    name = FactoryUtils.getPendingSlotName(buildingPendingSlotId),
                    nodeId = nodeId,
                    isBuilding = true,
                    subBuildingIndex = -1,
                })
            end
        else
            local isBuilding =
                building.targetType == FacConst.FAC_INTERACT_TARGET_TYPE.Building
            local subIndex = building.subBuildingIndex

            local handler = FactoryUtils.getBuildingNodeHandler(nodeId)
            local targetName
            if isBuilding then
                if subIndex and subIndex >= 0 then
                    
                    targetName = Language.LUA_FAC_HUB_INPUT .. subIndex
                else
                    targetName = Tables.factoryBuildingTable[handler.templateId].name
                end
            else
                targetName = FactoryUtils.getLogisticData(handler.templateId).name
            end
            table.insert(targets, {
                type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                sortBase = 200,
                name = targetName,
                nodeId = nodeId,
                isBuilding = isBuilding,
                subBuildingIndex = subIndex,
            })
        end
    end
    local overlapBuildings = targetSet.overlapBuildings
    if overlapBuildings then
        
        
        
        for i, overlap in ipairs(overlapBuildings) do
            local overlapNodeId = overlap.nodeId
            local overlapPendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, overlapNodeId)
            local isOverlapPending = overlapPendingSlotId > 0
            if isOverlapPending then
                if not seenPendingSlotIds[overlapPendingSlotId] then
                    seenPendingSlotIds[overlapPendingSlotId] = true
                    table.insert(targets, {
                        type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                        sortBase = 150 + 10 * i,
                        name = FactoryUtils.getPendingSlotName(overlapPendingSlotId),
                        nodeId = overlapNodeId,
                        isBuilding = true,
                        subBuildingIndex = -1,
                    })
                end
            else
                local handler = FactoryUtils.getBuildingNodeHandler(overlapNodeId)
                if handler then
                    local overlapIsBuilding =
                        overlap.targetType == FacConst.FAC_INTERACT_TARGET_TYPE.Building
                    local overlapName
                    if overlapIsBuilding then
                        local _, buildingData = Tables.factoryBuildingTable:TryGetValue(handler.templateId)
                        overlapName = buildingData and buildingData.name
                    else
                        local unitData = FactoryUtils.getLogisticData(handler.templateId)
                        overlapName = unitData and unitData.name
                    end
                    if overlapName then
                        table.insert(targets, {
                            type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                            sortBase = 150 + 10 * i,
                            name = overlapName,
                            nodeId = overlapNodeId,
                            isBuilding = overlapIsBuilding,
                        })
                    end
                end
            end
        end
    end
    local belt = targetSet.belt
    if belt then
        local logisticPos = belt.logisticPos
        local beltNodeId = belt.nodeId
        local beltUnitIndex = belt.unitIndex
        if beltNodeId then
            local beltPendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, beltNodeId)
            local isPendingBelt = beltPendingSlotId > 0
            if not isPendingBelt or not seenPendingSlotIds[beltPendingSlotId] then
                if isPendingBelt then
                    seenPendingSlotIds[beltPendingSlotId] = true
                end
                local beltName
                if isPendingBelt then
                    beltName = FactoryUtils.getPendingSlotName(beltPendingSlotId)
                else
                    local chapterInfo = FactoryUtils.getCurChapterInfo()
                    local handler = chapterInfo:GetNode(beltNodeId)
                    beltName = Tables.factoryGridBeltTable:GetValue(handler.templateId).beltData.name
                end
                table.insert(targets, {
                    type = FacConst.FAC_INTERACT_TARGET_TYPE.Belt,
                    sortBase = 300,
                    name = beltName,
                    nodeId = beltNodeId,
                    unitIndex = beltUnitIndex,
                    logisticPos = logisticPos,
                })
            end
        end
    end
    table.sort(targets, function(a, b) return a.sortBase < b.sortBase end)
    return targets
end

FacTopViewCtrl._ControllerOpenCurBuildingMenu = HL.Method() << function(self)
    
    local facInteract = LuaSystemManager.factoryInteract:GetPresenter()

    local targets = self:_CollectControllerTargets()
    if #targets == 0 then
        return
    end

    local isMulti = #targets > 1
    local actions = {}
    for _, target in ipairs(targets) do
        self:_AddControllerMenuActionsForTarget(actions, target, isMulti)
    end
    table.sort(actions, function(a, b) return a.priority < b.priority end)

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

FacTopViewCtrl._AddControllerMenuActionsForTarget = HL.Method(HL.Table, HL.Table, HL.Boolean) << function(self, actions, target, isMulti)
    local fmt = Language.LUA_FAC_TOP_VIEW_CONTROLLER_MULTI_TARGET_MENU_FORMAT
    local function fmtText(text)
        return isMulti and string.format(fmt, target.name, text) or text
    end

    local PRIORITY_OTHER_OFFSET = 1000

    table.insert(actions, {
        objName = "Open_" .. TARGET_TYPE_NAME[target.type],
        text = fmtText(Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_OPEN),
        priority = target.sortBase,
        action = function()
            if target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
                if target.isBuilding then
                    if target.subBuildingIndex and target.subBuildingIndex >= 0 then
                        
                        LuaSystemManager.factoryInteract:ExecuteInteract({
                            buildingNodeId = target.nodeId,
                            subBuildingIndex = target.subBuildingIndex,
                        })
                    else
                        LuaSystemManager.factoryInteract:ExecuteInteract({ buildingNodeId = target.nodeId })
                    end
                else
                    LuaSystemManager.factoryInteract:ExecuteInteract({ nodeId = target.nodeId })
                end
            elseif target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Pipe then
                LuaSystemManager.factoryInteract:ExecuteInteract({ nodeId = target.nodeId, unitIndex = target.unitIndex })
            elseif target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Belt then
                LuaSystemManager.factoryInteract:ExecuteInteract({
                    nodeId = target.nodeId,
                    unitIndex = target.unitIndex,
                    logisticPos = target.logisticPos,
                })
            end
            LuaSystemManager.factoryInteract:ClearInteractPresentation()
        end,
    })

    if target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        if target.isBuilding and FactoryUtils.canMoveBuilding(target.nodeId) then
            table.insert(actions, {
                objName = "Move_Building",
                text = fmtText(Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_MOVE),
                priority = target.sortBase + PRIORITY_OTHER_OFFSET,
                action = function()
                    Notify(MessageConst.FAC_ENTER_BUILDING_MODE, { nodeId = target.nodeId })
                end,
            })
        end
        if FactoryUtils.canDelBuilding(target.nodeId) then
            table.insert(actions, {
                objName = "Del_Building",
                text = fmtText(Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL),
                priority = target.sortBase + PRIORITY_OTHER_OFFSET + 1,
                action = function()
                    FactoryUtils.delBuilding(target.nodeId)
                end,
            })
        end
    elseif target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Pipe
            or target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Belt then
        if FactoryUtils.canDelBuilding(target.nodeId) then
            table.insert(actions, {
                objName = "DelWhole_" .. TARGET_TYPE_NAME[target.type],
                text = fmtText(Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL_WHOLE),
                priority = target.sortBase + PRIORITY_OTHER_OFFSET,
                action = function()
                    GameInstance.player.remoteFactory.core:Message_OpDismantle(Utils.getCurrentChapterId(), target.nodeId)
                end,
            })
            table.insert(actions, {
                objName = "DelOneGrid_" .. target.type,
                text = fmtText(Language.LUA_FAC_TOP_VIEW_CONTROLLER_MENU_DEL_ONE_GRID),
                priority = target.sortBase + PRIORITY_OTHER_OFFSET + 1,
                action = function()
                    GameInstance.remoteFactoryManager:DismantleUnitFromConveyor(Utils.getCurrentChapterId(), target.nodeId, target.unitIndex)
                end,
            })
        end
    end
end

FacTopViewCtrl._ControllerMoveCurBuilding = HL.Method() << function(self)
    local output = LuaSystemManager.factoryInteract:GetCurrentTargetOutput()
    local building = output and output.building
    if not building or building.type ~= FacConst.FAC_INTERACT_TARGET_TYPE.Building
            or not FactoryUtils.canMoveBuilding(building.nodeId, true) then
        return
    end
    Notify(MessageConst.FAC_ENTER_BUILDING_MODE, { nodeId = building.nodeId })
end

FacTopViewCtrl.ToggleHideFacTopViewRightSideUi = HL.Method(HL.Boolean) << function(self, isHide)
    if DeviceInfo.usingController then
        self.view.controllerMouse.gameObject:SetActive(not isHide)
        self.view.controllerMouseHoverHint.gameObject:SetActive(not isHide and self.m_lastMouseHintContent ~= nil)
    end
end






FacTopViewCtrl._IsMultiTargetMenuShowing = HL.Method().Return(HL.Boolean) << function(self)
    return self.view.multiTargetMenuNode.gameObject.activeSelf
end

FacTopViewCtrl._IsHoveringMultiTargetMenuGrid = HL.Method().Return(HL.Boolean) << function(self)
    if not self:_IsMultiTargetMenuShowing() or not self.m_multiTargetMenuGridPos then
        return false
    end
    local input = LuaSystemManager.factoryInteract:GetCurrentTargetInput()
    local detectPos = input and input.worldPos
    if not detectPos then
        return false
    end
    local gridPos = self.m_multiTargetMenuGridPos
    return math.floor(detectPos.x) == gridPos.x and math.floor(detectPos.z) == gridPos.z
end

FacTopViewCtrl._ClearHoverHintsForMultiTargetMenu = HL.Method() << function(self)
    self.m_lastMouseHintContent = nil
    self.view.mouseHoverHint.gameObject:SetActiveIfNecessary(false)
    self.view.controllerMouseHoverHint.gameObject:SetActiveIfNecessary(false)
end

FacTopViewCtrl._ShowMultiTargetMenu = HL.Method(HL.Table) << function(self, args)
    local targets = args.targets
    local screenRect = args.screenRect

    self.m_multiTargetCells:Refresh(#targets, function(cell, index)
        local info = targets[index]
        cell.gameObject.name = "MultiTarget_" .. index
        cell.actionNode.onClick:RemoveAllListeners()
        cell.text.text = info.name
        cell.actionNode.onClick:AddListener(function()
            self:_HideMultiTargetMenu()
            info.action()
        end)
        if index == 1 then
            self:SetNaviTarget(cell.actionNode)
        end
    end)

    self.view.multiTargetMenuNode.gameObject:SetActive(true)
    local input = LuaSystemManager.factoryInteract:GetCurrentTargetInput()
    local detectPos = input and input.worldPos
    self.m_multiTargetMenuGridPos = detectPos and { x = math.floor(detectPos.x), z = math.floor(detectPos.z) } or nil
    self:_ClearHoverHintsForMultiTargetMenu()
    local contentRect = self.view.multiTargetMenuNode.content.transform
    LayoutRebuilder.ForceRebuildLayoutImmediate(contentRect)

    UIUtils.updateTipsPositionWithScreenRect(
        contentRect,
        screenRect,
        self.view.rectTransform,
        self.uiCamera,
        UIConst.UI_TIPS_POS_TYPE.RightTop,
        { bottom = 100 }
    )

    local firstEffectInfo = targets[1] and targets[1].effectInfo
    if firstEffectInfo and firstEffectInfo.worldPos then
        self:_SetMenuEffect(self.m_menuHoverEffect, firstEffectInfo.worldPos, 0)
    end
    for _, t in ipairs(targets) do
        if t.type == FacConst.FAC_INTERACT_TARGET_TYPE.Pipe and t.effectInfo then
            LuaSystemManager.factory:RequestPipeHighlight(
                FacConst.FAC_PIPE_HIGHLIGHT_SOURCE.MultiTargetMenu,
                t.effectInfo.nodeId,
                t.effectInfo.unitIndex
            )
            break
        end
    end

    AudioAdapter.PostEvent("Au_UI_Menu_FacOverlay_Open")
end

FacTopViewCtrl._HideMultiTargetMenu = HL.Method() << function(self)
    if self.view.multiTargetMenuNode.gameObject.activeSelf then
        self.view.multiTargetMenuNode.gameObject:SetActive(false)
    end
    self.m_multiTargetMenuGridPos = nil
    if self.m_menuHoverEffect then
        self.m_menuHoverEffect.gameObject:SetActive(false)
    end
    LuaSystemManager.factory:ReleasePipeHighlight(FacConst.FAC_PIPE_HIGHLIGHT_SOURCE.MultiTargetMenu)
end

FacTopViewCtrl._SetMenuEffect = HL.Method(HL.Table, CS.UnityEngine.Vector3, HL.Number) << function(self, effect, pos, offsetY)
    pos.y = pos.y + offsetY
    effect.transform.position = pos
    effect.transform.eulerAngles = Vector3.zero
    effect.transform.localScale = Vector3.one
    for k = 1, 4 do
        effect["corner" .. k].transform.localScale = Vector3.one
    end
    if not effect.gameObject.activeSelf then
        effect.gameObject:SetActive(true)
        for k = 1, 4 do
            effect["effect" .. k]:Update(0)
        end
    end
end




FacTopViewCtrl.GetCurStateArg = HL.Method(HL.Table) << function(self, arg)
    self.m_quickBar:GetCurStateArg(arg)
end

FacTopViewCtrl.RecoverStateOnChangeDevice = HL.Method(HL.Table) << function(self, arg)
    self.m_quickBar:RecoverStateOnChangeDevice(arg)
end

HL.Commit(FacTopViewCtrl)
