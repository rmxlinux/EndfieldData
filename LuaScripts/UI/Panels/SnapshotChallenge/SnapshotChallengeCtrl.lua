
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SnapshotChallenge
local PHASE_ID = PhaseId.SnapshotChallenge


local activitySystem = GameInstance.player.activitySystem

local snapshotSystem = GameInstance.player.snapshotSystem

local missionSystem = GameInstance.player.mission

local StageStateEnum = {
    Lock = 0,
    NeedCompletePreTask = 1,
    InProgress = 2,
    Complete = 3,
    Rewarded = 4,
}




























SnapshotChallengeCtrl = HL.Class('SnapshotChallengeCtrl', uiCtrl.UICtrl)







SnapshotChallengeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = '_OnMultiStageUpdate',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
}




SnapshotChallengeCtrl.m_info = HL.Field(HL.Table)


SnapshotChallengeCtrl.m_stageNodeList = HL.Field(HL.Table)


SnapshotChallengeCtrl.m_stageProgressBarList = HL.Field(HL.Table)


SnapshotChallengeCtrl.m_updateCor = HL.Field(HL.Thread)


SnapshotChallengeCtrl.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))


SnapshotChallengeCtrl.m_identifyDescCellCache = HL.Field(HL.Forward("UIListCache"))


SnapshotChallengeCtrl.m_activityId = HL.Field(HL.String) << ""


SnapshotChallengeCtrl.m_defaultStageId = HL.Field(HL.String) << ""

local WAIT_FOR_ANIM_TIME = 0.5








SnapshotChallengeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitArg(arg)
    if not self:_CheckActivityExist() then
        return
    end
    self:_InitUI()
    self:_InitData()
    self:_UpdateData(true)
    self:_RefreshAllUI()
end




SnapshotChallengeCtrl._InitArg = HL.Method(HL.Any) << function(self, arg)
    if type(arg) == "string" then
        self.m_activityId = arg
    else
        self.m_activityId = arg.activityId
        self.m_defaultStageId = arg.stageId or ""
    end
end



SnapshotChallengeCtrl._CheckActivityExist = HL.Method().Return(HL.Boolean) << function(self)
    
    if not activitySystem:GetActivity(self.m_activityId) then
        self:_StartCoroutine(function()
            coroutine.wait(WAIT_FOR_ANIM_TIME)
            Notify(MessageConst.SHOW_TOAST,Language.LUA_ACTIVITY_FORBIDDEN)
            self:_Close()
        end)
        return false
    end
    return true
end



SnapshotChallengeCtrl.OnClose = HL.Override() << function(self)
    self.m_updateCor = self:_ClearCoroutine(self.m_updateCor)
    local isOpen, _ = PhaseManager:IsOpen(PhaseId.Dialog)
    if isOpen then
        Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 0 })
    end
end





