local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.Painter

local Screen = Screen
local RectTransformUtility = Unity.RectTransformUtility

local MAX_DRAW_STEP = 75
local BRUSH_AUDIO_SILENCE_DELAY = 0.05
local BRUSH_LOOP_AUDIO_EVENT = "Au_UI_Event_InkPainting_BrushLoop"
local BRUSH_TURN_AUDIO_EVENT = "Au_UI_Event_InkPainting_BrushTurn"
local MOUSE_SPEED_RTPC = "au_mouse_speed"
local MOUSE_X_POSITION_RTPC = "au_mouse_x_position"


PainterCtrl = HL.Class('PainterCtrl', uiCtrl.UICtrl)







PainterCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

PainterCtrl.m_isActivating = HL.Field(HL.Boolean) << false

PainterCtrl.m_scrollComp = HL.Field(CS.Beyond.Gameplay.Core.PaintingScrollComponent)
PainterCtrl.m_inkPPComp = HL.Field(CS.HG.Rendering.Runtime.VFXPPInkWash)

PainterCtrl.m_cameraCtrl = HL.Field(CS.Beyond.Gameplay.View.PainterCameraController)

PainterCtrl.m_inputTick = HL.Field(HL.Function)
PainterCtrl.m_pressedArrowBtn = HL.Field(CS.Beyond.UI.UIButton)
PainterCtrl.m_arrowMoveDirection = HL.Field(Vector2)

PainterCtrl.m_isDrawing = HL.Field(HL.Boolean) << false
PainterCtrl.m_drawingTouchId = HL.Field(HL.Int) << -1
PainterCtrl.m_forceRadioHandler = HL.Field(HL.Userdata)





















PainterCtrl.m_allGroups = HL.Field(HL.Table) << nil
PainterCtrl.m_allExtras = HL.Field(HL.Table) << nil
PainterCtrl.m_allPoints = HL.Field(HL.Table) << nil

PainterCtrl.splashRadius = HL.Field(HL.Number) << 2
PainterCtrl.m_cameraPos = HL.Field(Vector3)
PainterCtrl.m_lastDrawScreenPos = HL.Field(HL.Any)
PainterCtrl.m_brushLoopAudioPlayingId = HL.Field(HL.Number) << 0
PainterCtrl.m_brushAudioTickId = HL.Field(HL.Number) << -1
PainterCtrl.m_lastBrushTime = HL.Field(HL.Number) << 0
PainterCtrl.m_lastBrushScreenPos = HL.Field(Vector2)
PainterCtrl.m_lastBrushVelocity = HL.Field(Vector2)


PainterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    local comp = arg[1]
    self.m_allGroups = {}
    self.m_allExtras = {}
    self.m_allPoints = {}

    self.m_cameraCtrl = CameraManager:LoadPersistentController("PainterCamera")
    if comp then
        self.m_scrollComp = comp
        self.m_inkPPComp = comp.vfxInkWashMono
        self.m_cameraCtrl:SetupConfig(comp:GetCameraControlConfig(), true)

        self.splashRadius = comp:GetSplashRadius()*0.7
        self.m_inkPPComp:SetParamsOnce(comp:GetSplashRadius(), comp:GetSplashRadius(), self.view.config.RESET_WAIT_TIME)
        self.m_inkPPComp:SetMode(false)
        local groupNum = comp:GetPaintingObjCount()
        logger.info("[Painter]groupnum:" .. groupNum)
        for i = 0, groupNum-1 do
            
            local data = comp:GetPaintingObjData(i)
            local groupData = {
                groupId = i,
                points = {},
                activated = data.isMapVarActivated,
                data = data,
            }
            self.m_allGroups[groupData.groupId] = groupData
            for j, spotData in cs_pairs(data.inkSpotDataList) do
                local pointId = spotData.pointId
                local pointData = {
                    id = pointId,
                    index = j,
                    worldPos = spotData.worldPos,
                    groupId = groupData.groupId,
                    nextId = -1,
                    scanned = false,
                    invalid = not spotData.isInteractable
                }
                self.m_allPoints[pointId] = pointData
                table.insert(groupData.points, pointData)
            end
            logger.info(string.format("[Painter]组[%d]共有[%d]个点", i, #groupData.points))
        end
        local microNum = comp:GetExtraObjCount()
        for i = 0, microNum-1 do
            
            local data = comp:GetExtraObjData(i)
            local _, pointEntity = data:TryGetEntity()
            local pointId = data.entityPtr.logicId
            local pointData = {
                id = pointId,
                index = -1,
                worldPos = data.position,
                groupId = -1,
                microId = i,
                nextId = -1,
                scanned = data.isScanned,
                invalid = false
            }
            self.m_allPoints[pointId] = pointData
            local extraData = {
                microId = i,
                point = pointData,
                activated = data.isScanned,
            }
            self.m_allExtras[i] = extraData
        end
    end

    self.view.closeBtn.onClick:AddListener(function()
        self:_OnClickCloseBtn()
    end)
    self.view.resetBtn.onClick:AddListener(function()
        self:_OnClickResetBtn()
    end)
    self.view.stopBtn.onClick:AddListener(function()
        self:_OnClickCloseBtn()
    end)
    self.view.sceneViewNode.onPress:AddListener(function(eventData)
        if self.m_isDrawing then
            return
        end
        if DeviceInfo.usingTouch then
            local touchId = InputManager.GetTouchId(eventData)
            if touchId < 0 then
                return
            end
            self.m_drawingTouchId = touchId
        end
        InputManagerInst:SetMouseSpeedOverride(0.7)
        self:_StartDrawing(eventData.position)
    end)
    self.view.sceneViewNode.onRelease:AddListener(function(eventData)
        if DeviceInfo.usingTouch and InputManager.GetTouchId(eventData) ~= self.m_drawingTouchId then
            return
        end
        InputManagerInst:ClearMouseSpeedOverride()
        self:_StopDrawing(eventData.position)
    end)

    self:_InitDirectionArrows()

    self.m_inputTick = function()
        self:_RefreshDirectionArrows()
        if DeviceInfo.usingController then
            
            local rightStickValue = InputManagerInst:GetGamepadStickValue(false)
            self:_DoMoveCamera(rightStickValue * self.view.config.CAM_MOVE_SPEED * Time.deltaTime)

            
            local stickValue = InputManagerInst:GetGamepadStickValue(true)
            local moveDelta = stickValue * self.view.config.CURSOR_SPEED * Time.deltaTime
            local targetPosition = self.view.cursorNode.anchoredPosition + moveDelta
            local cameraMoveDelta = Vector2(0, 0)

            if targetPosition.x < 0 and moveDelta.x < 0 then
                cameraMoveDelta.x = stickValue.x
                targetPosition.x = 0
            elseif targetPosition.x > self.view.cursorArea.rect.width and moveDelta.x > 0 then
                cameraMoveDelta.x = stickValue.x
                targetPosition.x = self.view.cursorArea.rect.width
            end
            if targetPosition.y < 0 and moveDelta.y < 0 then
                cameraMoveDelta.y = stickValue.y
                targetPosition.y = 0
            elseif targetPosition.y > self.view.cursorArea.rect.height and moveDelta.y > 0 then
                cameraMoveDelta.y = stickValue.y
                targetPosition.y = self.view.cursorArea.rect.height
            end

            self.view.cursorNode.anchoredPosition = targetPosition
            InputManager.SetMousePos(self.uiCamera:WorldToScreenPoint(self.view.cursorNode.position):XY())
            if cameraMoveDelta.x ~= 0 or cameraMoveDelta.y ~= 0 then
                self:_DoMoveCamera(cameraMoveDelta * self.view.config.CAM_MOVE_SPEED * Time.deltaTime)
            end
            if self.m_isDrawing then
                local pos = InputManager.mousePosition:XY()
                self:_UpdateBrushAudioParams(pos)
                self:_DrawOnPosition(pos, false)
            end
        else
            if DeviceInfo.usingKeyboard then
                
                if self.view.joystick.jsValue.x ~= 0 or self.view.joystick.jsValue.y ~= 0 then
                    local spd = self.view.config.CAM_MOVE_SPEED
                    self:_DoMoveCamera(self.view.joystick.jsValue*spd*Time.deltaTime)
                end
            end
            if self.m_isDrawing then
                self:_DrawMoveMouse()
            end
        end
        self:_UpdateArrowButtonMovement()
    end
    self:BindInputPlayerAction("painter_press_splash", function()
        if DeviceInfo.usingTouch then
            return
        end
        self:_StartDrawing(InputManager.mousePosition:XY())
    end, self.view.inputGroup.groupId)
    self:BindInputPlayerAction("painter_release_splash", function()
        if DeviceInfo.usingTouch then
            return
        end
        self:_StopDrawing(InputManager.mousePosition:XY())
    end, self.view.inputGroup.groupId)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.m_cameraPos = CameraManager.mainCamera.transform.position
    self.m_forceRadioHandler = GameWorld.narrativeManager:RequestForcePlayRadio()
    self:_RefreshMouseIcon(false)

    self:_ReportPoiInteractive("enter")
end


PainterCtrl._ReportPoiInteractive = HL.Method(HL.String) << function(self, action)
    local parametersStatus = {}
    
    for _, group in pairs(self.m_allGroups) do
        
        local groupData = group
        local paramsStatusList = {}
        for _, point in ipairs(groupData.points) do
            table.insert(paramsStatusList, string.format("params_%d:%d", point.index, point.scanned and 1 or 0))
        end
        table.insert(parametersStatus, {
            entity_id = groupData.data.mapVarKey or "",
            type = 2,
            status = groupData.activated and 1 or 0,
            params_status = table.concat(paramsStatusList, ","),
        })
    end
    
    for _, extra in pairs(self.m_allExtras) do
        
        local extraData = extra
        table.insert(parametersStatus, {
            entity_id = tostring(extraData.point.id),
            type = 1,
            status = extraData.activated and 1 or 0,
        })
    end
    
    local entityId = self.m_scrollComp and tostring(self.m_scrollComp.entityLid) or ""
    EventLogManagerInst:GameEvent_PaintingPoiInteractive(action, entityId, parametersStatus)
end

PainterCtrl.OnShow = HL.Override() << function(self)
    if DeviceInfo.usingController then
        local screenCenter = Vector2(Screen.width * 0.5, Screen.height * 0.5)
        local centerPos = UIUtils.screenPointToUI(screenCenter, self.uiCamera, self.view.cursorArea)
        self.view.cursorNode.anchoredPosition = centerPos
        InputManagerInst:SetCustomControllerMouse(self.view.cursorNode.transform, self.uiCamera)
    else
        self.view.cursorNode.gameObject:SetActive(false)
    end

    if InputManagerInst.afterCheckInput then
        InputManagerInst.afterCheckInput = InputManagerInst.afterCheckInput + self.m_inputTick
    else
        InputManagerInst.afterCheckInput = self.m_inputTick
    end
end

PainterCtrl.OnHide = HL.Override() << function(self)
    self.m_pressedArrowBtn = nil
    self:_StopDrawing()
    InputManagerInst:ClearMouseSpeedOverride()
    if InputManagerInst.afterCheckInput then
        InputManagerInst.afterCheckInput = InputManagerInst.afterCheckInput - self.m_inputTick
    end
    InputManagerInst:SetCustomControllerMouse(nil, nil)
    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "Painter",
        type = UIConst.MOUSE_ICON_HINT.Default,
    })
