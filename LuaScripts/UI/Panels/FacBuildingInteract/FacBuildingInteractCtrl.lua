local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
FacBuildingInteractCtrl = HL.Class('FacBuildingInteractCtrl', uiCtrl.UICtrl)





FacBuildingInteractCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_BUILD_MODE_CHANGE] = 'OnBuildModeChange',
    [MessageConst.ON_FAC_DESTROY_MODE_CHANGE] = 'OnFacDestroyModeChange',
    [MessageConst.BEFORE_EXIT_DESTROY_MODE] = 'BeforeExitDestroyMode',

    [MessageConst.FAC_UPDATE_INTERACT_OPTION] = 'UpdateInteractOption',
    [MessageConst.ON_TOGGLE_FAC_TOP_VIEW] = 'OnToggleFacTopView',
    [MessageConst.FAC_ON_NODE_REMOVED] = 'OnBuildingRemoved',
    [MessageConst.FAC_ON_PENDING_SLOTS_REMOVED] = 'OnPendingSlotsRemoved',
    [MessageConst.ON_FAC_TOP_VIEW_CAM_TARGET_MOVED] = 'OnFacTopViewCamTargetMoved',
    [MessageConst.ON_FAC_TOP_VIEW_CAM_ZOOM] = 'OnFacTopViewCamZoom',

    [MessageConst.FAC_BLOCK_OTHER_HUB_UNLOADER_INTERACT] = 'FacBlockOtherHubUnloaderInteract',

    [MessageConst.FAC_STOP_DRAG_IN_BATCH_MODE] = 'FacStopDragInBatchMode',
    [MessageConst.ACTIVE_BUILDING_LIKE] = 'OnActiveBuildingLike',
    [MessageConst.FAC_ON_UDPIPE_INTERACT_STATE_CHANGED] = '_OnUdpipeInteractStateChanged',
}

FacBuildingInteractCtrl.m_buildingInteractHighlightEffect = HL.Field(HL.Table)

FacBuildingInteractCtrl.m_subBuildingInteractHighlightEffect = HL.Field(HL.Table)

FacBuildingInteractCtrl.m_logisticInteractHighlightEffect = HL.Field(HL.Table)

FacBuildingInteractCtrl.m_pipeInteractHighlightEffect = HL.Field(HL.Table)

FacBuildingInteractCtrl.m_hoverInteractHighlightEffect = HL.Field(HL.Table)

FacBuildingInteractCtrl.m_appliedInteractOptions = HL.Field(HL.Table)
FacBuildingInteractCtrl.m_appliedBuildingIdentity = HL.Field(HL.String) << ""
FacBuildingInteractCtrl.m_appliedSubBuildingIdentity = HL.Field(HL.String) << ""
FacBuildingInteractCtrl.m_appliedPipeIdentity = HL.Field(HL.String) << ""
FacBuildingInteractCtrl.m_appliedBeltIdentity = HL.Field(HL.String) << ""
FacBuildingInteractCtrl.m_appliedHoverIdentity = HL.Field(HL.String) << ""



FacBuildingInteractCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local isUsingCache = self.m_buildingInteractHighlightEffect ~= nil

    self.view.batchToggle.onValueChanged:AddListener(function(isOn)
        self:_OnChangeDragBatchToggle(isOn)
    end)

    if not isUsingCache then
        self:_InitInteractHighlightEffects()
    end

    self.m_curHighlightedSlotIds = {}
    self.m_appliedInteractOptions = {
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.MainBuilding] = "",
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.SubBuilding] = "",
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.Belt] = "",
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.DeleteAllBelt] = "",
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.Pipe] = "",
        [FacConst.FAC_INTERACT_OPTION_SOURCE_ID.DeleteAllPipe] = "",
    }
    self.m_appliedBuildingIdentity = ""
    self.m_appliedSubBuildingIdentity = ""
    self.m_appliedPipeIdentity = ""
    self.m_appliedBeltIdentity = ""
    self.m_appliedHoverIdentity = ""

    self.view.listNode.gameObject:SetActive(false)
    self.view.hoverInfoTextNode.gameObject:SetActive(false)

    self.view.batchSelectFrame:InitFacBatchSelectFrame(self.uiCamera, self.view.rectTransform)
    self.view.longPressHint:InitLongPressHint()
    self.view.batchNode.gameObject:SetActive(false)

    
