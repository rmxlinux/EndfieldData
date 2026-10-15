local handlerBase = require_ex('UI/Panels/FacBuildingInteract/Runtime/FacInteractHandlerBase')



local INVALID_INTERACT_BUILDING_LIST = {
    ["log_pipe_repeater_1"] = true,
}


FacInteractNormalHandler = HL.Class('FacInteractNormalHandler', handlerBase.FacInteractHandlerBase)

FacInteractNormalHandler.m_clickTargets = HL.Field(HL.Table) << function() return {} end

FacInteractNormalHandler.FacInteractNormalHandler = HL.Constructor(HL.Forward('FacInteractSystem')) << function(self, host)
    FacInteractNormalHandler.SuperConstructor(self, host)
end

FacInteractNormalHandler.BuildPresentationModel = HL.Override(HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output)
    local isTopView = input.viewMode == FacConst.FAC_INTERACT_TARGET_VIEW_MODE.TopView
    return self:_BuildCommonPresentation(input, output, {
        showOptions = not isTopView,
        isTopView = isTopView,
        destroyMode = false,
        allowSubBuilding = true,
        controllerEmptyGrid = isTopView and DeviceInfo.usingController,
        suppressWorldEffects = isTopView and DeviceInfo.usingTouch,
        useAsyncRst = not isTopView,
    })
end

FacInteractNormalHandler.OnTick = HL.Override() << function(self)
    if LuaSystemManager.factory.inTopView and DeviceInfo.usingTouch then
        
        return
    end
    local input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview)
    self:_PublishTargetOutput(input, output)
end

FacInteractNormalHandler.OnClick = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end

    Notify(MessageConst.FAC_TOPVIEW_HIDE_MULTI_TARGET_MENU)
    local input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Click, eventData)
    local model = self:_PublishTargetOutput(input, output)
    local targets = self:_CollectClickTargets(input, output, model.resolvedTargetSet)
    if #targets == 0 then
        self.m_host:ClearInteractPresentation()
    elseif #targets == 1 then
        self.m_host:ExecuteInteract(targets[1].option)
        self.m_host:ClearInteractPresentation()
    else
        self.m_host:PublishMultiTarget({
            targets = targets,
        })
    end
end

FacInteractNormalHandler._CollectClickTargets = HL.Method(HL.Table, HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output, resolvedTargetSet)
    local targets = self.m_clickTargets
    for i = #targets, 1, -1 do
        targets[i] = nil
    end
    local seenPendingSlotIds = {}
    local detectPos = input.worldPos
    local chapterId = Utils.getCurrentChapterId()

    local pipe = resolvedTargetSet.pipe
    if pipe then
        local pipePendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, pipe.nodeId)
        local isPendingPipe = pipePendingSlotId > 0
        if not isPendingPipe or not seenPendingSlotIds[pipePendingSlotId] then
            if isPendingPipe then
                seenPendingSlotIds[pipePendingSlotId] = true
            end
            local height = CSFactoryUtil.GetPipeUnitHeight(pipe.nodeId, pipe.unitIndex)
            table.insert(targets, {
                type = FacConst.FAC_INTERACT_TARGET_TYPE.Pipe,
                name = isPendingPipe and FactoryUtils.getPendingSlotName(pipePendingSlotId) or Language.LUA_FAC_PIPE_INTERACT_OPTION,
                effectInfo = {
                    nodeId = pipe.nodeId,
                    unitIndex = pipe.unitIndex,
                    worldPos = Vector3(pipe.gridPos.x + 0.5, height, pipe.gridPos.y + 0.5),
                },
                option = {
                    nodeId = pipe.nodeId,
                    unitIndex = pipe.unitIndex,
                },
            })
        end
    end

    
    
    
    for _, overlap in ipairs(resolvedTargetSet.overlapBuildings) do
        local overlapNodeId = overlap.nodeId
        local overlapPendingSlotId = overlap.pendingSlotId
        local isOverlapPending = overlapPendingSlotId > 0
        if isOverlapPending then
            if not seenPendingSlotIds[overlapPendingSlotId] then
                seenPendingSlotIds[overlapPendingSlotId] = true
                table.insert(targets, {
                    type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                    name = FactoryUtils.getPendingSlotName(overlapPendingSlotId),
                    effectInfo = {
                        worldPos = detectPos,
                    },
                    option = { buildingNodeId = overlapNodeId },
                })
            end
        else
            local handler = FactoryUtils.getBuildingNodeHandler(overlapNodeId)
            if handler then
                local isBuilding = overlap.targetType == FacConst.FAC_INTERACT_TARGET_TYPE.Building
                local targetName
                if isBuilding then
                    targetName = Tables.factoryBuildingTable[overlap.templateId].name
                else
                    local unitData = FactoryUtils.getLogisticData(overlap.templateId)
                    targetName = unitData and unitData.name
                end
                if targetName then
                    local effectWorldPos = CSFactoryUtil.GetBuildingModelPosition(handler)
                    table.insert(targets, {
                        type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                        name = targetName,
                        effectInfo = {
                            worldPos = effectWorldPos,
                        },
                        option = overlap.option,
                    })
                end
            end
        end
    end

    local building = resolvedTargetSet.building
    if building then
        local buildingPendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, building.nodeId)
        local isPendingBuilding = buildingPendingSlotId > 0
        if isPendingBuilding then
            
            if not seenPendingSlotIds[buildingPendingSlotId] then
                seenPendingSlotIds[buildingPendingSlotId] = true
                table.insert(targets, {
                    type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                    name = FactoryUtils.getPendingSlotName(buildingPendingSlotId),
                    effectInfo = {
                        worldPos = detectPos,
                    },
                    option = { buildingNodeId = building.nodeId },
                })
            end
        else
            
            local isBuilding = building.targetType == FacConst.FAC_INTERACT_TARGET_TYPE.Building
            local subIndex = building.subBuildingIndex
            local handler = FactoryUtils.getBuildingNodeHandler(building.nodeId)
            local effectWorldPos = CSFactoryUtil.GetBuildingModelPosition(handler)
            local targetName
            if isBuilding then
                if subIndex and subIndex >= 0 then
                    targetName = Language.LUA_FAC_HUB_INPUT .. subIndex
                else
                    local buildingData = Tables.factoryBuildingTable[handler.templateId]
                    targetName = buildingData.name
                end
            else
                local unitData = FactoryUtils.getLogisticData(handler.templateId)
                targetName = unitData.name
            end
            table.insert(targets, {
                type = FacConst.FAC_INTERACT_TARGET_TYPE.Building,
                name = targetName,
                effectInfo = {
                    worldPos = effectWorldPos,
                },
                option = isBuilding
                        and { buildingNodeId = building.nodeId, subBuildingIndex = subIndex }
                        or { nodeId = building.nodeId },
            })
        end
    end

    local belt = resolvedTargetSet.belt
    if belt then
        local beltPendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, belt.nodeId)
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
                local handler = chapterInfo:GetNode(belt.nodeId)
                beltName = Tables.factoryGridBeltTable:GetValue(handler.templateId).beltData.name
            end
            local unitHeight = FactoryUtils.queryVoxelRangeHeightAdjust(
                belt.logisticPos.x, CSFactoryUtil.GetBeltHeight(belt.nodeId), belt.logisticPos.y
            )
            table.insert(targets, {
                type = FacConst.FAC_INTERACT_TARGET_TYPE.Belt,
                name = beltName,
                effectInfo = {
                    worldPos = Vector3(belt.logisticPos.x + 0.5, unitHeight, belt.logisticPos.y + 0.5),
                },
                option = {
                    nodeId = belt.nodeId,
                    unitIndex = belt.unitIndex,
                    logisticPos = belt.logisticPos,
                },
            })
        end
    end
    return targets
