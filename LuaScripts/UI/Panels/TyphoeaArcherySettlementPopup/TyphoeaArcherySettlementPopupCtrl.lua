local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaArcherySettlementPopup

local PanelState = {
    ShowResult = 1,
    ShowRewards = 2,
}

local SettlementType = {
    Daily = "daily",
    Simulation = "simulation",
}

TyphoeaArcherySettlementPopupCtrl = HL.Class('TyphoeaArcherySettlementPopupCtrl', uiCtrl.UICtrl)

TyphoeaArcherySettlementPopupCtrl.s_messages = HL.StaticField(HL.Table) << {}

TyphoeaArcherySettlementPopupCtrl.m_settlementType = HL.Field(HL.String) << ""

TyphoeaArcherySettlementPopupCtrl.m_panelState = HL.Field(HL.Number) << PanelState.ShowRewards

TyphoeaArcherySettlementPopupCtrl.m_dungeonId = HL.Field(HL.String) << ""

TyphoeaArcherySettlementPopupCtrl.m_items = HL.Field(HL.Table)

TyphoeaArcherySettlementPopupCtrl.m_afterItems = HL.Field(HL.Table)

TyphoeaArcherySettlementPopupCtrl.m_getRewardItemCellFunc = HL.Field(HL.Function)

TyphoeaArcherySettlementPopupCtrl.m_getAfterRewardCellFunc = HL.Field(HL.Function)

TyphoeaArcherySettlementPopupCtrl.m_leaveTick = HL.Field(HL.Number) << -1

TyphoeaArcherySettlementPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnLeaveDungeon.onClick:AddListener(function()
        self:_OnBtnEmptyClick()
    end)

    self.view.btnContinue.onClick:AddListener(function()
        self:_OnBtnEmptyClick()
    end)
    
    self.m_getRewardItemCellFunc = UIUtils.genCachedCellFunction(self.view.rewardsRoot.rewardsScrollList)
    self.view.rewardsRoot.rewardsScrollList.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateRewardCell(gameObject, csIndex)
    end)
    
    self.m_getAfterRewardCellFunc = UIUtils.genCachedCellFunction(self.view.rewardsRoot.rewardsNodeAfter)
    self.view.rewardsRoot.rewardsNodeAfter.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateAfterRewardCell(gameObject, csIndex)
    end)

    self:_InitController()
    self:StartSettlement(arg)
end

TyphoeaArcherySettlementPopupCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_OPENED)
end

TyphoeaArcherySettlementPopupCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
end

TyphoeaArcherySettlementPopupCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
    if self.m_leaveTick then
        self.m_leaveTick = LuaUpdate:Remove(self.m_leaveTick)
    end
end

TyphoeaArcherySettlementPopupCtrl.OnAnimationInFinished = HL.Override() << function(self)

end

TyphoeaArcherySettlementPopupCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.view.rewardsRoot.focusItemKeyHint.gameObject:SetActive(false)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local rewardNaviGroup = self.view.rewardsRoot.rewardsScrollList.gameObject:GetComponent("UISelectableNaviGroup")
    rewardNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)

    local afterRewardNaviGroup = self.view.rewardsRoot.rewardsNodeAfter.gameObject:GetComponent("UISelectableNaviGroup")
    if afterRewardNaviGroup then
        afterRewardNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
    end
end

