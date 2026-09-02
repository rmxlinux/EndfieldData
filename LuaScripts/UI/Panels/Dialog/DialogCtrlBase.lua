local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local KeyboardKeyCode = CS.Beyond.Input.KeyboardKeyCode
local GamepadKeyCode = CS.Beyond.Input.GamepadKeyCode
local HudFadeType = CS.Beyond.HudFadeType

local UI_HIDDEN_TYPE = {
    Active = "active",
    Alpha = "alpha",
}








local UI_HIDDEN_KEYBOARD_MODIFIER_INPUTS = {
    KeyboardKeyCode.LeftControl,
    KeyboardKeyCode.RightControl,
    KeyboardKeyCode.LeftShift,
    KeyboardKeyCode.RightShift,
    KeyboardKeyCode.LeftAlt,
    KeyboardKeyCode.RightAlt,
    KeyboardKeyCode.LeftMeta,
    KeyboardKeyCode.RightMeta,
}

local UI_HIDDEN_KEYBOARD_INPUT_BLACK_LIST = {
    KeyboardKeyCode.Mouse0, 
    KeyboardKeyCode.Space,
    KeyboardKeyCode.F1,
    KeyboardKeyCode.F2,
    KeyboardKeyCode.F3,
    KeyboardKeyCode.F4,
    KeyboardKeyCode.F5,
    KeyboardKeyCode.F6,
    KeyboardKeyCode.F7,
    KeyboardKeyCode.F8,
    KeyboardKeyCode.F9,
    KeyboardKeyCode.F10,
    KeyboardKeyCode.F11,
    KeyboardKeyCode.F12,
    KeyboardKeyCode.F13,
    KeyboardKeyCode.F14,
    KeyboardKeyCode.F15
}


local UI_HIDDEN_OPTION_KEYBOARD_INPUTS = {
    KeyboardKeyCode.Alpha1,
    KeyboardKeyCode.Alpha2,
    KeyboardKeyCode.Alpha3,
    KeyboardKeyCode.Alpha4,
    KeyboardKeyCode.Alpha5,
    KeyboardKeyCode.Alpha6,
    KeyboardKeyCode.Alpha7,
    KeyboardKeyCode.Alpha8,
    KeyboardKeyCode.Alpha9,
}

local UI_HIDDEN_GAMEPAD_INPUTS = {
    GamepadKeyCode.LeftStickBtn,
    GamepadKeyCode.RightStickBtn,
    GamepadKeyCode.ArrowUp,
    GamepadKeyCode.ArrowDown,
    GamepadKeyCode.ArrowLeft,
    GamepadKeyCode.ArrowRight,
    
    GamepadKeyCode.B,
    GamepadKeyCode.X,
    GamepadKeyCode.Y,
    GamepadKeyCode.LB,
    GamepadKeyCode.LT,
    GamepadKeyCode.RB,
    GamepadKeyCode.RT,
    GamepadKeyCode.LeftMenuBtn,
    GamepadKeyCode.RightMenuBtn,
    GamepadKeyCode.Home,
    GamepadKeyCode.TouchPanel,
    GamepadKeyCode.LeftStickUp,
    GamepadKeyCode.LeftStickDown,
    GamepadKeyCode.LeftStickLeft,
    GamepadKeyCode.LeftStickRight,
    GamepadKeyCode.RightStickUp,
    GamepadKeyCode.RightStickDown,
    GamepadKeyCode.RightStickLeft,
    GamepadKeyCode.RightStickRight,
}

local UI_HIDDEN_OPTION_GAMEPAD_INPUT_BLACK_LIST = {
    [GamepadKeyCode.ArrowUp] = true,
    [GamepadKeyCode.ArrowDown] = true,
    [GamepadKeyCode.LeftStickUp] = true,
    [GamepadKeyCode.LeftStickDown] = true,
    [GamepadKeyCode.A] = true,
}

DialogCtrlBase = HL.Class('DialogCtrlBase', uiCtrl.UICtrl)

