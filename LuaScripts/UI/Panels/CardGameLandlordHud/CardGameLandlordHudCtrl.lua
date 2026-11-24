local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local FLOW_STATE = require_ex('LuaSystem/CardGame/Doudizhu/Flow/DoudizhuFlowDefine').State
local CardGameDoudizhuSystem = require_ex('LuaSystem/CardGameDoudizhuSystem')
local PresentationType = CS.Beyond.Gameplay.DoudizhuPresentationType







local HUD_COMMAND_KIND = CardGameDoudizhuSystem.HudCommandKind

local HUD_SEAT_TO_RANDOM_SEAT_INDEX = { 1, 2, 4 }

local UI_STATE = {
    Continue = {
        Play = "Activate",
        PlayDisabled = "UnActivate",
        Bid = "RobLandlord",
        Empty = "Null",
        CantAfford = "CantAfford",
    },
    Stop = {
        Bid = "DontRobLandlord",
        Pass = "NotPlay",
        Empty = "Null",
        CantAfford = "CantAfford",
    },
    PlayerRole = {
        Landlord = "Landlord",
        Peasantry = "Peasantry",
    },
    PointInfo = {
        Normal = "Time",
        Warning = "TimeWarning",
        CallLandlord = "CallLandlord",
        RobLandlord = "RobLandlord",
        NoCall = "NoCall",
        NoRob = "NoRob",
    },
    ProgressToast = {
        OpenCard = "OpenCard",
    },
    ExplainToast = {
        Landlord = "Landlord",
        Reset = "Reset",
        AgainLandlord = "AgainLandlord",
    },
    VictoryToast = {
        Landlord = "LandlordVictory",
        Peasantry = "PeasantryVictory",
    },
    SeatTips = {
        RobLandlord = "RobLandlord",
        Peasant = "Peasant",
        Landlord = "Landlord",
        LastCard = "LastCard",
    },
}


local SEAT_TIPS_TYPE = {
    Normal = "Normal",
    LastCard = "LastCard",
}

local POINT_INFO_DECISION_TO_STATE = {
    BidCall = UI_STATE.PointInfo.CallLandlord,
    BidRob = UI_STATE.PointInfo.RobLandlord,
    BidNoCall = UI_STATE.PointInfo.NoCall,
    BidNoRob = UI_STATE.PointInfo.NoRob,
    PlayPass = UI_STATE.PointInfo.NoCall,
    
}

local POINT_INFO_DECISION = {
    BidCall = "BidCall",
    BidRob = "BidRob",
    BidNoCall = "BidNoCall",
    BidNoRob = "BidNoRob",
    PlayCards = "PlayCards",
    PlayPass = "PlayPass",
}

local PLAY_SELECTION_RESULT = CardGameDoudizhuSystem.PlaySelectionResult

local HANDOFF_CONFIG = {
    ZoneBottom = "Bottom",
    CameraDist = 0.6,
    Thickness = 0.003,
    Euler = Vector3(-90, 0, 0),
}

local SELF_HAND_CONFIG = {
    RegionId = "doudizhuHand_self",
    ReferenceLocalSize = Vector3(1.7325, 0.297, 0),
    InteractionRectEpsilon = 0.01,
    TouchpadSwipeStartThreshold = 0.02, 
    TouchpadSwipeStepThreshold = 0.04, 
}


local GUIDE_HAND_CELL_NAME_FORMAT = "GuideHand_%d_%d"
local SELF_HUD_SEAT = 1

local SELECT_CARD_ACTION_ID = "cardgame_select_card"
local SELECT_CARD_RELEASE_ACTION_ID = "cardgame_select_card_release"
local CARD_TYPE_LIST_WIDGET_PATH = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/CardGame/Widgets/CardTypeListNode.prefab"

local QUICK_MENU_DIRECTION_TO_HUD_SEAT = {
    [1] = 1,
    [2] = 2,
    [4] = 3,
}

local CARD_RANGE_SELECTION_MODE = {
    None = "",
    Pointer = "Pointer",
    Controller = "Controller",
    Touchpad = "Touchpad",
}
local POINT_INFO_CONFIG = {
    DeadlineWarningMs = 3000,
    UpdateInterval = UIConst.FAC_COMMON_UI_UPDATE_INTERVAL,
}


local SETTLEMENT_TOAST_DURATION_SECONDS = 2

CardGameLandlordHudCtrl = HL.Class('CardGameLandlordHudCtrl', uiCtrl.UICtrl)







CardGameLandlordHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
}


CardGameLandlordHudCtrl.m_hudAttached = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_seatIntroVisible = HL.Field(HL.Boolean) << false

CardGameLandlordHudCtrl.m_scene = HL.Field(HL.Forward("CardGameSceneDoudizhu"))

CardGameLandlordHudCtrl.m_hudMainView = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_latestHudModel = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_lastFlowState = HL.Field(HL.String) << ""
CardGameLandlordHudCtrl.m_lastProjectedEventId = HL.Field(HL.Any)


CardGameLandlordHudCtrl.m_playerInfoNodes = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_pointInfoNodes = HL.Field(HL.Table)

CardGameLandlordHudCtrl.m_lastBubbleLocalEventId = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_pointInfoDecisions = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_suppressedPointInfoHudSeat = HL.Field(HL.Number) << 0

CardGameLandlordHudCtrl.m_isPlayerHeadInit = HL.Field(HL.Table)

CardGameLandlordHudCtrl.m_seatTipsTypes = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_seatTipsTimers = HL.Field(HL.Table)

CardGameLandlordHudCtrl.m_startFlagShown = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_roleNodeShown = HL.Field(HL.Table)


CardGameLandlordHudCtrl.m_landlordCardWidgets = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_bottomHandoffStates = HL.Field(HL.Table)


CardGameLandlordHudCtrl.m_selfHand3DAligner = HL.Field(CS.Beyond.UI.WorldGoAlignedUI)

CardGameLandlordHudCtrl.m_selfHandCardInstIds = HL.Field(HL.Table)

CardGameLandlordHudCtrl.m_selectedCardInstIdSet = HL.Field(HL.Table)



CardGameLandlordHudCtrl.m_selfHandInteractionNode = HL.Field(GameObject)
CardGameLandlordHudCtrl.m_selfHandInteractionRoot = HL.Field(RectTransform)
CardGameLandlordHudCtrl.m_selfHandInteractionCellCache = HL.Field(HL.Any)
CardGameLandlordHudCtrl.m_selfHandInteractionCellsByUid = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_cardInteractionStateInstIds = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_selfHandInteractionSyncCoroutine = HL.Field(HL.Thread)

CardGameLandlordHudCtrl.m_guideHandRangeFrom = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_guideHandRangeTo = HL.Field(HL.Number) << 0



CardGameLandlordHudCtrl.m_dragSelectionActive = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_dragSelectionPointerId = HL.Field(HL.Number) << -1
CardGameLandlordHudCtrl.m_dragSelectionAnchorIndex = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_dragSelectionFrozenHandInstIds = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_dragSelectionBaselineSet = HL.Field(HL.Table)

CardGameLandlordHudCtrl.m_dragSelectionFrozenBounds = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_dragSelectionLastMinIndex = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_dragSelectionLastMaxIndex = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_dragSelectionPathIndices = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_cardRangeSelectionMode = HL.Field(HL.String) << CARD_RANGE_SELECTION_MODE.None
CardGameLandlordHudCtrl.m_pendingSelectedCardInstIds = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_pointerSelectionButton = HL.Field(CS.Beyond.UI.UIButton)


CardGameLandlordHudCtrl.m_focusClearTimer = HL.Field(HL.Number) << -1
CardGameLandlordHudCtrl.m_focusEpoch = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_cardNaviFocused = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_focusedCardInstId = HL.Field(HL.Number) << 0

CardGameLandlordHudCtrl.m_suppressedHandNaviTarget = HL.Field(CS.Beyond.UI.UIButton)
CardGameLandlordHudCtrl.m_resetCardFocusToFirst = HL.Field(HL.Boolean) << true


CardGameLandlordHudCtrl.m_cardSelectionEnabled = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_handInteractionLocked = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_selfHandInteractionSuppressed = HL.Field(HL.Boolean) << false 
CardGameLandlordHudCtrl.m_selectCardBindingId = HL.Field(HL.Number) << -1


CardGameLandlordHudCtrl.m_touchpadInputRegistered = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_touchpadSwipeStartPos = HL.Field(Vector2)
CardGameLandlordHudCtrl.m_touchpadSwipeAccumulatedX = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_touchpadSwipeStarted = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_touchpadSwipeAnchorInstId = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_onStartSwipeTouchPanel = HL.Field(HL.Function)
CardGameLandlordHudCtrl.m_onSwipeTouchPanel = HL.Field(HL.Function)
CardGameLandlordHudCtrl.m_onEndSwipeTouchPanel = HL.Field(HL.Function)


CardGameLandlordHudCtrl.m_cardTypeListWidget = HL.Field(HL.Forward('CardTypeListNode'))


CardGameLandlordHudCtrl.m_optInfoShown = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_optInfoActive = HL.Field(HL.Boolean) << false
CardGameLandlordHudCtrl.m_optInfoOutPlaying = HL.Field(HL.Boolean) << false


CardGameLandlordHudCtrl.m_deadlineCountdownWindow = HL.Field(HL.Table)
CardGameLandlordHudCtrl.m_deadlineCountdownDurationMs = HL.Field(HL.Number) << 0



CardGameLandlordHudCtrl.m_lastProgressToastEventId = HL.Field(HL.Any)
CardGameLandlordHudCtrl.m_actionToastNodeList = HL.Field(HL.Table)


CardGameLandlordHudCtrl.m_stateToastTimer = HL.Field(HL.Number) << -1
CardGameLandlordHudCtrl.m_stateToastEpoch = HL.Field(HL.Number) << 0
CardGameLandlordHudCtrl.m_actionToastTimer = HL.Field(HL.Number) << -1
CardGameLandlordHudCtrl.m_actionToastEpoch = HL.Field(HL.Number) << 0


CardGameLandlordHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.view.stateController:SetState("DoNotReady")
    self:_BindHudMainFromScene()
    self:_InitUI()
    self:_InitCardInput()
end

CardGameLandlordHudCtrl.OnShow = HL.Override() << function(self)
    
    self:_OnPanelInputBlocked(self.view.inputGroup.internalEnabled)
    self:_SetHudMainActive(true)
    self:_AttachHud()
    self:_RegisterTouchpadCardSelection()
end

CardGameLandlordHudCtrl.OnHide = HL.Override() << function(self)
    
    self.m_suppressedHandNaviTarget = nil
    self:_UnregisterTouchpadCardSelection()
    
    self.m_cardTypeListWidget:Hide()
    self:HideEmojiPopup()
    self:_DetachHud()
    self:_ResetTransientState()
    self:_SetHudMainActive(false)
end

CardGameLandlordHudCtrl.OnClose = HL.Override() << function(self)
    self.view.quickMenuHintNode:SetAvailable(false)
    self.m_suppressedHandNaviTarget = nil
    self:_UnregisterTouchpadCardSelection()
    self:_DetachHud()
end

CardGameLandlordHudCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if IsNull(self.m_hudMainView.gameObject) then
        return
    end
    self.m_hudMainView.inputGroup.internalEnabled = active
    
    self:_RefreshCardFocusState()
    if active then
        
        self:_TryRestoreSelfHandCardFocus()
    end
end

CardGameLandlordHudCtrl._ResetTransientState = HL.Method() << function(self)
    self:PlaySeatIntro(false)
    self:_CloseQuickMenu()
    self.m_cardTypeListWidget:Hide()
    self:_ResetEmojiVisuals()
    self:_ResetDeadlineCountdown()
    self:_ClearStateToast()
    self:_ClearActionToast()
    self:_ClearCardInteractionTimers()
    self:_Clear3DCardInteractionStates()
    self.m_lastProgressToastEventId = nil
    self.m_lastProjectedEventId = nil
    self.m_selectedCardInstIdSet = {}
    self.m_focusedCardInstId = 0
    self.m_guideHandRangeFrom = 0
    self.m_guideHandRangeTo = 0
    self.view.guideHandRange.gameObject:SetActive(false)
    
    self.m_cardSelectionEnabled = false
    self.m_handInteractionLocked = false
    self.m_resetCardFocusToFirst = true
    self.m_latestHudModel = nil
    self.m_lastFlowState = ""
    self.m_suppressedPointInfoHudSeat = 0
    self.m_isPlayerHeadInit = {}
    self:_ResetOptInfoNode()
    self:_SetSelectCardBindingGray(true)
    self:_ClearPointInfoDecisions()
    self:_ResetSeatTips()
end

CardGameLandlordHudCtrl._BindHudMainFromScene = HL.Method() << function(self)
    local scene = LuaSystemManager.cardGameDoudizhuSystem.scene
    if not scene or not scene.hudMain then
        logger.error("CardGameLandlordHudCtrl._BindHudMainFromScene: hudMain not ready (must Init scene before panel)")
        return
    end
    self.m_scene = scene
    self.m_hudMainView = scene.hudMain
end

CardGameLandlordHudCtrl._SetHudMainActive = HL.Method(HL.Boolean) << function(self, active)
    self.m_hudMainView.gameObject:SetActive(active)
end

CardGameLandlordHudCtrl._InitUI = HL.Method() << function(self)
    self.view.randomSeatNode:InitCardGameRandomSeatNode(HUD_SEAT_TO_RANDOM_SEAT_INDEX)
    
    self.m_actionToastNodeList = {}
    local actionToast = self.view.actionToast
    table.insert(self.m_actionToastNodeList, actionToast.landlordToast)
    table.insert(self.m_actionToastNodeList, actionToast.normalToast)
    table.insert(self.m_actionToastNodeList, actionToast.bombToast)
    table.insert(self.m_actionToastNodeList, actionToast.kingBombToast)
    
    for i, toastNode in pairs(self.m_actionToastNodeList) do
        toastNode.gameObject:SetActive(false)
    end
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
        self.view.inputGroup.groupId,
        self.m_hudMainView.inputGroup.groupId,
    }, nil, function(infoList)
        self:_FilterControllerHints(infoList)
    end)
    self.view.titleNode.exitBtn.onClick:AddListener(function()
        self:_ShowLeaveRoomPopUp({
            content = Language.LUA_MULTIPLAYER_PLAY_ROOM_LEAVE_CONFIRM,
        })
    end)
    self.view.titleNode.helpBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, "intro_doudizhu")
    end)
    self:_InitCardTypeList()
    self.view.quickMenuHintNode:InitCardGameQuickMenuHintNode({
        getOpenArg = function()
            self.m_cardTypeListWidget:Hide()
            self:HideEmojiPopup()
            if not self.m_hudAttached then
                return nil
            end
            return self:_BuildQuickMenuArg()
        end,
    })
    local optInfoNode = self.view.optInfoNode
    optInfoNode.continueBtn.onClick:AddListener(function()
        self:_OnClickContinue()
    end)
    optInfoNode.stopBtn.onClick:AddListener(function()
        self:_OnClickStop()
    end)
    optInfoNode.reminderBtn.onClick:AddListener(function()
        self:_OnClickReminder()
    end)

    local playerInfoNode = self.view.playerInfoNode
    self.m_playerInfoNodes = {
        playerInfoNode.playerInfo_Self,
        playerInfoNode.playerInfo_Left,
        playerInfoNode.playerInfo_Right,
    }
    self.m_isPlayerHeadInit = {}
    for hudSeat = 1, 3 do
        local targetHudSeat = hudSeat
        local playerInfo = self.m_playerInfoNodes[hudSeat]
        playerInfo.button.onClick:AddListener(function()
            LuaSystemManager.cardGameDoudizhuSystem:OpenPlayerGameInfoByHudSeat(targetHudSeat)
        end)
    end
    playerInfoNode.gameObject:SetActive(false)
    self:_InitSeatTips()
    local tableInfoNode = self.m_hudMainView.tableInfoNode
    self.m_pointInfoNodes = {
        tableInfoNode.pointInfoState_Self,
        tableInfoNode.pointInfoState_Left,
        tableInfoNode.pointInfoState_Right,
    }
    self:_InitEmoji()
    self.m_selectedCardInstIdSet = {}
    self.m_pendingSelectedCardInstIds = {}
    self.m_selfHandCardInstIds = {}
    self.m_bottomHandoffStates = {}
    self.m_selfHandInteractionCellsByUid = {}
    self.m_cardInteractionStateInstIds = {}
    self.m_selfHandInteractionSyncCoroutine = nil
    self:_ResetCardDragSelection()
    self.m_focusClearTimer = -1
    self.m_focusEpoch = 0
    self.m_cardNaviFocused = false
    self.m_landlordCardWidgets = {}
    self.m_pointInfoDecisions = {}
    self.m_suppressedPointInfoHudSeat = 0
    self.m_lastFlowState = ""
    self:_InitDeadlineCountdown()
    self:_InitGameplayToasts()
    self:_InitCardViews()
