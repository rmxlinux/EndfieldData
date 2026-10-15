local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local InnUtils = require_ex('Common/Utils/InnUtils')

InnKitchenHUD = HL.Class('InnKitchenHUD', UIWidgetBase)

InnKitchenHUD.m_kitchenId = HL.Field(HL.Number) << 0

InnKitchenHUD.m_cachedKitchenState = HL.Field(CS.Beyond.Gameplay.InnSystem.KitchenState)

InnKitchenHUD.m_kitchenProgressCoroutine = HL.Field(HL.Thread) << nil

InnKitchenHUD.m_categoryTagCache = HL.Field(HL.Any) << nil

InnKitchenHUD.m_affixTagCache = HL.Field(HL.Any) << nil


InnKitchenHUD.m_speedBoostByDish = HL.Field(HL.Table)


InnKitchenHUD._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_INN_KITCHEN_STATE_CHANGED, function(args)
        local kitchenId = unpack(args)
        if kitchenId == self.m_kitchenId then
            self:_RefreshFoodQueue()
        end
    end)
end

InnKitchenHUD.InitInnKitchenHUD = HL.Method(HL.Number) << function(self, id)
    self:_FirstTimeInit()

    self.m_kitchenId = id
    if id == 0 then
        self.view.stateController:SetState("Empty")
        return
    end

    self.m_speedBoostByDish = {}
    self:_RefreshSkillTags()
    self:_RefreshFoodQueue()
    local inn = self:_GetInnSystem()
    local unlockedQueueSize = inn.kitchenQueueSize
    self.view.stateController:SetState(string.format("Queue%d", unlockedQueueSize))
    local topicId = (inn.gameSetting and inn.gameSetting.topicId) or ""
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    local bgId = hasTopic and topicData.bgId or InnConst.INN_TOPIC_EMPTY_CONFIG.bgId
    self.view.topicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, bgId)
end

InnKitchenHUD._GetInnSystem = HL.Method().Return(CS.Beyond.Gameplay.InnSystem) << function(self)
    return GameInstance.player.innSystem
end

InnKitchenHUD._GetCookElapsedMs = HL.Method(CS.Beyond.Gameplay.InnSystem.KitchenState).Return(HL.Number) << function(self, kitchenState)
    if not kitchenState or string.isEmpty(kitchenState.cookingFoodItemId) then
        return 0
    end
    local itemId = kitchenState.cookingFoodItemId
    local boost = self.m_speedBoostByDish[itemId]
    if not boost then
        boost = InnUtils.getKitchenSpeedBoost(self.m_kitchenId, itemId)
        self.m_speedBoostByDish[itemId] = boost
    end
    return self:_GetInnSystem():GetKitchenRealtimeElapsedMs(kitchenState, boost)
end

InnKitchenHUD._RefreshSkillTags = HL.Method() << function(self)
    local inn = self:_GetInnSystem()
    local topicId = (inn.gameSetting and inn.gameSetting.topicId) or ""
    local catRows, affRows = InnUtils.getKitchenSkillTagRows(self.m_kitchenId, topicId)

    if self.view.innItemTagCategory and not self.m_categoryTagCache then
        self.m_categoryTagCache = UIUtils.genCellCache(self.view.innItemTagCategory)
    end
    if self.view.innItemTagAffix and not self.m_affixTagCache then
        self.m_affixTagCache = UIUtils.genCellCache(self.view.innItemTagAffix)
    end
    if self.m_categoryTagCache then
        self.m_categoryTagCache:Refresh(#catRows, function(cell, index)
            cell:InitInnItemTag(catRows[index].args)
        end)
    end
    if self.m_affixTagCache then
        self.m_affixTagCache:Refresh(#affRows, function(cell, index)
            cell:InitInnItemTag(affRows[index].args)
        end)
    end
end

