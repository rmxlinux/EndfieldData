local ActivityUtils = {}



local newHintText = "new_activity_key_"
function ActivityUtils.isNewActivity(id)
    return not ClientDataManagerInst:GetBool(newHintText .. id,false)
end
function ActivityUtils.setFalseNewActivity(id)
    ClientDataManagerInst:SetBool(newHintText .. id, true, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local newActivityUnlockText = "new_activity_unlock_key_"
function ActivityUtils.isNewUnlockActivity(id)
    return ActivityUtils.isActivityUnlocked(id) and not ClientDataManagerInst:GetBool(newActivityUnlockText .. id,false)
end
function ActivityUtils.setFalseNewUnlockActivity(id)
    ClientDataManagerInst:SetBool(newActivityUnlockText .. id, true, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local newIntroText = "new_activity_intro_mission_key_"
function ActivityUtils.isNewIntroMissionActivity(id)
    return GameInstance.player.activitySystem:GetActivityStatus(id) == GEnums.ActivityStatus.IntroMission and not ClientDataManagerInst:GetBool(newIntroText .. id, false)
end
function ActivityUtils.setFalseIntroMissionActivity(id)
    ClientDataManagerInst:SetBool(newIntroText .. id, true, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


function ActivityUtils.checkActivityRedDot(id)
    if ActivityUtils.isNewUnlockActivity(id) then
        return true, UIConst.RED_DOT_TYPE.Normal
    end
    if ActivityUtils.isNewIntroMissionActivity(id) then
        return true, UIConst.RED_DOT_TYPE.Normal
    end
    if ActivityUtils.isNewActivity(id) then
        return true, UIConst.RED_DOT_TYPE.New
    end
    return false
end


local newConditionalStageText = "new_activity_conditional_stage_key_"
function ActivityUtils.isNewActivityConditionalStage(stageId)
    return not ClientDataManagerInst:GetBool(newConditionalStageText .. stageId, false)
end
function ActivityUtils.setFalseNewActivityConditionalStage(stageId)
    ClientDataManagerInst:SetBool(newConditionalStageText .. stageId, false, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_READ_ACTIVITY_CONDITION_STAGE, stageId)
end


local newGameEntranceSeriesKeyPrefix = "new_activity_game_entrance_series"
function ActivityUtils.isNewGameEntranceSeries(seriesId)
    return not ClientDataManagerInst:GetBool(newGameEntranceSeriesKeyPrefix .. seriesId, false)
end
function ActivityUtils.setFalseNewGameEntranceSeries(seriesId)
    ClientDataManagerInst:SetBool(newGameEntranceSeriesKeyPrefix .. seriesId, false, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_READ_GAME_ENTRANCE_SERIES, seriesId)
end


local newCharacterGuideLineKeyPrefix = "new_activity_character_guideline_"
function ActivityUtils.isNewUnlockCharacterGuideLine(activityId)
    return ActivityUtils.isActivityUnlocked(activityId) and not ClientDataManagerInst:GetBool(newCharacterGuideLineKeyPrefix .. activityId, false)
end
function ActivityUtils.setFalseNewUnlockCharacterGuideLine(activityId)
    ClientDataManagerInst:SetBool(newCharacterGuideLineKeyPrefix .. activityId, false, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local newActivityDayText = "new_activity_day_"
function ActivityUtils.isNewActivityDay(activityId, totalDays)
    activityId = ActivityUtils.getResetableActivityRealId(activityId)
    local date = DateTimeUtils.GetNextCrossDayTime(DateTimeUtils.GetServerDateTime())
    local id = newActivityDayText .. activityId .. tostring(date)
    if totalDays then
        local _,days = ClientDataManagerInst:GetInt(newActivityDayText .. activityId, false)
        if days < 0 then
             ClientDataManagerInst:SetInt(newActivityDayText .. activityId, 0, false, EClientDataTimeValidType.Permanent)
        end
        if days >= totalDays then
            return false
        end
    end
    return not ClientDataManagerInst:GetBool(id, false)
end
function ActivityUtils.setFalseNewActivityDay(activityId)
    activityId = ActivityUtils.getResetableActivityRealId(activityId)
    if not ActivityUtils.isNewActivityDay(activityId) then
        return
    end
    local date = DateTimeUtils.GetNextCrossDayTime(DateTimeUtils.GetServerDateTime())
    local id = newActivityDayText .. activityId .. tostring(date)
    ClientDataManagerInst:SetBool(id, true, false, EClientDataTimeValidType.Permanent)
    local _,days = ClientDataManagerInst:GetInt(newActivityDayText .. activityId, false)
    if days then
        ClientDataManagerInst:SetInt(newActivityDayText .. activityId, days + 1, false, EClientDataTimeValidType.Permanent)
    end
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local popUpText = "_new_activity_pop_up_"
function ActivityUtils.notPopupToday(id,day)
    return not ClientDataManagerInst:GetBool(id .. popUpText ..tostring(day),false)
end
function ActivityUtils.setFalsePopupToday(id,day)
    ClientDataManagerInst:SetBool(id .. popUpText ..tostring(day) , true, false, EClientDataTimeValidType.Permanent)
end


local newBubbleText = "new_activity_bubble_key_"
function ActivityUtils.isNewActivityBubble(id)
    id = ActivityUtils.getResetableActivityRealId(id)
    return not ClientDataManagerInst:GetBool(newBubbleText .. id,false)
end
function ActivityUtils.setFalseNewActivityBubble(id)
    id = ActivityUtils.getResetableActivityRealId(id)
    ClientDataManagerInst:SetBool(newBubbleText .. id, true, false, EClientDataTimeValidType.Permanent)
end



function ActivityUtils.getResetableActivityRealId(activityId)
    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    if activity and activity.type == GEnums.ActivityType.Reflow:GetHashCode() then
        return activityId .. tostring(activity.endTime)
    end
    return activityId
end



function ActivityUtils.isActivityUnlocked(id)
    local activity = GameInstance.player.activitySystem:GetActivity(id)
    return activity and (activity.status == GEnums.ActivityStatus.InProgress or activity.status == GEnums.ActivityStatus.Completed) or false
end

function ActivityUtils.hasIntroMissionAndComplete(id)
    local activity = GameInstance.player.activitySystem:GetActivity(id)
    return activity and (activity.hasIntroMission and ActivityUtils.isActivityUnlocked(id)) or false
end

function ActivityUtils.getNaviConfig(panel, type)
    local rightNaviGroup
    local forbidCommonNavi = false
    if panel.uiCtrl.view.rightNaviGroup then
        rightNaviGroup = panel.uiCtrl.view.rightNaviGroup
        forbidCommonNavi = panel.uiCtrl.view.activityCommonInfo.view.config.FORBID_COMMON_NAVI
    elseif type == GEnums.ActivityType.Checkin then
        rightNaviGroup = panel.uiCtrl.m_checkInWidget.m_scrollNaviGroup
        forbidCommonNavi = panel.uiCtrl.m_checkInWidget.view.activityCommonInfo.view.config.FORBID_COMMON_NAVI
    elseif type == GEnums.ActivityType.VersionGuide then
        rightNaviGroup = panel.uiCtrl.m_versionGuide.view.selectableNaviGroup
        forbidCommonNavi = panel.uiCtrl.m_versionGuide.view.activityCommonInfo.view.config.FORBID_COMMON_NAVI
    end
    return { rightNaviGroup, forbidCommonNavi}
end




function ActivityUtils.getPopUpIds()
    local popUpIds = {}
    
    local activities = GameInstance.player.activitySystem:GetAllActivities()
    local str = "ActivityPopup popupIds are: "
    for _, activity in cs_pairs(activities) do
        local id = activity.id
        local _, activityData = Tables.activityTable:TryGetValue(id)
        if activityData ~= nil and activityData.popUpSortId > 0 and ActivityUtils.shouldPopup(id) then
            table.insert(popUpIds,id)
            str = str .. id .. " "
        end
    end
    logger.info(str)
    table.sort(popUpIds, function(a, b)
        return Tables.activityTable[a].popUpSortId < Tables.activityTable[b].popUpSortId
    end)
    return popUpIds
end


function ActivityUtils.shouldPopup(id)
    local activity = GameInstance.player.activitySystem:GetActivity(id)
    local notPopupToday

    
    if GEnums.ActivityType.__CastFrom(activity.type) ~= (GEnums.ActivityType.Checkin) then
        if Tables.activityTable[id].popUpOnlyOnce then
            
            notPopupToday = ActivityUtils.notPopupToday(id, 1)
            return notPopupToday
        else
            
            notPopupToday = ActivityUtils.isNewActivityDay(id)
            return notPopupToday
        end
    end

    
    notPopupToday = ActivityUtils.notPopupToday(id, activity.loginDays)
    if notPopupToday and activity.loginDays ~= activity.rewardDays.Count then
        local rewardDaysSet = {}
        for i = 1, activity.rewardDays.Count do
            rewardDaysSet[activity.rewardDays[CSIndex(i)]] = true
        end

        for day = 1, activity.loginDays do
            if Tables.checkInRewardTable[id].stageList[CSIndex(day)].isPopup and not rewardDaysSet[day] then
                return true
            end
        end
    end
    return false
end


function ActivityUtils.recordPopup(id)
    local activity = GameInstance.player.activitySystem:GetActivity(id)

    
    if GEnums.ActivityType.__CastFrom(activity.type) ~= (GEnums.ActivityType.Checkin) then
        if Tables.activityTable[id].popUpOnlyOnce then
            
            ActivityUtils.setFalsePopupToday(id, 1)
        else
            
            ActivityUtils.setFalseNewActivityDay(id)
        end
        return
    end

    
    if activity.loginDays ~= activity.rewardDays.Count then
        local rewardDaysSet = {}
        for i = 1, activity.rewardDays.Count do
            rewardDaysSet[activity.rewardDays[CSIndex(i)]] = true
        end

        for day = 1, activity.loginDays do
            if Tables.checkInRewardTable[id].stageList[CSIndex(day)].isPopup and not rewardDaysSet[day] then
                ActivityUtils.setFalsePopupToday(id, activity.loginDays)
                return
            end
        end
    end
end

function ActivityUtils.getActivityRedDotName(id)
    
    local suc, activityData = Tables.activityTable:TryGetValue(id)
    if not suc then
        return nil
    end
    if not string.isEmpty(activityData.redDotName) then
        return activityData.redDotName
    elseif ActivityConst.ACTIVITY_TABLE[activityData.type] and ActivityConst.ACTIVITY_TABLE[activityData.type].redDot then
        return ActivityConst.ACTIVITY_TABLE[activityData.type].redDot
    end
    return nil
end




function ActivityUtils.StaminaDiscount(stamina)
    local staminaAfterDiscount = math.max(stamina - GameInstance.player.activitySystem.staminaDiscount, 0)
    return staminaAfterDiscount
end

function ActivityUtils.getRealStaminaCost(stamina)
    if not ActivityUtils.hasStaminaReduceCount() then
        return stamina
    end

    return math.max(0, stamina - GameInstance.player.activitySystem.staminaDiscount)
end

function ActivityUtils.isActivityStaminaReduce()
    return GameInstance.player.activitySystem.staminaTotalCount > 0
end

function ActivityUtils.hasStaminaReduceCount()
    local activity = GameInstance.player.activitySystem
    return activity.staminaTotalCount > activity.staminaReduceUsedCount
end


function ActivityUtils.getStaminaReduceInfo()
    local activitySystem = GameInstance.player.activitySystem
    local totalCount = activitySystem.staminaTotalCount
    local disCount = activitySystem.staminaDiscount
    local usedCount = activitySystem.staminaReduceUsedCount
    local activityIsOn = totalCount > 0
    local hasTimes = totalCount > usedCount

    return {
        activityIsOn = activityIsOn,
        hasTimes = hasTimes,
        activityUsable = activityIsOn and hasTimes,
        totalCount = totalCount,
        disCount = disCount,
        usedCount = usedCount,
    }
end

function ActivityUtils.showStaminaReduceProgress()
    local reduceInfo = ActivityUtils.getStaminaReduceInfo()
    local usedCount = reduceInfo.usedCount
    local totalCount = reduceInfo.totalCount
    local remainCount = totalCount - usedCount
    local colorStr = remainCount == 0 and UIConst.COUNT_RED_COLOR_STR or "85E272"
    Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_STAMINA_REDUCE_PROGRESS_HINT_FORMAT, colorStr, remainCount, totalCount))
end





function ActivityUtils.GameEventLogActivityEnter(enterType, activityId)
    EventLogManagerInst:GameEvent_ActivityEnter(enterType, activityId)
end


function ActivityUtils.GameEventLogActivityVisit(activityId, buttonId, visitStatus)
    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activity then
        return
    end
    local templateId = activity.typeName
    local panelId = Tables.activityTable[activityId].panelId
    EventLogManagerInst:GameEvent_ActivityVisit(templateId, activityId, panelId, buttonId, visitStatus)
end


function ActivityUtils.GameEventLogActivityRankView(activityId)
    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activity then
        return
    end
    local templateId = activity.typeName
    
    local rankId = ""
    local rankType = ""
    local rankInfo = {
        rank = 1,
        roleId = tonumber(GameInstance.player.playerInfoSystem.roleId),
        passTime = 0,
    }
    EventLogManagerInst:GameEvent_ActivityRankView(templateId, activityId, rankId, rankType, rankInfo)
end





_G.ActivityUtils = ActivityUtils
return ActivityUtils








