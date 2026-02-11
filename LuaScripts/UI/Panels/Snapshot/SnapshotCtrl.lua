local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.Snapshot
local PHASE_ID = PhaseId.Snapshot













































































































SnapshotCtrl = HL.Class('SnapshotCtrl', uiCtrl.UICtrl)








SnapshotCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SQUAD_INFIGHT_CHANGED] = 'OnSquadInFightChanged',
    [MessageConst.FORBID_SYSTEM_CHANGED] = 'OnForbidSystemChanged',
    [MessageConst.SNAPSHOT_LISTENER_IDENTIFY_CHANGED] = 'OnListenerIdentifyChanged',
    
    [MessageConst.ON_TELEPORT_SQUAD] = 'AutoCloseSelfOnInterrupt',
    [MessageConst.DEAD_ZONE_ROLLBACK] = 'AutoCloseSelfOnInterrupt',
    [MessageConst.ALL_CHARACTER_DEAD] = 'AutoCloseSelfOnInterrupt',
    [MessageConst.ON_CINEMATIC_TO_QUEUE] = 'OnCinematicToQueue',
    [MessageConst.CLOSE_SNAPSHOT] = '_CloseSelf',
}



local snapshotSystem = GameInstance.player.snapshotSystem


local formationManager = GameWorld.aiManager.characterPhotoSystem


local inventorySystem = GameInstance.player.inventory

local DATA_KEY_MOVE_MODE = "SNAPSHOT_IS_CAMERA_MOVE_MODE"

local FIRST_PERSON_FORBID_KEY = "FirstPerson"

local showCharConfig = {
    {
        nameLuaKey = "LUA_SNAPSHOT_SHOW_CHAR_ALL",
        showLeader = true,
        showTeamMate = true,
    },
    {
        nameLuaKey = "LUA_SNAPSHOT_SHOW_CHAR_LEADER_ONLY",
        showLeader = true,
        showTeamMate = false,
    },
    {
        nameLuaKey = "LUA_SNAPSHOT_SHOW_CHAR_HIDE_ALL",
        showLeader = false,
        showTeamMate = false,
    },
}


local controllerExitHideUIAnyKeyDown = {
    [CS.Beyond.Input.GamepadKeyCode.RightStickBtn] = true,
    [CS.Beyond.Input.GamepadKeyCode.ArrowUp] = true,
    [CS.Beyond.Input.GamepadKeyCode.ArrowDown] = true,
    [CS.Beyond.Input.GamepadKeyCode.ArrowLeft] = true,
    [CS.Beyond.Input.GamepadKeyCode.ArrowRight] = true,
    
    [CS.Beyond.Input.GamepadKeyCode.A] = true,
    [CS.Beyond.Input.GamepadKeyCode.B] = true,
    [CS.Beyond.Input.GamepadKeyCode.X] = true,
    [CS.Beyond.Input.GamepadKeyCode.Y] = true,
    
    [CS.Beyond.Input.GamepadKeyCode.LB] = true,
    [CS.Beyond.Input.GamepadKeyCode.LT] = true,
    [CS.Beyond.Input.GamepadKeyCode.RB] = true,
    [CS.Beyond.Input.GamepadKeyCode.RT] = true,
    
    [CS.Beyond.Input.GamepadKeyCode.LeftMenuBtn] = true,
    [CS.Beyond.Input.GamepadKeyCode.RightMenuBtn] = true,
    [CS.Beyond.Input.GamepadKeyCode.Home] = true,
    [CS.Beyond.Input.GamepadKeyCode.TouchPanel] = true,
}





SnapshotCtrl.m_cameraCtrl = HL.Field(HL.Forward("SnapshotCameraCtrl"))


SnapshotCtrl.m_isInCapture = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_captureTexture = HL.Field(HL.Any)


SnapshotCtrl.m_tipTimerKey = HL.Field(HL.Number) << -1


SnapshotCtrl.m_nextAutoFocusTime = HL.Field(HL.Number) << -1


SnapshotCtrl.m_defaultFocus = HL.Field(HL.Number) << -1


SnapshotCtrl.m_isInCloseProcess = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_cinematicInQueueWaitCloseSnapshot = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_autoFocusDistanceTime = HL.Field(HL.Number) << 0



SnapshotCtrl.m_onZoom = HL.Field(HL.Function)


SnapshotCtrl.m_onDrag = HL.Field(HL.Function)


SnapshotCtrl.m_onClickTouchPlate = HL.Field(HL.Function)


SnapshotCtrl.m_isShowSnapshotUI = HL.Field(HL.Boolean) << true


SnapshotCtrl.m_addFocalLengthCoroutine = HL.Field(HL.Thread)


SnapshotCtrl.m_minusFocalLengthCoroutine = HL.Field(HL.Thread)






SnapshotCtrl.m_curSelectMenuIndex = HL.Field(HL.Number) << 0


SnapshotCtrl.m_menuTabCellList = HL.Field(HL.Table)


SnapshotCtrl.m_menuContentCellList = HL.Field(HL.Table)


SnapshotCtrl.m_onChangeContentFuncList = HL.Field(HL.Table)


SnapshotCtrl.m_isMenuExpand = HL.Field(HL.Boolean) << false




SnapshotCtrl.m_isShowNpc = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_isShowDropItem = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_isShowFactoryBuilding = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_addApertureCoroutine = HL.Field(HL.Thread)


SnapshotCtrl.m_minusApertureCoroutine = HL.Field(HL.Thread)




SnapshotCtrl.m_curTeamFormationIndex = HL.Field(HL.Number) << -1




SnapshotCtrl.m_filterInfos = HL.Field(HL.Table)


SnapshotCtrl.m_getFilterCellFunc = HL.Field(HL.Function)


SnapshotCtrl.m_curSelectFilterIndex = HL.Field(HL.Number) << 0




SnapshotCtrl.m_stickerInfos = HL.Field(HL.Table)


SnapshotCtrl.m_isInitRefreshStickerUI = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_getStickerCellFunc = HL.Field(HL.Function)


SnapshotCtrl.m_curSelectStickerIndex = HL.Field(HL.Number) << 0


SnapshotCtrl.m_inStickerEditMode = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_hideSnapshotUIBySticker = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_editStickerCtrl = HL.Field(HL.Any)







SnapshotCtrl.m_lastSuccess = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_updateKey = HL.Field(HL.Number) << -1


SnapshotCtrl.m_hasTraceIdentify = HL.Field(HL.Boolean) << false


SnapshotCtrl.m_traceIdentifyGroupId = HL.Field(HL.String) << ""


SnapshotCtrl.m_unTraceIdentifyGroupIds = HL.Field(HL.Table)


SnapshotCtrl.m_overrideTraceIdentifyGroupId = HL.Field(HL.String) << ""


SnapshotCtrl.m_identifyInfos = HL.Field(HL.Table)


SnapshotCtrl.m_indicatorCellCache = HL.Field(HL.Forward("UIListCache"))


SnapshotCtrl.m_identifyGoalCellCache = HL.Field(HL.Forward("UIListCache"))




SnapshotCtrl.m_forbidRecords = HL.Field(HL.Table)




SnapshotCtrl.m_eventLogInfo = HL.Field(HL.Table)











SnapshotCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    snapshotSystem:ToggleSnapshotMode(true)
    self:_InitUI()
    self:_InitData(arg)
    self:_RefreshAllUI()
    
    self:OnSquadInFightChanged()
    if arg.forbidFirstPerson then
        self:_SetForbid(self.m_forbidRecords.firstPersonPerspective, true, "InitArg")
    end
    if arg.forbidMoveOrRotateCam then
        self:_SetForbid(self.m_forbidRecords.controlCam, true, "InitArg")
    end
    if arg.onOpenCallBack then
        arg.onOpenCallBack()
    end
    
    EventLogManagerInst:GameEvent_Snapshot(1)
    if self.m_eventLogInfo.isFromActivity then
        EventLogManagerInst:GameEvent_SnapshotActivityStart(
            self.m_eventLogInfo.activityId,
            self.m_eventLogInfo.stageId,
            self.m_eventLogInfo.isFromInteractive and 1 or 2
        )
    end
    self:_AddRegisters()
end



SnapshotCtrl.OnShow = HL.Override() << function(self)
    self:_SwitchAllWorldUIActive(false)
    CS.Beyond.Gameplay.AI.CharacterFollowGraph.s_enableDodge = false
    
    self.m_updateKey = LuaUpdate:Add("TailTick", function()
        self:_OnUpdate()
    end)
end



SnapshotCtrl.OnHide = HL.Override() << function(self)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
end



SnapshotCtrl.OnClose = HL.Override() << function(self)
    self:_ClearRegisters()
    
    CS.Beyond.Gameplay.AI.CharacterFollowGraph.s_enableDodge = true
    snapshotSystem:SwitchMoveMode(false)
    self:_SwitchAllWorldUIActive(true)
    self:_SwitchShowFactoryBuilding(true)
    self:_SwitchShowDropItem(true)
    self:_SwitchShowNpc(true)
    self:_ChangeCharShowMode(1)
    self:_ChangeTeamFormation(-1)
    self:_ChangeFilter(1)
    self:_ClearFilter()
    snapshotSystem.camController:ResetToInitialParam()
    self:_SwitchPersonPerspectiveMode(false, false)
    
    snapshotSystem:ToggleSnapshotMode(false)
    
    if self.m_editStickerCtrl then
        self.m_editStickerCtrl:Close()
        self.m_editStickerCtrl = nil
    end
end



SnapshotCtrl.ShowSnapshot = HL.StaticMethod(HL.Opt(HL.Any)) << function(args)
    
    local isForbidden, forbidParams = Utils.isForbiddenWithReason(ForbidType.ForbidGeneralAbility)
    if isForbidden then
        if forbidParams and forbidParams:IsStyleForbidden(CS.Beyond.Gameplay.GeneralAbilityForbidParams.ForbidStyle.Snapshot) then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FORBID_SNAPSHOT)
            logger.info("拍照模式当前被禁用")
            return
        end
    end
    if LuaSystemManager.mainHudActionQueue:HasRequest(Const.CinematicQueueType) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FORBID_SNAPSHOT)
        logger.info("拍照模式当前被禁用，原因是mainHud队列里有演出")
        return
    end
    
    snapshotSystem:SetForcePlayRadio(true)
    if args then
        local param = unpack(args)
        PhaseManager:OpenPhase(PhaseId.Snapshot, param)
    else
        PhaseManager:OpenPhase(PhaseId.Snapshot)
    end