end

FacInteractNormalHandler.OnLongPress = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    local output = self.m_host:GetCurrentTargetOutput()
    if DeviceInfo.usingTouch then
        local input
        input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Click, eventData)
        self:_PublishTargetOutput(input, output)
    end
    local building = output and output.building 
    if not building or building.type ~= FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        return
    end
    
    if FactoryUtils.canMoveBuilding(building.nodeId, true) then
        local args = { nodeId = building.nodeId }
        if DeviceInfo.usingTouch then
            
            
            args.triggerPressScreen = true
        end
        Notify(MessageConst.FAC_ENTER_BUILDING_MODE, args)
    end
end

FacInteractNormalHandler.OnDragBegin = HL.Override(HL.Any, HL.Opt(HL.Boolean)) << function(self, pos, fromController)
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
end

FacInteractNormalHandler.OnDragEnd = HL.Override(HL.Opt(HL.Any)) << function(self, pos)
end

FacInteractNormalHandler.OnPress = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    local output = self.m_host:GetCurrentTargetOutput()
    if DeviceInfo.usingTouch then 
        local input
        input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Click, eventData)
        self:_PublishTargetOutput(input, output)
    end
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    local building = output and output.building
    
    if not building or building.type ~= FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        return
    end
    if not FactoryUtils.canMoveBuilding(building.nodeId) then
        return
    end
    self.m_host:PublishPressHint({
        op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Start,
        isLongPressToDragHint = false,
    })
end

FacInteractNormalHandler.OnRelease = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    if DeviceInfo.usingTouch then
        self.m_host:ClearInteractPresentation()
    end
end

FacInteractNormalHandler.ExecuteInteract = HL.Override(HL.Table) << function(self, option)
    local buildingNodeId = option.buildingNodeId
    if not string.isEmpty(buildingNodeId) then
        
        local curChapter = FactoryUtils.getCurChapterInfo()
        local node = curChapter:GetNode(buildingNodeId)
        local preventOpen = false
        if node and node.nodeType == GEnums.FCNodeType.SubHub:GetHashCode() and not node.power.inPower then
            preventOpen = true
            Notify(MessageConst.SHOW_TOAST, Language.lang_int_jumpmachine_toast)
        end
        if not preventOpen then
            if not option.subBuildingIndex or option.subBuildingIndex == -1 then
                Notify(MessageConst.FAC_OPEN_BUILDING_PANEL, {
                    nodeId = buildingNodeId,
                })
            else
                local onlyValidHubUnloaderIndex = self.m_host:GetOnlyValidHubUnloaderIndex()
                if onlyValidHubUnloaderIndex > 0
                        and option.subBuildingIndex ~= onlyValidHubUnloaderIndex then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_HUB_UNLOADER_BLOCKED)
                    return
                end
                Notify(MessageConst.FAC_OPEN_BUILDING_PANEL, {
                    nodeId = buildingNodeId,
                    customArg = { subIndex = option.subBuildingIndex },
                    panelBuildingDataId = "unloader_1",
                }) 
            end
        end
    end

    local nodeId = option.nodeId
    if nodeId then
        
        if FactoryUtils.isPendingBuildingNode(nodeId) then
            Notify(MessageConst.FAC_OPEN_LOGISTIC_PANEL, { nodeId = nodeId, index = option.unitIndex })
        else
            local nodeHandler = FactoryUtils.getBuildingNodeHandler(nodeId)
            if nodeHandler ~= nil and not INVALID_INTERACT_BUILDING_LIST[nodeHandler.templateId] then
                Notify(MessageConst.FAC_OPEN_LOGISTIC_PANEL, { nodeId = nodeId, index = option.unitIndex })
            end
        end
    end
end


HL.Commit(FacInteractNormalHandler)
