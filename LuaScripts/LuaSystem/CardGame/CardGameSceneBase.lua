local luaLoader = require_ex('Common/Utils/LuaResourceLoader')

local CHAR_POSTMODEL_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Actors/PostModels/NPC/%s_postmodel.prefab"
local CHAR_OVERRIDE_AC_PATH = "Assets/Beyond/DynamicAssets/Gameplay/CardGame/CharAnimator/%s.overrideController"
local SCENE_FOLD_NAME = "CardGame"


CardGameSceneBase = HL.Class('CardGameSceneBase')




CardGameSceneBase.sceneRoot = HL.Field(HL.Table)
CardGameSceneBase.hudMain = HL.Field(HL.Table)

CardGameSceneBase.charItems = HL.Field(HL.Table)
CardGameSceneBase.uiSceneId = HL.Field(HL.String) << ""

CardGameSceneBase.seatChars = HL.Field(HL.Table)





CardGameSceneBase.m_resourceLoader = HL.Field(HL.Forward("LuaResourceLoader"))
CardGameSceneBase.modelLoader = HL.Field(CS.Beyond.UI.UIModelLoader)
CardGameSceneBase.m_animatorControllerCache = HL.Field(HL.Table)
CardGameSceneBase.m_charLoadRequestIds = HL.Field(HL.Table)
CardGameSceneBase.m_updateKeys = HL.Field(HL.Table)
CardGameSceneBase.m_destroyed = HL.Field(HL.Boolean) << false



CardGameSceneBase.CardGameSceneBase = HL.Constructor() << function(self)
end




CardGameSceneBase.Init = HL.Method(HL.Opt(HL.Table)) << function(self, seatChars)
    if self.sceneRoot ~= nil then
        return
    end

    self.m_destroyed = false
    self.seatChars = seatChars or {}
    self.charItems = {}
    self.m_animatorControllerCache = {}
    self.m_charLoadRequestIds = {}
    self.m_updateKeys = {}
    self.m_resourceLoader = luaLoader.LuaResourceLoader()
    self.modelLoader = CS.Beyond.UI.UIModelLoader()

    self:_LoadScenePrefab()
    self:InitCharModels()
    self:_InitHudMain()
    self:InitRegions()
end

CardGameSceneBase.Unload = HL.Method() << function(self)
    if self.m_destroyed then
        return
    end
    self.m_destroyed = true

    
    self:_OnUnload()
    self:_ClearAllTimersAndUpdates()

    self:_ReleaseRegions()
    self:_ReleaseHudMain()
    self:_ReleaseCharModels()
    self:_ReleaseScenePrefab()

    self.m_animatorControllerCache = {}
    self.seatChars = nil

    if self.m_resourceLoader then
        self.m_resourceLoader:DisposeAllHandles()
        self.m_resourceLoader = nil
    end
    if self.modelLoader then
        self.modelLoader:Dispose()
        self.modelLoader = nil
    end
end





CardGameSceneBase.GetScenePrefabName = HL.Virtual().Return(HL.String) << function(self)
    return ""
end

CardGameSceneBase.GetMaxSeatCount = HL.Virtual().Return(HL.Number) << function(self)
    return 0
end


CardGameSceneBase.GetHudSeatToSceneSeat = HL.Virtual().Return(HL.Table) << function(self)
    local mapping = {}
    for i = 1, self:GetMaxSeatCount() do
        mapping[i] = i
    end
    return mapping
end

CardGameSceneBase.InitCharModels = HL.Virtual() << function(self)
end

CardGameSceneBase.InitRegions = HL.Virtual() << function(self)
end


CardGameSceneBase._OnUnload = HL.Virtual() << function(self)
end





CardGameSceneBase._StartTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean)).Return(HL.Number)
        << function(self, duration, func, unscaled)
    return TimerManager:StartTimer(duration, func, unscaled, self)
end

