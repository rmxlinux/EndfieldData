local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SweetPieAim
SweetPieAimCtrl = HL.Class('SweetPieAimCtrl', uiCtrl.UICtrl)

SweetPieAimCtrl.m_isCloseOutside = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isLaunched = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isKeyInputBound = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isAccelerateInputBound = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isCloseToObstacle = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isChangeInputDeviceType = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_isInSweetPieFlight = HL.Field(HL.Boolean) << false
SweetPieAimCtrl.m_tickKey = HL.Field(HL.Number) << -1
SweetPieAimCtrl.m_tipsOffsetDist = HL.Field(HL.Number) << 0
SweetPieAimCtrl.m_tipsPrefabLocalRot = HL.Field(HL.Any)
SweetPieAimCtrl.m_sweetPieForward = HL.Field(HL.Any)
SweetPieAimCtrl.m_cameraForward = HL.Field(HL.Any)
SweetPieAimCtrl.m_cameraRight = HL.Field(HL.Any)
SweetPieAimCtrl.m_cameraUp = HL.Field(HL.Any)
SweetPieAimCtrl.m_sweetPiePos = HL.Field(HL.Any)
SweetPieAimCtrl.m_hitPoint = HL.Field(HL.Any)
SweetPieAimCtrl.m_obstaclePos = HL.Field(HL.Any)

SweetPieAimCtrl.s_isInSweetPie = HL.StaticField(HL.Boolean) << false

local FLAVOR_SPRITE = "SweetPieAim"
local NORMAL_STATE = "Normal"
local WARNING_STATE = "Warning"
local INTERACT_OPTION_HIDE_KEY = "inSweetPieAim"
local LOCK_TARGET_FORBID_KEY = "SweetPie"

SweetPieAimCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.HIDE_SWEET_PIE_AIM] = '_OnHideSweetPieAim',
    [MessageConst.ON_LAUNCH_SWEET_PIE] = '_OnLaunchSweetPie',
    [MessageConst.ON_SWEET_PIE_CLOSE_TO_OBSTACLE] = '_SetCloseToObstacle',
    [MessageConst.SET_SWEET_PIE_MODE] = "_SetFlavor",
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnChangeInputDeviceTypeFinished',
}

SweetPieAimCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_isCloseOutside = false
    self.m_isLaunched = false
    self.m_isKeyInputBound = false
    self.m_isAccelerateInputBound = false

    self:_SetFlavorInternal(0)
    self:_InitBtn()
    self:_RefreshState()
    self.m_tickKey = LuaUpdate:Add("TailTick", function()
        self:_UpdateState()
    end)
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {true, "SweetPie"})
end

SweetPieAimCtrl._InitBtn = HL.Method() << function(self)
    self:_BindDeviceKeyInput()
    self.view.closeBtn.onClick:AddListener(function()
        if self.m_isLaunched then
            self:_SetAccelerate(false)
            self:_ShowCancelPopup()
        else
            self:_OnCancel()
        end
    end)
    self.view.boostBtn.onPressStart:AddListener(function()
        self:_SetAccelerate(true)
    end)
    self.view.boostBtn.onPressEnd:AddListener(function()
        self:_SetAccelerate(false)
    end)

    self.view.chargeFireBtn.onClick:AddListener(function()
        GameInstance.playerController.mainCharacter.customAbilityCom:LaunchSweetPie()
    end)
    self.view.RecipeBtn.onClick:AddListener(function()
        self:_SetAccelerate(false)
        PhaseManager:OpenPhase(PhaseId.SweetPieManual)
    end)
end

SweetPieAimCtrl._RefreshState = HL.Method() << function(self)
    if self.m_isLaunched then
        self.view.RecipeBtn.gameObject:SetActive(true)
        self.view.state:SetState("Fly")
        self.view.aims.simpleStateController:SetState("Fly")
    else
        self.view.RecipeBtn.gameObject:SetActive(false)
        self.view.state:SetState("Aim")
    end
end

SweetPieAimCtrl.OnShow = HL.Override() << function(self)
end

SweetPieAimCtrl.OnHide = HL.Override() << function(self)
end

SweetPieAimCtrl.OnClose = HL.Override() << function(self)
    UIManager:ShowWithKey(PanelId.GeneralAbility, "SweetPieAim")
    
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, "SweetPieAim", false)
    if not self.m_isCloseOutside and not self.m_isChangeInputDeviceType then
        self:_OnCancel()
    end

    self:_CancelTick()
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {false, "SweetPie"})
end

