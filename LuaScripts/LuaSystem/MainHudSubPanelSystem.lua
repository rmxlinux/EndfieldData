local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')

local MAIN_HUD_VISIBILITY_KEY = 'MainHudSubPanelSystem'
local OPENING_PANEL = {}


MainHudSubPanelSystem = HL.Class('MainHudSubPanelSystem', LuaSystemBase.LuaSystemBase)


MainHudSubPanelSystem.m_openPanels = HL.Field(HL.Table)

MainHudSubPanelSystem.m_panelRecords = HL.Field(HL.Table)
MainHudSubPanelSystem.m_mainHudOwner = HL.Field(HL.Any)
MainHudSubPanelSystem.m_mainHudAvailable = HL.Field(HL.Boolean) << false
MainHudSubPanelSystem.m_mainHudVisible = HL.Field(HL.Boolean) << false

MainHudSubPanelSystem.MainHudSubPanelSystem = HL.Constructor() << function(self)
    self.m_openPanels = {}
    self.m_panelRecords = {}
end

MainHudSubPanelSystem.OnInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.OPEN_MAIN_HUD_SUB_PANEL, function(arg)
        local panelName = unpack(arg)
        self:OpenPanelByName(panelName)
    end)
    
    self:RegisterMessage(MessageConst.CLOSE_MAIN_HUD_SUB_PANEL, function(arg)
        local panelName = unpack(arg)
        self:ClosePanelByName(panelName)
    end)
    
    self:RegisterMessage(MessageConst.APPLY_MAIN_HUD_SUB_PANEL_ACTION, function(arg)
        local panelName, actionName, actionArg = unpack(arg)
        self:ApplyActionByName(panelName, actionName, actionArg)
    end)
    
    self:RegisterMessage(MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED, function()
        self:_OnChangeInputDeviceTypeFinished()
    end)
end

MainHudSubPanelSystem.OnRelease = HL.Override() << function(self)
    self.m_mainHudAvailable = false
    self.m_mainHudVisible = false
    self.m_mainHudOwner = nil
    self.m_panelRecords = {}
    self:_CloseAllPanels()
end

MainHudSubPanelSystem.OpenPanelByName = HL.Method(HL.Opt(HL.String)).Return(HL.Opt(HL.Forward('UICtrl'))) << function(self, panelName)
    local panelId = self:_ResolvePanelId(panelName)
    if not panelId then
        return nil
    end
    return self:OpenPanel(panelId)
end

MainHudSubPanelSystem.ClosePanelByName = HL.Method(HL.Opt(HL.String)) << function(self, panelName)
    local panelId = self:_ResolvePanelId(panelName)
    if panelId then
        self:ClosePanel(panelId)
    end
end

MainHudSubPanelSystem.ApplyActionByName = HL.Method(HL.Opt(HL.String, HL.String, HL.Any)).Return(HL.Boolean)
    << function(self, panelName, actionName, actionArg)
    local panelId = self:_ResolvePanelId(panelName)
    if not panelId then
        return false
    end
    if string.isEmpty(actionName) then
        logger.error('[MainHudSubPanelSystem] ActionName为空', panelName)
        return false
    end
    return self:ApplyAction(panelId, actionName, actionArg)
end









MainHudSubPanelSystem.OpenPanel = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Opt(HL.Forward('UICtrl'))) << function(self, panelId, panelArg)
    local ctrl = self:GetPanel(panelId)
    if ctrl then
        return ctrl
    end

    if self.m_panelRecords[panelId] and UIManager.m_isHotSwitching then
        logger.warn(
            '[MainHudSubPanelSystem] 热切期间重复打开SubPanel，保留已有运行状态并等待热切结束后恢复',
            panelId)
        return nil
    end

    local panelRecord = {
        panelArg = panelArg,
        pendingActions = {},
        isFlushing = false,
    }
    local previousPanelRecord = self.m_panelRecords[panelId]
    self.m_panelRecords[panelId] = panelRecord
    ctrl = self:_OpenPanelInstance(panelId, panelRecord)
    if not ctrl and self.m_panelRecords[panelId] == panelRecord then
        self.m_panelRecords[panelId] = previousPanelRecord
    end
    return ctrl
