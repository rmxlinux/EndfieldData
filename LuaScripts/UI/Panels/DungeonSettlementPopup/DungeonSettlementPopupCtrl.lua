
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonSettlementPopup

local LevelScriptTaskType = CS.Beyond.Gameplay.LevelScriptTaskType
local RewardSourceType = CS.Beyond.GEnums.RewardSourceType

local PanelState = {
    ShowResult = 1,
    ShowRewards = 2,
}

local RESULT_2_REWARDS_CLIP = "dungeonsettlementpopup_change"





































DungeonSettlementPopupCtrl = HL.Class('DungeonSettlementPopupCtrl', uiCtrl.UICtrl)







DungeonSettlementPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STAMINA_CHANGED] = 'OnStaminaChanged',
}


DungeonSettlementPopupCtrl.s_cachedCompleteResult = HL.StaticField(HL.Table)



DungeonSettlementPopupCtrl.OnDungeonComplete = HL.StaticMethod(HL.Any) << function(args)
    local isNewTimeRecord, curGameTimeRecord = unpack(args)
    if DungeonSettlementPopupCtrl.s_cachedCompleteResult == nil then
        DungeonSettlementPopupCtrl.s_cachedCompleteResult = {}
    end

    DungeonSettlementPopupCtrl.s_cachedCompleteResult.isNewTimeRecord = isNewTimeRecord
    DungeonSettlementPopupCtrl.s_cachedCompleteResult.curGameTimeRecord = curGameTimeRecord
end



DungeonSettlementPopupCtrl.OnShowDungeonResult = HL.StaticMethod(HL.Any) << function(args)
    local dungeonId, leaveTimeDuration, useStaminaReduce = unpack(args)

    
    if DungeonUtils.dungeonTypeValidate(dungeonId, DungeonConst.DUNGEON_CATEGORY.WorldLevel) then
        GameInstance.dungeonManager:LeaveDungeon()
        return
    end

    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonSettlement", function()
        if not Utils.isInDungeon() then
            
            
            logger.error(ELogChannel.Dungeon, "error, try to open settlement out of dungeon")
            return
        end

        
        PhaseManager:ExitPhaseFastTo(PhaseId.Level)

        
        local ctrl = UIManager:AutoOpen(PANEL_ID)
        ctrl:StartSettlement(dungeonId)

        if useStaminaReduce then
            
            ActivityUtils.showStaminaReduceProgress()
        end

    end, function()
        UIManager:Close(PANEL_ID)
    end)
end


DungeonSettlementPopupCtrl.m_panelState = HL.Field(HL.Number) << -1


DungeonSettlementPopupCtrl.m_dungeonId = HL.Field(HL.String) << ""


DungeonSettlementPopupCtrl.m_mainCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonSettlementPopupCtrl.m_extraCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonSettlementPopupCtrl.m_getRewardItemCellFunc = HL.Field(HL.Function)


DungeonSettlementPopupCtrl.m_items = HL.Field(HL.Table)


DungeonSettlementPopupCtrl.m_canCloseSelf = HL.Field(HL.Boolean) << false

DungeonSettlementPopupCtrl.m_hasShowResultState = HL.Field(HL.Boolean) << false


DungeonSettlementPopupCtrl.m_leaveTick = HL.Field(HL.Number) << -1





DungeonSettlementPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnEmpty.onClick:AddListener(function()
        self:_OnBtnEmptyClick()
    end)

    self.view.btnConfirm.onClick:AddListener(function()
        self:_OnBtnEmptyClick()
    end)

    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.view.btnLeaveDungeon.onClick:AddListener(function()
        self:_OnBtnLeaveDungeonClick()
    end)

    self.view.btnRestartDungeon.onClick:AddListener(function()
        self:_OnBtnRestartDungeonClick()
    end)

    self.m_mainCellCache = UIUtils.genCellCache(self.view.mainCell)
    self.m_extraCellCache = UIUtils.genCellCache(self.view.extraCell)
    self.m_getRewardItemCellFunc = UIUtils.genCachedCellFunction(self.view.rewardsScrollList)
    self.view.rewardsScrollList.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateCell(gameObject, csIndex)
    end)

    self.view.rewardsScrollList.onGraduallyShowFinish:AddListener(function()
        self:_OnGraduallyShowFinish()
    end)

    self:_InitController()
end



DungeonSettlementPopupCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_OPENED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, false)
end



DungeonSettlementPopupCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)
end



DungeonSettlementPopupCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)

    if self.m_leaveTick then
        self.m_leaveTick = LuaUpdate:Remove(self.m_leaveTick)
    end
end



DungeonSettlementPopupCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local obj = self.view.rewardsScrollList:Get(0)
    if obj then
        local cell = self.m_getRewardItemCellFunc(obj)
        if cell then
            InputManagerInst:MoveVirtualMouseTo(cell.transform, self.uiCamera)
        end
    end
end



DungeonSettlementPopupCtrl._OnGraduallyShowFinish = HL.Method() << function(self)
    self.view.btnEmpty.gameObject:SetActive(false)
    self:_CheckCanCloseSelf()

    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder.gameObject:SetActive(true)
        self.view.focusItemKeyHint.gameObject:SetActive(true)
        local firstItemGo = self.view.rewardsScrollList:Get(0)
        if firstItemGo then
            self.view.focusItemKeyHint.transform.position = firstItemGo.transform.position
            local keyHintPos = self.view.focusItemKeyHint.transform.localPosition
            keyHintPos = keyHintPos + self.view.config.FOCUS_REWARDS_OFFSET
            self.view.focusItemKeyHint.transform.localPosition = keyHintPos
        end
    end
end



DungeonSettlementPopupCtrl._OnBtnEmptyClick = HL.Method() << function(self)
    if self.m_panelState == PanelState.ShowResult then
        self.m_panelState = PanelState.ShowRewards
        self:_ToggleRewardsState(true)
        self.animationWrapper:Play(RESULT_2_REWARDS_CLIP)
        self:_UpdateRewardsState()
    elseif self.m_panelState == PanelState.ShowRewards then
        self:_OnClickSkipGraduallyShow()
    end
end



DungeonSettlementPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    if not self.m_canCloseSelf then
        return
    end

    
    self:PlayAnimationOutWithCallback(function()
        self:Close()
        UIManager:Show(PanelId.DungeonCharTimeHint)
    end)
end



DungeonSettlementPopupCtrl._UpdateRewardsState = HL.Method() << function(self)
    self.m_items = self:_GetRewardItems()

    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local gameCategory = dungeonCfg.dungeonCategory
    local gameMechanicCategoryCfg = Tables.gameMechanicCategoryTable[gameCategory]

    self.view.btnRestartDungeon.gameObject:SetActiveIfNecessary(gameMechanicCategoryCfg.canReChallengeAfterReward)

    local rewardsCount = #self.m_items
    self.view.rewardsList.gameObject:SetActiveIfNecessary(rewardsCount > 0)
    self.view.emptyRewardNode.gameObject:SetActiveIfNecessary(rewardsCount == 0)
    self.view.rewardsScrollList:UpdateCount(rewardsCount)

    self.view.btnNode.gameObject:SetActiveIfNecessary(not self.m_canCloseSelf)
    self.view.infoDeco.gameObject:SetActiveIfNecessary(self.m_canCloseSelf)

    local showStaminaNode = DungeonUtils.isDungeonCostStamina(self.m_dungeonId)
    if showStaminaNode then
        self:_RefreshCostStamina()
    end
    self.view.staminaNode.gameObject:SetActiveIfNecessary(showStaminaNode)

    self.view.btnEmpty.gameObject:SetActiveIfNecessary(true)
end



DungeonSettlementPopupCtrl._RefreshCostStamina = HL.Method() << function(self)
    
    
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local isHunterMode = DungeonUtils.isDungeonHasHunterMode(self.m_dungeonId)
    local costStamina = isHunterMode and dungeonCfg.hunterModeCostStamina or dungeonCfg.costStamina

    UIUtils.updateStaminaNode(self.view.staminaNode, {
        costStamina = ActivityUtils.getRealStaminaCost(costStamina),
        descStamina = Language["ui_dungeon_details_ap_refresh"],
        delStamina = ActivityUtils.hasStaminaReduceCount() and costStamina or nil
    })
end




DungeonSettlementPopupCtrl._ToggleRewardsState = HL.Method(HL.Boolean) << function(self, isRewardState)
    self.view.rewardsNode.gameObject:SetActiveIfNecessary(isRewardState)
    self.view.infoNode.gameObject:SetActiveIfNecessary(not isRewardState)

    
    self.view.btnNode.gameObject:SetActiveIfNecessary(isRewardState)
    self.view.titleTxt.text = isRewardState and Language.LUA_DUNGEON_SETTLEMENT_REWARDS_TITLE
            or Language.LUA_DUNGEON_SETTLEMENT_RESULT_TITLE
end



DungeonSettlementPopupCtrl._OnBtnRestartDungeonClick = HL.Method() << function(self)
    local restartFunc = function()
        self:PlayAnimationOutWithCallback(function()
            GameInstance.dungeonManager:RestartDungeonWithBlackScreen()
            
            self:Close()
        end)
    end

    local isCostStamina, costStamina = DungeonUtils.isDungeonCostStamina(self.m_dungeonId)
    if isCostStamina then
        local cntStamina = GameInstance.player.inventory.curStamina
        local realCostStamina = ActivityUtils.getRealStaminaCost(costStamina)
        if cntStamina < realCostStamina then
            DungeonUtils.TryShowDungeonInsufficientStaminaPopup(self.m_dungeonId, restartFunc)
        else
            restartFunc()
        end
    else
        restartFunc()
    end
