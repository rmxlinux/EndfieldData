local CommonPopUpCtrl = require_ex('UI/Panels/CommonPopUp/CommonPopUpCtrl')
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleMain
local PHASE_ID = PhaseId.GambleBattleMain
GambleBattleMainCtrl = HL.Class('GambleBattleMainCtrl', uiCtrl.UICtrl)







GambleBattleMainCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_GAMBLE_BATTLE_DRAW_NORMAL] = '_HandleNormalDrawCard',
    [MessageConst.ON_GAMBLE_BATTLE_DATA_SYNC] = '_OnGambleBattleDataSync',
    [MessageConst.ON_CLOSE_GAMBLE_BATTLE_MAIN_FOR_SETTLEMENT] = '_OnCloseMainForSettlement',
}


GambleBattleMainCtrl.ShowGambleBattleMain = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    PhaseManager:OpenPhase(PHASE_ID, args)
end


GambleBattleMainCtrl.OnOpenGambleBattleDungeonInfoPopup = HL.StaticMethod() << function()
    DungeonUtils.onClickCharFormationDungeonInfoBtn(Tables.gambleBattleConst.gambleBattleDungeonId)
end


GambleBattleMainCtrl.m_enemyCells = HL.Field(HL.Forward("UIListCache"))


GambleBattleMainCtrl.m_remainCardCells = HL.Field(HL.Forward("UIListCache"))


GambleBattleMainCtrl.m_rewardPointCells = HL.Field(HL.Forward("UIListCache"))


GambleBattleMainCtrl.m_system = HL.Field(HL.Any)


GambleBattleMainCtrl.m_enemyIds = HL.Field(HL.Table)


GambleBattleMainCtrl.m_enemyLevels = HL.Field(HL.Table)


GambleBattleMainCtrl.m_poolAllCardPoint2Num = HL.Field(HL.Table)


GambleBattleMainCtrl.m_remainCardPoint2Num = HL.Field(HL.Table)


GambleBattleMainCtrl.m_lastPointNumber = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_curPointNumber = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_infoTickHandle = HL.Field(HL.Number) << -1


GambleBattleMainCtrl.m_curShowPoolName = HL.Field(HL.String) << ""


GambleBattleMainCtrl.m_lastBonusHandType = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_dailyPlayCnt = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_commonToggleInitialed = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_floorState = HL.Field(HL.Any) << nil


GambleBattleMainCtrl.m_lastMainState = HL.Field(HL.Any) << nil


GambleBattleMainCtrl.m_curMainState = HL.Field(HL.Any) << nil


GambleBattleMainCtrl.m_playDrawCardVxIng = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_canDrawCard = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_luaIndex2rewardPointCell = HL.Field(HL.Table) << nil


GambleBattleMainCtrl.m_openSwitchInVsPost = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_allTaskRewarded = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_curBottomState = HL.Field(HL.Any) << nil

GambleBattleMainCtrl.m_lastBottomState = HL.Field(HL.Any) << nil
GambleBattleMainCtrl.m_resetHandCardFlag = HL.Field(HL.Boolean) << false
GambleBattleMainCtrl.m_resetHandCloseFlag = HL.Field(HL.Boolean) << false
GambleBattleMainCtrl.m_skipOpenCloseAudio = HL.Field(HL.Boolean) << false
GambleBattleMainCtrl.m_openedFromActivity = HL.Field(HL.Boolean) << false


GambleBattleMainCtrl.m_lastHandCardState = HL.Field(HL.String) << ""


GambleBattleMainCtrl.m_lastHandType = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_challengeMoneyAnimLuaUpdateKey = HL.Field(HL.Number) << -1


GambleBattleMainCtrl.m_displayedChallengeMoney = HL.Field(HL.Number) << 0


GambleBattleMainCtrl.m_lastCanChallenge = HL.Field(HL.Any) << nil

local MAX_POINT_NUMBER = 20
local PUNISH_POINT_10 = 10

local CHALLENGE_MONEY_ANIM_DURATION = 0.35
local DRAW_CARD_ANIM_NAMES = {
    "gamblebattlemain_draw1",
    "gamblebattlemain_draw2",
    "gamblebattlemain_draw3",
    "gamblebattlemain_draw4",
    "gamblebattlemain_draw5",
}
local TOGGLE_NEVER_TIP_CLOSE_FLAG = "GAMBLE_BATTLE_TOGGLE_NEVER_TIP_CLOSE_FLAG"
local DRAW_TOAST_DAILY_FLAG = "GAMBLE_BATTLE_DRAW_TOAST_DAILY_FLAG_"



local BottomState = {
    Normal = "Normal",
    Best = "Best",
    Punish = "Punish",
}


local function showConfirmPopUp(content, warningContent, onConfirm)
    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        warningContent = warningContent,
        onConfirm = onConfirm,
        confirmText = Language.LUA_GAMBLE_BATTLE_POPUP_CONFIRM_TEXT,
        cancelText = Language.LUA_GAMBLE_BATTLE_POPUP_CANCEL_TEXT,
    })
end


GambleBattleMainCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        openedFromActivity = self.m_openedFromActivity,
        recoverState = {
            lastHandCardState = self.m_lastHandCardState,
            lastHandType = self.m_lastHandType,
        },
    }
end


GambleBattleMainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_openedFromActivity = arg ~= nil and arg.openedFromActivity == true
    
    if arg and arg.recoverState then
        self.m_lastHandCardState = arg.recoverState.lastHandCardState
        self.m_lastHandType = arg.recoverState.lastHandType
    end
    self:_BindData()
    self:_BindUI()
    ActivityUtils.playGambleBattleRoundBgm(self.m_system.gamblingDungeonRoundIndex)

    self:_InitTopMiddleTipInfo()
    self:_InitBuffLayoutNode()

    self:_HandleDrawCardVxPre()
    self:_HandleDrawCardVxPost()
end


GambleBattleMainCtrl.OnShow = HL.Override() << function(self)
    if not self.m_skipOpenCloseAudio then
        AudioAdapter.PostEvent("Au_UI_Menu_Gamblev1d6_Open")
    end
end


GambleBattleMainCtrl._ClosePhase = HL.Method() << function(self)
    ActivityUtils.stopGambleBattleBgm()
    PhaseManager:PopPhase(PHASE_ID)
end

