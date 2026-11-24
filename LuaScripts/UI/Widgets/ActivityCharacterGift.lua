local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget
local CHARACTER_GIFT_SHARE_TYPE = "CharacterGift"
local CHARACTER_GIFT_SHARE_STATE = "Share"
local CHARACTER_GIFT_NO_SHARE_STATE = "NoShare"
local CHARACTER_GIFT_SHARE_HIDE_KEY = "ActivityCharacterGiftShare"

ActivityCharacterGift = HL.Class('ActivityCharacterGift', UIWidgetBase)

ActivityCharacterGift.m_activityId = HL.Field(HL.String) << ''
ActivityCharacterGift.m_taskInfos = HL.Field(HL.Table)
ActivityCharacterGift.m_taskCellMap = HL.Field(HL.Table)
ActivityCharacterGift.m_mainTaskId = HL.Field(HL.String) << ''
ActivityCharacterGift.m_selectedTaskId = HL.Field(HL.String) << ''
ActivityCharacterGift.m_viewBindingId = HL.Field(HL.Number) << -1
ActivityCharacterGift.m_receiveAllBindingId = HL.Field(HL.Number) << -1
ActivityCharacterGift.m_taskListFocused = HL.Field(HL.Boolean) << false
ActivityCharacterGift.m_getCellFunc = HL.Field(HL.Function)
ActivityCharacterGift.m_shownNewTaskIds = HL.Field(HL.Table)
ActivityCharacterGift.m_shareRewardCells = HL.Field(HL.Forward("UIListCache"))
ActivityCharacterGift.m_onShareAction = HL.Field(HL.Function)



ActivityCharacterGift.Init = HL.Method(HL.Table) << function(self, arg)
    self.m_activityId = arg and arg.activityId or ''
    
    self.m_taskInfos = {}
    self.m_taskCellMap = {}
    self.m_mainTaskId = ''
    self.m_selectedTaskId = ''
    self.m_shownNewTaskIds = {}
    self.view.shareStateController:SetState(CHARACTER_GIFT_NO_SHARE_STATE)

    local hasConfig, configData = Tables.activityCharacterGiftConfigTable:TryGetValue(self.m_activityId)
    if not hasConfig then
        logger.error("ActivityCharacterGift: config not found", self.m_activityId)
        return
    end

    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.taskListNode)

    
    self.view.activityCommonInfo:InitActivityCommonInfo(arg)

    
    self.m_mainTaskId = configData.mainTaskId
    self:_InitShowCharBtn(configData.characterId)
    self:_InitShare(configData.enableShare)

    
    self.view.taskListNode.onUpdateCell:AddListener(function(object, csIndex)
        self:_UpdateTaskCell(object, LuaIndex(csIndex))
    end)
    self.view.taskListNodeScrollRect.onValueChanged:AddListener(function()
        self:_RefreshMainTaskSpecialDeconVisibility()
    end)

    self:_BindUI()
    self:_Refresh()
    if arg.openShare == true and configData.enableShare then
        self:_OpenShare()
    end
end

ActivityCharacterGift._OpenCharacterPreview = HL.Method(HL.String) << function(self, charId)
    CharInfoUtils.openCharInfoBestWay({
        initCharInfoCreator = function()
            local previewCharInfo = GameInstance.player.charBag:CreateClientInitialGachaPoolChar(charId)
            local perfectCharInfo = GameInstance.player.charBag:CreateClientPerfectGachaPoolCharInfo(charId)
            return {
                instId = previewCharInfo.instId,
                templateId = previewCharInfo.templateId,
                charInstIdList = { previewCharInfo.instId },
                maxCharInstIdList = { perfectCharInfo.instId },
                isShowPreview = true,
            }
        end,
        onClose = function()
            GameInstance.player.charBag:ClearAllClientCharAndItemData()
        end,
    })
end

