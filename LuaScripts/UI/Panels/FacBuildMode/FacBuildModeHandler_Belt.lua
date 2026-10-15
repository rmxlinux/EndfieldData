








local handlerBase = require_ex('UI/Panels/FacBuildMode/FacBuildModeHandler')
local FacBuildCheckResultHint = require_ex('UI/Panels/FacBuildMode/FacBuildCheckResultHint')

local KeyHints = {
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
}


FacBuildModeHandler_Belt = HL.Class('FacBuildModeHandler_Belt', handlerBase.FacBuildModeHandler)


FacBuildModeHandler_Belt.m_curCustomGridCenter = HL.Field(HL.Userdata)

FacBuildModeHandler_Belt.FacBuildModeHandler_Belt = HL.Constructor(HL.Forward('FacBuildModeCtrl')) << function(self, host)
    FacBuildModeHandler_Belt.SuperConstructor(self, host)
    self.m_provider = GameInstance.remoteFactoryManager.conveyorPlacementProvider
end

FacBuildModeHandler_Belt._IsPipe = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_host.m_beltId == FacConst.PIPE_ID
end

FacBuildModeHandler_Belt._GetConveyorMode = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    return GameInstance.remoteFactoryManager.interact.currentConveyorMode
end

FacBuildModeHandler_Belt._GetMark = HL.Method().Return(HL.Table) << function(self)
    return self:_IsPipe() and self.m_host.m_pipePreviewMark or self.m_host.m_beltStartPreviewMark
end




FacBuildModeHandler_Belt.OnEnter = HL.Override(HL.Table) << function(self, args)
    FacBuildModeHandler_Belt.Super.OnEnter(self, args)
    local host = self.m_host
    local provider = self.m_provider

    host.m_beltId = args.beltId
    host.m_beltHasStartLastTick = false

    local isPipe = self:_IsPipe()
    local mark = self:_GetMark()

    if host:_InDragMode() then
        provider:BeginConveyor(host.m_beltId, true) 
        mark.gameObject:SetActive(false)
    else
        provider:BeginConveyor(host.m_beltId, false) 
        mark.gameObject:SetActive(true)
        self:_UpdateBPStartPreviewMark(host:_GetCurPointerPressPos(), true)
    end
    host:_RefreshKeyHint(isPipe and KeyHints.pipeStart or KeyHints.beltStart)

    
    if LuaSystemManager.factory.inTopView then
        host.m_simpleFigureBackupValid = true
        host.m_simpleFigureModeBeforeBeltBuild = LuaSystemManager.factory.simpleFigureMode
        local autoMode = isPipe and FacConst.SIMPLE_FIGURE_MODE.SimpleBeltFigure or FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure
        LuaSystemManager.factory.simpleFigureMode = autoMode
    else
        host.m_simpleFigureBackupValid = false
    end

    if isPipe then
        local data = Tables.factoryLiquidPipeTable[host.m_beltId].pipeData
        host:_SetCamState(data.buildCamState)
    else
        local data = Tables.factoryGridBeltTable[host.m_beltId].beltData
        host:_SetCamState(data.buildCamState)
    end

    
    host:RefreshValidResult()
end

FacBuildModeHandler_Belt.OnExit = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local mark = self:_GetMark()
    mark.transform:DOKill()
    mark.gameObject:SetActive(false)

    
    host.m_mobileDragBeltChecker = host:_ClearCoroutine(host.m_mobileDragBeltChecker)

    if not InputManagerInst.inChangingInputDevice then
        if LuaSystemManager.factory.inTopView and host.m_simpleFigureBackupValid then
            host.m_simpleFigureBackupValid = false
            LuaSystemManager.factory:SetSimpleFigureMode(host.m_simpleFigureModeBeforeBeltBuild)
        else
            LuaSystemManager.factory:ApplySimpleFigureToRenderer()
        end
    end

    if DeviceInfo.usingTouch then
        LuaSystemManager.factory.canMoveCamTarget = true
    end

    FacBuildModeHandler_Belt.Super.OnExit(self, ctx)
end

FacBuildModeHandler_Belt.GetEnterMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_ENTER_BELT_MODE
end

