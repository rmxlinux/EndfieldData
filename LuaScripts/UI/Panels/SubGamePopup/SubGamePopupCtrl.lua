local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SubGamePopup

SubGamePopupCtrl = HL.Class('SubGamePopupCtrl', uiCtrl.UICtrl)







SubGamePopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STAMINA_CHANGED] = "OnStaminaChanged",
}

SubGamePopupCtrl.m_isInterrupted = HL.Field(HL.Boolean) << false

SubGamePopupCtrl.m_args = HL.Field(HL.Table)


SubGamePopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    if arg and GameWorld.worldInfo.curSubGameId == Tables.gambleBattleConst.gambleBattleDungeonId then
        arg.showRestartBtn = false
    end
    self.view.confirmButton.onClick:AddListener(function()
        self:_OnClickConfirm()
    end)
    self.view.cancelButton.onClick:AddListener(function()
        self:_OnClickCancel()
    end)

    self.view.toggle.tipsBtn.onClick:AddListener(function()
        local toggleArg = self.m_args.toggle
        if toggleArg and not string.isEmpty(toggleArg.toggleTips) then
            if self.view.toggle.tipsInfoNode.gameObject.activeSelf then
                self.view.toggle.tipsInfoNode:CloseSelf()
            else
                self.view.toggle.tipsInfoNode:OpenSelf()
                if DeviceInfo.usingController then
                    self.view.toggle.tipsInfoNaviGroup:ManuallyFocus()
                end
            end
        end
    end)
    self.view.toggle.tipsInfoNaviGroup.onIsFocusedChange:AddListener(function(isFocus)
        if not isFocus then
            self.view.toggle.tipsInfoNode:CloseSelf()
        end
    end)

    if arg then
        UIManager:SetTopOrder(PANEL_ID)
        self:_ShowPopUp(arg)
    end
end

SubGamePopupCtrl.OnClose = HL.Override() << function(self)
    self:_TryProcessInterruptMessage(false)
    self.m_args = nil
end

SubGamePopupCtrl.OnStaminaChanged = HL.Method() << function(self)
    self:_RefreshCostStaminaInfo()
end


SubGamePopupCtrl._ShowPopUp = HL.Method(HL.Table) << function(self, args)
    self.view.fullScreenMask.gameObject:SetActive(false)

    self.m_args = args
    self.m_isInterrupted = false

    self.view.contentText:SetAndResolveTextStyle(args.content)

    if args.subContent then
        self.view.subText:SetAndResolveTextStyle(args.subContent)
        self.view.subText.gameObject:SetActiveIfNecessary(true)
    else
        self.view.subText.gameObject:SetActiveIfNecessary(false)
    end

    if args.warningContent then
        self.view.warningNode.warningText:SetAndResolveTextStyle(args.warningContent)
        self.view.warningNode.gameObject:SetActive(true)
    else
        self.view.warningNode.gameObject:SetActive(false)
    end

    if args.secondWarningContent then
        self.view.secondWarningNode.warningText:SetAndResolveTextStyle(args.secondWarningContent)
        self.view.secondWarningNode.gameObject:SetActive(true)
    else
        self.view.secondWarningNode.gameObject:SetActive(false)
    end

    self.view.confirmButton.text = args.confirmText or Language.LUA_CONFIRM
    self.view.cancelButton.text = args.cancelText or Language.LUA_CANCEL

    local hideCancel = args.hideCancel == true
    self.view.cancelButton.gameObject:SetActive(not hideCancel)
    self.view.oneBtnBg.gameObject:SetActive(hideCancel)
    self.view.twoBtnBg.gameObject:SetActive(not hideCancel)

    local toggleArg = self.m_args.toggle
    if toggleArg ~= nil then
        
        self.view.toggle.toggle.onValueChanged:RemoveAllListeners()
        self.view.toggle.toggle.onValueChanged:AddListener(function(isOn)
            local onValueChanged = toggleArg.onValueChanged
            if onValueChanged ~= nil then
                onValueChanged(isOn)
            end
        end)
        
        local styleType = toggleArg.styleType or EToggleStyle.Square
        self:_SetToggleStyle(styleType)
        
        self.view.toggle.gameObject:SetActive(true)
        
        self.view.toggle.toggleText.text = toggleArg.toggleText
        self.view.toggle.toggle.isOn = toggleArg.isOn
        if toggleArg.onHintTextId ~= nil then
            self.view.toggle.toggle.onHintTextId = toggleArg.onHintTextId
        end
        if toggleArg.offHintTextId ~= nil then
            self.view.toggle.toggle.offHintTextId = toggleArg.offHintTextId
        end
        if toggleArg.onHintTextId ~= nil or toggleArg.offHintTextId ~= nil then
            self.view.toggle.toggle:RefreshHintText()
        end
        
        if string.isEmpty(toggleArg.toggleTips) then
            self.view.toggle.tipsNode.gameObject:SetActive(false)
        else
            self.view.toggle.tipsInfoNode.gameObject:SetActive(false)
            self.view.toggle.tipsNode.gameObject:SetActive(true)
            self.view.toggle.tipsInfoTxt:SetAndResolveTextStyle(toggleArg.toggleTips)
        end
    else
        
        self.view.toggle.gameObject:SetActive(false)
    end

    if self.m_args.staminaInfo then
        self:_RefreshCostStaminaInfo()
        self.view.walletBarPlaceholder:InitWalletBarPlaceholder(UIConst.REGION_MAP_STAMINA_IDS, false, false, true)
    else
        Notify(MessageConst.HIDE_WALLET_BAR, PANEL_ID)
    end
    self.view.staminaNode.gameObject:SetActive(self.m_args.staminaInfo ~= nil)

    
    if self.m_args.showGameSettingBtn then
        self.view.setBtn.onClick:RemoveAllListeners()
        self.view.setBtn.onClick:AddListener(function()
            self:PlayAnimationOutWithCallback(function()
                self:Close()
                PhaseManager:OpenPhaseFast(PhaseId.GameSetting)
            end)
        end)
    end
    self.view.setNode.gameObject:SetActive(self.m_args.showGameSettingBtn)

    local curSubGameId = GameWorld.worldInfo.curSubGameId
    local isGambleBattle = curSubGameId == Tables.gambleBattleConst.gambleBattleDungeonId
    local succ, gameMechanicsCategoryCfg = GameMechanicsUtils.tryGetGameMechanicCategoryCfg(curSubGameId)
    
    local showRestartBtn = (not isGambleBattle) and succ and gameMechanicsCategoryCfg.canReChallenge and self.m_args.showRestartBtn
    if showRestartBtn then
        local curStatus = GameWorld.worldInfo.subGame:GetCurrentCompletionStatus()
        self.view.restartBtn.onClick:RemoveAllListeners()
        self.view.restartBtn.onClick:AddListener(function()
            GameWorld.worldInfo.subGame:UserSendReStartAtStatus(curStatus)
            self:Close()
        end)
    end
    self.view.restartNode.gameObject:SetActive(showRestartBtn)

    self:_TryProcessInterruptMessage(true)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

