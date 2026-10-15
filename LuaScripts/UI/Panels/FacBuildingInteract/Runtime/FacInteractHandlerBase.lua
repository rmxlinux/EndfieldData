









































































































local function clearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end


local function appendDebugSuffix(text, chapterId, nodeId)
    if chapterId == nil or not CS.Beyond.Gameplay.Factory.BuildingName.s_showDebugNodeId then
        return text
    end
    return text .. " (ch:" .. chapterId .. ", nid:" .. nodeId .. ")"
end


local function isUdPipeConnected(nodeId)
    local nodeHandler = FactoryUtils.getBuildingNodeHandler(nodeId)
    if nodeHandler == nil then
        return false
    end
    local cpt = nodeHandler:GetComponentInPosition(GEnums.FCComponentPos.FluidUdPipe:GetHashCode())
    return cpt ~= nil and cpt.valid and cpt.udPipe.connectComponent ~= nil
end



local function copyResolvedTarget(source, target)
    clearTable(target)
    if not source then
        return nil
    end
    target.targetType = source.type
    target.nodeId = source.nodeId
    target.templateId = source.templateId or source.unitTemplateId
    target.chapterId = source.chapterId
    target.unitIndex = source.unitIndex
    target.logisticPos = source.logisticPos
    target.gridPos = source.gridPos
    target.subBuildingIndex = -1
    target.pendingSlotId = source.pendingSlotId or 0
    if source.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        target.option = { buildingNodeId = source.nodeId }
    else
        target.option = {
            nodeId = source.nodeId,
            unitIndex = source.unitIndex,
            logisticPos = source.logisticPos,
        }
    end
    return target
end


local function fillHighlight(target, identity, position, offsetY, rotation, scale)
    clearTable(target)
    target.identity = identity
    target.position = position
    target.offsetY = offsetY or 0
    target.rotation = rotation
    target.scale = scale
    target.useCone = false
    return target
end

FacInteractHandlerBase = HL.Class('FacInteractHandlerBase')


FacInteractHandlerBase.m_host = HL.Field(HL.Forward('FacInteractSystem'))

FacInteractHandlerBase.m_args = HL.Field(HL.Table)

FacInteractHandlerBase.m_interactPresentationModel = HL.Field(HL.Table) << function()
    return {
        resolvedTargetSet = {
            overlapBuildings = {},
            _building = {},
            _pipe = {},
            _belt = {},
        },
        scene = {
            pendingSlotIds = {},
            _building = {},
            _subBuilding = {},
            _pipe = {},
            _belt = {},
            _controllerEmptyGrid = {},
        },
        options = {},
    }
end

FacInteractHandlerBase.m_lastApproachBuildingNodeId = HL.Field(HL.Any)

FacInteractHandlerBase.m_lastApproachIdentity = HL.Field(HL.Any)

FacInteractHandlerBase.m_lastSocialBuildingNodeId = HL.Field(HL.Any)

FacInteractHandlerBase.m_cachedXLoaderNodeId = HL.Field(HL.Any)

FacInteractHandlerBase.m_cachedXLoaderSubInfo = HL.Field(HL.Table)


FacInteractHandlerBase.FacInteractHandlerBase = HL.Constructor(HL.Forward('FacInteractSystem')) << function(self, host)
    self.m_host = host
end




FacInteractHandlerBase.OnEnter = HL.Virtual(HL.Table) << function(self, args)
    self.m_args = args
end


FacInteractHandlerBase.OnExit = HL.Virtual() << function(self)
    self:ClearPresentationState()
    self.m_args = nil
end


FacInteractHandlerBase.OnSuspend = HL.Virtual() << function(self)
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    self:ClearPresentationState()
end


FacInteractHandlerBase.OnResume = HL.Virtual() << function(self)
end








FacInteractHandlerBase.OnTick = HL.Virtual() << function(self)
end

FacInteractHandlerBase.OnClick = HL.Virtual(HL.Any) << function(self, eventData)
end

FacInteractHandlerBase.OnLongPress = HL.Virtual(HL.Any) << function(self, eventData)
end

FacInteractHandlerBase.OnDragBegin = HL.Virtual(HL.Any, HL.Opt(HL.Boolean)) << function(self, pos, fromController)
end

