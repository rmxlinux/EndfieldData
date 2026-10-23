local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local detectorModule = require_ex('UI/Panels/FacBuildingInteract/Runtime/FacInteractTargetDetector')


local s_handlerDefs = {
    [FacConst.FAC_INTERACT_MODE.Normal] = {
        'UI/Panels/FacBuildingInteract/Runtime/FacInteractNormalHandler',
        'FacInteractNormalHandler',
    },
    [FacConst.FAC_INTERACT_MODE.DestroySingle] = {
        'UI/Panels/FacBuildingInteract/Runtime/FacInteractDestroyHandler',
        'FacInteractDestroyHandler',
    },
    [FacConst.FAC_INTERACT_MODE.BatchSelect] = {
        'UI/Panels/FacBuildingInteract/Runtime/FacInteractBatchHandler',
        'FacInteractBatchHandler',
    },
}

local s_handlerClassCache = {}

local function getHandlerClass(mode)
    local cls = s_handlerClassCache[mode]
    if not cls then
        local def = s_handlerDefs[mode]
        if not def then
            return nil
        end
        cls = require_ex(def[1])[def[2]]
        s_handlerClassCache[mode] = cls
    end
    return cls
end

FacInteractSystem = HL.Class('FacInteractSystem', LuaSystemBase.LuaSystemBase)

FacInteractSystem.m_detector = HL.Field(HL.Forward('FacInteractTargetDetector'))
FacInteractSystem.m_currentHandler = HL.Field(HL.Forward('FacInteractHandlerBase'))
FacInteractSystem.m_presenter = HL.Field(HL.Forward('FacBuildingInteractCtrl'))
FacInteractSystem.m_interactTargetInputs = HL.Field(HL.Table)
FacInteractSystem.m_currentInteractTargetInput = HL.Field(HL.Table)
FacInteractSystem.m_currentInteractTargetOutput = HL.Field(HL.Table)
FacInteractSystem.m_currentPresentationModel = HL.Field(HL.Table)

FacInteractSystem.m_mode = HL.Field(HL.Number) << FacConst.FAC_INTERACT_MODE.Disabled
FacInteractSystem.m_viewMode = HL.Field(HL.Number) << FacConst.FAC_INTERACT_TARGET_VIEW_MODE.RPG
FacInteractSystem.m_runtimeActive = HL.Field(HL.Boolean) << false
FacInteractSystem.m_tailTickId = HL.Field(HL.Number) << -1
FacInteractSystem.m_buildingInteractRange = HL.Field(HL.Number) << 0
FacInteractSystem.m_buildingInteractAngle = HL.Field(HL.Number) << 0
FacInteractSystem.m_subBuildingSetTopDist = HL.Field(HL.Number) << 0
FacInteractSystem.m_pipeOptionDelay = HL.Field(HL.Number) << 0
FacInteractSystem.m_onlyValidHubUnloaderIndex = HL.Field(HL.Number) << -1
FacInteractSystem.m_batchControllerBindingGroupId = HL.Field(HL.Number) << -1
FacInteractSystem.m_batchControllerDragCor = HL.Field(HL.Thread)
FacInteractSystem.m_batchControllerDragCorIsReverseDrag = HL.Field(HL.Boolean) << false

FacInteractSystem.m_onClickScreen = HL.Field(HL.Function)
FacInteractSystem.m_onLongPressScreen = HL.Field(HL.Function)
FacInteractSystem.m_onDragScreen = HL.Field(HL.Function)
FacInteractSystem.m_onDragScreenBegin = HL.Field(HL.Function)
FacInteractSystem.m_onDragScreenEnd = HL.Field(HL.Function)
FacInteractSystem.m_onPressScreen = HL.Field(HL.Function)
FacInteractSystem.m_onReleaseScreen = HL.Field(HL.Function)