ActivityCharacterGift._InitShareRewards = HL.Method() << function(self)
    local activityData = Tables.activityTable[self.m_activityId]
    local rewardId = activityData.rewardId
    local rewardTableData = Tables.rewardTable[rewardId]
    local rewardBundles = UIUtils.getRewardItems(rewardId)

    local sortedItems = {}
    for index, bundle in ipairs(rewardBundles) do
        local itemData = Tables.itemTable[bundle.id]
        table.insert(sortedItems, {
            bundle = bundle,
            originalIndex = index,
            rarity = itemData.rarity,
            sortId1 = itemData.sortId1,
            sortId2 = itemData.sortId2,
        })
    end
    table.sort(sortedItems, Utils.genSortFunction({ "rarity", "sortId1", "sortId2" }))

    self.m_shareRewardCells = UIUtils.genCellCache(self.view.shareNode.rewardItem)
    self.m_shareRewardCells:Refresh(#sortedItems, function(cell, index)
        local sortedItem = sortedItems[index]
        cell:InitItem(sortedItem.bundle, false)
        local showCount = rewardTableData.itemBundleVisibleList[CSIndex(sortedItem.originalIndex)] == 1
        cell.view.countNode.gameObject:SetActive(showCount)
    end)
end


ActivityCharacterGift._InitShare = HL.Virtual(HL.Boolean) << function(self, enableShare)
    local shareBtn = self.view.shareBtn
    shareBtn.onClick:RemoveAllListeners()
    shareBtn.gameObject:SetActiveIfNecessary(enableShare)

    if not enableShare then
        return
    end

    self:_InitShareRewards()

    local activityId = self.m_activityId
    local shareCountGameVarKey = Tables.activityCharacterGiftConfigTable:GetValue(activityId).shareCountGameVarKey
    local onShareAction
    if not string.isEmpty(shareCountGameVarKey) then
        local player = GameInstance.player
        onShareAction = function()
            if player ~= GameInstance.player then
                return
            end
            local _, gameVarConfig = Tables.globalVarTable:TryGetValue(shareCountGameVarKey)
            local success, value = player.globalVar:TryGetClientVar(shareCountGameVarKey)
            if not success then
                value = gameVarConfig.defaultValue
            end
            player.globalVar:SetClientVar(shareCountGameVarKey, value + 1)
        end
    end

    self.m_onShareAction = onShareAction
    self.view.shareBtn.onClick:AddListener(function()
        self:_OpenShare()
    end)
end

ActivityCharacterGift._OpenShare = HL.Method() << function(self)
    local shareBtn = self.view.shareBtn
    shareBtn.gameObject:SetActiveIfNecessary(false)
    self.view.shareStateController:SetState(CHARACTER_GIFT_SHARE_STATE)
    UIManager:HideWithKey(PanelId.ActivityCenter, CHARACTER_GIFT_SHARE_HIDE_KEY)
    Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
        type = CHARACTER_GIFT_SHARE_TYPE,
        timeStamp = Utils.appendUTC(Utils.timestampToDateYMDHM(DateTimeUtils.GetCurrentTimestampBySeconds())),
        onShareAction = self.m_onShareAction,
        onCaptureEnd = function()
            self.view.shareStateController:SetState(CHARACTER_GIFT_NO_SHARE_STATE)
            shareBtn.gameObject:SetActiveIfNecessary(true)
            UIManager:ShowWithKey(PanelId.ActivityCenter, CHARACTER_GIFT_SHARE_HIDE_KEY)
        end,
    })
end

ActivityCharacterGift._BindUI = HL.Method() << function(self)
    
    self.m_receiveAllBindingId = self:BindInputPlayerAction("activity_stamina_receive_all", function()
        self:_ReceiveAllTaskRewards()
    end)
    self:_ToggleBindingIfValid(self.m_receiveAllBindingId, false) 

    self.view.taskListNaviGroup.getDefaultSelectableFunc = function()
        local firstTaskInfo = self.m_taskInfos and self.m_taskInfos[1]
        local info = firstTaskInfo and self.m_taskCellMap[firstTaskInfo.taskId]
        return info and info.cell.button or nil
    end

    self.view.taskListNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.m_taskListFocused = isFocused
        if not isFocused then
            self:_SetSelectedTask(nil)
        end
        self:_ApplyControllerFocusState()
    end)

    if DeviceInfo.usingController then
        
        self.m_viewBindingId = self:BindInputPlayerAction("common_view_item", function()
            self:OnActivityCenterNaviFailed()
        end)

        
        self.view.taskListNaviGroup.onIsTopLayerChanged:AddListener(function(active)
            self.m_taskListFocused = active
            InputManagerInst:ToggleGroup(self.view.scrollInputGroup.groupId, not active)
            if not active then
                self:_SetSelectedTask(nil)
            end
            self:_ApplyControllerFocusState()
        end)
    end
