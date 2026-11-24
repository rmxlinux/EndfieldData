
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityHighDifficulty

ActivityHighDifficultyCtrl = HL.Class('ActivityHighDifficultyCtrl', uiCtrl.UICtrl)





ActivityHighDifficultyCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = 'OnStageChange',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_PROGRESS_CHANGE] = 'OnStageChange',
}

ActivityHighDifficultyCtrl.m_activityId = HL.Field(HL.String) << ''

ActivityHighDifficultyCtrl.m_activity = HL.Field(HL.Any)

ActivityHighDifficultyCtrl.m_tasks = HL.Field(HL.Table)

ActivityHighDifficultyCtrl.m_getTaskCell = HL.Field(HL.Function)

ActivityHighDifficultyCtrl.m_curShowingTasks = HL.Field(HL.Table)

ActivityHighDifficultyCtrl.m_BgNode = HL.Field(HL.Any)

ActivityHighDifficultyCtrl.m_shownNewTaskIds = HL.Field(HL.Table)

ActivityHighDifficultyCtrl.m_lockTaskCountdownCoroutine = HL.Field(HL.Thread)

local LOCK_TASK_COUNTDOWN_REFRESH_INTERVAL = 1 


ActivityHighDifficultyCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    
    self.m_activityId = args.activityId
    self.m_curShowingTasks = {}
    self.m_shownNewTaskIds = {}
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    self:_RefreshInfo()

    
    self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
        return self:GetRedDotStateAt(csIndex)
    end

    
    self.m_getTaskCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getTaskCell(obj), LuaIndex(csIndex))
    end)

    
    self.view.topNode.gameObject:SetActive(false)
    self:_RefreshTaskList(true)

    
    local viewBindingId = self:BindInputPlayerAction("common_view_item", function()
        self:_SetNaviTarget(1)
    end)
    
    self.view.rightNaviGroup.onIsTopLayerChanged:AddListener(function(active)
        InputManagerInst:ToggleBinding(viewBindingId, not active)
        InputManagerInst:ToggleGroup(self.view.enterNode.groupId, not active)
    end)

    
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot("ActivityHighDifficultyDetailBtn", self.m_activityId)

    
    local _, info = Tables.activityHighDifficultyTable:TryGetValue(self.m_activityId)
    if info and info.bgNode then
        local path = string.format(UIConst.UI_ACTIVITY_HIGH_DIFFICULTY_BG_PREFAB_PATH, info.bgNode)
        local prefab = self:LoadGameObject(path)
        if self.m_BgNode then
            CSUtils.ClearUIComponents(self.m_BgNode) 
            GameObject.DestroyImmediate(self.m_BgNode)
        end
        self.m_BgNode = CSUtils.CreateObject(prefab, self.view.bgNode)
    end
end

ActivityHighDifficultyCtrl._RefreshInfo = HL.Method() << function(self)
    self.m_activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    self.m_tasks = {}

    
    for stageId, stageInfo in pairs(Tables.activityConditionalMultiStageTable[self.m_activityId].stageList) do
        local total = Tables.activityConditionalMultiStageCompleteConditionTable[stageId].conditionList[0].progressToCompare
        local curProgress
        local isComplete
        local isReceived

        local _, stageData = self.m_activity.stageDataDict:TryGetValue(stageId)
        local openTime = stageData.OpenTimeTs
        
        local isServerLocked = stageData.Status == GEnums.ActivityConditionalStageState.Locked:GetHashCode()
        local isLocked = isServerLocked and openTime > DateTimeUtils.GetCurrentTimestampBySeconds()
        if not isServerLocked then
            if stageData.Conditions then
                
                for _, info in pairs(stageData.Conditions.Values) do
                    curProgress = info
                end
            else
                
                curProgress = total
            end
            isComplete = stageData.Status >= GEnums.ActivityConditionalStageState.Completed:GetHashCode()
            isReceived = stageData.Status >= GEnums.ActivityConditionalStageState.Rewarded:GetHashCode()
        else
            curProgress = 0
            isComplete = false
            isReceived = false
        end

        local task = {
            stageId = stageId,
            name = stageInfo.name,
            sortId = stageInfo.sortId,
            openTime = openTime,
            rewardId = stageInfo.rewardId,
            isLocked = isLocked,
            isComplete = isComplete,
            isReceived = isReceived,
            curProgress = curProgress,
            total = total,
        }
        task.statusSortId = task.isReceived and 3 or (task.isComplete and 1 or 2)
        table.insert(self.m_tasks, task)
    end