FacInteractSystem.FacInteractSystem = HL.Constructor() << function(self)
    self.m_detector = detectorModule.FacInteractTargetDetector()
    self.m_interactTargetInputs = {
        [FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview] = {},
        [FacConst.FAC_INTERACT_TARGET_PURPOSE.Click] = {},
        [FacConst.FAC_INTERACT_TARGET_PURPOSE.Rect] = {},
    }

    self.m_onClickScreen = function(eventData)
        if self.m_currentHandler then
            self.m_currentHandler:OnClick(eventData)
        end
    end
    self.m_onLongPressScreen = function(eventData)
        if self.m_currentHandler then
            self.m_currentHandler:OnLongPress(eventData)
        end
    end
    self.m_onDragScreen = function(eventData)
        if self.m_currentHandler then
            self.m_currentHandler:OnDrag(eventData)
        end
    end
    self.m_onDragScreenBegin = function(pos)
        if self.m_currentHandler then
            self.m_currentHandler:OnDragBegin(pos)
        end
    end
    self.m_onDragScreenEnd = function(pos)
        if self.m_currentHandler then
            self.m_currentHandler:OnDragEnd(pos)
        end
    end
    self.m_onPressScreen = function(eventData)
        if self.m_currentHandler then
            self.m_currentHandler:OnPress(eventData)
        end
    end
    self.m_onReleaseScreen = function(eventData)
        if self.m_currentHandler then
            self.m_currentHandler:OnRelease(eventData)
        end
    end

    self:RegisterMessage(MessageConst.ON_BUILD_MODE_CHANGE, function(arg)
        self:_ResolveAndApplyMode()
    end)
    self:RegisterMessage(MessageConst.ON_FAC_DESTROY_MODE_CHANGE, function(arg)
        self:_ResolveAndApplyMode()
    end)
    self:RegisterMessage(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, function(arg)
        self:_ResolveAndApplyMode()
    end)
    self:RegisterMessage(MessageConst.FAC_ON_TOGGLE_BATCH_MODE, function(arg)
        self:_ResolveAndApplyMode()
    end)
    
    self:RegisterMessage(MessageConst.FAC_ON_NODE_REMOVED, function(arg)
        self:_ClearCurrentInteractTargetOutputAndPresentation()
    end)
    self:RegisterMessage(MessageConst.FAC_ON_PENDING_SLOTS_REMOVED, function(arg)
        self:_ClearCurrentInteractTargetOutputAndPresentation()
    end)
    self:RegisterMessage(MessageConst.ON_SCENE_LOAD_START, function(arg)
        self.m_onlyValidHubUnloaderIndex = -1
        self:_ClearCurrentInteractTargetOutputAndPresentation()
    end)
end

FacInteractSystem.OnInit = HL.Override() << function(self)
    self:_ResolveAndApplyMode()
end

FacInteractSystem.OnRelease = HL.Override() << function(self)
    self:_SuspendRuntime()
    self:_ClearBatchControllerInput()
    if self.m_currentHandler then
        self.m_currentHandler:OnExit()
        self.m_currentHandler = nil
    end
    self.m_currentInteractTargetInput = nil
    self.m_currentInteractTargetOutput = nil
    self.m_currentPresentationModel = nil
    self.m_presenter = nil
    self.m_mode = FacConst.FAC_INTERACT_MODE.Disabled
    self.m_viewMode = FacConst.FAC_INTERACT_TARGET_VIEW_MODE.RPG
    self.m_onlyValidHubUnloaderIndex = -1
end




FacInteractSystem.AttachPresenter = HL.Method(HL.Any) << function(self, presenter)
    if self.m_presenter == presenter then
        return
    end
    if self.m_presenter then
        logger.error("[FacInteract] duplicated presenter")
        return
    end

    self.m_presenter = presenter
    self.m_buildingInteractRange = presenter.view.config.BUILDING_INTERACT_RANGE
    self.m_buildingInteractAngle = presenter.view.config.BUILDING_INTERACT_ANGLE
    self.m_subBuildingSetTopDist = presenter.view.config.SUB_BUILDING_SET_TOP_DIST
    self.m_pipeOptionDelay = presenter.view.config.PIPE_OPTION_DELAY
    self:_InitBatchControllerInput(presenter.view.inputGroup.groupId)
    self:_ResolveAndApplyMode()
    self:_ResumeRuntime()
end

FacInteractSystem.DetachPresenter = HL.Method(HL.Any) << function(self, presenter)
    if self.m_presenter ~= presenter then
        return
    end

    
    self:_SuspendRuntime()
    self:_ClearCurrentInteractTargetOutputAndPresentation()
    self:_ClearBatchControllerInput()
    self.m_presenter = nil
end

