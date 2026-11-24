



local Queue = require_ex('Common/Utils/DataStructure/Queue')

local ActionEntryType = {
    Normal = 1,
    Finally = 2,
    OnlyInterrupt = 3,
}

CardGameAnimQueue = HL.Class('CardGameAnimQueue')

CardGameAnimQueue.m_pendingActionEntries = HL.Field(Queue)
CardGameAnimQueue.m_running = HL.Field(HL.Boolean) << false

CardGameAnimQueue.m_blockPlayCount = HL.Field(HL.Number) << 0

CardGameAnimQueue.m_pauseKeys = HL.Field(HL.Table)

CardGameAnimQueue.m_clearGen = HL.Field(HL.Number) << 0
CardGameAnimQueue.m_skipNormal = HL.Field(HL.Boolean) << false


CardGameAnimQueue.m_pumping = HL.Field(HL.Boolean) << false
CardGameAnimQueue.m_needPump = HL.Field(HL.Boolean) << false

CardGameAnimQueue.CardGameAnimQueue = HL.Constructor() << function(self)
    self.m_pendingActionEntries = Queue()
    self.m_pauseKeys = {}
end



CardGameAnimQueue.Enqueue = HL.Method(HL.Function) << function(self, action)
    self:_EnqueuePendingActionEntry(action, ActionEntryType.Normal)
end



CardGameAnimQueue.EnqueueFinallyAction = HL.Method(HL.Function) << function(self, action)
    self:_EnqueuePendingActionEntry(action, ActionEntryType.Finally)
end



CardGameAnimQueue.EnqueueOnlyInterruptAction = HL.Method(HL.Function) << function(self, action)
    self:_EnqueuePendingActionEntry(action, ActionEntryType.OnlyInterrupt)
end


CardGameAnimQueue.Pause = HL.Method(HL.String) << function(self, key)
    self.m_pauseKeys[key] = true
end


CardGameAnimQueue.Resume = HL.Method(HL.String) << function(self, key)
    self.m_pauseKeys[key] = nil
    self:TryRunNext()
end

CardGameAnimQueue.IsPaused = HL.Method().Return(HL.Boolean) << function(self)
    return next(self.m_pauseKeys) ~= nil
end


CardGameAnimQueue.GetPendingCount = HL.Method().Return(HL.Number) << function(self)
    return self.m_pendingActionEntries:Count()
end


CardGameAnimQueue.SetSkipNormal = HL.Method(HL.Boolean) << function(self, isSkip)
    self.m_skipNormal = isSkip
    self:TryRunNext()
end

CardGameAnimQueue._EnqueuePendingActionEntry = HL.Method(HL.Function, HL.Number) << function(self, action, entryType)
    self.m_pendingActionEntries:Push({
        action = action,
        entryType = entryType,
    })
    self:TryRunNext()
end




CardGameAnimQueue.Clear = HL.Method(HL.Opt(HL.Boolean, HL.Boolean))
        << function(self, isRunInterrupt, isRunFinally)
    if isRunInterrupt == nil then
        isRunInterrupt = true
    end
    if isRunFinally == nil then
        isRunFinally = true
    end

    self.m_blockPlayCount = self.m_blockPlayCount + 1
    local toRun = {}
    while not self.m_pendingActionEntries:Empty() do
        local entry = self.m_pendingActionEntries:Pop()
        local entryType = entry.entryType
        if entryType == ActionEntryType.OnlyInterrupt and isRunInterrupt then
            table.insert(toRun, entry)
        elseif entryType == ActionEntryType.Finally and isRunFinally then
            table.insert(toRun, entry)
        end
    end
    self.m_running = false
    self.m_clearGen = self.m_clearGen + 1
    for i = 1, #toRun do
        local entry = toRun[i]
        if entry.action then
            self:_SafeRunAction(entry.action)
        end
    end
    self.m_blockPlayCount = self.m_blockPlayCount - 1
    if self.m_blockPlayCount == 0 then
        self:TryRunNext()
    end
end


CardGameAnimQueue._SafeRunAction = HL.Method(HL.Function, HL.Opt(HL.Function)).Return(HL.Boolean)
        << function(self, action, finish)
    local succ, log = xpcall(action, debug.traceback, finish)
    if not succ then
        logger.error("CardGameAnimQueue action 执行出错: " .. tostring(log))
    end
    return succ
end



CardGameAnimQueue.TryRunNext = HL.Method() << function(self)
    if self.m_pumping then
        self.m_needPump = true
        return
    end
    self.m_pumping = true
    repeat
        self.m_needPump = false
        self:_RunHead()
    until not self.m_needPump
    self.m_pumping = false
end


CardGameAnimQueue._RunHead = HL.Method() << function(self)
    if self:IsPaused() or self.m_blockPlayCount > 0 or self.m_running or self.m_pendingActionEntries:Empty() then
        return
    end
    local entry = self.m_pendingActionEntries:Pop()
    local entryType = entry.entryType
    if entryType ~= ActionEntryType.Normal or self.m_skipNormal then
        
        if entryType == ActionEntryType.Finally
                or (entryType == ActionEntryType.OnlyInterrupt and self.m_skipNormal) then
            self:_SafeRunAction(entry.action)
        end
        self.m_needPump = true
        return
    end

    self.m_running = true
    
    local isFinished = false
    local gen = self.m_clearGen
    local function finish()
        if isFinished or gen ~= self.m_clearGen then
            return
        end
        isFinished = true
        self.m_running = false
        self:TryRunNext()
    end
    if not self:_SafeRunAction(entry.action, finish) then
        finish()
    end
end

HL.Commit(CardGameAnimQueue)
return CardGameAnimQueue