end

MainHudSubPanelSystem._OpenPanelInstance = HL.Method(HL.Number, HL.Table, HL.Opt(HL.Any)).Return(HL.Opt(HL.Forward('UICtrl')))
    << function(self, panelId, panelRecord, restoreState)

    if self.m_openPanels[panelId] == OPENING_PANEL then
        logger.warn('[MainHudSubPanelSystem] Panel 已经被打开了', panelId)
        return nil
    end

    self.m_openPanels[panelId] = OPENING_PANEL
    local openSuccess, openResult, runtimeState = xpcall(function()
        local openedCtrl = UIManager:Open(panelId, {
            fromMHSubSystem = true,
            panelArg = panelRecord.panelArg,
            restoreState = restoreState,
            mainHudVisible = self.m_mainHudAvailable and self.m_mainHudVisible,
        })
        return openedCtrl, openedCtrl and openedCtrl:CaptureMainHudSubPanelState()
    end, debug.traceback)

    if not openSuccess then
        self.m_openPanels[panelId] = nil
        logger.error('[MainHudSubPanelSystem] UIManager.Open 打开失败', panelId, openResult)
        local isPartiallyOpen = UIManager:IsOpen(panelId)
        if isPartiallyOpen then
            UIManager:Close(panelId)
        end
        return nil
    end
    local ctrl = openResult

    local stillOpen, openedCtrl = UIManager:IsOpen(panelId)
    local valid = ctrl ~= nil
        and self.m_openPanels[panelId] == OPENING_PANEL
        and HL.TryGet(ctrl, 'IsMainHudSubPanelReady')
        and ctrl:IsMainHudSubPanelReady()

    if not valid then
        self.m_openPanels[panelId] = nil
        logger.error('[MainHudSubPanelSystem]: panel creation failed', panelId)
        if stillOpen and openedCtrl == ctrl then
            UIManager:Close(panelId)
        end
        return nil
    end

    self.m_openPanels[panelId] = ctrl
    panelRecord.runtimeState = runtimeState
    self:_RefreshPanelVisibility(panelId)
    return ctrl
end

MainHudSubPanelSystem.ClosePanel = HL.Method(HL.Number) << function(self, panelId)
    self.m_panelRecords[panelId] = nil
    self.m_openPanels[panelId] = nil
    UIManager:Close(panelId)
end

MainHudSubPanelSystem.GetPanel = HL.Method(HL.Number).Return(HL.Opt(HL.Forward('UICtrl'))) << function(self, panelId)
    local ctrl = self.m_openPanels[panelId]
    if not ctrl or ctrl == OPENING_PANEL then
        return nil
    end

    local isOpen, openedCtrl = UIManager:IsOpen(panelId)
    if not isOpen or openedCtrl ~= ctrl then
        self.m_openPanels[panelId] = nil
        return nil
    end
    return ctrl
end



MainHudSubPanelSystem.ApplyAction = HL.Method(HL.Number, HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, panelId, actionName, actionArg)
    local panelRecord = self.m_panelRecords[panelId]
    if not panelRecord then
        logger.error('[MainHudSubPanelSystem] SubPanel缺少打开记录', panelId, actionName)
        return false
    end

    panelRecord.pendingActions = panelRecord.pendingActions or {}
    panelRecord.isFlushing = panelRecord.isFlushing == true

    local ctrl = self:GetPanel(panelId)
    local mainHudHidden = not (self.m_mainHudAvailable and self.m_mainHudVisible)
    local canCache = UIManager.m_isHotSwitching
        or (mainHudHidden and self.m_mainHudAvailable and ctrl ~= nil)
    if canCache or panelRecord.isFlushing then
        table.insert(panelRecord.pendingActions, {
            actionName = actionName,
            actionArg = actionArg,
        })
        if canCache then
            logger.warn(
                '[MainHudSubPanelSystem] MainHud隐藏或热切期间触发SubPanel Action，已缓存；Show后将立即下发，请确认关卡配置允许延迟执行',
                panelId, actionName)
        end
        return true
    end

    if not ctrl then
        logger.error('[MainHudSubPanelSystem] 尝试对一个没有打开的SubPanel执行Action！检查MainHud和LevelScript的生命周期',panelId,actionName)
        return false
    end

    return self:_ExecuteAction(panelId, actionName, actionArg)
