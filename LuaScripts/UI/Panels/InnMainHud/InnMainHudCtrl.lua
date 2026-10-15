local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnMainHud

local COUNTDOWN_TICK_SEC = 0.2

local GAME_ENDING_FORBID_REASON = "InnGameEnding"

local COMMON_TOAST_DISABLE_KEY = "InnMainHud"

local HIDE_MAIN_HUD_INTERACT_OPTION_KEY = "InnMainHudHidden"

InnMainHudCtrl = HL.Class('InnMainHudCtrl', uiCtrl.UICtrl)






InnMainHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_OPEN_KITCHEN_POP_UP] = '_OnOpenKitchenPopUp',
    [MessageConst.ON_INN_OPEN_DRINK_POP_UP] = '_OnOpenDrinkPopUp',
    [MessageConst.ON_INN_BAR_COUNTER_RETURN_DRINK_INTERACT] = '_OnBarCounterReturnDrinkInteract',
    [MessageConst.ON_INN_SERVING_COUNTER_CHANGED] = '_OnServingCounterChanged',
    [MessageConst.ON_INN_SERVING_COUNTER_INTERACT] = '_OnServingCounterInteract',
    [MessageConst.ON_INN_ENTER_SERVING_COUNTER] = '_OnEnterServingCounter',
    [MessageConst.ON_INN_EXIT_SERVING_COUNTER] = '_OnExitServingCounter',
    [MessageConst.ON_INN_TRASH_CAN_INTERACT] = '_OnTrashCanInteract',
    [MessageConst.ON_INN_STATISTICS_CHANGED] = '_OnStatisticsChanged',
    [MessageConst.ON_INN_DESK_CHECK_OUT] = '_OnDeskCheckOut',
    [MessageConst.ON_INN_DESK_RECEIVE_INTERACT] = '_OnDeskReceiveInteract',
    [MessageConst.ON_INN_DESK_SERVE_INTERACT] = '_OnDeskServeInteract',
    [MessageConst.ON_INN_DESK_CHECKOUT_INTERACT] = '_OnDeskCheckoutInteract',
    [MessageConst.ON_INN_DESK_STATE_CHANGED] = '_OnDeskStateChanged',
    [MessageConst.ON_INN_RUSH_STATE_CHANGED] = '_OnRushStateChanged',
    [MessageConst.ON_INN_AUTO_SERVER_FOOD_CHANGED] = '_OnAutoServeFoodChanged',
    [MessageConst.ON_INN_AUTO_CHECKOUT_CHANGED] = '_OnAutoCheckoutChanged',
    [MessageConst.ON_INN_GUEST_GET_FOOD] = '_OnInnGuestGetFood',
    [MessageConst.ON_INN_GUEST_AUTO_GET_FOOD] = '_OnInnGuestAutoGetFood',
    [MessageConst.ON_INN_PAUSE_GAME] = '_OnInnPauseGame',
    [MessageConst.ON_INN_RESUME_GAME] = '_OnInnResumeGame',
    [MessageConst.ON_INN_DROP_FOOD] = '_OnDropFood',
    [MessageConst.ON_INN_TOPIC_OBJECTIVE_PROGRESS_CHANGED] = '_OnTopicObjectiveProgressChange',
    [MessageConst.ON_INN_FOOD_TRAY_CHANGED] = '_OnFoodTrayChanged',
    [MessageConst.ON_INN_HELD_FOOD_TRAY_SLOT_CHANGED] = '_OnHeldFoodMaybeChanged',
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnChangeInputDeviceTypeFinished',
    [MessageConst.ON_CONFIRM_CHANGE_INPUT_DEVICE_TYPE] = '_OnConfirmChangeInputDeviceType',
    [MessageConst.ON_INN_GAME_TIME_WRAP_UP_CHANGED] = '_OnGameTimeWrapUpChanged',
    [MessageConst.ON_INN_HIDE_MAIN_HUD] = '_OnHideMainHud',
    [MessageConst.ON_INN_SHOW_MAIN_HUD] = '_OnShowMainHud',
    [MessageConst.ON_INN_GAME_END_BEGIN] = '_OnGameEndBegin',
    [MessageConst.ON_INN_GAME_RESULT] = '_OnGameResult',
    [MessageConst.ON_INN_ENDING_CHECKOUT_MONEY] = '_OnEndingCheckoutMoney',
    [MessageConst.ON_INN_SET_KITCHEN_ORDERING_POP_UP_LOCKED] = '_OnSetKitchenOrderingPopUpLocked',
    [MessageConst.ON_INN_KITCHEN_STATE_CHANGED] = '_OnKitchenStateChanged',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = '_OnItemCountChanged',
}

InnMainHudCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnMainHudCtrl.m_levelMountPointRoot = HL.Field(CS.Beyond.Gameplay.LevelMountPointRoot)

local PAUSE_SOURCE_NONE = 0
local PAUSE_SOURCE_EXIT_CONFIRM = 1
local PAUSE_SOURCE_RUSH_TIPS = 2
InnMainHudCtrl.m_pendingPauseSource = HL.Field(HL.Number) << PAUSE_SOURCE_NONE

InnMainHudCtrl.m_rushTipsFreezeHandle = HL.Field(HL.Number) << 0

InnMainHudCtrl.m_isRushTipsHotSwitching = HL.Field(HL.Boolean) << false

InnMainHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_PlayFirstInAnimation()
    Notify(MessageConst.TOGGLE_INTERACT_OPTION_WHITE_LIST, {"InnFood", true, { CS.Beyond.Gameplay.Core.InteractOptionType.InnFood, CS.Beyond.Gameplay.Core.InteractOptionType.InnGame }})
    Notify(MessageConst.ON_DISABLE_COMMON_TOAST, COMMON_TOAST_DISABLE_KEY)
    GameInstance.player.commonTrackingSystem:AddTrackingPointWhiteList("Inn", { CS.Beyond.Gameplay.CommonTrackingPointStyleType.Inn })
    self.m_innSystem = GameInstance.player.innSystem
    _, self.m_levelMountPointRoot = GameInstance.dataManager.levelMountPointTable:TryGetData(GameWorld.worldInfo.curLevelId)
    LuaSystemManager.innRootSystem:Prepare(self.view.config.DISH_HUD, self.view.config.GUEST_HUD)
    LuaSystemManager.innNpcSystem:PrepareGameNpc()
    LuaSystemManager.innRadioSystem:PrepareInnRadio()
    self:_InitAction()
    self:_InitCountdown()
    self:_RefreshServingCounters()
    self:_InitDeskStates()
    self:_InitNpcHuds()
    self:_InitStatistics()
    self:_InitRushMode()
    self:_InitAutoService()
    self:_InitTopic()
    self:_InitServeFood()
    self:_InitRadio()
    self:_InitMainCharFoodPerform()
    self:_RefreshSoldOutReminder()
    self.view.topNode.autoCheckoutToastNode.gameObject:SetActive(false)
    UIManager:PreloadPanelAsset(PanelId.InnKitchenOrderingPopUp, PANEL_ID)
    UIManager:PreloadPanelAsset(PanelId.InnDrinkMenuPopUp, PANEL_ID)
    self:_StartStagedInit()
end

InnMainHudCtrl._StartStagedInit = HL.Method() << function(self)
    self:_StartCoroutine(function()
        local function waitStep()
            coroutine.wait(self.view.config.STAGED_INIT_STEP_INTERVAL)
        end
        waitStep()
        self:_InitKitchens(waitStep)
        self:_InitDeskHUDs(waitStep)
    end)
end

InnMainHudCtrl._PlayFirstInAnimation = HL.Method() << function(self)
    local wrapper = self.animationWrapper
    if not wrapper then
        return
    end
    wrapper:ClearTween(false)
    wrapper:SetAnimationInClip("innmainhud_first_in")
    self.view.luaPanel:BlockAllInput()
    wrapper:PlayInAnimation(function()
        wrapper:SetAnimationInClip("innmainhud_in")
        self.view.luaPanel:RecoverAllInput()
    end)
    AudioManager.PostEvent("Au_UI_Popup_InnOperateStart")
end

InnMainHudCtrl.OnShow = HL.Override() << function(self)
    self.m_innSystem.isMainHudShowing = true
    self:_RefreshRushTriggerEffect()
end

InnMainHudCtrl.OnHide = HL.Override() << function(self)
    self.m_innSystem.isMainHudShowing = false
    self:_ClearRushTriggerEffect()
end

InnMainHudCtrl.OnClose = HL.Override() << function(self)
    self.m_innSystem.isMainHudShowing = false
    self.m_soldOutReminderPendingTimerId = self:_ClearTimer(self.m_soldOutReminderPendingTimerId)
    Notify(MessageConst.TOGGLE_INTERACT_OPTION_WHITE_LIST, {"InnFood", false})
    Notify(MessageConst.ON_ENABLE_COMMON_TOAST, COMMON_TOAST_DISABLE_KEY)
    self:_SetBlockPlayerActionForGameEnding(false)
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { HIDE_MAIN_HUD_INTERACT_OPTION_KEY, false })
    GameInstance.player.commonTrackingSystem:RemoveTrackingPointWhiteList("Inn")
    LuaSystemManager.innNpcSystem:ReleaseGameNpc()
    LuaSystemManager.innRadioSystem:ReleaseInnRadio()
    self:_DestroyKitchens()
    self:_DestroyServingCounters()
    self:_DestroyDeskHUDs()
    self:_DestroyMoneyHUDs()
    self:_DestroyGuestHuds()
    self:_DestroyMainCharFoodPerform()
    self:_ClearAllDeskDishModels()
    self:_ClearAllDeskPurseModels()
    LuaSystemManager.innRootSystem:DestroyInnRoot()
    self:_ClearMoneyCellHideTimer()
    self:_DestroyRushMode()
    self:_CleanupRushInstructionBook()
    self:_ClearServeFoodHideTimer()

    if CS.Beyond.BeyondMemoryUtility.IsLowMemoryDevice() then
        CS.Beyond.Lua.UtilsForLua.ForceGCWithBlackScreen("InnMainHud ForceGC")
    end
end

InnMainHudCtrl._InitAction = HL.Method() << function(self)
    self.view.topNode.exitGameBtn.onClick:AddListener(function()
        self:_ShowExitConfirmPopup()
    end)
    if self.view.innFoodTray then
        self.view.innFoodTray:InitInnFoodTray()
    end
    if self.view.kitchenOrderBtn then
        self.view.kitchenOrderBtn.onClick:AddListener(function()
            if self:_BlockKitchenOrderingPopUpIfLocked() then
                return
            end
            self.view.innFoodTray.view.selectableNaviGroup:ManuallyStopFocus()
            UIManager:AutoOpen(PanelId.InnKitchenOrderingPopUp)
        end)
    end
end

InnMainHudCtrl._ShowExitConfirmPopup = HL.Method() << function(self)
    self:_RequestPauseGame(PAUSE_SOURCE_EXIT_CONFIRM)
end

InnMainHudCtrl._RequestPauseGame = HL.Method(HL.Number) << function(self, source)
    if self.m_pendingPauseSource ~= PAUSE_SOURCE_NONE then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    self.m_innSystem:RequestManualPauseGame()
    if gameState.isPaused then
        self:_ShowManualPauseUI(source)
        return
    end
    self.m_pendingPauseSource = source
end

InnMainHudCtrl._OnInnPauseGame = HL.Method() << function(self)
    local source = self.m_pendingPauseSource
    self.m_pendingPauseSource = PAUSE_SOURCE_NONE
    self:_ShowManualPauseUI(source)
end

InnMainHudCtrl._ShowManualPauseUI = HL.Method(HL.Number) << function(self, source)
    if source == PAUSE_SOURCE_EXIT_CONFIRM then
        self:_ShowPauseGamePopup()
    elseif source == PAUSE_SOURCE_RUSH_TIPS then
        self:_OpenRushInstructionBook()
    end
end

InnMainHudCtrl._ShowPauseGamePopup = HL.Method() << function(self)
    self.m_innSystem.isMainHudShowing = false
    self:Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_INN_MAIN_HUD_EXIT_POPUP_TEXT,
        onConfirm = function()
            if self.m_innSystem then
                self.m_innSystem:SendExitGame()
            end
        end,
        onCancel = function()
            if self.m_innSystem then
                self.m_innSystem:ReleaseManualPauseGame()
            end
            self.m_innSystem.isMainHudShowing = true
        end,
        freezeWorld = true,
    })
end

InnMainHudCtrl._OnInnResumeGame = HL.Method() << function(self)
    self:_RefreshCountdown()
    self:_RefreshRushModeProgress()
    self:_FlushPendingAutoCompletes()
end

InnMainHudCtrl._OnDeskStateChanged = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 then
        return
    end
    self:_RefreshDeskDishModelsByState(deskId)
    self:_RefreshDeskPurseModel(deskId)
    self:_OnDeskStateChangedForNpcHud(args)
    self:_TryShowRushAdditionsOnEating(deskId)
end

InnMainHudCtrl._OnInnGuestGetFood = HL.Method(HL.Table) << function(self, args)
    local deskId, foodId = unpack(args)
    if not foodId or foodId <= 0 then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    local hasFood, food = gameState.foods:TryGetValue(foodId)
    if not hasFood or food == nil or string.isEmpty(food.itemId) then
        return
    end
    self:_ShowServeFood(food.itemId, food.isRare == true)
    self:_RefreshDeskDishModels(deskId)
    self:_PlayServeFoodSound(deskId, foodId)
