local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local CommonCache = require_ex("Common/Utils/CommonCache")
local PANEL_ID = PanelId.TyphoeaArcheryHud
local STANDARD_SCREEN_WIDTH = CS.Beyond.UI.UIConst.STANDARD_HORIZONTAL_RESOLUTION
local STANDARD_SCREEN_HEIGHT = CS.Beyond.UI.UIConst.STANDARD_VERTICAL_RESOLUTION

local ETyphoeaArcheryState = CS.Beyond.Gameplay.TyphoeaArcheryAbility.ETyphoeaArcheryState
local EChipLockingFrameStyle = CS.Beyond.Gameplay.EChipLockingFrameStyle
local LOCKING_ANIM_FORMAT = "typoeaarcheryhud_crosshair_%s_locking"

local ARROW_TYPE_SWITCH_LEFT_CHIP_ANIM_NAME = "typhoeaarcheryhud_switch_toleft"
local ARROW_TYPE_SWITCH_RIGHT_CHIP_ANIM_NAME = "typhoeaarcheryhud_switch_toright"


local LOCKING_FRAME_SWITCH_IN_CHIP_ANIM_NAME = "lockingframestyle1_arrowchange_in"
local LOCKING_FRAME_SWITCH_OUT_CHIP_ANIM_NAME = "lockingframestyle1_arrowchange_out"
local WARNING_AUTO_STOP_LOCKING_ANIM_NAME = "typoeaarcheryhud_lockingframe_autounlock_warning"
local LOCKING_START_ANIM_NAME = "typoeaarcheryhud_lockingframe_locking_start"
local LOCKING_END_ANIM_NAME = "typoeaarcheryhud_lockingframe_locking_end"
local LOCKING_LOOP_ANIM_FORMAT = "%s_loop"

local NONE_SUB_CHIP_ICON = "icon_typhoeaarchery_chip_null"

local MAIN_HUD_TOP_BTNS_FORBID_REASON = "TyphoeaArcheryHud"

local EChipLockingFrameStyle2PrefabName = {
    
    [EChipLockingFrameStyle.Style1] = "LockingFrameStyle1",
    
    [EChipLockingFrameStyle.Style2] = "LockingFrameStyle2",
}

local AUDIO_ARROW_CHARGE_START = {
    [EChipLockingFrameStyle.Style1] = "Au_UI_Event_ArrowChargeStart_large",
    [EChipLockingFrameStyle.Style2] = "Au_UI_Event_ArrowChargeStart_small",
}
local AUDIO_ARROW_CHARGED = {
    [EChipLockingFrameStyle.Style1] = "Au_UI_Event_ArrowCharged_large",
    [EChipLockingFrameStyle.Style2] = "Au_UI_Event_ArrowCharged_small",
}
TyphoeaArcheryHudCtrl = HL.Class('TyphoeaArcheryHudCtrl', uiCtrl.UICtrl)

TyphoeaArcheryHudCtrl.m_ability = HL.Field(HL.Any)

TyphoeaArcheryHudCtrl.m_chipLockingCapacityCellCache = HL.Field(HL.Forward("UIListCache"))

TyphoeaArcheryHudCtrl.m_mainChipCrosshairPool = HL.Field(HL.Any)

TyphoeaArcheryHudCtrl.m_subChipCrosshairPool = HL.Field(HL.Any)

TyphoeaArcheryHudCtrl.m_curChipCrosshairPool = HL.Field(HL.Any)

TyphoeaArcheryHudCtrl.m_target2Cell = HL.Field(HL.Table)

TyphoeaArcheryHudCtrl.m_playingOutCell2OwnPool = HL.Field(HL.Table)

TyphoeaArcheryHudCtrl.m_cell2OwnerPool = HL.Field(HL.Table)

TyphoeaArcheryHudCtrl.m_curChipLockingAnimStr = HL.Field(HL.String) << ""

TyphoeaArcheryHudCtrl.m_autoStopLockingAnimTimer = HL.Field(HL.Number) << 0

TyphoeaArcheryHudCtrl.m_lockingFrameWarningAnimLength = HL.Field(HL.Number) << 0

TyphoeaArcheryHudCtrl.m_hudTickId = HL.Field(HL.Number) << -1

TyphoeaArcheryHudCtrl.m_lockingFrameNodeCache = HL.Field(HL.Table)

TyphoeaArcheryHudCtrl.m_curLockingFrameNode = HL.Field(HL.Any)

TyphoeaArcheryHudCtrl.m_chargeStartAudioPlayingId = HL.Field(HL.Number) << 0




TyphoeaArcheryHudCtrl.m_isSwitchingChipAnim = HL.Field(HL.Boolean) << false





TyphoeaArcheryHudCtrl.m_controllerTriggerSettingHandlerId = HL.Field(HL.Number) << -1

TyphoeaArcheryHudCtrl.m_curTriggerEffectIndex = HL.Field(HL.Number) << -1







TyphoeaArcheryHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_TYPHOEA_ARCHERY_LOCKING_COUNT_CHANGE] = 'OnLockingCountChange',
    [MessageConst.ON_TYPHOEA_ARCHERY_TARGET_START_LOCKING] = "OnTargetStartLocking",
    [MessageConst.ON_TYPHOEA_ARCHERY_TARGET_UNLOCKED] = "OnTargetUnlocked",

    [MessageConst.ON_TYPHOEA_ARCHERY_CLOSE_PANEL] = "OnCloseTyphoeaArcheryHud",
    [MessageConst.ON_TYPHOEA_ARCHERY_CUR_CHIP_CHANGE] = "OnCurChipChange",

    [MessageConst.ON_TYPHOEA_ARCHERY_ENTER_STATE_LOCKING] = "OnEnterStateLocking",
    [MessageConst.ON_TYPHOEA_ARCHERY_EXIT_STATE_LOCKING] = "OnExitStateLocking",
    [MessageConst.ON_TYPHOEA_ARCHERY_ENTER_STATE_OPEN_SCOPE] = "OnEnterStateOpenScope",
    [MessageConst.ON_TYPHOEA_ARCHERY_ENTER_STATE_SHOOT_ARROW] = "OnEnterStateShootArrow",
    [MessageConst.ON_TYPHOEA_ARCHERY_EXIT_STATE_LOCKED] = "OnExitStateLocked",

    [MessageConst.ON_TYPHOEA_ARCHERY_LOCKING_TIME_OUT_CD_DONE] = "OnLockingTimeOutCDDone",

    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = "OnChangeInputDeviceTypeFinished",

    [MessageConst.ON_TYPHOEA_ARCHERY_DEBUG_CHANGE] = "OnDebugChange"
}

TyphoeaArcheryHudCtrl.OnOpenTyphoeaArcheryHud = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    if not GameUtil.mainCharacter or
            GameUtil.mainCharacter.customAbilityCom.curState ~= CS.Beyond.Gameplay.CustomAbilityType.TyphoeaArchery then
        return
    end
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl.animationWrapper:ClearTween()
    end

    
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { "TyphoeaArchery", true })
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, { true, "TyphoeaArchery" })
    UIManager:AutoOpen(PANEL_ID, args)
end


TyphoeaArcheryHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData()
    self:_InitUI()
    self:_InitView()
    self:_InitBind()
    self:_StartTick()
    self:_TryForbidMainHudTopBtns()
end





TyphoeaArcheryHudCtrl.OnClose = HL.Override() << function(self)
    if self.m_hudTickId > 0 then
        LuaUpdate:Remove(self.m_hudTickId)
    end
    self:_ClearAllCrosshairCells()
    self:_StopChargeStartAudio()
    
    self:_ClearControllerTriggerEffect()
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { "TyphoeaArchery", false })
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, { false, "TyphoeaArchery" })
    self:_ReleaseMainHudTopBtnsForbid()
end

TyphoeaArcheryHudCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    self:_StartCoroutine(function()
        
        coroutine.waitForRenderDone()
        LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.rightButtonLayout)
    end)
end

TyphoeaArcheryHudCtrl.OnLockingCountChange = HL.Method() << function(self)
    self:_UpdateLockingCapacity()
end

TyphoeaArcheryHudCtrl.OnCloseTyphoeaArcheryHud = HL.Method(HL.Table) << function(self, args)
    if self.m_isClosed then
        return
    end

    
    
    
    if not self:IsShow() then
        self:Close()
        return
    end

    
    if self.m_outAnimAsyncActionHelper and self.m_outAnimAsyncActionHelper:IsExecuting() then
        return
    end

    local needAnimOut = unpack(args)
    if needAnimOut then
        self:PlayAnimationOutAndClose()
    else
        self:Close()
    end
end

TyphoeaArcheryHudCtrl.OnCurChipChange = HL.Method() << function(self)
    self:_ClearAllCrosshairCells()
    self:_UpdateLockingFrame(false)
    self:_UpdateLockingCrosshair()
    self:_UpdateLockingCapacity()

    self:_UpdateMainAndSubChipV2(false)
end

TyphoeaArcheryHudCtrl.OnEnterStateOpenScope = HL.Method(HL.Table) << function(self, args)
    if self.m_ability.isInLockingTimeoutCd then
        return
    end
    local fromStateId = unpack(args)
    self:_ManuallyShowHudComponent(fromStateId ~= ETyphoeaArcheryState.Locking and fromStateId ~= ETyphoeaArcheryState.LockTarget)
    
    self:_SetControllerTriggerEffect(0)
end

TyphoeaArcheryHudCtrl.OnEnterStateLocking = HL.Method(HL.Table) << function(self, args)
    
    self.m_autoStopLockingAnimTimer = 0
    
    self.m_curTriggerEffectIndex = -1
    self:_ManuallyShowHudComponent(false)
    self:_PlayCurChipLockingAnim()
end

TyphoeaArcheryHudCtrl.OnExitStateLocking = HL.Method(HL.Table) << function(self, args)
    local toStateId = unpack(args)
    local toLockTarget = toStateId == ETyphoeaArcheryState.LockTarget

    
    if toLockTarget then
        return
    end

    
    self:_StopChargeStartAudio()
    self:_ClearAllCrosshairCells()
    self:_LockingFrameRecoverToNormal()
    self.m_curLockingFrameNode.effectImgTextBoom.gameObject:SetActive(false)
    local isTimeOut = self.m_ability.isInLockingTimeoutCd
    if isTimeOut then
        self.m_curLockingFrameNode.animationWrapper:SampleClipAtPercent(LOCKING_START_ANIM_NAME, 0)
        self:_ManuallyHideHudComponent()
    else
        self.m_curLockingFrameNode.animationWrapper:Play(LOCKING_END_ANIM_NAME)
    end
end