DialogCtrlBase.m_optionCells = HL.Field(HL.Forward("UIListCache"))

DialogCtrlBase.m_optionCount = HL.Field(HL.Number) << 0

DialogCtrlBase.m_curEntryLinks = HL.Field(HL.Userdata) << nil

DialogCtrlBase.m_enableGlossaryPopUp = HL.Field(HL.Boolean) << true

DialogCtrlBase.m_isUIHidden = HL.Field(HL.Boolean) << false

DialogCtrlBase.m_showOptionWhenUIHidden = HL.Field(HL.Boolean) << false

DialogCtrlBase.m_autoAndHideButtonsVisible = HL.Field(HL.Boolean) << false

DialogCtrlBase.m_uiHiddenStates = HL.Field(HL.Table)

DialogCtrlBase.m_uiHiddenWhiteList = HL.Field(HL.Table)

DialogCtrlBase.m_uiHiddenInputUpdateKey = HL.Field(HL.Number) << -1

DialogCtrlBase.m_skipNextUIHiddenInputInterrupt = HL.Field(HL.Boolean) << false

DialogCtrlBase.m_mouseLeftPressBindingId = HL.Field(HL.Number) << -1

DialogCtrlBase.m_mouseLeftReleaseBindingId = HL.Field(HL.Number) << -1

DialogCtrlBase.m_mouseLeftPressedWhileCursorHidden = HL.Field(HL.Boolean) << false




DialogCtrlBase.s_messages = HL.StaticField(HL.Table) << {}


DialogCtrlBase.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_isUIHidden = self:_GetCurrentUIHidden()
    self.m_showOptionWhenUIHidden = false
    self.m_autoAndHideButtonsVisible = false
    self.m_uiHiddenStates = {}
    self.m_uiHiddenWhiteList = {}
    self:_InitUIHiddenWhiteList()
    self.m_skipNextUIHiddenInputInterrupt = false
    self.m_mouseLeftPressedWhileCursorHidden = false
    self.m_mouseLeftPressBindingId = self:BindInputPlayerAction("dialog_on_mouse_left_press", function()
        self:_OnMouseLeftPress()
    end)
    self.m_mouseLeftReleaseBindingId = self:BindInputPlayerAction("dialog_on_mouse_left_release", function()
        self:_OnMouseLeftRelease()
    end)
    self:_RefreshMouseLeftBindings()
    self.m_uiHiddenInputUpdateKey = self:_StartUpdate(function()
        self:_OnUpdateUIHiddenInput()
    end, "TailTick")
    self.m_optionCells = UIUtils.genCellCache(self.view.panelOptionCell)

    
    self.view.buttonBack.onClick:RemoveAllListeners()
    self.view.buttonBack.onClick:AddListener(function()
        self:OnBtnBackClick()

    end)

    
    self.view.buttonNext.onClick:RemoveAllListeners()
    self.view.buttonNext.onClick:AddListener(function()
        self:OnBtnNextClick()
    end)

    
    self.view.buttonSkip.onClick:RemoveAllListeners()
    self.view.buttonSkip.onClick:AddListener(function()
        self:OnBtnSkipClick()
    end)

    
    self.view.buttonAuto.onClick:RemoveAllListeners()
    self.view.buttonAuto.onClick:AddListener(function()
        self:OnBtnAutoClick()
    end)

    
    self.view.buttonHide.onClick:RemoveAllListeners()
    self.view.buttonHide.onClick:AddListener(function()
        self:OnBtnHideClick()
    end)

    
    self.view.buttonLog.onClick:RemoveAllListeners()
    self.view.buttonLog.onClick:AddListener(function()
        self:OnBtnLogClick()
    end)

    
    self.view.buttonStop.onClick:RemoveAllListeners()
    self.view.buttonStop.onClick:AddListener(function()
        self:OnBtnStopClick()
    end)

    self.view.textTalk.uiText.onClickLink:RemoveAllListeners()
    self.view.textTalk.uiText.onClickLink:AddListener(function(linkId)
        self:OnLinkClick(linkId)
    end)

    
    self:_InitDialogController()
    self:OnCreated(arg)