FacInteractHandlerBase.OnDrag = HL.Virtual(HL.Opt(HL.Any, HL.Boolean)) << function(self, eventData, fromController)
end

FacInteractHandlerBase.OnDragEnd = HL.Virtual(HL.Opt(HL.Any)) << function(self, pos)
end

FacInteractHandlerBase.OnPress = HL.Virtual(HL.Any) << function(self, eventData)
end

FacInteractHandlerBase.OnRelease = HL.Virtual(HL.Any) << function(self, eventData)
end


FacInteractHandlerBase.BuildPresentationModel = HL.Virtual(HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output)
    return self:_BuildCommonPresentation(input, output, {
        showOptions = false,
        isTopView = input.viewMode == FacConst.FAC_INTERACT_TARGET_VIEW_MODE.TopView,
        destroyMode = false,
        allowSubBuilding = false,
        controllerEmptyGrid = false,
        suppressWorldEffects = false,
    })
end


FacInteractHandlerBase._PublishTargetOutput = HL.Method(HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output)
    local model = self:BuildPresentationModel(input, output)
    self.m_host:PublishInteractPresentation(model)
    return model
end


FacInteractHandlerBase._ResetPresentationModel = HL.Method(HL.Table).Return(HL.Table) << function(self, input)
    local model = self.m_interactPresentationModel
    model.forceUpdate = input.forceUpdate == true
    model.detectWorldPos = input.worldPos

    local targetSet = model.resolvedTargetSet
    targetSet.primary = nil
    targetSet.building = nil
    targetSet.pipe = nil
    targetSet.belt = nil
    for i = #targetSet.overlapBuildings, 1, -1 do
        targetSet.overlapBuildings[i] = nil
    end

    local scene = model.scene
    scene.building = nil
    scene.subBuilding = nil
    scene.pipe = nil
    scene.belt = nil
    scene.hover = nil
    scene.controllerEmptyGrid = nil
    scene.pipeSelection = nil
    scene.suppressWorldEffects = false
    clearTable(scene.pendingSlotIds)
    clearTable(model.options)
    return model
end


FacInteractHandlerBase._AddOption = HL.Method(HL.Table, HL.String, HL.Table, HL.String, HL.Opt(HL.Boolean, HL.Boolean))
        << function(self, model, sourceId, args, identity, updateEveryFrame, setTopWhenIdentityChanged)
    args.type = CS.Beyond.Gameplay.Core.InteractOptionType.Factory
    args.sourceId = sourceId
    model.options[sourceId] = {
        identity = identity,
        args = args,
        updateEveryFrame = updateEveryFrame == true,
        setTopWhenIdentityChanged = setTopWhenIdentityChanged == true,
    }
end


