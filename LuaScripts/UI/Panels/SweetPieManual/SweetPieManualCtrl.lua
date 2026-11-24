local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PHASE_ID = PhaseId.SweetPieManual

SweetPieManualCtrl = HL.Class('SweetPieManualCtrl', uiCtrl.UICtrl)

SweetPieManualCtrl.m_layoutIndex = HL.Field(HL.Number) << 1
SweetPieManualCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_QUEST_STATE_CHANGE] = '_OnQuestStateChange',
    [MessageConst.HIDE_SWEET_PIE_POPTIPS] = '_CloseManual',
    [MessageConst.ON_EXIT_SWEET_PIE] = '_CloseManual',
}

SweetPieManualCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.LeftBtn.onClick:AddListener(function()
        self:_ShowPage(self:_FindNextUnlockedPage(self.m_layoutIndex, -1))
    end)
    self.view.RightBtn.onClick:AddListener(function()
        self:_ShowPage(self:_FindNextUnlockedPage(self.m_layoutIndex, 1))
    end)
    self.view.CloseBtn.onClick:AddListener(function()
        self:_CloseManual(true)
    end)
    self:_ShowPage(tonumber(arg) or 1)
end

SweetPieManualCtrl._CloseManual = HL.Method(HL.Opt(HL.Boolean)) << function(self, isManualClose)
    if PhaseManager:IsInPhaseTransition() then
        return
    end
    if isManualClose then
        PhaseManager:PopPhase(PHASE_ID, function()
            GameWorld.eventManager:RaiseLevelEvent(GameLevelEvent.ON_SWEET_PIE_POPTIPS_MANUALLY_CLOSED)
        end)
    else
        self.m_phase:CloseSelf()
    end
end

SweetPieManualCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_layoutIndex
end

SweetPieManualCtrl._IsPageUnlocked = HL.Method(HL.Number).Return(HL.Boolean) << function(self, pageIndex)
    local unlockQuestIds = self.view.config.PAGE_UNLOCK_QUEST_ID
    local questId = unlockQuestIds and unlockQuestIds["pageLayout" .. pageIndex]
    return questId == nil or questId == "" or GameInstance.player.mission:IsQuestCompleted(questId)
end

SweetPieManualCtrl._FindNextUnlockedPage = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, pageIndex, direction)
    local pageCount = self.view.config.PAGE_COUNT
    local endIndex = direction > 0 and pageCount or 1
    for index = pageIndex + direction, endIndex, direction do
        if self:_IsPageUnlocked(index) then
            return index
        end
    end
    return 0
end

SweetPieManualCtrl._ShowPage = HL.Method(HL.Number) << function(self, pageIndex)
    local pageCount = self.view.config.PAGE_COUNT
    local requestedLayoutIndex = math.max(1, math.min(pageIndex, pageCount))
    self.m_layoutIndex = 1
    for index = requestedLayoutIndex, 1, -1 do
        if self:_IsPageUnlocked(index) then
            self.m_layoutIndex = index
            break
        end
    end

    local unlockedPageCount = 0
    local currentUnlockedPageIndex = 0
    for index = 1, pageCount do
        local isUnlocked = self:_IsPageUnlocked(index)
        self.view["pageLayout" .. index].gameObject:SetActive(index == self.m_layoutIndex)
        if isUnlocked then
            unlockedPageCount = unlockedPageCount + 1
            if index == self.m_layoutIndex then
                currentUnlockedPageIndex = unlockedPageCount
            end
        end
    end

    self.view.PageText.text = string.format("%d/%d", currentUnlockedPageIndex, unlockedPageCount)
    self.view.LeftBtn.interactable = self:_FindNextUnlockedPage(self.m_layoutIndex, -1) > 0
    self.view.RightBtn.interactable = self:_FindNextUnlockedPage(self.m_layoutIndex, 1) > 0
end

SweetPieManualCtrl._OnQuestStateChange = HL.Method(HL.Any) << function(self, args)
    local questId = unpack(args)
    local unlockQuestIds = self.view.config.PAGE_UNLOCK_QUEST_ID
    for _, unlockQuestId in pairs(unlockQuestIds or {}) do
        if unlockQuestId == questId then
            self:_ShowPage(self.m_layoutIndex)
            return
        end
    end
end

SweetPieManualCtrl.ShowSelf = HL.StaticMethod(HL.Opt(HL.Any)) << function(args)
    local pageIndex = args and unpack(args) or 1
    PhaseManager:OpenPhase(PHASE_ID, pageIndex)
end

HL.Commit(SweetPieManualCtrl)