end

DialogCtrlBase.OnCreated = HL.Virtual(HL.Any) << function(self, arg)
end



DialogCtrlBase._RefreshMouseLeftBindings = HL.Method(HL.Opt(HL.Boolean)) << function(self, cursorVisible)
    if cursorVisible == nil then
        cursorVisible = InputManager.cursorVisible
    end
    local cursorHidden = not cursorVisible
    if self.m_mouseLeftPressBindingId > 0 then
        InputManagerInst:ToggleBinding(self.m_mouseLeftPressBindingId,
            cursorHidden and not self.m_mouseLeftPressedWhileCursorHidden)
    end
    if self.m_mouseLeftReleaseBindingId > 0 then
        InputManagerInst:ToggleBinding(self.m_mouseLeftReleaseBindingId,
            cursorHidden or self.m_mouseLeftPressedWhileCursorHidden)
    end
end

DialogCtrlBase._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        self.m_mouseLeftPressedWhileCursorHidden = false
    end
    self:_RefreshMouseLeftBindings()
end

DialogCtrlBase._UpdateMouseLeftPressState = HL.Method() << function(self)
    if not self.m_mouseLeftPressedWhileCursorHidden or InputManagerInst:GetKey(KeyboardKeyCode.Mouse0) then
        return
    end
    self.m_mouseLeftPressedWhileCursorHidden = false
    self:_RefreshMouseLeftBindings()
end

DialogCtrlBase._OnMouseLeftPress = HL.Method() << function(self)
    if InputManager.cursorVisible then
        self:_RefreshMouseLeftBindings(true)
        return
    end
    self.m_mouseLeftPressedWhileCursorHidden = true
    self:_RefreshMouseLeftBindings(false)
end

DialogCtrlBase._OnMouseLeftRelease = HL.Method() << function(self)
    local shouldNext = self.m_mouseLeftPressedWhileCursorHidden
    self.m_mouseLeftPressedWhileCursorHidden = false
    self:_RefreshMouseLeftBindings()
    if shouldNext then
        self:OnBtnNextClick()
    end
end

DialogCtrlBase._OnToggleHudFade = HL.Method(HL.Table) << function(self, args)
    if args[1] ~= HudFadeType.Cursor then
        return
    end
    self:_RefreshMouseLeftBindings(args[2])
end





DialogCtrlBase._InitDialogController = HL.Method() << function(self)
    self:_SwitchControllerAutoPlayHint()
    self:_RefreshGlossaryNoteKeyHint()
    self:BindInputPlayerAction("dialog_open_note", function()
        if self:TryInterruptUIHidden() then
            return
        end
        self:_OpenGlossaryPopUp()
    end)
end

DialogCtrlBase._EnableDialogControllerOption = HL.Method() << function(self)
    if not DeviceInfo.usingController or self.m_optionCount <= 0 then
        return
    end

    local optionCount = self.m_optionCells:GetCount()
    if optionCount == 0 then
        return
    end

    self.view.optionNaviGroup:ManuallyFocus()
end

DialogCtrlBase._DisableDialogControllerOption = HL.Method() << function(self)
    
    if not DeviceInfo.usingController then
        return
    end

    self.view.optionNaviGroup:ManuallyStopFocus()
end

DialogCtrlBase._IsOptionShownWhenUIHidden = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isUIHidden and self:_ShouldShowOptionList()
end

