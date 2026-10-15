
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local s_tickCtx = {} 
local s_pressCtx = {} 
local s_handlerExitCtx = {} 
local PANEL_ID = PanelId.FacBuildMode




local s_handlerDefs = {
    [FacConst.FAC_BUILD_MODE.Building]  = { 'UI/Panels/FacBuildMode/FacBuildModeHandler_Building',  'FacBuildModeHandler_Building' },
    [FacConst.FAC_BUILD_MODE.Logistic]  = { 'UI/Panels/FacBuildMode/FacBuildModeHandler_Logistic',  'FacBuildModeHandler_Logistic' },
    [FacConst.FAC_BUILD_MODE.Belt]      = { 'UI/Panels/FacBuildMode/FacBuildModeHandler_Belt',      'FacBuildModeHandler_Belt' },
    [FacConst.FAC_BUILD_MODE.Blueprint] = { 'UI/Panels/FacBuildMode/FacBuildModeHandler_Blueprint', 'FacBuildModeHandler_Blueprint' },
}
local s_handlerClassCache = {}

local function getHandlerClass(mode)
    local cls = s_handlerClassCache[mode]
    if not cls then
        local def = s_handlerDefs[mode]
        cls = require_ex(def[1])[def[2]]
        s_handlerClassCache[mode] = cls
    end
    return cls
end

local function makeHandlerExitCtx(isSwitching, skipAnim)
    s_handlerExitCtx.isSwitching = isSwitching
    s_handlerExitCtx.skipAnim = skipAnim
    return s_handlerExitCtx
end

FacBuildModeCtrl = HL.Class('FacBuildModeCtrl', uiCtrl.UICtrl)






FacBuildModeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INTERACT_CONVEYOR_LOCAL_CHECKING_FAILED] = 'OnInteractConveyorLocalCheckingFailed',
    [MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE] = 'OnInFacMainRegionChange',
    [MessageConst.FAC_LOCK_BUILD_POS] = 'FacLockBuildPos',
    [MessageConst.FAC_ON_BUILDING_BATCH_MOVED] = 'FacOnBuildingBatchMoved',
}




FacBuildModeCtrl.s_enableContinueBuild = HL.StaticField(HL.Boolean) << false 

FacBuildModeCtrl.m_onClickScreen = HL.Field(HL.Function)

FacBuildModeCtrl.m_onPressScreen = HL.Field(HL.Function)

FacBuildModeCtrl.m_onReleaseScreen = HL.Field(HL.Function)

FacBuildModeCtrl.m_mode = HL.Field(HL.Number) << FacConst.FAC_BUILD_MODE.Normal


FacBuildModeCtrl.m_currentHandler = HL.Field(HL.Forward('FacBuildModeHandler'))

FacBuildModeCtrl.m_buildArgs = HL.Field(HL.Table)

FacBuildModeCtrl.m_itemData = HL.Field(HL.Userdata)

FacBuildModeCtrl.m_buildingNodeId = HL.Field(HL.Any)

FacBuildModeCtrl.m_buildingId = HL.Field(HL.String) << ""

FacBuildModeCtrl.m_beltId = HL.Field(HL.String) << ""

FacBuildModeCtrl.m_lastMouseWorldPos = HL.Field(HL.Userdata)

FacBuildModeCtrl.m_tickCor = HL.Field(HL.Thread)

FacBuildModeCtrl.m_sizeIndicator = HL.Field(HL.Table)

FacBuildModeCtrl.m_beltStartPreviewMark = HL.Field(HL.Table)

FacBuildModeCtrl.m_pipePreviewMark = HL.Field(HL.Table)

FacBuildModeCtrl.m_hideKey = HL.Field(HL.Number) << -1

FacBuildModeCtrl.m_isCropRegion = HL.Field(HL.Boolean) << false

FacBuildModeCtrl.m_workingRange = HL.Field(HL.Table)

FacBuildModeCtrl.m_fluidSprayRange = HL.Field(HL.Table)

FacBuildModeCtrl.m_battleRange = HL.Field(HL.Table)

FacBuildModeCtrl.m_isDragging = HL.Field(HL.Boolean) << false

FacBuildModeCtrl.m_draggingOffset = HL.Field(Vector3) 

FacBuildModeCtrl.m_camState = HL.Field(HL.Any)

FacBuildModeCtrl.m_signResetBindingId = HL.Field(HL.Number) << -1

FacBuildModeCtrl.m_rpgBuildBindingGroupId = HL.Field(HL.Number) << -1

FacBuildModeCtrl.m_topViewBuildBindingGroupId = HL.Field(HL.Number) << -1


FacBuildModeCtrl.m_simpleFigureBackupValid = HL.Field(HL.Boolean) << false

FacBuildModeCtrl.m_simpleFigureModeBeforeBeltBuild = HL.Field(HL.Number) << FacConst.SIMPLE_FIGURE_MODE.None

FacBuildModeCtrl.s_radioTagHandle = HL.StaticField(HL.Any)





FacBuildModeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    for _, node in ipairs({ self.view.actionButtonsAsIcon, self.view.actionButtonsAsOption }) do
        node.exitButton.onClick:AddListener(function()
            self:_OnClickExitIcon()
        end)
        node.confirmButton.onClick:AddListener(function()
            self:_OnClickConfirm()
        end)
        node.rotateButton.onClick:AddListener(function()
            self:_RotateUnit()
        end)
        node.delButton.onClick:AddListener(function()
            self:_DelBuilding()
        end)
        if node.signResetButton ~= nil then
            node.signResetButton.onClick:AddListener(function()
                self:_OpenSignSettingPanel(true)
            end)
            node.signResetButton.gameObject:SetActiveIfNecessary(false)
        end
    end

    self.view.exitBeltModeButton.onClick:AddListener(function()
        self:_ExitCurMode(true)
    end)

    self.m_onClickScreen = function()
        self:_OnClickScreen()
    end
    self.m_onPressScreen = function()
        self:_OnPressScreen()
    end
    self.m_onReleaseScreen = function()
        self:_OnReleaseScreen()
    end

    
    
    self.m_onPlaceFinish = function()
        if self.m_currentHandler then
            self.m_currentHandler:OnBackendPlaceFinish()
        end
    end

    
    self.m_rpgBuildBindingGroupId = self:CreateInputGroup(self.view.inputGroup.groupId)
    self:BindInputPlayerAction("fac_build_confirm", function()
        if DeviceInfo.usingController then
            
            self:_OnClickConfirm()
        end
    end, self.m_rpgBuildBindingGroupId)
    self:BindInputPlayerAction("fac_build_cancel_alter", function()
        self:_ExitCurMode(true)
    end, self.m_rpgBuildBindingGroupId)
    self:BindInputPlayerAction("fac_build_mode_delete", function()
        self:_DelBuilding()
    end, self.m_rpgBuildBindingGroupId)

    
    self.m_topViewBuildBindingGroupId = self:CreateInputGroup(self.view.inputGroup.groupId)
    self:BindInputPlayerAction("fac_build_confirm_in_top_view", function()
        if DeviceInfo.usingController then
            
            self:_OnClickConfirm()
        end
    end, self.m_topViewBuildBindingGroupId)
    self:BindInputPlayerAction("fac_build_continuous_confirm", function()
        if DeviceInfo.usingController then
            
            self:_OnClickConfirm()
        end
    end, self.m_topViewBuildBindingGroupId)
    self:BindInputPlayerAction("fac_build_mode_delete_in_top_view", function()
        self:_DelBuilding() 
    end, self.m_topViewBuildBindingGroupId)
    self:BindInputPlayerAction("fac_build_cancel", function()
        self:_ExitCurMode(true)
    end, self.m_topViewBuildBindingGroupId)

    self:BindInputPlayerAction("fac_disable_mouse1_sprint", function()
        
    end)
    self:BindInputPlayerAction("fac_rotate_device", function()
        self:_RotateUnit()
    end)
    self.m_signResetBindingId = self:BindInputPlayerAction("fac_build_sign_reset", function()
        self:_OpenSignSettingPanel(true)
    end)
    InputManagerInst:ToggleBinding(self.m_signResetBindingId, false)

    

    self.view.moveBuildingHint.gameObject:SetActive(false)

    do 
        if not self.m_sizeIndicator then
            local prefab = self.loader:LoadGameObject(FacConst.BUILDING_SIZE_INDICATOR_PATH)
            local obj = self:_CreateWorldGameObject(prefab)
            self.m_sizeIndicator = Utils.wrapLuaNode(obj)
            obj.gameObject:SetActive(false)
        end
    end

    do 
        if not self.m_beltStartPreviewMark then
            local prefab = self.loader:LoadGameObject(FacConst.BELT_START_PREVIEW_MARK_PREFAB_PATH)
            local obj = self:_CreateWorldGameObject(prefab)
            local mark = Utils.wrapLuaNode(obj)
            mark.gameObject:SetActive(false)
            mark.mesh.sharedMaterial = mark.mesh:GetInstantiatedMaterial()
            local cornerMeshMat = mark.cornerMesh1:GetInstantiatedMaterial()
            mark.cornerMesh1.sharedMaterial = cornerMeshMat
            mark.cornerMesh2.sharedMaterial = cornerMeshMat
            mark.cornerMesh3.sharedMaterial = cornerMeshMat
            mark.cornerMesh4.sharedMaterial = cornerMeshMat
            mark.mats = { mark.mesh.sharedMaterial, cornerMeshMat }
            self.m_beltStartPreviewMark = mark
        end
    end

    do 
        if not self.m_pipePreviewMark then
            local prefab = self.loader:LoadGameObject(FacConst.PIPE_PREVIEW_MARK_PREFAB_PATH)
            local obj = self:_CreateWorldGameObject(prefab)
            local mark = Utils.wrapLuaNode(obj)
            mark.gameObject:SetActive(false)
            
            mark.mesh1.sharedMaterial = mark.mesh1:GetInstantiatedMaterial()
            mark.mesh2.sharedMaterial = mark.mesh2:GetInstantiatedMaterial()
            mark.mesh3.sharedMaterial = mark.mesh3:GetInstantiatedMaterial()
            local cornerMeshMat = mark.cornerMesh1:GetInstantiatedMaterial()
            mark.cornerMesh1.sharedMaterial = cornerMeshMat
            mark.cornerMesh2.sharedMaterial = cornerMeshMat
            mark.cornerMesh3.sharedMaterial = cornerMeshMat
            mark.cornerMesh4.sharedMaterial = cornerMeshMat
            mark.mats = { mark.mesh1.sharedMaterial, mark.mesh2.sharedMaterial, mark.mesh3.sharedMaterial, cornerMeshMat }
            self.m_pipePreviewMark = mark
        end
    end

    do 
        if not self.m_fluidSprayRange then
            local prefab = self.loader:LoadGameObject(FacConst.FLUID_SPRAY_RANGE_EFFECT)
            local obj = self:_CreateWorldGameObject(prefab)
            self.m_fluidSprayRange = Utils.wrapLuaNode(obj)
            obj.gameObject:SetActive(false)
        end
    end

    self.view.hideToggle.toggle.onValueChanged:AddListener(function(isOn)
        self:_OnChangeHideToggle(isOn)
    end)
    self.view.continueBuildToggle.isOn = false
    self.view.continueBuildToggle.onValueChanged:AddListener(function(isOn)
        self:_OnChangeContinueToggle(isOn)
    end)

    self:_InitKeyHint()

    if BEYOND_DEBUG_COMMAND then
        self:BindInputEvent(CS.Beyond.Input.KeyboardKeyCode.C, function()
            self:DebugOutputPrepareBuildingPosInfo()
        end)
    end
end

FacBuildModeCtrl._Tick = HL.Method() << function(self)
    if not CS.UnityEngine.Application.isFocused then return end
    if self.m_mode == FacConst.FAC_BUILD_MODE.Normal then
        return
    end

    local handler = self.m_currentHandler
    if handler then
        self:_TickWithHandler(handler)
    end
end


FacBuildModeCtrl._TickWithHandler = HL.Method(HL.Forward('FacBuildModeHandler')) << function(self, handler)
    if self.m_lockBuildPos then
        handler:OnTickLocked()
        return
    end

    local provider = handler.m_provider
    local rawPointerPos = self:_GetCurPointerPressPos()
    local camRay = CameraManager.mainCamera:ScreenPointToRay(rawPointerPos)
    local sampleOk, rawWorldPos = provider:SampleGroundPoint(camRay)

    local pointerPos = rawPointerPos
    local pointerWorldPos = rawWorldPos
    if self.m_isDragging then
        pointerPos = rawPointerPos + self.m_draggingOffset
        local dragRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        sampleOk, pointerWorldPos = provider:SampleGroundPoint(dragRay)
    end

    local ctx = s_tickCtx
    ctx.pointerPos = pointerPos
    ctx.pointerWorldPos = pointerWorldPos
    ctx.rawPointerWorldPos = rawWorldPos
    ctx.sampleOk = sampleOk 
    ctx.usingDrag = self:_InDragMode()
    ctx.isDragging = self.m_isDragging
    ctx.customGridCenter = nil
    ctx.posChanged = nil
    handler:OnTick(ctx)

    self.m_lastMouseWorldPos = rawWorldPos
    self:RefreshValidResult()
    handler:OnPostTick(ctx)

    if ctx.usingDrag then
        local followInfo = handler:GetDragFollowInfo()
        if followInfo then
            local targetWorldPos = followInfo.worldPos
            local targetSize = followInfo.worldSize
            local min = CameraManager.mainCamera:WorldToScreenPoint(targetWorldPos + targetSize / 2)
            local max = CameraManager.mainCamera:WorldToScreenPoint(targetWorldPos - targetSize / 2)
            local size = max - min
            size.x = math.abs(size.x)
            size.y = math.abs(size.y)
            min.x = math.min(min.x, max.x)
            min.y = math.min(min.y, max.y)
            max = min + size
            local targetScreenRect = Unity.Rect(min.x, Screen.height - (min.y + size.y), size.x, size.y)
            UIUtils.updateTipsPositionWithScreenRect(self.view.actionButtonsAsIcon.transform, targetScreenRect, self.view.transform,
                    self.uiCamera, UIConst.UI_TIPS_POS_TYPE.FacTopViewBuildActionIcons, {
                        top = self.view.config.DRAG_MODE_BUILDING_PADDING_Y.x,
                        left = self.view.config.DRAG_MODE_BUILDING_PADDING_X.x,
                        right = self.view.config.DRAG_MODE_BUILDING_PADDING_X.y,
                        bottom = self.view.config.DRAG_MODE_BUILDING_PADDING_Y.y,
                    })
        end
    end
end

FacBuildModeCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegister()
    CS.HG.Rendering.ScriptBridge.TAAUControlBridge.taauFastConverge = true
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { "FacBuildModeCtrl", true })
    self:FacLockBuildPos({ false })
    self.view.continueBuildToggle.isOn = FacBuildModeCtrl.s_enableContinueBuild
    self.view.actionButtonsAsOption.signResetButton.gameObject:SetActiveIfNecessary(false)
    self.view.miasmaIndicator:InitMiasmaIndicator()
end

FacBuildModeCtrl.OnHide = HL.Override() << function(self)
    self:FacLockBuildPos({ false })
    self:_OnReleaseScreen()
    self:_ClearRegister()
    CS.HG.Rendering.ScriptBridge.TAAUControlBridge.taauFastConverge = true
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { "FacBuildModeCtrl", false })

    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "FacBuildModeCtrl-ContinuousBuild",
        type = UIConst.MOUSE_ICON_HINT.Default,
    })

    GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacBuildSystemActionConflictName)
end

FacBuildModeCtrl.OnClose = HL.Override() << function(self)
    self:_ExitCurMode(false, true, true)
    self:_ClearRegister()
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { "FacBuildModeCtrl", false })

    
    self.m_hideKey = UIManager:RecoverScreen(self.m_hideKey)

    GameInstance.remoteFactoryManager.inBuildMode = false

    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "FacBuildModeCtrl-ContinuousBuild",
        type = UIConst.MOUSE_ICON_HINT.Default,
    })

    GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacBuildSystemActionConflictName)
end

FacBuildModeCtrl.ExtractHotSwitchRuntimeState = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if self.m_keyHintCells == nil and self.m_sizeIndicator == nil and self.m_beltStartPreviewMark == nil and self.m_pipePreviewMark == nil and self.m_fluidSprayRange == nil then
        return nil
    end

    local state = {
        keyHintCells = self.m_keyHintCells,
        sizeIndicator = self.m_sizeIndicator,
        beltStartPreviewMark = self.m_beltStartPreviewMark,
        pipePreviewMark = self.m_pipePreviewMark,
        fluidSprayRange = self.m_fluidSprayRange,
    }
    self.m_keyHintCells = nil
    self.m_sizeIndicator = nil
    self.m_beltStartPreviewMark = nil
    self.m_pipePreviewMark = nil
    self.m_fluidSprayRange = nil
    return state
end

FacBuildModeCtrl.RestoreHotSwitchRuntimeState = HL.Override(HL.Opt(HL.Any)) << function(self, state)
    if not state then
        return
    end
    self.m_keyHintCells = state.keyHintCells
    self.m_sizeIndicator = state.sizeIndicator
    self.m_beltStartPreviewMark = state.beltStartPreviewMark
    self.m_pipePreviewMark = state.pipePreviewMark
    self.m_fluidSprayRange = state.fluidSprayRange
end




FacBuildModeCtrl.EnterBlueprintMode = HL.StaticMethod(HL.Table) << function(args)
    FacBuildModeCtrl._EnterMode(args, FacConst.FAC_BUILD_MODE.Blueprint)
end

FacBuildModeCtrl._EnterMode = HL.StaticMethod(HL.Table, HL.Number) << function(args, mode)
    if Utils.isCurSquadAllDead() then
        return
    end

    if FacBuildModeCtrl._CheckBanAndToastSignInTopView(args.itemId) then
        return
    end

    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        if ctrl.m_mode ~= FacConst.FAC_BUILD_MODE.Normal then
            return  
        end
    end

    if not FacBuildModeCtrl.CheckCanEnterAndShowToast() then
        return
    end

    
    if not GameInstance.player.systemActionConflictManager:TryStartSystemAction(Const.FacBuildSystemActionConflictName) then
        return
    end

    
    FacBuildModeCtrl.s_radioTagHandle = GameInstance.player.globalTagsSystem:AddGlobalTag(CS.Beyond.Gameplay.GlobalTagDefine.notStopRadioTags)
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "facBuildMode", isInMainHud = false })

    FacBuildModeCtrl._BeforeEnterBuildMode(args.skipMainHudAnim or false)

    local onClearScreenFinishAct = function(key)
        if GameInstance.player.systemActionConflictManager.curProcessingSystemAction ~= Const.FacBuildSystemActionConflictName then
            
            UIManager:RecoverScreen(key)

            Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "facBuildMode", isInMainHud = true })
            if FacBuildModeCtrl.s_radioTagHandle then
                
                FacBuildModeCtrl.s_radioTagHandle:RemoveTag()
                FacBuildModeCtrl.s_radioTagHandle = nil
            end

            Notify(MessageConst.ON_BUILD_MODE_CHANGE, FacConst.FAC_BUILD_MODE.Normal)
            return
        end

        
        local self = FacBuildModeCtrl.AutoOpen(PANEL_ID, nil, true)
        self.m_hideKey = key
        local facRegion = GameInstance.player.factoryRegionManager.currentRegion
        self.m_isCropRegion = facRegion.type == GEnums.FacRegionType.Crop
        self:SwitchTo(mode, args)
        if args.triggerPressScreen then
            
            self:_StartCoroutine(function()
                coroutine.step() 
                if self:IsShow() and InputManager.IsLeftMouseDown(true) then
                    self:_OnPressScreen()
                end
            end)
        end
        if DeviceInfo.usingKeyboard then
            self:_UpdateAutoMoveTopViewCamState()
        end
    end

    
    if args.fastEnter then
        local key = UIManager:ClearScreen(Const.RESERVE_PANEL_IDS_FOR_FAC_BUILD_MODE)
        onClearScreenFinishAct(key)
    else
        UIManager:ClearScreenWithOutAnimation(function(key)
            onClearScreenFinishAct(key)
        end, Const.RESERVE_PANEL_IDS_FOR_FAC_BUILD_MODE)
    end

    GameInstance.remoteFactoryManager.inBuildMode = true
end

FacBuildModeCtrl.EnterBuildingMode = HL.StaticMethod(HL.Table) << function(args)
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.FacMode) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_PLACE_BUILDING_LOCKED)
        return
    end
    FacBuildModeCtrl._EnterMode(args, FacConst.FAC_BUILD_MODE.Building)
end

FacBuildModeCtrl.EnterLogisticMode = HL.StaticMethod(HL.Table) << function(args)
    
    local logisticId = Tables.factoryItem2LogisticIdTable[args.itemId].logisticId
    local logisticData, isLiquid = FactoryUtils.getLogisticData(logisticId)
    if isLiquid and not FactoryUtils.isDomainSupportPipe() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_DOMAIN_NOT_SUPPORT_PIPE)
        return
    end
    FacBuildModeCtrl._EnterMode(args, FacConst.FAC_BUILD_MODE.Logistic)
end

FacBuildModeCtrl.EnterBeltMode = HL.StaticMethod(HL.Table) << function(args)
    if lume.isarray(args) then
        
        args = { beltId = args[1] }
    end
    FacBuildModeCtrl._EnterMode(args, FacConst.FAC_BUILD_MODE.Belt)
end

FacBuildModeCtrl._BeforeEnterBuildMode = HL.StaticMethod(HL.Boolean) << function(skipMainHudAnim)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    
    PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
    Notify(MessageConst.BEFORE_ENTER_BUILD_MODE, skipMainHudAnim)
end

FacBuildModeCtrl.CheckCanEnterAndShowToast = HL.StaticMethod().Return(HL.Boolean)<< function()
    local level = PhaseManager.m_openedPhaseSet[PhaseId.Level]
    if not level then
        return false
    end
    local csCheckResult = GameInstance.remoteFactoryManager:CheckEnterInteractMode()
    if csCheckResult == CS.Beyond.Gameplay.RemoteFactory.EnterInteractModeCheckResult.InvalidLevel then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CANT_ENTER_BUILD_MODE_WHEN_NO_FAC_REGION)
        return false
    end
    if FactoryUtils.isPlayerOutOfRangeManual() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CANT_ENTER_BUILD_MODE_WHEN_OUT_OF_RANGE_MANUAL)
        return false
    end
    if GameWorld.battle.isSquadInFight and not Utils.isInSettlementDefenseDefending() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CANT_ENTER_BUILD_MODE_WHEN_FIGHT)
        return false
    end
    return true
end






FacBuildModeCtrl.m_needCloseMiniPower = HL.Field(HL.Boolean) << false

FacBuildModeCtrl._AddRegister = HL.Method() << function(self)
    
    if not DeviceInfo.usingController then 
        local touchPanel = UIManager.commonTouchPanel
        touchPanel.onClick:AddListener(self.m_onClickScreen)
        touchPanel.onPress:AddListener(self.m_onPressScreen)
        touchPanel.onRelease:AddListener(self.m_onReleaseScreen)
    end

    
    self:_Tick()
    self.m_tickCor = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_Tick()
        end
    end)
end

FacBuildModeCtrl._ClearRegister = HL.Method() << function(self)
    
    self.m_tickCor = self:_ClearCoroutine(self.m_tickCor)

    
    local touchPanel = UIManager.commonTouchPanel
    touchPanel.onClick:RemoveListener(self.m_onClickScreen)
    touchPanel.onPress:RemoveListener(self.m_onPressScreen)
    touchPanel.onRelease:RemoveListener(self.m_onReleaseScreen)