SnapshotChallengeCtrl._InitData = HL.Method() << function(self)
    local activityId = self.m_activityId
    local _, activityCfg = Tables.activityTable:TryGetValue(activityId)
    
    local activityData = activitySystem:GetActivity(activityId)

    
    self.m_info = {
        activityId = activityId,
        activityName = activityCfg.name,
        instructionId = activityCfg.instructionId,
        
        startTime = activityData and activityData.startTime or -1,
        nextStageUnlockTime = -1,
        stageInfoList = {},
        
        curSelectStage = 1,
        curStageInfo = nil,
    }
    
    local _, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(activityId)
    for stageId, stageCfg in pairs(multiStageCfg.stageList) do
        local _, activitySnapshotCfg = Tables.activitySnapshotChallengeTable:TryGetValue(stageId)
        local levelId = stageCfg.levelId
        local hasLevelCfg, levelCfg = Tables.levelDescTable:TryGetValue(levelId)
        local levelName = hasLevelCfg and levelCfg.showName or ""
        local missionId = stageCfg.missionId
        local questId = stageCfg.questId
        
        local rewardId = stageCfg.rewardId
        
        local identifyGroupId = snapshotSystem:GetQuestIdentifyGroupId(missionId, questId)
        local identifyDescInfos = {}
        local hasCfg, identifyGroupCfg = Tables.snapshotIdentifyGroupTable:TryGetValue(identifyGroupId)
        if hasCfg then
            for _, identifyId in pairs(identifyGroupCfg.identifyIds) do
                local desc = GameInstance.player.snapshotSystem:GetIdentifyDesc(identifyId)
                table.insert(identifyDescInfos, desc)
            end
        end
        
        local preTaskId = activitySnapshotCfg.missionId
        local preTaskState = missionSystem:GetMissionState(preTaskId)
        local isPreTaskComplete = preTaskState == CS.Beyond.Gameplay.MissionSystem.MissionState.Completed
        
        local canShowPreTaskDetail = preTaskState == CS.Beyond.Gameplay.MissionSystem.MissionState.Processing
        
        local stageInfo = {
            stageId = stageId,
            missionId = missionId,
            questId = questId,
            questTitle = stageCfg.name,
            questDesc = stageCfg.desc,
            mapJumpId = stageCfg.mapJumpId,
            levelName = levelName,
            timeOffset = stageCfg.timeOffset,
            rewardList = UIUtils.getRewardItems(rewardId),
            sortId = stageCfg.sortId,
            
            preTaskMissionId = preTaskId, 
            isPreTaskComplete = isPreTaskComplete,
            canShowPreTaskDetail = canShowPreTaskDetail,
            normalImg = activitySnapshotCfg.normalImg,
            completeImg = activitySnapshotCfg.completeImg,
            normalDesc = activitySnapshotCfg.normalStoryDesc,
            completeDesc = activitySnapshotCfg.completeStoryDesc,
            
            identifyGroupId = identifyGroupId,
            identifyDescInfos = identifyDescInfos,
            
            state = StageStateEnum.Lock,
            identifyComplete = false,
        }
        table.insert(self.m_info.stageInfoList, stageInfo)
    end
    table.sort(self.m_info.stageInfoList, function(a, b)
        return a.sortId < b.sortId
    end)
end




SnapshotChallengeCtrl._UpdateData = HL.Method(HL.Boolean) << function(self, isInit)
    self.m_info.nextStageUnlockTime = -1
    local firstCompleteStageIndex = -1
    local firstInProgressStageIndex = -1
    local initArgDefaultIndex = -1
    for i, stageInfo in pairs(self.m_info.stageInfoList) do
        self:_UpdateStageInfo(stageInfo)
        if stageInfo.stageId == self.m_defaultStageId and stageInfo.state ~= StageStateEnum.Lock then
            initArgDefaultIndex = i
        end
        if self.m_info.startTime > 0 and self.m_info.nextStageUnlockTime < 0 and stageInfo.state == StageStateEnum.Lock then
            self.m_info.nextStageUnlockTime = stageInfo.unlockTime
        end
        if firstCompleteStageIndex < 0 and stageInfo.state == StageStateEnum.Complete then
            firstCompleteStageIndex = i
        end
        if firstInProgressStageIndex < 0 and stageInfo.state == StageStateEnum.InProgress then
            firstInProgressStageIndex = i
        end
    end
    
    if isInit then
        local defaultIndex = 1
        if initArgDefaultIndex > 0 then
            defaultIndex = initArgDefaultIndex
        elseif firstCompleteStageIndex > 0 then
            defaultIndex = firstCompleteStageIndex
        elseif firstInProgressStageIndex > 0 then
            defaultIndex = firstInProgressStageIndex
        end
        defaultIndex = math.max(defaultIndex, 1)
        self.m_info.curSelectStage = defaultIndex
    end
end




