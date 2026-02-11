local WaterDroneAimType = CS.Beyond.Gameplay.WaterDroneAimType
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WaterDroneAim

































WaterDroneAimCtrl = HL.Class('WaterDroneAimCtrl', uiCtrl.UICtrl)


WaterDroneAimCtrl.m_curActiveAim = HL.Field(GameObject)


WaterDroneAimCtrl.m_waterDroneBar = HL.Field(HL.Table)


WaterDroneAimCtrl.m_controllerTriggerSettingHandlerId = HL.Field(HL.Number) << -1






WaterDroneAimCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SYNC_WATER_DRONE_AIM] = '_SyncWaterDroneAim',
    [MessageConst.HIDE_WATER_DRONE_AIM] = '_OnHideWaterDroneAim',
    [MessageConst.SYNC_LIQUID_STATE] = '_SyncLiquidState',
    [MessageConst.SYNC_REMAINING_LIQUID_CAPACITY] = '_SyncRemainingLiquidCapacity',
    [MessageConst.SYNC_SPRAYING] = '_SyncSpraying',
    [MessageConst.WATER_DRONE_AIM_HAS_LIQUID_STATE] = '_SyncHasLiquidState',
    [MessageConst.WATER_DRONE_LIQUID_STATE_EMPTY] = '_SetLiquidStateEmpty',
    [MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE] = '_OnChangeInputDeviceType',
    [MessageConst.SYNC_WATER_DRONE_SHOOT_BUT_BANNED_HINT_LIQUID] = '_SyncWaterDroneShootButBannedHintLiquid',
}





WaterDroneAimCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.view.closeBtn.onClick:AddListener(function()
        self:_OnCancel()
    end)

    
    self.view.switchLiquidBtn.onClick:AddListener(function()
        self:_OnSwitchLiquidOpenBagBtn()
    end)

    
    
    

    
    if DeviceInfo.usingController then
        self:BindInputPlayerAction("battle_attack_start", function()
        end)
        self:BindInputPlayerAction("battle_attack_end", function()
        end)
    end

    
    
    
    
    
    self:BindNormalAttackInputEvent()
    
    if DeviceInfo.usingTouch then
        self.view.sprayBtn.onPressStart:AddListener(function()
            self:StartPressAttackBtn()
        end)

        self.view.sprayBtn.onPressEnd:AddListener(function()
            self:ReleaseNormalAttackBtn()
        end)
    end

    self.m_waterDroneBar = Utils.wrapLuaNode(CSUtils.CreateObject(self.view.config.WATER_DRONE_BAR, UIManager.worldObjectRoot))

    self:_InitWaterDroneJoystickBinding()
end



WaterDroneAimCtrl.CanSwitchLiquid = HL.Method().Return(HL.Boolean) << function(self)
    return not GameInstance.player.forbidSystem:IsForbidden(ForbidType.ForbidWaterDroneSwitchLiquidBtn)
end













WaterDroneAimCtrl.BindNormalAttackInputEvent = HL.Method() << function(self)
    self:BindInputPlayerAction("water_drone_attack_start", function() 
        if UNITY_EDITOR and DeviceInfo.usingTouch then
            return
        end
        if not InputManager.cursorVisible then
            
            self:StartPressAttackBtn()
        end
    end)

    self:BindInputPlayerAction("water_drone_attack_end", function() 
        if UNITY_EDITOR and DeviceInfo.usingTouch then
            return
        end
        self:ReleaseNormalAttackBtn()
    end)
end



WaterDroneAimCtrl.OnClose = HL.Override() << function(self)
    if self.m_waterDroneBar then
        GameObject.Destroy(self.m_waterDroneBar.gameObject)
    end
    self.m_waterDroneBar = nil
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {false, "WaterDrone"})
    if DeviceInfo.usingController then
        GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, "WaterDrone", false)
    end
    self:_ClearControllerTriggerSetting()
end



