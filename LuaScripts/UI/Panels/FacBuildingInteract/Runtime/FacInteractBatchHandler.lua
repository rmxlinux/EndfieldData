local handlerBase = require_ex('UI/Panels/FacBuildingInteract/Runtime/FacInteractHandlerBase')


FacInteractBatchHandler = HL.Class('FacInteractBatchHandler', handlerBase.FacInteractHandlerBase)

FacInteractBatchHandler.m_dragging = HL.Field(HL.Boolean) << false
FacInteractBatchHandler.m_dragDirty = HL.Field(HL.Boolean) << false
FacInteractBatchHandler.m_oldBatchSelectedTargetIds = HL.Field(HL.Table)
FacInteractBatchHandler.m_dragStartWorldPos = HL.Field(HL.Any)
FacInteractBatchHandler.m_dragTargetsInBatchModeUpdateKey = HL.Field(HL.Number) << -1
FacInteractBatchHandler.m_needUpdateDragTargetsInBatchMode = HL.Field(HL.Boolean) << false
FacInteractBatchHandler.m_dragPos = HL.Field(Vector2)
FacInteractBatchHandler.m_hoverGridRectInt = HL.Field(CS.UnityEngine.RectInt)

FacInteractBatchHandler.FacInteractBatchHandler = HL.Constructor(HL.Forward('FacInteractSystem')) << function(self, host)
    FacInteractBatchHandler.SuperConstructor(self, host)
end

FacInteractBatchHandler.BuildPresentationModel = HL.Override(HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output)
    return self:_BuildCommonPresentation(input, output, {
        showOptions = false,
        isTopView = true,
        destroyMode = true,
        allowSubBuilding = false,
        controllerEmptyGrid = DeviceInfo.usingController,
        suppressWorldEffects = DeviceInfo.usingTouch,
        useAsyncRst = false,
    })
end

FacInteractBatchHandler.OnSuspend = HL.Override() << function(self)
    FacInteractBatchHandler.Super.OnSuspend(self)
    self.m_host:StopBatchControllerDrag()
    if self:IsDraggingInBatchMode() then
        self:OnDragEnd()
    end
    self.m_dragging = false
    self.m_dragDirty = false
end

FacInteractBatchHandler.OnResume = HL.Override() << function(self)
    self.m_dragDirty = false
end

FacInteractBatchHandler.OnExit = HL.Override() << function(self)
    if not InputManagerInst.inChangingInputDevice then
        self.m_host:ClearAllBatchTargets()
    end
    FacInteractBatchHandler.Super.OnExit(self)
end

FacInteractBatchHandler.IsDraggingInBatchMode = HL.Override().Return(HL.Boolean) << function(self)
    return self.m_dragTargetsInBatchModeUpdateKey > 0
end

FacInteractBatchHandler.MarkBatchDragDirty = HL.Override() << function(self)
    if self.m_dragTargetsInBatchModeUpdateKey > 0 then
        self.m_needUpdateDragTargetsInBatchMode = true
    end
end

FacInteractBatchHandler.OnTick = HL.Override() << function(self)
    if not DeviceInfo.usingTouch then
        local screenPos = InputManager.mousePosition
        local _, worldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(CameraManager.mainCamera:ScreenPointToRay(screenPos))
        CSFactoryUtil.SetHoverGrid(CS.UnityEngine.Vector2Int(math.floor(worldPos.x), math.floor(worldPos.z)))
    end

    local curScreenWorldRect = CSFactoryUtil.GetCurScreenWorldRect(CSFactoryUtil.Padding(0, 0, 0, 0), 6.5)
    local posXMin = math.floor(curScreenWorldRect.xMin)
    local posZMin = math.floor(curScreenWorldRect.yMin)
    local posXMax = math.ceil(curScreenWorldRect.xMax)
    local posZMax = math.ceil(curScreenWorldRect.yMax)
    local width = posXMax - posXMin
    local height = posZMax - posZMin
    local rectInt = CS.UnityEngine.RectInt(posXMin, posZMin, width, height)
    if not (self.m_hoverGridRectInt and self.m_hoverGridRectInt:Equals(rectInt)) then
        GameInstance.remoteFactoryManager.visual:UpdateAndShowGrid3D(rectInt)
        self.m_hoverGridRectInt = rectInt
    end

    GameInstance.remoteFactoryManager.batchSelect:TryUpdateRange()

    if not DeviceInfo.usingTouch then
        local input, output = self.m_host:QueryPoint(
            FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview
        )
        self:_PublishTargetOutput(input, output)
    end
end

