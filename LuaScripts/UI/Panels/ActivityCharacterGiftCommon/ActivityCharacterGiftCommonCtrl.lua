local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

ActivityCharacterGiftCommonCtrl = HL.Class('ActivityCharacterGiftCommonCtrl', uiCtrl.UICtrl)






ActivityCharacterGiftCommonCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_TASK_PROGRESS_CHANGE] = 'OnActivityUpdate',
    [MessageConst.ON_SC_MULTI_STAGE_ACTIVITY_GAIN_TASK_REWARD] = 'OnActivityUpdate',
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdate',
}

ActivityCharacterGiftCommonCtrl.m_characterGiftPrefab = HL.Field(HL.Any)
ActivityCharacterGiftCommonCtrl.m_characterGiftWidget = HL.Field(HL.Any)

ActivityCharacterGiftCommonCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    args = args or {}
    local activityId = args.activityId or ""
    local phaseArg = self.m_phase and self.m_phase.arg
    if phaseArg and phaseArg.openShare and phaseArg.activityId == activityId then
        args.openShare = true
        phaseArg.openShare = nil
    end
    local _, configData = Tables.activityCharacterGiftConfigTable:TryGetValue(activityId)

    local prefabName = configData.commonPanelWidgetName

    local path = string.format(UIConst.UI_ACTIVITY_CHARACTER_GIFT_PREFAB_PATH, prefabName)
    local prefab = self:LoadGameObject(path)

    self.m_characterGiftPrefab = CSUtils.CreateObject(prefab, self.view.main)

    local widget = Utils.wrapLuaNode(self.m_characterGiftPrefab)

    self.m_characterGiftWidget = widget
    self.animationWrapper = self.m_characterGiftWidget.view.animationWrapper
    self.m_characterGiftWidget:Init(args)
end

ActivityCharacterGiftCommonCtrl.OnShow = HL.Override() << function(self)
    if self.m_characterGiftWidget then
        self.m_characterGiftWidget:OnShow()
    end
end

ActivityCharacterGiftCommonCtrl.OnClose = HL.Override() << function(self)
    if self.m_characterGiftWidget then
        self.m_characterGiftWidget:OnClose()
    end
end

ActivityCharacterGiftCommonCtrl.OnActivityUpdate = HL.Method(HL.Any) << function(self, arg)
    if self.m_characterGiftWidget then
        self.m_characterGiftWidget:OnActivityUpdate(arg)
    end
end

ActivityCharacterGiftCommonCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    if arg and arg.openShare and self.m_characterGiftWidget and arg.activityId == self.m_characterGiftWidget.m_activityId then
        arg.openShare = nil
        self.m_characterGiftWidget:_OpenShare()
    end
end

ActivityCharacterGiftCommonCtrl.OnActivityCenterNaviFailed = HL.Method() << function(self)
    if self.m_characterGiftWidget then
        self.m_characterGiftWidget:OnActivityCenterNaviFailed()
    end
end

HL.Commit(ActivityCharacterGiftCommonCtrl)
