local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.WonderBuild

local SCENE_ITEM_NAME = "WonderMap"
local LOCK_RESOLUTION_HEIGHT = 720
local RENDERING_SCALE_NAME = "renderingScale"
local AREA_COUNT = 4
local MAX_LEVEL = 5

PhaseWonderBuild = HL.Class('PhaseWonderBuild', phaseBase.PhaseBase)

PhaseWonderBuild.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WONDER_BUILD_SELECT_STAGE] = { '_OnSelectStage', true },
    [MessageConst.ON_WONDER_BUILD_HIGHLIGHT_STAGE] = { '_OnHighlightStage', true },
    [MessageConst.ON_WONDER_BUILD_UNHIGHLIGHT_STAGE] = { '_OnUnhighlightStage', true },
    [MessageConst.ON_WONDER_BUILD_SIDE_INFO_BACK] = { '_OnSideInfoBack', true },
    [MessageConst.ON_WONDER_BUILD_SIDE_INFO_PREV_STAGE] = { '_OnSideInfoPrevStage', true },
    [MessageConst.ON_WONDER_BUILD_SIDE_INFO_NEXT_STAGE] = { '_OnSideInfoNextStage', true },
    [MessageConst.ON_WONDER_BUILD_REWARD_CHANGE] = { '_TryPlayCurrentStageLevelUp', true },
    [MessageConst.ON_WONDER_BUILD_STAGE_UPGRADE] = { '_UpdateMoodEffects', true },
}

PhaseWonderBuild.m_panel = HL.Field(HL.Forward("PhasePanelItem"))

PhaseWonderBuild.m_sceneRoot = HL.Field(HL.Forward("PhaseGameObjectItem"))

PhaseWonderBuild.m_curStageId = HL.Field(HL.Number) << 0
PhaseWonderBuild.m_highlightStageId = HL.Field(HL.Number) << 0

PhaseWonderBuild.m_camAnimCor = HL.Field(HL.Thread)

PhaseWonderBuild.m_wonderProgress = HL.Field(HL.Userdata)





PhaseWonderBuild.ShowWonderBuild = HL.StaticMethod(HL.Table) << function(args)
    local domainId = unpack(args)
    PhaseManager:OpenPhase(PHASE_ID, {
        domainId = domainId,
    })
end


PhaseWonderBuild._OnInit = HL.Override() << function(self)
    PhaseWonderBuild.Super._OnInit(self)
    self.m_wonderProgress = GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterCinematic()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(false)
end

PhaseWonderBuild.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        local path = string.format(PhaseConst.PHASE_GAME_OBJECT_FILE_PATH, self.cfg.name, SCENE_ITEM_NAME)
        self.m_resourceLoader:LoadGameObjectAsync(path, function(go)
            logger.info(path, "预载完成")
        end)
    end
end

PhaseWonderBuild._InitAllPhaseItems = HL.Override() << function(self)
    PhaseWonderBuild.Super._InitAllPhaseItems(self)
    self.m_panel = self:_GetPanelPhaseItem(PanelId.WonderBuild)
    self:_InitSceneRoot()
    self.m_panel.uiCtrl:BindScene(self.m_sceneRoot)
end

PhaseWonderBuild._InitSceneRoot = HL.Method() << function(self)
    if self.m_sceneRoot ~= nil then
        return
    end
    CameraManager:SetNextBlendOverride(0, CS.Cinemachine.CinemachineBlendDefinition.Style.Cut)
    self.m_sceneRoot = self:CreateUIScene(SCENE_ITEM_NAME)
    self:_InitAreaStatus()
    self:_UpdateMoodEffects()
end

PhaseWonderBuild._UpdateMoodEffects = HL.Method() << function(self)
    if self.m_sceneRoot == nil then
        return
    end
    local isFinalStage = not Tables.wonderStageTable:ContainsKey(self.m_wonderProgress.stage + 1)
    self.m_sceneRoot.view.mood1.gameObject:SetActive(not isFinalStage)
    self.m_sceneRoot.view.mood2.gameObject:SetActive(isFinalStage)
end

PhaseWonderBuild._InitAreaStatus = HL.Method() << function(self)
    local _, lastStageId = ClientDataManagerInst:GetInt("WONDER_BUILD_AREA_STAGE", false, 1)
    local _, lastLevel = ClientDataManagerInst:GetInt("WONDER_BUILD_AREA_LEVEL", false, 0)
    for i = 1, AREA_COUNT do
        if i < lastStageId then
            
            self.m_sceneRoot.view["area" .. i]:InitWithLevel(MAX_LEVEL)
        elseif i == lastStageId then
            
            self.m_sceneRoot.view["area" .. i]:InitWithLevel(lastLevel)
        elseif i <= self.m_wonderProgress.stage then
            
            self.m_sceneRoot.view["area" .. i]:InitWithLevel(0)
        end
    end
