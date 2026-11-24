


CardGameStateMachine = HL.Class('CardGameStateMachine')

local MAX_DISPATCH_PER_DRAIN = 128
local ANY_STATE = "*"

CardGameStateMachine.m_states = HL.Field(HL.Table)
CardGameStateMachine.m_anyTransitions = HL.Field(HL.Table)
CardGameStateMachine.m_currentStateId = HL.Field(HL.String) << ""
CardGameStateMachine.m_triggerQueue = HL.Field(HL.Table)
CardGameStateMachine.m_isDispatching = HL.Field(HL.Boolean) << false
CardGameStateMachine.m_started = HL.Field(HL.Boolean) << false

CardGameStateMachine.CardGameStateMachine = HL.Constructor() << function(self)
    self.m_states = {}
    self.m_anyTransitions = {}
    self.m_triggerQueue = {}
end




CardGameStateMachine.AddState = HL.Method(HL.Table).Return(HL.Boolean) << function(self, stateDef)
    local stateId = stateDef and stateDef.id
    if type(stateId) ~= "string" or string.isEmpty(stateId) then
        logger.error("CardGameStateMachine.AddState: state id must be a non-empty string")
        return false
    end
    if self.m_states[stateId] ~= nil then
        logger.error("CardGameStateMachine.AddState: duplicate state=" .. stateId)
        return false
    end
    self.m_states[stateId] = {
        id = stateId,
        onEnter = stateDef.onEnter,
        onExit = stateDef.onExit,
        transitions = {},
    }
    return true
end






CardGameStateMachine.AddTransition = HL.Method(HL.Table).Return(HL.Boolean)
        << function(self, transitionDef)
    local fromState = transitionDef and transitionDef.from
    local triggerId = transitionDef and transitionDef.trigger
    if type(fromState) ~= "string" or string.isEmpty(fromState)
            or type(triggerId) ~= "string" or string.isEmpty(triggerId) then
        logger.error("CardGameStateMachine.AddTransition: from/trigger must be non-empty strings")
        return false
    end
    if transitionDef.internal ~= true and transitionDef.target == nil then
        logger.error(string.format(
                "CardGameStateMachine.AddTransition: target missing, from=%s trigger=%s",
                tostring(fromState), tostring(triggerId)))
        return false
    end

    local bucket
    if fromState == ANY_STATE then
        bucket = self.m_anyTransitions
    else
        local state = fromState and self.m_states[fromState] or nil
        if state == nil then
            logger.error(string.format(
                    "CardGameStateMachine.AddTransition: from state missing, from=%s trigger=%s",
                    tostring(fromState), tostring(triggerId)))
            return false
        end
        bucket = state.transitions
    end

    local transitions = bucket[triggerId]
    if transitions == nil then
        transitions = {}
        bucket[triggerId] = transitions
    end
    transitions[#transitions + 1] = {
        from = fromState,
        trigger = triggerId,
        target = transitionDef.target,
        checker = transitionDef.checker,
        action = transitionDef.action,
        internal = transitionDef.internal == true,
        reenter = transitionDef.reenter == true,
    }
    return true
end

CardGameStateMachine.Start = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean)
        << function(self, stateId, context)
    if self.m_started then
        logger.error("CardGameStateMachine.Start: already started")
        return false
    end
    if self.m_states[stateId] == nil then
        logger.error("CardGameStateMachine.Start: state missing=" .. tostring(stateId))
        return false
    end

    self.m_started = true
    self.m_currentStateId = stateId
    self.m_isDispatching = true
    local entered = self:_InvokeLifecycle(stateId, "onEnter", "Start", context, "", stateId)
    self.m_isDispatching = false
    if not entered then
        self.m_started = false
        self.m_currentStateId = ""
        self.m_triggerQueue = {}
        return false
    end
    if self.m_triggerQueue[1] ~= nil then
        local drained = self:_DrainWorkQueue()
        if not drained then
            self.m_started = false
            self.m_currentStateId = ""
            self.m_triggerQueue = {}
        end
        return drained
    end
    return true
end


CardGameStateMachine.Dispatch = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean)
        << function(self, triggerId, payload)
    if not self.m_started then
        return false
    end
    return self:_EnqueueWork({
        trigger = triggerId,
        payload = payload,
    })
end



CardGameStateMachine.CanDispatch = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean)
        << function(self, triggerId, payload)
    if not self.m_started then
        return false
    end
    local ok, transitionOrError = xpcall(function()
        return self:_FindTransition(triggerId, payload)
    end, debug.traceback)
    if not ok then
        logger.error("CardGameStateMachine.CanDispatch checker failed: "
                .. tostring(transitionOrError))
        return false
    end
    return transitionOrError ~= nil
end

