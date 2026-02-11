local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.DomainDepotPackage
local DOMAIN_DEPOT_BACKGROUND_STAGES = UIConst.DOMAIN_DEPOT_BACKGROUND_STAGES
































PhaseDomainDepotPackage = HL.Class('PhaseDomainDepotPackage', phaseBase.PhaseBase)

local DOMAIN_MONEY_TITLE_NAVI_GROUP_ORDER_OFFSET = 5


PhaseDomainDepotPackage.m_popAsyncActionHelper = HL.Field(HL.Forward("AsyncActionHelper"))


PhaseDomainDepotPackage.m_curPanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_panelItemDic = HL.Field(HL.Table)


PhaseDomainDepotPackage.m_typePanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_itemPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_backPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_sellPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_tabPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_showSellAnimPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDomainDepotPackage.m_sellEndPanel = HL.Field(HL.Forward("PhasePanelItem"))






PhaseDomainDepotPackage.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_OPEN_DOMAIN_DEPOT_TAB] = { 'OnOpenDomainDepotTab', false },
    [MessageConst.ON_CLOSE_DOMAIN_DEPOT_TAB] = { 'OnCloseDomainDepotTab', true },
    [MessageConst.ON_OPEN_DOMAIN_DEPOT_PACK_TYPE_SELECT_PANEL] = { 'OnOpenPackTypeSelectPanel', true },
    [MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_TYPE_SELECT_PANEL] = { 'OnClosePackTypeSelectPanel', true },
    [MessageConst.ON_OPEN_DOMAIN_DEPOT_PACK_ITEM_SELECT_PANEL] = { 'OnOpenPackItemSelectPanel', true },
    [MessageConst.ON_DOMAIN_DEPOT_BACK_TO_PACK_TYPE_SELECT_PANEL] = { 'OnBackToPackTypeSelectPanel', true },
    [MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_ITEM_SELECT_PANEL] = { 'OnClosePackItemSelectPanel', true },
    [MessageConst.ON_OPEN_DOMAIN_DEPOT_PACK_SELL_PANEL] = { 'OnOpenPackSellPanel', true },
    [MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_SELL_PANEL] = { 'OnClosePackSellPanel', true },
    [MessageConst.ON_OPEN_SHOW_SELL_ANIM_PANEL] = { 'OnOpenSellAnimPanel', true },
    [MessageConst.ON_SELECT_BUYER_END] = { 'OnPackSellEndPanel', true },
    [MessageConst.ON_CLOSE_DOMAIN_DEPOT_PACK_SETTLE_PANEL] = { 'OnClosePackSellEndPanel', true },
}



PhaseDomainDepotPackage.OnOpenDomainDepotTab = HL.StaticMethod(HL.Table) << function(args)
    local domainId
    if string.isEmpty(args) then
        domainId = ScopeUtil.GetCurrentChapterIdAsStr()
    else
        local domainDepotId = unpack(args)
        local domainDepotCfg = Tables.domainDepotTable[domainDepotId]
        domainId = domainDepotCfg.domainId
    end
    PhaseManager:OpenPhase(PhaseId.DomainDepotPackage, { domainId = domainId })
end



PhaseDomainDepotPackage.OnCloseDomainDepotTab = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end




PhaseDomainDepotPackage.OnTabChange = HL.Method(HL.Number) << function(self, panelId)
    if panelId == nil then
        return
    end

    if self.m_curPanelItem then
        self.m_curPanelItem.uiCtrl:Hide()
    end

    local panelItem
    if self.m_panelItemDic[panelId] then
        panelItem = self.m_panelItemDic[panelId]
    else
        panelItem = self:CreatePhasePanelItem(panelId, { domainId = self.arg.domainId })
        self.m_panelItemDic[panelId] = panelItem
    end
    panelItem.uiCtrl:Show()
    if HL.TryGet(panelItem.uiCtrl, "Sync") then
        panelItem.uiCtrl:Sync()
    end
    self.m_curPanelItem = panelItem
    self:_BindPlaceHolder()
end









PhaseDomainDepotPackage.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseDomainDepotPackage._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if self.arg == nil then
        self.arg = {
            domainId = ScopeUtil.GetCurrentChapterIdAsStr()
        }
    end

    self.m_tabPanel = self:CreatePhasePanelItem(PanelId.DomainDepotTab, { domainId = self.arg.domainId })
    self.m_panelItemDic = {}
    
    Notify(MessageConst.ON_CHANGE_DOMAIN_DEPOT_TAB, self.arg)
end





PhaseDomainDepotPackage._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDomainDepotPackage._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseDomainDepotPackage._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end









PhaseDomainDepotPackage._OnInit = HL.Override() << function(self)
    PhaseDomainDepotPackage.Super._OnInit(self)

    self.m_popAsyncActionHelper = require_ex("Common/Utils/AsyncActionHelper")(true)
end



PhaseDomainDepotPackage._OnActivated = HL.Override() << function(self)
end