FacInteractHandlerBase._BuildCommonPresentation = HL.Method(HL.Table, HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output, policy)
    local model = self:_ResetPresentationModel(input)
    local targetSet = model.resolvedTargetSet
    local scene = model.scene
    local isTopView = policy.isTopView == true
    scene.suppressWorldEffects = policy.suppressWorldEffects == true

    
    if isTopView and DeviceInfo.usingKeyboard and not UIManager.commonTouchPanel.isPointerEntered then
        self:_SyncBuildingApproach(nil, nil)
        return model
    end

    local chapterId = Utils.getCurrentChapterId()
    
    local building = copyResolvedTarget(output.building, targetSet._building)
    local buildingData
    local isBuilding = false
    local isHub = false
    local isXLoader = false
    local isUdPipe = false
    local subKind
    local subNodeId
    local subTemplateId
    local subPosition
    local subRotation
    local subScale
    local subOffsetY
    if building then
        targetSet.building = building
        isBuilding, buildingData = Tables.factoryBuildingTable:TryGetValue(building.templateId)
        building.targetType = isBuilding
                and FacConst.FAC_INTERACT_TARGET_TYPE.Building
                or FacConst.FAC_INTERACT_TARGET_TYPE.Logistic
        building.option = isBuilding
                and { buildingNodeId = building.nodeId }
                or { nodeId = building.nodeId }
        isHub = isBuilding and (buildingData.type == GEnums.FacBuildingType.Hub
                or buildingData.type == GEnums.FacBuildingType.SubHub)
        isXLoader = isBuilding and (buildingData.type == GEnums.FacBuildingType.Loader
                or buildingData.type == GEnums.FacBuildingType.Unloader)
        isUdPipe = isBuilding and (buildingData.type == GEnums.FacBuildingType.UdPipeLoader
                or buildingData.type == GEnums.FacBuildingType.UdPipeUnloader)

        if policy.allowSubBuilding and building.pendingSlotId == 0 and isBuilding then
            local subBuildingInfo = output.building.subBuildingInfo
            if isHub and subBuildingInfo
                    and GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPort then
                local maxDist = isTopView and 1 or input.subBuildingSetTopDist
                if subBuildingInfo.dist <= maxDist then
                    building.subBuildingIndex = LuaIndex(subBuildingInfo.subIndex)
                    subKind = FacConst.FAC_INTERACT_SUB_KIND.Hub
                    subPosition = subBuildingInfo.position
                    subRotation = Vector3(
                        subBuildingInfo.rotation.x,
                        subBuildingInfo.rotation.y,
                        subBuildingInfo.rotation.z
                    )
                    subScale = Vector3.one
                end
            elseif isXLoader and not isTopView then
                if self.m_cachedXLoaderNodeId ~= building.nodeId then
                    self.m_cachedXLoaderNodeId = building.nodeId
                    self.m_cachedXLoaderSubInfo = { valid = false }
                    local cptPos = buildingData.type == GEnums.FacBuildingType.Loader
                            and GEnums.FCComponentPos.BusLoader or GEnums.FCComponentPos.Selector
                    local syncNode = FactoryUtils.getBuildingNodeHandler(building.nodeId)
                    local cpt = syncNode:GetComponentInPosition(cptPos:GetHashCode())
                    local attachedBus = cpt and (buildingData.type == GEnums.FacBuildingType.Loader
                            and cpt.busLoader.attachedBus or cpt.selector.attachedBus)
                    if attachedBus and attachedBus.Count > 0 then
                        local busNode = attachedBus[0]
                        local succ, busData = Tables.factoryBuildingTable:TryGetValue(busNode.templateId)
                        if succ then
                            local busPosition = busNode.transform.worldPosition
                            local adjustHeight = FactoryUtils.queryVoxelRangeHeightAdjust(
                                busPosition.x, busPosition.y, busPosition.z
                            )
                            self.m_cachedXLoaderSubInfo = {
                                valid = true,
                                nodeId = busNode.nodeId,
                                templateId = busNode.templateId,
                                position = Vector3(busPosition.x, adjustHeight, busPosition.z),
                                rotation = busNode.transform.worldRotation,
                                scale = Vector3(busData.range.width, 1, busData.range.depth),
                                offsetY = FacConst.BUILDING_SELECT_EFFECT_OFFSET[busData.type],
                            }
                        end
                    end
                end
                local cachedSubInfo = self.m_cachedXLoaderSubInfo
                if cachedSubInfo and cachedSubInfo.valid then
                    building.subBuildingIndex = 1
                    subKind = FacConst.FAC_INTERACT_SUB_KIND.Loader
                    subNodeId = cachedSubInfo.nodeId
                    subTemplateId = cachedSubInfo.templateId
                    subPosition = cachedSubInfo.position
                    subRotation = cachedSubInfo.rotation
                    subScale = cachedSubInfo.scale
                    subOffsetY = cachedSubInfo.offsetY
                end
            end
        end
        if not isXLoader then
            self.m_cachedXLoaderNodeId = nil
            self.m_cachedXLoaderSubInfo = nil
        end

        building.option.subBuildingIndex = building.subBuildingIndex
        local position = Vector3(
            output.building.position.x,
            output.building.adjustMapHeight,
            output.building.position.z
        )
        local xScale = buildingData and buildingData.range.width or 1
        local zScale = buildingData and buildingData.range.depth or 1
        local offsetY = FacConst.DEFAULT_BUILDING_SELECT_EFFECT_OFFSET
        if isBuilding and FacConst.BUILDING_SELECT_EFFECT_OFFSET[buildingData.type] ~= nil then
            offsetY = FacConst.BUILDING_SELECT_EFFECT_OFFSET[buildingData.type]
        end
        local highlight = fillHighlight(
            scene._building,
            "building:" .. building.nodeId,
            position,
            offsetY,
            output.building.rotation,
            Vector3(xScale, 1, zScale)
        )
        highlight.nodeId = building.nodeId
        highlight.useCone = FacConst.BUILDING_SELECT_EFFECT_USE_CONE_NODE_IDS[building.templateId] == true
        if highlight.useCone then
            local succ, terrainPos = CSFactoryUtil.SampleLevelRegionPointWithRay(
                CS.UnityEngine.Ray(position, Vector3.down)
            )
            highlight.terrainDistance = succ and (position.y - terrainPos.y) or 3
        end
        if isTopView then
            scene.hover = highlight
        else
            scene.building = highlight
        end

        if subKind then
            local subHighlight = fillHighlight(
                scene._subBuilding,
                "sub:" .. building.nodeId .. ":" .. building.subBuildingIndex,
                subPosition,
                subOffsetY or FacConst.DEFAULT_BUILDING_SELECT_EFFECT_OFFSET,
                subRotation,
                subScale
            )
            subHighlight.nodeId = subNodeId or building.nodeId
            subHighlight.templateId = subTemplateId or building.templateId
            subHighlight.subKind = subKind
            subHighlight.subBuildingIndex = building.subBuildingIndex
            if isTopView and isHub then
                scene.hover = subHighlight
            elseif not isTopView then
                scene.subBuilding = subHighlight
            end
        end
        if building.pendingSlotId > 0 then
            scene.pendingSlotIds[building.pendingSlotId] = true
        end
    else
        self.m_cachedXLoaderNodeId = nil
        self.m_cachedXLoaderSubInfo = nil
    end

    
    for _, overlapNodeId in ipairs(output.overlapBuildings) do
        local overlap = {}
        overlap.nodeId = overlapNodeId
        overlap.subBuildingIndex = -1
        overlap.pendingSlotId = CSFactoryUtil.GetBlueprintSlotId(chapterId, overlapNodeId)
        local overlapHandler = FactoryUtils.getBuildingNodeHandler(overlapNodeId)
        overlap.templateId = overlapHandler and overlapHandler.templateId
        local overlapIsBuilding = overlap.templateId
                and Tables.factoryBuildingTable:TryGetValue(overlap.templateId) or false
        overlap.targetType = overlapIsBuilding
                and FacConst.FAC_INTERACT_TARGET_TYPE.Building
                or FacConst.FAC_INTERACT_TARGET_TYPE.Logistic
        overlap.option = overlapIsBuilding
                and { buildingNodeId = overlapNodeId }
                or { nodeId = overlapNodeId }
        targetSet.overlapBuildings[#targetSet.overlapBuildings + 1] = overlap
    end

    local pipe = copyResolvedTarget(output.pipe, targetSet._pipe)
    if pipe then
        targetSet.pipe = pipe
        local height = CSFactoryUtil.GetPipeUnitHeight(pipe.nodeId, pipe.unitIndex)
        local worldPos = Vector3(output.pipe.gridPos.x + 0.5, height, output.pipe.gridPos.y + 0.5)
        local pipeHighlight = fillHighlight(
            scene._pipe,
            "pipe:" .. pipe.nodeId .. ":" .. pipe.unitIndex,
            worldPos,
            0
        )
        pipeHighlight.nodeId = pipe.nodeId
        pipeHighlight.unitIndex = pipe.unitIndex
        local succ, terrainPos = CSFactoryUtil.SampleLevelRegionPointWithRay(
            CS.UnityEngine.Ray(worldPos, Vector3.down)
        )
        pipeHighlight.terrainDistance = succ and (worldPos.y - terrainPos.y) or 3
        scene.pipeSelection = pipe
        if isTopView then
            scene.hover = pipeHighlight
        else
            scene.pipe = pipeHighlight
        end
        if pipe.pendingSlotId > 0 then
            scene.pendingSlotIds[pipe.pendingSlotId] = true
        end
    end

    local belt = copyResolvedTarget(output.belt, targetSet._belt)
    if belt then
        targetSet.belt = belt
        local unitHeight = FactoryUtils.queryVoxelRangeHeightAdjust(
            belt.logisticPos.x,
            CSFactoryUtil.GetBeltHeight(belt.nodeId),
            belt.logisticPos.y
        )
        local worldPos = Vector3(belt.logisticPos.x + 0.5, unitHeight, belt.logisticPos.y + 0.5)
        local beltHighlight = fillHighlight(
            scene._belt,
            "belt:" .. belt.nodeId .. ":" .. belt.unitIndex,
            worldPos,
            0.2
        )
        beltHighlight.nodeId = belt.nodeId
        beltHighlight.unitIndex = belt.unitIndex
        if isTopView then
            scene.hover = beltHighlight
        else
            scene.belt = beltHighlight
        end
        if belt.pendingSlotId > 0 then
            scene.pendingSlotIds[belt.pendingSlotId] = true
        end
    end

    if output.primaryTarget == output.pipe then
        targetSet.primary = pipe
    elseif output.primaryTarget == output.building then
        targetSet.primary = building
    elseif output.primaryTarget == output.belt then
        targetSet.primary = belt
    end

    
    if isTopView and policy.controllerEmptyGrid then
        local manager = GameInstance.remoteFactoryManager
        
        local curGridPos = manager.visual:WorldToVoxel(manager:ViewToLogical(input.playerPos))
        curGridPos = Vector3(
            math.floor(curGridPos.x) + 0.5,
            curGridPos.y,
            math.floor(curGridPos.z) + 0.5
        )
        scene.controllerEmptyGrid = curGridPos
        if not targetSet.primary then
            scene.hover = fillHighlight(
                scene._controllerEmptyGrid,
                "empty:" .. curGridPos.x .. ":" .. curGridPos.z,
                manager.visual:VoxelToWorld(curGridPos),
                0.2
            )
        end
    end

    if scene.suppressWorldEffects then
        scene.building = nil
        scene.subBuilding = nil
        scene.pipe = nil
        scene.belt = nil
        scene.hover = nil
        scene.pipeSelection = nil
    end

    
    if policy.showOptions then
        self:_BuildBuildingOptions(model, building, buildingData, isBuilding, isHub, isUdPipe, scene.subBuilding, policy)
        self:_BuildPipeOptions(model, pipe, policy)
        self:_BuildBeltOptions(model, belt, input, policy)
    end

    local approachNodeId
    local approachIdentity
    local socialNodeId
    if policy.showOptions and building and isBuilding
            and building.pendingSlotId == 0 and not FactoryUtils.isInvalidBuilding(building.nodeId) then
        approachNodeId = building.nodeId
        approachIdentity = building.nodeId .. ":"
                .. tostring(CSFactoryUtil.ShouldShowBuildingUIInteractOption(building.nodeId))
        if not policy.destroyMode and FactoryUtils.isOthersSocialBuilding(building.nodeId) then
            socialNodeId = building.nodeId
        end
    end
    self:_SyncBuildingApproach(approachNodeId, socialNodeId, approachIdentity, model.forceUpdate)
    return model
end


FacInteractHandlerBase._BuildBuildingOptions = HL.Method(
    HL.Table, HL.Any, HL.Any, HL.Boolean, HL.Boolean, HL.Boolean, HL.Any, HL.Table
) << function(self, model, building, buildingData, isBuilding, isHub, isUdPipe, subScene, policy)
    if not building then
        return
    end
    local nodeId = building.nodeId
    local isPending = building.pendingSlotId > 0
    local isInvalid = FactoryUtils.isInvalidBuilding(nodeId)
    local useDefaultOption = isPending or CSFactoryUtil.ShouldShowBuildingUIInteractOption(nodeId)
    local args = {
        sortId = 200,
        buildingNodeId = nodeId,
        templateId = building.templateId,
        icon = policy.destroyMode
                and (FactoryUtils.isOthersSocialBuilding(nodeId)
                    and FacConst.FAC_INTERACT_ICON.DeleteSocial or FacConst.FAC_INTERACT_ICON.Delete)
                or (isInvalid and FacConst.FAC_INTERACT_ICON.Delete or FacConst.FAC_INTERACT_ICON.Common),
        isDel = isInvalid or policy.destroyMode,
    }
    if isPending then
        args.text = FactoryUtils.getPendingSlotName(building.pendingSlotId)
        args.action = function()
            self.m_host:ExecuteInteract({ buildingNodeId = nodeId })
        end
    elseif isInvalid then
        local name = isBuilding and buildingData.name
                or FactoryUtils.getLogisticData(building.templateId).name
        args.text = string.format(Language.LUA_FACTORY_INVALID_BUILDING_INTERACT, name)
        args.action = function()
            FactoryUtils.delBuilding(nodeId)
        end
    elseif isBuilding then
        args.text = buildingData.name
        if isUdPipe and not policy.destroyMode and isUdPipeConnected(nodeId) then
            args.text = string.format(Language.LUA_FAC_UDPIPE_INTERACT_CONNECTED, buildingData.name)
        end
        args.action = function()
            self.m_host:ExecuteInteract({ buildingNodeId = nodeId })
        end
        if not policy.destroyMode then
            args.longPressAction = function()
                if FactoryUtils.canMoveBuilding(nodeId, true) then
                    Notify(MessageConst.FAC_ENTER_BUILDING_MODE, { nodeId = nodeId })
                else
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FACTORY_BUILDING_MOVE_NOT_ALLOWED)
                end
            end
        end
    else
        local unitData = FactoryUtils.getLogisticData(building.templateId)
        args.text = unitData.name
        args.action = function()
            self.m_host:ExecuteInteract({ nodeId = nodeId })
        end
    end
    if policy.useAsyncRst then
        args.text = appendDebugSuffix(args.text, building.chapterId, nodeId)
    end

    local visible = useDefaultOption
    if isHub and not Utils.isSystemUnlocked(GEnums.UnlockSystemType.FacHub) then
        visible = false
    elseif not useDefaultOption and policy.destroyMode then
        visible = CSFactoryUtil.IsSoil(nodeId)
    end
    if visible then
        self:_AddOption(
            model,
            FacConst.FAC_INTERACT_OPTION_SOURCE_ID.MainBuilding,
            args,
            nodeId .. ":" .. tostring(useDefaultOption) .. ":" .. tostring(args.text)
        )
    end

    if not subScene then
        return
    end
    local subArgs = {
        templateId = subScene.templateId,
        buildingNodeId = subScene.nodeId,
        subBuildingIndex = subScene.subBuildingIndex,
    }
    if subScene.subKind == FacConst.FAC_INTERACT_SUB_KIND.Hub then
        local subBuildingIndex = subScene.subBuildingIndex
        subArgs.sortId = GameWorld.gameMechManager.linkWireBrain.isLinking and 100 or -100
        subArgs.needReSort = true
        local inputName = I18nUtils.CombineStringWithLanguageSpilt(
            Language.LUA_FAC_HUB_INPUT, subBuildingIndex
        )
        subArgs.text = string.format("<color=#fff100>%s</color>", inputName)
        if policy.useAsyncRst then
            subArgs.text = appendDebugSuffix(subArgs.text, building.chapterId, nodeId)
        end
        subArgs.icon = FacConst.FAC_INTERACT_ICON.HubPort
        subArgs.action = function()
            self.m_host:ExecuteInteract({
                buildingNodeId = nodeId,
                subBuildingIndex = subBuildingIndex,
            })
        end
        self:_AddOption(
            model,
            FacConst.FAC_INTERACT_OPTION_SOURCE_ID.SubBuilding,
            subArgs,
            nodeId .. ":" .. subBuildingIndex,
            true,
            true
        )
    elseif subScene.subKind == FacConst.FAC_INTERACT_SUB_KIND.Loader then
        local capturedSubNodeId = subScene.nodeId
        local capturedSubTemplateId = subScene.templateId
        subArgs.sortId = 300
        subArgs.needReSort = true
        subArgs.text = Tables.factoryBuildingTable[capturedSubTemplateId].name
        if policy.useAsyncRst then
            subArgs.text = appendDebugSuffix(subArgs.text, building.chapterId, nodeId)
        end
        subArgs.action = function()
            self.m_host:ExecuteInteract({ buildingNodeId = capturedSubNodeId })
        end
        self:_AddOption(
            model,
            FacConst.FAC_INTERACT_OPTION_SOURCE_ID.SubBuilding,
            subArgs,
            capturedSubNodeId .. ":" .. capturedSubTemplateId
        )
    end
