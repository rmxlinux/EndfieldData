
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivitySkiplevel1

ActivitySkiplevel1Ctrl = HL.Class('ActivitySkiplevel1Ctrl', uiCtrl.UICtrl)

ActivitySkiplevel1Ctrl.s_messages = HL.StaticField(HL.Table) << {
    
}

ActivitySkiplevel1Ctrl.m_activityId = HL.Field(HL.String) << ''

ActivitySkiplevel1Ctrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
end


HL.Commit(ActivitySkiplevel1Ctrl)
