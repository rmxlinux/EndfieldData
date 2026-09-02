





local UITextType = typeof(CS.Beyond.UI.UIText)
local UIImageType = typeof(CS.UnityEngine.UI.Image)
local LayoutRebuilder = CS.UnityEngine.UI.LayoutRebuilder
local GOLD_ICON_COLOR = CS.UnityEngine.Color(1, 0.94509804, 0, 1)
local WHITE_ICON_COLOR = CS.UnityEngine.Color(1, 1, 1, 1)

local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')

ForesightCharGrowthDetailGemCell = HL.Class('ForesightCharGrowthDetailGemCell')

ForesightCharGrowthDetailGemCell.m_phase = HL.Field(HL.Forward('PhaseForesightCharGrowth'))
ForesightCharGrowthDetailGemCell.m_onLevelUp = HL.Field(HL.Function)
ForesightCharGrowthDetailGemCell.m_onToggleWish = HL.Field(HL.Function)
ForesightCharGrowthDetailGemCell.m_onRefreshGemBubbleRow = HL.Field(HL.Function)

ForesightCharGrowthDetailGemCell.ForesightCharGrowthDetailGemCell = HL.Constructor(HL.Table)
    << function(self, ctx)
    ctx = ctx or {}
    self.m_phase = ctx.phase
    self.m_onLevelUp = ctx.onLevelUp
    self.m_onToggleWish = ctx.onToggleWish
    self.m_onRefreshGemBubbleRow = ctx.onRefreshGemBubbleRow
end

ForesightCharGrowthDetailGemCell._ResolveTermTagName = HL.StaticMethod(HL.Table).Return(HL.String) << function(entry)
    if not entry then
        return ""
    end
    if not string.isEmpty(entry.tagName) then
        return entry.tagName
    end
    if entry.gemTermId then
        local _, termCfg = Tables.gemTable:TryGetValue(entry.gemTermId)
        if termCfg then
            return termCfg.tagName or ""
        end
    end
    return ""
end

ForesightCharGrowthDetailGemCell._EnsureHorLayoutCaches = HL.StaticMethod(HL.Table) << function(cell)
    if cell._abilityCellCache or not cell.horLayout or not cell.abilityCell or not cell.unknownNode then
        return
    end
    local horLayoutParent = cell.horLayout.transform or cell.horLayout
    cell._abilityCellCache = UIUtils.genCellCache(cell.abilityCell, function(item)
        return Utils.wrapLuaNode(item)
    end, horLayoutParent)
    cell._unknownNodeCache = UIUtils.genCellCache(cell.unknownNode, function(item)
        return Utils.wrapLuaNode(item)
    end, horLayoutParent)
end

ForesightCharGrowthDetailGemCell._ApplyAbilityCellEntry = HL.StaticMethod(HL.Table, HL.Table, HL.Boolean, HL.Boolean) << function(slotCell, entry, showLine, showLevel)
    if not slotCell or not slotCell.transform then
        return
    end
    if slotCell.gameObject then
        slotCell.gameObject:SetActive(true)
    end
    local tagName = ForesightCharGrowthDetailGemCell._ResolveTermTagName(entry)
    local abilityTxtTr = slotCell.transform:Find("AbilityTxt")
    local abilityTxt = abilityTxtTr and abilityTxtTr:GetComponent(UITextType)
    local hasGemBonus = entry.hasGemBonus == true
    local skillNameFormat = hasGemBonus
        and Language.LUA_GEM_CARD_SKILL_ACTIVE or Language.LUA_GEM_CARD_SKILL_INACTIVE
    if abilityTxt and abilityTxt.SetAndResolveTextStyle then
        abilityTxt:SetAndResolveTextStyle(string.format(skillNameFormat, tagName))
    else
        CellHelper.SetUiText(abilityTxt, tagName)
    end
    local abilityNodeTr = slotCell.transform:Find("AbilityNode")
    if abilityNodeTr then
        abilityNodeTr.gameObject:SetActive(showLevel == true)
    end
    if showLevel then
        local numTxtTr = abilityNodeTr and abilityNodeTr:Find("NumTxt")
        local numTxt = numTxtTr and numTxtTr:GetComponent(UITextType)
        if numTxt then
            CellHelper.SetUiText(numTxt, string.format("%d", entry.level or 0))
        end
        local iconImgTr = abilityNodeTr and abilityNodeTr:Find("IconImg")
        local iconImg = iconImgTr and iconImgTr:GetComponent(UIImageType)
        if iconImg then
            iconImg.color = hasGemBonus and GOLD_ICON_COLOR or WHITE_ICON_COLOR
        end
    end
    local lineTr = slotCell.transform:Find("Line")
    if lineTr then
        lineTr.gameObject:SetActive(showLine == true)
    end
