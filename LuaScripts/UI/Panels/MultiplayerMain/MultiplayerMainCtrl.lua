local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MultiplayerMain
local PHASE_ID = PhaseId.MultiplayerMain
local INVITATION_PANEL_ID = PanelId.MultiplayerRoomInvitation
local ACTIVITY_ID = MultiplayerConst.CARD_GAME_ACTIVITY_ID

local SCROLL_PRE_ACTION_ID = "multiplayer_main_scroll_pre"
local SCROLL_NEXT_ACTION_ID = "multiplayer_main_scroll_next"


MultiplayerMainCtrl = HL.Class('MultiplayerMainCtrl', uiCtrl.UICtrl)






MultiplayerMainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_GAME_STATUS_CHANGED] = '_OnGameStatusChanged',
    [MessageConst.ON_UI_PHASE_OPENED] = '_RefreshBannerActivity',
    [MessageConst.ON_UI_PHASE_EXITED] = '_OnBannerPhaseExited',
    [MessageConst.ON_MULTIPLAYER_ALL_GAMES_CLOSED] = '_OnAllGamesClosed',
    [MessageConst.ON_FRIEND_BUSINESS_INFO_CHANGE] = '_RefreshPlayerCell',
    [MessageConst.ON_MULTIPLAYER_CARD_GAME_SET_CHAR_RSP] = '_RefreshCharHeadIcon',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_RETURN] = '_OnPlayRoomReturn',
    [MessageConst.RECV_FRIEND_SEND_CHAT_NOTIFY] = '_OnFriendChatNotify',
}


MultiplayerMainCtrl.m_bannerDatas = HL.Field(HL.Table)
MultiplayerMainCtrl.m_curBannerIndex = HL.Field(HL.Number) << 0
MultiplayerMainCtrl.m_curBannerView = HL.Field(HL.Table)
MultiplayerMainCtrl.m_bannerAudioPlayingId = HL.Field(HL.Number) << 0
MultiplayerMainCtrl.m_bannerActive = HL.Field(HL.Boolean) << false


MultiplayerMainCtrl.m_bannerPrefabCache = HL.Field(HL.Table)

MultiplayerMainCtrl.m_bannerViews = HL.Field(HL.Table)
MultiplayerMainCtrl.m_genBannerPageTabCells = HL.Field(HL.Forward("UIListCache"))
MultiplayerMainCtrl.m_bannerTimer = HL.Field(HL.Number) << -1
MultiplayerMainCtrl.m_bannerPreBindingId = HL.Field(HL.Number) << -1
MultiplayerMainCtrl.m_bannerNextBindingId = HL.Field(HL.Number) << -1


MultiplayerMainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_bannerDatas = {}
    self.m_bannerPrefabCache = {}
    self.m_bannerViews = {}
    self.m_curBannerIndex = 0
    self.m_curBannerView = nil
    self.m_bannerActive = false
    self:_InitUI()
    self:_InitActivityEntries()
    self:_RefreshPlayerCell()
    self:_RefreshCharHeadIcon()
    AudioManager.PostEvent("au_music_gambling_v1d7")
    self:_InitBanner()
    if PhaseManager.isRecovering then
        self.animationWrapper:SkipInAnimation()
    end
    LuaSystemManager.ps5MultiplayerSystem:TryShowPSOnlyNotice()
    if arg and arg.enterRoomArg then
        UIManager:Open(PanelId.MultiplayerEnterRoom, arg.enterRoomArg)
    end
end

MultiplayerMainCtrl.OnShow = HL.Override() << function(self)
    MultiplayerUtils.checkAllGamesClosed()
    if not InputManagerInst.inChangingInputDevice then
        AudioManager.PostEvent("au_music_gambling_v1d7_hall")
    end
    self:_RefreshBannerActivity()
end

MultiplayerMainCtrl.OnHide = HL.Override() << function(self)
    self:_SetBannerActive(false)
    if self.m_curBannerView then
        self.m_curBannerView.inAnimationWrapper:SkipInAnimation()
    end
end

MultiplayerMainCtrl.OnClose = HL.Override() << function(self)
    UIManager:Close(PanelId.MultiplayerEnterRoom)
    LuaSystemManager.ps5MultiplayerSystem:TryClosePSOnlyNotice()
    self:_SetBannerActive(false)
    self.m_curBannerView = nil
    for _, bannerView in pairs(self.m_bannerViews) do
        CSUtils.ClearUIComponents(bannerView.gameObject)
        GameObject.DestroyImmediate(bannerView.gameObject)
    end
    self.m_bannerViews = {}
    self.m_bannerPrefabCache = {}
    self.m_genBannerPageTabCells:ClearAll()
    AudioManager.PostEvent("au_music_meta_ui_stop")
end


MultiplayerMainCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    if PhaseManager:GetTopPhaseId() ~= PHASE_ID then
        return
    end
    local isOpen, ctrl = UIManager:IsOpen(PanelId.MultiplayerEnterRoom)
    if isOpen and ctrl:IsShow() then
        return { enterRoomArg = ctrl:GetRecoverState() }
    end
end





MultiplayerMainCtrl._InitUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        self:_CloseSelf()
    end)
    self.view.enterRoomBtn.onClick:AddListener(function()
        self:_OnEnterRoomBtnClick()
    end)
    self.view.quickMatchBtn.onClick:AddListener(function()
        self:_OnQuickMatchBtnClick()
    end)
    self.view.ruleBtn.onClick:AddListener(function()
        self:_OnRuleBtnClick()
    end)
    self.view.charBtn.onClick:AddListener(function()
        MultiplayerUtils.openCharSelect()
    end)
    self.view.quickMatchRedDot:InitRedDot("MultiplayerNewGameEntry")
    MultiplayerUtils.initAchievementMedals(self.view)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

MultiplayerMainCtrl._InitActivityEntries = HL.Method() << function(self)
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(ACTIVITY_ID)
    
    local hasTaskJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.taskJumpId)
    if self.view.taskEntryBtn then
        if hasTaskJump then
            self.view.taskEntryBtn:InitActivityTaskEntry({activityId = ACTIVITY_ID})
        else
            self.view.taskEntryBtn.gameObject:SetActive(false)
        end
    end
    
    local hasShopJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.shopJumpId)
    if self.view.shopEntryBtn then
        if hasShopJump then
            self.view.shopEntryBtn:InitActivityShopEntry({activityId = ACTIVITY_ID})
        else
            self.view.shopEntryBtn.gameObject:SetActive(false)
        end
    end
end

MultiplayerMainCtrl._RefreshCharHeadIcon = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    MultiplayerUtils.refreshCharHeadIcon(self.view.headIcon, MultiplayerUtils.getSelfDisplayCharTemplateId())
end


MultiplayerMainCtrl._RefreshPlayerCell = HL.Method() << function(self)
    local roleId = GameInstance.player.roleId
    local friendInfo = GameInstance.player.friendSystem.SelfInfo
    local openBusinessCard = function()
        MultiplayerUtils.openBusinessCard(roleId)
    end
    self.view.infoBtn.onClick:RemoveAllListeners()
    self.view.infoBtn.onClick:AddListener(openBusinessCard)
    self.view.playerCell:InitMultiplayerPlayerCell(roleId, friendInfo, openBusinessCard, openBusinessCard)
end



MultiplayerMainCtrl._InitBanner = HL.Method() << function(self)
    self.m_genBannerPageTabCells = UIUtils.genCellCache(self.view.pageTabCell)
    self:_InitBannerDrag()
    self:_InitBannerController()
    self:_RefreshBanner()
end

MultiplayerMainCtrl._OnGameStatusChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:_RefreshBanner()
    if not GameInstance.player.multiplayerGameCenterSystem.areAllGamesClosed then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU)
    end
end

MultiplayerMainCtrl._OnAllGamesClosed = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    MultiplayerUtils.checkAllGamesClosed()
end

MultiplayerMainCtrl._RefreshBanner = HL.Method() << function(self)
    local currentData = self.m_bannerDatas[self.m_curBannerIndex]
    self:_LoadBannerData()
    local currentIndex = 0
    local availableGameIds = {}
    for index, data in ipairs(self.m_bannerDatas) do
        availableGameIds[data.gameId] = true
        if currentData and data.gameId == currentData.gameId then
            currentIndex = index
        end
    end
    for gameId, bannerView in pairs(self.m_bannerViews) do
        if not availableGameIds[gameId] then
            if bannerView == self.m_curBannerView then
                self:_StopBannerAudio()
                self.m_curBannerView = nil
            end
            bannerView.inAnimationWrapper:SkipInAnimation()
            bannerView.gameObject:SetActive(false)
        end
    end
    self.m_curBannerIndex = currentIndex
    local count = #self.m_bannerDatas
    self.view.bgRoot.gameObject:SetActive(count > 0)
    self.m_genBannerPageTabCells:Refresh(count)
    if currentIndex > 0 and self.m_curBannerView then
        self:_RefreshBannerPageTabs()
    elseif count > 0 then
        self:_ShowBanner(math.max(currentIndex, 1))
    else
        self.m_curBannerView = nil
    end
    
    local canScroll = count > 1
    self.view.bannerDragHandler.gameObject:SetActive(canScroll)
    self.view.scrollKeyHintNode.gameObject:SetActive(canScroll)
    InputManagerInst:ToggleBinding(self.m_bannerPreBindingId, canScroll)
    InputManagerInst:ToggleBinding(self.m_bannerNextBindingId, canScroll)
    self:_ResetBannerTimer()
