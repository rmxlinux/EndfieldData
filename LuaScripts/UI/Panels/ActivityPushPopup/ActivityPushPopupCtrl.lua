local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityPushPopup

ActivityPushPopupCtrl = HL.Class('ActivityPushPopupCtrl', uiCtrl.UICtrl)






ActivityPushPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SYSTEM_DISPLAY_SIZE_CHANGED] = '_OnSystemDisplaySizeChanged',
    [MessageConst.ON_SYSTEM_SCREEN_SIZE_CHANGED] = '_OnSystemScreenSizeChanged',
    [MessageConst.ON_UI_CANVAS_SIZE_CHANGED] = '_OnCanvasSizeChanged',
}

ActivityPushPopupCtrl.m_pushIdList = HL.Field(HL.Table)
ActivityPushPopupCtrl.m_genCellCache = HL.Field(HL.Function)
ActivityPushPopupCtrl.m_centerIndexBeforeScreenSizeChanged = HL.Field(HL.Number) << -1


ActivityPushPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs()
    self:_UpdateBgm()
end

ActivityPushPopupCtrl._InitData = HL.Method(HL.Any) << function(self,arg)
    self.m_pushIdList = arg.pushIdList
end

ActivityPushPopupCtrl._InitUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
         self:PlayAnimationOutAndClose()
    end)
    self.view.activityScrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_OnUpdateActivityCell(go, csIndex)
    end)
    self.m_genCellCache = UIUtils.genCachedCellFunction(self.view.activityScrollList)
    
    UIManager:ToggleBlockObtainWaysJump("ActivityPushPopup", true, {})
end

ActivityPushPopupCtrl._RefreshAllUIs = HL.Method() << function(self)
     self.view.activityScrollList:UpdateCount(#self.m_pushIdList)
     self.view.activityScrollList.onScrollEnd:RemoveAllListeners()
     self.view.activityScrollList.onScrollEnd:AddListener(function()
         self:_UpdateBgm()
     end)
     self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

ActivityPushPopupCtrl._OnUpdateActivityCell = HL.Method(HL.Any, HL.Number) << function(self, go, csIndex)
    local cell = self.m_genCellCache(go, csIndex)
    local index = LuaIndex(csIndex)
    local pushId = self.m_pushIdList[index]
    cell:InitActivityPushPopupInfo({pushId = pushId})
end

ActivityPushPopupCtrl._UpdateBgm = HL.Method() << function(self)
    local csIndex = math.floor(self.view.activityScrollList:GetCenterIndex())
    local index = LuaIndex(csIndex)
    local pushId = self.m_pushIdList[index]
    local _, pushCfg = Tables.activityPushPopupTable:TryGetValue(pushId)
    AudioManager.PostEvent(pushCfg.bgm)
end

ActivityPushPopupCtrl._TryCaptureCenterIndex = HL.Method() << function(self)
    if not self.m_pushIdList or #self.m_pushIdList <= 0 then
        return
    end
    if self.m_centerIndexBeforeScreenSizeChanged >= 0 then
        return
    end

    
    local csIndex = math.floor(self.view.activityScrollList:GetCenterIndex())
    self.m_centerIndexBeforeScreenSizeChanged = math.min(math.max(csIndex, 0), #self.m_pushIdList - 1)
end

ActivityPushPopupCtrl._OnSystemDisplaySizeChanged = HL.Method() << function(self)
    self:_TryCaptureCenterIndex()
end

ActivityPushPopupCtrl._OnSystemScreenSizeChanged = HL.Method(HL.Opt(HL.Any, HL.Any)) << function(self, _, _)
    self:_TryCaptureCenterIndex()
end

ActivityPushPopupCtrl._OnCanvasSizeChanged = HL.Method() << function(self)
    if not self.m_pushIdList or #self.m_pushIdList <= 0 or self.m_centerIndexBeforeScreenSizeChanged < 0 then
        return
    end

    local csIndex = self.m_centerIndexBeforeScreenSizeChanged
    self.m_centerIndexBeforeScreenSizeChanged = -1
    
    self.view.activityScrollList:TryRecalculateSize()
    self.view.activityScrollList:ScrollToIndex(csIndex, true)
end

ActivityPushPopupCtrl.OnClose = HL.Override() << function(self)
    if self.m_phase then
        self.m_phase:RemovePhasePanelItemById(PANEL_ID)
    end
    self.view.activityScrollList.onScrollEnd:RemoveAllListeners()
    
    UIManager:ToggleBlockObtainWaysJump("ActivityPushPopup", false, {})
end

HL.Commit(ActivityPushPopupCtrl)
