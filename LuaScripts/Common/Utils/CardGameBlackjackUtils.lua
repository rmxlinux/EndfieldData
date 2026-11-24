local CardGameBlackjackUtils = {}



CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME = 5




CardGameBlackjackUtils.CLIENT_PHASE = {
    
    WaitStart = "WaitStart",
    
    Dealing = "Dealing",
    
    
    InitialRelic = "InitialRelic",
    
    Battle = "Battle",
    
    RoundSettle = "RoundSettle",
    
    RoundEndWait = "RoundEndWait",
    
    Idle = "Idle",
    
    Shop = "Shop",
    
    ShopWait = "ShopWait",
    
    FinalSettle = "FinalSettle",
}


CardGameBlackjackUtils.BATTLE_SUB_PHASE = {
    None = "None",
    
    WaitPick = "WaitPick",
    
    ShowCard = "ShowCard",
}

CardGameBlackjackUtils.CARD_ANI_SEE_WAIT_TIME = 0.3
CardGameBlackjackUtils.ShopItemBuyState = {
    Gain = "Gain",
    Buy = "Buy",
    Max = "Max",
    NoMoney = "NoMoney",
}


CardGameBlackjackUtils.RelicPreviewType = {
    
    GainSlot = "GainSlot",
    
    Insert = "Insert",
}

CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType = {
    Relic = 1,
    HandZone = 2,
    CardDeck = 3,
}

CardGameBlackjackUtils.IsBlackjackRelicShopGoodsType = function(slotType)
    local goodsType = CS.Beyond.GEnums.BlackJackCardGameShopGoodsSlotType.__CastFrom(slotType)
    local isCardPack = goodsType == CS.Beyond.GEnums.BlackJackCardGameShopGoodsSlotType.CardPack
        or goodsType == CS.Beyond.GEnums.BlackJackCardGameShopGoodsSlotType.CardChange
    return not isCardPack
end

CardGameBlackjackUtils.GetBlackjackRelicCfgByIntId = function(relicIntId)
    local _, relicId = CS.Beyond.Cfg.Tables.blackjackRelicIdToStr:TryGetValue(relicIntId)
    local _, relicCfg = Tables.cardGameRelicInfoTable:TryGetValue(relicId)
    return relicCfg, relicId
end


CardGameBlackjackUtils.GetBlackjackCardChangeCfgByIntId = function(changeIntId)
    local _, changeId = CS.Beyond.Cfg.Tables.blackjackCardChangeIdToStr:TryGetValue(changeIntId)
    local _, changeCfg = Tables.cardGameCardChangTable:TryGetValue(changeId)
    return changeCfg, changeId
end


CardGameBlackjackUtils.GetBlackjackShopGoodsCfgByIntId = function(goodsIntId)
    local _, goodsId = CS.Beyond.Cfg.Tables.blackjackShopGoodsIdToStr:TryGetValue(goodsIntId)
    local _, shopGoodsCfg = Tables.cardGameShopGoodsTable:TryGetValue(goodsId)
    return shopGoodsCfg, goodsId
end


CardGameBlackjackUtils.InitGoldMoneyCell = function(moneyCell, count)
    moneyCell:InitMoneyCell(Tables.cardGameBlackjackConst.goldItemId, false, false, false, nil, nil, {
        skipDefaultRefresh = true,
        getDisplayText = function()
            return count
        end,
        getTipsExtraArgs = function()
            return { customOwnCount = count }
        end,
    })
end

CardGameBlackjackUtils.PlayChangeValueTips = function(uiCtrl, valueChangeTips, valueChangeType, value, onPlayEnd)
    if valueChangeType == CardGameUtils.ValueChangeType.Add then
        valueChangeTips.stateController:SetState("Add")
        valueChangeTips.valueTxt.text = "+" .. value
    elseif valueChangeType == CardGameUtils.ValueChangeType.Sub then
        valueChangeTips.stateController:SetState("Sub")
        valueChangeTips.valueTxt.text = "-" .. value
    else
        valueChangeTips.stateController:SetState("ChangeTo")
        valueChangeTips.valueTxt.text = value
    end
    valueChangeTips.gameObject:SetActive(true)
    valueChangeTips.animationWrapper:PlayInAnimation(function()
        valueChangeTips.animationWrapper:PlayOutAnimation(function()
            valueChangeTips.gameObject:SetActive(false)
            if onPlayEnd then
                onPlayEnd()
            end
        end)
    end)
end



CardGameBlackjackUtils.PlayHpCellsChangeAni = function(hpCellCache, firstIndex, lastIndex, isAdd, onPlayEnd)
    local hasRegisteredEnd = false
    for index = firstIndex, lastIndex do
        local hpCell = hpCellCache:Get(index)
        if hpCell then
            local callback = nil
            if not hasRegisteredEnd then
                hasRegisteredEnd = true
                callback = onPlayEnd
            end
            if isAdd then
                hpCell.animationWrapper:PlayInAnimation(callback)
            else
                hpCell.animationWrapper:PlayOutAnimation(callback)
            end
        end
    end
    if not hasRegisteredEnd and onPlayEnd then
        onPlayEnd()
    end
end


CardGameBlackjackUtils.SetCardDeckSuitCountTxt = function(uiText)
    local CardSuit = CS.Beyond.GEnums.BlackJackCardGameCardSuit
    local counts = LuaSystemManager.cardGameBlackjackSystem:GetSelfDeckSuitCounts()
    
    uiText:SetAndResolveTextStyle(string.format(Language.LUA_CARD_GAME_BLACKJACK_HAND_CARD_DECK_SUIT,
        counts[CardSuit.Spades:ToInt()],
        counts[CardSuit.Hearts:ToInt()],
        counts[CardSuit.Clubs:ToInt()],
        counts[CardSuit.Diamonds:ToInt()]))
end


CardGameBlackjackUtils.GetSuitDisplayName = function(suit)
    local CardSuit = CS.Beyond.GEnums.BlackJackCardGameCardSuit
    local suitEnum = CardSuit.__CastFrom(suit)
    if suitEnum == CardSuit.Spades then
        return Language.LUA_CARD_GAME_BLACKJACK_SUIT_NAME_SPADES
    elseif suitEnum == CardSuit.Hearts then
        return Language.LUA_CARD_GAME_BLACKJACK_SUIT_NAME_HEARTS
    elseif suitEnum == CardSuit.Clubs then
        return Language.LUA_CARD_GAME_BLACKJACK_SUIT_NAME_CLUBS
    elseif suitEnum == CardSuit.Diamonds then
        return Language.LUA_CARD_GAME_BLACKJACK_SUIT_NAME_DIAMONDS
    end
    return ""
end


