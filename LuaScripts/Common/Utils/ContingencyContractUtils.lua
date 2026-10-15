local ContingencyContractUtils = {}


ContingencyContractUtils.MAX_ROW_COUNT = 3


function ContingencyContractUtils.CreateTagFullInfosTable(gameId)
    
    local tagInfos = {}
    local allTagInfosMap = {}
    local tagKeyInfos = {}
    local tagConflictInfos = {}
    local unlockScoreInfos = {}
    local resultInfos = {
        tagInfos = tagInfos,
        allTagInfosMap = allTagInfosMap,
        tagKeyInfos = tagKeyInfos,
        tagConflictInfos = tagConflictInfos,
        unlockScoreInfos = unlockScoreInfos,
    }

    
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        return resultInfos
    end
    
    for column, ccGroupCfg in pairs(ccCfg.contractColMap) do
        for row = 1, ContingencyContractUtils.MAX_ROW_COUNT do
            
            local _, singleTagCfg = ccGroupCfg.contractRowMap:TryGetValue(row)
            
            local tagEffectCfg
            hasCfg = false
            if singleTagCfg then
                hasCfg, tagEffectCfg = Tables.ccTagTable:TryGetValue(singleTagCfg.tagId)
            end
            local info

            
            if not tagEffectCfg then
                
                info = ContingencyContractUtils._GetTagInfoTemplate()
                info.isEmpty = true
                info.tagId = -ContingencyContractUtils.GetCellIndex(column, row) 
            else
                
                info = ContingencyContractUtils.CreateTagBasicInfo(singleTagCfg, tagEffectCfg)
                if UNITY_EDITOR and ContingencyContractUtils.IsRemoveCCTagLimit then
                    info.keyId = ""
                    info.unlockStage = ""
                    info.lockIds = {}
                else
                    
                    local tagId = info.tagId
                    local keyId = info.keyId
                    if not string.isEmpty(keyId) then
                        local keyInfo = tagKeyInfos[keyId]
                        if not keyInfo then
                            keyInfo = ContingencyContractUtils._CreateKeyLockInfoFullInfo(keyId)
                            tagKeyInfos[keyId] = keyInfo
                        end
                        keyInfo.keyTags[tagId] = info
                        table.insert(keyInfo.keyTagsList, info)
                    end
                    if #info.lockIds > 0 then
                        for i, lockId in pairs(info.lockIds) do
                            local lockInfo = tagKeyInfos[lockId]
                            if not lockInfo then
                                lockInfo = ContingencyContractUtils._CreateKeyLockInfoFullInfo(lockId)
                                tagKeyInfos[lockId] = lockInfo
                            end
                            lockInfo.lockTags[tagId] = info
                        end
                        table.sort(info.lockIds)
                    end
                    
                end

                
                local conflictId = singleTagCfg.conflictId
                if not string.isEmpty(conflictId) then
                    local conflictInfo = tagConflictInfos[conflictId]
                    if not conflictInfo then
                        conflictInfo = {
                            curJoinedTag = nil,
                            conflictTagsList = {},
                        }
                        tagConflictInfos[conflictId] = conflictInfo
                    end
                    table.insert(conflictInfo.conflictTagsList, info)
                end
                

                
                if info.unlockScore > 0 then
                    local unlockScoreInfo = unlockScoreInfos[info.unlockScore]
                    if not unlockScoreInfo then
                        unlockScoreInfo = {
                            score = info.unlockScore,
                            minCol = column,
                            maxCol = column,
                        }
                        unlockScoreInfos[info.unlockScore] = unlockScoreInfo
                    else
                        unlockScoreInfo.minCol = math.min(unlockScoreInfo.minCol, column)
                        unlockScoreInfo.maxCol = math.max(unlockScoreInfo.maxCol, column)
                    end
                end
                
            end
            

            
            if tagInfos[column] == nil then
                tagInfos[column] = {}
            end
            tagInfos[column][row] = info
            allTagInfosMap[info.tagId] = info
            

            
            
            local tempInfo
            if row > 1 then
                tempInfo = tagInfos[column][row - 1]
                if tempInfo then
                    info.upTag = tempInfo
                    tempInfo.downTag = info
                end
            end
            
            if row < 3 then
                tempInfo = tagInfos[column][row + 1]
                if tempInfo then
                    info.downTag = tempInfo
                    tempInfo.upTag = info
                end
            end
            
            if tagInfos[column - 1] then
                tempInfo = tagInfos[column - 1][row]
                if tempInfo then
                    info.leftTag = tempInfo
                    tempInfo.rightTag = info
                end
            end
            
            if tagInfos[column + 1] then
                tempInfo = tagInfos[column + 1][row]
                if tempInfo then
                    info.rightTag = tempInfo
                    tempInfo.leftTag = info
                end
            end
            
        end
    end

    return resultInfos
