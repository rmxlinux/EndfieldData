local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')




InnRadioSystem = HL.Class('InnRadioSystem', LuaSystemBase.LuaSystemBase)

local CondType = GEnums.InnConditionType
local MatchLevel = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel
local GuestTypeSpecial = CS.Proto.INN_MANAGEMENT_GUEST_TYPE.GuestTypeSpecial



InnRadioSystem.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)


InnRadioSystem.m_curShow = HL.Field(HL.Any)


InnRadioSystem.m_waitingQueue = HL.Field(HL.Table)


InnRadioSystem.m_pendingCandidates = HL.Field(HL.Table)


InnRadioSystem.m_cooldownEndTime = HL.Field(HL.Table)


InnRadioSystem.m_rowsByCondition = HL.Field(HL.Table)


InnRadioSystem.m_queueSortFunc = HL.Field(HL.Function)


InnRadioSystem.m_lateTickKey = HL.Field(HL.Any)



InnRadioSystem.m_prevComboStage = HL.Field(HL.Number) << 0

InnRadioSystem.m_prevRushPercent = HL.Field(HL.Number) << 0

InnRadioSystem.m_kitchenBlocked = HL.Field(HL.Table)

InnRadioSystem.m_consecutiveCheckoutCount = HL.Field(HL.Number) << 0

InnRadioSystem.m_serveFailCount = HL.Field(HL.Number) << 0

InnRadioSystem.m_guestFullyServedFired = HL.Field(HL.Table)

InnRadioSystem.m_specialPerfectFired = HL.Field(HL.Table)




InnRadioSystem.InnRadioSystem = HL.Constructor() << function(self)
    self.m_innSystem = GameInstance.player.innSystem
end

InnRadioSystem.OnInit = HL.Override() << function(self)
    self.m_queueSortFunc = function(a, b)
        if a.row.priority ~= b.row.priority then
            return a.row.priority < b.row.priority
        end
        return a.addTime < b.addTime
    end
end

InnRadioSystem.OnRelease = HL.Override() << function(self)
    self:ReleaseInnRadio()
end

InnRadioSystem.PrepareInnRadio = HL.Method() << function(self)
    self.m_rowsByCondition = {}
    self:_BuildConditionIndex()
    self:_ResetRuntimeState()
    logger.info("[InnRadioSystem] PrepareInnRadio")

    self:RegisterMessage(MessageConst.ON_INN_IN_RUSH_CHANGED, function(args)
        if not self.m_innSystem.isInGame then return end
        local isInRush = unpack(args)
        self:_EvalRushStart(isInRush)
    end)
    self:RegisterMessage(MessageConst.ON_INN_RUSH_STATE_CHANGED, function()
        if not self.m_innSystem.isInGame then return end
        self:_EvalRushAndCombo()
    end)
    self:RegisterMessage(MessageConst.ON_INN_KITCHEN_STATE_CHANGED, function(args)
        if not self.m_innSystem.isInGame then return end
        local kitchenId = unpack(args)
        self:_EvalKitchenBlocked(kitchenId)
    end)
    self:RegisterMessage(MessageConst.ON_INN_AUTO_CHECKOUT_CHANGED, function()
        if not self.m_innSystem.isInGame then return end
        self:_EvalConsecutiveCheckout()
    end)
    self:RegisterMessage(MessageConst.ON_INN_AUTO_SERVER_FOOD_CHANGED, function()
        if not self.m_innSystem.isInGame then return end
        
        self.m_consecutiveCheckoutCount = 0
    end)
    self:RegisterMessage(MessageConst.ON_INN_GUEST_AUTO_GET_FOOD, function(args)
        if not self.m_innSystem.isInGame then return end
        
        local deskId = unpack(args)
        self:_EvalDeskFullyServed(deskId)
    end)
    self:RegisterMessage(MessageConst.ON_INN_GUEST_GET_FOOD, function(args)
        if not self.m_innSystem.isInGame then return end
        local deskId, foodId = unpack(args)
        self:_EvalServeFailed(deskId, foodId)
        
        self:_EvalSpecialGuestPerfect(deskId)
    end)
    self:RegisterMessage(MessageConst.ON_INN_GAME_RESULT, function()
        self:_FlushAll()
    end)


    self.m_lateTickKey = LuaUpdate:Add("LateTick", function()
        self:_OnLateTick()
    end)
