








local InputBindingGroupNaviDecoratorType = typeof(CS.Beyond.UI.InputBindingGroupNaviDecorator)
local InputBindingGroupMonoTargetType = typeof(CS.Beyond.Input.InputBindingGroupMonoTarget)
local UISelectableNaviGroupType = typeof(CS.Beyond.UI.UISelectableNaviGroup)
local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')
local GemItemCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailGemItemCell')
local ForesightCharGrowthDetailGemItemCell = GemItemCellModule.ForesightCharGrowthDetailGemItemCell
local s_pairTextDefaultColors = setmetatable({}, { __mode = "k" })

local function _ApplyPairProgressTextStyle(txt, cur, target)
    if not txt then
        return
    end
    if not s_pairTextDefaultColors[txt] then
        s_pairTextDefaultColors[txt] = txt.color
    end
    if cur and target and cur >= target then
        txt.color = UIUtils.getColorByString("c7ff00")
    else
        txt.color = s_pairTextDefaultColors[txt]
    end
end

ForesightCharGrowthDetailCharCell = HL.Class('ForesightCharGrowthDetailCharCell')

ForesightCharGrowthDetailCharCell.m_onLevelUp = HL.Field(HL.Function)
ForesightCharGrowthDetailCharCell.m_onGoChar = HL.Field(HL.Function)

ForesightCharGrowthDetailCharCell.ForesightCharGrowthDetailCharCell = HL.Constructor(HL.Table) << function(self, ctx)
    self.m_onLevelUp = ctx.onLevelUp
    self.m_onGoChar = ctx.onGoChar
end

ForesightCharGrowthDetailCharCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, info, bundle)
    if not cell or not info or not bundle then
        return
    end
    local growthData = bundle.growthData
    local templateId = info.templateId
    local isForesight = info.isForesight == true
    local isOwned = info.isOwned == true and not isForesight
    local inCurGacha = not isForesight and info.isInCurGachaPool == true
    local isGoalReached = isOwned and bundle.isGoalReached == true
    local isCharLvMax = isOwned and (info.level or 0) >= Tables.characterConst.maxLevel

    if cell.headIcon then
        cell.headIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. templateId)
    end
    if cell.nameTxt then
        if not isForesight and cell.nameTxt.SetPhoneticText then
            cell.nameTxt:SetPhoneticText(GEnums.PhoneticType.CharNamePhonetic, templateId)
        else
            CellHelper.SetUiText(cell.nameTxt, info.name or "")
        end
    end
    if cell.curLvNumTxt then
        CellHelper.SetUiText(cell.curLvNumTxt, isOwned and string.format("%d", info.level or 1) or "")
    end
    if cell.curLvLabelNode then
        cell.curLvLabelNode.gameObject:SetActive(isOwned)
    end
    CellHelper.SetUiText(cell.targetLvNumTxt, string.format("%d", (growthData and growthData.targetLevel) or 0))

    local stateName, targetLabelText
    local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(templateId)
    local gotoActivity = ok and not string.isEmpty(cfg.activityId) and ActivityUtils.isActivityUnlocked(cfg.activityId)
    if isOwned then
        if isCharLvMax then
            stateName = "Complete"
        else
            stateName = "GotoLvUp"
            targetLabelText = isGoalReached and Language.LUA_FORESIGHT_GROWTH_LABEL_GOAL_REACHED or Language.LUA_FORESIGHT_GROWTH_LABEL_CUR_TARGET
        end
    elseif gotoActivity then
        stateName, targetLabelText = "GotoActivity", Language.LUA_FORESIGHT_GROWTH_LABEL_CUR_TARGET
    elseif inCurGacha then
        stateName, targetLabelText = "GotoCharPool", Language.LUA_FORESIGHT_GROWTH_LABEL_CUR_TARGET
    else
        stateName, targetLabelText = "GotoDisable", Language.LUA_FORESIGHT_GROWTH_LABEL_TARGET_LEVEL
    end
    if cell.charLevelNode and cell.charLevelNode.SetState then
        cell.charLevelNode:SetState(stateName)
    end
    if cell.targetLabelText then
        CellHelper.SetUiText(cell.targetLabelText, targetLabelText or "")
    end
    if cell.growthLabelText and not isOwned then
        CellHelper.SetUiText(cell.growthLabelText, Language.LUA_FORESIGHT_GROWTH_NOT_OWNED)
    end
    CellHelper.BindClick(cell.levelUpBtn, isOwned and self.m_onLevelUp ~= nil, function()
        self.m_onLevelUp(info)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_LEVELUP)
    CellHelper.BindClick(cell.goCharBtn, (not isOwned) and (inCurGacha or gotoActivity) and self.m_onGoChar ~= nil, function()
        self.m_onGoChar(templateId)
    end, gotoActivity and Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_ACTIVITY_VIEW or Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_CHAR)
end





ForesightCharGrowthDetailRewardsCell = HL.Class('ForesightCharGrowthDetailRewardsCell')

ForesightCharGrowthDetailRewardsCell.m_phase = HL.Field(HL.Forward('PhaseForesightCharGrowth'))
ForesightCharGrowthDetailRewardsCell.m_getShowConverted = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_setShowConverted = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_getSelectedTemplateId = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_getForesightGoToLog = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_onRewardRowNeedRefresh = HL.Field(HL.Function)

ForesightCharGrowthDetailRewardsCell.m_getNaviLeftTarget = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_getDetailHeaderNaviTarget = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_setNaviTarget = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_onRefreshControllerHints = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_onSyncScrollListSelectedIndex = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_getScrollRowNaviTargetAt = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_getScrollRowEquippedGemEq1At = HL.Field(HL.Function)
ForesightCharGrowthDetailRewardsCell.m_gemItemCellHelper = HL.Field(HL.Forward('ForesightCharGrowthDetailGemItemCell'))
ForesightCharGrowthDetailRewardsCell.m_loadGameObject = HL.Field(HL.Function)

ForesightCharGrowthDetailRewardsCell.ForesightCharGrowthDetailRewardsCell = HL.Constructor(HL.Table) << function(self, ctx)
    self.m_phase = ctx.phase
    self.m_getShowConverted = ctx.getShowConverted
    self.m_setShowConverted = ctx.setShowConverted
    self.m_getSelectedTemplateId = ctx.getSelectedTemplateId
    self.m_getForesightGoToLog = ctx.getForesightGoToLog
    self.m_onRewardRowNeedRefresh = ctx.onRewardRowNeedRefresh
    self.m_getDetailHeaderNaviTarget = ctx.getDetailHeaderNaviTarget
    self.m_onRefreshControllerHints = ctx.onRefreshControllerHints
    self.m_onSyncScrollListSelectedIndex = ctx.onSyncScrollListSelectedIndex
    self.m_getScrollRowNaviTargetAt = ctx.getScrollRowNaviTargetAt
    self.m_getScrollRowEquippedGemEq1At = ctx.getScrollRowEquippedGemEq1At
    self.m_gemItemCellHelper = ctx.gemItemCellHelper
    self.m_loadGameObject = ctx.loadGameObject
end


