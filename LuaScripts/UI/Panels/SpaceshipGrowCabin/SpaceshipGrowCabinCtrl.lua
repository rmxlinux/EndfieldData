local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipGrowCabin
local PHASE_ID = PhaseId.SpaceshipGrowCabin

local PanelType = {
    Overview = 1, 
    Sow = 2, 
    Breed = 3, 
}

local EnumState = SpaceshipUtils.RoomStateEnum

local AUTO_SELECT_NEXT_SOW_BOX_SWITCH_KEY = "auto_select_next_sow_box_switch"
local CLIENT_DATA_MANAGER_CATEGORY = "spaceship"
































































SpaceshipGrowCabinCtrl = HL.Class('SpaceshipGrowCabinCtrl', uiCtrl.UICtrl)


SpaceshipGrowCabinCtrl.m_roomId = HL.Field(HL.String) << ""


SpaceshipGrowCabinCtrl.m_panelType = HL.Field(HL.Number) << PanelType.Overview


SpaceshipGrowCabinCtrl.m_panelStack = HL.Field(HL.Forward("Stack"))


SpaceshipGrowCabinCtrl.m_growCabinTick = HL.Field(HL.Thread)


SpaceshipGrowCabinCtrl.m_id2GrowCabinBoxCell = HL.Field(HL.Table)


SpaceshipGrowCabinCtrl.m_id2GrowCabinBoxCellLine = HL.Field(HL.Table)


SpaceshipGrowCabinCtrl.m_overviewPanelTick = HL.Field(HL.Thread)


SpaceshipGrowCabinCtrl.m_selectBoxId = HL.Field(HL.Number) << -1


SpaceshipGrowCabinCtrl.m_curSelectSowFormulaId = HL.Field(HL.String) << ""


SpaceshipGrowCabinCtrl.m_sowFormulaList = HL.Field(HL.Table)


SpaceshipGrowCabinCtrl.m_autoSelectNextSowBox = HL.Field(HL.Boolean) << false


SpaceshipGrowCabinCtrl.m_trainAudioPlayed = HL.Field(HL.Boolean) << false


SpaceshipGrowCabinCtrl.m_curSelectBreedFormulaId = HL.Field(HL.String) << ""


SpaceshipGrowCabinCtrl.m_breedFormulaList = HL.Field(HL.Table)


SpaceshipGrowCabinCtrl.m_selectBreedMaterialNumber = HL.Field(HL.Number) << 0


SpaceshipGrowCabinCtrl.m_animationWrapper = HL.Field(HL.Userdata)






SpaceshipGrowCabinCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION] = "OnSpaceshipRoomStationSync",

    [MessageConst.ON_SPACESHIP_GROW_CABIN_MODIFY] = 'OnSpaceshipGrowCabinModify',
    [MessageConst.ON_SPACESHIP_GROW_CABIN_SOW] = 'OnSpaceshipGrowCabinSow',
    [MessageConst.ON_SPACESHIP_GROW_CABIN_CANCEL] = 'OnSpaceshipGrowCabinCancel',
    [MessageConst.ON_SPACESHIP_GROW_CABIN_HARVEST] = "OnSpaceshipGrowCabinHarvest",
    [MessageConst.ON_SPACESHIP_GROW_CABIN_BREED] = "OnSpaceshipGrowCabinBreed",
    [MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY] = "_RefreshOverviewPanel",
}


SpaceshipGrowCabinCtrl.s_cachedBreedSortOptCsIndex = HL.StaticField(HL.Number) << 0


SpaceshipGrowCabinCtrl.s_cachedBreedSortIncremental = HL.StaticField(HL.Boolean) << false


SpaceshipGrowCabinCtrl.s_cachedSowSortOptCsIndex = HL.StaticField(HL.Number) << 0


SpaceshipGrowCabinCtrl.s_cachedSowSortIncremental = HL.StaticField(HL.Boolean) << false



SpaceshipGrowCabinCtrl.m_moveCam = HL.Field(HL.Boolean) << false


SpaceshipGrowCabinCtrl.m_isInDetailNaviState = HL.Field(HL.Boolean) << false


SpaceshipGrowCabinCtrl.m_tempCancelBindingId = HL.Field(HL.Number) << -1






SpaceshipGrowCabinCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_roomId = arg.roomId
    self.m_moveCam = arg.moveCam == true

    local _, value = ClientDataManagerInst:GetBool(AUTO_SELECT_NEXT_SOW_BOX_SWITCH_KEY, false, true,
                                                   CLIENT_DATA_MANAGER_CATEGORY)
    self.m_autoSelectNextSowBox = value

    self.m_panelStack = require_ex("Common/Utils/DataStructure/Stack")()
    self.m_animationWrapper = self.animationWrapper
    self:_PushPanel(PanelType.Overview)

    
    local plantingWarehouse = self.view.plantingWarehouse
    plantingWarehouse.toBreedBtn.onClick:AddListener(function()
        self:_OnGoToBreedBtnClick()
    end)

    plantingWarehouse.allContinueSowBtn.onClick:AddListener(function()
        self:_OnAllContinueSowBtnClick()
    end)

    plantingWarehouse.collectAllBtn.onClick:AddListener(function()
        self:_OnCollectAllBtnClick()
    end)

    
    local cultivationObject = self.view.cultivationObject
    cultivationObject.toBreedBtn.onClick:AddListener(function()
        self:_OnGoToBreedBtnClick(true)
    end)

    cultivationObject.formulaSelectConfirmBtn.onClick:AddListener(function()
        self:_OnSowFormulaConfirmClick()
    end)

    cultivationObject.formulaSelectCancelBtn.onClick:AddListener(function()
        self:_PopPanel()
    end)

    cultivationObject.continuousBtn.onClick:AddListener(function()
        self:_ToggleAutoSow(not self.m_autoSelectNextSowBox)
    end)

    if DeviceInfo.usingController then
        cultivationObject.pipingBgNode.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)  
            end
        end)
    end

    
    local extractionWarehouse = self.view.extractionWarehouse
    extractionWarehouse.formulaSelectConfirmBtn.onClick:AddListener(function()
        self:_OnBreedFormulaConfirmClick()
    end)

    extractionWarehouse.formulaSelectCancelBtn.onClick:AddListener(function()
        self:_PopPanel()
    end)

    self:_InitBG()
    self:_InitRoomInfo()
    self:_InitOverviewPanel()
    self:_RefreshBgBottomNode()
    self:_RefreshOverviewPanelBottomNode()

    
    self.m_overviewPanelTick = self:_StartCoroutine(function()
        while (true) do
            coroutine.wait(UIConst.COMMON_UI_TIME_UPDATE_INTERVAL)
            self:_TickGrowCabin()
        end
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end



SpaceshipGrowCabinCtrl.OnHide = HL.Override() << function(self)
    self:_DeleteDetailNaviBinding()
end



SpaceshipGrowCabinCtrl.OnClose = HL.Override() << function(self)
    self.m_trainAudioPlayed = false
    ClientDataManagerInst:SetBool(AUTO_SELECT_NEXT_SOW_BOX_SWITCH_KEY, self.m_autoSelectNextSowBox, false,
                                  CLIENT_DATA_MANAGER_CATEGORY, true)
    if self.m_moveCam then
        local clearScreenKey = GameInstance.player.spaceship:UndoMoveCamToSpaceshipRoom(self.m_roomId)
        if clearScreenKey and clearScreenKey ~= -1 then
            UIManager:RecoverScreen(clearScreenKey)
        end
    end
end



SpaceshipGrowCabinCtrl._OnCloseBtnClick = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
    if self.m_overviewPanelTick then
        self.m_overviewPanelTick = self:_ClearCoroutine(self.m_overviewPanelTick)
    end
end



SpaceshipGrowCabinCtrl._InitBG = HL.Method() << function(self)
    self.view.spaceshipRoomCommonBg:InitSpaceshipRoomCommonBg(self.m_roomId, function()
        self:_PopPanel()
    end, function()
        self:_OnCloseBtnClick()
    end)
end



SpaceshipGrowCabinCtrl._InitRoomInfo = HL.Method() << function(self)
    self.view.roomCommonInfo:InitSpaceshipRoomCommonInfo(self.m_roomId, self.m_moveCam)
end



SpaceshipGrowCabinCtrl._InitOverviewPanel = HL.Method() << function(self)
    self.m_id2GrowCabinBoxCell = {}
    self.m_id2GrowCabinBoxCellLine = {}

    local plantingWarehouse = self.view.plantingWarehouse
    for boxId = 1, Tables.spaceshipConst.growCabinBoxCount do
        local lineCellId = string.format("imageMask%02d", boxId)
        local lineCell = plantingWarehouse.boxInfoNode[lineCellId]
        self.m_id2GrowCabinBoxCellLine[boxId] = lineCell

        local nodeId = string.format("boxInfo%02d", boxId)
        local boxNode = plantingWarehouse.boxInfoNode[nodeId]
        boxNode:InitSSGrowCabinBoxInfo(self, self.m_roomId, boxId, lineCell, function(boxId, needClear)
            self:_PushPanel(PanelType.Sow, { boxId = boxId })
            if needClear then
                GameInstance.player.spaceship:GrowCabinClearPreviewRecipe(self.m_roomId, boxId)
            end
        end)
        self.m_id2GrowCabinBoxCell[boxId] = boxNode
    end
    self:BindInputPlayerAction("ss_open_detail_navi", function()
        if self.m_isInDetailNaviState then
            return
        end
        self.m_isInDetailNaviState = true
        self.view.plantingWarehouse.growBoxKeyHint.gameObject:SetActiveIfNecessary(false)
        local boxes = GameInstance.player.spaceship:GetGrowCabinBoxes(self.m_roomId)
        local leftTopCell = 4
        local topCell = 2
        local succ, box = boxes:TryGetValue(leftTopCell)
        local cellIndex = succ and leftTopCell or topCell
        InputManagerInst.controllerNaviManager:SetTarget(self.m_id2GrowCabinBoxCell[cellIndex].view.inputBindingGroupNaviDecorator)
        Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
            panelId = PANEL_ID,
            isGroup = true,
            id = self.view.plantingWarehouse.boxInfoNode.inputBindingGroupMonoTarget.groupId,
            hintPlaceholder = self.view.controllerHintPlaceholder,
            rectTransform = self.view.plantingWarehouse.boxInfoNode.naviNode,
            noHighlight = false,
            useNormalFrame = true,
        })

        self.m_tempCancelBindingId = self:BindInputPlayerAction("common_cancel", function()
            self:_DeleteDetailNaviBinding()
        end, self.view.plantingWarehouse.boxInfoNode.inputBindingGroupMonoTarget.groupId)
        InputManagerInst:SetBindingText(self.m_tempCancelBindingId, Language["key_hint_common_back"])
    end,self.view.plantingWarehouse.boxInfoNode.inputBindingGroupMonoTarget.groupId)