GambleBattleMainCtrl._CloseAll = HL.Method(HL.Any) << function(self, arg)
    
    if PhaseManager:GetTopPhaseId() == PhaseId.CharFormation then
        PhaseManager:ExitPhaseFast(PhaseId.CharFormation)
    end

    if PhaseManager:IsOpen(PhaseId.GambleBattlePreviewHandType) then
        PhaseManager:ExitPhaseFast(PhaseId.GambleBattlePreviewHandType)
    end

    self:_ClosePhase()
    Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_ACTIVITY_END)
end

GambleBattleMainCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if self.m_system.curCardSuits.Count == 0 then
        local activityId = Tables.gambleBattleConst.gambleBattleActivityId
        local drawToastDailyKey = GameInstance.player.roleId .. DRAW_TOAST_DAILY_FLAG .. activityId
        if not ClientDataManagerInst:GetBool(drawToastDailyKey, false) then
            
            ClientDataManagerInst:SetBool(
                drawToastDailyKey, true, false, EClientDataTimeValidType.CurrentDayUntil4AM)
            UIManager:Open(PanelId.GambleBattleDrawToast)
        end
    end

    
    self:_RefreshRewardPointScroll()

    
    Notify(MessageConst.ON_GAMBLE_BATTLE_MAIN_ANIMATION_IN_FINISHED)
end

GambleBattleMainCtrl.OnClose = HL.Override() << function(self)
    
    local activity = GameInstance.player.activitySystem:GetActivity(Tables.gambleBattleConst.gambleBattleActivityId)
    if not activity or (not self.m_openedFromActivity and not InputManagerInst.inChangingInputDevice) then
        ActivityUtils.stopGambleBattleBgm()
    end

    if not self.m_skipOpenCloseAudio then
        AudioAdapter.PostEvent("Au_UI_Menu_Gamblev1d6_Close")
    end
    if self.m_enemyCells then
        for i = 1, self.m_enemyCells:GetCount() do
            local cell = self.m_enemyCells:GetItem(i)
            if cell then
                cell.infoNode.onClick:RemoveAllListeners()
            end
        end
    end

    self:_StopChallengeMoneyAnim()

    
    Notify(MessageConst.ON_CLOSE_GAMBLE_BATTLE_MAIN_PANEL)
end

GambleBattleMainCtrl._BindData = HL.Method() << function(self)
    self.m_system = GameInstance.player.gambleBattleSystem
    self.m_lastBonusHandType = self.m_system.bonusHandType
    self.m_system:RefreshProgressFromRecord()
    self.view.currentRoundText.text = self.m_system.gamblingDungeonRoundIndex + 1
    self.view.allRoundText.text = Tables.gambleBattleConst.dungeonContinuousChallengeTimes
end

GambleBattleMainCtrl._BindUI = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.btnClose.onClick:AddListener(function()
        self:_OnClickBtnClose()
    end)

    self.view.helpBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, "gamble_battle")
    end)

    self.m_enemyCells = UIUtils.genCellCache(self.view.gambleBattleEnemyCell)
    self.m_remainCardCells = UIUtils.genCellCache(self.view.remainCardCell)
    self.m_rewardPointCells = UIUtils.genCellCache(self.view.rewardPointCell)

    self.view.enemyInformationBtn.onClick:AddListener(function()
        self:_OnEnemyInformationBtnClick(1)
    end)

    self.view.drawCardBtn.onClick:AddListener(function()
        self:_OnDrawCardBtnClick()
    end)

    self.view.abandonBtn.gameObject:SetActive(false)
    self.view.retreatBtn.gameObject:SetActive(true)

    self.view.abandonBtn.onClick:AddListener(function()
        self:_OnAbandonBtnClick()
    end)

    self.view.retreatBtn.onClick:AddListener(function()
        self:_OnRetreatBtnClick()
    end)

    self.view.challengeBtn.onClick:AddListener(function()
        self:_OnChallengeBtnClick()
    end)

    self.view.handCardNode.button.onClick:AddListener(function()
        self:_OnClickHandCardNode()
    end)
end

GambleBattleMainCtrl._OnClickHandCardNode = HL.Method() << function(self)
    PhaseManager:OpenPhase(PhaseId.GambleBattlePreviewHandType)
end


GambleBattleMainCtrl._IsInDungeon = HL.Method().Return(HL.Boolean) << function(self)
    return GameWorld.worldInfo.curSubGameId == Tables.gambleBattleConst.gambleBattleDungeonId
end

GambleBattleMainCtrl._OnAbandonBtnClick = HL.Method() << function(self)
    
    if self.m_system.gamblingDungeonRoundIndex == 0 then
        showConfirmPopUp(
        Language.LUA_GAMBLE_BATTLE_ABANDON_OUT_POPUP_CONTENT, 
        nil,
        function()
            self:_DoAbandon()
        end)
    else
         showConfirmPopUp(
         Language.LUA_GAMBLE_BATTLE_ABANDON_IN_POPUP_CONTENT, 
         Language.LUA_GAMBLE_BATTLE_ABANDON_IN_POPUP_WARNING, 
         function()
             self:_RequestInDungeonSettle()
         end)
    end
end


GambleBattleMainCtrl._DoAbandon = HL.Method() << function(self)
    self.m_resetHandCardFlag = true
    self.m_system:ResetHandCard()
end

GambleBattleMainCtrl._OnRetreatBtnClick = HL.Method() << function(self)
    
    if not self:_IsInDungeon() then
        
        PhaseManager:PopPhase(PHASE_ID)
        return
    end

    if self.m_system.gamblingDungeonRoundIndex == 0 then
        showConfirmPopUp(
            Language.LUA_GAMBLE_BATTLE_CLOSE_OUT_DRAWN_POPUP_CONTENT, 
            nil,
            function()
                GameInstance.dungeonManager:LeaveDungeon()
            end)
        return
    end

    
    showConfirmPopUp(
        string.format(Language.LUA_GAMBLE_BATTLE_SETTLE_IN_POPUP_CONTENT, self.m_system.gamblingDungeonTotalPoint), 
        nil,
        function()
            self:_RequestInDungeonSettle()
        end)
end

GambleBattleMainCtrl._RequestInDungeonSettle = HL.Method() << function(self)
    if self.m_system.isPendingSettlement then
        return
    end

    self.m_system:RequestDoCompletion(self.m_system.curCardSuits.Count == 0, true)
end


GambleBattleMainCtrl._OnCloseMainForSettlement = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    PhaseManager:ExitPhaseFast(PHASE_ID)
end

