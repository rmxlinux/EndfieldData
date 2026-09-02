local phaseBase = require_ex('Phase/Core/PhaseBase')


PhaseForesightCharGrowth = HL.Class('PhaseForesightCharGrowth', phaseBase.PhaseBase)
PhaseForesightCharGrowth.m_tipsArrow = HL.Field(HL.Any)
PhaseForesightCharGrowth.m_tipsArrowCloseFunc = HL.Field(HL.Function)
PhaseForesightCharGrowth.m_showConvertedOperator = HL.Field(HL.Boolean) << true
PhaseForesightCharGrowth.m_showConvertedWeapon = HL.Field(HL.Boolean) << true

local s_dataInst = nil
PhaseForesightCharGrowth.s_messages = HL.StaticField(HL.Table) << {
}

PhaseForesightCharGrowth._OnInit = HL.Override() << function(self)
    PhaseForesightCharGrowth.Super._OnInit(self)
end



PhaseForesightCharGrowth.Get = HL.StaticMethod().Return(HL.Forward('PhaseForesightCharGrowth')) << function()
    if s_dataInst == nil then s_dataInst = PhaseForesightCharGrowth() end
    return s_dataInst
end








PhaseForesightCharGrowth.GetWeaponGrowthListData = HL.Method(HL.String, HL.Number, HL.Number, HL.Opt(HL.Table, HL.Any)).Return(HL.Table) << function(self, weaponId, stageId, weaponInstId, stageList, weaponInstDict)
    local okStage, stageCfg = Tables.foresightGrowthStageTable:TryGetValue(stageId)
    if not okStage then
        return { stageId = stageId, targetLevel = 0, hasPendingNeed = false }
    end
    local levelCap = stageCfg.weaponLevel
    if levelCap <= 0 then
        levelCap = 0
    end

    if Tables.foresightWeaponTable:ContainsKey(weaponId) and not Tables.weaponBasicTable:ContainsKey(weaponId) then
        local okW, wCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        return self:_GetForesightStageMaterialResult(stageCfg.stageId, levelCap, okW and wCfg.stageMaterials, "weapon")
    end

    local ok, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
    if not ok then
        return { stageId = stageCfg.stageId, targetLevel = levelCap, hasPendingNeed = false }
    end

    local _, breakthroughTemplateCfg = Tables.weaponBreakThroughTemplateTable:TryGetValue(weaponCfg.breakthroughTemplateId)
    if not breakthroughTemplateCfg then
        return { stageId = stageCfg.stageId, targetLevel = levelCap, hasPendingNeed = false }
    end

    local _, levelUpCfg = Tables.weaponUpgradeTemplateTable:TryGetValue(weaponCfg.levelTemplateId)
    if not levelUpCfg then
        return { stageId = stageCfg.stageId, targetLevel = levelCap, hasPendingNeed = false }
    end

    if levelCap > weaponCfg.maxLv then
        levelCap = weaponCfg.maxLv
    end

    local maxLevelCap = levelCap
    stageList = stageList or self:GetCultivateStageIdList()
    if stageList and #stageList > 0 then
        local okMax, maxStageCfg = Tables.foresightGrowthStageTable:TryGetValue(stageList[#stageList].stageId)
        if okMax then
            maxLevelCap = maxStageCfg.weaponLevel
            if maxLevelCap > weaponCfg.maxLv then
                maxLevelCap = weaponCfg.maxLv
            end
        end
    end

    local maxBreak, breakLv2StageLv = CharInfoUtils.getWeaponBreakLv2StageLv(weaponId)
    local curLevel, curExp, curBreakShowLv = 1, 0, 0
    do
        local resolvedInst = weaponInstId > 0 and CharInfoUtils.getWeaponByInstId(weaponInstId)
        if resolvedInst then
            curLevel = resolvedInst.weaponLv
            curExp = resolvedInst.exp
            curBreakShowLv = resolvedInst.breakthroughLv
        else
            local foundOwned = false
            local hasInst = weaponInstDict ~= nil
            if not hasInst then hasInst, weaponInstDict = GameInstance.player.inventory:TryGetAllWeaponInstItems(Utils.getCurrentScope()) end
            if hasInst then
                for _, itemBundle in pairs(weaponInstDict) do
                    local inst = itemBundle.instData
                    if inst.templateId == weaponId then
                        if not foundOwned or inst.weaponLv > curLevel
                            or (inst.weaponLv == curLevel and inst.breakthroughLv > curBreakShowLv) then
                            curLevel = inst.weaponLv
                            curExp = inst.exp
                            curBreakShowLv = inst.breakthroughLv
                            foundOwned = true
                        end
                    end
                end
            end
        end
    end

    local itemCountMap
    local goldItemId = UIConst.INVENTORY_MONEY_IDS[1]

    local function findBreakthroughCfg(showLv)
        for i = 0, breakthroughTemplateCfg.list.Count - 1 do
            local cfg = breakthroughTemplateCfg.list[i]
            if cfg.breakthroughShowLv == showLv then
                return cfg
            end
        end
    end

    local function getTargetBreakthroughShowLv(targetLevel)
        for showLv = 0, maxBreak do
            local cap = breakLv2StageLv[showLv]
            if cap and cap >= targetLevel then
                return showLv
            end
        end
        return maxBreak
    end

    local curTargetBreakShowLv = getTargetBreakthroughShowLv(levelCap)
    local maxTargetBreakShowLv = getTargetBreakthroughShowLv(maxLevelCap)
    for showLv = 1, maxTargetBreakShowLv do
        local breakCfg = findBreakthroughCfg(showLv)
        if breakCfg then
            local useReal = showLv > curBreakShowLv and showLv <= curTargetBreakShowLv
            itemCountMap = self:_AddItemCount(itemCountMap, goldItemId, useReal and breakCfg.breakthroughGold or 0)
            if breakCfg.breakItemList then
                for i = 0, breakCfg.breakItemList.Count - 1 do
                    local bundle = breakCfg.breakItemList[i]
                    itemCountMap = self:_AddItemCount(itemCountMap, bundle.id, useReal and bundle.count or 0)
                end
            end
        end
    end

    local goldNeed = 0
    if levelCap > curLevel then
        goldNeed = self:_CalcLevelUpGoldNeed(
            "weapon", levelUpCfg, curLevel, curExp, levelCap, 0)
    end
    itemCountMap = self:_AddItemCount(itemCountMap, goldItemId, goldNeed)

    local expRawList, expConvertedList
    local expCardInfos = {}
    for i = 1, Tables.characterConst.weaponExpItem.Count do
        local cardItemId = Tables.characterConst.weaponExpItem[CSIndex(i)]
        local okItem, itemCfg = Tables.itemTable:TryGetValue(cardItemId)
        if okItem then
            local okRarity, rarityCfg = Tables.weaponExpItemTable:TryGetValue(itemCfg.rarity)
            if okRarity and rarityCfg.itemExp > 0 then
                table.insert(expCardInfos, {
                    itemId = cardItemId,
                    expGain = rarityCfg.itemExp,
                    inventory = Utils.getItemCount(cardItemId, true),
                })
            end
        end
    end
    table.sort(expCardInfos, function(a, b)
        return a.expGain < b.expGain
    end)
    local expNeed = 0
    if levelCap > curLevel then
        expNeed = self:_CalcLevelExpNeed(
            "weapon", levelUpCfg, curLevel, curExp, levelCap)
    end
    if maxLevelCap > 1 then
        expRawList, expConvertedList = self:_BuildExpCardListResult(expNeed, expCardInfos)
    end

    return self:_FinalizeGrowthResult(
        stageCfg.stageId, levelCap, "weapon", itemCountMap, expRawList, expConvertedList)
end


PhaseForesightCharGrowth._GetSkillTargetLevelsFromStage = HL.Method(HL.Any).Return(HL.Table) << function(self, stageCfg)
    local targets = {}
    if not stageCfg then
        return targets
    end
    local baseBreakStage = stageCfg.breakStage
    local hasSkillLevelConfig = false
    if stageCfg.skillLevel and stageCfg.skillLevel.Count > 0 then
        for i = 0, stageCfg.skillLevel.Count - 1 do
            if stageCfg.skillLevel[i] > 0 then
                hasSkillLevelConfig = true
                break
            end
        end
    end
    if hasSkillLevelConfig then
        if stageCfg.skillLevel.Count ~= 4 then
            logger.error(string.format(
                "GetSkillTargetLevels: skillLevel must have 4 entries. stageId=%d count=%d",
                stageCfg.stageId, stageCfg.skillLevel.Count))
        end
        for i = 1, math.min(4, stageCfg.skillLevel.Count) do
            targets[i] = stageCfg.skillLevel[CSIndex(i)]
        end
    elseif baseBreakStage >= 0 then
        for i = 1, #UIConst.CHAR_INFO_SKILL_SHOW_ORDER do
            local skillGroupType = UIConst.CHAR_INFO_SKILL_SHOW_ORDER[i]
            targets[i] = CharInfoUtils.getSkillCanUpgradeLv(skillGroupType, baseBreakStage)
        end
    end
    return targets
end


PhaseForesightCharGrowth._CountTalentNodesForBreakStage = HL.Method(HL.Any, HL.Number, HL.Number).Return(HL.Number, HL.Number) << function(self, growthData, baseBreakStage, charInstId)
    local unlockable = 0
    local unlocked = 0
    if not growthData or not growthData.talentNodeMap or baseBreakStage < 0 then
        return unlocked, unlockable
    end
    for nodeId, nodeCfg in pairs(growthData.talentNodeMap) do
        local nodeBreakStage
        if nodeCfg.nodeType == GEnums.TalentNodeType.Attr then
            nodeBreakStage = nodeCfg.attributeNodeInfo.breakStage
        elseif nodeCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
            nodeBreakStage = nodeCfg.passiveSkillNodeInfo.breakStage
        elseif nodeCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
            nodeBreakStage = nodeCfg.factorySkillNodeInfo.breakStage
        end
        if nodeBreakStage then
            if nodeBreakStage <= baseBreakStage then
                unlockable = unlockable + 1
            end
            if charInstId > 0 then
                local isActive
                if nodeCfg.nodeType == GEnums.TalentNodeType.Attr then
                    isActive = select(1, CharInfoUtils.getAttributeNodeStatus(charInstId, nodeId))
                elseif nodeCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
                    isActive = select(1, CharInfoUtils.getPassiveSkillNodeStatus(charInstId, nodeId))
                elseif nodeCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
                    isActive = select(1, CharInfoUtils.getShipSkillNodeStatus(charInstId, nodeId))
                end
                if isActive then
                    unlocked = unlocked + 1
                end
            end
        end
    end
    return unlocked, unlockable
end

PhaseForesightCharGrowth.GetSkillGrowthHeaderBundle = HL.Method(HL.String, HL.Number, HL.Opt(HL.Table, HL.Table)).Return(HL.Table) << function(self, templateId, stageId, stageList, growthDataForGoal)
    templateId, growthData, stageCfg, _ = self:_ResolveGrowthStage(templateId, stageId)
    local skillTargets = self:_GetSkillTargetLevelsFromStage(stageCfg)

    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    local isOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    local curSkillLevels
    if isOwned then
        curSkillLevels = {}
        for i = 1, #UIConst.CHAR_INFO_SKILL_SHOW_ORDER do
            local skillGroupType = UIConst.CHAR_INFO_SKILL_SHOW_ORDER[i]
            local levelInfo = CharInfoUtils.getCharSkillLevelInfoByType(playerChar, skillGroupType)
            curSkillLevels[i] = levelInfo and levelInfo.level or 1
        end
    end

    local talentUnlocked, talentUnlockable = 0, 0
    if stageCfg and stageCfg.containTalent and growthData and stageCfg.breakStage >= 0 then
        local charInstId = isOwned and playerChar.instId or 0
        talentUnlocked, talentUnlockable = self:_CountTalentNodesForBreakStage(
            growthData, stageCfg.breakStage, charInstId)
    end

    growthDataForGoal = growthDataForGoal or self:GetSkillGrowthItemListData(templateId, stageId, stageList)
    local showSkillHidden = false
    local ok, foresightCfg = Tables.foresightCharGrowthTable:TryGetValue(templateId)
    if ok and foresightCfg.isReplica ~= true and foresightCfg.showSkill == false then
        showSkillHidden = true
    end

    return {
        skillTargets = skillTargets,
        curSkillLevels = curSkillLevels,
        talentUnlocked = talentUnlocked,
        talentUnlockable = talentUnlockable,
        isGoalReached = self:IsOperatorGoalReached(growthDataForGoal),
        isCurStageMax = self:IsCurCultivateStageMax(templateId, stageList),
        showSkillHidden = showSkillHidden,
        containTalent = stageCfg and stageCfg.containTalent == true,
    }
end



PhaseForesightCharGrowth.GetSkillGrowthItemListData = HL.Method(HL.String, HL.Number, HL.Opt(HL.Table)).Return(HL.Table) << function(self, charId, stageId, stageList)
    if self:IsForesightCharId(charId) then
        local okS, s = Tables.foresightGrowthStageTable:TryGetValue(stageId)
        local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
        return self:_GetForesightStageMaterialResult(stageId, okS and s.level or 0, ok and cfg.stageMaterials, "skill")
    end
    local growthData, stageCfg, levelCap
    charId, growthData, stageCfg, levelCap = self:_ResolveGrowthStage(charId, stageId)
    if not growthData or not stageCfg then
        return { stageId = stageId, targetLevel = levelCap or 0, hasPendingNeed = false }
    end

    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(charId, GEnums.CharType.Default)
    local isOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    local charInstId = isOwned and playerChar.instId or nil
    local curBreakStage = stageCfg.breakStage

    local maxBreakStage = curBreakStage
    local maxStageCfg = stageCfg
    stageList = stageList or self:GetCultivateStageIdList()
    if stageList and #stageList > 0 then
        local _, _, resolvedMaxStageCfg = self:_ResolveGrowthStage(charId, stageList[#stageList].stageId)
        if resolvedMaxStageCfg then
            maxStageCfg = resolvedMaxStageCfg
            maxBreakStage = resolvedMaxStageCfg.breakStage
        end
    end

    local itemCountMap
    local goldItemId = UIConst.INVENTORY_MONEY_IDS[1]

    local function addTalentNodeItems(nodeId, inCurrentGoal)
        local ok, nodeCfg = growthData.talentNodeMap:TryGetValue(nodeId)
        if not ok or not nodeCfg.requiredItem then
            return
        end
        local isActive = false
        if isOwned then
            if nodeCfg.nodeType == GEnums.TalentNodeType.Attr then
                isActive = select(1, CharInfoUtils.getAttributeNodeStatus(charInstId, nodeId))
            elseif nodeCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
                isActive = select(1, CharInfoUtils.getPassiveSkillNodeStatus(charInstId, nodeId))
            elseif nodeCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
                isActive = select(1, CharInfoUtils.getShipSkillNodeStatus(charInstId, nodeId))
            end
        end
        local useReal = inCurrentGoal and not isActive
        for _, bundle in pairs(nodeCfg.requiredItem) do
            itemCountMap = self:_AddItemCount(itemCountMap, bundle.id, useReal and bundle.count or 0)
        end
    end

    local function addSkillToTargetLevel(skillGroupType, curTargetSkillLevel, maxTargetSkillLevel)
        local catalogTarget = maxTargetSkillLevel or 0
        if catalogTarget <= 1 then
            return
        end
        local skillGroupCfg = CharInfoUtils.getCharSkillGroupCfgByType(charId, skillGroupType)
        if not skillGroupCfg then
            return
        end
        local skillGroupId = skillGroupCfg.skillGroupId
        local curLevel = 1
        if isOwned then
            local skillInfo = CharInfoUtils.getCharSkillLevelInfo(playerChar, skillGroupId)
            if skillInfo then
                curLevel = skillInfo.level
            end
        end
        local goalTarget = curTargetSkillLevel or 1
        for skillLv = 2, catalogTarget do
            local skillUpgradeCfg = CharInfoUtils.getSkillTalentNodeBySkillId(charId, skillGroupId, skillLv)
            if skillUpgradeCfg then
                local useReal = skillLv > curLevel and skillLv <= goalTarget
                itemCountMap = self:_AddItemCount(itemCountMap, goldItemId, useReal and skillUpgradeCfg.goldCost or 0)
                if skillUpgradeCfg.itemBundle then
                    for _, bundle in pairs(skillUpgradeCfg.itemBundle) do
                        itemCountMap = self:_AddItemCount(itemCountMap, bundle.id, useReal and bundle.count or 0)
                    end
                end
            end
        end
    end

    if stageCfg.containTalent and maxBreakStage >= 0 then
        for nodeId, nodeCfg in pairs(growthData.talentNodeMap) do
            local nodeBreakStage
            if nodeCfg.nodeType == GEnums.TalentNodeType.Attr then
                nodeBreakStage = nodeCfg.attributeNodeInfo.breakStage
            elseif nodeCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
                nodeBreakStage = nodeCfg.passiveSkillNodeInfo.breakStage
            elseif nodeCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
                nodeBreakStage = nodeCfg.factorySkillNodeInfo.breakStage
            end
            if nodeBreakStage and nodeBreakStage <= maxBreakStage then
                addTalentNodeItems(nodeId, nodeBreakStage <= curBreakStage)
            end
        end
    end

    local curSkillTargets = self:_GetSkillTargetLevelsFromStage(stageCfg)
    local maxSkillTargets = self:_GetSkillTargetLevelsFromStage(maxStageCfg)
    for i = 1, #UIConst.CHAR_INFO_SKILL_SHOW_ORDER do
        local skillGroupType = UIConst.CHAR_INFO_SKILL_SHOW_ORDER[i]
        addSkillToTargetLevel(skillGroupType, curSkillTargets[i], maxSkillTargets[i])
    end

    return self:_FinalizeGrowthResult(stageCfg.stageId, levelCap, "skill", itemCountMap, nil, nil)
end












PhaseForesightCharGrowth.GetLevelGrowthItemListData = HL.Method(HL.String, HL.Number, HL.Opt(HL.Table)).Return(HL.Table) << function(self, charId, stageId, stageList)
    if self:IsForesightCharId(charId) then
        local okS, s = Tables.foresightGrowthStageTable:TryGetValue(stageId)
        local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
        return self:_GetForesightStageMaterialResult(stageId, okS and s.level or 0, ok and cfg.stageMaterials, "upgrade")
    end
    local growthData, stageCfg, levelCap
    charId, growthData, stageCfg, levelCap = self:_ResolveGrowthStage(charId, stageId)
    if not growthData or not stageCfg then
        return { stageId = stageId, targetLevel = levelCap or 0, hasPendingNeed = false }
    end

    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(charId, GEnums.CharType.Default)
    local isOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    local curLevel, curExp, charInstId = 1, 0, nil
    if isOwned then
        charInstId = playerChar.instId
        curLevel = playerChar.level
        curExp = playerChar.exp
    end
    local curBreakStage = stageCfg.breakStage
    local maxBreakStage = curBreakStage
    local maxLevelCap = levelCap
    stageList = stageList or self:GetCultivateStageIdList()
    if stageList and #stageList > 0 then
        local _, _, maxStageCfg, resolvedMaxLevelCap = self:_ResolveGrowthStage(charId, stageList[#stageList].stageId)
        if maxStageCfg then
            maxBreakStage = maxStageCfg.breakStage
            maxLevelCap = resolvedMaxLevelCap
        end
    end
    local processedBreakNodes = {}

    local itemCountMap
    local goldItemId = UIConst.INVENTORY_MONEY_IDS[1]

    local function addBreakNodeItems(nodeId, inCurrentGoal)
        if processedBreakNodes[nodeId] then
            return
        end
        local ok, breakCfg = growthData.charBreakCostMap:TryGetValue(nodeId)
        if not ok or not breakCfg.requiredItem then
            return
        end
        local active = false
        if isOwned then
            if breakCfg.nodeType == GEnums.TalentNodeType.CharBreak then
                active = select(1, CharInfoUtils.getCharBreakNodeStatus(charInstId, nodeId))
            elseif breakCfg.nodeType == GEnums.TalentNodeType.EquipBreak then
                active = select(1, CharInfoUtils.getEquipBreakNodeStatus(charInstId, nodeId))
            end
        end
        processedBreakNodes[nodeId] = true
        local useReal = inCurrentGoal and not active
        for _, bundle in pairs(breakCfg.requiredItem) do
            itemCountMap = self:_AddItemCount(itemCountMap, bundle.id, useReal and bundle.count or 0)
        end
    end

    if maxBreakStage >= 0 then
        for nodeId, breakCfg in pairs(growthData.charBreakCostMap) do
            if breakCfg.breakStage <= maxBreakStage then
                addBreakNodeItems(nodeId, breakCfg.breakStage <= curBreakStage)
            end
        end
    end

    local goldNeed = 0
    if levelCap > curLevel then
        goldNeed = self:_CalcLevelUpGoldNeed(
            "char", Tables.charLevelUpTable, curLevel, curExp, levelCap, 0)
    end
    itemCountMap = self:_AddItemCount(itemCountMap, goldItemId, goldNeed)

    local STAGE1_MAX_LEVEL = Tables.charBreakStageTable[2].maxCharLevel
    local expRawList, expConvertedList
    if maxLevelCap > 1 then
        local stage1ExpNeed = 0
        if levelCap > curLevel and curLevel < STAGE1_MAX_LEVEL then
            stage1ExpNeed = self:_CalcLevelExpNeed(
                "char", Tables.charLevelUpTable, curLevel, curExp, math.min(STAGE1_MAX_LEVEL, levelCap))
        end
        expRawList, expConvertedList = self:_AppendExpCardListResult(
            expRawList, expConvertedList, stage1ExpNeed, self:_CollectCharExpCardInfos(Tables.charBreakTable[0]))
    end
    if maxLevelCap > STAGE1_MAX_LEVEL then
        local stage2ExpNeed = 0
        if levelCap > STAGE1_MAX_LEVEL and levelCap > curLevel then
            local fromLevel, fromExp = STAGE1_MAX_LEVEL, 0
            if curLevel >= STAGE1_MAX_LEVEL then
                fromLevel, fromExp = curLevel, curExp
            end
            if fromLevel < levelCap then
                stage2ExpNeed = self:_CalcLevelExpNeed(
                    "char", Tables.charLevelUpTable, fromLevel, fromExp, levelCap)
            end
        end
        expRawList, expConvertedList = self:_AppendExpCardListResult(
            expRawList, expConvertedList, stage2ExpNeed, self:_CollectCharExpCardInfos(Tables.charBreakTable[3]))
    end

    return self:_FinalizeGrowthResult(
        stageCfg.stageId, levelCap, "upgrade", itemCountMap, expRawList, expConvertedList)
end
















PhaseForesightCharGrowth.IsCharPinned = HL.Method(HL.String).Return(HL.Boolean) << function(self, templateId)
    if string.isEmpty(templateId) then
        return false
    end
    local charBag = GameInstance.player.charBag
    if not charBag then
        return false
    end
    return charBag:IsCharCultivatePriorityPinned(templateId)
end


PhaseForesightCharGrowth.RequestSetCharPinned = HL.Method(HL.String, HL.Boolean, HL.String).Return(HL.Boolean) << function(self, templateId, isPinned, charStatus)
    if string.isEmpty(templateId) then
        return false
    end
    local charBag = GameInstance.player.charBag
    if not charBag then
        return false
    end
    local pinCountAfter = 0
    local bundle = self:GetCharListBundle()
    for _, item in ipairs(bundle.gachaPreviewList or {}) do
        if item.templateId and not item.isForesight and self:IsCharPinned(item.templateId) then
            pinCountAfter = pinCountAfter + 1
        end
    end
    for _, item in ipairs(bundle.charInfoList or {}) do
        if item.templateId and not item.isForesight and self:IsCharPinned(item.templateId) then
            pinCountAfter = pinCountAfter + 1
        end
    end
    if isPinned then
        pinCountAfter = pinCountAfter + 1
    else
        pinCountAfter = pinCountAfter - 1
    end
    Notify(MessageConst.SHOW_TOAST,isPinned and Language.LUA_FORESIGHT_GROWTH_CTRL_PIN_SUC or Language.LUA_FORESIGHT_GROWTH_CTRL_PIN_CANCEL_SUC)
    EventLogManagerInst:GameEvent_CultiOverviewPinChange(templateId, isPinned, charStatus, pinCountAfter)
    return charBag:Send_SetCharPriorityList(templateId, isPinned)
end


PhaseForesightCharGrowth.GetCultivateStageIdList = HL.Method().Return(HL.Table) << function(self)
    local rows = {}
    for _, stageCfg in pairs(Tables.foresightGrowthStageTable) do
        table.insert(rows, {
            stageId = stageCfg.stageId,
            sortWeight = stageCfg.sortWeight or stageCfg.stageId,
            name = stageCfg.name,
        })
    end
    table.sort(rows, function(a, b)
        if a.sortWeight ~= b.sortWeight then
            return a.sortWeight < b.sortWeight
        end
        return a.stageId < b.stageId
    end)
    return rows
end

PhaseForesightCharGrowth.GetCharFinishedCultivateStageId = HL.Method(HL.String, HL.Opt(HL.Table)).Return(HL.Number) << function(self, charId, stageList)
    if string.isEmpty(charId) then
        return 0
    end
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(charId, GEnums.CharType.Default)
    if not playerChar or not CharInfoUtils.IsServerDefaultChar(playerChar) or not playerChar.instId or playerChar.instId <= 0 or not CharInfoUtils.getCharGrowthData(CSCharUtils.GetVirtualCharTemplateId(charId)) then
        return 0
    end
    local weaponInstId = playerChar.weaponInstId
    local weaponInst = weaponInstId and weaponInstId > 0 and CharInfoUtils.getWeaponByInstId(weaponInstId)
    if not weaponInst then
        return 0
    end
    stageList = stageList or self:GetCultivateStageIdList()
    for i = #stageList, 1, -1 do
        local stageId = stageList[i].stageId
        if self:IsOperatorGoalReached(self:GetLevelGrowthItemListData(charId, stageId, stageList)) and self:IsOperatorGoalReached(self:GetSkillGrowthItemListData(charId, stageId, stageList)) and self:IsOperatorGoalReached(self:GetWeaponGrowthListData(weaponInst.templateId, stageId, weaponInstId, stageList)) then
            return stageId
        end
    end
    return 0
end

PhaseForesightCharGrowth.GetCultivateStageIconState = HL.Method(HL.Number).Return(HL.Opt(HL.String)) << function(self, stageId)
    local ok, cfg = Tables.foresightGrowthConfigTable:TryGetValue("StageId2ShowIcon")
    if not ok then
        return nil
    end
    for i = 0, cfg.arr.Count - 1 do
        if cfg.arr[i] == stageId then
            return cfg.stringList[i]
        end
    end
    return nil
end


PhaseForesightCharGrowth.GetCharCultivateStageId = HL.Method(HL.String).Return(HL.Number,HL.Boolean) << function(self, templateId)
    local defaultStage = 4
    if string.isEmpty(templateId) then
        return defaultStage, false
    end
    if self:IsForesightCharId(templateId) then
        local hasValue, stageId = ClientDataManagerInst:GetInt("ForesightCultivateStage_" .. templateId, false, defaultStage, "ForesightCharGrowth")
        if hasValue then
            return stageId, true
        end
        return defaultStage, false
    end
    local charBag = GameInstance.player.charBag
    if not charBag then
        return defaultStage, false
    end
    local ok, stageId = charBag:TryGetCharCultivatePlanStageId(templateId)
    if ok then
        return stageId, true
    end
    return defaultStage, false
end


PhaseForesightCharGrowth.RequestSetCharCultivateStage = HL.Method(HL.String, HL.Number, HL.String, HL.Number).Return(HL.Boolean) << function(self, templateId, stageId, charStatus, stageIdBefore)
    EventLogManagerInst:GameEvent_CultiOverviewTargetChange(templateId, stageId, stageIdBefore, charStatus)
    if self:IsForesightCharId(templateId) then
        ClientDataManagerInst:SetInt(
            "ForesightCultivateStage_" .. templateId, stageId, false,
            "ForesightCharGrowth", EClientDataTimeValidType.Permanent)
        Notify(MessageConst.ON_CHAR_CULTIVATE_PLAN_CHANGED)
        return true
    end
    local charBag = GameInstance.player.charBag
    if not charBag then
        return false
    end
    return charBag:Send_SetCharCultivatePlan(templateId, stageId)
end


PhaseForesightCharGrowth._CollectListContext = HL.Method().Return(HL.Table, HL.Table, HL.Table) << function(self)
    local upCharIdSet = {}
    local poolList = {}
    for poolId, csInfo in pairs(GameInstance.player.gacha.poolInfos) do
        if csInfo.isChar and csInfo.isOpenValid then
            local ok, poolCfg = Tables.gachaCharPoolTable:TryGetValue(poolId)
            if ok then
                table.insert(poolList, poolCfg)
                if poolCfg.upCharIds then
                    for i = 0, poolCfg.upCharIds.Count - 1 do
                        upCharIdSet[poolCfg.upCharIds[i]] = true
                    end
                end
            end
        end
    end
    table.sort(poolList, Utils.genSortFunction({ "sortId" }, true))
    return upCharIdSet, self:_CollectFormationInstIdSet(), poolList
end

PhaseForesightCharGrowth._CollectFormationInstIdSet = HL.Method().Return(HL.Table) << function(self)
    local formationInstIdSet = {}
    local charBag = GameInstance.player.charBag
    local memberList = charBag.teamList[charBag.curTeamIndex].memberList
    for i = 1, memberList.Count do
        formationInstIdSet[memberList[CSIndex(i)]] = true
    end
    return formationInstIdSet
end

PhaseForesightCharGrowth.IsForesightCharId = HL.Method(HL.String, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, charId, isInOpenPool)
    local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
    if not ok or cfg.isReplica == true then
        return false
    end
    if not string.isEmpty(cfg.activityId) then
        return not ActivityUtils.isActivityUnlocked(cfg.activityId)
    end
    if isInOpenPool ~= nil then
        return not isInOpenPool
    end
    return string.isEmpty(self:FindCharGachaPoolId(charId))
end


PhaseForesightCharGrowth._BuildGachaCharListItem = HL.Method(HL.String, HL.Table, HL.Table).Return(HL.Opt(HL.Table))
    << function(self, charId, upCharIdSet, formationInstIdSet)
    if self:IsForesightCharId(charId, upCharIdSet[charId] == true) then
        return nil
    end
    local ok, charCfg = Tables.characterTable:TryGetValue(charId)
    if not ok then
        return nil
    end
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(charId, GEnums.CharType.Default)
    local isOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    local instId = isOwned and playerChar.instId or nil
    return {
        templateId = charId,
        instId = instId,
        name = charCfg.name,
        profession = charCfg.profession,
        charTypeId = charCfg.charTypeId,
        level = isOwned and playerChar.level or nil,
        ownTime = isOwned and playerChar.ownTime or 0,
        rarity = charCfg.rarity,
        sortOrder = charCfg.sortOrder,
        slotIndex = Const.BATTLE_SQUAD_MAX_CHAR_NUM + 1,
        slotReverseIndex = -1,
        isSingleSelect = true,
        replaceablePriority = 0,
        replaceablePriorityReverse = 1,
        isOwned = isOwned,
        isForesight = false,
        isInCurGachaPool = upCharIdSet[charId] == true,
        isInCurFormation = instId ~= nil and formationInstIdSet[instId] == true,
    }
end


PhaseForesightCharGrowth._BuildForesightCharListItem = HL.Method(HL.String, HL.Boolean).Return(HL.Opt(HL.Table))
    << function(self, charId, isInOpenPool)
    if not self:IsForesightCharId(charId, isInOpenPool) then
        return nil
    end
    local _, foresightCfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
    return {
        templateId = charId,
        instId = nil,
        name = foresightCfg.name,
        level = 1,
        ownTime = 0,
        rarity = foresightCfg.rarity,
        sortOrder = 0,
        profession = foresightCfg.profession,
        charTypeId = foresightCfg.charTypeId,
        slotIndex = Const.BATTLE_SQUAD_MAX_CHAR_NUM + 1,
        slotReverseIndex = -1,
        isSingleSelect = true,
        replaceablePriority = 0,
        replaceablePriorityReverse = 1,
        isOwned = false,
        isForesight = true,
        isInCurGachaPool = false,
        isInCurFormation = false,
        previewTag = "foresight",
    }
end


PhaseForesightCharGrowth._BuildDownCharacterList = HL.Method(HL.Table, HL.Table).Return(HL.Table)
    << function(self, upCharIdSet, formationInstIdSet)
    local list = {}
    for charId, _ in pairs(Tables.gachaCharInfoTable) do
        local item = self:_BuildGachaCharListItem(charId, upCharIdSet, formationInstIdSet)
        if item then
            table.insert(list, item)
        end
    end
    local charBag = GameInstance.player.charBag
    for _, charInfo in cs_pairs(charBag.charInfos) do
        if CharInfoUtils.IsServerDefaultChar(charInfo) then
            local charId = charInfo.templateId
            if not Tables.gachaCharInfoTable:ContainsKey(charId) then
                local item = self:_BuildGachaCharListItem(charId, upCharIdSet, formationInstIdSet)
                if item then
                    table.insert(list, item)
                end
            end
        end
    end
    return list
end



PhaseForesightCharGrowth._BuildGachaPreviewList = HL.Method(HL.Table, HL.Table, HL.Table).Return(HL.Table)
    << function(self, upCharIdSet, formationInstIdSet, poolList)
    local result = {}
    local item
    local currentCharIdSet = {}
    local previewTagOrder = { current = 1, rerun = 2, activity = 3, foresight = 4, replica = 5, foresight_activity = 6 }
    for _, poolCfg in ipairs(poolList) do
        if poolCfg.upCharIds then
            local previewTag = poolCfg.type == GEnums.CharacterGachaPoolType.Rerun and "rerun" or "current"
            for i = 0, poolCfg.upCharIds.Count - 1 do
                local charId = poolCfg.upCharIds[i]
                if not currentCharIdSet[charId]
                    and Tables.gachaCharInfoTable[charId]
                    and Tables.characterTable:TryGetValue(charId) then
                    currentCharIdSet[charId] = true
                    item = self:_BuildGachaCharListItem(charId, upCharIdSet, formationInstIdSet)
                    if item then
                        item.previewTag, item.previewTagSort = previewTag, previewTagOrder[previewTag]
                        table.insert(result, item)
                    end
                end
            end
        end
    end
    for charId, cfg in pairs(Tables.foresightCharGrowthTable) do
        local tag = not currentCharIdSet[charId] and (cfg.isReplica == true and "replica" or not string.isEmpty(cfg.activityId) and ActivityUtils.isActivityUnlocked(cfg.activityId) and "activity")
        if tag then
            item = self:_BuildGachaCharListItem(charId, upCharIdSet, formationInstIdSet)
            if item then
                item.previewTag, item.previewTagSort, currentCharIdSet[charId] = tag, previewTagOrder[tag], true
                table.insert(result, item)
            end
        end
    end
    for charId, _ in pairs(Tables.foresightCharGrowthTable) do
        if not currentCharIdSet[charId] then
            item = self:_BuildForesightCharListItem(charId, upCharIdSet[charId] == true)
            if item then
                local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
                item.previewTagSort = (ok and not string.isEmpty(cfg.activityId)) and previewTagOrder.foresight_activity or previewTagOrder.foresight
                table.insert(result, item)
            end
        end
    end
    for _, item in ipairs(result) do
        local ok, cfg = Tables.foresightCharGrowthTable:TryGetValue(item.templateId)
        item.sortWeightReverse = -(ok and cfg.sortWeight or 0)
    end
    table.sort(result, Utils.genSortFunction({ "previewTagSort", "sortWeightReverse" }, true))
    return result
end


PhaseForesightCharGrowth.GetCharListBundle = HL.Method().Return(HL.Table) << function(self)
    local upCharIdSet, formationInstIdSet, poolList = self:_CollectListContext()
    return {
        gachaPreviewList = self:_BuildGachaPreviewList(upCharIdSet, formationInstIdSet, poolList),
        charInfoList = self:_BuildDownCharacterList(upCharIdSet, formationInstIdSet),
    }
end


PhaseForesightCharGrowth.JumpToItemObtian = HL.Method(HL.Table, HL.Table).Return(HL.Boolean)
    << function(self, categoryTable, foresightGoToLog)
    local function normalizeCategoryItemList(category)
        if category.rawList or category.convertedList then
            if category.rawList and #category.rawList > 0 then
                return category.rawList
            end
            return category.convertedList or {}
        end
        if category.materials then
            return category.materials
        end
        return category
    end

    local function pickJumpTargetItemId(itemList)
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

    local function inferJumpModeFromCategoryTable(category)
        if category.rawList or category.convertedList then
            return "dungeon"
        end
        local firstEntry = category[1]
        if firstEntry and firstEntry.itemId == UIConst.INVENTORY_MONEY_IDS[1] then
            return "dungeon"
        end
        if firstEntry then
            local ok, itemCfg = Tables.itemTable:TryGetValue(firstEntry.itemId)
            if ok and itemCfg.type == GEnums.ItemType.Material then
                return "collect"
            end
        end
        return "dungeon"
    end

    local function isObtainWayMatchJumpMode(jumpMode, obtainWayCfg, phaseArgs, phaseId)
        if jumpMode == "collect" then
            return phaseArgs ~= nil and not string.isEmpty(phaseArgs.resourceTemplateId)
        end
        local phaseName = obtainWayCfg.phaseId
        if phaseName == "UsableItemChest" or phaseName == "CashShop" or phaseName == "ShopTrade" then
            return false
        end
        if phaseId == PhaseId.DungeonEntry or phaseName == "AdventureBook" then
            return true
        end
        if phaseId == PhaseId.Map then
            if phaseArgs and not string.isEmpty(phaseArgs.resourceTemplateId) then
                return false
            end
            if phaseArgs and not string.isEmpty(phaseArgs.instId) then
                return true
            end
        end
        if obtainWayCfg.bindSystem == GEnums.UnlockSystemType.Dungeon then
            return true
        end
        return false
    end

    local function foreachObtainWayId(obtainWayIds, visitor)
        if not obtainWayIds then
            return false
        end
        if obtainWayIds.Count then
            for i = 0, obtainWayIds.Count - 1 do
                if visitor(obtainWayIds[i], i) then
                    return true
                end
            end
            return false
        end
        local keys = {}
        for k, _ in pairs(obtainWayIds) do
            table.insert(keys, k)
        end
        table.sort(keys, function(a, b) return a < b end)
        for _, k in ipairs(keys) do
            if visitor(obtainWayIds[k], k) then
                return true
            end
        end
        return false
    end

    local function getFirstCustomObtainWay(itemId, jumpMode)
        local ok, itemCfg = Tables.itemTable:TryGetValue(itemId)
        if not ok or not itemCfg.obtainWayIds then
            return nil
        end
        local firstObtainWay
        foreachObtainWayId(itemCfg.obtainWayIds, function(obtainWayId)
            local _, obtainWayCfg = Tables.systemJumpTable:TryGetValue(obtainWayId)
            if not obtainWayCfg then
                return false
            end
            local isShowOrNoCondition = true
            local showSucc, showCondition = Tables.obtainWayShowCondTable:TryGetValue(obtainWayId)
            if showSucc then
                isShowOrNoCondition = ItemObtainWaysUtils.CheckObtainWayCondition(showCondition)
            end
            if not isShowOrNoCondition or not Utils.isSystemUnlocked(obtainWayCfg.bindSystem) then
                return false
            end
            local phaseId = PhaseId[obtainWayCfg.phaseId]
            local phaseArgs = Utils.buildSystemJumpPhaseArgsWithItem(obtainWayCfg, itemId)
            if not isObtainWayMatchJumpMode(jumpMode, obtainWayCfg, phaseArgs, phaseId) then
                return false
            end
            local blockJumpToast = ""
            if phaseId ~= nil and not PhaseManager:CheckCanOpenPhase(phaseId, phaseArgs) then
                if obtainWayCfg.bindSystem == GEnums.UnlockSystemType.Map then
                    blockJumpToast = Language.LUA_OBTAIN_WAYS_MAP_JUMP_BLOCKED
                else
                    blockJumpToast = Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED
                end
            end
            firstObtainWay = {
                phaseId = phaseId,
                phaseArgs = phaseArgs,
                blockJumpToast = blockJumpToast,
                obtainWayId = obtainWayId,
            }
            return true
        end)
        return firstObtainWay
    end

    local itemList = normalizeCategoryItemList(categoryTable)
    local itemId = pickJumpTargetItemId(itemList)
    if string.isEmpty(itemId) then
        return false
    end

    local jumpMode = inferJumpModeFromCategoryTable(categoryTable)
    local obtainWay = getFirstCustomObtainWay(itemId, jumpMode)
    if not obtainWay or not obtainWay.phaseId then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED)
        return false
    end
    if UIManager:ShouldBlockObtainWaysPhaseJump(obtainWay.phaseId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED)
        return false
    end
    if not string.isEmpty(obtainWay.blockJumpToast) then
        Notify(MessageConst.SHOW_TOAST, obtainWay.blockJumpToast)
        return false
    end

    local phaseId = obtainWay.phaseId
    local phaseArgs = obtainWay.phaseArgs
    local goToName = PhaseManager:GetPhaseName(phaseId)
    local missingItemIds = {}
    for _, entry in ipairs(itemList) do
        if not string.isEmpty(entry.itemId) and (entry.count or 0) > 0
            and Utils.getItemCount(entry.itemId, true) < entry.count then
            missingItemIds[#missingItemIds + 1] = entry.itemId
        end
    end
    EventLogManagerInst:GameEvent_CultiOverviewGoTo(foresightGoToLog.charId,goToName,table.concat(missingItemIds, ";"),foresightGoToLog.charStatus or "",foresightGoToLog.sourceBlock or 0,false,itemId or "")
    if phaseId == PhaseId.Map then
        phaseArgs = phaseArgs and lume.deepCopy(phaseArgs) or {}
        local canOpen, toast = MapUtils.checkCanOpenMapAndParseArgs(phaseArgs)
        if not canOpen then
            Notify(MessageConst.SHOW_TOAST, toast or Language.LUA_OBTAIN_WAYS_MAP_JUMP_BLOCKED)
            return false
        end
        local instId = phaseArgs.instId
        if jumpMode == "collect" and not string.isEmpty(instId) then
            MapUtils.openMap(instId)
            return true
        end
    end
    PhaseManager:OpenPhase(phaseId,phaseArgs)
    return true
end



PhaseForesightCharGrowth._AddItemCount = HL.Method(HL.Any, HL.String, HL.Number).Return(HL.Any) << function(self, itemCountMap, itemId, count)
    if not itemCountMap then
        itemCountMap = {}
    end
    if count == 0 then
        itemCountMap[itemId] = itemCountMap[itemId] or 0
    else
        itemCountMap[itemId] = (itemCountMap[itemId] or 0) + count
    end
    return itemCountMap
end

PhaseForesightCharGrowth._GetLevelUpgradeCost = HL.Method(HL.String, HL.Any, HL.Number).Return(HL.Number, HL.Number) << function(self, sourceType, costSource, level)
    if sourceType == "char" then
        local data = costSource[level]
        return data.gold, data.exp
    end
    local data = costSource.list[CSIndex(level)]
    return data.lvUpGold, data.lvUpExp
end

PhaseForesightCharGrowth._CalcLevelUpGoldNeed = HL.Method(
    HL.String, HL.Any, HL.Number, HL.Number, HL.Number, HL.Number
).Return(HL.Number) << function(self, sourceType, costSource, oldLv, oldExp, newLv, newExp)
    if newLv <= oldLv then
        return 0
    end
    local levelUpGold, levelUpExp = self:_GetLevelUpgradeCost(sourceType, costSource, oldLv)
    local goldNeed = 0
    if levelUpGold > 0 then
        if oldExp > 0 then
            goldNeed = goldNeed + math.ceil(levelUpGold * (levelUpExp - oldExp) / levelUpExp)
        else
            goldNeed = goldNeed + levelUpGold
        end
    end
    for level = oldLv + 1, newLv - 1 do
        levelUpGold = self:_GetLevelUpgradeCost(sourceType, costSource, level)
        goldNeed = goldNeed + levelUpGold
    end
    if newExp > 0 then
        levelUpGold, levelUpExp = self:_GetLevelUpgradeCost(sourceType, costSource, newLv)
        if levelUpGold > 0 then
            goldNeed = goldNeed + math.ceil(levelUpGold * newExp / levelUpExp)
        end
    end
    return goldNeed
end

PhaseForesightCharGrowth._CalcLevelExpNeed = HL.Method(
    HL.String, HL.Any, HL.Number, HL.Number, HL.Number
).Return(HL.Number) << function(self, sourceType, costSource, fromLevel, fromExp, toLevel)
    if toLevel <= fromLevel then
        return 0
    end
    local _, levelUpExp = self:_GetLevelUpgradeCost(sourceType, costSource, fromLevel)
    local accExp = levelUpExp - fromExp
    for level = fromLevel + 1, toLevel - 1 do
        _, levelUpExp = self:_GetLevelUpgradeCost(sourceType, costSource, level)
        accExp = accExp + levelUpExp
    end
    return accExp
end

PhaseForesightCharGrowth._CollectCharExpCardInfos = HL.Method(HL.Any).Return(HL.Table) << function(self, breakCfg)
    local expCardInfos = {}
    if not breakCfg or not breakCfg.availableExpItems then
        return expCardInfos
    end
    for i = 0, breakCfg.availableExpItems.Count - 1 do
        local cardItemId = breakCfg.availableExpItems[i]
        local ok, expItemData = Tables.expItemDataMap:TryGetValue(cardItemId)
        if ok then
            table.insert(expCardInfos, {
                itemId = cardItemId,
                expGain = expItemData.expGain,
                inventory = Utils.getItemCount(cardItemId, true),
            })
        end
    end
    table.sort(expCardInfos, function(a, b)
        return a.expGain < b.expGain
    end)
    return expCardInfos
end

PhaseForesightCharGrowth._BuildExpCardListResult = HL.Method(HL.Number, HL.Table).Return(HL.Opt(HL.Table, HL.Table)) << function(self, expNeed, expCardInfos)
    if #expCardInfos == 0 then
        return nil, nil
    end
    local lowest = expCardInfos[1]
    local ownedExp = 0
    for _, info in ipairs(expCardInfos) do
        ownedExp = ownedExp + (info.inventory or 0) * (info.expGain or 0)
    end
    local ownedConverted = (lowest.expGain or 0) > 0 and math.floor(ownedExp / lowest.expGain) or 0
    if expNeed <= 0 then
        local zeroRawList = {}
        for _, info in ipairs(expCardInfos) do
            table.insert(zeroRawList, { itemId = info.itemId, count = 0 })
        end
        return zeroRawList, { { itemId = lowest.itemId, count = 0, ownedCount = ownedConverted } }
    end
    local expDeficit = expNeed
    local cardCount = #expCardInfos
    local expRawMap = {}
    for i = 1, cardCount do
        local info = expCardInfos[i]
        if expDeficit <= 0 then
            expRawMap[info.itemId] = 0
        elseif i < cardCount then
            local needCount = math.ceil(expDeficit / info.expGain)
            local useCount = math.min(needCount, info.inventory)
            expRawMap[info.itemId] = useCount
            expDeficit = expDeficit - useCount * info.expGain
        else
            expRawMap[info.itemId] = math.ceil(expDeficit / info.expGain)
            expDeficit = 0
        end
    end
    local expRawList = {}
    for _, info in ipairs(expCardInfos) do
        table.insert(expRawList, { itemId = info.itemId, count = expRawMap[info.itemId] or 0 })
    end
    local expConvertedList = {
        { itemId = lowest.itemId, count = math.ceil(expNeed / lowest.expGain), ownedCount = ownedConverted },
    }
    return expRawList, expConvertedList
end

PhaseForesightCharGrowth._AppendExpCardListResult = HL.Method(
    HL.Any, HL.Any, HL.Number, HL.Table
).Return(HL.Any, HL.Any) << function(self, expRawList, expConvertedList, expNeed, expCardInfos)
    local stageRawList, stageConvertedList = self:_BuildExpCardListResult(expNeed, expCardInfos)
    if not stageRawList then
        return expRawList, expConvertedList
    end
    if not expRawList then
        expRawList = {}
    end
    for _, entry in ipairs(stageRawList) do
        table.insert(expRawList, entry)
    end
    if not expConvertedList then
        expConvertedList = {}
    end
    for _, entry in ipairs(stageConvertedList) do
        table.insert(expConvertedList, entry)
    end
    return expRawList, expConvertedList
end



PhaseForesightCharGrowth._IsGatherMaterial = HL.Method(HL.Any).Return(HL.Boolean) << function(self, itemCfg)
    if not itemCfg or not itemCfg.obtainWayIds then
        return false
    end
    local function matchWay(wayId)
        local s = tostring(wayId or "")
        return string.find(s, "gather", 1, true) ~= nil
            or string.find(s, "spaceship_plant", 1, true) ~= nil
    end
    if itemCfg.obtainWayIds.Count then
        for i = 0, itemCfg.obtainWayIds.Count - 1 do
            if matchWay(itemCfg.obtainWayIds[i]) then
                return true
            end
        end
        return false
    end
    for _, wayId in pairs(itemCfg.obtainWayIds) do
        if matchWay(wayId) then
            return true
        end
    end
    return false
end

PhaseForesightCharGrowth._ClassifyItemCategory = HL.Method(HL.String, HL.String, HL.Any).Return(HL.Opt(HL.String)) << function(self, line, itemId, itemCfg)
    local goldItemId = UIConst.INVENTORY_MONEY_IDS[1]
    if not itemId or itemId == goldItemId then
        return "Gold"
    end
    if not itemCfg then
        return nil
    end
    local itemType = itemCfg.type
    if itemType == GEnums.ItemType.CardExp or itemType == GEnums.ItemType.WpnExpItem then
        return "Exp"
    end
    if itemType == GEnums.ItemType.WpnBreakMat then
        return line == "weapon" and "Nurture" or nil
    end
    if itemType == GEnums.ItemType.spCrown then
        return line == "skill" and "PreciousItem" or nil
    end
    if itemType == GEnums.ItemType.spMaterial then
        return "Precious"
    end
    if itemType == GEnums.ItemType.CharGradeUp then
        if string.find(itemId, "break_stage", 1, true) then
            return line == "upgrade" and "Nurture" or nil
        end
        if string.find(itemId, "skill_level", 1, true) then
            return line == "skill" and "Nurture" or nil
        end
        return (line == "upgrade" or line == "skill") and "Nurture" or nil
    end
    if itemType == GEnums.ItemType.Material then
        return self:_IsGatherMaterial(itemCfg) and "Collect" or "Precious"
    end
    return nil
end


local FORESIGHT_STAGE_MAT_COLS = {
    upgrade = {
        { "Gold", "upGoldIds", "upGoldCnt" },
        { "Exp", "upExpIds", "upExpCnt" },
        { "Nurture", "upAdvIds", "upAdvCnt" },
        { "Collect", "upColIds", "upColCnt" },
        { "Precious", "upPreIds", "upPreCnt" },
    },
    skill = {
        { "Gold", "skGoldIds", "skGoldCnt" },
        { "Nurture", "skNurIds", "skNurCnt" },
        { "Collect", "skColIds", "skColCnt" },
        { "Precious", "skPreMatIds", "skPreMatCnt" },
        { "PreciousItem", "skPreItmIds", "skPreItmCnt" },
    },
    weapon = {
        { "Gold", "upGoldIds", "upGoldCnt" },
        { "Exp", "upExpIds", "upExpCnt" },
        { "Nurture", "upBrkIds", "upBrkCnt" },
        { "Collect", "upColIds", "upColCnt" },
        { "Precious", "upPreIds", "upPreCnt" },
    },
}
PhaseForesightCharGrowth._GetForesightStageMaterialResult = HL.Method(HL.Number, HL.Number, HL.Any, HL.String).Return(HL.Table) << function(self, stageId, targetLevel, stageMaterials, mode)
    local result = { stageId = stageId, targetLevel = targetLevel or 0, hasPendingNeed = false }
    if not stageMaterials then
        return result
    end
    local ok, mats = stageMaterials:TryGetValue(stageId)
    if not ok then
        return result
    end
    for _, col in ipairs(FORESIGHT_STAGE_MAT_COLS[mode]) do
        local ids, cnts = mats[col[2]], mats[col[3]]
        local list = {}
        if ids and cnts and ids.Count and cnts.Count then
            for i = 0, math.min(ids.Count, cnts.Count) - 1 do
                local itemId, count = ids[i], cnts[i] or 0
                if not string.isEmpty(itemId) and (count > 0 or not Tables.itemTable:ContainsKey(itemId)) then
                    list[#list + 1] = { itemId = itemId, count = count }
                end
            end
        end
        if #list > 0 then
            if col[1] == "Exp" then
                local expRawList, expConvertedList
                local weaponExpCardInfos
                for i = 1, #list do
                    local entry = list[i]
                    local expGain = 0
                    local expCardInfos
                    if mode == "weapon" then
                        if not weaponExpCardInfos then
                            weaponExpCardInfos = {}
                            for wi = 1, Tables.characterConst.weaponExpItem.Count do
                                local cardItemId = Tables.characterConst.weaponExpItem[CSIndex(wi)]
                                local okItem, itemCfg = Tables.itemTable:TryGetValue(cardItemId)
                                if okItem then
                                    local okRarity, rarityCfg = Tables.weaponExpItemTable:TryGetValue(itemCfg.rarity)
                                    if okRarity and rarityCfg.itemExp > 0 then
                                        table.insert(weaponExpCardInfos, {
                                            itemId = cardItemId,
                                            expGain = rarityCfg.itemExp,
                                            inventory = Utils.getItemCount(cardItemId, true),
                                        })
                                    end
                                end
                            end
                            table.sort(weaponExpCardInfos, function(a, b)
                                return a.expGain < b.expGain
                            end)
                        end
                        expCardInfos = weaponExpCardInfos
                        local okItem, itemCfg = Tables.itemTable:TryGetValue(entry.itemId)
                        if okItem then
                            local okRarity, rarityCfg = Tables.weaponExpItemTable:TryGetValue(itemCfg.rarity)
                            if okRarity then
                                expGain = rarityCfg.itemExp
                            end
                        end
                    else
                        local breakStage = 0
                        if i > 1 then
                            breakStage = 3
                        end
                        expCardInfos = self:_CollectCharExpCardInfos(Tables.charBreakTable[breakStage])
                        local okExp, expItemData = Tables.expItemDataMap:TryGetValue(entry.itemId)
                        if okExp then
                            expGain = expItemData.expGain
                        end
                    end
                    local expNeed = 0
                    if expGain > 0 then
                        expNeed = entry.count * expGain
                    end
                    expRawList, expConvertedList = self:_AppendExpCardListResult(
                        expRawList, expConvertedList, expNeed, expCardInfos)
                end
                if expConvertedList then
                    for i = 1, #list do
                        local algo = expConvertedList[i]
                        if algo then
                            list[i].ownedCount = algo.ownedCount
                        end
                    end
                end
                result.Exp = { rawList = expRawList or list, convertedList = list }
            else
                result[col[1]] = list
            end
            result.hasPendingNeed = true
        end
    end
    return result
end

PhaseForesightCharGrowth._FinalizeGrowthResult = HL.Method(
    HL.Number, HL.Number, HL.String, HL.Any, HL.Any, HL.Any
).Return(HL.Table) << function(self, stageId, targetLevel, line, itemCountMap, expRawList, expConvertedList)
    local result = {
        targetLevel = targetLevel,
        stageId = stageId,
        hasPendingNeed = false,
    }
    if itemCountMap then
        for itemId, count in pairs(itemCountMap) do
            local ok, itemCfg = Tables.itemTable:TryGetValue(itemId)
            local category = self:_ClassifyItemCategory(line, itemId, ok and itemCfg or nil)
            if category and category ~= "Exp" then
                result[category] = result[category] or {}
                table.insert(result[category], { itemId = itemId, count = count })
            end
            if count > 0 then
                result.hasPendingNeed = true
            end
        end
    end
    if expRawList or expConvertedList then
        result.Exp = { rawList = expRawList, convertedList = expConvertedList }
        if not result.hasPendingNeed then
            for _, entry in ipairs(expRawList or {}) do
                if entry.count > 0 then
                    result.hasPendingNeed = true
                    break
                end
            end
        end
        if not result.hasPendingNeed then
            for _, entry in ipairs(expConvertedList or {}) do
                if entry.count > 0 then
                    result.hasPendingNeed = true
                    break
                end
            end
        end
    end
    return result
end

PhaseForesightCharGrowth._ResolveGrowthStage = HL.Method(HL.String, HL.Number).Return(HL.Opt(HL.String, HL.Any, HL.Any, HL.Number)) << function(self, charId, stageId)
    charId = CSCharUtils.GetVirtualCharTemplateId(charId)
    local growthData = CharInfoUtils.getCharGrowthData(charId)

    local ok, stageCfg = Tables.foresightGrowthStageTable:TryGetValue(stageId)
    if not ok then
        return charId, growthData, nil, 0
    end

    local levelCap = stageCfg.level
    if levelCap <= 0 then
        return charId, growthData, stageCfg, 0
    end

    local maxLevel = Tables.characterConst.maxLevel
    if levelCap > maxLevel then
        levelCap = maxLevel
    end

    return charId, growthData, stageCfg, levelCap
end





local s_operatorCategoryKeys = nil
local s_itemOrderByCategory = nil

local PRECIOUS_SKILLSP_CHEST_ITEM_ID = "item_case_bp_selfselect_skillsp_1"

PhaseForesightCharGrowth._EnsureOperatorDisplayConfig = HL.Method() << function(self)
    if s_operatorCategoryKeys then
        return
    end
    local operatorRowKeys = {
        Gold = true,
        Exp = true,
        Nurture = true,
        Collect = true,
        Precious = true,
        PreciousItem = true,
    }
    local rows = {}
    s_itemOrderByCategory = {}
    for key, cfg in pairs(Tables.foresightGrowthConfigTable) do
        if operatorRowKeys[key] and cfg then
            table.insert(rows, { key = key, sortValue = cfg.value or 0 })
            local orderMap = {}
            local stringList = cfg.stringList
            if stringList then
                if stringList.Count then
                    for i = 0, stringList.Count - 1 do
                        orderMap[stringList[i]] = i + 1
                    end
                else
                    for i, itemId in ipairs(stringList) do
                        orderMap[itemId] = i
                    end
                end
            end
            s_itemOrderByCategory[key] = orderMap
        end
    end
    table.sort(rows, function(a, b)
        if a.sortValue ~= b.sortValue then
            return a.sortValue < b.sortValue
        end
        return a.key < b.key
    end)
    s_operatorCategoryKeys = {}
    for _, row in ipairs(rows) do
        table.insert(s_operatorCategoryKeys, row.key)
    end
end

PhaseForesightCharGrowth._SortDisplayItems = HL.Method(HL.String, HL.Table).Return(HL.Table) << function(self, categoryKey, itemList)
    if not itemList or #itemList == 0 then
        return itemList
    end
    self:_EnsureOperatorDisplayConfig()
    local orderMap = s_itemOrderByCategory[categoryKey]
    if not orderMap or not next(orderMap) then
        return itemList
    end
    table.sort(itemList, function(a, b)
        local oa = orderMap[a.itemId] or 99999
        local ob = orderMap[b.itemId] or 99999
        if oa ~= ob then
            return oa < ob
        end
        return (a.itemId or "") < (b.itemId or "")
    end)
    return itemList
end

PhaseForesightCharGrowth._PreciousCategoryHasSpMaterial = HL.Method(HL.Table).Return(HL.Boolean) << function(self, itemList)
    for _, entry in ipairs(itemList or {}) do
        if not string.isEmpty(entry.itemId) then
            local ok, itemCfg = Tables.itemTable:TryGetValue(entry.itemId)
            if ok and itemCfg.type == GEnums.ItemType.spMaterial then
                return true
            end
        end
    end
    return false
end

PhaseForesightCharGrowth._PrepareOperatorCategoryData = HL.Method(HL.String, HL.Any).Return(HL.Any) << function(self, categoryKey, data)
    if not data then
        return nil
    end
    local function categoryHasPendingNeed(itemList)
        for _, entry in ipairs(itemList or {}) do
            if entry.count > 0 or (not string.isEmpty(entry.itemId) and not Tables.itemTable:ContainsKey(entry.itemId)) then
                return true
            end
        end
        return false
    end
    if categoryKey == "Exp" then
        local prepared = {
            rawList = self:_SortDisplayItems("Exp", data.rawList),
            convertedList = self:_SortDisplayItems("Exp", data.convertedList),
        }
        if #prepared.rawList == 0 and #prepared.convertedList == 0 then
            return nil
        end
        if not categoryHasPendingNeed(prepared.rawList) and not categoryHasPendingNeed(prepared.convertedList) then
            return nil
        end
        return prepared
    end
    local list = self:_SortDisplayItems(categoryKey, data)
    if #list == 0 then
        return nil
    end
    if not categoryHasPendingNeed(list) then
        return nil
    end
    if categoryKey == "Precious" and self:_PreciousCategoryHasSpMaterial(list) then
        return {
            materials = list,
            chestItemId = PRECIOUS_SKILLSP_CHEST_ITEM_ID,
        }
    end
    return list
end

PhaseForesightCharGrowth._CategoryHasShortage = HL.Method(HL.Any, HL.Boolean, HL.Boolean).Return(HL.Boolean)
    << function(self, data, isExp, showConverted)
    local list
    if isExp then
        list = showConverted and data.convertedList or data.rawList
    elseif data.materials then
        list = data.materials
    else
        list = data
    end
    for _, entry in ipairs(list or {}) do
        if entry.count > 0 then
            local owned = entry.ownedCount
            if owned == nil then
                owned = Utils.getItemCount(entry.itemId, true)
            end
            if owned < entry.count then
                return true
            end
        end
    end
    return false
end


PhaseForesightCharGrowth.IsOperatorGoalReached = HL.Method(HL.Table).Return(HL.Boolean) << function(self, growthData)
    if not growthData then
        return false
    end
    return not growthData.hasPendingNeed
end

PhaseForesightCharGrowth.IsCurCultivateStageMax = HL.Method(HL.String, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, templateId, stageList)
    if string.isEmpty(templateId) then
        return false
    end
    local curStageId = self:GetCharCultivateStageId(templateId)
    stageList = stageList or self:GetCultivateStageIdList()
    if not stageList or #stageList == 0 then
        return false
    end
    return curStageId >= stageList[#stageList].stageId
end


PhaseForesightCharGrowth.IsGrowthTabCultivateGoalReached = HL.Method(HL.String, HL.String, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, templateId, tabKey, stageList)
    if string.isEmpty(templateId) or string.isEmpty(tabKey) then
        return false
    end
    if tabKey == "matrix" then
        return false
    end
    stageList = stageList or self:GetCultivateStageIdList()
    if not stageList or #stageList == 0 then
        return false
    end
    local stageId = stageList[#stageList].stageId
    if tabKey == "operator" then
        return self:IsOperatorGoalReached(self:GetLevelGrowthItemListData(templateId, stageId, stageList))
    elseif tabKey == "skill" then
        return self:IsOperatorGoalReached(self:GetSkillGrowthItemListData(templateId, stageId, stageList))
    elseif tabKey ~= "weapon" then
        return true
    end
    for _, section in ipairs(self:_BuildWeaponGrowthSections(templateId, stageId, stageList, true)) do
        if not section.isGoalReached then
            return false
        end
    end
    return true
end


PhaseForesightCharGrowth.GetMatrixTabGoalButtonState = HL.Method(HL.String).Return(HL.String) << function(self, templateId)
    local GROWTH_TAB_GOAL_STATE_MAX = "Max"
    local GROWTH_TAB_GOAL_STATE_IN_MAX = "InMax"
    local GROWTH_TAB_GOAL_STATE_UN_COM = "unCom"
    if string.isEmpty(templateId) then
        return GROWTH_TAB_GOAL_STATE_UN_COM
    end
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    local isCharOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    if not isCharOwned or not playerChar.instId or playerChar.instId <= 0 then
        return GROWTH_TAB_GOAL_STATE_UN_COM
    end
    local weaponInfo = CharInfoUtils.getCharCurWeapon(playerChar.instId)
    local weaponInstId = weaponInfo and weaponInfo.weaponInstId or 0
    if weaponInstId <= 0 then
        return GROWTH_TAB_GOAL_STATE_UN_COM
    end
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    if not weaponInst then
        return GROWTH_TAB_GOAL_STATE_UN_COM
    end
    local gemInstId = weaponInst.attachedGemInstId or 0
    local tryGemInstId = gemInstId > 0 and gemInstId or nil
    local _, skillList = CS.Beyond.Gameplay.WeaponUtil.TryGetWeaponSkillIdAndLevel(
        Utils.getCurrentScope(), weaponInstId, tryGemInstId, weaponInst.breakthroughLv, weaponInst.refineLv)
    if not skillList or skillList.Count < 3 then
        return GROWTH_TAB_GOAL_STATE_UN_COM
    end
    local lv1 = skillList[0].level or 0
    local lv2 = skillList[1].level or 0
    local lv3 = skillList[2].level or 0
    if lv1 >= 9 and lv2 >= 9 and lv3 >= 9 then
        return GROWTH_TAB_GOAL_STATE_MAX
    end
    if lv1 >= 9 and lv2 >= 9 and lv3 >= 4 then
        return GROWTH_TAB_GOAL_STATE_IN_MAX
    end
    return GROWTH_TAB_GOAL_STATE_UN_COM
end


PhaseForesightCharGrowth.GetGrowthTabGoalButtonState = HL.Method(HL.String, HL.String, HL.Opt(HL.Table)).Return(HL.String) << function(self, templateId, tabKey, stageList)
    local GROWTH_TAB_GOAL_STATE_MAX = "Max"
    local GROWTH_TAB_GOAL_STATE_IN_MAX = "InMax"
    if tabKey == "matrix" then
        return self:GetMatrixTabGoalButtonState(templateId)
    end
    if self:IsGrowthTabCultivateGoalReached(templateId, tabKey, stageList) then
        return GROWTH_TAB_GOAL_STATE_MAX
    end
    return GROWTH_TAB_GOAL_STATE_IN_MAX
end

PhaseForesightCharGrowth._ResolveGrowthCategoryDisplayName = HL.Method(HL.String, HL.Any, HL.String).Return(HL.String) << function(self, categoryKey, cfg, tabKey)
    if tabKey == "skill" and categoryKey == "Nurture" then
        return Language.LUA_FORESIGHT_GROWTH_ROW_SKILL_NURTURE
    end
    if tabKey == "weapon" then
        if categoryKey == "Exp" then
            return Language.LUA_FORESIGHT_GROWTH_ROW_WEAPON_EXP
        elseif categoryKey == "Nurture" then
            return Language.LUA_FORESIGHT_GROWTH_ROW_WEAPON_NURTURE
        elseif categoryKey == "Collect" then
            return Language.LUA_FORESIGHT_GROWTH_ROW_WEAPON_COLLECT
        end
    end
    return cfg and cfg.name or ""
end

PhaseForesightCharGrowth.GetOperatorGrowthDisplayRows = HL.Method(HL.Table, HL.Boolean, HL.String).Return(HL.Table) << function(self, growthData, showConverted, tabKey)
    if not growthData or not growthData.hasPendingNeed then
        return {}
    end
    self:_EnsureOperatorDisplayConfig()
    showConverted = showConverted ~= false
    local rows = {}
    for _, key in ipairs(s_operatorCategoryKeys) do
        local data = self:_PrepareOperatorCategoryData(key, growthData[key])
        if data then
            local cfg = Tables.foresightGrowthConfigTable[key]
            table.insert(rows, {
                key = key,
                name = self:_ResolveGrowthCategoryDisplayName(key, cfg, tabKey),
                data = data,
                canGet = self:_CategoryHasShortage(data, key == "Exp", showConverted),
                targetLevel = key == "Exp" and growthData.targetLevel,
            })
        end
    end
    return rows
end

PhaseForesightCharGrowth.FindCharGachaPoolId = HL.Method(HL.String).Return(HL.String) << function(self, templateId)
    if string.isEmpty(templateId) then
        return ""
    end
    local poolInfos = GameInstance.player.gacha.poolInfos
    if not poolInfos then
        return ""
    end
    for poolId, csInfo in pairs(poolInfos) do
        if csInfo.isChar and csInfo.isOpenValid then
            local ok, poolCfg = Tables.gachaCharPoolTable:TryGetValue(poolId)
            if ok and poolCfg.upCharIds then
                for i = 0, poolCfg.upCharIds.Count - 1 do
                    if poolCfg.upCharIds[i] == templateId then
                        return poolId
                    end
                end
            end
        end
    end
    return ""
end

local LOW_QUALITY_WEAPON_RARITY = 4

PhaseForesightCharGrowth._AppendRecommendWeaponIds = HL.Method(HL.Table, HL.Any) << function(self, outList, idList)
    if not outList or not idList then
        return
    end
    if idList.Count then
        for i = 0, idList.Count - 1 do
            local weaponId = idList[i]
            if not string.isEmpty(weaponId) then
                table.insert(outList, weaponId)
            end
        end
        return
    end
    for _, weaponId in pairs(idList) do
        if not string.isEmpty(weaponId) then
            table.insert(outList, weaponId)
        end
    end
end

PhaseForesightCharGrowth.GetRecommendWeaponIdList = HL.Method(HL.String).Return(HL.Table) << function(self, charId)
    local weaponIds = {}
    if string.isEmpty(charId) then
        return weaponIds
    end
    if self:IsForesightCharId(charId) then
        local okForesight, foresightCfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
        if okForesight then
            self:_AppendRecommendWeaponIds(weaponIds, foresightCfg.weaponIds)
        end
        return weaponIds
    end
    local ok, cfg = Tables.CharWpnRecommendTable:TryGetValue(charId)
    if ok then
        self:_AppendRecommendWeaponIds(weaponIds, cfg.weaponIds1)
        self:_AppendRecommendWeaponIds(weaponIds, cfg.weaponIds2)
        self:_AppendRecommendWeaponIds(weaponIds, cfg.weaponIds3)
    end
    return weaponIds
end

PhaseForesightCharGrowth.GetPrimaryRecommendWeaponId = HL.Method(HL.String).Return(HL.String) << function(self, charId)
    local weaponIds = self:GetRecommendWeaponIdList(charId)
    return weaponIds[1] or ""
end



PhaseForesightCharGrowth.GetCharRecommendWeaponEntries = HL.Method(HL.String).Return(HL.Table)
    << function(self, charId)
    local entries = {}
    if string.isEmpty(charId) then
        return entries
    end
    local function appendGroup(groupIndex, idList)
        if not idList then
            return
        end
        local weaponIds = {}
        self:_AppendRecommendWeaponIds(weaponIds, idList)
        for _, weaponId in ipairs(weaponIds) do
            table.insert(entries, { weaponId = weaponId, groupIndex = groupIndex })
        end
    end
    if self:IsForesightCharId(charId) then
        local okForesight, foresightCfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
        if okForesight then
            appendGroup(1, foresightCfg.weaponIds)
        end
        return entries
    end
    local ok, cfg = Tables.CharWpnRecommendTable:TryGetValue(charId)
    if not ok then
        return entries
    end
    appendGroup(1, cfg.weaponIds1)
    appendGroup(2, cfg.weaponIds2)
    appendGroup(3, cfg.weaponIds3)
    return entries
end

PhaseForesightCharGrowth.GetTierOneRecommendWeaponIds = HL.Method(HL.String, HL.Opt(HL.Number)).Return(HL.Table)
    << function(self, charId, maxCount)
    maxCount = maxCount or 2
    local weaponIds = {}
    if string.isEmpty(charId) or maxCount <= 0 then
        return weaponIds
    end
    local tierOneIds = {}
    if self:IsForesightCharId(charId) then
        local okForesight, foresightCfg = Tables.foresightCharGrowthTable:TryGetValue(charId)
        if okForesight then
            self:_AppendRecommendWeaponIds(tierOneIds, foresightCfg.weaponIds)
        end
    else
        local ok, cfg = Tables.foresightCharWpnRecommendTable:TryGetValue(charId)
        if ok then
            self:_AppendRecommendWeaponIds(tierOneIds, cfg.weaponIds)
        end
    end
    for i = 1, math.min(maxCount, #tierOneIds) do
        table.insert(weaponIds, tierOneIds[i])
    end
    return weaponIds
end

PhaseForesightCharGrowth.IsWeaponInRecommendList = HL.Method(HL.String, HL.String).Return(HL.Boolean)
    << function(self, charId, weaponId)
    if string.isEmpty(charId) or string.isEmpty(weaponId) then
        return false
    end
    for _, recommendId in ipairs(self:GetRecommendWeaponIdList(charId)) do
        if recommendId == weaponId then
            return true
        end
    end
    return false
end


PhaseForesightCharGrowth.GetBestOwnedWeaponInstInfo = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Number, HL.Boolean, HL.Number, HL.Number) << function(self, weaponId, weaponInstDict)
    if string.isEmpty(weaponId) then
        return 1, false, 0, 0
    end
    local curLevel, curRefineLv = 1, 0
    local bestInstId = 0
    local foundOwned = false
    local hasInst = weaponInstDict ~= nil
    if not hasInst then hasInst, weaponInstDict = GameInstance.player.inventory:TryGetAllWeaponInstItems(Utils.getCurrentScope()) end
    if not hasInst then return curLevel, foundOwned, curRefineLv, bestInstId end
    for instId, itemBundle in pairs(weaponInstDict) do
        local inst = itemBundle.instData
        if inst.templateId == weaponId then
            local refineLv = inst.refineLv or 0
            if not foundOwned or inst.weaponLv > curLevel
                or (inst.weaponLv == curLevel and refineLv > curRefineLv) then
                curLevel = inst.weaponLv
                curRefineLv = refineLv
                bestInstId = instId
                foundOwned = true
            end
        end
    end
    return curLevel, foundOwned, curRefineLv, bestInstId
end

PhaseForesightCharGrowth.FindWeaponGachaPoolId = HL.Method(HL.String).Return(HL.String) << function(self, weaponId)
    for poolId, csInfo in pairs(GameInstance.player.gacha.poolInfos) do
        if not csInfo.isChar and csInfo.isOpenValid then
            local ok, poolCfg = Tables.gachaWeaponPoolTable:TryGetValue(poolId)
            if ok and poolCfg.upWeaponIds then
                for i = 0, poolCfg.upWeaponIds.Count - 1 do
                    if poolCfg.upWeaponIds[i] == weaponId then
                        return poolId
                    end
                end
            end
        end
    end
    return ""
end


PhaseForesightCharGrowth.JumpToWeaponObtainSource = HL.Method(HL.String).Return(HL.Boolean) << function(self, weaponId)
    if string.isEmpty(weaponId) then
        return false
    end
    if PhaseManager:IsPhaseForbidden(PhaseId.CashShop) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SYSTEM_FORBIDDEN)
        return false
    end
    local poolId = self:FindWeaponGachaPoolId(weaponId)
    if not string.isEmpty(poolId) then
        local _, upBox = GameInstance.player.shopSystem:GetNowUpWeaponData()
        if upBox then
            for i = 0, upBox.Count - 1 do
                local boxData = upBox[i]
                local goodsCfg = Tables.shopGoodsTable[boxData.goodsTemplateId]
                if goodsCfg and goodsCfg.weaponGachaPoolId == poolId then
                    PhaseManager:GoToPhase(PhaseId.CashShop, {
                        shopGroupId = CashShopConst.CashShopCategoryType.Weapon,
                        goodsId = boxData.goodsId,
                    })
                    return true
                end
            end
        end
    end
    local _, jumpFunc = CashShopUtils.TryGetWeaponByWeaponId(weaponId)
    if jumpFunc then
        jumpFunc()
        return true
    end
    return false
end

PhaseForesightCharGrowth.IsWeaponLowQuality = HL.Method(HL.String).Return(HL.Boolean) << function(self, weaponId)
    if string.isEmpty(weaponId) then
        return false
    end
    local ok, itemCfg = Tables.itemTable:TryGetValue(weaponId)
    return ok and itemCfg.rarity and itemCfg.rarity <= LOW_QUALITY_WEAPON_RARITY
end

local function buildWeaponGrowthHeaderBundle(
    self, templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId, stageList, weaponInstDict, growthOnly)
    equippedWeaponId = equippedWeaponId or self:_ResolveCharWeaponTemplateId(templateId)
    displayWeaponId = displayWeaponId or ""

    local displayWeaponLevel, isDisplayWeaponOwned, displayWeaponRefineLv, displayWeaponInstId = 1, false, 0, 0
    local useEquippedInst = isCharOwned and not string.isEmpty(displayWeaponId) and displayWeaponId == equippedWeaponId
    if useEquippedInst then
        local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
        local weaponInfo = playerChar and playerChar.instId and playerChar.instId > 0
            and CharInfoUtils.getCharCurWeapon(playerChar.instId)
        if weaponInfo and weaponInfo.weaponInst then
            displayWeaponLevel = weaponInfo.weaponInst.weaponLv or 1
            displayWeaponRefineLv = weaponInfo.weaponInst.refineLv or 0
            displayWeaponInstId = weaponInfo.weaponInstId or 0
            isDisplayWeaponOwned = true
        end
    end
    if not isDisplayWeaponOwned then
        displayWeaponLevel, isDisplayWeaponOwned, displayWeaponRefineLv, displayWeaponInstId =
            self:GetBestOwnedWeaponInstInfo(displayWeaponId, weaponInstDict)
    end

    local growthData
    if not string.isEmpty(displayWeaponId) then
        growthData = self:GetWeaponGrowthListData(displayWeaponId, stageId, displayWeaponInstId, stageList, weaponInstDict)
    else
        growthData = { stageId = stageId, targetLevel = 0 }
    end
    if growthOnly then
        return nil, growthData
    end

    local primaryRecommendWeaponId = self:GetPrimaryRecommendWeaponId(templateId)
    local isDisplayWeaponInGachaPool = not string.isEmpty(self:FindWeaponGachaPoolId(displayWeaponId))
    local isDisplayWeaponInShop = (CashShopUtils.TryGetWeaponByWeaponId(displayWeaponId) == true)
    return {
        displayWeaponId = displayWeaponId,
        equippedWeaponId = equippedWeaponId,
        primaryRecommendWeaponId = primaryRecommendWeaponId,
        isForesightWeapon = Tables.foresightWeaponTable:ContainsKey(displayWeaponId),
        displayWeaponLevel = displayWeaponLevel,
        isDisplayWeaponOwned = isDisplayWeaponOwned,
        isDisplayWeaponInGachaPool = isDisplayWeaponInGachaPool,
        isDisplayWeaponInShop = isDisplayWeaponInShop,
        isDisplayWeaponObtainable = not isDisplayWeaponOwned
            and (isDisplayWeaponInGachaPool or isDisplayWeaponInShop),
        growthLabelState = isDisplayWeaponOwned and "Owned" or "NotOwn",
        displayWeaponRefineLv = displayWeaponRefineLv,
        displayWeaponInstId = displayWeaponInstId,
        isEquippedRecommended = not string.isEmpty(equippedWeaponId)
            and self:IsWeaponInRecommendList(templateId, equippedWeaponId),
        isEquippedLowQuality = not string.isEmpty(equippedWeaponId)
            and self:IsWeaponLowQuality(equippedWeaponId),
        targetLevel = growthData and growthData.targetLevel or 0,
        isGoalReached = self:IsOperatorGoalReached(growthData),
        isCurStageMax = self:IsCurCultivateStageMax(templateId, stageList),
    }, growthData
end

PhaseForesightCharGrowth.BuildWeaponGrowthHeaderBundle = HL.Method(HL.String, HL.Number, HL.String, HL.Boolean, HL.Opt(HL.String)).Return(HL.Table) << function(self, templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId)
    return (buildWeaponGrowthHeaderBundle(self, templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId))
end

PhaseForesightCharGrowth.GetWeaponGrowthHeaderBundle = HL.Method(HL.String, HL.Number).Return(HL.Table)
    << function(self, templateId, stageId)
    local equippedWeaponId = self:_ResolveCharWeaponTemplateId(templateId)
    local primaryRecommendWeaponId = self:GetPrimaryRecommendWeaponId(templateId)
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    local isCharOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)

    local displayWeaponId = isCharOwned and not string.isEmpty(equippedWeaponId)
        and equippedWeaponId or primaryRecommendWeaponId

    return self:BuildWeaponGrowthHeaderBundle(
        templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId)
end

PhaseForesightCharGrowth._BuildWeaponGrowthSections = HL.Method(HL.String, HL.Number, HL.Opt(HL.Table, HL.Boolean)).Return(HL.Table) << function(self, templateId, stageId, stageList, growthOnly)
    stageList = stageList or self:GetCultivateStageIdList()
    local equippedWeaponId = self:_ResolveCharWeaponTemplateId(templateId)
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    local isCharOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    local displayWeaponIds = isCharOwned
        and { not string.isEmpty(equippedWeaponId) and equippedWeaponId or self:GetPrimaryRecommendWeaponId(templateId) }
        or self:GetTierOneRecommendWeaponIds(templateId, 2)
    local weaponInstDict
    if #displayWeaponIds > 1 then
        local hasInst
        hasInst, weaponInstDict = GameInstance.player.inventory:TryGetAllWeaponInstItems(Utils.getCurrentScope())
        weaponInstDict = hasInst and weaponInstDict or {}
    end
    local sections = {}
    for _, displayWeaponId in ipairs(displayWeaponIds) do
        local headerBundle, growthData = buildWeaponGrowthHeaderBundle(
            self, templateId, stageId, displayWeaponId, isCharOwned,
            equippedWeaponId, stageList, weaponInstDict, growthOnly)
        table.insert(sections, {
            headerBundle = headerBundle,
            growthData = growthData,
            isGoalReached = self:IsOperatorGoalReached(growthData),
        })
    end
    return sections
end


PhaseForesightCharGrowth._ResolveCharWeaponTemplateId = HL.Method(HL.String).Return(HL.String) << function(self, templateId)
    if string.isEmpty(templateId) then
        return ""
    end
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    if not playerChar or not playerChar.instId or playerChar.instId <= 0 then
        return ""
    end
    local weaponInfo = CharInfoUtils.getCharCurWeapon(playerChar.instId)
    if not weaponInfo or string.isEmpty(weaponInfo.weaponTemplateId) then
        return ""
    end
    return weaponInfo.weaponTemplateId
end



local GEM_WISH_LIST_MAX = 200

local function collectWeaponGemWishListIds()
    local wishListIds = {}
    local wishList = GameInstance.player.inventory.weaponGemWishList
    for _, weaponId in pairs(wishList) do
        if not string.isEmpty(weaponId) then
            table.insert(wishListIds, weaponId)
        end
    end
    return wishListIds
end

PhaseForesightCharGrowth.GetWeaponGemWishListMax = HL.StaticMethod().Return(HL.Number) << function()
    return GEM_WISH_LIST_MAX
end

PhaseForesightCharGrowth.IsWeaponGemWishListFull = HL.StaticMethod().Return(HL.Boolean) << function()
    return GameInstance.player.inventory.weaponGemWishList.Count >= GEM_WISH_LIST_MAX
end

PhaseForesightCharGrowth.RequestAddWeaponToGemWishList = HL.StaticMethod(HL.String).Return(HL.Boolean, HL.Boolean)
    << function(weaponId)
    if string.isEmpty(weaponId) then
        return false, false
    end
    local t = GameInstance.player.inventory.weaponGemWishList
    if t:Contains(weaponId) then
        return true, false
    end
    if t.Count >= GEM_WISH_LIST_MAX then
        return false, true
    end
    local wishListIds = {}
    for _, v in pairs(t) do table.insert(wishListIds, v) end
    table.insert(wishListIds, weaponId)
    GameInstance.player.inventory:SetWeaponGemWishList(wishListIds)
    return true, false
end

PhaseForesightCharGrowth._BuildWeaponGemTagMap = HL.Method(HL.String).Return(HL.Table, HL.Boolean)
    << function(self, weaponId)
    local tagMap = {}
    if string.isEmpty(weaponId) then
        return tagMap, false
    end
    if Tables.foresightWeaponTable:ContainsKey(weaponId) then
        local okForesight, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        if not okForesight or not foresightCfg.gemTagIds then
            return tagMap, true
        end
        local hasUnknown = false
        for i = 0, foresightCfg.gemTagIds.Count - 1 do
            local termCfg = self:_FindGemTermCfgByTagId(foresightCfg.gemTagIds[i])
            if termCfg and not string.isEmpty(termCfg.tagId) then
                tagMap[termCfg.tagId] = true
            else
                hasUnknown = true
            end
        end
        return tagMap, hasUnknown
    end
    local hasCfg, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
    if not hasCfg or not weaponCfg.weaponSkillList then
        return tagMap, false
    end
    for _, skillId in pairs(weaponCfg.weaponSkillList) do
        local hasSkillCfg, skillCfg = Tables.skillPatchTable:TryGetValue(skillId)
        if hasSkillCfg and skillCfg.SkillPatchDataBundle and skillCfg.SkillPatchDataBundle.Count > 0 then
            local skillPatchData = skillCfg.SkillPatchDataBundle[0]
            if skillPatchData and not string.isEmpty(skillPatchData.tagId) then
                tagMap[skillPatchData.tagId] = true
            end
        end
    end
    return tagMap, false
end

PhaseForesightCharGrowth.HasWeaponUnknownGemTerms = HL.Method(HL.String).Return(HL.Boolean)
    << function(self, weaponId)
    if not Tables.foresightWeaponTable:ContainsKey(weaponId) then
        return false
    end
    local okForesight, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
    if not okForesight or not foresightCfg.gemTagIds then
        return true
    end
    for i = 0, foresightCfg.gemTagIds.Count - 1 do
        if not self:_FindGemTermCfgByTagId(foresightCfg.gemTagIds[i]) then
            return true
        end
    end
    return false
end

PhaseForesightCharGrowth._BuildSkillLevelByTagId = HL.Method(
    HL.String, HL.Opt(HL.Number, HL.Number, HL.Number, HL.Number)).Return(HL.Table) << function(self, weaponId, weaponInstId, tryGemInstId, breakthroughLv, refineLv)
    local tagIdToLevel = {}
    if string.isEmpty(weaponId) then
        return tagIdToLevel
    end
    local _, skillList
    if weaponInstId and weaponInstId > 0 then
        local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
        breakthroughLv = breakthroughLv or (weaponInst and weaponInst.breakthroughLv or 0)
        refineLv = refineLv or (weaponInst and weaponInst.refineLv or 0)
        _, skillList = CS.Beyond.Gameplay.WeaponUtil.TryGetWeaponSkillIdAndLevel(
            Utils.getCurrentScope(), weaponInstId, tryGemInstId, breakthroughLv, refineLv)
    else
        breakthroughLv = breakthroughLv or 0
        refineLv = refineLv or 0
        _, skillList = CS.Beyond.Gameplay.WeaponUtil.TryGetWeaponSkillIdAndLevel(
            weaponId, nil, breakthroughLv, refineLv)
    end
    if not skillList then
        return tagIdToLevel
    end
    for i = 0, skillList.Count - 1 do
        local levelInfo = skillList[i]
        local hasSkillCfg, skillCfg = Tables.skillPatchTable:TryGetValue(levelInfo.skillId)
        if hasSkillCfg and skillCfg.SkillPatchDataBundle and skillCfg.SkillPatchDataBundle.Count > 0 then
            local tagId = skillCfg.SkillPatchDataBundle[0].tagId
            if not string.isEmpty(tagId) then
                tagIdToLevel[tagId] = levelInfo
            end
        end
    end
    return tagIdToLevel
end

PhaseForesightCharGrowth._FindGemTermCfgByTagId = HL.Method(HL.String).Return(HL.Opt(HL.Userdata))
    << function(self, id)
    if string.isEmpty(id) then
        return nil
    end
    local ok, termCfg = Tables.gemTable:TryGetValue(id)
    if ok then
        return termCfg
    end
    for _, gemTermCfg in pairs(Tables.gemTable) do
        if gemTermCfg.tagId == id then
            return gemTermCfg
        end
    end
end

PhaseForesightCharGrowth.BuildAttachedGemTermEntries = HL.Method(HL.Number, HL.String).Return(HL.Table)
    << function(self, gemInstId, weaponId)
    local entries = {}
    if not gemInstId or gemInstId <= 0 then
        return entries
    end
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst then
        return entries
    end
    local weaponTagMap = {}
    if not string.isEmpty(weaponId) then
        weaponTagMap = self:_BuildWeaponGemTagMap(weaponId)
    end
    for i = 0, gemInst.termList.Count - 1 do
        local term = gemInst.termList[i]
        local _, termCfg = Tables.gemTable:TryGetValue(term.termId)
        if termCfg then
            local level = term.cost or 0
            local tagId = termCfg.tagId or ""
            table.insert(entries, {
                isUnknown = false,
                gemTermId = term.termId,
                tagId = tagId,
                tagName = termCfg.tagName or "",
                level = level,
                isWeaponTagMatch = not string.isEmpty(tagId) and weaponTagMap[tagId] == true,
            })
        end
    end
    return entries
end

PhaseForesightCharGrowth.BuildWeaponGemTermEntries = HL.Method(
    HL.String, HL.Opt(HL.Number, HL.Number, HL.Table)
).Return(HL.Table) << function(self, weaponId, weaponInstId, tryGemInstId, tagIdToLevelBase)
    local entries = {}
    if string.isEmpty(weaponId) then
        return entries
    end
    if Tables.foresightWeaponTable:ContainsKey(weaponId) and (not weaponInstId or weaponInstId <= 0) then
        local okForesight, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        if not okForesight or not foresightCfg.gemTagIds then
            return entries
        end
        for i = 0, foresightCfg.gemTagIds.Count - 1 do
            local id = foresightCfg.gemTagIds[i]
            local termCfg = self:_FindGemTermCfgByTagId(id)
            if termCfg then
                table.insert(entries, {
                    isUnknown = false,
                    gemTermId = termCfg.gemTermId or id,
                    tagName = termCfg.tagName or "",
                    level = 1,
                    baseLevel = 1,
                    gemBonusLevel = 0,
                    hasGemBonus = false,
                    maxLevel = 1,
                })
            else
                table.insert(entries, { isUnknown = true })
            end
        end
        return entries
    end

    local tagIdToLevel = self:_BuildSkillLevelByTagId(weaponId, weaponInstId, tryGemInstId)
    tagIdToLevelBase = tagIdToLevelBase
        or (tryGemInstId == nil and tagIdToLevel or self:_BuildSkillLevelByTagId(weaponId, weaponInstId, nil))
    local function resolveLevelFields(tagId)
        local withGemInfo = tagIdToLevel[tagId]
        local baseInfo = tagIdToLevelBase[tagId]
        local level = withGemInfo and withGemInfo.level or 0
        local baseLevel = baseInfo and baseInfo.level or 0
        local gemBonusLevel = math.max(0, level - baseLevel)
        return {
            level = level,
            baseLevel = baseLevel,
            gemBonusLevel = gemBonusLevel,
            hasGemBonus = gemBonusLevel > 0,
            maxLevel = withGemInfo and withGemInfo.maxLevel or (baseInfo and baseInfo.maxLevel or 0),
        }
    end

    local hasCfg, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
    if not hasCfg or not weaponCfg.weaponSkillList then
        return entries
    end
    for _, skillId in pairs(weaponCfg.weaponSkillList) do
        local hasSkillCfg, skillCfg = Tables.skillPatchTable:TryGetValue(skillId)
        if hasSkillCfg and skillCfg.SkillPatchDataBundle and skillCfg.SkillPatchDataBundle.Count > 0 then
            local tagId = skillCfg.SkillPatchDataBundle[0].tagId
            if not string.isEmpty(tagId) then
                local termCfg = self:_FindGemTermCfgByTagId(tagId)
                local levelFields = resolveLevelFields(tagId)
                table.insert(entries, {
                    isUnknown = false,
                    gemTermId = termCfg and termCfg.gemTermId or nil,
                    tagName = termCfg and termCfg.tagName or "",
                    level = levelFields.level,
                    baseLevel = levelFields.baseLevel,
                    gemBonusLevel = levelFields.gemBonusLevel,
                    hasGemBonus = levelFields.hasGemBonus,
                    maxLevel = levelFields.maxLevel,
                })
            end
        end
    end
    return entries
end

PhaseForesightCharGrowth._IsGemEnhanceAllMax = HL.Method(HL.Number).Return(HL.Boolean)
    << function(self, gemInstId)
    if not gemInstId or gemInstId <= 0 then
        return false
    end
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst or gemInst.termList.Count < 3 then
        return false
    end
    for i = 0, gemInst.termList.Count - 1 do
        local term = gemInst.termList[i]
        if not CharInfoUtils.isGemTermEnhanceMax(term.termId, term.cost) then
            return false
        end
    end
    return true
end

PhaseForesightCharGrowth._IsWeaponGemMaxDisplay = HL.Method(HL.Number, HL.Number).Return(HL.Boolean)
    << function(self, weaponInstId, gemInstId)
    if not weaponInstId or weaponInstId <= 0 or not gemInstId or gemInstId <= 0 then
        return false
    end
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not weaponInst or not gemInst then
        return false
    end
    local hasWeapon, weaponBundle = GameInstance.player.inventory:TryGetInstItem(
        Utils.getCurrentScope(), weaponInstId)
    local hasGem, gemBundle = GameInstance.player.inventory:TryGetInstItem(
        Utils.getCurrentScope(), gemInstId)
    if not hasWeapon or not hasGem then
        return false
    end
    local isMax = CS.Beyond.Gameplay.WeaponUtil.IsWeaponAttachGemSkillMathAndMaxLevel(weaponBundle, gemBundle, nil)
    return isMax
end

PhaseForesightCharGrowth._GetWeaponAttachedGemInstId = HL.Method(HL.Number).Return(HL.Number) << function(self, weaponInstId)
    if not weaponInstId or weaponInstId <= 0 then
        return 0
    end
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    if not weaponInst or not weaponInst.attachedGemInstId or weaponInst.attachedGemInstId <= 0 then
        return 0
    end
    return weaponInst.attachedGemInstId
end

PhaseForesightCharGrowth.IsGemPerfectMatchWeapon = HL.Method(HL.Number, HL.String).Return(HL.Boolean) << function(self, gemInstId, weaponId)
    if not gemInstId or gemInstId <= 0 or string.isEmpty(weaponId) then
        return false
    end
    if Tables.foresightWeaponTable:ContainsKey(weaponId) then
        local _, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        local isPerfectMatch = foresightCfg
            and UIUtils.isGemPerfectMatchWeaponTagIds(gemInstId, foresightCfg.gemTagIds)
        return isPerfectMatch == true
    end
    return UIUtils.isGemPerfectMatchWeapon(gemInstId, weaponId)
end


PhaseForesightCharGrowth.IsPerfectGoldGemForWeapon = HL.Method(HL.Number, HL.String).Return(HL.Boolean)
    << function(self, gemInstId, weaponId)
    if not gemInstId or gemInstId <= 0 or string.isEmpty(weaponId) then
        return false
    end
    if not self:IsGemPerfectMatchWeapon(gemInstId, weaponId) then
        return false
    end
    local gemInst = CharInfoUtils.getGemByInstId(gemInstId)
    if not gemInst then
        return false
    end
    local _, gemItemCfg = Tables.itemTable:TryGetValue(gemInst.templateId)
    if not gemItemCfg or gemItemCfg.rarity <= 4 then
        return false
    end
    return true
end

PhaseForesightCharGrowth.CountPerfectMatchGemsForWeapon = HL.Method(HL.String).Return(HL.Table)
    << function(self, weaponId)
    local result = { gold = 0, purple = 0 }
    if string.isEmpty(weaponId) then
        return result
    end
    local gemDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.WeaponGem]
        :GetOrFallback(Utils.getCurrentScope())
    if not gemDepot then
        return result
    end
    for _, gemInst in cs_pairs(gemDepot.instItems) do
        local gemInstId = gemInst.instId
        if self:IsGemPerfectMatchWeapon(gemInstId, weaponId) then
            local _, itemCfg = Tables.itemTable:TryGetValue(gemInst.id)
            if itemCfg and itemCfg.rarity > 4 then
                result.gold = result.gold + 1
            elseif itemCfg and itemCfg.rarity == 4 then
                result.purple = result.purple + 1
            end
        end
    end
    return result
end



PhaseForesightCharGrowth.GetPerfectGoldGemSelectIndex = HL.Method(HL.String, HL.Number).Return(HL.Number)
    << function(self, weaponId, weaponInstId)
    if string.isEmpty(weaponId) or not weaponInstId or weaponInstId <= 0 then
        return 0
    end
    local gemDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.WeaponGem]
        :GetOrFallback(Utils.getCurrentScope())
    if not gemDepot then
        return 0
    end
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    if not weaponInst then
        return 0
    end
    local _, weaponSkillList = CS.Beyond.Gameplay.WeaponUtil.TryGetWeaponSkillIdAndLevel(
        Utils.getCurrentScope(), weaponInstId, nil, weaponInst.breakthroughLv, weaponInst.refineLv)
    local extraArgs = { weaponSkillList = weaponSkillList }
    local itemInfoList = {}
    for _, gemInst in cs_pairs(gemDepot.instItems) do
        local itemInfo = FilterUtils.processWeaponGem(gemInst.id, gemInst.instId, extraArgs)
        if itemInfo then
            table.insert(itemInfoList, itemInfo)
        end
    end
    local sortKeys = UIConst.WEAPON_GEM_SORT_OPTION[1].keys
    table.sort(itemInfoList, Utils.genSortFunction(sortKeys, false))
    for luaIndex, itemInfo in ipairs(itemInfoList) do
        local gemInstId = itemInfo.instId or 0
        if gemInstId > 0 and self:IsPerfectGoldGemForWeapon(gemInstId, weaponId) then
            return luaIndex
        end
    end
    return 0
end

PhaseForesightCharGrowth.BuildGemFilterSelectedTagsForWeapon = HL.Method(HL.String).Return(HL.Table)
    << function(self, weaponId)
    local selectedTermIdMap = {}
    if Tables.foresightWeaponTable:ContainsKey(weaponId) then
        local okForesight, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        if okForesight and foresightCfg.gemTagIds then
            for i = 0, foresightCfg.gemTagIds.Count - 1 do
                local termCfg = self:_FindGemTermCfgByTagId(foresightCfg.gemTagIds[i])
                if termCfg and not string.isEmpty(termCfg.gemTermId) then
                    selectedTermIdMap[termCfg.gemTermId] = true
                end
            end
        end
    else
        local _, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
        if weaponCfg and weaponCfg.weaponSkillList then
            for _, skillId in pairs(weaponCfg.weaponSkillList) do
                local hasSkillCfg, skillCfg = Tables.skillPatchTable:TryGetValue(skillId)
                if hasSkillCfg and skillCfg.SkillPatchDataBundle and skillCfg.SkillPatchDataBundle.Count > 0 then
                    local tagId = skillCfg.SkillPatchDataBundle[0].tagId
                    local termCfg = self:_FindGemTermCfgByTagId(tagId)
                    if termCfg then
                        selectedTermIdMap[termCfg.gemTermId] = true
                    end
                end
            end
        end
    end
    local _, selectedTags = FilterUtils.generateConfig_WEAPON_EXHIBIT_GEM(selectedTermIdMap)
    return selectedTags or {}
end


PhaseForesightCharGrowth.FindBestGemEnergyPointGroupId = HL.Method(HL.String).Return(HL.Any, HL.Boolean) << function(self, weaponId)
    local weaponTagMap, hasUnknown = self:_BuildWeaponGemTagMap(weaponId)
    if hasUnknown or lume.count(weaponTagMap) <= 0 then
        return nil, false
    end
    local candidates = {}
    local hasLockedTagMatch = false
    for groupId, _ in pairs(Tables.worldEnergyPointGroupTable) do
        local groupCfg = Tables.worldEnergyPointGroupTable:GetValue(groupId)
        local groupTagMap = {}
        for _, ids in ipairs({ groupCfg.primAttrTermIds, groupCfg.secAttrTermIds, groupCfg.skillTermIds }) do
            for _, termId in pairs(ids) do
                local hasTermCfg, termCfg = Tables.gemTable:TryGetValue(termId)
                if hasTermCfg then
                    groupTagMap[termCfg.tagId] = true
                end
            end
        end
        local allTagsMatch = true
        for tagId, _ in pairs(weaponTagMap) do
            if not groupTagMap[tagId] then
                allTagsMatch = false
                break
            end
        end
        if allTagsMatch then
            local subGameId = GameInstance.player.worldEnergyPointSystem:GetCurSubGameId(groupId)
            local canOpen = subGameId ~= nil
                and GameInstance.player.subGameSys:IsGameMapMarkUnlock(groupId, GEnums.MarkType.EnemySpawner)
                and GameInstance.player.subGameSys:IsGameUnlocked(subGameId)
                and AdventureBookUtils.CheckEnemySpawnerCanOpenMap(groupId)
            if canOpen then
                table.insert(candidates, { groupId = groupId })
            else
                hasLockedTagMatch = true
            end
        end
    end
    if #candidates <= 0 then
        return nil, hasLockedTagMatch
    end
    table.sort(candidates, Utils.genSortFunction({ "groupId" }, false))
    return candidates[1].groupId, hasLockedTagMatch
end


PhaseForesightCharGrowth.JumpToBestGemEnergyPoint = HL.Method(HL.String).Return(HL.Boolean) << function(self, weaponId)
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.EnemySpawner) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_SYSTEM_LOCKED)
        return false
    end
    if PhaseManager:IsPhaseForbidden(PhaseId.Map) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SYSTEM_FORBIDDEN)
        return false
    end
    local groupId, hasLockedTagMatch = self:FindBestGemEnergyPointGroupId(weaponId)
    if not groupId then
        if hasLockedTagMatch then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_NO_MATCH_MAIN_STORY)
        else
            Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_NO_DUNGEON)
        end
        return false
    end
    local hasData, instId = GameInstance.player.mapManager:GetMapMarkInstId(
        GEnums.MarkType.EnemySpawner, groupId)
    if not hasData then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_NO_MATCH_MAIN_STORY)
        return false
    end
    local function doOpen()
        MapUtils.openMap(instId)
    end
    
    if not GameInstance.player.worldEnergyPointSystem.isFull then
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_GEM_TAG_OBTAIN_NOT_FULL_CONFIRM,
            onConfirm = doOpen,
        })
        return true
    end
    doOpen()
    return true
