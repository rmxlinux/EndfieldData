local MapUtils = {}

local remindConfig = require_ex("UI/Panels/Map/MapRemindConfig")

if BEYOND_DEBUG_COMMAND or BEYOND_DEBUG or UNITY_EDITOR then
    MapUtils.IsMapRemindShow = true
end

function MapUtils.checkCanOpenMapAndParseArgs(args)
    if Utils.isCurSquadAllDead() then
        
        return false, Language.LUA_GAME_MODE_FORBID_FACTORY_WATCH
    end
    args = args or {}
    if PhaseManager:IsPhaseForbidden(PhaseId.Map) then
        return false, Language.LUA_MAP_OPEN_FORBID_CONDITION
    end
    if not string.isEmpty(args.templateId) then
        if not string.isEmpty(args.mapId) then
            if GameWorld.worldInfo.curMapIdStr == args.mapId then
                
                args.instId = GameInstance.player.mapManager:GetMainCharacterMostNearbyMarkByTemplateId(args.templateId)
            else
                
                args.instId = GameInstance.player.mapManager:GetFirstValidMarkByTemplateId(args.templateId, args.mapId)
            end
        else
            local mostNearbyId = GameInstance.player.mapManager:GetMainCharacterMostNearbyMarkByTemplateId(args.templateId)
            if not string.isEmpty(mostNearbyId) then
                
                args.instId = mostNearbyId
            else
                
                args.instId = GameInstance.player.mapManager:GetFirstValidMarkByTemplateId(args.templateId)
            end
        end
        if string.isEmpty(args.instId) then
            return false, Language.LUA_JUMP_TO_MAP_BY_TEMPLATE_ID_FAILED
        end
    end
    if not string.isEmpty(args.resourceTemplateId) then
        
        if not string.isEmpty(args.mapId) then
            if GameWorld.worldInfo.curMapIdStr == args.mapId then
                args.instId = GameInstance.player.mapManager:GetMainCharacterMostNearbyResourceMarkByTemplateId(
                    args.resourceTemplateId,
                    args.resourceItemId
                )
            else
                args.instId = GameInstance.player.mapManager:GetFirstValidResourceMarkByTemplateId(
                    args.resourceTemplateId,
                    args.resourceItemId,
                    args.mapId
                )
            end
        else
            local mostNearbyId = GameInstance.player.mapManager:GetMainCharacterMostNearbyResourceMarkByTemplateId(
                args.resourceTemplateId,
                args.resourceItemId
            )
            if not string.isEmpty(mostNearbyId) then
                args.instId = mostNearbyId
            else
                args.instId = GameInstance.player.mapManager:GetFirstValidResourceMarkByTemplateId(
                    args.resourceTemplateId,
                    args.resourceItemId
                )
            end
        end
        if string.isEmpty(args.instId) then
            return false, Language.LUA_JUMP_TO_MAP_BY_TEMPLATE_ID_FAILED
        end
    end
    if not string.isEmpty(args.levelId) and not MapUtils.checkIsValidLevelId(args.levelId) then
        return false, Language.LUA_OPEN_MAP_LEVEL_LOCKED
    end
    if not string.isEmpty(args.instId) and not MapUtils.checkIsValidMarkInstId(args.instId) then
        return false
    end
    return true
end

function MapUtils.openMap(instId, levelId, customArgs)
    local data = {}

    levelId = string.isEmpty(levelId) and GameWorld.worldInfo.curLevelId or levelId
    if not string.isEmpty(instId) then
        local _, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(instId)
        levelId = markRuntimeData.levelId
        if markRuntimeData.nodeId ~= nil and not markRuntimeData.isVisible then
            
            GameInstance.player.mapManager.forceShowFacMarkInRegionList:Add(instId)
        end
    end

    data.instId = instId
    data.levelId = levelId
    data.customArgs = customArgs

    PhaseManager:GoToPhase(PhaseId.Map, data)
end

function MapUtils.openMapByMissionId(trackId)
    local instId = GameInstance.player.mapManager:GetMissionTrackingMarkInstIdByTrackId(trackId)
    MapUtils.openMap(instId)
end