FacBuildModeHandler_Belt.GetExitMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_EXIT_BELT_MODE
end

FacBuildModeHandler_Belt.OnEnterRefreshNodes = HL.Override() << function(self)
    local host = self.m_host
    if host:_InDragMode() then
        self:_UpdateOnBeltHasStartChanged()
    end
    
    
    if DeviceInfo.usingTouch and LuaSystemManager.factory.inTopView then
        host.view.actionButtonsAsIcon.gameObject:SetActive(false)
    end
end






FacBuildModeHandler_Belt.OnTick = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local provider = self.m_provider
    local conveyorMode = self:_GetConveyorMode()
    local usingDrag = ctx.usingDrag
    local curMouseWorldPos = ctx.rawPointerWorldPos

    if usingDrag then
        if ctx.isDragging and ctx.sampleOk then
            provider:UpdateTrace(ctx.pointerWorldPos)
            ctx.posChanged = true
        end
    else
        if ctx.sampleOk then
            provider:UpdatePreview(ctx.pointerWorldPos)
            ctx.posChanged = true
        end
    end

    local hasStart = conveyorMode.hasStart
    if hasStart ~= host.m_beltHasStartLastTick then
        self:_UpdateOnBeltHasStartChanged()
        if usingDrag then
            self:_GetMark().gameObject.gameObject:SetActive(hasStart)
        end
    end

    ctx.customGridCenter = nil
    self.m_curCustomGridCenter = ctx.rawPointerWorldPos
    if hasStart and usingDrag then
        
        local endViewPos = self.m_provider:GetTraceDragEndCenterWorld(Vector3.zero, true)
        endViewPos.y = curMouseWorldPos.y
        self.m_curCustomGridCenter = endViewPos
        if not host.m_isDragging then
            local endLogicPos = self.m_provider:GetTraceDragEndCenterWorld(Vector3.zero, false)
            endLogicPos.y = GameInstance.remoteFactoryManager:ViewToLogical(curMouseWorldPos).y
            ctx.customGridCenter = endLogicPos
        end
        self:_UpdateBPStartPreviewMarkWithWorldPos(endViewPos) 
    end
    if not usingDrag then
        self:_UpdateBPStartPreviewMarkWithWorldPos(curMouseWorldPos) 
    end

    if usingDrag and LuaSystemManager.factory.inTopView then
        GameInstance.remoteFactoryManager.interact:SetTopViewCameraFactor(1 - LuaSystemManager.factory.m_topViewCamCtrl.curZoomPercent)
    end

    self:_ApplyCustomGridCenter(ctx)
end


FacBuildModeHandler_Belt._ApplyCustomGridCenter = HL.Method(HL.Table) << function(self, ctx)
    local curMode = self:_GetConveyorMode()
    if not curMode then
        return
    end
    curMode.useCustomGridCenter = LuaSystemManager.factory.inTopView
    if not curMode.useCustomGridCenter then
        return
    end
    
    if ctx.customGridCenter then
        curMode.customGridCenter = ctx.customGridCenter
    elseif ctx.posChanged then
        curMode.customGridCenter = GameInstance.remoteFactoryManager:ViewToLogical(ctx.rawPointerWorldPos)
    end
end

FacBuildModeHandler_Belt.OnTickLocked = HL.Override() << function(self)
    self:_UpdateBPStartPreviewMarkColor()
end

FacBuildModeHandler_Belt.GetDragFollowInfo = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    
    local r = self.m_dragFollowInfo
    r.worldPos = self.m_curCustomGridCenter or self.m_host.m_lastMouseWorldPos
    r.worldSize = Vector3.zero
    return r
end

