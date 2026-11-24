local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackHud
local PHASE_ID = PhaseId.CardGameBlackjackHud

local RANDOM_SEAT_INDEX_LIST = { 1, 2, 3, 4 }

local HUD_2D_PERFORM_FORBID_KEY = "CardGameBlackjackHud.2dPerform"
local NAVI_DIRECTION = CS.UnityEngine.UI.NaviDirection

local CARD_COUNT_NODE_MAX_HEIGHT_COUNT = 150

local CHOOSE_KEY_TO_CHOOSE_STATE_MAP = {
    [CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard] = "PreviewPickCard",
    [CardGameBlackjackUtils.CHOOSE_KEY.DestroyCard] = "Backtracking",
}

CardGameBlackjackHudCtrl = HL.Class('CardGameBlackjackHudCtrl', uiCtrl.UICtrl)







CardGameBlackjackHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
}





CardGameBlackjackHudCtrl.m_onPickCard = HL.Field(HL.Any)

CardGameBlackjackHudCtrl.m_scene = HL.Field(HL.Forward("CardGameSceneBlackjack"))
CardGameBlackjackHudCtrl.m_hudSeatNaviSelectables = HL.Field(HL.Table)
CardGameBlackjackHudCtrl.m_curHudSeatNaviSelectable = HL.Field(HL.Any)

CardGameBlackjackHudCtrl.m_lastHudSeatNaviAllowed = HL.Field(HL.Boolean) << false
CardGameBlackjackHudCtrl.m_hudSeatButtons = HL.Field(HL.Table)

CardGameBlackjackHudCtrl.m_handZoneNaviSeats = HL.Field(HL.Table)

CardGameBlackjackHudCtrl.m_hudSeatNaviMap = HL.Field(HL.Table)

CardGameBlackjackHudCtrl.m_naviArrowRoots = HL.Field(HL.Table)

CardGameBlackjackHudCtrl.m_handHoverCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackHudCtrl.m_handHoverUids = HL.Field(HL.Table)
CardGameBlackjackHudCtrl.m_hoveringHandUid = HL.Field(HL.Number) << 0
CardGameBlackjackHudCtrl.m_hoveringCellIndex = HL.Field(HL.Number) << 0

CardGameBlackjackHudCtrl.m_centerArrowPercent = HL.Field(HL.Number) << 0
CardGameBlackjackHudCtrl.m_centerArrowHudSeat = HL.Field(HL.Number) << 0
CardGameBlackjackHudCtrl.m_centerArrowRotateUpdateKey = HL.Field(HL.Number) << -1

CardGameBlackjackHudCtrl.m_gameSignTipsTimers = HL.Field(HL.Table) << function() return {} end

CardGameBlackjackHudCtrl.m_lightBarStates = HL.Field(HL.Table) << function() return {} end

CardGameBlackjackHudCtrl.m_isOptInfoBtnsIn = HL.Field(HL.Boolean) << false




CardGameBlackjackHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    arg = arg or {}
    self.m_onPickCard = arg.onPickCard
    self:_BindHudMainFromScene()
    self:_InitUI()
    self:_RecoverPlayerInfoNode()
    self:_RecoverHudChooseOtherPlayer()
    self:_RecoverHudChooseSelfPlayer(arg.recoverState)
end


CardGameBlackjackHudCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        hudChooseIsExpand = self.m_hudChooseIsExpand,
    }
end

CardGameBlackjackHudCtrl.OnShow = HL.Override() << function(self)
    if self.m_scene == nil then
        return
    end
    
    self:_OnPanelInputBlocked(self.view.inputGroup.internalEnabled)
    local isShowHudMain = self:_ShouldShowHudMain()
    self.view.hudMain.gameObject:SetActive(isShowHudMain)
    self.view.playerInfoNode.gameObject:SetActive(isShowHudMain)
    
    
    if not LuaSystemManager.cardGameBlackjackSystem.isHudReady then
        LuaSystemManager.cardGameBlackjackSystem:OnHudReady()
    end
    self:RefreshHudSeatNavi()
end

CardGameBlackjackHudCtrl.OnHide = HL.Override() << function(self)
    self.m_lastHudSeatNaviAllowed = false
    self.view.quickMenuHintNode:SetAvailable(false)
    if self.m_scene == nil then
        return
    end
    self.view.hudMain.gameObject:SetActive(false)
    
    local arrowTrans = self:_GetNaviArrowTransform()
    if arrowTrans then
        arrowTrans.gameObject:SetActive(false)
    end
end

CardGameBlackjackHudCtrl.OnClose = HL.Override() << function(self)
    self:_Set2dPerformForbidHotswap(false)
    self.view.quickMenuHintNode:SetAvailable(false)
    self:DetachScene()
end


CardGameBlackjackHudCtrl.DetachScene = HL.Method() << function(self)
    if self.m_scene == nil then
        return
    end
    if self.view.randomSeatNode:IsPlaying() then
        self.view.randomSeatNode:Stop(false)
        self:_Set2dPerformForbidHotswap(false)
    end
    self.m_centerArrowRotateUpdateKey = self:_RemoveUpdate(self.m_centerArrowRotateUpdateKey)
    self:_UnbindHudSeatNavi()
    for hudSeat, timer in pairs(self.m_gameSignTipsTimers) do
        self:_ClearTimer(timer)
        self.m_gameSignTipsTimers[hudSeat] = nil
    end
    self.m_handHoverUids = {}
    self.m_hoveringHandUid = 0
    self.m_hoveringCellIndex = 0
    self.m_scene = nil
    self.view.hudMain = nil
end


CardGameBlackjackHudCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    local hudMain = self.view.hudMain
    if hudMain == nil or IsNull(hudMain.gameObject) then
        return
    end
    hudMain.inputGroup.internalEnabled = active
end

CardGameBlackjackHudCtrl._InitUI = HL.Method() << function(self)
    self.view.randomSeatNode:InitCardGameRandomSeatNode(RANDOM_SEAT_INDEX_LIST)
    local system = LuaSystemManager.cardGameBlackjackSystem
    self.view.titleNode.exitBtn.onClick:AddListener(function()
        system:RequestLeavePlayRoom(true)
    end)
    
    self.view.roundReportNode.gameObject:SetActive(false)
    self.view.turnReportNode.gameObject:SetActive(false)
    self.view.chooseInitialRelicReport.gameObject:SetActive(false)
    self.view.effectReportNode:InitCardGameEffectReport()
    self:RefreshTitleRoundAndTurn()
    self:_RecoverHpHintNode()
    self:_RecoverSelfMoneyNum()
    self:_RecoverOptInfoBtns()
    self:_RecoverOptInfoPickCardBtnTips()
    
    self:_InitHudChooseSelfPlayer()

    
    self.view.titleNode.helpBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, CardGameBlackjackUtils.INTRO_KEY)
    end)

    
    self.view.optInfoNode.stopBtn.onClick:AddListener(function()
        self:_OnClickPick(false)
    end)
    self.view.optInfoNode.pickCardBtn.onClick:AddListener(function()
        self:_OnClickPick(true)
    end)
    local emojiNode = self.view.emojiNode
    emojiNode.emojiPopupBtn.button.onClick:AddListener(function()
        self:OnClickEmojiPopupBtn()
    end)
    emojiNode.emojiPopupNode:InitMultiplayerEmojiNode({
        roomStrId = system:GetEmojiRoomStrId(),
        onEmojiSent = function()
            self:HideEmojiPopup()
            system:StartEmojiCd()
        end,
        onActiveChanged = function(active)
            if not active then
                self:SetEmojiCdState(system:IsEmojiInCd())
            end
        end,
    })
    self:HideEmojiPopup()
    for i = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        
        
        local relicInfoNode = self.view.hudMain.relicInfoNode["relicInfo_" .. i]
        relicInfoNode.button.onClick:RemoveAllListeners()
        relicInfoNode.button.onClick:AddListener(function()
            LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(i, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.Relic)
        end)
        
        local gameSignNode = relicInfoNode.gameSignNode
        gameSignNode.button.onClick:RemoveAllListeners()
        gameSignNode.button.onHoverChange:RemoveAllListeners()
        self:_HideGameSignTips(i)
        if DeviceInfo.usingKeyboard then
            gameSignNode.button.onHoverChange:AddListener(function(isHover)
                if isHover then
                    self:_TryShowGameSignTips(i)
                else
                    self:_HideGameSignTips(i)
                end
            end)
        end
        if DeviceInfo.usingTouch then
            gameSignNode.button.onClick:AddListener(function()
                if gameSignNode.tipsNode.gameObject.activeSelf then
                    self:_HideGameSignTips(i)
                    return
                end
                if self:_TryShowGameSignTips(i) then
                    self.m_gameSignTipsTimers[i] = self:_StartTimer(self.view.hudMain.config.GAME_SIGN_TIPS_SHOW_DURATION, function()
                        self.m_gameSignTipsTimers[i] = nil
                        self:_HideGameSignTips(i)
                    end)
                end
            end)
        end
        
        local playerInfoNode = self:_GetPlayerInfoNode(i)
        playerInfoNode.emojiNode:Clear()
        if i ~= 1 then
            playerInfoNode.button.onClick:RemoveAllListeners()
            playerInfoNode.button.onClick:AddListener(function()
                LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(i, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.HandZone)
            end)
        end
        
        local cardDeckNode = self:_GetCardDeck(i)
        cardDeckNode.button.onClick:RemoveAllListeners()
        cardDeckNode.button.onClick:AddListener(function()
            LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(i, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck)
        end)
        
        local handZoneBtn = self.view.hudMain.tableInfoNode["handZoneBtn_" .. i].button
        handZoneBtn.onClick:RemoveAllListeners()
        if DeviceInfo.usingController then
            handZoneBtn.gameObject:SetActive(true)
            handZoneBtn.onClick:AddListener(function()
                LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(i, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.HandZone)
            end)
        else
            handZoneBtn.gameObject:SetActive(false)
        end
    end
    self:_InitHudController()
    self:_InitHandHover()
    
    if system.isHudReady then
        return
    end

    
    self:RefreshOptInfoPickCardBtnState("Empty")
    self:RefreshOptInfoStopBtnState("Empty")
    self:ShowTableInfoCountDown(false)
    self:ShowTableInfoCenterArrow(false)

    
    self.view.hudMain.gameObject:SetActive(false)
    self.view.playerInfoNode.gameObject:SetActive(false)
    self.m_scene:SetRoomCameraPos(CardGameUtils.RoomCameraPosType.Overlook)
