
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonRewardDetails
local PHASE_ID = PhaseId.DungeonRewardDetails











DungeonRewardDetailsPopupCtrl = HL.Class('DungeonRewardDetailsPopupCtrl', uiCtrl.UICtrl)


DungeonRewardDetailsPopupCtrl.m_dungeonId = HL.Field(HL.String) << ""


DungeonRewardDetailsPopupCtrl.m_firstPassRewardCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonRewardDetailsPopupCtrl.m_recycleRewardCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonRewardDetailsPopupCtrl.m_extraRewardCellCache = HL.Field(HL.Forward("UIListCache"))






DungeonRewardDetailsPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





DungeonRewardDetailsPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.view.mask.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.m_dungeonId = arg.dungeonId

    self.m_firstPassRewardCellCache = UIUtils.genCellCache(self.view.firstRewardCell)
    self.m_recycleRewardCellCache = UIUtils.genCellCache(self.view.recycleRewardCell)
    self.m_extraRewardCellCache = UIUtils.genCellCache(self.view.extraRewardCell)

    self:_Refresh()
end



DungeonRewardDetailsPopupCtrl._Refresh = HL.Method() << function(self)
    local dungeonMgr = GameInstance.dungeonManager
    local gameMechanicData = Tables.gameMechanicTable[self.m_dungeonId]
    
    local hasFirstReward = not string.isEmpty(gameMechanicData.firstPassRewardId)
    if hasFirstReward then
        local rewardId = gameMechanicData.firstPassRewardId
        local firstRewardGained = dungeonMgr:IsDungeonFirstPassRewardGained(self.m_dungeonId)
        local firstRewardsTbl = self:_ProcessRewards(rewardId, firstRewardGained)
        self.m_firstPassRewardCellCache:Refresh(#firstRewardsTbl, function(cell, index)
            self:_UpdateRewardCell(cell, firstRewardsTbl[index])
        end)
    end
    self.view.firstRewardsNode.gameObject:SetActiveIfNecessary(hasFirstReward)

    
    local hasRecycleReward = not string.isEmpty(gameMechanicData.rewardId)
    if hasRecycleReward then
        local recycleRewardsTbl = self:_ProcessRewards(gameMechanicData.rewardId, false)
        self.m_recycleRewardCellCache:Refresh(#recycleRewardsTbl, function(cell, index)
            self:_UpdateRewardCell(cell, recycleRewardsTbl[index])
        end)
    end
    self.view.recycleRewardsNode.gameObject:SetActiveIfNecessary(hasRecycleReward)

    
    
    local hasExtraReward = not string.isEmpty(gameMechanicData.extraRewardId)
    if hasExtraReward then
        local extraRewardId = gameMechanicData.extraRewardId
        local gained = dungeonMgr:IsDungeonExtraRewardGained(self.m_dungeonId)
        local extraRewardsTbl = self:_ProcessRewards(extraRewardId, gained)
        self.m_extraRewardCellCache:Refresh(#extraRewardsTbl, function(cell, index)
            self:_UpdateRewardCell(cell, extraRewardsTbl[index])
        end)
    end
    self.view.extraRewardsNode.gameObject:SetActiveIfNecessary(hasExtraReward)
end



DungeonRewardDetailsPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    self:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Close)
end





DungeonRewardDetailsPopupCtrl._ProcessRewards = HL.Method(HL.String, HL.Boolean).Return(HL.Table)
        << function(self, rewardId, gained)
    local rewardsTbl = {}
    local rewardsCfg = Tables.rewardTable[rewardId]
    for _, itemBundle in pairs(rewardsCfg.itemBundles) do
        local itemCfg = Tables.itemTable[itemBundle.id]
        table.insert(rewardsTbl, {
            id = itemBundle.id,
            count = itemBundle.count,
            gained = gained,
            sortId1 = itemCfg.sortId1,
            sortId2 = itemCfg.sortId2,
        })
    end
    table.sort(rewardsTbl, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    return rewardsTbl
end





DungeonRewardDetailsPopupCtrl._UpdateRewardCell = HL.Method(HL.Any, HL.Table) << function(self, cell, info)
    cell.item:InitItem(info, true)
    cell.getNode.gameObject:SetActiveIfNecessary(info.gained)
end

HL.Commit(DungeonRewardDetailsPopupCtrl)
