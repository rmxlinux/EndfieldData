local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleSubSettlement


local BOOST_SCORE_THRESHOLD = 10000

GambleBattleSubSettlementCtrl = HL.Class('GambleBattleSubSettlementCtrl', uiCtrl.UICtrl)






GambleBattleSubSettlementCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DUNGEON_RESTART_FINISHED] = '_OnDungeonRestartFinished',
    [MessageConst.ON_DUNGEON_RESTART_ABORTED] = '_OnDungeonRestartAborted',
    [MessageConst.ON_CLOSE_GAMBLE_BATTLE_MAIN_FOR_SETTLEMENT] = '_OnCloseMainForSettlement',
    [MessageConst.ON_GAMBLE_BATTLE_MAIN_ANIMATION_IN_FINISHED] = '_OnGambleBattleMainAnimationInFinished',
}

GambleBattleSubSettlementCtrl.m_system = HL.Field(HL.Any)

GambleBattleSubSettlementCtrl.m_handled = HL.Field(HL.Boolean) << false

GambleBattleSubSettlementCtrl.m_restartFinished = HL.Field(HL.Boolean) << false

GambleBattleSubSettlementCtrl.m_mainAnimationInFinished = HL.Field(HL.Boolean) << false


GambleBattleSubSettlementCtrl.ShowGambleBattleSubSettlement = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonSettlement", function()
        UIManager:Open(PANEL_ID, args)
    end, function()
        if UIManager:IsShow(PANEL_ID) then
            UIManager:Close(PANEL_ID)
        end
    end)
end


GambleBattleSubSettlementCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_system = GameInstance.player.gambleBattleSystem
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    arg = arg or {}
    self.m_handled = false
    self.m_restartFinished = false
    self.m_mainAnimationInFinished = false

    local totalPoint = self.m_system.gamblingDungeonTotalPoint
    local nextRateText = string.format("×%.1f", math.floor(totalPoint / BOOST_SCORE_THRESHOLD) / 10 + 1)

    self.view.addRewardNum.text = string.format("+%s", self.m_system.gamblingDungeonAddPoint)
    self.view.nextRateNum.text = "×1"
    self.view.newNextRateNum.text = nextRateText
    self.view.haveRewardNum.text = totalPoint

    self:_TryPlayBoostInAnimation(totalPoint, nextRateText)

    self:_UpdateProgressText(arg)

    self.view.retreatBtn.onClick:RemoveAllListeners()
    self.view.retreatBtn.onClick:AddListener(function()
        self:_OnRetreat()
    end)

    self.view.continueBtn.onClick:RemoveAllListeners()
    self.view.continueBtn.onClick:AddListener(function()
        self:_OnContinue()
    end)

    
    self.view.countdownTxt.gameObject:SetActiveIfNecessary(false)
    self:_RefreshCleaningState(false)
end


GambleBattleSubSettlementCtrl._TryPlayBoostInAnimation = HL.Method(HL.Number, HL.String) << function(self, totalPoint, nextRateText)
    self.view.simulationTxt.text = string.format("(%s × 10%%) + 100%%", math.floor(totalPoint / BOOST_SCORE_THRESHOLD))
    self.view.simulationTxtResult.text = nextRateText

    if totalPoint >= BOOST_SCORE_THRESHOLD then
        self.view.ani:PlayInAnimation()
    else
        
        self.view.simulationTxt.transform.parent.gameObject:SetActiveIfNecessary(false)
        self.view.nextRateNum.text = nextRateText
        self.view.newNextRateNum.text = nextRateText
    end
end


GambleBattleSubSettlementCtrl._RefreshCleaningState = HL.Method(HL.Boolean) << function(self, isCleaning)
    self.view.loadingText.gameObject:SetActiveIfNecessary(isCleaning)
    self.view.retreatBtn.gameObject:SetActiveIfNecessary(not isCleaning)
    self.view.continueBtn.gameObject:SetActiveIfNecessary(not isCleaning)
end

GambleBattleSubSettlementCtrl._UpdateProgressText = HL.Method(HL.Table) << function(self, arg)
    local curRound = self.m_system.gamblingDungeonRoundIndex + 1
    local totalRound = Tables.GambleBattleConst.dungeonContinuousChallengeTimes
    self.view.progressTxt.text = string.format(Language.LUA_GAMBLE_BATTLE_SUB_SETTLEMENT_PROGRESS, curRound, totalRound)
end



GambleBattleSubSettlementCtrl._OnDungeonRestartFinished = HL.Method(HL.Table) << function(self, args)
    
    self.m_restartFinished = true
    self:_TryCloseAfterRestart()
end


GambleBattleSubSettlementCtrl._OnGambleBattleMainAnimationInFinished = HL.Method() << function(self)
    self.m_mainAnimationInFinished = true
    self:_TryCloseAfterRestart()
end

GambleBattleSubSettlementCtrl._TryCloseAfterRestart = HL.Method() << function(self)
    if self.m_restartFinished and self.m_mainAnimationInFinished then
        UIManager:Close(PANEL_ID)
    end
end


GambleBattleSubSettlementCtrl._OnDungeonRestartAborted = HL.Method(HL.Table) << function(self, args)
    UIManager:Close(PANEL_ID)
end

GambleBattleSubSettlementCtrl._OnContinue = HL.Method() << function(self)
    if self.m_handled then
        return
    end
    ActivityUtils.GameEventLogGambleActivityVisit("click_continue_gamble")
    self.m_handled = true

    local activity = GameInstance.player.activitySystem:GetActivity(Tables.GambleBattleConst.gambleBattleActivityId)
    if not activity then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_ACTIVITY_END)
        
        self:_StartTimer(1.5, function()
            GameInstance.dungeonManager:LeaveDungeon()
        end, true)
        return
    end

    
    self.m_system:RequestResetDungeon(true)

    
    self:_RefreshCleaningState(true)
end


GambleBattleSubSettlementCtrl._OnRetreat = HL.Method() << function(self)
    if self.m_handled then
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = string.format(Language.LUA_GAMBLE_BATTLE_SETTLE_IN_POPUP_CONTENT, self.m_system.gamblingDungeonTotalPoint),
        confirmText = Language.LUA_GAMBLE_BATTLE_POPUP_CONFIRM_TEXT,
        cancelText = Language.LUA_GAMBLE_BATTLE_POPUP_CANCEL_TEXT,
        onConfirm = function()
            if self.m_handled then
                return
            end
            self.m_handled = true
            self.m_system:RequestDoCompletion(true, true)
        end,
    })
end


GambleBattleSubSettlementCtrl._OnCloseMainForSettlement = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    UIManager:Close(PANEL_ID)
end

GambleBattleSubSettlementCtrl.OnClose = HL.Override() << function(self)
    
    GameInstance.player.gambleBattleSystem:SetPendingSettlement(false)
end

HL.Commit(GambleBattleSubSettlementCtrl)
