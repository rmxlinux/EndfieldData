local GachaPoolCellBase = require_ex('UI/Widgets/GachaPoolCellBase')

GachaPoolCellRerun = HL.Class('GachaPoolCellRerun', GachaPoolCellBase)

local RERUN_VERSION_INHERIT_POPUP_PULL_THRESHOLD = 60
local MILESTONE_TYPE = {
    HardGuarantee = 1,
    FreeTen = 2,
    LoopPotential = 3,
}



GachaPoolCellRerun.m_versionConfirmHandled = HL.Field(HL.Boolean) << false




GachaPoolCellRerun._OnFirstTimeInit = HL.Override() << function(self)
    GachaPoolCellRerun.Super._OnFirstTimeInit(self)
    self:_InitUI()
end

GachaPoolCellRerun._InnerInitGachaPoolCell = HL.Override() << function(self)
    logger.info("初始化 GachaPoolCellRerun")
    self.view.gachaTenBtn.redDot:InitRedDot("GachaCharTenLtTicket", self.m_poolId)
end

GachaPoolCellRerun._InnerUpdateGachaPoolCell = HL.Override() << function(self)
    logger.info("更新 GachaPoolCellRerun")
    self:_RefreshAllUI()
    
    self:_TryHandleRerunVersionConfirm()
end



GachaPoolCellRerun._InitUI = HL.Method() << function(self)
    self.view.freeTenNode.gachaFreeBtn.button.onClick:AddListener(function()
        if not self:_CheckCanGacha() then
            return
        end
        GameInstance.player.gacha:GachaFreeTen(self.m_poolId)
    end)
    self.view.potentialRewardBtn.button.onClick:AddListener(function()
        local loopRewardInfo = self.m_baseInfo.loopCumulateRewardInfo
        local itemId = loopRewardInfo.rewardItemInfo[1].id
        local itemName = Tables.itemTable[itemId].name
        local arg = {
            title = Language.LUA_GACHA_ITEM_INSTRUCTION_TITLE_POTENTIAL,
            desc = string.format(Language.LUA_GACHA_ITEM_INSTRUCTION_DESC_POTENTIAL, loopRewardInfo.needPullCount, itemName),
            tips = string.format(Language.LUA_GACHA_ITEM_INSTRUCTION_TIPS, loopRewardInfo.remainNeedPullCount, itemName),
            itemId = itemId,
        }
        UIManager:Open(PanelId.GachaItemInstructionPopup, arg)
    end)
end

GachaPoolCellRerun._RefreshAllUI = HL.Method() << function(self)
    local baseInfo = self.m_baseInfo
    
    if self.view.rerunVersionTxt then
        self.view.rerunVersionTxt.text = '#' .. self.m_baseInfo.poolVersion
    end
    
    GachaPoolCellRerun.Super._RefreshFreeTenUI(self)
    local freeTenInfo = baseInfo.cumulateFreeTenGachaInfo
    
    local loopRewardInfo = baseInfo.loopCumulateRewardInfo
    if #loopRewardInfo.rewardItemInfo <= 0 then
        logger.error("当前限定卡池的循环奖励配置为空！卡池id：" .. self.m_poolId)
        self.view.potentialRewardBtn.gameObject:SetActive(false)
    else
        local canShowLoopReward = freeTenInfo.curCanUseCount <= 0 and baseInfo.remainHardGuaranteeCount <= 0
        if canShowLoopReward then
            local itemInfo = loopRewardInfo.rewardItemInfo[1]
            self.view.potentialRewardBtn.gameObject:SetActive(true)
            self.view.potentialRewardBtn.gachaItem.itemIcon:InitItemIcon(itemInfo.id)
            self.view.potentialRewardBtn.gachaItem.numText.text = itemInfo.count
            self.view.potentialRewardBtn.remainPullCountTxt.text = loopRewardInfo.remainNeedPullCount
        else
            self.view.potentialRewardBtn.gameObject:SetActive(false)
        end
    end
end




GachaPoolCellRerun.CheckAndShowSpecialRewardPopup = HL.Override() << function(self)
    
    local csGachaSystem = GameInstance.player.gacha
    local baseInfo = self.m_baseInfo
    
    local loopRewardInfo = baseInfo.loopCumulateRewardInfo
    if not loopRewardInfo.allIsCheck then
        
        local succ, poolData = csGachaSystem.poolInfos:TryGetValue(self.m_poolId)
        if succ then
            local poolCfg = Tables.gachaCharPoolTable[self.m_poolId]
            for loopRound, isCheck in pairs(poolData.roleDataMsg.IntervalAutoRewardCheckMap) do
                if not isCheck then
                    local poolId = self.m_poolId    
                    local arg = {
                        queueRewardType = "PotentialReward",
                        showRewardFunc = function()
                            UIManager:AutoOpen(PanelId.GachaPotentialPopup, {
                                charId = poolCfg.upCharIds[0],
                                potentialItemId = loopRewardInfo.rewardItemInfo[1].id,
                                onComplete = function()
                                    csGachaSystem:SendConfirmRewardReq(poolId, CS.Proto.GACHA_CONFIRM_REWARD_TYPE.GcrtIntervalReward, {
                                        loopRound
                                    })
                                    Notify(MessageConst.ON_ONE_GACHA_POOL_REWARD_FINISHED)
                                end,
                            })
                        end
                    }
                    Notify(MessageConst.GACHA_POOL_ADD_SHOW_REWARD, arg)
                end
            end
        end
    end
