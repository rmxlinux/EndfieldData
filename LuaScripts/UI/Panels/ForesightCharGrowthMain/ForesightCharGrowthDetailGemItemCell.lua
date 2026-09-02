






local UITextType = typeof(CS.Beyond.UI.UIText)

local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')
local GemCellModule = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailGemCell')
local ForesightCharGrowthDetailGemCell = GemCellModule.ForesightCharGrowthDetailGemCell

local STATIC_ABILITY_CELL_FIELDS = { "abilityCell1", "abilityCell2", "abilityCell3" }

ForesightCharGrowthDetailGemItemCell = HL.Class('ForesightCharGrowthDetailGemItemCell')

ForesightCharGrowthDetailGemItemCell.m_phase = HL.Field(HL.Forward('PhaseForesightCharGrowth'))
ForesightCharGrowthDetailGemItemCell.m_onGainGem = HL.Field(HL.Function)
ForesightCharGrowthDetailGemItemCell.m_onOpenDepot = HL.Field(HL.Function)
ForesightCharGrowthDetailGemItemCell.m_onGemEnhance = HL.Field(HL.Function)
ForesightCharGrowthDetailGemItemCell.m_onRefreshGemBubbleRow = HL.Field(HL.Function)
ForesightCharGrowthDetailGemItemCell.m_onSyncScrollListSelectedIndex = HL.Field(HL.Function)

ForesightCharGrowthDetailGemItemCell.ForesightCharGrowthDetailGemItemCell = HL.Constructor(HL.Table)
    << function(self, ctx)
    ctx = ctx or {}
    self.m_phase = ctx.phase
    self.m_onGainGem = ctx.onGainGem
    self.m_onOpenDepot = ctx.onOpenDepot
    self.m_onGemEnhance = ctx.onGemEnhance
    self.m_onRefreshGemBubbleRow = ctx.onRefreshGemBubbleRow
    self.m_onSyncScrollListSelectedIndex = ctx.onSyncScrollListSelectedIndex
end

ForesightCharGrowthDetailGemItemCell._ShowGemItemTips = HL.Method(HL.Table, HL.Table)
    << function(self, cell, header)
    if not cell or not header then
        return
    end
    local gemInstId = header.attachedGemInstId or 0
    if gemInstId <= 0 or not cell.item then
        return
    end
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst then
        return
    end
    Notify(MessageConst.SHOW_ITEM_TIPS, {
        itemId = gemInst.templateId,
        instId = gemInstId,
        posType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        transform = cell.item.transform,
        isSideTips = false,
    })
end

ForesightCharGrowthDetailGemItemCell._IsGainBtnActionable = HL.StaticMethod(HL.Table).Return(HL.Boolean) << function(cell)
    if not cell or not cell.gainBtn or not cell.gainBtn.gameObject then
        return false
    end
    if not cell.gainBtn.gameObject.activeInHierarchy then
        return false
    end
    if cell.gainBtnState and cell.gainBtnState.GetState then
        local stateName = cell.gainBtnState:GetState()
        if stateName == "GrayState" then
            return false
        end
    end
    return cell.gainBtn.interactable ~= false
end

ForesightCharGrowthDetailGemItemCell._IsGemEnhanceBtnActionable = HL.StaticMethod(HL.Table, HL.Table).Return(HL.Boolean) << function(cell, header)
    if not cell or not cell.gemBtn or not cell.gemBtn.gameObject then
        return false
    end
    if not cell.gemBtn.gameObject.activeInHierarchy then
        return false
    end
    local _, canClick = ForesightCharGrowthDetailGemItemCell._ResolveGemEnhanceBtnState(header or {})
    return canClick == true and cell.gemBtn.interactable ~= false
end

ForesightCharGrowthDetailGemItemCell._ResolveGainDepotFlags = HL.StaticMethod(HL.String, HL.Table).Return(HL.Boolean, HL.Boolean) << function(detailState, header)
    if detailState == "Unknown" then
        return false, false
    end
    local canGain = detailState == "NotEquipped" or detailState == "Perfect" or detailState == "UnPerfect"
    local canDepot = detailState == "Perfect" or detailState == "UnPerfect"
    return canGain, canDepot
