
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacConditionerSelect
























FacConditionerSelectCtrl = HL.Class('FacConditionerSelectCtrl', uiCtrl.UICtrl)

local RATED_SLIDER_STEP = 1
local RATED_SLIDER_MIN = 1
local RATED_SLIDER_MAX = 5000
local REFRESH_INTERVAL_CHANGE_COUNT = 5
local REFRESH_FAST_INTERVAL = 0.1
local REFRESH_INTERVAL = 0.5
local REFRESH_CONTROLLER_RATE = 32






FacConditionerSelectCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


FacConditionerSelectCtrl.m_nodeId = HL.Field(HL.Any)


FacConditionerSelectCtrl.m_fluidType = HL.Field(HL.Boolean) << false


FacConditionerSelectCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo)


FacConditionerSelectCtrl.m_unionArgs = HL.Field(HL.Any)


FacConditionerSelectCtrl.m_updateThread = HL.Field(HL.Thread)


FacConditionerSelectCtrl.m_curValveNode = HL.Field(HL.Table)


FacConditionerSelectCtrl.m_curEmptyBtn = HL.Field(HL.Any)


FacConditionerSelectCtrl.m_blackBoxLockItem = HL.Field(HL.Boolean) << false


FacConditionerSelectCtrl.m_addBtnPressCoroutine = HL.Field(HL.Thread)


FacConditionerSelectCtrl.m_reduceBtnPressCoroutine = HL.Field(HL.Thread)


FacConditionerSelectCtrl.m_cacheShowItemTipsBindingId = HL.Field(HL.Number) << -1


FacConditionerSelectCtrl.m_btnPressFastChangeRate = HL.Field(HL.Number) << 1






FacConditionerSelectCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    local nodeId = self.m_uiInfo.nodeId
    self.m_nodeId = nodeId

    local logisticData = FactoryUtils.getLogisticData(self.m_uiInfo.nodeHandler.templateId)
    local buildingData = { nodeId = nodeId }
    setmetatable(buildingData, { __index = logisticData })
    self.view.buildingCommon:InitBuildingCommon(nil, {
        data = buildingData,
        customRightButtonOnClicked = function()
            if not FactoryUtils.canDelBuilding(self.m_nodeId, true) then
                return
            end
            PhaseManager:ExitPhaseFast(PhaseId.FacMachine)
            GameInstance.player.remoteFactory.core:Message_OpDismantle(Utils.getCurrentChapterId(), self.m_nodeId)
        end
    })

    local buildingitemData = Tables.itemTable:GetValue(logisticData.itemId)
    self.view.descText.text = buildingitemData.desc

    self.m_unionArgs = self.m_uiInfo.boxValve or self.m_uiInfo.fluidValve
    self.m_fluidType = self.m_uiInfo.boxValve == nil

    self:_InitValveNode()
    self:_InitBlackBoxState()
    self:_RefreshSelectItem(true)

    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            if not string.isEmpty(self.m_unionArgs.selectedItemId) then
                local showThroughCount = self.m_unionArgs.currentPassed and self.m_unionArgs.currentPassed > 0
                self.view.throughCountTxt.gameObject:SetActiveIfNecessary(showThroughCount)
                self.view.throughCountEmpty.gameObject:SetActiveIfNecessary(not showThroughCount)
                if showThroughCount then
                    self.view.throughCountTxt.text = self.m_unionArgs.currentPassed
                end
            end
        end
    end)

    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_nodeId)
end



FacConditionerSelectCtrl.OnClose = HL.Override() << function(self)
    self.m_updateThread = self:_ClearCoroutine(self.m_updateThread)
    self.m_addBtnPressCoroutine = self:_ClearCoroutine(self.m_addBtnPressCoroutine)
    self.m_reduceBtnPressCoroutine = self:_ClearCoroutine(self.m_reduceBtnPressCoroutine)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_nodeId)
end



