
local DoudizhuHintSolver = {}

local PATTERN = {
    None = 0,
    Single = 1,
    Pair = 2,
    Triple = 3,
    TripleOne = 4,
    TriplePair = 5,
    Plane = 6,
    PlaneSingle = 7,
    PlanePair = 8,
    Straight = 9,
    PairStraight = 10,
    FourTwo = 11,
    FourTwoPair = 12,
    Bomb = 13,
    Rocket = 14,
}

local SELECTION_RESULT = {
    Empty = "Empty",
    InvalidPattern = "InvalidPattern",
    CannotBeat = "CannotBeat",
    Playable = "Playable",
}


local LEAD_PATTERN_PRIORITY = {
    [PATTERN.Single] = 1,
    [PATTERN.Pair] = 2,
    [PATTERN.Triple] = 3,
    [PATTERN.TripleOne] = 4,
    [PATTERN.TriplePair] = 5,
    [PATTERN.Straight] = 6,
    [PATTERN.PairStraight] = 7,
    [PATTERN.Plane] = 8,
    [PATTERN.PlaneSingle] = 9,
    [PATTERN.PlanePair] = 10,
    [PATTERN.FourTwo] = 11,
    [PATTERN.FourTwoPair] = 12,
    [PATTERN.Bomb] = 13,
    [PATTERN.Rocket] = 14,
}

local JOKER_SUIT = 5
local SMALL_JOKER_RANK = 1
local BIG_JOKER_RANK = 2
local SMALL_JOKER_STRENGTH = 16
local BIG_JOKER_STRENGTH = 17
local CHAIN_MIN_RANK = 3
local CHAIN_MAX_RANK = 14

local function cloneArray(source)
    local result = {}
    for index, value in ipairs(source or {}) do
        result[index] = value
    end
    return result
end

local function normalizeStrength(rank, suit)
    if suit == JOKER_SUIT then
        if rank == SMALL_JOKER_RANK then
            return SMALL_JOKER_STRENGTH
        elseif rank == BIG_JOKER_RANK then
            return BIG_JOKER_STRENGTH
        end
        return nil
    end
    if rank >= CHAIN_MIN_RANK and rank <= 15 then
        return rank
    end
    return nil
end

