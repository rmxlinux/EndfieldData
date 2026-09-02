
































local LayoutUtility = CS.UnityEngine.UI.LayoutUtility
local TAB_TOGGLE_KEYS = { "tabPerson", "tabSkill", "tabWeapon", "tabMatrix" }
local TAB_TOGGLE_STATE_KEYS = { "tabPersonState", "tabSkillState", "tabWeaponState", "tabMatrixState" }
local GROWTH_TAB_LABEL_LANG = {
    "LUA_FORESIGHT_GROWTH_TAB_OPERATOR",
    "LUA_FORESIGHT_GROWTH_TAB_SKILL",
    "LUA_FORESIGHT_GROWTH_TAB_WEAPON",
    "LUA_FORESIGHT_GROWTH_TAB_MATRIX",
}

local GROWTH_TAB_KEYS = { "operator", "skill", "weapon", "matrix" }


local GROWTH_CELL_NAMES = {
    Char = "CharCell",
    CharSkill = "CharSkillCell",
    Weapon = "WeaponCell",
    Gem = "GemCell",
    WeaponItem = "WeaponItemCell",
    GemItem = "GemItemCell",
}
local GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER = {
    GROWTH_CELL_NAMES.Char,
    GROWTH_CELL_NAMES.CharSkill,
    GROWTH_CELL_NAMES.Weapon,
    GROWTH_CELL_NAMES.Gem,
    GROWTH_CELL_NAMES.WeaponItem,
    GROWTH_CELL_NAMES.GemItem,
}
local GROWTH_CELL_PREFAB_PATHS = {
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailCharCell.prefab",
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailCharSkillCell.prefab",
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailWeaponCell.prefab",
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailGemCell.prefab",
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailWeaponItemCell.prefab",
    "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailGemItemCell.prefab",
}
local GROWTH_SCROLL_ROW_DISPLAY = {
    Material = "material",
    Header = "header",
    WeaponRecommend = "weaponRecommend",
    GemItem = "gemItem",
}

local OperatorCells = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthOperatorCells')
local WeaponCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailWeaponCell')
local WeaponItemCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailWeaponItemCell')
local GemCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailGemCell')
local GemItemCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailGemItemCell')
local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')

local Vector2 = CS.UnityEngine.Vector2
local RectTransformType = typeof(CS.UnityEngine.RectTransform)
local UIScrollRectType = typeof(CS.Beyond.UI.UIScrollRect)
local ScrollRectMovementType = CS.UnityEngine.UI.ScrollRect.MovementType
local LayoutRebuilder = CS.UnityEngine.UI.LayoutRebuilder



local function ensureLuaReferenceRootRef(go)
    if not go or IsNull(go) then
        return
    end
    local luaRef = go:GetComponent(typeof(CS.Beyond.Lua.LuaReference))
    if luaRef and not luaRef.isRootRef then
        luaRef.isRootRef = true
    end
end

local function wrapGrowthWeaponItemCell(item)
    if item and item.gameObject then
        ensureLuaReferenceRootRef(item.gameObject)
    end
    return Utils.wrapLuaNode(item)
end

ForesightCharGrowthDetailCtrl = HL.Class('ForesightCharGrowthDetailCtrl')
ForesightCharGrowthDetailCtrl.m_phase = HL.Field(HL.Forward('PhaseForesightCharGrowth'))
ForesightCharGrowthDetailCtrl.m_view = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_selectedInfo = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_displayTemplateId = HL.Field(HL.String) << ""
ForesightCharGrowthDetailCtrl.m_stageIdList = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_curTabIndex = HL.Field(HL.Number) << 1
ForesightCharGrowthDetailCtrl.m_prevTabIndex = HL.Field(HL.Number) << 0
ForesightCharGrowthDetailCtrl.m_isRefreshingGoal = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_getIsCharListFocused = HL.Field(HL.Function)
ForesightCharGrowthDetailCtrl.m_refreshControllerHints = HL.Field(HL.Function)
ForesightCharGrowthDetailCtrl.m_isPanelActive = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_cultivateUiCallbackDepth = HL.Field(HL.Number) << 0
ForesightCharGrowthDetailCtrl.m_pendingPlanRefresh = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_pendingPinRefresh = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_getRewardCell = HL.Field(HL.Function)
ForesightCharGrowthDetailCtrl.m_operatorRows = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_watchedItemIdMap = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_operatorGoalReached = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_operatorStageMax = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_growthScrollInited = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_growthScrollCountListenerWired = HL.Field(HL.Boolean) << false
ForesightCharGrowthDetailCtrl.m_loadGameObject = HL.Field(HL.Function)
ForesightCharGrowthDetailCtrl.m_headerTemplateHolderGo = HL.Field(HL.Userdata)
ForesightCharGrowthDetailCtrl.m_growthHeaderTemplateWraps = HL.Field(HL.Table) << function() return {} end
ForesightCharGrowthDetailCtrl.m_charCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailCharCell'))
ForesightCharGrowthDetailCtrl.m_skillCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailSkillCell'))
ForesightCharGrowthDetailCtrl.m_weaponCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailWeaponCell'))
ForesightCharGrowthDetailCtrl.m_weaponItemCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailWeaponItemCell'))
ForesightCharGrowthDetailCtrl.m_gemCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailGemCell'))
ForesightCharGrowthDetailCtrl.m_gemItemCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailGemItemCell'))
ForesightCharGrowthDetailCtrl.m_weaponRecommendEntries = HL.Field(HL.Table) << function() return {} end
ForesightCharGrowthDetailCtrl.m_rewardsCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailRewardsCell'))
ForesightCharGrowthDetailCtrl.m_weaponRecommendViewByChar = HL.Field(HL.Table) << function() return {} end

ForesightCharGrowthDetailCtrl.m_pendingGrowthScrollLuaIndex = HL.Field(HL.Number) << 0
ForesightCharGrowthDetailCtrl.m_curTabBundle = HL.Field(HL.Table)
ForesightCharGrowthDetailCtrl.m_weaponTabSections = HL.Field(HL.Table) << function() return {} end
ForesightCharGrowthDetailCtrl.m_gemTabSections = HL.Field(HL.Table) << function() return {} end
ForesightCharGrowthDetailCtrl.m_growthScrollRowMeta = HL.Field(HL.Table) << function() return {} end
ForesightCharGrowthDetailCtrl.m_scrollHeaderRowHeights = HL.Field(HL.Table) << function() return {} end

ForesightCharGrowthDetailCtrl.m_getNaviLeftTarget = HL.Field(HL.Function)
ForesightCharGrowthDetailCtrl.m_setNaviTarget = HL.Field(HL.Function)



ForesightCharGrowthDetailCtrl.ForesightCharGrowthDetailCtrl = HL.Constructor(
    HL.Forward('PhaseForesightCharGrowth'), HL.Opt(HL.Table))
    << function(self, phase, view)
    self.m_phase = phase
    self.m_view = view
    self.m_stageIdList = {}
    self.m_operatorRows = {}
end

ForesightCharGrowthDetailCtrl.Init = HL.Method() << function(self)
    self:_InitGrowthTabs()
    self:_InitDetailPinBtn()
    self:_InitGoalSelecter()
    self:_InitGrowthContentScroll()
end

ForesightCharGrowthDetailCtrl.OnShow = HL.Method() << function(self)
    MessageManager:UnregisterAll(self)
    MessageManager:Register(MessageConst.ON_CHAR_CULTIVATE_PLAN_CHANGED, function()
        self:_OnCharCultivatePlanChanged()
    end, self)
    MessageManager:Register(MessageConst.ON_CHAR_CULTIVATE_PRIORITY_CHANGED, function()
        self:_OnCharCultivatePriorityChanged()
    end, self)
    for _, msg in ipairs({
        MessageConst.ON_GEM_ATTACH,
        MessageConst.ON_GEM_DETACH,
        MessageConst.ON_GEM_ENHANCE,
    }) do
        MessageManager:Register(msg, function()
            self:_OnGemInventoryChanged()
        end, self)
    end
    MessageManager:Register(MessageConst.ON_WEAPON_GEM_WISH_LIST_CHANGED, function()
        if not self.m_isPanelActive or self.m_curTabIndex ~= 4 then return end
        for sectionIndex = 1, #self.m_gemTabSections do
            self:_RefreshGemHeaderRowAtSection(sectionIndex)
        end
    end, self)
    MessageManager:Register(MessageConst.ON_ITEM_COUNT_CHANGED, function(args)
        local map = self.m_watchedItemIdMap
        if not self.m_isPanelActive or not map or not next(map) then return end
        local changed, hit = unpack(args), false
        for itemId, _ in pairs(changed or {}) do
            if map[itemId] then hit = true break end
        end
        if not hit then return end
        local restoreIndex = 0
        local focused = self:_GetFocusedScrollRowCell()
        if focused and (focused._growthScrollLuaIndex or 0) > 0 then
            restoreIndex = focused._growthScrollLuaIndex
        elseif not self.m_getIsCharListFocused() then
            local selectedCs = self.m_view.contentScrollList and self.m_view.contentScrollList.curSelectedIndex
            if selectedCs and selectedCs >= 0 then
                restoreIndex = LuaIndex(selectedCs)
            end
        end
        if restoreIndex > 0 then
            self.m_pendingGrowthScrollLuaIndex = restoreIndex
        end
        self:_RefreshGrowthTabByIndex(self.m_curTabIndex)
        if DeviceInfo.usingController and restoreIndex > 0 then
            self.m_pendingGrowthScrollLuaIndex = restoreIndex
            self:_TryApplyPendingGrowthScrollNavi()
        end
    end, self)
    
    if DeviceInfo.usingController then
        self.m_refreshControllerHints()
    end
end

ForesightCharGrowthDetailCtrl.OnClose = HL.Method() << function(self)
    if self.m_rewardsCellHelper then
        self.m_rewardsCellHelper:HideCommonTipsIfVisible()
    end
    MessageManager:UnregisterAll(self)
    self.m_selectedInfo = nil
    self.m_displayTemplateId = ""
    self.m_isPanelActive = false
    self.m_cultivateUiCallbackDepth = 0
    self.m_pendingPlanRefresh = false
    self.m_pendingPinRefresh = false
    self.m_operatorRows = {}
    self.m_watchedItemIdMap = nil
end





ForesightCharGrowthDetailCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    local state = {
        growthTabIndex = self.m_curTabIndex,
    }
    local templateId = self.m_selectedInfo and self.m_selectedInfo.templateId
    if templateId and self.m_weaponRecommendViewByChar[templateId] ~= nil then
        state.weaponRecommendView = self.m_weaponRecommendViewByChar[templateId] == true
    end
    local focusedRow = self:_GetFocusedScrollRowCell()
    if focusedRow and focusedRow._growthScrollLuaIndex and focusedRow._growthScrollLuaIndex > 0 then
        state.growthScrollLuaIndex = focusedRow._growthScrollLuaIndex
        state.growthListFocused = true
    end
    return state
end

ForesightCharGrowthDetailCtrl._ApplyRecoverSettingsFromArg = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, charInfo, arg)
    if not arg then
        return
    end
    local templateId = charInfo and charInfo.templateId
    if templateId and arg.weaponRecommendView ~= nil then
        self.m_weaponRecommendViewByChar[templateId] = arg.weaponRecommendView == true
    end
end





ForesightCharGrowthDetailCtrl.SetPanelActive = HL.Method(HL.Boolean) << function(self, active)
    self.m_isPanelActive = active == true
    if not self.m_isPanelActive then
        self.m_pendingPlanRefresh = false
        self.m_pendingPinRefresh = false
    end
    if DeviceInfo.usingController then
        self.m_refreshControllerHints()
    end
end

ForesightCharGrowthDetailCtrl.Refresh = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, charInfo, arg)
    self:_ApplyRecoverSettingsFromArg(charInfo, arg)
    if not charInfo or not charInfo.templateId or not self.m_view or not self.m_view.headIcon then
        return
    end
    self.m_selectedInfo = charInfo
    self.m_displayTemplateId = charInfo.templateId
    self:_RefreshCharInfoBlock(charInfo)
    if DeviceInfo.usingController and arg and arg.growthListFocused
        and arg.growthScrollLuaIndex and arg.growthScrollLuaIndex > 0 then
        self.m_pendingGrowthScrollLuaIndex = math.floor(arg.growthScrollLuaIndex)
    else
        self.m_pendingGrowthScrollLuaIndex = 0
    end
    local previousTabIndex = self.m_curTabIndex
    self:_SetGrowthTab((arg and arg.growthTabIndex) or self.m_curTabIndex, false)
    if self.m_curTabIndex == previousTabIndex then
        self:_RefreshGrowthTabByIndex(self.m_curTabIndex)
    end
    if arg then
        arg.growthTabIndex = nil
        arg.weaponRecommendView = nil
        arg.growthScrollLuaIndex = nil
        arg.growthListFocused = nil
    end