CardGameBlackjackUtils.ENHANCE_EFFECT_REPORT_ICON = {
    [CS.Beyond.GEnums.BlackJackCardGameCardEnhance.Colorful:ToInt()] = "icon_change_enhance_colored",
    [CS.Beyond.GEnums.BlackJackCardGameCardEnhance.Mining:ToInt()] = "icon_change_enhance_gold",
    [CS.Beyond.GEnums.BlackJackCardGameCardEnhance.TransBack:ToInt()] = "icon_change_enhance_reverse",
    [CS.Beyond.GEnums.BlackJackCardGameCardEnhance.Royal:ToInt()] = "icon_change_enhance_crown",
}


CardGameBlackjackUtils.SetPokerCellSelectState = function(cell, isSelect, playAni)
    cell.stateController:SetState(isSelect and "Select" or "Unselect")
    local animationWrapper = cell.animationWrapper
    animationWrapper:ClearTween()
    if isSelect then
        if playAni then
            animationWrapper:PlayInAnimation()
        else
            animationWrapper:SampleToInAnimationEnd()
        end
    else
        if playAni then
            animationWrapper:PlayOutAnimation()
        else
            animationWrapper:SampleToOutAnimationEnd()
        end
    end
end




CardGameBlackjackUtils.MAX_SEAT_COUNT = 4




CardGameBlackjackUtils.ELIMINATED_SORT_RANK = 99



CardGameBlackjackUtils.ERR_CHOOSE_BY_SERVER = 6252


CardGameBlackjackUtils.CARD_REGION_DECK = "deck"
CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX = "playerHandZone_"
CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX = "playerCardDeck_"
CardGameBlackjackUtils.CARD_REGION_CARD_CHANGE_ANI = "CardChangeAniNodeCardLayout"
CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_PRE = "CardReplaceAniNodePreCardLayout"
CardGameBlackjackUtils.CARD_REGION_CARD_REPLACE_ANI_NOW = "CardReplaceAniNodeNowCardLayout"






CardGameBlackjackUtils.PLACEHOLDER_UID_BASE = 1000000
CardGameBlackjackUtils.PLACEHOLDER_UID_SEAT_STRIDE = 10000

CardGameBlackjackUtils.HUD_CARD_CHANGE_TEST_UID_BASE = 8000000

CardGameBlackjackUtils.CARD_CHANGE_ANI_TEMP_UID_BASE = 9000000

CardGameBlackjackUtils.CHOOSE_KEY = {
    Pick = "Pick",
    Shop = "Shop",
    InitialRelic = "InitialRelic",
    ChangeCard = "ChangeCard",
    GainCard = "GainCard",
    ChooseAttr = "ChooseAttr",
    PreviewCard = "PreviewCard",
    DestroyCard = "DestroyCard",
}



CardGameBlackjackUtils.INTRO_KEY = "intro_blackjack"


CardGameBlackjackUtils.TriggerPhaseEventForGuide = function(eventType)
    local system = LuaSystemManager.cardGameBlackjackSystem
    CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.Trigger(system:GetGameRound(), system:GetGameTurn(), eventType)
end



local CardChangeType = CS.Beyond.GEnums.BlackJackCardGameCardChangeType
local CardSuit = CS.Beyond.GEnums.BlackJackCardGameCardSuit
local CardEnhance = CS.Beyond.GEnums.BlackJackCardGameCardEnhance
local ChooseAttributeType = CS.Beyond.GEnums.BlackJackCardGameChooseAttributeType

local function getPanelCtrl(panelId)
    local isOpen, ctrl = UIManager:IsOpen(panelId)
    if not isOpen then
        return nil
    end
    return ctrl
end

