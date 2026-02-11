local AdventureBookUtils = {}

function AdventureBookUtils.CheckRedDotAdventureBookTabStage()
    
    local adventureBookData = GameInstance.player.adventure.adventureBookData
    local isComplete = adventureBookData.isCurAdventureBookStateComplete
    local curStage = adventureBookData.adventureBookStage
    local isActualStage = curStage == adventureBookData.actualBookStage
    if isActualStage and isComplete then
        return true
    end
    
    local hasCfg, stageTaskCfg = Tables.adventureBookStageRewardTable:TryGetValue(curStage)
    if not hasCfg then
        logger.error("[Adventure Book Stage Reward Table] missing cfg, id = "..curStage)
        return false
    end
    local taskIds = stageTaskCfg.taskIds
    for _, taskId in pairs(taskIds) do
        isComplete = GameInstance.player.adventure:IsTaskComplete(taskId)
        if isComplete then
            return true
        end
    end
    return false
end


function AdventureBookUtils.CheckRedDotAdventureBookTabDaily()
    
    local curDailyActivation = GameInstance.player.adventure.adventureBookData.dailyActivation
    
    local curDailyRewardedActivation = GameInstance.player.adventure.adventureBookData.dailyRewardedActivation
    
    local maxActivation = 0
    for _, cfg in pairs(Tables.dailyActivationRewardTable) do
        if cfg.activation > maxActivation then
            maxActivation = cfg.activation
        end
    end
    
    if curDailyRewardedActivation >= maxActivation then
        return false
    end
    
    local taskDic = GameInstance.player.adventure.adventureBookData.adventureTasks
    for k, v in pairs(Tables.adventureTaskTable) do
        local succ, csTask = taskDic:TryGetValue(k)
        if succ then
            if v.taskType == GEnums.AdventureTaskType.Daily and csTask.isComplete then
                return true
            end
        end
    end
    
    for _, cfg in pairs(Tables.dailyActivationRewardTable) do
        if cfg.activation > curDailyRewardedActivation and cfg.activation <= curDailyActivation then
            return true
        end
    end

    return false
end

function AdventureBookUtils.CheckRedDotAdventureBookTabDungeon()
    
    for seriesId, seriesCfg in pairs(Tables.dungeonSeriesTable) do
        local isUnlocked = seriesCfg.dungeonCategory ~= GEnums.DungeonCategoryType.None and
            seriesCfg.dungeonCategory ~= GEnums.DungeonCategoryType.Train and
                GameInstance.player.adventure:IsAdventureDungeonCategoryTypeUnlocked(seriesId, seriesCfg.dungeonCategory)
        if isUnlocked then
            for _, id in pairs(seriesCfg.includeDungeonIds) do
                if GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true
                end
            end
        end
    end
    
    for groupId, tableData in pairs(Tables.worldEnergyPointGroupTable) do
        local id = GameInstance.player.worldEnergyPointSystem:GetCurSubGameId(groupId)
        local isGameUnread =
            GameInstance.player.subGameSys:IsGameMapMarkUnlock(groupId, GEnums.MarkType.EnemySpawner) and
            GameInstance.player.subGameSys:IsGameUnlocked(id) and
            AdventureBookUtils.CheckEnemySpawnerCanOpenMap(groupId) and
            GameInstance.player.subGameSys:IsGameUnread(id)
        if isGameUnread then
            return true
        end
    end
    return false
end

function AdventureBookUtils.CheckRedDotAdventureBookTabTrain()
    for seriesId, seriesCfg in pairs(Tables.dungeonSeriesTable) do
        if seriesCfg.dungeonCategory == GEnums.DungeonCategoryType.Train then
            for _, id in pairs(seriesCfg.includeDungeonIds) do
                if DungeonUtils.isDungeonUnlock(id) and
                    GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true
                end
            end
        end
    end
    return false
end

function AdventureBookUtils.CheckRedDotAdventureBookTabBlackbox()
    local dungeonMgr = GameInstance.dungeonManager
    for _, cfg in pairs(Tables.domainDataTable) do
        local canShow = true
        local hasCfg, facCfg = Tables.facSTTGroupTable:TryGetValue(cfg.facTechPackageId)
        if not hasCfg then
            logger.error("[Domain Data Table] missing, id = "..cfg.facTechPackageId)
            canShow = false
        end
        
        if canShow then
            local isLock = GameInstance.player.facTechTreeSystem:PackageIsLocked(cfg.facTechPackageId) or
                GameInstance.player.facTechTreeSystem:PackageIsHidden(cfg.facTechPackageId)
            if not isLock then
                local blackboxIds = facCfg.blackboxIds
                for _, blackboxId in pairs(blackboxIds) do
                    
                    local isUnlock = DungeonUtils.isDungeonUnlock(blackboxId)
                    local isActive = DungeonUtils.isDungeonActive(blackboxId)
                    if isActive and isUnlock and not dungeonMgr:IsBlackboxRead(blackboxId) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function AdventureBookUtils.CheckRedDotAdventureBookTabWeekRaid()
    return RedDotManager:GetRedDotState("AdventureBookTabWeekRaid")
end

