local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Dialog




















































PhaseDialog = HL.Class('PhaseDialog', phaseBase.PhaseBase)

local clearPhases = {
    PhaseId.CharInfo,
    PhaseId.CharFormation,
}






PhaseDialog.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_DIALOG_START] = { 'OnDirectDialogStart', false },
    [MessageConst.ON_EXIT_DIALOG] = { 'OnExitDialog', true },
    [MessageConst.ON_PLAY_DIALOG_TRUNK] = { 'OnPlayDialogTrunk', true },
    [MessageConst.ON_SHOW_DIALOG_OPTION] = { 'OnShowDialogOption', true },
    [MessageConst.DIALOG_PANEL_SHOW_FULL_BG] = { 'OnShowDialogFullBg', true },
    [MessageConst.DIALOG_PANEL_SHOW_POST_PROCESS_EFFECT] = {"OnShowPostProcessEffect", true},
    [MessageConst.DIALOG_PANEL_SHOW_LEFT_SUBTITLE] = { 'OnShowDialogLeftSubtitle', true },
    [MessageConst.DIALOG_PANEL_EXIT_LEFT_SUBTITLE] = { 'OnExitDialogLeftSubtitle', true },
    [MessageConst.ON_DIALOG_ENV_TALK_CHANGED] = { 'OnDialogEnvTalkChanged', true },
    [MessageConst.ON_COMMON_BACK_CLICKED] = { 'OnCommonBackClicked', true },
    [MessageConst.DIALOG_OPEN_UI] = { "OpenUI", true },
    [MessageConst.DIALOG_CLOSE_UI] = { 'CloseUI', false },
    [MessageConst.DIALOG_SEND_PRESENT_END] = { "OnSendPresentEnd", true },

    [MessageConst.OPEN_DIALOG_RECORD] = { '_OpenDialogRecord', true },
    [MessageConst.HIDE_DIALOG_RECORD] = { '_HideDialogRecord', true },

    [MessageConst.OPEN_DIALOG_SKIP_POP_UP] = { '_OpenDialogSkipPopUp', true },
    [MessageConst.HIDE_DIALOG_SKIP_POP_UP] = { '_HideDialogSkipPopUp', true },
    [MessageConst.SKIP_DIALOG] = { '_SkipDialog', true },
}


PhaseDialog.m_panelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseDialog.m_targetGroup = HL.Field(HL.Forward("PhaseGameObjectItem"))


PhaseDialog.m_inited = HL.Field(HL.Boolean) << false


PhaseDialog.doingOut = HL.Field(HL.Boolean) << false


PhaseDialog.m_onRightMouseButtonPress = HL.Field(HL.Function)


PhaseDialog.m_onDrag = HL.Field(HL.Function)


PhaseDialog.m_hasListened = HL.Field(HL.Boolean) << false


PhaseDialog.s_nextDialog = HL.StaticField(HL.String) << ""





PhaseDialog._OnInit = HL.Override() << function(self)
    PhaseDialog.Super._OnInit(self)
    UIManager:ToggleBlockObtainWaysJump("IN_CINEMATIC", true)
end



PhaseDialog.ClearPhasesWithCam = HL.StaticMethod(HL.Opt(HL.Any)) << function(_)
    for _, phaseId in pairs(clearPhases) do
        local isOpen, phase = PhaseManager:IsOpen(phaseId)
        if isOpen then
            PhaseManager:ExitPhaseFast(phaseId)
        end
    end
end



PhaseDialog.OnDialogStart = HL.StaticMethod(HL.Table) << function(arg)
    arg.fast = true
    local isOpen, _ = PhaseManager:IsOpen(PhaseId.Dialog)
    if not isOpen then
        PhaseDialog.AutoOpen(PHASE_ID, arg)
    else
        if phase.doingOut then
            local nextDialog = GameWorld.dialogManager.dialogId
            logger.info("Dialog already open: " .. nextDialog)
            PhaseDialog.s_nextDialog = nextDialog
        end
    end
end



PhaseDialog.OnDirectDialogStart = HL.StaticMethod(HL.Opt(HL.Table)) << function(data)
    local arg = {
        direct = true,
        fast = true,
    }

    local inWaitingQueue =  PhaseManager:IsInWaitingQueue(PhaseId.Dialog)
    if inWaitingQueue then
        return
    end

    local isOpen, phase = PhaseManager:IsOpen(PhaseId.Dialog)
    if not isOpen then
        local res = PhaseDialog.AutoOpen(PHASE_ID, arg)
        if not res then
            logger.warn("PhaseDialog Open Failed!!!!")
        end
    else
        if phase.doingOut then
            local nextDialog = GameWorld.dialogManager.dialogId
            logger.info("Dialog already open: " .. nextDialog)
            PhaseDialog.s_nextDialog = nextDialog
        end
    end
end




