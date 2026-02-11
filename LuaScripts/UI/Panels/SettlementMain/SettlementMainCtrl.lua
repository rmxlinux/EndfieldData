local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SettlementMain
local PHASE_ID = PhaseId.SettlementMain

local settlementSystem = GameInstance.player.settlementSystem

local missionSystem = GameInstance.player.mission













































SettlementMainCtrl = HL.Class('SettlementMainCtrl', uiCtrl.UICtrl)







SettlementMainCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_SETTLEMENT_MODIFY] = '_OnSettlementModify',
    
    [MessageConst.ON_SETTLEMENT_OFFICER_CHANGE] = '_OnUpdateOfficer',
    
    [MessageConst.ON_SETTLEMENT_REMAIN_MONEY_MODIFY] = '_OnUpdateTickMoney',
    
    [MessageConst.ON_SETTLEMENT_TRADE_SUCCESS] = '_OnTradeSuccess',
    
    [MessageConst.ON_FACTORY_DEPOT_CHANGED] = '_TryUpdateItemDepot',
}



local StlStateFlag = {
    None = 0,
    IsSelect = 1 << 0,
    CanUpgrade = 1 << 1,
    HasOfficer = 1 << 2,
    IsMoneyEmpty = 1 << 3,
    IsMoneyFilled = 1 << 4,
}


local StlCellStateNameMap = {
    basic = {
        checkFlag = StlStateFlag.IsSelect,
        [StlStateFlag.None] = "UnselectState",
        [StlStateFlag.IsSelect] = "SelectState",
    },
    expProgress = {
        checkFlag = StlStateFlag.CanUpgrade,
        [StlStateFlag.None] = "NormalState",
        [StlStateFlag.CanUpgrade] = "UpgradeState",
    },
    officer = {
        checkFlag = StlStateFlag.HasOfficer,
        [StlStateFlag.None] = "EmptyState",
        [StlStateFlag.HasOfficer] = "StationedState",
    },
    moneyProgress = {
        checkFlag = StlStateFlag.IsMoneyEmpty | StlStateFlag.IsMoneyFilled,
        [StlStateFlag.None] = "ProgressState",
        [StlStateFlag.IsMoneyEmpty] = "EmptyState",
        [StlStateFlag.IsMoneyFilled] = "FilledState",
    },
}

local TradeIconAniStage = {
    None = 0,
    In = 1,
    Loop = 2,
    Done = 3,
    Out = 4,
}


SettlementMainCtrl.m_genStlCellFunc = HL.Field(HL.Function)


SettlementMainCtrl.m_getTagCells = HL.Field(HL.Forward("UIListCache"))


SettlementMainCtrl.m_domainInfo = HL.Field(HL.Table)


SettlementMainCtrl.m_stlInfoList = HL.Field(HL.Table)


SettlementMainCtrl.m_curSelectStlIndex = HL.Field(HL.Number) << 0


SettlementMainCtrl.m_onSelectorNumberChanged = HL.Field(HL.Function)




SettlementMainCtrl.m_moneyStoreCellCache = HL.Field(HL.Forward("UIListCache"))


SettlementMainCtrl.m_itemStoreCellCache = HL.Field(HL.Forward("UIListCache"))



SettlementMainCtrl.m_moneyStoreCellAniInterval = HL.Field(HL.Thread)










SettlementMainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    local initSuccess = self:_InitData(arg)
    if not initSuccess then
        return
    end
    self:_UpdateData()
    self:_RefreshAllUI()
end



SettlementMainCtrl.OnShow = HL.Override() << function(self)
    settlementSystem:AddSettlementSyncRequest(self.view.transform.name)
end



SettlementMainCtrl.OnClose = HL.Override() << function(self)
    settlementSystem:RemoveSettlementSyncRequest(self.view.transform.name)
    self.m_moneyStoreCellAniInterval = self:_ClearCoroutine(self.m_moneyStoreCellAniInterval)
    local isOpen, _ = PhaseManager:IsOpen(PhaseId.Dialog)
    if isOpen then
        Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 0 })
    end
end




SettlementMainCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    self.view.domainTopMoneyTitle.view.contentNaviGroup:ManuallyStopFocus()
end







SettlementMainCtrl._InitData = HL.Method(HL.Any).Return(HL.Boolean) << function(self, arg)
    local domainId, defaultStlId = DomainPOIUtils.resolveOpenSettlementArgs(arg)
    local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    if not hasCfg then
        logger.error("domainDataTable missing cfg, id: " .. domainId)
        return false
    end
    
    self.m_domainInfo = {
        id = domainId,
        name = domainCfg.domainName,
        icon = domainCfg.domainIcon,
        stlIdList = domainCfg.settlementGroup,
        moneyId = domainCfg.domainGoldItemId,
        itemStoreLimitCount = Utils.getDepotItemStackLimitCount(domainId),
        defaultStlId = defaultStlId,
    }
    
    self.m_tradeIconAniInfo = {
        stage = TradeIconAniStage.None,
        moneyAniStage = TradeIconAniStage.None,
        itemAniStage = TradeIconAniStage.None,
        curIsAdd = false,
        lastUpdateAniTime = 0,
    }
    
    return true
end



