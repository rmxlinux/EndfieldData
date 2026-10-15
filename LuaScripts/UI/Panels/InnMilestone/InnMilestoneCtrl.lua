local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnMilestone
local PHASE_ID = PhaseId.InnMilestone

local TaskStatus = CS.Proto.INN_MANAGEMENT_MILESTONE_TASK_STATUS

InnMilestoneCtrl = HL.Class('InnMilestoneCtrl', uiCtrl.UICtrl)

InnMilestoneCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_GET_MILESTONE_REWARD] = '_OnMilestoneLevelChanged',
    [MessageConst.SHOW_INN_MILESTONE_REWARD] = '_OnShowMilestoneReward',
    [MessageConst.ON_INN_GET_MILESTONE_TASK_REWARD] = '_OnMilestoneTaskRewardChanged',
}

InnMilestoneCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnMilestoneCtrl.m_milestoneList = HL.Field(HL.Table)
InnMilestoneCtrl.m_getCellFunc = HL.Field(HL.Function)
InnMilestoneCtrl.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))
InnMilestoneCtrl.m_prevLevel = HL.Field(HL.Number) << 0
InnMilestoneCtrl.m_prevExp = HL.Field(HL.Number) << 0
InnMilestoneCtrl.m_expTween = HL.Field(HL.Any)
InnMilestoneCtrl.m_milestoneRewardArgs = HL.Field(HL.Table)
InnMilestoneCtrl.m_upgradeAnimationFinished = HL.Field(HL.Boolean) << false

InnMilestoneCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_milestoneRewardArgs = nil
    self.m_upgradeAnimationFinished = false
    self:_BindUI()
    self:_BuildMilestoneList()
    self:_RefreshUI()
    self.m_prevLevel = self.m_innSystem.milestoneLv
    self.m_prevExp = tonumber(self.m_innSystem.milestoneExp) or 0
    self.view.redDot:InitRedDot("InnMilestoneLevel")
    if DeviceInfo.usingController then
        self:SetNaviTarget(self.m_getCellFunc(1).naviTarget)
    end
end

InnMilestoneCtrl._BindUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.m_rewardCellCache = UIUtils.genCellCache(self.view.rewardCell)

    self.view.receiveBtn.onClick:AddListener(function()
        self.m_upgradeAnimationFinished = false
        self.m_innSystem:SendGetMilestoneReward(self.m_innSystem.milestoneLv)
    end)

    self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
        local item = self.m_milestoneList and self.m_milestoneList[LuaIndex(csIndex)]
        if not item then
            return 0
        end
        local hasRedDot, redDotType = RedDotManager:GetRedDotState("InnMilestoneTask", item.id)
        return hasRedDot and redDotType or 0
    end

    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.taskScrollList)
    self.view.taskScrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateCell(object, LuaIndex(csIndex))
    end)
end

InnMilestoneCtrl._BuildMilestoneList = HL.Method() << function(self)
    local list = {}
    for id, data in pairs(Tables.innMilestoneTable) do
        local taskData = nil
        local hasTask, task = self.m_innSystem.milestoneTasks:TryGetValue(id)
        if hasTask then
            taskData = task
        end
        table.insert(list, {
            id = id,
            cfg = data,
            taskData = taskData,
        })
    end
    local statusOrder = {
        [TaskStatus.MilestoneTaskStatusCompleted] = 1,
        [TaskStatus.MilestoneTaskStatusProgress] = 2,
        [TaskStatus.MilestoneTaskStatusRewarded] = 3,
        [TaskStatus.MilestoneTaskStatusLocked] = 4,
    }
    table.sort(list, function(a, b)
        local sa = statusOrder[a.taskData and a.taskData.status or TaskStatus.MilestoneTaskStatusLocked] or 5
        local sb = statusOrder[b.taskData and b.taskData.status or TaskStatus.MilestoneTaskStatusLocked] or 5
        if sa ~= sb then
            return sa < sb
        end
        if a.cfg.level ~= b.cfg.level then
            return a.cfg.level < b.cfg.level
        end
        return a.id < b.id
    end)
    self.m_milestoneList = list
end

