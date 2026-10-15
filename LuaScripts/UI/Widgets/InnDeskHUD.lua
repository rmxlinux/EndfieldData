local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnDeskHUD = HL.Class('InnDeskHUD', UIWidgetBase)

InnDeskHUD.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem) << nil

InnDeskHUD.m_deskId = HL.Field(HL.Number) << 0

InnDeskHUD.m_matchCellCache = HL.Field(HL.Forward("UIListCache")) << nil

InnDeskHUD.m_foodCellCache = HL.Field(HL.Forward("UIListCache")) << nil

InnDeskHUD.m_specialReqCellCache = HL.Field(HL.Forward("UIListCache")) << nil


InnDeskHUD.m_foodSlots = HL.Field(HL.Table) << nil

InnDeskHUD.m_lastDeskStatus = HL.Field(HL.Any) << nil

InnDeskHUD.m_eatingDelayTimerId = HL.Field(HL.Number) << -1

InnDeskHUD.m_isDelayingEatingState = HL.Field(HL.Boolean) << false

InnDeskHUD.m_progressCoroutine = HL.Field(HL.Thread) << nil




local DESK_STATUS = CS.Proto.INN_MANAGEMENT_DESK_STATUS
local GUEST_TYPE = CS.Proto.INN_MANAGEMENT_GUEST_TYPE
local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel














local DESK_STATUS_STATE_NAMES = {
    [GUEST_TYPE.GuestTypeNormal] = {
        [DESK_STATUS.DeskStatusOrdering] = "OrderingNormal",
        [DESK_STATUS.DeskStatusWaitingForEating] = "OrderedNormal",
        [DESK_STATUS.DeskStatusEating] = "EatingNormal",
        [DESK_STATUS.DeskStatusWaitingForPay] = "Pay",
    },
    [GUEST_TYPE.GuestTypeSpecial] = {
        [DESK_STATUS.DeskStatusOrdering] = "OrderingSpecial",
        [DESK_STATUS.DeskStatusEating] = "EatingSpecial",
        [DESK_STATUS.DeskStatusWaitingForPay] = "Pay",
    },
}


local PROGRESS_DEFAULT_FILL = 1
local DESK_PROGRESS_TICK_SEC =  1/60


local MATCH_STATE_NAMES = {
    [MATCH_LEVEL.NotServed] = "Empty",
    [MATCH_LEVEL.Unsatisfied] = "Failed",
    [MATCH_LEVEL.Normal] = "Normal",
    [MATCH_LEVEL.Perfect] = "Perfect",
}


InnDeskHUD._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_INN_DESK_STATE_CHANGED, function(args)
        local deskId = unpack(args)
        if deskId == self.m_deskId then
            self:_Refresh()
        end
    end)
    self:RegisterMessage(MessageConst.ON_INN_GUEST_STATE_CHANGED, function(args)
        local guestId = unpack(args)
        local deskState = self:_GetDeskState()
        if deskState and deskState.guestId == guestId then
            local guest = self:_GetGuestState(deskState)
            self:_RefreshMatches(guest)
            self:_RefreshFoodCells(guest)
            self:_RefreshSpecialRequirementCells(guest)
        end
    end)
    
    self:RegisterMessage(MessageConst.ON_INN_AUTO_SERVER_FOOD_CHANGED, function()
        self:_RefreshServingDeco()
    end)
    
    self:RegisterMessage(MessageConst.ON_INN_AUTO_CHECKOUT_CHANGED, function()
        self:_RefreshAutoPayDeco()
    end)
    
    self:RegisterMessage(MessageConst.ON_INN_GAME_END_BEGIN, function()
        self:_SetActiveState(false)
    end)
end

InnDeskHUD._OnDestroy = HL.Override() << function(self)
    self:_ClearEatingDelay()
    if self.m_progressCoroutine then
        self.m_progressCoroutine = self:_ClearCoroutine(self.m_progressCoroutine)
    end
end

InnDeskHUD.InitInnDeskHUD = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    self:_ClearEatingDelay()
    self.m_lastDeskStatus = nil
    self.m_deskId = args.deskId or 0
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem or nil

    self:_Refresh()
end

InnDeskHUD._GetDeskState = HL.Method().Return(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self)
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