SettlementMainCtrl._UpdateData = HL.Method() << function(self)
    self.m_stlInfoList = {}
    local defaultIndex = 1
    for index, stlId in pairs(self.m_domainInfo.stlIdList) do
        if stlId == self.m_domainInfo.defaultStlId then
            defaultIndex = LuaIndex(index)
        end
        
        
        local stlData = settlementSystem:GetUnlockSettlementData(stlId)
        if stlData then
            local stlCfg = Tables.settlementBasicDataTable[stlId]
            local domainLevelCfg = Tables.levelDescTable[stlCfg.domainLevelId]
            local moneyId = self.m_domainInfo.moneyId
            local moneyIcon = ""
            local moneyItemCfg = Utils.tryGetTableCfg(Tables.itemTable, moneyId)
            if moneyItemCfg then
                moneyIcon = moneyItemCfg.iconId
            end
            
            local tagInfos = {}
            for _, stlTagId in pairs(stlCfg.wantTagIdGroup) do
                local tagCfg = Tables.settlementTagTable[stlTagId]
                local tagInfo = {
                    stlTagId = stlTagId,
                    name = tagCfg.settlementTagName,
                    
                    enhanceMoneyProduceSpeedRate = tagCfg.enhanceMoneyProduceSpeedRate,
                    enhanceMoneyProfitRate = tagCfg.enhanceMoneyProfitRate,
                    enhanceExpProfitRate = tagCfg.enhanceExpProfitRate,
                }
                table.insert(tagInfos, tagInfo)
            end
            
            local stlInfo = {
                
                stlId = stlId,
                stlName = stlCfg.settlementName,
                levelName = domainLevelCfg.showName,
                maxLevel = SettlementMainCtrl._GetSettlementMaxLevel(stlCfg),
                stlColor = UIUtils.getColorByString(stlCfg.settlementColor),
                moneyId = moneyId,
                moneyIcon = moneyIcon,
                tagInfos = tagInfos,
                
                upgradeMissionInfo = {},
                officerInfo = {},
                sellItemInfo = {},
                tradeInfo = {},
            }
            self:_UpdateStlRuntimeInfo(stlInfo)
            table.insert(self.m_stlInfoList, stlInfo)
        end
    end
    
    self.m_curSelectStlIndex = defaultIndex
    if #self.m_stlInfoList <= 0 then
        local msg = string.format("据点stlInfoList为空！domainId: %s; defaultStlId: %s", self.m_domainInfo.id, self.m_domainInfo.defaultStlId or "Non")
        logger.error(msg)
        self.m_curSelectStlIndex = 0
    end
end




SettlementMainCtrl._UpdateStlRuntimeInfo = HL.Method(HL.Table) << function(self, stlInfo)
    local stlId = stlInfo.stlId
    
    local stlData = settlementSystem:GetUnlockSettlementData(stlId)
    local stlCfg = Tables.settlementBasicDataTable[stlId]
    local stlLevelCfg = stlCfg.settlementLevelMap[stlData.level]
    
    stlInfo.curLevel = stlData.level
    stlInfo.stlPic = stlLevelCfg.settlementPicId
    stlInfo.stlDesc = stlLevelCfg.desc
    
    local curMoney = stlData.remainMoney
    local maxMoney = stlLevelCfg.moneyMax
    stlInfo.curMoney = curMoney
    stlInfo.maxMoney = maxMoney
    
    local curExp = stlData.exp
    local maxExp = stlLevelCfg.levelUpExp
    stlInfo.curExp = curExp
    stlInfo.maxExp = maxExp
    stlInfo.expProgress = maxExp ~= 0 and curExp / maxExp or 1
    stlInfo.canUpgrade = maxExp ~= 0 and curExp >= maxExp
    
    local missionId = stlLevelCfg.upgradeMissionId
    self:_UpdateMissionInfo(stlInfo, missionId)
    
    local officerId = stlData.officerCharId
    self:_UpdateOfficerInfo(stlInfo, officerId)
    
    local sellItemId = settlementSystem:GetCurSellItem(stlId)
    self:_UpdateSellItemInfo(stlInfo, sellItemId)
end





SettlementMainCtrl._UpdateMissionInfo = HL.Method(HL.Table, HL.String) << function(self, stlInfo, missionId)
    local upgradeMissionInfo = stlInfo.upgradeMissionInfo
    if upgradeMissionInfo.missionId == missionId then
        return
    end
    upgradeMissionInfo.missionId = missionId
    if not string.isEmpty(missionId) then
        upgradeMissionInfo.upgradeMissionTips = Language.LUA_SETTLEMENT_UPGRADE_MISSION_TIPS
        upgradeMissionInfo.isProcessing = missionSystem:GetMissionState(missionId) == CS.Beyond.Gameplay.MissionSystem.MissionState.Processing
    else
        upgradeMissionInfo.isProcessing = false
    end
end





SettlementMainCtrl._UpdateOfficerInfo = HL.Method(HL.Table, HL.String) << function(self, stlInfo, charId)
    local officerInfo = stlInfo.officerInfo
    if officerInfo.charId == charId then
        return
    end
    local hasCfg, charCfg = Tables.characterTable:TryGetValue(charId)
    if hasCfg then
        officerInfo.charId = charId
        officerInfo.iconName = UIConst.UI_CHAR_HEAD_PREFIX .. charId
        officerInfo.charName = charCfg.name
        
        officerInfo.enhanceMoneyProduceSpeedRate = 0
        officerInfo.enhanceMoneyProfitRate = 0
        officerInfo.enhanceExpProfitRate = 0
        for _, stlTagInfo in pairs(stlInfo.tagInfos) do
            if settlementSystem:IsCharMatchSettlementTag(charId, stlTagInfo.stlTagId) then
                officerInfo.enhanceMoneyProduceSpeedRate = officerInfo.enhanceMoneyProduceSpeedRate + stlTagInfo.enhanceMoneyProduceSpeedRate
                officerInfo.enhanceMoneyProfitRate = officerInfo.enhanceMoneyProfitRate + stlTagInfo.enhanceMoneyProfitRate
                officerInfo.enhanceExpProfitRate = officerInfo.enhanceExpProfitRate + stlTagInfo.enhanceExpProfitRate
            end
        end
        
        local effectText = UIUtils.getSettlementEnhanceEffectDesc(officerInfo.enhanceMoneyProduceSpeedRate,
            officerInfo.enhanceMoneyProfitRate,
            officerInfo.enhanceExpProfitRate)
        if string.isEmpty(effectText) then
            officerInfo.effectText = Language.LUA_SETTLEMENT_CHARACTER_NO_EFFECT
        else
            officerInfo.effectText = effectText
        end
    else
        officerInfo.charId = ""
    end
