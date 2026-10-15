







local handlerBase = require_ex('UI/Panels/FacBuildMode/FacBuildModeHandler')
local FacBuildCheckResultHint = require_ex('UI/Panels/FacBuildMode/FacBuildCheckResultHint')


local KeyHints = {
    newBuilding = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    newBuildingInTopView = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_continuous_confirm",
        "fac_build_cancel_alter",
    },
    oldBuilding = {
        "fac_build_mode_delete",
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    signBuilding = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_sign_reset",
        "fac_build_cancel_alter",
    },
}


FacBuildModeHandler_Building = HL.Class('FacBuildModeHandler_Building', handlerBase.FacBuildModeHandler)


FacBuildModeHandler_Building.m_suppressCancelCallback = HL.Field(HL.Boolean) << false

FacBuildModeHandler_Building.FacBuildModeHandler_Building = HL.Constructor(HL.Forward('FacBuildModeCtrl')) << function(self, host)
    FacBuildModeHandler_Building.SuperConstructor(self, host)
    self.m_provider = GameInstance.remoteFactoryManager.buildingPlacementProvider
end

FacBuildModeHandler_Building._GetCurBuildingMode = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    return GameInstance.remoteFactoryManager.interact.currentBuildingMode
end




FacBuildModeHandler_Building.OnEnter = HL.Override(HL.Table) << function(self, args)
    FacBuildModeHandler_Building.Super.OnEnter(self, args)
    local host = self.m_host
    local provider = self.m_provider

    
    local initWorldPos
    do
        local pointerPos
        if args.initMousePos then
            pointerPos = Vector3(args.initMousePos.x, args.initMousePos.y, 0)
        else
            pointerPos = host:_InDragMode() and Vector3(Screen.width / 2, Screen.height / 2, 0) or host:_GetCurPointerPressPos()
        end
        local camRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        local _, worldPos = provider:SampleGroundPoint(camRay)
        initWorldPos = worldPos
    end

    local buildingId, itemData
    local nodeId = args.nodeId
    if nodeId then
        
        host.m_buildingNodeId = nodeId
        local node = FactoryUtils.getBuildingNodeHandler(nodeId)
        buildingId = node.templateId
        itemData = FactoryUtils.getBuildingItemData(buildingId)
        host:_RefreshKeyHint(KeyHints.oldBuilding)
        if not args.initMousePos and DeviceInfo.usingTouch and LuaSystemManager.factory.inTopView then
            
            if args.initDir then
                provider:BeginMoveAtNodePosition(nodeId, args.initDir * 90)
            else
                provider:BeginMoveAtNodePosition(nodeId)
            end
        elseif args.initDir then
            provider:BeginMove(nodeId, initWorldPos, args.initDir * 90)
        else
            provider:BeginMove(nodeId, initWorldPos) 
        end
        host.view.moveBuildingHint.gameObject:SetActive(true)
    else
        
        host.m_buildingNodeId = nil
        local itemId = args.itemId
        itemData = Tables.itemTable[itemId]
        local buildingItemData = Tables.factoryBuildingItemTable[itemId]
        buildingId = buildingItemData.buildingId
        host:_RefreshKeyHint(LuaSystemManager.factory.inTopView and KeyHints.newBuildingInTopView or KeyHints.newBuilding)
        local initDir = args.initDir
        if initDir == nil then
            initDir = math.floor(((CameraManager.mainCamera.transform.eulerAngles.y + 45) % 360) / 90) % 4
        end
        
        if args.initDir == nil and FacConst.SIGN_BUILDING_EXTRA_SETTING_PANEL[buildingId] then
            initDir = (initDir + 1) % 4
        end
        provider:BeginPlace(buildingId, initWorldPos, initDir * 90)
        host.view.moveBuildingHint.gameObject:SetActive(false)
        local mode = GameInstance.remoteFactoryManager.interact.buildingMode
        mode.onPlaceBuilding = mode.onPlaceBuilding - host.m_onPlaceFinish
        mode.onPlaceBuilding = mode.onPlaceBuilding + host.m_onPlaceFinish
    end
    host.m_buildingId = buildingId
    host.m_itemData = itemData

    self:_UpdateAutoConnectExtraHint()

    local bData = Tables.factoryBuildingTable[buildingId]

    do 
        if host.m_workingRange then
            if host.m_workingRange.gameObject then
                GameObject.Destroy(host.m_workingRange.gameObject)
            end
            host.m_workingRange = nil
        end
        local effectPath = nil
        if bData then
            if bData.type == GEnums.FacBuildingType.PowerPole or bData.type == GEnums.FacBuildingType.PowerDiffuser then
                effectPath = FacConst.POLE_RANGE_EFFECT_MAP[buildingId]
            elseif bData.type == GEnums.FacBuildingType.EnvGenWithActivator then
                effectPath = FacConst.VAPORIZER_RANGE_EFFECT
            end
        end
        if effectPath then
            local prefab = host.loader:LoadGameObject(effectPath)
            local obj = host:_CreateWorldGameObject(prefab)
            host.m_workingRange = Utils.wrapLuaNode(obj)
            obj.gameObject:SetActive(false)
        end
    end

    do 
        if host.m_battleRange then
            if host.m_battleRange.gameObject then
                GameObject.Destroy(host.m_battleRange.gameObject)
            end
            host.m_battleRange = nil
        end
        local battleData = GameInstance.remoteFactoryManager.staticData:QueryBattleData(buildingId)
        if battleData then
            local effectPath = string.format(FacConst.EFFECT_PREFAB_PATH_FORMAT, battleData.attackRangeEffect)
            local prefab = host.loader:LoadGameObject(effectPath)
            local obj = host:_CreateWorldGameObject(prefab)
            host.m_battleRange = Utils.wrapLuaNode(obj)
            obj.gameObject:SetActive(false)
        end
    end
    self:_UpdateFollowerState(true)

    host:_SetCamState(bData.buildCamState)
