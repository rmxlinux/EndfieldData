




local CellHelper = require_ex('UI/Panels/ForesightCharGrowthMain/ForesightCharGrowthDetailCellHelper')

ForesightCharGrowthDetailWeaponItemCell = HL.Class('ForesightCharGrowthDetailWeaponItemCell')

ForesightCharGrowthDetailWeaponItemCell.m_phase = HL.Field(HL.Forward('PhaseForesightCharGrowth'))
ForesightCharGrowthDetailWeaponItemCell.m_onGoViewWeapon = HL.Field(HL.Function)
ForesightCharGrowthDetailWeaponItemCell.m_onGoObtainWeapon = HL.Field(HL.Function)

ForesightCharGrowthDetailWeaponItemCell.ForesightCharGrowthDetailWeaponItemCell = HL.Constructor(HL.Table)
    << function(self, ctx)
    self.m_phase = ctx.phase
    self.m_onGoViewWeapon = ctx.onGoViewWeapon
    self.m_onGoObtainWeapon = ctx.onGoObtainWeapon
end

ForesightCharGrowthDetailWeaponItemCell._ApplyLimitOverlay = HL.StaticMethod(HL.Table, HL.Boolean) << function(cell, showActivityLimit)
    CellHelper.SetNodeActive(cell.limitActivityNode, showActivityLimit)
    CellHelper.SetNodeActive(cell.limitCharNode, false)
    CellHelper.SetNodeActive(cell.btnView, not showActivityLimit)
end

ForesightCharGrowthDetailWeaponItemCell.Refresh = HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, entry, ctx)
    if not cell or not entry or not ctx then
        return
    end
    local weaponId = entry.weaponId or ""
    local groupIndex = entry.groupIndex or 1
    local curWeaponInfo = ctx.curWeaponInfo or {}
    local phase = self.m_phase
    CellHelper.SetNodeActive(cell.recommendNode, groupIndex == 1)
    CellHelper.SetNodeActive(cell.propertyNode, groupIndex == 2)

    local _, itemCfg = Tables.itemTable:TryGetValue(weaponId)
    if cell.descTxt then
        CellHelper.SetUiText(cell.descTxt, itemCfg and itemCfg.name or "")
    end

    local isEquip = curWeaponInfo.weaponTemplateId == weaponId
    local ownedWeaponInstId = 0
    if isEquip then
        ownedWeaponInstId = curWeaponInfo.weaponInstId or 0
    elseif phase then
        local _, foundOwned, _, bestInstId = phase:GetBestOwnedWeaponInstInfo(weaponId)
        if foundOwned and bestInstId and bestInstId > 0 then
            ownedWeaponInstId = bestInstId
        end
    end
    local isInBag = not isEquip and ownedWeaponInstId > 0

    if cell.item and cell.item.InitItem then
        
        cell.item:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
            tipsPosTransform = cell.item.transform,
        })
        cell.item:InitItem({ id = weaponId, forceHidePotentialStar = true }, true)
        if DeviceInfo.usingController then
            cell.item:SetEnableHoverTips(false)
            cell.item.view.button.onIsNaviTargetChanged = function(isTarget)
                if isTarget then
                    cell.item:ShowTips()
                elseif cell.item.showingTips then
                    Notify(MessageConst.HIDE_ITEM_TIPS)
                end
            end
        end
    end

    local isInShop = CashShopUtils.TryGetWeaponByWeaponId(weaponId)
    local isInGachaPool = not string.isEmpty(phase:FindWeaponGachaPoolId(weaponId))
    local canObtain = isInGachaPool or isInShop

    local growthState = "NotOwn"
    local btnStateName = "DarkState"
    local showActivityLimit = false
    local canFunction = false
    local functionHandler
    local btnLabel = (isEquip or isInBag)
        and Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_VIEW
        or Language.LUA_FORESIGHT_GROWTH_CTRL_GOTO_GET

    if isEquip then
        growthState = "Equipped"
        btnStateName = "NormalState"
        canFunction = self.m_onGoViewWeapon ~= nil
        functionHandler = function()
            self.m_onGoViewWeapon(ctx.info, weaponId, ownedWeaponInstId)
        end
    elseif isInBag then
        growthState = "Owned"
        btnStateName = "NormalState"
        canFunction = self.m_onGoViewWeapon ~= nil
        functionHandler = function()
            self.m_onGoViewWeapon(ctx.info, weaponId, ownedWeaponInstId)
        end
    elseif canObtain then
        growthState = "NotOwn"
        btnStateName = "NormalState"
        canFunction = self.m_onGoObtainWeapon ~= nil
        functionHandler = function()
            self.m_onGoObtainWeapon(weaponId)
        end
    else
        growthState = "NotOwn"
        btnStateName = "DarkState"
        showActivityLimit = true
    end

    if cell.growthLabelNode and cell.growthLabelNode.SetState then
        cell.growthLabelNode:SetState(growthState)
    end
    if cell.btnState and cell.btnState.SetState then
        cell.btnState:SetState(btnStateName)
    end
    ForesightCharGrowthDetailWeaponItemCell._ApplyLimitOverlay(cell, showActivityLimit)

    if showActivityLimit then
        CellHelper.BindClick(cell.functionBtn, false)
    else
        CellHelper.SetUiText(cell.functionTxt, btnLabel)
        local onClick = functionHandler
        if onClick and ctx.onSyncScrollListSelectedIndex then
            onClick = function()
                local row = cell._growthRowCell
                if row and row._growthScrollLuaIndex and row._growthScrollLuaIndex > 0 then
                    ctx.onSyncScrollListSelectedIndex(row._growthScrollLuaIndex)
                end
                functionHandler()
            end
        end
        CellHelper.BindClick(cell.functionBtn, canFunction, onClick, btnLabel)
    end

    cell._weaponItemCanFunction = canFunction
    cell._weaponItemCanGoView = canFunction and (isEquip or isInBag)
    cell._weaponItemCanGoObtain = canFunction and canObtain and not isEquip and not isInBag
end

HL.Commit(ForesightCharGrowthDetailWeaponItemCell)

return {
    ForesightCharGrowthDetailWeaponItemCell = ForesightCharGrowthDetailWeaponItemCell,
}
