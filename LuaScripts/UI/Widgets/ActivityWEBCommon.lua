local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityWEBCommon = HL.Class('ActivityWEBCommon', UIWidgetBase)

ActivityWEBCommon.m_activityId = HL.Field(HL.String) << ''

ActivityWEBCommon.Init = HL.Method(HL.Table) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)

    local redDotName = ActivityUtils.getActivityRedDotName(self.m_activityId) or "ActivityWEB"
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot(redDotName, self.m_activityId)

    ActivityUtils.queryActivityWebPortalState(self.m_activityId)
    self.view.activityCommonInfo.view.gotoNode.btnDetail.onClick:AddListener(function()
        ActivityUtils.setWebActivityFirstVisitRead(self.m_activityId)
    end)

    self:RegisterMessage(MessageConst.ON_CLOSE_WEB_APPLICATION, function(_)
        ActivityUtils.queryActivityWebPortalState(self.m_activityId)
    end)
end

HL.Commit(ActivityWEBCommon)
return ActivityWEBCommon