SnapshotChallengeCtrl._UpdateStageInfo = HL.Method(HL.Table) << function(self, stageInfo)
    local activityId = self.m_info.activityId
    local stageId = stageInfo.stageId
    
    local activityData = activitySystem:GetActivity(activityId)
    local stageData = activityData:GetStageData(stageId)
    stageInfo.unlockTime = self.m_info.startTime + stageInfo.timeOffset * Const.SEC_PER_HOUR
    
    local state = StageStateEnum.Lock
    if stageData ~= nil then
        local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
        local nowTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        if status == GEnums.ActivityConditionalStageState.Locked and nowTime >= stageInfo.unlockTime then
            local canForceShow, failDesc = activityData:CanShowStage(stageInfo.stageId)
            if canForceShow then
                status = GEnums.ActivityConditionalStageState.Unlocked
                stageInfo.preTaskTipsDesc = failDesc
            end
        end
        if status == GEnums.ActivityConditionalStageState.Locked then
            state = StageStateEnum.Lock
        elseif status == GEnums.ActivityConditionalStageState.Unlocked then
            state = stageInfo.isPreTaskComplete and StageStateEnum.InProgress or StageStateEnum.NeedCompletePreTask
        elseif status == GEnums.ActivityConditionalStageState.Completed then
            state = StageStateEnum.Complete
        elseif status == GEnums.ActivityConditionalStageState.Rewarded then
            state = StageStateEnum.Rewarded
        end
    end
    stageInfo.state = state
    stageInfo.identifyComplete = state == StageStateEnum.Complete or state == StageStateEnum.Rewarded
end





SnapshotChallengeCtrl._InitUI = HL.Method() << function(self)
    self.view.commonTitle.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.commonTitle.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, self.m_info.instructionId)
    end)
    self.view.preTaskBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.Mission, {
            autoSelect = self.m_info.curStageInfo.preTaskMissionId
        })
    end)
    self.view.goToBtn.onClick:AddListener(function()
        
        local stageInfo = self.m_info.curStageInfo
        Utils.jumpToSystem(stageInfo.mapJumpId)
    end)
    self.view.rewardBtn.onClick:AddListener(function()
        local stageInfo = self.m_info.curStageInfo
        activitySystem:SendReceiveRewardConditionMultiStage(self.m_info.activityId, stageInfo.stageId)
    end)
    
    self.m_rewardCellCache = UIUtils.genCellCache(self.view.itemRewardCell)
    self.m_identifyDescCellCache = UIUtils.genCellCache(self.view.identifyDescCell)
    
    self.m_stageNodeList = {}
    self.m_stageProgressBarList = {}
    for i = 1, self.view.config.MAX_STAGE_NUM do
        table.insert(self.m_stageNodeList, self.view.stageProgress["stageNode" .. i])
        table.insert(self.m_stageProgressBarList, self.view.stageProgress["stageProgressBar" .. i])
    end
    table.insert(self.m_stageProgressBarList, self.view.stageProgress.stageProgressBarFinal)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    
    local preActionId = self.view.stageProgress.keyHintLeft.actionId
    local nextActionId = self.view.stageProgress.keyHintRight.actionId
    self:BindInputPlayerAction(preActionId, function()
        AudioAdapter.PostEvent("Au_UI_Button_TundraTaleTab")
        local count = self.view.config.MAX_STAGE_NUM
        local newIndex = (self.m_info.curSelectStage + count - 2) % count + 1
        if newIndex ~= self.m_info.curSelectStage then
            self:_OnClickStageBtn(newIndex)
        end
    end)
    self:BindInputPlayerAction(nextActionId, function()
        AudioAdapter.PostEvent("Au_UI_Button_TundraTaleTab")
        local count = self.view.config.MAX_STAGE_NUM
        local newIndex = self.m_info.curSelectStage % count + 1
        if newIndex ~= self.m_info.curSelectStage then
            self:_OnClickStageBtn(newIndex)
        end
    end)
end



SnapshotChallengeCtrl._RefreshAllUI = HL.Method() << function(self)
    self:_RefreshTitle()
    self:_RefreshStageCell()
    self:_RefreshContentUI(self.m_info.curSelectStage)
end



