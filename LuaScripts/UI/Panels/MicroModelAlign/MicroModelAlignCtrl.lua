local uiCtrl = require_ex("UI/Panels/Base/UICtrl")

local PANEL_ID = PanelId.MicroModelAlign
local PHASE_ID = PhaseId.MicroModelAlign

local PREVIEW_INSTANCE_NAME = "__MicroModelAlignPreview__"
local PIVOT_INSTANCE_NAME = "__MicroModelAlignPivot__"
local ACTION_RESET_PERSPECTIVE = "micro_model_align_reset_perspective"
local ACTION_ZOOM_IN_START = "micro_model_align_zoom_in_start"
local ACTION_ZOOM_IN_END = "micro_model_align_zoom_in_end"
local ACTION_ZOOM_OUT_START = "micro_model_align_zoom_out_start"
local ACTION_ZOOM_OUT_END = "micro_model_align_zoom_out_end"
local ACTION_EXIT = "micro_model_align_exit"
local MicroModelAlignModelViewStateHelper = CS.Beyond.Gameplay.Actions.MicroModelAlignModelViewStateHelper


MicroModelAlignCtrl = HL.Class("MicroModelAlignCtrl", uiCtrl.UICtrl)

MicroModelAlignCtrl.s_messages = HL.StaticField(HL.Table) << {}
MicroModelAlignCtrl.s_previewPivot = HL.StaticField(HL.Any)
MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy = HL.StaticField(HL.Any)

MicroModelAlignCtrl.m_arg = HL.Field(HL.Table)
MicroModelAlignCtrl.m_updateKey = HL.Field(HL.Number) << -1
MicroModelAlignCtrl.m_onTouchPanelDrag = HL.Field(HL.Function)
MicroModelAlignCtrl.m_onTouchPanelZoom = HL.Field(HL.Function)
MicroModelAlignCtrl.m_judgeState = HL.Field(HL.Table)
MicroModelAlignCtrl.m_previewInstance = HL.Field(HL.Any)
MicroModelAlignCtrl.m_previewPivot = HL.Field(HL.Any)
MicroModelAlignCtrl.m_previewModelViewStateCtrlProxy = HL.Field(HL.Any)
MicroModelAlignCtrl.m_cameraCtrl = HL.Field(HL.Any)
MicroModelAlignCtrl.m_currentScale = HL.Field(HL.Number) << 1
MicroModelAlignCtrl.m_scaleStep = HL.Field(HL.Number) << 0.05
MicroModelAlignCtrl.m_addScaleCoroutine = HL.Field(HL.Thread)
MicroModelAlignCtrl.m_minusScaleCoroutine = HL.Field(HL.Thread)
MicroModelAlignCtrl.m_scaleDisplayOffset = HL.Field(HL.Number) << 0
MicroModelAlignCtrl.m_successTodoLogged = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_openElapsed = HL.Field(HL.Number) << 0
MicroModelAlignCtrl.m_timeoutFired = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_isFinishing = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_completeFlowDone = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_finishElapsed = HL.Field(HL.Number) << 0
MicroModelAlignCtrl.m_finishDuration = HL.Field(HL.Number) << 0
MicroModelAlignCtrl.m_finishStartScale = HL.Field(HL.Number) << 1
MicroModelAlignCtrl.m_finishStartCameraRotation = HL.Field(HL.Any)
MicroModelAlignCtrl.m_finishTargetCameraRotation = HL.Field(HL.Any)
MicroModelAlignCtrl.m_finishStartCenterPosition = HL.Field(HL.Any)
MicroModelAlignCtrl.m_finishTargetCenterPosition = HL.Field(HL.Any)
MicroModelAlignCtrl.m_isCompleteToastFlow = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_completeToastElapsed = HL.Field(HL.Number) << 0
MicroModelAlignCtrl.m_completeToastClosed = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_completeOutStarted = HL.Field(HL.Boolean) << false
MicroModelAlignCtrl.m_completeOutFinished = HL.Field(HL.Boolean) << false

MicroModelAlignCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitArg(arg)
    
    if self.m_arg.onOpenCallBack then
        self.m_arg.onOpenCallBack()
    end
    self:_EnterMicroModelCamera()
    self:_SetAllSquadMembersVisible(false)
    self:_BindUI()
    self:_RefreshScaleUI()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:_DestroyExistingPreviewPivot()
    self:_CreatePreviewInstance()
    self:_ApplyResumeState()
    
    
    if InputManagerInst.inChangingInputDevice then
        if self.m_isFinishing then
            self:_TickCompleteAlignAnim(0)
            return
        end
        if self.m_isCompleteToastFlow then
            self:_TickCompleteToastFlow(0)
            return
        end
        if self.m_completeFlowDone then
            return
        end
    end
    self:_UpdateJudge(0)