end


ForesightCharGrowthDetailCtrl._TryApplyPendingGrowthScrollNavi = HL.Method().Return(HL.Boolean) << function(self)
    if not DeviceInfo.usingController or not self.m_isPanelActive then
        self.m_pendingGrowthScrollLuaIndex = 0
        return false
    end
    local scrollLuaIndex = self.m_pendingGrowthScrollLuaIndex
    if scrollLuaIndex < 1 then
        return false
    end
    local scrollList = self.m_view.contentScrollList
    local scrollRowCount = scrollList and scrollList.count or 0
    if scrollRowCount < 1 then
        self.m_pendingGrowthScrollLuaIndex = 0
        return false
    end
    scrollLuaIndex = math.min(scrollLuaIndex, scrollRowCount)
    local target = self:_GetScrollRowNaviTargetAt(scrollLuaIndex)
    if not target or not target.gameObject or not target.gameObject.activeInHierarchy then
        return false
    end
    self.m_pendingGrowthScrollLuaIndex = 0
    self:_SyncScrollListSelectedIndex(scrollLuaIndex)
    local naviMgr = InputManagerInst and InputManagerInst.controllerNaviManager
    if naviMgr and naviMgr.curTarget == target then
        return true
    end
    self.m_setNaviTarget(target)
    self.m_refreshControllerHints()
    return true
end

ForesightCharGrowthDetailCtrl._GetContentFocusHintGroupIds = HL.Method().Return(HL.Table) << function(self)
    local focusedRow = self:_GetFocusedScrollRowCell()
    if not focusedRow then
        return {}
    end
    local costNavi = self.m_rewardsCellHelper:_GetRewardScrollNaviGroup(focusedRow)
    if costNavi and costNavi.IsTopLayer then
        return {}
    end
    return self.m_rewardsCellHelper:CollectFocusHintGroupIds(focusedRow)
end





ForesightCharGrowthDetailCtrl._InitGrowthTabs = HL.Method() << function(self)
    local view = self.m_view
    for tabIndex, key in ipairs(TAB_TOGGLE_KEYS) do
        local toggle = view[key]
        if toggle and toggle.onValueChanged then
            toggle.onValueChanged:RemoveAllListeners()
            toggle.onValueChanged:AddListener(function(isOn)
                self:_SetGrowthTab(tabIndex, true, isOn)
            end)
        end
        local langKey = GROWTH_TAB_LABEL_LANG[tabIndex]
        if toggle and langKey and toggle.gameObject then
            local label = Language[langKey]
            local texts = toggle.gameObject:GetComponentsInChildren(typeof(CS.Beyond.UI.UIText), true)
            for i = 0, texts.Length - 1 do
                CellHelper.SetUiText(texts[i], label)
            end
        end
    end
    self.m_view[TAB_TOGGLE_KEYS[self.m_curTabIndex]]:SetIsOnWithoutNotify(true)
    self:_RefreshGrowthTabButtonStates()
end


ForesightCharGrowthDetailCtrl._RefreshGrowthTabButtonStates = HL.Method(HL.Opt(HL.Table, HL.Number)) << function(self, stageList, onlyTabIndex)
    if not self.m_isPanelActive then
        return
    end
    local info = self.m_selectedInfo
    local phase = self.m_phase
    if not info or not phase or string.isEmpty(info.templateId) then
        return
    end
    local templateId = info.templateId
    local view = self.m_view
    stageList = stageList or phase:GetCultivateStageIdList()
    for tabIndex, _ in ipairs(TAB_TOGGLE_KEYS) do
        local stateKey = TAB_TOGGLE_STATE_KEYS[tabIndex]
        local tabKey = GROWTH_TAB_KEYS[tabIndex]
        if (not onlyTabIndex or onlyTabIndex == tabIndex) and stateKey and tabKey then
            local stateCtrl = view[stateKey]
            local goalState = phase:GetGrowthTabGoalButtonState(templateId, tabKey, stageList)
            if string.isEmpty(goalState) then
                goalState = "InMax"
            end
            stateCtrl:SetState(goalState)
            if tabIndex == self.m_curTabIndex then
                stateCtrl:SetState("Select")
            end
        end
    end
end

ForesightCharGrowthDetailCtrl._InitGoalSelecter = HL.Method() << function(self)
    local goalSelecter = self.m_view.goalSelecter
    if not goalSelecter or not goalSelecter.Init then
        return
    end
    local headerGroup = self.m_view.headerInputGroup
    if headerGroup and headerGroup.groupId and headerGroup.groupId > 0 and goalSelecter.groupId and goalSelecter.groupId > 0 then
        InputManagerInst:ChangeParent(true, goalSelecter.groupId, headerGroup.groupId)
    end
    self.m_stageIdList = self.m_phase and self.m_phase:GetCultivateStageIdList() or {}
    goalSelecter:Init(function(index, option, isSelected)
        local t = self.m_stageIdList[LuaIndex(index)]
        if t then
            CellHelper.SetUiText(option, t.name or "")
            local labelState = self.m_phase:GetCultivateStageIconState(t.stageId)
            local labelImg = option.transform:Find("LabelImg")
            local showLabel = not string.isEmpty(labelState)
            if labelImg and labelImg.gameObject then
                labelImg.gameObject:SetActive(showLabel)
                if showLabel then
                    labelImg:GetComponent(typeof(CS.Beyond.UI.UIState.UIStateController)):SetState(labelState)
                end
            end
        end
    end, function(index) self:_OnSelectGoalOption(index) end)
end

ForesightCharGrowthDetailCtrl._InitDetailPinBtn = HL.Method() << function(self)
    local view = self.m_view
    local pinBtn = view.detailPinBtn
    if not pinBtn or not pinBtn.onClick then
        return
    end
    pinBtn.onClick:RemoveAllListeners()
    pinBtn.onClick:AddListener(function()
        self:_OnDetailPinClick()
    end)
    if view.pinKeyHint then
        local graphics = view.pinKeyHint.gameObject:GetComponentsInChildren(typeof(CS.UnityEngine.UI.Graphic), true)
        for i = 0, graphics.Length - 1 do
            graphics[i].raycastTarget = false
        end
    end
end

ForesightCharGrowthDetailCtrl._EnsureGrowthHeaderTemplateHolder = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    if self.m_headerTemplateHolderGo and not IsNull(self.m_headerTemplateHolderGo) then
        return self.m_headerTemplateHolderGo
    end
    local holder = CS.UnityEngine.GameObject("GrowthHeaderTemplateHolder")
    local rect = holder:AddComponent(RectTransformType)
    rect:SetParent(self.m_view.growthContentRoot, false)
    rect.anchorMin = Vector2(0, 0)
    rect.anchorMax = Vector2(1, 1)
    rect.offsetMin = Vector2(0, 0)
    rect.offsetMax = Vector2(0, 0)
    rect.localScale = Vector3.one
    holder:SetActive(false)
    self.m_headerTemplateHolderGo = holder
    return holder
end

ForesightCharGrowthDetailCtrl._EnsureLoadedHeaderTemplate = HL.Method(HL.String, HL.Boolean).Return(HL.Opt(HL.Table)) << function(self, prefabPath, needLuaReferenceRoot)
    local cache = self.m_growthHeaderTemplateWraps
    local cachedWrap = cache[prefabPath]
    if cachedWrap and cachedWrap.gameObject and not IsNull(cachedWrap.gameObject) then
        cachedWrap.gameObject:SetActive(false)
        return cachedWrap
    end
    if not self.m_loadGameObject then
        return nil
    end
    local prefab = self.m_loadGameObject(prefabPath)
    if not prefab then
        return nil
    end
    local holder = self:_EnsureGrowthHeaderTemplateHolder()
    if not holder then
        return nil
    end
    local go = CSUtils.CreateObject(prefab, holder)
    go:SetActive(false)
    if needLuaReferenceRoot then
        ensureLuaReferenceRootRef(go)
    end
    local wrap = needLuaReferenceRoot
        and Utils.wrapLuaNode({ gameObject = go, transform = go.transform })
        or Utils.wrapLuaNode(go)
    cache[prefabPath] = wrap
    return wrap
end

ForesightCharGrowthDetailCtrl._GetGrowthCellTemplate = HL.Method(HL.String).Return(HL.Opt(HL.Table))
    << function(self, templateKey)
    local slotIndex
    for i, key in ipairs(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER) do
        if key == templateKey then
            slotIndex = i
            break
        end
    end
    if not slotIndex then
        return nil
    end
    if slotIndex == 5 and not self:_IsWeaponRecommendListView() then
        return nil
    end
    if slotIndex == 6 and self.m_curTabIndex ~= 4 then
        return nil
    end
    return self:_EnsureLoadedHeaderTemplate(GROWTH_CELL_PREFAB_PATHS[slotIndex], slotIndex >= 5)
end

ForesightCharGrowthDetailCtrl._IsWeaponRecommendListView = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_curTabIndex ~= 3 then
        return false
    end
    local info = self.m_selectedInfo
    if not info then
        return false
    end
    local isForesight = info.isForesight == true
    local isOwned = info.isOwned == true and not isForesight
    if not isOwned then
        return false
    end
    return self.m_weaponRecommendViewByChar[info.templateId] == true
end

ForesightCharGrowthDetailCtrl._RebuildGrowthScrollRowMeta = HL.Method() << function(self)
    local meta = {}
    if self:_IsWeaponRecommendListView() then
        meta[1] = { kind = "header", sectionIndex = 1 }
        for i = 1, #(self.m_weaponRecommendEntries or {}) do
            meta[i + 1] = { kind = "weaponRecommend", recommendLuaIndex = i }
        end
    elseif self.m_curTabIndex == 3 and self.m_weaponTabSections and #self.m_weaponTabSections > 1 then
        local scrollIdx = 1
        local rewardIdx = 1
        for si, section in ipairs(self.m_weaponTabSections) do
            meta[scrollIdx] = { kind = "header", sectionIndex = si }
            scrollIdx = scrollIdx + 1
            for _ = 1, section.rowCount or 0 do
                meta[scrollIdx] = { kind = "reward", rewardLuaIndex = rewardIdx, sectionIndex = si }
                rewardIdx = rewardIdx + 1
                scrollIdx = scrollIdx + 1
            end
        end
    elseif self.m_curTabIndex == 4 and self.m_gemTabSections and #self.m_gemTabSections > 0 then
        local scrollIdx = 1
        for si, section in ipairs(self.m_gemTabSections) do
            meta[scrollIdx] = { kind = "header", sectionIndex = si }
            scrollIdx = scrollIdx + 1
            meta[scrollIdx] = { kind = "gemItem", sectionIndex = si }
            scrollIdx = scrollIdx + 1
        end
    else
        meta[1] = { kind = "header", sectionIndex = 1 }
        for i = 1, #(self.m_operatorRows or {}) do
            meta[i + 1] = { kind = "reward", rewardLuaIndex = i, sectionIndex = 1 }
        end
    end
    self.m_growthScrollRowMeta = meta
end

ForesightCharGrowthDetailCtrl._FindScrollLuaIndex = HL.Method(HL.String, HL.Number).Return(HL.Number) << function(self, kind, contentIndex)
    for scrollIdx, rowMeta in ipairs(self.m_growthScrollRowMeta or {}) do
        if kind == "reward" and rowMeta.kind == "reward" and rowMeta.rewardLuaIndex == contentIndex then
            return scrollIdx
        end
        if kind == "gemItem" and rowMeta.kind == "gemItem" and rowMeta.sectionIndex == contentIndex then
            return scrollIdx
        end
        if kind == "header" and rowMeta.kind == "header" and rowMeta.sectionIndex == contentIndex then
            return scrollIdx
        end
    end
    return 0
end

ForesightCharGrowthDetailCtrl._GetGrowthTemplateRowHeight = HL.Method(HL.String).Return(HL.Number) << function(self, templateKey)
    local heights = self.m_scrollHeaderRowHeights
    if heights[templateKey] and heights[templateKey] > 0 then
        return heights[templateKey]
    end
    local tpl = self:_GetGrowthCellTemplate(templateKey)
    if tpl and tpl.transform then
        local scrollList = self.m_view.contentScrollList
        local layoutWidth = scrollList and self:_GetRewardScrollViewportWidth(scrollList) or 0
        local measured = self:_MeasureGrowthRowTemplateHeight(tpl, layoutWidth)
        if measured > 0 then
            heights[templateKey] = measured
            return measured
        end
    end
    return 0