end



SpaceshipGrowCabinCtrl._DeleteDetailNaviBinding = HL.Method() << function(self)
    InputManagerInst:DeleteBinding(self.m_tempCancelBindingId)
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.plantingWarehouse.boxInfoNode.inputBindingGroupMonoTarget.groupId)
    InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.plantingWarehouse.boxInfoNodeSelectableNaviGroup)
    self.m_isInDetailNaviState = false
    self.view.plantingWarehouse.growBoxKeyHint.gameObject:SetActiveIfNecessary(true)
end




SpaceshipGrowCabinCtrl._TickGrowCabin = HL.Method() << function(self)
    if self.m_panelType == PanelType.Breed then
        return
    end

    if not GameInstance.player.spaceship:IsGrowCabinStateProducing(self.m_roomId) then
        return
    end

    if self.m_panelType == PanelType.Overview then
        for _, boxCell in pairs(self.m_id2GrowCabinBoxCell) do
            boxCell:RefreshTimeSchedule()
        end
    end
end



SpaceshipGrowCabinCtrl._RefreshOverviewPanel = HL.Method() << function(self)
    for id, boxCell in pairs(self.m_id2GrowCabinBoxCell) do
        local lineCell = self.m_id2GrowCabinBoxCellLine[id]
        boxCell:Refresh(lineCell)
    end

    self:_RefreshOverviewPanelBottomNode()
end



SpaceshipGrowCabinCtrl._RefreshOverviewPanelBottomNode = HL.Method() << function(self)
    
    local spaceship = GameInstance.player.spaceship
    local hasOutputs = spaceship:HasGrowCabinProduct(self.m_roomId)

    
    local boxes = spaceship:GetGrowCabinBoxes(self.m_roomId)
    local sustainable = false
    for boxId, box in pairs(boxes) do
        if box.sustainable then
            sustainable = true
            break
        end
    end

    
    local stateContent
    if spaceship:IsGrowCabinStateProducing(self.m_roomId) then
        stateContent = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_IS_PRODUCING_DESC
    elseif spaceship:IsGrowCabinStateShutDown(self.m_roomId) then
        stateContent = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_IS_SHUT_DOWN_DESC
    else
        stateContent = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_IS_IDLE_DESC
    end

    local node = self.view.plantingWarehouse
    node.collectNode.gameObject:SetActiveIfNecessary(hasOutputs)

    if hasOutputs then
        AudioManager.PostEvent("Au_UI_Event_Manufacturing_Finish")
    end

    local itemMap, needSowBoxIds = self:_GetCanContinueSowData()
    local canAllContinueSow = #needSowBoxIds > 0 and sustainable

    node.allContinueSowBtn.gameObject:SetActiveIfNecessary(not hasOutputs and canAllContinueSow)
    node.formulaState.gameObject:SetActiveIfNecessary(not hasOutputs and not canAllContinueSow)
    if not hasOutputs and not canAllContinueSow then
        node.stateTxt.text = stateContent
    end
end





SpaceshipGrowCabinCtrl._PushPanel = HL.Method(HL.Number, HL.Opt(HL.Table)) << function(self, panelType, args)
    if self.m_panelStack:Contains(panelType) then
        logger.error("SpaceshipGrowCabinCtrl try to push an exit panel", panelType, self.m_panelStack:IndexOf(panelType))
        return
    end
    self.view.spaceshipRoomCommonBg:SetFriendAssistNode(panelType == PanelType.Overview)

    if panelType == PanelType.Overview then
        self.view.plantingWarehouse.gameObject:SetActiveIfNecessary(true)
        self.view.cultivationObject.gameObject:SetActiveIfNecessary(false)
        self.view.extractionWarehouse.gameObject:SetActiveIfNecessary(false)
    elseif panelType == PanelType.Sow then
        self.m_selectBoxId = args.boxId

        self.view.spaceshipRoomCommonBg:ToggleReturnBtnOn(true)
        self.view.spaceshipRoomCommonBg:SetSubTitle(Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_SUBTITLE_DESC)

        self.m_animationWrapper:Play("spaceshipgrowcabin_change")

        self:_RefreshSowFormulaList()
        self:_RefreshSowPanel(true)
    elseif panelType == PanelType.Breed then
        local peekPanel = self.m_panelStack:Peek()
        if peekPanel == PanelType.Overview then
            self.m_animationWrapper:Play("spaceshipgrowcabin_extract")
        elseif peekPanel == PanelType.Sow then
            self.m_animationWrapper:Play("spaceshipgrowcabin_exchange")
        end

        self.view.spaceshipRoomCommonBg:ToggleReturnBtnOn(true)
        self.view.spaceshipRoomCommonBg:SetSubTitle(Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BREED_SUBTITLE_DESC)

        self:_RefreshBreedFormulaList(args)
        self:_RefreshBreedPanel()
    end

    self.m_panelStack:Push(panelType)
