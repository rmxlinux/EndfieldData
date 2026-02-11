local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharInfoProfileShow





































CharInfoProfileShowCtrl = HL.Class('CharInfoProfileShowCtrl', uiCtrl.UICtrl)








CharInfoProfileShowCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CharInfoProfileShowCtrl.m_lastMainControlTab = HL.Field(HL.Number) << UIConst.CHAR_INFO_PAGE_TYPE.PROFILE


CharInfoProfileShowCtrl.m_curTab = HL.Field(HL.Number) << UIConst.CHAR_INFO_PROFILE_TAB_ENUM.Files


CharInfoProfileShowCtrl.m_charInfo = HL.Field(HL.Table)


CharInfoProfileShowCtrl.m_profile = HL.Field(HL.Table)


CharInfoProfileShowCtrl.m_fileCellCache = HL.Field(HL.Forward("UIListCache"))


CharInfoProfileShowCtrl.m_genVoiceCell = HL.Field(HL.Function)


CharInfoProfileShowCtrl.m_voiceSelectIndex = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_timerId = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_onlyShow = HL.Field(HL.Boolean) << false


CharInfoProfileShowCtrl.m_voiceHandleId = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_onDrag = HL.Field(HL.Function)


CharInfoProfileShowCtrl.m_onZoom = HL.Field(HL.Function)


CharInfoProfileShowCtrl.m_zoomInTickKey = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_zoomOutTickKey = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_rotateTickKey = HL.Field(HL.Number) << -1






CharInfoProfileShowCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        self:Notify(MessageConst.CHAR_INFO_PROFILE_CLOSE)
        self:Notify(MessageConst.CHAR_INFO_PAGE_CHANGE, {
            pageType = self.m_lastMainControlTab,
            isFast = true,
        })
    end)

    self.m_charInfo = arg.initCharInfo
    self.m_curTab = arg.pageType
    self.m_onlyShow = arg.extraArg and arg.extraArg.onlyShow
    self.m_lastMainControlTab = arg.lastMainControlTab
    self.m_profile = CharInfoUtils.getCharInfoProfile(self.m_charInfo.templateId)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId},{"char_profile_rotate"})

    self:_StartCoroutine(function()
        self.m_rotateTickKey = LuaUpdate:Add("LateTick", function(deltaTime)
            local stickValue = InputManagerInst:GetGamepadStickValue(false)
            if stickValue.x ~= 0 then
                self:_MoveCharacter(stickValue * self.view.config.CONTROLLER_ROTATE_SENSITIVITY)
            end
        end)
    end)

    local virtualMouseMode = self.m_onlyShow and Types.EPanelMouseMode.ForceHide or Types.EPanelMouseMode.NeedShow
    self:SwitchCharInfoVirtualMouseType(virtualMouseMode)
    InputManagerInst:MoveVirtualMouseTo(self.view.transform, self.uiCamera)

    if self.m_onlyShow then
        self.view.left.hideButton.gameObject:SetActive(true)
        self.view.right.gameObject:SetActive(true)
        self.view.centerNode.gameObject:SetActive(false)

        self.view.left.hideButton.onClick:AddListener(function()
            local active = self.view.right.gameObject.activeSelf
            self.view.right.gameObject:SetActive(not active)
        end)
        self:BindInputPlayerAction("char_profile_zoom_in_enable", function()
            LuaUpdate:Remove(self.m_zoomInTickKey)
            self.m_zoomInTickKey = LuaUpdate:Add("LateTick", function(deltaTime)
                self:_ZoomCamera(-deltaTime * self.view.config.CONTROLLER_ZOOM_SENSITIVITY)
            end)
        end)
        self:BindInputPlayerAction("char_profile_zoom_in_disable", function()
            LuaUpdate:Remove(self.m_zoomInTickKey)
        end)
        self:BindInputPlayerAction("char_profile_zoom_out_enable", function()
            LuaUpdate:Remove(self.m_zoomOutTickKey)
            self.m_zoomOutTickKey = LuaUpdate:Add("LateTick", function(deltaTime)
                self:_ZoomCamera(deltaTime * self.view.config.CONTROLLER_ZOOM_SENSITIVITY)
            end)
        end)
        self:BindInputPlayerAction("char_profile_zoom_out_disable", function()
            LuaUpdate:Remove(self.m_zoomOutTickKey)
        end)
    else
        self.view.left.hideButton.gameObject:SetActive(false)
        self.view.right.gameObject:SetActive(false)
        self.view.centerNode.gameObject:SetActive(true)

        for i = 1, UIConst.CHAR_INFO_PROFILE_TAB_ENUM.TotalNum do
            local tab = self.view.centerNode[string.format("tab%d", i)]
            tab.button.onClick:RemoveAllListeners()
            tab.button.onClick:AddListener(function()
                if self.m_curTab ~= i then
                    self:_OnTabClick(i)
                end
            end)
        end

        self.m_fileCellCache = UIUtils.genCellCache(self.view.centerNode.filesElementCell)
        self.m_genVoiceCell = UIUtils.genCachedCellFunction(self.view.centerNode.voiceScrollList, function(object)
            return Utils.wrapLuaNode(object)
        end)

        self.view.centerNode.voiceScrollList.onUpdateCell:RemoveAllListeners()
        self.view.centerNode.voiceScrollList.onUpdateCell:AddListener(function(object, csIndex)
            self:_OnUpdateVoiceList(object, LuaIndex(csIndex))
        end)

        self.view.centerNode.voiceScrollList.onGraduallyShowFinish:RemoveAllListeners()
        self.view.centerNode.voiceScrollList.onGraduallyShowFinish:AddListener(function()
            local isVoice = self.m_curTab == UIConst.CHAR_INFO_PROFILE_TAB_ENUM.Voice
            if isVoice then
                local cell = self.view.centerNode.voiceScrollList:Get(CSIndex(1))
                if cell then
                    
                    InputManagerInst:MoveVirtualMouseTo(cell.transform, self.uiCamera, false)
                end
            end
        end)
    end
