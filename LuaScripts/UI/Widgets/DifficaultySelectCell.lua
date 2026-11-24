local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local UNLOCK_ANIMATION = "dungeonbossentry_levelcell_glow"

DifficaultySelectCell = HL.Class('DifficaultySelectCell', UIWidgetBase)

DifficaultySelectCell.m_gameId = HL.Field(HL.String) << ""


DifficaultySelectCell._OnFirstTimeInit = HL.Override() << function(self)
end

DifficaultySelectCell.InitDiffcaultySelectCell = HL.Method(HL.String, HL.Function, HL.Opt(HL.Boolean)) << function(
    self, gameId, onClick, canSelectLocked)
    self:_FirstTimeInit()

    self.m_gameId = gameId
    local highDifficultySystem = GameInstance.player.highDifficultySystem

    local isUnlocked = highDifficultySystem:IsBossGameUnlocked(gameId)
    local canSelect = isUnlocked or canSelectLocked == true

    self.view.nameTxt.text = highDifficultySystem:GetBossGameDifficultyName(gameId)
    self:RefreshState()

    if self.view.button then
        self.view.button.interactable = canSelect
        self.view.button.onClick:RemoveAllListeners()
        if canSelect then
            self.view.button.onClick:AddListener(function()
                onClick()
            end)
        end
    end
end

DifficaultySelectCell.GetButton = HL.Method().Return(HL.Any) << function(self)
    self:_FirstTimeInit()
    return self.view.button
end

DifficaultySelectCell.PlayUnlockAnimation = HL.Method(HL.Opt(HL.Function)) << function(self, onComplete)
    self.view.unlockAnimationWrapper:PlayWithTween(UNLOCK_ANIMATION, function()
        if not self.gameObject.activeInHierarchy then
            return
        end
        if onComplete then
            onComplete()
        end
    end)
    
    self:RefreshState()
end

DifficaultySelectCell.RefreshState = HL.Method() << function(self)
    local highDifficultySystem = GameInstance.player.highDifficultySystem
    local gameId = self.m_gameId
    local isUnlocked = highDifficultySystem:IsBossGameUnlocked(gameId)
    local isSpecial = highDifficultySystem:IsBossGameSpecial(gameId)
    local isPassed = isUnlocked and highDifficultySystem:IsBossGamePassed(gameId)

    local stateName
    if not isUnlocked then
        stateName = "Lock"
    elseif isPassed then
        stateName = isSpecial and "SpecialComplete" or "NormalComplete"
    else
        stateName = isSpecial and "Special" or "Normal"
    end
    
    if highDifficultySystem.newUnlockedBossGameIds:Contains(gameId) then
        stateName = "Lock"
    end
    self.view.cellTypeController:SetState(stateName)
end

HL.Commit(DifficaultySelectCell)
return DifficaultySelectCell
