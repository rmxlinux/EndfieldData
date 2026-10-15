local handlerBase = require_ex('UI/Panels/FacBuildingInteract/Runtime/FacInteractHandlerBase')


FacInteractDestroyHandler = HL.Class('FacInteractDestroyHandler', handlerBase.FacInteractHandlerBase)

FacInteractDestroyHandler.FacInteractDestroyHandler = HL.Constructor(HL.Forward('FacInteractSystem')) << function(self, host)
    FacInteractDestroyHandler.SuperConstructor(self, host)
end

FacInteractDestroyHandler.BuildPresentationModel = HL.Override(HL.Table, HL.Table).Return(HL.Table)
        << function(self, input, output)
    local isTopView = input.viewMode == FacConst.FAC_INTERACT_TARGET_VIEW_MODE.TopView
    return self:_BuildCommonPresentation(input, output, {
        showOptions = not isTopView,
        isTopView = isTopView,
        destroyMode = true,
        allowSubBuilding = false,
        controllerEmptyGrid = isTopView and DeviceInfo.usingController,
        suppressWorldEffects = isTopView and DeviceInfo.usingTouch,
        useAsyncRst = false,
    })
end

FacInteractDestroyHandler.OnTick = HL.Override() << function(self)
    if LuaSystemManager.factory.inTopView and DeviceInfo.usingTouch then
        
        return
    end
    local input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Preview)
    self:_PublishTargetOutput(input, output)
end

FacInteractDestroyHandler.OnClick = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end

    Notify(MessageConst.FAC_TOPVIEW_HIDE_MULTI_TARGET_MENU)
    local input, output = self.m_host:QueryPoint(FacConst.FAC_INTERACT_TARGET_PURPOSE.Click, eventData)
    self:_PublishTargetOutput(input, output)
    local target = output.primaryTarget
    if not target then
        return
    end
    if target.type == FacConst.FAC_INTERACT_TARGET_TYPE.Building then
        self:ExecuteInteract({ buildingNodeId = target.nodeId })
    else
        self:ExecuteInteract({
            nodeId = target.nodeId,
            unitIndex = target.unitIndex,
            logisticPos = target.logisticPos,
        })
    end
    self.m_host:ClearInteractPresentation()
end

FacInteractDestroyHandler.OnLongPress = HL.Override(HL.Any) << function(self, eventData)
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

FacInteractDestroyHandler.OnDragBegin = HL.Override(HL.Any, HL.Opt(HL.Boolean)) << function(self, pos, fromController)
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
end

FacInteractDestroyHandler.OnDragEnd = HL.Override(HL.Opt(HL.Any)) << function(self, pos)
end

FacInteractDestroyHandler.OnPress = HL.Override(HL.Any) << function(self, eventData)
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

FacInteractDestroyHandler.OnRelease = HL.Override(HL.Any) << function(self, eventData)
    if not LuaSystemManager.factory.inTopView then
        return
    end
    self.m_host:PublishPressHint({ op = FacConst.FAC_INTERACT_PRESS_HINT_OP.Stop })
    if DeviceInfo.usingTouch then
        self.m_host:PublishBatchToggle(false)
    end
end

FacInteractDestroyHandler.ExecuteInteract = HL.Override(HL.Table) << function(self, option)
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


HL.Commit(FacInteractDestroyHandler)
