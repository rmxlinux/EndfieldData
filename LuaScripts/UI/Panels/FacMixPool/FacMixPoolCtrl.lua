local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacMixPool
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget

local MainState = {
    None = "None",
    Normal = "Normal",  
    Select = "Select",  
}

local CacheItemSlotState = {
    None = "None",
    Empty = "Empty",          
    Normal = "Normal",        
    Locked = "Locked",        
    Blocked = "Blocked",      
    Dimmed = "Dimmed",        
}

local SelectorState = {
    None = "None",
    Empty = "Empty",    
    Normal = "Normal",  
}

local CenterState = {
    None = "None",
    Blocked = "Blocked",  
    Normal = "Normal",    
}

local ArrowState = {
    None = "None",
    Active = "Active",      
    Inactive = "Inactive",  
}

local NaviDir = {
    Up = 1,
    Down = 2,
    Left = 3,
    Right = 4,
}

local NaviDirMap = {
    [1] = { -1, -1, 2, 3 },
    [2] = { 1, 4, -1, 4 },
    [3] = { 1, 5, 5, 0 },
    [4] = { 2, -1, 2, 5 },
    [5] = { 3, -1, 4, 3 },
}

local FindCacheNaviPriority = { 2, 4, 1, 5, 3 }
local FindSelectNaviPriority = { 3, 1, 2 }































































FacMixPoolCtrl = HL.Class('FacMixPoolCtrl', uiCtrl.UICtrl)

local CACHE_ITEM_SLOT_VIEW_NAME_FORMAT = "itemSlot%d"
local CACHE_INPUT_ARROW_VIEW_NAME_FORMAT = "inputNode%d"
local CACHE_OUTPUT_ARROW_VIEW_NAME_FORMAT = "outputNode%d"
local MAX_POOL_CACHE_SLOT_COUNT = 5
local MAIN_SELECT_MODE_IN_ANIM_NAME = {
    "mixpool_select_in",
    "mixpool_select_in_Space_Bottom",
    "mixpool_select_in_Space_Top"
}
local MAIN_SELECT_MODE_OUT_ANIM_NAME = "mixpool_select_out"

local ARROW_NODE_ANIM_REFRESH_MAX_COUNT = 4
local ARROW_NODE_ANIM_REFRESH_VIEW_NAME_FORMAT = "arrow%d"


local POOL_CACHE_BRIDGE_INDEX = 3


FacMixPoolCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FluidReaction)


FacMixPoolCtrl.m_onCacheChanged = HL.Field(HL.Function)


FacMixPoolCtrl.m_cacheItemDataList = HL.Field(HL.Table)


FacMixPoolCtrl.m_cacheItemIdToIndexMap = HL.Field(HL.Table)


FacMixPoolCtrl.m_nextValidIndex = HL.Field(HL.Number) << -1


FacMixPoolCtrl.m_inputItemList = HL.Field(HL.Table)


FacMixPoolCtrl.m_outputItemList = HL.Field(HL.Table)


FacMixPoolCtrl.m_selectorConfig = HL.Field(HL.Table)


FacMixPoolCtrl.m_selectModeIndex = HL.Field(HL.Number) << -1


FacMixPoolCtrl.m_selectModeItemId = HL.Field(HL.String) << ""


FacMixPoolCtrl.m_lastHoverTipsItemTag = HL.Field(HL.String) << ""


FacMixPoolCtrl.m_stopHoverTips = HL.Field(HL.Boolean) << false


FacMixPoolCtrl.m_isInSelectMode = HL.Field(HL.Boolean) << false


FacMixPoolCtrl.m_formulaIdList = HL.Field(HL.Table)


FacMixPoolCtrl.m_blockedFormulaIdList = HL.Field(HL.Table)






FacMixPoolCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.FAC_NAVI_TO_MIXPOOL_TARGET_ITEM] = "OnActionNaviToTarget",
}





FacMixPoolCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo
    self.m_cacheItemDataList = {}
    self.m_cacheItemIdToIndexMap = {}

    self.view.facCacheBelt:InitFacCacheBelt(self.m_buildingInfo, { noGroup = true })

    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo)

    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo, {
        onStateChanged = function(state)
            self:_RefreshPoolCacheArrowsRunningState()
            self:_RefreshPoolFormulaRunningAnimState()
        end
    })

    self:_InitPoolCache()
    self:_InitPoolFormula()
    self:_InitPoolSelector()

    self:_UpdateAndRefreshAll()
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_UpdateAndRefreshAll()
        end
    end)

    self:_InitControllerChangeAction()
end



FacMixPoolCtrl.OnClose = HL.Override() << function(self)
    self:_ClearPoolCache()
end




FacMixPoolCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        Notify(MessageConst.HIDE_COMMON_HOVER_TIP)
        self.m_lastHoverTipsItemTag = ""
    end
    self.m_stopHoverTips = not active
end



FacMixPoolCtrl._UpdateAndRefreshAll = HL.Method() << function(self)
    self:_UpdatePoolFormulaDataList()
    self:_UpdatePoolCacheItemDataList()
    self:_RefreshPoolCacheItemSlotList()
    self:_RefreshPoolSelectorList()
    self:_RefreshPoolCacheSlotHighlightState()
    self:_RefreshPoolFormulaState()

    if self.m_isInSelectMode then
        self:_RefreshPoolCacheSelectModeState(true)
    end
end






