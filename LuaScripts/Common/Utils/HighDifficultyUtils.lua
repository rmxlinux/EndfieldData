local HighDifficultyUtils = {}

function HighDifficultyUtils.GetHighDifficultyId(seriesId)
    return GameInstance.player.highDifficultySystem:GetHighDifficultyId(seriesId)
end

function HighDifficultyUtils.GetHighDifficultySeriesIds(seriesId)
    return GameInstance.player.highDifficultySystem:GetHighDifficultySeriesIds(seriesId)
end

function HighDifficultyUtils.GetAllUnlockDisplaySeriesIds()
    return GameInstance.player.highDifficultySystem:GetAllUnlockDisplaySeriesIds()
end

function HighDifficultyUtils.GetBossProgressionBossGroupIds(seriesId)
    return GameInstance.player.highDifficultySystem:GetBossGroupIdsInHighDifficulty(seriesId)
end

function HighDifficultyUtils.IsBossGroupInHighDifficultySeries(bossGroupId, seriesId)
    return GameInstance.player.highDifficultySystem:IsBossGroupInHighDifficulty(bossGroupId, seriesId)
end


function HighDifficultyUtils.GetHighDifficultyName(seriesId)
    local seriesIds = HighDifficultyUtils.GetHighDifficultySeriesIds(seriesId)
    return Tables.HighDifficultySeriesTable[seriesIds[CSIndex(1)]].name
end

function HighDifficultyUtils.GetHighDifficultyAchieveId(seriesId)
    local achievementId = ""
    local seriesIds = HighDifficultyUtils.GetHighDifficultySeriesIds(seriesId)
    for i = 1, seriesIds.Count do
        local seriesIdInHighDifficulty = seriesIds[CSIndex(i)]
        local seriesCfg = Tables.HighDifficultySeriesTable[seriesIdInHighDifficulty]
        if not string.isEmpty(seriesCfg.achieveId) then
            if string.isEmpty(achievementId) then
                achievementId = seriesCfg.achieveId
            elseif achievementId ~= seriesCfg.achieveId then
                logger.error("同一个高难关配置了多个不同的achieveId，hdId=", HighDifficultyUtils.GetHighDifficultyId(seriesId),
                    ", seriesId=", seriesIdInHighDifficulty, ", achieveId=", seriesCfg.achieveId)
            end
        end
    end
    return achievementId
end


function HighDifficultyUtils.isNewHighDifficultyBoss(bossGroupId)
    if string.isEmpty(bossGroupId) then
        return false
    end
    if not GameInstance.player.highDifficultySystem:IsBossGroupUnlocked(bossGroupId) then
        return false
    end
    return not GameInstance.player.highDifficultySystem:IsBossGroupInfoRead(bossGroupId)
end

function HighDifficultyUtils.setFalseNewHighDifficultyBoss(bossGroupId)
    if string.isEmpty(bossGroupId) then
        return
    end
    GameInstance.player.highDifficultySystem:MarkBossGroupInfoRead(bossGroupId)
end


function HighDifficultyUtils.isInLatestHighDifficultyActivity(seriesOrHdId)
    if string.isEmpty(seriesOrHdId) or not HighDifficultyUtils.getHighDifficultyActivityId() then
        return false
    end
    local targetHdId = HighDifficultyUtils.GetHighDifficultyId(seriesOrHdId)
    for _, seriesId in ipairs(HighDifficultyUtils.GetLatestSeriesIds()) do
        if HighDifficultyUtils.GetHighDifficultyId(seriesId) == targetHdId then
            return true
        end
    end
    return false
end


function HighDifficultyUtils.hasNewHighDifficultyBossInSeries(seriesId)
    if string.isEmpty(seriesId) then
        return false
    end
    if not HighDifficultyUtils.isInLatestHighDifficultyActivity(seriesId) then
        return false
    end
    local highDifficultySystem = GameInstance.player.highDifficultySystem
    if not highDifficultySystem:IsBossProgressionSeries(seriesId) then
        return false
    end
    local bossGroupIds = HighDifficultyUtils.GetBossProgressionBossGroupIds(seriesId)
    for i = 1, bossGroupIds.Count do
        if HighDifficultyUtils.isNewHighDifficultyBoss(bossGroupIds[CSIndex(i)]) then
            return true
        end
    end
    return false