end

FacBuildModeHandler_Building.OnPostEnter = HL.Override() << function(self)
    
    self:_NotifyPowerPoleTravelHint()
    self.m_host:_ProcessSignBuildSetting()
end

FacBuildModeHandler_Building.GetEnterMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_ENTER_BUILDING_MODE
end

FacBuildModeHandler_Building.GetEnterMessageArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_host.m_itemData.id
end

FacBuildModeHandler_Building.GetExitMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_EXIT_BUILDING_MODE
end

FacBuildModeHandler_Building.OnExit = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    if not ctx.isSwitching and not self.m_suppressCancelCallback then
        local onCancel = self.m_args.onCancel
        if onCancel then
            onCancel()
        end
    end

    
    host.m_sizeIndicator.followerObject.getTargetPosInfo = nil
    host.m_sizeIndicator.gameObject:SetActiveIfNecessary(false)
    if host.m_workingRange then
        host.m_workingRange.followerObject.getTargetPosInfo = nil
        if host.m_workingRange.gameObject then
            GameObject.Destroy(host.m_workingRange.gameObject)
        end
        host.m_workingRange = nil
    end
    if host.m_battleRange then
        host.m_battleRange.followerObject.getTargetPosInfo = nil
        if host.m_battleRange.gameObject then
            GameObject.Destroy(host.m_battleRange.gameObject)
        end
        host.m_battleRange = nil
    end
    host.m_fluidSprayRange.followerObject.getTargetPosInfo = nil
    host.m_fluidSprayRange.gameObject:SetActive(false)
    host:_ResetMoveBuildingHintState()

    
    local mode = GameInstance.remoteFactoryManager.interact.buildingMode
    mode.onPlaceBuilding = mode.onPlaceBuilding - host.m_onPlaceFinish
end