end


ForesightCharGrowthDetailCtrl._GetGrowthScrollRowCellSize = HL.Method(HL.Number).Return(HL.Number) << function(self, scrollLuaIndex)
    local meta = self.m_growthScrollRowMeta[scrollLuaIndex] or {}
    if meta.kind == "header" then
        local slotKey = GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex]
        if slotKey then
            return self:_GetGrowthTemplateRowHeight(slotKey)
        end
    elseif meta.kind == "weaponRecommend" then
        return self:_GetGrowthTemplateRowHeight(GROWTH_CELL_NAMES.WeaponItem)
    elseif meta.kind == "gemItem" then
        return self:_GetGrowthTemplateRowHeight(GROWTH_CELL_NAMES.GemItem)
    end
    local scrollList = self.m_view.contentScrollList
    if scrollList and scrollList.cellHeight and scrollList.cellHeight > 0 then
        return scrollList.cellHeight
    end
    return 0
end



ForesightCharGrowthDetailCtrl._SetScrollRowItemCellVisible = HL.Method(HL.Table, HL.Boolean) << function(self, rowCell, visible)
    if not rowCell or not rowCell.itemCell then
        return
    end
    local itemGo = rowCell.itemCell.gameObject or rowCell.itemCell
    if itemGo then
        itemGo:SetActive(visible == true)
    end
end

ForesightCharGrowthDetailCtrl._SetScrollRowHeaderSlotVisible = HL.Method(HL.Table, HL.String, HL.Boolean) << function(self, rowCell, slotKey, visible)
    if not rowCell or string.isEmpty(slotKey) then
        return
    end
    local cache = rowCell[slotKey]
    if not cache then
        return
    end
    local cell = cache:GetItem(1)
    if cell and cell.gameObject then
        cell.gameObject:SetActive(visible == true)
    end
end

ForesightCharGrowthDetailCtrl._HideAllScrollRowDynamicContent = HL.Method(HL.Table) << function(self, rowCell)
    if not rowCell then
        return
    end
    self:_SetScrollRowItemCellVisible(rowCell, false)
    for _, slotKey in ipairs(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER) do
        self:_SetScrollRowHeaderSlotVisible(rowCell, slotKey, false)
    end
end

ForesightCharGrowthDetailCtrl._ShouldRefocusGrowthScrollFirstRowOnFullReset = HL.Method().Return(HL.Boolean) << function(self)
    if not DeviceInfo.usingController or not self.m_isPanelActive then
        return false
    end
    if not UIManager:IsShow(PanelId.ForesightCharGrowthMain) then
        return false
    end
    if self.m_getIsCharListFocused() then
        return false
    end
    return self:_GetFocusedScrollRowCell() ~= nil
end


ForesightCharGrowthDetailCtrl._ApplyScrollRowDisplayMode = HL.Method(HL.Table, HL.String, HL.Opt(HL.Table)) << function(self, rowCell, mode, opt)
    opt = opt or {}
    if not rowCell then
        return
    end
    local prevMode = rowCell._growthRowDisplayMode
    local slotKey = opt.slotKey
    if rowCell._growthRowDisplayMode == mode then
        if mode ~= GROWTH_SCROLL_ROW_DISPLAY.Header or rowCell._growthHeaderSlotKey == slotKey then
            return
        end
    end
    rowCell._growthHeaderSlotKey = slotKey
    self:_HideAllScrollRowDynamicContent(rowCell)
    rowCell._growthRowDisplayMode = mode
    if mode == GROWTH_SCROLL_ROW_DISPLAY.Material then
        self:_SetScrollRowItemCellVisible(rowCell, true)
    elseif mode == GROWTH_SCROLL_ROW_DISPLAY.Header then
        if slotKey then
            self:_SetScrollRowHeaderSlotVisible(rowCell, slotKey, true)
        end
    elseif mode == GROWTH_SCROLL_ROW_DISPLAY.WeaponRecommend then
        self:_SetScrollRowHeaderSlotVisible(rowCell, GROWTH_CELL_NAMES.WeaponItem, true)
    elseif mode == GROWTH_SCROLL_ROW_DISPLAY.GemItem then
        self:_SetScrollRowHeaderSlotVisible(rowCell, GROWTH_CELL_NAMES.GemItem, true)
    end
    if rowCell.stateController then
        rowCell.stateController:SetState(mode == GROWTH_SCROLL_ROW_DISPLAY.Header and "Title" or "Item")
    end
    if DeviceInfo.usingController then
        local decorator = rowCell.cacheCellDecorator
        if decorator and decorator.isNaviTarget and prevMode and prevMode ~= mode then
            self.m_rewardsCellHelper:_OnRowRootNaviTargetChanged(rowCell, true)
        end
    end
end

ForesightCharGrowthDetailCtrl._SyncGrowthScrollListScrollable = HL.Method(HL.Number) << function(self, scrollRowCount)
    local scrollList = self.m_view.contentScrollList
    if not scrollList then
        return
    end
    local enableScroll = scrollRowCount > 1
    local scrollRect = scrollList.gameObject:GetComponent(UIScrollRectType)
    if scrollRect then
        scrollRect.vertical = enableScroll
        scrollRect.horizontal = false
        scrollRect.disableScroll = not enableScroll
        if not enableScroll then
            scrollRect:KillScrollTween()
            scrollRect:StopMovement()
            scrollRect.movementType = ScrollRectMovementType.Clamped
            scrollRect.verticalNormalizedPosition = 1
            scrollRect:ClampContentToBounds()
        else
            scrollRect.movementType = ScrollRectMovementType.Elastic
        end
    end
    if scrollList.gameObject and scrollList.gameObject.transform then
        local dragLayer = scrollList.gameObject.transform:Find("Container/ScrollDragLayer")
        if dragLayer then
            local graphic = dragLayer:GetComponent(typeof(CS.UnityEngine.UI.Graphic))
            if graphic then
                graphic.raycastTarget = enableScroll
            end
        end
    end
end

local function _IsTransformUnderGameObject(transform, ancestorGo)
    local t = transform
    while t do
        if t.gameObject == ancestorGo then
            return true
        end
        t = t.parent
    end
    return false
end

ForesightCharGrowthDetailCtrl._GetFocusedScrollRowCell = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if not DeviceInfo.usingController then
        return nil
    end
    local cur = InputManagerInst.controllerNaviManager.curTarget
    if not cur or not cur.transform then
        return nil
    end
    local scrollList = self.m_view.contentScrollList
    if not scrollList or not self.m_getRewardCell then
        return nil
    end
    local scrollRowCount = scrollList.count or 0
    local headerSlotKey = GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex]
    for scrollLuaIndex = 1, scrollRowCount do
        local go = scrollList:Get(CSIndex(scrollLuaIndex))
        if go then
            local rowCell = self.m_getRewardCell(go)
            if rowCell then
                local decorator = rowCell.cacheCellDecorator
                if decorator and cur == decorator then
                    return rowCell
                end
                
                local gemItemCell = rowCell._growthGemItemCell
                if gemItemCell and (cur == gemItemCell.eq1 or cur == gemItemCell.eq2) then
                    return rowCell
                end
                if headerSlotKey then
                    local headerCell = rowCell._growthHeaderCell
                    if headerCell and headerCell.gameObject
                        and _IsTransformUnderGameObject(cur.transform, headerCell.gameObject) then
                        return rowCell
                    end
                end
                if gemItemCell and gemItemCell.gameObject
                    and _IsTransformUnderGameObject(cur.transform, gemItemCell.gameObject) then
                    return rowCell
                end
                if rowCell.gameObject and _IsTransformUnderGameObject(cur.transform, rowCell.gameObject) then
                    return rowCell
                end
            end
        end
    end
    return nil
end


ForesightCharGrowthDetailCtrl._StretchInListHeaderCellRoot = HL.Method(HL.Table) << function(self, cell)
    if not cell or not cell.transform then
        return
    end
    if cell.gameObject then
        cell.gameObject.layer = UIConst.UI_LAYER
    end
    local rect = cell.transform
    local parentRect = rect.parent
    local rowHeight = parentRect and parentRect.rect.height or 0
    if rowHeight <= 0 then
        rowHeight = rect.rect.height
    end
    if rowHeight <= 0 then
        rowHeight = rect.sizeDelta.y
    end
    rect.anchorMin = Vector2(0, 1)
    rect.anchorMax = Vector2(1, 1)
    rect.pivot = Vector2(0.5, 1)
    rect.anchoredPosition3D = Vector3(0, 0, 0)
    rect.offsetMin = Vector2(0, rowHeight > 0 and -rowHeight or 0)
    rect.offsetMax = Vector2(0, 0)
end

ForesightCharGrowthDetailCtrl._ApplyInListTabBundleCell = HL.Method(HL.Table) << function(self, cell)
    local info = self.m_selectedInfo
    local bundle = self.m_curTabBundle
    local helper
    if self.m_curTabIndex == 1 then
        helper = self.m_charCellHelper
    elseif self.m_curTabIndex == 2 then
        helper = self.m_skillCellHelper
    else
        return
    end
    if not cell or not info or not bundle or not helper then
        return
    end
    if self.m_curTabIndex == 2 then
        helper:Refresh(cell, info, {
            headerBundle = bundle.headerBundle,
            showGrowthEmpty = #(self.m_growthScrollRowMeta or {}) <= 1,
        })
        return
    end
    helper:Refresh(cell, info, bundle)
end


ForesightCharGrowthDetailCtrl._ApplyInListSectionHeaderCell = HL.Method(HL.Table) << function(self, cell)
    local tabIndex = self.m_curTabIndex
    local sections, helper
    if tabIndex == 3 then
        sections = self.m_weaponTabSections
        helper = self.m_weaponCellHelper
    elseif tabIndex == 4 then
        sections = self.m_gemTabSections
        helper = self.m_gemCellHelper
    else
        return
    end
    local info = self.m_selectedInfo
    if not cell or not info or not sections or not helper then
        return
    end
    local sectionIndex = 1
    local rowCell = cell._growthRowCell
    if rowCell and rowCell._growthHeaderSectionIndex then
        sectionIndex = rowCell._growthHeaderSectionIndex
    end
    local section = sections[sectionIndex]
    local tabBundle = self.m_curTabBundle or {}
    local bundle = {
        headerBundle = section and section.headerBundle or tabBundle.headerBundle,
        isGoalReached = section and section.isGoalReached or tabBundle.isGoalReached,
        isCurStageMax = tabBundle.isCurStageMax,
    }
    if not bundle.headerBundle then
        return
    end
    helper:Refresh(cell, info, bundle)
end

ForesightCharGrowthDetailCtrl._ApplyInListWeaponItemCell = HL.Method(HL.Table, HL.Number)
    << function(self, cell, recommendLuaIndex)
    local info = self.m_selectedInfo
    local entry = self.m_weaponRecommendEntries and self.m_weaponRecommendEntries[recommendLuaIndex]
    if not cell or not info or not entry or not self.m_weaponItemCellHelper then
        return
    end
    local curWeaponInfo = {}
    if info.instId and info.instId > 0 then
        curWeaponInfo = CharInfoUtils.getCharCurWeapon(info.instId) or {}
    end
    self.m_weaponItemCellHelper:Refresh(cell, entry, {
        info = info,
        curWeaponInfo = curWeaponInfo,
        onSyncScrollListSelectedIndex = function(scrollLuaIndex)
            self:_SyncScrollListSelectedIndex(scrollLuaIndex)
        end,
    })
end

ForesightCharGrowthDetailCtrl._EnsureScrollRowInlineItem = HL.Method(
    HL.Table, HL.Number, HL.String, HL.Number, HL.Function)
    << function(self, rowCell, scrollLuaIndex, displayMode, contentIndex, applyCell)
    local mountKey = displayMode == GROWTH_SCROLL_ROW_DISPLAY.WeaponRecommend
        and GROWTH_CELL_NAMES.WeaponItem or GROWTH_CELL_NAMES.GemItem
    local template = self:_GetGrowthCellTemplate(mountKey)
    local mount = rowCell and rowCell.transform
    if not template or not mount then
        return
    end
    self:_ApplyScrollRowDisplayMode(rowCell, displayMode)
    if not rowCell[mountKey] then
        rowCell[mountKey] = UIUtils.genCellCache(template, wrapGrowthWeaponItemCell, mount)
    end
    rowCell[mountKey]:Refresh(1, function(cell)
        if cell.gameObject then
            cell.gameObject.name = mountKey
        end
        cell._growthRowCell = rowCell
        if displayMode == GROWTH_SCROLL_ROW_DISPLAY.GemItem then
            rowCell._growthGemItemCell = cell
        end
        applyCell(cell, contentIndex)
    end)
    rowCell._growthScrollLuaIndex = scrollLuaIndex
    if displayMode == GROWTH_SCROLL_ROW_DISPLAY.GemItem then
        rowCell._growthGemSectionIndex = contentIndex
    end