end

function ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfos(gameId, tagIds, outTagInfos)
    local tagInfos = outTagInfos or {}
    if not tagIds then
        return tagInfos
    end

    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        return tagInfos
    end

    for _, tagId in pairs(tagIds) do
        
        local hasSingleTagCfg, singleTagCfg = ccCfg.contractMap:TryGetValue(tagId)
        local hasTagEffectCfg, tagEffectCfg = Tables.ccTagTable:TryGetValue(tagId)
        if hasSingleTagCfg and hasTagEffectCfg then
            local tagInfo = ContingencyContractUtils.CreateTagBasicInfo(singleTagCfg, tagEffectCfg)
            if tagInfo then
                table.insert(tagInfos, tagInfo)
                
                if not string.isEmpty(tagInfo.keyId) then
                    tagInfo.keyInfo = ContingencyContractUtils.CreateKeyLockBasicInfo(tagInfo.keyId)
                end
                
                tagInfo.lockInfos = {}
                if #tagInfo.lockIds > 0 then
                    table.sort(tagInfo.lockIds)
                    for _, lockId in ipairs(tagInfo.lockIds) do
                        table.insert(tagInfo.lockInfos, ContingencyContractUtils.CreateKeyLockBasicInfo(lockId))
                    end
                end
            end
        end
    end
    
    table.sort(tagInfos, function(a, b)
        return a.cellIndex < b.cellIndex
    end)
    return tagInfos
end

function ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfosByGroup(gameId, tagGroupId, outTagInfos)
    local tagIds = {}
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        return nil
    end

    local hasGroupCfg, groupCfg = ccCfg.contractGroupMap:TryGetValue(tagGroupId)
    if not hasGroupCfg then
        return nil
    end

    for _, singleTagCfg in pairs(groupCfg.contractMap) do
        table.insert(tagIds, singleTagCfg.tagId)
    end
    return ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfos(gameId, tagIds, outTagInfos)
end

function ContingencyContractUtils.CreateTagBasicInfoWithKeyLockJoinedInfos(gameId, tagIds, tagGroupIds)
    local tagInfos = {}  
    local tagGroupInfos = {} 
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        return tagInfos, tagGroupInfos
    end

    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(gameId)
    local joinedTagSet = ccData and ccData.curSelectTagSet or nil
    local joinedConflictMap = {}
    if joinedTagSet then
        for _, singleTagCfg in pairs(ccCfg.contractMap) do
            if joinedTagSet:Contains(singleTagCfg.tagId) and not string.isEmpty(singleTagCfg.conflictId) then
                joinedConflictMap[singleTagCfg.conflictId] = singleTagCfg.tagId
            end
        end
    end

    local function fillJoinedInfos(infos)
        for _, tagInfo in pairs(infos) do
            tagInfo.isJoined = joinedTagSet ~= nil and joinedTagSet:Contains(tagInfo.tagId)
            tagInfo.isConflict = not tagInfo.isJoined
                and not string.isEmpty(tagInfo.conflictId)
                and joinedConflictMap[tagInfo.conflictId] ~= nil
        end
    end

    ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfos(gameId, tagIds, tagInfos)
    fillJoinedInfos(tagInfos)

    for _, tagGroupId in pairs(tagGroupIds or {}) do
        local tagGroupInfo = {}
        ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfosByGroup(gameId, tagGroupId, tagGroupInfo)
        fillJoinedInfos(tagGroupInfo)
        table.insert(tagGroupInfos, tagGroupInfo)
    end
    return tagInfos, tagGroupInfos
