local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Dialog2D






PhaseDialog2D = HL.Class('PhaseDialog2D', phaseBase.PhaseBase)







PhaseDialog2D.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_OPEN_DIALOG_UI] = { "OnOpenDialogUI", false },
    [MessageConst.IS_DIALOG_PHASE_OPENED] = { "IsDialogPhaseOpened", false },

    [MessageConst.DIALOG_OPEN_UI] = { "OpenUI", true },
    [MessageConst.ON_EXIT_DIALOG] = { "OnExitDialog", true },
    [MessageConst.DIALOG_CHANGE_NEXT_INDEX] = { "ChangeNextIndex", true },

    
    [MessageConst.OPEN_DIALOG_SKIP_POP_UP] = { "_OpenDialogSkipPopUp", true },
    [MessageConst.HIDE_DIALOG_SKIP_POP_UP] = { "_HideDialogSkipPopUp", true },
    [MessageConst.SKIP_DIALOG] = { "_SkipDialog", true },
}

PhaseDialog2D.m_panelItem = HL.Field(HL.Forward("PhasePanelItem"))

PhaseDialog2D.s_nextIndexConfig = HL.StaticField(HL.Table)

PhaseDialog2D.m_tempNextIndex = HL.Field(HL.Number) << -1

PhaseDialog2D.m_openedPhaseId = HL.Field(HL.Number) << -1

PhaseDialog2D._InitNextIndex = HL.StaticMethod() << function()
    PhaseDialog2D.s_nextIndexConfig = {}
    for phaseName, nextIndex in pairs(DialogConst.DIALOG_PHASE_2_NEXT_INDEX) do
        PhaseDialog2D.s_nextIndexConfig[PhaseId[phaseName]] = nextIndex
    end
end

PhaseDialog2D._InitAllPhaseItems = HL.Override() << function(self)
    PhaseDialog2D.Super._InitAllPhaseItems(self)
    self.m_panelItem = self:_GetPanelPhaseItem(PanelId.Dialog2D)
end

PhaseDialog2D.GetOpenedPhaseId = HL.Method().Return(HL.Number) << function(self)
    return self.m_openedPhaseId
end

PhaseDialog2D.ChangeNextIndex = HL.Method(HL.Table) << function(self, args)
    if args.phaseId == self.m_openedPhaseId then
        self.m_tempNextIndex = args.nextIndex
    end
end

PhaseDialog2D.GetNextIndex = HL.StaticMethod(HL.Number).Return(HL.Number) << function(phaseId)
    local suc, phase = PhaseManager:IsOpen(PHASE_ID)
    if not suc then
        return 0
    end
    if phase.m_tempNextIndex >= 0 then
        return phase.m_tempNextIndex
    end
    if not PhaseDialog2D.s_nextIndexConfig then
        PhaseDialog2D._InitNextIndex()
    end
    return PhaseDialog2D.s_nextIndexConfig[phaseId] or 0
end






PhaseDialog2D.OnOpenDialogUI = HL.StaticMethod(HL.Table) << function(arg)
    local is2DUI = unpack(arg)
    if not is2DUI then
        return
    end

    local inWaitingQueue = PhaseManager:IsInWaitingQueue(PHASE_ID)
    if inWaitingQueue then
        return
    end

    
    
    
    
    
    local isOpen, _ = PhaseManager:IsOpen(PHASE_ID)
    if not isOpen then
        PhaseManager:OpenPhaseFast(PHASE_ID)
    end
end






PhaseDialog2D.IsDialogPhaseOpened = HL.StaticMethod(HL.Table) << function(arg)
    local isOpenedContext = unpack(arg)
    local isOpen, phase = PhaseManager:IsOpenAndValid(PHASE_ID)
    if isOpen then
        isOpenedContext.isPhaseOpen = true
        return
    end
    
    
    
    if PhaseManager:IsInWaitingQueue(PHASE_ID) or PhaseManager:IsOpen(PHASE_ID) then
        isOpenedContext.isPhasePending = true
    end
end

PhaseDialog2D.OpenUI = HL.Method(HL.Table) << function(self, arg)
    local panelIdStr, paramStr, actionData = unpack(arg)
    local phaseId = PhaseId[panelIdStr]
    local param = not string.isEmpty(paramStr) and Utils.stringJsonToTable(paramStr) or {}
    param.fromDialog = true
    param.actionData = actionData
    if param.blockWhitePhaseName ~= nil then
        local exceptIds = {}
        for _, whitePhaseName in pairs(param.blockWhitePhaseName) do
            table.insert(exceptIds, whitePhaseName)
        end
        UIManager:ToggleBlockObtainWaysJump("IN_CINEMATIC", true, exceptIds)
    end

    if not phaseId then
        logger.error(("Dialog2D OpenUI Failed !! PhaseId Not Found !! PanelIdStr is %s, Param is %s"):format(panelIdStr, paramStr))
        self:Next()
        return
    end

    self.m_panelItem.uiCtrl:PlayAnimationOutWithCallback(function()
        if phaseId == PhaseId.ReadingPopUp then
            
            
            local closeCallback = function() end
            param = {param.id, closeCallback}
        end

        local res = PhaseManager:OpenPhase(phaseId, param)
        if res then
            self.m_openedPhaseId = phaseId
        else
            logger.error("Dialog2D OpenUI fail!!!", panelIdStr)
            GameWorld.dialogManager:Next()
        end
        GameWorld.dialogManager:TryRecoverVoiceManager()
    end)
end

PhaseDialog2D.OnExitDialog = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    self:CloseSelf()
end

PhaseDialog2D._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:OnDialogPhaseTransitionBackToTop()
end

PhaseDialog2D.OnDialogPhaseTransitionBackToTop = HL.Method() << function(self)
    if self.m_openedPhaseId == -1 then
        return
    end

    local nextIndex = PhaseDialog2D.GetNextIndex(self.m_openedPhaseId)
    self:ChangeNextIndex({
        phaseId = self.m_openedPhaseId,
        nextIndex = -1,
    })

    self.m_openedPhaseId = -1

    GameWorld.dialogManager:TryPauseVoiceManager()

    self.m_panelItem.uiCtrl:PlayAnimationIn()
    if nextIndex then
        self:Next(nextIndex)
    end
end

PhaseDialog2D.Next = HL.Method(HL.Opt(HL.Number)) << function(self, num)
    num = num or -1
    GameWorld.dialogManager:Next(num)
end





PhaseDialog2D._OpenDialogSkipPopUp = HL.Method() << function(self)
    local summaryId = GameWorld.dialogManager.summaryId
    if string.isEmpty(summaryId) then
        local dialogId = GameWorld.dialogManager.dialogId
        if not string.isEmpty(dialogId) then
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language.LUA_CONFIRM_SKIP_DIALOG,
                onConfirm = function()
                    GameWorld.dialogManager:SkipDialog(dialogId)
                end,
                onCancel = function() end,
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

PhaseDialog2D._HideDialogSkipPopUp = HL.Method() << function(self)
    local panelItem = self:_GetPanelPhaseItem(PanelId.DialogSkipPopUp)
    if panelItem then
        panelItem.uiCtrl:Hide()
    end
end

PhaseDialog2D._SkipDialog = HL.Method() << function(self)
    self:_HideDialogSkipPopUp()
    local dialogId = GameWorld.dialogManager.dialogId
    if not string.isEmpty(dialogId) then
        GameWorld.dialogManager:SkipDialog(dialogId)
    end
end


HL.Commit(PhaseDialog2D)