end

FacBuildingInteractCtrl.OnShow = HL.Override() << function(self)
    LuaSystemManager.factoryInteract:AttachPresenter(self)
    if not LuaSystemManager.factory.inTopView then
        LuaSystemManager.factoryInteract:RefreshCurrentTarget(true)
    end

    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "FacBuildingInteract-BatchMode",
        type = LuaSystemManager.factory.inBatchSelectMode and UIConst.MOUSE_ICON_HINT.Frame or UIConst.MOUSE_ICON_HINT.Default,
    })
end
FacBuildingInteractCtrl.OnHide = HL.Override() << function(self)
    LuaSystemManager.factoryInteract:DetachPresenter(self)
    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "FacBuildingInteract-BatchMode",
        type = UIConst.MOUSE_ICON_HINT.Default,
    })
end
FacBuildingInteractCtrl.OnClose = HL.Override() << function(self)
    self:_RemoveInteractOption() 
    LuaSystemManager.factoryInteract:DetachPresenter(self)
end

FacBuildingInteractCtrl.ApplyInteractPresentation = HL.Method(HL.Opt(HL.Any)) << function(self, model)
    if not model then
        return
    end
    local scene = model.scene
    self.m_lastDetectWorldPos = model.detectWorldPos

    self:_ApplyBuildingPresentation(scene.building, model.forceUpdate)
    self:_ApplySubBuildingPresentation(scene.subBuilding, model.forceUpdate)
    self:_ApplyPipePresentation(scene.pipe, scene.pipeSelection, model.forceUpdate)
    self:_ApplyBeltPresentation(scene.belt, model.forceUpdate)
    self:_ApplyHoverPresentation(scene.hover, model.forceUpdate)
    self:_ApplyControllerGridPresentation(scene.controllerEmptyGrid)
    self:_ApplyPendingPresentation(scene.pendingSlotIds)
    self:_ApplyOptionModels(model.options, model.forceUpdate)
end

FacBuildingInteractCtrl.ApplyDragFrameModel = HL.Method(HL.Opt(HL.Any)) << function(self, model)
    if not model then
        return
    end
    if model.op == FacConst.FAC_INTERACT_DRAG_FRAME_OP.Begin then
        self.view.batchSelectFrame:Begin(model.reverse)
    elseif model.op == FacConst.FAC_INTERACT_DRAG_FRAME_OP.Update then
        self.view.batchSelectFrame:UpdateFrame(model)
    elseif model.op == FacConst.FAC_INTERACT_DRAG_FRAME_OP.End then
        self.view.batchSelectFrame:End()
    elseif model.op == FacConst.FAC_INTERACT_DRAG_FRAME_OP.Cancel then
        self.view.batchSelectFrame:Cancel()
    end
end

FacBuildingInteractCtrl.ApplyPressHintModel = HL.Method(HL.Table) << function(self, model)
    if model.op == FacConst.FAC_INTERACT_PRESS_HINT_OP.Start then
        self.view.longPressHint:StartLongPressHint(
            model.isLongPressToDragHint == true,
            self.view.rectTransform,
            self.view.config.LONG_PRESS_TO_DRAG_HINT_PADDING
        )
    elseif model.op == FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop then
        self.view.longPressHint:StopLongPressHint()
    end
end

FacBuildingInteractCtrl.ApplyBatchToggleModel = HL.Method(HL.Boolean) << function(self, active)
    self.view.batchToggle.isOn = active
end

FacBuildingInteractCtrl.ApplyMultiTargetModel = HL.Method(HL.Table) << function(self, model)
    local targets = model.targets
    for _, target in ipairs(targets) do
        target.action = function()
            LuaSystemManager.factoryInteract:ExecuteInteract(target.option)
            LuaSystemManager.factoryInteract:ClearInteractPresentation()
        end
    end
    Notify(MessageConst.FAC_TOPVIEW_SHOW_MULTI_TARGET_MENU, {
        targets = targets,
        screenRect = self:_CalcInteractScreenRect(),
    })
end

FacBuildingInteractCtrl.ClearInteractPresentation = HL.Method() << function(self)
    self:_RemoveInteractOption()
end

