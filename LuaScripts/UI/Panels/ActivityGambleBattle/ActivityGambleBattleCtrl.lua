local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityGambleBattle

ActivityGambleBattleCtrl = HL.Class('ActivityGambleBattleCtrl', uiCtrl.UICtrl)

ActivityGambleBattleCtrl.m_system = HL.Field(HL.Any)






ActivityGambleBattleCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_QUEST_STATE_CHANGE] = '_OnEntryQuestStateChange',
    [MessageConst.ON_ACTIVITY_REQ_RANK_LIST] = '_OnActivityReqRankList',
    [MessageConst.ON_FRIEND_INFO_SYNC] = '_OnFriendInfoSync',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE] = '_OnActivityUpdated',
    [MessageConst.ON_ACTIVITY_MILESTONE_REWARD_RECEIVED] = '_OnActivityUpdated',
    [MessageConst.ON_RACING_DUNGEON_GET_MILESTONE_REWARD] = '_OnActivityUpdated',
}

ActivityGambleBattleCtrl.m_activityId = HL.Field(HL.String) << ''
ActivityGambleBattleCtrl.m_rankRelatedId = HL.Field(HL.String) << ''


ActivityGambleBattleCtrl.m_rankScore = HL.Field(HL.Number) << 0
ActivityGambleBattleCtrl.m_rankIndex = HL.Field(HL.Number) << 0
ActivityGambleBattleCtrl.m_rawRankInfoDic = HL.Field(HL.Userdata)
ActivityGambleBattleCtrl.m_rankInfoReady = HL.Field(HL.Boolean) << false
ActivityGambleBattleCtrl.m_roleSimpleInfoReady = HL.Field(HL.Boolean) << false


ActivityGambleBattleCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_system = GameInstance.player.gambleBattleSystem
    self.m_activityId = arg.activityId
    self.m_rankRelatedId = Tables.GambleBattleConst.rankRelatedId

    arg.skipReceive = true
    self.view.activityCommonInfo:InitActivityCommonInfo(arg)
    self.m_system:RefreshProgressFromRecord()
    ActivityUtils.playGambleBattleBgm("")
    self.view.taskBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.ActivityCoinReward, {
            activityId = self.m_activityId,
            openInDungeon = false,
            stateName = "GambleBattle",
        })
    end)
    self.view.milestoneBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.GambleBattleMilestone, {
            activityId = self.m_activityId,
            stateName = "GambleBattle",
        })
    end)
    
    
    
    
    
    


    self.view.rankingBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.ActivityRanking, {
            activityId = self.m_activityId,
            rankRelatedId = self.m_rankRelatedId,
            stateName = "GambleBattle",
        })
    end)



    self.view.btnStartGame.onClick:AddListener(function()
        
        ActivityUtils.GameEventLogGambleActivityVisit("click_open_gamble_panel")
        ClientDataManagerInst:SetBool(self.m_activityId .. "_gamble_battle_start_challenge_clicked", true, false, EClientDataTimeValidType.Permanent)
        Notify(MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE)
        LuaSystemManager.uiRestoreSystem:AddRequest(Tables.GambleBattleConst.gambleBattleDungeonId)
        PhaseManager:OpenPhase(PhaseId.GambleBattleMain, { openedFromActivity = true })
    end)

    self.view.btnContinueGame.onClick:AddListener(function()
        
        ActivityUtils.GameEventLogGambleActivityVisit("click_continue_gamble")
        ActivityUtils.stopGambleBattleBgm()
        LuaSystemManager.uiRestoreSystem:AddRequest(Tables.GambleBattleConst.gambleBattleDungeonId)
        GameInstance.dungeonManager:TryReqEnterDungeon(Tables.GambleBattleConst.gambleBattleDungeonId, "")
    end)

    self.view.btnStartGame.gameObject:SetActive(false)
    self.view.btnContinueGame.gameObject:SetActive(false)
    self.view.cdState.gameObject:SetActive(false)

    self.view.activityCommonInfo.view.gotoNode.btnDetail.onClick:RemoveAllListeners()
    self.view.activityCommonInfo.view.gotoNode.btnDetail.gameObject:SetActive(false)

    
    self.view.taskBtnRedDot:InitRedDot("ActivityGambleBattleTask", self.m_activityId)
    self.view.milestoneBtnRedDot:InitRedDot("ActivityGambleBattleMilestone", self.m_activityId)
    self.view.rankingBtnRedDot:InitRedDot("ActivityGambleBattleRanking", self.m_activityId)
    self.view.startChallengeRedDot:InitRedDot("ActivityGambleBattleStartChallenge", self.m_activityId)
    self.view.continueChallengeRedDot:InitRedDot("ActivityGambleBattleContinueChallenge", self.m_activityId)

    local _, achievementData = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    self.view.dungeonMedalCell:InitCommonMedalNode(achievementData.achievementId)

    self:_RefreshEntryProgress()
    self:_RefreshEntryVisible()
    self:_RefreshStartContinueButtons()