end

function ContingencyContractUtils.CreateTagBasicInfoWithKeyLockJoinedInfosFilterGroup(gameId, tagIds, tagGroupIds)
    local tagInfos, tagGroupInfos = ContingencyContractUtils.CreateTagBasicInfoWithKeyLockJoinedInfos(gameId, tagIds, tagGroupIds)
    local tagInfoMap = {}
    for _, tagInfo in pairs(tagInfos) do
        tagInfo.isFromGroup = false
        tagInfoMap[tagInfo.tagId] = tagInfo
    end

    for _, tagGroupInfo in pairs(tagGroupInfos) do
        local targetTagInfo
        for _, tagInfo in pairs(tagGroupInfo) do
            tagInfo.isFromGroup = true
            if tagInfoMap[tagInfo.tagId] then
                tagInfoMap[tagInfo.tagId].isFromGroup = true
            end
            if tagInfo.isJoined then
                targetTagInfo = tagInfo
                break
            end
            if not targetTagInfo
                or tagInfo.level < targetTagInfo.level
            then
                targetTagInfo = tagInfo
            end
        end
        if targetTagInfo and not tagInfoMap[targetTagInfo.tagId] then
            table.insert(tagInfos, targetTagInfo)
            tagInfoMap[targetTagInfo.tagId] = true
            targetTagInfo.isFromGroup = true
        end
    end

    table.sort(tagInfos, function(a, b)
        return a.cellIndex < b.cellIndex
    end)
    return tagInfos
end


function ContingencyContractUtils._GetTagInfoTemplate()
    return {
        
        isEmpty = false,
        
        tagId = 0,
        level = 0,
        groupId = 0,
        conflictId = "",
        keyId = "",
        lockIds = {},
        unlockStage = "",
        canPreview = false,
        
        tagName = "",
        romanNumSuffix = "",
        tagFullName = "",
        icon = "",
        desc = "",
        
        joinedSeq = 0,
        isUnlockByStage = false, 
        hasFirstPassReward = true, 
        useKeyCount = 0,
        isJoined = false,
        isConflict = false,
        
        column = 0,
        row = 0,
        cellIndex = 0,
        upTag = nil,
        downTag = nil,
        leftTag = nil,
        rightTag = nil,
    }
end



function ContingencyContractUtils.CreateTagBasicInfo(singleTagCfg, tagEffectCfg)
    if not singleTagCfg or not tagEffectCfg then
        return nil
    end
    local info = ContingencyContractUtils._GetTagInfoTemplate()
    info.isEmpty = false
    info.tagId = singleTagCfg.tagId
    info.groupId = singleTagCfg.groupId
    info.column = singleTagCfg.column
    info.row = singleTagCfg.row
    info.conflictId = singleTagCfg.conflictId
    info.keyId = singleTagCfg.keyId
    info.unlockScore = singleTagCfg.unlockScore
    info.unlockStage = singleTagCfg.unlockActivityStage
    info.canPreview = singleTagCfg.canPreview
    info.cellIndex = ContingencyContractUtils.GetCellIndex(info.column, info.row)
    for i, lockId in pairs(singleTagCfg.lockIds) do
        table.insert(info.lockIds, lockId)
    end
    info.tagName = tagEffectCfg.name
    info.level = tagEffectCfg.score
    info.icon = tagEffectCfg.icon
    info.romanNumSuffix = tagEffectCfg.romanNumSuffix
    if string.isEmpty(info.romanNumSuffix) then
        info.tagFullName = info.tagName
    else
        info.tagFullName = string.format(Language.LUA_CONTINGENCY_CONTRACT_TAG_NAME_FORMAT, info.tagName, info.romanNumSuffix)
    end
    local formatData = CS.Beyond.Gameplay.ContingencyContractFormatData(info.tagId)
    info.desc = formatData:GetFormattedDesc()
    return info
end