function AdventureBookUtils.CheckRedDotAdventureBookTabActivity()
    local dataList = AdventureBookUtils.InitActivityDataList()
    for _, data in ipairs(dataList) do
        local redDotName = data.redDotName
        if not string.isEmpty(redDotName) then
            local ret, redDotType, expireTs = RedDotManager:GetRedDotState(redDotName)
            if ret then
                return ret, redDotType, expireTs
            end
        end
    end
    return false
end


function AdventureBookUtils.GetTaskCurrProgress(taskData)
    if taskData.conditionDataList.Count == 1 then
        local condition = taskData.conditionDataList[0]
        local success, value = LuaGameConditionUtils.getConditionValueByParameters(
            condition.conditionType,
            condition.parameters)
        if success then
            return value
        else
            return 0
        end
    else
        local allConditionComplete = true
        for _, condition in pairs(taskData.conditionDataList) do
            local success, value = LuaGameConditionUtils.getConditionValueByParameters(
                condition.conditionType,
                condition.parameters)
            if not success or value < condition.progressToCompare then
                allConditionComplete = false
                break
            end
        end
        return allConditionComplete and 1 or 0
    end
end


function AdventureBookUtils.GetTaskMaxProgress(taskData)
    if taskData.conditionDataList.Count == 1 then
        local condition = taskData.conditionDataList[0]
        return condition.progressToCompare
    else
        return 1
    end
end


function AdventureBookUtils.HaveDungeon()
    local typeList = {
        GEnums.DungeonCategoryType.CharResource,
        GEnums.DungeonCategoryType.BasicResource,
        GEnums.DungeonCategoryType.BossRush,
        GEnums.DungeonCategoryType.SpecialResource,
    }
    
    for _, type in pairs(typeList) do
        local isCategoryUnlocked = GameInstance.player.adventure:IsAdventureDungeonFirCategoryUnlock(type)

        if isCategoryUnlocked then
            return true
        end
    end
    
    for groupId, _ in pairs(Tables.worldEnergyPointGroupTable) do
        local id = GameInstance.player.worldEnergyPointSystem:GetCurSubGameId(groupId)
        local canShow = false
        if GameInstance.player.subGameSys:IsGameMapMarkUnlock(groupId, GEnums.MarkType.EnemySpawner) and
            GameInstance.player.subGameSys:IsGameUnlocked(id) and
            self:_CheckCanOpenMap(groupId) then
            return true
        end
    end

    return false
end

function AdventureBookUtils.CheckEnemySpawnerCanOpenMap(seriesId)
    local hasData, instId = GameInstance.player.mapManager:GetMapMarkInstId(GEnums.MarkType.EnemySpawner, seriesId)
    if not hasData then
        return false
    end

    local data = {}

    local levelId = GameInstance.player.mapManager:GetMarkInstRuntimeDataLevelId(instId)

    data.instId = instId
    data.levelId = levelId

    local ret = MapUtils.checkCanOpenMapAndParseArgs(data)
    return ret
end


function AdventureBookUtils.HaveActivityTab()
    local dataList = AdventureBookUtils.InitActivityDataList()
    for _, data in ipairs(dataList) do
        if data.willShowTab ~= false then
            return true
        end
    end
    return false
end

function AdventureBookUtils.InitActivityDataList()
    local ret = {}
    for id, cfg in pairs(Tables.AdventureActivityDataTable) do
        local type = cfg.type
        local data = AdventureBookUtils.GetActivityDataByType(type)
        data.id = cfg.id
        data.type = cfg.type
        data.name = cfg.name
        data.titleImg = cfg.titleImg
        data.decoImg = cfg.decoImg
        data.bgImg = cfg.bgImg
        data.bgNodeColor = cfg.bgNodeColor

        local rewardInfos = {}
        if cfg.rewardList ~= nil then
            for _, rewardId in pairs(cfg.rewardList) do
                table.insert(rewardInfos, { id = rewardId })
            end
        end
        data.rewardInfos = rewardInfos

        local isShow = data.checkShowFunc()
        if isShow then
            table.insert(ret, data)
        end
    end
    return ret
end

function AdventureBookUtils.GetActivityDataByType(type)
    if type == "WeekRaid" then
        return {
            checkShowFunc = function()
                local ret = Utils.isSystemUnlocked(GEnums.UnlockSystemType.WeekRaidIntro)
                return ret
            end,
            nodeStateName = "Normal",
            setUI = true,
            ClickFunc = function()
                PhaseManager:OpenPhase(PhaseId.DungeonWeeklyRaid)
            end,
            redDotName = "WeekRaidBattlePass",
        }
    elseif type == "HighDifficulty" then
        return {
            checkShowFunc = function()
                local ret = GameInstance.dungeonManager:IsDungeonCategoryUnlocked(
                    DungeonConst.DUNGEON_CATEGORY.HighDifficulty)
                if not ret then
                    return false
                end
                local ids = GameInstance.player.highDifficultySystem:GetAllUnlockSeriesIds()
                return ids.Count > 0
            end,
            nodeStateName = "Normal",
            setUI = true,
            ClickFunc = function()
                PhaseManager:OpenPhase(PhaseId.HighDifficultyMainHud,{})
            end,
        }
    elseif type == "empty" then
        return {
            checkShowFunc = function()
                return true
            end,
            nodeStateName = "EmptyNode",
            setUI = false,
            willShowTab = false,
        }
    else
        return nil
    end
end


_G.AdventureBookUtils = AdventureBookUtils
return AdventureBookUtils