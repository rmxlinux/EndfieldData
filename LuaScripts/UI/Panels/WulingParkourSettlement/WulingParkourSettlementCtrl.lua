local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WulingParkourSettlement
local RewardSourceType = CS.Beyond.GEnums.RewardSourceType

WulingParkourSettlementCtrl = HL.Class('WulingParkourSettlementCtrl', uiCtrl.UICtrl)







WulingParkourSettlementCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

WulingParkourSettlementCtrl.m_dungeonId = HL.Field(HL.String) << ""
WulingParkourSettlementCtrl.m_items = HL.Field(HL.Table)
WulingParkourSettlementCtrl.m_getRewardItemCellFunc = HL.Field(HL.Function)
WulingParkourSettlementCtrl.m_leaveTick = HL.Field(HL.Number) << -1
WulingParkourSettlementCtrl.m_passTime = HL.Field(HL.Number) << 0

WulingParkourSettlementCtrl.m_resultCells = HL.Field(HL.Forward("UIListCache"))
WulingParkourSettlementCtrl.m_progressCells = HL.Field(HL.Forward("UIListCache"))


WulingParkourSettlementCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)

    self.m_passTime = 0
    self.m_dungeonId = arg
    self.view.btnContinue.gameObject:SetActive(false)

    self.view.btnLeaveDungeon.onClick:AddListener(function()
        self:_OnBtnLeaveDungeonClick()
    end)

    self.view.btnRestartDungeon.onClick:AddListener(function()
        self:_OnBtnRestartDungeonClick()
    end)

    self.m_leaveTick = DungeonUtils.startSubGameLeaveTick(function(leftTime)
        self.view.leaveTxt.text = tostring(leftTime) .. Language.LUA_LEAVE_DUNGEON_TEXT
    end)

    self.m_resultCells = UIUtils.genCellCache(self.view.resultCell)
    self.m_progressCells = UIUtils.genCellCache(self.view.progressCell)

    self.m_getRewardItemCellFunc = UIUtils.genCachedCellFunction(self.view.gameSettlementRewardsWithTitleNode.rewardsNodeList)
    self.view.gameSettlementRewardsWithTitleNode.rewardsNodeList.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateRewardCell(gameObject, csIndex)
    end)

    self:_RefreshResultInfos()
    self:_RefreshProgressInfos()
    self:_RefreshRewardInfo()

end

WulingParkourSettlementCtrl._OnBtnLeaveDungeonClick = HL.Method() << function(self)
    
    self:Notify(MessageConst.HIDE_ITEM_TIPS)


    self:PlayAnimationOutWithCallback(function()
        GameInstance.dungeonManager:LeaveDungeon()
        self:Close()
    end)
end

WulingParkourSettlementCtrl._OnBtnRestartDungeonClick = HL.Method() << function(self)
    self:PlayAnimationOutWithCallback(function()
        GameInstance.dungeonManager.curDungeonLikeSubGame:SendReStart(true)
        self:Close()
    end)
end

WulingParkourSettlementCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)

    if self.m_leaveTick then
        self.m_leaveTick = LuaUpdate:Remove(self.m_leaveTick)
    end
end

WulingParkourSettlementCtrl._OnUpdateRewardCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getRewardItemCellFunc(go)
    local itemData = self.m_items[LuaIndex(csIndex)]
    cell:InitItem(itemData, true)
    local firstCell = self.m_getRewardItemCellFunc(1)
    cell:SetExtraInfo({
        tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
        tipsPosTransform = firstCell and firstCell.transform or cell.transform,
        isSideTips = DeviceInfo.usingController,
    })
end

