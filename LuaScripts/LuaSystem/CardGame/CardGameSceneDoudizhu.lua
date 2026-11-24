local CardGameSceneBase = require_ex('LuaSystem/CardGame/CardGameSceneBase').CardGameSceneBase

local MAX_SEAT_COUNT = 3
local CARD_REGION_DECK = "doudizhuDeck"
local CARD_REGION_PLAYER_HAND_IDS = {
    "doudizhuHand_self",
    "doudizhuHand_left",
    "doudizhuHand_right",
}
local CARD_REGION_PLAYER_PLAY_IDS = {
    "doudizhuPlay_self",
    "doudizhuPlay_left",
    "doudizhuPlay_right",
}

CardGameSceneDoudizhu = HL.Class('CardGameSceneDoudizhu', CardGameSceneBase)

CardGameSceneDoudizhu.CardGameSceneDoudizhu = HL.Constructor() << function(self)
    CardGameSceneDoudizhu.SuperConstructor(self)
end

CardGameSceneDoudizhu.GetScenePrefabName = HL.Override().Return(HL.String) << function(self)
    return "CardGameRoom_Landlord"
end

CardGameSceneDoudizhu.GetMaxSeatCount = HL.Override().Return(HL.Number) << function(self)
    return MAX_SEAT_COUNT
end


CardGameSceneDoudizhu.GetHudSeatToSceneSeat = HL.Override().Return(HL.Table) << function(self)
    return { 1, 2, 4 }
end

CardGameSceneDoudizhu.InitCharModels = HL.Override() << function(self)
    self:_ReleaseCharModels()
    local seatChars = self.seatChars
    if next(seatChars) == nil then
        logger.warn("[斗地主][角色] 没有收到座位角色列表；牌桌会继续准备，但角色模型不会加载")
    end

    local mapping = self:GetHudSeatToSceneSeat()
    for hudSeat = 1, self:GetMaxSeatCount() do
        local sceneSeat = mapping[hudSeat]
        local seatChar = seatChars[hudSeat]
        local charId = (seatChar and seatChar.charId) or ""
        if string.isEmpty(charId) then
            logger.error(string.format(
                "[斗地主][角色] 座位角色ID缺失：HUD席位=%d，场景席位=%d；请检查服务端 brief 数据",
                hudSeat, sceneSeat))
        end
        self:CreateCharOnHudSeat(hudSeat, charId, seatChar and seatChar.showPotentialFx)
    end
end




CardGameSceneDoudizhu.InitRegions = HL.Override() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    local emptyRoot = self.sceneRoot.view.emptyRoot
    cardSystem:RegisterRegion(CARD_REGION_DECK, emptyRoot.tableCenterRoot)
    for hudSeat = 1, MAX_SEAT_COUNT do
        cardSystem:RegisterRegion(CARD_REGION_PLAYER_HAND_IDS[hudSeat],
                emptyRoot["doudizhuHandRoot_" .. hudSeat])
        cardSystem:RegisterRegion(CARD_REGION_PLAYER_PLAY_IDS[hudSeat],
                emptyRoot["doudizhuPlayRoot_" .. hudSeat])
    end
end



CardGameSceneDoudizhu.SyncSelfHandRegionLayout = HL.Method().Return(HL.Boolean) << function(self)
    if self.sceneRoot == nil or self.sceneRoot.view == nil then
        return false
    end
    local emptyRoot = self.sceneRoot.view.emptyRoot
    local luaRef = emptyRoot.gameObject:GetComponent("LuaReference")
    if luaRef ~= nil then
        luaRef:RefreshCustomUIStyleBindings()
    end

    local cardSystem = LuaSystemManager.cardGameSystem
    local regionId = CARD_REGION_PLAYER_HAND_IDS[1]
    local region = cardSystem:GetRegion(regionId)
    local layout = emptyRoot.doudizhuHandRoot_1:GetComponent(typeof(CS.Beyond.UI.CardGamePokerLayout))
    if region == nil or IsNull(layout) or region:GetLayout() == layout then
        return false
    end
    
    layout.layoutData:SetSelectedIndices(nil)
    return cardSystem:RebindRegionLayout(regionId, layout)
end

HL.Commit(CardGameSceneDoudizhu)