end

MicroModelAlignCtrl.OnClose = HL.Override() << function(self)
    local isHotSwitch = InputManagerInst.inChangingInputDevice
    self:_ClearRegisters()
    self:_ExitMicroModelCamera(isHotSwitch)
    
    
    local isCompleted = self.m_completeFlowDone
    if not isHotSwitch and not isCompleted and self.m_arg.onCloseCallBack then
        self.m_arg.onCloseCallBack()
    end
    
    if not isHotSwitch and isCompleted and self.m_arg.onAlignmentCompleteCallBack then
        self.m_arg.onAlignmentCompleteCallBack()
    end
end

MicroModelAlignCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegisters()
end

MicroModelAlignCtrl.OnHide = HL.Override() << function(self)
    self:_ClearRegisters()
end

MicroModelAlignCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = {}
    for key, value in pairs(self.m_arg) do
        arg[key] = value
    end
    arg.resumeState = self:_BuildResumeState()
    return arg
end



MicroModelAlignCtrl._InitArg = HL.Method(HL.Any) << function(self, arg)
    local resumeState = arg.resumeState

    
    local correctDuration = Tables.globalConst.microModelAlignCorrectDuration
    local defaultScale = arg.defaultScale
    local minScale = defaultScale - arg.scaleRange
    local maxScale = defaultScale + arg.scaleRange
    local currentScale = defaultScale
    if resumeState ~= nil and resumeState.currentScale ~= nil then
        currentScale = resumeState.currentScale
    end

    self.m_arg = {
        cameraPosition = arg.cameraPosition, 
        cameraRotation = arg.cameraRotation, 
        modelPath = arg.modelPath, 
        modelViewStateCtrlId = arg.modelViewStateCtrlId, 
        modelCenterOffset = arg.modelCenterOffset, 
        targetWorldPosition = arg.targetWorldPosition, 
        targetWorldRotation = arg.targetWorldRotation, 
        horizontalRotationLimit = arg.horizontalRotationLimit, 
        verticalRotationLimit = arg.verticalRotationLimit, 
        initialYawOffset = arg.initialYawOffset,
        initialPitchOffset = arg.initialPitchOffset,
        defaultScale = defaultScale,
        scaleRange = arg.scaleRange,
        correctScale = arg.correctScale,
        scaleTolerance = arg.scaleTolerance,
        distanceTolerance = arg.distanceTolerance,
        distance = arg.distance, 
        cameraFov = arg.cameraFov,
        correctCameraRotation = arg.correctCameraRotation, 
        initialModelRotation = arg.initialModelRotation, 
        sourceEntityId = arg.sourceEntityId,
        completeAlignDuration = arg.completeAlignDuration, 
        delayCompleteEventByAlignDuration = arg.delayCompleteEventByAlignDuration, 
        completeToastCloseDelay = arg.completeToastCloseDelay, 
        completeFlowCloseDelay = arg.completeFlowCloseDelay, 
        
        
        onOpenCallBack = arg.onOpenCallBack,
        
        onCloseCallBack = arg.onCloseCallBack,
        onAlignmentCompleteCallBack = arg.onAlignmentCompleteCallBack,
        onRaiseCompleteLevelEventCallBack = arg.onRaiseCompleteLevelEventCallBack,
        
        hintTimeout = arg.hintTimeout,
        onTimeoutCallBack = arg.onTimeoutCallBack,
        
        minScale = minScale,
        maxScale = maxScale,
        correctDuration = correctDuration,
        resumeState = resumeState,
    }
    self.m_currentScale = math.max(minScale, math.min(maxScale, currentScale))
    self.m_scaleStep = (maxScale - minScale) / 20
    self.m_scaleDisplayOffset = 1 - defaultScale
    self.m_judgeState = {
        posOk = false,
        scaleOk = false,
        isInTolerance = false,
        elapsed = 0,
        isSuccess = false,
    }
    self.m_successTodoLogged = false
    self.m_openElapsed = 0
    self.m_timeoutFired = false
    self.m_isFinishing = false
    self.m_completeFlowDone = false
    self.m_finishElapsed = 0
    self.m_finishDuration = 0
    self.m_finishStartScale = 1
    self.m_finishStartCameraRotation = nil
    self.m_finishTargetCameraRotation = nil
    self.m_finishStartCenterPosition = nil
    self.m_finishTargetCenterPosition = nil
    self.m_isCompleteToastFlow = false
    self.m_completeToastElapsed = 0
    self.m_completeToastClosed = false
    self.m_completeOutStarted = false
    self.m_completeOutFinished = false