end



SpaceshipGrowCabinCtrl._PopPanel = HL.Method() << function(self)
    if self.m_panelStack:Peek() == PanelType.Overview then
        logger.error("SpaceshipGrowCabinCtrl try to pop Overview panel")
        self:_OnCloseBtnClick()
        return
    end

    local popPanel = self.m_panelStack:Pop()
    local peekPanel = self.m_panelStack:Peek()

    if peekPanel == PanelType.Overview then
        if popPanel == PanelType.Sow then
            self.m_animationWrapper:Play("spaceshipgrowcabin_return")
        elseif popPanel == PanelType.Breed then
            self.m_animationWrapper:Play("spaceshipgrowcabin_extractreturn")
        end
        self.view.spaceshipRoomCommonBg:SetFriendAssistNode(true)
        self.view.spaceshipRoomCommonBg:ToggleReturnBtnOn(false)
        self.view.spaceshipRoomCommonBg:SetSubTitle()

        self:_InitRoomInfo()
        self:_RefreshOverviewPanel()
    elseif peekPanel == PanelType.Sow then
        self.m_animationWrapper:Play("spaceshipgrowcabin_exchangereturn")

        self.view.spaceshipRoomCommonBg:SetSubTitle(Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_SUBTITLE_DESC)

        self:_RefreshSowFormulaList()
        self:_RefreshSowPanel()
    end
end



SpaceshipGrowCabinCtrl._RefreshSowFormulaList = HL.Method() << function(self)
    local formulaData = {}
    formulaData.formulas = self:_ProcessSowFormulaTabListData()

    formulaData.sortOptions = {
        {
            name = Language.LUA_FAC_CRAFT_SORT_1,
            keys = { "isUnlockSortId", "seedCount", "rarity", "sortId" }
        },
        {
            name = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_SORT_2,
            keys = { "outcomeCount", "rarity", "sortId" }
        },
        {
            name = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_SORT_3,
            keys = { "seedCount", "rarity", "sortId" }
        },
        {
            name = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_RARITY_SORT,
            keys = { "rarity", "sortId" }
        },
    }

    formulaData.onCellClick = function(info)
        self.m_curSelectSowFormulaId = info.formulaId
        self:_RefreshSowPanel()
    end

    formulaData.selectedSortOptionCsIndex = SpaceshipGrowCabinCtrl.s_cachedSowSortOptCsIndex
    formulaData.isIncremental = SpaceshipGrowCabinCtrl.s_cachedSowSortIncremental

    formulaData.onSortChanged = function(csIndex, isIncremental)
        SpaceshipGrowCabinCtrl.s_cachedSowSortOptCsIndex = csIndex
        SpaceshipGrowCabinCtrl.s_cachedSowSortIncremental = isIncremental
    end

    self.view.formulaList:InitSpaceshipRoomFormulaList(formulaData)
end



SpaceshipGrowCabinCtrl._ProcessSowFormulaTabListData = HL.Method().Return(HL.Table) << function(self)
    local spaceship = GameInstance.player.spaceship

    local formulaTabListData = {}
    local formulaShowType2Data = {}
    local allFormulaList = {}

    for _, formulaData in pairs(Tables.spaceshipGrowCabinFormulaTable) do
        if not formulaShowType2Data[formulaData.type] then
            formulaShowType2Data[formulaData.type] = {}
        end

        local outcomeItemData = Tables.itemTable[formulaData.outcomeItemId]
        local isUnlock = spaceship:IsGrowCabinSowFormulaUnlock(self.m_roomId, formulaData.id)
        local formulaDataUnit = {
            formulaId = formulaData.id,
            roomAttrType = formulaData.roomAttrType,
            itemId = outcomeItemData.id,
            roomId = self.m_roomId,
            isUnlock = isUnlock,

            outcomeCount = Utils.getItemCount(formulaData.outcomeItemId),
            seedCount = Utils.getItemCount(formulaData.seedItemId),
            rarity = formulaData.rarity,
            sortId = formulaData.sortId,
            isUnlockSortId = isUnlock and 1 or 0,
        }
        formulaDataUnit.isSow = true

        table.insert(allFormulaList, formulaDataUnit)
        table.insert(formulaShowType2Data[formulaData.type], formulaDataUnit)
    end

    
    for showType, formulaDataList in pairs(formulaShowType2Data) do
        local showingTypeCfgData = Tables.spaceshipGrowCabinFormulaShowingTypeTable[showType]
        table.insert(formulaTabListData, {
            tabName = showingTypeCfgData.name,
            iconName = showingTypeCfgData.icon,
            sortId = showType:GetHashCode(),
            list = formulaDataList,
        })
    end
    
    table.insert(formulaTabListData, {
        tabName = Language.LUA_SPACESHIP_ROOM_FORMULA_LIST_TAB_ALL_DESC,
        iconName = "icon_type_all",
        sortId = 0,
        list = allFormulaList,
    })
    
    table.sort(formulaTabListData, Utils.genSortFunction({ "sortId" }, true))

    return formulaTabListData
