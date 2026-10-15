local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacTopHud

local CONTENT_TYPE = {
    Power = 'power',
}

FacTopHudCtrl = HL.Class('FacTopHudCtrl', uiCtrl.UICtrl)

FacTopHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_EXIT_FACTORY_MODE] = 'OnExitFactoryMode',
    [MessageConst.ON_EXIT_BUILDING_MODE] = 'OnExitBuildingMode',
    [MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE] = 'OnInFacMainRegionChange',
    [MessageConst.ON_FAC_BUILDING_PREVIEW_POSITION_ROTATION_CHANGED] = 'OnFacBuildingPreviewPositionRotationChanged',
    [MessageConst.ON_FAC_CHAPTER_RESET] = 'OnFacChapterReset',
    [MessageConst.ON_BUILD_MODE_CHANGE] = 'OnBuildModeChange',
}

FacTopHudCtrl.m_facHudPanelConfig = HL.Field(HL.Table)
FacTopHudCtrl.m_currentContent = HL.Field(HL.Userdata)
FacTopHudCtrl.m_currentContentType = HL.Field(HL.String) << ""
FacTopHudCtrl.m_baseMode = HL.Field(HL.String) << ""
FacTopHudCtrl.m_switchMode = HL.Field(HL.String) << ""
FacTopHudCtrl.m_ignoreModeSwitchPopUp = HL.Field(HL.Boolean) << false
FacTopHudCtrl.m_curBuildBuildingItemId = HL.Field(HL.String) << ''
FacTopHudCtrl.m_allowHudContentShow = HL.Field(HL.Boolean) << false

FacTopHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_UpdateFacHudConfig()

    self.m_allowHudContentShow = false
    self.view.defaultNode.animationWrapper:SampleToOutAnimationEnd()

    local node = self.view.defaultNode
    node.multimodeToggle:InitCommonToggle(function(isOn)
        self:_OnMultimodeToggleChanged(isOn)
    end, false, true)
    node.multimodeToggle.toggle.checkIsValueValid = function(isOn)
        return self:_CheckIsMultimodeToggleValueValid(isOn)
    end
    node.multimodeToggle:SetCustomAnimation("common_toggle_to_left05", "common_toggle_to_right05")
    self:_HideMultimodeToggle()

    UIManager:SetTopOrder(PanelId.MainHud)
end

FacTopHudCtrl._UpdateFacHudConfig = HL.Method() << function(self)
    self.m_facHudPanelConfig = LuaSystemManager.factoryHud:GetFacHudPanelConfig(PANEL_ID)
end

FacTopHudCtrl._SyncContentVisibility = HL.Method() << function(self)
    local content = self.m_currentContent
    if not content or not content.gameObject then
        return
    end
    local visible = self.m_allowHudContentShow and (Utils.isInFactoryMode() or self:IsShow())
    content:SyncVisibilityForContent(visible, self.m_curBuildBuildingItemId)
end

FacTopHudCtrl._TryLoadContent = HL.Method(HL.String) << function(self, contentType)
    local config = self.m_facHudPanelConfig[contentType]
    if not config then
        logger.warning(ELogChannel.UI, 'Content type not found: ' .. tostring(contentType))
        return
    end
    if config.loadCondition and not config.loadCondition() then
        self:_SuspendFactoryContent()
        return
    end

    local defaultNode = self.view.defaultNode
    if self.m_currentContentType == contentType and self.m_currentContent then return end
    self:_UnloadContent()
    self.m_currentContentType = contentType
    self:LoadGameObjectAsync(config.prefabPath, function(prefab)
        if not prefab then
            self.m_currentContentType = ''
            return
        end
        
        if self.m_isClosed or self.m_currentContentType ~= contentType then return end
        local parent = defaultNode.animationWrapper.gameObject.transform
        if self.m_currentContent then return end    
        local go = CSUtils.CreateObject(prefab, parent)
        local slot = defaultNode.contentContainer
        if slot then
            local slotTransform = slot.transform or slot
            go.transform:SetSiblingIndex(slotTransform:GetSiblingIndex() + 1)
        end
        self.m_currentContent = UIWidgetManager:Wrap(go)
        go.name = config.luaClass
        go.transform.anchoredPosition, go.transform.sizeDelta = Vector2.zero, Vector2.zero
        if not self.m_currentContent then
            GameObject.Destroy(go)
            self.m_currentContentType = ''
            return
        end
        self.m_currentContent:InitLoadedForContent()
        self:_SyncContentVisibility()
    end)
end

FacTopHudCtrl._UnloadContent = HL.Method() << function(self)
    local content = self.m_currentContent
    if content then
        content:ToggleCoroutine(false)
        if NotNull(content.gameObject) then
            GameObject.Destroy(content.gameObject)
        end
        self.m_currentContent = nil
    end
    self.m_currentContentType = ''
    local slot = self.view.defaultNode.contentContainer
    if slot then
        slot.gameObject:SetActive(true)
    end