end

CardGameBlackjackHudCtrl._InitHudController = HL.Method() << function(self)
    self:_BindHudSeatNavi()
    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId, self.view.hudMain.inputGroup.groupId })
    end
    self:_InitQuickMenu()
    self:RefreshHudSeatNavi()
    self:RefreshStartPresentationNodes()
end

CardGameBlackjackHudCtrl._OnClickPick = HL.Method(HL.Boolean) << function(self, pick)
    if not self.m_onPickCard then
        return
    end
    self.m_onPickCard(pick)
end




CardGameBlackjackHudCtrl._Set2dPerformForbidHotswap = HL.Method(HL.Boolean) << function(self, forbid)
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(HUD_2D_PERFORM_FORBID_KEY, forbid)
end


CardGameBlackjackHudCtrl.RefreshTitleRoundAndTurn = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    self:SetTitleRoundText(string.format(Language.LUA_CARD_GAME_BLACKJACK_HUD_TITLE_ROUND, system:GetGameRound()))
    local displayTurn = math.max(system:GetGameTurn() - 1, 0)
    
    local phase = system:GetClientPhase()
    if displayTurn <= 0
            or phase == CardGameBlackjackUtils.CLIENT_PHASE.ShopWait
            or phase == CardGameBlackjackUtils.CLIENT_PHASE.RoundEndWait then
        self.view.titleNode.turnInfoTxt.gameObject:SetActive(false)
    else
        self.view.titleNode.turnInfoTxt.gameObject:SetActive(true)
        self:SetTitleTurnText(string.format(Language.LUA_CARD_GAME_BLACKJACK_HUD_TITLE_TURN, displayTurn))
    end
end


CardGameBlackjackHudCtrl.RefreshStartPresentationNodes = HL.Method() << function(self)
    local isShow = not LuaSystemManager.cardGameBlackjackSystem.m_isStartPresentationPlaying
    self.view.titleNode.roundInfoNode.gameObject:SetActive(isShow)
    self.view.emojiNode.gameObject:SetActive(isShow)
end

CardGameBlackjackHudCtrl.SetTitleRoundText = HL.Method(HL.String) << function(self, text)
    self.view.titleNode.roundInfoTxt.text = text
end

CardGameBlackjackHudCtrl.SetTitleTurnText = HL.Method(HL.String) << function(self, text)
    self.view.titleNode.turnInfoTxt.text = text
end

CardGameBlackjackHudCtrl.SetRoundReport = HL.Method(HL.Number) << function(self, round)
    self.view.roundReportNode.roundNumTxt.text = round
    self.view.roundReportNode.roundTxt.text = string.format(Language.LUA_CARD_GAME_ROUND_REPORT_TEXT, round)
end

CardGameBlackjackHudCtrl.PlayRoundReport = HL.Method(HL.Opt(HL.Function)) << function(self, onPlayEnd)
    self:_Set2dPerformForbidHotswap(true)
    self.view.roundReportNode.gameObject:SetActive(true)
    self.view.roundReportNode.animationWrapper:PlayInAnimation(function()
        self.view.roundReportNode.gameObject:SetActive(false)
        self:_Set2dPerformForbidHotswap(false)
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end


CardGameBlackjackHudCtrl.StopRoundReport = HL.Method() << function(self)
    self.view.roundReportNode.gameObject:SetActive(false)
    self:_Set2dPerformForbidHotswap(false)
end

CardGameBlackjackHudCtrl.RefreshTurnReportStartShowCard = HL.Method(HL.Number) << function(self, turn)
    local turnReportNode = self.view.turnReportNode
    turnReportNode.stateController:SetState("StartShowCard")
    if turn == 0 then
        turnReportNode.titleTxt.text = Language.LUA_CARD_GAME_BLACKJACK_REPORT_FIRST_TURN_DEAL
    else
        turnReportNode.titleTxt.text = string.format(Language.LUA_CARD_GAME_SHOW_CARD_REPORT_START_TEXT, turn)
    end
end

CardGameBlackjackHudCtrl.RefreshTurnReportStartGameTurn = HL.Method(HL.Number, HL.Number) << function(self, turn, seatIndex)
    local turnReportNode = self.view.turnReportNode
    turnReportNode.stateController:SetState("StartGameTurn")
    turnReportNode.titleTxt.text = string.format(Language.LUA_CARD_GAME_START_TURN_REPORT_TEXT, turn)
end

CardGameBlackjackHudCtrl.RefreshTurnReportRoundSettle = HL.Method() << function(self)
    local turnReportNode = self.view.turnReportNode
    turnReportNode.stateController:SetState("StartGameTurn")
    turnReportNode.titleTxt.text = string.format(Language.LUA_CARD_GAME_BLACKJACK_REPORT_ROUND_SETTLE)
end

CardGameBlackjackHudCtrl.PlayTurnReport = HL.Method(HL.Opt(HL.Function)) << function(self, onPlayEnd)
    self:StopTurnReport()
    self:_Set2dPerformForbidHotswap(true)
    self.view.turnReportNode.gameObject:SetActive(true)
    self.view.turnReportNode.animationWrapper:PlayInAnimation(function()
        self.view.turnReportNode.gameObject:SetActive(false)
        self:_Set2dPerformForbidHotswap(false)
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end


CardGameBlackjackHudCtrl.StopTurnReport = HL.Method() << function(self)
    self.view.turnReportNode.gameObject:SetActive(false)
    self:_Set2dPerformForbidHotswap(false)
end

CardGameBlackjackHudCtrl.PlayChooseInitialRelicReport = HL.Method(HL.Opt(HL.Function)) << function(self, onPlayEnd)
    self:_Set2dPerformForbidHotswap(true)
    self.view.chooseInitialRelicReport.gameObject:SetActive(true)
    self.view.chooseInitialRelicReport.animationWrapper:PlayInAnimation(function()
        self.view.chooseInitialRelicReport.gameObject:SetActive(false)
        self:_Set2dPerformForbidHotswap(false)
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end

CardGameBlackjackHudCtrl.StopChooseInitialRelicReport = HL.Method() << function(self)
    self.view.chooseInitialRelicReport.gameObject:SetActive(false)
    self:_Set2dPerformForbidHotswap(false)
end

CardGameBlackjackHudCtrl.InitRandomSeat = HL.Method(HL.Number, HL.Any) << function(self, hudSeat, playerInfo)
    self.view.randomSeatNode:SetSeatPlayer(hudSeat, playerInfo)
end


CardGameBlackjackHudCtrl.PlayRandomSeatAni = HL.Method(HL.Number, HL.Opt(HL.Function)) << function(self, finalTargetHudSeat, onPlayEnd)
    finalTargetHudSeat = math.min(math.max(finalTargetHudSeat, 1), CardGameBlackjackUtils.MAX_SEAT_COUNT)

    self:_Set2dPerformForbidHotswap(true)
    self.view.hudMain.gameObject:SetActive(false)
    self.view.playerInfoNode.gameObject:SetActive(false)
    self.m_scene:SetRoomCameraPos(CardGameUtils.RoomCameraPosType.Overlook)

    self.view.randomSeatNode:Play(finalTargetHudSeat, function()
        self:_ShowRandomSeatAniEnd()
        if onPlayEnd then
            onPlayEnd()
        end
    end)
end



CardGameBlackjackHudCtrl.StopRandomSeatAni = HL.Method() << function(self)
    if self.m_scene == nil then
        return
    end
    local randomSeatNode = self.view.randomSeatNode
    if randomSeatNode:IsPlaying() then
        randomSeatNode:Stop(false)
    end
    self:_ShowRandomSeatAniEnd()
end

CardGameBlackjackHudCtrl._ShouldShowHudMain = HL.Method().Return(HL.Boolean) << function(self)
    local phase = LuaSystemManager.cardGameBlackjackSystem:GetClientPhase()
    return phase ~= CardGameBlackjackUtils.CLIENT_PHASE.WaitStart and not self.view.randomSeatNode:IsPlaying()
end

CardGameBlackjackHudCtrl._ShowRandomSeatAniEnd = HL.Method() << function(self)
    self.view.hudMain.gameObject:SetActive(true)
    self.view.playerInfoNode.gameObject:SetActive(true)
    if self.m_scene then
        self.m_scene:SetRoomCameraPos(CardGameUtils.RoomCameraPosType.Normal)
    end
    self:_Set2dPerformForbidHotswap(false)
end


CardGameBlackjackHudCtrl._RecoverHpHintNode = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local hpLoss = system:GetCurRoundHpLoss()
    if hpLoss then
        self:RefreshHpHintNode(hpLoss)
    end
    self:ShowHpHintNode(system:IsHpHintShow())
end

CardGameBlackjackHudCtrl.RefreshHpHintNode = HL.Method(HL.Number) << function(self, hpValue)
    self.view.titleNode.hpHintValueTxt.text = "x" .. hpValue
end

CardGameBlackjackHudCtrl.ShowHpHintNode = HL.Method(HL.Boolean) << function(self, isShow)
    self.view.titleNode.hpHintNode.gameObject:SetActive(isShow)
end


CardGameBlackjackHudCtrl.ShowSelfHandZoneCardMaxTips = HL.Method(HL.Number) << function(self, maxCardCount)
    self.view.hudMain.handZoneCardMaxTips.gameObject:SetActive(true)
    self.view.hudMain.handZoneCardMaxTips.cardCountTxt.text = string.format("%d/%d", maxCardCount, maxCardCount)
end

CardGameBlackjackHudCtrl.HideSelfHandZoneCardMaxTips = HL.Method() << function(self)
    self.view.hudMain.handZoneCardMaxTips.gameObject:SetActive(false)
end


CardGameBlackjackHudCtrl._InitHandHover = HL.Method() << function(self)
    self.view.pokerTips:InitBlackjackPokerTips()
    self.m_handHoverUids = {}
    self.m_handHoverCellCache = UIUtils.genCellCache(self.view.hudMain.tableInfoNode.handZoneHoverBtnCell)
    
    self:RefreshHandHover()
end


CardGameBlackjackHudCtrl._ClearHandHover = HL.Method() << function(self)
    self:_HideHandPokerTips()
    if self.m_handHoverCellCache then
        self.m_handHoverCellCache:ClearAll()
    end
    self.m_handHoverUids = {}
end



CardGameBlackjackHudCtrl.RefreshHandHover = HL.Method() << function(self)
    local uids, hudSeats = {}, {}
    if not DeviceInfo.usingController then
        uids, hudSeats = LuaSystemManager.cardGameBlackjackSystem:GetHandPokerTipsUids()
    end
    local cardSystem = LuaSystemManager.cardGameSystem
    self.m_handHoverUids = uids
    local guideSeatCounts = {}
    self.m_handHoverCellCache:Refresh(#uids, function(cell, index)
        
        cell.transform:SetAsLastSibling()
        self:_AlignHoverCellToCard(cell.transform, cardSystem:GetRuntimeCard(uids[index]):GetCardRenderer())
        cell.button.onHoverChange:RemoveAllListeners()
        cell.button.onHoverChange:AddListener(function(isHover)
            self:_OnHandHoverChange(cell, index, isHover)
        end)
        local hudSeat = hudSeats[index]
        local guideIndex = (guideSeatCounts[hudSeat] or 0) + 1
        guideSeatCounts[hudSeat] = guideIndex
        cell.gameObject.name = string.format("GuideHand_%d_%d", hudSeat, guideIndex)
        cell.button.onClick:RemoveAllListeners()
        cell.button.onClick:AddListener(function()
            self:_HideHandPokerTips()
            LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(hudSeat, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.HandZone)
        end)
    end)
    
    if self.m_hoveringCellIndex > #uids then
        self:_HideHandPokerTips()
    end
    if DeviceInfo.usingController then
        self:_EnsureHudSeatNaviTargetAvailable()
    end
end


CardGameBlackjackHudCtrl.OnHandCardRemoved = HL.Method(HL.Number) << function(self, uid)
    if uid == self.m_hoveringHandUid then
        self:_HideHandPokerTips()
    end
end



CardGameBlackjackHudCtrl._AlignHoverCellToCard = HL.Method(RectTransform, CS.UnityEngine.MeshRenderer)
        << function(self, cellTrans, renderer)
    local parent = cellTrans.parent
    local rendererTrans = renderer.transform
    local bounds = renderer.localBounds
    local extents = bounds.extents
    local axisX = parent:InverseTransformVector(rendererTrans:TransformVector(Vector3(extents.x, 0, 0)))
    local axisY = parent:InverseTransformVector(rendererTrans:TransformVector(Vector3(0, extents.y, 0)))
    local axisZ = parent:InverseTransformVector(rendererTrans:TransformVector(Vector3(0, 0, extents.z)))
    local halfWidth = math.abs(axisX.x) + math.abs(axisY.x) + math.abs(axisZ.x)
    local halfHeight = math.abs(axisX.y) + math.abs(axisY.y) + math.abs(axisZ.y)
    cellTrans.localPosition = parent:InverseTransformPoint(rendererTrans:TransformPoint(bounds.center))
    cellTrans:SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, halfWidth * 2)
    cellTrans:SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, halfHeight * 2)
end

CardGameBlackjackHudCtrl._OnHandHoverChange = HL.Method(HL.Table, HL.Number, HL.Boolean) << function(self, cell, index, isHover)
    if not isHover then
        
        if index == self.m_hoveringCellIndex then
            self:_HideHandPokerTips()
        end
        return
    end
    local uid = self.m_handHoverUids[index]
    local pokerInfo = uid and LuaSystemManager.cardGameBlackjackSystem:GetHandPokerInfo(uid)
    if pokerInfo == nil then
        return
    end
    
    self.view.pokerTips:ShowPokerTips(cell, pokerInfo, false, function()
        self.m_hoveringHandUid = 0
        self.m_hoveringCellIndex = 0
    end, self:_GetWorldRectScreenRect(cell.transform))
    self.m_hoveringHandUid = uid
    self.m_hoveringCellIndex = index
end

CardGameBlackjackHudCtrl._HideHandPokerTips = HL.Method() << function(self)
    if self.m_hoveringCellIndex == 0 then
        return
    end
    self.m_hoveringHandUid = 0
    self.m_hoveringCellIndex = 0
    self.view.pokerTips:HidePokerTips()
end


CardGameBlackjackHudCtrl._GetWorldRectScreenRect = HL.Method(RectTransform).Return(HL.Any) << function(self, rectTransform)
    local camera = self.view.hudMain.canvas.worldCamera
    local rect = rectTransform.rect
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, x in ipairs({ rect.xMin, rect.xMax }) do
        for _, y in ipairs({ rect.yMin, rect.yMax }) do
            local screenPos = camera:WorldToScreenPoint(rectTransform:TransformPoint(Vector3(x, y, 0)))
            minX = math.min(minX, screenPos.x)
            minY = math.min(minY, screenPos.y)
            maxX = math.max(maxX, screenPos.x)
            maxY = math.max(maxY, screenPos.y)
        end
    end
    return Unity.Rect(minX, Screen.height - maxY, maxX - minX, maxY - minY)
end




CardGameBlackjackHudCtrl._RecoverSelfMoneyNum = HL.Method() << function(self)
    local gold = LuaSystemManager.cardGameBlackjackSystem:GetSelfGold()
    if gold then
        self:RefreshSelfMoneyNum(gold)
    end
end

CardGameBlackjackHudCtrl.RefreshSelfMoneyNum = HL.Method(HL.Number) << function(self, num)
    CardGameBlackjackUtils.InitGoldMoneyCell(self.view.titleNode.moneyCell, num)
end

CardGameBlackjackHudCtrl.PlayPlayerInfoChangeMoneyNum = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Function))
    << function(self, valueChangeType, value, onPlayEnd)
    local valueChangeTips = self.view.titleNode.moneyCell.view.moneyChangeTipsNode
    CardGameBlackjackUtils.PlayChangeValueTips(self, valueChangeTips, valueChangeType, value, onPlayEnd)
