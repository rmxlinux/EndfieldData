local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerMatch
local PHASE_ID = PhaseId.MultiplayerMatch


MultiplayerMatchCtrl = HL.Class('MultiplayerMatchCtrl', uiCtrl.UICtrl)



local PANEL_MODE_CLICK_ACTIONS = {
    [MultiplayerConst.EMatchMode.CreateRoom] = "multiplayer_select_create_room",
    [MultiplayerConst.EMatchMode.QuickMatch] = "multiplayer_select_start_match",
}

local PLAY_NAVIGATION_ENABLED_STATES = {
    [MultiplayerConst.EClickState.CreateRoom] = true,
    [MultiplayerConst.EClickState.StartMatch] = true,
}



local MODE_PLAY_CELL_FILTERS = {
    [MultiplayerConst.EMatchMode.QuickMatch] = "_FilterNeedMatch",
}


local STATE_TICK_INTERVAL = 1





local function getNowSec()
    return DateTimeUtils.GetCurrentTimestampBySeconds()
end






MultiplayerMatchCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_GAME_STATUS_CHANGED] = '_OnGameStatusChanged',
    [MessageConst.ON_MULTIPLAYER_QUICK_MATCH_START_RSP] = '_OnQuickMatchStartRsp',
    [MessageConst.ON_MULTIPLAYER_QUICK_MATCH_CANCEL_RSP] = '_OnQuickMatchCancelRsp',
    [MessageConst.ON_MULTIPLAYER_ENTER_PLAY_ROOM] = '_OnEnterPlayRoom',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_RETURN] = '_OnPlayRoomReturn',
    [MessageConst.MULTIPLAYER_MATCH_SELECT_GAME] = '_OnSelectGame',
}



MultiplayerMatchCtrl.m_panelMode = HL.Field(HL.String) << ""

MultiplayerMatchCtrl.m_gameId = HL.Field(HL.String) << ""




MultiplayerMatchCtrl.m_gameData = HL.Field(HL.Any)

MultiplayerMatchCtrl.m_gameBackground = HL.Field(HL.Table)

MultiplayerMatchCtrl.m_gameBackgroundCache = HL.Field(HL.Table)
MultiplayerMatchCtrl.m_gameBackgroundAudioActive = HL.Field(HL.Boolean) << false
MultiplayerMatchCtrl.m_gameBackgroundAudioPlayingId = HL.Field(HL.Number) << 0


MultiplayerMatchCtrl.m_clickState = HL.Field(HL.String) << ""


MultiplayerMatchCtrl.m_exitAfterCancel = HL.Field(HL.Boolean) << false


MultiplayerMatchCtrl.m_stateEnterTime = HL.Field(HL.Number) << 0
MultiplayerMatchCtrl.m_cancelCoroutine = HL.Field(HL.Thread)


MultiplayerMatchCtrl.m_playCellCache = HL.Field(HL.Forward("UIListCache"))
MultiplayerMatchCtrl.m_playGameIds = HL.Field(HL.Table)




MultiplayerMatchCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_gameBackgroundCache = {}
    self.m_gameBackgroundAudioActive = true
    self.m_gameBackgroundAudioPlayingId = 0
    self.m_exitAfterCancel = false
    self.m_playGameIds = {}
    self:_ApplyPanelMode(arg)
    self:_InitUI()
    self:_RefreshPlayCellList(arg and arg.gameId or "")
    self:_SetClickState(self:_GetInitialClickState())
    self:_StartStateTick()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    LuaSystemManager.ps5MultiplayerSystem:TryShowPSOnlyNotice()
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
    CS.Beyond.Gameplay.Conditions.OnMultiplayerMatchPanelOpen.Trigger(
        self.m_panelMode == MultiplayerConst.EMatchMode.QuickMatch)
end

MultiplayerMatchCtrl._OnGameStatusChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:_RefreshPlayCellList(self.m_gameId, true)
end

MultiplayerMatchCtrl.OnShow = HL.Override() << function(self)
    if self.m_gameBackgroundAudioActive then
        return
    end
    self.m_gameBackgroundAudioActive = true
    
    self:_StartGameBackgroundLoop()
end

MultiplayerMatchCtrl.OnHide = HL.Override() << function(self)
    self.m_gameBackgroundAudioActive = false
    self:_StopGameBackgroundLoopAudio()
end