end




SpaceshipGrowCabinCtrl._RefreshSowPanel = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local node = self.view.cultivationObject
    local spaceship = GameInstance.player.spaceship
    local succ , formulaData = Tables.spaceshipGrowCabinFormulaTable:TryGetValue(self.m_curSelectSowFormulaId)
    if not succ then
        logger.error("grow cabin unknown m_curSelectSowFormulaId:" .. self.m_curSelectSowFormulaId)
        return
    end
    local seedItemData = Tables.itemTable[formulaData.seedItemId]
    local outcomeItemData = Tables.itemTable[formulaData.outcomeItemId]

    local selectSowFormulaUnlock = spaceship:IsGrowCabinSowFormulaUnlock(self.m_roomId, formulaData.id)
    local ownSeedCount = Utils.getItemCount(formulaData.seedItemId)
    local seedEnough = ownSeedCount >= formulaData.seedItemCount

    
    node.seedItem:InitItem({ id = seedItemData.id, count = formulaData.seedItemCount }, true)
    if DeviceInfo.usingController then
        node.seedItem:SetExtraInfo({
            isSideTips = true,
        })
    end
    node.seedNameTxt.text = seedItemData.name
    node.seedStorage:InitStorageNode(Utils.getItemCount(seedItemData.id), formulaData.seedItemCount, true)
    node.bgFrame.gameObject:SetActiveIfNecessary(not seedEnough)

    
    node.outcomeItem:InitItem({ id = outcomeItemData.id, count = formulaData.outcomeItemCount }, true)
    if DeviceInfo.usingController then
        node.outcomeItem:SetExtraInfo({
            isSideTips = true,
        })
    end
    node.outcomeNameTxt.text = outcomeItemData.name
    node.outcomeStorage:InitStorageNode(Utils.getItemCount(outcomeItemData.id), 0, true)

    
    
    local produceRate = spaceship:GetRoomProduceRate(self.m_roomId, formulaData.roomAttrType)
    node.timeTxt.text = UIUtils.getLeftTimeToSecond(formulaData.totalProgress / produceRate)

    
    if isInit then
        
        self:_RefreshSowPanelWareHouse()
    end

    
    node.continuousNode.gameObject:SetActiveIfNecessary(selectSowFormulaUnlock and seedEnough)
    self:_ToggleAutoSow(self.m_autoSelectNextSowBox)

    
    node.formulaState.gameObject:SetActiveIfNecessary(not selectSowFormulaUnlock)
    node.changeFormulaNode.gameObject:SetActiveIfNecessary(selectSowFormulaUnlock and seedEnough)
    node.toBreedBtn.gameObject:SetActiveIfNecessary(selectSowFormulaUnlock and not seedEnough)
    if not selectSowFormulaUnlock then
        node.stateTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BOX_UNLOCK_CONDITION_FORMAT,
                                           formulaData.level)
    end
end



SpaceshipGrowCabinCtrl._RefreshSowPanelTimeInfo = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local boxes = spaceship:GetGrowCabinBoxes(self.m_roomId)
    local succ, box = boxes:TryGetValue(self.m_selectBoxId)

    if not succ or string.isEmpty(box.scdMsg.RecipeId) or box.scdMsg.IsReady then
        self.view.cultivationObject.timeTxt.text = UIUtils.getLeftTimeToSecond(0)
        return
    end

    local node = self.view.cultivationObject
    local diffTime = DateTimeUtils.GetCurrentTimestampBySeconds() - box.lastSyncTime
    local formula = Tables.spaceshipGrowCabinFormulaTable[box.scdMsg.RecipeId]
    local produceRate = spaceship:GetRoomProduceRate(self.m_roomId, formula.roomAttrType)
    local totalProgress = formula.totalProgress
    local curProgress = box.progress + produceRate * diffTime

    node.timeTxt.text = UIUtils.getLeftTimeToSecond((totalProgress - curProgress) / produceRate)
end



SpaceshipGrowCabinCtrl._RefreshSowPanelWareHouse = HL.Method() << function(self)
    local node = self.view.cultivationObject
    local spaceship = GameInstance.player.spaceship
    local boxes = spaceship:GetGrowCabinBoxes(self.m_roomId)
    local warehouse = node.warehouse
    for boxId = 1, Tables.spaceshipConst.growCabinBoxCount do
        local nodeId = string.format("unit%02d", boxId)
        local boxNode = warehouse[nodeId]

        local succ, box = boxes:TryGetValue(boxId)
        local selected = self.m_selectBoxId == boxId
        local hasFormula = succ and box.hasFormula

        boxNode.selected.gameObject:SetActiveIfNecessary(selected)
        boxNode.locked.gameObject:SetActiveIfNecessary(not succ)
        boxNode.empty.gameObject:SetActiveIfNecessary(succ and not hasFormula)
        boxNode.have.gameObject:SetActiveIfNecessary(succ and hasFormula)
    end
end