TyphoeaArcherySettlementPopupCtrl.StartSettlement = HL.Method(HL.String) << function(self, dungeonId)
    self.m_dungeonId = dungeonId or GameWorld.worldInfo.curLevelId

    local system = GameInstance.player.typhoeaArcherySystem
    local simReward = system:ConsumeSimulationRewardCache()
    local dailyReward = simReward == nil and system:ConsumeDailyRewardCache() or nil

    if simReward ~= nil then
        self.m_settlementType = SettlementType.Simulation
        self.m_items = self:_BuildItemsFromRewardIds({ simReward.rewardId })
        self.m_afterItems = {}
    elseif dailyReward ~= nil then
        self.m_settlementType = SettlementType.Daily
        self.m_items = {}
        self.m_afterItems = {}
    else
        logger.critical("TyphoeaArcherySettlementPopupCtrl 没收到：SC_SHOOTING_RANGE_DAILY_TRAINING_REWARD SC_SHOOTING_RANGE_SIMULATION_TRAINING_REWARD协议")
        self.m_settlementType = SettlementType.Daily
        self.m_items = {}
        self.m_afterItems = {}
    end

    self.m_panelState = self.m_settlementType == SettlementType.Daily and PanelState.ShowResult or PanelState.ShowRewards
    local isDaily = self.m_settlementType == SettlementType.Daily
    self.view.infoNode.gameObject:SetActiveIfNecessary(isDaily)
    self.view.rewardsNode.gameObject:SetActiveIfNecessary(not isDaily)
    self.view.titleTxt.text = Language.LUA_DUNGEON_SETTLEMENT_RESULT_TITLE

    self:_RefreshState()
    self:_RefreshGoalInfo()
    self:_RefreshTimeInfo()
    self:_ResetBtnState()
    if not isDaily then
        self:_RefreshRewardInfo()
    end
    self.m_leaveTick = DungeonUtils.startSubGameLeaveTick(function(leftTime)
        self.view.leaveTxt.text = tostring(leftTime) .. Language.LUA_LEAVE_DUNGEON_TEXT
    end)
end

