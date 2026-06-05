local ActivityUtils = {}



local newHintText = "new_activity_key_"
function ActivityUtils.isNewActivity(id)
    
    
    
    
    return not ClientDataManagerInst:GetBool(newHintText .. id, false)
end
function ActivityUtils.setFalseNewActivity(id, noSave)
    if noSave then
        
        ClientDataManagerInst:SetBool(newHintText .. id, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newHintText .. id, true, false)
    end
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local newActivityUnlockText = "new_activity_unlock_key_"
function ActivityUtils.isNewUnlockActivity(id)
    return ActivityUtils.isActivityUnlocked(id) and not ClientDataManagerInst:GetBool(newActivityUnlockText .. id, false)
end
function ActivityUtils.setFalseNewUnlockActivity(id, noSave)
    if noSave then
        
        ClientDataManagerInst:SetBool(newActivityUnlockText .. id, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newActivityUnlockText .. id, true, false)
    end
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


local newIntroText = "new_activity_intro_mission_key_"
function ActivityUtils.isNewIntroMissionActivity(id)
    return GameInstance.player.activitySystem:GetActivityStatus(id) == GEnums.ActivityStatus.IntroMission and not ClientDataManagerInst:GetBool(newIntroText .. id, false)
end
function ActivityUtils.setFalseIntroMissionActivity(id, noSave)
    if noSave then
        
        ClientDataManagerInst:SetBool(newIntroText .. id, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newIntroText .. id, true, false)
    end
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
function ActivityUtils.setFalseNewActivityConditionalStage(stageId, noSave)
    if noSave then
        
        ClientDataManagerInst:SetBool(newConditionalStageText .. stageId, false, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newConditionalStageText .. stageId, false, false)
    end
    Notify(MessageConst.ON_READ_ACTIVITY_CONDITION_STAGE, stageId)
end



function ActivityUtils.isNewActivityConditionalStageByTime(activityId, stageId)
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    local activityStartTime = activityData.startTime
    local currTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    local _, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(activityId)
    for cfgStageId, stageCfg in pairs(multiStageCfg.stageList) do
        if cfgStageId == stageId then
            local timeId = stageCfg.timeId
            if Utils.isCurTimeInTimeIdRange(timeId) then
                return not ClientDataManagerInst:GetBool(newConditionalStageText .. stageId, false)
            end
        end
    end
    return false
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




local newActivityDayText = "new_activity_day_bool_"
local newActivityDayCountText = "new_activity_day_"
function ActivityUtils.isNewActivityDayUnread(activityId, totalDays)
    activityId = ActivityUtils.getResetableActivityRealId(activityId)
    local id = newActivityDayText .. activityId
    if totalDays then
        local countId = newActivityDayCountText .. activityId
        local _, days = ClientDataManagerInst:GetInt(countId, false)
        if days < 0 then
            ClientDataManagerInst:SetInt(countId, 0, false, EClientDataTimeValidType.Permanent)
        end
        if days >= totalDays then
            return false
        end
    end
    return not ClientDataManagerInst:GetBool(id, false)
end
function ActivityUtils.setActivityDayAsRead(activityId, noSave)
    activityId = ActivityUtils.getResetableActivityRealId(activityId)
    if not ActivityUtils.isNewActivityDayUnread(activityId) then
        return
    end
    local id = newActivityDayText .. activityId
    
    if noSave then
        ClientDataManagerInst:SetBool(id, true, false, ClientDataManagerInst.defaultCategory, false, EClientDataTimeValidType.CurrentDayUntil4AM)
    else
        ClientDataManagerInst:SetBool(id, true, false, EClientDataTimeValidType.CurrentDayUntil4AM)
    end
    
    local countId = newActivityDayCountText .. activityId
    local _, days = ClientDataManagerInst:GetInt(countId, false)
    if days then
        ClientDataManagerInst:SetInt(countId, days + 1, false, EClientDataTimeValidType.Permanent, false) 
    end
    Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
end


function ActivityUtils.CheckMultiStageHaveCompletedStatus(activityId)
    local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(activityId)
    if not haveCfg then
        return false
    end
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activityData then
        return false
    end
    for stageId, stageCfg in pairs(multiStageCfg.stageList) do
        
        local csConditionalStageInfo = activityData:GetStageData(stageId)
        if csConditionalStageInfo ~= nil then
            local status = GEnums.ActivityConditionalStageState.__CastFrom(csConditionalStageInfo.Status)
            if status == GEnums.ActivityConditionalStageState.Completed then
                return true
            end
        end
    end