FacBuildingInteractCtrl._ApplyBuildingPresentation = HL.Method(HL.Any, HL.Boolean)
        << function(self, scene, forceUpdate)
    if not scene then
        self.m_buildingInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
        self.m_appliedBuildingIdentity = ""
        return
    end
    if forceUpdate or self.m_appliedBuildingIdentity ~= scene.identity then
        self:_SetEffect(
            self.m_buildingInteractHighlightEffect,
            scene.position,
            scene.offsetY,
            scene.rotation,
            scene.scale
        )
        self.m_buildingInteractHighlightEffect.normalNode.gameObject:SetActive(not scene.useCone)
        self.m_buildingInteractHighlightEffect.coneNode.gameObject:SetActive(scene.useCone)
        if scene.useCone then
            local dist = scene.terrainDistance or 3
            self.m_buildingInteractHighlightEffect.dot.localPosition = Vector3(0, -dist, 0)
            self.m_buildingInteractHighlightEffect.line.localScale = Vector3(
                1,
                dist + self.m_buildingInteractHighlightEffect.line.localPosition.y,
                1
            )
        end
        self.m_appliedBuildingIdentity = scene.identity
    end
    if CSFactoryUtil.hideBuildingInteractHighlightEffect then
        self.m_buildingInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
    end
end

FacBuildingInteractCtrl._ApplySubBuildingPresentation = HL.Method(HL.Any, HL.Boolean)
        << function(self, scene, forceUpdate)
    if not scene then
        self.m_subBuildingInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
        self.m_appliedSubBuildingIdentity = ""
        return
    end
    if forceUpdate or self.m_appliedSubBuildingIdentity ~= scene.identity then
        self:_SetEffect(
            self.m_subBuildingInteractHighlightEffect,
            scene.position,
            scene.offsetY,
            scene.rotation,
            scene.scale
        )
        self.m_appliedSubBuildingIdentity = scene.identity
    end
end

FacBuildingInteractCtrl._ApplyPipePresentation = HL.Method(HL.Any, HL.Any, HL.Boolean)
        << function(self, scene, pipeSelection, forceUpdate)
    if not scene then
        self.m_pipeInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
        self.m_appliedPipeIdentity = ""
    elseif forceUpdate or self.m_appliedPipeIdentity ~= scene.identity then
        self.m_pipeInteractHighlightEffect.transform.position = scene.position
        local dist = scene.terrainDistance or 3
        self.m_pipeInteractHighlightEffect.dot.localPosition = Vector3(0, -dist, 0)
        self.m_pipeInteractHighlightEffect.line.localScale = Vector3(
            1,
            dist + self.m_pipeInteractHighlightEffect.line.localPosition.y,
            1
        )
        self.m_pipeInteractHighlightEffect.gameObject:SetActive(true)
        self.m_appliedPipeIdentity = scene.identity
    end
    if pipeSelection then
        self:_SetHighlightedPipeNode(pipeSelection.nodeId, pipeSelection.unitIndex)
    else
        self:_SetHighlightedPipeNode()
    end
end

FacBuildingInteractCtrl._ApplyBeltPresentation = HL.Method(HL.Any, HL.Boolean)
        << function(self, scene, forceUpdate)
    if not scene then
        self.m_logisticInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
        self.m_appliedBeltIdentity = ""
        return
    end
    if forceUpdate or self.m_appliedBeltIdentity ~= scene.identity then
        self:_SetEffect(
            self.m_logisticInteractHighlightEffect,
            scene.position,
            scene.offsetY,
            scene.rotation,
            scene.scale
        )
        self.m_appliedBeltIdentity = scene.identity
    end
end

FacBuildingInteractCtrl._ApplyHoverPresentation = HL.Method(HL.Any, HL.Boolean)
        << function(self, scene, forceUpdate)
    if not scene then
        self.m_hoverInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
        self.m_appliedHoverIdentity = ""
        return
    end
    if forceUpdate or self.m_appliedHoverIdentity ~= scene.identity then
        self:_SetEffect(
            self.m_hoverInteractHighlightEffect,
            scene.position,
            scene.offsetY,
            scene.rotation,
            scene.scale
        )
        self.m_appliedHoverIdentity = scene.identity
    end
end