CardGameBlackjackUtils.PanelTest = function(panelName, param)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    local panelId = PanelId[panelName]

    
    
    local function buildTestDisplayInfo(nickname, isAI)
        return {
            isAI = isAI == true,
            roleId = 0,
            nickname = nickname or "",
            signature = "",
            avatarIcon = "",
            avatarFrameIcon = "",
            cardTopicId = "",
            adventureLevel = 0,
            psName = "",
        }
    end

    local function buildTestShopPlayerInfo(seatIndex, state, nickname, isSelf, isAI)
        local info = buildTestDisplayInfo(nickname, isAI)
        info.seatIndex = seatIndex
        info.state = state
        info.isSelf = isSelf
        return info
    end

    
    
    if panelId == PanelId.CardGameBlackjackHud then
        local system = LuaSystemManager.cardGameBlackjackSystem
        
        system.isHudReady = true
        local charIds = {
            "chr_0034_typhoea",
            "chr_0039_mimino",
            "chr_0040_sweetpie",
            "chr_0037_minghe",
        }
        if system.scene == nil then
            local CardGameSceneBlackjack = require_ex('LuaSystem/CardGame/CardGameSceneBlackjack').CardGameSceneBlackjack
            system.scene = CardGameSceneBlackjack()
            local seatChars = {}
            for i, charId in ipairs(charIds) do
                seatChars[i] = { charId = charId, showPotentialFx = true }
            end
            system.scene:Init(seatChars)
        end
        PhaseManager:OpenPhase(PhaseId.CardGameBlackjackHud, {
            charIds = charIds,
            onPickCard = function(pick)
                Notify(MessageConst.SHOW_TOAST, pick and "PanelTest：抽牌" or "PanelTest：停牌")
            end,
        }, function()
            local isOpen, ctrl = UIManager:IsOpen(PanelId.CardGameBlackjackHud)
            if not isOpen or ctrl == nil then
                return
            end

            ctrl.view.randomSeatNode:Stop(false)
            ctrl.view.hudMain.gameObject:SetActive(true)
            ctrl.m_scene:SetRoomCameraPos(CardGameUtils.RoomCameraPosType.Normal)

            ctrl:SetTitleRoundText(string.format(Language.LUA_CARD_GAME_BLACKJACK_HUD_TITLE_ROUND, 2))
            ctrl:SetTitleTurnText(string.format(Language.LUA_CARD_GAME_BLACKJACK_HUD_TITLE_TURN, 3))

            local playerInfos = {
                { seatIndex = 1, nickname = "PanelTest 自己", isAI = false },
                { seatIndex = 2, nickname = "PanelTest 玩家2", isAI = false },
                { seatIndex = 3, nickname = "PanelTest AI", isAI = true },
                { seatIndex = 4, nickname = "PanelTest 玩家4", isAI = false },
            }
            local relicInfos = {
                {
                    { relicIcon = "item_card_blackjack_baojun" },
                    { relicIcon = "item_card_blackjack_bianxing" },
                },
                {
                    { relicIcon = "item_card_blackjack_bingyuanwanbei" },
                },
                {},
                {},
            }
            local points = { 18, 20, 12, 0 }
            local extraPoints = { 3, 0, 0, 0 }
            local maxPoints = { 21, 21, 21, 21 }
            local deckCounts = { 18, 20, 16, 22 }
            local golds = { 120, 80, 40, 20 }
            local hps = { 4, 3, 2, 0 }
            local pointStates = { "PointNormal", "PointNormal", "PointNormal", "PointBust" }
            local optStates = { "PickCard", "ChoiceComplete", "StopPickCard", "GameOut" }

            for hudSeat = 1, 4 do
                local info = buildTestDisplayInfo(playerInfos[hudSeat].nickname, playerInfos[hudSeat].isAI)
                info.seatIndex = playerInfos[hudSeat].seatIndex
                ctrl:RefreshPlayerInfoBasicUI(hudSeat, info)
                if hudSeat == 1 then
                    ctrl:RefreshSelfMoneyNum(golds[hudSeat])
                end
                if system.scene then
                    system.scene:RefreshPlayerHpNum(hudSeat, hps[hudSeat])
                end
                ctrl:RefreshTableInfoCardDeckCount(hudSeat, deckCounts[hudSeat])
                ctrl:RefreshTableInfoPointInfoPoint(hudSeat, points[hudSeat], maxPoints[hudSeat])
                ctrl:RefreshTableInfoPointInfoExtraPoint(hudSeat, extraPoints[hudSeat])
                ctrl:ShowTableInfoPointInfoExtraPoint(hudSeat, extraPoints[hudSeat] ~= 0)
                ctrl:SetTableInfoPointInfoState(hudSeat, pointStates[hudSeat])
                ctrl:RefreshPlayerInfoOptInfo(hudSeat, optStates[hudSeat])
                ctrl:ShowPlayerInfoOptInfo(hudSeat, true)
                ctrl:RefreshLightBarColorByState(hudSeat, optStates[hudSeat])
            end

            ctrl:RefreshPlayerInfoGameSign(1, "StartFlag")
            ctrl:ShowPlayerInfoGameSign(1, true)
            ctrl:ShowPlayerInfoGameSign(2, false)
            ctrl:ShowPlayerInfoGameSign(3, false)
            ctrl:RefreshPlayerInfoGameSign(4, "Watch")
            ctrl:ShowPlayerInfoGameSign(4, true)
            ctrl:RefreshPlayerInfoSelfIsWatch(false)
            ctrl:ShowOtherPlayerInfoAIIcon(2, false)
            ctrl:ShowOtherPlayerInfoAIIcon(3, true)
            ctrl:ShowOtherPlayerInfoAIIcon(4, false)

            ctrl:SetTableInfoCountDownProgress(12, 30)
            ctrl:ShowTableInfoCountDown(true)
            ctrl:ShowTableInfoCenterArrow(true, 1)
            ctrl:RefreshTableInfoTableTipsState("OpenCard")
            ctrl:ShowTableInfoTableTips(true)
            ctrl:ShowOptInfoNode(true)
            ctrl:SetOptInfoBtnsSelectable(false)
            ctrl:RefreshOptInfoTipsBustProbability(35)
            ctrl:ShowOptInfoPickCardBtnTipsNode(true)
            if param then
                param()
            end
        end)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackShopMain then
        local arg = nil
        local selectedIndex = 1
        local shopMainInfo = {
            isInitialRelic = false,
            roundNum = 2,
            gold = 120,
            refreshCost = 20,
            deckCardNum = 24,
            outScoreCap = 21,
            outAdditionalPoints = 3,
            hp = 4,
            maxHp = 10,
            relicInfos = {
                { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = true },
            },
            maxRelicSlotNum = 5,
            extraRelicNum = 1,
            countDownRemain = 60,
            countDownTotal = 90,
        }
        local items = {
            {
                isRelic = true,
                name = "测试遗物：金币护符",
                desc = "用于无对局数据时测试遗物商品表现。",
                icon = "item_card_blackjack_bingyuanwanbei",
                rarity = 3,
                isExtraRelic = false,
                canRefresh = false,
                isPin = false,
                hasPrice = true,
                buyState = CardGameBlackjackUtils.ShopItemBuyState.Buy,
                curPrice = 30,
                originPrice = 40,
            },
            {
                isRelic = false,
                name = "测试卡包：强化包",
                desc = "用于测试卡包商品表现、价格和购买按钮状态。",
                icon = "icon_blackjack_card_pack_buff",
                isPin = true,
                buyState = CardGameBlackjackUtils.ShopItemBuyState.Buy,
                curPrice = 20,
                originPrice = 20,
            },
            {
                isRelic = true,
                name = "测试遗物：槽位已满",
                desc = "用于测试遗物满槽不可购买状态。",
                icon = "item_card_blackjack_bingyuanwanbei",
                rarity = 4,
                isExtraRelic = true,
                canRefresh = false,
                isPin = false,
                hasPrice = true,
                buyState = CardGameBlackjackUtils.ShopItemBuyState.Max,
                curPrice = 60,
                originPrice = 60,
            },
            {
                isRelic = false,
                name = "测试卡包：金币不足",
                desc = "用于测试金币不足状态。",
                icon = "icon_blackjack_card_pack_big",
                isPin = false,
                buyState = CardGameBlackjackUtils.ShopItemBuyState.NoMoney,
                curPrice = 999,
                originPrice = 999,
            },
        }

        local refreshSelectList = function()
            local ctrl = getPanelCtrl(PanelId.CardGameBlackjackShopSelect)
            if ctrl ~= nil then
                ctrl:RefreshItemList(arg.items, arg.selectedIndex)
            end
        end

        arg = {
            isChooseInitRelic = false,
            shopMainInfo = shopMainInfo,
            items = items,
            selectedIndex = selectedIndex,
            playerInfos = {
                buildTestShopPlayerInfo(1, "Wait", "PanelTest 自己", true, false),
                buildTestShopPlayerInfo(2, "Ready", "PanelTest 玩家2", false, false),
                buildTestShopPlayerInfo(3, "Off", "PanelTest AI", false, true),
                buildTestShopPlayerInfo(4, "Wait", "PanelTest 玩家4", false, false),
            },
            onSelect = function(index)
                
                selectedIndex = selectedIndex == index and 0 or index
                arg.selectedIndex = selectedIndex
                refreshSelectList()
            end,
            onBuy = function(index)
                Notify(MessageConst.SHOW_TOAST, string.format("PanelTest：点击购买第 %d 个商品", index))
            end,
            onRefresh = function(index)
                Notify(MessageConst.SHOW_TOAST, string.format("PanelTest：点击刷新第 %d 个商品", index))
            end,
            onPin = function(index)
                local item = arg.items[index]
                if item == nil then
                    return
                end
                item.isPin = not item.isPin
                local ctrl = getPanelCtrl(PanelId.CardGameBlackjackShopSelect)
                local cell = ctrl ~= nil and ctrl:GetItemCell(index) or nil
                if cell ~= nil then
                    cell:SetPinState(item.isPin)
                end
            end,
            onRefreshShop = function()
                Notify(MessageConst.SHOW_TOAST, "PanelTest：点击刷新商店")
            end,
            onFinishShop = function()
                if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackShopMain) then
                    PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackShopMain)
                end
            end,
            onSkip = function()
                Notify(MessageConst.SHOW_TOAST, "PanelTest：点击跳过")
            end,
        }

        PhaseManager:OpenPhase(PhaseId.CardGameBlackjackShopMain, arg)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackPlayerGameInfo then
        local arg = {
            canShowHandZone = true,
            defaultPage = CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck,
            playerBasicInfo = {
                seatIndex = 1,
                nickname = "PanelTest 玩家",
                displayInfo = buildTestDisplayInfo("PanelTest 玩家", true),
                isSelf = true,
            },
            curHp = 4,
            maxHp = 10,
            curMoney = 120,
            curPoint = 18,
            maxPoint = 21,
            extraPoint = 3,
            relicInfos = {
                {
                    name = "测试遗物：金币护符",
                    desc = "用于测试普通遗物展示。",
                    icon = "item_card_blackjack_bingyuanwanbei",
                    rarity = 3,
                    isExtraRelic = false,
                },
                {
                    name = "测试遗物：额外插槽",
                    desc = "用于测试不占位遗物展示。",
                    icon = "item_card_blackjack_bingyuanwanbei",
                    rarity = 4,
                    isExtraRelic = true,
                },
            },
            relicNum = 2,
            extraRelicNum = 1,
            maxRelicNum = 2,
            handZonePokerInfos = {
                {
                    suit = CardSuit.Hearts:ToInt(),
                    rank = 1,
                    style = CardGameUtils.GetCardStyleByEnhance(1),
                    enhance = 1,
                    realRank = 11,
                    isTemporary = false,
                    isInHandZone = true,
                    isDelete = false,
                },
                {
                    suit = CardSuit.Spades:ToInt(),
                    rank = 13,
                    style = CardGameUtils.GetCardStyleByEnhance(2),
                    enhance = 2,
                    realRank = 10,
                    isTemporary = true,
                    isInHandZone = true,
                    isDelete = false,
                },
            },
            maxHandZoneCount = 4,
            deckPokerInfos = {
                totalCardNum = 8,
                temporaryCardNum = 2,
                heartsPokerInfos = {
                    {
                        suit = CardSuit.Hearts:ToInt(),
                        rank = 1,
                        style = CardGameUtils.GetCardStyleByEnhance(1),
                        enhance = 1,
                        realRank = 11,
                        isTemporary = false,
                        isInHandZone = true,
                        isDelete = false,
                    },
                    {
                        suit = CardSuit.Hearts:ToInt(),
                        rank = 7,
                        style = CardGameUtils.GetCardStyleByEnhance(1),
                        enhance = 1,
                        realRank = 7,
                        isTemporary = false,
                        isInHandZone = false,
                        isDelete = false,
                    },
                },
                spadesPokerInfos = {
                    {
                        suit = CardSuit.Spades:ToInt(),
                        rank = 13,
                        style = CardGameUtils.GetCardStyleByEnhance(2),
                        enhance = 2,
                        realRank = 10,
                        isTemporary = true,
                        isInHandZone = true,
                        isDelete = false,
                    },
                    {
                        suit = CardSuit.Spades:ToInt(),
                        rank = 9,
                        style = CardGameUtils.GetCardStyleByEnhance(1),
                        enhance = 1,
                        realRank = 9,
                        isTemporary = false,
                        isInHandZone = false,
                        isDelete = true,
                    },
                },
                diamondsPokerInfos = {
                    {
                        suit = CardSuit.Diamonds:ToInt(),
                        rank = 5,
                        style = CardGameUtils.GetCardStyleByEnhance(3),
                        enhance = 3,
                        realRank = 5,
                        isTemporary = true,
                        isInHandZone = false,
                        isDelete = false,
                    },
                    {
                        suit = CardSuit.Diamonds:ToInt(),
                        rank = 12,
                        style = CardGameUtils.GetCardStyleByEnhance(1),
                        enhance = 1,
                        realRank = 10,
                        isTemporary = false,
                        isInHandZone = false,
                        isDelete = false,
                    },
                },
                clubsPokerInfos = {
                    {
                        suit = CardSuit.Clubs:ToInt(),
                        rank = 3,
                        style = CardGameUtils.GetCardStyleByEnhance(1),
                        enhance = 1,
                        realRank = 3,
                        isTemporary = false,
                        isInHandZone = false,
                        isDelete = false,
                    },
                    {
                        suit = CardSuit.Clubs:ToInt(),
                        rank = 10,
                        style = CardGameUtils.GetCardStyleByEnhance(4),
                        enhance = 4,
                        realRank = 10,
                        isTemporary = false,
                        isInHandZone = false,
                        isDelete = false,
                    },
                },
            },
        }
        local pokerInfo = arg.deckPokerInfos.heartsPokerInfos[1]
        for i = 1, 15 do
            table.insert(arg.deckPokerInfos.heartsPokerInfos, pokerInfo)
        end

        PhaseManager:OpenPhase(PhaseId.CardGameBlackjackPlayerGameInfo, arg, function()
            local ctrl = getPanelCtrl(PanelId.CardGameBlackjackPlayerGameInfo)
            if ctrl == nil then
                return
            end
            
            ctrl:ShowCountDown(true)
            ctrl.view.countDownNode.stateController:SetState("Normal")
            ctrl:SetCountDown(45, 60)
        end)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackRoundSettle then
        local arg = nil
        local settleInfos = {
            {
                seatIndex = 1,
                memberId = 1,
                nickname = "PanelTest 未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 未出局", false),
                isSelf = true,
                isAi = false,
                rank = 1,
                displayRank = 1,
                point = 20,
                extraPoint = 3,
                isBust = false,
                gameOutRound = 0,
                hp = 4,
                maxHp = 10,
                hpDelta = 0,
                moneyNum = 120,
                moneyDelta = 35,
                handZoneCardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 1, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 9, style = CardGameUtils.GetCardStyleByEnhance(2) },
                },
            },
            {
                seatIndex = 2,
                memberId = 2,
                nickname = "PanelTest 爆牌未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 爆牌未出局", false),
                isSelf = false,
                isAi = false,
                rank = 2,
                displayRank = 2,
                point = 25,
                extraPoint = 0,
                isBust = true,
                gameOutRound = 0,
                hp = 2,
                maxHp = 10,
                hpDelta = 1,
                moneyNum = 80,
                moneyDelta = -10,
                handZoneCardInfos = {
                    { suit = CardSuit.Diamonds:ToInt(), rank = 13, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Clubs:ToInt(), rank = 8, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Hearts:ToInt(), rank = 7, style = CardGameUtils.GetCardStyleByEnhance(3) },
                },
            },
            {
                seatIndex = 3,
                memberId = 3,
                nickname = "PanelTest 本轮爆牌出局",
                displayInfo = buildTestDisplayInfo("PanelTest 本轮爆牌出局", true),
                isSelf = false,
                isAi = true,
                rank = 3,
                displayRank = 3,
                point = 26,
                extraPoint = 0,
                isBust = true,
                gameOutRound = 2,
                hp = 0,
                maxHp = 10,
                hpDelta = 2,
                moneyNum = 40,
                moneyDelta = -15,
                handZoneCardInfos = {
                    { suit = CardSuit.Spades:ToInt(), rank = 12, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Diamonds:ToInt(), rank = 9, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Clubs:ToInt(), rank = 5, style = CardGameUtils.GetCardStyleByEnhance(4) },
                },
            },
            {
                
                seatIndex = 3,
                memberId = 5,
                nickname = "PanelTest 本轮未爆牌出局",
                displayInfo = buildTestDisplayInfo("PanelTest 本轮未爆牌出局", false),
                isSelf = false,
                isAi = false,
                rank = 3,
                displayRank = 3,
                point = 15,
                extraPoint = 2,
                isBust = false,
                gameOutRound = 2,
                hp = 0,
                maxHp = 5,
                hpDelta = 1,
                moneyNum = 30,
                moneyDelta = -5,
                handZoneCardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 6, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 9, style = CardGameUtils.GetCardStyleByEnhance(1) },
                },
            },
            {
                seatIndex = 4,
                memberId = 4,
                nickname = "PanelTest 早已出局",
                displayInfo = buildTestDisplayInfo("PanelTest 早已出局", false),
                isSelf = false,
                isAi = false,
                rank = 4,
                displayRank = 4,
                point = 0,
                extraPoint = 0,
                isBust = false,
                gameOutRound = 1,
                hp = 0,
                maxHp = 10,
                hpDelta = 0,
                moneyNum = 20,
                moneyDelta = 0,
                handZoneCardInfos = {},
            },
        }
        arg = {
            curRound = 2,
            settleInfos = settleInfos,
            selfSettleInfo = settleInfos[1],
            isWatch = false,
            isGameOver = false,
            roundSettleFinish = function()
                Notify(MessageConst.SHOW_TOAST, "PanelTest：小回合结算倒计时结束")
            end,
        }
        UIManager:Open(PanelId.CardGameBlackjackRoundSettle, arg)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackFinalSettle then
        local settleInfos = {
            {
                seatIndex = 1,
                nickname = "PanelTest 未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 未出局", true),
                charId = "chr_0034_typhoea",
                isSelf = true,
                isAI = false,
                isBust = false,
                gameOutRound = 0,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 1,
                moneyNum = 180,
                maxRoundScore = 21,
                relicInfos = {
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = true },
                },
                relicSlotMaxLimit = 3,
                cardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 1, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 13, style = CardGameUtils.GetCardStyleByEnhance(2) },
                    { suit = CardSuit.Diamonds:ToInt(), rank = 7, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Clubs:ToInt(), rank = 10, style = CardGameUtils.GetCardStyleByEnhance(4) },
                },
            },
            {
                seatIndex = 2,
                nickname = "PanelTest 爆牌未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 爆牌未出局", true),
                charId = "chr_0039_mimino",
                isSelf = false,
                isAI = false,
                isBust = true,
                gameOutRound = 0,
                isFriend = true,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 2,
                moneyNum = 140,
                maxRoundScore = 19,
                relicInfos = {
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                },
                relicSlotMaxLimit = 2,
                cardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 8, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 9, style = CardGameUtils.GetCardStyleByEnhance(1) },
                },
            },
            {
                seatIndex = 3,
                nickname = "PanelTest 本轮出局",
                displayInfo = buildTestDisplayInfo("PanelTest 本轮出局", true),
                charId = "chr_0040_sweetpie",
                isSelf = false,
                isAI = true,
                isBust = true,
                gameOutRound = 2,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 3,
                moneyNum = 70,
                maxRoundScore = 17,
                relicInfos = {},
                relicSlotMaxLimit = 2,
                cardInfos = {
                    { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = CardGameUtils.GetCardStyleByEnhance(3) },
                },
            },
            {
                seatIndex = 4,
                nickname = "PanelTest 早已出局",
                displayInfo = buildTestDisplayInfo("PanelTest 早已出局", true),
                charId = "chr_0037_minghe",
                isSelf = false,
                isAI = false,
                isBust = false,
                gameOutRound = 1,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = true,
                rank = 4,
                moneyNum = 20,
                maxRoundScore = 0,
                relicInfos = {},
                relicSlotMaxLimit = 2,
                cardInfos = {},
            },
        }
        PhaseManager:OpenPhase(PhaseId.CardGameBlackjackFinalSettle, {
            settleInfos = settleInfos,
            selfSettleInfo = settleInfos[1],
        })
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackFinalSettleRank then
        local settleInfos = {
            {
                seatIndex = 1,
                nickname = "PanelTest 未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 未出局", true),
                charId = "chr_0034_typhoea",
                isSelf = true,
                isAI = false,
                isBust = false,
                gameOutRound = 0,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 1,
                moneyNum = 180,
                maxRoundScore = 21,
                relicInfos = {
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = true },
                },
                relicSlotMaxLimit = 3,
                cardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 1, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 13, style = CardGameUtils.GetCardStyleByEnhance(2) },
                    { suit = CardSuit.Diamonds:ToInt(), rank = 7, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Clubs:ToInt(), rank = 10, style = CardGameUtils.GetCardStyleByEnhance(4) },
                },
            },
            {
                seatIndex = 2,
                nickname = "PanelTest 爆牌未出局",
                displayInfo = buildTestDisplayInfo("PanelTest 爆牌未出局", true),
                charId = "chr_0038_purrche",
                isSelf = false,
                isAI = false,
                isBust = true,
                gameOutRound = 0,
                isFriend = true,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 2,
                moneyNum = 140,
                maxRoundScore = 19,
                relicInfos = {
                    { relicIcon = "item_card_blackjack_bingyuanwanbei", isExtraRelic = false },
                },
                relicSlotMaxLimit = 2,
                cardInfos = {
                    { suit = CardSuit.Hearts:ToInt(), rank = 8, style = CardGameUtils.GetCardStyleByEnhance(1) },
                    { suit = CardSuit.Spades:ToInt(), rank = 9, style = CardGameUtils.GetCardStyleByEnhance(1) },
                },
            },
            {
                seatIndex = 3,
                nickname = "PanelTest 本轮出局",
                displayInfo = buildTestDisplayInfo("PanelTest 本轮出局", true),
                charId = "chr_0035_liino",
                isSelf = false,
                isAI = true,
                isBust = true,
                gameOutRound = 2,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = false,
                rank = 3,
                moneyNum = 70,
                maxRoundScore = 17,
                relicInfos = {},
                relicSlotMaxLimit = 2,
                cardInfos = {
                    { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = CardGameUtils.GetCardStyleByEnhance(3) },
                },
            },
            {
                seatIndex = 4,
                nickname = "PanelTest 早已出局",
                displayInfo = buildTestDisplayInfo("PanelTest 早已出局", true),
                charId = "chr_0036_jsspsi",
                isSelf = false,
                isAI = false,
                isBust = false,
                gameOutRound = 1,
                isFriend = false,
                isFriendRequestSent = false,
                canAddFriend = true,
                rank = 4,
                moneyNum = 20,
                maxRoundScore = 0,
                relicInfos = {},
                relicSlotMaxLimit = 2,
                cardInfos = {},
            },
        }
        PhaseManager:OpenPhase(PhaseId.CardGameBlackjackFinalSettleRank, {
            settleInfos = settleInfos,
            selfSettleInfo = settleInfos[1],
        })
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackSelectChange then
        
        local arg = {
            chooseType = ChooseAttributeType.Suit,
            selectedSuit = CardSuit.None:ToInt(),
        }
        UIManager:Open(PanelId.CardGameBlackjackSelectChange, arg)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackOpenCardPack then
        local selectedIndexes = {}
        local arg = {
            desc = "PanelTest：开卡包选牌，可多选候选牌。",
            maxSelectNum = 1,
            cardPackIcon = "icon_blackjack_card_pack_big",
            pokerInfo = {
                {
                    suit = CardSuit.Hearts:ToInt(),
                    rank = 1,
                    style = CardGameUtils.GetCardStyleByEnhance(1),
                },
                {
                    suit = CardSuit.Spades:ToInt(),
                    rank = 13,
                    style = CardGameUtils.GetCardStyleByEnhance(2),
                },
                {
                    suit = CardSuit.Diamonds:ToInt(),
                    rank = 7,
                    style = CardGameUtils.GetCardStyleByEnhance(3),
                },
                {
                    suit = CardSuit.Clubs:ToInt(),
                    rank = 10,
                    style = CardGameUtils.GetCardStyleByEnhance(4),
                },
                {
                    suit = CardSuit.Hearts:ToInt(),
                    rank = 5,
                    style = CardGameUtils.GetCardStyleByEnhance(1),
                },
            },
            onSelectPoker = function(index, isSelect)
                selectedIndexes[index] = isSelect and true or nil
            end,
        }
        UIManager:Open(PanelId.CardGameBlackjackOpenCardPack, arg)
        return
    end
    

    
    if panelId == PanelId.CardGameBlackjackShopChangeCard then
        local selectedChangeTypeIndex = 1
        local selectedPokerIndex = 0
        local arg = {
            changeTypeInfos = {
                {
                    icon = "icon_card_change_heart",
                    name = "变红桃",
                    desc = "将选中的牌变化为红桃。",
                },
                {
                    icon = "icon_card_change_seven",
                    name = "变7",
                    desc = "将选中的牌点数变化为7。",
                },
                {
                    icon = "icon_card_change_crown",
                    name = "变王室",
                    desc = "给选中的牌添加王室强化。",
                },
                {
                    icon = "icon_card_change_delete",
                    name = "删除",
                    desc = "从牌组中移除选中的牌。",
                },
            },
            pokerInfo = {
                {
                    suit = CardSuit.Hearts:ToInt(),
                    rank = 1,
                    style = CardGameUtils.GetCardStyleByEnhance(1),
                },
                {
                    suit = CardSuit.Spades:ToInt(),
                    rank = 13,
                    style = CardGameUtils.GetCardStyleByEnhance(2),
                },
                {
                    suit = CardSuit.Diamonds:ToInt(),
                    rank = 7,
                    style = CardGameUtils.GetCardStyleByEnhance(3),
                },
                {
                    suit = CardSuit.Clubs:ToInt(),
                    rank = 10,
                    style = CardGameUtils.GetCardStyleByEnhance(4),
                },
            },
            onSelectChangeType = function(index)
                selectedChangeTypeIndex = index
                Notify(MessageConst.SHOW_TOAST, string.format("PanelTest：选择变化 %d", selectedChangeTypeIndex))
            end,
            onSelectPoker = function(index)
                selectedPokerIndex = index
                Notify(MessageConst.SHOW_TOAST, string.format("PanelTest：选择牌 %d", selectedPokerIndex))
            end,
        }
        UIManager:Open(PanelId.CardGameBlackjackShopChangeCard, arg)
        return
    end
    
