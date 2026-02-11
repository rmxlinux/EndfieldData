local GachaPoolCellBase = require_ex('UI/Widgets/GachaPoolCellBase')









GachaPoolCellLimited = HL.Class('GachaPoolCellLimited', GachaPoolCellBase)








GachaPoolCellLimited._OnFirstTimeInit = HL.Override() << function(self)
    GachaPoolCellLimited.Super._OnFirstTimeInit(self)
    self:_InitUI()
end



GachaPoolCellLimited._InnerInitGachaPoolCell = HL.Override() << function(self)
    logger.info("初始化 GachaPoolCellLimited")
end



GachaPoolCellLimited._InnerUpdateGachaPoolCell = HL.Override() << function(self)
    logger.info("更新 GachaPoolCellLimited")
    self:_RefreshAllUI()
end




GachaPoolCellLimited.UpdateMoneyNodeOnlyGachaTicket = HL.Override(HL.Any) << function(self, moneyNode)
    
    moneyNode.gachaItem1.view.gameObject:SetActiveIfNecessary(true)
    local singlePullItemId = Tables.charGachaConst.gachaTicketSpecialSingleItemId
    moneyNode.gachaItem1:InitMoneyCell(singlePullItemId)
    
    local poolCfg = Tables.gachaCharPoolTable[self.m_poolId]
    local inventory = GameInstance.player.inventory
    local valuableDepotType = GEnums.ItemValuableDepotType.CommercialItem;
    local contains = inventory.valuableDepots:ContainsKey(valuableDepotType)
    local depot
    if contains then
        
        depot = inventory.valuableDepots[valuableDepotType]:GetOrFallback(CS.Beyond.Gameplay.Scope.Create(GEnums.ScopeName.Main))
    end
    if string.isEmpty(poolCfg.ticketGachaSingleLt) then
        moneyNode.gachaItem2.view.gameObject:SetActiveIfNecessary(false)
    else
        moneyNode.gachaItem2.view.gameObject:SetActiveIfNecessary(true)
        moneyNode.gachaItem2:InitMoneyCell(poolCfg.ticketGachaSingleLt)
        if depot then
            for instId, itemBundle in pairs(depot.instItems) do
                if itemBundle.id == poolCfg.ticketGachaSingleLt then
                    moneyNode.gachaItem2:SetItemInstId(instId)
                end
            end
        end
    end
    
    if string.isEmpty(poolCfg.ticketGachaTenLt) then
        moneyNode.gachaItem3.view.gameObject:SetActiveIfNecessary(false)
    else
        moneyNode.gachaItem3.view.gameObject:SetActiveIfNecessary(true)
        moneyNode.gachaItem3:InitMoneyCell(poolCfg.ticketGachaTenLt)
        if depot then
            for instId, itemBundle in pairs(depot.instItems) do
                if itemBundle.id == poolCfg.ticketGachaTenLt then
                    moneyNode.gachaItem3:SetItemInstId(instId)
                end
            end
        end
    end
end





GachaPoolCellLimited._InitUI = HL.Method() << function(self)
    self.view.freeTenNode.gachaFreeBtn.button.onClick:AddListener(function()
        if not self:_CheckCanGacha() then
            return
        end
        GameInstance.player.gacha:GachaFreeTen(self.m_poolId)
    end)
    self.view.testimonialRewardBtn.button.onClick:AddListener(function()
        local testimonialInfo = self.m_baseInfo.cumulateTestimonialInfo
        local itemId = testimonialInfo.testimonialItemId
        local itemName = Tables.itemTable[itemId].name
        
        local finalDescStr = string.gsub(Language.LUA_GACHA_ITEM_INSTRUCTION_DESC_TESTIMONIAL, "%%1%$d", testimonialInfo.needPullCount, 1)
        finalDescStr = string.gsub(finalDescStr, "%%2%$s", itemName, 1)
        local arg = {
            title = Language.LUA_GACHA_ITEM_INSTRUCTION_TITLE_TESTIMONIAL,
            desc = finalDescStr,
            tips = string.format(Language.LUA_GACHA_ITEM_INSTRUCTION_TIPS, testimonialInfo.remainNeedPullCount, itemName),
            itemId = itemId,
        }
        UIManager:Open(PanelId.GachaItemInstructionPopup, arg)
    end)
    self.view.potentialRewardBtn.button.onClick:AddListener(function()
        local loopRewardInfo = self.m_baseInfo.loopCumulateRewardInfo
        local itemId = loopRewardInfo.rewardItemInfo[1].id
        local itemName = Tables.itemTable[itemId].name
        
        local finalDescStr = string.gsub(Language.LUA_GACHA_ITEM_INSTRUCTION_DESC_POTENTIAL, "%%1%$d", loopRewardInfo.needPullCount, 1)
        finalDescStr = string.gsub(finalDescStr, "%%2%$s", itemName, 1)
        local arg = {
            title = Language.LUA_GACHA_ITEM_INSTRUCTION_TITLE_POTENTIAL,
            desc = finalDescStr,
            tips = string.format(Language.LUA_GACHA_ITEM_INSTRUCTION_TIPS, loopRewardInfo.remainNeedPullCount, itemName),
            itemId = itemId,
        }
        UIManager:Open(PanelId.GachaItemInstructionPopup, arg)
    end)
