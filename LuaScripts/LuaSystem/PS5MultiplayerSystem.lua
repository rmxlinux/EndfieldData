local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')


PS5MultiplayerSystem = HL.Class('PS5MultiplayerSystem', LuaSystemBase.LuaSystemBase)

local MAIN_HUD_QUEUE_ACTION_TYPE = "PS5GameIntent"
local PS_ONLY_NOTICE_DAILY_KEY = "MULTIPLAYER_PS_ONLY_NOTICE_DAILY"
local PS_ONLY_NOTICE_DATA_CATEGORY = "Multiplayer"


local PS_ONLY_NOTICE_PANELS = {
    PanelId.MultiplayerMain,
    PanelId.MultiplayerMatch,
    PanelId.MultiplayerEnterRoom,
    PanelId.MultiplayerRoom,
}

PS5MultiplayerSystem.OnInit = HL.Override() << function(self)
    if not UNITY_PS5 then
        return
    end

    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PS5_JOIN_SESSION_RECEIVED, function(_)
        self:_OnMultiplayerPS5JoinSessionReceived() 
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PS5_JOIN_SESSION_SUCCEEDED, function(_)
        self:_OnMultiplayerPS5JoinSessionSucceeded() 
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PS5_JOIN_SESSION_FAILED, function(args)
        self:_OnMultiplayerPS5JoinSessionFailed(args) 
    end)
    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_PS5_JOIN_SESSION_EXPIRED, function(_)
        self:_OnMultiplayerPS5JoinSessionExpired() 
    end)

    self:RegisterMessage(MessageConst.ON_MULTIPLAYER_ENTER_PLAY_ROOM, function(_)
        self:_ClosePSOnlyNotice()
    end)

    
    self:_OnMultiplayerPS5JoinSessionReceived()
end


PS5MultiplayerSystem.OnRelease = HL.Override() << function(self)
    UIManager:Close(PanelId.MultiplayerPSOnlyNotice)
end




PS5MultiplayerSystem._CanShowPSOnlyNotice = HL.Method().Return(HL.Boolean) << function(self)
    local enterPlayRoomInfo = GameInstance.player.multiplayerMatchSystem.enterPlayRoom
    return FriendUtils.isPsnPlatform()
        and GameInstance.player.friendSystem.isPSNOnly
        and (enterPlayRoomInfo == nil
            or enterPlayRoomInfo.playRoomKind == CS.Beyond.Gameplay.MultiplayerMatchSystem.PlayRoomKind.None)
        and not GameInstance.player.multiplayerPlayRoomSystem.inRoom
end


PS5MultiplayerSystem.TryShowPSOnlyNotice = HL.Method(HL.Opt(HL.Number)) << function(self, duration)
    if not self:_CanShowPSOnlyNotice() then
        return
    end
    if UIManager:IsOpen(PanelId.MultiplayerPSOnlyNotice) then
        return
    end
    local _, shownToday = ClientDataManagerInst:GetBool(
        PS_ONLY_NOTICE_DAILY_KEY, false, false, PS_ONLY_NOTICE_DATA_CATEGORY)
    if shownToday then
        return
    end
    local ctrl = UIManager:Open(PanelId.MultiplayerPSOnlyNotice, { duration = duration })
    if ctrl then
        
        ClientDataManagerInst:SetBool(PS_ONLY_NOTICE_DAILY_KEY, true, false,
            PS_ONLY_NOTICE_DATA_CATEGORY, EClientDataTimeValidType.CurrentDayUntil4AM)
    end
end


PS5MultiplayerSystem.TryClosePSOnlyNotice = HL.Method() << function(self)
    for _, panelId in ipairs(PS_ONLY_NOTICE_PANELS) do
        if UIManager:IsOpen(panelId) then
            return
        end
    end
    self:_ClosePSOnlyNotice()
end

PS5MultiplayerSystem._ClosePSOnlyNotice = HL.Method() << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PanelId.MultiplayerPSOnlyNotice)
    if isOpen then
        ctrl:PlayAnimationOutAndClose()
    end
end






