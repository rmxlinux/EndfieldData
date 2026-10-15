local InnUtils = {}

local tagSortIndex = {}

local FOOD_BOX_TITLE_ITEM_ID_CONFIG = {
    {
        title = "LUA_MAPMARK_FOODBOX_TITLE_1",
        itemIdList = { "item_corp_potato_1" },
    },
    {
        title = "LUA_MAPMARK_FOODBOX_TITLE_2",
        itemIdList = { "item_ranch_meat_1", "item_ranch_meat_2" },
    },
    {
        title = "LUA_MAPMARK_FOODBOX_TITLE_3",
        itemIdList = {
            "item_inn_drink_1",
            "item_inn_drink_2",
            "item_inn_drink_3",
            "item_inn_drink_4",
            "item_inn_drink_5",
            "item_inn_drink_6",
            "item_inn_drink_7",
            "item_inn_drink_8",
            "item_inn_drink_9",
            "item_inn_drink_10",
        },
    },
}

local FOOD_BOX_DEFAULT_TITLE = "LUA_MAPMARK_FOODBOX_TITLE_DEFAULT"



function InnUtils.findKitchenSetting(kitchenId)
    local inn = GameInstance.player and GameInstance.player.innSystem
    if not inn then
        return nil
    end
    local settings = inn and inn.gameSetting and inn.gameSetting.kitchenSettings
    if not settings or settings.Count == 0 then
        return nil
    end
    for i = 0, settings.Count - 1 do
        local ks = settings[i]
        if ks and ks.id == kitchenId then
            return ks
        end
    end
    return nil
end



