
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonEntry
local PHASE_ID = PhaseId.DungeonEntry

local GameMechanicsType = {
    Race = "dungeon_rpg",
    Char = "dungeon_char",
    Train = "dungeon_train",
}































DungeonEntryCtrl = HL.Class('DungeonEntryCtrl', uiCtrl.UICtrl)



DungeonEntryCtrl.s_onLeaveDungeonCachedSeriesId = HL.StaticField(HL.String) << ""






DungeonEntryCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STAMINA_CHANGED] = 'OnStaminaChanged',
    [MessageConst.ON_SUB_GAME_UNLOCK] = "OnSubGameUnlock",
}



DungeonEntryCtrl.OnOpenDungeonEntryPanel = HL.StaticMethod(HL.Any) << function(arg)
    local dungeonSeriesId, couldWait = unpack(arg)
    PhaseManager:OpenPhase(PHASE_ID, {dungeonSeriesId = dungeonSeriesId}, nil , couldWait)
end



DungeonEntryCtrl.OnLeaveDungeon = HL.StaticMethod(HL.Any) << function(arg)
    local dungeonId = unpack(arg)
    local dungeonCfg = Tables.dungeonTable[dungeonId]
    local gameMechCfg = Tables.gameMechanicTable[dungeonId]
    if gameMechCfg.gameCategory == GameMechanicsType.Train then
        DungeonEntryCtrl.s_onLeaveDungeonCachedSeriesId = dungeonCfg.dungeonSeriesId
    end
end


DungeonEntryCtrl.OnPhaseLevelOnTop = HL.StaticMethod() << function()
    if string.isEmpty(DungeonEntryCtrl.s_onLeaveDungeonCachedSeriesId) then
        return
    end
    
    GameInstance.player.guide:OnOpenCachedDungeonTrainPanel()
    DungeonEntryCtrl.OnOpenDungeonEntryPanel({ DungeonEntryCtrl.s_onLeaveDungeonCachedSeriesId, true })
    DungeonEntryCtrl.s_onLeaveDungeonCachedSeriesId = ""
end


DungeonEntryCtrl.m_dungeonSeriesId = HL.Field(HL.String) << ""


DungeonEntryCtrl.m_dungeonId = HL.Field(HL.String) << ""


DungeonEntryCtrl.m_dungeonTabCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonEntryCtrl.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonEntryCtrl.m_dungeonGoalCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonEntryCtrl.m_charTeamCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonEntryCtrl.m_selectedTabIndex = HL.Field(HL.Number) << -1


DungeonEntryCtrl.m_selectedTabCell = HL.Field(HL.Any)





DungeonEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.m_dungeonSeriesId = arg.dungeonSeriesId

    self.m_rewardCellCache = UIUtils.genCellCache(self.view.rewardCell)
    self.m_dungeonTabCellCache = UIUtils.genCellCache(self.view.dungeonSelectionCell)
    self.m_dungeonGoalCellCache = UIUtils.genCellCache(self.view.dungeonGoalCell)
    self.m_charTeamCellCache = UIUtils.genCellCache(self.view.charHeadCell)

    self.view.btnEnemyDetails.onClick:AddListener(function()
        self:_OnBtnEnemyDetailsClick()
    end)

    self.view.btnRewardDetails.onClick:AddListener(function()
        UIManager:AutoOpen(PanelId.DungeonRewardDetailsPopup, { dungeonId = self.m_dungeonId })
    end)

    self.view.btnDungeonEntry.onClick:AddListener(function()
        self:_OnBtnDungeonEntryClick()
    end)

    self.view.btnUnlockCondition.onClick:AddListener(function()
        self:_OnBtnUnlockConditionClick()
    end)

    self:_RefreshContent()
end




DungeonEntryCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    self.m_dungeonSeriesId = args.dungeonSeriesId
    self:_RefreshContent()
end



