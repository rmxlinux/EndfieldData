local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Watch
















PhaseWatch = HL.Class('PhaseWatch', phaseBase.PhaseBase)





PhaseWatch.s_messages = HL.StaticField(HL.Table) << {
    
}


PhaseWatch.m_watchPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseWatch.m_watchBlurCtrl = HL.Field(HL.Forward("WatchBlurCtrl"))


PhaseWatch.m_clearScreenKey = HL.Field(HL.Number) << -1





PhaseWatch._OnInit = HL.Override() << function(self)
    PhaseWatch.Super._OnInit(self)
end




PhaseWatch._InitAllPhaseItems = HL.Override() << function(self)
    PhaseWatch.Super._InitAllPhaseItems(self)
    self.m_watchBlurCtrl = UIManager:Open(PanelId.WatchBlur)
    self.m_watchPanel = self:_GetPanelPhaseItem(PanelId.Watch)
end








PhaseWatch.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        local assetPath
        if Utils.isInSpaceShip() then
            assetPath = string.format(MapConst.UI_DOMAIN_MAP_PATH, MapConst.UI_SPACESHIP_MAP)
        else
            local _, domainData = Tables.domainDataTable:TryGetValue(Utils.getCurDomainId())
            if domainData then
                assetPath = string.format(MapConst.UI_DOMAIN_MAP_PATH, domainData.domainMap)
            end
        end
        if assetPath then
            self.m_resourceLoader:LoadGameObjectAsync(assetPath, function(go)
                logger.info(assetPath, "预载完成")
            end)
        end
    elseif transitionType == PhaseConst.EPhaseState.TransitionBackToTop then
        self.m_watchBlurCtrl:Show()
    end
end






PhaseWatch._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:_ChangeBlurSetting(true)
    if not CS.Beyond.BeyondMemoryUtility.IsLowMemoryDevice() then
        UIManager:PreloadPanelAsset(PanelId.EquipTech, PHASE_ID)
    end

    Notify(MessageConst.CHANGE_WATER_MARK_GRID)

    self.m_clearScreenKey = UIManager:ClearScreen({ PanelId.Watch, PanelId.WatchController })
    local ctrl = self.m_watchPanel.uiCtrl
    ctrl:ChangePanelCfg("clearedPanel", true) 
    ctrl.view.volume.gameObject:SetActive(false) 
    ctrl.view.content.gameObject:SetActive(true)

    ctrl.view.animationWrapper:SampleToInAnimationBegin()   
    coroutine.waitForRenderDone()

    ctrl:PlayAnimationIn()
    
    ctrl.view.animationWrapper.autoPlay = true
    ctrl:_SetCameraCfg()
end




PhaseWatch._OnActivated = HL.Override() << function(self)
end




PhaseWatch._OnDeActivated = HL.Override() << function(self)
    self.m_watchBlurCtrl:Hide()
end




PhaseWatch._ChangeBlurSetting = HL.Method(HL.Boolean) << function(self, isActive)
    local _, blurPanel = UIManager:IsOpen(PanelId.FullScreenSceneBlur)
    if blurPanel then
        blurPanel.view.gameObject:SetLayerRecursive(isActive and UIConst.UIPP_LAYER or UIConst.UI_LAYER)
    end
    self.m_watchBlurCtrl.view.gameObject:SetLayerRecursive(isActive and UIConst.UIPP_LAYER or UIConst.UI_LAYER)
end






PhaseWatch._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.m_watchPanel.uiCtrl:ChangePanelCfg("clearedPanel", false)
    self.m_clearScreenKey = UIManager:RecoverScreen(self.m_clearScreenKey)
    self.m_watchBlurCtrl.view.fullScreenBlurScene.gameObject:SetActive(false)
    
    self.m_watchPanel.uiCtrl.view.animationWrapper.autoPlay = false
end






PhaseWatch._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local usingBT = UIUtils.usingBlockTransition()
    local nextPhaseId = args.anotherPhaseId
    local toCommonMoneyExchange = nextPhaseId == PhaseId.CommonMoneyExchange
    if not usingBT and not toCommonMoneyExchange then
        self.m_watchPanel.uiCtrl.animationWrapper:ClearTween(true)
        self.m_watchPanel.uiCtrl.view.content.gameObject:SetActive(false)
        self:_ChangeBlurSetting(false)
    end
end





PhaseWatch._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local nextPhaseId = args.anotherPhaseId
    local toCommonMoneyExchange = tonumber(nextPhaseId) == PhaseId.CommonMoneyExchange
    if not toCommonMoneyExchange then
        self.m_watchPanel.uiCtrl.animationWrapper:PlayInAnimation()
        self.m_watchPanel.uiCtrl.view.content.gameObject:SetActive(true)
        self.m_watchPanel.uiCtrl:Show()
        self:_ChangeBlurSetting(true)
    end
    self.m_watchPanel.uiCtrl:_SetCameraCfg()

    local _, blurPanel = UIManager:IsOpen(PanelId.FullScreenSceneBlur)
    if blurPanel then
        
        local src = self.m_watchBlurCtrl.view.blurBG.rawImage.texture
        local dst = blurPanel.view.blurBG.rawImage.texture
        CS.UnityEngine.Graphics.Blit(src, dst)
    end
end




PhaseWatch._OnDestroy = HL.Override() << function(self)
    self.m_watchBlurCtrl:PlayAnimationOutAndClose()
    self:_ChangeBlurSetting(false)
    self.m_watchPanel.uiCtrl.view.scrollViewScrollRect.verticalNormalizedPosition = 1
end

HL.Commit(PhaseWatch)