GambleBattleMainCtrl._OnClickBtnClose = HL.Method() << function(self)
    local hasDrawn = self.m_system.curCardSuits.Count > 0

    if not self:_IsInDungeon() then
        
        if not hasDrawn then
            PhaseManager:PopPhase(PHASE_ID)
            return
        end

        
        showConfirmPopUp(
            Language.LUA_GAMBLE_BATTLE_CLOSE_OUT_DRAWN_POPUP_CONTENT, 
            nil,
            function()
                self.m_resetHandCloseFlag = true
                self.m_system:ResetHandCard()
            end)
        return
    end

    if self.m_system.gamblingDungeonRoundIndex == 0 then
        showConfirmPopUp(
            Language.LUA_GAMBLE_BATTLE_CLOSE_OUT_DRAWN_POPUP_CONTENT, 
            nil,
            function()
                GameInstance.dungeonManager:LeaveDungeon()
            end)
        return
    end

    
    if hasDrawn then
        showConfirmPopUp(
            Language.LUA_GAMBLE_BATTLE_CLOSE_IN_DRAWN_POPUP_CONTENT, 
            Language.LUA_GAMBLE_BATTLE_CLOSE_IN_DRAWN_POPUP_WARNING, 
            function()
                self:_RequestInDungeonSettle()
            end)
    else
        showConfirmPopUp(
            string.format(Language.LUA_GAMBLE_BATTLE_SETTLE_IN_POPUP_CONTENT, self.m_system.gamblingDungeonTotalPoint), 
            nil,
            function()
                self:_RequestInDungeonSettle()
            end)
    end
end

GambleBattleMainCtrl._OnDrawCardBtnClick = HL.Method() << function(self)
    if self.m_system.isPendingSettlement then
        return
    end

    if self.m_system.curCardSuits.Count == 5 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_DRAW_5_TOAST)
        return
    end

    if self.m_playDrawCardVxIng then
        return
    end

    
    
    

    self.m_system:RequestDungeonDraw()
end

GambleBattleMainCtrl._OnChallengeBtnClick = HL.Method() << function(self)
    if self.m_system.isPendingSettlement then
        return
    end

    if self.m_system.curCardSuits.Count == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.ui_activity_gamblingbattle_toast_draw)
        return
    end
    if self.m_playDrawCardVxIng then
        return
    end

    GameInstance.player.forbidSystem:SetPhaseForbid("CharFormation", "MainCharInAir", false, nil)
    if Utils.isInDungeon() then
        local charBag = GameInstance.player.charBag
        local teamInfo = charBag:GetMainTeam(GEnums.ScopeName.GamblingDungeon, 0)
        local initCharInstIdList = teamInfo and teamInfo.memberList or nil

        
        PhaseManager:GoToPhase(PhaseId.CharFormation, {
            dungeonId = Tables.gambleBattleConst.gambleBattleDungeonId,
            openConfirmPopup = false,
            initCharInstIdList = initCharInstIdList,
            hideTeamSwitch = true,
            candidateScope = GEnums.ScopeName.GamblingDungeon,
            customSetTeamCallback = function(charInstIdList)
                GameInstance.player.charBag:SetTeamWithSkill(0, charInstIdList, {}, GEnums.ScopeName.GamblingDungeon)
            end,
            getComboSkill = function()
                local teamInfo = GameInstance.player.charBag:GetMainTeam(GEnums.ScopeName.GamblingDungeon, 0)
                return teamInfo and teamInfo.comboSkillOrder
            end,
            comboSkillSaveCallback = function(comboSkillCharList)
                GameInstance.player.charBag:SetTeamComboSkillOrder(0, comboSkillCharList, GEnums.ScopeName.GamblingDungeon)
            end,
            infoBtnCallback = function()
                DungeonUtils.onClickCharFormationDungeonInfoBtn(Tables.gambleBattleConst.gambleBattleDungeonId)
            end,
            startBtnCallback = function()
                self.m_skipOpenCloseAudio = true
                ActivityUtils.stopGambleBattleBgm()
                PhaseManager:ExitPhaseFast(PhaseId.CharFormation)
                if PhaseManager:IsOpen(PHASE_ID) then
                    PhaseManager:ExitPhaseFast(PHASE_ID)
                end
                DungeonUtils.onClickCharFormationDungeonInfoBtn(Tables.gambleBattleConst.gambleBattleDungeonId)
            end,
            startBtnText = Language.LUA_GAMBLE_BATTLE_CHAR_FORMATION_CHALLENGE_BTN,
            sendReqEnterDungeon = false,
        })
    else
        PhaseManager:GoToPhase(PhaseId.CharFormation, {
            dungeonId = Tables.gambleBattleConst.gambleBattleDungeonId,
            customTitle = Language.LUA_GAMBLE_BATTLE_CHAR_FORMATION_TITLE,
            sendReqEnterDungeon = false,
            startBtnCallback = function()
                
                if GameInstance.dungeonManager:TryReqEnterDungeon(Tables.gambleBattleConst.gambleBattleDungeonId) then
                    
                    self.m_skipOpenCloseAudio = true
                    ActivityUtils.stopGambleBattleBgm()
                end
            end,
            hideTeamSwitch = true,
            openConfirmPopup = false,
            infoBtnCallback = function()
                DungeonUtils.onClickCharFormationDungeonInfoBtn(Tables.gambleBattleConst.gambleBattleDungeonId)
            end,
            startBtnText = Language.LUA_GAMBLE_BATTLE_CHAR_FORMATION_CHALLENGE_BTN,
        })
    end
end

GambleBattleMainCtrl._OnEnemyInformationBtnClick = HL.Method(HL.Number) << function(self, luaIndex)
    if not self.m_enemyIds or #self.m_enemyIds == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_NO_ENEMY_TOAST)
        return
    end
    UIManager:AutoOpen(
        PanelId.CommonEnemyPopup,
        {
            title = Language.LUA_GAMBLE_BATTLE_ENEMY_POPUP_TITLE,
            enemyListTitle = Language["ui_dungeon_enemy_popup_info_list"],
            enemyInfoTitle = Language["ui_dungeon_enemy_popup_info_desc"],
            enemyIds = self.m_enemyIds,
            enemyLevels = self.m_enemyLevels,
            initSelectEnemyLuaIndex = luaIndex,
            hideLevelTextNode = true,
        })
end