DungeonEntryCtrl._OnBtnCloseClick = HL.Method() << function(self)
    
    local isOpen, phase = PhaseManager:IsOpen(PhaseId.Dialog)
    if isOpen then
        self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
    else
        PhaseManager:PopPhase(PHASE_ID)
    end
end



DungeonEntryCtrl._OnBtnEnemyDetailsClick = HL.Method() << function(self)
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local dungeonTypeCfg = Tables.dungeonTypeTable[gameMechanicCfg.gameCategory]
    UIManager:AutoOpen(PanelId.CommonEnemyPopup, { title = dungeonTypeCfg.enemyInfoTitle,
                                                   enemyIds = dungeonCfg.enemyIds,
                                                   enemyLevels = dungeonCfg.enemyLevels })
end



DungeonEntryCtrl._OnBtnDungeonEntryClick = HL.Method() << function(self)
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    if GameInstance.player.inventory.curStamina < gameMechanicCfg.costStamina then
        UIManager:Open(PanelId.StaminaPopUp)
        return
    end

    if gameMechanicCfg.gameCategory == GameMechanicsType.Char then
        self:Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_DUNGEON_ENTRY_CONFIRM,
            onConfirm = function()
                PhaseManager:GoToPhase(PhaseId.CharFormation, { dungeonId = self.m_dungeonId })
            end,
            onCancel = function()
            end
        })
    else
        PhaseManager:GoToPhase(PhaseId.CharFormation, { dungeonId = self.m_dungeonId })
    end
end



DungeonEntryCtrl._OnBtnUnlockConditionClick = HL.Method() << function(self)
    local uncompletedConditionIds = DungeonUtils.getUncompletedConditionIds(self.m_dungeonId)
    if #uncompletedConditionIds > 1 then
        UIManager:AutoOpen(PanelId.DungeonUnlockConditionPopup, { dungeonId = self.m_dungeonId })
    else
        DungeonUtils.diffActionByConditionId(uncompletedConditionIds[1])
    end
end



DungeonEntryCtrl._RefreshContent = HL.Method() << function(self)
    
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    self.view.titleTxt.text = dungeonSeriesCfg.name

    
    local needStamina = not string.isEmpty(dungeonSeriesCfg.staminaText)
    if needStamina then
        self.view.walletBarPlaceholder:InitWalletBarPlaceholder(UIConst.REGION_MAP_STAMINA_IDS)
    end

    local dungeonTypeCfg = Tables.dungeonTypeTable[dungeonSeriesCfg.gameCategory]
    self.view.btnEntryTxt.text = dungeonTypeCfg.entryText

    self.view.dungeonBG:LoadSprite(UIConst.UI_SPRITE_DUNGEON ,dungeonSeriesCfg.dungeonPicPath)

    
    self:_InitDungeonTabs()
    
    self:_RefreshLeftDownNode()
    
    self:_RefreshDungeonDetailList()
end



DungeonEntryCtrl._InitDungeonTabs = HL.Method() << function(self)
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    local dungeonMgr = GameInstance.dungeonManager
    local dungeonTabInfos = {}

    for csIndex, dungeonId in pairs(dungeonSeriesCfg.includeDungeonIds) do
        table.insert(dungeonTabInfos, dungeonId)
        if self.m_selectedTabIndex < 0 then
            
            local isPass = dungeonMgr:IsDungeonPassed(dungeonId)
            local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
            if isUnlock and not isPass then
                self.m_selectedTabIndex = LuaIndex(csIndex)
            end
        end
    end

    
    if self.m_selectedTabIndex < 0 then
        self.m_selectedTabIndex = #dungeonTabInfos
    end

    
    self.m_dungeonId = dungeonTabInfos[self.m_selectedTabIndex]
    self.m_dungeonTabCellCache:Refresh(#dungeonTabInfos, function(cell, luaIndex)
        local dungeonId = dungeonTabInfos[luaIndex]
        cell:InitDungeonSelectionCell(dungeonId, function()
            self:_OnDungeonTabClick(cell, luaIndex, dungeonId)
        end)
        cell:SetSelected(self.m_selectedTabIndex == luaIndex)

        if self.m_selectedTabIndex == luaIndex then
            self.m_selectedTabCell = cell
        end
    end)

    if #dungeonTabInfos > 2 then
        local targetScrollToCell = self.m_dungeonTabCellCache:Get(self.m_selectedTabIndex)
        self.view.dungeonSelectionNode:AutoScrollToRectTransform(targetScrollToCell.gameObject.transform, true)
    end

    self.view.dungeonSelectionNode.gameObject:SetActiveIfNecessary(dungeonSeriesCfg.gameCategory ~= GameMechanicsType.Char)