end

MainHudSubPanelSystem._ExecuteAction = HL.Method(HL.Number, HL.String, HL.Opt(HL.Any)).Return(HL.Boolean)
    << function(self, panelId, actionName, actionArg)
    local ctrl = self:GetPanel(panelId)
    if not ctrl then
        logger.error('[MainHudSubPanelSystem] 执行Action时SubPanel未打开', panelId, actionName)
        return false
    end

    local panelRecord = self.m_panelRecords[panelId]
    if not panelRecord then
        logger.error('[MainHudSubPanelSystem] 执行Action时SubPanel缺少打开记录', panelId, actionName)
        return false
    end

    local success, accepted, runtimeState = xpcall(
        function()
            local actionAccepted = ctrl:OnMainHudSubPanelAction(actionName, actionArg)
            if not actionAccepted then
                return false
            end
            return true, ctrl:CaptureMainHudSubPanelState()
        end, debug.traceback)
    if not success or not accepted then
        logger.error('[MainHudSubPanelSystem] Action 执行失败',panelId,actionName,accepted)
        return false
    end
    panelRecord.runtimeState = runtimeState
    return true
end

MainHudSubPanelSystem._FlushPendingActions = HL.Method(HL.Number) << function(self, panelId)
    if not (self.m_mainHudAvailable and self.m_mainHudVisible) then
        return
    end

    local panelRecord = self.m_panelRecords[panelId]
    if not panelRecord then
        return
    end

    panelRecord.pendingActions = panelRecord.pendingActions or {}
    if panelRecord.isFlushing or #panelRecord.pendingActions == 0 then
        return
    end

    panelRecord.isFlushing = true
    while #panelRecord.pendingActions > 0 do
        if self.m_panelRecords[panelId] ~= panelRecord
            or not (self.m_mainHudAvailable and self.m_mainHudVisible) then
            break
        end

        local pendingAction = table.remove(panelRecord.pendingActions, 1)
        local success = self:_ExecuteAction(
            panelId, pendingAction.actionName, pendingAction.actionArg)
        if not success then
            logger.error('[MainHudSubPanelSystem] 缓存的SubPanel Action执行失败', panelId, pendingAction.actionName)
        end
    end
    panelRecord.isFlushing = false
end



MainHudSubPanelSystem.OnMainHudSubPanelClosing = HL.Method(
    HL.Number, HL.Forward('UICtrl'), HL.Boolean, HL.Opt(HL.Any))
    << function(self, panelId, ctrl, captureSuccess, runtimeState)
    if self.m_openPanels[panelId] ~= ctrl then
        return
    end

    self.m_openPanels[panelId] = nil
    local panelRecord = self.m_panelRecords[panelId]
    if UIManager.m_isHotSwitching then
        if panelRecord and captureSuccess then
            panelRecord.runtimeState = runtimeState
        end
        return
    end

    self.m_panelRecords[panelId] = nil
end


MainHudSubPanelSystem.SetMainHudAvailable = HL.Method(HL.Boolean, HL.Opt(HL.Any)) << function(self, available, owner)
    if available then
        if self.m_mainHudOwner ~= owner then
            self.m_mainHudVisible = false
        end
        self.m_mainHudOwner = owner
        self.m_mainHudAvailable = true
        self:_RefreshAllPanelVisibility()
        return
    end
    if owner ~= nil
        and self.m_mainHudOwner ~= nil
        and self.m_mainHudOwner ~= owner then
        return
    end

    self.m_mainHudVisible = false
    self.m_mainHudAvailable = false
    self:_RefreshAllPanelVisibility()
    if not UIManager.m_isHotSwitching then
        self.m_panelRecords = {}
    end
    self:_CloseAllPanels()
    self.m_mainHudOwner = nil