GambleBattleMainCtrl._InitTopMiddleTipInfo = HL.Method() << function(self)
    local node = self.view.topMiddleNode
    node.topMiddleTipsPopupNode.gameObject:SetActive(false)

    local function closeTipsPopup()
        node.topMiddleTipsPopupNodeAnimationWrapper:PlayOutAnimation(function()
            node.topMiddleTipsPopupNode.gameObject:SetActive(false)
            if DeviceInfo.usingController then
                node.selectableNaviGroup:ManuallyStopFocus()
            end
        end)
    end

    node.topMiddleTipsPopupCloseBtn.onClick:AddListener(closeTipsPopup)
    node.topMiddleInformationBtn.onClick:AddListener(function()
        if node.topMiddleTipsPopupNode.gameObject.activeSelf then
            closeTipsPopup()
        else
            node.topMiddleTipsPopupNode.gameObject:SetActive(true)
            if DeviceInfo.usingController then
                node.selectableNaviGroup:ManuallyFocus()
            end
        end
    end)
end

GambleBattleMainCtrl._UpdateTopMiddleTipInfo = HL.Method() << function(self)
    local baseAward = self.m_system.rewardScoreNumber

    
    local luckyBenefit = self:_GetEffectiveComboBenefit()

    
    local haveMoney = self.m_system.gamblingDungeonTotalPoint

    
    local challengeMoney = math.floor(baseAward * luckyBenefit / 100) + haveMoney

    self.view.topMiddleNode.haveMoneyText.text = self.m_system.gamblingDungeonTotalPoint
    self:_StartChallengeMoneyAnim(self.m_displayedChallengeMoney, challengeMoney)

    
    self.view.topMiddleNode.formulaHaveText.text = haveMoney                              
    self.view.topMiddleNode.formulaPointText.text = baseAward                             
    self.view.topMiddleNode.formulaLuckyText.text = self:_FormatComboRate(luckyBenefit / 100) 
end

GambleBattleMainCtrl._SetChallengeMoneyText = HL.Method(HL.Number) << function(self, value)
    local num = lume.round(value)
    self.m_displayedChallengeMoney = num
    self.view.topMiddleNode.challengeMoneyText.text = num
end

GambleBattleMainCtrl._StopChallengeMoneyAnim = HL.Method() << function(self)
    if self.m_challengeMoneyAnimLuaUpdateKey > 0 then
        self.m_challengeMoneyAnimLuaUpdateKey = self:_RemoveUpdate(self.m_challengeMoneyAnimLuaUpdateKey)
    end
end


GambleBattleMainCtrl._StartChallengeMoneyAnim = HL.Method(HL.Number, HL.Number) << function(self, fromValue, toValue)
    self:_StopChallengeMoneyAnim()

    local duration = CHALLENGE_MONEY_ANIM_DURATION
    self:_SetChallengeMoneyText(fromValue)

    if duration <= 0 or fromValue == toValue then
        self:_SetChallengeMoneyText(toValue)
        return
    end

    if toValue > fromValue then
        AudioAdapter.PostEvent("Au_UI_Event_CambleCount")
    end

    local rewardNumAnim = self.view.topMiddleNode.rewardNumNodeAnim
    rewardNumAnim:ClearTween(false)
    rewardNumAnim:PlayWithTween("gamblebattlemainrewardlight_in", nil, CS.Beyond.UI.UIConst.AnimationState.Others)

    local timeCount = 0
    self.m_challengeMoneyAnimLuaUpdateKey = self:_StartUpdate(function(deltaTime)
        timeCount = timeCount + deltaTime
        if timeCount < duration then
            local normalizedX = timeCount / duration
            
            local normalizedY = 1 - (1 - normalizedX) * (1 - normalizedX)
            self:_SetChallengeMoneyText(fromValue + (toValue - fromValue) * normalizedY)
        else
            self:_SetChallengeMoneyText(toValue)
            self:_StopChallengeMoneyAnim()
        end
    end)
end

GambleBattleMainCtrl._CalCurHandPoint = HL.Method().Return(HL.Number) << function(self)
    local pointNumber = 0
    for i = 1, self.m_system.curCardSuits.Count do
        local cardName = self.m_system.curCardSuits[i - 1].cardId
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
        if hasCard then
            pointNumber = pointNumber + cardData.cardPoint
        end
    end
    return pointNumber
end



GambleBattleMainCtrl._GetEffectiveComboBenefit = HL.Method().Return(HL.Number) << function(self)
    local data, isMatchToday = self:_GetEffectiveHandTypeData()
    if not data then
        return 100
    end
    return isMatchToday and data.bonusBenefit or data.handTypeBenefit
end


GambleBattleMainCtrl._HandleDrawCardVxPre = HL.Method() << function(self)
    self:_CalRewardPointNumber()
    self:_UpdateBottomState()
    self:_UpdateAbandonButtonVisible()
end


GambleBattleMainCtrl._UpdateAbandonButtonVisible = HL.Method() << function(self)
    if self.m_system.curCardSuits.Count > 0 then
        self.view.abandonBtn.gameObject:SetActive(true)
        self.view.retreatBtn.gameObject:SetActive(false)
    else
        self.view.abandonBtn.gameObject:SetActive(false)
        self.view.retreatBtn.gameObject:SetActive(true)
        
        if self.m_system.gamblingDungeonRoundIndex == 0 then
            self.view.retreatBtn.text = Language.LUA_GAMBLE_BATTLE_RETREAT_BTN_TEXT
        else
            self.view.retreatBtn.text = Language.LUA_GAMBLE_BATTLE_GIVE_UP_BTN_TEXT
        end
    end
end


GambleBattleMainCtrl._UpdateChallengeBtnState = HL.Method() << function(self)
    local canChallenge = self.m_system.curCardSuits.Count > 0
    self.view.challengeBtn.interactable = canChallenge
    self.view.challengeBtnStateController:SetState(canChallenge and "Normal" or "Gray")

    local lastCanChallenge = self.m_lastCanChallenge
    self.m_lastCanChallenge = canChallenge
    
    if lastCanChallenge ~= nil and lastCanChallenge ~= canChallenge then
        local challengeBtnAnim = self.view.challengeBtnAnimationWrapper
        challengeBtnAnim:ClearTween(false)
        local animName = canChallenge and "gamblebattlemainchallengebtn_change" or "gamblebattlemainchallengebtn_gay"
        challengeBtnAnim:PlayWithTween(animName, nil, CS.Beyond.UI.UIConst.AnimationState.Others)
    end
end

