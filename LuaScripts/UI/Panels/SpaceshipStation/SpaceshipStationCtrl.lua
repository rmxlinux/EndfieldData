
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipStation
local PHASE_ID = PhaseId.SpaceshipStation
local ENTER_ANIMATION = "spaceshipstation_in"
local ENTER_FROM_SCHEDULE_ANIMATION = "spaceshipstation_in01"

SpaceshipStationCtrl = HL.Class('SpaceshipStationCtrl', uiCtrl.UICtrl)






SpaceshipStationCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SPACESHIP_ON_SET_ROOM_STATION_SUCC] = 'OnSetRoomStationSucc',
    [MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION] = '_OnSyncRoomStation',
    [MessageConst.ON_SPACESHIP_HEAD_NAVI_TARGET_CHANGE] = 'OnHeadCellNaviTargetChange',
    [MessageConst.SPACESHIP_ON_EDIT_SCHEDULE] = '_OnEditScheduleSucc',
}


SpaceshipStationCtrl.m_roomId = HL.Field(HL.String) << ''

SpaceshipStationCtrl.m_isControlCenter = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl.m_charEffectCells = HL.Field(HL.Forward('UIListCache'))

SpaceshipStationCtrl.m_getCharCell = HL.Field(HL.Function)

SpaceshipStationCtrl.m_maxStationCharNum = HL.Field(HL.Number) << -1

SpaceshipStationCtrl.m_maxLvStationCharNum = HL.Field(HL.Number) << -1

SpaceshipStationCtrl.m_isScrollInit = HL.Field(HL.Boolean) << true

SpaceshipStationCtrl.m_skillNodes = HL.Field(HL.Table)

SpaceshipStationCtrl.m_skillHintBindingId = HL.Field(HL.Number) << -1

SpaceshipStationCtrl.m_nowNaviHeadCell = HL.Field(HL.Userdata)

SpaceshipStationCtrl.m_isEditingSchedule = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl.m_curTeamType = HL.Field(HL.Any)

SpaceshipStationCtrl.m_editTeamType = HL.Field(HL.Any)

SpaceshipStationCtrl.m_chosenCharIdListA = HL.Field(HL.Table)

SpaceshipStationCtrl.m_chosenCharIdListB = HL.Field(HL.Table)

SpaceshipStationCtrl.m_supportsSchedule = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl.m_openScheduleAfterSetStation = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl.m_addTeamAfterSetRoomStation = HL.Field(HL.Any)

SpaceshipStationCtrl.m_openScheduleAfterModifyTeam = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl.m_waitingReturnToSchedule = HL.Field(HL.Boolean) << false


SpaceshipStationCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.confirmBtn.onClick:AddListener(function()
        self:_OnClickConfirm()
    end)
    self.view.resetBtn.onClick:AddListener(function()
        self:_OnClickReset()
    end)

    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "instru_spaceship_schedule")
    end)

    local roomId = arg.roomId
    self.m_roomId = roomId
    self.m_isControlCenter = roomId == Tables.spaceshipConst.controlCenterRoomId

    self:_InitFilter()
    self:_InitSort()

    self.m_getCharCell = UIUtils.genCachedCellFunction(self.view.charScrollList)
    self:BindInputPlayerAction("ss_char_detail", function()
        if self.m_nowNaviHeadCell then
            self.m_nowNaviHeadCell:ShowTips()
        end
    end)

    self.view.charScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCharCell(obj), LuaIndex(csIndex))
    end)
    self.view.charScrollList.getCellName = function(csIndex)
        local charInfo = self.m_curCharInfos[LuaIndex(csIndex)]
        return "Char-" .. charInfo.id
    end

    self.m_charEffectCells = UIUtils.genCellCache(self.view.charEffectCell)

    local spaceship = GameInstance.player.spaceship
    
    local room = spaceship.rooms:get_Item(roomId)
    self.m_maxStationCharNum = room.maxStationCharNum
    self.m_maxLvStationCharNum = room.maxLvStationCount

    self.view.topNodeLuaUIWidget:InitSpaceshipStationTopNode({
        roomId = roomId,
        onClose = function()
            self:_CloseSelf()
        end,
    })

    local roomType = SpaceshipUtils.getRoomTypeByRoomId(roomId)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]
    self.view.bigBgIcon:LoadSprite(UIConst.UI_SPRITE_SPACESHIP_ROOM, roomTypeData.bg .. "_shallow")
    local color = self.view.topNodeLuaUIWidget:GetRoomColor()
    self.view.colorDeco.color = color
    self.view.colorDeco.gameObject:SetActive(true)

    self.m_supportsSchedule = SpaceshipUtils.isRoomScheduleSupported(roomId)
    self:_InitScheduleState(arg.editTeamType)
    self:_UpdateBottomNodeState()

    self:_UpdateCharacters()
    self:_UpdateStationInfos()

    local recoverState = arg and arg.recoverState or nil
    if recoverState then
        self:_TryRecoverState(recoverState)
        arg.recoverState = nil
    end

    self.m_skillHintBindingId = self:BindInputPlayerAction("ss_station_char_skill_detail",function()
        if self.m_skillNodes then
            for i, v in pairs(self.m_skillNodes) do
                if v:GetCanLevelUpState() then
                    v:TriggerSkillHint()
                end
            end
        end
    end)
    self:_RefreshSkillHintBinding()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    local enterAnimation = arg.isFromSchedule and ENTER_FROM_SCHEDULE_ANIMATION or ENTER_ANIMATION
    self.animationWrapper:Play(enterAnimation, nil, CS.Beyond.UI.UIConst.AnimationState.In)
end

SpaceshipStationCtrl.OnHeadCellNaviTargetChange = HL.Method(HL.Opt(HL.Userdata)) << function(self, cell)
    self.m_nowNaviHeadCell = cell
    self:_OnCellSelectedChanged(cell.m_charId, cell.view.button)
end

SpaceshipStationCtrl._OnCellSelectedChanged = HL.Method(HL.String, HL.Any) << function(self, charId, target)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charId)
    if chosenIndex then
        InputManagerInst:SetBindingText(target.hoverConfirmBindingId, Language.key_hint_common_unselect)
    else
        InputManagerInst:SetBindingText(target.hoverConfirmBindingId, Language.key_hint_common_select)
    end
end



SpaceshipStationCtrl.m_filterTags = HL.Field(HL.Table)

local FilterType = {
    Skill = 1,
    WorkState = 2,
}

