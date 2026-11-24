local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameLandlordPlayerGameInfo
local PHASE_ID = PhaseId.CardGameLandlordPlayerGameInfo
CardGameLandlordPlayerGameInfoCtrl = HL.Class('CardGameLandlordPlayerGameInfoCtrl', uiCtrl.UICtrl)







CardGameLandlordPlayerGameInfoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BLACK_LIST_INFO_SYNC] = '_RefreshAllUI', 
    [MessageConst.ON_FRIEND_CELL_INFO_CHANGE] = '_RefreshAllUI',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
}

CardGameLandlordPlayerGameInfoCtrl.m_arg = HL.Field(HL.Table)
CardGameLandlordPlayerGameInfoCtrl.m_landlordCardWidgets = HL.Field(HL.Table)


CardGameLandlordPlayerGameInfoCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self:RefreshPlayerGameInfo(arg)
end

CardGameLandlordPlayerGameInfoCtrl.RefreshPlayerGameInfo = HL.Method(HL.Table) << function(self, arg)
    self.m_arg = arg
    self:_RefreshAllUI()
end


CardGameLandlordPlayerGameInfoCtrl.RefreshPlayerSocialInfo = HL.Method(HL.Opt(HL.Table)) << function(self, player)
    if player ~= nil then
        self.m_arg.player = player
    end
    self:_RefreshAllUI()
end

CardGameLandlordPlayerGameInfoCtrl.GetHudSeat = HL.Method().Return(HL.Number) << function(self)
    return self.m_arg.hudSeat
end

CardGameLandlordPlayerGameInfoCtrl._InitUI = HL.Method() << function(self)
    local closePanel = function()
        PhaseManager:PopPhase(PHASE_ID)
    end
    self.view.titleNode.closeBtn.onClick:AddListener(closePanel)
    self.view.closeClick.onClick:AddListener(closePanel)
    self:BindInputPlayerAction("common_back", closePanel)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    local landlordCardNode = self.view.gameInfoNode.landlordCardNode
    self.m_landlordCardWidgets = {
        landlordCardNode.cardCell01,
        landlordCardNode.cardCell02,
        landlordCardNode.cardCell03,
    }
end

CardGameLandlordPlayerGameInfoCtrl._RefreshAllUI = HL.Method() << function(self)
    local arg = self.m_arg
    local player = arg.player
    local playerMsgNode = self.view.playerMsgNode
    playerMsgNode.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, player.seatIndex))
    self:_RefreshPlayerAIState()
    CardGameUtils.InitCardGameMultiplayerPlayerCell(playerMsgNode.multiplayerPlayerCell, player, "CardGameLandlordPlayerGameInfo")

    local camp = arg.camp
    local stateName
    if camp == CS.Proto.DDZ_CAMP.None then
        stateName = "NoIdentity"
    elseif camp == CS.Proto.DDZ_CAMP.Landlord then
        stateName = "LandlordInfo"
    elseif camp == CS.Proto.DDZ_CAMP.Farmer then
        stateName = "PeasantInfo"
    end
    self.view.mainState:SetState(stateName)
    self.view.gameInfoNode.handNumTxt.text = tostring(arg.handCardsCount)

    if camp == CS.Proto.DDZ_CAMP.Landlord then
        for index, cardData in ipairs(arg.bottomCards) do
            local card = self.m_landlordCardWidgets[index]
            card:InitCardGame2DPoker(cardData.instId)
            card:SetCardSuitRank(cardData.suit, cardData.rank)
            card:SetFace(true)
        end
    end
end

CardGameLandlordPlayerGameInfoCtrl._RefreshPlayerAIState = HL.Method() << function(self)
    local player = self.m_arg.player
    local isAI = CardGameUtils.IsMemberShowAI(player.memberId)
    self.view.playerMsgNode.stateController:SetState(player.isSelf and "Self" or isAI and "Ai" or "None")
    self.view.gameInfoNode.isSelfFlagIcon.gameObject:SetActive(player.isSelf)
end

CardGameLandlordPlayerGameInfoCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    if self.m_arg.player.memberId == unpack(arg) then
        self:_RefreshPlayerAIState()
    end
end

HL.Commit(CardGameLandlordPlayerGameInfoCtrl)
