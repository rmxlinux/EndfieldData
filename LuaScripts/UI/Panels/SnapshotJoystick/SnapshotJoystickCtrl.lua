local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SnapshotJoystick





























SnapshotJoystickCtrl = HL.Class('SnapshotJoystickCtrl', uiCtrl.UICtrl)







SnapshotJoystickCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SNAPSHOT_PLAYER_MOVE_MODE] = 'SetPlayerMoveMode',
    [MessageConst.SNAPSHOT_CAMERA_MOVE_MODE] = 'SetCameraMoveMode',
    [MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK] = 'OnForbidJoystick',
    [MessageConst.SNAPSHOT_INNER_FORBID_PLAYER_MOVE] = 'OnInnerForbidPlayerMove',
    
    [MessageConst.FORBID_SYSTEM_CHANGED] = 'OnForbidSystemChanged',
    [MessageConst.ON_GAME_SETTING_CHANGED] = 'OnGameSettingChanged',
}


local snapshotSystem = GameInstance.player.snapshotSystem
local forbidToastColdDownTime = 3




SnapshotJoystickCtrl.m_updateKey = HL.Field(HL.Number) << -1


SnapshotJoystickCtrl.m_isPlayerMoveMode = HL.Field(HL.Boolean) << true


SnapshotJoystickCtrl.m_cameraCtrl = HL.Field(HL.Forward("SnapshotCameraCtrl"))


SnapshotJoystickCtrl.m_snapshotForbidJoystickKeys = HL.Field(HL.Table)


SnapshotJoystickCtrl.m_isForbidFromSnapshot = HL.Field(HL.Boolean) << false


SnapshotJoystickCtrl.m_isForbidPlayerMoveFromSnapshot = HL.Field(HL.Boolean) << false


SnapshotJoystickCtrl.m_forbidToastColdDown = HL.Field(HL.Number) << 0









SnapshotJoystickCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_cameraCtrl = arg
    self.m_isPlayerMoveMode = not snapshotSystem.isCameraMoveMode
    
    self.view.joystick.onTouchStart:AddListener(function()
        self:_onJoystickTouchStart()
    end)
    self.view.joystick.onTouchEnd:AddListener(function()
        self:_onJoystickTouchEnd()
    end)
    self.view.joystick.onToggleAutoSprint:AddListener(function(isAutoSprint)
        self:_ToggleAutoSprint(isAutoSprint)
    end)
    
    self.view.sprintBtn.onPressStart:AddListener(function()
        self:_OnPressSprint()
    end)
    self.view.sprintBtn.onPressEnd:AddListener(function()
        self:_OnReleaseSprint()
    end)
    
    self.view.joystick.walkRation = DataManager.movementSetting.walkRunStickRatio
    self.view.sprintBtn.gameObject:SetActive(not GameInstance.player.forbidSystem:IsForbidden(ForbidType.ForbidSprint))
    self.m_snapshotForbidJoystickKeys = {}

    self:_UpdateWalkRunRation()
end



SnapshotJoystickCtrl.OnShow = HL.Override() << function(self)
    self:_AddRegisters()
end



SnapshotJoystickCtrl.OnHide = HL.Override() << function(self)
    self:_ClearRegisters()
end




SnapshotJoystickCtrl.OnClose = HL.Override() << function(self)
    self:_ClearRegisters()
end






SnapshotJoystickCtrl._AddRegisters = HL.Method() << function(self)
    self.m_updateKey = LuaUpdate:Add("Tick", function()
        self:_UpdateMove()
    end)
end



SnapshotJoystickCtrl._ClearRegisters = HL.Method() << function(self)
    GameInstance.playerController:UpdateMoveCommand(Vector2.zero)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
end






SnapshotJoystickCtrl._onJoystickTouchStart = HL.Method() << function(self)
    if snapshotSystem.isFirstPersonMode then
        return
    end
    if self.m_isPlayerMoveMode then
        
        GameInstance.playerController:ProduceMoveCommand()
    end
end



SnapshotJoystickCtrl._onJoystickTouchEnd = HL.Method() << function(self)
    if snapshotSystem.isFirstPersonMode then
        return
    end
    if self.m_isPlayerMoveMode then
        
        GameInstance.playerController:ConsumeMoveCommand()
    end
end



