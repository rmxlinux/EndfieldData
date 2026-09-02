local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonWulingParkourEntry
local PHASE_ID = PhaseId.DungeonWulingParkourEntry



local PARKOUR_DUNGEON_QUEST_GATE = {
    ["dung02_rcdg002"] = "a1m15_q#5",
    ["dung02_rcdg004"] = "a1m15_q#11",
    ["dung02_rcdg003"] = "a1m15_q#16",
}

DungeonWulingParkourEntryCtrl = HL.Class('DungeonWulingParkourEntryCtrl', uiCtrl.UICtrl)






DungeonWulingParkourEntryCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = '_OnActivityUpdated',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
}

DungeonWulingParkourEntryCtrl.m_rightStarCells = HL.Field(HL.Any) << nil


DungeonWulingParkourEntryCtrl.m_luaIndex2Cell = HL.Field(HL.Table) << nil

DungeonWulingParkourEntryCtrl.m_luaIndex2starCell = HL.Field(HL.Table) << nil


DungeonWulingParkourEntryCtrl.m_luaIndex2DungeonId = HL.Field(HL.Table) << nil

DungeonWulingParkourEntryCtrl.m_luaIndex2ActivityState = HL.Field(HL.Table) << nil
DungeonWulingParkourEntryCtrl.m_luaIndex2ActivityLeftTime = HL.Field(HL.Table) << nil


DungeonWulingParkourEntryCtrl.m_activityId = HL.Field(HL.String) << ""

DungeonWulingParkourEntryCtrl.m_activityData = HL.Field(HL.Any)

DungeonWulingParkourEntryCtrl.m_activityDungeonData = HL.Field(HL.Any)

DungeonWulingParkourEntryCtrl.m_selectedCellIndex = HL.Field(HL.Number) << -1


DungeonWulingParkourEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.m_activityId = Cfg.Tables.ParkourConst.parkourActivityId
    self.m_activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local recoverState = arg and arg.recoverState or nil
    local _, activityDungeonData = Tables.ActivityDungeonTable:TryGetValue(self.m_activityId)
    self.m_activityDungeonData = activityDungeonData
    self.m_luaIndex2ActivityState = {}
    self.m_luaIndex2ActivityLeftTime = {}
    self.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, Cfg.Tables.ParkourConst.mainPanelInstructionId)
    end)
    self.view.milestoneLevelNode.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.WulingParkourMilestonePopup, { activityId = self.m_activityId})
    end)

    self.m_rightStarCells = UIUtils.genCellCache(self.view.starIconNode)
    self:InitAllDungeonNodeInfo()        

    
    local _, achievementData = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    if achievementData then
        self.view.dungeonMedalCell:InitCommonMedalNode(achievementData.achievementId)
    end

    self.view.dungeonActivityInfo:InitDungeonCommonInfo({
        customRewardDetailsClickFun = function()
            self:_OpenChallengeGoalPopup()
        end,
        
        enterDungeonCallback = function()
            local dungeonId = self.m_luaIndex2DungeonId[self.m_selectedCellIndex]
            local activityId = self.m_activityId
            LuaSystemManager.uiRestoreSystem:AddRequest(dungeonId, function()
                if not GameInstance.player.activitySystem:GetActivity(activityId) then
                    return false
                end
                local modeType = GameInstance.mode.modeType
                return modeType == GEnums.GameModeType.Default or modeType == GEnums.GameModeType.SpaceShip
            end)
            self:_CloseMusicPanelsOnEnterDungeon()
        end,
    })

    self:RefreshAllUIs(true)
    if recoverState then
        self:_TryRecoverState(recoverState)
        arg.recoverState = nil
    end
    
    ActivityUtils.backToMainHudWhenActivityClosed(self, self.m_activityId)
end

DungeonWulingParkourEntryCtrl.RefreshAllUIs = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    self.m_activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    
    if not self.m_activityData then
        return
    end
    self:RefreshMilestoneLevelInfo(isInit)
    for luaIndex, cell in pairs(self.m_luaIndex2Cell) do
        self:RefreshDungeonCell(luaIndex, cell, isInit)
    end

    if isInit then
        
        local initLuaIndex = self:_GetLastPlayableLuaIndex()
        self:SelectedDungeonByLuaIndex(initLuaIndex)
        if DeviceInfo.usingController then
            local cell = self.m_luaIndex2Cell[initLuaIndex]
            self:SetNaviTarget(cell.clickBtn)
        end
    elseif self.m_selectedCellIndex > 0 then
        
        self:SelectedDungeonByLuaIndex(self.m_selectedCellIndex, true)
    end
