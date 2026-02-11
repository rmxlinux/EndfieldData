
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.PresetTeamSwitch

local PhaseFuncState = {
    PresetTeamSwitch = 1,
    DungeonCharacter = 2,
    PresetTeamDungeon = 3,
}





















PhasePresetTeamSwitch = HL.Class('PhasePresetTeamSwitch', phaseBase.PhaseBase)


PhasePresetTeamSwitch.m_currFuncState = HL.Field(HL.Any)


PhasePresetTeamSwitch.m_dungeonId = HL.Field(HL.String) << ""






PhasePresetTeamSwitch.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SHOW_ENTER_FOCUS_MODE_CONFIRM] = { 'ShowEnterFocusModeConfirm', false },
    [MessageConst.SHOW_ENTER_PRESET_TEAM_DUNGEON_CONFIRM] = {'ShowEnterPresetTeamDungeonConfirm', false}
}



PhasePresetTeamSwitch.ShowEnterFocusModeConfirm = HL.StaticMethod(HL.Table) << function(arg)
    local focusModeInstId, onConfirm = unpack(arg)
    local _, focusModeData = GameInstance.dataManager.focusModeInstDataTable:TryGetValue(focusModeInstId)
    if not focusModeData then
        logger.error('Focus mode data not found for ID: %s', focusModeInstId)
        return
    end
    PhaseManager:GoToPhase(PHASE_ID, {
        title = Language.LUA_ENTER_FOCUS_MODE_POPUP_TITLE,
        subTitle = Language.LUA_ENTER_FOCUS_MODE_POPUP_SUB_TITLE,
        presetTeamId = focusModeData.presetTeamId,
        onConfirm = onConfirm,
    })
end



PhasePresetTeamSwitch.ShowEnterPresetTeamDungeonConfirm = HL.StaticMethod(HL.Table) << function(arg)
    local dungeonSeriesId = unpack(arg)
    local dunSeriesId = dungeonSeriesId
    local dunSeriesData = Tables.DungeonSeriesTable[dunSeriesId]
    local dungeonId = dunSeriesData.includeDungeonIds[0]
    local _, dungeonCfg = Tables.DungeonTable:TryGetValue(dungeonId)
    local teamId = dungeonCfg.previewCharTeamId
    if teamId == nil then
        logger.error('试图通过【副本入口 - 预设编队Only】交互物，进入一个没配预设编队的副本 %s', dungeonSeriesId)
        return
    end
    local charInfo = CharInfoUtils.getLockedFormationData(teamId, true)

    if charInfo == nil then
        logger.error('试图通过【副本入口 - 预设编队Only】交互物，无法获取预设编队的副本 %s   %s', dungeonSeriesId, teamId)
        return
    end

    local allPresetTeam = charInfo.lockedTeamMemberCount >= charInfo.maxTeamMemberCount

    if not allPresetTeam then
        logger.error('试图通过【副本入口 - 预设编队Only】交互物，进入一个非纯预设编队副本 %s   %s', dungeonSeriesId, teamId)
        return
    end

    PhaseManager:GoToPhase(PHASE_ID, {
        dungeonSeriesId = dungeonSeriesId,
        presetTeamDungeon = true,
    })
end











PhasePresetTeamSwitch._OnInit = HL.Override() << function(self)
    PhasePresetTeamSwitch.Super._OnInit(self)
end



PhasePresetTeamSwitch._InitAllPhaseItems = HL.Override() << function(self)

    if self.arg.presetTeamDungeon == true then
        self.m_currFuncState = PhaseFuncState.PresetTeamDungeon
    elseif self:_CheckIsDungeonCharacter() then
        self.m_currFuncState = PhaseFuncState.DungeonCharacter
    else
        self.m_currFuncState = PhaseFuncState.PresetTeamSwitch
    end

    
    local arg = {}
    if self.m_currFuncState == PhaseFuncState.PresetTeamSwitch then
        arg = self:_CreateTeamSwitchArg()
    elseif self.m_currFuncState == PhaseFuncState.DungeonCharacter then
        arg = self:_CreateDungeonCharArg()
    elseif self.m_currFuncState == PhaseFuncState.PresetTeamDungeon then
        arg = self:_CreatePresetTeamDungeonArg()
    end
    self:CreatePhasePanelItem(PanelId.PresetTeamSwitch, arg)
end



PhasePresetTeamSwitch._CheckIsDungeonCharacter = HL.Method().Return(HL.Boolean) << function(self)
    if self.arg.dungeonSeriesId == nil then
        return false
    end
    local dunSeriesId = self.arg.dungeonSeriesId
    local dunSeriesData = Tables.DungeonSeriesTable[dunSeriesId]
    local dungeonId = dunSeriesData.includeDungeonIds[0]
    if dungeonId == nil then
        return false
    end
    self.m_dungeonId = dungeonId
    return DungeonUtils.isDungeonChar(dungeonId)