end





SettlementMainCtrl._UpdateSellItemInfo = HL.Method(HL.Table, HL.String) << function(self, stlInfo, itemId)
    local sellItemInfo = stlInfo.sellItemInfo
    if not string.isEmpty(itemId) then
        local stlCfg = Tables.settlementBasicDataTable[stlInfo.stlId]
        local stlLevelCfg = stlCfg.settlementLevelMap[stlInfo.curLevel]
        local tradeItemCfg = stlLevelCfg.settlementTradeItemMap[itemId]
        sellItemInfo.itemId = itemId
        sellItemInfo.localCount = Utils.getDepotItemCount(itemId, Utils.getCurrentScope(), self.m_domainInfo.id)
        sellItemInfo.rewardMoneyCount = tradeItemCfg.rewardMoneyCount
        sellItemInfo.rewardExpCount = tradeItemCfg.stmExp
    else
        sellItemInfo.itemId = ""
    end
    self:_UpdateTradeInfo(stlInfo, 1)
end





SettlementMainCtrl._UpdateTradeInfo = HL.Method(HL.Table, HL.Opt(HL.Number)) << function(self, stlInfo, curCount)
    local tradeInfo = stlInfo.tradeInfo
    local sellItemInfo = stlInfo.sellItemInfo
    if not string.isEmpty(sellItemInfo.itemId) then
        local maxSelectCount = math.min(sellItemInfo.localCount, math.floor(stlInfo.curMoney / sellItemInfo.rewardMoneyCount))
        local minCount = math.min(1, maxSelectCount)
        if not curCount then
            curCount = tradeInfo.selectCount
        end
        curCount = lume.clamp(curCount, minCount, maxSelectCount)
        tradeInfo.selectCount = curCount
        tradeInfo.maxSelectCount = maxSelectCount
        tradeInfo.totalRewardMoney = curCount * sellItemInfo.rewardMoneyCount
        tradeInfo.totalRewardExp = curCount * sellItemInfo.rewardExpCount
    else
        tradeInfo.maxSelectCount = 0
        tradeInfo.selectCount = 0
        tradeInfo.totalRewardMoney = 0
        tradeInfo.totalRewardExp = 0
    end
end



SettlementMainCtrl._GetSettlementMaxLevel = HL.StaticMethod(Cfg.Tables.SettlementBasicData).Return(HL.Number) << function(stlTableCfg)
    local maxLv = 0
    for level, _ in pairs(stlTableCfg.settlementLevelMap) do
        maxLv = math.max(maxLv, level)
    end
    return maxLv
end







SettlementMainCtrl._InitUI = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    
    self.view.domainTopMoneyTitle.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    
    self.view.officerNode.changeOfficerBtn.onClick:AddListener(function()
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        PhaseManager:OpenPhase(PhaseId.SettlementChar, stlInfo.stlId)
    end)
    
    self.view.tradeNode.playerDepotStore.changeItemBtn.onClick:AddListener(function()
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        PhaseManager:OpenPhase(PhaseId.SettlementCommodity, {
            settlementId = stlInfo.stlId,
            settlementLevel = stlInfo.curLevel,
            curSellItem = stlInfo.sellItemInfo.itemId,
            onConfirmChanged = function(itemId)
                local curInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
                settlementSystem:SetCurSellItem(curInfo.stlId, itemId)
                self:_UpdateSellItemInfo(curInfo, itemId)
                self:_RefreshTradeNodeUI()
            end
        })
    end)
    
    self.view.jumpMissionBtn.onClick:AddListener(function()
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        local missionId = stlInfo.upgradeMissionInfo.missionId
        PhaseManager:OpenPhase(PhaseId.Mission, {
            autoSelect = missionId
        })
    end)
    
    
    self.m_genStlCellFunc = UIUtils.genCachedCellFunction(self.view.settlementList)
    self.view.settlementList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnRefreshStlCell(self.m_genStlCellFunc(obj), LuaIndex(csIndex))
    end)
    
    local preActionId = self.view.keyHintLeft.actionId
    local nextActionId = self.view.keyHintRight.actionId
    self:BindInputPlayerAction(preActionId, function()
        local count = #self.m_stlInfoList
        local newIndex = (self.m_curSelectStlIndex + count - 2) % count + 1
        if newIndex ~= self.m_curSelectStlIndex then
            self:_OnChangeSelectStl(newIndex)
            self.view.settlementList:ScrollToIndex(CSIndex(newIndex))
            
            AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
        end
    end)
    self:BindInputPlayerAction(nextActionId, function()
        local count = #self.m_stlInfoList
        local newIndex = self.m_curSelectStlIndex % count + 1
        if newIndex ~= self.m_curSelectStlIndex then
            self:_OnChangeSelectStl(newIndex)
            self.view.settlementList:ScrollToIndex(CSIndex(newIndex))
            
            AudioManager.PostEvent("Au_UI_Toggle_Tab_On")
        end
    end)
    
    self.m_getTagCells = UIUtils.genCellCache(self.view.tagCell)

    
    
    self.m_moneyStoreCellCache = UIUtils.genCellCache(self.view.tradeNode.stlStore.moneyStoreCell)
    self.m_itemStoreCellCache = UIUtils.genCellCache(self.view.tradeNode.playerDepotStore.itemStoreCell)
    self.m_moneyStoreCellCache:Refresh(self.view.config.STORE_CELL_COUNT)
    self.m_itemStoreCellCache:Refresh(self.view.config.STORE_CELL_COUNT)
    
    self.m_onSelectorNumberChanged = function(curNumber, isChangeByBtn)
        if not self.m_stlInfoList then
            return
        end
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        local preCount = stlInfo.tradeInfo.selectCount
        self:_UpdateTradeInfo(stlInfo, curNumber)
        self:_RefreshTradeNodeUI()
        
        if preCount ~= curNumber then
            self:_OnSelectItemCountPlayAni(preCount < curNumber)
        end
    end
    self.view.tradeNode.numberSelector:InitNumberSelector(1, 1, 1, self.m_onSelectorNumberChanged)
    
    self.view.tradeNode.stlStore.moneyTipsBtn.onClick:AddListener(function()
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        UIManager:Open(PanelId.SettlementTokenInstruction, stlInfo.stlId)
    end)
    
    self.view.tradeNode.tradeBtn.onClick:AddListener(function()
        self:_OnSellItem()
    end)
    
    self.view.tradeNode.centerNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
        local tradeNode = self.view.tradeNode
        tradeNode.playerDepotStore.changeItemBtn.gameObject:SetActive(not isFocused)
        tradeNode.stlStore.moneyTipsBtn.interactable = not isFocused
        tradeNode.reduceBtnKeyHint.gameObject:SetActive(not isFocused)
        tradeNode.addBtnKeyHint.gameObject:SetActive(not isFocused)
    end)
    
