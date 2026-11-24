local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameLandlordFinalSettleRank
local NAVI_DIRECTION = CS.UnityEngine.UI.NaviDirection

CardGameLandlordFinalSettleRankCtrl = HL.Class('CardGameLandlordFinalSettleRankCtrl', uiCtrl.UICtrl)







CardGameLandlordFinalSettleRankCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED] = '_RefreshPlayerCells',
    [MessageConst.ON_FRIEND_CELL_INFO_CHANGE] = '_RefreshPlayerCells',
}

CardGameLandlordFinalSettleRankCtrl.m_arg = HL.Field(HL.Table)
CardGameLandlordFinalSettleRankCtrl.m_playerRankingCells = HL.Field(HL.Table)
CardGameLandlordFinalSettleRankCtrl.m_isReturnMatchRoom = HL.Field(HL.Boolean) << false

CardGameLandlordFinalSettleRankCtrl.m_hasPlayedVictoryVoice = HL.Field(HL.Boolean) << false


CardGameLandlordFinalSettleRankCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self:_InitUI()
    self:_RefreshAllUI()
    
    if InputManagerInst.inChangingInputDevice then
        self.m_hasPlayedVictoryVoice = true
    else
        AudioManager.PostEvent("au_music_gambling_v1d7_doudizhu_score")
    end
end

CardGameLandlordFinalSettleRankCtrl.OnShow = HL.Override() << function(self)
    if self.m_hasPlayedVictoryVoice then
        return
    end
    local selfInfo = self.m_arg and self.m_arg.selfInfo
    if selfInfo == nil or not selfInfo.isWinner then
        return
    end
    self.m_hasPlayedVictoryVoice = true
    CardGameUtils.TriggerVoice(CardGameUtils.VoiceType.Victory, selfInfo.charId)
end


CardGameLandlordFinalSettleRankCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return lume.deepCopy(self.m_arg)
end

CardGameLandlordFinalSettleRankCtrl._InitUI = HL.Method() << function(self)
    local view = self.view
    view.controllerHintPlaceholder:InitControllerHintPlaceholder({ view.inputGroup.groupId })
    local restoreShareState = function()
        local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
        if isOpen then
            ctrl.view.stateController:SetState("NoShare")
        end
    end
    view.stateController:SetState("NoShare")
    view.shareBtn.onClick:AddListener(function()
        view.stateController:SetState("Share")
        Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
            type = "Normal",
            onCaptureEnd = restoreShareState,
            onClose = restoreShareState,
        })
    end)
    view.exitBtnState.button.onClick:AddListener(function()
        self:_OnClickExitBtn()
    end)
    view.returnLobbyBtn.onClick:AddListener(function()
        LuaSystemManager.cardGameDoudizhuSystem:ReturnFromFinalSettle(MultiplayerConst.EPlayRoomReturn.Main)
    end)
    self.m_playerRankingCells = {
        view.playerRankingCell01,
        view.playerRankingCell02,
        view.playerRankingCell03,
    }
    local playerCount = #self.m_playerRankingCells
    for index, cell in ipairs(self.m_playerRankingCells) do
        local currentIndex = index
        local currentButton = cell.contBtn
        local currentInputGroupId = cell.inputGroup.groupId
        InputManagerInst:ToggleGroup(currentInputGroupId, not DeviceInfo.usingController)
        currentButton.onIsNaviTargetChanged = function(isTarget)
            InputManagerInst:ToggleGroup(currentInputGroupId, not DeviceInfo.usingController or isTarget)
        end
        
        currentButton.customNaviTargetInDirFunc = function(dir)
            if dir == NAVI_DIRECTION.Left then
                local targetIndex = currentIndex == 1 and playerCount or currentIndex - 1
                return self.m_playerRankingCells[targetIndex].contBtn
            elseif dir == NAVI_DIRECTION.Right then
                local targetIndex = currentIndex == playerCount and 1 or currentIndex + 1
                return self.m_playerRankingCells[targetIndex].contBtn
            elseif dir == NAVI_DIRECTION.Up or dir == NAVI_DIRECTION.Down then
                return currentButton
            end
        end
    end
    self:_RefreshExitButtonState()
end