FacBuildModeHandler_Belt.EvaluatePlacement = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local host = self.m_host
    local r = self:_ResetPlacementResult()
    local conveyorMode = self:_GetConveyorMode()
    if not conveyorMode then
        return r
    end
    local isPipe = self:_IsPipe()
    local inDragMode = host:_InDragMode()
    local rst = conveyorMode.checkResult
    local valid = conveyorMode.hasStart or conveyorMode.hasPrecalculatedPort
    local errorHint, warningHint, normalHint
    if not valid then
        if not inDragMode then
            errorHint = conveyorMode.usePipePreview and Language.LUA_FAC_BUILD_MODE_PIPE_CANNOT_FROM_EMPTY or Language.LUA_FAC_BUILD_MODE_CONVEYOR_CANNOT_FROM_EMPTY
        end
    end
    if valid then
        valid, errorHint = FacBuildCheckResultHint.getConveyorHint(rst, isPipe, self:_HintCtx())
    end
    if valid then
        valid, errorHint = FacBuildCheckResultHint.getBuildingHint(conveyorMode.additionalBuildingCheckResult, self:_HintCtx())
    end
    if valid then
        local hasEnd, endPos
        if conveyorMode.hasStart then
            
            hasEnd, endPos = self.m_provider:TryGetTraceDragEndOpCenterWorld()
        end
        local mark = self:_GetMark()
        if hasEnd then
            local endPos2 = mark.transform.position
            if (endPos - endPos2):XZ().sqrMagnitude <= 0.1 then
                
                CS.Beyond.Gameplay.Conditions.OnFacPrepareBuildingEnterArea.Trigger(host.m_beltId, endPos, 0)
            end
        else
            endPos = mark.transform.position
            CS.Beyond.Gameplay.Conditions.OnFacPrepareBuildingEnterArea.Trigger(host.m_beltId, endPos, 0)
        end
    end
    if valid and errorHint == nil then
        if conveyorMode:HasMismatchedEndPort() then
            warningHint = conveyorMode.usePipePreview and Language.LUA_FAC_BUILD_MODE_PIPE_END_PORT_REVERSE or Language.LUA_FAC_BUILD_MODE_CONVEYOR_END_PORT_REVERSE
        elseif conveyorMode.hasStart then
            
            if not conveyorMode.endNodeHandler and not conveyorMode:HasEndJointNode() then
                normalHint = isPipe and Language.LUA_FAC_BUILD_MODE_PIPE_END_IS_EMPTY or Language.LUA_FAC_BUILD_MODE_BELT_END_IS_EMPTY
            end
        end
    end
    r.valid = valid
    r.errorHint = errorHint
    r.warningHint = warningHint
    r.normalHint = normalHint
    r.actionHintIsStatic = inDragMode 
    return r
end

FacBuildModeHandler_Belt._HintCtx = HL.Method().Return(HL.Table) << function(self)
    local ctx = self.m_hintCtx
    ctx.buildingId = self.m_host.m_buildingId
    ctx.isBlueprintVariant = false
    ctx.pumpingLiquidItemId = nil
    return ctx
end

FacBuildModeHandler_Belt.m_hintCtx = HL.Field(HL.Table) << function() return {} end






FacBuildModeHandler_Belt.OnPressScreen = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local curMousePos = ctx.pointerPos
    local worldPos = ctx.pointerWorldPos

    local dragTargetCenterPos = self.m_provider:GetTraceDragEndCenterWorld(worldPos, true) 
    local conveyorModeValidResult = self.m_provider:IsValidTraceStartByScreen(curMousePos)

    
    local dragTargetCenterScreenPos = CameraManager.mainCamera:WorldToScreenPoint(dragTargetCenterPos)
    local halfMinSizeInScreen = host.view.config.MOBILE_MIN_DRAG_SIZE / 2 / host.view.transform.rect.width * Screen.width
    if (math.abs(curMousePos.x - dragTargetCenterScreenPos.x) > halfMinSizeInScreen or math.abs(curMousePos.y - dragTargetCenterScreenPos.y) > halfMinSizeInScreen) and (not conveyorModeValidResult) then
        local targetWorldRect = Unity.Rect()
        targetWorldRect.size = Vector2.one
        targetWorldRect.center = Vector2(dragTargetCenterPos.x, dragTargetCenterPos.z)
        if not targetWorldRect:Contains(worldPos:XZ()) then
            
            return
        end
    end

    if conveyorModeValidResult then
        LuaSystemManager.factory.canMoveCamTarget = false
        host.m_mobileDragBeltChecker = host:_StartCoroutine(function()
            while true do
                coroutine.step()
                if Input.touchCount > 1 then
                    
                    LuaSystemManager.factory.canMoveCamTarget = true
                    host.m_mobileDragBeltChecker = nil
                    return
                end
                
                if (host:_GetCurPointerPressPos() - curMousePos).sqrMagnitude > 100 then
                    host.m_isDragging = true
                    UIManager.commonTouchPanel.enableZoom = false
                    host.m_draggingOffset = Vector3.zero 
                    self.m_provider:BeginTrace(worldPos)
                    host:_UpdateAutoMoveTopViewCamState()
                    host.m_mobileDragBeltChecker = nil
                    return
                end
            end
        end)
    end
