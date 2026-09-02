
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharExpandList

CharExpandListCtrl = HL.Class('CharExpandListCtrl', uiCtrl.UICtrl)





CharExpandListCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

CharExpandListCtrl.m_getCharHeadCell = HL.Field(HL.Function)

CharExpandListCtrl.m_charInfoList = HL.Field(HL.Table)

CharExpandListCtrl.m_onCharListChanged = HL.Field(HL.Function)

CharExpandListCtrl.m_charInfo = HL.Field(HL.Table)

CharExpandListCtrl.m_skipGraduallyShow = HL.Field(HL.Boolean) << false

CharExpandListCtrl.m_args = HL.Field(HL.Table)

CharExpandListCtrl.m_naviTargetInitialized = HL.Field(HL.Boolean) << false

CharExpandListCtrl.m_filteredCharList = HL.Field(HL.Table)

CharExpandListCtrl.m_filterTags = HL.Field(HL.Table)








CharExpandListCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_args = arg
    self.m_charInfo = self.m_args.charInfo
    self.m_charInfoList = self.m_args.charInfoList
    self.view.emptyCloseBtn.onClick:AddListener(function()
        self:Notify(MessageConst.CHAR_INFO_EMPTY_BUTTON_CLICK)
    end)

    self.m_getCharHeadCell = UIUtils.genCachedCellFunction(self.view.charHeadCell)

    local stateArg = self.m_args.stateArg
    local csSortIndex
    if stateArg and stateArg.sortSelectedIndex then
        csSortIndex = CSIndex(stateArg.sortSelectedIndex)
    end
    local isIncremental = false
    if stateArg and stateArg.sortIsIncremental ~= nil then
        isIncremental = stateArg.sortIsIncremental
    end
    if stateArg then
        self.m_filterTags = stateArg.filterTags
    end

    self:_InitFilterNode()
    self:_InitSortNode(isIncremental, csSortIndex)

    self.view.charScrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_UpdateCharScrollListCell(object, csIndex)
        
        
        
        
    end)
    self.view.charScrollList.onSelectedCell:AddListener(function(obj, csIndex)
        self:_OnClickCell(csIndex)
    end)
    self.view.charScrollList.getCurSelectedIndex = function()
        if self.m_charInfo then
            for k, info in ipairs(self.m_filteredCharList) do
                if info.templateId == self.m_charInfo.templateId then
                    return CSIndex(k)
                end
            end
        end
        return -1
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

CharExpandListCtrl.OnShow = HL.Override() << function(self)
    self.m_naviTargetInitialized = false
    self:RefreshCharExpandList(self.m_charInfo, self.m_charInfoList)
end



CharExpandListCtrl.RefreshCharExpandList = HL.Method(HL.Opt(HL.Table, HL.Table, HL.Boolean)) << function(self, charInfo, charInfoList, skipGraduallyShow)
    self.m_charInfo = charInfo
    self.m_charInfoList = charInfoList
    self.m_skipGraduallyShow = skipGraduallyShow or false
    self:_FilterCharList()
    self.view.sortNode:SortCurData()
end

CharExpandListCtrl._RefreshCharList = HL.Method() << function(self)
    self:_EnsureSelectedInFilteredList()
    if self.m_skipGraduallyShow then
        self.view.charScrollList:UpdateCount(#self.m_filteredCharList, false, false, false, self.m_skipGraduallyShow)
    else
        local fastScrollToIndex = -1
        if self.m_charInfo then
            for k, info in ipairs(self.m_filteredCharList) do
                if info.instId == self.m_charInfo.instId then
                    fastScrollToIndex = CSIndex(k)
                    break
                end
            end
        end
        if DeviceInfo.usingController then
            self.naviGroup:SetLayerSelectedTarget(nil, true)
            self.m_naviTargetInitialized = false
        end
        self.view.charScrollList:UpdateCount(#self.m_filteredCharList, fastScrollToIndex, false, false, self.m_skipGraduallyShow)
    end
    self.m_skipGraduallyShow = false
end

CharExpandListCtrl._EnsureSelectedInFilteredList = HL.Method() << function(self)
    if not self.m_charInfo or not self.m_filteredCharList or #self.m_filteredCharList == 0 then
        return
    end
    
    for _, info in ipairs(self.m_filteredCharList) do
        if info.instId == self.m_charInfo.instId then
            return
        end
    end
    
    local firstInfo = self.m_filteredCharList[1]
    self.m_charInfo = firstInfo
    if self.m_args.onClickCell then
        self.m_args.onClickCell(firstInfo)
    end
end

CharExpandListCtrl._OnSortChanged = HL.Method(HL.Table, HL.Boolean) << function(self, optData, isIncremental)
    if self.m_filteredCharList then
        local keys = isIncremental and optData.keys or optData.reverseKeys
        self:_SortData(keys, isIncremental)
    end
end

CharExpandListCtrl._SortData = HL.Method(HL.Table, HL.Boolean) << function(self, keys, isIncremental)
    if self.m_filteredCharList then
        table.sort(self.m_filteredCharList, Utils.genSortFunction(keys, isIncremental))
        table.sort(self.m_charInfoList, Utils.genSortFunction(keys, isIncremental))
        self:_RefreshCharList()
    end
end

CharExpandListCtrl._UpdateCharScrollListCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, csIndex)
    local info = self.m_filteredCharList[LuaIndex(csIndex)]
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(info.instId)
    local templateId = info.templateId
    local charCfg = Tables.characterTable[templateId]
    local cell = self.m_getCharHeadCell(object)

    cell:InitCharFormationHeadCell({
        instId = charInst.instId,
        level = charInst.level,
        ownTime = charInst.ownTime,
        rarity = charCfg.rarity,
        templateId = templateId,
        noHpBar = true,
        isSingleSelect = info.isSingleSelect,
        slotIndex = info.slotIndex,
    }, function()
        self:_OnClickCell(csIndex)
    end)
    cell:SetSingleModeSelected(true)
    cell.view.redDot:InitRedDot("CharInfo", charInst.instId)
    cell.view.tryoutTips.gameObject:SetActive(info.isShowTrail)
    cell.view.fixedTips.gameObject:SetActive(info.isShowFixed)

    if self.m_args.refreshAddon then
        self.m_args.refreshAddon(cell, info)
    end

    if DeviceInfo.usingController and not self.m_naviTargetInitialized and charInst.instId == self.m_charInfo.instId then
        self:SetNaviTarget(cell.view.button)
        self.m_naviTargetInitialized = true
    end
end

CharExpandListCtrl._OnClickCell = HL.Method(HL.Number) << function(self, csIndex)
    local info = self.m_filteredCharList[LuaIndex(csIndex)]
    if self.m_args.onClickCell then
        self.m_args.onClickCell(info)
    end
end

CharExpandListCtrl._InitSortNode = HL.Method(HL.Boolean, HL.Opt(HL.Number)) << function(self, isIncremental, csSortIndex)
    local sortOption = {
        {
            name = Language.LUA_CHAR_SORT_1, 
            
            
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "level", "rarity", "sortOrder", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "level", "rarity", "sortOrder", "templateId" },
        },
        {
            name = Language.LUA_CHAR_SORT_2, 
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "ownTime", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "ownTime", "templateId" },
        },
        {
            name = Language.LUA_CHAR_SORT_3, 
            keys = { "slotIndex", "replaceablePriorityReverse", "isNew", "rarity", "level", "sortOrder", "templateId" },
            reverseKeys = { "slotReverseIndex", "replaceablePriority", "isNewReverse", "rarity", "level", "sortOrder", "templateId" },
        },
    }

    self.view.sortNode:InitSortNode(sortOption, function(optData, isIncremental)
        self:_OnSortChanged(optData, isIncremental)
    end, csSortIndex, isIncremental, true, self.view.filterBtn)
