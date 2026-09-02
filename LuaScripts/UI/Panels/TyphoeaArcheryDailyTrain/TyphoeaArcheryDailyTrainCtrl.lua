
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaArcheryDailyTrain
local system = GameInstance.player.typhoeaArcherySystem

TyphoeaArcheryDailyTrainCtrl = HL.Class('TyphoeaArcheryDailyTrainCtrl', uiCtrl.UICtrl)

TyphoeaArcheryDailyTrainCtrl.m_archeryData = HL.Field(HL.Any)
TyphoeaArcheryDailyTrainCtrl.m_tabGroups = HL.Field(HL.Table)
TyphoeaArcheryDailyTrainCtrl.m_curSelectedTabIndex = HL.Field(HL.Number) << -1
TyphoeaArcheryDailyTrainCtrl.m_curSelectedDungeonId = HL.Field(HL.String) << ""
TyphoeaArcheryDailyTrainCtrl.m_curSelectedCell = HL.Field(HL.Any)
TyphoeaArcheryDailyTrainCtrl.m_rewardDetailCache = HL.Field(HL.Any)
TyphoeaArcheryDailyTrainCtrl.m_tabCells = HL.Field(HL.Table)
TyphoeaArcheryDailyTrainCtrl.m_level2DungeonId = HL.Field(HL.Table)

local popupRank = {
    higherLevel = 1,
    noChip = 2,
    canEnter = 3,
}

local floorRankValueConverter = function(value)
    return math.floor(value / 1000)
end





TyphoeaArcheryDailyTrainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_TYPHOEA_ARCHERY_ENTER_NEW_DAY] = '_OnNewDayRefresh', 
    [MessageConst.ON_TYPHOEA_ARCHERY_DAILY_TRAINING_REWARD] = '_UpdateDailyTrain', 
    [MessageConst.ON_TYPHOEA_ARCHERY_DAILY_AFFIX_UPDATE] = '_UpdateDailyTrain', 
    [MessageConst.ON_TYPHOEA_ARCHERY_CHIP_SET_CHANGED] = '_OnRefreshChip', 
}


TyphoeaArcheryDailyTrainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs(true)
end

TyphoeaArcheryDailyTrainCtrl.OnShow = HL.Override() << function(self)
    TyphoeaArcheryUtils.setNewDayRead()
    if DeviceInfo.usingController then
        self:SetNaviTarget(self.m_tabCells[self.m_curSelectedDungeonId].button)
    end
    
    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_curSelectedDungeonId)
    self.view.infoNode.chipSetWidget:InitArcheryChipSet(isLocked, chipIds, true)
    
    self.m_phase:UpdateSelectedDungeonId(self.m_curSelectedDungeonId)
    
    GameInstance.player.typhoeaArcherySystem:TyphoeaArcheryGetDailyAffix()
end

TyphoeaArcheryDailyTrainCtrl._InitUI = HL.Method() << function(self)
    
    self.view.infoNode.btnConfigureChip.onClick:AddListener(function()
        self.m_phase:ConfigureChip(self.m_curSelectedDungeonId)
    end)
    
    self.view.infoNode.btnDungeonEntry.onClick:AddListener(function()
        self:_EnterDungeonCheckPopup(popupRank.higherLevel)
    end)
    
    self.view.infoNode.btnEnemyDetail.onClick:AddListener(function()
        local _, dungeonId = system:GetDailyTrainDungeonId(self.m_curSelectedDungeonId)
        self.m_phase:OpenEnemyDetailsPopup(dungeonId)
    end)

    self.m_rewardDetailCache = UIUtils.genCellCache(self.view.infoNode.rewardDetailCell)
end