GambleBattleMainCtrl._UpdateBottomState = HL.Method() << function(self)
    if self.m_curPointNumber > PUNISH_POINT_10 then
        self.m_curBottomState = BottomState.Punish
        self.view.bottomNodeStateController:SetState(self.m_curBottomState)
    else
        self.m_curBottomState = BottomState.Normal
        self.view.bottomNodeStateController:SetState(self.m_curBottomState)
    end

    if self.m_lastBottomState ~= self.m_curBottomState then
        
        if self.m_lastBottomState ~= nil and self.m_curBottomState == BottomState.Punish then
            self.view.mainAnim:ClearTween(true)
            AudioAdapter.PostEvent("Au_UI_Event_GambleRed")
            self.view.mainAnim:PlayWithTween("gamblebattlemaincolor_in")
        end
        self.m_lastBottomState = self.m_curBottomState
    end

    
    self:_UpdateBuffLayoutNode()
end


GambleBattleMainCtrl._CalRewardPointNumber = HL.Method() << function(self)
    self.m_lastPointNumber = self.m_curPointNumber
    local pointNumber = 0
    for i = 1, self.m_system.curCardSuits.Count do
        local cardName = self.m_system.curCardSuits[i - 1].cardId
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
        if hasCard then
            local cardPoint = cardData.cardPoint
            pointNumber = pointNumber + cardPoint
        end
    end
    self.m_curPointNumber = pointNumber

    self.m_system.deBuffMonsterLevel = 0
    if self.m_curPointNumber > PUNISH_POINT_10 then
        self.m_system.deBuffMonsterLevel = Tables.gambleBattleConst.firstDebuffMonsterLv
    end
end

GambleBattleMainCtrl._HandleNormalDrawTTT = HL.Method(HL.Number) << function(self, ssss)
    self:_HandleDrawCardVxPre()  
    self.m_curPointNumber = ssss
    self:_HandleDrawCardVxPost()
end

GambleBattleMainCtrl._HandleNormalDrawCard = HL.Method() << function(self)
    local vxName = DRAW_CARD_ANIM_NAMES[self.m_system.curCardSuits.Count] or DRAW_CARD_ANIM_NAMES[1]
    if DeviceInfo.isMobile and not DeviceInfo.usingController then
        vxName = "mobile" .. vxName
    end

    self.m_playDrawCardVxIng = true
    self:_HandleDrawCardVxPre()

    self.view.drawCardPreAnimNode.gameObject:SetActive(true)
    

    self.view.middleAnimationWrapper:PlayWithTween(vxName, function()       
        self:_HandleDrawCardVxPost()
        self.view.drawCardPreAnimNode.gameObject:SetActive(false)
        
    end)

    self:_HandleCardDecoVxCell()
end


GambleBattleMainCtrl._RenderCard = HL.Method(HL.Any, HL.Any, HL.Number) << function(self, cell, cardData, suits)
    local cardPoint = cardData.cardPoint
    local enemyId = cardData.enemyIdList[0]
    local enemyCount = cardData.enemyCountList[0]
    local suitType = "tong"
    if suits == 1 then
        suitType = "tiao"
    elseif suits == 2 then
        suitType = "wan"
    end

    local enemyInfo = UIUtils.getEnemyInfoByIdAndLevel(enemyId, cardData.enemyLevel[0])
    cell.nameTxt.text = string.format(Language.LUA_GAMBLE_BATTLE_ENEMY_SHOW_NAME_AND_COUNT, enemyInfo.name, enemyCount)
    cell.lvTxt.text = enemyInfo.level + self.m_system.deBuffMonsterLevel
    cell.iconImg:LoadSprite(UIConst.UI_SPRITE_MONSTER_ICON_BIG, enemyInfo.templateId)
    cell.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. cardPoint)
    cell.typeImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. suitType)
    cell.rightTopImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" ..
        suitType .. "_" .. cardPoint)
end

GambleBattleMainCtrl._HandleCardDecoVxCell = HL.Method() << function(self)
    
    if self.m_system.curCardSuits.Count == 0 then
        return
    end
    local cell = self.view.gambleBattleEnemyVxCell
    local latest = self.m_system.curCardSuits[self.m_system.curCardSuits.Count - 1]
    local cardName = latest.cardId
    local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
    if not hasCard or cardData.enemyIdList.Count <= 0 then
        return
    end

    cell.stateController:SetState("Normal")
    self:_RenderCard(cell, cardData, latest.suit)
end


GambleBattleMainCtrl._RefreshAfterDataSync = HL.Method() << function(self)
    self.m_playDrawCardVxIng = false
    self.view.middleAnimationWrapper:ClearTween(false)
    self.view.drawCardPreAnimNode.gameObject:SetActive(false)
    self:_BindData()
    self:_HandleDrawCardVxPre()
    self:_HandleDrawCardVxPost()
    self.animationWrapper:PlayInAnimation()
    if not self.m_skipOpenCloseAudio then
        AudioAdapter.PostEvent("Au_UI_Menu_Gamblev1d6_Open")
    end
end

GambleBattleMainCtrl._OnGambleBattleDataSync = HL.Method() << function(self)
    if self.m_resetHandCardFlag then
        self.m_resetHandCardFlag = false
        self:_RefreshAfterDataSync()
        return
    end
    if self.m_resetHandCloseFlag then
        self.m_resetHandCloseFlag = false
        PhaseManager:PopPhase(PHASE_ID)
        return
    end
    
    local isPoolChanged = self.m_curShowPoolName ~= "" and self.m_curShowPoolName ~= self.m_system:GetValidCardPoolId()
    local isBonusHandTypeChanged = self.m_lastBonusHandType ~= self.m_system.bonusHandType
    self.m_lastBonusHandType = self.m_system.bonusHandType
    if isPoolChanged or isBonusHandTypeChanged then
        self:_RefreshAfterDataSync()
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_PREVIEW_ACTIVITY_UPDATED)
        return
    end
end

GambleBattleMainCtrl._InitBuffLayoutNode = HL.Method() << function(self)
    local tipsPopupNode = self.view.buffLayoutNode.tipsPopupNode
    local tipsPopupAnim = self.view.buffLayoutNode.tipsPopupNodeAnimationWrapper
    tipsPopupNode.gameObject:SetActive(false)

    local function closeTipsPopup()
        UIUtils.PlayAnimationAndToggleActive(tipsPopupAnim, false, function()
            self.view.buffLayoutNode.selectableNaviGroup:ManuallyStopFocus()
        end)
    end

    self.view.buffLayoutNode.tipsPopupCloseBtn.onClick:AddListener(function()
        closeTipsPopup()
    end)

    self.view.buffLayoutNode.buffTipsBtn.onClick:AddListener(function()
        if tipsPopupNode.gameObject.activeSelf then
            closeTipsPopup()
        else
            UIUtils.PlayAnimationAndToggleActive(tipsPopupAnim, true)
            if DeviceInfo.usingController then
                self.view.buffLayoutNode.selectableNaviGroup:ManuallyFocus()
            end
        end
    end)