end



CardGameBlackjackHudCtrl._InitQuickMenu = HL.Method() << function(self)
    self.view.quickMenuHintNode:InitCardGameQuickMenuHintNode({
        getOpenArg = function()
            if not self:_IsHudSeatNaviAllowed() then
                return nil
            end
            return self:_BuildQuickMenuArg()
        end,
    })
end


CardGameBlackjackHudCtrl._BuildQuickMenuArg = HL.Method().Return(HL.Table) << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local seats = {}
    for hudSeat = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        local info = system:BuildPlayerBasicInfoByHudSeat(hudSeat)
        seats[hudSeat] = { isEmpty = info == nil, playerInfo = info }
    end
    return {
        seats = seats,
        onConfirm = function(hudSeat)
            LuaSystemManager.cardGameBlackjackSystem:OpenPlayerGameInfoByHudSeat(hudSeat, CardGameBlackjackUtils.BlackjackPlayerGameInfoPageType.CardDeck)
        end,
    }
end

CardGameBlackjackHudCtrl._GetActualSeatIndexByHudSeat = HL.Method(HL.Number).Return(HL.Number) << function(self, hudSeat)
    local seatToHudSeat = LuaSystemManager.cardGameBlackjackSystem.m_seatToHudSeat
    if seatToHudSeat then
        for actualSeat, mappedHudSeat in pairs(seatToHudSeat) do
            if mappedHudSeat == hudSeat then
                return actualSeat
            end
        end
    end
    return hudSeat
end






CardGameBlackjackHudCtrl.m_hudChooseIsExpand = HL.Field(HL.Boolean) << true
CardGameBlackjackHudCtrl.m_hudChoosePopupPokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackHudCtrl.m_hudChooseFoldToastPokerCellCache = HL.Field(HL.Forward("UIListCache"))

CardGameBlackjackHudCtrl.m_hudChooseCanSelect = HL.Field(HL.Boolean) << false
CardGameBlackjackHudCtrl.m_hudChooseSelectedIndex = HL.Field(HL.Number) << 0

CardGameBlackjackHudCtrl._InitHudChooseSelfPlayer = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    self.m_hudChoosePopupPokerCellCache = UIUtils.genCellCache(self.view.hudChoosePopup.pokerCell)
    self.m_hudChooseFoldToastPokerCellCache = UIUtils.genCellCache(self.view.hudChooseFoldToast.pokerCell)
    
    self.view.hudChooseFoldToast.button.onClick:AddListener(function()
        self:ExpandHudChooseSelfPlayer(true)
    end)
    
    self.view.hudChoosePopup.foldBtn.onClick:AddListener(function()
        self:ExpandHudChooseSelfPlayer(false)
    end)
    self.view.hudChoosePopup.confirmBtn.onClick:AddListener(function()
        system:OnHudChooseConfirm()
    end)
    self.view.hudChoosePopup.cancelBtn.onClick:AddListener(function()
        system:OnHudChooseCancel()
    end)
end

CardGameBlackjackHudCtrl._RecoverHudChooseSelfPlayer = HL.Method(HL.Opt(HL.Table)) << function(self, recoverState)
    local view = LuaSystemManager.cardGameBlackjackSystem:BuildHudChooseSelfPlayerView()
    if view == nil then
        return
    end
    self:OpenHudChooseSelfPlayer(view, recoverState.hudChooseIsExpand)
end


