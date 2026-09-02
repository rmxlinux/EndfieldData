
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaArcherySimulateTrain
local system = GameInstance.player.typhoeaArcherySystem

TyphoeaArcherySimulateTrainCtrl = HL.Class('TyphoeaArcherySimulateTrainCtrl', uiCtrl.UICtrl)






TyphoeaArcherySimulateTrainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_TYPHOEA_ARCHERY_SIMULATION_TRAINING_REWARD] = '_UpdateSimulateTrain', 
    [MessageConst.ON_TYPHOEA_ARCHERY_CHIP_SET_CHANGED] = '_OnRefreshChip', 
}

TyphoeaArcherySimulateTrainCtrl.m_archeryData = HL.Field(HL.Any)
TyphoeaArcherySimulateTrainCtrl.m_tabGroups = HL.Field(HL.Table)
TyphoeaArcherySimulateTrainCtrl.m_tabGroupCache = HL.Field(HL.Any)
TyphoeaArcherySimulateTrainCtrl.m_curSelectedCell = HL.Field(HL.Any)
TyphoeaArcherySimulateTrainCtrl.m_curSelectedDungeonId = HL.Field(HL.String) << ""
TyphoeaArcherySimulateTrainCtrl.m_rewardCache = HL.Field(HL.Any)
TyphoeaArcherySimulateTrainCtrl.m_cellCache = HL.Field(HL.Table)
TyphoeaArcherySimulateTrainCtrl.m_tabSubCells = HL.Field(HL.Table)


TyphoeaArcherySimulateTrainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs(true)
end

TyphoeaArcherySimulateTrainCtrl.OnShow = HL.Override() << function(self)
    
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.contentRect)
    local selectedTab = self.m_tabSubCells[self.m_curSelectedDungeonId]
    self.view.simulateTrainGroupScrollRect:AutoScrollToRectTransform(selectedTab.rectTransform, true);
    
    if DeviceInfo.usingController then
        self:SetNaviTarget(selectedTab.clickBtn)
    end
    
    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_curSelectedDungeonId)
    self.view.rightNode.chipSetWidget:InitArcheryChipSet(isLocked, chipIds, true)
    
    self.m_phase:UpdateSelectedDungeonId(self.m_curSelectedDungeonId)
end

TyphoeaArcherySimulateTrainCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_archeryData = system.archeryData
    self.m_tabGroups = {}
    self.m_cellCache = {}
    self.m_tabSubCells = {}

    local found = false
    
    if not string.isEmpty(arg.dungeonId) then
        self.m_curSelectedDungeonId = arg.dungeonId
        found = true
    end

    local archeryMaxLv = self.m_archeryData.maxLv
    
    local gameInfos = TyphoeaArcheryUtils.getGameIdsByPoiLevel(archeryMaxLv, Tables.typhoeaArcherySimulateTrainTable, false)
    local groupInfoRecorded = {}
    local unlockedGameIds = {}
    for _, gameInfo in pairs(gameInfos) do
        local groupId = gameInfo.simLevelGroupId
        local dungeonId = gameInfo.simLevelId
        local index = groupInfoRecorded[groupId] and groupInfoRecorded[groupId] or (#self.m_tabGroups + 1)
        if index > #self.m_tabGroups then
            table.insert(self.m_tabGroups,{
                groupId = groupId,
                gameIds = {gameInfo.simLevelId}
            })
            groupInfoRecorded[groupId] = index
        else
            table.insert(self.m_tabGroups[index].gameIds, dungeonId)
        end
        
        if DungeonUtils.isDungeonUnlock(dungeonId) then
            table.insert(unlockedGameIds, dungeonId)
            if not found and not system:IsSimulateTrainCompleted(dungeonId) then
                found = true
                self.m_curSelectedDungeonId = dungeonId
            end
        end
    end
    
    if not found then
        self.m_curSelectedDungeonId = unlockedGameIds[#unlockedGameIds]
    end
end

TyphoeaArcherySimulateTrainCtrl._InitUI = HL.Method() << function(self)
    
    self.view.rightNode.btnConfigureChip.onClick:AddListener(function()
        self.m_phase:ConfigureChip(self.m_curSelectedDungeonId)
    end)
    
    self.view.rightNode.btnBeginTraining.onClick:AddListener(function()
        self:_EnterDungeon()
    end)
    
    self.view.rightNode.btnRewardDetails.onClick:AddListener(function()
        self:_ShowRewardDetail()
    end)
    
    self.view.rightNode.btnEnemyDetail.onClick:AddListener(function()
        self.m_phase:OpenEnemyDetailsPopup(self.m_curSelectedDungeonId)
    end)

    self.m_tabGroupCache = UIUtils.genCellCache(self.view.tabGroupCell)
    self.m_rewardCache = UIUtils.genCellCache(self.view.rightNode.rewardCell)
end

TyphoeaArcherySimulateTrainCtrl._UpdateData = HL.Method() << function(self)
    self.m_archeryData = system.archeryData
end

TyphoeaArcherySimulateTrainCtrl._RefreshAllUIs = HL.Method(HL.Boolean) << function(self, isInit)
    self.m_tabGroupCache:Refresh(#self.m_tabGroups, function(cell, luaIndex)
        self:_OnRefreshTabGroupCell(cell, luaIndex, isInit)
    end)
    self:_RefreshCommonInfo(isInit)
end

TyphoeaArcherySimulateTrainCtrl._OnRefreshTabGroupCell = HL.Method(HL.Any, HL.Number, HL.Boolean) << function(self, cell, luaIndex, isInit)
    local tabGroupData = self.m_tabGroups[luaIndex]
    local cellCache = self.m_cellCache[luaIndex]
    local _, groupCfg = Tables.typhoeaArcherySimulateTrainGroupTable:TryGetValue(tabGroupData.groupId)

    
    cell.gameObject.name = "SimTrainGroup-"..luaIndex
    cell.nameTxt.text = groupCfg.simLevelGroupName
    cell.nameTxt.text = groupCfg.simLevelGroupName
    cell.stateController:SetState(groupCfg.style)

    
    local completeNum = 0
    local hasSelectedCell = false
    local dungeonIds = {}
    for _, dungeonId in pairs(tabGroupData.gameIds) do
        table.insert(dungeonIds, dungeonId)
        if system:IsSimulateTrainCompleted(dungeonId) then
            completeNum = completeNum + 1
        end
        if dungeonId == self.m_curSelectedDungeonId then
            hasSelectedCell = true
        end
    end
    local maxNum = #tabGroupData.gameIds
    cell.numTxt.text = string.format(Language.LUA_DUNGEONCOMMONSELECTIONGROUPCELL_NUMBER, completeNum, maxNum)
    cell.stateController:SetState(completeNum==maxNum and "Finish" or "UnFinish")
    
    if hasSelectedCell then
        cell.mainTog.isOn = hasSelectedCell
    else
        if isInit then
            local isUsingController = (DeviceInfo.inputType == DeviceInfo.InputType.Controller)
            cell.mainTog.isOn = false or isUsingController
        end
    end

    
    if isInit then
        cellCache = UIUtils.genCellCache(cell.subTrainCell)
        
        cell.redDot:InitRedDot("TyphoeaArcheryDungeonReadNormal", dungeonIds, nil, self.view.redDotScrollRect)
    end
    cellCache:Refresh(maxNum, function(cell, index)
        self:_OnRefreshTabSubCell(cell, luaIndex, index, groupCfg.style, isInit)
    end)

end

TyphoeaArcherySimulateTrainCtrl._OnRefreshTabSubCell = HL.Method(HL.Any, HL.Number, HL.Number, HL.String, HL.Boolean) << function(self, cell, groupIndex, index, style, isInit)
    local dungeonId = self.m_tabGroups[groupIndex].gameIds[index]
    self.m_tabSubCells[dungeonId] = cell
    
    local _, trainData = Tables.typhoeaArcherySimulateTrainTable:TryGetValue(dungeonId)
    cell.gameObject.name = "SimTrain-"..index
    cell.nameTxt.text = trainData.levelName
    cell.completeNameTxt.text = trainData.levelName
    
    local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
    local isPassed = system:IsSimulateTrainCompleted(dungeonId)
    local isSelected = dungeonId == self.m_curSelectedDungeonId
    cell.stateController:SetState(style)
    cell.stateController:SetState(isUnlock and "UnLock" or "Lock")
    cell.stateController:SetState(isPassed and "Complete" or "UnComplete")
    self:_SetCellSelected(cell, isSelected)
    
    if isInit then
        cell.clickBtn.onClick:AddListener(function()
            self:_OnDungeonTabClick(cell, dungeonId)
        end)
    end
    cell.redDot:InitRedDot("TyphoeaArcheryDungeonReadNormal", {dungeonId}, nil, self.view.redDotScrollRect)
end

TyphoeaArcherySimulateTrainCtrl._SetCellSelected = HL.Method(HL.Any, HL.Boolean) << function(self, cell, isSelected)
    cell.stateController:SetState(isSelected and "Select" or "UnSelect")
    if isSelected then
        self.m_curSelectedCell = cell
        
        GameInstance.player.subGameSys:SendReadSubGames({ self.m_curSelectedDungeonId })
    end
end

TyphoeaArcherySimulateTrainCtrl._OnDungeonTabClick = HL.Method(HL.Any, HL.String) << function(self, cell, dungeonId)
    if self.m_curSelectedDungeonId == dungeonId then
        return
    end

    
    self.view.rightNode.animationWrapper:PlayInAnimation()

    local preCell = self.m_curSelectedCell
    self.m_curSelectedCell = cell
    self.m_curSelectedDungeonId = dungeonId

    self:_SetCellSelected(preCell, false)
    self:_SetCellSelected(cell, true)

    self:_RefreshCommonInfo(false)
    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_curSelectedDungeonId)
    self.view.rightNode.chipSetWidget:InitArcheryChipSet(isLocked, chipIds, true)

    self.m_phase:UpdateSelectedDungeonId(self.m_curSelectedDungeonId)
end

TyphoeaArcherySimulateTrainCtrl._RefreshCommonInfo = HL.Method(HL.Boolean) << function(self, isInit)
    local succ, trainData = Tables.typhoeaArcherySimulateTrainTable:TryGetValue(self.m_curSelectedDungeonId)

    
    self.view.rightNode.dungeonTitleTxt.text = trainData.levelName
    self.view.rightNode.dungeonDescTxt.text = trainData.levelDesc
    
    local completed = system:IsSimulateTrainCompleted(self.m_curSelectedDungeonId)
    self.view.rightNode.featureTxt.text = trainData.levelTargetDesc
    self.view.rightNode.featureStateNode:SetState(completed and "Finish" or "UnFinished")
    
    local isUnlock = DungeonUtils.isDungeonUnlock(self.m_curSelectedDungeonId)
    self.view.rightNode.bottomStateController:SetState(isUnlock and "Unlock" or "Lock")
    if not isUnlock then
        local unCompletedConditions = DungeonUtils.getUncompletedConditionIds(self.m_curSelectedDungeonId)
        table.sort(unCompletedConditions)
        if #unCompletedConditions > 0 then
            local conditionId = unCompletedConditions[1]
            local _, conditionCfg = Tables.gameMechanicConditionTable:TryGetValue(conditionId)
            self.view.rightNode.lockedTxt.text = conditionCfg.desc
        end
    end
    
    local dungeonMgr = GameInstance.dungeonManager
    local firstRewardGained = completed 
    local rewardBundles = UIUtils.getRewardItems(trainData.levelReward)
    
    local items = {}
    for _, reward in ipairs(rewardBundles) do
        local succ, itemCfg = Tables.itemTable:TryGetValue(reward.id)
        if succ then
            local item = {
                id = reward.id,
                count = reward.count,
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
            }
            table.insert(items, item)
        end
    end
    table.sort(items, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    self.m_rewardCache:Refresh(#items, function(cell, index)
        
        cell.stateController:SetState(firstRewardGained and "Get" or "First")
        cell.gameObject.name = "reward-"..index
        
        local itemCell = cell.itemSmall
        itemCell.view.simpleStateController:SetState("Normal")
        local reward = {
            id = items[index].id,
            count = items[index].count,
            forceHidePotentialStar = true,
        }
        itemCell:InitItem(reward, function()
            itemCell:ShowTips()
        end)
        itemCell:SetExtraInfo({
            tipsPosTransform = itemCell.view.content,
            isSideTips = true,
        })
    end)
end

TyphoeaArcherySimulateTrainCtrl._ShowRewardDetail = HL.Method() << function(self)
    local _, trainData = Tables.typhoeaArcherySimulateTrainTable:TryGetValue(self.m_curSelectedDungeonId)
    local gained = system:IsSimulateTrainCompleted(self.m_curSelectedDungeonId) 
    local rewardId = trainData.levelReward
    local rewardData = {}
    if not string.isEmpty(rewardId) then
        local rewardCfg = Tables.rewardTable[rewardId]
        for _, itemBundle in pairs(rewardCfg.itemBundles) do
            local itemCfg = Tables.itemTable[itemBundle.id]
            table.insert(rewardData, {
                id = itemBundle.id,
                count = itemBundle.count,
                gained = gained,
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
            })
        end
    end
    table.sort(rewardData, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    local args = {
        firstPartRewards = rewardData,
    }
    UIManager:AutoOpen(PanelId.CommonRewardDetailsPopup, args)
end

TyphoeaArcherySimulateTrainCtrl._EnterDungeon = HL.Method() << function(self)
    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_curSelectedDungeonId)
    if not isLocked and chipIds.Count < 2 then
        local noChipTipType = "noChip"
        local noChipNoTip = TyphoeaArcheryUtils.isNoTipToday(noChipTipType)
        if not noChipNoTip then
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language.LUA_TYPHOEA_ARCHERY_DAILY_NO_CHIP_POP_UP, 
                onConfirm = function()
                    if noChipNoTip then
                        TyphoeaArcheryUtils.setNoTipToday(noChipTipType)
                    end
                    self.m_phase:EnterDungeon(self.m_curSelectedDungeonId)
                end,
                toggle = {
                    isOn = false,
                    onValueChanged = function(isOn)
                        noChipNoTip = isOn
                    end,
                    toggleText = Language.LUA_TYPHOEA_ARCHERY_NO_TIP_TODAY, 
                },
            })
        else
            self.m_phase:EnterDungeon(self.m_curSelectedDungeonId)
        end
    else
        self.m_phase:EnterDungeon(self.m_curSelectedDungeonId)
    end
end

TyphoeaArcherySimulateTrainCtrl._OnRefreshChip = HL.Method(HL.Table) << function(self, arg)
    if arg.dungeonId ~= self.m_curSelectedDungeonId then
        return
    end
    self.view.rightNode.chipSetWidget:InitArcheryChipSet(arg.isLocked, arg.chipIds, false)
end

TyphoeaArcherySimulateTrainCtrl._UpdateSimulateTrain = HL.Method() << function(self)
    self:_UpdateData()
    self:_RefreshAllUIs(false)
end

HL.Commit(TyphoeaArcherySimulateTrainCtrl)
