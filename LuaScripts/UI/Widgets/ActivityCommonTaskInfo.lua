local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityCommonTaskInfo = HL.Class('ActivityCommonTaskInfo', UIWidgetBase)
ActivityCommonTaskInfo.m_activityId = HL.Field(HL.String) << ""
ActivityCommonTaskInfo.m_taskStatusInfo = HL.Field(HL.Table)
ActivityCommonTaskInfo.m_waitToReceiveTasks = HL.Field(HL.Table)
ActivityCommonTaskInfo.m_readTasks = HL.Field(HL.Table)
ActivityCommonTaskInfo.m_getListCell = HL.Field(HL.Function)
ActivityCommonTaskInfo.m_forcedRewardCellCount = HL.Field(HL.Number) << -1
ActivityCommonTaskInfo.m_latestUnlockTime = HL.Field(HL.Number) << -1
ActivityCommonTaskInfo.m_naviIndex = HL.Field(HL.Number) << -1


ActivityCommonTaskInfo._OnFirstTimeInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE, function(arg)
        local id = unpack(arg)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_UpdateData()
            self:_RefreshAllUIs(false)
        end
    end)

    
    self:RegisterMessage(MessageConst.ON_UI_CANVAS_SIZE_CHANGED, function()
        self:_OnCanvasSizeChanged()
    end)
end




ActivityCommonTaskInfo.InitActivityCommonTaskInfo = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()
    self.m_activityId = arg.activityId
    self.m_forcedRewardCellCount = arg.forcedRewardCellCount
    self.m_readTasks = {}

    self:_InitUI()
    self:_UpdateData()
    self:_RefreshAllUIs(true)
end

ActivityCommonTaskInfo._InitUI = HL.Method() << function(self)
    
    self.m_getListCell = UIUtils.genCachedCellFunction(self.view.taskScrollList)
    self.view.taskScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getListCell(obj)
        
        if csIndex == #self.m_taskStatusInfo then
            cell.view.stateController:SetState("Lock")
            cell.view.redDot.gameObject:SetActive(false)
            cell.view.rewardItemListNode.gameObject:SetActive(false)
            cell.view.countDownText:InitCountDownText(self.m_latestUnlockTime, nil, function(leftSec)
                local leftTime = UIUtils.getLeftTime(leftSec)
                return string.format(Language.LUA_COMMON_TASK_PREVIEW, leftTime)
            end)
            return
        end

        local taskId = self.m_taskStatusInfo[LuaIndex(csIndex)].id
        cell:InitActivityTaskCell({
            activityId = self.m_activityId,
            taskId = taskId,
            forcedRewardCellCount = self.m_forcedRewardCellCount,
            redDotScrollRect = self.view.redDotScrollRect,
        })
         
        cell:UpdateAllReceiveTaskIds(self.m_waitToReceiveTasks)
        if ActivityUtils.isNewTask(self.m_activityId, taskId) then
            self.m_readTasks[taskId] = true
        end
    end)
    
    if self.view.redDotScrollRect then
        self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
            return self:_GetRedDotStateAt(csIndex)
        end
    end

    
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if activityData then
        self.view.countDownText:InitCountDownText(activityData.endTime, nil, function(leftSec)
            local leftTime = UIUtils.getLeftTime(leftSec)
            return I18nUtils.CombineStringWithLanguageSpilt("", leftTime)
        end)
    end

    
    if self.view.walletBarPlaceholder then
        local _, shopGroupId = Tables.activityId2ShopGroupId:TryGetValue(self.m_activityId)
        if shopGroupId ~= nil then
            local _, shopCfg = Tables.activityShopAdditionalTable:TryGetValue(shopGroupId)
            if shopCfg and not string.isEmpty(shopCfg.activityMoneyId) then
                local moneyId = shopCfg.activityMoneyId
                LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.topRightNode)
                self.view.walletBarPlaceholder:InitWalletBarPlaceholder({moneyId})
            end
        end
    end
end

ActivityCommonTaskInfo._UpdateData = HL.Method() << function(self)
    
    self.m_taskStatusInfo = {}
    self.m_waitToReceiveTasks = {}
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if activityData == nil then
        return
    end

    local hideTimeLockedTask = self.view.config and self.view.config:HasValue("HIDE_TIME_LOCKED_TASKS") and self.view.config.HIDE_TIME_LOCKED_TASKS
    local _, taskConfig = Tables.activityConditionalMultiStageTaskConfigTable:TryGetValue(self.m_activityId)
    for id, singleTaskConfig in pairs(taskConfig.TaskConfigMap) do
        local taskStatusData = activityData:GetTaskData(id)
        local status
        if taskStatusData ~= nil then
            
            local unlockTimeArrived = string.isEmpty(singleTaskConfig.unlockTimeId) or Utils.isCurTimeInTimeIdRange(singleTaskConfig.unlockTimeId)
            local noUnlockCondition = #singleTaskConfig.unlockConditionId == 0
            if activityData.status == GEnums.ActivityStatus.Locked and unlockTimeArrived and noUnlockCondition then
                status = GEnums.ActivityConditionalTaskState.Unlocked
            else
                status = GEnums.ActivityConditionalTaskState.__CastFrom(taskStatusData.Status)
            end
            
            if not unlockTimeArrived then
                local unlockTime = Utils.getTimeIdOpenTimeStamp(singleTaskConfig.unlockTimeId)
                self.m_latestUnlockTime = self.m_latestUnlockTime >= 0 and (self.m_latestUnlockTime <= unlockTime and self.m_latestUnlockTime or unlockTime) or unlockTime
            end
            if hideTimeLockedTask and not unlockTimeArrived then
                goto continue
            end
            
            if status == GEnums.ActivityConditionalTaskState.Completed then
                table.insert(self.m_waitToReceiveTasks, id)
            end
            table.insert(self.m_taskStatusInfo, {
                id = id,
                toReceive = status == GEnums.ActivityConditionalTaskState.Completed and 0 or 1, 
                inProgress = status == GEnums.ActivityConditionalTaskState.Unlocked and 0 or 1, 
                rewarded = status == GEnums.ActivityConditionalTaskState.Rewarded and 0 or 1, 
                sortId = singleTaskConfig.sortId
            })
        end
        ::continue::
    end
    
    table.sort(self.m_taskStatusInfo, Utils.genSortFunction({ "toReceive", "inProgress", "rewarded", "sortId"}, true))