end


MultiplayerMainCtrl._InitBannerDrag = HL.Method() << function(self)
    
    self.view.bannerDragHandler.onBeginDrag:AddListener(function(eventData)
        if eventData.button ~= CS.UnityEngine.EventSystems.PointerEventData.InputButton.Left then
            return
        end
        local delta = eventData.position - eventData.pressPosition
        if math.abs(delta.x) <= math.abs(delta.y) then
            return
        end
        self:_ScrollBanner(delta.x < 0)
    end)
end

MultiplayerMainCtrl._InitBannerController = HL.Method() << function(self)
    self.m_bannerPreBindingId = self:BindInputPlayerAction(SCROLL_PRE_ACTION_ID, function()
        self:_ScrollBanner(false)
    end)
    self.m_bannerNextBindingId = self:BindInputPlayerAction(SCROLL_NEXT_ACTION_ID, function()
        self:_ScrollBanner(true)
    end)
end

MultiplayerMainCtrl._ScrollBanner = HL.Method(HL.Boolean) << function(self, pageDown)
    local count = #self.m_bannerDatas
    if count <= 1 or not self.m_bannerActive then
        return
    end
    local offset = pageDown and 1 or -1
    local index = (self.m_curBannerIndex - 1 + offset) % count + 1
    self:_ShowBanner(index)
    self:_ResetBannerTimer()
end

MultiplayerMainCtrl._ShowBanner = HL.Method(HL.Number) << function(self, index)
    self:_StopBannerAudio()
    if self.m_curBannerView then
        
        self.m_curBannerView.inAnimationWrapper:SkipInAnimation()
    end
    self.m_curBannerIndex = index
    local bannerView = self:_GetBannerView(index)
    self.m_curBannerView = bannerView
    if bannerView then
        bannerView.transform:SetAsLastSibling()
        bannerView.gameObject:SetActive(true)
        bannerView.inAnimationWrapper:PlayInAnimation()
        
        if self.m_bannerActive then
            self:_PlayBannerLoopAndAudio()
        end
    end
    self:_RefreshBannerPageTabs()
end


MultiplayerMainCtrl._RefreshBannerActivity = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:_SetBannerActive(self:IsShow() and PhaseManager:GetTopPhaseId() == PHASE_ID)
end

MultiplayerMainCtrl._OnBannerPhaseExited = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    
    self:_StartCoroutine(function()
        coroutine.step()
        self:_RefreshBannerActivity()
    end)
end

MultiplayerMainCtrl._SetBannerActive = HL.Method(HL.Boolean) << function(self, active)
    if self.m_bannerActive == active then
        return
    end
    self.m_bannerActive = active
    if active then
        self:_ResetBannerTimer()
        self:_PlayBannerLoopAndAudio()
    else
        self:_StopBannerTimer()
        self:_StopBannerAudio()
    end
end

MultiplayerMainCtrl._PlayBannerLoopAndAudio = HL.Method() << function(self)
    self:_StopBannerAudio()
    local bannerView = self.m_curBannerView
    if not self.m_bannerActive or not bannerView or not bannerView.loopAnimationWrapper then
        return
    end
    
    bannerView.loopAnimationWrapper:PlayLoopAnimation()
    local audioEvent = bannerView.config.AUDIO_ON_ENTER
    if not string.isEmpty(audioEvent) then
        self.m_bannerAudioPlayingId = CS.Beyond.Audio.AudioAdapter.PostEvent(audioEvent)
    end
end

MultiplayerMainCtrl._StopBannerAudio = HL.Method() << function(self)
    if self.m_bannerAudioPlayingId ~= 0 then
        CS.Beyond.Audio.AudioAdapter.StopByPlayingId(self.m_bannerAudioPlayingId, 0)
        self.m_bannerAudioPlayingId = 0
    end
end

MultiplayerMainCtrl._RefreshBannerPageTabs = HL.Method() << function(self)
    self.m_genBannerPageTabCells:Update(function(cell, index)
        cell.toggle.isOn = index == self.m_curBannerIndex
    end)
end

MultiplayerMainCtrl._ResetBannerTimer = HL.Method() << function(self)
    self:_StopBannerTimer()
    if not self.m_bannerActive or #self.m_bannerDatas <= 1 then
        return
    end
    
    self.m_bannerTimer = self:_StartTimer(self.view.config.AUTO_SCROLL_TIME, function()
        self.m_bannerTimer = -1
        self:_ScrollBanner(true)
    end, true)
end

MultiplayerMainCtrl._StopBannerTimer = HL.Method() << function(self)
    if self.m_bannerTimer > 0 then
        self.m_bannerTimer = self:_ClearTimer(self.m_bannerTimer)
    end
