local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnDeskStateCell = HL.Class('InnDeskStateCell', UIWidgetBase)

InnDeskStateCell.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem) << nil

InnDeskStateCell.m_deskId = HL.Field(HL.Number) << 0

InnDeskStateCell.m_matchCellCache = HL.Field(HL.Forward("UIListCache")) << nil

InnDeskStateCell.m_foodCellCache = HL.Field(HL.Forward("UIListCache")) << nil


InnDeskStateCell.m_foodSlots = HL.Field(HL.Table) << nil

InnDeskStateCell.m_lastDeskStatus = HL.Field(HL.Any) << nil

InnDeskStateCell.m_eatingDelayTimerId = HL.Field(HL.Number) << -1

InnDeskStateCell.m_isDelayingEatingState = HL.Field(HL.Boolean) << false

InnDeskStateCell.m_progressCoroutine = HL.Field(HL.Thread) << nil

InnDeskStateCell.m_appliedGuestTypeStateName = HL.Field(HL.String) << ""




local DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS
local GUEST_TYPE = CS.Proto.INN_MANAGEMENT_GUEST_TYPE
local FOOD_TYPE = CS.Proto.INN_MANAGEMENT_FOOD_TYPE
local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel




local DESK_STATUS_STATE_NAMES = {
    [DESK_STATUS.DeskStatusEmpty] = "Empty",
    [DESK_STATUS.DeskStatusOrdering] = "Ordering",
    [DESK_STATUS.DeskStatusWaitingForEating] = "Ordered",
    [DESK_STATUS.DeskStatusEating] = "Eating",
    [DESK_STATUS.DeskStatusWaitingForPay] = "Pay",
    [DESK_STATUS.DeskStatusOrderingFailed] = "Empty",
    [DESK_STATUS.DeskStatusLeaving] = "Empty",
}


local PROGRESS_DEFAULT_FILL = 1
local DESK_PROGRESS_TICK_SEC = 1/60


local GUEST_TYPE_STATE_NAMES = {
    [GUEST_TYPE.GuestTypeNormal] = "Normal",
    [GUEST_TYPE.GuestTypeSpecial] = "Special",
}


local MATCH_STATE_NAMES = {
    [MATCH_LEVEL.NotServed] = "Empty",
    [MATCH_LEVEL.Unsatisfied] = "Failed",
    [MATCH_LEVEL.Normal] = "Normal",
    [MATCH_LEVEL.Perfect] = "Perfect",
}


InnDeskStateCell._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_INN_DESK_STATE_CHANGED, function(args)
        local deskId = unpack(args)
        if deskId == self.m_deskId and not self.m_innSystem.gameState.isEndingGame then
            self:_Refresh()
        end
    end)
    self:RegisterMessage(MessageConst.ON_INN_GUEST_STATE_CHANGED, function(args)
        local guestId = unpack(args)
        local deskState = self:_GetDeskState()
        if deskState and deskState.guestId == guestId then
            local guest = self:_GetGuestState(deskState)
            self:_RefreshMatches(guest)
            self:_RefreshOrderCells(guest)
        end
    end)
    self:RegisterMessage(MessageConst.ON_INN_AUTO_SERVER_FOOD_CHANGED, function()
        self:_RefreshServingDeco()
    end)
    self:RegisterMessage(MessageConst.ON_INN_AUTO_CHECKOUT_CHANGED, function()
        self:_RefreshAutoPayDeco()
    end)
    self:RegisterMessage(MessageConst.ON_INN_DESK_CHECK_OUT, function(args)
        self:_OnDeskCheckOut(args)
    end)
end

InnDeskStateCell._OnDestroy = HL.Override() << function(self)
    self:_ClearEatingDelay()
    if self.m_progressCoroutine then
        self.m_progressCoroutine = self:_ClearCoroutine(self.m_progressCoroutine)
    end
end

InnDeskStateCell.InitInnDeskStateCell = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    self:_ClearEatingDelay()
    self.m_lastDeskStatus = nil
    self.m_deskId = args.deskId or 0
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem or nil
    self.view.autoCheckoutNode.gameObject:SetActive(false)

    self:_Refresh()
end

InnDeskStateCell._GetDeskState = HL.Method().Return(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self)
    if not self.m_innSystem or self.m_deskId <= 0 then
        return nil
    end
    local gs = self.m_innSystem.gameState
    if not gs or not gs.deskStates then
        return nil
    end
    local has, desk = gs.deskStates:TryGetValue(self.m_deskId)
    if not has then
        return nil
    end
    return desk