end






ActivityGambleBattleCtrl.OnClose = HL.Override() << function(self)
    ActivityUtils.stopGambleBattleBgm()
end


ActivityGambleBattleCtrl._RefreshEntryVisible = HL.Method() << function(self)
    local visible = ActivityUtils.isGambleBattleEntryUnlocked(self.m_activityId)
    self.view.taskBtn.gameObject:SetActive(visible)
    self.view.milestoneBtn.gameObject:SetActive(visible)
    self.view.rankingBtn.gameObject:SetActive(visible)
    
    self.view.taskBtn.transform.parent.gameObject:SetActive(visible)
end

ActivityGambleBattleCtrl._OnEntryQuestStateChange = HL.Method(HL.Any) << function(self, arg)
    local questId = unpack(arg)
    if questId == "a1m19_q#2" then
        self:_RefreshEntryVisible()
    end
end

ActivityGambleBattleCtrl._RefreshEntryProgress = HL.Method() << function(self)
    local finishTaskNum, maxTaskNum = ActivityUtils.GetTaskCompletionCount(self.m_activityId)
    self.view.taskNumTxt.text = string.format("%s/%s", finishTaskNum, maxTaskNum)

    local milestoneCurScore = ActivityUtils.GetRacingDungeonMilestoneCurrScore(self.m_activityId)
    local milestoneMaxScore = ActivityUtils.GetRacingDungeonMilestoneMaxScore(self.m_activityId)
    self.view.milestoneNumTxt.text = string.format("%s/%s", milestoneCurScore, milestoneMaxScore)

    local succ, rankValue = GameInstance.player.activitySystem:TryGetActivityOwnRankValue(self.m_activityId, self.m_rankRelatedId)
    self.m_rankScore = (succ and rankValue >= 0) and math.floor(rankValue) or 0
    self.view.rankingNumTxt.text = self.m_rankScore > 0 and tostring(self.m_rankScore) or "-"
    self:_RefreshActivityCommonInfoRewardState()
end


ActivityGambleBattleCtrl._RefreshActivityCommonInfoRewardState = HL.Method() << function(self)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local receiveAll = activity ~= nil and activity.receiveAllReward
        and self:_HasReceivedAllMilestoneRewards() and self:_HasReceivedHeadReward()
        and not self.view.activityCommonInfo.view.config.HIDE_RECEIVE_ALL
    local gotoNode = self.view.activityCommonInfo.view.gotoNode
    gotoNode.receiveAllNode.gameObject:SetActive(receiveAll)
    gotoNode.notReceiveAllNode.gameObject:SetActive(not receiveAll)
end

ActivityGambleBattleCtrl._HasReceivedAllMilestoneRewards = HL.Method().Return(HL.Boolean) << function(self)
    local haveCfg, milestoneCfg = Tables.activityCommonUIMilestoneTable:TryGetValue(self.m_activityId)
    if not haveCfg then
        return false
    end

    local hasMilestoneReward = false
    for _, nodeData in pairs(milestoneCfg.milestoneMap) do
        if not ActivityUtils.IsActivityCoinMilestoneReceived(self.m_activityId, nodeData.milestoneId) then
            return false
        end
        hasMilestoneReward = true
    end
    return hasMilestoneReward