end

ForesightCharGrowthDetailGemCell._RefreshHorLayoutTerms = HL.StaticMethod(HL.Table, HL.Table, HL.Boolean) << function(cell, termEntries, showLevel)
    termEntries = termEntries or {}
    CellHelper.SetNodeActive(cell.horLayout, #termEntries > 0)
    CellHelper.SetNodeActive(cell.abilityCell, false)
    CellHelper.SetNodeActive(cell.unknownNode, false)
    if #termEntries <= 0 then
        return
    end
    ForesightCharGrowthDetailGemCell._EnsureHorLayoutCaches(cell)
    local abilityCache = cell._abilityCellCache
    local unknownCache = cell._unknownNodeCache
    if not abilityCache or not unknownCache then
        return
    end
    local abilityEntries = {}
    local unknownCount = 0
    for slotIndex, entry in ipairs(termEntries) do
        if entry.isUnknown then
            unknownCount = unknownCount + 1
        else
            table.insert(abilityEntries, {
                entry = entry,
                showLine = slotIndex < #termEntries,
            })
        end
    end
    abilityCache:Refresh(#abilityEntries, function(slotCell, luaIndex)
        local info = abilityEntries[luaIndex]
        if info then
            ForesightCharGrowthDetailGemCell._ApplyAbilityCellEntry(slotCell, info.entry, info.showLine, showLevel)
        end
    end)
    unknownCache:Refresh(unknownCount, function(slotCell)
        if slotCell.gameObject then
            slotCell.gameObject:SetActive(true)
        end
    end)
    local abilityIndex = 0
    local unknownIndex = 0
    for slotIndex, entry in ipairs(termEntries) do
        local slotCell
        if entry.isUnknown then
            unknownIndex = unknownIndex + 1
            slotCell = unknownCache:GetItem(unknownIndex)
        else
            abilityIndex = abilityIndex + 1
            slotCell = abilityCache:GetItem(abilityIndex)
        end
        if slotCell and slotCell.transform then
            slotCell.transform:SetSiblingIndex(slotIndex - 1)
        end
    end
    local horLayoutRect = cell.horLayout and (cell.horLayout.rectTransform or cell.horLayout.transform)
    if horLayoutRect then
        LayoutRebuilder.ForceRebuildLayoutImmediate(horLayoutRect)
    end
end

ForesightCharGrowthDetailGemCell._RefreshWishToggle = HL.StaticMethod(HL.Table, HL.Boolean, HL.Opt(HL.Boolean))
    << function(cell, showWishlist, isInWishList)
    CellHelper.SetNodeActive(cell.addWishBtn, showWishlist == true)
    if not showWishlist then
        CellHelper.SetNodeActive(cell.dotmark, false)
        if cell.circleTog then
            cell.circleTog.interactable = false
        end
        return
    end
    CellHelper.SetNodeActive(cell.dotmark, isInWishList == true)
    if not cell.circleTog then
        return
    end
    if cell.circleTog.SetIsOnWithoutNotify then
        cell.circleTog:SetIsOnWithoutNotify(isInWishList == true)
    elseif cell.circleTog.isOn ~= nil then
        cell.circleTog.isOn = isInWishList == true
    end
    cell.circleTog.interactable = true
end

ForesightCharGrowthDetailGemCell._ShouldShowGemWishlist = HL.Method(HL.Table).Return(HL.Boolean) << function(self, header)
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.WeaponWishList) then
        return false
    end
    if header.isDisplayWeaponOwned ~= true then
        return true
    end
    local weaponId = header.displayWeaponId or ""
    if string.isEmpty(weaponId) then
        return true
    end
    local ok, itemCfg = Tables.itemTable:TryGetValue(weaponId)
    if ok and itemCfg.rarity and itemCfg.rarity <= 3 then
        return false
    end
    return true
end

ForesightCharGrowthDetailGemCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, info, bundle)
    if not cell or not info or not bundle then
        return
    end
    local header = bundle.headerBundle or {}
    local weaponId = header.displayWeaponId or ""
    local hasUnknown = header.hasUnknownTerms == true

    local isDisplayWeaponOwned = header.isDisplayWeaponOwned == true
    local isCharOwned = info.isOwned == true and not (info.isForesight == true)
    CellHelper.SetUiText(cell.gemText, isCharOwned and Language.LUA_FORESIGHT_GROWTH_GEM_TEXT_INJECT or Language.LUA_FORESIGHT_GROWTH_GEM_TEXT_ADAPT)
    CellHelper.SetWeaponIconAndName(
        cell, weaponId, header.isForesightWeapon == true, header.displayWeaponRefineLv or 0, isDisplayWeaponOwned)
    CellHelper.SetWeaponLineImgRarity(cell, weaponId, header.isForesightWeapon == true)
    CellHelper.ApplyGrowthLabelState(cell, nil, isDisplayWeaponOwned, header.displayWeaponLevel)
    if cell.lvNumTxt and cell.lvNumTxt.transform and cell.lvNumTxt.transform.parent then
        CellHelper.SetNodeActive(cell.lvNumTxt.transform.parent, isDisplayWeaponOwned)
    end

    local stateName = "GotoDisable"
    if isDisplayWeaponOwned and not hasUnknown then
        stateName = "GotoLvUp"
    end
    cell.stateController:SetState(stateName)
    cell.stateController:SetState((cell._growthRowCell and cell._growthRowCell._growthHeaderSectionIndex or 1) <= 1 and "First" or "NoFirst")
    CellHelper.SetNodeActive(cell.disableNode, stateName == "GotoDisable")

    ForesightCharGrowthDetailGemCell._RefreshHorLayoutTerms(cell, header.gemTermEntries, isDisplayWeaponOwned)

    local showBubble = header.showGrowthBubble == true
    local rowCell = cell._growthRowCell
    local bubbleExpanded = rowCell and rowCell._gemBubbleExpanded == true
    CellHelper.SetNodeActive(cell.growthGemBubbleBtn, showBubble)
    if showBubble and cell.growthGemBubbleBtnStateController then
        cell.growthGemBubbleBtnStateController:SetState(bubbleExpanded and "Expand" or "Close")
    end

    local showGemWishlist = self:_ShouldShowGemWishlist(header)
    local isInWishList = GameInstance.player.inventory.weaponGemWishList:Contains(weaponId)
    ForesightCharGrowthDetailGemCell._RefreshWishToggle(cell, showGemWishlist, isInWishList)

    local canLevelUp = stateName == "GotoLvUp" and self.m_onLevelUp ~= nil
    CellHelper.BindClick(cell.levelUpBtn, canLevelUp, function()
        self.m_onLevelUp(info, header, showBubble)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_VIEW)
    local wishHint = Language.LUA_FORESIGHT_GROWTH_CTRL_GEM_WISHLIST_TOGGLE
    if isInWishList then
        wishHint = Language.LUA_FORESIGHT_GROWTH_CTRL_GEM_WISHLIST_TOGGLE_CANCEL
    end
    CellHelper.BindClick(cell.addWishBtn, showGemWishlist and self.m_onToggleWish ~= nil, function()
        self.m_onToggleWish(info, header)
    end, wishHint)
    if cell.circleTog and cell.circleTog.onValueChanged then
        cell.circleTog.onValueChanged:RemoveAllListeners()
        if showGemWishlist and self.m_onToggleWish then
            cell.circleTog.onValueChanged:AddListener(function()
                local inWish = GameInstance.player.inventory.weaponGemWishList:Contains(weaponId)
                if cell.circleTog.SetIsOnWithoutNotify then
                    cell.circleTog:SetIsOnWithoutNotify(inWish)
                end
                self.m_onToggleWish(info, header)
            end)
        end
    end
    CellHelper.BindClick(cell.growthGemBubbleBtn, showBubble and self.m_onRefreshGemBubbleRow ~= nil, function()
        local rc = cell._growthRowCell
        if rc then
            rc._gemBubbleExpanded = not (rc._gemBubbleExpanded == true)
            AudioAdapter.PostEvent(rc._gemBubbleExpanded and "Au_UI_Toast_Tips_Open" or "Au_UI_Toast_Tips_Close")
        end
        self.m_onRefreshGemBubbleRow(rc and rc._growthHeaderSectionIndex or 1, "header")
    end)

    cell._gemCellCanLevelUp = canLevelUp
    cell._gemCellShowWishlist = showGemWishlist
    cell._gemCellShowBubble = showBubble
end

HL.Commit(ForesightCharGrowthDetailGemCell)

return {
    ForesightCharGrowthDetailGemCell = ForesightCharGrowthDetailGemCell,
}