FacInteractSystem.GetPresenter = HL.Method().Return(HL.Opt(HL.Forward('FacBuildingInteractCtrl'))) << function(self)
    return self.m_presenter
end

FacInteractSystem.GetCurrentTargetInput = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    return self.m_currentInteractTargetInput
end

FacInteractSystem.GetCurrentTargetOutput = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    return self.m_currentInteractTargetOutput
end

FacInteractSystem.GetCurrentPresentationModel = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    return self.m_currentPresentationModel
end

FacInteractSystem.SetOnlyValidHubUnloaderIndex = HL.Method(HL.Number) << function(self, index)
    self.m_onlyValidHubUnloaderIndex = index
end

FacInteractSystem.GetOnlyValidHubUnloaderIndex = HL.Method().Return(HL.Number) << function(self)
    return self.m_onlyValidHubUnloaderIndex
end

FacInteractSystem.RefreshCurrentTarget = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Table, HL.Table)
        << function(self, forceUpdate)
    self:_ResolveAndApplyMode()
    local purpose = LuaSystemManager.factory.inTopView
            and FacConst.FAC_INTERACT_TARGET_PURPOSE.Click
            or FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview
    local input, output = self:QueryPoint(purpose)
    input.forceUpdate = forceUpdate == true
    if not self.m_currentHandler then
        return input, output
    end
    local model = self.m_currentHandler:BuildPresentationModel(input, output)
    self:PublishInteractPresentation(model)
    return input, output
end

FacInteractSystem.ExecuteInteract = HL.Method(HL.Table) << function(self, option)
    if self.m_currentHandler then
        self.m_currentHandler:ExecuteInteract(option)
    end
end

FacInteractSystem.ExecuteCurrentTarget = HL.Method(HL.Opt(HL.Boolean)) << function(self, isAll)
    local output = self.m_currentInteractTargetOutput
    local target = output and output.primaryTarget
    if not target then
        return
    end
    if target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        self:ExecuteInteract({
            buildingNodeId = target.nodeId,
            subBuildingIndex = target.subBuildingIndex,
        })
    else
        self:ExecuteInteract({
            nodeId = target.nodeId,
            unitIndex = target.unitIndex,
            logisticPos = target.logisticPos,
            isAll = isAll,
        })
    end
    self:ClearInteractPresentation()
end

FacInteractSystem.ClearInteractPresentation = HL.Method() << function(self)
    if self.m_currentHandler then
        self.m_currentHandler:ClearPresentationState()
    end
    self.m_currentPresentationModel = nil
    if self.m_presenter then
        self.m_presenter:ClearInteractPresentation()
    end
end

FacInteractSystem.ClearAllBatchTargets = HL.Method() << function(self)
    local curChapterId = Utils.getCurrentChapterId()
    for nodeId, _ in pairs(LuaSystemManager.factory.batchSelectTargets) do
        GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
            curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, false
        )
        if FactoryUtils.isPendingBuildingNode(nodeId) then
            GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.TO_BE_BUILD, true
            )
        end
    end
    LuaSystemManager.factory.batchSelectTargets = {}
    GameInstance.remoteFactoryManager.batchSelect:ClearTargets()
end

FacInteractSystem.SelectBatchTarget = HL.Method(HL.Number, HL.Boolean, HL.Opt(HL.Number))
        << function(self, nodeId, isAdd, unitIndex)
    if self.m_currentHandler then
        self.m_currentHandler:SelectBatchTarget(nodeId, isAdd, unitIndex)
    end
end

FacInteractSystem.BeginBatchDrag = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, pos, fromController)
    if self.m_currentHandler then
        self.m_currentHandler:OnDragBegin(pos, fromController)
    end
end

FacInteractSystem.UpdateBatchDrag = HL.Method(HL.Opt(HL.Any, HL.Boolean)) << function(self, eventData, fromController)
    if self.m_currentHandler then
        self.m_currentHandler:OnDrag(eventData, fromController)
    end
end

FacInteractSystem.EndBatchDrag = HL.Method(HL.Opt(HL.Any)) << function(self, pos)
    if self.m_currentHandler then
        self.m_currentHandler:OnDragEnd(pos)
    end
end

FacInteractSystem.IsDraggingInBatchMode = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_currentHandler and self.m_currentHandler:IsDraggingInBatchMode() or false
end

