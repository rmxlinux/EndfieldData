local SeasonTowerUtils = {}

local ClientDataManagerInst = ClientDataManagerInst
local GameInstance = GameInstance
local SEASONTOWER_CHECKED_WEEK = "SEASONTOWER_CHECKED_WEEK"
local DateTimeUtils = DateTimeUtils

local RANK_STATE_NAME = {
    [0] = "None",
    [1] = "D",
    [2] = "C",
    [3] = "B",
    [4] = "A",
    [5] = "S",
    [6] = "SS",
}


function SeasonTowerUtils.checkMainRedDot()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    local currentSeasonId = seasonTowerSystem.currentSeasonId
    local currentWeekId = seasonTowerSystem.currentWeekId
    if currentSeasonId <= 0 or currentWeekId <= 0 then
        return false
    end
    
    local weekRecord = seasonTowerSystem.weekRecord
    if weekRecord and weekRecord.starNum > 0 then
        return false
    end
    local id = currentSeasonId * 100 + currentWeekId
    local _, prevId = ClientDataManagerInst:GetInt(SEASONTOWER_CHECKED_WEEK, false)
    return id ~= prevId
end

function SeasonTowerUtils.setMainRedDotChecked()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    local currentSeasonId = seasonTowerSystem.currentSeasonId
    local currentWeekId = seasonTowerSystem.currentWeekId
    if currentSeasonId <= 0 or currentWeekId <= 0 then
        return
    end
    local id = currentSeasonId * 100 + currentWeekId
    ClientDataManagerInst:SetInt(SEASONTOWER_CHECKED_WEEK, id, false, EClientDataTimeValidType.Permanent)
    RedDotManager:TriggerUpdate("SeasonTowerMain")
    Notify(MessageConst.ON_SEASON_TOWER_RED_DOT_SET_FALSE)
end

function SeasonTowerUtils.isNewSeason()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    local currentSeasonId = seasonTowerSystem.currentSeasonId
    local _, prevId = ClientDataManagerInst:GetInt(SEASONTOWER_CHECKED_WEEK, false)
    local prevSeasonId = prevId // 100
    
    local seasonRecord = seasonTowerSystem.seasonRecord
    if seasonRecord and seasonRecord.starNum > 0 then
        return false
    end
    if currentSeasonId > prevId then
        return true
    end
    return false
end

function SeasonTowerUtils.isClosed()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    if GameInstance.player.gameSettingSystem.forbiddenSeasonTower then
        return true
    end
    return false
end

function SeasonTowerUtils.getShouldRefresh()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    if seasonTowerSystem.needRefresh then
        return true
    end
    return false
end

function SeasonTowerUtils.hasAnyAchieveReward()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    return seasonTowerSystem:HasAnyAchieveReward()
end

function SeasonTowerUtils.hasGameAchieveReward(gameId)
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    return seasonTowerSystem:HasAchieveReward(gameId)
end

function SeasonTowerUtils.isFinalWeek()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    return seasonTowerSystem.weekEndTime == seasonTowerSystem.seasonRecord.endTime
end


function SeasonTowerUtils.getRemainTimeText()
    local seasonTowerSystem = GameInstance.player.seasonTowerSystem
    local remainTime = seasonTowerSystem.weekEndTime - DateTimeUtils.GetCurrentTimestampBySeconds()
    return UIUtils.getLeftTime(remainTime)
end

function SeasonTowerUtils.getRankStateName(rank)
    return RANK_STATE_NAME[rank]
end


function SeasonTowerUtils.getStartEndDateString(startTime, endTime)
    return string.format("%s~%s", Utils.timestampToDateYMD(startTime), Utils.timestampToDateYMD(endTime))
end


_G.SeasonTowerUtils = SeasonTowerUtils
return SeasonTowerUtils