CardGameSceneBase._ClearTimer = HL.Method(HL.Number).Return(HL.Number) << function(self, timer)
    TimerManager:ClearTimer(timer)
    return -1
end

CardGameSceneBase._StartUpdate = HL.Method(HL.Function, HL.Opt(HL.String)).Return(HL.Number)
        << function(self, func, updateName)
    if self.m_destroyed then
        return -1
    end
    updateName = updateName or "Tick"
    local key = LuaUpdate:Add(updateName, func)
    if self.m_updateKeys == nil then
        self.m_updateKeys = {}
    end
    self.m_updateKeys[key] = true
    return key
end

CardGameSceneBase._RemoveUpdate = HL.Method(HL.Number).Return(HL.Number) << function(self, key)
    LuaUpdate:Remove(key)
    if self.m_updateKeys then
        self.m_updateKeys[key] = nil
    end
    return -1
end

CardGameSceneBase._ClearAllTimersAndUpdates = HL.Method() << function(self)
    TimerManager:ClearAllTimer(self)
    if self.m_updateKeys then
        for key, _ in pairs(self.m_updateKeys) do
            LuaUpdate:Remove(key)
        end
        self.m_updateKeys = {}
    end
end





CardGameSceneBase._LoadScenePrefab = HL.Method() << function(self)
    local prefabName = self:GetScenePrefabName()
    if string.isEmpty(prefabName) then
        logger.error("CardGameSceneBase._LoadScenePrefab: prefab name empty")
        return
    end

    local path = string.format(PhaseConst.PHASE_GAME_OBJECT_FILE_PATH, SCENE_FOLD_NAME, prefabName)
    local goAsset = self.m_resourceLoader:LoadGameObject(path)
    if IsNull(goAsset) then
        logger.error(string.format("CardGameSceneBase._LoadScenePrefab: load failed, path=%s", path))
        return
    end

    local go = CSUtils.CreateObject(goAsset)
    go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
    self.sceneRoot = {
        go = go,
        view = Utils.wrapLuaNode(go),
    }

    self.uiSceneId = "CardGameScene_" .. prefabName
    UISceneManager:Register(self.uiSceneId, go, {
        position = Vector3(0, 0, 0),    
        cullingName = self.uiSceneId,
    })
    UISceneManager:Deactivate(self.uiSceneId)   
end

CardGameSceneBase._ReleaseScenePrefab = HL.Method() << function(self)
    if not string.isEmpty(self.uiSceneId) then
        UISceneManager:Unregister(self.uiSceneId)
        self.uiSceneId = ""
    end

    local sceneRoot = self.sceneRoot
    self.sceneRoot = nil
    if sceneRoot == nil or sceneRoot.go == nil or IsNull(sceneRoot.go) then
        return
    end

    CSUtils.ClearUIComponents(sceneRoot.go)
    GameObject.DestroyImmediate(sceneRoot.go)
end






CardGameSceneBase._InitHudMain = HL.Method() << function(self)
    if self.hudMain ~= nil then
        return
    end
    if self.sceneRoot == nil or self.sceneRoot.view == nil then
        logger.error("CardGameSceneBase._InitHudMain: sceneRoot not ready")
        return
    end

    local emptyRoot = self.sceneRoot.view.emptyRoot
    if emptyRoot == nil or emptyRoot.hudMain == nil then
        logger.error("CardGameSceneBase._InitHudMain: emptyRoot.hudMain missing")
        return
    end

    local hudMainRef = emptyRoot.hudMain
    local hudMainGo = hudMainRef.gameObject or hudMainRef
    self.hudMain = Utils.wrapLuaNode(hudMainGo)
    self.hudMain.canvas.worldCamera = CameraManager.mainCamera
    hudMainGo:SetLayerRecursive(UIConst.WORLD_UI_LAYER)
end

CardGameSceneBase._ReleaseHudMain = HL.Method() << function(self)
    
    self.hudMain = nil
end