end

CharExpandListCtrl._InitFilterNode = HL.Method() << function(self)
    local filterArgs = {
        tagGroups = FilterUtils.generateConfig_CHAR_FORMATION(),
        onConfirm = function(tags)
            self:_OnFilterConfirm(tags)
        end,
        selectedTags = self.m_filterTags,
        getResultCount = function(tags)
            return self:_FilterBtnGetResCount(tags)
        end,
        sortNodeWidget = self.view.sortNode,
    }
    self.view.filterBtn:InitFilterBtn(filterArgs)
end

CharExpandListCtrl._OnFilterConfirm = HL.Method(HL.Any) << function(self, tags)
    self.m_filterTags = tags
    self:_FilterCharList()
    self:_OnSortChanged(self.view.sortNode:GetCurSortData(), self.view.sortNode.isIncremental)
end

CharExpandListCtrl._GroupFilterTagsByFuncName = HL.Method(HL.Table).Return(HL.Table) << function(self, tags)
    local tagsByFuncName = {}
    for _, tag in ipairs(tags) do
        local list = tagsByFuncName[tag.funcName]
        if not list then
            list = {}
            tagsByFuncName[tag.funcName] = list
        end
        table.insert(list, tag)
    end
    return tagsByFuncName
end

CharExpandListCtrl._CheckCharPassFilterTags = HL.Method(HL.Any, HL.Table).Return(HL.Boolean) << function(self, templateId, tagsByFuncName)
    for funcName, tagList in pairs(tagsByFuncName) do
        local passOne = false
        for _, tag in ipairs(tagList) do
            if FilterUtils[funcName](templateId, tag.param) then
                passOne = true
                break
            end
        end
        if not passOne then
            return false
        end
    end
    return true
end

CharExpandListCtrl._FilterCharList = HL.Method() << function(self)
    if self.m_filterTags == nil then
        self.m_filteredCharList = self.m_charInfoList
    else
        self.m_filteredCharList = {}
        local tagsByFuncName = self:_GroupFilterTagsByFuncName(self.m_filterTags)
        for _, charInfo in ipairs(self.m_charInfoList) do
            if charInfo.slotIndex ~= nil and charInfo.slotIndex <= Const.BATTLE_SQUAD_MAX_CHAR_NUM then
                table.insert(self.m_filteredCharList, charInfo)
            elseif self:_CheckCharPassFilterTags(charInfo.templateId, tagsByFuncName) then
                table.insert(self.m_filteredCharList, charInfo)
            end
        end
    end
end

CharExpandListCtrl._FilterBtnGetResCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    if tags == nil or #tags == 0 then
        return 0
    end

    local tagsByFuncName = self:_GroupFilterTagsByFuncName(tags)
    local count = 0
    for _, charInfo in ipairs(self.m_charInfoList) do
        if charInfo.slotIndex ~= nil and charInfo.slotIndex <= Const.BATTLE_SQUAD_MAX_CHAR_NUM then
            count = count + 1
        elseif self:_CheckCharPassFilterTags(charInfo.templateId, tagsByFuncName) then
            count = count + 1
        end
    end
    return count
end

CharExpandListCtrl.GetCurStateArg = HL.Method().Return(HL.Table) << function(self)
    local arg = {}
    arg.sortSelectedIndex = self.view.sortNode:GetCurSelectedIndex()
    arg.sortIsIncremental = self.view.sortNode.isIncremental
    arg.filterTags = self.m_filterTags
    return arg
end

HL.Commit(CharExpandListCtrl)