end



function HighDifficultyUtils.isNewHighDifficultySeries(seriesId)
    if not HighDifficultyUtils.isInLatestHighDifficultyActivity(seriesId) then
        return false
    end
    local highDifficultySystem = GameInstance.player.highDifficultySystem
    if not highDifficultySystem:IsHighDifficultySeriesUnlock(seriesId) then
        return false
    end

    
    local achievementId = HighDifficultyUtils.GetHighDifficultyAchieveId(seriesId)
    local achievementData = Tables.achievementTable[achievementId]
    local achievementInfos = GameInstance.player.achievementSystem.achievementData.achievementInfos
    local hasAchievementInfo, achievementInfo = achievementInfos:TryGetValue(achievementId)
    if hasAchievementInfo and achievementInfo.level >= achievementData.initLevel then
        return false
    end

    return not highDifficultySystem:IsHighDifficultyDungeonSeriesRead(seriesId)
end
function HighDifficultyUtils.setFalseNewHighDifficultySeries(seriesId)
    if string.isEmpty(seriesId) then
        return
    end
    
    local seriesIds = HighDifficultyUtils.GetHighDifficultySeriesIds(seriesId)
    for i = 1, seriesIds.Count do
       GameInstance.player.highDifficultySystem:MarkHighDifficultyDungeonSeriesRead(seriesIds[CSIndex(i)])
    end
end


local newActivityHighDifficultyTaskText = "new_high_difficulty_task_"
function HighDifficultyUtils.isNewHighDifficultyTask(activityId, taskId)
    return not ClientDataManagerInst:GetBool(newActivityHighDifficultyTaskText .. activityId .. taskId, false)
end
function HighDifficultyUtils.setFalseNewHighDifficultyTask(activityId, taskIds)
    for index, taskId in ipairs(taskIds) do
        ClientDataManagerInst:SetBool(newActivityHighDifficultyTaskText .. activityId .. taskId, true, false, "Default", EClientDataTimeValidType.Permanent)
    end
    Notify(MessageConst.ACTIVITY_HIGH_DIFFICULTY_NEW_TASK_SET_FALSE)
end


function HighDifficultyUtils.getHighDifficultyActivityId()
    local ids = GameInstance.player.activitySystem:GetActivityOfCertainType(GEnums.ActivityType.HighDifficultyChallenge)
    if ids.Count > 0 then
        return ids[0]
    end
    return nil
end


function HighDifficultyUtils.GetLatestSeriesIds()
    local latestSeriesIds = {};
    local latestSortId = 0;
    local allSeriesIds = HighDifficultyUtils.GetAllUnlockDisplaySeriesIds()
    for i = 1, allSeriesIds.Count do
        local seriesId = allSeriesIds[CSIndex(i)]
        local sortId = Tables.highDifficultySeriesTable[seriesId].newSeriesSortId;
        if (sortId >= latestSortId) then
            if (sortId > latestSortId) then
                latestSeriesIds = {}
            end
            table.insert(latestSeriesIds, seriesId)
            latestSortId = sortId
        end
    end
    return latestSeriesIds
end


function HighDifficultyUtils.GetSeriesInfo(seriesId)
    local seriesCfg = Tables.highDifficultyGameTable[seriesId]
    local seriesInfo = {}
    for _, dungeonInfo in pairs(seriesCfg.gameList) do
        if not Tables.dungeonRaidTable[dungeonInfo.gameId].isRaid then
            local normalId = dungeonInfo.gameId
            local raidId = Tables.dungeonRaidTable[normalId].RelatedLevel
            table.insert(seriesInfo, {
                normalId = normalId,
                raidId = raidId,
                raidUnlocked = GameInstance.dungeonManager:IsDungeonUnlocked(raidId),
                raidPassed = GameInstance.dungeonManager:IsDungeonPassed(raidId),
                sortId = dungeonInfo.sortId,
            })
        end
    end
    table.sort(seriesInfo,Utils.genSortFunction({ "sortId" }, true))
    return seriesInfo
end


_G.HighDifficultyUtils = HighDifficultyUtils
return HighDifficultyUtils