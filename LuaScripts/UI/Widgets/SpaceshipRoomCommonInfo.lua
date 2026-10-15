local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

SpaceshipRoomCommonInfo = HL.Class('SpaceshipRoomCommonInfo', UIWidgetBase)

SpaceshipRoomCommonInfo.m_genPersonnelCellCache = HL.Field(HL.Forward("UIListCache"))

SpaceshipRoomCommonInfo.m_roomId = HL.Field(HL.String) << ""

SpaceshipRoomCommonInfo.m_personnelInfo = HL.Field(HL.Table)

SpaceshipRoomCommonInfo.m_personnelWorkTimeTick = HL.Field(HL.Thread)

SpaceshipRoomCommonInfo.m_hasPersonStation = HL.Field(HL.Boolean) << false

SpaceshipRoomCommonInfo.m_hasPersonStationButNoneWorking = HL.Field(HL.Boolean) << false



SpaceshipRoomCommonInfo._OnFirstTimeInit = HL.Override() << function(self)
    self.m_genPersonnelCellCache = UIUtils.genCellCache(self.view.ssRoomPersonnelCell)
    self:GetUICtrl():BindInputPlayerAction("ss_occupancy_manage", function()
        self:_OnPersonnelInfoClick()
    end, self.view.personnelList.groupId)

    self:RegisterMessage(MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION, function()
        if GameInstance.player.spaceship.isViewingFriend then
            return
        end
        self:OnSpaceshipSyncRoomStation()
    end)

    self:RegisterMessage(MessageConst.SPACESHIP_ON_ROOM_LEVEL_UP, function(args)
        self:OnSpaceshipLevelUp(args)
    end)

    self:RegisterMessage(MessageConst.SPACESHIP_ON_EDIT_SCHEDULE, function()
        if GameInstance.player.spaceship.isViewingFriend then
            return
        end
        self:_UpdateStationState()
    end)
end

SpaceshipRoomCommonInfo.InitSpaceshipRoomCommonInfo = HL.Method(HL.String, HL.Opt(HL.Boolean, HL.Boolean))
    << function(self, roomId, isMoveCam, isRemoteCamera)
    self:_FirstTimeInit()

    self.m_roomId = roomId
    local roomType = SpaceshipUtils.getRoomTypeByRoomId(roomId)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]
    local roomColor = UIUtils.getColorByString(roomTypeData.color)
    self.view.icon:LoadSprite(UIConst.UI_SPRITE_SPACESHIP_ROOM, roomTypeData.icon)
    self.view.deco.color = roomColor
    self.view.roomBgImg.color = roomColor

    self.view.contentBtn.onClick:AddListener(function()
        GameInstance.player.spaceship:SetCurSpaceshipRoomCamConfig(roomId, CS.Beyond.Gameplay.SpaceshipSystem.UPGRADE_CAM_BLEND_KEY)
        PhaseManager:OpenPhase(PhaseId.SpaceshipRoomUpgrade, {
            roomId = roomId,
            moveCam = isMoveCam,
            isRemoteCamera = isRemoteCamera,
        })
    end)

    self:_UpdateStationState()

    self:_UpdateCharTime()
    self.m_personnelWorkTimeTick = self:_StartCoroutine(function()
        while(true) do
            coroutine.wait(1)
            self:_UpdateCharTime()
        end
    end)
end

SpaceshipRoomCommonInfo._UpdateCharTime = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    for _, personnel in ipairs(self.m_personnelInfo) do
        if not personnel.locked and not personnel.needAdd then
            local charLeftTime = spaceship:GetCharLeftTime(personnel.charId)
            local cell = personnel.cell
            cell.timeTxt.text = UIUtils.getLeftTimeToSecond(charLeftTime)
            local staminaNode = cell.ssCharHeadCell.view.staminaNode
            SpaceshipUtils.updateSSCharStamina(staminaNode, personnel.charId)
        end
    end
end


