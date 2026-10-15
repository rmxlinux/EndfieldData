










local FacRemoteTopViewConfig = require_ex('LuaSystem/FacRemoteTopViewConfig')
local TopViewExitTrigger = FacRemoteTopViewConfig.TopViewExitTrigger
local luaLoader = require_ex('Common/Utils/LuaResourceLoader')



local REMOTE_TOP_VIEW_NODE_PREFAB = "Assets/Beyond/DynamicAssets/Gameplay/Prefabs/FacRemoteTopView/FacRemoteTopViewNode.prefab"

local FacTopViewController = HL.Class('FacTopViewController')


FacTopViewController.m_facSys = HL.Field(HL.Forward('FacLuaSystem'))


FacTopViewController.m_topViewStack = HL.Field(HL.Table) << function() return {} end


FacTopViewController.currentTopViewContext = HL.Field(HL.Table)

FacTopViewController.isTopViewHideUIMode = HL.Field(HL.Boolean) << false


FacTopViewController.m_terrainManager = HL.Field(HL.Forward('FacRemoteTerrainManager'))


FacTopViewController.m_savedCustomFacTopViewRange = HL.Field(HL.Any)
FacTopViewController.m_didSetCustomRange = HL.Field(HL.Boolean) << false


FacTopViewController.m_remoteTopViewNode = HL.Field(GameObject)
FacTopViewController.m_remoteTopViewLoader = HL.Field(HL.Forward("LuaResourceLoader"))

FacTopViewController.FacTopViewController = HL.Constructor(HL.Forward('FacLuaSystem')) << function(self, facSys)
    self.m_facSys = facSys
end


FacTopViewController._ResolveToggleAction = HL.Method(HL.Boolean, HL.Opt(HL.Table)).Return(HL.String, HL.Opt(HL.Table)) << function(self, active, ctx)
    if not active then
        return FacConst.TOP_VIEW_ACTION.ExitManual, nil
    end
    local useCtx = ctx or self:_BuildLocalTopViewContext()
    local action = (useCtx.kind == FacConst.TOP_VIEW_KIND.Local) and FacConst.TOP_VIEW_ACTION.EnterLocal or FacConst.TOP_VIEW_ACTION.EnterRemote
    return action, useCtx
end


FacTopViewController._WillTopViewStackChange = HL.Method(HL.String, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, action, ctx)
    local stack = self.m_topViewStack
    local n = #stack
    if action == FacConst.TOP_VIEW_ACTION.ExitManual then
        return n > 0
    elseif action == FacConst.TOP_VIEW_ACTION.EnterLocal then
        return n == 0
    elseif action == FacConst.TOP_VIEW_ACTION.EnterRemote then
        if n == 0 then
            return true
        end
        local top = stack[n]
        if n == 1 and top.kind == FacConst.TOP_VIEW_KIND.Local then
            return true 
        end
        
        return ctx ~= nil and top.configKey ~= ctx.configKey
    end
    return false
end