FacMixPoolCtrl._InitPoolCache = HL.Method() << function(self)
    self.m_onCacheChanged = function(changedItems, hasNewOrRemove)
        self:_OnPoolCacheChanged(changedItems, hasNewOrRemove)
    end
    self.m_buildingInfo.cache.onCacheChanged:AddListener(self.m_onCacheChanged)
    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_buildingInfo.nodeId)

    
    self:_ClearPoolCacheItemDataList()
end



FacMixPoolCtrl._ClearPoolCache = HL.Method() << function(self)
    self.m_buildingInfo.cache.onCacheChanged:RemoveListener(self.m_onCacheChanged)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
end



FacMixPoolCtrl._ClearPoolCacheItemDataList = HL.Method() << function(self)
    for index = 1, MAX_POOL_CACHE_SLOT_COUNT do
        if self.m_cacheItemDataList[index] == nil then
            self.m_cacheItemDataList[index] = {
                id = "",
                count = 0,
            }
        end
    end
end





FacMixPoolCtrl._OnPoolCacheChanged = HL.Method(HL.Userdata, HL.Boolean) << function(self, changedItems, hasNewOrRemove)
    self:_UpdateAndRefreshAll()
end



FacMixPoolCtrl._UpdatePoolCacheItemDataList = HL.Method() << function(self)
    local items = self.m_buildingInfo.cache.items
    local itemOrderMap = self.m_buildingInfo.cache.itemOrderMap

    local dirtyItemIdList = {}
    for id, count in cs_pairs(items) do
        local orderSuccess, csIndex = itemOrderMap:TryGetValue(id)
        if orderSuccess then
            local luaIndex = LuaIndex(csIndex)

            local lastIndex = self.m_cacheItemIdToIndexMap[id]
            if lastIndex ~= nil and lastIndex ~= luaIndex then
                
                self.m_cacheItemDataList[lastIndex] = {
                    id = "",
                    count = 0,
                }
            end

            self.m_cacheItemDataList[luaIndex] = {
                id = id,
                count = count,
            }
            dirtyItemIdList[id] = true
        end
    end

    
    for _, itemData in pairs(self.m_cacheItemDataList) do
        local itemId = itemData.id
        if not dirtyItemIdList[itemId] then
            itemData.count = 0
        end
    end

    self:_RecordItemIdToIndexMap()  

    local fillFunction = function(itemList)
        for itemId, _ in pairs(itemList) do
            if self.m_nextValidIndex > self.m_buildingInfo.cache.size then
                break
            end
            if self.m_cacheItemIdToIndexMap[itemId] == nil then
                
                self.m_cacheItemDataList[self.m_nextValidIndex] = {
                    id = itemId,
                    count = 0,
                }
            end
        end
    end

    fillFunction(self.m_inputItemList)
    fillFunction(self.m_outputItemList)

    self:_RecordItemIdToIndexMap()  
end



FacMixPoolCtrl._RecordItemIdToIndexMap = HL.Method() << function(self)
    self.m_cacheItemIdToIndexMap = {}
    local maxIndex = self.m_buildingInfo.cache.size + 1
    self.m_nextValidIndex = maxIndex
    for index, itemData in ipairs(self.m_cacheItemDataList) do
        local itemId = itemData.id
        if not string.isEmpty(itemData.id) then
            self.m_cacheItemIdToIndexMap[itemId] = index

            local nextIndex = index + 1
            if nextIndex < maxIndex and nextIndex < self.m_nextValidIndex then
                local nextItemData = self.m_cacheItemDataList[nextIndex]
                if string.isEmpty(nextItemData.id) then
                    self.m_nextValidIndex = nextIndex
                end
            end
        end
    end
end



FacMixPoolCtrl._RefreshPoolCacheItemSlotList = HL.Method() << function(self)
    for index = 1, MAX_POOL_CACHE_SLOT_COUNT do
        self:_RefreshPoolCacheItemSlot(index)
        self:_RefreshPoolCacheArrowState(index)
    end
    self:_ToggleCacheBindingAction()
end




FacMixPoolCtrl._RefreshPoolCacheItemSlot = HL.Method(HL.Number) << function(self, index)
    local itemData = self.m_cacheItemDataList[index]
    if itemData == nil then
        return
    end

    local itemSlot = self:_GetPoolCacheItemSlotByIndex(index)
    if itemSlot == nil then
        return
    end

    if index > self.m_buildingInfo.cache.size then
        self:_RefreshPoolCacheItemState(index, CacheItemSlotState.Locked)
        return
    end

    local itemId = itemData.id
    if string.isEmpty(itemId) then
        self:_RefreshPoolCacheItemState(index, CacheItemSlotState.Empty)
        return
    end

    itemSlot.item:InitItem(itemData)
    itemSlot.button.onClick:RemoveAllListeners()
    itemSlot.button.onClick:AddListener(function()
        self:_OnClickPoolCacheItemSlot(index)
    end)

    local itemCount = itemData.count
    if itemCount > 0 then
        local success, data = Tables.factoryItemTable:TryGetValue(itemId)
        if success then
            local maxStackBuffer = data.buildingBufferStackLimit
            local state = itemCount < maxStackBuffer and CacheItemSlotState.Normal or CacheItemSlotState.Blocked
            self:_RefreshPoolCacheItemState(index, state)
        end
    else
        self:_RefreshPoolCacheItemState(index, CacheItemSlotState.Dimmed)
    end
end