end

PainterCtrl._OnPlayAnimationOut = HL.Override() << function(self)
    self.m_pressedArrowBtn = nil
    self:_StopDrawing()
    InputManagerInst:ClearMouseSpeedOverride()
    if InputManagerInst.afterCheckInput then
        InputManagerInst.afterCheckInput = InputManagerInst.afterCheckInput - self.m_inputTick
    end
    CameraManager:RemoveCameraController(self.m_cameraCtrl, false)
    self.m_cameraCtrl = nil
    self.m_scrollComp:SetExitCameraOverride(CameraManager.mainCamera.transform.position, CameraManager.mainCamera.transform.rotation)
end

PainterCtrl.OnClose = HL.Override() << function(self)
    self.m_pressedArrowBtn = nil
    self:_StopDrawing()
    InputManagerInst:ClearMouseSpeedOverride()
    self:_ReportPoiInteractive("exit")
    if InputManagerInst.afterCheckInput then
        InputManagerInst.afterCheckInput = InputManagerInst.afterCheckInput - self.m_inputTick
    end
    InputManagerInst:SetCustomControllerMouse(nil, nil)
    Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
        name = "Painter",
        type = UIConst.MOUSE_ICON_HINT.Default,
    })
    if self.m_cameraCtrl then
        CameraManager:RemoveCameraController(self.m_cameraCtrl)
        self.m_cameraCtrl = nil
    end
    self.m_forceRadioHandler:RemoveTag()
end

PainterCtrl._OnClickCloseBtn = HL.Method() << function(self)
    InputManagerInst:ToggleGroup(self.view.inputGroup.groupId, false)
    self.m_scrollComp:LeavePaintingScroll()
    
    
end