end



DungeonSettlementPopupCtrl._OnBtnLeaveDungeonClick = HL.Method() << function(self)
    
    self:Notify(MessageConst.HIDE_ITEM_TIPS)

    
    
    GameInstance.dungeonManager:LeaveDungeon()
end



DungeonSettlementPopupCtrl._OnClickSkipGraduallyShow = HL.Method() << function(self)
    if self.m_hasShowResultState then
        self.animationWrapper:SampleClipAtPercent(RESULT_2_REWARDS_CLIP, 1)
    else
        self.view.luaPanel.animationWrapper:SkipInAnimation()
    end

    self.view.rewardsScrollList:SkipGraduallyShow()
end





DungeonSettlementPopupCtrl._OnUpdateCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getRewardItemCellFunc(go)
    local index = LuaIndex(csIndex)
    local itemBundle = self.m_items[index]
    cell:InitItem(itemBundle, true)
    UIUtils.setRewardItemRarityGlow(cell, UIUtils.getItemRarity(itemBundle.id))
    cell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
end



DungeonSettlementPopupCtrl._GetRewardItems = HL.Method().Return(HL.Table) << function(self)
    local items = {}
    local firstPassRewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(RewardSourceType.DungeonFirstPass)
    if firstPassRewardPack and firstPassRewardPack.rewardSourceType == RewardSourceType.DungeonFirstPass then
        for _, itemBundle in pairs(firstPassRewardPack.itemBundleList) do
            local _, itemCfg = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemCfg then
                table.insert(items, {id = itemBundle.id,
                                     count = itemBundle.count,
                                     typeId = 3,
                                     typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.First,
                                     sortId1 = itemCfg.sortId1,
                                     sortId2 = itemCfg.sortId2,})
            end
        end
    end

    local extraRewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(RewardSourceType.DungeonExtraReward)
    if extraRewardPack and extraRewardPack.rewardSourceType == RewardSourceType.DungeonExtraReward then
        for _, itemBundle in pairs(extraRewardPack.itemBundleList) do
            local _, itemCfg = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemCfg then
                table.insert(items, {id = itemBundle.id,
                                     count = itemBundle.count,
                                     typeId = 2,
                                     typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.Extra,
                                     sortId1 = itemCfg.sortId1,
                                     sortId2 = itemCfg.sortId2,})
            end
        end
    end

    local mainRewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(RewardSourceType.DungeonMainReward)
    if mainRewardPack and mainRewardPack.rewardSourceType == RewardSourceType.DungeonMainReward then
        for _, itemBundle in pairs(mainRewardPack.itemBundleList) do
            local _, itemCfg = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemCfg then
                table.insert(items, {id = itemBundle.id,
                                     count = itemBundle.count,
                                     typeId = 1,
                                     typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.Regular,
                                     sortId1 = itemCfg.sortId1,
                                     sortId2 = itemCfg.sortId2,})
            end
        end
    end

    local sortKeys = UIConst.COMMON_ITEM_SORT_KEYS
    table.insert(sortKeys, 1, "typeId")
    table.sort(items, Utils.genSortFunction(sortKeys))
    return items
end



DungeonSettlementPopupCtrl._UpdateResultState = HL.Method() << function(self)
    local succ, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_dungeonId)
    if not succ then
        return
    end

    
    local showTimeInfo = subGameData.hasTimer or subGameData.hasTimeLimit
    if showTimeInfo then
        local curGameTimeRecord = DungeonSettlementPopupCtrl.s_cachedCompleteResult.curGameTimeRecord
        local isNewTimeRecord = DungeonSettlementPopupCtrl.s_cachedCompleteResult.isNewTimeRecord

        self.view.curGameTimeTxt.text = UIUtils.getLeftTimeToSecond(curGameTimeRecord / 1000)
        self.view.newTimeRecord.gameObject:SetActiveIfNecessary(isNewTimeRecord)
    end
    self.view.timeInfoNode.gameObject:SetActiveIfNecessary(showTimeInfo)

    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    
    local mainTask = trackingMgr.mainTask
    local mainTaskCount = mainTask ~= nil and mainTask.objectives.Length or 0
    self.m_mainCellCache:Refresh(mainTaskCount, function(cell, luaIndex)
        self:_UpdateGoalCell(cell, luaIndex, LevelScriptTaskType.Main)
    end)
    self.view.mainInfoNode.gameObject:SetActiveIfNecessary(mainTaskCount > 0)

    
    local extraTask = trackingMgr.extraTask
    local extraTaskCount = extraTask ~= nil and extraTask.objectives.Length or 0
    self.m_extraCellCache:Refresh(extraTaskCount, function(cell, luaIndex)
        self:_UpdateGoalCell(cell, luaIndex, LevelScriptTaskType.Extra)
    end)
    self.view.extraInfoNode.gameObject:SetActiveIfNecessary(extraTaskCount > 0)

    
    local sceneId = GameWorld.worldInfo.curLevelId
    local gainedRewardChestNum, maxRewardChestNum = DungeonUtils.getDungeonChestCount(sceneId)
    local hasChest = maxRewardChestNum > 0
    self.view.chestInfoNode.gameObject:SetActive(hasChest)
    if hasChest then
        self.view.chestInfoNode.chestNumTxt.text = string.format("%d/%d", gainedRewardChestNum, maxRewardChestNum)
    end