end

MicroModelAlignCtrl._EnterMicroModelCamera = HL.Method() << function(self)
    self.m_cameraCtrl = CameraManager:LoadPersistentController("MicroModelAlignCamera")
    self.m_cameraCtrl:SetupConfig(
        self.m_arg.cameraPosition,
        self.m_arg.cameraRotation,
        self.m_arg.horizontalRotationLimit,
        self.m_arg.verticalRotationLimit,
        self.m_arg.cameraFov
    )
end

MicroModelAlignCtrl._ExitMicroModelCamera = HL.Method(HL.Boolean) << function(self, isHotSwitch)
    if isHotSwitch then
        return
    end
    self:_SetAllSquadMembersVisible(true)
    self:_DestroyPreviewInstance()
    CameraManager:RemoveCameraController(self.m_cameraCtrl)
    self.m_cameraCtrl = nil
end

MicroModelAlignCtrl._ResetPerspective = HL.Method() << function(self)
    if self.m_isFinishing or self.m_isCompleteToastFlow then
        return
    end
    self.m_cameraCtrl:ResetPerspective()
    self:_ApplyScaleValue(self.m_arg.defaultScale)
    self:_UpdateJudge(0)
end


MicroModelAlignCtrl._ApplyResumeState = HL.Method() << function(self)
    local resumeState = self.m_arg.resumeState
    if resumeState == nil then
        return
    end
    if resumeState.currentScale ~= nil then
        self.m_currentScale = resumeState.currentScale
        self:_ApplyScaleValue(self.m_currentScale)
    end
    
    if resumeState.openElapsed ~= nil then
        self.m_openElapsed = resumeState.openElapsed
    end
    if resumeState.timeoutFired ~= nil then
        self.m_timeoutFired = resumeState.timeoutFired
    end
    if resumeState.completeFlowDone then
        self.m_successTodoLogged = true
        self.m_completeFlowDone = true
    end
    local cameraState = resumeState.camera
    if cameraState == nil then
        return
    end
    self.m_cameraCtrl:SetCameraRotation(cameraState.rotation)
    local finishingState = resumeState.finishing
    if finishingState ~= nil and finishingState.isFinishing then
        self.m_successTodoLogged = true
        if not self.m_arg.delayCompleteEventByAlignDuration then
            self:_SetPreviewModelViewState(0)
        end
        self.m_isFinishing = true
        self.m_isCompleteToastFlow = false
        self.m_completeFlowDone = false
        self.m_finishDuration = finishingState.duration
        self.m_finishElapsed = finishingState.elapsed
        self.m_finishStartScale = finishingState.startScale
        self.m_finishStartCameraRotation = finishingState.startCameraRotation
        self.m_finishTargetCameraRotation = finishingState.targetCameraRotation
        self.m_finishStartCenterPosition = finishingState.startCenterPosition
        self.m_finishTargetCenterPosition = finishingState.targetCenterPosition
        if self.m_finishDuration > 0 then
            self.m_finishElapsed = math.min(self.m_finishElapsed, self.m_finishDuration)
        end
    end
    local completeToastState = resumeState.completeToast
    if completeToastState ~= nil and completeToastState.isCompleteToastFlow then
        self.m_successTodoLogged = true
        self:_SetPreviewModelViewState(0)
        self.m_isFinishing = false
        self.m_isCompleteToastFlow = true
        self.m_completeFlowDone = false
        self.m_completeToastElapsed = completeToastState.elapsed
        self.m_completeToastClosed = completeToastState.toastClosed
    end
    if resumeState.completeOutStarted then
        self:_StartCompleteAnimationOut()
    end
end



MicroModelAlignCtrl._CreatePreviewInstance = HL.Method() << function(self)
    local mainCamera = CameraManager.mainCamera
    local prefab = self:LoadGameObject(self.m_arg.modelPath)
    local pivot = GameObject(PIVOT_INSTANCE_NAME)
    self.m_previewPivot = pivot
    MicroModelAlignCtrl.s_previewPivot = pivot

    local pivotTrans = pivot.transform
    pivotTrans:SetParent(mainCamera.transform, false)

    
    self.m_previewInstance = CSUtils.CreateObject(prefab, pivotTrans)
    self.m_previewInstance.name = PREVIEW_INSTANCE_NAME
    
    
    
    local localPos = Quaternion.Euler(self.m_arg.initialPitchOffset, self.m_arg.initialYawOffset, 0) * Vector3.forward * self.m_arg.distance
    local initialModelRotation = self.m_arg.initialModelRotation
    local centerOffset = self.m_arg.modelCenterOffset
    pivotTrans.localPosition = localPos + Quaternion.Euler(initialModelRotation) * centerOffset
    pivotTrans.localRotation = Quaternion.Euler(initialModelRotation)
    pivotTrans.localScale = Vector3.one

    local trans = self.m_previewInstance.transform
    trans.localPosition = centerOffset * -1
    trans.localRotation = Quaternion.identity
    trans.localScale = Vector3.one
    self:_ApplyScaleValue(self.m_currentScale)
    self:_CreatePreviewModelViewStateCtrlProxy()
    self:_SetPreviewModelViewState(1)