end


local popUpText = "_new_activity_pop_up_"
function ActivityUtils.shouldPopupToday(id, day)
    return not ClientDataManagerInst:GetBool(id .. popUpText .. tostring(day), false)
end
function ActivityUtils.setPopedupToday(id, day)
    ClientDataManagerInst:SetBool(id .. popUpText .. tostring(day), true, false, EClientDataTimeValidType.Permanent)
end


local newBubbleText = "new_activity_bubble_key_"
function ActivityUtils.isNewActivityBubble(id)
    id = ActivityUtils.getResetableActivityRealId(id)
    return not ClientDataManagerInst:GetBool(newBubbleText .. id, false)
end
function ActivityUtils.setFalseNewActivityBubble(id, noSave)
    id = ActivityUtils.getResetableActivityRealId(id)
    if noSave then
        ClientDataManagerInst:SetBool(newBubbleText .. id, true, false, ClientDataManagerInst.defaultCategory)
    else
        ClientDataManagerInst:SetBool(newBubbleText .. id, true, false)
    end
end







local activityEndTabRedDotSeenText = "activity_end_tab_seen_key_"
function ActivityUtils.isActivityEndTabRedDotSeen(pushID)
    if string.isEmpty(pushID) then
        return true
    end
    return ClientDataManagerInst:GetBool(activityEndTabRedDotSeenText .. pushID, false)
end
function ActivityUtils.setActivityEndTabRedDotSeen(pushID, noSave)
    if string.isEmpty(pushID) then
        return
    end
    if noSave then
        ClientDataManagerInst:SetBool(activityEndTabRedDotSeenText .. pushID, true, false, ClientDataManagerInst.defaultCategory)
    else
        ClientDataManagerInst:SetBool(activityEndTabRedDotSeenText .. pushID, true, false)
    end
end
function ActivityUtils.clearActivityEndTabRedDotSeen(pushID, noSave)
    if string.isEmpty(pushID) then
        return
    end
    if noSave then
        ClientDataManagerInst:SetBool(activityEndTabRedDotSeenText .. pushID, false, false, ClientDataManagerInst.defaultCategory)
    else
        ClientDataManagerInst:SetBool(activityEndTabRedDotSeenText .. pushID, false, false)
    end
end


local newDebugBubbleText = "new_debug_activity_bubble_key"
function ActivityUtils.getDebugActivityBubbleId()
    local success, activityId = ClientDataManagerInst:GetString(newDebugBubbleText, false)
    if success and not string.isEmpty(activityId) then
        ClientDataManagerInst:SetString(newDebugBubbleText, "", false, EClientDataTimeValidType.Permanent)
        return activityId
    end
    return
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
    return { rightNaviGroup, forbidCommonNavi }
end

function ActivityUtils.actionWhenActivityClosed(action, ctrl, activityId)
    MessageManager:Register(MessageConst.ON_ACTIVITY_UPDATED, function(args)
        local id = unpack(args)
        if id ~= activityId then
            return
        end
        local activity = GameInstance.player.activitySystem:GetActivity(id)
        if not activity then
            action(true)
        end
    end, ctrl)
end


function ActivityUtils.backToMainHud(noToast)
    GameInstance.player.guide:OnActivityDisabled()
    UIManager:Close(PanelId.ActivityStartReminderPopup)
    UIManager:Close(PanelId.InstructionBook)
    if not noToast then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_FORBIDDEN)
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU,
        hideCancel = true,
        onConfirm = function()
            PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
        end
    })
end


function ActivityUtils.backToMainHudWhenActivityClosed(ctrl, activityId)
    ActivityUtils.actionWhenActivityClosed(ActivityUtils.backToMainHud, ctrl, activityId)
end




function ActivityUtils.isFinalStageMultiConditionStageActivity(activityData, finalStageId)
    
    local stageData = activityData:GetStageData(finalStageId)
    local isFinalStage = false
    if stageData then
        local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
        if status ~= GEnums.ActivityConditionalStageState.Locked then
            isFinalStage = true
        end
    end
    return isFinalStage
end




function ActivityUtils.isStageUnlockMultiConditionStageActivity(activityData, stageId)
    
    local stageData = activityData:GetStageData(stageId)
    if stageData then
        local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
        if status ~= GEnums.ActivityConditionalStageState.Locked then
            return true
        end
    end
    return false
