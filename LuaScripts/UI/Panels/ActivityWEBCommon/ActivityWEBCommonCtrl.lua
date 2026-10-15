local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityWEBCommon

ActivityWEBCommonCtrl = HL.Class('ActivityWEBCommonCtrl', uiCtrl.UICtrl)

ActivityWEBCommonCtrl.s_messages = HL.StaticField(HL.Table) << {
}

ActivityWEBCommonCtrl.m_webPrefab = HL.Field(HL.Any)

ActivityWEBCommonCtrl.m_webWidget = HL.Field(HL.Any)

ActivityWEBCommonCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    local success, webInfo = Tables.activityWebTable:TryGetValue(args.activityId)
    if not success then
        logger.error("[ActivityWEBCommon] Web活动表缺少活动配置", args.activityId)
        return
    end

    local prefabName = webInfo.commonPanelWidgetName
    if prefabName == nil or prefabName == "" then
        logger.error("[ActivityWEBCommon] commonPanelWidgetName 未配置", args.activityId)
        return
    end

    local path = string.format(UIConst.UI_ACTIVITY_WEB_PREFAB_PATH, prefabName)
    local prefab = self:LoadGameObject(path)
    if not prefab then
        logger.error("[ActivityWEBCommon] 加载活动 Prefab 失败", args.activityId, path)
        return
    end

    if self.m_webPrefab then
        CSUtils.ClearUIComponents(self.m_webPrefab)
        GameObject.DestroyImmediate(self.m_webPrefab)
    end
    self.m_webPrefab = CSUtils.CreateObject(prefab, self.view.main)
    self.m_webWidget = Utils.wrapLuaNode(self.m_webPrefab)
    if not self.m_webWidget then
        logger.error("[ActivityWEBCommon] Prefab 根节点缺少 LuaUIWidget", args.activityId, path)
        return
    end

    self.m_webWidget:Init(args)
end

ActivityWEBCommonCtrl.PlayAnimationOut = HL.Override(HL.Opt(HL.Number)) << function(self, outCompleteActionType)
    outCompleteActionType = outCompleteActionType or UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Close
    local animationWrapper = self.m_webPrefab:GetComponent(typeof(CS.Beyond.UI.UIAnimationWrapper))
    animationWrapper:PlayOutAnimation(function()
        if outCompleteActionType == UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Close then
            self:Close()
        elseif outCompleteActionType == UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Hide then
            self:Hide()
        end
    end)
end

HL.Commit(ActivityWEBCommonCtrl)
