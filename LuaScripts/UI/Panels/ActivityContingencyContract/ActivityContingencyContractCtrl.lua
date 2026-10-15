local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityContingencyContract
local PHASE_ID = PhaseId.ActivityCenter

ActivityContingencyContractCtrl = HL.Class('ActivityContingencyContractCtrl', uiCtrl.UICtrl)

ActivityContingencyContractCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CC_NEW_TAG_READ] = '_OnNewTagRead',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = '_OnStageUpdate',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdate',
    [MessageConst.ON_ACHIEVEMENT_UPDATE] = '_OnAchievementUpdate',
    [MessageConst.ON_ACTIVITY_PREPARE_TRANSITION_BACK_TO_TOP] = '_OnBackToTop',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE] = '_OnTaskUpdate',
}

ActivityContingencyContractCtrl.m_activityId = HL.Field(HL.String) << ""

ActivityContingencyContractCtrl.m_gameId = HL.Field(HL.String) << ""

ActivityContingencyContractCtrl.m_gotoDetailJumpId = HL.Field(HL.String) << ""

ActivityContingencyContractCtrl.m_shopEndTime = HL.Field(HL.Number) << -1

ActivityContingencyContractCtrl.m_gameplayEndTime = HL.Field(HL.Number) << -1

ActivityContingencyContractCtrl.m_allTagInfosMap = HL.Field(HL.Table)

ActivityContingencyContractCtrl.m_stageToTagMap = HL.Field(HL.Table)

ActivityContingencyContractCtrl.m_hasCreated = HL.Field(HL.Boolean) << false

ActivityContingencyContractCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_hasCreated = false
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    self.view.activityCommonInfo.view.leftBtnGroupNode.activityTaskEntry:InitActivityTaskEntry(args)
    self.view.activityCommonInfo.view.leftBtnGroupNode.activityShopEntry:InitActivityShopEntry(args)

    
    local info = Tables.activityContingencyContractTable[self.m_activityId]
    self.m_gotoDetailJumpId = Tables.activityTable[self.m_activityId].detailJumpId
    self.m_gameId = info.gameId
    local infosTable = ContingencyContractUtils.CreateTagFullInfosTable(self.m_gameId)
    self.m_allTagInfosMap = infosTable.allTagInfosMap
    self.m_stageToTagMap = ContingencyContractUtils.CreateStageToTagMap()
    self.view.activityCommonInfo.view.infoNode.detailsYellowTxt.text = info.otherDesc

    
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    self.m_gameplayEndTime = activityData.gameplayEndTime
    self.m_shopEndTime = activityData.endTime
    self.view.activityCommonInfo.view.infoNode.countDownWidget:InitCountDownText(self.m_gameplayEndTime, nil, function(leftSec)
        local leftTime = UIUtils.getLeftTime(leftSec)
        return string.format(Language.LUA_ACTIVITY_CONTINGENCY_CONTRACT_GAME_REMAIN_TIME_TEXT, leftTime)
    end)

    
    self:_SyncHistoryBestScoreRtpc()

    self:_ActivityUpdate()
    self:_StageUpdate(true)
    self:_UpdateData()
    self.m_hasCreated = true
    self:PlayAnimationIn()
end


ActivityContingencyContractCtrl._SyncHistoryBestScoreRtpc = HL.Method() << function(self)
    local rtpcName = "au_music_rtpc_cc_v1d6_history_highest_stars"
    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local isGameplayEnd = self.m_gameplayEndTime - currentTime <= 0
    if isGameplayEnd then
        AudioManager.SetRtpc(rtpcName, -20)
        return
    end

    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activityData or activityData.status ~= GEnums.ActivityStatus.InProgress then
        AudioManager.SetRtpc(rtpcName, -10)
        return
    end

    local gameData = GameInstance.player.contingencyContractSystem:GetCcGameData(self.m_gameId)
    if gameData then
        AudioManager.SetRtpc(rtpcName, gameData.historyBestScore)
    else
        AudioManager.SetRtpc(rtpcName, 0)
    end
end

ActivityContingencyContractCtrl._PlayCommonIn = HL.Method() << function(self)
    
    if self.m_hasCreated then
        self.view.animationWrapper:Play("activity_contingencycontract_in", function()
            self.view.animationWrapper:Play("activity_contingencycontract_effect_loop")
        end)
    end
end

