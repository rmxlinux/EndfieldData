







local FacBuildCheckResultHint = {}




function FacBuildCheckResultHint.getBuildingHint(checkResult, ctx)
    local valid, hint = checkResult.success, nil

    if not valid then
        if checkResult.skipChapterInvalidInDomain then
            hint = Language.LUA_FAC_BUILD_MODE_SKIP_CHAPTER_INVALID_IN_DOMAIN
        elseif checkResult.busLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ROAD_ATTACH
        elseif checkResult.buildableInChapterLimitedTemplates and checkResult.buildableInChapterLimitedTemplates.Count > 0 then
            local tempId = checkResult.buildableInChapterLimitedTemplates[0].Item1
            local requireMode = checkResult.buildableInChapterLimitedTemplates[0].Item2
            hint = Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDABLE_LIMIT_DEFAULT
            if not string.isEmpty(tempId) then
                local buildingData = Tables.factoryBuildingTable:GetValue(tempId)
                if buildingData then
                    local displayString = buildingData.name
                    if requireMode ~= nil then
                        local succ, modeData = Tables.FactoryMachineCraftModeTable:TryGetValue(requireMode)
                        if succ then
                            displayString = string.format("%s(%s)", displayString, modeData.machineModeTypeName)
                        end
                    end
                    if ctx.isBlueprintVariant then
                        hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDABLE_LIMIT_MULTI_FORMAT, displayString)
                    elseif checkResult.domainModeLimited then
                        hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_MODE_LIMIT_FORMAT, GameInstance.remoteFactoryManager.currentChapterInfo.data.name, displayString)
                    else
                        local limitChapters = CSFactoryUtil.GetLimitedChapterNames(tempId)
                        local nameCount = limitChapters.Count
                        if nameCount == 1 then
                            hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDABLE_LIMIT_FORMAT_1, limitChapters[0])
                        elseif nameCount == 2 then
                            hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDABLE_LIMIT_FORMAT_2, limitChapters[0], limitChapters[1])
                        elseif nameCount >= 3 then
                            hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDABLE_LIMIT_FORMAT_3, limitChapters[0], limitChapters[1])
                        end
                    end
                end
            end
        elseif checkResult.totalCountLimitedTemplates and checkResult.totalCountLimitedTemplates.Count > 0 then
            local tempId = checkResult.totalCountLimitedTemplates[0]
            local maxPriority = FactoryUtils.evaluateMultiBuildingLimitedPriority(tempId)
            for i = 1, checkResult.totalCountLimitedTemplates.Count - 1 do
                local curTempId = checkResult.totalCountLimitedTemplates[i]
                local priority = FactoryUtils.evaluateMultiBuildingLimitedPriority(curTempId)
                if priority > maxPriority then
                    tempId = curTempId
                    maxPriority = priority
                end
            end
            hint = Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDING_COUNT_LIMIT_DEFAULT
            if not string.isEmpty(tempId) then
                local buildingData = Tables.factoryBuildingTable:GetValue(tempId)
                if buildingData then
                    if ctx.isBlueprintVariant then
                        hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDING_COUNT_LIMIT_MULTI_FORMAT, buildingData.name)
                    else
                        hint = string.format(Language.LUA_FAC_BUILD_MODE_CHAPTER_BUILDING_COUNT_LIMIT_FORMAT, buildingData.name)
                    end
                end
            end
        elseif checkResult.totalCountLimitedBuildingTypes and checkResult.totalCountLimitedBuildingTypes.Count > 0 then
            local buildingType = checkResult.totalCountLimitedBuildingTypes[0]
            local buildingTypeText = Language.LUA_FAC_BATCH_MODE_BUILDING_TYPE_TEXT_DEFAULT
            if buildingType == GEnums.FacBuildingType.Decorate:GetHashCode() then
                buildingTypeText = Language.LUA_FAC_BATCH_MODE_BUILDING_TYPE_TEXT_DECORATE
            end
            hint = string.format(Language.LUA_FAC_BUILD_MODE_BUILDING_TYPE_COUNT_LIMITED_FORMAT, buildingTypeText)
        elseif checkResult.bandwidthLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_BANDWIDTH_MAX
        elseif checkResult.zoneLimited then
            if ctx.isBlueprintVariant then
                local facRegionType = GameInstance.player.factoryRegionManager.currentRegion.type
                if facRegionType == GEnums.FacRegionType.Crop then
                    hint = Language.LUA_FAC_BUILD_MODE_CROP_REGION_LIMITED_BLUEPRINT
                else
                    hint = Language.LUA_FAC_BUILD_MODE_MAIN_REGION_LIMITED_BLUEPRINT
                end
            else
                hint = Language.LUA_FAC_BUILD_MODE_MAIN_REGION_LIMITED
            end
        elseif checkResult.sceneLimited then
            hint = Language.LUA_FAC_BUILD_MODE_SCENE_LIMITED_DEFAULT
            local currentMode = GameInstance.remoteFactoryManager.interact.currentBuildingMode
            if not currentMode then
                currentMode = GameInstance.remoteFactoryManager.interact.currentBlueprintMode
                if currentMode then
                end
            end
            if currentMode then
                local limitedSceneIds = currentMode.limitedSceneIds
                if limitedSceneIds and limitedSceneIds.Count == 1 then
                    local sceneId = limitedSceneIds[0]
                    local sceneData = GameInstance.remoteFactoryManager.staticData:QuerySceneData(sceneId)
                    if sceneData then
                        hint = string.format(Language.LUA_FAC_BUILD_MODE_SCENE_LIMITED_FORMAT, sceneData.name)
                    end
                end
            end
        elseif checkResult.cropAreaLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_CROP_AREA_ONLY
        elseif checkResult.cropCntLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_CROP_COUNT_LIMITED
        elseif checkResult.travelPoleCountLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_TRAVEL_POLE_COUNT_MAX
        elseif checkResult.battleCountLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_BATTLE_COUNT_MAX
        elseif checkResult.mineLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_MINE_ONLY
        elseif checkResult.mineTypeLimited then
            hint = Language.LUA_FAC_BUILD_MODE_ON_WRONG_MINE_TYPE
        elseif checkResult.mineLevelLimited then
            hint = Language.LUA_FAC_BUILD_MODE_MINE_LEVEL_LIMITED
        elseif checkResult.buildableRiftLimited then
            hint = Language.LUA_FAC_BUILD_MODE_IN_RIFT_LIMITED
        elseif checkResult.buildableWaterLimited then
            hint = Language.LUA_FAC_BUILD_MODE_IN_WATER_LIMITED
        elseif checkResult.buildableLimited then 
            hint = Language.LUA_FAC_BUILD_MODE_IN_BUILDABLE_RANGE_BUT_HAS_INVALID_GRID
        elseif checkResult.occludedByArea then
            hint = Language.LUA_FAC_BUILD_MODE_OCCLUDED_BY_AREA
        elseif checkResult.crossDivisionBoundary then
            hint = Language.LUA_FAC_BUILD_MODE_CROSS_DIVISION_BOUNDARY
        elseif checkResult.overlayWithBlueprintNode
            or (checkResult.overlayNodes and checkResult.overlayNodes.Count > 0)
            or (checkResult.overlayPendingNodes and checkResult.overlayPendingNodes.Count > 0) then
            hint = Language.LUA_FAC_BUILD_MODE_BUILDING_OVERLAP
        elseif checkResult.outRanged then
            hint = Language.LUA_FAC_BUILD_MODE_OUT_OF_RANGE
        elseif checkResult.outOfHeight then
            hint = Language.LUA_FAC_BUILD_MODE_HEIGHT_OVER_TOOMUCH
        elseif checkResult.groundTooUneven then
            hint = Language.LUA_FAC_BUILD_MODE_GROUND_TOO_UNEVEN
        elseif checkResult.collideWithMap then
            hint = Language.LUA_FAC_BUILD_MODE_SPACE_HEIGHT_NOT_ENOUGH
        elseif checkResult.blockedByInter then
            hint = Language.LUA_FAC_BUILD_MODE_BLOCK_BY_DYNAMIC_ENTITY
        elseif checkResult.blockedByLoot then
            hint = Language.LUA_FAC_BUILD_MODE_BLOCK_BY_LOOT
        elseif checkResult.blockedByErosion then
            hint = Language.LUA_FAC_BUILD_MODE_BLOCK_WITH_EROSION
        elseif checkResult.pumpReachLiquidLimited then
            hint = Language.LUA_FAC_BUILD_MODE_PUMP_MUST_REACH_LIQUID
        elseif checkResult.pumpLiquidTypeNotMatched then
            local liquidItemId = ctx.pumpingLiquidItemId
            if ctx.buildingId and not ctx.buildingId:isEmpty() and liquidItemId and not string.isEmpty(liquidItemId) then
                local buildingData = GameInstance.remoteFactoryManager.staticData:QueryBuildingData(ctx.buildingId)
                local itemData = Tables.itemTable[liquidItemId]
                if buildingData and itemData then
                    hint = string.format(Language.LUA_FAC_BUILD_MODE_PUMP_LIQUID_TYPE_NOT_MATCH_FORMAT, buildingData.name, itemData.name)
                else
                    hint = Language.LUA_FAC_BUILD_MODE_PUMP_LIQUID_TYPE_NOT_MATCH_DEFAULT
                end
            else
                hint = Language.LUA_FAC_BUILD_MODE_PUMP_LIQUID_TYPE_NOT_MATCH_DEFAULT
            end
        elseif checkResult.dumpReachLiquidLimited then
            if GameInstance.remoteFactoryManager.system.core.progressStatus.riftFilling.enableRiftFilling then
                hint = Language.LUA_FAC_BUILD_MODE_DUMP_MUST_REACH_LIQUID_0N_RIFT_FILLING_UNLOCK
            else
                hint = Language.LUA_FAC_BUILD_MODE_DUMP_MUST_REACH_LIQUID
            end
        elseif checkResult.riftFillingNotEnabled then
            hint = Language.LUA_FAC_BUILD_MODE_RIFT_FILLING_NOT_ENABLED
        elseif checkResult.riftIsNotSuppressedYet then
            hint = Language.LUA_FAC_BUILD_MODE_RIFT_IS_NOT_SUPPRESSED_YET
        elseif checkResult.noSoilForWaterSpray then
            hint = Language.LUA_FAC_BUILD_MODE_NO_SOIL_IN_SPRAY
        elseif checkResult.moveAcrossScene then
            hint = Language.LUA_FAC_BUILD_MODE_MOVE_ACROSS_SCENE
        elseif checkResult.notAlongLogistic then
            hint = Language.LUA_FAC_BUILD_MODE_NOT_ALONG_LOGISTIC_DIRECTION
        elseif checkResult.notPutOnConveyor then
            if ctx.buildingId and not ctx.buildingId:isEmpty() then
                if Tables.factoryFluidValveTable:ContainsKey(ctx.buildingId) then
                    hint = Language.LUA_FAC_BUILD_MODE_VALVE_NOT_ON_CONVEYOR_FLUID
                end
            end
            if not hint then
                hint = Language.LUA_FAC_BUILD_MODE_VALVE_NOT_ON_CONVEYOR_BOX
            end
        elseif checkResult.minDistanceLimitNodes and checkResult.minDistanceLimitNodes.Count > 0 then
            hint = Language.LUA_FAC_BUILD_MODE_MIN_DISTANCE_LIMIT
        elseif checkResult.medicRangeOverlap then
            hint = Language.LUA_FAC_BUILD_MODE_MEDIC_RANGE_OVERLAP
        elseif checkResult.overlayMineIndex and checkResult.overlayMineIndex.Count > 0 then
            hint = Language.LUA_FAC_BUILD_MODE_MINE_OVERLAP
        elseif checkResult.freeBusNoConnectSource then
            hint = Language.LUA_FAC_BUILD_MODE_FREE_BUS_NO_CONNECTION_TO_START
        elseif checkResult.deviceItemCountNotEnough then
            hint = Language.LUA_FAC_BUILD_MODE_DEVICE_ITEM_NOT_ENOUGH
        else
            hint = Language.LUA_FAC_BUILD_MODE_OTHERS
        end
    end
    return valid, hint