end

CardGameBlackjackUtils.PanelTestClose = function(panelName)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    local panelId = PanelId[panelName]
    if panelId == nil then
        return
    end

    if panelId == PanelId.CardGameBlackjackHud then
        if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackHud) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackHud)
            local system = LuaSystemManager.cardGameBlackjackSystem
            
            system:_ClearChooseStack()
            
            system.m_effectReportInfo = nil
            system.isHudReady = false
            if system.scene then
                system.scene:Unload()
                system.scene = nil
            end
            return
        end
    elseif panelId == PanelId.CardGameBlackjackShopMain then
        if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackShopMain) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackShopMain)
            return
        end
    elseif panelId == PanelId.CardGameBlackjackPlayerGameInfo then
        if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackPlayerGameInfo) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackPlayerGameInfo)
            return
        end
    elseif panelId == PanelId.CardGameBlackjackFinalSettle then
        if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackFinalSettle) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackFinalSettle)
            return
        end
    elseif panelId == PanelId.CardGameBlackjackFinalSettleRank then
        if PhaseManager:IsOpenAndValid(PhaseId.CardGameBlackjackFinalSettleRank) then
            PhaseManager:ExitPhaseFast(PhaseId.CardGameBlackjackFinalSettleRank)
            return
        end
    end

    if UIManager:IsOpen(panelId) then
        UIManager:Close(panelId)
    end