ActivityContingencyContractCtrl._ActivityUpdate = HL.Method() << function(self)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local info = Tables.activityContingencyContractTable[self.m_activityId]

    if activityData.status == GEnums.ActivityStatus.InProgress then
        
        self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot("ActivityContingencyContractDetail", self.m_activityId)
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityTaskEntry.view.redDot:InitRedDot("ActivityContingencyContractTaskDetail", self.m_activityId)
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityShopEntry.view.redDot:InitRedDot("ActivityContingencyContractShopDetail", self.m_activityId)
        
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityTaskEntry.view.gameObject:SetActive(true)
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityShopEntry.view.gameObject:SetActive(true)
        self.view.activityCommonInfo.view.historyHighNode.gameObject:SetActive(true)
    else
        
        self.view.activityCommonInfo.view.historyHighNode.gameObject:SetActive(false)
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityTaskEntry.view.gameObject:SetActive(false)
        self.view.activityCommonInfo.view.leftBtnGroupNode.activityShopEntry.view.gameObject:SetActive(false)
    end
end

ActivityContingencyContractCtrl._StageUpdate = HL.Method(HL.Opt(HL.Boolean)) << function(self, onCreate)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local info = Tables.activityContingencyContractTable[self.m_activityId]
    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local isGameplayEnd = self.m_gameplayEndTime - currentTime <= 0
    self.view.activityCommonInfo.view.gotoNode.endPrompt.gameObject:SetActive(isGameplayEnd)

    
    if not onCreate and isGameplayEnd then
        ActivityUtils.backToMainHud(true)
    end

    
    if activityData.status == GEnums.ActivityStatus.InProgress then
        if isGameplayEnd then
            self:_OnGameplayEnd()
        else
            
            self:_RefreshTagUpdateDetailTip(onCreate)
        end
    
    else
        if isGameplayEnd then
            self.view.activityCommonInfo.view.infoNode.countDownWidget:InitCountDownText(self.m_shopEndTime)
            self.view.activityCommonInfo.view.gotoNode.stateController:SetState("None")
            ActivityUtils.setFalseIntroMissionActivity(self.m_activityId) 
        end
    end
end

ActivityContingencyContractCtrl._RefreshTagUpdateDetailTip = HL.Method(HL.Opt(HL.Boolean)) << function(self, onCreate)
    local renewTipsNode = self.view.activityCommonInfo.view.gotoNode
    local unreadStage = self:_GetCcNewTagStage(onCreate)
    if unreadStage then
        
        if not onCreate and PhaseManager:GetTopPhaseId()==PHASE_ID then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU)
        end
        self:_InitTagRenewTips(unreadStage)
    else
        renewTipsNode.renewTips.gameObject:SetActive(false)
    end
end

ActivityContingencyContractCtrl._InitTagRenewTips = HL.Method(HL.String) << function(self, unreadStage)
    local renewTipsNode = self.view.activityCommonInfo.view.gotoNode
    renewTipsNode.renewTips.gameObject:SetActive(true)
    local tagList = self.m_stageToTagMap[unreadStage]
    local newTagCount = tagList and #tagList or 0
    renewTipsNode.reNewNumTxt.text = string.format(Language.LUA_ACTIVITY_CONTINGENCY_CONTRACT_TAG_UPDATE, newTagCount)
    if not ActivityUtils.isCcFirstEnterSelectAfterUpdate(unreadStage) then
        renewTipsNode.btnDetail.onClick:RemoveAllListeners()
        renewTipsNode.btnDetail.onClick:AddListener(function()
            ActivityUtils.setCcFirstEnterSelectAfterUpdate(unreadStage)
            ActivityUtils.setFalseNewActivityBubble(self.m_activityId)
            ActivityUtils.setFalseNewActivityBubble(unreadStage)
            Utils.jumpToSystem(self.m_gotoDetailJumpId)
            
            if self:_CheckCcAllNewTagRead(unreadStage) then
                self.view.activityCommonInfo.view.gotoNode.renewTips.gameObject:SetActive(false)
            end
        end)
        Notify(MessageConst.ON_CC_FIRST_ENTER_SELECT_AFTER_UPDATE)
    end
end

ActivityContingencyContractCtrl._OnGameplayEnd = HL.Method() << function(self)
    self.view.activityCommonInfo.view.infoNode.countDownWidget:InitCountDownText(self.m_shopEndTime, nil, function(leftSec)
        local leftTime = UIUtils.getLeftTime(leftSec)
        return string.format(Language.LUA_ACTIVITY_CONTINGENCY_CONTRACT_SHOP_REMAIN_TIME_TEXT, leftTime)
    end)
    self.view.activityCommonInfo.view.gotoNode.stateController:SetState("None")
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:Stop()
    self.view.activityCommonInfo.view.leftBtnGroupNode.activityTaskEntry.view.redDot:Stop()
    self.view.activityCommonInfo.view.gotoNode.renewTips.gameObject:SetActive(false)
    self.view.activityCommonInfo.view.historyHighNode.gameObject:SetActive(false)
