
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.CommonSelectChar
PhaseCommonSelectChar = HL.Class('PhaseCommonSelectChar', phaseBase.PhaseBase)



local SCENE_NAME = "CharFormation"
local SCENE_FOLDER = "CharFormation"

local CHAR_INFO_FOLDER = "CharInfo"
local OVERRIDE_CAMERA_PATH = "OverrideCameras/"


local SLOT_INDEX = 1

local ANIM_STATE_SINGLE = 0

local AUDIO_EVENT_CHAR_GLITCH = "Au_UI_Event_CharFormation_Glitch"
local AUDIO_EVENT_CHAR_GLITCH_INTERVAL = 0.1

local CameraIndex = {
    Single = 1,
    OverrideSingle = 2,
}




PhaseCommonSelectChar.s_messages = HL.StaticField(HL.Table) << {
    
}




PhaseCommonSelectChar.m_sceneObject = HL.Field(HL.Forward("PhaseGameObjectItem"))

PhaseCommonSelectChar.m_inited = HL.Field(HL.Boolean) << false


PhaseCommonSelectChar.m_waitCharInfo = HL.Field(HL.Table)


PhaseCommonSelectChar.m_loadingInstId = HL.Field(HL.Number) << 0

PhaseCommonSelectChar.m_curCharInstId = HL.Field(HL.Number) << 0

PhaseCommonSelectChar.m_tickKey = HL.Field(HL.Number) << -1

PhaseCommonSelectChar.m_updateCounter = HL.Field(HL.Number) << 0

PhaseCommonSelectChar.m_lastPostGlitchEventTime = HL.Field(HL.Number) << 0

PhaseCommonSelectChar.m_templateId2LightGroup = HL.Field(HL.Table)

PhaseCommonSelectChar.m_templateId2TrackGroup = HL.Field(HL.Table)

PhaseCommonSelectChar.m_templateId2CameraGroup = HL.Field(HL.Table)

PhaseCommonSelectChar.m_templateId2VolumeGroup = HL.Field(HL.Table)

PhaseCommonSelectChar.m_charVolumeTween = HL.Field(HL.Userdata)

PhaseCommonSelectChar.m_overrideSingleCamera = HL.Field(HL.Userdata)














PhaseCommonSelectChar._OnInit = HL.Override() << function(self)
    self.m_templateId2LightGroup = {}
    self.m_templateId2TrackGroup = {}
    self.m_templateId2CameraGroup = {}
    self.m_templateId2VolumeGroup = {}

    self.m_tickKey = LuaUpdate:Add("Tick", function(deltaTime)
        self:_TryConsumeWaitChar()
    end)

    PhaseCommonSelectChar.Super._OnInit(self)
end

PhaseCommonSelectChar.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if not fastMode and (transitionType == PhaseConst.EPhaseState.TransitionIn or transitionType == PhaseConst.EPhaseState.TransitionOut) then
        coroutine.waitCondition(function()
            return true
        end, coroutine.TailTick)
        Notify(MessageConst.PREPARE_BLOCK_GLITCH_TRANSITION)
        coroutine.waitForRenderDone()
        coroutine.step()
    end
end

PhaseCommonSelectChar._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if not fastMode then
        Notify(MessageConst.SHOW_BLOCK_GLITCH_TRANSITION)
    end
    self:_InitGameObject()
    if self.m_sceneObject then
        self.m_sceneObject.go:SetActive(true)
    end
end

PhaseCommonSelectChar._OnActivated = HL.Override() << function(self)
    
    if not self.m_inited then
        self:CreatePhasePanelItem(PanelId.CommonSelectChar, self.arg)
        self.m_inited = true
    end

    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterCinematic()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(false)
end

PhaseCommonSelectChar._OnRefresh = HL.Override() << function(self)
    self:ClearChar()
    PhaseCommonSelectChar.Super._OnRefresh(self)
end

PhaseCommonSelectChar._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if not fastMode then
        Notify(MessageConst.SHOW_BLOCK_GLITCH_TRANSITION)
    end
end

PhaseCommonSelectChar._OnDestroy = HL.Override() << function(self)
    if self.m_tickKey > 0 then
        LuaUpdate:Remove(self.m_tickKey)
        self.m_tickKey = -1
    end

    self:ClearChar()

    
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterNormal()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(true)

    PhaseCommonSelectChar.Super._OnDestroy(self)