MultiplayerMatchCtrl.OnClose = HL.Override() << function(self)
    self.m_gameBackgroundAudioActive = false
    self:_StopGameBackgroundLoopAudio()
    for _, background in pairs(self.m_gameBackgroundCache) do
        MultiplayerUtils.clearGameBackground(background.gameObject)
    end
    self.m_gameBackgroundCache = nil
    self.m_gameBackground = nil
    LuaSystemManager.ps5MultiplayerSystem:TryClosePSOnlyNotice()
    
    self.view.playScrollList.enabled = true
end


MultiplayerMatchCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        mode = self.m_panelMode,
        gameId = self.m_gameId,
    }
end






MultiplayerMatchCtrl._InitUI = HL.Method() << function(self)
    self.view.btnBack.onClick:AddListener(function()
        self:_CloseSelf()
    end)
    self.view.helpBtn.onClick:AddListener(function()
        self:_OnHelpBtnClick()
    end)


    local click = self.view.clickStateNode
    click.clickBtn.onClick:ChangeBindingPlayerAction(PANEL_MODE_CLICK_ACTIONS[self.m_panelMode])
    click.clickBtn.onClick:AddListener(function()
        self:_OnClickBtnClick()
    end)
    
    
    click.cancelBtn:InitBinding()
    click.cancelBtn.onClick:ChangeBindingPlayerAction("multiplayer_select_cancel_match")
    click.cancelBtn.onClick:AddListener(function()
        self:_OnCancelBtnClick()
    end)
    click.trainBtn.onClick:AddListener(function()
        self:_OnTrainBtnClick()
    end)

    self.m_playCellCache = UIUtils.genCellCache(self.view.playCell)
end

MultiplayerMatchCtrl._CloseSelf = HL.Method() << function(self)
    if self.m_clickState == MultiplayerConst.EClickState.Matching then
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_MULTIPLAYER_QUICK_MATCH_EXIT_CONFIRM,
            onConfirm = function()
                self:_ConfirmCancelMatchAndExit()
            end,
            interrupt = {
                interruptMessage = {
                    MessageConst.ON_MULTIPLAYER_ENTER_PLAY_ROOM,
                    MessageConst.ON_MULTIPLAYER_QUICK_MATCH_CANCEL_RSP,
                },
            },
        })
        return
    end
    PhaseManager:PopPhase(PHASE_ID)
end

MultiplayerMatchCtrl._ConfirmCancelMatchAndExit = HL.Method() << function(self)
    self.m_exitAfterCancel = true
    self:_RequestCancelMatch()
end


MultiplayerMatchCtrl._OnHelpBtnClick = HL.Method() << function(self)
    local introKey = self.m_gameData and self.m_gameData.introKey or ""
    Notify(MessageConst.SHOW_INTRO, introKey)
end






MultiplayerMatchCtrl._ApplyPanelMode = HL.Method(HL.Any) << function(self, arg)
    local mode = arg and arg.mode or ""
    if mode ~= MultiplayerConst.EMatchMode.CreateRoom and mode ~= MultiplayerConst.EMatchMode.QuickMatch then
        logger.error("[MultiplayerMatchCtrl] invalid panel mode, fallback QuickMatch", mode)
        mode = MultiplayerConst.EMatchMode.QuickMatch
    end
    self.m_panelMode = mode
    self.view.main:SetState(mode)
end

MultiplayerMatchCtrl._GetInitialClickState = HL.Method().Return(HL.String) << function(self)
    if self.m_panelMode == MultiplayerConst.EMatchMode.CreateRoom then
        return MultiplayerConst.EClickState.CreateRoom
    end
    local status = GameInstance.player.multiplayerMatchSystem.quickStatus
    
    if status.isMatching and status.matchStartTime > 0 then
        return MultiplayerConst.EClickState.Matching
    end
    return MultiplayerConst.EClickState.StartMatch
end






MultiplayerMatchCtrl.SetGameId = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, gameId, isRefresh)
    self.m_gameId = gameId or ""
    self.m_gameData = nil

    if not string.isEmpty(self.m_gameId) then
        local found, data = Tables.multiplayerGameCenterTable:TryGetValue(self.m_gameId)
        if found then
            self.m_gameData = data
        end
        
    end

    self:_RefreshGameBackground(self.m_gameData and self.m_gameData.gameSelectBgName or "")
    self.view.gameTitleTxt.text = self.m_gameData and self.m_gameData.gameName or ""
    self.view.gameInfoNode:InitMultiplayerGameInfoNode({
        gameId = self.m_gameId,
    })
    
    if not isRefresh or self:IsShow() then
        MultiplayerUtils.setNewGameRead(self.m_gameId)
    end
end