FacInteractBatchHandler.OnClick = HL.Override(HL.Any) << function(self, eventData)
    local input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Click, eventData)
    self:_PublishTargetOutput(input, output)
    local target = output.primaryTarget
    local nodeId = target and target.nodeId
    if nodeId then
        if Utils.isInBlackbox() and CSFactoryUtil.IsPreplacedBuilding(nodeId) then
            
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BATCH_MODE_CLICK_BLACKBOX_NODE)
            return
        end
    end
    local unitIndex
    local selectSingleGrid
    if DeviceInfo.usingKeyboard then
        selectSingleGrid = InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.LeftControl)
    elseif DeviceInfo.usingController then
        selectSingleGrid = InputManagerInst:GetKey(CS.Beyond.Input.GamepadKeyCode.LB)
    end
    if target and target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Pipe then
        if selectSingleGrid then
            unitIndex = target.unitIndex
        end
    elseif target and target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Belt then
        unitIndex = target.unitIndex
        if not selectSingleGrid then
            unitIndex = nil
        end
    end
    if not nodeId then
        return
    end
    if FactoryUtils.isInvalidBuilding(nodeId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FACTORY_INVALID_BUILDING_OP_DISABLE_TOAST)
        return 
    end
    local slotId = FactoryUtils.getPendingBuildingNodeSlotId(nodeId)
    if slotId then
        unitIndex = nil
    end
    if not unitIndex then
        local isAdd = LuaSystemManager.factory.batchSelectTargets[nodeId] ~= true
        if slotId then
            
            CSFactoryUtil.AddAllSlotNodes(slotId)
            for _, v in pairs(CSFactoryUtil.s_tmpNodeIdList) do
                self:SelectBatchTarget(v, isAdd, nil)
            end
        else
            self:SelectBatchTarget(nodeId, isAdd, nil)
        end
    else
        local indexList = LuaSystemManager.factory.batchSelectTargets[nodeId]
        if not indexList then
            
            self:SelectBatchTarget(nodeId, true, unitIndex)
        else
            local isAdd
            if indexList == true then
                isAdd = false
            else
                isAdd = indexList[unitIndex] == nil
            end
            self:SelectBatchTarget(nodeId, isAdd, unitIndex)
        end
    end
end








FacInteractBatchHandler.OnLongPress = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    if DeviceInfo.usingTouch then
        
        self.m_host:PublishBatchToggle(true)
        GameInstance.mobileMotionManager:PostEventCommonShort()
    elseif DeviceInfo.usingKeyboard then
        if next(LuaSystemManager.factory.batchSelectTargets) then
            local _, desCtrl = UIManager:IsOpen(PanelId.FacDestroyMode)
            desCtrl:TryStartBatchMove()
        end
    end
end

FacInteractBatchHandler.OnDragBegin = HL.Override(HL.Any, HL.Opt(HL.Boolean)) << function(self, pos, fromController)
    if not fromController and (not LuaSystemManager.factory.inDragSelectBatchMode
            or InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse2)) then
        return
    end
    self.m_dragging = true
    self.m_dragDirty = true
    if DeviceInfo.usingKeyboard then
        
        LuaSystemManager.factory:ChangeIsReverseSelect(
            InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1)
        )
    end
    self.m_oldBatchSelectedTargetIds = {}
    for id, info in pairs(LuaSystemManager.factory.batchSelectTargets) do
        self.m_oldBatchSelectedTargetIds[id] = lume.copy(info)
    end
    local _
    _, self.m_dragStartWorldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(
        CameraManager.mainCamera:ScreenPointToRay(pos:XY())
    )
    LuaSystemManager.factory:ToggleAutoMoveTopViewCam(Vector2.one)
    Notify(MessageConst.FAC_ON_DRAG_BEGIN_IN_BATCH_MODE)

    self.m_host:PublishDragFrame({
        op = FacConst.FAC_INTERACT_DRAG_FRAME_OP.Begin,
        reverse = LuaSystemManager.factory.isReverseBatchSelect,
    })

    self.m_needUpdateDragTargetsInBatchMode = false
    self.m_dragTargetsInBatchModeUpdateKey = LuaUpdate:Remove(self.m_dragTargetsInBatchModeUpdateKey)
    self.m_dragTargetsInBatchModeUpdateKey = LuaUpdate:Add("TailTick", function()
        if self.m_needUpdateDragTargetsInBatchMode then
            self.m_needUpdateDragTargetsInBatchMode = false
            self:_UpdateDragTargetsInBatchMode()
        end
    end)

    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })

    

    
    InputManagerInst:ToggleBinding(UIManager.commonTouchPanel.onClick.bindingId, false)
end