SpaceshipStationCtrl._InitFilter = HL.Method() << function(self)
    local inited = false
    local filterTagGroups = {
        { 
            title = Language.LUA_SPACESHIP_FILTER_TITLE_SKILL,
            tags = {},
        },
        { 
            title = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE,
            tags = {
                {
                    name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_NONE,
                    type = FilterType.WorkState,
                    isWorking = false,
                    isResting = false,
                },
                {
                    name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_RESTING,
                    type = FilterType.WorkState,
                    isWorking = false,
                    isResting = true,
                },
                {
                    name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_WORKING,
                    type = FilterType.WorkState,
                    isWorking = true,
                    isResting = false,
                },
            },
        },
    }
    for t, v in pairs(Tables.spaceshipRoomTypeTable) do
        local roomType = GEnums.SpaceshipRoomType.__CastFrom(t)
        if roomType == GEnums.SpaceshipRoomType.GuestRoom then
            goto continue
        end
        table.insert(filterTagGroups[1].tags, {
            name = v.name,
            type = FilterType.Skill,
            roomType = roomType,
            order = t,
        })
        ::continue::
    end
    table.sort(filterTagGroups[1].tags, Utils.genSortFunction({"order"}, true))
    self.m_filterTags = nil
    self.view.filterBtn:InitFilterBtn({
        tagGroups = filterTagGroups,
        onConfirm = function(tags)
            if not inited then
                return
            end
            self:_ApplyFilter(tags)
        end,
        getResultCount = function(tags)
            return self:_GetContentFilterResultCount(tags)
        end,
        sortNodeWidget = self.view.sortNode,
    })
    inited = true
end

SpaceshipStationCtrl._ApplyFilter = HL.Method(HL.Opt(HL.Table)) << function(self, tags)
    self.m_filterTags = tags
    self:_GenCurCharInfos()
    self:_UpdateCharacters(true)
end

SpaceshipStationCtrl._IsFilterValid = HL.Method(HL.Table, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, info, tags)
    tags = tags or self.m_filterTags
    if not tags then
        return true
    end
    local groups = {}
    for _, v in ipairs(tags) do
        local list = groups[v.type]
        if not list then
            list = {}
            groups[v.type] = list
        end
        table.insert(list, v)
    end
    for _, list in pairs(groups) do
        local isPass
        for _, v in ipairs(list) do
            if v.type == FilterType.Skill then
                if info.char:HasSkillForRoom(v.roomType) or lume.find(self.m_chosenCharIdList, info.char.id) then
                    isPass = true
                    break
                end
            elseif v.type == FilterType.WorkState then
                local isWorking = info.char.isWorking
                local isResting = not string.isEmpty(info.char.stationedRoomId) and not isWorking
                if v.isWorking == isWorking and v.isResting == isResting or lume.find(self.m_chosenCharIdList, info.char.id) then
                    isPass = true
                    break
                end
            end
        end
        if not isPass then
            return false
        end
    end
    return true
end

SpaceshipStationCtrl._GetContentFilterResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    local count = 0
    for _, v in ipairs(self.m_allCharInfos) do
        if self:_IsFilterValid(v, tags) then
            count = count + 1
        end
    end
    return count
end

