
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.AchievementDepot

AchievementDepotCtrl = HL.Class('AchievementDepotCtrl', uiCtrl.UICtrl)






AchievementDepotCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

AchievementDepotCtrl.m_getCategoryCellFunc = HL.Field(HL.Function)

AchievementDepotCtrl.m_getAchievementCellFunc = HL.Field(HL.Function)

AchievementDepotCtrl.m_getAchievementTitleFunc = HL.Field(HL.Function)

AchievementDepotCtrl.m_flatGroupList = HL.Field(HL.Table)

AchievementDepotCtrl.m_categoryFirstFlatGroupIndex = HL.Field(HL.Table)

AchievementDepotCtrl.m_filterArgs = HL.Field(HL.Table)

AchievementDepotCtrl.m_categoryDataSource = HL.Field(HL.Any) << nil

AchievementDepotCtrl.m_sourceAchievementMap = HL.Field(HL.Any) << nil

AchievementDepotCtrl.m_categoryFilteredData = HL.Field(HL.Any) << nil

AchievementDepotCtrl.m_filteredDataCount = HL.Field(HL.Number) << 0

AchievementDepotCtrl.m_filteredAchievementMap = HL.Field(HL.Any) << nil

AchievementDepotCtrl.m_selectCategoryIndex = HL.Field(HL.Number) << 1

AchievementDepotCtrl.m_selectGroupIndex = HL.Field(HL.Number) << 1

AchievementDepotCtrl.m_searchKey = HL.Field(HL.String) << ''

AchievementDepotCtrl.m_selectedFilterTags = HL.Field(HL.Table)

AchievementDepotCtrl.m_editSelected = HL.Field(HL.Table)

AchievementDepotCtrl.m_selectCount = HL.Field(HL.Number) << 0

AchievementDepotCtrl.m_categorySelectCountInfo = HL.Field(HL.Table)

AchievementDepotCtrl.m_groupSelectCountInfo = HL.Field(HL.Table)

AchievementDepotCtrl.m_depotLimit = HL.Field(HL.Number) << 0

AchievementDepotCtrl.m_args = HL.Field(HL.Any)

AchievementDepotCtrl.m_isFold = HL.Field(HL.Boolean) << false

AchievementDepotCtrl.m_waitAutoScrollTime = HL.Field(HL.Number) << -1

AchievementDepotCtrl.m_isScrollingByCode = HL.Field(HL.Boolean) << false

local SCROLL_SYNC_DELAY = 0.3




AchievementDepotCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    local recoverState = args and args.recoverState or nil
    self.m_args = args
    self:_InitViews()
    self:_LoadData(args and args.depot)
    self:_TryRecoverState(recoverState)
    self:_RenderViews(true)
end