ForesightCharGrowthDetailRewardsCell._ApplyCostItemSlot = HL.Method(HL.Any, HL.Table, HL.Opt(HL.Table))
    << function(self, cell, slot, rowView)
    if not cell or not slot then
        return
    end
    local itemId, needCount, ownedCount
    if slot.isChest then
        itemId = slot.itemId
        needCount = slot.needCount
        if string.isEmpty(itemId) then
            return
        end
        ownedCount = Utils.getItemCount(itemId, true)
    else
        local bundle = slot.bundle
        if not bundle or string.isEmpty(bundle.itemId) then
            return
        end
        itemId = bundle.itemId
        needCount = bundle.count or 0
        if bundle.ownedCount ~= nil then
            ownedCount = bundle.ownedCount
        else
            ownedCount = Utils.getItemCount(itemId, true)
        end
    end
    if cell.gameObject then
        cell.gameObject:SetActive(true)
    end
    if HL.GetTypeName(cell) ~= "Item" and cell.transform then
        cell = Utils.wrapLuaNode(cell)
    end
    if not cell.view then
        return
    end
    local itemExists = Tables.itemTable:ContainsKey(itemId)
    if not itemExists then
        cell:InitItem(nil)
        if cell.view.button then
            cell.view.button.enabled = false
        end
        ForesightCharGrowthDetailRewardsCell._SetCostItemStorageNode(cell, itemId, needCount, nil)
        cell.view.simpleStateController:SetState("Unknown")
        return
    end
    if rowView then
        rowView._hasValidCostItem = true
    end
    cell:InitItem({ id = itemId }, true)
    cell:SetIconTransparent(UIConst.ITEM_EXIST_TRANSPARENCY)
    if cell.view.count then
        local showNeedCount = (needCount or 0) > 0
        cell.view.count.gameObject:SetActive(showNeedCount)
        if showNeedCount then
            CellHelper.SetUiText(cell.view.count, UIUtils.getNumString(needCount))
        end
    end
    ForesightCharGrowthDetailRewardsCell._SetCostItemStorageNode(cell, itemId, needCount, ownedCount)
    if cell.view.animationNode then
        cell.view.animationNode.gameObject:SetActive(true)
    end
end

ForesightCharGrowthDetailRewardsCell._RefreshCostItemSlotList = HL.Method(HL.Table, HL.Table, HL.Opt(HL.Table))
    << function(self, v, slots, layoutOpt)
    layoutOpt = layoutOpt or {}
    slots = slots or {}
    local slotCount = #slots
    local itemTemplate = v.costItemTemplate
    local itemTemplateGo = itemTemplate.gameObject
    local content = v.content
    v.costItemTemplateWidget = v.costItemTemplateWidget or Utils.wrapLuaNode(itemTemplateGo)
    v.costExtraCache = v.costExtraCache or UIUtils.genCellCache(itemTemplate, nil, content)
    v._hasValidCostItem = false

    local extraCount = math.max(0, slotCount - 1)
    v.costExtraCache:Refresh(extraCount, function(cell, index)
        self:_ApplyCostItemSlot(cell, slots[index + 1], v)
        local cellWidget = HL.GetTypeName(cell) == "Item" and cell or Utils.wrapLuaNode(cell.gameObject)
        self:_ApplyCostItemControllerExtra(v, cellWidget)
    end)

    if slotCount >= 1 then
        itemTemplateGo:SetActive(true)
        self:_ApplyCostItemSlot(v.costItemTemplateWidget, slots[1], v)
        self:_ApplyCostItemControllerExtra(v, v.costItemTemplateWidget)
        local siblingIndex = itemTemplate:GetSiblingIndex() + 1
        local cutBeforeExtraIndex = layoutOpt.cutLineBeforeChest and extraCount or nil
        for index = 1, extraCount do
            if cutBeforeExtraIndex and index == cutBeforeExtraIndex and v.costCutLine then
                v.costCutLine.gameObject:SetActive(true)
                v.costCutLine:SetSiblingIndex(siblingIndex)
                siblingIndex = siblingIndex + 1
            end
            local itemCell = v.costExtraCache:GetItem(index)
            if itemCell and itemCell.gameObject then
                itemCell.gameObject:SetActive(true)
                itemCell.transform:SetSiblingIndex(siblingIndex)
                siblingIndex = siblingIndex + 1
            end
        end
    else
        itemTemplateGo:SetActive(false)
    end
    if v.costCutLine and not layoutOpt.cutLineBeforeChest then
        v.costCutLine.gameObject:SetActive(false)
    end
    if content then
        CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(content)
    end
end