CardGameBlackjackHudCtrl.RefreshHudChooseSelfPlayer = HL.Method(HL.Table) << function(self, arg)
    local chooseState = CHOOSE_KEY_TO_CHOOSE_STATE_MAP[arg.chooseKey]
    if chooseState == nil then
        logger.error("CardGameBlackjackHudCtrl.RefreshHudChooseSelfPlayer: 不支持的 chooseKey=" .. tostring(arg.chooseKey))
        return
    end
    self.view.hudChoosePopup.stateController:SetState(chooseState)
    self.view.hudChooseFoldToast.stateController:SetState(chooseState)

    
    local canSelect = arg.chooseKey == CardGameBlackjackUtils.CHOOSE_KEY.PreviewCard
    local cardInfos = arg.cardInfos
    local selectedIndex = arg.selectedIndex
    self.m_hudChooseCanSelect = canSelect
    self.m_hudChooseSelectedIndex = selectedIndex
    self.m_hudChoosePopupPokerCellCache:Refresh(#cardInfos, function(cell, index)
        local info = cardInfos[index]
        cell.poker:SetCardSuitRankStyle(info.suit, info.rank, info.style)
        CardGameBlackjackUtils.SetPokerCellSelectState(cell, index == selectedIndex, false)
        cell.button.onClick:RemoveAllListeners()
        if canSelect then
            cell.button.onClick:AddListener(function()
                LuaSystemManager.cardGameBlackjackSystem:OnHudChooseSelectCard(index)
            end)
            
            cell.naviDeco.onIsNaviTargetChanged = function(isTarget)
                if isTarget then
                    LuaSystemManager.cardGameBlackjackSystem:OnHudChooseSelectCard(index)
                end
            end
        else
            cell.naviDeco.onIsNaviTargetChanged = nil
        end
    end)
    self.m_hudChooseFoldToastPokerCellCache:Refresh(#cardInfos, function(cell, index)
        local info = cardInfos[index]
        cell.poker:SetCardSuitRankStyle(info.suit, info.rank, info.style)
        cell.stateController:SetState(index == selectedIndex and "Select" or "Unselect")
    end)
    
    self:_RefreshHudChooseConfirmBtn(not canSelect or selectedIndex ~= 0)
end


CardGameBlackjackHudCtrl.RefreshHudChooseSelectedCard = HL.Method(HL.Number, HL.Number) << function(self, oldIndex, newIndex)
    if oldIndex ~= 0 then
        self:_SetHudChooseCardState(oldIndex, "Unselect")
    end
    if newIndex ~= 0 then
        self:_SetHudChooseCardState(newIndex, "Select")
    end
    self.m_hudChooseSelectedIndex = newIndex
    self:_RefreshHudChooseConfirmBtn(newIndex ~= 0)
end

CardGameBlackjackHudCtrl._RefreshHudChooseConfirmBtn = HL.Method(HL.Boolean) << function(self, canConfirm)
    local popup = self.view.hudChoosePopup
    popup.confirmBtn.interactable = canConfirm
    popup.confirmBtnStateCtrl:SetState(canConfirm and "CanConfirm" or "CanNotConfirm")
end

CardGameBlackjackHudCtrl._SetHudChooseCardState = HL.Method(HL.Number, HL.String) << function(self, index, state)
    CardGameBlackjackUtils.SetPokerCellSelectState(self.m_hudChoosePopupPokerCellCache:Get(index), state == "Select", true)
    self.m_hudChooseFoldToastPokerCellCache:Get(index).stateController:SetState(state)
end

CardGameBlackjackHudCtrl.OpenHudChooseSelfPlayer = HL.Method(HL.Table, HL.Boolean) << function(self, arg, isExpand)
    self:RefreshHudChooseSelfPlayer(arg)
    self:ExpandHudChooseSelfPlayer(isExpand)
end

CardGameBlackjackHudCtrl.CloseHudChooseSelfPlayer = HL.Method() << function(self)
    self:_StopHudChoosePopupFocus()
    self.view.hudChoosePopup.gameObject:SetActive(false)
    self.view.hudChooseFoldToast.gameObject:SetActive(false)
    self.m_hudChoosePopupPokerCellCache:Refresh(0)
    self.m_hudChooseFoldToastPokerCellCache:Refresh(0)
    self.m_hudChooseCanSelect = false
    self.m_hudChooseSelectedIndex = 0
    self:RefreshHudSeatNavi()
end

CardGameBlackjackHudCtrl.ExpandHudChooseSelfPlayer = HL.Method(HL.Boolean) << function(self, isExpand)
    
    self.m_hudChooseIsExpand = isExpand
    if not isExpand then
        self:_StopHudChoosePopupFocus()
    end
    self.view.hudChoosePopup.gameObject:SetActive(isExpand)
    self.view.hudChooseFoldToast.gameObject:SetActive(not isExpand)
    if isExpand then
        self:_StartHudChoosePopupFocus()
    end
    self:RefreshHudSeatNavi()
end


CardGameBlackjackHudCtrl._StartHudChoosePopupFocus = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    self.view.hudChoosePopup.naviGroup:ManuallyFocus(true)
end

CardGameBlackjackHudCtrl._StopHudChoosePopupFocus = HL.Method() << function(self)
    self.view.hudChoosePopup.naviGroup:ManuallyStopFocus()
end

CardGameBlackjackHudCtrl.RefreshHudChooseCountDownSelfPlayer = HL.Method(HL.Number, HL.Number) << function(self, remain, total)
    local curTime = math.floor(remain)
    local progress = total > 0 and lume.clamp(remain / total, 0, 1) or 0
    local warning = curTime <= CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME
    
    local popupCountDown = self.view.hudChoosePopup.countDownNode
    popupCountDown.timeTxt.text = curTime
    popupCountDown.countDownBar.fillAmount = progress
    popupCountDown.stateController:SetState(warning and "Red" or "White")
    
    local foldToast = self.view.hudChooseFoldToast
    foldToast.countDownTxt.text = curTime .. "s"
    foldToast.countDownBar.fillAmount = progress
    foldToast.countDownBgBar.fillAmount = progress
    foldToast.countDownShadowBar.fillAmount = progress
    foldToast.stateController:SetState(warning and "TimeWarning" or "TimeNormal")
end



CardGameBlackjackHudCtrl._RecoverHudChooseOtherPlayer = HL.Method() << function(self)
    local view = LuaSystemManager.cardGameBlackjackSystem:BuildHudChooseOtherPlayerView()
    if view == nil then
        self:CloseHudChooseOtherPlayer()
        return
    end
    self:OpenHudChooseOtherPlayer(view)
end


CardGameBlackjackHudCtrl.OpenHudChooseOtherPlayer = HL.Method(HL.Table) << function(self, arg)
    local chooseKey = arg.chooseKey
    local chooseState = CHOOSE_KEY_TO_CHOOSE_STATE_MAP[chooseKey]
    if chooseState == nil then
        logger.error("CardGameBlackjackHudCtrl.OpenHudChooseOtherPlayer: 不支持的 chooseKey=" .. tostring(chooseKey))
        return
    end
    self.view.hudChooseOtherPlayerPopup.gameObject:SetActive(true)
    self.view.hudChooseOtherPlayerPopup.stateController:SetState(chooseState)
    
    if arg.total <= 0 then
        self:RefreshHudChooseCountDownOtherPlayer(0, 0)
    end
end

CardGameBlackjackHudCtrl.CloseHudChooseOtherPlayer = HL.Method() << function(self)
    self.view.hudChooseOtherPlayerPopup.gameObject:SetActive(false)
end

CardGameBlackjackHudCtrl.RefreshHudChooseCountDownOtherPlayer = HL.Method(HL.Number, HL.Number) << function(self, remain, total)
    
    self.view.hudChooseOtherPlayerPopup.timeTxt.text = total > 0 and math.floor(remain) .. "s" or "0s"
end








CardGameBlackjackHudCtrl._BindHudMainFromScene = HL.Method() << function(self)
    local scene = LuaSystemManager.cardGameBlackjackSystem.scene
    if not scene or not scene.hudMain then
        logger.error("CardGameBlackjackHudCtrl._BindHudMainFromScene: hudMain not ready (must Init scene before panel)")
        return
    end
    self.m_scene = scene
    self.view.hudMain = scene.hudMain
end


CardGameBlackjackHudCtrl._RecoverPlayerInfoNode = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    for hudSeat = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        local memberId = system:GetMemberIdByHudSeat(hudSeat)
        if memberId ~= nil then
            self:RefreshPlayerInfoBasicUI(hudSeat, system:BuildPlayerBasicInfoByHudSeat(hudSeat))
            self:RefreshPlayerInfoOptInfoBySeat(hudSeat)
            if hudSeat == 1 then
                self:RefreshPlayerInfoSelfIsWatch(system:IsSelfGameOut())
            else
                self:ShowOtherPlayerInfoAIIcon(hudSeat, CardGameUtils.IsMemberShowAI(memberId))
            end
        end
    end
end


CardGameBlackjackHudCtrl.RefreshPlayerInfoOptInfoBySeat = HL.Method(HL.Number) << function(self, hudSeatIndex)
    local system = LuaSystemManager.cardGameBlackjackSystem
    if system:GetMemberIdByHudSeat(hudSeatIndex) == nil then
        return
    end
    local optState = self:_CalcPlayerOptInfoState(hudSeatIndex)
    if optState ~= nil then
        self:RefreshPlayerInfoOptInfo(hudSeatIndex, optState)
    end
    self:ShowPlayerInfoOptInfo(hudSeatIndex, optState ~= nil)

    
    local lightBarState = optState
    if hudSeatIndex == 1 and lightBarState == nil and self:_IsSelfPickTimeWillOut() then
        lightBarState = "PickCardTimeWillOut"
    end
    if lightBarState ~= nil then
        self:RefreshLightBarColorByState(hudSeatIndex, lightBarState)
    else
        self:HideLightBar(hudSeatIndex)
    end
end


