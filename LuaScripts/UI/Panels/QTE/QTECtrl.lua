












































local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PHASE_ID = PhaseId.QTE


local ACTION_TYPE_TAP_ONCE = 0  
local ACTION_TYPE_HOLD = 1      
local ACTION_TYPE_MASH = 2      

local POINTER_BUTTON_LEFT = 0


local PROGRESS_STATE_ACTIVE  = 0
local PROGRESS_STATE_SUCCESS = 1
local PROGRESS_STATE_FAIL    = 2


local PHASE_WAITING   = "waiting"
local PHASE_IN_DELAY  = "inDelay"
local PHASE_HINT      = "hint"
local PHASE_ACTIVE    = "active"
local PHASE_OUT_DELAY = "outDelay"
local PHASE_DONE      = "done"




local RESULT_FEEDBACK_DELAY = 0.8

local DEFAULT_POOL_SIZE = 5

local ANIM_PRE_TO_NORMAL = "qte_pretonormal_in"
local ANIM_NORMAL = "qte_normal"
local ANIM_PRESS = "qte_press"
local ANIM_RING_HIGHLIGHT_IN = "qte_ringimage_click_in"
local ANIM_RING_HIGHLIGHT = "qte_ringimage_click"
local ANIM_RING_OUT = "qte_ringimage_out"
local ANIM_RESULT_SUCCESS = "qte_result_success"
local ANIM_RESULT_FAIL = "qte_result_fail"
local ANIM_MASH_ARROW_NORMAL = "qte_masharrow_loop"
local ANIM_MASH_ARROW_FAST = "qte_masharrow_loop_clickfast"
local ANIM_PANEL_IN = "qtepanel_in"
local ANIM_PANEL_OUT = "qtepanel_out"

local AUDIO_QTE_PROMPT = "Au_UI_Toast_QTE"
local AUDIO_QTE_HIGHLIGHT = {
    [ACTION_TYPE_TAP_ONCE] = "Au_UI_Toast_QTEHighlight",
    [ACTION_TYPE_HOLD] = "Au_UI_Toast_QTEHighlight_Hold",
    [ACTION_TYPE_MASH] = "Au_UI_Toast_QTEHighlight_Mash",
}
local AUDIO_QTE_SUCCESS = "Au_UI_Toast_QTEGreen"
local AUDIO_QTE_FAIL = "Au_UI_Toast_QTERed"
local AUDIO_QTE_PRESS = {
    [ACTION_TYPE_TAP_ONCE] = "Au_UI_Button_QTEPress",
    [ACTION_TYPE_HOLD] = "Au_UI_Button_QTEPressHold",
    [ACTION_TYPE_MASH] = "Au_UI_Button_QTEPressMash",
}

local DYNAMIC_RING_SCALE_START = 2
local DYNAMIC_RING_SCALE_END = 0.85
local DEFAULT_HOLD_SUCCESS_RATIO = 0.7
local HOLD_VISUAL_DECAY_SPEED_RATIO = 0.8


local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080
local SAFE_WIDTH = 1540   
local SAFE_HEIGHT = 868   

local UIConst = CS.Beyond.UI.UIConst



local function _CalcSafeAreaBounds()
    local canvasRect = UIManager.uiCanvasRect.rect
    local canvasW = canvasRect.width
    local canvasH = canvasRect.height

    local scale = UIConst.GetResolutionScale()
    local refW = BASE_WIDTH * scale
    local refH = BASE_HEIGHT * scale
    local safeW = SAFE_WIDTH * scale
    local safeH = SAFE_HEIGHT * scale

    local actualSafeW = canvasW >= refW and safeW or (canvasW * SAFE_WIDTH / BASE_WIDTH)
    local actualSafeH = canvasH >= refH and safeH or (canvasH * SAFE_HEIGHT / BASE_HEIGHT)

    local marginH = (canvasW - actualSafeW) * 0.5
    local marginV = (canvasH - actualSafeH) * 0.5

    local normLeft = marginH / canvasW
    local normRight = 1 - marginH / canvasW
    local normBottom = marginV / canvasH
    local normTop = 1 - marginV / canvasH

    return normLeft, normRight, normBottom, normTop, actualSafeW, actualSafeH, canvasW, canvasH
end


local function _BuildAnchorMap(normLeft, normRight, normBottom, normTop)
    local cx = 0.5
    local cy = 0.5
    return {
        [0] = Vector2(cx, cy),                    
        [1] = Vector2(normLeft, normTop),          
        [2] = Vector2(cx, normTop),                
        [3] = Vector2(normRight, normTop),         
        [4] = Vector2(normLeft, cy),               
        [5] = Vector2(normRight, cy),              
        [6] = Vector2(normLeft, normBottom),       
        [7] = Vector2(cx, normBottom),             
        [8] = Vector2(normRight, normBottom),      
    }
end

local InputManager = CS.Beyond.Input.InputManager
local KeyboardInput = CS.Beyond.Input.KeyboardInput
local GamepadInput = CS.Beyond.Input.GamepadInput

QTECtrl = HL.Class('QTECtrl', uiCtrl.UICtrl)

QTECtrl.m_config = HL.Field(HL.Any)              