AchievementDepotCtrl._InitViews = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        if self.view.rightListScroll.IsTopLayer then
            self.view.rightListScroll:ManuallyStopFocus()
            self:_ScrollCategoryToCurrentSelect()
            return
        end
        self:_SaveEditData()
    end)

    self.m_getCategoryCellFunc = UIUtils.genCachedCellFunction(self.view.categoryList)
    self.view.categoryList.onUpdateCell:RemoveAllListeners()
    self.view.categoryList.onUpdateCell:AddListener(function(obj, csIndex)
        local isSyncingFromRight = self.view.rightListScroll.IsTopLayer
        self:_RenderCategory(self.m_getCategoryCellFunc(obj), LuaIndex(csIndex), isSyncingFromRight)
    end)
    self.view.categoryList.getCellSize = function(csIndex)
        local luaIndex = LuaIndex(csIndex)
        local categoryInfo = self.m_categoryFilteredData[luaIndex]
        if categoryInfo == nil then
            return 0
        end
        
        local isExpanded = DeviceInfo.usingController or (luaIndex == self.m_selectCategoryIndex and not self.m_isFold)
        if categoryInfo.haveSub and isExpanded then
            return self.view.config.CATEGORY_CELL_HEIGHT + self.view.config.CATEGORY_GROUP_CELL_HEIGHT * #categoryInfo.filteredGroups
        end
        return self.view.config.CATEGORY_CELL_HEIGHT
    end

    self.m_getAchievementCellFunc = UIUtils.genCachedCellFunction(self.view.achievementList)
    self.m_getAchievementTitleFunc = UIUtils.genCachedCellFunction(self.view.achievementList, nil, true)
    self.view.achievementList.onUpdateCell:RemoveAllListeners()
    self.view.achievementList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_RenderAchievement(self.m_getAchievementCellFunc(obj), LuaIndex(csIndex))
    end)
    self.view.achievementList.onUpdateGroupTitle:RemoveAllListeners()
    self.view.achievementList.onUpdateGroupTitle:AddListener(function(obj, groupCSIndex)
        self:_RenderAchievementTitle(self.m_getAchievementTitleFunc(obj), LuaIndex(groupCSIndex))
    end)
    self.view.achievementList.getCellCountInGroup = function(groupCSIndex)
        return self:_GetGroupCellCount(LuaIndex(groupCSIndex))
    end
    self.view.achievementList.onEndDrag:AddListener(function()
        self.m_waitAutoScrollTime = 0
        self.m_isScrollingByCode = false
    end)
    local achievementScrollRect = self.view.achievementList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    if achievementScrollRect then
        achievementScrollRect.onValueChanged:AddListener(function(_)
            if DeviceInfo.usingController then
                return
            end
            if not self.m_isScrollingByCode and self.m_waitAutoScrollTime < 0 then
                self.m_waitAutoScrollTime = 0
            end
        end)
        achievementScrollRect.OnScrollStart:AddListener(function()
            if DeviceInfo.usingController then
                return
            end
            self.m_isScrollingByCode = false
            self.m_waitAutoScrollTime = 0
        end)
    end
    self:_StartUpdate(function(deltaTime)
        if self.m_waitAutoScrollTime < 0 then
            return
        end
        if self.m_waitAutoScrollTime >= SCROLL_SYNC_DELAY then
            self:_SyncLeftPanelByScroll()
            self.m_waitAutoScrollTime = -1
        else
            self.m_waitAutoScrollTime = self.m_waitAutoScrollTime + deltaTime
        end
    end)

    self.view.clearBtn.gameObject:SetActive(false)
    self.view.inputField.text = ''

    UIUtils.initSearchInput(self.view.inputField, {
        clearBtn = self.view.clearBtn,
        onInputValueChanged = function(input)
            local trimedInput = string.trim(input)
            if trimedInput ~= self.m_searchKey then
                self:_SetSearchKey(trimedInput)
            end
        end,
        onInputFocused = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                panelId = PANEL_ID,
                isGroup = true,
                id = self.view.inputFieldInputBindingGroupMonoTarget.groupId,
                rectTransform = self.view.inputField.transform,
                noHighlight = true,
                hintPlaceholder = self.view.controllerHintPlaceholder,
            })
        end,
        onInputEndEdit = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.inputFieldInputBindingGroupMonoTarget.groupId)
            self.view.inputField:DeactivateInputField(true)
            local target = self.view.rightListScroll.getDefaultSelectableFunc()
            if target then
                self:SetNaviTarget(target)
            end
        end,
        onClearClick = function()
            self.view.inputField.text = ''
        end,
    })

    self.m_selectedFilterTags = {}
    self.m_filterArgs = self:_GenFilterArgs()
    self.view.btnCommonFilterNew.button.onClick:RemoveAllListeners()
    self.view.btnCommonFilterNew.button.onClick:AddListener(function()
        self:Notify(MessageConst.SHOW_COMMON_FILTER, self.m_filterArgs)
    end)

    self.view.resetBtn.onClick:RemoveAllListeners()
    self.view.resetBtn.onClick:AddListener(function()
        self:_ResetDepot()
    end)

    self.view.saveBtn.onClick:RemoveAllListeners()
    self.view.saveBtn.onClick:AddListener(function()
        self:_SaveEditData()
    end)

    self.view.rightListScroll.getDefaultSelectableFunc = function()
        local flatIdx = self:_GetFlatGroupIndex(self.m_selectCategoryIndex, self.m_selectGroupIndex)
        local firstObj = self.view.achievementList:Get(CSIndex(flatIdx), 0)
        if firstObj then
            local cell = self.m_getAchievementCellFunc(firstObj)
            return cell.button
        end
        self.view.achievementList:ScrollToIndex(
            CSIndex(flatIdx), 0, true,
            CS.Beyond.UI.UIScrollList.ScrollAlignType.TopEdge)
        local targetObj = self.view.achievementList:Get(CSIndex(flatIdx), 0)
        if targetObj then
            local targetButton = self.m_getAchievementCellFunc(targetObj).button
            return targetButton
        end
        return nil
    end

    self.view.rightListScroll.onSetLayerSelectedTarget:AddListener(function(target)
        if not DeviceInfo.usingController or not target then
            return
        end
        self:_SyncGroupBySelectedAchievement(target)
    end)

    self.view.focusHelperLeft.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            self.view.rightListScroll:ManuallyFocus()
        end
    end
    self.view.focusHelperRight.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            self:_ScrollCategoryToCurrentSelect()
            self.view.rightListScroll:ManuallyStopFocus()
        end
    end
    self.view.rightListScroll.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            self:_ScrollCategoryToCurrentSelect()
        else
            self.view.leftListScroll:SetLayerSelectedTarget(nil, false)
        end
    end)
end

AchievementDepotCtrl._LoadData = HL.Method(HL.Any) << function(self, currDepot)
    self.m_categoryDataSource = {}
    self.m_editSelected = {}
    self.m_sourceAchievementMap = {}
    self.m_selectCount = 0

    self.m_categoryDataSource, self.m_sourceAchievementMap = AchievementUtils.loadAchievementData()

    if currDepot ~= nil then
        self:_LoadDepot(currDepot)
    end

    self.m_depotLimit = Tables.achievementConst.maxDisplayDepotCount

    self:_LoadFilteredData()
    self:_ResetSelectIndex()
end

AchievementDepotCtrl._LoadDepot = HL.Method(HL.Any) << function(self, currDepot)
    for _, achievementId in pairs(currDepot) do
        if self.m_editSelected[achievementId] == nil then
            self.m_editSelected[achievementId] = true
            self.m_selectCount = self.m_selectCount + 1
        end
    end