FacMixPoolCtrl._RefreshPoolCacheArrowState = HL.Method(HL.Number) << function(self, index)
    local itemData = self.m_cacheItemDataList[index]
    if itemData == nil then
        return
    end

    local itemId = itemData.id
    local inputArrow = self.view.inputArrowList[string.format(CACHE_INPUT_ARROW_VIEW_NAME_FORMAT, index)]
    local outputArrow = self.view.outputArrowList[string.format(CACHE_OUTPUT_ARROW_VIEW_NAME_FORMAT, index)]

    if index > self.m_buildingInfo.cache.size then
        inputArrow.gameObject:SetActiveIfNecessary(false)
        outputArrow.gameObject:SetActiveIfNecessary(false)
        return
    end

    local isInput = self.m_inputItemList[itemId]
    local isOutput = self.m_outputItemList[itemId]
    inputArrow.gameObject:SetActiveIfNecessary(true)
    outputArrow.gameObject:SetActiveIfNecessary(true)


    local inArrowState = isInput and ArrowState.Active or ArrowState.Inactive
    inputArrow.stateController:SetState(inArrowState)

    local outArrowState = isOutput and ArrowState.Active or ArrowState.Inactive
    outputArrow.stateController:SetState(outArrowState)

    self:_RefreshPoolCacheArrowRunningState(index)
end



FacMixPoolCtrl._RefreshPoolCacheArrowsRunningState = HL.Method() << function(self)
    for index = 1, MAX_POOL_CACHE_SLOT_COUNT do
        if index <= self.m_buildingInfo.cache.size then
            self:_RefreshPoolCacheArrowRunningState(index)
        end
    end
end




FacMixPoolCtrl._RefreshPoolCacheArrowRunningState = HL.Method(HL.Number) << function(self, index)
    local inputArrow = self.view.inputArrowList[string.format(CACHE_INPUT_ARROW_VIEW_NAME_FORMAT, index)]
    local outputArrow = self.view.outputArrowList[string.format(CACHE_OUTPUT_ARROW_VIEW_NAME_FORMAT, index)]

    local isRunning = self.view.buildingCommon.lastState == GEnums.FacBuildingState.Normal

    local stateRefreshFunc = function(arrow, isIn)
        if isRunning then
            local animName = isIn and "facmixpoolwhitenormalbg_loop" or "facmixpoolnormalbg_loop"
            if arrow.animationWrapper.curStateName ~= animName then
                arrow.animationWrapper:PlayWithTween(animName)
            end
            arrow.isRunning = true
        else
            local animName = isIn and "facmixpoolwhitenormalbg_default" or "facmixpoolnormalbg_default"
            if arrow.animationWrapper.curStateName ~= animName then
                arrow.animationWrapper:PlayWithTween(animName)
            end
            arrow.isRunning = false
        end
        for arrowIndex = 1, ARROW_NODE_ANIM_REFRESH_MAX_COUNT do
            local arrowNode = arrow[string.format(ARROW_NODE_ANIM_REFRESH_VIEW_NAME_FORMAT, arrowIndex)]
            arrowNode.gameObject:SetActive(isRunning)
        end
        arrow.staticArrow.gameObject:SetActive(not isRunning)
    end

    if inputArrow.stateController.curStateName == ArrowState.Active then
        stateRefreshFunc(inputArrow, true)
    end

    if outputArrow.stateController.curStateName == ArrowState.Active then
        stateRefreshFunc(outputArrow, false)
    end
end





FacMixPoolCtrl._RefreshPoolCacheItemState = HL.Method(HL.Number, HL.String) << function(self, index, state)
    local itemSlot = self.view.cacheItemList[string.format(CACHE_ITEM_SLOT_VIEW_NAME_FORMAT, index)]
    if itemSlot == nil then
        return
    end

    local stateChanged = itemSlot.controller.curStateName ~= nil and itemSlot.controller.curStateName ~= state
    local isNormalOrBlockedState = itemSlot.controller.curStateName == CacheItemSlotState.Normal or
        itemSlot.controller.curStateName == CacheItemSlotState.Blocked
    if stateChanged and isNormalOrBlockedState then
        local animName = state == CacheItemSlotState.Normal and "facmixpoolitemblocked_out" or "facmixpoolitemblocked_in"
        itemSlot.animationWrapper:PlayWithTween(animName, function()
            if state == CacheItemSlotState.Normal then
                itemSlot.controller:SetState(state)  
            end
        end)
        if state == CacheItemSlotState.Blocked then
            itemSlot.controller:SetState(state)
        end
    else
        itemSlot.controller:SetState(state)
    end

    itemSlot.item.view.count.color = state == CacheItemSlotState.Blocked and
        self.view.config.CACHE_SLOT_BLOCKED_COUNT_COLOR or
        Color.white
end




FacMixPoolCtrl._GetPoolCacheItemSlotByIndex = HL.Method(HL.Number).Return(HL.Any) << function(self, index)
    return self.view.cacheItemList[string.format(CACHE_ITEM_SLOT_VIEW_NAME_FORMAT, index)]
end




FacMixPoolCtrl._GetPoolCacheItemDataById = HL.Method(HL.String).Return(HL.Any) << function(self, itemId)
    for _, itemData in pairs(self.m_cacheItemDataList) do
        if itemData.id == itemId then
            return itemData
        end
    end
    return nil
end