end




FacBuildModeCtrl._OnClickScreen = HL.Method() << function(self)
    if not DeviceInfo.usingTouch then
        self:_OnClickConfirm()
    elseif self.m_currentHandler then
        self.m_currentHandler:OnTouchClickScreen()
    end
end

FacBuildModeCtrl._OnClickConfirm = HL.Method() << function(self)
    if not FacBuildModeCtrl.s_enableConfirmBuild then
        return
    end

    local mainChar = GameInstance.mainCharPtr
    if mainChar then
        if mainChar.movementComponent and mainChar.movementComponent.moveMode == CS.Beyond.Gameplay.Core.MovementComponent.MoveMode.Plunge then
            
            return
        end
    end

    local handler = self.m_currentHandler
    if handler then
        handler:OnConfirm()
    end
end

FacBuildModeCtrl._OnPressScreen = HL.Method() << function(self)
    self.m_mobileDragBeltChecker = self:_ClearCoroutine(self.m_mobileDragBeltChecker)

    if self.m_mode == FacConst.FAC_BUILD_MODE.Normal then
        return
    end

    if not LuaSystemManager.factory.inTopView or not DeviceInfo.usingTouch then
        return
    end 

    if Input.touchCount > 1 then
        
        return
    end

    local handler = self.m_currentHandler
    if handler then
        local pointerPos = self:_GetCurPointerPressPos()
        local camRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        local _, worldPos = handler.m_provider:SampleGroundPoint(camRay)
        local ctx = s_pressCtx
        ctx.pointerPos = pointerPos
        ctx.pointerWorldPos = worldPos
        handler:OnPressScreen(ctx)
    end
end




FacBuildModeCtrl.TryBeginDragOnPreview = HL.Method(HL.Table) << function(self, ctx)
    local handler = self.m_currentHandler
    local hitInfo = handler:GetDragHitInfo(ctx.pointerWorldPos)
    if not hitInfo then
        return
    end
    local curMousePos = ctx.pointerPos
    local dragTargetCenterPos = hitInfo.centerPos

    
    local dragTargetCenterScreenPos = CameraManager.mainCamera:WorldToScreenPoint(dragTargetCenterPos)
    local halfMinSizeInScreen = self.view.config.MOBILE_MIN_DRAG_SIZE / 2 / self.view.transform.rect.width * Screen.width
    if math.abs(curMousePos.x - dragTargetCenterScreenPos.x) > halfMinSizeInScreen or math.abs(curMousePos.y - dragTargetCenterScreenPos.y) > halfMinSizeInScreen then
        local targetWorldRect = Unity.Rect()
        targetWorldRect.size = hitInfo.sizeXZ
        targetWorldRect.center = Vector2(dragTargetCenterPos.x, dragTargetCenterPos.z)
        if not targetWorldRect:Contains(ctx.pointerWorldPos:XZ()) then
            
            return
        end
    end

    self:BeginDragOnTarget(curMousePos, dragTargetCenterPos)
end


FacBuildModeCtrl.BeginDragOnTarget = HL.Method(Vector3, Vector3) << function(self, pointerPos, dragTargetCenterPos)
    self.m_isDragging = true
    UIManager.commonTouchPanel.enableZoom = false
    local targetCenterScreenPos = CameraManager.mainCamera:WorldToScreenPoint(dragTargetCenterPos)
    targetCenterScreenPos.z = 0
    self.m_draggingOffset = targetCenterScreenPos - pointerPos
    local autoMoveCamExtraPadding = Unity.Vector4() 
    if self.m_draggingOffset.x >= 0 then
        autoMoveCamExtraPadding.z = self.m_draggingOffset.x
    else
        autoMoveCamExtraPadding.y = -self.m_draggingOffset.x
    end
    if self.m_draggingOffset.y >= 0 then
        autoMoveCamExtraPadding.x = self.m_draggingOffset.y
    else
        autoMoveCamExtraPadding.w = -self.m_draggingOffset.y
    end
    LuaSystemManager.factory.canMoveCamTarget = false
    self:_UpdateAutoMoveTopViewCamState(autoMoveCamExtraPadding)
end

FacBuildModeCtrl.m_mobileDragBeltChecker = HL.Field(HL.Any)


FacBuildModeCtrl._OnReleaseScreen = HL.Method() << function(self)
    local handler = self.m_currentHandler
    if handler then
        local pointerPos = self:_GetCurPointerPressPos()
        local camRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        local sampleOk, worldPos = handler.m_provider:SampleGroundPoint(camRay)
        if self.m_isDragging then
            if sampleOk then
                handler:OnDragRelease(worldPos)
            end
            
            self.m_isDragging = false
            UIManager.commonTouchPanel.enableZoom = true
            self.m_draggingOffset = nil
            LuaSystemManager.factory:ToggleAutoMoveTopViewCam()
        elseif sampleOk then
            handler:OnReleaseScreen(worldPos)
        end
        LuaSystemManager.factory.canMoveCamTarget = true
    end
end






FacBuildModeCtrl.OnInFacMainRegionChange = HL.Method(HL.Boolean) << function(self, inMainRegion)
    if inMainRegion then
        return
    end

    local handler = self.m_currentHandler
    if handler and not handler:CanStayOutOfMainRegion() then
        self:_ExitCurMode(false, true)
    end
end

FacBuildModeCtrl._SetCamState = HL.Method(HL.Opt(HL.String)) << function(self, camStateName)
    if LuaSystemManager.factory.inTopView then
        return
    end
    if not camStateName then
        if self.m_camState then
            self.m_camState = FactoryUtils.exitFacCamera(self.m_camState)
        end
        return
    end
    if self.m_camState then
        logger.error("self.m_camState Not Null", self.m_camState)
        return
    end
    self.m_camState = FactoryUtils.enterFacCamera(camStateName)
end

FacBuildModeCtrl._OnChangeHideToggle = HL.Method(HL.Boolean) << function(self, isOn)
    
    if self.m_currentHandler then
        self.m_currentHandler:OnHideToggleChanged(isOn)
    end
end








FacBuildModeCtrl.SwitchTo = HL.Method(HL.Number, HL.Opt(HL.Table, HL.Boolean)) << function(self, mode, args, skipAnim)
    local cur = self.m_currentHandler
    if mode == FacConst.FAC_BUILD_MODE.Normal then
        if cur then
            cur:OnExit(makeHandlerExitCtx(false, skipAnim))
            self:_ExitMode(skipAnim) 
        end
        return
    end

    if cur then
        
        cur:OnExit(makeHandlerExitCtx(true, nil))
        local exitMsg = cur:GetExitMessage()
        self.m_currentHandler = nil
        if exitMsg then
            Notify(exitMsg)
        end
    end

    self.m_isDragging = false
    UIManager.commonTouchPanel.enableZoom = true

    self.m_buildArgs = args
    self.m_mode = mode
    local handler = getHandlerClass(mode)(self)
    self.m_currentHandler = handler
    handler:OnEnter(args)

    Notify(MessageConst.ON_BUILD_MODE_CHANGE, self.m_mode)
    local enterMsg = handler:GetEnterMessage()
    if enterMsg then
        Notify(enterMsg, handler:GetEnterMessageArg())
    end
    self:_UpdateCommonNodesOnEnterMode()
    if not self:_InDragMode() then
        
        self:_Tick()
    end
    handler:OnPostEnter()
end


FacBuildModeCtrl.ExitCurrentHandlerMode = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAnim)
    self:SwitchTo(FacConst.FAC_BUILD_MODE.Normal, nil, skipAnim)
end


FacBuildModeCtrl.SamplePointerWorldPos = HL.Method().Return(HL.Boolean, Vector3) << function(self)
    local pointerPos = self:_GetCurPointerPressPos()
    local camRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
    local handler = self.m_currentHandler
    if handler then
        local ok, worldPos = handler.m_provider:SampleGroundPoint(camRay)
        return ok, worldPos
    end
    local ok, worldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(camRay)
    return ok, worldPos
end


FacBuildModeCtrl.TickOnce = HL.Method() << function(self)
    self:_Tick()