InnDeskHUD._GetGuestState = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)).Return(HL.Opt(CS.Beyond.Gameplay.InnSystem.GuestState)) << function(self, deskState)
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

InnDeskHUD._Refresh = HL.Method() << function(self)
    local desk = self:_GetDeskState()
    local guest = self:_GetGuestState(desk)

    self:_RefreshStateNode(desk, guest)
    self:_RefreshMatches(guest)
    self:_RefreshFoodCells(guest)
    self:_RefreshSpecialRequirementCells(guest)
    self:_RefreshAutoPayDeco()
    self:_RefreshProgress(desk)
    self:_EnsureProgressCoroutine(desk)
end





InnDeskHUD._GetStateNodeName = HL.Method(HL.Userdata, HL.Userdata, HL.Opt(HL.Any)).Return(HL.String) << function(self, desk, guest, deskStatus)
    deskStatus = deskStatus or desk.deskStatus
    if guest.guestType == GUEST_TYPE.GuestTypeSpecial
        and deskStatus == DESK_STATUS.DeskStatusWaitingForEating then
        return guest.isReceived and "OrderedSpecial" or "Waiting"
    end

    local table = DESK_STATUS_STATE_NAMES[guest.guestType]
    return table and table[deskStatus] or ""
end

InnDeskHUD._ClearEatingDelay = HL.Method() << function(self)
    if self.m_eatingDelayTimerId >= 0 then
        self.m_eatingDelayTimerId = self:_ClearTimer(self.m_eatingDelayTimerId)
    end
    self.m_isDelayingEatingState = false
end

InnDeskHUD._GetRenderDeskStatus = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Opt(HL.Any)) << function(self, desk)
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



InnDeskHUD._SetActiveState = HL.Method(HL.Boolean) << function(self, isActive)
    if self.view.worldUIFollowAndFaceCamera then
        self.view.worldUIFollowAndFaceCamera.enabled = isActive
    end
    if self.view.canvas then
        self.view.canvas.enabled = isActive
    end
end







InnDeskHUD._RefreshStateNode = HL.Method(HL.Opt(HL.Userdata, HL.Userdata)) << function(self, desk, guest)
    if not self.view.stateNode then
        return
    end

    if not desk or not guest then
        self:_ClearEatingDelay()
        self.m_lastDeskStatus = nil
        self:_SetActiveState(false)
        return
    end

    local stateName = self:_GetStateNodeName(desk, guest, self:_GetRenderDeskStatus(desk))
    if string.isEmpty(stateName) then
        self:_SetActiveState(false)
        return
    end

    self:_SetActiveState(true)
    self.view.stateNode:SetState(stateName)
end

InnDeskHUD._RefreshMatches = HL.Method(HL.Opt(HL.Userdata)) << function(self, guest)
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



InnDeskHUD._BuildFoodSlots = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Table) << function(self, guest)
    local foodSlots = {}
    if not guest or guest.guestType ~= GUEST_TYPE.GuestTypeNormal or not guest.orders then
        return foodSlots
    end

    for i = 0, guest.orders.Count - 1 do
        local order = guest.orders[i]
        foodSlots[#foodSlots + 1] = {
            matchIndex = i + 1,
            itemId = order.itemId,
            foodType = order.foodType,
        }
    end
    return foodSlots
end

InnDeskHUD._RefreshFoodCells = HL.Method(HL.Opt(HL.Userdata)) << function(self, guest)
    if not self.view.foodCell then
        return
    end

    local foodSlots = self:_BuildFoodSlots(guest)
    self.m_foodSlots = foodSlots
    local servingMatchIndex = self:_GetAutoServeMatchIndex(guest)

    self.m_foodCellCache = self.m_foodCellCache or UIUtils.genCellCache(self.view.foodCell)
    self.m_foodCellCache:Refresh(#foodSlots, function(cell, index)
        self:_ApplyFoodCell(cell, foodSlots[index], servingMatchIndex, guest)
    end)
end