PainterCtrl._OnClickResetBtn = HL.Method() << function(self)
    self.view.luaPanel:BlockAllInput()
    self.m_scrollComp:ClearPaintingScroll()
    for id, group in pairs(self.m_allGroups) do
        
        local groupData = group
        if groupData.activated then
            groupData.activated = false
        end
    end
    for id, point in pairs(self.m_allPoints) do
        
        local pointData = point
        if pointData.groupId >= 0 then
            pointData.scanned = false
        end
    end
    self:_StartCoroutine(function()
        self.view.cleanShader.gameObject:SetActive(true)
        coroutine.wait(self.view.config.RESET_WAIT_TIME)
        self.view.cleanShader.gameObject:SetActive(false)
        self.view.luaPanel:RecoverAllInput()
    end)
end

PainterCtrl._StartDrawing = HL.Method(Vector2) << function(self, pos)
    if self.m_isDrawing then
        return
    end
    self.m_isDrawing = true
    self.view.resetBtn.interactable = false
    self.view.stopBtn.interactable = false
    self.m_lastDrawScreenPos = nil
    self:_StartBrushAudio(pos)
    self:_RefreshMouseIcon(true)
end

PainterCtrl._StopDrawing = HL.Method(HL.Opt(Vector2)) << function(self, pos)
    if self.m_isDrawing and pos then
        self:_UpdateBrushAudioParams(pos)
        pos = self:_ClampDrawPos(pos)
        self:_DrawOnPosition(pos, false)
    end
    self:_StopBrushAudio()
    self.m_isDrawing = false
    self.m_drawingTouchId = -1
    self.view.resetBtn.interactable = true
    self.view.stopBtn.interactable = true
    self.m_lastDrawScreenPos = nil
    self:_RefreshMouseIcon(false)
end

PainterCtrl._ClampDrawPos = HL.Method(Vector2).Return(Vector2) << function(self, pos)
    if self.m_lastDrawScreenPos then
        local diff = pos - self.m_lastDrawScreenPos
        local dist = diff.magnitude
        
        local maxDrawStep = MAX_DRAW_STEP * Screen.height / 1080
        if dist > maxDrawStep then
            pos = self.m_lastDrawScreenPos + diff * (maxDrawStep / dist)
        end
    end
    self.m_lastDrawScreenPos = pos
    return pos
end

PainterCtrl._DrawMoveMouse = HL.Method() << function(self)
    local pos
    if DeviceInfo.usingTouch then
        local found
        found, pos = InputManager.GetPressPosByTouchId(self.m_drawingTouchId)
        if not found then
            InputManagerInst:ClearMouseSpeedOverride()
            self:_StopDrawing()
            return
        end
    else
        pos = InputManager.mousePosition:XY()
    end
    local outScreen = false
    if pos.x < 0 or pos.x > Screen.width or pos.y < 0 or pos.y > Screen.height then
        outScreen = true
    end

    local uiPos, inside = UIUtils.screenPointToUI(pos, self.uiCamera, self.view.cursorArea)
    inside = self.view.cursorArea.rect:Contains(uiPos)
    if not inside then
        local moveDelta = Vector2(0, 0)
        if uiPos.x < 0 then
            moveDelta.x = -1
        elseif uiPos.x > self.view.cursorArea.rect.width then
            moveDelta.x = 1
        end
        if uiPos.y < 0 then
            moveDelta.y = -1
        elseif uiPos.y > self.view.cursorArea.rect.height then
            moveDelta.y = 1
        end
        self:_DoMoveCamera(moveDelta*Time.deltaTime*self.view.config.CAM_MOVE_SPEED_DRAG)
    end
    if not outScreen then
        self:_UpdateBrushAudioParams(pos)
        pos = self:_ClampDrawPos(pos)
        self:_DrawOnPosition(pos, false)
    end
end

PainterCtrl._RefreshMouseIcon = HL.Method(HL.Boolean) << function(self, isPress)
    if DeviceInfo.usingKeyboard then
        Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
            name = "Painter",
            type = isPress and UIConst.MOUSE_ICON_HINT.PainterLinkPress or UIConst.MOUSE_ICON_HINT.PainterLink,
            hotspotPos =  isPress and Vector2(14, 56) or Vector2(14, 63),
        })
    elseif DeviceInfo.usingController then
        self.view.cursorNodeState:SetState(isPress and "LinkPress" or "Link")
    end
end

