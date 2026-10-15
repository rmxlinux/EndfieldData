local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnTopicSelection
local PHASE_ID = PhaseId.InnTopicSelection

local PRIVATE_CHEF_RED_DOT_NAME = "InnPrivateChefNew"
local PRIVATE_CHEF_NEW_VAR_KEY = "inn_private_chef_new"
local PRIVATE_CHEF_NEW_READ_LOCKED = 1    
local PRIVATE_CHEF_NEW_READ_UNLOCKED = 2  

local NO_TOPIC_RED_DOT_NAME = "InnNoTopicNew"
local NO_TOPIC_NEW_VAR_KEY = "inn_no_topic_new"
local NO_TOPIC_NEW_READ = 1  

InnTopicSelectionCtrl = HL.Class('InnTopicSelectionCtrl', uiCtrl.UICtrl)







InnTopicSelectionCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_CUSTOMER_VOLUME_CHANGED] = '_OnInnCustomerVolumeChanged',
    [MessageConst.ON_INN_DAILY_FASHION_CHANGED] = '_OnInnDailyFashionChanged',
}

InnTopicSelectionCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem) << nil

InnTopicSelectionCtrl.m_normalTopicIds = HL.Field(HL.Table)

InnTopicSelectionCtrl.m_privateChefTopicId = HL.Field(HL.String) << ""

InnTopicSelectionCtrl.m_isPrivateChefOpen = HL.Field(HL.Boolean) << false

InnTopicSelectionCtrl.m_privateChefCor = HL.Field(HL.Thread)


InnTopicSelectionCtrl.m_selectedTopicId = HL.Field(HL.String) << ""

InnTopicSelectionCtrl.m_preSelectedTopicId = HL.Field(HL.String) << ""

InnTopicSelectionCtrl.m_topicCellCache = HL.Field(HL.Forward("UIListCache"))

InnTopicSelectionCtrl.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))

InnTopicSelectionCtrl.m_hasShownOnce = HL.Field(HL.Boolean) << false

InnTopicSelectionCtrl.m_isPlayingNextOut = HL.Field(HL.Boolean) << false


InnTopicSelectionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem

    self.view.commonTopTitleNode.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.btnStart.button.onClick:AddListener(function()
        local softOpening = false
        
        if self.m_innSystem and self.m_innSystem:IsTeachingMode() then
            softOpening = true
        end

        self:_OpenKitchenSettings(softOpening)
    end)

    self.view.btnSoftOpen.onClick:AddListener(function()
        self:_OpenKitchenSettings(true)
    end)

    self.view.btnRewardDetails.onClick:AddListener(function()
        UIManager:Open(PanelId.InnRewardDetailsPopup, { topicId = self.m_selectedTopicId })
    end)

    self.view.tipsBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_COMMON_TIPS, {
            text = Language.LUA_INN_TOPIC_SELECTION_TIPS,
            transform = self.view.tipsPos,
            posType = UIConst.UI_TIPS_POS_TYPE.LeftDown,
        })
    end)

    self.m_rewardCellCache = UIUtils.genCellCache(self.view.itemSmallReward)

    self.m_topicCellCache = UIUtils.genCellCache(self.view.listNode.topicCell)

    self:_RefreshCustomerVolume()
    self:_BuildTopicData()

    
    self.m_selectedTopicId = self:_ResolveSelectedTopicId(arg and arg.topicId or nil)

    self:_InitFixedCell(self.view.listNode.noTopicCell, "")
    self:_RefreshPrivateChefNode()
    local innLevel = self.m_innSystem.innLevel
    self.view.listNode.lockAll.gameObject:SetActive(innLevel <= 1)
    local normalTopicCount = innLevel > 1 and #self.m_normalTopicIds or 0
    local restoreScrollValue = arg and arg.scrollValue or nil
    if restoreScrollValue then
        self.m_topicCellCache:Refresh(normalTopicCount, function(cell, index)
            self:_InitTopicCell(cell, self.m_normalTopicIds[index])
        end)
        self.view.listNode.scrollList.verticalNormalizedPosition = restoreScrollValue
    else
        self.m_topicCellCache:GraduallyRefresh(normalTopicCount, self.view.config.TOPIC_CELL_REFRESH_INTERVAL, function(cell, index)
            local topicId = self.m_normalTopicIds[index]
            self:_InitTopicCell(cell, topicId)
            if topicId == self.m_selectedTopicId then
                self:_ScrollToSelectedTopic()
            end
        end)
        self:_ScrollToSelectedTopic()
    end
    self:_TrySetDefaultNaviTarget()

    self:_TryReadTopicRedDot(self.m_selectedTopicId)

    self:_RefreshDetail()
    self:_RefreshReward()

    local moneyInfos = {
        { moneyId = "inn_customer_volume_display", clearRuleType = GEnums.MoneyClearRuleType.None },
    }
    if self.m_innSystem.innLevel > 1 then
        table.insert(moneyInfos, 1, { moneyId = "inn_star_display", clearRuleType = GEnums.MoneyClearRuleType.None })
    end
    self.view.commonTopTitleNode.walletBarPlaceholder:InitWalletBarPlaceholderDetailed(moneyInfos)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnTopicSelectionCtrl.OnShow = HL.Override() << function(self)
    if self.m_hasShownOnce then
        self:PlayAnimation("inntopicselection_in")
    end
    self.m_hasShownOnce = true
