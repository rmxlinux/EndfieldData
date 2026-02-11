



















local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget

















ItemObtainWays = HL.Class('ItemObtainWays', UIWidgetBase)


ItemObtainWays.hasObtainWay = HL.Field(HL.Boolean) << false


ItemObtainWays.m_obtainCells = HL.Field(HL.Forward('UIListCache'))


ItemObtainWays.m_exitNaviBindingId = HL.Field(HL.Number) << -1


ItemObtainWays.m_itemTipsPosInfo = HL.Field(HL.Table)


ItemObtainWays.m_itemId = HL.Field(HL.String) << ''


ItemObtainWays.m_onClickItem = HL.Field(HL.Function)


ItemObtainWays.m_onBeforeJump = HL.Field(HL.Function)




ItemObtainWays._OnFirstTimeInit = HL.Override() << function(self)
    self.m_obtainCells = UIUtils.genCellCache(self.view.obtainCell)
    self.m_exitNaviBindingId = InputManagerInst:CreateBindingByActionId("item_tips_exit_obtain_ways", function()
        self:_ToggleNavi(false)
    end, self.view.inputBindingGroupMonoTarget.groupId)
    InputManagerInst:ToggleBinding(self.m_exitNaviBindingId, false)
end




ItemObtainWays._ToggleNavi = HL.Method(HL.Boolean) << function(self, active)
    if active then
        if self.hasObtainWay then
            local cell = self.m_obtainCells:Get(1)
            InputManagerInst.controllerNaviManager:SetTarget(cell.selectedTarget)
        else
            InputManagerInst.controllerNaviManager:SetTarget(self.view.emptyNode.button)
        end
    else
        InputManagerInst.controllerNaviManager:TryRemoveLayer(self.view.selectableNaviGroup)
    end
    InputManagerInst:ToggleBinding(self.m_exitNaviBindingId, active)
end








ItemObtainWays.InitItemObtainWays = HL.Method(HL.String, HL.Opt(HL.Number, HL.Table, HL.Function, HL.Function)) << function(
    self, itemId, instId, itemTipsPosInfo, onClickItem, onBeforeJump)
    self:_FirstTimeInit()

    self.m_itemTipsPosInfo = itemTipsPosInfo
    self.m_itemId = itemId
    self.m_onClickItem = onClickItem
    self.m_onBeforeJump = onBeforeJump

    local itemCfg = Tables.itemTable:GetValue(itemId)

    local obtainInfoList = self:_GenerateObtainInfoList(itemId)
    self.hasObtainWay = next(obtainInfoList) ~= nil
    if self.hasObtainWay then
        self.view.gameObject:SetActive(true)
        self.view.emptyNode.gameObject:SetActive(false)
        self.m_obtainCells:Refresh(#obtainInfoList, function(cell, index)
            local obtainInfo = obtainInfoList[index]
            self:_RefreshObtainCell(cell, obtainInfo, index)
        end)
    else
        if itemCfg.noObtainWayId == nil or itemCfg.noObtainWayId.Count == 0 then
            
            self.view.gameObject:SetActive(false)
        else
            local find, showNoObtainWayId = self:_FindShowNoObtainWayId(itemCfg)
            if find then
                self.view.gameObject:SetActive(true)
                self.m_obtainCells:Refresh(0)
                self.view.emptyNode.gameObject:SetActive(false)
                local _, obtainWayCfg = Tables.systemJumpTable:TryGetValue(showNoObtainWayId)
                if obtainWayCfg then
                    self.view.emptyNode.gameObject:SetActive(true)
                    self.view.emptyNode.nameTxt:SetAndResolveTextStyle(obtainWayCfg.desc)
                    self.view.emptyNode.jumpNodeDeco.gameObject:SetActive(false)
                    self.view.emptyNode.button.onClick:RemoveAllListeners()
                    local isUnlock = Utils.isSystemUnlocked(obtainWayCfg.bindSystem) and not Utils.isInBlackbox()
                    if isUnlock then
                        local phaseId = PhaseId[obtainWayCfg.phaseId]
                        local phaseArgs
                        if not string.isEmpty(obtainWayCfg.phaseArgs) then
                            phaseArgs = Json.decode(obtainWayCfg.phaseArgs)
                        end
                        if phaseId ~= nil and PhaseManager:CheckCanOpenPhase(phaseId, phaseArgs) then
                            self.view.emptyNode.jumpNodeDeco.gameObject:SetActive(true)
                            self.view.emptyNode.button.onClick:AddListener(function()
                                if self.m_onBeforeJump then
                                    self.m_onBeforeJump()
                                end
                                PhaseManager:GoToPhase(phaseId, phaseArgs)
                                Notify(MessageConst.HIDE_ITEM_TIPS)
                            end)
                        end
                    end
                end
            else
                self.view.gameObject:SetActive(false)
            end
        end
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(self.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.emptyNode.nameTxt.transform)
end