end

ActivityHighDifficultyCtrl._RefreshTaskList = HL.Method(HL.Opt(HL.Boolean)) << function(self, scrollToTop)
    table.sort(self.m_tasks, Utils.genSortFunction({"statusSortId", "sortId"}, true))
    self.m_curShowingTasks = self.m_tasks
    self.view.scrollList:UpdateCount(#self.m_curShowingTasks)
    if scrollToTop and #self.m_curShowingTasks > 0 then
        self.view.scrollList:ScrollToIndex(1, true)
    end
    self:_StartLockTaskCountdown()
end

ActivityHighDifficultyCtrl.GetAllCanReceiveStageIds = HL.Method().Return(HL.Table) << function(self)
    local stageIds = {}
    for _, task in ipairs(self.m_curShowingTasks) do
        if task.isComplete and not task.isReceived then
            table.insert(stageIds, task.stageId)
        end
    end
    return stageIds
end

ActivityHighDifficultyCtrl._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    
    local task = self.m_curShowingTasks[index]
    local isLocked = task.isLocked
    local isComplete = task.isComplete
    local isReceived = task.isReceived
    cell.descTxt.text = task.name
    cell.progressTxt.text = task.curProgress .. "/" .. task.total
    cell.fgSlider.fillAmount = task.curProgress / task.total
    cell.redDot:InitRedDot("ActivityHighDifficultyTask", {self.m_activityId, task.stageId}, nil, self.view.redDotScrollRect)
    if not isLocked and HighDifficultyUtils.isNewHighDifficultyTask(self.m_activityId, task.stageId) then
        self.m_shownNewTaskIds[task.stageId] = true
    end
    cell.gameObject.name = "Cell" .. index

    
    local rewardId = task.rewardId
    local rewardBundles = UIUtils.getRewardItems(rewardId)
    cell.rewardCellCache = cell.rewardCellCache or UIUtils.genCellCache(cell.itemSmallReward)
    cell.rewardCellCache:Refresh(#rewardBundles, function(item, innerIndex)
        local reward = {
            id = rewardBundles[innerIndex].id,
            count = rewardBundles[innerIndex].count,
        }
        item:InitItem(reward, true)
        item:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
            tipsPosTransform = self.view.scrollList.transform,
            isSideTips = true,
        })
        item.view.rewardedCover.gameObject:SetActive(isReceived)
    end)

    
    local state = isReceived and "Received" or (isComplete and "Completed" or "Normal")
    cell.nodeState:SetState(state)
    cell.nodeState:SetState( state .. "Topic")
    cell.nodeState:SetState(isLocked and "Lock" or "UnLock")
    if isLocked then
        self:_RefreshLockTaskCountdown(cell, task)
    else
        cell.unLockText.text = ""
    end
    local bgName = Tables.activityHighDifficultySpecialStageTable[task.stageId].bgName
    if not string.isEmpty(bgName) then
        cell.bgImage.gameObject:SetActive(true)
        cell.bgImage:LoadSprite(UIConst.UI_SPRITE_ACTIVITY_HIGH_DIFFICULTY, bgName)
    else
        cell.bgImage.gameObject:SetActive(false)
    end

    
    cell.clickNode.onClick:RemoveAllListeners()
    if isComplete and not isReceived then
        cell.clickNode.onClick:AddListener(function()
            GameInstance.player.activitySystem:SendReceiveRewardConditionMultiStage(self.m_activityId, self:GetAllCanReceiveStageIds())
        end)
    end