FacBuildModeHandler_Building.OnTick = HL.Override(HL.Table) << function(self, ctx)
    local host = self.m_host
    local provider = self.m_provider
    if not ctx.usingDrag or ctx.isDragging then
        
        if ctx.sampleOk then
            provider:UpdatePreview(ctx.pointerWorldPos)
            ctx.posChanged = true
        end
    else
        
        local ok, buildingCenterPos = provider:TryGetPreviewPose()
        if ok then
            local buildingScreenPos = CameraManager.mainCamera:WorldToScreenPoint(buildingCenterPos)
            buildingScreenPos.z = 0
            local newScreenPos = Vector3.zero
            newScreenPos.x = lume.clamp(buildingScreenPos.x, host.view.config.DRAG_MODE_BUILDING_PADDING_X.x, Screen.width - host.view.config.DRAG_MODE_BUILDING_PADDING_X.y)
            newScreenPos.y = lume.clamp(buildingScreenPos.y, host.view.config.DRAG_MODE_BUILDING_PADDING_Y.x, Screen.height - host.view.config.DRAG_MODE_BUILDING_PADDING_Y.y)
            if newScreenPos ~= buildingScreenPos then
                local camRay = CameraManager.mainCamera:ScreenPointToRay(newScreenPos)
                local sampled, clampedWorldPos = provider:SampleGroundPoint(camRay)
                if sampled then
                    provider:UpdatePreview(clampedWorldPos)
                end
                _, buildingCenterPos = provider:TryGetPreviewPose()
                ctx.posChanged = true
            end
            ctx.customGridCenter = buildingCenterPos
        end
    end
    if not host.m_buildingNodeId and DeviceInfo.usingKeyboard then
        Notify(MessageConst.CHANGE_MOUSE_ICON_HINT, {
            name = "FacBuildModeCtrl-ContinuousBuild",
            type = host:_EnableContinueBuild() and UIConst.MOUSE_ICON_HINT.ContinuousBuild or UIConst.MOUSE_ICON_HINT.Default,
        })
    end
    self:_ApplyCustomGridCenter(ctx)
end


FacBuildModeHandler_Building._ApplyCustomGridCenter = HL.Method(HL.Table) << function(self, ctx)
    local curMode = self:_GetCurBuildingMode()
    if not curMode then
        return
    end
    curMode.useCustomGridCenter = LuaSystemManager.factory.inTopView
    if not curMode.useCustomGridCenter then
        return
    end
    
    
    
    
    if ctx.customGridCenter then
        curMode.customGridCenter = ctx.customGridCenter
    elseif ctx.posChanged then
        curMode.customGridCenter = GameInstance.remoteFactoryManager:ViewToLogical(ctx.rawPointerWorldPos)
    end
end

FacBuildModeHandler_Building.OnPostTick = HL.Override(HL.Table) << function(self, ctx)
    self:_UpdateAutoConnectExtraHint()
    self:_NotifyPowerPoleTravelHint()
end

