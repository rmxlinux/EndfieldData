local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerSuccess


MultiplayerSuccessCtrl = HL.Class('MultiplayerSuccessCtrl', uiCtrl.UICtrl)


MultiplayerSuccessCtrl.m_enterPlayRoomInfo = HL.Field(HL.Any)

MultiplayerSuccessCtrl.m_playerCellCache = HL.Field(HL.Forward("UIListCache"))
MultiplayerSuccessCtrl.m_successFlowStarted = HL.Field(HL.Boolean) << false
MultiplayerSuccessCtrl.m_successOutStarted = HL.Field(HL.Boolean) << false






MultiplayerSuccessCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_CREATE] = '_OnPlayRoomCreate',
}


MultiplayerSuccessCtrl.ShowMultiplayerSuccess = HL.StaticMethod(HL.Any) << function(args)
    local enterPlayRoomInfo = args and unpack(args) or nil
    local isRoom = PhaseManager:IsOpen(PhaseId.MultiplayerRoom)
    local phaseId = isRoom and PhaseId.MultiplayerRoom or PhaseId.MultiplayerMatch
    local panelId = isRoom and PanelId.MultiplayerRoom or PanelId.MultiplayerMatch
    local isOpen, ctrl = UIManager:IsOpen(panelId)
    if not isOpen or not PhaseManager:IsOpen(phaseId) then
        UIManager:Open(PANEL_ID, enterPlayRoomInfo)
        return
    end

    
    ctrl:_StartCoroutine(function()
        while PhaseManager:IsInPhaseTransition() do
            coroutine.step()
        end
        if not PhaseManager:IsOpen(phaseId) then
            return
        end
        PhaseManager:ExitPhaseFastTo(phaseId)
        MultiplayerUtils.closeMatchOverlayPanels(isRoom)
        UIManager:Open(PANEL_ID, enterPlayRoomInfo)
    end)
end


MultiplayerSuccessCtrl.FinishMultiplayerSuccessFlow = HL.StaticMethod(HL.Opt(HL.Any)) << function(args)
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        
        ctrl:Close()
    end
end


MultiplayerSuccessCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_enterPlayRoomInfo = arg
    self.m_successFlowStarted = false
    self.m_successOutStarted = false
    self.m_playerCellCache = UIUtils.genCellCache(self.view.playerCell)

    
    local gameId = arg and arg.gameId or ""
    self.view.main:SetState(gameId)
    self.view.infoNode:InitMultiplayerGameInfoNode({
        gameId = gameId,
    })
    self:_RefreshMembers()
    if arg and arg.matchRoomFull then
        self.view.textState:SampleToInAnimationEnd()
    else
        self.view.textState:SampleToInAnimationBegin()
    end
    self:PlayAnimationIn()
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
end

MultiplayerSuccessCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if self.m_successFlowStarted then
        return
    end
    self.m_successFlowStarted = true
    local onComplete = function()
        GameInstance.player.multiplayerMatchSystem:SendReportReady()
    end
    if self.m_enterPlayRoomInfo and self.m_enterPlayRoomInfo.matchRoomFull then
        onComplete()
    else
        self.view.textState:PlayInAnimation(onComplete)
    end
end

MultiplayerSuccessCtrl._RefreshMembers = HL.Method() << function(self)
    local info = self.m_enterPlayRoomInfo
    local members = info and info.members or nil
    local memberCount = members and members.Count or 0

    self.m_playerCellCache:Refresh(memberCount, function(cell, index)
        local briefData = members[CSIndex(index)]
        local isSelf = briefData ~= nil and briefData.roleId == GameInstance.player.roleId
        cell.view.playerCell.gameObject:SetActiveIfNecessary(true)
        cell:InitMultiplayerRoomPlayerCell({
            briefData = briefData,
            nodeState = MultiplayerConst.EPlayerCellState.MatchSucc,
            ownerState = MultiplayerConst.EPlayerCellState.NotOwner,
            selfState = isSelf and MultiplayerConst.EPlayerCellState.Myself
                or MultiplayerConst.EPlayerCellState.Other,
        })
        if briefData ~= nil and not string.isEmpty(briefData.npcTplId) then
            self:_InitNpcPlayerCell(cell, briefData.npcTplId)
        end
    end)
end

MultiplayerSuccessCtrl._InitNpcPlayerCell = HL.Method(HL.Any, HL.String) << function(self, cell, npcTplId)
    local playerCell = cell.view.playerCell
    local found, npcCfg = Tables.multiplayerNpcPoolInfoTable:TryGetValue(npcTplId)
    if not found or npcCfg == nil then
        logger.error(string.format(
                "[MultiplayerSuccessCtrl] multiplayerNpcPoolInfoTable 查不到 npcTplId=%s", npcTplId))
        playerCell.gameObject:SetActiveIfNecessary(false)
        return
    end

    local avatarIcon = ""
    if not string.isEmpty(npcCfg.avatarId) then
        avatarIcon = Tables.userAvatarTable:GetValue(npcCfg.avatarId).icon
    end
    local avatarFrameIcon = ""
    if not string.isEmpty(npcCfg.avatarFrameId) then
        avatarFrameIcon = Tables.userAvatarTableFrame:GetValue(npcCfg.avatarFrameId).icon
    end

    playerCell:InitMultiplayerPlayerCellByDisplayInfo({
        nickname = npcCfg.nickname,
        signature = npcCfg.signature,
        avatarIcon = avatarIcon,
        avatarFrameIcon = avatarFrameIcon,
        cardTopicId = npcCfg.cardTopicId,
        adventureLevel = 0,
        psName = "",
    })
end


MultiplayerSuccessCtrl._OnPlayRoomCreate = HL.Method(HL.Any) << function(self, arg)
    if self.m_successOutStarted then
        return
    end
    self.m_successOutStarted = true
    local gameType = unpack(arg)
    self:PlayAnimationOutWithCallback(function()
        Notify(MessageConst.ON_MULTIPLAYER_SUCCESS_ANIM_OUT_FINISH, { gameType })
    end)
end





MultiplayerSuccessCtrl.OnClose = HL.Override() << function(self)
    
    self.view.textState:ClearTween(false)
end




HL.Commit(MultiplayerSuccessCtrl)
