
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SocializeVisitMission










SocializeVisitMissionCtrl = HL.Class('SocializeVisitMissionCtrl', uiCtrl.UICtrl)


SocializeVisitMissionCtrl.m_listCells = HL.Field(HL.Forward("UIListCache"))







SocializeVisitMissionCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY] = '_UpdateQuestCell',
    [MessageConst.ON_SPACESHIP_JOIN_FRIEND_INFO_EXCHANGE] = '_UpdateQuestCell',
    [MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE] = '_UpdateQuestCell',
    [MessageConst.ON_SPACESHIP_CLUE_INFO_SYNC] = '_UpdateQuestCell',
}





SocializeVisitMissionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.exitBtn.onClick:AddListener(function()
        self:_Exit()
    end)

    self.view.visitorBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.SpaceshipControlCenter)
    end)

    self:_UpdateQuestCell()
end



SocializeVisitMissionCtrl.OnShow = HL.Override() << function(self)

end


SocializeVisitMissionCtrl.OnHide = HL.Override() << function(self)

end


SocializeVisitMissionCtrl.OnClose = HL.Override() << function(self)

end



SocializeVisitMissionCtrl._Exit = HL.Method() << function(self)
    Notify(MessageConst.ON_OPEN_VISIT_FRIEND_LIST)
end




SocializeVisitMissionCtrl._UpdateQuestCell = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    if not self.m_listCells then
        self.m_listCells = UIUtils.genCellCache(self.view.questCell)
    end

    local realMissionTable = {}
    for i, missionData in ipairs(SpaceshipUtils.getFriendMissionTable()) do
        if not missionData:finish() then
            table.insert(realMissionTable, missionData)
        end
    end
    if #realMissionTable == 0 then
        table.insert(realMissionTable, {
            showText = Language.LUA_SPACESHIP_VISIT_FRIEND_FINISH_MISSION
        })
    end
    self.m_listCells:Refresh(#realMissionTable, function(cell, index)
        local data = realMissionTable[index]
        cell.objectiveCell.desc.text = data.showText
    end)
end





HL.Commit(SocializeVisitMissionCtrl)
