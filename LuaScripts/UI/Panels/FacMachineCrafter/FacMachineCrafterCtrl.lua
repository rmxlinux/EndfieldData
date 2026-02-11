local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacMachineCrafter



















































FacMachineCrafterCtrl = HL.Class('FacMachineCrafterCtrl', uiCtrl.UICtrl)

local SWITCH_LIQUID_MODE_POPUP_TITLE_TEXT_ID = "ui_fac_pipe_mode_close_info_title"
local SWITCH_LIQUID_MODE_POPUP_DESC_TEXT_ID = "ui_fac_pipe_mode_close_info_des"
local SWITCH_LIQUID_MODE_POPUP_TOGGLE_TEXT_ID = "ui_fac_pipe_mode_close_info_choose"
local SWITCH_LIQUID_MODE_POPUP_LOCAL_DATA_KEY = "hide_fac_machine_crafter_mode_switch_pop_up"

local START_CACHE_COUNT = 1
local MAX_CACHE_COUNT = 4
local SINGLE_LIQUID_CACHE_SLOT_SPACING_Y = 110

local SMART_ALERT_FUNCTION_NAME_LIST = {
    "_CheckAlertNoPowerCondition",
    "_CheckAlertNoPowerWithDiffuserCondition",
    "_CheckAlertNoPowerWithoutDiffuserCondition",
    "_CheckAlertCanBeOpenedCondition",
    "_CheckAlertFluidInputEmptyCondition",
    "_CheckAlertNormalInputEmptyCondition",
    "_CheckAlertInputInvalidFormulaCondition",
    "_CheckAlertOutputCacheFullWithPipeCondition",
    "_CheckAlertOutputCacheFullWithoutPipeCondition",
    "_CheckAlertOutputCacheFullWithBeltCondition",
    "_CheckAlertOutputCacheFullWithoutBeltCondition",
    "_CheckAlertInputCacheFullCondition",
    "_CheckAlertFluidOutputMultiBlockedCondition",
    "_CheckAlertNormalOutputMultiBlockedCondition",
    "_CheckAlertFluidInputMultiBlockedCondition",
    "_CheckAlertFluidInputSingleBlockedCondition",
    "_CheckAlertNormalInputMultiBlockedCondition",
    "_CheckAlertNormalInputSingleBlockedCondition",
}








FacMachineCrafterCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


FacMachineCrafterCtrl.m_nodeId = HL.Field(HL.Any)


FacMachineCrafterCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_Producer)


FacMachineCrafterCtrl.m_onBuildingFormulaChanged = HL.Field(HL.Function)


FacMachineCrafterCtrl.m_cachesMap = HL.Field(HL.Table)


FacMachineCrafterCtrl.m_normalSlotList = HL.Field(HL.Table)


FacMachineCrafterCtrl.m_hideModeSwitchPopUp = HL.Field(HL.Boolean) << false


FacMachineCrafterCtrl.m_lastProgressFormulaId = HL.Field(HL.String) << ""


FacMachineCrafterCtrl.m_skipFirstRefreshFormula = HL.Field(HL.Boolean) << true


FacMachineCrafterCtrl.m_isInventoryLocked = HL.Field(HL.Boolean) << false


FacMachineCrafterCtrl.m_smartAlertTargetTransformCache = HL.Field(HL.Table)


FacMachineCrafterCtrl.m_smartAlertConditionDataCache = HL.Field(HL.Table)





FacMachineCrafterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    local nodeId = self.m_uiInfo.nodeId
    self.m_nodeId = nodeId
    self.m_cachesMap = {}

    
    local layoutData = FactoryUtils.getMachineCraftCacheLayoutData(self.m_nodeId)
    self.view.inventoryArea:InitInventoryArea({
        onStateChange = function()
            self:_RefreshNaviGroupSwitcherInfos()
        end,
        customSetActionMenuArgs = function(actionMenuArgs)
            actionMenuArgs.cacheArea = self.view.cacheArea
        end,
        hasFluidInCache = layoutData and #layoutData.fluidIncomeCaches > 0,
        lockFormulaId = FactoryUtils.getMachineCraftLockFormulaId(self.m_uiInfo.nodeId),
    })
    self.m_isInventoryLocked = FactoryUtils.isBuildingInventoryLocked(nodeId)
    self.view.inventoryArea:LockInventoryArea(self.m_isInventoryLocked)

    
    self:_StartCoroutine(function()
        while true do
            if self.m_isClosed then
                return
            end
            coroutine.step()
            self.view.facProgressNode:UpdateProgress(self.m_uiInfo.producer.currentProgress)
            self:_UpdateGainButtonState()
        end
    end)

    
    self.view.formulaNode:InitFormulaNode(self.m_uiInfo)
    self.m_onBuildingFormulaChanged = function()
        self:_RefreshFormulaInfo()
    end
    self.m_uiInfo.onFormulaChanged:AddListener(self.m_onBuildingFormulaChanged)

    
    self.view.buildingCommon:InitBuildingCommon(self.m_uiInfo, {
        onStateChanged = function(state)
            self:_RefreshChangeState(state)
        end,
        smartAlertFuncNameList = SMART_ALERT_FUNCTION_NAME_LIST,
        targetCtrlInstance = self
    })
    self:_RefreshCrafterWidth()

    
    self.view.cachePipe:InitFacCachePipe(self.m_uiInfo, { needModeSwitch = true })
    self:_ChangePipeSpacingWithCacheSlotCount()

    
    self:_InitModeSwitchNode()

    self.view.cacheAreaCanvasGroup.alpha = 0
    
    self.view.cacheArea:InitFacCacheArea({
        buildingInfo = self.m_uiInfo,
        inChangedCallback = function(cacheItems)
            
            if self.m_skipFirstRefreshFormula then
                self.m_skipFirstRefreshFormula = false
                return
            end
            self:_RefreshFormulaInfo()
        end,
        outChangedCallback = function(cacheItems)
            self:_RefreshCacheMap(cacheItems)
        end,
        onInitializeFinished = function()
            self.view.cacheAreaCanvasGroup.alpha = 1
            self:_InitCacheBelt()

            
            self:_InitFacMachineCrafterController()

            
            self:_RefreshFormulaInfo()
            self:_UpdateSmartAlertCache()
        end,
        onIsInCacheAreaNaviGroup = function(isIn)
            self.view.contentBindingGroup.enabled = isIn
        end
    })
    self.view.gainBtn.onClick:AddListener(function()
    self.view.cacheArea:GainAreaOutItems()
    end)

    
    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(nodeId)
    end