end




function ActivityUtils.GetFoodSubmitStageState(activityId, stageId)
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    local status = GEnums.ActivityConditionalStageState.Locked
    if not activityData then
        return status
    end
    local stageData = activityData:GetStageData(stageId)
    if stageData ~= nil then
        status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
    end
    return status
end

function ActivityUtils.GetFoodSubmitCurGoToRedDot()
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds() + Utils.getServerTimeZoneOffsetSeconds()
    local curDate = os.date("!*t", curTime)
    local year = curDate.year
    local month = curDate.month
    local day = curDate.day
    if curDate.hour < UIConst.COMMON_SERVER_UPDATE_TIME then
        day = day - 1
    end

    return year * 10000 + month * 100 + day
end





function ActivityUtils.IsSimulationTrainingGotoDetailRead()
    return ClientDataManagerInst:GetBool("activity_simulation_training_goto_detail", false)
end
function ActivityUtils.SetSimulationTrainingGotoDetailRead()
    ClientDataManagerInst:SetBool("activity_simulation_training_goto_detail", true, false, EClientDataTimeValidType.Permanent)
    Notify(MessageConst.ON_ACTIVITY_SIMULATION_TRAINING_GOTO)
end




function ActivityUtils.getPopUpIds()
    local popUpIds = {}
    
    local activities = GameInstance.player.activitySystem:GetAllActivities()
    local str = "ActivityPopup popupIds are: "
    for _, activity in cs_pairs(activities) do
        local id = activity.id
        local _, activityData = Tables.activityTable:TryGetValue(id)
        if activityData ~= nil and activityData.popUpSortId > 0 and ActivityUtils.shouldPopup(id) then
            table.insert(popUpIds, id)
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
    if not activity then
        return
    end
    local shouldPopupToday

    
    if GEnums.ActivityType.__CastFrom(activity.type) == (GEnums.ActivityType.ArknightsXEndfieldLightWeight) then
        local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(id)
        if not haveCfg then
            return false
        end
        local activityData = GameInstance.player.activitySystem:GetActivity(id)
        local res = false
        local arkNightsBirthText = "activity_arknights_birth_"
        
        local maskStageId = ''
        for stageId, _ in pairs(multiStageCfg.stageList) do
            local hasBirthCfg, birthStageCfg = Tables.activityArknightsBirthMultiStageTable:TryGetValue(stageId)
            if hasBirthCfg and not birthStageCfg.isVisible then
                maskStageId = stageId
            end
        end
        for stageId, _ in pairs(multiStageCfg.stageList) do
            local hasBirthCfg, birthStageCfg = Tables.activityArknightsBirthMultiStageTable:TryGetValue(stageId)
            if not hasBirthCfg then
                goto continue
            end
            
            if not birthStageCfg.isVisible then
                goto continue
            end
            
            local csConditionalStageInfo = activityData:GetStageData(stageId)
            if csConditionalStageInfo ~= nil then
                local status = GEnums.ActivityConditionalStageState.__CastFrom(csConditionalStageInfo.Status)
                local popupPanelId = birthStageCfg.popupPanelId
                
                if status ~= GEnums.ActivityConditionalStageState.Locked then
                    local ok, popped, removed = ClientDataManagerInst:GetBool(arkNightsBirthText .. popupPanelId, false)
                    if maskStageId ~= '' then
                        local maskCsConditionalStageInfo = activityData:GetStageData(maskStageId)
                        if maskCsConditionalStageInfo ~= nil then
                            local maskStatus = GEnums.ActivityConditionalStageState.__CastFrom(maskCsConditionalStageInfo.Status)
                            
                            if not popped or maskStatus ~= GEnums.ActivityConditionalStageState.Rewarded then
                                res = true
                            end
                        end
                    end
                end
            end
            :: continue ::
        end
        return res
    end

    
    if GEnums.ActivityType.__CastFrom(activity.type) == (GEnums.ActivityType.CalendarCheckin) then
        local activityData = GameInstance.player.activitySystem:GetActivity(id)
        if activityData == nil then
            return false
        end
        local _, haveGotReward, allGetReward = ActivityUtils.CalendarCheckInGetCurDayNumber(id)
        return not haveGotReward and not allGetReward
    end

    
    if GEnums.ActivityType.__CastFrom(activity.type) ~= (GEnums.ActivityType.Checkin) then
        if Tables.activityTable[id].popUpOnlyOnce then
            
            shouldPopupToday = ActivityUtils.shouldPopupToday(id, 1)
            return shouldPopupToday
        else
            
            shouldPopupToday = ActivityUtils.isNewActivityDayUnread(id)
            return shouldPopupToday
        end
    end

    
    shouldPopupToday = ActivityUtils.shouldPopupToday(id, activity.loginDays)
    if shouldPopupToday and activity.loginDays ~= activity.rewardDays.Count then
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
    if not activity then
        return
    end

    
    if GEnums.ActivityType.__CastFrom(activity.type) == (GEnums.ActivityType.ArknightsXEndfieldLightWeight) then
        local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(id)
        if not haveCfg then
            return false
        end
        local activityData = GameInstance.player.activitySystem:GetActivity(id)
        local res = false
        local arkNightsBirthText = "activity_arknights_birth_"
        for stageId, _ in pairs(multiStageCfg.stageList) do
            local hasBirthCfg, birthStageCfg = Tables.activityArknightsBirthMultiStageTable:TryGetValue(stageId)
            if not hasBirthCfg then
                goto continue
            end
            
            if not birthStageCfg.isVisible then
                goto continue
            end
            
            local csConditionalStageInfo = activityData:GetStageData(stageId)
            if csConditionalStageInfo ~= nil then
                local status = GEnums.ActivityConditionalStageState.__CastFrom(csConditionalStageInfo.Status)
                local popupPanelId = birthStageCfg.popupPanelId
                
                if status == GEnums.ActivityConditionalStageState.Locked then
                    ClientDataManagerInst:SetBool(arkNightsBirthText .. popupPanelId, false, false, EClientDataTimeValidType.Permanent)
                else 
                    local ok, popped, removed = ClientDataManagerInst:GetBool(arkNightsBirthText .. popupPanelId, false)
                    if not popped then 
                        ClientDataManagerInst:SetBool(arkNightsBirthText .. popupPanelId, true, false, EClientDataTimeValidType.Permanent)
                    end
                end
            end
            :: continue ::
        end
        return
    end

    
    if GEnums.ActivityType.__CastFrom(activity.type) ~= (GEnums.ActivityType.Checkin) then
        if Tables.activityTable[id].popUpOnlyOnce then
            
            ActivityUtils.setPopedupToday(id, 1)
        else
            
            ActivityUtils.setActivityDayAsRead(id)
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
                ActivityUtils.setPopedupToday(id, activity.loginDays)
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





