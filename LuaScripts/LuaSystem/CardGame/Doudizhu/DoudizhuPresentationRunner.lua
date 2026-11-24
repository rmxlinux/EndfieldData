

local PRESENTATION_WATCHDOG_SECONDS = 15
local PresentationType = CS.Beyond.Gameplay.DoudizhuPresentationType

DoudizhuPresentationRunner = HL.Class('DoudizhuPresentationRunner')

DoudizhuPresentationRunner.m_owner = HL.Field(HL.Any)
DoudizhuPresentationRunner.m_queue = HL.Field(HL.Table)
DoudizhuPresentationRunner.m_playingItem = HL.Field(HL.Table)
DoudizhuPresentationRunner.m_stage = HL.Field(HL.Table)
DoudizhuPresentationRunner.m_nextBatchTimer = HL.Field(HL.Number) << -1
DoudizhuPresentationRunner.m_timerEpoch = HL.Field(HL.Number) << 0
DoudizhuPresentationRunner.m_timerOwner = HL.Field(HL.Table)
DoudizhuPresentationRunner.m_pendingDealCount = HL.Field(HL.Number) << 0

DoudizhuPresentationRunner.DoudizhuPresentationRunner = HL.Constructor(HL.Any) << function(self, owner)
    self.m_owner = owner
    self.m_queue = {}
    self.m_timerOwner = {}
end

DoudizhuPresentationRunner.IsBusy = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_playingItem ~= nil or #self.m_queue > 0
end

DoudizhuPresentationRunner.HasPendingDeal = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_pendingDealCount > 0
end

DoudizhuPresentationRunner.Reset = HL.Method(HL.Opt(HL.String)) << function(self, reason)
    self:CancelActive(false, reason or 'Reset')
    self.m_queue = {}
    self.m_pendingDealCount = 0
end


DoudizhuPresentationRunner.SetPending = HL.Method(HL.Table) << function(self, batches)
    self.m_queue = {}
    self.m_pendingDealCount = 0
    for index, batch in ipairs(batches) do
        self.m_queue[index] = {
            localEventId = batch.localEventId,
            batch = batch,
            fastForward = index < #batches or self.m_owner:ShouldFastForwardPresentation(batch),
        }
        if batch.type == PresentationType.Deal then
            self.m_pendingDealCount = self.m_pendingDealCount + 1
        end
    end
end

