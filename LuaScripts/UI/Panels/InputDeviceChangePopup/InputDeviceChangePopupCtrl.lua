local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InputDeviceChangePopup









InputDeviceChangePopupCtrl = HL.Class('InputDeviceChangePopupCtrl', uiCtrl.UICtrl)







InputDeviceChangePopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.START_GUIDE_GROUP] = 'OnStartGuideGroup',
}



InputDeviceChangePopupCtrl.m_args = HL.Field(HL.Any)


InputDeviceChangePopupCtrl.m_hasExecuted = HL.Field(HL.Boolean) << false






InputDeviceChangePopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_args = args

    self.view.controllerContentText.gameObject:SetActive(args.inputType == DeviceInfo.InputType.Controller)
    self.view.keyboardContentText.gameObject:SetActive(args.inputType == DeviceInfo.InputType.Keyboard)
    self.view.touchContentText.gameObject:SetActive(args.inputType == DeviceInfo.InputType.Touch)

    
    
    
    InputManagerInst:ToggleInputDeviceChangeMode(true)
    InputManagerInst:ToggleForceShowRealCursor(true)

    self.view.confirmButton.onClick:AddListener(function()
        if self:IsPlayingAnimationIn() then
            return
        end
        InputManagerInst:ToggleForceShowRealCursor(false)
        self.m_hasExecuted = true
        args.onConfirm()
    end)

    self.view.cancelButton.onClick:AddListener(function()
        if self:IsPlayingAnimationIn() or self:IsPlayingAnimationOut() then
            return
        end
        InputManagerInst:ToggleForceShowRealCursor(false)
        self.m_hasExecuted = true
        args.onCancel()
        self:PlayAnimationOutAndClose()
    end)

    InputManagerInst:MoveMouseTo(self.view.rectTransform, self.uiCamera)

    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        self.view.debugHintText.gameObject:SetActive(true)
    end
end



InputDeviceChangePopupCtrl.OnShowInputDeviceChangePopup = HL.StaticMethod(HL.Table) << function(args)
    UIManager:Open(PANEL_ID, args)
end



InputDeviceChangePopupCtrl.OnClose = HL.Override() << function(self)
    if not self.m_hasExecuted then
        
        InputManagerInst:ToggleForceShowRealCursor(false)
        self.m_args.onCancel()
    end
end




InputDeviceChangePopupCtrl.OnStartGuideGroup = HL.Method(HL.Any) << function(self, arg)
    local guideGroup = arg[1]
    if guideGroup.type == CS.Beyond.Gameplay.GuideGroupType.Force then
        
        self:Close()
    end
end


HL.Commit(InputDeviceChangePopupCtrl)