end



SnapshotCtrl._AddRegisters = HL.Method() << function(self)
    self.view.touchPlate.onZoom:RemoveListener(self.m_onZoom)
    self.view.touchPlate.onDrag:RemoveListener(self.m_onDrag)
    self.view.touchPlate.onClick:RemoveListener(self.m_onClickTouchPlate)
    self.view.touchPlate.onZoom:AddListener(self.m_onZoom)
    self.view.touchPlate.onDrag:AddListener(self.m_onDrag)
    self.view.touchPlate.onClick:AddListener(self.m_onClickTouchPlate)
end



SnapshotCtrl._ClearRegisters = HL.Method() << function(self)
    if self.m_onZoom then
        self.view.touchPlate.onZoom:RemoveListener(self.m_onZoom)
        self.m_onZoom = nil
    end
    if self.m_onDrag then
        self.view.touchPlate.onDrag:RemoveListener(self.m_onDrag)
        self.m_onDrag = nil
    end
    if self.m_onClickTouchPlate then
        self.view.touchPlate.onClick:RemoveListener(self.m_onClickTouchPlate)
        self.m_onClickTouchPlate = nil
    end
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
    
    self.m_addFocalLengthCoroutine = self:_ClearCoroutine(self.m_addFocalLengthCoroutine)
    self.m_minusFocalLengthCoroutine = self:_ClearCoroutine(self.m_minusFocalLengthCoroutine)
    self.m_addApertureCoroutine = self:_ClearCoroutine(self.m_addApertureCoroutine)
    self.m_minusApertureCoroutine = self:_ClearCoroutine(self.m_minusApertureCoroutine)
    
    local basicNode = self.view.menuContentNode.menuBasicNode
    basicNode.showCharDropDown.onIsNaviTargetChanged = nil
    basicNode.apertureSlider.onIsNaviTargetChanged = nil
end



SnapshotCtrl._OnUpdate = HL.Method() << function(self)
    
    local traceGroupInfo = self.m_identifyInfos.traceIdentifyGroupInfo
    if traceGroupInfo and #traceGroupInfo.identifyIds > 0 then
        local successIds, targetPosList = snapshotSystem:ExecuteIdentify(traceGroupInfo.identifyIds)
        
        local matchCount = 0
        for index, id in pairs(traceGroupInfo.identifyIds) do
            local info = traceGroupInfo.identifyInfos[id]
            local curMatched = lume.find(successIds, id)
            if curMatched ~= info.matched then
                local cell = self.m_identifyGoalCellCache:Get(index)
                if cell then
                    cell.animation:ClearTween(false)
                    if curMatched then
                        cell.animation:SampleClipAtPercent("tasktrackhud_celldefault", 1)
                        cell.animation:Play("tasktrackhud_cellfinish")
                    else
                        cell.animation:SampleClipAtPercent("tasktrackhud_cellfinish", 0)
                        cell.animation:Play("tasktrackhud_celldefault")
                    end
                    if curMatched then
                        AudioAdapter.PostEvent("Au_UI_Mission_Step_Complete")
                    end
                end
            end
            info.matched = curMatched
            if curMatched then
                matchCount = matchCount + 1
            end
        end
        local success = matchCount == #traceGroupInfo.identifyIds

        if self.m_lastSuccess ~= success then
            CS.Beyond.Gameplay.Conditions.CheckSnapShotTrace.Trigger(self.m_traceIdentifyGroupId, success)
            self.m_lastSuccess = success

            
            self.view.shutterBtnHighLight.gameObject:SetActive(success)
            self.view.shutterBtnAnimationWrapper:ClearTween(false)
            self.view.shutterBtnAnimationWrapper:SampleClipAtPercent("shutterbtn_in", 0)
            if success then
                AudioAdapter.PostEvent("Au_UI_Mission_PhotoComplete")
                self.view.shutterBtnAnimationWrapper:Play("shutterbtn_in", function()
                    self.view.shutterBtnAnimationWrapper:Play("shutterbtn_loop")
                end)
            end
        end
        
        self.m_indicatorCellCache:Refresh(targetPosList.Count, function(cell, luaIndex)
            
            local pos = targetPosList[CSIndex(luaIndex)]
            local screenPos = CameraManager.mainCamera:WorldToScreenPoint(pos)
            local uiPos = UIUtils.screenPointToUI(Vector2(screenPos.x, screenPos.y), self.uiCamera, self.view.transform)
            cell.transform.anchoredPosition = uiPos
            
            local curCamDis = (snapshotSystem.camController.cameraTrans.position - pos)
            curCamDis = curCamDis.magnitude
            local curFocal = CameraManager.mainCamera.focalLength
            local scale = (curFocal * self.view.config.INDICATOR_STANDARD_CAM_DISTANCE) / (curCamDis * self.view.config.INDICATOR_STANDARD_FOCAL_LENGTH)
            local finalLength = math.max(scale * self.view.config.INDICATOR_STANDARD_LENGTH, self.view.config.INDICATOR_MIN_LENGTH)
            cell.transform:SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, finalLength)
            cell.transform:SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, finalLength)
        end)
    end
    
    if self.m_nextAutoFocusTime > 0 and Time.time >= self.m_nextAutoFocusTime then
        if not snapshotSystem.isFirstPersonMode then
            self.m_nextAutoFocusTime = Time.time + self.m_autoFocusDistanceTime
            snapshotSystem:AutoFocus()
        end
    end
    
    if DeviceInfo.usingController then
        if self.m_inStickerEditMode then
            
            
            local screenWidth = UIManager.uiCanvasRect.rect.size.x
            local delta = screenWidth * self.view.config.CONTROLLER_MOVE_STICKER_SPEED * Time.deltaTime
            local moveDelta = InputManagerInst:GetGamepadStickValue(true) * delta
            local newPos = self.view.stickerImg.rectTransform.anchoredPosition + moveDelta
            self:_SetStickerNewPos(newPos)
        elseif not self.m_isShowSnapshotUI then
            
            for keyCode, _ in pairs(controllerExitHideUIAnyKeyDown) do
                if InputManagerInst:GetKeyDown(keyCode) then
                    self:_SwitchSnapshotUIVisible(true)
                    break
                end
            end
        end
    end
    
end








SnapshotCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    
    self.m_cameraCtrl = arg.cameCtrl
    self.m_autoFocusDistanceTime = self.view.config.AUTO_FOCUS_DISTANCE_TIME
    
    self.m_onZoom = function(delta)
        self.m_cameraCtrl:ZoomCamera(delta)
    end
    self.m_onDrag = function(eventData)
        if eventData.button == CS.UnityEngine.EventSystems.PointerEventData.InputButton.Right then
            return
        end
        if self.m_inStickerEditMode then
            self:_EnableStickerEditMode(false)
        end
        self:_MoveCamera(eventData)
    end
    self.m_onClickTouchPlate = function(_)
        if not self.m_isShowSnapshotUI then
            self:_SwitchSnapshotUIVisible(true)
        end
        if self.m_inStickerEditMode then
            self:_EnableStickerEditMode(false)
        end
    end
    
    
    self.m_forbidRecords = {
        
        switchMoveMode = {
            forbidKeys = {},
            forbidFuncName = "_ForbidSwitchMoveMode",
        },
        
        hideChar = {
            forbidKeys = {},
            forbidFuncName = "_ForbidHideChar",
        },
        
        aperture = {
            forbidKeys = {},
            forbidFuncName = "_ForbidAperture",
        },
        
        switchFormation = {
            forbidKeys = {},
            forbidFuncName = "_ForbidSwitchFormation",
        },
        
        firstPersonPerspective = {
            forbidKeys = {},
            forbidFuncName = "_ForbidFirstPersonPerspective",
        },
        
        playerMoveMode = {
            forbidKeys = {},
            forbidFuncName = "_ForbidPlayerMove",
        },
        
        controlCam = {
            forbidKeys = {},
            forbidFuncName = "_ForbidMoveOrRotateCam",
        },
    }
    

    
    local _, isCameraMoveMode, _ = ClientDataManagerInst:GetBool(DATA_KEY_MOVE_MODE, true, false)
    isCameraMoveMode = isCameraMoveMode and not GameWorld.battle.isSquadInFight and not DeviceInfo.usingController  
    self:_SwitchMoveMode(isCameraMoveMode, false)
    self:_SwitchSnapshotUIVisible(true)
    self:_SwitchPersonPerspectiveMode(arg.thirdPerson == false, false)
    if Utils.isForbidden(ForbidType.ForbidMove) then
        self:_SetForbid(self.m_forbidRecords.playerMoveMode, true, "ForbidSystem")
    end

    if arg.focus then
        self.m_defaultFocus = arg.focus
    else
        self.m_defaultFocus = self.view.config.DEFAULT_FOCAL_LENGTH
    end

    

    
    self.m_curSelectMenuIndex = 1

    
    
    self:_SwitchShowNpc(true)
    self:_SwitchShowDropItem(false)
    self:_SwitchShowFactoryBuilding(true)
    

    
    self:_ChangeTeamFormation(-1)
    

    
    self.m_filterInfos = {}
    table.insert(self.m_filterInfos, {
        isEmpty = true,
        isUnlock = true,
        sortId = math.mininteger,
    })
    for id, filterCfg in pairs(Tables.snapshotFilterTable) do
        local itemId = filterCfg.itemId
        local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
        if not itemCfg then
            logger.error("滤镜对应的itemId表配置不存在！滤镜id：" .. id)
        else
            local isUnlock = filterCfg.isDefaultUnlock or inventorySystem:IsItemGot(itemId)
            local canShow = isUnlock or Utils.isNotObtainCanShow(itemCfg.notObtainShow, itemCfg.notObtainShowTimeId)
            if canShow then
                local info = {
                    id = id,
                    itemId = itemId,
                    name = filterCfg.name,
                    icon = filterCfg.icon,
                    filterPath = filterCfg.filterPath,
                    effectPath = filterCfg.filterEffectPath,
                    
                    isEmpty = false,
                    isUnlock = isUnlock,
                    filterObj = nil,
                    effectInst = nil,
                    
                    sortId = filterCfg.sortId,
                }
                table.insert(self.m_filterInfos, info)
            end
        end
    end
    table.sort(self.m_filterInfos, function(a, b)
        if a.isUnlock ~= b.isUnlock then
            return a.isUnlock
        end
        return a.sortId < b.sortId
    end)
    self:_ChangeFilter(1)
    

    
    self.m_stickerInfos = {}
    table.insert(self.m_stickerInfos, {
        isEmpty = true,
        isUnlock = true,
        sortId = math.mininteger,
    })
    for id, stickerCfg in pairs(Tables.snapshotStickerTable) do
        local itemId = stickerCfg.itemId
        local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
        if not itemCfg then
            logger.error("贴纸对应的itemId表配置不存在！贴纸id：" .. id)
        else
            local isUnlock = stickerCfg.isDefaultUnlock or inventorySystem:IsItemGot(itemId)
            local canShow = isUnlock or Utils.isNotObtainCanShow(itemCfg.notObtainShow, itemCfg.notObtainShowTimeId)
            if canShow then
                local info = {
                    id = id,
                    itemId = itemId,
                    icon = stickerCfg.icon,
                    
                    isEmpty = false,
                    isUnlock = isUnlock,
                    
                    sortId = stickerCfg.sortId,
                }
                table.insert(self.m_stickerInfos, info)
            end
        end
    end
    table.sort(self.m_stickerInfos, function(a, b)
        if a.isUnlock ~= b.isUnlock then
            return a.isUnlock
        end
        return a.sortId < b.sortId
    end)
    self:_ChangeSticker(1)
    

    

    
    self.m_eventLogInfo = {
        isFromInteractive = arg.isFromInteractive,
        isFromActivity = false,
        activityId = "",
        stageId = "",
        
        identifyGroupId = "",
        traceIdentifyProgress = {},
        traceIdentifySuccess = false,
    }
    

    
    self.m_overrideTraceIdentifyGroupId = ""
    if not string.isEmpty(arg.identifyGroupId) then
        self.m_overrideTraceIdentifyGroupId = arg.identifyGroupId
    else
        
        local trackIdentifyGroupId = snapshotSystem:GetCurTrackIdentifyGroupId()
        if not string.isEmpty(trackIdentifyGroupId) then
            self.m_overrideTraceIdentifyGroupId = trackIdentifyGroupId
        end
    end
    self:_UpdateIdentifyInfo()
    

    
    if arg.camInitRotate then
        snapshotSystem.camController:SetCameraRotation(arg.camInitRotate)
    end
    
