
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ManualCraft
local PHASE_ID = PhaseId.ManualCraft
local MAX_APPEND_MANUFACTURE_COUNT_LIMIT = 5  
local CraftShowingType = CS.Beyond.GEnums.CraftShowingType
local TAB_INDEX_MIN = 1
local filterList = {
    [1] = {
        type = CraftShowingType.ManualCraftTonic,
    },
    [2] = {
        type = CraftShowingType.ManualCraftArmament,
    },
    [3] = {
        type = CraftShowingType.ManualCraftDish,
    },
    [4] = {
        type = CraftShowingType.ManualArableField,
    },
}
















































































ManualCraftCtrl = HL.Class('ManualCraftCtrl', uiCtrl.UICtrl)








ManualCraftCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_MANUAL_WORK_MODIFY] = 'OnManualWorkModify',
    [MessageConst.ON_MANUAL_WORK_CANCEL] = 'OnManualWorkCancel',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = 'OnItemCountChanged',
}


ManualCraftCtrl.m_inventorySystem = HL.Field(HL.Any)


ManualCraftCtrl.m_facManualCraftSystem = HL.Field(HL.Any)


ManualCraftCtrl.m_cntFilterType = HL.Field(HL.Any)


ManualCraftCtrl.m_cntFilterTypeShow = HL.Field(HL.Table)


ManualCraftCtrl.m_filterTypeTabCellCache = HL.Field(HL.Forward("UIListCache"))


ManualCraftCtrl.m_filterTypeTabClickList = HL.Field(HL.Table)


ManualCraftCtrl.m_TabIndex2Cell = HL.Field(HL.Table)


ManualCraftCtrl.m_TabIndex2Valid = HL.Field(HL.Table)


ManualCraftCtrl.m_TabValidNum = HL.Field(HL.Number) << 0


ManualCraftCtrl.m_sortMode = HL.Field(HL.Number) << 1  


ManualCraftCtrl.m_sortIncremental = HL.Field(HL.Boolean) << true


ManualCraftCtrl.m_getCraftCellFunc = HL.Field(HL.Function)


ManualCraftCtrl.m_craftInfoList = HL.Field(HL.Table)


ManualCraftCtrl.m_allIngredientsForDisplayCraft = HL.Field(HL.Table)


ManualCraftCtrl.m_csIndex2craftItemCell = HL.Field(HL.Table)


ManualCraftCtrl.m_selectedCraftId = HL.Field(HL.String) << ""


ManualCraftCtrl.m_selectedCraftTabType = HL.Field(HL.Any) << ""


ManualCraftCtrl.m_selectedTabIndex = HL.Field(HL.Number) << -1


ManualCraftCtrl.m_workshopList = HL.Field(HL.Forward("UIListCache"))


ManualCraftCtrl.m_manualCount = HL.Field(HL.Number) << 0


ManualCraftCtrl.m_manufactureListCache = HL.Field(HL.Forward("UIListCache"))


ManualCraftCtrl.m_readCraftIds = HL.Field(HL.Table)


ManualCraftCtrl.m_isMaking = HL.Field(HL.Boolean) << false


ManualCraftCtrl.itemNaviFlag = HL.Field(HL.Boolean) << false


ManualCraftCtrl.m_tabPlayingOutAnim = HL.Field(HL.Boolean) << false


ManualCraftCtrl.m_fabricateSoundKey = HL.Field(HL.Number) << 0


ManualCraftCtrl.m_filterSetting = HL.Field(HL.Table)


ManualCraftCtrl.m_realFilterSetting = HL.Field(HL.Table)


ManualCraftCtrl.m_nowTabCell = HL.Field(HL.Any)


ManualCraftCtrl.m_nowCraftCell = HL.Field(HL.Any)


ManualCraftCtrl.m_filterCells = HL.Field(HL.Forward("UIListCache"))


ManualCraftCtrl.m_filterCurNaviIndex = HL.Field(HL.Number) << 0


ManualCraftCtrl.m_jumpId = HL.Field(HL.String) << ""


ManualCraftCtrl.m_initSelectCsIndex = HL.Field(HL.Number) << 0






ManualCraftCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    MAX_APPEND_MANUFACTURE_COUNT_LIMIT = Tables.factoryConst.manualWorkCountLimit  

    self.m_inventorySystem = GameInstance.player.inventory
    self.m_facManualCraftSystem = GameInstance.player.facManualCraft

    self.m_readCraftIds = {}

    self.m_workshopList = UIUtils.genCellCache(self.view.itemCell)
    if arg and arg.jumpId then
        self.m_jumpId = arg.jumpId
    end
    if arg and arg.showPopup then
        UIManager:Open(PanelId.ManualCraftPopups,{ itemId = arg.itemId })
    end
    
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.ManualCraft)
    end)
    self.m_csIndex2craftItemCell = {}
    self.view.craftContent.onUpdateCell:AddListener(function(gameObject, index)
        self:_UpdateCell(gameObject, index)
    end)
    self.view.craftContent.onSelectedCell:AddListener(function(obj, csIndex)
        self:_SelectCraft(self.m_craftInfoList[LuaIndex(csIndex)].id)
    end)

    self.view.productionManualBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.ManualCraftPopups)
    end)
    self.m_sortMode = 1
    self.m_sortIncremental = false
    self.m_filterSetting = {}
    self.m_realFilterSetting = {}
    local list = self.m_facManualCraftSystem:GetAllDomainData()
    for i = 0 , list.Count - 1 do
        local domainData = list[i]
        table.insert(self.m_filterSetting, {id = domainData.domainId, domainName = domainData.domainName, defaultIsOn = false,name = domainData.domainName})
    end

    for index, info in ipairs(self.m_filterSetting) do
        local keyName = "ManualCraft.Filter.Tab." .. index
        self.m_filterSetting[index].isOn = Unity.PlayerPrefs.GetInt(keyName, info.defaultIsOn and 1 or 0) == 1
    end


    self:BindInputPlayerAction("jump_manual_tab_prev", function()
        self:_ClickPrevTab()
    end)
    self:BindInputPlayerAction("jump_manual_tab_next", function()
        self:_ClickNextTab()
    end)

    self:_InitFilterTypeTab()

    self.view.btnCommon.onClick:AddListener(function()
        self:_StartCraft()
    end)

    self.view.settingList.gameObject:SetActive(false)
    self.view.productionManualRedDot:InitRedDot("ManualCraftRewardEntry")

    local isUnlock = Utils.isSystemUnlocked(GEnums.UnlockSystemType.ProductManual) and Utils.isInMainScope()
    self.view.productionManualBtn.gameObject:SetActive(isUnlock)

    if DeviceInfo.usingController then
        self.view.rightBottomDecorationIcon.gameObject:SetActive(false)
    else
        self.view.rightBottomDecorationIcon.gameObject:SetActive(true)
    end

    self.view.itemContentSelectableNaviGroup.onIsFocusedChange:AddListener(function(isFocus)
        self.view.rightBottomDecorationIcon.gameObject:SetActive(isFocus)
        self.view.promptBox.gameObject:SetActive(not isFocus)
    end)

    self:Notify(MessageConst.ON_DISABLE_COMMON_TOAST)