end

FacBuildModeHandler_Belt.OnReleaseScreen = HL.Override(Vector3) << function(self, worldPos)
    local host = self.m_host
    if host.m_mobileDragBeltChecker then
        
        host.m_mobileDragBeltChecker = host:_ClearCoroutine(host.m_mobileDragBeltChecker)
        if Input.touchCount <= 1 then
            self.m_provider:BeginTrace(worldPos) 
            
            host:_StartTimer(0, function()
                self.m_provider:EndTrace(worldPos) 
            end)
        end
    end
end

FacBuildModeHandler_Belt.OnTouchClickScreen = HL.Override() << function(self)
    local host = self.m_host
    if LuaSystemManager.factory.inTopView and not self:_GetConveyorMode().hasStart and host.view.actionHint.gameObject.activeInHierarchy then
        host.view.actionHint:Play("facbuildmodeerrorhint_blink")
    end
end






FacBuildModeHandler_Belt.OnConfirm = HL.Override() << function(self)
    local host = self.m_host
    local conveyorMode = self:_GetConveyorMode()
    if host.m_curBuildIsValid then
        if host.m_lockBuildPos then
            
            self.m_provider:SubmitAtGridCenter(self:_GetMark().transform.position)
        else
            local ok, worldPos = host:SamplePointerWorldPos()
            if ok then
                self.m_provider:Submit(worldPos)
            end
        end
        AudioAdapter.PostEvent("au_ui_fac_btn_belt_build_click")
    else
        AudioAdapter.PostEvent("au_ui_fac_unbuildable")
    end
    if not conveyorMode.hasStart then
        Notify(MessageConst.SHOW_TOAST, self:_IsPipe() and Language.LUA_FAC_BUILD_PIPE_START_CLICK_ERROR or Language.LUA_FAC_BUILD_BELT_START_CLICK_ERROR)
        if host.view.errorHint.gameObject.activeInHierarchy then
            host.view.errorHint:Play("facbuildmodeerrorhint_blink")
        end
    end
end

FacBuildModeHandler_Belt.OnRequestExit = HL.Override(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, reason, skipAnim)
    if reason == FacConst.FAC_BUILD_EXIT_REASON.ExitIcon and self.m_host:_InDragMode() then
        
        local conveyorMode = self:_GetConveyorMode()
        if conveyorMode then
            conveyorMode:TriggerConveyorKeyReset()
        end
        return true
    end
    return false
end

FacBuildModeHandler_Belt.CanRotate = HL.Override().Return(HL.Boolean) << function(self)
    return true 
end

FacBuildModeHandler_Belt.OnRotate = HL.Override() << function(self)
    GameInstance.remoteFactoryManager.interact:InputKeyRotation(true)
end

FacBuildModeHandler_Belt.CanStayOutOfMainRegion = HL.Override().Return(HL.Boolean) << function(self)
    return self:_IsPipe()
end

FacBuildModeHandler_Belt.OnConveyorLocalCheckFailed = HL.Override(HL.Table) << function(self, args)
    self.m_host:RefreshValidResult()
    if not self.m_host.m_curBuildIsValid then
        Notify(MessageConst.SHOW_TOAST, self.m_host.view.errorHintText.text)
    end
end

FacBuildModeHandler_Belt.OnHideToggleChanged = HL.Override(HL.Boolean) << function(self, isOn)
    local mode = FacConst.SIMPLE_FIGURE_MODE.None
    if isOn then
        mode = self:_IsPipe() and FacConst.SIMPLE_FIGURE_MODE.SimpleBeltFigure or FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure
    end
    LuaSystemManager.factory:SetSimpleFigureMode(mode)
end