FacMachineCrafterCtrl.OnClose = HL.Override() << function(self)
    self.view.buildingCommon:ClearSmartAlertUpdate()
    self.m_uiInfo.onFormulaChanged:RemoveListener(self.m_onBuildingFormulaChanged)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_nodeId)
end



FacMachineCrafterCtrl.OnAnimationInFinished = HL.Override() << function(self)
end






FacMachineCrafterCtrl._GetMachineFormulaId = HL.Method().Return(HL.String) << function(self)
    local lockFormulaId = FactoryUtils.getMachineCraftLockFormulaId(self.m_uiInfo.nodeId)
    if not string.isEmpty(lockFormulaId) then
        return lockFormulaId
    end

    if not string.isEmpty(self.m_uiInfo.formulaId) then
        return self.m_uiInfo.formulaId
    end

    local matchedFormulaId = self:_GetCurrentMatchedFormulaId()
    if not string.isEmpty(matchedFormulaId) then
        return matchedFormulaId
    end

    if not string.isEmpty(self.m_lastProgressFormulaId) then
        return self.m_lastProgressFormulaId
    end

    return self.m_uiInfo.lastFormulaId
end



FacMachineCrafterCtrl._RefreshFormulaInfo = HL.Method() << function(self)
    local id = self:_GetMachineFormulaId()
    local isFormulaMissing = string.isEmpty(id)

    if isFormulaMissing then
        self.view.formulaNode:RefreshDisplayFormula()
        self.view.facProgressNode:InitFacProgressNode(-1, -1)
        self.view.facProgressNode:SwitchAudioPlayingState(false)
        self.m_lastProgressFormulaId = id
        return
    end

    if id == self.m_lastProgressFormulaId then
        return
    end

    local craftInfo = FactoryUtils.parseMachineCraftData(id)
    local craftData = Tables.factoryMachineCraftTable:GetValue(id)
    local time = FactoryUtils.getCraftNeedTime(craftData)

    self.view.formulaNode:RefreshDisplayFormula(craftInfo)
    self.view.cacheArea:ChangedFormula(id, self.m_uiInfo.lastFormulaId)

    local colorStr = ""
    self.view.facProgressNode:InitFacProgressNode(
        time,
        craftData.totalProgress * FacConst.CRAFT_PROGRESS_MULTIPLIER,
        colorStr,
        function()
            self.view.cacheArea:PlayArrowAnimation("facmac_decoarrow_loop")
            AudioAdapter.PostEvent("au_ui_fac_yield")
        end,
        function()
            self:_PlayProgressFinishedAnimation()
        end
    )
    self.m_lastProgressFormulaId = id

    self.view.facProgressNode:SwitchAudioPlayingState(not string.isEmpty(self.m_uiInfo.formulaId))
end



FacMachineCrafterCtrl._GetCurrentMatchedFormulaId = HL.Method().Return(HL.String) << function(self)
    local itemList = {}
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, true, false)
        if normalCache and normalCache.items.Count > 0 then
            for itemId, _ in cs_pairs(normalCache.items) do
                table.insert(itemList, itemId)
            end
        end
        local liquidCache = self.m_uiInfo:GetCache(i, true, true)
        if liquidCache and liquidCache.items.Count > 0 then
            for itemId, _ in cs_pairs(liquidCache.items) do
                table.insert(itemList, itemId)
            end
        end
    end

    return FactoryUtils.getMatchedFormulaIdByItemList(
        self.m_uiInfo.buildingId,
        self.m_uiInfo.formulaMan.currentMode,
        itemList
    )
end



FacMachineCrafterCtrl._RefreshCrafterWidth = HL.Method() << function(self)
    local isWide = self.view.buildingCommon.bgRatio > 1

    
    local cfg = self.view.config
    
    self.view.cacheBelt.view.inBeltGroup.anchoredPosition = Vector2(
        isWide and cfg.WIDE_IN_BELT_POS_X or cfg.NORMAL_IN_BELT_POS_X,
        self.view.cacheBelt.view.inBeltGroup.anchoredPosition.y
    )
    self.view.cacheBelt.view.outBeltGroup.anchoredPosition = Vector2(
        isWide and cfg.WIDE_OUT_BELT_POS_X or cfg.NORMAL_OUT_BELT_POS_X,
        self.view.cacheBelt.view.inBeltGroup.anchoredPosition.y
    )
    
    local inWidth = isWide and cfg.WIDE_IN_LINE_WIDTH or cfg.NORMAL_IN_LINE_WIDTH
    local outWidth = isWide and cfg.WIDE_OUT_LINE_WIDTH or cfg.NORMAL_OUT_LINE_WIDTH
    self.view.cacheArea.view.inRepositoryList.repository1.view.slotCell.view.itemSlot.view.facLineCell:ChangeLineWidth(inWidth)
    self.view.cacheArea.view.inRepositoryList.repository2.view.slotCell.view.itemSlot.view.facLineCell:ChangeLineWidth(inWidth)
    self.view.cacheArea.view.outRepositoryList.repository1.view.slotCell.view.itemSlot.view.facLineCell:ChangeLineWidth(outWidth)
    self.view.cacheArea.view.outRepositoryList.repository2.view.slotCell.view.itemSlot.view.facLineCell:ChangeLineWidth(outWidth)
