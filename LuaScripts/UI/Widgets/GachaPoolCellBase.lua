local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')



























GachaPoolCellBase = HL.Class('GachaPoolCellBase', UIWidgetBase)


local csGachaSystem = GameInstance.player.gacha




GachaPoolCellBase.m_poolId = HL.Field(HL.String) << ""


GachaPoolCellBase.m_baseInfo = HL.Field(HL.Table)






GachaPoolCellBase._OnFirstTimeInit = HL.Override() << function(self)
    self:_InitBaseUI()
end




GachaPoolCellBase.InitGachaPoolCell = HL.Method(HL.String) << function(self, poolId)
    self.m_poolId = poolId
    self:_FirstTimeInit()
    self:_InitBaseData()
    self:_InnerInitGachaPoolCell()
    
    self.view.animationWrapper:SampleToOutAnimationEnd()
end



GachaPoolCellBase.UpdateGachaPoolCell = HL.Method() << function(self)
    self:_UpdateBaseData()
    self:_RefreshBaseUI()
    self:_InnerUpdateGachaPoolCell()
end



GachaPoolCellBase._InnerInitGachaPoolCell = HL.Virtual() << function(self)
end



GachaPoolCellBase._InnerUpdateGachaPoolCell = HL.Virtual() << function(self)
end






GachaPoolCellBase._InitBaseData = HL.Method() << function(self)
    
    local poolCfg = Tables.gachaCharPoolTable[self.m_poolId]
    local poolTypeCfg = Tables.gachaCharPoolTypeTable[poolCfg.type]
    
    self.m_baseInfo = {
        
        maxPullCount = poolTypeCfg.maxPullCount,
        remainPullCount = 0,
        
        hardGuarantee = poolTypeCfg.hardGuarantee,
        remainHardGuaranteeProgress = 0,
        maxHardGuaranteeCount = poolTypeCfg.hardGuarantee > 0 and 1 or 0, 
        remainHardGuaranteeCount = 0,
        
        softGuarantee = poolTypeCfg.softGuarantee,
        remainSoftGuaranteeProgress = 0,
        maxSoftGuaranteeCount = poolTypeCfg.maxSoftGuaranteeCount,
        remainSoftGuaranteeCount = 0,
        
        star5SoftGuarantee = poolTypeCfg.star5SoftGuarantee,
        remainStar5SoftGuaranteeProgress = 0,
        
        
        cumulateRewardItemInfo = {},
        
        cumulateFreeTenGachaInfo = {
            needPullCount = poolTypeCfg.freeTenPullRewardPullCount,
            remainNeedPullCount = 0,
            maxFreeCount = poolTypeCfg.freeTenPullRewardPullCount > 0 and 1 or 0, 
            remainFreeCount = 0,
            curCanUseCount = 0,
        },
        
        cumulateChoicePackInfo = {
            needPullCount = poolTypeCfg.choicePackPullCount,
            remainNeedPullCount = 0,
            maxReceivedCount = poolTypeCfg.choicePackPullCount > 0 and 1 or 0, 
            remainReceivedCount = 0,
            curCanUseCount = 0,
        },
        
        cumulateTestimonialInfo = {
            testimonialItemId = poolCfg.testimonialRewardItemId,
            needPullCount = poolTypeCfg.testimonialPullCount,
            remainNeedPullCount = 0,
            maxReceivedCount = poolTypeCfg.testimonialPullCount > 0 and 1 or 0, 
            remainReceivedCount = 0,
            isCheck = false,
        },
        
        loopCumulateRewardInfo = {
            rewardItemInfo = {},
            needPullCount = poolTypeCfg.intervalAutoRewardPerPullCount,
            curRounds = 0,
            remainNeedPullCount = 0,
            receivedRounds = 0, 
            allIsCheck = true, 
        },
        
        previewCharList = {},
        
        gachaCostInfos = {
            permitSinglePull = poolTypeCfg.permitSinglePull,
            tenPullCostCountAfterDiscount = poolTypeCfg.tenPullCostCountAfterDiscount,
            
            singlePullItemInfos = {}, 
            tenPullItemInfos = {}, 
            
            singlePullCostInfos = nil, 
            tenPullCostInfos = nil, 
        }
    }
    
    
    for index, cumulateRewardId in pairs(poolCfg.cumulativeRewardIds) do
        local needPullCount = poolTypeCfg.cumulativeRewardsPullCount[index]
        local rewardItems = UIUtils.getRewardItems(cumulateRewardId)
        local info = {
            id = rewardItems[1].id,
            count = rewardItems[1].count,
            needPullCount = needPullCount,
            isGot = false,
        }
        table.insert(self.m_baseInfo.cumulateRewardItemInfo, info)
    end
    
    for _, loopCumulateRewardId in pairs(poolCfg.intervalAutoRewardIds) do
        local rewardItems = UIUtils.getRewardItems(loopCumulateRewardId)
        local info = {
            id = rewardItems[1].id,
            count = rewardItems[1].count,
        }
        table.insert(self.m_baseInfo.loopCumulateRewardInfo.rewardItemInfo, info)
    end
    
    
    local gachaCostInfo = self.m_baseInfo.gachaCostInfos
    if not string.isEmpty(poolCfg.ticketGachaSingleLt) then
        table.insert(gachaCostInfo.singlePullItemInfos, {
            itemId = poolCfg.ticketGachaSingleLt,
            needCount = 1,
        })
    end
    if not string.isEmpty(poolCfg.ticketGachaTenLt) then
        table.insert(gachaCostInfo.tenPullItemInfos, {
            itemId = poolCfg.ticketGachaTenLt,
            needCount = 1,
        })
    end
    
    for index, itemId in pairs(poolTypeCfg.singlePullCostItemIds) do
        local needCount = poolTypeCfg.singlePullCostItemCounts[index]
        table.insert(gachaCostInfo.singlePullItemInfos, {
            itemId = itemId,
            needCount = needCount,
        })
    end
    for index, itemId in pairs(poolTypeCfg.tenPullCostItemIds) do
        local needCount = poolTypeCfg.tenPullCostItemCounts[index]
        table.insert(gachaCostInfo.tenPullItemInfos, {
            itemId = itemId,
            needCount = needCount,
        })
    end
