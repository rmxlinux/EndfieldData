
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacFertilization
local PHASE_ID = PhaseId.FacFertilization
local FertilizeType = GEnums.FertilizeType

local PageType = {
    Fertilizer = 1,  
    Feed = 2,  
}



FERTILIZATION_SORT_KEYS = { "isNotEnough", "reverseRarity", "sortId1", "sortId2", "id" }

local Fertilize_Cell_Select_In = "facfertilization_cell_select_in"
local Fertilize_Cell_Select_Out = "facfertilization_cell_select_out"





FacFertilizationCtrl = HL.Class('FacFertilizationCtrl', uiCtrl.UICtrl)





FacFertilizationCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FAC_FERTILIZATION_MODE_SETTING_CHANGED] = '_UpdateContent',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = '_OnItemCountChanged',
}

FacFertilizationCtrl.m_pageType = HL.Field(HL.Any)

FacFertilizationCtrl.m_nodeId = HL.Field(HL.Any)

FacFertilizationCtrl.m_intFacSoilComponent = HL.Field(CS.Beyond.Gameplay.Core.IntFacSoilComponent)


FacFertilizationCtrl.m_inventorySystem = HL.Field(CS.Beyond.Gameplay.InventorySystem)

FacFertilizationCtrl.m_typeStateMap = HL.Field(HL.Table)

FacFertilizationCtrl.m_itemCell = HL.Field(HL.Any)

FacFertilizationCtrl.m_itemList = HL.Field(HL.Any)

FacFertilizationCtrl.m_chosenIdx = HL.Field(HL.Any)

FacFertilizationCtrl.m_originalFeedId = HL.Field(HL.String) << ""




FacFertilizationCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_pageType = arg.pageType

    
    self.m_inventorySystem = GameInstance.player.inventory
    local nodeId = arg.nodeId
    self.m_nodeId = nodeId
    if self.m_pageType == PageType.Fertilizer then
        local soilShow = GameInstance.player.facSoilSystem:GetSoilShow(nodeId)
        self.m_intFacSoilComponent = soilShow.facSoilComponent
    else
        self.m_originalFeedId = arg.originalFeedId or ""
        if string.isEmpty(self.m_originalFeedId) then
            local _, ranchData = GameInstance.player.ranchSystem:GetRanchData(nodeId)
            self.m_originalFeedId = ranchData and ranchData.feed.feedId or ""
        end
    end
    self.m_chosenIdx = -1
    self.m_typeStateMap = {
        [FertilizeType.DecreaseTime] = "AccelerateGrowth",    
        [FertilizeType.IncreaseProduction] = "Increase",   
    }

    
    self:_BindUI()

    self:_RefreshItemList()

    CS.Beyond.Gameplay.Conditions.OnFacFertilizationPanelOpen.Trigger(self.m_pageType)
end












FacFertilizationCtrl._BindUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:_Exit()
    end)
    self.view.maskBtn.onClick:AddListener(function()
        self:_Exit()
    end)

    if self.m_pageType == PageType.Fertilizer then
        self.view.useBtn.onClick:AddListener(function()
            
            self:_DoFertilize()
        end)
        self.view.right.supportBtn.button.onClick:AddListener(function()
            self:_OnSupportBtnClick()
        end)
    else
        local onFeedBtnClick = function()
            self:_DoFeedAdd()
        end
        self.view.addBtn.onClick:AddListener(onFeedBtnClick)
        self.view.replaceBtn.onClick:AddListener(onFeedBtnClick)
        self.view.right.infoBtnNode.gameObject:SetActive(true)
    end
    self.view.right.infoBtn.onClick:RemoveAllListeners()
    self.view.right.infoBtn.onClick:AddListener(function()
    local info = self.m_itemList[self.m_chosenIdx]
    if info == nil then
        return
    end
    Notify(MessageConst.SHOW_ITEM_TIPS, {
        transform = self.view.right.infoBtn.transform,
        posType = UIConst.UI_TIPS_POS_TYPE.RightTop,
        itemId = info.id,
    })
    end)

    self.m_itemCell = UIUtils.genCachedCellFunction(self.view.itemList)
    self.view.itemList.onUpdateCell:AddListener(function(obj, index)
        self:_UpdateItem(self.m_itemCell(obj), LuaIndex(index))
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputBindingGroupMonoTarget.groupId })
end

FacFertilizationCtrl._InitData = HL.Method().Return(HL.Any) << function(self)
    if self.m_pageType == PageType.Fertilizer then
        return self:_LoadFertilization()
    else
        return self:_LoadFeed()
    end
