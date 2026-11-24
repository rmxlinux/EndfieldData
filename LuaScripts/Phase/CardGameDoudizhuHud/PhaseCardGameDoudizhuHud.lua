local phaseBase = require_ex('Phase/Core/PhaseBase')

local PHASE_ID = PhaseId.CardGameDoudizhuHud

PhaseCardGameDoudizhuHud = HL.Class('PhaseCardGameDoudizhuHud', phaseBase.PhaseBase)



PhaseCardGameDoudizhuHud.s_messages = HL.StaticField(HL.Table) << {
}

PhaseCardGameDoudizhuHud.m_hudPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseCardGameDoudizhuHud.m_phaseActivated = HL.Field(HL.Boolean) << false
PhaseCardGameDoudizhuHud.m_readyNotified = HL.Field(HL.Boolean) << false

PhaseCardGameDoudizhuHud.Open = HL.StaticMethod(HL.Opt(HL.Table)) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg)
end

PhaseCardGameDoudizhuHud._OnInit = HL.Override() << function(self)
    PhaseCardGameDoudizhuHud.Super._OnInit(self)
    self.m_phaseActivated = false
    self.m_readyNotified = false
end


PhaseCardGameDoudizhuHud.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = PhaseCardGameDoudizhuHud.Super.GetCurStateArg(self) or {}
    arg.deadlineCountdownState = self.m_hudPanel ~= nil and self.m_hudPanel.uiCtrl:GetDeadlineCountdownState() or nil
    arg.selectedCardInstIds = self.m_hudPanel ~= nil and self.m_hudPanel.uiCtrl:GetSelectedCardInstIds() or nil
    arg.pointInfoState = self.m_hudPanel ~= nil and self.m_hudPanel.uiCtrl:GetPointInfoRecoverState() or nil
    arg.finalSettleRecoverArg = nil
    arg.isCardTypeListShown = nil
    arg.leaveRoomPopUpArg = nil
    if PhaseManager:GetTopPhaseId() == PHASE_ID then
        if UIManager:IsShow(PanelId.CardGameLandlordFinalSettleRank) then
            local _, settleCtrl = UIManager:IsOpen(PanelId.CardGameLandlordFinalSettleRank)
            arg.finalSettleRecoverArg = settleCtrl:GetRecoverStateArg()
        end
        if self.m_hudPanel ~= nil then
            arg.isCardTypeListShown = self.m_hudPanel.uiCtrl:IsCardTypeListShown() or nil
            arg.leaveRoomPopUpArg = self.m_hudPanel.uiCtrl:GetLeaveRoomPopUpRecoverArg()
        end
    end
    return arg
end



PhaseCardGameDoudizhuHud.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number))
        << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseCardGameDoudizhuHud._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table))
        << function(self, fastMode, args)
    local scene = LuaSystemManager.cardGameDoudizhuSystem.scene
    if scene and not string.isEmpty(scene.uiSceneId) then
        UISceneManager:Activate(scene.uiSceneId)
    end
end

PhaseCardGameDoudizhuHud._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table))
        << function(self, fastMode, args)
end

PhaseCardGameDoudizhuHud._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table))
        << function(self, fastMode, args)
end

PhaseCardGameDoudizhuHud._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table))
        << function(self, fastMode, args)
end





PhaseCardGameDoudizhuHud._InitAllPhaseItems = HL.Override() << function(self)
    PhaseCardGameDoudizhuHud.Super._InitAllPhaseItems(self)
    self.m_hudPanel = self:_GetPanelPhaseItem(PanelId.CardGameLandlordHud)
end



PhaseCardGameDoudizhuHud._TryNotifyPhaseReady = HL.Method() << function(self)
    if self.m_readyNotified or not self.m_phaseActivated then
        return
    end
    self.m_readyNotified = true
    local scene = LuaSystemManager.cardGameDoudizhuSystem.scene
    local loadedCount = 0
    if scene and scene.charItems then
        for _, _ in pairs(scene.charItems) do
            loadedCount = loadedCount + 1
        end
    end
    logger.info(string.format(
            "[斗地主][场景] 牌桌基础资源已就绪：当前已加载角色=%d，开始牌桌表现",
            loadedCount))
    local onPhaseReady = self.arg and self.arg.onPhaseReady
    if onPhaseReady ~= nil then
        onPhaseReady()
    end
    local countdownState = self.arg and self.arg.deadlineCountdownState
    if countdownState ~= nil then
        self.arg.deadlineCountdownState = nil
        
        self.m_hudPanel.uiCtrl:RestoreDeadlineCountdownState(countdownState)
    end
    local selectedCardInstIds = self.arg and self.arg.selectedCardInstIds
    if selectedCardInstIds ~= nil then
        self.arg.selectedCardInstIds = nil
        
        self.m_hudPanel.uiCtrl:SetSelectedCardInstIds(selectedCardInstIds)
    end
    local pointInfoState = self.arg and self.arg.pointInfoState
    if pointInfoState ~= nil then
        self.arg.pointInfoState = nil
        
        self.m_hudPanel.uiCtrl:RestorePointInfoState(pointInfoState)
    end
    if self.arg and self.arg.isCardTypeListShown then
        self.arg.isCardTypeListShown = nil
        self.m_hudPanel.uiCtrl:ShowCardTypeList()
    end
end

PhaseCardGameDoudizhuHud._OnActivated = HL.Override() << function(self)
    local scene = LuaSystemManager.cardGameDoudizhuSystem.scene
    if scene then
        scene:SetRoomCameraPos(CardGameUtils.RoomCameraPosType.Normal)
    end
    UIManager:Hide(PanelId.Touch)
    local wasReady = self.m_readyNotified
    self.m_phaseActivated = true
    self:_TryNotifyPhaseReady()
    if wasReady then
        local onPhaseActivated = self.arg and self.arg.onPhaseActivated
        if onPhaseActivated ~= nil then
            onPhaseActivated()
        end
    end
    local finalSettleRecoverArg = self.arg and self.arg.finalSettleRecoverArg
    if finalSettleRecoverArg ~= nil then
        self.arg.finalSettleRecoverArg = nil
        
        UIManager:Open(PanelId.CardGameLandlordFinalSettleRank, finalSettleRecoverArg)
    end
    local leaveRoomPopUpArg = self.arg and self.arg.leaveRoomPopUpArg
    if leaveRoomPopUpArg ~= nil then
        self.arg.leaveRoomPopUpArg = nil
        self.m_hudPanel.uiCtrl:RecoverLeaveRoomPopUp(leaveRoomPopUpArg)
    end
end

PhaseCardGameDoudizhuHud._OnDeActivated = HL.Override() << function(self)
    self.m_phaseActivated = false
    local onPhaseDeactivated = self.arg and self.arg.onPhaseDeactivated
    if onPhaseDeactivated ~= nil then
        onPhaseDeactivated()
    end
end

PhaseCardGameDoudizhuHud._OnDestroy = HL.Override() << function(self)
    UIManager:Show(PanelId.Touch)
    
    
    if self.m_hudPanel ~= nil then
        self:RemovePhasePanelItem(self.m_hudPanel)
        self.m_hudPanel = nil
    end
    PhaseCardGameDoudizhuHud.Super._OnDestroy(self)
end



HL.Commit(PhaseCardGameDoudizhuHud)