QTECtrl.m_configId = HL.Field(HL.String) << ""    

QTECtrl.m_cellCache = HL.Field(HL.Any)            

QTECtrl.m_cellPool = HL.Field(HL.Table)            

QTECtrl.m_poolTotal = HL.Field(HL.Number) << 0     

QTECtrl.m_timelineFailed = HL.Field(HL.Table)      

QTECtrl.m_actionStates = HL.Field(HL.Table)       

QTECtrl.m_mainCor = HL.Field(HL.Any)              

QTECtrl.m_updateKey = HL.Field(HL.Number) << -1   

QTECtrl.m_prevElapsed = HL.Field(HL.Number) << 0   

QTECtrl.m_isFinished = HL.Field(HL.Boolean) << false

QTECtrl.m_allSuccess = HL.Field(HL.Boolean) << true

QTECtrl.m_totalActions = HL.Field(HL.Number) << 0

QTECtrl.m_completedActions = HL.Field(HL.Number) << 0

QTECtrl.m_anchorMap = HL.Field(HL.Table)            
QTECtrl.m_safeWidth = HL.Field(HL.Number) << 0      
QTECtrl.m_safeHeight = HL.Field(HL.Number) << 0     
QTECtrl.m_canvasWidth = HL.Field(HL.Number) << 0    
QTECtrl.m_canvasHeight = HL.Field(HL.Number) << 0   

QTECtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INPUT_DEVICE_TYPE_CHANGED] = '_OnInputDeviceTypeChanged',
    [MessageConst.ON_QTE_COMPLETE] = '_ForceClose',
}

QTECtrl.OnQTEStart = HL.StaticMethod() << function()
    PhaseManager:OpenPhase(PhaseId.QTE)
end

QTECtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local config = GameWorld.qteManager.currentConfig
    if not config then
        logger.error("[QTECtrl] No config from QTEManager")
        self:_FinishQTE(false)
        return
    end

    self.m_configId = config.configId
    self.m_config = config

    local normLeft, normRight, normBottom, normTop, safeW, safeH, canvasW, canvasH = _CalcSafeAreaBounds()
    self.m_anchorMap = _BuildAnchorMap(normLeft, normRight, normBottom, normTop)
    self.m_safeWidth = safeW
    self.m_safeHeight = safeH
    self.m_canvasWidth = canvasW
    self.m_canvasHeight = canvasH

    self:_SetupSafeAreaBorder(normLeft, normRight, normBottom, normTop)

    self:_SetupActionNodes()

    self.m_prevElapsed = 0
    self.m_mainCor = self:_StartCoroutine(function()
        self:_RunQTE()
    end)
end

QTECtrl.OnClose = HL.Override() << function(self)
    if self.m_updateKey >= 0 then
        self.m_updateKey = self:_RemoveUpdate(self.m_updateKey)
    end
    if self.m_mainCor then
        self.m_mainCor = self:_ClearCoroutine(self.m_mainCor)
    end
    if self.m_actionStates then
        for i = 1, #self.m_actionStates do
            local state = self.m_actionStates[i]
            if state.mashArrowNormalCor then
                state.mashArrowNormalCor = self:_ClearCoroutine(state.mashArrowNormalCor)
            end
        end
    end
    if self.m_cellCache then
        self.m_cellCache:OnClose()
    end
end

QTECtrl._SetupActionNodes = HL.Method() << function(self)
    local config = self.m_config
    local actionStates = {}
    local count = 0
    for ti = 0, config.timelines.Count - 1 do
        local timeline = config.timelines[ti]
        for ai = 0, timeline.actions.Count - 1 do
            count = count + 1
            local actionData = timeline.actions[ai]
            local holdSuccessDuration = actionData.holdSuccessDuration
            if actionData.actionType:GetHashCode() == ACTION_TYPE_HOLD
                and (holdSuccessDuration > 1 or holdSuccessDuration < 0) then
                holdSuccessDuration = DEFAULT_HOLD_SUCCESS_RATIO
            end
            actionStates[count] = {
                action = actionData,
                timelineIdx = ti,
                actionIdx = ai,
                phase = PHASE_WAITING,
                success = false,
                holdTime = 0,
                holdVisualProgress = 0,
                isHolding = false,
                ringOutPlayed = false,
                mashCount = 0,
                isPressAnimated = false,
                pressActionVersion = 0,
                resultAnimFinished = false,
                isActionHiding = false,
                feedbackPending = false,
                mashHasValidPress = false,
                mashArrowFastStarted = false,
                mashArrowNormalCor = nil,
                cell = nil,
                touchDown = false,
                touchHeld = false,
                touchUp = false,
                holdSuccessTime = actionData.actionTime * holdSuccessDuration,
                mashSuccessCount = actionData.mashSuccessCount,
                eventLogStartTime = 0,
                eventLogged = false,
            }
        end
    end
    self.m_actionStates = actionStates
    self.m_totalActions = count

    self.m_timelineFailed = {}
    self.m_poolTotal = DEFAULT_POOL_SIZE
    self.m_cellCache = UIUtils.genCellCache(self.view.actionTemplate)
    self.m_cellPool = {}
    self.m_cellCache:Refresh(DEFAULT_POOL_SIZE, function(cell, index)
        cell.gameObject:SetActive(false)
        self.m_cellPool[index] = cell
    end)