end




FacMachineCrafterCtrl._RefreshChangeState = HL.Method(HL.Userdata) << function(self, state)
    local stateText
    if state == GEnums.FacBuildingState.NoPower then
        stateText = Language.LUA_FAC_CRAFTER_STATE_NOPOWER_TIPS
    elseif state == GEnums.FacBuildingState.NotInPowerNet then
        stateText = Language.LUA_FAC_CRAFTER_STATE_NOTINPOWERNET_TIPS
    elseif state == GEnums.FacBuildingState.Closed then
        stateText = Language.LUA_FAC_CRAFTER_STATE_CLOSE_TIPS
    end

    self.view.cacheArea:RefreshAreaBlockState(state == GEnums.FacBuildingState.Blocked)
    self.view.facProgressNode.gameObject:SetActiveIfNecessary(stateText == nil)

    if stateText == nil then
        self.view.facProgressNode:SwitchAudioPlayingState(state == GEnums.FacBuildingState.Normal)
        self.view.facStateNode.animationWrapper:PlayOutAnimation(function()
            self.view.facStateNode.gameObject:SetActiveIfNecessary(false)
        end)
    else
        self.view.facStateNode.gameObject:SetActiveIfNecessary(true)
        self.view.facStateNode.stateTxt.text = stateText
    end
end








FacMachineCrafterCtrl._InitCacheBelt = HL.Method() << function(self)
    self.view.cacheBeltCanvasGroup.alpha = 0
    self.view.cacheBelt:InitFacCacheBelt(self.m_uiInfo, {
        noGroup = false,
        inEndSlotGroupGetter = function()
            return self.view.cacheArea:GetAreaInRepositoryNormalSlotGroup()
        end,
        outEndSlotGroupGetter = function()
            return self.view.cacheArea:GetAreaOutRepositoryNormalSlotGroup()
        end,
        onInitializeFinished = function()
            self.view.cacheBeltCanvasGroup.alpha = 1
            self.view.cacheArea:InitAreaNaviTarget()  
        end
    })
end




FacMachineCrafterCtrl._RefreshCacheMap = HL.Method(HL.Userdata) << function(self, cache)
    if cache == nil then
        return
    end

    local componentId = cache.componentId
    if self.m_cachesMap[componentId] == nil then
        self.m_cachesMap[componentId] = cache
    end
end


FacMachineCrafterCtrl._UpdateGainButtonState = HL.Method() << function(self)
    local findItem = false

    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local cache = self.m_uiInfo:GetCache(i, false, false)
        if cache and cache.operationItemsInfo.Count > 0 then
            findItem = true
            break
        end
        
        
        
        
        
        
    end

    self.view.gainBtn.interactable = findItem and not self.m_isInventoryLocked
end








FacMachineCrafterCtrl._PlayProgressFinishedAnimation = HL.Method() << function(self)
    local normalSlotList = self.view.cacheArea:GetAreaInRepositoryNormalSlotGroup()
    local liquidSlotList = self.view.cacheArea:GetAreaInRepositoryFluidSlotGroup()

    if normalSlotList ~= nil then
        for _, slotGroup in ipairs(normalSlotList) do
            for _, slot in ipairs(slotGroup) do
                slot:PlaySlotAnimation("itemslot_arrow_loop")
            end
        end
    end

    if liquidSlotList ~= nil then
        for _, slotGroup in ipairs(liquidSlotList) do
            for _, slot in ipairs(slotGroup) do
                slot:PlaySlotAnimation("liquidslot_arrow_loop")
            end
        end
    end
end








FacMachineCrafterCtrl._InitModeSwitchNode = HL.Method() << function(self)
    self.view.modeToggle.gameObject:SetActive(false)

    local nodePredefinedParam = self.m_uiInfo.nodeHandler.predefinedParam
    local needModeNode = true
    if
        nodePredefinedParam ~= nil and
        nodePredefinedParam.producer ~= nil
    then
        needModeNode = nodePredefinedParam.producer.enableModeSwitch
    end
    if needModeNode then
        if
            nodePredefinedParam ~= nil and
            nodePredefinedParam.producer ~= nil and
            nodePredefinedParam.producer.modeMethod ~= CS.Beyond.GEnums.FCProducerPredefineModeMethod.InheritDomain
        then
            needModeNode = nodePredefinedParam.producer.modeMethod == CS.Beyond.GEnums.FCProducerPredefineModeMethod.NormalAndLiquid
        else
            needModeNode = FactoryUtils.checkBuildingHasModeSwitch(self.m_uiInfo.nodeHandler.templateId)
        end
    end

    if not needModeNode then
        return
    end

    self.view.modeToggle.gameObject:SetActive(true)

    self.view.modeToggle.onValueChanged:AddListener(function(isOn)
        
        self.view.modeToggle:SetIsOnWithoutNotify(not isOn)
        self:_OnModeSwitchButtonClicked()
    end)

    local formulaMan = self.m_uiInfo.formulaMan
    if formulaMan ~= nil then
        self.view.modeToggle:SetIsOnWithoutNotify(formulaMan.currentMode == FacConst.FAC_FORMULA_MODE_MAP.NORMAL)
    end
end