PhaseDomainDepotPackage._OnDeActivated = HL.Override() << function(self)
end



PhaseDomainDepotPackage._OnDestroy = HL.Override() << function(self)
    self.m_popAsyncActionHelper:Clear()
    self.m_popAsyncActionHelper = nil

    PhaseDomainDepotPackage.Super._OnDestroy(self)
end



PhaseDomainDepotPackage._OnRefresh = HL.Override() << function(self)
    local removeFunc = function(panel)
        if panel ~= nil and panel.uiCtrl ~= nil then
            self:RemovePhasePanelItem(panel)
        end
    end
    removeFunc(self.m_backPanel)
    self.m_backPanel = nil
    removeFunc(self.m_typePanel)
    self.m_typePanel = nil
    removeFunc(self.m_itemPanel)
    self.m_itemPanel = nil
    removeFunc(self.m_sellPanel)
    self.m_sellPanel = nil

    self.m_tabPanel.uiCtrl:ForceResetTab()
end





PhaseDomainDepotPackage._PlayAnimationOutAndRemovePhaseItem = HL.Method(HL.Forward("PhasePanelItem"), HL.Opt(HL.Function)) << function(self, phaseItem, onRemove)
    local removeCallback = function()
        if onRemove ~= nil then
            onRemove()
        end
    end

    if phaseItem and phaseItem.uiCtrl and not phaseItem.uiCtrl:IsPlayingAnimationOut() then
        phaseItem.uiCtrl:PlayAnimationOutWithCallback(function()
            self:RemovePhasePanelItem(phaseItem)
            removeCallback()
        end)
    else
        removeCallback()
    end
end




PhaseDomainDepotPackage._AsyncPlayAnimationOutAndRemovePhaseItem = HL.Method(HL.Forward("PhasePanelItem")) << function(self, phaseItem)
    self.m_popAsyncActionHelper:AddAction(function(onComplete)
        self:_PlayAnimationOutAndRemovePhaseItem(phaseItem, function()
            onComplete()
        end)
    end)
end




PhaseDomainDepotPackage._AsyncPlayBackAnimationOutByStageAndRemovePhaseItem = HL.Method(HL.Number, HL.Opt(HL.Function)) << function(self, stage)
    self.m_popAsyncActionHelper:AddAction(function(onComplete)
        self.m_backPanel.uiCtrl:PlayAnimationByStage(stage, false, function()
            self:RemovePhasePanelItem(self.m_backPanel)
            onComplete()
        end)
    end)
end




PhaseDomainDepotPackage._AsyncPlayBackAnimationOutByStage = HL.Method(HL.Number) << function(self, stage)
    self.m_popAsyncActionHelper:AddAction(function(onComplete)
        self.m_backPanel.uiCtrl:PlayAnimationByStage(stage, false, function()
            onComplete()
        end)
    end)
end



PhaseDomainDepotPackage._BindPlaceHolder = HL.Method() << function(self)
    if not self.m_tabPanel then
        return
    end

    local tabCtrl = self.m_tabPanel.uiCtrl
    if tabCtrl then
        self.m_curPanelItem.uiCtrl.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
            tabCtrl.view.inputGroup.groupId,
            self.m_curPanelItem.uiCtrl.view.inputGroup.groupId,
        })
        tabCtrl.view.domainTopMoneyTitle.view.contentNaviGroup.focusPanelSortingOrder = self.m_curPanelItem.uiCtrl:GetSortingOrder() +
            DOMAIN_MONEY_TITLE_NAVI_GROUP_ORDER_OFFSET
    end
end









PhaseDomainDepotPackage.OnOpenPackTypeSelectPanel = HL.Method(HL.Table) << function(self, args)
    self.m_backPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackBackGround)
    self.m_typePanel = self:CreatePhasePanelItem(PanelId.DomainDepotGoodsType, { depotId = args.depotId, pack = self.m_backPanel.uiCtrl.view.domainDepotPack, backPanel = self.m_backPanel.uiCtrl })
    self.m_backPanel.uiCtrl:OnGoodsPack()
end



PhaseDomainDepotPackage.OnClosePackTypeSelectPanel = HL.Method() << function(self)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_backPanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_typePanel)
end




PhaseDomainDepotPackage.OnOpenPackItemSelectPanel = HL.Method(HL.Table) << function(self, args)
    if self.m_typePanel.uiCtrl:IsPlayingAnimationOut() then
        self.m_typePanel.uiCtrl:Hide()  
    else
        self.m_typePanel.uiCtrl:PlayAnimationOutAndHide()
    end
    args.pack = self.m_backPanel.uiCtrl.view.domainDepotPack
    
    self.m_backPanel.uiCtrl:ChangePackItemType(GEnums.DomainDepotDeliverItemType.Misc)
    self.m_itemPanel = self:CreatePhasePanelItem(PanelId.DomainDepotGoodsPack, args)
end