function ContingencyContractUtils.CreateKeyLockBasicInfo(keyId)
    local _, keyCfg = Tables.contingencyContractKeyLockTable:TryGetValue(keyId)
    return {
        keyId = keyId,
        keyName = keyCfg.keyName,
        lockName = keyCfg.lockName,
        color = UIUtils.getColorByString(keyCfg.color),
        keyDecoImg = keyCfg.keyDecoImg,
    }
end


function ContingencyContractUtils._CreateKeyLockInfoFullInfo(keyId)
    local basicInfo = ContingencyContractUtils.CreateKeyLockBasicInfo(keyId)
    basicInfo.keyTags = {}
    basicInfo.keyTagsList = {}
    basicInfo.lockTags = {}
    basicInfo.curJoinedKeyTags = {}
    basicInfo.curJoinedLockTags = {}
    return basicInfo
end

function ContingencyContractUtils.GetCellIndex(column, row)
    return (column - 1) * ContingencyContractUtils.MAX_ROW_COUNT + row
end

function ContingencyContractUtils.GetColumnRow(luaIndex)
    local column = (luaIndex - 1) // ContingencyContractUtils.MAX_ROW_COUNT + 1
    local row = (luaIndex - 1) % ContingencyContractUtils.MAX_ROW_COUNT + 1
    return column, row
end





function ContingencyContractUtils.SortTagIdsByGridPos(gameId, tagIds)
    if not tagIds then
        return {}
    end
    local sorted = lume.copy(tagIds)

    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg or not ccCfg then
        return sorted
    end

    table.sort(sorted, function(a, b)
        local aCfg = ccCfg.contractMap[a]
        local bCfg = ccCfg.contractMap[b]
        local aIndex = ContingencyContractUtils.GetCellIndex(aCfg.column, aCfg.row)
        local bIndex = ContingencyContractUtils.GetCellIndex(bCfg.column, bCfg.row)
        if aIndex ~= bIndex then
            return aIndex < bIndex
        end
        return a < b
    end)

    return sorted
end


function ContingencyContractUtils.CreateStageToTagMap()
    local stageToTagMap = {}
    for _, contractData in pairs(Tables.contingencyContractTable) do
        for _, groupData in pairs(contractData.contractColMap) do
            for _, singleData in pairs(groupData.contractRowMap) do
                local unlockStage = singleData.unlockActivityStage
                local tagId = singleData.tagId
                if not string.isEmpty(unlockStage) then
                    if not stageToTagMap[unlockStage] then
                        stageToTagMap[unlockStage] = {}
                    end
                    table.insert(stageToTagMap[unlockStage], tagId)
                end
            end
        end
    end
    return stageToTagMap
end




ContingencyContractUtils.GenShareCodeSourceType = {
    DungeonClear = 0,   
    DungeonFail = 1,    
    Normal = 2,         
}



local _BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
local _BASE8_ALPHABET = "01234567"
local _BASE32_MAP = {}
for i = 1, #_BASE32_ALPHABET do
    _BASE32_MAP[_BASE32_ALPHABET:sub(i, i)] = i - 1
end

local function _GetShareCodeConfig(gameId)
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg or not ccCfg then
        return false, nil, 0, 0
    end

    local hasActivityCfg, ccActivityCfg = Tables.activityContingencyContractTable:TryGetValue(ccCfg.activityId)
    if not hasActivityCfg then
        return false, nil, 0, 0
    end

    local tagMaxColumn = ccActivityCfg.tagMaxColumn
    local shareCodeLength = math.ceil(tagMaxColumn * ContingencyContractUtils.MAX_ROW_COUNT / 5)
    return true, ccCfg, tagMaxColumn, shareCodeLength
end





local function _ConvertBase(digits, fromBase, toBase)
    if #digits == 0 then
        return { 0 }
    end
    
    local working = {}
    for i = 1, #digits do
        working[i] = digits[i]
    end

    local result = {}
    while #working > 0 do
        local nextWorking = {}
        local remainder = 0
        for i = 1, #working do
            local cur = remainder * fromBase + working[i]
            local quotient = math.floor(cur / toBase)
            remainder = cur % toBase
            if quotient > 0 or #nextWorking > 0 then
                table.insert(nextWorking, quotient)
            end
        end
        
        table.insert(result, 1, remainder)
        working = nextWorking
    end

    return result
