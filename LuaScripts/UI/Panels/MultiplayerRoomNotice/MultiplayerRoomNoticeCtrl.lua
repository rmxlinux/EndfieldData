local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerRoomNotice

MultiplayerRoomNoticeCtrl = HL.Class('MultiplayerRoomNoticeCtrl', uiCtrl.UICtrl)







MultiplayerRoomNoticeCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


MultiplayerRoomNoticeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
end











HL.Commit(MultiplayerRoomNoticeCtrl)