end

AchievementDepotCtrl._UpdateEditSelectCountInfo = HL.Method() << function(self)
    self.m_groupSelectCountInfo = {}
    self.m_categorySelectCountInfo = {}
    if self.m_filteredAchievementMap == nil then
        return
    end
    for achievementId, flag in pairs(self.m_editSelected) do
        if flag == nil or flag ~= true then
            goto continue
        end

        local achievementIndexInfo = self.m_filteredAchievementMap[achievementId]
        if achievementIndexInfo == nil then
            goto continue
        end

        local categoryIndex = achievementIndexInfo.categoryIndex
        if categoryIndex ~= nil then
            if self.m_categorySelectCountInfo[categoryIndex] == nil then
                self.m_categorySelectCountInfo[categoryIndex] = 0
            end
            self.m_categorySelectCountInfo[categoryIndex] = self.m_categorySelectCountInfo[categoryIndex] + 1
            if self.m_groupSelectCountInfo[categoryIndex] == nil then
                self.m_groupSelectCountInfo[categoryIndex] = {}
            end
            local groupIndex = achievementIndexInfo.groupIndex
            if groupIndex ~= nil then
                if self.m_groupSelectCountInfo[categoryIndex][groupIndex] == nil then
                    self.m_groupSelectCountInfo[categoryIndex][groupIndex] = 0
                end
                self.m_groupSelectCountInfo[categoryIndex][groupIndex] = self.m_groupSelectCountInfo[categoryIndex][groupIndex] + 1
            end
        end
        ::continue::
    end
end

AchievementDepotCtrl._LoadFilteredData = HL.Method() << function(self)
    self.m_filteredDataCount = 0
    self.m_categoryFilteredData, self.m_filteredAchievementMap = AchievementUtils.filterAchievementData(self.m_categoryDataSource, function(achievementInfo, filteredInfos, showNoObtain)
        return self:_FilterAchievement(achievementInfo, filteredInfos, showNoObtain)
    end)
    self:_BuildFlatGroupList()
    self:_UpdateEditSelectCountInfo()
end

AchievementDepotCtrl._ResetEditSelect = HL.Method() << function(self)
    self.m_editSelected = {}
    self.m_selectCount = 0
end

AchievementDepotCtrl._ResetSelectIndex = HL.Method() << function(self)
    self.m_selectCategoryIndex = 1
    self.m_selectGroupIndex = 1
end

AchievementDepotCtrl._FilterAchievement = HL.Method(HL.Any, HL.Any, HL.Boolean).Return(HL.Boolean) << function(self, achievementInfo, filteredInfos, showNoObtain)
    local isObtained = achievementInfo.achievementPlayerInfo ~= nil
        and achievementInfo.achievementPlayerInfo.level >= achievementInfo.achievementData.initLevel
    if not showNoObtain and not isObtained then
        return false
    end
    local isSearch = not string.isEmpty(self.m_searchKey)
    if isSearch then
        local isInclude, repName = self:_IsFilteredBySearchKey(achievementInfo.achievementData.name)
        if not isInclude then
            return false
        end
        achievementInfo.repName = repName
    else
        if self.m_selectedFilterTags and next(self.m_selectedFilterTags) then
            if not FilterUtils.checkIfPassFilter(achievementInfo, self.m_selectedFilterTags) then
                return false
            end
        end
    end
    table.insert(filteredInfos, achievementInfo)
    self.m_filteredDataCount = self.m_filteredDataCount + 1
    return true
end

AchievementDepotCtrl._IsFilteredBySearchKey = HL.Method(HL.String).Return(HL.Boolean, HL.String) << function(self, name)
    if string.isEmpty(self.m_searchKey) then
        return true, name
    end
    if string.isEmpty(name) then
        return false, name
    end
    local key = self.m_searchKey
    local rep = string.format(Language.LUA_ACHIEVEMENT_NAME_SEARCH_REPLACE, key) 
    rep = rep:gsub("%%", "%%%%")
    local pattern = key:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local nameStr, repCount = string.gsub(name, pattern, rep)
    if repCount > 0 then
        return true, nameStr
    end
    return false, name
end