end

GachaPoolCellRerun._TryHandleRerunVersionConfirm = HL.Method() << function(self)
    if self.m_versionConfirmHandled then
        return
    end

    local csGachaSystem = GameInstance.player.gacha
    local succ, poolInfo = csGachaSystem.poolInfos:TryGetValue(self.m_poolId)
    if not succ then
        return
    end
    
    if poolInfo.totalPullCount <= 0  
        or poolInfo.gachaPoolVersion < 2    
        or poolInfo.gachaPoolVersionConfirmed
    then
        return
    end
    
    local poolId = self.m_poolId
    local nearest = self:_GetNearestRerunMilestone()
    local needShowReminder = nearest and nearest.remainNeedPullCount <= RERUN_VERSION_INHERIT_POPUP_PULL_THRESHOLD

    local poolCfg = Tables.gachaCharPoolTable[poolId]
    local pullCount = poolInfo.totalPullCount
    local content = string.format(Language.LUA_GACHA_RERUN_VERSION_INHERIT_CONTENT, poolCfg.name, pullCount)
    local reminderContent
    if needShowReminder then
        local remain = nearest.remainNeedPullCount
        if nearest.milestoneType == MILESTONE_TYPE.HardGuarantee then
            local upCharId = poolCfg.upCharIds[0]
            local upCharName = Tables.characterTable[upCharId].name
            reminderContent = string.format(Language.LUA_GACHA_RERUN_VERSION_INHERIT_REMINDER_HARD_GUARANTEE, remain, upCharName)
        elseif nearest.milestoneType == MILESTONE_TYPE.LoopPotential then
            reminderContent = string.format(Language.LUA_GACHA_RERUN_VERSION_INHERIT_REMINDER_POTENTIAL, remain)
        else
            local freeTenInfo = self.m_baseInfo.cumulateFreeTenGachaInfo
            if freeTenInfo.curCanUseCount > 0 then
                reminderContent = Language.LUA_GACHA_RERUN_VERSION_INHERIT_REMINDER_FREE_TEN_READY
            else
                reminderContent = string.format(Language.LUA_GACHA_RERUN_VERSION_INHERIT_REMINDER_FREE_TEN, remain)
            end
        end
    end

    self.m_versionConfirmHandled = true
    local arg = {
        queueRewardType = "RerunVersionConfirm",
        poolId = poolId,
        showRewardFunc = function()
            Notify(MessageConst.SHOW_POP_UP, {
                content = content,
                reminderContent = reminderContent,
                hideCancel = true,
                onConfirm = function()
                    csGachaSystem:SendConfirmGachaPoolVersionReq(poolId)
                    Notify(MessageConst.ON_ONE_GACHA_POOL_REWARD_FINISHED)
                end,
            })
        end,
    }
    Notify(MessageConst.GACHA_POOL_ADD_SHOW_REWARD, arg)
end

GachaPoolCellRerun._GetNearestRerunMilestone = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local baseInfo = self.m_baseInfo
    local nearest = nil

    
    local freeTenInfo = baseInfo.cumulateFreeTenGachaInfo
    if freeTenInfo.curCanUseCount > 0 then
        nearest = self:_TryUpdateNearestMilestone(MILESTONE_TYPE.FreeTen, 0, nearest)
    elseif freeTenInfo.remainFreeCount > 0 then
        nearest = self:_TryUpdateNearestMilestone(MILESTONE_TYPE.FreeTen, freeTenInfo.remainNeedPullCount, nearest)
    end
    
    if baseInfo.remainHardGuaranteeCount > 0 then
        nearest = self:_TryUpdateNearestMilestone(MILESTONE_TYPE.HardGuarantee, baseInfo.remainHardGuaranteeProgress, nearest)
    end
    
    local loopRewardInfo = baseInfo.loopCumulateRewardInfo
    if loopRewardInfo.needPullCount > 0 then
        nearest = self:_TryUpdateNearestMilestone(MILESTONE_TYPE.LoopPotential, loopRewardInfo.remainNeedPullCount, nearest)
    end

    return nearest
end

GachaPoolCellRerun._TryUpdateNearestMilestone = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Table)).Return(HL.Opt(HL.Table))
    << function(self, milestoneType, remainNeedPullCount, nearest)
    if remainNeedPullCount < 0 then
        return nearest
    end
    if not nearest or remainNeedPullCount < nearest.remainNeedPullCount
        or (remainNeedPullCount == nearest.remainNeedPullCount and milestoneType < nearest.milestoneType) then
        return {
            milestoneType = milestoneType,
            remainNeedPullCount = remainNeedPullCount,
        }
    end
    return nearest
end


HL.Commit(GachaPoolCellRerun)
return GachaPoolCellRerun