WulingParkourSettlementCtrl._RefreshResultInfos = HL.Method() << function(self)
    self.view.titleTxt.text = Language.LUA_PARKOUR_SETTLEMENT_PANEL_TITLE
    self.view.resultNodeTitleText.text = Language.LUA_PARKOUR_SETTLEMENT_RESULT_TITLE
    self.view.resultNodeTitleIcon.gameObject:SetActive(false)

    local subGameId = GameWorld.worldInfo.curSubGameId
    local collectedCount = GameInstance.player.parkourSystem.currentCollectedCount
    local bubbleMax = 0
    local succ, uiCfg = Tables.ParkourUiTable:TryGetValue(subGameId)
    if succ then
        bubbleMax = uiCfg.bubbleMaxNumber
    end

    self.m_passTime = GameInstance.player.parkourSystem:GetBestPassTimeBySubGameId(self.m_dungeonId)
    self.m_resultCells:Refresh(2,function(cell, luaIndex)
        if luaIndex == 1 then
            cell.headIcon:LoadSprite("Common", "icon_settlement_wuling_parkour_score")
            cell.goalTxt.text = Language.LUA_PARKOUR_SETTLEMENT_RESULT_DESC_TIME
            cell.resultDescText.text = self.m_passTime > 0 and UIUtils.getLeftTimeToSecond(math.floor(self.m_passTime / 1000)) or "--:--"
            local lastBestPassTime = GameInstance.player.parkourSystem.lastBestPassTime
            local showNewRecord = self.m_passTime > 0 and (lastBestPassTime == 0 or self.m_passTime < lastBestPassTime)
            if showNewRecord then
                cell.newTimeRecord.gameObject:SetActive(true)
            else
                cell.newTimeRecord.gameObject:SetActive(false)
            end
        elseif luaIndex == 2 then
            cell.headIcon:LoadSprite("Common", "icon_settlement_wuling_parkour_collect_progress")
            cell.goalTxt.text = Language.LUA_PARKOUR_SETTLEMENT_RESULT_DESC_COLLECT
            cell.resultDescText.text = string.format(Language.LUA_PARKOUR_SETTLEMENT_COLLECT_FORMAT, collectedCount, bubbleMax)
            cell.newTimeRecord.gameObject:SetActive(false)
        end
    end)
end

WulingParkourSettlementCtrl._RefreshProgressInfos = HL.Method() << function(self)
    self.view.progressNodeTitleText.text = Language.LUA_PARKOUR_SETTLEMENT_PROGRESS_TITLE
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local extraTasks = trackingMgr.extraTasks

    self.m_progressCells:Refresh(extraTasks.Count, function(cell, luaIndex)
        local taskInfo = extraTasks[CSIndex(luaIndex)]
        local taskKey = taskInfo.taskKey
        local trackingTask = trackingMgr:GetTaskByKey(taskKey)
        local objective = trackingTask.objectives[CSIndex(1)]
        local isCompleted = objective.isCompleted
        cell.stateController:SetState(isCompleted and "statesucc" or "statefail")
        local success, descText = trackingTask:TryGetValueObjectiveDescription(objective)
        if success then
            cell.goalTxt.text = descText
        end
    end)
end

WulingParkourSettlementCtrl._RefreshRewardInfo = HL.Method() << function(self)
    self.m_items = self:_GetRewardItems()
    local rewardCount = #self.m_items
    if rewardCount > 0 then
        self.view.gameSettlementRewardsWithTitleNode.stateController:SetState("HasItem")
        self.view.gameSettlementRewardsWithTitleNode.rewardsNodeList:UpdateCount(rewardCount)
    else
        self.view.gameSettlementRewardsWithTitleNode.stateController:SetState("EmptyItem")
    end
end

WulingParkourSettlementCtrl._GetRewardItems = HL.Method().Return(HL.Table) << function(self)
    local items = {}

    local mainRewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(RewardSourceType.DungeonExtraReward)
    if mainRewardPack and mainRewardPack.rewardSourceType == RewardSourceType.DungeonExtraReward then
        for _, itemBundle in pairs(mainRewardPack.itemBundleList) do
            local _, itemCfg = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemCfg then
                local typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.Regular
                local typeId = typeTag == DungeonConst.DUNGEON_REWARD_TAG_STATE.Regular and 2 or 1
                table.insert(items, {id = itemBundle.id,
                                     count = itemBundle.count,
                                     typeId = typeId,
                                     
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











HL.Commit(WulingParkourSettlementCtrl)