CardGameBlackjackHudCtrl._CalcPlayerOptInfoState = HL.Method(HL.Number).Return(HL.Opt(HL.String)) << function(self, hudSeatIndex)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local memberId = system:GetMemberIdByHudSeat(hudSeatIndex)
    local mirror = system:GetSeatMirror(hudSeatIndex)
    local phase = system:GetClientPhase()
    if memberId == nil or mirror == nil
            or phase == CardGameBlackjackUtils.CLIENT_PHASE.WaitStart
            or phase == CardGameBlackjackUtils.CLIENT_PHASE.Dealing then
        return nil
    end

    
    if mirror.hp <= 0 then
        return "GameOut"
    end

    if phase == CardGameBlackjackUtils.CLIENT_PHASE.Shop or phase == CardGameBlackjackUtils.CLIENT_PHASE.ShopWait then
        return system:IsMemberChosenDone(memberId) and "IsReady" or "Readying"
    end

    
    if phase ~= CardGameBlackjackUtils.CLIENT_PHASE.Battle
            and phase ~= CardGameBlackjackUtils.CLIENT_PHASE.RoundSettle then
        return nil
    end

    
    if mirror.isBust then
        return "Bust"
    end
    
    if system:IsMemberPickShown(memberId) then
        return nil
    end
    local subPhase = system:GetBattleSubPhase()
    local curTurn = system:GetGameTurn()
    
    if mirror.standTurn > 0 and (subPhase ~= CardGameBlackjackUtils.BATTLE_SUB_PHASE.WaitPick or mirror.standTurn < curTurn) then
        return "StopPickCard"
    end

    
    if curTurn == 1 then
        return nil
    end

    if subPhase == CardGameBlackjackUtils.BATTLE_SUB_PHASE.WaitPick then
        
        return system:IsMemberPickChosen(memberId) and "ChoiceComplete" or nil
    end

    if subPhase == CardGameBlackjackUtils.BATTLE_SUB_PHASE.ShowCard then
        local found, pick = system:TryGetPickResult(memberId)
        if not found then
            return nil
        end
        return pick and "PickCard" or "StopPickCard"
    end

    return nil
end


CardGameBlackjackHudCtrl._IsSelfPickTimeWillOut = HL.Method().Return(HL.Boolean) << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    if system:GetBattleSubPhase() ~= CardGameBlackjackUtils.BATTLE_SUB_PHASE.WaitPick or not system:IsSelfPickChoosing() then
        return false
    end
    local remain = system:GetCountDownRemain()
    return remain > 0 and remain < CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME
end

CardGameBlackjackHudCtrl.RefreshPlayerInfoBasicUI = HL.Method(HL.Number, HL.Any) << function(self, hudSeatIndex, playerBasicInfo)
    local playInfoNode = self:_GetPlayerInfoNode(hudSeatIndex)
    
    if hudSeatIndex == 1 then
        
        return
    end
    
    playInfoNode.playerNameTxt.text = CardGameUtils.GetPlayerDisplayName(playerBasicInfo)
    CardGameUtils.InitCommonPlayerHead(playInfoNode.commonPlayerHead, playerBasicInfo)
end











CardGameBlackjackHudCtrl.RefreshPlayerInfoOptInfo = HL.Method(HL.Number, HL.String) << function(self, hudSeatIndex, stateName)
    local playInfoNode = self:_GetPlayerInfoNode(hudSeatIndex)
    if playInfoNode.optInfoStateNode.currentStateName ~= stateName then
        playInfoNode.optInfoStateNode:SetState(stateName)
    end
end


CardGameBlackjackHudCtrl.RefreshLightBarColorByState = HL.Method(HL.Number, HL.String) << function(self, hudSeatIndex, stateName)
    local config = self.m_scene.sceneRoot.view.config
    local color
    if stateName == "StopPickCard" then
        color = config.LIGHT_BAR_STOP_CARD_COLOR
    elseif stateName == "PickCard" then
        color = config.LIGHT_BAR_PICK_CARD_COLOR
    elseif stateName == "Bust" then
        color = config.LIGHT_BAR_BUST_COLOR
    elseif stateName == "PickCardTimeWillOut" then
        color = config.COUNT_DOWN_WARNING_COLOR
    elseif stateName == "ChoiceComplete" then
        color = config.COUNT_DOWN_NORMAL_COLOR
    end
    if color == nil then
        self:HideLightBar(hudSeatIndex)
        return
    end
    if self.m_lightBarStates[hudSeatIndex] == stateName then
        return
    end
    self:_ShowLightBar(hudSeatIndex, stateName, color)
end

CardGameBlackjackHudCtrl.ShowPlayerInfoOptInfo = HL.Method(HL.Number, HL.Boolean) << function(self, hudSeatIndex, isShow)
    local playInfoNode = self:_GetPlayerInfoNode(hudSeatIndex)
    playInfoNode.optInfoStateNode.gameObject:SetActive(isShow)
end




CardGameBlackjackHudCtrl.RefreshPlayerInfoGameSign = HL.Method(HL.Number, HL.String) << function(self, hudSeatIndex, stateName)
    local gameSignNode = self.view.hudMain.relicInfoNode["relicInfo_" .. hudSeatIndex].gameSignNode
    gameSignNode.stateController:SetState(stateName)
    if stateName ~= "StartFlag" then
        self:_HideGameSignTips(hudSeatIndex)
    end
end

CardGameBlackjackHudCtrl.ShowPlayerInfoGameSign = HL.Method(HL.Number, HL.Boolean) << function(self, hudSeatIndex, isShow)
    local gameSignNode = self.view.hudMain.relicInfoNode["relicInfo_" .. hudSeatIndex].gameSignNode
    gameSignNode.gameObject:SetActive(isShow)
    
    if not isShow then
        self:_HideGameSignTips(hudSeatIndex)
    end
end


CardGameBlackjackHudCtrl._TryShowGameSignTips = HL.Method(HL.Number).Return(HL.Boolean) << function(self, hudSeatIndex)
    local gameSignNode = self.view.hudMain.relicInfoNode["relicInfo_" .. hudSeatIndex].gameSignNode
    if gameSignNode.stateController.currentStateName ~= "StartFlag" then
        return false
    end
    gameSignNode.tipsNode.gameObject:SetActive(true)
    gameSignNode.tipsNode.animationWrapper:PlayInAnimation()
    return true
end

CardGameBlackjackHudCtrl._HideGameSignTips = HL.Method(HL.Number) << function(self, hudSeatIndex)
    local timer = self.m_gameSignTipsTimers[hudSeatIndex]
    if timer then
        self:_ClearTimer(timer)
        self.m_gameSignTipsTimers[hudSeatIndex] = nil
    end
    local gameSignNode = self.view.hudMain.relicInfoNode["relicInfo_" .. hudSeatIndex].gameSignNode
    gameSignNode.tipsNode.animationWrapper:PlayOutAnimation(function()
        gameSignNode.tipsNode.gameObject:SetActive(false)
    end)
end

CardGameBlackjackHudCtrl.RefreshPlayerInfoSelfIsWatch = HL.Method(HL.Boolean) << function(self, isWatch)
    local playInfoNode = self:_GetPlayerInfoNode(1)
    playInfoNode.stateController:SetState(isWatch and "Watch" or "Normal")
end


CardGameBlackjackHudCtrl.ShowOtherPlayerInfoAIIcon = HL.Method(HL.Number, HL.Boolean) << function(self, hudSeatIndex, isShow)
    local playInfoNode = self:_GetPlayerInfoNode(hudSeatIndex)
    playInfoNode.aiIcon.gameObject:SetActive(isShow)
end

CardGameBlackjackHudCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    local memberId = unpack(arg)
    local hudSeat = LuaSystemManager.cardGameBlackjackSystem:GetHudSeatByMemberId(memberId)
    if hudSeat ~= nil and hudSeat ~= 1 then
        self:ShowOtherPlayerInfoAIIcon(hudSeat, CardGameUtils.IsMemberShowAI(memberId))
    end
end



CardGameBlackjackHudCtrl.SetTableInfoCountDownProgress = HL.Method(HL.Number, HL.Number) << function(self, curTime, maxTime)
    local countDownNode = self.view.hudMain.tableInfoNode.countDownNode
    countDownNode.countDownTimeTxt.text = tostring(math.floor(curTime))
    local warning = curTime <= CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME
    countDownNode.stateController:SetState(warning and "Warning" or "Normal")

    local progress = 0
    if maxTime > 0 then
        progress = lume.clamp(curTime / maxTime, 0, 1)
    end
    countDownNode.countDownBar.fillAmount = progress
    self:_RefreshCountDownBarProgress(progress)
    local color = warning
        and self.m_scene.sceneRoot.view.config.COUNT_DOWN_WARNING_COLOR
        or self.m_scene.sceneRoot.view.config.COUNT_DOWN_NORMAL_COLOR
    self:_RefreshCountDownBarColor(color)
end


CardGameBlackjackHudCtrl.ShowTableInfoCountDown = HL.Method(HL.Boolean) << function(self, isShow)
    local countDownBar3D = self.m_scene.sceneRoot.view.countDownBar
    local countDownNode = self.view.hudMain.tableInfoNode.countDownNode
    
    local preIsShow = countDownNode.gameObject.activeSelf
    countDownNode.gameObject:SetActive(isShow)
    if preIsShow ~= isShow then
        local aniWrapper = self.m_scene.sceneRoot.view.countDownBarAniWrapper
        
        aniWrapper:ClearTween(false)
        if isShow then
            countDownBar3D.gameObject:SetActive(true)
            aniWrapper:PlayInAnimation()
        else
            aniWrapper:PlayOutAnimation(function()
                countDownBar3D.gameObject:SetActive(false)
            end)
        end
    end
    if isShow then
        self:ShowTableInfoCenterArrow(false)
    end
end



CardGameBlackjackHudCtrl.ShowTableInfoCenterArrow = HL.Method(HL.Boolean, HL.Opt(HL.Number)) << function(self, isShow, hudSeatIndex)
    local centerArrowNode = self.view.hudMain.tableInfoNode.centerArrowNode
    local preIsShow = centerArrowNode.gameObject.activeSelf
    if not isShow then
        self.m_centerArrowRotateUpdateKey = self:_RemoveUpdate(self.m_centerArrowRotateUpdateKey)
    end
    
    if preIsShow ~= isShow then
        if isShow then
            centerArrowNode.gameObject:SetActive(true)
            centerArrowNode.animationWrapper:PlayInAnimation()
        else
            centerArrowNode.animationWrapper:PlayOutAnimation(function()
                centerArrowNode.gameObject:SetActive(false)
            end)
        end
    end
    if isShow then
        self:ShowTableInfoCountDown(false)
        
        if hudSeatIndex and hudSeatIndex ~= self.m_centerArrowHudSeat then
            self.m_centerArrowRotateUpdateKey = self:_RemoveUpdate(self.m_centerArrowRotateUpdateKey)
            self.m_centerArrowHudSeat = hudSeatIndex
            local wrapper = centerArrowNode.animationWrapper
            local targetPercent = ((hudSeatIndex - 3) % 4) / 4
            if preIsShow then
                local rotateDuration = self.view.hudMain.config.CENTER_ARROW_ROT_ANI_TIME
                local percent = self.m_centerArrowPercent
                local toPercent = percent + (targetPercent - percent) % 1
                local speed = (toPercent - percent) / rotateDuration
                self.m_centerArrowRotateUpdateKey = self:_StartUpdate(function(deltaTime)
                    percent = math.min(percent + deltaTime * speed, toPercent)
                    self.m_centerArrowPercent = percent % 1
                    wrapper:SampleClipAtPercent("centerarrow_rotation", self.m_centerArrowPercent, false)
                    if percent >= toPercent then
                        self.m_centerArrowRotateUpdateKey = self:_RemoveUpdate(self.m_centerArrowRotateUpdateKey)
                    end
                end)
            else
                self.m_centerArrowPercent = targetPercent
                centerArrowNode.stateController:SetState("PointTo" .. hudSeatIndex)
            end
        end
    end