FacConditionerSelectCtrl._InitValveNode = HL.Method() << function(self)
    self.m_curValveNode = self.m_fluidType and self.view.liquidNode or self.view.solidityNode
    self.m_curEmptyBtn = self.m_fluidType and self.view.liquiditemEmptyBtn or self.view.itemEmptyBtn
    self.m_curValveNode.gameObject:SetActiveIfNecessary(true)
    self.m_curEmptyBtn.gameObject:SetActiveIfNecessary(true)
    self.view.buildingCommon.view.machineBg.gameObject:SetActiveIfNecessary(not self.m_fluidType)
    self.view.buildingCommon.view.pipeBg.gameObject:SetActiveIfNecessary(self.m_fluidType)

    if DeviceInfo.usingController then
        self.m_btnPressFastChangeRate = REFRESH_CONTROLLER_RATE
    end

    if self.m_fluidType then
        self.m_curValveNode.facCachePipe:InitFacCachePipe(self.m_uiInfo, {
            useSinglePipe = true,
            stateRefreshCallback = function(portInfo)
                self:_RefreshPortBlockState(portInfo.isBlock)
            end
        })
    else
        self.m_curValveNode.facCacheBelt:InitFacCacheBelt(self.m_uiInfo, {
            noGroup = true,
            stateRefreshCallback = function(portInfo)
                self:_RefreshPortBlockState(portInfo.isBlock)
            end
        })
    end

    self.view.resetBtn.onClick:AddListener(function()
        GameInstance.player.remoteFactory.core:Message_ResetValveRecord(ScopeUtil.GetCurrentChapterId(), self.m_unionArgs.componentId)
    end)
    self.view.switchBtn.onClick:AddListener(function()
        self:_ShowSelectPanel()
    end)
    self.m_curEmptyBtn.onClick:AddListener(function()
        self:_ShowSelectPanel()
    end)
    self.view.commonToggle:InitCommonToggle(function(isOn)
        GameInstance.player.remoteFactory.core:Message_SetValveLimit(
            ScopeUtil.GetCurrentChapterId(),
            self.m_unionArgs.componentId,
            isOn,
            self.view.ratedCountSlider.value * RATED_SLIDER_STEP,
            function()
                self:_RefreshThroughCountState()
            end)
    end, self.m_unionArgs.enabled, true)

    self.view.ratedCountMinTxt.text = tostring(RATED_SLIDER_MIN * RATED_SLIDER_STEP)
    self.view.ratedCountMaxTxt.text = tostring(RATED_SLIDER_MAX * RATED_SLIDER_STEP)
    self.view.ratedCountSlider.minValue = RATED_SLIDER_MIN
    self.view.ratedCountSlider.maxValue = RATED_SLIDER_MAX
    self.view.ratedCountSlider.onValueChanged:AddListener(function(newNum)
        self:_OnSliderChanged(newNum)
    end)
    self.view.ratedCountSlider.onEndDragSlider:AddListener(function(newNum)
        GameInstance.player.remoteFactory.core:Message_SetValveLimit(
            ScopeUtil.GetCurrentChapterId(),
            self.m_unionArgs.componentId,
            true,
            newNum * RATED_SLIDER_STEP)
    end)
    self.view.ratedCountSlider.onClickSlider:AddListener(function(newNum)
        GameInstance.player.remoteFactory.core:Message_SetValveLimit(
            ScopeUtil.GetCurrentChapterId(),
            self.m_unionArgs.componentId,
            true,
            newNum * RATED_SLIDER_STEP)
    end)
    self.view.ratedCountMinBtn.onPressStart:AddListener(function()
        if InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1) then
            return
        end
        self.view.ratedCountSlider.value = self.view.ratedCountSlider.value - 1
        self.m_reduceBtnPressCoroutine = self:_ClearCoroutine(self.m_reduceBtnPressCoroutine)
        self.m_reduceBtnPressCoroutine = self:_StartCoroutine(function()
            local refreshCount = 0
            while true do
                local fastMode = refreshCount >= REFRESH_INTERVAL_CHANGE_COUNT
                local refreshInterval = fastMode and REFRESH_FAST_INTERVAL or REFRESH_INTERVAL
                local changeNum = fastMode and self.m_btnPressFastChangeRate or 1
                coroutine.wait(refreshInterval)
                if self.view.ratedCountSlider.value <= self.view.ratedCountSlider.minValue then
                    self.m_reduceBtnPressCoroutine = self:_ClearCoroutine(self.m_reduceBtnPressCoroutine)
                end
                self.view.ratedCountSlider.value = self.view.ratedCountSlider.value - changeNum
                refreshCount = refreshCount + 1
            end
        end)
    end)
    self.view.ratedCountMinBtn.onPressEnd:AddListener(function()
        self.m_reduceBtnPressCoroutine = self:_ClearCoroutine(self.m_reduceBtnPressCoroutine)
        GameInstance.player.remoteFactory.core:Message_SetValveLimit(
            ScopeUtil.GetCurrentChapterId(),
            self.m_unionArgs.componentId,
            true,
            self.view.ratedCountSlider.value * RATED_SLIDER_STEP)
    end)
    self.view.ratedCountMaxBtn.onPressStart:AddListener(function()
        if InputManagerInst:GetKey(CS.Beyond.Input.KeyboardKeyCode.Mouse1) then
            return
        end
        self.view.ratedCountSlider.value = self.view.ratedCountSlider.value + 1
        self.m_addBtnPressCoroutine = self:_ClearCoroutine(self.m_addBtnPressCoroutine)
        self.m_addBtnPressCoroutine = self:_StartCoroutine(function()
            local refreshCount = 0
            while true do
                local fastMode = refreshCount >= REFRESH_INTERVAL_CHANGE_COUNT
                local refreshInterval = fastMode and REFRESH_FAST_INTERVAL or REFRESH_INTERVAL
                local changeNum = fastMode and self.m_btnPressFastChangeRate or 1
                coroutine.wait(refreshInterval)
                if self.view.ratedCountSlider.value <= self.view.ratedCountSlider.minValue then
                    self.m_addBtnPressCoroutine = self:_ClearCoroutine(self.m_addBtnPressCoroutine)
                end
                self.view.ratedCountSlider.value = self.view.ratedCountSlider.value + changeNum
                refreshCount = refreshCount + 1
            end
        end)
    end)
    self.view.ratedCountMaxBtn.onPressEnd:AddListener(function()
        self.m_addBtnPressCoroutine = self:_ClearCoroutine(self.m_addBtnPressCoroutine)
        GameInstance.player.remoteFactory.core:Message_SetValveLimit(
            ScopeUtil.GetCurrentChapterId(),
            self.m_unionArgs.componentId,
            true,
            self.view.ratedCountSlider.value * RATED_SLIDER_STEP)
    end)
    self.view.ratedCountSlider.value = self.m_unionArgs.valvePassed / RATED_SLIDER_STEP

    self.m_cacheShowItemTipsBindingId = InputManagerInst:CreateBindingByActionId("show_item_tips", function()
        local itemId = self.m_unionArgs.selectedItemId
        local itemExist = not string.isEmpty(itemId)
        if itemExist then
            self.m_curValveNode.item:ShowTips()
        end
    end, self.view.inputGroup.groupId)
    InputManagerInst:ToggleBinding(self.m_cacheShowItemTipsBindingId, false)
