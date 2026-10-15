local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local NpcRestaurantRole = CS.Beyond.Gameplay.AI.NpcRestaurantRole
local AIEvent = CS.Beyond.Gameplay.AI.AIEvent
local AIEventData = CS.Beyond.Gameplay.AI.AIEventData
local AttractStatus = CS.Beyond.Gameplay.AI.AttractStatus
local AttractObjectType = CS.Beyond.Gameplay.AI.AttractObjectType
local DeskStatus = CS.Proto.INN_MANAGEMENT_DESK_STATUS

InnNpcSystem = HL.Class('InnNpcSystem', LuaSystemBase.LuaSystemBase)

InnNpcSystem.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)


InnNpcSystem.m_chefEntityIds = HL.Field(HL.Table)

InnNpcSystem.m_ownerEntityId = HL.Field(HL.Any)




InnNpcSystem.m_pendingNpcRoutes = HL.Field(HL.Table)


InnNpcSystem.m_npcOwnerById = HL.Field(HL.Table)


InnNpcSystem.m_npcIdSerial = HL.Field(HL.Number) << 0


InnNpcSystem.m_pendingOwnerServiceCallback = HL.Field(HL.Function)


InnNpcSystem.m_guestEntityIds = HL.Field(HL.Table)


InnNpcSystem.m_guestQueuePoints = HL.Field(HL.Table)


InnNpcSystem.m_lastKnownDeskStatus = HL.Field(HL.Table)


InnNpcSystem.m_lastKnownDeskGuestId = HL.Field(HL.Table)


InnNpcSystem.m_specialGuestEffects = HL.Field(HL.Table)


InnNpcSystem.m_isPreparingChefs = HL.Field(HL.Boolean) << false


InnNpcSystem.m_pendingChefCreateCount = HL.Field(HL.Number) << 0


InnNpcSystem.m_hasScheduledChefShowEvent = HL.Field(HL.Boolean) << false


InnNpcSystem.m_chefShowBatchId = HL.Field(HL.Number) << 0


InnNpcSystem.m_gameMsgRegisterKeys = HL.Field(HL.Table)

InnNpcSystem.m_isGamePrepared = HL.Field(HL.Boolean) << false

InnNpcSystem.InnNpcSystem = HL.Constructor() << function(self)
    self.m_innSystem = GameInstance.player.innSystem
end

InnNpcSystem.OnRelease = HL.Override() << function(self)
    self:ReleaseGameNpc()
end

InnNpcSystem._RegisterGameMessages = HL.Method() << function(self)
    self:_UnregisterGameMessages()
    self.m_gameMsgRegisterKeys = {}
    local function register(msg, action)
        self.m_gameMsgRegisterKeys[msg] = MessageManager:Register(msg, action, self)
    end
    register(MessageConst.ON_CLIENT_NPC_CREATED, function(args)
        local npcId, _templateId, entityId = unpack(args)
        self:_OnClientNpcCreated(npcId, entityId)
    end)
    register(MessageConst.ON_CLIENT_NPC_DEACTIVATED, function(args)
        local _npcId, _templateId, entityId = unpack(args)
        self:_OnClientNpcDeactivated(entityId)
    end)
    register(MessageConst.ON_RESTAURANT_OWNER_SERVICE_GENERATE_DISH, function()
        self:_OnOwnerServiceGenerateDish()
    end)
    register(MessageConst.ON_RESTAURANT_OWNER_CHECKOUT_MONEY, function()
        self:_OnOwnerCheckoutMoney()
    end)
    register(MessageConst.ON_INN_GUEST_QUEUE_CHANGED, function()
        self:_OnGuestQueueChanged()
    end)
    register(MessageConst.ON_INN_DESK_STATE_CHANGED, function(args)
        local deskId = unpack(args)
        self:_OnDeskStateChanged(deskId)
    end)
    register(MessageConst.ON_INN_GAME_END_BEGIN, function()
        self:_OnGameEndBegin()
    end)
    register(MessageConst.ON_INN_GAME_RESULT, function()
        self:ReleaseGameNpc()
    end)
end

InnNpcSystem._UnregisterGameMessages = HL.Method() << function(self)
    if self.m_gameMsgRegisterKeys == nil then
        return
    end
    for _, registerKey in pairs(self.m_gameMsgRegisterKeys) do
        MessageManager:Unregister(registerKey)
    end
    self.m_gameMsgRegisterKeys = nil
end

InnNpcSystem._ActiveRoutedNpc = HL.Method(HL.String, HL.Any, HL.Any, HL.Any, HL.String, HL.Boolean)
        << function(self, templateId, position, rotation, role, routeId, isActive)
    local entityId = self.m_innSystem:ActiveGameNpc(templateId, position, rotation, role, routeId, isActive)
    local route = self.m_pendingNpcRoutes[routeId]
    if route ~= nil and entityId ~= nil and entityId ~= 0 then
        route.pendingEntityId = entityId
    end
end

InnNpcSystem._TryGetNpcEntity = HL.Method(HL.Any).Return(HL.Opt(CS.Beyond.Gameplay.Core.Entity))
        << function(self, entityId)
    local hasEntity, entity = GameWorld.objectContainer:TryGetEntityById(entityId)
    if not hasEntity then
        return nil
    end
    return entity
end

InnNpcSystem._CancelPendingGuestRoutes = HL.Method(HL.Number) << function(self, guestId)
    for routeId, route in pairs(self.m_pendingNpcRoutes) do
        if route.kind == "guest" and route.guestId == guestId then
            logger.info(string.format(
                "[InnNpcSystem] _CancelPendingGuestRoutes 取消创建中的 NPC guestId=%d routeId=%s entityId=%s",
                guestId, routeId, tostring(route.pendingEntityId)))
            
            if route.pendingEntityId ~= nil and route.pendingEntityId ~= 0 then
                self.m_innSystem:RemoveGameNpc(route.pendingEntityId)
            end
            self.m_pendingNpcRoutes[routeId] = nil
        end
    end