end



SnapshotCtrl._UpdateIdentifyInfo = HL.Method() << function(self)
    self.m_identifyInfos = {
        traceIdentifyGroupInfo = nil,
        allIdentifyGroupIds = {},
        allIdentifyGroupInfos = {},
        allIdentifyIds = {},
    }
    local allIdentifyGroupIds = snapshotSystem:GetCurListenerIdentifyGroupIds()
    allIdentifyGroupIds:Sort()
    for _, groupId in cs_pairs(allIdentifyGroupIds) do
        table.insert(self.m_identifyInfos.allIdentifyGroupIds, groupId)
    end
    allIdentifyGroupIds = self.m_identifyInfos.allIdentifyGroupIds
    if not string.isEmpty(self.m_overrideTraceIdentifyGroupId) then
        self.m_traceIdentifyGroupId = self.m_overrideTraceIdentifyGroupId
        if not lume.find(allIdentifyGroupIds, self.m_traceIdentifyGroupId) then
            table.insert(allIdentifyGroupIds, self.m_traceIdentifyGroupId)
        end
    end
    self.m_hasTraceIdentify = not string.isEmpty(self.m_traceIdentifyGroupId)
    
    
    self.m_eventLogInfo.isFromActivity = false
    self.m_eventLogInfo.identifyGroupId = self.m_traceIdentifyGroupId
    local hasCfg, cfg = Tables.identifyGroupId2ActivitySnapshotStageTable:TryGetValue(self.m_traceIdentifyGroupId)
    if hasCfg then
        self.m_eventLogInfo.isFromActivity = true
        self.m_eventLogInfo.activityId = cfg.activityId
        self.m_eventLogInfo.stageId = cfg.stageId
    end
    
    if self.m_hasTraceIdentify then
        self.m_identifyInfos.traceIdentifyGroupInfo = SnapshotCtrl._WrapIdentifyGroupInfo(self.m_traceIdentifyGroupId, true)
    end
    for _, groupId in pairs(self.m_identifyInfos.allIdentifyGroupIds) do
        local groupInfo
        if groupId == self.m_traceIdentifyGroupId then
            groupInfo = SnapshotCtrl._WrapIdentifyGroupInfo(self.m_traceIdentifyGroupId, true)
            self.m_identifyInfos.traceIdentifyGroupInfo = groupInfo
            CS.Beyond.Gameplay.SnapshotSystem.curRealTraceIdentifyIds:Clear()
            for _, id in pairs(groupInfo.identifyIds) do
                CS.Beyond.Gameplay.SnapshotSystem.curRealTraceIdentifyIds:Add(id)
            end
        else
            groupInfo = SnapshotCtrl._WrapIdentifyGroupInfo(self.m_traceIdentifyGroupId, false)
        end
        if groupInfo then
            self.m_identifyInfos.allIdentifyGroupInfos[groupId] = groupInfo
            for _, identifyId in pairs(groupInfo.identifyIds) do
                table.insert(self.m_identifyInfos.allIdentifyIds, identifyId)
            end
        end
    end
end




SnapshotCtrl._WrapIdentifyGroupInfo = HL.StaticMethod(HL.String, HL.Boolean).Return(HL.Table) << function(identifyGroupId, needDesc)
    local hasCfg, cfg = Tables.snapshotIdentifyGroupTable:TryGetValue(identifyGroupId)
    if not hasCfg then
        return nil
    end
    
    local groupInfo = {
        identifyGroupId = identifyGroupId,
        identifyIds = {},
        identifyInfos = {},
    }
    for _, identifyId in pairs(cfg.identifyIds) do
        table.insert(groupInfo.identifyIds, identifyId)
        local identifyInfo = {
            id = identifyId,
            matched = false,
        }
        if needDesc then
            identifyInfo.desc = snapshotSystem:GetIdentifyDesc(identifyId)
        end
        groupInfo.identifyInfos[identifyId] = identifyInfo
    end
    
    return groupInfo
end