function ActivityUtils.CalendarCheckInGetGetMaxDayNumber(activityId)
    local _, cfgData = Tables.checkInInfoTable:TryGetValue(activityId)
    if cfgData == nil then
        return 0
    end
    return cfgData.maxRewardCnt
end



function ActivityUtils.CalendarCheckInGetCurDayNumber(activityId)
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    if activityData == nil then
        return 0, false, false
    end
    local rewardDays = activityData.rewardDays
    local curDayRewarded = activityData.curDayRewarded
    local maxDays = ActivityUtils.CalendarCheckInGetGetMaxDayNumber(activityId)
    
    if rewardDays >= maxDays then
        
        return maxDays, curDayRewarded, true
    end
    if curDayRewarded then
        return rewardDays, true, false
    else
        return rewardDays + 1, false, false
    end
end

function ActivityUtils.CalendarCheckInGetDailyReward(activityId)
    local stageList = Tables.CheckInRewardTable[activityId].stageList
    local curDayNumber = ActivityUtils.CalendarCheckInGetCurDayNumber(activityId)
    local rewardId = stageList[CSIndex(curDayNumber)].rewardId
    local rewardBundles = UIUtils.getRewardItems(rewardId)
    local rewardInfoList = {}
    for i, v in ipairs(rewardBundles) do
        table.insert(rewardInfoList, {
            rewardId = v.id,
            number = v.count,
        })
    end
    return rewardInfoList
end

function ActivityUtils.CalendarCheckInGetAllReward(activityId)
    local rewardInfoList = {}
    local stageList = Tables.CheckInRewardTable[activityId].stageList
    local maxDays = ActivityUtils.CalendarCheckInGetGetMaxDayNumber(activityId)
    for i = 1, maxDays do
        local rewardId = stageList[CSIndex(i)].rewardId
        local rewardBundles = UIUtils.getRewardItems(rewardId)
        for _, v in ipairs(rewardBundles) do
            local id = v.id
            local found = lume.match(rewardInfoList, function(info)
                return info.rewardId == id
            end)
            if found then
                found.number = found.number + v.count
            else
                table.insert(rewardInfoList, {
                    rewardId = v.id,
                    number = v.count,
                })
            end
        end
    end
    return rewardInfoList
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


