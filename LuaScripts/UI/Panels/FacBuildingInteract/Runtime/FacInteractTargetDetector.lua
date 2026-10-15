















































local function hasUsableNodeHandler(nodeId, chapterId, pendingSlotId)
    if not nodeId or nodeId <= 0 then
        return false
    end
    if pendingSlotId and pendingSlotId > 0 then
        return true
    end
    chapterId = chapterId or Utils.getCurrentChapterId()
    return FactoryUtils.getBuildingNodeHandler(nodeId, chapterId) ~= nil
end


FacInteractTargetDetector = HL.Class('FacInteractTargetDetector')

FacInteractTargetDetector.m_pointOutput = HL.Field(HL.Table) << function()
    return {
        targets = {},
        overlapBuildings = {},
        targetMap = {},
    }
end

FacInteractTargetDetector.m_rectOutput = HL.Field(HL.Table) << function()
    return {
        targets = {},
        overlapBuildings = {},
        targetMap = {},
    }
end

FacInteractTargetDetector.m_buildingTarget = HL.Field(HL.Table) << function() return {} end
FacInteractTargetDetector.m_pipeTarget = HL.Field(HL.Table) << function() return {} end
FacInteractTargetDetector.m_beltTarget = HL.Field(HL.Table) << function() return {} end
FacInteractTargetDetector.m_delayedPipeNodeInfo = HL.Field(HL.Table)

FacInteractTargetDetector.FacInteractTargetDetector = HL.Constructor() << function(self)
end

FacInteractTargetDetector._ResetOutput = HL.Method(HL.Table).Return(HL.Table) << function(self, output)
    output.primaryTarget = nil
    output.building = nil
    output.pipe = nil
    output.belt = nil
    output.formationZone = nil
    for key in pairs(output.targets) do
        output.targets[key] = nil
    end
    for key in pairs(output.overlapBuildings) do
        output.overlapBuildings[key] = nil
    end
    for key in pairs(output.targetMap) do
        output.targetMap[key] = nil
    end
    return output
end








FacInteractTargetDetector._GetGridUnitFromWorldPos = HL.Method(Vector2, HL.Number).Return(HL.Table) << function(self, worldPos, sampleType)
    local gridPos = Unity.Vector2Int(lume.round(worldPos.x), lume.round(worldPos.y))

    local success, nodeId, unitIndex, unitTemplateId
    if sampleType == FacConst.FAC_SAMPLE_TYPE.Belt then
        success, nodeId, unitIndex, unitTemplateId = GameInstance.remoteFactoryManager:TrySampleConveyor(gridPos)
    elseif sampleType == FacConst.FAC_SAMPLE_TYPE.Pipe then
        success, nodeId, unitIndex, unitTemplateId = GameInstance.remoteFactoryManager:TrySamplePipe(gridPos)
    end

    return {
        success = success,
        nodeId = nodeId,
        unitIndex = unitIndex,
        unitTemplateId = unitTemplateId,
    }
end

FacInteractTargetDetector._BuildPointDetectContext = HL.Method(HL.Table).Return(HL.Table)
        << function(self, input)
    local isClickMode = input.viewMode == FacConst.FAC_INTERACT_TARGET_VIEW_MODE.TopView
    local maxDist, maxAngle
    if not isClickMode then
        if LuaSystemManager.factory.inDestroyMode then
            
            maxDist = input.buildingInteractRange + 1
        else
            maxDist = input.buildingInteractRange
        end
        maxAngle = input.buildingInteractAngle
    else
        maxDist = 0
        maxAngle = -1
    end

    
    
    local useAsyncRst = not (isClickMode or LuaSystemManager.factory.inDestroyMode)

    local playerPos = input.playerPos
    
    
    
    local gridSampleWorldPos = playerPos
    if GameInstance.remoteFactoryManager.isRemoteTopViewActive then
        gridSampleWorldPos = playerPos - GameInstance.remoteFactoryManager.remoteTopViewOffset
    end

    return {
        input = input,
        isClickMode = isClickMode,
        chapterId = Utils.getCurrentChapterId(),
        playerPos = playerPos,
        playerForward = input.playerForward,
        maxDist = maxDist,
        maxAngle = maxAngle,
        useAsyncRst = useAsyncRst,
        gridSampleWorldPos = gridSampleWorldPos,
        buildingPendingSlotId = 0,
        pipePendingSlotId = 0,
    }
