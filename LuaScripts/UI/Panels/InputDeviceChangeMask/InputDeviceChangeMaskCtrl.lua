local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

InputDeviceChangeMaskCtrl = HL.Class('InputDeviceChangeMaskCtrl', uiCtrl.UICtrl)

InputDeviceChangeMaskCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE] = '_OnInputDeviceTypeChangeStart',
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnInputDeviceTypeChangeFinished',
}

InputDeviceChangeMaskCtrl.m_waitingPanelIds = HL.Field(HL.Table)

InputDeviceChangeMaskCtrl.m_waitCoroutine = HL.Field(HL.Thread)

InputDeviceChangeMaskCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self:SetSortingOrder(-32768, true)
end

InputDeviceChangeMaskCtrl._OnInputDeviceTypeChangeStart = HL.Method(HL.Any) << function(self, arg)
    
    if self.m_waitCoroutine then
        self.m_waitCoroutine = self:_ClearCoroutine(self.m_waitCoroutine)
    end
    self.m_waitingPanelIds = {}
    for panelId, ctrl in pairs(UIManager.m_openedPanels) do
        if panelId ~= self.panelId and ctrl:IsShow() then
            self.m_waitingPanelIds[panelId] = true
        end
    end
end

InputDeviceChangeMaskCtrl._OnInputDeviceTypeChangeFinished = HL.Method(HL.Any) << function(self, arg)
    
    self.m_waitCoroutine = self:_StartCoroutine(function()
        repeat
            coroutine.step()
            for panelId in pairs(self.m_waitingPanelIds) do
                local _, ctrl = UIManager:IsOpen(panelId)
                local wrapper = ctrl and ctrl.animationWrapper
                if not ctrl or not ctrl:IsShow() or IsNull(wrapper)
                        or (wrapper.curState ~= CS.Beyond.UI.UIConst.AnimationState.In
                            and wrapper.curState ~= CS.Beyond.UI.UIConst.AnimationState.InEasing) then
                    self.m_waitingPanelIds[panelId] = nil
                end
            end
        until next(self.m_waitingPanelIds) == nil
        self.m_waitCoroutine = nil
        self:Close()
    end)
end

HL.Commit(InputDeviceChangeMaskCtrl)
