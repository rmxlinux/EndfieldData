local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRating


InnRatingCtrl = HL.Class('InnRatingCtrl', uiCtrl.UICtrl)

InnRatingCtrl.s_messages = HL.StaticField(HL.Table) << {}

InnRatingCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnRatingCtrl.m_closeCallback = HL.Field(HL.Function)
InnRatingCtrl.m_targetLevel = HL.Field(HL.Number) << 0
InnRatingCtrl.m_curPageIndex = HL.Field(HL.Number) << 0

InnRatingCtrl.m_unlockDishCache = HL.Field(HL.Forward('UIListCache'))
InnRatingCtrl.m_unlockTopicCache = HL.Field(HL.Forward('UIListCache'))
InnRatingCtrl.m_unlockExpansionCache = HL.Field(HL.Forward('UIListCache'))
InnRatingCtrl.m_unlockUpgradeCache = HL.Field(HL.Forward('UIListCache'))

InnRatingCtrl.m_unlockDishes = HL.Field(HL.Table)
InnRatingCtrl.m_unlockTopics = HL.Field(HL.Table)
InnRatingCtrl.m_unlockExpansions = HL.Field(HL.Table)
InnRatingCtrl.m_unlockUpgrades = HL.Field(HL.Table)

InnRatingCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_targetLevel = arg and arg.targetLevel or (self.m_innSystem.innLevel + 1)
    self.m_closeCallback = arg and arg.closeCallback
    self.m_curPageIndex = 0

    self.view.clickBtn.onClick:AddListener(function()
        self:_OnClickBtn()
    end)

    self.m_unlockDishCache = UIUtils.genCellCache(self.view.unlockDishCell)
    self.m_unlockTopicCache = UIUtils.genCellCache(self.view.unlockTopicCell)
    self.m_unlockExpansionCache = UIUtils.genCellCache(self.view.unlockExpansionCell)
    self.m_unlockUpgradeCache = UIUtils.genCellCache(self.view.unlockUpgradeCell)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self:_CollectUnlockData()
    self:_RefreshHeader()
    self:_RefreshPage()
end

InnRatingCtrl.OnClose = HL.Override() << function(self)
    if self.m_closeCallback then
        self.m_closeCallback()
        self.m_closeCallback = nil
    end
end




InnRatingCtrl._OnClickBtn = HL.Method() << function(self)
    if self.m_curPageIndex == 0 then
        self.m_curPageIndex = 1
        self:_RefreshPage()
    else
        self:Close()
    end
end

InnRatingCtrl._RefreshPage = HL.Method() << function(self)
    if self.m_curPageIndex == 0 then
        self.view.pageState:SetState("One")
        self:_RefreshGradeDetail()
        self:_RefreshUnlockDishes()
        self:_RefreshUnlockTopics()
    else
        self.view.pageState:SetState("Two")
        self:_RefreshUnlockExpansions()
        self:_RefreshUnlockUpgrades()
    end
end






InnRatingCtrl._RefreshHeader = HL.Method() << function(self)
    self.view.lvTxt.text = tostring(self.m_targetLevel)
    local success, targetData = Tables.innLevelTable:TryGetValue(self.m_targetLevel)
    if success then
        self.view.descTxt.text = targetData.unlockDesc or ""
    else
        self.view.descTxt.text = ""
    end
end






InnRatingCtrl._CollectUnlockData = HL.Method() << function(self)
    local targetLevel = self.m_targetLevel

    self.m_unlockDishes = {}
    for _, dishData in pairs(Tables.innDishTable) do
        if dishData.unlockLevel == targetLevel then
            table.insert(self.m_unlockDishes, dishData)
        end
    end

    self.m_unlockTopics = {}
    for _, topicData in pairs(Tables.innTopicTable) do
        if topicData.unlockLevel == targetLevel then
            table.insert(self.m_unlockTopics, topicData)
        end
    end

    self.m_unlockExpansions = {}
    for _, expData in pairs(Tables.innExpansionTable) do
        if expData.unlockLevel == targetLevel then
            table.insert(self.m_unlockExpansions, expData)
        end
    end

    self.m_unlockUpgrades = {}
    local success, targetData = Tables.innLevelTable:TryGetValue(targetLevel)
    if success and targetData.unlockText then
        for i = 0, targetData.unlockText.Count - 1 do
            local text = targetData.unlockText[i]
            if not string.isEmpty(text) then
                table.insert(self.m_unlockUpgrades, text)
            end
        end
    end