PhaseDomainDepotPackage.OnClosePackItemSelectPanel = HL.Method() << function(self)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_typePanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_itemPanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_backPanel)
end



PhaseDomainDepotPackage.OnBackToPackTypeSelectPanel = HL.Method() << function(self)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_itemPanel)
    if self.m_typePanel.uiCtrl:IsPlayingAnimationOut() then
        self.m_typePanel.uiCtrl:Hide()  
    end
    self.m_typePanel.uiCtrl:Show()
end




PhaseDomainDepotPackage.OnOpenSellAnimPanel = HL.Method(HL.Any) << function(self, args)
    if self.m_backPanel == nil or self.m_backPanel.uiCtrl == nil then
        self.m_backPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackBackGround)
    end

    local removeFinishAndOpen = function()
        local domainDepotId = unpack(args)
        self.m_showSellAnimPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackBidPrice, { domainDepotId = domainDepotId, pack = self.m_backPanel.uiCtrl.view.domainDepotPack })
        self.m_backPanel.uiCtrl:OnPackBackGround()
    end

    self.m_popAsyncActionHelper:Clear()
    self.m_popAsyncActionHelper:SetOnFinished(function()
        removeFinishAndOpen()
    end)

    self:_AsyncPlayBackAnimationOutByStage(DOMAIN_DEPOT_BACKGROUND_STAGES.Pack)
    self:_AsyncPlayAnimationOutAndRemovePhaseItem(self.m_itemPanel)
    self:_AsyncPlayAnimationOutAndRemovePhaseItem(self.m_typePanel)

    self.m_popAsyncActionHelper:Start()
end




PhaseDomainDepotPackage.OnOpenPackSellPanel = HL.Method(HL.Any) << function(self, args)
    if self.m_backPanel == nil or self.m_backPanel.uiCtrl == nil then
        self.m_backPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackBackGround)
    end

    local removeFinishAndOpen = function()
        self.m_sellPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackageSell, { domainDepotId = args.domainDepotId })
        self.m_backPanel.uiCtrl:OnPackageSell()
    end

    if args.simpleOpen then
        removeFinishAndOpen()
        local deliverInfo = GameInstance.player.domainDepotSystem:GetDomainDepotDeliverInfoByDepotId(args.domainDepotId)
        self.m_backPanel.uiCtrl:InitPackageSellBgNode(deliverInfo)
    else
        self.m_popAsyncActionHelper:Clear()
        self.m_popAsyncActionHelper:SetOnFinished(function()
            removeFinishAndOpen()
        end)

        self:_AsyncPlayBackAnimationOutByStage(DOMAIN_DEPOT_BACKGROUND_STAGES.WaitSelectBuyer)
        self:_AsyncPlayAnimationOutAndRemovePhaseItem(self.m_showSellAnimPanel)

        self.m_popAsyncActionHelper:Start()
    end
end



PhaseDomainDepotPackage.OnClosePackSellPanel = HL.Method() << function(self)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_backPanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_showSellAnimPanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_sellPanel)
end




PhaseDomainDepotPackage.OnPackSellEndPanel = HL.Method(HL.Any) << function(self, args)
    if self.m_backPanel == nil or self.m_backPanel.uiCtrl == nil then
        self.m_backPanel = self:CreatePhasePanelItem(PanelId.DomainDepotPackBackGround)
    end

    self:_PlayAnimationOutAndRemovePhaseItem(self.m_sellPanel)
    self:_PlayAnimationOutAndRemovePhaseItem(self.m_showSellAnimPanel)

    local deliverInstId, stateName = unpack(args)
    local deliverInfo = GameInstance.player.domainDepotSystem:GetDomainDepotDeliverInfoByInstId(deliverInstId)
    self.m_backPanel.uiCtrl:OnGoodsSettle(deliverInstId)

    local panelArgs = { deliverInstId = deliverInstId, stateName = stateName }
    self.m_sellEndPanel = self:CreatePhasePanelItem(PanelId.DomainDepotGoodsSettle, panelArgs)

    
    if self.m_tabPanel then
        self:RemovePhasePanelItem(self.m_tabPanel)
    end
    if self.m_curPanelItem then
        self:RemovePhasePanelItem(self.m_curPanelItem)
    end
end



PhaseDomainDepotPackage.OnClosePackSellEndPanel = HL.Method() << function(self)
    self.m_popAsyncActionHelper:Clear()
    self.m_popAsyncActionHelper:SetOnFinished(function()
        Notify(MessageConst.RECOVER_PHASE_LEVEL)
    end)

    
    self:_AsyncPlayBackAnimationOutByStageAndRemovePhaseItem(DOMAIN_DEPOT_BACKGROUND_STAGES.FinishSelectBuyer)
    self:_AsyncPlayAnimationOutAndRemovePhaseItem(self.m_sellEndPanel)

    self.m_popAsyncActionHelper:Start()
end




HL.Commit(PhaseDomainDepotPackage)