function ActivityUtils.GameEventLogActivityRankView(activityId, rankRelatedId, rankInfo)
    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activity then
        return
    end
    local templateId = activity.typeName
    EventLogManagerInst:GameEvent_ActivityRankView(templateId, activityId, rankRelatedId, "", rankInfo)
end





function ActivityUtils.GetSnapshotChallengeMainNodePath(activityId)
    local _, cfg = Tables.activitySnapshotChallengeMainTable:TryGetValue(activityId)
    local mainPrefabName = cfg.mainPrefabName
    local path = string.format("Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Activity/SnapshotChallenge/%s.prefab", mainPrefabName)
    return path
end




local newCCTagRead = "IS_CC_NEW_TAG_READ_"
function ActivityUtils.setCcTagRead(tagId, noSave)
    local _, isRead = ActivityUtils.isCcTagRead(tagId)
    if isRead then
        return
    end
    if noSave then
        
        ClientDataManagerInst:SetBool(newCCTagRead .. tagId, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newCCTagRead .. tagId, true, false)
    end
    Notify(MessageConst.ON_CC_NEW_TAG_READ, tagId)
end

function ActivityUtils.isCcTagRead(tagId)
    local _, isRead = ClientDataManagerInst:GetBool(newCCTagRead .. tagId, false)
    return isRead
end


local firstCcEnterSelectAfterUpdate = "IS_CC_FIRST_ENTER_"
function ActivityUtils.setCcFirstEnterSelectAfterUpdate(stageId, noSave)
    if noSave then
        
        ClientDataManagerInst:SetBool(firstCcEnterSelectAfterUpdate .. stageId, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(firstCcEnterSelectAfterUpdate .. stageId, true, false)
    end
    Notify(MessageConst.ON_CC_FIRST_ENTER_SELECT_AFTER_UPDATE, stageId)
end

function ActivityUtils.isCcFirstEnterSelectAfterUpdate(stageId)
    return ClientDataManagerInst:GetBool(firstCcEnterSelectAfterUpdate .. stageId, false)
end


local newCCTaskText = "IS_CC_NEW_TASK_READ"
function ActivityUtils.setCcNewTaskRead(activityId, taskId, noSave)
    if not ActivityUtils.isCcNewTask(activityId, taskId) then
        return
    end
    if noSave then
        
        ClientDataManagerInst:SetBool(newCCTaskText .. taskId, true, false, ClientDataManagerInst.defaultCategory)
    else
        
        ClientDataManagerInst:SetBool(newCCTaskText .. taskId, true, false)
    end
    Notify(MessageConst.ON_CC_NEW_TASK_READ, taskId)
end

function ActivityUtils.isCcNewTask(activityId, taskId)
    local unlockTime = Tables.activityConditionalMultiStageTaskConfigTable[activityId].TaskConfigMap[taskId].unlockTimeId
    
    if string.isEmpty(unlockTime) then
        return false
    end
    return not ClientDataManagerInst:GetBool(newCCTaskText .. taskId, false)
end



local newSimulationTrainingTaskText = "IS_SIMULATION_TRAINING_NEW_TASK_READ"
function ActivityUtils.setSimulationTrainingTaskRead(activityId, taskId, noSave)
    if not ActivityUtils.isSimulationTrainingNewTask(activityId, taskId) then
        return
    end
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activityData or activityData.status == GEnums.ActivityStatus.Locked then
        return
    end
    if noSave then
        ClientDataManagerInst:SetBool(newSimulationTrainingTaskText .. taskId, true, false, ClientDataManagerInst.defaultCategory)
    else
        ClientDataManagerInst:SetBool(newSimulationTrainingTaskText .. taskId, true, false)
    end
    Notify(MessageConst.ON_SIMULATION_TRAINING_TASK_READ, taskId)
end

function ActivityUtils.isSimulationTrainingNewTask(activityId, taskId)
    return not ClientDataManagerInst:GetBool(newSimulationTrainingTaskText .. taskId, false)
end



_G.ActivityUtils = ActivityUtils
return ActivityUtils








