local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local COUNTDOWN_TICK_SEC = 0.2

InnCountDown = HL.Class('InnCountDown', UIWidgetBase)

InnCountDown.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnCountDown.m_countdownCoroutine = HL.Field(HL.Thread)

InnCountDown.m_countdownIsWarning = HL.Field(HL.Any)

InnCountDown.m_wrapUpCountdownIsWarning = HL.Field(HL.Any)


InnCountDown._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_INN_GAME_TIME_WRAP_UP_CHANGED, function()
        self:_UpdateGameTimeWrapUp()
    end)
    self:RegisterMessage(MessageConst.ON_INN_RESUME_GAME, function()
        self:_RefreshCountdown()
    end)
end

InnCountDown.InitInnCountDown = HL.Method() << function(self)
    self:_FirstTimeInit()

    self.m_innSystem = GameInstance.player.innSystem
    self.m_countdownIsWarning = nil
    self.m_wrapUpCountdownIsWarning = nil
    self:_UpdateGameTimeWrapUp()
    self:_RefreshCountdown()

    if self.m_countdownCoroutine then
        self.m_countdownCoroutine = self:_ClearCoroutine(self.m_countdownCoroutine)
    end
    self.m_countdownCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(COUNTDOWN_TICK_SEC)
            self:_RefreshCountdown()
        end
    end)
end

InnCountDown._RefreshCountdown = HL.Method() << function(self)
    local gameState = self.m_innSystem and self.m_innSystem.gameState
    if gameState == nil then
        return
    end

    local elapsedMs = gameState.elapsedTimeMS
    if not gameState.isPaused and not gameState.isGameTimeStopped then
        local nowMs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
        elapsedMs = elapsedMs + math.max(0, nowMs - gameState.timeStampMS)
    end

    if gameState.wrapUp then
        local totalSec = Tables.innManagementConst.wrapUpTime
        local warningSec = Tables.innManagementConst.warningWrapUpTime

        local leftSec = math.max(0, totalSec - elapsedMs / 1000)

        self.view.timeRemainingTxt.text = UIUtils.getSecondsLeftTime(leftSec)

        local isWarning = leftSec <= warningSec
        if isWarning ~= self.m_wrapUpCountdownIsWarning then
            self.m_wrapUpCountdownIsWarning = isWarning
            self.view.countDownOverNode:SetState(isWarning and "Warning" or "Normal")
        end
    else
        local totalSec = self.m_innSystem:GetPlayTime()
        local warningSec = Tables.innManagementConst.warningPlayTime

        local leftSec = math.max(0, totalSec - elapsedMs / 1000)

        self.view.timeNumTxt.text = UIUtils.getLeftTimeToSecond(leftSec)
        self.view.timeBar.fillAmount = totalSec > 0 and leftSec / totalSec or 0

        local isWarning = leftSec <= warningSec
        if isWarning ~= self.m_countdownIsWarning then
            self.m_countdownIsWarning = isWarning
            self.view.countDownNode:SetState(isWarning and "Warning" or "Normal")
        end
    end
end

InnCountDown._UpdateGameTimeWrapUp = HL.Method() << function(self)
    local wrapUp = self.m_innSystem and self.m_innSystem.gameState and self.m_innSystem.gameState.wrapUp or false
    self.view.countDownNode.gameObject:SetActiveIfNecessary(not wrapUp)
    self.view.countDownOverNode.gameObject:SetActiveIfNecessary(wrapUp)
end

HL.Commit(InnCountDown)
return InnCountDown