end

InnNpcSystem.PrepareGameNpc = HL.Method() << function(self)
    self.m_isGamePrepared = true
    self:_RegisterGameMessages()
    self.m_innSystem:InitGameAttractPointData()
    GameInstance.effectManager:PreloadEffect(Tables.innManagementConst.jsspsiPreloadEffect)

    self.m_guestEntityIds = {}
    self.m_guestQueuePoints = {}
    self.m_lastKnownDeskStatus = {}
    self.m_lastKnownDeskGuestId = {}
    self.m_specialGuestEffects = {}
    self.m_pendingNpcRoutes = {}
    self.m_npcOwnerById = {}

    self:_PrepareChefs()
    self:_PrepareOwner()
end

InnNpcSystem.ReleaseGameNpc = HL.Method() << function(self)
    if not self.m_isGamePrepared then
        return
    end
    self.m_isGamePrepared = false
    GameInstance.effectManager:CancelPreloadEffect(Tables.innManagementConst.jsspsiPreloadEffect)

    self.m_chefEntityIds = {}
    self.m_guestEntityIds = {}
    self.m_ownerEntityId = nil
    self.m_npcOwnerById = {}
    self.m_pendingNpcRoutes = {}
    self.m_pendingOwnerServiceCallback = nil

    local attractPointSystem = GameWorld.aiManager.attractPointSystem

    
    
    if self.m_guestQueuePoints ~= nil then
        for _, points in pairs(self.m_guestQueuePoints) do
            for _, point in ipairs(points) do
                if point ~= nil and point.uuid ~= 0 then
                    attractPointSystem:SetAttractPointStatus(
                        AttractObjectType.Npc, point.uuid, AttractStatus.Available)
                end
            end
        end
        self.m_guestQueuePoints = {}
    end


    
    
    
    local deskPointData = self.m_innSystem and self.m_innSystem.deskAttractPointData or nil
    if deskPointData ~= nil then
        for _, seats in pairs(deskPointData) do
            if seats ~= nil then
                for i = 0, seats.Count - 1 do
                    local point = seats[i]
                    if point ~= nil and point.uuid ~= 0 then
                        attractPointSystem:SetAttractPointStatus(
                            AttractObjectType.Npc, point.uuid, AttractStatus.Available)
                    end
                end
            end
        end
    end

    self.m_lastKnownDeskStatus = {}
    self.m_lastKnownDeskGuestId = {}

    if self.m_specialGuestEffects ~= nil then
        for _, effectPtr in pairs(self.m_specialGuestEffects) do
            local effect = effectPtr and effectPtr:Lock()
            if effect ~= nil then
                effect:Finish()
            end
        end
    end
    self.m_specialGuestEffects = {}
    self.m_chefShowBatchId = self.m_chefShowBatchId + 1

    self:_UnregisterGameMessages()

    GameWorld.npcManager:CleanupClientNpcPool()
end