PhaseDialog.OnShowDialogFullBg = HL.Method(HL.Table) << function(self, data)
    local actionData = unpack(data)
    self:_DoShowFullBg(actionData)
end




PhaseDialog.OnShowPostProcessEffect = HL.Method(HL.Table) << function(self, data)
    local actionData = unpack(data)
    self.m_panelItem.uiCtrl:SetPostProcessEffect(actionData)
    self.m_panelItem.uiCtrl:Show()
    self.m_inited = true
end




PhaseDialog.OnShowDialogLeftSubtitle = HL.Method(HL.Table) << function(self, data)
    local actionData = unpack(data)
    self:_DoShowLeftSubtitle(actionData)
end



PhaseDialog.OnExitDialogLeftSubtitle = HL.Method() << function(self)
    self:_DoExitLeftSubtitle()
end




PhaseDialog.OnDialogEnvTalkChanged = HL.Method(HL.Table) << function(self, arg)
    self:_GetPanelPhaseItem(PanelId.HeadLabelInDialog).uiCtrl:RefreshEnvTalk(arg)
end




PhaseDialog._InitAllPhaseItems = HL.Override() << function(self)
    PhaseDialog.Super._InitAllPhaseItems(self)
    self.m_panelItem = self:_GetPanelPhaseItem(PanelId.Dialog)
    self.m_panelItem.uiCtrl:Hide()
end



PhaseDialog.OnCommonBackClicked = HL.Method() << function(self)
end




PhaseDialog.OnExitDialog = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local fast = false
    if arg then
        fast = unpack(arg)
    end

    
    UIManager:Hide(PanelId.CommonPopUp)

    if not fast then
        self.doingOut = true
        self.m_panelItem.uiCtrl:PlayAnimationOutWithCallback(function()
            if PhaseManager:IsOpenAndValid(PHASE_ID) then
                self:ExitSelfFast()
            end

            if not string.isEmpty(PhaseDialog.s_nextDialog) then
                PhaseDialog.s_nextDialog = ""
                PhaseDialog.OnDirectDialogStart()
            end
        end)
    else
        self:ExitSelfFast()
    end
end





PhaseDialog.OnPlayDialogTrunk = HL.Method(HL.Table) << function(self, data)
    local trunkNodeData, fastMode, npcId, npcGroupId = unpack(data)
    self:_DoPlayDialogTrunk(trunkNodeData, fastMode, npcId, npcGroupId)
end




PhaseDialog.OnShowDialogOption = HL.Method(HL.Table) << function(self, data)
    local options = unpack(data)
    self:_DoShowDialogOption(options)
end







PhaseDialog._DoPlayDialogTrunk = HL.Method(CS.Beyond.Gameplay.DTTrunkNodeData, HL.Opt(HL.Boolean, HL.Any, HL.Any)) <<
    function
    (self, trunkNodeData, fastMode, npcId, npcGroupId)
        self.m_panelItem.uiCtrl:Show()
        self.m_panelItem.uiCtrl:SetTrunk(trunkNodeData, fastMode, npcId, npcGroupId)
        self.m_inited = true
    end




PhaseDialog._DoShowDialogOption = HL.Method(HL.Userdata) << function
(self, options)
    self.m_panelItem.uiCtrl:SetTrunkOption(options)
    self.m_inited = true
end




PhaseDialog._DoShowFullBg = HL.Method(CS.Beyond.Gameplay.DialogFullBgActionData) << function(self, actionData)
    self.m_panelItem.uiCtrl:SetFullBg(actionData)
    self.m_panelItem.uiCtrl:Show()
    self.m_inited = true
end




PhaseDialog._DoShowLeftSubtitle = HL.Method(CS.Beyond.Gameplay.DialogLeftSubtitleActionData) << function(self, actionData)
    self.m_panelItem.uiCtrl:Show()
    self.m_panelItem.uiCtrl:SetLeftSubtitle(actionData)
    self.m_inited = true
end



PhaseDialog._DoExitLeftSubtitle = HL.Method() << function(self)
    self.m_panelItem.uiCtrl:ExitLeftSubtitle()
end



PhaseDialog._AddRegisters = HL.Method() << function(self)
    local touchPanel = self.m_panelItem.uiCtrl:GetTouchPanel()
    if not touchPanel then
        return
    end

    if not self.m_onDrag then
        self.m_onDrag = function(eventData)
            self:_MoveCamera(eventData.delta)
        end
    end

    if not self.m_hasListened then
        touchPanel.onDrag:AddListener(self.m_onDrag)

        if BEYOND_DEBUG then
            if not self.m_onRightMouseButtonPress then
                self.m_onRightMouseButtonPress = function(delta)
                    self:_MoveCamera(delta)
                end
            end
            touchPanel.onRightMouseButtonPress:AddListener(self.m_onRightMouseButtonPress)
        end
    end

    self.m_hasListened = true