end


ForesightCharGrowthDetailGemItemCell._IsEquippedGemEnhanceEnabled = HL.StaticMethod(HL.Table).Return(HL.Boolean) << function(header)
    local gemInstId = header.attachedGemInstId or 0
    if gemInstId <= 0 then
        return false
    end
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst then
        return false
    end
    local _, itemCfg = Tables.itemTable:TryGetValue(gemInst.templateId)
    if not itemCfg then
        return false
    end
    local minRarity = Tables.gemConst.enhanceCostGemRarity
    return itemCfg.rarity >= minRarity
end

ForesightCharGrowthDetailGemItemCell._ResolveGemEnhanceBtnState = HL.StaticMethod(HL.Table).Return(HL.String, HL.Boolean) << function(header)
    if ForesightCharGrowthDetailGemItemCell._IsEquippedGemEnhanceEnabled(header) ~= true then
        return "GrayState", false
    end
    if header.isGemEnhanceMax == true then
        return "DarkState", false
    end
    return "NormalState", true
end


ForesightCharGrowthDetailGemItemCell._RefreshGemAttriTermNodes = HL.StaticMethod(HL.Table, HL.Table) << function(cell, termEntries)
    local cfgOk,cfg
    if DeviceInfo.isMobile then
        cfgOk, cfg = Tables.foresightGrowthConfigTable:TryGetValue("GemLineTextMaxNum_M")
    else
        cfgOk, cfg = Tables.foresightGrowthConfigTable:TryGetValue("GemLineTextMaxNum_PC")
    end
    local maxGemTextNum = cfg and cfg.value or 70
    local ver = cell.gemVerLayout
    if not ver then return end
    local hors = { ver.gemHorLayout1, ver.gemHorLayout2, ver.gemHorLayout3 }
    local nodes = {
        ver.gemAttriNode1, ver.gemAttriNode2, ver.gemAttriNode3,
        ver.gemAttriNode4, ver.gemAttriNode5, ver.gemAttriNode6,
    }
    
    for i = 1, 6 do CellHelper.SetNodeActive(nodes[i], false) end
    
    for i = 1, 3 do CellHelper.SetNodeActive(hors[i], false) end
    termEntries = termEntries or {}
    local n = #termEntries
    if n <= 0 then return end
    local names, lens = {}, {}
    for i = 1, n do
        names[i] = ForesightCharGrowthDetailGemCell._ResolveTermTagName(termEntries[i])
        lens[i] = I18nUtils.GetTextRealLength(names[i])
    end
    local pattern
    if n == 1 then
        
        pattern = { 1 }
    elseif n == 2 then
        
        pattern = (lens[1] + lens[2] <= maxGemTextNum) and { 2 } or { 1, 1 }
    elseif lens[1] + lens[2] + lens[3] <= maxGemTextNum then
        
        pattern = { 3 }
    elseif lens[1] + lens[2] <= maxGemTextNum then
        
        pattern = { 2, 1 }
    elseif lens[2] + lens[3] <= maxGemTextNum then
        
        pattern = { 1, 2 }
    else
        
        pattern = { 1, 1, 1 }
    end
    local termIndex = 1
    for lineIdx, count in ipairs(pattern) do
        CellHelper.SetNodeActive(hors[lineIdx], true)
        local base = lineIdx == 1 and 1 or (lineIdx == 2 and 4 or 6)
        for j = 1, count do
            local node = nodes[base + j - 1]
            local entry = termEntries[termIndex]
            CellHelper.SetNodeActive(node, true)
            node:SetState(entry.isWeaponTagMatch == true and "Normal" or "Grey")
            local rootTr = node and (node.transform or (node.gameObject and node.gameObject.transform))
            local gemTxtTr = rootTr and rootTr:Find("GemTxt")
            CellHelper.SetUiText(gemTxtTr and gemTxtTr:GetComponent(UITextType), names[termIndex])
            local lineTr = rootTr and rootTr:Find("LineImage")
            if lineTr then
                lineTr.gameObject:SetActive(j < count)
            end
            termIndex = termIndex + 1
        end
    end