FacInteractSystem.MarkBatchDragDirty = HL.Method() << function(self)
    if self.m_currentHandler then
        self.m_currentHandler:MarkBatchDragDirty()
    end
end

FacInteractSystem.PublishInteractPresentation = HL.Method(HL.Opt(HL.Any)) << function(self, model)
    self.m_currentPresentationModel = model
    if self.m_presenter then
        self.m_presenter:ApplyInteractPresentation(model)
    end
end

FacInteractSystem.PublishDragFrame = HL.Method(HL.Opt(HL.Any)) << function(self, model)
    if self.m_presenter then
        self.m_presenter:ApplyDragFrameModel(model)
    end
end

FacInteractSystem.PublishPressHint = HL.Method(HL.Table) << function(self, model)
    if self.m_presenter then
        self.m_presenter:ApplyPressHintModel(model)
    end
end

FacInteractSystem.PublishBatchToggle = HL.Method(HL.Boolean) << function(self, active)
    if self.m_presenter then
        self.m_presenter:ApplyBatchToggleModel(active)
    end
end

FacInteractSystem.PublishMultiTarget = HL.Method(HL.Table) << function(self, model)
    if self.m_presenter then
        self.m_presenter:ApplyMultiTargetModel(model)
    end
end






FacInteractSystem._ResolveAndApplyMode = HL.Method() << function(self)
    local factory = LuaSystemManager.factory
    if not factory then
        return
    end

    local viewMode = factory.inTopView
            and FacConst.FAC_INTERACT_TARGET_VIEW_MODE.TopView
            or FacConst.FAC_INTERACT_TARGET_VIEW_MODE.RPG
    local mode
    if FactoryUtils.isInBuildMode() then
        mode = FacConst.FAC_INTERACT_MODE.Disabled
    elseif factory.inDestroyMode then
        mode = factory.inTopView and factory.inBatchSelectMode
                and FacConst.FAC_INTERACT_MODE.BatchSelect
                or FacConst.FAC_INTERACT_MODE.DestroySingle
    else
        mode = FacConst.FAC_INTERACT_MODE.Normal
    end

    self:_SwitchTo(mode, viewMode)
    self:ToggleBatchControllerInput(mode == FacConst.FAC_INTERACT_MODE.BatchSelect and DeviceInfo.usingController)
end

FacInteractSystem._SwitchTo = HL.Method(HL.Number, HL.Number) << function(self, mode, viewMode)
    if self.m_mode == mode and self.m_viewMode == viewMode then
        self:_ResumeRuntime()
        return
    end

    self:_SuspendRuntime()
    if self.m_currentHandler then
        self.m_currentHandler:OnExit()
        self.m_currentHandler = nil
    end

    self:_ClearCurrentInteractTargetOutputAndPresentation()
    self.m_mode = mode
    self.m_viewMode = viewMode

    if mode ~= FacConst.FAC_INTERACT_MODE.Disabled then
        local handlerClass = getHandlerClass(mode)
        if not handlerClass then
            logger.error("[FacInteract] handler class not found, mode:", mode)
            return
        end
        self.m_currentHandler = handlerClass(self)
        self.m_currentHandler:OnEnter({ viewMode = viewMode })
    end

    self:_ResumeRuntime()
end

FacInteractSystem._ResumeRuntime = HL.Method() << function(self)
    if self.m_runtimeActive
            or not self.m_presenter
            or self.m_mode == FacConst.FAC_INTERACT_MODE.Disabled
            or not self.m_currentHandler then
        return
    end

    self:_EnsureInputAndTick()
    self.m_runtimeActive = true
    self.m_currentHandler:OnResume()
end

FacInteractSystem._SuspendRuntime = HL.Method() << function(self)
    if not self.m_runtimeActive then
        return
    end

    self:_ClearInputAndTick()
    self.m_runtimeActive = false
    if self.m_currentHandler then
        self.m_currentHandler:OnSuspend()
    end
    self.m_currentInteractTargetInput = nil
    self.m_currentInteractTargetOutput = nil
end