end


ForesightCharGrowthDetailCtrl._ApplyInListGemItemCell = HL.Method(HL.Table, HL.Number)
    << function(self, cell, sectionIndex)
    local info = self.m_selectedInfo
    local section = self.m_gemTabSections and self.m_gemTabSections[sectionIndex]
    if not cell or not info or not section or not self.m_gemItemCellHelper then
        return
    end
    local tabBundle = self.m_curTabBundle or {}
    self.m_gemItemCellHelper:Refresh(cell, info, {
        headerBundle = section.headerBundle,
        isGoalReached = section.isGoalReached,
        isCurStageMax = tabBundle.isCurStageMax,
    })
    if self.m_rewardsCellHelper then
        GemItemCellModule.ForesightCharGrowthDetailGemItemCell.WireEquippedEqNaviOnce(cell, self.m_rewardsCellHelper)
        local rowCell = cell._growthRowCell
        if rowCell then
            self.m_rewardsCellHelper:_SyncGemItemRowWrapNaviState(rowCell, cell)
        end
    end
end

ForesightCharGrowthDetailCtrl._RefreshGemHeaderRowAtSection = HL.Method(HL.Number) << function(self, sectionIndex)
    if self.m_curTabIndex ~= 4 then
        return
    end
    local scrollLuaIndex = self:_FindScrollLuaIndex("header", sectionIndex)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or scrollLuaIndex < 1 then
        return
    end
    local go = scrollList:Get(CSIndex(scrollLuaIndex))
    if not go then
        return
    end
    local rowCell = self.m_getRewardCell(go)
    local slotKey = GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex]
    if rowCell and slotKey then
        self:_EnsureScrollRowHeader(rowCell, slotKey, scrollLuaIndex)
        self:_SyncGrowthRowHeightFromActiveContent(go, rowCell, scrollLuaIndex)
    end
end

ForesightCharGrowthDetailCtrl._RefreshGemItemRowAtSection = HL.Method(HL.Number) << function(self, sectionIndex)
    if self.m_curTabIndex ~= 4 then
        return
    end
    local scrollLuaIndex = self:_FindScrollLuaIndex("gemItem", sectionIndex)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or scrollLuaIndex < 1 then
        return
    end
    local go = scrollList:Get(CSIndex(scrollLuaIndex))
    if go then
        local rowCell = self.m_getRewardCell(go)
        self:_EnsureScrollRowInlineItem(rowCell, scrollLuaIndex, GROWTH_SCROLL_ROW_DISPLAY.GemItem, sectionIndex,
            function(cell, idx)
                cell._growthSectionIndex = idx
                self:_ApplyInListGemItemCell(cell, idx)
            end)
        self:_SyncGrowthRowHeightFromActiveContent(go, rowCell, scrollLuaIndex)
    end
end

ForesightCharGrowthDetailCtrl._GetScrollRowNaviTargetAt = HL.Method(HL.Number).Return(HL.Opt(HL.Userdata))
    << function(self, scrollLuaIndex)
    if scrollLuaIndex < 1 then
        return nil
    end
    local scrollList = self.m_view.contentScrollList
    local go = scrollList:Get(CSIndex(scrollLuaIndex))
    if not go and scrollList.ScrollToIndex then
        scrollList:ScrollToIndex(CSIndex(scrollLuaIndex), true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
        go = scrollList:Get(CSIndex(scrollLuaIndex))
    end
    if not go then
        return nil
    end
    local rowCell = self.m_getRewardCell(go)
    if not rowCell then
        return nil
    end
    local meta = self.m_growthScrollRowMeta[scrollLuaIndex] or {}
    if meta.kind == "header" then
        local slotKey = GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex]
        if slotKey then
            self:_EnsureScrollRowHeader(rowCell, slotKey, scrollLuaIndex)
            self.m_rewardsCellHelper:WireRowRootNaviOnce(rowCell, scrollLuaIndex)
        end
    end
    local decorator = rowCell.cacheCellDecorator
    if not decorator then
        return nil
    end
    decorator.enableControllerNavi = true
    decorator.interactable = true
    return decorator
end

ForesightCharGrowthDetailCtrl._GetScrollRowEquippedGemEq1At = HL.Method(HL.Number).Return(HL.Opt(HL.Userdata))
    << function(self, scrollLuaIndex)
    if scrollLuaIndex < 1 then
        return nil
    end
    local scrollList = self.m_view.contentScrollList
    local go = scrollList:Get(CSIndex(scrollLuaIndex))
    if not go then
        return nil
    end
    local rowCell = self.m_getRewardCell(go)
    local innerCell = rowCell and rowCell._growthGemItemCell
    if innerCell and innerCell._gemItemDetailState == "Equipped" and innerCell.eq1 then
        GemItemCellModule.ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, true)
        return innerCell.eq1
    end
    return nil
end

ForesightCharGrowthDetailCtrl._EnsureScrollRowHeader = HL.Method(HL.Table, HL.String, HL.Number)
    << function(self, rowCell, slotKey, scrollLuaIndex)
    local tabIndex = self.m_curTabIndex
    if tabIndex < 1 or tabIndex > 4 then
        return
    end
    rowCell._growthScrollLuaIndex = scrollLuaIndex
    local meta = self.m_growthScrollRowMeta[scrollLuaIndex]
    rowCell._growthHeaderSectionIndex = meta and meta.sectionIndex or 1
    local template = self:_GetGrowthCellTemplate(slotKey)
    local mount = rowCell and rowCell.transform
    if not template or not mount then
        return
    end
    self:_ApplyScrollRowDisplayMode(rowCell, GROWTH_SCROLL_ROW_DISPLAY.Header, { slotKey = slotKey })
    if not rowCell[slotKey] then
        rowCell[slotKey] = UIUtils.genCellCache(template, nil, mount)
    end
    rowCell[slotKey]:Refresh(1, function(cell)
        if cell.gameObject then
            cell.gameObject.name = slotKey
        end
        cell._growthRowCell = rowCell
        rowCell._growthHeaderCell = cell
        if tabIndex <= 2 then
            self:_ApplyInListTabBundleCell(cell)
        else
            self:_ApplyInListSectionHeaderCell(cell)
        end
    end)
end



ForesightCharGrowthDetailCtrl._GetRewardScrollViewportWidth = HL.Method(HL.Userdata).Return(HL.Number)
    << function(self, scrollList)
    if not scrollList then
        return 0
    end
    local listRect = scrollList.gameObject:GetComponent(RectTransformType)
    if listRect and listRect.rect.width > 0 then
        return listRect.rect.width
    end
    local scrollRect = scrollList.gameObject:GetComponent(UIScrollRectType)
    if scrollRect and scrollRect.viewport then
        local viewportRect = scrollRect.viewport
        if viewportRect.rect.width > 0 then
            return viewportRect.rect.width
        end
    end
    return 0
end



ForesightCharGrowthDetailCtrl._MeasureGrowthRowTemplateHeight = HL.Method(HL.Table, HL.Number).Return(HL.Number)
    << function(self, tplWrap, layoutWidth)
    if not tplWrap or not tplWrap.transform or not tplWrap.gameObject or IsNull(tplWrap.gameObject) then
        return 0
    end
    local rect = tplWrap.transform
    if rect.sizeDelta.y > 0 then
        return rect.sizeDelta.y
    end
    local holderTr = rect.parent
    local holderGo = holderTr and holderTr.gameObject
    local holderWasActive = holderGo and holderGo.activeSelf
    local wasActive = tplWrap.gameObject.activeSelf
    if holderGo and not holderWasActive then
        holderGo:SetActive(true)
    end
    tplWrap.gameObject:SetActive(true)
    local oldAnchorMin = rect.anchorMin
    local oldAnchorMax = rect.anchorMax
    local oldPivot = rect.pivot
    local oldSizeDelta = rect.sizeDelta
    local oldPos = rect.anchoredPosition
    rect.anchorMin = Vector2(0, 1)
    rect.anchorMax = Vector2(0, 1)
    rect.pivot = Vector2(0, 1)
    rect.anchoredPosition = Vector2(0, 0)
    local measureWidth = layoutWidth
    if (not measureWidth or measureWidth <= 0) and rect.sizeDelta.x > 0 then
        measureWidth = rect.sizeDelta.x
    end
    if measureWidth and measureWidth > 0 then
        rect.sizeDelta = Vector2(measureWidth, 0)
    end
    LayoutRebuilder.ForceRebuildLayoutImmediate(rect)
    local preferred = LayoutUtility.GetPreferredHeight(rect)
    local measured = (preferred and preferred > 0) and preferred or rect.rect.height
    rect.anchorMin = oldAnchorMin
    rect.anchorMax = oldAnchorMax
    rect.pivot = oldPivot
    rect.sizeDelta = oldSizeDelta
    rect.anchoredPosition = oldPos
    tplWrap.gameObject:SetActive(wasActive)
    if holderGo and not holderWasActive then
        holderGo:SetActive(false)
    end
    return measured > 0 and measured or 0
end


ForesightCharGrowthDetailCtrl._GetScrollRowActiveContentTransform = HL.Method(HL.Table).Return(HL.Opt(HL.Userdata))
    << function(self, rowCell)
    if not rowCell then
        return nil
    end
    if rowCell.itemCell then
        local itemGo = rowCell.itemCell.gameObject or rowCell.itemCell
        if itemGo and itemGo.activeSelf then
            return rowCell.itemCell.transform or itemGo.transform
        end
    end
    for _, slotKey in ipairs(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER) do
        local cell = rowCell[slotKey] and rowCell[slotKey]:GetItem(1)
        if cell and cell.gameObject and cell.gameObject.activeSelf and cell.transform then
            return cell.transform
        end
    end
    return nil
end

ForesightCharGrowthDetailCtrl._SyncGrowthRowHeightFromActiveContent = HL.Method(HL.Userdata, HL.Table, HL.Number)
    << function(self, obj, rowCell, scrollLuaIndex)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or not obj or not rowCell or scrollLuaIndex < 1 then
        return
    end
    local activeRect = self:_GetScrollRowActiveContentTransform(rowCell)
    local measured = 0
    if activeRect then
        LayoutRebuilder.ForceRebuildLayoutImmediate(activeRect)
        measured = LayoutUtility.GetPreferredHeight(activeRect)
        if measured <= 0 then
            measured = activeRect.rect.height
        end
        measured = measured > 0 and measured or 0
    end
    local mode = rowCell._growthRowDisplayMode
    if mode == GROWTH_SCROLL_ROW_DISPLAY.Material then
        measured = 0
    end
    local finalHeight = measured > 0 and measured or self:_GetGrowthScrollRowCellSize(scrollLuaIndex)
    if finalHeight <= 0 then
        return
    end
    self:_FixRewardRowCellLayout(obj, scrollLuaIndex, finalHeight)
    self:_LayoutActiveScrollRowInnerContent(rowCell)
    if scrollList.NotifyCellSizeChange then
        scrollList:NotifyCellSizeChange(CSIndex(scrollLuaIndex), finalHeight)
    end
end

ForesightCharGrowthDetailCtrl._FixRewardRowCellLayout = HL.Method(HL.Userdata, HL.Number, HL.Number)
    << function(self, obj, luaIndex, overrideHeight)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or not obj then
        return
    end
    local cellRect = obj:GetComponent(RectTransformType)
    if not cellRect then
        return
    end
    local targetWidth = self:_GetRewardScrollViewportWidth(scrollList)
    if targetWidth <= 0 then
        targetWidth = cellRect.rect.width
    end
    local targetHeight = overrideHeight
    if not targetHeight or targetHeight <= 0 then
        targetHeight = luaIndex and self:_GetGrowthScrollRowCellSize(luaIndex) or cellRect.sizeDelta.y
    end
    if targetHeight <= 0 then
        targetHeight = cellRect.rect.height
    end
    local cellWidth = cellRect.rect.width
    local cellHeight = cellRect.sizeDelta.y
    if targetWidth > 0 and cellWidth > 0
        and math.abs(cellWidth - targetWidth) < 1 and math.abs(cellHeight - targetHeight) < 1 then
        return
    end
    cellRect.anchorMin = Vector2(0, 1)
    cellRect.anchorMax = Vector2(0, 1)
    cellRect.pivot = Vector2(0, 1)
    if targetWidth > 0 and targetHeight > 0 then
        cellRect.sizeDelta = Vector2(targetWidth, targetHeight)
        LayoutRebuilder.ForceRebuildLayoutImmediate(cellRect)
    end