end

PhaseForesightCharGrowth._GetWeaponDisplayName = HL.Method(HL.String).Return(HL.String)
    << function(self, weaponId)
    if string.isEmpty(weaponId) then
        return ""
    end
    if Tables.foresightWeaponTable:ContainsKey(weaponId) then
        local ok, cfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        if ok then
            return cfg.name or ""
        end
    end
    local okItem, itemCfg = Tables.itemTable:TryGetValue(weaponId)
    if okItem then
        return itemCfg.name or ""
    end
    local okWeapon, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
    return okWeapon and weaponCfg.name or weaponId
end

PhaseForesightCharGrowth.TryRemoveWeaponFromGemWishList = HL.Method(HL.String).Return(HL.Boolean)
    << function(self, weaponId)
    local t = GameInstance.player.inventory.weaponGemWishList
    if string.isEmpty(weaponId) or not t:Contains(weaponId) then
        return false
    end
    local wishListIds = {}
    for _, id in pairs(t) do
        if not string.isEmpty(id) and id ~= weaponId then
            table.insert(wishListIds, id)
        end
    end
    GameInstance.player.inventory:SetWeaponGemWishList(wishListIds)
    return true
end

PhaseForesightCharGrowth.TryAddWeaponToGemWishList = HL.Method(HL.String).Return(HL.Boolean, HL.Boolean)
    << function(self, weaponId)
    if string.isEmpty(weaponId) then
        return true, false
    end
    local wasInList = GameInstance.player.inventory.weaponGemWishList:Contains(weaponId)
    local ok, needFullConfirm = PhaseForesightCharGrowth.RequestAddWeaponToGemWishList(weaponId)
    if ok and not wasInList then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_ADD_SUCCESS)
    end
    return ok, needFullConfirm