FacInteractSystem._InitBatchControllerInput = HL.Method(HL.Number) << function(self, parentGroupId)
    if self.m_batchControllerBindingGroupId > 0 then
        return
    end
    self.m_batchControllerBindingGroupId = InputManagerInst:CreateGroup(parentGroupId)
    UIUtils.bindInputPlayerAction("fac_top_view_batch_drag_ct_start", function()
        self:_StartBatchControllerDragCor(false)
    end, self.m_batchControllerBindingGroupId)
    UIUtils.bindInputPlayerAction("fac_top_view_batch_drag_ct_end", function()
        if self.m_batchControllerDragCorIsReverseDrag == false then
            self:_StopBatchControllerDragCor()
        end
    end, self.m_batchControllerBindingGroupId)
    UIUtils.bindInputPlayerAction("fac_top_view_batch_drag_reverse_ct_start", function()
        self:_StartBatchControllerDragCor(true)
    end, self.m_batchControllerBindingGroupId)
    UIUtils.bindInputPlayerAction("fac_top_view_batch_drag_reverse_ct_end", function()
        if self.m_batchControllerDragCorIsReverseDrag == true then
            self:_StopBatchControllerDragCor()
        end
    end, self.m_batchControllerBindingGroupId)
    InputManagerInst:ToggleGroup(self.m_batchControllerBindingGroupId, false)
end

FacInteractSystem._ClearBatchControllerInput = HL.Method() << function(self)
    self:_StopBatchControllerDragCor()
    if self.m_batchControllerBindingGroupId > 0 then
        InputManagerInst:DeleteGroup(self.m_batchControllerBindingGroupId)
        self.m_batchControllerBindingGroupId = -1
    end
end

FacInteractSystem.ToggleBatchControllerInput = HL.Method(HL.Boolean) << function(self, active)
    if self.m_batchControllerBindingGroupId > 0 then
        InputManagerInst:ToggleGroup(self.m_batchControllerBindingGroupId, active)
    end
end

FacInteractSystem._StartBatchControllerDragCor = HL.Method(HL.Boolean) << function(self, isReverse)
    if self.m_batchControllerDragCor then
        return
    end
    self.m_batchControllerDragCorIsReverseDrag = isReverse
    LuaSystemManager.factory:ChangeIsReverseSelect(isReverse)
    local startPos = InputManager.mousePosition
    self.m_batchControllerDragCor = self:_StartCoroutine(function()
        local curPos
        while true do
            coroutine.step()
            curPos = InputManager.mousePosition
            if (startPos - curPos).sqrMagnitude >= UIConst.COMMON_UI_DRAG_MIN_SQR_DIST then
                break
            end
        end
        self:BeginBatchDrag(startPos:XY(), true)
        self:UpdateBatchDrag(nil, true)
        local lastPos = curPos
        while true do
            coroutine.step()
            curPos = InputManager.mousePosition
            if (curPos - lastPos).sqrMagnitude >= UIConst.COMMON_UI_DRAG_MIN_SQR_DIST then
                lastPos = curPos
                self:UpdateBatchDrag(nil, true)
            end
        end
    end)
end

FacInteractSystem._StopBatchControllerDragCor = HL.Method() << function(self)
    if not self.m_batchControllerDragCor then
        return
    end
    self.m_batchControllerDragCor = self:_ClearCoroutine(self.m_batchControllerDragCor)
    self:EndBatchDrag()
    LuaSystemManager.factory:ChangeIsReverseSelect(false)
end

FacInteractSystem.StopBatchControllerDrag = HL.Method() << function(self)
    self:_StopBatchControllerDragCor()
    self:EndBatchDrag()
end






FacInteractSystem._EnsureInputAndTick = HL.Method() << function(self)
    local touchPanel = UIManager.commonTouchPanel
    touchPanel.onClick:AddListener(self.m_onClickScreen)
    touchPanel.onLongPress:AddListener(self.m_onLongPressScreen)
    touchPanel.onDrag:AddListener(self.m_onDragScreen)
    touchPanel.onDragBegin:AddListener(self.m_onDragScreenBegin)
    touchPanel.onDragEnd:AddListener(self.m_onDragScreenEnd)
    touchPanel.onPress:AddListener(self.m_onPressScreen)
    touchPanel.onRelease:AddListener(self.m_onReleaseScreen)

    self.m_tailTickId = LuaUpdate:Remove(self.m_tailTickId)
    self.m_tailTickId = LuaUpdate:Add("TailTick", function()
        if CS.UnityEngine.Application.isFocused and self.m_currentHandler then
            self.m_currentHandler:OnTick()
        end
    end, true)