end

InnRadioSystem.ReleaseInnRadio = HL.Method() << function(self)
    logger.info("[InnRadioSystem] ReleaseInnRadio")
    self:_FlushAll()
    if self.m_lateTickKey then
        self.m_lateTickKey = LuaUpdate:Remove(self.m_lateTickKey)
    end
    MessageManager:UnregisterAll(self)
end



InnRadioSystem._BuildConditionIndex = HL.Method() << function(self)
    self.m_rowsByCondition = {}
    for _, data in pairs(Tables.innRadioTable) do
        local ct = data.conditionType
        if ct ~= nil and ct ~= CondType.None then
            local list = self.m_rowsByCondition[ct]
            if list == nil then
                list = {}
                self.m_rowsByCondition[ct] = list
            end
            table.insert(list, data)
        end
    end
end

InnRadioSystem._ResetRuntimeState = HL.Method() << function(self)
    self.m_prevComboStage = 0
    self.m_prevRushPercent = 0
    self.m_kitchenBlocked = {}
    self.m_consecutiveCheckoutCount = 0
    self.m_serveFailCount = 0
    self.m_guestFullyServedFired = {}
    self.m_specialPerfectFired = {}
    self.m_cooldownEndTime = {}
    self:_FlushAll()
end

InnRadioSystem._GetParamInt = HL.Method(HL.Userdata, HL.Number).Return(HL.Number) << function(self, row, luaIdx)
    local params = row.parameters
    if params == nil or params.Count == nil or luaIdx > params.Count then
        return 0
    end
    return Utils.getDynamicParamIntValue(params[CSIndex(luaIdx)])
end





InnRadioSystem._GetComboStage = HL.Method(HL.Number).Return(HL.Number) << function(self, comboCount)
    local c = Tables.innManagementConst
    if comboCount >= c.rushAddThirdStage then
        return 3
    elseif comboCount >= c.rushAddSecondStage then
        return 2
    elseif comboCount >= c.rushAddFirstStage then
        return 1
    end
    return 0
end

InnRadioSystem._GetRushPercent = HL.Method().Return(HL.Number) << function(self)
    local gs = self.m_innSystem.gameState
    if gs == nil then
        return 0
    end
    local fullK = Tables.innManagementConst.rushSum * 1000
    if fullK <= 0 then
        return 0
    end
    return gs.rushValueK / fullK * 100
end

InnRadioSystem._IsGuestFullyServed = HL.Method(HL.Userdata).Return(HL.Boolean) << function(self, guest)
    local m = guest.matches
    if m == nil or m.Count <= 0 then
        return false
    end
    for k = 1, m.Count do
        if m[CSIndex(k)] == MatchLevel.NotServed then
            return false
        end
    end
    return true
end

InnRadioSystem._AreAllPerfect = HL.Method(HL.Userdata).Return(HL.Boolean) << function(self, guest)
    local m = guest.matches
    if m == nil or m.Count <= 0 then
        return false
    end
    for k = 1, m.Count do
        if m[CSIndex(k)] ~= MatchLevel.Perfect then
            return false
        end
    end
    return true
end

InnRadioSystem._IsServedFoodSuccess = HL.Method(HL.Userdata, HL.Userdata).Return(HL.Boolean) << function(self, guest, food)
    if guest.guestType == GuestTypeSpecial then
        local reqs = guest.requirementIds
        if reqs == nil or reqs.Count <= 0 then
            return false
        end
        for k = 1, reqs.Count do
            local lvl = CS.Beyond.Gameplay.InnSystem.GetRequirementMatch(food.itemId, reqs[CSIndex(k)])
            if lvl == MatchLevel.Normal or lvl == MatchLevel.Perfect then
                return true
            end
        end
        return false
    end

    local orders = guest.orders
    if orders == nil or orders.Count <= 0 then
        return false
    end
    for k = 1, orders.Count do
        local order = orders[CSIndex(k)]
        if order.foodType == food.foodType and order.itemId == food.itemId then
            return true
        end
    end
    return false