TyphoeaArcheryDailyTrainCtrl._EnterDungeonCheckPopup = HL.Method(HL.Number) << function(self, tipRank)
    
    
    if tipRank <= popupRank.higherLevel then
        if self.m_curSelectedTabIndex < self.m_archeryData.lv then
            local hasHigherLevelDungeonUnlocked = false
            for i = self.m_curSelectedTabIndex+1, self.m_archeryData.lv do
                if DungeonUtils.isDungeonUnlock(self.m_level2DungeonId[i]) then
                    hasHigherLevelDungeonUnlocked = true
                    break
                end
            end
            local higherLevelTipType = "higherLevel"
            local higherLevelNoTip = TyphoeaArcheryUtils.isNoTipToday(higherLevelTipType)
            if not higherLevelNoTip and hasHigherLevelDungeonUnlocked then
                Notify(MessageConst.SHOW_POP_UP, {
                    content = Language.LUA_TYPHOEA_ARCHERY_DAILY_HAS_HIGHER_LEVEL_POP_UP, 
                    onConfirm = function()
                        if higherLevelNoTip then
                            TyphoeaArcheryUtils.setNoTipToday(higherLevelTipType)
                        end
                        self:_EnterDungeonCheckPopup(tipRank+1)
                    end,
                    toggle = {
                        isOn = false,
                        onValueChanged = function(isOn)
                            higherLevelNoTip = isOn
                        end,
                        toggleText = Language.LUA_TYPHOEA_ARCHERY_NO_TIP_TODAY, 
                    },
                })
            else
                self:_EnterDungeonCheckPopup(tipRank+1)
            end
        else
            self:_EnterDungeonCheckPopup(tipRank+1)
        end
    
    elseif tipRank <= popupRank.noChip then
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
                        self:_EnterDungeonCheckPopup(tipRank+1)
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
                self:_EnterDungeonCheckPopup(tipRank+1)
            end
        else
            self:_EnterDungeonCheckPopup(tipRank+1)
        end
    
    else
        self:_EnterDungeon()
    end
end

TyphoeaArcheryDailyTrainCtrl._EnterDungeon = HL.Method() << function(self)
    
    local succ, dungeonId = system:GetDailyTrainDungeonId(self.m_curSelectedDungeonId)
    if not succ or string.isEmpty(dungeonId) then
        logger.error("选中的提丰靶场日常训练%s没有配置轮替的真实副本ID!!!", self.m_curSelectedDungeonId)
        dungeonId = self.m_curSelectedDungeonId
    end
    self.m_phase:EnterDungeon(dungeonId)
end

TyphoeaArcheryDailyTrainCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_archeryData = system.archeryData
    self.m_tabGroups = {}
    self.m_tabCells = {}
    self.m_level2DungeonId = {}

    local found = false
    for id,trainData in pairs(Tables.typhoeaArcheryDailyTrainTable) do
        local levelIndex = trainData.unlockLevel
        self.m_level2DungeonId[levelIndex] = id
        local cellName = string.format("levelStateCell%02d", levelIndex)
        self.m_tabGroups[levelIndex] = {
            id = id,
            cell = self.view.levelListNode[cellName]
        }

        if arg.dungeonId == id then
            found = true
            self.m_curSelectedTabIndex = levelIndex
            self.m_curSelectedDungeonId = id
        end
        
        if not found and levelIndex == self.m_archeryData.lv then
            self.m_curSelectedTabIndex = levelIndex
            self.m_curSelectedDungeonId = id
        end
    end
end

TyphoeaArcheryDailyTrainCtrl._UpdateData = HL.Method() << function(self)
    self.m_archeryData = system.archeryData
end

TyphoeaArcheryDailyTrainCtrl._RefreshAllUIs = HL.Method(HL.Boolean) << function(self, isInit)
    self:_RefreshTabs(isInit)
    self:_RefreshCommonInfo(isInit)
end