SpaceshipGrowCabinCtrl._RefreshBreedFormulaList = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    local formulaData = {}
    formulaData.formulas = self:_ProcessBreedFormulaTabListData()

    formulaData.sortOptions = {
        {
            name = Language.LUA_FAC_CRAFT_SORT_1,
            keys = { "isUnlockSortId", "rarity", "sortId" }
        },
        {
            name = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BREED_SORT_2,
            keys = { "materialCount", "rarity", "sortId" }
        },
        {
            name = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_RARITY_SORT,
            keys = { "rarity", "sortId" }
        },
    }

    formulaData.onCellClick = function(info)
        self.m_curSelectBreedFormulaId = info.formulaId
        self:_RefreshBreedPanel()
    end

    formulaData.selectedSortOptionCsIndex = SpaceshipGrowCabinCtrl.s_cachedBreedSortOptCsIndex
    formulaData.isIncremental = SpaceshipGrowCabinCtrl.s_cachedBreedSortIncremental

    formulaData.onSortChanged = function(csIndex, isIncremental)
        SpaceshipGrowCabinCtrl.s_cachedBreedSortOptCsIndex = csIndex
        SpaceshipGrowCabinCtrl.s_cachedBreedSortIncremental = isIncremental
    end

    formulaData.defaultSelectFormulaId = args and args.jumpToSeedFormulaId

    self.view.formulaList:InitSpaceshipRoomFormulaList(formulaData)
end



SpaceshipGrowCabinCtrl._ProcessBreedFormulaTabListData = HL.Method().Return(HL.Table) << function(self)
    local spaceship = GameInstance.player.spaceship

    local formulaTabListData = {}
    local formulaShowType2Data = {}
    local allFormulaList = {}

    for _, formulaData in pairs(Tables.spaceshipGrowCabinSeedFormulaTable) do
        if not formulaShowType2Data[formulaData.type] then
            formulaShowType2Data[formulaData.type] = {}
        end

        local materialItemData = Tables.itemTable[formulaData.materialItemId]
        local isUnlock = spaceship:IsGrowCabinBreedFormulaUnlock(self.m_roomId, formulaData.id)
        local formulaDataUnit = {
            formulaId = formulaData.id,
            itemId = materialItemData.id,
            roomId = self.m_roomId,
            isUnlock = isUnlock,

            materialCount = Utils.getItemCount(formulaData.materialItemId),
            rarity = formulaData.rarity,
            sortId = formulaData.sortId,
            isUnlockSortId = isUnlock and 1 or 0,
        }

        formulaDataUnit.isBreed = true

        table.insert(allFormulaList, formulaDataUnit)
        table.insert(formulaShowType2Data[formulaData.type], formulaDataUnit)
    end

    
    for showType, formulaDataList in pairs(formulaShowType2Data) do
        local showingTypeCfgData = Tables.spaceshipGrowCabinFormulaShowingTypeTable[showType]
        table.insert(formulaTabListData, {
            tabName = showingTypeCfgData.name,
            iconName = showingTypeCfgData.icon,
            sortId = showType:GetHashCode(),
            list = formulaDataList,
        })
    end
    
    table.insert(formulaTabListData, {
        tabName = Language.LUA_SPACESHIP_ROOM_FORMULA_LIST_TAB_ALL_DESC,
        iconName = "icon_type_all",
        sortId = 0,
        list = allFormulaList,
    })
    
    table.sort(formulaTabListData, Utils.genSortFunction({ "sortId" }, true))

    return formulaTabListData
end



SpaceshipGrowCabinCtrl._RefreshBreedPanel = HL.Method() << function(self)
    local node = self.view.extractionWarehouse
    local spaceship = GameInstance.player.spaceship
    local succ , formulaData = Tables.SpaceshipGrowCabinSeedFormulaTable:TryGetValue(self.m_curSelectBreedFormulaId)
    if not succ then
        logger.error("grow cabin unknown breedFormulaId:" .. self.m_curSelectBreedFormulaId)
        return
    end
    local materialItemData = Tables.itemTable[formulaData.materialItemId]
    local outcomeItemData = Tables.itemTable[formulaData.outcomeseedItemId]

    
    local seedOwnCount = Utils.getItemCount(materialItemData.id)
    local seedNeedCount = formulaData.materialItemCount
    node.materialItem:InitItem({ id = materialItemData.id, count = seedNeedCount }, true)
    if DeviceInfo.usingController then
        node.materialItem:SetExtraInfo({
            isSideTips = true,
        })
    end
    node.materialNameTxt.text = materialItemData.name
    node.materialStorage:InitStorageNode(seedOwnCount, seedNeedCount, true)
    node.notEnoughDeco.gameObject:SetActiveIfNecessary(seedOwnCount < seedNeedCount)

    
    node.outcomeItem:InitItem({ id = outcomeItemData.id, count = formulaData.outcomeseedItemCount }, true)
    if DeviceInfo.usingController then
        node.outcomeItem:SetExtraInfo({
            isSideTips = true,
        })
    end
    node.outcomeNameTxt.text = outcomeItemData.name
    node.outcomeStorage:InitStorageNode(Utils.getItemCount(outcomeItemData.id), 0, true)

    local selectBreedFormulaUnlock = spaceship:IsGrowCabinBreedFormulaUnlock(self.m_roomId, formulaData.id)
    local ownMaterialCount = Utils.getItemCount(formulaData.materialItemId)
    local materialEnough = ownMaterialCount >= formulaData.materialItemCount
    
    local minNumber = selectBreedFormulaUnlock and materialEnough and 1 or 0
    local maxNumber = selectBreedFormulaUnlock and materialEnough and ownMaterialCount or 0
    local curNumber = selectBreedFormulaUnlock and materialEnough and 1 or 0
    node.numberSelector:InitNumberSelector(curNumber, minNumber, maxNumber, function(number, isChangeByBtn)
        self.m_selectBreedMaterialNumber = number
        if isChangeByBtn then
            node.materialItem:UpdateCount(self.m_selectBreedMaterialNumber * seedNeedCount)
            node.outcomeItem:UpdateCount(self.m_selectBreedMaterialNumber * formulaData.outcomeseedItemCount)
        end
    end)

    
    node.changeFormulaNode.gameObject:SetActiveIfNecessary(selectBreedFormulaUnlock and materialEnough)
    node.formulaState.gameObject:SetActiveIfNecessary(not selectBreedFormulaUnlock or not materialEnough)

    if not selectBreedFormulaUnlock then
        node.stateTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BREED_FORMULA_UNLOCK_CONDITION_FORMAT,
                                           formulaData.level)
    elseif not materialEnough then
        node.stateTxt.text = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BREED_LACK_MATERIAL_DESC
    end

    if DeviceInfo.usingController then
        node.formulaItems.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)  
            end
        end)
    end