SweetPieAimCtrl._CancelTick = HL.Method() << function(self)
    if self.m_tickKey > 0 then
        LuaUpdate:Remove(self.m_tickKey)
    end
end

SweetPieAimCtrl.ApplySweetPieToMainHud = HL.StaticMethod() << function()
    if SweetPieAimCtrl.s_isInSweetPie then
        Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { INTERACT_OPTION_HIDE_KEY, true })
    end
    if not UIManager:IsOpen(PanelId.SweetPieAim) then
        return
    end
    Notify(MessageConst.TOGGLE_PLAYER_JUMP, {"sweet_pie", true})
    Notify(MessageConst.DISABLE_MAIN_HUD_CONTROLLER_INDICATOR, {"inSweetPieAim", true})
end

SweetPieAimCtrl._OnShowSweetPieAim = HL.StaticMethod() << function()
    UIManager:AutoOpen(PANEL_ID)
    SweetPieAimCtrl.ApplySweetPieToMainHud()
    Notify(MessageConst.RELEASE_MAIN_HUD_ATTACK_INPUT)
end

SweetPieAimCtrl.OnHideMainHudButtons = HL.StaticMethod() << function()
    Notify(MessageConst.TOGGLE_PLAYER_JUMP, {"sweet_pie", false})
    Notify(MessageConst.DISABLE_MAIN_HUD_CONTROLLER_INDICATOR, {"inSweetPieAim", false})
end


SweetPieAimCtrl.OnEnterSweetPie = HL.StaticMethod() << function()
    SweetPieAimCtrl.s_isInSweetPie = true
    GameWorld.battle:ForceResetLockTarget()
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidLockTarget, LOCK_TARGET_FORBID_KEY, true)
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { INTERACT_OPTION_HIDE_KEY, true })
end

SweetPieAimCtrl.OnExitSweetPie = HL.StaticMethod() << function()
    SweetPieAimCtrl.s_isInSweetPie = false
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidLockTarget, LOCK_TARGET_FORBID_KEY, false)
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { INTERACT_OPTION_HIDE_KEY, false })
end

SweetPieAimCtrl._OnHideSweetPieAim = HL.Method() << function(self)
    self.m_isCloseOutside = true
    self:Close()
end

SweetPieAimCtrl._ShowCancelPopup = HL.Method() << function(self)
    local arg = {
        content = Language.LUA_SWEET_PIE_CANCEL_POPUP_CONTENT,
        onConfirm = function()
            self:_OnCancel()
        end,
        freezeWorld = true
    }
    if not UIUtils.inDungeonOrFocusMode() then
        arg.showGameSettingBtn = true
        arg.gameSettingArg = { tabId = GameSettingConst.TAB_ID_CONTROLLER }
        arg.tips = Language.LUA_SWEET_PIE_COMMON_POPUP_TIPS
    end
    Notify(MessageConst.SHOW_POP_UP, arg)
end

SweetPieAimCtrl._OnCancel = HL.Method() << function(self)
    if GameInstance.playerController.mainCharacter == nil then
        return
    end
    GameInstance.playerController.mainCharacter.customAbilityCom:ManuallyEndSweetPieAbility()
end

SweetPieAimCtrl._OnLaunchSweetPie = HL.Method() << function(self)
    self.m_isLaunched = true
    self.view.aims.gameObject:SetActive(true)
    UIManager:HideWithKey(PanelId.GeneralAbility, "SweetPieAim")
    self:_RefreshState()
    self:_BindAccelerateInput()
end


SweetPieAimCtrl._BindDeviceKeyInput = HL.Method() << function(self)
    if DeviceInfo.inputType == DeviceInfo.InputType.Touch or self.m_isKeyInputBound then
        return
    end
    self.m_isKeyInputBound = true
    self:BindInputPlayerAction("sweet_pie_drone_fly", function()
        GameInstance.playerController.mainCharacter.customAbilityCom:LaunchSweetPie()
    end)
end

SweetPieAimCtrl._BindAccelerateInput = HL.Method() << function(self)
    if DeviceInfo.inputType == DeviceInfo.InputType.Touch or self.m_isAccelerateInputBound then
        return
    end
    self.m_isAccelerateInputBound = true
    self:BindInputPlayerAction("sweet_pie_start_accelerate", function()
        self:_SetAccelerate(true)
    end)
    self:BindInputPlayerAction("sweet_pie_stop_accelerate", function()
        self:_SetAccelerate(false)
    end)