end


QTECtrl._SetupSafeAreaBorder = HL.Method(HL.Number, HL.Number, HL.Number, HL.Number) << function(self, normLeft, normRight, normBottom, normTop)
    local border = self.view.safeAreaBorder
    if not border then
        return
    end
    local rt = border.rectTransform
    rt.anchorMin = Vector2(normLeft, normBottom)
    rt.anchorMax = Vector2(normRight, normTop)
    rt.offsetMin = Vector2.zero
    rt.offsetMax = Vector2.zero
    border.gameObject:SetActive(GameWorld.qteManager.showSafeAreaBorder)
end


QTECtrl._PositionActionCell = HL.Method(HL.Any, HL.Any) << function(self, cell, action)
    local screenPosVal = action.screenPos:GetHashCode()
    local anchor = self.m_anchorMap[screenPosVal]
    if not anchor then
        logger.error("[QTECtrl] Invalid screenPos enum value: " .. tostring(screenPosVal))
        return
    end

    
    local offset = action.screenPosOffset
    local offsetScreenX = offset.x * (self.m_safeWidth / self.m_canvasWidth)
    local offsetScreenY = offset.y * (self.m_safeHeight / self.m_canvasHeight)

    local finalX = math.max(0, math.min(1, anchor.x + offsetScreenX))
    local finalY = math.max(0, math.min(1, anchor.y + offsetScreenY))

    local rt = cell.rectTransform
    rt.anchorMin = Vector2(finalX, finalY)
    rt.anchorMax = Vector2(finalX, finalY)
    rt.anchoredPosition = Vector2.zero
end


QTECtrl._InitActionCellDisplay = HL.Method(HL.Any, HL.Any, HL.Any) << function(self, cell, action, state)
    self:_AnimInitCell(cell, action)
    self:_SetupKeyDisplay(cell, action)
    self:_SetupTouchButton(cell, state)
end

QTECtrl._SetupTouchButton = HL.Method(HL.Any, HL.Any) << function(self, cell, state)
    local touchBtn = cell.touchButton
    local enablePointerInput = DeviceInfo.usingTouch or not DeviceInfo.usingController
    touchBtn.gameObject:SetActive(enablePointerInput)

    touchBtn.onPressStart:AddListener(function(eventData)
        if eventData and eventData.button:GetHashCode() ~= POINTER_BUTTON_LEFT then
            return
        end
        if state.phase ~= PHASE_ACTIVE then
            return
        end
        state.touchDown = true
        state.touchHeld = true
    end)
    touchBtn.onPressEnd:AddListener(function(eventData)
        if eventData and eventData.button:GetHashCode() ~= POINTER_BUTTON_LEFT then
            return
        end
        if not state.touchHeld then
            return
        end
        state.touchHeld = false
        state.touchUp = true
    end)
end

QTECtrl._CleanupTouchButton = HL.Method(HL.Any) << function(self, cell)
    local touchBtn = cell.touchButton
    touchBtn.onPressStart:RemoveAllListeners()
    touchBtn.onPressEnd:RemoveAllListeners()
    touchBtn.gameObject:SetActive(false)
end

QTECtrl._SetupKeyDisplay = HL.Method(HL.Any, HL.Any) << function(self, cell, action)
    local usingTouch = DeviceInfo.usingTouch
    local usingController = DeviceInfo.usingController

    if usingTouch then
        cell.keyIconPC.gameObject:SetActive(false)
        cell.keyIconGamepad.gameObject:SetActive(false)
    elseif usingController then
        cell.keyIconPC.gameObject:SetActive(false)
        local gpKey = action.gamepadBinding
        if gpKey then
            local keyName = InputManager.GetStringByGamepadKeyCode(gpKey)
            local spritePath = InputManager.GetGamepadKeyIconPath(keyName, false, true)
            if spritePath then
                cell.keyIconGamepad:LoadSpriteWithOutFormat(spritePath)
                cell.keyIconGamepad:SetNativeSize()
            end
            cell.keyIconGamepad.gameObject:SetActive(true)
        else
            cell.keyIconGamepad.gameObject:SetActive(false)
        end
    else
        cell.keyIconGamepad.gameObject:SetActive(false)
        local kbKey = action.keyBinding
        if kbKey then
            local kbInput = KeyboardInput()
            kbInput.key = kbKey
            local spritePath = InputManager.GetKeyIconPath(kbInput, false, true)
            if spritePath then
                cell.keyIconPC:LoadSpriteWithOutFormat(spritePath)
                cell.keyIconPC:SetNativeSize()
            end
            cell.keyIconPC.gameObject:SetActive(true)
        else
            cell.keyIconPC.gameObject:SetActive(false)
        end
    end

    cell.touchButton.gameObject:SetActive(usingTouch or not usingController)
end

QTECtrl._OnInputDeviceTypeChanged = HL.Method() << function(self)
    if self.m_isFinished then
        return
    end
    for i = 1, self.m_totalActions do
        local state = self.m_actionStates[i]
        if state.cell and state.phase ~= PHASE_DONE then
            self:_SetupKeyDisplay(state.cell, state.action)
        end
    end