end




InnTopicSelectionCtrl.OnClose = HL.Override() << function(self)
    RedDotUtils.markAllUnlockedInnTopicsRead()
end

InnTopicSelectionCtrl._OnInnCustomerVolumeChanged = HL.Method(HL.Any) << function(self, arg)
    self:_RefreshCustomerVolume()
end

InnTopicSelectionCtrl._OnInnDailyFashionChanged = HL.Method() << function(self)
    self:_InitFixedCell(self.view.listNode.noTopicCell, "")
    if not string.isEmpty(self.m_privateChefTopicId) and self.m_isPrivateChefOpen then
        self:_InitFixedCell(self.view.listNode.privateChefNode.topicCell, self.m_privateChefTopicId)
    end
    self:_RefreshDetail()
end

InnTopicSelectionCtrl._OpenKitchenSettings = HL.Method(HL.Boolean) << function(self, softOpening)
    if self.m_isPlayingNextOut then
        return
    end
    self.m_isPlayingNextOut = true
    self.view.luaPanel:BlockAllInput()
    self:PlayAnimation("inntopicselection_next_out", function()
        self.m_isPlayingNextOut = false
        if self.m_isClosed then
            return
        end
        self.view.luaPanel:RecoverAllInput()
        self.m_innSystem.gameSetting.topicId = self.m_selectedTopicId
        self.m_innSystem.gameSetting.softOpening = softOpening
        if self.m_preSelectedTopicId ~= self.m_selectedTopicId then
            self.m_innSystem.gameSetting.kitchenSettings:Clear()
            self.m_innSystem.gameSetting.menuItems:Clear()
            self.m_innSystem.gameSetting.autoDuty:Clear()
        end
        PhaseManager:OpenPhase(PhaseId.InnKitchenSettings, {
            topicId = self.m_selectedTopicId,
        })
        self.m_preSelectedTopicId = self.m_selectedTopicId
    end)
end

InnTopicSelectionCtrl._RefreshCustomerVolume = HL.Method() << function(self)
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local hasLevel, levelData = Tables.innLevelTable:TryGetValue(innLevel)
    local cost = (hasLevel and levelData and levelData.customerVolumeCost) or 0
    local volume = (self.m_innSystem and self.m_innSystem.customerVolume) or 0

    local isShortCustomer = volume < cost
    local costColor = isShortCustomer and self.view.config.CUSTOMER_VOLUME_SHORT_COLOR or self.view.config.CUSTOMER_VOLUME_ENOUGH_COLOR
    self.view.customerVolumeCostTxt.text = Language.ui_inntopicselection_consumenode_consumetxt
        .. string.format(UIConst.COLOR_NUMBER_FORMAT, costColor, cost)
    self.view.btnStart.stateController:SetState(isShortCustomer and "DisableState" or "NormalState")
    InputManagerInst:ToggleGroup(self.view.btnStart.button.groupId, not isShortCustomer)
