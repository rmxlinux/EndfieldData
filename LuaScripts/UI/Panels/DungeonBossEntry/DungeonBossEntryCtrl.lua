local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonBossEntry

local BOSS_COUNT = 2
local QUICK_SELECT_FORBIDDEN_TYPE = "DungeonBossEntryQuickSelect"
local PROGRESS_ANIMATION = "dungeonbossentry_unlock_in"
local BOSS_PROGRESS_BLOCK_INPUT_REASON = "BossProgress"

DungeonBossEntryCtrl = HL.Class('DungeonBossEntryCtrl', uiCtrl.UICtrl)

DungeonBossEntryCtrl.m_arg = HL.Field(HL.Table)
DungeonBossEntryCtrl.m_highDifficultyId = HL.Field(HL.String) << ""
DungeonBossEntryCtrl.m_seriesId = HL.Field(HL.String) << ""
DungeonBossEntryCtrl.m_bossGroupId = HL.Field(HL.String) << ""
DungeonBossEntryCtrl.m_curSelectedDungeonId = HL.Field(HL.String) << ""
DungeonBossEntryCtrl.m_bossGroupIds = HL.Field(HL.Table)
DungeonBossEntryCtrl.m_bossCellSlots = HL.Field(HL.Table)
DungeonBossEntryCtrl.m_bossGameIds = HL.Field(HL.Table)
DungeonBossEntryCtrl.m_bossCells = HL.Field(HL.Table)
DungeonBossEntryCtrl.m_difficultySelectCellCache = HL.Field(HL.Any)
DungeonBossEntryCtrl.m_difficultySelectCellTemplate = HL.Field(HL.Any)
DungeonBossEntryCtrl.m_fromDialog = HL.Field(HL.Boolean) << false
DungeonBossEntryCtrl.m_playingProgressAnimation = HL.Field(HL.Boolean) << false
DungeonBossEntryCtrl.m_settlementEnteredGameId = HL.Field(HL.String) << ""
local highDifficultySystem = GameInstance.player.highDifficultySystem

local function _isBossGroupDisplayUnlocked(bossGroupId)
    if string.isEmpty(bossGroupId) then
        return false
    end
    return highDifficultySystem:IsBossGroupUnlocked(bossGroupId)
end






DungeonBossEntryCtrl.s_messages = HL.StaticField(HL.Table) << {
}


DungeonBossEntryCtrl.RecordBossDungeonStart = HL.StaticMethod(HL.Any) << function(args)
    local dungeonId = unpack(args)
    local system = GameInstance.player.highDifficultySystem
    if string.isEmpty(system:GetBossGroupIdByGameId(dungeonId))
        or system.lastEnteredBossDungeonId == dungeonId then
        return
    end
    system.lastEnteredBossDungeonId = dungeonId
    system.bossProgressCandidateGameId = ""
    system.newUnlockedBossGameIds:Clear()
    
    local bossGroupId = system:GetBossGroupIdByGameId(dungeonId)
    local gameIds = system:GetBossGameIds(bossGroupId)
    for i = gameIds.Count - 1, 0, -1 do
        local gameId = gameIds[i]
        if system:IsBossGamePassed(gameId) then
            return
        end
        if gameId == dungeonId then
            system.bossProgressCandidateGameId = gameId
            return
        end
    end
end

DungeonBossEntryCtrl.RecordBossGameUnlock = HL.StaticMethod(HL.Any) << function(args)
    local system = GameInstance.player.highDifficultySystem
    local dungeonId = system.lastEnteredBossDungeonId
    if string.isEmpty(dungeonId) then
        return
    end
    local gameId = unpack(args)
    local bossGroupId = system:GetBossGroupIdByGameId(dungeonId)
    if gameId ~= dungeonId and system:GetBossGroupIdByGameId(gameId) == bossGroupId
        and system:IsBossGameUnlocked(gameId) then
        system.newUnlockedBossGameIds:Add(gameId)
    end
end


DungeonBossEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    arg = arg or {}
    self.m_arg = arg
    self.m_fromDialog = arg.fromDialog or false
    self.m_bossGroupIds = {}
    self.m_bossGameIds = {}
    self.m_bossCells = {}
    self.m_bossCellSlots = {
        self.view.bossInfoCell1,
        self.view.bossInfoCell2,
    }
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.m_seriesId = arg.dungeonSeriesId
    self.m_highDifficultyId = HighDifficultyUtils.GetHighDifficultyId(self.m_seriesId)
    self:_InitDungeonSeriesInfo()

    self.m_difficultySelectCellCache, self.m_difficultySelectCellTemplate = self:_CreateCellCache(
        UIConst.UI_DIFFICULTY_SELECT_CELL_PREFAB_PATH, self.view.difficaultySelecListRoot)

    self.view.dungeonBossInfo:InitDungeonBossInfo(self.m_arg)

    self:_RefreshBossGroupIds()
    self:_ResolveInitialSelection()
    
    if HighDifficultyUtils.isNewHighDifficultyBoss(self.m_bossGroupId) then
        HighDifficultyUtils.setFalseNewHighDifficultyBoss(self.m_bossGroupId)
    end

    self:BindInputPlayerAction(self.view.leftKeyHint.actionId, function()
        self:_SelectDifficultyByOffset(-1)
    end)
    self:BindInputPlayerAction(self.view.rightKeyHint.actionId, function()
        self:_SelectDifficultyByOffset(1)
    end)

    self:_RefreshAll()
    self:_InitController()

    
    if GameInstance.dungeonManager.inDungeon then
        PhaseManager:AddPhaseForbiddenOverrideConfig(QUICK_SELECT_FORBIDDEN_TYPE, {
            [PhaseId.CharFormation] = {
                forbid = false,
            },
        })
    end

    CS.Beyond.Gameplay.Conditions.OnDungeonCommonEntryPanelOpen.Trigger(self.m_seriesId, false)
end

DungeonBossEntryCtrl.OnAnimationInFinished = HL.Override() << function(self)
    CS.Beyond.Gameplay.Conditions.OnDungeonCommonEntryPanelOpen.Trigger(self.m_seriesId, true)
end

DungeonBossEntryCtrl.OnShow = HL.Override() << function(self)
    self:_UpdateNaviTarget()
    self:_TryPlayBossProgressAnimation()
end

DungeonBossEntryCtrl.OnHide = HL.Override() << function(self)
    self:_ClearBossProgressState()
end

DungeonBossEntryCtrl._OnPlayAnimationOut = HL.Override() << function(self)
    self:_ClearBossProgressState(false)
end

DungeonBossEntryCtrl.OnClose = HL.Override() << function(self)
    self:_ClearBossProgressState()
    PhaseManager:RemovePhaseForbiddenOverrideConfig(QUICK_SELECT_FORBIDDEN_TYPE)
    self.m_difficultySelectCellCache:ClearAll()
    GameObject.Destroy(self.m_difficultySelectCellTemplate.gameObject)
    UIManager:Close(PanelId.CommonEnemyPopup)
end




DungeonBossEntryCtrl._InitDungeonSeriesInfo = HL.Method() << function(self)
    self.view.titleTxt.text = HighDifficultyUtils.GetHighDifficultyName(self.m_seriesId)
    self.view.dungeonMedalCell:InitCommonMedalNode(HighDifficultyUtils.GetHighDifficultyAchieveId(self.m_seriesId))
end

DungeonBossEntryCtrl._CreateCellCache = HL.Method(HL.String, HL.Any).Return(HL.Any, HL.Any)
    << function(self, prefabPath, parent)
    local prefab = self:LoadGameObject(prefabPath)
    local templateObj = CSUtils.CreateObject(prefab, parent)
    local template = Utils.wrapLuaNode(templateObj)
    return UIUtils.genCellCache(template), template
end

