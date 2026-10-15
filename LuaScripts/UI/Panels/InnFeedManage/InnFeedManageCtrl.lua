local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnFeedManage
local PHASE_ID = PhaseId.InnFeedManage
local innSystem = GameInstance.player.innSystem
local ranchSystem = GameInstance.player.ranchSystem
InnFeedManageCtrl = HL.Class('InnFeedManageCtrl', uiCtrl.UICtrl)







InnFeedManageCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WALLET_CHANGED] = "_OnWalletChanged",
    [MessageConst.ON_RANCH_PRODUCT_UPDATED] = "_OnRanchProductUpdated",
    [MessageConst.ON_RANCH_HARVEST_SUCC] = "_OnHarvestSuccess",
    [MessageConst.ON_COMMON_POI_LEVEL_CHANGE_PERFORM_START] = "_OnStableUnlocked",
}
InnFeedManageCtrl.m_ranchId = HL.Field(HL.String) << ""
InnFeedManageCtrl.m_moneyId = HL.Field(HL.String) << ""
InnFeedManageCtrl.m_stableGroupCfg = HL.Field(HL.Table)
InnFeedManageCtrl.m_stableCellCfg = HL.Field(HL.Table)
InnFeedManageCtrl.m_getCellFunc = HL.Field(HL.Function)
InnFeedManageCtrl.m_getTitleFunc = HL.Field(HL.Function)
InnFeedManageCtrl.m_rewardCells = HL.Field(HL.Forward("UIListCache"))
InnFeedManageCtrl.m_rewardNaviGroup = HL.Field(CS.Beyond.UI.UISelectableNaviGroup)
InnFeedManageCtrl.m_instructionShown  = HL.Field(HL.Boolean) << false
InnFeedManageCtrl.m_unlockReshowDelayTimer = HL.Field(HL.Number) << -1
InnFeedManageCtrl.m_openedFromInteractive = HL.Field(HL.Boolean) << false


InnFeedManageCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs(true)

    
    if arg and arg.showInstruction then
        self:_ShowInstruction()
        arg.showInstruction = false
    end
end

InnFeedManageCtrl.OnClose = HL.Override() << function(self)
    if self.m_unlockReshowDelayTimer > 0 then
        self:_ClearTimer(self.m_unlockReshowDelayTimer)
        self.m_unlockReshowDelayTimer = -1
    end
end

InnFeedManageCtrl.OnOpenRanchManagePanel = HL.StaticMethod(HL.Any) << function(arg)
    local ranchId = unpack(arg)
    PhaseManager:OpenPhase(PHASE_ID, {
        ranchId = ranchId,
        fromInteractive = true,
    })
end

InnFeedManageCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_stableGroupCfg = {}
    self.m_stableCellCfg = {}
    self.m_ranchId = arg and arg.ranchId or Tables.innManagementConst.innRanchId
    self.m_openedFromInteractive = arg and arg.fromInteractive == true or false
    for _, groupCfg in pairs(Tables.innRanchStableGroupTable) do
        table.insert(self.m_stableGroupCfg, groupCfg)
        for _, cellCfg in pairs(groupCfg.stables) do
            table.insert(self.m_stableCellCfg, cellCfg)
        end
    end
    table.sort(self.m_stableGroupCfg, Utils.genSortFunction({"sortId"}, true))
    table.sort(self.m_stableCellCfg, Utils.genSortFunction({"sortId"}, true))
end