FacBuildingInteractCtrl._ApplyControllerGridPresentation = HL.Method(HL.Any) << function(self, gridPos)
    if not gridPos or (self.m_lastControllerHoverGridPos and self.m_lastControllerHoverGridPos == gridPos) then
        return
    end
    self.m_lastControllerHoverGridPos = gridPos
    AudioAdapter.PostEvent("au_ui_fac_checkerboard_controller")
end

FacBuildingInteractCtrl._ApplyPendingPresentation = HL.Method(HL.Table) << function(self, slotIds)
    local chapterId = Utils.getCurrentChapterId()
    for id in pairs(self.m_curHighlightedSlotIds) do
        if not slotIds[id] then
            CSFactoryUtil.SetPendingSlotSelected(chapterId, id, false)
        end
    end
    for id in pairs(slotIds) do
        if not self.m_curHighlightedSlotIds[id] then
            CSFactoryUtil.SetPendingSlotSelected(chapterId, id, true)
        end
    end
    local snapshot = {}
    for id in pairs(slotIds) do
        snapshot[id] = true
    end
    self.m_curHighlightedSlotIds = snapshot
end

FacBuildingInteractCtrl._ApplyOptionModels = HL.Method(HL.Table, HL.Boolean)
        << function(self, options, forceUpdate)
    local applied = self.m_appliedInteractOptions
    for sourceId in pairs(applied) do
        if not options[sourceId] then
            Notify(MessageConst.REMOVE_INTERACT_OPTION, {
                type = CS.Beyond.Gameplay.Core.InteractOptionType.Factory,
                sourceId = sourceId,
            })
            applied[sourceId] = nil
        end
    end
    for sourceId, option in pairs(options) do
        local oldIdentity = applied[sourceId]
        local identityChanged = oldIdentity ~= option.identity
        if not oldIdentity then
            Notify(MessageConst.ADD_INTERACT_OPTION, option.args)
        elseif option.updateEveryFrame then
            option.args.setTopAsSelectedWhenSort =
                option.setTopWhenIdentityChanged and identityChanged
            Notify(MessageConst.UPDATE_INTERACT_OPTION, option.args)
        elseif identityChanged or forceUpdate then
            Notify(MessageConst.ADD_INTERACT_OPTION, option.args)
        end
        applied[sourceId] = option.identity
    end
end

FacBuildingInteractCtrl._InitInteractHighlightEffects = HL.Method() << function(self)
    do
        local prefab = self.loader:LoadGameObject(FacConst.BUILDING_INTERACT_BUILDING_INDICATOR_PATH)
        self.m_buildingInteractHighlightEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_buildingInteractHighlightEffect.gameObject.name = "BuildingInteractHighlightEffect"
        self.m_buildingInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
    end

    do
        local prefab = self.loader:LoadGameObject(FacConst.BUILDING_INTERACT_NORMAL_INDICATOR_PATH)
        self.m_subBuildingInteractHighlightEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_subBuildingInteractHighlightEffect.gameObject.name = "SubBuildingInteractHighlightEffect"
        self.m_subBuildingInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)

        self.m_logisticInteractHighlightEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_logisticInteractHighlightEffect.gameObject.name = "LogisticInteractHighlightEffect"
        self.m_logisticInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
    end

    do
        local prefab = self.loader:LoadGameObject(FacConst.BUILDING_INTERACT_HOVER_INDICATOR_PATH)
        self.m_hoverInteractHighlightEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_hoverInteractHighlightEffect.gameObject.name = "HoverInteractHighlightEffect"
        self.m_hoverInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
    end

    do
        local prefab = self.loader:LoadGameObject(FacConst.BUILDING_INTERACT_PIPE_INDICATOR_PATH)
        self.m_pipeInteractHighlightEffect = Utils.wrapLuaNode(self:_CreateWorldGameObject(prefab))
        self.m_pipeInteractHighlightEffect.gameObject.name = "PipeInteractHighlightEffect"
        self.m_pipeInteractHighlightEffect.gameObject:SetActiveIfNecessary(false)
    end
end

