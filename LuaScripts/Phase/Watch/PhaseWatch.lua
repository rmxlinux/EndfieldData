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
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterCinematic()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(false)
end




PhaseWatch._InitAllPhaseItems = HL.Override() << function(self)
    PhaseWatch.Super._InitAllPhaseItems(self)
    local isOpen, cachedBlurPanel = UIManager:IsOpen(PanelId.WatchBlur)
    if isOpen then
        self.m_watchBlurCtrl = cachedBlurPanel
    else
        self.m_watchBlurCtrl = UIManager:Open(PanelId.WatchBlur)
    end
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
    if not fastMode then
        coroutine.waitForRenderDone()
    end

    ctrl:PlayAnimationIn()
    
    ctrl.view.animationWrapper.autoPlay = true
    ctrl:_SetCameraCfg()

    local recoverArg = self.arg
    local tipsState = recoverArg and recoverArg.worldLevelTipsPopupState
    if tipsState and tipsState.isOpen then
        local isTipsPopupOpen = UIManager:IsOpen(PanelId.WorldLevelTipsPopup)
        if not isTipsPopupOpen then
            UIManager:Open(PanelId.WorldLevelTipsPopup, {
                isTipsMode = tipsState.isTipsMode,
            })
        end
    end

    local popupState = recoverArg and recoverArg.worldLevelPopupState
    if popupState and popupState.isOpen then
        local isPopupOpen = UIManager:IsOpen(PanelId.WorldLevelPopup)
        if not isPopupOpen then
            UIManager:Open(PanelId.WorldLevelPopup, {
                isUp = popupState.isUp,
                targetWorldLevel = popupState.targetWorldLevel,
            })
        end
    end
end




PhaseWatch._OnActivated = HL.Override() << function(self)
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterCinematic()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(false)
end




PhaseWatch._OnDeActivated = HL.Override() << function(self)
    local needIgnoreHide = not PhaseManager.isRecovering and InputManagerInst.inChangingInputDevice
    if not needIgnoreHide then
        self.m_watchBlurCtrl:Hide()
    end
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
    if not InputManagerInst.inChangingInputDevice then
        self.m_watchBlurCtrl.view.fullScreenBlurScene.gameObject:SetActive(false)
    end
    
    self.m_watchPanel.uiCtrl.view.animationWrapper.autoPlay = false
end






PhaseWatch._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local usingBT = UIUtils.usingBlockTransition()
    local nextPhaseId = args.anotherPhaseId
    local toCommonMoneyExchange = nextPhaseId == PhaseId.CommonMoneyExchange or nextPhaseId == PhaseId.StaminaPopUp
    if not toCommonMoneyExchange then
        if not usingBT then
            self.m_watchPanel.uiCtrl.animationWrapper:ClearTween(true)
            self:_ChangeBlurSetting(false)
        end
        self.m_watchPanel.uiCtrl.view.content.gameObject:SetActive(false)
    end
end





PhaseWatch._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local nextPhaseId = args.anotherPhaseId
    local toCommonMoneyExchange = tonumber(nextPhaseId) == PhaseId.CommonMoneyExchange or nextPhaseId == PhaseId.StaminaPopUp
    if not toCommonMoneyExchange then
        self.m_watchPanel.uiCtrl.animationWrapper:PlayInAnimation()
        self.m_watchPanel.uiCtrl.view.content.gameObject:SetActive(true)
        self.m_watchPanel.uiCtrl:Show()
        self:_ChangeBlurSetting(true)
    end
    self.m_watchPanel.uiCtrl:_SetCameraCfg()

    local _, blurPanel = UIManager:IsOpen(PanelId.FullScreenSceneBlur)
    if blurPanel then
        
        
        
        
        blurPanel.view.blurBG:SetCustomBlurImg(self.m_watchBlurCtrl.view.blurBG.rawImage.texture)
    end
end



PhaseWatch.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local ret = self.arg and lume.deepCopy(self.arg) or {}
    local isTipsPopupOpen, tipsPopupCtrl = UIManager:IsOpen(PanelId.WorldLevelTipsPopup)
    if isTipsPopupOpen and tipsPopupCtrl then
        ret.worldLevelTipsPopupState = {
            isOpen = true,
            isTipsMode = tipsPopupCtrl.isTipsMode,
        }
    else
        ret.worldLevelTipsPopupState = nil
    end

    local isPopupOpen, popupCtrl = UIManager:IsOpen(PanelId.WorldLevelPopup)
    if isPopupOpen and popupCtrl then
        local popupState = popupCtrl:GetPopupState()
        ret.worldLevelPopupState = {
            isOpen = true,
            isUp = popupState.isUp,
            targetWorldLevel = popupState.targetWorldLevel,
        }
    else
        ret.worldLevelPopupState = nil
    end

    if next(ret) ~= nil then
        return ret
    end
    return nil
end




PhaseWatch._OnDestroy = HL.Override() << function(self)
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterNormal()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(true)
    if not InputManagerInst.inChangingInputDevice then
        self.m_watchBlurCtrl:PlayAnimationOutAndClose()
    end
    self:_ChangeBlurSetting(false)
    self.m_watchPanel.uiCtrl.view.scrollViewScrollRect.verticalNormalizedPosition = 1
end

HL.Commit(PhaseWatch)