CardGameLandlordFinalSettleRankCtrl._RefreshExitButtonState = HL.Method() << function(self)
    local stateController = self.view.exitBtnState.stateController
    self.m_isReturnMatchRoom = false
    if not LuaSystemManager.cardGameSystem.isEnterFromMatchRoom then
        stateController:SetState("Again")
    elseif GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        self.m_isReturnMatchRoom = true
        stateController:SetState("ReturnMatchRoom")
    else
        stateController:SetState("ReturnLobby")
    end
end


CardGameLandlordFinalSettleRankCtrl._OnClickExitBtn = HL.Method() << function(self)
    local doudizhuSystem = LuaSystemManager.cardGameDoudizhuSystem
    if not LuaSystemManager.cardGameSystem.isEnterFromMatchRoom then
        doudizhuSystem:ReturnFromFinalSettle(MultiplayerConst.EPlayRoomReturn.QuickMatch)
        return
    end
    if GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        doudizhuSystem:ReturnFromFinalSettle(MultiplayerConst.EPlayRoomReturn.RoomMatch)
        return
    end
    if self.m_isReturnMatchRoom then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_ROOM_CLOSED_TOAST)
    end
    doudizhuSystem:ReturnFromFinalSettle(MultiplayerConst.EPlayRoomReturn.Main)
end

CardGameLandlordFinalSettleRankCtrl._RefreshAllUI = HL.Method() << function(self)
    
    local winnerCamp = self.m_arg.winnerCamp
    if winnerCamp == CS.Proto.DDZ_CAMP.Landlord then
        self.view.stateController:SetState("LeftIsLandowner")
        self.view.stateController:SetState("LandownerWin")
    elseif winnerCamp == CS.Proto.DDZ_CAMP.Farmer then
        self.view.stateController:SetState("LeftIsPeasant")
        self.view.stateController:SetState("LandownerLost")
    end
    self:_RefreshPlayerCells()
    if DeviceInfo.usingController then
        InputManagerInst:ToggleGroup(self.m_playerRankingCells[1].inputGroup.groupId, true)
    end
    self:SetNaviTarget(self.m_playerRankingCells[1].contBtn)
end


CardGameLandlordFinalSettleRankCtrl._RefreshPlayerCells = HL.Method() << function(self)
    for index, playerInfo in ipairs(self.m_arg.playerInfos) do
        self:_RefreshPlayerRankingCell(self.m_playerRankingCells[index], playerInfo)
    end
end

CardGameLandlordFinalSettleRankCtrl._RefreshPlayerRankingCell = HL.Method(HL.Table, HL.Table) << function(self, cell, playerInfo)
    cell.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, playerInfo.seatIndex))
    local showChar = not string.isEmpty(playerInfo.charId)
    cell.charImg.gameObject:SetActive(showChar)
    if showChar then
        cell.charImg:LoadSprite(UIConst.UI_SPRITE_GACHA_CHAR, playerInfo.charId)
    end

    
    local social = CardGameUtils.QueryPlayerSocialFlags(playerInfo)
    if playerInfo.isSelf then
        cell.cellState:SetState("SelfFlag")
    elseif social.isFriend then
        cell.cellState:SetState("FriendFlag")
    else
        cell.cellState:SetState("NoFlag")
    end
    if playerInfo.camp == CS.Proto.DDZ_CAMP.Landlord then
        cell.cellState:SetState("Landlord")
    elseif playerInfo.camp == CS.Proto.DDZ_CAMP.Farmer then
        cell.cellState:SetState("Peasant")
    end
    cell.cellState:SetState(playerInfo.isWinner and "Victory" or "Defeat")

    cell.addFriendBtn.onClick:RemoveAllListeners()
    if social.canAddFriend then
        cell.cellState:SetState(social.isFriendRequestSent and "AppliedAddFriend" or "CanAddFriend")
        cell.addFriendBtn.onClick:AddListener(function()
            if LuaSystemManager.cardGameDoudizhuSystem:RequestAddFriend(playerInfo.roleId, "CardGameLandlordFinalSettleRank") then
                cell.cellState:SetState("AppliedAddFriend")
            end
        end)
    else
        cell.cellState:SetState("NoAddFriend")
    end
    CardGameUtils.InitCardGameMultiplayerPlayerCell(cell.friendNode, playerInfo, "CardGameLandlordFinalSettleRank")
end

HL.Commit(CardGameLandlordFinalSettleRankCtrl)
