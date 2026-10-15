local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnKitchenCharSelection
local PHASE_ID = PhaseId.InnKitchenCharSelection


InnKitchenCharSelectionCtrl = HL.Class('InnKitchenCharSelectionCtrl', uiCtrl.UICtrl)


InnKitchenCharSelectionCtrl.m_kitchenId = HL.Field(HL.Number) << 0
InnKitchenCharSelectionCtrl.m_topicId = HL.Field(HL.String) << ""

InnKitchenCharSelectionCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)


InnKitchenCharSelectionCtrl.m_allCharIds = HL.Field(HL.Table)



InnKitchenCharSelectionCtrl.m_kitchenCharIds = HL.Field(HL.Table)



InnKitchenCharSelectionCtrl.m_savedKitchenCharIds = HL.Field(HL.Table)


InnKitchenCharSelectionCtrl.m_displayCharIds = HL.Field(HL.Table)


InnKitchenCharSelectionCtrl.m_selectedFilterTags = HL.Field(HL.Table)

InnKitchenCharSelectionCtrl.m_isIncremental = HL.Field(HL.Boolean) << false

InnKitchenCharSelectionCtrl.m_getCharCell = HL.Field(HL.Function)
InnKitchenCharSelectionCtrl.m_getBuffCell = HL.Field(HL.Function)
InnKitchenCharSelectionCtrl.m_kitchenSlotCache = HL.Field(HL.Forward('UIListCache'))

InnKitchenCharSelectionCtrl.m_categoryTagCache = HL.Field(HL.Forward('UIListCache'))
InnKitchenCharSelectionCtrl.m_affixTagCache = HL.Field(HL.Forward('UIListCache'))


InnKitchenCharSelectionCtrl.s_messages = HL.StaticField(HL.Table) << {
}


InnKitchenCharSelectionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_kitchenId = (arg and arg.kitchenId) or 0
    self.m_topicId = (arg and arg.topicId) or ""
    self.m_selectedFilterTags = {}
    self.m_displayCharIds = {}

    self:_BuildAllCharIds()
    self:_BuildLocalKitchenSettingsFromPending()

    local recoverState = arg and arg.recoverState or nil
    self:_TryRecoverState(recoverState)

    self:_InitTopNode()
    self:_InitCharList()
    self:_InitSortAndFilter(recoverState)
    self:_InitRightNode()
    self:_InitBottomNode()

    self:_RebuildDisplayList()
    self:_RefreshCharList()
    self:_RefreshHotTags()
    self:_RefreshRightSide()
    self:_RefreshBottom()

    self:_InitController()

    if arg then
        arg.recoverState = nil
    end
end