end


ActivityCharacterGift._Refresh = HL.Method() << function(self)
    
    self:_RefreshTaskData()
    
    self:_RefreshTaskList()
    self:_RefreshReceiveAllBtn()
end

ActivityCharacterGift.OnShow = HL.Method() << function(self)
    self:_ApplyControllerFocusState()
end

ActivityCharacterGift.OnClose = HL.Method() << function(self)
    self:_StopUnlockCountdown()
    for taskId, _ in pairs(self.m_shownNewTaskIds) do
        ActivityUtils.setTaskRead(self.m_activityId, taskId)
    end
end

ActivityCharacterGift._RefreshTaskData = HL.Method() << function(self)
    
    self.m_taskInfos = ActivityUtils.GetTaskInfos(self.m_activityId)

    for _, taskInfo in ipairs(self.m_taskInfos) do
        if taskInfo.status == GEnums.ActivityConditionalTaskState.Completed then
            taskInfo._statusSort = 0
        elseif taskInfo.status == GEnums.ActivityConditionalTaskState.Unlocked then
            taskInfo._statusSort = 1
        elseif taskInfo.status == GEnums.ActivityConditionalTaskState.Locked then
            taskInfo._statusSort = 2
        elseif taskInfo.status == GEnums.ActivityConditionalTaskState.Rewarded then
            taskInfo._statusSort = 3
        else
            taskInfo._statusSort = 4
        end
        taskInfo._rewardedMainTaskSort = taskInfo.status == GEnums.ActivityConditionalTaskState.Rewarded
                and taskInfo.taskId == self.m_mainTaskId and 1 or 0
    end
    
    
    
    table.sort(self.m_taskInfos, Utils.genSortFunction({ "_statusSort", "_rewardedMainTaskSort", "sortId" }, true))
end

