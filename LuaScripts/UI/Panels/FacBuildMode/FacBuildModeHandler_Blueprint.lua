








local handlerBase = require_ex('UI/Panels/FacBuildMode/FacBuildModeHandler')
local FacBuildCheckResultHint = require_ex('UI/Panels/FacBuildMode/FacBuildCheckResultHint')

local KeyHints = {
    blueprint = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel",
    },
}


FacBuildModeHandler_Blueprint = HL.Class('FacBuildModeHandler_Blueprint', handlerBase.FacBuildModeHandler)

FacBuildModeHandler_Blueprint.FacBuildModeHandler_Blueprint = HL.Constructor(HL.Forward('FacBuildModeCtrl')) << function(self, host)
    FacBuildModeHandler_Blueprint.SuperConstructor(self, host)
    self.m_provider = GameInstance.remoteFactoryManager.blueprintPlacementProvider
end

FacBuildModeHandler_Blueprint._GetBlueprintMode = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    return GameInstance.remoteFactoryManager.interact.currentBlueprintMode
end




FacBuildModeHandler_Blueprint.OnEnter = HL.Override(HL.Table) << function(self, args)
    FacBuildModeHandler_Blueprint.Super.OnEnter(self, args)
    local host = self.m_host
    local provider = self.m_provider
    host.m_lastBPGridPos = nil

    local initGridPos
    if args.initGridPos then
        initGridPos = Unity.Vector3Int(math.floor(args.initGridPos.x), math.floor(args.initGridPos.y), math.floor(args.initGridPos.z))
    else
        local mousePos
        if args.initMousePos then
            mousePos = Vector3(args.initMousePos.x, args.initMousePos.y, 0)
        else
            mousePos = host:_InDragMode() and Vector3(Screen.width / 2, Screen.height / 2, 0) or host:_GetCurPointerPressPos()
        end
        local camRay = CameraManager.mainCamera:ScreenPointToRay(mousePos)
        local _, initWorldPos = provider:SampleGroundPoint(camRay)
        initGridPos = provider:WorldToInitGrid(initWorldPos)
    end

    host:_RefreshKeyHint(KeyHints.blueprint)

    local initDir = args.initDir or 0
    if args.blueprint then
        
        provider:BeginBlueprint(args.blueprint, initGridPos, initDir, args.isMove or false)
        Notify(MessageConst.FAC_TOP_VIEW_SET_BLUEPRINT_ICONS, args.blueprint)
    elseif args.csBPInst then
        
        provider:BeginServerBlueprint(args.csBPInst, initGridPos, initDir)
        if args.csBPInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Sys then
            host.m_buildArgs.isSystemBP = true
            host.m_buildArgs.sysBpKey = args.csBPInst.param.sysBpKey
        elseif args.csBPInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Preset then
            host.m_buildArgs.isSystemBP = true
            host.m_buildArgs.sysBpKey = args.csBPInst.param.presetBpKey
        end
        Notify(MessageConst.FAC_TOP_VIEW_SET_BLUEPRINT_ICONS, args.csBPInst.info.bp)
    elseif args[1] then 
        provider:BeginServerBlueprint(args[1], initGridPos, initDir)
    end

    local mode = self:_GetBlueprintMode()
    if mode.onPlaceBlueprint then
        mode.onPlaceBlueprint = mode.onPlaceBlueprint - host.m_onPlaceFinish
        mode.onPlaceBlueprint = mode.onPlaceBlueprint + host.m_onPlaceFinish
    else
        mode.onPlaceBlueprint = host.m_onPlaceFinish
    end

    host:_ResetMoveBuildingHintState()
    host.view.moveBuildingHint.gameObject:SetActive(args.isMove == true)
    self:_AdjustCameraForBlueprint(true)

    if args.isMove then
        host:_TryExitLinkWireOnBuildingMove(args.batchSelectTargets)
    end
end

FacBuildModeHandler_Blueprint.OnExit = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    Notify(MessageConst.FAC_TOP_VIEW_SET_BLUEPRINT_ICONS)
    
    local mode = self:_GetBlueprintMode()
    if mode then
        mode.onPlaceBlueprint = mode.onPlaceBlueprint - host.m_onPlaceFinish
    end
    FacBuildModeHandler_Blueprint.Super.OnExit(self, ctx)
    self:_AdjustCameraForBlueprint(false)