TyphoeaArcheryHudCtrl.OnExitStateLocked = HL.Method(HL.Table) << function(self, args)
    local toStateId = unpack(args)
    local toShootArrow = toStateId == ETyphoeaArcheryState.ShootArrow
    

    self:_ClearAllCrosshairCells()
    self:_LockingFrameRecoverToNormal()
    self.m_curLockingFrameNode.effectImgTextBoom.gameObject:SetActive(toShootArrow)
    local isTimeOut = self.m_ability.isInLockingTimeoutCd
    if toShootArrow or isTimeOut then
        self.m_curLockingFrameNode.animationWrapper:SampleClipAtPercent(LOCKING_START_ANIM_NAME, 0)
        self:_ManuallyHideHudComponent()
    else
        self.m_curLockingFrameNode.animationWrapper:Play(LOCKING_END_ANIM_NAME)
    end
end

TyphoeaArcheryHudCtrl.OnEnterStateShootArrow = HL.Method(HL.Table) << function(self, args)
    
    self:_ClearControllerTriggerEffect()
end

TyphoeaArcheryHudCtrl.OnLockingTimeOutCDDone = HL.Method(HL.Table) << function(self, args)
    local stateId = unpack(args)
    if stateId ~= ETyphoeaArcheryState.OpenScope then
        return
    end
    self:_ManuallyShowHudComponent(true)
    
    self:_SetControllerTriggerEffect(0)
end

TyphoeaArcheryHudCtrl._PlayCurChipLockingAnim = HL.Method() << function(self)
    
    local frameNode = self.m_curLockingFrameNode
    local loopAnimName = self:_GetCurChipLockingLoopAnimStr()
    local lockingFrameStyle = self.m_ability.curChip.lockingFrameStyle
    self:_PlayChargeStartAudio(lockingFrameStyle)
    frameNode.animationWrapper:Play(LOCKING_START_ANIM_NAME, function()
        if self.m_curLockingFrameNode ~= frameNode then
            return
        end
        self:_PlayChargedAudio(lockingFrameStyle)
        frameNode.animationWrapper:Play(loopAnimName)
    end)
end

TyphoeaArcheryHudCtrl._PlayChargeStartAudio = HL.Method(HL.Any) << function(self, lockingFrameStyle)
    self:_StopChargeStartAudio()
    local eventName = AUDIO_ARROW_CHARGE_START[lockingFrameStyle]
    if eventName then
        self.m_chargeStartAudioPlayingId = AudioAdapter.PostEvent(eventName)
    end
end

TyphoeaArcheryHudCtrl._PlayChargedAudio = HL.Method(HL.Any) << function(self, lockingFrameStyle)
    local eventName = AUDIO_ARROW_CHARGED[lockingFrameStyle]
    if eventName then
        AudioAdapter.PostEvent(eventName)
    end
end

TyphoeaArcheryHudCtrl._StopChargeStartAudio = HL.Method() << function(self)
    if self.m_chargeStartAudioPlayingId > 0 then
        AudioAdapter.StopByPlayingId(self.m_chargeStartAudioPlayingId)
        self.m_chargeStartAudioPlayingId = 0
    end
end
TyphoeaArcheryHudCtrl._GetCurChipLockingLoopAnimStr = HL.Method().Return(HL.String) << function(self)
    local curChipLockingFrameStyle = self.m_ability.curChip.lockingFrameStyle
    local styleStr = EChipLockingFrameStyle2PrefabName[curChipLockingFrameStyle]
    local loopAnimName = string.format(LOCKING_LOOP_ANIM_FORMAT, string.lower(styleStr))
    return loopAnimName
end

TyphoeaArcheryHudCtrl._ManuallyHideHudComponent = HL.Method() << function(self)
    self.m_curLockingFrameNode.animationWrapper:PlayOutAnimation(function()
        self.view.lockingFrameNode.gameObject:SetActive(false)
    end)
    self.view.lockingCapacityNode.gameObject:SetActive(false)
end

TyphoeaArcheryHudCtrl._ManuallyShowHudComponent = HL.Method(HL.Boolean) << function(self, playInAnim)
    self.view.lockingFrameNode.gameObject:SetActive(true)
    self.view.lockingCapacityNode.gameObject:SetActive(true)
    if playInAnim then
        self.m_curLockingFrameNode.animationWrapper:PlayInAnimation()
    end
end

TyphoeaArcheryHudCtrl._LockingFrameRecoverToNormal = HL.Method() << function(self)
    self.m_autoStopLockingAnimTimer = 0
    self.m_curLockingFrameNode.anima:SampleClipAtPercent(WARNING_AUTO_STOP_LOCKING_ANIM_NAME, 0)
    self.m_curLockingFrameNode.animationWrapper:SampleClipAtPercent(self:_GetCurChipLockingLoopAnimStr(), 0)
end



TyphoeaArcheryHudCtrl.OnTargetStartLocking = HL.Method(HL.Table) << function(self, args)
    local lockingTarget = unpack(args)
    if self.m_target2Cell[lockingTarget] then
        return
    end

    local cell = self:_GetCrosshairCellFromCurPool()
    self.m_target2Cell[lockingTarget] = cell
    self:_UpdateLockingCrosshairCell(cell, lockingTarget)
end

TyphoeaArcheryHudCtrl.OnTargetUnlocked = HL.Method(HL.Table) << function(self, args)
    local lockingTarget = unpack(args)
    local cell = self.m_target2Cell[lockingTarget]
    if not cell then
        return
    end

    self.m_target2Cell[lockingTarget] = nil
    local ownerPool = self.m_cell2OwnerPool[cell]
    self.m_playingOutCell2OwnPool[cell] = ownerPool

    cell.typhoeaArcheryCrosshairComp.uiAnimationWrapper:PlayOutAnimation(function()
        if not self.m_playingOutCell2OwnPool[cell] then
            return
        end
        local pool = self.m_playingOutCell2OwnPool[cell]
        self.m_playingOutCell2OwnPool[cell] = nil
        self:_CacheCrosshairCell(cell, pool)
    end)