SnapshotChallengeCtrl._RefreshTitle = HL.Method() << function(self)
    self.view.commonTitle.titleTxt.text = self.m_info.activityName
    local nowTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local hasUnlockTime = self.m_info.nextStageUnlockTime > nowTime
    self.view.commonTitle.timeTxtNode.gameObject:SetActive(hasUnlockTime)
    if hasUnlockTime then
        self.m_updateCor = self:_ClearCoroutine(self.m_updateCor)
        self.m_updateCor = self:_StartCoroutine(function()
            self.view.commonTitle.timeTxtNode.gameObject:SetActive(true)
            local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
            while curTime <= self.m_info.nextStageUnlockTime do
                local leftTime = self.m_info.nextStageUnlockTime - curTime
                self.view.commonTitle.timeTxt.text = UIUtils.getLeftTime(leftTime)
                coroutine.wait(1)
            end
            self.view.commonTitle.timeTxtNode.gameObject:SetActive(false)
        end)
    else
        self.view.commonTitle.timeTxtNode.gameObject:SetActive(false)
    end
end



SnapshotChallengeCtrl._RefreshStageCell = HL.Method() << function(self)
    local infoCount = #self.m_info.stageInfoList
    local maxUICount = self.view.config.MAX_STAGE_NUM
    
    for i = 1, maxUICount do
        local isShow = i <= infoCount
        self.m_stageNodeList[i].gameObject:SetActive(isShow)
        self.m_stageProgressBarList[i + 1].gameObject:SetActive(isShow)
    end
    
    local completeCount = 0
    for i = 1, infoCount do
        local stageInfo = self.m_info.stageInfoList[i]
        
        local stageNode = self.m_stageNodeList[i]
        
        local stageBar = self.m_stageProgressBarList[i]
        
        local isComplete = stageInfo.state == StageStateEnum.Complete
        local isRewarded = stageInfo.state == StageStateEnum.Rewarded
        if stageInfo.state == StageStateEnum.Lock then
            stageNode.stateCtrl:SetState("NotUnlocked")
            stageBar.progressImg.fillAmount = 0
        else
            if isComplete or isRewarded then
                stageNode.stateCtrl:SetState("Complete")
                stageBar.progressImg.fillAmount = 1
                completeCount = completeCount + 1
            else
                stageNode.stateCtrl:SetState("Normal")
                stageBar.progressImg.fillAmount = 0
            end
        end
        
        stageNode.stateCtrl:SetState(self.m_info.curSelectStage == i and "Select" or "UnSelect")
        
        stageNode.btn.onClick:RemoveAllListeners()
        stageNode.btn.onClick:AddListener(function()
            if self.m_info.curSelectStage == i then
                return
            end
            self:_OnClickStageBtn(i)
        end)
        
        local isFirstUnlock = stageInfo.state ~= StageStateEnum.Lock
            and stageInfo.state ~= StageStateEnum.Rewarded
            and ActivityUtils.isNewActivityConditionalStage(stageInfo.stageId)
        if isFirstUnlock or stageInfo.state == StageStateEnum.Complete then
            stageNode.stateCtrl:SetState("HasRedDot")
        else
            stageNode.stateCtrl:SetState("NoRedDot")
        end
    end
    local finalBar = self.m_stageProgressBarList[infoCount + 1]
    finalBar.progressImg.fillAmount = completeCount == infoCount and 1 or 0
end