end

FacBuildModeHandler_Blueprint.GetEnterMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_ENTER_BLUEPRINT_MODE
end

FacBuildModeHandler_Blueprint.GetExitMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_EXIT_BLUEPRINT_MODE
end

FacBuildModeHandler_Blueprint.OnRequestExit = HL.Override(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, reason, skipAnim)
    local host = self.m_host
    local fromClick = reason == FacConst.FAC_BUILD_EXIT_REASON.CancelInput
    if InputManagerInst.inChangingInputDevice then
        host:SwitchTo(FacConst.FAC_BUILD_MODE.Normal, nil, true)
        return true
    end

    local targets = host.m_buildArgs.batchSelectTargets
    local showCreateHint = host.m_buildArgs.showCreateHint
    if fromClick and targets then
        
        host:SwitchTo(FacConst.FAC_BUILD_MODE.Normal, nil, true)
        Notify(MessageConst.FAC_ENTER_DESTROY_MODE, {
            fastEnter = true,
            batchSelectTargets = targets,
            showCreateHint = showCreateHint,
        })
        return true
    end

    local csBPInst = host.m_buildArgs.csBPInst
    local bpSearchInfos = host.m_buildArgs.searchInfos
    if fromClick and csBPInst then
        
        local clearScreenKey = UIManager:ClearScreen({ PanelId.FacBuildMode })
        host:SwitchTo(FacConst.FAC_BUILD_MODE.Normal, nil, true)
        PhaseManager:OpenPhaseFast(PhaseId.FacBlueprint, { csBPInst = csBPInst, bpSearchInfos = bpSearchInfos })
        UIManager:RecoverScreen(clearScreenKey)
        return true
    end

    return false
end






FacBuildModeHandler_Blueprint.OnTick = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local provider = self.m_provider
    local curMode = self:_GetBlueprintMode()
    local usingDrag = ctx.usingDrag

    if not usingDrag or ctx.isDragging then
        
        if ctx.sampleOk then
            provider:UpdatePreview(ctx.pointerWorldPos)
            ctx.posChanged = true
        end
        local gridPos = Unity.Vector2Int(curMode.preparedPosition.x, curMode.preparedPosition.z)
        if gridPos ~= host.m_lastBPGridPos then
            self:_SetBluePrintSelectGrids(gridPos)
        end
    elseif usingDrag then
        if not host.m_lastBPGridPos then
            ctx.posChanged = true
            self:_SetBluePrintSelectGrids(Unity.Vector2Int(curMode.preparedPosition.x, curMode.preparedPosition.z))
        else
            
            local buildingCenterPos = provider:GetPreparedCenterWorld() 
            local buildingScreenPos = CameraManager.mainCamera:WorldToScreenPoint(buildingCenterPos)
            buildingScreenPos.z = 0
            local newScreenPos = Vector3.zero
            newScreenPos.x = lume.clamp(buildingScreenPos.x, host.view.config.DRAG_MODE_BUILDING_PADDING_X.x, Screen.width - host.view.config.DRAG_MODE_BUILDING_PADDING_X.y)
            newScreenPos.y = lume.clamp(buildingScreenPos.y, host.view.config.DRAG_MODE_BUILDING_PADDING_Y.x, Screen.height - host.view.config.DRAG_MODE_BUILDING_PADDING_Y.y)
            if newScreenPos ~= buildingScreenPos then
                local camRay = CameraManager.mainCamera:ScreenPointToRay(newScreenPos)
                local ok, wp = provider:SampleGroundPoint(camRay)
                if ok then
                    provider:UpdatePreview(wp)
                end
                ctx.posChanged = true
                self:_SetBluePrintSelectGrids(Unity.Vector2Int(curMode.preparedPosition.x, curMode.preparedPosition.z))
            end
        end
    end
    
    ctx.customGridCenter = provider:GetPreparedLogicAnchorWorld()
    Notify(MessageConst.ON_BLUEPRINT_UPDATE)
    self:_ApplyCustomGridCenter(ctx)
end

