local CardGameDoudizhuUtils = {}




local PokerSuit = CS.Beyond.Gameplay.PokerSuit
local PokerRank = CS.Beyond.Gameplay.PokerRank

local MAX_SEAT_COUNT = 3

local LANDLORD_HAND_COUNT = 20
local FARMER_HAND_COUNT = 17
local BOTTOM_CARD_COUNT = 3

local PLAY_DELAY_SECONDS = 1
local TURN_DEADLINE_MS = 15000

local TEST_CHAR_IDS = {
    "chr_0034_typhoea",
    "chr_0039_mimino",
    "chr_0040_sweetpie",
}
local TEST_NICKNAMES = {
    "XXXX",
    "XXXX",
    "XXXX",
}
local TEST_IS_AI = { false, false, true }
local TEST_HAND_REGION_IDS = {
    "doudizhuHand_self",
    "doudizhuHand_left",
    "doudizhuHand_right",
}
local TEST_PLAY_REGION_IDS = {
    "doudizhuPlay_self",
    "doudizhuPlay_left",
    "doudizhuPlay_right",
}

local TEMP_DECK_UID_BASE = 900000

local HAND_PLACEHOLDER_UID_BASE = -10000
local HAND_PLACEHOLDER_UID_SEAT_STRIDE = 100

local LIVE_TEST_CARD_UID_BASE = -90000

local function card(suit, rank)
    return { suit = suit:GetHashCode(), rank = rank:GetHashCode() }
end

local function joker(rank)
    
    return { suit = PokerSuit.None:GetHashCode(), rank = rank:GetHashCode() }
end


local PATTERN_TEST_CASES = {
    Straight = {
        pattern = CS.Proto.DDZ_PATTERN.Straight,
        cards = {
            card(PokerSuit.Spades, PokerRank.Seven),
            card(PokerSuit.Hearts, PokerRank.Six),
            card(PokerSuit.Clubs, PokerRank.Five),
            card(PokerSuit.Diamonds, PokerRank.Four),
            card(PokerSuit.Spades, PokerRank.Three),
        },
    },
    PairStraight = {
        pattern = CS.Proto.DDZ_PATTERN.PairStraight,
        cards = {
            card(PokerSuit.Spades, PokerRank.Five),
            card(PokerSuit.Hearts, PokerRank.Five),
            card(PokerSuit.Clubs, PokerRank.Four),
            card(PokerSuit.Diamonds, PokerRank.Four),
            card(PokerSuit.Spades, PokerRank.Three),
            card(PokerSuit.Hearts, PokerRank.Three),
        },
    },
    Plane = {
        pattern = CS.Proto.DDZ_PATTERN.Plane,
        cards = {
            card(PokerSuit.Spades, PokerRank.Four),
            card(PokerSuit.Hearts, PokerRank.Four),
            card(PokerSuit.Clubs, PokerRank.Four),
            card(PokerSuit.Spades, PokerRank.Three),
            card(PokerSuit.Hearts, PokerRank.Three),
            card(PokerSuit.Clubs, PokerRank.Three),
        },
    },
    PlaneSingle = {
        pattern = CS.Proto.DDZ_PATTERN.PlaneSingle,
        cards = {
            card(PokerSuit.Spades, PokerRank.Four),
            card(PokerSuit.Hearts, PokerRank.Four),
            card(PokerSuit.Clubs, PokerRank.Four),
            card(PokerSuit.Spades, PokerRank.Three),
            card(PokerSuit.Hearts, PokerRank.Three),
            card(PokerSuit.Clubs, PokerRank.Three),
            card(PokerSuit.Diamonds, PokerRank.Nine),
            card(PokerSuit.Diamonds, PokerRank.Seven),
        },
    },
    PlanePair = {
        pattern = CS.Proto.DDZ_PATTERN.PlanePair,
        cards = {
            card(PokerSuit.Spades, PokerRank.Four),
            card(PokerSuit.Hearts, PokerRank.Four),
            card(PokerSuit.Clubs, PokerRank.Four),
            card(PokerSuit.Spades, PokerRank.Three),
            card(PokerSuit.Hearts, PokerRank.Three),
            card(PokerSuit.Clubs, PokerRank.Three),
            card(PokerSuit.Spades, PokerRank.Nine),
            card(PokerSuit.Hearts, PokerRank.Nine),
            card(PokerSuit.Spades, PokerRank.Seven),
            card(PokerSuit.Hearts, PokerRank.Seven),
        },
    },
    Bomb = {
        pattern = CS.Proto.DDZ_PATTERN.Bomb,
        cards = {
            card(PokerSuit.Spades, PokerRank.Eight),
            card(PokerSuit.Hearts, PokerRank.Eight),
            card(PokerSuit.Clubs, PokerRank.Eight),
            card(PokerSuit.Diamonds, PokerRank.Eight),
        },
    },
    Rocket = {
        pattern = CS.Proto.DDZ_PATTERN.Rocket,
        cards = {
            joker(PokerRank.BigJoker),
            joker(PokerRank.LittleJoker),
        },
    },
}
local PATTERN_TEST_TYPE_NAMES = "Straight / PairStraight / Plane / PlaneSingle / PlanePair / Bomb / Rocket"