end



SettlementMainCtrl._RefreshAllUI = HL.Method() << function(self)
    self.view.settlementList:UpdateCount(#self.m_stlInfoList, true)
    self.view.keyHintContent.gameObject:SetActive(#self.m_stlInfoList > 1)
    self:_RefreshDomainUI()
    self:_RefreshTitleMoneyUI()
    self:_RefreshCurSettlementUI()
end





SettlementMainCtrl._OnRefreshStlCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local stlInfo = self.m_stlInfoList[luaIndex]
    cell.gameObject.name = "StlCell_" .. luaIndex
    cell.settlementNameTxt.text = stlInfo.stlName
    cell.settlementLvTxt.text = stlInfo.curLevel
    
    local progressTxt
    if stlInfo.curLevel >= stlInfo.maxLevel then
        progressTxt = "-/-"
    else
        progressTxt = stlInfo.curExp .. "/" .. stlInfo.maxExp
    end
    
    cell.moneyProgressBar.fillAmount = stlInfo.curMoney / stlInfo.maxMoney
    
    local officerInfo = stlInfo.officerInfo
    if not string.isEmpty(officerInfo.charId) then
        cell.officerIconImg.spriteName = officerInfo.iconName
    end
    
    local flag = 0
    if self.m_curSelectStlIndex == luaIndex then
        flag = flag | StlStateFlag.IsSelect
    end
    if stlInfo.canUpgrade then
        flag = flag | StlStateFlag.CanUpgrade
    end
    if not string.isEmpty(stlInfo.officerInfo.charId) then
        flag = flag | StlStateFlag.HasOfficer
    end
    if stlInfo.curMoney == 0 then
        flag = flag | StlStateFlag.IsMoneyEmpty
    elseif stlInfo.curMoney == stlInfo.maxMoney then
        flag = flag | StlStateFlag.IsMoneyFilled
    end
    cell.expProgressStateCtrl:SetState(StlCellStateNameMap.expProgress[flag & StlCellStateNameMap.expProgress.checkFlag])
    cell.officerStateCtrl:SetState(StlCellStateNameMap.officer[flag & StlCellStateNameMap.officer.checkFlag])
    cell.moneyProgressStateCtrl:SetState(StlCellStateNameMap.moneyProgress[flag & StlCellStateNameMap.moneyProgress.checkFlag])
    cell.animationWrapper:SampleClipAtPercent(self.m_curSelectStlIndex == luaIndex and "settlementmainscrollcell_selected" or "settlementmainscrollcell_normal", 1)
    
    cell.cellBtn.interactable = self.m_curSelectStlIndex ~= luaIndex
    cell.cellBtn.onClick:RemoveAllListeners()
    cell.cellBtn.onClick:AddListener(function()
        if self.m_curSelectStlIndex ~= luaIndex then
            self:_OnChangeSelectStl(luaIndex)
        end
    end)
    
    cell.redDot:InitRedDot("SettlementMainTab", stlInfo.stlId)
end



SettlementMainCtrl._RefreshDomainUI = HL.Method() << function(self)
    local domainInfo = self.m_domainInfo
    self.view.domainIconImg:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT_ICON_BIG, domainInfo.icon)
end



SettlementMainCtrl._RefreshTitleMoneyUI = HL.Method() << function(self)
    local domainInfo = self.m_domainInfo
    local hasData, domainDevData = GameInstance.player.domainDevelopmentSystem.domainDevDataDic:TryGetValue(domainInfo.id)
    if hasData then
        local maxCount = domainDevData.curLevelData.moneyLimit
        self.view.domainTopMoneyTitle:InitDomainTopMoneyTitle(domainInfo.moneyId, maxCount)
    else
        logger.error("地区发展数据不存在！可能是还没解锁这个地区的地区发展，domainId:", domainInfo.id)
    end
end



SettlementMainCtrl._RefreshCurSettlementUI = HL.Method() << function(self)
    
    local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
    if not stlInfo then
        local msg = string.format("stlInfo为空！curSelectStlIndex：%s；domainId：%s；defaultStlId：%s", self.m_curSelectStlIndex, self.m_domainInfo.id, self.m_domainInfo.defaultStlId or "Non")
        logger.error(msg)
        return
    end
    self.view.settlementLvTxt.text = stlInfo.curLevel
    self.view.settlementNameTxt.text = stlInfo.stlName
    self.view.levelNameTxt.text = stlInfo.levelName 
    if stlInfo.curLevel >= stlInfo.maxLevel then
        self.view.expProgressTxt.text = "-/-"
        self.view.tradeNode.rewardExpTextStateCtrl:SetState("ExpMax")
    else
        self.view.expProgressTxt.text = stlInfo.curExp .. "/" .. stlInfo.maxExp
        self.view.tradeNode.rewardExpTextStateCtrl:SetState(stlInfo.curExp < stlInfo.maxExp and "ExpNotMax" or "ExpMax")
    end
    self.view.expProgressBar.value = stlInfo.expProgress
    self.view.settlementDescTxt.text = stlInfo.stlDesc
    self.view.settlementPicImg:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT_DETAIL_LEVEL, stlInfo.stlPic)
    self.view.domainIconBgImg.color = Color(stlInfo.stlColor.r, stlInfo.stlColor.g, stlInfo.stlColor.b, self.view.domainIconBgImg.color.a)
    self.view.bottomMaskImg.color = Color(stlInfo.stlColor.r, stlInfo.stlColor.g, stlInfo.stlColor.b, self.view.bottomMaskImg.color.a)
    self.view.colorBgImage.color = Color(stlInfo.stlColor.r, stlInfo.stlColor.g, stlInfo.stlColor.b, self.view.colorBgImage.color.a)
    
    local missionInfo = stlInfo.upgradeMissionInfo
    self.view.missionTipsTxt.text = missionInfo.upgradeMissionTips
    if stlInfo.canUpgrade and not string.isEmpty(missionInfo.missionId) and missionInfo.isProcessing then
        self.view.levelUpStateCtrl:SetState("CanUpgradeState")
    else
        self.view.levelUpStateCtrl:SetState("NormalState")
    end
    
    self:_RefreshOfficerUI()
    
    self:_RefreshTradeNodeUI()