end


FacInteractHandlerBase._BuildPipeOptions = HL.Method(HL.Table, HL.Any, HL.Table)
        << function(self, model, pipe, policy)
    if not pipe then
        return
    end
    local nodeId = pipe.nodeId
    local unitIndex = pipe.unitIndex
    local templateId = pipe.templateId
    local isInvalid = FactoryUtils.isInvalidBuilding(nodeId)
    local args = {
        templateId = templateId,
        isDel = policy.destroyMode or isInvalid,
        text = pipe.pendingSlotId > 0 and FactoryUtils.getPendingSlotName(pipe.pendingSlotId)
                or Language.LUA_FAC_PIPE_INTERACT_OPTION,
        icon = policy.destroyMode
                and FacConst.FAC_INTERACT_ICON.Delete or FacConst.FAC_INTERACT_ICON.Common,
        sortId = 500,
        action = function()
            if isInvalid then
                FactoryUtils.delBuilding(nodeId)
            else
                self.m_host:ExecuteInteract({
                    nodeId = nodeId,
                    unitIndex = unitIndex,
                })
            end
        end,
    }
    if isInvalid then
        args.text = string.format(Language.LUA_FACTORY_INVALID_BUILDING_INTERACT, args.text)
    end
    if policy.useAsyncRst then
        args.text = appendDebugSuffix(args.text, pipe.chapterId, nodeId)
    end
    self:_AddOption(
        model,
        FacConst.FAC_INTERACT_OPTION_SOURCE_ID.Pipe,
        args,
        nodeId .. ":" .. unitIndex .. ":" .. tostring(args.text)
    )
    if policy.destroyMode then
        self:_AddOption(model, FacConst.FAC_INTERACT_OPTION_SOURCE_ID.DeleteAllPipe, {
            templateId = templateId,
            isDel = true,
            text = string.format(Language.DEL_ALL_BELT_FORMAT, Language.LUA_FAC_PIPE_INTERACT_OPTION),
            icon = FacConst.FAC_INTERACT_ICON.DeleteAll,
            action = function()
                self.m_host:ExecuteInteract({ nodeId = nodeId, isAll = true })
            end,
            sortId = 499,
        }, nodeId .. ":all")
    end