SpaceshipRoomCommonInfo._UpdateStationState = HL.Method() << function(self)
    local _, roomInfo = GameInstance.player.spaceship:TryGetRoom(self.m_roomId)
    self:_UpdatePersonnelNodeState(roomInfo)
    self:_UpdateLvInfo(roomInfo)
    self:_UpdateStationPersonnelInfo(roomInfo)
    self:_UpdateRoomAttrInfo(roomInfo)
end

SpaceshipRoomCommonInfo._UpdateLvInfo = HL.Method(HL.Opt(HL.Any)) << function(self, roomInfo)
    if not roomInfo then
        local _, curRoomInfo = GameInstance.player.spaceship:TryGetRoom(self.m_roomId)
        roomInfo = curRoomInfo
    end
    self.view.lvDotNode:InitLvDotNode(roomInfo.lv, roomInfo.maxLv, self.view.deco.color)

    local showTxt = roomInfo.lv == roomInfo.maxLv and Language.LUA_SPACESHIP_ROOM_MAX_LV_DESC
            or Language.LUA_SPACESHIP_ROOM_NOT_MAX_LV_DESC
    self.view.lvStateTxt.text = showTxt
end

SpaceshipRoomCommonInfo._UpdateStationPersonnelInfo = HL.Method(HL.Opt(HL.Any)) << function(self, roomInfo)
    local spaceship = GameInstance.player.spaceship
    if not roomInfo then
        local _, curRoomInfo = spaceship:TryGetRoom(self.m_roomId)
        roomInfo = curRoomInfo
        self:_UpdatePersonnelNodeState(roomInfo)
    end
    local stationCharNum = roomInfo.stationedCharList.Count
    local maxStationCharNum = roomInfo.maxStationCharNum
    self.view.numberTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_COMMON_INFO_STATIONED_NUMBER_FORMAT,
                                             stationCharNum, maxStationCharNum)

    local preStation = self.m_hasPersonStation
    self.m_hasPersonStation = stationCharNum < 1
    if not preStation and self.m_hasPersonStation then
        self.view.noStationTxtNode.gameObject:SetActiveIfNecessary(true)
    elseif preStation and not self.m_hasPersonStation then
        self.view.noStationTxtNode:PlayOutAnimation(function()
            self.view.noStationTxtNode.gameObject:SetActiveIfNecessary(false)
        end)
    end


    local noneWorking = stationCharNum > 0
    for _, charId in pairs(roomInfo.stationedCharList) do
        if spaceship:IsCharWorking(charId) then
            noneWorking = false
            break
        end
    end
    local preNoneWorking = self.m_hasPersonStationButNoneWorking
    self.m_hasPersonStationButNoneWorking = noneWorking
    if not preNoneWorking and self.m_hasPersonStationButNoneWorking then
        
        self.view.noWorkingTxtNode.gameObject:SetActiveIfNecessary(true)
    elseif preNoneWorking and not self.m_hasPersonStationButNoneWorking then
        
        self.view.noWorkingTxtNode:PlayOutAnimation(function()
            self.view.noWorkingTxtNode.gameObject:SetActiveIfNecessary(false)
        end)
    end

    local personnelInfo = {}
    self.m_personnelInfo = personnelInfo
    for i = 1, 3 do
        local personnel = {}
        local locked = i > maxStationCharNum
        local needAdd = i > stationCharNum
        personnel.locked = locked
        personnel.needAdd = needAdd

        personnel.targetRoomId = self.m_roomId
        personnel.onClick = function()
            self:_OnPersonnelInfoClick()
        end

        if locked then
            personnel.unlockDesc = Language["LUA_SPACESHIP_ROOM_COMMON_INFO_UNLOCK_CONDITION_LEVEL_"..tostring(i)]
        end

        if not needAdd then
            personnel.charId = roomInfo.stationedCharList[CSIndex(i)]
        end

        table.insert(personnelInfo, personnel)
    end

    self.m_genPersonnelCellCache:Refresh(#personnelInfo, function(cell, luaIndex)
        personnelInfo[luaIndex].cell = cell

        local personnel = personnelInfo[luaIndex]
        local locked = personnel.locked
        local needAdd = personnel.needAdd

        cell.locked.gameObject:SetActiveIfNecessary(locked)
        cell.toBeAdded.gameObject:SetActiveIfNecessary(not locked and needAdd)
        cell.ssCharHeadCell.gameObject:SetActiveIfNecessary(not locked and not needAdd)
        cell.timeNode.gameObject:SetActiveIfNecessary(not locked and not needAdd)

        if not locked and not needAdd then
            cell.ssCharHeadCell:InitSSCharHeadCell({ charId = personnel.charId,
                                                     targetRoomId = personnel.targetRoomId,
                                                     onClick = personnel.onClick })
        elseif not locked and needAdd then
            cell.toBeAdded.onClick:RemoveAllListeners()
            cell.toBeAdded.onClick:AddListener(function()
                if personnel.onClick then
                    personnel.onClick()
                end
            end)
        elseif locked then
            cell.unlockTxt:SetAndResolveTextStyle(personnel.unlockDesc)
        end
    end)