InnMilestoneCtrl._RefreshUI = HL.Method() << function(self)
    self:_RefreshLevelInfo()
    self.view.taskScrollList:UpdateCount(#self.m_milestoneList)
end

InnMilestoneCtrl._RefreshLevelInfo = HL.Method() << function(self)
    local currentLevel = self.m_innSystem.milestoneLv
    local totalExp = tonumber(self.m_innSystem.milestoneExp) or 0

    self.view.levelNumTxt.text = tostring(currentLevel)

    local hasCur, curData = Tables.innMilestoneLevelTable:TryGetValue(currentLevel)

    if not hasCur then
        self.view.expSlider.value = 1
        self.view.expNumTxt.text = "0/0"
        self.view.titleStateController:SetState("MaxState")
        self:_RefreshRewardList("")
        return
    end

    local prevLevel = currentLevel - 1
    local hasPrev, prevData = Tables.innMilestoneLevelTable:TryGetValue(prevLevel)
    local prevThreshold = hasPrev and prevData.progress or 0

    local curThreshold = curData.progress
    local range = curThreshold - prevThreshold
    local displayExp = totalExp - prevThreshold

    if range > 0 then
        self.view.expSlider.value = math.min(displayExp / range, 1)
        self.view.expNumTxt.text = string.format("%d/%d", math.min(displayExp, range), range)
    else
        self.view.expSlider.value = 1
        self.view.expNumTxt.text = "0/0"
    end

    if totalExp >= curThreshold then
        self.view.titleStateController:SetState("ReceiveState")
    else
        self.view.titleStateController:SetState("InProgressState")
    end

    self:_RefreshRewardList(curData.rewardId or "")
end

InnMilestoneCtrl._RefreshRewardList = HL.Method(HL.String) << function(self, rewardId)
    local rewardItems = {}
    if rewardId and rewardId ~= "" then
        rewardItems = UIUtils.getRewardItems(rewardId)
    end

    self.m_rewardCellCache:Refresh(#rewardItems, function(cell, index)
        cell.stateController:SetState("Normal")
        cell.itemReward:InitItem(rewardItems[index], true)
        cell.itemReward:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
    end)
end

InnMilestoneCtrl._OnUpdateCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, index)
    local cell = self.m_getCellFunc(object)
    local item = self.m_milestoneList[index]
    if not item then
        return
    end

    local cfg = item.cfg
    local taskData = item.taskData
    local status = taskData and taskData.status or TaskStatus.MilestoneTaskStatusLocked

    cell.redDot:InitRedDot("InnMilestoneTask", item.id, nil, self.view.redDotScrollRect)
    cell.completeBtn.onClick:RemoveAllListeners()
    cell.taskNameTxt.text = cfg.descText or item.id

    local progress = taskData and taskData.progress or 0
    local target = self:_GetTaskTarget(cfg)

    if status == TaskStatus.MilestoneTaskStatusLocked then
        cell.stateController:SetState("LockState")
        cell.lockText.text = string.format(Language.LUA_INN_MILESTONE_LOCK_LEVEL, cfg.level)
        cell.expNumTxt.text = tostring(cfg.progressReward)
    elseif status == TaskStatus.MilestoneTaskStatusProgress then
        cell.stateController:SetState("InProgressState")
        cell.expNumTxt.text = tostring(cfg.progressReward)
        if target > 0 then
            cell.progressSlider.value = math.min(progress / target, 1)
            cell.progressTxt.text = string.format("%d/%d", progress, target)
        else
            cell.progressSlider.value = 1
            cell.progressTxt.text = string.format("%d/%d", progress, progress)
        end
    elseif status == TaskStatus.MilestoneTaskStatusCompleted then
        cell.stateController:SetState("CompleteState")
        cell.expNumTxt.text = tostring(cfg.progressReward)
        cell.progressSlider.value = 1
        cell.progressTxt.text = string.format("%d/%d", target, target)
        cell.completeBtn.onClick:AddListener(function()
            local claimableIds = {}
            for _, task in ipairs(self.m_milestoneList) do
                local s = task.taskData and task.taskData.status or TaskStatus.MilestoneTaskStatusLocked
                if s == TaskStatus.MilestoneTaskStatusCompleted then
                    table.insert(claimableIds, task.id)
                end
            end
            if #claimableIds > 0 then
                self.m_innSystem:SendGetMilestoneTaskReward(claimableIds)
            end
        end)
    elseif status == TaskStatus.MilestoneTaskStatusRewarded then
        cell.stateController:SetState("Completed")
        cell.expNumTxt.text = tostring(cfg.progressReward)
        cell.progressSlider.value = 1
        cell.progressTxt.text = string.format("%d/%d", target, target)
    end
end