end






PhaseCommonSelectChar._InitGameObject = HL.Method() << function(self)
    if self.m_sceneObject then
        return
    end

    self.m_sceneObject = self:CreateUIScene(SCENE_NAME, {
        folderName = SCENE_FOLDER,
        skipSetActive = true,
        onActivate = function()
            self.m_sceneObject.view.light.gameObject:SetActive(true)
        end,
        onDeactivate = function()
            self.m_sceneObject.view.light.gameObject:SetActive(false)
        end,
    })

    self:_HideUnusedSceneNodes()
    
    self:_RefreshCamera(nil)
end

PhaseCommonSelectChar._HideUnusedSceneNodes = HL.Method() << function(self)
    local view = self.m_sceneObject.view
    for index = 1, Const.BATTLE_SQUAD_MAX_CHAR_NUM do
        view[string.format("slot%d", index)].root.gameObject:SetActive(false)
        view[string.format("charMark%d", index)].decoCross.gameObject:SetActive(false)
        view[string.format("effectList%d", index)].gameObject:SetActive(false)
        view[string.format("selectEffect%d", index)].gameObject:SetActive(false)
    end
    view.formationDeco.gameObject:SetActive(false)

    local cameraController = view.cameraController
    cameraController.teamCamera.gameObject:SetActive(false)
    cameraController.teamExtraCamera.gameObject:SetActive(false)
    cameraController.multiCamera.gameObject:SetActive(false)
end







PhaseCommonSelectChar.ShowChar = HL.Method(HL.Table) << function(self, charInfo)
    self:_RefreshCamera(charInfo)
    self.m_waitCharInfo = charInfo
    self:_TryConsumeWaitChar()
end


PhaseCommonSelectChar.ClearChar = HL.Method() << function(self)
    self.m_waitCharInfo = nil
    self:_RemoveCurCharModel()

    if not self.m_sceneObject then
        return
    end
    self:_StopModelEffect()
    self:_ClearCharLightAndVolume()
end






PhaseCommonSelectChar._TryConsumeWaitChar = HL.Method() << function(self)
    if self.m_loadingInstId ~= 0 then
        return
    end
    if not self.m_waitCharInfo then
        return
    end

    local charInfo = self.m_waitCharInfo
    self.m_waitCharInfo = nil
    self:_DoShowChar(charInfo)
end

PhaseCommonSelectChar._DoShowChar = HL.Method(HL.Table) << function(self, charInfo)
    local instId = charInfo.charInstId
    if self.m_curCharInstId == instId then
        return
    end

    self.m_updateCounter = self.m_updateCounter + 1
    self:_RemoveCurCharModel()

    local charId = charInfo.charId
    self.m_loadingInstId = instId
    local parent = self.m_sceneObject.view[string.format("charContainer%d", SLOT_INDEX)]
    self:CreatePhaseCharItem({ charInstId = instId, charId = charId }, parent, function(phaseCharItem)
        self.m_loadingInstId = 0
        if not phaseCharItem then
            return
        end
        self.m_curCharInstId = instId

        local lightGroup = self:_TryGetLightGroup(charId)
        if lightGroup then
            phaseCharItem.uiModelMono:InitLightFollower(lightGroup.go.transform)
        end
        local lookAtIk = phaseCharItem.go:GetComponent("LookAtIK")
        if lookAtIk then
            lookAtIk.solver:SetLookAtWeight(0)
        end

        phaseCharItem:SetVisible(true)
        phaseCharItem:SetTrigger(UIConst.PHASE_CHAR_ITEM_ENABLE_SWITCH_FORMATION)
        phaseCharItem:SetInteger(PhaseConst.PHASE_CHAR_ITEM_FORMATION_PARAM_NAME, ANIM_STATE_SINGLE)
        phaseCharItem:ReloadWeapon(false)
        phaseCharItem:SwitchWeaponState(CS.Beyond.Gameplay.View.CharUIModelMono.WeaponState.FORCE_HIDE)
        
        phaseCharItem.uiModelMono:ForceUpdateAnimator()

        self:_PlayModelEffect(charId)
        self:_TryPostGlitchEvent()
        self:_RefreshCharLightAndVolume(charId)
    end, nil, UIConst.UI_MODEL_LAYER)
