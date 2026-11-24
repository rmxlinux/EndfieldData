local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WonderBuild
local PHASE_ID = PhaseId.WonderBuild
local STAGE_COUNT = 4

WonderBuildCtrl = HL.Class('WonderBuildCtrl', uiCtrl.UICtrl)

WonderBuildCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_START] = '_UpdateStageTipAccelerateState',
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_END] = '_UpdateStageTipAccelerateState',
    [MessageConst.ON_WONDER_BUILD_STAGE_UPGRADE] = '_UpdateStageTipAccelerateState',
}

WonderBuildCtrl.m_domainId = HL.Field(HL.String) << ""

WonderBuildCtrl.m_sceneRoot = HL.Field(HL.Userdata) << nil
WonderBuildCtrl.m_selectedStageId = HL.Field(HL.Number) << 0
WonderBuildCtrl.m_focusedStageId = HL.Field(HL.Number) << 0

WonderBuildCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_domainId = arg.domainId

    if string.isEmpty(self.m_domainId) then
        logger.error("WonderBuildCtrl.OnCreate: domainId is empty!")
    end

    self.view.domainTopMoneyTitle.view.closeBtn.onClick:RemoveAllListeners()
    self.view.domainTopMoneyTitle.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    if not string.isEmpty(self.m_domainId) then
        self.view.domainTopMoneyTitle:InitDomainTopMoneyTitle(self.m_domainId)
    else
        self.view.domainTopMoneyTitle.gameObject:SetActive(false)
    end

    self.view.helpBtn.onClick:AddListener(function()
        
    end)

    self.view.backBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_WONDER_BUILD_SIDE_INFO_BACK)
    end)

    self:_InitStageNodes()

    self.view.activityTaskEntry:InitActivityTaskEntry({activityId = "activity_timelimited_wonder_construct"})

    self.view.stageTip.gameObject:SetActive(false)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

WonderBuildCtrl.BindScene = HL.Method(HL.Userdata) << function(self, sceneRoot)
    self.m_sceneRoot = sceneRoot
    self:_UpdateStageNodePositions()
end

WonderBuildCtrl.StartTransition = HL.Method() << function(self)
    self.view.luaPanel:BlockAllInput()
    self.view.bgInputGroup.gameObject:SetActive(false)
    self:_HideStageTip()
    self:_HideSideInfo()
end

WonderBuildCtrl.EndTransition = HL.Method() << function(self)
    self.view.luaPanel:RecoverAllInput()
end

WonderBuildCtrl.SetMapMode = HL.Method() << function(self)
    self.m_focusedStageId = 0
    self.view.bgInputGroup.gameObject:SetActive(true)
    self.view.backPanel.gameObject:SetActive(false)
    self:_UpdateStageNodePositions()
    if self.view.stageTip.gameObject.activeSelf then
        self:_UpdateStageTipPosition()
    end
    if DeviceInfo.usingController then
        self:SetNaviTarget(self.view["stage" .. self.m_selectedStageId .. "Node"])
    end
end

WonderBuildCtrl.SetFocusMode = HL.Method(HL.Number) << function(self, focusStageId)
    self.m_selectedStageId = focusStageId
    self.m_focusedStageId = focusStageId
    self.view.bgInputGroup.gameObject:SetActive(false)
    self.view.backPanel.gameObject:SetActive(true)
    self:_UpdateStageNodePositions()
    self:_ShowStageTip(self.m_focusedStageId)
end

WonderBuildCtrl._UpdateStageNodePositions = HL.Method() << function(self)
    if self.m_sceneRoot == nil then
        return
    end

    for i = 1, STAGE_COUNT do
        local nodeRect = self.view["stage" .. i .. "NodeRectTransform"]
        local sceneTrans = self.m_sceneRoot.view["area" .. i].transform
        if nodeRect == nil or sceneTrans == nil then
            break
        end

        local worldPos = sceneTrans.position
        local screenPos = CameraManager.mainCamera:WorldToScreenPoint(worldPos)
        local uiPos = UIUtils.screenPointToUI(Vector2(screenPos.x, screenPos.y), self.uiCamera, self.view.rectTransform)
        nodeRect.anchoredPosition = uiPos

        if i == self.m_focusedStageId then
            self.view.curNodeMask.anchoredPosition = uiPos
        end
    end
end

