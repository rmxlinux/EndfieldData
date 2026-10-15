local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityInn

ActivityInnCtrl = HL.Class('ActivityInnCtrl', uiCtrl.UICtrl)

ActivityInnCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


ActivityInnCtrl.m_activityId = HL.Field(HL.String) << ''

ActivityInnCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)

    
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot.gameObject:SetActive(false)

    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    
    local hasTaskJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.taskJumpId)
    if self.view.innTaskTips then
        if hasTaskJump then
            self.view.innTaskTips:InitActivityTaskEntry({activityId = self.m_activityId})
        else
            self.view.innTaskTips.gameObject:SetActive(false)
        end
    end
end

HL.Commit(ActivityInnCtrl)