SnapshotCtrl._InitUI = HL.Method() << function(self)
    
    self.view.closeBtn.onClick:AddListener(function()
        self:_CloseSelf()
    end)
    self.view.shutterBtn.onClick:AddListener(function()
        self:_ClickShutter()
    end)
    self.view.personPerspectiveBtn.onClick:AddListener(function()
        local isFirstPersonMode = snapshotSystem.isFirstPersonMode
        if not isFirstPersonMode and self:_IsForbid(self.m_forbidRecords.firstPersonPerspective) then
            self:_ShowForbidToast(self.m_forbidRecords.firstPersonPerspective)
            return
        end
        self:_SwitchPersonPerspectiveMode(not isFirstPersonMode, true)
    end)
    self.view.resetPerspectiveBtn.onClick:AddListener(function()
        self:_ResetPerspective()
    end)
    self.view.uiVisibleBtn.onClick:AddListener(function()
        self:_SwitchSnapshotUIVisible(false)
    end)
    self.view.switchMoveModeTog.onValueChanged:AddListener(function(isOn)
        if self:_IsForbid(self.m_forbidRecords.switchMoveMode) then
            self:_ShowForbidToast(self.m_forbidRecords.switchMoveMode)
            return
        end
        self:_SwitchMoveMode(isOn, true)
        self.view.switchMoveModeAniWrapper:Play(isOn and "switchmove_to_left" or "switchmove_to_right")
    end)
    
    local focalLengthNode = self.view.focalLengthNode
    focalLengthNode.focalLengthSlider.minValue = self.view.config.MIN_FOCAL_LENGTH
    focalLengthNode.focalLengthSlider.maxValue = self.view.config.MAX_FOCAL_LENGTH
    focalLengthNode.focalLengthSlider.onValueChanged:AddListener(function(newValue)
        self:_ChangeFocalLength(newValue)
    end)
    
    
    focalLengthNode.addBtn.onPressStart:AddListener(function()
        if InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1) then
            return
        end

        self.m_addFocalLengthCoroutine = self:_ClearCoroutine(self.m_addFocalLengthCoroutine)
        self.m_addFocalLengthCoroutine = self:_StartCoroutine(function()
            local preValue = focalLengthNode.focalLengthSlider.value
            focalLengthNode.focalLengthSlider.value = preValue + 1
            coroutine.wait(UIConst.NUMBER_SELECTOR_COUNT_REFRESH_INTERVAL)
            while true do
                preValue = focalLengthNode.focalLengthSlider.value
                focalLengthNode.focalLengthSlider.value = preValue + Time.deltaTime * self.view.config.PRESS_CHANGE_FOCAL_LENGTH_SPEED
                coroutine.step()
            end
        end)
    end)
    focalLengthNode.addBtn.onPressEnd:AddListener(function()
        self.m_addFocalLengthCoroutine = self:_ClearCoroutine(self.m_addFocalLengthCoroutine)
    end)
    
    focalLengthNode.minusBtn.onPressStart:AddListener(function()
        if InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1) then
            return
        end

        self.m_minusFocalLengthCoroutine = self:_ClearCoroutine(self.m_minusFocalLengthCoroutine)
        self.m_minusFocalLengthCoroutine = self:_StartCoroutine(function()
            local preValue = focalLengthNode.focalLengthSlider.value
            focalLengthNode.focalLengthSlider.value = preValue - 1
            coroutine.wait(UIConst.NUMBER_SELECTOR_COUNT_REFRESH_INTERVAL)
            while true do
                preValue = focalLengthNode.focalLengthSlider.value
                focalLengthNode.focalLengthSlider.value = preValue - Time.deltaTime * self.view.config.PRESS_CHANGE_FOCAL_LENGTH_SPEED
                coroutine.step()
            end
        end)
    end)
    focalLengthNode.minusBtn.onPressEnd:AddListener(function()
        self.m_minusFocalLengthCoroutine = self:_ClearCoroutine(self.m_minusFocalLengthCoroutine)
    end)
    
    

    
    self.view.menuFoldBtn.onClick:AddListener(function()
        self:_SwitchMenuContentExpand(not self.m_isMenuExpand)
    end)
    self.view.menuNodeNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = isFocused, key = "focusMenu" })
        self.view.hintNode.gameObject:SetActive(not isFocused)
        self.view.menuTabNode.focusMenuKeyHintNode.gameObject:SetActive(not isFocused)
        if isFocused then
            self:_ChangeMenuTab(self.m_curSelectMenuIndex, true)
            
            if DeviceInfo.usingController then
                self.m_addFocalLengthCoroutine = self:_ClearCoroutine(self.m_addFocalLengthCoroutine)
                self.m_minusFocalLengthCoroutine = self:_ClearCoroutine(self.m_minusFocalLengthCoroutine)
                self.m_addApertureCoroutine = self:_ClearCoroutine(self.m_addApertureCoroutine)
                self.m_minusApertureCoroutine = self:_ClearCoroutine(self.m_minusApertureCoroutine)
            end
        else
            self:_SwitchMenuContentExpand(false)
        end
    end)
    
    local menuTabNode = self.view.menuTabNode
    self.m_menuTabCellList = {
        menuTabNode.menuTabBasicBtn,
        menuTabNode.menuTabFormationBtn,
        menuTabNode.menuTabFilterBtn,
        menuTabNode.menuTabStickerBtn,
    }
    for i, tabBtnCell in pairs(self.m_menuTabCellList) do
        tabBtnCell.btn.onClick:AddListener(function()
            if self.m_isMenuExpand and self.m_curSelectMenuIndex == i then
                self:_SwitchMenuContentExpand(false)
            else
                self:_ChangeMenuTab(i, true)
            end
        end)
    end
    
    local preTabActionId = menuTabNode.keyHintPreTab.actionId
    local nextTabActionId = menuTabNode.keyHintNextTab.actionId
    UIUtils.bindInputPlayerAction(preTabActionId, function()
        local count = #self.m_menuTabCellList
        local newIndex = (self.m_curSelectMenuIndex + count - 2) % count + 1
        if newIndex ~= self.m_curSelectMenuIndex then
            AudioAdapter.PostEvent("Au_UI_Toggle_Tab_On")
            self:_ChangeMenuTab(newIndex, true)
        end
    end, self.view.menuInputGroup.groupId)
    UIUtils.bindInputPlayerAction(nextTabActionId, function()
        local count = #self.m_menuTabCellList
        local newIndex = self.m_curSelectMenuIndex % count + 1
        if newIndex ~= self.m_curSelectMenuIndex then
            AudioAdapter.PostEvent("Au_UI_Toggle_Tab_On")
            self:_ChangeMenuTab(newIndex, true)
        end
    end, self.view.menuInputGroup.groupId)
    if DeviceInfo.usingController then
        menuTabNode.keyHintPreTabRoot.gameObject:SetActive(false)
        menuTabNode.keyHintNextTabRoot.gameObject:SetActive(false)
    end
    

    
    local menuContentNode = self.view.menuContentNode
    self.m_menuContentCellList = {
        menuContentNode.menuBasicNode,
        menuContentNode.menuFormationNode,
        menuContentNode.menuFilterNode,
        menuContentNode.menuStickerNode,
    }
    self:_InitUIMenuContentChangeFunc()

    
    local basicNode = menuContentNode.menuBasicNode
    basicNode.showCharDropDown:ClearComponent()
    basicNode.showCharDropDown:Init(
        function(csIndex, option, _)
            
            option:SetText(Language[showCharConfig[LuaIndex(csIndex)].nameLuaKey])
        end,
        function(csIndex)
            
            self:_ChangeCharShowMode(LuaIndex(csIndex))
        end
    )
    basicNode.showCharDropDown.onIsNaviTargetChanged = function(isTarget)
        InputManagerInst:ToggleGroup(basicNode.showCharDropDown.groupId, isTarget)
    end
    basicNode.showCharDropDownForbidToastBtn.onClick:AddListener(function()
        self:_ShowForbidToast(self.m_forbidRecords.hideChar)
    end)
    basicNode.showNpcTog.onValueChanged:AddListener(function(isOn)
        self:_SwitchShowNpc(isOn)
    end)
    basicNode.showDropItemTog.onValueChanged:AddListener(function(isOn)
        self:_SwitchShowDropItem(isOn)
    end)
    basicNode.showFactoryBuildingTog.onValueChanged:AddListener(function(isOn)
        self:_SwitchShowFactoryBuilding(isOn)
    end)

    
    basicNode.apertureSlider.minValue = self.view.config.MIN_APERTURE
    basicNode.apertureSlider.maxValue = self.view.config.MAX_APERTURE
    basicNode.apertureSlider.onValueChanged:AddListener(function(newValue)
        self:_ChangeAperture(newValue)
    end)
    basicNode.apertureSlider.onEndDragSlider:AddListener(function()
        if self:_IsForbid(self.m_forbidRecords.aperture) then
            self:_ShowForbidToast(self.m_forbidRecords.aperture)
        end
    end)
    
    local minusSliderActionId = basicNode.keyHintApertureSliderLeft.actionId
    local minusSliderEndActionId = "snapshot_controller_aperture_minus_end"
    
    UIUtils.bindInputPlayerAction(minusSliderActionId, function()
        self.m_minusApertureCoroutine = self:_ClearCoroutine(self.m_minusApertureCoroutine)
        self.m_minusApertureCoroutine = self:_StartCoroutine(function()
            local preValue = basicNode.apertureSlider.value
            basicNode.apertureSlider.value = preValue - 0.1
            coroutine.wait(UIConst.NUMBER_SELECTOR_COUNT_REFRESH_INTERVAL)
            while true do
                preValue = basicNode.apertureSlider.value
                basicNode.apertureSlider.value = preValue - Time.deltaTime * self.view.config.CONTROLLER_CHANGE_APERTURE_SPEED
                coroutine.step()
            end
        end)
    end, basicNode.apertureSlider.groupId)
    UIUtils.bindInputPlayerAction(minusSliderEndActionId, function()
        self.m_minusApertureCoroutine = self:_ClearCoroutine(self.m_minusApertureCoroutine)
    end, basicNode.apertureSlider.groupId)
    
    local addSliderActionId = basicNode.keyHintApertureSliderRight.actionId
    local addSliderEndActionId = "snapshot_controller_aperture_add_end"
    UIUtils.bindInputPlayerAction(addSliderActionId, function()
        self.m_addApertureCoroutine = self:_ClearCoroutine(self.m_addApertureCoroutine)
        self.m_addApertureCoroutine = self:_StartCoroutine(function()
            local preValue = basicNode.apertureSlider.value
            basicNode.apertureSlider.value = preValue + 0.1
            coroutine.wait(UIConst.NUMBER_SELECTOR_COUNT_REFRESH_INTERVAL)
            while true do
                preValue = basicNode.apertureSlider.value
                basicNode.apertureSlider.value = preValue + Time.deltaTime * self.view.config.CONTROLLER_CHANGE_APERTURE_SPEED
                coroutine.step()
            end
        end)
    end, basicNode.apertureSlider.groupId)
    UIUtils.bindInputPlayerAction(addSliderEndActionId, function()
        self.m_addApertureCoroutine = self:_ClearCoroutine(self.m_addApertureCoroutine)
    end, basicNode.apertureSlider.groupId)
    
    basicNode.apertureSlider.onIsNaviTargetChanged = function(isTarget)
        InputManagerInst:ToggleGroup(basicNode.apertureSlider.groupId, isTarget)
    end
    basicNode.apertureSliderForbidToastBtn.onClick:AddListener(function()
        self:_ShowForbidToast(self.m_forbidRecords.aperture)
    end)
    
    

    

    
    local formationNode = menuContentNode.menuFormationNode
    formationNode.gameObject:SetActive(false)
    formationNode.formationTog.onValueChanged:AddListener(function(isOn)
        if not isOn then
            formationNode.formationDropDown:SetSelected(0)
        end
        formationNode.formationDropDown.interactable = isOn
        formationNode.formationDropDownForbidToastBtn.gameObject:SetActive(not isOn)
    end)
    formationNode.formationDropDownForbidToastBtn.onClick:AddListener(function()
        self:_ShowForbidToast(self.m_forbidRecords.switchFormation)
    end)
    formationNode.formationDropDown:ClearComponent()
    formationNode.formationDropDown:Init(
        function(csIndex, option, _)
            local name
            if csIndex <= 0 then
                name = Language.LUA_SNAPSHOT_FORMATION_NONE
            else
                local textId = formationManager.formationUIData[csIndex - 1].Item2
                local _, result = I18nUtils.TryGetText(textId)
                name = result
            end
            option:SetText(name)
        end,
        function(csIndex)
            
            self:_ChangeTeamFormation(csIndex - 1)
        end
    )
    

    
    local filterNode = menuContentNode.menuFilterNode
    filterNode.gameObject:SetActive(false)
    self.m_getFilterCellFunc = UIUtils.genCachedCellFunction(filterNode.menuFilterList)
    filterNode.menuFilterList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getFilterCellFunc(obj)
        self:_RefreshFilterCell(cell, LuaIndex(csIndex))
    end)
    

    
    local stickerNode = menuContentNode.menuStickerNode
    stickerNode.gameObject:SetActive(false)
    self.m_getStickerCellFunc = UIUtils.genCachedCellFunction(stickerNode.stickerList)
    stickerNode.stickerList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getFilterCellFunc(obj)
        self:_RefreshStickerCell(cell, LuaIndex(csIndex))
    end)
    
    local stickerTouchPlate = self.view.stickerTouchPlate
    stickerTouchPlate.onDrag:AddListener(function(eventData)
        self:_OnDragSticker(eventData)
    end)
    stickerTouchPlate.onDragBegin:AddListener(function(_)
        if not self.m_inStickerEditMode then
            return
        end
        if self.m_isShowSnapshotUI then
            self.m_hideSnapshotUIBySticker = true
            self:_SwitchSnapshotUIVisible(false)
        end
    end)
    stickerTouchPlate.onDragEnd:AddListener(function(_)
        if not self.m_inStickerEditMode then
            return
        end
        if self.m_hideSnapshotUIBySticker then
            self.m_hideSnapshotUIBySticker = false
            self:_SwitchSnapshotUIVisible(true)
        end
    end)
    
    local stickerTouchPlateNoEdit = self.view.stickerTouchPlateNoEdit
    stickerTouchPlateNoEdit.onClick:AddListener(function()
        if not self.m_inStickerEditMode then
            self:_EnableStickerEditMode(true)
        end
    end)
    stickerTouchPlateNoEdit.onDrag:AddListener(function(eventData)
        self.m_onDrag(eventData)
    end)
    

    
    

    
    self.m_indicatorCellCache = UIUtils.genCellCache(self.view.indicatorCell)
    self.m_identifyGoalCellCache = UIUtils.genCellCache(self.view.identifyTaskNode.identifyGoalCell)
    

    
    self.view.tipNode.gameObject:SetActive(false)
    