end


FacInteractHandlerBase._BuildBeltOptions = HL.Method(HL.Table, HL.Any, HL.Table, HL.Table)
        << function(self, model, belt, input, policy)
    if not belt then
        return
    end
    local nodeId = belt.nodeId
    local unitIndex = belt.unitIndex
    local logisticPos = belt.logisticPos
    local logisticName
    if belt.pendingSlotId > 0 then
        logisticName = FactoryUtils.getPendingSlotName(belt.pendingSlotId)
    else
        local chapterInfo = FactoryUtils.getCurChapterInfo()
        local nodeHandler = chapterInfo:GetNode(nodeId)
        if nodeHandler then
            local _, logisticData = Tables.factoryGridBeltTable:TryGetValue(nodeHandler.templateId)
            logisticName = logisticData and logisticData.beltData.name
        end
    end
    if not logisticName then
        return
    end
    local args = {
        action = function()
            self.m_host:ExecuteInteract({
                nodeId = nodeId,
                unitIndex = unitIndex,
                logisticPos = logisticPos,
            })
        end,
        icon = policy.destroyMode
                and FacConst.FAC_INTERACT_ICON.Delete or FacConst.FAC_INTERACT_ICON.Common,
        isDel = policy.destroyMode,
        sortId = policy.destroyMode and -100 or 300,
        text = logisticName,
    }
    if policy.useAsyncRst and not policy.destroyMode then
        args.text = appendDebugSuffix(args.text, belt.chapterId, nodeId)
    end
    self:_AddOption(
        model,
        FacConst.FAC_INTERACT_OPTION_SOURCE_ID.Belt,
        args,
        nodeId .. ":" .. unitIndex .. ":" .. tostring(args.text)
    )
    if policy.destroyMode then
        self:_AddOption(model, FacConst.FAC_INTERACT_OPTION_SOURCE_ID.DeleteAllBelt, {
            isDel = true,
            text = string.format(Language.DEL_ALL_BELT_FORMAT, logisticName),
            icon = FacConst.FAC_INTERACT_ICON.DeleteAll,
            action = function()
                self.m_host:ExecuteInteract({
                    nodeId = nodeId,
                    unitIndex = unitIndex,
                    isAll = true,
                })
            end,
            sortId = -200,
        }, nodeId .. ":all")
    end