WaterDroneAimCtrl.OnShow = HL.Override() << function(self)
    
    
    
    local customAbilityCom = GameUtil.mainCharacter.customAbilityCom
    self:_SyncRemainingLiquidCapacity({customAbilityCom.isInfinityLiquid, tostring(customAbilityCom.showCapacityCount)})

    if self:CanSwitchLiquid() then
        self.view.switchLiquidBtn.gameObject:SetActive(true)
    else
        self.view.switchLiquidBtn.gameObject:SetActive(false)
    end

    
    if self.m_waterDroneBar then
        self.m_waterDroneBar.gameObject:SetActive(true)
    end
    
    self:_ToggleShowHideBattleAction(false)
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {true, "WaterDrone"})
    self:_ClearControllerTriggerSetting()
    if DeviceInfo.usingController then
        GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, "WaterDrone", true)
        if self.m_hasLiquid then
            self:_AddControllerTriggerSetting()
        end
    end
end



WaterDroneAimCtrl.OnHide = HL.Override() << function(self)
    
    if self.m_waterDroneBar then
        
        self.m_waterDroneBar.gameObject:GetComponent("UIAnimationWrapper"):PlayOutAnimation(function()
            self.m_waterDroneBar.gameObject:SetActive(false)
        end);
    end

    
    self:_ToggleShowHideBattleAction(true)

    self:_ClearControllerTriggerSetting()
end



WaterDroneAimCtrl._ClearControllerTriggerSetting = HL.Method() << function(self)
    if self.m_controllerTriggerSettingHandlerId > 0 then
        GameInstance.audioManager.gamePad.scePad:EndTriggerEffect(self.m_controllerTriggerSettingHandlerId)
        self.m_controllerTriggerSettingHandlerId = -1
    end
end




WaterDroneAimCtrl._ToggleShowHideBattleAction = HL.Method(HL.Boolean) << function(self, active)
    if active then
        UIManager:ShowWithKey(PanelId.BattleAction, "WaterDroneAim")
    else
        UIManager:HideWithKey(PanelId.BattleAction, "WaterDroneAim")
    end
end



WaterDroneAimCtrl.StartPressAttackBtn = HL.Method() << function(self)
    self:_ExecuteCustomAbility()
    
end



WaterDroneAimCtrl.ReleaseNormalAttackBtn = HL.Method() << function(self)
    GameInstance.playerController.mainCharacter.customAbilityCom:StopAbility();
    
end




WaterDroneAimCtrl._ExecuteCustomAbility = HL.Method() << function(self)
    GameInstance.playerController.mainCharacter.customAbilityCom:UseAbility()
end


WaterDroneAimCtrl.OnShowWaterDroneAim = HL.StaticMethod() << function()
    local waterDroneAimPanel = UIManager:AutoOpen(PANEL_ID)
end



WaterDroneAimCtrl._OnHideWaterDroneAim = HL.Method() << function(self)
    
    self:Hide()
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {false, "WaterDrone"})
    if DeviceInfo.usingController then
        GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, "WaterDrone", false)
    end
end




WaterDroneAimCtrl._SyncWaterDroneAim = HL.Method(HL.Any) << function(self, args)
    local aimType = unpack(args)
    local aimObject
    if aimType == WaterDroneAimType.AimAndGood then
        aimObject = self.view.aimAndGood.gameObject
    elseif aimType == WaterDroneAimType.AimButBanned then
        aimObject = self.view.aimButBanned.gameObject
    elseif aimType == WaterDroneAimType.AimButNoUse then
        aimObject = self.view.aimButNoUse.gameObject
    elseif aimType == WaterDroneAimType.NoLiquid then
        aimObject = self.view.noLiquid.gameObject
    elseif aimType == WaterDroneAimType.OutOfRange then
        aimObject = self.view.outOfRange.gameObject
    elseif aimType == WaterDroneAimType.ShootAndGood then
        aimObject = self.view.shootAndGood.gameObject
    elseif aimType == WaterDroneAimType.ShootButBanned then
        aimObject = self.view.shootButBanned.gameObject
    elseif aimType == WaterDroneAimType.ShootButNoUse then
        aimObject = self.view.shootButNoUse.gameObject
    elseif aimType == WaterDroneAimType.CannotShoot then
        aimObject = self.view.cannotShoot.gameObject
    end
    if aimObject == self.m_curActiveAim then
        return
    end
    if self.m_curActiveAim then
        self.m_curActiveAim:SetActive(false)
    end
    self.m_curActiveAim = aimObject
    if self.m_curActiveAim then
        self.m_curActiveAim:SetActive(true)
    end