FacBuildModeHandler_Blueprint._ApplyCustomGridCenter = HL.Method(HL.Table) << function(self, ctx)
    local curMode = self:_GetBlueprintMode()
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

FacBuildModeHandler_Blueprint.GetDragFollowInfo = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local host = self.m_host
    local curMode = self:_GetBlueprintMode()
    local range = host.m_buildArgs.range
    local needReverse = curMode.preparedDirection % 2 == 1
    local r = self.m_dragFollowInfo
    r.worldPos = self.m_provider:GetPreparedAnchorWorld() 
    r.worldSize = Vector3(needReverse and range.height or range.width, 0, needReverse and range.width or range.height)
    return r
end

FacBuildModeHandler_Blueprint.EvaluatePlacement = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local host = self.m_host
    local r = self:_ResetPlacementResult()
    local curMode = self:_GetBlueprintMode()
    if not curMode then
        return r
    end
    local valid, errorHint
    valid, errorHint = FacBuildCheckResultHint.getBuildingHint(curMode.addBuildingCheckResult, self:_HintCtx())
    if valid then
        valid, errorHint = FacBuildCheckResultHint.getConveyorHint(curMode.addConveyorCheckResult, false, self:_HintCtx())
    end
    if valid then
        valid, errorHint = FacBuildCheckResultHint.getConveyorHint(curMode.addPipeCheckResult, true, self:_HintCtx())
    end
    if valid and host.m_buildArgs.isSystemBP then
        local dir = curMode.preparedDirection * 90
        local pos = self.m_provider:GetPreparedAnchorWorld() 
        CS.Beyond.Gameplay.Conditions.OnFacPrepareBuildingEnterArea.Trigger(host.m_buildArgs.sysBpKey, pos, dir)
    end
    r.valid = valid
    r.errorHint = errorHint
    return r
end

FacBuildModeHandler_Blueprint._HintCtx = HL.Method().Return(HL.Table) << function(self)
    local ctx = self.m_hintCtx
    ctx.buildingId = nil
    ctx.isBlueprintVariant = true
    ctx.pumpingLiquidItemId = nil
    return ctx
end

FacBuildModeHandler_Blueprint.m_hintCtx = HL.Field(HL.Table) << function() return {} end






FacBuildModeHandler_Blueprint.OnPressScreen = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local curMode = self:_GetBlueprintMode()
    local curMousePos = ctx.pointerPos
    local worldPos = ctx.pointerWorldPos
    local dragTargetCenterPos = self.m_provider:GetPreparedAnchorWorld() 

    
    local dragTargetCenterScreenPos = CameraManager.mainCamera:WorldToScreenPoint(dragTargetCenterPos)
    local halfMinSizeInScreen = host.view.config.MOBILE_MIN_DRAG_SIZE / 2 / host.view.transform.rect.width * Screen.width
    if math.abs(curMousePos.x - dragTargetCenterScreenPos.x) > halfMinSizeInScreen or math.abs(curMousePos.y - dragTargetCenterScreenPos.y) > halfMinSizeInScreen then
        local range = host.m_buildArgs.range
        local targetWorldRect = Unity.Rect()
        targetWorldRect.size = Vector2(range.width, range.height)
        local direction = curMode.preparedDirection
        if direction % 2 == 1 then
            targetWorldRect.size = Vector2(targetWorldRect.size.y, targetWorldRect.size.x)
        end
        local rectCenter = Vector2(dragTargetCenterPos.x, dragTargetCenterPos.z)
        if targetWorldRect.width % 2 == 1 then
            rectCenter.x = rectCenter.x + 0.5
        end
        if targetWorldRect.height % 2 == 1 then
            rectCenter.y = rectCenter.y + 0.5
        end
        targetWorldRect.center = rectCenter
        if not targetWorldRect:Contains(worldPos:XZ()) then
            
            return
        end
    end

    
    host:BeginDragOnTarget(curMousePos, self.m_provider:GetPreparedCenterWorld())
end






FacBuildModeHandler_Blueprint.OnConfirm = HL.Override() << function(self)
    self:_ConfirmCommon()
end

FacBuildModeHandler_Blueprint.OnRotate = HL.Override() << function(self)
    FacBuildModeHandler_Blueprint.Super.OnRotate(self)
    self:_SetBluePrintSelectGrids(self.m_host.m_lastBPGridPos)