InnMilestoneCtrl._GetTaskTarget = HL.Method(HL.Userdata).Return(HL.Number) << function(self, cfg)
    local conditions = cfg.conditions
    if not conditions then
        return 1
    end
    for _, cond in pairs(conditions) do
        return cond.progressToCompare
    end
    return 1
end

InnMilestoneCtrl._OnMilestoneLevelChanged = HL.Method() << function(self)
    self.m_prevLevel = self.m_innSystem.milestoneLv
    self.m_prevExp = tonumber(self.m_innSystem.milestoneExp) or 0

    self:_BuildMilestoneList()
    self:_RefreshUI()

    self.m_upgradeAnimationFinished = false
    self.view.luaPanel:BlockAllInput()
    UIUtils.PlayAnimationAndToggleActive(self.view.upgradeAni, true, function()
        UIUtils.PlayAnimationAndToggleActive(self.view.upgradeAni, false)
        self.m_upgradeAnimationFinished = true
        self.view.luaPanel:RecoverAllInput()
        self:_TryShowMilestoneReward()
    end)
end

InnMilestoneCtrl._OnShowMilestoneReward = HL.Method(HL.Table) << function(self, args)
    self.m_milestoneRewardArgs = args
    self:_TryShowMilestoneReward()
end

InnMilestoneCtrl._TryShowMilestoneReward = HL.Method() << function(self)
    
    if not self.m_upgradeAnimationFinished or not self.m_milestoneRewardArgs then
        return
    end
    local args = self.m_milestoneRewardArgs
    self.m_milestoneRewardArgs = nil
    Notify(MessageConst.CS_SHOW_SYSTEM_REWARDS, args)
end

InnMilestoneCtrl._PlayExpAnimation = HL.Method(HL.Number, HL.Number, HL.Number, HL.Number) << function(self, oldLevel, oldExp, newLevel, newExp)
    if self.m_expTween then
        self.m_expTween:Kill()
        self.m_expTween = nil
    end

    self.view.levelNumTxt.text = tostring(newLevel)

    local hasCur, curData = Tables.innMilestoneLevelTable:TryGetValue(newLevel)
    if not hasCur then
        self.view.expSlider.value = 1
        self.view.expNumTxt.text = "0/0"
        self.view.titleStateController:SetState("MaxState")
        return
    end

    local prevLevelKey = newLevel - 1
    local hasPrev, prevData = Tables.innMilestoneLevelTable:TryGetValue(prevLevelKey)
    local prevThreshold = hasPrev and prevData.progress or 0

    local curThreshold = curData.progress
    local range = curThreshold - prevThreshold

    if range > 0 then
        local startDisplayExp = oldExp - prevThreshold
        local endDisplayExp = newExp - prevThreshold

        self.view.expSlider.value = math.min(startDisplayExp / range, 1)
        self.view.expNumTxt.text = string.format("%d/%d", math.min(startDisplayExp, range), range)

        local duration = 0.5
        self.m_expTween = DOTween.To(
            function() return startDisplayExp end,
            function(value)
                value = math.floor(value)
                if not self.view or IsNull(self.view.expSlider) then
                    return
                end
                self.view.expSlider.value = math.min(value / range, 1)
                self.view.expNumTxt.text = string.format("%d/%d", math.min(value, range), range)
            end,
            endDisplayExp,
            duration
        )
        AudioAdapter.PostEvent("Au_UI_Event_BPLevelUp")
        self.m_expTween:OnComplete(function()
            self.m_expTween = nil
            if newExp >= curThreshold then
                self.view.titleStateController:SetState("ReceiveState")
            else
                self.view.titleStateController:SetState("InProgressState")
            end
            self:_RefreshRewardList(curData.rewardId or "")
        end)
    else
        self.view.expSlider.value = 1
        self.view.expNumTxt.text = "0/0"
        self:_RefreshRewardList(curData.rewardId or "")
    end
end

InnMilestoneCtrl._OnMilestoneTaskRewardChanged = HL.Method() << function(self)
    local oldLevel = self.m_prevLevel
    local oldExp = self.m_prevExp

    local newLevel = self.m_innSystem.milestoneLv
    local newExp = tonumber(self.m_innSystem.milestoneExp) or 0

    self.m_prevLevel = newLevel
    self.m_prevExp = newExp

    self:_BuildMilestoneList()
    self.view.taskScrollList:UpdateCount(#self.m_milestoneList)

    self:_PlayExpAnimation(oldLevel, oldExp, newLevel, newExp)
end

HL.Commit(InnMilestoneCtrl)