end



QTECtrl._AcquireCell = HL.Method().Return(HL.Any) << function(self)
    local n = #self.m_cellPool
    if n > 0 then
        local cell = self.m_cellPool[n]
        self.m_cellPool[n] = nil
        return cell
    end
    local prevTotal = self.m_poolTotal
    self.m_poolTotal = prevTotal + 1
    local newCell
    self.m_cellCache:Refresh(self.m_poolTotal, function(cell, index)
        if index > prevTotal then
            cell.gameObject:SetActive(false)
            newCell = cell
        end
    end)
    return newCell
end

QTECtrl._ReleaseCell = HL.Method(HL.Any) << function(self, cell)
    self:_CleanupTouchButton(cell)
    cell.gameObject:SetActive(false)
    self.m_cellPool[#self.m_cellPool + 1] = cell
end






QTECtrl._AnimInitCell = HL.Method(HL.Any, HL.Any) << function(self, cell, action)
    self:_AnimHideInteraction(cell)
    cell.rectTransform.localScale = Vector3.one
    cell.canvasGroup.alpha = 1
end

local TypeStateHandle = {
    [ACTION_TYPE_TAP_ONCE] = "Tap",
    [ACTION_TYPE_HOLD]     = "Hold",
    [ACTION_TYPE_MASH]     = "Mash",
}

local SuccessStateHandle = {
    [ACTION_TYPE_TAP_ONCE] = "Success",
    [ACTION_TYPE_HOLD]     = "HoldSuccess",
    [ACTION_TYPE_MASH]     = "Success",
}

local FailStateHandle = {
    [ACTION_TYPE_TAP_ONCE] = "Fail",
    [ACTION_TYPE_HOLD]     = "HoldFail",
    [ACTION_TYPE_MASH]     = "Fail",
}

QTECtrl._SetDynamicRingScale = HL.Method(HL.Any, HL.Number) << function(self, dynamicRing, progress)
    local ratio = math.min(math.max(progress, 0), 1)
    local scale = DYNAMIC_RING_SCALE_START + (DYNAMIC_RING_SCALE_END - DYNAMIC_RING_SCALE_START) * ratio
    dynamicRing.localScale = Vector3(scale, scale, 1)
end


QTECtrl._AnimActionShow = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    self:_AnimHideInteraction(cell)
    cell.gameObject:SetActive(true)
    cell.preImage.gameObject:SetActive(true)
    cell.stateController:SetState(TypeStateHandle[state.action.actionType:GetHashCode()] .. "Pre")
    AudioAdapter.PostEvent(AUDIO_QTE_PROMPT)
    cell.animationWrapper:PlayWithTween(ANIM_PANEL_IN)
end


QTECtrl._AnimHintEnter = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    local actionType = state.action.actionType:GetHashCode()
    cell.stateController:SetState(TypeStateHandle[actionType])
    cell.dynamicRing.gameObject:SetActive(actionType ~= ACTION_TYPE_MASH)
    if actionType ~= ACTION_TYPE_MASH then
        self:_SetDynamicRingScale(cell.dynamicRing, 0)
    end
    cell.idleRing.gameObject:SetActive(true)
    cell.idleRingBg.gameObject:SetActive(true)
    cell.preImage.gameObject:SetActive(false)
    if actionType == ACTION_TYPE_MASH then
        self:_AnimMashAppear(state)
    end
    cell.animationWrapper:PlayWithTween(ANIM_PRE_TO_NORMAL)
end


QTECtrl._AnimHintExit = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    self:_SetDynamicRingScale(cell.dynamicRing, 1)
    cell.dynamicRing.gameObject:SetActive(false)
    cell.ringImage.gameObject:SetActive(true)
    local actionType = state.action.actionType:GetHashCode()
    AudioAdapter.PostEvent(AUDIO_QTE_HIGHLIGHT[actionType])
    cell.animationWrapper:PlayWithTween(ANIM_RING_HIGHLIGHT_IN, function()
        cell.animationWrapper:PlayWithTween(ANIM_RING_HIGHLIGHT)
    end)
end

QTECtrl._AnimRingOut = HL.Method(HL.Any) << function(self, state)
    if state.ringOutPlayed then
        return
    end
    state.ringOutPlayed = true
    local cell = state.cell
    local highlightAnim = cell.animationWrapper.curStateName
    if highlightAnim == ANIM_RING_HIGHLIGHT_IN or highlightAnim == ANIM_RING_HIGHLIGHT then
        
        cell.animationWrapper:ClearTween(false)
    end
    cell.ringImageAnimationWrapper:PlayWithTween(ANIM_RING_OUT)
end


QTECtrl._AnimActiveEnterHold = HL.Method(HL.Any) << function(self, cell)
    cell.holdRing.gameObject:SetActive(true)
    cell.holdRing.fillAmount = 0
end


QTECtrl._AnimMashAppear = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    cell.mashRing.gameObject:SetActive(true)
    cell.mashArrow.gameObject:SetActive(true)
    cell.mashArrowStateController:SetState("Normal")
    state.mashArrowFastStarted = false
    cell.mashArrowAnimationWrapper:PlayWithTween(ANIM_MASH_ARROW_NORMAL)
end


QTECtrl._AnimActiveEnterMash = HL.Method(HL.Any) << function(self, cell)
    cell.mashRingTrue.gameObject:SetActive(true)
end


QTECtrl._AnimPress = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, cell, onComplete)
    cell.main:PlayWithTween(ANIM_PRESS, onComplete)