end




local function _DigitsToString(digits, alphabet)
    local sb = {}
    for i = 1, #digits do
        sb[i] = alphabet:sub(digits[i] + 1, digits[i] + 1)
    end
    return table.concat(sb)
end





local function _StringToDigits(str, map)
    local digits = {}
    for i = 1, #str do
        local ch = str:sub(i, i)
        ch = ch:upper()
        local value = map[ch]
        if value == nil then
            return false, {}
        end
        table.insert(digits, value)
    end
    return true, digits
end





function ContingencyContractUtils.GenShareText(gameId, tagIds, totalScore, source)
    local suc, result = ContingencyContractUtils.GenShareCode(gameId, tagIds)
    if not suc then
        return false, ""
    end
    
    return true, ContingencyContractUtils.WrapShareText(result, totalScore, source)
end


function ContingencyContractUtils.WrapShareText(shareCode, totalScore, source)
    local resultText = string.format("<%s>", shareCode)
    if source == ContingencyContractUtils.GenShareCodeSourceType.Normal then
        resultText = string.format(Language.LUA_CONTINGENCY_CONTRACT_SHARE_CODE_WRAP_TEXT_NORMAL, totalScore, resultText)
    elseif source == ContingencyContractUtils.GenShareCodeSourceType.DungeonClear then
        resultText = string.format(Language.LUA_CONTINGENCY_CONTRACT_SHARE_CODE_WRAP_TEXT_DUNGEON_CLEAR, totalScore, resultText)
    elseif source == ContingencyContractUtils.GenShareCodeSourceType.DungeonFail then
        resultText = string.format(Language.LUA_CONTINGENCY_CONTRACT_SHARE_CODE_WRAP_TEXT_DUNGEON_FAIL, totalScore, resultText)
    end
    return resultText
end


