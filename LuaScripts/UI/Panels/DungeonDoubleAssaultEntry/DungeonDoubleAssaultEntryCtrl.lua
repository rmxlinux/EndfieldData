local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonDoubleAssaultEntry
local dungeonActivityEntry = require_ex('UI/Panels/DungeonActivityEntry/DungeonActivityEntryCtrl')
local QUICK_SELECT_FORBIDDEN_TYPE = "DungeonDoubleAssaultEntryQuickSelect"

DungeonDoubleAssaultEntryCtrl = HL.Class('DungeonDoubleAssaultEntryCtrl', dungeonActivityEntry.DungeonActivityEntryCtrl)

DungeonDoubleAssaultEntryCtrl.m_skipSameDungeonCellClick = HL.Field(HL.Boolean) << true




















DungeonDoubleAssaultEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_skipSameDungeonCellClick = false

    
    
    
    if arg and not string.isEmpty(arg.dungeonId) then
        local hasRaid, raidId = Tables.dungeonNormal2RaidTable:TryGetValue(arg.dungeonId)
        if hasRaid and not string.isEmpty(raidId) and DungeonUtils.isDungeonPassed(arg.dungeonId) then
            arg.dungeonId = raidId
        end
    end

    DungeonDoubleAssaultEntryCtrl.Super.OnCreate(self, arg)

    
    if GameInstance.dungeonManager.inDungeon and arg.enterDungeonCallback then
        self.m_enterDungeonCallback = arg.enterDungeonCallback
    end

    if GameInstance.dungeonManager.inDungeon then
        PhaseManager:AddPhaseForbiddenOverrideConfig(QUICK_SELECT_FORBIDDEN_TYPE, {
            [PhaseId.CharFormation] = {
                forbid = false
            },
        })
    end

    if arg.onCloseCallback then
        self.view.btnClose.onClick:RemoveAllListeners()
        self.view.btnClose.onClick:AddListener(function()
            arg.onCloseCallback()
        end)
    end

    if DeviceInfo.usingController then
        self.view.dungeonCommonInfo.view.hardTog.customBindingViewLabelText = Language.LUA_DOUBLE_ASSAULT_SWITCH_FULL_POWER_MODE_HINT
        self.view.dungeonCommonInfo.view.fakeHardTogBtn.customBindingViewLabelText = Language.LUA_DOUBLE_ASSAULT_SWITCH_FULL_POWER_MODE_HINT
    end

    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    
    if not activity then
        return
    end

    self.view.helpBtn.onClick:RemoveAllListeners()
    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "activity_dungeon_actmonster")
    end)

    self.view.dungeonCommonInfo:SetOpenCharFormationCallback(function(gameId)
        self:_OpenDoubleAssaultCharFormation(gameId)
    end)

    self.view.dungeonCommonInfo.view.hardTog.onValueChanged:AddListener(function(isOn)
        if isOn then
            self.m_curSelectedDungeonId = Tables.dungeonNormal2RaidTable[self.m_curSelectedDungeonId]
        else
            self.m_curSelectedDungeonId = Tables.dungeonRaid2NormalTable[self.m_curSelectedDungeonId]
        end
        self:UpdateInfo()
        if isOn then
            AudioAdapter.PostEvent("Au_UI_Toast_HighDifficultyHint")
        end
    end)

    for i, id in ipairs(self.m_dungeons) do
        if self:_IsSameDungeon(id) then
            local cell = self.m_genCells:Get(i)
            self:_OnDungeonCellClick(cell, i, id)
            LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.dungeonNode.transform)
            self.view.dungeonNode:AutoScrollToRectTransform(cell.gameObject.transform, true)
            break
        end
    end
    self.m_skipSameDungeonCellClick = true
    
    local currentDungeonId = self.m_curSelectedDungeonId
    if Tables.dungeonRaid2NormalTable:TryGetValue(currentDungeonId) then
        self.view.dungeonCommonInfo.view.hardTog:SetIsOnWithoutNotify(true)
    end
