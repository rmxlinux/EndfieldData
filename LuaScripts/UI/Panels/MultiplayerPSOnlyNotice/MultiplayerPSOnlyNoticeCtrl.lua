local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerPSOnlyNotice

MultiplayerPSOnlyNoticeCtrl = HL.Class('MultiplayerPSOnlyNoticeCtrl', uiCtrl.UICtrl)







MultiplayerPSOnlyNoticeCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

MultiplayerPSOnlyNoticeCtrl.m_showDuration = HL.Field(HL.Number) << 0
MultiplayerPSOnlyNoticeCtrl.m_finishTime = HL.Field(HL.Number) << -1


MultiplayerPSOnlyNoticeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_showDuration = arg and arg.duration or self.view.config.SHOW_DURATION
    self.m_finishTime = -1
    self.view.slider.value = 1
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
end

MultiplayerPSOnlyNoticeCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if self.m_finishTime >= 0 then
        return
    end
    self.m_finishTime = DateTimeUtils.GetCurrentTimestampByMilliseconds() / 1000 + self.m_showDuration
    self:_StartCoroutine(function()
        while true do
            
            local remaining = self.m_finishTime - DateTimeUtils.GetCurrentTimestampByMilliseconds() / 1000
            if remaining <= 0 then
                self.view.slider.value = 0
                if self:IsShow() then
                    self:PlayAnimationOutAndClose()
                else
                    self:Close()
                end
                return
            end
            self.view.slider.value = remaining / self.m_showDuration
            coroutine.step()
        end
    end)
end

HL.Commit(MultiplayerPSOnlyNoticeCtrl)