FacInteractBatchHandler.OnDrag = HL.Override(HL.Opt(HL.Any, HL.Boolean)) << function(self, eventData, fromController)
    if not fromController and (not LuaSystemManager.factory.inDragSelectBatchMode
            or InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse2)) then
        return
    end
    self.m_dragDirty = true
    self.m_needUpdateDragTargetsInBatchMode = true
    if eventData then
        self.m_dragPos = eventData.position
    end
end

FacInteractBatchHandler.OnDragEnd = HL.Override(HL.Opt(HL.Any)) << function(self, pos)
    if not self.m_dragging then
        return
    end
    self.m_dragging = false
    self.m_dragDirty = false
    if DeviceInfo.usingKeyboard then
        LuaSystemManager.factory:ChangeIsReverseSelect(false)
    end
    self.m_host:PublishDragFrame({ op = FacConst.FAC_INTERACT_DRAG_FRAME_OP.End })
    self.m_oldBatchSelectedTargetIds = {}
    self.m_dragStartWorldPos = nil
    LuaSystemManager.factory:ToggleAutoMoveTopViewCam()
    Notify(MessageConst.FAC_ON_DRAG_END_IN_BATCH_MODE)

    self.m_dragTargetsInBatchModeUpdateKey = LuaUpdate:Remove(self.m_dragTargetsInBatchModeUpdateKey)

    

    
    InputManagerInst:ToggleBinding(UIManager.commonTouchPanel.onClick.bindingId, true)

    if DeviceInfo.usingTouch then
        
        self.m_host:PublishBatchToggle(false)
    end
end

FacInteractBatchHandler.OnPress = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    local isLongPressToDragHint
    if DeviceInfo.usingTouch then
        
        self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
        isLongPressToDragHint = true
    elseif DeviceInfo.usingKeyboard then
        
        local _, desCtrl = UIManager:IsOpen(PanelId.FacDestroyMode)
        if not desCtrl:CheckBatchActionValid(true, true) then
            return
        end
        if next(LuaSystemManager.factory.batchSelectTargets) == nil then
            return
        end
        self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    else
        return
    end
    self.m_host:PublishPressHint({
        op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Start,
        isLongPressToDragHint = isLongPressToDragHint == true,
    })
end

FacInteractBatchHandler.OnRelease = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    if DeviceInfo.usingTouch then
        self.m_host:PublishBatchToggle(false)
    end
end

FacInteractBatchHandler._UpdateDragTargetsInBatchMode = HL.Method() << function(self)
    local startWorldPos = self.m_dragStartWorldPos
    local endMousePos
    if DeviceInfo.usingTouch and self.m_dragPos then
        endMousePos = self.m_dragPos:XY()
        self.m_dragPos = nil
    else
        endMousePos = InputManager.mousePosition
    end
    local _, endWorldPos = CSFactoryUtil.SampleLevelRegionPointWithRay(CameraManager.mainCamera:ScreenPointToRay(endMousePos))
    

    
    local posXMin = math.floor(math.min(startWorldPos.x, endWorldPos.x))
    local posZMin = math.floor(math.min(startWorldPos.z, endWorldPos.z))
    local posXMax = math.ceil(math.max(startWorldPos.x, endWorldPos.x))
    local posZMax = math.ceil(math.max(startWorldPos.z, endWorldPos.z))

    
    self.m_host:PublishDragFrame({
        op = FacConst.FAC_INTERACT_DRAG_FRAME_OP.Update,
        worldMin = Vector3(posXMin, startWorldPos.y, posZMin),
        worldMax = Vector3(posXMax, startWorldPos.y, posZMax),
        dragStartWorldPos = startWorldPos,
        dragEndWorldPos = endWorldPos,
    })

    
    local _, output = self.m_host:QueryRect({
        startWorldPos = startWorldPos,
        endWorldPos = endWorldPos,
    })
    local targetNodeIdTbl = output.targetMap

    local old = self.m_oldBatchSelectedTargetIds
    local target = targetNodeIdTbl
    local current = LuaSystemManager.factory.batchSelectTargets
    local expandTrue = function(nodeId)
        local t = {}
        local length = CSFactoryUtil.GetConveyorLength(Utils.getCurrentChapterId(), nodeId)
        for i = 0, length - 1 do
            t[i] = true
        end
        return t
    end

    local toAdd, toRemove
    if LuaSystemManager.factory.isReverseBatchSelect then
        
        toAdd = Utils.nestedBoolSetSubtract(old, target, expandTrue)
        toRemove = target
    else
        
        toRemove = Utils.nestedBoolSetSubtract(current, Utils.nestedBoolSetUnion(target, old), expandTrue)
        toAdd = target
    end

    Utils.foreachNestedBoolSet(toAdd, function(nodeId, unitIndex)
        self:SelectBatchTarget(nodeId, true, unitIndex)
    end)
    Utils.foreachNestedBoolSet(toRemove, function(nodeId, unitIndex)
        self:SelectBatchTarget(nodeId, false, unitIndex)
    end)