DungeonBossEntryCtrl._RefreshBossGroupIds = HL.Method() << function(self)
    self.m_bossGroupIds = {}
    local csGroupIds = HighDifficultyUtils.GetBossProgressionBossGroupIds(self.m_highDifficultyId)
    for i = 1, csGroupIds.Count do
        self.m_bossGroupIds[i] = csGroupIds[CSIndex(i)]
    end
end


DungeonBossEntryCtrl._ResolveInitialSelection = HL.Method() << function(self)
    
    
    
    
    
    
    
    
    if not string.isEmpty(self.m_arg.dungeonId) then
        self.m_bossGroupId = highDifficultySystem:GetBossGroupIdByGameId(self.m_arg.dungeonId)
        self.m_curSelectedDungeonId = self.m_arg.dungeonId
        return
    end

    local lastEnteredGameId = highDifficultySystem.lastEnteredBossDungeonId
    if not string.isEmpty(lastEnteredGameId) then
        local lastEnteredBossGroupId = highDifficultySystem:GetBossGroupIdByGameId(lastEnteredGameId)
        if highDifficultySystem:IsBossGroupInHighDifficulty(lastEnteredBossGroupId, self.m_highDifficultyId) then
            self.m_bossGroupId = lastEnteredBossGroupId
            if highDifficultySystem:IsBossGroupAllPassed(lastEnteredBossGroupId) then
                self.m_curSelectedDungeonId = self:_FindDefaultGameId(lastEnteredBossGroupId)
            elseif highDifficultySystem:IsBossGamePassed(lastEnteredGameId)
                and not string.isEmpty(highDifficultySystem.bossProgressCandidateGameId) then
                self.m_curSelectedDungeonId = self:_FindDefaultGameId(lastEnteredBossGroupId)
            else
                self.m_curSelectedDungeonId = lastEnteredGameId
            end
            self.m_settlementEnteredGameId = lastEnteredGameId
            highDifficultySystem.lastEnteredBossDungeonId = ""
            return
        end
    end

    local allBossesAllPassed = #self.m_bossGroupIds > 0
    local lastBossGroupId = ""
    local firstIncompleteBossGroupId = ""
    for _, bossGroupId in ipairs(self.m_bossGroupIds) do
        if not string.isEmpty(bossGroupId) then
            lastBossGroupId = bossGroupId
            local unlocked = _isBossGroupDisplayUnlocked(bossGroupId)
            local allPassed = unlocked and highDifficultySystem:IsBossGroupAllPassed(bossGroupId)
            if not allPassed then
                allBossesAllPassed = false
                if unlocked and string.isEmpty(firstIncompleteBossGroupId) then
                    firstIncompleteBossGroupId = bossGroupId
                end
            end
        end
    end

    if allBossesAllPassed then
        self.m_bossGroupId = lastBossGroupId
    else
        self.m_bossGroupId = firstIncompleteBossGroupId
        if string.isEmpty(self.m_bossGroupId) then
            for _, bossGroupId in ipairs(self.m_bossGroupIds) do
                if _isBossGroupDisplayUnlocked(bossGroupId) then
                    self.m_bossGroupId = bossGroupId
                    break
                end
            end
        end
    end
    self.m_curSelectedDungeonId = self:_FindDefaultGameId(self.m_bossGroupId)
end