end






DungeonEntryCtrl._OnDungeonTabClick = HL.Method(HL.Any, HL.Number, HL.String)
        << function(self, cell, luaIndex, dungeonId)
    if self.m_selectedTabIndex == luaIndex then
        return
    end

    local preCell = self.m_selectedTabCell
    self.m_selectedTabCell = cell
    self.m_selectedTabIndex = luaIndex
    self.m_dungeonId = dungeonId

    preCell:SetSelected(false)
    cell:SetSelected(true)

    self:_RefreshLeftDownNode()
    self:_RefreshDungeonDetailList()

    self.view.rightNode:ClearTween()
    self.view.rightNode:PlayInAnimation()
end



DungeonEntryCtrl._RefreshLeftDownNode = HL.Method() << function(self)
    
    local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_dungeonId)
    local hasMission = success and not string.isEmpty(subGameData.dungeonMissionId)
    if hasMission then
        local missionId = subGameData.dungeonMissionId
        local missionInfo = GameInstance.player.mission:GetMissionInfo(missionId)
        local succ, charCfg = Tables.CharacterTable:TryGetValue(missionInfo.charId)
        self.view.mainTxt.text = succ and charCfg.name or "TBD"
        self.view.subTxt.text = missionInfo.missionName:GetText()
    end
    self.view.missionInfoNode.gameObject:SetActiveIfNecessary(hasMission)

    
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local hasCharTeam = not string.isEmpty(dungeonCfg.previewCharTeamId)
    if hasCharTeam then
        local lockedTeamData = CharInfoUtils.getLockedFormationData(dungeonCfg.previewCharTeamId, false)
        local chars = lockedTeamData.chars

        self.m_charTeamCellCache:Refresh(#chars, function(cell, luaIndex)
            local char = chars[luaIndex]
            local isFixed, isTrail = CharInfoUtils.getLockedFormationCharTipsShow(char)

            cell.charImage:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, UIConst.UI_ROUND_CHAR_HEAD_PREFIX..char.charId)
            cell.fixedTips.gameObject:SetActive(isFixed)
            cell.tryoutTips.gameObject:SetActive(isTrail)
        end)
    end
    self.view.charTeamNode.gameObject:SetActiveIfNecessary(hasCharTeam)

    self.view.leftDownNode.gameObject:SetActiveIfNecessary(hasMission or hasCharTeam)
end