ForesightCharGrowthDetailRewardsCell._BuildItemSlotsFromList = HL.StaticMethod(HL.Table).Return(HL.Table)
    << function(itemList)
    local slots = {}
    for _, entry in ipairs(itemList or {}) do
        if entry and not string.isEmpty(entry.itemId) and ((entry.count or 0) > 0 or not Tables.itemTable:ContainsKey(entry.itemId)) then
            slots[#slots + 1] = { bundle = entry }
        end
    end
    return slots
end


ForesightCharGrowthDetailRewardsCell._ResetRewardRowAuxiliaryUI = HL.Method(HL.Table) << function(self, v)
    if not v then
        return
    end
    if v.exchangeNode and v.exchangeNode.gameObject then
        v.exchangeNode.gameObject:SetActive(false)
    end
    if v.conversionTog and v.conversionTog.gameObject then
        v.conversionTog.gameObject:SetActive(false)
    end
    if v.costCutLine and v.costCutLine.gameObject then
        v.costCutLine.gameObject:SetActive(false)
    end
    if v.descTxt then
        CellHelper.SetUiText(v.descTxt, "")
    end
    if v.exchangeNodeCache then
        v.exchangeNodeCache:Refresh(0)
    end
end

ForesightCharGrowthDetailRewardsCell._SetCostItemStorageNode = HL.StaticMethod(HL.Any, HL.String, HL.Number, HL.Opt(HL.Number))
    << function(cell, itemId, needCount, ownedCount)
    if not cell or not cell.transform or string.isEmpty(itemId) then
        return
    end
    local storageNode = cell.transform:Find("StorageNode")
    if not storageNode then
        return
    end
    local haveTextTransform = storageNode:Find("HaveText")
    if haveTextTransform then
        local haveText = haveTextTransform:GetComponent(typeof(CS.Beyond.UI.UIText))
        CellHelper.SetUiText(haveText, I18nUtils.CombineStringWithLanguageSpilt(Language.LUA_FORESIGHT_GROWTH_OWNED_FORMAT, ""))
    end
    local haveNumTransform = storageNode:Find("HaveNum")
    if haveNumTransform then
        local haveNum = haveNumTransform:GetComponent(typeof(CS.Beyond.UI.UIText))
        if ownedCount == nil then
            CellHelper.SetUiText(haveNum, "-")
        else
            local isLack = ownedCount < (needCount or 0)
            CellHelper.SetUiText(
                haveNum,
                UIUtils.setCountColor(UIUtils.getNumString(ownedCount), isLack)
            )
        end
    end
end

ForesightCharGrowthDetailRewardsCell._GetRewardScrollNaviGroup = HL.Method(HL.Table).Return(HL.Opt(HL.Userdata))
    << function(self, v)
    if not v or not v.scrollView then
        return nil
    end
    
    local naviGroup = v.scrollView:GetComponent(UISelectableNaviGroupType)
    if naviGroup then
        return naviGroup
    end
    if v.content then
        return v.content:GetComponent(UISelectableNaviGroupType)
    end
    return nil
end

ForesightCharGrowthDetailRewardsCell._GetFirstCostItemButton = HL.Method(HL.Table).Return(HL.Opt(HL.Userdata))
    << function(self, v)
    if not v then
        return nil
    end
    if v.costItemTemplateWidget and v.costItemTemplateWidget.view and v.costItemTemplateWidget.view.button then
        local button = v.costItemTemplateWidget.view.button
        if button.gameObject.activeInHierarchy and button.isActiveAndEnabled then
            return button
        end
    end
    if v.costExtraCache then
        for index = 1, v.costExtraCache:GetCount() do
            local itemGo = v.costExtraCache:GetItem(index)
            if itemGo then
                local itemWidget = HL.GetTypeName(itemGo) == "Item" and itemGo or Utils.wrapLuaNode(itemGo.gameObject)
                local button = itemWidget and itemWidget.view and itemWidget.view.button
                if button and button.gameObject.activeInHierarchy and button.isActiveAndEnabled then
                    return button
                end
            end
        end
    end
    return nil
end



ForesightCharGrowthDetailRewardsCell._ApplyCostItemControllerExtra = HL.Method(HL.Table, HL.Any)
    << function(self, v, cellWidget)
    if not DeviceInfo.usingController or not cellWidget or not cellWidget.view or not cellWidget.view.button then
        return
    end
    if string.isEmpty(cellWidget.id) then
        return
    end
    cellWidget:SetEnableHoverTips(false)
    cellWidget:SetExtraInfo({
        tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
        tipsPosTransform = cellWidget.view.content,
        isSideTips = true,
        onBeforeJump = function()
            if DeviceInfo.usingController then
                local naviGroup = self:_GetRewardScrollNaviGroup(v)
                if naviGroup then
                    naviGroup:ManuallyStopFocus()
                end
            end
        end,
    })
    cellWidget.customShowTipsFunc = function()
        if self.m_onRefreshControllerHints then
            self.m_onRefreshControllerHints(true)
        end
    end
    cellWidget.customHideTipsFunc = function()
        if self.m_onRefreshControllerHints then
            self.m_onRefreshControllerHints(false)
        end
    end
    cellWidget.view.button.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            cellWidget:ShowTips()
        end
    end
end

ForesightCharGrowthDetailRewardsCell._RefreshExchangeItemIconCell = HL.Method(HL.Any, HL.Table)
    << function(self, cell, bundle)
    if not cell or not bundle or string.isEmpty(bundle.itemId) then
        return
    end
    if HL.GetTypeName(cell) ~= "ItemIcon" and cell.transform then
        cell = Utils.wrapLuaNode(cell)
    end
    cell:InitItemIcon(bundle.itemId)
end

ForesightCharGrowthDetailRewardsCell._RefreshCostListItems = HL.Method(HL.Table, HL.Table) << function(self, v, itemList)
    self:_RefreshCostItemSlotList(v, ForesightCharGrowthDetailRewardsCell._BuildItemSlotsFromList(itemList))
end

ForesightCharGrowthDetailRewardsCell._CalcPreciousChestNeedCount = HL.StaticMethod(HL.Table).Return(HL.Number) << function(materials)
    local chestNeed = 0
    for _, entry in ipairs(materials or {}) do
        if entry.itemId and (entry.count or 0) > 0 then
            local deficit = math.max(0, (entry.count or 0) - Utils.getItemCount(entry.itemId, true))
            if deficit > 0 then
                chestNeed = chestNeed + math.ceil(deficit / 2)
            end
        end
    end
    return chestNeed
end


ForesightCharGrowthDetailRewardsCell._RefreshPreciousCostListItems = HL.Method(HL.Table, HL.Table)
    << function(self, v, preciousData)
    local materials = preciousData.materials or {}
    local chestItemId = preciousData.chestItemId or ""
    local hasChest = not string.isEmpty(chestItemId)
    local slots = ForesightCharGrowthDetailRewardsCell._BuildItemSlotsFromList(materials)
    local hasMaterialSlots = #slots > 0
    if hasChest then
        local chestNeedCount = ForesightCharGrowthDetailRewardsCell._CalcPreciousChestNeedCount(materials)
        slots[#slots + 1] = {
            isChest = true,
            itemId = chestItemId,
            needCount = chestNeedCount,
        }
    end
    self:_RefreshCostItemSlotList(v, slots, {
        cutLineBeforeChest = hasChest and hasMaterialSlots,
    })
end

ForesightCharGrowthDetailRewardsCell._RefreshExchangeItemIcons = HL.Method(HL.Table, HL.Table) << function(self, v, itemList)
    itemList = itemList or {}
    local node = v.exchangeNode
    if #itemList <= 0 or not node then
        if v.exchangeNodeCache then
            v.exchangeNodeCache:Refresh(0)
        end
        return
    end
    v.exchangeNodeCache = v.exchangeNodeCache or UIUtils.genCellCache(node.exchangeItemIconTemplate, nil, node.exchangeCostList)
    v.exchangeNodeCache:Refresh(#itemList, function(cell, index)
        self:_RefreshExchangeItemIconCell(cell, itemList[index])
    end)
end

ForesightCharGrowthDetailRewardsCell._ApplyFunctionBtnState = HL.Method(HL.Table, HL.String) << function(self, v, key)
    if not v then
        return
    end
    local isObtain = key == "PreciousItem"
    if not v.functionBtnState and v.btnGet then
        v.functionBtnState = v.btnGet.gameObject:GetComponent(typeof(CS.Beyond.UI.UIState.UIStateController))
    end
    if v.functionBtnState and v.functionBtnState.SetState then
        v.functionBtnState:SetState(isObtain and "Obtain" or "Goto")
    end
    if not v.functionTxt and v.btnGet then
        local txtTransform = v.btnGet.transform:Find("FunctionTxt")
        if txtTransform then
            v.functionTxt = txtTransform:GetComponent(typeof(CS.Beyond.UI.UIText))
        end
    end
    CellHelper.SetUiText(
        v.functionTxt,
        isObtain and Language.LUA_FORESIGHT_GROWTH_CTRL_CHECK_OBTAIN_WAY or Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_GET
    )
    if v.btnGet then
        v.btnGet.customBindingViewLabelText = isObtain and Language.LUA_FORESIGHT_GROWTH_CTRL_CHECK_OBTAIN_WAY or Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_GET
    end
end


ForesightCharGrowthDetailRewardsCell._SyncRewardScrollViewWidth = HL.Method(HL.Table) << function(self, v)
    if not v or not v.scrollView then
        return
    end
    local scrollViewTransform = v.scrollView.transform
    if not scrollViewTransform then
        return
    end
    if not v._rewardScrollViewMaxWidth then
        local initialWidth = scrollViewTransform.rect.width
        if initialWidth > 0 then
            v._rewardScrollViewMaxWidth = initialWidth
        end
    end
    local maxWidth = v._rewardScrollViewMaxWidth
    if not maxWidth or maxWidth <= 0 then
        return
    end
    local contentTransform = v.content
    if not contentTransform then
        return
    end
    CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(contentTransform)
    local contentWidth = CS.UnityEngine.UI.LayoutUtility.GetPreferredWidth(contentTransform)
    local targetWidth = math.min(math.max(contentWidth, 0), maxWidth)
    scrollViewTransform:SetSizeWithCurrentAnchors(CS.UnityEngine.RectTransform.Axis.Horizontal, targetWidth)
end



local function isTransformUnderRowCell(rowCell, transform)
    if not rowCell or not rowCell.gameObject or not transform then
        return false
    end
    local t = transform
    while t do
        if t.gameObject == rowCell.gameObject then
            return true
        end
        t = t.parent
    end
    return false
end

local function isFocusStillWithinRow(rowCell)
    if not rowCell then
        return false
    end
    local naviMgr = InputManagerInst and InputManagerInst.controllerNaviManager
    local cur = naviMgr and naviMgr.curTarget
    if not cur or not cur.transform then
        return false
    end
    return isTransformUnderRowCell(rowCell, cur.transform)
end


ForesightCharGrowthDetailRewardsCell.CollectFocusHintGroupIds = HL.Method(HL.Table).Return(HL.Table)
    << function(self, rowCell)
    local groupIds = {}
    local function appendUnique(groupId)
        if not groupId or groupId <= 0 then
            return
        end
        for _, id in ipairs(groupIds) do
            if id == groupId then
                return
            end
        end
        groupIds[#groupIds + 1] = groupId
    end
    if not rowCell or not rowCell.gameObject then
        return groupIds
    end
    local cur = InputManagerInst.controllerNaviManager.curTarget
    local mode = rowCell._growthRowDisplayMode or "material"
    local rowMono = rowCell.cacheCellTarget
    if mode == "gemItem" then
        appendUnique(rowMono and rowMono.groupId)
        if cur and cur.transform and isFocusStillWithinRow(rowCell) then
            local t = cur.transform
            while t and t.gameObject ~= rowCell.gameObject do
                local pathMono = t.gameObject:GetComponent(InputBindingGroupMonoTargetType)
                appendUnique(pathMono and pathMono.groupId)
                t = t.parent
            end
        end
        return groupIds
    end
    if not cur or not cur.transform or not isFocusStillWithinRow(rowCell) then
        return groupIds
    end
    local t = cur.transform
    while t do
        if t.gameObject == rowCell.gameObject then
            appendUnique(rowMono and rowMono.groupId)
            break
        end
        local pathMono = t.gameObject:GetComponent(InputBindingGroupMonoTargetType)
        if pathMono and pathMono.groupId and pathMono.groupId > 0 then
            appendUnique(pathMono.groupId)
            break
        end
        t = t.parent
    end
    return groupIds
end

ForesightCharGrowthDetailRewardsCell._ToggleRowBindingGroup = HL.Method(HL.Table, HL.Boolean)
    << function(self, rowCell, isOn)
    if not rowCell or not rowCell.gameObject then
        return
    end
    local mono = rowCell.cacheCellTarget
    if mono and mono.groupId and mono.groupId > 0 then
        InputManagerInst:ToggleGroup(mono.groupId, isOn == true)
    end
end


ForesightCharGrowthDetailRewardsCell._SyncGemItemRowWrapNaviState = HL.Method(HL.Table, HL.Table)
    << function(self, rowCell, innerCell)
    if not DeviceInfo.usingController or not rowCell or not innerCell then
        return
    end
    local rowDecorator = rowCell.cacheCellDecorator
    if not rowDecorator then
        return
    end
    rowDecorator.enableControllerNavi = true
    rowDecorator.interactable = true
    local detailState = innerCell._gemItemDetailState or ""
    ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, false)
    if detailState == "Equipped" then
        ForesightCharGrowthDetailGemItemCell._SetSubButtonWrapNaviEnabled(innerCell, false)
        ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, true)
    else
        ForesightCharGrowthDetailGemItemCell._SetSubButtonWrapNaviEnabled(innerCell, true)
        ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, false)
    end