InnNpcSystem._OnClientNpcCreated = HL.Method(HL.String, HL.Any) << function(self, npcId, entityId)
    if not self.m_pendingNpcRoutes then
        return
    end
    local route = self.m_pendingNpcRoutes[npcId]
    if route == nil then
        return
    end
    self.m_pendingNpcRoutes[npcId] = nil

    
    if route.kind == "chef" then
        self:_OnChefCreateFinished()
    end

    local entity = self:_TryGetNpcEntity(entityId)
    if entity == nil then
        logger.error(string.format("InnNpcSystem ON_CLIENT_NPC_CREATED 找不到 entity, npcId=%s, entityId=%s",
            tostring(npcId), tostring(entityId)))
        return
    end

    if route.kind == "chef" then
        local kitchenCache = self.m_chefEntityIds[route.kitchenId]
        if kitchenCache == nil then
            logger.error(string.format(
                "InnNpcSystem ON_CLIENT_NPC_CREATED chef 路由命中但 kitchen 已释放 npcId=%s kitchenId=%d slot=%d entityId=%s",
                tostring(npcId), route.kitchenId, route.slotIndex, tostring(entityId)))
            return
        end
        kitchenCache[route.slotIndex] = entityId
        self.m_npcOwnerById[entityId] = route
        local delay = math.random() * Tables.innManagementConst.chefRandomCookingTime
        logger.info(string.format(
            "[InnNpcSystem] _OnClientNpcCreated chef 落位 npcId=%s kitchenId=%d slot=%d entityId=%s 安排延迟 %.2fs 后派发 ChefStartCooking",
            tostring(npcId), route.kitchenId, route.slotIndex, tostring(entityId), delay))
        local kitchenId = route.kitchenId
        local slotIndex = route.slotIndex
        self:_StartTimer(delay, function()
            local cache = self.m_chefEntityIds[kitchenId]
            local chefEntity = cache ~= nil and cache[slotIndex] == entityId and self:_TryGetNpcEntity(entityId) or nil
            if chefEntity == nil then
                logger.info(string.format(
                    "[InnNpcSystem] chef 延迟到期 跳过派发 kitchenId=%d slot=%d entityId=%s 原因=已释放或被复用",
                    kitchenId, slotIndex, tostring(entityId)))
                return
            end
            logger.info(string.format(
                "[InnNpcSystem] chef 延迟到期 派发 ChefStartCooking kitchenId=%d slot=%d entityId=%s",
                kitchenId, slotIndex, tostring(entityId)))
            chefEntity.npcAICom:TriggerEvent(AIEvent.NPCRestaurantChefStartCooking)
        end)
    elseif route.kind == "owner" then
        self.m_ownerEntityId = entityId
        self.m_npcOwnerById[entityId] = route
        logger.info(string.format(
            "[InnNpcSystem] _OnClientNpcCreated owner 落位 npcId=%s entityId=%s",
            tostring(npcId), tostring(entityId)))
    elseif route.kind == "guest" then
        local list = self.m_guestEntityIds[route.guestId]
        if list == nil then
            logger.error(string.format(
                "InnNpcSystem ON_CLIENT_NPC_CREATED guest 路由命中但 guest 已离场 npcId=%s guestId=%d entityId=%s",
                tostring(npcId), route.guestId, tostring(entityId)))
            return
        end
        table.insert(list, entityId)
        self.m_npcOwnerById[entityId] = route
        logger.info(string.format(
            "[InnNpcSystem] _OnClientNpcCreated guest 落位 npcId=%s guestId=%d entityId=%s listCount=%d",
            tostring(npcId), route.guestId, tostring(entityId), #list))
        self:_TryAttachSpecialGuestEffect(route.guestId, entity)
        if route.playAppearSound then
            self:_PlayGuestAppearOnDeskSound(route.guestId, entity)
        end
        
        
        if route.enterOrderSeatUuid ~= nil and route.enterOrderSeatUuid ~= 0 then
            logger.info(string.format(
                "[InnNpcSystem] _OnClientNpcCreated 派发 GuestEnterOrder guestId=%d entityId=%s seatUuid=%s",
                route.guestId, tostring(entityId), tostring(route.enterOrderSeatUuid)))
            local data = AIEventData()
            data.ulongParam = route.enterOrderSeatUuid
            entity.npcAICom:TriggerEvent(AIEvent.NPCRestaurantGuestEnterOrder, data)
        end
    end
end



InnNpcSystem._PrepareChefs = HL.Method() << function(self)
    self.m_chefEntityIds = {}
    self.m_isPreparingChefs = true
    self.m_pendingChefCreateCount = 0
    self.m_hasScheduledChefShowEvent = false
    self.m_chefShowBatchId = self.m_chefShowBatchId + 1

    local gameSetting = self.m_innSystem.gameSetting
    local kitchenSettings = gameSetting and gameSetting.kitchenSettings
    if kitchenSettings == nil or kitchenSettings.Count <= 0 then
        self.m_isPreparingChefs = false
        return
    end

    local kitchenAttractData = self.m_innSystem.kitchenAttractPointData
    for i = 0, kitchenSettings.Count - 1 do
        local ks = kitchenSettings[i]
        if ks ~= nil then
            local hasPoints, attractPoints = kitchenAttractData:TryGetValue(ks.id)
            if hasPoints then
                self:_SpawnChefsForKitchen(ks.id, ks.charIds, attractPoints)
            else
                logger.error(string.format("InnNpcSystem 厨房未找到挂点，kitchenId=%d", ks.id))
            end
        end
    end

    self.m_isPreparingChefs = false
    self:_TryScheduleChefShowEvent()
end

InnNpcSystem._SpawnChefsForKitchen = HL.Method(HL.Number, HL.Userdata, HL.Userdata)
        << function(self, kitchenId, charIds, attractPoints)
    if charIds == nil or charIds.Count <= 0 then
        return
    end

    local kitchenCache = {}
    self.m_chefEntityIds[kitchenId] = kitchenCache

    local count = math.min(charIds.Count, attractPoints.Count)
    for slot = 0, count - 1 do
        local intCharId = charIds[slot]
        if intCharId ~= 0 then
            local hasStr, strCharId = CS.Beyond.Cfg.Tables.charIdToStr:TryGetValue(intCharId)
            if not hasStr then
                logger.error(string.format(
                    "InnNpcSystem charIdToStr 未找到 intCharId=%d (kitchenId=%d, slot=%d)",
                    intCharId, kitchenId, slot))
            else
                local hasData, charData = Tables.innCharTable:TryGetValue(strCharId)
                if not hasData then
                    logger.error(string.format(
                        "InnNpcSystem innCharTable 未找到 charId=%s (kitchenId=%d, slot=%d)",
                        strCharId, kitchenId, slot))
                else
                    local point = attractPoints[slot]
                    local slotIndex = slot + 1
                    
                    
                    
                    self.m_npcIdSerial = self.m_npcIdSerial + 1
                    local npcId = string.format("inn_chef_%d_%d_%d", kitchenId, slotIndex, self.m_npcIdSerial)
                    self.m_pendingNpcRoutes[npcId] = {
                        kind = "chef",
                        kitchenId = kitchenId,
                        slotIndex = slotIndex,
                    }
                    self.m_pendingChefCreateCount = self.m_pendingChefCreateCount + 1
                    logger.info(string.format(
                        "[InnNpcSystem] _SpawnChefsForKitchen 请求创建 chef kitchenId=%d slot=%d charId=%s npcId=%s",
                        kitchenId, slotIndex, tostring(strCharId), npcId))
                    self:_ActiveRoutedNpc(
                        charData.npcId,
                        point.position,
                        point.rotation.eulerAngles,
                        NpcRestaurantRole.Chef,
                        npcId,
                        false)
                end
            end
        end
    end
end


InnNpcSystem._OnChefCreateFinished = HL.Method() << function(self)
    self.m_pendingChefCreateCount = math.max(0, self.m_pendingChefCreateCount - 1)
    self:_TryScheduleChefShowEvent()
end


InnNpcSystem._TryScheduleChefShowEvent = HL.Method() << function(self)
    if self.m_isPreparingChefs or self.m_pendingChefCreateCount > 0 or self.m_hasScheduledChefShowEvent then
        return
    end

    self.m_hasScheduledChefShowEvent = true
    local batchId = self.m_chefShowBatchId
    local delay = Tables.innManagementConst.allChefLoadFinishDelayShowTime
    logger.info(string.format(
        "[InnNpcSystem] 所有 chef 创建完成 安排延迟 %.2fs 后派发 ChefShow batchId=%d",
        delay, batchId))
    self:_StartTimer(delay, function()
        self:_TriggerChefShowEvent(batchId)
    end)
end


InnNpcSystem._TriggerChefShowEvent = HL.Method(HL.Number) << function(self, batchId)
    if batchId ~= self.m_chefShowBatchId then
        logger.info(string.format(
            "[InnNpcSystem] ChefShow 延迟到期 跳过 batchId=%d currentBatchId=%d 原因=批次已失效",
            batchId, self.m_chefShowBatchId))
        return
    end

    local chefCount = 0
    for kitchenId, kitchenCache in pairs(self.m_chefEntityIds) do
        for slotIndex, entityId in pairs(kitchenCache) do
            local entity = self:_TryGetNpcEntity(entityId)
            if entity ~= nil and entity.npcAICom ~= nil then
                chefCount = chefCount + 1
                logger.info(string.format(
                    "[InnNpcSystem] ChefShow 派发 kitchenId=%d slot=%d entityId=%s batchId=%d",
                    kitchenId, slotIndex, tostring(entityId), batchId))
                entity.npcAICom:TriggerEvent(AIEvent.NPCRestaurantChefShow)
            end
        end
    end
    logger.info(string.format(
        "[InnNpcSystem] ChefShow 派发完成 batchId=%d chefCount=%d",
        batchId, chefCount))
end

InnNpcSystem.GetChef = HL.Method(HL.Number, HL.Number).Return(HL.Opt(HL.Userdata))
        << function(self, kitchenId, slotIndex)
    local kitchenCache = self.m_chefEntityIds[kitchenId]
    if kitchenCache == nil or kitchenCache[slotIndex] == nil then
        return nil
    end
    return self:_TryGetNpcEntity(kitchenCache[slotIndex])
end





InnNpcSystem._PrepareOwner = HL.Method() << function(self)
    self.m_ownerEntityId = nil

    local strCharId = Tables.innManagementConst.jsspsiCharId
    if string.isEmpty(strCharId) then
        logger.error("InnNpcSystem InnManagementConst.jsspsiCharId 未配置")
        return
    end

    local hasData, charData = Tables.innCharTable:TryGetValue(strCharId)
    if not hasData then
        logger.error(string.format("InnNpcSystem innCharTable 未找到客栈老板娘 charId=%s", strCharId))
        return
    end

    local point = self.m_innSystem.ownerInitAttractPointData
    if point == nil or point.uuid == 0 then
        logger.error("InnNpcSystem 关卡未配置 OwnerInitPoint (ownerInitAttractPointData)")
        return
    end

    self.m_npcIdSerial = self.m_npcIdSerial + 1
    local npcId = string.format("inn_owner_%d", self.m_npcIdSerial)
    self.m_pendingNpcRoutes[npcId] = { kind = "owner" }
    logger.info(string.format(
        "[InnNpcSystem] _PrepareOwner 请求创建 owner charId=%s npcId=%s", tostring(strCharId), npcId))
    self:_ActiveRoutedNpc(
        charData.npcId,
        point.position,
        point.rotation.eulerAngles,
        NpcRestaurantRole.Owner,
        npcId,
        false)
end

InnNpcSystem.GetOwner = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    if self.m_ownerEntityId == nil then
        return nil
    end
    return self:_TryGetNpcEntity(self.m_ownerEntityId)
end

InnNpcSystem.PlayOwnerAutoServe = HL.Method(HL.String, HL.Number, HL.Opt(HL.Function))
        << function(self, itemId, deskId, onFinish)
    local itemPath = ""
    local modelId
    local _, dishData = Tables.innDishTable:TryGetValue(itemId)
    if dishData then
        modelId = dishData.attachmentModelId
    else
        local _, drinkData = Tables.innDrinkTable:TryGetValue(itemId)
        if drinkData then
            modelId = drinkData.attachmentModelId
        end
    end
    if modelId then
        itemPath = string.format("%s/%s", InnConst.INN_NPC_FOOD_ATTACHMENT_FOLDER, modelId)
    end
    self:_TriggerOwnerService(deskId, true, itemPath, onFinish)
end

InnNpcSystem.PlayOwnerAutoCheckout = HL.Method(HL.Number, HL.Opt(HL.Function))
        << function(self, deskId, onFinish)
    self:_TriggerOwnerService(deskId, false, "", onFinish)
end

InnNpcSystem._TriggerOwnerService = HL.Method(HL.Number, HL.Boolean, HL.String, HL.Opt(HL.Function))
        << function(self, deskId, isServe, itemPath, onFinish)
    local ownerEntity = self:GetOwner()
    if ownerEntity == nil then
        logger.error("InnNpcSystem._TriggerOwnerService 老板娘未找到")
        if onFinish ~= nil then onFinish() end
        return
    end
    local point = self:_GetRandomDeskServicePoint(deskId)
    if point == nil then
        logger.error(string.format(
            "InnNpcSystem._TriggerOwnerService 餐桌未配置 ServicePoint, deskId=%d", deskId))
        if onFinish ~= nil then onFinish() end
        return
    end

    
    self.m_pendingOwnerServiceCallback = onFinish

    logger.info(string.format(
        "[InnNpcSystem] _TriggerOwnerService 派发 OwnerService deskId=%d isServe=%s itemPath=%s seatUuid=%s",
        deskId, tostring(isServe), tostring(itemPath), tostring(point.uuid)))
    local data = AIEventData()
    data.ulongParam = point.uuid
    data.boolParam = isServe
    data.stringParam = itemPath
    ownerEntity.npcAICom:TriggerEvent(AIEvent.NPCRestaurantOwnerService, data)
end

InnNpcSystem._GetRandomDeskServicePoint = HL.Method(HL.Number).Return(HL.Opt(HL.Userdata))
        << function(self, deskId)
    local hasPoints, attractPoints = self.m_innSystem.autoServiceAttractPointData:TryGetValue(deskId)
    if not hasPoints or attractPoints == nil or attractPoints.Count <= 0 then
        return nil
    end
    local index = math.random(0, attractPoints.Count - 1)
    return attractPoints[index]
end

InnNpcSystem._InvokePendingOwnerServiceCallback = HL.Method() << function(self)
    local cb = self.m_pendingOwnerServiceCallback
    self.m_pendingOwnerServiceCallback = nil
    if cb ~= nil then
        cb()
    end
end


InnNpcSystem._OnOwnerServiceGenerateDish = HL.Method() << function(self)
    logger.info(string.format(
        "[InnNpcSystem] _OnOwnerServiceGenerateDish 菜品生成 hasCallback=%s",
        tostring(self.m_pendingOwnerServiceCallback ~= nil)))
    self:_InvokePendingOwnerServiceCallback()
end


InnNpcSystem._OnOwnerCheckoutMoney = HL.Method() << function(self)
    logger.info(string.format(
        "[InnNpcSystem] _OnOwnerCheckoutMoney 结账完成 hasCallback=%s",
        tostring(self.m_pendingOwnerServiceCallback ~= nil)))
    self:_InvokePendingOwnerServiceCallback()
end






InnNpcSystem.GetGuestEntities = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, guestId)
    local list = self.m_guestEntityIds and self.m_guestEntityIds[guestId] or nil
    if list == nil then
        return nil
    end
    local entities = {}
    for _, entityId in ipairs(list) do
        local entity = self:_TryGetNpcEntity(entityId)
        if entity ~= nil then
            table.insert(entities, entity)
        end
    end
    return entities
end

InnNpcSystem._GetGuestNpcIds = HL.Method(HL.Number).Return(HL.Opt(HL.Userdata))
        << function(self, guestId)
    local gameState = self.m_innSystem.gameState
    if gameState == nil then
        return nil
    end
    local hasGuest, guest = gameState.guestStates:TryGetValue(guestId)
    if not hasGuest or guest == nil then
        logger.error(string.format(
            "InnNpcSystem._GetGuestNpcIds 未找到 guestState, guestId=%d", guestId))
        return nil
    end
    local hasData, data = Tables.innGuestTable:TryGetValue(guest.templateId)
    if not hasData or data == nil then
        logger.error(string.format(
            "InnNpcSystem._GetGuestNpcIds innGuestTable 未找到 templateId=%s (guestId=%d)",
            tostring(guest.templateId), guestId))
        return nil
    end
    return data.npcIds
end



InnNpcSystem._PickAvailableAttractPoints = HL.Method(HL.Userdata, HL.Number).Return(HL.Table)
        << function(self, pool, count)
    local result = {}
    if pool == nil or pool.Count <= 0 or count <= 0 then
        return result
    end
    local availableIdx = {}
    for i = 0, pool.Count - 1 do
        local p = pool[i]
        if p ~= nil and p.attractStatus == AttractStatus.Available then
            table.insert(availableIdx, i)
        end
    end
    local takeCount = math.min(count, #availableIdx)
    for i = 1, takeCount do
        local r = math.random(i, #availableIdx)
        availableIdx[i], availableIdx[r] = availableIdx[r], availableIdx[i]
        table.insert(result, pool[availableIdx[i]])
    end
    return result
end

InnNpcSystem._ReleaseGuestQueuePoints = HL.Method(HL.Number) << function(self, guestId)
    local points = self.m_guestQueuePoints[guestId]
    if points == nil then
        return
    end
    self.m_guestQueuePoints[guestId] = nil
    logger.info(string.format(
        "[InnNpcSystem] _ReleaseGuestQueuePoints guestId=%d count=%d", guestId, #points))
    local attractPointSystem = GameWorld.aiManager.attractPointSystem
    for _, point in ipairs(points) do
        if point ~= nil and point.uuid ~= 0 then
            attractPointSystem:SetAttractPointStatus(
                AttractObjectType.Npc, point.uuid, AttractStatus.Available)
        end
    end

    self:_TrySpawnWaitingQueueGuests()
end



InnNpcSystem._SpawnGuestForQueue = HL.Method(HL.Number).Return(HL.Boolean) << function(self, guestId)
    local npcIds = self:_GetGuestNpcIds(guestId)
    if npcIds == nil or npcIds.Count <= 0 then
        return false
    end

    local pool = self.m_innSystem.guestQueueAttractPointData
    local pickedPoints = self:_PickAvailableAttractPoints(pool, npcIds.Count)
    
    
    if #pickedPoints < npcIds.Count then
        logger.info(string.format(
            "InnNpcSystem._SpawnGuestForQueue 空闲队列点位不足，暂不生成，等待空位, guestId=%d, need=%d, got=%d",
            guestId, npcIds.Count, #pickedPoints))
        return false
    end

    self.m_guestEntityIds[guestId] = {}
    local queuePoints = {}
    self.m_guestQueuePoints[guestId] = queuePoints

    local attractPointSystem = GameWorld.aiManager.attractPointSystem
    local count = math.min(npcIds.Count, #pickedPoints)
    for i = 1, count do
        local npcId = npcIds[i - 1]
        local point = pickedPoints[i]
        attractPointSystem:SetAttractPointStatus(
            AttractObjectType.Npc, point.uuid, AttractStatus.Using)
        table.insert(queuePoints, point)

        self.m_npcIdSerial = self.m_npcIdSerial + 1
        local routeId = string.format("inn_guest_%d_%d_%d", guestId, i, self.m_npcIdSerial)
        self.m_pendingNpcRoutes[routeId] = {
            kind = "guest",
            guestId = guestId,
        }
        logger.info(string.format(
            "[InnNpcSystem] _SpawnGuestForQueue 请求创建 guest guestId=%d idx=%d/%d npcTpl=%s queuePointUuid=%s routeId=%s",
            guestId, i, count, tostring(npcId), tostring(point.uuid), routeId))
        self:_ActiveRoutedNpc(
            npcId,
            point.position,
            point.rotation.eulerAngles,
            NpcRestaurantRole.Guest,
            routeId,
            true)
    end
    return true
end




InnNpcSystem._TrySpawnWaitingQueueGuests = HL.Method() << function(self)
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.guestQueue == nil or gameState.isEndingGame then
        return
    end
    for i = 0, gameState.guestQueue.Count - 1 do
        local guestId = gameState.guestQueue[i]
        if self.m_guestEntityIds[guestId] == nil and self.m_guestQueuePoints[guestId] == nil then
            if not self:_SpawnGuestForQueue(guestId) then
                break
            end
        end
    end
end




InnNpcSystem._SpawnGuestForDesk = HL.Method(HL.Number, HL.Number)
        << function(self, guestId, deskId)
    local npcIds = self:_GetGuestNpcIds(guestId)
    if npcIds == nil or npcIds.Count <= 0 then
        return
    end

    local hasPoints, pool = self.m_innSystem.deskAttractPointData:TryGetValue(deskId)
    if not hasPoints or pool == nil then
        logger.error(string.format(
            "InnNpcSystem._SpawnGuestForDesk 未找到桌位点位, deskId=%d, guestId=%d", deskId, guestId))
        return
    end

    local pickedPoints = self:_PickAvailableAttractPoints(pool, npcIds.Count)
    if #pickedPoints <= 0 then
        logger.error(string.format(
            "InnNpcSystem._SpawnGuestForDesk 未找到空闲座位, deskId=%d, guestId=%d, need=%d",
            deskId, guestId, npcIds.Count))
        return
    end
    if #pickedPoints < npcIds.Count then
        logger.error(string.format(
            "InnNpcSystem._SpawnGuestForDesk 桌位座位不足, deskId=%d, guestId=%d, need=%d, got=%d",
            deskId, guestId, npcIds.Count, #pickedPoints))
    end

    self.m_guestEntityIds[guestId] = {}

    local count = math.min(npcIds.Count, #pickedPoints)
    for i = 1, count do
        local npcId = npcIds[i - 1]
        local point = pickedPoints[i]

        self.m_npcIdSerial = self.m_npcIdSerial + 1
        local routeId = string.format("inn_guest_%d_%d_%d", guestId, i, self.m_npcIdSerial)
        
        
        
        self.m_pendingNpcRoutes[routeId] = {
            kind = "guest",
            guestId = guestId,
            enterOrderSeatUuid = point.uuid,
            playAppearSound = (i == 1),
        }
        logger.info(string.format(
            "[InnNpcSystem] _SpawnGuestForDesk 请求创建 guest deskId=%d guestId=%d idx=%d/%d npcTpl=%s seatUuid=%s routeId=%s",
            deskId, guestId, i, count, tostring(npcId), tostring(point.uuid), routeId))
        self:_ActiveRoutedNpc(
            npcId,
            point.position,
            point.rotation.eulerAngles,
            NpcRestaurantRole.Guest,
            routeId,
            false)
    end
end

InnNpcSystem._BindPendingGuestRoutesToDesk = HL.Method(HL.Number, HL.Number, HL.Boolean).Return(HL.Number)
        << function(self, guestId, deskId, playAppearSound)
    local pendingRoutes = {}
    for routeId, route in pairs(self.m_pendingNpcRoutes) do
        if route.kind == "guest" and route.guestId == guestId
                and (route.enterOrderSeatUuid == nil or route.enterOrderSeatUuid == 0) then
            table.insert(pendingRoutes, { routeId = routeId, route = route })
        end
    end
    if #pendingRoutes <= 0 then
        return 0
    end
    
    table.sort(pendingRoutes, function(a, b) return a.routeId < b.routeId end)

    local hasPoints, pool = self.m_innSystem.deskAttractPointData:TryGetValue(deskId)
    if not hasPoints or pool == nil then
        logger.error(string.format(
            "InnNpcSystem._BindPendingGuestRoutesToDesk 未找到桌位点位, deskId=%d, guestId=%d", deskId, guestId))
        return 0
    end
    local pickedPoints = self:_PickAvailableAttractPoints(pool, #pendingRoutes)
    if #pickedPoints < #pendingRoutes then
        logger.error(string.format(
            "InnNpcSystem._BindPendingGuestRoutesToDesk 桌位座位不足, deskId=%d, guestId=%d, need=%d, got=%d",
            deskId, guestId, #pendingRoutes, #pickedPoints))
    end

    local boundCount = math.min(#pendingRoutes, #pickedPoints)
    for i = 1, boundCount do
        local entry = pendingRoutes[i]
        entry.route.enterOrderSeatUuid = pickedPoints[i].uuid
        entry.route.playAppearSound = playAppearSound and i == 1
        logger.info(string.format(
            "[InnNpcSystem] _BindPendingGuestRoutesToDesk 排队 NPC 尚在创建 改为落位后直接入座 deskId=%d guestId=%d routeId=%s seatUuid=%s",
            deskId, guestId, entry.routeId, tostring(pickedPoints[i].uuid)))
    end
    return boundCount
end

InnNpcSystem._TriggerEventOnGuestEntities = HL.Method(HL.Number, HL.Any)
        << function(self, guestId, aiEvent)
    local list = self.m_guestEntityIds[guestId]
    if list == nil then
        logger.info(string.format(
            "[InnNpcSystem] _TriggerEventOnGuestEntities guestId=%d 无 entity 列表 跳过 aiEvent=%s",
            guestId, tostring(aiEvent)))
        return
    end
    logger.info(string.format(
        "[InnNpcSystem] _TriggerEventOnGuestEntities 派发 AI 事件 guestId=%d count=%d aiEvent=%s",
        guestId, #list, tostring(aiEvent)))
    for _, entityId in ipairs(list) do
        local entity = self:_TryGetNpcEntity(entityId)
        if entity ~= nil and entity.npcAICom ~= nil then
            entity.npcAICom:TriggerEvent(aiEvent)
        end
    end
end

InnNpcSystem._DeactivateGuestEntities = HL.Method(HL.Number) << function(self, guestId)
    local list = self.m_guestEntityIds[guestId]
    if list == nil then
        return
    end
    logger.info(string.format(
        "[InnNpcSystem] _DeactivateGuestEntities guestId=%d count=%d", guestId, #list))
    self.m_guestEntityIds[guestId] = nil
    for _, entityId in ipairs(list) do
        self.m_innSystem:RemoveGameNpc(entityId)
    end
    self:_CancelPendingGuestRoutes(guestId)
end




InnNpcSystem._TryAttachSpecialGuestEffect = HL.Method(HL.Number, CS.Beyond.Gameplay.Core.Entity)
        << function(self, guestId, entity)
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.guestStates == nil then
        return
    end
    local hasGuest, guest = gameState.guestStates:TryGetValue(guestId)
    if not hasGuest or guest == nil
            or guest.guestType ~= CS.Proto.INN_MANAGEMENT_GUEST_TYPE.GuestTypeSpecial then
        return
    end

    if entity.npcCrowd == nil or entity.npcCrowd.unionAnimator == nil then
        logger.error(string.format(
            "InnNpcSystem 特殊客人挂特效失败，unionAnimator 缺失, guestId=%d, entityId=%s",
            guestId, tostring(entity.serverId)))
        return
    end
    local mountTransform = entity.npcCrowd.unionAnimator:GetNodeTransform(
        CS.Beyond.Gameplay.MountPoint.LookAtPoint)
    if mountTransform == nil then
        logger.error(string.format(
            "InnNpcSystem 特殊客人挂特效失败，HeadLabel 挂点缺失, guestId=%d", guestId))
        return
    end

    local effectPtr = GameInstance.effectManager:CreateEffectOnTransform(
        InnConst.INN_SPECIAL_GUEST_EFFECT_ID, mountTransform)
    self.m_specialGuestEffects[entity.serverId] = effectPtr
end

InnNpcSystem._PlayGuestAppearOnDeskSound = HL.Method(HL.Number, CS.Beyond.Gameplay.Core.Entity)
        << function(self, guestId, entity)
    local isSpecial = false
    local gameState = self.m_innSystem.gameState
    if gameState ~= nil and gameState.guestStates ~= nil then
        local hasGuest, guest = gameState.guestStates:TryGetValue(guestId)
        if hasGuest and guest ~= nil
                and guest.guestType == CS.Proto.INN_MANAGEMENT_GUEST_TYPE.GuestTypeSpecial then
            isSpecial = true
        end
    end
    AudioManager.PostEvent(entity, isSpecial and "au_int_system_inn_customer_vip" or "au_int_system_inn_customer")
end

InnNpcSystem._OnClientNpcDeactivated = HL.Method(HL.Any) << function(self, entityId)
    local owner = self.m_npcOwnerById[entityId]
    if owner ~= nil then
        self.m_npcOwnerById[entityId] = nil
        if owner.kind == "guest" then
            local list = self.m_guestEntityIds[owner.guestId]
            if list ~= nil then
                lume.remove(list, entityId)
            end
        elseif owner.kind == "chef" then
            local kitchenCache = self.m_chefEntityIds[owner.kitchenId]
            if kitchenCache ~= nil and kitchenCache[owner.slotIndex] == entityId then
                kitchenCache[owner.slotIndex] = nil
            end
        elseif owner.kind == "owner" then
            self.m_ownerEntityId = nil
        end
    end

    local effectPtr = self.m_specialGuestEffects[entityId]
    if effectPtr == nil then
        return
    end
    self.m_specialGuestEffects[entityId] = nil
    logger.info(string.format(
        "[InnNpcSystem] _OnClientNpcDeactivated 特殊客人特效卸载 entityId=%s", tostring(entityId)))
    local effect = effectPtr:Lock()
    if effect ~= nil then
        effect:Finish()
    end
end




InnNpcSystem._ResetDeskAttractPointsToAvailable = HL.Method(HL.Number) << function(self, deskId)
    local hasSeats, seats = self.m_innSystem.deskAttractPointData:TryGetValue(deskId)
    if not hasSeats or seats == nil then
        return
    end
    local attractPointSystem = GameWorld.aiManager.attractPointSystem
    for i = 0, seats.Count - 1 do
        local point = seats[i]
        if point ~= nil and point.uuid ~= 0 then
            attractPointSystem:SetAttractPointStatus(
                AttractObjectType.Npc, point.uuid, AttractStatus.Available)
        end
    end
end






InnNpcSystem._OnGuestQueueChanged = HL.Method() << function(self)
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.guestQueue == nil then
        return
    end

    local currentSet = {}
    for i = 0, gameState.guestQueue.Count - 1 do
        currentSet[gameState.guestQueue[i]] = true
    end

    logger.info(string.format(
        "[InnNpcSystem] _OnGuestQueueChanged 队列变化 queueCount=%d", gameState.guestQueue.Count))

    
    self:_TrySpawnWaitingQueueGuests()

    local leftIds = {}
    for guestId, _ in pairs(self.m_guestQueuePoints) do
        if not currentSet[guestId] then
            table.insert(leftIds, guestId)
        end
    end

    for _, guestId in ipairs(leftIds) do
        self:_ReleaseGuestQueuePoints(guestId)

        local onDesk = false
        if gameState.deskStates ~= nil then
            for _, deskState in cs_pairs(gameState.deskStates) do
                if deskState ~= nil and deskState.guestId == guestId then
                    onDesk = true
                    break
                end
            end
        end

        logger.info(string.format(
            "[InnNpcSystem] _OnGuestQueueChanged guestId=%d 离队 onDesk=%s",
            guestId, tostring(onDesk)))

        if not onDesk then
            self:_DeactivateGuestEntities(guestId)
        end
    end
end







InnNpcSystem._OnDeskStateChanged = HL.Method(HL.Number) << function(self, deskId)
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil or gameState.isEndingGame then
        return
    end
    local hasDesk, desk = gameState.deskStates:TryGetValue(deskId)
    if not hasDesk or desk == nil then
        return
    end

    local prevStatus = self.m_lastKnownDeskStatus[deskId] or DeskStatus.DeskStatusEmpty
    local prevGuestId = self.m_lastKnownDeskGuestId[deskId] or 0
    local newStatus = desk.deskStatus
    local curGuestId = desk.guestId

    
    if newStatus == prevStatus then
        if curGuestId ~= 0 then
            self.m_lastKnownDeskGuestId[deskId] = curGuestId
        end
        return
    end

    self.m_lastKnownDeskStatus[deskId] = newStatus
    if curGuestId ~= 0 then
        self.m_lastKnownDeskGuestId[deskId] = curGuestId
    end

    logger.info(string.format(
        "[InnNpcSystem] _OnDeskStateChanged deskId=%d %s -> %s prevGuestId=%d curGuestId=%d",
        deskId, tostring(prevStatus), tostring(newStatus), prevGuestId, curGuestId))

    if newStatus == DeskStatus.DeskStatusOrdering then
        if curGuestId == 0 then
            logger.error(string.format(
                "InnNpcSystem._OnDeskStateChanged Ordering 状态下 desk.guestId=0, deskId=%d", deskId))
            return
        end
        self:_ReleaseGuestQueuePoints(curGuestId)

        
        
        
        
        
        if prevGuestId ~= 0 and prevGuestId ~= curGuestId then
            logger.info(string.format(
                "[InnNpcSystem] _OnDeskStateChanged Ordering 桌位直接复用兜底 deskId=%d prevGuestId=%d curGuestId=%d",
                deskId, prevGuestId, curGuestId))
            self:_DeactivateGuestEntities(prevGuestId)
            self:_ResetDeskAttractPointsToAvailable(deskId)
        end

        local list = self:GetGuestEntities(curGuestId)
        if list == nil or #list <= 0 then
            
            
            
            if self:_BindPendingGuestRoutesToDesk(curGuestId, deskId, true) > 0 then
                return
            end
            
            
            
            self:_SpawnGuestForDesk(curGuestId, deskId)
            return
        end

        
        self:_PlayGuestAppearOnDeskSound(curGuestId, list[1])
        local hasSeats, seats = self.m_innSystem.deskAttractPointData:TryGetValue(deskId)
        if not hasSeats or seats == nil then
            logger.error(string.format(
                "InnNpcSystem._OnDeskStateChanged 未找到桌位座位, deskId=%d", deskId))
            return
        end

        
        for idx, entity in ipairs(list) do
            if entity ~= nil and entity.npcAICom ~= nil then
                local picked = self:_PickAvailableAttractPoints(seats, 1)
                if #picked <= 0 then
                    logger.error(string.format(
                        "InnNpcSystem._OnDeskStateChanged 桌位空闲座位不足, deskId=%d, guestId=%d",
                        deskId, curGuestId))
                    break
                end
                logger.info(string.format(
                    "[InnNpcSystem] _OnDeskStateChanged 派发 GuestEnterOrder deskId=%d guestId=%d entityIdx=%d/%d seatUuid=%s",
                    deskId, curGuestId, idx, #list, tostring(picked[1].uuid)))
                local data = AIEventData()
                data.ulongParam = picked[1].uuid
                entity.npcAICom:TriggerEvent(AIEvent.NPCRestaurantGuestEnterOrder, data)
            end
        end
        
        self:_BindPendingGuestRoutesToDesk(curGuestId, deskId, false)
    elseif newStatus == DeskStatus.DeskStatusWaitingForEating then
        self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestFinishOrder)
    elseif newStatus == DeskStatus.DeskStatusEating then
        self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestEnterEating)
    elseif newStatus == DeskStatus.DeskStatusWaitingForPay then
        self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestFinishEating)
    elseif newStatus == DeskStatus.DeskStatusLeaving then
        if prevStatus == DeskStatus.DeskStatusWaitingForPay then
            self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestFinishCheckOut)
        elseif prevStatus == DeskStatus.DeskStatusOrderingFailed then
            self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestFinishOrderFailed)
        end
    elseif newStatus == DeskStatus.DeskStatusOrderingFailed then
        self:_TriggerEventOnGuestEntities(curGuestId, AIEvent.NPCRestaurantGuestOrderFailed)
    elseif newStatus == DeskStatus.DeskStatusEmpty then
        
        if prevGuestId ~= 0 then
            logger.info(string.format(
                "[InnNpcSystem] _OnDeskStateChanged Empty 兜底 Deactivate prevGuestId=%d deskId=%d",
                prevGuestId, deskId))
            self:_DeactivateGuestEntities(prevGuestId)
        end
        logger.info(string.format(
            "[InnNpcSystem] _OnDeskStateChanged Empty 兜底重置桌位 attract deskId=%d", deskId))
        self:_ResetDeskAttractPointsToAvailable(deskId)
        self.m_lastKnownDeskGuestId[deskId] = nil
    end
end

InnNpcSystem._HideGuestEntities = HL.Method(HL.Number, HL.Number) << function(self, guestId, fadeTime)
    local list = self:GetGuestEntities(guestId)
    if list == nil then
        return
    end
    local npcManager = GameWorld.npcManager
    for _, entity in ipairs(list) do
        if entity ~= nil and entity.npc ~= nil then
            npcManager:HideNpcById(entity.npc.npcId, fadeTime)
        end
    end
end

InnNpcSystem._OnGameEndBegin = HL.Method() << function(self)
    local gameState = self.m_innSystem.gameState
    if gameState == nil or gameState.deskStates == nil then
        return
    end
    local fadeTime = Tables.innManagementConst.autoCheckoutTime
    for _, deskState in cs_pairs(gameState.deskStates) do
        if deskState ~= nil
                and deskState.guestId ~= 0
                and deskState.deskStatus ~= DeskStatus.DeskStatusLeaving then
            self:_HideGuestEntities(deskState.guestId, fadeTime)
        end
    end

    local owner = self:GetOwner()
    if owner ~= nil and owner.npc ~= nil then
        GameWorld.npcManager:HideNpcById(owner.npc.npcId, fadeTime)
    end
end



HL.Commit(InnNpcSystem)
return InnNpcSystem
