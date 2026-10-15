local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ActivityTaskConfigFile = require_ex("UI/Widgets/ActivityTaskConfig")

ActivityCommonTaskEntry = HL.Class('ActivityTask', UIWidgetBase)

ActivityCommonTaskEntry.m_activityId = HL.Field(HL.String) << ""
ActivityCommonTaskEntry.m_showTaskCompletedCount = HL.Field(HL.Boolean) << false
ActivityCommonTaskEntry.m_redDotKey = HL.Field(HL.String) << "ActivityCommonTaskEntry"


ActivityCommonTaskEntry._OnFirstTimeInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE, function(arg)
        local id = unpack(arg)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_RefreshUI()
        end
    end)
    
    self:RegisterMessage(MessageConst.ON_ACTIVITY_UPDATED, function(updateArgs)
        local id = unpack(updateArgs)
        if id == self.m_activityId then
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
    self.m_redDotKey = arg.redDotKey or "ActivityCommonTaskEntry"
    self:_FirstTimeInit()
    self:_InitUI()
    self:_RefreshUI()
end

ActivityCommonTaskEntry._InitUI = HL.Method() << function(self)
    
    self.view.redDot:InitRedDot(self.m_redDotKey, self.m_activityId)
    
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

    
    self:_TryAutoCloseTaskPageWhenDisabled(state)

    
    if state == "Hide" then
        self.view.gameObject:SetActive(false)
        return
    end
    self.view.gameObject:SetActive(true)

    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    
    if self.view.stateController then
        self.view.stateController:SetState(state)
        if state == "Disabled" then
            if DeviceInfo.usingController then
                self.view.button.enabled = false
            else
                self.view.button.onClick:RemoveAllListeners()
                self.view.button.onClick:AddListener(function()
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_CONTINGENCY_CONTRACT_MECHANICS_END)
                end)
            end
        end
        if state == "Normal" then
            self.view.button.interactable = true
            if self.view.config and self.view.config:HasValue("CAN_SWITCH_FINISH_STATE") and self.view.config.CAN_SWITCH_FINISH_STATE then
                local allReceived = true
                for _, taskData in cs_pairs(activity.taskDataDict) do
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
    end

    
    if self.view.taskNumTxt then
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
        self.view.taskNumTxt.text = string.format("%d/%d", completedTaskCount, totalTaskCount)
    end
end

ActivityCommonTaskEntry._TryAutoCloseTaskPageWhenDisabled = HL.Method(HL.String) << function(self, state)
    if not (self.view.config and self.view.config:HasValue("AUTO_CLOSE_TASK_PAGE_WHEN_DISABLED") and self.view.config.AUTO_CLOSE_TASK_PAGE_WHEN_DISABLED) then
        return
    end
    if state ~= "Disabled" and state ~= "Hide" then
        return
    end
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    local _, jumpCfg = Tables.systemJumpTable:TryGetValue(activityJumpCfg.taskJumpId)
    local taskPhaseId = PhaseId[jumpCfg.phaseId]
    if taskPhaseId and PhaseManager:IsOpen(taskPhaseId) then
        local ctrl = self:GetUICtrl()
        local currentPhaseId = ctrl and ctrl.m_phase and ctrl.m_phase.phaseId
        
        Notify(MessageConst.SHOW_ACTIVITY_POP_UP, {
            content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU, 
            hideCancel = true,
            onConfirm = function()
                if currentPhaseId then
                    PhaseManager:ExitPhaseFastTo(currentPhaseId)
                end
            end
        })
    end
end

HL.Commit(ActivityCommonTaskEntry)
return ActivityCommonTaskEntry