end

ActivityContingencyContractCtrl._OnNewTagRead = HL.Method(HL.Number) << function(self, tagId)
    local stageId = self.m_allTagInfosMap[tagId].unlockStage
    if string.isEmpty(stageId) then
        return
    end
    if self:_CheckCcAllNewTagRead(stageId) then
        self.view.activityCommonInfo.view.gotoNode.renewTips.gameObject:SetActive(false)
    end
end

ActivityContingencyContractCtrl._GetCcNewTagStage = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Opt(HL.String)) << function(self, onCreate)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local gameData = GameInstance.player.contingencyContractSystem:GetCcGameData(self.m_gameId)
    if gameData == nil then
        return nil
    end
    local unreadStageId
    for stageId, tagList in pairs(self.m_stageToTagMap) do
        local stageData = activityData:GetStageData(stageId)
        if stageData then
            local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
            if status == GEnums.ActivityConditionalStageState.Unlocked then
                
                if not ActivityUtils.isCcFirstEnterSelectAfterUpdate(stageId) then
                    unreadStageId = stageId
                end
                for _, tagId in ipairs(tagList) do
                    local tagInfo = self.m_allTagInfosMap[tagId]
                    if not ActivityUtils.isCcTagRead(tagId) then
                        
                        if tagInfo.unlockScore > gameData.historyBestScore then
                            ActivityUtils.setCcTagRead(tagId)
                        else
                            unreadStageId = stageId
                        end
                    end
                end
            end
        end
    end
    return unreadStageId
end

ActivityContingencyContractCtrl._CheckCcAllNewTagRead = HL.Method(HL.String).Return(HL.Boolean) << function(self, stageId)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local stageData = activityData:GetStageData(stageId)
    local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
    if status ~= GEnums.ActivityConditionalStageState.Unlocked then
        return true
    end
    local tagList = self.m_stageToTagMap[stageId]
    for _, tagId in ipairs(tagList) do
        if not ActivityUtils.isCcTagRead(tagId) then
            return false
        end
    end
    return true
end

ActivityContingencyContractCtrl._OnTaskUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    self:_UpdateData()
end

ActivityContingencyContractCtrl._OnStageUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    self:_StageUpdate()
    self:_UpdateData()
    self:_SyncHistoryBestScoreRtpc()
end

ActivityContingencyContractCtrl._OnActivityUpdate = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activity then
        return
    end
    self:_ActivityUpdate()
    self:_UpdateData()
    self:_SyncHistoryBestScoreRtpc()
end

ActivityContingencyContractCtrl._OnAchievementUpdate = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local _, activityAchievementCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    if not activityAchievementCfg then
        self.view.activityCommonInfo.view.historyHighNode.stateController:SetState("noMedal")
        return
    end
    local achievementId = activityAchievementCfg.achievementId
    local achievementData = Tables.achievementTable[achievementId]
    local achievementSystem = GameInstance.player.achievementSystem
    local succ, playerInfo = achievementSystem.achievementData.achievementInfos:TryGetValue(achievementId)
    local obtained = succ and playerInfo.level >= achievementData.initLevel
    local plated = obtained and achievementData.canBePlated and playerInfo.isPlated
    local medalState = "noMedal"
    if plated then
        medalState = "hasMedalPlated"
    elseif obtained then
        medalState = "hasMedal"
    end
    self.view.activityCommonInfo.view.historyHighNode.stateController:SetState(medalState)
end

ActivityContingencyContractCtrl._UpdateData = HL.Method() << function(self)
    
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local gameData = GameInstance.player.contingencyContractSystem:GetCcGameData(self.m_gameId)
    local score
    if gameData then
        score = gameData.historyBestScore
    end
    
    
    
    
    
    
    self.view.activityCommonInfo.view.historyHighNode.historyNumTxt.text = score
    
    self:_OnAchievementUpdate()
    
    local completedTaskCount = 0
    local totalTaskCount = 0
    for _, taskData in cs_pairs(activityData.taskDataDict) do
        local status = GEnums.ActivityConditionalTaskState.__CastFrom(taskData.Status)
        if status ~= GEnums.ActivityConditionalTaskState.Locked then
            totalTaskCount = totalTaskCount + 1
        end
        if status == GEnums.ActivityConditionalTaskState.Completed or
            status == GEnums.ActivityConditionalTaskState.Rewarded then
            completedTaskCount = completedTaskCount + 1
        end
    end
end

ActivityContingencyContractCtrl._OnBackToTop = HL.Method() << function(self)
    self:_PlayCommonIn()
    Notify(MessageConst.ON_ACTIVITY_CENTER_BACK_TO_TOP)
end

HL.Commit(ActivityContingencyContractCtrl)