end


FacFertilizationCtrl._LoadFertilization = HL.Method().Return(HL.Any) << function(self)
    
    local fertilizeTable = Tables.fertilizeDataTable
    
    local itemCount = 0
    self.m_itemList = {}
    for id, _ in pairs(fertilizeTable) do
        
        if self.m_inventorySystem:IsItemFound(id) then
            local count = Utils.getItemCount(id, true, true)
            local itemCfg = Tables.itemTable[id]
            local _, fertilizeCfg = Tables.fertilizeDataTable:TryGetValue(id)
            local iconId
            if fertilizeCfg ~= nil then
                iconId = fertilizeCfg.detailIconId
            end
            local info = {
                id = id,
                count = count,
                rarity = itemCfg.rarity,
                reverseRarity = -itemCfg.rarity,
                type = itemCfg.type,
                name = itemCfg.name,
                iconId = itemCfg.iconId,
                detailText = itemCfg.desc,
                richText = itemCfg.decoDesc,
                detailIconId = iconId,
                fertilizeDataList = {},
                isNotEnough = count <= 0 and 1 or 0,    
                
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
            }
            
            for i = 0, fertilizeCfg.fertilizeType.Count - 1 do
                table.insert(info.fertilizeDataList, {
                    type = fertilizeCfg.fertilizeType[i],
                    param = fertilizeCfg.fertilizeParam1[i],
                })
            end
            table.insert(self.m_itemList, info)
            itemCount = itemCount + 1
        end
    end

    
    table.sort(self.m_itemList, Utils.genSortFunction(FERTILIZATION_SORT_KEYS, true))
    return itemCount
end


FacFertilizationCtrl._LoadFeed = HL.Method().Return(HL.Any) << function(self)
    
    local feedTable = Tables.innRanchFeedTable
    
    local itemCount = 0
    self.m_itemList = {}
    for id, _ in pairs(feedTable) do
        
        if self.m_inventorySystem:IsItemFound(id) then
            
            local count = Utils.getItemCount(id, true, true)
            local itemCfg = Tables.itemTable[id]
            local _, feedCfg = feedTable:TryGetValue(id)
            local iconId
            if feedCfg ~= nil then
                iconId = feedCfg.detailIconId
            end
            local info = {
                id = id,
                count = count,
                rarity = itemCfg.rarity,
                reverseRarity = -itemCfg.rarity,
                type = itemCfg.type,
                name = itemCfg.name,
                iconId = itemCfg.iconId,
                detailText = itemCfg.desc,
                richText = itemCfg.decoDesc,
                obtainWayIds = itemCfg.obtainWayIds,
                detailIconId = iconId,
                feedDataList = {},
                isNotEnough = count <= 0 and 1 or 0,    
                
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
            }
            
            
            if feedCfg.fullnessAddSeconds > 0 then
                table.insert(info.feedDataList, {
                    type = "FullnessAdd",
                    param = feedCfg.fullnessAddSeconds,
                })
            end
            if feedCfg.happinessAddSeconds > 0 then
                table.insert(info.feedDataList, {
                    type = "HappinessAdd",
                    param = feedCfg.happinessAddSeconds,
                })
            end
            table.insert(self.m_itemList, info)
            itemCount = itemCount + 1
        end
    end

    
    table.sort(self.m_itemList, Utils.genSortFunction(FERTILIZATION_SORT_KEYS, true))
    return itemCount
end