function ContingencyContractUtils.GenShareCode(gameId, tagIds)
    local hasCfg, ccCfg, tagMaxColumn, shareCodeLength = _GetShareCodeConfig(gameId)
    if not hasCfg then
        return false, ""
    end

    
    local selectedTagSet = {}
    for _, tagId in pairs(tagIds) do
        selectedTagSet[tagId] = true
    end

    local columnValues = {}
    for column, ccGroupCfg in pairs(ccCfg.contractColMap) do
        for row = 1, ContingencyContractUtils.MAX_ROW_COUNT do
            local hasTag, singleTagCfg = ccGroupCfg.contractRowMap:TryGetValue(row)
            if hasTag and singleTagCfg and selectedTagSet[singleTagCfg.tagId] then
                local weight = 1 << (row - 1) 
                columnValues[column] = (columnValues[column] or 0) + weight
            end
        end
    end

    
    local octalDigits = {}
    for col = 1, tagMaxColumn do
        local value = columnValues[col] or 0
        
        value = lume.clamp(value, 0, 7)
        octalDigits[tagMaxColumn - col + 1] = value
    end

    
    local base32Digits = _ConvertBase(octalDigits, 8, 32)
    local shareCode = _DigitsToString(base32Digits, _BASE32_ALPHABET)
    if #shareCode < shareCodeLength then
        shareCode = string.rep("0", shareCodeLength - #shareCode) .. shareCode
    end

    return true, shareCode
end



function ContingencyContractUtils.AnalyzeShareText(gameId, shareText)
    if type(shareText) ~= "string" then
        return false, {}, 0
    end

    local leftPos = string.find(shareText, "<", 1, true)
    local rightPos = leftPos and string.find(shareText, ">", leftPos + 1, true) or nil

    
    if not leftPos or not rightPos or leftPos >= rightPos then
        return ContingencyContractUtils.AnalyzeShareCode(gameId, string.upper(shareText))
    end
    if string.find(shareText, "<", leftPos + 1, true) or string.find(shareText, ">", rightPos + 1, true) then
        return false, {}, 0
    end

    local shareCode = string.sub(shareText, leftPos + 1, rightPos - 1)
    if shareCode == "" then
        return false, {}, 0
    end

    return ContingencyContractUtils.AnalyzeShareCode(gameId, string.upper(shareCode))
end


function ContingencyContractUtils.AnalyzeShareCode(gameId, shareCode, noUnlockToast)
    local hasCfg, ccCfg, tagMaxColumn, shareCodeLength = _GetShareCodeConfig(gameId)
    if not hasCfg then
        if not noUnlockToast then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        end
        return false, {}, 0
    end

    shareCode = shareCode or ""
    local ok, base32Digits = _StringToDigits(shareCode, _BASE32_MAP)
    if not ok or #base32Digits == 0 or #shareCode ~= shareCodeLength then
        if not noUnlockToast then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        end
        return false, {}, 0
    end

    local octalDigits = _ConvertBase(base32Digits, 32, 8)
    
    local octalStr = _DigitsToString(octalDigits, _BASE8_ALPHABET)
    if #octalStr > tagMaxColumn then
        
        if not noUnlockToast then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        end
        return false, {}, 0
    end
    if #octalStr < tagMaxColumn then
        octalStr = string.rep("0", tagMaxColumn - #octalStr) .. octalStr
    end

    local resultTagIds = {}
    local totalScore = 0
    for col = 1, tagMaxColumn do
        local digitIndex = tagMaxColumn - col + 1
        local digitChar = octalStr:sub(digitIndex, digitIndex)
        local value = tonumber(digitChar) or 0
        local hasGroup, ccGroupCfg = ccCfg.contractColMap:TryGetValue(col)
        if hasGroup then
            for row = 1, ContingencyContractUtils.MAX_ROW_COUNT do
                local weight = 1 << (row - 1)
                if value & weight ~= 0 then
                    local fail = true
                    local hasTag, singleTagCfg = ccGroupCfg.contractRowMap:TryGetValue(row)
                    if hasTag then
                        local hasTagCfg, tagCfg = Tables.ccTagTable:TryGetValue(singleTagCfg.tagId)
                        if hasTagCfg then
                            table.insert(resultTagIds, singleTagCfg.tagId)
                            totalScore = totalScore + tagCfg.score
                            fail = false
                        end
                    end
                    
                    if fail then
                        if not noUnlockToast then
                            Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
                        end
                        return false, {}, 0
                    end
                end
            end
        end
    end

    local isValid = ContingencyContractUtils.CheckJoinedTagListValid(gameId, resultTagIds, noUnlockToast)
    if not isValid then
        
        return false, {}, 0
    end

    return true, resultTagIds, totalScore
end


function ContingencyContractUtils.CheckJoinedTagListValid(gameId, joinedTagIds, noUnlockToast)
    if #joinedTagIds <= 0 then
        return true
    end
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        return false
    end
    local activityId = ccCfg.activityId
    local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
    if not activityData then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        return false
    end
    
    local ccGameData = GameInstance.player.contingencyContractSystem:GetCcGameData(gameId)
    if not ccGameData then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
        return false
    end
    
    
    local joinedTagIdMap = {}
    for _, tagId in pairs(joinedTagIds) do
        joinedTagIdMap[tagId] = true
    end
    local infosTable = ContingencyContractUtils.CreateTagFullInfosTable(gameId)
    local allTagInfosMap = infosTable.allTagInfosMap
    local keyInfos = infosTable.tagKeyInfos
    local conflictInfos = infosTable.tagConflictInfos
    
    for _, tagId in pairs(joinedTagIds) do
        local tagInfo = allTagInfosMap[tagId]
        if not tagInfo then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
            return false
        end
        
        if not string.isEmpty(tagInfo.unlockStage) then
            if not ActivityUtils.isStageUnlockMultiConditionStageActivity(activityData, tagInfo.unlockStage) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
                return false
            end
        end
        
        if #tagInfo.lockIds > 0 then
            for _, lockId in pairs(tagInfo.lockIds) do
                local lockInfo = keyInfos[lockId]
                local hasKeyJoined = false
                for keyTagId, keyTagInfo in pairs(lockInfo.keyTags) do
                    if keyTagId ~= tagId and joinedTagIdMap[keyTagId] then
                        hasKeyJoined = true
                        break
                    end
                end
                if not hasKeyJoined then
                    
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NOT_VALID_TOAST)
                    return false
                end
            end
        end
        
        local conflictId = tagInfo.conflictId
        if not string.isEmpty(conflictId) then
            local conflictInfo = conflictInfos[conflictId]
            for _, conflictTagInfo in pairs(conflictInfo.conflictTagsList) do
                if conflictTagInfo.tagId ~= tagId and joinedTagIdMap[conflictTagInfo.tagId] then
                    
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SHARE_ERROR_CODE_TIP)
                    return false
                end
            end
        end
        
        if tagInfo.unlockScore > ccGameData.historyBestScore then
            if not noUnlockToast then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NOT_VALID_TOAST)
            end
            return false
        end
    end
    return true