end



SettlementMainCtrl._RefreshOfficerUI = HL.Method() << function(self)
    local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
    if not stlInfo then
        return
    end
    self.m_getTagCells:Refresh(#stlInfo.tagInfos, function(cell, luaIndex)
        self:_OnRefreshTagCell(cell, luaIndex)
    end)
    local officerNode = self.view.officerNode
    local officerInfo = stlInfo.officerInfo
    if not string.isEmpty(officerInfo.charId) then
        officerNode.officerStateCtrl:SetState("NormalState")
        officerNode.officerNameTxt.text = officerInfo.charName
        officerNode.officerIconImg.spriteName = officerInfo.iconName
        officerNode.officerEffectTxt:SetAndResolveTextStyle(officerInfo.effectText)
    else
        officerNode.officerStateCtrl:SetState("EmptyState")
    end
end





SettlementMainCtrl._OnRefreshTagCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
    if not stlInfo then
        return
    end
    local tagInfo = stlInfo.tagInfos[luaIndex]
    local officerInfo = stlInfo.officerInfo
    local isMatch = false
    if not string.isEmpty(officerInfo.charId) then
        isMatch = settlementSystem:IsCharMatchSettlementTag(officerInfo.charId, tagInfo.stlTagId)
    end
    cell.tagNameTxt.text = tagInfo.name
    cell.matchStateCtrl:SetState(isMatch and "MatchState" or "MismatchState")
end






