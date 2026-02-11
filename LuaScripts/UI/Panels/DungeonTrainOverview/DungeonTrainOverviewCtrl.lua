
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonTrainOverview
local PHASE_ID = PhaseId.DungeonTrainOverview









DungeonTrainOverviewCtrl = HL.Class('DungeonTrainOverviewCtrl', uiCtrl.UICtrl)


DungeonTrainOverviewCtrl.m_dungeonSeriesIds = HL.Field(HL.Table)


DungeonTrainOverviewCtrl.m_dungeonSeriesTabCellCache = HL.Field(HL.Forward("UIListCache"))






DungeonTrainOverviewCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





DungeonTrainOverviewCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnClickBtnClose()
    end)

    self.m_dungeonSeriesTabCellCache = UIUtils.genCellCache(self.view.dungeonSeriesTabCell)
    self.m_dungeonSeriesIds = {}
    for _, dungeonSeriesId in pairs(Tables.dungeonConst.dungeonTrainSeriesIds) do
        table.insert(self.m_dungeonSeriesIds, dungeonSeriesId)
    end

    self:_RefreshTabs()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end



DungeonTrainOverviewCtrl._OnBtnCloseClick = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end



DungeonTrainOverviewCtrl._RefreshTabs = HL.Method() << function(self)
    local emptyStateCount = Tables.dungeonConst.dungeonTrainEmptyTabCount
    emptyStateCount = 0
    self.m_dungeonSeriesTabCellCache:Refresh(#self.m_dungeonSeriesIds + emptyStateCount, function(cell, luaIndex)
        self:_UpdateTabCell(cell, luaIndex)
    end)

    if DeviceInfo.usingController then
        local cell = self.m_dungeonSeriesTabCellCache:Get(1)
        UIUtils.setAsNaviTarget(cell.view.naviDecorator)
    end
end





DungeonTrainOverviewCtrl._UpdateTabCell = HL.Method(HL.Forward("TrainingEntryTab"), HL.Number) << function(self, cell, luaIndex)
    if luaIndex > #self.m_dungeonSeriesIds then
        cell:InitTrainingEntryTab(true)
    else
        local dungeonSeriesId = self.m_dungeonSeriesIds[luaIndex]
        cell:InitTrainingEntryTab(false, dungeonSeriesId, luaIndex, function()
            
            self:Notify(MessageConst.DIALOG_CLOSE_UI, {nil, nil, 0})
        end)
    end
end



DungeonTrainOverviewCtrl._OnClickBtnClose = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID, function()
        if PhaseManager:IsOpen(PhaseId.Dialog) then
            self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
        end
    end)
end

HL.Commit(DungeonTrainOverviewCtrl)