end

FacInteractSystem._ClearInputAndTick = HL.Method() << function(self)
    local touchPanel = UIManager.commonTouchPanel
    touchPanel.onClick:RemoveListener(self.m_onClickScreen)
    touchPanel.onLongPress:RemoveListener(self.m_onLongPressScreen)
    touchPanel.onDrag:RemoveListener(self.m_onDragScreen)
    touchPanel.onDragBegin:RemoveListener(self.m_onDragScreenBegin)
    touchPanel.onDragEnd:RemoveListener(self.m_onDragScreenEnd)
    touchPanel.onPress:RemoveListener(self.m_onPressScreen)
    touchPanel.onRelease:RemoveListener(self.m_onReleaseScreen)
    self.m_tailTickId = LuaUpdate:Remove(self.m_tailTickId)
end






FacInteractSystem._BuildInteractTargetInput = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Table)
        << function(self, purpose, arg)
    local input = self.m_interactTargetInputs[purpose]
    input.purpose = purpose
    input.viewMode = self.m_viewMode
    input.worldPos = nil
    input.ray = nil
    input.playerPos = nil
    input.playerForward = nil
    input.playerRight = nil
    input.rect = nil
    input.forceUpdate = purpose ~= FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview
    input.buildingInteractRange = self.m_buildingInteractRange
    input.buildingInteractAngle = self.m_buildingInteractAngle
    input.subBuildingSetTopDist = self.m_subBuildingSetTopDist
    input.pipeOptionDelay = self.m_pipeOptionDelay

    if self.m_viewMode == FacConst.FAC_INTERACT_TARGET_VIEW_MODE.RPG then
        local playerTrans = GameUtil.playerTrans
        input.playerPos = playerTrans.position
        input.playerForward = playerTrans.forward
        input.playerRight = playerTrans.right
    else
        local pointerPos = InputManager.mousePosition
        input.ray = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        local rfm = GameInstance.remoteFactoryManager
        if rfm.isRemoteTopViewActive then
            
            
            local planeY = LuaSystemManager.factory.topViewCamTarget.position.y
            local origin, dir = input.ray.origin, input.ray.direction
            if math.abs(dir.y) > 1e-5 then
                local t = (planeY - origin.y) / dir.y
                if t > 0 then
                    input.worldPos = origin + dir * t
                end
            end
        end
        if not input.worldPos then
            local _, worldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(input.ray)
            input.worldPos = worldPos
        end
        if DeviceInfo.usingController then
            
            
            
            
            local objPos = LuaSystemManager.factory.topViewControllerMouseMoveTarget.position
            if (objPos - input.worldPos):XZ().sqrMagnitude <= 0.1 then
                input.worldPos = objPos
            end
        end
        input.playerPos = input.worldPos
        input.playerForward = Vector3.forward
        input.playerRight = Vector3.right
    end
    return input
end

FacInteractSystem.QueryPoint = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Table, HL.Table)
        << function(self, purpose, arg)
    local input = self:_BuildInteractTargetInput(purpose, arg)
    local output = self.m_detector:DetectPoint(input)
    self.m_currentInteractTargetInput = input
    self.m_currentInteractTargetOutput = output
    return input, output
end

FacInteractSystem.QueryRect = HL.Method(HL.Any).Return(HL.Table, HL.Table) << function(self, rect)
    local input = self:_BuildInteractTargetInput(FacConst.FAC_INTERACT_TARGET_PURPOSE.Rect)
    input.rect = rect
    local output = self.m_detector:DetectRect(input)
    self.m_currentInteractTargetInput = input
    self.m_currentInteractTargetOutput = output
    return input, output
end

FacInteractSystem._ClearCurrentInteractTargetOutputAndPresentation = HL.Method() << function(self)
    self.m_currentInteractTargetInput = nil
    self.m_currentInteractTargetOutput = nil
    self.m_currentPresentationModel = nil
    if self.m_currentHandler then
        self.m_currentHandler:ClearPresentationState()
    end
    if self.m_presenter then
        self.m_presenter:ClearInteractPresentation()
    end
    self:PublishDragFrame({ op = FacConst.FAC_INTERACT_DRAG_FRAME_OP.Cancel })
end




HL.Commit(FacInteractSystem)
return FacInteractSystem