FacBuildModeHandler_Building.EvaluatePlacement = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local host = self.m_host
    local r = self:_ResetPlacementResult()
    local buildingMode = self:_GetCurBuildingMode()
    if not buildingMode then
        return r
    end
    r.actionColor = "Black"
    local rst = buildingMode.addBuildingCheckResult
    r.valid, r.errorHint = FacBuildCheckResultHint.getBuildingHint(rst, self:_BuildHintCtx())
    if r.valid then
        local ok, pos, rot = self.m_provider:TryGetPreviewPose()
        if ok or pos then
            CS.Beyond.Gameplay.Conditions.OnFacPrepareBuildingEnterArea.Trigger(host.m_buildingId, pos, rot.y)
        end
        
        local autoConnect = buildingMode.autoConnectCandidateList
        local inFac = buildingMode.inMainRegion or false
        if autoConnect ~= nil and autoConnect.Count > 0 then
            local buildingData
            if host.m_buildingId and not string.isEmpty(host.m_buildingId) then
                buildingData = GameInstance.remoteFactoryManager.staticData:QueryBuildingData(buildingMode.buildingId)
            end
            if
                buildingData and
                buildingData.type ~= GEnums.FacBuildingType.Hub:GetHashCode() and
                buildingData.type ~= GEnums.FacBuildingType.SubHub:GetHashCode() and
                buildingData.type ~= GEnums.FacBuildingType.SubHubOnlyPower:GetHashCode()
            then
                r.actionHint = inFac and Language.LUA_POWER_AUTOCONNECT_INFAC_HINT or Language.LUA_POWER_AUTOCONNECT_BUILD_MODE_HINT
            end
        elseif FacConst.POLE_RANGE_EFFECT_MAP[host.m_buildingId] and inFac then
            r.actionHint = Language.LUA_POWER_AUTOCONNECT_INFAC_HINT
        end

        if not host:_CheckSignCanBuild() then
            r.actionHint = Language.LUA_MARKER_BUILD_COUNT_MAX
        end
        local envRel = buildingMode.envRelationInfo
        if envRel:NotFullyCovered() then
            if envRel:NotFullyCoveredPartial() then
                r.actionHint = Language.LUA_BUILDING_ENV_NOT_FULLY_COVERED_BUT_PARTIAL
                r.actionColor = "Yellow"
            end
        elseif envRel:FullyCovered() then
            local env = envRel:FullyCoveredEnv()
            local envDisplayConfig = FacConst.FAC_ENV_DISPLAY_CONFIG[env]
            local envText = Language.LUA_BUILDING_ENV_NONE
            if envDisplayConfig.textKey then
                local envI18nResult, envI18nText = CS.Beyond.I18n.I18nUtils.TryGetText(envDisplayConfig.textKey)
                if envI18nResult then
                    envText = envI18nText
                end
            end
            r.actionHint = string.format(Language.LUA_BUILDING_ENV_FULLY_COVERED, envDisplayConfig.icon, envDisplayConfig.color, envText)
        end
        local soilAdjacentCount = buildingMode.adjacentSoilCount
        if soilAdjacentCount and soilAdjacentCount > 0 then
            r.actionHint = string.format(Language.LUA_FAC_BUILD_MODE_ON_SOIL_NEIGHBOR, soilAdjacentCount)
            r.actionColor = "Yellow"
        end
    end
    return r
end

FacBuildModeHandler_Building._BuildHintCtx = HL.Method().Return(HL.Table) << function(self)
    local ctx = self.m_hintCtx
    local buildingMode = self:_GetCurBuildingMode()
    ctx.buildingId = self.m_host.m_buildingId
    ctx.isBlueprintVariant = false
    ctx.pumpingLiquidItemId = buildingMode and buildingMode.pumpingLiquidItemId or nil
    return ctx
end

FacBuildModeHandler_Building.m_hintCtx = HL.Field(HL.Table) << function() return {} end


FacBuildModeHandler_Building._UpdateAutoConnectExtraHint = HL.Method() << function(self)
    local host = self.m_host
    local buildingMode = self:_GetCurBuildingMode()
    if not buildingMode then
        return
    end
    local notInPower, noPower = false, false
    if FacConst.NEED_AUTO_CONNECT_EXTRA_HINT_BUILDING[host.m_buildingId] then
        local autoConnect = buildingMode.autoConnectCandidateList
        if autoConnect then
            notInPower = true
            local status = CS.Beyond.Gameplay.Factory.PowerAutoConnectStatus
            for i = 0, autoConnect.Count - 1 do
                local info = autoConnect[i]
                if info.Item5 == status.Outage then
                    noPower = true
                    notInPower = false
                    break
                elseif info.Item5 ~= status.LocalLink and info.Item5 ~= status.DistLimit then
                    notInPower = false
                end
            end
        end
    end
    local udpipeKeepConnect, udpipeNoConnect = false, false
    if buildingMode.isMoving then
        local udpipeConnectEntry = buildingMode.udpipeConnectEntry
        if udpipeConnectEntry then
            udpipeNoConnect = udpipeConnectEntry.outOfRange
            udpipeKeepConnect = not udpipeNoConnect
        end
    end

    local moving = buildingMode.isMoving
    host.view.moveBuildingHint.gameObject:SetActiveIfNecessary(moving or notInPower or noPower or udpipeNoConnect or udpipeKeepConnect)
    host.view.rebuildInfoTxt.gameObject:SetActiveIfNecessary(moving)
    host.view.noPowerTxt.gameObject:SetActiveIfNecessary(notInPower)
    host.view.noElectricity.gameObject:SetActiveIfNecessary(noPower)
    if host.view.keepConnected then
        host.view.keepConnected.gameObject:SetActiveIfNecessary(udpipeKeepConnect)
    end
    if host.view.noConnected then
        host.view.noConnected.gameObject:SetActiveIfNecessary(udpipeNoConnect)
    end