PainterCtrl._InitDirectionArrows = HL.Method() << function(self)
    self.m_pressedArrowBtn = nil
    local horizontalLimit = self.m_cameraCtrl.horizontalRotationLimit
    local verticalLimit = self.m_cameraCtrl.verticalRotationLimit
    local canMoveHorizontal = horizontalLimit.x < horizontalLimit.y
    local canMoveVertical = verticalLimit.x < verticalLimit.y
    self:_InitDirectionArrowBtn(self.view.leftArrowBtn, Vector2(-1, 0), canMoveHorizontal)
    self:_InitDirectionArrowBtn(self.view.rightArrowBtn, Vector2(1, 0), canMoveHorizontal)
    self:_InitDirectionArrowBtn(self.view.upArrowBtn, Vector2(0, 1), canMoveVertical)
    self:_InitDirectionArrowBtn(self.view.downArrowBtn, Vector2(0, -1), canMoveVertical)
    self:_RefreshDirectionArrows()
end

PainterCtrl._InitDirectionArrowBtn = HL.Method(CS.Beyond.UI.UIButton, Vector2, HL.Boolean) << function(self, button, direction, canMove)
    
    button.gameObject:SetActive(canMove)
    button.onPressStart:AddListener(function(eventData)
        if eventData and eventData.button ~= CS.UnityEngine.EventSystems.PointerEventData.InputButton.Left then
            return
        end
        if not button.interactable or not button.groupEnabled then
            return
        end
        self.m_pressedArrowBtn = button
        self.m_arrowMoveDirection = direction
        self:_UpdateArrowButtonMovement()
    end)
    button.onPressEnd:AddListener(function()
        if self.m_pressedArrowBtn == button then
            self.m_pressedArrowBtn = nil
        end
    end)
end

PainterCtrl._UpdateArrowButtonMovement = HL.Method() << function(self)
    local button = self.m_pressedArrowBtn
    if not button then
        return
    end
    if not button.interactable or not button.groupEnabled or not button.gameObject.activeInHierarchy then
        self.m_pressedArrowBtn = nil
        return
    end
    self:_DoMoveCamera(self.m_arrowMoveDirection * self.view.config.CAM_MOVE_SPEED * Time.deltaTime)
end

PainterCtrl._RefreshDirectionArrows = HL.Method() << function(self)
    if not self.m_cameraCtrl then
        return
    end
    local canLeft, canRight, canUp, canDown = self.m_cameraCtrl:GetRotationLimits()
    self.view.leftArrowBtn.interactable = canLeft
    self.view.rightArrowBtn.interactable = canRight
    self.view.upArrowBtn.interactable = canUp
    self.view.downArrowBtn.interactable = canDown
end

PainterCtrl._DoMoveCamera = HL.Method(Vector2) << function(self, delta)
    if not self.m_cameraCtrl then
        return
    end
    self.m_cameraCtrl:Move(delta)
end

PainterCtrl._StartBrushAudio = HL.Method(Vector2) << function(self, screenPos)
    if self.m_brushLoopAudioPlayingId ~= 0 then
        return
    end

    self.m_lastBrushTime = Time.unscaledTime
    self.m_lastBrushScreenPos = screenPos
    self.m_lastBrushVelocity = nil

    AudioAdapter.PostEvent("Au_UI_Button_InkPaint")

    AudioAdapter.SetRtpc(MOUSE_SPEED_RTPC, 0)
    local normalizedX = math.max(0, math.min(1, screenPos.x / Screen.width))
    AudioAdapter.SetRtpc(MOUSE_X_POSITION_RTPC, normalizedX)

    self.m_brushAudioTickId = LuaUpdate:Add("Tick", function()
        if Time.unscaledTime - self.m_lastBrushTime > BRUSH_AUDIO_SILENCE_DELAY then
            AudioAdapter.SetRtpc(MOUSE_SPEED_RTPC, 0)
        end
    end)
    self.m_brushLoopAudioPlayingId = AudioAdapter.PostEvent(BRUSH_LOOP_AUDIO_EVENT)
end

PainterCtrl._StopBrushAudio = HL.Method() << function(self)
    if self.m_brushAudioTickId >= 0 then
        self.m_brushAudioTickId = LuaUpdate:Remove(self.m_brushAudioTickId)
    end
    if self.m_brushLoopAudioPlayingId ~= 0 then
        AudioAdapter.StopByPlayingId(self.m_brushLoopAudioPlayingId, 2000)
        self.m_brushLoopAudioPlayingId = 0
    end

    self.m_lastBrushTime = 0
    self.m_lastBrushScreenPos = nil
    self.m_lastBrushVelocity = nil
    AudioAdapter.SetRtpc(MOUSE_SPEED_RTPC, 0)