FacMachineCrafterCtrl._OnModeSwitchButtonClicked = HL.Method() << function(self)
    
    local currentMode = self.m_uiInfo.formulaMan.currentMode
    if currentMode == FacConst.FAC_FORMULA_MODE_MAP.NORMAL then
        self:_SwitchMode(FacConst.FAC_FORMULA_MODE_MAP.LIQUID)
    else
        
        local _, hidePopUp = ClientDataManagerInst:GetBool(SWITCH_LIQUID_MODE_POPUP_LOCAL_DATA_KEY, false)
        if hidePopUp then
            self:_SwitchMode(FacConst.FAC_FORMULA_MODE_MAP.NORMAL)
        else
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language[SWITCH_LIQUID_MODE_POPUP_TITLE_TEXT_ID],
                subContent = string.format(UIConst.COLOR_STRING_FORMAT,
                        UIConst.COUNT_RED_COLOR_STR,
                        Language[SWITCH_LIQUID_MODE_POPUP_DESC_TEXT_ID]),
                onConfirm = function()
                    self:_SwitchMode(FacConst.FAC_FORMULA_MODE_MAP.NORMAL)
                end,
                toggle = {
                    onValueChanged = function(isOn)
                        self.m_hideModeSwitchPopUp = isOn
                    end,
                    toggleText = Language[SWITCH_LIQUID_MODE_POPUP_TOGGLE_TEXT_ID],
                    isOn = false,
                }
            })
        end
    end
end




FacMachineCrafterCtrl._SwitchMode = HL.Method(HL.String) << function(self, targetMode)
    self.view.buildingCommon.smartAlertChangeCachePauseUpdate = true
    GameInstance.player.remoteFactory.core:Message_OpChangeProducerMode(Utils.getCurrentChapterId(), self.m_nodeId, targetMode, function(message, result)
        self.m_uiInfo:Update(true)
        self.m_uiInfo:ClearProducerLastValidFormulaId()
        self.view.cacheArea:RefreshCacheArea()
        self.view.cacheBelt:RefreshCacheBelt()
        self.view.cachePipe:RefreshCachePipe()
        self.view.formulaNode:RefreshRedDot()
        self.view.modeToggle:SetIsOnWithoutNotify(self.m_uiInfo.formulaMan.currentMode == FacConst.FAC_FORMULA_MODE_MAP.NORMAL)
        self:_UpdateSmartAlertCache()
        self.view.inventoryArea:SetBuildingHasFluidCache(self.m_smartAlertConditionDataCache.hasFluidCache)
        if self.view.buildingCommon.smartAlertDynamicNode ~= nil then
            self.view.buildingCommon.smartAlertDynamicNode:ForceUpdateAlertPosition()
        end
        if self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) or self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) then
            self.view.cacheArea:InitAreaNaviTarget()
        end

        if self.m_hideModeSwitchPopUp then
            
            ClientDataManagerInst:SetBool(SWITCH_LIQUID_MODE_POPUP_LOCAL_DATA_KEY, true, false)
            self.m_hideModeSwitchPopUp = false 
        end
    end)
end



FacMachineCrafterCtrl._ChangePipeSpacingWithCacheSlotCount = HL.Method() << function(self)
    local layoutData = FactoryUtils.getMachineCraftCacheLayoutData(self.m_nodeId)
    if #layoutData.normalIncomeCaches <= 0 and #layoutData.fluidIncomeCaches <= 1 then
        self.view.cachePipe:ChangePipeSpacingY(SINGLE_LIQUID_CACHE_SLOT_SPACING_Y, true)
    end
    if #layoutData.normalOutcomeCaches <= 0 and #layoutData.fluidOutcomeCaches <= 1 then
        self.view.cachePipe:ChangePipeSpacingY(SINGLE_LIQUID_CACHE_SLOT_SPACING_Y, false)
    end
end







FacMachineCrafterCtrl.m_naviGroupSwitcher = HL.Field(HL.Forward('NaviGroupSwitcher'))



FacMachineCrafterCtrl._InitFacMachineCrafterController = HL.Method() << function(self)
    local NaviGroupSwitcher = require_ex("Common/Utils/UI/NaviGroupSwitcher").NaviGroupSwitcher
    self.m_naviGroupSwitcher = NaviGroupSwitcher(self.view.inputGroup.groupId, nil, true)

    self:_RefreshNaviGroupSwitcherInfos()

    InputManagerInst:ChangeParent(
        true,
        self.view.buildingCommon.view.closeButton.groupId,
        self.view.inputGroup.groupId
    )
end



FacMachineCrafterCtrl._RefreshNaviGroupSwitcherInfos = HL.Method() << function(self)
    if self.m_naviGroupSwitcher == nil then
        return
    end

    local naviGroupInfos = {}
    self.view.cacheArea:AddNaviGroupSwitchInfo(naviGroupInfos)
    self.view.inventoryArea:AddNaviGroupSwitchInfo(naviGroupInfos)
    self.m_naviGroupSwitcher:ChangeGroupInfos(naviGroupInfos)
end