end






CardGameBlackjackHudCtrl.RefreshTableInfoTableTipsState = HL.Method(HL.String) << function(self, state)
    self.view.hudMain.tableInfoNode.tableTipsNode.stateController:SetState(state)
end


CardGameBlackjackHudCtrl.ShowTableInfoTableTips = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isShow, skipAni)
    local tableTipsNode = self.view.hudMain.tableInfoNode.tableTipsNode
    local wrapper = tableTipsNode.animationWrapper
    
    local preIsShow = tableTipsNode.gameObject.activeSelf
        and wrapper.curState ~= CS.Beyond.UI.UIConst.AnimationState.Out
    if preIsShow == isShow and not skipAni then
        return
    end
    
    wrapper:ClearTween(false)
    if isShow then
        tableTipsNode.gameObject:SetActive(true)
        if skipAni then
            wrapper:SampleToInAnimationEnd()
        else
            wrapper:PlayInAnimation()
        end
    else
        if skipAni then
            wrapper:SampleToOutAnimationEnd()
            tableTipsNode.gameObject:SetActive(false)
        else
            wrapper:PlayOutAnimation(function()
                tableTipsNode.gameObject:SetActive(false)
            end)
        end
    end
end


CardGameBlackjackHudCtrl.RefreshTableInfoTableTips = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAni)
    local state = self:_CalcTableTipsState()
    if state ~= nil then
        self:RefreshTableInfoTableTipsState(state)
    end
    self:ShowTableInfoTableTips(state ~= nil, skipAni)
end


CardGameBlackjackHudCtrl._CalcTableTipsState = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local phase = system:GetClientPhase()
    local remain = system:GetCountDownRemain()
    local isCountDownWarning = remain > 0 and remain < CardGameBlackjackUtils.COUNT_DOWN_WARNING_TIME
    if phase == CardGameBlackjackUtils.CLIENT_PHASE.Shop or phase == CardGameBlackjackUtils.CLIENT_PHASE.ShopWait then
        return isCountDownWarning and "GameStart" or "WaitingReady"
    end
    
    if phase == CardGameBlackjackUtils.CLIENT_PHASE.RoundEndWait then
        return "WaitingReady"
    end

    if phase ~= CardGameBlackjackUtils.CLIENT_PHASE.Battle
            or system:GetBattleSubPhase() ~= CardGameBlackjackUtils.BATTLE_SUB_PHASE.WaitPick then
        return nil
    end
    
    if self:_IsSelfPickTimeWillOut() then
        return "PickCardTimeWillOut"
    end
    
    if isCountDownWarning and not system:IsSpectateCountDown() and system:IsAllAliveMembersChosenDone() then
        return "OpenCard"
    end
    return nil
end

CardGameBlackjackHudCtrl.RefreshTableInfoCardDeckCount = HL.Method(HL.Number, HL.Number) << function(self, hudSeatIndex, count)
    local cardDeck = self:_GetCardDeck(hudSeatIndex)
    cardDeck.cardCountTxt.text = count
    self:_RefreshCardCountNodeHeight(hudSeatIndex, count)
    
    self:_RefreshNaviArrow()
end



CardGameBlackjackHudCtrl._RefreshCardCountNodeHeight = HL.Method(HL.Number, HL.Number) << function(self, hudSeatIndex, count)
    local nodeTrans = self:_GetCardDeck(hudSeatIndex).cardCountNode.transform
    local pos = nodeTrans.localPosition
    pos.z = 0

    local region = LuaSystemManager.cardGameSystem:GetRegion(CardGameBlackjackUtils.CARD_REGION_PLAYER_DECK_PREFIX .. hudSeatIndex)
    local layout = region and region:GetLayout()
    if not IsNull(layout) and layout.layoutData ~= nil then
        local worldStep = layout.transform:TransformVector(layout.layoutData.stackOffset)
        local localStep = nodeTrans.parent:InverseTransformVector(worldStep)
        pos.z = localStep.z * lume.clamp(count, 0, CARD_COUNT_NODE_MAX_HEIGHT_COUNT)
    end
    nodeTrans.localPosition = pos
end

CardGameBlackjackHudCtrl.ShowTableInfoCardDeck = HL.Method(HL.Boolean) << function(self, isShow)
    for i = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        self:_GetCardDeck(i).gameObject:SetActive(isShow)
    end
end

CardGameBlackjackHudCtrl.RefreshTableInfoPointInfoPoint = HL.Method(HL.Number, HL.Number, HL.Number) << function(self, hudSeatIndex, curPoint, maxPoint)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    pointInfo.curPointTxt.text = curPoint
    pointInfo.maxPointTxt.text = maxPoint
    local progress = 0
    if maxPoint > 0 then
        progress = math.min(math.max(curPoint / maxPoint, 0), 1)
    end
    pointInfo.pointProgressBar.fillAmount = progress
end

CardGameBlackjackHudCtrl.RefreshTableInfoPointInfoExtraPoint = HL.Method(HL.Number, HL.Number) << function(self, hudSeatIndex, value)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    pointInfo.extraPointTxt.text = CardGameUtils.GetNumDeltaText(value)
end

CardGameBlackjackHudCtrl.ShowTableInfoPointInfoExtraPoint = HL.Method(HL.Number, HL.Boolean) << function(self, hudSeatIndex, isShow)
    local pointInfo = self:_GetPointInfo(hudSeatIndex)
    pointInfo.extraPointNode.gameObject:SetActive(isShow)
end






CardGameBlackjackHudCtrl.SetTableInfoPointInfoState = HL.Method(HL.Number, HL.String, HL.Opt(HL.Boolean)) << function(self, index, stateName, playAudio)
    local pointInfo = self:_GetPointInfo(index)
    if playAudio and pointInfo.stateController.currentStateName ~= stateName then
        if stateName == "PointBust" then
            AudioAdapter.PostEvent("Au_UI_Event_CardBust")
        elseif stateName == "PointFull" then
            AudioAdapter.PostEvent("Au_UI_Event_CardFullPoint")
        end
    end
    pointInfo.stateController:SetState(stateName)
end

CardGameBlackjackHudCtrl.ShowTableInfoPointInfo = HL.Method(HL.Number, HL.Boolean) << function(self, index, isShow)
    local pointInfo = self:_GetPointInfo(index)
    local preIsShow = pointInfo.gameObject.activeSelf
    if preIsShow ~= isShow then
        if isShow then
            pointInfo.gameObject:SetActive(true)
            pointInfo.animationWrapper:PlayInAnimation()
        else
            pointInfo.animationWrapper:PlayOutAnimation(function()
                pointInfo.gameObject:SetActive(false)
            end)
        end
    end
end




CardGameBlackjackHudCtrl._RecoverOptInfoBtns = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    if not system:IsHudPickTipsShow() then
        self:SetOptInfoBtnsEmpty(false)
        return
    end
    self:SetOptInfoBtnsSelectable(false)
    local pickResult = system.m_selfPickResult
    if pickResult ~= nil then
        self:SetOptInfoBtnsPicked(pickResult)
    end
end


CardGameBlackjackHudCtrl._RecoverOptInfoPickCardBtnTips = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local isShow = system:IsHudPickTipsShow()
    if isShow then
        system:RefreshHudPickTips(self)
    end
    self:ShowOptInfoPickCardBtnTipsNode(isShow)
end

CardGameBlackjackHudCtrl.RefreshOptInfoTipsBustProbability = HL.Method(HL.Number) << function(self, probability)
    local optInfoNode = self.view.optInfoNode
    optInfoNode.bustProbabilityTxt.text = probability .. "%"
    local config = self.m_scene.sceneRoot.view.config
    if probability <= config.BUST_PROBABILITY_LEVEL_1 then
        optInfoNode.pickCardBtnTipsNode:SetState("BustProbabilityLow")
    elseif probability < config.BUST_PROBABILITY_LEVEL_2 then
        optInfoNode.pickCardBtnTipsNode:SetState("BustProbabilityMedium")
    else
        optInfoNode.pickCardBtnTipsNode:SetState("BustProbabilityHigh")
    end
end


CardGameBlackjackHudCtrl.RefreshOptInfoTipsNoCards = HL.Method() << function(self)
    self.view.optInfoNode.pickCardBtnTipsNode:SetState("NoCards")
end


CardGameBlackjackHudCtrl.RefreshOptInfoTipsFullCards = HL.Method() << function(self)
    self.view.optInfoNode.pickCardBtnTipsNode:SetState("FullCards")
end

CardGameBlackjackHudCtrl.ShowOptInfoPickCardBtnTipsNode = HL.Method(HL.Boolean) << function(self, isShow)
    self.view.optInfoNode.pickCardBtnTipsNode.gameObject:SetActive(isShow)
end

CardGameBlackjackHudCtrl.ShowOptInfoNode = HL.Method(HL.Boolean) << function(self, isShow)
    self.view.optInfoNode.gameObject:SetActive(isShow)
end