AchievementDepotCtrl._RenderViews = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local isSearchMode = not string.isEmpty(self.m_searchKey)
    if isSearchMode then
        self.view.searchTxt.text = I18nUtils.GetText("ui_achv_list_search_result") .. self.m_filteredDataCount
    end

    local filteredDataCount = #self.m_categoryFilteredData
    isInit = isInit == true

    self.m_isFold = false
    self.view.categoryList:UpdateCount(filteredDataCount, isInit, true)
    if filteredDataCount ~= 0 then
        if DeviceInfo.usingController then
            self.view.categoryList:FoldAll(true)
        else
            self.view.categoryList:FoldAll(false)
            self.view.categoryList:ToggleByState(CSIndex(self.m_selectCategoryIndex), true, true)
        end
    end

    local hasFilter = self.m_selectedFilterTags ~= nil and #self.m_selectedFilterTags > 0
    self.view.btnCommonFilterNew.normalNode.gameObject:SetActiveIfNecessary(not hasFilter)
    self.view.btnCommonFilterNew.existNode.gameObject:SetActiveIfNecessary(hasFilter)

    local state = "Normal"
    if isSearchMode and filteredDataCount > 0 then
        state = "Searching"
    elseif isSearchMode and filteredDataCount <= 0 then
        state = "SearchNull"
    elseif not isSearchMode and filteredDataCount <= 0 then
        state = "FiltrateNull"
    end
    self.view.stateCtrl:SetState(state)

    local flatGroupCount = #self.m_flatGroupList
    self.view.achievementList:UpdateGroup(flatGroupCount, isInit)
    if flatGroupCount > 0 and isInit then
        self:_SetSelectIndex(self.m_selectCategoryIndex, self.m_selectGroupIndex, true)
    elseif flatGroupCount > 0 then
        local flatIdx = self:_GetScrollTargetFlatIndex(self.m_selectCategoryIndex, self.m_selectGroupIndex)
        self.view.achievementList:ScrollToGroup(
            CSIndex(flatIdx), true,
            CS.Beyond.UI.UIScrollList.ScrollAlignType.TopEdge)
    end

    self.view.selectTxt.text = string.format(Language.LUA_ACHIEVEMENT_DEPOT_SELECT_TEXT_FORMAT, self.m_selectCount, self.m_depotLimit)
end

AchievementDepotCtrl._RefreshViews = HL.Method() << function(self)
    self:_RefreshCategoryView()
    self.view.achievementList:UpdateShowingCells(function(csIndex, obj)
        self:_RenderAchievement(self.m_getAchievementCellFunc(obj), LuaIndex(csIndex))
    end)
    self.view.selectTxt.text = string.format(Language.LUA_ACHIEVEMENT_DEPOT_SELECT_TEXT_FORMAT, self.m_selectCount, self.m_depotLimit)
end

AchievementDepotCtrl._RefreshCategoryView = HL.Method() << function(self)
    self.view.categoryList:UpdateShowingCells(function(csIndex, obj)
        self:_RenderCategory(self.m_getCategoryCellFunc(obj), LuaIndex(csIndex), true)
    end)
end

AchievementDepotCtrl._RenderCategory = HL.Method(HL.Any, HL.Number, HL.Opt(HL.Boolean)) << function(self, cell, luaIndex, isRefresh)
    local categoryInfo = self.m_categoryFilteredData[luaIndex]
    if categoryInfo == nil then
        return
    end
    isRefresh = isRefresh == true
    local selected = luaIndex == self.m_selectCategoryIndex
    local isSearchMode = not string.isEmpty(self.m_searchKey)
    local haveSub = categoryInfo.haveSub
    local needExpand = (selected and haveSub) or DeviceInfo.usingController
    local count = self.m_categorySelectCountInfo[luaIndex]
    local showCount = not (haveSub and needExpand) and count ~= nil and count > 0
    cell:InitAchievementCategoryCell(categoryInfo, luaIndex, {
        selectCategoryIndex = self.m_selectCategoryIndex,
        selectGroupIndex = self.m_selectGroupIndex,
        isSearchMode = isSearchMode,
        needSetNavi = not isRefresh,
        isFold = self.m_isFold,
        onCategoryClick = function(categoryIndex)
            local selected = categoryIndex == self.m_selectCategoryIndex
            if not DeviceInfo.usingController and categoryInfo.haveSub then
                AudioAdapter.PostEvent((self.m_isFold or not selected) and "Au_UI_Toggle_AchieveDropDown_On" or "Au_UI_Toggle_AchieveDropDown_Off")
            else
                AudioAdapter.PostEvent("Au_UI_Toggle_Common_On")
            end
            if self.m_selectCategoryIndex == categoryIndex and not DeviceInfo.usingController then
                self.view.categoryList:ToggleByState(CSIndex(categoryIndex), self.m_isFold)
                self.m_isFold = not self.m_isFold
                cell:UpdateArrow(self.m_isFold)
                return
            end
            self:_SetSelectIndex(categoryIndex, 1)
        end ,
        onGroupClick = function(categoryIndex, groupIndex)
            if categoryIndex == self.m_selectCategoryIndex and groupIndex == self.m_selectGroupIndex then
                return
            end
            AudioAdapter.PostEvent("Au_UI_Toggle_Common_On")
            self:_SetSelectIndex(categoryIndex, groupIndex)
        end ,
        onGroupCellRender = function(groupCell, groupIndex)
            local count = 0
            if self.m_groupSelectCountInfo[luaIndex] ~= nil and self.m_groupSelectCountInfo[luaIndex][groupIndex] ~= nil then
                count = self.m_groupSelectCountInfo[luaIndex][groupIndex]
            end
            groupCell.countNode.gameObject:SetActive(count > 0)
            if count > 0 then
                groupCell.countTxt.text = count
            end

            self.view.categoryList:ToggleByState(CSIndex(self.m_selectCategoryIndex), true)
            self.m_isFold = false
            cell:UpdateArrow(self.m_isFold)
        end,
    })
    cell.view.countNode.gameObject:SetActive(showCount)
    if showCount then
        cell.view.countTxt.text = count
    end