end






ManualCraftCtrl._ApplySort = HL.Method(HL.Table, HL.Boolean) << function(self, optData, isIncremental)
    self.m_sortMode = optData.sortMode
    self.m_sortIncremental = isIncremental
    if self.m_nowCraftCell ~= nil then
        self.m_nowCraftCell.selected.gameObject:SetActive(false)
        self.m_nowCraftCell = nil
    end
    self:_RefreshCraftList()
    for k,v in pairs(self.m_readCraftIds) do
        self.m_facManualCraftSystem:ReadSingleCraft(k)
    end
end




ManualCraftCtrl._FilterBtnConfirm = HL.Method(HL.Any) << function(self, tags)
    if self.m_nowCraftCell then
        self.m_nowCraftCell.defalut.gameObject:SetActive(true)
        self.m_nowCraftCell.selected.gameObject:SetActive(false)
        self.m_nowCraftCell = nil
    end
    for i = 1, #self.m_filterSetting do
        self.m_filterSetting[i].isOn = false
        local keyName = "ManualCraft.Filter.Tab." .. i
        Unity.PlayerPrefs.SetInt(keyName, 0)
    end

    if tags ~= nil then
        for i = 1,#tags do
            for j = 1,#self.m_filterSetting do
                if self.m_filterSetting[j].id == tags[i].id then
                    local keyName = "ManualCraft.Filter.Tab." .. j
                    self.m_filterSetting[j].isOn = true
                    Unity.PlayerPrefs.SetInt(keyName, 1)
                end
            end
        end
    end
    self:_RefreshCraftList()
end




ManualCraftCtrl._FilterBtnGetResCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    local noSelect = #tags == 0
    local formulaList = self.m_facManualCraftSystem:GetUnlockedFormulaByType(self.m_cntFilterType)

    if noSelect then
        return formulaList.Count
    end
    local count = 0
    local manualCraftData = Tables.factoryManualCraftTable
    if formulaList ~= nil then
        for _, formulaId in pairs(formulaList) do
            local success, manualCraftInfo = manualCraftData:TryGetValue(formulaId)
            if success == true then
                for j = 1,#tags do
                    if (tags[j].id == manualCraftInfo.domainId) then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end




ManualCraftCtrl._StartCraft = HL.Method() << function(self)
    local needItems = self:_GetIngredientItems(self.m_selectedCraftId, self.m_manualCount)
    
    for _, item in pairs(needItems) do
        local inventoryCount = self:_GetItemCount(item.id)
        local itemName = Tables.itemTable:GetValue(item.id).name
        if inventoryCount < item.count then
            GameAction.ShowUIToast(string.format(Language.LUA_INGREDIENT_NOT_ENOUGH, itemName))
            return
        end
    end
    self.m_facManualCraftSystem:DoManualWork(Utils.getCurrentScope(), self.m_selectedCraftId, self.m_manualCount)
end



ManualCraftCtrl._InitFilterTypeTab = HL.Method() << function(self)
    self.m_cntFilterTypeShow = self.m_cntFilterTypeShow or {}
    self.m_filterTypeTabCellCache = self.m_filterTypeTabCellCache or UIUtils.genCellCache(self.view.tabCell)
    self.m_filterTypeTabClickList = {}
    self.m_TabIndex2Cell = {}
    self.m_TabIndex2Valid = {}


    self.m_TabValidNum = 0
    self.m_filterTypeTabCellCache:Refresh(#filterList, function(cell, index)
        self.m_TabIndex2Cell[index] = cell
        local l = self.m_facManualCraftSystem:GetUnlockedFormulaByType(filterList[index].type)
        if l ~= nil and l.Count > 0 then
            self.m_cntFilterTypeShow[filterList[index].type] = true
            cell.gameObject:SetActive(true)
            self.m_TabIndex2Valid[index] = true
            self.m_TabValidNum = self.m_TabValidNum + 1
        else
            self.m_cntFilterTypeShow[filterList[index].type] = false
            cell.gameObject:SetActive(false)
            self.m_TabIndex2Valid[index] = false
        end
        cell.gameObject.name = "Tab_" .. filterList[index].type:ToString()
        cell.redDot:InitRedDot("ManualCraftType", filterList[index].type)
        local success, craftTypeInfo = Tables.factoryCraftShowingTypeTable:TryGetValue(filterList[index].type:ToInt())
        local clickFUnc = function()
            self:_ClickTab(index)
        end

        if success then
            cell.defalut.gameObject:SetActive(self.m_selectedCraftTabType ~= filterList[index].type)
            cell.selected.gameObject:SetActive(self.m_selectedCraftTabType == filterList[index].type)
            cell.defalut.text.text = craftTypeInfo.name
            cell.selected.text.text = craftTypeInfo.name
            cell.selected.icon:LoadSprite(UIConst.UI_SPRITE_MANUAL_CRAFT_TYPE_ICON, craftTypeInfo.icon)
            cell.defalut.icon:LoadSprite(UIConst.UI_SPRITE_MANUAL_CRAFT_TYPE_ICON, craftTypeInfo.icon)
            cell.button.onClick:AddListener(function()
                self:_ClickTab(index)
            end)
            table.insert(self.m_filterTypeTabClickList, clickFUnc)
        end
    end)

    self:_UpdateTabKeyHint()

    local isAllHide = true
    if not string.isEmpty(self.m_jumpId) then
        local craftData = Tables.factoryManualCraftTable:GetValue(self.m_jumpId)
        if not self.m_cntFilterTypeShow[craftData.showingType] then
            self.m_jumpId = ""
        end
    end

    if string.isEmpty(self.m_jumpId) then
        for i = 1,#filterList do
            if self.m_cntFilterTypeShow[filterList[i].type] then
                isAllHide = false
                self:_ClickTab(i)
                
                break
            end
        end
    else
        local craftData = Tables.factoryManualCraftTable:GetValue(self.m_jumpId)
        for i = 1,#filterList do
            if craftData.showingType == filterList[i].type and self.m_cntFilterTypeShow[filterList[i].type] then
                isAllHide = false
                self:_ClickTab(i)
                
            end
        end
    end

    if isAllHide then
        self:_SetEmpty()
    end