end

TyphoeaArcheryHudCtrl._GetCrosshairCellFromCurPool = HL.Method().Return(HL.Any) << function(self)
    local pool = self.m_curChipCrosshairPool
    local cell = pool:Get()
    self.m_cell2OwnerPool[cell] = pool

    local parentRect = self.m_ability.curIsMain
            and self.view.mainChipCrosshairGroupNode
            or self.view.subChipCrosshairGroupNode
    cell.transform:SetParent(parentRect, false)
    cell.transform.localScale = Vector3.one
    cell.transform.localRotation = Quaternion.identity
    return cell
end

TyphoeaArcheryHudCtrl._CacheCrosshairCell = HL.Method(HL.Any, HL.Any) << function(self, cell, ownerPool)
    local pool = ownerPool or self.m_cell2OwnerPool[cell]
    self.m_cell2OwnerPool[cell] = nil
    pool:Cache(cell)
end

TyphoeaArcheryHudCtrl._ClearAllCrosshairCells = HL.Method() << function(self)
    for cell, ownerPool in pairs(self.m_playingOutCell2OwnPool) do
        cell.typhoeaArcheryCrosshairComp.uiAnimationWrapper:ClearTween(false)
        self.m_playingOutCell2OwnPool[cell] = nil
        self:_CacheCrosshairCell(cell, ownerPool)
    end
    self.m_playingOutCell2OwnPool = {}

    for target, cell in pairs(self.m_target2Cell) do
        self.m_target2Cell[target] = nil
        self:_CacheCrosshairCell(cell, self.m_cell2OwnerPool[cell])
    end
    self.m_target2Cell = {}
end

TyphoeaArcheryHudCtrl._UpdateLockingCrosshairCell = HL.Method(HL.Any, HL.Any) << function(self, cell, lockingTarget)
    local parentRect = self.m_ability.curIsMain and self.view.mainChipCrosshairGroupNode or self.view.subChipCrosshairGroupNode
    cell.typhoeaArcheryCrosshairComp:UpdateComp(lockingTarget, self.m_curChipLockingAnimStr, parentRect)
end





TyphoeaArcheryHudCtrl._SetControllerTriggerEffect = HL.Method(HL.Number) << function(self, csIndex)
    if not DeviceInfo.usingController or DeviceInfo.isMobile then
        return
    end
    if self.m_controllerTriggerSettingHandlerId > 0 then
        GameInstance.audioManager.gamePad.scePad:EndTriggerEffect(self.m_controllerTriggerSettingHandlerId)
        self.m_controllerTriggerSettingHandlerId = -1
    end
    self.m_controllerTriggerSettingHandlerId = GameInstance.audioManager.gamePad.scePad:SetTriggerEffect(self.view.psTriggerEffectCfg.commands[csIndex])
end

TyphoeaArcheryHudCtrl._ClearControllerTriggerEffect = HL.Method() << function(self)
    if self.m_controllerTriggerSettingHandlerId > 0 then
        GameInstance.audioManager.gamePad.scePad:EndTriggerEffect(self.m_controllerTriggerSettingHandlerId)
        self.m_controllerTriggerSettingHandlerId = -1
    end
end

TyphoeaArcheryHudCtrl._TriggerEffectTick = HL.Method(HL.Number) << function(self, deltaTime)
    if self.m_ability.lockingTimer <= 0 or not DeviceInfo.usingController or DeviceInfo.isMobile then
        return
    end
    local timer = self.m_ability.lockingTimer
    local commandCount = self.view.psTriggerEffectCfg.commands.Count
    local lockingTime = self.m_ability.curChip.lockingData.lockingTime
    if commandCount <= 0 or lockingTime <= 0 then
        return
    end
    local interval = lockingTime / commandCount
    local index = math.floor(timer / interval)
    if index >= commandCount then
        return
    end
    if index ~= self.m_curTriggerEffectIndex then
        self.m_curTriggerEffectIndex = index
        self:_SetControllerTriggerEffect(index)
    end
end


TyphoeaArcheryHudCtrl.OnChangeInputDeviceTypeFinished = HL.Method(HL.Table) << function(self, args)
    if not self:IsShow() then
        return
    end
    
    Notify(MessageConst.GENERAL_ABILITY_CHANGE_KEY_BINDING, { true, "TyphoeaArchery" })

    
    self:_ClearControllerTriggerEffect()
    self.m_curTriggerEffectIndex = -1
    if DeviceInfo.usingController and not DeviceInfo.isMobile then
        
        if self.m_ability:GetCurrentState() == ETyphoeaArcheryState.OpenScope and not self.m_ability.isInLockingTimeoutCd then
            self:_SetControllerTriggerEffect(0)
        end
    end
end



TyphoeaArcheryHudCtrl._InitData = HL.Method() << function(self)
    local typhoeaArcheryAbility = GameUtil.mainCharacter.customAbilityCom.curAbility
    self.m_ability = typhoeaArcheryAbility

    self.m_lockingFrameNodeCache = {}
    self.m_target2Cell = {}
    self.m_playingOutCell2OwnPool = {}
    self.m_cell2OwnerPool = {}
end

