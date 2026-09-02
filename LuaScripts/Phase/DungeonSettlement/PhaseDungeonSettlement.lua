
local phaseBase = require_ex('Phase/Core/PhaseBase')

local Category2Panel = {
    [DungeonConst.DUNGEON_CATEGORY.Archery] = PanelId.TyphoeaArcherySettlementPopup,
    [DungeonConst.DUNGEON_CATEGORY.WulingRacing] = PanelId.WulingParkourSettlement,
}

PhaseDungeonSettlement = HL.Class('PhaseDungeonSettlement', phaseBase.PhaseBase)

PhaseDungeonSettlement.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SHOW_DUNGEON_RESULT] = { 'OnShowDungeonResult', false },
}

PhaseDungeonSettlement.OnShowDungeonResult = HL.StaticMethod(HL.Any) << function(args)
    local dungeonId, leaveTimeDuration, useStaminaReduce = unpack(args)
    local dungeonCfg = Tables.dungeonTable[dungeonId]
    local panelId = Category2Panel[dungeonCfg.dungeonCategory] or PanelId.DungeonSettlementPopup

    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonSettlement", function()
        if not Utils.isInDungeon() then
            logger.error(ELogChannel.Dungeon, "error, try to open settlement out of dungeon")
            return
        end

        PhaseManager:ExitPhaseFastTo(PhaseId.Level)

        UIManager:AutoOpen(panelId, dungeonId)

        if useStaminaReduce then
            ActivityUtils.showStaminaReduceProgress()
        end
    end, function()
        UIManager:Close(panelId)
    end)
end

PhaseDungeonSettlement._OnInit = HL.Override() << function(self)
    PhaseDungeonSettlement.Super._OnInit(self)
end

PhaseDungeonSettlement._OnDestroy = HL.Override() << function(self)
    PhaseDungeonSettlement.Super._OnDestroy(self)
end

HL.Commit(PhaseDungeonSettlement)