end

CardGameLandlordHudCtrl._InitCardTypeList = HL.Method() << function(self)
    local prefab = self:LoadGameObject(CARD_TYPE_LIST_WIDGET_PATH)
    local widgetGo = CSUtils.CreateObject(prefab, self.view.cardTypeListRoot)
    widgetGo.name = "CardTypeListNode"
    widgetGo.transform.localScale = Vector3.one
    widgetGo.transform.anchoredPosition = Vector2.zero
    self.m_cardTypeListWidget = Utils.wrapLuaNode(widgetGo)
    self.m_cardTypeListWidget:InitCardTypeListNode(self.view.cardTypeListBtn, function(active)
        if active then
            self:_CloseQuickMenu()
            self:HideEmojiPopup()
        end
        
        self:_SetSelfHandInteractionSuppressed(active)
        self.view.controllerHintPlaceholder.gameObject:SetActiveIfNecessary(not active)
    end)
end


CardGameLandlordHudCtrl.IsCardTypeListShown = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_cardTypeListWidget ~= nil and self.m_cardTypeListWidget.gameObject.activeSelf
end

CardGameLandlordHudCtrl.ShowCardTypeList = HL.Method() << function(self)
    self.m_cardTypeListWidget:Show()
end

CardGameLandlordHudCtrl._ShowLeaveRoomPopUp = HL.Method(HL.Table) << function(self, popUpArg)
    
    popUpArg.onConfirm = function()
        self:_OnConfirmLeaveRoom()
    end
    self:Notify(MessageConst.SHOW_POP_UP, popUpArg)
end

CardGameLandlordHudCtrl._OnConfirmLeaveRoom = HL.Method() << function(self)
    LuaSystemManager.cardGameDoudizhuSystem:RequestLeaveRoom()
end


CardGameLandlordHudCtrl.GetLeaveRoomPopUpRecoverArg = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local isOpen, commonPopUpCtrl = UIManager:IsOpen(PanelId.CommonPopUp)
    if not isOpen or not commonPopUpCtrl:IsShow() then
        return nil
    end
    local popUpArg = commonPopUpCtrl:GetCurPhaseStateArg()
    if popUpArg == nil or popUpArg.content ~= Language.LUA_MULTIPLAYER_PLAY_ROOM_LEAVE_CONFIRM then
        return nil
    end
    return popUpArg
end

CardGameLandlordHudCtrl.RecoverLeaveRoomPopUp = HL.Method(HL.Table) << function(self, popUpArg)
    if UIManager:IsShow(PanelId.CommonPopUp) then
        return
    end
    self:_ShowLeaveRoomPopUp(popUpArg)
end


CardGameLandlordHudCtrl._BuildQuickMenuArg = HL.Method().Return(HL.Table) << function(self)
    local modelSeats = self.m_latestHudModel and self.m_latestHudModel.seats or {}
    local seats = {}
    for direction = 1, 4 do
        local hudSeat = QUICK_MENU_DIRECTION_TO_HUD_SEAT[direction]
        local seat = hudSeat and modelSeats[hudSeat]
        local displayInfo = seat and seat.displayInfo
        seats[direction] = { isEmpty = displayInfo == nil, playerInfo = displayInfo }
    end
    return {
        seats = seats,
        onConfirm = function(direction)
            LuaSystemManager.cardGameDoudizhuSystem:OpenPlayerGameInfoByHudSeat(QUICK_MENU_DIRECTION_TO_HUD_SEAT[direction])
        end,
    }
end

CardGameLandlordHudCtrl._CloseQuickMenu = HL.Method() << function(self)
    self.view.quickMenuHintNode:CloseQuickMenu()
end









CardGameLandlordHudCtrl._InitCardInput = HL.Method() << function(self)
    self.m_selectCardBindingId = self:BindInputPlayerAction(SELECT_CARD_ACTION_ID, function()
        self:_OnSelectCardActionPressed()
    end)
    self:BindInputPlayerAction(SELECT_CARD_RELEASE_ACTION_ID, function()
        self:_OnSelectCardActionReleased()
    end)
    self:_SetSelectCardBindingGray(true)
end


CardGameLandlordHudCtrl._FilterControllerHints = HL.Method(HL.Table) << function(self, infoList)
    local model = self.m_latestHudModel
    local hideAll = model == nil or model.hideControllerHints == true
    local selfSeat = model and model.seats[1]
    local handCards = selfSeat and selfSeat.handCardsInstIds
    local hasHandCards = handCards ~= nil and #handCards > 0
    for index = #infoList, 1, -1 do
        local actionId = infoList[index].actionId
        local isSelectCard = actionId == SELECT_CARD_ACTION_ID or actionId == SELECT_CARD_RELEASE_ACTION_ID
        if hideAll or isSelectCard and not hasHandCards then
            table.remove(infoList, index)
        end
    end
end

CardGameLandlordHudCtrl._SetSelectCardBindingGray = HL.Method(HL.Boolean) << function(self, gray)
    if self.m_selectCardBindingId ~= nil and self.m_selectCardBindingId > 0 then
        InputManagerInst:ForceBindingKeyhintToGray(self.m_selectCardBindingId, gray)
    end
end


CardGameLandlordHudCtrl._IsCardSelectionInputAvailable = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_hudAttached and self.m_cardSelectionEnabled
            and not self.m_selfHandInteractionSuppressed 
            and InputManagerInst:IsGroupEnabled(self.view.inputGroup.groupId)
end

CardGameLandlordHudCtrl._OnSelectCardActionPressed = HL.Method() << function(self)
    if not DeviceInfo.usingController or not self:_IsCardSelectionInputAvailable() or self.m_focusedCardInstId == 0 then
        return
    end
    if self.m_dragSelectionActive then
        self:_ResetCardDragSelection()
    end
    if self:_BeginCardRangeSelection(
            self.m_focusedCardInstId, CARD_RANGE_SELECTION_MODE.Controller) then
        AudioAdapter.PostEvent("Au_UI_Button_CardChoose")
    end
end

CardGameLandlordHudCtrl._OnSelectCardActionReleased = HL.Method() << function(self)
    if self.m_cardRangeSelectionMode == CARD_RANGE_SELECTION_MODE.Controller then
        if DeviceInfo.usingController and self:_IsCardSelectionInputAvailable() then
            self:_CommitCardRangeSelection()
        end
        self:_ResetCardDragSelection()
    end
end


CardGameLandlordHudCtrl._RegisterTouchpadCardSelection = HL.Method() << function(self)
    if self.m_touchpadInputRegistered then
        return
    end
    if self.m_onStartSwipeTouchPanel == nil then
        self.m_onStartSwipeTouchPanel = function(pos) 
            self:_OnStartTouchpadCardSelection(pos)
        end
        self.m_onSwipeTouchPanel = function(delta, pos) 
            self:_OnSwipeTouchpadCardSelection(delta, pos)
        end
        self.m_onEndSwipeTouchPanel = function() 
            self:_OnEndTouchpadCardSelection()
        end
    end
    InputManagerInst.onStartSwipeTouchPanel:Add(self.m_onStartSwipeTouchPanel)
    InputManagerInst.onSwipeTouchPanel:Add(self.m_onSwipeTouchPanel)
    InputManagerInst.onEndSwipeTouchPanel:Add(self.m_onEndSwipeTouchPanel)
    self.m_touchpadInputRegistered = true
end

CardGameLandlordHudCtrl._UnregisterTouchpadCardSelection = HL.Method() << function(self)
    if not self.m_touchpadInputRegistered then
        return
    end
    InputManagerInst.onStartSwipeTouchPanel:Remove(self.m_onStartSwipeTouchPanel)
    InputManagerInst.onSwipeTouchPanel:Remove(self.m_onSwipeTouchPanel)
    InputManagerInst.onEndSwipeTouchPanel:Remove(self.m_onEndSwipeTouchPanel)
    self.m_touchpadInputRegistered = false
    self:_ResetTouchpadCardSelection()
end

CardGameLandlordHudCtrl._ResetTouchpadCardSelection = HL.Method() << function(self)
    if self.m_cardRangeSelectionMode == CARD_RANGE_SELECTION_MODE.Touchpad then
        self:_ResetCardDragSelection()
    end
    self.m_touchpadSwipeStartPos = nil
    self.m_touchpadSwipeAccumulatedX = 0
    self.m_touchpadSwipeStarted = false
    self.m_touchpadSwipeAnchorInstId = 0
end

CardGameLandlordHudCtrl._OnStartTouchpadCardSelection = HL.Method(Vector2) << function(self, pos)
    self:_ResetTouchpadCardSelection()
    if not DeviceInfo.usingController or not self:_IsCardSelectionInputAvailable()
            or self.m_focusedCardInstId == 0 then
        return
    end
    self.m_touchpadSwipeStartPos = pos
    self.m_touchpadSwipeAnchorInstId = self.m_focusedCardInstId
end

CardGameLandlordHudCtrl._OnSwipeTouchpadCardSelection = HL.Method(Vector2, Vector2)  << function(self, delta, pos)
    if self.m_touchpadSwipeStartPos == nil then
        return
    end
    if not DeviceInfo.usingController or not self:_IsCardSelectionInputAvailable() then
        self:_ResetTouchpadCardSelection()
        return
    end
    if not self.m_touchpadSwipeStarted then
        local totalDeltaX = pos.x - self.m_touchpadSwipeStartPos.x
        local totalDeltaY = pos.y - self.m_touchpadSwipeStartPos.y
        if math.abs(totalDeltaX) < SELF_HAND_CONFIG.TouchpadSwipeStartThreshold
                or math.abs(totalDeltaX) <= math.abs(totalDeltaY) then
            return
        end
        if not self:_BeginCardRangeSelection(
                self.m_touchpadSwipeAnchorInstId, CARD_RANGE_SELECTION_MODE.Touchpad) then
            self:_ResetTouchpadCardSelection()
            return
        end
        AudioAdapter.PostEvent("Au_UI_Button_CardChoose")
        self.m_touchpadSwipeStarted = true
        self.m_touchpadSwipeAccumulatedX = totalDeltaX
    else
        self.m_touchpadSwipeAccumulatedX = self.m_touchpadSwipeAccumulatedX + delta.x
    end
    local stepThreshold = SELF_HAND_CONFIG.TouchpadSwipeStepThreshold
    while math.abs(self.m_touchpadSwipeAccumulatedX) >= stepThreshold do
        local direction = self.m_touchpadSwipeAccumulatedX > 0 and 1 or -1
        if not self:_MoveFocusedCard(direction) then
            
            self.m_touchpadSwipeAccumulatedX = 0
            break
        end
        self.m_touchpadSwipeAccumulatedX = self.m_touchpadSwipeAccumulatedX - direction * stepThreshold
    end
end

CardGameLandlordHudCtrl._OnEndTouchpadCardSelection = HL.Method() << function(self)
    if self.m_cardRangeSelectionMode == CARD_RANGE_SELECTION_MODE.Touchpad then
        if DeviceInfo.usingController and self:_IsCardSelectionInputAvailable() then
            self:_CommitCardRangeSelection()
        end
    end
    self:_ResetTouchpadCardSelection()
end


CardGameLandlordHudCtrl._InitGameplayToasts = HL.Method() << function(self)
    self.m_lastProgressToastEventId = nil
    self.m_lastProjectedEventId = nil
    self.m_stateToastTimer = -1
    self.m_stateToastEpoch = 0
    self.m_actionToastTimer = -1
    self.m_actionToastEpoch = 0
    self:_ClearStateToast()
    self:_SetCantAffordToastShown(false, true)
    self:_ClearActionToast()
end



CardGameLandlordHudCtrl.PlayProgressToast = HL.Method(HL.Table) << function(self, command)
    if command.localEventId ~= nil and command.localEventId == self.m_lastProgressToastEventId then
        return
    end
    self.m_lastProgressToastEventId = command.localEventId
    
    self:_ClearActionToast()
    if command.kind == HUD_COMMAND_KIND.Deal then
        self:_ClearStateToast()
        if command.isRedeal == true then
            self:_ShowStateToast(UI_STATE.ExplainToast.Reset, false,
                    Tables.LandLoardConst.redealPresentationMs / 1000)
        end
    elseif command.kind == HUD_COMMAND_KIND.TurnChanged
            and command.presentationType == PresentationType.BidTurn then
        if command.startsNewRound == true then
            local condition = CS.Beyond.Gameplay.Conditions.OnCardGameDoudizhuPhaseEventForGuide
            local function triggerPromptEnd()
                condition.Trigger(command.bidRound, command.hudSeat, condition.DoudizhuPhaseEventTypeForGuide.BidRoundPromptEnd)
            end
            
            local stateName
            if command.isFirstBidTurnAfterRedeal == true then
                stateName = UI_STATE.ExplainToast.AgainLandlord
            elseif command.bidRound == 1 then
                stateName = UI_STATE.ExplainToast.Landlord
            end
            if stateName ~= nil then
                self:_ShowStateToast(stateName, false, Tables.LandLoardConst.bidResultPresentationMs / 1000, triggerPromptEnd)
            else
                triggerPromptEnd()
            end
        end
    elseif command.presentationType == PresentationType.PlayTurn and command.startsPlaying == true then
        self:_ShowStartStateToast(Tables.LandLoardConst.playPresentationMs / 1000)
    elseif command.kind == HUD_COMMAND_KIND.BottomRevealed then
        self:_PlayLandlordResultToast(command, Tables.LandLoardConst.landlordPresentationMs / 1000)
    elseif command.kind == HUD_COMMAND_KIND.PlayCards then
        
        self:_PlayPatternActionToast(command)
    end
end

CardGameLandlordHudCtrl._ClearPointInfoDecisions = HL.Method() << function(self)
    self.m_pointInfoDecisions = {}
end

CardGameLandlordHudCtrl._PreparePointInfoTurn = HL.Method(HL.Number) << function(self, hudSeat)
    if hudSeat <= 0 then
        return
    end
    self.m_pointInfoDecisions[hudSeat] = nil
end

CardGameLandlordHudCtrl._RecordPointInfoDecision = HL.Method(HL.Number, HL.String)
        << function(self, hudSeat, decision)
    if hudSeat <= 0 then
        return
    end
    self.m_pointInfoDecisions[hudSeat] = decision
end


