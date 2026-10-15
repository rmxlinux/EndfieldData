local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnDetail
local PHASE_ID = PhaseId.InnDetail

InnDetailCtrl = HL.Class('InnDetailCtrl', uiCtrl.UICtrl)

InnDetailCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_ADD_EXP] = '_OnInnExpChanged',
    [MessageConst.ON_INN_LEVEL_UP] = '_OnInnLevelUp',
}

InnDetailCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnDetailCtrl.m_curLevel = HL.Field(HL.Number) << 0
InnDetailCtrl.m_isMaxLevel = HL.Field(HL.Boolean) << false
InnDetailCtrl.m_pendingDialogId = HL.Field(HL.String) << ""
InnDetailCtrl.m_pendingDialogEndAction = HL.Field(HL.Function)


InnDetailCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_curLevel = self.m_innSystem.innLevel

    self.view.btnClose.onClick:AddListener(function()
        if not PhaseManager:CanPopPhase(PHASE_ID) then
            return
        end
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.upgradeBtn.onClick:AddListener(function()
        self:_OnUpgradeBtnClick()
    end)

    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "inn_system")
    end)

    self.view.recipeNode.button.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.InnRecipeOverview)
    end)

    self.view.topicNode.button.onClick:AddListener(function()
        if self.m_curLevel <= 1 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_TOPIC_UNLOCK_AT_LEVEL2)
            return
        end
        PhaseManager:OpenPhase(PhaseId.InnTopicSelect)
    end)

    self.view.milestoneNode.button.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.InnMilestone)
    end)

    self.view.charaNode.button.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.InnCharAddition)
    end)

    self.view.milestoneNode.redDot:InitRedDot("InnMilestone")
    self.view.topicNode.redDot:InitRedDot("InnTopic")
    self.view.recipeNode.redDot:InitRedDot("InnRecipe")

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self:_InitWalletBar()

    self:_Refresh()
    self:_RefreshActivityTask()

    if DeviceInfo.usingController then
        self:SetNaviTarget(self.view.recipeNode.button)
    end
end

InnDetailCtrl.OnClose = HL.Override() << function(self)
    self:_ClearPendingDialogAction()
end




InnDetailCtrl._InitWalletBar = HL.Method() << function(self)
    local moneyInfos = {
        { moneyId = "inn_customer_volume_display", clearRuleType = GEnums.MoneyClearRuleType.None },
    }
    if self.m_innSystem.innLevel > 1 then
        table.insert(moneyInfos, 1, { moneyId = "inn_star_display", clearRuleType = GEnums.MoneyClearRuleType.None })
    end
    self.view.walletBarPlaceholder:InitWalletBarPlaceholderDetailed(moneyInfos)
end






InnDetailCtrl._Refresh = HL.Method() << function(self)
    self.m_curLevel = self.m_innSystem.innLevel

    local maxLevel = 0
    for level, _ in pairs(Tables.innLevelTable) do
        if level > maxLevel then
            maxLevel = level
        end
    end
    self.m_isMaxLevel = self.m_curLevel >= maxLevel

    self:_RefreshLevelInfo()
    self:_RefreshExpProgress()
    self:_RefreshGradeDetail()
    self:_RefreshStatistics()
    self:_RefreshUpgradeConditions()
    self:_RefreshUpgradeBtn()
end






InnDetailCtrl._RefreshLevelInfo = HL.Method() << function(self)
    self.view.levelTxt.text = tostring(self.m_curLevel)

    local success, curData = Tables.innLevelTable:TryGetValue(self.m_curLevel)
    if success then
        self.view.tipRateText.text = string.format("%.0f%%", curData.tipRate * 100)
        self.view.rareRateText.text = string.format("%.0f%%", curData.rareRate * 100)
    end

    if self.m_isMaxLevel then
        self.view.levelState:SetState("UpperLimit")
    else
        self.view.levelState:SetState("Lv")
        self.view.curLvTxt.text = tostring(self.m_curLevel)
        self.view.nextLvTxt.text = tostring(self.m_curLevel + 1)
    end

    if self.m_curLevel > 1 then
        self.view.topicNode.stateController:SetState("Normal")
    else
        self.view.topicNode.stateController:SetState("Lock")
    end