FacTopViewController._TransitTopViewStack = HL.Method(HL.String, HL.Opt(HL.Table)).Return(HL.Boolean, HL.String, HL.Opt(HL.Table, HL.Table)) << function(self, action, ctx)
    local stack = self.m_topViewStack
    local n = #stack
    if action == FacConst.TOP_VIEW_ACTION.ExitManual then
        if n == 0 then
            return false, FacConst.TOP_VIEW_TRANSITION.None
        end
        local old = table.remove(stack)
        if #stack > 0 then
            self.currentTopViewContext = stack[#stack]
            return true, FacConst.TOP_VIEW_TRANSITION.PopToLocal, old, self.currentTopViewContext
        end
        self.currentTopViewContext = nil
        return true, FacConst.TOP_VIEW_TRANSITION.ExitToEmpty, old, nil
    elseif action == FacConst.TOP_VIEW_ACTION.EnterLocal then
        if n == 0 then
            stack[1] = ctx
            self.currentTopViewContext = ctx
            return true, FacConst.TOP_VIEW_TRANSITION.EnterFromEmpty, nil, ctx
        end
        return false, FacConst.TOP_VIEW_TRANSITION.None
    elseif action == FacConst.TOP_VIEW_ACTION.EnterRemote then
        if n == 0 then
            stack[1] = ctx
            self.currentTopViewContext = ctx
            return true, FacConst.TOP_VIEW_TRANSITION.EnterFromEmpty, nil, ctx
        elseif n == 1 and stack[1].kind == FacConst.TOP_VIEW_KIND.Local then
            stack[2] = ctx
            self.currentTopViewContext = ctx
            return true, FacConst.TOP_VIEW_TRANSITION.PushLayer, nil, ctx
        else
            local old = stack[n]
            if old.configKey == ctx.configKey then
                return false, FacConst.TOP_VIEW_TRANSITION.None
            end
            stack[n] = ctx
            self.currentTopViewContext = ctx
            return true, FacConst.TOP_VIEW_TRANSITION.SwapTop, old, ctx
        end
    end
    return false, FacConst.TOP_VIEW_TRANSITION.None
end

FacTopViewController._InternalToggleTopView = HL.Method(HL.Boolean, HL.Opt(HL.Boolean, HL.String, HL.Table)) << function(self, active, fastMode, action, ctx)
    
    action = action or (active and FacConst.TOP_VIEW_ACTION.EnterLocal or FacConst.TOP_VIEW_ACTION.ExitManual)
    if active and ctx == nil then
        ctx = self:_BuildLocalTopViewContext()
    end

    
    Notify(MessageConst.REMOVE_COMMON_BLOCK_MASK, "FacTopView")
    Notify(MessageConst.FAC_EXIT_DESTROY_MODE)
    Notify(MessageConst.FAC_BUILD_EXIT_CUR_MODE)

    local changed, ttype, oldCtx, newCtx = self:_TransitTopViewStack(action, ctx)
    if not changed then
        return
    end

    
    self.m_facSys.inTopView = (#self.m_topViewStack > 0)
    self.m_facSys:ResetSimpleFigureForTopView()
    if self.isTopViewHideUIMode then
        self:ToggleTopViewHideUIMode(false)
    end

    if ttype == FacConst.TOP_VIEW_TRANSITION.EnterFromEmpty then
        self:_OnEnterTopView(fastMode)
        self:_OnAddTopViewContext(newCtx, fastMode)
    elseif ttype == FacConst.TOP_VIEW_TRANSITION.ExitToEmpty then
        self:_OnExitTopView(fastMode)
        self:_OnRemoveTopViewContext(oldCtx, fastMode)
    elseif ttype == FacConst.TOP_VIEW_TRANSITION.PushLayer then
        self:_OnAddTopViewContext(newCtx, fastMode)
    elseif ttype == FacConst.TOP_VIEW_TRANSITION.PopToLocal then
        self:_OnRemoveTopViewContext(oldCtx, fastMode)
    elseif ttype == FacConst.TOP_VIEW_TRANSITION.SwapTop then
        self:_OnRemoveTopViewContext(oldCtx, fastMode)
        self:_OnAddTopViewContext(newCtx, fastMode)
    end

    EventLogManagerInst:GameEvent_FactoryTopViewSwitch(self.m_facSys.inTopView)
end


FacTopViewController._OnEnterTopView = HL.Method(HL.Opt(HL.Boolean)) << function(self, fastMode)
    self.m_facSys:AddFactoryModeRequest({ true, "FacTopView" })
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { "FacTopView", true })
    GameInstance.player.forbidSystem:SetForbid(ForbidType.DisableSwitchMode, "FacTopView", true, self.m_facSys.m_disableSwitchModeParams)
    GameInstance.playerController:OnToggleFactoryTopView(true)
    GameInstance.remoteFactoryManager:ChangeTopViewState(true)
    
end


FacTopViewController._OnExitTopView = HL.Method(HL.Opt(HL.Boolean)) << function(self, fastMode)
    self.m_facSys:RemoveFactoryModeRequest("FacTopView")
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { "FacTopView", false })
    GameInstance.player.forbidSystem:SetForbid(ForbidType.DisableSwitchMode, "FacTopView", false, self.m_facSys.m_disableSwitchModeParams)
    GameInstance.playerController:OnToggleFactoryTopView(false)
    GameInstance.remoteFactoryManager:ChangeTopViewState(false)
end