local VICTORY_TOAST_TEST_SECONDS = 2
local STATE_TOAST_TEST_CASES = {
    Landlord = { stateName = "Landlord", isVictory = false, durationKey = "bidResultPresentationMs" },
    AgainLandlord = { stateName = "AgainLandlord", isVictory = false, durationKey = "bidResultPresentationMs" },
    Reset = { stateName = "Reset", isVictory = false, durationKey = "redealPresentationMs" },
    Start = { isStart = true, durationKey = "playPresentationMs" },
    LandlordVictory = { stateName = "LandlordVictory", isVictory = true },
    PeasantryVictory = { stateName = "PeasantryVictory", isVictory = true },
}
local STATE_TOAST_TEST_TYPE_NAMES = "Landlord / AgainLandlord / Reset / Start / LandlordVictory / PeasantryVictory"


local FINAL_SETTLE_TEST_ROLE_ID_BASE = -900


local s_pendingHudAction = nil

local s_rawQuerySocialFlags = nil
local s_rawRequestAddFriend = nil

local s_testEpoch = 0
local s_localEventId = 0
local s_playTimer = -1
local s_playTimerCtrl = nil

local s_liveTestCardUids = {}

local function getHudCtrl()
    local isOpen, ctrl = UIManager:IsOpen(PanelId.CardGameLandlordHud)
    if not isOpen then
        return nil
    end
    return ctrl
end


local function isTempHud()
    return not LuaSystemManager.cardGameDoudizhuSystem.m_inGame
end

local function nextLocalEventId()
    s_localEventId = s_localEventId + 1
    return s_localEventId
end

local function clearPlayTimer()
    if s_playTimer >= 0 and s_playTimerCtrl ~= nil then
        s_playTimer = s_playTimerCtrl:_ClearTimer(s_playTimer)
    end
    s_playTimer = -1
    s_playTimerCtrl = nil
end


local function getCardPower(cardInfo)
    if cardInfo.rank == PokerRank.Ace:GetHashCode() then
        return 14
    elseif cardInfo.rank == PokerRank.Two:GetHashCode() then
        return 15
    elseif cardInfo.rank == PokerRank.LittleJoker:GetHashCode() then
        return 16
    elseif cardInfo.rank == PokerRank.BigJoker:GetHashCode() then
        return 17
    end
    return cardInfo.rank
end


local function sortUidsByPower(uids, cardInfos)
    table.sort(uids, function(a, b)
        local cardA = cardInfos[a]
        local cardB = cardInfos[b]
        local powerA = getCardPower(cardA)
        local powerB = getCardPower(cardB)
        if powerA == powerB then
            return cardA.suit > cardB.suit
        end
        return powerA > powerB
    end)
    return uids
end

local function makePlaceholderUid(hudSeat, index)
    return HAND_PLACEHOLDER_UID_BASE - hudSeat * HAND_PLACEHOLDER_UID_SEAT_STRIDE - index
end

local function buildTestDisplayInfo(hudSeat)
    return {
        isAI = TEST_IS_AI[hudSeat],
        roleId = 0,
        nickname = TEST_NICKNAMES[hudSeat],
        signature = "",
        avatarIcon = "",
        avatarFrameIcon = "",
        cardTopicId = "",
        adventureLevel = 0,
        psName = "",
    }
end