end






InnDetailCtrl._RefreshExpProgress = HL.Method() << function(self)
    if self.m_isMaxLevel then
        self.view.progress.fillAmount = 1
        self.view.expText.text = "MAX"
        return
    end

    local success, nextData = Tables.innLevelTable:TryGetValue(self.m_curLevel + 1)
    local requiredExp = success and nextData.exp or 0
    local currentExp = math.min(self.m_innSystem.innExp, requiredExp)

    if requiredExp > 0 then
        local _, curData = Tables.innLevelTable:TryGetValue(self.m_curLevel)
        currentExp = currentExp - curData.exp
        requiredExp = requiredExp - curData.exp
        self.view.progress.fillAmount = currentExp / requiredExp
        self.view.expText.text = string.format("%d<color=#7a7a7a>/%d</color>", currentExp, requiredExp)
    else
        self.view.progress.fillAmount = 1
        self.view.expText.text = tostring(currentExp)
    end
end






local JSSPSI_DUTY_STATE_MAP = {
    [GEnums.JsspsiDutyType.ServeDish] = "Serving",
    [GEnums.JsspsiDutyType.ServeDrink] = "Wine",
    [GEnums.JsspsiDutyType.Checkout] = "Bill",
}

InnDetailCtrl._RefreshGradeDetail = HL.Method() << function(self)
    local curLevel = self.m_curLevel
    local successCur, curData = Tables.innLevelTable:TryGetValue(curLevel)
    if not successCur then
        return
    end

    local detail = self.view.gradeDetailNode
    local inn = self.m_innSystem

    if self.m_isMaxLevel then
        local function showNode(node, val, fmt)
            node.gameObject:SetActive(true)
            node.num1Txt.text = fmt and string.format(fmt, val) or tostring(val)
            node.num2Txt.gameObject:SetActive(false)
        end

        showNode(detail.tableNode, curData.deskNum)
        showNode(detail.customerNode, curData.customerVolume)
        showNode(detail.chefNode, inn.kitchenCharSlotMaxNum)
        showNode(detail.kitchenNode, inn.kitchenNum)
        showNode(detail.counterNode, inn.servingCounterSize)
        showNode(detail.trayNode, inn.foodTraySize)

        local kitchenQueueSize = Tables.innManagementConst.initKitchenQueueSize
        for _, expData in pairs(Tables.innExpansionTable) do
            if inn:IsExtendEntryUnlocked(expData.id) then
                kitchenQueueSize = kitchenQueueSize + expData.addKitchenQueueSize
            end
        end
        showNode(detail.kitchenSeqNode, kitchenQueueSize)

        detail.lockNode.gameObject:SetActive(false)
        detail.tipNode.gameObject:SetActive(false)
        detail.dishNode.gameObject:SetActive(false)
        detail.getDishNode.gameObject:SetActive(false)
    else
        local successNext, nextData = Tables.innLevelTable:TryGetValue(curLevel + 1)

        local function showChangeNode(node, curVal, nextVal, fmt)
            local changed = successNext and nextVal ~= curVal
            node.gameObject:SetActive(changed)
            if changed then
                node.num1Txt.text = fmt and string.format(fmt, curVal) or tostring(curVal)
                node.num2Txt.gameObject:SetActive(true)
                node.num2Txt.text = fmt and string.format(fmt, nextVal) or tostring(nextVal)
            end
        end

        showChangeNode(detail.tableNode, curData.deskNum,
            successNext and nextData.deskNum or 0)
        showChangeNode(detail.customerNode, curData.customerVolume,
            successNext and nextData.customerVolume or 0)
        showChangeNode(detail.tipNode, curData.tipRate * 100,
            successNext and nextData.tipRate * 100 or 0, "%.0f%%")
        showChangeNode(detail.dishNode, curData.rareRate * 100,
            successNext and nextData.rareRate * 100 or 0, "%.0f%%")
        showChangeNode(detail.getDishNode, curData.menuDishTypeNumMin,
            successNext and nextData.menuDishTypeNumMin or 0)
        showChangeNode(detail.chefNode, inn.kitchenCharSlotMaxNum,
            successNext and inn.kitchenCharSlotMaxNum+nextData.kitchenStuffNum-curData.kitchenStuffNum or inn.kitchenCharSlotMaxNum)

        detail.kitchenNode.gameObject:SetActive(false)
        detail.counterNode.gameObject:SetActive(false)
        detail.trayNode.gameObject:SetActive(false)
        detail.kitchenSeqNode.gameObject:SetActive(false)

        local hasNewDuty = successNext and nextData.newJsspsiDuty ~= GEnums.JsspsiDutyType.None
        detail.lockNode.gameObject:SetActive(hasNewDuty)
        if hasNewDuty then
            local stateStr = JSSPSI_DUTY_STATE_MAP[nextData.newJsspsiDuty]
            if stateStr then
                detail.conState:SetState(stateStr)
            end
        end
    end