end



PhaseDialog._ClearRegisters = HL.Method() << function(self)
    if not self.m_panelItem then
        return
    end

    local touchPanel = self.m_panelItem.uiCtrl:GetTouchPanel()
    if not touchPanel or not self.m_onRightMouseButtonPress then
        return
    end

    if self.m_hasListened then
        touchPanel.onDrag:RemoveListener(self.m_onDrag)

        if BEYOND_DEBUG then
            touchPanel.onRightMouseButtonPress:RemoveListener(self.m_onRightMouseButtonPress)
        end
    end
    self.m_hasListened = false
end




PhaseDialog._MoveCamera = HL.Method(HL.Userdata) << function(self, delta)
    CameraManager:OnInput(UIUtils.getNormalizedScreenX(delta.x), UIUtils.getNormalizedScreenY(delta.y))
end









PhaseDialog._OnActivated = HL.Override() << function(self)
    PhaseDialog.ClearPhasesWithCam() 
    self:_TryShowTrunk()
    self:_TryShowOptions()
    self:_AddRegisters()
    self:_InitPhaseDialogController()
end




PhaseDialog._OnDeActivated = HL.Override() << function(self)
    self:_ClearRegisters()
    self:_ClearPhaseDialogController()

    
    self:RemovePhasePanelItemById(PanelId.DialogRecord)
end



PhaseDialog._TryShowTrunk = HL.Method() << function(self)
    local mainFlowHandle = GameWorld.dialogManager.mainFlowHandle
    if not self.m_inited and mainFlowHandle ~= nil and mainFlowHandle.trunkNodeData then
        self:_DoPlayDialogTrunk(mainFlowHandle.trunkNodeData, true, mainFlowHandle.npcId, mainFlowHandle.templateId)
    else
        self.m_panelItem.uiCtrl:RefreshTrunk()
    end

end



PhaseDialog._TryShowOptions = HL.Method() << function(self)
    local options = GameWorld.dialogManager.options
    if not self.m_inited and options.Count > 0 then
        self:_DoShowDialogOption(options)
    end
end




PhaseDialog._OnDestroy = HL.Override() << function(self)
    UIManager:ToggleBlockObtainWaysJump("IN_CINEMATIC", false)
    self.m_panelItem = nil
end




PhaseDialog.OpenUI = HL.Method(HL.Table) << function(self, arg)
    local panelIdStr, paramStr = unpack(arg)
    local panelId = PanelId[panelIdStr]
    local phaseId = PhaseId[panelIdStr]
    local param = not string.isEmpty(paramStr) and Utils.stringJsonToTable(paramStr) or {}
    param.fromDialog = true

    if not panelId or not phaseId then
        logger.error(("Dialog OpenUI Failed !! PanelId Not Found !! PanelIdStr is %s, Param is %s"):format(panelIdStr, paramStr))
        self:Next()
        return
    end

    self.m_panelItem.uiCtrl:PlayAnimationOutWithCallback(function()
        if Utils.isInclude(UIConst.DIALOG_OPEN_UI_USE_PANEL, panelId) then
            self:CreatePhasePanelItem(panelId, param)
        else
            if phaseId == PhaseId.ReadingPopUp then
                local closeCallback = function()
                    Notify(MessageConst.DIALOG_CLOSE_UI, { nil, nil, 0 })
                end
                param = {param.id, closeCallback}
            end

            local res = PhaseManager:OpenPhase(phaseId, param)
            if not res then
                logger.error("Dialog OpenUI fail!!!", panelIdStr)
                GameWorld.dialogManager:Next()
            end
        end
        
        GameWorld.dialogManager:TryRecoverVoiceManager()
    end)
end



PhaseDialog.CloseUI = HL.StaticMethod(HL.Table) << function(arg)
    local isOpen, phaseDialog = PhaseManager:IsOpen(PHASE_ID)

    
    local panelId, phaseId, nextIndex, notFastMode = unpack(arg)
    local panelItem = (phaseDialog and panelId) and phaseDialog:_GetPanelPhaseItem(panelId) or nil
    if panelItem and Utils.isInclude(UIConst.DIALOG_OPEN_UI_USE_PANEL, panelId) then
        phaseDialog:RemovePhasePanelItem(panelItem)
    elseif phaseId and PhaseManager:IsOpenAndValid(phaseId) then
        if PhaseManager.m_curState == Const.PhaseState.Push or PhaseManager.m_curState == Const.PhaseState.Pop then
            
            
            logger.critical("PhaseDialog.CloseUI出错，当前PhaseManager正在pop状态中！", PhaseManager:GetPhaseName(phaseId))
            return
        end
        if notFastMode then
            PhaseManager:PopPhase(phaseId)
        else
            PhaseManager:ExitPhaseFast(phaseId)
        end
    end

    if phaseDialog and phaseDialog.doingOut then
        return
    end

    if isOpen then
        
        GameWorld.dialogManager:TryPauseVoiceManager()

        phaseDialog.m_panelItem.uiCtrl:PlayAnimationIn()
        if nextIndex then
            phaseDialog:Next(nextIndex)
        end
    end