function InnUtils.kitchenCharStringIds(kitchenSetting)
    local out = {}
    if not kitchenSetting or not kitchenSetting.charIds or kitchenSetting.charIds.Count == 0 then
        return out
    end
    local map = CS.Beyond.Cfg.Tables.charIdToStr
    for i = 0, kitchenSetting.charIds.Count - 1 do
        local numId = kitchenSetting.charIds[i]
        local hasStr, charStr = map:TryGetValue(numId)
        if hasStr and charStr and not string.isEmpty(charStr) then
            out[#out + 1] = charStr
        end
    end
    return out
end



function InnUtils.getSkillItemTagParamString(skillData)
    local params = skillData and skillData.parameters
    if not params or params.Count < 2 then
        return nil
    end
    local s = Utils.getDynamicParamStringValue(params[1])
    if not string.isEmpty(s) then
        return s
    end
    return nil
end



function InnUtils.classifyInnSkillTag(skillData)
    local tagId = InnUtils.getSkillItemTagParamString(skillData)
    if not tagId then
        return nil, nil
    end
    if tagId == Tables.innManagementConst.rareTag or Tables.innDishCategoryTable:TryGetValue(tagId) then
        return "category", tagId
    end
    if Tables.innAffixTable:TryGetValue(tagId) then
        return "affix", tagId
    end
    return nil, nil
end





function InnUtils.getCharInnSkills(charId, includeUnlock)
    if not charId or string.isEmpty(charId) then
        return {}
    end
    local hasEntry, entry = Tables.innCharSkillTable:TryGetValue(charId)
    if not hasEntry or not entry or not entry.list or entry.list.Count == 0 then
        return {}
    end
    local innLevel = 0
    if not includeUnlock then
        local inn = GameInstance.player and GameInstance.player.innSystem
        innLevel = (inn and inn.innLevel) or 0
    end
    local outList = {}
    for i = 0, entry.list.Count - 1 do
        local skillId = entry.list[i]
        local hasSkill, skillData = Tables.innSkillTable:TryGetValue(skillId)
        if hasSkill and skillData then
            if includeUnlock or (skillData.unlockLevel or 0) <= innLevel then
                outList[#outList + 1] = skillData
            end
        end
    end
    return outList
end





function InnUtils.isItemTagTopicHot(topicId, tagId)
    if not tagId or string.isEmpty(tagId) then
        return false
    end

    if string.isEmpty(topicId) then
        return GameInstance.player.innSystem.dailyCategoryIds:Contains(tagId) or
            GameInstance.player.innSystem.dailyAffixIds:Contains(tagId)
    end

    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if not hasTopic then
        return false
    end

    
    if topicData.topicType == GEnums.InnTopicType.PrivateChef then
        return GameInstance.player.innSystem.privateChefDailyCategoryIds:Contains(tagId) or
            GameInstance.player.innSystem.privateChefDailyAffixIds:Contains(tagId)
    end

    if topicData.hotCategory and Utils.isInclude(topicData.hotCategory, tagId) then
        return true
    end
    if topicData.hotAffix and Utils.isInclude(topicData.hotAffix, tagId) then
        return true
    end
    return false
end

function InnUtils.isTopicUsingDailyFashion(topicId)
    if string.isEmpty(topicId) then
        return true
    end
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    return hasTopic and topicData.topicType == GEnums.InnTopicType.PrivateChef
end





function InnUtils.itemSatisfiesAnyTopicReq(itemId, topicId)
    if string.isEmpty(itemId) or string.isEmpty(topicId) then
        return false
    end
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if not hasTopic or not topicData or not topicData.requirementList then
        return false
    end
    local matchLevelEnum = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel
    local list = topicData.requirementList
    for i = 0, list.Count - 1 do
        local reqId = list[i]
        if reqId and not string.isEmpty(reqId)
            and CS.Beyond.Gameplay.InnSystem.GetRequirementMatch(itemId, reqId) == matchLevelEnum.Perfect then
            return true
        end
    end
    return false
end





function InnUtils.collectInnSkillDetailTextByTagFromCharIds(charIds)
    
    local byTagId = {}
    if not charIds or #charIds == 0 then
        return {}
    end
    for _, charId in ipairs(charIds) do
        local skills = InnUtils.getCharInnSkills(charId)
        for _, skill in ipairs(skills) do
            local _, tagId = InnUtils.classifyInnSkillTag(skill)
            if tagId then
                local g = byTagId[tagId]
                if not g then
                    g = { desc = "", descValue = "", boost = 0 }
                    byTagId[tagId] = g
                end
                if string.isEmpty(g.desc) and not string.isEmpty(skill.desc) then
                    g.desc = skill.desc
                end
                if string.isEmpty(g.descValue) and not string.isEmpty(skill.descValue) then
                    g.descValue = skill.descValue
                end
                local params = skill.parameters
                if params and params.Count >= 3 then
                    g.boost = g.boost + Utils.getDynamicParamFloatValue(params[2])
                end
            end
        end
    end

    
    local tagToText = {}
    for tagId, g in pairs(byTagId) do
        if g.boost > 0 and not string.isEmpty(g.descValue) then
            tagToText[tagId] = string.format(g.descValue, string.format("%.0f%%", g.boost * 100))
        else
            tagToText[tagId] = g.desc
        end
    end
    return tagToText
end







function InnUtils.buildSkillTagRowsFromCharIds(charIds, topicId)
    if not charIds or #charIds == 0 then
        return {}, {}
    end

    
    local byTagId = {}
    for _, charId in ipairs(charIds) do
        local skills = InnUtils.getCharInnSkills(charId)
        for _, skill in ipairs(skills) do
            local side, tagId = InnUtils.classifyInnSkillTag(skill)
            if side and tagId then
                local g = byTagId[tagId]
                if not g then
                    local tagSortId = 0
                    local isRare = tagId == Tables.innManagementConst.rareTag
                    if side == "category" and not isRare then
                        local hasC, catData = Tables.innDishCategoryTable:TryGetValue(tagId)
                        if hasC and catData then
                            tagSortId = catData.sortId or 0
                        end
                    elseif side == "affix" or isRare then
                        local hasA, affData = Tables.innAffixTable:TryGetValue(tagId)
                        if hasA and affData then
                            tagSortId = affData.sortId or 0
                        end
                    end
                    byTagId[tagId] = { side = side, tagId = tagId, count = 1, sortId = tagSortId }
                else
                    g.count = g.count + 1
                end
            end
        end
    end

    
    local catRows = {}
    
    local affRows = {}
    for tagId, g in pairs(byTagId) do
        local args = {
            tagId = tagId,
            isHot = InnUtils.isItemTagTopicHot(topicId, tagId),
            upCount = g.count,
        }
        if g.side == "category" then
            catRows[#catRows + 1] = { tagId = tagId, sortId = g.sortId, upCountReverse = -g.count, args = args }
        elseif g.side == "affix" then
            affRows[#affRows + 1] = { tagId = tagId, sortId = g.sortId, upCountReverse = -g.count, args = args }
        end
    end

    local tagRowSort = Utils.genSortFunction({ "upCountReverse", "sortId", "tagId" }, true)
    table.sort(catRows, tagRowSort)
    table.sort(affRows, tagRowSort)
    return catRows, affRows
end






function InnUtils.getKitchenSkillTagRows(kitchenId, topicId)
    local inn = GameInstance.player and GameInstance.player.innSystem
    if not inn then
        return {}, {}
    end
    local kitchenSetting = InnUtils.findKitchenSetting(kitchenId)
    local charIds = InnUtils.kitchenCharStringIds(kitchenSetting)
    return InnUtils.buildSkillTagRowsFromCharIds(charIds, topicId)
end





function InnUtils.dishHasAffix(dish, affixId)
    if not dish or not dish.affix or string.isEmpty(affixId) then
        return false
    end
    for i = 0, dish.affix.Count - 1 do
        if dish.affix[i] == affixId then
            return true
        end
    end
    return false
end









function InnUtils.getKitchenSpeedBoost(kitchenId, dishItemId)
    if not kitchenId or string.isEmpty(dishItemId) then
        return 0
    end
    local hasD, dish = Tables.innDishTable:TryGetValue(dishItemId)
    if not hasD or not dish then
        return 0
    end
    local dishCategory = dish.category or ""

    local kitchenSetting = InnUtils.findKitchenSetting(kitchenId)
    local charIds = InnUtils.kitchenCharStringIds(kitchenSetting)
    local SkillType = GEnums.InnManagementSkillType
    local boost = 0
    for _, charId in ipairs(charIds) do
        local skills = InnUtils.getCharInnSkills(charId)
        for _, skill in ipairs(skills) do
            local tagId = InnUtils.getSkillItemTagParamString(skill)
            local params = skill.parameters
            if tagId and params then
                if skill.skillType == SkillType.CategorySpeedUp
                    and tagId == dishCategory and params.Count >= 3 then
                    boost = boost + Utils.getDynamicParamFloatValue(params[2])
                elseif skill.skillType == SkillType.AffixBonus
                    and InnUtils.dishHasAffix(dish, tagId) and params.Count >= 3 then
                    boost = boost + Utils.getDynamicParamFloatValue(params[2])
                end
            end
        end
    end
    return boost
end




function InnUtils.getDishCookTotalMs(itemId)
    if string.isEmpty(itemId) then
        return 0
    end
    local _, dish = Tables.innDishTable:TryGetValue(itemId)
    if not dish or not dish.timeCost or dish.timeCost <= 0 then
        return 0
    end
    return dish.timeCost * 1000
end





function InnUtils.getDishRealCookSeconds(kitchenId, itemId)
    local totalMs = InnUtils.getDishCookTotalMs(itemId)
    if totalMs <= 0 then
        return 0
    end
    local boost = InnUtils.getKitchenSpeedBoost(kitchenId, itemId)
    if boost < 0 then
        boost = 0
    end
    local rate = 1 + boost
    local inn = GameInstance.player and GameInstance.player.innSystem
    local gs = inn and inn.gameState
    if gs and gs.isInRushTime then
        local rushRate = inn:GetRushSpeedRate()
        rate = rate * ((rushRate and rushRate > 0) and rushRate or 1)
    end
    if rate <= 0 then
        rate = 1
    end
    return math.ceil(totalMs / rate / 1000)
end







function InnUtils.getKitchenRareRate(kitchenId, returnDetails)
    local inn = GameInstance.player and GameInstance.player.innSystem
    if not inn then
        return 0, returnDetails and {} or nil
    end

    local baseRate, baseRateFromTopic = inn:GetBaseRareRate()
    baseRate = baseRate or 0

    local skillRate = 0
    local kitchenSetting = InnUtils.findKitchenSetting(kitchenId)
    local charIds = InnUtils.kitchenCharStringIds(kitchenSetting)
    local SkillType = GEnums.InnManagementSkillType
    for _, charId in ipairs(charIds) do
        local skills = InnUtils.getCharInnSkills(charId)
        for _, skill in ipairs(skills) do
            if skill.skillType == SkillType.RareRateBonus then
                local params = skill.parameters
                if params and params.Count >= 3 then
                    skillRate = skillRate + Utils.getDynamicParamFloatValue(params[2])
                end
            end
        end
    end

    local jsspsiRate = 0
    local jsspsiStage = 0
    local innConst = Tables.innManagementConst
    local jsspsiCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(innConst.jsspsiCharId, GEnums.CharType.Default)
    if jsspsiCharInfo then
        local friendship = CSPlayerDataUtil.GetCharFriendship(innConst.jsspsiCharId)
        if friendship >= innConst.jsspsiThidStageFavorability then
            jsspsiRate = innConst.jsspsiThirdStageSkillParam
            jsspsiStage = 3
        elseif friendship >= innConst.jsspsiSecondStageFavorability then
            jsspsiRate = innConst.jsspsiSecondStageSkillParam
            jsspsiStage = 2
        else
            jsspsiRate = innConst.jsspsiFirstStageSkillParam
            jsspsiStage = 1
        end
    end

    local total = baseRate + skillRate + jsspsiRate
    if not returnDetails then
        return total
    end

    local function buildDesc(tagText, rate)
        local percentText = string.format("%.0f", rate * 100)
        return string.format(Language.LUA_INN_RARE_RATE_DESC_FORMAT, tagText, percentText)
    end

    local details = {}
    if baseRate > 0 then
        local tagText
        if baseRateFromTopic then
            
            local topicId = inn.gameSetting and inn.gameSetting.topicId
            local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId or "")
            tagText = (hasTopic and topicData) and topicData.name or ""
        else
            tagText = string.format(Language.LUA_INN_RARE_RATE_DESC_TAG_INN_LEVEL, inn.innLevel)
        end
        details[#details + 1] = {
            source = "inn",
            title = Language.LUA_INN_RARE_RATE_TITLE_INN,
            desc = buildDesc(tagText, baseRate),
            rate = baseRate,
        }
    end
    if jsspsiCharInfo and jsspsiRate > 0 then
        local tagText = string.format(Language.LUA_INN_RARE_RATE_DESC_TAG_JSSPSI_STAGE, jsspsiStage)
        details[#details + 1] = {
            source = "jsspsi",
            title = Language.LUA_INN_RARE_RATE_TITLE_JSSPSI,
            desc = buildDesc(tagText, jsspsiRate),
            rate = jsspsiRate,
        }
    end
    if skillRate > 0 then
        details[#details + 1] = {
            source = "kitchen",
            title = Language.LUA_INN_RARE_RATE_TITLE_KITCHEN,
            desc = buildDesc(Language.LUA_INN_RARE_RATE_DESC_TAG_KITCHEN_CHAR, skillRate),
            rate = skillRate,
        }
    end

    return total, details
end




















InnUtils.debugStartGameConfig = {
    
    softOpening = nil,
    
    topicId = nil,
    
    autoDuty = nil,
    
    
    kitchenSettings = nil,
    
    dishes = nil,
    
    drinks = nil,
}











function InnUtils.debugStartGame()
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    if not innSystem then
        return
    end
    local cfg = InnUtils.debugStartGameConfig or {}
    local gameSetting = innSystem.gameSetting

    if cfg.softOpening ~= nil then
        gameSetting.softOpening = cfg.softOpening
    else
        gameSetting.softOpening = false
    end

    if cfg.topicId and not string.isEmpty(cfg.topicId) then
        gameSetting.topicId = cfg.topicId
    else
        local topicIds = {}
        for topicId, topicData in pairs(Tables.innTopicTable) do
            if topicData and (topicData.unlockLevel or 0) <= innSystem.innLevel then
                topicIds[#topicIds + 1] = topicId
            end
        end
        gameSetting.topicId = #topicIds > 0 and lume.randomchoice(topicIds) or ""
    end

    local autoDuty = gameSetting.autoDuty
    autoDuty:Clear()
    if type(cfg.autoDuty) == "table" then
        for dutyType, isOn in pairs(cfg.autoDuty) do
            autoDuty[dutyType] = isOn and true or false
        end
    else
        local DutyTypeNone = GEnums.JsspsiDutyType.None
        for level, levelData in pairs(Tables.innLevelTable) do
            if level <= innSystem.innLevel
                and levelData and levelData.newJsspsiDuty ~= DutyTypeNone then
                autoDuty[levelData.newJsspsiDuty] = true
            end
        end
    end

    local hasLv, lvData = Tables.innLevelTable:TryGetValue(innSystem.innLevel)

    gameSetting.kitchenSettings:Clear()
    if type(cfg.kitchenSettings) == "table" then
        for _, kEntry in ipairs(cfg.kitchenSettings) do
            local ks = CS.Beyond.Gameplay.InnSystem.KitchenSetting()
            ks.id = kEntry.id or 0
            if type(kEntry.charIds) == "table" then
                for _, charIdStr in ipairs(kEntry.charIds) do
                    if type(charIdStr) == "string" and not string.isEmpty(charIdStr) then
                        local hasNum, numId = CS.Beyond.Cfg.Tables.charIdToNum:TryGetValue(charIdStr)
                        if hasNum then
                            ks.charIds:Add(numId)
                        else
                            logger.error(string.format(
                                "[InnUtils.debugStartGame] kitchen %d charId '%s' not found in charIdToNum, skipped",
                                ks.id, charIdStr))
                        end
                    end
                end
            end
            gameSetting.kitchenSettings:Add(ks)
        end
    else
        local jsspsiCharId = Tables.innManagementConst.jsspsiCharId
        local charPool = {}
        for charId, _ in pairs(Tables.characterTable) do
            if not string.isEmpty(charId)
                and not CS.Beyond.Gameplay.CharUtils.IsEndminTemplateId(charId)
                and charId ~= jsspsiCharId then
                local hasNum, numId = CS.Beyond.Cfg.Tables.charIdToNum:TryGetValue(charId)
                if hasNum then
                    charPool[#charPool + 1] = numId
                end
            end
        end
        lume.shuffle(charPool)

        local kitchenCount = innSystem.kitchenNum
        local maxStaffPerKitchen = innSystem.kitchenCharSlotNum > 0 and innSystem.kitchenCharSlotNum or 2

        local cursor = 1
        local remaining = #charPool
        for kid = 1, kitchenCount do
            local ks = CS.Beyond.Gameplay.InnSystem.KitchenSetting()
            ks.id = kid
            local reserved = kitchenCount - kid
            local maxPick = math.max(0, remaining - reserved)
            local pick = remaining > 0 and math.min(math.random(1, maxStaffPerKitchen), maxPick) or 0
            for _ = 1, pick do
                ks.charIds:Add(charPool[cursor])
                cursor = cursor + 1
            end
            remaining = remaining - pick
            gameSetting.kitchenSettings:Add(ks)
        end
    end

    local function rollRangeCount(range, fallback)
        if not range or range.Count < 2 then
            return fallback
        end
        local lo = range[0]
        local hi = range[1]
        if hi < lo then
            lo, hi = hi, lo
        end
        return math.random(lo, hi)
    end

    local dishCount = rollRangeCount(hasLv and lvData and lvData.menuDishNumRange or nil, 8)
    local drinkCount = rollRangeCount(hasLv and lvData and lvData.menuDrinkNumRange or nil, 8)

    local innLevel = innSystem.innLevel
    local usableDishType = hasLv and lvData and lvData.usableDishType or nil

    local function isDishUsable(dishData)
        if not dishData then
            return false
        end
        if (dishData.unlockLevel or 0) > innLevel then
            return false
        end
        if usableDishType and #usableDishType > 0 then
            if not Utils.isInclude(usableDishType, dishData.category) then
                return false
            end
        end
        return true
    end

    local function isDrinkUsable(drinkData)
        if not drinkData then
            return false
        end
        return (drinkData.unlockLevel or 0) <= innLevel
    end

    local function addPickedToMenu(picked, foodType)
        for _, id in ipairs(picked) do
            local mi = CS.Beyond.Gameplay.InnSystem.MenuItem()
            mi.foodType = foodType
            mi.itemId = id
            gameSetting.menuItems:Add(mi)
        end
    end

    
    local function pickMenu(tbl, foodType, count, filter, forcedIds)
        forcedIds = forcedIds or {}
        local picked = {}
        local pickedSet = {}
        for id in pairs(forcedIds) do
            picked[#picked + 1] = id
            pickedSet[id] = true
        end
        local ids = {}
        for id, data in pairs(tbl) do
            if (not filter or filter(data)) and not pickedSet[id] then
                ids[#ids + 1] = id
            end
        end
        lume.shuffle(ids)
        local idx = 1
        while #picked < count and idx <= #ids do
            picked[#picked + 1] = ids[idx]
            idx = idx + 1
        end
        addPickedToMenu(picked, foodType)
    end

    
    local function pickDishMenu(count, filter, minTypes, forcedIds)
        forcedIds = forcedIds or {}

        
        local picked = {}
        local pickedSet = {}
        local coveredCats = {}
        for id in pairs(forcedIds) do
            picked[#picked + 1] = id
            pickedSet[id] = true
            local has, data = Tables.innDishTable:TryGetValue(id)
            if has and data then
                coveredCats[data.category or ""] = true
            end
        end

        
        local buckets = {}
        local categories = {}
        for id, data in pairs(Tables.innDishTable) do
            if (not filter or filter(data)) and not pickedSet[id] then
                local cat = data.category or ""
                local b = buckets[cat]
                if not b then
                    b = {}
                    buckets[cat] = b
                    categories[#categories + 1] = cat
                end
                b[#b + 1] = id
            end
        end
        for _, b in pairs(buckets) do
            lume.shuffle(b)
        end
        lume.shuffle(categories)

        
        local coveredCount = 0
        for _ in pairs(coveredCats) do
            coveredCount = coveredCount + 1
        end
        local needTypes = math.max(0, minTypes or 0)
        for _, cat in ipairs(categories) do
            if coveredCount >= needTypes or #picked >= count then
                break
            end
            if not coveredCats[cat] then
                local id = table.remove(buckets[cat])
                if id then
                    picked[#picked + 1] = id
                    pickedSet[id] = true
                    coveredCats[cat] = true
                    coveredCount = coveredCount + 1
                end
            end
        end

        
        local pool = {}
        for _, b in pairs(buckets) do
            for _, id in ipairs(b) do
                if not pickedSet[id] then
                    pool[#pool + 1] = id
                end
            end
        end
        lume.shuffle(pool)
        local poolIdx = 1
        while #picked < count and poolIdx <= #pool do
            picked[#picked + 1] = pool[poolIdx]
            poolIdx = poolIdx + 1
        end

        addPickedToMenu(picked, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish)
    end

    local minDishTypes = hasLv and lvData and lvData.menuDishTypeNumMin or 0

    local function pickFromConfigList(cfgList, tbl, foodType)
        local picked = {}
        for _, itemId in ipairs(cfgList) do
            if type(itemId) == "string" and not string.isEmpty(itemId) then
                local has, _data = tbl:TryGetValue(itemId)
                if has then
                    picked[#picked + 1] = itemId
                else
                    logger.error(string.format(
                        "[InnUtils.debugStartGame] menu itemId '%s' not found, skipped", itemId))
                end
            end
        end
        addPickedToMenu(picked, foodType)
    end

    
    
    
    
    local function collectRequirementForcedIds(topicId)
        local forcedDish, forcedDrink = {}, {}
        if string.isEmpty(topicId) then
            return forcedDish, forcedDrink
        end
        local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
        if not hasTopic or not topicData or not topicData.requirementList then
            return forcedDish, forcedDrink
        end
        local list = topicData.requirementList
        local nums = topicData.requirementNum
        local Perfect = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel.Perfect

        local function gatherMatches(reqId, tbl, usableFn)
            local out = {}
            for id, data in pairs(tbl) do
                if usableFn(data)
                    and CS.Beyond.Gameplay.InnSystem.GetRequirementMatch(id, reqId) == Perfect then
                    out[#out + 1] = id
                end
            end
            lume.shuffle(out)
            return out
        end

        for i = 0, list.Count - 1 do
            local reqId = list[i]
            local need = (nums and i < nums.Count) and nums[i] or 0
            if reqId and not string.isEmpty(reqId) and need > 0 then
                local dishMatches = gatherMatches(reqId, Tables.innDishTable, isDishUsable)
                local pool, forced
                if #dishMatches > 0 then
                    pool, forced = dishMatches, forcedDish
                else
                    pool, forced = gatherMatches(reqId, Tables.innDrinkTable, isDrinkUsable), forcedDrink
                end
                
                local added = 0
                for _, id in ipairs(pool) do
                    if added >= need then
                        break
                    end
                    if not forced[id] then
                        forced[id] = true
                        added = added + 1
                    end
                end
                if added < need then
                    logger.error(string.format(
                        "[InnUtils.debugStartGame] topic requirement '%s' needs %d perfect-match foods but only %d available",
                        reqId, need, added))
                end
            end
        end
        return forcedDish, forcedDrink
    end

    local forcedDishIds, forcedDrinkIds = collectRequirementForcedIds(gameSetting.topicId)

    gameSetting.menuItems:Clear()
    if type(cfg.dishes) == "table" then
        pickFromConfigList(cfg.dishes, Tables.innDishTable, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish)
    else
        pickDishMenu(dishCount, isDishUsable, minDishTypes, forcedDishIds)
    end
    if type(cfg.drinks) == "table" then
        pickFromConfigList(cfg.drinks, Tables.innDrinkTable, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink)
    else
        pickMenu(Tables.innDrinkTable, CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink, drinkCount, isDrinkUsable, forcedDrinkIds)
    end

    innSystem:SendStartGame()
end













function InnUtils.buildFoodDemandMap(innSystem, foodType)
    local map = {}
    local gs = innSystem and innSystem.gameState
    if not gs or foodType == nil then
        return map
    end

    local NORMAL = CS.Proto.INN_MANAGEMENT_GUEST_TYPE.GuestTypeNormal
    local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel
    local DISH = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish

    
    if gs.guestStates then
        for _, guest in cs_pairs(gs.guestStates) do
            if guest and guest.guestType == NORMAL and guest.orders and guest.matches then
                
                local slotCount = math.min(guest.orders.Count, guest.matches.Count)
                local hasEmptySlot = false
                for i = 0, slotCount - 1 do
                    local order = guest.orders[i]
                    if order and order.foodType == foodType and guest.matches[i] == MATCH_LEVEL.NotServed then
                        hasEmptySlot = true
                        break
                    end
                end
                if hasEmptySlot then
                    for i = 0, slotCount - 1 do
                        local order = guest.orders[i]
                        if order and order.foodType == foodType
                                and guest.matches[i] ~= MATCH_LEVEL.Normal
                                and not string.isEmpty(order.itemId) then
                            map[order.itemId] = (map[order.itemId] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    
    if gs.servingCounterFoodIds and gs.foods then
        for _, foodId in cs_pairs(gs.servingCounterFoodIds) do
            local _, food = gs.foods:TryGetValue(foodId)
            if food and food.foodType == foodType and not string.isEmpty(food.itemId) and map[food.itemId] then
                map[food.itemId] = map[food.itemId] - 1
            end
        end
    end

    
    if foodType == DISH and gs.kitchenStates then
        for _, ks in cs_pairs(gs.kitchenStates) do
            if ks then
                if not string.isEmpty(ks.cookingFoodItemId) and map[ks.cookingFoodItemId] then
                    map[ks.cookingFoodItemId] = map[ks.cookingFoodItemId] - 1
                end
                if ks.waitingFoodItemIds then
                    for i = 0, ks.waitingFoodItemIds.Count - 1 do
                        local itemId = ks.waitingFoodItemIds[i]
                        if not string.isEmpty(itemId) and map[itemId] then
                            map[itemId] = map[itemId] - 1
                        end
                    end
                end
            end
        end
    end

    
    if gs.foodTrayFoodIds and gs.foods then
        for _, foodId in cs_pairs(gs.foodTrayFoodIds) do
            local _, food = gs.foods:TryGetValue(foodId)
            if food and food.foodType == foodType and not string.isEmpty(food.itemId) and map[food.itemId] then
                map[food.itemId] = map[food.itemId] - 1
            end
        end
    end

    return map
end











function InnUtils.getDeskRemainingFoodTypeFlags(innSystem, deskId)
    local gs = innSystem and innSystem.gameState
    if not gs or not deskId or deskId <= 0 then
        return false, false
    end
    if not gs.deskStates or not gs.guestStates then
        return false, false
    end

    local hasDesk, desk = gs.deskStates:TryGetValue(deskId)
    if not hasDesk or not desk or desk.guestId <= 0 then
        return false, false
    end
    local hasGuest, guest = gs.guestStates:TryGetValue(desk.guestId)
    if not hasGuest or not guest then
        return false, false
    end

    local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
    local GUEST_TYPE = CS.Proto.INN_MANAGEMENT_GUEST_TYPE

    local needDish, needDrink = 0, 0
    if guest.guestType == GUEST_TYPE.GuestTypeNormal then
        if guest.orders then
            for i = 0, guest.orders.Count - 1 do
                local order = guest.orders[i]
                if order then
                    if order.foodType == FOOD_TYPE.FoodTypeDish then
                        needDish = needDish + 1
                    elseif order.foodType == FOOD_TYPE.FoodTypeDrink then
                        needDrink = needDrink + 1
                    end
                end
            end
        end
    else
        
        if guest.requirementIds and Tables and Tables.innRequirementTable then
            for i = 0, guest.requirementIds.Count - 1 do
                local reqId = guest.requirementIds[i]
                if not string.isEmpty(reqId) then
                    local hasReq, req = Tables.innRequirementTable:TryGetValue(reqId)
                    if hasReq and req then
                        if req.foodType == GEnums.InnManagementFoodType.Dish then
                            needDish = needDish + 1
                        elseif req.foodType == GEnums.InnManagementFoodType.Drink then
                            needDrink = needDrink + 1
                        end
                    end
                end
            end
        end
    end

    local gotDish, gotDrink = 0, 0
    if guest.gotFoodIds and gs.foods then
        for i = 0, guest.gotFoodIds.Count - 1 do
            local foodId = guest.gotFoodIds[i]
            local hasFood, food = gs.foods:TryGetValue(foodId)
            if hasFood and food then
                if food.foodType == FOOD_TYPE.FoodTypeDish then
                    gotDish = gotDish + 1
                elseif food.foodType == FOOD_TYPE.FoodTypeDrink then
                    gotDrink = gotDrink + 1
                end
            end
        end
    end

    return needDish > gotDish, needDrink > gotDrink
end



function InnUtils.DebugResultPanel()
    local DictStringInt = CS.System.Collections.Generic.Dictionary(CS.System.String, CS.System.Int32)
    local DictIntInt = CS.System.Collections.Generic.Dictionary(CS.System.Int32, CS.System.Int32)
    local DictStringCondition = CS.System.Collections.Generic.Dictionary(CS.System.String, CS.Beyond.Gameplay.InnSystem.TopicObjectiveCondition)

    local data = CS.Beyond.Gameplay.InnGameResultData()
    data.totalBaseMoney = 12345
    data.totalTipMoney = 6789
    data.moneyScore = 19134
    data.maxComboCount = 8
    data.rareDishCount = 3
    data.perfectSpecialGuestServed = 2
    data.notFailedSpecialGuestServed = 4
    data.successNormalGuestServed = 15
    data.totalGuestServed = 23
    data.rushCount = 2
    data.kpiScore = 8500
    data.topicScore = 3000
    data.totalScore = 30634
    data.topicStar = 5
    data.oldTopicStar = 3
    data.isNewRecord = true
    data.jsspsiFavorabilityBefore = 99999
    data.jsspsiFavorabilityAfter = 99999
    data.isTeachingMode = false

    local dishDict = DictStringInt()
    local dishPicked = 0
    for dishId, _ in pairs(Tables.innDishTable) do
        if dishPicked >= 5 then break end
        dishDict:Add(dishId, math.random(1, 10))
        dishPicked = dishPicked + 1
    end
    data.soldDishCount = dishDict

    local drinkDict = DictStringInt()
    local drinkPicked = 0
    for drinkId, _ in pairs(Tables.innDrinkTable) do
        if drinkPicked >= 3 then break end
        drinkDict:Add(drinkId, math.random(1, 8))
        drinkPicked = drinkPicked + 1
    end
    data.soldDrinkCount = drinkDict

    local kitchenDict = DictIntInt()
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local kitchenCount = innSystem and innSystem.kitchenNum or 2
    for i = 1, kitchenCount do
        kitchenDict:Add(i, math.random(5, 20))
    end
    data.kitchensDishCount = kitchenDict

    data.conditionState = DictStringCondition()
    local condition = CS.Beyond.Gameplay.InnSystem.TopicObjectiveCondition()
    condition.condId = "object_inn_topic_2"
    condition.value = 5
    condition.flag = true
    data.conditionState:Add(condition.condId, condition)

    data.mvpCharId = 0
    if innSystem then
        local settings = innSystem.gameSetting and innSystem.gameSetting.kitchenSettings
        if settings and settings.Count > 0 then
            local firstKitchen = settings[0]
            if firstKitchen and firstKitchen.charIds and firstKitchen.charIds.Count > 0 then
                data.mvpCharId = firstKitchen.charIds[0]
            end
        end
    end

    data.addExp = 500
    data.rewardCoupon = 2345

    data.unsettled = false
    data.gameSetting = data.unsettled and innSystem.oldGameSetting or innSystem.gameSetting

    
    
    Notify(MessageConst.ON_INN_OPEN_RESULT_PANEL, {data})

    
    
end






function InnUtils.getFriendshipAddTier(star)
    local rewards = Tables.innManagementConst.jsspsiFavorabilityReward
    if not rewards or rewards.Count == 0 then
        return 1, 0
    end
    star = math.max(0, math.min(star, rewards.Count - 1))

    local tier = 1
    local reward = rewards[0]
    for i = 1, star do
        if rewards[i] ~= rewards[i - 1] then
            tier = tier + 1
            reward = rewards[i]
        end
    end

    return math.min(tier, 4), reward
end


local pendingTopicSelectionArg = nil

function InnUtils.startGame(onOpened, arg)
    local innSystem = GameInstance.player.innSystem
    local gameSetting = CS.Beyond.Gameplay.InnSystem.GameSetting()
    innSystem.gameSetting = gameSetting
    return PhaseManager:OpenPhase(PhaseId.InnTopicSelection, arg, onOpened)
end

function InnUtils.takePendingTopicSelectionArg()
    local arg = pendingTopicSelectionArg
    pendingTopicSelectionArg = nil
    return arg
end

function InnUtils.openTopicSelection(arg)
    local innSystem = GameInstance.player.innSystem
    if innSystem.existUnsettledGame then
        pendingTopicSelectionArg = arg
        innSystem:SendSettleOldGame(function()
            pendingTopicSelectionArg = nil
        end)
        return
    end
    PhaseManager:OpenPhase(PhaseId.InnTopicSelection, arg)
end


function InnUtils.getTagSortIndex(tagName)
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    if not innSystem then
        return -1
    end

    local innLevel = innSystem.innLevel
    local ok, ruleData = Tables.innRandomRuleTable:TryGetValue(innLevel)
    if not ok or not ruleData then
        return -1
    end

    local levelTagConfig = tagSortIndex[innLevel]
    if not levelTagConfig then
        levelTagConfig = {}
        tagSortIndex[innLevel] = levelTagConfig

        for i = 0, ruleData.mustTag.Count - 1 do
            levelTagConfig[ruleData.mustTag[i]] = i + 1
        end
    end

    return levelTagConfig[tagName] or -1
end

function InnUtils.sortShopGoods(shopId, goods, soldOut)
    local shopSystem = GameInstance.player.shopSystem

    local compareFunc = function(goodsInfo1, goodsInfo2)
        local goodsId1 = goodsInfo1.id
        local goodsId2 = goodsInfo2.id
        local goodsData1 = shopSystem:GetShopGoodsData(shopId, goodsId1)
        local goodsData2 = shopSystem:GetShopGoodsData(shopId, goodsId2)

        if not goodsData1 or not goodsData2 then
            return goodsData1 ~= nil
        end

        
        if goodsData1.discount ~= goodsData2.discount then
            return goodsData1.discount < goodsData2.discount
        end

        local __, randomData1 = Tables.innGoodsRandomTable:TryGetValue(goodsId1)
        local __, randomData2 = Tables.innGoodsRandomTable:TryGetValue(goodsId2)
        if not randomData1 or not randomData2 then
            return randomData1 ~= nil
        end

        
        local tagIndex1 = InnUtils.getTagSortIndex(randomData1.randomTag)
        local tagIndex2 = InnUtils.getTagSortIndex(randomData2.randomTag)
        if tagIndex1 ~= tagIndex2 then
            return tagIndex1 > tagIndex2
        end

        
        if goodsInfo1.rarity ~= goodsInfo2.rarity then
            return goodsInfo1.rarity > goodsInfo2.rarity
        end

        return goodsId1 > goodsId2
    end

    table.sort(goods, compareFunc)
    table.sort(soldOut, compareFunc)
end





function InnUtils.getDishCraftInfo(itemId)
    if string.isEmpty(itemId) then
        return nil
    end
    local hasDish, dishData = Tables.innDishTable:TryGetValue(itemId)
    if not hasDish or not dishData then
        return nil
    end
    local ingredient = dishData.ingredient
    if not ingredient or ingredient.Count == 0 then
        return nil
    end

    local incomes = {}
    local nums = dishData.ingredientNum
    for i = 0, ingredient.Count - 1 do
        local id = ingredient[i]
        if id and not string.isEmpty(id) then
            local count = 1
            if nums and i < nums.Count then
                count = nums[i] or 1
            end
            if count <= 0 then
                count = 1
            end
            table.insert(incomes, { id = id, count = count })
        end
    end
    if #incomes == 0 then
        return nil
    end

    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local isUnlock = (innSystem ~= nil and innSystem:IsDishUnlocked(itemId)) or false

    return {
        craftId = itemId,
        incomes = incomes,
        outcomes = { { id = itemId, count = 1 } },
        isUnlock = isUnlock,
    }
end





function InnUtils.getIngredientCount(itemId)
    if string.isEmpty(itemId) then
        return 0
    end
    if not GameInstance.player or not GameInstance.player.inventory then
        return 0
    end
    return GameInstance.player.inventory:GetItemCount(Utils.getCurrentScope(), Utils.getCurrentChapterId(), itemId)
end




function InnUtils.getDishCraftableCount(itemId)
    local craftInfo = InnUtils.getDishCraftInfo(itemId)
    if not craftInfo or #craftInfo.incomes == 0 then
        return 0
    end
    local minBatches = math.huge
    for _, income in ipairs(craftInfo.incomes) do
        local batches = InnUtils.getIngredientCount(income.id) // income.count
        if batches < minBatches then
            minBatches = batches
        end
    end
    if minBatches == math.huge then
        return 0
    end
    return minBatches
end





function InnUtils.isAllMenuDishSoldOut(innSystem)
    local gameSetting = innSystem and innSystem.gameSetting
    if not gameSetting or gameSetting.softOpening then
        return false
    end
    local menuItems = gameSetting.menuItems
    if not menuItems or menuItems.Count <= 0 then
        return false
    end
    local DISH = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish
    local hasDish = false
    for i = 0, menuItems.Count - 1 do
        local mi = menuItems[i]
        if mi and mi.foodType == DISH and not string.isEmpty(mi.itemId) then
            hasDish = true
            if InnUtils.getDishCraftableCount(mi.itemId) > 0 then
                return false
            end
        end
    end
    return hasDish
end





function InnUtils.hasDishInFoodIds(gs, foodIds)
    if not foodIds or not gs.foods then
        return false
    end
    local DISH = CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish
    for _, foodId in cs_pairs(foodIds) do
        local _, food = gs.foods:TryGetValue(foodId)
        if food and food.foodType == DISH then
            return true
        end
    end
    return false
end




function InnUtils.hasRemainingDish(innSystem)
    local gs = innSystem and innSystem.gameState
    if not gs then
        return false
    end
    if InnUtils.hasDishInFoodIds(gs, gs.servingCounterFoodIds) or InnUtils.hasDishInFoodIds(gs, gs.foodTrayFoodIds) then
        return true
    end
    
    if gs.kitchenStates then
        for _, ks in cs_pairs(gs.kitchenStates) do
            if ks then
                if not string.isEmpty(ks.cookingFoodItemId) then
                    return true
                end
                if ks.waitingFoodItemIds and ks.waitingFoodItemIds.Count > 0 then
                    return true
                end
            end
        end
    end
    return false
end

InnUtils.DISH_SOLD_OUT_TIPS_ALL_GONE = "AllGone"
InnUtils.DISH_SOLD_OUT_TIPS_HAS_REMAINING = "HasRemaining"







function InnUtils.getDishSoldOutTipsState(innSystem)
    local gs = innSystem and innSystem.gameState
    if not gs or gs.wrapUp or gs.isEndingGame then
        return nil
    end
    if not InnUtils.isAllMenuDishSoldOut(innSystem) then
        return nil
    end
    if InnUtils.hasRemainingDish(innSystem) then
        return InnUtils.DISH_SOLD_OUT_TIPS_HAS_REMAINING
    end
    return InnUtils.DISH_SOLD_OUT_TIPS_ALL_GONE
end



function InnUtils.GetShopStorageWayToggleInfo(shopId)
    if not InnConst.INN_STORAGE_WAY_EDITABLE_SHOP[shopId] then
        return nil
    end

    local shopDepotFirst = GameInstance.player.innSystem.shopDepotFirst
    local onChangeFunc = function (isOn)
        GameInstance.player.innSystem:SendSetShopDepotStorageWay(isOn)
    end

    return shopDepotFirst, onChangeFunc
end

function InnUtils.GetShopLockToast(shopId)
    local shopCfg = Tables.shopTable[shopId]
    local conditions = shopCfg and shopCfg.unlockConditions
    if not conditions or conditions.Count == nil or conditions.Count == 0 then
        return nil
    end
    local desc = conditions[0].desc 
    return desc
end



function InnUtils.getFoodBoxTitle(markInstId)
    if string.isEmpty(markInstId) then
        return Language[FOOD_BOX_DEFAULT_TITLE]
    end

    local player = GameInstance.player
    if player == nil or player.doodadSystem == nil or player.farmTerminalSystem == nil then
        return Language[FOOD_BOX_DEFAULT_TITLE]
    end

    local doodadGroupData = player.doodadSystem:GetDoodadSystemDataByMarkInst(markInstId)
    if doodadGroupData == nil then
        return Language[FOOD_BOX_DEFAULT_TITLE]
    end

    local rewardBundles = player.farmTerminalSystem:GetFoodBoxDropItems(markInstId, true)
    local rewardItemIdSet = {}
    for i = 0, rewardBundles.Count - 1 do
        rewardItemIdSet[rewardBundles[i].id] = true
    end

    for _, titleInfo in ipairs(FOOD_BOX_TITLE_ITEM_ID_CONFIG) do
        for _, itemId in ipairs(titleInfo.itemIdList) do
            if rewardItemIdSet[itemId] then
                return Language[titleInfo.title]
            end
        end
    end
    return Language[FOOD_BOX_DEFAULT_TITLE]
end

function InnUtils.exitToTopicSelectionOrLevel()
    if PhaseManager:IsOpen(PhaseId.InnTopicSelection) then
        PhaseManager:ExitPhaseFastTo(PhaseId.InnTopicSelection)
    else
        PhaseManager:ExitPhaseFastTo(PhaseId.Level)
    end
end

function InnUtils.isRanchHighProductionUnLock()
    
    
    return GameInstance.player.innSystem.innLevel >= 3
end


_G.InnUtils = InnUtils
return InnUtils