end

FacInteractTargetDetector._DetectPointBuilding = HL.Method(HL.Table, HL.Table)
        << function(self, ctx, output)
    local foundBuilding, targetBuildingNodeId, targetBuildingTemplateId, targetBuildingPosition
    local targetBuildingRotation, targetBuildingAdjustMapHeight, subBuildingInfo, targetBuildingChapterId
    local csOverlappingNodeIds

    if ctx.useAsyncRst then
        
        local succ, info = CSFactoryUtil.GetShouldInteractFacEntityUsingAsyncRst()
        foundBuilding = succ and info.valid and info.nodeId > 0
        if foundBuilding then
            targetBuildingNodeId = info.nodeId
            targetBuildingChapterId = info.chapterId
            targetBuildingTemplateId = info.templateName
            targetBuildingPosition = info.position:ToVector3()
            targetBuildingRotation = info.rotation:ToVector3()
            targetBuildingAdjustMapHeight = info.adjustMapHeight
            if info.subIndex >= 0 then
                subBuildingInfo = {
                    subIndex = info.subIndex,
                    position = info.subPosition:ToVector3(),
                    rotation = info.subRotation:ToVector3(),
                    dist = info.subDist,
                }
            end
        end
    else
        foundBuilding, targetBuildingNodeId, targetBuildingTemplateId, targetBuildingPosition,
                targetBuildingRotation, targetBuildingAdjustMapHeight, subBuildingInfo, csOverlappingNodeIds
            = CSFactoryUtil.GetShouldInteractFacEntity(
                LuaSystemManager.factory.inDestroyMode,
                ctx.maxDist,
                ctx.maxAngle,
                ctx.playerPos,
                ctx.playerForward,
                ctx.isClickMode,
                ctx.isClickMode
            )
    end

    
    if csOverlappingNodeIds and csOverlappingNodeIds.Count > 0 then
        for i = 0, csOverlappingNodeIds.Count - 1 do
            output.overlapBuildings[#output.overlapBuildings + 1] = csOverlappingNodeIds[i]
        end
    end

    local buildingPendingSlotId = foundBuilding
            and CSFactoryUtil.GetBlueprintSlotId(ctx.chapterId, targetBuildingNodeId) or 0
    ctx.buildingPendingSlotId = buildingPendingSlotId

    if foundBuilding
            and not hasUsableNodeHandler(
                targetBuildingNodeId, targetBuildingChapterId or ctx.chapterId, buildingPendingSlotId) then
        foundBuilding = false
    end

    if foundBuilding then
        local target = self.m_buildingTarget
        local isBuilding = Tables.factoryBuildingTable:TryGetValue(targetBuildingTemplateId)
        target.type = isBuilding
                and FacConst.FAC_INTERACT_TARGET_TYPE.Building
                or FacConst.FAC_INTERACT_TARGET_TYPE.Logistic
        target.nodeId = targetBuildingNodeId
        target.chapterId = targetBuildingChapterId
        target.templateId = targetBuildingTemplateId
        target.position = targetBuildingPosition
        target.rotation = targetBuildingRotation
        target.adjustMapHeight = targetBuildingAdjustMapHeight
        target.subBuildingInfo = subBuildingInfo
        target.pendingSlotId = buildingPendingSlotId
        output.building = target
        table.insert(output.targets, target)

        if string.isEmpty(targetBuildingTemplateId) then
            local purpose = ctx.input and ctx.input.purpose
            local purposeName = purpose == FacConst.FAC_INTERACT_TARGET_PURPOSE.Click and "Click"
                    or (purpose == FacConst.FAC_INTERACT_TARGET_PURPOSE.Rect and "Rect" or "Preview")
            logger.error("[FacInteract][NoLogisticData]",
                "detect=" .. (ctx.useAsyncRst and "AsyncRst" or "SyncGetShouldInteract"),
                "view=" .. (ctx.isClickMode and "TopView" or "RPG"),
                "purpose=" .. purposeName,
                "destroy=" .. tostring(LuaSystemManager.factory.inDestroyMode),
                "templateId=" .. (targetBuildingTemplateId == nil and "<nil>" or "<empty>")
            )
        end
    end
end

FacInteractTargetDetector._SampleLogisticUnit = HL.Method(HL.Table, HL.Boolean).Return(HL.Table)
        << function(self, ctx, isBelt)
    local sampleType = isBelt and FacConst.FAC_SAMPLE_TYPE.Belt or FacConst.FAC_SAMPLE_TYPE.Pipe
    local excludeMode = isBelt
            and FacConst.SIMPLE_FIGURE_MODE.SimpleBeltFigure
            or FacConst.SIMPLE_FIGURE_MODE.SimplePipeFigure

    if ctx.isClickMode then
        if LuaSystemManager.factory:GetSimpleFigureModeFromRenderer() == excludeMode then
            return { success = false }
        end
        local beltPos = GameInstance.remoteFactoryManager.visual:WorldToBeltGrid(ctx.gridSampleWorldPos)
        local gridUnit = self:_GetGridUnitFromWorldPos(beltPos, sampleType)
        if not gridUnit.success then
            return { success = false }
        end
        return {
            success = true,
            nodeId = gridUnit.nodeId,
            unitIndex = gridUnit.unitIndex,
            unitTemplateId = gridUnit.unitTemplateId,
            gridPos = Unity.Vector2Int(lume.round(beltPos.x), lume.round(beltPos.y)),
        }
    end

    local success, nodeId, unitIndex, gridPos, chapterId
    if ctx.useAsyncRst then
        
        local valid, info = CSFactoryUtil.GetShouldInteractLogisticUsingAsyncRst(isBelt)
        success = valid and info.valid and info.nodeId > 0
        if success then
            nodeId = info.nodeId
            unitIndex = info.uintIndex
            gridPos = Unity.Vector2Int(math.floor(info.position.x), math.floor(info.position.z))
            chapterId = info.chapterId
        end
    else
        success, gridPos, nodeId, unitIndex = CSFactoryUtil.GetShouldInteractLogistic(
            isBelt, LuaSystemManager.factory.inDestroyMode, true
        )
    end

    return {
        success = success,
        nodeId = nodeId,
        unitIndex = unitIndex,
        gridPos = gridPos,
        chapterId = chapterId,
    }
end


FacInteractTargetDetector._ResolvePipeShowDelay = HL.Method(HL.Table, HL.Number).Return(HL.Boolean)
        << function(self, sample, pipeOptionDelay)
    if not sample.success then
        self.m_delayedPipeNodeInfo = nil
        return false
    end

    if LuaSystemManager.factory.inDestroyMode then
        return true
    end

    
    local shouldShow, shouldUpdateInfo = false, true
    if self.m_delayedPipeNodeInfo then
        if self.m_delayedPipeNodeInfo.nodeId == sample.nodeId
                and self.m_delayedPipeNodeInfo.unitIndex == sample.unitIndex then
            shouldUpdateInfo = false
            shouldShow = Time.unscaledTime >= self.m_delayedPipeNodeInfo.delayEndTime
        end
    end

    if shouldShow then
        return true
    end
    if shouldUpdateInfo then
        self.m_delayedPipeNodeInfo = {
            nodeId = sample.nodeId,
            unitIndex = sample.unitIndex,
            delayEndTime = Time.unscaledTime + pipeOptionDelay,
        }
    end
    return false
end

FacInteractTargetDetector._ShouldSuppressPendingSlot = HL.Method(HL.Number, HL.Boolean, HL.Table).Return(HL.Boolean)
        << function(self, pendingSlotId, isClickMode, conflictPendingSlotIds)
    if pendingSlotId <= 0 then
        return false
    end
    
    if LuaSystemManager.factory.inDestroyMode and not isClickMode then
        return true
    end
    for _, conflictId in ipairs(conflictPendingSlotIds) do
        if pendingSlotId == conflictId then
            return true
        end
    end
    return false
end

FacInteractTargetDetector._DetectPointPipe = HL.Method(HL.Table, HL.Table)
        << function(self, ctx, output)
    local sample = self:_SampleLogisticUnit(ctx, false)

    local showPipe = sample.success
    if not ctx.isClickMode then
        showPipe = self:_ResolvePipeShowDelay(sample, ctx.input.pipeOptionDelay)
    end

    local pipeNodeId = showPipe and sample.nodeId or nil
    local pipePendingSlotId = pipeNodeId
            and CSFactoryUtil.GetBlueprintSlotId(ctx.chapterId, pipeNodeId) or 0

    if self:_ShouldSuppressPendingSlot(pipePendingSlotId, ctx.isClickMode, { ctx.buildingPendingSlotId }) then
        
        pipeNodeId = nil
        pipePendingSlotId = 0
    end

    if pipeNodeId and not hasUsableNodeHandler(pipeNodeId, sample.chapterId or ctx.chapterId, pipePendingSlotId) then
        pipeNodeId = nil
    end

    ctx.pipePendingSlotId = pipePendingSlotId

    if pipeNodeId then
        local target = self.m_pipeTarget
        target.type = FacConst.FAC_INTERACT_TARGET_TYPE.Pipe
        target.nodeId = pipeNodeId
        target.chapterId = sample.chapterId
        target.unitIndex = sample.unitIndex
        target.unitTemplateId = sample.unitTemplateId
        target.gridPos = sample.gridPos
        target.pendingSlotId = pipePendingSlotId
        output.pipe = target
        table.insert(output.targets, target)
    end
end

FacInteractTargetDetector._DetectPointBelt = HL.Method(HL.Table, HL.Table)
        << function(self, ctx, output)
    local sample = self:_SampleLogisticUnit(ctx, true)

    local beltPendingSlotId = sample.success
            and CSFactoryUtil.GetBlueprintSlotId(ctx.chapterId, sample.nodeId) or 0

    if sample.success and self:_ShouldSuppressPendingSlot(
            beltPendingSlotId,
            ctx.isClickMode,
            { ctx.buildingPendingSlotId, ctx.pipePendingSlotId }
    ) then
        
        sample.success = false
        beltPendingSlotId = 0
    end

    if sample.success
            and not hasUsableNodeHandler(sample.nodeId, sample.chapterId or ctx.chapterId, beltPendingSlotId) then
        sample.success = false
    end

    if sample.success then
        local target = self.m_beltTarget
        target.type = FacConst.FAC_INTERACT_TARGET_TYPE.Belt
        target.nodeId = sample.nodeId
        target.chapterId = sample.chapterId
        target.unitIndex = sample.unitIndex
        target.unitTemplateId = sample.unitTemplateId
        target.logisticPos = sample.gridPos
        target.pendingSlotId = beltPendingSlotId
        output.belt = target
        table.insert(output.targets, target)
    end
end

FacInteractTargetDetector.DetectPoint = HL.Method(HL.Table).Return(HL.Table) << function(self, input)
    
    local output = self:_ResetOutput(self.m_pointOutput)
    local ctx = self:_BuildPointDetectContext(input)
    self:_DetectPointBuilding(ctx, output)
    self:_DetectPointPipe(ctx, output)
    self:_DetectPointBelt(ctx, output)
    output.primaryTarget = output.pipe or output.building or output.belt
    return output
end

FacInteractTargetDetector.DetectRect = HL.Method(HL.Table).Return(HL.Table) << function(self, input)
    local output = self:_ResetOutput(self.m_rectOutput)
    local rect = input.rect
    if not rect then
        return output
    end
    local excludeBelt, excludePipe = LuaSystemManager.factory:GetSimpleFigureExcludeBeltPipeForBatchSelect()
    local targetNodeIds, beltInfos = CSFactoryUtil.GetFacEntityInRect(
        LuaSystemManager.factory.inDestroyMode,
        rect.startWorldPos,
        rect.endWorldPos,
        excludeBelt,
        excludePipe,
        true,
        Utils.isInBlackbox(),
        true
    )
    for _, nodeId in pairs(targetNodeIds) do
        if not FactoryUtils.isInvalidBuilding(nodeId) then
            output.targetMap[nodeId] = true
        end
    end
    for nodeId, unitIndices in pairs(beltInfos) do
        if not FactoryUtils.isInvalidBuilding(nodeId) then
            output.targetMap[nodeId] = Utils.csList2Table(unitIndices)
        end
    end
    return output
end


HL.Commit(FacInteractTargetDetector)
