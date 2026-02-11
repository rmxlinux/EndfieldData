
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')







ActivityVersionGuideCtrl = HL.Class('ActivityVersionGuideCtrl', uiCtrl.UICtrl)


ActivityVersionGuideCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


ActivityVersionGuideCtrl.m_activityId = HL.Field(HL.String) << ''


ActivityVersionGuideCtrl.m_prefabNode = HL.Field(HL.Any)


ActivityVersionGuideCtrl.m_versionGuide = HL.Field(HL.Any)




ActivityVersionGuideCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    local suc,info = Tables.activityVersionGuideTable:TryGetValue(args.activityId)
    if suc then
        local path = string.format(UIConst.UI_ACTIVITY_VERSION_GUIDE_PREFAB_PATH, info.prefabName)
        local prefab = self:LoadGameObject(path)
        if self.m_prefabNode then
            CSUtils.ClearUIComponents(self.m_prefabNode)
            GameObject.DestroyImmediate(self.m_prefabNode)
        end
        self.m_prefabNode = CSUtils.CreateObject(prefab, self.view.main)
        self.m_versionGuide = Utils.wrapLuaNode(self.m_prefabNode)
        self.m_versionGuide:InitVersionGuide(args)
    end
end



ActivityVersionGuideCtrl.OnActivityCenterNaviFailed = HL.Method() << function(self)
    self.m_versionGuide:OnActivityCenterNaviFailed()
end


HL.Commit(ActivityVersionGuideCtrl)