MultiplayerMatchCtrl._RefreshGameBackground = HL.Method(HL.String) << function(self, prefabName)
    local background = self.m_gameBackgroundCache[prefabName]
    if background ~= nil and background == self.m_gameBackground then
        return
    end
    
    local previous = self.m_gameBackground
    self.m_gameBackground = nil
    self:_StopGameBackgroundLoopAudio()
    if previous ~= nil then
        previous.gameObject:SetActive(false)
    end
    if background == nil and not string.isEmpty(prefabName) then
        local instance = MultiplayerUtils.refreshGameBackground(self, self.view.deployNode, nil, prefabName)
        if instance ~= nil then
            background = Utils.wrapLuaNode(instance)
            self.m_gameBackgroundCache[prefabName] = background
        end
    end
    self.m_gameBackground = background
    if background ~= nil then
        background.gameObject:SetActive(true)
        self:_StartGameBackgroundLoop()
    end
end

MultiplayerMatchCtrl._StartGameBackgroundLoop = HL.Method() << function(self)
    local background = self.m_gameBackground
    if not self.m_gameBackgroundAudioActive or background == nil then
        return
    end
    local wrapper = background.cardLoopAnimationWrapper
    wrapper:PlayLoopAnimation()
    local tween = wrapper.curTween
    if tween == nil then
        return
    end
    
    tween.handler.onStepComplete = function()
        self:_PlayGameBackgroundLoopAudio(background)
    end
    self:_PlayGameBackgroundLoopAudio(background)
end


MultiplayerMatchCtrl._PlayGameBackgroundLoopAudio = HL.Method(HL.Table) << function(self, background)
    if not self.m_gameBackgroundAudioActive or background ~= self.m_gameBackground then
        return
    end
    local audioEvent = background.config.CARD_LOOP_AUDIO
    if string.isEmpty(audioEvent) then
        return
    end
    self:_StopGameBackgroundLoopAudio()
    self.m_gameBackgroundAudioPlayingId = CS.Beyond.Audio.AudioAdapter.PostEvent(audioEvent)
end

MultiplayerMatchCtrl._StopGameBackgroundLoopAudio = HL.Method() << function(self)
    if self.m_gameBackgroundAudioPlayingId ~= 0 then
        CS.Beyond.Audio.AudioAdapter.StopByPlayingId(self.m_gameBackgroundAudioPlayingId, 0)
        self.m_gameBackgroundAudioPlayingId = 0
    end
end


MultiplayerMatchCtrl._FilterNeedMatch = HL.Method(HL.Any).Return(HL.Boolean) << function(self, data)
    return data.needMatch
end


MultiplayerMatchCtrl._RefreshPlayCellList = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, argGameId, isRefresh)
    
    local filterName = MODE_PLAY_CELL_FILTERS[self.m_panelMode]
    local playDatas = {}
    for _, data in pairs(Tables.multiplayerGameCenterTable) do
        if GameInstance.player.multiplayerGameCenterSystem:IsGameVisible(data.gameId)
            and (string.isEmpty(filterName) or self[filterName](self, data)) then
            table.insert(playDatas, data)
        end
    end
    table.sort(playDatas, Utils.genSortFunction({ "sortId" }, true))

    local playGameIds = {}
    local firstUnlockedIndex = 0
    local restoredIndex = 0
    for index, data in ipairs(playDatas) do
        table.insert(playGameIds, data.gameId)
        if GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(data.gameId) then
            if firstUnlockedIndex == 0 then
                firstUnlockedIndex = index
            end
            if data.gameId == argGameId then
                restoredIndex = index
            end
        end
    end
    self.m_playGameIds = playGameIds

    
    local defaultIndex = restoredIndex > 0 and restoredIndex or firstUnlockedIndex
    local defaultGameId = defaultIndex > 0 and playGameIds[defaultIndex] or ""
    local status = GameInstance.player.multiplayerMatchSystem.quickStatus
    if isRefresh and status.isMatching then
        
        defaultGameId = argGameId
        defaultIndex = 0
        for index, gameId in ipairs(playGameIds) do
            if gameId == argGameId then
                defaultIndex = index
                break
            end
        end
    end
    self:SetGameId(defaultGameId, isRefresh)

    self.m_playCellCache:Refresh(#playGameIds, function(cell, index)
        cell:InitMultiplayerMatchPlayCell({
            gameId = playGameIds[index],
            onClick = function(clickedGameId)
                self:_OnPlayCellClick(clickedGameId)
            end,
        })
    end)

    if defaultIndex > 0 then
        local cell = self.m_playCellCache:GetItem(defaultIndex)
        if cell then
            cell:SetSelected(true)
        end
    end