end






WaterDroneAimCtrl._SyncLiquidState = HL.Method(HL.Table) << function(self, args)
    local isAvailable, stateName = unpack(args)
    if isAvailable then
        
        self.view.liquidAvailableState:SetState(stateName)
        local found, liquidItemData = Tables.itemTable:TryGetValue(stateName)
        if found then
            local liquidItemName = liquidItemData.name
            self.view.liquidTypeText.text = liquidItemName
        end
    else
    end
end




WaterDroneAimCtrl._SyncRemainingLiquidCapacity = HL.Method(HL.Table) << function(self, args)
    local isInfinity, count = unpack(args)
    if isInfinity then
        self.view.supplyTxt.text = Language.LUA_ITEM_INFINITE_COUNT
        self.view.supplyTxt.color = Color.white
    else
        self.view.supplyTxt.text = count
        if count == "0" then
            self.view.supplyTxt.color = self.view.config.ZERO_COLOR
        else
            self.view.supplyTxt.color = Color.white
        end
    end
end




WaterDroneAimCtrl._SyncSpraying = HL.Method(HL.Table) << function(self, args)
    local isSpraying = unpack(args)
    self.view.sprayingText.gameObject:SetActive(isSpraying)
end


WaterDroneAimCtrl.m_hasLiquid = HL.Field(HL.Boolean) << false




WaterDroneAimCtrl._SyncHasLiquidState = HL.Method(HL.Table) << function(self, args)
    local hasLiquid = unpack(args)
    self.m_hasLiquid = hasLiquid
    self:_ClearControllerTriggerSetting()
    if hasLiquid then
        self.view.liquidState:SetState("AvailableNode")
        self:_AddControllerTriggerSetting()
    else
        
        
    end
end



WaterDroneAimCtrl._AddControllerTriggerSetting = HL.Method() << function(self)
    if DeviceInfo.usingController and not DeviceInfo.isMobile and self.m_controllerTriggerSettingHandlerId == -1 then
        self.m_controllerTriggerSettingHandlerId = GameInstance.audioManager.gamePad.scePad:SetTriggerEffect(self.view.psTriggerEffectCfg.commands[0])
    end
end





WaterDroneAimCtrl._SetLiquidStateEmpty = HL.Method() << function(self)
    self.view.liquidState:SetState("EmptyNode")
end




WaterDroneAimCtrl._SyncWaterDroneShootButBannedHintLiquid = HL.Method(HL.Table) << function(self, args)
    local liquidId = unpack(args)
    
    self.view.shootButBannedStateController:SetState(liquidId)
    
end




WaterDroneAimCtrl._OnChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    local customAbilityCom = GameUtil.mainCharacter.customAbilityCom
    customAbilityCom:TryEndAbility_ByChangeInputDeviceType()
end



WaterDroneAimCtrl._OnCancel = HL.Method() << function(self)
    if GameInstance.playerController.mainCharacter == nil then
        return
    end
    GameInstance.playerController.mainCharacter.customAbilityCom:EndAbility() 
end




WaterDroneAimCtrl._OnSwitchLiquidOpenBagBtn = HL.Method() << function(self)
    if self:CanSwitchLiquid() then
        Notify(MessageConst.SHOW_WATER_DRONE_BAG)
        
        self:Hide()
    end
end





WaterDroneAimCtrl._InitWaterDroneJoystickBinding = HL.Method() << function(self)
    self.view.uiJoystick.onDrag:AddListener(function(eventData)
        self:_OnDrag(eventData)
    end)
end





WaterDroneAimCtrl._OnDrag = HL.Method(HL.Userdata) << function(self, eventData)
    local delta = eventData.delta
    local cameraInputScaleX = self.view.waterDroneJoystickCtrl.cameraInputScaleX
    local cameraInputScaleY = self.view.waterDroneJoystickCtrl.cameraInputScaleY
    delta.x = cameraInputScaleX * delta.x
    delta.y = cameraInputScaleY * delta.y
    Notify(MessageConst.ON_DRAG_WATER_DRONE_JOYSTICK, delta)
end



HL.Commit(WaterDroneAimCtrl)