DungeonEntryCtrl._RefreshDungeonDetailList = HL.Method() << function(self)
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local dungeonMgr = GameInstance.dungeonManager
    local _, subGameRecord = GameInstance.player.subGameSys:TryGetSubGameRecord(self.m_dungeonId)
    local isPass = dungeonMgr:IsDungeonPassed(self.m_dungeonId)
    local isUnlock = DungeonUtils.isDungeonUnlock(self.m_dungeonId)
    local succ, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_dungeonId)
    local showTimeInfo = succ and (subGameData.hasTimer or subGameData.hasTimeLimit)

    local positionText = DungeonUtils.getEntryLocation(dungeonCfg.levelId, true)
    self.view.positionTxt.text = positionText
    self.view.positionNode.gameObject:SetActiveIfNecessary(not string.isEmpty(positionText))

    self.view.dungeonTitleTxt.text = dungeonCfg.dungeonName
    self.view.normalFinishedNode.gameObject:SetActiveIfNecessary(isPass)
    self.view.bestTimeNode.gameObject:SetActiveIfNecessary(showTimeInfo)
    self.view.timeTxt.text = isPass
            and UIUtils.getLeftTimeToSecond(subGameRecord.bestPassTime/1000) or "--:--:--"
    self.view.recommendLvTxt.text = string.format("Lv.%s",
                                                  dungeonCfg.recommendLv > 0 and tostring(dungeonCfg.recommendLv) or "-")

    self.view.dungeonDescTxt:SetAndResolveTextStyle(dungeonCfg.dungeonDesc)
    local hasFeature = DungeonUtils.isDungeonHasFeatureInfo(self.m_dungeonId)
    if hasFeature then
        self.view.ruleDescTxt:SetAndResolveTextStyle(dungeonCfg.featureDesc)
    end
    self.view.rule.gameObject:SetActiveIfNecessary(hasFeature)

    
    
    local isTrain = DungeonUtils.isDungeonTrain(self.m_dungeonId)
    local goalTxt = isTrain and dungeonCfg.mainGoalDesc or dungeonCfg.extraGoalDesc
    local goalTxtTbl = DungeonUtils.getListByStr(goalTxt)
    local complete = isTrain and dungeonMgr:IsDungeonFirstPassRewardGained(self.m_dungeonId) or
            dungeonMgr:IsDungeonExtraRewardGained(self.m_dungeonId)
    self.m_dungeonGoalCellCache:Refresh(#goalTxtTbl, function(cell, luaIndex)
        cell.goalTxt:SetAndResolveTextStyle(goalTxtTbl[luaIndex])
        cell.normalIcon.gameObject:SetActiveIfNecessary(not complete)
        cell.finishedIcon.gameObject:SetActiveIfNecessary(complete)
    end)
    self.view.dungeonGoalInfoNode.gameObject:SetActiveIfNecessary(#goalTxtTbl > 0)
    self.view.awardsTxt.gameObject:SetActiveIfNecessary(not isTrain)
    self.view.trainTxt.gameObject:SetActiveIfNecessary(isTrain)

    
    local hasEnemy = dungeonCfg.enemyIds.Count > 0
    self.view.enemyNode.gameObject:SetActiveIfNecessary(hasEnemy)

    
    local rewards = self:_ProcessDungeonRewards()
    self.m_rewardCellCache:Refresh(#rewards, function(cell, luaIndex)
        local reward = rewards[luaIndex]
        cell.item:InitItem({id = reward.id, count = reward.count}, true)
        cell.getNode.gameObject:SetActiveIfNecessary(reward.gained == true)
        cell.extraTag.gameObject:SetActiveIfNecessary(reward.isExtra == true)
    end)
    self.view.rewardNode.gameObject:SetActiveIfNecessary(#rewards > 0)

    
    self.view.unlockedNode.gameObject:SetActiveIfNecessary(isUnlock)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(not isUnlock)

    
    self:_RefreshUnlockCondition()

    
    self:_RefreshBottomStamina()
end



DungeonEntryCtrl._ProcessDungeonRewards = HL.Method().Return(HL.Table) << function(self)
    local dungeonMgr = GameInstance.dungeonManager
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local rewards = {}

    local getRewardCommonInfo = function(itemBundle)
        local itemCfg = Tables.itemTable[itemBundle.id]
        return {
            id = itemBundle.id,
            count = itemBundle.count,
            sortId1 = itemCfg.sortId1,
            sortId2 = itemCfg.sortId2,
        }
    end

    
    local hasFirstReward = not string.isEmpty(gameMechanicCfg.firstPassRewardId)
    if hasFirstReward then
        local firstRewardGained = dungeonMgr:IsDungeonFirstPassRewardGained(self.m_dungeonId)
        local rewardsCfg = Tables.rewardTable[gameMechanicCfg.firstPassRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = getRewardCommonInfo(itemBundle)
            reward.first = true and not string.isEmpty(gameMechanicCfg.rewardId)
            reward.gainedSortId = firstRewardGained and 0 or 1
            reward.rewardTypeSortId = 3
            reward.gained = firstRewardGained
            table.insert(rewards, reward)
        end
    end

    
    local hasRecycleReward = not string.isEmpty(gameMechanicCfg.rewardId)
    if hasRecycleReward then
        local rewardsCfg = Tables.rewardTable[gameMechanicCfg.rewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = getRewardCommonInfo(itemBundle)
            reward.first = false
            reward.gainedSortId = 1
            reward.rewardTypeSortId = 1
            reward.gained = false
            table.insert(rewards, reward)
        end
    end

    
    local hasExtraReward = not string.isEmpty(gameMechanicCfg.extraRewardId)
    if hasExtraReward then
        local extraRewardGained = dungeonMgr:IsDungeonExtraRewardGained(self.m_dungeonId)
        local rewardsCfg = Tables.rewardTable[gameMechanicCfg.extraRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local reward = getRewardCommonInfo(itemBundle)
            reward.first = false
            reward.gainedSortId = extraRewardGained and 0 or 1
            reward.rewardTypeSortId = 2
            reward.gained = extraRewardGained
            reward.isExtra = true
            table.insert(rewards, reward)
        end
    end

    table.sort(rewards, Utils.genSortFunction({ "gainedSortId", "rewardTypeSortId", "sortId1", "sortId2" }))
    return rewards
end



DungeonEntryCtrl._RefreshUnlockCondition = HL.Method() << function(self)
    local isUnlock = DungeonUtils.isDungeonUnlock(self.m_dungeonId)
    if isUnlock then
        return
    end

    
    local uncompletedConditionId = DungeonUtils.getUncompletedConditionIds(self.m_dungeonId)
    local multiUnComplete = #uncompletedConditionId > 1
    if multiUnComplete then
        self.view.lockedTxt.text = Language.LUA_DUNGEON_MULTI_UNCOMPLETED_CONDITION
        self.view.infoNode.gameObject:SetActiveIfNecessary(true)
        self.view.jumpNode.gameObject:SetActiveIfNecessary(false)
        self.view.btnUnlockCondition.interactable = true
    else
        local conditionId = uncompletedConditionId[1]
        local gameMechanicConditionCfg = Tables.gameMechanicConditionTable[conditionId]

        local canJump = DungeonUtils.getConditionCanJump(self.m_dungeonId, conditionId)
        self.view.lockedTxt.text = gameMechanicConditionCfg.desc
        self.view.infoNode.gameObject:SetActiveIfNecessary(false)
        self.view.jumpNode.gameObject:SetActiveIfNecessary(canJump)
        self.view.btnUnlockCondition.interactable = canJump
    end
end



DungeonEntryCtrl._RefreshBottomStamina = HL.Method() << function(self)
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local costStamina = gameMechanicCfg.costStamina

    self.view.staminaCostNode.gameObject:SetActiveIfNecessary(costStamina > 0)
    if costStamina > 0 then
        local cntStamina = GameInstance.player.inventory.curStamina
        local color = cntStamina >= costStamina
                and self.view.config.STAMINA_ENOUGH_COLOR or self.view.config.STAMINA_NOT_ENOUGH_COLOR
        self.view.staminaCostDescTxt.color = color
        self.view.staminaCostNumberTxt.color = color
        self.view.staminaCostNumberTxt.text = ActivityUtils.StaminaDiscount(costStamina)
    end
end



DungeonEntryCtrl.OnStaminaChanged = HL.Method() << function(self)
    self:_RefreshBottomStamina()
end




DungeonEntryCtrl.OnSubGameUnlock = HL.Method(HL.Any) << function(self, args)
    local dungeonId = unpack(args)
    local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(dungeonId)
    if not succ or dungeonCfg.dungeonSeriesId ~= self.m_dungeonSeriesId then
        return
    end

    self:_RefreshContent()
end

HL.Commit(DungeonEntryCtrl)