DoudizhuPresentationRunner.Enqueue = HL.Method(HL.Any) << function(self, batch)
    local hadWork = self:IsBusy()
    local item = {
        localEventId = batch.localEventId,
        batch = batch,
        fastForward = self.m_owner:ShouldFastForwardPresentation(batch),
    }
    if batch.type == PresentationType.Deal then
        self.m_pendingDealCount = self.m_pendingDealCount + 1
    end
    
    self.m_queue[#self.m_queue + 1] = item
    if hadWork and self.m_owner:CanFastForwardOnNewEvent() then
        local current = self.m_playingItem
        local finishDealFirst = current ~= nil and current.batch.type == PresentationType.Deal
                and self.m_owner:ShouldFinishDealBeforePresentation(batch)
        if not finishDealFirst then
            self:MarkQueuedFastForward()
            self:FastForwardCurrent('NextServerEvent')
        end
    end
    self:TryPlayNext()
end

DoudizhuPresentationRunner.MarkQueuedFastForward = HL.Method() << function(self)
    for _, item in ipairs(self.m_queue) do
        item.fastForward = true
    end
end

DoudizhuPresentationRunner.TryPlayNext = HL.Method() << function(self)
    if self.m_nextBatchTimer >= 0 then
        TimerManager:ClearTimer(self.m_nextBatchTimer)
        self.m_nextBatchTimer = -1
    end
    if not self.m_owner:CanConsumePresentations() or self.m_playingItem ~= nil then
        return
    end
    if not self:_DrainFastForwardQueue() then
        return
    end
    
    if not self.m_owner:CanConsumePresentations() then
        return
    end
    local item = table.remove(self.m_queue, 1)
    if item == nil then
        self.m_owner:OnPresentationQueueAllDone()
        return
    end
    self.m_playingItem = item
    self:_PlayItem(item)
end

DoudizhuPresentationRunner._PrepareItem = HL.Method(HL.Table, HL.String) << function(self, item, reason)
    local owner = self.m_owner
    local previousState = owner:GetFlowState()
    if not owner:_PrepareFlowForPresentation(item.batch) then
        logger.error('斗地主表现阶段转换失败')
    end
    item.hudCommand = owner:_BuildHudCommand(item, previousState)
    owner:_RefreshHudByState(reason, item.hudCommand, item.hudCommand.viewModel)
end

DoudizhuPresentationRunner._DrainFastForwardQueue = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_queue[1] == nil or not self.m_queue[1].fastForward then
        return true
    end
    local items = {}
    local ok, err = xpcall(function()
        while self.m_queue[1] ~= nil and self.m_queue[1].fastForward do
            local item = table.remove(self.m_queue, 1)
            items[#items + 1] = item
            if item.hudCommand == nil then
                self:_PrepareItem(item, 'FastForwardEvent')
            else
                
                item.hudCommand.fastForward = true
                self.m_owner:_RefreshHudByState('FastForwardEvent', item.hudCommand)
            end
        end
        self.m_owner:RebuildPresentation()
        for _, item in ipairs(items) do
            if not self:_CompleteItem(item) then
                logger.error('斗地主快进事件完成失败')
            end
        end
        self.m_owner:_RefreshHudByState('FastForwardDrain')
    end, debug.traceback)
    if not ok then
        self:_ReportFailure('队列快进失败', err)
        return false
    end
    return true
end

DoudizhuPresentationRunner._PlayItem = HL.Method(HL.Table) << function(self, item)
    local ok, err = xpcall(function()
        self:_PrepareItem(item, 'ServerEvent')
        self.m_owner:_PlayHudProgressToast(item.hudCommand)
    end, debug.traceback)
    if not ok then
        self:_ReportFailure('准备表现失败', err)
        return
    end
    self:_RunStage(item, 'Play3D', function(finish)
        return self.m_owner:_PlayDefaultPresentationEffect(item.batch, item.hudCommand, finish)
    end, function()
        self:_RunStage(item, 'PlayCommandHud', function(finish)
            return self.m_owner:_PlayHudCommand(item.hudCommand, finish)
        end, function()
            self:_FinishItem(item)
        end)
    end)
end


DoudizhuPresentationRunner._RunStage = HL.Method(HL.Table, HL.String, HL.Function, HL.Function) << function(self, item, stageName, run, onDone)
    if self.m_playingItem ~= item then
        return
    end
    local stage = { name = stageName, completed = false }
    self.m_stage = stage
    local finish = function()
        if self.m_stage ~= stage or self.m_playingItem ~= item then
            return
        end
        stage.completed = true
        self.m_stage = nil
        self:_ClearTimers()
        onDone()
    end
    self:StartTimer(PRESENTATION_WATCHDOG_SECONDS, function()
        logger.error('[斗地主][表现] watchdog 超时，快进当前事件：' .. stageName)
        self:FastForwardCurrent('Watchdog')
    end, true)
    local ok, cancelOrError = xpcall(function()
        return run(finish)
    end, debug.traceback)
    if not ok then
        self:_ReportFailure('播放阶段失败：' .. stageName, cancelOrError)
        return
    end
    if self.m_stage == stage then
        stage.cancel = cancelOrError
    elseif not stage.completed and cancelOrError ~= nil then
        
        cancelOrError(false)
    end
end

DoudizhuPresentationRunner._CancelStage = HL.Method(HL.Boolean).Return(HL.Boolean) << function(self, applyFinal)
    local stage = self.m_stage
    self.m_stage = nil
    self:_ClearTimers()
    if stage == nil or stage.cancel == nil then
        return true
    end
    local ok, err = xpcall(function()
        stage.cancel(applyFinal)
    end, debug.traceback)
    if not ok then
        self:_ReportFailure('取消表现失败', err)
    end
    return ok
end

DoudizhuPresentationRunner._CompleteItem = HL.Method(HL.Table).Return(HL.Boolean) << function(self, item)
    if item.completionNotified then
        return true
    end
    if not self.m_owner:OnOnePresentationFinished(item) then
        return false
    end
    item.completionNotified = true
    if item.batch.type == PresentationType.Deal then
        self.m_pendingDealCount = self.m_pendingDealCount - 1
    end
    return true
end

DoudizhuPresentationRunner._FinishItem = HL.Method(HL.Table) << function(self, item)
    if self.m_playingItem ~= item then
        return
    end
    self.m_playingItem = nil
    local ok, completed = xpcall(function()
        return self:_CompleteItem(item)
    end, debug.traceback)
    if not ok or not completed then
        self:_ReportFailure('事件完成失败', completed)
        return
    end
    
    self.m_owner:TriggerPhaseEventForGuide(item.batch)
    self.m_owner:_RefreshHudByState('PresentationFinished')
    self:_ScheduleNext()
end

DoudizhuPresentationRunner._ScheduleNext = HL.Method() << function(self)
    self.m_nextBatchTimer = self:StartTimer(0, function()
        self.m_nextBatchTimer = -1
        self:TryPlayNext()
    end, true)
end

DoudizhuPresentationRunner.FastForwardCurrent = HL.Method(HL.String) << function(self, reason)
    self:MarkQueuedFastForward()
    local item = self.m_playingItem
    if item == nil then
        return
    end
    if not self:_CancelStage(true) then
        return
    end
    self.m_playingItem = nil
    item.fastForward = true
    table.insert(self.m_queue, 1, item)
    
    if self:_DrainFastForwardQueue() then
        self:_ScheduleNext()
    end
end

DoudizhuPresentationRunner.CancelActive = HL.Method(HL.Boolean, HL.String) << function(self, applyFinal, reason)
    self.m_playingItem = nil
    if not self:_CancelStage(applyFinal) then
        return
    end
    if applyFinal then
        local ok, err = xpcall(function()
            self.m_owner:RebuildPresentation()
        end, debug.traceback)
        if not ok then
            self:_ReportFailure('取消后重建失败：' .. reason, err)
        end
    end
end

DoudizhuPresentationRunner.StartTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean))
        .Return(HL.Number) << function(self, duration, action, unscaled)
    local epoch = self.m_timerEpoch
    return TimerManager:StartTimer(duration, function()
        if epoch == self.m_timerEpoch then
            action()
        end
    end, unscaled, self.m_timerOwner)
end

DoudizhuPresentationRunner._ClearTimers = HL.Method() << function(self)
    
    self.m_timerEpoch = self.m_timerEpoch + 1
    TimerManager:ClearAllTimer(self.m_timerOwner)
    self.m_nextBatchTimer = -1
end

DoudizhuPresentationRunner._ReportFailure = HL.Method(HL.String, HL.Any) << function(self, reason, err)
    self.m_owner:_ReportClientFlowError(reason, {
        localEventId = self.m_playingItem and self.m_playingItem.localEventId,
        stage = self.m_stage and self.m_stage.name,
        error = err,
    })
end

DoudizhuPresentationRunner.GetSnapshot = HL.Method().Return(HL.Table) << function(self)
    return {
        queuedCount = #self.m_queue,
        playingItem = self.m_playingItem,
        timerEpoch = self.m_timerEpoch,
        stage = self.m_stage and self.m_stage.name,
        pendingDealCount = self.m_pendingDealCount,
    }
end

HL.Commit(DoudizhuPresentationRunner)

return DoudizhuPresentationRunner