FacMachineCrafterCtrl._UpdateSmartAlertCache = HL.Method() << function(self)
    self.m_smartAlertTargetTransformCache = {}
    self.m_smartAlertTargetTransformCache.inBelt = {}
    if self.view.cacheBelt.m_inBeltList then
        local tempCount = self.view.cacheBelt.m_inBeltList:GetCount()
        for index = 1, tempCount do
            local cell = self.view.cacheBelt.m_inBeltList:GetItem(index)
            self.m_smartAlertTargetTransformCache.inBelt[index] = cell.transform
        end
    end
    self.m_smartAlertTargetTransformCache.outBelt = {}
    if self.view.cacheBelt.m_outBeltList then
        local tempCount = self.view.cacheBelt.m_outBeltList:GetCount()
        for index = 1, tempCount do
            local cell = self.view.cacheBelt.m_outBeltList:GetItem(index)
            self.m_smartAlertTargetTransformCache.outBelt[index] = cell.transform
        end
        self.m_smartAlertTargetTransformCache.lastOutBelt = self.m_smartAlertTargetTransformCache.outBelt[tempCount]
    end
    self.m_smartAlertTargetTransformCache.inPipe = {}
    if self.view.cachePipe.m_inPipeList then
        tempCount = #self.view.cachePipe.m_inPipeList
        for i = 1, tempCount do
            local pipe = self.view.cachePipe.m_inPipeList[i]
            self.m_smartAlertTargetTransformCache.inPipe[i] = pipe.transform
        end
    end
    self.m_smartAlertTargetTransformCache.outPipe = {}
    if self.view.cachePipe.m_outPipeList then
        for i = 1, #self.view.cachePipe.m_outPipeList do
            local pipe = self.view.cachePipe.m_outPipeList[i]
            self.m_smartAlertTargetTransformCache.outPipe[i] = pipe.transform
        end
    end
    self.m_smartAlertTargetTransformCache.normalInput = {}
    if self.view.cacheArea.view.inRepositoryList.repository1.m_slotList then
        tempCount = self.view.cacheArea.view.inRepositoryList.repository1.m_slotList:GetCount()
        for i = 1, tempCount do
            local cell = self.view.cacheArea.view.inRepositoryList.repository1.m_slotList:GetItem(i)
            self.m_smartAlertTargetTransformCache.normalInput[i] = cell.transform
        end
    end
    self.m_smartAlertTargetTransformCache.fluidInput = {}
    if self.view.cacheArea.view.inRepositoryList.repository2.m_slotList then
        tempCount = self.view.cacheArea.view.inRepositoryList.repository2.m_slotList:GetCount()
        for i = 1, tempCount do
            local cell = self.view.cacheArea.view.inRepositoryList.repository2.m_slotList:GetItem(i)
            self.m_smartAlertTargetTransformCache.fluidInput[i] = cell.transform
        end
    end
    self.m_smartAlertTargetTransformCache.normalOutput = {}
    if self.view.cacheArea.view.outRepositoryList.repository1.m_slotList then
        tempCount = self.view.cacheArea.view.outRepositoryList.repository1.m_slotList:GetCount()
        for i = 1, tempCount do
            local cell = self.view.cacheArea.view.outRepositoryList.repository1.m_slotList:GetItem(i)
            self.m_smartAlertTargetTransformCache.normalOutput[i] = cell.transform
        end
    end
    self.m_smartAlertTargetTransformCache.fluidOutput = {}
    if self.view.cacheArea.view.outRepositoryList.repository2.m_slotList then
        tempCount = self.view.cacheArea.view.outRepositoryList.repository2.m_slotList:GetCount()
        for i = 1, tempCount do
            local cell = self.view.cacheArea.view.outRepositoryList.repository2.m_slotList:GetItem(i)
            self.m_smartAlertTargetTransformCache.fluidOutput[i] = cell.transform
        end
    end
    self.m_smartAlertTargetTransformCache.state = self.view.buildingCommon.view.stateNode.transform

    self.m_smartAlertConditionDataCache = {}
    self.m_smartAlertConditionDataCache.effectiveFormula = {}
    local crafts = FactoryUtils.getBuildingCraftsWithNodeId(self.m_nodeId)
    if crafts then
        for _, craft in ipairs(crafts) do
            if craft.incomes then
                for i = 1, #craft.incomes do
                    self.m_smartAlertConditionDataCache.effectiveFormula[craft.incomes[i].id] = true
                end
            end
        end
    end
    local layoutData = FactoryUtils.getMachineCraftCacheLayoutData(self.m_nodeId)
    if layoutData then
        self.m_smartAlertConditionDataCache.hasItemCache = #layoutData.normalIncomeCaches > 0
        self.m_smartAlertConditionDataCache.hasFluidCache = #layoutData.fluidIncomeCaches > 0
    end
    self.m_smartAlertConditionDataCache.machineName = Tables.factoryBuildingTable:GetValue(self.m_uiInfo.buildingId).name
    self.m_smartAlertConditionDataCache.hasBelt = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedBelt and
        GameInstance.remoteFactoryManager:IsFacNodeInMainRegion(
            self.m_uiInfo.nodeHandler.belongChapter.chapterId,
            self.m_nodeId
        )
    self.m_smartAlertConditionDataCache.hasPipe = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipe

    self.view.buildingCommon.smartAlertChangeCachePauseUpdate = false
end