end

PhaseWonderBuild._TryPlayAreaUpdate = HL.Method().Return(HL.Boolean) << function(self)
    local _, lastStageId = ClientDataManagerInst:GetInt("WONDER_BUILD_AREA_STAGE", false, 1)
    local _, lastLevel = ClientDataManagerInst:GetInt("WONDER_BUILD_AREA_LEVEL", false, 0)
    local newStageId = self.m_wonderProgress.stage    
    local _, stageData = Tables.wonderStageTable:TryGetValue(newStageId)
    local newLevel = 1
    for i = 0, stageData.wonderRewards.length - 1 do
        if self.m_wonderProgress.curExp >= stageData.wonderRewards[i].wonderExp then
            newLevel = newLevel+1
        else
            break
        end
    end

    if newLevel == lastLevel and newStageId == lastStageId then
        return false
    end

    for i = 1, AREA_COUNT do
        if i >= lastStageId and i <= newStageId then
            if i < newStageId then
                self.m_sceneRoot.view["area" .. i]:UpdateLevel(MAX_LEVEL)
            else
                self.m_sceneRoot.view["area" .. i]:UpdateLevel(newLevel)
            end
        end
    end

    ClientDataManagerInst:SetInt("WONDER_BUILD_AREA_LEVEL", newLevel, false, EClientDataTimeValidType.Permanent)
    ClientDataManagerInst:SetInt("WONDER_BUILD_AREA_STAGE", newStageId, false, EClientDataTimeValidType.Permanent)
    self:_StartCoroutine(function()
        self.m_panel.uiCtrl:StartTransition()
        coroutine.wait(2)
        self:_SetStageFocused()
        AudioManager.PostEvent("Au_UI_Menu_MapPanel_Open")
    end)
    return true
end

PhaseWonderBuild._TryPlayCurrentStageLevelUp = HL.Method() << function(self)
    
    local stageId = self.m_wonderProgress.stage
    local _, stageData = Tables.wonderStageTable:TryGetValue(stageId)
    local newLevel = 1
    for i = 0, stageData.wonderRewards.length - 1 do
        if self.m_wonderProgress.curExp >= stageData.wonderRewards[i].wonderExp then
            newLevel = newLevel+1
        else
            break
        end
    end
    self.m_sceneRoot.view["area" .. stageId]:UpdateLevel(newLevel)
    ClientDataManagerInst:SetInt("WONDER_BUILD_AREA_LEVEL", newLevel, false, EClientDataTimeValidType.Permanent)
end


PhaseWonderBuild._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:ActiveRenderScaleLock(true)
    if self.arg and self.arg.curStageId then
        local stageId = self.arg.curStageId
        self.arg.curStageId = nil
        self.m_curStageId = stageId
    else
        self.m_curStageId = GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress.stage
    end
    if not self:_TryPlayAreaUpdate() then
        
        if self.m_sceneRoot.view.blendCamera.curShowIndex ~= self.m_curStageId then
            self.m_sceneRoot.view.blendCamera:SetNextSwitchBlend(CS.Cinemachine.CinemachineBlendDefinition.Style.Cut, 0)
        end
        self.m_sceneRoot.view.blendCamera.curShowIndex = self.m_curStageId

        
        
        self.m_camAnimCor = self:_ClearCoroutine(self.m_camAnimCor)
        self.m_camAnimCor = self:_StartCoroutine(function()
            coroutine.step()
            AudioManager.PostEvent("Au_UI_Menu_MapPanel_Open")
            self:_SetStageFocused()
            self.m_camAnimCor = nil
        end)
    end
end

PhaseWonderBuild._OnActivated = HL.Override() << function(self)
end

PhaseWonderBuild._OnDeActivated = HL.Override() << function(self)
end

PhaseWonderBuild._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:ActiveRenderScaleLock(false)
end

PhaseWonderBuild._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:ActiveRenderScaleLock(false)
end

PhaseWonderBuild._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:ActiveRenderScaleLock(true)
    self:_UpdateMoodEffects()
end

PhaseWonderBuild._OnDestroy = HL.Override() << function(self)
    self.m_camAnimCor = self:_ClearCoroutine(self.m_camAnimCor)
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetVFXPPPriorityFilterNormal()
    CS.HG.Rendering.ScriptBridge.HGRenderBridgeStatics.SetSceneDarkEnabled(true)
    PhaseWonderBuild.Super._OnDestroy(self)
end



PhaseWonderBuild._OnSelectStage = HL.Method(HL.Number) << function(self, stageId)
    self:_NavigateToStage(stageId)
    AudioManager.PostEvent("Au_UI_Menu_MapPanel_Open")
end