end


MultiplayerMatchCtrl._SetSelectedPlayCellNaviTarget = HL.Method() << function(self)
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(self.m_gameId) then
        return
    end
    for index, gameId in ipairs(self.m_playGameIds) do
        if gameId == self.m_gameId then
            local cell = self.m_playCellCache:GetItem(index)
            if cell then
                self:SetNaviTarget(cell.view.clickBtn)
            end
            return
        end
    end
end


MultiplayerMatchCtrl._OnPlayCellClick = HL.Method(HL.String) << function(self, gameId)
    self:_SelectPlayCell(gameId)
end


MultiplayerMatchCtrl._OnSelectGame = HL.Method(HL.Any) << function(self, args)
    local gameId = unpack(args)
    if string.isEmpty(gameId) then
        return
    end
    if self:_SelectPlayCell(gameId) then
        self:_SetSelectedPlayCellNaviTarget()
    end
end

MultiplayerMatchCtrl._SelectPlayCell = HL.Method(HL.String).Return(HL.Boolean) << function(self, gameId)
    if self.m_clickState ~= MultiplayerConst.EClickState.StartMatch
        and self.m_clickState ~= MultiplayerConst.EClickState.CreateRoom then
        return false
    end
    
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(gameId) then
        return false
    end

    local oldIndex, newIndex = 0, 0
    for index, id in ipairs(self.m_playGameIds) do
        if id == self.m_gameId then
            oldIndex = index
        end
        if id == gameId then
            newIndex = index
        end
    end

    if newIndex == 0 then
        return false
    end
    if gameId == self.m_gameId then
        return true
    end

    if oldIndex > 0 then
        local oldCell = self.m_playCellCache:GetItem(oldIndex)
        if oldCell then
            oldCell:SetSelected(false)
        end
    end
    self:SetGameId(gameId)
    local newCell = self.m_playCellCache:GetItem(newIndex)
    if newCell then
        newCell:SetSelected(true)
    end
    return true
end






MultiplayerMatchCtrl._OnClickBtnClick = HL.Method() << function(self)
    if self.m_clickState == MultiplayerConst.EClickState.StartMatch then
        self:_RequestStartMatch()
    elseif self.m_clickState == MultiplayerConst.EClickState.CreateRoom then
        self:_RequestCreateRoom()
    end
end


MultiplayerMatchCtrl._OnCancelBtnClick = HL.Method() << function(self)
    if self.m_clickState == MultiplayerConst.EClickState.Matching then
        self.m_exitAfterCancel = false
        self:_RequestCancelMatch()
    end
end



MultiplayerMatchCtrl._OnTrainBtnClick = HL.Method() << function(self)
    local gameId = self.m_gameId
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(gameId) then
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_MULTIPLAYER_TRAINING_ENTER_CONFIRM,
        onConfirm = function()
            self:_RequestTraining(gameId)
        end,
    })
end

MultiplayerMatchCtrl._RequestTraining = HL.Method(HL.String) << function(self, gameId)
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(gameId) then
        return
    end
    if MultiplayerUtils.isNewbieGuideDone(gameId) then
        GameInstance.player.multiplayerMatchSystem:SendStartAllNpcRoom(gameId)
    else
        GameInstance.player.multiplayerMatchSystem:SendCreateNewbieGuidePlayRoom(gameId)
    end
end

MultiplayerMatchCtrl._RequestCreateRoom = HL.Method() << function(self)
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(self.m_gameId) then
        return
    end
    GameInstance.player.multiplayerMatchSystem:NewRoom(self.m_gameId)
    
end

MultiplayerMatchCtrl._RequestStartMatch = HL.Method() << function(self)
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(self.m_gameId) then
        return
    end
    
    GameInstance.player.multiplayerMatchSystem:SendQuickMatchStartReq(self.m_gameData.quickMatchType)
    
    
end

MultiplayerMatchCtrl._RequestCancelMatch = HL.Method() << function(self)
    GameInstance.player.multiplayerMatchSystem:SendQuickMatchCancelReq()
    
    
end