end

PhaseCommonSelectChar._RemoveCurCharModel = HL.Method() << function(self)
    if self.m_loadingInstId ~= 0 then
        self:RemovePhaseCharItemByInstId(self.m_loadingInstId)
        self.m_loadingInstId = 0
    end
    if self.m_curCharInstId ~= 0 then
        self:RemovePhaseCharItemByInstId(self.m_curCharInstId)
        self.m_curCharInstId = 0
    end
end






PhaseCommonSelectChar._PlayModelEffect = HL.Method(HL.String) << function(self, charId)
    if string.isEmpty(charId) or not self.m_sceneObject then
        return
    end
    local charDisplayData = CharInfoUtils.getCharDisplayData(charId)
    if not charDisplayData then
        return
    end

    local height = LuaIndex(charDisplayData.height:ToInt())
    local effectParent = self.m_sceneObject.view[string.format("effectSingle%d", SLOT_INDEX)]
    effectParent.gameObject:SetActive(true)
    local parent = effectParent[string.format("effect%d", height)]

    local effect = self.m_sceneObject.view[string.format("charEffect%d", SLOT_INDEX)]
    effect.transform:SetParent(parent)
    effect.transform.localPosition = Vector3.zero
    effect.transform.localEulerAngles = Vector3.zero
    effect.transform.localScale = Vector3.one
    effect.gameObject:SetActive(true)
    effect:Play()
end

PhaseCommonSelectChar._StopModelEffect = HL.Method() << function(self)
    local effect = self.m_sceneObject.view[string.format("charEffect%d", SLOT_INDEX)]
    effect.gameObject:SetActive(false)
    effect:Stop()
end

PhaseCommonSelectChar._TryPostGlitchEvent = HL.Method() << function(self)
    if Time.realtimeSinceStartup - self.m_lastPostGlitchEventTime <= AUDIO_EVENT_CHAR_GLITCH_INTERVAL then
        return
    end
    self.m_lastPostGlitchEventTime = Time.realtimeSinceStartup
    if self.m_updateCounter > 1 then  
        AudioAdapter.PostEvent(AUDIO_EVENT_CHAR_GLITCH)
    end
end






PhaseCommonSelectChar._RefreshCamera = HL.Method(HL.Opt(HL.Table)) << function(self, charInfo)
    if self.m_overrideSingleCamera then
        self.m_overrideSingleCamera.gameObject:SetActive(false)
    end

    local cameraIndex = CameraIndex.Single
    local virtualCamera

    
    local overrideSingleCamera = charInfo and self:_TryGetSingleCamera(charInfo.charId)
    if overrideSingleCamera then
        self.m_overrideSingleCamera = overrideSingleCamera
        cameraIndex = CameraIndex.OverrideSingle
    else
        local cameras = self.m_sceneObject.view[string.format("singleCameras%d", SLOT_INDEX)]
        if charInfo then
            local charId = charInfo.charId
            local charDisplayData = CharInfoUtils.getCharDisplayData(charId)
            if charDisplayData then
                local overridePath = charDisplayData.cameraConfig.charFormationOverride
                if string.isEmpty(overridePath) then
                    virtualCamera = cameras[string.format("camera%d", LuaIndex(charDisplayData.height:ToInt()))]
                else
                    virtualCamera = self:_GetOverrideCamera(overridePath, cameras.transform)
                end
            else
                logger.error("PhaseCommonSelectChar._RefreshCamera getCharDisplayData nil: " .. charId .. "!!!")
            end
        else
            virtualCamera = cameras["camera1"]
        end
    end

    if virtualCamera then
        local singleCamera = self.m_sceneObject.view.cameraController.singleCamera
        singleCamera:SetFieldOfView(virtualCamera.m_Lens.FieldOfView)
        singleCamera.transform.position = virtualCamera.transform.position
        singleCamera.transform.rotation = virtualCamera.transform.rotation
    end

    self:_RefreshCameraController(cameraIndex)
end