end

DungeonDoubleAssaultEntryCtrl._IsSameDungeon = HL.Override(HL.String).Return(HL.Boolean) << function(self, dungeonId)
    if dungeonId == self.m_curSelectedDungeonId then
        return true
    end
    local hasRaid, raidDungeonId = Tables.dungeonNormal2RaidTable:TryGetValue(dungeonId)
    return hasRaid and raidDungeonId == self.m_curSelectedDungeonId
end








DungeonDoubleAssaultEntryCtrl.GetDefaultSelectedDungeonId = HL.Override().Return(HL.String) << function(self)
    local success, dungeonSeriesData = Tables.dungeonSeriesTable:TryGetValue(self.m_dungeonSeriesId)
    if not success then
        return ""
    end

    local normalDungeons = {}
    for i = 0, dungeonSeriesData.includeDungeonIds.Count - 1 do
        local dungeonId = dungeonSeriesData.includeDungeonIds[i]
        if Tables.dungeonNormal2RaidTable:TryGetValue(dungeonId) then
            table.insert(normalDungeons, dungeonId)
        end
    end
    table.sort(normalDungeons, function(a, b)
        local _, cfgA = Tables.dungeonTable:TryGetValue(a)
        local _, cfgB = Tables.dungeonTable:TryGetValue(b)
        return cfgA.sortId < cfgB.sortId
    end)

    
    for _, normalId in ipairs(normalDungeons) do
        if DungeonUtils.isDungeonUnlock(normalId) and not DungeonUtils.isDungeonPassed(normalId) then
            return normalId
        end
    end

    
    for _, normalId in ipairs(normalDungeons) do
        local raidId = Tables.dungeonNormal2RaidTable[normalId]
        if not string.isEmpty(raidId)
            and DungeonUtils.isDungeonUnlock(raidId)
            and not DungeonUtils.isDungeonPassed(raidId)
        then
            return raidId
        end
    end

    
    for i = #normalDungeons, 1, -1 do
        local normalId = normalDungeons[i]
        local raidId = Tables.dungeonNormal2RaidTable[normalId]
        if not string.isEmpty(raidId) and DungeonUtils.isDungeonUnlock(raidId) then
            return raidId
        end
        if DungeonUtils.isDungeonUnlock(normalId) then
            return normalId
        end
    end

    return ""
end

DungeonDoubleAssaultEntryCtrl._OpenDoubleAssaultCharFormation = HL.Method(HL.String) << function(self, dungeonId)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activity then
        return
    end
    local hasNormal, normalDungeonId = Tables.dungeonRaid2NormalTable:TryGetValue(dungeonId)
    if not hasNormal then
        normalDungeonId = dungeonId
    end
    local dungeonNumId = CS.Beyond.Cfg.Tables.gameMechanicsIdToNum:GetValue(normalDungeonId)
    local _, subGameData = DataManager.subGameInstDataTable:TryGetValue(dungeonId)
    local teamId = subGameData.teamConfigIds[1]
    local activityId = self.m_activityId
    
    local getSavedTeam = function()
        local charInstIds = {}
        local currentActivity = GameInstance.player.activitySystem:GetActivity(activityId)
        local hasTeam, setting = currentActivity.presetTeamSettings:TryGetValue(dungeonNumId)
        if hasTeam then
            for _, charId in cs_pairs(setting.charTeam) do
                table.insert(charInstIds, charId:GetCharInstId())
            end
        end
        return charInstIds
    end
    
    PhaseManager:GoToPhase(PhaseId.CharFormation, {
        dungeonId = dungeonId,
        presetTeamId = teamId,
        pinTrialCandidates = true,
        forbidDeadChar = true,
        enterDungeonCallback = self.m_enterDungeonCallback,
        getInitCharInstIdList = getSavedTeam,
        customSetTeamCallback = function(charInstIds)
            local _, sendingPhase = PhaseManager:IsOpen(PhaseId.CharFormation)
            GameInstance.player.activitySystem:SendActivitySetPresetTeam(activityId, normalDungeonId, teamId,
                charInstIds, function()
                    local isOpen, phase = PhaseManager:IsOpenAndValid(PhaseId.CharFormation)
                    
                    if isOpen and phase == sendingPhase and phase.arg.getInitCharInstIdList == getSavedTeam then
                        phase:ReloadCustomTeam()
                    end
                end)
        end,
    })
