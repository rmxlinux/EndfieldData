local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local COUNTDOWN_REFRESH_INTERVAL = 1

BossInfoCell = HL.Class('BossInfoCell', UIWidgetBase)

BossInfoCell.m_bossGroupId = HL.Field(HL.String) << ""
BossInfoCell.m_selectedDungeonId = HL.Field(HL.String) << ""
BossInfoCell.m_unlocked = HL.Field(HL.Boolean) << false
BossInfoCell.m_allPassed = HL.Field(HL.Boolean) << false
BossInfoCell.m_progressDifficultyName = HL.Field(HL.String) << ""
BossInfoCell.m_levelCellCache = HL.Field(HL.Any)
BossInfoCell.m_lockTextCoroutine = HL.Field(HL.Thread)
BossInfoCell.m_onClick = HL.Field(HL.Function)

local highDifficultySystem = GameInstance.player.highDifficultySystem


BossInfoCell._OnFirstTimeInit = HL.Override() << function(self)
    if self.view.diffInfoListRoot then
        local prefab = self:LoadGameObject(UIConst.UI_DIFFICULTY_LEVEL_CELL_PREFAB_PATH)
        if prefab then
            local templateObj = CSUtils.CreateObject(prefab, self.view.diffInfoListRoot)
            self.m_levelCellCache = UIUtils.genCellCache(Utils.wrapLuaNode(templateObj))
        end
    end

    self:RegisterMessage(MessageConst.ON_SUB_GAME_UNLOCK, function(args)
        self:_OnSubGameUnlock(args)
    end)
end

BossInfoCell._OnDisable = HL.Override() << function(self)
    self:_StopLockTextCoroutine()
end

BossInfoCell.InitBossInfoCell = HL.Method(HL.String, HL.String, HL.Function) << function(
    self, bossGroupId, selectedDungeonId, onClick)
    self:_FirstTimeInit()
    self:_StopLockTextCoroutine()

    self.m_bossGroupId = bossGroupId
    self.m_onClick = onClick
    self.m_unlocked = highDifficultySystem:IsBossGroupUnlocked(bossGroupId)
    self.m_allPassed = highDifficultySystem:IsBossGroupAllPassed(bossGroupId)
    self.m_progressDifficultyName = self:_GetProgressDifficultyName(bossGroupId)

    self:_RefreshStateController(selectedDungeonId)
    if self.m_unlocked then
        self:_RefreshProgressText()
    end
    self.view.redDot:InitRedDot("HighDifficultyBossCell", bossGroupId)

    self:_RefreshLockText()

    self.view.button.interactable = self.m_unlocked
    self.view.button.onClick:RemoveAllListeners()
    self.view.button.onClick:AddListener(function()
        onClick()
    end)
    
    self.view.lockedButton.onClick:RemoveAllListeners()
    self.view.lockedButton.onClick:AddListener(function()
        Notify(MessageConst.SHOW_TOAST, Language.LUA_HIGHDIFFICULTY_BOSS_LOCKED_TOAST)
    end)

    local config = Tables.highDifficultyBossGroupTable[self.m_bossGroupId]
    local bossImage = config.bossImage .. (self.m_unlocked and "_bright" or "_ash")
    self.view.bossHeadImg:LoadSprite(UIConst.UI_SPRITE_HIGH_DIFFICULTY_BOSS, bossImage)
    self.view.bossNameText.text = config.bossName
    self.view.bossTitleText.text = Language.LUA_HIGHDIFFICULTY_BOSS_TITLE_TIPS
    self:_RefreshLevelCells(selectedDungeonId)
end

BossInfoCell._RefreshCurrent = HL.Method() << function(self)
    if string.isEmpty(self.m_bossGroupId) then
        return
    end

    self:InitBossInfoCell(self.m_bossGroupId, self.m_selectedDungeonId, self.m_onClick)
end



BossInfoCell.RefreshSelectedDungeon = HL.Method(HL.String) << function(self, selectedDungeonId)
    self:_RefreshStateController(selectedDungeonId)
    self:_RefreshLevelCells(selectedDungeonId)
end

BossInfoCell._RefreshLevelCells = HL.Method(HL.String) << function(self, selectedDungeonId)
    if not self.m_levelCellCache then
        return
    end

    local gameIds = self.m_unlocked and highDifficultySystem:GetBossGameIds(self.m_bossGroupId) or nil
    local count = gameIds and gameIds.Count or 0
    self.m_levelCellCache:Refresh(count, function(cell, luaIndex)
        local gameId = gameIds[CSIndex(luaIndex)]
        cell:InitDiffcaultyLevelCell(gameId, selectedDungeonId == gameId)
    end)
end

BossInfoCell.PlayLevelProgressAnimation = HL.Method(HL.String, HL.Function) << function(self, passedGameId, onComplete)
    local gameIds = highDifficultySystem:GetBossGameIds(self.m_bossGroupId)
    for index = 1, gameIds.Count do
        if gameIds[CSIndex(index)] == passedGameId then
            self.m_levelCellCache:GetItem(index):PlayProgressAnimation(onComplete)
            return
        end
    end
