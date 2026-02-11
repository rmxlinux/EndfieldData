local EquipTechUtils = {}




function EquipTechUtils.hasEquipSuit(equipTemplateId)
    local hasValue, equipTemplate = Tables.equipTable:TryGetValue(equipTemplateId)
    if not hasValue then
        return false
    end
    local suitId = equipTemplate.suitID
    local hasSuit, _ = Tables.equipSuitTable:TryGetValue(suitId)
    return hasSuit
end




function EquipTechUtils.canEquipEnhance(templateId)
    local _, itemData = Tables.itemTable:TryGetValue(templateId)
    if itemData and itemData.rarity == Tables.equipConst.enhanceEquipRarity then
        return true
    end
    return false
end




function EquipTechUtils.getEquipEnhanceItemList(partType)
    
    local itemList = {}
    
    local equipDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Equip]:GetOrFallback(Utils.getCurrentScope())
    if equipDepot then
        for _, itemBundle in cs_pairs(equipDepot.instItems) do
            local equipInst = itemBundle.instData
            local templateId = equipInst.templateId

            local _, equipData = Tables.equipTable:TryGetValue(templateId)

            if equipData and (not partType or equipData.partType == partType) and EquipTechUtils.canEquipEnhance(templateId) then
                table.insert(itemList, itemBundle)
            end
        end
    end
    return itemList
end






function EquipTechUtils.getEquipEnhanceMaterialsItemList(partType, attrShowInfo, equipInstId)
    
    local itemList = {}

    
    local equipDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Equip]:GetOrFallback(Utils.getCurrentScope())
    if equipDepot then
        for _, itemBundle in cs_pairs(equipDepot.instItems) do
            local equipInstData = itemBundle.instData
            local templateId = equipInstData.templateId
            local _, equipData = Tables.equipTable:TryGetValue(templateId)

            
            if not equipInstData.isLocked and equipInstData.instId ~= equipInstId and equipData and
                equipData.partType == partType and EquipTechUtils.canEquipEnhance(templateId) then
                if EquipTechUtils.getEquipEnhanceSuccessProbability(equipInstData, attrShowInfo) >
                    EquipTechConst.EEquipEnhanceSuccessProb.None then
                    table.insert(itemList, itemBundle)
                end
            end
        end
    end

    return itemList
end





function EquipTechUtils.getEquipEnhanceSuccessProbability(equipInstData, attrShowInfo)
    if not equipInstData then
        return EquipTechConst.EEquipEnhanceSuccessProb.None
    end
    local _, equipData = Tables.equipTable:TryGetValue(equipInstData.templateId)
    if not equipData then
        return EquipTechConst.EEquipEnhanceSuccessProb.None
    end
    for _, attrModifier in pairs(equipData.displayAttrModifiers) do
        if attrModifier.modifierType == attrShowInfo.attrModifier and
            ((attrShowInfo.isCompositeAttr and attrShowInfo.attributeType == attrModifier.compositeAttr) or
                (not attrShowInfo.isCompositeAttr and attrShowInfo.attributeType == attrModifier.attrType)) then
            local attrValue = AttributeUtils.modifyAttributeValue(attrModifier.attrType, attrModifier.attrValue, attrShowInfo.attrShowCfg.showPercent)
            if attrValue > attrShowInfo.modifiedValue then
                return EquipTechConst.EEquipEnhanceSuccessProb.High
            elseif attrValue == attrShowInfo.modifiedValue then
                return EquipTechConst.EEquipEnhanceSuccessProb.Normal
            else
                return EquipTechConst.EEquipEnhanceSuccessProb.None
            end
        end
    end
    return EquipTechConst.EEquipEnhanceSuccessProb.None
end






function EquipTechUtils.getEnhancedAttrValue(attrInfo, equipInstData, isNextLevel)
    local enhancedLevel = equipInstData:GetAttrEnhanceLevel(attrInfo.enhancedAttrIndex)
    if isNextLevel then
        enhancedLevel = enhancedLevel + 1
    end
    if enhancedLevel > 0 and enhancedLevel <= #attrInfo.enhancedAttrValues then
        return attrInfo.enhancedAttrValues[enhancedLevel - 1]
    end
    return attrInfo.attrValue
end




function EquipTechUtils.getEquipInstData(equipInstId)
    local _, equipInstData = CS.Beyond.Gameplay.EquipUtil.TryGetEquipInstData(Utils.getCurrentScope(), equipInstId)
    return equipInstData
end






function EquipTechUtils.getAttrShowValueText(attrShowInfo, isNextLevel, equipInstId)
    local showValueText = attrShowInfo.showValue
    if isNextLevel then
        local equipInstData = EquipTechUtils.getEquipInstData(equipInstId)
        if equipInstData then
            local targetAttrModifier = nil
            local equipData = Tables.equipTable[equipInstData.templateId]
            for _, attrModifier in pairs(equipData.displayAttrModifiers) do
                if attrModifier.enhancedAttrIndex == attrShowInfo.enhancedAttrIndex then
                    targetAttrModifier = attrModifier
                    break
                end
            end
            local attrValue = EquipTechUtils.getEnhancedAttrValue(targetAttrModifier, equipInstData, true)
            showValueText = AttributeUtils.generateShowValueByValueFormat(attrValue,
                attrShowInfo.attrShowCfg.valueFormat, attrShowInfo.attrShowCfg.showPercent)
        end
    end
    return string.format(Language.LUA_WEAPON_EXHIBIT_UPGRADE_ADD_FORMAT, showValueText)