end



GachaPoolCellBase._UpdateBaseData = HL.Method() << function(self)
    
    local hasInfo, poolInfo = csGachaSystem.poolInfos:TryGetValue(self.m_poolId)
    if not hasInfo then
        logger.error("卡池信息不存在，卡池id：" .. self.m_poolId)
        return
    end
    
    local baseInfo = self.m_baseInfo
    if baseInfo.maxPullCount > 0 then
        baseInfo.remainPullCount = baseInfo.maxPullCount - poolInfo.totalPullCountNoShare
    end
    
    baseInfo.remainHardGuaranteeProgress = baseInfo.hardGuarantee - poolInfo.hardGuaranteeProgress
    baseInfo.remainHardGuaranteeCount = baseInfo.maxHardGuaranteeCount - poolInfo.upGotCount
    
    baseInfo.remainSoftGuaranteeProgress = baseInfo.softGuarantee - poolInfo.softGuaranteeProgress
    baseInfo.remainSoftGuaranteeCount = baseInfo.maxSoftGuaranteeCount - poolInfo.star6GotCount
    
    baseInfo.remainStar5SoftGuaranteeProgress = baseInfo.star5SoftGuarantee - poolInfo.star5SoftGuaranteeProgress
    
    
    local poolRoleData = poolInfo.roleDataMsg
    if poolRoleData then
        for _, rewardIndex in cs_pairs(poolRoleData.CumulativeRewardList) do
            local info = baseInfo.cumulateRewardItemInfo[LuaIndex(rewardIndex)]
            info.isGot = true
        end
    end
    
    local freeTenGachaInfo = baseInfo.cumulateFreeTenGachaInfo
    freeTenGachaInfo.curCanUseCount = poolInfo.freeTenPullCount
    freeTenGachaInfo.remainFreeCount = poolInfo.freeTenPullUsed and 0 or freeTenGachaInfo.maxFreeCount
    freeTenGachaInfo.remainNeedPullCount = freeTenGachaInfo.needPullCount - poolInfo.totalPullCountNoShare
    
    local choicePackInfo = baseInfo.cumulateChoicePackInfo
    choicePackInfo.curCanUseCount = poolInfo.choicePackCount
    choicePackInfo.remainReceivedCount = poolInfo.choicePackUsed and 0 or choicePackInfo.maxReceivedCount
    choicePackInfo.remainNeedPullCount = choicePackInfo.needPullCount - poolInfo.totalPullCountNoShare
    
    local testimonialInfo = baseInfo.cumulateTestimonialInfo
    testimonialInfo.remainNeedPullCount = testimonialInfo.needPullCount - poolInfo.totalPullCountNoShare
    testimonialInfo.remainReceivedCount = poolInfo.testimonialIsGot and 0 or testimonialInfo.maxReceivedCount
    testimonialInfo.isCheck = poolInfo.testimonialIsCheck
    
    local loopRewardInfo = baseInfo.loopCumulateRewardInfo
    if loopRewardInfo.needPullCount > 0 then
        loopRewardInfo.receivedRounds = poolInfo.loopCumulateRewardReceivedRounds
        loopRewardInfo.curRounds = math.floor(poolInfo.totalPullCountNoShare / loopRewardInfo.needPullCount)
        loopRewardInfo.remainNeedPullCount = (loopRewardInfo.curRounds + 1) * loopRewardInfo.needPullCount - poolInfo.totalPullCountNoShare
        loopRewardInfo.allIsCheck = poolInfo.allLoopCumulateRewardIsCheck
    end