end

InnDeskStateCell._GetGuestState = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)).Return(HL.Opt(CS.Beyond.Gameplay.InnSystem.GuestState)) << function(self, deskState)
    if not self.m_innSystem or not deskState or deskState.guestId <= 0 then
        return nil
    end
    local gs = self.m_innSystem.gameState
    if not gs or not gs.guestStates then
        return nil
    end
    local has, guest = gs.guestStates:TryGetValue(deskState.guestId)
    if not has then
        return nil
    end
    return guest
end

InnDeskStateCell._Refresh = HL.Method() << function(self)
    local desk = self:_GetDeskState()
    local guest = self:_GetGuestState(desk)

    self:_RefreshStateController(desk, guest)
    self:_RefreshMatches(guest)
    self:_RefreshOrderCells(guest)
    self:_RefreshAutoPayDeco()
    self:_RefreshProgress(desk)
    self:_EnsureProgressCoroutine(desk)
end





InnDeskStateCell._GetDeskStatusStateName = HL.Method(HL.Userdata, HL.Userdata, HL.Opt(HL.Any)).Return(HL.String) << function(self, desk, guest, deskStatus)
    deskStatus = deskStatus or desk.deskStatus
    if deskStatus == DESK_STATUS.DeskStatusWaitingForEating
        and guest.guestType == GUEST_TYPE.GuestTypeSpecial
        and not guest.isReceived then
        return "Waiting"
    end
    return DESK_STATUS_STATE_NAMES[deskStatus] or "Empty"
end

InnDeskStateCell._ClearEatingDelay = HL.Method() << function(self)
    if self.m_eatingDelayTimerId >= 0 then
        self.m_eatingDelayTimerId = self:_ClearTimer(self.m_eatingDelayTimerId)
    end
    self.m_isDelayingEatingState = false
end

InnDeskStateCell._GetRenderDeskStatus = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Opt(HL.Any)) << function(self, desk)
    if not desk then
        self:_ClearEatingDelay()
        self.m_lastDeskStatus = nil
        return nil
    end

    local curStatus = desk.deskStatus
    local renderStatus = curStatus
    if curStatus ~= DESK_STATUS.DeskStatusEating then
        self:_ClearEatingDelay()
    elseif self.m_isDelayingEatingState then
        renderStatus = DESK_STATUS.DeskStatusWaitingForEating
    elseif self.m_lastDeskStatus == DESK_STATUS.DeskStatusWaitingForEating then
        self.m_isDelayingEatingState = true
        renderStatus = DESK_STATUS.DeskStatusWaitingForEating
        self.m_eatingDelayTimerId = self:_ClearTimer(self.m_eatingDelayTimerId)
        self.m_eatingDelayTimerId = self:_StartTimer(Tables.innManagementConst.guestStartEatTime, function()
            self.m_eatingDelayTimerId = -1
            self.m_isDelayingEatingState = false
            self.m_lastDeskStatus = DESK_STATUS.DeskStatusEating
            self:_Refresh()
        end)
    end

    self.m_lastDeskStatus = curStatus
    return renderStatus
end




InnDeskStateCell._RefreshStateController = HL.Method(HL.Opt(HL.Userdata, HL.Userdata)) << function(self, desk, guest)
    local stateController = self.view.stateController
    if not stateController then
        return
    end

    self.view.deskNumImg:LoadSprite(UIConst.UI_SPRITE_INN_DESK_NUM, string.format("icon_table_num%d", self.m_deskId))

    local stateName
    if not desk or not guest then
        self:_ClearEatingDelay()
        self.m_lastDeskStatus = nil
        stateName = "Empty"
    else
        
        stateName = self:_GetDeskStatusStateName(desk, guest, self:_GetRenderDeskStatus(desk))
    end

    if stateName == "Empty" then
        self.m_appliedGuestTypeStateName = ""
        if stateController.currentStateName ~= "Empty" then
            stateController:SetState("Empty")
        end
        return
    end

    local guestTypeStateName = GUEST_TYPE_STATE_NAMES[guest.guestType] or ""
    if stateController.currentStateName == stateName and self.m_appliedGuestTypeStateName == guestTypeStateName then
        return
    end
    if not string.isEmpty(guestTypeStateName) then
        stateController:SetState(guestTypeStateName)
    end
    stateController:SetState(stateName)
    self.m_appliedGuestTypeStateName = guestTypeStateName