end


DungeonWulingParkourEntryCtrl._GetLastPlayableLuaIndex = HL.Method().Return(HL.Number) << function(self)
    local lastPlayableLuaIndex = 1
    for luaIndex = 1, #self.m_luaIndex2DungeonId do
        if self.m_luaIndex2ActivityState[luaIndex] == "Normal" then
            lastPlayableLuaIndex = luaIndex
        end
    end
    return lastPlayableLuaIndex
end

DungeonWulingParkourEntryCtrl.RefreshMilestoneLevelInfo = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local milestoneConfig, level = ActivityUtils.getActivityMilestoneInfo(self.m_activityId)
    self.view.milestoneLevelNumber.text = level
    if isInit then
        self.view.milestoneRedDot:InitRedDot("ActivityParkourMilestone", self.m_activityId)
    end
end


DungeonWulingParkourEntryCtrl.InitAllDungeonNodeInfo = HL.Method() << function(self)
    self.m_luaIndex2Cell = {}
    self.m_luaIndex2Cell[1] = self.view.dungeonNode1
    self.m_luaIndex2Cell[2] = self.view.dungeonNode2
    self.m_luaIndex2Cell[3] = self.view.dungeonNode3
    self.m_luaIndex2Cell[4] = self.view.dungeonNode4

    self.m_luaIndex2starCell = {}
    self.m_luaIndex2starCell[1] = UIUtils.genCellCache(self.view.dungeonNode1.starNode)
    self.m_luaIndex2starCell[2] = UIUtils.genCellCache(self.view.dungeonNode2.starNode)
    self.m_luaIndex2starCell[3] = UIUtils.genCellCache(self.view.dungeonNode3.starNode)
    self.m_luaIndex2starCell[4] = UIUtils.genCellCache(self.view.dungeonNode4.starNode)

    self.m_luaIndex2DungeonId = {}
    self.m_luaIndex2DungeonId[1] = "dung02_rcdg001"
    self.m_luaIndex2DungeonId[2] = "dung02_rcdg002"
    self.m_luaIndex2DungeonId[3] = "dung02_rcdg004"
    self.m_luaIndex2DungeonId[4] = "dung02_rcdg003"

    self:_SetupDungeonNodesNavi()
end





DungeonWulingParkourEntryCtrl._SetupDungeonNodesNavi = HL.Method() << function(self)
    local grid = {
        { 1, 2 },
        { 3, 4 },
    }
    local rows = #grid
    local cols = #grid[1]
    local indexToPos = {}
    for r = 1, rows do
        for c = 1, cols do
            indexToPos[grid[r][c]] = { r = r, c = c }
        end
    end

    local function getBtnByRC(r, c)
        r = (r - 1) % rows + 1
        c = (c - 1) % cols + 1
        return self.m_luaIndex2Cell[grid[r][c]].clickBtn
    end

    for luaIndex, pos in pairs(indexToPos) do
        local btn = self.m_luaIndex2Cell[luaIndex].clickBtn
        btn.useExplicitNaviSelect = true
        btn.banExplicitOnLeft = false
        btn.banExplicitOnRight = false
        btn.banExplicitOnUp = false
        btn.banExplicitOnDown = false
        
        btn:SetExplicitSelect(
            getBtnByRC(pos.r, pos.c - 1),
            getBtnByRC(pos.r, pos.c + 1),
            getBtnByRC(pos.r - 1, pos.c),
            getBtnByRC(pos.r + 1, pos.c)
        )
    end
end

DungeonWulingParkourEntryCtrl._OpenChallengeGoalPopup = HL.Method() << function(self)
    local dungeonId = self.m_luaIndex2DungeonId[self.m_selectedCellIndex]
    if string.isEmpty(dungeonId) then
        return
    end
    UIManager:AutoOpen(PanelId.WulingParkourChallengeGoalPopup, {
        dungeonId = dungeonId,
        activityId = self.m_activityId,
    })