function MapUtils.checkIsValidMarkInstId(instId, ignoreInvisible)
    if instId == nil then
        return false
    end

    local success, markData = GameInstance.player.mapManager:GetMarkInstRuntimeData(instId)
    if not success then
        return false
    end

    if not MapUtils.checkIsValidLevelId(markData.levelId) then
        return false
    end

    if not markData.isVisible and not ignoreInvisible then
        return false
    end

    return true
end

function MapUtils.checkIsValidLevelId(levelId)
    if levelId == nil then
        return false
    end

    if not GameInstance.player.mapManager:IsLevelUnlocked(levelId) then
        return false
    end

    return true
end

function MapUtils.openMapAndSetMarkVisibleIfNecessary(instId)
    GameInstance.player.mapManager:SetStaticMarkVisibleStateWithCallback(instId, true, function()
        MapUtils.openMap(instId)
    end)
end

function MapUtils.switchFromLevelMapToRegionMap(levelId, domainId)
    
    local topPhase = PhaseManager:GetTopPhaseId()
    if topPhase ~= PhaseId.Map then
        return
    end
    local args
    if levelId ~= nil or domainId ~= nil then
        args = {
            levelId = levelId,
            domainId = domainId,
        }
    end
    PhaseManager:OpenPhase(PhaseId.RegionMap, args, function()
        PhaseManager:ExitPhaseFast(PhaseId.Map)
    end)
end

function MapUtils.switchFromRegionMapToLevelMap(instId, levelId)
    
    local topPhase = PhaseManager:GetTopPhaseId()
    if topPhase ~= PhaseId.RegionMap then
        return
    end
    local args
    if instId ~= nil or levelId ~= nil then
        args = {
            instId = instId,
            levelId = levelId,
            needTransit = true,
        }
    end
    PhaseManager:OpenPhaseFast(PhaseId.Map, args)
    PhaseManager:ExitPhaseFast(PhaseId.RegionMap)
end

function MapUtils.closeMapRelatedPhase()
    local topPhase = PhaseManager:GetTopPhaseId()

    if PhaseManager:IsOpen(PhaseId.Map) then
        if topPhase == PhaseId.Map then
            PhaseManager:PopPhase(PhaseId.Map)
        else
            PhaseManager:ExitPhaseFast(PhaseId.Map)
        end
    end

    if PhaseManager:IsOpen(PhaseId.RegionMap) then
        if topPhase == PhaseId.RegionMap then
            PhaseManager:PopPhase(PhaseId.RegionMap)
        else
            PhaseManager:ExitPhaseFast(PhaseId.RegionMap)
        end
    end
end

function MapUtils.updateMapInfoViewNode(viewNode, data, ignoreSetActive)
    local total = data.total
    local curr = data.curr

    local needActive = total > 0
    if needActive or ignoreSetActive then
        if viewNode.countText then
            viewNode.countText.text = string.format(MapConst.MAP_BUILDING_COLLECTION_INFO_NUM_TEXT_FORMAT, curr, total)
        end

        if viewNode.fillImage then
            viewNode.fillImage.fillAmount = curr / total
        end

        if viewNode.currCountTxt then
            viewNode.currCountTxt.text = curr
        end

        if viewNode.totalCountTxt then
            viewNode.totalCountTxt.text = string.format(MapConst.MAP_BUILDING_COLLECTION_INFO_POPUP_TOTAL_NUM_TEXT_FORMAT, total)
        end
    end

    if not ignoreSetActive then
        viewNode.gameObject:SetActive(needActive)
    end
end