CardGameLandlordHudCtrl.GetPointInfoRecoverState = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if next(self.m_pointInfoDecisions) == nil and self.m_suppressedPointInfoHudSeat == 0 then
        return nil
    end
    return {
        windowSeqId = self.m_latestHudModel and self.m_latestHudModel.windowSeqId or nil,
        decisions = lume.clone(self.m_pointInfoDecisions),
        suppressedHudSeat = self.m_suppressedPointInfoHudSeat,
    }
end

CardGameLandlordHudCtrl.RestorePointInfoState = HL.Method(HL.Table) << function(self, state)
    local model = self.m_latestHudModel
    
    if model == nil or model.windowSeqId ~= state.windowSeqId then
        return
    end
    self.m_pointInfoDecisions = lume.clone(state.decisions or {})
    self.m_suppressedPointInfoHudSeat = state.suppressedHudSeat or 0
    self:_RefreshTurnStates(model)
end


CardGameLandlordHudCtrl._UpdatePointInfoState = HL.Method(HL.Table) << function(self, command)
    if command.kind == HUD_COMMAND_KIND.Deal or command.kind == HUD_COMMAND_KIND.Settlement then
        self.m_suppressedPointInfoHudSeat = 0
        self:_ClearPointInfoDecisions()
    elseif command.kind == HUD_COMMAND_KIND.BottomRevealed then
        self.m_suppressedPointInfoHudSeat = command.landlordHudSeat
    elseif command.presentationType == PresentationType.BidTurn
            or command.presentationType == PresentationType.PlayTurn then
        self.m_suppressedPointInfoHudSeat = 0
        
        if command.startsNewRound and command.presentationType == PresentationType.PlayTurn then
            self:_ClearPointInfoDecisions()
        end
        self:_PreparePointInfoTurn(command.hudSeat)
    elseif command.kind == HUD_COMMAND_KIND.BidResult then
        
        local hasPriorPositiveBid = command.hasPriorPositiveBidInRound == true
                or (command.bidRound ~= nil and command.bidRound > 1)
        local decision = command.action == 1
                and (hasPriorPositiveBid and POINT_INFO_DECISION.BidRob or POINT_INFO_DECISION.BidCall)
                or (hasPriorPositiveBid and POINT_INFO_DECISION.BidNoRob or POINT_INFO_DECISION.BidNoCall)
        self:_RecordPointInfoDecision(command.hudSeat, decision)
    elseif command.kind == HUD_COMMAND_KIND.PlayCards then
        self:_RecordPointInfoDecision(command.hudSeat, POINT_INFO_DECISION.PlayCards)
    elseif command.kind == HUD_COMMAND_KIND.Pass then
        self:_RecordPointInfoDecision(command.hudSeat, POINT_INFO_DECISION.PlayPass)
    end
end


CardGameLandlordHudCtrl._TryPlayPointInfoBubbleAudio = HL.Method(HL.Table, HL.Table) << function(self, model, command)
    if command.kind ~= HUD_COMMAND_KIND.BidResult and command.kind ~= HUD_COMMAND_KIND.Pass then
        return
    end
    local hudSeat = command.hudSeat
    if hudSeat == nil or hudSeat <= 0 or hudSeat == self.m_suppressedPointInfoHudSeat
            or model.headlessPresentation or model.isRecovering then
        return
    end
    if command.localEventId <= self.m_lastBubbleLocalEventId then
        return
    end
    self.m_lastBubbleLocalEventId = command.localEventId
    AudioAdapter.PostEvent(hudSeat == SELF_HUD_SEAT
            and "Au_UI_Popup_SNSDialogContent_MyselfNode_Open"
            or "Au_UI_Popup_SNSDialogContent_OtherNode_Open")
end


CardGameLandlordHudCtrl._ShowStateToast = HL.Method(HL.String, HL.Boolean, HL.Number, HL.Opt(HL.Function)) << function(self, stateName, isVictory, durationSeconds, onDone)
    self:_ClearStateToast()
    local stateToast = self.view.stateToast
    local activeController = isVictory and stateToast.victoryStateLayout
            or stateToast.explainStateLayout
    local inactiveController = isVictory and stateToast.explainStateLayout
            or stateToast.victoryStateLayout
    stateToast.startStateLayout.gameObject:SetActive(false)
    inactiveController.gameObject:SetActive(false)
    activeController.gameObject:SetActive(true)
    activeController:SetState(stateName)
    AudioAdapter.PostEvent(isVictory and "Au_UI_Toast_CardVictoryBanner" or "Au_UI_Toast_CardRoundBanner")
    self:_ScheduleStateToastHide(durationSeconds, onDone)
end

CardGameLandlordHudCtrl._ShowStartStateToast = HL.Method(HL.Number) << function(self, durationSeconds)
    self:_ClearStateToast()
    local stateToast = self.view.stateToast
    stateToast.victoryStateLayout.gameObject:SetActive(false)
    stateToast.explainStateLayout.gameObject:SetActive(false)
    stateToast.startStateLayout.gameObject:SetActive(true)
    AudioAdapter.PostEvent("Au_UI_Toast_CardRoundBanner")
    self:_ScheduleStateToastHide(durationSeconds)
end

CardGameLandlordHudCtrl._ScheduleStateToastHide = HL.Method(HL.Number, HL.Opt(HL.Function)) << function(self, durationSeconds, onDone)
    local stateToast = self.view.stateToast
    stateToast.gameObject:SetActive(true)
    if durationSeconds <= 0 then
        return
    end

    local epoch = self.m_stateToastEpoch
    self.m_stateToastTimer = self:_StartTimer(durationSeconds, function()
        if epoch ~= self.m_stateToastEpoch then
            return
        end
        self.m_stateToastTimer = -1
        stateToast.gameObject:SetActive(false)
        if onDone then
            onDone()
        end
    end, true)
end

CardGameLandlordHudCtrl._ClearStateToast = HL.Method() << function(self)
    self.m_stateToastEpoch = self.m_stateToastEpoch + 1
    if self.m_stateToastTimer >= 0 then
        self.m_stateToastTimer = self:_ClearTimer(self.m_stateToastTimer)
    end
    local stateToast = self.view.stateToast
    stateToast.startStateLayout.gameObject:SetActive(false)
    stateToast.gameObject:SetActive(false)
end

CardGameLandlordHudCtrl._ShowActionToast = HL.Method(HL.Any, HL.Number)
        << function(self, toastNode, durationSeconds)
    self:_ClearActionToast()
    toastNode.gameObject:SetActive(true)
    toastNode.animationWrapper:PlayInAnimation()
    local epoch = self.m_actionToastEpoch
    self.m_actionToastTimer = self:_StartTimer(durationSeconds, function()
        if epoch ~= self.m_actionToastEpoch then
            return
        end
        self.m_actionToastTimer = -1
        toastNode.animationWrapper:PlayOutAnimation(function()
            self:_ClearActionToast()
        end)
    end, true)
end

CardGameLandlordHudCtrl._ClearActionToast = HL.Method() << function(self)
    self.m_actionToastEpoch = self.m_actionToastEpoch + 1
    if self.m_actionToastTimer >= 0 then
        self.m_actionToastTimer = self:_ClearTimer(self.m_actionToastTimer)
    end
    for i, toastNode in pairs(self.m_actionToastNodeList) do
        toastNode.gameObject:SetActive(false)
        toastNode.animationWrapper:ClearTween(false)
    end
end

CardGameLandlordHudCtrl._SetCantAffordToastShown = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, shown, skipAni)
    local preIsShown = self.view.cantAffordToast.gameObject.activeSelf
    if preIsShown == shown then
        return
    end
    
    if skipAni then
        self.view.cantAffordToast.gameObject:SetActive(shown)
        return
    end
    
    if shown then
        self.view.cantAffordToast.gameObject:SetActive(true)
        self.view.cantAffordToast.animationWrapper:PlayInAnimation()
    else
        self.view.cantAffordToast.animationWrapper:PlayOutAnimation(function()
            self.view.cantAffordToast.gameObject:SetActive(false)
        end)
    end
end

CardGameLandlordHudCtrl._PlayPatternActionToast = HL.Method(HL.Table) << function(self, command)
    local actionToast = self.view.actionToast
    local toastNode = nil
    local durationSeconds = 0
    if command.pattern == CS.Proto.DDZ_PATTERN.PairStraight
            or command.pattern == CS.Proto.DDZ_PATTERN.Straight
            or command.pattern == CS.Proto.DDZ_PATTERN.Plane
            or command.pattern == CS.Proto.DDZ_PATTERN.PlaneSingle
            or command.pattern == CS.Proto.DDZ_PATTERN.PlanePair then
        toastNode = actionToast.normalToast
        durationSeconds = Tables.LandLoardConst.normalPresentationMs
        if command.pattern == CS.Proto.DDZ_PATTERN.PairStraight then
            toastNode.toastTxt.text = Language.LUA_CARD_GAME_DOUDIZHU_PAIR_STRAIGHT_TOAST
        elseif command.pattern == CS.Proto.DDZ_PATTERN.Straight then
            toastNode.toastTxt.text = Language.LUA_CARD_GAME_DOUDIZHU_STRAIGHT_TOAST
        else
            toastNode.toastTxt.text = Language.LUA_CARD_GAME_DOUDIZHU_PLANE_TOAST
        end
    elseif command.pattern == CS.Proto.DDZ_PATTERN.Bomb then
        toastNode = actionToast.bombToast
        durationSeconds = Tables.LandLoardConst.bombPresentationMs
    elseif command.pattern == CS.Proto.DDZ_PATTERN.Rocket then
        toastNode = actionToast.kingBombToast
        durationSeconds = Tables.LandLoardConst.rocketPresentationMs
    else
        return
    end
    self:_ShowActionToast(toastNode, durationSeconds / 1000)
end

CardGameLandlordHudCtrl._PlayLandlordResultToast = HL.Method(HL.Table, HL.Number) << function(self, command, durationSeconds)
    local landlordToast = self.view.actionToast.landlordToast
    local landlordSeat = command.viewModel.seats[command.landlordHudSeat]
    local playerName = CardGameUtils.GetPlayerDisplayName(landlordSeat.displayInfo, landlordSeat.nickname)
    landlordToast.toastTxt.text = string.format(
            Language.LUA_CARD_GAME_DOUDIZHU_LANDLORD_RESULT_TOAST, playerName)
    self:_ShowActionToast(landlordToast, durationSeconds)
end

CardGameLandlordHudCtrl._PlaySettlementToast = HL.Method(HL.Table) << function(self, command)
    local winnerCamp = command.finalSettleArg.winnerCamp
    if winnerCamp == CS.Proto.DDZ_CAMP.Landlord then
        self:_ShowStateToast(UI_STATE.VictoryToast.Landlord, true, -1)
    elseif winnerCamp == CS.Proto.DDZ_CAMP.Farmer then
        self:_ShowStateToast(UI_STATE.VictoryToast.Peasantry, true, -1)
    end
end


CardGameLandlordHudCtrl._InitEmoji = HL.Method() << function(self)
    local emojiNode = self.view.emojiNode
    emojiNode.emojiPopupBtn.button.onClick:AddListener(function()
        self:OnClickEmojiPopupBtn()
    end)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    emojiNode.emojiPopupNode:InitMultiplayerEmojiNode({
        roomStrId = system:GetEmojiRoomStrId(),
        onEmojiSent = function()
            self:HideEmojiPopup()
            system:StartEmojiCd()
        end,
        onActiveChanged = function(active)
            if not self.m_hudAttached then
                return
            end
            if active then
                self:_CloseQuickMenu()
                self.m_cardTypeListWidget:Hide()
            end
            self:_SetSelfHandInteractionSuppressed(active)
            self:_RefreshEmojiPopupBtnState(active, system:IsEmojiInCd())
        end
    })
    self:_ResetEmojiVisuals()
end

CardGameLandlordHudCtrl._ResetEmojiVisuals = HL.Method() << function(self)
    self:HideEmojiPopup()
    for hudSeat = 1, 3 do
        self.m_playerInfoNodes[hudSeat].emojiNode:Clear()
    end
end

CardGameLandlordHudCtrl.OnClickEmojiPopupBtn = HL.Method() << function(self)
    local emojiPopupNode = self.view.emojiNode.emojiPopupNode
    if emojiPopupNode.gameObject.activeSelf then
        self:HideEmojiPopup()
        return
    end
    if not LuaSystemManager.cardGameDoudizhuSystem:IsEmojiInCd() then
        self:ShowEmojiPopup()
    end
end

CardGameLandlordHudCtrl.ShowEmojiPopup = HL.Method() << function(self)
    self.view.emojiNode.emojiPopupNode:SetEmojiNodeActive(true)
end

CardGameLandlordHudCtrl.HideEmojiPopup = HL.Method() << function(self)
    self.view.emojiNode.emojiPopupNode:SetEmojiNodeActive(false)
end

CardGameLandlordHudCtrl.SetEmojiCdState = HL.Method(HL.Boolean) << function(self, inCd)
    self:_RefreshEmojiPopupBtnState(self.view.emojiNode.emojiPopupNode.gameObject.activeSelf, inCd)
end

CardGameLandlordHudCtrl._RefreshEmojiPopupBtnState = HL.Method(HL.Boolean, HL.Boolean) << function(self, active, inCd)
    local emojiPopupBtn = self.view.emojiNode.emojiPopupBtn
    emojiPopupBtn.nodeState:SetState(active and "Click" or inCd and "Time" or "Normal")
    
    emojiPopupBtn.button.interactable = active or not inCd
end

CardGameLandlordHudCtrl.RefreshEmojiCd = HL.Method(HL.Number) << function(self, cdTime)
    self.view.emojiNode.emojiPopupBtn.numTxt.text =
            string.format("%ds", math.floor(cdTime))
end

CardGameLandlordHudCtrl.PlayEmojiBySeatIndex = HL.Method(HL.Number, HL.String, HL.Opt(HL.String))
        << function(self, hudSeat, emojiId, charId)
    local cell = self.m_playerInfoNodes[hudSeat]
    if not cell then
        return
    end
    cell.emojiNode:Init(emojiId)
    cell.emojiNode:Play(charId)
end


CardGameLandlordHudCtrl._InitCardViews = HL.Method() << function(self)
    self.m_landlordCardWidgets = {
        self.view.landlordCard1,
        self.view.landlordCard2,
        self.view.landlordCard3,
    }
    self.view.landlordCardNode.gameObject:SetActive(false)

    self:_BindSelfHand3DAnchor()
    self:_BindSelfHandInteractionList()
end

CardGameLandlordHudCtrl._BindSelfHand3DAnchor = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    local handRegion = cardSystem:GetRegion(SELF_HAND_CONFIG.RegionId)
    self.m_selfHand3DAligner = self.view.selfHand3DAligner
    self.m_selfHand3DAligner:BindExternalTarget(
            handRegion:GetRoot(), SELF_HAND_CONFIG.ReferenceLocalSize, true)
end


CardGameLandlordHudCtrl.OnSelfHandRegionRebound = HL.Method() << function(self)
    self:_BindSelfHand3DAnchor()
    self:_RefreshCardSelectionVisuals(false)
    self:_RefreshSelfHandInteraction()
    
    self:_RefreshSelfHandCardFocus(self.m_selfHandCardInstIds, self.m_focusedCardInstId, false)
end


CardGameLandlordHudCtrl._BindSelfHandInteractionList = HL.Method() << function(self)
    local interactionNode = self.view.selfHandInteractionNode
    self.m_selfHandInteractionNode = interactionNode.gameObject
    self.m_selfHandInteractionRoot = interactionNode.rectTransform
    self.m_selfHandInteractionCellCache = UIUtils.genCellCache(interactionNode.cellTemplate)
    self.m_selfHandInteractionNode:SetActive(false)
    
    self.view.guideHandRange.sizeDelta = Vector2.zero
    self.view.guideHandRange.gameObject:SetActive(false)