end


ForesightCharGrowthDetailCtrl._LayoutActiveScrollRowInnerContent = HL.Method(HL.Table) << function(self, rowCell)
    if not rowCell then
        return
    end
    local mode = rowCell._growthRowDisplayMode
    if mode == GROWTH_SCROLL_ROW_DISPLAY.Material or not mode then
        return
    end
    for _, slotKey in ipairs(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER) do
        local cell = rowCell[slotKey] and rowCell[slotKey]:GetItem(1)
        if cell and cell.gameObject and cell.gameObject.activeSelf then
            self:_StretchInListHeaderCellRoot(cell)
            return
        end
    end
end

ForesightCharGrowthDetailCtrl._EnsureGrowthContentCaches = HL.Method() << function(self)
    if not self.m_view.contentScrollList then
        return
    end
    self:_GetGrowthCellTemplate(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex])
    if self.m_curTabIndex == 4 then
        self:_GetGrowthCellTemplate(GROWTH_CELL_NAMES.GemItem)
    elseif self:_IsWeaponRecommendListView() then
        self:_GetGrowthCellTemplate(GROWTH_CELL_NAMES.WeaponItem)
    end
    self:_EnsureOperatorCellHelpers()
end

ForesightCharGrowthDetailCtrl._EnsureOperatorCellHelpers = HL.Method() << function(self)
    if self.m_curTabIndex == 1 and not self.m_charCellHelper then
        self.m_charCellHelper = OperatorCells.ForesightCharGrowthDetailCharCell({
            onLevelUp = function(info)
                self:_OpenCharInfoForGrowth(info, { pageType = UIConst.CHAR_INFO_PAGE_TYPE.UPGRADE })
            end,
            onGoChar = function(templateId)
                self:_OnClickGoCharBtn(templateId)
            end,
        })
    end
    if self.m_curTabIndex == 2 and not self.m_skillCellHelper then
        self.m_skillCellHelper = OperatorCells.ForesightCharGrowthDetailSkillCell({
            onLevelUp = function(info)
                self:_OpenCharInfoForGrowth(info, { pageType = UIConst.CHAR_INFO_PAGE_TYPE.TALENT })
            end,
        })
    end
    if self.m_curTabIndex == 3 and not self.m_weaponCellHelper then
        self.m_weaponCellHelper = WeaponCellModule.ForesightCharGrowthDetailWeaponCell({
            phase = self.m_phase,
            getShowRecommend = function(templateId)
                return self.m_weaponRecommendViewByChar[templateId] == true
            end,
            setShowRecommend = function(templateId, isOn)
                self.m_weaponRecommendViewByChar[templateId] = isOn == true
            end,
            onLevelUp = function(info, weaponId, weaponInstId)
                self:_OnClickWeaponLevelUpBtn(info, weaponId, weaponInstId)
            end,
            onGoWeaponPool = function(weaponId)
                self:_OnClickGoWeaponPoolBtn(weaponId)
            end,
            onToggleRecommendView = function(templateId)
                self:_ToggleWeaponRecommendView(templateId)
            end,
        })
    end
    if self.m_curTabIndex == 3 and not self.m_weaponItemCellHelper then
        self.m_weaponItemCellHelper = WeaponItemCellModule.ForesightCharGrowthDetailWeaponItemCell({
            phase = self.m_phase,
            onGoViewWeapon = function(info, weaponId, weaponInstId)
                self:_OnClickRecommendWeaponView(info, weaponId, weaponInstId)
            end,
            onGoObtainWeapon = function(weaponId)
                self:_OnClickGoWeaponPoolBtn(weaponId)
            end,
        })
    end
    if self.m_curTabIndex == 4 and not self.m_gemCellHelper then
        self.m_gemCellHelper = GemCellModule.ForesightCharGrowthDetailGemCell({
            phase = self.m_phase,
            onRefreshGemBubbleRow = function(sectionIndex, rowKind)
                if rowKind == "header" then
                    self:_RefreshGemHeaderRowAtSection(sectionIndex)
                else
                    self:_RefreshGemItemRowAtSection(sectionIndex)
                end
            end,
            onLevelUp = function(info, header, showBubble)
                self:_OnClickGemLevelUpBtn(info, header, showBubble)
            end,
            onToggleWish = function(info, header)
                self:_OnClickGemWishBtn(info, header)
            end,
        })
    end
    if self.m_curTabIndex == 4 and not self.m_gemItemCellHelper then
        self.m_gemItemCellHelper = GemItemCellModule.ForesightCharGrowthDetailGemItemCell({
            phase = self.m_phase,
            onSyncScrollListSelectedIndex = function(scrollLuaIndex)
                self:_SyncScrollListSelectedIndex(scrollLuaIndex)
            end,
            onRefreshGemBubbleRow = function(sectionIndex, rowKind)
                if rowKind == "header" then
                    self:_RefreshGemHeaderRowAtSection(sectionIndex)
                else
                    self:_RefreshGemItemRowAtSection(sectionIndex)
                end
            end,
            onGainGem = function(weaponId, attachedGemInstId)
                self:_OnClickGainGem(weaponId, attachedGemInstId)
            end,
            onOpenDepot = function(weaponId, withPerfectMatchFilter)
                if self.m_phase then
                    local _, _, _, weaponInstId = self.m_phase:GetBestOwnedWeaponInstInfo(weaponId)
                    local gemInstId = weaponInstId > 0 and self.m_phase:_GetWeaponAttachedGemInstId(weaponInstId) or 0
                    local ok, gemInst = GameInstance.player.inventory:TryGetGemInst(Utils.getCurrentScope(), gemInstId)
                    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.ValuableDepot),ok and gemInst and gemInst.templateId or "")
                    self.m_phase:OpenValuableDepotForWeapon(weaponId, withPerfectMatchFilter == true)
                end
            end,
            onGemEnhance = function(gemInstId)
                self:_OnClickGemEnhance(gemInstId)
            end,
        })
    end
    if not self.m_rewardsCellHelper then
        self.m_rewardsCellHelper = OperatorCells.ForesightCharGrowthDetailRewardsCell({
            phase = self.m_phase,
            getShowConverted = function()
                if self.m_curTabIndex == 3 then return self.m_phase.m_showConvertedWeapon end
                return self.m_phase.m_showConvertedOperator
            end,
            setShowConverted = function(isOn)
                if self.m_curTabIndex == 3 then self.m_phase.m_showConvertedWeapon = isOn == true else self.m_phase.m_showConvertedOperator = isOn == true end
            end,
            getSelectedTemplateId = function()
                local info = self.m_selectedInfo
                return info and info.templateId
            end,
            getForesightGoToLog = function()
                local info = self.m_selectedInfo
                if not info or not info.templateId then
                    return nil
                end
                return {
                    charId = info.templateId,
                    charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned"),
                    sourceBlock = self.m_curTabIndex,
                }
            end,
            onRewardRowNeedRefresh = function()
                self:_RefreshAllExpGrowthRewardRows()
            end,
            getDetailHeaderNaviTarget = function()
                return self:_GetDetailHeaderNaviSelectable()
            end,
            onRefreshControllerHints = function(hideForItemTips)
                self.m_refreshControllerHints(hideForItemTips)
            end,
            onSyncScrollListSelectedIndex = function(scrollLuaIndex)
                self:_SyncScrollListSelectedIndex(scrollLuaIndex)
            end,
            getScrollRowNaviTargetAt = function(scrollLuaIndex)
                return self:_GetScrollRowNaviTargetAt(scrollLuaIndex)
            end,
            getScrollRowEquippedGemEq1At = function(scrollLuaIndex)
                return self:_GetScrollRowEquippedGemEq1At(scrollLuaIndex)
            end,
            gemItemCellHelper = self.m_gemItemCellHelper,
            loadGameObject = self.m_loadGameObject,
        })
    else
        self.m_rewardsCellHelper.m_gemItemCellHelper = self.m_gemItemCellHelper
        self.m_rewardsCellHelper.m_loadGameObject = self.m_loadGameObject
    end
end


ForesightCharGrowthDetailCtrl._GetDetailHeaderNaviSelectable = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    local view = self.m_view
    if not view then
        return nil
    end
    if view.headerNaviDecorator then
        return view.headerNaviDecorator
    end
    local mono = view.headerInputGroup
    if mono and mono.gameObject then
        return mono.gameObject:GetComponent(typeof(CS.Beyond.UI.InputBindingGroupNaviDecorator))
    end
    return nil
end

ForesightCharGrowthDetailCtrl._GetDetailNaviGroup = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    local view = self.m_view
    if not view or not view.gameObject then
        return nil
    end
    
    return view.gameObject:GetComponent(typeof(CS.Beyond.UI.UISelectableNaviGroup))
end


ForesightCharGrowthDetailCtrl._SyncScrollListSelectedIndex = HL.Method(HL.Number) << function(self, scrollLuaIndex)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or not scrollList.SetSelectedIndex then
        return
    end
    local targetCs = CSIndex(scrollLuaIndex)
    local selectedCs = scrollList.curSelectedIndex
    if selectedCs ~= targetCs then
        scrollList:SetSelectedIndex(targetCs, false, false, false)
    end
end

ForesightCharGrowthDetailCtrl._ClearGrowthRowControllerNavFlags = HL.Method(HL.Table) << function(self, rowCell)
    if not rowCell then
        return
    end
    rowCell._growthNavWired = false
    rowCell._growthNavWiredDisplayMode = nil
    for _, slotKey in ipairs(GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER) do
        local innerCell = rowCell[slotKey] and rowCell[slotKey]:GetItem(1)
        if innerCell then
            innerCell._gemEqNavWired = false
            innerCell._gemSubBtnLeftNavWired = false
            innerCell._gemHeaderLeftNavWired = false
            innerCell._growthBtnLeftNavWired = nil
        end
    end
end

ForesightCharGrowthDetailCtrl._RewireVisibleGrowthScrollRows = HL.Method() << function(self)
    if not DeviceInfo.usingController or not self.m_isPanelActive then
        return
    end
    local scrollList = self.m_view.contentScrollList
    local helper = self.m_rewardsCellHelper
    if not scrollList or not self.m_getRewardCell or not helper then
        return
    end
    local scrollRowCount = scrollList.count or 0
    for scrollLuaIndex = 1, scrollRowCount do
        local go = scrollList:Get(CSIndex(scrollLuaIndex))
        if go then
            local rowCell = self.m_getRewardCell(go)
            if rowCell then
                self:_ClearGrowthRowControllerNavFlags(rowCell)
                if rowCell._growthRowDisplayMode == GROWTH_SCROLL_ROW_DISPLAY.Material then
                    local opt = rowCell._growthScrollControllerMaterialOpt or {}
                    if opt.materialKey then
                        helper:_SetupCostItemsSubNav(rowCell, opt.materialKey)
                    end
                end
                helper:WireRowRootNaviOnce(rowCell, scrollLuaIndex)
                local gemItemCell = rowCell._growthGemItemCell
                if gemItemCell then
                    GemItemCellModule.ForesightCharGrowthDetailGemItemCell.WireEquippedEqNaviOnce(gemItemCell, helper)
                    helper:_SyncGemItemRowWrapNaviState(rowCell, gemItemCell)
                end
            end
        end
    end
end

ForesightCharGrowthDetailCtrl.RefreshRewardRowControllerState = HL.Method() << function(self)
    self:_RewireVisibleGrowthScrollRows()
    if DeviceInfo.usingController and self.m_refreshControllerHints then
        self.m_refreshControllerHints()
    end
end

ForesightCharGrowthDetailCtrl._InitGrowthContentScroll = HL.Method() << function(self)
    local view = self.m_view
    if not view or not view.contentScrollList then
        return
    end
    
    local detailGroup = self:_GetDetailNaviGroup()
    if detailGroup then
        detailGroup.isIsolate = true
    end
    self:_EnsureGrowthContentCaches()
    local scrollList = view.contentScrollList
    if scrollList.TryRecalculateSize then
        scrollList:TryRecalculateSize()
    end
    if not self.m_growthScrollInited then
        self.m_getRewardCell = UIUtils.genCachedCellFunction(scrollList, function(obj)
            return Utils.wrapLuaNode(obj)
        end)
        scrollList.getCellSize = function(csIndex)
            return self:_GetGrowthScrollRowCellSize(LuaIndex(csIndex))
        end
        scrollList.onUpdateCell:AddListener(function(obj, csIndex)
            self:_OnUpdateGrowthScrollCell(obj, LuaIndex(csIndex))
        end)
        if not self.m_growthScrollCountListenerWired and scrollList.onUpdateCount then
            scrollList.onUpdateCount:AddListener(function(newCount)
                self:_SyncGrowthScrollListScrollable(newCount)
            end)
            self.m_growthScrollCountListenerWired = true
        end
        self.m_growthScrollInited = true
    end