SnapshotJoystickCtrl._UpdateMove = HL.Method() << function(self)
    if snapshotSystem.isFirstPersonMode or self.m_isForbidFromSnapshot then
        return
    end
    local dir = self.view.joystick.jsValue
    if dir == Vector2.zero then
        return
    end
    if self.m_isPlayerMoveMode then
        local isForbidMoveFromSys = GameInstance.player.forbidSystem:IsForbidden(ForbidType.ForbidMove)
        if self.m_isForbidPlayerMoveFromSnapshot and isForbidMoveFromSys then
            if self.m_forbidToastColdDown < Time.time then
                Notify(MessageConst.SHOW_TOAST, { Language.LUA_SNAPSHOT_FORBID_PLAYER_MOVE, forbidToastColdDownTime })
                self.m_forbidToastColdDown = Time.time + forbidToastColdDownTime
            end
            return
        end
        
        GameInstance.playerController:UpdateMoveCommand(dir)
    else
        
        self.m_cameraCtrl:MoveCameraInPlane(dir)
    end
end



SnapshotJoystickCtrl.SetPlayerMoveMode = HL.Method() << function(self)
    self.m_isPlayerMoveMode = true
end



SnapshotJoystickCtrl.SetCameraMoveMode = HL.Method() << function(self)
    self.m_isPlayerMoveMode = false
    GameInstance.playerController:UpdateMoveCommand(Vector2.zero)
end



SnapshotJoystickCtrl._OnPressSprint = HL.Method() << function(self)
    if snapshotSystem.isFirstPersonMode then
        return
    end
    GameInstance.playerController:OnSprintPressed()
end



SnapshotJoystickCtrl._OnReleaseSprint = HL.Method() << function(self)
    if snapshotSystem.isFirstPersonMode then
        return
    end
    GameInstance.playerController:OnSprintReleased()
end




SnapshotJoystickCtrl._ToggleAutoSprint = HL.Method(HL.Boolean) << function(self, isAutoSprint)
    if snapshotSystem.isFirstPersonMode then
        return
    end
    if not CS.Beyond.GameSetting.controllerCachedAutoSprint then
        return
    end
    GameInstance.playerController:OnJoystickSprint(isAutoSprint)
end



SnapshotJoystickCtrl._UpdateWalkRunRation = HL.Method() << function(self)
    self.view.joystick.walkRation = CS.Beyond.GameSetting.controllerCachedWalkRunRatio
end







SnapshotJoystickCtrl.OnForbidSystemChanged = HL.Method(HL.Any) << function(self, args)
    local forbidType, isForbid = unpack(args)
    if forbidType == ForbidType.ForbidMove then
        self:OnInnerForbidPlayerMove(isForbid)
        if isForbid then
            if self.m_isPlayerMoveMode then
                GameInstance.playerController:UpdateMoveCommand(Vector2.zero)
            end
        end
    end
    
    if forbidType == ForbidType.ForbidSprint then
        if isForbid then
            self.view.sprintBtn.gameObject:SetActive(false)
            self:_OnReleaseSprint()
        else
            self.view.sprintBtn.gameObject:SetActive(true)
        end
    end
end




SnapshotJoystickCtrl.OnForbidJoystick = HL.Method(HL.Table) << function(self, arg)
    local isForbid, key = arg.isForbid, arg.key
    self.m_snapshotForbidJoystickKeys[key] = isForbid and true or nil
    local nowForbid = not not next(self.m_snapshotForbidJoystickKeys)
    
    if self.m_isForbidFromSnapshot ~= nowForbid then
        if nowForbid then
            if self.m_isPlayerMoveMode then
                GameInstance.playerController:UpdateMoveCommand(Vector2.zero)
            end
        end
        self.m_isForbidFromSnapshot = nowForbid
        self.view.mainCanvasGroup.alpha = nowForbid and 0 or 1
        self.view.graphicRaycaster.enabled = not nowForbid
    end
end




SnapshotJoystickCtrl.OnInnerForbidPlayerMove = HL.Method(HL.Boolean) << function(self, isForbid)
    self.m_isForbidPlayerMoveFromSnapshot = isForbid
end



SnapshotJoystickCtrl.OnGameSettingChanged = HL.Method() << function(self)
    self:_UpdateWalkRunRation()
end


HL.Commit(SnapshotJoystickCtrl)