FacTopViewController._OnAddTopViewContext = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, ctx, fastMode)
    local facSys = self.m_facSys
    
    local isFirstLayer = facSys.m_topViewCamCtrl == nil
    local isRemote = ctx.kind == FacConst.TOP_VIEW_KIND.Remote
    
    local glitchEnter = isFirstLayer and isRemote and not fastMode

    if isRemote then
        
        self:_ApplyRemoteTopView(ctx)
        if ctx.abstractTerrain then
            self:_GetTerrainManager():Load(ctx.abstractTerrain)
        end
    end

    if isFirstLayer then
        
        
        
        if not facSys.topViewCamTarget then
            facSys.topViewCamTarget = GameObject("TopViewCamTarget").transform
            GameObject.DontDestroyOnLoad(facSys.topViewCamTarget.gameObject)
            facSys.topViewControllerMouseMoveTarget = GameObject("TopViewControllerMouseMoveTarget").transform
            GameObject.DontDestroyOnLoad(facSys.topViewControllerMouseMoveTarget.gameObject)
        end
        local topViewCamCtrl = CameraManager:LoadPersistentController("FacTopViewCamera")
        topViewCamCtrl:SetTarget(facSys.topViewCamTarget)
        local anchorPos = ctx.anchorWorldPos
        
        local duration = topViewCamCtrl:StartEnterTween(anchorPos, fastMode or isRemote)
        facSys.topViewControllerMouseMoveTarget.position = anchorPos
        if duration > 0 then
            Notify(MessageConst.SHOW_BLOCK_INPUT_PANEL, duration)
        end
        facSys.m_topViewCamCtrl = topViewCamCtrl
        facSys.m_topViewCamCtrl.onZoom = function(zoomPercent)
            Notify(MessageConst.ON_FAC_TOP_VIEW_CAM_ZOOM, zoomPercent)
        end
    else
        
        self:_MoveTopViewCamTargetTo(ctx.anchorWorldPos)
    end
    
    CSFactoryUtil.ChangeFacEcsCullingSetting(120, 100) 

    
    
    if not isFirstLayer then
        return
    end

    if glitchEnter then
        
        Notify(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, true)
        Notify(MessageConst.SHOW_BLOCK_GLITCH_TRANSITION)
        GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacTopViewSystemActionConflictName)
        return
    end

    if fastMode then
        Notify(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, true)
    else
        UIManager:PreloadPersistentPanelAsset(PanelId.FacTopView)
        UIManager:PreloadPersistentPanelAsset(PanelId.FacTopViewLowerCfg)
        UIManager:PreloadPersistentPanelAsset(PanelId.FacTopViewBuildingInfo)
        UIManager:ClearScreenWithOutAnimation(function(clearScreenKey)
            facSys:_StartTimer(0.6, function()
                GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacTopViewSystemActionConflictName)
                if facSys.inTopView then 
                    Notify(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, true)
                end
                UIManager:RecoverScreen(clearScreenKey)
            end)
        end)
    end
end



FacTopViewController._OnRemoveTopViewContext = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, ctx, fastMode)
    local facSys = self.m_facSys
    if ctx.kind == FacConst.TOP_VIEW_KIND.Remote then
        
        self:_ClearRemoteTopView()
        if ctx.abstractTerrain then
            self:_GetTerrainManager():Unload()
        end
    end

    if not facSys.inTopView then
        
        facSys:ToggleAutoMoveTopViewCam()
        if facSys.m_topViewCamCtrl then
            facSys.m_topViewCamCtrl.onZoom = nil
            
            
            local levelCamCtrl
            local _, panel = UIManager:IsOpen(PanelId.LevelCamera)
            if panel then
                levelCamCtrl = panel.m_curFreeLookCamCtrl
            end
            if levelCamCtrl then
                
                levelCamCtrl.param:SetHorizontalAngle(facSys.m_topViewCamCtrl.transform.eulerAngles.y, false)
                levelCamCtrl.param:SetVerticalValue(0.5, false)
            end
            CameraManager:RemoveCameraController(facSys.m_topViewCamCtrl)
            facSys.m_topViewCamCtrl = nil
            if not fastMode then
                Notify(MessageConst.SHOW_BLOCK_GLITCH_TRANSITION)
            end
        end
        CSFactoryUtil.ResetFacEcsCullingSetting()
    else
        
        local newTop = self.currentTopViewContext
        if newTop and newTop.anchorWorldPos then
            self:_MoveTopViewCamTargetTo(newTop.anchorWorldPos)
        end
    end

    
    
    if not facSys.inTopView then
        Notify(MessageConst.ON_TOGGLE_FAC_TOP_VIEW, false)
        GameInstance.player.systemActionConflictManager:OnSystemActionEnd(Const.FacTopViewSystemActionConflictName)
    end
end