end

FacTopHudCtrl._SuspendFactoryContent = HL.Method() << function(self)
    self.m_curBuildBuildingItemId = ''
    self.m_ignoreModeSwitchPopUp = false
    self.m_allowHudContentShow = false
    self:_HideMultimodeToggle()
    self:_SyncContentVisibility()
end

FacTopHudCtrl.OnClose = HL.Override() << function(self)
    self:_SuspendFactoryContent()
    self:_UnloadContent()
end

FacTopHudCtrl.OnShow = HL.Override() << function(self)
    self:_SyncContentVisibility()
end

FacTopHudCtrl.OnHide = HL.Override() << function(self)
    if not Utils.isInFactoryMode() then
        self:_SuspendFactoryContent()
        return
    end
    self:_SyncContentVisibility()
end

FacTopHudCtrl.OnEnterFactoryMode = HL.StaticMethod() << function()
    if FactoryUtils.isInBuildMode() then
        return
    end
    local self = UIManager:AutoOpen(PANEL_ID)
    if not self:IsShow() then
        self:Show()
    end
    if self.view.defaultNode.animationWrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
        self.view.defaultNode.animationWrapper:SampleToOutAnimationEnd()
    end
    self.m_allowHudContentShow = false
    self:_TryLoadContent(CONTENT_TYPE.Power)
    self:_OnBuildModeChange('')
    self.view.defaultNode.animationWrapper:PlayInAnimation(function()
        self.m_allowHudContentShow = true
        self:_SyncContentVisibility()
    end)
end

FacTopHudCtrl.OnExitFactoryMode = HL.Method() << function(self)
    if FactoryUtils.isInBuildMode() then
        return
    end
    self:_SuspendFactoryContent()
    self.view.defaultNode.animationWrapper:PlayOutAnimation(function()
        self:Hide()
    end)
end

FacTopHudCtrl.OnEnterBuildingMode = HL.StaticMethod(HL.String) << function(itemId)
    local self = UIManager:AutoOpen(PANEL_ID)
    if not self:IsShow() then
        self:Show()
    end
    self.m_allowHudContentShow = false
    self:_TryLoadContent(CONTENT_TYPE.Power)
    self.view.defaultNode.animationWrapper:SampleToInAnimationEnd()
    self:_OnBuildModeChange(itemId)
    self.view.defaultNode.animationWrapper:PlayWithTween("fac_mini_bar_enter_fac_mode_change", function()
        self.m_allowHudContentShow = true
        self:_SyncContentVisibility()
    end)
end

FacTopHudCtrl.OnExitBuildingMode = HL.Method() << function(self)
    if Utils.isInFactoryMode() and self:IsShow() then
        self.view.defaultNode.animationWrapper:SampleToInAnimationEnd()
        self:_OnBuildModeChange('')
    else
        self:_SuspendFactoryContent()
        self.view.defaultNode.animationWrapper:PlayWithTween("fac_mini_bar_enter_fac_mode_changeout", function()
            self:Hide()
        end)
    end
end

FacTopHudCtrl.OnInFacMainRegionChange = HL.Method(HL.Boolean) << function(self, _)
    if not string.isEmpty(self.m_curBuildBuildingItemId) then
        self:_OnBuildModeChange(self.m_curBuildBuildingItemId)
    end
end

FacTopHudCtrl._OnBuildModeChange = HL.Method(HL.String) << function(self, buildingItemId)
    local changed = self.m_curBuildBuildingItemId ~= buildingItemId
    self.m_curBuildBuildingItemId = buildingItemId
    local data = FactoryUtils.getItemBuildingData(buildingItemId)
    local inBuildingMode = FactoryUtils.isInBuildMode()
    local node = self.view.defaultNode
    self:OnFacBuildingPreviewPositionRotationChanged(buildingItemId, true)
    if changed then
        self.m_ignoreModeSwitchPopUp = false
    end
    self:_RefreshMultimodeToggle(buildingItemId)

    node.buildPreviewTxt.gameObject:SetActive(inBuildingMode)
    if not inBuildingMode then
        return
    end
    node.buildPreviewTxt.text = string.format(Language.LUA_BUILD_PREVIEW_TITLE, data.name)
end

FacTopHudCtrl.OnFacBuildingPreviewPositionRotationChanged = HL.Method(HL.Opt(HL.String, HL.Boolean)) << function(self, buildingItemId, forceChanged)
    buildingItemId = buildingItemId or self.m_curBuildBuildingItemId
    if not forceChanged and string.isEmpty(buildingItemId) then
        return
    end
    if self.m_currentContent then
        self.m_currentContent:OnFacBuildingPreviewPositionRotationChangedForContent(buildingItemId)
    end