end

MicroModelAlignCtrl._DestroyPreviewInstance = HL.Method() << function(self)
    self:_ReleasePreviewModelViewStateCtrlProxy()
    GameObject.Destroy(self.m_previewPivot)
    if MicroModelAlignCtrl.s_previewPivot == self.m_previewPivot then
        MicroModelAlignCtrl.s_previewPivot = nil
    end
    self.m_previewPivot = nil
    self.m_previewInstance = nil
end

MicroModelAlignCtrl._DestroyExistingPreviewPivot = HL.Method() << function(self)
    local previewModelViewStateCtrlProxy = MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy
    if previewModelViewStateCtrlProxy ~= nil then
        MicroModelAlignModelViewStateHelper.Release(previewModelViewStateCtrlProxy)
    end
    MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy = nil

    local previewPivot = MicroModelAlignCtrl.s_previewPivot
    if previewPivot ~= nil and not IsNull(previewPivot) then
        GameObject.Destroy(previewPivot)
    end
    MicroModelAlignCtrl.s_previewPivot = nil
end

MicroModelAlignCtrl._CreatePreviewModelViewStateCtrlProxy = HL.Method() << function(self)
    if self.m_arg.modelViewStateCtrlId == nil or string.isEmpty(self.m_arg.modelViewStateCtrlId) then
        return
    end
    self:_ReleasePreviewModelViewStateCtrlProxy()
    self.m_previewModelViewStateCtrlProxy = MicroModelAlignModelViewStateHelper.Create(self.m_arg.modelViewStateCtrlId, self.m_previewInstance)
    MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy = self.m_previewModelViewStateCtrlProxy
end

MicroModelAlignCtrl._SetPreviewModelViewState = HL.Method(HL.Number) << function(self, state)
    if self.m_previewModelViewStateCtrlProxy ~= nil then
        MicroModelAlignModelViewStateHelper.SetState(self.m_previewModelViewStateCtrlProxy, state)
    end
end

MicroModelAlignCtrl._ReleasePreviewModelViewStateCtrlProxy = HL.Method() << function(self)
    if self.m_previewModelViewStateCtrlProxy ~= nil then
        MicroModelAlignModelViewStateHelper.Release(self.m_previewModelViewStateCtrlProxy)
    end
    if MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy == self.m_previewModelViewStateCtrlProxy then
        MicroModelAlignCtrl.s_previewModelViewStateCtrlProxy = nil
    end
    self.m_previewModelViewStateCtrlProxy = nil
end

MicroModelAlignCtrl._BindUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:_ClosePhase()
    end)
    self.view.downNode.addBtn.onPressStart:AddListener(function()
        self.m_addScaleCoroutine = self:_ClearCoroutine(self.m_addScaleCoroutine)
        self.m_addScaleCoroutine = self:_StartScaleChangeCoroutine(1)
    end)
    self.view.downNode.addBtn.onPressEnd:AddListener(function()
        self.m_addScaleCoroutine = self:_ClearCoroutine(self.m_addScaleCoroutine)
    end)
    self.view.downNode.minusBtn.onPressStart:AddListener(function()
        self.m_minusScaleCoroutine = self:_ClearCoroutine(self.m_minusScaleCoroutine)
        self.m_minusScaleCoroutine = self:_StartScaleChangeCoroutine(-1)
    end)
    self.view.downNode.minusBtn.onPressEnd:AddListener(function()
        self.m_minusScaleCoroutine = self:_ClearCoroutine(self.m_minusScaleCoroutine)
    end)
    self.view.downNode.revertBtn.onClick:AddListener(function()
        self:_ResetPerspective()
    end)
    self.view.downNode.scaleSlider.minValue = self:_GetDisplayScale(self.m_arg.minScale)
    self.view.downNode.scaleSlider.maxValue = self:_GetDisplayScale(self.m_arg.maxScale)
    self.view.downNode.scaleSlider.wholeNumbers = false
    self.view.downNode.scaleSlider:SetValueWithoutNotify(self:_GetDisplayScale(self.m_currentScale))
    self.view.downNode.scaleSlider.onValueChanged:AddListener(function(value)
        self:_ApplyScaleValue(self:_GetRealScale(value))
    end)