ItemObtainWays._FindShowNoObtainWayId = HL.Method(HL.Any).Return(HL.Boolean, HL.String) << function(self, itemCfg)
    if itemCfg == nil or itemCfg.noObtainWayId == nil or itemCfg.noObtainWayId.Count == 0 then
        return false, ""
    end

    for csIndex = 0, itemCfg.noObtainWayId.Count - 1 do
        if csIndex >= itemCfg.noObtainWayConditionId.Count then
            return true, itemCfg.noObtainWayId[csIndex]
        end
        local conditionId = itemCfg.noObtainWayConditionId[csIndex]
        local succ, conditionCfg = Tables.noObtainWayCondTable:TryGetValue(conditionId)
        if not succ then
            return true, itemCfg.noObtainWayId[csIndex]
        end
        local unlockTag = false
        if conditionCfg.conditionType == GEnums.ConditionType.CheckWikiUnlocked then
            unlockTag = WikiUtils.isWikiEntryUnlock(conditionCfg.checkId)
        elseif conditionCfg.conditionType == GEnums.ConditionType.CheckFacTechTreeUnlocked then
            unlockTag = not GameInstance.player.facTechTreeSystem:NodeIsLocked(conditionCfg.checkId)
        end
        if not unlockTag then
            return true, itemCfg.noObtainWayId[csIndex]
        end
    end

    return false, ""
end






ItemObtainWays._GenerateObtainInfoList = HL.Method(HL.String).Return(HL.Table) << function(self, itemId)
    
    local obtainInfoList = {}

    
    local itemCfg = Tables.itemTable:GetValue(itemId)
    if itemCfg.obtainWayIds then
        for k, obtainWayId in pairs(itemCfg.obtainWayIds) do
            local _, obtainWayCfg = Tables.systemJumpTable:TryGetValue(obtainWayId)
            if obtainWayCfg then
                local isUnlock = Utils.isSystemUnlocked(obtainWayCfg.bindSystem)
                if isUnlock then
                    local phaseId = PhaseId[obtainWayCfg.phaseId]
                    local phaseArgs
                    if not string.isEmpty(obtainWayCfg.phaseArgs) then
                        phaseArgs = Json.decode(obtainWayCfg.phaseArgs)
                    end
                    local blockJumpToast = ""
                    if phaseId ~= nil and not PhaseManager:CheckCanOpenPhase(phaseId, phaseArgs) then
                        if obtainWayCfg.bindSystem == GEnums.UnlockSystemType.Map then
                            blockJumpToast = Language.LUA_OBTAIN_WAYS_MAP_JUMP_BLOCKED
                        else
                            blockJumpToast = Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED
                        end
                    end
                    table.insert(obtainInfoList, {
                        name = obtainWayCfg.desc,
                        iconFolder = UIConst.UI_SPRITE_ITEM_TIPS,
                        iconId = obtainWayCfg.iconId,
                        phaseId = phaseId,
                        phaseArgs = phaseArgs,
                        blockJumpToast = blockJumpToast,
                        sortId = -k / 1000,
                    })
                end
            end
        end
    end

    
    local craftInfoList, canCraft = FactoryUtils.getItemCrafts(itemId)
    local hasFormula = next(craftInfoList) ~= nil
    if canCraft and hasFormula then
        self:_InsertCrafts(obtainInfoList, craftInfoList)
    end

    














    if self.view.config.ENABLE_DYNAMIC_SORT then
        table.sort(obtainInfoList, Utils.genSortFunction({"sortId"}))
    end

    return obtainInfoList
end