DungeonBossEntryCtrl._FindDefaultGameId = HL.Method(HL.String).Return(HL.String) << function(self, bossGroupId)
    local gameIds = highDifficultySystem:GetBossGameIds(bossGroupId)
    if gameIds == nil or gameIds.Count <= 0 then
        return ""
    end

    local firstGameId = gameIds[CSIndex(1)]
    if not _isBossGroupDisplayUnlocked(bossGroupId) then
        logger.error("DungeonBossEntryCtrl._FindDefaultGameId Boss未解锁，不应尝试选择关卡，bossGroupId=", bossGroupId)
        return ""
    end

    local lowestUnlockedUnpassedGameId = ""
    local highestUnlockedGameId = ""

    for i = 1, gameIds.Count do
        local gameId = gameIds[CSIndex(i)]
        if highDifficultySystem:IsBossGameUnlocked(gameId) then
            if string.isEmpty(lowestUnlockedUnpassedGameId) and not highDifficultySystem:IsBossGamePassed(gameId) then
                lowestUnlockedUnpassedGameId = gameId
            end
            highestUnlockedGameId = gameId
        end
    end

    if not string.isEmpty(lowestUnlockedUnpassedGameId) then
        return lowestUnlockedUnpassedGameId
    end
    if not string.isEmpty(highestUnlockedGameId) then
        return highestUnlockedGameId
    end
    return firstGameId
end

DungeonBossEntryCtrl._RefreshAll = HL.Method() << function(self)
    self:_RefreshBossCells()
    self:_RefreshDifficultyCells()
    self:_UpdateNaviTarget()
    self:_RefreshBossInfo()
end

DungeonBossEntryCtrl._RefreshBossCells = HL.Method() << function(self)
    self.m_bossCells = {}
    for index = 1, BOSS_COUNT do
        local bossGroupId = self.m_bossGroupIds[index]
        local bossCell = self.m_bossCellSlots[index]
        local hasBoss = not string.isEmpty(bossGroupId)
        bossCell.gameObject:SetActive(hasBoss)
        if hasBoss then
            self.m_bossCells[bossGroupId] = bossCell
            bossCell:InitBossInfoCell(bossGroupId, self.m_curSelectedDungeonId, function()
                self:_OnBossCellClick(bossGroupId)
            end)
        end
    end
end

DungeonBossEntryCtrl._RefreshDifficultyCells = HL.Method() << function(self)
    self.m_bossGameIds = {}
    if string.isEmpty(self.m_bossGroupId) then
        if self.m_difficultySelectCellCache then
            self.m_difficultySelectCellCache:Refresh(0, function()
            end)
        end
        self:_RefreshDifficultySwitchKeyHints()
        self:_RefreshDifficultySelectLayout()
        return
    end

    local bossGameIds = highDifficultySystem:GetBossGameIds(self.m_bossGroupId)
    for i = 1, bossGameIds.Count do
        table.insert(self.m_bossGameIds, bossGameIds[CSIndex(i)])
    end

    self:_RefreshDifficultySwitchKeyHints()
    if self.m_difficultySelectCellCache then
        local canSelectLocked = _isBossGroupDisplayUnlocked(self.m_bossGroupId)
        self.m_difficultySelectCellCache:Refresh(#self.m_bossGameIds, function(cell, luaIndex)
            local gameId = self.m_bossGameIds[luaIndex]
            cell:InitDiffcaultySelectCell(gameId, function()
                self:_OnDifficultyCellClick(gameId)
            end, canSelectLocked)

            cell.view.cellTypeController:SetState(self.m_curSelectedDungeonId == gameId and "Selected" or "UnSelected")
        end)
    end
    self:_RefreshDifficultySelectLayout()
end

DungeonBossEntryCtrl._RefreshDifficultySwitchKeyHints = HL.Method() << function(self)
    local active = #self.m_bossGameIds > 1
    self.view.leftKeyHint.gameObject:SetActive(active)
    self.view.rightKeyHint.gameObject:SetActive(active)
end

DungeonBossEntryCtrl._RefreshDifficultySelectLayout = HL.Method() << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.difficaultySelecListRoot)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.difficaultySelectLayout.transform)
end

DungeonBossEntryCtrl._RefreshBossInfo = HL.Method() << function(self)
    if self.view.dungeonBossInfo then
        self.view.dungeonBossInfo:RefreshDungeonBossInfo(self.m_curSelectedDungeonId)
    end
    if not string.isEmpty(self.m_curSelectedDungeonId) then
        local dungeonCfg = Tables.dungeonTable[self.m_curSelectedDungeonId]
        self.view.dungeonBG:LoadSprite(UIConst.UI_SPRITE_DUNGEON, dungeonCfg.dungeonPicPath)
        self.view.maskImg:LoadSprite(UIConst.UI_SPRITE_DUNGEON, dungeonCfg.dungeonPicPath .. "_bg")
    end