TyphoeaArcheryHudCtrl._InitUI = HL.Method() << function(self)
    local mainChip = self.m_ability.mainChip
    self.m_mainChipCrosshairPool = self:_CreateCrosshairPool(mainChip.aimingPrefabName, self.view.mainChipCrosshairGroupNode)

    local hasSubChip = self.m_ability.subChip ~= nil
    if hasSubChip then
        local subChip = self.m_ability.subChip
        self.m_subChipCrosshairPool = self:_CreateCrosshairPool(subChip.aimingPrefabName, self.view.subChipCrosshairGroupNode)
    end
    
    local show = self:_ShowMainAndSubChip()
    self.view.arrowTypeNode.gameObject:SetActive(show)

    self.m_chipLockingCapacityCellCache = UIUtils.genCellCache(self.view.lockingCapacityCell)

    self.view.joystick.onDrag:AddListener(function(eventData)
        self:_OnJoystickBtnDrag(eventData)
    end)

    self.view.joystickButton.onPressStart:AddListener(function()
        self:_OnJoystickBtnPressStart()
    end)

    self.view.joystickButton.onPressEnd:AddListener(function()
        self:_OnJoystickBtnPressEnd()
    end)

    self.view.arrowTypeSwitchBtn.onClick:AddListener(function()
        self.m_ability:SwitchCurChip()
    end)

    self.view.switchArrowMobileBtn.onClick:AddListener(function()
        self.m_ability:SwitchCurChip()
    end)

    self.view.closeBtn.onClick:AddListener(function()
        GameUtil.mainCharacter.customAbilityCom:EndAbility()
    end)
end

TyphoeaArcheryHudCtrl._CreateCrosshairPool = HL.Method(HL.String, Transform).Return(HL.Any) << function(self, crosshairPrefabName, parentRect)
    return CommonCache(
            function()
                local go = self:_CreateCrosshairGo(crosshairPrefabName, parentRect)
                return Utils.wrapLuaNode(go)
            end,
            function(cell)
                cell.gameObject:SetActive(true)
            end,
            function(cell)
                cell.gameObject:SetActive(false)
            end)
end

TyphoeaArcheryHudCtrl._CreateCrosshairGo = HL.Method(HL.String, Transform).Return(GameObject) << function(self, crosshairPrefabName, parentRect)
    local chipCrosshairPrefabPath = string.format(UIConst.UI_TYPHOEA_ARCHERY_CROSSHAIR_WIDGETS_PATH,
                                                  crosshairPrefabName)
    local chipCrosshairGoAsset = self:LoadGameObject(chipCrosshairPrefabPath)
    local chipCrosshairGo = CSUtils.CreateObject(chipCrosshairGoAsset, parentRect)
    chipCrosshairGo.name = crosshairPrefabName
    chipCrosshairGo.transform.localScale = Vector3.one
    chipCrosshairGo.transform.localPosition = Vector3.zero
    chipCrosshairGo.transform.localRotation = Quaternion.identity
    return chipCrosshairGo
end

TyphoeaArcheryHudCtrl._OnJoystickBtnPressStart = HL.Method() << function(self)
    if not DeviceInfo.usingKeyboard or not InputManager.cursorVisible then
        self.m_ability:OnInputPressed()
        self.m_ability:UseAbility()
    end
end

TyphoeaArcheryHudCtrl._OnJoystickBtnPressEnd = HL.Method() << function(self)
    
    if self.m_ability.isInputHeld then
        self.m_ability:OnInputReleased()
        self.m_ability:StopAbility()
    end
end

TyphoeaArcheryHudCtrl._InitView = HL.Method() << function(self)
    self:_UpdateLockingFrame(true)
    self:_UpdateLockingCrosshair()
    self:_UpdateLockingCapacity()
    self:_InitMainAndSubChip()
    self:_UpdateComponentState()
end

TyphoeaArcheryHudCtrl._InitBind = HL.Method() << function(self)
    
    if GameInstance.player.typhoeaArcherySystem:IsInShootingRange() then
        local shootingRangeSuffix = "_shooting_range"
        local switchChipAction = self.view.arrowTypeSwitchBtn.onClick.playerActionId .. shootingRangeSuffix
        self.view.arrowTypeSwitchBtn.onClick:ChangeBindingPlayerAction(switchChipAction)

        local pressAction = self.view.joystickButton.onPressStart.playerActionId .. shootingRangeSuffix
        local releaseAction = self.view.joystickButton.onPressEnd.playerActionId .. shootingRangeSuffix
        self.view.joystickButton.onPressStart:ChangeBindingPlayerAction(pressAction)
        self.view.joystickButton.onPressEnd:ChangeBindingPlayerAction(releaseAction)
    end
end

TyphoeaArcheryHudCtrl._UpdateComponentState = HL.Method() << function(self)
    local canSwitchChip = self.m_ability.subChip ~= nil
    self.view.main:SetState(canSwitchChip and "WithSubChip" or "WithoutSubChip")

    local canManuallyExitAbility = not GameInstance.player.typhoeaArcherySystem:IsInShootingRange()
    self.view.closeBtn.gameObject:SetActive(canManuallyExitAbility)
end


TyphoeaArcheryHudCtrl._TryForbidMainHudTopBtns = HL.Method() << function(self)
    if GameInstance.player.typhoeaArcherySystem:IsInShootingRange() then
        return
    end
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, MAIN_HUD_TOP_BTNS_FORBID_REASON, true)
end

TyphoeaArcheryHudCtrl._ReleaseMainHudTopBtnsForbid = HL.Method() << function(self)
    
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidMainHudTopBtns, MAIN_HUD_TOP_BTNS_FORBID_REASON, false)
end