end



SnapshotCtrl._InitUIMenuContentChangeFunc = HL.Method() << function(self)
    self.m_onChangeContentFuncList = {
        {
            
            entryFunc = function()
                self.view.menuContentNode.menuBasicNode.apertureSlider.interactable = false
            end,
            naviFunc = function()
                InputManagerInst.controllerNaviManager:SetTarget(self.view.menuContentNode.menuBasicNode.showCharDropDown)
                
                if not self:_IsForbid(self.m_forbidRecords.aperture) then
                    self.view.menuContentNode.menuBasicNode.apertureSlider.interactable = true
                end
                InputManagerInst:ToggleGroup(self.view.menuContentNode.menuBasicNode.apertureSlider.groupId, false)
            end,
            leaveFunc = nil,
        },
        {
            
            entryFunc = function()
            end,
            naviFunc = function()
                InputManagerInst.controllerNaviManager:SetTarget(self.view.menuContentNode.menuFormationNode.formationTog)
            end,
            leaveFunc = nil,
        },
        {
            
            entryFunc = function()
                self:_ShowFilterName(true)
            end,
            naviFunc = function()
                local obj = self.view.menuContentNode.menuFilterNode.menuFilterList:Get(CSIndex(self.m_curSelectFilterIndex))
                local cell = self.m_getFilterCellFunc(obj)
                if cell then
                    InputManagerInst.controllerNaviManager:SetTarget(cell.btn)
                end
            end,
            leaveFunc = function()
                self:_ShowFilterName(false)
            end,
        },
        {
            
            entryFunc = function()
                if not self.m_isInitRefreshStickerUI then
                    self.m_isInitRefreshStickerUI = true
                    local stickerNode = self.view.menuContentNode.menuStickerNode
                    stickerNode.stickerList:UpdateCount(#self.m_stickerInfos, true)
                end
            end,
            naviFunc = function()
                local obj = self.view.menuContentNode.menuStickerNode.stickerList:Get(CSIndex(self.m_curSelectStickerIndex))
                local cell = self.m_getStickerCellFunc(obj)
                if cell then
                    InputManagerInst.controllerNaviManager:SetTarget(cell.btn)
                end
            end,
            leaveFunc = function()
                if self.m_inStickerEditMode then
                    self:_EnableStickerEditMode(false)
                end
            end,
        },
    }
end



SnapshotCtrl._RefreshAllUI = HL.Method() << function(self)
    
    self.view.switchMoveModeTog:SetIsOnWithoutNotify(snapshotSystem.isCameraMoveMode)
    local value = math.max(math.min(self.view.config.MAX_FOCAL_LENGTH, self.m_defaultFocus), self.view.config.MIN_FOCAL_LENGTH)
    if self.view.focalLengthNode.focalLengthSlider.value == value then
        self:_ChangeFocalLength(value)
    end
    self.view.focalLengthNode.focalLengthSlider.value = value
    self.view.shutterBtnHighLight.gameObject:SetActive(false)
    
    local menuContentNode = self.view.menuContentNode
    self.m_curSelectMenuIndex = 1
    
    local basicNode = menuContentNode.menuBasicNode
    basicNode.showNpcTog:SetIsOnWithoutNotify(self.m_isShowNpc)
    basicNode.showDropItemTog:SetIsOnWithoutNotify(self.m_isShowDropItem)
    basicNode.showFactoryBuildingTog:SetIsOnWithoutNotify(self.m_isShowFactoryBuilding)
    basicNode.showCharDropDown:Refresh(#showCharConfig, 0, false)
    basicNode.apertureSlider.value = self.view.config.DEFAULT_APERTURE
    
    local formationNode = menuContentNode.menuFormationNode
    formationNode.formationDropDown:Refresh(formationManager.formationUIData.Count + 1, 0, false) 
    
    local filterNode = menuContentNode.menuFilterNode
    filterNode.menuFilterList:UpdateCount(#self.m_filterInfos, true)
    
    
    self:_ChangeMenuTab(1, false, true)
    self:_SwitchMenuContentExpand(false, true)
    
    
    self:_RefreshIdentifyTask()
    
    self.m_indicatorCellCache:Refresh(0)
end





SnapshotCtrl._RefreshFilterCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local info = self.m_filterInfos[luaIndex]
    cell.selectStateCtrl:SetState(self.m_curSelectFilterIndex == luaIndex and "Select" or "Unselect")
    cell.editorStateCtrl:SetState("NoEditor")
    cell.emptyStateCtrl:SetState(info.isEmpty and "Empty" or "Normal")
    cell.btn.onClick:RemoveAllListeners()
    cell.btn.onLongPress:RemoveAllListeners()
    cell.showTipsBtn.onClick:RemoveAllListeners()
    if info.isUnlock then
        cell.lockStateCtrl:SetState("Unlock")
        cell.btn.onClick:AddListener(function()
            local oldIndex = self.m_curSelectFilterIndex
            if oldIndex == luaIndex then
                return
            end
            if oldIndex > 0 then
                local oldObj = self.view.menuContentNode.menuFilterNode.menuFilterList:Get(CSIndex(oldIndex))
                local oldCell = self.m_getFilterCellFunc(oldObj)
                if oldCell then
                    oldCell.selectStateCtrl:SetState("Unselect")
                end
            end
            cell.selectStateCtrl:SetState("Select")
            self:_ChangeFilter(luaIndex)
        end)
    else
        cell.lockStateCtrl:SetState("Lock")
        cell.btn.onClick:AddListener(function()
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FILTER_UNLOCK_TOAST)
        end)
    end
    if not string.isEmpty(info.itemId) then
        cell.btn.onLongPress:AddListener(function()
            Notify(MessageConst.SHOW_ITEM_TIPS, {
                transform = cell.transform,
                posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                itemId = info.itemId,
            })
        end)
        cell.showTipsBtn.gameObject:SetActive(false)
        if DeviceInfo.usingController then
            cell.showTipsBtn.onClick:AddListener(function()
                Notify(MessageConst.SHOW_ITEM_TIPS, {
                    transform = cell.transform,
                    posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                    itemId = info.itemId,
                })
            end)
            cell.btn.onIsNaviTargetChanged = function(isTarget)
                cell.showTipsBtn.gameObject:SetActive(isTarget)
            end
        end
    end
    
    if not info.isEmpty then
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_SNAPSHOT_FILTER, info.icon)
    end
end





SnapshotCtrl._RefreshStickerCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local info = self.m_stickerInfos[luaIndex]
    local isSelect = self.m_curSelectStickerIndex == luaIndex
    cell.selectStateCtrl:SetState(isSelect and "Select" or "Unselect")
    local isEditor = (not info.isEmpty) and isSelect
    cell.editorStateCtrl:SetState(isEditor and "Editor" or "NoEditor")
    cell.emptyStateCtrl:SetState(info.isEmpty and "Empty" or "Normal")
    cell.btn.onClick:RemoveAllListeners()
    cell.btn.onLongPress:RemoveAllListeners()
    cell.showTipsBtn.onClick:RemoveAllListeners()
    if info.isUnlock then
        cell.lockStateCtrl:SetState("Unlock")
        InputManagerInst:SetBindingText(cell.btn.hoverConfirmBindingId, Language.LUA_SNAPSHOT_STICKER_SELECT_HINT_TEXT)
        cell.btn.onClick:AddListener(function()
            self:_OnClickMenuStickerCell(luaIndex, cell)
        end)
    else
        cell.lockStateCtrl:SetState("Lock")
        cell.btn.onClick:AddListener(function()
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_STICKER_UNLOCK_TOAST)
        end)
    end
    if not string.isEmpty(info.itemId) then
        cell.btn.onLongPress:AddListener(function()
            Notify(MessageConst.SHOW_ITEM_TIPS, {
                transform = cell.transform,
                posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                itemId = info.itemId,
            })
        end)
        cell.showTipsBtn.gameObject:SetActive(false)
        if DeviceInfo.usingController then
            cell.showTipsBtn.onClick:AddListener(function()
                Notify(MessageConst.SHOW_ITEM_TIPS, {
                    transform = cell.transform,
                    posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
                    itemId = info.itemId,
                })
            end)
            cell.btn.onIsNaviTargetChanged = function(isTarget)
                cell.showTipsBtn.gameObject:SetActive(isTarget)
            end
        end
    end
    
    if not info.isEmpty then
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_SNAPSHOT_STICKER, info.icon)
    end
end