end




ManualCraftCtrl._UpdateTabKeyHint = HL.Method() << function(self)
    if DeviceInfo.usingTouch then
        self.view.tabKeyHintLeft.gameObject:SetActive(false)
        self.view.tabKeyHintRight.gameObject:SetActive(false)
    else
        if self.m_TabValidNum > 1 then
            self.view.tabKeyHintLeft.gameObject:SetActive(true)
            self.view.tabKeyHintRight.gameObject:SetActive(true)
        else
            self.view.tabKeyHintLeft.gameObject:SetActive(false)
            self.view.tabKeyHintRight.gameObject:SetActive(false)
        end
    end
end





ManualCraftCtrl._ClickPrevTab = HL.Method() << function(self)
    if self.m_tabPlayingOutAnim then
        return
    end

    if self.m_selectedTabIndex == -1 then
        return
    end

    if self.m_TabValidNum == 1 then
        return
    end

    local selected = false
    for index = self.m_selectedTabIndex - 1, TAB_INDEX_MIN, -1 do
        if self.m_TabIndex2Valid[index] then
            self:_ClickTab(index)
            selected = true
            break
        end
    end

    if not selected then
        for index = #filterList, TAB_INDEX_MIN, -1 do
            if self.m_TabIndex2Valid[index] then
                self:_ClickTab(index)
                selected = true
                break
            end
        end
    end
end



ManualCraftCtrl._ClickNextTab = HL.Method() << function(self)
    if self.m_tabPlayingOutAnim then
        return
    end

    if self.m_TabValidNum == 1 then
        return
    end

    if self.m_selectedTabIndex == -1 then
        return
    end

    local selected = false
    for index = self.m_selectedTabIndex + 1, #filterList do
        if self.m_TabIndex2Valid[index] then
            self:_ClickTab(index)
            selected = true
            break
        end
    end

    if not selected then
        for index = TAB_INDEX_MIN, #filterList do
            if self.m_TabIndex2Valid[index] then
                self:_ClickTab(index)
                selected = true
                break
            end
        end
    end
end




ManualCraftCtrl._ClickTab = HL.Method(HL.Any) << function(self, tabIndex)
    if self.m_tabPlayingOutAnim then
        return
    end

    local cell = self.m_TabIndex2Cell[tabIndex]
    if cell == nil then
        return
    end

    self.itemNaviFlag = true

    local filterType = filterList[tabIndex].type
    if self.m_selectedCraftTabType == filterType then
        return
    end

    for k,v in pairs(self.m_readCraftIds) do
        self.m_facManualCraftSystem:ReadSingleCraft(k)
    end

    if self.m_nowTabCell ~= nil then
        self.m_nowTabCell.defalut.gameObject:SetActive(true)
        local nowTabCell = self.m_nowTabCell
        self.m_tabPlayingOutAnim = true
        nowTabCell.selectedAnimationWrapper:PlayOutAnimation(function()
            nowTabCell.selected.gameObject:SetActive(false)
            self.m_tabPlayingOutAnim = false
        end)
    end

    if self.m_nowCraftCell ~= nil then
        self.m_nowCraftCell.defalut.gameObject:SetActive(true)
        self.m_nowCraftCell.selected.gameObject:SetActive(false)
        self.m_nowCraftCell = nil
    end
    self.view.settingList.gameObject:SetActive(false)
    cell.defalut.gameObject:SetActive(false)
    cell.selected.gameObject:SetActive(true)
    cell.selectedAnimationWrapper:PlayInAnimation()
    self:_SetFilterType(filterType)
    self.m_selectedCraftTabType = filterType
    self.m_selectedTabIndex = tabIndex
    self.m_nowTabCell = cell
    if DeviceInfo.usingController then
        AudioAdapter.PostEvent("Au_UI_Button_Common")
    end
    if self.m_selectedTabIndex > 0 then
        local success, craftTypeInfo = Tables.factoryCraftShowingTypeTable:TryGetValue(filterList[self.m_selectedTabIndex].type:ToInt())
        local path = string.gsub(craftTypeInfo.icon, "small", "")
        self.view.typeDecoBg:LoadSprite(UIConst.UI_SPRITE_MANUAL_CRAFT_TYPE_ICON, path)
    end
end