end

InnDeskStateCell._RefreshMatches = HL.Method(HL.Opt(HL.Userdata)) << function(self, guest)
    if not self.view.matchStateCell then
        return
    end

    self.m_matchCellCache = self.m_matchCellCache or UIUtils.genCellCache(self.view.matchStateCell)

    local matchCount = (guest and guest.displayMatches) and guest.displayMatches.Count or 0
    self.m_matchCellCache:Refresh(matchCount, function(cell, index)
        local level = guest.displayMatches[CSIndex(index)]
        cell.stateController:SetState(MATCH_STATE_NAMES[level] or "Empty")
    end)
end

InnDeskStateCell._BuildOrderSlots = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Table) << function(self, guest)
    local foodSlots = {}
    if not guest then
        return foodSlots
    end

    if guest.guestType == GUEST_TYPE.GuestTypeNormal and guest.orders then
        for i = 0, guest.orders.Count - 1 do
            local order = guest.orders[i]
            foodSlots[#foodSlots + 1] = { matchIndex = i + 1, itemId = order.itemId, isSpecial = false }
        end
    elseif guest.guestType == GUEST_TYPE.GuestTypeSpecial and guest.requirementIds then
        for i = 0, guest.requirementIds.Count - 1 do
            local reqId = guest.requirementIds[i]
            foodSlots[#foodSlots + 1] = { matchIndex = i + 1, requirementId = reqId, isSpecial = true }
        end
    end

    return foodSlots
end

InnDeskStateCell._RefreshOrderCells = HL.Method(HL.Opt(HL.Userdata)) << function(self, guest)
    if not self.view.foodCell then
        return
    end

    local foodSlots = self:_BuildOrderSlots(guest)
    self.m_foodSlots = foodSlots
    local servingMatchIndex = self:_GetAutoServeMatchIndex(guest)

    self.m_foodCellCache = self.m_foodCellCache or UIUtils.genCellCache(self.view.foodCell)
    self.m_foodCellCache:Refresh(#foodSlots, function(cell, index)
        cell.stateController:SetState(foodSlots[index].isSpecial and "Special" or "Normal")
        self:_ApplyOrderCell(cell, foodSlots[index], servingMatchIndex, guest)
    end)
end



InnDeskStateCell._RefreshServingDeco = HL.Method() << function(self)
    if not self.m_foodCellCache or not self.m_foodSlots then
        return
    end

    local desk = self:_GetDeskState()
    local guest = self:_GetGuestState(desk)
    local servingMatchIndex = self:_GetAutoServeMatchIndex(guest)

    for i = 1, self.m_foodCellCache:GetCount() do
        local cell = self.m_foodCellCache:GetItem(i)
        local slot = self.m_foodSlots[i]
        if cell and cell.decoServing and slot then
            local isServing = servingMatchIndex > 0 and slot.matchIndex == servingMatchIndex
            cell.decoServing.gameObject:SetActiveIfNecessary(isServing)
        end
    end
end

InnDeskStateCell._RefreshAutoPayDeco = HL.Method() << function(self)
    if not self.view.decoAutoPay then
        return
    end
    local gs = self.m_innSystem and self.m_innSystem.gameState or nil
    local isAutoPay = gs ~= nil and gs.autoCheckoutDeskId == self.m_deskId and self.m_deskId > 0
    self.view.decoAutoPay.gameObject:SetActiveIfNecessary(isAutoPay)
end






InnDeskStateCell._GetAutoServeMatchIndex = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Number) << function(self, guest)
    if not self.m_innSystem or not guest then
        return 0
    end
    local gs = self.m_innSystem.gameState
    if not gs then
        return 0
    end
    if gs.autoServeFoodDeskId ~= self.m_deskId or (gs.autoServeFoodId or 0) <= 0 then
        return 0
    end

    local hasFood, food = gs.foods:TryGetValue(gs.autoServeFoodId)
    if not hasFood or not food or string.isEmpty(food.itemId) then
        return 0
    end

    local matches = guest.matches
    if not matches then
        return 0
    end

    if guest.guestType == GUEST_TYPE.GuestTypeNormal and guest.orders then
        local fallbackIndex = 0
        for i = 0, guest.orders.Count - 1 do
            local matchIndex = i + 1
            if matches[CSIndex(matchIndex)] == MATCH_LEVEL.NotServed then
                local order = guest.orders[i]
                if order.foodType == food.foodType then
                    if order.itemId == food.itemId then
                        return matchIndex
                    end
                    if fallbackIndex == 0 then
                        fallbackIndex = matchIndex
                    end
                end
            end
        end
        return fallbackIndex
    end

    return 0
end

InnDeskStateCell._ApplyOrderCell = HL.Method(HL.Any, HL.Table, HL.Number, HL.Opt(HL.Userdata)) << function(self, cell, slot, servingMatchIndex, guest)
    if not cell or not slot then
        return
    end

    if cell.itemIcon and slot.itemId and not string.isEmpty(slot.itemId) then
        cell.itemIcon:InitItemIcon(slot.itemId, false)
        cell.itemIcon.gameObject:SetActiveIfNecessary(true)
    elseif cell.itemIcon then
        cell.itemIcon.gameObject:SetActiveIfNecessary(false)
    end

    if cell.iconSpecialFood then
        if slot.requirementId then
            cell.iconSpecialFood.gameObject:SetActiveIfNecessary(true)
            local stateName = "Dish"
            local _, requirement = Tables.innRequirementTable:TryGetValue(slot.requirementId)
            if requirement then
                stateName = requirement.foodType == GEnums.InnManagementFoodType.Drink and "Drink" or "Dish"
            end
            cell.iconSpecialFood:SetState(stateName)
        else
            cell.iconSpecialFood.gameObject:SetActiveIfNecessary(false)
        end
    end

    local level = MATCH_LEVEL.NotServed
    if guest and guest.judgedMatches and slot.matchIndex <= guest.judgedMatches.Count then
        level = guest.judgedMatches[CSIndex(slot.matchIndex)]
    end
    if cell.iconEmotion then
        local emojiId = InnConst.INN_MATCH_EMOJI_ICON_ID[level]
        if emojiId then
            cell.iconEmotion.gameObject:SetActiveIfNecessary(true)
            cell.iconEmotion:LoadSprite(UIConst.UI_SPRITE_INN_Emotion, emojiId)
        else
            cell.iconEmotion.gameObject:SetActiveIfNecessary(false)
        end
    end

    if cell.decoServing then
        local isServing = servingMatchIndex > 0 and slot.matchIndex == servingMatchIndex
        cell.decoServing.gameObject:SetActiveIfNecessary(isServing)
    end
end



InnDeskStateCell._IsProgressActive = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)).Return(HL.Boolean) << function(self, desk)
    if not desk then
        return false
    end
    local status = desk.deskStatus
    if status == DESK_STATUS.DeskStatusOrdering then
        return true
    end
    if status == DESK_STATUS.DeskStatusEating and not self.m_isDelayingEatingState then
        return true
    end
    return false