end

InnTopicSelectionCtrl._BuildTopicData = HL.Method() << function(self)
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local normalInfos = {}
    local privateChefTopicId = ""
    for topicId, topicData in pairs(Tables.innTopicTable) do
        if topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef then
            privateChefTopicId = topicId
        else
            
            local unlockLevel = (topicData and topicData.unlockLevel) or 0
            local isUnlocked = innLevel >= unlockLevel
            local totalStars = (topicData and topicData.starRequiredScore and topicData.starRequiredScore.Count) or 0
            local currentStars = (self.m_innSystem and self.m_innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId))) or 0
            local isFullStar = currentStars >= totalStars
            normalInfos[#normalInfos + 1] = {
                id = topicId,
                sortId = topicData and topicData.sortId or 0,
                
                unlockSortId = isUnlocked and 1 or 2,
                
                starSortId = isUnlocked and (isFullStar and 2 or 1) or 0,
            }
        end
    end
    table.sort(normalInfos, Utils.genSortFunction({ "unlockSortId", "starSortId", "sortId", "id" }, true))

    local normalTopicIds = {}
    for _, info in ipairs(normalInfos) do
        normalTopicIds[#normalTopicIds + 1] = info.id
    end
    self.m_normalTopicIds = normalTopicIds
    self.m_privateChefTopicId = privateChefTopicId

    
    local openTimeId = (Tables.innManagementConst and Tables.innManagementConst.privateChefOpenTime) or ""
    self.m_isPrivateChefOpen = Utils.isCurTimeInTimeIdRange(openTimeId, true)
end


InnTopicSelectionCtrl._ResolveSelectedTopicId = HL.Method(HL.Opt(HL.String)).Return(HL.String) << function(self, topicId)
    if topicId ~= nil and self:_IsSelectableTopic(topicId) then
        return topicId
    end

    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    for _, normalId in ipairs(self.m_normalTopicIds) do
        local hasTopic, topicData = Tables.innTopicTable:TryGetValue(normalId)
        if hasTopic and topicData then
            local unlockLevel = topicData.unlockLevel or 0
            if innLevel >= unlockLevel then
                local totalStars = (topicData.starRequiredScore and topicData.starRequiredScore.Count) or 0
                local currentStars = (self.m_innSystem and self.m_innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(normalId))) or 0
                if currentStars < totalStars then
                    return normalId
                end
            end
        end
    end
    return ""
end


InnTopicSelectionCtrl._IsSelectableTopic = HL.Method(HL.String).Return(HL.Boolean) << function(self, topicId)
    if string.isEmpty(topicId) then
        return true
    end
    if topicId == self.m_privateChefTopicId then
        return self.m_isPrivateChefOpen
    end
    for _, normalId in ipairs(self.m_normalTopicIds) do
        if normalId == topicId then
            return true
        end
    end
    return false
end


InnTopicSelectionCtrl._RefreshPrivateChefNode = HL.Method() << function(self)
    if self.m_privateChefCor then
        self.m_privateChefCor = self:_ClearCoroutine(self.m_privateChefCor)
    end

    local privateChefNode = self.view.listNode.privateChefNode
    if string.isEmpty(self.m_privateChefTopicId) then
        privateChefNode.gameObject:SetActiveIfNecessary(false)
        return
    end
    privateChefNode.gameObject:SetActiveIfNecessary(true)

    if self.m_isPrivateChefOpen then
        privateChefNode.lockedNode.gameObject:SetActiveIfNecessary(false)
        privateChefNode.topicCell.gameObject:SetActiveIfNecessary(true)
        self:_InitFixedCell(privateChefNode.topicCell, self.m_privateChefTopicId)
        privateChefNode.topicCell.view.redDot.view.gameObject:SetActiveIfNecessary(true)
        privateChefNode.topicCell.view.redDot:InitRedDot(PRIVATE_CHEF_RED_DOT_NAME, nil, nil, self.view.listNode.redDotScrollRect)
        return
    end

    
    privateChefNode.topicCell.gameObject:SetActiveIfNecessary(false)
    privateChefNode.lockedNode.gameObject:SetActiveIfNecessary(true)

    local unlockLevel = (Tables.innManagementConst and Tables.innManagementConst.privateChefUnlockLevel) or 0
    privateChefNode.lockTxt.text = string.format(Language.LUA_INN_PRIVATE_CHEF_LOCK_LEVEL, unlockLevel)

    local openTimeId = (Tables.innManagementConst and Tables.innManagementConst.privateChefOpenTime) or ""
    self:_UpdatePrivateChefOpenTime(openTimeId)
    self.m_privateChefCor = self:_StartCoroutine(function()
        while not Utils.isCurTimeInTimeIdRange(openTimeId, true) do
            self:_UpdatePrivateChefOpenTime(openTimeId)
            coroutine.wait(1)
        end
        self:_OnPrivateChefOpened()
    end)
