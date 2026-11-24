
CardGameStateBase = HL.Class('CardGameStateBase')

CardGameStateBase.m_owner = HL.Field(HL.Any)
CardGameStateBase.m_stateId = HL.Field(HL.String) << ""

CardGameStateBase.CardGameStateBase = HL.Constructor(HL.Any, HL.String) << function(self, owner, stateId)
    self.m_owner = owner
    self.m_stateId = stateId
end

CardGameStateBase.GetStateId = HL.Method().Return(HL.String) << function(self)
    return self.m_stateId
end



CardGameStateBase.GetDefinitions = HL.Virtual().Return(HL.Table) << function(self)
    return {
        {
            id = self.m_stateId,
            onEnter = function(machine, triggerId, payload, fromState, toState)
                self:OnEnter(triggerId, payload, fromState, toState)
            end,
            onExit = function(machine, triggerId, payload, fromState, toState)
                self:OnExit(triggerId, payload, fromState, toState)
            end,
        },
    }
end


CardGameStateBase.GetTransitions = HL.Virtual().Return(HL.Table) << function(self)
    return {}
end

CardGameStateBase.OnEnter = HL.Virtual(HL.String, HL.Any, HL.String, HL.String) << function(self, triggerId, payload, fromState, toState)
end

CardGameStateBase.OnExit = HL.Virtual(HL.String, HL.Any, HL.String, HL.String) << function(self, triggerId, payload, fromState, toState)
end

HL.Commit(CardGameStateBase)
return CardGameStateBase