end

InnMainHudCtrl._PlayServeFoodSound = HL.Method(HL.Number, HL.Number) << function(self, deskId, foodId)
    if self.m_innSystem == nil or not deskId or deskId <= 0 then
        return
    end
    local isRight = self.m_innSystem:IsServedFoodSatisfied(deskId, foodId)
    local eventName = isRight and "au_int_system_inn_food_dishup_right" or "au_int_system_inn_food_dishup_wrong"
    local models = self.m_deskDishModels and self.m_deskDishModels[deskId]
    local dishGo = models and models[1]
    if dishGo then
        AudioManager.PostEvent(dishGo, eventName)
    else
        AudioManager.PostEvent(eventName)
    end
end

InnMainHudCtrl._OnInnGuestAutoGetFood = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 then
        return
    end
    self:_RefreshDeskDishModels(deskId)
end

InnMainHudCtrl._OnChangeInputDeviceTypeFinished = HL.Method(HL.Any) << function(self, args)
    self.view.innFoodTray:OnChangeInputDeviceTypeFinished(args)
    self:_RefreshRushTriggerEffect()
    if self.m_isRushTipsHotSwitching then
        self.m_isRushTipsHotSwitching = false
        self:_OpenRushInstructionBook()
    elseif self.m_innSystem.gameState.isPaused and self.m_innSystem.gameState.isManualPauseHeld and not self.m_innSystem.gameState.isEndingGame then
        
        self:_ShowPauseGamePopup()
    end
end

InnMainHudCtrl._OnConfirmChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    self.view.innFoodTray:OnConfirmChangeInputDeviceType(args)
    self.m_isRushTipsHotSwitching = self.m_rushTipsFreezeHandle > 0
end

InnMainHudCtrl._OnHideMainHud = HL.Method() << function(self)
    self:Hide()
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { HIDE_MAIN_HUD_INTERACT_OPTION_KEY, true })
end

InnMainHudCtrl._OnShowMainHud = HL.Method() << function(self)
    self:Show()
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { HIDE_MAIN_HUD_INTERACT_OPTION_KEY, false })
end

InnMainHudCtrl._OnGameEndBegin = HL.Method() << function(self)
    self.view.luaPanel:BlockAllInput()
    self:_SetBlockPlayerActionForGameEnding(true)
    UIUtils.PlayAnimationAndToggleActive(self.view.topNode.autoCheckoutToastNode, true)
    self.view.topNode.countDownEndNode.gameObject:SetActive(true)
    self.view.topNode.countDownOverNode.gameObject:SetActive(false)
    UIUtils.PlayAnimationAndToggleActive(self.view.topNode.counDownOverTimeNodeAnimationWrapper, false)
    self.view.topNode.countDownNode.gameObject:SetActive(false)
    self.view.topNode.closeEarlyNode.gameObject:SetActive(false)
    self.view.timeReminderNode.gameObject:SetActiveIfNecessary(false)
end

InnMainHudCtrl._OnGameResult = HL.Method() << function(self)
    if self.m_rushPrevInRush and self.view.rushEffect then
        UIUtils.PlayAnimationAndToggleActive(self.view.rushEffect, false)
    end
end

InnMainHudCtrl._SetBlockPlayerActionForGameEnding = HL.Method(HL.Boolean) << function(self, block)
    local forbidSystem = GameInstance.player.forbidSystem
    forbidSystem:SetForbid(ForbidType.ForbidMove, GAME_ENDING_FORBID_REASON, block)
    forbidSystem:SetForbid(ForbidType.ForbidJump, GAME_ENDING_FORBID_REASON, block)
    Notify(MessageConst.TOGGLE_HIDE_INTERACT_OPTION_LIST, { GAME_ENDING_FORBID_REASON, block })
end



InnMainHudCtrl.m_countdownCoroutine = HL.Field(HL.Thread)

InnMainHudCtrl.m_countdownIsWarning = HL.Field(HL.Any)

InnMainHudCtrl.m_wrapUpCountdownIsWarning = HL.Field(HL.Any)

InnMainHudCtrl.m_wrapUpShownSec = HL.Field(HL.Number) << -1

InnMainHudCtrl._InitCountdown = HL.Method() << function(self)
    self.m_countdownIsWarning = nil
    self.m_wrapUpCountdownIsWarning = nil
    self.m_wrapUpShownSec = -1
    self:_UpdateGameTimeWrapUp()
    self:_RefreshCountdown()
    self.m_countdownCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(COUNTDOWN_TICK_SEC)
            self:_RefreshCountdown()
        end
    end)
end

InnMainHudCtrl._RefreshCountdown = HL.Method() << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil or gameState.isPaused or gameState.isGameTimeStopped then
        return
    end

    if gameState.wrapUp then
        local totalSec = Tables.innManagementConst.wrapUpTime
        local warningSec = Tables.innManagementConst.warningWrapUpTime
    
        local nowMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
        local elapsedMs = gameState.elapsedTimeMS + math.max(0, nowMs - gameState.timeStampMS)
        local leftSec = math.max(0, totalSec - elapsedMs / 1000)
    
        self.view.topNode.timeRemainingTxt.text= UIUtils.getSecondsLeftTime(leftSec)
        local shownSec = math.floor(leftSec)
        local isShownSecChanged = shownSec ~= self.m_wrapUpShownSec
        self.m_wrapUpShownSec = shownSec
    
        local isWarning = leftSec <= warningSec
        if isWarning ~= self.m_wrapUpCountdownIsWarning then
            self.m_wrapUpCountdownIsWarning = isWarning
            self.view.topNode.counDownOverTimeNode:SetState(isWarning and "Warning" or "Normal")
        end
        if isWarning and isShownSecChanged then
            AudioManager.PostEvent("Au_UI_Toast_TickDown_OS")
        end
    else
        local totalSec = self.m_innSystem:GetPlayTime()
        local warningSec = Tables.innManagementConst.warningPlayTime
    
        local nowMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
        local elapsedMs = gameState.elapsedTimeMS + math.max(0, nowMs - gameState.timeStampMS)
        local leftSec = math.max(0, totalSec - elapsedMs / 1000)
    
        self.view.topNode.timeNumTxt.text = UIUtils.getLeftTimeToSecond(leftSec)
        self.view.topNode.timeBar.fillAmount = totalSec > 0 and leftSec / totalSec or 0
    
        local isWarning = leftSec <= warningSec
        if isWarning ~= self.m_countdownIsWarning then
            self.m_countdownIsWarning = isWarning
            self.view.topNode.countDownNode:SetState(isWarning and "Warning" or "Normal")
            UIUtils.PlayAnimationAndToggleActive(self.view.topNode.closingSoonToastNode, isWarning)
            AudioManager.PostEvent("Au_UI_Toast_TickDown_OS")
        end
    end
end

InnMainHudCtrl._OnGameTimeWrapUpChanged = HL.Method(HL.Table) << function(self, args)
    self:_UpdateGameTimeWrapUp()
    self:_ScheduleRefreshSoldOutReminder()
end

InnMainHudCtrl._UpdateGameTimeWrapUp = HL.Method() << function(self)
    local wrapUp = self.m_innSystem and self.m_innSystem.gameState and self.m_innSystem.gameState.wrapUp
    self.view.topNode.countDownNode.gameObject:SetActiveIfNecessary(not wrapUp)
    UIUtils.PlayAnimationAndToggleActive(self.view.topNode.closingSoonToastNode, false)
    UIUtils.PlayAnimationAndToggleActive(self.view.topNode.countDownOverNode, wrapUp == true)
    UIUtils.PlayAnimationAndToggleActive(self.view.topNode.counDownOverTimeNodeAnimationWrapper, wrapUp == true)
end





InnMainHudCtrl.m_kitchenHUDs = HL.Field(HL.Table)

InnMainHudCtrl._InitKitchens = HL.Method(HL.Opt(HL.Function)) << function(self, yieldFrame)
    local _, levelMountPointNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(CS.Beyond.Gameplay.LevelMountPointType.InnKitchen)
    if levelMountPointNode == nil then
        return
    end

    
    local configuredIdSet = {}
    local settingList = self.m_innSystem.gameSetting and self.m_innSystem.gameSetting.kitchenSettings
    if settingList and settingList.Count > 0 then
        for i = 0, settingList.Count - 1 do
            local ks = settingList[i]
            if ks then
                configuredIdSet[ks.id] = true
            end
        end
    end

    local kitchenNum = self.m_innSystem.kitchenNum or 0
    local kitchenHudRoot = LuaSystemManager.innRootSystem:GetKitchenHudRoot()
    self.m_kitchenHUDs = {}
    for i = 1, kitchenNum do
        local kitchenKey = Tables.innManagementConst.kitchenKeys[CSIndex(i)]
        local _, kitchenNode = levelMountPointNode.children:TryGetValue(kitchenKey)
        if kitchenNode ~= nil then
            local mountPoint = kitchenNode.mountPoint
            local kitchenHudGo = CSUtils.CreateObject(self.view.config.KITCHEN_HUD, kitchenHudRoot.transform)
            if kitchenHudGo then
                kitchenHudGo.transform:SetPositionAndRotation(mountPoint.position, Quaternion.Euler(mountPoint.rotation))
                local kitchenHud = Utils.wrapLuaNode(kitchenHudGo)
                local initId = configuredIdSet[i] and i or 0
                kitchenHud:InitInnKitchenHUD(initId)
                self.m_kitchenHUDs[i] = kitchenHud
            end
        else
            logger.error(string.format("未找到厨房挂点，厨房id：%d，挂点key：%s", i, kitchenKey))
        end
        if yieldFrame then
            yieldFrame()
        end
    end
end


InnMainHudCtrl._DestroyKitchens = HL.Method() << function(self)
    self.m_kitchenHUDs = nil
end

InnMainHudCtrl.m_isKitchenOrderingPopUpLocked = HL.Field(HL.Boolean) << false

InnMainHudCtrl._OnSetKitchenOrderingPopUpLocked = HL.Method(HL.Table) << function(self, args)
    local locked = unpack(args)
    self.m_isKitchenOrderingPopUpLocked = locked == true
end

InnMainHudCtrl._BlockKitchenOrderingPopUpIfLocked = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_isKitchenOrderingPopUpLocked then
        return false
    end
    Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_MAIN_HUD_KITCHEN_ORDERING_LOCKED_TOAST)
    return true
end

InnMainHudCtrl._OnOpenKitchenPopUp = HL.Method(HL.Table) << function(self, args)
    if self:_BlockKitchenOrderingPopUpIfLocked() then
        return
    end
    local kitchenKey = unpack(args)
    local kitchenId = LuaIndex(lume.find(Tables.innManagementConst.kitchenKeys, kitchenKey))
    local ctrl = UIManager:AutoOpen(PanelId.InnKitchenOrderingPopUp)
    if ctrl then
        ctrl:SelectKitchenTab(kitchenId)
    end
end

InnMainHudCtrl._OnKitchenStateChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_ScheduleRefreshSoldOutReminder()
end

InnMainHudCtrl._OnItemCountChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _args)
    self:_ScheduleRefreshSoldOutReminder()
end

InnMainHudCtrl.m_soldOutReminderPendingTimerId = HL.Field(HL.Number) << -1

InnMainHudCtrl._ScheduleRefreshSoldOutReminder = HL.Method() << function(self)
    if self.m_soldOutReminderPendingTimerId ~= -1 then
        return
    end
    self.m_soldOutReminderPendingTimerId = TimerManager:StartFrameTimer(2, function()
        self.m_soldOutReminderPendingTimerId = -1
        self:_RefreshSoldOutReminder()
    end, self)
end

InnMainHudCtrl._RefreshSoldOutReminder = HL.Method() << function(self)
    local node = self.view.timeReminderNode
    if not node then
        return
    end
    local state = InnUtils.getDishSoldOutTipsState(self.m_innSystem)
    node.gameObject:SetActiveIfNecessary(state == InnUtils.DISH_SOLD_OUT_TIPS_ALL_GONE)
end





InnMainHudCtrl.m_servingCounterDishes = HL.Field(HL.Table)

InnMainHudCtrl.m_servingCounterInteractEffects = HL.Field(HL.Table)


InnMainHudCtrl.m_insideServingCounters = HL.Field(HL.Table)