end


FacBuildModeCtrl.IsContinueBuildToggleOn = HL.Method().Return(HL.Boolean) << function(self)
    return FacBuildModeCtrl.s_enableContinueBuild
end

FacBuildModeCtrl.ExitCurModeForCS = HL.StaticMethod(HL.Opt(HL.Any)) << function()
    FacBuildModeCtrl.ExitCurMode(true)
end

FacBuildModeCtrl.ExitCurMode = HL.StaticMethod(HL.Opt(HL.Boolean)) << function(skipAnim)
    
    GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacBuildSystemActionConflictName)

    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if not isOpen then
        return
    end
    
    local self = ctrl
    self:_ExitCurMode(false, skipAnim, true)
end

FacBuildModeCtrl._OnClickExitIcon = HL.Method() << function(self)
    
    local handler = self.m_currentHandler
    if handler and handler:OnRequestExit(FacConst.FAC_BUILD_EXIT_REASON.ExitIcon) then
        return
    end
    self:_ExitCurMode(true)
end

FacBuildModeCtrl._ExitCurMode = HL.Method(HL.Opt(HL.Boolean, HL.Boolean, HL.Boolean)) << function(self, fromClick, skipAnim, forceExit)
    if not FacBuildModeCtrl.s_enableExitBuildMode and not forceExit then
        return
    end

    if self.m_mode == FacConst.FAC_BUILD_MODE.Normal then
        return
    end

    GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacBuildSystemActionConflictName)

    local handler = self.m_currentHandler
    if handler then
        local reason = fromClick and FacConst.FAC_BUILD_EXIT_REASON.CancelInput or FacConst.FAC_BUILD_EXIT_REASON.System
        if handler:OnRequestExit(reason, skipAnim) then
            return
        end
        self:SwitchTo(FacConst.FAC_BUILD_MODE.Normal, nil, skipAnim)
        AudioAdapter.PostEvent("au_sfx_ui_fac_buiding_off")
    end
end

FacBuildModeCtrl._ClearArgs = HL.Method() << function(self)
    self.m_buildArgs = nil
    self.m_itemData = nil
    self.m_buildingNodeId = nil
    self.m_buildingId = ""
    self.m_beltId = ""
    self.m_lastMouseWorldPos = nil
    self:_SetCamState()
end

FacBuildModeCtrl._ExitMode = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAnim)
    local oldMode = self.m_mode

    
    local handler = self.m_currentHandler
    local handlerExitMsg = handler and handler:GetExitMessage() or nil
    self.m_currentHandler = nil

    self.m_mode = FacConst.FAC_BUILD_MODE.Normal
    self.view.errorHint.gameObject:SetActiveIfNecessary(false)

    local onExit = self.m_buildArgs.onExit
    self:_ClearArgs()
    GameInstance.remoteFactoryManager.interact:ExitCurrentMode()
    LuaSystemManager.factory:ToggleAutoMoveTopViewCam()

    local exitAct = function()
        self:Hide()
        self.m_hideKey = UIManager:RecoverScreen(self.m_hideKey)

        Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "facBuildMode", isInMainHud = true })
        if FacBuildModeCtrl.s_radioTagHandle then
            
            FacBuildModeCtrl.s_radioTagHandle:RemoveTag()
            FacBuildModeCtrl.s_radioTagHandle = nil
        end

        if onExit then
            onExit()
        end

        if handlerExitMsg then
            Notify(handlerExitMsg)
        elseif oldMode == FacConst.FAC_BUILD_MODE.Building then
            Notify(MessageConst.ON_EXIT_BUILDING_MODE)
        elseif oldMode == FacConst.FAC_BUILD_MODE.Logistic then
            Notify(MessageConst.ON_EXIT_LOGISTIC_MODE)
        elseif oldMode == FacConst.FAC_BUILD_MODE.Belt then
            Notify(MessageConst.ON_EXIT_BELT_MODE)
        elseif oldMode == FacConst.FAC_BUILD_MODE.Blueprint then
            Notify(MessageConst.ON_EXIT_BLUEPRINT_MODE)
        end
        Notify(MessageConst.ON_BUILD_MODE_CHANGE, self.m_mode)
        GameInstance.remoteFactoryManager.inBuildMode = false
        if LuaSystemManager.factory.inTopView then
            LuaSystemManager.factory:ApplySimpleFigureToRenderer()
        end
    end
    if not skipAnim then
        self:PlayAnimationOutWithCallback(exitAct)
    else
        exitAct()
    end
end

FacBuildModeCtrl._UpdateCommonNodesOnEnterMode = HL.Method() << function(self)
    local isBuilding = self.m_mode == FacConst.FAC_BUILD_MODE.Building
    local isBelt = self.m_mode == FacConst.FAC_BUILD_MODE.Belt
    local isLogistic = self.m_mode == FacConst.FAC_BUILD_MODE.Logistic
    local isBlueprint = self.m_mode == FacConst.FAC_BUILD_MODE.Blueprint
    local isPipe = self:_IsPipe()
    local usingDrag = self:_InDragMode()
    local inTopView = LuaSystemManager.factory.inTopView

    self.view.actionHint.gameObject:SetActive(isBelt and usingDrag)

    local node = (inTopView and self.view.actionButtonsAsIcon or self.view.actionButtonsAsOption)
    node.confirmButton.gameObject:SetActive(true)
    node.rotateButton.gameObject:SetActive(not isBelt and self:_CanRotate()) 
    node.rotateButton.text = isBelt and Language["ui_fac_common_logistic_rotate_mobile"] or Language["ui_fac_common_rotate_mobile"]
    node.delButton.gameObject:SetActive(self:_CanDelBuilding())
    if not inTopView then
        node.confirmText.text = isBelt and Language.LUA_FAC_BUILD_MODE_CONFIRM_BELT_START or Language.LUA_FAC_BUILD_CONFIRM_NORMAL
    end

    local showHideToggle = inTopView and (isBelt or isPipe)
    if showHideToggle then
        if isPipe then
            showHideToggle = FactoryUtils.canShowBelt()
        else
            showHideToggle = FactoryUtils.canShowPipe()
        end
    end
    self.view.hideToggle.gameObject:SetActive(showHideToggle)
    if showHideToggle then
        if self.m_buildArgs.isFromChangeInputDevice then 
            local rMode = LuaSystemManager.factory:GetSimpleFigureModeFromRenderer()
            local isToggleOn = isPipe and rMode == FacConst.SIMPLE_FIGURE_MODE.SimpleBeltFigure
                or (not isPipe) and rMode == FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure
            self.view.hideToggle.toggle:SetIsOnWithoutNotify(isToggleOn)
            LuaSystemManager.factory:SetSimpleFigureMode(rMode, true)
        else
            local fac = LuaSystemManager.factory
            local wantOn = isPipe and fac.simpleFigureMode == FacConst.SIMPLE_FIGURE_MODE.SimpleBeltFigure
                or (not isPipe) and fac.simpleFigureMode == FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure
            self.view.hideToggle.toggle:SetIsOnWithoutNotify(wantOn)
            self:_OnChangeHideToggle(wantOn)
        end
    else
        self.view.hideToggle.toggle:SetIsOnWithoutNotify(false)
        
        LuaSystemManager.factory:ClearSimpleFigureEcsOnly()
    end
    self.view.hideToggle.beltIcon.gameObject:SetActive(isPipe)
    self.view.hideToggle.pipeIcon.gameObject:SetActive(not isPipe)

    local showContinueBuild = (isBuilding or isLogistic) and self.m_buildingNodeId == nil and ((inTopView and DeviceInfo.usingTouch) or not inTopView)
        and not FacConst.SIGN_BUILDING_EXTRA_SETTING_PANEL[self.m_buildingId] 
    self.view.continueBuildToggle.gameObject:SetActive(showContinueBuild)
    self.view.actionButtonsAsIcon.continueBuildHint.gameObject:SetActive(inTopView and showContinueBuild and self.view.continueBuildToggle.isOn)

    if isBuilding and self.m_buildingNodeId == nil and self.m_buildingId and self.m_itemData then
        local count, materialEnough, ingredients
        count = Utils.getItemCount(self.m_itemData.id, true, true)
        if count == 0 then
            materialEnough, ingredients = FactoryUtils.checkBuildingMaterialEnough(self.m_itemData.id)
            if materialEnough then
                for index = 1, FacConst.FAC_HUB_CRAFT_MAX_INCOME_NUM do
                    local itemBundle = ingredients[index]
                    if itemBundle then
                        local itemCfg = Tables.itemTable[itemBundle.id]
                        self.view.materialCostNode["icon" .. index].gameObject:SetActiveIfNecessary(true)
                        self.view.materialCostNode["icon" .. index]:LoadSprite(UIConst.UI_SPRITE_ITEM, itemCfg.iconId)
                        self.view.materialCostNode["count" .. index].text = itemBundle.count
                    else
                        self.view.materialCostNode["icon" .. index].gameObject:SetActiveIfNecessary(false)
                    end
                end
            end
        end
        if count == 0 and materialEnough then
            self.view.materialCostNode.gameObject:SetActiveIfNecessary(true)
        else
            self.view.materialCostNode.gameObject:SetActiveIfNecessary(false)
        end
    else
        self.view.materialCostNode.gameObject:SetActiveIfNecessary(false)
    end

    self.view.actionButtonsAsIcon.gameObject:SetActive(inTopView)
    self.view.actionButtonsAsOption.gameObject:SetActive(not inTopView)

    
    self.view.joystick.gameObject:SetActive(false) 

    if not isBuilding and not isBlueprint then
        self.view.moveBuildingHint.gameObject:SetActive(false)
    end

    self.view.exitBeltModeButton.gameObject:SetActive(isBelt and usingDrag)

    if isBlueprint then
        if self.m_buildArgs.isMove then
            self.view.modeName.text = Language.LUA_FAC_BUILD_MODE_TITLE_BATCH_MOVE
        elseif self.m_buildArgs.csBPInst then
            self.view.modeName.text = Language.LUA_FAC_BUILD_MODE_TITLE_BLUEPRINT
        else
            self.view.modeName.text = Language.LUA_FAC_BUILD_MODE_TITLE_BATCH_COPY
        end
    else
        self.view.modeName.text = Language.LUA_FAC_BUILD_MODE_TITLE_NORMAL
    end
    self:_UpdatePendingHint()
    self.view.normalHint.gameObject:SetActive(false)
    self.view.warningHint.gameObject:SetActive(false)

    self.m_sizeIndicator.simpleStateController:SetState(inTopView and "TopView" or "Normal")

    if inTopView then
        GameInstance.mobileMotionManager:PostEventCommonShort()
    end

    InputManagerInst:ToggleGroup(self.m_topViewBuildBindingGroupId, inTopView)
    InputManagerInst:ToggleGroup(self.m_rpgBuildBindingGroupId, not inTopView)

    
    
    self.m_currentHandler:OnEnterRefreshNodes()