PhaseCommonSelectChar._RefreshCameraController = HL.Method(HL.Number) << function(self, cameraIndex)
    local singleCamera = self.m_sceneObject.view.cameraController.singleCamera
    singleCamera.gameObject:SetActive(cameraIndex == CameraIndex.Single)
    if self.m_overrideSingleCamera then
        self.m_overrideSingleCamera.gameObject:SetActive(cameraIndex == CameraIndex.OverrideSingle)
    end
end

PhaseCommonSelectChar._GetOverrideCamera = HL.Method(HL.String, Transform).Return(HL.Userdata) << function(self, name, parent)
    local path = OVERRIDE_CAMERA_PATH .. name
    local phaseItem = self:_GetGOPhaseItem(path)
    if not phaseItem then
        phaseItem = self:CreatePhaseGOItem(path)
        phaseItem.go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
        phaseItem.go:SetActive(false)
    end

    phaseItem.go.transform:SetParent(parent)
    return phaseItem.go:GetComponent("CinemachineVirtualCamera")
end






PhaseCommonSelectChar._RefreshCharLightAndVolume = HL.Method(HL.String) << function(self, templateId)
    local light = self:_TryGetLight(templateId)
    if light ~= nil then
        light.gameObject:SetActive(true)
        light:TweenLightGroupAlpha(0, 1, 1)
    end
    self.m_sceneObject.view.lightTeam.gameObject:SetActive(false)

    local volume = self:_TryGetVolume(templateId)
    if volume ~= nil then
        self.m_sceneObject.view.charOverrideVolume.gameObject:SetActive(true)
        local tween = volume:GetMainLightBiasTween(self.m_sceneObject.view.charOverrideVolume, volume.tweenDuration)
        
        if self.m_charVolumeTween then
            self.m_charVolumeTween:Kill()
        end
        self.m_charVolumeTween = tween
        tween:Play()
    end

    
    for cachedId, lightGroup in pairs(self.m_templateId2LightGroup) do
        if cachedId ~= templateId then
            local otherLight = PhaseCommonSelectChar._GetLight(lightGroup)
            if otherLight.gameObject.activeSelf then
                otherLight:TweenLightGroupAlpha(1, 0, 1)
            else
                otherLight.gameObject:SetActive(false)
            end
        end
    end
end

PhaseCommonSelectChar._ClearCharLightAndVolume = HL.Method() << function(self)
    for _, lightGroup in pairs(self.m_templateId2LightGroup) do
        local light = PhaseCommonSelectChar._GetLight(lightGroup)
        light.gameObject:SetActive(false)
    end
    self.m_sceneObject.view.charOverrideVolume.gameObject:SetActive(false)
end

PhaseCommonSelectChar._GetLight = HL.StaticMethod(HL.Forward("PhaseGameObjectItem")).Return(HL.Any) << function(lightGroup)
    local light
    if lightGroup then
        local lightName = string.format("light_%s", UIConst.PHASE_CHAR_ITEM_CAMERA_POSTFIX_DICT.OVERVIEW)
        light = lightGroup.view[lightName]
    end
    return light
end

PhaseCommonSelectChar._GetSingleCamera = HL.StaticMethod(HL.Any).Return(HL.Any) << function(cameraGroup)
    local camera
    if cameraGroup then
        local cameraName = string.format("vcam_%s", UIConst.PHASE_CHAR_ITEM_CAMERA_POSTFIX_DICT.FORMATION)
        camera = cameraGroup[cameraName]
    end
    return camera
end

PhaseCommonSelectChar._GetVolume = HL.StaticMethod(HL.Any).Return(HL.Any) << function(volumeGroup)
    local volume
    if volumeGroup then
        local volumeName = string.format("volume_%s", UIConst.PHASE_CHAR_ITEM_CAMERA_POSTFIX_DICT.OVERVIEW)
        volume = volumeGroup[volumeName]
    end
    return volume
end

PhaseCommonSelectChar._TryGetLightGroup = HL.Method(HL.String).Return(HL.Forward("PhaseGameObjectItem")) << function(self, templateId)
    local charDisplayData = CharInfoUtils.getCharDisplayData(templateId)
    local lightGroup = self.m_templateId2LightGroup[templateId]
    if not lightGroup and not string.isEmpty(charDisplayData.charInfoLightGroup) then
        
        local success, result = xpcall(self.CreatePhaseGOItem, debug.traceback, self, charDisplayData.charInfoLightGroup, nil, nil, CHAR_INFO_FOLDER)
        if success then
            lightGroup = result
            lightGroup.go:SetAllChildrenActiveIfNecessary(false)
            lightGroup.go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
        end
        self.m_templateId2LightGroup[templateId] = lightGroup
    end
    return lightGroup
