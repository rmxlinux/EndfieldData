local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharInfoProfileShow



















CharInfoProfileShowCtrl = HL.Class('CharInfoProfileShowCtrl', uiCtrl.UICtrl)








CharInfoProfileShowCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CharInfoProfileShowCtrl.m_charInfo = HL.Field(HL.Table)


CharInfoProfileShowCtrl.m_onDrag = HL.Field(HL.Function)


CharInfoProfileShowCtrl.m_onZoom = HL.Field(HL.Function)


CharInfoProfileShowCtrl.m_zoomInTickKey = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_zoomOutTickKey = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_rotateTickKey = HL.Field(HL.Number) << -1


CharInfoProfileShowCtrl.m_charBag = HL.Field(HL.Userdata)






CharInfoProfileShowCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_charBag = GameInstance.player.charBag
    self.m_charInfo = arg.initCharInfo
    self:_InitAction()

    local _, charData = Tables.characterTable:TryGetValue(self.m_charInfo.templateId)
    local showEffectNode = CharInfoUtils.isCharMaxPotential(self.m_charInfo.instId) and
        charData ~= nil and charData.rarity >= UIConst.CHAR_POTENTIAL_EFFECT_RARITY
    self.view.overallPotentialEffectNode.gameObject:SetActive(showEffectNode)
    self.view.charInfoFileInformation:InitCharInfoProfileInformation(self.m_charInfo)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId},{"char_profile_rotate"})
end



CharInfoProfileShowCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegisters()
end



CharInfoProfileShowCtrl.OnHide = HL.Override() << function(self)
    self:_ClearRegisters()
end



CharInfoProfileShowCtrl.OnClose = HL.Override() << function(self)
    self:_ClearRegisters()
end



CharInfoProfileShowCtrl.OnCharMaxPotentialEffectToggled = HL.StaticMethod(HL.Table) << function(args)
    local charId, isOn = unpack(args)
    local tipFmt = isOn and Language.LUA_CHAR_MAX_POTENTIAL_EFFECT_ON_TIP or Language.LUA_CHAR_MAX_POTENTIAL_EFFECT_OFF_TIP
    local tip = string.format(tipFmt, Tables.characterTable[charId].name)
    Notify(MessageConst.SHOW_TOAST, tip)
end



CharInfoProfileShowCtrl._InitAction = HL.Method() << function(self)
    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        self:_ClearRegisters()
        self:Notify(MessageConst.CHAR_INFO_PROFILE_CLOSE)
        self:Notify(MessageConst.CHAR_INFO_PAGE_CHANGE, {
            pageType = UIConst.CHAR_INFO_PAGE_TYPE.OVERVIEW,
            isFast = true,
        })
    end)
    self.view.overallPotentialEffectToggle:SetIsOnWithoutNotify(self.m_charBag:IsCharMaxPotentialEffectEnabled(self.m_charInfo.templateId))
    self.view.overallPotentialEffectToggle.onValueChanged:AddListener(function(isOn)
        self.m_charBag:SetCharMaxPotentialEffectEnabled(self.m_charInfo.templateId, isOn)
    end)

    self:_StartCoroutine(function()
        self.m_rotateTickKey = LuaUpdate:Add("LateTick", function(deltaTime)
            local stickValue = InputManagerInst:GetGamepadStickValue(false)
            if stickValue.x ~= 0 then
                self:_MoveCharacter(stickValue * self.view.config.CONTROLLER_ROTATE_SENSITIVITY)
            end
        end)
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
    self:Notify(MessageConst.CHAR_INFO_SHOW_ROTATE_CHAR, delta.x * self.view.config.ROTATE_CHARACTER_SPEED)
end





CharInfoProfileShowCtrl._ZoomCamera = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, delta, needTween)
    if not needTween then
        self:Notify(MessageConst.CHAR_INFO_SHOW_ZOOMING, delta)
    else
        CameraManager:Zoom(delta * 2, true)
    end
end

HL.Commit(CharInfoProfileShowCtrl)