end

MicroModelAlignCtrl._AddRegisters = HL.Method() << function(self)
    if self.m_updateKey >= 0 then
        return
    end
    self.m_updateKey = LuaUpdate:Add("Tick", function()
        self:_Tick()
    end)
    self:BindInputPlayerAction(ACTION_RESET_PERSPECTIVE, function()
        self:_ResetPerspective()
    end)
    self:BindInputPlayerAction(ACTION_ZOOM_IN_START, function()
        self.m_addScaleCoroutine = self:_ClearCoroutine(self.m_addScaleCoroutine)
        self.m_addScaleCoroutine = self:_StartScaleChangeCoroutine(1)
    end)
    self:BindInputPlayerAction(ACTION_ZOOM_IN_END, function()
        self.m_addScaleCoroutine = self:_ClearCoroutine(self.m_addScaleCoroutine)
    end)
    self:BindInputPlayerAction(ACTION_ZOOM_OUT_START, function()
        self.m_minusScaleCoroutine = self:_ClearCoroutine(self.m_minusScaleCoroutine)
        self.m_minusScaleCoroutine = self:_StartScaleChangeCoroutine(-1)
    end)
    self:BindInputPlayerAction(ACTION_ZOOM_OUT_END, function()
        self.m_minusScaleCoroutine = self:_ClearCoroutine(self.m_minusScaleCoroutine)
    end)
    self:BindInputPlayerAction(ACTION_EXIT, function()
        self:_ClosePhase()
    end)
    local touchPanel = UIManager.commonTouchPanel
    if self.m_onTouchPanelDrag == nil then
        self.m_onTouchPanelDrag = function(eventData)
            if eventData.button == CS.UnityEngine.EventSystems.PointerEventData.InputButton.Right then
                return
            end
            self:_RotateCameraByDelta(eventData.delta)
        end
    end
    touchPanel.onDrag:AddListener(self.m_onTouchPanelDrag)
    if self.m_onTouchPanelZoom == nil then
        self.m_onTouchPanelZoom = function(delta)
            local range = self.m_arg.maxScale - self.m_arg.minScale
            if DeviceInfo.usingTouch then
                delta = -delta
            end
            self:_ApplyScaleDelta(delta / Screen.height * range * 4)
        end
    end
    touchPanel.onZoom:AddListener(self.m_onTouchPanelZoom)
end

MicroModelAlignCtrl._ClearRegisters = HL.Method() << function(self)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
    self.m_addScaleCoroutine = self:_ClearCoroutine(self.m_addScaleCoroutine)
    self.m_minusScaleCoroutine = self:_ClearCoroutine(self.m_minusScaleCoroutine)
    local touchPanel = UIManager.commonTouchPanel
    if touchPanel ~= nil then
        if self.m_onTouchPanelDrag ~= nil then
            touchPanel.onDrag:RemoveListener(self.m_onTouchPanelDrag)
        end
        if self.m_onTouchPanelZoom ~= nil then
            touchPanel.onZoom:RemoveListener(self.m_onTouchPanelZoom)
        end
    end
end

MicroModelAlignCtrl._Tick = HL.Method() << function(self)
    if self.m_isFinishing then
        self:_TickCompleteAlignAnim(Time.deltaTime)
        return
    end
    if self.m_isCompleteToastFlow then
        self:_TickCompleteToastFlow(Time.deltaTime)
        return
    end
    if DeviceInfo.usingController then
        local deltaX = InputManagerInst:GetAxis("View X") * Time.deltaTime
        local deltaY = InputManagerInst:GetAxis("View Y") * Time.deltaTime
        if deltaX ~= 0 or deltaY ~= 0 then
            if self:_MoveCamera(deltaX, deltaY) then
                return
            end
        end
    end
    
    if self:_UpdateJudge(Time.deltaTime) then
        return
    end
    self:_TickHintTimeout(Time.deltaTime)
end

MicroModelAlignCtrl._MoveCamera = HL.Method(HL.Number, HL.Number).Return(HL.Boolean) << function(self, deltaX, deltaY)
    if self.m_isFinishing or self.m_isCompleteToastFlow then
        return false
    end
    if self.m_cameraCtrl:Move(deltaX, deltaY) then
        return self:_UpdateJudge(0)
    end
    return false
end