end

FacBuildModeCtrl._UpdatePendingHint = HL.Method() << function(self)
    local isBlueprint = self.m_mode == FacConst.FAC_BUILD_MODE.Blueprint
    local isPending = false
    local materialEnough = false
    if isBlueprint and not self.m_buildArgs.isMove then
        local bp = self.m_buildArgs.blueprint or self.m_buildArgs.csBPInst.info.bp or self.m_buildArgs[1]
        local needItems = {}
        for _, entry in pairs(bp.buildingNodes) do
            local itemId = FactoryUtils.getBuildingItemId(entry.templateId)
            if itemId then
                if needItems[itemId] then
                    needItems[itemId] = needItems[itemId] + 1
                else
                    needItems[itemId] = 1
                end
            end
        end
        local allCostMap = {}
        for itemId, count in pairs(needItems) do
            if isPending and self.m_isCropRegion then
                break
            end
            local lackCount = count - Utils.getItemCount(itemId, true, true)
            if lackCount > 0 then
                local craftId = FactoryUtils.getBuildingHubCraftList(itemId)
                if craftId then
                    materialEnough = true
                    local craftData = Tables.factoryHubCraftTable:GetValue(craftId)
                    for index = 1, FacConst.FAC_HUB_CRAFT_MAX_INCOME_NUM do
                        if craftData.ingredients.length >= index then
                            local itemBundle = craftData.ingredients[CSIndex(index)]
                            local materialCount = Utils.getItemCount(itemBundle.id, true, true)
                            if materialCount < itemBundle.count * lackCount + (allCostMap[itemBundle.id] or 0) then
                                materialEnough = false
                                isPending = true
                                break
                            end
                            if allCostMap[itemBundle.id] then
                                allCostMap[itemBundle.id] = allCostMap[itemBundle.id] + itemBundle.count * lackCount
                            else
                                allCostMap[itemBundle.id] = itemBundle.count * lackCount
                            end
                        end
                    end
                else
                    local isManualCraftItem, manualCraftId = Tables.factoryManualCraftOutcomeToIdTable:TryGetValue(itemId)
                    if isManualCraftItem then
                        materialEnough = true
                        local manualData = Tables.factoryManualCraftTable:GetValue(manualCraftId)
                        for index = 1, FacConst.FAC_MANUAL_CRAFT_MAX_INCOME_NUM do
                            if manualData.ingredients.length >= index then
                                local itemBundle = manualData.ingredients[CSIndex(index)]
                                local materialCount = Utils.getItemCount(itemBundle.id, true, true)
                                if materialCount < itemBundle.count * lackCount + (allCostMap[itemBundle.id] or 0) then
                                    materialEnough = false
                                    isPending = true
                                    break
                                end
                                if allCostMap[itemBundle.id] then
                                    allCostMap[itemBundle.id] = allCostMap[itemBundle.id] + itemBundle.count * lackCount
                                else
                                    allCostMap[itemBundle.id] = itemBundle.count * lackCount
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if isPending and self.m_isCropRegion then
        self.view.pendingHint.gameObject:SetActive(false)
        return
    end
    self.view.pendingHint.gameObject:SetActive(materialEnough or isPending)
    if materialEnough or isPending then
        self.view.pendingHint:SetState(isPending and "Pending" or "Enough")
    end
end







local KeyHints = {
    newBuilding = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    newBuildingInTopView = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_continuous_confirm",
        "fac_build_cancel_alter",
    },
    oldBuilding = {
        "fac_build_mode_delete",
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    blueprint = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel",
    },
    logistic = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    logisticInTopView = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_continuous_confirm",
        "fac_build_cancel_alter",
    },
    beltStart = {
        "fac_build_confirm_belt_start",
        "fac_build_rotate_belt",
        "fac_build_cancel_alter",
    },
    beltEnd = {
        "fac_build_confirm_belt_end",
        "fac_build_rotate_belt",
        "fac_build_cancel_alter",
    },
    pipeStart = {
        "fac_build_confirm_belt_start",
        "fac_build_rotate_pipe",
        "fac_build_cancel_alter",
    },
    pipeEnd = {
        "fac_build_confirm_belt_end",
        "fac_build_rotate_pipe",
        "fac_build_cancel_alter",
    },
    signBuilding = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_sign_reset",
        "fac_build_cancel_alter",
    },
}

FacBuildModeCtrl.m_keyHintCells = HL.Field(HL.Forward('UIListCache'))

FacBuildModeCtrl._InitKeyHint = HL.Method() << function(self)
    self.m_keyHintCells = self.m_keyHintCells or UIUtils.genCellCache(self.view.keyHintCell)
end