end

InnDeskStateCell._RefreshProgress = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self, desk)
    if not self.view.progressImg then
        return
    end
    local fill = PROGRESS_DEFAULT_FILL
    if desk and desk.deskStatus == DESK_STATUS.DeskStatusOrderingFailed then
        fill = 1
    end
    if desk and self.m_innSystem and self:_IsProgressActive(desk) then
        fill = self.m_innSystem:GetDeskProgressRatio(desk)
    end
    self.view.progressImg.fillAmount = 1- fill
end


InnDeskStateCell._EnsureProgressCoroutine = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self, desk)
    if not self:_IsProgressActive(desk) then
        if self.m_progressCoroutine then
            self.m_progressCoroutine = self:_ClearCoroutine(self.m_progressCoroutine)
        end
        return
    end
    if self.m_progressCoroutine then
        return
    end
    self.m_progressCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(DESK_PROGRESS_TICK_SEC)
            if self.m_isDestroyed then
                break
            end
            local d = self:_GetDeskState()
            if not self:_IsProgressActive(d) then
                break
            end
            local gs = self.m_innSystem and self.m_innSystem.gameState or nil
            if not (gs and gs.isPaused) then
                self:_RefreshProgress(d)
            end
        end
        self.m_progressCoroutine = nil
    end)
end

InnDeskStateCell._OnDeskCheckOut = HL.Method(HL.Table) << function(self, args)
    local deskId = unpack(args)
    if deskId ~= self.m_deskId or not self.m_innSystem.gameState.isEndingGame then
        return
    end
    self:_ClearEatingDelay()
    self.view.autoCheckoutNode.gameObject:SetActive(true)
end

HL.Commit(InnDeskStateCell)
return InnDeskStateCell