InnMainHudCtrl._RefreshServingCounters = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAppearEffect)
    if self.m_levelMountPointRoot == nil then
        return
    end
    local _, servingCounterNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(CS.Beyond.Gameplay.LevelMountPointType.InnServingCounter)
    if servingCounterNode == nil then
        return
    end

    self.m_servingCounterDishes = self.m_servingCounterDishes or {}

    local newSlots = {}
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState ~= nil then
        for slotId, foodId in cs_pairs(gameState.servingCounterFoodIds) do
            local _, food = gameState.foods:TryGetValue(foodId)
            if food and not string.isEmpty(food.itemId) then
                newSlots[slotId] = { itemId = food.itemId, isRare = food.isRare == true }
            end
        end
    end

    for slotId, dishInfo in pairs(self.m_servingCounterDishes) do
        local newInfo = newSlots[slotId]
        if newInfo == nil or newInfo.itemId ~= dishInfo.itemId then
            LuaSystemManager.innRootSystem:ReturnDishModel(dishInfo.go)
            LuaSystemManager.innRootSystem:ReturnDishHud(dishInfo.hud)
            self.m_servingCounterDishes[slotId] = nil
        end
    end

    local dishHudOffset = self.view.config.DISH_HUD_OFFSET
    for slotId, slotInfo in pairs(newSlots) do
        if not self.m_servingCounterDishes[slotId] then
            local slotKey = self.m_innSystem:GetServingCounterKeyById(slotId)
            local _, slotNode = servingCounterNode.children:TryGetValue(slotKey)
            if slotNode ~= nil then
                local mountPoint = slotNode.mountPoint
                local dishGo = LuaSystemManager.innRootSystem:GetDishModel(slotInfo.itemId)
                if dishGo then
                    dishGo.transform:SetPositionAndRotation(mountPoint.position, Quaternion.Euler(mountPoint.rotation))
                end
                if playAppearEffect then
                    GameInstance.effectManager:CreateStationaryEffect(
                        InnConst.INN_FOOD_APPEAR_EFFECT_ID, mountPoint.position, Quaternion.Euler(mountPoint.rotation))
                    AudioManager.PostEvent(dishGo, "au_int_system_inn_food_appear")
                end
                local dishHud = LuaSystemManager.innRootSystem:GetDishHud()
                if dishHud then
                    dishHud:InitInnDishIcon({ itemId = slotInfo.itemId, isRare = slotInfo.isRare })
                    dishHud.view.worldUIFollowAndFaceCamera:SetFollowPosition(mountPoint.position, dishHudOffset)
                end
                self.m_servingCounterDishes[slotId] = { go = dishGo, hud = dishHud, itemId = slotInfo.itemId }
            else
                logger.error(string.format("未找到出餐台挂点，slotId：%d，挂点key：%s", slotId, slotKey))
            end
        end
    end
end

InnMainHudCtrl._DestroyServingCounters = HL.Method() << function(self)
    self.m_servingCounterDishes = nil
    self.m_insideServingCounters = nil
    if self.m_servingCounterInteractEffects ~= nil then
        for _, effect in pairs(self.m_servingCounterInteractEffects) do
            local inst = effect and effect:Lock()
            if inst ~= nil then
                inst:Finish()
            end
        end
    end
    self.m_servingCounterInteractEffects = nil
end

InnMainHudCtrl._OnServingCounterChanged = HL.Method() << function(self)
    self:_RefreshServingCounters(true)
    self:_RefreshAllServingCounterInteractEffects()
    self:_ScheduleRefreshSoldOutReminder()
end

InnMainHudCtrl._OnServingCounterInteract = HL.Method(HL.Table) << function(self, args)
    local counterId = unpack(args)
    if not counterId or counterId <= 0 or self.m_innSystem == nil then
        return
    end

    local gameState = self.m_innSystem.gameState
    if gameState == nil then
        return
    end

    local hasFoodId, foodId = gameState.servingCounterFoodIds:TryGetValue(counterId)
    if hasFoodId then
        local hasFood, food = gameState.foods:TryGetValue(foodId)
        if hasFood and food and not string.isEmpty(food.itemId) then
            if self.m_innSystem:IsFoodTrayFull() then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_DRINK_TRAY_FULL)
                return
            end
            local dishInfo = self.m_servingCounterDishes and self.m_servingCounterDishes[counterId]
            local dishGo = dishInfo and dishInfo.go
            if dishGo then
                AudioManager.PostEvent(dishGo, "au_int_system_inn_food_pickup")
            else
                AudioManager.PostEvent("au_int_system_inn_food_pickup")
            end
            self.m_innSystem:SendPickUpFood(food.id)
            return
        end
    end

    local foodTray = self.view.innFoodTray
    if foodTray == nil then
        return
    end
    local heldFood = foodTray:GetHeldFood()
    if heldFood == nil then
        return
    end
    self.m_innSystem:SendReturnDishToServingCounter(counterId, heldFood.id)
end

InnMainHudCtrl._GetServingCounterMountPointByInstId = HL.Method(HL.String).Return(HL.Opt(HL.Userdata)) << function(self, instId)
    if self.m_levelMountPointRoot == nil then
        return nil
    end
    local _, servingCounterNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(
        CS.Beyond.Gameplay.LevelMountPointType.InnServingCounter)
    if servingCounterNode == nil then
        return nil
    end
    local _, slotNode = servingCounterNode.children:TryGetValue(instId)
    if slotNode == nil then
        return nil
    end
    return slotNode.mountPoint
end

InnMainHudCtrl._ServingCounterHasFood = HL.Method(HL.String).Return(HL.Boolean) << function(self, instId)
    if self.m_innSystem == nil then
        return false
    end
    local gameState = self.m_innSystem.gameState
    if gameState == nil then
        return false
    end
    local counterId = self.m_innSystem:GetServingCounterIdByKey(instId)
    if not counterId or counterId <= 0 then
        return false
    end
    local hasFoodId, foodId = gameState.servingCounterFoodIds:TryGetValue(counterId)
    if not hasFoodId then
        return false
    end
    local hasFood, food = gameState.foods:TryGetValue(foodId)
    return hasFood and food ~= nil and not string.isEmpty(food.itemId)
end

InnMainHudCtrl._ShouldShowServingCounterInteractEffect = HL.Method(HL.String).Return(HL.Boolean) << function(self, instId)
    if self.m_innSystem == nil then
        return false
    end
    local heldFood = self.m_innSystem:GetHeldFood()
    if heldFood ~= nil and heldFood.foodType == CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDish then
        return true
    end
    return self:_ServingCounterHasFood(instId)
end

InnMainHudCtrl._RefreshServingCounterInteractEffect = HL.Method(HL.String) << function(self, instId)
    self.m_servingCounterInteractEffects = self.m_servingCounterInteractEffects or {}

    local shouldShow = self.m_insideServingCounters ~= nil
        and self.m_insideServingCounters[instId] == true
        and self:_ShouldShowServingCounterInteractEffect(instId)

    self:_RefreshServingCounterDishArrow(instId, shouldShow)

    local existing = self.m_servingCounterInteractEffects[instId]
    if not shouldShow then
        if existing ~= nil then
            local inst = existing:Lock()
            if inst ~= nil then
                inst:Finish()
            end
            self.m_servingCounterInteractEffects[instId] = nil
        end
        return
    end

    if existing ~= nil then
        return
    end

    local mountPoint = self:_GetServingCounterMountPointByInstId(instId)
    if mountPoint == nil then
        return
    end

    local effect = GameInstance.effectManager:CreateStationaryEffect(
        InnConst.INN_SERVING_COUNTER_INTERACT_EFFECT_ID, mountPoint.position, Quaternion.Euler(mountPoint.rotation))
    self.m_servingCounterInteractEffects[instId] = effect
end


InnMainHudCtrl._RefreshServingCounterDishArrow = HL.Method(HL.String, HL.Boolean) << function(self, instId, visible)
    if self.m_innSystem == nil then
        return
    end
    local counterId = self.m_innSystem:GetServingCounterIdByKey(instId)
    local dishInfo = counterId and self.m_servingCounterDishes and self.m_servingCounterDishes[counterId]
    local hud = dishInfo and dishInfo.hud
    if hud ~= nil then
        hud:SetArrowVisible(visible)
    end
end

InnMainHudCtrl._RefreshAllServingCounterInteractEffects = HL.Method() << function(self)
    if self.m_insideServingCounters == nil then
        return
    end
    for instId in pairs(self.m_insideServingCounters) do
        self:_RefreshServingCounterInteractEffect(instId)
    end
end

InnMainHudCtrl._OnEnterServingCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end

    self.m_insideServingCounters = self.m_insideServingCounters or {}
    self.m_insideServingCounters[instId] = true

    self:_RefreshServingCounterInteractEffect(instId)
end

InnMainHudCtrl._OnExitServingCounter = HL.Method(HL.Table) << function(self, args)
    local instId = unpack(args)
    if not instId or instId == "" then
        return
    end

    if self.m_insideServingCounters ~= nil then
        self.m_insideServingCounters[instId] = nil
    end

    self:_RefreshServingCounterInteractEffect(instId)
end





InnMainHudCtrl._OnOpenDrinkPopUp = HL.Method() << function(self)
    UIManager:AutoOpen(PanelId.InnDrinkMenuPopUp)
end

InnMainHudCtrl._OnBarCounterReturnDrinkInteract = HL.Method() << function(self)
    if self.m_innSystem == nil then
        return
    end
    local foodTray = self.view.innFoodTray
    if foodTray == nil then
        return
    end
    local heldFood = foodTray:GetHeldFood()
    if heldFood == nil or heldFood.foodType ~= CS.Proto.INN_MANAGEMENT_FOOD_TYPE.FoodTypeDrink then
        return
    end
    self.m_innSystem:SendReturnDrink({ heldFood.id })
end






InnMainHudCtrl._OnTrashCanInteract = HL.Method() << function(self)
    if self.m_innSystem == nil then
        return
    end
    local foodTray = self.view.innFoodTray
    if foodTray == nil then
        return
    end
    local heldFood = foodTray:GetHeldFood()
    if heldFood == nil then
        return
    end
    self.m_innSystem:SendDropFood({ heldFood.id })
end




InnMainHudCtrl._OnDropFood = HL.Method(HL.Table) << function(self, args)
    local foodIds = unpack(args)
    if foodIds == nil or foodIds.Count == nil or foodIds.Count <= 0 then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    for i = 0, foodIds.Count - 1 do
        local foodId = foodIds[i]
        local hasFood, food = gameState.foods:TryGetValue(foodId)
        if hasFood and food and not string.isEmpty(food.itemId) then
            local itemData = Tables.itemTable[food.itemId]
            if itemData and itemData.name then
                Notify(MessageConst.SHOW_TOAST,
                    string.format(Language.LUA_INN_MAIN_HUD_DROP_FOOD_TOAST, itemData.name))
            end
        end
    end
end





InnMainHudCtrl.m_heldFoodModelGo = HL.Field(GameObject)

InnMainHudCtrl.m_heldFoodModelItemId = HL.Field(HL.String) << ""

InnMainHudCtrl.m_isHoldingFoodPerform = HL.Field(HL.Boolean) << false

InnMainHudCtrl.m_lastForbidToastTime = HL.Field(HL.Number) << 0

InnMainHudCtrl.m_jumpInputBindingId = HL.Field(HL.Number) << 0

InnMainHudCtrl.m_sprintInputBindingId = HL.Field(HL.Number) << 0

InnMainHudCtrl._InitMainCharFoodPerform = HL.Method() << function(self)
    self.m_isHoldingFoodPerform = false
    self.m_heldFoodModelItemId = ""
    self:_OnHeldFoodMaybeChanged()
end

InnMainHudCtrl._TryToastForbidInfo = HL.Method() << function(self)
    if not self.m_isHoldingFoodPerform then
        return
    end
    local interval = self.view.config and self.view.config.HOLDING_FOOD_FORBID_TOAST_INTERVAL or 0
    local now = Time.unscaledTime
    if interval > 0 and now - self.m_lastForbidToastTime < interval then
        return
    end
    self.m_lastForbidToastTime = now
    Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_MAIN_HUD_HOLDING_FOOD_FORBID)
end

InnMainHudCtrl._OnFoodTrayChanged = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_OnHeldFoodMaybeChanged(args)
    self:_ScheduleRefreshSoldOutReminder()
end

InnMainHudCtrl._OnHeldFoodMaybeChanged = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    local isHolding = self.m_innSystem ~= nil and self.m_innSystem:GetHeldFood() ~= nil
    if isHolding then
        self:_RefreshMainCharFoodPerform()
        self:_RefreshMainCharFoodModel()
    else
        self:_RefreshMainCharFoodModel()
        self:_RefreshMainCharFoodPerform()
    end
    self:_RefreshAllServingCounterInteractEffects()
end

InnMainHudCtrl._RefreshMainCharFoodPerform = HL.Method() << function(self)
    if self.m_innSystem == nil then
        return
    end
    local isHolding = self.m_innSystem:GetHeldFood() ~= nil
    if isHolding == self.m_isHoldingFoodPerform then
        return
    end
    self.m_isHoldingFoodPerform = isHolding
    self:_SetMainCharFoodPerform(isHolding)
end

InnMainHudCtrl._SetMainCharFoodPerform = HL.Method(HL.Boolean) << function(self, isHolding)
    if isHolding then
        self.m_innSystem:PlayMainCharPerform()
        self.m_jumpInputBindingId = self:BindInputPlayerAction("common_jump", function()
            self:_TryToastForbidInfo()
        end)
        self.m_sprintInputBindingId = self:BindInputPlayerAction("common_sprint_start", function()
            self:_TryToastForbidInfo()
        end)
    else
        self.m_innSystem:StopMainCharPerform()
        InputManagerInst:DeleteBinding(self.m_jumpInputBindingId)
        InputManagerInst:DeleteBinding(self.m_sprintInputBindingId)
        self.m_jumpInputBindingId = 0
        self.m_sprintInputBindingId = 0
    end
    local forbidReason = "InnHodingFood"
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidSpIdle, forbidReason, isHolding)
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidJump, forbidReason, isHolding)
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidSprint, forbidReason, isHolding)
end