FacBuildingInteractCtrl.ExtractHotSwitchRuntimeState = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if not self.m_buildingInteractHighlightEffect and
        not self.m_subBuildingInteractHighlightEffect and
        not self.m_logisticInteractHighlightEffect and
        not self.m_pipeInteractHighlightEffect and
        not self.m_hoverInteractHighlightEffect then
        return nil
    end

    local state = {
        buildingInteractHighlightEffect = self.m_buildingInteractHighlightEffect,
        subBuildingInteractHighlightEffect = self.m_subBuildingInteractHighlightEffect,
        logisticInteractHighlightEffect = self.m_logisticInteractHighlightEffect,
        pipeInteractHighlightEffect = self.m_pipeInteractHighlightEffect,
        hoverInteractHighlightEffect = self.m_hoverInteractHighlightEffect,
    }

    self.m_buildingInteractHighlightEffect = nil
    self.m_subBuildingInteractHighlightEffect = nil
    self.m_logisticInteractHighlightEffect = nil
    self.m_pipeInteractHighlightEffect = nil
    self.m_hoverInteractHighlightEffect = nil

    return state
end

FacBuildingInteractCtrl.RestoreHotSwitchRuntimeState = HL.Override(HL.Opt(HL.Any)) << function(self, state)
    if not state then
        return
    end

    self.m_buildingInteractHighlightEffect = state.buildingInteractHighlightEffect
    self.m_subBuildingInteractHighlightEffect = state.subBuildingInteractHighlightEffect
    self.m_logisticInteractHighlightEffect = state.logisticInteractHighlightEffect
    self.m_pipeInteractHighlightEffect = state.pipeInteractHighlightEffect
    self.m_hoverInteractHighlightEffect = state.hoverInteractHighlightEffect
end

FacBuildingInteractCtrl.OnToggleFacTopView = HL.Method(HL.Boolean) << function(self, active)
    self:_RemoveInteractOption() 
    local pipeMarkShowAsBox = active and DeviceInfo.usingTouch
    self.m_pipeInteractHighlightEffect.content.gameObject:SetActive(not pipeMarkShowAsBox)
    self.m_pipeInteractHighlightEffect.boxMarkNode.gameObject:SetActive(pipeMarkShowAsBox)
end

FacBuildingInteractCtrl.UpdateInteractOption = HL.Method(HL.Opt(HL.Boolean)) << function(self, force)
    if force or self:IsShow() then
        LuaSystemManager.factoryInteract:RefreshCurrentTarget(force)
    end
end



FacBuildingInteractCtrl._OnUdpipeInteractStateChanged = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    LuaSystemManager.factoryInteract:RefreshCurrentTarget(true)
end



FacBuildingInteractCtrl.OnBuildModeChange = HL.Method(HL.Number) << function(self, mode)
    if mode ~= FacConst.FAC_BUILD_MODE.Normal then
        self:_RemoveInteractOption()
    end
    CSFactoryUtil.ClearSelectGrids()
    CSFactoryUtil.ClearHoverGrid()
end

FacBuildingInteractCtrl.OnFacDestroyModeChange = HL.Method(HL.Boolean) << function(self, inDestroyMode)
    
    local reserveBatchMode
    local _, desPanelCtrl = UIManager:IsOpen(PanelId.FacDestroyMode)
    if not inDestroyMode and InputManagerInst.inChangingInputDevice then
        
        reserveBatchMode = true
    elseif inDestroyMode and desPanelCtrl.m_args.isFromChangeInputDevice then
        
        reserveBatchMode = true
    end

    if LuaSystemManager.factory.inTopView and DeviceInfo.usingController then
        
        LuaSystemManager.factoryInteract:RefreshCurrentTarget()
    else
        self:_RemoveInteractOption()
        LuaSystemManager.factoryInteract:RefreshCurrentTarget(true)
    end

    self:_ResetBatch(inDestroyMode)
    self.view.batchNode:ClearTween(false)
    local isBatch = inDestroyMode and LuaSystemManager.factory.inTopView
    if isBatch then
        
        self.view.batchNode.gameObject:SetActive(true)
        if not reserveBatchMode then
            self:_ChangeBatchMode(true)
        end
    else
        self.view.batchNode.gameObject:SetActive(false)
        if not reserveBatchMode then
            self:_ChangeBatchMode(false)
        end
    end

    CSFactoryUtil.ClearSelectGrids()
    CSFactoryUtil.ClearHoverGrid()
end

FacBuildingInteractCtrl.BeforeExitDestroyMode = HL.Method() << function(self)
    
    self.view.batchNode:PlayOutAnimation()
end