end



DungeonWulingParkourEntryCtrl._ApplyDungeonQuestGate = HL.Method(HL.String) << function(self, dungeonId)
    local questId = PARKOUR_DUNGEON_QUEST_GATE[dungeonId]
    if string.isEmpty(questId) then
        return
    end
    if GameInstance.player.mission:IsQuestCompleted(questId) then
        return
    end

    local commonInfo = self.view.dungeonActivityInfo
    
    if commonInfo.view.jumpBtn.gameObject.activeSelf or commonInfo.view.lockedNode.gameObject.activeSelf then
        return
    end

    commonInfo.view.goToBattleBtn.gameObject:SetActive(false)
    commonInfo.view.claimRewardsBtn.gameObject:SetActive(false)
    commonInfo.view.rechallengeBtn.gameObject:SetActive(false)

    local missionId = GameInstance.player.mission:GetMissionIdByQuestId(questId)
    commonInfo.m_missionId = missionId or ""
    if not string.isEmpty(commonInfo.m_missionId) then
        commonInfo.view.jumpTxt.text = Language.LUA_ACTIVITY_PARKOUR_DUNGEON_QUEST_LOCK_JUMP_TEXT
        commonInfo.view.jumpBtn.onClick:RemoveAllListeners()
        commonInfo.view.jumpBtn.onClick:AddListener(function()
            PhaseManager:OpenPhase(PhaseId.Mission, { autoSelect = commonInfo.m_missionId })
        end)
        commonInfo.view.jumpBtn.gameObject:SetActive(true)
        commonInfo.view.lockedNode.gameObject:SetActive(false)
    else
        commonInfo.view.jumpBtn.gameObject:SetActive(false)
        commonInfo.view.lockedNode.gameObject:SetActive(true)
        commonInfo.view.lockedTxt.text = Language.LUA_ACTIVITY_PARKOUR_DUNGEON_QUEST_LOCK_HINT_TEXT
    end
end



DungeonWulingParkourEntryCtrl._CloseMusicPanelsOnEnterDungeon = HL.Method() << function(self)
    if PhaseManager:IsOpen(PhaseId.ActivityCenter) then
        PhaseManager:ExitPhaseFast(PhaseId.ActivityCenter)
    end
    if PhaseManager:IsOpen(PHASE_ID) then
        PhaseManager:ExitPhaseFast(PHASE_ID)
    end
end