FacMachineCrafterCtrl._CheckAlertNormalInputSingleBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, true, false)
        if normalCache and normalCache.blockedMismatchItems.Count > 0 then
            local itemIdOrMultiTag, blockPort
            for i = 0, normalCache.blockedMismatchItems.Count - 1 do
                blockPort = normalCache.blockedMismatchItems[i].portIndex
                if not itemIdOrMultiTag then
                    itemIdOrMultiTag = normalCache.blockedMismatchItems[i].itemId
                elseif itemIdOrMultiTag ~= normalCache.blockedMismatchItems[i].itemId then
                    return false
                end
            end
            
            if itemIdOrMultiTag then
                local checkOpen = DeviceInfo.usingController and
                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                local alertInfo = {
                    condition = GEnums.FacSmartAlertType.NormalInputSingleBlocked,
                    targetTransform = self.m_smartAlertTargetTransformCache.inBelt[LuaIndex(blockPort)],
                    args = {},
                    checkRefresh = itemIdOrMultiTag .. tostring(blockPort),
                    defaultOpen = checkOpen
                }
                table.insert(alertInfo.args, UIUtils.getItemName(itemIdOrMultiTag))
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                return true, alertInfo
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNormalInputMultiBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, true, false)
        if normalCache and normalCache.blockedMismatchItems.Count > 0 then
            local itemIdOrMultiTag, blockPort
            for i = 0, normalCache.blockedMismatchItems.Count - 1 do
                blockPort = normalCache.blockedMismatchItems[i].portIndex
                if not itemIdOrMultiTag then
                    itemIdOrMultiTag = normalCache.blockedMismatchItems[i].itemId
                elseif itemIdOrMultiTag ~= normalCache.blockedMismatchItems[i].itemId then
                    itemIdOrMultiTag = true
                end
            end
            
            if itemIdOrMultiTag == true then
                local checkOpen = DeviceInfo.usingController and
                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                local alertInfo = {
                    condition = GEnums.FacSmartAlertType.NormalInputMultiBlocked,
                    targetTransform = self.m_smartAlertTargetTransformCache.inBelt[LuaIndex(blockPort)],
                    args = {},
                    checkRefresh = tostring(blockPort),
                    defaultOpen = checkOpen
                }
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                return true, alertInfo
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertFluidInputSingleBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local liquidCache = self.m_uiInfo:GetCache(i, true, true)
        if liquidCache and liquidCache.blockedMismatchItems.Count > 0 then
            local itemIdOrMultiTag, blockPort
            for i = 0, liquidCache.blockedMismatchItems.Count - 1 do
                blockPort = liquidCache.blockedMismatchItems[i].portIndex
                if not itemIdOrMultiTag then
                    itemIdOrMultiTag = liquidCache.blockedMismatchItems[i].itemId
                elseif itemIdOrMultiTag ~= liquidCache.blockedMismatchItems[i].itemId then
                    return false
                end
            end
            
            if itemIdOrMultiTag then
                local checkOpen = DeviceInfo.usingController and
                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                local alertInfo = {
                    condition = GEnums.FacSmartAlertType.FluidInputSingleBlocked,
                    targetTransform = self.m_smartAlertTargetTransformCache.inPipe[LuaIndex(blockPort)],
                    args = {},
                    checkRefresh = itemIdOrMultiTag .. tostring(blockPort),
                    defaultOpen = checkOpen
                }
                table.insert(alertInfo.args, UIUtils.getItemName(itemIdOrMultiTag))
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                return true, alertInfo
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertFluidInputMultiBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local liquidCache = self.m_uiInfo:GetCache(i, true, true)
        if liquidCache and liquidCache.blockedMismatchItems.Count > 0 then
            local itemIdOrMultiTag, blockPort
            for i = 0, liquidCache.blockedMismatchItems.Count - 1 do
                blockPort = liquidCache.blockedMismatchItems[i].portIndex
                if not itemIdOrMultiTag then
                    itemIdOrMultiTag = liquidCache.blockedMismatchItems[i].itemId
                elseif itemIdOrMultiTag ~= liquidCache.blockedMismatchItems[i].itemId then
                    itemIdOrMultiTag = true
                end
            end
            
            if itemIdOrMultiTag == true then
                local checkOpen = DeviceInfo.usingController and
                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                local alertInfo = {
                    condition = GEnums.FacSmartAlertType.FluidInputMultiBlocked,
                    targetTransform = self.m_smartAlertTargetTransformCache.inPipe[LuaIndex(blockPort)],
                    args = {},
                    checkRefresh = tostring(blockPort),
                    defaultOpen = checkOpen
                }
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                table.insert(alertInfo.args, self.m_smartAlertConditionDataCache.machineName)
                return true, alertInfo
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNormalOutputMultiBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    local _, outBeltInfoList = FactoryUtils.getBuildingPortState(self.m_nodeId, false)
    if outBeltInfoList then
        local blockPort = 0
        for i = 1, #outBeltInfoList do
            if outBeltInfoList[i].isBlock then
                blockPort = i
            end
        end
        if blockPort > 0 then
            local checkOpen = DeviceInfo.usingController and
                self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
            
            local alertInfo = {
                condition = GEnums.FacSmartAlertType.NormalOutputMultiBlocked,
                targetTransform = self.m_smartAlertTargetTransformCache.outBelt[blockPort],
                checkRefresh = tostring(blockPort),
                defaultOpen = checkOpen
            }
            return true, alertInfo
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertFluidOutputMultiBlockedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    local _, outPipeInfoList = FactoryUtils.getBuildingPortState(self.m_nodeId, true)
    if outPipeInfoList then
        local blockPort = 0
        for i = 1, #outPipeInfoList do
            if outPipeInfoList[i].isBlock then
                blockPort = i
            end
        end
        if blockPort > 0 then
            local checkOpen = DeviceInfo.usingController and
                self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
            
            local alertInfo = {
                condition = GEnums.FacSmartAlertType.FluidOutputMultiBlocked,
                targetTransform = self.m_smartAlertTargetTransformCache.outPipe[blockPort],
                checkRefresh = tostring(blockPort),
                defaultOpen = checkOpen
            }
            return true, alertInfo
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertInputCacheFullCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Normal then
        return false
    end
    local inBeltInfoList = FactoryUtils.getBuildingPortState(self.m_nodeId, false)
    local inPipeInfoList = FactoryUtils.getBuildingPortState(self.m_nodeId, true)
    if inBeltInfoList then
        for i = 1, #inBeltInfoList do
            if inBeltInfoList[i].isBlock then
                local normalCache = self.m_uiInfo:GetCache(1, true, false)
                if normalCache and normalCache.items.Count > 0 then
                    for itemId, itemCount in cs_pairs(normalCache.items) do
                        local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                        if facItemSuccess then
                            
                            if itemCount >= facItemData.buildingBufferStackLimit - 1 then
                                local _, csIndex = normalCache.itemOrderMap:TryGetValue(itemId)
                                local checkOpen = DeviceInfo.usingController and
                                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                                local alertInfo = {
                                    condition = GEnums.FacSmartAlertType.InputCacheFull,
                                    targetTransform = self.m_smartAlertTargetTransformCache.normalInput[LuaIndex(csIndex)],
                                    checkRefresh = "normal" .. tostring(csIndex),
                                    defaultOpen = checkOpen
                                }
                                return true, alertInfo
                            end
                        end
                    end
                end
                break
            end
        end
    end
    if inPipeInfoList then
        for i = 1, #inPipeInfoList do
            if inPipeInfoList[i].isBlock then
                local liquidCache = self.m_uiInfo:GetCache(1, true, true)
                if liquidCache and liquidCache.items.Count > 0 then
                    for itemId, itemCount in cs_pairs(liquidCache.items) do
                        local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                        if facItemSuccess then
                            
                            if itemCount >= facItemData.buildingBufferStackLimit - 1 then
                                local _, csIndex = liquidCache.itemOrderMap:TryGetValue(itemId)
                                local checkOpen = DeviceInfo.usingController and
                                    self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                                    self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                                local alertInfo = {
                                    condition = GEnums.FacSmartAlertType.InputCacheFull,
                                    targetTransform = self.m_smartAlertTargetTransformCache.fluidInput[LuaIndex(csIndex)],
                                    checkRefresh = "fluid" .. tostring(csIndex),
                                    defaultOpen = checkOpen
                                }
                                return true, alertInfo
                            end
                        end
                    end
                end
                break
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertOutputCacheFullWithoutBeltCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Blocked then
        return false
    end
    if self.m_smartAlertConditionDataCache.hasBelt then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, false, false)
        if normalCache and normalCache.items.Count > 0 then
            for itemId, itemCount in cs_pairs(normalCache.items) do
                local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                if facItemSuccess then
                    if itemCount >= facItemData.buildingBufferStackLimit then
                        local _, csIndex = normalCache.itemOrderMap:TryGetValue(itemId)
                        local checkOpen = DeviceInfo.usingController and
                            self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                        
                        local alertInfo = {
                            condition = GEnums.FacSmartAlertType.OutputCacheFullWithoutBelt,
                            targetTransform = self.m_smartAlertTargetTransformCache.normalOutput[LuaIndex(csIndex)],
                            args = {},
                            checkRefresh = itemId .. tostring(csIndex),
                            defaultOpen = checkOpen
                        }
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        return true, alertInfo
                    end
                end
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertOutputCacheFullWithBeltCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Blocked then
        return false
    end
    if not self.m_smartAlertConditionDataCache.hasBelt then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, false, false)
        if normalCache and normalCache.items.Count > 0 then
            for itemId, itemCount in cs_pairs(normalCache.items) do
                local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                if facItemSuccess then
                    if itemCount >= facItemData.buildingBufferStackLimit then
                        local _, csIndex = normalCache.itemOrderMap:TryGetValue(itemId)
                        local checkOpen = DeviceInfo.usingController and
                            self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                        
                        local alertInfo = {
                            condition = GEnums.FacSmartAlertType.OutputCacheFullWithBelt,
                            targetTransform = self.m_smartAlertTargetTransformCache.lastOutBelt,
                            args = {},
                            checkRefresh = itemId,
                            defaultOpen = checkOpen
                        }
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        return true, alertInfo
                    end
                end
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertOutputCacheFullWithoutPipeCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Blocked then
        return false
    end
    if self.m_smartAlertConditionDataCache.hasPipe then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local liquidCache = self.m_uiInfo:GetCache(i, false, true)
        if liquidCache and liquidCache.items.Count > 0 then
            for itemId, itemCount in cs_pairs(liquidCache.items) do
                local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                if facItemSuccess then
                    if itemCount >= facItemData.buildingBufferStackLimit then
                        local _, csIndex = liquidCache.itemOrderMap:TryGetValue(itemId)
                        local checkOpen = DeviceInfo.usingController and
                            self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                        
                        local alertInfo = {
                            condition = GEnums.FacSmartAlertType.OutputCacheFullWithoutPipe,
                            targetTransform = self.m_smartAlertTargetTransformCache.fluidOutput[LuaIndex(csIndex)],
                            args = {},
                            checkRefresh = itemId .. tostring(csIndex),
                            defaultOpen = checkOpen
                        }
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        return true, alertInfo
                    end
                end
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertOutputCacheFullWithPipeCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Blocked then
        return false
    end
    if not self.m_smartAlertConditionDataCache.hasPipe then
        return false
    end
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local liquidCache = self.m_uiInfo:GetCache(i, false, true)
        if liquidCache and liquidCache.items.Count > 0 then
            for itemId, itemCount in cs_pairs(liquidCache.items) do
                local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(itemId)
                if facItemSuccess then
                    if itemCount >= facItemData.buildingBufferStackLimit then
                        local hasPipe = GameInstance.remoteFactoryManager.unlockSystem.systemUnlockedPipe
                        local _, csIndex = liquidCache.itemOrderMap:TryGetValue(itemId)
                        local checkOpen = DeviceInfo.usingController and
                            self.view.cacheArea:CheckRepoNaviTargetTopLayer(false) and
                            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                        
                        local alertInfo = {
                            condition = GEnums.FacSmartAlertType.OutputCacheFullWithPipe,
                            targetTransform = self.m_smartAlertTargetTransformCache.outPipe[LuaIndex(csIndex)],
                            args = {},
                            checkRefresh = itemId .. tostring(csIndex),
                            defaultOpen = checkOpen
                        }
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        table.insert(alertInfo.args, UIUtils.getItemName(itemId))
                        return true, alertInfo
                    end
                end
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertInputInvalidFormulaCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Idle then
        return false
    end
    local effectiveFormulaItemMap = self.m_smartAlertConditionDataCache.effectiveFormula
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, true, false)
        if normalCache and normalCache.items.Count > 0 then
            for itemId, _ in cs_pairs(normalCache.items) do
                if not effectiveFormulaItemMap[itemId] then
                    local _, csIndex = normalCache.itemOrderMap:TryGetValue(itemId)
                    local checkOpen = DeviceInfo.usingController and
                        self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                        self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                    local alertInfo = {
                        condition = GEnums.FacSmartAlertType.InputInvalidFormula,
                        targetTransform = self.m_smartAlertTargetTransformCache.normalInput[LuaIndex(csIndex)],
                        checkRefresh = "normal" .. csIndex,
                        defaultOpen = checkOpen
                    }
                    return true, alertInfo
                end
            end
        end
        local liquidCache = self.m_uiInfo:GetCache(i, true, true)
        if liquidCache and liquidCache.items.Count > 0 then
            for itemId, _ in cs_pairs(liquidCache.items) do
                if not effectiveFormulaItemMap[itemId] then
                    local _, csIndex = liquidCache.itemOrderMap:TryGetValue(itemId)
                    local checkOpen = DeviceInfo.usingController and
                        self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
                        self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
                    local alertInfo = {
                        condition = GEnums.FacSmartAlertType.InputInvalidFormula,
                        targetTransform = self.m_smartAlertTargetTransformCache.fluidInput[LuaIndex(csIndex)],
                        checkRefresh = "fluid" .. csIndex,
                        defaultOpen = checkOpen
                    }
                    return true, alertInfo
                end
            end
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNormalInputEmptyCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Idle then
        return false
    end
    if not self.m_smartAlertConditionDataCache.hasItemCache then
        return false
    end
    local itemEmpty = true
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local normalCache = self.m_uiInfo:GetCache(i, true, false)
        if normalCache and normalCache.items.Count > 0 then
            itemEmpty = false
            break
        end
    end
    if itemEmpty then
        local checkOpen = DeviceInfo.usingController and
            self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
        local alertInfo = {
            condition = GEnums.FacSmartAlertType.NormalInputEmpty,
            targetTransform = self.m_smartAlertTargetTransformCache.normalInput[1],
            defaultOpen = checkOpen
        }
        return true, alertInfo
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertFluidInputEmptyCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Idle then
        return false
    end
    if not self.m_smartAlertConditionDataCache.hasFluidCache then
        return false
    end
    local fluidEmpty = true
    for i = START_CACHE_COUNT, MAX_CACHE_COUNT do
        local liquidCache = self.m_uiInfo:GetCache(i, true, true)
        if liquidCache and liquidCache.items.Count > 0 then
            fluidEmpty = false
            break
        end
    end
    if fluidEmpty then
        local checkOpen = DeviceInfo.usingController and
            self.view.cacheArea:CheckRepoNaviTargetTopLayer(true) and
            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
        local alertInfo = {
            condition = GEnums.FacSmartAlertType.FluidInputEmpty,
            targetTransform = self.m_smartAlertTargetTransformCache.fluidInput[1],
            defaultOpen = checkOpen
        }
        return true, alertInfo
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertCanBeOpenedCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.Closed then
        return false
    end
    local node = self.m_uiInfo.nodeHandler
    if node and node.power and node.power.powerCost then
        local curCost = node.power.powerCost
        local powerInfo = FactoryUtils.getCurRegionPowerInfo()
        local powerCost = powerInfo.powerCost
        local powerGen = powerInfo.powerGen
        if powerCost + curCost <= powerGen then
            local checkOpen = DeviceInfo.usingController and
                self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
            local alertInfo = {
                condition = GEnums.FacSmartAlertType.CanBeOpened,
                targetTransform = self.m_smartAlertTargetTransformCache.state,
                defaultOpen = checkOpen
            }
            return true, alertInfo
        end
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNoPowerWithoutDiffuserCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.NotInPowerNet then
        return false
    end
    if self.m_uiInfo.inPowerRangeDiffusers.Count <= 0 then
        local checkOpen = DeviceInfo.usingController and
            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
        local alertInfo = {
            condition = GEnums.FacSmartAlertType.NoPowerWithoutDiffuser,
            targetTransform = self.m_smartAlertTargetTransformCache.state,
            defaultOpen = checkOpen
        }
        return true, alertInfo
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNoPowerWithDiffuserCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.NotInPowerNet then
        return false
    end
    if self.m_uiInfo.inPowerRangeDiffusers.Count > 0 then
        local checkOpen = DeviceInfo.usingController and
            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
        local alertInfo = {
            condition = GEnums.FacSmartAlertType.NoPowerWithDiffuser,
            targetTransform = self.m_smartAlertTargetTransformCache.state,
            defaultOpen = checkOpen
        }
        return true, alertInfo
    end
    return false
end




FacMachineCrafterCtrl._CheckAlertNoPowerCondition = HL.Method(HL.Userdata).Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.view.buildingCommon.smartAlertChangeCachePauseUpdate or state ~= GEnums.FacBuildingState.NoPower then
        return false
    end
    local checkOpen = DeviceInfo.usingController and
        self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
    local alertInfo = {
        condition = GEnums.FacSmartAlertType.NoPower,
        targetTransform = self.m_smartAlertTargetTransformCache.state,
        defaultOpen = checkOpen
    }
    return true, alertInfo
end




HL.Commit(FacMachineCrafterCtrl)