FacBuildingInteractCtrl.OnBuildingRemoved = HL.Method(HL.Table) << function(self, arg)
    
    self:_RemoveInteractOption()
    if LuaSystemManager.factory.inBatchSelectMode then
        LuaSystemManager.factoryInteract:ClearAllBatchTargets()
    end
end

FacBuildingInteractCtrl.OnPendingSlotsRemoved = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    self:_RemoveInteractOption()
    if LuaSystemManager.factory.inBatchSelectMode then
        LuaSystemManager.factoryInteract:ClearAllBatchTargets()
    end
end

FacBuildingInteractCtrl._RemoveInteractOption = HL.Method() << function(self)
    self:_ApplyBuildingPresentation(nil, true)
    self:_ApplySubBuildingPresentation(nil, true)
    self:_ApplyPipePresentation(nil, nil, true)
    self:_ApplyBeltPresentation(nil, true)
    self:_ApplyHoverPresentation(nil, true)
    self:_ApplyPendingPresentation({})
    self:_ApplyOptionModels({}, true)

    self.view.listNode.gameObject:SetActiveIfNecessary(false)
    self.view.hoverInfoTextNode.gameObject:SetActiveIfNecessary(false)

    GameWorld.interactiveFacWrapperManager:OnFacBuildingInteractOptionRemoveAll()
end

FacBuildingInteractCtrl._SetEffect = HL.Method(HL.Table, CS.UnityEngine.Vector3, HL.Number, HL.Opt(CS.UnityEngine.Vector3, CS.UnityEngine.Vector3))
        << function(self, effect, pos, offsetY, rot, scale)
    
    
    local effectPos = Vector3(pos.x, pos.y + offsetY, pos.z)
    local rfm = GameInstance.remoteFactoryManager
    if rfm.isRemoteTopViewActive then
        effectPos = effectPos + rfm.remoteTopViewOffset
    end
    effect.transform.position = effectPos
    effect.transform.eulerAngles = rot or Vector3.zero
    scale = scale or Vector3.one
    effect.transform.localScale = scale
    for k = 1, 4 do
        effect["corner" .. k].transform.localScale = Vector3(1 / scale.x, 1, 1 / scale.z)
    end
    if effect.gameObject.activeSelf then
        return
    end
    effect.gameObject:SetActive(true)
    
    for k = 1, 4 do
        effect["effect" .. k]:Update(0)
    end
end




FacBuildingInteractCtrl.m_lastDetectWorldPos = HL.Field(HL.Any)

FacBuildingInteractCtrl.OnActiveBuildingLike = HL.Method(HL.Any) << function(self, args)
    local nodeId = unpack(args)
    FactoryUtils.likeSocialBuilding(nodeId, function()
        local model = LuaSystemManager.factoryInteract:GetCurrentPresentationModel()
        local building = model and model.resolvedTargetSet.building
        if not building or building.nodeId ~= nodeId then
            return 
        end
        FactoryUtils.updateBuildingLikeAbilityState(nodeId)
    end)
end


FacBuildingInteractCtrl.m_lastControllerHoverGridPos = HL.Field(HL.Any)

FacBuildingInteractCtrl.m_curHighlightedPipeNodeId = HL.Field(HL.Any)

FacBuildingInteractCtrl.m_curHighlightedPipeUnitIndex = HL.Field(HL.Any)

FacBuildingInteractCtrl._SetHighlightedPipeNode = HL.Method(HL.Opt(HL.Number, HL.Number)) << function(self, pipeNodeId, unitIndex)
    if self.m_curHighlightedPipeNodeId == pipeNodeId and self.m_curHighlightedPipeUnitIndex == unitIndex then
        return
    end
    if pipeNodeId then
        LuaSystemManager.factory:RequestPipeHighlight(
            FacConst.FAC_PIPE_HIGHLIGHT_SOURCE.InteractHover,
            pipeNodeId,
            unitIndex
        )
    else
        LuaSystemManager.factory:ReleasePipeHighlight(FacConst.FAC_PIPE_HIGHLIGHT_SOURCE.InteractHover)
    end
    self.m_curHighlightedPipeNodeId = pipeNodeId
    self.m_curHighlightedPipeUnitIndex = unitIndex
end


FacBuildingInteractCtrl.m_curHighlightedSlotIds = HL.Field(HL.Table)