DialogCtrlBase._IsKeyboardOptionShortcutInput = HL.Method().Return(HL.Boolean) << function(self)
    
    local count = math.min(self.m_optionCount, #UI_HIDDEN_OPTION_KEYBOARD_INPUTS)
    for i = 1, count do
        if InputManagerInst:GetKeyDown(UI_HIDDEN_OPTION_KEYBOARD_INPUTS[i]) then
            return true
        end
    end
    return false
end

DialogCtrlBase._IsMouseDownOnOptionList = HL.Method().Return(HL.Boolean) << function(self)
    if not InputManagerInst:GetKeyDown(KeyboardKeyCode.Mouse0) then
        return false
    end
    return UIUtils.isScreenPosInRectTransform(InputManager.mousePosition, self.view.optionList.transform, self.uiCamera)
end

DialogCtrlBase._IsUIHiddenInputInBlackList = HL.Method().Return(HL.Boolean) << function(self)
    if not self:_IsOptionShownWhenUIHidden() then
        return false
    end
    return self:_IsKeyboardOptionShortcutInput() or self:_IsMouseDownOnOptionList()
end

DialogCtrlBase._HasGamepadUIHiddenInterruptInputDown = HL.Method().Return(HL.Boolean) << function(self)
    local hasInterruptInput = false
    local optionShownWhenUIHidden = self:_IsOptionShownWhenUIHidden()
    for _, keyCode in ipairs(UI_HIDDEN_GAMEPAD_INPUTS) do
        if InputManagerInst:GetKeyDown(keyCode) then
            if not (optionShownWhenUIHidden and UI_HIDDEN_OPTION_GAMEPAD_INPUT_BLACK_LIST[keyCode]) then
                hasInterruptInput = true
            end
        end
    end
    return hasInterruptInput
end

DialogCtrlBase.hasUIHiddenKeyboardModifierInput = HL.Method().Return(HL.Boolean) << function(self)
    for _, keyCode in ipairs(UI_HIDDEN_KEYBOARD_MODIFIER_INPUTS) do
        if InputManagerInst:GetKey(keyCode) then
            return true
        end
    end
    return false
end

DialogCtrlBase.hasUIHiddenKeyboardBlackListInputDown = HL.Method().Return(HL.Boolean) << function(self)
    for _, keyCode in ipairs(UI_HIDDEN_KEYBOARD_INPUT_BLACK_LIST) do
        if InputManagerInst:GetKeyDown(keyCode) then
            return true
        end
    end
    return false
end

DialogCtrlBase._HasUIHiddenInterruptInputDown = HL.Method().Return(HL.Boolean) << function(self)
    if DeviceInfo.usingController then
        return self:_HasGamepadUIHiddenInterruptInputDown()
    end
    if self:hasUIHiddenKeyboardModifierInput() or self:hasUIHiddenKeyboardBlackListInputDown() then
        return false
    end
    if not InputManager.anyKeyDown then
        return false
    end
    return not self:_IsUIHiddenInputInBlackList()
end

DialogCtrlBase._MarkOptionSelectedWhenUIHidden = HL.Method() << function(self)
    if self.m_isUIHidden then
        self.m_skipNextUIHiddenInputInterrupt = true
    end
end

DialogCtrlBase._OnUpdateUIHiddenInput = HL.Method() << function(self)
    self:_UpdateMouseLeftPressState()
    if self.m_skipNextUIHiddenInputInterrupt then
        self.m_skipNextUIHiddenInputInterrupt = false
        return
    end
    if not self.m_isUIHidden or self:IsHide() then
        return
    end
    if not self:_HasUIHiddenInterruptInputDown() then
        return
    end
    self:SetUIHidden(false)
end

DialogCtrlBase._InitUIHiddenWhiteList = HL.Virtual() << function(self)
end

DialogCtrlBase._ResolveViewTarget = HL.Method(HL.String).Return(HL.Any) << function(self, path)
    local cur = self.view
    for seg in string.gmatch(path, "[^%.]+") do
        cur = cur[seg]
    end
    return cur
end

DialogCtrlBase._BuildUIHiddenWhiteList = HL.Method(HL.Table) << function(self, config)
    for _, path in ipairs(config.active or {}) do
        local target = self:_ResolveViewTarget(path)
        if target ~= nil then
            self.m_uiHiddenWhiteList[target] = { type = UI_HIDDEN_TYPE.Active }
        end
    end
    for _, entry in ipairs(config.alpha or {}) do
        local path = type(entry) == "string" and entry or entry[1]
        local useUpdateAlpha = type(entry) == "table" and entry.useUpdateAlpha == true
        local target = self:_ResolveViewTarget(path)
        if target ~= nil then
            self.m_uiHiddenWhiteList[target] = { type = UI_HIDDEN_TYPE.Alpha, useUpdateAlpha = useUpdateAlpha }
        end
    end
end

DialogCtrlBase._GetUIHiddenConfig = HL.Method(HL.Userdata, HL.String).Return(HL.Any) << function(self, target, expectedType)
    local data = self.m_uiHiddenWhiteList[target]
    if data == nil then
        logger.warn(ELogChannel.UI, "[Dialog] Hide Target没有注册", target)
        return nil
    end
    if data.type ~= expectedType then
        logger.warn(ELogChannel.UI, "[Dialog] Hide Target类型不匹配", target, data.type, expectedType)
        return nil
    end
    return data
end


DialogCtrlBase._SetUIHiddenActiveState = HL.Method(HL.Userdata, HL.Boolean) << function(self, target, active)
    local data = self:_GetUIHiddenConfig(target, UI_HIDDEN_TYPE.Active)
    if data == nil then
        return
    end
    
    self.m_uiHiddenStates[target] = active
    target.gameObject:SetActive(active and not self.m_isUIHidden)
end
DialogCtrlBase._SetUIHiddenAlphaState = HL.Method(HL.Userdata, HL.Number) << function(self, target, alpha)
    local data = self:_GetUIHiddenConfig(target, UI_HIDDEN_TYPE.Alpha)
    if data == nil then
        return
    end
    local useUpdateAlpha = data.useUpdateAlpha == true
    self.m_uiHiddenStates[target] = alpha
    local realAlpha = self.m_isUIHidden and 0 or alpha
    if useUpdateAlpha then
        target:UpdateAlpha(realAlpha)
    else
        target.alpha = realAlpha
        target.interactable = not self.m_isUIHidden
        target.blocksRaycasts = not self.m_isUIHidden
    end
end

DialogCtrlBase._ShouldShowOptionList = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_optionCount > 0 and (not self.m_isUIHidden or self.m_showOptionWhenUIHidden)
end

DialogCtrlBase._RefreshOptionListVisibleState = HL.Method() << function(self)
    if self.m_optionCount <= 0 then
        if self.m_isUIHidden then
            self.view.optionList.gameObject:SetActive(false)
        end
        self:_DisableDialogControllerOption()
        return
    end

    local visible = self:_ShouldShowOptionList()
    self.view.optionList.gameObject:SetActive(visible)
    if visible then
        self:_EnableDialogControllerOption()
    else
        self:_DisableDialogControllerOption()
    end
end

DialogCtrlBase._RefreshUIHiddenState = HL.Virtual() << function(self)
    
    for target, data in pairs(self.m_uiHiddenWhiteList) do
        if data.type == UI_HIDDEN_TYPE.Active then
            local active = self.m_uiHiddenStates[target]
            if active == nil then
                active = target.gameObject.activeSelf
                self.m_uiHiddenStates[target] = active
            end
            target.gameObject:SetActive(active and not self.m_isUIHidden)
        elseif data.type == UI_HIDDEN_TYPE.Alpha then
            local alpha = self.m_uiHiddenStates[target]
            if alpha == nil then
                local useUpdateAlpha = data.useUpdateAlpha == true
                alpha = useUpdateAlpha and 1 or target.alpha
                self.m_uiHiddenStates[target] = alpha
            end
            self:_SetUIHiddenAlphaState(target, alpha)
        else
            logger.warn(ELogChannel.UI, "[Dialog] Hide Target类型非法", target, data.type)
        end
    end
    self:_RefreshOptionListVisibleState()
end


DialogCtrlBase._OnUIHiddenChanged = HL.Virtual(HL.Boolean) << function(self, hidden)
end
DialogCtrlBase._GetCurrentUIHidden = HL.Virtual().Return(HL.Boolean) << function(self)
    return GameWorld.dialogManager.uiHidden
end
DialogCtrlBase._SetCurrentUIHidden = HL.Virtual(HL.Boolean) << function(self, hidden)
    GameWorld.dialogManager:SetUIHidden(hidden)
end

DialogCtrlBase._ApplyUIHiddenState = HL.Method(HL.Boolean) << function(self, hidden)
    if hidden == self.m_isUIHidden then
        return
    end
    self.m_isUIHidden = hidden
    if hidden then
        self.m_showOptionWhenUIHidden = false
        self.m_skipNextUIHiddenInputInterrupt = true
    else
       AudioAdapter.PostEvent("Au_UI_Button_Show") 
    end
    self:_RefreshUIHiddenState()
    self:_OnUIHiddenChanged(hidden)
end

DialogCtrlBase.SetUIHidden = HL.Method(HL.Boolean) << function(self, hidden)
    if hidden ~= self:_GetCurrentUIHidden() then
        self:_SetCurrentUIHidden(hidden)
    end
    self:_ApplyUIHiddenState(hidden)
end

DialogCtrlBase.TryInterruptUIHidden = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_isUIHidden then
        return false
    end
    
    if self:hasUIHiddenKeyboardModifierInput() then
        return true
    end
    self:SetUIHidden(false)
    return true
end

DialogCtrlBase._SetAutoAndHideButtonsVisible = HL.Method(HL.Boolean) << function(self, visible)
    self.m_autoAndHideButtonsVisible = visible
    self:_SetUIHiddenActiveState(self.view.buttonAuto, visible)
    self:_SetUIHiddenActiveState(self.view.buttonHide, visible)
    if visible then
        self:_RefreshAutoMode(self:_GetCurrentAutoMode())
    else
        self:_SetUIHiddenActiveState(self.view.textAuto, false)
    end
end

DialogCtrlBase.SetTrunkOption = HL.Virtual(HL.Userdata) << function(self, optionData)
    if self:IsHide() then
        self:Show()
        self.view.textTalkCenterNode.gameObject:SetActive(false)
        self.view.radioNode.gameObject:SetActive(false)
        self.view.bottomLayout.gameObject:SetActive(false)
    end

    local count = optionData.Count
    self.m_optionCount = count
    if count == 0 then
        self:_DisableDialogControllerOption()
        self.m_optionCells:PlayAllOut()
        self.m_showOptionWhenUIHidden = false
    else
        if self.m_isUIHidden then
            self.m_showOptionWhenUIHidden = true
        end
        self.view.optionList.gameObject:SetActive(self:_ShouldShowOptionList())
        self.m_optionCells:ClearAllTween(false)
        self.m_optionCells:Refresh(count, function(cell, luaIndex)
            local option = optionData[CSIndex(luaIndex)]
            local data = {
                optionId = option.optionId,
                index = luaIndex,
                text = option.optionText or "",
                iconType = option.iconType,
                icon = option.optionIcon,
                color = option.useExOptionColor and  option.optionIconColor or nil,
                setGreyed = option.setGreyed,
            }
            cell:InitDialogOptionCell(data, function()
                self:_MarkOptionSelectedWhenUIHidden()
                self:OnOptionClick(luaIndex, option)
            end)
            cell.view.animationWrapper:PlayInAnimation()
        end)

        self:_RefreshOptionListVisibleState()
    end

    self:_RefreshCanSkip()
    local showWait = count <= 0
    self:_TrySetWaitNode(showWait)
    self:_RefreshUIHiddenState()
end

DialogCtrlBase._RefreshCanSkip = HL.Virtual() << function(self)
end

DialogCtrlBase.OnDialogTextStopped = HL.Virtual() << function(self)
end

DialogCtrlBase.OnOptionClick = HL.Virtual(HL.Number, HL.Any) << function(self, index, data)
end


DialogCtrlBase._TrySetWaitNode = HL.Virtual(HL.Boolean) << function(self, active)
end

DialogCtrlBase._SwitchControllerAutoPlayHint = HL.Method() << function(self)
    local onAutoPlay = self:_GetCurrentAutoMode()
    
    if onAutoPlay then
        InputManagerInst:SetBindingText(self.view.buttonAuto.onClick.bindingId, Language["ui_nar_dialogue_auto"])
    else
        InputManagerInst:SetBindingText(self.view.buttonAuto.onClick.bindingId, Language["key_hint_dialog_auto_play"])
    end

    self:_SetUIHiddenActiveState(self.view.controllerHint.skipHint, not onAutoPlay)
    self:_SetUIHiddenActiveState(self.view.controllerHint.skipHintLoop, onAutoPlay)
end

DialogCtrlBase._RefreshGlossaryNoteKeyHint = HL.Method() << function(self)
    local enable = true

    if self.m_phase == nil or self.m_curEntryLinks == nil or self.m_curEntryLinks.Count == 0 then
        enable = false
    end

    if not self.m_enableGlossaryPopUp then
        enable = false
    end

    self:_SetUIHiddenActiveState(self.view.noteKeyHintNode, enable)
end

DialogCtrlBase._GetCurrentAutoMode = HL.Virtual().Return(HL.Boolean) << function(self)
    return GameWorld.dialogManager.autoMode
end




DialogCtrlBase.OnBtnBackClick = HL.Virtual() << function(self)
end

DialogCtrlBase.OnBtnNextClick = HL.Virtual() << function(self)
end

DialogCtrlBase.OnBtnSkipClick = HL.Virtual() << function(self)
end

DialogCtrlBase.OnBtnAutoClick = HL.Virtual() << function(self)
end

DialogCtrlBase.OnBtnHideClick = HL.Virtual() << function(self)
end

DialogCtrlBase.OnBtnLogClick = HL.Virtual() << function(self)
    self:Notify(MessageConst.OPEN_DIALOG_RECORD)
end

DialogCtrlBase.OnBtnStopClick = HL.Virtual() << function(self)
end




DialogCtrlBase.OnLinkClick = HL.Virtual(HL.String) << function(self, linkId)
    if UIUtils.resolveLinkTypeFromId(linkId) ~= UIConst.UI_TEXT_LINK_TYPE.Narrative then
        return
    end
    self:_OpenGlossaryPopUp()
end

DialogCtrlBase._OpenGlossaryPopUp = HL.Method() << function(self)
    if self.m_phase == nil or self.m_curEntryLinks == nil or self.m_curEntryLinks.Count == 0 then
        return
    end

    if not self.m_enableGlossaryPopUp then
        return
    end

    AudioAdapter.PostEvent("Au_UI_Button_Common")
    self.m_phase:CreatePhasePanelItem(PanelId.DialogGlossaryPopUp, { self.m_curEntryLinks })
end

DialogCtrlBase.SetCurEntryLinks = HL.Method(HL.Userdata) << function(self, links)
    self.m_curEntryLinks = links
    self:_RefreshGlossaryNoteKeyHint()
end

DialogCtrlBase.SetGlossaryPopUpEnable = HL.Method(HL.Boolean) << function(self, isEnable)
    self.m_enableGlossaryPopUp = isEnable
    self:_RefreshGlossaryNoteKeyHint()
end




DialogCtrlBase._RefreshAutoMode = HL.Virtual(HL.Boolean) << function(self, autoMode)
    self:_SetUIHiddenActiveState(self.view.textAuto, self.m_autoAndHideButtonsVisible and autoMode)
    self:_SwitchControllerAutoPlayHint()
end

DialogCtrlBase.OnRefreshAutoMode = HL.Method(HL.Table) << function (self, arg)
    self:_RefreshAutoMode(unpack(arg))
end

DialogCtrlBase.OnRefreshUIHidden = HL.Method(HL.Table) << function(self, arg)
    self:_ApplyUIHiddenState(unpack(arg))
end


DialogCtrlBase.ShowDevWaterMark = HL.Method() << function(self)
    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        self.view.devWaterMarkGroup.gameObject:SetActive(true)
        self.view.devWaterMark_1.text = Language.LUA_DIALOG_DEV_WATER_MARK
        self.view.devWaterMark_2.text = Language.LUA_DIALOG_DEV_WATER_MARK
    end
end

DialogCtrlBase.GetCurDialogId = HL.Virtual().Return(HL.String) << function(self)
    return ""
end

DialogCtrlBase.GetCurDialogTrunkId = HL.Virtual().Return(HL.String) << function(self)
    return ""
end

DialogCtrlBase.GetDebugDescDialogId = HL.Virtual().Return(HL.String) << function(self)
    return self:GetCurDialogId()
end

DialogCtrlBase._GetDialogSpecPriorityDesc = HL.Method(HL.String).Return(HL.String) << function(self, dialogId)
    local descItems = {}
    if UNITY_EDITOR then
        local success, specPriority = Tables.dialogQualityTable:TryGetValue(dialogId)
        if success and specPriority ~= nil and specPriority ~= "" then
            table.insert(descItems, "预期：" .. specPriority)
        end
    end

    if GameWorld.dialogManager.dialogTree then
        local qualityLevel = "Default"
        if GameWorld.dialogManager.dialogTree.dialogTreeData.qualityLevel == CS.Beyond.Gameplay.DialogEnums.DialogQualityLevel.High then
            qualityLevel = "High"
        end
        table.insert(descItems, "质量：" .. qualityLevel)
    end

    if #descItems > 0 then
        return "\n" .. table.concat(descItems, " ")
    end
    return ""
end

DialogCtrlBase._GetDialogDebugText = HL.Method().Return(HL.String) << function(self)
    local dialogId = self:GetCurDialogId()
    local trunkId = self:GetCurDialogTrunkId() or ""
    local desc = self:_GetDialogSpecPriorityDesc(self:GetDebugDescDialogId())
    return dialogId .. "\nTrunkId: " .. trunkId .. desc
end

DialogCtrlBase.CheckTextPlaying = HL.Method().Return(HL.Boolean) << function(self)
    if self.view.textTalk.gameObject.activeInHierarchy and self.view.textTalk.playing then
        return true
    end

    return false
end

DialogCtrlBase.RefreshDebugNode = HL.Virtual() << function(self)
    self.view.debugNode.gameObject:SetActive(false)
    if NarrativeUtils.ShouldShowNarrativeDebugNode() then
        self.view.debugNode.gameObject:SetActive(true)
        self.view.textDialogId.text = self:_GetDialogDebugText()
    end
end

DialogCtrlBase.OnShow = HL.Override() << function(self)
    self:OnDialogShow()
    self:RefreshDebugNode()
end

DialogCtrlBase.OnDialogShow = HL.Virtual() << function(self)
    if self.m_optionCount > 0 then
         self:_EnableDialogControllerOption()
    end
end




DialogCtrlBase.OnClose = HL.Override() << function(self)
    self.m_isUIHidden = false
    self.m_showOptionWhenUIHidden = false
    self.m_autoAndHideButtonsVisible = false
    self.m_uiHiddenStates = {}
    self.m_uiHiddenWhiteList = {}
    self.m_skipNextUIHiddenInputInterrupt = false
    self.m_mouseLeftPressedWhileCursorHidden = false
    self.m_uiHiddenInputUpdateKey = self:_RemoveUpdate(self.m_uiHiddenInputUpdateKey)

    self.view.bgSprite:DOKill()
    self.view.bgBlack:DOKill()
    self.view.bottomLayout:DOKill()
    self.view.textTalkCenterNode:DOKill()

    self.view.buttonBack.onClick:RemoveAllListeners()
    self.view.buttonNext.onClick:RemoveAllListeners()
    self.view.buttonSkip.onClick:RemoveAllListeners()
    self.view.buttonAuto.onClick:RemoveAllListeners()
    self.view.buttonHide.onClick:RemoveAllListeners()
end




HL.Commit(DialogCtrlBase)
