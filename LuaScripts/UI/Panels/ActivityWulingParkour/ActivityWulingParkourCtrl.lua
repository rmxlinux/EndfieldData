
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityWulingParkour

ActivityWulingParkourCtrl = HL.Class('ActivityWulingParkourCtrl', uiCtrl.UICtrl)

ActivityWulingParkourCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = '_OnStageUpdate',
    [MessageConst.ON_SUB_GAME_READ] = '_OnDungeonRead',
    [MessageConst.ON_ACTIVITY_MILESTONE_REWARD_RECEIVED] = '_OnMilestoneRewardReceived',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
}

ActivityWulingParkourCtrl.m_activityId = HL.Field(HL.String) << ''

ActivityWulingParkourCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self:_InitData(args)
    self:_InitUI()
    self:_RefreshAllUIs()
end

ActivityWulingParkourCtrl._InitData = HL.Method(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    
    args.skipReceive = true
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
end

ActivityWulingParkourCtrl._InitUI = HL.Method() << function(self)
    
    local _, achievementData = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    if achievementData then
        self.view.activityCommonInfo.view.gotoNode.dungeonMedalCell:InitCommonMedalNode(achievementData.achievementId)
    end
    
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot("ActivityParkourDetail", self.m_activityId)
end

ActivityWulingParkourCtrl._RefreshAllUIs = HL.Method() << function(self)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activityData then
        return
    end
    if activityData.status == GEnums.ActivityStatus.Locked then
        self.view.activityCommonInfo.view.gotoNode.medalNode.gameObject:SetActive(false)
        self.view.activityCommonInfo.view.gotoNode.nextTipStateController:SetState("Hide")
    else
        self.view.activityCommonInfo.view.gotoNode.medalNode.gameObject:SetActive(true)
        self:_RefreshStageTip()
    end
    self:_RefreshActivityCommonInfoRewardState()
end



ActivityWulingParkourCtrl._RefreshActivityCommonInfoRewardState = HL.Method() << function(self)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local receiveAll = false
    if activity then
        receiveAll = activity.receiveAllReward and self:_HasReceivedAllMilestoneRewards()
                and self:_HasClearedAllDungeonsWithThreeStars()
    end

    receiveAll = receiveAll and not self.view.activityCommonInfo.view.config.HIDE_RECEIVE_ALL
    local gotoNode = self.view.activityCommonInfo.view.gotoNode
    gotoNode.receiveAllNode.gameObject:SetActive(receiveAll)
    gotoNode.notReceiveAllNode.gameObject:SetActive(not receiveAll)
end

ActivityWulingParkourCtrl._HasReceivedAllMilestoneRewards = HL.Method().Return(HL.Boolean) << function(self)
    local haveCfg, milestoneCfg = Tables.activityConditionalMultiStageMilestoneTable:TryGetValue(self.m_activityId)
    if not haveCfg then
        return false
    end

    local hasMilestoneReward = false
    for milestoneId, _ in pairs(milestoneCfg.mileStones) do
        if not GameInstance.player.activitySystem:IsActivityMilestoneReceived(self.m_activityId, milestoneId) then
            return false
        end
        hasMilestoneReward = true
    end
    return hasMilestoneReward
end


ActivityWulingParkourCtrl._HasClearedAllDungeonsWithThreeStars = HL.Method().Return(HL.Boolean) << function(self)
    local _, activityDungeonData = Tables.ActivityDungeonTable:TryGetValue(self.m_activityId)
    if not activityDungeonData then
        return false
    end

    local hasDungeon = false
    local parkourSystem = GameInstance.player.parkourSystem
    for _, gameData in pairs(activityDungeonData.gameMap) do
        if gameData and not string.isEmpty(gameData.gameId) then
            hasDungeon = true
            local gameId = gameData.gameId
            if not parkourSystem:CheckMainGoalIsCompleted(gameId) then
                return false
            end

            local extraTaskCount = 3
            local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(gameId)
            if success and subGameData.extraTasks and subGameData.extraTasks.Count > 0 then
                extraTaskCount = subGameData.extraTasks.Count
            end
            if parkourSystem:GetCompletedExtraTaskCountBySubGameId(gameId) < extraTaskCount then
                return false
            end
        end
    end
    return hasDungeon
end

ActivityWulingParkourCtrl._RefreshStageTip = HL.Method() << function(self)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    
    local hasUnreadDungeon = false
    local _, activityDungeonData = Tables.ActivityDungeonTable:TryGetValue(self.m_activityId)
    local done = GameInstance.player.mission:IsQuestCompleted("a1m15_q#3")  
    if activityDungeonData then
        for _, gameData in pairs(activityDungeonData.gameMap) do
            if gameData and gameData.lv ~= 1 then
                local id = gameData.gameId
                local stageData = activityData:GetStageData(gameData.gameUnlockStage)
                if stageData ~= nil then
                    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
                    local isUnlocked = stageData.OpenTimeTs - currentTime <= 0
                    if done and isUnlocked and not GameInstance.player.subGameSys:IsGameRead(id) then
                        hasUnreadDungeon = true
                        break
                    end
                end
            end
        end
    end
    if hasUnreadDungeon then
        self.view.activityCommonInfo.view.gotoNode.nextTipStateController:SetState("New")
    else
        
        local hasNextStage = false
        local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(self.m_activityId)
        if haveCfg then
            local stages = {}
            for stageId, stageCfg in pairs(multiStageCfg.stageList) do
                table.insert(stages, { stageId = stageId, cfg = stageCfg })
            end
            table.sort(stages, function(a, b) return a.cfg.sortId < b.cfg.sortId end)

            local lockedStage = nil
            for _, stage in ipairs(stages) do
                local _, stageData = activityData.stageDataDict:TryGetValue(stage.stageId)
                local status = stageData and GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
                if status == GEnums.ActivityConditionalStageState.Locked then
                    lockedStage = stageData
                    break
                end
            end

            if lockedStage then
                local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
                local isTimeArrived = lockedStage.OpenTimeTs - currentTime <= 0
                if not isTimeArrived then
                    hasNextStage = true
                    self.view.activityCommonInfo.view.gotoNode.countDownText:InitCountDownText(lockedStage.OpenTimeTs,
                        function()
                            RedDotManager:TriggerUpdate("ActivityParkourDetail")
                            self:_RefreshAllUIs()
                        end, function(leftSec)
                        local leftTime = UIUtils.getLeftTime(leftSec)
                        return string.format(Language.LUA_ACTIVITY_PARKOUR_NEXT_STAGE_TIME_TEXT, leftTime)
                    end)
                end
            end
        end
        self.view.activityCommonInfo.view.gotoNode.nextTipStateController:SetState(hasNextStage and "WaitUpdate" or "Hide")
    end
end

ActivityWulingParkourCtrl._OnStageUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    self:_RefreshAllUIs()
end

ActivityWulingParkourCtrl._OnDungeonRead = HL.Method() << function(self)
    self:_RefreshAllUIs()
end

ActivityWulingParkourCtrl._OnMilestoneRewardReceived = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    self:_RefreshActivityCommonInfoRewardState()
end

ActivityWulingParkourCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    if not GameInstance.player.activitySystem:GetActivity(self.m_activityId) then
        return
    end
    self:_RefreshAllUIs()
end


HL.Commit(ActivityWulingParkourCtrl)