end

MultiplayerMainCtrl._LoadBannerData = HL.Method() << function(self)
    local bannerDatas = {}
    for _, data in pairs(Tables.multiplayerGameCenterTable) do
        if GameInstance.player.multiplayerGameCenterSystem:IsGameTimeAvailable(data.gameId) then
            table.insert(bannerDatas, data)
        end
    end
    table.sort(bannerDatas, Utils.genSortFunction({ "sortId" }, true))
    self.m_bannerDatas = bannerDatas
end

MultiplayerMainCtrl._GetBannerView = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, index)
    local data = self.m_bannerDatas[index]
    local bannerView = self.m_bannerViews[data.gameId]
    if bannerView then
        return bannerView
    end
    if string.isEmpty(data.gameMainBgName) then
        logger.error("[MultiplayerMainCtrl] gameMainBgName 为空，gameId=%s", data.gameId)
        return
    end
    local prefab = self:_LoadBannerPrefab(data.gameMainBgName)
    if prefab == nil then
        logger.error("[MultiplayerMainCtrl] 无法加载 banner 背景，gameId=%s, gameMainBgName=%s", data.gameId, data.gameMainBgName)
        return
    end
    local bgNode = CSUtils.CreateObject(prefab, self.view.bgRoot.gameObject)
    bannerView = Utils.wrapLuaNode(bgNode)
    if not bannerView.inAnimationWrapper or not bannerView.config then
        logger.error("[MultiplayerMainCtrl] banner 背景缺少入场引用或 LuaCustomConfig，gameId=%s", data.gameId)
        CSUtils.ClearUIComponents(bgNode)
        GameObject.DestroyImmediate(bgNode)
        return
    end
    self.m_bannerViews[data.gameId] = bannerView
    return bannerView
end

MultiplayerMainCtrl._LoadBannerPrefab = HL.Method(HL.String).Return(HL.Any) << function(self, gameMainBgName)
    local prefab = self.m_bannerPrefabCache[gameMainBgName]
    if prefab ~= nil then
        return prefab
    end
    local path = string.format(UIConst.UI_MULTIPLAYER_WIDGETS_PREFAB_PATH, gameMainBgName)
    prefab = self:LoadGameObject(path)
    if prefab ~= nil then
        self.m_bannerPrefabCache[gameMainBgName] = prefab
    end
    return prefab
end



MultiplayerMainCtrl._CloseSelf = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end

MultiplayerMainCtrl._OnPlayRoomReturn = HL.Method(HL.Opt(HL.Number)) << function(self, returnTarget)
    if returnTarget ~= MultiplayerConst.EPlayRoomReturn.Main then
        return
    end
    if MultiplayerUtils.checkAllGamesClosed() then
        return
    end
    local matchSystem = GameInstance.player.multiplayerMatchSystem
    if matchSystem.isInMatchRoom then
        matchSystem:Leave()
    end
    PhaseManager:ExitPhaseFastTo(PHASE_ID)
end

MultiplayerMainCtrl._OnFriendChatNotify = HL.Method(HL.Any) << function(self, args)
    if not MultiplayerUtils.canShowRoomInvitationNotice() then
        return
    end

    local chatRoleId, fromSelf, importantNotifyBitset = unpack(args)
    if fromSelf then
        return
    end

    local roomInviteMask = 1 << (GEnums.FriendImportantNotifyType.RoomGameInvite:ToInt() - 1)
    if (importantNotifyBitset & roomInviteMask) == 0 then
        return
    end
    if GameInstance.player.friendSystem.isCommunicationRestricted then
        return
    end

    local isOpen, invitationCtrl = UIManager:IsOpen(INVITATION_PANEL_ID)
    if isOpen and invitationCtrl:IsPlayingAnimationOut() then
        invitationCtrl:Close()
    end
    local ctrl = UIManager:AutoOpen(INVITATION_PANEL_ID, chatRoleId)
    ctrl:UpdateChatRoleId(chatRoleId)
end

MultiplayerMainCtrl._OnEnterRoomBtnClick = HL.Method() << function(self)
    
    UIManager:Open(PanelId.MultiplayerEnterRoom)
end

MultiplayerMainCtrl._OnQuickMatchBtnClick = HL.Method() << function(self)
    PhaseManager:OpenPhase(PhaseId.MultiplayerMatch, {
        mode = MultiplayerConst.EMatchMode.QuickMatch,
    })
end


MultiplayerMainCtrl._OnRuleBtnClick = HL.Method() << function(self)
    Notify(MessageConst.SHOW_INTRO, Tables.multiplayerGameConst.multiplayerRoomMainIntro)
end



HL.Commit(MultiplayerMainCtrl)