end

ForesightCharGrowthDetailGemItemCell._RefreshEquippedSubStates = HL.StaticMethod(HL.Table, HL.Table, HL.String).Return(HL.Boolean) << function(cell, header, detailState)
    local termEntries = detailState == "Equipped" and (header.attachedGemTermEntries or {}) or {}
    ForesightCharGrowthDetailGemItemCell._RefreshGemAttriTermNodes(cell, termEntries)
    if detailState ~= "Equipped" then
        return false
    end
    local t = "UnPerfect"
    if header.isWeaponGemMaxDisplay == true or header.isGemPerfectMatch == true then t = "Perfect" end
    cell.gemNode:SetState(t)
    local stateName, canEnhance = ForesightCharGrowthDetailGemItemCell._ResolveGemEnhanceBtnState(header)
    if cell.gemBtnState and cell.gemBtnState.SetState then
        cell.gemBtnState:SetState(stateName)
    else
        CellHelper.SetNodeActive(cell.gemBtn, canEnhance == true)
        CellHelper.SetNodeActive(cell.btnGemEnhance, canEnhance == true)
    end
    return canEnhance
end

ForesightCharGrowthDetailGemItemCell._SetStaticAbilityCellLevel = HL.StaticMethod(HL.Any, HL.Opt(HL.Number))
    << function(slotCell, level)
    local slotTr = slotCell and (slotCell.transform or slotCell)
    if not slotTr then
        return
    end
    local abilityNodeTr = slotTr:Find("AbilityNode")
    local numTxtTr = abilityNodeTr and abilityNodeTr:Find("NumTxt")
    local numTxt = numTxtTr and numTxtTr:GetComponent(UITextType)
    if numTxt then
        CellHelper.SetUiText(numTxt, string.format("%d", level or 0))
    end
end