end






function ContingencyContractUtils.GetImportWarningScores(gameId)
    local warningScore1, warningScore2 = 0, 0
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if not hasCfg then
        logger.error(string.format("危机合约，gameId[%s]配置不存在", gameId))
        return warningScore1, warningScore2
    end
    local hasActivityCfg, ccActivityCfg = Tables.activityContingencyContractTable:TryGetValue(ccCfg.activityId)
    if not hasActivityCfg then
        logger.error(string.format("危机合约，activityId[%s]配置不存在", ccCfg.activityId))
        return warningScore1, warningScore2
    end
    local scoreBandCount = ccActivityCfg.scoreBand.Count
    if scoreBandCount < 2 then
        logger.error(string.format("危机合约活动表，[Id:%s]活动配置scoreBand数量少于2！无法正确显示分数难度提示功能", ccCfg.activityId))
    else
        warningScore1 = ccActivityCfg.scoreBand[0]
        warningScore2 = ccActivityCfg.scoreBand[1]
    end
    return warningScore1, warningScore2
end



function ContingencyContractUtils.BuildImportTagResult(gameId, tagInfos)
    
    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(gameId)
    local resultSet = {}
    local conflictToTagId = {}
    local historyBestScore = ccData and ccData.historyBestScore or 0

    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(gameId)
    if ccData then
        for _, tagId in pairs(ccData.curSelectTagList) do
            resultSet[tagId] = true
            if hasCfg then
                local hasSingle, singleCfg = ccCfg.contractMap:TryGetValue(tagId)
                if hasSingle and not string.isEmpty(singleCfg.conflictId) then
                    conflictToTagId[singleCfg.conflictId] = tagId
                end
            end
        end
    end

    local allJoined = true
    local hasConflict = false
    local hasScoreLock = false
    for _, tagInfo in ipairs(tagInfos or {}) do
        if not tagInfo.isJoined then
            allJoined = false
            if tagInfo.isConflict then
                hasConflict = true
            end
            if tagInfo.unlockScore > historyBestScore then
                hasScoreLock = true
            end
            if not string.isEmpty(tagInfo.conflictId) then
                local oldId = conflictToTagId[tagInfo.conflictId]
                if oldId then
                    resultSet[oldId] = nil
                end
                conflictToTagId[tagInfo.conflictId] = tagInfo.tagId
            end
            resultSet[tagInfo.tagId] = true
        end
    end

    local mergedIds = {}
    local finalScore = 0
    for tagId, _ in pairs(resultSet) do
        table.insert(mergedIds, tagId)
        local hasTagCfg, tagEffectCfg = Tables.ccTagTable:TryGetValue(tagId)
        if hasTagCfg then
            finalScore = finalScore + tagEffectCfg.score
        end
    end

    return {
        mergedIds = mergedIds,
        finalScore = finalScore,
        allJoined = allJoined,
        hasConflict = hasConflict,
        hasScoreLock = hasScoreLock,
    }
end