end

SweetPieAimCtrl._OnChangeInputDeviceTypeFinished = HL.Method(HL.Table) << function(self, args)
    if not self:IsShow() then
        return
    end
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, {true, "SweetPie"})
    self.m_isChangeInputDeviceType = true
    
    self:_BindDeviceKeyInput()
    if self.m_isLaunched then
        self:_SetAccelerate(false)
        self:_BindAccelerateInput()
        UIManager:HideWithKey(PanelId.GeneralAbility, "SweetPieAim")
    end
    
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, "SweetPieAim",
        args.inputType == DeviceInfo.InputType.Controller)
    self:_RefreshState()
end

SweetPieAimCtrl._SetAccelerate = HL.Method(HL.Boolean) << function(self, active)
    if not self.m_isLaunched then
        return
    end
    GameInstance.playerController.mainCharacter.customAbilityCom:SetSweetPieAccelerating(active)
end

SweetPieAimCtrl._UpdateState = HL.Method() << function(self)
    if self.m_isLaunched then
        self:_UpdateFlyState()
    else
        self:_UpdateAim()
    end
end

SweetPieAimCtrl._UpdateAim = HL.Method() << function(self)
    
    local customAbilityCom = GameInstance.playerController.mainCharacter.customAbilityCom
    if customAbilityCom.curState ~= CS.Beyond.Gameplay.CustomAbilityType.SweetPie then
        return
    end

    local sweetPieAbility = customAbilityCom.curAbility
    local isReady = sweetPieAbility.sweetPieReady
    self.view.aims.gameObject:SetActive(isReady)
    if not isReady then
        return
    end

    local canLaunch = sweetPieAbility.canLaunch
    if canLaunch then
        if sweetPieAbility.aimTargetPos ~= Vector3.zero then
            self.view.aims.simpleStateController:SetState("HasTarget")
        else
            self.view.aims.simpleStateController:SetState("Common")
        end
    else
        self.view.aims.simpleStateController:SetState("CannotFire")
    end
end

SweetPieAimCtrl._UpdateFlyState = HL.Method() << function(self)
    
    if self:_HandleSweetPieInfo() then
        
        self:_HandleSpiritLevel()
        
        self:_HandleCollision()
    end
    
    self:_HandleTime()
end

SweetPieAimCtrl._HandleSweetPieInfo = HL.Method().Return(HL.Boolean) << function(self)
    local customAbilityCom = GameInstance.playerController.mainCharacter.customAbilityCom
    if customAbilityCom.curState ~= CS.Beyond.Gameplay.CustomAbilityType.SweetPie then
        return false
    end

    local brain = GameWorld.gameMechManager.sweetPieBrain
    self.m_isInSweetPieFlight = brain:IsSweetPieFlighting()

    local sweetPieAbility = customAbilityCom.curAbility
    self.m_hitPoint = sweetPieAbility.m_hitPoint

    local sweetPiePtr = sweetPieAbility.sweetPie
    local sweetPieEntity = sweetPiePtr and sweetPiePtr:Lock()
    if sweetPieEntity == nil then
        return false
    end

    self.m_sweetPiePos = sweetPieEntity.position
    self.m_sweetPieForward = sweetPieEntity.forward
    local camTrans = GameInstance.cameraManager.mainCamera.transform
    self.m_cameraForward = camTrans.forward
    self.m_cameraRight = camTrans.right
    self.m_cameraUp = camTrans.up

    return true
end

SweetPieAimCtrl._HandleSpiritLevel = HL.Method() << function(self)
    local camYaw = SweetPieAimCtrl._HorizontalYawDeg(self.m_cameraForward)
    local sweetYaw = SweetPieAimCtrl._HorizontalYawDeg(self.m_sweetPieForward)
    local relativeYaw = ((sweetYaw - camYaw + 180) % 360) - 180
    self.view.aims.flyAim.transform.localRotation = Quaternion.Euler(0, 0, -relativeYaw);
end

SweetPieAimCtrl._HorizontalYawDeg = HL.StaticMethod(HL.Any).Return(HL.Number) << function(fwd)
    local x, z = fwd.x, fwd.z
    if x * x + z * z < 1e-8 then return 0 end   
    return math.deg(math.atan(x, z))
end