FacMixPoolCtrl._OnClickPoolCacheItemSlot = HL.Method(HL.Number) << function(self, index)
    local itemData = self.m_cacheItemDataList[index]
    if itemData == nil then
        return
    end

    local itemSlot = self.view.cacheItemList[string.format(CACHE_ITEM_SLOT_VIEW_NAME_FORMAT, index)]
    if itemSlot == nil then
        return
    end

    AudioAdapter.PostEvent("Au_UI_Button_Item")

    if self.m_isInSelectMode then
        self:_SetAndRefreshPoolSelectModeSelectorState(itemData.id)
    else
        itemSlot.highlightBg.gameObject:SetActiveIfNecessary(true)
        itemSlot.item:ShowTips(nil, function()
            if self.m_isClosed then
                return
            end
            itemSlot.highlightBg.gameObject:SetActiveIfNecessary(false)
        end)
    end
end








FacMixPoolCtrl._InitPoolFormula = HL.Method() << function(self)
    self.view.formulaButton.onClick:AddListener(function()
        Notify(MessageConst.FAC_SHOW_FORMULA, {
            nodeId = self.m_buildingInfo.nodeId,
            buildingId = self.m_buildingInfo.buildingId,
            isMachineCrafterFormula = true,
            belongingCanvasGroup = self.view.canvasGroup,
            highlightFormulaIdList = self.m_formulaIdList,
            blockFormulaIdList = self.m_blockedFormulaIdList,
        })
    end)

    if not Utils.isInBlackbox() then
        self.view.redDot:InitRedDot("BuildingFormula", {
            buildingId = self.m_buildingInfo.buildingId,
            modeName = FacConst.FAC_FORMULA_MODE_MAP.LIQUID
        })
        self.view.redDot.gameObject:SetActive(true)
    else
        self.view.redDot.gameObject:SetActive(false)
    end
end



FacMixPoolCtrl._UpdatePoolFormulaDataList = HL.Method() << function(self)
    local formulaList = self.m_buildingInfo.fluidReaction.formulas
    self.m_inputItemList = {}
    self.m_outputItemList = {}
    for _, formula in cs_pairs(formulaList) do
        local formulaId = formula.formulaId
        local success, formulaData = Tables.factoryMachineCraftTable:TryGetValue(formulaId)
        if success then
            local ingredients = formulaData.ingredients
            for ingredientIdx = 0, ingredients.Count - 1 do
                local ingredient = ingredients[ingredientIdx]
                local inputItemList = ingredient.group
                for inputBundleIdx = 0, inputItemList.Count - 1 do
                    local inputItemBundle = inputItemList[inputBundleIdx]
                    self.m_inputItemList[inputItemBundle.id] = true
                end
            end
            local outcomes = formulaData.outcomes
            for outcomeIdx = 0, outcomes.Count - 1 do
                local outcome = outcomes[outcomeIdx]
                local outputItemList = outcome.group
                for outputBundleIdx = 0, outputItemList.Count - 1 do
                    local outputItemBundle = outputItemList[outputBundleIdx]
                    self.m_outputItemList[outputItemBundle.id] = true
                end
            end
        end
    end

    self.m_formulaIdList = {}
    self.m_blockedFormulaIdList = {}
    for _, formulaData in cs_pairs(self.m_buildingInfo.fluidReaction.formulas) do
        local formulaId = formulaData.formulaId
        table.insert(self.m_formulaIdList, formulaId)
        if self.m_buildingInfo:IsBlockedFormula(formulaId) then
            table.insert(self.m_blockedFormulaIdList, formulaId)
        end
    end
end



FacMixPoolCtrl._RefreshPoolFormulaState = HL.Method() << function(self)
    local state = next(self.m_blockedFormulaIdList) == nil and CenterState.Normal or CenterState.Blocked
    if self.view.centerController.curStateName ~= nil and self.view.centerController.curStateName ~= state then
        local animName = state == CenterState.Blocked and "facmixpoolblocked_in" or "facmixpoolblocked_out"
        self.view.centerAnimationWrapper:PlayWithTween(animName, function()
            self:_RefreshPoolFormulaRunningAnimState()
        end)
    end
    self.view.centerController:SetState(state)
end



FacMixPoolCtrl._RefreshPoolFormulaRunningAnimState = HL.Method() << function(self)
    local isRunning = self.view.buildingCommon.lastState == GEnums.FacBuildingState.Normal
    local animName = isRunning and "facmixpoolblocked_loop" or "facmixpoolblocked_gray"
    self.view.centerAnimationWrapper:PlayWithTween(animName)
end








FacMixPoolCtrl._InitPoolSelector = HL.Method() << function(self)
    self:_InitPoolSelectorConfig()
    self:_InitPoolSelectorButtons()
    self.view.mainController:SetState(MainState.Normal)
end



FacMixPoolCtrl._InitPoolSelectorConfig = HL.Method() << function(self)
    










    local selectorNode = self.view.selectorNode
    self.m_selectorConfig = {
        {
            viewSelector = selectorNode.selector1,
            compSelector = self.m_buildingInfo.selector1,
            viewPortNodeList = {
                self.view.facCacheBelt.view.outBeltGroup,
                self.view.facCacheBelt.view.outFacLineDrawer,
                self.view.facCacheBelt.view.outEndLineCell,
            },
            isFluid = false,
        },
        {
            viewSelector = selectorNode.selector2,
            compSelector = self.m_buildingInfo.selector2,
            viewPortNodeList = {
                self.view.facCachePipe.view.pipeCell4
            },
            isFluid = true,
        },
        {
            viewSelector = selectorNode.selector3,
            compSelector = self.m_buildingInfo.selector3,
            viewPortNodeList = {
                self.view.facCachePipe.view.pipeCell3
            },
            isFluid = true,
        },
    }
end