end




CardGameBlackjackUtils.PanelTestCardChangeRankEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardChangeEffectForShop: 商店未打开")
        return
    end

    local style = CardGameUtils.GetCardStyleByEnhance(1)
    local changeInfo = {
        cardChangeType = CardChangeType.Rank,
        valueChangeType = CardGameUtils.ValueChangeType.ChangeTo,
        rank = 7,
    }
    local preCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 10, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }
    local nowCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 7, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 7, style = style },
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlaySetCardRankForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackUtils.PanelTestCardChangeSuitEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardChangeSuitEffectForShop: 商店未打开")
        return
    end

    local style = CardGameUtils.GetCardStyleByEnhance(1)
    local changeInfo = {
        cardChangeType = CardChangeType.Suit,
        suit = CardSuit.Diamonds,
    }
    local preCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }
    local nowCardInfos = {
        { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = style },
        { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = style },
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlaySetCardSuitForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackUtils.PanelTestCardChangeEnhanceEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardChangeEnhanceEffectForShop: 商店未打开")
        return
    end

    local preStyle = CardGameUtils.GetCardStyleByEnhance(CardEnhance.None:ToInt())
    local nowStyle = CardGameUtils.GetCardStyleByEnhance(CardEnhance.Colorful:ToInt())
    local changeInfo = {
        cardChangeType = CardChangeType.Enhance,
        enhance = CardEnhance.Colorful,
    }
    local preCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = preStyle },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = preStyle },
    }
    local nowCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = nowStyle },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = nowStyle },
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayApplyEnhanceForShop(changeInfo, preCardInfos, nowCardInfos)
end