SnapshotCtrl._RefreshIdentifyTask = HL.Method() << function(self)
    local count = 0
    if self.m_identifyInfos.traceIdentifyGroupInfo then
        count = #self.m_identifyInfos.traceIdentifyGroupInfo.identifyIds
    end
    self.m_identifyGoalCellCache:Refresh(
        count,
        function(cell, luaIndex)
            local id = self.m_identifyInfos.traceIdentifyGroupInfo.identifyIds[luaIndex]
            local info = self.m_identifyInfos.traceIdentifyGroupInfo.identifyInfos[id]
            cell.goalTxt.text = info.desc
            cell.animation:Play("tasktrackhud_celldefault")
        end
    )
end



SnapshotCtrl._RefreshTaskNodeVisible = HL.Method() << function(self)
    if DeviceInfo.usingTouch then
        self.view.identifyTaskNode.gameObject:SetActive(self.m_hasTraceIdentify and not self.m_isMenuExpand)
    else
        self.view.identifyTaskNode.gameObject:SetActive(self.m_hasTraceIdentify)
    end
end










SnapshotCtrl._CloseSelf = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, filterCommonShare, closeFast)
    if self.m_isInCloseProcess or not PhaseManager:IsOpenAndValid(PhaseId.Snapshot) or not PhaseManager:CanPopPhase(PhaseId.Snapshot) then
        return
    end
    self.m_isInCloseProcess = true  
    if not filterCommonShare then
        UIManager:Close(PanelId.CommonShare)
    end
    UIManager:Close(PanelId.CommonPopUp)
    if PhaseManager:GetTopPhaseId() == PHASE_ID and not closeFast then
        PhaseManager:PopPhase(PHASE_ID, function()
            snapshotSystem:SetForcePlayRadio(false)
        end)
    else
        PhaseManager:ExitPhaseFast(PHASE_ID)
        snapshotSystem:SetForcePlayRadio(false)
    end
    AudioAdapter.PostEvent("Au_UI_Popup_PhotoPanel_Close")
end



SnapshotCtrl._ClickShutter = HL.Method() << function(self)
    EventLogManagerInst:GameEvent_Snapshot(2)
    if self.m_inStickerEditMode then
        self:_EnableStickerEditMode(false)
    end
    self.m_isInCapture = true
    self.view.captureInvisibleRoot.gameObject:SetActive(false)
    self.view.touchPlate.gameObject:SetActive(false)
    local atLeastOneSuccess = false

    
    if #self.m_identifyInfos.allIdentifyIds > 0 then
        local successIds = snapshotSystem:ExecuteIdentify(self.m_identifyInfos.allIdentifyIds)
        
        local tempSet = {}
        for _, identifyId in cs_pairs(successIds) do
            tempSet[identifyId] = true
        end
        for _, groupInfo in pairs(self.m_identifyInfos.allIdentifyGroupInfos) do
            local curMatchCount = 0
            for _, identifyId in pairs(groupInfo.identifyIds) do
                if tempSet[identifyId] then
                    groupInfo.identifyInfos[identifyId].matched = true
                    curMatchCount = curMatchCount + 1
                end
                if groupInfo.identifyGroupId == self.m_eventLogInfo.identifyGroupId then
                    self.m_eventLogInfo.traceIdentifyProgress[identifyId] = not not tempSet[identifyId]
                end
            end
            local isAllComplete = curMatchCount == #groupInfo.identifyIds
            if isAllComplete then
                
                snapshotSystem:NotifyIdentifyGroupSuccess(groupInfo.identifyGroupId)
                atLeastOneSuccess = true
            end
            if groupInfo.identifyGroupId == self.m_eventLogInfo.identifyGroupId then
                self.m_eventLogInfo.traceIdentifySuccess = isAllComplete
            end
        end
    end
    
    if self.m_eventLogInfo.isFromActivity then
        EventLogManagerInst:GameEvent_SnapshotActivityShot(
            self.m_eventLogInfo.activityId,
            self.m_eventLogInfo.stageId,
            self.m_eventLogInfo.isFromInteractive and 1 or 2,
            self.m_eventLogInfo.traceIdentifyProgress,
            self.m_eventLogInfo.traceIdentifySuccess and 1 or 0
        )
    end
    
    local curShowSticker = self.view.stickerImg.gameObject.activeSelf
    Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = true, key = "Shutter" })
    
    local needCloseSelfFast = atLeastOneSuccess or self.m_cinematicInQueueWaitCloseSnapshot 
    Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
        type = "PhotoShot",
        aperture = self.view.menuContentNode.menuBasicNode.apertureValueTxt.text,
        focus = self.view.focalLengthNode.sliderValueTxt.text,
        showPlayerInfo = true,
        success = atLeastOneSuccess,
        isCloseFast = needCloseSelfFast,
        onCaptureEnd = function()
            if not UIManager:IsOpen(PANEL_ID) or not PhaseManager:IsOpenAndValid(PHASE_ID) then
                return  
            end
            if curShowSticker then
                self.view.stickerImg.gameObject:SetActive(false)
            end
        end,
        onClose = function()
            if not UIManager:IsOpen(PANEL_ID) or not PhaseManager:IsOpenAndValid(PHASE_ID) then
                return  
            end
            self.m_isInCapture = false
            if curShowSticker then
                self.view.stickerImg.gameObject:SetActive(true)
            end
            self.view.touchPlate.gameObject:SetActive(true)
            self.view.captureInvisibleRoot.gameObject:SetActive(true)
            Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = false, key = "Shutter" })
            if needCloseSelfFast then
                self:_CloseSelf(true, true)
            end
        end,
    })
end





SnapshotCtrl._SwitchPersonPerspectiveMode = HL.Method(HL.Boolean, HL.Boolean) << function(self, isFirstPersonMode, showTip)
    if showTip then
        Notify(MessageConst.SHOW_TOAST, isFirstPersonMode
            and Language.LUA_SNAPSHOT_SWITCH_FIRST_PERSON_MODE
            or Language.LUA_SNAPSHOT_SWITCH_THIRD_PERSON_MODE
        )
    end
    snapshotSystem:SetFirstPersonMode(isFirstPersonMode)
    if isFirstPersonMode then
        self.m_nextAutoFocusTime = -1
        snapshotSystem.camController:SetFocusDistance(self.view.config.DEFAULT_AUTO_FOCUS_DISTANCE)
        GameInstance.playerController:UpdateMoveCommand(Vector2.zero)
    else
        self.m_nextAutoFocusTime = Time.time + self.m_autoFocusDistanceTime
    end
    
    self:_SetForbid(self.m_forbidRecords.aperture, isFirstPersonMode, FIRST_PERSON_FORBID_KEY)
    self:_SetForbid(self.m_forbidRecords.playerMoveMode, isFirstPersonMode, FIRST_PERSON_FORBID_KEY)
    self:_SetForbid(self.m_forbidRecords.switchMoveMode, isFirstPersonMode, FIRST_PERSON_FORBID_KEY)
    Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = isFirstPersonMode, key = "IsFirstPersonMode" })
    self.view.hintNode.moveNode.gameObject:SetActive(not isFirstPersonMode)
    self.view.hintNode.moveRoleNode.gameObject:SetActive(not isFirstPersonMode)
    self.view.hintNode.moveCamNode.gameObject:SetActive(not isFirstPersonMode)
    self.view.hintNode.pcZoomNode.gameObject:SetActive(not isFirstPersonMode)
    self.view.hintNode.gamepadZoomNode.gameObject:SetActive(not isFirstPersonMode)
end



SnapshotCtrl._ResetPerspective = HL.Method() << function(self)
    self:Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_SNAPSHOT_RESET_PERSPECTIVE_SECOND_CONFIRM,
        onConfirm = function()
            snapshotSystem.camController:ResetToInitialParam()
        end,
    })
end




SnapshotCtrl._ChangeFocalLength = HL.Method(HL.Number) << function(self, newValue)
    self.view.focalLengthNode.sliderValueTxt.text = string.format("%.0f mm", newValue)
    self.m_cameraCtrl:SetFocalLenCamera(newValue)
end





SnapshotCtrl._SwitchMoveMode = HL.Method(HL.Boolean, HL.Boolean) << function(self, isCameraMoveMode, showTip)
    if DeviceInfo.usingController and isCameraMoveMode then
        logger.error("[拍照模式] 手柄模式下，禁止切换到相机移动模式！因为手柄模式下相机移动模式和玩家移动模式是共存的")
        return
    end
    if showTip then
        local msg = isCameraMoveMode
            and Language.LUA_SNAPSHOT_SWITCH_MOVE_MODE_CAMERA
            or Language.LUA_SNAPSHOT_SWITCH_MOVE_MODE_PLAYER
        Notify(MessageConst.SHOW_TOAST, msg)
    end
    snapshotSystem:SwitchMoveMode(isCameraMoveMode)
    if isCameraMoveMode then
        self.view.hintNode.pcMoveNodeStateCtrl:SetState("CameraMove")
        Notify(MessageConst.SNAPSHOT_CAMERA_MOVE_MODE)
    else
        self.view.hintNode.pcMoveNodeStateCtrl:SetState("PlayerMove")
        Notify(MessageConst.SNAPSHOT_PLAYER_MOVE_MODE)
    end
    ClientDataManagerInst:SetBool(DATA_KEY_MOVE_MODE, isCameraMoveMode, true)
end




SnapshotCtrl._SwitchSnapshotUIVisible = HL.Method(HL.Boolean) << function(self, isShow)
    self.m_isShowSnapshotUI = isShow
    self.view.captureInvisibleRoot.gameObject:SetActive(isShow)
    if DeviceInfo.usingController then
        self.view.inputGroup.enabled = isShow
    elseif DeviceInfo.usingTouch then
        Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = not isShow, key = "SnapshotUIVisibleUsingTouch" })
    end
    AudioAdapter.PostEvent(isShow and "Au_UI_Popup_Common_Large_Open" or "Au_UI_Popup_Common_Large_Close")
end