FacMixPoolCtrl._InitPoolSelectorButtons = HL.Method() << function(self)
    for selectorIndex, selectorInfo in ipairs(self.m_selectorConfig) do
        local viewSelector = selectorInfo.viewSelector
        viewSelector.selectButton.onClick:AddListener(function()
            self:_OnEnterPoolSelectMode(selectorIndex)
        end)
        viewSelector.switchButton.onClick:AddListener(function()
            self:_OnEnterPoolSelectMode(selectorIndex)
        end)
    end

    self.view.selectModeNode.confirmButton.onClick:AddListener(function()
        self:_OnClickSelectModeConfirmBtn()
    end)
    self.view.selectModeNode.cancelButton.onClick:AddListener(function()
        self:_SetAndRefreshPoolSelectModeSelectorState("")
    end)
    self.view.selectBackBtn.onClick:AddListener(function()
        self:_OnLeavePoolSelectMode()
    end)
    self.view.selectBackMaskBtn.onClick:AddListener(function()
        self:_OnLeavePoolSelectMode()
    end)
end



FacMixPoolCtrl._OnClickSelectModeConfirmBtn = HL.Method() << function(self)
    local selectorInfo = self.m_selectorConfig[self.m_selectModeIndex]
    if selectorInfo == nil then
        return
    end

    self.m_buildingInfo.sender:Message_OpSetSelectTarget(
        Utils.getCurrentChapterId(),
        selectorInfo.compSelector.componentId,
        self.m_selectModeItemId,
        function()
            self.m_buildingInfo:Update()
            self:_UpdateAndRefreshAll()
            self:_OnLeavePoolSelectMode()
        end
    )
end



FacMixPoolCtrl._RefreshPoolSelectorList = HL.Method() << function(self)
    for selectorIndex = 1, #self.m_selectorConfig do
        self:_RefreshPoolSelectorState(selectorIndex)
        self:_RefreshPoolSelectorButtonController(selectorIndex)
    end
end




FacMixPoolCtrl._RefreshPoolSelectorState = HL.Method(HL.Number) << function(self, selectorIndex)
    local selectorInfo = self.m_selectorConfig[selectorIndex]
    if selectorInfo == nil then
        return
    end

    local viewSelector, compSelector = selectorInfo.viewSelector, selectorInfo.compSelector
    local selectItemId = compSelector.selectItemId
    if string.isEmpty(selectItemId) then
        viewSelector.lineCell:ChangeLineColor(self.view.config.INACTIVE_SELECTOR_LINE_COLOR)
        viewSelector.stateController:SetState(SelectorState.Empty)
        return
    end

    local itemData = self:_GetPoolCacheItemDataById(selectItemId)
    if itemData == nil then
        itemData = { id = selectItemId, count = 0 }  
    end

    if viewSelector.item.id == selectItemId then
        viewSelector.item:UpdateCountSimple(itemData.count)
    else
        viewSelector.item:InitItem(itemData, true)
    end
    local blocked = false
    if itemData.count > 0 then
        local success, data = Tables.factoryItemTable:TryGetValue(selectItemId)
        if success then
            blocked = itemData.count >= data.buildingBufferStackLimit
        end
    end
    viewSelector.item.view.count.color = blocked and self.view.config.CACHE_SLOT_BLOCKED_COUNT_COLOR or Color.white

    viewSelector.lineCell:ChangeLineColor(self.view.config.ACTIVE_SELECTOR_LINE_COLOR)
    viewSelector.stateController:SetState(SelectorState.Normal)
end




FacMixPoolCtrl._OnEnterPoolSelectMode = HL.Method(HL.Number) << function(self, selectorIndex)
    local currSelectorInfo = self.m_selectorConfig[selectorIndex]
    if currSelectorInfo == nil then
        return
    end

    if string.isEmpty(currSelectorInfo.compSelector.selectItemId) then
        AudioAdapter.PostEvent("Au_UI_Button_Common")
    else
        AudioAdapter.PostEvent("Au_UI_Button_Reset")
    end

    self.m_selectModeIndex = selectorIndex
    for index, selectorInfo in ipairs(self.m_selectorConfig) do
        for _, node in ipairs(selectorInfo.viewPortNodeList) do
            node.gameObject:SetActiveIfNecessary(selectorIndex == index)
        end
    end

    local typeMatched = false
    for index = 1, self.m_buildingInfo.cache.size do
        local itemData = self.m_cacheItemDataList[index]
        typeMatched = currSelectorInfo.isFluid == FactoryUtils.isFactoryItemFluid(itemData.id) and not string.isEmpty(itemData.id)
        if typeMatched then
            break
        end
    end
    self.view.nopProductTips.gameObject:SetActiveIfNecessary(not typeMatched)

    self.view.mainController:SetState(MainState.Select)
    self.view.mainAnimation:PlayWithTween(MAIN_SELECT_MODE_IN_ANIM_NAME[selectorIndex])

    self.view.selectModeNode.selector.normal.gameObject:SetActiveIfNecessary(not currSelectorInfo.isFluid)
    self.view.selectModeNode.selector.fluid.gameObject:SetActiveIfNecessary(currSelectorInfo.isFluid)
    self:_SetAndRefreshPoolSelectModeSelectorState(currSelectorInfo.compSelector.selectItemId)
    self:_RefreshPoolCacheSelectModeState(true, true)

    self.view.facCacheBelt:SetCacheBeltSingleState(true)
    self.view.facCachePipe:SetCachePipeSingleState(true)

    AudioAdapter.PostEvent("Au_UI_Popup_Common_Medium_Open")
    self.view.buildingCommon.view.controllerSideMenuBtn.gameObject:SetActive(false)

    self:_FindFittingCacheToNaviOnSwitchMode(true)

    self.m_isInSelectMode = true

    self:_ToggleCacheBindingAction()
