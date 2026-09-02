local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityCommonTask
local PHASE_ID = PhaseId.ActivityCommonTask
ActivityCommonTaskCtrl = HL.Class('ActivityCommonTaskCtrl', uiCtrl.UICtrl)






ActivityCommonTaskCtrl.s_messages = HL.StaticField(HL.Table) << {

}

ActivityCommonTaskCtrl.m_activityId = HL.Field(HL.String) << ""
ActivityCommonTaskCtrl.m_taskPrefab = HL.Field(HL.Any)
ActivityCommonTaskCtrl.m_taskWidget = HL.Field(HL.Any)







ActivityCommonTaskCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId

    local path = string.format(UIConst.UI_ACTIVITY_TASK_PREFAB_PATH, arg.widgetPath)
    local prefab = self:LoadGameObject(path)
    if self.m_taskPrefab then
        CSUtils.ClearUIComponents(self.m_taskPrefab)
        GameObject.DestroyImmediate(self.m_taskPrefab)
    end
    self.m_taskPrefab = CSUtils.CreateObject(prefab, self.view.main)
    self.m_taskWidget = Utils.wrapLuaNode(self.m_taskPrefab)

    self.animationWrapper = self.m_taskWidget.view.animationWrapper
    self.m_taskWidget:InitActivityCommonTaskInfo({
        activityId = self.m_activityId,
        forcedRewardCellCount = arg.forcedRewardCellCount or -1,
    })
    self.m_taskWidget.view.btnBack.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
end

HL.Commit(ActivityCommonTaskCtrl)