CardGameBlackjackHudCtrl.RefreshOptInfoPickCardBtnState = HL.Method(HL.String) << function(self, state)
    local optInfoNode = self.view.optInfoNode
    CardGameBlackjackHudCtrl.RefreshOptInfoBtnState(optInfoNode.pickCardBtn, optInfoNode.pickCardBtnStateCtrl,
            optInfoNode.pickCardBtnKeyHint, state)
end

CardGameBlackjackHudCtrl.RefreshOptInfoStopBtnState = HL.Method(HL.String) << function(self, state)
    local optInfoNode = self.view.optInfoNode
    CardGameBlackjackHudCtrl.RefreshOptInfoBtnState(optInfoNode.stopBtn, optInfoNode.stopBtnStateCtrl,
            optInfoNode.stopBtnKeyHint, state)
end









CardGameBlackjackHudCtrl.RefreshOptInfoBtnState = HL.StaticMethod(HL.Any, HL.Any, CS.Beyond.UI.UIActionKeyHint, HL.String)
        << function(btn, btnStateCtrl, keyHint, state)
    btnStateCtrl:SetState(state)
    btn.enabled = state ~= "Empty"
    keyHint.gameObject:SetActive(state ~= "Empty")
end





CardGameBlackjackHudCtrl.SetOptInfoBtnsEmpty = HL.Method(HL.Boolean) << function(self, playAni)
    self:RefreshOptInfoPickCardBtnState("Empty")
    self:RefreshOptInfoStopBtnState("Empty")
    self:_RefreshOptInfoBtnsAni(false, playAni)
end



CardGameBlackjackHudCtrl.SetOptInfoBtnsSelectable = HL.Method(HL.Boolean) << function(self, playAni)
    self:RefreshOptInfoPickCardBtnState("Normal")
    self:RefreshOptInfoStopBtnState("Normal")
    self:_RefreshOptInfoBtnsAni(true, playAni)
end


CardGameBlackjackHudCtrl._RefreshOptInfoBtnsAni = HL.Method(HL.Boolean, HL.Boolean) << function(self, isIn, playAni)
    local needPlay = playAni and self.m_isOptInfoBtnsIn ~= isIn
    self.m_isOptInfoBtnsIn = isIn
    local optInfoNode = self.view.optInfoNode
    CardGameBlackjackHudCtrl._RefreshOptInfoBtnAni(optInfoNode.pickCardBtnAniWrapper, isIn, needPlay)
    CardGameBlackjackHudCtrl._RefreshOptInfoBtnAni(optInfoNode.stopBtnAniWrapper, isIn, needPlay)
end

CardGameBlackjackHudCtrl._RefreshOptInfoBtnAni = HL.StaticMethod(CS.Beyond.UI.UIAnimationWrapper, HL.Boolean, HL.Boolean) << function(aniWrapper, isIn, needPlay)
    if isIn then
        if needPlay then
            aniWrapper:PlayInAnimation()
        else
            aniWrapper:SampleToInAnimationEnd()
        end
    else
        if needPlay then
            aniWrapper:PlayOutAnimation()
        else
            aniWrapper:SampleToOutAnimationEnd()
        end
    end
end


CardGameBlackjackHudCtrl.SetOptInfoBtnsPicked = HL.Method(HL.Boolean) << function(self, pick)
    self:RefreshOptInfoPickCardBtnState(pick and "Select" or "NotSelect")
    self:RefreshOptInfoStopBtnState(pick and "NotSelect" or "Select")
end



CardGameBlackjackHudCtrl.OnClickEmojiPopupBtn = HL.Method() << function(self)
    if LuaSystemManager.cardGameBlackjackSystem:IsEmojiInCd() then
        return
    end

    local emojiNode = self.view.emojiNode
    local isShow = emojiNode.emojiPopupNode.gameObject.activeSelf
    if isShow then
        self:HideEmojiPopup()
    else
        self:ShowEmojiPopup()
    end
end

CardGameBlackjackHudCtrl.ShowEmojiPopup = HL.Method() << function(self)
    local emojiNode = self.view.emojiNode
    emojiNode.emojiPopupNode:SetEmojiNodeActive(true)
    emojiNode.emojiPopupBtn.nodeState:SetState("Click")
end

CardGameBlackjackHudCtrl.HideEmojiPopup = HL.Method() << function(self)
    local emojiNode = self.view.emojiNode
    emojiNode.emojiPopupNode:SetEmojiNodeActive(false)
    emojiNode.emojiPopupBtn.nodeState:SetState("Normal")
end

CardGameBlackjackHudCtrl.SetEmojiCdState = HL.Method(HL.Boolean) << function(self, inCd)
    local emojiNode = self.view.emojiNode
    emojiNode.emojiPopupBtn.nodeState:SetState(inCd and "Time" or "Normal")
    emojiNode.emojiPopupBtn.button.interactable = not inCd
end

CardGameBlackjackHudCtrl.RefreshEmojiCd = HL.Method(HL.Number) << function(self, cdTime)
    self.view.emojiNode.emojiPopupBtn.numTxt.text = string.format("%ds", math.ceil(cdTime))
end

CardGameBlackjackHudCtrl.PlayEmojiBySeatIndex = HL.Method(HL.Number, HL.String, HL.Opt(HL.String))
    << function(self, hudSeatIndex, emojiId, charId)
    local cell = self:_GetPlayerInfoNode(hudSeatIndex)
    if not cell then
        return
    end
    cell.emojiNode:Init(emojiId)
    cell.emojiNode:Play(charId)
end






CardGameBlackjackHudCtrl._RefreshCountDownBarColor = HL.Method(CS.UnityEngine.Color) << function(self, color)
    self.m_scene.sceneRoot.view.countDownBar:SetColor("MainColor", color)
end


CardGameBlackjackHudCtrl._RefreshCountDownBarProgress = HL.Method(HL.Number) << function(self, value)
    local x = -0.62 + (0.15 - (-0.62)) * value
    self.m_scene.sceneRoot.view.countDownBar:SetTextureOffset("MainOffset", Vector2(x, 0))
end


CardGameBlackjackHudCtrl._ShowLightBar = HL.Method(HL.Number, HL.String, CS.UnityEngine.Color) << function(self, index, stateName, color)
    local lightBar = self.m_scene.sceneRoot.view["lightBar_" .. index]
    local lightBarAni = self.m_scene.sceneRoot.view["lightBarAniWrapper_" .. index]
    local lastState = self.m_lightBarStates[index]
    self.m_lightBarStates[index] = stateName
    if lastState == nil then
        lightBar:SetColor("MainColor", color)
        lightBarAni:SampleToInAnimationEnd()
        return
    end
    if lastState == false then
        lightBar:SetColor("MainColor", color)
        lightBarAni:PlayInAnimation()
        return
    end
    lightBarAni:PlayOutAnimation(function()
        if self.m_lightBarStates[index] ~= stateName then
            return
        end
        lightBar:SetColor("MainColor", color)
        lightBarAni:PlayInAnimation()
    end)
end

CardGameBlackjackHudCtrl.HideLightBar = HL.Method(HL.Number) << function(self, index)
    local lastState = self.m_lightBarStates[index]
    if lastState == false then
        return
    end
    self.m_lightBarStates[index] = false
    local lightBarAni = self.m_scene.sceneRoot.view["lightBarAniWrapper_" .. index]
    if lastState == nil then
        lightBarAni:SampleToOutAnimationEnd()
        return
    end
    lightBarAni:PlayOutAnimation()
end



CardGameBlackjackHudCtrl._GetCardDeck = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, index)
    if index < 1 or index > CardGameBlackjackUtils.MAX_SEAT_COUNT then
        logger.error(string.format("CardGameBlackjackHudCtrl._GetCardDeck: invalid index=%d", index))
        return nil
    end
    return self.view.hudMain.tableInfoNode["cardDeck_" .. index]
end

CardGameBlackjackHudCtrl._GetPlayerInfoNode = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, index)
    if index < 1 or index > CardGameBlackjackUtils.MAX_SEAT_COUNT then
        logger.error(string.format("CardGameBlackjackHudCtrl._GetPlayerInfoNode: invalid index=%d", index))
        return nil
    end
    return self.view.playerInfoNode["playerInfo_" .. index]
end

CardGameBlackjackHudCtrl._GetPointInfo = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, index)
    if index < 1 or index > CardGameBlackjackUtils.MAX_SEAT_COUNT then
        logger.error(string.format("CardGameBlackjackHudCtrl._GetPointInfo: invalid index=%d", index))
        return nil
    end
    return self.view.hudMain.tableInfoNode["pointInfo_" .. index]
end