end


FacBuildModeHandler_Building._NotifyPowerPoleTravelHint = HL.Method() << function(self)
    local host = self.m_host
    if host.m_mode ~= FacConst.FAC_BUILD_MODE.Building then
        return
    end
    local _, pos = self.m_provider:TryGetPreviewPose()
    if not host.m_buildingNodeId then
        Notify(MessageConst.ON_BUILD_POWER_POLE_TRAVEL_HINT, {
            buildingTypeId = host.m_buildingId,
            position = pos
        })
    else
        Notify(MessageConst.ON_MOVE_POWER_POLE_TRAVEL_HINT, {
            buildingTypeId = host.m_buildingId,
            position = pos,
            nodeId = host.m_buildingNodeId,
        })
    end
end






FacBuildModeHandler_Building.OnConfirm = HL.Override() << function(self)
    local host = self.m_host
    if not host:_CheckSignCanBuild() then
        host.m_lockBuildPos = true
        UIManager:AutoOpen(PanelId.FacMarkerManagePopup, {
            onClose = function()
                host.m_lockBuildPos = false
            end
        })
        return
    end

    host:TickOnce()
    if not host.m_curBuildIsValid then
        Notify(MessageConst.SHOW_TOAST, host.view.errorHintText.text)
        AudioAdapter.PostEvent("au_ui_fac_unbuildable")
        
        local buildingMode = self:_GetCurBuildingMode()
        local checkResult = buildingMode and buildingMode.addBuildingCheckResult or nil
        local limitType = checkResult and (checkResult.bandwidthLimited and "bandwidth" 
            or checkResult.travelPoleCountLimited and "travel_pole"                     
            or checkResult.battleCountLimited and "battle"                              
            or nil) or nil
        if limitType then
            EventLogManagerInst:GameEvent_MapBuildingLimit(Utils.getCurDomainId(), GameWorld.worldInfo.curLevelId, limitType)
        end
        return
    end

    local buildingItemId = host.m_itemData.id
    local buildingId = host.m_buildingId
    local ok, worldPos = host:SamplePointerWorldPos()
    if ok then
        self.m_provider:Submit(worldPos)
    end
    local isNewBuilding = host.m_buildingNodeId == nil

    if isNewBuilding then
        if host:_EnableContinueBuild() then
            local count = Utils.getItemCount(buildingItemId, true, true)
            if count <= 1 then
                
                local materialEnough, ingredients = FactoryUtils.checkBuildingMaterialEnough(buildingItemId, count == 0)
                if materialEnough then
                    host.view.materialCostNode.gameObject:SetActiveIfNecessary(true)
                    for index = 1, FacConst.FAC_HUB_CRAFT_MAX_INCOME_NUM do
                        local itemBundle = ingredients[index]
                        if itemBundle then
                            local itemCfg = Tables.itemTable[itemBundle.id]
                            host.view.materialCostNode["icon" .. index].gameObject:SetActiveIfNecessary(true)
                            host.view.materialCostNode["icon" .. index]:LoadSprite(UIConst.UI_SPRITE_ITEM, itemCfg.iconId)
                            host.view.materialCostNode["count" .. index].text = itemBundle.count
                        else
                            host.view.materialCostNode["icon" .. index].gameObject:SetActiveIfNecessary(false)
                        end
                    end
                else
                    self:_ExitSelf()
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BUILD_CONTINUOUS_STOPPED)
                end
            end
        else
            self:_ExitSelf()
        end
    else
        self:_ExitSelf()
        CS.Beyond.Gameplay.Audio.AudioRemoteFactoryBridge.PlayMoveEndAudio(buildingId)
    end