TyphoeaArcheryDailyTrainCtrl._RefreshTabs = HL.Method(HL.Boolean) << function(self, isInit)
    for i=1, self.m_archeryData.maxLv do
        local tabData = self.m_tabGroups[i]
        local dungeonId = tabData.id
        local cell = tabData.cell
        self.m_tabCells[dungeonId] = cell
        local isSelected = i == self.m_curSelectedTabIndex
        local isUnlock = i <= self.m_archeryData.lv
        self:_SetCellSelected(cell, isSelected)
        cell.stateController:SetState(isUnlock and "UnLock" or "Lock")
        
        cell.button.onClick:RemoveAllListeners()
        cell.button.onClick:AddListener(function()
            if not isUnlock then
                local lockTip = string.format(Language.LUA_TYPHOEA_ARCHERY_DAILY_TRAIN_LOCK_TOAST, i)
                Notify(MessageConst.SHOW_TOAST, lockTip)
            else
                self:_OnDungeonTabClick(cell, i, dungeonId)
            end
        end)
        
        for j=1, self.m_archeryData.perLevelStarCount do
            local starCell = cell.starLevelNode[string.format("starLevelCell%d",j)]
            local accumulatedStar = (i-1) * self.m_archeryData.perLevelStarCount + j
            local isCompleted = accumulatedStar <= self.m_archeryData.dailyStarCount
            starCell.stateController:SetState(isCompleted and "Full" or "Null")
        end
        
        if DeviceInfo.usingController then
            
            cell.button.interactable = isUnlock
        end
        cell.redDot:InitRedDot("TyphoeaArcheryDungeonReadNormal", {dungeonId})
    end
end

TyphoeaArcheryDailyTrainCtrl._SetCellSelected = HL.Method(HL.Any, HL.Boolean) << function(self, cell, isSelected)
    cell.stateController:SetState(isSelected and "Select" or "Normal")
    if isSelected then
        self.m_curSelectedCell = cell
        
        for i=1, self.m_archeryData.maxLv do
            local lowCell = self.m_tabGroups[i].cell
            for j=1, self.m_archeryData.perLevelStarCount do
                local starCell = lowCell.starLevelNode[string.format("starLevelCell%d",j)]
                local accumulatedStar = (i-1) * self.m_archeryData.perLevelStarCount + j
                local isCompleted = accumulatedStar <= self.m_archeryData.dailyStarCount
                local canPreview = i < self.m_curSelectedTabIndex
                starCell.stateController:SetState(isCompleted and "Full" or (canPreview and "Preview" or "Null"))
            end
        end
        
        GameInstance.player.subGameSys:SendReadSubGames({ self.m_curSelectedDungeonId })
    end
end

TyphoeaArcheryDailyTrainCtrl._OnDungeonTabClick = HL.Method(HL.Any, HL.Number, HL.String) << function(self, cell, tabIndex, dungeonId)
    if self.m_curSelectedTabIndex == tabIndex then
        return
    end

    
    self.view.infoNode.animationWrapper:PlayInAnimation()
    cell.animationNode:PlayInAnimation()

    local preCell = self.m_curSelectedCell
    self.m_curSelectedCell = cell
    self.m_curSelectedDungeonId = dungeonId
    self.m_curSelectedTabIndex = tabIndex

    self:_SetCellSelected(preCell, false)
    self:_SetCellSelected(cell, true)

    self:_RefreshCommonInfo(false)
    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_curSelectedDungeonId)
    self.view.infoNode.chipSetWidget:InitArcheryChipSet(isLocked, chipIds, true)

    self.m_phase:UpdateSelectedDungeonId(self.m_curSelectedDungeonId)
end