ItemObtainWays._InsertCrafts = HL.Method(HL.Table, HL.Table) << function(self, obtainInfoList, craftInfoList)
    local manuSortId, sortId, curOpenedBuildingId
    local topPhaseId = PhaseManager:GetTopPhaseId()
    if self.view.config.ENABLE_DYNAMIC_SORT then
        if topPhaseId == PhaseId.FacMachine then
            curOpenedBuildingId = FactoryUtils.getCurOpenedBuildingId()
            sortId = 1
        else
            local inFac = Utils.isInFacMainRegion()
            manuSortId = inFac and 1 or -1
            sortId = inFac and 100 or -100
        end
    end

    local craftsByBuilding = {}
    local manualCrafts = {}
    for _, info in pairs(craftInfoList) do
        local buildingId = info.buildingId
        if not buildingId then
            table.insert(manualCrafts, info)
        else
            if not craftsByBuilding[buildingId] then
                craftsByBuilding[buildingId] = {}
            end
            table.insert(craftsByBuilding[buildingId], info)
        end
    end

    if next(manualCrafts) then
        for _, data in pairs(manualCrafts) do
            local info = {
                name = Language.LUA_OBTAIN_WAYS_MANUAL_CRAFT_NAME,
                crafts = manualCrafts,
                iconFolder = UIConst.UI_SPRITE_ITEM_TIPS,
                iconId = UIConst.UI_MANUALCRAFT_ICON_ID,
                phaseId = PhaseId.ManualCraft,
                phaseArgs = {jumpId = data.craftId},
                sortId = manuSortId,
            }
            table.insert(obtainInfoList, info)
        end
    end

    for buildingId, crafts in pairs(craftsByBuilding) do
        local buildingData = Tables.factoryBuildingTable:GetValue(buildingId)
        local groupInfo = {
            buildingId = buildingId,
            name = buildingData.name,
            iconFolder = UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON,
            iconId = buildingData.iconOnPanel,
        }
        local hubBan = false
        if sortId then
            if curOpenedBuildingId == buildingId then
                groupInfo.sortId = 1000
            else
                groupInfo.sortId = sortId
            end
        end
        if buildingData.type == GEnums.FacBuildingType.Hub or buildingData.type == GEnums.FacBuildingType.SubHub then
            if Utils.isSystemUnlocked(GEnums.UnlockSystemType.FacHub) then
                groupInfo.name = Language.ITEM_OBTAIN_WAY_HUB_CRAFT
                groupInfo.phaseId = PhaseId.FacBuildListSelect
                local itemId = FactoryUtils.getBuildingItemId(crafts[1].craftId)
                groupInfo.phaseArgs = { selectedId = itemId }
                if topPhaseId ~= PhaseId.FacMachine and topPhaseId ~= PhaseId.Inventory then
                    groupInfo.phaseArgs.onlyCraftNode = true
                end
            else
                hubBan = true
            end
        end
        for _, info in pairs(crafts) do
            if buildingData.type ~= GEnums.FacBuildingType.Miner then
                if not groupInfo.crafts then
                    groupInfo.crafts = {}
                end
                table.insert(groupInfo.crafts, info)
            end
        end
        if not hubBan then
            table.insert(obtainInfoList, groupInfo)
        end
    end
end



local jumpBlockWhiteMap = {
    [PhaseId.CommonMoneyExchange] = true,
}







ItemObtainWays._RefreshObtainCell = HL.Method(HL.Any, HL.Table, HL.Number) << function(self, cell, info, index)
    cell.selectedTarget = cell.normalNode.button

    cell.normalNode.nameTxt.text = info.name
    local iconId = info.iconId
    local iconFolder = info.iconFolder
    cell.normalNode.icon.gameObject:SetActive(iconId ~= nil and iconFolder ~= nil)
    if iconId ~= nil and iconFolder ~= nil then
        cell.normalNode.icon:LoadSprite(info.iconFolder, info.iconId)
    end

    self:_UpdateCraftCell(cell, info)

    cell.normalNode.button.onClick:RemoveAllListeners()
    if info.phaseId or not string.isEmpty(info.buildingId) then
        cell.normalNode.animationNode:PlayInAnimation()
        cell.normalNode.button.onClick:AddListener(function()
            
            local isBlocked
            if jumpBlockWhiteMap[info.phaseId] then
                isBlocked = UIManager:ShouldBlockAllObtainWaysJump()
            else
                isBlocked = UIManager:ShouldBlockObtainWaysJump()
            end
            if isBlocked then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED)
                return
            end
            if info.blockJumpToast ~= nil and not string.isEmpty(info.blockJumpToast) then
                Notify(MessageConst.SHOW_TOAST, info.blockJumpToast)
                return
            end
            Notify(MessageConst.HIDE_ITEM_TIPS)
            if self.m_onBeforeJump then
                self.m_onBeforeJump()
            end
            if info.phaseId then
                
                PhaseManager:GoToPhase(info.phaseId, info.phaseArgs)
            else
                local firstCraft = info.crafts and info.crafts[1] or nil
                if firstCraft then
                    PhaseManager:GoToPhase(PhaseId.Wiki, {
                        isItemCraft = true,
                        itemId = self.m_itemId,
                        craftId = firstCraft.craftId })
                else
                    Notify(MessageConst.SHOW_WIKI_ENTRY, { buildingId = info.buildingId })

                end
            end
        end)
        cell.normalNode.button:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.PressConfirmTriggerOnClick)
        cell.normalNode.button.interactable = true
    else
        cell.normalNode.button:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
        cell.normalNode.animationNode:PlayOutAnimation()
        
        if not DeviceInfo.usingController then
            cell.normalNode.button.interactable = false
        end
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(cell.transform)
    cell.gameObject.name = "ObtainWay-" .. index