FacBuildModeCtrl._RefreshKeyHint = HL.Method(HL.Opt(HL.Table)) << function(self, keyHint)
    if not keyHint then
        self.m_keyHintCells:Refresh(0)
        return
    end

    if DeviceInfo.usingController and LuaSystemManager.factory.inTopView then
        
        keyHint = {}
    end

    local count = #keyHint
    local preActionIds, preActionIdCount
    if LuaSystemManager.factory.inTopView then
        preActionIds = DeviceInfo.usingController and FacConst.FAC_TOP_VIEW_BASIC_ACTION_IDS_FOR_CONTROLLER or FacConst.FAC_TOP_VIEW_BASIC_ACTION_IDS
        preActionIdCount = #preActionIds
        count = count + preActionIdCount
    else
        preActionIds = { "cam_zoom_in_ct", }
        preActionIdCount = #preActionIds
        count = count + preActionIdCount
    end

    self.m_keyHintCells:Refresh(count, function(cell, index)
        local actionId
        if preActionIds then
            actionId = preActionIds[index] or keyHint[index - preActionIdCount]
        else
            actionId = keyHint[index]
        end
        if LuaSystemManager.factory.inTopView then
            if actionId == "fac_build_confirm" then
                actionId = "fac_build_confirm_in_top_view"
            elseif actionId == "fac_build_mode_delete" then
                actionId = "fac_build_mode_delete_in_top_view"
            elseif actionId == "fac_build_confirm_belt_start" then
                actionId = "fac_build_confirm_belt_start_in_top_view"
            end
        end
        cell.actionKeyHint:SetActionId(actionId)
        cell.gameObject.name = "KeyHint-" .. actionId
    end)
end






FacBuildModeCtrl.m_curBuildIsValid = HL.Field(HL.Boolean) << true


FacBuildModeCtrl._ApplyPlacementResult = HL.Method(HL.Boolean, HL.Opt(HL.String, HL.String, HL.String, HL.String, HL.String, HL.Boolean)) << function(self, valid, errorHint, actionHint, actionColor, warningHint, normalHint, actionHintIsStatic)
    if errorHint then
        if not self.view.errorHint.gameObject.activeInHierarchy then
            UIUtils.PlayAnimationAndToggleActive(self.view.errorHint, true)
        end
        self.view.errorHintText:SetAndResolveTextStyle(errorHint)
    else
        if self.view.errorHint.gameObject.activeInHierarchy and self.view.errorHint.curState ~= UIConst.UI_ANIMATION_WRAPPER_STATE.Out then
            UIUtils.PlayAnimationAndToggleActive(self.view.errorHint, false)
        end
    end
    if actionHintIsStatic then
        
        self.view.actionHint.gameObject:SetActive(errorHint == nil)
    else
        if actionHint then
            if not self.view.actionHint.gameObject.activeInHierarchy then
                UIUtils.PlayAnimationAndToggleActive(self.view.actionHint, true)
            end
            self.view.actionHintTxt:SetAndResolveTextStyle(actionHint)
            self.view.actionColorCtrl:SetState(actionColor)
        else
            if self.view.actionHint.gameObject.activeInHierarchy and self.view.actionHint.curState ~= UIConst.UI_ANIMATION_WRAPPER_STATE.Out then
                UIUtils.PlayAnimationAndToggleActive(self.view.actionHint, false)
            end
        end
    end
    if warningHint then
        if not self.view.warningHint.gameObject.activeInHierarchy then
            UIUtils.PlayAnimationAndToggleActive(self.view.warningHint, true)
        end
        self.view.warningHintTxt:SetAndResolveTextStyle(warningHint)
    else
        if self.view.warningHint.gameObject.activeInHierarchy and self.view.warningHint.curState ~= UIConst.UI_ANIMATION_WRAPPER_STATE.Out then
            UIUtils.PlayAnimationAndToggleActive(self.view.warningHint, false)
        end
    end
    if normalHint then
        if not self.view.normalHint.gameObject.activeInHierarchy then
            UIUtils.PlayAnimationAndToggleActive(self.view.normalHint, true)
        end
        self.view.normalHintTxt:SetAndResolveTextStyle(normalHint)
    else
        if self.view.normalHint.gameObject.activeInHierarchy and self.view.normalHint.curState ~= UIConst.UI_ANIMATION_WRAPPER_STATE.Out then
            UIUtils.PlayAnimationAndToggleActive(self.view.normalHint, false)
        end
    end
    self.m_curBuildIsValid = valid
end


FacBuildModeCtrl.RefreshValidResult = HL.Method() << function(self)
    local handler = self.m_currentHandler
    if not handler or self.m_mode == FacConst.FAC_BUILD_MODE.Normal then
        return
    end
    local r = handler:EvaluatePlacement()
    if not r then
        return
    end
    self:_ApplyPlacementResult(r.valid, r.errorHint, r.actionHint, r.actionColor or "Black", r.warningHint, r.normalHint,
        r.actionHintIsStatic == true)
    handler.m_provider:SetPreviewResultState(r.valid)
end






FacBuildModeCtrl.GetRecoverBuildStateOnChangeDevice = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local handler = self.m_currentHandler
    if handler then
        return handler:GetRecoverState()
    end
    return nil
end

FacBuildModeCtrl._ResetMoveBuildingHintState = HL.Method() << function(self)
    self.view.moveBuildingHint.gameObject:SetActiveIfNecessary(false)
    self.view.rebuildInfoTxt.gameObject:SetActive(true)
    self.view.noPowerTxt.gameObject:SetActive(false)
    self.view.noElectricity.gameObject:SetActive(false)
    if self.view.keepConnected then
        self.view.keepConnected.gameObject:SetActiveIfNecessary(false)
    end
    if self.view.noConnected then
        self.view.noConnected.gameObject:SetActiveIfNecessary(false)
    end
end


FacBuildModeCtrl._TryExitLinkWireOnBuildingMove = HL.Method(HL.Any) << function(self, moveTarget)
    local linkBrain = GameWorld.gameMechManager.linkWireBrain
    if not linkBrain.isLinking then
        return
    end
    local sourceNodeId = linkBrain.currentLinkSourceNodeId
    if sourceNodeId == 0 then
        return
    end
    if (type(moveTarget) == "number" and sourceNodeId == moveTarget)
        or (type(moveTarget) == "table" and moveTarget[sourceNodeId]) then
        linkBrain:EndLinkWithCancel(true)
    end
end

FacBuildModeCtrl._DelBuilding = HL.Method() << function(self)
    if not self:_CanDelBuilding() then
        return
    end
    if self.m_currentHandler then
        self.m_currentHandler:OnDelete()
    end
end

FacBuildModeCtrl._CanDelBuilding = HL.Method().Return(HL.Boolean) << function(self)
    local handler = self.m_currentHandler
    return handler ~= nil and handler:CanDelete()
end

FacBuildModeCtrl._RotateUnit = HL.Method() << function(self)
    if not self:_CanRotate() then
        return
    end
    self.m_currentHandler:OnRotate()
    if DeviceInfo.usingKeyboard then
        self:_UpdateAutoMoveTopViewCamState()
    end
    AudioAdapter.PostEvent("au_ui_building_turn")
end

FacBuildModeCtrl._CanRotate = HL.Method().Return(HL.Boolean) << function(self)
    local handler = self.m_currentHandler
    return handler ~= nil and handler:CanRotate()
end

FacBuildModeCtrl._UpdateAutoMoveTopViewCamState = HL.Method(HL.Opt(HL.Any)) << function(self, extraPadding)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    local handler = self.m_currentHandler
    local size = handler and handler:GetAutoMoveCamSize() or Vector2.one
    LuaSystemManager.factory:ToggleAutoMoveTopViewCam(size, extraPadding)
end







FacBuildModeCtrl._ProcessSignBuildSetting = HL.Method() << function(self)
    local isSign = FacConst.SIGN_BUILDING_EXTRA_SETTING_PANEL[self.m_buildingId] or false
    local isMoving = self.m_buildingNodeId ~= nil
    self.view.actionButtonsAsOption.signResetButton.gameObject:SetActiveIfNecessary(isSign and not isMoving)
    InputManagerInst:ToggleBinding(self.m_signResetBindingId, isSign and not isMoving)
    if isSign then
        if isMoving then
            local icons = GameInstance.remoteFactoryManager:GetSignBuildingIcons(self.m_buildingNodeId)
            GameInstance.remoteFactoryManager:SetPreviewSignBuildingIcon(icons[0], icons[1], icons[2])
        else
            self:_RefreshKeyHint(KeyHints.signBuilding)
            self:_OpenSignSettingPanel(false)
        end
    end