end






InnDetailCtrl._RefreshStatistics = HL.Method() << function(self)
    local inn = self.m_innSystem
    self.view.totalGuestNumTxt.text = tostring(inn.totalServeGuestCount)
    self.view.specialGuestNumTxt.text = tostring(inn.serveSpecialGuestCountRecord:GetSum())
    local foodRecord = inn.serveFoodRecordCountRecord
    local drinkCategoryId = CS.Beyond.Cfg.Tables.innManagementCategoryIdToNum:GetValue("drink")
    self.view.serveFoodNumTxt.text = tostring(foodRecord:GetSum() - foodRecord:GetValue(drinkCategoryId))
    self.view.maxComboNumTxt.text = tostring(inn.maxComboCount)
end






InnDetailCtrl._RefreshUpgradeConditions = HL.Method() << function(self)
    local starNode = self.view.starRatingNode
    local taskNode = self.view.taskNode
    local expNode = self.view.expNode

    if self.m_isMaxLevel then
        starNode.gameObject:SetActive(false)
        taskNode.gameObject:SetActive(false)
        expNode.gameObject:SetActive(false)
        return
    end

    local successNext, nextData = Tables.innLevelTable:TryGetValue(self.m_curLevel + 1)

    local unlockStar = successNext and nextData.unlockStar or 0
    if unlockStar > 0 then
        starNode.gameObject:SetActive(true)
        starNode.nameText.text = string.format(Language.LUA_INN_DETAIL_STAR_RATING_NAME, unlockStar)
        local currentStar = self.m_innSystem.starRecord:GetSum()
        starNode.valueTxt.text = string.format(Language.LUA_INN_DETAIL_STAR_RATING_VALUE, currentStar, unlockStar)
        starNode.stateController:SetState(currentStar >= unlockStar and "Complete" or "Normal")
        starNode.btnJump.onClick:RemoveAllListeners()
        starNode.btnJump.onClick:AddListener(function()
            if currentStar < unlockStar then
                InnUtils.openTopicSelection()
            else
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DETAIL_TASK_COMPLETED_TOAST)
            end
        end)
    else
        starNode.gameObject:SetActive(false)
    end

    local questId = successNext and nextData.unlockQuest or ""
    if not string.isEmpty(questId) then
        taskNode.gameObject:SetActive(true)
        taskNode.nameText.text = nextData.unlockQuestDesc or ""
        local questDone = GameInstance.player.mission:IsQuestCompleted(questId)
        taskNode.stateController:SetState(questDone and "Complete" or "Normal")
        taskNode.btnJump.onClick:RemoveAllListeners()
        taskNode.btnJump.onClick:AddListener(function()
            if not questDone then
                local missionId = GameInstance.player.mission:GetMissionIdByQuestId(questId)
                if missionId then
                    PhaseManager:OpenPhase(PhaseId.Mission, { autoSelect = missionId, useBlackMask = true })
                end
            else
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DETAIL_TASK_COMPLETED_TOAST)
            end
        end)
    else
        taskNode.gameObject:SetActive(false)
    end

    local requiredExp = successNext and nextData.exp or 0
    if requiredExp > 0 then
        expNode.gameObject:SetActive(true)
        local currentExp = tonumber(self.m_innSystem.innExp) or 0
        local expReached = currentExp >= requiredExp
        expNode.stateController:SetState(expReached and "Complete" or "Normal")
        expNode.btnJump.onClick:RemoveAllListeners()
        expNode.btnJump.onClick:AddListener(function()
            if not expReached then
                InnUtils.openTopicSelection()
            else
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DETAIL_TASK_COMPLETED_TOAST)
            end
        end)
    else
        expNode.gameObject:SetActive(false)
    end