end




ForesightCharGrowthDetailCtrl._OnGemInventoryChanged = HL.Method() << function(self)
    if self.m_curTabIndex == 4 then
        self:_RefreshGrowthTabByIndex(self.m_curTabIndex, 4)
    end
end

ForesightCharGrowthDetailCtrl._FlushPendingCultivateRefresh = HL.Method() << function(self)
    if self.m_pendingPlanRefresh then
        self.m_pendingPlanRefresh = false
        self:_OnCharCultivatePlanChanged()
    end
    if self.m_pendingPinRefresh then
        self.m_pendingPinRefresh = false
        self:_OnCharCultivatePriorityChanged()
    end
end

ForesightCharGrowthDetailCtrl._RunCultivateUiAction = HL.Method(HL.Function) << function(self, action)
    if not self.m_isPanelActive then
        return
    end
    self.m_cultivateUiCallbackDepth = self.m_cultivateUiCallbackDepth + 1
    action()
    self.m_cultivateUiCallbackDepth = math.max(0, self.m_cultivateUiCallbackDepth - 1)
    if self.m_cultivateUiCallbackDepth > 0 then
        return
    end
    if not self.m_isPanelActive then
        self.m_pendingPlanRefresh = false
        self.m_pendingPinRefresh = false
        return
    end
    self:_FlushPendingCultivateRefresh()
end

ForesightCharGrowthDetailCtrl._OnCharCultivatePlanChanged = HL.Method() << function(self)
    if self.m_cultivateUiCallbackDepth > 0 then
        self.m_pendingPlanRefresh = true
        return
    end
    self:_RefreshGoalSelecter()
    self:_RefreshGrowthTabByIndex(self.m_curTabIndex)
end

ForesightCharGrowthDetailCtrl._OnCharCultivatePriorityChanged = HL.Method() << function(self)
    if self.m_cultivateUiCallbackDepth > 0 then
        self.m_pendingPinRefresh = true
        return
    end
    self:_RefreshPinState()
end





ForesightCharGrowthDetailCtrl._OnDetailPinClick = HL.Method() << function(self)
    local info = self.m_selectedInfo
    local phase = self.m_phase
    if not info or info.isForesight or not phase then
        return
    end
    local templateId = info.templateId
    local newPinned = not phase:IsCharPinned(templateId)
    local charStatus = info.isOwned and "owned" or "unowned"
    self:_RunCultivateUiAction(function()
        phase:RequestSetCharPinned(templateId, newPinned, charStatus)
    end)
end

ForesightCharGrowthDetailCtrl._RefreshPinState = HL.Method() << function(self)
    if not self.m_isPanelActive then
        return
    end
    local info = self.m_selectedInfo
    local phase = self.m_phase
    local view = self.m_view
    local pinBtn = view and view.detailPinBtn
    if not info or not info.templateId or info.isForesight or not phase or not view then
        CellHelper.ToggleBtnBinding(pinBtn, false)
        return
    end
    local pinIcon = view.detailPinIcon
    local pinnedIcon = view.detailPinIconPinned
    local pinNode = view.detailPinNode
    local pinnedNode = view.detailPinPinnedNode
    local isPinned = phase:IsCharPinned(info.templateId)
    if pinNode then
        pinNode.gameObject:SetActive(not isPinned)
    end
    if pinnedNode then
        pinnedNode.gameObject:SetActive(isPinned)
    end
    if pinBtn and pinBtn.targetGraphic then
        local graphic = isPinned and pinnedIcon or pinIcon
        if graphic then
            pinBtn.targetGraphic = graphic
        end
    end
    local hintText = isPinned and Language.LUA_FORESIGHT_GROWTH_CTRL_DEL_PIN
        or Language.LUA_FORESIGHT_GROWTH_CTRL_ADD_PIN
    CellHelper.ToggleBtnBinding(pinBtn, true, hintText)
end





ForesightCharGrowthDetailCtrl._FindStageCsIndex = HL.Method(HL.Number).Return(HL.Number) << function(self, stageId)
    for i, v in ipairs(self.m_stageIdList) do
        if v.stageId == stageId then
            return CSIndex(i)
        end
    end
    return 0
end

ForesightCharGrowthDetailCtrl._RefreshCharInfoBlock = HL.Method(HL.Table) << function(self, charInfo)
    local view = self.m_view
    if not view or not charInfo then
        return
    end
    local templateId = charInfo.templateId
    local isForesight = charInfo.isForesight == true
    if view.headIcon then
        view.headIcon.gameObject:SetActive(true)
        
        view.headIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. templateId)
    end
    if view.charName then
        if not isForesight and view.charName.SetPhoneticText then
            view.charName:SetPhoneticText(GEnums.PhoneticType.CharNamePhonetic, templateId)
        else
            view.charName.text = charInfo.name or ""
        end
    end
    local charTypeId = charInfo.charTypeId
    if charTypeId then
        local okType, charTypeData = Tables.charTypeTable:TryGetValue(charTypeId)
        if okType then
            view.charClassIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_ELEMENT, charTypeData.icon)
            view.charIconBg.color = UIUtils.getColorByString(charTypeData.color)
            view.charClassText.text = charTypeData.name
        end
    end
    local profession = charInfo.profession
    if profession then
        local okPro, professionCfg = Tables.charProfessionTable:TryGetValue(profession)
        if okPro then
            if view.charProfessionIcon then
                view.charProfessionIcon:LoadSprite(
                    UIConst.UI_SPRITE_CHAR_PROFESSION,
                    CharInfoUtils.getCharProfessionIconName(profession)
                )
            end
            if view.charProfessionText then
                view.charProfessionText.text = professionCfg.name
            end
        end
    end
    self:_RefreshGoalSelecter(templateId)
    if view.detailPinBtn then
        view.detailPinBtn.gameObject:SetActive(not isForesight)
    end
    self:_RefreshPinState()
end