end

AchievementDepotCtrl._RenderAchievement = HL.Method(HL.Table, HL.Number) << function(self, cell, globalLuaIndex)
    cell.button.customNaviTargetInDirFunc = nil
    local result = self:_GlobalToGroupLocal(globalLuaIndex)
    if not result.flatGroupIndex then
        return
    end
    local flatGroup = self.m_flatGroupList[result.flatGroupIndex]
    if not flatGroup then
        return
    end
    local achievementInfo = flatGroup.groupInfo.filteredInfos[result.localIndex]
    if achievementInfo == nil then
        return
    end

    local isSearchMode = not string.isEmpty(self.m_searchKey)
    local achievementData = achievementInfo.achievementData
    local achievementId = achievementData.achieveId
    local isSelected = self.m_editSelected[achievementId] ~= nil and self.m_editSelected[achievementId] == true
    local playerInfo = achievementInfo.achievementPlayerInfo
    local playerLevel = (playerInfo == nil) and 0 or playerInfo.level
    local playerPlated = playerInfo ~= nil and playerInfo.isPlated
    local canRare = achievementData.applyRareEffect
    local medalBundle = {
        achievementId = achievementId,
        level = playerLevel,
        isPlated = playerPlated,
        isRare = canRare
    }

    cell.gameObject.name = achievementId
    if isSearchMode then
        cell.name.text = achievementInfo.repName
    else
        cell.name.text = achievementData.name
    end
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:_OnAchievementSelect(achievementId)
    end)
    local totalCellCount = self.view.achievementList.totalCellCount
    local countPerLine = self.view.achievementList.countPerLine
    local groupCellCount = #flatGroup.groupInfo.filteredInfos
    local groupStartGlobalLuaIndex = globalLuaIndex - result.localIndex + 1
    local groupEndGlobalLuaIndex = groupStartGlobalLuaIndex + groupCellCount - 1
    local isFirstRow = groupStartGlobalLuaIndex == 1 and result.localIndex <= countPerLine
    local lastRowStartLocalIndex = math.floor((groupCellCount - 1) / countPerLine) * countPerLine + 1
    local isLastRow = groupEndGlobalLuaIndex == totalCellCount and result.localIndex >= lastRowStartLocalIndex
    
    
    local shouldNaviRightToNextRow = result.localIndex % countPerLine == 0 and result.localIndex < groupCellCount
    if isFirstRow or isLastRow or shouldNaviRightToNextRow then
        cell.button.customNaviTargetInDirFunc = function(dir)
            if isFirstRow and dir == CS.UnityEngine.UI.NaviDirection.Up then
                return self:_GetCircleNaviTarget(totalCellCount - 1, true)
            end
            if isLastRow and dir == CS.UnityEngine.UI.NaviDirection.Down then
                return self:_GetCircleNaviTarget(0, true)
            end
            if shouldNaviRightToNextRow and dir == CS.UnityEngine.UI.NaviDirection.Right then
                return self:_GetCircleNaviTarget(globalLuaIndex, false)
            end
            if globalLuaIndex == totalCellCount and dir == CS.UnityEngine.UI.NaviDirection.Right then
                return self:_GetCircleNaviTarget(0, false)
            end
            return nil
        end
    end
    cell.medal:InitMedal(medalBundle)
    cell.stateCtrl:SetState(isSelected and "Select" or "Normal")
end

AchievementDepotCtrl._GetCircleNaviTarget = HL.Method(HL.Number, HL.Boolean).Return(HL.Any) << function(self, targetCSIndex, shouldClearNaviTarget)
    if targetCSIndex < 0 then
        return nil
    end
    
    if shouldClearNaviTarget then
        self:ClearNaviTarget()
    end
    self.view.achievementList:ScrollToIndex(targetCSIndex, true)
    local targetObj = self.view.achievementList:Get(targetCSIndex)
    if not targetObj then
        return nil
    end
    local targetButton = self.m_getAchievementCellFunc(targetObj).button
    return targetButton
end

AchievementDepotCtrl._OnAchievementSelect = HL.Method(HL.String) << function(self, achievementId)
    local isSelected = self.m_editSelected[achievementId] ~= nil and self.m_editSelected[achievementId] == true
    if isSelected then
        self.m_editSelected[achievementId] = nil
        self.m_selectCount = self.m_selectCount - 1
    elseif self.m_selectCount < self.m_depotLimit then
        self.m_editSelected[achievementId] = true
        self.m_selectCount = self.m_selectCount + 1
    else
        Notify(MessageConst.SHOW_TOAST, I18nUtils.GetText("ui_achv_edit_add_choose_limit"))
        return
    end
    self:_UpdateEditSelectCountInfo()
    self:_RefreshViews()
end

AchievementDepotCtrl._SetSearchKey = HL.Method(HL.String) << function(self, searchKey)
    if self.m_searchKey == searchKey then
        return
    end
    self.m_searchKey = searchKey
    self:_LoadFilteredData()
    self:_ResetSelectIndex()
    self:_RenderViews(true)