end



CardGameLandlordHudCtrl._SetSelfHandInteractionSuppressed = HL.Method(HL.Boolean) << function(self, suppressed)
    if self.m_selfHandInteractionSuppressed == suppressed then
        return
    end
    self.m_selfHandInteractionSuppressed = suppressed
    
    if suppressed then
        
        local currentTarget = InputManagerInst.controllerNaviManager.curTarget
        self.m_suppressedHandNaviTarget = nil
        if DeviceInfo.usingController and self.m_cardNaviFocused then
            for _, entry in pairs(self.m_selfHandInteractionCellsByUid) do
                if entry.button == currentTarget then
                    self.m_suppressedHandNaviTarget = currentTarget
                    break
                end
            end
        end
        
        self:_ResetTouchpadCardSelection()
        if self.m_dragSelectionActive then
            self:_ResetCardDragSelection()
        end
        
        self:_HideSelfHandCardFocus()
        
        self:_RefreshSelfHandInteraction()
        return
    end
    
    
    self.m_resetCardFocusToFirst = true
    self:_RefreshSelfHandInteraction()
    if #self.m_selfHandCardInstIds > 0 then
        self:_EnsureSelfHandInteractionSyncCoroutine()
    end
end




CardGameLandlordHudCtrl._TryRestoreSelfHandCardFocus = HL.Method() << function(self)
    local suppressedNaviTarget = self.m_suppressedHandNaviTarget
    if suppressedNaviTarget == nil or self.m_selfHandInteractionSuppressed then
        return
    end
    if not DeviceInfo.usingController or #self.m_selfHandCardInstIds == 0 then
        self.m_suppressedHandNaviTarget = nil
        return
    end
    if not self:_IsCardSelectionInputAvailable() then
        return
    end

    local currentTarget = InputManagerInst.controllerNaviManager.curTarget
    local targetInstId = 0
    for instId, entry in pairs(self.m_selfHandInteractionCellsByUid) do
        if entry.button == currentTarget and entry.button.interactable then
            targetInstId = instId
            break
        end
    end
    if targetInstId == 0 then
        if currentTarget ~= nil and currentTarget ~= suppressedNaviTarget then
            
            self.m_suppressedHandNaviTarget = nil
            return
        end
        targetInstId = self.m_selfHandCardInstIds[1]
    end
    if self:_SetSelfHandCardNaviTarget(targetInstId) then
        self.m_suppressedHandNaviTarget = nil
        self.m_resetCardFocusToFirst = false
    end
end

CardGameLandlordHudCtrl._BindSelfHandInteractionCell = HL.Method(HL.Table, HL.Number)
        << function(self, cell, index)
    local instId = self.m_selfHandCardInstIds[index]
    local button = cell.button
    local rectTransform = cell.rectTransform

    cell.gameObject.name = string.format(GUIDE_HAND_CELL_NAME_FORMAT, SELF_HUD_SEAT, index)
    button.onClick:RemoveAllListeners()
    button.onLongPress:RemoveAllListeners()
    
    
    
    
    button.onPressStart:RemoveAllListeners()
    button.onPressStart:AddListener(function(eventData)
        self:_BeginCardPointerSelection(button, eventData)
    end)
    button.onPressEnd:RemoveAllListeners()
    button.onPressEnd:AddListener(function(eventData)
        self:_EndCardPointerSelection(eventData)
    end)
    button:ChangeActionOnSetNaviTarget(CS.Beyond.Input.ActionOnSetNaviTarget.None)
    button.hideNaviHint = true
    button.customNaviTargetInDirFunc = function(dir)
        return self:_GetSelfHandCardNaviTarget(instId, dir)
    end
    button.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            self.m_cardNaviFocused = true
            self:_CancelFocusedCardClear()
            self:SetFocusedCardInstId(instId)
            self:_UpdateCardRangeSelectionFromFocus(instId)
        elseif self.m_focusedCardInstId == instId then
            self.m_cardNaviFocused = false
            
            self:_ScheduleFocusedCardClear(instId)
        end
    end
    
    rectTransform:SetAsLastSibling()
    self.m_selfHandInteractionCellsByUid[instId] = {
        cell = cell,
        rectTransform = rectTransform,
        button = button,
        projectedRect = CS.Beyond.UI.WorldGoProjectedUIRect(),
    }
    cell.projectedRect = self.m_selfHandInteractionCellsByUid[instId].projectedRect
end


CardGameLandlordHudCtrl._UnbindSelfHandInteractionCell = HL.Method(HL.Table) << function(self, cell)
    local button = cell.button
    button.onClick:RemoveAllListeners()
    button.onLongPress:RemoveAllListeners()
    button.onPressStart:RemoveAllListeners()
    button.onPressEnd:RemoveAllListeners()
    button.onIsNaviTargetChanged = nil
    button.customNaviTargetInDirFunc = nil
end


CardGameLandlordHudCtrl._RefreshSelfHandInteractionList = HL.Method() << function(self)
    local cardCount = #self.m_selfHandCardInstIds
    self.m_selfHandInteractionCellsByUid = {}
    self.m_selfHandInteractionCellCache:Refresh(cardCount, function(cell, index)
        self:_BindSelfHandInteractionCell(cell, index)
    end, false, function(cell)
        self:_UnbindSelfHandInteractionCell(cell)
    end)
    self:_RefreshSelfHandInteraction()
    if cardCount > 0 then
        self:_EnsureSelfHandInteractionSyncCoroutine()
    else
        self.m_selfHandInteractionSyncCoroutine = CoroutineManager:ClearCoroutine(
                self.m_selfHandInteractionSyncCoroutine)
    end
end


CardGameLandlordHudCtrl._FindSelfHandCardIndex = HL.Method(HL.Number).Return(HL.Number) << function(self, instId)
    for index, handInstId in ipairs(self.m_selfHandCardInstIds) do
        if handInstId == instId then
            return index
        end
    end
    return 0
end

CardGameLandlordHudCtrl._SetSelfHandCardNaviTarget = HL.Method(HL.Number).Return(HL.Boolean)  << function(self, instId)
    local entry = self.m_selfHandInteractionCellsByUid[instId]
    if entry == nil or not entry.button.interactable then
        return false
    end
    self:SetNaviTarget(entry.button)
    if not entry.button.isNaviTarget then
        return false
    end
    
    
    if self.m_focusedCardInstId ~= instId then
        self.m_cardNaviFocused = true
        self:_CancelFocusedCardClear()
        self:SetFocusedCardInstId(instId)
        self:_UpdateCardRangeSelectionFromFocus(instId)
    end
    return true
end

CardGameLandlordHudCtrl._GetSelfHandCardNaviTarget = HL.Method(HL.Number, HL.Any).Return(HL.Any) << function(self, instId, dir)
    local cardCount = #self.m_selfHandCardInstIds
    local currentIndex = self:_FindSelfHandCardIndex(instId)
    local currentEntry = self.m_selfHandInteractionCellsByUid[instId]
    if cardCount <= 0 or currentIndex <= 0 or currentEntry == nil then
        return nil
    end
    local targetIndex = currentIndex
    if dir == CS.UnityEngine.UI.NaviDirection.Left then
        targetIndex = currentIndex > 1 and currentIndex - 1 or cardCount
    elseif dir == CS.UnityEngine.UI.NaviDirection.Right then
        targetIndex = currentIndex < cardCount and currentIndex + 1 or 1
    end
    
    local targetInstId = self.m_selfHandCardInstIds[targetIndex]
    local targetEntry = self.m_selfHandInteractionCellsByUid[targetInstId]
    return targetEntry ~= nil and targetEntry.button or currentEntry.button
end

CardGameLandlordHudCtrl._MoveFocusedCard = HL.Method(HL.Number).Return(HL.Boolean) << function(self, direction)
       local cardCount = #self.m_selfHandCardInstIds
       local currentIndex = self:_FindSelfHandCardIndex(self.m_focusedCardInstId)
       if cardCount <= 0 or currentIndex <= 0 or direction == 0 then
           return false
       end
       
       local targetIndex = currentIndex + direction
       if targetIndex < 1 or targetIndex > cardCount then
           return false
       end
       return self:_SetSelfHandCardNaviTarget(self.m_selfHandCardInstIds[targetIndex])
   end










CardGameLandlordHudCtrl._RefreshSelfHandInteraction = HL.Method() << function(self)
    self.m_selfHandInteractionNode:SetActiveIfNecessary(
            #self.m_selfHandCardInstIds > 0 and not self.m_selfHandInteractionSuppressed)
    local cardSystem = LuaSystemManager.cardGameSystem

    for index, instId in ipairs(self.m_selfHandCardInstIds) do
        local entry = self.m_selfHandInteractionCellsByUid[instId]
        local card = cardSystem:GetRuntimeCard(instId)
        local cell = entry.cell
        local button = entry.button
        local rectTransform = entry.rectTransform
        local projectedRect = entry.projectedRect
        local hasProjection = card ~= nil and NotNull(card.transform)
                and CS.Beyond.UI.WorldGoAlignedUI.TryUpdateExternalProjectedUIRect(
                        card.transform, self.m_selfHandInteractionRoot, projectedRect)
        local interactable = hasProjection and self.m_cardSelectionEnabled
                and not self.m_selfHandInteractionSuppressed
        if button.interactable ~= interactable then
            button.interactable = interactable
        end
        if cell.gameObject.activeSelf ~= hasProjection then
            cell.gameObject:SetActive(hasProjection)
        end
        if hasProjection then
            local oldLocalPosition = rectTransform.localPosition
            if math.abs(oldLocalPosition.x - projectedRect.localCenter.x)
                            > SELF_HAND_CONFIG.InteractionRectEpsilon
                    or math.abs(oldLocalPosition.y - projectedRect.localCenter.y)
                            > SELF_HAND_CONFIG.InteractionRectEpsilon then
                rectTransform.localPosition = Vector3(projectedRect.localCenter.x,
                        projectedRect.localCenter.y, oldLocalPosition.z)
            end
            local oldRect = rectTransform.rect
            if math.abs(oldRect.width - projectedRect.size.x)
                    > SELF_HAND_CONFIG.InteractionRectEpsilon then
                rectTransform:SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal,
                        projectedRect.size.x)
            end
            if math.abs(oldRect.height - projectedRect.size.y)
                    > SELF_HAND_CONFIG.InteractionRectEpsilon then
                rectTransform:SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,
                        projectedRect.size.y)
            end
        end
    end
    self:_RefreshGuideHandRange()
    
    self:_TryRestoreSelfHandCardFocus()
end