end



GachaPoolCellLimited._RefreshAllUI = HL.Method() << function(self)
    local baseInfo = self.m_baseInfo
    
    local freeTenInfo = baseInfo.cumulateFreeTenGachaInfo
    if freeTenInfo.curCanUseCount > 0 then
        self.view.freeTenNode.stateController:SetState("FreeTen")
        self.view.freeTenNode.stateController:SetState("HideFreeTenTip")
    else
        self.view.freeTenNode.stateController:SetState("Normal")
        
        if freeTenInfo.remainFreeCount > 0 then
            self.view.freeTenNode.stateController:SetState("ShowFreeTenTip")
            self.view.freeTenNumTxt.text = freeTenInfo.remainNeedPullCount
        else
            self.view.freeTenNode.stateController:SetState("HideFreeTenTip")
        end
    end
    
    local testimonialInfo = baseInfo.cumulateTestimonialInfo
    if string.isEmpty(testimonialInfo.testimonialItemId) then
        logger.error("当前限定卡池的介绍信配置为空！卡池id：" .. self.m_poolId)
        self.view.testimonialRewardBtn.gameObject:SetActive(false)
    else
        local canShowTestimonial = freeTenInfo.curCanUseCount <= 0 and freeTenInfo.remainFreeCount <= 0 and testimonialInfo.remainReceivedCount > 0
        if canShowTestimonial then
            self.view.testimonialRewardBtn.gameObject:SetActive(true)
            self.view.testimonialRewardBtn.gachaItem.itemIcon:InitItemIcon(testimonialInfo.testimonialItemId)
            self.view.testimonialRewardBtn.gachaItem.numText.text = 1
            self.view.testimonialRewardBtn.remainNeedPullCountTxt.text = testimonialInfo.remainNeedPullCount
        else
            self.view.testimonialRewardBtn.gameObject:SetActive(false)
        end
    end
    
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






GachaPoolCellLimited.CheckAndShowSpecialRewardPopup = HL.Override() << function(self)
    
    local csGachaSystem = GameInstance.player.gacha
    local baseInfo = self.m_baseInfo
    
    local testimonialInfo = baseInfo.cumulateTestimonialInfo
    if not testimonialInfo.isCheck then
        local itemId = testimonialInfo.testimonialItemId
        local arg = {
            queueRewardType = "TestimonialReward",
            showRewardFunc = function()
                UIManager:AutoOpen(PanelId.GachaImportantRewardPopup, {
                    itemId = itemId,
                    onComplete = function()
                        csGachaSystem:SendConfirmRewardReq(self.m_poolId, CS.Proto.GACHA_CONFIRM_REWARD_TYPE.GcrtOnceReward, {
                            CS.Proto.CHAR_GACHA_ONCE_AUTO_REWARD_INDEX.CgoarIndexTestimonial:GetHashCode()
                        })
                        Notify(MessageConst.ON_ONE_GACHA_POOL_REWARD_FINISHED)
                    end,
                })
            end
        }
        Notify(MessageConst.GACHA_POOL_ADD_SHOW_REWARD, arg)
    end
    
    local loopRewardInfo = baseInfo.loopCumulateRewardInfo
    if not loopRewardInfo.allIsCheck then
        
        local succ, poolData = csGachaSystem.poolInfos:TryGetValue(self.m_poolId)
        if succ then
            local poolCfg = Tables.gachaCharPoolTable[self.m_poolId]
            for loopRound, isCheck in pairs(poolData.roleDataMsg.IntervalAutoRewardCheckMap) do
                if not isCheck then
                    local arg = {
                        queueRewardType = "PotentialReward",
                        showRewardFunc = function()
                            UIManager:AutoOpen(PanelId.GachaPotentialPopup, {
                                charId = poolCfg.upCharIds[0],
                                potentialItemId = loopRewardInfo.rewardItemInfo[1].id,
                                onComplete = function()
                                    csGachaSystem:SendConfirmRewardReq(self.m_poolId, CS.Proto.GACHA_CONFIRM_REWARD_TYPE.GcrtIntervalReward, {
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


HL.Commit(GachaPoolCellLimited)
return GachaPoolCellLimited