SnapshotChallengeCtrl._RefreshContentUI = HL.Method(HL.Number) << function(self, stageIndex)
    self.m_info.curSelectStage = stageIndex
    local stageInfo = self.m_info.stageInfoList[stageIndex]
    local isComplete = stageInfo.state == StageStateEnum.Complete
    local isRewarded = stageInfo.state == StageStateEnum.Rewarded
    local isCompleteOrRewarded = isComplete or isRewarded
    self.m_info.curStageInfo = stageInfo
    
    self.view.normalImg:LoadSprite(UIConst.UI_SPRITE_SNAPSHOT_CHALLENGE, stageInfo.normalImg)
    self.view.completeImg:LoadSprite(UIConst.UI_SPRITE_SNAPSHOT_CHALLENGE, stageInfo.completeImg)
    self.view.normalImg.gameObject:SetActive(not isCompleteOrRewarded)
    self.view.completeImg.gameObject:SetActive(isCompleteOrRewarded)
    self.view.descTxt.text = isCompleteOrRewarded and stageInfo.completeDesc or stageInfo.normalDesc
    self.view.questTitleTxt.text = stageInfo.questTitle
    self.view.levelNameTxt.text = stageInfo.levelName
    self.view.questDescTxt.text = stageInfo.questDesc
    
    self.m_identifyDescCellCache:Refresh(#stageInfo.identifyDescInfos, function(cell, luaIndex)
        local curStageInfo = self.m_info.curStageInfo
        local desc = curStageInfo.identifyDescInfos[luaIndex]
        cell.descTxt.text = desc
        cell.stateController:SetState(curStageInfo.identifyComplete and "Complete" or "Normal")
        cell.finishedIcon.gameObject:SetActive(curStageInfo.identifyComplete)
        cell.gameObject.name = "identifyDescCell_" .. luaIndex
    end)
    
    
    self.m_rewardCellCache:Refresh(#stageInfo.rewardList, function(rewardCell, luaIndex)
        rewardCell:InitItem(stageInfo.rewardList[luaIndex], function()
            UIUtils.showItemSideTips(rewardCell)
        end)
        rewardCell:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
        rewardCell.view.rewardedCover.gameObject:SetActive(isRewarded)
    end)
    self.view.rewardedImg.gameObject:SetActive(isRewarded)
    self.view.rewardListNaviGroup.onIsFocusedChange:RemoveAllListeners()
    self.view.rewardListNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    
    if isComplete then
        self.view.btnNodeStateCtrl:SetState("CanGetReward")
    elseif stageInfo.state == StageStateEnum.NeedCompletePreTask then
        if stageInfo.canShowPreTaskDetail then
            self.view.btnNodeStateCtrl:SetState("HasPreTask")
        else
            self.view.btnNodeStateCtrl:SetState("HasPreTaskNoJump")
        end
    else
        self.view.btnNodeStateCtrl:SetState("Normal")
    end
    if stageInfo.preTaskTipsDesc then
        self.view.preTaskTipsTxt.text = stageInfo.preTaskTipsDesc
    end
end




SnapshotChallengeCtrl._ChangeSelectStage = HL.Method(HL.Number) << function(self, stageIndex)
    local oldIndex = self.m_info.curSelectStage
    
    local oldStageNode = self.m_stageNodeList[oldIndex]
    oldStageNode.stateCtrl:SetState("UnSelect")
    
    local curStageNode = self.m_stageNodeList[stageIndex]
    curStageNode.stateCtrl:SetState("Select")
    local curStageInfo = self.m_info.stageInfoList[stageIndex]
    
    self:_RefreshContentUI(stageIndex)
    
    ActivityUtils.setFalseNewActivityConditionalStage(curStageInfo.stageId)
    if curStageInfo.state == StageStateEnum.Complete then
        curStageNode.stateCtrl:SetState("HasRedDot")
    else
        curStageNode.stateCtrl:SetState("NoRedDot")
    end
end






SnapshotChallengeCtrl._OnMultiStageUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if self.m_info.activityId ~= activityId then
        return
    end
    self:_UpdateData(false)
    self:_RefreshAllUI()
end




SnapshotChallengeCtrl._OnClickStageBtn = HL.Method(HL.Number) << function(self, luaIndex)
    local stageInfo = self.m_info.stageInfoList[luaIndex]
    if stageInfo.state ~= StageStateEnum.Lock then
        self:_ChangeSelectStage(luaIndex)
    else
        local nowTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        if stageInfo.unlockTime > nowTime then
            
            Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_LOCK_TOAST_TIME)
        else
            
            Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_LOCK_TOAST_PRECONDITION)
        end
    end
end



SnapshotChallengeCtrl._Close = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end




SnapshotChallengeCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    if id ~= self.m_activityId then
        return
    end
    local activity = GameInstance.player.activitySystem:GetActivity(id)
    if not activity then
        Notify(MessageConst.SHOW_TOAST,Language.LUA_ACTIVITY_FORBIDDEN)
        self:_Close()
    end
end


HL.Commit(SnapshotChallengeCtrl)