CardGameSceneBase.CreateCharOnHudSeat = HL.Method(HL.Number, HL.String, HL.Opt(HL.Boolean))
        << function(self, hudSeat, charId, showPotentialFx)
    
    if CS.Beyond.Gameplay.CharUtils.IsEndminVirtualTemplateId(charId) then
        charId = MultiplayerUtils.resolveDisplayCharTemplateId(charId) or ""
    end
    if self.sceneRoot == nil or self.sceneRoot.view == nil then
        logger.error(string.format("CardGameSceneBase.CreateCharOnHudSeat: sceneRoot not ready, hudSeat=%d", hudSeat))
        return
    end

    local mapping = self:GetHudSeatToSceneSeat()
    local sceneSeat = (mapping and mapping[hudSeat]) or hudSeat
    local chair = self.sceneRoot.view["chair_" .. sceneSeat]
    if chair == nil then
        logger.error(string.format(
            "CardGameSceneBase.CreateCharOnHudSeat: chair missing, hudSeat=%d sceneSeat=%d",
            hudSeat, sceneSeat))
        return
    end

    local oldItem = self.charItems[hudSeat]
    if oldItem then
        self:_UnloadCharItem(oldItem)
        self.charItems[hudSeat] = nil
    end

    self:_ApplyChairByCharId(chair, charId)
    if not string.isEmpty(charId) then
        self:_LoadCharPostModel(hudSeat, charId, chair.chairModel, showPotentialFx == true)
    end
end



CardGameSceneBase._ApplyChairByCharId = HL.Method(HL.Any, HL.String) << function(self, chair, charId)
    if string.isEmpty(charId) then
        chair.gameObject:SetActive(false)
        return
    end

    chair.gameObject:SetActive(true)

    local success, templateData = DataManager:TryGetEntityTemplate(Const.ObjectType.Character, charId)
    if not success or not templateData then
        logger.error(string.format("CardGameSceneBase._ApplyChairByCharId: template missing, charId=%s", charId))
        return
    end

    if not chair.stateController then
        logger.error(string.format("CardGameSceneBase._ApplyChairByCharId: stateController missing, charId=%s", charId))
        return
    end

    local bodyTypeDef = templateData.bodyType
    local bodyType = bodyTypeDef.bodyType
    local stateName
    if bodyType == CS.Beyond.Gameplay.BodyType.Custom then
        stateName = string.format("%s_%d", bodyTypeDef.CustomName, bodyTypeDef.CustomId)
    else
        stateName = bodyType:ToString()
    end
    chair.stateController:SetState(stateName)
end

CardGameSceneBase._LoadCharPostModel = HL.Method(HL.Number, HL.String, HL.Any, HL.Boolean)
        << function(self, seatIndex, charId, sitRoot, showPotentialFx)
    local modelPath = string.format(CHAR_POSTMODEL_PATH, charId)
    local requestId
    requestId = self.modelLoader:LoadModelAsync(modelPath, sitRoot, function(modelGo)
        if requestId then
            self.m_charLoadRequestIds[requestId] = nil
        end
        if not modelGo then
            logger.error(string.format("CardGameSceneBase._LoadCharPostModel: load failed, path=%s", modelPath))
            return
        end
        if self.m_destroyed then
            self.modelLoader:UnloadModel(modelGo)
            return
        end

        modelGo.transform.localPosition = Vector3.zero
        modelGo.transform.localRotation = Quaternion.identity
        modelGo:SetLayerRecursive(UIConst.UI_MODEL_LAYER)

        local animator = modelGo:GetComponentInChildren(typeof(CS.UnityEngine.Animator), true)
        self:_ApplyCharOverrideAC(animator, charId)
        self:_DisableCharCloth(modelGo)
        local potentialFx = CS.Beyond.Gameplay.PotentialUtil.ApplyMaxPotentialToModel(
            modelGo, charId, UIConst.UI_MODEL_LAYER, showPotentialFx)

        self.charItems[seatIndex] = {
            go = modelGo,
            animator = animator,
            charId = charId,
            potentialFx = potentialFx,
        }
    end)
    if requestId then
        self.m_charLoadRequestIds[requestId] = true
    end