end






DungeonSettlementPopupCtrl._UpdateGoalCell = HL.Method(HL.Any, HL.Number, CS.Beyond.Gameplay.LevelScriptTaskType)
        << function(self, cell, luaIndex, taskType)
    local trackingTask = GameWorld.levelScriptTaskTrackingManager:GetTaskByType(taskType)
    local csIndex = CSIndex(luaIndex)
    local obj = trackingTask.objectives[csIndex]
    local finished = obj.isCompleted

    local success, descText, progressText = trackingTask:TryGetValueObjectiveDescription(obj)
    cell.finishedIcon.gameObject:SetActiveIfNecessary(finished)
    cell.normalIcon.gameObject:SetActiveIfNecessary(not finished)
    cell.goalTxt.text = descText
    cell.stateTxt.text = progressText

    local succ, objTrackingInfo = trackingTask.extraInfo.trackingInfoDict:TryGetValue(obj.objectiveEnum)
    cell.stateTxt.gameObject:SetActiveIfNecessary(succ and objTrackingInfo.needFormatProgress)
end



DungeonSettlementPopupCtrl._CheckCanCloseSelf = HL.Method() << function(self)
    if not self.m_canCloseSelf then
        return
    end
    self.view.btnClose.gameObject:SetActiveIfNecessary(true)
end




DungeonSettlementPopupCtrl.StartSettlement = HL.Method(HL.String) << function(self, dungeonId)
    self.m_dungeonId = dungeonId

    local needStamina = DungeonUtils.isDungeonCostStamina(self.m_dungeonId)
    if needStamina then
        local ids = { Tables.dungeonConst.staminaItemId }
        local doubleTicket = Tables.dungeonConst.doubleStaminaTicketItemId
        local hasGotDoubleTicket = GameInstance.player.inventory:IsItemGot(doubleTicket)
        if hasGotDoubleTicket then
            table.insert(ids, 1, doubleTicket)
        end
        self.view.walletBarPlaceholder:InitWalletBarPlaceholder(ids)
    end

    
    local needShowResult = DungeonUtils.isDungeonChallenge(self.m_dungeonId)
    self.m_hasShowResultState = needShowResult
    
    self.m_canCloseSelf = DungeonUtils.isDungeonChar(self.m_dungeonId)
    self.view.btnEmpty.gameObject:SetActiveIfNecessary(self.m_canCloseSelf)
    self.view.btnClose.gameObject:SetActiveIfNecessary(false)

    if needShowResult then
        self.m_panelState = PanelState.ShowResult
    else
        self.m_panelState = PanelState.ShowRewards
    end

    if self.m_panelState == PanelState.ShowResult then
        self:_ToggleRewardsState(false)
        self:_UpdateResultState()
    elseif self.m_panelState == PanelState.ShowRewards then
        self:_ToggleRewardsState(true)
        self:_UpdateRewardsState()
    end

    if self.m_canCloseSelf then
        UIManager:Open(PanelId.DungeonCharTimeHint)
        UIManager:Hide(PanelId.DungeonCharTimeHint)
    else
        
        self.m_leaveTick = DungeonUtils.startSubGameLeaveTick(function(leftTime)
            self.view.leaveTxt.text = tostring(leftTime) .. Language.LUA_LEAVE_DUNGEON_TEXT
        end)
    end
end



DungeonSettlementPopupCtrl.OnStaminaChanged = HL.Method() << function(self)
    self:_RefreshCostStamina()
end



DungeonSettlementPopupCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.view.focusItemKeyHint.gameObject:SetActive(false)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    local rewardNaviGroup = self.view.rewardsScrollList.gameObject:GetComponent("UISelectableNaviGroup")
    rewardNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
end

HL.Commit(DungeonSettlementPopupCtrl)