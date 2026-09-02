
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PANEL_ID = PanelId.DungeonInfoPopup

PhaseDungeonInfo = HL.Class('PhaseDungeonInfo', phaseBase.PhaseBase)





PhaseDungeonInfo.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DUNGEON_GAME_INIT] = { 'TryToShow', false },
    [MessageConst.SHOW_DUNGEON_INFO_POPUP] = { 'OnShowDungeonInfoPopup', false },
    [MessageConst.TRY_OPEN_DUNGEON_INFO] = { 'OnShowDungeonInfoPopup', false },
}


PhaseDungeonInfo.TryToShow = HL.StaticMethod(HL.Any) << function(args)
    local dungeonId = unpack(args)
    if not DungeonUtils.tryAutoShowDungeonPopup(dungeonId) then
        DungeonUtils.onDungeonInfoFinished()
    end
end


PhaseDungeonInfo.OnShowDungeonInfoPopup = HL.StaticMethod() << function()
    DungeonUtils.showDungeonPopupByEvent()
end



PhaseDungeonInfo.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseDungeonInfo._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDungeonInfo._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDungeonInfo._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseDungeonInfo._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end



HL.Commit(PhaseDungeonInfo)