end

InnRadioSystem._EvalRushStart = HL.Method(HL.Boolean) << function(self, isInRush)
    if not isInRush then
        return
    end
    local rows = self.m_rowsByCondition[CondType.RushStart]
    if rows then
        for _, row in ipairs(rows) do
            self:_AddCandidate(row, CondType.RushStart, nil)
        end
    end
end

InnRadioSystem._EvalRushAndCombo = HL.Method() << function(self)
    local gs = self.m_innSystem.gameState
    if gs == nil then
        return
    end

    local curStage = self:_GetComboStage(gs.comboCount)
    local comboRows = self.m_rowsByCondition[CondType.ComboStage]
    if comboRows then
        for _, row in ipairs(comboRows) do
            local stage = self:_GetParamInt(row, 1)
            if stage > 0 and self.m_prevComboStage < stage and curStage >= stage then
                self:_AddCandidate(row, CondType.ComboStage, { stage = stage })
            end
        end
    end
    self.m_prevComboStage = curStage

    local curPercent = self:_GetRushPercent()
    local rushRows = self.m_rowsByCondition[CondType.RushValueNearlyFull]
    if rushRows then
        for _, row in ipairs(rushRows) do
            local percent = self:_GetParamInt(row, 1)
            if percent > 0 and self.m_prevRushPercent < percent and curPercent >= percent then
                self:_AddCandidate(row, CondType.RushValueNearlyFull, { percent = percent })
            end
        end
    end
    self.m_prevRushPercent = curPercent
end

InnRadioSystem._EvalKitchenBlocked = HL.Method(HL.Number) << function(self, kitchenId)
    local gs = self.m_innSystem.gameState
    if gs == nil then
        return
    end
    local has, kitchen = gs.kitchenStates:TryGetValue(kitchenId)
    if not has then
        return
    end
    local prev = self.m_kitchenBlocked[kitchenId] or false
    local cur = kitchen.isBlocked
    if cur and not prev then
        local rows = self.m_rowsByCondition[CondType.KitchenBlocked]
        if rows then
            for _, row in ipairs(rows) do
                self:_AddCandidate(row, CondType.KitchenBlocked, { kitchenId = kitchenId })
            end
        end
    end
    self.m_kitchenBlocked[kitchenId] = cur
end

InnRadioSystem._EvalConsecutiveCheckout = HL.Method() << function(self)
    self.m_consecutiveCheckoutCount = self.m_consecutiveCheckoutCount + 1
    local rows = self.m_rowsByCondition[CondType.ConsecutiveCheckout]
    if rows then
        for _, row in ipairs(rows) do
            local n = self:_GetParamInt(row, 1)
            if n > 0 and self.m_consecutiveCheckoutCount == n then
                self:_AddCandidate(row, CondType.ConsecutiveCheckout, nil)
            end
        end
    end
end

InnRadioSystem._EvalServeFailed = HL.Method(HL.Number, HL.Number) << function(self, deskId, foodId)
    local gs = self.m_innSystem.gameState
    if gs == nil then
        return
    end
    local hasDesk, desk = gs.deskStates:TryGetValue(deskId)
    if not hasDesk or desk.guestId == 0 then
        return
    end
    local hasGuest, guest = gs.guestStates:TryGetValue(desk.guestId)
    if not hasGuest then
        return
    end
    local hasFood, food = gs.foods:TryGetValue(foodId)
    if not hasFood then
        return
    end

    if self:_IsServedFoodSuccess(guest, food) then
        self.m_serveFailCount = 0
    else
        self.m_serveFailCount = self.m_serveFailCount + 1
        local rows = self.m_rowsByCondition[CondType.ServeFailed]
        if rows then
            for _, row in ipairs(rows) do
                local n = self:_GetParamInt(row, 1)
                if n > 0 and self.m_serveFailCount == n then
                    self:_AddCandidate(row, CondType.ServeFailed, nil)
                end
            end
        end
    end
end