end



DungeonBossEntryCtrl._TryPlayBossProgressAnimation = HL.Method() << function(self)
    if self.m_isClosed or self.m_playingProgressAnimation or not self:IsShow() then
        return
    end
    local wrapper = self.animationWrapper
    if wrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
        return
    end
    self.view.dungeonBossInfo.view.canvasGroup.alpha = 1
    local system = GameInstance.player.highDifficultySystem
    local enteredGameId = self.m_settlementEnteredGameId
    self.m_settlementEnteredGameId = ""
    if string.isEmpty(enteredGameId) then
        return
    end
    local bossGroupId = system:GetBossGroupIdByGameId(enteredGameId)
    if not system:IsBossGroupInHighDifficulty(bossGroupId, self.m_highDifficultyId) then
        return
    end
    local passedGameId = system.bossProgressCandidateGameId
    local hasNewHighestPass = not string.isEmpty(passedGameId) and system:IsBossGamePassed(passedGameId)
    local unlockedGameIds = {}
    local bossGameIds = system:GetBossGameIds(bossGroupId)
    for i = 0, bossGameIds.Count - 1 do
        local gameId = bossGameIds[i]
        if system.newUnlockedBossGameIds:Contains(gameId) and system:IsBossGameUnlocked(gameId) then
            table.insert(unlockedGameIds, { gameId = gameId, index = LuaIndex(i) })
        end
    end
    if not hasNewHighestPass and #unlockedGameIds == 0 then
        return
    end

    self:_RefreshAll()
    self.m_playingProgressAnimation = true

    if wrapper.curState == CS.Beyond.UI.UIConst.AnimationState.In then
        wrapper:SkipInAnimation()
    elseif wrapper.curState == CS.Beyond.UI.UIConst.AnimationState.InEasing then
        wrapper:SampleClipAtPercent(wrapper.animationInEasing.name, 1)
    end
    if not self.m_playingProgressAnimation then
        return
    end
    self.view.luaPanel:BlockAllInput(BOSS_PROGRESS_BLOCK_INPUT_REASON)
    local playCellAnimations = function()
        if not self.m_playingProgressAnimation then
            return
        end
        self.view.dungeonBossInfo.view.canvasGroup.alpha = 1
        if hasNewHighestPass then
            self.view.bossInfoAnimation:PlayInAnimation()
        end
        system.bossProgressCandidateGameId = ""
        system.newUnlockedBossGameIds:Clear()
        local remainingCount = #unlockedGameIds + (hasNewHighestPass and 1 or 0)
        local onCellComplete = function()
            if not self.m_playingProgressAnimation then
                return
            end
            remainingCount = remainingCount - 1
            if remainingCount == 0 then
                self:_ClearBossProgressState()
            end
        end
        if hasNewHighestPass then
            self.m_bossCells[bossGroupId]:PlayLevelProgressAnimation(passedGameId, onCellComplete)
        end
        for _, unlocked in ipairs(unlockedGameIds) do
            self.m_difficultySelectCellCache:GetItem(unlocked.index):PlayUnlockAnimation(onCellComplete)
        end
    end
    if hasNewHighestPass then
        self.view.progressDifficultyTxt.text = system:GetBossGameDifficultyName(passedGameId)
        self.view.dungeonBossInfo.view.canvasGroup.alpha = 0
        wrapper:PlayWithTween(PROGRESS_ANIMATION, playCellAnimations)
    else
        playCellAnimations()
    end
end