ActivityCharacterGift._RefreshTaskList = HL.Method() << function(self)
    self:_StopUnlockCountdown()
    self.m_taskCellMap = {}
    self.view.taskListNode:UpdateCount(#self.m_taskInfos)
end

local TaskActionType = {
    ["None"] = "None", 
    ["Receive"] = "Receive", 
    ["Goto"] = "Goto", 
}

ActivityCharacterGift._RefreshMainTaskSpecialDeconVisibility = HL.Method() << function(self)
    local mainTaskInfo = self.m_taskCellMap[self.m_mainTaskId]
    if not mainTaskInfo or not mainTaskInfo.cell then
        return
    end

    local cell = mainTaskInfo.cell
    
    cell.transform:SetAsLastSibling()
    
    
    local shouldShow = cell.gameObject.activeInHierarchy and self.view.taskListNode.currentStep <= 0.01
    if mainTaskInfo.taskInfo.status == GEnums.ActivityConditionalTaskState.Rewarded then
        shouldShow = false
    end
    if cell.specialDeconNode.gameObject.activeSelf ~= shouldShow then
        cell.specialDeconNode.gameObject:SetActive(shouldShow)
    end
end

ActivityCharacterGift._UpdateTaskCell = HL.Method(HL.Any, HL.Any) << function(self, obj, csIndex)
    local taskInfo = self.m_taskInfos[csIndex]

    local cell = self.m_getCellFunc(obj)
    if cell.unLockTimeText then
        cell.unLockTimeText:StopCountDown()
    end
    cell.redDot:InitRedDot("ActivityCharacterGiftSingleTask", {
        activityId = self.m_activityId,
        taskId = taskInfo.taskId,
    })

    
    local shouldMoveSelection = false
    for oldTaskId, oldInfo in pairs(self.m_taskCellMap) do
        if oldInfo.cell == cell and oldTaskId ~= taskInfo.taskId then
            self.m_taskCellMap[oldTaskId] = nil
            if self.m_selectedTaskId == oldTaskId then
                shouldMoveSelection = true
            end
        end
    end
    if shouldMoveSelection then
        self.m_selectedTaskId = taskInfo.taskId
    end

    local actionType = self:_GetTaskActionType(taskInfo)
    self.m_taskCellMap[taskInfo.taskId] = { cell = cell, taskInfo = taskInfo, actionType = actionType }

    
    self:_RefreshTaskCellInput(cell, taskInfo.taskId)

    cell.gameObject.name = "CharacterGiftTask_" .. taskInfo.taskId
    cell.taskDescText.text = taskInfo.desc
    local isMainTask = taskInfo.taskId == self.m_mainTaskId
    cell.stateController:SetState(isMainTask and "MainStatus" or "CommonStatus")
    local status = taskInfo.status
    if status == GEnums.ActivityConditionalTaskState.Unlocked
        and ActivityUtils.isNewTask(self.m_activityId, taskInfo.taskId) then
        self.m_shownNewTaskIds[taskInfo.taskId] = true
    end
    if status == GEnums.ActivityConditionalTaskState.Completed then
        cell.stateController:SetState("Completed")
    elseif status == GEnums.ActivityConditionalTaskState.Rewarded then
        cell.stateController:SetState("Rewarded")
    elseif status == GEnums.ActivityConditionalTaskState.Locked then
        cell.stateController:SetState("Locked")
        self:_RefreshTaskUnlockTime(cell, taskInfo)
    else
        cell.stateController:SetState("GoingTo")
    end
    if isMainTask then
    	
        cell.transform:SetAsLastSibling()
        self:_RefreshMainTaskSpecialDeconVisibility()
    else
        cell.specialDeconNode.gameObject:SetActive(false)
    end

    local rewardItems = UIUtils.getRewardItems(taskInfo.rewardId)
    self:_InitRewardItem(cell.rewardItem1, rewardItems[1], taskInfo)
    self:_InitRewardItem(cell.rewardItem2, rewardItems[2], taskInfo)

    if DeviceInfo.usingController then
        self:_ApplyTaskCellFocusState(self.m_taskCellMap[taskInfo.taskId])
    end
end

ActivityCharacterGift._InitRewardItem = HL.Method(HL.Any, HL.Any, HL.Table) << function(self, itemCell, rewardBundle, taskInfo)
    itemCell.gameObject:SetActive(rewardBundle ~= nil)
    if not rewardBundle then
        return
    end

    local reward = {
        id = rewardBundle.id,
        count = rewardBundle.count,
        forceHidePotentialStar = true,
    }

    itemCell:InitItem(reward, function()
        itemCell:ShowTips()
    end)

    itemCell:SetExtraInfo({
        tipsPosTransform = itemCell.view.content,
        isSideTips = true,
    })
    itemCell.view.rewardedCover.gameObject:SetActive(taskInfo.status == GEnums.ActivityConditionalTaskState.Rewarded)
    itemCell.view.button:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.AutoTriggerOnClick)
end


ActivityCharacterGift._GetTaskUnlockTimestamp = HL.Method(HL.Table).Return(HL.Number) << function(self, taskInfo)
    if not taskInfo or taskInfo.status ~= GEnums.ActivityConditionalTaskState.Locked then
        return 0
    end

    local _, taskCfg = Tables.activityConditionalMultiStageTaskConfigTable:TryGetValue(self.m_activityId)
    local _, config = taskCfg.TaskConfigMap:TryGetValue(taskInfo.taskId)
    return Utils.getTimeIdOpenTimeStamp(config.unlockTimeId) or 0
end

ActivityCharacterGift._RefreshTaskUnlockTime = HL.Method(HL.Any, HL.Table) << function(self, cell, taskInfo)
    if not cell.unLockTimeText then
        return
    end

    local unlockTimestamp = self:_GetTaskUnlockTimestamp(taskInfo)
    local currTimestamp = DateTimeUtils.GetCurrentTimestampBySeconds()
    if unlockTimestamp <= currTimestamp then
        return
    end

    cell.unLockTimeText:InitCountDownText(unlockTimestamp, nil,
    function(leftTime)
        return string.format(Language.LUA_ACTIVITY_CHAR_GIFT_UNLOCK_TIME,
            UIUtils.getLeftTime(math.max(leftTime, 0)))
    end)