local function buildCardState(cards)
    local groups = {}
    local ranks = {}
    local seenInstIds = {}
    for _, source in ipairs(cards or {}) do
        local instId = source.instId
        local rank = source.rank
        local suit = source.suit
        local strength = normalizeStrength(rank, suit)
        if type(instId) == "number" and instId ~= 0 and strength ~= nil and not seenInstIds[instId] then
            seenInstIds[instId] = true
            local group = groups[strength]
            if group == nil then
                group = {}
                groups[strength] = group
                ranks[#ranks + 1] = strength
            end
            group[#group + 1] = {
                instId = instId,
                rank = rank,
                suit = suit,
                strength = strength,
            }
        end
    end
    table.sort(ranks)
    for _, rank in ipairs(ranks) do
        table.sort(groups[rank], function(a, b)
            if a.suit == b.suit then
                return a.instId < b.instId
            end
            return a.suit < b.suit
        end)
    end
    return {
        groups = groups,
        ranks = ranks,
    }
end

local function buildInstIdSignature(instIds)
    local sorted = cloneArray(instIds)
    table.sort(sorted)
    return table.concat(sorted, ",")
end

local function compareArray(a, b)
    local count = math.min(#a, #b)
    for index = 1, count do
        if a[index] ~= b[index] then
            return a[index] < b[index] and -1 or 1
        end
    end
    if #a == #b then
        return 0
    end
    return #a < #b and -1 or 1
end

local function chooseRanks(ranks, count, onChosen, startIndex, selected)
    selected = selected or {}
    startIndex = startIndex or 1
    if #selected == count then
        onChosen(selected)
        return
    end
    local remaining = count - #selected
    local lastStart = #ranks - remaining + 1
    for index = startIndex, lastStart do
        selected[#selected + 1] = ranks[index]
        chooseRanks(ranks, count, onChosen, index + 1, selected)
        selected[#selected] = nil
    end
end

local function collectEligibleRanks(state, excludedRanks, minimumCount)
    local result = {}
    for _, rank in ipairs(state.ranks) do
        if not excludedRanks[rank] and #state.groups[rank] >= minimumCount then
            result[#result + 1] = rank
        end
    end
    return result
end

local function enumerateChains(state, minimumPerRank, minimumLength, requiredLength, onChain)
    for startRank = CHAIN_MIN_RANK, CHAIN_MAX_RANK do
        if state.groups[startRank] ~= nil and #state.groups[startRank] >= minimumPerRank then
            for endRank = startRank, CHAIN_MAX_RANK do
                local group = state.groups[endRank]
                if group == nil or #group < minimumPerRank then
                    break
                end
                local length = endRank - startRank + 1
                if length >= minimumLength and (requiredLength == nil or length == requiredLength) then
                    local ranks = {}
                    for rank = startRank, endRank do
                        ranks[#ranks + 1] = rank
                    end
                    onChain(ranks, endRank)
                end
                if requiredLength ~= nil and length >= requiredLength then
                    break
                end
            end
        end
    end
end

local function buildAllCandidates(handCards, requiredPattern, requiredChainLength)
    local state = buildCardState(handCards)
    local candidates = {}
    local seenSignatures = {}

    local function wants(patternId)
        return requiredPattern == nil or requiredPattern == patternId
    end

    local function addCandidate(patternId, mainRank, chainLength, rankSpecs, attachmentRanks)
        local instIds = {}
        for _, spec in ipairs(rankSpecs) do
            local group = state.groups[spec.rank]
            if group == nil or #group < spec.count then
                return
            end
            for index = 1, spec.count do
                instIds[#instIds + 1] = group[index].instId
            end
        end
        local signature = buildInstIdSignature(instIds)
        if seenSignatures[signature] then
            return
        end
        seenSignatures[signature] = true
        candidates[#candidates + 1] = {
            instIds = instIds,
            patternId = patternId,
            mainRank = mainRank,
            chainLength = chainLength or 1,
            cardCount = #instIds,
            attachmentRanks = cloneArray(attachmentRanks),
            signature = signature,
        }
    end

    if wants(PATTERN.Single) then
        for _, rank in ipairs(state.ranks) do
            addCandidate(PATTERN.Single, rank, 1, { { rank = rank, count = 1 } })
        end
    end
    if wants(PATTERN.Pair) then
        for _, rank in ipairs(state.ranks) do
            if #state.groups[rank] >= 2 then
                addCandidate(PATTERN.Pair, rank, 1, { { rank = rank, count = 2 } })
            end
        end
    end
    if wants(PATTERN.Triple) then
        for _, rank in ipairs(state.ranks) do
            if #state.groups[rank] >= 3 then
                addCandidate(PATTERN.Triple, rank, 1, { { rank = rank, count = 3 } })
            end
        end
    end

    if wants(PATTERN.TripleOne) or wants(PATTERN.TriplePair) then
        for _, tripleRank in ipairs(state.ranks) do
            if #state.groups[tripleRank] >= 3 then
                local excluded = { [tripleRank] = true }
                if wants(PATTERN.TripleOne) then
                    for _, wingRank in ipairs(collectEligibleRanks(state, excluded, 1)) do
                        addCandidate(PATTERN.TripleOne, tripleRank, 1, {
                            { rank = tripleRank, count = 3 },
                            { rank = wingRank, count = 1 },
                        }, { wingRank })
                    end
                end
                if wants(PATTERN.TriplePair) then
                    for _, wingRank in ipairs(collectEligibleRanks(state, excluded, 2)) do
                        addCandidate(PATTERN.TriplePair, tripleRank, 1, {
                            { rank = tripleRank, count = 3 },
                            { rank = wingRank, count = 2 },
                        }, { wingRank })
                    end
                end
            end
        end
    end

    if wants(PATTERN.Straight) then
        enumerateChains(state, 1, 5, requiredChainLength, function(chainRanks, mainRank)
            local specs = {}
            for _, rank in ipairs(chainRanks) do
                specs[#specs + 1] = { rank = rank, count = 1 }
            end
            addCandidate(PATTERN.Straight, mainRank, #chainRanks, specs)
        end)
    end
    if wants(PATTERN.PairStraight) then
        enumerateChains(state, 2, 3, requiredChainLength, function(chainRanks, mainRank)
            local specs = {}
            for _, rank in ipairs(chainRanks) do
                specs[#specs + 1] = { rank = rank, count = 2 }
            end
            addCandidate(PATTERN.PairStraight, mainRank, #chainRanks, specs)
        end)
    end

    local wantsPlane = wants(PATTERN.Plane) or wants(PATTERN.PlaneSingle) or wants(PATTERN.PlanePair)
    if wantsPlane then
        enumerateChains(state, 3, 2, requiredChainLength, function(chainRanks, mainRank)
            local coreSpecs = {}
            local excluded = {}
            for _, rank in ipairs(chainRanks) do
                coreSpecs[#coreSpecs + 1] = { rank = rank, count = 3 }
                excluded[rank] = true
            end
            if wants(PATTERN.Plane) then
                addCandidate(PATTERN.Plane, mainRank, #chainRanks, coreSpecs)
            end
            if wants(PATTERN.PlaneSingle) then
                local eligible = collectEligibleRanks(state, excluded, 1)
                chooseRanks(eligible, #chainRanks, function(wingRanks)
                    local specs = cloneArray(coreSpecs)
                    for _, rank in ipairs(wingRanks) do
                        specs[#specs + 1] = { rank = rank, count = 1 }
                    end
                    addCandidate(PATTERN.PlaneSingle, mainRank, #chainRanks, specs, wingRanks)
                end)
            end
            if wants(PATTERN.PlanePair) then
                local eligible = collectEligibleRanks(state, excluded, 2)
                chooseRanks(eligible, #chainRanks, function(wingRanks)
                    local specs = cloneArray(coreSpecs)
                    for _, rank in ipairs(wingRanks) do
                        specs[#specs + 1] = { rank = rank, count = 2 }
                    end
                    addCandidate(PATTERN.PlanePair, mainRank, #chainRanks, specs, wingRanks)
                end)
            end
        end)
    end

    if wants(PATTERN.FourTwo) or wants(PATTERN.FourTwoPair) then
        for _, fourRank in ipairs(state.ranks) do
            if #state.groups[fourRank] >= 4 then
                local excluded = { [fourRank] = true }
                if wants(PATTERN.FourTwo) then
                    local eligible = collectEligibleRanks(state, excluded, 1)
                    chooseRanks(eligible, 2, function(wingRanks)
                        addCandidate(PATTERN.FourTwo, fourRank, 1, {
                            { rank = fourRank, count = 4 },
                            { rank = wingRanks[1], count = 1 },
                            { rank = wingRanks[2], count = 1 },
                        }, wingRanks)
                    end)
                end
                if wants(PATTERN.FourTwoPair) then
                    local eligible = collectEligibleRanks(state, excluded, 2)
                    chooseRanks(eligible, 2, function(wingRanks)
                        addCandidate(PATTERN.FourTwoPair, fourRank, 1, {
                            { rank = fourRank, count = 4 },
                            { rank = wingRanks[1], count = 2 },
                            { rank = wingRanks[2], count = 2 },
                        }, wingRanks)
                    end)
                end
            end
        end
    end

    
    for _, rank in ipairs(state.ranks) do
        if #state.groups[rank] >= 4 then
            addCandidate(PATTERN.Bomb, rank, 1, { { rank = rank, count = 4 } })
        end
    end
    if state.groups[SMALL_JOKER_STRENGTH] ~= nil and state.groups[BIG_JOKER_STRENGTH] ~= nil then
        addCandidate(PATTERN.Rocket, BIG_JOKER_STRENGTH, 1, {
            { rank = SMALL_JOKER_STRENGTH, count = 1 },
            { rank = BIG_JOKER_STRENGTH, count = 1 },
        })
    end

    return candidates
end

local function findRankWithCount(state, count)
    for _, rank in ipairs(state.ranks) do
        if #state.groups[rank] == count then
            return rank
        end
    end
    return nil
end

local function analyzeExactChain(state, countPerRank, expectedLength)
    if #state.ranks ~= expectedLength then
        return nil
    end
    local previousRank = nil
    for _, rank in ipairs(state.ranks) do
        if rank > CHAIN_MAX_RANK or #state.groups[rank] ~= countPerRank
                or previousRank ~= nil and rank ~= previousRank + 1 then
            return nil
        end
        previousRank = rank
    end
    return state.ranks[#state.ranks]
end

local function findPlaneMainRank(state, chainLength)
    for startRank = CHAIN_MIN_RANK, CHAIN_MAX_RANK - chainLength + 1 do
        local valid = true
        for rank = startRank, startRank + chainLength - 1 do
            if state.groups[rank] == nil or #state.groups[rank] < 3 then
                valid = false
                break
            end
        end
        if valid then
            return startRank + chainLength - 1
        end
    end
    return nil
end

local function analyzeTarget(targetAction)
    if targetAction == nil then
        return nil
    end
    local patternId = targetAction.patternId or targetAction.pattern
    if patternId == nil or patternId == PATTERN.None then
        return nil
    end
    local cards = targetAction.cards or {}
    local state = buildCardState(cards)
    local cardCount = #cards
    local mainRank = nil
    local chainLength = 1

    if patternId == PATTERN.Single and cardCount == 1 then
        mainRank = state.ranks[1]
    elseif patternId == PATTERN.Pair and cardCount == 2 then
        mainRank = findRankWithCount(state, 2)
    elseif patternId == PATTERN.Triple and cardCount == 3 then
        mainRank = findRankWithCount(state, 3)
    elseif patternId == PATTERN.TripleOne and cardCount == 4 then
        mainRank = findRankWithCount(state, 3)
    elseif patternId == PATTERN.TriplePair and cardCount == 5 then
        mainRank = findRankWithCount(state, 3)
    elseif patternId == PATTERN.Straight and cardCount >= 5 then
        chainLength = cardCount
        mainRank = analyzeExactChain(state, 1, chainLength)
    elseif patternId == PATTERN.PairStraight and cardCount >= 6 and cardCount % 2 == 0 then
        chainLength = cardCount / 2
        mainRank = analyzeExactChain(state, 2, chainLength)
    elseif patternId == PATTERN.Plane and cardCount >= 6 and cardCount % 3 == 0 then
        chainLength = cardCount / 3
        mainRank = findPlaneMainRank(state, chainLength)
    elseif patternId == PATTERN.PlaneSingle and cardCount >= 8 and cardCount % 4 == 0 then
        chainLength = cardCount / 4
        mainRank = findPlaneMainRank(state, chainLength)
    elseif patternId == PATTERN.PlanePair and cardCount >= 10 and cardCount % 5 == 0 then
        chainLength = cardCount / 5
        mainRank = findPlaneMainRank(state, chainLength)
    elseif patternId == PATTERN.FourTwo and cardCount == 6 then
        mainRank = findRankWithCount(state, 4)
    elseif patternId == PATTERN.FourTwoPair and cardCount == 8 then
        mainRank = findRankWithCount(state, 4)
    elseif patternId == PATTERN.Bomb and cardCount == 4 then
        mainRank = findRankWithCount(state, 4)
    elseif patternId == PATTERN.Rocket and cardCount == 2
            and state.groups[SMALL_JOKER_STRENGTH] ~= nil
            and state.groups[BIG_JOKER_STRENGTH] ~= nil then
        mainRank = BIG_JOKER_STRENGTH
    end

    return {
        patternId = patternId,
        mainRank = mainRank,
        chainLength = chainLength,
        cardCount = cardCount,
        valid = mainRank ~= nil,
    }
end

local function canBeat(candidate, target)
    if target == nil then
        return true
    end
    if target.patternId == PATTERN.Rocket then
        return false
    end
    if candidate.patternId == PATTERN.Rocket then
        return true
    end
    if candidate.patternId == PATTERN.Bomb then
        if target.patternId ~= PATTERN.Bomb then
            return true
        end
        return target.valid and candidate.mainRank > target.mainRank
    end
    if target.patternId == PATTERN.Bomb or not target.valid then
        return false
    end
    return candidate.patternId == target.patternId
            and candidate.cardCount == target.cardCount
            and candidate.chainLength == target.chainLength
            and candidate.mainRank > target.mainRank
end

local function getStateCardCount(state)
    local count = 0
    for _, rank in ipairs(state.ranks) do
        count = count + #state.groups[rank]
    end
    return count
end

local function hasHigherGroup(state, groupCount, targetMainRank, attachmentCount)
    local totalCardCount = getStateCardCount(state)
    for _, rank in ipairs(state.ranks) do
        if rank > targetMainRank and #state.groups[rank] >= groupCount
                and totalCardCount - groupCount >= attachmentCount then
            return true
        end
    end
    return false
end

local function hasHigherChain(state, countPerRank, chainLength, targetMainRank, attachmentCount)
    if chainLength == nil or chainLength <= 0 then
        return false
    end
    local totalCardCount = getStateCardCount(state)
    for startRank = CHAIN_MIN_RANK, CHAIN_MAX_RANK - chainLength + 1 do
        local mainRank = startRank + chainLength - 1
        if mainRank > targetMainRank then
            local valid = true
            for rank = startRank, mainRank do
                if state.groups[rank] == nil or #state.groups[rank] < countPerRank then
                    valid = false
                    break
                end
            end
            local coreCardCount = countPerRank * chainLength
            if valid and totalCardCount - coreCardCount >= attachmentCount then
                return true
            end
        end
    end
    return false
end



function DoudizhuHintSolver.HasPotentialResponse(handCards, targetAction)
    local target = analyzeTarget(targetAction)
    if target == nil or not target.valid then
        return true
    end
    if target.patternId == PATTERN.Rocket then
        return false
    end

    local state = buildCardState(handCards)
    if getStateCardCount(state) ~= #(handCards or {}) then
        return true
    end
    local hasRocket = state.groups[SMALL_JOKER_STRENGTH] ~= nil
            and state.groups[BIG_JOKER_STRENGTH] ~= nil
    if hasRocket then
        return true
    end
    for _, rank in ipairs(state.ranks) do
        if #state.groups[rank] >= 4 then
            if target.patternId ~= PATTERN.Bomb or rank > target.mainRank then
                return true
            end
        end
    end
    if target.patternId == PATTERN.Bomb then
        return false
    end

    if target.patternId == PATTERN.Single then
        return hasHigherGroup(state, 1, target.mainRank, 0)
    elseif target.patternId == PATTERN.Pair then
        return hasHigherGroup(state, 2, target.mainRank, 0)
    elseif target.patternId == PATTERN.Triple then
        return hasHigherGroup(state, 3, target.mainRank, 0)
    elseif target.patternId == PATTERN.TripleOne then
        return hasHigherGroup(state, 3, target.mainRank, 1)
    elseif target.patternId == PATTERN.TriplePair then
        return hasHigherGroup(state, 3, target.mainRank, 2)
    elseif target.patternId == PATTERN.Straight then
        return hasHigherChain(state, 1, target.chainLength, target.mainRank, 0)
    elseif target.patternId == PATTERN.PairStraight then
        return hasHigherChain(state, 2, target.chainLength, target.mainRank, 0)
    elseif target.patternId == PATTERN.Plane then
        return hasHigherChain(state, 3, target.chainLength, target.mainRank, 0)
    elseif target.patternId == PATTERN.PlaneSingle then
        return hasHigherChain(state, 3, target.chainLength, target.mainRank,
                target.chainLength)
    elseif target.patternId == PATTERN.PlanePair then
        return hasHigherChain(state, 3, target.chainLength, target.mainRank,
                target.chainLength * 2)
    elseif target.patternId == PATTERN.FourTwo then
        return hasHigherGroup(state, 4, target.mainRank, 2)
    elseif target.patternId == PATTERN.FourTwoPair then
        return hasHigherGroup(state, 4, target.mainRank, 4)
    end
    return true
end

local function getSortClass(candidate, target)
    if target == nil then
        return LEAD_PATTERN_PRIORITY[candidate.patternId] or 100
    end
    if candidate.patternId == target.patternId then
        return 1
    elseif candidate.patternId == PATTERN.Bomb then
        return 2
    elseif candidate.patternId == PATTERN.Rocket then
        return 3
    end
    return 100
end

local function sortCandidates(candidates, target)
    table.sort(candidates, function(a, b)
        local classA = getSortClass(a, target)
        local classB = getSortClass(b, target)
        if classA ~= classB then
            return classA < classB
        end
        if a.mainRank ~= b.mainRank then
            return a.mainRank < b.mainRank
        end
        if a.chainLength ~= b.chainLength then
            return a.chainLength < b.chainLength
        end
        if a.cardCount ~= b.cardCount then
            return a.cardCount < b.cardCount
        end
        local attachmentCompare = compareArray(a.attachmentRanks, b.attachmentRanks)
        if attachmentCompare ~= 0 then
            return attachmentCompare < 0
        end
        return a.signature < b.signature
    end)
end


local function collectBombInstIds(handCards)
    local state = buildCardState(handCards)
    local bombInstIds = {}
    for _, rank in ipairs(state.ranks) do
        local group = state.groups[rank]
        if #group >= 4 then
            for _, card in ipairs(group) do
                bombInstIds[card.instId] = true
            end
        end
    end
    return bombInstIds
end

local function splitsBomb(candidate, bombInstIds)
    if candidate.patternId == PATTERN.Bomb or candidate.patternId == PATTERN.Rocket then
        return false
    end
    for _, instId in ipairs(candidate.instIds) do
        if bombInstIds[instId] then
            return true
        end
    end
    return false
end


function DoudizhuHintSolver.BuildCandidates(handCards, targetAction)
    local target = analyzeTarget(targetAction)
    local requiredPattern = target ~= nil and target.patternId or nil
    local requiredChainLength = target ~= nil and target.chainLength or nil
    local allCandidates = buildAllCandidates(handCards, requiredPattern, requiredChainLength)
    local bombInstIds = collectBombInstIds(handCards)
    local result = {}
    for _, candidate in ipairs(allCandidates) do
        if canBeat(candidate, target) and not splitsBomb(candidate, bombInstIds) then
            result[#result + 1] = candidate
        end
    end
    sortCandidates(result, target)
    return result
end



function DoudizhuHintSolver.EvaluateSelection(selectedCards, targetAction)
    local selectionCount = #(selectedCards or {})
    if selectionCount <= 0 then
        return SELECTION_RESULT.Empty, nil
    end
    local target = analyzeTarget(targetAction)
    local candidates = buildAllCandidates(selectedCards, nil, nil)
    local validCandidate = nil
    for _, candidate in ipairs(candidates) do
        if candidate.cardCount == selectionCount then
            validCandidate = validCandidate or candidate
            if canBeat(candidate, target) then
                return SELECTION_RESULT.Playable, candidate
            end
        end
    end
    if validCandidate ~= nil then
        return SELECTION_RESULT.CannotBeat, validCandidate
    end
    return SELECTION_RESULT.InvalidPattern, nil
end


function DoudizhuHintSolver.CanPlaySelection(selectedCards, targetAction)
    local result = DoudizhuHintSolver.EvaluateSelection(selectedCards, targetAction)
    return result == SELECTION_RESULT.Playable
end


function DoudizhuHintSolver.FindNextCandidate(candidates, currentInstIds)
    local count = #(candidates or {})
    if count <= 0 then
        return nil, 0
    end
    local currentSignature = buildInstIdSignature(currentInstIds or {})
    if currentSignature ~= "" then
        for index, candidate in ipairs(candidates) do
            if candidate.signature == currentSignature then
                local nextIndex = index % count + 1
                return candidates[nextIndex], nextIndex
            end
        end
    end
    return candidates[1], 1
end

local function findPlayedMainRanks(state, patternId, cardCount)
    if patternId == PATTERN.Triple or patternId == PATTERN.TripleOne or patternId == PATTERN.TriplePair then
        local rank = findRankWithCount(state, 3)
        return rank ~= nil and { rank } or nil, 3
    elseif patternId == PATTERN.FourTwo or patternId == PATTERN.FourTwoPair then
        local rank = findRankWithCount(state, 4)
        return rank ~= nil and { rank } or nil, 4
    end
    local cardsPerChainRank = patternId == PATTERN.Plane and 3
            or patternId == PATTERN.PlaneSingle and 4
            or patternId == PATTERN.PlanePair and 5
            or nil
    if cardsPerChainRank == nil or cardCount % cardsPerChainRank ~= 0 then
        return nil, 0
    end
    local chainLength = math.floor(cardCount / cardsPerChainRank)
    local topRank = findPlaneMainRank(state, chainLength)
    if topRank == nil then
        return nil, 0
    end
    local ranks = {}
    for rank = topRank - chainLength + 1, topRank do
        ranks[#ranks + 1] = rank
    end
    return ranks, 3
end



function DoudizhuHintSolver.SortPlayedInstIds(cards, patternId)
    local state = buildCardState(cards)
    local result = {}
    local mainRanks, mainCount = findPlayedMainRanks(state, patternId, #(cards or {}))
    local usedCounts = {}
    if mainRanks ~= nil then
        for index = #mainRanks, 1, -1 do
            local rank = mainRanks[index]
            local group = state.groups[rank]
            for cardIndex = #group, #group - mainCount + 1, -1 do
                result[#result + 1] = group[cardIndex].instId
            end
            usedCounts[rank] = mainCount
        end
    end
    local restRanks = cloneArray(state.ranks)
    table.sort(restRanks, function(a, b)
        if mainRanks == nil then
            local countA = #state.groups[a]
            local countB = #state.groups[b]
            if countA ~= countB then
                return countA > countB
            end
        end
        return a > b
    end)
    for _, rank in ipairs(restRanks) do
        local group = state.groups[rank]
        for cardIndex = #group - (usedCounts[rank] or 0), 1, -1 do
            result[#result + 1] = group[cardIndex].instId
        end
    end
    return result
end

DoudizhuHintSolver.Pattern = PATTERN
DoudizhuHintSolver.SelectionResult = SELECTION_RESULT
DoudizhuHintSolver.BuildInstIdSignature = buildInstIdSignature
DoudizhuHintSolver.AnalyzeTarget = analyzeTarget

return DoudizhuHintSolver