end

InnTopicSelectionCtrl._UpdatePrivateChefOpenTime = HL.Method(HL.String) << function(self, openTimeId)
    local openTs = Utils.getTimeIdOpenTimeStamp(openTimeId)
    local curTs = DateTimeUtils.GetCurrentTimestampBySeconds()
    local leftSec = (openTs and (openTs - curTs)) or 0
    if leftSec < 0 then
        leftSec = 0
    end
    self.view.listNode.privateChefNode.openTimeTxt.text =
        string.format(Language.LUA_INN_PRIVATE_CHEF_OPEN_TIME, UIUtils.getLeftTime(leftSec))
end

InnTopicSelectionCtrl._OnPrivateChefOpened = HL.Method() << function(self)
    self.m_privateChefCor = nil
    self.m_isPrivateChefOpen = true

    local privateChefNode = self.view.listNode.privateChefNode
    privateChefNode.lockedNode.gameObject:SetActiveIfNecessary(false)
    privateChefNode.topicCell.gameObject:SetActiveIfNecessary(true)
    self:_InitFixedCell(privateChefNode.topicCell, self.m_privateChefTopicId)
    privateChefNode.topicCell.view.redDot.view.gameObject:SetActiveIfNecessary(true)
    privateChefNode.topicCell.view.redDot:InitRedDot(PRIVATE_CHEF_RED_DOT_NAME, nil, nil, self.view.listNode.redDotScrollRect)
end

InnTopicSelectionCtrl._InitTopicCell = HL.Method(HL.Any, HL.String) << function(self, cell, topicId)
    self:_InitFixedCell(cell, topicId)
    cell.gameObject.name = topicId
    
    if topicId == self.m_selectedTopicId then
        self:SetNaviTarget(cell.view.naviTarget)
    end
end

InnTopicSelectionCtrl._InitFixedCell = HL.Method(HL.Any, HL.String) << function(self, cell, topicId)
    cell:InitInnTopicEntry({
        topicId = topicId,
        showDetailTip = false,
        onClick = function()
            self:_SelectTopic(topicId)
        end,
    })
    cell:SetSelected(topicId == self.m_selectedTopicId, false)
    cell.view.naviTarget.onGroupSetAsNaviTarget:RemoveAllListeners()
    cell.view.naviTarget.onGroupSetAsNaviTarget:AddListener(function(select)
        if select then
            self:_SelectTopic(topicId)
        end
    end)
    if cell.view.redDot then
        if string.isEmpty(topicId) then
            cell.view.redDot:InitRedDot(NO_TOPIC_RED_DOT_NAME, nil, nil, self.view.listNode.redDotScrollRect)
        else
            cell.view.redDot:InitRedDot("InnTopicSingle", topicId, nil, self.view.listNode.redDotScrollRect)
        end
    end
end

InnTopicSelectionCtrl._TryReadNoTopicRedDot = HL.Method() << function(self)
    local globalVar = GameInstance.player and GameInstance.player.globalVar
    if not globalVar then
        return
    end
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local fashionUnlockLevel = (Tables.innManagementConst and Tables.innManagementConst.fashionUnlockLevel) or 0
    if innLevel < fashionUnlockLevel then
        return
    end
    local _, value = globalVar:TryGetClientVar(NO_TOPIC_NEW_VAR_KEY)
    if (value or 0) < NO_TOPIC_NEW_READ then
        globalVar:SetClientVar(NO_TOPIC_NEW_VAR_KEY, NO_TOPIC_NEW_READ)
        self.view.listNode.noTopicCell.view.redDot:UpdateState()
    end