SettlementMainCtrl._RefreshTradeNodeUI = HL.Method(HL.Opt(HL.Boolean)) << function(self, onlyUpdateCount)
    
    local tradeNode = self.view.tradeNode
    local stlStore = tradeNode.stlStore
    local playerStore = tradeNode.playerDepotStore
    local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
    if not stlInfo then
        return
    end
    local tradeInfo = stlInfo.tradeInfo
    local sellItemInfo = stlInfo.sellItemInfo
    
    if not string.isEmpty(sellItemInfo.itemId) then
        if stlInfo.curMoney < sellItemInfo.rewardMoneyCount then
            tradeNode.tradeStateCtrl:SetState("OutOfMoneyState")
        else
            tradeNode.tradeStateCtrl:SetState("CanTradeState")
        end
        if not onlyUpdateCount then
            local hasCfg, itemCfg = Tables.itemTable:TryGetValue(sellItemInfo.itemId)
            if hasCfg then
                playerStore.tradeItemImg:LoadSprite(UIConst.UI_SPRITE_ITEM, itemCfg.iconId)
            else
                logger.error("Item表配置不存在！id：", sellItemInfo.itemId)
            end
            playerStore.itemTipsBtn.onClick:RemoveAllListeners()
            playerStore.itemTipsBtn.onClick:AddListener(function()
                Notify(MessageConst.SHOW_ITEM_TIPS, {
                    itemId = sellItemInfo.itemId,
                    itemCount = sellItemInfo.localCount,
                    
                    transform = playerStore.tradeItemImg.transform,
                    posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                    isSideTips = DeviceInfo.usingController,
                })
            end)
        end
        playerStore.depotNumTxt.text = sellItemInfo.localCount
        playerStore.depotNumTxt.color = sellItemInfo.localCount <= 0 and self.view.config.NUM_COLOR_NOT_ENOUGH or self.view.config.NUM_COLOR_ENOUGH
        playerStore.tradeItemNumTxt.text = string.format("-%d", tradeInfo.selectCount)
        
        local maxCount = self.m_domainInfo.itemStoreLimitCount
        local curStoreItemCellCount = math.ceil(sellItemInfo.localCount / maxCount * self.view.config.STORE_CELL_COUNT)
        local totalTradeItemCellCount = math.ceil(tradeInfo.selectCount / maxCount * self.view.config.STORE_CELL_COUNT)
        local remainItemCellCount = curStoreItemCellCount - totalTradeItemCellCount
        self.m_itemStoreCellCache:Update(function(cell, luaIndex)
            self:_RefreshStoreCell(cell, luaIndex, remainItemCellCount, curStoreItemCellCount)
        end)
    else
        tradeNode.tradeStateCtrl:SetState("NoItemState")
        playerStore.depotNumTxt.text = "-"
    end
    playerStore.depotTitleTxt.text = string.format(Language.LUA_SETTLEMENT_DEPOT_TITLE, self.m_domainInfo.name)
    

    
    if not onlyUpdateCount then
        stlStore.moneyBigIconImg:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, stlInfo.moneyIcon)
        stlStore.moneyIconImg:LoadSprite(UIConst.UI_SPRITE_WALLET, stlInfo.moneyIcon)
        stlStore.moneyItemTipsBtn.onClick:RemoveAllListeners()
        stlStore.moneyItemTipsBtn.onClick:AddListener(function()
            Notify(MessageConst.SHOW_ITEM_TIPS, {
                itemId = self.m_domainInfo.moneyId,
                itemCount = stlInfo.curMoney,
                transform = stlStore.moneyBigIconImg.transform,
                
                posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                isSideTips = DeviceInfo.usingController,
            })
        end)
    end
    stlStore.curMoneyNumTxt.text = stlInfo.curMoney
    stlStore.tradeMoneyNumTxt.text = string.format("+%d", tradeInfo.totalRewardMoney)
    tradeNode.expNumTxt.text = math.tointeger(tradeInfo.totalRewardExp)
    if stlInfo.curExp < stlInfo.maxExp then
        if stlInfo.curExp + tradeInfo.totalRewardExp < stlInfo.maxExp then
            tradeNode.rewardExpTextStateCtrl:SetState("ExpNotMax")
        else
            tradeNode.rewardExpTextStateCtrl:SetState("ExpWillMax")
        end
    else
        tradeNode.rewardExpTextStateCtrl:SetState("ExpMax")
    end
    
    local curStoreMoneyCellCount = math.ceil(stlInfo.curMoney / stlInfo.maxMoney * self.view.config.STORE_CELL_COUNT)
    local totalRewardMoneyCellCount = math.ceil(tradeInfo.totalRewardMoney / stlInfo.maxMoney * self.view.config.STORE_CELL_COUNT)
    local remainMoneyCellCount = curStoreMoneyCellCount - totalRewardMoneyCellCount
    self.m_moneyStoreCellCache:Update(function(cell, luaIndex)
        self:_RefreshStoreCell(cell, luaIndex, remainMoneyCellCount, curStoreMoneyCellCount)
    end)
    

    
    tradeNode.numberSelector:RefreshNumber(
        tradeInfo.selectCount,
        math.min(1, tradeInfo.maxSelectCount),
        tradeInfo.maxSelectCount
    )
end







SettlementMainCtrl._RefreshStoreCell = HL.Method(HL.Any, HL.Number, HL.Number, HL.Number) << function(self, cell, luaIndex, remainCount, curCount)
    if luaIndex <= remainCount then
        cell.imgStateCtrl:SetState("Normal")
    elseif luaIndex <= curCount then
        cell.imgStateCtrl:SetState("Red")
    else
        cell.imgStateCtrl:SetState("Empty")
    end
end










SettlementMainCtrl._OnChangeSelectStl = HL.Method(HL.Number) << function(self, newLuaIndex)
    local oldIndex = self.m_curSelectStlIndex
    self.m_curSelectStlIndex = newLuaIndex
    if newLuaIndex <= 0 or newLuaIndex > #self.m_stlInfoList then
        logger.error("select settlement index out of range: " .. newLuaIndex)
        return
    end
    local cell = self.m_genStlCellFunc(oldIndex)
    if cell then
        cell.animationWrapper:Play("settlementmainscrollcell_normal")
        cell.cellBtn.interactable = true
    end
    cell = self.m_genStlCellFunc(newLuaIndex)
    if cell then
        cell.animationWrapper:Play("settlementmainscrollcell_selected")
        cell.cellBtn.interactable = false
    end
    self:_RefreshCurSettlementUI()
    
    self.view.stlNodeAniWrapper:Play(newLuaIndex > oldIndex and "settlementmainnew_change" or "settlementmainnew_changeleft")
end




SettlementMainCtrl._OnUpdateOfficer = HL.Method(HL.Any) << function(self, arg)
    local stlId, officerId = unpack(arg)
    local targetIndex = 0
    local targetStlInfo
    
    for index, stlInfo in pairs(self.m_stlInfoList) do
        if stlInfo.stlId == stlId then
            targetIndex = index
            targetStlInfo = stlInfo
            break
        end
    end
    
    if not targetStlInfo then
        return
    end
    self:_UpdateOfficerInfo(targetStlInfo, officerId)
    
    local cell = self.m_genStlCellFunc(targetIndex)
    if cell then
        self:_OnRefreshStlCell(cell, targetIndex)
    end
    if self.m_curSelectStlIndex == targetIndex then
        self:_RefreshOfficerUI()
    end