TyphoeaArcheryHudCtrl._StartTick = HL.Method() << function(self)
    self.m_hudTickId = LuaUpdate:Add("TailTick", function(deltaTime)
        if self.m_isClosed then
            return
        end
        self:_CrosshairTick(deltaTime)
        self:_LockingFrameTick(deltaTime)
        self:_CompassTick(deltaTime)
        self:_TriggerEffectTick(deltaTime)
    end)
end

TyphoeaArcheryHudCtrl._CrosshairTick = HL.Method(HL.Number) << function(self, deltaTime)
    for target, cell in pairs(self.m_target2Cell) do
        self:_UpdateLockingCrosshairCell(cell, target)
    end
end

TyphoeaArcheryHudCtrl._LockingFrameTick = HL.Method(HL.Number) << function(self, deltaTime)
    if self.m_ability.autoStopLockingAnimLoopTimeRatio <= 0 then
        return
    end

    self.m_autoStopLockingAnimTimer = self.m_autoStopLockingAnimTimer +
            deltaTime * self.m_ability.autoStopLockingAnimLoopTimeRatio
    self.m_curLockingFrameNode.anima:SampleClipAtPercent(WARNING_AUTO_STOP_LOCKING_ANIM_NAME,
                                                        self.m_autoStopLockingAnimTimer % self.m_lockingFrameWarningAnimLength)
end

TyphoeaArcheryHudCtrl._CompassTick = HL.Method(HL.Number) << function(self, deltaTime)
    local cam = CameraManager.mainCamera
    if not cam or not self.m_curLockingFrameNode then
        return
    end

    
    local yaw = cam.transform.eulerAngles.y
    if yaw > 180 then
        yaw = yaw - 360
    end

    
    local rot = Vector3(0, 0, -yaw)
    self.m_curLockingFrameNode.directionIndicatorTop.localEulerAngles = rot
    self.m_curLockingFrameNode.directionIndicatorBottom.localEulerAngles = rot
end

TyphoeaArcheryHudCtrl._UpdateLockingFrame = HL.Method(HL.Boolean) << function(self, isInit)
    local lockingFrameNode = self:_GetLockingFrameNode()
    if self.m_curLockingFrameNode == lockingFrameNode then
        self.m_curLockingFrameNode.animationWrapper:Play(LOCKING_FRAME_SWITCH_IN_CHIP_ANIM_NAME)
        
        return
    end

    
    
    local lockingRange = self.m_ability.curChip.lockingData.lockingRange
    local screenCenterX = Screen.width / 2
    local screenCenterY = Screen.height / 2
    local ratio = Screen.height / STANDARD_SCREEN_HEIGHT
    
    
    
    local topLockingRange = lockingRange[0]
    local topScreenPos = Vector2(screenCenterX + topLockingRange.center.x * ratio,
                                 screenCenterY + topLockingRange.center.y * ratio - topLockingRange.radius * ratio)
    local topRectPos = UIUtils.screenPointToUI(topScreenPos, self.uiCamera, lockingFrameNode.rectTransform)
    lockingFrameNode.bottom.anchoredPosition = topRectPos

    local bottomLockingRange = lockingRange[1]
    local bottomScreenPos = Vector2(screenCenterX + bottomLockingRange.center.x * ratio,
                                    screenCenterY + bottomLockingRange.center.y * ratio + bottomLockingRange.radius * ratio)
    local bottomRectPos = UIUtils.screenPointToUI(bottomScreenPos, self.uiCamera, lockingFrameNode.rectTransform)
    lockingFrameNode.top.anchoredPosition = bottomRectPos

    
    local leftLockingRange = lockingRange[2]
    local leftScreenPos = Vector2(screenCenterX + leftLockingRange.center.x * ratio + leftLockingRange.radius * ratio,
                                  screenCenterY + leftLockingRange.center.y * ratio)
    local leftRectPos = UIUtils.screenPointToUI(leftScreenPos, self.uiCamera, lockingFrameNode.rectTransform)
    lockingFrameNode.right.anchoredPosition = leftRectPos

    local rightLockingRange = lockingRange[3]
    local rightScreenPos = Vector2(screenCenterX + rightLockingRange.center.x * ratio - rightLockingRange.radius * ratio,
                                   screenCenterY + rightLockingRange.center.y * ratio)
    local rightRectPos = UIUtils.screenPointToUI(rightScreenPos, self.uiCamera, lockingFrameNode.rectTransform)
    lockingFrameNode.left.anchoredPosition = rightRectPos

    
    
    

    local preFrameNode = self.m_curLockingFrameNode
    self.m_curLockingFrameNode = lockingFrameNode
    self.m_lockingFrameWarningAnimLength = lockingFrameNode.anima:GetClipLength(WARNING_AUTO_STOP_LOCKING_ANIM_NAME)
    self:_SyncLockingCapacityNodePosition()
    if preFrameNode then
        self.m_isSwitchingChipAnim = true
        lockingFrameNode.gameObject:SetActive(false)
        preFrameNode.animationWrapper:Play(LOCKING_FRAME_SWITCH_OUT_CHIP_ANIM_NAME ,function()
            preFrameNode.gameObject:SetActive(false)
            lockingFrameNode.gameObject:SetActive(true)
            lockingFrameNode.animationWrapper:Play(LOCKING_FRAME_SWITCH_IN_CHIP_ANIM_NAME, function()
                self:_OnSwitchingChipAnimFinish()
            end)
        end)
    end

    self:_UpdateDebugView()
end

