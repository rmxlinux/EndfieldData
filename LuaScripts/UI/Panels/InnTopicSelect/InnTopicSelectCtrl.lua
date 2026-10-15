local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnTopicSelect
local PHASE_ID = PhaseId.InnTopicSelect

InnTopicSelectCtrl = HL.Class('InnTopicSelectCtrl', uiCtrl.UICtrl)

InnTopicSelectCtrl.s_messages = HL.StaticField(HL.Table) << {
}

InnTopicSelectCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnTopicSelectCtrl.m_topicDataList = HL.Field(HL.Table)

InnTopicSelectCtrl.m_getCell = HL.Field(HL.Function)

InnTopicSelectCtrl.m_openPopupTopicId = HL.Field(HL.String) << ""

InnTopicSelectCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem

    self.view.btnClose.onClick:AddListener(function()
        if not PhaseManager:CanPopPhase(PHASE_ID) then
            return
        end
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self:_InitWalletBar()
    self:_InitScrollList()
    self:_InitController()
    self:_InitRedDot()

    self:_BuildTopicDataList()
    self:_Refresh()

    local recoverTopicId = arg and arg.openPopupTopicId
    if recoverTopicId and not string.isEmpty(recoverTopicId) then
        UIManager:Open(PanelId.InnRewardDetailsPopup, { topicId = recoverTopicId })
    end
end


InnTopicSelectCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshEdgeRedDot()
end

InnTopicSelectCtrl.OnClose = HL.Override() << function(self)
    RedDotUtils.markAllUnlockedInnTopicsRead()
end

InnTopicSelectCtrl._RefreshEdgeRedDot = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if self.view.redDotScrollRect then
        self.view.redDotScrollRect:RegisterRedDotStatesForScrollList()
    end
end




InnTopicSelectCtrl._InitWalletBar = HL.Method() << function(self)
    local moneyInfos = {
        { moneyId = "inn_star_display", clearRuleType = GEnums.MoneyClearRuleType.None },
    }
    self.view.walletBarPlaceholder:InitWalletBarPlaceholderDetailed(moneyInfos)
end

InnTopicSelectCtrl._InitScrollList = HL.Method() << function(self)
    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
end

InnTopicSelectCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnTopicSelectCtrl._InitRedDot = HL.Method() << function(self)
    if self.view.redDotScrollRect then
        self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
            return self:_GetRedDotStateAt(csIndex)
        end
    end
end

InnTopicSelectCtrl._GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, csIndex)
    local data = self.m_topicDataList[LuaIndex(csIndex)]
    if not data then
        return 0
    end
    local hasRedDot, redDotType = RedDotManager:GetRedDotState("InnTopicSingle", data.id)
    if hasRedDot then
        return redDotType
    end
    return 0
end






InnTopicSelectCtrl._BuildTopicDataList = HL.Method() << function(self)
    local topicDataList = {}
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0

    for topicId, topicData in pairs(Tables.innTopicTable) do
        if topicData.topicType ~= GEnums.InnTopicType.PrivateChef then
            local unlockLevel = topicData.unlockLevel or 0
            local isUnlocked = innLevel >= unlockLevel
            local totalStars = (topicData.starRequiredScore and topicData.starRequiredScore.Count) or 0
            local currentStars = self.m_innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId)) or 0

            local isFullStar = isUnlocked and totalStars > 0 and currentStars >= totalStars
            topicDataList[#topicDataList + 1] = {
                id = topicId,
                name = topicData.name,
                unlockLevel = unlockLevel,
                sortId = topicData.sortId or 0,
                isUnlocked = isUnlocked,
                totalStars = totalStars,
                currentStars = currentStars,
                sortGroup = isUnlocked and (isFullStar and 2 or 1) or 3,
            }
        end
    end

    table.sort(topicDataList, Utils.genSortFunction({ "sortGroup", "unlockLevel", "sortId", "id" }, true))
    self.m_topicDataList = topicDataList
end






InnTopicSelectCtrl._Refresh = HL.Method() << function(self)
    self:_RefreshStarsInfo()
    self.view.scrollList:UpdateCount(#self.m_topicDataList)
    if DeviceInfo.usingController then
        self:SetNaviTarget(self.m_getCell(1).view.naviTarget)
    end
end

InnTopicSelectCtrl._RefreshStarsInfo = HL.Method() << function(self)
    local fullStarCount = 0
    local unlockedCount = 0
    for _, data in ipairs(self.m_topicDataList) do
        if data.isUnlocked then
            unlockedCount = unlockedCount + 1
            if data.totalStars > 0 and data.currentStars >= data.totalStars then
                fullStarCount = fullStarCount + 1
            end
        end
    end
    self.view.fullStarsNumTxt.text = tostring(fullStarCount)
    self.view.unlockNumTxt.text = tostring(unlockedCount)
end

InnTopicSelectCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local data = self.m_topicDataList[luaIndex]
    if not data then
        return
    end

    cell:InitInnTopicEntry({
        topicId = data.id,
        showDetailTip = true,
        onClick = function()
            self.m_openPopupTopicId = data.id
            UIManager:Open(PanelId.InnRewardDetailsPopup, { topicId = data.id })
        end,
        onGoToClick = function()
            InnUtils.openTopicSelection({ topicId = data.id })
        end,
    })

    if cell.view.redDot then
        cell.view.redDot:InitRedDot("InnTopicSingle", data.id, nil, self.view.redDotScrollRect)
    end
end






InnTopicSelectCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local popupTopicId = ""
    if UIManager:IsOpen(PanelId.InnRewardDetailsPopup) then
        popupTopicId = self.m_openPopupTopicId
    end
    return {
        openPopupTopicId = popupTopicId,
    }
end




HL.Commit(InnTopicSelectCtrl)