end

QTECtrl._AnimNormal = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, cell, onComplete)
    cell.main:PlayWithTween(ANIM_NORMAL, onComplete)
end


QTECtrl._PlayTapMashPressNormalAction = HL.Method(HL.Any) << function(self, state)
    state.pressActionVersion = (state.pressActionVersion or 0) + 1
    local version = state.pressActionVersion
    state.isPressAnimated = true
    self:_AnimPress(state.cell, function()
        if state.pressActionVersion ~= version or not state.cell then
            return
        end
        state.isPressAnimated = false
        self:_AnimNormal(state.cell)
    end)
end


QTECtrl._AnimHoldProgress = HL.Method(HL.Any, HL.Number) << function(self, cell, holdRatio)
    cell.holdRing.fillAmount = math.min(holdRatio, 1)
end


QTECtrl._AnimMashPress = HL.Method(HL.Any, HL.Boolean) << function(self, state, isFirstPress)
    local cell = state.cell
    if isFirstPress then
        cell.mashArrowStateController:SetState("AfterClick")
        if state.mashArrowNormalCor then
            state.mashArrowNormalCor = self:_ClearCoroutine(state.mashArrowNormalCor)
        end
        state.mashArrowNormalCor = self:_StartCoroutine(function()
            coroutine.wait(cell.mashArrowAnimationWrapper:GetClipLength(ANIM_MASH_ARROW_NORMAL))
            state.mashArrowNormalCor = nil
            if state.phase == PHASE_ACTIVE and not state.mashArrowFastStarted then
                state.mashArrowFastStarted = true
                cell.mashArrowAnimationWrapper:PlayWithTween(ANIM_MASH_ARROW_FAST)
            end
        end)
    end
    cell.ringImage.gameObject:SetActive(true)
    cell.pressImage.gameObject:SetActive(false)
    cell.pressImage.gameObject:SetActive(true)
end


QTECtrl._AnimHideInteraction = HL.Method(HL.Any) << function(self, cell)
    cell.idleRing.gameObject:SetActive(false)
    cell.dynamicRing.gameObject:SetActive(false)
    cell.ringImage.gameObject:SetActive(false)
    cell.holdRing.gameObject:SetActive(false)
    cell.holdRing.fillAmount = 0
    cell.mashRing.gameObject:SetActive(false)
    cell.mashArrow.gameObject:SetActive(false)
    cell.mashRingTrue.gameObject:SetActive(false)
    cell.mashRingFalse.gameObject:SetActive(false)
    cell.pressImage.gameObject:SetActive(false)
    cell.resultRing.gameObject:SetActive(false)
    cell.successResult.gameObject:SetActive(false)
    cell.failureResult.gameObject:SetActive(false)
    cell.idleRingBg.gameObject:SetActive(false)
end



QTECtrl._AnimShowSuccess = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    local actionType = state.action.actionType:GetHashCode()
    cell.stateController:SetState(SuccessStateHandle[actionType])
    if actionType == ACTION_TYPE_HOLD then
        state.holdVisualProgress = 1
        self:_AnimHoldProgress(cell, 1)
    end
    cell.mashRingTrue.gameObject:SetActive(false)
    cell.pressImage.gameObject:SetActive(false)
    AudioAdapter.PostEvent(AUDIO_QTE_SUCCESS)
    cell.animationWrapper:PlayWithTween(ANIM_RESULT_SUCCESS, function()
        state.resultAnimFinished = true
        self:_TryAnimActionHide(state, GameWorld.qteManager.elapsedTime)
    end)
end


QTECtrl._AnimShowFail = HL.Method(HL.Any) << function(self, state)
    local cell = state.cell
    local actionType = state.action.actionType:GetHashCode()
    cell.stateController:SetState(FailStateHandle[actionType])
    cell.mashRingTrue.gameObject:SetActive(false)
    cell.pressImage.gameObject:SetActive(false)
    AudioAdapter.PostEvent(AUDIO_QTE_FAIL)
    cell.animationWrapper:PlayWithTween(ANIM_RESULT_FAIL, function()
        state.resultAnimFinished = true
        self:_TryAnimActionHide(state, GameWorld.qteManager.elapsedTime)
    end)
end


QTECtrl._AnimActionHide = HL.Method(HL.Any) << function(self, state)
    if state.phase ~= PHASE_OUT_DELAY or state.isActionHiding then
        return
    end
    state.isActionHiding = true
    local cell = state.cell
    cell.animationWrapper:PlayWithTween(ANIM_PANEL_OUT, function()
        cell.gameObject:SetActive(false)
        self:_ReleaseCell(cell)
        state.cell = nil
        state.phase = PHASE_DONE
        state.feedbackPending = false
        self.m_completedActions = self.m_completedActions + 1
    end)
end