SpaceshipStationCtrl._InitSort = HL.Method() << function(self)
    local sortOptions = {
        {
            name = Language.LUA_SPACESHIP_CHAR_SORT_DEFAULT,
            decKeys = { "chosenSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
            incKeys = { "reverseChosenSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
        },
        {
            name = Language.LUA_SPACESHIP_CHAR_SORT_STAMINA,
            decKeys = { "chosenSortId", "stamina", "isCurRoomSortId", "workingStateSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
            incKeys = { "reverseChosenSortId", "stamina", "isCurRoomSortId", "workingStateSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
        },
        {
            name = Language.LUA_SPACESHIP_CHAR_SORT_SKILL,
            decKeys = { "chosenSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "id" },
            incKeys = { "reverseChosenSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "id" },
        },
        {
            name = Language.LUA_SPACESHIP_CHAR_SORT_WORKING_STATE,
            decKeys = { "chosenSortId", "workingStateSortId", "stamina", "isCurRoomSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
            incKeys = { "reverseChosenSortId", "workingStateSortId", "stamina", "isCurRoomSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
        },
    }
    if self.m_isControlCenter then
        table.insert(sortOptions, {
            name = Language.LUA_SPACESHIP_CHAR_SORT_FRIENDSHIP,
            decKeys = { "chosenSortId", "friendship", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
            incKeys = { "reverseChosenSortId", "friendship", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" },
            showFriendship = true,
        })
    end
    self.view.sortNode:InitSortNode(sortOptions, function(data, isIncremental)
        self:_ApplySortOption(data, isIncremental, true)
    end, 0, nil, true, self.view.filterBtn)
end

SpaceshipStationCtrl._ApplySortOption = HL.Method(HL.Opt(HL.Table, HL.Boolean, HL.Boolean)) << function(self, sortData, isIncremental, needUpdateList)
    sortData = sortData or self.view.sortNode:GetCurSortData()
    if isIncremental == nil then
        isIncremental = self.view.sortNode.isIncremental
    end

    local spaceship = GameInstance.player.spaceship
    for _, info in ipairs(self.m_curCharInfos) do
        local chosenIndex = lume.find(self.m_chosenCharIdList, info.id)
        if chosenIndex then
            info.chosenSortId = math.maxinteger - chosenIndex
            info.reverseChosenSortId = -info.chosenSortId
        else
            info.chosenSortId = 0
            info.reverseChosenSortId = 0
        end
        info.friendship = info.char.friendship
        info.stamina = spaceship:GetCharCurStamina(info.id)
        info.isCurRoomSortId = info.char.stationedRoomId == self.m_roomId and 1 or 0
        if string.isEmpty(info.char.stationedRoomId) then
            info.workingStateSortId = 1
        else
            
            info.workingStateSortId = info.char.isWorking and -1 or 0
        end
    end

    local keys = isIncremental and sortData.incKeys or sortData.decKeys
    table.sort(self.m_curCharInfos, Utils.genSortFunction(keys, isIncremental))
    self.m_showFriendship = keys.showFriendship == true

    self.m_curCharInfoReverseMap = {}
    for k, v in ipairs(self.m_curCharInfos) do
        self.m_curCharInfoReverseMap[v.id] = k
    end

    if needUpdateList then
        self.m_isScrollInit = true
        self.view.charScrollList:UpdateCount(#self.m_curCharInfos)
    end
end







SpaceshipStationCtrl.m_allCharInfos = HL.Field(HL.Table)

SpaceshipStationCtrl.m_allCharInfoReverseMap = HL.Field(HL.Table)

SpaceshipStationCtrl.m_curCharInfos = HL.Field(HL.Table)

SpaceshipStationCtrl.m_curCharInfoReverseMap = HL.Field(HL.Table)

SpaceshipStationCtrl.m_chosenCharIdList = HL.Field(HL.Table)

SpaceshipStationCtrl._GenAllCharInfos = HL.Method() << function(self)
    self.m_allCharInfos = {}
    self.m_chosenCharIdList = {}
    self.m_allCharInfoReverseMap = {}
    local spaceship = GameInstance.player.spaceship
    
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local roomType = room.type
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if self.m_editTeamType == TeamType.A and self.m_isEditingSchedule then
        for _, id in pairs(self.m_chosenCharIdListA) do
            table.insert(self.m_chosenCharIdList, id)
        end
    elseif self.m_editTeamType == TeamType.B and self.m_isEditingSchedule then
        for _, id in pairs(self.m_chosenCharIdListB) do
            table.insert(self.m_chosenCharIdList, id)
        end
    else
        for _, id in pairs(room.stationedCharList) do
            table.insert(self.m_chosenCharIdList, id)
        end
    end
    local index = 1
    for id, char in pairs(spaceship.characters) do
        local info = {
            id = id,
            char = char,
            validSkillCount = 0,
            validSkillCountIgnoreUnlock = 0,
            maxSkillSortId = math.mininteger,
        }
        local haveData, charSkillData = Tables.spaceshipCharSkillTable:TryGetValue(id)
        if haveData then
            for _, v in pairs(charSkillData.skillList) do
                local skillId = v.skillId
                local skillData = Tables.spaceshipSkillTable[skillId]
                if skillData.roomType == roomType then
                    info.validSkillCountIgnoreUnlock = info.validSkillCountIgnoreUnlock + 1
                    if char.skills:ContainsValue(skillId) then
                        info.validSkillCount = info.validSkillCount + 1
                    end
                    if skillData.sortId > info.maxSkillSortId then
                        info.maxSkillSortId = skillData.sortId
                    end
                end
            end
        end
        self.m_allCharInfos[index] = info
        self.m_allCharInfoReverseMap[id] = index
        index = index + 1
    end
end

SpaceshipStationCtrl._GenCurCharInfos = HL.Method() << function(self)
    self.m_curCharInfos = {}
    for _, v in ipairs(self.m_allCharInfos) do
        if self:_IsFilterValid(v) then
            table.insert(self.m_curCharInfos, v)
        end
    end
    self:_ApplySortOption()
end






SpaceshipStationCtrl.m_showFriendship = HL.Field(HL.Boolean) << false

SpaceshipStationCtrl._UpdateCharacters = HL.Method(HL.Opt(HL.Boolean)) << function(self, notGen)
    if not notGen then
        self:_GenAllCharInfos()
        self:_GenCurCharInfos()
    end
    local count = #self.m_curCharInfos
    self.m_isScrollInit = true
    self.view.charScrollList:UpdateCount(count)
    self.view.charListEmptyNode.gameObject:SetActive(count == 0)
end

SpaceshipStationCtrl._OnUpdateCell = HL.Method(HL.Forward("SSCharHeadCell"), HL.Number) << function(self, cell, index)
    local contentScreenRect = UIUtils.getUIRectOfRectTransform(self.view.content.transform, self.uiCamera) 

    local charInfo = self.m_curCharInfos[index]
    cell:InitSSCharHeadCell({
        charId = charInfo.id,
        targetRoomId = self.m_roomId,
        onClick = function()
            self:_OnClickChar(index)
            self:_OnCellSelectedChanged(self.m_curCharInfos[index].id, cell.view.button)
        end,
        groupId = self.view.inputGroup.groupId,
        padding = {
            bottom = self.view.transform.rect.height - contentScreenRect.yMax,
            left = self.view.charListNode.rect.width + contentScreenRect.x * 2
        },
    })

    self:_UpdateCharCellChooseState(charInfo.id, cell)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charInfo.id)
    cell:SetChooseState(chosenIndex)
    local showFriendship = self.m_isControlCenter or self.m_showFriendship
    cell.view.friendshipNode.gameObject:SetActive(showFriendship)
    if index == 1 and self.m_isScrollInit then
        self:SetNaviTarget(cell.view.button)
        self.m_isScrollInit = false
        self:OnHeadCellNaviTargetChange(cell)
    end
end

SpaceshipStationCtrl._UpdateCharChooseState = HL.Method(HL.String) << function(self, charId)
    local index = self.m_curCharInfoReverseMap[charId]
    if not index then
        return
    end
    local cell = self.m_getCharCell(index)
    if cell then
        self:_UpdateCharCellChooseState(charId, cell)
    end
end

SpaceshipStationCtrl._UpdateCharCellChooseState = HL.Method(HL.String, HL.Forward("SSCharHeadCell")) << function(self, charId, cell)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charId)
    cell:SetChooseState(chosenIndex)
end

SpaceshipStationCtrl._OnClickChar = HL.Method(HL.Number) << function(self, index)
    local charInfo = self.m_curCharInfos[index]
    self:_ToggleChooseChar(charInfo.id)
end






SpaceshipStationCtrl._UpdateStationInfos = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local roomLvTable = SpaceshipUtils.getRoomLvTableByType(room.type)
    local roomTypeData = Tables.spaceshipRoomTypeTable[room.type]

    local attrs = SpaceshipUtils.preCalcRoomAttrs(self.m_roomId, self.m_chosenCharIdList)
    self.view.topNodeLuaUIWidget:UpdateRoomEffectInfo(attrs)

    local contentScreenRect = UIUtils.getUIRectOfRectTransform(self.view.content.transform, self.uiCamera) 
    local padding = {
        bottom = self.view.transform.rect.height - contentScreenRect.yMax,
        right = self.view.charEffectNode.rect.width - self.view.effectPadding.rect.width + contentScreenRect.x
    }
    self.m_skillNodes = {}
    self.m_charEffectCells:Refresh(self.m_maxLvStationCharNum, function(cell, index)
        local charId = self.m_chosenCharIdList[index]
        cell.gameObject.name = "Cell-" .. index
        cell.indexTxt.text = index

        local isEmpty = string.isEmpty(charId)
        local isLocked = index > self.m_maxStationCharNum
        if isEmpty then
            if isLocked then
                local needLv
                for k = room.lv + 1, room.maxLv do
                    local roomLvData = roomLvTable[k]
                    if roomLvData.stationMaxCount >= index then
                        needLv = k
                        break
                    end
                end
                cell.lockedTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_UNLOCK_STATION_HINT, roomTypeData.name, needLv)
                cell.simpleStateController:SetState("Locked")
            else
                cell.simpleStateController:SetState("Empty")
            end
        else
            cell.simpleStateController:SetState("Normal")
            cell.headCell:InitSSCharHeadCell({
                charId = charId,
                targetRoomId = self.m_roomId,
                onClick = function()
                    cell.headCell:ShowTips()
                end,
                padding = padding,
            })
            cell.headCell.view.friendshipNode.gameObject:SetActive(self.m_isControlCenter)
            cell.charSkillNode:InitSSCharSkillNode(charId, self.m_roomId, true)
            table.insert(self.m_skillNodes, cell.charSkillNode)
            cell.delBtn.onClick:RemoveAllListeners()
            cell.delBtn.onClick:AddListener(function()
                self:_ToggleChooseChar(charId)
            end)
            if not cell.warnCells then
                cell.warnCells = UIUtils.genCellCache(cell.skillEffectWarnCell)
            end
            local warnTextList = {}
            
            local char = spaceship.characters:get_Item(charId)
            if not string.isEmpty(char.stationedRoomId) and char.stationedRoomId ~= self.m_roomId then
                local _, stationedRoom = spaceship:TryGetRoom(char.stationedRoomId)
                local roomName = ""
                if stationedRoom then
                    roomName = SpaceshipUtils.getFormatCabinSerialNum(char.stationedRoomId, stationedRoom.serialNum)
                    local teamType = self:_GetScheduleTeamTypeByCharId(stationedRoom, charId)
                    if teamType ~= CS.Proto.SpaceshipCharTeamType.None and not SpaceshipUtils.isSingleTeamMode(char.stationedRoomId) then
                        roomName = SpaceshipUtils.getFormatScheduleRoomTeamName(roomName, teamType)
                    end
                else
                    local roomType = SpaceshipUtils.getRoomTypeByRoomId(char.stationedRoomId)
                    local data = Tables.spaceshipRoomTypeTable[roomType]
                    roomName = data.name
                end
                table.insert(warnTextList, {
                    state = "InOtherRoom",
                    text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_LEAVE_ROOM,
                    roomColor = SpaceshipUtils.getRoomColor(char.stationedRoomId),
                    roomName = roomName
                })
            end
            local info = self.m_allCharInfos[self.m_allCharInfoReverseMap[charId]]
            if info.validSkillCount == 0 then
                table.insert(warnTextList, {
                    state = "NoSkill",
                    text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_NO_SKILL,
                })
            end
            if not string.isEmpty(char.stationedRoomId) and not char.isWorking then
                table.insert(warnTextList, {
                    state = "IsResting",
                    text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_REST,
                })
            end
            cell.warnCells:Refresh(#warnTextList, function(warnCell, warnIndex)
                local warnInfo = warnTextList[warnIndex]
                warnCell.simpleStateController:SetState(warnInfo.state)
                warnCell.text.text = warnInfo.text
                if warnInfo.roomName then
                    warnCell.roomBG.gameObject:SetActive(true)
                    warnCell.roomBG.color = warnInfo.roomColor
                    warnCell.roomName.text = warnInfo.roomName
                else
                    warnCell.roomBG.gameObject:SetActive(false)
                end
            end)
        end
    end)

    local curCount = #self.m_chosenCharIdList
    self.view.stationCountDotNode:InitLvDotNode(curCount, self.m_maxStationCharNum)
    self.view.stationCountTxt.text = string.format(Language.LUA_SPACESHIP_STATION_CHAR_COUNT_FORMAT, curCount, self.m_maxStationCharNum)
    self:_RefreshSkillHintBinding()
end

SpaceshipStationCtrl._CanTriggerSkillHint = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_skillNodes then
        return false
    end
    for _, skillNode in ipairs(self.m_skillNodes) do
        if skillNode:GetCanLevelUpState() then
            return true
        end
    end
    return false
end

SpaceshipStationCtrl._RefreshSkillHintBinding = HL.Method() << function(self)
    if self.m_skillHintBindingId > 0 then
        InputManagerInst:ToggleBinding(self.m_skillHintBindingId, self:_CanTriggerSkillHint())
    end
end

SpaceshipStationCtrl._SyncChosenListToTeam = HL.Method() << function(self)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if self.m_editTeamType == TeamType.A then
        self.m_chosenCharIdListA = lume.clone(self.m_chosenCharIdList)
    elseif self.m_editTeamType == TeamType.B then
        self.m_chosenCharIdListB = lume.clone(self.m_chosenCharIdList)
    end
end


SpaceshipStationCtrl._ToggleChooseChar = HL.Method(HL.String) << function(self, charId)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charId)
    if chosenIndex then
        
        table.remove(self.m_chosenCharIdList, chosenIndex)
        self:_UpdateCharChooseState(charId)
        for _, v in ipairs(self.m_chosenCharIdList) do
            self:_UpdateCharChooseState(v)
        end
    else
        
        local curCount = #self.m_chosenCharIdList
        if curCount >= self.m_maxStationCharNum then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_STATION_CHAR_MAX)
            return
        end
        table.insert(self.m_chosenCharIdList, charId)
        self:_UpdateCharChooseState(charId)

        Utils.triggerVoice("sim_assign_work", charId)

    end
    self:_SyncChosenListToTeam()
    self:_UpdateStationInfos()
end

SpaceshipStationCtrl._OnClickReset = HL.Method() << function(self)
    local oldChars = self.m_chosenCharIdList
    self.m_chosenCharIdList = {}
    for _, v in ipairs(oldChars) do
        self:_UpdateCharChooseState(v)
    end
    self:_SyncChosenListToTeam()
    self:_UpdateStationInfos()
end

SpaceshipStationCtrl.OnSetRoomStationSucc = HL.Method(HL.Table) << function(self, _)
    if self.m_addTeamAfterSetRoomStation then
        local teamType = self.m_addTeamAfterSetRoomStation
        self.m_addTeamAfterSetRoomStation = nil
        self:_RequestAddTeam(teamType)
        return
    end
    self:_CloseSelf()
end

SpaceshipStationCtrl._TryRecoverState = HL.Method(HL.Table) << function(self, recoverState)
    local savedChosen = recoverState.chosenCharIdList
    if savedChosen then
        self.m_chosenCharIdList = {}
        for _, charId in ipairs(savedChosen) do
            if self.m_allCharInfoReverseMap[charId] then
                table.insert(self.m_chosenCharIdList, charId)
            end
        end
        self:_SyncChosenListToTeam()
    end

    local sortNode = self.view.sortNode
    local sortSelectedIndex = recoverState.sortSelectedIndex
    local sortIsIncremental = recoverState.sortIsIncremental
    if sortSelectedIndex and sortNode and sortNode.m_sortOptions and sortNode.view and sortNode.view.mobilePCNode and sortNode.view.mobilePCNode.dropDown then
        local optionCount = #sortNode.m_sortOptions
        if optionCount > 0 then
            sortSelectedIndex = math.max(1, math.min(sortSelectedIndex, optionCount))
            sortNode.isIncremental = sortIsIncremental == true
            sortNode:RefreshIncremental()
            sortNode.view.mobilePCNode.dropDown:SetSelected(CSIndex(sortSelectedIndex), true, false)
        end
    end

    local filterTags = recoverState.filterTags
    if filterTags and self.view.filterBtn.m_args and self.view.filterBtn.m_args.onConfirm then
        self.view.filterBtn.m_args.onConfirm(filterTags)
    else
        sortNode:OnSortChanged()
    end
    sortNode:UpdateDeviceState()

    self:_UpdateStationInfos()
end

SpaceshipStationCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = {
        roomId = self.m_roomId,
    }
    if self.m_isEditingSchedule then
        arg.editTeamType = self.m_editTeamType
    end
    local recoverState = {
        chosenCharIdList = lume.clone(self.m_chosenCharIdList),
        sortSelectedIndex = self.view.sortNode:GetCurSelectedIndex(),
        sortIsIncremental = self.view.sortNode.isIncremental,
    }
    if self.view.filterBtn.m_args then
        recoverState.filterTags = lume.deepCopy(self.view.filterBtn.m_args.selectedTags)
    end
    arg.recoverState = recoverState
    return arg
end

SpaceshipStationCtrl._OnClickConfirm = HL.Method() << function(self)
    if self.m_isEditingSchedule then
        self:_ConfirmWithScheduleCheck()
        return
    end
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(self.m_roomId)
    if self:_IsCharListSameAsServer(self.m_chosenCharIdList, room.stationedCharList) then
        PhaseManager:PopPhase(PhaseId.SpaceshipStation)
        return
    end
    if room.schedule then
        local TeamType = CS.Proto.SpaceshipCharTeamType
        local isEditA = self.m_editTeamType == TeamType.A
        local charListA = isEditA and lume.clone(self.m_chosenCharIdList) or lume.clone(self.m_chosenCharIdListA)
        local charListB = isEditA and lume.clone(self.m_chosenCharIdListB) or lume.clone(self.m_chosenCharIdList)
        self:_NormalizeScheduleCharLists(charListA, charListB, self.m_editTeamType)
        local confirm = function()
            spaceship:SetRoomStation(self.m_roomId, self.m_chosenCharIdList)
        end
        if self:_TryShowScheduleEdgeConfirm(charListA, charListB, confirm) then
            return
        end
        confirm()
        return
    end
    spaceship:SetRoomStation(self.m_roomId, self.m_chosenCharIdList)
end






SpaceshipStationCtrl._InitScheduleState = HL.Method(HL.Opt(HL.Any)) << function(self, editTeamType)
    local spaceship = GameInstance.player.spaceship
    local scheduleUnlocked = SpaceshipUtils.isScheduleUnlocked()
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local isEditingScheduleTeam = editTeamType and editTeamType ~= TeamType.None
    self.m_isEditingSchedule = isEditingScheduleTeam == true
    local showEditBtn = scheduleUnlocked and self.m_supportsSchedule and not self.m_isEditingSchedule
        and SpaceshipUtils.isSingleTeamMode(self.m_roomId)

    self.view.editScheduleBtn.gameObject:SetActive(showEditBtn)
    self.view.helpBtn.gameObject:SetActive(scheduleUnlocked and self.m_supportsSchedule)
    if showEditBtn then
        self.view.editScheduleBtn.button.onClick:RemoveAllListeners()
        self.view.editScheduleBtn.button.onClick:AddListener(function()
            self:_OnClickEditSchedule()
        end)
    end

    local curTeam = spaceship:GetRoomCurrentWorkingTeam(self.m_roomId)
    self.m_curTeamType = curTeam


    self.m_editTeamType = isEditingScheduleTeam and editTeamType
        or (self.m_curTeamType ~= TeamType.None and self.m_curTeamType or TeamType.A)

    self.m_chosenCharIdListA = {}
    self.m_chosenCharIdListB = {}

    local _, room = spaceship:TryGetRoom(self.m_roomId)
    local schedule = room.schedule
    if schedule then
        for _, id in pairs(schedule.StationedCharListA) do
            table.insert(self.m_chosenCharIdListA, id)
        end
        for _, id in pairs(schedule.StationedCharListB) do
            table.insert(self.m_chosenCharIdListB, id)
        end
    end
    if not isEditingScheduleTeam and SpaceshipUtils.isSingleTeamMode(self.m_roomId)
        and SpaceshipUtils.isScheduleListEmpty(self.m_chosenCharIdListA)
        and SpaceshipUtils.isScheduleListEmpty(self.m_chosenCharIdListB) then
        self.m_editTeamType = TeamType.A
    end
end

SpaceshipStationCtrl._UpdateBottomNodeState = HL.Method() << function(self)
    if not self.m_isEditingSchedule then
        self.view.bottomNode:SetState("Single")
        self.view.bottomNode:SetState("Black")
        return
    end
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if self.m_editTeamType == TeamType.A then
        self.view.bottomNode:SetState("A")
        self.view.bottomNode:SetState("Color")
        local color = self.view.topNodeLuaUIWidget:GetRoomColor()
        self.view.bgImg.color = color
        self.view.canvasGroup.color = color
        self.view.colorVx = color
    elseif self.m_editTeamType == TeamType.B then
        self.view.bottomNode:SetState("B")
        self.view.bottomNode:SetState("Grey")
    else
        logger.error("_UpdateBottomNodeState:未知的状态", self.m_editTeamType )
    end
end

SpaceshipStationCtrl._IsCharListSameAsServer = HL.Method(HL.Table, HL.Any).Return(HL.Boolean) << function(self, newList, serverList)
    return SpaceshipUtils.isCharListSameAsServer(newList, serverList)
end

SpaceshipStationCtrl._OnClickEditSchedule = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local TeamType = CS.Proto.SpaceshipCharTeamType

    local isEditA = self.m_editTeamType == TeamType.A
    local charListA = isEditA and lume.clone(self.m_chosenCharIdList) or lume.clone(self.m_chosenCharIdListA)
    local charListB = isEditA and lume.clone(self.m_chosenCharIdListB) or lume.clone(self.m_chosenCharIdList)
    self:_NormalizeScheduleCharLists(charListA, charListB, self.m_editTeamType)

    local serverScheduleList = room.schedule and (isEditA and room.schedule.StationedCharListA or room.schedule.StationedCharListB)
    if self:_IsCharListSameAsServer(self.m_chosenCharIdList, serverScheduleList) then
        self:_RequestAddTeam(self:_GetTeamTypeToAdd())
        return
    end

    local confirm = function()
        self.m_addTeamAfterSetRoomStation = self:_GetTeamTypeToAdd()
        spaceship:SetRoomStation(self.m_roomId, self.m_chosenCharIdList)
    end
    if self:_TryShowScheduleEdgeConfirm(charListA, charListB, confirm) then
        return
    end
    confirm()
end

SpaceshipStationCtrl._GetTeamTypeToAdd = HL.Method().Return(HL.Any) << function(self)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local _, room = GameInstance.player.spaceship:TryGetRoom(self.m_roomId)
    local schedule = room and room.schedule
    if schedule then
        local isTeamAEmpty = SpaceshipUtils.isScheduleListEmpty(schedule.StationedCharListA)
        local isTeamBEmpty = SpaceshipUtils.isScheduleListEmpty(schedule.StationedCharListB)
        if not isTeamAEmpty and isTeamBEmpty then
            return TeamType.B
        elseif isTeamAEmpty and not isTeamBEmpty then
            return TeamType.A
        end
    end
    return self.m_editTeamType == TeamType.B and TeamType.A or TeamType.B
end

SpaceshipStationCtrl._RequestAddTeam = HL.Method(HL.Any) << function(self, teamType)
    self.m_openScheduleAfterModifyTeam = true
    GameInstance.player.spaceship:ModifyTeam(self.m_roomId, teamType, true)
end

SpaceshipStationCtrl._OnSyncRoomStation = HL.Method(HL.Opt(HL.Table)) << function(self, _)
    if not self.m_openScheduleAfterModifyTeam or SpaceshipUtils.isSingleTeamMode(self.m_roomId) then
        return
    end
    self.m_openScheduleAfterModifyTeam = false
    self:_ReturnToSchedule()
end

SpaceshipStationCtrl._ConfirmWithScheduleCheck = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local TeamType = CS.Proto.SpaceshipCharTeamType

    local isEditA = self.m_editTeamType == TeamType.A
    local charListA = isEditA and lume.clone(self.m_chosenCharIdList) or lume.clone(self.m_chosenCharIdListA)
    local charListB = isEditA and lume.clone(self.m_chosenCharIdListB) or lume.clone(self.m_chosenCharIdList)
    self:_NormalizeScheduleCharLists(charListA, charListB, self.m_editTeamType)

    local setA = true
    local setB = true

    local room = spaceship.rooms:get_Item(self.m_roomId)
    local serverScheduleList = isEditA and room.schedule.StationedCharListA or room.schedule.StationedCharListB
    local notChanged = self:_IsCharListSameAsServer(self.m_chosenCharIdList, serverScheduleList)
    if notChanged then
        self:_CloseSelf()
        return
    end

    local confirm = function()
        self.m_openScheduleAfterSetStation = true
        spaceship:SetStationChar(self.m_roomId, charListA, charListB, setA, setB)
    end
    if self:_TryShowScheduleEdgeConfirm(charListA, charListB, confirm) then
        return
    end
    confirm()
end

SpaceshipStationCtrl._TryShowScheduleEdgeConfirm = HL.Method(HL.Table, HL.Table, HL.Function).Return(HL.Boolean) << function(self, charListA, charListB, onConfirm)
    local warningInfo = self:_GetScheduleEdgeWarningInfo(charListA, charListB)
    if not warningInfo then
        return false
    end

    local content = string.format(Language.LUA_SPACESHIP_SCHEDULE_TRANSFER_ROOMS_CONFIRM, warningInfo.roomNames)
    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        warningContent = warningInfo.warningContent,
        onConfirm = onConfirm,
    })
    return true
end

SpaceshipStationCtrl._NormalizeScheduleCharLists = HL.Method(HL.Table, HL.Table, HL.Any) << function(self, charListA, charListB, editTeamType)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if editTeamType == TeamType.A then
        for _, charId in ipairs(charListA) do
            self:_RemoveIdFromList(charListB, charId)
        end
    elseif editTeamType == TeamType.B then
        for _, charId in ipairs(charListB) do
            self:_RemoveIdFromList(charListA, charId)
        end
    end
end

SpaceshipStationCtrl._GetScheduleEdgeWarningInfo = HL.Method(HL.Table, HL.Table).Return(HL.Any) << function(self, charListA, charListB)
    local spaceship = GameInstance.player.spaceship
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local selectedIds = self:_GenIdSetFromLists(charListA, charListB)
    local warningInfo
    local affectedMap = {}
    local externalRoomLists = {}
    local hasExternalSelectedChar = false

    for charId, _ in pairs(selectedIds) do
        local charInfo = self.m_allCharInfos[self.m_allCharInfoReverseMap[charId]]
        local char = charInfo and charInfo.char
        if char and not string.isEmpty(char.stationedRoomId) and char.stationedRoomId ~= self.m_roomId then
            hasExternalSelectedChar = true
            break
        end
    end

    local _, curRoom = spaceship:TryGetRoom(self.m_roomId)
    if curRoom and curRoom.schedule then
        local editTeamType = self.m_editTeamType
        local changedA = not self:_IsCharListSameAsServer(charListA, curRoom.schedule.StationedCharListA)
        local changedB = not self:_IsCharListSameAsServer(charListB, curRoom.schedule.StationedCharListB)
        local removedA = self:_HasRemovedScheduleChar(charListA, curRoom.schedule.StationedCharListA)
        local removedB = self:_HasRemovedScheduleChar(charListB, curRoom.schedule.StationedCharListB)
        if changedA or changedB then
            if curRoom.schedule.AutoSchedule and ((removedA and #charListA == 0) or (removedB and #charListB == 0)) then
                local emptyTeamType = removedA and #charListA == 0 and TeamType.A or TeamType.B
                warningInfo = {
                    priority = 1,
                    roomId = self.m_roomId,
                    roomName = SpaceshipUtils.getFormatCabinSerialNum(self.m_roomId, curRoom.serialNum),
                    teamLabel = self:_GetScheduleTeamLabel(emptyTeamType),
                    warningContent = Language.LUA_SPACESHIP_SCHEDULE_EXIT_AUTO_WARNING,
                }
            end
            if removedA then
                local onlyChangedEditingTeam = not hasExternalSelectedChar and editTeamType == TeamType.A and not changedB
                local key = self.m_roomId .. "_" .. tostring(TeamType.A)
                affectedMap[key] = {
                    roomId = self.m_roomId,
                    teamType = TeamType.A,
                    charListA = charListA,
                    charListB = charListB,
                    ignoreWorkingTeamSwitch = onlyChangedEditingTeam,
                }
            end
            if removedB then
                local onlyChangedEditingTeam = not hasExternalSelectedChar and editTeamType == TeamType.B and not changedA
                local key = self.m_roomId .. "_" .. tostring(TeamType.B)
                affectedMap[key] = {
                    roomId = self.m_roomId,
                    teamType = TeamType.B,
                    charListA = charListA,
                    charListB = charListB,
                    ignoreWorkingTeamSwitch = onlyChangedEditingTeam,
                }
            end
        end
    end

    for charId, _ in pairs(selectedIds) do
        local charInfo = self.m_allCharInfos[self.m_allCharInfoReverseMap[charId]]
        local char = charInfo and charInfo.char
        if char and not string.isEmpty(char.stationedRoomId) then
            local _, room = spaceship:TryGetRoom(char.stationedRoomId)
            local originTeamType = self:_GetScheduleTeamTypeByCharId(room, charId)
            if originTeamType ~= TeamType.None then
                local staysInOriginalTeam = char.stationedRoomId == self.m_roomId
                        and ((originTeamType == TeamType.A and selectedIds[charId] and lume.find(charListA, charId))
                        or (originTeamType == TeamType.B and selectedIds[charId] and lume.find(charListB, charId)))
                if not staysInOriginalTeam and room and room.schedule then
                    local key = char.stationedRoomId .. "_" .. tostring(originTeamType)
                    local info = affectedMap[key]
                    if not info then
                        if char.stationedRoomId == self.m_roomId then
                            info = {
                                roomId = char.stationedRoomId,
                                teamType = originTeamType,
                                charListA = charListA,
                                charListB = charListB,
                            }
                        else
                            local lists = externalRoomLists[char.stationedRoomId]
                            if not lists then
                                lists = {
                                    a = self:_CloneScheduleList(room.schedule.StationedCharListA),
                                    b = self:_CloneScheduleList(room.schedule.StationedCharListB),
                                }
                                externalRoomLists[char.stationedRoomId] = lists
                            end
                            info = {
                                roomId = char.stationedRoomId,
                                teamType = originTeamType,
                                charListA = lists.a,
                                charListB = lists.b,
                            }
                        end
                        affectedMap[key] = info
                    end
                    if char.stationedRoomId ~= self.m_roomId then
                        self:_RemoveIdFromList(info.charListA, charId)
                        self:_RemoveIdFromList(info.charListB, charId)
                    end
                end
            end
        end
    end

    local roomGroups = {}
    for _, info in pairs(affectedMap) do
        local _, room = spaceship:TryGetRoom(info.roomId)
        local candidate = self:_BuildScheduleEdgeWarningInfo(room, info.roomId, info.teamType, info.charListA, info.charListB, info.ignoreWorkingTeamSwitch == true)
        if candidate or info.roomId ~= self.m_roomId then
            local group = roomGroups[info.roomId]
            if not group then
                group = { name = SpaceshipUtils.getFormatCabinSerialNum(info.roomId, room.serialNum), teams = {} }
                roomGroups[info.roomId] = group
            end
            group.teams[self:_GetScheduleTeamLabel(info.teamType)] = true
            if candidate and (not warningInfo or candidate.priority < warningInfo.priority) then
                warningInfo = candidate
            end
        end
    end
    local roomIds = {}
    for roomId in pairs(roomGroups) do
        table.insert(roomIds, roomId)
    end
    table.sort(roomIds)
    if #roomIds == 0 then
        return nil
    end
    local names = {}
    for _, roomId in ipairs(roomIds) do
        local group = roomGroups[roomId]
        local name = group.name
        if not SpaceshipUtils.isSingleTeamMode(roomId) then
            local labels = {}
            if group.teams.A then
                table.insert(labels, Language.LUA_SPACESHIP_SCHEDULE_TEAM_A)
            end
            if group.teams.B then
                table.insert(labels, Language.LUA_SPACESHIP_SCHEDULE_TEAM_B)
            end
            name = string.format(Language.LUA_SPACESHIP_SCHEDULE_ROOM_TEAMS_FORMAT, name, table.concat(labels, Language.LUA_SPACESHIP_SCHEDULE_TEAM_SEPARATOR))
        end
        table.insert(names, string.format(Language.LUA_SPACESHIP_SCHEDULE_SOURCE_ROOM_FORMAT, name))
    end
    return {
        roomNames = table.concat(names, " "),
        warningContent = warningInfo and warningInfo.warningContent or nil,
    }
end

SpaceshipStationCtrl._GetScheduleTeamTypeByCharId = HL.Method(HL.Any, HL.String).Return(HL.Any) << function(self, room, charId)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if not room or not room.schedule then
        return TeamType.None
    end
    for _, id in pairs(room.schedule.StationedCharListA) do
        if id == charId then
            return TeamType.A
        end
    end
    for _, id in pairs(room.schedule.StationedCharListB) do
        if id == charId then
            return TeamType.B
        end
    end
    return TeamType.None
end

SpaceshipStationCtrl._BuildScheduleEdgeWarningInfo = HL.Method(HL.Any, HL.String, HL.Any, HL.Table, HL.Table, HL.Boolean).Return(HL.Any) << function(self, room, roomId, teamType, charListA, charListB, ignoreWorkingTeamSwitch)
    if not room or not room.schedule then
        return nil
    end
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local emptyA = #charListA == 0
    local emptyB = #charListB == 0
    local isAutoSchedule = room.schedule.AutoSchedule
    local curTeam = GameInstance.player.spaceship:GetRoomCurrentWorkingTeam(roomId)
    local curTeamEmpty = (curTeam == TeamType.A and emptyA) or (curTeam == TeamType.B and emptyB)
    local otherTeamHasChar = (curTeam == TeamType.A and not emptyB) or (curTeam == TeamType.B and not emptyA)

    local warningContent
    local priority
    if isAutoSchedule and (emptyA or emptyB) then
        priority = 1
        warningContent = Language.LUA_SPACESHIP_SCHEDULE_EXIT_AUTO_WARNING
    elseif not ignoreWorkingTeamSwitch and curTeamEmpty and otherTeamHasChar then
        priority = 2
        warningContent = Language.LUA_SPACESHIP_SCHEDULE_SWITCH_WORKING_TEAM_WARNING
    elseif not ignoreWorkingTeamSwitch and isAutoSchedule and not emptyA and not emptyB and self:_HasScheduleWorkTimeNotEnough(room, charListA, charListB) then
        priority = 3
        warningContent = Language.LUA_SPACESHIP_SCHEDULE_CHANGE_TEAM_WORK_TIME_NOT_ENOUGH_WARNING
    end
    if not warningContent then
        return nil
    end

    return {
        priority = priority,
        roomId = roomId,
        roomName = SpaceshipUtils.getFormatCabinSerialNum(roomId, room.serialNum),
        teamLabel = self:_GetScheduleTeamLabel(teamType),
        warningContent = warningContent,
    }
end

SpaceshipStationCtrl._HasScheduleWorkTimeNotEnough = HL.Method(HL.Any, HL.Table, HL.Table).Return(HL.Boolean) << function(self, room, charListA, charListB)
    local schedule = room.schedule
    if not schedule or not schedule.AutoSchedule then
        return false
    end
    local daySeconds = 24 * 60 * 60
    local startTs = schedule.StartTsOffset
    local endTs = schedule.EndTsOffset
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local appliesTeamType = TeamType.__CastFrom(schedule.AppliesTeamType)
    if appliesTeamType == TeamType.None then
        appliesTeamType = TeamType.A
    end
    if startTs == endTs then
        startTs = 0
        endTs = 12 * 60 * 60
        appliesTeamType = TeamType.A
    end
    local duration = endTs - startTs
    if duration <= 0 then
        duration = duration + daySeconds
    end
    local durationA = appliesTeamType == TeamType.A and duration or daySeconds - duration
    local durationB = appliesTeamType == TeamType.B and duration or daySeconds - duration
    return self:_IsTeamWorkTimeNotEnough(room, charListA, durationA, self:_CloneScheduleList(schedule.StationedCharListA))
            or self:_IsTeamWorkTimeNotEnough(room, charListB, durationB, self:_CloneScheduleList(schedule.StationedCharListB))
end

SpaceshipStationCtrl._IsTeamWorkTimeNotEnough = HL.Method(HL.Any, HL.Table, HL.Number, HL.Table).Return(HL.Boolean) << function(self, room, charList, duration, originalCharList)
    if duration <= 0 then
        return false
    end
    local estimatedWorkSeconds = SpaceshipUtils.getScheduleTeamEstimatedWorkSeconds(room, charList)
    if estimatedWorkSeconds <= 0 or duration <= estimatedWorkSeconds then
        return false
    end
    local originalWorkSeconds = SpaceshipUtils.getScheduleTeamEstimatedWorkSeconds(room, originalCharList)
    
    
    return originalWorkSeconds <= 0 or estimatedWorkSeconds < originalWorkSeconds
end

SpaceshipStationCtrl._GenIdSetFromLists = HL.Method(HL.Table, HL.Table).Return(HL.Table) << function(self, charListA, charListB)
    local idSet = {}
    for _, charId in ipairs(charListA) do
        idSet[charId] = true
    end
    for _, charId in ipairs(charListB) do
        idSet[charId] = true
    end
    return idSet
end

SpaceshipStationCtrl._HasRemovedScheduleChar = HL.Method(HL.Table, HL.Any).Return(HL.Boolean) << function(self, newList, serverList)
    for _, charId in pairs(serverList) do
        if not lume.find(newList, charId) then
            return true
        end
    end
    return false
end

SpaceshipStationCtrl._CloneScheduleList = HL.Method(HL.Any).Return(HL.Table) << function(self, sourceList)
    return SpaceshipUtils.cloneScheduleList(sourceList)
end

SpaceshipStationCtrl._RemoveIdFromList = HL.Method(HL.Table, HL.String) << function(self, list, charId)
    local index = lume.find(list, charId)
    if index then
        table.remove(list, index)
    end
end

SpaceshipStationCtrl._GetScheduleTeamLabel = HL.Method(HL.Any).Return(HL.String) << function(self, teamType)
    return SpaceshipUtils.getScheduleTeamText(teamType)
end

SpaceshipStationCtrl._OnEditScheduleSucc = HL.Method(HL.Any) << function(self, arg)
    local roomId = type(arg) == "table" and arg[1] or arg
    if roomId ~= self.m_roomId then
        return
    end
    if self.m_openScheduleAfterSetStation then
        self.m_openScheduleAfterSetStation = false
        self:_ReturnToSchedule()
        return
    end
    local spaceship = GameInstance.player.spaceship
    local curTeam = spaceship:GetRoomCurrentWorkingTeam(self.m_roomId)
    self.m_curTeamType = curTeam
    self:_UpdateBottomNodeState()
    self:_UpdateStationInfos()
end

SpaceshipStationCtrl._CloseSelf = HL.Method() << function(self)
    if self.m_isEditingSchedule then
        self:_ReturnToSchedule()
        return
    end
    PhaseManager:PopPhase(PHASE_ID)
end

SpaceshipStationCtrl._ReturnToSchedule = HL.Method() << function(self)
    if self.m_waitingReturnToSchedule then
        return
    end
    if PhaseManager:CheckIsInTransition() then
        self.m_waitingReturnToSchedule = true
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self.m_isClosed
                    or PhaseManager:GetTopPhaseId() ~= PHASE_ID
                    or not PhaseManager:CheckIsInTransition()
            end)
            self.m_waitingReturnToSchedule = false
            if self.m_isClosed or PhaseManager:GetTopPhaseId() ~= PHASE_ID then
                return
            end
            self:_ReturnToSchedule()
        end)
        return
    end

    self.m_waitingReturnToSchedule = true
    if self.m_isEditingSchedule then
        if not PhaseManager:PopPhase(PHASE_ID) then
            self.m_waitingReturnToSchedule = false
        end
        return
    end
    self:_ExitToSchedule()
end

SpaceshipStationCtrl._ExitToSchedule = HL.Method() << function(self)
    if self.m_isClosed or PhaseManager:GetTopPhaseId() ~= PHASE_ID then
        self.m_waitingReturnToSchedule = false
        return
    end
    if PhaseManager:CheckIsInTransition() then
        self:_StartCoroutine(function()
            coroutine.waitCondition(function()
                return self.m_isClosed
                    or PhaseManager:GetTopPhaseId() ~= PHASE_ID
                    or not PhaseManager:CheckIsInTransition()
            end)
            self:_ExitToSchedule()
        end)
        return
    end

    local roomId = self.m_roomId
    if PhaseManager:ExitPhaseFast(PHASE_ID) then
        PhaseManager:GoToPhase(PhaseId.SpaceshipSchedule, {roomId = roomId, isFromStation = true})
    else
        self.m_waitingReturnToSchedule = false
    end
end




HL.Commit(SpaceshipStationCtrl)