MultiplayerMatchCtrl._OnPlayRoomReturn = HL.Method(HL.Opt(HL.Number)) << function(self, returnTarget)
    if returnTarget ~= MultiplayerConst.EPlayRoomReturn.QuickMatch
        or self.m_panelMode ~= MultiplayerConst.EMatchMode.QuickMatch then
        return
    end
    if MultiplayerUtils.checkAllGamesClosed()
        or self.m_clickState ~= MultiplayerConst.EClickState.StartMatch then
        return
    end

    local status = GameInstance.player.multiplayerMatchSystem.quickStatus
    if status == nil or status.isMatching then
        return
    end
    local enterPlayRoomInfo = GameInstance.player.multiplayerMatchSystem.enterPlayRoom
    local playRoomKind = CS.Beyond.Gameplay.MultiplayerMatchSystem.PlayRoomKind
    if enterPlayRoomInfo and (enterPlayRoomInfo.playRoomKind == playRoomKind.NewbieGuide
        or enterPlayRoomInfo.playRoomKind == playRoomKind.Training) then
        self:_RequestTraining(enterPlayRoomInfo.gameId)
    else
        self:_RequestStartMatch()
    end
end


MultiplayerMatchCtrl._OnQuickMatchStartRsp = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self.m_clickState ~= MultiplayerConst.EClickState.StartMatch then
        return
    end
    self:_SetClickState(MultiplayerConst.EClickState.Matching)
end


MultiplayerMatchCtrl._OnQuickMatchCancelRsp = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self.m_clickState ~= MultiplayerConst.EClickState.Matching then
        return
    end
    if self.m_exitAfterCancel then
        self.m_exitAfterCancel = false
        PhaseManager:PopPhase(PHASE_ID)
        return
    end
    
    self:_SetClickState(MultiplayerConst.EClickState.Cancel)
end




MultiplayerMatchCtrl._OnEnterPlayRoom = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if self.m_panelMode ~= MultiplayerConst.EMatchMode.QuickMatch then
        return
    end
    
    self.m_exitAfterCancel = false
    self:_RefreshClickStateFromQuickStatus()
end


MultiplayerMatchCtrl._RefreshClickStateFromQuickStatus = HL.Method() << function(self)
    local target = self:_GetInitialClickState()
    if self.m_clickState == target then
        return
    end
    self:_SetClickState(target)
end

MultiplayerMatchCtrl._SetClickState = HL.Method(HL.String) << function(self, state)
    if self.m_cancelCoroutine then
        self.m_cancelCoroutine = self:_ClearCoroutine(self.m_cancelCoroutine)
    end
    self.m_clickState = state
    self.m_stateEnterTime = state == MultiplayerConst.EClickState.Matching
        and GameInstance.player.multiplayerMatchSystem.quickStatus.matchStartTime or getNowSec()

    local click = self.view.clickStateNode
    click.clickNodeState:SetState(state)
    
    click.trainBtn.gameObject:SetActiveIfNecessary(state ~= MultiplayerConst.EClickState.Matching)

    
    self.view.btnBack.interactable = state == MultiplayerConst.EClickState.Matching
        or state == MultiplayerConst.EClickState.StartMatch
        or state == MultiplayerConst.EClickState.CreateRoom

    local playNavigationEnabled = PLAY_NAVIGATION_ENABLED_STATES[state] == true
    self.view.playScrollList.enabled = playNavigationEnabled
    if playNavigationEnabled then
        self:_SetSelectedPlayCellNaviTarget()
    end

    if state == MultiplayerConst.EClickState.Matching then
        
        click.matchingTimeTxt.text = UIUtils.getLeftTimeToSecond(math.max(0, getNowSec() - self.m_stateEnterTime))
    elseif state == MultiplayerConst.EClickState.Cancel or state == MultiplayerConst.EClickState.Offline then
        
        
        local endTime = Time.realtimeSinceStartup + click.cancelLight:GetClip("click_cancellight_in").length
        self.m_cancelCoroutine = self:_StartCoroutine(function()
            while Time.realtimeSinceStartup < endTime do
                coroutine.step()
            end
            
            coroutine.waitForRenderDone()
            self.m_cancelCoroutine = nil
            self:_RefreshClickStateFromQuickStatus()
        end)
    end
end



MultiplayerMatchCtrl._StartStateTick = HL.Method() << function(self)
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(STATE_TICK_INTERVAL)
            self:_TickState()
        end
    end)
end

MultiplayerMatchCtrl._TickState = HL.Method() << function(self)
    for index, _ in ipairs(self.m_playGameIds) do
        self.m_playCellCache:GetItem(index):RefreshAvailableTime()
    end
    local elapsed = math.max(0, getNowSec() - self.m_stateEnterTime)
    local state = self.m_clickState
    local click = self.view.clickStateNode

    if state == MultiplayerConst.EClickState.Matching then
        
        click.matchingTimeTxt.text = UIUtils.getLeftTimeToSecond(elapsed)
    end
end



HL.Commit(MultiplayerMatchCtrl)
