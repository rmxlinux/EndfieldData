local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityWEBMergeGame

ActivityWEBMergeGameCtrl = HL.Class('ActivityWEBMergeGameCtrl', uiCtrl.UICtrl)

ActivityWEBMergeGameCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CLOSE_WEB_APPLICATION] = '_OnWebClosed',
}

ActivityWEBMergeGameCtrl.m_activityId = HL.Field(HL.String) << ''

ActivityWEBMergeGameCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    local redDotName = ActivityUtils.getActivityRedDotName(self.m_activityId) or "ActivityWEB"
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot(redDotName, args.activityId)

    ActivityUtils.queryActivityWebPortalState(self.m_activityId)

    self.view.activityCommonInfo.view.gotoNode.btnDetail.onClick:AddListener(function()
        ActivityUtils.setWebActivityFirstVisitRead(self.m_activityId)
    end)
end

ActivityWEBMergeGameCtrl._OnWebClosed = HL.Method(HL.Any) << function(self, _)
    ActivityUtils.queryActivityWebPortalState(self.m_activityId)
end


HL.Commit(ActivityWEBMergeGameCtrl)