end






local JSSPSI_DUTY_STATE_MAP = {
    [GEnums.JsspsiDutyType.ServeDish] = "Serving",
    [GEnums.JsspsiDutyType.ServeDrink] = "Wine",
    [GEnums.JsspsiDutyType.Checkout] = "Bill",
}

InnRatingCtrl._RefreshGradeDetail = HL.Method() << function(self)
    local targetLevel = self.m_targetLevel
    local prevLevel = targetLevel - 1

    local successTarget, targetData = Tables.innLevelTable:TryGetValue(targetLevel)
    local successPrev, prevData = Tables.innLevelTable:TryGetValue(prevLevel)

    if not successTarget then
        return
    end

    local detail = self.view.gradeDetail

    local prevDeskNum = successPrev and prevData.deskNum or 0
    local prevCustomer = successPrev and prevData.customerVolume or 0
    local prevTipRate = successPrev and prevData.tipRate or 0
    local prevRareRate = successPrev and prevData.rareRate or 0

    local hasTableChange = targetData.deskNum ~= prevDeskNum
    detail.tableNode.gameObject:SetActive(hasTableChange)
    if hasTableChange then
        detail.tableNode.num1Txt.text = tostring(prevDeskNum)
        detail.tableNode.num2Txt.text = tostring(targetData.deskNum)
    end

    local hasCustomerChange = targetData.customerVolume ~= prevCustomer
    detail.customerNode.gameObject:SetActive(hasCustomerChange)
    if hasCustomerChange then
        detail.customerNode.num1Txt.text = tostring(prevCustomer)
        detail.customerNode.num2Txt.text = tostring(targetData.customerVolume)
    end

    local hasTipChange = targetData.tipRate ~= prevTipRate
    detail.tipNode.gameObject:SetActive(hasTipChange)
    if hasTipChange then
        detail.tipNode.num1Txt.text = string.format("%.0f%%", prevTipRate * 100)
        detail.tipNode.num2Txt.text = string.format("%.0f%%", targetData.tipRate * 100)
    end

    local hasRareChange = targetData.rareRate ~= prevRareRate
    detail.dishNode.gameObject:SetActive(hasRareChange)
    if hasRareChange then
        detail.dishNode.num1Txt.text = string.format("%.0f%%", prevRareRate * 100)
        detail.dishNode.num2Txt.text = string.format("%.0f%%", targetData.rareRate * 100)
    end

    local hasNewDuty = targetData.newJsspsiDuty ~= GEnums.JsspsiDutyType.None
    detail.lockNode.gameObject:SetActive(hasNewDuty)
    if hasNewDuty then
        local stateStr = JSSPSI_DUTY_STATE_MAP[targetData.newJsspsiDuty]
        if stateStr then
            detail.conState:SetState(stateStr)
        end
    end

    detail.getDishNode.gameObject:SetActive(false)
    detail.kitchenNode.gameObject:SetActive(false)
    detail.counterNode.gameObject:SetActive(false)
    detail.trayNode.gameObject:SetActive(false)
    detail.chefNode.gameObject:SetActive(false)
    detail.kitchenSeqNode.gameObject:SetActive(false)
end






InnRatingCtrl._RefreshUnlockDishes = HL.Method() << function(self)
    self.m_unlockDishCache:Refresh(#self.m_unlockDishes, function(cell, index)
        local data = self.m_unlockDishes[index]
        cell:InitItem({ id = data.recipeId, count = 1 }, true)
        cell:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
    end)
end






InnRatingCtrl._RefreshUnlockTopics = HL.Method() << function(self)
    self.m_unlockTopicCache:Refresh(#self.m_unlockTopics, function(cell, index)
        local data = self.m_unlockTopics[index]
        cell.tagTxt.text = data.name
    end)
end






InnRatingCtrl._RefreshUnlockExpansions = HL.Method() << function(self)
    self.m_unlockExpansionCache:Refresh(#self.m_unlockExpansions, function(cell, index)
        local data = self.m_unlockExpansions[index]
        cell.expansionTxt.text = data.name
    end)
end






InnRatingCtrl._RefreshUnlockUpgrades = HL.Method() << function(self)
    self.m_unlockUpgradeCache:Refresh(#self.m_unlockUpgrades, function(cell, index)
        cell.upgradeTxt.text = self.m_unlockUpgrades[index]
    end)
end




HL.Commit(InnRatingCtrl)