ManualCraftCtrl._SetFilterType = HL.Method(HL.Any) << function(self, craftType)
    
    self.m_nowCraftCell = nil
    self.m_cntFilterType = craftType
    self:_RefreshCraftList()
    
end



ManualCraftCtrl._SetEmpty = HL.Method() << function(self)
    self.view.emptyNode.gameObject:SetActive(true)
    self.view.middleBarNode.gameObject:SetActive(false)
    self.view.rightBar.gameObject:SetActive(false)
    self.view.topBarNode.gameObject:SetActive(false)
    self:_RefreshStartCraftBtn()
end




ManualCraftCtrl._RefreshCraftList = HL.Method() << function(self)
    if self.m_cntFilterType == null then
        self:_SetEmpty()
        return
    end

    local manualCraftData = Tables.factoryManualCraftTable

    self.m_craftInfoList = {}
    self.m_realFilterSetting = {}

    local filterCount = 0
    local realCount = 0
    local formulaList = self.m_facManualCraftSystem:GetUnlockedFormulaByType(self.m_cntFilterType)
    local noSelectFilter = true
    for _, info in pairs(self.m_filterSetting) do
        if info.isOn then
            noSelectFilter = false
            break
        end
    end

    if formulaList ~= nil then
        for _, formulaId in pairs(formulaList) do
            local success, manualCraftInfo = manualCraftData:TryGetValue(formulaId)
            if success == true then
                realCount = realCount + 1
                self.m_realFilterSetting[manualCraftInfo.domainId] = true
                if noSelectFilter then
                    table.insert(self.m_craftInfoList, manualCraftInfo)
                else
                    for j = 1,#self.m_filterSetting do
                        if not self.m_realFilterSetting[manualCraftInfo.domainId] or (self.m_filterSetting[j].id == manualCraftInfo.domainId and self.m_filterSetting[j].isOn) then
                            table.insert(self.m_craftInfoList, manualCraftInfo)
                        end
                    end
                end
            end
        end
    end

    for _, info in pairs(self.m_realFilterSetting) do
        filterCount = filterCount + 1
    end

    local active = filterCount > 1 or (#self.m_craftInfoList == 0 and realCount > 0)
    self.view.filterBtn.gameObject:SetActive(active)


    local selectedFilter = {}
    for _, v in ipairs(self.m_filterSetting) do
        if v.isOn then
            table.insert(selectedFilter, v)
        end
    end

    local filterTags = {}
    if active then
        filterTags = self.m_filterSetting
        self.view.sortNodeUp:InitSortNode(UIConst.ManualCraftSortOptions, function(optData, isIncremental)
            self:_ApplySort(optData, isIncremental)
        end, self.m_sortMode - 1, self.m_sortIncremental, true, self.view.filterBtn)
    else
        selectedFilter = {}

        self.view.sortNodeUp:InitSortNode(UIConst.ManualCraftSortOptions, function(optData, isIncremental)
            self:_ApplySort(optData, isIncremental)
        end, self.m_sortMode - 1, self.m_sortIncremental, true)
    end

    self.view.filterBtn:InitFilterBtn({
        tagGroups = {{tags = filterTags}},
        selectedTags = selectedFilter,
        onConfirm = function(tags)
            self:_FilterBtnConfirm(tags)
            self:_ApplySort(self.view.sortNodeUp:GetCurSortData(), self.view.sortNodeUp.isIncremental)
        end,
        getResultCount = function(tags)
            return self:_FilterBtnGetResCount(tags)
        end,
        sortNodeWidget = self.view.sortNodeUp,
    })


    if active == false then
        self.view.settingList.gameObject:SetActive(active)
    end
    local sortFunc = Utils.genSortFunction(UIConst.ManualCraftSortOptions[self.m_sortMode].sortKeys, self.m_sortIncremental)
    local realFunc = function(a,b)
        if self.m_sortMode == 1 then
            local aCanDo = self:_CheckFormulaAvailable(a.id)
            local bCanDo = self:_CheckFormulaAvailable(b.id)
            if aCanDo ~= bCanDo then
                if self.m_sortIncremental then
                    return not aCanDo
                else
                    return aCanDo
                end
            end
            return sortFunc(a,b)
        else
            return sortFunc(a,b)
        end
    end
    table.sort(self.m_craftInfoList, realFunc)

    self.m_allIngredientsForDisplayCraft = {}

    self.m_getCraftCellFunc = self.m_getCraftCellFunc or UIUtils.genCachedCellFunction(self.view.craftContent)
    local selectIndex = 0
    if not string.isEmpty(self.m_jumpId) then
        for i = 1,#self.m_craftInfoList do
            if self.m_craftInfoList[i].id == self.m_jumpId then
                selectIndex = i - 1
                self.m_jumpId = ""
                self.m_initSelectCsIndex = selectIndex
                break
            end
        end
    end
    
     if #self.m_craftInfoList > 0 then
         self.view.craftContent:SetSelectedIndex(selectIndex, true, true, false)
         self.view.emptyNode.gameObject:SetActive(false)
         self.view.middleBarNode.gameObject:SetActive(true)
         self.view.rightBar.gameObject:SetActive(true)
         self.view.topBarNode.gameObject:SetActive(true)
         self.view.middleBar.gameObject:SetActive(true)
         self.view.itemContent.gameObject:SetActive(true)
         self.view.rightBar.gameObject:SetActive(true)
     elseif realCount > 0 then
         self.view.emptyNode.gameObject:SetActive(false)
         self.view.middleBarNode.gameObject:SetActive(true)
         self.view.middleBar.gameObject:SetActive(false)
         self.view.itemContent.gameObject:SetActive(false)
         self.view.rightBar.gameObject:SetActive(false)
         self.view.topBarNode.gameObject:SetActive(true)
     else
        self:_SetEmpty()
        self.m_workshopList:Refresh(0, function(cell, index)
        end)
    end

    if self.m_csIndex2craftItemCell ~= nil then
        for i, cell in ipairs(self.m_csIndex2craftItemCell) do
            cell.button.onClick:RemoveAllListeners()
        end
    end

    self.m_csIndex2craftItemCell = {}
    if selectIndex == 0 then
        self.view.craftContent:UpdateCount(#self.m_craftInfoList, true)
    else
        self.view.craftContent:UpdateCount(#self.m_craftInfoList, selectIndex)
    end
end





ManualCraftCtrl._UpdateCell = HL.Method(GameObject, HL.Number) << function(self, gameObject, index)
    local luaIdx = LuaIndex(index)

    local craftInfo = self.m_craftInfoList[luaIdx]
    gameObject.name = "Craft_" .. craftInfo.id
    self.m_readCraftIds[craftInfo.id] = true
    local outcomeItemId = craftInfo.outcomes[0].id 
    local craftItemCell = self.m_getCraftCellFunc(gameObject)
    self.m_csIndex2craftItemCell[index] = craftItemCell
    craftItemCell.id = craftInfo.id
    local data = Tables.itemTable:GetValue(outcomeItemId)
    craftItemCell.selected.commodityText.text = data.name
    craftItemCell.defalut.commodityText.text = data.name
    craftItemCell.defalut.itemIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, data.iconId)
    craftItemCell.selected.itemIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, data.iconId)
    craftItemCell.notUnlocked.gameObject:SetActive(false)
    UIUtils.setItemRarityImage(craftItemCell.defalut.colorLine, data.rarity)
    UIUtils.setItemRarityImage(craftItemCell.selected.colorLine, data.rarity)
    if self.view.craftContent.curSelectedIndex == index then
        craftItemCell.selected.gameObject:SetActive(true)
        craftItemCell.animationWrapper:SampleToInAnimationEnd()
        craftItemCell.defalut.gameObject:SetActive(false)
        if self.m_nowCraftCell == nil then
            self.m_nowCraftCell = craftItemCell
        end
        self.m_facManualCraftSystem:ReadSingleCraft(craftInfo.id)
        craftItemCell.defalut.redDot:InitRedDot("ManualCraftItem", craftInfo.id)
    else
        craftItemCell.selected.gameObject:SetActive(false)
        craftItemCell.defalut.gameObject:SetActive(true)
    end

    if self.itemNaviFlag then
        if luaIdx == self.m_initSelectCsIndex + 1 then
            self.itemNaviFlag = false
            InputManagerInst.controllerNaviManager:SetTarget(craftItemCell.button)
        end
    else
        if self.m_selectedCraftId == craftInfo.id then
            InputManagerInst.controllerNaviManager:SetTarget(craftItemCell.button)
        end
    end


    craftItemCell.button.onClick:RemoveAllListeners()
    craftItemCell.button.onClick:AddListener(function()
        self:_SelectCraftItem(index)
    end)

    craftItemCell.defalut.redDot:InitRedDot("ManualCraftItem", craftInfo.id)

    for i = 1, craftInfo.ingredients.Count do
        self.m_allIngredientsForDisplayCraft[craftInfo.ingredients[i-1].id] = true
    end

    self:_RefreshCraftCellAvailable(craftItemCell, true)
end




ManualCraftCtrl._SelectCraftItem = HL.Method(HL.Number) << function(self, csIndex)
    local craftItemCell = self.m_csIndex2craftItemCell[csIndex]
    local luaIdx = LuaIndex(csIndex)
    local craftInfo = self.m_craftInfoList[luaIdx]

    if craftInfo == nil or craftItemCell == nil then
        return
    end

    if self.view.craftContent.curSelectedIndex ~= csIndex then
        if self.m_nowCraftCell ~= nil then
            self.m_nowCraftCell.defalut.gameObject:SetActive(true)
        end
        self.m_facManualCraftSystem:ReadSingleCraft(craftInfo.id)
        craftItemCell.defalut.redDot:InitRedDot("ManualCraftItem", craftInfo.id)
        craftItemCell.defalut.gameObject:SetActive(false)
        craftItemCell.selected.gameObject:SetActive(true)
        self.m_nowCraftCell = craftItemCell
        self.view.craftContent:SetSelectedIndex(csIndex)
        self.view.rightBar.gameObject:GetComponent(typeof(CS.Beyond.UI.UIAnimationWrapper)):PlayInAnimation()
    end
end





ManualCraftCtrl._RefreshCraftCellAvailable = HL.Method(HL.Any, HL.Boolean) << function(self, inCraftItemCell, clearTween)
    local craftAvailable = self:_CheckFormulaAvailable(inCraftItemCell.id)
    










    if craftAvailable then
        inCraftItemCell.selected.craftableText.gameObject:SetActive(true)
        inCraftItemCell.defalut.craftableText.gameObject:SetActive(true)
        inCraftItemCell.defalut.insufficientText.gameObject:SetActive(false)
        inCraftItemCell.selected.insufficientText.gameObject:SetActive(false)

        inCraftItemCell.selected.craftableText.text = Language.LUA_CRAFT_AVAILABLE
        inCraftItemCell.selected.craftableText.color = self.view.config.NORMAL_NUM_COLOR
        inCraftItemCell.defalut.craftableText.color = self.view.config.NORMAL_NUM_COLOR
        inCraftItemCell.defalut.craftableText.text = Language.LUA_CRAFT_AVAILABLE
    else
        inCraftItemCell.selected.craftableText.gameObject:SetActive(false)
        inCraftItemCell.defalut.craftableText.gameObject:SetActive(false)
        inCraftItemCell.defalut.insufficientText.gameObject:SetActive(true)
        inCraftItemCell.selected.insufficientText.gameObject:SetActive(true)

        inCraftItemCell.selected.insufficientText.text = Language.LUA_CRAFT_NOT_AVAILABLE
        inCraftItemCell.selected.insufficientText.color = self.view.config.CRAFT_NOT_AVAILABLE_TEXT_COLOR
        inCraftItemCell.defalut.insufficientText.color = self.view.config.CRAFT_NOT_AVAILABLE_TEXT_COLOR
        inCraftItemCell.defalut.insufficientText.text = Language.LUA_CRAFT_NOT_AVAILABLE
    end

    local color1 = inCraftItemCell.defalut.itemIcon.color
    local color2 = inCraftItemCell.selected.itemIcon.color


    if craftAvailable then
        color1.a = UIConst.ITEM_EXIST_TRANSPARENCY
        color2.a = UIConst.ITEM_EXIST_TRANSPARENCY
        inCraftItemCell.defalut.itemIcon.color = color1
        inCraftItemCell.selected.itemIcon.color = color2

    else
        color1.a = UIConst.ITEM_MISSING_TRANSPARENCY
        color2.a = UIConst.ITEM_MISSING_TRANSPARENCY
        inCraftItemCell.defalut.itemIcon.color = color1
        inCraftItemCell.selected.itemIcon.color = color2
    end
end




ManualCraftCtrl._SelectCraft = HL.Method(HL.String) << function(self, craftId)
    local lastSelectedCraftId = self.m_selectedCraftId
    self.m_selectedCraftId = craftId
    self:_PlayCraftListSelectEffect(lastSelectedCraftId)
    self:_RefreshCraftNode(true)
end





ManualCraftCtrl._OnItemClick = HL.Method(HL.Number) << function(self, luaIndex)
    if PhaseManager:GetTopPhaseId() ~= PhaseId.ManualCraft then
        return
    end
    local rewardCell = self.m_workshopList:Get(luaIndex)
    local posInfo
    if DeviceInfo.usingController then
        posInfo = {
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightMid,
            isSideTips = true,
        }
    end

    rewardCell.itemBigBlack:ShowTips(posInfo)
end




ManualCraftCtrl._RefreshCraftNode = HL.Method(HL.Opt(HL.Boolean)) << function(self, needResetManualCount)
    
    local maxFormulaWorkTimes = 0  
    local success, craftInfo = Tables.factoryManualCraftTable:TryGetValue(self.m_selectedCraftId)
    if not success then
        return
    end

    self.m_workshopList:Refresh(3, function(cell, index)
        if  index <= craftInfo.ingredients.Count then
            local ingredientItem = craftInfo.ingredients[index - 1]
            local inventoryCount = self:_GetItemCount(ingredientItem.id)

            cell.itemBigBlack.gameObject:SetActive(true)
            cell.itemBigBlack:InitItem({id = ingredientItem.id, count = 1}, function()
                self:_OnItemClick(index)
            end)
            cell.itemBigBlack:SetExtraInfo({ isSideTips = DeviceInfo.usingController })

            cell.itemBigBlack.canUse = false
            cell.emptyBG.gameObject:SetActive(false)
            cell.commonStorageNodeNew.gameObject:SetActive(true)
            local inventoryCount = self:_GetItemCount(ingredientItem.id)
            if index == 1 then
                maxFormulaWorkTimes = inventoryCount // ingredientItem.count
            else
                maxFormulaWorkTimes = math.min(maxFormulaWorkTimes, inventoryCount // ingredientItem.count)
            end
        else
            cell.itemBigBlack.gameObject:SetActive(false)
            cell.emptyBG.gameObject:SetActive(true)
            cell.commonStorageNodeNew.gameObject:SetActive(false)
        end
    end)

    maxFormulaWorkTimes = math.max(maxFormulaWorkTimes, 1)  
    maxFormulaWorkTimes = math.min(maxFormulaWorkTimes, MAX_APPEND_MANUFACTURE_COUNT_LIMIT) 

    if success and craftInfo.outcomes.Count > 0 then
        local outcomeItem = craftInfo.outcomes[0].id
        local item = Tables.itemTable:GetValue(outcomeItem)
        if item.type == GEnums.ItemType.CardExp then

        end

        self.view.currentIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, item.iconId)
        self.view.itemDescNode:InitItemDescNode(item.id)
        
        self.view.mainTitle.text = item.name
        local itemTypeName = UIUtils.getItemTypeName(outcomeItem)
        self.view.subtitleText.text = itemTypeName
    end

    local c = 1
    if not needResetManualCount then
        c = math.min(self.m_manualCount, maxFormulaWorkTimes)
    end

    self.view.numberSelector_New:InitNumberSelector(c, 1, maxFormulaWorkTimes, function(cntCount)
        self.m_manualCount = cntCount
        self:_RefreshCraftCount()
    end, false, 0)

    UIUtils.setItemRarityImage(self.view.qualityLight, Tables.itemTable:GetValue(craftInfo.outcomes[0].id).rarity)
end




ManualCraftCtrl.OnItemCountChanged = HL.Method(HL.Any) << function(self, args)
    if string.isEmpty(self.m_selectedCraftId) then
        return
    end
    local changedItemId2DiffCount, _ = unpack(args)
    local manualCraftData = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftData:TryGetValue(self.m_selectedCraftId)
    local needRefreshCount = false
    if success then
        for i = 1, craftInfo.ingredients.Count do
            if changedItemId2DiffCount:ContainsKey(craftInfo.ingredients[i-1].id) then
                needRefreshCount = true
                break
            end
        end
        if changedItemId2DiffCount:ContainsKey(craftInfo.outcomes[0].id) then
            needRefreshCount = true
        end
    end
    if needRefreshCount then
        self:_RefreshCraftCount()
        self:_RefreshCraftNode()
    end

    if self.m_allIngredientsForDisplayCraft then
        for itemId, _ in pairs(changedItemId2DiffCount) do
            if self.m_allIngredientsForDisplayCraft[itemId] then
                for i = 1, #self.m_craftInfoList do
                    local gameObject = self.view.craftContent:Get(CSIndex(i))
                    if gameObject then
                        local craftCell = self.m_getCraftCellFunc(gameObject)
                        if craftCell then
                            self:_RefreshCraftCellAvailable(craftCell, false)
                        end
                    end
                end
                break
            end
        end
    end
end



ManualCraftCtrl._RefreshCraftCount = HL.Method() << function(self)
    self:_RefreshStartCraftBtn()

    if string.isEmpty(self.m_selectedCraftId) then
        return
    end
    local manualCraftData = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftData:TryGetValue(self.m_selectedCraftId)
    if success then
        self.m_workshopList:Refresh(3, function(cell, index)
            if index <= craftInfo.ingredients.Count then
                local itemId = craftInfo.ingredients[CSIndex(index)].id
                local count = craftInfo.ingredients[CSIndex(index)].count
                local demandCount = math.floor(count * self.m_manualCount)
                local inventoryCount = self:_GetItemCount(itemId)
                cell.itemBigBlack:UpdateCountSimple(demandCount, demandCount > inventoryCount)
                UIUtils.setItemStorageCountText(cell.commonStorageNodeNew, itemId, count, false)
            end
        end)

        if craftInfo.outcomes.Count > 0 then
            local outcomeItem = craftInfo.outcomes[0]
            UIUtils.setItemStorageCountText(self.view.commonStorageNodeNew, outcomeItem.id, 1)
            local outcomeCount = math.floor(outcomeItem.count * self.m_manualCount)
            self.view.curNumberText.text = outcomeCount
        end
    end
end



ManualCraftCtrl._RefreshStartCraftBtn = HL.Method() << function(self)
    local manufactureData = self.m_facManualCraftSystem.manufactureData:GetOrFallback(Utils.getCurrentScope())
    local available = not string.isEmpty(self.m_selectedCraftId) and self:_CheckFormulaAvailable(self.m_selectedCraftId)
    if available then
        self.view.btnCommon.gameObject:SetActive(true)
        if self.m_manualCount > 0 and manufactureData.queue.Count < MAX_APPEND_MANUFACTURE_COUNT_LIMIT then
            self.view.btnCommon.interactable = true
        else
            self.view.btnCommon.interactable = false
        end
        self.view.notEnoughBtn.gameObject:SetActive(false)
    else
        self.view.btnCommon.gameObject:SetActive(false)
        self.view.notEnoughBtn.gameObject:SetActive(true)
    end
end




ManualCraftCtrl._PlayCraftListSelectEffect = HL.Method(HL.String) << function(self, lastSelectedCraftId)
    
    for idx, craftInfo in ipairs(self.m_craftInfoList) do
        local gameObject = self.view.craftContent:Get(CSIndex(idx))
        if gameObject then
            local craftCell = self.m_getCraftCellFunc(gameObject)
            local craftAvailable = self:_CheckFormulaAvailable(craftInfo.id)
            if craftInfo.id == self.m_selectedCraftId then
                craftCell.animationWrapper:PlayInAnimation()
            else
                if craftInfo.id == lastSelectedCraftId then
                    local cell = craftCell
                    cell.defalut.gameObject:SetActive(true)
                    craftCell.animationWrapper:PlayOutAnimation(function()
                        if cell ~= self.m_nowCraftCell and self.m_nowCraftCell then
                            cell.selected.gameObject:SetActive(false)
                        end
                    end)
                end
            end
        end
    end
end



ManualCraftCtrl._RefreshMakingState = HL.Method() << function(self)

end




ManualCraftCtrl._ToggleFabricateSound = HL.Method(HL.Boolean) << function(self, isOn)
    if isOn then
        if self.m_fabricateSoundKey == 0 then
            self.m_fabricateSoundKey = AudioManager.PostEvent("au_ui_fac_manualcraft_fabricate")
        end
    else
        if self.m_fabricateSoundKey ~= 0 then
            AudioManager.StopSoundByPlayingId(self.m_fabricateSoundKey)
            self.m_fabricateSoundKey = 0
        end
    end
end




ManualCraftCtrl._RefreshfilterNaviSelected = HL.Method() << function(self)
    self.m_filterCells:Update(function(cell, index)
        cell.controllerSelectedHintNode.gameObject:SetActive(index == self.m_filterCurNaviIndex)
    end)
end



ManualCraftCtrl._RefreshManufactureList = HL.Method() << function(self)

end





ManualCraftCtrl._GetIngredientItems = HL.Method(HL.String, HL.Number).Return(HL.Table) << function(self, formulaId, count)
    local manualCraftTable = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftTable:TryGetValue(formulaId)
    local ret = {}
    if success then
        for i, v in pairs(craftInfo.ingredients) do
            table.insert(ret, {id = v.id, count = v.count * count})
        end
    end
    return ret
end





ManualCraftCtrl._GetOutcomeItems = HL.Method(HL.String, HL.Number).Return(HL.Table) << function(self, formulaId, count)
    local manualCraftTable = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftTable:TryGetValue(formulaId)
    local ret = {}
    if success then
        for i, v in pairs(craftInfo.outcomes) do
            table.insert(ret, {id = v.id, count = v.count * count})
        end
    end
    return ret
end




ManualCraftCtrl._GetItemCount = HL.Method(HL.String).Return(HL.Any) << function(self, itemId)
    local count = Utils.getItemCount(itemId, false, true)
    return count
    




end




ManualCraftCtrl._IsValuableItem = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    local itemData = Tables.itemTable[itemId]
    local valuableDepotType = itemData.valuableTabType
    if valuableDepotType ~= CS.Beyond.GEnums.ItemValuableDepotType.Factory then
        return true
    else
        return false
    end
end





ManualCraftCtrl._CheckFormulaAvailable = HL.Method(HL.String).Return(HL.Boolean) << function(self, formulaId)
    local manualCraftTable = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftTable:TryGetValue(formulaId)
    if success then
        local needItems = self:_GetIngredientItems(formulaId, 1)
        for _, item in pairs(needItems) do
            local inventoryCount = self:_GetItemCount(item.id)
            if inventoryCount < item.count then
                return false
            end
        end

    end
    return true
end




ManualCraftCtrl.OnManualWorkModify = HL.Method(HL.Any) << function(self, arg)
    local manufactureData = self.m_facManualCraftSystem.manufactureData:GetOrFallback(Utils.getCurrentScope())
    if manufactureData.inBlock then
        GameAction.ShowUIToast(Language.LUA_BAG_FULL)
    end
    



    local info = {
        title = Language.LUA_FAC_CRAFT_ITEM_SUCCESS_MAKE,
        onComplete = function()
        end,
    }
    arg = arg[1]
    local manualCraftTable = Tables.factoryManualCraftTable
    local success, craftInfo = manualCraftTable:TryGetValue(arg.FormulaId)
    info.items = {}
    local outItems = self:_GetOutcomeItems(arg.FormulaId, arg.Count)
    for _, item in pairs(outItems) do
        table.insert(info.items, {
            id = item.id,
            count = item.count,
        })
    end
    local _arg = {info, craftInfo.itemId, self:_GetIngredientItems(arg.FormulaId, arg.Count)}
    UIManager:Open(PanelId.CompositeToast, _arg)

    self:_RefreshCraftNode()
    self:_RefreshManufactureList()
end



ManualCraftCtrl.OnGetNewManualFormula = HL.StaticMethod(HL.Any) << function(args)
    local newFormulaIds = unpack(args)
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl:_OnGetNewManualFormula(args)
        ctrl:_RefreshCraftNode()
        ctrl:_RefreshManufactureList()
    else
        if newFormulaIds.Count == 1 then
            local _, craftInfo = Tables.factoryManualCraftTable:TryGetValue(newFormulaIds[0])
            if craftInfo then
                Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_CRAFT_UNLOCK, craftInfo.name))
            end
        elseif newFormulaIds.Count > 1 then
            local _, craftInfo = Tables.factoryManualCraftTable:TryGetValue(newFormulaIds[0])
            if craftInfo then
                Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_MULTIPLE_CRAFT_UNLOCK, craftInfo.name, newFormulaIds.Count))
            end
        end
    end