end

PhaseForesightCharGrowth.OpenGemTagObtainForWeapon = HL.Method(HL.String, HL.Opt(HL.Table)) << function(self, weaponId, extraArg)
    if string.isEmpty(weaponId) then
        return
    end
    PhaseManager:OpenPhase(PhaseId.GemTagObtain,{
        weaponId = weaponId,
        addToWishlist = true,
        foresightGoToLog = extraArg and extraArg.foresightGoToLog,
    })
end

PhaseForesightCharGrowth.OpenValuableDepotForWeapon = HL.Method(HL.String, HL.Opt(HL.Boolean))
    << function(self, weaponId, withPerfectMatchFilter)
    local args = {
        depotType = GEnums.ItemValuableDepotType.WeaponGem,
        shouldClearScreenOnOpen = true,
    }
    if withPerfectMatchFilter and not string.isEmpty(weaponId) then
        args.filterSelectedTags = self:BuildGemFilterSelectedTagsForWeapon(weaponId)
    end
    PhaseManager:OpenPhase(PhaseId.ValuableDepot,args)
end

local function fillGemGrowthHeader(self, header, isCharOwned)
    local weaponId = header.displayWeaponId or ""
    local weaponInstId = header.displayWeaponInstId or 0
    local hasUnknownTerms = self:HasWeaponUnknownGemTerms(weaponId)
    local attachedGemInstId = 0
    local isGemEquipped = false
    local isGemPerfectMatch = false
    local isGemEnhanceMax = false
    local isWeaponGemMaxDisplay = false
    if weaponInstId > 0 then
        attachedGemInstId = self:_GetWeaponAttachedGemInstId(weaponInstId)
        isGemEquipped = attachedGemInstId > 0
        if isGemEquipped then
            isGemPerfectMatch = self:IsGemPerfectMatchWeapon(attachedGemInstId, weaponId)
            isGemEnhanceMax = self:_IsGemEnhanceAllMax(attachedGemInstId)
            isWeaponGemMaxDisplay = self:_IsWeaponGemMaxDisplay(weaponInstId, attachedGemInstId)
        end
    end
    local perfectMatchCounts = self:CountPerfectMatchGemsForWeapon(weaponId)
    local matchedGem = isGemPerfectMatch and CharInfoUtils.getGemByInstId(attachedGemInstId)
    local matchedGemCfg = matchedGem and Tables.itemTable[matchedGem.templateId]
    local equippedIsPerfectGold = matchedGemCfg and matchedGemCfg.rarity > 4
    local okWeaponRarity, weaponItemCfg = Tables.itemTable:TryGetValue(weaponId)
    local showGrowthBubble = isCharOwned == true
        and (okWeaponRarity and weaponItemCfg.rarity and weaponItemCfg.rarity > 4)
        and not equippedIsPerfectGold
        and perfectMatchCounts.gold > 0
    local tryGemInstId = isGemEquipped and attachedGemInstId or nil
    local attachedGemTermEntries = {}
    local isGemSkillLevelOverWeaponCap = false
    local baseByTag
    if isGemEquipped then
        attachedGemTermEntries = self:BuildAttachedGemTermEntries(attachedGemInstId, weaponId)
        baseByTag = self:_BuildSkillLevelByTagId(weaponId, weaponInstId, nil)
        for _, g in ipairs(attachedGemTermEntries) do
            local info = g.isWeaponTagMatch and baseByTag[g.tagId]
            if info and (info.level or 0) + (g.level or 0) > (info.maxLevel or 0) then
                isGemSkillLevelOverWeaponCap = true
                break
            end
        end
    end
    header.hasUnknownTerms = hasUnknownTerms
    header.attachedGemInstId = attachedGemInstId
    header.isGemEquipped = isGemEquipped
    header.isGemPerfectMatch = isGemPerfectMatch
    header.isGemEnhanceMax = isGemEnhanceMax
    header.isWeaponGemMaxDisplay = isWeaponGemMaxDisplay
    header.isGemSkillLevelOverWeaponCap = isGemSkillLevelOverWeaponCap
    header.perfectMatchCounts = perfectMatchCounts
    header.hasPerfectMatchInDepot = perfectMatchCounts.gold > 0
    header.showGrowthBubble = showGrowthBubble
    header.gemTermEntries = self:BuildWeaponGemTermEntries(weaponId, weaponInstId, tryGemInstId, baseByTag)
    header.attachedGemTermEntries = attachedGemTermEntries
    return header
