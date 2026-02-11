local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')










ItemAsInput = HL.Class('ItemAsInput', UIWidgetBase)


ItemAsInput.m_obtainCells = HL.Field(HL.Forward('UIListCache'))


ItemAsInput.m_itemTipsPosInfo = HL.Field(HL.Table)


ItemAsInput.m_onClickItem = HL.Field(HL.Function)




ItemAsInput._OnFirstTimeInit = HL.Override() << function(self)
    self.m_obtainCells = UIUtils.genCellCache(self.view.obtainCell)
end









ItemAsInput.InitItemAsInput = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.m_itemTipsPosInfo = args.itemTipsPosInfo
    self.m_onClickItem = args.onClickItem

    local showCrafts, craftInfos, canCraft
    craftInfos, canCraft = FactoryUtils.getItemAsInputRecipeIds(args.itemId)
    showCrafts = next(craftInfos) ~= nil

    local obtainInfos = {}
    if canCraft then
        if showCrafts then
            self:_InsertCrafts(obtainInfos, craftInfos)
        end
    end

    
    self.m_obtainCells:Refresh(#obtainInfos, function(cell, index)
        self:_RefreshObtainCell(obtainInfos, cell, index)
    end)

    self.view.emptyNode.gameObject:SetActive(#obtainInfos == 0)

    LayoutRebuilder.ForceRebuildLayoutImmediate(self.transform)
end






ItemAsInput._RefreshObtainCell = HL.Method(HL.Any, HL.Table, HL.Number) << function(self, obtainInfos, cell, index)
    local info = obtainInfos[index]
    cell.nameTxt.text = info.name
    local iconFolder = info.iconFolder or UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON
    cell.icon:LoadSprite(iconFolder, info.icon)



    local canJump = info.crafts ~= nil and info.noJump ~= true
    if canJump then
        cell.animWrapper:PlayInAnimation()
    else
        cell.animWrapper:PlayOutAnimation()
    end
    cell.content.clickHintTextId = canJump and "virtual_mouse_hint_view" or ""

    cell.content.enabled = canJump
    cell.expand = info.crafts ~= nil
    self:_UpdateCraftCellExpand(cell, info)
    local isBuildingIdValid = not string.isEmpty(info.buildingId)
    cell.content.onClick:RemoveAllListeners()
    if canJump then
        cell.content.onClick:AddListener(function()
            if isBuildingIdValid then
                Notify(MessageConst.SHOW_WIKI_ENTRY, { buildingId = info.buildingId })
            else
                PhaseManager:GoToPhase(PhaseId.ManualCraft)
            end
        end)
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(cell.transform)

    cell.gameObject.name = "ObtainWay-" .. index
end





ItemAsInput._InsertCrafts = HL.Method(HL.Table, HL.Table) << function(self, obtainInfos, craftInfos)
    local craftsByBuilding = {}
    local manualCrafts = {}
    local manualCraftIsUnlock = false
    
    local wikiSystem = GameInstance.player.wikiSystem
    for _, info in pairs(craftInfos) do
        if info.isUnlock then
            local buildingId = info.buildingId
            if buildingId then
                local buildingItemId = FactoryUtils.getBuildingItemId(buildingId)
                local buildingLocked = false
                if buildingItemId then
                    local entryId = WikiUtils.getWikiEntryIdFromItemId(buildingItemId)
                    if entryId then
                        buildingLocked = wikiSystem:GetWikiEntryState(entryId) == CS.Beyond.Gameplay.WikiSystem.EWikiEntryState.Locked
                    end
                end
                if not buildingLocked then
                    if not craftsByBuilding[buildingId] then
                        craftsByBuilding[buildingId] = {}
                    end
                    table.insert(craftsByBuilding[buildingId], info)
                end
            else

                table.insert(manualCrafts, info)
                manualCraftIsUnlock = true

            end
        end
    end

    if next(manualCrafts) then
        table.insert(obtainInfos, {
            name = Language.LUA_OBTAIN_WAYS_MANUAL_CRAFT_NAME,
            crafts = manualCrafts,
            iconFolder = UIConst.UI_SPRITE_ITEM_TIPS,
            icon = UIConst.UI_MANUALCRAFT_ICON_ID,
            isUnlock = manualCraftIsUnlock,
        })
    end

    for buildingId, crafts in pairs(craftsByBuilding) do
        local buildingData = Tables.factoryBuildingTable:GetValue(buildingId)
        if buildingData.type == GEnums.FacBuildingType.Miner then
            table.insert(obtainInfos, {
                buildingId = buildingId,
                name = buildingData.name,
                icon = buildingData.iconOnPanel
            })
        elseif buildingData.type == GEnums.FacBuildingType.Hub then
            table.insert(obtainInfos, {
                buildingId = buildingId,
                name = Language.ui_fac_sp_hub_building_manufacture_title,
                icon = buildingData.iconOnPanel,
                crafts = crafts,
                noJump = true,
            })
        else
            table.insert(obtainInfos, {
                buildingId = buildingId,
                name = buildingData.name,
                crafts = crafts,
                icon = buildingData.iconOnPanel
            })
        end
    end
end





ItemAsInput._UpdateCraftCellExpand = HL.Method(HL.Table, HL.Table) << function(self, cell, info)
    if not cell.craftCells then
        cell.craftCells = UIUtils.genCellCache(cell.craftCell)
    end

    local expand = cell.expand
    
    
    if not expand then
        cell.craftCells:Refresh(0)
        return
    end

    local craftCount = #info.crafts
    cell.craftCells:Refresh(craftCount, function(craftCell, craftIndex)
        
        local craftInfo = info.crafts[craftIndex]
        if not craftCell.itemCells then
            craftCell.itemCells = UIUtils.genCellCache(craftCell.itemCell)
        end
        local incomeCount = #craftInfo.incomes
        local outcomeCount = craftInfo.outcomes and #craftInfo.outcomes or 0
        craftCell.itemCells:Refresh(incomeCount + outcomeCount, function(itemCell, itemIndex)
            local bundle
            if itemIndex <= incomeCount then
                bundle = craftInfo.incomes[itemIndex]
            else
                bundle = craftInfo.outcomes[itemIndex - incomeCount]
            end
            if self.m_onClickItem then
                itemCell:InitItem(bundle, function()
                    self.m_onClickItem(itemCell, craftCell)
                end)
            else
                itemCell:InitItem(bundle, true)
            end
            itemCell.canUse = false
            itemCell.transform:SetSiblingIndex(itemIndex)
            itemCell.gameObject.name = "Item-" .. bundle.id
            if self.m_itemTipsPosInfo then
                itemCell:SetExtraInfo(self.m_itemTipsPosInfo)
            end
        end)
        craftCell.arrow.transform:SetSiblingIndex(incomeCount + 1)

        if craftInfo.outcomeText then
            craftCell.outcomePower.gameObject:SetActiveIfNecessary(true)
            craftCell.powerText.text = craftInfo.outcomeText
        else
            craftCell.outcomePower.gameObject:SetActiveIfNecessary(false)
        end

        craftCell.line.gameObject:SetActive(craftIndex ~= craftCount)
        if craftCell.pinBtn then
            local showPin = not string.isEmpty(craftInfo.craftId) and
                Tables.factoryMachineCraftTable:ContainsKey(craftInfo.craftId)
            craftCell.pinBtn.gameObject:SetActive(showPin)
            if showPin then
                craftCell.pinBtn:InitPinBtn(craftInfo.craftId, GEnums.FCPinPosition.Formula:GetHashCode())
            end
        end
        if craftCell.add then
            if not craftCell.addCells then
                craftCell.addCells = UIUtils.genCellCache(craftCell.add)
            end
            local addCount = incomeCount + outcomeCount - 2
            if outcomeCount == 0 then
                addCount = incomeCount - 1
            end
            craftCell.addCells:Refresh(addCount, function(addCell, addCellIndex)
                local siblingIndex = 0
                if addCellIndex <= incomeCount - 1 then
                    siblingIndex = addCellIndex * 2
                else
                    siblingIndex = (addCellIndex + 1) * 2
                end
                addCell.transform:SetSiblingIndex(siblingIndex)
            end)
        end
        if craftCell.timeTxt then
            if craftInfo.time and craftInfo.time > 0 then
                craftCell.timeTxt.text = string.format(Language["LUA_CRAFT_CELL_STANDARD_TIME"], FactoryUtils.getCraftTimeStr(craftInfo.time))
                craftCell.timeTxt.gameObject:SetActive(true)
            else
                craftCell.timeTxt.gameObject:SetActive(false)
            end
        end

        craftCell.gameObject.name = "Craft-" .. craftInfo.craftId
    end)
end

HL.Commit(ItemAsInput)
return ItemAsInput