CardGameLandlordHudCtrl._RefreshGuideHandRange = HL.Method() << function(self)
    local rangeTrans = self.view.guideHandRange
    if not rangeTrans.gameObject.activeSelf then
        return
    end
    local xMin, yMin, xMax, yMax
    if self.m_guideHandRangeFrom > 0 then
        local toIndex = math.min(self.m_guideHandRangeTo, #self.m_selfHandCardInstIds)
        for index = self.m_guideHandRangeFrom, toIndex do
            local entry = self.m_selfHandInteractionCellsByUid[self.m_selfHandCardInstIds[index]]
            if entry ~= nil and entry.cell.gameObject.activeSelf then
                local center = entry.projectedRect.localCenter
                local size = entry.projectedRect.size
                local halfWidth, halfHeight = size.x * 0.5, size.y * 0.5
                xMin = math.min(xMin or math.huge, center.x - halfWidth)
                yMin = math.min(yMin or math.huge, center.y - halfHeight)
                xMax = math.max(xMax or -math.huge, center.x + halfWidth)
                yMax = math.max(yMax or -math.huge, center.y + halfHeight)
            end
        end
        
        if xMin ~= nil then
            for index = toIndex + 1, #self.m_selfHandCardInstIds do
                local entry = self.m_selfHandInteractionCellsByUid[self.m_selfHandCardInstIds[index]]
                if entry ~= nil and entry.cell.gameObject.activeSelf then
                    local rect = entry.projectedRect
                    xMax = math.max(xMin, math.min(xMax, rect.localCenter.x - rect.size.x * 0.5))
                    break
                end
            end
        end
    end

    local width, height = 0, 0
    if xMin ~= nil then
        local root = self.m_selfHandInteractionRoot
        local parent = rangeTrans.parent
        local minPos = parent:InverseTransformPoint(root:TransformPoint(Vector3(xMin, yMin, 0)))
        local maxPos = parent:InverseTransformPoint(root:TransformPoint(Vector3(xMax, yMax, 0)))
        width, height = maxPos.x - minPos.x, maxPos.y - minPos.y
        rangeTrans.localPosition = Vector3((minPos.x + maxPos.x) * 0.5, (minPos.y + maxPos.y) * 0.5,
                rangeTrans.localPosition.z)
    end
    local oldSize = rangeTrans.sizeDelta
    if math.abs(oldSize.x - width) > SELF_HAND_CONFIG.InteractionRectEpsilon
            or math.abs(oldSize.y - height) > SELF_HAND_CONFIG.InteractionRectEpsilon then
        rangeTrans.sizeDelta = Vector2(width, height)
    end
end



CardGameLandlordHudCtrl.SetGuideHandRange = HL.Method(HL.Number, HL.Number, HL.Boolean)
        << function(self, fromIndex, toIndex, isShow)
    local rangeGo = self.view.guideHandRange.gameObject
    if not isShow then
        self.m_guideHandRangeFrom = 0
        self.m_guideHandRangeTo = 0
        rangeGo:SetActive(false)
        return
    end
    if fromIndex <= 0 or toIndex <= 0 then
        logger.error(string.format("[斗地主][引导] 框选区间无效：from=%d, to=%d", fromIndex, toIndex))
        fromIndex, toIndex = 0, 0
    elseif fromIndex > toIndex then
        fromIndex, toIndex = toIndex, fromIndex
    end
    if toIndex > #self.m_selfHandCardInstIds then
        logger.error(string.format("[斗地主][引导] 高亮区间超出手牌数：from=%d, to=%d, handCount=%d",
                fromIndex, toIndex, #self.m_selfHandCardInstIds))
    end
    self.m_guideHandRangeFrom = fromIndex
    self.m_guideHandRangeTo = toIndex
    rangeGo:SetActive(true)
    self:_RefreshGuideHandRange()
end



CardGameLandlordHudCtrl.SetSelfHandCardsSelectedByGuide = HL.Method(HL.Table, HL.Boolean)
        << function(self, indices, isSelect)
    local selectedSet = {}
    for instId in pairs(self.m_selectedCardInstIdSet) do
        selectedSet[instId] = true
    end
    if #indices == 0 then
        for _, instId in ipairs(self.m_selfHandCardInstIds) do
            selectedSet[instId] = isSelect or nil
        end
    else
        for _, index in ipairs(indices) do
            local instId = self.m_selfHandCardInstIds[index]
            if instId == nil then
                logger.error(string.format("[斗地主][引导] 选牌下标超出手牌数：index=%s, handCount=%d",
                        tostring(index), #self.m_selfHandCardInstIds))
            else
                selectedSet[instId] = isSelect or nil
            end
        end
    end
    local selectedInstIds = {}
    for _, instId in ipairs(self.m_selfHandCardInstIds) do
        if selectedSet[instId] then
            selectedInstIds[#selectedInstIds + 1] = instId
        end
    end
    self:SetSelectedCardInstIds(selectedInstIds)
end


CardGameLandlordHudCtrl._EnsureSelfHandInteractionSyncCoroutine = HL.Method() << function(self)
    if self.m_selfHandInteractionSyncCoroutine ~= nil then
        return
    end
    self.m_selfHandInteractionSyncCoroutine = CoroutineManager:StartCoroutine(function()
        while true do
            coroutine.step()
            if self.m_selfHandInteractionNode.activeInHierarchy
                    and self.m_cardSelectionEnabled then
                self:_RefreshSelfHandInteraction()
                if self.m_cardRangeSelectionMode == CARD_RANGE_SELECTION_MODE.Pointer
                        and self.m_pointerSelectionButton ~= nil then
                    self:_UpdateCardPointerPendingSelection(
                            self.m_pointerSelectionButton.curPressPos)
                end
            end
        end
    end, self)
end

CardGameLandlordHudCtrl._ResetCardDragSelection = HL.Method() << function(self)
    local hadPendingSelection = self.m_pendingSelectedCardInstIds ~= nil
            and #self.m_pendingSelectedCardInstIds > 0
    self.m_dragSelectionActive = false
    self.m_cardRangeSelectionMode = CARD_RANGE_SELECTION_MODE.None
    self.m_dragSelectionPointerId = -1
    self.m_dragSelectionAnchorIndex = 0
    self.m_dragSelectionFrozenHandInstIds = {}
    self.m_dragSelectionBaselineSet = {}
    self.m_dragSelectionPathIndices = {}
    self.m_dragSelectionFrozenBounds = {}
    self.m_dragSelectionLastMinIndex = 0
    self.m_dragSelectionLastMaxIndex = 0
    self.m_pendingSelectedCardInstIds = {}
    self.m_pointerSelectionButton = nil
    if hadPendingSelection then
        self:_Refresh3DCardInteractionStates()
    end
end

CardGameLandlordHudCtrl._BeginCardRangeSelection = HL.Method(HL.Number, HL.String).Return(HL.Boolean) << function(self, instId, mode)
    if not self:_IsCardSelectionInputAvailable() or self.m_dragSelectionActive then
        return false
    end

    local anchorIndex = 0
    local frozenHandInstIds = {}
    for index, handInstId in ipairs(self.m_selfHandCardInstIds) do
        frozenHandInstIds[index] = handInstId
        if handInstId == instId then
            anchorIndex = index
        end
    end
    if anchorIndex <= 0 then
        return false
    end

    local baselineSet = {}
    for selectedInstId in pairs(self.m_selectedCardInstIdSet) do
        baselineSet[selectedInstId] = true
    end

    self.m_dragSelectionActive = true
    self.m_cardRangeSelectionMode = mode
    self.m_dragSelectionAnchorIndex = anchorIndex
    self.m_dragSelectionFrozenHandInstIds = frozenHandInstIds
    self.m_dragSelectionBaselineSet = baselineSet
    self.m_dragSelectionPathIndices = { anchorIndex }
    self:_ApplyCardDragSelectionRange(anchorIndex)
    return true
end

CardGameLandlordHudCtrl._BeginCardPointerSelection = HL.Method(CS.Beyond.UI.UIButton, HL.Any).Return(HL.Boolean) << function(self, button, eventData)
    if eventData == nil or eventData.button ~= CS.UnityEngine.EventSystems.PointerEventData.InputButton.Left then
        return false
    end
    if self.m_dragSelectionActive then
        return self.m_cardRangeSelectionMode == CARD_RANGE_SELECTION_MODE.Pointer and eventData.pointerId == self.m_dragSelectionPointerId
    end
    local hasPointerStart, pointerStartLocalPosition = Unity.RectTransformUtility.ScreenPointToLocalPointInRectangle(self.m_selfHandInteractionRoot, eventData.position, self.uiCamera)
    if not hasPointerStart then
        return false
    end
    
    local bounds = self:_BuildSelfHandCardBounds()
    local anchorInstId = self.m_selfHandCardInstIds[CardGameLandlordHudCtrl._FindCardIndexByX(bounds, pointerStartLocalPosition.x)]
    if not self:_BeginCardRangeSelection(anchorInstId, CARD_RANGE_SELECTION_MODE.Pointer) then
        return false
    end
    self.m_dragSelectionPointerId = eventData.pointerId
    self.m_dragSelectionFrozenBounds = bounds
    self.m_pointerSelectionButton = button 
    return true
end


CardGameLandlordHudCtrl._BuildSelfHandCardBounds = HL.Method().Return(HL.Table) << function(self)
    local bounds = {}
    local rect
    for index, instId in ipairs(self.m_selfHandCardInstIds) do
        rect = self.m_selfHandInteractionCellsByUid[instId].projectedRect
        bounds[index] = rect.localCenter.x - rect.size.x * 0.5
        if index > 1 and bounds[index] <= bounds[index - 1] then
            logger.error(string.format("[斗地主] 第 index 张手牌投影左边缘没有在上一张右侧，二分查找前提被破坏，鼠标拖选会选错牌：index=%d, x=%s, prevX=%s",
                    index, tostring(bounds[index]), tostring(bounds[index - 1])))
        end
    end
    bounds[#bounds + 1] = rect.localCenter.x + rect.size.x * 0.5
    return bounds
end



CardGameLandlordHudCtrl._FindCardIndexByX = HL.StaticMethod(HL.Table, HL.Number).Return(HL.Number) << function(bounds, x)
    local lo, hi = 1, #bounds - 1
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if bounds[mid] <= x then
            lo = mid
        else
            hi = mid - 1
        end
    end
    return lo
end

CardGameLandlordHudCtrl._UpdateCardPointerPendingSelection = HL.Method(Vector2).Return(HL.Boolean) << function(self, screenPosition)
    if self.m_cardRangeSelectionMode ~= CARD_RANGE_SELECTION_MODE.Pointer
            or not self.m_dragSelectionActive then
        return false
    end
    local hasLocalPosition, localPosition = Unity.RectTransformUtility.ScreenPointToLocalPointInRectangle(
            self.m_selfHandInteractionRoot, screenPosition, self.uiCamera)
    if not hasLocalPosition then
        return false
    end
    return self:_ApplyCardDragSelectionRange(
            CardGameLandlordHudCtrl._FindCardIndexByX(self.m_dragSelectionFrozenBounds, localPosition.x))
end

CardGameLandlordHudCtrl._ApplyCardRangeSelectionIndices = HL.Method(HL.Table).Return(HL.Boolean) << function(self, rangeIndices)
    if not self.m_dragSelectionActive or rangeIndices == nil or #rangeIndices <= 0 then
        return false
    end

    local frozenHandInstIds = self.m_dragSelectionFrozenHandInstIds
    local rangeIndexSet = {}
    for _, index in ipairs(rangeIndices) do
        rangeIndexSet[index] = true
    end
    local pendingSelectedInstIds = {}
    for index, handInstId in ipairs(frozenHandInstIds) do
        if rangeIndexSet[index] == true then
            pendingSelectedInstIds[#pendingSelectedInstIds + 1] = handInstId
        end
    end
    self.m_pendingSelectedCardInstIds = pendingSelectedInstIds
    self:_Refresh3DCardInteractionStates()
    return true
end

CardGameLandlordHudCtrl._CommitCardRangeSelection = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_dragSelectionActive or #self.m_pendingSelectedCardInstIds <= 0 then
        return false
    end

    local pendingSelectedSet = {}
    local allSelected = true
    for _, instId in ipairs(self.m_pendingSelectedCardInstIds) do
        pendingSelectedSet[instId] = true
        if not self.m_dragSelectionBaselineSet[instId] then
            allSelected = false
        end
    end
    local targetSelected = not allSelected
    local selectedInstIds = {}
    for _, handInstId in ipairs(self.m_dragSelectionFrozenHandInstIds) do
        local isPendingSelected = pendingSelectedSet[handInstId] == true
        if (isPendingSelected and targetSelected)
                or (not isPendingSelected and self.m_dragSelectionBaselineSet[handInstId]) then
            selectedInstIds[#selectedInstIds + 1] = handInstId
        end
    end

    
    self.m_pendingSelectedCardInstIds = {}
    self:_SetSelectedCardInstIdsInternal(selectedInstIds)
    self:_RefreshLocalActionButtons()
    return true
end

CardGameLandlordHudCtrl._ApplyCardDragSelectionRange = HL.Method(HL.Number).Return(HL.Boolean) << function(self, endIndex)
    if not self.m_dragSelectionActive or endIndex <= 0 then
        return false
    end
    local minIndex = math.min(self.m_dragSelectionAnchorIndex, endIndex)
    local maxIndex = math.max(self.m_dragSelectionAnchorIndex, endIndex)
    if minIndex == self.m_dragSelectionLastMinIndex
            and maxIndex == self.m_dragSelectionLastMaxIndex then
        return true
    end
    local rangeIndices = {}
    for index = minIndex, maxIndex do
        rangeIndices[#rangeIndices + 1] = index
    end
    self.m_dragSelectionLastMinIndex = minIndex
    self.m_dragSelectionLastMaxIndex = maxIndex
    return self:_ApplyCardRangeSelectionIndices(rangeIndices)
end

CardGameLandlordHudCtrl._EndCardPointerSelection = HL.Method(HL.Any).Return(HL.Boolean) << function(self, eventData)
    if self.m_cardRangeSelectionMode ~= CARD_RANGE_SELECTION_MODE.Pointer
            or not self.m_dragSelectionActive
            or (eventData ~= nil and eventData.pointerId ~= self.m_dragSelectionPointerId) then
        return false
    end
    if not self:_IsCardSelectionInputAvailable() then
        self:_ResetCardDragSelection()
        return false
    end
    if eventData ~= nil then
        self:_UpdateCardPointerPendingSelection(eventData.position)
    end
    self:_CommitCardRangeSelection()
    self:_ResetCardDragSelection()
    return true
end

CardGameLandlordHudCtrl._UpdateCardRangeSelectionFromFocus = HL.Method(HL.Number)
        << function(self, instId)
    if not self.m_dragSelectionActive
            or (self.m_cardRangeSelectionMode ~= CARD_RANGE_SELECTION_MODE.Controller
                and self.m_cardRangeSelectionMode ~= CARD_RANGE_SELECTION_MODE.Touchpad) then
        return
    end
    local targetIndex = self:_FindSelfHandCardIndex(instId)
    if targetIndex <= 0 then
        return
    end
    
    local pathIndices = self.m_dragSelectionPathIndices
    local pathCount = #pathIndices
    if pathCount > 1 and pathIndices[pathCount - 1] == targetIndex then
        pathIndices[pathCount] = nil
    elseif pathIndices[pathCount] ~= targetIndex then
        pathIndices[#pathIndices + 1] = targetIndex
    end
    self:_ApplyCardRangeSelectionIndices(pathIndices)
end

CardGameLandlordHudCtrl._ScheduleFocusedCardClear = HL.Method(HL.Number) << function(self, instId)
    self.m_focusEpoch = self.m_focusEpoch + 1
    local epoch = self.m_focusEpoch
    if self.m_focusClearTimer >= 0 then
        self.m_focusClearTimer = self:_ClearTimer(self.m_focusClearTimer)
    end
    self.m_focusClearTimer = self:_StartTimer(0, function()
        self.m_focusClearTimer = -1
        if epoch == self.m_focusEpoch and self.m_focusedCardInstId == instId then
            self:ClearFocusedCardInstId()
        end
    end, true)
end

CardGameLandlordHudCtrl._CancelFocusedCardClear = HL.Method() << function(self)
    self.m_focusEpoch = self.m_focusEpoch + 1
    if self.m_focusClearTimer >= 0 then
        self.m_focusClearTimer = self:_ClearTimer(self.m_focusClearTimer)
    end
end

CardGameLandlordHudCtrl._ClearCardInteractionTimers = HL.Method() << function(self)
    self.m_cardNaviFocused = false
    self:_ResetTouchpadCardSelection()
    if self.m_dragSelectionActive then
        self:_ResetCardDragSelection()
    end
    self:_CancelFocusedCardClear()
    self.m_selfHandInteractionSyncCoroutine = CoroutineManager:ClearCoroutine(
            self.m_selfHandInteractionSyncCoroutine)
end

CardGameLandlordHudCtrl._ApplyCardDataToWidget = HL.Method(HL.Any, HL.Number, HL.Opt(HL.Table, HL.Boolean)) << function(self, widget, instId, cardData, faceUp)
    widget:InitCardGame2DPoker(instId)
    if faceUp == false then
        widget:SetFace(false)
        return
    end
    local suit = cardData.pokerSuit or cardData.suit
    local rank = cardData.pokerRank or cardData.rank
    if not string.isEmpty(cardData.style) then
        widget:SetCardSuitRankStyle(suit, rank, cardData.style)
    else
        widget:SetCardSuitRank(suit, rank)
    end
    widget:SetFace(true)
end

CardGameLandlordHudCtrl._RefreshLandlordCards = HL.Method(HL.Table) << function(self, model)
    local bottomInstIds = model.bottomInstIds or {}
    local bottomCards = model.bottomCards or {}
    
    local showBottomCards = model.flowState == FLOW_STATE.Bidding or model.flowState == FLOW_STATE.Playing
            or model.flowState == FLOW_STATE.Settling
            or model.flowState == FLOW_STATE.Dealing and self.view.landlordCardNode.gameObject.activeSelf
    self.view.landlordCardNode.gameObject:SetActive(showBottomCards)
    if showBottomCards then
        
        self.view.stateController:SetState("Ready")
        self.view.quickMenuHintNode:SetAvailable(true)
    end
    for index = 1, 3 do
        local widget = self.m_landlordCardWidgets[index]
        local handoffState = self.m_bottomHandoffStates[index]
        local instId = bottomInstIds[index] or (handoffState and handoffState.uid or nil)
        local cardData = handoffState and handoffState.cardData or bottomCards[index]
        widget.view.rectTransform.gameObject:SetActive(showBottomCards)
        if instId ~= nil then
            self:_ApplyCardDataToWidget(widget, instId, cardData,
                    handoffState == nil or handoffState.faceUp ~= false)
        else
            widget:InitCardGame2DPoker(0)
            widget:SetFace(false)
        end
        local contentVisible = #bottomInstIds > 0
        if model.flowState == FLOW_STATE.Dealing then
            contentVisible = false
        end
        if handoffState ~= nil then
            contentVisible = handoffState.visible == true
        end
        widget:SetPokerContentVisible(contentVisible)
    end
end

CardGameLandlordHudCtrl._HideSelfHandCardFocus = HL.Method() << function(self)
    if self.m_cardNaviFocused then
        self:ClearNaviTarget()
    end
    self:_CancelFocusedCardClear()
    self.m_cardNaviFocused = false
    self.m_focusedCardInstId = 0
    self:_RefreshCardFocusState()
end



CardGameLandlordHudCtrl._UpdateHandInteractionLock = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, model, context)
    local kind = context and context.kind
    local bottomChangesSelfHand = false
    if kind == HUD_COMMAND_KIND.BottomRevealed then
        local selfSeat = model.seats and model.seats[1] or nil
        local nextHandInstIds = selfSeat and selfSeat.handCardsInstIds or {}
        bottomChangesSelfHand = #nextHandInstIds ~= #self.m_selfHandCardInstIds
        if not bottomChangesSelfHand then
            for index, instId in ipairs(nextHandInstIds) do
                if self.m_selfHandCardInstIds[index] ~= instId then
                    bottomChangesSelfHand = true
                    break
                end
            end
        end
    end
    local shouldReset = kind == HUD_COMMAND_KIND.Deal
            or bottomChangesSelfHand
    if shouldReset then
        self:_ResetTouchpadCardSelection()
        if self.m_dragSelectionActive then
            self:_ResetCardDragSelection()
        end
        if next(self.m_selectedCardInstIdSet) ~= nil then
            self:_SetSelectedCardInstIdsInternal({})
        end
        self.m_resetCardFocusToFirst = true
        self.m_handInteractionLocked = model.presentationBusy == true
        self:_HideSelfHandCardFocus()
    elseif self.m_handInteractionLocked and not model.presentationBusy then
        self.m_handInteractionLocked = false
    end
end

CardGameLandlordHudCtrl._ResolveFocusAfterHandChanged = HL.Method(HL.Table, HL.Number)
        .Return(HL.Number) << function(self, previousHandInstIds, previousFocusedInstId)
    if #self.m_selfHandCardInstIds <= 0 then
        return 0
    end
    if self.m_resetCardFocusToFirst or previousFocusedInstId == 0 then
        return self.m_selfHandCardInstIds[1]
    end

    local currentSet = {}
    for _, instId in ipairs(self.m_selfHandCardInstIds) do
        currentSet[instId] = true
    end
    if currentSet[previousFocusedInstId] then
        return previousFocusedInstId
    end

    local previousIndex = 0
    for index, instId in ipairs(previousHandInstIds) do
        if instId == previousFocusedInstId then
            previousIndex = index
            break
        end
    end
    for index = previousIndex + 1, #previousHandInstIds do
        local instId = previousHandInstIds[index]
        if currentSet[instId] then
            return instId
        end
    end
    for index = previousIndex - 1, 1, -1 do
        local instId = previousHandInstIds[index]
        if currentSet[instId] then
            return instId
        end
    end
    return self.m_selfHandCardInstIds[1]
end

CardGameLandlordHudCtrl._RefreshSelfHandCardFocus = HL.Method(HL.Table, HL.Number, HL.Boolean) << function(self, previousHandInstIds, previousFocusedInstId, handChanged)
    if not self.m_cardSelectionEnabled or self.m_selfHandInteractionSuppressed then
        self:_HideSelfHandCardFocus()
        return
    end
    if not DeviceInfo.usingController then
        return
    end

    local targetInstId = self.m_focusedCardInstId
    if handChanged or self.m_resetCardFocusToFirst or targetInstId == 0 then
        targetInstId = self:_ResolveFocusAfterHandChanged(
                previousHandInstIds, previousFocusedInstId)
    end
    if targetInstId ~= 0 and self:_SetSelfHandCardNaviTarget(targetInstId) then
        self.m_resetCardFocusToFirst = false
    end
end

CardGameLandlordHudCtrl._RefreshSelfHandCards = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, model, syncSelectedLayout)
    local previousHandInstIds = self.m_selfHandCardInstIds
    local previousFocusedInstId = self.m_focusedCardInstId
    local wasSelectionEnabled = self.m_cardSelectionEnabled
    local selfSeat = model.seats and model.seats[1] or nil
    local nextHandInstIds = selfSeat and selfSeat.handCardsInstIds or nil
    local nextHandCount = nextHandInstIds and #nextHandInstIds or 0
    local handChanged = #self.m_selfHandCardInstIds ~= nextHandCount
    if not handChanged then
        for index = 1, nextHandCount do
            if self.m_selfHandCardInstIds[index] ~= nextHandInstIds[index] then
                handChanged = true
                break
            end
        end
    end
    local shouldCancelCardInput = handChanged or syncSelectedLayout == true
    local hasActiveCardInput = self.m_dragSelectionActive
            or self.m_touchpadSwipeStartPos ~= nil
    if shouldCancelCardInput and hasActiveCardInput then
        self:_ResetTouchpadCardSelection()
        if self.m_dragSelectionActive then
            self:_ResetCardDragSelection()
        end
    end
    if handChanged then
        local handInstIds = {}
        for index = 1, nextHandCount do
            handInstIds[index] = nextHandInstIds[index]
        end
        self.m_selfHandCardInstIds = handInstIds
    end
    
    self.m_cardSelectionEnabled = nextHandCount > 0 and model.inGame and not model.isRecovering
            and not model.hasClientFlowError
            and not self.m_handInteractionLocked
            and model.phaseReady and model.phaseActive and not model.headlessPresentation
    if not self.m_cardSelectionEnabled and (self.m_dragSelectionActive
            or self.m_touchpadSwipeStartPos ~= nil) then
        self:_ResetTouchpadCardSelection()
        if self.m_dragSelectionActive then
            self:_ResetCardDragSelection()
        end
    end
    if not wasSelectionEnabled and self.m_cardSelectionEnabled then
        self.m_resetCardFocusToFirst = true
    end
    self:_SetSelectCardBindingGray(not self.m_cardSelectionEnabled)
    
    if handChanged then
        self:_RefreshSelfHandInteractionList()
    else
        
        self:_RefreshSelfHandInteraction()
        if nextHandCount > 0 then
            self:_EnsureSelfHandInteractionSyncCoroutine()
        else
            self.m_selfHandInteractionSyncCoroutine = CoroutineManager:ClearCoroutine(
                    self.m_selfHandInteractionSyncCoroutine)
        end
    end
    self:_RefreshSelfHandCardFocus(
            previousHandInstIds, previousFocusedInstId, handChanged)
    if syncSelectedLayout == true or (handChanged and not self.m_handInteractionLocked) then
        
        self:_RefreshCardSelectionVisuals(handChanged and syncSelectedLayout ~= true)
    else
        self:_Refresh3DCardInteractionStates()
    end
end

CardGameLandlordHudCtrl._IsCardSelected = HL.Method(HL.Number).Return(HL.Boolean) << function(self, instId)
    return self.m_selectedCardInstIdSet[instId] == true
end

CardGameLandlordHudCtrl._IsCardPendingSelected = HL.Method(HL.Number).Return(HL.Boolean) << function(self, instId)
    for _, pendingInstId in ipairs(self.m_pendingSelectedCardInstIds or {}) do
        if pendingInstId == instId then
            return true
        end
    end
    return false
end

CardGameLandlordHudCtrl._RefreshCardSelectionVisuals = HL.Method(HL.Opt(HL.Boolean)) << function(self, useAnim)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system ~= nil then
        system:RefreshSelfHandLayout(
                self.m_selfHandCardInstIds, self.m_selectedCardInstIdSet, useAnim == true)
    end
    self:_Refresh3DCardInteractionStates()
end


CardGameLandlordHudCtrl._RefreshCardFocusState = HL.Method() << function(self)
    self:_Refresh3DCardInteractionStates()
end

CardGameLandlordHudCtrl._Refresh3DCardInteractionStates = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem == nil then
        return
    end

    local currentInstIds = {}
    local hasControllerFocus = DeviceInfo.usingController and self.m_cardNaviFocused
            and InputManagerInst:IsGroupEnabled(self.view.inputGroup.groupId)
    for _, instId in ipairs(self.m_selfHandCardInstIds) do
        currentInstIds[instId] = true
        local card = cardSystem:GetRuntimeCard(instId)
        if card ~= nil then
            card:SetInteractionState(self:_IsCardSelected(instId),
                    hasControllerFocus and self.m_focusedCardInstId == instId,
                    self:_IsCardPendingSelected(instId))
        end
    end
    for instId, _ in pairs(self.m_cardInteractionStateInstIds) do
        if not currentInstIds[instId] then
            local card = cardSystem:GetRuntimeCard(instId)
            if card ~= nil then
                card:SetInteractionState(false, false, false)
            end
        end
    end
    self.m_cardInteractionStateInstIds = currentInstIds
end

CardGameLandlordHudCtrl._Clear3DCardInteractionStates = HL.Method() << function(self)
    local cardSystem = LuaSystemManager.cardGameSystem
    if cardSystem ~= nil then
        for instId, _ in pairs(self.m_cardInteractionStateInstIds or {}) do
            local card = cardSystem:GetRuntimeCard(instId)
            if card ~= nil then
                card:SetInteractionState(false, false, false)
            end
        end
    end
    self.m_cardInteractionStateInstIds = {}
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system ~= nil then
        system:RefreshSelfHandLayout(self.m_selfHandCardInstIds, {}, false)
    end
end

CardGameLandlordHudCtrl._ResolveCardHandoffWidget = HL.Method(HL.Table).Return(HL.Any) << function(self, request)
    local index = request.index or 0
    if index <= 0 and request.uid ~= nil then
        for slotIndex = 1, 3 do
            local state = self.m_bottomHandoffStates[slotIndex]
            if state ~= nil and state.uid == request.uid then
                index = slotIndex
                break
            end
        end
    end
    return index >= 1 and index <= 3 and self.m_landlordCardWidgets[index] or nil
end


CardGameLandlordHudCtrl.PrepareBottomCardDeal = HL.Method() << function(self)
    self.view.landlordCardNode.gameObject:SetActive(true)
    self.view.titleNode.gameObject:SetActive(true)
    self.view.quickMenuHintNode:SetAvailable(true)
    for index = 1, 3 do
        local widget = self.m_landlordCardWidgets[index]
        widget.view.rectTransform.gameObject:SetActive(true)
        widget:SetPokerContentVisible(false)
    end
    CS.UnityEngine.Canvas.ForceUpdateCanvases()
end


CardGameLandlordHudCtrl.PrepareCardHandoff = HL.Method(HL.Table).Return(HL.Boolean) << function(self, request)
    if request == nil then
        return false
    end
    if request.zone == nil and request.kind ~= nil then
        local model = request.viewModel or self.m_latestHudModel
        if model == nil then
            return false
        end
        self:_PrepareBottomCardDisplayState(model, request)
        self:_RefreshSelfHandCards(model)
        self:_RefreshLandlordCards(model)
        CS.UnityEngine.Canvas.ForceUpdateCanvases()
        return true
    end
    local visible = request.visible == true
    local faceUp = request.faceUp ~= false
    if request.zone ~= HANDOFF_CONFIG.ZoneBottom then
        return false
    end
    local index = request.index or 0
    if index < 1 or index > 3 then
        return false
    end
    self.m_bottomHandoffStates[index] = {
        uid = request.uid or 0,
        index = index,
        visible = visible,
        faceUp = faceUp,
        cardData = request.cardData,
    }

    local widget = self:_ResolveCardHandoffWidget(request)
    local uid = request.uid or 0
    self:_ApplyCardDataToWidget(widget, uid, request.cardData, faceUp)
    widget:SetPokerContentVisible(visible)
    return true
end

CardGameLandlordHudCtrl.ResolveCardHandoffPose = HL.Method(HL.Table).Return(HL.Opt(HL.Any))  << function(self, request)
    if request == nil then
        return nil
    end
    
    if not self.view.landlordCardNode.gameObject.activeInHierarchy then
        return nil
    end
    local widget = self:_ResolveCardHandoffWidget(request)
    local cardTransform = request.cardTransform
    local rectTransform = widget:GetHandoffRectTransform()
    local positionRectTransform = widget:GetHandoffPositionRectTransform()
    return CS.Beyond.UI.WorldGoAlignedUI.GetExternalAlignedPose(
            cardTransform,
            rectTransform,
            positionRectTransform,
            request.cameraDist or HANDOFF_CONFIG.CameraDist,
            request.thickness or HANDOFF_CONFIG.Thickness,
            request.euler or request.localEulerAngles or HANDOFF_CONFIG.Euler)
end

CardGameLandlordHudCtrl.SetCardHandoffVisible = HL.Method(HL.Table).Return(HL.Boolean) << function(self, request)
    if request == nil or not self:PrepareCardHandoff(request) then
        return false
    end
    local widget = self:_ResolveCardHandoffWidget(request)
    widget:SetPokerContentVisible(request.visible == true)
    return true
end

CardGameLandlordHudCtrl._AttachHud = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system == nil then
        return
    end
    system:AttachHud(self)
    self.m_hudAttached = true
end

CardGameLandlordHudCtrl._DetachHud = HL.Method() << function(self)
    if not self.m_hudAttached then
        return
    end
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system ~= nil then
        system:DetachHud(self)
    end
    self.m_hudAttached = false
end

CardGameLandlordHudCtrl._RefreshLocalActionButtons = HL.Method() << function(self)
    if self.m_latestHudModel ~= nil then
        self:_RefreshActionButtons(self.m_latestHudModel)
    end
end


CardGameLandlordHudCtrl.RefreshHud = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, model, context)
    if model == nil then
        return
    end
    self.m_latestHudModel = model
    if self.m_lastFlowState ~= model.flowState then
        self.m_lastFlowState = model.flowState
        if model.flowState == FLOW_STATE.Recovering then
            self.m_suppressedPointInfoHudSeat = 0
            self:_ClearPointInfoDecisions()
        end
        
        self.m_lastProjectedEventId = nil
    end
    self:_UpdateHandInteractionLock(model, context)
    local isRebuild = context ~= nil and context.kind == HUD_COMMAND_KIND.Rebuild
    if isRebuild then
        self.m_suppressedPointInfoHudSeat = 0
        self:_ClearPointInfoDecisions()
        self:_ClearStateToast()
        self:_ClearActionToast()
        self.m_lastProgressToastEventId = nil
    end
    
    self:_PrepareBottomCardDisplayState(model, context)
    
    local eventId = context and context.kind and context.localEventId
    if eventId ~= nil and eventId ~= self.m_lastProjectedEventId then
        self.m_lastProjectedEventId = eventId
        self:_UpdatePointInfoState(context)
        self:_TryPlayPointInfoBubbleAudio(model, context)
        self:_UpdateSeatTipsByEvent(context)
    end
    local selfSeat = model.seats and model.seats[1] or nil
    local handCards = selfSeat and selfSeat.handCardsInstIds or nil
    if handCards == nil or #handCards <= 0 then
        if next(self.m_selectedCardInstIdSet) ~= nil then
            self:_SetSelectedCardInstIdsInternal({})
        end
    else
        self:_RevalidateSelectedCardInstIds(handCards)
    end
    
    self:_RefreshPlayerInfos(model)
    
    
    self.view.emojiNode.gameObject:SetActive(not model.hideControllerHints)
    if not model.hideControllerHints then
        self.view.playerInfoNode.gameObject:SetActive(true)
    end
    
    self:_RefreshTurnStates(model)
    
    
    self:_RefreshLandlordCards(model)
    
    self:_RefreshSelfHandCards(model, isRebuild)
    self:_RefreshActionButtons(model)
end

CardGameLandlordHudCtrl._PrepareBottomCardDisplayState = HL.Method(HL.Table, HL.Opt(HL.Table))
        << function(self, model, context)
    if context == nil then
        return
    end
    if context.kind == HUD_COMMAND_KIND.Rebuild then
        
        self.view.landlordCardNode.gameObject:SetActive(#(model.bottomInstIds or {}) == 3 or context.showBottomBack == true)
        self.m_bottomHandoffStates = {}
        if #(model.bottomInstIds or {}) == 3 then
            for index, instId in ipairs(model.bottomInstIds) do
                self.m_bottomHandoffStates[index] = {
                    uid = instId,
                    index = index,
                    visible = true,
                    faceUp = true,
                    cardData = model.bottomCards[index],
                }
            end
        elseif context.showBottomBack then
            for index = 1, 3 do
                self.m_bottomHandoffStates[index] = {
                    uid = 0,
                    index = index,
                    visible = true,
                    faceUp = false,
                }
            end
        end
    elseif context.kind == HUD_COMMAND_KIND.Deal then
        self.view.landlordCardNode.gameObject:SetActive(false)
        self.m_bottomHandoffStates = {}
        for index = 1, 3 do
            self.m_bottomHandoffStates[index] = {
                uid = 0,
                index = index,
                visible = false,
                faceUp = false,
            }
        end
    elseif context.kind == HUD_COMMAND_KIND.BottomRevealed then
        local bottomCards = context.bottomCards or model.bottomCards
        for index, instId in ipairs(context.bottomInstIds or model.bottomInstIds or {}) do
            local oldState = self.m_bottomHandoffStates[index]
            self.m_bottomHandoffStates[index] = {
                uid = instId,
                index = index,
                visible = oldState == nil or oldState.visible == true,
                faceUp = false,
                cardData = bottomCards[index],
            }
        end
    end
end

CardGameLandlordHudCtrl._RefreshPlayerInfos = HL.Method(HL.Table) << function(self, model)
    local seats = model.seats or {}
    local hasLandlord = (model.landlordHudSeat or 0) > 0
    local bidStartHudSeat = model.bidStartHudSeat or 0
    for hudSeat = 1, 3 do
        local playerInfoNode = self.m_playerInfoNodes[hudSeat]
        local seat = seats[hudSeat]
        
        self:_RefreshSeatTipsTriggers(hudSeat,
                seat ~= nil and not hasLandlord and hudSeat == bidStartHudSeat,
                seat ~= nil and hasLandlord,
                model.flowState == FLOW_STATE.Playing)
        if seat ~= nil then
            playerInfoNode.moneyNumTxt.text = tostring(seat.handCardsCount or 0)
            playerInfoNode.iconNum:LoadSprite(string.format(
                    UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, seat.serverSeatId))
            if hudSeat ~= 1 then
                playerInfoNode.playerNameTxt.text = CardGameUtils.GetPlayerDisplayName(seat.displayInfo, seat.nickname)
                playerInfoNode.iconAI.gameObject:SetActive(CardGameUtils.IsMemberShowAI(seat.memberId))
                self:_RefreshPlayerHead(hudSeat, seat.displayInfo)
            end
            local roleStateController = playerInfoNode.roleNode.stateController
            roleStateController.gameObject:SetActive(hasLandlord)
            if hasLandlord then
                roleStateController:SetState(seat.isLandlord
                        and UI_STATE.PlayerRole.Landlord or UI_STATE.PlayerRole.Peasantry)
            end
        end
    end
end

CardGameLandlordHudCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    local memberId = unpack(arg)
    local hudSeat = LuaSystemManager.cardGameDoudizhuSystem:GetHudSeatByMemberId(memberId)
    if hudSeat ~= nil and hudSeat ~= 1 then
        self.m_playerInfoNodes[hudSeat].iconAI.gameObject:SetActive(CardGameUtils.IsMemberShowAI(memberId))
    end
end


CardGameLandlordHudCtrl.SetSeatHandCardCount = HL.Method(HL.Number, HL.Number) << function(self, hudSeat, count)
    local playerInfoNode = self.m_playerInfoNodes[hudSeat]
    if playerInfoNode ~= nil then
        playerInfoNode.moneyNumTxt.text = tostring(count)
    end
end

CardGameLandlordHudCtrl._RefreshPlayerHead = HL.Method(HL.Number, HL.Table) << function(self, hudSeat, displayInfo)
    if self.m_isPlayerHeadInit[hudSeat] then
        return
    end
    self.m_isPlayerHeadInit[hudSeat] = true
    CardGameUtils.InitCommonPlayerHead(self.m_playerInfoNodes[hudSeat].commonPlayerHead, displayInfo)
end


CardGameLandlordHudCtrl._InitSeatTips = HL.Method() << function(self)
    self.m_seatTipsTypes = {}
    self.m_seatTipsTimers = {}
    self.m_startFlagShown = {}
    self.m_roleNodeShown = {}
    for hudSeat = 1, 3 do
        local playerInfoNode = self.m_playerInfoNodes[hudSeat]
        self:_BindSeatTipsButton(hudSeat, playerInfoNode.startFlagNode.button, function()
            return self.m_startFlagShown[hudSeat] and UI_STATE.SeatTips.RobLandlord or nil
        end)
        self:_BindSeatTipsButton(hudSeat, playerInfoNode.roleNode.button, function()
            if not self.m_roleNodeShown[hudSeat] then
                return nil
            end
            local seat = self.m_latestHudModel and self.m_latestHudModel.seats[hudSeat]
            if seat == nil then
                return nil
            end
            return seat.isLandlord and UI_STATE.SeatTips.Landlord or UI_STATE.SeatTips.Peasant
        end)
    end
    self:_ResetSeatTips()
end


CardGameLandlordHudCtrl._BindSeatTipsButton = HL.Method(HL.Number, CS.Beyond.UI.UIButton, HL.Function)
        << function(self, hudSeat, button, getTipsState)
    if DeviceInfo.usingKeyboard then
        button.onHoverChange:AddListener(function(isHover)
            if isHover then
                self:_TryShowNormalSeatTips(hudSeat, false, getTipsState())
            else
                self:_HideNormalSeatTips(hudSeat)
            end
        end)
    end
    if DeviceInfo.usingTouch then
        button.onClick:AddListener(function()
            if self.m_seatTipsTypes[hudSeat] == SEAT_TIPS_TYPE.Normal then
                self:_HideNormalSeatTips(hudSeat)
                return
            end
            self:_TryShowNormalSeatTips(hudSeat, true, getTipsState())
        end)
    end
end


CardGameLandlordHudCtrl._ResetSeatTips = HL.Method() << function(self)
    for hudSeat = 1, 3 do
        self:_ClearSeatTipsTimer(hudSeat)
        local playerInfoNode = self.m_playerInfoNodes[hudSeat]
        
        for _, node in ipairs({ playerInfoNode.tipsNode, playerInfoNode.startFlagNode }) do
            node.animationWrapper:ClearTween(false)
            node.gameObject:SetActive(false)
        end
        self.m_startFlagShown[hudSeat] = false
        self.m_roleNodeShown[hudSeat] = false
    end
    self.m_seatTipsTypes = {}
end

CardGameLandlordHudCtrl._RefreshSeatTipsTriggers = HL.Method(HL.Number, HL.Boolean, HL.Boolean, HL.Boolean)
        << function(self, hudSeat, showStartFlag, showRole, isPlaying)
    local startFlagHidden = self.m_startFlagShown[hudSeat] and not showStartFlag
    if self.m_startFlagShown[hudSeat] ~= showStartFlag then
        self.m_startFlagShown[hudSeat] = showStartFlag
        self:_PlayNodeShowAni(self.m_playerInfoNodes[hudSeat].startFlagNode, showStartFlag)
    end
    local roleHidden = self.m_roleNodeShown[hudSeat] and not showRole
    self.m_roleNodeShown[hudSeat] = showRole
    
    if startFlagHidden or roleHidden then
        self:_HideNormalSeatTips(hudSeat)
    end
    
    if not isPlaying and self.m_seatTipsTypes[hudSeat] == SEAT_TIPS_TYPE.LastCard then
        self:_HideSeatTips(hudSeat)
    end
end

CardGameLandlordHudCtrl._UpdateSeatTipsByEvent = HL.Method(HL.Table) << function(self, command)
    if command.kind == HUD_COMMAND_KIND.Deal or command.kind == HUD_COMMAND_KIND.Settlement then
        for hudSeat = 1, 3 do
            self:_HideSeatTips(hudSeat)
        end
    elseif command.kind == HUD_COMMAND_KIND.PlayCards and command.hudSeat > 0 then
        local remainCount = command.remainCount or 0
        if remainCount > 0 and remainCount < self.view.config.LAST_CARD_NUM_SHOW_TIPS then
            self.m_playerInfoNodes[command.hudSeat].tipsNode.lastCardNumTipsTxt.text =
                    string.format(Language.LUA_CARD_GAME_DOUDIZHU_LAST_CARD_TIPS, remainCount)
            self:_ShowSeatTips(command.hudSeat, SEAT_TIPS_TYPE.LastCard, UI_STATE.SeatTips.LastCard,
                    self.view.config.LAST_CARD_TIPS_SHOW_DURATION)
        end
    end
end


CardGameLandlordHudCtrl._TryShowNormalSeatTips = HL.Method(HL.Number, HL.Boolean, HL.Opt(HL.String))
        << function(self, hudSeat, autoHide, stateName)
    if stateName == nil or self.m_seatTipsTypes[hudSeat] == SEAT_TIPS_TYPE.LastCard then
        return
    end
    self:_ShowSeatTips(hudSeat, SEAT_TIPS_TYPE.Normal, stateName,
            autoHide and self.view.config.NORMAL_TIPS_SHOW_DURATION or 0)
end


CardGameLandlordHudCtrl._ShowSeatTips = HL.Method(HL.Number, HL.String, HL.String, HL.Number)
        << function(self, hudSeat, tipsType, stateName, duration)
    self:_ClearSeatTipsTimer(hudSeat)
    local tipsNode = self.m_playerInfoNodes[hudSeat].tipsNode
    local wasShown = self.m_seatTipsTypes[hudSeat] ~= nil
    self.m_seatTipsTypes[hudSeat] = tipsType
    tipsNode.stateController:SetState(stateName)
    if not wasShown then
        self:_PlayNodeShowAni(tipsNode, true)
    end
    if duration > 0 then
        self.m_seatTipsTimers[hudSeat] = self:_StartTimer(duration, function()
            self.m_seatTipsTimers[hudSeat] = nil
            self:_HideSeatTips(hudSeat)
        end, true)
    end
end

CardGameLandlordHudCtrl._HideNormalSeatTips = HL.Method(HL.Number) << function(self, hudSeat)
    if self.m_seatTipsTypes[hudSeat] == SEAT_TIPS_TYPE.Normal then
        self:_HideSeatTips(hudSeat)
    end
end

CardGameLandlordHudCtrl._HideSeatTips = HL.Method(HL.Number) << function(self, hudSeat)
    self:_ClearSeatTipsTimer(hudSeat)
    if self.m_seatTipsTypes[hudSeat] == nil then
        return
    end
    self.m_seatTipsTypes[hudSeat] = nil
    self:_PlayNodeShowAni(self.m_playerInfoNodes[hudSeat].tipsNode, false)
end

CardGameLandlordHudCtrl._ClearSeatTipsTimer = HL.Method(HL.Number) << function(self, hudSeat)
    local timer = self.m_seatTipsTimers[hudSeat]
    if timer then
        self:_ClearTimer(timer)
        self.m_seatTipsTimers[hudSeat] = nil
    end
end

CardGameLandlordHudCtrl._PlayNodeShowAni = HL.Method(HL.Any, HL.Boolean) << function(self, node, isShow)
    local wrapper = node.animationWrapper
    if isShow then
        
        wrapper:ClearTween(false)
        node.gameObject:SetActive(true)
        wrapper:PlayInAnimation()
    elseif node.gameObject.activeSelf then
        wrapper:PlayOutAnimation(function()
            node.gameObject:SetActive(false)
        end)
    end
end


CardGameLandlordHudCtrl._RefreshTurnStates = HL.Method(HL.Table) << function(self, model)
    local isActionPhase = model.flowState == FLOW_STATE.Bidding
            or model.flowState == FLOW_STATE.Playing
    
    local showTurn = model.inGame and model.phaseReady
            and not model.headlessPresentation and not model.isRecovering
            and not model.hasClientFlowError
            and isActionPhase and model.turnHudSeat > 0
    local hasDeadline = model.deadlineMs > 0
    
    local remainMs = hasDeadline and math.max(0,
            model.deadlineMs - LuaSystemManager.cardGameDoudizhuSystem:GetCountDownNowMs()) or 0
    local pointInfoDecisions = self.m_pointInfoDecisions
    local showCountdown = showTurn and hasDeadline
            and pointInfoDecisions[model.turnHudSeat] == nil
    local countdownWindow = self.m_deadlineCountdownWindow
    if showCountdown then
        if countdownWindow == nil
                or countdownWindow.windowSeqId ~= model.windowSeqId
                or countdownWindow.hudSeat ~= model.turnHudSeat
                or countdownWindow.deadlineMs ~= model.deadlineMs then
            countdownWindow = {
                windowSeqId = model.windowSeqId,
                hudSeat = model.turnHudSeat,
                deadlineMs = model.deadlineMs,
                displayedSeconds = -1,
                ticking = true,
            }
            self.m_deadlineCountdownWindow = countdownWindow
            self.m_deadlineCountdownDurationMs = math.max(1, remainMs)
        end
        countdownWindow.ticking = remainMs > 0
    else
        self.m_deadlineCountdownWindow = nil
        self.m_deadlineCountdownDurationMs = 0
    end
    local countdownProgress = showCountdown and math.min(1,
            remainMs / math.max(1, self.m_deadlineCountdownDurationMs)) or 0
    
    local turnState = hasDeadline and remainMs <= POINT_INFO_CONFIG.DeadlineWarningMs
            and UI_STATE.PointInfo.Warning or UI_STATE.PointInfo.Normal
    for hudSeat = 1, 3 do
        local pointInfoNode = self.m_pointInfoNodes[hudSeat]
        local decision = pointInfoDecisions[hudSeat]
        local persistentState = POINT_INFO_DECISION_TO_STATE[decision]
        local isCurrent = hudSeat ~= self.m_suppressedPointInfoHudSeat
                and (persistentState ~= nil
                    or showCountdown and model.turnHudSeat == hudSeat)
        local go = pointInfoNode.gameObject
        if isCurrent ~= go.activeSelf then
            pointInfoNode.animationWrapper:ClearTween(false)
            go:SetActive(isCurrent)
            if isCurrent then
                pointInfoNode.animationWrapper:PlayInAnimation()
            end
        end
        if isCurrent then
            local stateName = persistentState or turnState
            if persistentState == nil then
                if countdownWindow.displayedState ~= stateName then
                    countdownWindow.displayedState = stateName
                    pointInfoNode.stateController:SetState(stateName)
                end
                pointInfoNode.timeSlider:SetValueWithoutNotify(countdownProgress)
                local displaySeconds = math.floor(remainMs / 1000)
                if countdownWindow.displayedSeconds ~= displaySeconds then
                    
                    if countdownWindow.displayedSeconds >= 0 and stateName == UI_STATE.PointInfo.Warning then
                        AudioAdapter.PostEvent("Au_UI_Event_CardGameCountDown")
                    end
                    countdownWindow.displayedSeconds = displaySeconds
                    pointInfoNode.timeNumTxt.text = tostring(displaySeconds)
                end
            else
                pointInfoNode.stateController:SetState(stateName)
            end
        end
    end
end

CardGameLandlordHudCtrl._RefreshActionButtons = HL.Method(HL.Table) << function(self, model)
    local isBidding = model.flowState == FLOW_STATE.Bidding
    local isPlaying = model.flowState == FLOW_STATE.Playing
    
    local showButtonRoot = model.inGame and model.phaseReady
            and not model.hasClientFlowError and (isBidding or isPlaying)
    
    local showActions = isBidding and model.canBid == true
            or isPlaying and model.canPlay == true
    self:_RefreshOptInfoNode(showButtonRoot, showButtonRoot and showActions)
    local isCantAfford = self:_IsCantAfford(model)
    self:_SetCantAffordToastShown(showButtonRoot and isCantAfford)
    if not showActions then
        self:_SetContinueButtonState(UI_STATE.Continue.Empty, false)
        self:_SetStopButtonState(UI_STATE.Stop.Empty, false)
        self:_SetReminderButtonState(false, false)
        return
    end

    if isBidding then
        self:_SetContinueButtonState(UI_STATE.Continue.Bid, model.canBid == true)
        self:_SetStopButtonState(UI_STATE.Stop.Bid, model.canBid == true)
        self:_SetReminderButtonState(false, false)
        return
    end

    if isCantAfford then
        if self.m_dragSelectionActive then
            self:_ResetCardDragSelection()
        end
        if next(self.m_selectedCardInstIdSet) ~= nil then
            
            self:_SetSelectedCardInstIdsInternal({})
        end
        self:_SetContinueButtonState(UI_STATE.Continue.PlayDisabled, false)
        self:_SetStopButtonState(UI_STATE.Stop.CantAfford, true)
        self:_SetReminderButtonState(false, false)
        return
    end

    
    
    local hasSelection = next(self.m_selectedCardInstIdSet) ~= nil
    self:_SetContinueButtonState(hasSelection
            and UI_STATE.Continue.Play or UI_STATE.Continue.PlayDisabled, true)
    self:_SetStopButtonState(model.canRequestPass == true
            and UI_STATE.Stop.Pass or UI_STATE.Stop.Empty, model.canRequestPass == true)
    self:_SetReminderButtonState(true, self.m_cardSelectionEnabled)
end



CardGameLandlordHudCtrl._RefreshOptInfoNode = HL.Method(HL.Boolean, HL.Boolean)
        << function(self, isActive, isShown)
    local optInfoNode = self.view.optInfoNode
    local go = optInfoNode.gameObject
    local wrapper = optInfoNode.animationWrapper
    self.m_optInfoActive = isActive
    if isShown then
        if not self.m_optInfoShown or not go.activeSelf then
            self.m_optInfoShown = true
            self.m_optInfoOutPlaying = false
            
            wrapper:ClearTween(false)
            go:SetActive(true)
            wrapper:PlayInAnimation()
        end
        return
    end
    if self.m_optInfoShown then
        self.m_optInfoShown = false
        if go.activeInHierarchy then
            self.m_optInfoOutPlaying = true
            wrapper:PlayOutAnimation(function()
                self.m_optInfoOutPlaying = false
                if not self.m_optInfoActive then
                    go:SetActive(false)
                end
            end)
            return
        end
    end
    if self.m_optInfoOutPlaying then
        return
    end
    if isActive and not go.activeSelf then
        
        go:SetActive(true)
        wrapper:SampleToOutAnimationEnd()
    elseif not isActive then
        go:SetActive(false)
    end
end

CardGameLandlordHudCtrl._ResetOptInfoNode = HL.Method() << function(self)
    local optInfoNode = self.view.optInfoNode
    optInfoNode.animationWrapper:ClearTween(false)
    optInfoNode.gameObject:SetActive(false)
    self.m_optInfoShown = false
    self.m_optInfoOutPlaying = false
    self.m_optInfoActive = false
end

CardGameLandlordHudCtrl._IsCantAfford = HL.Method(HL.Table).Return(HL.Boolean)
        << function(self, model)
    return model.flowState == FLOW_STATE.Playing and model.turnHudSeat == 1
            and model.canPlay == true and model.canRequestPass == true
            and model.hasPlayableResponse == false
end

CardGameLandlordHudCtrl._SetContinueButtonState = HL.Method(HL.String, HL.Boolean)
        << function(self, stateName, interactable)
    local optInfoNode = self.view.optInfoNode
    optInfoNode.continueBtnStateCtrl:SetState(stateName)
    optInfoNode.continueBtn.interactable = interactable
end

CardGameLandlordHudCtrl._SetStopButtonState = HL.Method(HL.String, HL.Boolean)
        << function(self, stateName, interactable)
    local optInfoNode = self.view.optInfoNode
    optInfoNode.stopBtnStateCtrl:SetState(stateName)
    optInfoNode.stopBtn.interactable = interactable
end

CardGameLandlordHudCtrl._SetReminderButtonState = HL.Method(HL.Boolean, HL.Boolean)
        << function(self, active, interactable)
    local reminderBtn = self.view.optInfoNode.reminderBtn
    reminderBtn.gameObject:SetActive(active)
    reminderBtn.interactable = active and interactable
end


CardGameLandlordHudCtrl.GetDeadlineCountdownState = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local window = self.m_deadlineCountdownWindow
    if window == nil then
        return nil
    end
    return {
        windowSeqId = window.windowSeqId,
        hudSeat = window.hudSeat,
        deadlineMs = window.deadlineMs,
        durationMs = self.m_deadlineCountdownDurationMs,
    }
end

CardGameLandlordHudCtrl.RestoreDeadlineCountdownState = HL.Method(HL.Table) << function(self, state)
    local window = self.m_deadlineCountdownWindow
    
    if window == nil or window.windowSeqId ~= state.windowSeqId
            or window.hudSeat ~= state.hudSeat or window.deadlineMs ~= state.deadlineMs then
        return
    end
    self.m_deadlineCountdownDurationMs = state.durationMs
    self:_RefreshTurnStates(self.m_latestHudModel)
end

CardGameLandlordHudCtrl._ResetDeadlineCountdown = HL.Method() << function(self)
    self.m_deadlineCountdownWindow = nil
    self.m_deadlineCountdownDurationMs = 0
end

CardGameLandlordHudCtrl._InitDeadlineCountdown = HL.Method() << function(self)
    self:_ResetDeadlineCountdown()
    local trackedWindow = nil
    local nextRefreshTime = 0
    self:_StartUpdate(function()
        local window = self.m_deadlineCountdownWindow
        if window ~= trackedWindow then
            trackedWindow = window
            nextRefreshTime = 0
        end
        if window == nil or not window.ticking or self.m_latestHudModel == nil then
            return
        end
        local currentTime = Time.unscaledTime
        if currentTime < nextRefreshTime then
            return
        end
        nextRefreshTime = currentTime + POINT_INFO_CONFIG.UpdateInterval
        self:_RefreshTurnStates(self.m_latestHudModel)
    end)
end

CardGameLandlordHudCtrl._OnClickContinue = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system == nil then
        return
    end
    local model = self.m_latestHudModel
    if model == nil then
        return
    end
    if model.flowState == FLOW_STATE.Bidding then
        
        AudioAdapter.PostEvent("Au_UI_Button_CardBidWarlord")
        system:RequestBid(true)
    elseif model.flowState == FLOW_STATE.Playing and not self:_IsCantAfford(model) then
        local selectedCardInstIds = self:_GetSelectedCardInstIds()
        if #selectedCardInstIds <= 0 then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_CARD_GAME_DOUDIZHU_NO_CARD_SELECTED_TOAST)
            return
        end
        local selectionResult = system:GetPlaySelectionResult(selectedCardInstIds)
        if selectionResult == PLAY_SELECTION_RESULT.InvalidPattern then
            self:_RejectPlaySelection(Language.LUA_CARD_GAME_DOUDIZHU_INVALID_PATTERN_TOAST)
        elseif selectionResult == PLAY_SELECTION_RESULT.CannotBeat then
            self:_RejectPlaySelection(Language.LUA_CARD_GAME_DOUDIZHU_CANNOT_BEAT_LAST_PLAY_TOAST)
        elseif selectionResult == PLAY_SELECTION_RESULT.Playable then
            
            system:RequestPlay(selectedCardInstIds)
        end
    end
end

CardGameLandlordHudCtrl._OnClickStop = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system == nil then
        return
    end
    local model = self.m_latestHudModel
    if model == nil then
        return
    end
    if model.flowState == FLOW_STATE.Bidding then
        system:RequestBid(false)
    elseif model.flowState == FLOW_STATE.Playing then
        self:_TryRequestPass()
    end
end

CardGameLandlordHudCtrl._TryRequestPass = HL.Method().Return(HL.Boolean) << function(self)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system == nil or not system:RequestPass() then
        return false
    end
    self:_SetSelectedCardInstIdsInternal({})
    self:_RefreshLocalActionButtons()
    return true
end

CardGameLandlordHudCtrl._RejectPlaySelection = HL.Method(HL.String) << function(self, toastText)
    self:Notify(MessageConst.SHOW_TOAST, toastText)
    if self.m_dragSelectionActive then
        self:_ResetCardDragSelection()
    end
    self:_SetSelectedCardInstIdsInternal({})
    self:_RefreshLocalActionButtons()
end

CardGameLandlordHudCtrl._OnClickReminder = HL.Method() << function(self)
    local system = LuaSystemManager.cardGameDoudizhuSystem
    if system == nil or not self.m_cardSelectionEnabled then
        return
    end
    local hint = system:GetNextPlayHint(self:_GetSelectedCardInstIds())
    if hint == nil then
        self:SetSelectedCardInstIds({})
        return
    end

    self:SetSelectedCardInstIds(hint.instIds)
    logger.info(string.format("[斗地主][提示] 已选择第%d/%d组：牌型ID=%s，主点数=%s，牌=%s",
            hint.index, hint.count, tostring(hint.patternId), tostring(hint.mainRank),
            table.concat(hint.instIds, ",")))
end


CardGameLandlordHudCtrl.SetSelectedCardInstIds = HL.Method(HL.Opt(HL.Table)) << function(self, instIds)
    if self.m_dragSelectionActive then
        self:_ResetCardDragSelection()
    end
    self:_SetSelectedCardInstIdsInternal(instIds or {})
    self:_RefreshLocalActionButtons()
end


CardGameLandlordHudCtrl._GetSelectedCardInstIds = HL.Method().Return(HL.Table) << function(self)
    local selectedInstIds = {}
    for _, instId in ipairs(self.m_selfHandCardInstIds) do
        if self.m_selectedCardInstIdSet[instId] then
            selectedInstIds[#selectedInstIds + 1] = instId
        end
    end
    return selectedInstIds
end


CardGameLandlordHudCtrl.GetSelectedCardInstIds = HL.Method().Return(HL.Table) << function(self)
    return self:_GetSelectedCardInstIds()
end

CardGameLandlordHudCtrl._SetSelectedCardInstIdsInternal = HL.Method(HL.Table)
        << function(self, instIds)
    local available = {}
    for _, instId in ipairs(self.m_selfHandCardInstIds) do
        available[instId] = true
    end
    local selectedSet = {}
    for _, instId in ipairs(instIds) do
        if available[instId] then
            selectedSet[instId] = true
        end
    end
    self.m_selectedCardInstIdSet = selectedSet
    self:_RefreshCardSelectionVisuals()
end

CardGameLandlordHudCtrl.ToggleSelectedCardInstId = HL.Method(HL.Number).Return(HL.Boolean)
        << function(self, instId)
    if not self.m_cardSelectionEnabled or self.m_dragSelectionActive then
        return false
    end
    local selectedSet = self.m_selectedCardInstIdSet
    if selectedSet[instId] then
        selectedSet[instId] = nil
    elseif self:_FindSelfHandCardIndex(instId) > 0 then
        selectedSet[instId] = true
    end
    self:_RefreshCardSelectionVisuals()
    self:_RefreshLocalActionButtons()
    return true
end

CardGameLandlordHudCtrl.SetFocusedCardInstId = HL.Method(HL.Number).Return(HL.Boolean)
        << function(self, instId)
    if not self.m_cardSelectionEnabled then
        return false
    end
    local found = false
    for _, handInstId in ipairs(self.m_selfHandCardInstIds) do
        if handInstId == instId then
            found = true
            break
        end
    end
    if not found then
        return false
    end
    if self.m_focusedCardInstId == instId then
        return true
    end
    self.m_focusedCardInstId = instId
    self:_RefreshCardFocusState()
    return true
end

CardGameLandlordHudCtrl.ClearFocusedCardInstId = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_focusedCardInstId == 0 then
        return false
    end
    self.m_cardNaviFocused = false
    self.m_focusedCardInstId = 0
    self:_RefreshCardFocusState()
    return true
end

CardGameLandlordHudCtrl._RevalidateSelectedCardInstIds = HL.Method(HL.Opt(HL.Table)) << function(self, handCards)
    if next(self.m_selectedCardInstIdSet) == nil then
        return
    end
    local available = {}
    for _, instId in ipairs(handCards or {}) do
        available[instId] = true
    end
    for instId in pairs(self.m_selectedCardInstIdSet) do
        if not available[instId] then
            self.m_selectedCardInstIdSet[instId] = nil
        end
    end
end

CardGameLandlordHudCtrl._RevalidateFocusedCardInstId = HL.Method(HL.Opt(HL.Table)) << function(self, handCards)
    if self.m_focusedCardInstId == 0 then
        return
    end
    for _, instId in ipairs(handCards or {}) do
        if instId == self.m_focusedCardInstId then
            return
        end
    end
    self.m_focusedCardInstId = 0
end


CardGameLandlordHudCtrl.PlaySeatIntro = HL.Method(HL.Boolean, HL.Opt(HL.Table, HL.Number, HL.Function))
        << function(self, visible, players, targetHudSeat, onDone)
    local randomSeatNode = self.view.randomSeatNode
    randomSeatNode:Stop(false)
    if not visible and not self.m_seatIntroVisible then
        return
    end
    self.m_seatIntroVisible = visible
    self:_SetHudMainActive(not visible)
    self.view.playerInfoNode.gameObject:SetActive(not visible)
    self:_SetSelfHandInteractionSuppressed(visible)
    self.m_scene:SetRoomCameraPos(visible and CardGameUtils.RoomCameraPosType.Overlook or CardGameUtils.RoomCameraPosType.Normal)
    if not visible then
        return
    end
    for hudSeat, seatIndex in ipairs(HUD_SEAT_TO_RANDOM_SEAT_INDEX) do
        local displayInfo = players[hudSeat]
        randomSeatNode:SetSeatPlayer(seatIndex, {
            isSelf = hudSeat == 1,
            seatIndex = displayInfo.seatIndex,
            displayInfo = displayInfo,
        })
    end
    randomSeatNode:Play(HUD_SEAT_TO_RANDOM_SEAT_INDEX[targetHudSeat], function()
        self:PlaySeatIntro(false)
        onDone()
    end)
end



CardGameLandlordHudCtrl.PlayHudCommand = HL.Method(HL.Table, HL.Function).Return(HL.Opt(HL.Function))
        << function(self, command, onDone)
    if command.kind == HUD_COMMAND_KIND.Deal then
        for index = 1, 3 do
            local state = self.m_bottomHandoffStates[index]
            self:SetCardHandoffVisible({
                zone = HANDOFF_CONFIG.ZoneBottom,
                uid = state and state.uid or 0,
                index = index,
                visible = true,
                faceUp = false,
            })
        end
    elseif command.kind == HUD_COMMAND_KIND.BottomRevealed then
        for index, instId in ipairs(command.bottomInstIds or {}) do
            self:SetCardHandoffVisible({
                zone = HANDOFF_CONFIG.ZoneBottom,
                uid = instId,
                index = index,
                visible = true,
                faceUp = true,
                cardData = command.bottomCards[index],
            })
        end
    elseif command.kind == HUD_COMMAND_KIND.PlayCards then
        if command.hudSeat == 1 and command.viewModel ~= nil then
            local selfSeat = command.viewModel.seats and command.viewModel.seats[1] or nil
            local handCards = selfSeat and selfSeat.handCardsInstIds or {}
            self:_RevalidateSelectedCardInstIds(handCards)
            self:_RefreshSelfHandCards(command.viewModel)
        end
    elseif command.kind == HUD_COMMAND_KIND.Settlement then
        self:_PlaySettlementToast(command)
        local finished = false
        local timerId = -1
        local finishSettlementToast = function(invokeDone)
            if finished then
                return
            end
            finished = true
            if timerId >= 0 then
                timerId = self:_ClearTimer(timerId)
            end
            self:_ClearStateToast()
            if invokeDone then
                onDone()
            end
        end
        
        timerId = self:_StartTimer(SETTLEMENT_TOAST_DURATION_SECONDS, function()
            timerId = -1
            finishSettlementToast(true)
        end, true)
        return function(applyFinal)
            
            finishSettlementToast(false)
        end
    end
    onDone()
    return nil
end




HL.Commit(CardGameLandlordHudCtrl)