end

GambleBattleMainCtrl._UpdateBuffLayoutNode = HL.Method() << function(self)
    if self.m_curPointNumber > PUNISH_POINT_10 then
        self.view.buffLayoutNode.buffTipsTxt.text = Language.LUA_GAMBLE_BATTLE_PUNISHMENT_10_BTN_TEXT
        self.view.buffLayoutNode.tipsPopupTitleText.text = Language.LUA_GAMBLE_BATTLE_PUNISHMENT_10_POPUP_TITLE
        self.view.buffLayoutNode.tipsPopupHintText.text = Language.LUA_GAMBLE_BATTLE_PUNISHMENT_10_POPUP_CONTENT
    end
end

GambleBattleMainCtrl._GetEnemyBuffsAnim = HL.Method(HL.Any).Return(HL.Opt(HL.Any)) << function(self, cell)
    local wrapper = cell.animationWrapper
    if not wrapper then
        return nil
    end
    local trans = wrapper.transform:Find("EnemyBuffs")
    if not trans then
        return nil
    end
    return trans:GetComponent("UIAnimationWrapper")
end

GambleBattleMainCtrl._SetEnemyBuffsLoop = HL.Method(HL.Any, HL.Boolean) << function(self, cell, enable)
    local buffsAnim = self:_GetEnemyBuffsAnim(cell)
    if not buffsAnim then
        return
    end
    if enable then
        local wasActive = buffsAnim.gameObject.activeSelf
        if not wasActive then
            buffsAnim.gameObject:SetActive(true)
        end
        if not wasActive or buffsAnim.curState ~= CS.Beyond.UI.UIConst.AnimationState.Loop then
            buffsAnim:PlayLoopAnimation()
        end
    else
        buffsAnim:ClearTween(false)
        buffsAnim.gameObject:SetActive(false)
    end
end

GambleBattleMainCtrl._RefreshAllEnemyBuffsLoop = HL.Method() << function(self)
    
    local pendingLoopCells = {}
    local hasHandTypeCardIds, handTypeCardIdSet = self.m_system:TryGetCurHandTypeCardIdSet()
    for luaIndex = 1, self.m_enemyCells:GetCount() do
        local cell = self.m_enemyCells:GetItem(luaIndex)
        if cell then
            local enable = false
            if luaIndex <= self.m_system.curCardSuits.Count then
                local cardName = self.m_system.curCardSuits[CSIndex(luaIndex)].cardId
                enable = hasHandTypeCardIds and handTypeCardIdSet:Contains(cardName)
            end
            if enable then
                local buffsAnim = self:_GetEnemyBuffsAnim(cell)
                if buffsAnim and (not buffsAnim.gameObject.activeSelf or
                        buffsAnim.curState ~= CS.Beyond.UI.UIConst.AnimationState.Loop) then
                    table.insert(pendingLoopCells, cell)
                end
            else
                self:_SetEnemyBuffsLoop(cell, false)
            end
        end
    end

    
    for _, cell in ipairs(pendingLoopCells) do
        self:_SetEnemyBuffsLoop(cell, true)
    end
end

GambleBattleMainCtrl._UpdateEnemyCells = HL.Method() << function(self)
    self.m_enemyIds = {}
    self.m_enemyLevels = {}

    local enemyAllCount = 0
    local playedLightIn = false
    self.m_enemyCells:Refresh(5, function(cell, luaIndex)
        cell.gameObject.name = "GambleBattleCardCell_" .. luaIndex
        cell.infoNode.onClick:RemoveAllListeners()

        if luaIndex > self.m_system.curCardSuits.Count then
            cell.stateController:SetState("Empty", false)
            self:_SetEnemyBuffsLoop(cell, false)
            return
        end

        
        cell.stateController:SetState("Normal", false)
        local card = self.m_system.curCardSuits[CSIndex(luaIndex)]
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(card.cardId)
        if hasCard then
            table.insert(self.m_enemyIds, cardData.enemyIdList[0])
            table.insert(self.m_enemyLevels, cardData.enemyLevel[0])
            if cardData.enemyIdList.Count > 0 then
                enemyAllCount = enemyAllCount + cardData.enemyCountList[0]
                self:_RenderCard(cell, cardData, card.suit)
                cell.numberImgVx:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. cardData.cardPoint)
                cell.infoNode.onClick:AddListener(function()
                    self:_OnEnemyInformationBtnClick(luaIndex)
                end)
            end
        end
        local isNewestDraw = luaIndex == self.m_system.curCardSuits.Count and self.m_playDrawCardVxIng
        if isNewestDraw then
            
            playedLightIn = true
            self:_SetEnemyBuffsLoop(cell, false)
            AudioAdapter.PostEvent("Au_UI_Event_GambleInlay")
            cell.animationWrapper:PlayWithTween("gamblebattleenemylight_in", function()
                self:_RefreshAllEnemyBuffsLoop()
                self.m_playDrawCardVxIng = false
            end, CS.Beyond.UI.UIConst.AnimationState.Others)
        end
    end)

    for i = 1, self.m_enemyCells:GetCount() do
        self.m_enemyCells:GetItem(i).transform:SetAsFirstSibling()
    end
    self.m_system.enemyAllCount = enemyAllCount
    if self.m_playDrawCardVxIng and not playedLightIn then
        self.m_playDrawCardVxIng = false
    end
    
    
    if not self.m_playDrawCardVxIng then
        self:_RefreshAllEnemyBuffsLoop()
    end
end