InnRadioSystem._EvalDeskFullyServed = HL.Method(HL.Number) << function(self, deskId)
    local gs = self.m_innSystem.gameState
    if gs == nil or deskId == nil or deskId == 0 then
        return
    end
    local hasDesk, desk = gs.deskStates:TryGetValue(deskId)
    if not hasDesk or desk.guestId == 0 then
        return
    end
    local guestId = desk.guestId
    local hasGuest, guest = gs.guestStates:TryGetValue(guestId)
    if not hasGuest then
        return
    end

    local fully = self:_IsGuestFullyServed(guest)
    if fully then
        if not self.m_guestFullyServedFired[guestId] then
            local rows = self.m_rowsByCondition[CondType.DeskFullyServed]
            if rows then
                for _, row in ipairs(rows) do
                    self:_AddCandidate(row, CondType.DeskFullyServed, { guestId = guestId })
                end
            end
            self.m_guestFullyServedFired[guestId] = true
        end
    else
        self.m_guestFullyServedFired[guestId] = nil
    end
end

InnRadioSystem._EvalSpecialGuestPerfect = HL.Method(HL.Number) << function(self, deskId)
    local gs = self.m_innSystem.gameState
    if gs == nil or deskId == nil or deskId == 0 then
        return
    end
    local hasDesk, desk = gs.deskStates:TryGetValue(deskId)
    if not hasDesk or desk.guestId == 0 then
        return
    end
    local guestId = desk.guestId
    local has, guest = gs.guestStates:TryGetValue(guestId)
    if not has then
        return
    end

    local isPerfect = guest.guestType == GuestTypeSpecial
        and self:_IsGuestFullyServed(guest)
        and self:_AreAllPerfect(guest)
    if isPerfect then
        if not self.m_specialPerfectFired[guestId] then
            local rows = self.m_rowsByCondition[CondType.SpecialGuestPerfect]
            if rows then
                for _, row in ipairs(rows) do
                    self:_AddCandidate(row, CondType.SpecialGuestPerfect, { guestId = guestId })
                end
            end
            self.m_specialPerfectFired[guestId] = true
        end
    else
        self.m_specialPerfectFired[guestId] = nil
    end
end





InnRadioSystem._AddCandidate = HL.Method(HL.Userdata, GEnums.InnConditionType, HL.Opt(HL.Table)) << function(self, row, condType, ctx)
    logger.info(string.format(
        "[InnRadioSystem] condition hit: rowId=%s, condType=%s, priority=%d, queueable=%s",
        row.id, tostring(condType), row.priority, tostring(row.queueable)))
    table.insert(self.m_pendingCandidates, {
        row = row,
        condType = condType,
        ctx = ctx or {},
        addTime = TimeManagerInst.unscaledTime,
    })
end

InnRadioSystem._OnLateTick = HL.Method() << function(self)
    if not self.m_innSystem.isInGame then
        if #self.m_pendingCandidates > 0 then
            self.m_pendingCandidates = {}
        end
        return
    end
    self:_FlushCandidates()
end


InnRadioSystem._FlushCandidates = HL.Method() << function(self)
    if #self.m_pendingCandidates <= 0 then
        return
    end
    local list = self.m_pendingCandidates
    self.m_pendingCandidates = {}
    table.sort(list, self.m_queueSortFunc)
    for _, cand in ipairs(list) do
        self:_ProcessCandidate(cand)
    end
end