end






GachaPoolCellBase._InitBaseUI = HL.Method() << function(self)
    self.view.gachaOnceBtn.button.onClick:RemoveAllListeners()
    self.view.gachaOnceBtn.button.onClick:AddListener(function()
        self:_Gacha(false)
    end)
    self.view.gachaTenBtn.button.onClick:RemoveAllListeners()
    self.view.gachaTenBtn.button.onClick:AddListener(function()
        self:_Gacha(true)
    end)
    if self.view.roleTrialBtn then
        self.view.roleTrialBtn.onClick:RemoveAllListeners()
        self.view.roleTrialBtn.onClick:AddListener(function()
            local poolCfg = Tables.gachaCharPoolTable[self.m_poolId]
            Utils.jumpToSystem(poolCfg.trialActivityJumpId)
        end)
    end
end



GachaPoolCellBase._RefreshBaseUI = HL.Method() << function(self)
    self.view.gachaOnceBtn.gameObject:SetActive(self.m_baseInfo.gachaCostInfos.permitSinglePull)
    
    local baseInfo = self.m_baseInfo
    
    if self.view.hardGuaranteeNode then
        if baseInfo.maxHardGuaranteeCount > 0 then
            if baseInfo.remainHardGuaranteeCount <= 0 then
                self.view.hardGuaranteeNode.gameObject:SetActive(false)
            else
                self.view.hardGuaranteeNode.gameObject:SetActive(true)
                self.view.hardGuaranteeTxt.text = baseInfo.remainHardGuaranteeProgress
            end
        else
            self.view.hardGuaranteeNode.gameObject:SetActive(false)
        end
    end
    
    if self.view.softGuaranteeTxt then
        self.view.softGuaranteeTxt.text = baseInfo.remainSoftGuaranteeProgress
    end
    
    if self.view.star5SoftGuaranteeTxt then
        self.view.star5SoftGuaranteeTxt.text = baseInfo.remainStar5SoftGuaranteeProgress
    end
end