DungeonWulingParkourEntryCtrl.RefreshDungeonCell = HL.Method(HL.Number, HL.Any, HL.Opt(HL.Boolean)) << function(self, luaIndex, cell, isInit)
    local dungeonId = self.m_luaIndex2DungeonId[luaIndex]

    if isInit then
        cell.stateController:SetState("Unselect")

        cell.clickBtn.onClick:RemoveAllListeners()
        cell.clickBtn.onClick:AddListener(function()
            self:SelectedDungeonByLuaIndex(luaIndex)
        end)

        
        local redDotArgs = {
            activityId = self.m_activityId,
            dungeonIds = {dungeonId},
        }
        cell.redDot:InitRedDot("ActivityParkourDungeonReadNormal", redDotArgs)
    end

    local succ, uiCfg = Tables.ParkourUiTable:TryGetValue(dungeonId)
    if succ then
        cell.nameTxt.text = uiCfg.areaName
    end

    local completedExtraTaskCount = GameInstance.player.parkourSystem:GetCompletedExtraTaskCountBySubGameId(dungeonId)
    self.m_luaIndex2starCell[luaIndex]:Refresh(3, function(startCell, starLuaIndex)
        startCell.stateController:SetState(starLuaIndex <= completedExtraTaskCount and "Yellow" or "Black")
    end)

    
    if self.m_activityDungeonData then
        local _, dungeonData = self.m_activityDungeonData.gameMap:TryGetValue(dungeonId)

        local isUnlock = false
        local relatedStageData = {}
        if string.isEmpty(dungeonData.gameUnlockStage) then
            isUnlock = true
        else
            relatedStageData = self.m_activityData:GetStageData(dungeonData.gameUnlockStage)
            if relatedStageData ~= nil then
                local status = GEnums.ActivityConditionalStageState.__CastFrom(relatedStageData.Status)
                isUnlock = status ~= GEnums.ActivityConditionalStageState.Locked
            end
        end


        if isUnlock then
            self.m_luaIndex2ActivityState[luaIndex] = "Normal"
            self.m_luaIndex2ActivityLeftTime[luaIndex] = nil
            cell.timeLockTxt:StopCountDown()
            cell.stateController:SetState("NameNormal")      
            cell.stateController:SetState("BuildNormal")      
            local currentNumber = GameInstance.player.parkourSystem:GetCollectNumberBySubGameId(dungeonId)
            if uiCfg then
                cell.bubbleNumberTxt.text = string.format(
                    Language.LUA_ACTIVITY_PARKOUR_MAIN_PANEL_LEVEL_BUBBLE_NUMBER, currentNumber,uiCfg.bubbleMaxNumber)
            end
        else
            local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
            local isTimeArrived = relatedStageData.OpenTimeTs - currentTime <= 0
            
            
            
            local hasFrontLock = isTimeArrived and GameInstance.player.activitySystem:HasUncompletedNonTimeConditions(dungeonData.gameUnlockStage)
            if hasFrontLock then
                self.m_luaIndex2ActivityState[luaIndex] = "FrontLock"
                self.m_luaIndex2ActivityLeftTime[luaIndex] = nil
                cell.timeLockTxt:StopCountDown()
                cell.stateController:SetState("FrontLock")
                cell.stateController:SetState("BuildNormal")
            else
                self.m_luaIndex2ActivityState[luaIndex] = "TimeLock"
                cell.stateController:SetState("TimeLock")
                cell.stateController:SetState("BuildLock")
                if isTimeArrived then
                    
                    local leftTimeText = string.format(Language.LUA_ACTIVITY_PARKOUR_DUNGEON_UNLOCK_TIME_TEXT, UIUtils.getLeftTime(0))
                    self.m_luaIndex2ActivityLeftTime[luaIndex] = leftTimeText
                    cell.timeLockTxt:StopCountDown()
                    cell.timeLockTxt.view.text:SetAndResolveTextStyle(leftTimeText)
                else
                    
                    cell.timeLockTxt:InitCountDownText(relatedStageData.OpenTimeTs, function()
                        self:RefreshAllUIs()
                    end, function(leftSec)
                        local leftTime = UIUtils.getLeftTime(leftSec)
                        self.m_luaIndex2ActivityLeftTime[luaIndex] = string.format(Language.LUA_ACTIVITY_PARKOUR_DUNGEON_UNLOCK_TIME_TEXT, leftTime)
                        if self.m_selectedCellIndex == luaIndex then
                            self.view.timeTxt.text = self.m_luaIndex2ActivityLeftTime[luaIndex]
                        end
                        return self.m_luaIndex2ActivityLeftTime[luaIndex]
                    end)
                end
            end
        end
    end
end

DungeonWulingParkourEntryCtrl.PlaySelectAnimation = HL.Method(HL.Any) << function(self, cell)
    if not cell or not cell.animationWrapper then
        return
    end

    local animationWrapper = cell.animationWrapper
    animationWrapper:PlayWithTween("wulingparkourmilestone_slc", function()
        animationWrapper:PlayWithTween("wulingparkourmilestone_slc_loop")
    end)
end

DungeonWulingParkourEntryCtrl.PlayUnselectAnimation = HL.Method(HL.Any) << function(self, cell)
    if not cell or not cell.animationWrapper then
        return
    end

    cell.animationWrapper:PlayWithTween("wulingparkourmilestone_slcout")
end

