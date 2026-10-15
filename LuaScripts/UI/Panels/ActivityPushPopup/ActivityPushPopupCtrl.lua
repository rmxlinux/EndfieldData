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
ActivityPushPopupCtrl.m_hasPlayedInAnimation = HL.Field(HL.Boolean) << false


ActivityPushPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs()
    self:_UpdateBgm()
end

ActivityPushPopupCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    local pushInfoList = {}
    for _, pushId in pairs(arg.pushIdList) do
      local _, pushCfg = Tables.activityPushPopupTable:TryGetValue(pushId)
      if pushCfg then
          table.insert(pushInfoList, {
              pushId = pushId,
              sortId = -pushCfg.sortId
          })
      end
    end
    table.sort(pushInfoList, Utils.genSortFunction({ "sortId", "pushId" }, true))

    self.m_pushIdList = {}
    for _, pushInfo in ipairs(pushInfoList) do
        table.insert(self.m_pushIdList, pushInfo.pushId)
    end
end

ActivityPushPopupCtrl._InitUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.activityScrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_OnUpdateActivityCell(go, csIndex)
    end)
    self.m_genCellCache = UIUtils.genCachedCellFunction(self.view.activityScrollList)
    self.view.leftSwitchBtn.onClick:AddListener(function()
        self:_OnClickSwitchBtn(-1)
    end)
    self.view.rightSwitchBtn.onClick:AddListener(function()
        self:_OnClickSwitchBtn(1)
    end)
    self.view.activityScrollList.onCenterIndexChanged:AddListener(function(_, _)
        self:_UpdateBgm()
        self:_RefreshSwitchBtns()
        self:_RefreshPagesFocusInput()
    end)
    self.m_hasPlayedInAnimation = false
    
    UIManager:ToggleBlockObtainWaysJump("ActivityPushPopup", true, {})
end

ActivityPushPopupCtrl._RefreshAllUIs = HL.Method() << function(self)
    self:_RefreshPageSpace()
    self.view.activityScrollList:UpdateCount(#self.m_pushIdList)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:_RefreshSwitchBtns()
end



ActivityPushPopupCtrl._RefreshPageSpace = HL.Method() << function(self)
    local scrollList = self.view.activityScrollList
    scrollList:TryRecalculateSize()
    local cellWidth = scrollList.cellWidth
    if cellWidth <= 0 then
        return
    end
    local extraWidth = math.max(0, self.view.rectTransform.rect.width - cellWidth)
    scrollList:SetSpace(Vector2(extraWidth, scrollList.space.y))
end

ActivityPushPopupCtrl._OnUpdateActivityCell = HL.Method(HL.Any, HL.Number) << function(self, go, csIndex)
    local cell = self.m_genCellCache(go, csIndex)
    local index = LuaIndex(csIndex)
    local pushId = self.m_pushIdList[index]
    cell:InitActivityPushPopupInfo({ pushId = pushId })
    InputManagerInst:ToggleGroup(cell.view.inputGroup.groupId, csIndex == self.view.activityScrollList.centerIndex)

    if self.m_hasPlayedInAnimation then
        self:_SkipPageInAnimation(go)
    else
        self.m_hasPlayedInAnimation = true
    end
end

ActivityPushPopupCtrl._RefreshPagesFocusInput = HL.Method() << function(self)
    if not self.m_pushIdList then
        return
    end
    local scrollList = self.view.activityScrollList
    for luaIndex = 1, #self.m_pushIdList do
        local cell = self.m_genCellCache(luaIndex)
        local csIndex = CSIndex(luaIndex)
        if cell then
            InputManagerInst:ToggleGroup(cell.view.inputGroup.groupId, csIndex == scrollList.centerIndex)
        end
    end
end



ActivityPushPopupCtrl._SkipPageInAnimation = HL.Method(HL.Any) << function(self, go)
    local animationWrapper = go:GetComponent(typeof(CS.Beyond.UI.UIAnimationWrapper))
    if animationWrapper then
        animationWrapper:SkipInAnimation()
    end
end

ActivityPushPopupCtrl._RefreshSwitchBtns = HL.Method() << function(self)
    local totalCount = self.m_pushIdList and #self.m_pushIdList or 0
    local hasMulti = totalCount > 1
    local luaIndex = hasMulti and LuaIndex(self.view.activityScrollList.centerIndex) or 0
    local canLeft = hasMulti and luaIndex > 1
    local canRight = hasMulti and luaIndex < totalCount
    self.view.switchBtnGroup.gameObject:SetActive(hasMulti)
    self.view.leftSwitchBtn.gameObject:SetActive(canLeft)
    self.view.rightSwitchBtn.gameObject:SetActive(canRight)
end

ActivityPushPopupCtrl._OnClickSwitchBtn = HL.Method(HL.Number) << function(self, offset)
    if self:IsPlayingAnimationOut() then
        return
    end
    local targetCsIndex = self.view.activityScrollList.centerIndex + offset
    if not self.m_pushIdList or targetCsIndex < 0 or targetCsIndex >= #self.m_pushIdList then
        return
    end
    self.view.activityScrollList:ScrollToIndex(targetCsIndex)
end

ActivityPushPopupCtrl._UpdateBgm = HL.Method() << function(self)
    local pushId = self.m_pushIdList[LuaIndex(self.view.activityScrollList.centerIndex)]
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

    
    self.m_centerIndexBeforeScreenSizeChanged = self.view.activityScrollList.centerIndex
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
    
    self:_RefreshPageSpace()
    
    self.view.activityScrollList:UpdateCount(#self.m_pushIdList)
    self.view.activityScrollList:ScrollToIndex(csIndex, true)
    self:_RefreshSwitchBtns()
end

ActivityPushPopupCtrl.OnClose = HL.Override() << function(self)
    if self.m_phase then
        self.m_phase:RemovePhasePanelItemById(PANEL_ID)
    end
    self.view.activityScrollList.onCenterIndexChanged:RemoveAllListeners()
    
    UIManager:ToggleBlockObtainWaysJump("ActivityPushPopup", false, {})
end

HL.Commit(ActivityPushPopupCtrl)