InnDeskHUD._RefreshSpecialRequirementCells = HL.Method(HL.Opt(HL.Userdata)) << function(self, guest)
    if not self.view.specialRequirementCell then
        return
    end

    self.m_specialReqCellCache = self.m_specialReqCellCache or UIUtils.genCellCache(self.view.specialRequirementCell)

    local requirementIds = (guest and guest.guestType == GUEST_TYPE.GuestTypeSpecial) and guest.requirementIds or nil
    local reqCount = requirementIds and requirementIds.Count or 0
    self.m_specialReqCellCache:Refresh(reqCount, function(cell, index)
        local reqId = requirementIds and tostring(requirementIds[CSIndex(index)] or "") or ""
        self:_ApplySpecialRequirementCell(cell, reqId, index, guest)
    end)
end



InnDeskHUD._RefreshServingDeco = HL.Method() << function(self)
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


InnDeskHUD._RefreshAutoPayDeco = HL.Method() << function(self)
    if not self.view.decoAutoPay then
        return
    end
    local gs = self.m_innSystem and self.m_innSystem.gameState or nil
    local isAutoPay = gs ~= nil and gs.autoCheckoutDeskId == self.m_deskId and self.m_deskId > 0
    self.view.decoAutoPay.gameObject:SetActiveIfNecessary(isAutoPay)
end



InnDeskHUD._IsProgressActive = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)).Return(HL.Boolean) << function(self, desk)
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

InnDeskHUD._RefreshProgress = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self, desk)
    if not self.view.progressImg then
        return
    end
    local fill = PROGRESS_DEFAULT_FILL
    if desk and self.m_innSystem and self:_IsProgressActive(desk) then
        fill = self.m_innSystem:GetDeskProgressRatio(desk)
    end
    self.view.progressImg.fillAmount = fill
end


InnDeskHUD._EnsureProgressCoroutine = HL.Method(HL.Opt(CS.Beyond.Gameplay.InnSystem.DeskState)) << function(self, desk)
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



InnDeskHUD._GetAutoServeMatchIndex = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Number) << function(self, guest)
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

InnDeskHUD._ApplyFoodCell = HL.Method(HL.Any, HL.Table, HL.Number, HL.Opt(HL.Userdata)) << function(self, cell, slot, servingMatchIndex, guest)
    if not cell or not slot then
        return
    end

    if cell.itemIcon and slot.itemId and not string.isEmpty(slot.itemId) then
        cell.itemIcon:InitItemIcon(slot.itemId, false)
        cell.itemIcon.gameObject:SetActiveIfNecessary(true)
    elseif cell.itemIcon then
        cell.itemIcon.gameObject:SetActiveIfNecessary(false)
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




InnDeskHUD._ApplySpecialRequirementCell = HL.Method(HL.Any, HL.String, HL.Number, HL.Opt(HL.Userdata)) << function(self, cell, requirementId, matchIndex, guest)
    if not cell then
        return
    end

    local foodType
    local requirement = nil
    if not string.isEmpty(requirementId) and Tables and Tables.innRequirementTable then
        requirement = Tables.innRequirementTable[requirementId]
    end
    if requirement then
        foodType = requirement.foodType
    end

    local level = MATCH_LEVEL.NotServed
    if guest and guest.judgedMatches and matchIndex <= guest.judgedMatches.Count then
        level = guest.judgedMatches[CSIndex(matchIndex)]
    end
    local emojiId = InnConst.INN_MATCH_EMOJI_ICON_ID[level]
    local showEmotion = emojiId ~= nil

    
    if cell.decoDish then
        cell.decoDish.gameObject:SetActiveIfNecessary(not showEmotion and foodType == GEnums.InnManagementFoodType.Dish)
    end
    if cell.decoDrink then
        cell.decoDrink.gameObject:SetActiveIfNecessary(not showEmotion and foodType == GEnums.InnManagementFoodType.Drink)
    end

    if cell.iconEmotion then
        if showEmotion then
            cell.iconEmotion.gameObject:SetActiveIfNecessary(true)
            cell.iconEmotion:LoadSprite(UIConst.UI_SPRITE_INN_Emotion, emojiId)
        else
            cell.iconEmotion.gameObject:SetActiveIfNecessary(false)
        end
    end

    if cell.requirementTxt then
        cell.requirementTxt.text = requirement.requirementText or ""
    end
end

HL.Commit(InnDeskHUD)
return InnDeskHUD