end



PhasePresetTeamSwitch._CreatePresetTeamDungeonArg = HL.Method().Return(HL.Table) << function(self)
    local dunSeriesId = self.arg.dungeonSeriesId
    local dunSeriesData = Tables.DungeonSeriesTable[dunSeriesId]
    local dungeonId = dunSeriesData.includeDungeonIds[0]
    local _, dungeonCfg = Tables.DungeonTable:TryGetValue(dungeonId)
    local teamId = dungeonCfg.previewCharTeamId
    local charInfo = CharInfoUtils.getLockedFormationData(teamId, true)

    local arg = {
        title = Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_TITLE,
        subTitle = Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_SUBTITLE,
        presetTeamId = teamId,
        hideTeam = true,
        onConfirm = function()
            local charInfos = {}
            for _, char in ipairs(charInfo.chars) do
                local presetCharInfo = CharInfoUtils.getPlayerCharInfoByInstId(char.charInstId)
                table.insert(charInfos, presetCharInfo)
            end
            if GameInstance.dungeonManager:TryReqEnterDungeon(dungeonId, charInfos) then
                Utils.reportPlacementEvent(GEnums.ClientPlacementEventType.DungeonBattleFirst)
            end
            GameInstance.player.charBag:ClearAllClientCharAndItemData()
        end,
        onCancel = function()
            self:CloseSelf()
        end,
    }
    return arg
end



PhasePresetTeamSwitch._CreateTeamSwitchArg = HL.Method().Return(HL.Table) << function(self)
    local arg = {
        title = self.arg.title,
        subTitle = self.arg.subTitle,
        presetTeamId = self.arg.presetTeamId,
        onConfirm = function()
            local onConfirm = self.arg.onConfirm
            self:CloseSelf()
            if onConfirm then
                onConfirm()
            end
        end,
        onCancel = function()
            local onCancel = self.arg.onCancel
            self:ExitSelfFast()
            if onCancel then
                onCancel()
            end
        end,
    }
    return arg
end



PhasePresetTeamSwitch._CreateDungeonCharArg = HL.Method().Return(HL.Table) << function(self)
    local dungeonId = self.m_dungeonId
    local _, dungeonCfg = Tables.DungeonTable:TryGetValue(dungeonId)
    local teamId = dungeonCfg.previewCharTeamId
    local charInfo = CharInfoUtils.getLockedFormationData(teamId, true)
    
    local allPresetTeam = charInfo.lockedTeamMemberCount >= charInfo.maxTeamMemberCount
    local arg = {
        title = allPresetTeam and Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_TITLE or Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_TITLE_2,
        subTitle = allPresetTeam and Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_SUBTITLE or Language.LUA_DUNGEON_CHAR_ENTER_DIALOG_SUBTITLE_2,
        presetTeamId = teamId,
        hideTeam = allPresetTeam,
        onConfirm = function()
            if allPresetTeam then
                
                local charInfos = {}
                for _, char in ipairs(charInfo.chars) do
                    local presetCharInfo = CharInfoUtils.getPlayerCharInfoByInstId(char.charInstId)
                    table.insert(charInfos, presetCharInfo)
                end
                Notify(MessageConst.DIALOG_CLOSE_UI, {PanelId.PresetTeamSwitch, PHASE_ID, 0})
                GameInstance.dungeonManager:TryReqEnterDungeon(dungeonId, charInfos)
                GameInstance.player.charBag:ClearAllClientCharAndItemData()
            else
                GameInstance.player.charBag:ClearAllClientCharAndItemData()
                PhaseManager:ExitPhaseFast(PHASE_ID)
                PhaseManager:GoToPhase(PhaseId.CharFormation, { dungeonId = dungeonId })
            end
        end,
        onCancel = function()
            local onCancel = self.arg.onCancel
            if onCancel then
                onCancel()
            end
            Notify(MessageConst.DIALOG_CLOSE_UI, {PanelId.PresetTeamSwitch, PHASE_ID, 0})
        end,
    }
    return arg
end








PhasePresetTeamSwitch.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhasePresetTeamSwitch._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhasePresetTeamSwitch._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhasePresetTeamSwitch._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhasePresetTeamSwitch._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end








PhasePresetTeamSwitch._OnActivated = HL.Override() << function(self)
end



PhasePresetTeamSwitch._OnDeActivated = HL.Override() << function(self)
end



PhasePresetTeamSwitch._OnDestroy = HL.Override() << function(self)
    PhasePresetTeamSwitch.Super._OnDestroy(self)
end




HL.Commit(PhasePresetTeamSwitch)

