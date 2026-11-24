local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

DungeonBossInfo = HL.Class('DungeonBossInfo', UIWidgetBase)

DungeonBossInfo.m_dungeonId = HL.Field(HL.String) << ""
DungeonBossInfo.m_customArgs = HL.Field(HL.Table)
DungeonBossInfo.m_detailRewardData = HL.Field(HL.Table)
DungeonBossInfo.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))
DungeonBossInfo.m_paramBlackboard = HL.Field(CS.Beyond.Blackboard)
DungeonBossInfo.m_paramBlackboardFormatData = HL.Field(CS.Beyond.Gameplay.BlackboardFormatData)

local highDifficultySystem = GameInstance.player.highDifficultySystem

local function _isDungeonDisplayUnlocked(dungeonId)
    if string.isEmpty(dungeonId) then
        return false
    end

    local bossGroupId = highDifficultySystem:GetBossGroupIdByGameId(dungeonId)
    if string.isEmpty(bossGroupId) then
        return DungeonUtils.isDungeonUnlock(dungeonId)
    end
    return highDifficultySystem:IsBossGameUnlocked(dungeonId)
end


DungeonBossInfo._OnFirstTimeInit = HL.Override() << function(self)
    self.m_paramBlackboard = CS.Beyond.Blackboard()
    self.m_paramBlackboardFormatData = CS.Beyond.Gameplay.BlackboardFormatData(self.m_paramBlackboard)

    self.m_rewardCellCache = UIUtils.genCellCache(self.view.rewardCell)

    self.view.btnEnemyDetails.onClick:AddListener(function()
        self:_OnBtnEnemyDetailsClick()
    end)

     self.view.btnRewardDetails.onClick:AddListener(function()
        self:_OnBtnRewardDetailsClick()
     end)
    self.view.startButton.onClick:AddListener(function()
        self:_OnBtnDungeonEntryClick()
    end)

    self:RegisterMessage(MessageConst.ON_SUB_GAME_CUSTOM_REWARD_CHANGE, function()
        self:_RefreshDungeonRewards()
    end)
end

DungeonBossInfo.InitDungeonBossInfo = HL.Method(HL.Opt(HL.Table)) << function(self, customArgs)
    self:_FirstTimeInit()

    self.m_customArgs = customArgs or {}
    self.m_detailRewardData = nil
end

DungeonBossInfo.RefreshDungeonBossInfo = HL.Method(HL.String) << function(self, dungeonId)
    self.m_dungeonId = dungeonId
    if string.isEmpty(dungeonId) then
        return
    end

    local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(dungeonId)
    if not succ then
        logger.error("DungeonBossInfo找不到副本配置，dungeonId=", dungeonId)
        return
    end

    local isUnlock = _isDungeonDisplayUnlocked(dungeonId)
    self:_RefreshStateController(dungeonId, isUnlock)
    self:_RefreshLockText(dungeonId, isUnlock)

    self.view.startButton.interactable = isUnlock
    self.view.startButton.text = DungeonUtils.getEntryText(dungeonId)

    self:_RefreshRecommendLv(dungeonCfg)
    self:_RefreshFeature(dungeonCfg)
    self:_RefreshEnemyInfo(dungeonCfg)
    self:_RefreshRewardChest(dungeonCfg)
    self:_RefreshDungeonRewards()

    local hasCustomReward = not string.isEmpty(dungeonCfg.customRewardId)
    self.view.rewardNode:SetState(hasCustomReward and "CustomReward" or "NormalReward ")
end

DungeonBossInfo._RefreshStateController = HL.Method(HL.String, HL.Boolean) << function(self, dungeonId, isUnlock)
    self.view.rightNodeStateController:SetState(isUnlock and "UnLock" or "Lock")
    self.view.rightNodeStateController:SetState("Common")

    if highDifficultySystem:IsBossGameSpecial(dungeonId) then
        self.view.rightNodeStateController:SetState("Special")
    end

    if highDifficultySystem:IsBossGamePassed(dungeonId) then
        self.view.rightNodeStateController:SetState("Complete")
    end
end

DungeonBossInfo._RefreshLockText = HL.Method(HL.String, HL.Boolean) << function(self, dungeonId, isUnlock)
    if isUnlock then
        return
    end
    local conditionId = Tables.gameMechanicTable[dungeonId].conditionIds[CSIndex(1)]
    local desc = Tables.gameMechanicConditionTable[conditionId].desc
    self.view.lockText.text = string.isEmpty(desc) and Language.LUA_HIGHDIFFICULTY_BOSS_UNLOCK_TIP or desc
end