end


FacBuildModeHandler_Building._ExitSelf = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAnim)
    self.m_suppressCancelCallback = true
    self.m_host:ExitCurrentHandlerMode(skipAnim)
end

FacBuildModeHandler_Building.CanDelete = HL.Override().Return(HL.Boolean) << function(self)
    local nodeId = self.m_host.m_buildingNodeId
    if not nodeId then
        return false
    end
    return FactoryUtils.canDelBuilding(nodeId)
end

FacBuildModeHandler_Building.OnDelete = HL.Override() << function(self)
    local host = self.m_host
    GameInstance.player.remoteFactory.core:Message_OpDismantle(Utils.getCurrentChapterId(), host.m_buildingNodeId, false, function()
        self:_ExitSelf()
    end)
end

FacBuildModeHandler_Building.OnRotate = HL.Override() << function(self)
    FacBuildModeHandler_Building.Super.OnRotate(self)
    self:_UpdateFollowerState(false)
end

FacBuildModeHandler_Building.CanStayOutOfMainRegion = HL.Override().Return(HL.Boolean) << function(self)
    return FactoryUtils.canPlaceBuildingOnCurRegion(self.m_host.m_buildingId)
end






FacBuildModeHandler_Building.GetRecoverState = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local curMode = self:_GetCurBuildingMode()
    if not curMode then
        return nil
    end
    local _, pos = self.m_provider:TryGetPreviewPose()
    return {
        initDir = curMode.finalBuildingDirection,
        controllerMouseWorldPos = pos,
    }
end

FacBuildModeHandler_Building.GetDebugPosInfo = HL.Override().Return(HL.Opt(HL.Table)) << function(self)
    local _, pos, rot = self.m_provider:TryGetPreviewPose()
    return {
        id = self.m_host.m_buildingId,
        pos = pos,
        dir = rot.y,
    }
end

FacBuildModeHandler_Building.OnBackendPlaceFinish = HL.Override() << function(self)
    local host = self.m_host
    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_BUILD_CONTINUOUS_SUCCESS)
    if DeviceInfo.usingTouch and LuaSystemManager.factory.inTopView and host:IsContinueBuildToggleOn() then
        host:_StartCoroutine(function()
            coroutine.step()
            coroutine.step() 
            self.m_provider:SyncFence()
            self:_AutoMoveOnContinueBuildSucc()
        end)
    end
    host:_UpdatePendingHint()
    self.m_provider:SyncFence()
end

FacBuildModeHandler_Building._AutoMoveOnContinueBuildSucc = HL.Method() << function(self)
    if not DeviceInfo.usingTouch or not self:_GetCurBuildingMode() then
        
        return
    end
    
    local _, worldPos = self.m_provider:TryGetPreviewPose()
    worldPos = worldPos + CameraManager.mainCamera.transform.right
    self.m_provider:UpdatePreview(worldPos)
end


