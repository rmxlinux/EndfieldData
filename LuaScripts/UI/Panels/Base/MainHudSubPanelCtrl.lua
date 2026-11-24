local uiCtrl = require_ex('UI/Panels/Base/UICtrl')


MainHudSubPanelCtrl = HL.Class('MainHudSubPanelCtrl', uiCtrl.UICtrl)

MainHudSubPanelCtrl.m_isMainHudSubPanelAuthorized = HL.Field(HL.Boolean) << false
MainHudSubPanelCtrl.m_isMainHudSubPanelReady = HL.Field(HL.Boolean) << false
MainHudSubPanelCtrl.m_mainHudVisible = HL.Field(HL.Boolean) << false
MainHudSubPanelCtrl.m_isFollowingMainHudVisible = HL.Field(HL.Boolean) << false



MainHudSubPanelCtrl.OnCreate = HL.Final(HL.Opt(HL.Any)) << function(self, arg)
    if arg == nil then
        logger.error('MainHudSubPanelCtrl.OnCreate: panel must be opened by MainHudSubPanelSystem',self.panelCfg.name)
        return
    end
    local authorized = arg.fromMHSubSystem
    local panelArg = arg.panelArg
    local restoreState = arg.restoreState
    local mainHudVisible = arg.mainHudVisible

    if not authorized then
        logger.error('MainHudSubPanelCtrl.OnCreate: panel must be opened by MainHudSubPanelSystem',self.panelCfg.name)
        self.view.gameObject:SetActive(false)
        return
    end

    self.m_isMainHudSubPanelAuthorized = true
    self.m_mainHudVisible = mainHudVisible == true
    self:OnMainHudSubPanelCreate(panelArg)
    
    if restoreState ~= nil then
        self:RestoreMainHudSubPanelState(restoreState)
    end
    self.m_isMainHudSubPanelReady = true
end

MainHudSubPanelCtrl.OnShow = HL.Final() << function(self)
    if self.m_isMainHudSubPanelReady and self.m_mainHudVisible and not self.m_isFollowingMainHudVisible then
        self.m_isFollowingMainHudVisible = true
        self:OnMainHudSubPanelShow()
    end
end

MainHudSubPanelCtrl.OnHide = HL.Final() << function(self)
    if self.m_isMainHudSubPanelReady and self.m_isFollowingMainHudVisible then
        self.m_isFollowingMainHudVisible = false
        self:OnMainHudSubPanelHide()
    end
end

MainHudSubPanelCtrl.OnClose = HL.Final() << function(self)
    if self.m_isMainHudSubPanelReady then
        
        local captureSuccess, runtimeState = xpcall(function()
            return self:CaptureMainHudSubPanelState()
        end, debug.traceback)
        if not captureSuccess then
            logger.error("[MainHudSubPanelCtrl] 关闭SubPanel时，获取runtimeState失败", self.panelCfg.name, runtimeState)
        end

        local notifySuccess, notifyError = xpcall(
            function()
                
                LuaSystemManager.mainHudSubPanel:OnMainHudSubPanelClosing(self.panelId, self, captureSuccess, runtimeState)
            end, debug.traceback)
        if not notifySuccess then
            logger.error("[MainHudSubPanelCtrl] 关闭SubPanel时，RunTimeState上报System层失败", self.panelCfg.name, notifyError)
        end
    end

    local success, errorInfo = xpcall(function()
        if self.m_isMainHudSubPanelReady then
            self:OnMainHudSubPanelClose()
        end
    end, debug.traceback)

    self.m_isMainHudSubPanelAuthorized = false
    self.m_isMainHudSubPanelReady = false
    self.m_mainHudVisible = false
    self.m_isFollowingMainHudVisible = false

    if not success then
        logger.error("[MainHudSubPanelCtrl] 关闭失败", errorInfo)
    end
end



MainHudSubPanelCtrl.SetMainHudVisible = HL.Method(HL.Boolean) << function(
    self, visible)
    self.m_mainHudVisible = visible
end

MainHudSubPanelCtrl.OnMainHudSubPanelCreate = HL.Virtual(HL.Opt(HL.Any)) << function(self, arg)
end

MainHudSubPanelCtrl.OnMainHudSubPanelShow = HL.Virtual() << function(self)
end

MainHudSubPanelCtrl.OnMainHudSubPanelHide = HL.Virtual() << function(self)
end

MainHudSubPanelCtrl.OnMainHudSubPanelClose = HL.Virtual() << function(self)
end


MainHudSubPanelCtrl.CaptureMainHudSubPanelState = HL.Virtual().Return(HL.Opt(HL.Any)) << function(self)
    return nil
end

MainHudSubPanelCtrl.RestoreMainHudSubPanelState = HL.Virtual(HL.Opt(HL.Any))
    << function(self, state)
end


MainHudSubPanelCtrl.OnMainHudSubPanelAction = HL.Virtual(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, actionName, actionArg)
    return false
end

MainHudSubPanelCtrl.IsMainHudSubPanelAuthorized = HL.Method()
    .Return(HL.Boolean) << function(self)
    return self.m_isMainHudSubPanelAuthorized
end

MainHudSubPanelCtrl.IsMainHudSubPanelReady = HL.Method()
    .Return(HL.Boolean) << function(self)
    return self.m_isMainHudSubPanelReady
end

HL.Commit(MainHudSubPanelCtrl)