end






InnDetailCtrl._RefreshActivityTask = HL.Method() << function(self)
    if self.view.innTaskTips then
        self.view.innTaskTips:InitActivityTaskEntry({activityId = "activity_timelimited_inn"})
    end
end






InnDetailCtrl._RefreshUpgradeBtn = HL.Method() << function(self)
    if self.m_isMaxLevel then
        self.view.btnState.gameObject:SetActive(false)
        return
    end

    self.view.btnState.gameObject:SetActive(true)

    local successNext, nextData = Tables.innLevelTable:TryGetValue(self.m_curLevel + 1)
    local requiredExp = successNext and nextData.exp or 0
    local currentExp = tonumber(self.m_innSystem.innExp) or 0
    local questId = successNext and nextData.unlockQuest or ""
    local questDone = string.isEmpty(questId) or GameInstance.player.mission:IsQuestCompleted(questId)

    local unlockStar = successNext and nextData.unlockStar or 0
    local currentStar = self.m_innSystem.starRecord:GetSum()
    local starDone = unlockStar <= 0 or currentStar >= unlockStar

    if currentExp < requiredExp then
        self.view.btnState:SetState("Experience")
    elseif not questDone or not starDone then
        self.view.btnState:SetState("Incomplete ")
    else
        self.view.btnState:SetState("StartRating")
    end
end

InnDetailCtrl._OnUpgradeBtnClick = HL.Method() << function(self)
    if self.m_isMaxLevel then
        return
    end
    self.m_innSystem:SendLevelUp()
end

InnDetailCtrl._ClearPendingDialogAction = HL.Method() << function(self)
    if not string.isEmpty(self.m_pendingDialogId) and self.m_pendingDialogEndAction then
        GameWorld.dialogManager:UnRegisterDialogEndOnceAction(self.m_pendingDialogId, self.m_pendingDialogEndAction)
        self.m_pendingDialogId = ""
        self.m_pendingDialogEndAction = nil
    end
end






InnDetailCtrl._OnInnExpChanged = HL.Method(HL.Any) << function(self, _)
    self:_RefreshExpProgress()
    self:_RefreshUpgradeBtn()
end

InnDetailCtrl._OnInnLevelUp = HL.Method(HL.Any) << function(self, eventArgs)
    local newLevel = unpack(eventArgs)

    local success, levelData = Tables.innLevelTable:TryGetValue(newLevel)
    local dialogId = success and levelData.levelUpDialogue or ""
    if not string.isEmpty(dialogId) then
        self:_ClearPendingDialogAction()
        local action = function(_)
            self.m_pendingDialogId = ""
            self.m_pendingDialogEndAction = nil
            self:_OpenInnRating(newLevel)
        end
        self.m_pendingDialogId = dialogId
        self.m_pendingDialogEndAction = action
        GameWorld.dialogManager:RegisterDialogEndOnceAction(dialogId, action)
        GameWorld.dialogManager:PlayDialogByJsonId(dialogId)
        self:_StartTimer(1, function()
            self.view.gameObject:SetActive(false)
        end)
    else
        self.view.gameObject:SetActive(false)
        self:_OpenInnRating(newLevel)
    end
end

InnDetailCtrl._OpenInnRating = HL.Method(HL.Number) << function(self, targetLevel)
    UIManager:Open(PanelId.InnRating, {
        targetLevel = targetLevel,
        closeCallback = function()
            if not IsNull(self.view.gameObject) then
                self.view.gameObject:SetActive(true)
                self:_Refresh()
            end
        end,
    })
end




HL.Commit(InnDetailCtrl)