end




SettlementMainCtrl._OnUpdateTickMoney = HL.Method(HL.Any) << function(self, arg)
    local stlId, curMoney = unpack(arg)
    local targetIndex = 0
    local targetStlInfo
    
    for index, stlInfo in pairs(self.m_stlInfoList) do
        if stlInfo.stlId == stlId then
            targetIndex = index
            targetStlInfo = stlInfo
            break
        end
    end
    
    if not targetStlInfo then
        return
    end
    targetStlInfo.curMoney = curMoney
    self:_UpdateTradeInfo(targetStlInfo)
    
    local cell = self.m_genStlCellFunc(targetIndex)
    if cell then
        self:_OnRefreshStlCell(cell, targetIndex)
    end
    if self.m_curSelectStlIndex == targetIndex then
        self:_RefreshTradeNodeUI()
    end
    
    if targetStlInfo.curMoney < targetStlInfo.maxMoney then
        local moneyStoreCellIndex = math.ceil(targetStlInfo.curMoney / targetStlInfo.maxMoney * self.view.config.STORE_CELL_COUNT) + 1

        self.m_moneyStoreCellAniInterval = self:_ClearCoroutine(self.m_moneyStoreCellAniInterval)
        self.m_moneyStoreCellAniInterval = self:_StartCoroutine(function()
            for i = moneyStoreCellIndex, self.view.config.STORE_CELL_COUNT do
                local moneyStoreCell = self.m_moneyStoreCellCache:Get(i)
                if moneyStoreCell then
                    moneyStoreCell.animationWrapper:Play("storecelllight_in")
                    coroutine.wait(moneyStoreCell.config.CELL_LIGHT_ANI_INTERVAL)
                end
            end
        end)
    end
end




SettlementMainCtrl._OnSettlementModify = HL.Method(HL.Any) << function(self, arg)
    local stlId = unpack(arg)
    local targetIndex = 0
    local targetStlInfo
    
    for index, stlInfo in pairs(self.m_stlInfoList) do
        if stlInfo.stlId == stlId then
            targetIndex = index
            targetStlInfo = stlInfo
            break
        end
    end
    
    if not targetStlInfo then
        return
    end
    local isCurSelectStl = self.m_curSelectStlIndex == targetIndex
    self:_UpdateStlRuntimeInfo(targetStlInfo)
    
    self:_RefreshTitleMoneyUI()
    local cell = self.m_genStlCellFunc(targetIndex)
    if cell then
        self:_OnRefreshStlCell(cell, targetIndex)
    end
    if isCurSelectStl then
        self:_RefreshCurSettlementUI()
    end
end




SettlementMainCtrl._TryUpdateItemDepot = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    for _, stlInfo in pairs(self.m_stlInfoList) do
        local sellItemId = settlementSystem:GetCurSellItem(stlInfo.stlId)
        if not string.isEmpty(sellItemId) then
            local sellItemInfo = stlInfo.sellItemInfo
            local nowCount = Utils.getDepotItemCount(sellItemId, Utils.getCurrentScope(), self.m_domainInfo.id)
            if nowCount ~= sellItemInfo.localCount then
                sellItemInfo.localCount = nowCount
                self:_UpdateTradeInfo(stlInfo)
            end
        end
    end
    self:_RefreshTradeNodeUI(true)
end



SettlementMainCtrl._OnSellItem = HL.Method() << function(self)
    local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
    if not stlInfo then
        return
    end
    if stlInfo.tradeInfo.selectCount <= 0 or stlInfo.sellItemInfo.localCount <= 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SETTLEMENT_SELL_ITEM_NOT_ENOUGH)
        return
    end
    settlementSystem:SendSellItem(stlInfo.stlId, stlInfo.sellItemInfo.itemId, stlInfo.tradeInfo.selectCount)
    self.view.tradeNode.tradeBtn.interactable = false
end




SettlementMainCtrl._OnTradeSuccess = HL.Method(HL.Any) << function(self, rawMsg)
    AudioManager.PostEvent("Au_UI_Event_Animate_SettlementTrade")
    
    local msg = unpack(rawMsg)
    
    if msg.RealSellCount == 0 then
        self.view.tradeNode.tradeBtn.interactable = true
        local stlInfo = self.m_stlInfoList[self.m_curSelectStlIndex]
        if not stlInfo then
            return
        end
        stlInfo.sellItemInfo.localCount = 0
        self:_UpdateTradeInfo(stlInfo)
        self:_RefreshTradeNodeUI(true)
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SETTLEMENT_TRADE_NOT_ENOUGH_ZERO)
        return
    end
    
    local tradeAni = "tradenodenewpc_done"
    local isMobileAni = DeviceInfo.isMobile and ((Screen.width / Screen.height) >= (16/9))
    if isMobileAni then
        tradeAni = "tradenodenewmobile_done"
    end
    self.view.tradeNode.animationWrapper:Play(tradeAni, function()
        self.view.tradeNode.tradeBtn.interactable = true
        self.view.tradeNode.animationWrapper:Play("tradenodenewmobile_default")
        self:_ShowTradeReward(rawMsg)
    end)
end