end



FacInteractHandlerBase._SyncBuildingApproach = HL.Method(HL.Opt(HL.Number, HL.Number, HL.String, HL.Boolean))
        << function(self, nodeId, socialNodeId, approachIdentity, forceUpdate)
    if self.m_lastApproachBuildingNodeId ~= nodeId then
        CSFactoryUtil.DispatchFactoryBuildingApproachSelectedChanged(
            self.m_lastApproachBuildingNodeId,
            nodeId
        )
        if self.m_lastApproachBuildingNodeId then
            GameWorld.interactiveFacWrapperManager:OnFacBuildingInteractOptionRemove(
                self.m_lastApproachBuildingNodeId
            )
        end
        if nodeId then
            GameWorld.interactiveFacWrapperManager:OnFacBuildingInteractOptionAdded(nodeId)
        end
        self.m_lastApproachBuildingNodeId = nodeId
        self.m_lastApproachIdentity = approachIdentity
    elseif nodeId and (forceUpdate or self.m_lastApproachIdentity ~= approachIdentity) then
        GameWorld.interactiveFacWrapperManager:OnFacBuildingInteractOptionUpdate(nodeId)
        self.m_lastApproachIdentity = approachIdentity
    end

    if self.m_lastSocialBuildingNodeId ~= socialNodeId then
        if socialNodeId then
            local canLike = FactoryUtils.canLikeSocialBuilding(socialNodeId)
            local abilityState = canLike
                    and CS.Beyond.Gameplay.GeneralAbilitySystem.AbilityState.Idle
                    or CS.Beyond.Gameplay.GeneralAbilitySystem.AbilityState.ForbiddenUse
            GameInstance.player.generalAbilitySystem:SwitchAbilityStateByType(
                GEnums.GeneralAbilityType.BuildingLike,
                abilityState
            )
            GameInstance.player.generalAbilitySystem:ActivateTempAbility(
                GEnums.GeneralAbilityType.BuildingLike,
                canLike,
                socialNodeId
            )
        else
            GameInstance.player.generalAbilitySystem:DeactivateTempAbility(
                GEnums.GeneralAbilityType.BuildingLike
            )
        end
        self.m_lastSocialBuildingNodeId = socialNodeId
    end
end



FacInteractHandlerBase.ClearPresentationState = HL.Virtual() << function(self)
    self:_SyncBuildingApproach(nil, nil)
    
    GameInstance.player.generalAbilitySystem:DeactivateTempAbility(GEnums.GeneralAbilityType.BuildingLike)
    self.m_lastApproachIdentity = nil
    self.m_cachedXLoaderNodeId = nil
    self.m_cachedXLoaderSubInfo = nil
end


FacInteractHandlerBase.ExecuteInteract = HL.Virtual(HL.Table) << function(self, option)
end


FacInteractHandlerBase.ClearAllBatchTargets = HL.Virtual() << function(self)
end


FacInteractHandlerBase.SelectBatchTarget = HL.Virtual(HL.Number, HL.Boolean, HL.Opt(HL.Number))
        << function(self, nodeId, isAdd, unitIndex)
end


FacInteractHandlerBase.IsDraggingInBatchMode = HL.Virtual().Return(HL.Boolean) << function(self)
    return false
end


FacInteractHandlerBase.MarkBatchDragDirty = HL.Virtual() << function(self)
end




HL.Commit(FacInteractHandlerBase)