TyphoeaArcheryHudCtrl._SyncLockingCapacityNodePosition = HL.Method() << function(self)
    local lockingFrameNode = self.m_curLockingFrameNode
    local follower = lockingFrameNode and lockingFrameNode.capacityNodeFollower
    if not follower then
        return
    end
    self.view.lockingCapacityNode.position = follower.position
end

TyphoeaArcheryHudCtrl._OnSwitchingChipAnimFinish = HL.Method() << function(self)
    self.m_isSwitchingChipAnim = false
    if self.m_ability.lockingTimer > 0 then
        self:_PlayCurChipLockingAnim()
    end
end

TyphoeaArcheryHudCtrl._GetLockingFrameNode = HL.Method().Return(HL.Table) << function(self)
    local curChipLockingFrameStyle = self.m_ability.curChip.lockingFrameStyle
    local curChipId = self.m_ability.curChip.chipId
    local cacheNode = self.m_lockingFrameNodeCache[curChipId]
    if cacheNode then
        return cacheNode
    end

    local prefabName = EChipLockingFrameStyle2PrefabName[curChipLockingFrameStyle]
    local lockingFramePrefabPath = string.format(UIConst.UI_TYPHOEA_ARCHERY_LOCKINGFRAME_WIDGETS_PATH, prefabName)
    local locingFrameGoAsset = self:LoadGameObject(lockingFramePrefabPath)
    local lockingFrameGo = CSUtils.CreateObject(locingFrameGoAsset, self.view.lockingFrameNode)
    lockingFrameGo.name = prefabName
    lockingFrameGo.transform.localScale = Vector3.one
    lockingFrameGo.transform.localPosition = Vector3.zero
    lockingFrameGo.transform.localRotation = Quaternion.identity

    cacheNode = Utils.wrapLuaNode(lockingFrameGo)
    self.m_lockingFrameNodeCache[curChipId] = cacheNode
    return cacheNode
end

TyphoeaArcheryHudCtrl._UpdateLockingCrosshair = HL.Method() << function(self)
    if self.m_ability.curIsMain then
        self.m_curChipCrosshairPool = self.m_mainChipCrosshairPool
    else
        self.m_curChipCrosshairPool = self.m_subChipCrosshairPool
    end
    self.view.mainChipCrosshairGroupNode.gameObject:SetActive(self.m_ability.curIsMain)
    self.view.subChipCrosshairGroupNode.gameObject:SetActive(not self.m_ability.curIsMain)

    local typeName = self:_GetCrosshairTypeNameByPrefabName(self.m_ability.curChip.aimingPrefabName)
    self.m_curChipLockingAnimStr = string.format(LOCKING_ANIM_FORMAT, string.lowerFirst(typeName))
end

TyphoeaArcheryHudCtrl._UpdateLockingCapacity = HL.Method() << function(self)
    local lockingCount = self.m_ability.lockingCount
    local lockingCapacity = self.m_ability.lockingCapacity
    local typeName = self:_GetCrosshairTypeNameByPrefabName(self.m_ability.curChip.aimingPrefabName)

    self.m_chipLockingCapacityCellCache:Refresh(lockingCapacity, function(cell, luaIndex)
        cell.arrowState:SetState(typeName)
        cell.arrowState:SetState(luaIndex <= lockingCount and "Locking" or "Normal")
    end)
end

TyphoeaArcheryHudCtrl._GetCrosshairTypeNameByPrefabName = HL.Method(HL.String).Return(HL.String) << function(self,
                                                                                                             rawStr)
    local startIndex = string.len("Crosshair")
    local typeName = string.sub(rawStr, startIndex + 1)
    return typeName
end

TyphoeaArcheryHudCtrl._InitMainAndSubChip = HL.Method() << function(self)
    if not self:_ShowMainAndSubChip() then
        return
    end

    local curChipIcon
    local pendingChipIcon
    if self.m_ability.curIsMain then
        curChipIcon = self.m_ability.curChip.iconName
        local subChip = self.m_ability.subChip
        pendingChipIcon = subChip and subChip.iconName or NONE_SUB_CHIP_ICON
    else
        
        curChipIcon = self.m_ability.subChip.iconName
        pendingChipIcon = self.m_ability.mainChip.iconName
    end

    self.view.currentEquipArrowImg:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, curChipIcon)
    self.view.spareArrowImg:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, pendingChipIcon)

    self:_UpdateMainAndSubChipV2(true)
end

TyphoeaArcheryHudCtrl._UpdateMainAndSubChipV2 = HL.Method(HL.Boolean) << function(self, ignoreAnim)
    if not self:_ShowMainAndSubChip() then
        return
    end

    local curChipName
    local curIsMain = self.m_ability.curIsMain
    if curIsMain then
        curChipName = self.m_ability.curChip.nameKey:GetText()
    else
        
        curChipName = self.m_ability.subChip.nameKey:GetText()
    end

    self.view.arrowTypeTxt.text = curChipName

    if ignoreAnim then
        return
    end

    local animName = curIsMain and ARROW_TYPE_SWITCH_LEFT_CHIP_ANIM_NAME or ARROW_TYPE_SWITCH_RIGHT_CHIP_ANIM_NAME
    self.view.arrowTypeSwitchBtn.interactable = false
    self.view.switchArrowMobileBtn.interactable = false
    self.view.arrowTypeNode:Play(animName, function()
        self.view.arrowTypeSwitchBtn.interactable = true
        self.view.switchArrowMobileBtn.interactable = true
    end)
end