end

ActivityCharacterGift._StopUnlockCountdown = HL.Method() << function(self)
    for _, info in pairs(self.m_taskCellMap) do
        if info.cell and info.cell.unLockTimeText then
            info.cell.unLockTimeText:StopCountDown()
        end
    end
end


ActivityCharacterGift._GetCompletedTaskIds = HL.Method().Return(HL.Table) << function(self)
    local completedTaskIds = {}
    for _, taskInfo in ipairs(self.m_taskInfos) do
        if taskInfo.status == GEnums.ActivityConditionalTaskState.Completed then
            table.insert(completedTaskIds, taskInfo.taskId)
        end
    end
    return completedTaskIds
end

ActivityCharacterGift._HasCompletedTasks = HL.Method().Return(HL.Boolean) << function(self)
    for _, taskInfo in ipairs(self.m_taskInfos) do
        if taskInfo.status == GEnums.ActivityConditionalTaskState.Completed then
            return true
        end
    end
    return false
end

ActivityCharacterGift._ReceiveAllTaskRewards = HL.Method() << function(self)
    local completedTaskIds = self:_GetCompletedTaskIds()
    if #completedTaskIds <= 0 then
        return
    end
    GameInstance.player.activitySystem:SendReceiveTaskRewardConditionMultiStage(self.m_activityId, completedTaskIds)
end


ActivityCharacterGift._OnTaskCellFocusChanged = HL.Method(HL.String, HL.Boolean)
        << function(self, taskId, isTarget)
    if isTarget then
        self:_SetSelectedTask(taskId)
    elseif self.m_selectedTaskId == taskId then
        self:_SetSelectedTask(nil)
    end

    self:_ApplyControllerFocusState()
end

ActivityCharacterGift._GetTaskActionType = HL.Method(HL.Table).Return(HL.String) << function(self, taskInfo)
    if taskInfo.status == GEnums.ActivityConditionalTaskState.Completed then
        return TaskActionType.Receive
    end
    if taskInfo.status == GEnums.ActivityConditionalTaskState.Unlocked then
        return TaskActionType.Goto
    end
    return TaskActionType.None
end

ActivityCharacterGift._ToggleBindingIfValid = HL.Method(HL.Any, HL.Boolean) << function(self, bindingId, active)
    if bindingId and bindingId > 0 then
        InputManagerInst:ToggleBinding(bindingId, active)
    end
end

ActivityCharacterGift._RefreshTaskCellInput = HL.Method(HL.Any, HL.String) << function(self, cell, taskId)
    cell.btnClaim.onClick:RemoveAllListeners()
    cell.btnClaim.onClick:AddListener(function()
        self:_OnTaskCellRootClicked(taskId)
    end)
    cell.gotoNode.btnDetailButton.onClick:RemoveAllListeners()
    cell.gotoNode.btnDetailButton.onClick:AddListener(function()
        self:_OnTaskCellGotoClicked(taskId)
    end)

    if DeviceInfo.usingController then
        
        cell.button:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
        cell.button.onIsNaviTargetChanged = function(isTarget)
            self:_OnTaskCellFocusChanged(taskId, isTarget)
        end
        cell.receiveKeyHint:SetBindingId(cell.btnClaim.onClick.bindingId, true)
    end
end


ActivityCharacterGift._OnTaskCellRootClicked = HL.Method(HL.String) << function(self, taskId)
    local info = self.m_taskCellMap[taskId]
    if not (info and info.actionType == TaskActionType.Receive) then
        return
    end
    self:_ReceiveAllTaskRewards()
end

ActivityCharacterGift._OnTaskCellGotoClicked = HL.Method(HL.String) << function(self, taskId)
    local info = self.m_taskCellMap[taskId]
    if not (info and info.actionType == TaskActionType.Goto and info.taskInfo) then
        return
    end

    local jumpId = info.taskInfo.jumpId
    if string.isEmpty(jumpId) then
        return
    end
    local _, taskExtraInfo = Tables.activityCharacterGiftTaskExtraInfoTable:TryGetValue(taskId)
    local jumpLockedToast = taskExtraInfo and taskExtraInfo.jumpLockedToast
    
    
    if not string.isEmpty(jumpLockedToast) and not ActivityUtils.isActivityTaskJumpTargetVisible(jumpId) then
        Notify(MessageConst.SHOW_TOAST, jumpLockedToast)
        return
    end
    Utils.jumpToSystem(jumpId)