function MapUtils.getMapRemindTipInfo(levelId)
    local mapMrg = GameInstance.player.mapManager
    local remandInfo = {}
    if BEYOND_DEBUG_COMMAND or BEYOND_DEBUG or UNITY_EDITOR then
        if MapUtils.IsMapRemindShow == false then
            return remandInfo
        end
    end

    local function processSingleInstance(instId, enumType, remindData, mapMrg, markInsIds)
        if mapMrg:IsRemindRead(enumType, instId) then
            return
        end

        local processedId = instId
        if remindData.mapMarkType then
            local succ, mapMarkInstId = mapMrg:GetMapMarkInstId(remindData.mapMarkType, instId)
            processedId = succ and mapMarkInstId or instId
        end
        table.insert(markInsIds, processedId)
    end

    for remindType = GEnums.MapRemindType.Default:GetHashCode(), GEnums.MapRemindType.Max:GetHashCode() do
        local enumType = GEnums.MapRemindType.__CastFrom(remindType)

        local success, cfg = Tables.mapRemindTable:TryGetValue(enumType)
        if not success then
            goto continue
        end

        local remindData = remindConfig[enumType]
        if not remindData then
            logger.warn("MapRemindConfig未找到类型: " .. enumType:ToString())
            goto continue
        end

        local fatherRedDotName = cfg.tabType == GEnums.MapRemindTabType.ImportantMatters
            and "MapImportantMatters"
            or "MapCollectionTips"

        local redDotName = string.isEmpty(remindData.redDotName) and
            (cfg.redDotRead2Hide and "CommonMapRemindReadLike" or "CommonMapRemind") or remindData.redDotName
        if redDotName and redDotName ~= "" then
            RedDotManager:AddFatherSon(fatherRedDotName, redDotName)
        end

        if not remindData.Check then
            logger.error("MapRemindConfig Check函数为空: " .. enumType:ToString())
            goto continue
        end
        local markInsIds = {}
        local checkResult = remindData.Check(levelId)
        if type(checkResult) == "table" then
            for _, instId in pairs(checkResult) do
                processSingleInstance(instId, enumType, remindData, mapMrg, markInsIds)
            end
        elseif type(checkResult) == "userdata" then
            if checkResult.Count ~= 0 then
                for j = 0, checkResult.Count - 1 do
                    processSingleInstance(checkResult[j], enumType, remindData, mapMrg, markInsIds)
                end
            end
        end

        if #markInsIds > 0 then
            remandInfo[enumType] = {
                insIdList = markInsIds,
                redDotName = remindData.redDotName,
                useMarkIcon = remindData.useMarkIcon
            }
        end
        ::continue::
    end

    return remandInfo
end

function MapUtils.mapRemindRedDotCheck(args)
    if BEYOND_DEBUG_COMMAND or BEYOND_DEBUG or UNITY_EDITOR then
        if MapUtils.IsMapRemindShow == false then
            return false
        end
    end
    local mapMrg = GameInstance.player.mapManager
    local function isRemindReadOrNotVisible(instId, enumType, remindData)
        local processedId = instId
        if remindData.mapMarkType then
            local succ, mapMarkInstId = mapMrg:GetMapMarkInstId(remindData.mapMarkType, instId)
            processedId = succ and mapMarkInstId or instId
        end
        if mapMrg:IsRemindReadRedDot(enumType, processedId) then
            return true
        end
        local succ, markRuntimeData = mapMrg:GetMarkInstRuntimeData(processedId)
        if not succ or not markRuntimeData.isVisible or (not markRuntimeData.visibleInMist and markRuntimeData:IsInMist()) then
            return true
        end
        return false
    end

    if args == nil then
        return false, UIConst.RED_DOT_TYPE.Normal
    end

    if args.levelId == nil then
        logger.error("MapUtils.mapRemindRedDotCheck: levelId is nil")
        return false, UIConst.RED_DOT_TYPE.Normal
    end

    if args.instId ~= nil and args.mapRemindType ~= nil then
        if not GameInstance.player.mapManager:IsRemindReadRedDot(args.mapRemindType, args.instId) then
            return true, UIConst.RED_DOT_TYPE.Normal
        end
        return false, UIConst.RED_DOT_TYPE.Normal
    end

    
    if args.mapRemindType ~= nil then
        local mapRemind = remindConfig[args.mapRemindType]
        local list = mapRemind.Check(args.levelId)
        local hasRedDot = false
        if type(list) == "table" then
            for _, insId in pairs(list) do
                if not isRemindReadOrNotVisible(insId,args.mapRemindType,mapRemind) then
                    hasRedDot = true
                    break
                end
            end
        elseif type(list) == "userdata" then
            for i = 0, list.Count - 1 do
                if not isRemindReadOrNotVisible(list[i], args.mapRemindType, mapRemind) then
                    hasRedDot = true
                    break
                end
            end
        end
        return hasRedDot, UIConst.RED_DOT_TYPE.Normal
    end

    if args.tabType ~= nil then
        for remindType, remindData in pairs(remindConfig) do
            local cfg = Tables.mapRemindTable:GetValue(remindType)
            if cfg.tabType == args.tabType then
                local list = remindData.Check(args.levelId)
                if type(list) == "table" then
                    for i = 1, #list do
                        if not isRemindReadOrNotVisible(list[i], remindType, remindData) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                elseif type(list) == "userdata" then
                    for i = 0, list.Count - 1 do
                        if not isRemindReadOrNotVisible(list[i], remindType, remindData) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                end
            end
        end
        return false, UIConst.RED_DOT_TYPE.Normal
    end

    for remindType, remindData in pairs(remindConfig) do
        local list = remindData.Check(args.levelId)
        if type(list) == "table" then
            for i = 1, #list do
                if not isRemindReadOrNotVisible(list[i], remindType, remindData) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
        elseif type(list) == "userdata" then
            for i = 0, list.Count - 1 do
                if not isRemindReadOrNotVisible(list[i], remindType, remindData) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
        end
    end
    return false, UIConst.RED_DOT_TYPE.Normal