FacBuildingInteractCtrl._CalcInteractScreenRect = HL.Method().Return(HL.Userdata) << function(self)
    local worldPoints
    if DeviceInfo.usingTouch and LuaSystemManager.factory.inTopView and self.m_lastDetectWorldPos then
        local wp = self.m_lastDetectWorldPos
        local cx = math.floor(wp.x) + 0.5
        local cz = math.floor(wp.z) + 0.5
        worldPoints = {
            Vector3(cx - 0.5, wp.y, cz - 0.5),
            Vector3(cx + 0.5, wp.y, cz - 0.5),
            Vector3(cx - 0.5, wp.y, cz + 0.5),
            Vector3(cx + 0.5, wp.y, cz + 0.5),
        }
    else
        local effect = self.m_hoverInteractHighlightEffect
        worldPoints = {
            effect.corner1.transform.position,
            effect.corner2.transform.position,
            effect.corner3.transform.position,
            effect.corner4.transform.position,
        }
    end
    local cam = CameraManager.mainCamera
    local sp = cam:WorldToScreenPoint(worldPoints[1])
    local minX, minY, maxX, maxY = sp.x, sp.y, sp.x, sp.y
    for i = 2, #worldPoints do
        sp = cam:WorldToScreenPoint(worldPoints[i])
        minX = math.min(minX, sp.x)
        minY = math.min(minY, sp.y)
        maxX = math.max(maxX, sp.x)
        maxY = math.max(maxY, sp.y)
    end
    return Unity.Rect(minX, Screen.height - maxY, maxX - minX, maxY - minY)
end

FacBuildingInteractCtrl.OnFacTopViewCamTargetMoved = HL.Method() << function(self)
    self:_RemoveInteractOption()
    Notify(MessageConst.FAC_TOPVIEW_HIDE_MULTI_TARGET_MENU)
    LuaSystemManager.factoryInteract:MarkBatchDragDirty()
end

FacBuildingInteractCtrl.OnFacTopViewCamZoom = HL.Method(HL.Number) << function(self, _)
    self:_RemoveInteractOption()
    Notify(MessageConst.FAC_TOPVIEW_HIDE_MULTI_TARGET_MENU)
end







FacBuildingInteractCtrl._ResetBatch = HL.Method(HL.Boolean) << function(self, inDestroyMode)
    self.view.batchSelectFrame:Cancel()
    self.view.batchToggle.isOn = inDestroyMode and LuaSystemManager.factory.inTopView and DeviceInfo.usingKeyboard
    LuaSystemManager.factory:ChangeIsReverseSelect(false)
end

FacBuildingInteractCtrl._ChangeBatchMode = HL.Method(HL.Boolean) << function(self, isBatch)
    LuaSystemManager.factory.inBatchSelectMode = isBatch
    LuaSystemManager.factoryInteract:ClearAllBatchTargets()
    Notify(MessageConst.FAC_ON_TOGGLE_BATCH_MODE, isBatch)

    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "FacBuildingInteract-BatchMode",
        type = isBatch and UIConst.MOUSE_ICON_HINT.Frame or UIConst.MOUSE_ICON_HINT.Default,
    })

    if isBatch then
        GameInstance.remoteFactoryManager.batchSelect:EnterBatchSelect()
    else
        GameInstance.remoteFactoryManager.batchSelect:ExitBatchSelect()
    end
end

FacBuildingInteractCtrl._OnChangeDragBatchToggle = HL.Method(HL.Boolean) << function(self, isBatch)
    LuaSystemManager.factory.inDragSelectBatchMode = isBatch
    if isBatch then
        if DeviceInfo.usingTouch then
            
            UIManager.commonTouchPanel.enableZoom = false
        end
    else
        if DeviceInfo.usingTouch then
            UIManager.commonTouchPanel.enableZoom = true
        end
        LuaSystemManager.factoryInteract:EndBatchDrag()
    end
end




FacBuildingInteractCtrl.FacBlockOtherHubUnloaderInteract = HL.Method(HL.Table) << function(self, arg)
    local targetIndex = unpack(arg)
    LuaSystemManager.factoryInteract:SetOnlyValidHubUnloaderIndex(targetIndex)
end

FacBuildingInteractCtrl.FacStopDragInBatchMode = HL.Method() << function(self)
    LuaSystemManager.factoryInteract:StopBatchControllerDrag()
end


HL.Commit(FacBuildingInteractCtrl)