end

AchievementDepotCtrl._SetSelectIndex = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Boolean)) << function(self, categoryIndex, groupIndex, forceScroll)
    if not forceScroll and categoryIndex == self.m_selectCategoryIndex and groupIndex == self.m_selectGroupIndex then
        return
    end
    local prevCategory = self.m_selectCategoryIndex
    self.m_selectCategoryIndex = categoryIndex
    self.m_selectGroupIndex = groupIndex
    self.m_isScrollingByCode = true
    self.m_waitAutoScrollTime = -1
    local flatIdx = self:_GetScrollTargetFlatIndex(categoryIndex, groupIndex)
    self.view.achievementList:ScrollToGroup(
        CSIndex(flatIdx), true,
        CS.Beyond.UI.UIScrollList.ScrollAlignType.TopEdge)
    self:_RefreshCategoryView()
    if prevCategory ~= self.m_selectCategoryIndex and not DeviceInfo.usingController then
        if not self.m_isFold then
            self.view.categoryList:ToggleByState(CSIndex(prevCategory), false, true)
            self.m_isFold = true
        end
        local categoryInfo = self.m_categoryFilteredData[self.m_selectCategoryIndex]
        if categoryInfo.haveSub then
            self.view.categoryList:ToggleByState(CSIndex(self.m_selectCategoryIndex), true)
            self.m_isFold = false
        end
    end
end

AchievementDepotCtrl._BuildFlatGroupList = HL.Method() << function(self)
    self.m_flatGroupList = {}
    self.m_categoryFirstFlatGroupIndex = {}
    if not self.m_categoryFilteredData then
        return
    end
    local flatIdx = 1
    for catIdx = 1, #self.m_categoryFilteredData do
        self.m_categoryFirstFlatGroupIndex[catIdx] = flatIdx
        local categoryInfo = self.m_categoryFilteredData[catIdx]
        if not categoryInfo then
            goto continue
        end
        if categoryInfo.haveSub then
            table.insert(self.m_flatGroupList, {
                categoryIndex = catIdx,
                groupIndex = 0,
                groupInfo = nil,
                titleState = "Title",
                titleText = categoryInfo.data.categoryName,
            })
            flatIdx = flatIdx + 1
            for grpIdx = 1, #categoryInfo.filteredGroups do
                table.insert(self.m_flatGroupList, {
                    categoryIndex = catIdx,
                    groupIndex = grpIdx,
                    groupInfo = categoryInfo.filteredGroups[grpIdx],
                    titleState = "SubTitle",
                    titleText = categoryInfo.filteredGroups[grpIdx].data.groupName,
                })
                flatIdx = flatIdx + 1
            end
        else
            table.insert(self.m_flatGroupList, {
                categoryIndex = catIdx,
                groupIndex = 1,
                groupInfo = categoryInfo.filteredGroups[1],
                titleState = "Title",
                titleText = categoryInfo.data.categoryName,
            })
            flatIdx = flatIdx + 1
        end
        ::continue::
    end
end

AchievementDepotCtrl._GetFlatGroupIndex = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, categoryIndex, groupIndex)
    local base = self.m_categoryFirstFlatGroupIndex[categoryIndex]
    if not base then
        return 1
    end
    local categoryInfo = self.m_categoryFilteredData[categoryIndex]
    if categoryInfo and categoryInfo.haveSub then
        return base + groupIndex
    end
    return base
end

AchievementDepotCtrl._GetScrollTargetFlatIndex = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, categoryIndex, groupIndex)
    local base = self.m_categoryFirstFlatGroupIndex[categoryIndex]
    if not base then
        return 1
    end
    local categoryInfo = self.m_categoryFilteredData[categoryIndex]
    if categoryInfo and categoryInfo.haveSub then
        if groupIndex <= 1 then
            return base
        end
        return base + groupIndex
    end
    return base
end

AchievementDepotCtrl._FlatGroupToCategoryGroup = HL.Method(HL.Number).Return(HL.Number, HL.Number) << function(self, flatGroupIndex)
    local flatGroup = self.m_flatGroupList[flatGroupIndex]
    if not flatGroup then
        return 1, 1
    end
    return flatGroup.categoryIndex, math.max(flatGroup.groupIndex, 1)
end

AchievementDepotCtrl._RenderAchievementTitle = HL.Method(HL.Any, HL.Number) << function(self, title, flatGroupLuaIndex)
    local flatGroup = self.m_flatGroupList[flatGroupLuaIndex]
    if not flatGroup or not title then
        return
    end
    title.stateController:SetState(flatGroup.titleState)
    title.etchListCellTxt.text = flatGroup.titleText
end

AchievementDepotCtrl._GetGroupCellCount = HL.Method(HL.Number).Return(HL.Number) << function(self, flatGroupLuaIndex)
    local flatGroup = self.m_flatGroupList[flatGroupLuaIndex]
    if not flatGroup or not flatGroup.groupInfo then
        return 0
    end
    return #flatGroup.groupInfo.filteredInfos
end

