local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WulingParkourChallengeGoalPopup

WulingParkourChallengeGoalPopupCtrl = HL.Class('WulingParkourChallengeGoalPopupCtrl', uiCtrl.UICtrl)






WulingParkourChallengeGoalPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

WulingParkourChallengeGoalPopupCtrl.m_rewardDescCells = HL.Field(HL.Any) << nil

WulingParkourChallengeGoalPopupCtrl.m_goalDescCells = HL.Field(HL.Any) << nil

WulingParkourChallengeGoalPopupCtrl.m_rewardItems = HL.Field(HL.Any) << nil

WulingParkourChallengeGoalPopupCtrl.m_activityId = HL.Field(HL.String) << ""




WulingParkourChallengeGoalPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.view.closeButton.onClick:RemoveAllListeners()
    self.view.closeButton.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    local dungeonId = arg and arg.dungeonId or ""
    self.m_activityId = arg and arg.activityId or ""
    
    if not string.isEmpty(self.m_activityId) then
        ActivityUtils.actionWhenActivityClosed(function()
            self:PlayAnimationOutAndClose()
        end, self, self.m_activityId)
    end
    self.m_goalDescCells = UIUtils.genCellCache(self.view.goalDescCell)
    self.m_rewardDescCells = UIUtils.genCellCache(self.view.rewardDescCell)

    local haveParkourData, uiCfg = Tables.ParkourUiTable:TryGetValue(dungeonId)
    local haveRewardData, rewardCfg = Tables.ParkourGameplayTable:TryGetValue(dungeonId)

    self.m_goalDescCells:Refresh(3, function(goalDescCell, luaIndex)
        local goalDesc = ""
        if haveParkourData then
            if luaIndex == 1 then
                goalDesc = uiCfg.star1GoalText
            elseif luaIndex == 2 then
                goalDesc = uiCfg.star2GoalText
            elseif luaIndex == 3 then
                goalDesc = uiCfg.star3GoalText
            end
        end
        goalDescCell.goalDescTxt:SetAndResolveTextStyle(goalDesc)
        local isCompleted = GameInstance.player.parkourSystem:CheckExtraIsCompleted(dungeonId, CSIndex(luaIndex))
        goalDescCell.starStateController:SetState(isCompleted and "Complete" or "Incomplete")
    end)

    self.m_rewardItems = {}
    self.m_rewardDescCells:Refresh(3, function(rewardDescCell, luaIndex)
        local desc = string.format(Language.LUA_ACTIVITY_PARKOUR_STAR_REWARD_POPUP_DESC, luaIndex)
        rewardDescCell.rewardDescTxt.text = desc

        local rewardItems = {}
        local rewardId = ""
        if haveRewardData then
            if luaIndex == 1 then
                rewardId = rewardCfg.extraRewardId1
            elseif luaIndex == 2 then
                rewardId = rewardCfg.extraRewardId2
            elseif luaIndex == 3 then
                rewardId = rewardCfg.extraRewardId3
            end
        else
            return
        end

        local hasReward, rewardData = Tables.rewardTable:TryGetValue(rewardId)
        if hasReward then
            for _, v in pairs(rewardData.itemBundles) do
                table.insert(rewardItems, v)
            end
        end

        local isCompleted = GameInstance.player.parkourSystem:CheckExtraIsCompleted(dungeonId, CSIndex(luaIndex))
        self.m_rewardItems[luaIndex] = UIUtils.genCellCache(rewardDescCell.itemSmall)
        self.m_rewardItems[luaIndex]:Refresh(#rewardItems, function(rewardItemCell, rewardLuaIndex)
            rewardItemCell:InitItem(rewardItems[rewardLuaIndex], true)
            rewardItemCell.view.getNode.gameObject:SetActive(isCompleted)
            rewardItemCell:SetExtraInfo({
                tipsPosTransform = self.view.listVerLayout2,
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                isSideTips = DeviceInfo.usingController,
                
                onBeforeJump = function()
                    self:Close()
                end,
            })
        end)
    end)

end


HL.Commit(WulingParkourChallengeGoalPopupCtrl)
