
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityWonderBuild

ActivityWonderBuildCtrl = HL.Class('ActivityWonderBuildCtrl', uiCtrl.UICtrl)

ActivityWonderBuildCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_START] = '_RefreshBoostTip',
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_END] = '_RefreshBoostTip',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityRewardUpdated',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE] = '_OnActivityRewardUpdated',
    [MessageConst.ON_WONDER_BUILD_REWARD_CHANGE] = '_RefreshRewardState',
}


ActivityWonderBuildCtrl.m_activityId = HL.Field(HL.String) << ''

ActivityWonderBuildCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    local commonInfoArgs = {}
    for key, value in pairs(args) do
        commonInfoArgs[key] = value
    end
    
    commonInfoArgs.skipReceive = true
    self.view.activityCommonInfo:InitActivityCommonInfo(commonInfoArgs)
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot.gameObject:SetActive(false)
    
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    
    local hasTaskJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.taskJumpId)
    if self.view.activityTaskEntry then
        if hasTaskJump then
            self.view.activityTaskEntry:InitActivityTaskEntry({activityId = self.m_activityId})
        else
            self.view.activityTaskEntry.gameObject:SetActive(false)
        end
    end
    self:_RefreshBoostTip()
    self:_RefreshRewardState()
end

ActivityWonderBuildCtrl._RefreshBoostTip = HL.Method() << function(self)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    self.view.boostTip.gameObject:SetActive(activity and activity.isInAccelerateTime or false)
end

ActivityWonderBuildCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshRewardState()
end

ActivityWonderBuildCtrl._OnActivityRewardUpdated = HL.Method(HL.Any) << function(self, args)
    local activityId = unpack(args)
    if activityId == self.m_activityId then
        self:_RefreshRewardState()
    end
end

ActivityWonderBuildCtrl._RefreshRewardState = HL.Method() << function(self)
    local commonInfo = self.view.activityCommonInfo
    local receiveAll = not commonInfo.view.config.HIDE_RECEIVE_ALL and self:_HasReceivedAllRewards()
    local gotoNode = commonInfo.view.gotoNode
    gotoNode.receiveAllNode.gameObject:SetActive(receiveAll)
    gotoNode.notReceiveAllNode.gameObject:SetActive(not receiveAll)
end

ActivityWonderBuildCtrl._HasReceivedAllRewards = HL.Method().Return(HL.Boolean) << function(self)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activity then
        return false
    end

    
    local hasTaskConfig, taskConfig = Tables.activityConditionalMultiStageTaskConfigTable:TryGetValue(self.m_activityId)
    if hasTaskConfig then
        local rewardedStatus = GEnums.ActivityConditionalTaskState.Rewarded:GetHashCode()
        for taskId, taskInfo in pairs(taskConfig.TaskConfigMap) do
            if not string.isEmpty(taskInfo.rewardId) then
                local taskData = activity:GetTaskData(taskId)
                if not taskData or taskData.Status ~= rewardedStatus then
                    return false
                end
            end
        end
    end

    local factoryManager = GameInstance.remoteFactoryManager
    local factoryCore = factoryManager and factoryManager.system and factoryManager.system.core
    local wonderProgress = factoryCore and factoryCore.progressStatus and factoryCore.progressStatus.wonderProgress
    if not wonderProgress then
        return false
    end

    local hasStageReward = false
    for _, stageData in pairs(Tables.wonderStageTable) do
        for i = 0, stageData.wonderRewards.length - 1 do
            local reward = stageData.wonderRewards[i]
            
            if not reward.repeatedReward and not string.isEmpty(reward.rewardID) then
                hasStageReward = true
                if not wonderProgress:IsRewardClaimedByResIndex(reward.index) then
                    return false
                end
            end
        end
    end
    return hasStageReward
end

HL.Commit(ActivityWonderBuildCtrl)