end

MainHudSubPanelSystem.SetMainHudVisible = HL.Method(HL.Boolean, HL.Opt(HL.Any)) << function(self, visible, owner)
    if owner ~= nil
        and self.m_mainHudOwner ~= nil
        and self.m_mainHudOwner ~= owner then
        return
    end
    if visible and not self.m_mainHudAvailable then
        logger.error('[MainHudSubPanelSystem]: MainHud is unavailable')
        return
    end

    self.m_mainHudVisible = visible
    self:_RefreshAllPanelVisibility()
end


MainHudSubPanelSystem._ResolvePanelId = HL.Method(HL.Opt(HL.String)).Return(HL.Opt(HL.Number)) << function(self, panelName)
    if string.isEmpty(panelName) then
        logger.error('[MainHudSubPanelSystem]: panelName 为空')
        return nil
    end

    local panelId = PanelId[panelName]
    if not panelId then
        logger.error('[MainHudSubPanelSystem] 非法的PaneName: ',panelName)
        return nil
    end
    return panelId
end

MainHudSubPanelSystem._RefreshPanelVisibility = HL.Method(HL.Number) << function(self, panelId)
    local ctrl = self:GetPanel(panelId)
    if not ctrl then
        return
    end

    local visible = self.m_mainHudAvailable and self.m_mainHudVisible
    ctrl:SetMainHudVisible(visible)
    if visible then
        UIManager:ShowWithKey(panelId, MAIN_HUD_VISIBILITY_KEY)
        self:_FlushPendingActions(panelId)
    else
        UIManager:HideWithKey(panelId, MAIN_HUD_VISIBILITY_KEY)
        local panelRecord = self.m_panelRecords[panelId]
        if panelRecord then
            local success, runtimeState = xpcall(function()
                return ctrl:CaptureMainHudSubPanelState()
            end, debug.traceback)
            if success then
                panelRecord.runtimeState = runtimeState
            else
                logger.error('[MainHudSubPanelSystem] MainHud隐藏时保存SubPanel状态失败',panelId, runtimeState)
            end
        end
    end
end

MainHudSubPanelSystem._RefreshAllPanelVisibility = HL.Method() << function(self)
    local panelIds = {}
    for panelId, ctrl in pairs(self.m_openPanels) do
        if ctrl ~= OPENING_PANEL then
            table.insert(panelIds, panelId)
        end
    end
    for _, panelId in ipairs(panelIds) do
        self:_RefreshPanelVisibility(panelId)
    end
end



MainHudSubPanelSystem._OnChangeInputDeviceTypeFinished = HL.Method() << function(self)
    if next(self.m_panelRecords) == nil then
        return
    end
    if not self.m_mainHudAvailable then
        logger.error('[MainHudSubPanelSystem] 热切结束时MainHud不可用，无法恢复SubPanel')
        self.m_panelRecords = {}
        return
    end

    local panelIds = {}
    for panelId, _ in pairs(self.m_panelRecords) do
        table.insert(panelIds, panelId)
    end
    for _, panelId in ipairs(panelIds) do
        local panelRecord = self.m_panelRecords[panelId]
        if panelRecord and not self:GetPanel(panelId) then
            local ctrl = self:_OpenPanelInstance(panelId, panelRecord, panelRecord.runtimeState)
            if not ctrl and self.m_panelRecords[panelId] == panelRecord then
                self.m_panelRecords[panelId] = nil
            end
        end
    end
end

MainHudSubPanelSystem._CloseAllPanels = HL.Method() << function(self)
    local panelIds = {}
    for panelId, _ in pairs(self.m_openPanels) do
        table.insert(panelIds, panelId)
    end
    for _, panelId in ipairs(panelIds) do
        self.m_openPanels[panelId] = nil
        UIManager:Close(panelId)
    end
    self.m_openPanels = {}
end

HL.Commit(MainHudSubPanelSystem)
return MainHudSubPanelSystem