InnMainHudCtrl._RefreshMainCharFoodModel = HL.Method() << function(self)
    if self.m_innSystem == nil then
        return
    end
    local food = self.m_innSystem:GetHeldFood()
    local newItemId = (food and not string.isEmpty(food.itemId)) and food.itemId or ""
    if newItemId == self.m_heldFoodModelItemId then
        return
    end
    if not IsNull(self.m_heldFoodModelGo) then
        self.m_innSystem:ClearMainCharFoodModel()
        LuaSystemManager.innRootSystem:ReturnHeldFoodModel(self.m_heldFoodModelGo)
    end
    self.m_heldFoodModelGo = nil
    self.m_heldFoodModelItemId = newItemId
    if newItemId ~= "" then
        local go = LuaSystemManager.innRootSystem:GetHeldFoodModel(newItemId)
        if go then
            self.m_heldFoodModelGo = go
            self.m_innSystem:SetMainCharFoodModel(go)
        end
    end
end

InnMainHudCtrl._DestroyMainCharFoodPerform = HL.Method() << function(self)
    if not IsNull(self.m_heldFoodModelGo) then
        self.m_innSystem:ClearMainCharFoodModel()
        LuaSystemManager.innRootSystem:ReturnHeldFoodModel(self.m_heldFoodModelGo)
    end
    self.m_heldFoodModelGo = nil
    self:_SetMainCharFoodPerform(false)
    self.m_isHoldingFoodPerform = false
    self.m_heldFoodModelItemId = ""
end





InnMainHudCtrl.m_deskStateCellCache = HL.Field(HL.Forward("UIListCache"))

InnMainHudCtrl._InitDeskStates = HL.Method() << function(self)
    local topNode = self.view.topNode
    if not topNode or not topNode.innDeskStateCell then
        return
    end

    if self.m_innSystem == nil then
        return
    end

    local deskNum = self.m_innSystem.deskNum or 0
    if deskNum <= 0 then
        return
    end

    self.m_deskStateCellCache = self.m_deskStateCellCache or UIUtils.genCellCache(topNode.innDeskStateCell)
    self.m_deskStateCellCache:GraduallyRefresh(deskNum, self.view.config.DESK_STATE_CELL_REFRESH_INTERVAL, function(cell, index)
        cell:InitInnDeskStateCell({ deskId = index })
    end)
end

InnMainHudCtrl.m_deskHUDs = HL.Field(HL.Table)

InnMainHudCtrl.m_moneyHUDs = HL.Field(HL.Table)

InnMainHudCtrl._InitDeskHUDs = HL.Method(HL.Opt(HL.Function)) << function(self, yieldFrame)
    if self.m_levelMountPointRoot == nil then
        return
    end
    local _, deskRootNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(CS.Beyond.Gameplay.LevelMountPointType.InnDesk)
    if deskRootNode == nil then
        return
    end

    if self.m_innSystem == nil then
        return
    end

    local deskNum = self.m_innSystem.deskNum or 0
    if deskNum <= 0 then
        return
    end

    local deskHudRoot = LuaSystemManager.innRootSystem:GetDeskHudRoot()
    self.m_deskHUDs = {}
    self.m_moneyHUDs = {}
    for deskId = 1, deskNum do
        local deskKey = self.m_innSystem:GetDeskKeyById(deskId)
        local _, deskNode = deskRootNode.children:TryGetValue(deskKey)
        if deskNode == nil then
            logger.error(string.format("未找到餐桌挂点，deskId：%d，挂点key：%s", deskId, deskKey))
        else
            local _, hudNode = deskNode.children:TryGetValue(InnConst.INN_DESK_HUD_MOUNT_KEY)
            if hudNode == nil then
                logger.error(string.format("未找到餐桌HUD子挂点，deskId：%d，挂点key：%s/%s",
                    deskId, deskKey, InnConst.INN_DESK_HUD_MOUNT_KEY))
            else
                local mountPoint = hudNode.mountPoint
                local deskHudGo = CSUtils.CreateObject(self.view.config.DESK_HUD, deskHudRoot.transform)
                if deskHudGo then
                    local deskHud = Utils.wrapLuaNode(deskHudGo)
                    deskHud:InitInnDeskHUD({ deskId = deskId })
                    deskHud.view.worldUIFollowAndFaceCamera:SetFollowPosition(mountPoint.position)
                    self.m_deskHUDs[deskId] = deskHud
                end

                local moneyHudGo = CSUtils.CreateObject(self.view.config.MONEY_HUD, deskHudRoot.transform)
                if moneyHudGo then
                    local moneyHud = Utils.wrapLuaNode(moneyHudGo)
                    moneyHud:InitInnMoneyHUD({ deskId = deskId })
                    moneyHud.view.worldUIFollowAndFaceCamera:SetFollowPosition(mountPoint.position)
                    self.m_moneyHUDs[deskId] = moneyHud
                end
            end
        end
        if yieldFrame then
            yieldFrame()
        end
    end
end

InnMainHudCtrl._DestroyDeskHUDs = HL.Method() << function(self)
    self.m_deskHUDs = nil
end

InnMainHudCtrl._DestroyMoneyHUDs = HL.Method() << function(self)
    self.m_moneyHUDs = nil
end

InnMainHudCtrl._OnDeskReceiveInteract = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 or self.m_innSystem == nil then
        return
    end
    self.m_innSystem:ReceiveGuestByDeskId(deskId)
end

InnMainHudCtrl._OnDeskServeInteract = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 or self.m_innSystem == nil then
        return
    end
    local foodTray = self.view.innFoodTray
    if foodTray == nil then
        return
    end
    local heldFood = foodTray:GetHeldFood()
    if heldFood == nil or string.isEmpty(heldFood.itemId) then
        return
    end

    
    local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
    local canDish, canDrink = InnUtils.getDeskRemainingFoodTypeFlags(self.m_innSystem, deskId)
    if heldFood.foodType == FOOD_TYPE.FoodTypeDish and not canDish and canDrink then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_SERVE_NEED_DRINK_NOT_DISH)
        return
    end
    if heldFood.foodType == FOOD_TYPE.FoodTypeDrink and not canDrink and canDish then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_SERVE_NEED_DISH_NOT_DRINK)
        return
    end

    self.m_innSystem:SendServerFoodComplete(heldFood.id, deskId, false)
end

InnMainHudCtrl._OnDeskCheckoutInteract = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 or self.m_innSystem == nil then
        return
    end
    self.m_innSystem:SendCheckoutComplete(deskId, false)
end






local INN_DESK_FOOD_MAX_MODEL = 2


InnMainHudCtrl.m_deskDishModels = HL.Field(HL.Table)


InnMainHudCtrl.m_deskDishFoodIds = HL.Field(HL.Table)



InnMainHudCtrl._GetDeskFoodSlotIndex = HL.Method(HL.Number).Return(HL.Number) << function(self, deskId)
    if self.m_innSystem == nil or self.m_innSystem.deskAttractPointData == nil then
        return 0
    end
    local hasSeats, seats = self.m_innSystem.deskAttractPointData:TryGetValue(deskId)
    if not hasSeats or seats == nil then
        return 0
    end
    local AttractStatus = CS.Beyond.Gameplay.AI.AttractStatus
    local usingGroup1, usingGroup2 = false, false
    for i = 0, seats.Count - 1 do
        local point = seats[i]
        if point ~= nil and point.attractStatus == AttractStatus.Using then
            if point.groupIndex == 1 then
                usingGroup1 = true
            elseif point.groupIndex == 2 then
                usingGroup2 = true
            end
        end
    end
    if usingGroup1 and usingGroup2 then
        return 3
    elseif usingGroup1 then
        return 1
    elseif usingGroup2 then
        return 2
    end
    return 0
end


InnMainHudCtrl._CollectDeskFoods = HL.Method(HL.Number).Return(HL.Table) << function(self, deskId)
    local result = {}
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil then
        return result
    end
    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil or desk.guestId == 0 then
        return result
    end
    local hasGuest, guest = gameState.guestStates:TryGetValue(desk.guestId)
    if not hasGuest or guest == nil or guest.gotFoodIds == nil then
        return result
    end
    for i = 0, guest.gotFoodIds.Count - 1 do
        local foodId = guest.gotFoodIds[i]
        local hasFood, food = gameState.foods:TryGetValue(foodId)
        if hasFood and food and not string.isEmpty(food.itemId) then
            if #result >= INN_DESK_FOOD_MAX_MODEL then
                logger.error(string.format(
                    "餐桌菜品模型超过上限，deskId：%d，guestId：%d，仅展示前 %d 个，多余忽略",
                    deskId, desk.guestId, INN_DESK_FOOD_MAX_MODEL))
                break
            end
            table.insert(result, food)
        end
    end
    return result
end



InnMainHudCtrl._RefreshDeskDishModels = HL.Method(HL.Number) << function(self, deskId)
    if not deskId or deskId <= 0 then
        return
    end
    
    local prevFoodIds = (self.m_deskDishFoodIds and self.m_deskDishFoodIds[deskId]) or {}
    self:_ClearDeskDishModels(deskId)

    if self.m_levelMountPointRoot == nil or self.m_innSystem == nil then
        return
    end

    local foods = self:_CollectDeskFoods(deskId)
    if #foods <= 0 then
        return
    end

    local slotIndex = self:_GetDeskFoodSlotIndex(deskId)
    if slotIndex <= 0 then
        logger.error(string.format("餐桌菜品模型无可用挂点序号（座位未占用），deskId：%d", deskId))
        return
    end

    local _, deskRootNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(CS.Beyond.Gameplay.LevelMountPointType.InnDesk)
    if deskRootNode == nil then
        return
    end
    local deskKey = self.m_innSystem:GetDeskKeyById(deskId)
    local _, deskNode = deskRootNode.children:TryGetValue(deskKey)
    if deskNode == nil then
        logger.error(string.format("未找到餐桌挂点，deskId：%d，挂点key：%s", deskId, deskKey))
        return
    end
    local _, foodNode = deskNode.children:TryGetValue(InnConst.INN_DESK_FOOD_MOUNT_KEY)
    if foodNode == nil then
        logger.error(string.format("未找到餐桌菜品父挂点，deskId：%d，挂点key：%s/%s",
            deskId, deskKey, InnConst.INN_DESK_FOOD_MOUNT_KEY))
        return
    end

    
    
    local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
    local mountKeys = {}
    if #foods == 2 and foods[1].foodType == foods[2].foodType then
        if foods[1].foodType == FOOD_TYPE.FoodTypeDish then
            mountKeys[1] = string.format(InnConst.INN_DESK_DISH_MOUNT_KEY_FMT, 1)
            mountKeys[2] = string.format(InnConst.INN_DESK_DISH_MOUNT_KEY_FMT, 2)
        else
            mountKeys[1] = string.format(InnConst.INN_DESK_DRINK_MOUNT_KEY_FMT, 1)
            mountKeys[2] = string.format(InnConst.INN_DESK_DRINK_MOUNT_KEY_FMT, 2)
        end
    else
        for i, food in ipairs(foods) do
            if food.foodType == FOOD_TYPE.FoodTypeDrink then
                mountKeys[i] = string.format(InnConst.INN_DESK_DRINK_MOUNT_KEY_FMT, slotIndex)
            else
                mountKeys[i] = string.format(InnConst.INN_DESK_DISH_MOUNT_KEY_FMT, slotIndex)
            end
        end
    end

    local models = {}
    local newFoodIds = {}
    for i, food in ipairs(foods) do
        local mountKey = mountKeys[i]
        local _, slotNode = foodNode.children:TryGetValue(mountKey)
        if slotNode == nil then
            logger.error(string.format("未找到餐桌菜品子挂点，deskId：%d，挂点key：%s/%s/%s",
                deskId, deskKey, InnConst.INN_DESK_FOOD_MOUNT_KEY, mountKey))
        else
            local mountPoint = slotNode.mountPoint
            local dishGo = LuaSystemManager.innRootSystem:GetDishModel(food.itemId)
            if dishGo then
                dishGo.transform:SetPositionAndRotation(mountPoint.position, Quaternion.Euler(mountPoint.rotation))
                table.insert(models, dishGo)
                newFoodIds[food.id] = true
                if not prevFoodIds[food.id] then
                    GameInstance.effectManager:CreateStationaryEffect(
                        InnConst.INN_FOOD_APPEAR_EFFECT_ID, mountPoint.position, Quaternion.Euler(mountPoint.rotation))
                end
            end
        end
    end

    if #models > 0 then
        self.m_deskDishModels = self.m_deskDishModels or {}
        self.m_deskDishModels[deskId] = models
        self.m_deskDishFoodIds = self.m_deskDishFoodIds or {}
        self.m_deskDishFoodIds[deskId] = newFoodIds
    end
end


InnMainHudCtrl._ClearDeskDishModels = HL.Method(HL.Number) << function(self, deskId)
    if not self.m_deskDishModels then
        return
    end
    local models = self.m_deskDishModels[deskId]
    if models == nil then
        return
    end
    for _, go in ipairs(models) do
        LuaSystemManager.innRootSystem:ReturnDishModel(go)
    end
    self.m_deskDishModels[deskId] = nil
    if self.m_deskDishFoodIds then
        self.m_deskDishFoodIds[deskId] = nil
    end
end