GachaPoolCellBase._RefreshGachaBtn = HL.Method(HL.Any, HL.Table) << function(self, btnCell, pullCostInfos)
    if not btnCell.m_moneyCellCache then
        btnCell.m_moneyCellCache = UIUtils.genCellCache(btnCell.moneyPriceCell)
    end
    btnCell.m_moneyCellCache:Refresh(#pullCostInfos.costItems, function(moneyCell, index)
        local info = pullCostInfos.costItems[index]
        local itemData = Tables.itemTable:GetValue(info.id)
        moneyCell.icon:LoadSprite(UIConst.UI_SPRITE_WALLET, itemData.iconId)
        local isEnough = info.ownCount >= info.count
        moneyCell.countTxt.text = UIUtils.setCountColor(string.format("×%s", info.count), not isEnough)
        if pullCostInfos.priceRate then
            moneyCell.oriCountTxt.gameObject:SetActive(true)
            moneyCell.oriCountTxt.text = string.format("×%d", info.count / pullCostInfos.priceRate)
        else
            moneyCell.oriCountTxt.gameObject:SetActive(false)
        end
    end)
end






GachaPoolCellBase.UpdateMoneyNode = HL.Method(HL.Any) << function(self, moneyNode)
    self:UpdateMoneyNodeOnlyMoney(moneyNode)
    self:UpdateMoneyNodeOnlyGachaTicket(moneyNode)
    self:UpdateGachaBtnCost()
end




GachaPoolCellBase.UpdateMoneyNodeOnlyMoney = HL.Method(HL.Any) << function(self, moneyNode)
    local count = GameInstance.player.inventory:GetItemCountInWallet(Tables.globalConst.originiumItemId)
    moneyNode.originiumConvertedDiamond.text.text = count * Tables.CharGachaConst.exchangeCharGachaCostItemCount
    
end




GachaPoolCellBase.UpdateMoneyNodeOnlyGachaTicket = HL.Virtual(HL.Any) << function(self, moneyNode)
    
    moneyNode.gachaItem1.view.gameObject:SetActiveIfNecessary(false)
    moneyNode.gachaItem2.view.gameObject:SetActiveIfNecessary(false)
    moneyNode.gachaItem3.view.gameObject:SetActiveIfNecessary(false)
end



GachaPoolCellBase.UpdateGachaBtnCost = HL.Method() << function(self)
    local gachaCostInfos = self.m_baseInfo.gachaCostInfos
    
    if gachaCostInfos.permitSinglePull then
        gachaCostInfos.singlePullCostInfos = self:_GetGachaCost(gachaCostInfos.singlePullItemInfos, 1)
        self:_RefreshGachaBtn(self.view.gachaOnceBtn, gachaCostInfos.singlePullCostInfos)
    end
    
    
    gachaCostInfos.tenPullCostInfos = self:_GetGachaCost(gachaCostInfos.tenPullItemInfos, 1)
    if not gachaCostInfos.tenPullCostInfos.isEnough and #gachaCostInfos.singlePullItemInfos > 0 then
        
        local hasDiscount = gachaCostInfos.tenPullCostCountAfterDiscount > 0
        local times = hasDiscount and gachaCostInfos.tenPullCostCountAfterDiscount or 10
        gachaCostInfos.tenPullCostInfos = self:_GetGachaCost(gachaCostInfos.singlePullItemInfos, times)
        if hasDiscount then
            gachaCostInfos.tenPullCostInfos.priceRate = times / 10
        end
    end
    self:_RefreshGachaBtn(self.view.gachaTenBtn, gachaCostInfos.tenPullCostInfos)
end