GambleBattleMainCtrl._UpdateRemainCardCells = HL.Method() << function(self)
    self:_InitAllPoolPoint2Num()
    self.m_remainCardPoint2Num = {}

    for pointNum, remainNumber in pairs(self.m_poolAllCardPoint2Num) do
        self.m_remainCardPoint2Num[pointNum] = remainNumber
        local showInfo = {
            pointNum = pointNum,
            remainNumber = remainNumber,
        }
    end

    for i = 1, self.m_system.curCardSuits.Count do
        local cardName = self.m_system.curCardSuits[i - 1].cardId
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
        if hasCard then
            local cardPoint = cardData.cardPoint
            if self.m_remainCardPoint2Num[cardPoint] ~= nil then
                self.m_remainCardPoint2Num[cardPoint] = self.m_remainCardPoint2Num[cardPoint] - 1
            end
        end
    end

    local showRemainTable = {}
    for pointNum, remainNumber in pairs(self.m_remainCardPoint2Num) do
        if remainNumber >= 0 then
            local showInfo = {
                pointNum = pointNum,
                remainNumber = remainNumber,
            }
            table.insert(showRemainTable, showInfo)
        end
    end

    table.sort(showRemainTable, Utils.genSortFunction({ "pointNum" }, true))

    self.m_remainCardCells:Refresh(#showRemainTable, function(cell, luaIndex)
        local showInfo = showRemainTable[luaIndex]
        cell.remainCardTxt.text = showInfo.remainNumber
        cell.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. showInfo.pointNum)
    end)

    if self.m_system.curCardSuits.Count >= 5 then
        self.view.drawCardBtnStateController:SetState("Gray")
    else
        self.view.drawCardBtnStateController:SetState("Normal") 
    end

    local drawCardAnim = self.view.drawCardBtnAnimationWrapper
    if self.m_system.curCardSuits.Count == 0 then
        if drawCardAnim.curState ~= CS.Beyond.UI.UIConst.AnimationState.Loop then
            drawCardAnim:PlayLoopAnimation()
        end
    else
        drawCardAnim:ClearTween(false)
        drawCardAnim:SampleClipAtPercent("gamblebattlemaindrawcard_loop", 0, false)
    end

    self.view.drawCardBtn.interactable = self.m_system.curCardSuits.Count < 5
end


GambleBattleMainCtrl._InitAllPoolPoint2Num = HL.Method() << function(self)
    self.m_poolAllCardPoint2Num = {} 
    self.m_curShowPoolName = self.m_system:GetValidCardPoolId()
    local hasPool, poolData = Tables.GambleBattleCardPoolTable:TryGetValue(self.m_curShowPoolName)
    if hasPool then
        for i = 1, poolData.list.Count do
            local card = poolData.list[i - 1]
            local cardName = card.enemyGroupId
            local cardNum = card.cardNum
            local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
            if hasCard then
                local cardPoint = cardData.cardPoint
                if self.m_poolAllCardPoint2Num[cardPoint] == nil then
                    self.m_poolAllCardPoint2Num[cardPoint] = 0
                end
                self.m_poolAllCardPoint2Num[cardPoint] = self.m_poolAllCardPoint2Num[cardPoint] + cardNum
            end
        end
    end
end

GambleBattleMainCtrl._SetRewardPointCellNumberImg = HL.Method(HL.Any, HL.Number) << function(self, cell, pointNum)
    cell.numberTxt.text = pointNum
end

GambleBattleMainCtrl._RefreshRewardPointScroll = HL.Method() << function(self)
    if not self.m_luaIndex2rewardPointCell then
        return
    end
    local isOverMax = self.m_curPointNumber >= MAX_POINT_NUMBER
    local selectPoint = (self.m_curPointNumber > 0 and not isOverMax) and self.m_curPointNumber or 0
    self:_ScrollRewardPointCellsToSelected(selectPoint, isOverMax)
end


GambleBattleMainCtrl._ScrollRewardPointCellsToSelected = HL.Method(HL.Number, HL.Boolean) << function(self, selectPoint, isOverMax)
    local targetLuaIndex
    if isOverMax then
        targetLuaIndex = MAX_POINT_NUMBER - 1
    elseif selectPoint > 0 then
        targetLuaIndex = selectPoint
    else
        targetLuaIndex = 1
    end

    local cell = self.m_luaIndex2rewardPointCell[targetLuaIndex]
    local firstCell = self.m_luaIndex2rewardPointCell[1]
    local lastCell = self.m_luaIndex2rewardPointCell[MAX_POINT_NUMBER-1]
    if not cell or not firstCell or not lastCell then
        return
    end

    local layoutNode = cell.rectTransform.parent
    local maskRect = layoutNode and layoutNode.parent
    if not layoutNode or not maskRect then
        return
    end

    
    local rewardLayout = maskRect.parent
    if rewardLayout then
        LayoutRebuilder.ForceRebuildLayoutImmediate(rewardLayout)
    end
    LayoutRebuilder.ForceRebuildLayoutImmediate(maskRect)
    LayoutRebuilder.ForceRebuildLayoutImmediate(layoutNode)

    local viewLeft = maskRect.rect.xMin
    local viewRight = maskRect.rect.xMax
    local viewWidth = viewRight - viewLeft
    
    if viewWidth < 1 then
        return
    end

    local firstHalf = firstCell.rectTransform.rect.width * 0.5
    local lastHalf = lastCell.rectTransform.rect.width * 0.5
    local cellHalf = cell.rectTransform.rect.width * 0.5
    if firstHalf < 0.01 or lastHalf < 0.01 or cellHalf < 0.01 then
        return
    end

    local firstPosX = maskRect:InverseTransformPoint(firstCell.rectTransform.position).x
    local lastPosX = maskRect:InverseTransformPoint(lastCell.rectTransform.position).x
    local cellPosX = maskRect:InverseTransformPoint(cell.rectTransform.position).x
    local contentWidth = (lastPosX + lastHalf) - (firstPosX - firstHalf)

    local pos = layoutNode.anchoredPosition
    local deltaX
    if contentWidth <= viewWidth then
        
        deltaX = viewLeft - (firstPosX - firstHalf)
    else
        local maxDelta = viewLeft - (firstPosX - firstHalf)
        local minDelta = viewRight - (lastPosX + lastHalf)
        
        if targetLuaIndex >= MAX_POINT_NUMBER - 1 then
            deltaX = viewRight - (cellPosX + cellHalf)
        else
            deltaX = maskRect.rect.center.x - cellPosX
        end
        deltaX = math.min(maxDelta, math.max(minDelta, deltaX))
    end

    if math.abs(deltaX) < 0.01 then
        return
    end
    layoutNode.anchoredPosition = Vector2(pos.x + deltaX, pos.y)
end