CardGameBlackjackHudCtrl._BindHudSeatNavi = HL.Method() << function(self)
    local relicInfoNode = self.view.hudMain.relicInfoNode
    local tableInfoNode = self.view.hudMain.tableInfoNode
    local relicInfoDecos = {}
    local cardDeckDecos = {}
    local handZoneDecos = {}
    self.m_hudSeatNaviSelectables = {}
    self.m_hudSeatButtons = {}
    self.m_handZoneNaviSeats = {}
    self.m_naviArrowRoots = {}
    for i = 1, CardGameBlackjackUtils.MAX_SEAT_COUNT do
        local relicInfo = relicInfoNode["relicInfo_" .. i]
        local cardDeck = self:_GetCardDeck(i)
        local handZoneBtn = tableInfoNode["handZoneBtn_" .. i]
        relicInfoDecos[i] = relicInfo.naviDeco
        cardDeckDecos[i] = cardDeck.naviDeco
        handZoneDecos[i] = handZoneBtn.naviDeco
        self.m_naviArrowRoots[relicInfoDecos[i]] = relicInfo.naviArrowRoot
        self.m_naviArrowRoots[cardDeckDecos[i]] = cardDeck.naviArrowRoot
        self.m_naviArrowRoots[handZoneDecos[i]] = handZoneBtn.naviArrowRoot
        table.insert(self.m_hudSeatButtons, relicInfo.button)
        table.insert(self.m_hudSeatButtons, cardDeck.button)
        table.insert(self.m_hudSeatButtons, handZoneBtn.button)
        self.m_handZoneNaviSeats[handZoneDecos[i]] = i
        table.insert(self.m_hudSeatNaviSelectables, relicInfoDecos[i])
        table.insert(self.m_hudSeatNaviSelectables, cardDeckDecos[i])
        table.insert(self.m_hudSeatNaviSelectables, handZoneDecos[i])
    end

    
    self.m_hudSeatNaviMap = {
        [relicInfoDecos[1]] = { handZoneDecos[1], nil, cardDeckDecos[2], cardDeckDecos[1] },
        [relicInfoDecos[2]] = { cardDeckDecos[3], cardDeckDecos[2], nil, handZoneDecos[2] },
        [relicInfoDecos[3]] = { nil, handZoneDecos[3], cardDeckDecos[3], cardDeckDecos[4] },
        [relicInfoDecos[4]] = { cardDeckDecos[4], cardDeckDecos[1], handZoneDecos[4], nil },
        [cardDeckDecos[1]] = { handZoneDecos[4], nil, relicInfoDecos[1], relicInfoDecos[4] },
        [cardDeckDecos[2]] = { relicInfoDecos[2], relicInfoDecos[1], nil, handZoneDecos[1] },
        [cardDeckDecos[3]] = { nil, handZoneDecos[2], relicInfoDecos[2], relicInfoDecos[3] },
        [cardDeckDecos[4]] = { relicInfoDecos[3], relicInfoDecos[4], handZoneDecos[3], nil },
        [handZoneDecos[1]] = { handZoneDecos[3], relicInfoDecos[1], cardDeckDecos[2], cardDeckDecos[1] },
        [handZoneDecos[2]] = { cardDeckDecos[3], cardDeckDecos[2], relicInfoDecos[2], handZoneDecos[4] },
        [handZoneDecos[3]] = { relicInfoDecos[3], handZoneDecos[1], cardDeckDecos[3], cardDeckDecos[4] },
        [handZoneDecos[4]] = { cardDeckDecos[4], cardDeckDecos[1], handZoneDecos[2], relicInfoDecos[4] },
    }

    for _, selectable in ipairs(self.m_hudSeatNaviSelectables) do
        selectable.hideNaviHint = true
        selectable.customNaviTargetInDirFunc = function(dir)
            return self:_GetHudSeatNaviTarget(selectable, dir)
        end
        selectable.onIsNaviTargetChanged = function(isTarget)
            self:_OnHudSeatNaviTargetChanged(selectable, isTarget)
        end
        
        
        InputManagerInst:ToggleGroup(selectable:GetComponent("InputBindingGroupMonoTarget").groupId,
            not DeviceInfo.usingController or selectable.isNaviTarget)
    end
end


CardGameBlackjackHudCtrl._GetHudSeatNaviTarget = HL.Method(HL.Any, HL.Any).Return(HL.Any) << function(self, selectable, dir)
    local dirIndex = self:_GetHudSeatNaviDirIndex(dir)
    if dirIndex == nil then
        return selectable
    end
    local target = self.m_hudSeatNaviMap[selectable][dirIndex]
    while target ~= nil and not self:_IsHudSeatNaviTargetAvailable(target) do
        target = self.m_hudSeatNaviMap[target][dirIndex]
    end
    return target or selectable
end


CardGameBlackjackHudCtrl._GetHudSeatNaviDirIndex = HL.Method(HL.Any).Return(HL.Opt(HL.Number)) << function(self, dir)
    if dir == NAVI_DIRECTION.Up then
        return 1
    elseif dir == NAVI_DIRECTION.Down then
        return 2
    elseif dir == NAVI_DIRECTION.Left then
        return 3
    elseif dir == NAVI_DIRECTION.Right then
        return 4
    end
    return nil
end

CardGameBlackjackHudCtrl._OnHudSeatNaviTargetChanged = HL.Method(HL.Any, HL.Boolean) << function(self, selectable, isTarget)
    
    if isTarget and not self:_IsHudSeatNaviTargetAvailable(selectable) then
        self:SetNaviTarget(self.m_hudSeatNaviSelectables[1])
        return
    end
    if isTarget then
        self.m_curHudSeatNaviSelectable = selectable
    elseif self.m_curHudSeatNaviSelectable == selectable then
        self.m_curHudSeatNaviSelectable = nil
    end
    self:_RefreshNaviArrow()
end

CardGameBlackjackHudCtrl._UnbindHudSeatNavi = HL.Method() << function(self)
    if self.m_hudSeatNaviSelectables == nil then
        return
    end
    for _, selectable in pairs(self.m_hudSeatNaviSelectables) do
        selectable.customNaviTargetInDirFunc = nil
        selectable.onIsNaviTargetChanged = nil
    end
    self.m_hudSeatNaviSelectables = nil
    self.m_hudSeatButtons = nil
    self.m_handZoneNaviSeats = nil
    self.m_hudSeatNaviMap = nil
    self.m_naviArrowRoots = nil
    self.m_curHudSeatNaviSelectable = nil
    self.m_lastHudSeatNaviAllowed = false
end


CardGameBlackjackHudCtrl._IsHudSeatNaviTargetAvailable = HL.Method(HL.Any).Return(HL.Boolean) << function(self, selectable)
    local hudSeat = self.m_handZoneNaviSeats and self.m_handZoneNaviSeats[selectable]
    return hudSeat == nil or LuaSystemManager.cardGameBlackjackSystem:GetHandCardCountByHudSeat(hudSeat) > 0
end



CardGameBlackjackHudCtrl._EnsureHudSeatNaviTargetAvailable = HL.Method() << function(self)
    if self.m_hudSeatNaviSelectables == nil or not self:_IsHudSeatNaviAllowed() then
        return
    end
    local cur = self.m_curHudSeatNaviSelectable
    if cur ~= nil and not self:_IsHudSeatNaviTargetAvailable(cur) then
        
        self:SetNaviTarget(self.m_hudSeatNaviSelectables[1])
    end
end



CardGameBlackjackHudCtrl._SetDefaultHudSeatNaviTarget = HL.Method() << function(self)
    local cur = self.m_curHudSeatNaviSelectable
    if cur ~= nil and self:_IsHudSeatNaviTargetAvailable(cur) then
        return
    end
    
    local target = self.m_hudSeatNaviSelectables[1]
    if self:_IsNaviHeldByOtherLayer(target) then
        target.naviGroup:SetLayerSelectedTarget(target, true)
    else
        self:SetNaviTarget(target)
    end
end



CardGameBlackjackHudCtrl._IsNaviHeldByOtherLayer = HL.Method(HL.Any).Return(HL.Boolean) << function(self, seatSelectable)
    local naviMgr = InputManagerInst.controllerNaviManager
    if not naviMgr:IsPanelScopeTop(self.panelId) then
        return false
    end
    local curTarget = naviMgr.curTarget
    if IsNull(curTarget) or not curTarget.isActiveAndEnabled then
        return false
    end
    local layer = curTarget:GetLayerGroup()
    return layer ~= seatSelectable:GetLayerGroup() and layer ~= self.naviGroup:GetLayerGroup()
end


CardGameBlackjackHudCtrl._IsHudSeatNaviAllowed = HL.Method().Return(HL.Boolean) << function(self)
    return LuaSystemManager.cardGameBlackjackSystem.m_hudSeatNaviAllowed
        and not self.view.hudChoosePopup.gameObject.activeSelf
end

CardGameBlackjackHudCtrl.RefreshHudSeatNavi = HL.Method() << function(self)
    local allowed = self:_IsHudSeatNaviAllowed()
    self.view.quickMenuHintNode:SetAvailable(allowed)

    if self.m_hudSeatNaviSelectables == nil then
        self:_RefreshNaviArrow()
        return
    end
    local becameAllowed = allowed and not self.m_lastHudSeatNaviAllowed
    self.m_lastHudSeatNaviAllowed = allowed

    for _, selectable in pairs(self.m_hudSeatNaviSelectables) do
        selectable.enabled = allowed
    end
    for _, button in pairs(self.m_hudSeatButtons) do
        button.enabled = allowed
    end

    if not allowed then
        local hadSeatFocus = self.m_curHudSeatNaviSelectable ~= nil
        self.m_curHudSeatNaviSelectable = nil
        
        if not self:_TrySetHudChoosePopupNavi() and hadSeatFocus then
            self:ClearNaviTarget()
        end
        self:_RefreshNaviArrow()
        return
    end

    if becameAllowed then
        self:_SetDefaultHudSeatNaviTarget()
    else
        self:_EnsureHudSeatNaviTargetAvailable()
    end
    self:_RefreshNaviArrow()
end



CardGameBlackjackHudCtrl._TrySetHudChoosePopupNavi = HL.Method().Return(HL.Boolean) << function(self)
    if not DeviceInfo.usingController or not self.m_hudChooseCanSelect
        or not self.view.hudChoosePopup.gameObject.activeSelf then
        return false
    end
    local cellCache = self.m_hudChoosePopupPokerCellCache
    if cellCache:GetCount() == 0 then
        return false
    end
    local index = self.m_hudChooseSelectedIndex
    if index < 1 or index > cellCache:GetCount() then
        index = 1
    end
    self:SetNaviTarget(cellCache:Get(index).naviDeco)
    return true
end

CardGameBlackjackHudCtrl._GetNaviArrowTransform = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    local scene = self.m_scene
    local emptyRoot = scene and scene.sceneRoot and scene.sceneRoot.view and scene.sceneRoot.view.emptyRoot
    local naviArrow = emptyRoot and emptyRoot.naviArrow
    if IsNull(naviArrow) then
        return nil
    end
    return naviArrow.transform or naviArrow
end

CardGameBlackjackHudCtrl._RefreshNaviArrow = HL.Method() << function(self)
    local arrowTrans = self:_GetNaviArrowTransform()
    if arrowTrans == nil then
        return
    end

    local target = nil
    if DeviceInfo.usingController and self:_IsHudSeatNaviAllowed() then
        target = self.m_curHudSeatNaviSelectable
    end

    arrowTrans.gameObject:SetActive(target ~= nil)
    if target then
        
        local arrowRoot = self.m_naviArrowRoots and self.m_naviArrowRoots[target]
        local anchorTrans = IsNull(arrowRoot) and target.transform or arrowRoot.transform
        arrowTrans.position = anchorTrans.position
    end
end


HL.Commit(CardGameBlackjackHudCtrl)