end




ManualCraftCtrl._OnGetNewManualFormula = HL.Method(HL.Any) << function(self, args)
    self.itemNaviFlag = true
    self.m_initSelectCsIndex = 0
    local newFormulaIds = unpack(args)
    for _, formulaId in pairs(newFormulaIds) do
        local _, formulaData = Tables.factoryManualCraftTable:TryGetValue(formulaId)
        if formulaData then
            for i, k in pairs(filterList) do
                if k.type == formulaData.showingType and not self.m_cntFilterTypeShow[k.type] then
                    self.m_filterTypeTabCellCache:GetItem(i).gameObject:SetActive(true)
                    self.m_cntFilterTypeShow[k.type] = true
                    self.m_TabIndex2Valid[i] = true
                    self.m_TabValidNum = self.m_TabValidNum + 1
                    self:_UpdateTabKeyHint()
                end
            end

            self:_StartTimer(1, function()
                Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_CRAFT_UNLOCK, formulaData.name))
            end)
        end
    end
    self.m_selectedCraftTabType = nil
    if self.m_cntFilterType == nil then
        for i, k in pairs(filterList) do
            if self.m_cntFilterTypeShow[k.type] then
                self:_SetFilterType(k.type)
                break
            end
        end
    else
        for i, k in pairs(filterList) do
            if k.type == self.m_cntFilterType then
                self:_SetFilterType(self.m_cntFilterType)
                break
            end
        end
    end