QTECtrl._TryAnimActionHide = HL.Method(HL.Any, HL.Number) << function(self, state, elapsed)
    if state.phase ~= PHASE_OUT_DELAY or not state.resultAnimFinished or state.isActionHiding then
        return
    end
    local action = state.action
    local outEnd = action.startTime + action.inDelay + action.hintTime + action.actionTime + action.outDelay
    if self.m_isFinished or elapsed == -1 or elapsed >= outEnd then
        self:_AnimActionHide(state)
    end
end

QTECtrl._HasPendingActionFeedback = HL.Method().Return(HL.Boolean) << function(self)
    for i = 1, self.m_totalActions do
        if self.m_actionStates[i].feedbackPending then
            return true
        end
    end
    return false
end





QTECtrl._RunQTE = HL.Method() << function(self)
    self.m_updateKey = self:_StartUpdate(function()
        self:_OnUpdate()
    end)

    local totalDuration = self.m_config.totalDuration
    while not self.m_isFinished do
        coroutine.step()
        local elapsed = GameWorld.qteManager.elapsedTime
        if elapsed >= totalDuration or elapsed == -1 then
            self:_OnTimeout()
            break
        end
    end

    local feedbackStartTime = Time.realtimeSinceStartupAsDouble
    while Time.realtimeSinceStartupAsDouble - feedbackStartTime < RESULT_FEEDBACK_DELAY
        or self:_HasPendingActionFeedback() do
        coroutine.step()
    end
    self:_FinishQTE(self.m_allSuccess)
end

QTECtrl._OnUpdate = HL.Method() << function(self)
    if self.m_isFinished then
        return
    end

    local elapsed = GameWorld.qteManager.elapsedTime
    local dt = elapsed - self.m_prevElapsed
    self.m_prevElapsed = elapsed
    if dt < 0 then
        dt = 0
    end

    for i = 1, self.m_totalActions do
        local state = self.m_actionStates[i]
        if state.phase ~= PHASE_DONE then
            self:_UpdateActionState(state, elapsed, dt)
        end
    end
end













QTECtrl._UpdateActionState = HL.Method(HL.Any, HL.Number, HL.Number) << function(self, state, elapsed, dt)
    local action = state.action

    local actionStart = action.startTime
    local inEnd = actionStart + action.inDelay
    local hintEnd = inEnd + action.hintTime
    local activeEnd = hintEnd + action.actionTime

    if state.phase == PHASE_WAITING then
        if self.m_timelineFailed[state.timelineIdx] then
            state.phase = PHASE_DONE
            state.success = false
            self.m_allSuccess = false
            self.m_completedActions = self.m_completedActions + 1
            self:_ReportActionResult(state, false)
            return
        end
        if elapsed >= actionStart then
            state.eventLogStartTime = Time.realtimeSinceStartupAsDouble
            state.phase = PHASE_IN_DELAY
            state.cell = self:_AcquireCell()
            self:_PositionActionCell(state.cell, action)
            self:_InitActionCellDisplay(state.cell, action, state)
            self:_AnimActionShow(state)
        end

    elseif state.phase == PHASE_IN_DELAY then
        if elapsed >= inEnd then
            state.phase = PHASE_HINT
            self:_AnimHintEnter(state)
        end

    elseif state.phase == PHASE_HINT then
        local actionType = action.actionType:GetHashCode()
        if actionType ~= ACTION_TYPE_MASH then
            local hintProgress = action.hintTime > 0 and (elapsed - inEnd) / action.hintTime or 1
            self:_SetDynamicRingScale(state.cell.dynamicRing, hintProgress)
        end
        if elapsed >= hintEnd then
            state.phase = PHASE_ACTIVE
            self:_AnimHintExit(state)
            self:_OnEnterActive(state)
        end

    elseif state.phase == PHASE_ACTIVE then
        self:_UpdateActive(state, elapsed, dt)

        if not state.success then
            if elapsed >= activeEnd then
                self:_OnActionFail(state)
            elseif action.actionType:GetHashCode() == ACTION_TYPE_HOLD then
                local needed = state.holdSuccessTime - state.holdTime
                if needed > 0 and needed > activeEnd - elapsed then
                    self:_OnActionFail(state)
                end
            end
        end

    elseif state.phase == PHASE_OUT_DELAY then
        self:_UpdateReleasedPressAnimation(state)
        self:_TryAnimActionHide(state, elapsed)
    end
end

local ACTIVE_ENTER_ANIM = {
    [ACTION_TYPE_HOLD] = "_AnimActiveEnterHold",
    [ACTION_TYPE_MASH] = "_AnimActiveEnterMash",
}

QTECtrl._OnEnterActive = HL.Method(HL.Any) << function(self, state)
    local anim = ACTIVE_ENTER_ANIM[state.action.actionType:GetHashCode()]
    if anim then
        self[anim](self, state.cell)
    end
end


