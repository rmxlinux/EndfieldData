local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')








CommonIntTriggerSystem = HL.Class('CommonIntTriggerSystem', LuaSystemBase.LuaSystemBase)





CommonIntTriggerSystem.OnInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.COMPONENT_CALL_LUA_UI_ON, function(args)
        self:CallLuaUI(args, true)
    end)
    self:RegisterMessage(MessageConst.COMPONENT_CALL_LUA_UI_OFF, function(args)
        self:CallLuaUI(args, false)
    end)
end



CommonIntTriggerSystem.OnRelease = HL.Override() << function(self)
end





CommonIntTriggerSystem.CallLuaUI = HL.Method(HL.Table, HL.Boolean) << function(self, args, isOn)
    local argList, camConfigsCSCS = unpack(args)
    local name = argList[0]
    local funcName = name .. (isOn and "_ON" or "_OFF")
    local func = self[funcName]
    if not func then
        logger.error("No Func", funcName, name, args)
        return
    end

    local count = argList.Count - 1
    
    if count == 0 then
        func(self, camConfigsCSCS)
    elseif count == 1 then
        func(self, argList[1], camConfigsCSCS)
    elseif count == 2 then
        func(self, argList[1], argList[2], camConfigsCSCS)
    elseif count == 3 then
        func(self, argList[1], argList[2], argList[3], camConfigsCSCS)
    elseif count == 4 then
        func(self, argList[1], argList[2], argList[3], argList[4], camConfigsCSCS)
    elseif count == 5 then
        func(self, argList[1], argList[2], argList[3], argList[4], argList[5], camConfigsCSCS)
    elseif count == 6 then
        func(self, argList[1], argList[2], argList[3], argList[4], argList[5], argList[6], camConfigsCSCS)
    end
    AudioManager.PostEvent("au_int_template_slience")
end







CommonIntTriggerSystem.m_curSpaceshipRoomCamConfigs = HL.Field(HL.Table)


CommonIntTriggerSystem.m_curSpaceshipRoomCamStack = HL.Field(HL.Table)






CommonIntTriggerSystem.SpaceshipRoom_ON = HL.Method(HL.String, HL.Opt(HL.Any)) << function(self, roomId, camConfigsCS)
    local unlocked, room = GameInstance.player.spaceship:TryGetRoom(roomId)
    if not unlocked or GameInstance.player.spaceship.isViewingFriend then
        return
    end

    GameInstance.player.spaceship:SetSpaceshipRoomCamConfig(roomId, "default", camConfigsCS[0]);
    GameInstance.player.spaceship:SetSpaceshipRoomCamConfig(roomId, "upgrade", camConfigsCS[1]);

    local roomType = room.type
    local sourceId = roomId
    local phaseId = PhaseId[SpaceshipConst.ROOM_PHASE_ID_NAME_MAP_BY_TYPE[roomType]]
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]
    local roomName = roomTypeData.name
    local openInteractOptArgs = {
        type = CS.Beyond.Gameplay.Core.InteractOptionType.Spaceship,
        sourceId = sourceId,
        text = roomTypeData.viewOptName,
        action = function()
            GameInstance.player.spaceship:SetCurSpaceshipRoomCamConfig(roomId, camConfigsCS[0])
            GameInstance.player.spaceship:MoveCamToSpaceshipRoom(roomId)
            TimerManager:StartTimer(0.5, function()
                PhaseManager:OpenPhase(phaseId, { roomId = roomId, moveCam = true, })
            end)
        end,
        icon = roomTypeData.icon,
        subIndex = 1,
        sortId = 1,
        roomName = roomName,
    }
    Notify(MessageConst.ADD_INTERACT_OPTION, openInteractOptArgs)

    local isMaxLv = room.lv >= room.maxLv
    local upgradeInteractOptArgs = {
        type = CS.Beyond.Gameplay.Core.InteractOptionType.Spaceship,
        sourceId = sourceId,
        text = isMaxLv and roomTypeData.maxLvOptName or roomTypeData.upgradeOptName,
        action = function()
            GameInstance.player.spaceship:SetCurSpaceshipRoomCamConfig(roomId, camConfigsCS[1])
            PhaseManager:OpenPhase(PhaseId.SpaceshipRoomUpgrade, {
                roomId = roomId,
                moveCam = true,
            })
        end,
        icon = isMaxLv and "btn_common_exchange_icon" or "ss_room_upgrade_int_icon",
        subIndex = 2,
        sortId = 1,
    }
    Notify(MessageConst.ADD_INTERACT_OPTION, upgradeInteractOptArgs)
end





CommonIntTriggerSystem.SpaceshipRoom_OFF = HL.Method(HL.String, HL.Opt(HL.Any)) << function(self, roomId, camConfigsCS)
    local unlocked, room = GameInstance.player.spaceship:TryGetRoom(roomId)
    if not unlocked or GameInstance.player.spaceship.isViewingFriend then
        return
    end
    local sourceId = roomId
    Notify(MessageConst.REMOVE_INTERACT_OPTION, {
        type = CS.Beyond.Gameplay.Core.InteractOptionType.Spaceship,
        sourceId = sourceId,
        subIndex = 1,
    })
    Notify(MessageConst.REMOVE_INTERACT_OPTION, {
        type = CS.Beyond.Gameplay.Core.InteractOptionType.Spaceship,
        sourceId = sourceId,
        subIndex = 2,
    })
end






HL.Commit(CommonIntTriggerSystem)
return CommonIntTriggerSystem