end



FacConditionerSelectCtrl._InitBlackBoxState = HL.Method() << function(self)
    if not Utils.isInBlackbox()
        or not self.m_uiInfo.nodeHandler
        or not self.m_uiInfo.nodeHandler.predefinedParam
        or not self.m_uiInfo.nodeHandler.predefinedParam.valve then
        return
    end

    self.m_blackBoxLockItem = self.m_uiInfo.nodeHandler.predefinedParam.valve.isItemLocked
    local lockSlider = self.m_uiInfo.nodeHandler.predefinedParam.valve.isItemCountLocked
    local lockToggle = self.m_uiInfo.nodeHandler.predefinedParam.valve.isItemPassLocked

    if self.m_blackBoxLockItem then
        self.view.lockItemNode.gameObject:SetActiveIfNecessary(true)
    else
        self.view.lockItemNode:PlayOutAnimation(function()
            self.view.lockItemNode.gameObject:SetActiveIfNecessary(false)
        end)
    end
    self.view.unlockItemNode.gameObject:SetActiveIfNecessary(not self.m_blackBoxLockItem)
    self.view.sliderNode.gameObject:SetActiveIfNecessary(not lockSlider)
    self.view.lockSliderNode.gameObject:SetActiveIfNecessary(lockSlider)
    self.view.lLockIcon.gameObject:SetActiveIfNecessary(lockToggle)
    self.view.rLockIcon.gameObject:SetActiveIfNecessary(lockToggle)
    self.view.commonToggle:ToggleInteractable(not lockToggle)