DungeonBossInfo.SetRewardDetailsData = HL.Method(HL.Table) << function(self, data)
    self.m_detailRewardData = data
end

DungeonBossInfo._RefreshRecommendLv = HL.Method(HL.Any) << function(self, dungeonCfg)
    local hasRecommendLv = dungeonCfg.recommendLv > 0
    if hasRecommendLv then
        self.view.recommendLvTxt.text = string.format("LV.%d", dungeonCfg.recommendLv)
    end
    self.view.recommendLv.gameObject:SetActive(hasRecommendLv)
end

DungeonBossInfo._RefreshFeature = HL.Method(HL.Any) << function(self, dungeonCfg)
    self.m_paramBlackboard:Clear()
    if dungeonCfg.paramList then
        for i = 1, dungeonCfg.paramList.Count do
            local param = dungeonCfg.paramList[CSIndex(i)]
            self.m_paramBlackboard:Assign(param.key, param.value)
        end
    end

    local hasFeature = DungeonUtils.isDungeonHasFeatureInfo(self.m_dungeonId)
    if hasFeature and self.view.featureTxt then
        self.view.featureTxt:SetAndResolveTextStyle(
            CS.Beyond.Gameplay.FormatUtils.FormatBattleText(dungeonCfg.featureDesc, self.m_paramBlackboardFormatData))
    end
    self.view.feature.gameObject:SetActive(hasFeature)
end

DungeonBossInfo._RefreshEnemyInfo = HL.Method(HL.Any) << function(self, dungeonCfg)
    local hasEnemy = dungeonCfg.enemyIds ~= nil and dungeonCfg.enemyIds.Count > 0
    self.view.enemyNode.gameObject:SetActive( hasEnemy)
end

DungeonBossInfo._RefreshRewardChest = HL.Method(HL.Any) << function(self, dungeonCfg)
    local gainedRewardChestNum, maxRewardChestNum = DungeonUtils.getDungeonChestCount(dungeonCfg.sceneId)
    local hasChest = not string.isEmpty(dungeonCfg.sceneId) and maxRewardChestNum > 0
    if hasChest and self.view.rewardChestNode then
        self.view.rewardChestNode.chestTxt.text = string.format("%d/%d", gainedRewardChestNum, maxRewardChestNum)
    end
    self.view.rewardChestNode.gameObject:SetActive( hasChest)
end

DungeonBossInfo._GenRewardInfo = HL.Method(HL.String, HL.Number, HL.Number, HL.Boolean, HL.Boolean, HL.String,
                                           HL.Opt(HL.Number)).Return(HL.Table)
        << function(self, typeTag, groupId, rewardTypeSortId, locked, gained, itemId, itemCount)
    local itemCfg = Tables.itemTable[itemId]
    return {
        id = itemId,
        count = itemCount,
        locked = locked,
        gained = gained,
        typeTag = typeTag,
        lockedSortId = locked and 0 or 1,
        gainedSortId = gained and 0 or 1,
        groupId = groupId,
        rewardTypeSortId = rewardTypeSortId,
        sortId1 = itemCfg.sortId1,
        sortId2 = itemCfg.sortId2,
    }
end