TyphoeaArcheryDailyTrainCtrl._RefreshCommonInfo = HL.Method(HL.Boolean) << function(self, isInit)
    local _, trainData = Tables.typhoeaArcheryDailyTrainTable:TryGetValue(self.m_curSelectedDungeonId)
    local _, gameId = system:GetDailyTrainDungeonId(self.m_curSelectedDungeonId)

    
    self.view.infoNode.dungeonTitleTxt.text = trainData.levelName
    local _, affixCombinationId = system:TryGetDailyTrainAffixCombinationId(self.m_curSelectedDungeonId)
    if affixCombinationId ~= nil then
        local _, affixData = Tables.typhoeaShootingRangeAffixCombinationTable:TryGetValue(affixCombinationId)
        for i=0, #affixData.affixIds - 1 do
            local affixId = affixData.affixIds[i]
            local _, affixCfg = Tables.typhoeaShootingRangeAffixTable:TryGetValue(affixId)
            if affixCfg then
                if i == 0 then
                    self.view.infoNode.positiveAffix.levelDetailTxt.text = affixCfg.affixDesc
                else
                    self.view.infoNode.negativeAffix.levelDetailTxt.text = affixCfg.affixDesc
                end
            end
        end
        self.view.infoNode.negativeAffix.gameObject:SetActive(#affixData.affixIds > 1)
    end
    
    local descText = trainData.unlockLevel == self.m_archeryData.maxLv and Language["ui_archery_daily_train_refresh_tips_04"] or Language["ui_archery_daily_train_refresh_tips"]
    self.view.infoNode.dailyDescTxt:SetAndResolveTextStyle(descText)
    
    self.m_rewardDetailCache:Refresh(self.m_archeryData.perLevelStarCount, function(cell, index)
        
        local accumulatedStar = (self.m_curSelectedTabIndex-1) * self.m_archeryData.perLevelStarCount + index
        local isCompleted = accumulatedStar <= self.m_archeryData.dailyStarCount
        cell.stateController:SetState(isCompleted and "Finish" or "UnFinish")
        
        local _, result = GameWorld.subGameManager:TryGetExtraTaskExtraInfo(gameId, CSIndex(index))
        if result.useSingleDescription then
            cell.rewardDetailTxt.text = result.singleDescription:GetText()
        else
            for _, aim in cs_pairs(result.trackingInfoDict) do
                cell.rewardDetailTxt.text = aim.description:GetText()
                break
            end
        end
    end)
    
    if not DungeonUtils.isDungeonUnlock(self.m_curSelectedDungeonId) then
        self.view.infoNode.btnStateController:SetState("Lock")
        local unCompletedConditions = DungeonUtils.getUncompletedConditionIds(self.m_curSelectedDungeonId)
        table.sort(unCompletedConditions)
        if #unCompletedConditions > 0 then
            local conditionId = unCompletedConditions[1]
            local _, conditionCfg = Tables.gameMechanicConditionTable:TryGetValue(conditionId)
            self.view.infoNode.lockedTxt.text = conditionCfg.desc
        end
    else
        self.view.infoNode.btnStateController:SetState("UnLock")
    end
    
    local rankListNode = self.view.infoNode.rankingListNode
    local showRankList = not string.isEmpty(trainData.rankListId)
    rankListNode.gameObject:SetActive(showRankList)
    if showRankList then
        local _, selfRecord = GameInstance.player.commonRankSystem:TryGetSelfValue(trainData.rankListId)
        rankListNode.bestToDayTimeTxt.text = selfRecord>0 and UIUtils.getLeftTimeToSecond(floorRankValueConverter(selfRecord)) or "--:--"
        rankListNode.friendRecordsBtn.onClick:RemoveAllListeners()
        rankListNode.friendRecordsBtn.onClick:AddListener(function()
            local _, rankRelatedId = Tables.TyphoeaArcheryDailyLevelId2RankId:TryGetValue(gameId)
            PhaseManager:OpenPhase(PhaseId.CommonRanking, {
                rankListId = trainData.rankListId,
                rankRelatedId = rankRelatedId,
            })
        end)
    end
end

TyphoeaArcheryDailyTrainCtrl._OnRefreshChip = HL.Method( HL.Table) << function(self, arg)
    if arg.dungeonId ~= self.m_curSelectedDungeonId then
        return
    end
    
    self.view.infoNode.chipSetWidget:InitArcheryChipSet( arg.isLocked, arg.chipIds, false)
end

TyphoeaArcheryDailyTrainCtrl._UpdateDailyTrain = HL.Method() << function(self)
    self:_UpdateData()
    self:_RefreshAllUIs(false)
end

TyphoeaArcheryDailyTrainCtrl._OnNewDayRefresh = HL.Method() << function(self)
    
    Notify(MessageConst.SHOW_TOAST, Language.LUA_TYPHOEA_ARCHERY_DAILY_TRAIN_UPDATE_TOAST)
    
    GameInstance.player.typhoeaArcherySystem:TyphoeaArcheryGetDailyAffix()
end

HL.Commit(TyphoeaArcheryDailyTrainCtrl)
