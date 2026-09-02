local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityTaskCell = HL.Class('ActivityTaskCell', UIWidgetBase)

ActivityTaskCell.m_activityId = HL.Field(HL.String) << ""
ActivityTaskCell.m_taskId = HL.Field(HL.String) << ""
ActivityTaskCell.m_forcedRewardCellCount = HL.Field(HL.Number) << -1
ActivityTaskCell.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))


ActivityTaskCell._OnFirstTimeInit = HL.Override() << function(self)

end







ActivityTaskCell.InitActivityTaskCell = HL.Method(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId
    self.m_taskId = arg.taskId
    self.m_forcedRewardCellCount = arg.forcedRewardCellCount
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local taskStatusData = activityData:GetTaskData(self.m_taskId)
    local _, taskConfig = Tables.activityConditionalMultiStageTaskConfigTable:TryGetValue(self.m_activityId)
    local _, taskConfigInfo = taskConfig.TaskConfigMap:TryGetValue(self.m_taskId)

    
    self.view.taskNameTxt.text = taskConfigInfo.desc
    self.view.gameObject.name = "TaskCell_" .. self.m_taskId

    
    local state = "Underway"
    local status
    if activityData.status == GEnums.ActivityStatus.Locked and #taskConfigInfo.unlockConditionId == 0 then
        status = GEnums.ActivityConditionalTaskState.Unlocked
    else
        status = GEnums.ActivityConditionalTaskState.__CastFrom(taskStatusData.Status)
    end
    
    if status == GEnums.ActivityConditionalTaskState.Locked then
        state = "Lock"
        
        if #taskConfigInfo.unlockConditionId > 0 then
            local unlockConditionId = taskConfigInfo.unlockConditionId[CSIndex(1)]
            local _, unlockCondition = Tables.activityConditionalMultiStageTaskCompleteConditionTable:TryGetValue(unlockConditionId)
            self.view.lockTxt.text = unlockCondition.desc
        end
    elseif status == GEnums.ActivityConditionalTaskState.Unlocked then
        local jumpId = taskConfigInfo.jumpId
        if not string.isEmpty(jumpId) then
            state = "Normal"
            self.view.LeaveForBtn.onClick:RemoveAllListeners()
            self.view.LeaveForBtn.onClick:AddListener(function()
                
                ActivityUtils.setTaskRead(self.m_activityId, self.m_taskId)
                Utils.jumpToSystem(jumpId)
            end)
        end
     
    elseif status == GEnums.ActivityConditionalTaskState.Completed then
        state = "Receive"
        self.view.completeBtn.onClick:RemoveAllListeners()
        self.view.completeBtn.onClick:AddListener(function()
            GameInstance.player.activitySystem:SendReceiveTaskRewardConditionMultiStage(self.m_activityId, { self.m_taskId })
        end)
    
    elseif status == GEnums.ActivityConditionalTaskState.Rewarded then
        state = "Finish"
    end
    self.view.stateController:SetState(state)

    
    local rewardId = taskConfigInfo.rewardId
    local rewardCellCache = self.m_rewardCellCache or UIUtils.genCellCache(self.view.rewardItem)
    self.m_rewardCellCache = rewardCellCache
    local rewardBundles = UIUtils.getRewardItems(rewardId)
    
    local rewardCellCount = self.m_forcedRewardCellCount > 0 and self.m_forcedRewardCellCount or #rewardBundles
    rewardCellCache:Refresh(rewardCellCount, function(innerCell, innerIndex)
        
        if innerIndex > #rewardBundles then
            innerCell.stateController:SetState("Null")
            innerCell.stateController:SetState(status == GEnums.ActivityConditionalTaskState.Rewarded and "Finished" or "UnFinished")
            return
        end
        
        innerCell.stateController:SetState("Normal")
        local itemCell = innerCell.itemCell
        itemCell.view.simpleStateController:SetState("Normal")
        itemCell.view.rewardedCover.gameObject:SetActive(status == GEnums.ActivityConditionalTaskState.Rewarded)
        local reward = {
            id = rewardBundles[innerIndex].id,
            count = rewardBundles[innerIndex].count,
            forceHidePotentialStar = true,
        }
        itemCell:InitItem(reward, function()
            itemCell:ShowTips()
        end)
        itemCell:SetExtraInfo({
            tipsPosTransform = itemCell.view.content,
            isSideTips = true,
        })
    end)

    
    local conditionIdList = taskConfigInfo.completeConditionId
    local isInProgress = status == GEnums.ActivityConditionalTaskState.Unlocked
    local isLocked = status == GEnums.ActivityConditionalTaskState.Locked
    local progress = 0
    local target = 0
    
    if taskConfigInfo.isToggle then
        target = 1
    else
        for i = 1, conditionIdList.Count do
            local conditionId = conditionIdList[CSIndex(i)]
            if isInProgress and taskStatusData.Conditions then
                local _, val = taskStatusData.Conditions.Values:TryGetValue(conditionId)
                progress = progress + val
            end
            target = target + Tables.activityConditionalMultiStageTaskCompleteConditionTable[conditionId].progressToCompare
        end
    end
    if not isLocked and not isInProgress then
        progress = target 
    end
    self.view.taskBarPercentTxt.text = string.format("%d/%d", progress, target)
    self.view.taskBar.fillAmount = target ~= 0 and progress / target or 1

    
    local redDotArgs = {
        activityId = self.m_activityId,
        taskId = self.m_taskId,
    }
    self.view.redDot:InitRedDot("ActivitySingleTask", redDotArgs, nil, arg.redDotScrollRect)

    
    if DeviceInfo.usingController then
        
        self.view.rewardsKeyHint.gameObject:SetActive(false)
        self.view.naviDecorator.onIsNaviTargetChanged = function(isTarget)
            
            ActivityUtils.setTaskRead(self.m_activityId, self.m_taskId)
            self.view.rewardsKeyHint.gameObject:SetActive(isTarget)
        end
    end
end

HL.Commit(ActivityTaskCell)
return ActivityTaskCell