end

ActivityCharacterGift._SetSelectedTask = HL.Method(HL.Opt(HL.String)) << function(self, taskId)
    self.m_selectedTaskId = taskId or ''
end

ActivityCharacterGift._ApplyTaskActionState = HL.Method(HL.Table, HL.Boolean) << function(self, info, active)
    local cell = info.cell
    
    local receiveBindingId = cell.btnClaim.onClick.bindingId
    local gotoBindingId = cell.gotoNode.btnDetailButton.onClick.bindingId

    
    self:_ToggleBindingIfValid(receiveBindingId, false)
    self:_ToggleBindingIfValid(gotoBindingId, false)

    cell.rewardsKeyHint.gameObject:SetActive(active)

    if not active then
        return
    end

    local actionType = info.actionType or TaskActionType.None
    if actionType == TaskActionType.Receive then
        self:_ToggleBindingIfValid(receiveBindingId, true)
    elseif actionType == TaskActionType.Goto then
        self:_ToggleBindingIfValid(gotoBindingId, true)
    end
end

ActivityCharacterGift._SetTaskListNaviTarget = HL.Method(HL.Number) << function(self, index)
    if index <= 0 or index > #self.m_taskInfos or not DeviceInfo.usingController then
        return
    end
    local obj = self.view.taskListNode:Get(CSIndex(index))
    if not obj then
        self.view.taskListNode:ScrollToIndex(CSIndex(index), true)
        obj = self.view.taskListNode:Get(CSIndex(index))
    end
    local cell = obj and self.m_getCellFunc(obj)
    if cell then
        self:SetNaviTarget(cell.button)
    end
end

ActivityCharacterGift.OnActivityCenterNaviFailed = HL.Method() << function(self)
    local firstCell = self.view.taskListNode:GetRangeInView().x
    self:_SetTaskListNaviTarget(LuaIndex(firstCell))
end


ActivityCharacterGift._ApplyControllerFocusState = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    
    self:_ToggleBindingIfValid(self.m_viewBindingId, not self.m_taskListFocused)

    for _, info in pairs(self.m_taskCellMap) do
        if info.cell then
            self:_ApplyTaskCellFocusState(info)
        end
    end
    self:_RefreshReceiveAllBtn()
end


ActivityCharacterGift._ApplyTaskCellFocusState = HL.Method(HL.Table) << function(self, info)
    local cell = info.cell
    local taskFocused = self.m_taskListFocused and self.m_selectedTaskId == info.taskInfo.taskId 

    InputManagerInst:ToggleGroup(cell.inputBindingGroupMonoTarget.groupId, taskFocused)
    self:_ApplyTaskActionState(info, taskFocused)
end


ActivityCharacterGift._RefreshReceiveAllBtn = HL.Method() << function(self)
    self:_ToggleBindingIfValid(self.m_receiveAllBindingId, self:_HasCompletedTasks())
end

ActivityCharacterGift._InitShowCharBtn = HL.Method(HL.String) << function(self,characterId)
    if string.isEmpty(characterId) then
        logger.error("ActivityCharacterGift: characterId is empty", self.m_activityId)
        return
    end
    local node = self.view.showCharInfoBtn1
    self.view.showCharInfoBtn1.button.onClick:RemoveAllListeners()
    self.view.showCharInfoBtn1.button.onClick:AddListener(function()
        self:_OpenCharacterPreview(characterId)
    end)

    local charCfg = Tables.characterTable[characterId]
    node.nameTxt.text = charCfg.name
    node.professionIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, CharInfoUtils.getCharProfessionIconName(charCfg.profession))
    node.starGroup:InitStarGroup(charCfg.rarity)
end

ActivityCharacterGift.OnActivityUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId == self.m_activityId then
        self:_Refresh()
    end
end

HL.Commit(ActivityCharacterGift)
return ActivityCharacterGift