InnMainHudCtrl._ClearAllDeskDishModels = HL.Method() << function(self)
    self.m_deskDishModels = nil
    self.m_deskDishFoodIds = nil
end

InnMainHudCtrl._RefreshDeskDishModelsByState = HL.Method(HL.Number) << function(self, deskId)
    local DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    local status = nil
    if gameState and gameState.deskStates then
        local _, desk = gameState.deskStates:TryGetValue(deskId)
        if desk then
            status = desk.deskStatus
        end
    end
    if status == DESK_STATUS.DeskStatusEmpty
            or status == DESK_STATUS.DeskStatusLeaving
            or status == DESK_STATUS.DeskStatusOrdering then
        self:_ClearDeskDishModels(deskId)
    end
end







InnMainHudCtrl.m_deskPurseModels = HL.Field(HL.Table)


InnMainHudCtrl._RefreshDeskPurseModel = HL.Method(HL.Number) << function(self, deskId)
    if not deskId or deskId <= 0 then
        return
    end
    self:_ClearDeskPurseModel(deskId)

    if self.m_levelMountPointRoot == nil or self.m_innSystem == nil then
        return
    end

    local DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil then
        return
    end
    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil or desk.deskStatus ~= DESK_STATUS.DeskStatusWaitingForPay then
        return
    end

    local _, deskRootNode = self.m_levelMountPointRoot.subRootByType:TryGetValue(CS.Beyond.Gameplay.LevelMountPointType.InnDesk)
    if deskRootNode == nil then
        return
    end
    local deskKey = self.m_innSystem:GetDeskKeyById(deskId)
    local _, deskNode = deskRootNode.children:TryGetValue(deskKey)
    if deskNode == nil then
        logger.error(string.format("未找到餐桌挂点，deskId：%d，挂点key：%s", deskId, deskKey))
        return
    end
    local _, purseNode = deskNode.children:TryGetValue(InnConst.INN_DESK_PURSE_MOUNT_KEY)
    if purseNode == nil then
        logger.error(string.format("未找到餐桌钱包挂点，deskId：%d，挂点key：%s/%s",
            deskId, deskKey, InnConst.INN_DESK_PURSE_MOUNT_KEY))
        return
    end

    local mountPoint = purseNode.mountPoint
    local purseGo = LuaSystemManager.innRootSystem:GetPurseModel()
    if purseGo then
        purseGo.transform:SetPositionAndRotation(mountPoint.position, Quaternion.Euler(mountPoint.rotation))
        self.m_deskPurseModels = self.m_deskPurseModels or {}
        self.m_deskPurseModels[deskId] = purseGo
    end
end


InnMainHudCtrl._ClearDeskPurseModel = HL.Method(HL.Number) << function(self, deskId)
    if not self.m_deskPurseModels then
        return
    end
    local purseGo = self.m_deskPurseModels[deskId]
    if purseGo == nil then
        return
    end
    LuaSystemManager.innRootSystem:ReturnPurseModel(purseGo)
    self.m_deskPurseModels[deskId] = nil
end


InnMainHudCtrl._ClearAllDeskPurseModels = HL.Method() << function(self)
    self.m_deskPurseModels = nil
end






local RUSH_TICK_SEC = 0.1

local RUSH_INSTRUCTION_BOOK_ID = "inn_management_rush_mode"

local RUSH_DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS

InnMainHudCtrl.m_rushPrevValueK = HL.Field(HL.Number) << -1

InnMainHudCtrl.m_rushPrevInRush = HL.Field(HL.Boolean) << false

InnMainHudCtrl.m_rushProgressTweener = HL.Field(HL.Userdata)

InnMainHudCtrl.m_rushAddHideTimer = HL.Field(HL.Number) << -1

InnMainHudCtrl.m_rushAddValueHideTimer = HL.Field(HL.Number) << -1

InnMainHudCtrl.m_rushModeCoroutine = HL.Field(HL.Thread)

InnMainHudCtrl.m_rushStartTipTimer = HL.Field(HL.Number) << -1

InnMainHudCtrl.m_lastDeskStatusForRushAdd = HL.Field(HL.Table)

InnMainHudCtrl.m_controllerTriggerSettingHandlerId = HL.Field(HL.Number) << -1

InnMainHudCtrl._InitRushMode = HL.Method() << function(self)
    self.m_lastDeskStatusForRushAdd = {}

    if self.view.rushEffect then
        self.view.rushEffect.gameObject:SetActiveIfNecessary(false)
    end

    local rushNode = self.view.rushStateNode
    if rushNode == nil then
        return
    end

    local unlocked = self:_IsRushUnlocked()
    rushNode.gameObject:SetActiveIfNecessary(unlocked)

    if rushNode.rushModeBtn then
        rushNode.rushModeBtn.onClick:AddListener(function()
            self:_OnRushModeBtnClick()
        end)
    end

    if rushNode.tipsBtn then
        rushNode.tipsBtn.onClick:AddListener(function()
            self:_OnRushModeTipsBtnClick()
        end)
    end

    
    if rushNode.matchPerfectAddition then
        rushNode.matchPerfectAddition.gameObject:SetActiveIfNecessary(false)
    end
    if rushNode.rareFoodAddition then
        rushNode.rareFoodAddition.gameObject:SetActiveIfNecessary(false)
    end
    if rushNode.rushAddValueTxt then
        rushNode.rushAddValueTxt.gameObject:SetActiveIfNecessary(false)
    end

    self.m_rushPrevValueK = -1
    self.m_rushPrevInRush = false
    self:_RefreshRushMode(false)
end

InnMainHudCtrl._DestroyRushMode = HL.Method() << function(self)
    if self.m_rushPrevInRush and self.m_innSystem then
        self.m_innSystem:StopMainCharRushMode()
        local rushEffect = self.view.rushEffect
        if rushEffect then
            rushEffect:PlayCloseAudio()
        end
    end
    self.m_lastDeskStatusForRushAdd = nil
    self:_ClearRushTriggerEffect()
    self:_StopRushModeTick()
    self:_ClearRushAddHideTimer()
    self:_ClearRushAddValueHideTimer()
    self:_ClearRushStartTipTimer()
    if self.m_rushProgressTweener then
        self.m_rushProgressTweener:Kill(false)
        self.m_rushProgressTweener = nil
    end
end

InnMainHudCtrl._IsRushUnlocked = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_innSystem == nil then
        return false
    end
    local unlockLevel = Tables.innManagementConst.rushUnlockLevel or 0
    return self.m_innSystem.innLevel >= unlockLevel
end

InnMainHudCtrl._OnRushStateChanged = HL.Method() << function(self)
    self:_RefreshRushMode(true)
end

InnMainHudCtrl._OnRushModeBtnClick = HL.Method() << function(self)
    if self.m_innSystem == nil then
        return
    end
    local rushNode = self.view.rushStateNode
    if rushNode and rushNode.animation then
        rushNode.animation:Play("rushmode_press")
    end
    local stateName = self:_GetRushStateName()
    if stateName == "Full" then
        self.m_innSystem:SendStartRush()  
    end
end

InnMainHudCtrl._OnRushModeTipsBtnClick = HL.Method() << function(self)
    self:_RequestPauseGame(PAUSE_SOURCE_RUSH_TIPS)
end

InnMainHudCtrl._OpenRushInstructionBook = HL.Method() << function(self)
    Utils.ResumeWorldByUI(self.m_rushTipsFreezeHandle)
    self.m_rushTipsFreezeHandle = Utils.FreezeWorldByUI()
    self.m_innSystem.isMainHudShowing = false
    UIManager:Open(PanelId.InstructionBook, {
        id = RUSH_INSTRUCTION_BOOK_ID,
        closeActionId = "inn_rush_mode_tips",
        onClose = function()
            self:_OnRushInstructionBookClosed()
        end,
    })
end

InnMainHudCtrl._OnRushInstructionBookClosed = HL.Method() << function(self)
    if self.m_rushTipsFreezeHandle <= 0 then
        return
    end
    Utils.ResumeWorldByUI(self.m_rushTipsFreezeHandle)
    self.m_rushTipsFreezeHandle = 0
    if self.m_isRushTipsHotSwitching then
        return
    end
    if self.m_innSystem then
        self.m_innSystem:ReleaseManualPauseGame()
        self.m_innSystem.isMainHudShowing = true
    end
end

InnMainHudCtrl._CleanupRushInstructionBook = HL.Method() << function(self)
    if self.m_rushTipsFreezeHandle <= 0 then
        return
    end
    Utils.ResumeWorldByUI(self.m_rushTipsFreezeHandle)
    self.m_rushTipsFreezeHandle = 0
    self.m_isRushTipsHotSwitching = false
    UIManager:Close(PanelId.InstructionBook)
end

InnMainHudCtrl._GetRushStateName = HL.Method().Return(HL.String) << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return "Normal"
    end
    if gameState.isInRushTime then
        return "Rush"
    end
    if gameState.rushValueK >= Tables.innManagementConst.rushSum * 1000 then
        return "Full"
    end
    return "Normal"
end


InnMainHudCtrl._GetComboStateName = HL.Method(HL.Number).Return(HL.String) << function(self, comboCount)
    local const = Tables.innManagementConst
    if comboCount >= const.rushAddThirdStage then
        return "Red"
    elseif comboCount >= const.rushAddSecondStage then
        return "Yellow"
    elseif comboCount >= const.rushAddFirstStage then
        return "Green"
    end
    return "White"
end


InnMainHudCtrl._RefreshRushMode = HL.Method(HL.Boolean) << function(self, fromUpdate)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    self:_RefreshRushTriggerEffect()

    if self.view.comboStateNode then
        self.view.comboStateNode.stateController:SetState(self:_GetComboStateName(gameState.comboCount))
        self.view.comboStateNode.comboNumTxt.text = tostring(gameState.comboCount)
    end

    local rushNode = self.view.rushStateNode
    if rushNode == nil or not self:_IsRushUnlocked() then
        return
    end

    local rushFullValueK = math.max(1, Tables.innManagementConst.rushSum * 1000)
    local stateName = self:_GetRushStateName()
    if rushNode.stateController then
        rushNode.stateController:SetState(stateName)
    end

    if rushNode.rushValueTxt then
        rushNode.rushValueTxt.text = string.format("%d/%d",
            math.floor(gameState.rushValueK / 1000), Tables.innManagementConst.rushSum)
    end
    local progress = lume.clamp(gameState.rushValueK / rushFullValueK, 0, 1)
    if rushNode.progress then
        rushNode.progress.fillAmount = progress
    end
    if rushNode.progressTween then
        if self.m_rushProgressTweener then
            self.m_rushProgressTweener:Kill(false)
            self.m_rushProgressTweener = nil
        end
        local function setTweenProgress(value)
            rushNode.progressTween.fillAmount = value
            if rushNode.progressGlow then
                rushNode.progressGlow.fillAmount = value
            end
        end
        if not fromUpdate or self.m_rushPrevValueK < 0 or gameState.isInRushTime or self.m_rushPrevInRush then
            setTweenProgress(progress)
        else
            local tweenTime = self.view.config.RUSH_VALUE_TWEEN_TIME or 0
            if tweenTime > 0 then
                self.m_rushProgressTweener = rushNode.progressTween:DOFillAmount(progress, tweenTime):OnUpdate(function()
                    if rushNode.progressGlow then
                        rushNode.progressGlow.fillAmount = rushNode.progressTween.fillAmount
                    end
                end)
                if rushNode.progressGlowAnimationWrapper then
                    rushNode.progressGlowAnimationWrapper:PlayInAnimation()
                end
            else
                setTweenProgress(progress)
            end
        end
    end

    
    
    if rushNode.rushAddValueTxt then
        if gameState.isInRushTime then
            self:_ClearRushAddValueHideTimer()
            rushNode.rushAddValueTxt.gameObject:SetActiveIfNecessary(false)
        elseif fromUpdate
            and self.m_rushPrevValueK >= 0
            and gameState.rushValueK > self.m_rushPrevValueK then
            local addValue = math.floor(gameState.rushValueK / 1000) - math.floor(self.m_rushPrevValueK / 1000)
            if addValue > 0 then
                rushNode.rushAddValueTxt.text = string.format("+%d", addValue)
                UIUtils.PlayAnimationAndToggleActive(rushNode.rushAddValueTxtAnimationWrapper, true)
                self:_ClearRushAddValueHideTimer()
                local stayTime = self.view.config.RUSH_VALUE_ADD_STAY_TIME or 0
                if stayTime > 0 then
                    self.m_rushAddValueHideTimer = self:_StartTimer(stayTime, function()
                        self.m_rushAddValueHideTimer = -1
                        if self.view.rushStateNode and self.view.rushStateNode.rushAddValueTxt then
                            UIUtils.PlayAnimationAndToggleActive(rushNode.rushAddValueTxtAnimationWrapper, false)
                        end
                    end)
                end
            end
        end
    end

    if gameState.isInRushTime and not self.m_rushPrevInRush then
        self:_HideRushAdditionAll()
        self.m_innSystem:PlayMainCharRushMode()
        GameAction.PostMusicEvent("au_music_map02_lv010_innmanagement_fever", CS.Beyond.Gameplay.Audio.AudioMusicSystem.EMusicEventPreAction.NORMAL)
        if self.view.rushEffect then
            UIUtils.PlayAnimationAndToggleActive(self.view.rushEffect, true)
        end
        if fromUpdate then
            self:_ShowRushStartTip()
        end
    elseif not gameState.isInRushTime and self.m_rushPrevInRush then
        self:_ClearRushStartTipTimer()
        self.m_innSystem:StopMainCharRushMode()
        GameAction.PostMusicEvent("au_music_map02_lv010_innmanagement_start", CS.Beyond.Gameplay.Audio.AudioMusicSystem.EMusicEventPreAction.NORMAL)
        if self.view.rushEffect then
            UIUtils.PlayAnimationAndToggleActive(self.view.rushEffect, false)
        end
        UIUtils.PlayAnimationAndToggleActive(rushNode.hotingLayout, false)
    end

    if gameState.isInRushTime then
        self:_StartRushModeTick()
    else
        self:_StopRushModeTick()
        if rushNode.rushModeProgess then
            rushNode.rushModeProgess.fillAmount = 0
        end
        if rushNode.rushModeDurationTxt then
            rushNode.rushModeDurationTxt.text = ""
        end
    end

    self.m_rushPrevValueK = gameState.rushValueK
    self.m_rushPrevInRush = gameState.isInRushTime