SweetPieAimCtrl._HandleCollision = HL.Method() << function(self)
    if not self.m_isCloseToObstacle or self.m_obstaclePos == nil then
        self.view.tipsNode.gameObject:SetActive(false)
        return
    end
    local cam = GameInstance.cameraManager.mainCamera
    if cam == nil then
        self.view.tipsNode.gameObject:SetActive(false)
        return
    end
    if not self.m_isInSweetPieFlight then
        self.view.tipsNode.gameObject:SetActive(false)
        return
    end
    self.view.tipsNode.gameObject:SetActive(true)
    
    local obstacleScreenPos = cam:WorldToScreenPoint(self.m_obstaclePos)
    if obstacleScreenPos.z < 0 then
        obstacleScreenPos.x = -obstacleScreenPos.x
        obstacleScreenPos.y = -obstacleScreenPos.y
    end
    local centerTrans = self.view.centerNode
    local tipsTrans = self.view.tipsRotateImage.transform
    
    if self.m_tipsPrefabLocalRot == nil then
        local tipsLocal = centerTrans:InverseTransformPoint(tipsTrans.position)
        self.m_tipsOffsetDist = math.sqrt(tipsLocal.x * tipsLocal.x + tipsLocal.y * tipsLocal.y)
        self.m_tipsPrefabLocalRot = tipsTrans.localRotation
    end
    
    local centerScreenPos = Unity.RectTransformUtility.WorldToScreenPoint(self.uiCamera, centerTrans.position)
    local dx = obstacleScreenPos.x - centerScreenPos.x
    local dy = obstacleScreenPos.y - centerScreenPos.y
    local sqrMag = dx * dx + dy * dy
    local dirX, dirY
    if sqrMag < 1e-8 then
        
        dirX, dirY = 0, 1
    else
        local invMag = 1 / math.sqrt(sqrMag)
        dirX = dx * invMag
        dirY = dy * invMag
    end
    local dist = self.m_tipsOffsetDist
    tipsTrans.position = centerTrans:TransformPoint(Vector3(dirX * dist, dirY * dist, 0))
    
    local angleDeg = -math.deg(math.atan(dirX, dirY))
    tipsTrans.localRotation = self.m_tipsPrefabLocalRot * Quaternion.Euler(0, 0, angleDeg)
end

SweetPieAimCtrl._HandleTime = HL.Method() << function(self)
    local maxDuration = GameInstance.dataManager.sweetPieConfig.flightMaxDuration
    local playerCtrl = GameInstance.playerController
    local sweetPieEntity = playerCtrl and playerCtrl:GetMoveControlTarget()
    local flyingDuration = 0
    if sweetPieEntity and sweetPieEntity.movementComponent then
        local moveComp = sweetPieEntity.movementComponent
        if moveComp.moveMode == CS.Beyond.Gameplay.Core.MovementComponent.MoveMode.SweetPieFlight then
            local pipeline = moveComp.pipeline
            if pipeline then
                flyingDuration = pipeline.flyingDuration
            end
        end
    end
    local remainTime = maxDuration - flyingDuration
    self.view.progress.fillAmount = remainTime / maxDuration

    self.view.progressBarNode:SetState(remainTime > Tables.globalConst.sweetPieCountDownRedTime and NORMAL_STATE or WARNING_STATE)
end

SweetPieAimCtrl._SetCloseToObstacle = HL.Method(HL.Any) << function(self, args)
    local isCloseToObstacle, obstaclePos = unpack(args)
    self.m_isCloseToObstacle = isCloseToObstacle
    self.m_obstaclePos = obstaclePos
    
    self.view.tipsNode.gameObject:SetActive(isCloseToObstacle)
    if isCloseToObstacle then
        self:_HandleCollision()
        AudioAdapter.PostEvent("Au_UI_Toast_SweetPieWarm")
    end
end

SweetPieAimCtrl._SetFlavor = HL.Method(HL.Any) << function(self, arg)
    local flavorId = unpack(arg)
    self:_SetFlavorInternal(flavorId:GetHashCode())
end

SweetPieAimCtrl._SetFlavorInternal = HL.Method(HL.Number) << function(self, flavor)
    local hasCfg, flavorInfo = Tables.sweetPieFlavorTable:TryGetValue(flavor)
    if not hasCfg then
        return
    end
    self.view.flavorNode.flavor.text = flavorInfo.name
    self.view.flavorNode.icon:LoadSprite(FLAVOR_SPRITE, flavorInfo.icon)
end

HL.Commit(SweetPieAimCtrl)