PhaseWonderBuild._OnHighlightStage = HL.Method(HL.Number) << function(self, stageId)
    if self.m_highlightStageId > 0 and self.m_highlightStageId ~= stageId then
        self.m_sceneRoot.view["area" .. self.m_highlightStageId]:SetSelectState(false)
        self.m_sceneRoot.view["area" .. self.m_highlightStageId]:SetHoverState(false)
    end
    self.m_highlightStageId = stageId
    self.m_sceneRoot.view["area" .. stageId]:SetSelectState(true)
    self.m_sceneRoot.view["area" .. stageId]:SetHoverState(self.m_curStageId == 0)
end

PhaseWonderBuild._OnUnhighlightStage = HL.Method(HL.Number) << function(self, stageId)
    if self.m_highlightStageId == stageId then
        self.m_sceneRoot.view["area" .. self.m_highlightStageId]:SetSelectState(false)
        self.m_sceneRoot.view["area" .. self.m_highlightStageId]:SetHoverState(false)
        self.m_highlightStageId = 0
    end
end

PhaseWonderBuild._OnSideInfoBack = HL.Method() << function(self)
    self.m_camAnimCor = self:_ClearCoroutine(self.m_camAnimCor)
    self:_OnUnhighlightStage(self.m_curStageId)
    self.m_curStageId = 0
    self.m_panel.uiCtrl:StartTransition()
    AudioManager.PostEvent("Au_UI_Menu_MapPanel_Close")
    self.m_sceneRoot.view.blendCamera.curShowIndex = 0

    self.m_camAnimCor = self:_StartCoroutine(function()
        self:_WaitForBlendComplete()
        self.m_panel.uiCtrl:SetMapMode()
        self.m_panel.uiCtrl:EndTransition()
        self.m_camAnimCor = nil
    end)
end

PhaseWonderBuild._OnSideInfoPrevStage = HL.Method(HL.Any) << function(self, arg)
    local curStageId = arg
    local prevStageId = curStageId - 1
    if Tables.wonderStageTable:ContainsKey(prevStageId) then
        self:_NavigateToStage(prevStageId)
    end
end

PhaseWonderBuild._OnSideInfoNextStage = HL.Method(HL.Any) << function(self, arg)
    local curStageId = arg
    local nextStageId = curStageId + 1
    if Tables.wonderStageTable:ContainsKey(nextStageId) then
        self:_NavigateToStage(nextStageId)
    end
end

PhaseWonderBuild._NavigateToStage = HL.Method(HL.Number) << function(self, stageId)
    self.m_camAnimCor = self:_ClearCoroutine(self.m_camAnimCor)
    self.m_panel.uiCtrl:StartTransition()

    self.m_curStageId = stageId
    self:_OnHighlightStage(stageId)

    
    local sceneTrans = self.m_sceneRoot and self.m_sceneRoot.view["area" .. stageId].transform
    self.m_sceneRoot.view.blendCamera.curShowIndex = stageId

    self.m_camAnimCor = self:_StartCoroutine(function()
        self:_WaitForBlendComplete()
        self:_SetStageFocused()
        self.m_camAnimCor = nil
    end)
end

PhaseWonderBuild._SetStageFocused = HL.Method() << function(self)
    self.m_sceneRoot.view.blendCamera.curShowIndex = self.m_curStageId
    if self.m_curStageId == 0 then
        self.m_panel.uiCtrl:SetMapMode()
        return
    end
    self:_OnHighlightStage(self.m_curStageId)
    self.m_panel.uiCtrl:SetFocusMode(self.m_curStageId)
    self.m_panel.uiCtrl:EndTransition()
    self.m_panel.uiCtrl:ShowSideInfo(self.m_curStageId)
end

PhaseWonderBuild._WaitForBlendComplete = HL.Method() << function(self)
    coroutine.step()
    coroutine.wait(0.9)
end





PhaseWonderBuild.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = self.arg and lume.deepCopy(self.arg) or {}
    arg.curStageId = self.m_curStageId
    return arg
end



PhaseWonderBuild.ActiveRenderScaleLock = HL.Method(HL.Boolean) << function(self, isLocked)
    if DeviceInfo.usingTouch then
        
        local settingHub = CS.HG.Rendering.Runtime.HGRenderPipelineSettingHub.instance
        if isLocked then
            
            local settingParameters = CS.HG.Rendering.Runtime.HGRenderPipeline.currentPipeline.settingParameters
            local currentScale = settingParameters.renderingScale.paramValue
            local lockedScale = LOCK_RESOLUTION_HEIGHT / settingParameters.taauResolveResolutionHeight.paramValue
            if currentScale < lockedScale then
                settingHub:OverrideSettingParameter(RENDERING_SCALE_NAME, lockedScale)
            end
        else
            settingHub:ResetSettingParameter(RENDERING_SCALE_NAME)
        end
        CS.HG.Rendering.Runtime.HGRenderPipeline.currentPipeline.needRenderTerrain = not isLocked
    end
end

HL.Commit(PhaseWonderBuild)