InnRadioSystem._ProcessCandidate = HL.Method(HL.Table) << function(self, cand)
    local row = cand.row
    local now = TimeManagerInst.unscaledTime
    local cdEnd = self.m_cooldownEndTime[row.id] or 0
    local cdSec = row.coolDown / 1000
    if now < cdEnd then
        logger.info(string.format("[InnRadioSystem] skip(cd not ready): rowId=%s, remain=%.2f", row.id, cdEnd - now))
        return
    end

    if self.m_curShow == nil then
        
        logger.info(string.format("[InnRadioSystem] accept(play now): rowId=%s", row.id))
        self.m_cooldownEndTime[row.id] = now + cdSec
        self:_PlayCandidate(cand)
    elseif row.queueable then
        
        self.m_cooldownEndTime[row.id] = now + cdSec
        table.insert(self.m_waitingQueue, cand)
        table.sort(self.m_waitingQueue, self.m_queueSortFunc)
        logger.info(string.format("[InnRadioSystem] accept(enqueue): rowId=%s, queueLen=%d", row.id, #self.m_waitingQueue))
    else
        
        logger.info(string.format("[InnRadioSystem] discard(busy, not queueable): rowId=%s", row.id))
    end
end





InnRadioSystem._GetPanel = HL.Method().Return(HL.Forward("UICtrl")) << function(self)
    local isOpen, panel = UIManager:IsOpen(PanelId.InnMainHud)
    if isOpen then
        return panel
    end
    return nil
end


InnRadioSystem._ResolveRadio = HL.Method(HL.Userdata, HL.Opt(HL.String)).Return(HL.Opt(HL.String, HL.Userdata)) << function(self, row, radioId)
    if string.isEmpty(radioId) then
        local radioIds = row.radioIds
        if radioIds == nil or radioIds.Count == nil or radioIds.Count <= 0 then
            return nil, nil
        end
        radioId = radioIds[CSIndex(math.random(1, radioIds.Count))]
    end
    local has, radioData = Tables.radioTable:TryGetValue(radioId)
    if not has or radioData == nil then
        logger.error("[InnRadioSystem] radioId not in radioTable: " .. tostring(radioId))
        return radioId, nil
    end
    local list = radioData.radioSingleDataList
    if list == nil or list.Count <= 0 then
        return radioId, nil
    end
    return radioId, list[CSIndex(1)]
end

InnRadioSystem._PlayCandidate = HL.Method(HL.Table) << function(self, cand)
    local row = cand.row
    local panel = self:_GetPanel()
    if panel == nil then
        logger.info("[InnRadioSystem] play abort: InnMainHud not open")
        return
    end
    local radioId, singleData = self:_ResolveRadio(row, cand.radioId)
    if singleData == nil then
        logger.info(string.format("[InnRadioSystem] play abort(no radio data): rowId=%s", row.id))
        return
    end

    local charCount = panel:ShowRadio(singleData)

    
    local voiceId = singleData.audioOverride
    local hasDur, voiceDur = VoiceUtils.TryGetVoiceDuration(voiceId)
    if not hasDur then
        voiceId = ""
    end
    local voiceHandleId = -1
    local duration = nil
    if not string.isEmpty(voiceId) then
        local cfg = CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig(singleData.audioEffect, 1)
        voiceHandleId = VoiceManager:SpeakNarrative(voiceId, nil, cfg)
        if voiceHandleId > 0 and VoiceManager:IsVoicePlaying(voiceHandleId) then
            duration = voiceDur
        end
    end

    
    if duration == nil then
        local num = charCount / I18nUtils.GetTextSpeedFactor()
        duration = lume.clamp(num * Tables.cinematicConst.textShowDurationPerWord,
            Tables.cinematicConst.radioMinWaitTime, Tables.cinematicConst.radioMaxWaitTime)
        duration = math.max(duration, Tables.cinematicConst.radioTextMinDuration)
    end

    logger.info(string.format(
        "[InnRadioSystem] playing: rowId=%s, radioId=%s, duration=%.2f, voice=%s, charCount=%d",
        row.id, tostring(radioId), duration, string.isEmpty(voiceId) and "none" or voiceId, charCount))

    self.m_curShow = {
        cand = cand,
        radioId = radioId,
        voiceId = voiceId,
        voiceHandleId = voiceHandleId,
        timerId = -1,
    }
    self.m_curShow.timerId = self:_StartTimer(duration, function()
        self:_OnRadioFinish()
    end)
end

InnRadioSystem._OnRadioFinish = HL.Method() << function(self)
    self:_StopCur()
    self:_TryShowNext()
end


InnRadioSystem._StopCur = HL.Method() << function(self)
    local cur = self.m_curShow
    if cur == nil then
        return
    end
    local cand = cur.cand
    logger.info(string.format(
        "[InnRadioSystem] stop current: rowId=%s, condType=%s, radioId=%s, voiceId=%s, voiceHandleId=%s",
        cand and cand.row.id or "nil",
        cand and tostring(cand.condType) or "nil",
        tostring(cur.radioId),
        string.isEmpty(cur.voiceId) and "none" or cur.voiceId,
        tostring(cur.voiceHandleId)))
    if cur.timerId and cur.timerId > 0 then
        self:_ClearTimer(cur.timerId)
    end
    if cur.voiceHandleId and cur.voiceHandleId > 0 then
        VoiceManager:StopVoice(cur.voiceHandleId)
    end
    self.m_curShow = nil

    local panel = self:_GetPanel()
    if panel then
        panel:HideRadio()
    end
end


InnRadioSystem._TryShowNext = HL.Method() << function(self)
    while #self.m_waitingQueue > 0 do
        local cand = table.remove(self.m_waitingQueue, 1)
        if self:_RecheckCandidate(cand) then
            logger.info(string.format("[InnRadioSystem] dequeue play: rowId=%s", cand.row.id))
            self:_PlayCandidate(cand)
            return
        end
        logger.info(string.format("[InnRadioSystem] dequeue drop(condition no longer satisfied): rowId=%s", cand.row.id))
    end
end


InnRadioSystem._RecheckCandidate = HL.Method(HL.Table).Return(HL.Boolean) << function(self, cand)
    local gs = self.m_innSystem.gameState
    if gs == nil then
        return false
    end
    local ct = cand.condType
    local ctx = cand.ctx

    if ct == CondType.RushStart then
        return gs.isInRushTime
    elseif ct == CondType.RushValueNearlyFull then
        return self:_GetRushPercent() >= (ctx.percent or 0)
    elseif ct == CondType.ComboStage then
        return self:_GetComboStage(gs.comboCount) >= (ctx.stage or 0)
    elseif ct == CondType.KitchenBlocked then
        local has, kitchen = gs.kitchenStates:TryGetValue(ctx.kitchenId or 0)
        return has and kitchen.isBlocked
    elseif ct == CondType.DeskFullyServed then
        local has, guest = gs.guestStates:TryGetValue(ctx.guestId or 0)
        return has and self:_IsGuestFullyServed(guest)
    elseif ct == CondType.SpecialGuestPerfect then
        local has, guest = gs.guestStates:TryGetValue(ctx.guestId or 0)
        return has and guest.guestType == GuestTypeSpecial
            and self:_IsGuestFullyServed(guest) and self:_AreAllPerfect(guest)
    end

    return false
end


InnRadioSystem._FlushAll = HL.Method() << function(self)
    logger.info(string.format("[InnRadioSystem] FlushAll: queueLen=%d",
        self.m_waitingQueue and #self.m_waitingQueue or 0))
    self:_StopCur()
    self.m_waitingQueue = {}
    self.m_pendingCandidates = {}
end








InnRadioSystem.DebugPlayRadio = HL.Method(HL.String, HL.Opt(HL.String)).Return(HL.Opt(HL.String)) << function(self, rowId, radioId)
    if not self.m_innSystem.isInGame then
        return "当前不在客栈玩法中"
    end
    if self.m_lateTickKey == nil then
        return "InnRadioSystem 未 Prepare（InnMainHud 未打开）"
    end
    local has, row = Tables.innRadioTable:TryGetValue(rowId)
    if not has or row == nil then
        return "innRadioTable 里没有 " .. tostring(rowId)
    end
    if self:_GetPanel() == nil then
        return "InnMainHud 未打开"
    end
    if not string.isEmpty(radioId) then
        local available = {}
        local count = row.radioIds and row.radioIds.Count or 0
        for k = 1, count do
            available[k] = row.radioIds[CSIndex(k)]
        end
        if not lume.find(available, radioId) then
            return string.format("%s 的 radioIds 里没有 %s，可选：%s", rowId, radioId, table.concat(available, ","))
        end
    end
    self:_StopCur()
    self:_PlayCandidate({
        row = row,
        radioId = radioId,
        condType = row.conditionType,
        ctx = {},
        addTime = TimeManagerInst.unscaledTime,
    })
    if self.m_curShow == nil then
        return "radioIds 无可用 radio 数据，见 log"
    end
    return nil
end



HL.Commit(InnRadioSystem)
return InnRadioSystem
