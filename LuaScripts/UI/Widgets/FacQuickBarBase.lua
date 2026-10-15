local UIWidgetBase = require_ex("Common/Core/UIWidgetBase")


FacQuickBarBase = HL.Class("FacQuickBarBase", UIWidgetBase)




FacQuickBarBase.m_args = HL.Field(HL.Table) 

FacQuickBarBase.InitFacQuickBar = HL.Method(HL.Table) << function(self, args)
    self.m_args = args
    self:_FirstTimeInit()

    self:_OnInitFacQuickBar(args)
end

FacQuickBarBase._OnInitFacQuickBar = HL.Virtual(HL.Table) << function(self, args)
    
end

FacQuickBarBase.RefreshFacQuickBar = HL.Virtual() << function(self)
    
end




FacQuickBarBase.m_isActive = HL.Field(HL.Any)

FacQuickBarBase.IsActive = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isActive == true
end

FacQuickBarBase.Activate = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self.m_args == nil then
        logger.error("[FacHud] QuickBar not initialized")
        return
    end
    if self.m_isActive == true then
        return
    end

    logger.info("[FacHud] Activate QuickBar")

    self.m_isActive = true
    self:_OnActivate(args)

    local onActiveStateChange = self.m_args and self.m_args.onActiveStateChange
    if onActiveStateChange then
        onActiveStateChange(true, args)
    end
end

FacQuickBarBase._OnActivate = HL.Virtual(HL.Opt(HL.Any)) << function(self, args)
    
end

FacQuickBarBase.Deactivate = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self.m_args == nil then
        return
    end
    if self.m_isActive == false then
        return
    end

    logger.info("[FacHud] Deactivate QuickBar")

    self.m_isActive = false
    self:_OnDeactivate(args)

    local onActiveStateChange = self.m_args and self.m_args.onActiveStateChange
    if onActiveStateChange then
        onActiveStateChange(false, args)
    end
end

FacQuickBarBase._OnDeactivate = HL.Virtual(HL.Opt(HL.Any)) << function(self, args)
    
end






FacQuickBarBase.RecordControllerNaviInfo = HL.Virtual(HL.Table) << function(self, controllerNaviInfo)
    
end

FacQuickBarBase.TryRecoverControllerNaviInfo = HL.Virtual(HL.Table) << function(self, controllerNaviInfo)
    
end






FacQuickBarBase.ExtractHotSwitchRuntimeState = HL.Virtual().Return(HL.Opt(HL.Table)) << function(self)
    return nil
end

FacQuickBarBase.RestoreHotSwitchRuntimeState = HL.Virtual(HL.Opt(HL.Table)) << function(self, state)
end






FacQuickBarBase.GetCurStateArg = HL.Virtual(HL.Table) << function(self, arg)
    
end

FacQuickBarBase.RecoverStateOnChangeDevice = HL.Virtual(HL.Table) << function(self, arg)
    
end




HL.Commit(FacQuickBarBase)
return FacQuickBarBase