SettlementMainCtrl._ShowTradeReward = HL.Method(HL.Any) << function(self, rawMsg)
    
    local msg = unpack(rawMsg)
    
    local baseRewardMap = msg.RewardBase
    local bonusRewardMap = msg.RewardBonus
    local showItemInfos = {}
    
    for itemId, itemCount in cs_pairs(baseRewardMap) do
        if not string.isEmpty(itemId) and itemCount > 0 then
            local itemInfo = {
                id = itemId,
                count = itemCount,
                customSortId = 2,
            }
            table.insert(showItemInfos, itemInfo)
        end
    end
    
    for itemId, itemCount in cs_pairs(bonusRewardMap) do
        if not string.isEmpty(itemId) and itemCount > 0 then
            local itemInfo = {
                id = itemId,
                count = itemCount,
                customSortId = 1,
                isExtra = true,
            }
            table.insert(showItemInfos, itemInfo)
        end
    end
    
    local args = {
        title = Language.LUA_SETTLEMENT_SELL_ITEM_REWARD_TOAST_TITLE,
        items = showItemInfos,
        icon = self.view.config.SELL_ITEM_REWARD_TOAST_ICON,
    }
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, args)
    
    if msg.ExpectSellCount ~= msg.RealSellCount then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SETTLEMENT_TRADE_NOT_ENOUGH_AUTO_ADAPTIVE_COUNT)
    end
end




SettlementMainCtrl.m_tradeIconAniInfo = HL.Field(HL.Table)




SettlementMainCtrl._OnSelectItemCountPlayAni = HL.Method(HL.Boolean) << function(self, isAdd)
    local info = self.m_tradeIconAniInfo
    info.curIsAdd = isAdd
    AudioManager.PostEvent(isAdd and "Au_UI_Event_Animate_SettlementAdd" or "Au_UI_Event_Animate_SettlementReduce")
    
    local curStage = info.stage
    if curStage == TradeIconAniStage.None then
        self:_PlayTradeIconAni(isAdd)
    end
    
    info.lastUpdateAniTime = Time.time
end




SettlementMainCtrl._PlayTradeIconAni = HL.Method(HL.Boolean) << function(self, isAdd)
    local aniNode = self.view.tradeNode.aniNode
    
    local info = self.m_tradeIconAniInfo
    local continueIntervalTime = self.view.config.TRADE_ICON_ANI_CONTINUE_INTERVAL_TIME
    local curInterval = Time.time - info.lastUpdateAniTime
    local curStage = info.stage
    if curStage == TradeIconAniStage.None then
        
        info.stage = TradeIconAniStage.In
        if isAdd then
            aniNode.stlIconInAniWrapper:Play("tradenodenewiconleft_in", function()
                self:_PlayTradeIconAni(isAdd)
            end)
            aniNode.depotIconInAniWrapper:Play("tradenodenewiconright_in")
        else
            aniNode.stlIconOutAniWrapper:Play("tradenodenewiconleft_out", function()
                self:_PlayTradeIconAni(isAdd)
            end)
            aniNode.depotIconOutAniWrapper:Play("tradenodenewiconright_out")
        end
    elseif isAdd ~= info.curIsAdd then
        
        aniNode.stlIconHideAniWrapper:ClearTween(true)
        aniNode.depotIconHideAniWrapper:ClearTween(false)
        if isAdd then
            aniNode.stlIconHideAniWrapper:Play("tradenodeiconleftup_out", function()
                aniNode.stlIconInAniWrapper:ClearTween(false)
                aniNode.depotIconInAniWrapper:ClearTween(false)
            end)
            aniNode.depotIconHideAniWrapper:Play("tradenodeiconrightup_out")
        else
            aniNode.stlIconHideAniWrapper:Play("tradenodeiconleftdown_out", function()
                aniNode.stlIconOutAniWrapper:ClearTween(false)
                aniNode.depotIconOutAniWrapper:ClearTween(false)
            end)
            aniNode.depotIconHideAniWrapper:Play("tradenodeiconrightdown_out")
        end
        info.stage = TradeIconAniStage.None
        self:_PlayTradeIconAni(info.curIsAdd)
    else
        
        if curStage == TradeIconAniStage.In then
            info.stage = TradeIconAniStage.Loop
            if isAdd then
                aniNode.stlIconInAniWrapper:Play("tradenodenewiconleft_loop", function()
                    self:_PlayTradeIconAni(isAdd)
                end)
                aniNode.depotIconInAniWrapper:Play("tradenodenewiconright_loop")
            else
                aniNode.stlIconOutAniWrapper:Play("tradenodenewiconleft_outloop", function()
                    self:_PlayTradeIconAni(isAdd)
                end)
                aniNode.depotIconOutAniWrapper:Play("tradenodenewiconright_outloop")
            end
        elseif curStage == TradeIconAniStage.Loop then
            if curInterval <= continueIntervalTime then
                info.stage = TradeIconAniStage.In
                self:_PlayTradeIconAni(isAdd)
            else
                info.stage = TradeIconAniStage.Done
                if isAdd then
                    aniNode.stlIconInAniWrapper:Play("tradenodenewiconleft_done", function()
                        self:_PlayTradeIconAni(isAdd)
                    end)
                    aniNode.depotIconInAniWrapper:Play("tradenodenewiconright_done")
                else
                    aniNode.stlIconOutAniWrapper:Play("tradenodenewiconleft_outdone", function()
                        self:_PlayTradeIconAni(isAdd)
                    end)
                    aniNode.depotIconOutAniWrapper:Play("tradenodenewiconright_outdone")
                end
            end
        elseif curStage == TradeIconAniStage.Done then
            info.stage = TradeIconAniStage.None
            if curInterval <= continueIntervalTime then
                self:_PlayTradeIconAni(isAdd)
            end
        end
    end
    
end


HL.Commit(SettlementMainCtrl)