CardGameStateMachine._EnqueueWork = HL.Method(HL.Table).Return(HL.Boolean) << function(self, work)
    self.m_triggerQueue[#self.m_triggerQueue + 1] = work
    if self.m_isDispatching then
        return true
    end
    return self:_DrainWorkQueue()
end

CardGameStateMachine._DrainWorkQueue = HL.Method().Return(HL.Boolean) << function(self)
    self.m_isDispatching = true
    local allHandled = true
    local processedCount = 0
    while self.m_triggerQueue[1] ~= nil do
        processedCount = processedCount + 1
        if processedCount > MAX_DISPATCH_PER_DRAIN then
            logger.error("CardGameStateMachine: trigger loop overflow")
            self.m_triggerQueue = {}
            allHandled = false
            break
        end

        local currentWork = table.remove(self.m_triggerQueue, 1)
        local ok, handledOrError = xpcall(
            function()
                return self:_ProcessTrigger(currentWork.trigger, currentWork.payload)
            end, debug.traceback)
        local handled = ok and handledOrError == true
        if not ok then
            logger.error("CardGameStateMachine dispatch failed: " .. tostring(handledOrError))
        end
        if not handled then
            self.m_triggerQueue = {}
            allHandled = false
            break
        end
    end
    self.m_isDispatching = false
    return allHandled
end

CardGameStateMachine._FindTransition = HL.Method(HL.String, HL.Opt(HL.Any))
        .Return(HL.Opt(HL.Table)) << function(self, triggerId, payload)
    local state = self.m_states[self.m_currentStateId]
    local picked = state ~= nil
            and self:_PickTransition(state.transitions[triggerId], triggerId, payload) or nil
    if picked ~= nil then
        return picked
    end
    return self:_PickTransition(self.m_anyTransitions[triggerId], triggerId, payload)
end

CardGameStateMachine._PickTransition = HL.Method(HL.Opt(HL.Table, HL.String, HL.Any))
        .Return(HL.Opt(HL.Table)) << function(self, transitions, triggerId, payload)
    if transitions == nil then
        return nil
    end
    for _, transition in ipairs(transitions) do
        
        local checkerAccepted = transition.checker == nil
                or transition.checker(self, triggerId, payload) == true
        if checkerAccepted then
            return transition
        end
    end
    return nil
end


CardGameStateMachine._ProcessTrigger = HL.Method(HL.String, HL.Opt(HL.Any))
        .Return(HL.Boolean) << function(self, triggerId, payload)
    local transition = self:_FindTransition(triggerId, payload)
    if transition == nil then
        return false
    end
    return self:_ExecuteTransition(transition, triggerId, payload)
end

CardGameStateMachine._ExecuteTransition = HL.Method(HL.Table, HL.String, HL.Opt(HL.Any))
        .Return(HL.Boolean) << function(self, transition, triggerId, payload)
    local fromStateId = self.m_currentStateId

    if transition.internal then
        return self:_InvokeTransitionAction(transition, triggerId, payload, fromStateId, fromStateId)
    end

    
    local targetStateId = transition.target
    if type(targetStateId) == "function" then
        local ok, targetOrError = xpcall(function()
            return targetStateId(self, triggerId, payload)
        end, debug.traceback)
        if not ok then
            logger.error("CardGameStateMachine target resolver failed: " .. tostring(targetOrError))
            return false
        end
        targetStateId = targetOrError
    end
    if type(targetStateId) ~= "string" then
        logger.error(string.format(
                "CardGameStateMachine: target resolver must return stateId, trigger=%s got=%s",
                tostring(triggerId), tostring(targetStateId)))
        return false
    end
    if self.m_states[targetStateId] == nil then
        logger.error("CardGameStateMachine: target state missing=" .. tostring(targetStateId))
        return false
    end

    
    
    
    local moved = targetStateId ~= fromStateId or transition.reenter == true
    if moved and not self:_InvokeLifecycle(
            fromStateId, "onExit", triggerId, payload, fromStateId, targetStateId) then
        return false
    end
    if not self:_InvokeTransitionAction(transition, triggerId, payload, fromStateId, targetStateId) then
        return false
    end

    self.m_currentStateId = targetStateId
    if moved and not self:_InvokeLifecycle(
            targetStateId, "onEnter", triggerId, payload, fromStateId, targetStateId) then
        return false
    end
    return true
end

CardGameStateMachine._InvokeTransitionAction = HL.Method(
        HL.Table, HL.String, HL.Any, HL.String, HL.String).Return(HL.Boolean)
        << function(self, transition, triggerId, payload, fromStateId, toStateId)
    if transition.action == nil then
        return true
    end
    local ok, err = xpcall(function()
        transition.action(self, triggerId, payload, fromStateId, toStateId)
    end, debug.traceback)
    if not ok then
        logger.error(string.format(
                "CardGameStateMachine transition action failed: trigger=%s error=%s",
                tostring(triggerId), tostring(err)))
        return false
    end
    return true
end

CardGameStateMachine._InvokeLifecycle = HL.Method(
        HL.String, HL.String, HL.String, HL.Any, HL.String, HL.String).Return(HL.Boolean)
        << function(self, stateId, hookName, triggerId, payload, fromStateId, toStateId)
    local state = self.m_states[stateId]
    local hook = state and state[hookName] or nil
    if hook == nil then
        return true
    end
    local ok, err = xpcall(function()
        hook(self, triggerId, payload, fromStateId, toStateId)
    end, debug.traceback)
    if not ok then
        logger.error(string.format(
                "CardGameStateMachine lifecycle failed: state=%s hook=%s error=%s",
                tostring(stateId), tostring(hookName), tostring(err)))
        return false
    end
    return true
end

CardGameStateMachine.GetState = HL.Method().Return(HL.String) << function(self)
    return self.m_currentStateId
end

HL.Commit(CardGameStateMachine)

return {
    CardGameStateMachine = CardGameStateMachine,
}