end

DungeonDoubleAssaultEntryCtrl._OnDungeonCellClick = HL.Override(HL.Any, HL.Number, HL.String) << function(self, cell, index, dungeonId)
    if self.m_skipSameDungeonCellClick and self:_IsSameDungeon(dungeonId) then
        return
    end

    local dungeonCommonInfoView = self.view.dungeonCommonInfo.view
    local raidDungeonId = Tables.dungeonNormal2RaidTable[dungeonId]
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local isHardModeUnlocked = false
    if not string.isEmpty(raidDungeonId) and activityData then
        isHardModeUnlocked = DungeonUtils.isDungeonPassed(dungeonId)
    end
    if isHardModeUnlocked then
        dungeonCommonInfoView.hardModeNode:SetState("Enabled")
    else
        dungeonCommonInfoView.hardModeNode:SetState("Disabled")
        dungeonCommonInfoView.fakeHardTogBtn.onClick:RemoveAllListeners()
        dungeonCommonInfoView.fakeHardTogBtn.onClick:AddListener(function()
            Notify(MessageConst.SHOW_TOAST,Language.LUA_DUNGEON_HARD_MODE_CANT_TOG)
        end)
    end

    
    
    local autoPickHard = isHardModeUnlocked
    local finalDungeonId = autoPickHard and raidDungeonId or dungeonId
    dungeonCommonInfoView.hardTog:SetIsOnWithoutNotify(autoPickHard)
    dungeonCommonInfoView.hardTogStateController:SetState(autoPickHard and "On" or "Off")

    local prevSelectedDungeonId = self.m_curSelectedDungeonId
    DungeonDoubleAssaultEntryCtrl.Super._OnDungeonCellClick(self, cell, index, finalDungeonId)
    if autoPickHard then
        if self.m_curSelectedDungeonId ~= prevSelectedDungeonId then
            AudioAdapter.PostEvent("Au_UI_Toast_HighDifficultyHint")
        end
    end
end






DungeonDoubleAssaultEntryCtrl._GetCellRefreshContext = HL.Override().Return(HL.Table) << function(self)
    local context = DungeonDoubleAssaultEntryCtrl.Super._GetCellRefreshContext(self)
    context.cellRedDotName = "ActivityDoubleAssaultDungeon"
    context.cellRedDotArgsBuilder = function(dungeonId, _activityDungeonStateCfg)
        return {
            activityId = self.m_activityId,
            dungeonId = dungeonId,
        }
    end
    context.useDungeonPassedForCompleteState = true
    return context
end





DungeonDoubleAssaultEntryCtrl._MarkCurrentSelectedAsViewed = HL.Override(HL.Any) << function(self, _)
    local curId = self.m_curSelectedDungeonId
    if string.isEmpty(curId) then
        return
    end
    local hasRaid = Tables.dungeonNormal2RaidTable:ContainsKey(curId)
    local normalDungeonId = hasRaid and curId or Tables.dungeonRaid2NormalTable[curId]
    if string.isEmpty(normalDungeonId) then
        return
    end
    ActivityUtils.setFalseNewDoubleAssaultDungeon(normalDungeonId)
end

DungeonDoubleAssaultEntryCtrl.OnClose = HL.Override() << function(self)
    PhaseManager:RemovePhaseForbiddenOverrideConfig(QUICK_SELECT_FORBIDDEN_TYPE)
end











HL.Commit(DungeonDoubleAssaultEntryCtrl)