end

PhaseForesightCharGrowth.BuildGemGrowthHeaderBundle = HL.Method(HL.String, HL.Number, HL.String, HL.Boolean, HL.Opt(HL.String)).Return(HL.Table) << function(self, templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId)
    local header = self:BuildWeaponGrowthHeaderBundle(
        templateId, stageId, displayWeaponId, isCharOwned, equippedWeaponId)
    return fillGemGrowthHeader(self, header, isCharOwned)
end

PhaseForesightCharGrowth._BuildGemGrowthSections = HL.Method(HL.String, HL.Number, HL.Opt(HL.Table)).Return(HL.Table) << function(self, templateId, stageId, stageList)
    local weaponSections = self:_BuildWeaponGrowthSections(templateId, stageId, stageList)
    local playerChar = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
    local isCharOwned = playerChar ~= nil and CharInfoUtils.IsServerDefaultChar(playerChar)
    for _, section in ipairs(weaponSections) do
        section.headerBundle = fillGemGrowthHeader(self, section.headerBundle, isCharOwned)
    end
    return weaponSections
end





PhaseForesightCharGrowth.GetGrowthTabBundle = HL.Method(HL.String, HL.Number, HL.String, HL.Boolean, HL.Opt(HL.Table)).Return(HL.Table) << function(self, templateId, stageId, tabKey, showConverted, stageList)
    showConverted = showConverted ~= false
    stageList = stageList or self:GetCultivateStageIdList()
    local growthData
    local isCurStageMax = false
    if tabKey == "operator" then
        growthData = self:GetLevelGrowthItemListData(templateId, stageId, stageList)
        isCurStageMax = self:IsCurCultivateStageMax(templateId, stageList)
    elseif tabKey == "skill" then
        growthData = self:GetSkillGrowthItemListData(templateId, stageId, stageList)
    elseif tabKey == "weapon" then
        local weaponSections = self:_BuildWeaponGrowthSections(templateId, stageId, stageList)
        local rows = {}
        local headerBundle
        local isGoalReached = false
        for _, section in ipairs(weaponSections) do
            if not growthData then
                growthData = section.growthData
                headerBundle = section.headerBundle
                isGoalReached = section.isGoalReached == true
            end
            local sectionRows = self:GetOperatorGrowthDisplayRows(section.growthData, showConverted, tabKey)
            section.rowCount = #sectionRows
            for _, row in ipairs(sectionRows) do
                table.insert(rows, row)
            end
        end
        if not growthData then
            growthData = { stageId = stageId, targetLevel = 0 }
        end
        isCurStageMax = self:IsCurCultivateStageMax(templateId, stageList)
        return {
            growthData = growthData,
            rows = rows,
            weaponSections = weaponSections,
            headerBundle = headerBundle,
            isGoalReached = isGoalReached,
            isCurStageMax = isCurStageMax,
        }
    elseif tabKey == "matrix" then
        local gemSections = self:_BuildGemGrowthSections(templateId, stageId, stageList)
        local headerBundle
        local isGoalReached = false
        if #gemSections > 0 then
            growthData = gemSections[1].growthData
            headerBundle = gemSections[1].headerBundle
            isGoalReached = gemSections[1].isGoalReached == true
        else
            growthData = { stageId = stageId, targetLevel = 0 }
        end
        isCurStageMax = self:IsCurCultivateStageMax(templateId, stageList)
        return {
            growthData = growthData,
            rows = {},
            gemSections = gemSections,
            headerBundle = headerBundle,
            isGoalReached = isGoalReached,
            isCurStageMax = isCurStageMax,
        }
    else
        growthData = { stageId = stageId, targetLevel = 0 }
    end
    return {
        growthData = growthData,
        rows = self:GetOperatorGrowthDisplayRows(growthData, showConverted, tabKey),
        isGoalReached = self:IsOperatorGoalReached(growthData),
        isCurStageMax = isCurStageMax,
    }
end



HL.Commit(PhaseForesightCharGrowth)