AchievementDepotCtrl._SyncLeftPanelByScroll = HL.Method() << function(self)
    local cellRange = self.view.achievementList:GetShowRange(0)
    if not cellRange or cellRange.x < 0 then
        return
    end
    local midCellIndex = math.floor((cellRange.x + cellRange.y) / 2)
    local cellOffset = 0
    local targetCatIdx = nil
    local targetGrpIdx = 1
    for g = 1, #self.m_flatGroupList do
        local flatGroup = self.m_flatGroupList[g]
        local groupCellCount = self:_GetGroupCellCount(g)
        if flatGroup and groupCellCount > 0 then
            local groupEnd = cellOffset + groupCellCount - 1
            if midCellIndex >= cellOffset and midCellIndex <= groupEnd then
                targetCatIdx = flatGroup.categoryIndex
                targetGrpIdx = math.max(flatGroup.groupIndex, 1)
                break
            end
            cellOffset = cellOffset + groupCellCount
        end
    end
    if targetCatIdx == nil then
        return
    end
    if targetCatIdx ~= self.m_selectCategoryIndex or targetGrpIdx ~= self.m_selectGroupIndex then
        local prevCategory = self.m_selectCategoryIndex
        self.m_selectCategoryIndex = targetCatIdx
        self.m_selectGroupIndex = targetGrpIdx
        self:_UpdateCategorySelection(prevCategory)
    end
end

AchievementDepotCtrl._GlobalToGroupLocal = HL.Method(HL.Number).Return(HL.Table) << function(self, globalLuaIndex)
    local remaining = globalLuaIndex
    for g = 1, #self.m_flatGroupList do
        local grpInfo = self.m_flatGroupList[g].groupInfo
        if grpInfo then
            local count = #grpInfo.filteredInfos
            if remaining <= count then
                return { flatGroupIndex = g, localIndex = remaining }
            end
            remaining = remaining - count
        end
    end
    return {}
end

AchievementDepotCtrl._SyncGroupBySelectedAchievement = HL.Method(HL.Any) << function(self, target)
    if not target then
        return
    end
    local totalCount = self.view.achievementList.totalCellCount
    for csIndex = 0, totalCount - 1 do
        local obj = self.view.achievementList:Get(csIndex)
        if obj then
            local cell = self.m_getAchievementCellFunc(obj)
            if cell and cell.button == target then
                local result = self:_GlobalToGroupLocal(LuaIndex(csIndex))
                if result.flatGroupIndex then
                    local catIdx, grpIdx = self:_FlatGroupToCategoryGroup(result.flatGroupIndex)
                    if catIdx ~= self.m_selectCategoryIndex or grpIdx ~= self.m_selectGroupIndex then
                        local prevCategory = self.m_selectCategoryIndex
                        self.m_selectCategoryIndex = catIdx
                        self.m_selectGroupIndex = grpIdx
                        self:_UpdateCategorySelection(prevCategory)
                    end
                end
                return
            end
        end
    end
end

AchievementDepotCtrl._ScrollCategoryToCurrentSelect = HL.Method() << function(self)
    local csIndex = CSIndex(self.m_selectCategoryIndex)
    local catObj = self.view.categoryList:Get(csIndex)
    if not catObj then
        self.view.categoryList:ScrollToIndex(csIndex, true)
        catObj = self.view.categoryList:Get(csIndex)
    end
    if catObj then
        self:_RenderCategory(self.m_getCategoryCellFunc(catObj), self.m_selectCategoryIndex)
    end
    self:_ScrollCategoryToSubGroup()
end

AchievementDepotCtrl._ScrollCategoryToSubGroup = HL.Method() << function(self)
    local catObj = self.view.categoryList:Get(CSIndex(self.m_selectCategoryIndex))
    if not catObj then
        return
    end
    local categoryCell = self.m_getCategoryCellFunc(catObj)
    local categoryInfo = self.m_categoryFilteredData[self.m_selectCategoryIndex]
    local targetTransform = categoryCell.view.button.transform
    if categoryInfo and categoryInfo.haveSub then
        local subCell = categoryCell.m_cacheCell:Get(self.m_selectGroupIndex)
        if subCell then
            targetTransform = subCell.button.transform
        end
    end
    local scrollRect = self.view.categoryList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    if scrollRect then
        scrollRect:AutoScrollToRectTransform(targetTransform, true)
    end
end

AchievementDepotCtrl._UpdateCategorySelection = HL.Method(HL.Number) << function(self, prevCategoryIndex)
    local filteredDataCount = #self.m_categoryFilteredData
    
    if DeviceInfo.usingController or prevCategoryIndex == self.m_selectCategoryIndex then
        local csIndex = CSIndex(self.m_selectCategoryIndex)
        local catObj = self.view.categoryList:Get(csIndex)
        if not catObj then
            self.view.categoryList:ScrollToIndex(csIndex, true)
        end
        self.view.categoryList:UpdateShowingCells(function(csIndex, obj)
            self:_RenderCategory(self.m_getCategoryCellFunc(obj), LuaIndex(csIndex), true)
        end)
        self:_ScrollCategoryToSubGroup()
    else
        self.view.categoryList:UpdateCount(filteredDataCount, false, true)
        if filteredDataCount ~= 0 then
            self.view.categoryList:FoldAll(false)
            local categoryInfo = self.m_categoryFilteredData[self.m_selectCategoryIndex]
            if categoryInfo and categoryInfo.haveSub then
                self.view.categoryList:ToggleByState(CSIndex(self.m_selectCategoryIndex), true, true)
                self.m_isFold = false
            end
        end
        local csIndex = CSIndex(self.m_selectCategoryIndex)
        local catObj = self.view.categoryList:Get(csIndex)
        if not catObj then
            self.view.categoryList:ScrollToIndex(csIndex, true)
        end
        self:_ScrollCategoryToSubGroup()
    end
