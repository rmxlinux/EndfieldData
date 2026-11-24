local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')






CardGameQuickMenuHintNode = HL.Class('CardGameQuickMenuHintNode', UIWidgetBase)


CardGameQuickMenuHintNode.m_getOpenArg = HL.Field(HL.Function)
CardGameQuickMenuHintNode.m_available = HL.Field(HL.Boolean) << false




CardGameQuickMenuHintNode._OnFirstTimeInit = HL.Override() << function(self)
    self:_InitUI()
end


CardGameQuickMenuHintNode.InitCardGameQuickMenuHintNode = HL.Method(HL.Table) << function(self, arg)
    self.m_getOpenArg = arg.getOpenArg
    self:_FirstTimeInit()
    self:_RefreshVisible()
end

CardGameQuickMenuHintNode._InitUI = HL.Method() << function(self)
    self.view.openQuickMenuBtn.onPressStart:AddListener(function()
        self:_TryOpenQuickMenu()
    end)
    
    self:RegisterMessage(MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED, function()
        self:_RefreshVisible()
    end, true)
end

CardGameQuickMenuHintNode._OnDestroy = HL.Override() << function(self)
    self.m_available = false
    UIManager:Close(PanelId.CardGameQuickMenu)
end




CardGameQuickMenuHintNode.SetAvailable = HL.Method(HL.Boolean) << function(self, available)
    self.m_available = available
    self:_RefreshVisible()
end

CardGameQuickMenuHintNode.CloseQuickMenu = HL.Method() << function(self)
    UIManager:Close(PanelId.CardGameQuickMenu)
end

CardGameQuickMenuHintNode.IsQuickMenuOpen = HL.Method().Return(HL.Boolean) << function(self)
    return (UIManager:IsOpen(PanelId.CardGameQuickMenu))
end



CardGameQuickMenuHintNode._IsVisible = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_available and DeviceInfo.usingController
end

CardGameQuickMenuHintNode._RefreshVisible = HL.Method() << function(self)
    local visible = self:_IsVisible()
    if not visible then
        self:CloseQuickMenu()
        self.view.animationWrapper:ClearTween(false)
        self.gameObject:SetActive(false)
        return
    end
    if self.gameObject.activeSelf then
        return
    end
    
    self.gameObject:SetActive(true)
    if self:IsQuickMenuOpen() then
        self.view.animationWrapper:SampleToOutAnimationEnd()
    end
end

CardGameQuickMenuHintNode._TryOpenQuickMenu = HL.Method() << function(self)
    if not self:_IsVisible() or self:IsQuickMenuOpen() or self.m_getOpenArg == nil then
        return
    end
    local openArg = self.m_getOpenArg()
    if openArg == nil then
        return
    end
    local onClose = openArg.onClose
    openArg.onClose = function()
        self:_OnQuickMenuClosed()
        if onClose then
            onClose()
        end
    end
    UIManager:Open(PanelId.CardGameQuickMenu, openArg)
    
    self:_PlaySwitchAnimation(false)
end

CardGameQuickMenuHintNode._OnQuickMenuClosed = HL.Method() << function(self)
    if self.m_isDestroyed or not self:_IsVisible() then
        return
    end
    self:_PlaySwitchAnimation(true)
end

CardGameQuickMenuHintNode._PlaySwitchAnimation = HL.Method(HL.Boolean) << function(self, isIn)
    local wrapper = self.view.animationWrapper
    wrapper:ClearTween(false)
    if isIn then
        wrapper:PlayInAnimation()
    else
        wrapper:PlayOutAnimation()
    end
end


HL.Commit(CardGameQuickMenuHintNode)
return CardGameQuickMenuHintNode
