local CardGameUtils = {}


CardGameUtils.ValueChangeType = {
    Add = 1,
    Sub = 2,
    ChangeTo = 3,
}

CardGameUtils.RoomCameraPosType = {
    Overlook = 1,
    Normal = 2,
}

CardGameUtils.CardEffectVFXName = {
    Delete = "P_fxint_l_map02_lv011_card_end_02_asset",
    Appear = "P_fxint_l_map02_lv011_card_start_02_asset",
}


CardGameUtils.VoiceType = {
    Start = "boardgame_start",
    Victory = "boardgame_victory",
}



local ENHANCE_STYLE = {
    [1] = "None",
    [2] = "Colorful",
    [3] = "Mining",
    [4] = "TransBack",
    [5] = "Royal",
}

CardGameUtils.GetCardStyleByEnhance = function(enhance)
    return ENHANCE_STYLE[enhance] or ENHANCE_STYLE[1]
end

CardGameUtils.GetOrdinalSuffix = function(num)
    
    local n = math.abs(math.floor(num))
    
    local remainder_100 = n % 100
    if remainder_100 >= 11 and remainder_100 <= 13 then
        return "th"
    end
    
    local remainder_10 = n % 10
    if remainder_10 == 1 then
        return "st"
    elseif remainder_10 == 2 then
        return "nd"
    elseif remainder_10 == 3 then
        return "rd"
    else
        return "th"
    end
end

CardGameUtils.GetNumDeltaText = function(num)
    return (num >= 0) and ("+" .. num) or num
end


CardGameUtils.SyncPlayerHeadTargetGraphic = function(playerHead)
    local playerHeadBtn = playerHead.view.playerHeadBtn
    local targetGraphic = playerHeadBtn.targetGraphic
    if targetGraphic ~= nil then
        targetGraphic.gameObject:SetActiveIfNecessary(playerHeadBtn.enabled)
    end
end


CardGameUtils.InitCommonPlayerHead = function(playerHead, displayInfo)
    playerHead:UpdateHideLevelTxt(true)
    playerHead:UpdateHideSignature(true)
    if displayInfo.isAI then
        playerHead:InitCommonPlayerHead(displayInfo.avatarIcon, displayInfo.avatarFrameIcon, false,
            displayInfo.adventureLevel, displayInfo.nickname, displayInfo.signature, displayInfo.psName)
    else
        playerHead:InitCommonPlayerHeadByRoleId(displayInfo.roleId, false)
    end
    CardGameUtils.SyncPlayerHeadTargetGraphic(playerHead)
end



CardGameUtils.GetPlayerDisplayName = function(displayInfo, fallbackName)
    local friendInfo = displayInfo and displayInfo.friendInfo
    if displayInfo == nil or displayInfo.isAI or friendInfo == nil then
        local nickname = displayInfo and displayInfo.nickname
        return not string.isEmpty(nickname) and nickname or (fallbackName or "")
    end
    if not string.isEmpty(friendInfo.remakeName) then
        return string.format(Language.LUA_FRIEND_REMAKE_NAME, friendInfo.remakeName, friendInfo.name, friendInfo.shortId)
    end
    return string.format(Language.LUA_FRIEND_NAME, friendInfo.name, friendInfo.shortId)
end



CardGameUtils.IsMemberShowAI = function(memberId)
    local briefMember = GameInstance.player.multiplayerPlayRoomSystem:GetBriefMemberByMemberId(memberId)
    return briefMember ~= nil and briefMember.memberType ~= CS.Proto.MULTIPLAYER_PLAY_ROOM_MEMBER_TYPE.Player
end


CardGameUtils.QueryPlayerSocialFlags = function(player)
    local canQuery = not player.isSelf and not player.isAI and player.roleId ~= nil and player.roleId ~= 0
    local friendSystem = GameInstance.player.friendSystem
    local isInBlackList = canQuery and friendSystem:PlayerInBlackList(player.roleId)
    local isFriend = canQuery and not isInBlackList and friendSystem.friendInfoDic:ContainsKey(player.roleId)
    return {
        isInBlackList = isInBlackList,
        isFriend = isFriend,
        isFriendRequestSent = canQuery and not isInBlackList and not isFriend
                and friendSystem:ContainWaitAcceptRequestID(player.roleId),
        canAddFriend = canQuery and not isInBlackList and not isFriend,
    }
end


CardGameUtils.RequestAddFriend = function(roleId, sourcePanelId, phaseName)
    local friendSystem = GameInstance.player.friendSystem
    if friendSystem:PlayerInBlackList(roleId) then
        Notify(MessageConst.SHOW_TOAST, Tables.errorCodeTable:GetValue(1065).text)
        return false
    end
    friendSystem:AddFriend(roleId, phaseName or PhaseManager:GetTopPhaseName(), sourcePanelId, "")
    return true
end


CardGameUtils.BindCardGamePlayerHeadMenu = function(cell, player, sourcePanelId)
    if player.isSelf or player.isAI or player.roleId == 0 then
        return
    end

    cell.view.playerHead:SetClick(function()
        
        local social = CardGameUtils.QueryPlayerSocialFlags(player)
        local roleId = player.roleId
        local friendActions = FriendUtils.FRIEND_CELL_HEAD_FUNC
        local actions = {}
        if not social.isInBlackList then
            if social.isFriend then
                table.insert(actions, friendActions.REMARK_MODIFY(roleId))
            else
                table.insert(actions, {
                    text = Language.LUA_FRIEND_TITLE_FRIEND_ADD,
                    action = function()
                        CardGameUtils.RequestAddFriend(roleId, sourcePanelId)
                    end,
                })
            end
            table.insert(actions, friendActions.ADD_BLACK_LIST(roleId))
        end
        table.insert(actions, friendActions.REPORT(roleId))
        if FriendUtils.isPsnPlatform() and GameInstance.player.friendSystem:IsPsnFriend(roleId) then
            table.insert(actions, friendActions.PSN_INFO(roleId))
        end
        Notify(MessageConst.SHOW_NAVI_TARGET_ACTION_MENU, {
            transform = cell.view.playerHead.view.tipRectTransform,
            cellHeight = 60,
            actions = actions,
        })
    end)
end


CardGameUtils.InitMultiplayerPlayerCellBasic = function(cell, displayInfo)
    if displayInfo.isAI then
        cell:InitMultiplayerPlayerCellByDisplayInfo(displayInfo)
    else
        local roleId = displayInfo.roleId
        local headClick = roleId ~= GameInstance.player.roleId
                and FriendUtils.FRIEND_CELL_HEAD_FUNC.BUSINESS_CARD_PHASE(roleId).action or nil
        cell:InitMultiplayerPlayerCell(roleId, displayInfo.friendInfo, nil, headClick)
    end
end


CardGameUtils.InitCardGameMultiplayerPlayerCell = function(cell, player, sourcePanelId)
    CardGameUtils.InitMultiplayerPlayerCellBasic(cell, player.displayInfo)
    CardGameUtils.BindCardGamePlayerHeadMenu(cell, player, sourcePanelId)
    CardGameUtils.SyncPlayerHeadTargetGraphic(cell.view.playerHead)
end



CardGameUtils.TriggerVoice = function(voiceType, charId)
    if string.isEmpty(voiceType) then
        return
    end
    charId = MultiplayerUtils.resolveDisplayCharTemplateId(charId, GameInstance.player.playerInfoSystem.gender)
    if string.isEmpty(charId) then
        return
    end
    Utils.triggerVoice(voiceType, charId)
end



_G.CardGameUtils = CardGameUtils
return CardGameUtils