end

AchievementDepotCtrl._GenFilterArgs = HL.Method().Return(HL.Any) << function(self)
    return {
        tagGroups = FilterUtils.generateConfig_ACHIEVEMENT_MEDAL(),
        selectedTags = self.m_selectedFilterTags,
        onConfirm = function(tags)
            self.m_filterArgs.selectedTags = tags
            self.m_selectedFilterTags = tags
            self:_LoadFilteredData()
            self:_ResetSelectIndex()
            self:_RenderViews(true)
        end,
        getResultCount = function(tags)
            return self:_GetFilteredCount(tags)
        end,
    }
end

AchievementDepotCtrl._GetFilteredCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if not tags or not next(tags) then
        return
    end
    local count = 0
    for _, achievementInfo in pairs(self.m_sourceAchievementMap) do
        if achievementInfo ~= nil and FilterUtils.checkIfPassFilter(achievementInfo, tags) then
            count = count + 1
        end
    end
    return count
end

AchievementDepotCtrl.GetRecoverStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return {
        selectedAchievementIds = self:_GetSelectedAchievementRecoverState(),
        selectCategoryIndex = self.m_selectCategoryIndex,
        selectGroupIndex = self.m_selectGroupIndex,
        searchKey = self.m_searchKey,
        selectedFilterTags = lume.deepCopy(self.m_selectedFilterTags),
    }
end

AchievementDepotCtrl._GetSelectedAchievementRecoverState = HL.Method().Return(HL.Table) << function(self)
    local selectedAchievementIds = {}
    for achievementId, flag in pairs(self.m_editSelected) do
        if flag == true then
            table.insert(selectedAchievementIds, achievementId)
        end
    end
    return selectedAchievementIds
end

AchievementDepotCtrl._TryRecoverState = HL.Method(HL.Opt(HL.Any)) << function(self, recoverState)
    if recoverState == nil then
        return
    end
    self:_TryRecoverEditSelected(recoverState.selectedAchievementIds)
    self:_TryRecoverFilterState(recoverState)
    self:_TryRecoverSelectIndex(recoverState)
end

AchievementDepotCtrl._TryRecoverEditSelected = HL.Method(HL.Opt(HL.Any)) << function(self, selectedAchievementIds)
    if selectedAchievementIds == nil then
        return
    end
    self.m_editSelected = {}
    self.m_selectCount = 0
    for _, achievementId in ipairs(selectedAchievementIds) do
        if not string.isEmpty(achievementId) and self.m_editSelected[achievementId] == nil then
            self.m_editSelected[achievementId] = true
            self.m_selectCount = self.m_selectCount + 1
        end
    end
    self:_UpdateEditSelectCountInfo()
end

AchievementDepotCtrl._TryRecoverFilterState = HL.Method(HL.Any) << function(self, recoverState)
    self.m_searchKey = recoverState.searchKey or ''
    self.view.inputField.text = self.m_searchKey
    self.m_selectedFilterTags = lume.deepCopy(recoverState.selectedFilterTags or {})
    self.m_filterArgs.selectedTags = self.m_selectedFilterTags
    self:_LoadFilteredData()
end

AchievementDepotCtrl._TryRecoverSelectIndex = HL.Method(HL.Any) << function(self, recoverState)
    local categoryCount = #self.m_categoryFilteredData
    if categoryCount <= 0 then
        self:_ResetSelectIndex()
        return
    end
    self.m_selectCategoryIndex = math.min(math.max(recoverState.selectCategoryIndex or 1, 1), categoryCount)
    local categoryInfo = self.m_categoryFilteredData[self.m_selectCategoryIndex]
    local groupCount = categoryInfo ~= nil and #categoryInfo.filteredGroups or 0
    if groupCount <= 0 then
        self.m_selectGroupIndex = 1
        return
    end
    self.m_selectGroupIndex = math.min(math.max(recoverState.selectGroupIndex or 1, 1), groupCount)
end

AchievementDepotCtrl._ResetDepot = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = I18nUtils.GetText("ui_achv_edit_reset_choose_confirm"),
        onConfirm = function()
            self:_ResetEditSelect()
            self:_UpdateEditSelectCountInfo()
            self:_RefreshViews()
        end,
    })
end

AchievementDepotCtrl._SaveEditData = HL.Method() << function(self)
    if self.m_args ~= nil and self.m_args.onConfirm ~= nil then
        self.m_args.onConfirm(self.m_editSelected)
    end
    self:PlayAnimationOutAndClose()
end

HL.Commit(AchievementDepotCtrl)