FacFertilizationCtrl._RefreshItemList = HL.Method() << function(self)
    local isInitialSelection = self.m_chosenIdx == -1
    
    local chosenId = self.m_pageType == PageType.Feed and self.m_originalFeedId or nil
    if self.m_chosenIdx ~= -1 and self.m_itemList ~= nil then
        local chosenInfo = self.m_itemList[self.m_chosenIdx]
        if chosenInfo ~= nil then
            chosenId = chosenInfo.id
        end
    end

    
    self:_InitData()
    self.m_chosenIdx = -1

    
    self.view.itemList:UpdateCount(#self.m_itemList)

    
    self.view.main:SetState(#self.m_itemList <= 0 and "Empty" or "Content")
    self.view.main:SetState(self.m_pageType == PageType.Fertilizer and "Cowdung" or "Feed")

    local nextIdx = -1
    if chosenId ~= nil then
        for index, info in ipairs(self.m_itemList) do
            if info.id == chosenId then
                nextIdx = index
                break
            end
        end
    end
    if nextIdx == -1 and #self.m_itemList > 0 then
        nextIdx = LuaIndex(0)
    end
    if nextIdx ~= -1 then
        if isInitialSelection then
            
            self.view.itemList:ScrollToIndex(CSIndex(nextIdx), true)
        end
        
        self:_ChooseItem(nextIdx)
        if isInitialSelection and DeviceInfo.usingController then
            local item = self.m_itemCell(nextIdx)
            if item then
                self:SetNaviTarget(item.button)
            end
        end
    end
end

FacFertilizationCtrl._UpdateItem = HL.Method(HL.Any, HL.Any) << function(self, item, index)
    local itemInfo = self.m_itemList[index]
    item.gameObject.name = "itemCellState" .. index
    
    item.button.onClick:RemoveAllListeners()
    item.button.onClick:AddListener(function()
        self:_ChooseItem(index)
    end)
    
    item.nodeState:SetState(itemInfo.isNotEnough == 1 and "NotEnough" or "Enough")
    item.nodeState:SetState("NotSelected")
    item.nameTxt.text = itemInfo.name
    item.numTxt.text = I18nUtils.CombineStringWithLanguageSpilt(Language.ui_fac_soil_fertilize_fertilizer_taken_num, tostring(itemInfo.count))
    item.icon:LoadSprite(UIConst.UI_SPRITE_ITEM, itemInfo.iconId)
    UIUtils.setItemRarityImage(item.colorLine, itemInfo.rarity)
end

FacFertilizationCtrl._UpdateContent = HL.Method() << function(self)
    if self.m_chosenIdx == -1 then
        return
    end

    local info = self.m_itemList[self.m_chosenIdx]
    if info == nil then
        return
    end

    
    local canInteract = info.isNotEnough == 0
    self.view.useBtn.interactable = canInteract
    if canInteract then
        self.view.useBtnTxt.text = Language.LUA_FAC_FERTILIZATION_INTERACT
        self.view.useBtnState:SetState("NormalState")
    else
        self.view.useBtnTxt.text = Language.LUA_FAC_FERTILIZATION_CANNOT_INTERACT
        self.view.useBtnState:SetState("ActiveState")
    end

    
    self.view.nameTxt.text = info.name
    if info.detailIconId ~= nil then
        self.view.icon:LoadSprite(UIConst.UI_SPRITE_CROP, info.detailIconId)
    end

    
    self.view.detailTxt.text = info.detailText
    self.view.richTxt.text = info.richText

    
    local obtainWayNode = self.view.right.wayNode
    local hasFeedConfig, feedConfig = Tables.innRanchFeedTable:TryGetValue(info.id)
    if hasFeedConfig then
        obtainWayNode.gameObject:SetActive(true)
        obtainWayNode.descTxt.text = feedConfig.itemDesc
    else
        obtainWayNode.gameObject:SetActive(false)
    end

    
    local layoutNode = self.view.right.layoutNode
    layoutNode.accelerateState.gameObject:SetActive(false)
    layoutNode.increaseNode.gameObject:SetActive(false)
    layoutNode.fullnessNode.gameObject:SetActive(false)
    layoutNode.happinessNode.gameObject:SetActive(false)
    if self.m_pageType == PageType.Fertilizer then
        for _, data in ipairs(info.fertilizeDataList) do
            if data.type == FertilizeType.DecreaseTime then 
                layoutNode.accelerateState.gameObject:SetActive(true)
                local minutes = Utils.getDynamicParamIntValue(data.param) / Const.SEC_PER_MIN
                layoutNode.accelerateState.accelerateTxt.text = string.format(
                    Language.LUA_FAC_FERTILIZATION_EFFECT_ACCELERATE,
                    FactoryUtils.getHourTextByMinutes(minutes))
            end
            if data.type == FertilizeType.IncreaseProduction then  
                local increaseValue = FactoryUtils.getFertilizeIncreaseParam(data.param)
                if increaseValue ~= nil then
                    layoutNode.increaseNode.gameObject:SetActive(true)
                    local percentage = math.floor(increaseValue * 100 + 0.5)
                    local percentageStr = string.format("%d%%", percentage)
                    layoutNode.increaseNode.increaseTxt.text = string.format(
                        Language.LUA_FAC_FERTILIZATION_EFFECT_INCREASE,
                        percentageStr
                    )
                end
            end
        end
    elseif self.m_pageType == PageType.Feed then
        local isReplacingFeed = not string.isEmpty(self.m_originalFeedId) and self.m_originalFeedId ~= info.id
        local isReplacingFeed = not string.isEmpty(self.m_originalFeedId) and self.m_originalFeedId ~= info.id
        self.view.addBtn.gameObject:SetActive(not isReplacingFeed)
        self.view.replaceBtn.gameObject:SetActive(isReplacingFeed)
        for _, data in ipairs(info.feedDataList) do
            if data.type == "FullnessAdd" then 
                layoutNode.fullnessNode.gameObject:SetActive(true)
            end
            if data.type == "HappinessAdd" then  
                layoutNode.happinessNode.gameObject:SetActive(true)
            end
        end
        return
    end

    
    local isEnableTeammateFertilize = FactoryUtils.isEnableTeammateFertilize()
    local isTeammateFertilizeSameSoil = FactoryUtils.isTeammateFertilizeSameSoil()
    local supportTxt
    if not isEnableTeammateFertilize then
        supportTxt = Language.LUA_FAC_FERTILIZATION_SUPPORT_1
    else
        if not isTeammateFertilizeSameSoil then
            supportTxt = Language.LUA_FAC_FERTILIZATION_SUPPORT_2
        else
            supportTxt = Language.LUA_FAC_FERTILIZATION_SUPPORT_3
        end
    end
    self.view.right.supportBtn.supportTxt.text = supportTxt
end





FacFertilizationCtrl._ChooseItem = HL.Method(HL.Any) << function(self, index)
    if self.m_chosenIdx == index then
        return  
    end

    
    if self.m_chosenIdx ~= -1 then
        local lastItem = self.m_itemCell(self.m_chosenIdx)
        local lastItemInfo = self.m_itemList[self.m_chosenIdx]
        if lastItem then
            lastItem.nodeState:SetState((lastItemInfo.isNotEnough == 1) and "NotEnough" or "Enough")
            lastItem.nodeStateAnim:Play(Fertilize_Cell_Select_Out, function()
                lastItem.nodeState:SetState("NotSelected")
            end)
        end
    end

    local item = self.m_itemCell(index)
    local itemInfo = self.m_itemList[index]
    if item then
        item.nodeState:SetState((itemInfo.isNotEnough == 1) and "NotEnough" or "Enough")
        AudioAdapter.PostEvent("Au_UI_Toggle_Common_On")
        item.nodeStateAnim:Play(Fertilize_Cell_Select_In, function()
            item.nodeState:SetState("Selected")
        end)
    end

    self.m_chosenIdx = index

    
    self:_UpdateContent()
end

FacFertilizationCtrl._DoFertilize = HL.Method() << function(self)
    if PhaseManager:CheckIsInTransition() then
        return
    end

    if self.m_chosenIdx == -1 then
        return
    end

    local info = self.m_itemList[self.m_chosenIdx]
    if info == nil then
        return
    end

    
    Notify(MessageConst.On_FERTILIZE_PANEL_DO_OPERATION)
    self.m_intFacSoilComponent:DoFertilize(info.id) 
    
    
    
end

FacFertilizationCtrl._DoFeedAdd = HL.Method() << function(self)
    if self.m_chosenIdx == -1 then
        return
    end

    local info = self.m_itemList[self.m_chosenIdx]
    if info == nil then
        return
    end

    GameInstance.player.ranchSystem:SendRanchAddFeed(self.m_nodeId, info.id)
    self:_Exit()
end

FacFertilizationCtrl._Exit = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end

FacFertilizationCtrl._OnSupportBtnClick = HL.Method() << function(self)
    UIManager:Open(PanelId.FacFertilizationModePopup, {
        itemId = self.m_itemList[self.m_chosenIdx].id,
        nodeId = self.m_nodeId,
    })
end





FacFertilizationCtrl._OnItemCountChanged = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if args == nil then
        return
    end
    local itemId2DiffCount = unpack(args)
    if itemId2DiffCount == nil then
        return
    end
    local dataTable = self.m_pageType == PageType.Fertilizer and Tables.fertilizeDataTable or Tables.innRanchFeedTable
    for id, _ in pairs(dataTable) do
        if itemId2DiffCount:ContainsKey(id) then
            self:_RefreshItemList()
            return
        end
    end
end


FacFertilizationCtrl._OnOpenFertilization = HL.StaticMethod(HL.Any) << function(arg)
    local pageType, nodeId = unpack(arg)
    
    
    PhaseManager:OpenPhase(PHASE_ID, {
        pageType = pageType,
        nodeId = nodeId,
    })
end






HL.Commit(FacFertilizationCtrl)