ForesightCharGrowthDetailCtrl._RefreshGrowthTabByIndex = HL.Method(HL.Number, HL.Opt(HL.Number)) << function(self, tabIndex, onlyGoalTabIndex)
    if not self.m_isPanelActive then
        return
    end
    local tabKey = GROWTH_TAB_KEYS[tabIndex]
    if not tabKey then
        return
    end
    local view = self.m_view
    local info = self.m_selectedInfo
    local phase = self.m_phase
    if not view or not info or not info.templateId or not phase then
        return
    end
    self:_EnsureGrowthContentCaches()
    local templateId = info.templateId
    local stageId = phase:GetCharCultivateStageId(templateId)
    local stageList = phase:GetCultivateStageIdList()
    local showConverted
    if tabKey == "weapon" then
        showConverted = phase.m_showConvertedWeapon
    else
        showConverted = phase.m_showConvertedOperator
    end
    local bundle = phase:GetGrowthTabBundle(templateId, stageId, tabKey, showConverted, stageList)
    if tabKey ~= "weapon" then
        self.m_weaponTabSections = {}
        self.m_weaponRecommendEntries = {}
    end
    if tabKey ~= "matrix" then
        self.m_gemTabSections = {}
    end
    if tabKey == "skill" then
        bundle.headerBundle = phase:GetSkillGrowthHeaderBundle(templateId, stageId, stageList, bundle.growthData)
        if not bundle.headerBundle.isCurStageMax then
            if stageList and #stageList > 0 and phase:IsOperatorGoalReached(
                phase:GetSkillGrowthItemListData(templateId, stageList[#stageList].stageId, stageList)) then
                bundle.headerBundle.isCurStageMax = true
            end
        end
    elseif tabKey == "weapon" then
        self.m_weaponTabSections = bundle.weaponSections or {}
        if #self.m_weaponTabSections == 0 then
            bundle.headerBundle = phase:GetWeaponGrowthHeaderBundle(templateId, stageId)
            self.m_weaponTabSections = {{
                headerBundle = bundle.headerBundle,
                growthData = bundle.growthData,
                isGoalReached = bundle.isGoalReached,
            }}
        else
            bundle.headerBundle = self.m_weaponTabSections[1].headerBundle
        end
        if self.m_weaponRecommendViewByChar[templateId] == nil then
            local header = self.m_weaponTabSections[1] and self.m_weaponTabSections[1].headerBundle
            local preferRecommend = header
                and header.isEquippedLowQuality
                and not header.isEquippedRecommended
            self.m_weaponRecommendViewByChar[templateId] = preferRecommend == true
        end
        self.m_weaponRecommendEntries = phase:GetCharRecommendWeaponEntries(templateId)
    elseif tabKey == "matrix" then
        self.m_gemTabSections = bundle.gemSections or {}
        bundle.headerBundle = self.m_gemTabSections[1] and self.m_gemTabSections[1].headerBundle
    end
    self.m_operatorRows = bundle.rows or {}
    self.m_operatorGoalReached = bundle.isGoalReached == true
    self.m_operatorStageMax = bundle.isCurStageMax == true
    if tabIndex == 2 then
        self.m_operatorStageMax = stageList ~= nil and #stageList > 0
            and stageId >= stageList[#stageList].stageId
    end
    self.m_curTabBundle = bundle
    self:_RebuildGrowthScrollRowMeta()
    local scrollRowCount = #(self.m_growthScrollRowMeta or {})
    self:_SyncGrowthRewardScrollList()
    self:_SyncGrowthEmptyNode(info, scrollRowCount > 1)
    self:_RefreshGrowthTabButtonStates(stageList, onlyGoalTabIndex)
    self.m_watchedItemIdMap = {}
    local map = self.m_watchedItemIdMap
    for _, row in ipairs(self.m_operatorRows or {}) do
        local d = row.data
        if d then
            local list = d.rawList or d.materials or d
            for _, e in ipairs(list) do
                if not string.isEmpty(e.itemId) then map[e.itemId] = true end
            end
            for _, e in ipairs(d.convertedList or {}) do
                if not string.isEmpty(e.itemId) then map[e.itemId] = true end
            end
            if not string.isEmpty(d.chestItemId) then map[d.chestItemId] = true end
        end
    end
end

ForesightCharGrowthDetailCtrl._SyncGrowthRewardScrollList = HL.Method() << function(self)
    local scrollRowCount = #(self.m_growthScrollRowMeta or {})
    local scrollList = self.m_view.contentScrollList
    if not scrollList then
        return
    end
    if scrollList.TryRecalculateSize then
        scrollList:TryRecalculateSize()
    end
    if DeviceInfo.usingController then
        Notify(MessageConst.HIDE_ITEM_TIPS)
    end
    if self:_ShouldRefocusGrowthScrollFirstRowOnFullReset() and scrollRowCount > 0 and self.m_pendingGrowthScrollLuaIndex < 1 then
        self.m_pendingGrowthScrollLuaIndex = 1
    end
    self:_SyncGrowthScrollListScrollable(0)
    if self.m_pendingGrowthScrollLuaIndex > 0 then
        local scrollTo = math.min(self.m_pendingGrowthScrollLuaIndex, scrollRowCount)
        scrollList:UpdateCount(scrollRowCount, CSIndex(scrollTo), true, false, false,
            CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
    else
        scrollList:UpdateCount(scrollRowCount, true, true)
    end
    if scrollList.gameObject then
        scrollList.gameObject:SetActive(true)
    end
    if not DeviceInfo.usingController then
        self.m_pendingGrowthScrollLuaIndex = 0
    end
    self:_TryApplyPendingGrowthScrollNavi()
end


ForesightCharGrowthDetailCtrl._LayoutGrowthEmptyNode = HL.Method() << function(self)
    local emptyNode = self.m_view.growthEmptyNode
    if not emptyNode.gameObject.activeSelf then
        return
    end
    local scrollList = self.m_view.contentScrollList
    local emptyRt = emptyNode.transform
    local container = scrollList.transform:Find("Container")
    CS.UnityEngine.Canvas.ForceUpdateCanvases()
    local containerH = container and container.rect.height or 0
    emptyRt.anchorMin = Vector2(0, 0)
    emptyRt.anchorMax = Vector2(1, 1)
    local offsetMin = emptyRt.offsetMin
    local offsetMax = emptyRt.offsetMax
    emptyRt.offsetMin = Vector2(offsetMin.x, 30)
    emptyRt.offsetMax = Vector2(offsetMax.x, -containerH)
end

ForesightCharGrowthDetailCtrl._SyncGrowthEmptyNode = HL.Method(HL.Table, HL.Boolean)
    << function(self, info, hasRows)
    local emptyNode = self.m_view.growthEmptyNode
    if hasRows then
        emptyNode.gameObject:SetActive(false)
        return
    end
    emptyNode.gameObject:SetActive(true)
    local isForesight = info.isForesight == true
    local tabBundle = self.m_curTabBundle or {}
    local isGoalReached = false
    local isMaxStage = false
    local isOwned = info.isOwned == true and not isForesight
    if self.m_curTabIndex == 1 then
        isGoalReached = isOwned and self.m_operatorGoalReached
        local isCharLvMax = isOwned and (info.level or 0) >= Tables.characterConst.maxLevel
        isMaxStage = isOwned and self.m_operatorStageMax
        emptyNode:SetState(((isMaxStage or isCharLvMax) and isGoalReached) and "CharLvMax" or "CanRaise")
    elseif self.m_curTabIndex == 2 then
        local headerBundle = tabBundle.headerBundle or {}
        isGoalReached = isOwned and headerBundle.isGoalReached == true
        isMaxStage = isOwned and headerBundle.isCurStageMax == true
        emptyNode:SetState((isMaxStage and isGoalReached) and "SkillMax" or "CanRaise")
    elseif self.m_curTabIndex == 3 then
        local section = self.m_weaponTabSections and self.m_weaponTabSections[1]
        local headerBundle = (section and section.headerBundle) or tabBundle.headerBundle or {}
        local isWeaponOwned = headerBundle.isDisplayWeaponOwned == true
        local sectionGoalReached = section and section.isGoalReached or tabBundle.isGoalReached
        isGoalReached = isWeaponOwned and sectionGoalReached == true
        isMaxStage = isWeaponOwned and tabBundle.isCurStageMax == true
        local _, weaponCfg = Tables.weaponBasicTable:TryGetValue(headerBundle.displayWeaponId or "")
        local isWeaponLvMax = isWeaponOwned and weaponCfg
            and (headerBundle.displayWeaponLevel or 0) >= (weaponCfg.maxLv or 0)
        emptyNode:SetState(((isMaxStage or isWeaponLvMax) and isGoalReached) and "WeaponLvMax" or "CanRaise")
    end
    self:_LayoutGrowthEmptyNode()
end

ForesightCharGrowthDetailCtrl._OnUpdateGrowthScrollCell = HL.Method(HL.Userdata, HL.Number) << function(self, obj, scrollLuaIndex)
    local rowCell = self.m_getRewardCell(obj)
    if not rowCell then
        return
    end
    rowCell._growthScrollLuaIndex = scrollLuaIndex
    local meta = self.m_growthScrollRowMeta[scrollLuaIndex] or {}
    if meta.kind == "header" then
        local slotKey = GROWTH_SCROLL_ROW_DYNAMIC_SLOT_ORDER[self.m_curTabIndex]
        if slotKey then
            self:_EnsureScrollRowHeader(rowCell, slotKey, scrollLuaIndex)
        end
    elseif meta.kind == "weaponRecommend" then
        self:_EnsureScrollRowInlineItem(rowCell, scrollLuaIndex, GROWTH_SCROLL_ROW_DISPLAY.WeaponRecommend,
            meta.recommendLuaIndex, function(cell, idx)
                self:_ApplyInListWeaponItemCell(cell, idx)
            end)
    elseif meta.kind == "gemItem" then
        self:_EnsureScrollRowInlineItem(rowCell, scrollLuaIndex, GROWTH_SCROLL_ROW_DISPLAY.GemItem,
            meta.sectionIndex or 1, function(cell, idx)
                cell._growthSectionIndex = idx
                self:_ApplyInListGemItemCell(cell, idx)
            end)
    else
        self:_ApplyScrollRowDisplayMode(rowCell, GROWTH_SCROLL_ROW_DISPLAY.Material)
        local row = self.m_operatorRows[meta.rewardLuaIndex]
        if row and self.m_rewardsCellHelper then
            rowCell._foresightExpExchangeIsWeapon = self.m_curTabIndex == 3
            self.m_rewardsCellHelper:Refresh(rowCell, row, meta.rewardLuaIndex)
        end
    end
    self:_SyncGrowthRowHeightFromActiveContent(obj, rowCell, scrollLuaIndex)
    self.m_rewardsCellHelper:WireRowRootNaviOnce(rowCell, scrollLuaIndex)
    local scrollList = self.m_view.contentScrollList
    local scrollRowCount = scrollList and scrollList.count or 0
    if scrollRowCount <= 1 then
        self:_SyncGrowthScrollListScrollable(scrollRowCount)
        self:_LayoutGrowthEmptyNode()
    end
    if self.m_pendingGrowthScrollLuaIndex == scrollLuaIndex then
        self:_TryApplyPendingGrowthScrollNavi()
    end
end


ForesightCharGrowthDetailCtrl._RefreshGrowthRewardRow = HL.Method(HL.Number) << function(self, rewardLuaIndex)
    if self:_IsWeaponRecommendListView() then
        return
    end
    if self.m_curTabIndex == 4 then
        return
    end
    local row = self.m_operatorRows and self.m_operatorRows[rewardLuaIndex]
    if not row then
        return
    end
    local scrollLuaIndex = self:_FindScrollLuaIndex("reward", rewardLuaIndex)
    local scrollList = self.m_view.contentScrollList
    if not scrollList or scrollLuaIndex < 1 then
        return
    end
    local preserveFocus = false
    if DeviceInfo.usingController then
        local focusedRow = self:_GetFocusedScrollRowCell()
        preserveFocus = focusedRow and focusedRow._growthScrollLuaIndex == scrollLuaIndex
    end
    local go = scrollList:Get(CSIndex(scrollLuaIndex))
    if go then
        local rowCell = self.m_getRewardCell(go)
        if rowCell and self.m_rewardsCellHelper then
            rowCell._foresightExpExchangeIsWeapon = self.m_curTabIndex == 3
            self.m_rewardsCellHelper:Refresh(rowCell, row, rewardLuaIndex)
        end
        self:_SyncGrowthRowHeightFromActiveContent(go, rowCell, scrollLuaIndex)
    end
    if preserveFocus then
        local block = self:_GetScrollRowNaviTargetAt(scrollLuaIndex)
        if block then
            self.m_setNaviTarget(block)
        end
    end
end

ForesightCharGrowthDetailCtrl._RefreshAllExpGrowthRewardRows = HL.Method() << function(self)
    local rows = self.m_operatorRows
    if not rows then
        return
    end
    for rewardLuaIndex, row in ipairs(rows) do
        if row and row.key == "Exp" then
            self:_RefreshGrowthRewardRow(rewardLuaIndex)
        end
    end
end

ForesightCharGrowthDetailCtrl._OnClickRecommendWeaponView = HL.Method(HL.Table, HL.String, HL.Opt(HL.Number))
    << function(self, info, weaponId, weaponInstId)
    if not info or string.isEmpty(weaponId) then
        return
    end
    if not info.instId or info.instId <= 0 then
        return
    end
    local notifyArg
    if weaponInstId and weaponInstId > 0 then
        notifyArg = {
            instId = weaponInstId,
            audioEventName = "Au_UI_Event_WeaponBuild",
        }
    else
        notifyArg = {
            id = weaponId,
            audioEventName = "Au_UI_Event_WeaponBuild",
        }
    end
    self:_OpenCharInfoForGrowth(info, {
        pageType = UIConst.CHAR_INFO_PAGE_TYPE.WEAPON,
        stateArg = { isDetail = true, curSelectedIndex = 1 },
        onOpened = function()
            Notify(MessageConst.CHAR_INFO_WEAPON_SELECT_WEAPON, notifyArg)
        end,
    }, weaponId)
end





ForesightCharGrowthDetailCtrl._LogCultiOverviewGoTo = HL.Method(HL.String, HL.Opt(HL.String, HL.Boolean,HL.String)) << function(self, goToName, itemIdList, addWishlistListFail,jumpItem)
    local info = self.m_selectedInfo
    if not info or not info.templateId then
        return
    end
    local charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned")
    EventLogManagerInst:GameEvent_CultiOverviewGoTo(info.templateId, goToName, itemIdList or "", charStatus, self.m_curTabIndex, addWishlistListFail == true,jumpItem or "")
end

ForesightCharGrowthDetailCtrl._IsJumpBlocked = HL.Method().Return(HL.Boolean) << function(self)
    local info = self.m_selectedInfo
    if not info or not info.instId or info.instId <= 0 then
        return false
    end
    if CharInfoUtils.isCharDevAvailable(info.instId) then
        return false
    end
    Notify(MessageConst.SHOW_TOAST, Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED)
    return true
end

ForesightCharGrowthDetailCtrl._OpenCharInfoForGrowth = HL.Method(HL.Table, HL.Table, HL.Opt(HL.String)).Return(HL.Boolean)
    << function(self, info, opt, itemIdList)
    if not info or not info.instId or info.instId <= 0 then
        return false
    end
    if self:_IsJumpBlocked() then
        return false
    end

    local jumpScrollLuaIndex = 0
    local focusedRow = self:_GetFocusedScrollRowCell()
    if focusedRow and focusedRow._growthScrollLuaIndex and focusedRow._growthScrollLuaIndex > 0 then
        jumpScrollLuaIndex = focusedRow._growthScrollLuaIndex
    else
        local scrollList = self.m_view and self.m_view.contentScrollList
        if scrollList then
            local selectedCs = scrollList.curSelectedIndex
            if selectedCs and selectedCs >= 0 then
                jumpScrollLuaIndex = LuaIndex(selectedCs)
            end
        end
        if jumpScrollLuaIndex < 1 then
            jumpScrollLuaIndex = self:_FindScrollLuaIndex("header", 1)
        end
    end
    if jumpScrollLuaIndex > 0 then
        self:_SyncScrollListSelectedIndex(jumpScrollLuaIndex)
    end
    self:_LogCultiOverviewGoTo(opt.eventLogTarget or PhaseManager:GetPhaseName(PhaseId.CharInfo), itemIdList)
    local _, charInfoPhase = PhaseManager:IsOpen(PhaseId.CharInfo)
    local pid = PanelId.ForesightCharGrowthMain
    
    local clearKey = UIManager.m_autoClearScreenKeys[pid]
    if clearKey then
        UIManager.m_autoClearScreenKeys[pid] = nil
        UIManager:RecoverScreen(clearKey)
    end
    local targetCharInfo
    if charInfoPhase.m_charInfoList then
        for _, charInfo in ipairs(charInfoPhase.m_charInfoList) do
            if charInfo.instId == info.instId then
                targetCharInfo = charInfo
                break
            end
        end
    end
    local pageType = opt.pageType
    UIManager:Hide(pid)
    Notify(MessageConst.CHAR_INFO_JUMP_PAGE, {
        pageType = pageType,
        charInfo = targetCharInfo,
        onAfterPageChange = function()
            if opt.stateArg and pageType == UIConst.CHAR_INFO_PAGE_TYPE.WEAPON then
                local weaponItem = charInfoPhase:_GetPanelPhaseItem(PanelId.CharInfoWeapon)
                if weaponItem and weaponItem.uiCtrl and HL.TryGet(weaponItem.uiCtrl, "_ProcessStateArg") then
                    weaponItem.uiCtrl:_ProcessStateArg(opt.stateArg)
                end
            end
            if opt.onOpened then
                opt.onOpened()
            end
        end,
        extraArg = {
            backToForesightCharGrowth = true,
        },
    })
    return true
end

ForesightCharGrowthDetailCtrl._OnClickGoCharBtn = HL.Method(HL.String) << function(self, templateId)
    if string.isEmpty(templateId) then
        return
    end
    local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(templateId)
    if ok and not string.isEmpty(cfg.activityId) and ActivityUtils.isActivityUnlocked(cfg.activityId) then
        self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.ActivityCenter), cfg.activityId)
        PhaseManager:OpenPhase(PhaseId.ActivityCenter, { activityId = cfg.activityId, gotoCenter = true })
        return
    end
    local phase = self.m_phase
    local poolId = phase and phase:FindCharGachaPoolId(templateId)
    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.GachaPool), poolId)
    PhaseManager:OpenPhase(PhaseId.GachaPool, { poolId = poolId })
end

