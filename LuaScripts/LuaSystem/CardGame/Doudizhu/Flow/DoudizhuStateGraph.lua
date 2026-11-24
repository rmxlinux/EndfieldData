





local StateMachineModule = require_ex('LuaSystem/CardGame/StateMachine/CardGameStateMachine')
local Define = require_ex('LuaSystem/CardGame/Doudizhu/Flow/DoudizhuFlowDefine')

local CardGameStateMachine = StateMachineModule.CardGameStateMachine
local STATE = Define.State
local TRIGGER = Define.Trigger
local PresentationType = CS.Beyond.Gameplay.DoudizhuPresentationType

local AUTHORITY_STATE = {
    [CS.Proto.DDZ_PHASE.WaitingStart] = STATE.WaitingStart,
    [CS.Proto.DDZ_PHASE.Deal] = STATE.Dealing,
    [CS.Proto.DDZ_PHASE.Bid] = STATE.Bidding,
    [CS.Proto.DDZ_PHASE.Play] = STATE.Playing,
    [CS.Proto.DDZ_PHASE.Settle] = STATE.Settling,
}

local PRESENTATION_TRIGGER = {
    [PresentationType.Deal] = TRIGGER.Deal,
    [PresentationType.BidTurn] = TRIGGER.BidTurn,
    [PresentationType.BidResult] = TRIGGER.BidResult,
    [PresentationType.Bottom] = TRIGGER.Bottom,
    [PresentationType.PlayTurn] = TRIGGER.PlayTurn,
    [PresentationType.PlayAction] = TRIGGER.PlayAction,
    [PresentationType.Pass] = TRIGGER.Pass,
    [PresentationType.Settle] = TRIGGER.Settle,
}

DoudizhuStateGraph = HL.Class('DoudizhuStateGraph')

DoudizhuStateGraph.m_machine = HL.Field(CardGameStateMachine)

DoudizhuStateGraph.DoudizhuStateGraph = HL.Constructor() << function(self)
    self.m_machine = CardGameStateMachine()
    self:_BuildStateGraph()
    if not self.m_machine:Start(STATE.Inactive) then
        logger.error("DoudizhuStateGraph 状态机异常")
    end
end

DoudizhuStateGraph._BuildStateGraph = HL.Method() << function(self)
    local machine = self.m_machine
    local stateDefinitions = {
        { id = STATE.Inactive },
        { id = STATE.Entering },
        { id = STATE.WaitingStart },
        { id = STATE.Dealing },
        { id = STATE.Bidding },
        { id = STATE.Playing },
        { id = STATE.Settling },
        { id = STATE.Recovering },
        { id = STATE.Leaving },
    }
    for _, definition in ipairs(stateDefinitions) do
        machine:AddState(definition)
    end

    local transitions = {
        
        { from = "*", trigger = TRIGGER.Reset, target = STATE.Inactive, reenter = true },
        {
            from = "*",
            trigger = TRIGGER.RecoveryRequired,
            target = STATE.Recovering,
            reenter = true,
        },
        {
            from = "*",
            trigger = TRIGGER.FullSync,
            target = STATE.Recovering,
            reenter = true,
        },
        {
            from = "*",
            trigger = TRIGGER.LeaveRoom,
            target = STATE.Leaving,
            reenter = true,
        },

        { from = STATE.Inactive, trigger = TRIGGER.EnterRoom, target = STATE.Entering },
        { from = STATE.Entering, trigger = TRIGGER.RoomReady, target = STATE.WaitingStart },

        { from = STATE.WaitingStart, trigger = TRIGGER.Deal, target = STATE.Dealing },
        {
            from = STATE.Dealing,
            trigger = TRIGGER.Deal,
            target = STATE.Dealing,
            reenter = true,
        },
        { from = STATE.Dealing, trigger = TRIGGER.BidTurn, target = STATE.Bidding },

        {
            from = STATE.Bidding,
            trigger = TRIGGER.BidTurn,
            internal = true,
        },
        { from = STATE.Bidding, trigger = TRIGGER.BidResult, internal = true },
        { from = STATE.Bidding, trigger = TRIGGER.Bottom, internal = true },
        { from = STATE.Bidding, trigger = TRIGGER.Deal, target = STATE.Dealing },
        { from = STATE.Bidding, trigger = TRIGGER.PlayTurn, target = STATE.Playing },
        { from = STATE.Playing, trigger = TRIGGER.PlayTurn, internal = true },
        { from = STATE.Playing, trigger = TRIGGER.PlayAction, internal = true },
        { from = STATE.Playing, trigger = TRIGGER.Pass, internal = true },

        { from = STATE.Settling, trigger = TRIGGER.Deal, target = STATE.Dealing },
        { from = STATE.Recovering, trigger = TRIGGER.Deal, target = STATE.Dealing },

        
        { from = STATE.WaitingStart, trigger = TRIGGER.Settle, target = STATE.Settling },
        { from = STATE.Dealing, trigger = TRIGGER.Settle, target = STATE.Settling },
        { from = STATE.Bidding, trigger = TRIGGER.Settle, target = STATE.Settling },
        { from = STATE.Playing, trigger = TRIGGER.Settle, target = STATE.Settling },
        {
            from = STATE.Settling,
            trigger = TRIGGER.Settle,
            target = STATE.Settling,
            reenter = true,
        },
        { from = STATE.Recovering, trigger = TRIGGER.Settle, target = STATE.Settling },
        {
            from = STATE.Recovering,
            trigger = TRIGGER.SnapshotApplied,
            target = function(machine, triggerId, payload)
                return AUTHORITY_STATE[payload.phase]
            end,
        },
    }
    for _, transition in ipairs(transitions) do
        machine:AddTransition(transition)
    end
end

DoudizhuStateGraph.Dispatch = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, triggerId, payload)
    return self.m_machine:Dispatch(triggerId, payload)
end

DoudizhuStateGraph.DispatchPresentation = HL.Method(HL.Any).Return(HL.Boolean)
        << function(self, batch)
    if batch == nil then
        return false
    end
    local triggerId = PRESENTATION_TRIGGER[batch.type]
    return triggerId ~= nil and self:Dispatch(triggerId, batch)
end


DoudizhuStateGraph.ApplyAuthoritySnapshot = HL.Method(CS.Proto.DDZ_PHASE, HL.Opt(HL.Any))
        .Return(HL.Boolean) << function(self, phase, context)
    return self:Dispatch(TRIGGER.SnapshotApplied, { phase = phase, context = context })
end


DoudizhuStateGraph.Reset = HL.Method(HL.Opt(HL.String))
        .Return(HL.Boolean) << function(self, reason)
    return self:Dispatch(TRIGGER.Reset, { reason = reason or "Reset" })
end

DoudizhuStateGraph.GetState = HL.Method().Return(HL.String) << function(self)
    return self.m_machine:GetState()
end

DoudizhuStateGraph.IsIn = HL.Method(HL.String).Return(HL.Boolean) << function(self, state)
    return self.m_machine:GetState() == state
end

HL.Commit(DoudizhuStateGraph)

return {
    State = STATE,
    Trigger = TRIGGER,
    Graph = DoudizhuStateGraph,
}