end

FacBuildModeCtrl._OpenSignSettingPanel = HL.Method(HL.Boolean) << function(self, reset)
    self.m_lockBuildPos = true
    self.view.actionButtonsAsOption.gameObject:SetActive(false)
    self.view.errorHint.gameObject:SetActiveIfNecessary(false)
    self.view.actionHint.gameObject:SetActiveIfNecessary(false)
    if self.m_sizeIndicator then
        self.m_sizeIndicator.gameObject:SetActive(false)
    end
    if reset then
        UIManager:AutoOpen(PanelId.FacMarkerConfirm, {
            reset = reset,
            onConfirm = function()
                self.m_lockBuildPos = false
                self.view.actionButtonsAsOption.gameObject:SetActive(true)
                if self.m_sizeIndicator then
                    self.m_sizeIndicator.gameObject:SetActive(true)
                end
            end,
            onClose = function()
                self.m_lockBuildPos = false
                self.view.actionButtonsAsOption.gameObject:SetActive(true)
                if self.m_sizeIndicator then
                    self.m_sizeIndicator.gameObject:SetActive(true)
                end
            end
        })
    else
        UIManager:AutoOpen(PanelId.FacMarkerConfirm, {
            reset = reset,
            onConfirm = function()
                self.m_lockBuildPos = false
                self.view.actionButtonsAsOption.gameObject:SetActive(true)
                if self.m_sizeIndicator then
                    self.m_sizeIndicator.gameObject:SetActive(true)
                end
            end,
            onClose = function()
                self:_ExitCurMode(true)
            end
        })
    end
end

FacBuildModeCtrl._CheckSignCanBuild = HL.Method().Return(HL.Boolean) << function(self)
    local isSign = FacConst.SIGN_BUILDING_EXTRA_SETTING_PANEL[self.m_buildingId]
    if isSign then
        local curNum = FactoryUtils.getPlayerAllMarkerBuildingNodeInfo()
        local maxNum = Tables.factoryConst.signNodeCountLimit
        local detla = self.m_buildingNodeId == nil and 1 or 0
        return curNum + detla <= maxNum
    end
    return true
end

FacBuildModeCtrl._CheckBanAndToastSignInTopView = HL.StaticMethod().Return(HL.Boolean) << function(itemId)
    local ban = false
    if FacConst.SIGN_BUILDING_BAN_IN_TOPVIEW[itemId] then
        if GameInstance.player.gameSettingSystem.forbiddenFactorySign then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BAN_SIGN_SDK_FORBIDDEN)
            ban = true
        elseif LuaSystemManager.factory.inTopView then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BAN_SIGN_IN_TOP_VIEW)
            ban = true
        end
    end
    return ban
end






FacBuildModeCtrl.FacOnBuildingBatchMoved = HL.Method() << function(self)
    
    if self.m_currentHandler then
        self.m_currentHandler:OnBuildingBatchMoved()
    end
end

FacBuildModeCtrl.m_lastBPGridPos = HL.Field(HL.Any)











FacBuildModeCtrl.m_bpStartPreviewMarkLastPos = HL.Field(HL.Userdata)

FacBuildModeCtrl.m_bpStartPreviewMarkLastColor = HL.Field(Color)


FacBuildModeCtrl.OnInteractConveyorLocalCheckingFailed = HL.Method(HL.Table) << function(self, args)
    
    if self.m_currentHandler then
        self.m_currentHandler:OnConveyorLocalCheckFailed(args)
    end
end


FacBuildModeCtrl.m_beltHasStartLastTick = HL.Field(HL.Boolean) << false






FacBuildModeCtrl._GetCurPointerPressPos = HL.Method().Return(Vector3) << function(self)
    
    if self.m_lockBuildPos then
        return CameraManager.mainCamera:WorldToScreenPoint(self.m_lastMouseWorldPos)
    end
    if LuaSystemManager.factory.inTopView then
        if DeviceInfo.usingTouch then
            return UIManager.commonTouchPanel.touchPos:XY()
        else
            return InputManager.mousePosition
        end
    else
        if not InputManager.cursorVisible or DeviceInfo.usingTouch then
            return Vector3(Screen.width / 2, Screen.height / 2, 0)
        end
        return InputManager.mousePosition
    end
end

FacBuildModeCtrl._InDragMode = HL.Method().Return(HL.Boolean) << function(self)
    
    return DeviceInfo.usingTouch and LuaSystemManager.factory.inTopView
end

FacBuildModeCtrl._IsPipe = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_beltId == FacConst.PIPE_ID
end

FacBuildModeCtrl.DebugOutputPrepareBuildingPosInfo = HL.Method() << function(self)
    local handler = self.m_currentHandler
    if not handler then
        return
    end
    local posInfo = handler:GetDebugPosInfo()
    if not posInfo then
        return
    end
    local id, pos, dir = posInfo.id, posInfo.pos, posInfo.dir
    local info = string.format("%s %s %d", id, pos:ToString(), dir)
    Unity.GUIUtility.systemCopyBuffer = info
    Notify(MessageConst.SHOW_TOAST, string.format("DEBUG: 已复制 %s", info))
    logger.error("DebugOutputPrepareBuildingPosInfo", info)
end






FacBuildModeCtrl.GetCurBuildMode = HL.Method().Return(HL.Number) << function(self)
    return self.m_mode
end

FacBuildModeCtrl.GetMovingBuildingNodeId = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_buildingNodeId
end

FacBuildModeCtrl.CanRotateBuild = HL.Method().Return(HL.Boolean) << function(self)
    return self:_CanRotate()
end

FacBuildModeCtrl.IsBuildingPipe = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_mode == FacConst.FAC_BUILD_MODE.Belt and self:_IsPipe()
end

FacBuildModeCtrl.GetHotSwitchStateArgs = HL.Method().Return(HL.Table) << function(self)
    
    return { self.m_mode, self.m_buildArgs, self:GetRecoverBuildStateOnChangeDevice() }
end






FacBuildModeCtrl.s_enableConfirmBuild = HL.StaticField(HL.Boolean) << true

FacBuildModeCtrl.SetEnableConfirmBuild = HL.StaticMethod(HL.Table) << function(args)
    local enable = unpack(args)
    FacBuildModeCtrl.s_enableConfirmBuild = enable
end

FacBuildModeCtrl.s_enableExitBuildMode = HL.StaticField(HL.Boolean) << true

FacBuildModeCtrl.SetEnableExitBuildMode = HL.StaticMethod(HL.Table) << function(args)
    local enable = unpack(args)
    FacBuildModeCtrl.s_enableExitBuildMode = enable
end

FacBuildModeCtrl.m_lockBuildPos = HL.Field(HL.Boolean) << false

FacBuildModeCtrl.FacLockBuildPos = HL.Method(HL.Table) << function(self, arg)
    local isLock = unpack(arg)
    self.m_lockBuildPos = isLock
end






FacBuildModeCtrl._OnChangeContinueToggle = HL.Method(HL.Boolean) << function(self, isOn)
    FacBuildModeCtrl.s_enableContinueBuild = isOn
    UIUtils.PlayAnimationAndToggleActive(self.view.actionButtonsAsIcon.continueBuildHint, isOn)
end

FacBuildModeCtrl._EnableContinueBuild = HL.Method().Return(HL.Boolean) << function(self)
    
    if FacConst.SIGN_BUILDING_EXTRA_SETTING_PANEL[self.m_buildingId] then
        return false
    end
    if LuaSystemManager.factory.inTopView then
        if DeviceInfo.usingKeyboard then
            return InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.LeftControl)
        elseif DeviceInfo.usingController then
            return InputManagerInst:GetKey(CS.Beyond.Input.GamepadKeyCode.LT)
        end
    end
    return FacBuildModeCtrl.s_enableContinueBuild
end


FacBuildModeCtrl.m_onPlaceFinish = HL.Field(HL.Function)




HL.Commit(FacBuildModeCtrl)