end

SpaceshipRoomCommonInfo._UpdatePersonnelNodeState = HL.Method(HL.Any) << function(self, roomInfo)
    local roomColor = SpaceshipUtils.getRoomColor(self.m_roomId)
    self.view.roomBgImg.color = roomColor

    local scheduleEnabled = SpaceshipUtils.isScheduleUnlocked()
        and SpaceshipUtils.isRoomScheduleSupported(self.m_roomId)
        and not SpaceshipUtils.isSingleTeamMode(self.m_roomId)
    if not scheduleEnabled then
        self.view.personnelNode:SetState("Single")
        return
    end

    local TeamType = CS.Proto.SpaceshipCharTeamType
    local curTeam = GameInstance.player.spaceship:GetRoomCurrentWorkingTeam(self.m_roomId)
    self.view.personnelNode:SetState(curTeam == TeamType.B and "B" or "A")
    self.view.personnelNode:SetState(roomInfo.schedule and roomInfo.schedule.AutoSchedule and "AutoOpen" or "AutoClose")
end

SpaceshipRoomCommonInfo._OnPersonnelInfoClick = HL.Method() << function(self)
    local phaseId = SpaceshipUtils.isSingleTeamMode(self.m_roomId) and PhaseId.SpaceshipStation
        or PhaseId.SpaceshipSchedule
    PhaseManager:OpenPhase(phaseId, { roomId = self.m_roomId })
end

SpaceshipRoomCommonInfo._UpdateRoomAttrInfo = HL.Method(HL.Opt(HL.Any)) << function(self, roomInfo)
    if not roomInfo then
        local _, curRoomInfo = GameInstance.player.spaceship:TryGetRoom(self.m_roomId)
        roomInfo = curRoomInfo
    end
    self.view.ssRoomEffectInfoNode:InitSSRoomEffectInfoNode({
        attrsMap = roomInfo.attrsMap,
        color = SpaceshipUtils.getRoomColor(self.m_roomId),
    })
end

SpaceshipRoomCommonInfo.OnSpaceshipSyncRoomStation = HL.Method() << function(self)
    self:_UpdateStationState()
end

SpaceshipRoomCommonInfo.OnSpaceshipLevelUp = HL.Method(HL.Any) << function(self, args)
    local roomId = unpack(args)
    if roomId ~= self.m_roomId then
        return
    end

    local _, roomInfo = GameInstance.player.spaceship:TryGetRoom(self.m_roomId)
    self:_UpdatePersonnelNodeState(roomInfo)
    self:_UpdateLvInfo(roomInfo)
    self:_UpdateStationPersonnelInfo(roomInfo)
end

HL.Commit(SpaceshipRoomCommonInfo)
return SpaceshipRoomCommonInfo