end

ForesightCharGrowthDetailRewardsCell._DeferEquippedGemEqFocus = HL.Method(HL.Table, HL.Table, HL.Userdata)
    << function(self, rowCell, innerCell, eq1)
    if innerCell._gemEqHandoffCor then
        CoroutineManager:ClearCoroutine(innerCell._gemEqHandoffCor)
        innerCell._gemEqHandoffCor = nil
    end
    innerCell._gemEqHandoffPending = true
    innerCell._gemEqHandoffCor = CoroutineManager:StartCoroutine(function()
        coroutine.step()
        if not DeviceInfo.usingController or not eq1 then
            innerCell._gemEqHandoffPending = false
            innerCell._gemEqHandoffCor = nil
            return
        end
        local naviMgr = InputManagerInst and InputManagerInst.controllerNaviManager
        local curTarget = naviMgr and naviMgr.curTarget
        
        
        if curTarget ~= eq1 and curTarget ~= innerCell.eq2 then
            ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, true)
            self.m_setNaviTarget(eq1)
            if naviMgr and naviMgr.UpdateNaviInputBindingState then
                naviMgr:UpdateNaviInputBindingState()
            end
        end
        
        innerCell._gemEqHandoffPending = false
        innerCell._gemEqHandoffCor = nil
    end)
end


ForesightCharGrowthDetailRewardsCell._ApplyGemItemRowControllerFocus = HL.Method(HL.Table, HL.Boolean)
    << function(self, rowCell, isTarget)
    local innerCell = rowCell._growthGemItemCell
    if not innerCell then
        return
    end
    if not isTarget then
        if innerCell._gemEqHandoffPending then
            return
        end
        local curTarget = InputManagerInst and InputManagerInst.controllerNaviManager
            and InputManagerInst.controllerNaviManager.curTarget
        if innerCell._gemItemDetailState == "Equipped" and curTarget then
            if curTarget == innerCell.eq1 or curTarget == innerCell.eq2 then
                return
            end
        end
        ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(innerCell, false)
        self.m_gemItemCellHelper:ApplyControllerFocus(innerCell, false)
        return
    end
    if innerCell._gemItemDetailState == "Equipped" and innerCell.eq1 then
        self:_DeferEquippedGemEqFocus(rowCell, innerCell, innerCell.eq1)
        return
    end
    self.m_gemItemCellHelper:ApplyControllerFocus(innerCell, true, "row")
end

ForesightCharGrowthDetailRewardsCell._OnRowRootNaviTargetChanged = HL.Method(HL.Table, HL.Boolean) << function(self, rowCell, isTarget)
    if not isTarget and not isFocusStillWithinRow(rowCell) then
        self:HideCommonTipsIfVisible()
        Notify(MessageConst.HIDE_ITEM_TIPS)
    end
    if isTarget and rowCell._growthScrollLuaIndex then
        self.m_onSyncScrollListSelectedIndex(rowCell._growthScrollLuaIndex)
    end
    local focusActive = isTarget == true
    if not focusActive then
        local naviMgr = InputManagerInst and InputManagerInst.controllerNaviManager
        local cur = naviMgr and naviMgr.curTarget
        local decorator = rowCell.cacheCellDecorator
        if cur and decorator and cur ~= decorator and isFocusStillWithinRow(rowCell) then
            focusActive = true
        end
    end
    local mode = rowCell._growthRowDisplayMode or "material"
    if mode == "header" then
        local innerCell = rowCell._growthHeaderCell
        if innerCell and innerCell._gemCellShowBubble == true and innerCell.growthGemBubbleBtnStateController then
            innerCell.growthGemBubbleBtnStateController:SetState(focusActive and "Expand" or "Close")
        end
    elseif mode == "gemItem" then
        self:_ApplyGemItemRowControllerFocus(rowCell, focusActive)
    end
    self.m_onRefreshControllerHints()
end