DungeonBossInfo._RefreshDungeonRewards = HL.Method() << function(self)
    if string.isEmpty(self.m_dungeonId) or not self.m_rewardCellCache then
        return
    end

    local dungeonMgr = GameInstance.dungeonManager
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local rewards = {}

    local hasFirstReward = not string.isEmpty(dungeonCfg.firstPassRewardId)
    if hasFirstReward then
        local firstRewardGained = dungeonMgr:IsDungeonFirstPassRewardGained(self.m_dungeonId)
        local rewardsCfg = Tables.rewardTable[dungeonCfg.firstPassRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = self:_GenRewardInfo(DungeonConst.DUNGEON_REWARD_TAG_STATE.First, -1, -1, false,
                                               firstRewardGained, itemBundle.id, itemBundle.count)
            table.insert(rewards, reward)
        end
    end

    local hasExtraReward = not string.isEmpty(dungeonCfg.extraRewardId)
    if hasExtraReward then
        local extraRewardGained = dungeonMgr:IsDungeonExtraRewardGained(self.m_dungeonId)
        local rewardsCfg = Tables.rewardTable[dungeonCfg.extraRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = self:_GenRewardInfo(DungeonConst.DUNGEON_REWARD_TAG_STATE.Extra, -2, -2, false,
                                               extraRewardGained, itemBundle.id, itemBundle.count)
            table.insert(rewards, reward)
        end
    end

    local realRewardId
    local hasRecord, subGameRecord = GameInstance.player.subGameSys:TryGetSubGameRecord(self.m_dungeonId)
    if not string.isEmpty(dungeonCfg.customRewardId) then
        realRewardId = (hasRecord and subGameRecord.customRewardIndex == 1) and dungeonCfg.customRewardId or dungeonCfg.rewardId
    else
        realRewardId = dungeonCfg.rewardId
    end
    if not string.isEmpty(realRewardId) then
        local rewardsCfg = Tables.rewardTable[realRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = self:_GenRewardInfo(DungeonConst.DUNGEON_REWARD_TAG_STATE.Regular, -5, -5, false,
                                               false, itemBundle.id, itemBundle.count)
            table.insert(rewards, reward)
        end
    end

    local sortKeys = {}
    for _, key in ipairs(UIConst.COMMON_ITEM_SORT_KEYS) do
        table.insert(sortKeys, key)
    end
    table.insert(sortKeys, 1, "rewardTypeSortId")
    table.insert(sortKeys, 1, "gainedSortId")
    table.sort(rewards, Utils.genSortFunction(sortKeys))

    local groupFlag
    self.m_rewardCellCache:Refresh(#rewards, function(cell, luaIndex)
        local reward = rewards[luaIndex]
        cell.itemSmall:InitItem(reward, true)
        cell.getNode.gameObject:SetActive(reward.gained == true)
        cell.lockNode.gameObject:SetActive(reward.locked == true)
        cell.lineNode.gameObject:SetActive(reward.groupId ~= groupFlag)
        groupFlag = reward.groupId
    end)
    self.view.rewardNode.gameObject:SetActive(#rewards > 0)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.container)
    self.view.rewardList.normalizedPosition = Vector2(0, 0)
end

DungeonBossInfo._OnBtnDungeonEntryClick = HL.Method() << function(self)
    if string.isEmpty(self.m_dungeonId) or not _isDungeonDisplayUnlocked(self.m_dungeonId) then
        return
    end

    local isCostStamina, costStamina = DungeonUtils.isDungeonCostStamina(self.m_dungeonId)
    local realCostStamina = ActivityUtils.getRealStaminaCost(costStamina)
    if isCostStamina and realCostStamina > GameInstance.player.inventory.curStamina then
        DungeonUtils.TryShowDungeonInsufficientStaminaPopup(self.m_dungeonId, function()
            self:_TryOpenCharFormation()
        end)
    else
        self:_TryOpenCharFormation()
    end
end


local function _getIgnoreHighestDifficultyWarningKey(dungeonId)
    return GameInstance.player.roleId .. dungeonId .. "DungeonBossIgnoreHighestDifficultyWarning"
end


DungeonBossInfo._TryOpenCharFormation = HL.Method() << function(self)
    if not self:_NeedHighestDifficultyWarning() then
        self:_OpenCharFormation()
        return
    end

    local ignoreWarning = false
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_HIGHDIFFICULTY_BOSS_HIGHEST_DIFFICULTY_WARNING,
        confirmText = Language.LUA_HIGHDIFFICULTY_BOSS_CONTINUE_CHALLENGE,
        toggle = {
            isOn = false,
            toggleText = Language.LUA_HIGHDIFFICULTY_BOSS_NEVER_REMIND,
            onHintTextId = "LUA_HIGHDIFFICULTY_BOSS_NEVER_REMIND",
            offHintTextId = "LUA_HIGHDIFFICULTY_BOSS_NEVER_REMIND",
            onValueChanged = function(isOn)
                ignoreWarning = isOn
            end,
        },
        onConfirm = function()
            if ignoreWarning then
                ClientDataManagerInst:SetBool(_getIgnoreHighestDifficultyWarningKey(self.m_dungeonId), true, true)
            end
            self:_OpenCharFormation()
        end,
    })
end

DungeonBossInfo._NeedHighestDifficultyWarning = HL.Method().Return(HL.Boolean) << function(self)
    local _, ignoreWarning = ClientDataManagerInst:GetBool(_getIgnoreHighestDifficultyWarningKey(self.m_dungeonId), true)
    
    if ignoreWarning then
        return false
    end
    local bossGroupId = highDifficultySystem:GetBossGroupIdByGameId(self.m_dungeonId)
    if string.isEmpty(bossGroupId) then
        return false
    end
    local bossGameIds = highDifficultySystem:GetBossGameIds(bossGroupId)
    local count = bossGameIds.Count
    
    return count > 1
        and self.m_dungeonId == bossGameIds[CSIndex(count)]
        and not highDifficultySystem:IsBossGamePassed(bossGameIds[CSIndex(count - 1)])
end

DungeonBossInfo._OpenCharFormation = HL.Method() << function(self)
    PhaseManager:GoToPhase(PhaseId.CharFormation, {
        dungeonId = self.m_dungeonId,
        enterDungeonCallback = self.m_customArgs and self.m_customArgs.enterDungeonCallback or nil,
        enterConfirmCallback = self.m_customArgs and self.m_customArgs.enterConfirmCallback or nil,
    })
end

DungeonBossInfo._OnBtnRewardDetailsClick = HL.Method() << function(self)
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local hasOptionReward = not string.isEmpty(dungeonCfg.customRewardId)
    local openPanelId = hasOptionReward and PanelId.DungeonRewardSelectPopup or PanelId.CommonRewardDetailsPopup
    local firstPartRewards = self.m_detailRewardData
    if firstPartRewards == nil or next(firstPartRewards) == nil then
        firstPartRewards = DungeonUtils.genFirstPartRewardsInfo(self.m_dungeonId)
    end
    local args = hasOptionReward and { dungeonId = self.m_dungeonId } or {
        gameMechanicsId = self.m_dungeonId,
        firstPartRewards = firstPartRewards,
        firstPartRewardsTitle = DungeonUtils.getRewardsDetailFirstRowTitle(self.m_dungeonId),
        secondPartRewards = DungeonUtils.genSecondPartRewardsInfo(self.m_dungeonId),
        secondPartRewardsTitle = DungeonUtils.getRewardsDetailSecondRowTitle(self.m_dungeonId),
    }
    UIManager:AutoOpen(openPanelId, args)
end

DungeonBossInfo._OnBtnEnemyDetailsClick = HL.Method(HL.Opt(HL.Number)) << function(self, initSelectEnemyLuaIndex)
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local dungeonTypeCfg = Tables.dungeonTypeTable[dungeonCfg.dungeonCategory]
    local enemyPopupArg = {
        title = dungeonTypeCfg.enemyInfoTitle,
        enemyListTitle = Language["ui_dungeon_enemy_popup_info_list"],
        enemyInfoTitle = Language["ui_dungeon_enemy_popup_info_desc"],
        enemyIds = dungeonCfg.enemyIds,
        enemyLevels = dungeonCfg.enemyLevels,
        hideDamageTakenInfo = (dungeonCfg.dungeonCategory == DungeonConst.DUNGEON_CATEGORY.HighDifficulty)
    }
    if initSelectEnemyLuaIndex ~= nil then
        enemyPopupArg.initSelectEnemyLuaIndex = initSelectEnemyLuaIndex
    end
    UIManager:AutoOpen(PanelId.CommonEnemyPopup, enemyPopupArg)
end

DungeonBossInfo.GetRecoverPopupStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isRewardSelectOpen = UIManager:IsOpen(PanelId.DungeonRewardSelectPopup)
    if isRewardSelectOpen then
        return {
            popupType = "RewardDetails",
        }
    end

    local isRewardDetailsOpen = UIManager:IsOpen(PanelId.CommonRewardDetailsPopup)
    if isRewardDetailsOpen then
        return {
            popupType = "RewardDetails",
        }
    end

    local isEnemyPopupOpen, enemyPopupCtrl = UIManager:IsOpen(PanelId.CommonEnemyPopup)
    if isEnemyPopupOpen then
        local popupState = {
            popupType = "EnemyDetails",
        }
        if HL.TryGet(enemyPopupCtrl, "GetCurSelectEnemyLuaIndex") then
            local selectedEnemyLuaIndex = enemyPopupCtrl:GetCurSelectEnemyLuaIndex()
            if selectedEnemyLuaIndex > 0 then
                popupState.selectedEnemyLuaIndex = selectedEnemyLuaIndex
            end
        end
        return popupState
    end
end

DungeonBossInfo.TryRecoverPopupState = HL.Method(HL.Any) << function(self, popupState)
    if popupState == nil or string.isEmpty(popupState.popupType) then
        return
    end

    if popupState.popupType == "RewardDetails" then
        local isRewardSelectOpen = UIManager:IsOpen(PanelId.DungeonRewardSelectPopup)
        if isRewardSelectOpen then
            return
        end
        local isRewardDetailsOpen = UIManager:IsOpen(PanelId.CommonRewardDetailsPopup)
        if isRewardDetailsOpen then
            return
        end
        self:_OnBtnRewardDetailsClick()
        return
    end

    if popupState.popupType == "EnemyDetails" then
        local isOpen = UIManager:IsOpen(PanelId.CommonEnemyPopup)
        if isOpen then
            return
        end
        self:_OnBtnEnemyDetailsClick(popupState.selectedEnemyLuaIndex)
    end
end

HL.Commit(DungeonBossInfo)
return DungeonBossInfo