end



FacMixPoolCtrl._OnLeavePoolSelectMode = HL.Method() << function(self)
    for _, selectorInfo in ipairs(self.m_selectorConfig) do
        for _, node in ipairs(selectorInfo.viewPortNodeList) do
            node.gameObject:SetActiveIfNecessary(true)
        end
    end

    self.view.nopProductTips.gameObject:SetActiveIfNecessary(false)

    self.view.mainAnimation:PlayWithTween(MAIN_SELECT_MODE_OUT_ANIM_NAME, function()
        self.view.mainController:SetState(MainState.Normal)
        CS.Beyond.Gameplay.Conditions.OnMixPoolSelectFinish.Trigger()
    end)
    self:_RefreshPoolCacheSelectModeState(false, true)

    self.view.facCacheBelt:SetCacheBeltSingleState(false)
    self.view.facCachePipe:SetCachePipeSingleState(false)
    self.view.facCachePipe:RefreshPipeCellsState()

    self:_RefreshPoolCacheArrowsRunningState()

    AudioAdapter.PostEvent("Au_UI_Popup_Common_Medium_Close")
    self.view.buildingCommon.view.controllerSideMenuBtn.gameObject:SetActive(true)

    self:_FindFittingCacheToNaviOnSwitchMode(false)

    self.m_isInSelectMode = false

    self:_ToggleCacheBindingAction()
end





FacMixPoolCtrl._RefreshPoolCacheSelectModeState = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isInSelectMode, forceRefresh)
    local currSelectorInfo = self.m_selectorConfig[self.m_selectModeIndex]
    if isInSelectMode and currSelectorInfo == nil then
        return
    end

    local isFluid = currSelectorInfo.isFluid
    for index = 1, self.m_buildingInfo.cache.size do
        local itemSlot = self:_GetPoolCacheItemSlotByIndex(index)
        if itemSlot ~= nil then
            if isInSelectMode then
                local itemData = self.m_cacheItemDataList[index]
                local typeMatched = isFluid == FactoryUtils.isFactoryItemFluid(itemData.id) and not string.isEmpty(itemData.id)
                itemSlot.selectModeBg.gameObject:SetActiveIfNecessary(typeMatched)
                itemSlot.button.enabled = typeMatched
                itemSlot.canvasGroup.color = typeMatched and
                    self.view.config.NORMAL_SLOT_COLOR or
                    self.view.config.SELECT_INVALID_COLOR

                if forceRefresh then
                    itemSlot.highlightBg.gameObject:SetActiveIfNecessary(
                        not string.isEmpty(itemData.id) and
                            itemData.id == currSelectorInfo.compSelector.selectItemId
                    )
                end
            else
                itemSlot.selectModeBg.gameObject:SetActiveIfNecessary(false)
                itemSlot.highlightBg.gameObject:SetActiveIfNecessary(false)
                itemSlot.button.enabled = true
                itemSlot.canvasGroup.color = self.view.config.NORMAL_SLOT_COLOR

                if forceRefresh then
                    itemSlot.highlightBg.gameObject:SetActiveIfNecessary(false)
                end
            end
        end
    end
end




FacMixPoolCtrl._SetAndRefreshPoolSelectModeSelectorState = HL.Method(HL.String) << function(self, selectItemId)
    local currSelectorInfo = self.m_selectorConfig[self.m_selectModeIndex]
    if currSelectorInfo == nil then
        return
    end

    self.m_selectModeItemId = selectItemId
    local selectModeNode = self.view.selectModeNode

    self:_RefreshPoolCacheSlotHighlightState()

    local item = currSelectorInfo.isFluid and selectModeNode.selector.fluidItem or selectModeNode.selector.normalItem
    selectModeNode.selector.fluidItem.gameObject:SetActiveIfNecessary(currSelectorInfo.isFluid)
    selectModeNode.selector.normalItem.gameObject:SetActiveIfNecessary(not currSelectorInfo.isFluid)
    if string.isEmpty(selectItemId) then
        item.gameObject:SetActiveIfNecessary(false)
        selectModeNode.info.gameObject:SetActiveIfNecessary(false)
        selectModeNode.empty.gameObject:SetActiveIfNecessary(true)
        return
    end

    item:InitItem({ id = selectItemId, count = 1 }, false)  

    local success, itemData = Tables.itemTable:TryGetValue(selectItemId)
    if success then
        selectModeNode.nameText.text = itemData.name
        selectModeNode.descText.text = itemData.desc
    end

    item.gameObject:SetActiveIfNecessary(true)
    selectModeNode.info.gameObject:SetActiveIfNecessary(true)
    selectModeNode.empty.gameObject:SetActiveIfNecessary(false)
end



FacMixPoolCtrl._RefreshPoolCacheSlotHighlightState = HL.Method() << function(self)
    if not self.m_isInSelectMode then
        return
    end

    local selectItemId = self.m_selectModeItemId
    for index = 1, self.m_buildingInfo.cache.size do
        local slot = self:_GetPoolCacheItemSlotByIndex(index)
        local data = self.m_cacheItemDataList[index]
        slot.highlightBg.gameObject:SetActiveIfNecessary(data.id == selectItemId and not string.isEmpty(selectItemId))
    end
end