CardGameBlackjackUtils.PanelTestFuseUnenhancedNumbersEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestFuseUnenhancedNumbersEffectForShop: 商店未打开")
        return
    end

    local style = CardGameUtils.GetCardStyleByEnhance(CardEnhance.None:ToInt())
    local preCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 4, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }
    local nowCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 9, style = style },
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayFuseUnenhancedNumbersForShop(preCardInfos, nowCardInfos)
end





local function playHudCardChangeTest(logName, isFromHandZone, hudSeat, changeInfo, preCardInfos, nowCardInfos, playFn)
    if getPanelCtrl(PanelId.CardGameBlackjackHud) == nil then
        logger.error("CardGameBlackjackUtils." .. logName .. ": HUD未打开")
        return
    end

    local fromHandZone = isFromHandZone == true
    local createdUids = {}
    local recycleCreatedCards = function()
        local cardSystem = LuaSystemManager.cardGameSystem
        if cardSystem == nil then
            return
        end
        for i = 1, #createdUids do
            local uid = createdUids[i]
            if cardSystem:GetRuntimeCard(uid) ~= nil then
                cardSystem:RecycleCardByUid(uid, false)
            end
        end
        createdUids = {}
    end

    if fromHandZone then
        local cardSystem = LuaSystemManager.cardGameSystem
        local regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
        if cardSystem == nil or cardSystem:GetRegion(regionId) == nil then
            logger.error("CardGameBlackjackUtils." .. logName .. ": 手牌区未就绪")
            return
        end
        for i = 1, #preCardInfos do
            local uid = CardGameBlackjackUtils.HUD_CARD_CHANGE_TEST_UID_BASE + i
            if cardSystem:GetRuntimeCard(uid) ~= nil then
                cardSystem:RecycleCardByUid(uid, false)
            end
            local card = cardSystem:CreateCard(regionId, uid)
            if card == nil then
                logger.error("CardGameBlackjackUtils." .. logName .. ": 手牌区创牌失败, uid=" .. tostring(uid))
                recycleCreatedCards()
                return
            end
            cardSystem:SetPokerData(uid, preCardInfos[i].suit, preCardInfos[i].rank, preCardInfos[i].style, true)
            preCardInfos[i].uid = uid
            createdUids[#createdUids + 1] = uid
        end
        cardSystem:RelayoutRegion(regionId, false)
    end

    local system = LuaSystemManager.cardGameBlackjackSystem
    playFn(system, hudSeat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
    system.m_aniQueue:EnqueueFinallyAction(recycleCreatedCards)
end

CardGameBlackjackUtils.PanelTestCardChangeRankEffectForHud = function(isFromHandZone, hudSeat)
    local style = CardGameUtils.GetCardStyleByEnhance(1)
    playHudCardChangeTest("PanelTestCardChangeRankEffectForHud", isFromHandZone, hudSeat, {
        cardChangeType = CardChangeType.Rank,
        valueChangeType = CardGameUtils.ValueChangeType.ChangeTo,
        rank = 7,
    }, {
        { suit = CardSuit.Hearts:ToInt(), rank = 10, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }, {
        { suit = CardSuit.Hearts:ToInt(), rank = 7, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 7, style = style },
    }, function(system, seat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
        system:_PlaySetCardRankForHud(seat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
    end)
end

CardGameBlackjackUtils.PanelTestCardChangeSuitEffectForHud = function(isFromHandZone, hudSeat)
    local style = CardGameUtils.GetCardStyleByEnhance(1)
    playHudCardChangeTest("PanelTestCardChangeSuitEffectForHud", isFromHandZone, hudSeat, {
        cardChangeType = CardChangeType.Suit,
        suit = CardSuit.Diamonds,
    }, {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }, {
        { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = style },
        { suit = CardSuit.Diamonds:ToInt(), rank = 5, style = style },
    }, function(system, seat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
        system:_PlaySetCardSuitForHud(seat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
    end)
end

CardGameBlackjackUtils.PanelTestCardChangeEnhanceEffectForHud = function(isFromHandZone, hudSeat)
    local preStyle = CardGameUtils.GetCardStyleByEnhance(CardEnhance.None:ToInt())
    local nowStyle = CardGameUtils.GetCardStyleByEnhance(CardEnhance.Royal:ToInt())
    playHudCardChangeTest("PanelTestCardChangeEnhanceEffectForHud", isFromHandZone, hudSeat, {
        cardChangeType = CardChangeType.Enhance,
        enhance = CardEnhance.Colorful,
    }, {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = preStyle },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = preStyle },
    }, {
        { suit = CardSuit.Hearts:ToInt(), rank = 5, style = nowStyle },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = nowStyle },
    }, function(system, hudSeat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
        system:_PlayApplyEnhanceForHud(hudSeat, fromHandZone, changeInfo, preCardInfos, nowCardInfos)
    end)
end

CardGameBlackjackUtils.PanelTestFuseUnenhancedNumbersEffectForHud = function(hudSeat)
    hudSeat = hudSeat or 1
    if getPanelCtrl(PanelId.CardGameBlackjackHud) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestFuseUnenhancedNumbersEffectForHud: HUD未打开")
        return
    end

    local style = CardGameUtils.GetCardStyleByEnhance(CardEnhance.None:ToInt())
    local preCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 4, style = style },
        { suit = CardSuit.Spades:ToInt(), rank = 5, style = style },
    }
    local nowCardInfos = {
        { suit = CardSuit.Hearts:ToInt(), rank = 9, style = style },
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayFuseUnenhancedNumbersForHud(hudSeat, preCardInfos, nowCardInfos)
end







CardGameBlackjackUtils.PanelTestCardCreateEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardCreateEffectForShop: 商店未打开")
        return
    end

    local cardInfo = {
        suit = CardSuit.Hearts:ToInt(),
        rank = 10,
        style = CardGameUtils.GetCardStyleByEnhance(1),
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayCreateCardForShop(cardInfo)
end

CardGameBlackjackUtils.PanelTestCardDeleteEffectForShop = function()
    if getPanelCtrl(PanelId.CardGameBlackjackShopMain) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardDeleteEffectForShop: 商店未打开")
        return
    end

    local cardInfo = {
        suit = CardSuit.Hearts:ToInt(),
        rank = 10,
        style = CardGameUtils.GetCardStyleByEnhance(1),
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayRemoveCardForShop(cardInfo)
end



CardGameBlackjackUtils.PanelTestCardCreateEffectForHud = function(hudSeat)
    if getPanelCtrl(PanelId.CardGameBlackjackHud) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardCreateEffectForHud: HUD未打开")
        return
    end

    hudSeat = hudSeat or 1
    local cardInfo = {
        suit = CardSuit.Hearts:ToInt(),
        rank = 10,
        style = CardGameUtils.GetCardStyleByEnhance(1),
    }
    LuaSystemManager.cardGameBlackjackSystem:_PlayCreateCardForHud(hudSeat, cardInfo, 0, {})
end


CardGameBlackjackUtils.PanelTestCardDeleteEffectForHud = function(isFromHandZone, hudSeat)
    if getPanelCtrl(PanelId.CardGameBlackjackHud) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardDeleteEffectForHud: HUD未打开")
        return
    end

    hudSeat = hudSeat or 1
    local fromHandZone = isFromHandZone == true
    local cardInfo = {
        suit = CardSuit.Hearts:ToInt(),
        rank = 10,
        style = CardGameUtils.GetCardStyleByEnhance(1),
    }

    local regionId
    if fromHandZone then
        regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_HAND_PREFIX .. hudSeat
    else
        regionId = CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeat
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil or cardSystem:GetRegion(regionId) == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardDeleteEffectForHud: 手牌区未就绪")
        return
    end
    local uid = CardGameBlackjackUtils.HUD_CARD_CHANGE_TEST_UID_BASE + 1
    if cardSystem:GetRuntimeCard(uid) ~= nil then
        cardSystem:RecycleCardByUid(uid, false)
    end
    local card = cardSystem:CreateCard(regionId, uid)
    if card == nil then
        logger.error("CardGameBlackjackUtils.PanelTestCardDeleteEffectForHud: 手牌区创牌失败, uid=" .. tostring(uid))
        return
    end
    cardSystem:SetPokerData(uid, cardInfo.suit, cardInfo.rank, cardInfo.style, true)
    cardInfo.uid = uid
    cardSystem:RelayoutRegion(regionId, false)

    local system = LuaSystemManager.cardGameBlackjackSystem
    local deckDrawIndex = 0
    if not fromHandZone then
        
        local drawOrder = system.m_seatDeckUids[hudSeat]
        if drawOrder == nil then
            drawOrder = {}
            system.m_seatDeckUids[hudSeat] = drawOrder
        end
        table.insert(drawOrder, 1, uid)
        deckDrawIndex = 1
    end
    system:_PlayRemoveCardForHud(hudSeat, fromHandZone, cardInfo, deckDrawIndex, {})
end





local HUD_CHOOSE_TEST_TIMEOUT_MS = 30000


local function buildTestChooseCards(cards)
    local list = { Count = #cards }
    for i = 1, #cards do
        list[i - 1] = cards[i]
    end
    return list
end



local function testHudChooseSelfPlayer(chooseKey, cards, isClose)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    local system = LuaSystemManager.cardGameBlackjackSystem
    system:_PopChooseFrom(chooseKey)
    if isClose then
        return
    end

    local open = function()
        system:_OpenChooseByNotify(chooseKey, {
            seqId = 0,
            recvTime = system:_GetCountDownNow(),
            batch = {
                responseTimeoutMs = HUD_CHOOSE_TEST_TIMEOUT_MS,
                chooseData = { cards = buildTestChooseCards(cards) },
            },
        })
    end
    if getPanelCtrl(PanelId.CardGameBlackjackHud) ~= nil then
        open()
    else
        CardGameBlackjackUtils.PanelTest("CardGameBlackjackHud", open)
    end
end


CardGameBlackjackUtils.PanelTestHudChooseSelfPlayerPreviewCard = function(isClose)
    testHudChooseSelfPlayer(CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard, {
        { id = 1, suit = CardSuit.Hearts:ToInt(), rank = 1, enhance = 1 },
        { id = 2, suit = CardSuit.Spades:ToInt(), rank = 13, enhance = 2 },
        { id = 3, suit = CardSuit.Diamonds:ToInt(), rank = 7, enhance = 3 },
    }, isClose)
end


CardGameBlackjackUtils.PanelTestHudChooseSelfPlayerDestroyCard = function(isClose)
    testHudChooseSelfPlayer(CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard, {
        { id = 1, suit = CardSuit.Clubs:ToInt(), rank = 10, enhance = 1 },
    }, isClose)
end




local EFFECT_REPORT_TEST_DELTA = 2

local function runWithHud(fn)
    if getPanelCtrl(PanelId.CardGameBlackjackHud) ~= nil then
        fn()
    else
        CardGameBlackjackUtils.PanelTest("CardGameBlackjackHud", fn)
    end
end


CardGameBlackjackUtils.PanelTestEffectReportRelic = function(relicId)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    local _, relicCfg = Tables.cardGameRelicInfoTable:TryGetValue(relicId)
    if relicCfg == nil then
        logger.error("CardGameBlackjackUtils.PanelTestEffectReportRelic: 找不到遗物 " .. tostring(relicId))
        return
    end
    runWithHud(function()
        LuaSystemManager.cardGameBlackjackSystem.m_effectReportInfo = {
            memberId = 0,
            relicInfo = {
                relicId = relicId,
                relicIcon = relicCfg.relicIcon,
                relicName = relicCfg.relicName,
                effectList = {},
            },
        }
        Notify(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT)
    end)
end




CardGameBlackjackUtils.PanelTestEffectReportEffect = function(kind)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    runWithHud(function()
        local system = LuaSystemManager.cardGameBlackjackSystem
        local info = system.m_effectReportInfo
        local host = info and (info.relicInfo or info.pickCardInfo)
        if host == nil then
            logger.error("CardGameBlackjackUtils.PanelTestEffectReportEffect: 当前没有播报，先弹遗物或抽牌播报")
            return
        end
        local effectInfo = system:_BuildEffectReportArgEffectInfo(kind, { kind = kind, delta = EFFECT_REPORT_TEST_DELTA })
        if effectInfo == nil then
            logger.error("CardGameBlackjackUtils.PanelTestEffectReportEffect: 效果表没有 " .. tostring(kind))
            return
        end
        host.effectList = host.effectList or {}
        table.insert(host.effectList, effectInfo)
        Notify(MessageConst.CARD_GAME_BLACKJACK_UPDATE_EFFECT_REPORT)
    end)
end


CardGameBlackjackUtils.PanelTestEffectReportPickCard = function(hudSeat, isStopPick)
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    runWithHud(function()
        LuaSystemManager.cardGameBlackjackSystem.m_effectReportInfo = {
            memberId = 0,
            pickCardInfo = {
                seatIndex = hudSeat,
                isSelf = hudSeat == 1,
                isStopPick = isStopPick == true,
            },
        }
        Notify(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT)
    end)
end

CardGameBlackjackUtils.PanelTestEffectReportHide = function()
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    LuaSystemManager.cardGameBlackjackSystem:_ClearEffectReportInfoAndNotifyHide()
end




CardGameBlackjackUtils.TestPauseNotifyQueue = function()
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    LuaSystemManager.cardGameBlackjackSystem.m_notifyQueue:Pause("Debug")
end

CardGameBlackjackUtils.TestResumeNotifyQueue = function()
    if not (BEYOND_DEBUG or BEYOND_DEBUG_COMMAND) then
        return
    end
    LuaSystemManager.cardGameBlackjackSystem.m_notifyQueue:Resume("Debug")
end





_G.CardGameBlackjackUtils = CardGameBlackjackUtils
return CardGameBlackjackUtils