end

PhaseCommonSelectChar._TryGetTrackGroup = HL.Method(HL.String).Return(HL.Forward("PhaseGameObjectItem")) << function(self, templateId)
    local charDisplayData = CharInfoUtils.getCharDisplayData(templateId)
    local trackGroup = self.m_templateId2TrackGroup[templateId]
    if not trackGroup and not string.isEmpty(charDisplayData.charInfoCameraGroup) then
        local success, result = xpcall(self.CreatePhaseGOItem, debug.traceback, self, charDisplayData.charInfoCameraGroup, nil, nil, CHAR_INFO_FOLDER)
        if success then
            trackGroup = result
            trackGroup.go:SetLayerRecursive(UIConst.UI_MODEL_LAYER)
            
            local extraCams = trackGroup.view.extraCams
            extraCams.extra_cam_equip_second.gameObject:SetActive(false)
            extraCams.extra_cam_weapon_second.gameObject:SetActive(false)
        end
        self.m_templateId2TrackGroup[templateId] = trackGroup
    end
    return trackGroup
end

PhaseCommonSelectChar._TryGetCameraGroup = HL.Method(HL.String).Return(HL.Any) << function(self, templateId)
    local cameraGroup = self.m_templateId2CameraGroup[templateId]
    if not cameraGroup then
        local trackGroup = self:_TryGetTrackGroup(templateId)
        if trackGroup then
            cameraGroup = trackGroup.view.cameraGroup
            cameraGroup.gameObject:SetAllChildrenActiveIfNecessary(false)
            self.m_templateId2CameraGroup[templateId] = cameraGroup
        end
    end
    return cameraGroup
end

PhaseCommonSelectChar._TryGetVolumeGroup = HL.Method(HL.String).Return(HL.Any) << function(self, templateId)
    local volumeGroup = self.m_templateId2VolumeGroup[templateId]
    if not volumeGroup then
        local trackGroup = self:_TryGetTrackGroup(templateId)
        if trackGroup then
            volumeGroup = trackGroup.view.volumeModifiers
            self.m_templateId2VolumeGroup[templateId] = volumeGroup
        end
    end
    return volumeGroup
end

PhaseCommonSelectChar._TryGetLight = HL.Method(HL.String).Return(HL.Any) << function(self, templateId)
    local lightGroup = self:_TryGetLightGroup(templateId)
    if lightGroup ~= nil then
        lightGroup:SetActive(true)
        self:_MoveGoToCharContainer(lightGroup.go)
    end
    return PhaseCommonSelectChar._GetLight(lightGroup)
end

PhaseCommonSelectChar._TryGetSingleCamera = HL.Method(HL.String).Return(HL.Any) << function(self, templateId)
    local cameraGroup = self:_TryGetCameraGroup(templateId)
    if cameraGroup ~= nil then
        cameraGroup.gameObject:SetActive(true)
        self:_MoveGoToCharContainer(self:_TryGetTrackGroup(templateId).go)
    end
    return PhaseCommonSelectChar._GetSingleCamera(cameraGroup)
end

PhaseCommonSelectChar._TryGetVolume = HL.Method(HL.String).Return(HL.Any) << function(self, templateId)
    local volumeGroup = self:_TryGetVolumeGroup(templateId)
    if volumeGroup ~= nil then
        volumeGroup.gameObject:SetActive(true)
        self:_MoveGoToCharContainer(self:_TryGetTrackGroup(templateId).go)
    end
    return PhaseCommonSelectChar._GetVolume(volumeGroup)
end

PhaseCommonSelectChar._MoveGoToCharContainer = HL.Method(HL.Userdata) << function(self, go)
    local parent = self.m_sceneObject.view[string.format("charContainer%d", SLOT_INDEX)]
    go.transform:SetParent(parent.transform)
    go.transform.localPosition = Vector3.zero
    go.transform.localEulerAngles = Vector3.zero
end




HL.Commit(PhaseCommonSelectChar)