end




PhaseDialog.OnSendPresentEnd = HL.Method(HL.Table) << function(self, data)
    local success = data.success
    local deltaFav = data.deltaFav
    local selectedItems = data.selectedItems
    local nextIndex = data.nextIndex
    local levelChanged = data.levelChanged
    Notify(MessageConst.DIALOG_CLOSE_UI, {
        PanelId.FriendShipPresent,
        PhaseId.FriendShipPresent,
        nextIndex,
    })
    if success then
        self.m_panelItem.uiCtrl:ShowPresentSuccess(levelChanged, deltaFav, selectedItems)
    end
end





PhaseDialog.Next = HL.Method(HL.Opt(HL.Number)) << function(self, num)
    num = num or -1
    GameWorld.dialogManager:Next(num)
end





PhaseDialog.SetCtrlButtonVisible = HL.Method(HL.Boolean) << function(self, visible)
    local panelItem = self:_GetPanelPhaseItem(PanelId.Dialog)
    if panelItem then
        panelItem.uiCtrl:SetCtrlButtonVisible(visible)
    end
end




PhaseDialog._OpenDialogRecord = HL.Method() << function(self)
    local panelItem = self:_GetPanelPhaseItem(PanelId.DialogRecord)
    if not panelItem then
        panelItem = self:CreatePhasePanelItem(PanelId.DialogRecord)
    end
    panelItem.uiCtrl:Show()
    GameWorld.dialogManager:SetAutoMode(false)
end



PhaseDialog._HideDialogRecord = HL.Method() << function(self)
    local panelItem = self:_GetPanelPhaseItem(PanelId.DialogRecord)
    if panelItem then
        panelItem.uiCtrl:Hide()
    end
end





PhaseDialog._OpenDialogSkipPopUp = HL.Method() << function(self)
    local summaryId = GameWorld.dialogManager.summaryId
    GameWorld.dialogManager:SetAutoMode(false)
    if string.isEmpty(summaryId) then
        local dialogId = GameWorld.dialogManager.dialogId
        if not string.isEmpty(dialogId) then
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language.LUA_CONFIRM_SKIP_DIALOG,
                onConfirm = function()
                    GameWorld.dialogManager:SkipDialog(dialogId)
                end
            })
        end
    else
        local panelItem = self:_GetPanelPhaseItem(PanelId.DialogSkipPopUp)
        local firstCreate = false
        if not panelItem then
            panelItem = self:CreatePhasePanelItem(PanelId.DialogSkipPopUp)
            firstCreate = true
        end

        if not UIManager:IsOpen(PanelId.DialogSkipPopUp) then
            logger.error("DialogSkipPopUp Panel is not opened! FirstCreate: " .. tostring(firstCreate))
            return
        end

        panelItem.uiCtrl:Show()
        panelItem.uiCtrl:RefreshSummary(summaryId)
    end
end



PhaseDialog._HideDialogSkipPopUp = HL.Method() << function(self)
    local panelItem = self:_GetPanelPhaseItem(PanelId.DialogSkipPopUp)
    if panelItem then
        panelItem.uiCtrl:Hide()
    end
end



PhaseDialog._SkipDialog = HL.Method() << function(self)
    self:_HideDialogSkipPopUp()
    local dialogId = GameWorld.dialogManager.dialogId
    if not string.isEmpty(dialogId) then
        GameWorld.dialogManager:SkipDialog(dialogId)
    end
end





PhaseDialog.m_dialogControllerThread = HL.Field(HL.Thread)



PhaseDialog._InitPhaseDialogController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.m_dialogControllerThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdateControllerMoveCamera()
        end
    end)
end



PhaseDialog._ClearPhaseDialogController = HL.Method() << function(self)
    if self.m_dialogControllerThread ~= nil then
        self.m_dialogControllerThread = self:_ClearCoroutine(self.m_dialogControllerThread)
    end
end



PhaseDialog._UpdateControllerMoveCamera = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    if not self:_GetIsControllerDialogCameraValid() then
        return
    end

    local stickValue = InputManagerInst:GetGamepadStickValue(false)
    if InputManager.CheckGamepadStickInDeadZone(stickValue) then
        return
    end

    self:_MoveCamera(JsonConst.CONTROLLER_DIALOG_CAMERA_MOVE_SPEED[1] * stickValue)
end



PhaseDialog._GetIsControllerDialogCameraValid = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_panelItem.uiCtrl.view.inputGroup.groupEnabled
end



HL.Commit(PhaseDialog)