end



SpaceshipGrowCabinCtrl._RefreshBgBottomNode = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local isProducing = spaceship:IsGrowCabinStateProducing(self.m_roomId)
    local isShutDown = spaceship:IsGrowCabinStateShutDown(self.m_roomId)

    if isProducing then
        self.view.spaceshipRoomCommonBg:SetState(EnumState.Producing)
    elseif isShutDown then
        self.view.spaceshipRoomCommonBg:SetState(EnumState.ShutDown)
    else
        self.view.spaceshipRoomCommonBg:SetState(EnumState.Idle)
    end
end




SpaceshipGrowCabinCtrl._ToggleAutoSow = HL.Method(HL.Boolean) << function(self, toggleOn)
    self.m_autoSelectNextSowBox = toggleOn

    local node = self.view.cultivationObject
    node.pitchOn.gameObject:SetActiveIfNecessary(toggleOn)
end



SpaceshipGrowCabinCtrl._OnSowFormulaConfirmClick = HL.Method() << function(self)
    local boxes = GameInstance.player.spaceship:GetGrowCabinBoxes(self.m_roomId)
    local succ, box = boxes:TryGetValue(self.m_selectBoxId)
    if succ and not box.hasFormula then
        GameInstance.player.spaceship:GrowCabinSow(self.m_roomId, self.m_selectBoxId, self.m_curSelectSowFormulaId)
    end
end



SpaceshipGrowCabinCtrl._OnBreedFormulaConfirmClick = HL.Method() << function(self)
    GameInstance.player.spaceship:GrowCabinBreed(self.m_roomId, self.m_curSelectBreedFormulaId, self.m_selectBreedMaterialNumber)
end




SpaceshipGrowCabinCtrl._OnGoToBreedBtnClick = HL.Method(HL.Opt(HL.Boolean)) << function(self, jump)
    local args
    if jump then
        local sowFormulaData = Tables.spaceshipGrowCabinFormulaTable[self.m_curSelectSowFormulaId]
        args = {}
        args.jumpToSeedFormulaId = sowFormulaData.seedFormulaId
    end

    self:_PushPanel(PanelType.Breed, args)
end




SpaceshipGrowCabinCtrl.JumpToBreed = HL.Method(HL.String) << function(self, sowFormulaId)
    local args
    local sowFormulaData = Tables.spaceshipGrowCabinFormulaTable[sowFormulaId]
    args = {}
    args.jumpToSeedFormulaId = sowFormulaData.seedFormulaId
    self:_DeleteDetailNaviBinding()
    self:_PushPanel(PanelType.Breed, args)
end



SpaceshipGrowCabinCtrl._OnAllContinueSowBtnClick = HL.Method() << function(self)
    local itemMap, needSowBoxIds = self:_GetCanContinueSowData()

    local items = {}
    for itemId, item in pairs(itemMap) do
        table.insert(items, {
            id = itemId,
            needCount = item.count,
            count = item.ownCount,
        })
    end

    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_ALL_PREVIEW_RECIPE_CONFIRM_DESC,
        subContent = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_ALL_PREVIEW_RECIPE_CONFIRM_SUB_DESC,
        items = items,
        onConfirm = function()
            if #needSowBoxIds > 0 then
                GameInstance.player.spaceship:GrowCabinSowAllPreviewRecipe(self.m_roomId, needSowBoxIds)
            end
        end,
    })
end