end

FacInteractBatchHandler.ExecuteInteract = HL.Override(HL.Table) << function(self, option)
    local buildingNodeId = option.buildingNodeId
    if not string.isEmpty(buildingNodeId) then
        
        if Utils.isInSettlementDefenseDefending()
                and GameInstance.player.towerDefenseSystem.towerDefenseGame:IsPreBattleBuilding(buildingNodeId) then
            
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FORBID_DESTROY_PRE_BATTLE_BUILDING)
            return
        end
        local noConfirm = true
        local hintText
        if FactoryUtils.isOthersSocialBuilding(buildingNodeId) then
            noConfirm = false 
            hintText = Language.LUA_FAC_DEL_SOCIAL_BUILDING_CONFIRM
        end
        FactoryUtils.delBuilding(buildingNodeId, nil, noConfirm, hintText)
        return
    end

    local nodeId = option.nodeId
    
    if not nodeId or not FactoryUtils.canDelBuilding(nodeId, true) then
        return
    end
    local core = GameInstance.player.remoteFactory.core
    if option.isAll or not option.unitIndex then
        core:Message_OpDismantle(Utils.getCurrentChapterId(), nodeId)
    else
        GameInstance.remoteFactoryManager:DismantleUnitFromConveyor(
            Utils.getCurrentChapterId(), nodeId, option.unitIndex
        )
    end
    AudioAdapter.PostEvent("au_int_belt_remove_short")
end

FacInteractBatchHandler.ClearAllBatchTargets = HL.Override() << function(self)
    self.m_host:ClearAllBatchTargets()
end

FacInteractBatchHandler.SelectBatchTarget = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number))
        << function(self, nodeId, isAdd, unitIndex)
    if unitIndex then
        GameInstance.remoteFactoryManager.batchSelect:ChangeBatchTarget(nodeId, isAdd, unitIndex)
    else
        GameInstance.remoteFactoryManager.batchSelect:ChangeBatchTarget(nodeId, isAdd)
    end

    local targets = LuaSystemManager.factory.batchSelectTargets
    local curChapterId = Utils.getCurrentChapterId()
    local info = targets[nodeId]
    local isChanged
    if not unitIndex then
        
        if isAdd then
            if info ~= true then
                local nodeInst = GameInstance.remoteFactoryManager.currentChapterInfo:GetNode(nodeId)
                local placeInst = GameInstance.remoteFactoryManager.currentChapterInfo:GetNodeIncludingPending(nodeId)
                if nodeInst or placeInst and placeInst.belongSlot then
                    isChanged = true
                    targets[nodeId] = true
                    GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                        curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, true
                    )
                end
            end
        elseif info then
            isChanged = true
            targets[nodeId] = nil
            GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, false
            )
            if FactoryUtils.isPendingBuildingNode(nodeId) then
                
                
                GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                    curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.TO_BE_BUILD, true
                )
            end
        end
    else
        
        if isAdd then
            if info == true then
                return
            elseif not info then
                info = {}
                targets[nodeId] = info
            elseif info[unitIndex] then
                return
            end
            isChanged = true
            info[unitIndex] = true
            GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                curChapterId, nodeId, CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, true, unitIndex
            )
        else
            if not info then
                return
            elseif info == true then
                isChanged = true
                info = {}
                targets[nodeId] = info
                local length = CSFactoryUtil.GetConveyorLength(curChapterId, nodeId)
                for k = 0, length - 1 do
                    if k ~= unitIndex then
                        info[k] = true
                        
                        GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                            curChapterId, nodeId,
                            CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, true, k
                        )
                    else
                        GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                            curChapterId, nodeId,
                            CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, false, unitIndex
                        )
                    end
                end
            elseif not info[unitIndex] then
                return
            else
                isChanged = true
                info[unitIndex] = nil
                if not next(info) then
                    targets[nodeId] = nil
                end
                GameInstance.remoteFactoryManager:SetNodeBlueprintEffectType(
                    curChapterId, nodeId,
                    CS.Beyond.Gameplay.Factory.BlueprintState.EffectType.MOVING, false, unitIndex
                )
            end
        end
    end

    Notify(MessageConst.FAC_ON_TOGGLE_BATCH_TARGET) 
    if isChanged then
        AudioAdapter.PostEvent(
            isAdd and "Au_UI_Menu_FacBuildModePanel_Open" or "Au_UI_Menu_FacBuildModePanel_Close"
        )
    end
end


HL.Commit(FacInteractBatchHandler)