FacTopViewController._ApplyRemoteTopView = HL.Method(HL.Table) << function(self, ctx)
    if not ctx.viewOffset then
        return
    end
    
    local regionW, regionH
    if ctx.regionMin and ctx.regionMax then
        regionW = ctx.regionMax.x - ctx.regionMin.x
        regionH = ctx.regionMax.z - ctx.regionMin.z
    end
    
    self:_ShowRemoteTopViewNode(regionW, regionH)

    local rfm = GameInstance.remoteFactoryManager
    local relocate = ctx.factoryRelocate
    local targetMapId = (relocate and relocate.mapId) or rfm.currentMapId
    rfm:SetRemoteTopView(targetMapId, ctx.viewOffset)

    
    
    
    local _, level = PhaseManager:IsOpen(PhaseId.Level)
    if level and ctx.anchorWorldPos and regionW and regionH then
        self.m_savedCustomFacTopViewRange = level.customFacTopViewRangeInWorld
        self.m_didSetCustomRange = true
        local center = ctx.anchorWorldPos
        
        
        
        local p = FacConst.FAC_TOP_VIEW_MOVE_PADDING
        level.customFacTopViewRangeInWorld = Unity.Rect(
            center.x - regionW * 0.5 + p, center.z - regionH * 0.5 + p,
            regionW - p * 2, regionH - p * 2)
    end
end

FacTopViewController._ClearRemoteTopView = HL.Method() << function(self)
    
    GameInstance.remoteFactoryManager:ClearRemoteTopView()
    if self.m_didSetCustomRange then
        local _, level = PhaseManager:IsOpen(PhaseId.Level)
        if level then
            level.customFacTopViewRangeInWorld = self.m_savedCustomFacTopViewRange
        end
        self.m_savedCustomFacTopViewRange = nil
        self.m_didSetCustomRange = false
    end
    self:_HideRemoteTopViewNode()
end



FacTopViewController._ShowRemoteTopViewNode = HL.Method(HL.Opt(HL.Number, HL.Number)) << function(self, width, height)
    if self.m_remoteTopViewNode and not IsNull(self.m_remoteTopViewNode) then
        self.m_remoteTopViewNode:SetActive(true)
    else
        self.m_remoteTopViewNode = nil
        if not self.m_remoteTopViewLoader then
            self.m_remoteTopViewLoader = luaLoader.LuaResourceLoader()
        end
        local prefab = self.m_remoteTopViewLoader:LoadGameObject(REMOTE_TOP_VIEW_NODE_PREFAB)
        if not prefab then
            logger.error("FacTopViewController._ShowRemoteTopViewNode: load prefab failed: " .. REMOTE_TOP_VIEW_NODE_PREFAB)
            return
        end
        local go = GameObject.Instantiate(prefab)
        go.transform.position = FacConst.FAC_REMOTE_TOP_VIEW_NODE_POS
        GameObject.DontDestroyOnLoad(go)
        self.m_remoteTopViewNode = go
    end
    if width and height then
        self:_ResizeRemoteTopViewNodeGround(width, height)
    end
end

FacTopViewController._HideRemoteTopViewNode = HL.Method() << function(self)
    if self.m_remoteTopViewNode and not IsNull(self.m_remoteTopViewNode) then
        self.m_remoteTopViewNode:SetActive(false)
    end
end



FacTopViewController._ResizeRemoteTopViewNodeGround = HL.Method(HL.Number, HL.Number) << function(self, width, height)
    if not self.m_remoteTopViewNode or IsNull(self.m_remoteTopViewNode) then
        return
    end
    local planeTrans = self.m_remoteTopViewNode.transform:Find("Plane")
    if not planeTrans then
        logger.error("FacTopViewController: RemoteFacTopViewNode 缺少名为 'Plane' 的子节点，无法对齐区域大小")
        return
    end
    local baseX, baseZ = 10, 10
    local mf = planeTrans:GetComponent(typeof(CS.UnityEngine.MeshFilter))
    if mf and not IsNull(mf) and mf.sharedMesh and not IsNull(mf.sharedMesh) then
        local sz = mf.sharedMesh.bounds.size
        if sz.x > 1e-4 then baseX = sz.x end
        if sz.z > 1e-4 then baseZ = sz.z end
    end
    planeTrans.localScale = Vector3(width / baseX, 1, height / baseZ)
end



FacTopViewController._MoveTopViewCamTargetTo = HL.Method(Vector3) << function(self, pos)
    local facSys = self.m_facSys
    if facSys.topViewCamTarget then
        facSys.topViewCamTarget.position = pos
    end
    if facSys.topViewControllerMouseMoveTarget then
        facSys.topViewControllerMouseMoveTarget.position = pos
    end
end