SpaceshipGrowCabinCtrl._GetCanContinueSowData = HL.Method().Return(HL.Table, HL.Table) << function(self)
    local spaceship = GameInstance.player.spaceship
    local ownBoxes = spaceship:GetGrowCabinBoxes(self.m_roomId)

    local itemMap = {}
    local needSowBoxIds = {}
    local cachedItemCount = {}
    local boxCount = ownBoxes.Count
    
    for boxId = 1, boxCount do
        local succ, box = ownBoxes:TryGetValue(boxId)
        if succ and box.sustainable then
            local formulaData = Tables.spaceshipGrowCabinFormulaTable[box.scdMsg.PreviewRecipeId]
            local seedId = formulaData.seedItemId
            
            if itemMap[seedId] then
                local item = itemMap[seedId]
                itemMap[seedId].count = item.count + formulaData.seedItemCount
            else
                itemMap[seedId] = {}
                itemMap[seedId].count = formulaData.seedItemCount
                itemMap[seedId].ownCount = Utils.getItemCount(seedId)
            end

            local curItemCount = cachedItemCount[seedId]
            if curItemCount == nil then
                curItemCount = Utils.getItemCount(seedId)
                cachedItemCount[seedId] = curItemCount
            end

            if curItemCount >= formulaData.seedItemCount then
                table.insert(needSowBoxIds, boxId)
                curItemCount = curItemCount - formulaData.seedItemCount
                cachedItemCount[seedId] = curItemCount
            end
        end
    end

    return itemMap, needSowBoxIds
end



SpaceshipGrowCabinCtrl._OnCollectAllBtnClick = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    if spaceship:HasGrowCabinProduct(self.m_roomId) then
        spaceship:GrowCabinHarvestAll(self.m_roomId)
    end
end






SpaceshipGrowCabinCtrl._ShowOutcomePopup = HL.Method(HL.String, HL.Any, HL.Boolean)
    << function(self, title, csItems, showHelp)
    local itemMap = {}
    for i = 0, csItems.Count - 1 do
        local item = csItems[i]
        
        if itemMap[item.id or item.Id] then
            local accCount = itemMap[item.id or item.Id]
            itemMap[item.id or item.Id] = accCount + (item.Count or 0) + (item.count or 0)
        else
            itemMap[item.id or item.Id] = (item.Count or 0) + (item.count or 0)
        end
    end

    local items = {}
    for id, count in pairs(itemMap) do
        local needShowHelp = Tables.spaceshipGrowCabinOutCome2MaterialTable:ContainsKey(id) and showHelp
        table.insert(items, {
            id = id,
            count = count,
            needShowHelp = needShowHelp,
        })
    end

    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        title = title,
        items = items,
    })
end




SpaceshipGrowCabinCtrl.OnSpaceshipGrowCabinSow = HL.Method() << function(self)
    Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BOX_SELECT_SUCC)

    if self.m_panelStack:Peek() == PanelType.Sow then
        
        if not self.m_autoSelectNextSowBox then
            self:_PopPanel()
        else
            local boxes = GameInstance.player.spaceship:GetGrowCabinBoxes(self.m_roomId)
            
            local nextUsableBoxId = -1
            for boxId = 1, Tables.spaceshipConst.growCabinBoxCount do
                local succ, box = boxes:TryGetValue(boxId)
                if succ and not box.hasFormula then
                    nextUsableBoxId = boxId
                    break
                end
            end

            if nextUsableBoxId > 0 then
                self.m_selectBoxId = nextUsableBoxId
                self:_RefreshSowPanel()
                self:_RefreshSowPanelWareHouse()
            else
                self:_PopPanel()
            end
        end
    end
end




SpaceshipGrowCabinCtrl.OnSpaceshipGrowCabinModify = HL.Method(HL.Any) << function(self, args)
    local id, ids = unpack(args)
    self:_RefreshBgBottomNode()
    self:_RefreshOverviewPanel()
end



SpaceshipGrowCabinCtrl.OnSpaceshipRoomStationSync = HL.Method() << function(self)
    self:_RefreshBgBottomNode()
    self:_RefreshOverviewPanelBottomNode()

    for id, boxCell in pairs(self.m_id2GrowCabinBoxCell) do
        local lineCell = self.m_id2GrowCabinBoxCellLine[id]
        boxCell:Refresh(lineCell)
    end
end



SpaceshipGrowCabinCtrl.OnSpaceshipGrowCabinCancel = HL.Method() << function(self)
end




SpaceshipGrowCabinCtrl.OnSpaceshipGrowCabinHarvest = HL.Method(HL.Any) << function(self, args)
    local title = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_SOW_OUTCOME_POPUP_TITLE
    local items = unpack(args)
    self:_ShowOutcomePopup(title, items, true)
end




SpaceshipGrowCabinCtrl.OnSpaceshipGrowCabinBreed = HL.Method(HL.Any) << function(self, args)
    local title = Language.LUA_SPACESHIP_ROOM_GROW_CABIN_BREED_OUTCOME_POPUP_TITLE
    local items = unpack(args)
    self:_ShowOutcomePopup(title, items, false)
    self:_RefreshBreedPanel()
end




SpaceshipGrowCabinCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if DeviceInfo.usingController then
        self.view.extractionWarehouse.numberSelector.view.keyHintAdd.gameObject:SetActive(active)
        self.view.extractionWarehouse.numberSelector.view.keyHintReduce.gameObject:SetActive(active)
    end
end

HL.Commit(SpaceshipGrowCabinCtrl)