QTECtrl._UpdateHoldVisual = HL.Method(HL.Any, HL.Number) << function(self, state, dt)
    if state.success then return end
    local holdSuccessTime = state.holdSuccessTime
    local visualDelta = holdSuccessTime > 0 and dt / holdSuccessTime or 0
    if state.isHolding then
        state.holdVisualProgress = math.min(state.holdVisualProgress + visualDelta, 1)
    else
        state.holdVisualProgress = math.max(state.holdVisualProgress - visualDelta * HOLD_VISUAL_DECAY_SPEED_RATIO, 0)
    end
    self:_AnimHoldProgress(state.cell, state.holdVisualProgress)
end

local ACTIVE_UPDATERS = {
    [ACTION_TYPE_HOLD] = "_UpdateHoldVisual",
}

QTECtrl._UpdateActive = HL.Method(HL.Any, HL.Number, HL.Number) << function(self, state, elapsed, dt)
    self:_CheckInput(state, dt)
    local actionType = state.action.actionType:GetHashCode()
    local updater = ACTIVE_UPDATERS[actionType]
    if updater then
        self[updater](self, state, dt)
    end
    if not state.success and (actionType == ACTION_TYPE_HOLD or actionType == ACTION_TYPE_MASH) then
        self:_NotifyActionProgressActive(state)
    end
end





QTECtrl._PollKeys = HL.Method(HL.Any).Return(HL.Boolean, HL.Boolean, HL.Boolean) << function(self, state)
    local keyDown, keyHeld, keyUp = false, false, false
    local action = state.action

    local kbKey = action.keyBinding
    if kbKey then
        keyDown = keyDown or InputManagerInst:GetKeyDown(kbKey)
        keyHeld = keyHeld or InputManagerInst:GetKey(kbKey)
        keyUp   = keyUp   or InputManagerInst:GetKeyUp(kbKey)
    end
    local gpKey = action.gamepadBinding
    if gpKey then
        keyDown = keyDown or InputManagerInst:GetKeyDown(gpKey)
        keyHeld = keyHeld or InputManagerInst:GetKey(gpKey)
        keyUp   = keyUp   or InputManagerInst:GetKeyUp(gpKey)
    end

    if state.touchDown then
        keyDown = true
        state.touchDown = false
    end
    if state.touchHeld then
        keyHeld = true
    end
    if state.touchUp then
        keyUp = true
        state.touchUp = false
    end

    return keyDown, keyHeld, keyUp
end

QTECtrl._UpdatePressAnimation = HL.Method(HL.Any, HL.Boolean, HL.Boolean, HL.Opt(HL.Function)) << function(self, state, keyDown, keyUp, _)
    if keyDown and not state.isPressAnimated then
        state.isPressAnimated = true
        self:_AnimPress(state.cell)
    end
    if keyUp and state.isPressAnimated then
        state.isPressAnimated = false
        self:_AnimNormal(state.cell)
    end
end


QTECtrl._UpdateReleasedPressAnimation = HL.Method(HL.Any) << function(self, state)
    if state.action.actionType:GetHashCode() ~= ACTION_TYPE_HOLD
        or not state.isPressAnimated or not state.cell then
        return
    end
    local _, keyHeld, keyUp = self:_PollKeys(state)
    if keyUp and not keyHeld then
        state.isPressAnimated = false
        self:_AnimNormal(state.cell)
    end
end

QTECtrl._HandleTapInput = HL.Method(HL.Any, HL.Number, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, state, dt, keyDown, keyHeld, keyUp)
    if keyDown then
        self:_CompleteAction(state, true)
    end
end

QTECtrl._HandleHoldInput = HL.Method(HL.Any, HL.Number, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, state, dt, keyDown, keyHeld, keyUp)
    if keyDown or keyHeld then
        self:_AnimRingOut(state)
        state.isHolding = true
    end
    if keyUp then
        state.isHolding = false
    end
    if state.isHolding then
        state.holdTime = math.min(state.holdTime + dt, state.holdSuccessTime)
        if state.holdTime >= state.holdSuccessTime then
            self:_OnActionSuccess(state)
        end
    end
end

QTECtrl._HandleMashInput = HL.Method(HL.Any, HL.Number, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, state, dt, keyDown, keyHeld, keyUp)
    if keyDown then
        local nextMashCount = state.mashCount + 1
        local isFinalPress = nextMashCount >= state.mashSuccessCount
        state.mashCount = nextMashCount
        local isFirstPress = not state.mashHasValidPress
        state.mashHasValidPress = true
        self:_AnimMashPress(state, isFirstPress)
        self:_AnimRingOut(state)
        if isFinalPress then
            self:_CompleteAction(state, true)
        end
    end
end


local INPUT_HANDLERS = {
    [ACTION_TYPE_TAP_ONCE] = "_HandleTapInput",
    [ACTION_TYPE_HOLD]     = "_HandleHoldInput",
    [ACTION_TYPE_MASH]     = "_HandleMashInput",
}

QTECtrl._CheckInput = HL.Method(HL.Any, HL.Number) << function(self, state, dt)
    if state.success then
        return
    end
    if self.m_timelineFailed[state.timelineIdx] then
        return
    end
    local keyDown, keyHeld, keyUp = self:_PollKeys(state)
    local actionType = state.action.actionType:GetHashCode()
    if keyDown then
        AudioAdapter.PostEvent(AUDIO_QTE_PRESS[actionType])
    end
    if actionType == ACTION_TYPE_HOLD then
        self:_UpdatePressAnimation(state, keyDown, keyUp)
    elseif keyDown then
        self:_PlayTapMashPressNormalAction(state)
    end
    local handler = INPUT_HANDLERS[actionType]
    if handler then
        self[handler](self, state, dt, keyDown, keyHeld, keyUp)
    end