end

ActivityGambleBattleCtrl._HasReceivedHeadReward = HL.Method().Return(HL.Boolean) << function(self)
    local hasCfg, cfg = Tables.activityCommonCoinRewardTable:TryGetValue(self.m_activityId)
    if not hasCfg or string.isEmpty(cfg.headItemId) then
        return true
    end

    local taskInfos = ActivityUtils.GetTaskInfos(self.m_activityId)
    for _, taskInfo in ipairs(taskInfos) do
        for _, rewardItem in ipairs(UIUtils.getRewardItems(taskInfo.rewardId)) do
            if rewardItem.id == cfg.headItemId then
                return taskInfo.status == GEnums.ActivityConditionalTaskState.Rewarded
            end
        end
    end
    return false
end

ActivityGambleBattleCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    if id ~= self.m_activityId then
        return
    end
    self:_RefreshEntryProgress()
    self:_RefreshEntryVisible()
    self:_RefreshStartContinueButtons()
end

ActivityGambleBattleCtrl._OnActivityReqRankList = HL.Method(HL.Table) << function(self, args)
    local activityId, rankRelatedId, rankInfoDic = unpack(args)
    if activityId ~= self.m_activityId then
        return
    end

    if rankRelatedId ~= self.m_rankRelatedId then
        return
    end

    self.m_rawRankInfoDic = rankInfoDic
    self.m_rankInfoReady = true
    self:_TryCalcRankIndex()
end

ActivityGambleBattleCtrl._OnFriendInfoSync = HL.Method() << function(self)
    self.m_roleSimpleInfoReady = true
    self:_TryCalcRankIndex()
end


ActivityGambleBattleCtrl._TryCalcRankIndex = HL.Method() << function(self)
    if not self.m_rankInfoReady or not self.m_roleSimpleInfoReady then
        return
    end

    local succ, activityRankInfoCfg = Tables.activityRankInfoTable:TryGetValue(self.m_rankRelatedId)
    if not succ then
        logger.warn("没有活动排行榜数据：", self.m_rankRelatedId)
        return
    end

    local rankInfoList = {}
    
    for roleId, rankInfo in pairs(self.m_rawRankInfoDic) do
        local hasFriend, _ = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
        if hasFriend then
            table.insert(rankInfoList, {
                roleId = roleId,
                rankValue = rankInfo.rankValue,
            })
        end
    end
    
    for npcId, npcRankInfo in pairs(activityRankInfoCfg.npcRankInfo) do
        table.insert(rankInfoList, {
            npcId = npcId,
            rankValue = npcRankInfo.rankValue,
        })
    end

    table.sort(rankInfoList, Utils.genSortFunction({ "rankValue" }, activityRankInfoCfg.isIncremental))

    local selfInfo = GameInstance.player.friendSystem.SelfInfo
    for luaIndex, rankInfo in ipairs(rankInfoList) do
        if rankInfo.roleId == selfInfo.roleId then
            
            self.m_rankIndex = luaIndex
            self.m_rankScore = math.floor(rankInfo.rankValue)
            break
        end
    end
end

ActivityGambleBattleCtrl._RefreshStartContinueButtons = HL.Method() << function(self)
    if self.view.activityCommonInfo.m_state == "Detail" then
        if self.m_system.gamblingDungeonRoundIndex == 0 then
            self.view.btnStartGame.gameObject:SetActive(true)
            self.view.btnContinueGame.gameObject:SetActive(false)
        else
            self.view.btnStartGame.gameObject:SetActive(false)
            self.view.btnContinueGame.gameObject:SetActive(true)
        end
    else
        self.view.btnStartGame.gameObject:SetActive(false)
        self.view.btnContinueGame.gameObject:SetActive(false)
    end
end

HL.Commit(ActivityGambleBattleCtrl)