end

function MapUtils.getLevelTrackPositionAndLevel(startLevelId, endLevelId)
    local findDirectlyLinkFunc = function(startLinkLevelId, endLinkLevelId)
        for _, trackData in pairs(Tables.trackMapPointTable) do
            if trackData["start"] == startLinkLevelId and trackData["end"] == endLinkLevelId then
                return trackData.pos
            end
        end
        return nil
    end

    local position = findDirectlyLinkFunc(startLevelId, endLevelId)
    if position then
        return position, endLevelId
    end

    for _, trackLinkData in pairs(Tables.trackMapLinkTable) do
        if trackLinkData["start"] == startLevelId and trackLinkData["end"] == endLevelId then
            local linkLevel = trackLinkData.mid
            position = findDirectlyLinkFunc(startLevelId, linkLevel)
            if position then
                return position, linkLevel
            end
        end
    end

    return Vector3.zero, ""
end

function MapUtils.teleportToHubByHubMark(hubMarkData, overrideNodeId)
    if hubMarkData == nil then
        return
    end
    local hubNodeId = overrideNodeId == nil and hubMarkData.nodeId or overrideNodeId
    Utils.teleportToPosition(hubMarkData.levelId,
        hubMarkData:GetTeleportPosition(),
        hubMarkData:GetTeleportRotation(),
        GEnums.C2STeleportReason.ServerGotoHub,
        function()
            GameInstance.gameplayNetwork:RestAtHub()
        end,
        CS.Beyond.Gameplay.TeleportUIType.Default,
        hubNodeId
    )
end

function MapUtils.getLevelInitialOffset(levelId)
    local success, configInfo = DataManager.uiLevelMapConfig.levelConfigInfos:TryGetValue(levelId)
    if not success then
        return Vector2.zero
    end
    local minScale = configInfo.minScale
    local gridRectLength = DataManager.uiLevelMapConfig.gridRectLength
    return Vector2(
        -configInfo.horizontalInitOffsetGridsValue * gridRectLength * minScale,
        -configInfo.verticalInitOffsetGridsValue * gridRectLength * minScale
    )
end

function MapUtils.isSpaceshipRelatedLevel(levelId)
    return levelId == MapConst.LEVEL_MAP_ID_GETTER.BASE01_LV001 or levelId == MapConst.LEVEL_MAP_ID_GETTER.BASE01_LV003
end

function MapUtils.getActivitySnapShotMarkTitle(markRuntimeData)
    local success, cfg = Tables.activityConditionalMultiStageTable:TryGetValue(markRuntimeData.detail.activityId)
    if not success then
        return ""
    end
    return cfg.stageList[markRuntimeData.detail.activityStageId].name
end

function MapUtils.isTemporaryCustomMark(markInstId)
    local markRuntimeData = GameInstance.player.mapManager:GetQuickSearchCustomMarkData(markInstId)
    if markRuntimeData == nil then
        return false
    end
    return markRuntimeData.isSelect
end


_G.MapUtils = MapUtils
return MapUtils