InnKitchenHUD._ApplyFoodCell = HL.Method(HL.Any, HL.Opt(HL.Table)) << function(self, cell, slot)
    if not cell or not cell.stateController then
        return
    end
    if not slot or string.isEmpty(slot.itemId) then
        cell.stateController:SetState("EmptyState")
        return
    end
    if slot.isCooking then
        cell.stateController:SetState("MakeState")
        local total = InnUtils.getDishCookTotalMs(slot.itemId)
        local elapsed = slot.elapsedMs or 0
        if total > 0 then
            local t = elapsed / total
            if t < 0 then
                t = 0
            elseif t > 1 then
                t = 1
            end
            if cell.sliderImg then
                cell.sliderImg.fillAmount = t
            end
        end
    else
        cell.stateController:SetState("WaitState")
    end
    if cell.itemIcon then
        cell.itemIcon:InitItemIcon(slot.itemId)
    end
end

InnKitchenHUD._SyncKitchenStateCache = HL.Method() << function(self)
    self.m_cachedKitchenState = nil
    local inn = self:_GetInnSystem()
    local gs = inn.gameState
    if gs and gs.kitchenStates then
        local hasState, st = gs.kitchenStates:TryGetValue(self.m_kitchenId)
        if hasState then
            self.m_cachedKitchenState = st
        end
    end
end

InnKitchenHUD._RefreshFoodQueue = HL.Method() << function(self)
    self:_SyncKitchenStateCache()
    local kitchenState = self.m_cachedKitchenState

    local slots = {}
    local hasCookingFood = kitchenState and not string.isEmpty(kitchenState.cookingFoodItemId)
    if hasCookingFood then
        slots[#slots + 1] = {
            itemId = kitchenState.cookingFoodItemId,
            isCooking = true,
            elapsedMs = self:_GetCookElapsedMs(kitchenState),
        }
    end
    if kitchenState and kitchenState.waitingFoodItemIds then
        for i = 0, kitchenState.waitingFoodItemIds.Count - 1 do
            local itemId = kitchenState.waitingFoodItemIds[i]
            if itemId and not string.isEmpty(itemId) then
                slots[#slots + 1] = {
                    itemId = itemId,
                    isCooking = false,
                }
            end
        end
    end

    if self.view.stateController then
        local isBlocked = kitchenState and kitchenState.isBlocked or false
        self.view.stateController:SetState(isBlocked and "Block" or "Normal")
    end

    local cells = {
        self.view.innFoodQueueCell01,
        self.view.innFoodQueueCell02,
        self.view.innFoodQueueCell03,
    }
    for i = 1, #cells do
        self:_ApplyFoodCell(cells[i], slots[i])
    end

    self:_EnsureKitchenProgressCoroutine()
end

local KITCHEN_COOK_PROGRESS_TICK_SEC = 0.1

InnKitchenHUD._RefreshCookingCellProgress = HL.Method() << function(self)
    local kitchenState = self.m_cachedKitchenState
    if not kitchenState or string.isEmpty(kitchenState.cookingFoodItemId) then
        return
    end
    local cell = self.view.innFoodQueueCell01
    if not cell or not cell.sliderImg then
        return
    end
    local itemId = kitchenState.cookingFoodItemId
    local total = InnUtils.getDishCookTotalMs(itemId)
    local elapsed = self:_GetCookElapsedMs(kitchenState)
    if total > 0 then
        local t = elapsed / total
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        cell.sliderImg.fillAmount = t
    end
end

InnKitchenHUD._EnsureKitchenProgressCoroutine = HL.Method() << function(self)
    local kitchenState = self.m_cachedKitchenState
    local isCooking = kitchenState ~= nil and not string.isEmpty(kitchenState.cookingFoodItemId)
    if not isCooking then
        if self.m_kitchenProgressCoroutine then
            self.m_kitchenProgressCoroutine = self:_ClearCoroutine(self.m_kitchenProgressCoroutine)
        end
        return
    end
    if self.m_kitchenProgressCoroutine then
        return
    end
    self.m_kitchenProgressCoroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(KITCHEN_COOK_PROGRESS_TICK_SEC)
            if self.m_isDestroyed then
                break
            end
            local ks = self.m_cachedKitchenState
            local stillCooking = ks ~= nil and not string.isEmpty(ks.cookingFoodItemId)
            if not stillCooking then
                break
            end
            local inn = self:_GetInnSystem()
            local gs = inn and inn.gameState or nil
            if not (gs and gs.isPaused) then
                self:_RefreshCookingCellProgress()
            end
        end
        self.m_kitchenProgressCoroutine = nil
    end)
end

HL.Commit(InnKitchenHUD)
return InnKitchenHUD