ForesightCharGrowthDetailGemItemCell._RefreshSkillLevelAbilityCells = HL.StaticMethod(HL.Table, HL.Table, HL.String)
    << function(cell, header, detailState)
    local termEntries = detailState == "Equipped" and (header.attachedGemTermEntries or {}) or {}
    for index, fieldName in ipairs(STATIC_ABILITY_CELL_FIELDS) do
        local slotCell = cell[fieldName]
        local entry = termEntries[index - (#STATIC_ABILITY_CELL_FIELDS - #termEntries)]
        if entry then
            CellHelper.SetNodeActive(slotCell, true)
            ForesightCharGrowthDetailGemItemCell._SetStaticAbilityCellLevel(slotCell, entry.level)
        else
            CellHelper.SetNodeActive(slotCell, false)
        end
    end
end

ForesightCharGrowthDetailGemItemCell._RefreshGemIcon = HL.StaticMethod(HL.Table, HL.Table, HL.Forward('ForesightCharGrowthDetailGemItemCell')) << function(cell, header, helper)
    if not cell.item then
        return
    end
    local gemInstId = header.attachedGemInstId or 0
    if gemInstId > 0 then
        local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
        if gemInst then
            local onItemClick = DeviceInfo.usingController and true or function()
                if helper then
                    helper:_ShowGemItemTips(cell, header)
                end
            end
            cell.item:InitItem({ id = gemInst.templateId, instId = gemInstId }, onItemClick)
            if DeviceInfo.usingController then
                cell.item:SetEnableHoverTips(false)
                cell.item:SetExtraInfo({
                    tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                    tipsPosTransform = cell.item.transform,
                })
                cell.item.view.button.onIsNaviTargetChanged = function(isTarget)
                    if isTarget then
                        cell.item:ShowTips()
                    elseif cell.item.showingTips then
                        Notify(MessageConst.HIDE_ITEM_TIPS)
                    end
                end
            end
            CellHelper.SetNodeActive(cell.item, true)
            return
        end
    end
    CellHelper.SetNodeActive(cell.item, false)
end

ForesightCharGrowthDetailGemItemCell._RefreshGainArea = HL.Method(HL.Table, HL.Table, HL.String) << function(self, cell, header, detailState)
    CellHelper.BindClick(cell.gainBtn, false)
    CellHelper.BindClick(cell.depotBtn, false)
    if detailState == "Unknown" then
        return
    end
    CellHelper.BindClick(cell.gainBtn, self.m_onGainGem ~= nil, function()
        local row = cell._growthRowCell
        if row and row._growthScrollLuaIndex and row._growthScrollLuaIndex > 0 and self.m_onSyncScrollListSelectedIndex then
            self.m_onSyncScrollListSelectedIndex(row._growthScrollLuaIndex)
        end
        self.m_onGainGem(header.displayWeaponId, header.attachedGemInstId)
    end)
    local showDepot = detailState == "Perfect" or detailState == "UnPerfect"
    CellHelper.BindClick(cell.depotBtn, showDepot and self.m_onOpenDepot ~= nil, function()
        local row = cell._growthRowCell
        if row and row._growthScrollLuaIndex and row._growthScrollLuaIndex > 0 and self.m_onSyncScrollListSelectedIndex then
            self.m_onSyncScrollListSelectedIndex(row._growthScrollLuaIndex)
        end
        local counts = header.perfectMatchCounts or {}
        local withFilter = ((counts.gold or 0) + (counts.purple or 0)) > 0
        self.m_onOpenDepot(header.displayWeaponId, withFilter)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_VALUABLE_DEPOT)
end

ForesightCharGrowthDetailGemItemCell._RefreshGemEnhanceBtn = HL.Method(HL.Table, HL.Table, HL.String)
    << function(self, cell, header, detailState)
    CellHelper.BindClick(cell.gemBtn, false)
    if detailState ~= "Equipped" then
        return
    end
    CellHelper.BindClick(cell.gemBtn, self.m_onGemEnhance ~= nil, function()
        local _, canEnhance = ForesightCharGrowthDetailGemItemCell._ResolveGemEnhanceBtnState(header)
        if not canEnhance then
            return
        end
        local row = cell._growthRowCell
        if row and row._growthScrollLuaIndex and row._growthScrollLuaIndex > 0 and self.m_onSyncScrollListSelectedIndex then
            self.m_onSyncScrollListSelectedIndex(row._growthScrollLuaIndex)
        end
        self.m_onGemEnhance(header.attachedGemInstId)
    end)
end

ForesightCharGrowthDetailGemItemCell._RefreshItemBubbleToggle = HL.StaticMethod(HL.Table, HL.Boolean, HL.Boolean)
    << function(cell, showToggle, expanded)
    CellHelper.SetNodeActive(cell.growthGemBubbleBtn, showToggle == true)
    if showToggle and cell.growthGemBubbleBtnStateController then
        cell.growthGemBubbleBtnStateController:SetState(expanded == true and "Expand" or "Close")
    end
    CellHelper.SetNodeActive(cell.detailGetGemNode, true)
end

ForesightCharGrowthDetailGemItemCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, info, bundle)
    if not cell or not info or not bundle then return end
    local header = bundle.headerBundle or {}
    local weaponId = header.displayWeaponId or ""
    local detailState = "Equipped"
    if header.hasUnknownTerms then detailState = "Unknown" end
    local isCharOwned = info.isOwned == true and not (info.isForesight == true)
    if header.isDisplayWeaponOwned ~= true or not isCharOwned then
        detailState =  "UnPerfect"
        local counts = header.perfectMatchCounts or {}
        if (counts.gold or 0) > 0 or (counts.purple or 0) > 0 then detailState = "Perfect" end
    else
        if not header.isGemEquipped then detailState = "NotEquipped" end
    end
    local showItemToggle = not isCharOwned and (header.hasPerfectMatchInDepot == true)
    local rowCell = cell._growthRowCell
    local itemExpanded = rowCell and (rowCell._gemBubbleExpanded == true)
    if cell.detailGetGemNode and cell.detailGetGemNode.SetState then
        cell.detailGetGemNode:SetState(detailState)
    end

    local canEnhance = ForesightCharGrowthDetailGemItemCell._RefreshEquippedSubStates(cell, header, detailState)
    ForesightCharGrowthDetailGemItemCell._RefreshSkillLevelAbilityCells(cell, header, detailState)
    if detailState == "Equipped" then 
        ForesightCharGrowthDetailGemItemCell._RefreshGemIcon(cell, header, self)
    else 
        CellHelper.SetNodeActive(cell.item, false) 
    end
    CellHelper.SetUiText(cell.highGemNumTxt, tostring(header.perfectMatchCounts.gold or 0))
    CellHelper.SetUiText(cell.lowGemNumTxt, tostring(header.perfectMatchCounts.purple or 0))
    CellHelper.SetUiText(cell.gemLevelText, header.isGemSkillLevelOverWeaponCap and Language.LUA_FORESIGHT_GROWTH_GEMITEM_LEVELTEXT_OVERFULL or Language.LUA_FORESIGHT_GROWTH_GEMITEM_LEVELTEXT)
    ForesightCharGrowthDetailGemItemCell._RefreshItemBubbleToggle(cell, showItemToggle, itemExpanded)

    self:_RefreshGainArea(cell, header, detailState)
    self:_RefreshGemEnhanceBtn(cell, header, detailState)
    CellHelper.BindClick(cell.growthGemBubbleBtn, showItemToggle and self.m_onRefreshGemBubbleRow ~= nil, function()
        local rc = cell._growthRowCell
        if rc then
            rc._gemBubbleExpanded = not (rc._gemBubbleExpanded == true)
            AudioAdapter.PostEvent(rc._gemBubbleExpanded and "Au_UI_Toast_Tips_Open" or "Au_UI_Toast_Tips_Close")
        end
        self.m_onRefreshGemBubbleRow(cell._growthSectionIndex or 1, "item")
    end)

    local canGain, canDepot = ForesightCharGrowthDetailGemItemCell._ResolveGainDepotFlags(detailState, header)
    cell._gemItemDetailState = detailState
    cell._gemItemShowToggle = showItemToggle
    cell._gemItemCanGain = canGain and (self.m_onGainGem ~= nil)
    cell._gemItemEq1CanGain = detailState == "Equipped" and (self.m_onGainGem ~= nil) and ForesightCharGrowthDetailGemItemCell._IsGainBtnActionable(cell)
    cell._gemItemCanDepot = canDepot and self.m_onOpenDepot ~= nil
    cell._gemItemCanEnhance = detailState == "Equipped" and canEnhance and (self.m_onGemEnhance ~= nil)
    cell._gemItemCanItemTips = detailState == "Equipped" and ((header.attachedGemInstId or 0) > 0) and (cell.item ~= nil)
    cell._gemItemHeader = header

    if DeviceInfo.usingController then
        ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(cell, false)
    end
end

ForesightCharGrowthDetailGemItemCell._SetSubButtonWrapNaviEnabled = HL.StaticMethod(HL.Table, HL.Boolean) << function(cell, enabled)
    if not cell then
        return
    end
    local function apply(btn)
        if not btn then
            return
        end
        if enabled == true then
            btn.enableControllerNavi = true
            btn.interactable = true
        else
            btn.enableControllerNavi = false
        end
    end
    apply(cell.gainBtn)
    apply(cell.gemBtn)
    apply(cell.depotBtn)
    apply(cell.growthGemBubbleBtn)
    apply(cell.item.view.button)
end


ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable = HL.StaticMethod(HL.Table, HL.Boolean) << function(cell, enabled)
    if not cell then
        return
    end
    local isEnabled = enabled == true
    if cell.eq1 then
        cell.eq1.enableControllerNavi = isEnabled
        cell.eq1.interactable = isEnabled
        cell.eq1.hideNaviHint = false
    end
    if cell.eq2 then
        cell.eq2.enableControllerNavi = isEnabled
        cell.eq2.interactable = isEnabled
        cell.eq2.hideNaviHint = false
    end
end


ForesightCharGrowthDetailGemItemCell.ApplyControllerFocus = HL.Method(HL.Table, HL.Boolean, HL.Opt(HL.String))
    << function(self, cell, isTarget, focusZone)
    if not cell then
        return
    end
    focusZone = focusZone or "row"
    if not isTarget then
        CellHelper.ToggleBtnBinding(cell.gainBtn, false)
        CellHelper.ToggleBtnBinding(cell.gemBtn, false)
        CellHelper.ToggleBtnBinding(cell.depotBtn, false)
        CellHelper.ToggleItemBtnBinding(cell.item, false)
        ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(cell, false)
        if cell._gemItemShowToggle == true then
            ForesightCharGrowthDetailGemItemCell._RefreshItemBubbleToggle(cell, true, false)
        end
        return
    end
    if cell._gemItemShowToggle == true and focusZone == "row" then
        ForesightCharGrowthDetailGemItemCell._RefreshItemBubbleToggle(cell, true, true)
    end

    local detailState = cell._gemItemDetailState or ""
    if detailState == "Equipped" and (focusZone == "eq1" or focusZone == "eq2") then
        local onEq1 = focusZone == "eq1"
        local onEq2 = focusZone == "eq2"

        local showItemTips = onEq1 and cell._gemItemCanItemTips == true
        if not showItemTips then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
        CellHelper.ToggleItemBtnBinding(cell.item, showItemTips)

        local showGain = onEq1 and (cell._gemItemCanGain == true or cell._gemItemEq1CanGain == true)
        CellHelper.ToggleBtnBinding(cell.gainBtn, showGain, Language.LUA_GEM_TAG_OBTAIN_TITLE)

        local header = cell._gemItemHeader
        local showEnhance = onEq2 and cell._gemItemCanEnhance == true
            and ForesightCharGrowthDetailGemItemCell._IsGemEnhanceBtnActionable(cell, header)
        CellHelper.ToggleBtnBinding(cell.gemBtn, showEnhance, Language.LUA_FORESIGHT_GROWTH_CTRL_GEM_ENHANCE)

        CellHelper.ToggleBtnBinding(cell.depotBtn, false)
        return
    end

    if detailState ~= "Equipped" then
        CellHelper.ToggleBtnBinding(
            cell.gainBtn, cell._gemItemCanGain == true, Language.LUA_GEM_TAG_OBTAIN_TITLE)
        CellHelper.ToggleBtnBinding(
            cell.depotBtn,
            cell._gemItemCanDepot == true,
            Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_VALUABLE_DEPOT)
    end
end


ForesightCharGrowthDetailGemItemCell.WireEquippedEqNaviOnce = HL.StaticMethod(HL.Table, HL.Forward('ForesightCharGrowthDetailRewardsCell')) << function(cell, rewardsCell)
    if not DeviceInfo.usingController or not cell or cell._gemEqNavWired or not rewardsCell then
        return
    end
    local eq1 = cell.eq1
    local eq2 = cell.eq2
    if not eq1 or not eq2 then
        return
    end
    
    if eq1.transform and not eq1.overrideNaviHintRectTransform then
        eq1.overrideNaviHintRectTransform = eq1.transform
    end
    if eq2.transform and not eq2.overrideNaviHintRectTransform then
        eq2.overrideNaviHintRectTransform = eq2.transform
    end
    ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable(cell, false)
    local NaviDirection = CS.UnityEngine.UI.NaviDirection
    local function wireEqNavi(eq)
        eq.banExplicitOnRight = true
        eq.banExplicitOnLeft = true
    end
    wireEqNavi(eq1)
    wireEqNavi(eq2)
    local function resolveNaviLeftTarget()
        if not rewardsCell.m_getNaviLeftTarget then
            return nil
        end
        return rewardsCell.m_getNaviLeftTarget()
    end
    eq1.customNaviTargetInDirFunc = function(dir)
        if dir == NaviDirection.Left then
            return resolveNaviLeftTarget()
        end
        if dir == NaviDirection.Right then
            return nil
        end
        if dir == NaviDirection.Down then
            return eq2
        end
        if dir == NaviDirection.Up then
            local rowCell = cell._growthRowCell
            local scrollLuaIndex = rowCell and rowCell._growthScrollLuaIndex
            if (not scrollLuaIndex or scrollLuaIndex < 2) and cell._growthSectionIndex then
                scrollLuaIndex = cell._growthSectionIndex * 2
            end
            if scrollLuaIndex and scrollLuaIndex > 1 and rewardsCell.m_getScrollRowNaviTargetAt then
                return rewardsCell.m_getScrollRowNaviTargetAt(scrollLuaIndex - 1)
            end
            return nil
        end
        return nil
    end
    eq2.customNaviTargetInDirFunc = function(dir)
        if dir == NaviDirection.Left then
            return resolveNaviLeftTarget()
        end
        if dir == NaviDirection.Right then
            return nil
        end
        if dir == NaviDirection.Up then
            return eq1
        end
        return nil
    end
    local function deferRefreshControllerHints()
        if not rewardsCell.m_onRefreshControllerHints then
            return
        end
        local refresh = rewardsCell.m_onRefreshControllerHints
        CoroutineManager:StartCoroutine(function()
            coroutine.step()
            refresh()
        end)
    end
    local function onEqFocusGained(focusZone, _eq)
        local curRowCell = cell._growthRowCell
        if curRowCell then
            rewardsCell:_ToggleRowBindingGroup(curRowCell, true)
            if curRowCell._growthScrollLuaIndex and rewardsCell.m_onSyncScrollListSelectedIndex then
                rewardsCell.m_onSyncScrollListSelectedIndex(curRowCell._growthScrollLuaIndex)
            end
        end
        local helper = rewardsCell.m_gemItemCellHelper
        if helper then
            helper:ApplyControllerFocus(cell, true, focusZone)
        end
        local naviMgr = InputManagerInst and InputManagerInst.controllerNaviManager
        if naviMgr and naviMgr.UpdateNaviInputBindingState then
            naviMgr:UpdateNaviInputBindingState()
        end
        deferRefreshControllerHints()
    end
    local function onEqFocusLost(peerEq, _eq)
        local curTarget = InputManagerInst and InputManagerInst.controllerNaviManager
            and InputManagerInst.controllerNaviManager.curTarget
        if curTarget == peerEq then
            return
        end
        local curRowCell = cell._growthRowCell
        if curRowCell then
            rewardsCell:_ToggleRowBindingGroup(curRowCell, false)
        end
        local helper = rewardsCell.m_gemItemCellHelper
        if helper then
            helper:ApplyControllerFocus(cell, false)
        end
        deferRefreshControllerHints()
    end
    eq1.onGroupSetAsNaviTarget:RemoveAllListeners()
    eq1.onGroupSetAsNaviTarget:AddListener(function(isTarget)
        if not DeviceInfo.usingController then
            return
        end
        if isTarget then
            onEqFocusGained("eq1", eq1)
            return
        end
        onEqFocusLost(eq2, eq1)
    end)
    eq2.onGroupSetAsNaviTarget:RemoveAllListeners()
    eq2.onGroupSetAsNaviTarget:AddListener(function(isTarget)
        if not DeviceInfo.usingController then
            return
        end
        if isTarget then
            onEqFocusGained("eq2", eq2)
            return
        end
        onEqFocusLost(eq1, eq2)
    end)
    cell._gemEqNavWired = true
end

HL.Commit(ForesightCharGrowthDetailGemItemCell)

return {
    ForesightCharGrowthDetailGemItemCell = ForesightCharGrowthDetailGemItemCell,
    SetEquippedEqNaviEnabled = ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable,
    SetEquippedEqInteractable = ForesightCharGrowthDetailGemItemCell._SetEquippedEqInteractable,
}