end

ActivityCommonTaskInfo._RefreshAllUIs = HL.Method(HL.Boolean) << function(self, isInit)
   
   local preview = self.view.config and self.view.config:HasValue("SHOW_TASK_PREVIEW_NODE") and self.view.config.SHOW_TASK_PREVIEW_NODE
   local count = #self.m_taskStatusInfo + (preview and self.m_latestUnlockTime >= 0 and 1 or 0) or 0
   if isInit then
       self.view.taskScrollList:UpdateCount(count)
   else
       self.view.taskScrollList:UpdateCount(count, false, false, false, true)
       self.m_naviIndex = self:_GetCurrentNaviIndex()
   end

   
   local hasWaitToReceiveTasks = #self.m_waitToReceiveTasks > 0
   self.view.receiveAllNode.stateController:SetState(hasWaitToReceiveTasks and "NormalState" or "DisableState")
   self.view.receiveAllNode.button.interactable = hasWaitToReceiveTasks
   if hasWaitToReceiveTasks then
       self.view.receiveAllNode.button.onClick:RemoveAllListeners()
       self.view.receiveAllNode.button.onClick:AddListener(function()
           GameInstance.player.activitySystem:SendReceiveTaskRewardConditionMultiStage(self.m_activityId, self.m_waitToReceiveTasks)
       end)
   end

   
   if self.view.updateNode and self.view.updateCountDownText then
       local countdownState = self.m_latestUnlockTime >= 0 and "Countdown" or "Updated"
       if self.m_latestUnlockTime >= 0 then
           self.view.updateCountDownText:InitCountDownText(self.m_latestUnlockTime)
       end
       self.view.updateNode:SetState(countdownState)
   end

   
   if DeviceInfo.usingController then
       if isInit then
           self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
           self:_SetNaviToIndex(0, true)
       elseif self.m_naviIndex >= 0 and self:_GetCurrentNaviIndex() ~= self.m_naviIndex then
           self:_SetNaviToIndex(self.m_naviIndex, false)
       end
       
       self.view.receiveAllNode.inputGroup.internalEnabled = hasWaitToReceiveTasks
   end
end

ActivityCommonTaskInfo._GetCurrentNaviIndex = HL.Method().Return(HL.Number) << function(self)
    if not DeviceInfo.usingController then
        return -1
    end
    return self.view.taskScrollList:GetNaviManagerTargetIndex()
end

ActivityCommonTaskInfo._SetNaviToIndex = HL.Method(HL.Number, HL.Boolean) << function(self, csIndex, scrollToTop)
    self.m_naviIndex = csIndex
    if scrollToTop then
        self.view.taskScrollList:ScrollToIndex(csIndex, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
    end
    local cell = self.m_getListCell(LuaIndex(csIndex))
    if cell and cell.view.naviDecorator then
        self:SetNaviTarget(cell.view.naviDecorator)
    end
end

ActivityCommonTaskInfo._OnCanvasSizeChanged = HL.Method() << function(self)
    if string.isEmpty(self.m_activityId) or not self.m_taskStatusInfo then
        return
    end
    
    self.view.taskScrollList:UpdateCount(#self.m_taskStatusInfo, false, true, false, false)
end


ActivityCommonTaskInfo._GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, csIndex)
    local info = self.m_taskStatusInfo[LuaIndex(csIndex)]
    if not info then
        return 0
    end
    local hasRedDot, redDotType = RedDotManager:GetRedDotState("ActivitySingleTask", {
        activityId = self.m_activityId,
        taskId = info.id,
    })
    if not hasRedDot then
        return 0
    end
    return redDotType or UIConst.RED_DOT_TYPE.Normal
end

ActivityCommonTaskInfo._OnDestroy = HL.Override() << function(self)
    
    for id, _ in pairs(self.m_readTasks) do
        ActivityUtils.setTaskRead(self.m_activityId, id)
    end
end

HL.Commit(ActivityCommonTaskInfo)
return ActivityCommonTaskInfo