end

InnTopicSelectionCtrl._TryReadPrivateChefRedDot = HL.Method() << function(self)
    local globalVar = GameInstance.player and GameInstance.player.globalVar
    if not globalVar then
        return
    end
    local _, value = globalVar:TryGetClientVar(PRIVATE_CHEF_NEW_VAR_KEY)
    value = value or 0
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local unlockLevel = (Tables.innManagementConst and Tables.innManagementConst.privateChefUnlockLevel) or 0
    local targetValue = innLevel < unlockLevel and PRIVATE_CHEF_NEW_READ_LOCKED or PRIVATE_CHEF_NEW_READ_UNLOCKED
    if value < targetValue then
        globalVar:SetClientVar(PRIVATE_CHEF_NEW_VAR_KEY, targetValue)
        self.view.listNode.privateChefNode.topicCell.view.redDot:UpdateState()
    end
end

InnTopicSelectionCtrl._TryReadTopicRedDot = HL.Method(HL.String) << function(self, topicId)
    if string.isEmpty(topicId) then
        self:_TryReadNoTopicRedDot()
    elseif topicId == self.m_privateChefTopicId then
        self:_TryReadPrivateChefRedDot()
    else
        RedDotUtils.markInnTopicRead(topicId)
    end
end

InnTopicSelectionCtrl._SelectTopic = HL.Method(HL.String) << function(self, topicId)
    self:_TryReadTopicRedDot(topicId)

    if topicId == self.m_selectedTopicId then
        return
    end
    self.m_selectedTopicId = topicId

    self:_RefreshSelectionVisual()
    self:_RefreshDetail()
    self:_RefreshReward()
    self.view.rightAnim:Play("inntopicselection_right_in")
end

InnTopicSelectionCtrl._RefreshSelectionVisual = HL.Method() << function(self)
    self:_TrySetCellSelectState(self.view.listNode.noTopicCell, "")
    if not string.isEmpty(self.m_privateChefTopicId) and self.m_isPrivateChefOpen then
        self:_TrySetCellSelectState(self.view.listNode.privateChefNode.topicCell, self.m_privateChefTopicId)
    end
    for i = 1, #self.m_normalTopicIds do
        local cell = self.m_topicCellCache:GetItem(i)
        if cell then
            self:_TrySetCellSelectState(cell, self.m_normalTopicIds[i])
        end
    end
end

InnTopicSelectionCtrl._TrySetCellSelectState = HL.Method(HL.Any, HL.String) << function(self, cell, topicId)
    if not cell then
        return
    end
    cell:SetSelected(topicId == self.m_selectedTopicId, true)
end

InnTopicSelectionCtrl._TrySetDefaultNaviTarget = HL.Method() << function(self)
    if string.isEmpty(self.m_selectedTopicId) then
        self:SetNaviTarget(self.view.listNode.noTopicCell.view.naviTarget)
    elseif self.m_selectedTopicId == self.m_privateChefTopicId and self.m_isPrivateChefOpen then
        self:SetNaviTarget(self.view.listNode.privateChefNode.topicCell.view.naviTarget)
    end
end

InnTopicSelectionCtrl._ScrollToSelectedTopic = HL.Method() << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.listNode.scrollList.transform)
    local cell = self:_GetSelectedTopicCell()
    if cell then
        self.view.listNode.scrollList:AutoScrollToRectTransform(cell.rectTransform, true)
    end
end

InnTopicSelectionCtrl._GetSelectedTopicCell = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local topicId = self.m_selectedTopicId
    if string.isEmpty(topicId) then
        return self.view.listNode.noTopicCell
    end
    if topicId == self.m_privateChefTopicId and self.m_isPrivateChefOpen then
        return self.view.listNode.privateChefNode.topicCell
    end
    for i = 1, #self.m_normalTopicIds do
        if self.m_normalTopicIds[i] == topicId then
            return self.m_topicCellCache:GetItem(i)
        end
    end
    return nil
end

