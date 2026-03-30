local DungeonCommonInfo = require_ex('UI/Widgets/DungeonCommonInfo')







DungeonActivityCommonInfo = HL.Class('DungeonActivityCommonInfo', DungeonCommonInfo)


DungeonActivityCommonInfo.m_missionId = HL.Field(HL.String) << ''




DungeonActivityCommonInfo._OnFirstTimeInit = HL.Override() << function(self)
    DungeonActivityCommonInfo.Super._OnFirstTimeInit(self)
    self.view.jumpBtn.onClick:RemoveAllListeners()
    self.view.jumpBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.Mission, { autoSelect = self.m_missionId })
    end)
end


DungeonActivityCommonInfo.m_activityId = HL.Field(HL.String) << ''



DungeonActivityCommonInfo.InitDungeonActivityCommonInfo = HL.Method() << function(self)
    self:_FirstTimeInit()

    
end





DungeonActivityCommonInfo.RefreshDungeonActivityCommonInfo = HL.Method(HL.String, HL.String) << function(self, dungeonId, activityId)
    DungeonActivityCommonInfo.Super.RefreshDungeonCommonInfo(self, dungeonId)

    self.m_activityId = activityId

    local _, dungeonCfg = Tables.dungeonTable:TryGetValue(self.m_dungeonId)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local activityDungeonStateCfg = Tables.activityDungeonState:GetValue(self.m_dungeonId)
    local success, stageData = activityData.stageDataDict:TryGetValue(activityDungeonStateCfg.activityStage)
    local stageCfg = Tables.activityConditionalMultiStageTable:GetValue(self.m_activityId)

    self.view.claimRewardsBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Completed:GetHashCode())
    self.view.goToBattleBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Unlocked:GetHashCode())
    self.view.rechallengeBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Rewarded:GetHashCode())

    
    if not string.isEmpty(stageCfg.stageList[activityDungeonStateCfg.activityStage].rankRelatedId) then
        self.view.activityCommonRecord:InitActivityCommonRecord(self.m_activityId, stageCfg.stageList[activityDungeonStateCfg.activityStage].rankRelatedId)
        self.view.activityCommonRecord.gameObject:SetActive(true)
    else
        self.view.activityCommonRecord.gameObject:SetActive(false)
    end

    local gained = stageData.Status == GEnums.ActivityConditionalStageState.Rewarded:GetHashCode()

    local rewardId = stageCfg.stageList[activityDungeonStateCfg.activityStage].rewardId

    local rewards = {}

    local findReward, mainRewardData = Tables.rewardTable:TryGetValue(rewardId)
    if findReward then
        for _, itemBundle in pairs(mainRewardData.itemBundles) do
            local itemId = itemBundle.id
            local succ, itemCfg = Tables.itemTable:TryGetValue(itemId)
            if succ then
                table.insert(rewards, { id = itemId,
                                        count = itemBundle.count,
                                        gained = gained,
                                        sortId1 = itemCfg.sortId1,
                                        sortId2 = itemCfg.sortId2, })
            else
                logger.error("配置的RewardId中的ItemId在Item表中找不到", itemId, rewardId)
            end
        end
    elseif not string.isEmpty(rewardId) then
        logger.error("配置的首通奖励RewardId在Reward表中找不到：", rewardId)
    end

    self.view.rewardNode.gameObject:SetActive(#rewards > 0)
    self:SetRewardDetailsData(rewards)
    self.m_rewardCellCache:Refresh(#rewards, function(cell, luaIndex)
        local reward = rewards[luaIndex]
        cell.itemSmall:InitItem(reward, true)
        cell.itemSmall:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
        cell.getNode.gameObject:SetActive(reward.gained == true)
        cell.lockNode.gameObject:SetActive(reward.locked == true)
        cell.lineNode.gameObject:SetActiveIfNecessary(false)
    end)
    self.m_missionId = ''
    self.view.lockedSpNode.gameObject:SetActive(false)
    self.view.jumpBtn.gameObject:SetActive(false)
    self.view.lockedNode.gameObject:SetActive(false)
    
    if stageData.Status == GEnums.ActivityConditionalStageState.Locked:GetHashCode() then
        local stageId = activityDungeonStateCfg.activityStage
        local conditionCfg = Tables.activityConditionalMultiStageConditionTable:GetValue(stageId)
        local flags = stageData.Conditions.Flags
        local desc, conditionType, questId = nil, 0, nil
        local missionQuestFallbackDesc, missionQuestFallbackType, missionQuestFallbackQuestId = nil, 0, nil

        if conditionCfg and conditionCfg.conditionList then
            for i = 0, conditionCfg.conditionList.Count - 1 do
                local condition = conditionCfg.conditionList[i]
                local conditionSuccess ,isComplete = flags:TryGetValue(condition.conditionId)
                if conditionSuccess and isComplete then
                    
                else
                    local ct = condition.conditionType
                    local isMissionOrQuest = (ct == GEnums.ConditionType.MissionStateEqual or ct == GEnums.ConditionType.QuestStateEqual)
                    if isMissionOrQuest then
                        if missionQuestFallbackDesc == nil then
                            missionQuestFallbackDesc = condition.desc
                            missionQuestFallbackType = ct
                            if condition.parameters and condition.parameters.Count > 0 then
                                local p0 = condition.parameters[0]
                                missionQuestFallbackQuestId = (p0.valueStringList and p0.valueStringList.Count > 0) and p0.valueStringList[0] or ''
                            else
                                missionQuestFallbackQuestId = ''
                            end
                        end
                    else
                        desc = condition.desc
                        conditionType = ct
                        questId = ''
                        break
                    end
                end
            end
            if desc == nil and missionQuestFallbackDesc ~= nil then
                desc = missionQuestFallbackDesc
                conditionType = missionQuestFallbackType
                questId = missionQuestFallbackQuestId or ''
            end
        end

        if not string.isEmpty(desc) then
            if conditionType == GEnums.ConditionType.MissionStateEqual or conditionType == GEnums.ConditionType.QuestStateEqual then
                self.m_missionId = GameInstance.player.mission:GetMissionIdByQuestId(questId or '')
                self.view.jumpTxt.text = desc
            else
                self.view.lockedTxt.text = desc
                self.m_missionId = ''
            end
        end
        self.view.jumpBtn.gameObject:SetActive(string.isEmpty(self.m_missionId) == false)
        self.view.lockedNode.gameObject:SetActive(string.isEmpty(self.m_missionId))
    end
end

HL.Commit(DungeonActivityCommonInfo)
return DungeonActivityCommonInfo