end

ActivityHighDifficultyCtrl._RefreshLockTaskCountdown = HL.Method(HL.Table, HL.Table) << function(self, cell, task)
    local leftTime = math.max(task.openTime - DateTimeUtils.GetCurrentTimestampBySeconds(), 0)
    cell.unLockText.text = string.format(Language.LUA_ACTIVITY_HIGHDIFFICULTY_BOSS_LOCK_TASK_TIME,
        UIUtils.getLeftTime(leftTime))
end

ActivityHighDifficultyCtrl._RefreshVisibleLockTaskCountdowns = HL.Method().Return(HL.Boolean) << function(self)
    local hasLockedTask = false
    for index, task in ipairs(self.m_curShowingTasks) do
        if task.isLocked then
            hasLockedTask = true
            local obj = self.view.scrollList:Get(CSIndex(index))
            if obj then
                local cell = self.m_getTaskCell(obj)
                self:_RefreshLockTaskCountdown(cell, task)
            end
        end
    end
    return hasLockedTask
end

ActivityHighDifficultyCtrl._StopLockTaskCountdown = HL.Method() << function(self)
    self.m_lockTaskCountdownCoroutine = self:_ClearCoroutine(self.m_lockTaskCountdownCoroutine)
end

ActivityHighDifficultyCtrl._StartLockTaskCountdown = HL.Method() << function(self)
    self:_StopLockTaskCountdown()
    if not self:_RefreshVisibleLockTaskCountdowns() then
        return
    end
    self.m_lockTaskCountdownCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(LOCK_TASK_COUNTDOWN_REFRESH_INTERVAL)
            if not self:_RefreshVisibleLockTaskCountdowns() then
                self.m_lockTaskCountdownCoroutine = nil
                return
            end
        end
    end)
end

ActivityHighDifficultyCtrl._SetNaviTarget = HL.Method(HL.Number) << function(self,index)
    if index == 0 or not DeviceInfo.usingController  then
        return
    end
    local oriCell = self.view.scrollList:Get(CSIndex(index))
    if not oriCell then
        self.view.scrollList:ScrollToIndex(index, true)
        oriCell = self.view.scrollList:Get(CSIndex(index))
    end
    local cell = oriCell and self.m_getTaskCell(oriCell)
    if cell then
        self:SetNaviTarget(cell.naviDecorator)
    end
end

ActivityHighDifficultyCtrl.OnStageChange = HL.Method(HL.Any) << function(self, args)
    local id = unpack(args)
    if id ~= self.m_activityId then
        return
    end
    self:_RefreshInfo()
    self:_RefreshTaskList(false)
end

ActivityHighDifficultyCtrl.GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, index)
    local luaIndex = LuaIndex(index)
    if luaIndex < 1 or luaIndex > #self.m_curShowingTasks then
        return 0
    end
    local task = self.m_curShowingTasks[luaIndex]
    local hasRedDot, redDotType = RedDotManager:GetRedDotState("ActivityHighDifficultyTask", {self.m_activityId, task.stageId})
    if hasRedDot then
        return redDotType or UIConst.RED_DOT_TYPE.Normal
    else
        return 0
    end
end


ActivityHighDifficultyCtrl.OnActivityCenterNaviFailed = HL.Method() << function(self)
    local firstCell = self.view.scrollList:GetRangeInView().x
    self:_SetNaviTarget(LuaIndex(firstCell))
end

ActivityHighDifficultyCtrl.OnClose = HL.Override() << function(self)
    self:_StopLockTaskCountdown()
    local taskIds = {}
    for taskId,_ in pairs(self.m_shownNewTaskIds) do
        table.insert(taskIds, taskId)
    end
    HighDifficultyUtils.setFalseNewHighDifficultyTask(self.m_activityId, taskIds)
end

HL.Commit(ActivityHighDifficultyCtrl)