end




FacConditionerSelectCtrl._OnSliderChanged = HL.Method(HL.Number) << function(self, number)
    self.view.ratedCountTxt.text = tostring(math.floor(number * RATED_SLIDER_STEP))
end




FacConditionerSelectCtrl._RefreshPortBlockState = HL.Method(HL.Boolean) << function(self, isBlock)
    local state = isBlock and GEnums.FacBuildingState.Blocked or GEnums.FacBuildingState.Normal
    self.view.buildingCommon:ChangeBuildingStateDisplay(state)
end




FacConditionerSelectCtrl._RefreshSelectItem = HL.Method(HL.Opt(HL.Boolean)) << function(self, init)
    if IsNull(self.view.gameObject) then
        return
    end
    self.m_uiInfo:Update()
    local itemId = self.m_unionArgs.selectedItemId
    local itemExist = not string.isEmpty(itemId)

    self.m_curValveNode.item.gameObject:SetActiveIfNecessary(itemExist)
    self.view.passedNode.gameObject:SetActiveIfNecessary(itemExist)
    self.view.switchText.text = itemExist and Language["key_hint_fac_unloader_replace_item"] or Language["key_hint_fac_unloader_add_item"]
    self.view.switchIcon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_COMMON, itemExist and "icon_tips_replace" or "icon_tips_add")
    InputManagerInst:ToggleBinding(self.m_cacheShowItemTipsBindingId, itemExist)
    if itemExist and itemId ~= self.m_curValveNode.item.id then
        if not init then
            GameInstance.player.remoteFactory.core:Message_ResetValveRecord(ScopeUtil.GetCurrentChapterId(), self.m_unionArgs.componentId)
        end
        self.m_curValveNode.item:InitItem({id = itemId, count = 1}, true)
        self.view.commonToggle:SetValue(self.m_unionArgs.enabled, true)
        self:_RefreshThroughCountState()
    end
end



FacConditionerSelectCtrl._RefreshThroughCountState = HL.Method() << function(self)
    if IsNull(self.view.gameObject) then
        return
    end
    self.m_uiInfo:Update()
    local open = self.m_unionArgs.enabled
    self.view.openNode.gameObject:SetActiveIfNecessary(open)
    self.view.closeNode.gameObject:SetActiveIfNecessary(not open)
    self.view.tipsNode.gameObject:SetActiveIfNecessary(not open)

    local showThroughCount = self.m_unionArgs.currentPassed and self.m_unionArgs.currentPassed > 0
    self.view.throughCountTxt.gameObject:SetActiveIfNecessary(showThroughCount)
    self.view.throughCountEmpty.gameObject:SetActiveIfNecessary(not showThroughCount)
    if showThroughCount then
        self.view.throughCountTxt.text = self.m_unionArgs.currentPassed
    end
end



FacConditionerSelectCtrl._ShowSelectPanel = HL.Method() << function(self)
    if self.m_blackBoxLockItem then
        return
    end
    UIManager:AutoOpen(PanelId.FacConditioner, {
        selectItemId = self.m_unionArgs.selectedItemId,
        onClickItem = function(itemId)
            if self.m_unionArgs.selectedItemId == itemId then
                itemId = ""
            end
            GameInstance.player.remoteFactory.core:Message_SetValveItem(
                ScopeUtil.GetCurrentChapterId(),
                self.m_unionArgs.componentId,
                itemId,
                function()
                    self:_RefreshSelectItem()
                end)
        end,
        isFluid = self.m_fluidType,
    })
    UIManager:SetTopOrder(PanelId.FacConditioner)
end









HL.Commit(FacConditionerSelectCtrl)