MicroModelAlignCtrl._RotateCameraByDelta = HL.Method(HL.Any) << function(self, delta)
    local deltaX = delta.x
    local deltaY = delta.y
    if DeviceInfo.usingKeyboard then
        if deltaX == 0 then
            deltaX = InputManagerInst:GetAxis("Mouse X") * 0.9
        end
        if deltaY == 0 then
            deltaY = InputManagerInst:GetAxis("Mouse Y") * 0.63
        end
    end
    if deltaX == 0 and deltaY == 0 then
        return
    end
    self:_MoveCamera(UIUtils.getNormalizedScreenX(deltaX), UIUtils.getNormalizedScreenY(deltaY))
end

MicroModelAlignCtrl._ApplyScaleDelta = HL.Method(HL.Number) << function(self, delta)
    if self.m_isFinishing or self.m_isCompleteToastFlow then
        return
    end
    local scaleMultiplier
    if DeviceInfo.usingController then
        scaleMultiplier = Tables.globalConst.microModelAlignControllerScaleMultiplier
    elseif DeviceInfo.usingKeyboard then
        scaleMultiplier = Tables.globalConst.microModelAlignKeyboardMouseScaleMultiplier
    else
        scaleMultiplier = Tables.globalConst.microModelAlignMobileScaleMultiplier
    end
    self:_ApplyScaleValue(self.m_currentScale + delta * scaleMultiplier)
end


MicroModelAlignCtrl._StartScaleChangeCoroutine = HL.Method(HL.Number).Return(HL.Thread) << function(self, direction)
    return self:_StartCoroutine(function()
        self:_ApplyScaleDelta(direction * self.m_scaleStep)
        coroutine.wait(self.view.config.PRESS_CHANGE_SCALE_START_DELAY)
        local holdElapsed = 0
        while true do
            holdElapsed = holdElapsed + Time.deltaTime
            local accelerateDelay = self.view.config.PRESS_CHANGE_SCALE_ACCELERATE_DELAY
            local speedMultiplier = holdElapsed >= accelerateDelay and 2 or 1
            local delta = direction * self.m_scaleStep * self.view.config.PRESS_CHANGE_SCALE_SPEED
                * Time.deltaTime * speedMultiplier
            self:_ApplyScaleDelta(delta)
            coroutine.step()
        end
    end)
end

MicroModelAlignCtrl._ApplyScaleValue = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, scale, force)
    if (self.m_isFinishing or self.m_isCompleteToastFlow) and not force then
        return
    end
    local clampedScale = math.max(self.m_arg.minScale, math.min(self.m_arg.maxScale, scale))
    clampedScale = math.max(0.01, clampedScale)
    self.m_currentScale = clampedScale
    self.m_previewPivot.transform.localScale = Vector3(clampedScale, clampedScale, clampedScale)
    self:_RefreshScaleUI()
end

MicroModelAlignCtrl._RefreshScaleUI = HL.Method() << function(self)
    local displayScale = self:_GetDisplayScale(self.m_currentScale)
    self.view.downNode.scaleSlider:SetValueWithoutNotify(displayScale)
    self.view.downNode.sliderValueTxt.text = string.format("%.2fx", displayScale)
end

MicroModelAlignCtrl._GetDisplayScale = HL.Method(HL.Number).Return(HL.Number) << function(self, realScale)
    return realScale + self.m_scaleDisplayOffset
end

MicroModelAlignCtrl._GetRealScale = HL.Method(HL.Number).Return(HL.Number) << function(self, displayScale)
    return displayScale - self.m_scaleDisplayOffset
end


MicroModelAlignCtrl._UpdateJudge = HL.Method(HL.Number).Return(HL.Boolean) << function(self, deltaTime)
    local targetWorldPos = self.m_arg.targetWorldPosition
    local modelWorldPos = self.m_previewPivot.transform.position
    local posOk = Vector3.Distance(modelWorldPos, targetWorldPos) <= self.m_arg.distanceTolerance
    local scaleOk = math.abs(self.m_currentScale - self.m_arg.correctScale) <= self.m_arg.scaleTolerance
    local isInTolerance = posOk and scaleOk
    local elapsed = isInTolerance and (self.m_judgeState.elapsed + deltaTime) or 0

    self.m_judgeState = {
        posOk = posOk,
        scaleOk = scaleOk,
        isInTolerance = isInTolerance,
        elapsed = elapsed,
        isSuccess = elapsed >= self.m_arg.correctDuration,
    }

    return self:_TryCompleteAlignment()
end

MicroModelAlignCtrl._TryCompleteAlignment = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_judgeState.isSuccess then
        return false
    end
    if self.m_successTodoLogged then
        return true
    end
    self.m_successTodoLogged = true
    if not self.m_arg.delayCompleteEventByAlignDuration then
        self:_SetPreviewModelViewState(0)
        self:_RaiseCompleteLevelEvent()
    end
    self:_StartCompleteAlignAnim()
    return true