GambleBattleMainCtrl._UpdateRewardPointCells = HL.Method() << function(self)
    self.m_luaIndex2rewardPointCell = {}

    
    local awardMultiplierPercent = math.floor(self.m_system.gamblingDungeonTotalPoint / 10000) * 10 + 100
    local isOverMax = self.m_curPointNumber >= MAX_POINT_NUMBER
    
    local selectPoint = (self.m_curPointNumber > 0 and not isOverMax) and self.m_curPointNumber or 0

    self.m_rewardPointCells:Refresh(MAX_POINT_NUMBER-1, function(cell, luaIndex)
        self.m_luaIndex2rewardPointCell[luaIndex] = cell
        local rewardNum = math.floor(Tables.gambleBattleConst.pointAwardList[luaIndex - 1] * awardMultiplierPercent / 100)
        local pointNum = luaIndex
        cell.pointNumberTxt.text = pointNum
        cell.rewardNumberTxt.text = rewardNum
        if pointNum == selectPoint then
            self.m_system.rewardScoreNumber = rewardNum
            cell.stateController:SetState("Select") 
            cell.animationWrapper:PlayInAnimation()
            self:_SetRewardPointCellNumberImg(cell, pointNum)
        else
            cell.stateController:SetState("Normal")
        end
    end)

    local maxNode = self.view.rewardPointMaxNode
    local maxRewardNum = math.floor(Tables.gambleBattleConst.pointAwardList[MAX_POINT_NUMBER - 1] * awardMultiplierPercent / 100)
    self:_SetRewardPointCellNumberImg(maxNode, MAX_POINT_NUMBER)
    maxNode.rewardNumberTxt.text = maxRewardNum
    if isOverMax then
        self.m_system.rewardScoreNumber = maxRewardNum
        maxNode.animationWrapper:PlayInAnimation()
        maxNode.stateController:SetState("Select")
    else
        maxNode.stateController:SetState("Normal")
        if self.m_curPointNumber <= 0 then
            self.m_system.rewardScoreNumber = 0
        end
    end

    
    self:_StartTimer(0, function()
        self:_ScrollRewardPointCellsToSelected(selectPoint, isOverMax)
    end)
end


GambleBattleMainCtrl._HandleDrawCardVxPost = HL.Method() << function(self)
    self:_UpdateRewardPointCells() 
    self:_UpdateEnemyCells()
    self:_UpdateRemainCardCells()
    self:_UpdateTopMiddleTipInfo() 
    self:_UpdateHandCardNode() 
    self:_UpdateChallengeBtnState()
end


GambleBattleMainCtrl._UpdateHandCardNode = HL.Method() << function(self)
    local node = self.view.handCardNode
    
    local todayData = self:_GetHandTypeDataById(self.m_system.bonusHandType)
    local todayName = todayData and self:_GetHandTypeName(todayData) or ""
    node.todayHandText.text = I18nUtils.CombineStringWithLanguageSpilt("", todayName)

    local effectiveData, isMatchToday = self:_GetEffectiveHandTypeData()
    if not effectiveData then
        
        node.stateController:SetState("Empty")
        node.detailsTxt.text = Language.LUA_GAMBLE_BATTLE_MAIN_CARD_EMPTY_TIP
        self.m_lastHandCardState = "Empty"
        self.m_lastHandType = 0
        return
    end

    
    node.stateController:SetState("Normal")
    local nextState = isMatchToday and "HandBonusBenefit" or "HandBenefit"
    local nextHandType = self.m_system.handType
    node.stateController:SetState(nextState)
    node.cardTxt.text = I18nUtils.CombineStringWithLanguageSpilt("", self:_GetHandTypeName(effectiveData))
    
    if self.m_lastHandCardState ~= nextState or self.m_lastHandType ~= nextHandType then
        node.handCardAnim:ClearTween(false)
        AudioAdapter.PostEvent(isMatchToday and "Au_UI_Event_GambleMeetCondition_Yellow"
            or "Au_UI_Toast_GambleMeetCondition_Blue")
        node.handCardAnim:PlayWithTween("gamblebattlemainhandcard_change", nil, CS.Beyond.UI.UIConst.AnimationState.Others)
    end
    self.m_lastHandCardState = nextState
    self.m_lastHandType = nextHandType

    node.effectiveHandText.text = string.format(Language.LUA_GAMBLE_BATTLE_MAIN_CARD_EFFECTIVE_HAND,
        self:_GetHandTypeName(effectiveData))

    
    local benefit = isMatchToday and effectiveData.bonusBenefit or effectiveData.handTypeBenefit
    node.bonusText.text = string.format(Language.LUA_GAMBLE_BATTLE_MAIN_CARD_BONUS_RATE,
        self:_FormatComboRate(benefit / 100))

    
    node.detailsTxt:SetAndResolveTextStyle(string.format(Language.LUA_GAMBLE_BATTLE_MAIN_CARD_ENEMY_BUFF,self:_GetEnemyBuffDesc(effectiveData, isMatchToday)))
end


GambleBattleMainCtrl._GetHandTypeDataById = HL.Method(HL.Number).Return(HL.Any) << function(self, handTypeId)
    if handTypeId == 0 then
        return nil
    end
    local ok, data = Tables.gambleBattleHandTypeTable:TryGetValue(handTypeId)
    if ok then
        return data
    end
    return nil
end


GambleBattleMainCtrl._GetEffectiveHandTypeData = HL.Method().Return(HL.Any, HL.Boolean) << function(self)
    local data = self:_GetHandTypeDataById(self.m_system.handType)
    if not data then
        return nil, false
    end
    return data, self.m_system.isMatchHandType == true
end

GambleBattleMainCtrl._GetHandTypeName = HL.Method(HL.Any).Return(HL.String) << function(self, handTypeData)
    local handTypeName = handTypeData.handTypeName
    if type(handTypeName) == "string" then
        return handTypeName
    end
    if handTypeName and handTypeName.GetText then
        return handTypeName:GetText()
    end
    return ""
end


GambleBattleMainCtrl._GetEnemyBuffDesc = HL.Method(HL.Any, HL.Boolean).Return(HL.String) << function(self, handTypeData, useEnhanced)
    local buffIds = useEnhanced and handTypeData.handTypeBuffPlusId or handTypeData.handTypeBuffId
    local parts = {}
    if buffIds then
        for _, buffId in pairs(buffIds) do
            local ok, buffData = Tables.gambleBattleEnemyBuffTable:TryGetValue(buffId)
            if ok and buffData.desc and buffData.desc ~= "" then
                table.insert(parts, buffData.desc)
            end
        end
    end
    return table.concat(parts, "")
end


GambleBattleMainCtrl._FormatComboRate = HL.Method(HL.Number).Return(HL.String) << function(self, rate)
    if rate == math.floor(rate) then
        return tostring(math.floor(rate))
    end
    return string.format("%.1f", rate)
end

HL.Commit(GambleBattleMainCtrl)