end





ItemObtainWays._UpdateCraftCell = HL.Method(HL.Table, HL.Table) << function(self, cell, info)
    if not cell.craftCells then
        cell.craftCells = UIUtils.genCellCache(cell.craftCell)
    end

    if not info.crafts then
        cell.craftCells:Refresh(0)
        return
    end

    local craftCount = #info.crafts
    cell.craftCells:Refresh(craftCount, function(craftCell, craftIndex)
        local craftInfo = info.crafts[craftIndex]
        if not craftCell.itemCells then
            craftCell.itemCells = UIUtils.genCellCache(craftCell.itemCell)
        end
        local incomeCount = craftInfo.incomes and #craftInfo.incomes or 0
        local outcomeCount = craftInfo.outcomes and #craftInfo.outcomes or 0
        craftCell.itemCells:Refresh(incomeCount + outcomeCount, function(itemCell, itemIndex)
            local bundle
            if itemIndex <= incomeCount then
                bundle = craftInfo.incomes[itemIndex]
            else
                bundle = craftInfo.outcomes[itemIndex - incomeCount]
            end
            if self.view.config.IS_SIMPLE_ITEM then
                itemCell:InitItemSimple(bundle.id, bundle.count)
            else
                if self.m_onClickItem then
                    itemCell:InitItem(bundle, function()
                        self.m_onClickItem(itemCell, craftCell)
                    end)
                else
                    itemCell:InitItem(bundle, self.view.config.IS_ITEM_SHOW_TIPS)
                end
                if self.m_itemTipsPosInfo then
                    itemCell:SetExtraInfo(self.m_itemTipsPosInfo)
                end
            end
            itemCell.transform:SetSiblingIndex(itemIndex)
            itemCell.gameObject.name = "Item-" .. bundle.id
        end)
        craftCell.arrow.transform:SetSiblingIndex(incomeCount + 1)
        craftCell.line.gameObject:SetActive(craftIndex ~= craftCount)
        craftCell.mask.gameObject:SetActive(craftIndex == 1)
        if craftCell.modeLabel ~= nil then
            local showMode = craftInfo.formulaMode ~= nil and craftInfo.formulaMode ~= FacConst.FAC_FORMULA_MODE_MAP.NORMAL
            craftCell.modeLabel.gameObject:SetActive(showMode)
            if showMode then
                local _, modeData = Tables.factoryMachineCraftModeTable:TryGetValue(craftInfo.formulaMode)
                if modeData then
                    craftCell.modeLabel:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON, modeData.iconId)
                end
            end
        end

        craftCell.gameObject.name = "Craft-" .. craftInfo.craftId

        if craftCell.pinBtn then
            local showPin = not string.isEmpty(craftInfo.craftId) and
                Tables.factoryMachineCraftTable:ContainsKey(craftInfo.craftId)
            craftCell.pinBtn.gameObject:SetActive(showPin)
            if showPin then
                craftCell.pinBtn:InitPinBtn(craftInfo.craftId, GEnums.FCPinPosition.Formula:GetHashCode())
                craftCell.pinBtn.view.pinToggle.onHoverChange:RemoveAllListeners()
                craftCell.pinBtn.view.pinToggle.onHoverChange:AddListener(function(isHover)
                    if craftCell.stateController == nil then
                        return
                    end
                    if isHover then
                        craftCell.stateController:SetState("Highlighted")
                    else
                        craftCell.stateController:SetState("Other")
                    end
                end)
            end
        end

        if craftCell.add then
            if not craftCell.addCells then
                craftCell.addCells = UIUtils.genCellCache(craftCell.add)
            end
            craftCell.addCells:Refresh(incomeCount + outcomeCount - 2, function(addCell, addCellIndex)
                local siblingIndex = 0
                if addCellIndex <= incomeCount - 1 then
                    siblingIndex = addCellIndex * 2
                else
                    siblingIndex = (addCellIndex + 1) * 2
                end
                addCell.transform:SetSiblingIndex(siblingIndex)
            end)
        end

        if self.view.config.IS_SHOW_CRAFT_TIME then
            if craftInfo.time then
                craftCell.time.text = string.format(Language["LUA_CRAFT_CELL_STANDARD_TIME"], FactoryUtils.getCraftTimeStr(craftInfo.time))
                craftCell.time.gameObject:SetActive(true)
            else
                craftCell.time.gameObject:SetActive(false)
            end
        else
            craftCell.time.gameObject:SetActive(false)
        end
    end)
end




HL.Commit(ItemObtainWays)
return ItemObtainWays