end


MicroModelAlignCtrl._StartCompleteAnimationOut = HL.Method() << function(self)
    if self.m_completeOutStarted then
        return
    end
    self.m_completeOutStarted = true
    self.m_completeOutFinished = false
    self:PlayAnimationOutWithCallback(function()
        self.m_completeOutFinished = true
        if self.m_completeFlowDone then
            self:_ClosePhase(true)
        end
    end)
end


MicroModelAlignCtrl._StartCompleteAlignAnim = HL.Method() << function(self)
    if self.m_isFinishing or self.m_completeFlowDone then
        return
    end

    self:_StartCompleteAnimationOut()
    self.m_finishDuration = self.m_arg.completeAlignDuration
    self.m_finishElapsed = 0
    self.m_finishStartScale = self.m_currentScale
    self.m_finishStartCenterPosition = self.m_previewPivot.transform.position
    self.m_finishTargetCenterPosition = self.m_arg.targetWorldPosition
    self.m_finishStartCameraRotation = self.m_cameraCtrl:GetCameraRotation()
    self.m_finishTargetCameraRotation = self.m_arg.correctCameraRotation

    if self.m_finishDuration <= 0 then
        self:_FinishCompleteAlignment()
        return
    end

    self.m_isFinishing = true
    self:_ApplyCompleteAlignProgress(0)
end

MicroModelAlignCtrl._TickCompleteAlignAnim = HL.Method(HL.Number) << function(self, deltaTime)
    if not self.m_isFinishing or self.m_completeFlowDone then
        return
    end

    if self.m_finishDuration <= 0 then
        self:_FinishCompleteAlignment()
        return
    end

    self.m_finishElapsed = math.min(self.m_finishElapsed + deltaTime, self.m_finishDuration)
    local progress = self.m_finishElapsed / self.m_finishDuration
    self:_ApplyCompleteAlignProgress(progress)
    if progress >= 1 then
        self:_FinishCompleteAlignment()
    end
end


MicroModelAlignCtrl._ApplyCompleteAlignProgress = HL.Method(HL.Number) << function(self, progress)
    local t = math.max(0, math.min(1, progress))
    local startRot = self.m_finishStartCameraRotation
    local targetRot = self.m_finishTargetCameraRotation
    local currentRot = Quaternion.Slerp(Quaternion.Euler(startRot), Quaternion.Euler(targetRot), t).eulerAngles
    if t >= 1 then
        currentRot = targetRot
    end
    self.m_cameraCtrl:SetCameraRotation(currentRot)

    local targetScale = math.max(self.m_arg.minScale, math.min(self.m_arg.maxScale, self.m_arg.correctScale))
    local currentScale = self.m_finishStartScale + (targetScale - self.m_finishStartScale) * t
    if t >= 1 then
        currentScale = targetScale
    end
    self:_ApplyScaleValue(currentScale, true)
    self:_ApplyCompleteAlignCenterPosition(t)
end

MicroModelAlignCtrl._ApplyCompleteAlignCenterPosition = HL.Method(HL.Number) << function(self, progress)
    local t = math.max(0, math.min(1, progress))
    local startCenter = self.m_finishStartCenterPosition
    local targetCenter = self.m_finishTargetCenterPosition
    local centerPosition = Vector3.Lerp(startCenter, targetCenter, t)
    if t >= 1 then
        centerPosition = targetCenter
    end
    self.m_previewPivot.transform.position = centerPosition
end

MicroModelAlignCtrl._FinishCompleteAlignment = HL.Method() << function(self)
    if self.m_completeFlowDone then
        return
    end
    self:_ApplyCompleteAlignProgress(1)
    self.m_isFinishing = false
    if self.m_arg.delayCompleteEventByAlignDuration then
        self:_SetPreviewModelViewState(0)
        self:_RaiseCompleteLevelEvent()
    end
    self:_StartCompleteToastFlow()
end


MicroModelAlignCtrl._StartCompleteToastFlow = HL.Method() << function(self)
    if self.m_isCompleteToastFlow or self.m_completeFlowDone then
        return
    end
    self.m_isCompleteToastFlow = true
    self.m_completeToastElapsed = 0
    self.m_completeToastClosed = false
    Notify(MessageConst.ON_SHOW_COMMON_TASK_TOAST_FINISH_DIRECT)
    self:_TickCompleteToastFlow(0)
end

