local autoCalcOrderUICtrl = require_ex('UI/Panels/Base/AutoCalcOrderUICtrl')
local PANEL_ID = PanelId.FacQuickBar
FacQuickBarCtrl = HL.Class('FacQuickBarCtrl', autoCalcOrderUICtrl.AutoCalcOrderUICtrl)






FacQuickBarCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.HIDE_FAC_QUICK_BAR] = 'HideFacQuickBar',

    [MessageConst.PLAY_FAC_QUICK_BAR_OUT_ANIM] = 'PlayOutAnim',
    [MessageConst.ON_BLOCK_KEYBOARD_EVENT_PANEL_ORDER_CHANGED] = 'PanelOrderChanged',

    [MessageConst.NAVI_TO_FAC_QUICK_BAR] = 'NaviToFacQuickBar',
    [MessageConst.FAC_TOGGLE_CAN_DEACTIVE_QUICK_BAR] = 'ToggleCanDeactiveQuickBar',
}

FacQuickBarCtrl.m_currentQuickBar = HL.Field(HL.Forward("FacQuickBarBase"))

FacQuickBarCtrl.m_useActiveAction = HL.Field(HL.Boolean) << false


FacQuickBarCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_attachedPanels = {}
    self.m_currentQuickBar = self.view.quickBarCustom
    self:_InitController()
end

FacQuickBarCtrl.OnShow = HL.Override() << function(self)
    FacQuickBarCtrl.Super.OnShow(self)
end

FacQuickBarCtrl.OnHide = HL.Override() << function(self)
    FacQuickBarCtrl.Super.OnHide(self)
    
    self.m_currentQuickBar:CancelDragging()
    self.m_currentQuickBar:Deactivate()
end

FacQuickBarCtrl.OnClose = HL.Override() << function(self)
    FacQuickBarCtrl.Super.OnClose(self)
end

FacQuickBarCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, isActive)
end

FacQuickBarCtrl._RefreshContent = HL.Method() << function(self)
    local quickBarArgs = {
        showBelt = self.m_arg.showBelt,
        showPipe = self.m_arg.showPipe,
        showBuildBtn = self.m_arg.showBuildBtn,

        naviGroup = self.view.main,
        inputBindingGroup = self.view.mainInputBindingGroup,

        useActiveAction = self.m_useActiveAction,
        controllerSwitchArgs = self.m_arg.controllerSwitchArgs,

        onIsTopLayerChanged = function(isTopLayer)
            self:_OnIsTopLayerChanged(isTopLayer)
        end,
    } 
    self.m_currentQuickBar:InitFacQuickBar(quickBarArgs)
    self.m_currentQuickBar:RefreshFacQuickBar()
end




FacQuickBarCtrl.m_arg = HL.Field(HL.Table)

FacQuickBarCtrl.ShowFacQuickBar = HL.StaticMethod(HL.Table) << function(arg)
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.FacMode) then
        return
    end
    local self = FacQuickBarCtrl.AutoOpen(PANEL_ID, nil, true)

    
    
    if DeviceInfo.usingController and self.m_lastAttachPanelId > 0 and self.m_lastAttachPanelId ~= arg.panelId then
        self.m_currentQuickBar:Deactivate()
        
        if self.view.main then
            self.view.main:ManuallyStopFocus()
        end
    end
    self.m_lastAttachPanelId = arg.panelId

    self.m_arg = arg
    self.m_useActiveAction = arg.useActiveAction == true
    self:_AttachToPanel(arg)
    self:_RefreshContent()
    self:_RefreshControllerSettingOnShow()
end

FacQuickBarCtrl.HideFacQuickBar = HL.Method(HL.Number) << function(self, panelId)
    self:_CustomHide(panelId)
end

FacQuickBarCtrl.CustomSetPanelOrder = HL.Override(HL.Opt(HL.Number, HL.Table)) << function(self, maxOrder, args)
    self.m_curArgs = args
    self:SetSortingOrder(maxOrder, false)
    self:UpdateInputGroupState()
end





FacQuickBarCtrl.m_manualFocusBindingId = HL.Field(HL.Number) << -1

FacQuickBarCtrl.m_manualUnFocusBindingId = HL.Field(HL.Number) << -1

FacQuickBarCtrl.m_zoomCamGroupId = HL.Field(HL.Number) << 0

FacQuickBarCtrl.m_lastAttachPanelId = HL.Field(HL.Number) << -1

FacQuickBarCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.view.main.focusPanelSortingOrder = UIManager:GetBaseOrder(Types.EPanelOrderTypes.PopUp) - 1

    self.m_manualFocusBindingId = self:BindInputPlayerAction("fac_activate_quick_bar", function()
        self.m_currentQuickBar:Activate()
    end, self.view.mainInputBindingGroup.groupId)
    self.m_manualUnFocusBindingId = self:BindInputPlayerAction("fac_deactivate_quick_bar", function()
        self.m_currentQuickBar:Deactivate()
    end, self.view.mainInputBindingGroup.groupId)

    self.m_zoomCamGroupId = InputManagerInst:CreateGroup(self.view.mainInputBindingGroup.groupId)
    UIUtils.bindControllerCamZoom(self.m_zoomCamGroupId)
    InputManagerInst:ToggleGroup(self.m_zoomCamGroupId, false)
end

FacQuickBarCtrl._OnIsTopLayerChanged = HL.Method(HL.Boolean) << function(self, isTopLayer)
    InputManagerInst:ToggleGroup(self.m_zoomCamGroupId, isTopLayer and self.m_useActiveAction)
    if not self.m_useActiveAction then
        return
    end

    if isTopLayer then
        
        
        local keyCode = InputManagerInst:GetActionGamepadKeyCode("fac_activate_quick_bar", false, true);
        if not InputManagerInst:GetKey(keyCode) then
            self:_StartTimer(0, function()
                self.m_currentQuickBar:Deactivate()
            end)
            return
        end
    end

    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { "FacQuickBar", isTopLayer })
    local isOpen, jsPanelCtrl = UIManager:IsOpen(PanelId.Joystick)
    if isOpen then
        
        local jsGroupId = jsPanelCtrl.view.joystick.groupId
        if isTopLayer then
            InputManagerInst:ChangeParent(true, jsGroupId, self.view.mainInputBindingGroup.groupId)
        else
            InputManagerInst:ChangeParent(true, jsGroupId, jsPanelCtrl.view.inputGroup.groupId)
        end
    end
end

FacQuickBarCtrl._RefreshControllerSettingOnShow = HL.Method() << function(self)
    if DeviceInfo.usingTouch then
        return
    end
    local useActiveAction = DeviceInfo.usingController and self.m_useActiveAction
    InputManagerInst:ToggleBinding(self.m_manualFocusBindingId, useActiveAction)
    InputManagerInst:ToggleBinding(self.m_manualUnFocusBindingId, useActiveAction)
end

FacQuickBarCtrl.ToggleCanDeactiveQuickBar = HL.Method(HL.Table) << function(self, args)
    local canDeactive = unpack(args)
    if not self.m_useActiveAction then
        return
    end
    InputManagerInst:ToggleBinding(self.m_manualUnFocusBindingId, canDeactive)
    if canDeactive then
        self.m_currentQuickBar:Deactivate()
    end
end

FacQuickBarCtrl.NaviToFacQuickBar = HL.Method() << function(self)
    if not self:IsShow() then
        return
    end
    self.m_currentQuickBar:Activate()
end




HL.Commit(FacQuickBarCtrl)