end

InnMainHudCtrl._RefreshRushTriggerEffect = HL.Method() << function(self)
    local needEffect = DeviceInfo.usingController and not DeviceInfo.isMobile
        and self:IsShow() and self:_IsRushUnlocked() and self:_GetRushStateName() == "Full"
    if not needEffect then
        self:_ClearRushTriggerEffect()
        return
    end
    if self.m_controllerTriggerSettingHandlerId >= 0 then
        return
    end
    local cfg = self.view.psTriggerEffectCfg
    if cfg == nil or cfg.commands == nil or cfg.commands.Count <= 0 then
        return
    end
    self.m_controllerTriggerSettingHandlerId = GameInstance.audioManager.gamePad.scePad:SetTriggerEffect(cfg.commands[0])
end

InnMainHudCtrl._ClearRushTriggerEffect = HL.Method() << function(self)
    if self.m_controllerTriggerSettingHandlerId >= 0 then
        GameInstance.audioManager.gamePad.scePad:EndTriggerEffect(self.m_controllerTriggerSettingHandlerId)
        self.m_controllerTriggerSettingHandlerId = -1
    end
end

InnMainHudCtrl._StartRushModeTick = HL.Method() << function(self)
    if self.m_rushModeCoroutine ~= nil then
        return
    end
    self:_RefreshRushModeProgress()
    self.m_rushModeCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(RUSH_TICK_SEC)
            self:_RefreshRushModeProgress()
        end
    end)
end

InnMainHudCtrl._StopRushModeTick = HL.Method() << function(self)
    if self.m_rushModeCoroutine ~= nil then
        self.m_rushModeCoroutine = self:_ClearCoroutine(self.m_rushModeCoroutine)
    end
end



InnMainHudCtrl._RefreshRushModeProgress = HL.Method() << function(self)
    local rushNode = self.view.rushStateNode
    if rushNode == nil then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil or not gameState.isInRushTime or gameState.isPaused then
        return
    end

    local rushFullValueK = math.max(1, Tables.innManagementConst.rushSum * 1000)
    local consumeRate = Tables.innManagementConst.rushConsumeRate

    
    local nowMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
    local elapsedMs = math.max(0, nowMs - gameState.rushLastTs)
    local currentValueK = math.max(0, gameState.rushValueK - consumeRate * elapsedMs)

    if rushNode.rushModeDurationTxt then
        local leftSec = consumeRate > 0 and (currentValueK / (consumeRate * 1000)) or 0
        rushNode.rushModeDurationTxt.text = UIUtils.getLeftTimeToSecond(leftSec)
    end
    if rushNode.rushModeProgess then
        rushNode.rushModeProgess.fillAmount = lume.clamp(1 - currentValueK / rushFullValueK, 0, 1)
    end
end



InnMainHudCtrl._TryShowRushAdditionsOnEating = HL.Method(HL.Number) << function(self, deskId)
    if self.m_lastDeskStatusForRushAdd == nil then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil then
        return
    end
    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil then
        return
    end

    local prevStatus = self.m_lastDeskStatusForRushAdd[deskId] or RUSH_DESK_STATUS.DeskStatusEmpty
    local newStatus = desk.deskStatus
    self.m_lastDeskStatusForRushAdd[deskId] = newStatus

    if newStatus ~= RUSH_DESK_STATUS.DeskStatusEating or prevStatus == RUSH_DESK_STATUS.DeskStatusEating then
        return
    end
    self:_ShowRushAdditionsForEating(deskId)
end





InnMainHudCtrl._ShowRushAdditionsForEating = HL.Method(HL.Number) << function(self, deskId)
    local rushNode = self.view.rushStateNode
    if rushNode == nil or not self:_IsRushUnlocked() then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end

    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil or desk.guestId == 0 then
        return
    end
    local hasGuest, guest = gameState.guestStates:TryGetValue(desk.guestId)
    if not hasGuest or guest == nil then
        return
    end

    local GUEST_TYPE = CS.Proto.INN_MANAGEMENT_GUEST_TYPE
    local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel

    local matchPerfect = false
    if guest.guestType == GUEST_TYPE.GuestTypeSpecial
        and guest.matches and guest.matches.Count > 0 then
        matchPerfect = true
        for i = 0, guest.matches.Count - 1 do
            if guest.matches[i] ~= MATCH_LEVEL.Perfect then
                matchPerfect = false
                break
            end
        end
    end

    local hasRareFood = false
    if guest.gotFoodIds then
        for i = 0, guest.gotFoodIds.Count - 1 do
            local foodId = guest.gotFoodIds[i]
            local hasFood, food = gameState.foods:TryGetValue(foodId)
            if hasFood and food and food.isRare then
                hasRareFood = true
                break
            end
        end
    end

    if not matchPerfect and not hasRareFood then
        return
    end

    if rushNode.matchPerfectAddition then
        UIUtils.PlayAnimationAndToggleActive(rushNode.matchPerfectAddition, matchPerfect)
    end
    if rushNode.rareFoodAddition then
        UIUtils.PlayAnimationAndToggleActive(rushNode.rareFoodAddition, hasRareFood)
    end

    self:_ClearRushAddHideTimer()
    local stayTime = self.view.config.RUSH_ADDITION_STAY_TIME or 0
    if stayTime > 0 then
        self.m_rushAddHideTimer = self:_StartTimer(stayTime, function()
            self.m_rushAddHideTimer = -1
            self:_HideRushAdditionAll()
        end)
    end
end

InnMainHudCtrl._HideRushAdditionAll = HL.Method() << function(self)
    self:_ClearRushAddHideTimer()
    local rushNode = self.view.rushStateNode
    if rushNode == nil then
        return
    end
    if rushNode.matchPerfectAddition then
        UIUtils.PlayAnimationAndToggleActive(rushNode.matchPerfectAddition, false)
    end
    if rushNode.rareFoodAddition then
        UIUtils.PlayAnimationAndToggleActive(rushNode.rareFoodAddition, false)
    end
end

InnMainHudCtrl._ClearRushAddHideTimer = HL.Method() << function(self)
    if self.m_rushAddHideTimer and self.m_rushAddHideTimer > 0 then
        self:_ClearTimer(self.m_rushAddHideTimer)
        self.m_rushAddHideTimer = -1
    end
end

InnMainHudCtrl._ClearRushAddValueHideTimer = HL.Method() << function(self)
    if self.m_rushAddValueHideTimer and self.m_rushAddValueHideTimer > 0 then
        self:_ClearTimer(self.m_rushAddValueHideTimer)
        self.m_rushAddValueHideTimer = -1
    end
end

InnMainHudCtrl._ShowRushStartTip = HL.Method() << function(self)
    self:_ClearRushStartTipTimer()
    local rushNode = self.view.rushStateNode
    if rushNode == nil or rushNode.hotingLayout == nil then
        return
    end
    rushNode.hotingLayout.gameObject:SetActiveIfNecessary(false)
    local stayTime = self.view.config.RUSH_MODE_START_TIP_STAY_TIME or 0
    if stayTime <= 0 then
        self:_SwitchToHotingLayout()
        return
    end
    UIUtils.PlayAnimationAndToggleActive(rushNode.hotingTipsLayout, true)
    self.m_rushStartTipTimer = self:_StartTimer(stayTime, function()
        self.m_rushStartTipTimer = -1
        if self.m_rushPrevInRush then
            self:_SwitchToHotingLayout()
        end
    end)
end

InnMainHudCtrl._SwitchToHotingLayout = HL.Method() << function(self)
    local rushNode = self.view.rushStateNode
    if rushNode == nil then
        return
    end
    if rushNode.hotingTipsLayout then
        UIUtils.PlayAnimationAndToggleActive(rushNode.hotingTipsLayout, false)
    end
    if rushNode.hotingLayout then
        UIUtils.PlayAnimationAndToggleActive(rushNode.hotingLayout, true)
    end
end

InnMainHudCtrl._ClearRushStartTipTimer = HL.Method() << function(self)
    if self.m_rushStartTipTimer and self.m_rushStartTipTimer > 0 then
        self:_ClearTimer(self.m_rushStartTipTimer)
        self.m_rushStartTipTimer = -1
    end
end





InnMainHudCtrl.m_moneyCellHideTimer = HL.Field(HL.Number) << -1





InnMainHudCtrl._InitStatistics = HL.Method() << function(self)
    local statisticsNode = self.view.statisticsNode
    if not statisticsNode then
        return
    end

    local gameState = self.m_innSystem and self.m_innSystem.gameState
    statisticsNode.gameObject:SetActiveIfNecessary(gameState ~= nil)
    if gameState == nil then
        return
    end

    self:_RefreshStatisticsNumbers()
    self:_HideMoneyCell()
end

InnMainHudCtrl._RefreshStatisticsNumbers = HL.Method() << function(self)
    local statisticsNode = self.view.statisticsNode
    if not statisticsNode then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    local stats = gameState and gameState.statistics
    if stats == nil then
        return
    end

    if statisticsNode.incomeNumTxt then
        statisticsNode.incomeNumTxt.text = tostring(stats.totalIncome)
    end
    if statisticsNode.receptionNumTxt then
        statisticsNode.receptionNumTxt.text = tostring(stats.servedDeskCount)
    end
    if statisticsNode.soldNumTxt then
        statisticsNode.soldNumTxt.text = tostring(stats.soldFoodCount)
    end
end

InnMainHudCtrl._OnStatisticsChanged = HL.Method() << function(self)
    self:_RefreshStatisticsNumbers()
end

InnMainHudCtrl._OnDeskCheckOut = HL.Method(HL.Table) << function(self, args)
    local deskId, baseMoney, tipMoney = unpack(args)

    
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState and gameState.isEndingGame then
        return
    end

    self:_ShowCheckoutMoney(baseMoney or 0, tipMoney or 0)
end

InnMainHudCtrl._ShowCheckoutMoney = HL.Method(HL.Number, HL.Number) << function(self, baseMoney, tipMoney)
    local statisticsNode = self.view.statisticsNode
    if not statisticsNode then
        return
    end

    if statisticsNode.baseMoneyNumTxt then
        statisticsNode.baseMoneyNumTxt.text = string.format("+%d", baseMoney)
    end
    if statisticsNode.tipMoneyNumTxt then
        statisticsNode.tipMoneyNumTxt.text = string.format("+%d", tipMoney)
    end

    self:_ShowMoneyCell(baseMoney, tipMoney)

    self:_ClearMoneyCellHideTimer()
    local showTime = self.view.config and self.view.config.MONEY_SHOW_TIME or 0
    if showTime > 0 and (baseMoney ~= 0 or tipMoney ~= 0) then
        self.m_moneyCellHideTimer = self:_StartTimer(showTime, function()
            self.m_moneyCellHideTimer = -1
            self:_HideMoneyCell()
        end)
    end
end

InnMainHudCtrl._OnEndingCheckoutMoney = HL.Method(HL.Table) << function(self, args)
    local baseMoney, tipMoney = unpack(args)
    self:_ShowCheckoutMoney(baseMoney or 0, tipMoney or 0)
end

InnMainHudCtrl._ShowMoneyCell = HL.Method(HL.Number, HL.Number) << function(self, baseMoney, tipMoney)
    local statisticsNode = self.view.statisticsNode
    if not statisticsNode then
        return
    end
    if statisticsNode.baseMoneyNode then
        statisticsNode.baseMoneyNode.gameObject:SetActiveIfNecessary(baseMoney ~= 0)
    end
    if statisticsNode.tipMoneyNode then
        statisticsNode.tipMoneyNode.gameObject:SetActiveIfNecessary(tipMoney ~= 0)
    end
    if statisticsNode.moneyCell then
        local isOn = baseMoney ~= 0 or tipMoney ~= 0
        if isOn and statisticsNode.moneyCell.gameObject.activeSelf then
            statisticsNode.moneyCell:ClearTween(false)
            statisticsNode.moneyCell:PlayInAnimation()
        else
            UIUtils.PlayAnimationAndToggleActive(statisticsNode.moneyCell, isOn)
        end
    end
end