end




CharInfoProfileShowCtrl.SwitchCharInfoVirtualMouseType = HL.Method(HL.Any) << function(self, panelMouseMode)
    self:ChangePanelCfg("virtualMouseMode", panelMouseMode)
    self:ChangePanelCfg("realMouseMode", panelMouseMode)
end



CharInfoProfileShowCtrl.OnShow = HL.Override() << function(self)
    if self.m_onlyShow then
        self:_RefreshBasic()
        self:_AddRegisters()
    else
        self:_Refresh()
    end
end



CharInfoProfileShowCtrl.OnHide = HL.Override() << function(self)
    self:_ClearVoice()
    self:_ClearRegisters()
end



CharInfoProfileShowCtrl.OnClose = HL.Override() << function(self)
    self:_ClearVoice()
    self:_ClearRegisters()
end



CharInfoProfileShowCtrl._AddRegisters = HL.Method() << function(self)
    local touchPanel = self.view.touchPanel
    if not self.m_onDrag then
        self.m_onDrag = function(eventData)
            self:_MoveCharacter(eventData.delta)
        end
    end
    touchPanel.onDrag:AddListener(self.m_onDrag)

    if not self.m_onZoom then
        self.m_onZoom = function(delta)
            self:_ZoomCamera(delta, true)
        end
    end
    touchPanel.onZoom:AddListener(self.m_onZoom)
    
    
end



CharInfoProfileShowCtrl._ClearRegisters = HL.Method() << function(self)
    local touchPanel = self.view.touchPanel
    if self.m_onDrag then
        touchPanel.onDrag:RemoveListener(self.m_onDrag)
    end

    if self.m_onZoom then
        touchPanel.onZoom:RemoveListener(self.m_onZoom)
    end

    LuaUpdate:Remove(self.m_rotateTickKey)
    LuaUpdate:Remove(self.m_zoomInTickKey)
    LuaUpdate:Remove(self.m_zoomOutTickKey)
end




CharInfoProfileShowCtrl._MoveCharacter = HL.Method(HL.Userdata) << function(self, delta)
    if self.m_onlyShow then
        self:Notify(MessageConst.CHAR_INFO_SHOW_ROTATE_CHAR, delta.x * self.view.config.ROTATE_CHARACTER_SPEED)
    end
end





CharInfoProfileShowCtrl._ZoomCamera = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, delta, needTween)
    if self.m_onlyShow then
        if not needTween then
            self:Notify(MessageConst.CHAR_INFO_SHOW_ZOOMING, delta)
        else
            CameraManager:Zoom(delta * 2, true)
        end
    end
end



CharInfoProfileShowCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local isFiles = self.m_curTab == UIConst.CHAR_INFO_PROFILE_TAB_ENUM.Files
    if isFiles then
        local cell = self.m_fileCellCache:GetItem(1)
        InputManagerInst:MoveVirtualMouseTo(cell.gameObject.transform, self.uiCamera, false)
    end
end



CharInfoProfileShowCtrl._Refresh = HL.Method() << function(self)
    self:_RefreshBasic()

    local centerNode = self.view.centerNode
    local isFiles = self.m_curTab == UIConst.CHAR_INFO_PROFILE_TAB_ENUM.Files
    local isVoice = self.m_curTab == UIConst.CHAR_INFO_PROFILE_TAB_ENUM.Voice

    centerNode.contentNode.gameObject:SetActive(false)
    self.view.centerNode.charInfoFileInformation.gameObject:SetActive(true)
    self.view.centerNode.filesScrollList.gameObject:SetActive(isFiles)
    self.view.centerNode.voiceScrollList.gameObject:SetActive(isVoice)
    if isVoice then
        self:_RefreshVoice()
    end
    self:_RefreshFiles()
    self:_RefreshVoice()
    self:_RefreshTab()
end



