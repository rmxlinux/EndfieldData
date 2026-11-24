local MultiplayerUtils = {}



function MultiplayerUtils.hasOpenGame()
    local gameCenter = GameInstance.player.multiplayerGameCenterSystem
    if not gameCenter.hasSyncedAll then
        return false
    end
    for _, data in pairs(Tables.multiplayerGameCenterTable) do
        if gameCenter:IsGameAvailable(data.gameId) then
            return true
        end
    end
    return false
end



function MultiplayerUtils.checkAllGamesClosed()
    local gameCenter = GameInstance.player.multiplayerGameCenterSystem
    local cardGameSystem = LuaSystemManager.cardGameSystem
    
    if not gameCenter.hasSyncedAll or not gameCenter.areAllGamesClosed
        or cardGameSystem.isServerInGame or GameInstance.player.multiplayerPlayRoomSystem.inRoom
        or cardGameSystem.isClientInGame then
        return false
    end
    
    if not PhaseManager:IsOpen(PhaseId.MultiplayerMain)
        and not UIManager:IsOpen(PanelId.ActivityCardGame) then
        return false
    end
    
    if UIManager:IsShow(PanelId.ActivityPopUp) then
        return true
    end
    if not gameCenter:TryConsumeAllGamesClosed() then
        return false
    end
    Notify(MessageConst.SHOW_ACTIVITY_POP_UP, {
        content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU,
        hideCancel = true,
        onConfirm = function()
            PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
        end,
    })
    return true
end


function MultiplayerUtils.closeMatchOverlayPanels(isRoom)
    if isRoom then
        local roomPanels = {
            PanelId.CommonShare,
            PanelId.CommonShareWait,
            PanelId.CommonFilter, 
            PanelId.FriendRoleDisplay,
            PanelId.FriendBusinessCardPreview,
            PanelId.NaviTargetActionMenu,
            PanelId.ReportPlayer,
            PanelId.SetBirthdayPopUp,
            PanelId.FriendBusinessRecordTips,
            PanelId.MultiplayerRoomNotice,
        }
        for _, id in ipairs(roomPanels) do
            UIManager:Close(id)
        end
    end
    local matchPanels = {
        PanelId.CommonIntro,
        PanelId.CommonPopUp,
        PanelId.MultiplayerRoomInvitation,
        PanelId.MultiplayerPSOnlyNotice,
    }
    for _, id in ipairs(matchPanels) do
        UIManager:Close(id)
    end
end


function MultiplayerUtils.isRedDotRead(redDotName, id)
    local _, isRead = ClientDataManagerInst:GetBool(redDotName .. "_Read_" .. id, false, false, MultiplayerConst.CLIENT_DATA_CATEGORY)
    return isRead
end

function MultiplayerUtils.setRedDotRead(redDotName, id)
    if string.isEmpty(id) or MultiplayerUtils.isRedDotRead(redDotName, id) then
        return
    end
    ClientDataManagerInst:SetBool(redDotName .. "_Read_" .. id, true, false, MultiplayerConst.CLIENT_DATA_CATEGORY)
    RedDotManager:TriggerUpdate(redDotName)
end


function MultiplayerUtils.isUpdatedGame(data)
    return data.quickMatchType == GEnums.MatchGameType.Doudizhu
end

function MultiplayerUtils.isNewGameUnread(gameId)
    local found, data = Tables.multiplayerGameCenterTable:TryGetValue(gameId)
    return found and MultiplayerUtils.isUpdatedGame(data)
        and GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(gameId)
        and not MultiplayerUtils.isRedDotRead("MultiplayerNewGame", MultiplayerConst.CARD_GAME_ACTIVITY_ID .. "_" .. gameId)
end

function MultiplayerUtils.setNewGameRead(gameId)
    if MultiplayerUtils.isNewGameUnread(gameId) then
        MultiplayerUtils.setRedDotRead("MultiplayerNewGame", MultiplayerConst.CARD_GAME_ACTIVITY_ID .. "_" .. gameId)
    end
end







function MultiplayerUtils.refreshGameBackground(ctrl, parent, current, prefabName)
    if current ~= nil and current.name == prefabName then
        return current
    end
    MultiplayerUtils.clearGameBackground(current)
    if string.isEmpty(prefabName) then
        return nil
    end
    local path = string.format(UIConst.UI_MULTIPLAYER_WIDGETS_PREFAB_PATH, prefabName)
    local prefab = ctrl:LoadGameObject(path)
    if prefab == nil then
        logger.error("[MultiplayerUtils] 无法加载玩法背景", path)
        return nil
    end
    local background = CSUtils.CreateObject(prefab, parent)
    background.name = prefabName
    return background
end


function MultiplayerUtils.clearGameBackground(background)
    if background == nil then
        return
    end
    CSUtils.ClearUIComponents(background)
    GameObject.DestroyImmediate(background)
end




local CHAR_SELECT_STYLE = "CardGame"



function MultiplayerUtils.resolveDisplayCharTemplateId(templateId, gender)
    local charUtils = CS.Beyond.Gameplay.CharUtils
    if string.isEmpty(templateId) or not charUtils.IsEndminTemplateId(templateId) then
        return templateId
    end
    if gender == CS.Proto.GENDER.GenMale then
        return charUtils.endminMaleCharTemplateId
    end
    return charUtils.endminFemaleCharTemplateId
end


function MultiplayerUtils.getSelfDisplayCharTemplateId()
    local templateId = GameInstance.player.multiplayerGameCenterSystem.globalPersonalInfo.cardGameCharTemplateId
    return MultiplayerUtils.resolveDisplayCharTemplateId(templateId, GameInstance.player.playerInfoSystem.gender)
end