end

function EquipTechUtils.setEquipBaseInfo(view, loader, equipTemplateId)
    local itemData = Tables.itemTable[equipTemplateId]
    local equipCfg = Tables.equipTable[equipTemplateId]

    if view.equipName then
        view.equipName.text = itemData.name
    end
    view.levelNum.text = equipCfg.minWearLv
    local equipType = equipCfg.partType
    local equipTypeName = Language[UIConst.CHAR_INFO_EQUIP_TYPE_TILE_PREFIX .. LuaIndex(equipType:ToInt())]
    local equipTypeSpriteName = UIConst.EQUIP_TYPE_TO_ICON_NAME[equipType]
    view.equipTypeName.text = equipTypeName
    view.equipTypeIcon:LoadSprite(UIConst.UI_SPRITE_EQUIP_PART_ICON, equipTypeSpriteName)
    if view.rarityLightImg then
        UIUtils.setItemRarityImage(view.rarityLightImg, itemData.rarity)
    end
    if view.rarityImg then
        UIUtils.setItemRarityImage(view.rarityImg, itemData.rarity)
    end
end

function EquipTechUtils.canShowEquipEnhanceNode(equipInstId)
    if not equipInstId then
        return false
    end
    local equipInstData = EquipTechUtils.getEquipInstData(equipInstId)
    if not equipInstData then
        return false
    end
    return Utils.isSystemUnlocked(GEnums.UnlockSystemType.EquipEnhance) and
        EquipTechUtils.canEquipEnhance(equipInstData.templateId)
end







function EquipTechUtils.getUnlockedEquipPackList(isSuit)
    
    local equipPackDataList = {}
    local sortFunc = Utils.genSortFunction(EquipTechConst.EQUIP_PRODUCE_SORT_OPTION[1].keys, false)
    for packId, packFormulaDataList in pairs(Tables.equipPackFormulaTable) do
        local _, equipPackData = Tables.equipPackTable:TryGetValue(packId)
        if equipPackData and isSuit == equipPackData.isSuit then
            local equipList = {}
            for _, packFormulaData in pairs(packFormulaDataList.itemList) do
                if EquipTechUtils.isEquipFormulaVisible(packFormulaData.formulaId) then
                    table.insert(equipList, FilterUtils.processEquipProduce(Tables.equipFormulaTable[packFormulaData.formulaId]))
                end
            end
            if #equipList > 0 then
                
                local packData = {
                    equipPackData = equipPackData,
                    sortId = equipPackData.sortId,
                    isExpanded = true,
                    equipList = equipList,
                }
                table.sort(packData.equipList, sortFunc)
                table.insert(equipPackDataList, packData)
            end

        end
    end
    return equipPackDataList
end

function EquipTechUtils.isEquipFormulaVisible(formulaId)
    local _, formulaData = Tables.equipFormulaTable:TryGetValue(formulaId)
    if not formulaData then
        return false
    end
    
    local equipTechSystem = GameInstance.player.equipTechSystem
    
    local mapManager = GameInstance.player.mapManager
    local curLv = GameInstance.player.adventure.adventureLevelData.lv
    local visible = true
    if not equipTechSystem:IsFormulaUnlock(formulaData.formulaId) then
        if formulaData.unlockType == GEnums.EquipFormulaUnlockType.AdventureLevel then
            visible = formulaData.unlockValue - curLv <= Tables.equipTechConst.visibleFormulaMaxDeltaLevel
        elseif formulaData.unlockType == GEnums.EquipFormulaUnlockType.EquipFormulaChest then
            local found, instId = mapManager:GetMapMarkInstId(GEnums.MarkType.EquipFormulaChest, formulaData.unlockKey)
            visible = found and MapUtils.checkIsValidMarkInstId(instId)
        elseif formulaData.unlockType == GEnums.EquipFormulaUnlockType.DomainShop then
            local found, instId = mapManager:GetMapMarkInstId(GEnums.MarkType.DomainShop, formulaData.unlockKey)
            visible = found and MapUtils.checkIsValidMarkInstId(instId)
        else
            visible = false
        end
    end
    return visible
end

function EquipTechUtils.hasVisibleSuitEquipPack()
    for packId, packFormulaDataList in pairs(Tables.equipPackFormulaTable) do
        local _, equipPackData = Tables.equipPackTable:TryGetValue(packId)
        if equipPackData and equipPackData.isSuit then
            for _, packFormulaData in pairs(packFormulaDataList.itemList) do
                if EquipTechUtils.isEquipFormulaVisible(packFormulaData.formulaId) then
                    return true
                end
            end
        end
    end
    return false
end


_G.EquipTechUtils = EquipTechUtils
return EquipTechUtils