WonderBuildCtrl._InitStageNodes = HL.Method() << function(self)
    local wonderProgress = GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
    local curStage = wonderProgress and wonderProgress.stage or 0
    self.m_selectedStageId = curStage

    for i = 1, STAGE_COUNT do
        local stageNode = self.view["stage" .. i .. "Node"]
        if stageNode == nil then
            break
        end

        local visible = i <= curStage
        local nodeRect = self.view["stage" .. i .. "NodeRectTransform"]
        if nodeRect then
            nodeRect.gameObject:SetActive(visible)
        end

        local stageId = i
        stageNode.onClick:AddListener(function()
            Notify(MessageConst.ON_WONDER_BUILD_SELECT_STAGE, stageId)
        end)

        stageNode.onHoverChange:AddListener(function(isHover)
            if isHover then
                self:_SelectedStage(stageId)
            elseif self.m_focusedStageId == 0 then
                self:_UnselectedStage(stageId)
            end
        end)

        stageNode.onIsNaviTargetChanged = function(isNaviTarget)
            if isNaviTarget then
                self:_SelectedStage(stageId)
            elseif self.m_focusedStageId == 0 then
                self:_UnselectedStage(stageId)
            end
        end
    end
end

WonderBuildCtrl._SelectedStage = HL.Method(HL.Number) << function(self, stageId)
    self.m_selectedStageId = stageId
    self:_ShowStageTip(stageId)
    Notify(MessageConst.ON_WONDER_BUILD_HIGHLIGHT_STAGE, stageId)
end

WonderBuildCtrl._UnselectedStage = HL.Method(HL.Number) << function(self, stageId)
    if self.m_selectedStageId == stageId then
        self.m_selectedStageId = 0
        self:_HideStageTip()
        Notify(MessageConst.ON_WONDER_BUILD_UNHIGHLIGHT_STAGE, stageId)
    end
end

WonderBuildCtrl._ShowStageTip = HL.Method(HL.Number) << function(self, stageId)
    local success, stageData = Tables.wonderStageTable:TryGetValue(stageId)
    if not success then
        return
    end

    local tip = self.view.stageTip
    tip.stageNumTxt.text = stageData.stageTitle
    tip.stageTitleTxt.text = stageData.stageName
    tip.stageTitleShadowTxt.text = stageData.stageName
    tip.stageDescTxt.text = stageData.stageDesc
    tip.stageDescShadowTxt.text = stageData.stageDesc

    self:_UpdateStageTipAccelerateState()
    self:_UpdateStageTipPosition()
    tip.gameObject:SetActive(false)
    UIUtils.PlayAnimationAndToggleActive(tip.animationWrapper, true)
end

WonderBuildCtrl._UpdateStageTipAccelerateState = HL.Method() << function(self)
    local wonderProgress = GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
    local isAccelerating = self.m_selectedStageId == wonderProgress.stage
        and FactoryUtils.isInWonderBuildAccelerateTime()
    self.view.stageTip.stateController:SetState(isAccelerating and "Speed" or "NoSpeed")
end

WonderBuildCtrl._UpdateStageTipPosition = HL.Method() << function(self)
    if self.m_focusedStageId ~= 0 then
        self.view.stageTip.transform.position = self.view["buildTipsNode" .. self.m_selectedStageId].position
    else
        local nodeRect = self.view["stage" .. self.m_selectedStageId .. "NodeRectTransform"]
        if DeviceInfo.isMobileUser then
            self.view.stageTip.transform.position = nodeRect:TransformPoint(self.view.config.TIP_OFFSET_MOBILE)
        else
            self.view.stageTip.transform.position = nodeRect:TransformPoint(self.view.config.TIP_OFFSET_PC)
        end
    end
end

WonderBuildCtrl._HideStageTip = HL.Method() << function(self)
    UIUtils.PlayAnimationAndToggleActive(self.view.stageTip.animationWrapper, false)
end

WonderBuildCtrl.ShowSideInfo = HL.Method(HL.Number) << function(self, stageId)
    UIUtils.PlayAnimationAndToggleActive(self.view.sideInfoPanel.view.animationWrapper, true)
    self.view.sideInfoPanel:InitWonderBuildSideInfo({ stageId = stageId })
    Notify(MessageConst.ON_WONDER_BUILD_SIDE_INFO_SHOWN)
    CS.Beyond.Gameplay.Conditions.OnWonderBuildSideInfoShown.Trigger()
end

WonderBuildCtrl._HideSideInfo = HL.Method() << function(self)
    self.view.sideInfoPanel:CleanUp()
    UIUtils.PlayAnimationAndToggleActive(self.view.sideInfoPanel.view.animationWrapper, false)
end

HL.Commit(WonderBuildCtrl)