TyphoeaArcheryHudCtrl._UpdateMainAndSubChip = HL.Method() << function(self)
    if not self:_ShowMainAndSubChip() then
        return
    end

    local curChipIcon
    local pendingChipIcon
    local curChipName
    if self.m_ability.curIsMain then
        curChipIcon = self.m_ability.curChip.iconName
        curChipName = self.m_ability.curChip.nameKey:GetText()
        local subChip = self.m_ability.subChip
        pendingChipIcon = subChip and subChip.iconName or NONE_SUB_CHIP_ICON
    else
        
        curChipIcon = self.m_ability.subChip.iconName
        pendingChipIcon = self.m_ability.mainChip.iconName
        curChipName = self.m_ability.subChip.nameKey:GetText()
    end

    self.view.currentEquipArrowImg:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, curChipIcon)
    self.view.effectCurrentEquipArrowImg:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, curChipIcon)
    self.view.spareArrowImg:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, pendingChipIcon)

    self.view.arrowTypeTxt.text = curChipName
end

TyphoeaArcheryHudCtrl._ShowMainAndSubChip = HL.Method().Return(HL.Boolean) << function(self)
    
    return Utils.isSystemUnlocked(GEnums.UnlockSystemType.ShootingRange)
end

TyphoeaArcheryHudCtrl._OnJoystickBtnDrag = HL.Method(HL.Userdata) << function(self, eventData)
    local delta = eventData.delta
    local cameraInputScaleX = 1
    local cameraInputScaleY = 1
    delta.x = cameraInputScaleX * delta.x
    delta.y = cameraInputScaleY * delta.y
    Notify(MessageConst.ON_DRAG_TYPHOEA_ARCHERY_JOYSTICK, delta)
end



TyphoeaArcheryHudCtrl._UpdateDebugView = HL.Method() << function(self)
    local succ, result = ClientDataManagerInst:GetBool("DebugLockingArea", true)
    local showDebug = succ and result and BEYOND_DEBUG_COMMAND
    self.view.debug.gameObject:SetActive(showDebug)
    if not showDebug then
        return
    end

    
    
    local lockingRange = self.m_ability.curChip.lockingData.lockingRange
    local screenCenterX = Screen.width / 2
    local screenCenterY = Screen.height / 2
    local ratio = Screen.height / STANDARD_SCREEN_HEIGHT
    
    
    
    local topLockingRange = lockingRange[0]
    local topScreenPos = Vector2(screenCenterX + topLockingRange.center.x * ratio,
                                 screenCenterY + topLockingRange.center.y * ratio)
    local topRectPos = UIUtils.screenPointToUI(topScreenPos, self.uiCamera, self.view.debug.rectTransform)
    local topEdgeScreenPos = Vector2(screenCenterX + topLockingRange.center.x * ratio,
                                     screenCenterY + topLockingRange.center.y * ratio + topLockingRange.radius * ratio)
    local topEdgeRectPos = UIUtils.screenPointToUI(topEdgeScreenPos, self.uiCamera, self.view.debug.rectTransform)
    local topBottomRatio = 2 * math.abs(topEdgeRectPos.y - topRectPos.y)
    self.view.debug.lockingTop.anchoredPosition = topRectPos
    self.view.debug.lockingTop.sizeDelta = Vector2(topBottomRatio, topBottomRatio)

    local bottomLockingRange = lockingRange[1]
    local bottomScreenPos = Vector2(screenCenterX + bottomLockingRange.center.x * ratio,
                                    screenCenterY + bottomLockingRange.center.y * ratio)
    local bottomRectPos = UIUtils.screenPointToUI(bottomScreenPos, self.uiCamera, self.view.debug.rectTransform)
    self.view.debug.lockingBottom.anchoredPosition = bottomRectPos
    self.view.debug.lockingBottom.sizeDelta = Vector2(topBottomRatio, topBottomRatio)

    
    local leftLockingRange = lockingRange[2]
    local leftScreenPos = Vector2(screenCenterX + leftLockingRange.center.x * ratio,
                                  screenCenterY + leftLockingRange.center.y * ratio)
    local leftRectPos = UIUtils.screenPointToUI(leftScreenPos, self.uiCamera, self.view.debug.rectTransform)
    local leftEdgeScreenPos = Vector2(screenCenterX + leftLockingRange.center.x * ratio - leftLockingRange.radius * ratio,
                                      screenCenterY + leftLockingRange.center.y * ratio)
    local leftEdgeRectPos = UIUtils.screenPointToUI(leftEdgeScreenPos, self.uiCamera, self.view.debug.rectTransform)
    local leftRightRatio = 2 * math.abs(leftEdgeRectPos.x - leftRectPos.x)
    self.view.debug.lockingLeft.anchoredPosition = leftRectPos
    self.view.debug.lockingLeft.sizeDelta = Vector2(leftRightRatio, leftRightRatio)

    local rightLockingRange = lockingRange[3]
    local rightScreenPos = Vector2(screenCenterX + rightLockingRange.center.x * ratio,
                                   screenCenterY + rightLockingRange.center.y * ratio)
    local rightRectPos = UIUtils.screenPointToUI(rightScreenPos, self.uiCamera, self.view.debug.rectTransform)
    self.view.debug.lockingRight.anchoredPosition = rightRectPos
    self.view.debug.lockingRight.sizeDelta = Vector2(leftRightRatio, leftRightRatio)
end

TyphoeaArcheryHudCtrl.OnDebugChange = HL.Method() << function(self)
    local succ, result = ClientDataManagerInst:GetBool("DebugLockingArea", true)
    self.view.debug.gameObject:SetActive(succ and result)
    self:_UpdateDebugView()
end




HL.Commit(TyphoeaArcheryHudCtrl)
