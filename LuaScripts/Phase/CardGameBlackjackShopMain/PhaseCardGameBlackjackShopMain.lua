local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.CardGameBlackjackShopMain





PhaseCardGameBlackjackShopMain = HL.Class('PhaseCardGameBlackjackShopMain', phaseBase.PhaseBase)

PhaseCardGameBlackjackShopMain.s_messages = HL.StaticField(HL.Table) << {
}

PhaseCardGameBlackjackShopMain.m_shopMainPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseCardGameBlackjackShopMain.m_shopSelectPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseCardGameBlackjackShopMain.m_shopChangeCardPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseCardGameBlackjackShopMain.m_openCardPackPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseCardGameBlackjackShopMain.m_selectChangePanel = HL.Field(HL.Forward("PhasePanelItem"))

PhaseCardGameBlackjackShopMain.Open = HL.StaticMethod(HL.Opt(HL.Table)) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg)
end

PhaseCardGameBlackjackShopMain._OnInit = HL.Override() << function(self)
    PhaseCardGameBlackjackShopMain.Super._OnInit(self)
end


PhaseCardGameBlackjackShopMain.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {}
end

PhaseCardGameBlackjackShopMain._InitAllPhaseItems = HL.Override() << function(self)
    
    
    PhaseCardGameBlackjackShopMain.Super._InitAllPhaseItems(self)
    self.m_shopSelectPanel = self:_GetPanelPhaseItem(PanelId.CardGameBlackjackShopSelect)
    self.m_shopMainPanel = self:_GetPanelPhaseItem(PanelId.CardGameBlackjackShopMain)
    self:_LiftShopMainPanel()
    self:_RecoverChoosePanels()
end



PhaseCardGameBlackjackShopMain._RecoverChoosePanels = HL.Method() << function(self)
    local topKey = LuaSystemManager.cardGameBlackjackSystem:GetChooseTopKey()
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard then
        self:OpenShopChangeCardPanel(nil)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.GainCard then
        self:OpenCardPackPanel(nil)
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr then
        self:OpenSelectChangePanel(nil)
    end
end





PhaseCardGameBlackjackShopMain._LiftShopMainPanel = HL.Method() << function(self)
    local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if isOpen then
        UIManager:SetTopOrder(PanelId.CardGameBlackjackShopMain)
        local selectItemCtrl = self:_GetTopContentCtrl()
        
        if selectItemCtrl then
            shopMainCtrl.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ shopMainCtrl.view.inputGroup.groupId, selectItemCtrl.view.inputGroup.groupId })
        else
            shopMainCtrl.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ shopMainCtrl.view.inputGroup.groupId })
        end
    end
end



PhaseCardGameBlackjackShopMain._GetTopContentCtrl = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local topKey = LuaSystemManager.cardGameBlackjackSystem:GetChooseTopKey()
    local panelId = nil
    if topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChangeCard then
        panelId = PanelId.CardGameBlackjackShopChangeCard
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.GainCard then
        panelId = PanelId.CardGameBlackjackOpenCardPack
    elseif topKey == CardGameBlackjackUtils.CHOOSE_KEY.ChooseAttr then
        panelId = PanelId.CardGameBlackjackSelectChange
    end
    if panelId ~= nil then
        local isOpen, ctrl = UIManager:IsOpen(panelId)
        if isOpen then
            return ctrl
        end
    end
    local isShopSelectOpen, shopSelectCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopSelect)
    return isShopSelectOpen and shopSelectCtrl or nil
end


PhaseCardGameBlackjackShopMain._CreateOrShowContentPanel = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Forward("PhasePanelItem")) << function(self, panelId, arg)
    
    local oldItem = self:_GetPanelPhaseItem(panelId)
    if oldItem and oldItem.uiCtrl and oldItem.uiCtrl:IsPlayingAnimationOut() then
        self:RemovePhasePanelItem(oldItem)
    end
    local item = self:CreateOrShowPhasePanelItem(panelId, arg)
    self:_LiftShopMainPanel()
    return item