SnapshotCtrl._ChangeMenuTab = HL.Method(HL.Number, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, luaIndex, autoExpand, isInit)
    local oldIndex = self.m_curSelectMenuIndex
    self.m_curSelectMenuIndex = luaIndex
    if oldIndex ~= luaIndex then
        if self.m_isMenuExpand then
            self.m_menuTabCellList[luaIndex].tabAniWrapper:ClearTween(false)
            self.m_menuTabCellList[oldIndex].tabAniWrapper:Play("menutabcell_selectout")
        end
        self.m_menuContentCellList[oldIndex].gameObject:SetActive(false)
        if self.m_onChangeContentFuncList[oldIndex].leaveFunc then
            self.m_onChangeContentFuncList[oldIndex].leaveFunc()
        end
    end
    if isInit then
        self.m_menuTabCellList[luaIndex].tabAniWrapper:ClearTween(false)
        self.m_menuTabCellList[oldIndex].tabAniWrapper:SampleClipAtPercent(self.m_isMenuExpand and "menutabcell_select" or "menutabcell_selectout", 1)
    else
        self.m_menuTabCellList[luaIndex].tabAniWrapper:ClearTween(false)
        self.m_menuTabCellList[luaIndex].tabAniWrapper:Play("menutabcell_select")
        if self.m_onChangeContentFuncList[luaIndex].entryFunc then
            self.m_onChangeContentFuncList[luaIndex].entryFunc()
        end
    end
    self.m_menuContentCellList[luaIndex].gameObject:SetActive(true)
    
    if autoExpand and not self.m_isMenuExpand then
        self:_SwitchMenuContentExpand(true)
    elseif self.m_isMenuExpand then
        
        self.m_onChangeContentFuncList[luaIndex].naviFunc()
    end
end





SnapshotCtrl._SwitchMenuContentExpand = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isExpand, isInit)
    self.m_isMenuExpand = isExpand
    if isInit then
        self.view.menuFoldStateCtrl:SetState(isExpand and "Expand" or "Collapse")
        self.m_menuTabCellList[self.m_curSelectMenuIndex].selectStateCtrl:SetState(isExpand and "Select" or "Unselect")
        self.view.menuNodeAniWrapper:SampleClipAtPercent(isExpand and "menunode_in" or "menunode_out", 1)
        self.m_menuTabCellList[self.m_curSelectMenuIndex].tabAniWrapper:SampleClipAtPercent(isExpand and "menutabcell_select" or "menutabcell_selectout", 1)
    else
        self.m_menuTabCellList[self.m_curSelectMenuIndex].tabAniWrapper:Play(isExpand and "menutabcell_select" or "menutabcell_selectout")
        if isExpand then
            self.view.menuNodeAniWrapper:ClearTween(false)
            InputManagerInst.controllerNaviManager:SetTarget(nil)
            self.view.menuNodeAniWrapper:Play("menunode_in", function()
                self.m_onChangeContentFuncList[self.m_curSelectMenuIndex].naviFunc()
            end)
        else
            self.view.menuNodeAniWrapper:ClearTween(false)
            self.view.menuNodeAniWrapper:Play("menunode_out")
        end
        AudioManager.PostEvent(isExpand and "Au_UI_Popup_Photo_Small_Open" or "Au_UI_Popup_Photo_Small_Close")
    end
    if DeviceInfo.usingController then
        self.view.menuTabNode.keyHintPreTabRoot.gameObject:SetActive(isExpand)
        self.view.menuTabNode.keyHintNextTabRoot.gameObject:SetActive(isExpand)
    end
    
    self:_RefreshTaskNodeVisible()
end






SnapshotCtrl._ChangeCharShowMode = HL.Method(HL.Number) << function(self, luaIndex)
    local squadMembers = GameInstance.player.squadManager.squadMembers
    local count = squadMembers.Count
    local mainCharacter = GameInstance.playerController.mainCharacter
    
    local info = showCharConfig[luaIndex]
    local showLeader = info.showLeader
    local showTeamMate = info.showTeamMate
    
    for i = 0, count - 1 do
        local entity = GameInstance.player.squadManager.squadMembers[i];
        if entity ~= mainCharacter then
            CS.Beyond.Gameplay.View.ViewUtils.SetEntityActive(entity, showTeamMate , CS.Beyond.Gameplay.View.ModelVisibleType.Snapshot)
        else
            CS.Beyond.Gameplay.View.ViewUtils.SetEntityActive(entity, showLeader , CS.Beyond.Gameplay.View.ModelVisibleType.Snapshot)
        end
    end
end




SnapshotCtrl._SwitchShowNpc = HL.Method(HL.Boolean) << function(self, isShow)
    self.m_isShowNpc = isShow
    if isShow then
        GameWorld.npcManager:DisableNpcVisibleRule()
    else
        GameWorld.npcManager:EnableNpcVisibleRule(CS.Beyond.Gameplay.NpcEnums.NpcVisibleRuleType.WhiteList, nil)
    end
end




SnapshotCtrl._SwitchShowDropItem = HL.Method(HL.Boolean) << function(self, isShow)
    GameWorld.gameMechManager.itemDropBrain:SetDropItemVisible(isShow)
    self.m_isShowDropItem = isShow
end




SnapshotCtrl._SwitchShowFactoryBuilding = HL.Method(HL.Boolean) << function(self, isShow)
    GameAction.ChangeAllBuildingVisible(isShow, CS.Beyond.Gameplay.Factory.Visibility.EFlag.PHOTO);
    self.m_isShowFactoryBuilding = isShow
end




SnapshotCtrl._ChangeAperture = HL.Method(HL.Number) << function(self, value)
    self.m_cameraCtrl:SetApertureCamera(value)
    self.view.menuContentNode.menuBasicNode.apertureValueTxt.text = self:_GetApertureShowString(value)
end




SnapshotCtrl._GetApertureShowString = HL.Method(HL.Number).Return(HL.String) << function(self, value)
    local result = value
    if (lume.round(value, 0.1) * 10 % 10) < 1 then
        result = string.format("(f/%.0f)", value)
    else
        result = string.format("(f/%.1f)", value)
    end
    return result
end






SnapshotCtrl._ChangeTeamFormation = HL.Method(HL.Number) << function(self, csIndex)
    self.m_curTeamFormationIndex = csIndex
    if csIndex < 0 then
        formationManager:ExitPhotoFormation()
    else
        formationManager:EnterPhotoFormation(formationManager.formationUIData[csIndex].Item1);
    end
end






SnapshotCtrl._ChangeFilter = HL.Method(HL.Number) << function(self, luaIndex)
    local oldIndex = self.m_curSelectFilterIndex
    local oldInfo = self.m_filterInfos[oldIndex]
    local info = self.m_filterInfos[luaIndex]
    self.m_curSelectFilterIndex = luaIndex
    local filterContainer = self.view.filterContainer
    
    if oldIndex > 0 and not oldInfo.isEmpty then
        
        if oldInfo.filterObj ~= nil then
            oldInfo.filterObj:SetActive(false)
        end
        
        if oldInfo.effectInst ~= nil then
            oldInfo.effectInst:SetVisible(false)
        end
    end
    
    if not info.isEmpty then
        
        if info.filterObj ~= nil then
            info.filterObj:SetActive(true)
        else
            if not string.isEmpty(info.filterPath) then
                local path = string.format(UIConst.SNAPSHOT_FILTER_VOLUME_PATH, info.filterPath)
                local prefab = self.loader:LoadGameObject(path)
                info.filterObj = CSUtils.CreateObject(prefab, filterContainer.filterVolume)
                info.filterObj:SetActive(true)
            end
        end
        
        if info.effectInst ~= nil then
            info.effectInst:SetVisible(true)
        else
            if not string.isEmpty(info.effectPath) then
                
                local transform = snapshotSystem.camController.cameraTrans
                info.effectInst = GameInstance.effectManager:CreateStationaryEffect(
                    info.effectPath,
                    transform.position,
                    transform.rotation
                )
            end
        end
        
        self:_ShowFilterName(true)
    else
        self:_ShowFilterName(false)
    end
end




SnapshotCtrl._ShowFilterName = HL.Method(HL.Boolean) << function(self, isShow)
    if isShow then
        local info = self.m_filterInfos[self.m_curSelectFilterIndex]
        if not info.isEmpty then
            self:_ShowTip(info.name)
        end
    else
        self:_ShowTip(nil)
    end
end






SnapshotCtrl._ChangeSticker = HL.Method(HL.Number) << function(self, luaIndex)
    self.m_curSelectStickerIndex = luaIndex
    local info = self.m_stickerInfos[luaIndex]
    local stickerImg = self.view.stickerImg
    if info.isEmpty then
        self.view.stickerTouchPlate.transform.anchoredPosition = Vector2.zero
        self.view.stickerImg.rectTransform.anchoredPosition = Vector2.zero
        self.view.stickerTouchPlate.gameObject:SetActive(false)
        stickerImg.gameObject:SetActive(false)
        self:_EnableStickerEditMode(false)
    else
        self.view.stickerTouchPlate.gameObject:SetActive(true)
        
        self:_EnableStickerEditMode(true)
        
        self.view.stickerMoveHint.gameObject:SetActive(false)
        stickerImg.gameObject:SetActive(true)
        self.view.stickerImgAnimationWrapper:Play("stickertouchimg_in")
        stickerImg:LoadSprite(UIConst.UI_SPRITE_SNAPSHOT_STICKER, info.icon)
        local size = stickerImg.sprite.rect.size * UIManager.uiCanvasRect.rect.size.y / 1080 
        stickerImg.rectTransform:SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, size.x)
        stickerImg.rectTransform:SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, size.y)
        self.view.stickerTouchPlate.transform:SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, size.x)
        self.view.stickerTouchPlate.transform:SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, size.y)
    end
end




SnapshotCtrl._EnableStickerEditMode = HL.Method(HL.Boolean) << function(self, enable)
    self:_SwitchSnapshotUIVisible(not enable)
    Notify(MessageConst.SNAPSHOT_INNER_FORBID_JOYSTICK, { isForbid = enable, key = "stickerMode" })
    if enable then
        if self.m_editStickerCtrl == nil then
            self.m_editStickerCtrl = UIManager:Open(PanelId.SnapshotControllerEditSticker, function()
                self:_EnableStickerEditMode(false)
                self.m_editStickerCtrl:Hide()
            end)
        else
            self.m_editStickerCtrl:Show()
        end
    else
        if not self.m_editStickerCtrl == nil then
            self.m_editStickerCtrl:Hide()
        end
    end
    self.m_inStickerEditMode = enable
    self.view.stickerSurroundBoxImg.enabled = enable
    self.view.stickerTouchPlate.gameObject:SetActive(enable)
    self.view.stickerTouchPlateNoEdit.enabled = not enable
    self.view.stickerMoveHint.gameObject:SetActive(DeviceInfo.usingController and enable)