end

BossInfoCell._RefreshStateController = HL.Method(HL.String) << function(self, selectedDungeonId)
    local wasSelected = highDifficultySystem:GetBossGroupIdByGameId(self.m_selectedDungeonId) == self.m_bossGroupId
    self.m_selectedDungeonId = selectedDungeonId

    if not self.m_unlocked then
        self.view.stateController:SetState("Lock")
        return
    end

    self.view.stateController:SetState("UnLock")
    local selectedBossGroupId = highDifficultySystem:GetBossGroupIdByGameId(selectedDungeonId)
    local isSelected = selectedBossGroupId == self.m_bossGroupId
    self.view.stateController:SetState(isSelected and "Selected" or "UnSelected")
    if isSelected and not wasSelected then
        self.view.selectAnimationWrapper:PlayWithTween("dungeonbossentry_infocell_select")
    elseif wasSelected and not isSelected then
        self.view.selectAnimationWrapper:PlayWithTween("dungeonbossentry_infocell_unselect")
    end
end

BossInfoCell._RefreshLockText = HL.Method() << function(self)
    if self.m_unlocked or string.isEmpty(self.m_bossGroupId) then
        self.view.unLockTimeText.text = ""
        return
    end
    self:_StartLockTextCoroutine()
end

BossInfoCell._StartLockTextCoroutine = HL.Method() << function(self)
    self:_StopLockTextCoroutine()
    self.m_lockTextCoroutine = self:_StartCoroutine(function()
        while true do
            if string.isEmpty(self.m_bossGroupId) then
                self.m_lockTextCoroutine = nil
                return
            end
            if highDifficultySystem:IsBossGroupUnlocked(self.m_bossGroupId) then
                self.m_lockTextCoroutine = nil
                self:_RefreshCurrent()
                return
            end

            self:_RefreshBossUnlockTimeText()
            coroutine.wait(COUNTDOWN_REFRESH_INTERVAL)
        end
    end)
end

BossInfoCell._StopLockTextCoroutine = HL.Method() << function(self)
    self.m_lockTextCoroutine = self:_ClearCoroutine(self.m_lockTextCoroutine)
end

BossInfoCell._OnSubGameUnlock = HL.Method(HL.Any) << function(self, args)
    local gameId = unpack(args)
    if string.isEmpty(gameId) or string.isEmpty(self.m_bossGroupId) then
        return
    end
    if highDifficultySystem:GetBossGroupIdByGameId(gameId) ~= self.m_bossGroupId then
        return
    end

    self:_RefreshCurrent()
end

BossInfoCell._RefreshProgressText = HL.Method() << function(self)
    if self.m_allPassed then
        self.view.stateController:SetState("Complete")
        self.view.progressText.text = Language.LUA_HIGHDIFFICULTY_BOSS_COMPLETE
        return
    end
    self.view.stateController:SetState("Current")
    if string.isEmpty(self.m_progressDifficultyName) then
        self.view.progressText.text = Language.LUA_HIGHDIFFICULTY_BOSS_NOT_CHALLENGED
    else
        self.view.progressText.text = string.format(Language.LUA_HIGHDIFFICULTY_LEVEL_TIPS, self.m_progressDifficultyName)
    end
end

BossInfoCell._GetProgressDifficultyName = HL.Method(HL.String).Return(HL.String) << function(self, bossGroupId)
    if string.isEmpty(bossGroupId) then
        return ""
    end

    local gameIds = highDifficultySystem:GetBossGameIds(bossGroupId)
    if gameIds == nil or gameIds.Count <= 0 then
        return ""
    end
    
    for i = gameIds.Count, 1, -1 do
        local gameId = gameIds[CSIndex(i)]
        if highDifficultySystem:IsBossGamePassed(gameId) then
            return highDifficultySystem:GetBossGameDifficultyName(gameId)
        end
    end
    return ""
end

BossInfoCell._RefreshBossUnlockTimeText = HL.Method() << function(self)
    local unlockTimestamp = self:_GetBossUnlockTimestamp(self.m_bossGroupId)
    local currTimestamp = DateTimeUtils.GetCurrentTimestampBySeconds()
    if unlockTimestamp <= currTimestamp then
        self.view.unLockTimeText.text = ""
        return
    end

    local leftTime = math.max(unlockTimestamp - currTimestamp, 0)
    self.view.unLockTimeText:SetAndResolveTextStyle(
        string.format(Language.LUA_HIGHDIFFICULTY_BOSS_LOCK_TIME, UIUtils.getLeftTime(leftTime)))
end

BossInfoCell._GetBossUnlockTimestamp = HL.Method(HL.String).Return(HL.Number) << function(self, bossGroupId)
    local hasBossGroupCfg, bossGroupCfg = Tables.highDifficultyBossGroupTable:TryGetValue(bossGroupId)
    if hasBossGroupCfg and not string.isEmpty(bossGroupCfg.openTimeId) then
        return Utils.getTimeIdOpenTimeStamp(bossGroupCfg.openTimeId) or 0
    end
    return 0
end

HL.Commit(BossInfoCell)
return BossInfoCell