end

CardGameSceneBase._ApplyCharOverrideAC = HL.Method(HL.Any, HL.String) << function(self, animator, charId)
    if not animator then
        logger.error(string.format("CardGameSceneBase._ApplyCharOverrideAC: animator missing, charId=%s", charId))
        return
    end

    local animatorCtrlAsset = self.m_animatorControllerCache[charId]
    if not animatorCtrlAsset and not string.isEmpty(charId) then
        animatorCtrlAsset = self.m_resourceLoader:LoadAnimatorController(string.format(CHAR_OVERRIDE_AC_PATH, charId))
        if animatorCtrlAsset then
            self.m_animatorControllerCache[charId] = animatorCtrlAsset
        end
    end

    if not animatorCtrlAsset then
        logger.error(string.format(
            "CardGameSceneBase._ApplyCharOverrideAC: load failed, path=%s",
            string.format(CHAR_OVERRIDE_AC_PATH, charId)))
        return
    end

    animator.runtimeAnimatorController = animatorCtrlAsset
    animator:Update(0)
end


CardGameSceneBase._DisableCharCloth = HL.Method(HL.Any) << function(self, modelGo)
    if not modelGo then
        return
    end

    local boneCloths = modelGo:GetComponentsInChildren(typeof(CS.BeyondDynamicBone.BeyondBoneCloth), true)
    if boneCloths then
        for i = 0, boneCloths.Length - 1 do
            boneCloths[i].enabled = false
        end
    end

    local magicaCloths = modelGo:GetComponentsInChildren(typeof(CS.MagicaCloth.BaseCloth), true)
    if magicaCloths then
        for i = 0, magicaCloths.Length - 1 do
            magicaCloths[i].enabled = false
        end
    end
end

CardGameSceneBase._ReleaseCharModels = HL.Method() << function(self)
    if self.modelLoader and self.m_charLoadRequestIds then
        for requestId, _ in pairs(self.m_charLoadRequestIds) do
            if requestId then
                self.modelLoader:Cancel(requestId)
            end
        end
    end
    self.m_charLoadRequestIds = {}

    if self.modelLoader and self.charItems then
        for _, charItem in pairs(self.charItems) do
            if charItem then
                self:_UnloadCharItem(charItem)
            end
        end
    end
    self.charItems = {}
end


CardGameSceneBase._UnloadCharItem = HL.Method(HL.Table) << function(self, charItem)
    if charItem.potentialFx then
        charItem.potentialFx:Dispose()
        charItem.potentialFx = nil
    end
    if charItem.go then
        self.modelLoader:UnloadModel(charItem.go)
    end
end





CardGameSceneBase._ReleaseRegions = HL.Method() << function(self)
    if LuaSystemManager.cardGameSystem then
        LuaSystemManager.cardGameSystem:ClearRegions()
    end
end






CardGameSceneBase.SetRoomCameraPos = HL.Method(HL.Number) << function(self, posType)
    if self.sceneRoot == nil or self.sceneRoot.view == nil then
        logger.error("CardGameSceneBase.SetRoomCameraPos: sceneRoot not ready")
        return
    end
    local camTransform = self.sceneRoot.view.roomCamera.transform
    local config = self.sceneRoot.view.config
    if posType == CardGameUtils.RoomCameraPosType.Overlook then
        camTransform.localPosition = config.OVERLOOK_CAM_POS
        camTransform.localEulerAngles = config.OVERLOOK_CAM_ROT
    else
        camTransform.localPosition = config.NORMAL_CAM_POS
        camTransform.localEulerAngles = config.NORMAL_CAM_ROT
    end
end



HL.Commit(CardGameSceneBase)