ForesightCharGrowthDetailRewardsCell.WireRowRootNaviOnce = HL.Method(HL.Table, HL.Number)
    << function(self, rowCell, scrollLuaIndex)
    if not DeviceInfo.usingController or not rowCell then
        return
    end
    local mode = rowCell._growthRowDisplayMode or "material"
    local alreadyWired = rowCell._growthNavWired and rowCell._growthScrollLuaIndex == scrollLuaIndex
        and rowCell._growthNavWiredDisplayMode == mode
    if not alreadyWired then
        rowCell._growthNavWired = false
        rowCell._growthScrollLuaIndex = scrollLuaIndex
        local decorator = rowCell.cacheCellDecorator
        if not decorator then
            return
        end
        decorator.enableControllerNavi = true
        decorator.interactable = true
        decorator.useExplicitNaviSelect = false
        decorator.banExplicitOnLeft = true
        decorator.banExplicitOnRight = true
        decorator.customNaviTargetInDirFunc = function(dir)
            local liveIndex = rowCell._growthScrollLuaIndex or scrollLuaIndex
            if liveIndex == 1 and dir == CS.UnityEngine.UI.NaviDirection.Up then
                return self.m_getDetailHeaderNaviTarget()
            end
            if dir == CS.UnityEngine.UI.NaviDirection.Left then
                return self.m_getNaviLeftTarget()
            end
            if dir == CS.UnityEngine.UI.NaviDirection.Right then
                return decorator
            end
            if dir == CS.UnityEngine.UI.NaviDirection.Down then
                local rowMode = rowCell._growthRowDisplayMode
                if rowMode == "header" then
                    local eq1 = self.m_getScrollRowEquippedGemEq1At(liveIndex + 1)
                    if eq1 then
                        return eq1
                    end
                elseif rowMode == "gemItem" then
                    local innerCell = rowCell._growthGemItemCell
                    if innerCell and innerCell._gemItemDetailState == "Equipped" and innerCell.eq1 then
                        return innerCell.eq1
                    end
                end
            end
            if dir == CS.UnityEngine.UI.NaviDirection.Up and liveIndex > 1 then
                return self.m_getScrollRowNaviTargetAt(liveIndex - 1)
            end
            return nil
        end
        decorator.onGroupSetAsNaviTarget:RemoveAllListeners()
        decorator.onGroupSetAsNaviTarget:AddListener(function(isTarget)
            if not DeviceInfo.usingController then
                return
            end
            self:_OnRowRootNaviTargetChanged(rowCell, isTarget)
        end)
        rowCell._growthNavWired = true
        rowCell._growthNavWiredDisplayMode = mode
        if decorator.isNaviTarget then
            self:_OnRowRootNaviTargetChanged(rowCell, true)
        end
    end
    if mode == "gemItem" then
        local innerCell = rowCell._growthGemItemCell
        if innerCell then
            self:_SyncGemItemRowWrapNaviState(rowCell, innerCell)
        end
    end
    local decorator = rowCell.cacheCellDecorator
    if alreadyWired and decorator and decorator.isNaviTarget then
        self:_OnRowRootNaviTargetChanged(rowCell, true)
    end
end



ForesightCharGrowthDetailRewardsCell._GetRowDescriptionTipsText = HL.Method(HL.String).Return(HL.String) << function(self, key)
    if key == "Exp" then
        return Language.LUA_FORESIGHT_GROWTH_EXP_EXCHANGE_TIPS
    elseif key == "Collect" then
        return Language.LUA_FORESIGHT_GROWTH_COLLECT_TIPS
    elseif key == "Precious" then
        return Language.LUA_FORESIGHT_GROWTH_PRECIOUS_TIPS
    end
    return ""
end

ForesightCharGrowthDetailRewardsCell._UnbindTipsArrowClose = HL.Method() << function(self)
    local phase = self.m_phase
    local func = phase.m_tipsArrowCloseFunc
    if not func then return end
    local commonTipsCtrl = UIManager:AutoOpen(PanelId.CommonTips)
    if commonTipsCtrl then
        commonTipsCtrl.view.main.onTriggerAutoClose:RemoveListener(func)
    end
    phase.m_tipsArrowCloseFunc = nil
    if phase.m_tipsArrow then
        phase.m_tipsArrow.gameObject:SetActive(false)
        phase.m_tipsArrow = nil
    end
end

ForesightCharGrowthDetailRewardsCell.HideCommonTipsIfVisible = HL.Method() << function(self)
    local commonTipsCtrl = UIManager:AutoOpen(PanelId.CommonTips)
    if not commonTipsCtrl or not commonTipsCtrl.view.main.gameObject.activeSelf then
        return
    end
    self:_UnbindTipsArrowClose()
    commonTipsCtrl.view.main.gameObject:SetActive(false)
    commonTipsCtrl.view.controllerHintPlaceholder.gameObject:SetActive(false)
    commonTipsCtrl:ChangeCurPanelBlockSetting(false)
end

ForesightCharGrowthDetailRewardsCell._ShowRewardCommonTips = HL.Method(HL.Userdata, HL.String, HL.Opt(HL.Boolean)) << function(self, anchorTransform, text, isSideTips)
    if not anchorTransform or string.isEmpty(text) then
        return
    end
    local commonTipsCtrl = UIManager:AutoOpen(PanelId.CommonTips)
    if not commonTipsCtrl then
        return
    end
    local phase = self.m_phase
    self:_UnbindTipsArrowClose()
    anchorTransform.gameObject:SetActive(true)
    phase.m_tipsArrow = anchorTransform
    phase.m_tipsArrowCloseFunc = function() self:_UnbindTipsArrowClose() end
    commonTipsCtrl.view.main.onTriggerAutoClose:AddListener(phase.m_tipsArrowCloseFunc)
    commonTipsCtrl:ShowTips({
        stateType = "GrowthDeco",
        text = text,
        transform = anchorTransform,
        posType = UIConst.UI_TIPS_POS_TYPE.LeftAlignTop,
    })
    if isSideTips then
        commonTipsCtrl:ChangeCurPanelBlockSetting(false)
        commonTipsCtrl.view.controllerHintPlaceholder.gameObject:SetActive(false)
    end
end

ForesightCharGrowthDetailRewardsCell._BindDescriptionTipsClick = HL.Method(HL.Table, HL.String) << function(self, v, key)
    if string.isEmpty(self:_GetRowDescriptionTipsText(key)) then
        return
    end
    if v.descriptionNode and v.descriptionNode.gameObject.activeSelf then
        local descBtn = v.descriptionNode.transform:Find("DescriptionBtn"):GetComponent(typeof(CS.Beyond.UI.UIButton))
        descBtn.onClick:RemoveAllListeners()
        descBtn.onClick:AddListener(function()
            local text = self:_GetRowDescriptionTipsText(key)
            self:_ShowRewardCommonTips(v.iconArrow1, text)
        end)
    end
    if key == "Exp" and v.exchangeNode and v.exchangeNode.gameObject.activeInHierarchy then
        local exchangeBtn = v.exchangeNode.descriptionBtn
        if exchangeBtn then
            exchangeBtn.onClick:RemoveAllListeners()
            exchangeBtn.onClick:AddListener(function()
                local text = self:_GetRowDescriptionTipsText("Exp")
                self:_ShowRewardCommonTips(v.iconArrow2, text, true)
            end)
        end
    end
end


