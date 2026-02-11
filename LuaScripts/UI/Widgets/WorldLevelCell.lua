local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')





WorldLevelCell = HL.Class('WorldLevelCell', UIWidgetBase)




WorldLevelCell._OnFirstTimeInit = HL.Override() << function(self)
    
end



WorldLevelCell.InitWorldLevelCell = HL.Method() << function(self)
    self:_FirstTimeInit()

    self.view.exploreBtn.onClick:RemoveAllListeners()
    self.view.exploreBtn.onClick:AddListener(function()
        if GameInstance.player.adventure.currentMaxWorldLevel == 1 then
            
            UIManager:AutoOpen(PanelId.WorldLevelTipsPopup, { isTipsMode = true })
            return
        end
        UIManager:AutoOpen(PanelId.WorldLevelTipsPopup)
    end)

    local missionId = Tables.adventureWorldLevelTable:GetValue(GameInstance.player.adventure.currentMaxWorldLevel).missionId

    self.view.moreBtn.onClick:RemoveAllListeners()
    self.view.moreBtn.onClick:AddListener(function()
        self:OnClickMoreBtn()
    end)

    self.view.lvTxt.text = string.format("%02d", GameInstance.player.adventure.currentWorldLevel)
    local missionData = GameInstance.player.mission:GetMissionData(missionId, false)
    if missionData and (missionData.missionState == CS.Beyond.Gameplay.MissionSystem.MissionState.Available or missionData.missionState == CS.Beyond.Gameplay.MissionSystem.MissionState.Processing) then
        self.view.stateController:SetState("Up")
    else
        self.view.stateController:SetState(GameInstance.player.adventure.isCurWorldLvMax and "Nrl" or "Lower")
    end

end



WorldLevelCell.OnClickMoreBtn = HL.Method() << function(self)
    if GameInstance.player.adventure.currentMaxWorldLevel == 1 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_WORLD_LEVEL_SYSTEM_LOCK)
        return
    end

    local missionId = Tables.adventureWorldLevelTable:GetValue(GameInstance.player.adventure.currentMaxWorldLevel).missionId
    local missionData = GameInstance.player.mission:GetMissionData(missionId, false)
    if missionData and (missionData.missionState == CS.Beyond.Gameplay.MissionSystem.MissionState.Available or missionData.missionState == CS.Beyond.Gameplay.MissionSystem.MissionState.Processing) then
        PhaseManager:OpenPhase(PhaseId.Mission, { autoSelect = missionId })
    end

end

HL.Commit(WorldLevelCell)
return WorldLevelCell