local function dealTestTable(testCase, playHudSeat)
    local cardInfos = {}
    local remainUids = {}
    local deckIndex = 0
    local addDeckCard = function(cardInfo)
        deckIndex = deckIndex + 1
        local uid = TEMP_DECK_UID_BASE + deckIndex
        cardInfos[uid] = cardInfo
        remainUids[#remainUids + 1] = uid
    end
    for _, suit in ipairs({ PokerSuit.Hearts, PokerSuit.Spades, PokerSuit.Diamonds, PokerSuit.Clubs }) do
        for rank = PokerRank.Ace:GetHashCode(), PokerRank.King:GetHashCode() do
            addDeckCard({ suit = suit:GetHashCode(), rank = rank })
        end
    end
    addDeckCard(joker(PokerRank.LittleJoker))
    addDeckCard(joker(PokerRank.BigJoker))

    local playUids = {}
    for _, patternCard in ipairs(testCase.cards) do
        for index, uid in ipairs(remainUids) do
            local cardInfo = cardInfos[uid]
            if cardInfo.suit == patternCard.suit and cardInfo.rank == patternCard.rank then
                playUids[#playUids + 1] = uid
                table.remove(remainUids, index)
                break
            end
        end
    end
    for index = #remainUids, 2, -1 do
        local swapIndex = math.random(index)
        remainUids[index], remainUids[swapIndex] = remainUids[swapIndex], remainUids[index]
    end

    local hands = {}
    local bottomUids = {}
    for hudSeat = 1, MAX_SEAT_COUNT do
        local hand = {}
        local handCount = hudSeat == 1 and LANDLORD_HAND_COUNT or FARMER_HAND_COUNT
        if hudSeat == playHudSeat then
            for _, uid in ipairs(playUids) do
                hand[#hand + 1] = uid
            end
        end
        while #hand < handCount do
            local uid = table.remove(remainUids)
            hand[#hand + 1] = uid
            if hudSeat == 1 and #bottomUids < BOTTOM_CARD_COUNT then
                bottomUids[#bottomUids + 1] = uid
            end
        end
        hands[hudSeat] = sortUidsByPower(hand, cardInfos)
    end
    return {
        cardInfos = cardInfos,
        hands = hands,
        playUids = sortUidsByPower(playUids, cardInfos),
        bottomUids = bottomUids,
    }
end


local function buildTestHudModel(tableData, handCounts, selfHandUids, turnHudSeat, canRequestPass)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    local FLOW_STATE = require_ex('LuaSystem/CardGame/Doudizhu/Flow/DoudizhuFlowDefine').State
    local bottomCards = {}
    for index, uid in ipairs(tableData.bottomUids) do
        local cardInfo = tableData.cardInfos[uid]
        bottomCards[index] = {
            instId = uid,
            suit = cardInfo.suit,
            rank = cardInfo.rank,
            pokerSuit = cardInfo.suit,
            pokerRank = cardInfo.rank,
            style = "None",
        }
    end
    local model = {
        inGame = true,
        phaseReady = true,
        phaseActive = true,
        headlessPresentation = false,
        hideControllerHints = false,
        presentationBusy = false,
        flowState = FLOW_STATE.Playing,
        turnHudSeat = turnHudSeat,
        landlordHudSeat = 1,
        deadlineMs = system:GetCountDownNowMs() + TURN_DEADLINE_MS,
        windowSeqId = nextLocalEventId(),
        canBid = false,
        
        canPlay = turnHudSeat == 1,
        canRequestPass = turnHudSeat == 1 and canRequestPass,
        hasPlayableResponse = true,
        operationPending = false,
        isRecovering = false,
        hasClientFlowError = false,
        bottomInstIds = tableData.bottomUids,
        bottomCards = bottomCards,
        settlementWinnerCamp = nil,
        seats = {},
    }
    for hudSeat = 1, MAX_SEAT_COUNT do
        local seatModel = {
            serverSeatId = hudSeat,
            isLandlord = hudSeat == 1,
            handCardsCount = handCounts[hudSeat],
            displayInfo = buildTestDisplayInfo(hudSeat),
        }
        if hudSeat == 1 then
            seatModel.handCardsInstIds = selfHandUids
        else
            seatModel.isAI = TEST_IS_AI[hudSeat]
            seatModel.nickname = TEST_NICKNAMES[hudSeat]
        end
        model.seats[hudSeat] = seatModel
    end
    return model
end


local function playTestCards(tableData, hudSeat, epoch, onDone)
    local cardSystem = LuaSystemManager.cardGameSystem
    local playRegionId = TEST_PLAY_REGION_IDS[hudSeat]
    local playUids = tableData.playUids
    cardSystem:RecycleRegionCards(playRegionId)
    if hudSeat ~= 1 then
        local handRegion = cardSystem:GetRegion(TEST_HAND_REGION_IDS[hudSeat])
        local handCount = handRegion:GetCardCount()
        for index, uid in ipairs(playUids) do
            local sourceCard = handRegion:GetCardAtIndex(handCount - index + 1)
            cardSystem:ReplaceCardUid(sourceCard.uid, uid)
            local cardInfo = tableData.cardInfos[uid]
            cardSystem:SetCardData(uid, cardInfo.suit, cardInfo.rank, false)
        end
    end
    if not cardSystem:MoveCardsByUidToRegion(playUids, playRegionId, true, true, function()
        if epoch == s_testEpoch then
            onDone()
        end
    end) then
        logger.error("CardGameDoudizhuUtils.PanelTestActionToast: 出牌移动失败")
    end
end



local function simulateOnTempHud(ctrl, testCase, hudSeat)
    local epoch = s_testEpoch
    local cardSystem = LuaSystemManager.cardGameSystem
    for _, regionId in ipairs(TEST_HAND_REGION_IDS) do
        if cardSystem:GetRegion(regionId) == nil then
            logger.error("CardGameDoudizhuUtils.PanelTestActionToast: 牌桌 Region 未就绪")
            return
        end
    end
    
    cardSystem:ClearRuntimeCards()

    local tableData = dealTestTable(testCase, hudSeat)
    local handCounts = {}
    for seat = 1, MAX_SEAT_COUNT do
        local regionId = TEST_HAND_REGION_IDS[seat]
        local hand = tableData.hands[seat]
        handCounts[seat] = #hand
        for index, uid in ipairs(hand) do
            if seat == 1 then
                cardSystem:CreateCard(regionId, uid)
                local cardInfo = tableData.cardInfos[uid]
                cardSystem:SetCardData(uid, cardInfo.suit, cardInfo.rank, true)
            else
                cardSystem:CreateCard(regionId, makePlaceholderUid(seat, index))
            end
        end
        cardSystem:RelayoutRegion(regionId, false)
    end

    
    local beforeModel = buildTestHudModel(tableData, handCounts, tableData.hands[1], hudSeat, false)
    ctrl:RefreshHud(beforeModel, {
        kind = require_ex('LuaSystem/CardGameDoudizhuSystem').HudCommandKind.Rebuild,
        showBottomBack = false,
    })

    s_playTimerCtrl = ctrl
    s_playTimer = ctrl:_StartTimer(PLAY_DELAY_SECONDS, function()
        s_playTimer = -1
        s_playTimerCtrl = nil
        if epoch ~= s_testEpoch then
            return
        end
        local HudCommandKind = require_ex('LuaSystem/CardGameDoudizhuSystem').HudCommandKind
        local PresentationType = CS.Beyond.Gameplay.DoudizhuPresentationType
        local playSet = {}
        for _, uid in ipairs(tableData.playUids) do
            playSet[uid] = true
        end
        local afterSelfHand = {}
        for _, uid in ipairs(tableData.hands[1]) do
            if not playSet[uid] then
                afterSelfHand[#afterSelfHand + 1] = uid
            end
        end
        local afterCounts = {}
        for seat = 1, MAX_SEAT_COUNT do
            afterCounts[seat] = handCounts[seat] - (seat == hudSeat and #tableData.playUids or 0)
        end
        local nextHudSeat = hudSeat % MAX_SEAT_COUNT + 1
        
        local afterModel = buildTestHudModel(tableData, afterCounts, afterSelfHand, nextHudSeat, true)
        local command = {
            kind = HudCommandKind.PlayCards,
            localEventId = nextLocalEventId(),
            presentationType = PresentationType.PlayAction,
            hudSeat = hudSeat,
            pattern = testCase.pattern,
            viewModel = afterModel,
        }
        ctrl:RefreshHud(afterModel, command)
        ctrl:PlayProgressToast(command)
        playTestCards(tableData, hudSeat, epoch, function()
            ctrl:PlayHudCommand(command, function()
                if epoch ~= s_testEpoch then
                    return
                end
                ctrl:RefreshHud(afterModel, {
                    kind = HudCommandKind.TurnChanged,
                    localEventId = nextLocalEventId(),
                    presentationType = PresentationType.PlayTurn,
                    hudSeat = nextHudSeat,
                })
            end)
        end)
    end, true)
end


local function playOnLiveHud(ctrl, testCase, hudSeat)
    local cardSystem = LuaSystemManager.cardGameSystem
    for _, uid in ipairs(s_liveTestCardUids) do
        if cardSystem:GetRuntimeCard(uid) ~= nil then
            cardSystem:RecycleCardByUid(uid, false)
        end
    end
    s_liveTestCardUids = {}

    local handRegionId = TEST_HAND_REGION_IDS[hudSeat]
    local playRegionId = TEST_PLAY_REGION_IDS[hudSeat]
    if cardSystem:GetRegion(handRegionId) == nil or cardSystem:GetRegion(playRegionId) == nil then
        logger.error("CardGameDoudizhuUtils.PanelTestActionToast: 牌桌 Region 未就绪")
        return
    end
    cardSystem:RecycleRegionCards(playRegionId)
    local isSelf = hudSeat == 1
    for index, cardInfo in ipairs(testCase.cards) do
        local uid = LIVE_TEST_CARD_UID_BASE - index
        if cardSystem:CreateCard(handRegionId, uid) == nil then
            logger.error("CardGameDoudizhuUtils.PanelTestActionToast: 创牌失败, uid=" .. tostring(uid))
            return
        end
        cardSystem:SetCardData(uid, cardInfo.suit, cardInfo.rank, isSelf)
        s_liveTestCardUids[index] = uid
    end
    cardSystem:RelayoutRegion(handRegionId, false)

    ctrl:PlayProgressToast({
        kind = require_ex('LuaSystem/CardGameDoudizhuSystem').HudCommandKind.PlayCards,
        hudSeat = hudSeat,
        pattern = testCase.pattern,
    })
    cardSystem:MoveCardsByUidToRegion(s_liveTestCardUids, playRegionId, true, true)
end

local function runTest(ctrl, testCase, hudSeat)
    s_testEpoch = s_testEpoch + 1
    clearPlayTimer()
    if isTempHud() then
        simulateOnTempHud(ctrl, testCase, hudSeat)
    else
        playOnLiveHud(ctrl, testCase, hudSeat)
    end
end

local function openTempHud()
    local system = LuaSystemManager.cardGameDoudizhuSystem
    
    if system.scene == nil then
        local CardGameSceneDoudizhu = require_ex('LuaSystem/CardGame/CardGameSceneDoudizhu').CardGameSceneDoudizhu
        system.scene = CardGameSceneDoudizhu()
        local seatChars = {}
        for hudSeat, charId in ipairs(TEST_CHAR_IDS) do
            seatChars[hudSeat] = { charId = charId, showPotentialFx = false }
        end
        system.scene:Init(seatChars)
    end
    PhaseManager:OpenPhase(PhaseId.CardGameDoudizhuHud, {}, function()
        local pending = s_pendingHudAction
        s_pendingHudAction = nil
        local ctrl = getHudCtrl()
        if ctrl == nil or pending == nil then
            return
        end
        pending(ctrl)
    end)
end


local function runWithHud(action)
    local ctrl = getHudCtrl()
    if ctrl ~= nil then
        action(ctrl)
        return
    end
    local isOpening = s_pendingHudAction ~= nil
    s_pendingHudAction = action
    if not isOpening then
        openTempHud()
    end
end

local function isFinalSettleTestRoleId(roleId)
    return type(roleId) == "number" and roleId < FINAL_SETTLE_TEST_ROLE_ID_BASE
            and roleId >= FINAL_SETTLE_TEST_ROLE_ID_BASE - MAX_SEAT_COUNT
end



local function hookFinalSettleSocial()
    if s_rawQuerySocialFlags ~= nil then
        return
    end
    s_rawQuerySocialFlags = CardGameUtils.QueryPlayerSocialFlags
    s_rawRequestAddFriend = CardGameUtils.RequestAddFriend
    CardGameUtils.QueryPlayerSocialFlags = function(player)
        if not isFinalSettleTestRoleId(player.roleId) then
            return s_rawQuerySocialFlags(player)
        end
        return {
            isInBlackList = false,
            isFriend = false,
            isFriendRequestSent = false,
            canAddFriend = true,
        }
    end
    CardGameUtils.RequestAddFriend = function(roleId, ...)
        if isFinalSettleTestRoleId(roleId) then
            return true
        end
        return s_rawRequestAddFriend(roleId, ...)
    end
end

local function closeTempHud()
    s_testEpoch = s_testEpoch + 1
    s_pendingHudAction = nil
    clearPlayTimer()
    local cardSystem = LuaSystemManager.cardGameSystem
    for _, uid in ipairs(s_liveTestCardUids) do
        if cardSystem:GetRuntimeCard(uid) ~= nil then
            cardSystem:RecycleCardByUid(uid, false)
        end
    end
    s_liveTestCardUids = {}
    if not isTempHud() then
        return
    end
    if PhaseManager:IsOpenAndValid(PhaseId.CardGameDoudizhuHud) then
        PhaseManager:ExitPhaseFast(PhaseId.CardGameDoudizhuHud)
    end
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system.scene then
        
        cardSystem:ClearRuntimeCards()
        system.scene:Unload()
        system.scene = nil
    end
end







CardGameDoudizhuUtils.PanelTestActionToast = function(testType, hudSeat)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    if testType == "Close" then
        closeTempHud()
        return
    end
    local testCase = PATTERN_TEST_CASES[testType]
    if testCase == nil then
        logger.error("CardGameDoudizhuUtils.PanelTestActionToast: 未知 testType=" .. tostring(testType)
                .. "，可选：" .. PATTERN_TEST_TYPE_NAMES .. " / Close")
        return
    end
    hudSeat = hudSeat or 1
    if TEST_PLAY_REGION_IDS[hudSeat] == nil then
        logger.error("CardGameDoudizhuUtils.PanelTestActionToast: hudSeat 只能是 1~3, hudSeat=" .. tostring(hudSeat))
        return
    end

    runWithHud(function(ctrl)
        runTest(ctrl, testCase, hudSeat)
    end)
end




CardGameDoudizhuUtils.PanelTestStateToast = function(testType)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    if testType == "Close" then
        closeTempHud()
        return
    end
    local testCase = STATE_TOAST_TEST_CASES[testType]
    if testCase == nil then
        logger.error("CardGameDoudizhuUtils.PanelTestStateToast: 未知 testType=" .. tostring(testType)
                .. "，可选：" .. STATE_TOAST_TEST_TYPE_NAMES .. " / Close")
        return
    end
    runWithHud(function(ctrl)
        local durationSeconds = testCase.durationKey ~= nil
                and Tables.LandLoardConst[testCase.durationKey] / 1000
                or VICTORY_TOAST_TEST_SECONDS
        if testCase.isStart then
            ctrl:_ShowStartStateToast(durationSeconds)
        else
            ctrl:_ShowStateToast(testCase.stateName, testCase.isVictory, durationSeconds)
        end
    end)
end





CardGameDoudizhuUtils.PanelTestFinalSettle = function(isOpen, isFarmerWin)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    if isFarmerWin == nil then
        isFarmerWin = true
    end
    local panelId = PanelId.CardGameLandlordFinalSettleRank
    if not isOpen then
        if UIManager:IsOpen(panelId) then
            UIManager:Close(panelId)
        end
        return
    end
    hookFinalSettleSocial()

    local winnerCamp = isFarmerWin and CS.Proto.DDZ_CAMP.Farmer or CS.Proto.DDZ_CAMP.Landlord
    
    local seatOrder = isFarmerWin and { 2, 3, 1 } or { 1, 2, 3 }
    local playerInfos = {}
    local selfInfo
    for index, hudSeat in ipairs(seatOrder) do
        local displayInfo = buildTestDisplayInfo(hudSeat)
        
        displayInfo.isAI = true
        local isSelf = hudSeat == 1
        local camp = isSelf and CS.Proto.DDZ_CAMP.Landlord or CS.Proto.DDZ_CAMP.Farmer
        local player = {
            seatIndex = hudSeat,
            roleId = isSelf and 0 or FINAL_SETTLE_TEST_ROLE_ID_BASE - hudSeat,
            isSelf = isSelf,
            
            isAI = true,
            charId = TEST_CHAR_IDS[hudSeat],
            displayInfo = displayInfo,
            camp = camp,
            rank = index,
            isWinner = camp == winnerCamp,
        }
        playerInfos[index] = player
        if isSelf then
            selfInfo = player
        end
    end
    local arg = {
        winnerCamp = winnerCamp,
        selfInfo = selfInfo,
        playerInfos = playerInfos,
    }

    local isPanelOpen, ctrl = UIManager:IsOpen(panelId)
    if isPanelOpen then
        ctrl.m_arg = arg
        ctrl:_RefreshAllUI()
        return
    end
    UIManager:Open(panelId, arg)
end





_G.CardGameDoudizhuUtils = CardGameDoudizhuUtils
return CardGameDoudizhuUtils