end





function FacBuildCheckResultHint.getConveyorHint(checkResult, isPipe, ctx)
    local valid, hint = checkResult.success, nil

    if not valid then
        if checkResult.mainRegionLimited then
            if ctx.isBlueprintVariant then
                local facRegionType = GameInstance.player.factoryRegionManager.currentRegion.type
                if facRegionType == GEnums.FacRegionType.Crop then
                    hint = Language.LUA_FAC_BUILD_MODE_CROP_REGION_LIMITED_BLUEPRINT
                else
                    hint = Language.LUA_FAC_BUILD_MODE_MAIN_REGION_LIMITED_BLUEPRINT
                end
            else
                hint = Language.LUA_FAC_BUILD_MODE_MAIN_REGION_LIMITED
            end
        elseif checkResult.buildableLimited then
            hint = Language.LUA_FAC_BUILD_MODE_IN_BUILDABLE_RANGE_BUT_HAS_INVALID_GRID
        elseif checkResult.occludedByArea then
            hint = Language.LUA_FAC_BUILD_MODE_OCCLUDED_BY_AREA
        elseif checkResult.linkingNodeInvalidPlaced then
            hint = isPipe and Language.LUA_FAC_BUILD_MODE_PIPE_LINK_INVALID_PLACED_NODE or Language.LUA_FAC_BUILD_MODE_BELT_LINK_INVALID_PLACED_NODE
        elseif checkResult.hasSelfOverlay then
            hint = isPipe and Language.LUA_FAC_BUILD_MODE_PIPE_SELF_OVERLAP or Language.LUA_FAC_BUILD_MODE_BELT_SELF_OVERLAP
        elseif checkResult.pipeAngleLimited then
            hint = Language.LUA_FAC_BUILD_MODE_PIPE_ANGLE_LIMITED
        elseif (checkResult.overlayNodes and checkResult.overlayNodes.Count > 0)
            or (checkResult.overlayPendingNodes and checkResult.overlayPendingNodes.Count > 0) then
            hint = Language.LUA_FAC_BUILD_MODE_BUILDING_OVERLAP
        elseif checkResult.directionConflictLogisticUnits and checkResult.directionConflictLogisticUnits.Count > 0 then
            hint = isPipe and Language.LUA_FAC_BUILD_MODE_DIRECTION_CONFLICT_LOGISTIC_UNIT_PIPE or Language.LUA_FAC_BUILD_MODE_DIRECTION_CONFLICT_LOGISTIC_UNIT_BELT
        elseif checkResult.overLengthLimit then
            hint = isPipe and Language.LUA_FAC_BUILD_MODE_PIPE_OVER_LENGTH_LIMIT or Language.LUA_FAC_BUILD_MODE_BELT_OVER_LENGTH_LIMIT
        elseif checkResult.shapeInvalid then
            hint = isPipe and Language.LUA_FAC_BUILD_MODE_PIPE_SHAPE_INVALID or Language.LUA_FAC_BUILD_MODE_BELT_SHAPE_INVALID
        elseif checkResult.pipeStartModeLimited then
            hint = Language.LUA_FAC_BUILD_MODE_START_NODE_PIPE_MODE_LIMITED
        elseif checkResult.pipeEndModeLimited then
            hint = Language.LUA_FAC_BUILD_MODE_END_NODE_PIPE_MODE_LIMITED
        elseif checkResult.pipeStartPortLimited then
            hint = Language.LUA_FAC_BUILD_MODE_START_NODE_PIPE_PORT_LIMITED
        elseif checkResult.pipeEndPortLimited then
            hint = Language.LUA_FAC_BUILD_MODE_END_NODE_PIPE_PORT_LIMITED
        elseif checkResult.overlayMineIndex and checkResult.overlayMineIndex.Count > 0 then
            hint = Language.LUA_FAC_BUILD_MODE_MINE_OVERLAP
        elseif checkResult.domainModeLimited then
            local pipeData = Tables.factoryLiquidPipeTable:GetValue("log_pipe_01")
            local buildingName = pipeData and pipeData.pipeData.name or ""
            hint = string.format(
                Language.LUA_FAC_BUILD_MODE_CHAPTER_MODE_LIMIT_FORMAT,
                GameInstance.remoteFactoryManager.currentChapterInfo.data.name, buildingName
            )
        else
            hint = Language.LUA_FAC_BUILD_MODE_OTHERS
        end
    end
    return valid, hint
end


_G.FacBuildCheckResultHint = FacBuildCheckResultHint
return FacBuildCheckResultHint