TyphoeaArcherySettlementPopupCtrl._BuildItemsFromRewardIds = HL.Method(HL.Table).Return(HL.Table) << function(self, rewardIds)
    local itemMap = {}
    local items = {}
    for _, rewardId in ipairs(rewardIds) do
        if not string.isEmpty(rewardId) then
            local rewardBundles = UIUtils.getRewardItems(rewardId)
            for _, reward in ipairs(rewardBundles) do
                local succ, itemCfg = Tables.itemTable:TryGetValue(reward.id)
                if succ then
                    local existing = itemMap[reward.id]
                    if existing then
                        existing.count = existing.count + reward.count
                    else
                        local item = {
                            id = reward.id,
                            count = reward.count,
                            sortId1 = itemCfg.sortId1,
                            sortId2 = itemCfg.sortId2,
                        }
                        itemMap[reward.id] = item
                        table.insert(items, item)
                    end
                end
            end
        end
    end
    table.sort(items, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    return items
end

TyphoeaArcherySettlementPopupCtrl._RefreshState = HL.Method() << function(self)
    local state = "StateOnlyReward"
    if self.m_settlementType == SettlementType.Simulation then
        state = "StateSimulation"
    elseif self.m_settlementType == SettlementType.Daily then
        if self.m_panelState == PanelState.ShowResult then
            state = "StateDaily"
        elseif #self.m_afterItems > 0 then
            state = "StateDaily"
        else
            state = "StateOnlyReward"
        end
    end
    self.view.rewardsRoot.stateController:SetState(state)
end

TyphoeaArcherySettlementPopupCtrl._RefreshGoalInfo = HL.Method() << function(self)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local params = {}
    if self.m_settlementType == SettlementType.Daily then
        local extraTasks = trackingMgr.extraTasks
        local extraTasksCount = extraTasks.Count
        for i = 0, extraTasksCount - 1 do
            local extraTask = extraTasks[i]
            table.insert(params, {
                taskKey = extraTask.taskKey,
                objectiveIndex = 1,
                taskType = CS.Beyond.Gameplay.LevelScriptTaskType.Extra,
            })
        end
    else
        local mainTask = trackingMgr.mainTask
        if mainTask then
            table.insert(params, {
                taskKey = mainTask.taskKey,
                objectiveIndex = 1,
                taskType = CS.Beyond.Gameplay.LevelScriptTaskType.Main,
            })
        else
            logger.error("TyphoeaArcherySettlement Simulation has no mainTask")
        end
    end

    local nodeRef = self.m_settlementType == SettlementType.Daily and self.view.taskInfoNode or self.view.rewardsRoot.taskInfoNode
    DungeonUtils.initGameSettlementTaskInfoNode(nodeRef, params)
    nodeRef.gameObject:SetActiveIfNecessary(#params > 0)
end

TyphoeaArcherySettlementPopupCtrl._RefreshTimeInfo = HL.Method() << function(self)
    local showTimeInfo = false
    if self.m_settlementType == SettlementType.Daily then
        showTimeInfo = true
        self.view.curGameTimeTxt.text = UIUtils.getLeftTimeToSecond(math.floor(GameWorld.worldInfo.subGame.passTimeMs / 1000))
        self.view.newTimeRecord.gameObject:SetActiveIfNecessary(GameWorld.worldInfo.subGame.isPassNewTimeRecord)
    end
    self.view.timeInfoNode.gameObject:SetActiveIfNecessary(showTimeInfo)
end

TyphoeaArcherySettlementPopupCtrl._RefreshRewardInfo = HL.Method() << function(self)
    local rewardCount = #self.m_items
    local afterRewardCount = #self.m_afterItems
    local hasAnyReward = rewardCount > 0 or afterRewardCount > 0

    if self.m_settlementType == SettlementType.Simulation then
        DungeonUtils.initSettlementRewardsWithTitleNode(self.view.rewardsRoot.rewardsWithTitleNode, self.m_items)
    else
        if afterRewardCount > 0 then
            DungeonUtils.initSettlementRewardsWithTitleNode(self.view.rewardsRoot.rewardsWithTitleNode, self.m_items)
            self.view.rewardsRoot.rewardsNodeAfter:UpdateCount(afterRewardCount)
        else
            self.view.rewardsRoot.rewardsScrollList:UpdateCount(rewardCount)
        end
    end

    self.view.emptyRewardNode.gameObject:SetActiveIfNecessary(self.m_settlementType == SettlementType.Daily and not hasAnyReward)
end

TyphoeaArcherySettlementPopupCtrl._ResetBtnState = HL.Method() << function(self)
    local needShowConfirm = false
    if self.m_settlementType == SettlementType.Daily and self.m_panelState == PanelState.ShowResult then
        local hasRewards = #self.m_items > 0 or #self.m_afterItems > 0
        needShowConfirm = hasRewards
    end
    self.view.btnContinue.gameObject:SetActiveIfNecessary(needShowConfirm)
    self.view.btnLeaveDungeon.gameObject:SetActiveIfNecessary(not needShowConfirm)
end


TyphoeaArcherySettlementPopupCtrl._OnBtnEmptyClick = HL.Method() << function(self)
    if self.m_settlementType == SettlementType.Daily and self.m_panelState == PanelState.ShowResult then
        local hasRewards = #self.m_items > 0 or #self.m_afterItems > 0
        if hasRewards then
            self.m_panelState = PanelState.ShowRewards
            self.view.titleTxt.text = Language.LUA_DUNGEON_SETTLEMENT_REWARDS_TITLE
            self.animationWrapper:Play("subgamesettlement_base_popup_change")

            self:_ResetBtnState()
            self:_RefreshState()
            self:_RefreshRewardInfo()
            return
        end
    end
    self:_OnBtnCloseClick()
end

TyphoeaArcherySettlementPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    GameInstance.dungeonManager:LeaveDungeon()
end

TyphoeaArcherySettlementPopupCtrl._OnUpdateRewardCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getRewardItemCellFunc(go)
    local itemData = self.m_items[LuaIndex(csIndex)]
    cell:InitItem(itemData, true)
    cell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
end

TyphoeaArcherySettlementPopupCtrl._OnUpdateAfterRewardCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getAfterRewardCellFunc(go)
    local itemData = self.m_afterItems[LuaIndex(csIndex)]
    cell.item:InitItem(itemData, true)
    cell.item:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
    if cell.afterItemNameTxt then
        cell.afterItemNameTxt.text = itemData.levelName or ""
    end
end

HL.Commit(TyphoeaArcherySettlementPopupCtrl)