InnFeedManageCtrl._InitUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.helpBtn.onClick:AddListener(function()
        self:_ShowInstruction()
    end)

    
    local moneyId = Tables.ranchConst.unlockAutoMoneyId
    if string.isEmpty(moneyId) then
        local domainId = Utils.getCurDomainId()
        local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
        moneyId = domainCfg.domainGoldItemId
    end
    self.m_moneyId = moneyId
    self.view.walletBarPlaceholder:InitWalletBarPlaceholder({moneyId})

    
    self.view.receiveAllBtn.onClick:AddListener(function()
        if #self:_CollectRewardItems() == 0 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_HARVEST_EMPTY_TOAST)
            return
        end
        ranchSystem:SendRanchProductTake(self.m_ranchId)
    end)

    
    self.view.feedNode:InitRanchFeed({
        ranchId = self.m_ranchId,
    })

    
    
    self.view.scrollList.getCellName = function(csIndex)
        if csIndex < 0 then
            
            return string.format("StableTitle_%d", LuaIndex(-1 - csIndex))
        end
        return string.format("StableCell_%d", LuaIndex(csIndex))
    end
    self.view.scrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_UpdateStableCell(go, csIndex)
    end)
    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.m_getTitleFunc = UIUtils.genCachedCellFunction(self.view.scrollList, nil, true)
    self.view.scrollList.onUpdateGroupTitle:AddListener(function(go, csIndex)
        self:_UpdateStableTitle(go, csIndex)
    end)
    self.view.scrollList.getCellCountInGroup = function(groupCsIndex)
        local groupCfg = self.m_stableGroupCfg[LuaIndex(groupCsIndex)]
        return groupCfg and #groupCfg.stables or 0
    end

    
    self.m_rewardCells = UIUtils.genCellCache(self.view.itemSmall)
    
    self.view.rewardLayoutSelectableNaviGroup.getDefaultSelectableFunc = function()
        local cell = self.m_rewardCells:GetItem(1)
        if cell then
            return cell.view.button
        end
    end
    self.view.rewardLayoutSelectableNaviGroup.canFocusFun = function()
        return self.m_rewardCells:GetCount() > 0 
    end

    self.view.rewardTitleText.text = Language.LUA_RANCH_REWARD_TITLE
end

