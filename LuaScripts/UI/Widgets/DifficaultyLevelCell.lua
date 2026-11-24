local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local PROGRESS_ANIMATION = "dungeonbossentry_levelcell_glow"

DifficaultyLevelCell = HL.Class('DifficaultyLevelCell', UIWidgetBase)

DifficaultyLevelCell.m_gameId = HL.Field(HL.String) << ""


DifficaultyLevelCell._OnFirstTimeInit = HL.Override() << function(self)
end

DifficaultyLevelCell.InitDiffcaultyLevelCell = HL.Method(HL.String, HL.Boolean) << function(self, gameId, selected)
    self:_FirstTimeInit()

    self.m_gameId = gameId
    self:RefreshState()
    self.view.levelCellTypeController:SetState(selected and "Selected" or "UnSelected")
end

DifficaultyLevelCell.PlayProgressAnimation = HL.Method(HL.Opt(HL.Function)) << function(self, onComplete)
    self.view.unlockAnimationWrapper:PlayWithTween(PROGRESS_ANIMATION, function()
        if not self.gameObject.activeInHierarchy then
            return
        end
        self.view.unlockAnimationWrapper:PlayLoopAnimation()
        if onComplete then
            onComplete()
        end
    end)
    
    self:RefreshState()
end

DifficaultyLevelCell.RefreshState = HL.Method() << function(self)
    local highDifficultySystem = GameInstance.player.highDifficultySystem
    local gameId = self.m_gameId
    local isUnlocked = highDifficultySystem:IsBossGameUnlocked(gameId)
    local isSpecial = highDifficultySystem:IsBossGameSpecial(gameId)
    
    local isPassed = isUnlocked and highDifficultySystem:IsBossGamePassed(gameId)
        and highDifficultySystem.bossProgressCandidateGameId ~= gameId

    local stateName
    if not isUnlocked then
        stateName = "Lock"
    elseif isPassed then
        stateName = isSpecial and "SpecialComplete" or "NormalComplete"
    else
        stateName = isSpecial and "Special" or "Normal"
    end
    self.view.levelCellTypeController:SetState(stateName)
end

HL.Commit(DifficaultyLevelCell)
return DifficaultyLevelCell