InnKitchenCharSelectionCtrl._BuildLocalKitchenSettingsFromPending = HL.Method() << function(self)
    local result = {}
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    local settings = pending and pending.kitchenSettings
    if settings and settings.Count and settings.Count > 0 then
        local idToStr = CS.Beyond.Cfg.Tables.charIdToStr
        for i = 0, settings.Count - 1 do
            local ks = settings[i]
            if ks and ks.id then
                local list = {}
                if ks.charIds then
                    for j = 0, ks.charIds.Count - 1 do
                        local numId = ks.charIds[j]
                        local hasStr, charStr = idToStr:TryGetValue(numId)
                        if hasStr and not string.isEmpty(charStr) then
                            list[#list + 1] = charStr
                        end
                    end
                end
                result[ks.id] = list
            end
        end
    end
    
    if not result[self.m_kitchenId] then
        result[self.m_kitchenId] = {}
    end
    
    self.m_savedKitchenCharIds = lume.deepCopy(result)
    self.m_kitchenCharIds = result
end


InnKitchenCharSelectionCtrl._BuildAllCharIds = HL.Method() << function(self)
    local jsspsiCharId = Tables.innManagementConst and Tables.innManagementConst.jsspsiCharId or ""
    local infoList = CharInfoUtils.getAllCharInfoList()
    local out = {}
    local seen = {}
    for _, item in ipairs(infoList) do
        local templateId = item.templateId
        if templateId and not seen[templateId]
            and not CS.Beyond.Gameplay.CharUtils.IsEndminTemplateId(templateId)
            and templateId ~= jsspsiCharId then
            seen[templateId] = true
            out[#out + 1] = templateId
        end
    end
    self.m_allCharIds = out
end





InnKitchenCharSelectionCtrl._FindCharAssign = HL.Method(HL.String).Return(HL.Opt(HL.Number, HL.Number)) << function(self, charId)
    local curList = self.m_kitchenCharIds[self.m_kitchenId]
    if curList then
        for i, cid in ipairs(curList) do
            if cid == charId then
                return self.m_kitchenId, i
            end
        end
    end
    for kid, list in pairs(self.m_kitchenCharIds) do
        if kid ~= self.m_kitchenId then
            for i, cid in ipairs(list) do
                if cid == charId then
                    return kid, i
                end
            end
        end
    end
    return nil, nil
end



InnKitchenCharSelectionCtrl._FindSavedCharAssign = HL.Method(HL.String).Return(HL.Opt(HL.Number, HL.Number)) << function(self, charId)
    if not self.m_savedKitchenCharIds then
        return nil, nil
    end
    for kid, list in pairs(self.m_savedKitchenCharIds) do
        for i, cid in ipairs(list) do
            if cid == charId then
                return kid, i
            end
        end
    end
    return nil, nil
end


InnKitchenCharSelectionCtrl._GetCurrentKitchenCount = HL.Method().Return(HL.Number) << function(self)
    local list = self.m_kitchenCharIds[self.m_kitchenId]
    return list and #list or 0
end






InnKitchenCharSelectionCtrl._GetCharHotTagCount = HL.Method(HL.String).Return(HL.Number) << function(self, charId)
    local skills = InnUtils.getCharInnSkills(charId)
    local n = 0
    for _, skill in ipairs(skills) do
        local _, tagId = InnUtils.classifyInnSkillTag(skill)
        if tagId and InnUtils.isItemTagTopicHot(self.m_topicId, tagId) then
            n = n + 1
        end
    end
    return n
end


InnKitchenCharSelectionCtrl._CharPassesFilter = HL.Method(HL.String).Return(HL.Boolean) << function(self, charId)
    return FilterUtils.checkIfPassFilter(charId, self.m_selectedFilterTags)
end







InnKitchenCharSelectionCtrl._RebuildDisplayList = HL.Method() << function(self)
    local infos = {}
    for _, charId in ipairs(self.m_allCharIds) do
        local kid, slotIdx = self:_FindCharAssign(charId)
        local isCurrentKitchen = kid == self.m_kitchenId
        local isOtherKitchen = (kid ~= nil) and not isCurrentKitchen
        local passFilter = isCurrentKitchen or self:_CharPassesFilter(charId)
        if passFilter then
            
            local tier = isCurrentKitchen and 0 or (isOtherKitchen and 2 or 1)
            local charCfg = Tables.characterTable:GetValue(charId)
            infos[#infos + 1] = {
                charId = charId,
                slotIndex = slotIdx,
                tier = tier,
                hotTagCount = self:_GetCharHotTagCount(charId),
                sortOrder = charCfg and charCfg.sortOrder or 0,
            }
        end
    end

    
    table.sort(infos, function(a, b)
        if a.tier ~= b.tier then
            return a.tier < b.tier
        end
        if a.tier == 0 then
            local ai = a.slotIndex or 0
            local bi = b.slotIndex or 0
            if ai ~= bi then
                return ai < bi
            end
        elseif a.hotTagCount ~= b.hotTagCount then
            return a.hotTagCount > b.hotTagCount
        end
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        return a.charId < b.charId
    end)

    
    local ordered = {}
    local freeStart, freeEnd = nil, nil
    for i, info in ipairs(infos) do
        ordered[i] = info.charId
        if info.tier == 1 then
            freeStart = freeStart or i
            freeEnd = i
        end
    end

    
    if self.m_isIncremental and freeStart and freeEnd then
        local left, right = freeStart, freeEnd
        while left < right do
            ordered[left], ordered[right] = ordered[right], ordered[left]
            left = left + 1
            right = right - 1
        end
    end

    self.m_displayCharIds = ordered
end





InnKitchenCharSelectionCtrl._InitTopNode = HL.Method() << function(self)
    self.view.topNode.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    local titleKey = string.format("LUA_INN_KITCHEN_NAME_%d", self.m_kitchenId)
    self.view.topNode.titleTxt.text = Language[titleKey] or ""
end

InnKitchenCharSelectionCtrl._InitCharList = HL.Method() << function(self)
    self.m_getCharCell = UIUtils.genCachedCellFunction(self.view.charListNode.charScrollList)
    self.view.charListNode.charScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCharCell(self.m_getCharCell(obj), LuaIndex(csIndex))
    end)
end

InnKitchenCharSelectionCtrl._InitSortAndFilter = HL.Method(HL.Opt(HL.Table)) << function(self, recoverState)
    
    local sortOptions = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            sortMode = 1,
        },
    }

    local sortSelectedCsIndex = 0
    if recoverState and type(recoverState.sortSelectedIndex) == "number" then
        sortSelectedCsIndex = CSIndex(math.max(1, math.min(recoverState.sortSelectedIndex, #sortOptions)))
    end
    self.view.charListNode.sortNode:InitSortNode(sortOptions, function(_optData, isIncremental)
        self.m_isIncremental = isIncremental
        self:_RebuildDisplayList()
        self:_RefreshCharList()
    end, sortSelectedCsIndex, self.m_isIncremental, true, self.view.charListNode.filterBtn)

    
    
    
    self.view.charListNode.filterBtn:InitFilterBtn({
        tagGroups = FilterUtils.generateConfig_INN_KITCHEN_CHAR(),
        selectedTags = self.m_selectedFilterTags or {},
        onConfirm = function(selectedTags)
            self.m_selectedFilterTags = selectedTags or {}
            self:_RebuildDisplayList()
            self:_RefreshCharList()
        end,
        getResultCount = function(selectedTags)
            local oldSelected = self.m_selectedFilterTags
            self.m_selectedFilterTags = selectedTags or {}
            local cnt = 0
            for _, charId in ipairs(self.m_allCharIds) do
                local kid = self:_FindCharAssign(charId)
                local isCurrentKitchen = kid == self.m_kitchenId
                if isCurrentKitchen or self:_CharPassesFilter(charId) then
                    cnt = cnt + 1
                end
            end
            self.m_selectedFilterTags = oldSelected
            return cnt
        end,
        sortNodeWidget = self.view.charListNode.sortNode,
    })
end

InnKitchenCharSelectionCtrl._InitRightNode = HL.Method() << function(self)
    self.m_kitchenSlotCache = UIUtils.genCellCache(self.view.rightNode.kitchenCell)

    self.m_getBuffCell = UIUtils.genCachedCellFunction(self.view.rightNode.buffScrollList)
    self.view.rightNode.buffScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateBuffCell(self.m_getBuffCell(obj), LuaIndex(csIndex))
    end)
end

InnKitchenCharSelectionCtrl._InitBottomNode = HL.Method() << function(self)
    self.view.bottomNode.resetBtn.onClick:AddListener(function()
        self:_OnResetClicked()
    end)
    self.view.bottomNode.btnSave.onClick:AddListener(function()
        self:_OnSaveClicked()
    end)
end





InnKitchenCharSelectionCtrl._RefreshCharList = HL.Method() << function(self)
    local hasAny = self.m_displayCharIds and #self.m_displayCharIds > 0
    
    self.view.charListNode.charListEmptyNode.gameObject:SetActive(not hasAny)
    self.view.charListNode.charScrollList:UpdateCount(hasAny and #self.m_displayCharIds or 0)
end

InnKitchenCharSelectionCtrl._OnUpdateCharCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    if not cell then
        return
    end
    local charId = self.m_displayCharIds[luaIndex]
    if not charId then
        return
    end
    
    
    local selKid, slotIdx = self:_FindCharAssign(charId)
    local selectedIndex = (selKid == self.m_kitchenId) and slotIdx or nil
    local savedKid = self:_FindSavedCharAssign(charId)
    local isCurrentKitchen = savedKid == self.m_kitchenId
    cell:InitInnCharHeadCell({
        charId = charId,
        selectedIndex = selectedIndex,
        kitchenId = savedKid,
        isCurrentKitchen = isCurrentKitchen,
        onClick = function()
            self:_OnCharClicked(charId)
        end,
        onTipsClick = function()
            Notify(MessageConst.OPEN_INN_CHAR_TIPS, {
                charId = charId,
                kitchenId = savedKid,
                isCurrentKitchen = isCurrentKitchen,
                transform = self.view.charListNode.rectTransform,
                posType = UIConst.UI_TIPS_POS_TYPE.RightTop,
            })
        end,
    })
    if DeviceInfo.usingController then
        local isSelected = selectedIndex ~= nil
        InputManagerInst:SetBindingText(cell.view.button.hoverConfirmBindingId, 
            isSelected and Language.key_hint_kitchen_char_unselect or Language.key_hint_kitchen_char_select)
        InputManagerInst:ToggleGroup(cell.view.infoButton.groupId, false)
        cell.view.button.onIsNaviTargetChanged = function(isTarget)
            InputManagerInst:ToggleGroup(cell.view.infoButton.groupId, isTarget)
        end
    end
end





InnKitchenCharSelectionCtrl._OnCharClicked = HL.Method(HL.String) << function(self, charId)
    local kid, _slotIdx = self:_FindCharAssign(charId)
    if kid == self.m_kitchenId then
        
        self:_RemoveCharFromKitchen(charId, kid)
    else
        
        local curList = self.m_kitchenCharIds[self.m_kitchenId]
        if not curList then
            curList = {}
            self.m_kitchenCharIds[self.m_kitchenId] = curList
        end
        local unlockedSlots = self.m_innSystem.kitchenCharSlotNum or 0
        if #curList >= unlockedSlots then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_KITCHEN_CHAR_SELECT_FULL_TOAST)
            return
        end
        
        curList[#curList + 1] = charId
    end

    
    self:_RefreshVisibleCharCells()
    self:_RefreshRightSide()
    self:_RefreshBottom()
end


InnKitchenCharSelectionCtrl._RemoveCharFromKitchen = HL.Method(HL.String, HL.Number) << function(self, charId, kitchenId)
    local list = self.m_kitchenCharIds[kitchenId]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == charId then
            table.remove(list, i)
        end
    end
end


InnKitchenCharSelectionCtrl._RefreshVisibleCharCells = HL.Method() << function(self)
    if not self.m_getCharCell then
        return
    end
    local list = self.view.charListNode.charScrollList
    local count = #self.m_displayCharIds
    for i = 1, count do
        local obj = list:Get(CSIndex(i))
        if obj then
            local cell = self.m_getCharCell(obj)
            if cell then
                self:_OnUpdateCharCell(cell, i)
            end
        end
    end
end






InnKitchenCharSelectionCtrl._GetTopicHotTagLists = HL.Method().Return(HL.Table, HL.Table) << function(self)
    local function csListToTable(csList)
        local out = {}
        if csList then
            for i = 0, csList.Count - 1 do
                local tagId = csList[i]
                if tagId and not string.isEmpty(tagId) then
                    out[#out + 1] = tagId
                end
            end
        end
        return out
    end

    if not self.m_innSystem then
        return {}, {}
    end
    if string.isEmpty(self.m_topicId) then
        return csListToTable(self.m_innSystem.dailyCategoryIds), csListToTable(self.m_innSystem.dailyAffixIds)
    end
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(self.m_topicId)
    if not hasTopic or not topicData then
        return {}, {}
    end
    if topicData.topicType == GEnums.InnTopicType.PrivateChef then
        return csListToTable(self.m_innSystem.privateChefDailyCategoryIds), csListToTable(self.m_innSystem.privateChefDailyAffixIds)
    end
    return csListToTable(topicData.hotCategory), csListToTable(topicData.hotAffix)
end


InnKitchenCharSelectionCtrl._RefreshHotTags = HL.Method() << function(self)
    self.m_categoryTagCache = UIUtils.genCellCache(self.view.categoryTag)
    self.m_affixTagCache = UIUtils.genCellCache(self.view.affixTag)

    local catTagIds, affTagIds = self:_GetTopicHotTagLists()

    self.view.hotCategoryNode:SetState(#catTagIds > 0 and "Label" or "None")
    self.m_categoryTagCache:Refresh(#catTagIds, function(cell, index)
        cell:InitInnItemTag({
            tagId = catTagIds[index],
            isHot = false,
            upCount = 0,
        })
    end)

    self.view.hotAffixNode.gameObject:SetActiveIfNecessary(#affTagIds > 0)
    self.m_affixTagCache:Refresh(#affTagIds, function(cell, index)
        cell:InitInnItemTag({
            tagId = affTagIds[index],
            isHot = false,
            upCount = 0,
        })
    end)
end





InnKitchenCharSelectionCtrl._RefreshRightSide = HL.Method() << function(self)
    self:_RefreshKitchenSlots()
    self:_RefreshBuffList()
end

InnKitchenCharSelectionCtrl._RefreshKitchenSlots = HL.Method() << function(self)
    local maxSlot = self.m_innSystem.kitchenCharSlotMaxNum or 0
    local unlocked = self.m_innSystem.kitchenCharSlotNum or 0
    local curList = self.m_kitchenCharIds[self.m_kitchenId] or {}

    self.m_kitchenSlotCache:Refresh(maxSlot, function(cell, index)
        if not cell or not cell.stateController then
            return
        end
        cell.gameObject.name = "KitchenSlot" .. index
        local stateName
        local charId
        if index > unlocked then
            stateName = "Locked"
            local unlockLevel = 0
            for _, expData in pairs(Tables.innExpansionTable) do
                if expData.addKitchenCharNum > 0 then
                    unlockLevel = expData.unlockLevel
                end
            end
            cell.lockTxt.text = string.format(Language.LUA_INN_KITCHEN_SETTINGS_LOCK, unlockLevel)
        elseif curList[index] and not string.isEmpty(curList[index]) then
            stateName = "Selected"
            charId = curList[index]
        else
            stateName = "Empty"
        end
        cell.stateController:SetState(stateName)

        if cell.delBtn then
            cell.delBtn.onClick:RemoveAllListeners()
            if charId then
                cell.delBtn.onClick:AddListener(function()
                    self:_RemoveCharFromKitchen(charId, self.m_kitchenId)
                    self:_RefreshVisibleCharCells()
                    self:_RefreshRightSide()
                    self:_RefreshBottom()
                end)
            end
        end

        local isSelected = stateName == "Selected"
        cell.naviTarget.enabled = isSelected

        
        
        if cell.tipNode then
            local savedKid = charId and self:_FindSavedCharAssign(charId) or nil
            local isInOtherKitchen = savedKid ~= nil and savedKid ~= self.m_kitchenId
            cell.tipNode.gameObject:SetActive(isInOtherKitchen)
            if isInOtherKitchen and cell.roomName then
                cell.roomName.text = Language['LUA_INN_KITCHEN_NAME_' .. savedKid] or ""
            end
        end

        if not isSelected then
            return
        end

        
        local headCell = cell.kitchenCharCell
        if headCell then
            if headCell.charImg then
                local spriteName = UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. charId
                headCell.charImg:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, spriteName)
            end
            if headCell.nameTxt then
                local hasTag, tagData = Tables.characterTagTable:TryGetValue(charId)
                headCell.nameTxt.text = (hasTag and tagData and tagData.innNickname) or ""
            end
            if headCell.stateController then
                headCell.stateController:SetState("Char")
            end
        end
        if cell.titleTxt then
            local hasTag, tagData = Tables.characterTagTable:TryGetValue(charId)
            cell.titleTxt.text = (hasTag and tagData and tagData.innNickname) or ""
        end

        
        cell._categoryTagCache = cell._categoryTagCache or UIUtils.genCellCache(cell.innItemTagCategory)
        cell._affixTagCache = cell._affixTagCache or UIUtils.genCellCache(cell.innItemTagAffix)

        local catArgs, affArgs = self:_BuildCharTagArgs(charId)
        cell._categoryTagCache:Refresh(#catArgs, function(tagCell, tagIndex)
            tagCell:InitInnItemTag(catArgs[tagIndex])
        end)
        cell._affixTagCache:Refresh(#affArgs, function(tagCell, tagIndex)
            tagCell:InitInnItemTag(affArgs[tagIndex])
        end)
    end)

    local hasAny = #curList > 0
    if self.view.rightNode.charNodeNaviGroup.IsTopLayer then
        if hasAny then
            self:SetNaviTarget(self.m_kitchenSlotCache:Get(1).naviTarget)
        else
            self.view.rightNode.charNodeNaviGroup:ManuallyStopFocus()
        end
    end
    InputManagerInst:ToggleBinding(self.view.rightNode.charNodeNaviGroup.FocusBindingId, hasAny)
     self.view.rightNode.controllerFocusHintNode.gameObject:SetActiveIfNecessary(hasAny)
end



InnKitchenCharSelectionCtrl._BuildCharTagArgs = HL.Method(HL.String).Return(HL.Table, HL.Table) << function(self, charId)
    local catArgs, affArgs = {}, {}
    local argsByTagId = {}
    local skills = InnUtils.getCharInnSkills(charId)
    for _, skill in ipairs(skills) do
        local side, tagId = InnUtils.classifyInnSkillTag(skill)
        if tagId then
            local args = argsByTagId[tagId]
            if args then
                args.upCount = args.upCount + 1
            else
                args = {
                    tagId = tagId,
                    isHot = InnUtils.isItemTagTopicHot(self.m_topicId, tagId),
                    upCount = 1,
                }
                if side == "category" then
                    catArgs[#catArgs + 1] = args
                    argsByTagId[tagId] = args
                elseif side == "affix" then
                    affArgs[#affArgs + 1] = args
                    argsByTagId[tagId] = args
                end
            end
        end
    end
    return catArgs, affArgs
end

InnKitchenCharSelectionCtrl._BuildBuffRows = HL.Method().Return(HL.Table) << function(self)
    local curList = self.m_kitchenCharIds[self.m_kitchenId] or {}
    local catRows, affRows = InnUtils.buildSkillTagRowsFromCharIds(curList, self.m_topicId)
    return lume.concat(catRows, affRows)
end

InnKitchenCharSelectionCtrl._RefreshBuffList = HL.Method() << function(self)
    local rows = self:_BuildBuffRows()
    self.m_buffRows = rows
    local curList = self.m_kitchenCharIds[self.m_kitchenId] or {}
    self.m_tagDetailTextMap = InnUtils.collectInnSkillDetailTextByTagFromCharIds(curList)
    local hasAny = #rows > 0
    self.view.rightNode.emptBuffNode.gameObject:SetActive(not hasAny)
    self.view.rightNode.buffScrollList:UpdateCount(#rows)
end

InnKitchenCharSelectionCtrl.m_buffRows = HL.Field(HL.Table)


InnKitchenCharSelectionCtrl.m_tagDetailTextMap = HL.Field(HL.Table)

InnKitchenCharSelectionCtrl._OnUpdateBuffCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    if not cell or not self.m_buffRows then
        return
    end
    local row = self.m_buffRows[luaIndex]
    if not row then
        return
    end
    if cell.innItemTagBig and cell.innItemTagBig.InitInnItemTag then
        cell.innItemTagBig:InitInnItemTag(row.args)
    end
    if cell.detailsTxt then
        cell.detailsTxt.text = (self.m_tagDetailTextMap and self.m_tagDetailTextMap[row.tagId]) or ""
    end
    if cell.stateController then
        
        local bg = (luaIndex % 2 == 1) and "Bg1" or "Bg2"
        cell.stateController:SetState(bg)
    end
end





InnKitchenCharSelectionCtrl._RefreshBottom = HL.Method() << function(self)
    local unlocked = self.m_innSystem.kitchenCharSlotNum or 0
    local cur = self:_GetCurrentKitchenCount()
    if self.view.bottomNode.countTxt then
        self.view.bottomNode.countTxt.text = string.format("%d/%d", cur, unlocked)
    end
    if self.view.bottomNode.lvDotNode and self.view.bottomNode.lvDotNode.InitLvDotNode then
        self.view.bottomNode.lvDotNode:InitLvDotNode(cur, unlocked)
    end
end

InnKitchenCharSelectionCtrl._OnResetClicked = HL.Method() << function(self)
    self.m_kitchenCharIds[self.m_kitchenId] = {}
    self:_RefreshVisibleCharCells()
    self:_RefreshRightSide()
    self:_RefreshBottom()
end


InnKitchenCharSelectionCtrl._OnSaveClicked = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if not pending or not pending.kitchenSettings then
        return
    end
    local kitchenSettings = pending.kitchenSettings
    local idToNum = CS.Beyond.Cfg.Tables.charIdToNum

    
    
    local curList = self.m_kitchenCharIds[self.m_kitchenId]
    if curList then
        local inCurrent = {}
        for _, cid in ipairs(curList) do
            inCurrent[cid] = true
        end
        for kid, list in pairs(self.m_kitchenCharIds) do
            if kid ~= self.m_kitchenId then
                for i = #list, 1, -1 do
                    if inCurrent[list[i]] then
                        table.remove(list, i)
                    end
                end
            end
        end
    end

    
    
    local existingOrder = {}
    local seen = {}
    for i = 0, kitchenSettings.Count - 1 do
        local ks = kitchenSettings[i]
        if ks and ks.id and not seen[ks.id] then
            existingOrder[#existingOrder + 1] = ks.id
            seen[ks.id] = true
        end
    end
    for kid, _ in pairs(self.m_kitchenCharIds) do
        if kid and not seen[kid] then
            existingOrder[#existingOrder + 1] = kid
            seen[kid] = true
        end
    end

    kitchenSettings:Clear()
    for _, kid in ipairs(existingOrder) do
        local list = self.m_kitchenCharIds[kid] or {}
        local ks = CS.Beyond.Gameplay.InnSystem.KitchenSetting()
        ks.id = kid
        for _, charIdStr in ipairs(list) do
            if not string.isEmpty(charIdStr) then
                local hasNum, numId = idToNum:TryGetValue(charIdStr)
                if hasNum then
                    ks.charIds:Add(numId)
                end
            end
        end
        kitchenSettings:Add(ks)
    end

    Notify(MessageConst.ON_INN_KITCHEN_CHAR_SELECTION_SAVED, self.m_kitchenId)
    PhaseManager:PopPhase(PHASE_ID)
end





InnKitchenCharSelectionCtrl._TryRecoverState = HL.Method(HL.Opt(HL.Table)) << function(self, recoverState)
    if not recoverState then
        return
    end

    if recoverState.filterTags then
        self.m_selectedFilterTags = lume.deepCopy(recoverState.filterTags)
    end

    if recoverState.sortIsIncremental ~= nil then
        self.m_isIncremental = recoverState.sortIsIncremental == true
    end

    if recoverState.curKitchenCharIds then
        local valid = {}
        for _, charId in ipairs(self.m_allCharIds) do
            valid[charId] = true
        end
        local restored = {}
        for _, charId in ipairs(recoverState.curKitchenCharIds) do
            if valid[charId] then
                restored[#restored + 1] = charId
            end
        end
        self.m_kitchenCharIds[self.m_kitchenId] = restored
    end
end

InnKitchenCharSelectionCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local curList = self.m_kitchenCharIds and self.m_kitchenCharIds[self.m_kitchenId] or {}
    return {
        kitchenId = self.m_kitchenId,
        topicId = self.m_topicId,
        recoverState = {
            curKitchenCharIds = lume.clone(curList),
            sortSelectedIndex = self.view.charListNode.sortNode:GetCurSelectedIndex(),
            sortIsIncremental = self.m_isIncremental,
            filterTags = lume.deepCopy(self.m_selectedFilterTags or {}),
        },
    }
end





InnKitchenCharSelectionCtrl._InitController = HL.Method() << function(self)
    self.view.rightNode.charNodeNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.view.rightNode.controllerFocusHintNode.gameObject:SetActiveIfNecessary(not isFocused)
    end)
    self:_SetFirstCharNaviTarget()
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnKitchenCharSelectionCtrl._SetFirstCharNaviTarget = HL.Method() << function(self)
    local firstCharObj = self.view.charListNode.charScrollList:Get(CSIndex(1))
    if firstCharObj then
        self:SetNaviTarget(self.m_getCharCell(firstCharObj).view.button)
    end
end



HL.Commit(InnKitchenCharSelectionCtrl)