GachaPoolCellBase._GetGachaCost = HL.Method(HL.Table, HL.Number).Return(HL.Table) << function(self, pullItemInfos, times)
    local diamondId = Tables.globalConst.diamondItemId
    local curDiamondCount, diamondNeedCount
    local costItems = {}
    local isEnough

    
    local leftTimes = times
    for index, itemInfo in pairs(pullItemInfos) do
        local itemId = itemInfo.itemId
        local needCount = itemInfo.needCount
        local curCount = Utils.getItemCount(itemId)
        
        if itemId == diamondId then
            if index ~= #pullItemInfos then
                logger.error("合成玉只能是最后一个消耗", pullItemInfos)
            end
            
            table.insert(costItems, { id = itemId, count = needCount * leftTimes, ownCount = curCount })
            curDiamondCount = curCount
            diamondNeedCount = needCount * leftTimes
            isEnough = curDiamondCount >= diamondNeedCount
            break
        end
        if curCount >= needCount then
            local consumedTimes = math.min(leftTimes, math.floor(curCount / needCount))
            table.insert(costItems, { id = itemId, count = needCount * consumedTimes, ownCount = curCount })
            leftTimes = leftTimes - consumedTimes
        end
        if leftTimes == 0 then
            isEnough = true
            break
        end
    end
    
    if #costItems <= 0 and #pullItemInfos > 0 then
        local pullItemInfo = pullItemInfos[#pullItemInfos]
        local itemId = pullItemInfo.itemId
        local needCount = pullItemInfo.needCount
        local curCount = Utils.getItemCount(itemId)
        table.insert(costItems, { id = itemId, count = needCount * times, ownCount = curCount })
    end
    
    return {
        isEnough = isEnough,
        costItems = costItems,
        curDiamondCount = curDiamondCount,
        diamondNeedCount = diamondNeedCount,
    }
end




GachaPoolCellBase._Gacha = HL.Method(HL.Boolean) << function(self, isTen)
    if not self:_CheckCanGacha() then
        return
    end
    
    local diamondId = Tables.globalConst.diamondItemId
    local gachaCostInfos = self.m_baseInfo.gachaCostInfos
    local costInfos = isTen and gachaCostInfos.tenPullCostInfos or gachaCostInfos.singlePullCostInfos
    local isEnough = costInfos.isEnough
    local costItems = costInfos.costItems
    local curDiamondCount = costInfos.curDiamondCount
    local diamondNeedCount = costInfos.diamondNeedCount
    local costItemCount = #costItems

    logger.info("GachaPoolCellBase._Gacha", self.m_poolId, costItems)
    
    if not isEnough and not diamondNeedCount then
        
        if costItemCount > 0 then
            Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_GACHA_STARTER_GACHA_COST_NOT_ENOUGH, Tables.itemTable[costItems[1].id].name))
        end
        return
    end
    
    local content
    if costItemCount == 1 then
        local info = costItems[1]
        content = string.format(Language.LUA_GACHA_CONFIRM_USE_ONE_ITEM, Tables.itemTable[info.id].name, info.count)
    elseif costItemCount == 2 then
        local info1 = costItems[1]
        local info2 = costItems[2]
        content = string.format(Language.LUA_GACHA_CONFIRM_USE_TWO_ITEMS,
            Tables.itemTable[info1.id].name, info1.count,
            Tables.itemTable[info2.id].name, info2.count
        )
    else
        local info1 = costItems[1]
        local info2 = costItems[2]
        local info3 = costItems[3]
        content = string.format(Language.LUA_GACHA_CONFIRM_USE_THREE_ITEMS,
            Tables.itemTable[info1.id].name, info1.count,
            Tables.itemTable[info2.id].name, info2.count,
            Tables.itemTable[info3.id].name, info3.count
        )
    end
    
    local finalCostDic = {}
    for _, itemInfo in ipairs(costItems) do
        finalCostDic[itemInfo.id] = itemInfo.count
    end
    
    if isEnough then
        Notify(MessageConst.SHOW_POP_UP, {
            content = content,
            costItems = costItems,
            onConfirm = function()
                self:_ExecuteGacha(finalCostDic, isTen)
            end,
        })
        return
    end
    
    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        costItems = costItems,
        onConfirm = function()
            
            local diffCount = diamondNeedCount - curDiamondCount
            local convertRate = Tables.charGachaConst.exchangeCharGachaCostItemCount
            local oriNeedCount = math.ceil(diffCount / convertRate)
            local originiumItemId = Tables.globalConst.originiumItemId
            local curOriCount = Utils.getItemCount(originiumItemId)
            Notify(MessageConst.SHOW_POP_UP, {
                content = string.format(Language.LUA_GACHA_CONFIRM_CONVERT_ORI, oriNeedCount, oriNeedCount * convertRate),
                costItems = {
                    { id = originiumItemId, count = oriNeedCount, ownCount = curOriCount, },
                    { id = diamondId, count = oriNeedCount * convertRate, ownCount = curDiamondCount, },
                },
                convertArrowIndex = 1,
                onConfirm = function()
                    if curOriCount >= oriNeedCount then
                        
                        finalCostDic[diamondId] = curDiamondCount
                        finalCostDic[originiumItemId] = oriNeedCount
                        self:_ExecuteGacha(finalCostDic, isTen)
                    else
                        
                        Notify(MessageConst.SHOW_POP_UP, {
                            content = Language.LUA_GACHA_CONFIRM_CONVERT_ORI_FAIL,
                            onConfirm = function()
                                CashShopUtils.GotoCashShopRechargeTab()
                            end
                        })
                    end
                end,
            })
        end,
    })