DungeonBossEntryCtrl._ClearBossProgressState = HL.Method(HL.Opt(HL.Boolean)) << function(self, recoverInput)
    self.view.dungeonBossInfo.view.canvasGroup.alpha = 1
    if not self.m_playingProgressAnimation then
        return
    end
    self.m_playingProgressAnimation = false
    local system = GameInstance.player.highDifficultySystem
    system.bossProgressCandidateGameId = ""
    system.newUnlockedBossGameIds:Clear()
    if recoverInput ~= false then
        self.view.luaPanel:RecoverAllInput(BOSS_PROGRESS_BLOCK_INPUT_REASON)
    end
end

DungeonBossEntryCtrl._OnBossCellClick = HL.Method(HL.String) << function(self, bossGroupId)
    
    if HighDifficultyUtils.isNewHighDifficultyBoss(bossGroupId) then
        HighDifficultyUtils.setFalseNewHighDifficultyBoss(bossGroupId)
    end
    self:_SelectBossGroup(bossGroupId)
end

DungeonBossEntryCtrl._SelectBossGroup = HL.Method(HL.String) << function(self, bossGroupId)
    if string.isEmpty(bossGroupId) or not _isBossGroupDisplayUnlocked(bossGroupId) then
        return
    end
    if self.m_bossGroupId == bossGroupId then
        return
    end

    self.m_bossGroupId = bossGroupId
    self.m_curSelectedDungeonId = self:_FindDefaultGameId(bossGroupId)
    self:_RefreshAll()
end

DungeonBossEntryCtrl._OnDifficultyCellClick = HL.Method(HL.String) << function(self, gameId)
    local bossGroupId = highDifficultySystem:GetBossGroupIdByGameId(gameId)
    if string.isEmpty(bossGroupId) or not _isBossGroupDisplayUnlocked(bossGroupId) then
        return
    end
    if self.m_curSelectedDungeonId == gameId then
        return
    end

    AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
    self.m_curSelectedDungeonId = gameId
    self.m_bossGroupId = bossGroupId
    
    self:_RefreshDifficultyCells()
    local bossCell = self.m_bossCells[self.m_bossGroupId]
    if bossCell then
        bossCell:RefreshSelectedDungeon(self.m_curSelectedDungeonId)
    end
    self:_UpdateNaviTarget()
    self:_RefreshBossInfo()
end

DungeonBossEntryCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self:_UpdateNaviTarget()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

DungeonBossEntryCtrl._UpdateNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local bossCell = self.m_bossCells[self.m_bossGroupId]
    if bossCell and _isBossGroupDisplayUnlocked(self.m_bossGroupId) then
        self:SetNaviTarget(bossCell.view.button)
        return
    end

    self:SetNaviTarget(self.view.dungeonBossInfo.view.startButton)
end

DungeonBossEntryCtrl._SelectDifficultyByOffset = HL.Method(HL.Number) << function(self, offset)
    local count = #self.m_bossGameIds
    if count <= 1 then
        return
    end

    local curIndex = 1
    for index, gameId in ipairs(self.m_bossGameIds) do
        if gameId == self.m_curSelectedDungeonId then
            curIndex = index
            break
        end
    end

    local nextIndex = curIndex + offset
    if nextIndex < 1 then
        nextIndex = count
    elseif nextIndex > count then
        nextIndex = 1
    end
    self:_OnDifficultyCellClick(self.m_bossGameIds[nextIndex])
end

DungeonBossEntryCtrl._OnBtnCloseClick = HL.Method() << function(self)
    self.m_phase:RequestClose()
end

DungeonBossEntryCtrl.GetCurSelectDungeonId = HL.Method().Return(HL.String) << function(self)
    return self.m_curSelectedDungeonId
end

DungeonBossEntryCtrl.GetRecoverPopupStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return self.view.dungeonBossInfo:GetRecoverPopupStateArg()
end

DungeonBossEntryCtrl.TryRecoverPopupState = HL.Method(HL.Any) << function(self, popupState)
    self.view.dungeonBossInfo:TryRecoverPopupState(popupState)
end

HL.Commit(DungeonBossEntryCtrl)