end


PhaseCardGameBlackjackShopMain._RemoveContentPanelWithAnim = HL.Method(HL.Number) << function(self, panelId)
    local item = self:_GetPanelPhaseItem(panelId)
    if not item then
        return
    end
    local ctrl = item.uiCtrl
    if not ctrl then
        self:RemovePhasePanelItem(item)
        return
    end
    if ctrl:IsPlayingAnimationOut() then
        return
    end
    ctrl:PlayAnimationOutWithCallback(function()
        if self.m_destroyed then
            return
        end
        if self:_GetPanelPhaseItem(panelId) == item then
            self:RemovePhasePanelItem(item)
        end
    end)
end

PhaseCardGameBlackjackShopMain._DoTransitionOutCoroutine = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if fastMode or self.m_destroyed then
        PhaseCardGameBlackjackShopMain.Super._DoTransitionOutCoroutine(self, fastMode, args)
        return
    end

    
    
    
    local playingOutItems = {}
    for _, item in pairs(self.m_panel2Item) do
        local ctrl = item.uiCtrl
        if ctrl and ctrl:_ShouldSkipPlayAnimationOut() then
            playingOutItems[item] = true
        end
    end

    self:_DoPhaseTransitionOut(fastMode, args)
    for phaseItem, _ in pairs(self.m_phaseItems) do
        phaseItem:TransitionOut(playingOutItems[phaseItem] == true)
    end
    self:_DoPhaseTransitionOutAfterItems(fastMode, args)
end


PhaseCardGameBlackjackShopMain._CheckAllTransitionDone = HL.Override().Return(HL.Boolean) << function(self)
    if not PhaseCardGameBlackjackShopMain.Super._CheckAllTransitionDone(self) then
        return false
    end
    if self.m_destroyed or self.state ~= PhaseConst.EPhaseState.TransitionOut then
        return true
    end
    for _, item in pairs(self.m_panel2Item) do
        local ctrl = item.uiCtrl
        if ctrl and not IsNull(ctrl.view.gameObject) and ctrl:IsPlayingAnimationOut() then
            return false
        end
    end
    return true
end


PhaseCardGameBlackjackShopMain.OpenShopChangeCardPanel = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    self.m_shopChangeCardPanel = self:_CreateOrShowContentPanel(PanelId.CardGameBlackjackShopChangeCard, arg)
    if self.m_shopChangeCardPanel and self.m_shopChangeCardPanel.uiCtrl then
        self.m_shopChangeCardPanel.uiCtrl:OnPhaseRefresh(arg)
    end
end

PhaseCardGameBlackjackShopMain.CloseShopChangeCardPanel = HL.Method() << function(self)
    self:_RemoveContentPanelWithAnim(PanelId.CardGameBlackjackShopChangeCard)
    self.m_shopChangeCardPanel = nil
end



PhaseCardGameBlackjackShopMain.OpenCardPackPanel = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    self.m_openCardPackPanel = self:_CreateOrShowContentPanel(PanelId.CardGameBlackjackOpenCardPack, arg)
end

PhaseCardGameBlackjackShopMain.CloseCardPackPanel = HL.Method() << function(self)
    self:_RemoveContentPanelWithAnim(PanelId.CardGameBlackjackOpenCardPack)
    self.m_openCardPackPanel = nil
end



PhaseCardGameBlackjackShopMain.OpenSelectChangePanel = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    self.m_selectChangePanel = self:_CreateOrShowContentPanel(PanelId.CardGameBlackjackSelectChange, arg)
end

PhaseCardGameBlackjackShopMain.CloseSelectChangePanel = HL.Method() << function(self)
    self:_RemoveContentPanelWithAnim(PanelId.CardGameBlackjackSelectChange)
    self.m_selectChangePanel = nil
end

HL.Commit(PhaseCardGameBlackjackShopMain)
