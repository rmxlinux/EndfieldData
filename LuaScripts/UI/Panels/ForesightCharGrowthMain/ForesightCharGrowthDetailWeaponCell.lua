








local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')

ForesightCharGrowthDetailWeaponCell = HL.Class('ForesightCharGrowthDetailWeaponCell')

ForesightCharGrowthDetailWeaponCell.m_getShowRecommend = HL.Field(HL.Function)
ForesightCharGrowthDetailWeaponCell.m_setShowRecommend = HL.Field(HL.Function)
ForesightCharGrowthDetailWeaponCell.m_onLevelUp = HL.Field(HL.Function)
ForesightCharGrowthDetailWeaponCell.m_onGoWeaponPool = HL.Field(HL.Function)
ForesightCharGrowthDetailWeaponCell.m_onToggleRecommendView = HL.Field(HL.Function)

ForesightCharGrowthDetailWeaponCell.ForesightCharGrowthDetailWeaponCell = HL.Constructor(HL.Table) << function(self, ctx)
    self.m_getShowRecommend = ctx.getShowRecommend
    self.m_setShowRecommend = ctx.setShowRecommend
    self.m_onLevelUp = ctx.onLevelUp
    self.m_onGoWeaponPool = ctx.onGoWeaponPool
    self.m_onToggleRecommendView = ctx.onToggleRecommendView
end

ForesightCharGrowthDetailWeaponCell._IsWeaponToggleBtnActive = HL.StaticMethod(HL.Table).Return(HL.Boolean) << function(cell)
    if not cell or not cell.weaponBtn or not cell.weaponBtn.gameObject then
        return false
    end
    return cell.weaponBtn.gameObject.activeInHierarchy
end

ForesightCharGrowthDetailWeaponCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, info, bundle)
    if not cell or not info or not bundle then
        return
    end
    local header = bundle.headerBundle or {}
    local isForesight = info.isForesight == true
    local isCharOwned = info.isOwned == true and not isForesight
    local showRecommend = false
    if isCharOwned and self.m_getShowRecommend then
        showRecommend = self.m_getShowRecommend(info.templateId) == true
    end

    local isGoalReached = isCharOwned and bundle.isGoalReached == true
    local isMaxStage = isCharOwned and bundle.isCurStageMax == true
    local displayWeaponId = header.displayWeaponId or ""
    local isWeaponLvMax = false
    if header.isDisplayWeaponOwned == true and not string.isEmpty(displayWeaponId) then
        local okWeapon, weaponCfg = Tables.weaponBasicTable:TryGetValue(displayWeaponId)
        if okWeapon and weaponCfg then
            isWeaponLvMax = (header.displayWeaponLevel or 0) >= (weaponCfg.maxLv or 0)
        end
    end

    cell.stateController:SetState((cell._growthRowCell and cell._growthRowCell._growthHeaderSectionIndex or 1) <= 1 and "First" or "NoFirst")

    local levelNodeState = "GotoLvUp"
    if not isCharOwned then
        cell.titleNode:SetState("WeaponFit")
        if header.isDisplayWeaponOwned then levelNodeState = "GotoLvUp"
        elseif header.isDisplayWeaponObtainable then levelNodeState = "GotoWeaponPool"
        else levelNodeState = "GotoDisable" end
    else
        cell.titleNode:SetState(showRecommend and "WeaponRecommend" or "WeaponLvUp")
        if showRecommend then
            levelNodeState = (not string.isEmpty(header.equippedWeaponId) and not header.isEquippedLowQuality) and "ShowRecommend" or "ShowRecommendLow"
        elseif isWeaponLvMax then
            levelNodeState = "Complete"
        end
    end
    if cell.weaponLevelNode and cell.weaponLevelNode.SetState then
        cell.weaponLevelNode:SetState(levelNodeState)
    end

    local isDisplayWeaponOwned = header.isDisplayWeaponOwned == true
    CellHelper.SetWeaponIconAndName(cell, displayWeaponId, header.isForesightWeapon == true, header.displayWeaponRefineLv or 0, isDisplayWeaponOwned)
    CellHelper.SetWeaponLineImgRarity(cell, displayWeaponId, header.isForesightWeapon == true)
    CellHelper.ApplyGrowthLabelState(cell, nil, isDisplayWeaponOwned, header.displayWeaponLevel)
    CellHelper.SetUiText(cell.tarLvNumTxt, string.format("%d", header.targetLevel or 0))
    local verState = "Target"
    if isCharOwned and showRecommend and header.isEquippedLowQuality and not header.isEquippedRecommended then
        verState = "WeaponLow"
    elseif isCharOwned and isGoalReached and not isMaxStage then
        verState = "TargetComplete"
    end
    cell.verLayout:SetState(verState)

    local canToggleTitle = self.m_onToggleRecommendView ~= nil
    CellHelper.BindClick(cell.weaponBtn, canToggleTitle, function()
        self.m_onToggleRecommendView(info.templateId)
    end, showRecommend and Language.LUA_FORESIGHT_GROWTH_CTRL_TOGGLE_WEAPON_VIEW
        or Language.LUA_FORESIGHT_GROWTH_CTRL_TOGGLE_WEAPON_VIEW_2)

    local canLevelUp = self.m_onLevelUp ~= nil and (levelNodeState == "GotoLvUp"
        or levelNodeState == "ShowRecommend" or levelNodeState == "ShowRecommendLow")
    CellHelper.BindClick(cell.levelUpBtn, canLevelUp, function()
        self.m_onLevelUp(info, displayWeaponId, header.displayWeaponInstId or 0)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_CHAR_WEAPON)

    local canGoPool = not isCharOwned and levelNodeState == "GotoWeaponPool" and self.m_onGoWeaponPool ~= nil
    CellHelper.BindClick(cell.goCharBtn, canGoPool, function()
        self.m_onGoWeaponPool(displayWeaponId)
    end, Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_WEAPON_SHOP)

    cell._weaponCellCanLevelUp = canLevelUp
    cell._weaponCellCanGoPool = canGoPool
end

HL.Commit(ForesightCharGrowthDetailWeaponCell)

return {
    ForesightCharGrowthDetailWeaponCell = ForesightCharGrowthDetailWeaponCell,
}