FacMixPoolCtrl.OnActionNaviToTarget = HL.Method(HL.Any) << function(self, args)
    local targetIndex = unpack(args)
    if self.m_disableNaviCache or targetIndex < 0 or targetIndex > MAX_POOL_CACHE_SLOT_COUNT then
        return
    end

    if self.m_curNaviCacheIndex == 0 and targetIndex ~= 0 then
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.selectorNode.naviGroup)
        local itemSlot = self:_GetPoolCacheItemSlotByIndex(targetIndex)
        itemSlot.controllerLight.gameObject:SetActiveIfNecessary(true)
        self.m_curNaviCacheIndex = targetIndex
        return
    end

    local oldTarget = self:_GetPoolCacheItemSlotByIndex(self.m_curNaviCacheIndex)
    oldTarget.controllerLight.gameObject:SetActiveIfNecessary(false)
    if targetIndex ~= 0 then
        local newTarget = self:_GetPoolCacheItemSlotByIndex(targetIndex)
        newTarget.controllerLight.gameObject:SetActiveIfNecessary(true)
    end

    self.m_curNaviCacheIndex = targetIndex
    self:_ToggleCacheBindingAction()
end







FacMixPoolCtrl.m_curNaviCacheIndex = HL.Field(HL.Number) << 0


FacMixPoolCtrl.m_disableNaviCache = HL.Field(HL.Boolean) << false


FacMixPoolCtrl.m_cacheShowItemTipsBindingId = HL.Field(HL.Number) << -1


FacMixPoolCtrl.m_cacheSelectItemBindingId = HL.Field(HL.Number) << -1



FacMixPoolCtrl._InitControllerChangeAction = HL.Method() << function(self)
    InputManagerInst:CreateBindingByActionId("common_navigation_up_no_hint", function()
        self:_OnNaviCacheItemList(NaviDir.Up)
    end, self.view.inputGroup.groupId)
    InputManagerInst:CreateBindingByActionId("common_navigation_down", function()
        self:_OnNaviCacheItemList(NaviDir.Down)
    end, self.view.inputGroup.groupId)
    InputManagerInst:CreateBindingByActionId("common_navigation_left_no_hint", function()
        self:_OnNaviCacheItemList(NaviDir.Left)
    end, self.view.inputGroup.groupId)
    InputManagerInst:CreateBindingByActionId("common_navigation_right", function()
        self:_OnNaviCacheItemList(NaviDir.Right)
    end, self.view.inputGroup.groupId)
    self.m_cacheShowItemTipsBindingId = InputManagerInst:CreateBindingByActionId("show_item_tips", function()
        if self.m_curNaviCacheIndex > 0 then
            local itemSlot = self:_GetPoolCacheItemSlotByIndex(self.m_curNaviCacheIndex)
            itemSlot.item:ShowTips()
        end
    end, self.view.inputGroup.groupId)
    self.m_cacheSelectItemBindingId = InputManagerInst:CreateBindingByActionId("common_select", function()
        if self.m_curNaviCacheIndex > 0 then
            self:_OnClickPoolCacheItemSlot(self.m_curNaviCacheIndex)
        end
    end, self.view.inputGroup.groupId)
    self:_ToggleCacheBindingAction()

    local initNaviTarget
    for _, selectorIndex in ipairs(FindSelectNaviPriority) do
        local viewSelector = self.m_selectorConfig[selectorIndex].viewSelector
        local compSelector = self.m_selectorConfig[selectorIndex].compSelector
        self.m_selectorConfig[selectorIndex].showTipsBindingId = InputManagerInst:CreateBindingByActionId("show_item_tips", function()
            viewSelector.item:ShowTips()
        end, viewSelector.bindingGroup.groupId)
        viewSelector.naviTarget.onIsNaviTargetChanged = function(isNaviTarget)
            if isNaviTarget then
                self:_RefreshItemHoverTipsController(compSelector.selectItemId, viewSelector.selectButton.transform, "_SELECT")
            else
                self:_RefreshItemHoverTipsController("", viewSelector.selectButton.transform, "_SELECT")
            end
        end
        if initNaviTarget == nil and not string.isEmpty(compSelector.selectItemId) then
            initNaviTarget = viewSelector.naviTarget
        end
    end
    if initNaviTarget == nil then
        initNaviTarget = self.view.selectorNode.selector3.naviTarget
    end
    InputManagerInst.controllerNaviManager:SetTarget(initNaviTarget)
end




FacMixPoolCtrl._OnNaviCacheItemList = HL.Method(HL.Number) << function(self, naviDir)
    
    if self.m_disableNaviCache then
        return
    end

    AudioAdapter.PostEvent("Au_UI_Hover_ControllerSelect")

    
    if self.m_curNaviCacheIndex == 0 then
        if naviDir == NaviDir.Left then
            InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.selectorNode.naviGroup)
            local itemSlot = self:_GetPoolCacheItemSlotByIndex(POOL_CACHE_BRIDGE_INDEX)
            itemSlot.controllerLight.gameObject:SetActiveIfNecessary(true)
            self.m_curNaviCacheIndex = POOL_CACHE_BRIDGE_INDEX
        end
        return
    end

    
    local targetIndex = NaviDirMap[self.m_curNaviCacheIndex][naviDir]
    if targetIndex < 0 then
        return
    end
    
    if self.m_isInSelectMode and targetIndex == 0 then
        return
    end

    
    local oldTarget = self:_GetPoolCacheItemSlotByIndex(self.m_curNaviCacheIndex)
    oldTarget.controllerLight.gameObject:SetActiveIfNecessary(false)
    if targetIndex == 0 then
        InputManagerInst.controllerNaviManager:SetTarget(self.view.selectorNode.selector3.naviTarget)
    else
        local newTarget = self:_GetPoolCacheItemSlotByIndex(targetIndex)
        newTarget.controllerLight.gameObject:SetActiveIfNecessary(true)
    end

    self.m_curNaviCacheIndex = targetIndex
    self:_ToggleCacheBindingAction()