PS5MultiplayerSystem._IsJoinSessionAllowed = HL.Method().Return(HL.Boolean) << function(self)
    if GameInstance.player.ps5MultiplayerSystem.isJoinSessionInProgress then
        return false 
    end

    if GameInstance.player.multiplayerMatchSystem.isInMatchRoom then
        return false 
    end
    if GameInstance.player.multiplayerMatchSystem.quickStatus.isMatching then
        return false 
    end
    if GameInstance.player.multiplayerPlayRoomSystem.inRoom then
        return false 
    end

    if UIManager:IsShow(PanelId.SDKApplicationMask) then
        return false 
    end

    if Utils.isInDungeon() then
        return false 
    end
    if GameInstance.player.innSystem.isInGame then
        return false 
    end

    if GameInstance.player.guide.isInForceGuide then
        return false 
    end
    if Utils.isInFocusMode() then
        return false 
    end
    if Utils.isNarrativeTopPhase() then
        return false 
    end
    if UIUtils.inCG() then
        return false 
    end

    if GameWorld.gameMechManager.travelPoleBrain.inFastTravelMode then
        return false 
    end
    if GameWorld.gameMechManager.sweetPieBrain:IsSweetPieFlighting() then
        return false 
    end
    if FactoryUtils.isInBuildMode() then
        return false 
    end
    if LuaSystemManager.factory.inDestroyMode then
        return false 
    end
    if FactoryUtils.isCreatingBlueprint() then
        return false 
    end
    if Utils.isInSettlementDefense() then
        return false 
    end

    return true
end

PS5MultiplayerSystem._EnqueueJoinSession = HL.Method() << function(self)
    
    Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_ENQUEUE_TOAST)
    
    GameInstance.player.ps5MultiplayerSystem:StartJoinSessionCountdown()

    if LuaSystemManager.mainHudActionQueue:HasRequest(MAIN_HUD_QUEUE_ACTION_TYPE) then
        return 
    end

    LuaSystemManager.mainHudActionQueue:AddRequest(MAIN_HUD_QUEUE_ACTION_TYPE, function()
        if not self:_JoinSessionImmediately() then
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, MAIN_HUD_QUEUE_ACTION_TYPE)
            return
        end
    end)
end

PS5MultiplayerSystem._JoinSessionImmediately = HL.Method().Return(HL.Boolean) << function(self)
    if not GameInstance.player.ps5MultiplayerSystem:HasJoinSession() then
        return false 
    end
    if not self:_IsJoinSessionAllowed() then
        
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_NOT_ALLOWED_TOAST)
        GameInstance.player.ps5MultiplayerSystem:ClearJoinSession()
        return false
    end

    return GameInstance.player.ps5MultiplayerSystem:AcceptJoinSession()
end






PS5MultiplayerSystem._OnMultiplayerPS5JoinSessionReceived = HL.Method() << function(self)
    if not GameInstance.player.ps5MultiplayerSystem:HasJoinSession() then
        return 
    end
    if not self:_IsJoinSessionAllowed() then
        
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_NOT_ALLOWED_TOAST)
        GameInstance.player.ps5MultiplayerSystem:ClearJoinSession()
        return
    end

    
    GameInstance.player.ps5MultiplayerSystem:CheckPremium(function(authorized)
        if not GameInstance.player.ps5MultiplayerSystem:HasJoinSession() then
            return 
        end
        if not authorized then
            GameInstance.player.ps5MultiplayerSystem:ClearJoinSession()
            return 
        end
        self:_EnqueueJoinSession()
    end)
end

PS5MultiplayerSystem._OnMultiplayerPS5JoinSessionSucceeded = HL.Method() << function(self)
    
    
end

PS5MultiplayerSystem._OnMultiplayerPS5JoinSessionFailed = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    
    LuaSystemManager.mainHudActionQueue:RemoveActionsOfType(MAIN_HUD_QUEUE_ACTION_TYPE)

    local resultCode = unpack(args)
    if resultCode == CS.Beyond.Gameplay.PS5MultiplayerResultCode.MatchRoomGameNotAvailable then
        
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_MATCH_ROOM_GAME_NOT_AVAILABLE_TOAST)
    else
        
        Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_FAILED_TOAST)
    end
end

PS5MultiplayerSystem._OnMultiplayerPS5JoinSessionExpired = HL.Method() << function(self)
    
    Notify(MessageConst.SHOW_TOAST, Language.LUA_MULTIPLAYER_PS5_JOIN_SESSION_EXPIRED_TOAST)
end




HL.Commit(PS5MultiplayerSystem)
return PS5MultiplayerSystem