end

FacBuildModeHandler_Blueprint.GetRecoverState = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local curMode = self:_GetBlueprintMode()
    if not curMode then
        return nil
    end
    return {
        initDir = curMode.preparedDirection,
        controllerMouseWorldPos = self.m_provider:GetPreparedAnchorWorld(), 
    }
end

FacBuildModeHandler_Blueprint.GetDebugPosInfo = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local host = self.m_host
    if not host.m_buildArgs.isSystemBP then
        return nil
    end
    local curMode = self:_GetBlueprintMode()
    return {
        id = host.m_buildArgs.sysBpKey,
        dir = curMode.preparedDirection * 90,
        pos = self.m_provider:GetPreparedAnchorWorld(), 
    }
end

FacBuildModeHandler_Blueprint.OnBackendPlaceFinish = HL.Override() << function(self)
    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BUILD_CONTINUOUS_SUCCESS)
    self.m_host:_UpdatePendingHint()
    self.m_provider:SyncFence()
end

FacBuildModeHandler_Blueprint.OnBuildingBatchMoved = HL.Override() << function(self)
    local host = self.m_host
    if not host.m_buildArgs then
        return
    end
    local targets = host.m_buildArgs.batchSelectTargets
    host:_ExitCurMode(true)
    if targets then
        Notify(MessageConst.FAC_UPDATE_TOP_VIEW_BUILDING_INFOS, targets)
    end
end






FacBuildModeHandler_Blueprint._AdjustCameraForBlueprint = HL.Method(HL.Boolean) << function(self, isEnterBlueprint)
    local camCtrl = LuaSystemManager.factory.m_topViewCamCtrl
    if not isEnterBlueprint then
        camCtrl:ResetCameraAdjustForRange()
        return
    end

    local range = self.m_host.m_buildArgs.range
    if not range then
        return
    end
    local needReverse = lume.round(LuaSystemManager.factory.topViewCamTarget.eulerAngles.y) % 180 ~= 0
    camCtrl:AdjustCameraForRange(needReverse and range.height or range.width, needReverse and range.width or range.height, function(pos)
        return FactoryUtils.clampTopViewCamTargetPosition(pos)
    end)
end

FacBuildModeHandler_Blueprint._SetBluePrintSelectGrids = HL.Method(CS.UnityEngine.Vector2Int) << function(self, gridPos)
    local host = self.m_host
    host.m_lastBPGridPos = gridPos
    local range = host.m_buildArgs.range
    local curMode = self:_GetBlueprintMode()
    local dir = curMode.preparedDirection
    local needReverse = dir % 2 == 1
    local width = needReverse and range.height or range.width
    local height = needReverse and range.width or range.height
    local rectInt = CS.UnityEngine.RectInt(gridPos.x - math.floor(width / 2), gridPos.y - math.floor(height / 2), width, height)
    CSFactoryUtil.SetSelectGrids(rectInt, CS.Beyond.Gameplay.Factory.GlobalSharedData.MapGridRendererData.MapGridInfo.SelectType.BLUEPRINT)

    
    local bpOriVoxelPos = Vector3(rectInt.center.x, curMode.preparedPosition.y, rectInt.center.y)
    if dir == 0 then
        bpOriVoxelPos = bpOriVoxelPos - Vector3(width / 2, 0, height / 2)
    elseif dir == 1 then
        bpOriVoxelPos = bpOriVoxelPos - Vector3(width / 2, 0, -height / 2)
    elseif dir == 2 then
        bpOriVoxelPos = bpOriVoxelPos + Vector3(width / 2, 0, height / 2)
    elseif dir == 3 then
        bpOriVoxelPos = bpOriVoxelPos + Vector3(width / 2, 0, -height / 2)
    end
    local manager = GameInstance.remoteFactoryManager
    local bpOriWorldPos = manager:LogicalToView(manager.visual:VoxelToWorld(bpOriVoxelPos))
    Notify(MessageConst.FAC_TOP_VIEW_SET_BLUEPRINT_ICON_POS, { bpOriWorldPos, dir })
end




HL.Commit(FacBuildModeHandler_Blueprint)