ForesightCharGrowthDetailRewardsCell._SetupCostItemsSubNav = HL.Method(HL.Table, HL.String)
    << function(self, v, key)
    if not v or not v.scrollView then
        return
    end
    local naviGroup = self:_GetRewardScrollNaviGroup(v)
    if not naviGroup then
        return
    end
    naviGroup.enabled = v._hasValidCostItem == true

    naviGroup.onIsFocusedChange:RemoveAllListeners()
    naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
            if not isFocusStillWithinRow(v) then
                self:HideCommonTipsIfVisible()
            end
        end
    end)
    if naviGroup.onIsTopLayerChanged then
        naviGroup.onIsTopLayerChanged:RemoveAllListeners()
        naviGroup.onIsTopLayerChanged:AddListener(function()
            if UIManager:IsShow(PanelId.ItemTips) and self.m_onRefreshControllerHints then
                self.m_onRefreshControllerHints(true)
            end
        end)
    end

    naviGroup.getDefaultSelectableFunc = function()
        if key == "Exp" and v.exchangeNode then
            local exchangeGo = v.exchangeNode.gameObject
            if exchangeGo.activeInHierarchy then
                local exchangeDecorator = exchangeGo:GetComponent(InputBindingGroupNaviDecoratorType)
                if exchangeDecorator and exchangeDecorator.gameObject.activeInHierarchy
                    and exchangeDecorator.isActiveAndEnabled then
                    return exchangeDecorator
                end
            end
        end
        return self:_GetFirstCostItemButton(v)
    end

    if key == "Exp" and v.exchangeNode then
        local exchangeGo = v.exchangeNode.gameObject
        local exchangeDecorator = exchangeGo:GetComponent(InputBindingGroupNaviDecoratorType)
        if exchangeDecorator then
            
            exchangeDecorator.enableControllerNavi = true
            exchangeDecorator.onGroupSetAsNaviTarget:RemoveAllListeners()
            exchangeDecorator.onGroupSetAsNaviTarget:AddListener(function(isTarget)
                if isTarget then
                    Notify(MessageConst.HIDE_ITEM_TIPS)
                    self:_ShowRewardCommonTips(v.iconArrow2, self:_GetRowDescriptionTipsText("Exp"), true)
                else
                    self:HideCommonTipsIfVisible()
                end
            end)
        end
    end
end

ForesightCharGrowthDetailRewardsCell._SetupExpConversionToggle = HL.Method(HL.Table)
    << function(self, v)
    if not v.conversionTog then
        return
    end
    local showConverted = self.m_getShowConverted()
    v.conversionTog.onValueChanged:RemoveAllListeners()
    v.conversionTog:SetIsOnWithoutNotify(showConverted)
    v.conversionTog.onValueChanged:AddListener(function(isOn)
        local isConverted = isOn == true
        self.m_setShowConverted(isConverted)
        if v.descriptionNode then
            v.descriptionNode.gameObject:SetActive(false)
        end
        if self.m_onRewardRowNeedRefresh then
            self.m_onRewardRowNeedRefresh()
        end
    end)
end

ForesightCharGrowthDetailRewardsCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Opt(HL.Number)) << function(self, v, rowData, luaIndex)
    if not v then return end
    local key = rowData.key
    local data = rowData.data
    v._rewardRowLuaIndex = luaIndex
    self:_ResetRewardRowAuxiliaryUI(v)
    if v.descTxt then
        CellHelper.SetUiText(v.descTxt, rowData.name or "")
    end
    if v.togText then
        CellHelper.SetUiText(v.togText, Language.LUA_FORESIGHT_GROWTH_SHOW_CONVERT)
    end
    CellHelper.SetNodeActive(v.iconArrow1, false)
    CellHelper.SetNodeActive(v.iconArrow2, false)
    if v.descriptionNode then
        
        v.descriptionNode.gameObject:SetActive(key == "Collect" or key == "Precious")
    end
    if key == "Exp" then
        if v.detailStateNode and v.detailStateNode.gameObject then
            v.detailStateNode.gameObject:SetActive(true)
        end
        if v.conversionTog and v.conversionTog.gameObject then
            v.conversionTog.gameObject:SetActive(true)
        end
        self:_SetupExpConversionToggle(v)
        local rawList = data.rawList or {}
        local showConverted = self.m_getShowConverted()
        if v.detailStateNode and v.detailStateNode.SetState then
            v.detailStateNode:SetState(showConverted and "CheckWay" or "Conversion")
        end
        self:_RefreshCostListItems(v, showConverted and (data.convertedList or {}) or rawList)
        if showConverted then
            local exchangeItems
            if v._foresightExpExchangeIsWeapon then
                exchangeItems = {
                    { itemId = "item_weapon_expcard_mid" },
                    { itemId = "item_weapon_expcard_high" },
                }
            else
                local templateId = self.m_getSelectedTemplateId and self.m_getSelectedTemplateId() or ""
                local targetLevel = rowData.targetLevel or 0
                local startLevel = 1
                if self.m_phase and not string.isEmpty(templateId) then
                    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
                    if playerChar and CharInfoUtils.IsServerDefaultChar(playerChar) then
                        startLevel = playerChar.level or 1
                    end
                end
                exchangeItems = {}
                if startLevel <= 60 then
                    exchangeItems[#exchangeItems + 1] = { itemId = "item_expcard_stage1_mid" }
                    exchangeItems[#exchangeItems + 1] = { itemId = "item_expcard_stage1_high" }
                end
                if targetLevel > 60 then
                    exchangeItems[#exchangeItems + 1] = { itemId = "item_expcard_stage2_high" }
                end
            end
            if #exchangeItems > 0 and self.m_loadGameObject and v.content then
                if not (v.exchangeNode and v.exchangeNode.gameObject) then
                    local prefab = self.m_loadGameObject("Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CharInfo/Widgets/GrowthDetailExchangeNode.prefab")
                    local go = prefab and CSUtils.CreateObject(prefab, v.content)
                    if go then
                        v.exchangeNode = Utils.wrapLuaNode(go)
                        v.iconArrow2 = v.exchangeNode.iconArrow2
                        CellHelper.SetNodeActive(v.iconArrow2, false)
                        local navi = v.content:GetComponent(UISelectableNaviGroupType)
                        local bind = go:GetComponent(InputBindingGroupMonoTargetType)
                        if navi and bind then
                            navi.relatedInputBindingGroups:Add(bind)
                        end
                    end
                end
                if v.exchangeNode and v.exchangeNode.gameObject then
                    v.exchangeNode.gameObject:SetActive(true)
                    v.exchangeNode.transform:SetSiblingIndex(2)
                    self:_RefreshExchangeItemIcons(v, exchangeItems)
                end
            end
        end
    elseif key == "Precious" and data.materials then
        self:_RefreshPreciousCostListItems(v, data)
    elseif key == "PreciousItem" then
        self:_RefreshCostListItems(v, data)
    else
        self:_RefreshCostListItems(v, data)
    end
    self:_ApplyFunctionBtnState(v, key)
    local hasValid = v._hasValidCostItem == true
    CellHelper.SetNodeActive(v.disableBtn, not hasValid)
    CellHelper.SetNodeActive(v.btnGet, hasValid)
    CellHelper.BindClick(v.btnGet, v.btnGet ~= nil, function()
            if v._growthScrollLuaIndex and v._growthScrollLuaIndex > 0 and self.m_onSyncScrollListSelectedIndex then
                self.m_onSyncScrollListSelectedIndex(v._growthScrollLuaIndex)
            end
            self:_OnClickBtnGet(rowData, luaIndex)
        end, key == "PreciousItem" and Language.LUA_FORESIGHT_GROWTH_CTRL_CHECK_OBTAIN_WAY or Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_GET)
    self:_BindDescriptionTipsClick(v, key)
    v._growthScrollControllerMaterialOpt = { materialKey = key, materialLuaIndex = luaIndex }
    if DeviceInfo.usingController then
        self:_SetupCostItemsSubNav(v, key)
    end
    self:_SyncRewardScrollViewWidth(v)
end

ForesightCharGrowthDetailRewardsCell._PickJumpTargetItemId = HL.Method(HL.Table).Return(HL.String) << function(self, itemList)
    if not itemList or #itemList == 0 then
        return ""
    end
    local lastValidItemId
    for _, entry in ipairs(itemList) do
        if not string.isEmpty(entry.itemId) and (entry.count or 0) > 0
            and Tables.itemTable:ContainsKey(entry.itemId) then
            lastValidItemId = entry.itemId
            local owned = entry.ownedCount
            if owned == nil then
                owned = Utils.getItemCount(entry.itemId, true)
            end
            if owned < entry.count then
                return entry.itemId
            end
        end
    end
    return lastValidItemId or ""
end

ForesightCharGrowthDetailRewardsCell._OnClickBtnGet = HL.Method(HL.Table, HL.Opt(HL.Number)) << function(self, rowData, rewardLuaIndex)
    if not self.m_phase then
        return
    end
    local data = rowData.data
    if rowData.key == "Exp" then
        rewardLuaIndex = rewardLuaIndex or rowData._rewardRowLuaIndex
        local showConverted = self.m_getShowConverted()
        data = showConverted and data.convertedList or data.rawList
    end
    if rowData.key == "Precious" and data.materials then
        data = data.materials
    end
    if rowData.key == "PreciousItem" then
        local itemId = self:_PickJumpTargetItemId(data)
        if string.isEmpty(itemId) then
            return
        end
        UIManager:Open(PanelId.PreciousItemObtain, {
            itemId = itemId,
            foresightGoToLog = self.m_getForesightGoToLog and self.m_getForesightGoToLog() or nil,
        })
        return
    end
    self.m_phase:JumpToItemObtian(data,self.m_getForesightGoToLog and self.m_getForesightGoToLog() or nil)
end



HL.Commit(ForesightCharGrowthDetailCharCell)
HL.Commit(ForesightCharGrowthDetailRewardsCell)



ForesightCharGrowthDetailSkillCell = HL.Class('ForesightCharGrowthDetailSkillCell')

ForesightCharGrowthDetailSkillCell.m_onLevelUp = HL.Field(HL.Function)

ForesightCharGrowthDetailSkillCell.ForesightCharGrowthDetailSkillCell = HL.Constructor(HL.Table)
    << function(self, ctx)
    self.m_onLevelUp = ctx.onLevelUp
end


ForesightCharGrowthDetailSkillCell._EnsureSkillSlotCaches = HL.StaticMethod(HL.Table).Return(HL.Boolean) << function(cell)
    if cell._skillSlotCachesReady then
        return true
    end
    local skillNodeRef = cell.charSkillNodeNew
    if not skillNodeRef or not skillNodeRef.skillCell then
        return false
    end
    local skillCellTemplate = skillNodeRef.skillCell
    local templateGo = skillCellTemplate.gameObject
    local parent = skillNodeRef.transform or templateGo.transform.parent
    local function wrapSkillCell(item)
        local skillCell = Utils.wrapLuaNode(item)
        skillCell.view = skillCell
        return skillCell
    end
    cell._skillCellTemplateGo = templateGo
    cell._skillCellTemplateWidget = wrapSkillCell(templateGo)
    cell._skillCellsExtraCache = UIUtils.genCellCache(skillCellTemplate, wrapSkillCell, parent)
    cell._skillSlotCachesReady = true
    return true
end

ForesightCharGrowthDetailSkillCell._GetSkillSlotCell = HL.StaticMethod(HL.Table, HL.Number).Return(HL.Opt(HL.Any))
    << function(cell, luaIndex)
    if luaIndex == 1 then
        return cell._skillCellTemplateWidget
    end
    if not cell._skillCellsExtraCache then
        return nil
    end
    return cell._skillCellsExtraCache:GetItem(luaIndex - 1)
end

ForesightCharGrowthDetailSkillCell._ApplySkillSlotLayout = HL.StaticMethod(HL.Table, HL.Number)
    << function(cell, skillCount)
    local templateGo = cell._skillCellTemplateGo
    local extraCache = cell._skillCellsExtraCache
    if not templateGo or not extraCache then
        return
    end
    local extraCount = math.max(0, skillCount - 1)
    if skillCount >= 1 then
        templateGo:SetActive(true)
        templateGo.transform:SetSiblingIndex(0)
        local siblingIndex = 1
        for index = 1, extraCount do
            local itemCell = extraCache:GetItem(index)
            if itemCell and itemCell.gameObject then
                itemCell.gameObject:SetActive(true)
                itemCell.transform:SetSiblingIndex(siblingIndex)
                siblingIndex = siblingIndex + 1
            end
        end
    else
        templateGo:SetActive(false)
        extraCache:Refresh(0)
    end
    local skillNodeRef = cell.charSkillNodeNew
    if skillNodeRef and skillNodeRef.rectTransform then
        CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(skillNodeRef.rectTransform)
    end
end

ForesightCharGrowthDetailSkillCell._SetSkillRankText = HL.StaticMethod(HL.Any, HL.Opt(HL.Number,HL.Number)) << function(skillCell, curLevel, targetLevel)
    if not skillCell or not skillCell.view or not skillCell.view.rankText then
        return
    end
    if skillCell.view.rank then
        skillCell.view.rank.gameObject:SetActive(true)
    end
    local text
    if curLevel and targetLevel then
        text = string.format("%d/%d", curLevel, targetLevel)
    elseif curLevel then
        text = string.format("%d/-", curLevel)
    elseif targetLevel then
        text = string.format("-/%d", targetLevel)
    else
        text = "-/-"
    end
    skillCell.view.rankText.text = text
    _ApplyPairProgressTextStyle(skillCell.view.rankText, curLevel, targetLevel)
end

ForesightCharGrowthDetailSkillCell._DisableSkillCellInteraction = HL.StaticMethod(HL.Any)
    << function(skillCell)
    if not skillCell or not skillCell.view then
        return
    end
    if skillCell.view.button then
        skillCell.view.button.interactable = false
        skillCell.view.button.onClick:RemoveAllListeners()
    end
end

ForesightCharGrowthDetailSkillCell._RefreshSkillCellAsHidden = HL.StaticMethod(HL.Any, HL.Opt(HL.Number)) << function(skillCell, targetLevel)
    if not skillCell or not skillCell.view then
        return
    end
    ForesightCharGrowthDetailSkillCell._DisableSkillCellInteraction(skillCell)
    skillCell.view.stateController:SetState("UnKnow")
    if skillCell.view.textSkill then
        skillCell.view.textSkill.text = ""
    end
    if skillCell.view.bgSkillColor2 then
        skillCell.view.bgSkillColor2.gameObject:SetActive(true)
    end
    if skillCell.view.bgSkillColor3 then
        skillCell.view.bgSkillColor3.gameObject:SetActive(false)
    end
    ForesightCharGrowthDetailSkillCell._SetSkillRankText(skillCell, nil, targetLevel)
end

ForesightCharGrowthDetailSkillCell._RefreshSkillCellIcon = HL.StaticMethod(HL.Any, HL.Any, HL.Opt(HL.Number)) << function(skillCell, skillGroupCfg, charInstId)
    if not skillCell or not skillCell.view or not skillGroupCfg then
        return
    end
    local isUltimateSkill = skillGroupCfg.skillGroupType == GEnums.SkillGroupType.UltimateSkill
    if skillCell.view.bgSkillColor2 then
        skillCell.view.bgSkillColor2.gameObject:SetActive(not isUltimateSkill)
    end
    if skillCell.view.bgSkillColor3 then
        skillCell.view.bgSkillColor3.gameObject:SetActive(isUltimateSkill)
    end
    local bgColor = CharInfoUtils.getCharInfoSkillGroupBgColor(skillGroupCfg)
    if skillCell.view.bgSkillColor2 then
        skillCell.view.bgSkillColor2.color = bgColor
    end
    if skillCell.view.bgSkillColor3 then
        skillCell.view.bgSkillColor3.color = bgColor
    end
    if skillCell.view.textSkill then
        skillCell.view.textSkill.text = skillGroupCfg.name
    end
    local icon
    if charInstId and CharInfoUtils.hasBothSkillGroupConditions(skillGroupCfg) then
        local activeIdx = CharInfoUtils.getActiveSkillGroupConditionIdx(charInstId, skillGroupCfg)
        icon = CharInfoUtils.generateSkillGroupConditionIcon(charInstId, skillGroupCfg, activeIdx)
    end
    if icon == nil or string.isEmpty(icon) then
        icon = skillGroupCfg.icon
    end
    if skillCell.view.skillIcon then
        local showIcon = not string.isEmpty(icon)
        skillCell.view.skillIcon.gameObject:SetActive(showIcon)
        if showIcon then skillCell.view.skillIcon:LoadSprite(UIConst.UI_SPRITE_SKILL_ICON, icon) end
    end
    if skillCell.view.rank then
        skillCell.view.rank.gameObject:SetActive(true)
    end
    skillCell.view.stateController:SetState("Normal")
    ForesightCharGrowthDetailSkillCell._DisableSkillCellInteraction(skillCell)
end

ForesightCharGrowthDetailSkillCell._RefreshOwnedSkillCell = HL.StaticMethod(HL.Any, HL.Any, HL.Any, HL.Number, HL.Table) << function(skillCell, charInst, skillGroupType, luaIndex, headerBundle)
    if not skillCell or not skillCell.view then
        return
    end
    local skillGroupCfg = CharInfoUtils.getCharSkillGroupCfgByType(charInst.templateId, skillGroupType)
    if not skillGroupCfg then
        ForesightCharGrowthDetailSkillCell._RefreshSkillCellAsHidden(skillCell, headerBundle.skillTargets and headerBundle.skillTargets[luaIndex])
        return
    end
    ForesightCharGrowthDetailSkillCell._RefreshSkillCellIcon(skillCell, skillGroupCfg, charInst.instId)
    local curLevel = headerBundle.curSkillLevels and headerBundle.curSkillLevels[luaIndex] or 1
    local skillTargets = headerBundle.skillTargets or {}
    ForesightCharGrowthDetailSkillCell._SetSkillRankText(skillCell, curLevel, skillTargets[luaIndex])
end

ForesightCharGrowthDetailSkillCell._RefreshFourSkillCells = HL.Method(HL.Table, HL.Table, HL.Table, HL.Boolean, HL.Boolean)
    << function(self, cell, info, headerBundle, isOwned, showSkillHidden)
    if not ForesightCharGrowthDetailSkillCell._EnsureSkillSlotCaches(cell) then
        return
    end
    if cell.charSkillNodeNew and cell.charSkillNodeNew.gameObject then
        cell.charSkillNodeNew.gameObject:SetActive(true)
    end
    local skillCount = #UIConst.CHAR_INFO_SKILL_SHOW_ORDER
    local templateId = info.templateId
    local skillTargets = headerBundle.skillTargets or {}
    local charInst
    if isOwned and not showSkillHidden and info.instId and info.instId > 0 then
        charInst = CharInfoUtils.getPlayerCharInfoByInstId(info.instId)
    end

    local function refreshSlot(luaIndex)
        local slotCell = ForesightCharGrowthDetailSkillCell._GetSkillSlotCell(cell, luaIndex)
        if not slotCell then
            return
        end
        if slotCell.view and slotCell.view.skillIcon then
            slotCell.view.skillIcon.gameObject:SetActive(false)
        end
        local skillGroupType = UIConst.CHAR_INFO_SKILL_SHOW_ORDER[luaIndex]
        if showSkillHidden then
            ForesightCharGrowthDetailSkillCell._RefreshSkillCellAsHidden(slotCell, skillTargets[luaIndex])
        elseif charInst then
            ForesightCharGrowthDetailSkillCell._RefreshOwnedSkillCell(
                slotCell, charInst, skillGroupType, luaIndex, headerBundle)
        else
            local skillGroupCfg = CharInfoUtils.getCharSkillGroupCfgByType(templateId, skillGroupType)
            if not skillGroupCfg then
                ForesightCharGrowthDetailSkillCell._RefreshSkillCellAsHidden(slotCell, skillTargets[luaIndex])
                return
            end
            ForesightCharGrowthDetailSkillCell._RefreshSkillCellIcon(slotCell, skillGroupCfg)
            ForesightCharGrowthDetailSkillCell._SetSkillRankText(slotCell, nil, skillTargets[luaIndex])
        end
    end

    local extraCount = math.max(0, skillCount - 1)
    if cell._skillCellsExtraCache then
        cell._skillCellsExtraCache:Refresh(extraCount, function(extraCell, extraIndex)
            refreshSlot(extraIndex + 1)
        end)
    end
    if skillCount >= 1 then
        refreshSlot(1)
    end
    ForesightCharGrowthDetailSkillCell._ApplySkillSlotLayout(cell, skillCount)
end

ForesightCharGrowthDetailSkillCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, info, bundle)
    if not cell or not info or not bundle then
        return
    end
    local headerBundle = bundle.headerBundle or {}
    local isForesight = info.isForesight == true
    local isOwned = info.isOwned == true and not isForesight
    local showSkillHidden = headerBundle.showSkillHidden == true
    local showGrowthEmpty = isOwned and bundle.showGrowthEmpty == true
    local talentUnlocked = headerBundle.talentUnlocked or 0
    local talentUnlockable = headerBundle.talentUnlockable or 0

    local stateName
    if showSkillHidden or not isOwned then
        stateName = "GotoDisable"
    elseif showGrowthEmpty and headerBundle.isCurStageMax == true then
        stateName = "Complete"
    else
        stateName = "GotoLvUp"
    end
    if cell.charSkillNode and cell.charSkillNode.SetState then
        cell.charSkillNode:SetState(stateName)
    end
    if cell.targetText then
        CellHelper.SetUiText(cell.targetText, Language.LUA_FORESIGHT_GROWTH_LABEL_CHAR_SKILL_TALENT_TEXT)
    end
    if cell.charSkillNodeStateController then
        cell.charSkillNodeStateController:SetState(headerBundle.containTalent and "ShowTalent" or "HideTalent")
    end
    if cell.lvNumTxt then
        local curLevel
        local targetLevel
        local text = "-/-"
        if not showSkillHidden then
            if isOwned then
                curLevel = talentUnlocked
                targetLevel = talentUnlockable
                text = string.format("%d/%d", curLevel, targetLevel)
            elseif talentUnlockable > 0 then
                targetLevel = talentUnlockable
                text = string.format("-/%d", targetLevel)
            end
        end
        cell.lvNumTxt.text = text
        _ApplyPairProgressTextStyle(cell.lvNumTxt, curLevel, targetLevel)
    end

    self:_RefreshFourSkillCells(cell, info, headerBundle, isOwned, showSkillHidden)

    local canLevelUp = isOwned and not showSkillHidden and self.m_onLevelUp ~= nil
    CellHelper.BindClick(cell.levelUpBtn, canLevelUp, function()
        self.m_onLevelUp(info)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_TALENT_SKILL)
    cell._skillCellCanLevelUp = canLevelUp
end



HL.Commit(ForesightCharGrowthDetailSkillCell)

return {
    ForesightCharGrowthDetailCharCell = ForesightCharGrowthDetailCharCell,
    ForesightCharGrowthDetailSkillCell = ForesightCharGrowthDetailSkillCell,
    ForesightCharGrowthDetailRewardsCell = ForesightCharGrowthDetailRewardsCell,
}