function MultiplayerUtils.getMemberDisplayCharTemplateId(briefData)
    if briefData == nil then
        return nil
    end
    if briefData.roleId == GameInstance.player.roleId then
        return MultiplayerUtils.resolveDisplayCharTemplateId(briefData.charId, GameInstance.player.playerInfoSystem.gender)
    end
    local gender
    local success, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(briefData.roleId)
    if success and friendInfo ~= nil then
        gender = friendInfo.gender
    end
    return MultiplayerUtils.resolveDisplayCharTemplateId(briefData.charId, gender)
end


function MultiplayerUtils.openBusinessCard(roleId)
    if roleId == GameInstance.player.roleId then
        PhaseManager:GoToPhase(PhaseId.Friend, {
            panelId = PanelId.FriendBusinessCardRoot,
            hideTabs = true,
        })
    else
        FriendUtils.FRIEND_CELL_HEAD_FUNC.BUSINESS_CARD_PHASE(roleId, {
            ignoreFriendCommunication = true,
        }).action()
    end
end

function MultiplayerUtils.openCharSelect()
    local selectedCharInfo
    local templateId = MultiplayerUtils.getSelfDisplayCharTemplateId()
    if not string.isEmpty(templateId) then
        local curCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(templateId, GEnums.CharType.Default)
        if curCharInfo then
            selectedCharInfo = {
                charInstId = curCharInfo.instId,
                charId = templateId,
            }
        else
            logger.error("[MultiplayerUtils] 出战干员反查不到角色实例，templateId=", templateId)
        end
    end

    local phaseId = PhaseId.CommonSelectChar
    PhaseManager:GoToPhase(phaseId, {
        charItems = CharInfoUtils.getAllCharInfoList(),
        selectedCharInfo = selectedCharInfo,
        titleText = Language.ui_common_select_char_card_game_title,
        titleTxt02Text = Language.ui_common_select_char_cur_char,
        selectStyle = CHAR_SELECT_STYLE,
        setupBtnCallback = function(charInfo)
            GameInstance.player.multiplayerGameCenterSystem:SendCardGameSetChar(charInfo.charId)
            PhaseManager:PopPhase(phaseId)
        end,
    })
end


function MultiplayerUtils.refreshCharHeadIcon(headIcon, charTemplateId)
    local hasChar = not string.isEmpty(charTemplateId)
    headIcon.headIconImg.gameObject:SetActiveIfNecessary(hasChar)
    headIcon.emptyNode.gameObject:SetActiveIfNecessary(not hasChar)
    if hasChar then
        headIcon.headIconImg:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD,
            UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. charTemplateId)
    end
end

function MultiplayerUtils.canShowRoomInvitationNotice()
    local topPhaseId = PhaseManager:GetTopPhaseId()
    return topPhaseId == PhaseId.MultiplayerMain
        or topPhaseId == PhaseId.MultiplayerMatch
end

function MultiplayerUtils.enterRoomByInvitation(roomStrId)
    PhaseManager:GoToPhase(PhaseId.MultiplayerMain, nil, function()
        if PhaseManager:IsOpen(PhaseId.SNS) then
            PhaseManager:ExitPhaseFast(PhaseId.SNS)
        end
        GameInstance.player.multiplayerMatchSystem:Join(roomStrId)
    end)
end


function MultiplayerUtils.initAchievementMedals(view)
    local achievementIds = Tables.multiplayerGameConst.achievementIds
    local medalNodes = { view.dungeonMedalCell1, view.dungeonMedalCell2 }
    local achievements = {}
    
    for index, medalNode in ipairs(medalNodes) do
        local achievementId = achievementIds and index <= achievementIds.Count and achievementIds[CSIndex(index)] or nil
        local found, achievementData = false, nil
        if not string.isEmpty(achievementId) then
            found, achievementData = Tables.achievementTable:TryGetValue(achievementId)
        end
        medalNode.gameObject:SetActiveIfNecessary(found)
        if found then
            medalNode:InitCommonMedalNode(achievementId)
            table.insert(achievements, achievementData)
        end
    end

    view.achievementClickBtn.onClick:RemoveAllListeners()
    view.achievementClickBtn.onClick:AddListener(function()
        if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Achievement) then
            return
        end
        local target = achievements[1]
        if target == nil then
            return
        end
        
        local achievementInfos = GameInstance.player.achievementSystem.achievementData.achievementInfos
        for _, achievementData in ipairs(achievements) do
            local found, playerInfo = achievementInfos:TryGetValue(achievementData.achieveId)
            if not found or playerInfo.level < achievementData.initLevel then
                target = achievementData
                break
            end
        end
        
        if not AchievementUtils.canShowAchievementInList(target.achieveId) then
            target = nil
            for _, achievementData in ipairs(achievements) do
                if AchievementUtils.canShowAchievementInList(achievementData.achieveId) then
                    target = achievementData
                    break
                end
            end
        end
        if target ~= nil then
            Notify(MessageConst.SHOW_ACHIEVEMENT, target.achieveId)
        end
    end)
end


function MultiplayerUtils.getGameAvailableTimeText(availableTimeId)
    local closeTimestamp, isValid = Utils.getTimeIdCloseTimeStamp(availableTimeId)
    if not isValid then
        return ""
    end
    if closeTimestamp == nil then
        return Language.LUA_MULTIPLAYER_GAME_LONG_TERM_OPEN
    end
    return string.format(Language.LUA_MULTIPLAYER_GAME_END_TIME, Utils.timestampToDateMDHM(closeTimestamp))
end

function MultiplayerUtils.isNewbieGuideDone(gameId)
    local found, info = GameInstance.player.multiplayerGameCenterSystem:TryGetGameInfo(gameId)
    return not found or info.newbieGuideDone
end

return MultiplayerUtils