InnMainHudCtrl._HideMoneyCell = HL.Method() << function(self)
    local statisticsNode = self.view.statisticsNode
    if not statisticsNode then
        return
    end
    if statisticsNode.moneyCell then
        UIUtils.PlayAnimationAndToggleActive(statisticsNode.moneyCell, false)
    end
end

InnMainHudCtrl._ClearMoneyCellHideTimer = HL.Method() << function(self)
    if self.m_moneyCellHideTimer and self.m_moneyCellHideTimer > 0 then
        self:_ClearTimer(self.m_moneyCellHideTimer)
        self.m_moneyCellHideTimer = -1
    end
end





InnMainHudCtrl._InitRadio = HL.Method() << function(self)
    local radioNode = self.view.topNode and self.view.topNode.keeperInfoNode.radioNode
    if radioNode == nil then
        return
    end
    
    radioNode.gameObject:SetActiveIfNecessary(false)
end


InnMainHudCtrl.ShowRadio = HL.Method(HL.Userdata).Return(HL.Number) << function(self, radioSingleData)
    local keeperInfoNode = self.view.topNode and self.view.topNode.keeperInfoNode
    if keeperInfoNode == nil or keeperInfoNode.radioNode == nil then
        return 0
    end

    if radioSingleData == nil then
        self:HideRadio()
        return 0
    end

    local radioText = UIUtils.resolveTextCinematic(radioSingleData.radioText)

    UIUtils.PlayAnimationAndToggleActive(keeperInfoNode.radioNode, true)
    if keeperInfoNode.radioTxt == nil then
        return 0
    end

    keeperInfoNode.radioTxt:SetAndResolveTextStyle(radioText)
    keeperInfoNode.radioTxt:ForceMeshUpdate()
    return keeperInfoNode.radioTxt.textInfo.characterCount
end

InnMainHudCtrl.HideRadio = HL.Method() << function(self)
    local keeperInfoNode = self.view.topNode and self.view.topNode.keeperInfoNode
    if keeperInfoNode == nil or keeperInfoNode.radioNode == nil then
        return
    end
    UIUtils.PlayAnimationAndToggleActive(keeperInfoNode.radioNode, false)
end





local AUTO_DUTY_TYPE = GEnums.JsspsiDutyType
local INN_FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE



local AUTO_DUTY_ORDER = {
    AUTO_DUTY_TYPE.ServeDish,
    AUTO_DUTY_TYPE.ServeDrink,
    AUTO_DUTY_TYPE.Checkout,
}

InnMainHudCtrl.m_skillStateCellCache = HL.Field(HL.Forward("UIListCache"))


InnMainHudCtrl.m_skillDutyTypes = HL.Field(HL.Table)

InnMainHudCtrl.m_pendingAutoServeCompletes = HL.Field(HL.Table)

InnMainHudCtrl.m_pendingAutoCheckoutCompletes = HL.Field(HL.Table)

InnMainHudCtrl._InitAutoService = HL.Method() << function(self)
    local keeperInfoNode = self.view.topNode and self.view.topNode.keeperInfoNode
    if keeperInfoNode == nil then
        return
    end

    keeperInfoNode.ownerCharNode:InitInnOwnerCharNode()

    if keeperInfoNode.workingStateNode then
        keeperInfoNode.workingStateNode.gameObject:SetActiveIfNecessary(self:_IsAnyJsspsiDutyUnlocked())
    end

    self:_RefreshAutoServiceSkillCells()
    self:_RefreshAutoServiceState()
end

InnMainHudCtrl._IsAnyJsspsiDutyUnlocked = HL.Method().Return(HL.Boolean) << function(self)
    local unlockMap = self.m_innSystem and self.m_innSystem.jsspsiDutyUnlockInnLevel
    if unlockMap == nil then
        return false
    end
    local innLevel = self.m_innSystem.innLevel or 0
    for _, unlockLevel in pairs(unlockMap) do
        if innLevel >= (unlockLevel or 0) then
            return true
        end
    end
    return false
end