FacBuildModeHandler_Belt.GetDebugPosInfo = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    return {
        id = self.m_host.m_beltId,
        pos = self:_GetMark().transform.position,
        dir = 0,
    }
end






FacBuildModeHandler_Belt._UpdateBPStartPreviewMark = HL.Method(Vector3, HL.Opt(HL.Boolean)) << function(self, curMousePos, isInit)
    local camRay = CameraManager.mainCamera:ScreenPointToRay(curMousePos)
    local ok, worldPos = self.m_provider:SampleGroundPoint(camRay)
    if not ok then
        return
    end
    self:_UpdateBPStartPreviewMarkWithWorldPos(worldPos, isInit)
end

FacBuildModeHandler_Belt._UpdateBPStartPreviewMarkWithWorldPos = HL.Method(Vector3, HL.Opt(HL.Boolean)) << function(self, worldPos, isInit)
    local host = self.m_host
    local roundedWorldPos = self.m_provider:SnapToPlacementUnit(worldPos)
    local mark = self:_GetMark()
    local trans = mark.transform
    if isInit then
        trans.position = roundedWorldPos
        host.m_bpStartPreviewMarkLastPos = nil
    else
        if not host.m_bpStartPreviewMarkLastPos or (roundedWorldPos - host.m_bpStartPreviewMarkLastPos).sqrMagnitude >= 0.01 then
            trans.position = roundedWorldPos
            host.m_bpStartPreviewMarkLastPos = roundedWorldPos
            local needAudio
            if DeviceInfo.usingTouch then
                needAudio = not LuaSystemManager.factory.inTopView or host.m_isDragging
            else
                needAudio = true
            end
            if needAudio then
                AudioAdapter.PostEvent("au_ui_belt_move")
            end
        end
    end
    self:_UpdateBPStartPreviewMarkColor(isInit)
end

FacBuildModeHandler_Belt._UpdateBPStartPreviewMarkColor = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local host = self.m_host
    local mark = self:_GetMark()
    local color
    if host.m_curBuildIsValid then
        color = mark.config.NORMAL_COLOR
    else
        color = mark.config.INVALID_COLOR
    end
    if isInit or color ~= host.m_bpStartPreviewMarkLastColor then
        host.m_bpStartPreviewMarkLastColor = color
        for _, mat in ipairs(mark.mats) do
            mat:SetColor("_TintColor", color)
        end
    end
end

FacBuildModeHandler_Belt._UpdateOnBeltHasStartChanged = HL.Method() << function(self)
    local host = self.m_host
    local hasStart = self:_GetConveyorMode().hasStart
    host.m_beltHasStartLastTick = hasStart
    local isPipe = self:_IsPipe()
    local inTopView = LuaSystemManager.factory.inTopView
    if inTopView then
        if hasStart then
            host.view.actionHintTxt:SetAndResolveTextStyle(isPipe and Language.LUA_FAC_BUILD_MODE_DRAW_PIPE_HINT_WITH_START or Language.LUA_FAC_BUILD_MODE_DRAW_BELT_HINT_WITH_START)
            
            self.m_provider:InvalidateRangeGridBound()
        else
            host.view.actionHintTxt:SetAndResolveTextStyle(isPipe and Language.LUA_FAC_BUILD_MODE_DRAW_PIPE_HINT or Language.LUA_FAC_BUILD_MODE_DRAW_BELT_HINT)
            
            self.m_provider:HideRangeGrid()
        end
        host.view.actionButtonsAsIcon.gameObject:SetActive(hasStart)
        host.view.exitBeltModeButton.gameObject:SetActive(not hasStart)
    else
        host.view.actionButtonsAsOption.rotateButton.gameObject:SetActive(hasStart)
        host.view.actionButtonsAsOption.confirmText.text = hasStart and Language.LUA_FAC_BUILD_MODE_CONFIRM_BELT_END or Language.LUA_FAC_BUILD_MODE_CONFIRM_BELT_START
    end
    if isPipe then
        host:_RefreshKeyHint(hasStart and KeyHints.pipeEnd or KeyHints.pipeStart)
    else
        host:_RefreshKeyHint(hasStart and KeyHints.beltEnd or KeyHints.beltStart)
    end
end




HL.Commit(FacBuildModeHandler_Belt)
