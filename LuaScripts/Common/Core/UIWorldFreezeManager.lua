local panelConfig = require_ex("UI/Panels/PanelConfig").config

UIWorldFreezeManager = HL.Class('UIWorldFreezeManager')


do

    
    UIWorldFreezeManager.m_timeScaleHandle = HL.Field(HL.Number) << -1

    
    
    
    
    
    UIWorldFreezeManager.m_freezeWorldHolders = HL.Field(HL.Table)

    UIWorldFreezeManager.m_pauseGameModeHolders = HL.Field(HL.Table)

    
    UIWorldFreezeManager.m_pauseGameModeApplied = HL.Field(HL.Boolean) << false

    
    
    
    
    
    UIWorldFreezeManager.m_suspendedByLayerHide = HL.Field(HL.Boolean) << false
end


do
    UIWorldFreezeManager.UIWorldFreezeManager = HL.Constructor() << function(self)
        self.m_freezeWorldHolders = {}
        self.m_pauseGameModeHolders = {}
        self:_RegisterMessages()
    end

    UIWorldFreezeManager.IsUIWorldFreeze = HL.Method().Return(HL.Boolean) << function(self)
        return self.m_timeScaleHandle ~= -1
    end

    
    
    
    UIWorldFreezeManager.AddFreezeHolder = HL.Method(HL.String, HL.Opt(HL.Boolean))
            << function(self, key, pauseGameMode)
        self.m_freezeWorldHolders[key] = true
        if pauseGameMode == true then
            self.m_pauseGameModeHolders[key] = true
        else
            self.m_pauseGameModeHolders[key] = nil
        end
        self:_UpdateFreeze()
    end

    UIWorldFreezeManager.RemoveFreezeHolder = HL.Method(HL.String) << function(self, key)
        self.m_freezeWorldHolders[key] = nil
        self.m_pauseGameModeHolders[key] = nil
        self:_UpdateFreeze()
    end

    UIWorldFreezeManager.HasFreezeHolder = HL.Method(HL.String).Return(HL.Boolean) << function(self, key)
        return self.m_freezeWorldHolders[key] == true
    end

    
    UIWorldFreezeManager.SetUILayerHidden = HL.Method(HL.Boolean) << function(self, isHidden)
        if self.m_suspendedByLayerHide == isHidden then
            return
        end

        self.m_suspendedByLayerHide = isHidden
        self:_UpdateFreeze()
    end

    
    
    UIWorldFreezeManager.DumpFreezeHolders = HL.Method().Return(HL.String) << function(self)
        local lines = {}
        lines[#lines + 1] = string.format(
            "[UIWorldFreezeManager] handle=%s, suspendedByLayerHide=%s, pauseGameModeApplied=%s",
            tostring(self.m_timeScaleHandle), tostring(self.m_suspendedByLayerHide),
            tostring(self.m_pauseGameModeApplied))
        local holderCount = 0
        for key, _ in pairs(self.m_freezeWorldHolders) do
            holderCount = holderCount + 1
            lines[#lines + 1] = string.format("  holder=%s (%s), pauseGameMode=%s", key,
                                              self:_DescribeHolderPanel(key),
                                              tostring(self.m_pauseGameModeHolders[key] == true))
        end
        if holderCount == 0 then
            lines[#lines + 1] = "  <no holders>"
        end
        return table.concat(lines, "\n")
    end
end


do
    UIWorldFreezeManager._RegisterMessages = HL.Method() << function(self)
        Register(MessageConst.ON_BEFORE_UI_PANEL_OPEN, function(name)
            self:_OnPanelActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_CLOSED, function(name)
            self:_OnPanelDeActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_SHOW, function(name)
            self:_OnPanelActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_HIDE, function(name)
            self:_OnPanelDeActivate(name)
        end)
        
        
        Register(MessageConst.ON_DO_CLOSE_MAP, function()
            self:_AuditFreezeHoldersOnMapClose()
        end)
    end

    UIWorldFreezeManager._OnPanelActivate = HL.Method(HL.String) << function(self, panelName)
        local panelCfg = panelConfig[panelName]
        if not panelCfg or not panelCfg.freezeWorld then
            return
        end

        self.m_freezeWorldHolders[panelName] = true
        if not panelCfg.dontPauseGameMode then
            self.m_pauseGameModeHolders[panelName] = true
        end
        self:_UpdateFreeze()
    end

    UIWorldFreezeManager._OnPanelDeActivate = HL.Method(HL.String) << function(self, panelName)
        local panelCfg = panelConfig[panelName]
        if not panelCfg or not panelCfg.freezeWorld then
            return
        end

        self.m_freezeWorldHolders[panelName] = nil
        self.m_pauseGameModeHolders[panelName] = nil
        self:_UpdateFreeze()
    end

    
    UIWorldFreezeManager._UpdateFreeze = HL.Method() << function(self)
        local wantFreezeWorld = not self.m_suspendedByLayerHide and next(self.m_freezeWorldHolders) ~= nil
        if wantFreezeWorld ~= (self.m_timeScaleHandle ~= -1) then
            if wantFreezeWorld then
                self:_ApplyFreeze()
            else
                self:_ReleaseFreeze()
            end
        end

        local wantPauseGameMode = not self.m_suspendedByLayerHide and next(self.m_pauseGameModeHolders) ~= nil
        if wantPauseGameMode ~= self.m_pauseGameModeApplied and GameWorld.isInited then
            self.m_pauseGameModeApplied = wantPauseGameMode
            if wantPauseGameMode then
                GameWorld.subGameManager:TryPauseGameTime(GEnums.GameTimeFreezeReason.UI)
            else
                GameWorld.subGameManager:TryResumeGameTime(GEnums.GameTimeFreezeReason.UI)
            end
        end
    end

    
    UIWorldFreezeManager._ApplyFreeze = HL.Method() << function(self)
        self.m_timeScaleHandle = TimeManagerInst:StartChangeTimeScale(0,
            CS.Beyond.TimeManager.ChangeTimeScaleReason.UIPanel)
        if GameWorld.isInited then
            GameWorld.cutsceneManager:PauseTimelineByUI(true)
            GameWorld.levelSeqManager:PauseTimelineByUI(true)
            GameWorld.dialogTimelineManager:PauseTimelineByUI(true)
        end
        AudioAdapter.PostEvent("au_global_contr_fullscreen_menu_pause")
    end

    UIWorldFreezeManager._ReleaseFreeze = HL.Method() << function(self)
        if self.m_timeScaleHandle <= 0 then
            return
        end

        TimeManagerInst:StopChangeTimeScale(self.m_timeScaleHandle)
        self.m_timeScaleHandle = -1
        if GameWorld.isInited then
            GameWorld.cutsceneManager:PauseTimelineByUI(false)
            GameWorld.levelSeqManager:PauseTimelineByUI(false)
            GameWorld.dialogTimelineManager:PauseTimelineByUI(false)
        end
        AudioAdapter.PostEvent("au_global_contr_fullscreen_menu_resume")
    end

    
    UIWorldFreezeManager._GetHolderPanelName = HL.Method(HL.String).Return(HL.String) << function(self, key)
        if string.sub(key, 1, 1) == "@" then
            return string.sub(key, 2)
        end
        return key
    end

    
    UIWorldFreezeManager._DescribeHolderPanel = HL.Method(HL.String).Return(HL.String) << function(self, key)
        local panelId = PanelId[self:_GetHolderPanelName(key)]
        if not panelId then
            return "no-panel"
        end
        return string.format("open=%s,show=%s", tostring(UIManager:IsOpen(panelId)),
                             tostring(UIManager:IsShow(panelId)))
    end

    
    
    
    
    UIWorldFreezeManager._AuditFreezeHoldersOnMapClose = HL.Method() << function(self)
        if self.m_suspendedByLayerHide then
            
            return
        end

        local leakedKeys = {}
        for key, _ in pairs(self.m_freezeWorldHolders) do
            local isExternal = string.sub(key, 1, 1) == "@"
            local panelId = PanelId[self:_GetHolderPanelName(key)]
            if panelId and (not UIManager:IsOpen(panelId) or not UIManager:IsShow(panelId)) then
                if isExternal then
                    logger.info("[UIWorldFreezeManager] 外部时停 holder 对应的面板未打开或未显示:",
                                key, self:_DescribeHolderPanel(key))
                else
                    leakedKeys[#leakedKeys + 1] = key
                    logger.error("[UIWorldFreezeManager] 时停泄漏：面板已关闭或未显示，但时停 holder 没释放:",
                                 key, self:_DescribeHolderPanel(key))
                end
            end
        end

        if #leakedKeys == 0 then
            return
        end

        for _, key in ipairs(leakedKeys) do
            self.m_freezeWorldHolders[key] = nil
            self.m_pauseGameModeHolders[key] = nil
        end
        self:_UpdateFreeze()
    end
end

HL.Commit(UIWorldFreezeManager)
return UIWorldFreezeManager