InnFeedManageCtrl._RefreshAllUIs = HL.Method(HL.Boolean) << function(self, isInit)
    self.view.scrollList:UpdateGroup(#self.m_stableGroupCfg, isInit)
    self:_RefreshRewardItems()
    self.view.feedNode:_RefreshAllUIs()
    if isInit then
        if DeviceInfo.usingController then
            self.view.scrollList:ScrollToIndex(
                0, 0, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
            local firstCellObj = self.view.scrollList:Get(0, 0)
            if firstCellObj then
                local firstCell = self.m_getCellFunc(firstCellObj)
                self:SetNaviTarget(firstCell.view.naviDecorator)
            end
            self.view.controllerHintPlaceholder:InitControllerHintPlaceholder(
                { self.view.inputGroup.groupId },
                nil,
                function(infoList)
                    local rewardNaviGroup = self.view.rewardLayoutSelectableNaviGroup
                    if InputManagerInst.controllerNaviManager:IsLayerInStack(rewardNaviGroup) then
                        lume.clear(infoList)
                    end
                end)
        end
    end
end

InnFeedManageCtrl._CollectRewardItems = HL.Method().Return(HL.Table) << function(self)
    local rewardItems = {}
    local rewardItemMap = {}

    local addReward = function(itemId, itemCount)
        if itemCount <= 0 then
            return
        end
        local rewardItem = rewardItemMap[itemId]
        if rewardItem then
            rewardItem.itemCount = rewardItem.itemCount + itemCount
        else
            local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
            rewardItem = {
                itemId = itemId,
                itemCount = itemCount,
                rarity = itemCfg.rarity,
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
            }
            rewardItemMap[itemId] = rewardItem
            table.insert(rewardItems, rewardItem)
        end
    end

    for _, stableCfg in ipairs(self.m_stableCellCfg) do
        local hasAnimal, animalData = ranchSystem:GetStableAnimal(self.m_ranchId, stableCfg.stableId)
        if hasAnimal then
            local _, animalCfg = Tables.innRanchAnimalTable:TryGetValue(animalData.animalId)
            addReward(animalCfg.lowLevelProd, animalData.lowLevelProdCount)
            addReward(animalCfg.highLevelProd, animalData.highLevelProdCount)
        end
    end
    table.sort(rewardItems, Utils.genSortFunction({"rarity", "sortId1", "sortId2", "itemId"}, false))
    return rewardItems
end

InnFeedManageCtrl._RefreshRewardItems = HL.Method() << function(self)
    local rewardItems = self:_CollectRewardItems()
    local hasReward = #rewardItems > 0
    self.view.bottomNodeState:SetState(hasReward and "Normal" or "Null")
    local rewardNaviGroup = self.view.rewardLayoutSelectableNaviGroup
    if not hasReward and rewardNaviGroup.IsTopLayer then
        rewardNaviGroup:ManuallyStopFocus()
    end
    self.view.rewardKeyHint.gameObject:SetActive(hasReward)
    self.m_rewardCells:Refresh(#rewardItems, function(cell, index)
        local rewardItem = rewardItems[index]
        local item = cell
        local shouldShowTips = item.showingTips or (DeviceInfo.usingController and item.view.button.isNaviTarget)
        if item.showingTips then
            Notify(MessageConst.HIDE_ITEM_TIPS)
            item:_OnTipsClosed()
        end
        item:InitItem({
            id = rewardItem.itemId,
            count = rewardItem.itemCount,
        }, true)
        item:SetExtraInfo({
            isSideTips = true,
            onBeforeJump = function()
                self.view.rewardLayoutSelectableNaviGroup:ManuallyStopFocus()
            end,
        })
        if shouldShowTips then
            item:ShowTips()
        end
    end)
    InputManagerInst:ToggleBinding(rewardNaviGroup.FocusBindingId,
                                   hasReward and not rewardNaviGroup.IsTopLayer)
end

InnFeedManageCtrl._ShowInstruction = HL.Method() << function(self)
    self.m_instructionShown = true
    UIManager:Open(PanelId.InstructionBook, {
        id = Tables.ranchConst.instructionId,
        onClose = function()
            self.m_instructionShown = false
        end
    })
end

InnFeedManageCtrl._UpdateStableTitle = HL.Method(HL.Any, HL.Number) << function(self, go, csIndex)
    local title = self.m_getTitleFunc(go)
    local groupCfg = self.m_stableGroupCfg[LuaIndex(csIndex)]
    title.stateController:SetState(groupCfg.style)
end

InnFeedManageCtrl._UpdateStableCell = HL.Method(HL.Any, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getCellFunc(go)
    local index = LuaIndex(csIndex)
    local stableCfg = self.m_stableCellCfg[index]
    local _, stableGroupId = Tables.innRanchStableId2GroupId:TryGetValue(stableCfg.stableId)
    local _, stableGroupCfg = Tables.innRanchStableGroupTable:TryGetValue(stableGroupId)
    cell.gameObject.name = string.format("StableCell_%d", index)
    cell:InitRanchStableCell({
        ranchId = self.m_ranchId,
        stableId = stableCfg.stableId,
        stableCfg = stableCfg,
        stableGroupId = stableGroupId,
        style = stableGroupCfg.style,
        playUnlockCamera = self.m_openedFromInteractive,
    })
end

InnFeedManageCtrl._OnStableUnlocked = HL.Method(HL.Any) << function(self, arg)
    local poiType, _ , _ = unpack(arg)
    if poiType ~= GEnums.DomainPoiType.Ranch then
        return
    end
    if not self.m_openedFromInteractive then
        self:_RefreshAllUIs(false)
        return
    end
    
    
    self:Hide()
    self.m_unlockReshowDelayTimer = self:_StartTimer(Tables.ranchConst.reopenDelayAfterStableUnlock, function()
        self.m_unlockReshowDelayTimer = -1
        self:Show()
        self:_RefreshAllUIs(false)
    end)
end

InnFeedManageCtrl._OnHarvestSuccess = HL.Method(HL.Any) << function(self, arg)
    
    local _, items = unpack(arg)
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        items = items,
    })
    
    local domainId = Utils.getCurDomainId()
    local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    local domainName = domainCfg.domainName
    Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_RANCH_HARVEST_SUCCESS_TOAST, domainName))
end

InnFeedManageCtrl._OnWalletChanged = HL.Method(HL.Any) << function(self, arg)
    local moneyId = unpack(arg)
    if moneyId ~= self.m_moneyId then
        return
    end
    self:_RefreshAllUIs(false)
end

InnFeedManageCtrl._OnRanchProductUpdated = HL.Method() << function(self)
    self:_RefreshRewardItems()
end

InnFeedManageCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        ranchId = self.m_ranchId,
        fromInteractive = self.m_openedFromInteractive,
        showInstruction = self.m_instructionShown,
    }
end

HL.Commit(InnFeedManageCtrl)