end

PainterCtrl._UpdateBrushAudioParams = HL.Method(Vector2) << function(self, screenPos)
    if self.m_brushLoopAudioPlayingId == 0 or not self.m_lastBrushScreenPos then
        return
    end

    local currentTime = Time.unscaledTime
    local velocity = Vector2.zero
    local deltaTime = currentTime - self.m_lastBrushTime
    if deltaTime > 0 then
        velocity = (screenPos - self.m_lastBrushScreenPos) / deltaTime
    end
    self.m_lastBrushTime = currentTime
    self.m_lastBrushScreenPos = screenPos

    local speed = velocity.magnitude
    AudioAdapter.SetRtpc(MOUSE_SPEED_RTPC, speed)

    local turnSpeedThreshold = self.view.config.BRUSH_TURN_SPEED_THRESHOLD
    if speed > turnSpeedThreshold and self.m_lastBrushVelocity then
        local lastSpeed = self.m_lastBrushVelocity.magnitude
        if lastSpeed > turnSpeedThreshold then
            local dot = Vector2.Dot(self.m_lastBrushVelocity / lastSpeed, velocity / speed)
            local dotThreshold = math.cos(math.rad(self.view.config.BRUSH_TURN_ANGLE_THRESHOLD))
            if dot < dotThreshold then
                AudioAdapter.PostEvent(BRUSH_TURN_AUDIO_EVENT)
            end
        end
    end
    self.m_lastBrushVelocity = velocity

    local normalizedX = math.max(0, math.min(1, screenPos.x / Screen.width))
    AudioAdapter.SetRtpc(MOUSE_X_POSITION_RTPC, normalizedX)
end

PainterCtrl._DrawOnPosition = HL.Method(Vector2, HL.Boolean) << function(self, pos, isClick)
    self:_SplashOnPosition(pos, isClick)
end

PainterCtrl._SplashOnPosition = HL.Method(Vector2, HL.Boolean) << function(self, pos, isClick)
    self.m_inkPPComp:SetInstantBleeding(not isClick)
    local ray = CameraManager.mainCamera:ScreenPointToRay(Vector3(pos.x, pos.y, 0))
    self.m_inkPPComp:RequestNewInkDraw(ray.direction)

    for id, data in pairs(self.m_allPoints) do
        
        local pointData = data
        if not pointData.scanned and not pointData.invalid then
            if self:_IsDrawingCovered(ray.direction, pointData.worldPos, self.splashRadius) then
                pointData.scanned = true
                if pointData.groupId < 0 then
                    
                    self.m_scrollComp:OnExtraObjScanned(pointData.microId)
                    self:_TryActivateMicro(pointData.microId)
                else
                     
                    local groupData = self.m_allGroups[pointData.groupId]
                    self.m_scrollComp:OnInkSpotDiscovered(pointData.groupId, pointData.index)
                    logger.info(string.format("[Painter]发现点：groupId=%d, pointIndex=%d", pointData.groupId, pointData.index))
                    local activated = groupData.data.isMapVarActivated
                    if activated and not groupData.activated then
                        self:_TryActivateGroup(pointData.groupId)
                    end
                end
            end
        end
    end

    
    
    
    
end


PainterCtrl._TryActivateGroup = HL.Method(HL.Int) << function(self, groupId)
    local groupData = self.m_allGroups[groupId]
    self:_StopDrawing()
    self.m_isActivating = true
    self.view.luaPanel:BlockAllInput()
    self:_StartCoroutine(function()
        groupData.activated = true
        coroutine.wait(2)
        self.m_isActivating = false
        self.view.luaPanel:RecoverAllInput()
    end)
end

PainterCtrl._TryActivateMicro = HL.Method(HL.Int) << function(self, microId)
    if not self.m_allExtras[microId] then
        return
    end
    self.m_allExtras[microId].activated = true
end

PainterCtrl._IsDrawingCovered = HL.Method(Vector3, Vector3, HL.Number).Return(HL.Boolean)
    << function(self, screenRay, worldPos, radius)
    local camPos = self.m_cameraPos
    local dirToTarget = (worldPos - camPos).normalized
    local cosAngle = Vector3.Dot(dirToTarget, screenRay)
    local cosThreshold = 10 / math.sqrt(100 + radius * radius)
    return cosAngle >= cosThreshold
end

HL.Commit(PainterCtrl)
