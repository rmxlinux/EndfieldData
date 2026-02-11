
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.DungeonEntry

local Category2Panel = {
    [DungeonConst.DUNGEON_CATEGORY.SS] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.BossRush] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.CharTutorial] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.Challenge] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.Resource] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.Train] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.WorldLevel] = PanelId.DungeonCommonEntry,
    [DungeonConst.DUNGEON_CATEGORY.HighDifficulty] = PanelId.DungeonCommonEntry,
}
















PhaseDungeonEntry = HL.Class('PhaseDungeonEntry', phaseBase.PhaseBase)


PhaseDungeonEntry.m_currentPanelItem = HL.Field(HL.Forward("PhasePanelItem"))






PhaseDungeonEntry.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_OPEN_DUNGEON_ENTRY_PANEL] = { 'OnOpenDungeonEntryPanel', false },
}



PhaseDungeonEntry.OnOpenDungeonEntryPanel = HL.StaticMethod(HL.Any) << function(args)
    local id, enterDungeonCallback = unpack(args)
    local isDungeonId = Tables.dungeonTable:ContainsKey(id)
    local isDungeonSeriesId = Tables.dungeonSeriesTable:ContainsKey(id)

    local dungeonId
    local dungeonSeriesId
    if isDungeonId then
        local dungeonCfg = Tables.dungeonTable[id]
        dungeonSeriesId = dungeonCfg.dungeonSeriesId

        dungeonId = id
    elseif isDungeonSeriesId then
        dungeonSeriesId = id
    else
        logger.error("打开PhaseDungeonEntry的参数既不是副本系列id也不是副本id")
        return
    end

    PhaseManager:GoToPhase(PHASE_ID, {
        dungeonSeriesId = dungeonSeriesId,
        dungeonId = dungeonId,
        enterDungeonCallback = enterDungeonCallback,
    })
end




PhaseDungeonEntry._OnInit = HL.Override() << function(self)
    PhaseDungeonEntry.Super._OnInit(self)
end








PhaseDungeonEntry.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseDungeonEntry._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local openPanelArgs = self:_PrepareOpenPanelArgs()

    self.m_currentPanelItem = self:CreatePhasePanelItem(openPanelArgs.panelId, {
        dungeonSeriesId = openPanelArgs.dungeonSeriesId,
        dungeonId = openPanelArgs.dungeonId,
        fromDialog = self.arg.fromDialog,
        enterDungeonCallback = self.arg.enterDungeonCallback,
    })
end





PhaseDungeonEntry._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDungeonEntry._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDungeonEntry._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end








PhaseDungeonEntry._OnActivated = HL.Override() << function(self)
end



PhaseDungeonEntry._OnDeActivated = HL.Override() << function(self)
end



PhaseDungeonEntry._OnDestroy = HL.Override() << function(self)
    PhaseDungeonEntry.Super._OnDestroy(self)
end





PhaseDungeonEntry._OnRefresh = HL.Override() << function(self)
    local openPanelArgs = self:_PrepareOpenPanelArgs()

    if self.m_currentPanelItem then
        self:RemovePhasePanelItem(self.m_currentPanelItem)
    end

    self.m_currentPanelItem = self:CreatePhasePanelItem(openPanelArgs.panelId, {
        dungeonSeriesId = openPanelArgs.dungeonSeriesId,
        dungeonId = openPanelArgs.dungeonId,
        fromDialog = self.arg.fromDialog,
        enterDungeonCallback = self.arg.enterDungeonCallback,
    })
end



PhaseDungeonEntry._PrepareOpenPanelArgs = HL.Method().Return(HL.Table) << function(self)
    local dungeonId = self.arg.dungeonId
    local dungeonSeriesId = self.arg.dungeonSeriesId
    if string.isEmpty(dungeonSeriesId) then
        dungeonSeriesId = Tables.dungeonTable[dungeonId].dungeonSeriesId
    end
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[dungeonSeriesId]

    
    
    local panelId = PanelId.DungeonEntry
    if Category2Panel[dungeonSeriesCfg.gameCategory] then
        panelId = Category2Panel[dungeonSeriesCfg.gameCategory]
    end

    return {
        dungeonId = dungeonId,
        dungeonSeriesId = dungeonSeriesId,
        panelId = panelId
    }
end


HL.Commit(PhaseDungeonEntry)