DungeonWulingParkourEntryCtrl.SelectedDungeonByLuaIndex = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, luaIndex, forceRefresh)
    if self.m_selectedCellIndex == luaIndex and not forceRefresh then
        return
    end

    local isSameSelection = self.m_selectedCellIndex == luaIndex
    local lastSelectedCellIndex = self.m_selectedCellIndex
    self.m_selectedCellIndex = luaIndex

    for checkLuaIndex, cell in pairs(self.m_luaIndex2Cell) do
        if luaIndex == checkLuaIndex then
            cell.stateController:SetState("Select")
        else
            cell.stateController:SetState("Unselect")
        end
    end

    if not isSameSelection then
        self:PlaySelectAnimation(self.m_luaIndex2Cell[luaIndex])
        local lastSelectedCell = lastSelectedCellIndex > 0 and self.m_luaIndex2Cell[lastSelectedCellIndex] or nil
        if lastSelectedCell then
            self:PlayUnselectAnimation(lastSelectedCell)
        end
    end

    local dungeonId = self.m_luaIndex2DungeonId[luaIndex]

    local succ, uiCfg = Tables.ParkourUiTable:TryGetValue(dungeonId)
    local completedExtraTaskCount = GameInstance.player.parkourSystem:GetCompletedExtraTaskCountBySubGameId(dungeonId)
    self.view.balloonProgressNode.gameObject:SetActive(true)
    self.view.targetProgressNode.gameObject:SetActive(true)
    self.m_rightStarCells:Refresh(3, function(startCell, starLuaIndex)
        startCell.stateController:SetState(starLuaIndex <= completedExtraTaskCount and "Yellow" or "Black")
    end)

    local state = self.m_luaIndex2ActivityState[luaIndex]
    if state == "TimeLock" then
        self.view.lockNode.gameObject:SetActive(true)
        self.view.dungeonActivityInfo.gameObject:SetActive(false)
        local leftTimeText = self.m_luaIndex2ActivityLeftTime[luaIndex]
        if not string.isEmpty(leftTimeText) then
            self.view.timeTxt.text = leftTimeText
        end
    else
        
        self.view.lockNode.gameObject:SetActive(false)
        self.view.dungeonActivityInfo.gameObject:SetActive(true)
        self.view.dungeonActivityInfo:RefreshDungeonActivityCommonInfo(dungeonId, self.m_activityId)
        self.view.dungeonActivityInfo.view.rewardNode.gameObject:SetActive(true)
        
        if uiCfg and not string.isEmpty(uiCfg.showRewardId) then
            self.view.dungeonActivityInfo:RefreshChallengeRewardPreview(uiCfg.showRewardId, completedExtraTaskCount >= 3)
        end
        self:_ApplyDungeonQuestGate(dungeonId)
    end


    self.view.goToBattleBtn.onClick:RemoveAllListeners()
    self.view.goToBattleBtn.onClick:AddListener(function()
        self.view.dungeonActivityInfo:_OnBtnDungeonEntryClick()
    end)


    local currentNumber = GameInstance.player.parkourSystem:GetCollectNumberBySubGameId(dungeonId)
    if uiCfg then
        self.view.progressTxt.text = string.format(
            Language.LUA_ACTIVITY_PARKOUR_MAIN_PANEL_LEVEL_BUBBLE_NUMBER, currentNumber,uiCfg.bubbleMaxNumber)
        self.view.objectText.text = uiCfg.challengeGoalText
    end

    
    if not forceRefresh and state ~= "TimeLock" then
        GameInstance.player.subGameSys:SendReadSubGames({ dungeonId })
    end

end

DungeonWulingParkourEntryCtrl._TryRecoverState = HL.Method(HL.Table) << function(self, recoverState)
    local selectedCellIndex = type(recoverState.selectedCellIndex) == "number" and recoverState.selectedCellIndex or -1
    local targetCell = self.m_luaIndex2Cell and self.m_luaIndex2Cell[selectedCellIndex] or nil
    if targetCell == nil then
        return
    end

    self:SelectedDungeonByLuaIndex(selectedCellIndex)
    if DeviceInfo.usingController then
        self:SetNaviTarget(targetCell.clickBtn)
    end
end

DungeonWulingParkourEntryCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if self.m_selectedCellIndex <= 0 or self.m_luaIndex2Cell == nil or self.m_luaIndex2Cell[self.m_selectedCellIndex] == nil then
        return nil
    end

    return {
        recoverState = {
            selectedCellIndex = self.m_selectedCellIndex,
        }
    }
end

DungeonWulingParkourEntryCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    
    if not GameInstance.player.activitySystem:GetActivity(self.m_activityId) then
        return
    end
    self:RefreshAllUIs()
end



HL.Commit(DungeonWulingParkourEntryCtrl)