CharInfoProfileShowCtrl._RefreshBasic = HL.Method() << function(self)
    local centerNode = self.view.centerNode
    local right = self.view.right

    centerNode.charInfoFileInformation:InitCharInfoProfileInformation(self.m_charInfo)
    right.charInfoFileInformation:InitCharInfoProfileInformation(self.m_charInfo)
end



CharInfoProfileShowCtrl._RefreshFiles = HL.Method() << function(self)
    local profileRecord = self.m_profile.profileRecord
    self.m_fileCellCache:Refresh(profileRecord.Count, function(cell, luaIndex)
        local data = profileRecord[CSIndex(luaIndex)]
        cell.textName.text = data.recordTitle
        cell.textDes.text = data.recordDesc
        LayoutRebuilder.ForceRebuildLayoutImmediate(cell.information)
        LayoutRebuilder.ForceRebuildLayoutImmediate(cell.rectTransform)
    end)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.centerNode.filesScrollList.content.transform)
end



CharInfoProfileShowCtrl._RefreshVoice = HL.Method() << function(self)
    self.view.centerNode.voiceScrollList:UpdateCount(self.m_profile.profileVoice.Count, true, true)
end



CharInfoProfileShowCtrl._RefreshVoiceSelect = HL.Method() << function(self)
    for cellIndex = 1, self.view.centerNode.voiceScrollList.count do
        local go = self.view.centerNode.voiceScrollList:Get(CSIndex(cellIndex))
        if go then
            local select = self.m_voiceSelectIndex == cellIndex
            local cell = self.m_genVoiceCell(go)
            cell.selectNode.gameObject:SetActive(select)
            cell.bgPlaying.gameObject:SetActive(select)
            cell.normalNode.gameObject:SetActive(not select)
        end
    end
end




CharInfoProfileShowCtrl._OnTabClick = HL.Method(HL.Number) << function(self, tabIndex)
    self.m_curTab = tabIndex
    self.m_voiceSelectIndex = -1
    self:_Refresh()
end




CharInfoProfileShowCtrl._PlayVoice = HL.Method(HL.Number) << function(self, luaIndex)
    local data = self.m_profile.profileVoice[CSIndex(luaIndex)]
    local voiceId = data.voId
    local res, duration = VoiceUtils.TryGetVoiceDuration(voiceId)
    if res then
        self.m_voiceHandleId = VoiceManager:SpeakNarrative(voiceId, nil, CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig.CHAR_PROFILE_INFO_CONFIG)
        self.m_timerId = self:_StartTimer(duration, function()
            self:_ClearVoice()
        end)

        self.view.centerNode.contentNode.gameObject:SetActive(true)
        self.view.centerNode.charInfoFileInformation.gameObject:SetActive(false)
        self.view.centerNode.content.text = data.voiceDesc
        LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.centerNode.contentNode.transform)
    else
        logger.error("no such voiceId: " .. voiceId, "!!!")
    end
end



CharInfoProfileShowCtrl._ClearVoice = HL.Method() << function(self)
    if self.m_timerId >= 0 then
        self:_ClearTimer(self.m_timerId)
        self.m_timerId = -1
    end

    if self.m_voiceHandleId >= 0 then
        VoiceManager:StopVoice(self.m_voiceHandleId)
        self.m_voiceHandleId = -1
    end

    local object = self.view.centerNode.voiceScrollList:Get(CSIndex(self.m_voiceSelectIndex))
    if object then
        local cell = self.m_genVoiceCell(object)
        cell.bgPlaying.gameObject:SetActive(false)
    end

    self.view.centerNode.contentNode.gameObject:SetActive(false)
    self.view.centerNode.charInfoFileInformation.gameObject:SetActive(true)
end





CharInfoProfileShowCtrl._OnUpdateVoiceList = HL.Method(HL.Userdata, HL.Number) << function(self, object, luaIndex)
    local cell = self.m_genVoiceCell(object)
    local select = self.m_voiceSelectIndex == luaIndex
    local data = self.m_profile.profileVoice[CSIndex(luaIndex)]
    cell.textNameNormal.text = data.voiceTitle
    cell.textNameSelect.text = data.voiceTitle

    cell.selectNode.gameObject:SetActive(select)
    cell.normalNode.gameObject:SetActive(not select)

    cell.bgPlaying.gameObject:SetActive(select)

    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self.m_voiceSelectIndex = luaIndex
        self:_ClearVoice()
        self:_PlayVoice(luaIndex)
        self:_RefreshVoiceSelect()
    end)
    cell.button.animator:SetTrigger("Normal")
    cell.button.clickHintTextId = "key_hint_char_profile_show_play_voice"
end



CharInfoProfileShowCtrl._RefreshTab = HL.Method() << function(self)
    for i = 1, UIConst.CHAR_INFO_PROFILE_TAB_ENUM.TotalNum do
        local tab = self.view.centerNode[string.format("tab%d", i)]
        local select = i == self.m_curTab
        tab.selectNode.gameObject:SetActive(select)
        tab.normalNode.gameObject:SetActive(not select)
    end
end

HL.Commit(CharInfoProfileShowCtrl)