FacBuildModeHandler_Building._UpdateFollowerState = HL.Method(HL.Boolean) << function(self, isInit)
    local host = self.m_host
    local provider = self.m_provider
    
    
    local hasData, data = Tables.factoryBuildingTable:TryGetValue(host.m_buildingId)
    if not hasData then
        return
    end
    host.m_sizeIndicator.gameObject:SetActiveIfNecessary(true)
    host.m_sizeIndicator.followerObject.getTargetPosInfo = function(pos, rot)
        local _, previewPos, previewRot = provider:TryGetPreviewPose()
        return previewPos, previewRot
    end
    local scale = Vector3(data.range.width, data.modelHeight, data.range.depth)
    local reverseScale = Vector3(1 / scale.x, 1 / scale.y, 1 / scale.z)
    host.m_sizeIndicator.transform.localScale = scale
    host.m_sizeIndicator.transform:DoActionOnChildren(function(childTrans)
        childTrans.localScale = reverseScale
    end)

    if isInit then
        if host.m_workingRange then
            local extSizeW = 0
            local extSizeH = 0
            local powerPoleData = GameInstance.remoteFactoryManager.staticData:QueryPowerPoleData(host.m_buildingId)
            if powerPoleData and GameInstance.remoteFactoryManager.powerPoleConditionQuery:QueryDiffuserEnabled(powerPoleData) then
                local poleData = Tables.factoryPowerPoleTable[host.m_buildingId]
                extSizeW = poleData.rangeExtend.x
                extSizeH = poleData.rangeExtend.z
            else
                local vaporizerData = GameInstance.remoteFactoryManager.staticData:QueryVaporizerData(host.m_buildingId)
                if vaporizerData then
                    extSizeW = vaporizerData.rangeExtend.x
                    extSizeH = vaporizerData.rangeExtend.z
                end
            end
            if extSizeW > 0 or extSizeH > 0 then
                host.m_workingRange.gameObject:SetActive(true)
                host.m_workingRange.followerObject.getTargetPosInfo = function(pos, rot)
                    local _, previewPos, previewRot = provider:TryGetPreviewPose()
                    return previewPos, previewRot
                end
            end
        end
    end

    if isInit and data.type == GEnums.FacBuildingType.FluidSpray then
        local fluidSprayData = Tables.factoryFluidSprayTable[host.m_buildingId]
        local localCenterPosX = fluidSprayData.squirterOffset.x + fluidSprayData.squirterRange.x * 0.5 - data.range.width * 0.5
        local localCenterPosY = fluidSprayData.squirterOffset.y
        local localCenterPosZ = fluidSprayData.squirterOffset.z + fluidSprayData.squirterRange.z * 0.5 - data.range.depth * 0.5
        host.m_fluidSprayRange.gameObject:SetActive(true)
        host.m_fluidSprayRange.followerObject.getTargetPosInfo = function(pos, rot)
            local _, previewPos, previewRot = provider:TryGetPreviewPose()
            local q = Quaternion.Euler(previewRot.x, previewRot.y, previewRot.z)
            local m = Unity.Matrix4x4.TRS(previewPos, q, Vector3.one)
            previewPos = m:MultiplyPoint3x4(Vector3(localCenterPosX, localCenterPosY, localCenterPosZ))
            return previewPos, previewRot
        end
    end

    if isInit and data.type == GEnums.FacBuildingType.Battle then
        local battleData = GameInstance.remoteFactoryManager.staticData:QueryBattleData(host.m_buildingId)
        local range0 = battleData.attackRangeSize0
        local range1 = battleData.attackRangeSize1
        local scaleX = 1
        local scaleZ = 1
        local shapeType = battleData.rangeShapeType
        if shapeType == CS.Beyond.Gameplay.RemoteFactory.BattleShapeType.Circle then
            
            scaleX = range0 / 8
            scaleZ = scaleX
        elseif shapeType == CS.Beyond.Gameplay.RemoteFactory.BattleShapeType.Rect then
            
            scaleX = range1 / 2
            
            scaleZ = range0 / 6
        end
        if scaleX > 0 and scaleZ > 0 then
            host.m_battleRange.gameObject:SetActive(true)
            host.m_battleRange.transform.localScale = Vector3(scaleX, 1, scaleZ)
            host.m_battleRange.followerObject.getTargetPosInfo = function(pos, rot)
                local _, previewPos, previewRot = provider:TryGetPreviewPose()
                return previewPos, previewRot
            end
        end
    end
end




HL.Commit(FacBuildModeHandler_Building)