end





QTECtrl._CompleteAction = HL.Method(HL.Any, HL.Boolean) << function(self, state, success)
    if state.mashArrowNormalCor then
        state.mashArrowNormalCor = self:_ClearCoroutine(state.mashArrowNormalCor)
    end
    state.phase = PHASE_OUT_DELAY
    state.success = success
    state.resultAnimFinished = false
    state.feedbackPending = true
    state.isHolding = false
    local actionType = state.action.actionType:GetHashCode()
    if success then
        self:_AnimShowSuccess(state)
    else
        self:_AnimShowFail(state)
        self.m_allSuccess = false
        self.m_timelineFailed[state.timelineIdx] = true
    end
    state.ringOutPlayed = false
    self:_AnimRingOut(state)
    state.cell.mashRing.gameObject:SetActive(false)
    local progressState = success and PROGRESS_STATE_SUCCESS or PROGRESS_STATE_FAIL
    local progress = self:_CalcActionProgress(state, actionType)
    local count = actionType == ACTION_TYPE_MASH and state.mashCount or 0
    local timelineId = self.m_config.timelines[state.timelineIdx].timelineId
    local actionId = state.action.actionId
    GameWorld.qteManager:NotifyActionProgress(
        state.timelineIdx, state.actionIdx, actionType,
        progressState, progress, count, timelineId, actionId)
    self:_ReportActionResult(state, success)
end

QTECtrl._ReportActionResult = HL.Method(HL.Any, HL.Boolean) << function(self, state, success)
    if state.eventLogged then
        return
    end

    local costTime = 0
    if state.eventLogStartTime > 0 then
        local costSeconds = Time.realtimeSinceStartupAsDouble - state.eventLogStartTime
        costTime = math.floor(math.max(costSeconds, 0) * 1000)
    end
    EventLogManagerInst:GameEvent_ActingQTE(self.m_configId, state.action.actionId, success, costTime)
    state.eventLogged = true
end

QTECtrl._ReportPendingActionResults = HL.Method() << function(self)
    if not self.m_actionStates then
        return
    end
    for i = 1, self.m_totalActions do
        local state = self.m_actionStates[i]
        if not state.eventLogged then
            self:_ReportActionResult(state, false)
        end
    end
end

QTECtrl._CalcActionProgress = HL.Method(HL.Any, HL.Number).Return(HL.Number) << function(self, state, actionType)
    if actionType == ACTION_TYPE_HOLD then
        local holdSuccessTime = state.holdSuccessTime
        return holdSuccessTime > 0 and math.min(state.holdTime / holdSuccessTime, 1) or 0
    elseif actionType == ACTION_TYPE_MASH then
        return math.min(state.mashCount / state.mashSuccessCount, 1)
    end
    return state.success and 1 or 0
end

QTECtrl._NotifyActionProgressActive = HL.Method(HL.Any) << function(self, state)
    local actionType = state.action.actionType:GetHashCode()
    local progress = self:_CalcActionProgress(state, actionType)
    local count = actionType == ACTION_TYPE_MASH and state.mashCount or 0
    local timelineId = self.m_config.timelines[state.timelineIdx].timelineId
    local actionId = state.action.actionId
    GameWorld.qteManager:NotifyActionProgress(
        state.timelineIdx, state.actionIdx, actionType,
        PROGRESS_STATE_ACTIVE, progress, count, timelineId, actionId)
end

QTECtrl._OnActionSuccess = HL.Method(HL.Any) << function(self, state)
    self:_CompleteAction(state, true)
end

QTECtrl._OnActionFail = HL.Method(HL.Any) << function(self, state)
    self:_CompleteAction(state, false)
end

QTECtrl._OnTimeout = HL.Method() << function(self)
    for i = 1, self.m_totalActions do
        local state = self.m_actionStates[i]
        if state.phase == PHASE_OUT_DELAY then
            self:_TryAnimActionHide(state, GameWorld.qteManager.elapsedTime)
        elseif state.phase ~= PHASE_DONE and not state.success then
            if state.cell then
                self:_OnActionFail(state)
            else
                state.phase = PHASE_DONE
                state.success = false
                self.m_allSuccess = false
                self:_ReportActionResult(state, false)
            end
        end
    end
    self.m_isFinished = true
end






QTECtrl._FinishQTE = HL.Method(HL.Boolean) << function(self, success)
    self:_ReportPendingActionResults()
    GameWorld.qteManager:SetResult(success)

    local nextIndex = success and 0 or 1
    Notify(MessageConst.DIALOG_CHANGE_NEXT_INDEX, {
        phaseId = PHASE_ID,
        nextIndex = nextIndex,
    })
    PhaseManager:PopPhase(PHASE_ID)
end

QTECtrl._ForceClose = HL.Method(HL.Any) << function(self, args)
    self:_FinishQTE(false)
end



HL.Commit(QTECtrl)