end

FacTopHudCtrl._HideMultimodeToggle = HL.Method() << function(self)
    self.m_baseMode, self.m_switchMode = "", ""
    self.view.defaultNode.multimodeToggle.gameObject:SetActive(false)
end

FacTopHudCtrl._RefreshMultimodeToggle = HL.Method(HL.String) << function(self, buildingItemId)
    if not FactoryUtils.isInBuildMode() or string.isEmpty(buildingItemId) then
        self:_HideMultimodeToggle()
        return
    end

    local buildingMode = GameInstance.remoteFactoryManager.interact.currentBuildingMode
    if not buildingMode then
        self:_HideMultimodeToggle()
        return
    end

    local currentMode = buildingMode.nodeMode
    if string.isEmpty(currentMode) then
        self:_HideMultimodeToggle()
        return
    end

    local buildingId = buildingMode.buildingId
    local hasModeSwitch, baseMode, switchMode = FactoryUtils.checkBuildingHasModeSwitch(buildingId)
    if not hasModeSwitch then
        self:_HideMultimodeToggle()
        return
    end

    self.m_baseMode, self.m_switchMode = baseMode, switchMode

    if currentMode ~= baseMode and currentMode ~= switchMode then
        logger.error(ELogChannel.Factory, "Invalid building mode, buildingId: " .. tostring(buildingId)
            .. ", currentMode: " .. tostring(currentMode)
            .. ", baseMode: " .. tostring(baseMode) .. ", switchMode: " .. tostring(switchMode))
        self:_HideMultimodeToggle()
        return
    end

    local node = self.view.defaultNode
    node.multimodeToggle.gameObject:SetActive(true)
    node.multimodeToggle:SetValue(currentMode == switchMode, true)

    local switchModeData = Tables.factoryMachineCraftModeTable:GetValue(switchMode)
    node.multimodeToggle.view.left.text.text = switchModeData.machineModeTypeName
    node.multimodeToggle.view.left.icon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_COMMON, switchModeData.iconId)
    local baseModeData = Tables.factoryMachineCraftModeTable:GetValue(baseMode)
    node.multimodeToggle.view.right.text.text = baseModeData.machineModeTypeName
    node.multimodeToggle.view.right.icon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_COMMON, baseModeData.iconId)

    CS.Beyond.Gameplay.Conditions.OnFacEnterBuildingModeSwitch.Trigger()
end

FacTopHudCtrl._CheckIsMultimodeToggleValueValid = HL.Method(HL.Boolean).Return(HL.Boolean) << function(self, isOn)
    if self.m_ignoreModeSwitchPopUp then
        return true
    end

    local buildingMode = GameInstance.remoteFactoryManager.interact.currentBuildingMode
    if not buildingMode then
        return false
    end

    if not buildingMode.isMoving then
        return true
    end

    local success = FactoryUtils.checkSwitchBuildingMode(buildingMode.buildingId, buildingMode.nodeMode, self.m_baseMode, self.m_switchMode, function()
        self.m_ignoreModeSwitchPopUp = true
        self:_OnMultimodeToggleChanged(isOn)
    end)
    return success
end

FacTopHudCtrl._OnMultimodeToggleChanged = HL.Method(HL.Boolean) << function(self, isOn)
    local targetMode = isOn and self.m_switchMode or self.m_baseMode
    if string.isEmpty(targetMode) then
        self:_HideMultimodeToggle()
        return
    end

    local buildingMode = GameInstance.remoteFactoryManager.interact.currentBuildingMode
    if not buildingMode then
        self:_HideMultimodeToggle()
        return
    end

    local success = buildingMode:TrySetPreviewMode(CSFactoryUtil.ToFacNodeMode(targetMode))
    if success then
        self:OnFacBuildingPreviewPositionRotationChanged()
    end
    self:_RefreshMultimodeToggle(self.m_curBuildBuildingItemId)

    local toggleAudio = FacConst.FAC_FORMULA_MODE_TOGGLE_AUDIO[targetMode]
    if toggleAudio then
        AudioAdapter.PostEvent(toggleAudio)
    end
end

FacTopHudCtrl.OnBuildModeChange = HL.Method(HL.Number) << function(self, mode)
    if not self.m_currentContent then
        return
    end
    self.m_currentContent:BuildModeChangeForContent(mode == FacConst.FAC_BUILD_MODE.Normal)
end

FacTopHudCtrl.OnFacChapterReset = HL.Method() << function(self)
    if not self.m_currentContent then
        return
    end
    self.m_currentContent:FacChapterResetForContent(self.m_curBuildBuildingItemId)
    self:_RefreshMultimodeToggle(self.m_curBuildBuildingItemId)
end

HL.Commit(FacTopHudCtrl)
