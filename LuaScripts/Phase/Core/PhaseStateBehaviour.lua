





































PhaseStateBehaviour = HL.Class("PhaseStateBehaviour")





PhaseStateBehaviour.state = HL.Field(HL.Number) << PhaseConst.EPhaseState.Init


PhaseStateBehaviour.arg = HL.Field(HL.Any)


PhaseStateBehaviour.m_completeOnDestroy = HL.Field(HL.Boolean) << false









PhaseStateBehaviour.PhaseStateBehaviour = HL.Constructor(HL.Opt(HL.Any)) << function(self, arg)
    self.arg = arg
    self:_Init()
end



PhaseStateBehaviour._Init = HL.Method() << function(self)
    self.state = PhaseConst.EPhaseState.Init
    self.m_completeOnDestroy = false
    self:_OnInit()
end



PhaseStateBehaviour._OnInit = HL.Virtual() << function(self)
end







PhaseStateBehaviour.isActive = HL.Field(HL.Boolean) << false



PhaseStateBehaviour._ActivePhase = HL.Method() << function(self)
    local succ, log = xpcall(function()
        self.isActive = true
        self:_OnActivated()
    end, debug.traceback)
    if not succ then
        logger.critical(log)
    end
end



PhaseStateBehaviour._OnActivated = HL.Virtual() << function(self)
end




PhaseStateBehaviour._DeactivatePhase = HL.Method() << function(self)
    local succ, log = xpcall(function()
        self.isActive = false
        self:_OnDeActivated()
    end, debug.traceback)
    if not succ then
        logger.critical(log)
    end
end


PhaseStateBehaviour._OnDeActivated = HL.Virtual() << function(self)
end










PhaseStateBehaviour.TransitionIn = HL.Method(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.state = PhaseConst.EPhaseState.TransitionIn
    self:_DoTransitionInCoroutine(fastMode, args)
    if fastMode or self:_CheckAllTransitionDone() then
        self.state = PhaseConst.EPhaseState.Activated
        self:_ActivePhase()
    else
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self:_CheckAllTransitionDone()
            end)
            self.state = PhaseConst.EPhaseState.Activated
            self:_ActivePhase()
        end)
    end
end





PhaseStateBehaviour._DoTransitionInCoroutine = HL.Virtual(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end










PhaseStateBehaviour.TransitionBackToTop = HL.Method(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.state = PhaseConst.EPhaseState.TransitionBackToTop
    self:_DoTransitionBackToTopCoroutine(fastMode, args)
    if fastMode or self:_CheckAllTransitionDone() then
        self.state = PhaseConst.EPhaseState.Activated
        self:_ActivePhase()
    else
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self:_CheckAllTransitionDone()
            end)
            self.state = PhaseConst.EPhaseState.Activated
            self:_ActivePhase()
        end)
    end
end





PhaseStateBehaviour._DoTransitionBackToTopCoroutine = HL.Virtual(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end










PhaseStateBehaviour.TransitionBehind = HL.Method(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.state = PhaseConst.EPhaseState.TransitionBehind
    self:_DoTransitionBehindCoroutine(fastMode, args)
    if fastMode or self:_CheckAllTransitionDone() then
        self.state = PhaseConst.EPhaseState.Deactivated
        self:_DeactivatePhase()
    else
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self:_CheckAllTransitionDone()
            end)
            self.state = PhaseConst.EPhaseState.Deactivated
            self:_DeactivatePhase()
        end)
    end
end





PhaseStateBehaviour._DoTransitionBehindCoroutine = HL.Virtual(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end









PhaseStateBehaviour.TransitionOut = HL.Method(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.state = PhaseConst.EPhaseState.TransitionOut
    self:_DoTransitionOutCoroutine(fastMode, args)
    if fastMode or self:_CheckAllTransitionDone() then
        self.state = PhaseConst.EPhaseState.WaitRelease
        self:_DeactivatePhase()
    else
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self:_CheckAllTransitionDone()
            end)
            self.state = PhaseConst.EPhaseState.WaitRelease
            self:_DeactivatePhase()
        end)
    end
end





PhaseStateBehaviour._DoTransitionOutCoroutine = HL.Virtual(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end



PhaseStateBehaviour._CheckAllTransitionDone = HL.Virtual().Return(HL.Boolean) << function(self)
    return true
end







PhaseStateBehaviour.Destroy = HL.Method() << function(self)
    local succ, log = xpcall(function()
        self:_OnDestroy()
        self.m_completeOnDestroy = true
    end, debug.traceback)
    if not succ then
        logger.critical(log)
    end

    self:_InnerDestroy()
    self:_ClearAllCoroutine()
end




PhaseStateBehaviour._InnerDestroy = HL.Virtual() << function(self)
end




PhaseStateBehaviour._OnDestroy = HL.Virtual() << function(self)
end









PhaseStateBehaviour._StartCoroutine = HL.Method(HL.Function).Return(HL.Thread) << function(self, func)
    return CoroutineManager:StartCoroutine(func, self)
end




PhaseStateBehaviour._ClearCoroutine = HL.Method(HL.Thread).Return(HL.Any) << function(self, coroutine)
    CoroutineManager:ClearCoroutine(coroutine)
    return nil
end



PhaseStateBehaviour._ClearAllCoroutine = HL.Method() << function(self)
    CoroutineManager:ClearAllCoroutine(self)
end




HL.Commit(PhaseStateBehaviour)