SubGamePopupCtrl._OnClickConfirm = HL.Method() << function(self)
    local args = self.m_args
    local function onConfirm()
        if self.m_isInterrupted then
            
            return
        end
        if args.onConfirm then
            args.onConfirm()
        end
    end
    if self:IsPlayingAnimationOut() then
        self:Close()
        onConfirm()
    else
        self:PlayAnimationOutWithCallback(function()
            self:Close()
            onConfirm()
        end)
    end

    
    self.view.fullScreenMask.gameObject:SetActive(true)
    self.view.fullScreenMask.enabled = true
end

SubGamePopupCtrl._OnClickCancel = HL.Method() << function(self)
    local onCancel = self.m_args.onCancel
    if self:IsPlayingAnimationOut() then
        self:Close()
        if onCancel then
            onCancel()
        end
    else
        self:PlayAnimationOutWithCallback(function()
            self:Close()
            if onCancel then
                onCancel()
            end
        end)
    end
end



SubGamePopupCtrl._RefreshCostStaminaInfo = HL.Method() << function(self)
    if not self.m_args then
        return
    end

    if not self.m_args.staminaInfo then
        return
    end

    UIUtils.updateStaminaNode(self.view.staminaNode, self.m_args.staminaInfo)
end

SubGamePopupCtrl._SetToggleStyle = HL.Method(HL.String) << function(self, styleType)
    
    if self.view.toggle.square then
        self.view.toggle.square.gameObject:SetActive(false)
    end
    if self.view.toggle.circle then
        self.view.toggle.circle.gameObject:SetActive(false)
    end

    
    if styleType == EToggleStyle.Square and self.view.toggle.square then
        self.view.toggle.square.gameObject:SetActive(true)
        if self.view.toggle.checkmark then
            self.view.toggle.toggle.graphic = self.view.toggle.checkmark
            self.view.toggle.toggle.targetGraphic = self.view.toggle.square
        end
    elseif styleType == EToggleStyle.Circle and self.view.toggle.circle then
        self.view.toggle.circle.gameObject:SetActive(true)
        if self.view.toggle.dotmark then
            self.view.toggle.toggle.graphic = self.view.toggle.dotmark
            self.view.toggle.toggle.targetGraphic = self.view.toggle.circle
        end
    end
end


SubGamePopupCtrl._TryProcessInterruptMessage = HL.Method(HL.Boolean) << function(self, register)
    local interrupt = self.m_args and self.m_args.interrupt
    if not interrupt then
        return
    end

    local groupKey = "SubGamePopupInterruptMessage"
    for _, message in ipairs(interrupt.interruptMessage) do
        if register then
            MessageManager:Register(message, function()
                self.m_isInterrupted = true
                
                if interrupt.onInterrupt then
                    interrupt.onInterrupt()
                end
                self:Close()
            end, groupKey)
        else
            MessageManager:UnregisterAll(groupKey)
        end
    end
end

HL.Commit(SubGamePopupCtrl)