ForesightCharGrowthDetailCtrl._OnClickWeaponLevelUpBtn = HL.Method(HL.Table, HL.String, HL.Opt(HL.Number)) << function(self, info, weaponId, weaponInstId)
    if not info then return end
    if info.instId and info.instId > 0 then
        self:_OnClickRecommendWeaponView(info, weaponId, weaponInstId)
        return
    end
    if not weaponInstId or weaponInstId <= 0 then
        _, _, _, weaponInstId = self.m_phase:GetBestOwnedWeaponInstInfo(weaponId or "")
    end
    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.ValuableDepot), weaponId)
    PhaseManager:OpenPhase(PhaseId.ValuableDepot, {
        depotType = GEnums.ItemValuableDepotType.Weapon,
        itemId = weaponId,
        instId = weaponInstId,
        shouldClearScreenOnOpen = true,
    })
end

ForesightCharGrowthDetailCtrl._OnClickGoWeaponPoolBtn = HL.Method(HL.String) << function(self, weaponId)
    if string.isEmpty(weaponId) then
        return
    end
    local phase = self.m_phase
    if phase then
        local poolId = phase:FindWeaponGachaPoolId(weaponId)
        local gtName = PhaseManager:GetPhaseName(PhaseId.CashShop)
        local itemIdList = weaponId
        if not string.isEmpty(poolId) then
            gtName = PhaseManager:GetPhaseName(PhaseId.GachaWeaponPool)
            itemIdList = poolId .. ";" .. weaponId
        end
        self:_LogCultiOverviewGoTo(gtName, itemIdList)
        phase:JumpToWeaponObtainSource(weaponId)
    end
end

ForesightCharGrowthDetailCtrl._OnClickGemLevelUpBtn = HL.Method(HL.Table, HL.Table, HL.Boolean)
    << function(self, info, header, showBubble)
    if not info or not header then
        return
    end
    if self:_IsJumpBlocked() then
        return
    end
    local weaponId = header.displayWeaponId or ""
    local weaponInstId = header.displayWeaponInstId or 0
    if string.isEmpty(weaponId) or weaponInstId <= 0 then
        return
    end
    local focusedRow = self:_GetFocusedScrollRowCell()
    if focusedRow and focusedRow._growthScrollLuaIndex and focusedRow._growthScrollLuaIndex > 0 then
        self:_SyncScrollListSelectedIndex(focusedRow._growthScrollLuaIndex)
    end
    local phase = self.m_phase
    local stateArg
    if showBubble == true and phase then
        local selectIndex = phase:GetPerfectGoldGemSelectIndex(weaponId, weaponInstId)
        if selectIndex > 0 then
            stateArg = { curSelectedIndex = selectIndex }
        end
    end
    local ok, gemInst = GameInstance.player.inventory:TryGetGemInst(Utils.getCurrentScope(), header.attachedGemInstId)
    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.WeaponInfo), ok and gemInst and gemInst.templateId or "")
    PhaseManager:OpenPhase(PhaseId.WeaponInfo,{
        weaponTemplateId = weaponId,
        weaponInstId = weaponInstId,
        pageType = UIConst.WEAPON_EXHIBIT_PAGE_TYPE.GEM,
        stateArg = stateArg,
        isFocusJump = true,
    })
end

ForesightCharGrowthDetailCtrl._OnClickGemWishBtn = HL.Method(HL.Table, HL.Table)
    << function(self, info, header)
    if not info or not header then
        return
    end
    local phase = self.m_phase
    local weaponId = header.displayWeaponId or ""
    if string.isEmpty(weaponId) or not phase then
        return
    end
    if self.m_gemCellHelper and not self.m_gemCellHelper:_ShouldShowGemWishlist(header) then
        return
    end
    local weaponName = phase:_GetWeaponDisplayName(weaponId)
    if GameInstance.player.inventory.weaponGemWishList:Contains(weaponId) then
        Notify(MessageConst.SHOW_POP_UP, {
            content = string.format(Language.LUA_FORESIGHT_GEM_WISH_REMOVE_CONFIRM, weaponName),
            onConfirm = function()
                Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_REMOVE_SUCCESS)
                phase:TryRemoveWeaponFromGemWishList(weaponId)
            end,
        })
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = string.format(Language.LUA_FORESIGHT_GEM_WISH_ADD_CONFIRM, weaponName),
        onConfirm = function()
            local ok, needFullConfirm = phase:TryAddWeaponToGemWishList(weaponId)
            if not ok and needFullConfirm then
                self:_LogCultiOverviewGoTo("", weaponId, true)
                Notify(MessageConst.SHOW_POP_UP, {
                    content = Language.LUA_GEM_TAG_OBTAIN_WISHLIST_FULL_CONFIRM,
                    onConfirm = function()
                        PhaseManager:OpenPhase(PhaseId.GemWishlist)
                    end,
                })
            end
        end,
    })
end

ForesightCharGrowthDetailCtrl._OnClickGemEnhance = HL.Method(HL.Number) << function(self, gemInstId)
    if not gemInstId or gemInstId <= 0 then
        return
    end
    if self:_IsJumpBlocked() then
        return
    end
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.GemEnhance) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FORESIGHT_GEM_ENHANCE_LOCKED_TOAST)
        return
    end
    local ok, gemInst = GameInstance.player.inventory:TryGetGemInst(Utils.getCurrentScope(), gemInstId)
    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.GemEnhance), ok and gemInst and gemInst.templateId or "")
    PhaseManager:OpenPhase(PhaseId.GemEnhance, { gemInstId = gemInstId })
end

ForesightCharGrowthDetailCtrl._OnClickGainGem = HL.Method(HL.String, HL.Opt(HL.Number)) << function(self, weaponId, attachedGemInstId)
    if string.isEmpty(weaponId) then
        return
    end
    local phase = self.m_phase
    if not phase then
        return
    end
    local info = self.m_selectedInfo
    if self:_IsJumpBlocked() then
        return
    end
    local isCharOwned = info and info.isOwned == true and info.isForesight ~= true
    local itemIdList = ""
    if isCharOwned and attachedGemInstId and attachedGemInstId > 0 then
        local ok, gemInst = GameInstance.player.inventory:TryGetGemInst(Utils.getCurrentScope(), attachedGemInstId)
        itemIdList = ok and gemInst and gemInst.templateId or ""
    end
    local okWeaponItem, weaponItemCfg = Tables.itemTable:TryGetValue(weaponId)
    local isLowRarityWeapon = okWeaponItem and weaponItemCfg.rarity and weaponItemCfg.rarity <= 3
    local inWishList = GameInstance.player.inventory.weaponGemWishList:Contains(weaponId)
    local _, choice = ClientDataManagerInst:GetInt("WeaponAddWishChoice", false, 0, "ForesightCharGrowth")
    if not isLowRarityWeapon and not inWishList then
        if choice == 1 then
            local ok, needFullConfirm = phase:TryAddWeaponToGemWishList(weaponId)
            if not ok and needFullConfirm then
                self:_LogCultiOverviewGoTo("", weaponId, true)
                Notify(MessageConst.SHOW_POP_UP, {
                    content = Language.LUA_GEM_TAG_OBTAIN_WISHLIST_FULL_CONFIRM,
                    onConfirm = function()
                        PhaseManager:OpenPhase(PhaseId.GemWishlist)
                    end,
                })
                return
            end
        elseif choice ~= 2 then
            self:_LogCultiOverviewGoTo(UIManager.m_names[PanelId.GemTagObtain], itemIdList)
            local foresightGoToLog
            if info and info.templateId then
                foresightGoToLog = {
                    charId = info.templateId,
                    charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned"),
                    sourceBlock = self.m_curTabIndex,
                    itemIdList = itemIdList,
                }
            end
            UIManager:Open(PanelId.GemTagObtain, {
                weaponId = weaponId,
                addToWishlist = true,
                foresightGoToLog = foresightGoToLog,
            })
            return
        end
    end
    self:_LogCultiOverviewGoTo(PhaseManager:GetPhaseName(PhaseId.Map), itemIdList)
    phase:JumpToBestGemEnergyPoint(weaponId)
end

ForesightCharGrowthDetailCtrl._RefreshWeaponRecommendListView = HL.Method() << function(self)
    local phase = self.m_phase
    local info = self.m_selectedInfo
    if not phase or not info or not info.templateId then
        return
    end
    self.m_weaponRecommendEntries = phase:GetCharRecommendWeaponEntries(info.templateId)
    if not self:_IsWeaponRecommendListView() then
        local bundle = self.m_curTabBundle
        if bundle then
            self.m_operatorRows = bundle.rows or {}
        end
    end
    self:_RebuildGrowthScrollRowMeta()
    local scrollRowCount = #(self.m_growthScrollRowMeta or {})
    self:_SyncGrowthRewardScrollList()
    self:_SyncGrowthEmptyNode(info, scrollRowCount > 1)
    if DeviceInfo.usingController and self.m_refreshControllerHints then
        self.m_refreshControllerHints()
    end
end

ForesightCharGrowthDetailCtrl._ToggleWeaponRecommendView = HL.Method(HL.String) << function(self, templateId)
    local cur = self.m_weaponRecommendViewByChar[templateId] == true
    self.m_weaponRecommendViewByChar[templateId] = not cur
    self:_RefreshWeaponRecommendListView()
    self:_LogCultiOverviewTabChange(self.m_prevTabIndex)
end




ForesightCharGrowthDetailCtrl._RefreshGoalSelecter = HL.Method(HL.Opt(HL.String)) << function(self, templateId)
    if not self.m_isPanelActive then
        return
    end
    local view = self.m_view
    local goalSelecter = view and view.goalSelecter
    if not goalSelecter or not goalSelecter.gameObject then
        return
    end
    goalSelecter.gameObject:SetActive(true)
    local info = self.m_selectedInfo
    templateId = templateId or (info and info.templateId)
    local phase = self.m_phase
    if not phase then
        return
    end
    local curStageId = phase:GetCharCultivateStageId(templateId)
    self.m_isRefreshingGoal = true
    goalSelecter:Refresh(#self.m_stageIdList, self:_FindStageCsIndex(curStageId), false)
    self.m_isRefreshingGoal = false
end

ForesightCharGrowthDetailCtrl._SetGrowthTab = HL.Method(HL.Number, HL.Boolean, HL.Opt(HL.Boolean))
    << function(self, tabIndex, fromToggle, toggleIsOn)
    if not tabIndex or tabIndex < 1 or tabIndex > 4 then
        return
    end
    if fromToggle and toggleIsOn == false then
        return
    end
    if not self.m_isPanelActive then
        return
    end
    if self.m_curTabIndex == tabIndex then
        if not fromToggle then
            self.m_view[TAB_TOGGLE_KEYS[tabIndex]]:SetIsOnWithoutNotify(true)
        end
        return
    end
    self.m_curTabIndex = tabIndex
    if not fromToggle then
        self.m_view[TAB_TOGGLE_KEYS[tabIndex]]:SetIsOnWithoutNotify(true)
    end
    self:_RefreshGrowthTabByIndex(self.m_curTabIndex)
    self:_LogCultiOverviewTabChange(self.m_prevTabIndex)
end

ForesightCharGrowthDetailCtrl._LogCultiOverviewTabChange = HL.Method(HL.Number) << function(self, phaseTypeBefore)
    local info = self.m_selectedInfo
    if not info or not info.templateId then
        return
    end
    local charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned")
    local weaponPhaseType = 0
    if self.m_curTabIndex == 3 then
        weaponPhaseType = self.m_weaponRecommendViewByChar[info.templateId] and 2 or 1
    end
    EventLogManagerInst:GameEvent_CultiOverviewTabChange(
        info.templateId, self.m_curTabIndex, phaseTypeBefore, weaponPhaseType, charStatus)
    self.m_prevTabIndex = self.m_curTabIndex
end

ForesightCharGrowthDetailCtrl._OnSelectGoalOption = HL.Method(HL.Number) << function(self, index)
    if self.m_isRefreshingGoal then
        return
    end
    local info = self.m_selectedInfo
    local phase = self.m_phase
    if not info or not phase then
        return
    end
    local stageId = self.m_stageIdList[LuaIndex(index)].stageId
    local stageIdBefore,ok = phase:GetCharCultivateStageId(info.templateId)
    if not stageId or stageId == stageIdBefore then
        return
    end
    local charStatus = info.isForesight and "preview" or (info.isOwned and "owned" or "unowned")
    self:_RunCultivateUiAction(function()
        phase:RequestSetCharCultivateStage(info.templateId, stageId, charStatus, ok and stageIdBefore or 0)
    end)
end



HL.Commit(ForesightCharGrowthDetailCtrl)