end



ManualCraftCtrl.OnUnlockManualCraft = HL.StaticMethod(HL.Any) << function(args)
    local newItems = unpack(args)
    local info = {
        title = Language.LUA_FAC_MANUAL_CRAFT_UNLOCK,
        subTitle = Language.LUA_LOST_AND_FOUND_GET_ALL,
        onComplete = function()
        end,
    }
    info.items = {}
    for _, v in pairs(newItems) do
        local id = Tables.factoryManualCraftFormulaUnlockTable:GetValue(v).rewardItemId1
        table.insert(info.items, {
            id = id,
            count = 1,
        })
    end
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, info)
end




ManualCraftCtrl.OnManualWorkCancel = HL.Method(HL.Any) << function(self, arg)
    local backItems, breakItems = unpack(arg)
    local showItems = {}
    for itemId, itemCount in pairs(backItems) do
        table.insert(showItems, { id = itemId, count = itemCount})
    end
    if self.m_fabricateSoundKey ~= 0 then
        AudioManager.StopSoundByPlayingId(self.m_fabricateSoundKey)
        self.m_fabricateSoundKey = 0
    end
    AudioManager.PostEvent("au_ui_fac_manualcraft_terminate")
    GameAction.ShowUIToast(Language.LUA_MANUAL_WORK_HAS_BEEN_CANCELLED)
end



ManualCraftCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshMakingState()
end


ManualCraftCtrl.OnHide = HL.Override() << function(self)
    self:_ToggleFabricateSound(false)
    
end


ManualCraftCtrl.OnClose = HL.Override() << function(self)
    local craftIds = {}
    for craftId, _ in pairs(self.m_readCraftIds) do
        table.insert(craftIds, craftId)
    end
    self.m_facManualCraftSystem:ReadCrafts(craftIds)
    self:_ToggleFabricateSound(false)
    self:Notify(MessageConst.ON_ENABLE_COMMON_TOAST)
end



ManualCraftCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local obj = self.view.craftContent:Get(0)
    if obj then
        InputManagerInst:MoveVirtualMouseTo(obj.transform, self.uiCamera)
    end
end
HL.Commit(ManualCraftCtrl)