InnTopicSelectionCtrl._RefreshDetail = HL.Method() << function(self)
    local topicId = self.m_selectedTopicId
    local isNoTopic = string.isEmpty(topicId)
    local hasTopic, topicData
    if not isNoTopic then
        hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    end

    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local unlockLevel = (topicData and topicData.unlockLevel) or 0
    local isLocked = (not isNoTopic) and hasTopic and innLevel < unlockLevel

    self.view.buttonGroupNode.gameObject:SetActiveIfNecessary(not isLocked)
    self:_RefreshCustomerVolume()

    if isLocked then
        self.view.detailNode.gameObject:SetActive(false)
        self.view.emptyNode.gameObject:SetActive(true)
        self.view.lockLevelTxt.text = string.format(Language.LUA_INN_TOPIC_SELECTION_LOCK_LEVEL, unlockLevel)
    else
        self.view.emptyNode.gameObject:SetActive(false)
        self.view.detailNode.gameObject:SetActive(true)
        self.view.detailNode:InitInnTopicDetailNode({
            topicId = topicId,
            itemTipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
            showHistoryMaxScore = true,
        })
    end
end

InnTopicSelectionCtrl._RefreshReward = HL.Method() << function(self)
    local topicId = self.m_selectedTopicId
    local isNoTopic = string.isEmpty(topicId)
    local hasTopic, topicData
    if not isNoTopic then
        hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    end

    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    local unlockLevel = (topicData and topicData.unlockLevel) or 0
    local isLocked = (not isNoTopic) and hasTopic and innLevel < unlockLevel
    local isPrivateChef = topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef

    
    local showReward = (not isNoTopic) and hasTopic and (not isLocked) and (not isPrivateChef)
    self.view.rewardNode.gameObject:SetActive(showReward)
    if not showReward then
        if self.m_rewardCellCache then
            self.m_rewardCellCache:Refresh(0)
        end
        return
    end

    local currentStar = (self.m_innSystem and self.m_innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId))) or 0

    
    local merged = {}
    local mergedOrder = {}
    local starsRewardId = topicData.starsRewardId
    local starsRewardCount = (starsRewardId and starsRewardId.Count) or 0
    for i = 0, starsRewardCount - 1 do
        local rewardId = starsRewardId[i]
        if not string.isEmpty(rewardId) then
            local hasReward, rewardCfg = Tables.rewardTable:TryGetValue(rewardId)
            if hasReward and rewardCfg and rewardCfg.itemBundles then
                local star = i + 1
                for _, itemBundle in pairs(rewardCfg.itemBundles) do
                    local itemId = itemBundle.id
                    local existing = merged[itemId]
                    if existing then
                        existing.count = existing.count + itemBundle.count
                        if star > existing.maxStar then
                            existing.maxStar = star
                        end
                    else
                        local itemCfg = Tables.itemTable[itemId]
                        local info = {
                            id = itemId,
                            count = itemBundle.count,
                            rarity = (itemCfg and itemCfg.rarity) or 0,
                            sortId1 = (itemCfg and itemCfg.sortId1) or 0,
                            sortId2 = (itemCfg and itemCfg.sortId2) or 0,
                            maxStar = star,
                        }
                        merged[itemId] = info
                        mergedOrder[#mergedOrder + 1] = info
                    end
                end
            end
        end
    end

    
    for _, info in ipairs(mergedOrder) do
        local isRewarded = currentStar >= info.maxStar
        info.gainedSortId = isRewarded and 1 or 2
    end
    table.sort(mergedOrder, Utils.genSortFunction({ "gainedSortId", "rarity", "sortId1", "sortId2", "id" }))

    local showCount = math.min(#mergedOrder, 7)
    self.m_rewardCellCache:Refresh(showCount, function(cell, index)
        local info = mergedOrder[index]
        cell:InitItem({ id = info.id })
        
        cell.view.rewardedCover.gameObject:SetActive(currentStar >= info.maxStar)
    end)
end



InnTopicSelectionCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        topicId = self.m_selectedTopicId,
        scrollValue = self.view.listNode.scrollList.verticalNormalizedPosition,
    }
end



HL.Commit(InnTopicSelectionCtrl)