InnMainHudCtrl._RefreshAutoServiceSkillCells = HL.Method() << function(self)
    local keeperInfoNode = self.view.topNode and self.view.topNode.keeperInfoNode
    if keeperInfoNode == nil or keeperInfoNode.skillStateCell == nil then
        return
    end

    local autoDuty = self.m_innSystem and self.m_innSystem.gameSetting and self.m_innSystem.gameSetting.autoDuty
    local dutyTypes = {}
    if autoDuty ~= nil then
        for _, dutyType in ipairs(AUTO_DUTY_ORDER) do
            local has, isOn = autoDuty:TryGetValue(dutyType)
            if has and isOn then
                dutyTypes[#dutyTypes + 1] = dutyType
            end
        end
    end
    self.m_skillDutyTypes = dutyTypes

    self.m_skillStateCellCache = self.m_skillStateCellCache or UIUtils.genCellCache(keeperInfoNode.skillStateCell)
    self.m_skillStateCellCache:Refresh(#dutyTypes, function(cell, index)
        local dutyType = dutyTypes[index]
        if cell.iconSkill then
            local iconId = InnConst.INN_AUTO_DUTY_ICON_ID[dutyType]
            if iconId then
                cell.iconSkill:LoadSprite(UIConst.UI_SPRITE_INN_AUTO, iconId)
            end
        end
    end)
end




InnMainHudCtrl._GetCurrentAutoServingDuty = HL.Method().Return(HL.Any, HL.Number) << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return nil, 0
    end
    if (gameState.autoCheckoutDeskId or 0) > 0 then
        return AUTO_DUTY_TYPE.Checkout, gameState.autoCheckoutDeskId
    end
    if (gameState.autoServeFoodId or 0) > 0 and (gameState.autoServeFoodDeskId or 0) > 0 then
        local hasFood, food = gameState.foods:TryGetValue(gameState.autoServeFoodId)
        if hasFood and food then
            local dutyType = food.foodType == INN_FOOD_TYPE.FoodTypeDrink
                and AUTO_DUTY_TYPE.ServeDrink
                or AUTO_DUTY_TYPE.ServeDish
            return dutyType, gameState.autoServeFoodDeskId
        end
    end
    return nil, 0
end





InnMainHudCtrl._RefreshAutoServiceState = HL.Method() << function(self)
    local keeperInfoNode = self.view.topNode and self.view.topNode.keeperInfoNode
    if keeperInfoNode == nil then
        return
    end

    local servingDuty, deskId = self:_GetCurrentAutoServingDuty()

    if self.m_skillStateCellCache and self.m_skillDutyTypes then
        for i = 1, self.m_skillStateCellCache:GetCount() do
            local cell = self.m_skillStateCellCache:GetItem(i)
            if cell and cell.stateController then
                local cellDuty = self.m_skillDutyTypes[i]
                local stateName = (cellDuty ~= nil and servingDuty == cellDuty) and "Serving" or "Normal"
                cell.stateController:SetState(stateName)
            end
        end
    end

    if keeperInfoNode.workingStateNode then
        keeperInfoNode.workingStateNode:SetState(servingDuty ~= nil and "Working" or "Standby")
    end

    if servingDuty ~= nil then
        if keeperInfoNode.deskNumImg and deskId > 0 then
            keeperInfoNode.deskNumImg:LoadSprite(UIConst.UI_SPRITE_INN_DESK_NUM,
                string.format("icon_table_num%d", deskId))
        end
        if keeperInfoNode.workingTxt then
            local txt
            if servingDuty == AUTO_DUTY_TYPE.ServeDrink then
                txt = Language.LUA_INN_MAIN_HUD_KEEPER_SERVING_DRINK
            elseif servingDuty == AUTO_DUTY_TYPE.ServeDish then
                txt = Language.LUA_INN_MAIN_HUD_KEEPER_SERVING_DISH
            else
                txt = Language.LUA_INN_MAIN_HUD_KEEPER_CHECKOUT
            end
            keeperInfoNode.workingTxt.text = txt
        end
    end
end

InnMainHudCtrl._OnAutoServeFoodChanged = HL.Method() << function(self)
    self:_RefreshAutoServiceState()
    self:_HandleAutoServeTrigger()
end

InnMainHudCtrl._OnAutoCheckoutChanged = HL.Method() << function(self)
    self:_RefreshAutoServiceState()
    self:_HandleAutoCheckoutTrigger()
end

InnMainHudCtrl._HandleAutoServeTrigger = HL.Method() << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    local foodId = gameState.autoServeFoodId or 0
    local deskId = gameState.autoServeFoodDeskId or 0
    if foodId <= 0 or deskId <= 0 then
        return
    end

    local innSystem = self.m_innSystem
    local itemId = ""
    local hasFood, food = gameState.foods:TryGetValue(foodId)
    if hasFood and food then
        itemId = food.itemId
    end
    LuaSystemManager.innNpcSystem:PlayOwnerAutoServe(itemId, deskId, function()
        if innSystem ~= nil and innSystem.gameState and not innSystem.gameState.isEndingGame then
            if self:_IsInnPausedOnServer() then
                if self.m_pendingAutoServeCompletes == nil then
                    self.m_pendingAutoServeCompletes = {}
                end
                self.m_pendingAutoServeCompletes[foodId .. "_" .. deskId] = { foodId = foodId, deskId = deskId }
                logger.important(CS.Beyond.EnableLogType.DevOnly, string.format("[InnMainHud] 游戏暂停中, 缓存自动上菜完成 foodId=%d deskId=%d", foodId, deskId))
            else
                innSystem:SendServerFoodComplete(foodId, deskId, true)
            end
        end
    end)
end

InnMainHudCtrl._HandleAutoCheckoutTrigger = HL.Method() << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end
    local deskId = gameState.autoCheckoutDeskId or 0
    if deskId <= 0 then
        return
    end

    local innSystem = self.m_innSystem
    LuaSystemManager.innNpcSystem:PlayOwnerAutoCheckout(deskId, function()
        if innSystem ~= nil and self.m_innSystem.gameState and not self.m_innSystem.gameState.isEndingGame then
            if self:_IsInnPausedOnServer() then
                if self.m_pendingAutoCheckoutCompletes == nil then
                    self.m_pendingAutoCheckoutCompletes = {}
                end
                self.m_pendingAutoCheckoutCompletes[deskId] = deskId
                logger.important(CS.Beyond.EnableLogType.DevOnly, string.format("[InnMainHud] 游戏暂停中, 缓存自动结账完成 deskId=%d", deskId))
            else
                innSystem:SendCheckoutComplete(deskId, true)
            end
        end
    end)
end

InnMainHudCtrl._IsInnPausedOnServer = HL.Method().Return(HL.Boolean) << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return false
    end
    return gameState.isPaused or gameState.isManualPauseHeld or gameState.isScriptPauseHeld
end

InnMainHudCtrl._FlushPendingAutoCompletes = HL.Method() << function(self)
    local innSystem = self.m_innSystem
    local gameState = innSystem and innSystem.gameState
    if gameState == nil or gameState.isEndingGame then
        self.m_pendingAutoServeCompletes = nil
        self.m_pendingAutoCheckoutCompletes = nil
        return
    end
    if self:_IsInnPausedOnServer() then
        return
    end

    if self.m_pendingAutoServeCompletes then
    for _, item in pairs(self.m_pendingAutoServeCompletes) do
            logger.important(CS.Beyond.EnableLogType.DevOnly, string.format("[InnMainHud] 游戏恢复, 补发自动上菜完成 foodId=%d deskId=%d", item.foodId, item.deskId))
            innSystem:SendServerFoodComplete(item.foodId, item.deskId, true)
        end
        self.m_pendingAutoServeCompletes = nil
    end

    if self.m_pendingAutoCheckoutCompletes then
        for _, deskId in pairs(self.m_pendingAutoCheckoutCompletes) do
            logger.important(CS.Beyond.EnableLogType.DevOnly, string.format("[InnMainHud] 游戏恢复, 补发自动结账完成 deskId=%d", deskId))
            innSystem:SendCheckoutComplete(deskId, true)
        end
        self.m_pendingAutoCheckoutCompletes = nil
    end
end





InnMainHudCtrl.m_topicCondId = HL.Field(HL.String) << ""

InnMainHudCtrl.m_topicMaxProgress = HL.Field(HL.Number) << 0

InnMainHudCtrl.m_topicProgress = HL.Field(HL.Number) << 0

InnMainHudCtrl.m_topicFinished = HL.Field(HL.Boolean) << false

InnMainHudCtrl.m_topicTipCellCache = HL.Field(HL.Forward("UIListCache"))

InnMainHudCtrl._InitTopic = HL.Method() << function(self)
    local topicNode = self.view.topicNode
    if topicNode == nil then
        return
    end

    local topicData
    local topicId = self.m_innSystem and self.m_innSystem.gameSetting and self.m_innSystem.gameSetting.topicId
    if topicId and not string.isEmpty(topicId) then
        local hasTopic, data = Tables.innTopicTable:TryGetValue(topicId)
        if hasTopic then
            topicData = data
        end
    end

    topicNode.gameObject:SetActiveIfNecessary(true)

    if topicNode.topicTitleTxt then
        if topicData then
            topicNode.topicTitleTxt.text = topicData.name or ""
        else
            topicNode.topicTitleTxt.text = Language.LUA_INN_TOPIC_NONE_TITLE
        end
    end

    self:_RefreshTopicTips(topicData)

    local objectiveNode = topicNode.objectiveNode
    local objectiveDesc = topicData and topicData.objectiveDesc
    local hasObjective = not string.isEmpty(objectiveDesc)
    if objectiveNode then
        objectiveNode.gameObject:SetActiveIfNecessary(hasObjective)
    end

    self.m_topicCondId = ""
    self.m_topicMaxProgress = 0
    self.m_topicProgress = 0
    self.m_topicFinished = false
    if not hasObjective then
        return
    end

    self.m_topicCondId = topicData.objectiveConditionId
    self.m_topicMaxProgress = topicData.oProgressToCompare or 0

    local objectiveCell = topicNode.objectiveCell
    if objectiveCell and objectiveCell.goalTxt then
        objectiveCell.goalTxt:SetAndResolveTextStyle(objectiveDesc)
    end

    self:_RefreshTopicObjective(true)
end

InnMainHudCtrl._RefreshTopicTips = HL.Method(HL.Opt(HL.Any)) << function(self, topicData)
    local topicNode = self.view.topicNode
    local objectiveTipNode = topicNode and topicNode.objectiveTipNode
    local objectiveTipCell = topicNode and topicNode.objectiveTipCell
    if objectiveTipNode == nil or objectiveTipCell == nil then
        return
    end

    local tips = {}
    if topicData then
        if not string.isEmpty(topicData.objectiveTip1) then
            tips[#tips + 1] = topicData.objectiveTip1
        end
        if not string.isEmpty(topicData.objectiveTip2) then
            tips[#tips + 1] = topicData.objectiveTip2
        end
    else
        tips[#tips + 1] = Language.LUA_INN_MAIN_HUD_TOPIC_NONE_TIP_1
        tips[#tips + 1] = Language.LUA_INN_MAIN_HUD_TOPIC_NONE_TIP_2
    end

    objectiveTipNode.gameObject:SetActiveIfNecessary(#tips > 0)

    self.m_topicTipCellCache = self.m_topicTipCellCache or UIUtils.genCellCache(objectiveTipCell)
    self.m_topicTipCellCache:Refresh(#tips, function(cell, index)
        if cell.goalTxt then
            cell.goalTxt:SetAndResolveTextStyle(tips[index])
        end
        if cell.animationWrapper then
            cell.animationWrapper:Play("tasktrackhud_celldefault")
        end
    end)
end

InnMainHudCtrl._RefreshTopicObjective = HL.Method(HL.Boolean) << function(self, isInit)
    local topicNode = self.view.topicNode
    local objectiveCell = topicNode and topicNode.objectiveCell
    if objectiveCell == nil then
        return
    end
    if string.isEmpty(self.m_topicCondId) then
        return
    end

    local value = 0
    local finished = false
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState then
        local has, cond = gameState.topicObjectiveConditions:TryGetValue(self.m_topicCondId)
        if has and cond then
            value = cond.value
            finished = cond.flag
        end
    end

    if objectiveCell.progressTxt then
        objectiveCell.progressTxt.text = string.format("%d/%d", value, self.m_topicMaxProgress)
    end

    local animWrapper = objectiveCell.animationWrapper
    if animWrapper then
        if isInit then
            animWrapper:Play("tasktrackhud_celldefault")
        elseif finished and not self.m_topicFinished then
            animWrapper:Play("tasktrackhud_cellfinish")
        elseif value ~= self.m_topicProgress then
            animWrapper:Play("tasktrackhud_cellupdate")
        end
    end

    self.m_topicProgress = value
    self.m_topicFinished = finished
end

InnMainHudCtrl._OnTopicObjectiveProgressChange = HL.Method() << function(self)
    self:_RefreshTopicObjective(false)
end





InnMainHudCtrl.m_serveFoodHideTimer = HL.Field(HL.Number) << -1

InnMainHudCtrl._InitServeFood = HL.Method() << function(self)
    local serveFoodNode = self.view.serveFoodNode
    if serveFoodNode == nil then
        return
    end
    serveFoodNode.gameObject:SetActiveIfNecessary(false)
end

InnMainHudCtrl._ShowServeFood = HL.Method(HL.String, HL.Boolean) << function(self, itemId, isRare)
    local serveFoodNode = self.view.serveFoodNode
    if serveFoodNode == nil then
        return
    end

    if serveFoodNode.itemIcon then
        serveFoodNode.itemIcon:InitItemIcon(itemId)
    end
    if serveFoodNode.stateController then
        serveFoodNode.stateController:SetState(isRare and "Rare" or "Normal")
    end
    local animWrapper = serveFoodNode.animationWrapper
    if animWrapper then
        if serveFoodNode.gameObject.activeSelf then
            animWrapper:ClearTween(false)
            animWrapper:PlayInAnimation()
        else
            UIUtils.PlayAnimationAndToggleActive(animWrapper, true)
        end
    else
        serveFoodNode.gameObject:SetActiveIfNecessary(true)
    end

    self:_ClearServeFoodHideTimer()
    local stayTime = self.view.config and self.view.config.SERVE_FOOD_STAY_TIME or 0
    if stayTime > 0 then
        self.m_serveFoodHideTimer = self:_StartTimer(stayTime, function()
            self.m_serveFoodHideTimer = -1
            self:_HideServeFood()
        end)
    end
end

InnMainHudCtrl._HideServeFood = HL.Method() << function(self)
    local serveFoodNode = self.view.serveFoodNode
    if serveFoodNode == nil then
        return
    end
    local animWrapper = serveFoodNode.animationWrapper
    if animWrapper then
        UIUtils.PlayAnimationAndToggleActive(animWrapper, false)
    else
        serveFoodNode.gameObject:SetActiveIfNecessary(false)
    end
end

InnMainHudCtrl._ClearServeFoodHideTimer = HL.Method() << function(self)
    if self.m_serveFoodHideTimer and self.m_serveFoodHideTimer > 0 then
        self:_ClearTimer(self.m_serveFoodHideTimer)
        self.m_serveFoodHideTimer = -1
    end
end


 


local NPC_HUD_DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS



InnMainHudCtrl.m_guestHudGroups = HL.Field(HL.Table)


InnMainHudCtrl.m_lastDeskStatusForNpc = HL.Field(HL.Table)


InnMainHudCtrl.m_lastDeskGuestIdForNpc = HL.Field(HL.Table)

InnMainHudCtrl._InitNpcHuds = HL.Method() << function(self)
    self.m_guestHudGroups = {}
    self.m_lastDeskStatusForNpc = {}
    self.m_lastDeskGuestIdForNpc = {}
end


InnMainHudCtrl._DestroyGuestHuds = HL.Method() << function(self)
    if self.m_guestHudGroups then
        for _, group in pairs(self.m_guestHudGroups) do
            if group and group.timerId and group.timerId > 0 then
                self:_ClearTimer(group.timerId)
            end
        end
    end
    self.m_guestHudGroups = nil
    self.m_lastDeskStatusForNpc = nil
    self.m_lastDeskGuestIdForNpc = nil
end


InnMainHudCtrl._ClearGuestHudsForDesk = HL.Method(HL.Number) << function(self, deskId)
    if not self.m_guestHudGroups then
        return
    end
    local group = self.m_guestHudGroups[deskId]
    if not group then
        return
    end
    if group.timerId and group.timerId > 0 then
        self:_ClearTimer(group.timerId)
    end
    if group.huds then
        for _, hud in ipairs(group.huds) do
            LuaSystemManager.innRootSystem:ReturnGuestHud(hud)
        end
    end
    self.m_guestHudGroups[deskId] = nil
end



InnMainHudCtrl._OnDeskStateChangedForNpcHud = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if not deskId or deskId <= 0 then
        return
    end
    if self.m_guestHudGroups == nil then
        return
    end
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil then
        return
    end
    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil then
        return
    end

    local prevStatus = self.m_lastDeskStatusForNpc[deskId] or NPC_HUD_DESK_STATUS.DeskStatusEmpty
    local prevGuestId = self.m_lastDeskGuestIdForNpc[deskId] or 0
    local newStatus = desk.deskStatus
    local curGuestId = desk.guestId

    if newStatus == prevStatus then
        if curGuestId ~= 0 then
            self.m_lastDeskGuestIdForNpc[deskId] = curGuestId
        end
        return
    end

    self.m_lastDeskStatusForNpc[deskId] = newStatus
    if curGuestId ~= 0 then
        self.m_lastDeskGuestIdForNpc[deskId] = curGuestId
    end

    if newStatus == NPC_HUD_DESK_STATUS.DeskStatusEating and curGuestId > 0 then
        self:_ShowGuestEmojiHud(deskId, curGuestId)
    elseif newStatus == NPC_HUD_DESK_STATUS.DeskStatusOrderingFailed then
        local failedGuestId = curGuestId > 0 and curGuestId or prevGuestId
        if failedGuestId > 0 then
            self:_ShowOrderFailedHud(deskId, failedGuestId)
        end
    end
end

InnMainHudCtrl._ShowGuestEmojiHud = HL.Method(HL.Number, HL.Number) << function(self, deskId, guestId)
    local entities = LuaSystemManager.innNpcSystem:GetGuestEntities(guestId)
    if entities == nil or #entities <= 0 then
        return
    end

    self:_ClearGuestHudsForDesk(deskId)

    local huds = {}
    for _, entity in ipairs(entities) do
        if entity ~= nil then
            local hud = LuaSystemManager.innRootSystem:GetGuestHud()
            if hud then
                hud:InitInnNpcHeadLabel({ guestId = guestId })
                hud.view.worldUIFollowAndFaceCamera:SetFollowNpcHeadLabel(entity)
                huds[#huds + 1] = hud
            end
        end
    end
    if #huds <= 0 then
        return
    end

    local group = { huds = huds, timerId = -1 }
    self.m_guestHudGroups[deskId] = group
    local duration = self.view.config.EMOJI_DURATION or 0
    if duration > 0 then
        group.timerId = self:_StartTimer(duration, function()
            group.timerId = -1
            self:_ClearGuestHudsForDesk(deskId)
        end)
    end
end

InnMainHudCtrl._ShowOrderFailedHud = HL.Method(HL.Number, HL.Number) << function(self, deskId, guestId)
    local entities = LuaSystemManager.innNpcSystem:GetGuestEntities(guestId)
    if entities == nil or #entities <= 0 then
        return
    end
    local entity = entities[1]
    if entity == nil then
        return
    end

    self:_ClearGuestHudsForDesk(deskId)

    local hud = LuaSystemManager.innRootSystem:GetGuestHud()
    if not hud then
        return
    end
    hud:InitInnNpcHeadLabel({ text = Language.LUA_INN_MAIN_HUD_ORDER_FAILED })
    hud.view.worldUIFollowAndFaceCamera:SetFollowNpcHeadLabel(entity)

    local group = { huds = { hud }, timerId = -1 }
    self.m_guestHudGroups[deskId] = group
    local stayTime = Tables.innManagementConst.guestLeaveTime or 0
    if stayTime > 0 then
        group.timerId = self:_StartTimer(stayTime, function()
            group.timerId = -1
            self:_ClearGuestHudsForDesk(deskId)
        end)
    end
end





local SETTLE_OLD_GAME_WAIT_KEY = "InnSettleOldGame"
local SETTLE_OLD_GAME_TIMEOUT_SEC = 10

InnMainHudCtrl._OnCounterStartGameInteract = HL.StaticMethod() << function()
    if GameInstance.player.innSystem.existUnsettledGame then
        InnMainHudCtrl._BeginWaitSettleOldGame()
        GameInstance.player.innSystem:SendSettleOldGame(function()
            InnMainHudCtrl._EndWaitSettleOldGame()
        end)
        return
    end
    
    InnUtils.startGame()
end

InnMainHudCtrl._BeginWaitSettleOldGame = HL.StaticMethod() << function()
    TimerManager:ClearAllTimer(SETTLE_OLD_GAME_WAIT_KEY)
    MessageManager:UnregisterAll(SETTLE_OLD_GAME_WAIT_KEY)
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = SETTLE_OLD_GAME_WAIT_KEY, isInMainHud = false })
    MessageManager:Register(MessageConst.ON_UI_PANEL_START_OPEN, function(panelName)
        InnMainHudCtrl._EndWaitSettleOldGame()
    end, SETTLE_OLD_GAME_WAIT_KEY)
    TimerManager:StartTimer(SETTLE_OLD_GAME_TIMEOUT_SEC, function()
        InnMainHudCtrl._EndWaitSettleOldGame()
    end, true, SETTLE_OLD_GAME_WAIT_KEY)
end

InnMainHudCtrl._EndWaitSettleOldGame = HL.StaticMethod() << function()
    TimerManager:ClearAllTimer(SETTLE_OLD_GAME_WAIT_KEY)
    MessageManager:UnregisterAll(SETTLE_OLD_GAME_WAIT_KEY)
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = SETTLE_OLD_GAME_WAIT_KEY, isInMainHud = true })
end

InnMainHudCtrl._OnCounterInfoInteract = HL.StaticMethod() << function()
    PhaseManager:OpenPhase(PhaseId.InnDetail)
end

InnMainHudCtrl._OnCounterExpansionInteract = HL.StaticMethod(HL.Opt(HL.Any)) << function(args)
    local camCfgs = args and args[1]
    PhaseManager:OpenPhase(PhaseId.InnRegionUpgrade, {
        camCfgs = camCfgs,
    })
end



HL.Commit(InnMainHudCtrl)