end




SnapshotCtrl._OnDragSticker = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    local newScreenPos = UIUtils.screenPointToUI(eventData.position, self.uiCamera, self.view.rectTransform)
    self:_SetStickerNewPos(newScreenPos)
end




SnapshotCtrl._SetStickerNewPos = HL.Method(Vector2) << function(self, newPos)
    
    local touchPlate = self.view.stickerTouchPlate.transform
    
    local stickerHalfSize = touchPlate.rect.size / 2
    local minPos = UIManager.uiCanvasRect.offsetMin + stickerHalfSize
    local maxPos = UIManager.uiCanvasRect.offsetMax - stickerHalfSize
    local finalPos = Vector2(lume.clamp(newPos.x, minPos.x, maxPos.x), lume.clamp(newPos.y, minPos.y, maxPos.y))
    touchPlate.anchoredPosition = finalPos
    self.view.stickerImg.rectTransform.anchoredPosition = finalPos
end





SnapshotCtrl._OnClickMenuStickerCell = HL.Method(HL.Number, HL.Any) << function(self, newIndex, newCell)
    local info = self.m_stickerInfos[newIndex]
    local oldIndex = self.m_curSelectStickerIndex
    
    if oldIndex == newIndex and not info.isEmpty then
        if not self.m_inStickerEditMode then
            self:_EnableStickerEditMode(true)
        end
        return
    end
    
    if oldIndex > 0 then
        local oldObj = self.view.menuContentNode.menuStickerNode.stickerList:Get(CSIndex(oldIndex))
        local oldCell = self.m_getStickerCellFunc(oldObj)
        if oldCell then
            oldCell.selectStateCtrl:SetState("Unselect")
            oldCell.editorStateCtrl:SetState("NoEditor")
            InputManagerInst:SetBindingText(oldCell.btn.hoverConfirmBindingId, Language.LUA_SNAPSHOT_STICKER_SELECT_HINT_TEXT)
        end
    end
    
    newCell.selectStateCtrl:SetState("Select")
    if not info.isEmpty then
        newCell.editorStateCtrl:SetState("Editor")
        InputManagerInst:SetBindingText(newCell.btn.hoverConfirmBindingId, Language.LUA_SNAPSHOT_STICKER_MOVE_HINT_TEXT)
    end
    
    self:_ChangeSticker(newIndex)
end










SnapshotCtrl._SwitchAllWorldUIActive = HL.Method(HL.Boolean) << function(self, isActive)
    UIManager.worldObjectRoot.gameObject:SetActive(isActive)
    
end




SnapshotCtrl._ShowTip = HL.Method(HL.Opt(HL.String)) << function(self, content)
    if not content then
        self.view.tipNodeAnimationWrapper:Play("tipnode_out", function()
            self.view.tipNode.gameObject:SetActive(false)
        end)
        return
    end
    self.view.tipNode.gameObject:SetActive(true)
    self.view.tipNodeAnimationWrapper:Play("tipnode_in")
    self.view.tipTxt.text = content
end




SnapshotCtrl._MoveCamera = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    local delta = eventData.delta
    if UNITY_EDITOR and DeviceInfo.usingTouch then
        
        
        if math.abs(delta.x) > 500 or math.abs(delta.y) > 300 then
            return
        end
    end

    if DeviceInfo.usingKeyboard then
        
        
        
        if delta.x == 0 then
            delta.x = InputManagerInst:GetAxis("Mouse X") * 0.9 
        end
        if delta.y == 0 then
            delta.y = InputManagerInst:GetAxis("Mouse Y") * 0.63 
        end
    end

    local deltaX = UIUtils.getNormalizedScreenX(delta.x)
    local deltaY = UIUtils.getNormalizedScreenY(delta.y)
    self.m_cameraCtrl:SurroundMoveCamera(deltaX, deltaY)
end



SnapshotCtrl._ClearFilter = HL.Method() << function(self)
    for _, info in pairs(self.m_filterInfos) do
        if info.filterObj ~= nil then
            GameObject.Destroy(info.filterObj)
            info.filterObj = nil
        end
        if info.effectInst ~= nil then
            info.effectInst:Finish()
            info.effectInst = nil
        end
    end
end







SnapshotCtrl._SetForbid = HL.Method(HL.Table, HL.Boolean, HL.String) << function(self, forbidRecord, isForbid, key)
    local preForbid = next(forbidRecord.forbidKeys) ~= nil
    if isForbid then
        forbidRecord.forbidKeys[key] = true
    else
        forbidRecord.forbidKeys[key] = nil
    end
    local nowForbid = next(forbidRecord.forbidKeys) ~= nil
    if nowForbid ~= preForbid then
        self[forbidRecord.forbidFuncName](self, nowForbid)
    end
end




SnapshotCtrl._IsForbid = HL.Method(HL.Table).Return(HL.Boolean) << function(self, forbidRecord)
    return next(forbidRecord.forbidKeys) ~= nil
end




SnapshotCtrl._ShowForbidToast = HL.Method(HL.Table) << function(self, forbidRecord)
    if forbidRecord.forbidKeys[FIRST_PERSON_FORBID_KEY] then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FIRST_PERSON_MODE_FORBID_TOAST)
    else
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FORBID_COMMON_TOAST)
    end
end




SnapshotCtrl._ForbidSwitchMoveMode = HL.Method(HL.Boolean) << function(self, isForbid)
    self.view.switchMoveModeTog.interactable = not isForbid
    self.view.hintNode.switchMoveModeNode.gameObject:SetActive(not isForbid)
end




SnapshotCtrl._ForbidHideChar = HL.Method(HL.Boolean) << function(self, isForbid)
    local basicNode = self.view.menuContentNode.menuBasicNode
    if isForbid then
        basicNode.showCharDropDown:SetSelected(0)
    end
    basicNode.showCharDropDown.interactable = not isForbid
    basicNode.showCharDropDownForbidToastBtn.gameObject:SetActive(isForbid)
end




SnapshotCtrl._ForbidAperture = HL.Method(HL.Boolean) << function(self, isForbid)
    local basicNode = self.view.menuContentNode.menuBasicNode
    if isForbid then
        basicNode.apertureSlider.value = self.view.config.MAX_APERTURE
        basicNode.apertureSlider.interactable = false
    else
        basicNode.apertureSlider.interactable = true
    end
    basicNode.apertureSliderForbidToastBtn.gameObject:SetActive(isForbid)
end




SnapshotCtrl._ForbidSwitchFormation = HL.Method(HL.Boolean) << function(self, isForbid)
    local formationNode = self.view.menuContentNode.menuFormationNode
    if isForbid then
        formationNode.formationTog.isOn = false
        formationNode.formationTog.interactable = false
    else
        formationNode.formationTog.interactable = true
    end
end




SnapshotCtrl._ForbidFirstPersonPerspective = HL.Method(HL.Boolean) << function(self, isForbid)
    if isForbid then
        self.view.personPerspectiveBtn.interactable = false
        self:_SwitchPersonPerspectiveMode(false, true)
    else
        self.view.personPerspectiveBtn.interactable = true
    end
end




SnapshotCtrl._ForbidMoveOrRotateCam = HL.Method(HL.Boolean) << function(self, isForbid)
    self.m_cameraCtrl:SetForbidMoveOrRotate(isForbid)
end




SnapshotCtrl._ForbidPlayerMove = HL.Method(HL.Boolean) << function(self, isForbid)
    self:Notify(MessageConst.SNAPSHOT_INNER_FORBID_PLAYER_MOVE, isForbid)
end





SnapshotCtrl.OnSquadInFightChanged = HL.Method(HL.Opt(HL.Any)) << function(self)
    local inFight = Utils.isInFight()
    self:_SetForbid(self.m_forbidRecords.switchFormation, inFight, "Fight")
    self:_SetForbid(self.m_forbidRecords.firstPersonPerspective, inFight, "Fight")
    self:_SetForbid(self.m_forbidRecords.hideChar, inFight, "Fight")
end




SnapshotCtrl.OnForbidSystemChanged = HL.Method(HL.Any) << function(self, args)
    local forbidType, isForbid = unpack(args)
    if forbidType == ForbidType.ForbidMove then
        if isForbid then
            if not snapshotSystem.isCameraMoveMode then
                self.view.switchMoveModeTog.isOn = true
            end
            self:_SetForbid(self.m_forbidRecords.playerMoveMode, true, "ForbidSystem")
        else
            self:_SetForbid(self.m_forbidRecords.playerMoveMode, false, "ForbidSystem")
        end
    elseif forbidType == ForbidType.ForbidGeneralAbility then
        
        local forbidParams = Utils.getForbiddenReason(ForbidType.ForbidGeneralAbility)
        if forbidParams:IsStyleForbidden(CS.Beyond.Gameplay.GeneralAbilityForbidParams.ForbidStyle.Snapshot) then
            self:_CloseSelf()
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SNAPSHOT_FORBID_SNAPSHOT)
            logger.info("拍照模式当前被禁用")
        end
    end
end



SnapshotCtrl.OnListenerIdentifyChanged = HL.Method() << function(self)
    self:_UpdateIdentifyInfo()
    self:_RefreshIdentifyTask()
    self:_RefreshTaskNodeVisible()
end



SnapshotCtrl.AutoCloseSelfOnInterrupt = HL.Method(HL.Opt(HL.Any)) << function(self)
    self:_CloseSelf()
end



SnapshotCtrl.OnCinematicToQueue = HL.Method() << function(self)
    if UIManager:IsOpen(PanelId.CommonShare) then
        self.m_cinematicInQueueWaitCloseSnapshot = true
    else
        self:_CloseSelf()
    end
end




HL.Commit(SnapshotCtrl)
