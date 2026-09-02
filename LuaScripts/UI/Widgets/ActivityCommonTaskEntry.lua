local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ActivityTaskConfigFile = require_ex("UI/Widgets/ActivityTaskConfig")

ActivityCommonTaskEntry = HL.Class('ActivityTask', UIWidgetBase)

ActivityCommonTaskEntry.m_activityId = HL.Field(HL.String) << ""
ActivityCommonTaskEntry.m_showTaskCompletedCount = HL.Field(HL.Boolean) << false


ActivityCommonTaskEntry._OnFirstTimeInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE, function(arg)
        local id = unpack(arg)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_RefreshUI()
        end
    end)
    
    self:RegisterMessage(MessageConst.ON_ACTIVITY_UPDATED, function(updateArgs)
        local id = unpack(updateArgs)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_RefreshUI()
        end
    end)
    
    self:RegisterMessage(MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE, function(updateArgs)
        local id = unpack(updateArgs)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_RefreshUI()
        end
    end)
end




ActivityCommonTaskEntry.InitActivityTaskEntry = HL.Method(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId
    self:_FirstTimeInit()
    self:_InitUI()
    self:_RefreshUI()
end

ActivityCommonTaskEntry._InitUI = HL.Method() << function(self)
    
    self.view.redDot:InitRedDot("ActivityCommonTaskEntry", self.m_activityId)
    
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    self.view.button.onClick:AddListener(function()
        Utils.jumpToSystem(activityJumpCfg.taskJumpId)
    end)
    
    if self.view.countDownText then
        local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
        if activityData then
            self.view.countDownText:InitCountDownText(activityData.endTime)
        end
    end
end

ActivityCommonTaskEntry._RefreshUI = HL.Method() << function(self)
    
    local state = ActivityUtils.getActivityTaskLifecycleState(self.m_activityId)
    if state == "Hide" then
        self.view.gameObject:SetActive(false)
        return
    end
    self.view.gameObject:SetActive(true)

    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    
    if self.view.stateController then
        self.view.stateController:SetState(state)
        if state == "Disabled" then
            self.view.button.interactable = false
        end
        if state == "Normal" then
            self.view.button.interactable = true
            local allReceived = true
            for _,taskData in pairs(activity.taskDataDict) do
                local taskStatus = GEnums.ActivityConditionalTaskState.__CastFrom(taskData.Status)
                if taskStatus ~= GEnums.ActivityConditionalTaskState.Rewarded then
                    allReceived = false
                    break
                end
            end
            if allReceived then
                self.view.stateController:SetState("AllReceived")
            end
        end
    end

    
    if self.view.taskNumText then
        local completedTaskCount = 0
        local totalTaskCount = 0
        for _, taskData in cs_pairs(activity.taskDataDict) do
            local status = GEnums.ActivityConditionalTaskState.__CastFrom(taskData.Status)
            if status ~= GEnums.ActivityConditionalTaskState.Locked then
                totalTaskCount = totalTaskCount + 1
            end
            if status == GEnums.ActivityConditionalTaskState.Completed or
                status == GEnums.ActivityConditionalTaskState.Rewarded then
                completedTaskCount = completedTaskCount + 1
            end
        end
        self.view.taskNumText.text = string.format("%d/%d", completedTaskCount, totalTaskCount)
    end
end

HL.Commit(ActivityCommonTaskEntry)
return ActivityCommonTaskEntry