MicroModelAlignCtrl._TickCompleteToastFlow = HL.Method(HL.Number) << function(self, deltaTime)
    if not self.m_isCompleteToastFlow or self.m_completeFlowDone then
        return
    end
    self.m_completeToastElapsed = self.m_completeToastElapsed + deltaTime
    if not self.m_completeToastClosed and self.m_completeToastElapsed >= self.m_arg.completeToastCloseDelay then
        self.m_completeToastClosed = true
        Notify(MessageConst.ON_CLOSE_COMMON_TASK_TOAST_DIRECT)
    end
    if self.m_completeToastElapsed >= self.m_arg.completeFlowCloseDelay then
        self:_FinishCompleteToastFlow()
    end
end

MicroModelAlignCtrl._FinishCompleteToastFlow = HL.Method() << function(self)
    if self.m_completeFlowDone then
        return
    end
    if not self.m_completeToastClosed then
        self.m_completeToastClosed = true
        Notify(MessageConst.ON_CLOSE_COMMON_TASK_TOAST_DIRECT)
    end
    self.m_isCompleteToastFlow = false
    self.m_completeFlowDone = true
    self:_ClosePhase(true)
end


MicroModelAlignCtrl._RaiseCompleteLevelEvent = HL.Method() << function(self)
    if self.m_arg.onRaiseCompleteLevelEventCallBack then
        self.m_arg.onRaiseCompleteLevelEventCallBack()
    end
end



MicroModelAlignCtrl._TickHintTimeout = HL.Method(HL.Number) << function(self, deltaTime)
    if self.m_timeoutFired or self.m_arg.hintTimeout <= 0 then
        return
    end
    self.m_openElapsed = self.m_openElapsed + deltaTime
    if self.m_openElapsed >= self.m_arg.hintTimeout then
        self.m_timeoutFired = true
        if self.m_arg.onTimeoutCallBack then
            self.m_arg.onTimeoutCallBack()
        end
    end
end



MicroModelAlignCtrl._SetAllSquadMembersVisible = HL.Method(HL.Boolean) << function(self, isVisible)
    local squadMembers = GameInstance.player.squadManager.squadMembers
    local count = squadMembers.Count
    for i = 0, count - 1 do
        CS.Beyond.Gameplay.View.ViewUtils.SetEntityActive(
            squadMembers[i], isVisible,
            CS.Beyond.Gameplay.View.ModelVisibleType.Snapshot)
    end
end


MicroModelAlignCtrl._BuildResumeState = HL.Method().Return(HL.Table) << function(self)
    local state = {
        currentScale = self.m_currentScale,
        openElapsed = self.m_openElapsed,
        timeoutFired = self.m_timeoutFired,
        completeFlowDone = self.m_completeFlowDone,
        completeOutStarted = self.m_completeOutStarted,
        camera = {
            rotation = self.m_cameraCtrl:GetCameraRotation(),
            cameraPosition = self.m_arg.cameraPosition,
            fieldOfView = self.m_arg.cameraFov,
        },
    }
    if self.m_isFinishing and not self.m_completeFlowDone then
        state.finishing = {
            isFinishing = true,
            elapsed = self.m_finishElapsed,
            duration = self.m_finishDuration,
            startScale = self.m_finishStartScale,
            startCameraRotation = self.m_finishStartCameraRotation,
            targetCameraRotation = self.m_finishTargetCameraRotation,
            startCenterPosition = self.m_finishStartCenterPosition,
            targetCenterPosition = self.m_finishTargetCenterPosition,
        }
    end
    if self.m_isCompleteToastFlow and not self.m_completeFlowDone then
        state.completeToast = {
            isCompleteToastFlow = true,
            elapsed = self.m_completeToastElapsed,
            toastClosed = self.m_completeToastClosed,
        }
    end
    return state
end

MicroModelAlignCtrl._ClosePhase = HL.Method(HL.Opt(HL.Boolean)) << function(self, force)
    if (self.m_isFinishing or self.m_isCompleteToastFlow) and not force then
        return
    end
    
    if PhaseManager:IsInPhaseTransition() then
        return
    end
    
    if self.m_completeOutStarted then
        if not self.m_completeOutFinished then
            return
        end
        PhaseManager:ExitPhaseFast(PHASE_ID)
        return
    end
    self:PlayAnimationOutWithCallback(function()
        PhaseManager:ExitPhaseFast(PHASE_ID)
    end)
end






MicroModelAlignCtrl.ShowMicroModelAlign = HL.StaticMethod(HL.Opt(HL.Any)) << function(args)
    local param = unpack(args)
    PhaseManager:OpenPhase(PHASE_ID, param)
end

HL.Commit(MicroModelAlignCtrl)
