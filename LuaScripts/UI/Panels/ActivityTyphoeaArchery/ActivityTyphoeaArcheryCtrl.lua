
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityTyphoeaArchery

ActivityTyphoeaArcheryCtrl = HL.Class('ActivityTyphoeaArcheryCtrl', uiCtrl.UICtrl)

ActivityTyphoeaArcheryCtrl.s_messages = HL.StaticField(HL.Table) << {

}

ActivityTyphoeaArcheryCtrl.m_activityId = HL.Field(HL.String) << ''
ActivityTyphoeaArcheryCtrl.m_hasLimitedReward = HL.Field(HL.Boolean) << false

ActivityTyphoeaArcheryCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    
    local hasTaskJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.taskJumpId)
    if self.view.activityTaskEntry then
        if hasTaskJump then
            self.view.activityTaskEntry:InitActivityTaskEntry({activityId = self.m_activityId})
        else
            self.view.activityTaskEntry.gameObject:SetActive(false)
        end
    end

    
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if activityData.status == GEnums.ActivityStatus.InProgress then
        self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot("ActivityTyphoeaArcheryDetail", self.m_activityId)
    elseif activityData.status == GEnums.ActivityStatus.Completed then
        self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:Stop()
    end
end

HL.Commit(ActivityTyphoeaArcheryCtrl)