end



FacMixPoolCtrl._ToggleCacheBindingAction = HL.Method() << function(self)
    local naviNotEmpty = false
    local naviAndSelectDiffItem = false
    local typeMatched = false
    if self.m_curNaviCacheIndex > 0 then
        local itemData = self.m_cacheItemDataList[self.m_curNaviCacheIndex]
        local hoverTipsItemId = ""
        if itemData ~= nil and not string.isEmpty(itemData.id) then
            hoverTipsItemId = itemData.id
            naviNotEmpty = true
            naviAndSelectDiffItem = self.m_selectModeItemId ~= itemData.id
            local currSelectorInfo = self.m_selectorConfig[self.m_selectModeIndex]
            if currSelectorInfo ~= nil then
                typeMatched = currSelectorInfo.isFluid == FactoryUtils.isFactoryItemFluid(itemData.id)
            end
        end
        local targetSlot = self:_GetPoolCacheItemSlotByIndex(self.m_curNaviCacheIndex)
        self:_RefreshItemHoverTipsController(hoverTipsItemId, targetSlot.item.transform, "_CACHE")
    end
    InputManagerInst:ToggleBinding(self.m_cacheShowItemTipsBindingId, naviNotEmpty and not self.m_isInSelectMode)
    InputManagerInst:ToggleBinding(self.m_cacheSelectItemBindingId, naviNotEmpty and naviAndSelectDiffItem and typeMatched and self.m_isInSelectMode)
    if naviNotEmpty and naviAndSelectDiffItem and typeMatched and self.m_isInSelectMode then
        local bindingText = string.isEmpty(self.m_selectModeItemId) and Language["key_hint_common_select"] or Language.LUA_MIXPOOL_ACTION_CONFIRM_SWITCH
        InputManagerInst:SetBindingText(self.m_cacheSelectItemBindingId, bindingText)
    end
end




FacMixPoolCtrl._FindFittingCacheToNaviOnSwitchMode = HL.Method(HL.Boolean) << function(self, enterSelectMode)
    if not DeviceInfo.usingController then
        return
    end

    local currSelectorInfo = self.m_selectorConfig[self.m_selectModeIndex]
    if currSelectorInfo == nil then
        return
    end

    if enterSelectMode then
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.selectorNode.naviGroup)
        local isFluid = currSelectorInfo.isFluid
        for _, index in ipairs(FindCacheNaviPriority) do
            local itemSlot = self:_GetPoolCacheItemSlotByIndex(index)
            if itemSlot ~= nil then
                local itemData = self.m_cacheItemDataList[index]
                local typeMatched = isFluid == FactoryUtils.isFactoryItemFluid(itemData.id) and not string.isEmpty(itemData.id)
                if typeMatched then
                    itemSlot.controllerLight.gameObject:SetActiveIfNecessary(true)
                    self.m_curNaviCacheIndex = index
                    return
                end
            end
        end

        self.m_disableNaviCache = true
    else
        if self.m_curNaviCacheIndex > 0 then
            local itemSlot = self:_GetPoolCacheItemSlotByIndex(self.m_curNaviCacheIndex)
            itemSlot.controllerLight.gameObject:SetActiveIfNecessary(false)
            self.m_curNaviCacheIndex = 0
        end
        self.m_disableNaviCache = false
        InputManagerInst.controllerNaviManager:SetTarget(currSelectorInfo.viewSelector.naviTarget)
    end
end




FacMixPoolCtrl._RefreshPoolSelectorButtonController = HL.Method(HL.Number) << function(self, selectorIndex)
    local selectorInfo = self.m_selectorConfig[selectorIndex]
    if selectorInfo == nil then
        return
    end

    local viewSelector, compSelector = selectorInfo.viewSelector, selectorInfo.compSelector
    local selectItemId = compSelector.selectItemId
    if string.isEmpty(selectItemId) then
        InputManagerInst:ToggleBinding(selectorInfo.showTipsBindingId, false)
        viewSelector.selectButton.customBindingViewLabelText = Language.LUA_MIXPOOL_ACTION_SELECT_PRODUCT
    else
        InputManagerInst:ToggleBinding(selectorInfo.showTipsBindingId, true)
        viewSelector.selectButton.customBindingViewLabelText = Language.LUA_MIXPOOL_ACTION_SWITCH_PRODUCT
    end
end






FacMixPoolCtrl._RefreshItemHoverTipsController = HL.Method(HL.String, HL.Userdata, HL.String) << function(self, itemId, targetRect, pos)
    if self.m_lastHoverTipsItemTag == (itemId .. pos) or self.m_stopHoverTips then
        return
    end
    self.m_lastHoverTipsItemTag = (itemId .. pos)
    if string.isEmpty(itemId) then
        Notify(MessageConst.HIDE_COMMON_HOVER_TIP)
    else
        Notify(MessageConst.SHOW_COMMON_HOVER_TIP, {
            itemId = itemId,
            delay = 0,
            targetRect = targetRect,
            posType = UIConst.UI_TIPS_POS_TYPE.RightDown,
        })
    end
end




HL.Commit(FacMixPoolCtrl)