function ContingencyContractUtils.TryImportTagConfirmation(gameId, importResult, warningScores, opts)
    opts = opts or {}
    local warningScore1 = warningScores and warningScores.warningScore1 or 0
    local warningScore2 = warningScores and warningScores.warningScore2 or 0
    local gotoAfter = opts.gotoAfter
    local onSend = opts.onSend
    local onGotoSelectTag = opts.onGotoSelectTag

    if importResult.allJoined then
        if gotoAfter and onGotoSelectTag then
            onGotoSelectTag()
        end
        return
    end

    if importResult.hasScoreLock then
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_ACTIVITY_CONTINGENCY_CONTRACT_JUMP_HAS_LOCKED_TAG_CONFIRM_POP_UP,
            onConfirm = function()
                if onGotoSelectTag then
                    onGotoSelectTag()
                end
            end,
        })
        return
    end

    local finalScore = importResult.finalScore
    local hasConflict = importResult.hasConflict
    local needPopup = hasConflict or finalScore >= warningScore1
    if not needPopup then
        if onSend then
            onSend(importResult.mergedIds, finalScore)
        end
        return
    end

    local contentLang
    if finalScore < warningScore1 then
        contentLang = Language.LUA_CONTINGENCY_CONTRACT_IMPORT_TAG_CONFIRM
    elseif finalScore < warningScore2 then
        contentLang = Language.LUA_CONTINGENCY_CONTRACT_IMPORT_TAG_CONFIRM_HARD
    else
        contentLang = Language.LUA_CONTINGENCY_CONTRACT_IMPORT_TAG_CONFIRM_EXTREME
    end

    local popUpArg = {
        content = string.format(contentLang, finalScore),
        onConfirm = function()
            if onSend then
                onSend(importResult.mergedIds, finalScore)
            end
        end,
    }
    if hasConflict then
        popUpArg.warningContent = Language.LUA_CONTINGENCY_CONTRACT_IMPORT_TAG_CONFLICT_WARN
    end
    Notify(MessageConst.SHOW_POP_UP, popUpArg)
end





function ContingencyContractUtils.CreateGroupToTaskMap(activityId)
    local taskInfoDict = Tables.activityConditionalMultiStageTaskConfigTable[activityId].TaskConfigMap
    local groupToTaskMap = {}
    for _, taskConfigData in pairs(taskInfoDict) do
        local groupId = taskConfigData.taskGroupId
        local taskId = taskConfigData.taskId
        if not string.isEmpty(groupId) then
            if not groupToTaskMap[groupId] then
                groupToTaskMap[groupId] = {}
            end
            table.insert(groupToTaskMap[groupId], taskId)
        end
    end
    return groupToTaskMap
end



function ContingencyContractUtils.CheckVisibilityDungeonInfoBtn()
    local dungeonId = GameInstance.dungeonManager.curDungeonId
    return not string.isEmpty(dungeonId) and DungeonUtils.isDungeonContract(dungeonId)
end

function ContingencyContractUtils.OnClickDungeonInfoBtnContingencyContract()
    local dungeonId = GameInstance.dungeonManager.curDungeonId
    local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(dungeonId)
    if not succ then
        logger.error("ContingencyContractUtils.OnClickDungeonInfoBtnContingencyContract invalid dungeonId", dungeonId)
        return
    end
    DungeonUtils.onClickDungeonInfoBtnContingencyContract(dungeonId)
end

function ContingencyContractUtils.GetTotalScoreByGamaId(gameId)
    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(gameId)
    local totalScore = 0
    if not ccData then
        return totalScore
    end
    for _, tagId in pairs(ccData.curSelectTagList) do
        local succ, tagCfg = Tables.ccTagTable:TryGetValue(tagId)
        if succ then
            totalScore = totalScore + tagCfg.score
        end
    end
    return totalScore
end

function ContingencyContractUtils.UpdateMainHudInfoBtn(mainHudView)
    local dungeonId = GameInstance.dungeonManager.curDungeonId
    local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(dungeonId)
    if not succ then
        return
    end
    mainHudView.topLeftBtns.startCountTxt.text = ContingencyContractUtils.GetTotalScoreByGamaId(dungeonId)
end


ContingencyContractUtils.IsRemoveCCTagLimit = false



_G.ContingencyContractUtils = ContingencyContractUtils
return ContingencyContractUtils