end



GachaPoolCellBase._CheckCanGacha = HL.Method().Return(HL.Boolean) << function(self)
    local poolId = self.m_poolId
    local succ, csInfo = GameInstance.player.gacha.poolInfos:TryGetValue(poolId)
    if succ and csInfo.isOpenValid then
        return true
    end

    
    GameInstance.player.guide:OnGachaPoolClosed()

    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_GACHA_POOL_CLOSED,
        hideCancel = true,
        onConfirm = function()
            PhaseManager:PopPhase(PhaseId.GachaPool)
        end,
    })
    return false
end





GachaPoolCellBase._ExecuteGacha = HL.Method(HL.Table, HL.Boolean) << function(self, cost, isTen)
    logger.info("GachaPoolCellBase._ExecuteGacha", self.m_poolId, cost)
    if not self:_CheckCanGacha() then
        return
    end
    if isTen then
        GameInstance.player.gacha:GachaTen(self.m_poolId, cost)
    else
        GameInstance.player.gacha:GachaOnce(self.m_poolId, cost)
    end
end



GachaPoolCellBase.CheckAndShowSpecialRewardPopup = HL.Virtual() << function(self)
    
    
    
end





GachaPoolCellBase.PlayGachaChangeTabInAni = HL.Method() << function(self)
    
    local aniWrapper = self.view.animationWrapper
    if aniWrapper.animationIn then
        aniWrapper:ClearTween()
        aniWrapper:Play(aniWrapper.animationIn)
    else
        logger.error("[卡池动效缺失：ChangeTabInAni] 卡池id：" .. self.m_poolId)
    end
    
    
end



GachaPoolCellBase.PlayGachaScrollInAni = HL.Method() << function(self)
    
    local aniWrapper = self.view.animationWrapper
    local aniName = self.view.config.SCROLL_IN_ANI
    if not string.isEmpty(aniName) then
        aniWrapper:ClearTween()
        aniWrapper:Play(aniName)
    else
        logger.error("[卡池动效缺失：ScrollInAni] 卡池id：" .. self.m_poolId)
    end
    
    if not string.isEmpty(self.view.config.AUD_KEY_IN) then
        AudioManager.PostEvent(self.view.config.AUD_KEY_IN)
    end
end



GachaPoolCellBase.PlayGachaScrollOutAni = HL.Method() << function(self)
    
    local aniWrapper = self.view.animationWrapper
    local aniName = self.view.config.SCROLL_OUT_ANI
    if not string.isEmpty(aniName) then
        aniWrapper:ClearTween()
        aniWrapper:Play(aniName)
    else
        logger.error("[卡池动效缺失：ScrollOutAni] 卡池id：" .. self.m_poolId)
    end
end



GachaPoolCellBase.PlayGachaOutAni = HL.Method() << function(self)
    
    local aniWrapper = self.view.animationWrapper
    if aniWrapper.animationOut then
        aniWrapper:ClearTween()
        aniWrapper:Play(aniWrapper.animationOut)
    else
        logger.error("[卡池动效缺失：ChangeTabInAni] 卡池id：" .. self.m_poolId)
    end
end


HL.Commit(GachaPoolCellBase)
return GachaPoolCellBase