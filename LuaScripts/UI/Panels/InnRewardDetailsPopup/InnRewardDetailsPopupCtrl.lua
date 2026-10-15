local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRewardDetailsPopup

InnRewardDetailsPopupCtrl = HL.Class('InnRewardDetailsPopupCtrl', uiCtrl.UICtrl)

InnRewardDetailsPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
}

InnRewardDetailsPopupCtrl.m_rewardsCellCache = HL.Field(HL.Forward("UIListCache"))

InnRewardDetailsPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.closeBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.m_rewardsCellCache = UIUtils.genCellCache(self.view.rewardsCell)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self:_RefreshRewards(arg and arg.topicId)
end

InnRewardDetailsPopupCtrl._RefreshRewards = HL.Method(HL.Opt(HL.String)) << function(self, topicId)
    if not topicId or string.isEmpty(topicId) then
        self.m_rewardsCellCache:Refresh(0)
        return
    end

    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if not hasTopic or not topicData then
        self.m_rewardsCellCache:Refresh(0)
        return
    end

    self.view.titleText.text = topicData.name

    local innSystem = GameInstance.player.innSystem
    local currentStars = innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId)) or 0

    local starsRewardId = topicData.starsRewardId
    local starsRewardCount = (starsRewardId and starsRewardId.Count) or 0

    local starRewardList = {}
    for i = 0, starsRewardCount - 1 do
        local rewardId = starsRewardId[i]
        if not string.isEmpty(rewardId) then
            local hasReward, rewardCfg = Tables.rewardTable:TryGetValue(rewardId)
            if hasReward and rewardCfg and rewardCfg.itemBundles then
                local star = i + 1
                local items = {}
                for _, itemBundle in pairs(rewardCfg.itemBundles) do
                    items[#items + 1] = { id = itemBundle.id, count = itemBundle.count }
                end
                starRewardList[#starRewardList + 1] = {
                    star = star,
                    items = items,
                    isClaimed = currentStars >= star,
                }
            end
        end
    end

    self.m_rewardsCellCache:Refresh(#starRewardList, function(cell, index)
        local data = starRewardList[index]
        cell.titleTxt.text = string.format(Language.LUA_INN_REWARD_STAR_TITLE, data.star)

        cell.starCache = cell.starCache or UIUtils.genCellCache(cell.iconimg)
        cell.starCache:Refresh(data.star)

        cell.innerCache = cell.innerCache or UIUtils.genCellCache(cell.secondPartRewardCell)
        cell.innerCache:Refresh(#data.items, function(innerCell, innerIndex)
            local itemData = data.items[innerIndex]
            innerCell.item:InitItem(itemData, true)
            innerCell.item:SetExtraInfo({
                isSideTips = DeviceInfo.usingController,
            })
            innerCell.getNode.gameObject:SetActive(data.isClaimed)
            innerCell.item.view.button.customNaviTargetInDirFunc = function(dir)
                local step
                if dir == CS.UnityEngine.UI.NaviDirection.Up then
                    step = -1
                elseif dir == CS.UnityEngine.UI.NaviDirection.Down then
                    step = 1
                else
                    return nil
                end

                
                local targetIndex = index + step
                while targetIndex >= 1 and targetIndex <= self.m_rewardsCellCache:GetCount() do
                    local targetCache = self.m_rewardsCellCache:GetItem(targetIndex).innerCache
                    local targetCount = targetCache:GetCount()
                    if targetCount > 0 then
                        return targetCache:GetItem(math.min(innerIndex, targetCount)).item.view.button
                    end
                    targetIndex = targetIndex + step
                end
                return nil
            end
        end)
    end)
end

HL.Commit(InnRewardDetailsPopupCtrl)