FacTopViewController._BuildLocalTopViewContext = HL.Method().Return(HL.Table) << function(self)
    local cfg = FacRemoteTopViewConfig.Get("coreFactory")
    local anchorPos
    local playerController = GameInstance.playerController
    local mainChar = playerController and playerController.mainCharacter
    if mainChar and mainChar.rootCom then
        anchorPos = mainChar.rootCom.transform.position
    end
    return {
        kind = FacConst.TOP_VIEW_KIND.Local,
        configKey = "coreFactory",
        displayName = cfg and cfg.displayName or "",
        anchorWorldPos = anchorPos,
        
        exitTriggers = {
            [TopViewExitTrigger.Teleport] = true,
            [TopViewExitTrigger.FullPartyDead] = true,
            [TopViewExitTrigger.Deport] = true,
            [TopViewExitTrigger.OutOfBoundary] = true,
        },
    }
end




FacTopViewController._BuildRemoteTopViewContext = HL.Method(HL.String).Return(HL.Opt(HL.Table)) << function(self, configKey)
    local cfg = FacRemoteTopViewConfig.Get(configKey)
    if not cfg then
        logger.error("FacTopViewController._BuildRemoteTopViewContext: no config for", configKey)
        return nil
    end
    local relocate = cfg.factoryRelocate
    if not relocate then
        logger.error("FacTopViewController._BuildRemoteTopViewContext: config missing factoryRelocate:", configKey)
        return nil
    end

    
    local playerPos = Vector3.zero
    local playerController = GameInstance.playerController
    local mainChar = playerController and playerController.mainCharacter
    if mainChar and mainChar.rootCom then
        playerPos = mainChar.rootCom.transform.position
    end

    
    
    
    
    
    local regionMin = relocate.regionMin
    local regionMax = relocate.regionMax
    if not regionMin or not regionMax then
        local rect
        if relocate.regionSource == "mainRegion" then
            rect = GameInstance.remoteFactoryManager:GetMainRegionLocalRect(cfg.mainPanelIndex or 0, 0)
        end
        if not rect or rect.width <= 0 or rect.height <= 0 then
            local _, level = PhaseManager:IsOpen(PhaseId.Level)
            rect = level and level.facRegionLocalRect
        end
        if not rect or rect.width <= 0 or rect.height <= 0 then
            logger.error("FacTopViewController._BuildRemoteTopViewContext: cannot resolve region rect for", configKey)
            return nil
        end
        regionMin = Vector3(rect.xMin, playerPos.y, rect.yMin)
        regionMax = Vector3(rect.xMax, playerPos.y, rect.yMax)
    end
    local regionCenter = (regionMin + regionMax) * 0.5

    
    
    local displayAnchor = FacConst.FAC_REMOTE_TOP_VIEW_NODE_POS

    
    local viewOffset = displayAnchor - regionCenter

    return {
        kind = FacConst.TOP_VIEW_KIND.Remote,
        configKey = configKey,
        displayName = cfg.displayName,
        anchorWorldPos = displayAnchor, 
        anchorYawDeg = cfg.anchorYawDeg,
        regionRect = cfg.regionRect,
        regionMin = regionMin,          
        regionMax = regionMax,
        viewOffset = viewOffset,        
        abstractTerrain = cfg.abstractTerrain, 
        factoryRelocate = relocate,     
        
        exitTriggers = {
            [TopViewExitTrigger.Teleport] = true,
            [TopViewExitTrigger.FullPartyDead] = true,
            [TopViewExitTrigger.Deport] = true,
        },
    }
end


FacTopViewController._GetTerrainManager = HL.Method().Return(HL.Forward('FacRemoteTerrainManager')) << function(self)
    if not self.m_terrainManager then
        self.m_terrainManager = require_ex('LuaSystem/FacRemoteTerrainManager')()
    end
    return self.m_terrainManager
end


FacTopViewController.TryExitByTrigger = HL.Method(HL.String) << function(self, trigger)
    if not self.m_facSys.inTopView then
        return
    end
    local ctx = self.currentTopViewContext
    local hit = ctx and ctx.exitTriggers and ctx.exitTriggers[trigger]
    if hit then
        self.m_facSys:ToggleTopView(false, true)
    end
end

FacTopViewController.ToggleTopViewHideUIMode = HL.Method(HL.Boolean) << function(self, active)
    self.isTopViewHideUIMode = active
    Notify(MessageConst.ON_FAC_TOP_VIEW_HIDE_UI_MODE_CHANGE, active)
end

HL.Commit(FacTopViewController)
return FacTopViewController
