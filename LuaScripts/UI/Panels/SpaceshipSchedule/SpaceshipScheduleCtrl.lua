local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipSchedule
local PHASE_ID = PhaseId.SpaceshipSchedule
local TEAM_TYPE_NONE = 0
local TEAM_TYPE_A = 1
local TEAM_TYPE_B = 2
local WORK_HOUR_ALLOCATION_SLIDER_MAX = 24 * 60
local WORK_HOUR_ALLOCATION_STEP_MINUTES = 60
local WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES = WORK_HOUR_ALLOCATION_STEP_MINUTES
local WORK_HOUR_ALLOCATION_MAX_DURATION_MINUTES = WORK_HOUR_ALLOCATION_SLIDER_MAX - WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES
local WORK_HOUR_ALLOCATION_STICK_DEAD_ZONE = 0.2
local WORK_HOUR_ALLOCATION_STICK_REPEAT_DELAYS = {
    0.5,
    0.2,
    0.2,
    0.13,
}
local WORK_HOUR_ALLOCATION_STICK_OWNER_NONE = 0
local WORK_HOUR_ALLOCATION_STICK_OWNER_A = 1
local WORK_HOUR_ALLOCATION_STICK_OWNER_B = 2
local SHIFT_SCHEDULE_ACTION_START = "start"
local SHIFT_SCHEDULE_ACTION_STOP = "stop"

local START_TEAM_CD_ERROR_CODE = 6
local ENTER_ANIMATION = "spaceshipschedule_newin"
local ENTER_FROM_STATION_ANIMATION = "spaceshipschedule_newin02"
local GROUP_A_LOOP_ANIMATION = "spaceshipschedulestate_loop"
local GROUP_B_LOOP_ANIMATION = "spaceshipschedulestate_bloop"
SpaceshipScheduleCtrl = HL.Class('SpaceshipScheduleCtrl', uiCtrl.UICtrl)







SpaceshipScheduleCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SPACESHIP_ON_SET_ROOM_STATION_SUCC] = '_OnSetRoomStationSucc',
    [MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION] = '_OnSyncRoomStation',
    [MessageConst.SPACESHIP_ON_EDIT_SCHEDULE] = '_OnEditSchedule',
}

SpaceshipScheduleCtrl.m_roomId = HL.Field(HL.String) << ''

SpaceshipScheduleCtrl.m_spaceship = HL.Field(HL.Any)

SpaceshipScheduleCtrl.m_charEffectCellsA = HL.Field(HL.Forward('UIListCache'))

SpaceshipScheduleCtrl.m_charEffectCellsB = HL.Field(HL.Forward('UIListCache'))

SpaceshipScheduleCtrl.m_charEffectNodeB = HL.Field(HL.Any)

SpaceshipScheduleCtrl.m_skillNodesByTeamType = HL.Field(HL.Table)

SpaceshipScheduleCtrl.m_skillHintBindingId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_focusedCharEffectTeamType = HL.Field(HL.Any)

SpaceshipScheduleCtrl.m_lastFocusedCharEffectTeamType = HL.Field(HL.Any)

SpaceshipScheduleCtrl.m_autoReminderTimerId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_timeNowRefreshTimerId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_isEditingWorkHourAllocation = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_isUpdatingWorkHourAllocation = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_initialEditingStartTsOffset = HL.Field(HL.Number) << 0

SpaceshipScheduleCtrl.m_initialEditingEndTsOffset = HL.Field(HL.Number) << 0

SpaceshipScheduleCtrl.m_hasEditedWorkHourAllocation = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_showEditingTimeReminder = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_hasShownMinWorkHourToast = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_isWorkHourAllocationVisualReversed = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_initialWorkHourAllocationVisualReversed = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_selectedWorkHourAllocationSlider = HL.Field(HL.Number) << 0

SpaceshipScheduleCtrl.m_workHourAllocationStickOwner = HL.Field(HL.Number) << WORK_HOUR_ALLOCATION_STICK_OWNER_NONE

SpaceshipScheduleCtrl.m_workHourAllocationStickNextStepTime = HL.Field(HL.Number) << 0

SpaceshipScheduleCtrl.m_workHourAllocationStickNextStepDelayIndex = HL.Field(HL.Number) << 1

SpaceshipScheduleCtrl.m_workHourAllocationStickReleaseUpdateId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_workHourAllocationStepReleaseUpdateId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_workHourAllocationInputGroupId = HL.Field(HL.Number) << -1

SpaceshipScheduleCtrl.m_isDisablingInvalidAutoSchedule = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_reopenStationAfterModifyTeam = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_manualSwitchAnimationTeamType = HL.Field(HL.Any)

SpaceshipScheduleCtrl.m_nextStartTeamTime = HL.Field(HL.Number) << 0

SpaceshipScheduleCtrl.m_hasShownSchedulePanel = HL.Field(HL.Boolean) << false

SpaceshipScheduleCtrl.m_timeReminderShouldShowByTeamType = HL.Field(HL.Table)

SpaceshipScheduleCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = {
        roomId = self.m_roomId,
        lastFocusedCharEffectTeamType = self.m_lastFocusedCharEffectTeamType,
    }
    if not self.m_isEditingWorkHourAllocation then
        return arg
    end

    local startTsOffset, endTsOffset = self:_GetEditingTeamATimeRange()
    arg.isEditingWorkHourAllocation = true
    arg.editingStartTsOffset = startTsOffset
    arg.editingEndTsOffset = endTsOffset
    arg.initialEditingStartTsOffset = self.m_initialEditingStartTsOffset
    arg.initialEditingEndTsOffset = self.m_initialEditingEndTsOffset
    arg.isWorkHourAllocationVisualReversed = self.m_isWorkHourAllocationVisualReversed
    arg.initialWorkHourAllocationVisualReversed = self.m_initialWorkHourAllocationVisualReversed
    arg.selectedWorkHourAllocationSlider = self.m_selectedWorkHourAllocationSlider
    return arg
end


SpaceshipScheduleCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local roomId = arg.roomId
    self.m_roomId = roomId
    self.m_spaceship = GameInstance.player.spaceship
    self.m_manualSwitchAnimationTeamType = nil
    self.m_lastFocusedCharEffectTeamType = arg.lastFocusedCharEffectTeamType
    self.m_nextStartTeamTime = 0
    self.m_hasShownSchedulePanel = false
    self.m_timeReminderShouldShowByTeamType = {}

    self.view.topNodeLuaUIWidget:InitSpaceshipStationTopNode({
        roomId = roomId,
        onClose = function()
            self:_OnClickReturn()
        end
    })
    self.view.returnBtn.onClick:AddListener(function()
        self:_OnClickReturn()
    end)

    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "instru_spaceship_schedule")
    end)

    local TeamType = CS.Proto.SpaceshipCharTeamType
    self.m_charEffectNodeB = self:_CreateCharEffectNodeB()
    self.m_charEffectCellsA = UIUtils.genCellCache(self.view.charEffectNode1.charEffectCell)
    self.m_charEffectCellsB = UIUtils.genCellCache(self.m_charEffectNodeB.charEffectCell)
    self.m_skillNodesByTeamType = {}
    self:_BindCharEffectNodeNaviTargetChanged(self.view.charEffectNode1, TeamType.A)
    self:_BindCharEffectNodeNaviTargetChanged(self.m_charEffectNodeB, TeamType.B)
    self:_InitWorkHourAllocationInput()

    self.view.charEffectNode1.btnEdit.functionBtn.onClick:AddListener(function()
        self:_OpenStationForEditTeam(TeamType.A)
    end)
    self.m_charEffectNodeB.btnEdit.functionBtn.onClick:AddListener(function()
        self:_OpenStationForEditTeam(TeamType.B)
    end)

    self.view.charEffectNode1.btnDel.onClick:AddListener(function()
        self:_OnClickDeleteTeam(TeamType.A)
    end)
    self.m_charEffectNodeB.btnDel.onClick:AddListener(function()
        self:_OnClickDeleteTeam(TeamType.B)
    end)

    self.view.btnAuto.button.onClick:AddListener(function()
        self:_OnClickAutoBtn()
    end)
    self.view.btnAuto.button.onHoverChange:AddListener(function(isHover)
        local room = self:_GetRoom()
        if isHover and self:_CanEnableAutoSchedule(room) then
            AudioAdapter.PostEvent("Au_UI_Hover_Common")
        end
    end)
    self.view.autoNode.resetBtn.onClick:AddListener(function()
        self:_EnterWorkHourAllocation(false)
    end)
    self.view.autoNode.btnPauseAuto.onClick:AddListener(function()
        self:_OnClickPauseAuto()
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderA.slider.onValueChanged:AddListener(function(_)
        self:_OnWorkHourAllocationSliderChanged(true)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderB.slider.onValueChanged:AddListener(function(_)
        self:_OnWorkHourAllocationSliderChanged(false)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderA.slider.onClickSlider:AddListener(function(_)
        self:_SetWorkHourAllocationSliderSelected(true)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderB.slider.onClickSlider:AddListener(function(_)
        self:_SetWorkHourAllocationSliderSelected(false)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderA.slider.onClickSliderHandle:AddListener(function(_)
        self:_SetWorkHourAllocationSliderSelected(true)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderB.slider.onClickSliderHandle:AddListener(function(_)
        self:_SetWorkHourAllocationSliderSelected(false)
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderA.slider.onEndDragSlider:AddListener(function(_)
        self:_OnWorkHourAllocationInputReleased()
    end)
    self.view.workHourAllocation.spaceshipScheduleSliderB.slider.onEndDragSlider:AddListener(function(_)
        self:_OnWorkHourAllocationInputReleased()
    end)
    self:_BindWorkHourAllocationSliderPointerUp(self.view.workHourAllocation.spaceshipScheduleSliderA.eventTrigger)
    self:_BindWorkHourAllocationSliderPointerUp(self.view.workHourAllocation.spaceshipScheduleSliderB.eventTrigger)
    self.view.workHourAllocation.btnRevert.onClick:AddListener(function()
        self:_OnClickWorkHourAllocationRevert()
    end)
    self.view.workHourAllocation.btnReverse.onClick:AddListener(function()
        self:_OnClickWorkHourAllocationReverse()
    end)
    self.view.workHourAllocation.confirmBtn.onClick:AddListener(function()
        self:_OnClickWorkHourAllocationConfirm()
    end)
    self:_HideAutoReminder()

    local roomType = SpaceshipUtils.getRoomTypeByRoomId(roomId)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]
    self.view.bigBgIcon:LoadSprite(UIConst.UI_SPRITE_SPACESHIP_ROOM, roomTypeData.bg .. "_shallow")
    local color = self.view.topNodeLuaUIWidget:GetRoomColor()
    self.view.colorDeco.color = color
    self.view.charEffectNode1.roomColorLight.color = color
    self.view.colorDeco.gameObject:SetActive(true)

    self.m_skillHintBindingId = self:BindInputPlayerAction("ss_schedule_char_skill_detail", function()
        local skillNodes = self.m_skillNodesByTeamType[self.m_focusedCharEffectTeamType]
        if skillNodes then
            for _, skillNode in ipairs(skillNodes) do
                if skillNode:GetCanLevelUpState() then
                    skillNode:TriggerSkillHint()
                end
            end
        end
    end)

    if not self:_TryRecoverWorkHourAllocationState(arg) then
        self:_Refresh(true)
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    local enterAnimation = arg.isFromStation and ENTER_FROM_STATION_ANIMATION or ENTER_ANIMATION
    self.animationWrapper:Play(enterAnimation, nil, CS.Beyond.UI.UIConst.AnimationState.In)
end

SpaceshipScheduleCtrl._Refresh = HL.Method(HL.Opt(HL.Boolean)) << function(self, resetNaviTarget)
    local room = self:_GetRoom()
    self:_TryDisableInvalidAutoSchedule(room)
    self.view.topNodeLuaUIWidget:UpdateRoomEffectInfoFromCS(room.attrsMap)

    self:_UpdateCharEffectNodes(room)
    self:_UpdateAutoBtn(room)
    self:_UpdateAutoScheduleNodes(room)
    if self.m_isEditingWorkHourAllocation then
        self:_UpdateWorkHourAllocationSliderVisuals()
    end
    if resetNaviTarget then
        if self.m_isEditingWorkHourAllocation then
            self:_SetWorkHourAllocationNaviTarget()
        else
            self:_SetDefaultNaviTarget()
        end
    end
end

SpaceshipScheduleCtrl._GetRoom = HL.Method().Return(HL.Any) << function(self)
    return self.m_spaceship.rooms:get_Item(self.m_roomId)
end

SpaceshipScheduleCtrl._ResetWorkHourAllocationState = HL.Method(HL.Boolean) << function(self, isEditing)
    self.m_isEditingWorkHourAllocation = isEditing
    self.m_hasEditedWorkHourAllocation = false
    self.m_showEditingTimeReminder = false
    self.m_hasShownMinWorkHourToast = false
    self.m_isWorkHourAllocationVisualReversed = false
    self.m_initialWorkHourAllocationVisualReversed = false
    self.m_selectedWorkHourAllocationSlider = 0
    self.m_workHourAllocationStickOwner = WORK_HOUR_ALLOCATION_STICK_OWNER_NONE
    self:_ResetWorkHourAllocationStickRepeatState()
    self:_SetWorkHourAllocationInputEnabled(isEditing)
end

SpaceshipScheduleCtrl._TryRecoverWorkHourAllocationState = HL.Method(HL.Any).Return(HL.Boolean) << function(self, arg)
    if not arg.isEditingWorkHourAllocation then
        return false
    end

    self:_ResetWorkHourAllocationState(true)
    self.m_initialEditingStartTsOffset = arg.initialEditingStartTsOffset
    self.m_initialEditingEndTsOffset = arg.initialEditingEndTsOffset
    self.m_isWorkHourAllocationVisualReversed = arg.isWorkHourAllocationVisualReversed
    self.m_initialWorkHourAllocationVisualReversed = arg.initialWorkHourAllocationVisualReversed
    self:_SetWorkHourAllocationTeamATimeRange(arg.editingStartTsOffset, arg.editingEndTsOffset)
    self.m_showEditingTimeReminder = true
    self:_UpdateWorkHourAllocationEditedState()
    self:_Refresh(true)
    self.m_selectedWorkHourAllocationSlider = arg.selectedWorkHourAllocationSlider
    self:_UpdateWorkHourAllocationSliderVisuals()
    self:_UpdateCurrentTimeRangeText()
    self:_UpdateWorkHourAllocationArrow()
    return true
end

SpaceshipScheduleCtrl._UpdateCurrentRoomCharEffectScheduleInfo = HL.Method(HL.Opt(HL.Boolean)) << function(self, playTimeReminderAnimation)
    local room = self:_GetRoom()
    local schedule = room.schedule
    local isAutoSchedule = schedule ~= nil and schedule.AutoSchedule == true
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local charIdListA = self:_GetScheduleTeamCharIdList(schedule, TeamType.A)
    local charIdListB = self:_GetScheduleTeamCharIdList(schedule, TeamType.B)
    self:_UpdateCharEffectScheduleInfo(
        self.view.charEffectNode1, room, schedule, TeamType.A, charIdListA, isAutoSchedule, playTimeReminderAnimation)
    self:_UpdateCharEffectScheduleInfo(
        self.m_charEffectNodeB, room, schedule, TeamType.B, charIdListB, isAutoSchedule, playTimeReminderAnimation)
    if self.m_isEditingWorkHourAllocation then
        self:_UpdateWorkHourAllocationSliderVisuals()
    end
end

SpaceshipScheduleCtrl._CreateCharEffectNodeB = HL.Method().Return(HL.Any) << function(self)
    local sourceNode = self.view.charEffectNode1
    local go = GameObject.Instantiate(sourceNode.gameObject, sourceNode.transform.parent)
    go.name = "CharEffectNode2"
    go.transform:SetSiblingIndex(sourceNode.transform:GetSiblingIndex() + 1)
    go:SetActive(true)
    return Utils.wrapLuaNode(go)
end

SpaceshipScheduleCtrl._UpdateCharEffectNodes = HL.Method(HL.Any) << function(self, room)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    self.m_skillNodesByTeamType = {
        [TeamType.A] = {},
        [TeamType.B] = {},
    }
    self:_UpdateCharEffectNode(self.view.charEffectNode1, self.m_charEffectCellsA, room, TeamType.A)
    self:_UpdateCharEffectNode(self.m_charEffectNodeB, self.m_charEffectCellsB, room, TeamType.B)
    self:_RefreshSkillHintBinding()
end

SpaceshipScheduleCtrl._PlayTimeReminderInAnimation = HL.Method(HL.Any, HL.Any) << function(self, node, teamType)
    if not self.m_timeReminderShouldShowByTeamType[teamType] then
        return
    end
    node.timeReminderNode.gameObject:SetActiveIfNecessary(true)
    node.timeReminderNodeAnimationWrapper:PlayInAnimation()
end

SpaceshipScheduleCtrl._PlayTimeReminderInAnimations = HL.Method() << function(self)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    self:_PlayTimeReminderInAnimation(self.view.charEffectNode1, TeamType.A)
    self:_PlayTimeReminderInAnimation(self.m_charEffectNodeB, TeamType.B)
end

SpaceshipScheduleCtrl._SetTimeReminderVisible = HL.Method(HL.Any, HL.Any, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, node, teamType, shouldShow, playAnimation)
    local shouldShowByTeamType = self.m_timeReminderShouldShowByTeamType
    local previousShouldShow = shouldShowByTeamType[teamType]
    shouldShowByTeamType[teamType] = shouldShow

    local gameObject = node.timeReminderNode.gameObject
    if shouldShow then
        if previousShouldShow ~= true and playAnimation ~= false then
            gameObject:SetActiveIfNecessary(true)
            self:_PlayTimeReminderInAnimation(node, teamType)
        end
        return
    end
    if not gameObject.activeSelf then
        return
    end
    if previousShouldShow ~= true then
        if previousShouldShow == nil then
            gameObject:SetActive(false)
        end
        return
    end

    if playAnimation == false then
        gameObject:SetActive(false)
        return
    end
    node.timeReminderNodeAnimationWrapper:PlayOutAnimation(function()
        if not shouldShowByTeamType[teamType] then
            gameObject:SetActive(false)
        end
    end)
end

SpaceshipScheduleCtrl._CanTriggerSkillHint = HL.Method().Return(HL.Boolean) << function(self)
    local skillNodes = self.m_skillNodesByTeamType[self.m_focusedCharEffectTeamType]
    if not skillNodes then
        return false
    end
    for _, skillNode in ipairs(skillNodes) do
        if skillNode:GetCanLevelUpState() then
            return true
        end
    end
    return false
end

SpaceshipScheduleCtrl._RefreshSkillHintBinding = HL.Method() << function(self)
    if self.m_skillHintBindingId > 0 then
        InputManagerInst:ToggleBinding(self.m_skillHintBindingId, self:_CanTriggerSkillHint())
    end
end

SpaceshipScheduleCtrl._BindCharEffectNodeNaviTargetChanged = HL.Method(HL.Any, HL.Any) << function(self, node, teamType)
    local naviDecorator = node.inputBindingGroupNaviDecorator
    naviDecorator.onGroupSetAsNaviTarget:RemoveAllListeners()
    naviDecorator.onGroupSetAsNaviTarget:AddListener(function(isTarget)
        self:_OnCharEffectNodeNaviTargetChanged(teamType, isTarget)
    end)
end

SpaceshipScheduleCtrl._OnCharEffectNodeNaviTargetChanged = HL.Method(HL.Any, HL.Boolean) << function(self, teamType, isTarget)
    if isTarget then
        if self.m_focusedCharEffectTeamType ~= teamType then
            self:_HideFocusedCharEffectSkillHints()
            self.m_focusedCharEffectTeamType = teamType
        end
        self.m_lastFocusedCharEffectTeamType = teamType
    elseif self.m_focusedCharEffectTeamType == teamType then
        self:_HideFocusedCharEffectSkillHints()
        self.m_focusedCharEffectTeamType = nil
    end
    self:_RefreshSkillHintBinding()
end

SpaceshipScheduleCtrl._HideFocusedCharEffectSkillHints = HL.Method() << function(self)
    local skillNodes = self.m_skillNodesByTeamType[self.m_focusedCharEffectTeamType]
    if not skillNodes then
        return
    end
    for _, skillNode in ipairs(skillNodes) do
        skillNode:HideSkillHint()
    end
end

SpaceshipScheduleCtrl._SetCharEffectNodeNaviEnabled = HL.Method(HL.Boolean) << function(self, isEnabled)
    if not DeviceInfo.usingController then
        return
    end
    self.view.charEffectNode1.inputBindingGroupNaviDecorator.enabled = isEnabled
    self.m_charEffectNodeB.inputBindingGroupNaviDecorator.enabled = isEnabled
end

SpaceshipScheduleCtrl._OpenStationForEditTeam = HL.Method(HL.Any) << function(self, editTeamType)
    if self.m_isEditingWorkHourAllocation then
        return
    end
    local schedule = self:_GetRoom().schedule
    if schedule and schedule.AutoSchedule then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_SCHEDULE_CANT_EDIT_IN_AUTO_MODE_TOAST)
        return
    end
    self:_EnterStation({ roomId = self.m_roomId, editTeamType = editTeamType })
end

SpaceshipScheduleCtrl._EnterStation = HL.Method(HL.Table) << function(self, stationArg)
    stationArg.isFromSchedule = true
    if stationArg.editTeamType ~= nil then
        PhaseManager:GoToPhase(PhaseId.SpaceshipStation, stationArg)
    elseif PhaseManager:ExitPhaseFast(PHASE_ID) then
        PhaseManager:GoToPhase(PhaseId.SpaceshipStation, stationArg)
    end
end

SpaceshipScheduleCtrl._UpdateAutoBtn = HL.Method(HL.Any) << function(self, room)
    local canAuto = self:_CanEnableAutoSchedule(room)
    self.view.btnAuto.root:SetState(canAuto and "NormalState" or "DisableState")
end

SpaceshipScheduleCtrl._UpdateAutoScheduleNodes = HL.Method(HL.Any) << function(self, room)
    local schedule = room.schedule
    local isAutoSchedule = schedule ~= nil and schedule.AutoSchedule == true
    self.view.btnAuto.gameObject:SetActive(not isAutoSchedule and not self.m_isEditingWorkHourAllocation)
    self.view.autoNode.gameObject:SetActive(isAutoSchedule and not self.m_isEditingWorkHourAllocation)
    self.view.workHourAllocation.gameObject:SetActive(self.m_isEditingWorkHourAllocation)
    self.view.autoNode.autoText.gameObject:SetActive(isAutoSchedule and not self.m_isEditingWorkHourAllocation)
    if isAutoSchedule then
        self:_UpdateAutoNode(schedule)
    end
    self:_StartTimeNowRefreshTimer()
end

SpaceshipScheduleCtrl._SetDefaultNaviTarget = HL.Method() << function(self)
    self:_SetCharEffectNodeNaviEnabled(true)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local node = self.m_lastFocusedCharEffectTeamType == TeamType.B and self.m_charEffectNodeB
        or self.view.charEffectNode1
    local target = node.inputBindingGroupNaviDecorator
    if target then
        self:SetNaviTarget(target)
    else
        self:ClearNaviTarget()
    end
end

SpaceshipScheduleCtrl._ClearWorkHourAllocationNaviTarget = HL.Method() << function(self)
    self:ClearNaviTarget()
    if self.naviGroup then
        self.naviGroup:SetLayerSelectedTarget(nil, true)
    end
end

SpaceshipScheduleCtrl._SetWorkHourAllocationNaviTarget = HL.Method() << function(self)
    self:_ClearWorkHourAllocationNaviTarget()
    self:_SetCharEffectNodeNaviEnabled(false)
    self:_HideFocusedCharEffectSkillHints()
    self.m_focusedCharEffectTeamType = nil
    self:_RefreshSkillHintBinding()
    self:_ClearWorkHourAllocationSliderSelected()
end

SpaceshipScheduleCtrl._InitWorkHourAllocationInput = HL.Method() << function(self)
    self.m_workHourAllocationInputGroupId = self:CreateInputGroup()
    InputManagerInst:CreateBindingByActionId("common_back", function()
        self:_OnClickReturn()
    end, self.m_workHourAllocationInputGroupId)
    InputManagerInst:CreateBindingByActionId("spaceship_schedule_slider_reduce", function()
        self:_OnWorkHourAllocationStepInput(false)
    end, self.m_workHourAllocationInputGroupId)
    InputManagerInst:CreateBindingByActionId("spaceship_schedule_slider_add", function()
        self:_OnWorkHourAllocationStepInput(true)
    end, self.m_workHourAllocationInputGroupId)
    InputManagerInst:CreateBindingByActionId("slider_left_stick_scroll_hori", function()
        self:_OnWorkHourAllocationStickInput(WORK_HOUR_ALLOCATION_STICK_OWNER_A)
    end, self.m_workHourAllocationInputGroupId)
    InputManagerInst:CreateBindingByActionId("slider_stick_scroll_hori", function()
        self:_OnWorkHourAllocationStickInput(WORK_HOUR_ALLOCATION_STICK_OWNER_B)
    end, self.m_workHourAllocationInputGroupId)
    self:_SetWorkHourAllocationInputEnabled(false)
end

SpaceshipScheduleCtrl._SetWorkHourAllocationInputEnabled = HL.Method(HL.Boolean) << function(self, isEnabled)
    if self.m_workHourAllocationInputGroupId > 0 then
        InputManagerInst:ToggleGroup(self.m_workHourAllocationInputGroupId, isEnabled)
    end
    if not isEnabled then
        self:_StopWorkHourAllocationStickReleaseUpdate()
        self:_StopWorkHourAllocationStepReleaseUpdate()
        self.m_workHourAllocationStickOwner = WORK_HOUR_ALLOCATION_STICK_OWNER_NONE
        self:_ResetWorkHourAllocationStickRepeatState()
    end
end

SpaceshipScheduleCtrl._GetWorkHourAllocationStickValue = HL.Method(HL.Number).Return(HL.Number) << function(self, stickOwner)
    local stickValue = InputManagerInst:GetGamepadStickValue(stickOwner == WORK_HOUR_ALLOCATION_STICK_OWNER_A)
    return stickValue.x
end

SpaceshipScheduleCtrl._ResetWorkHourAllocationStickRepeatState = HL.Method() << function(self)
    self.m_workHourAllocationStickNextStepTime = 0
    self.m_workHourAllocationStickNextStepDelayIndex = 1
end

SpaceshipScheduleCtrl._ReleaseWorkHourAllocationStickOwnerIfNecessary = HL.Method() << function(self)
    if self.m_workHourAllocationStickOwner == WORK_HOUR_ALLOCATION_STICK_OWNER_NONE then
        return
    end
    local stickValue = self:_GetWorkHourAllocationStickValue(self.m_workHourAllocationStickOwner)
    if math.abs(stickValue) <= WORK_HOUR_ALLOCATION_STICK_DEAD_ZONE then
        self.m_workHourAllocationStickOwner = WORK_HOUR_ALLOCATION_STICK_OWNER_NONE
        self:_ResetWorkHourAllocationStickRepeatState()
        self:_StopWorkHourAllocationStickReleaseUpdate()
        self:_OnWorkHourAllocationInputReleased()
    end
end

SpaceshipScheduleCtrl._StartWorkHourAllocationStickReleaseUpdate = HL.Method() << function(self)
    if self.m_workHourAllocationStickReleaseUpdateId > 0 then
        return
    end
    self.m_workHourAllocationStickReleaseUpdateId = self:_StartUpdate(function()
        self:_ReleaseWorkHourAllocationStickOwnerIfNecessary()
    end)
end

SpaceshipScheduleCtrl._StopWorkHourAllocationStickReleaseUpdate = HL.Method() << function(self)
    if self.m_workHourAllocationStickReleaseUpdateId > 0 then
        self.m_workHourAllocationStickReleaseUpdateId =
            self:_RemoveUpdate(self.m_workHourAllocationStickReleaseUpdateId)
    end
end

SpaceshipScheduleCtrl._StartWorkHourAllocationStepReleaseUpdate = HL.Method() << function(self)
    if self.m_workHourAllocationStepReleaseUpdateId > 0 then
        return
    end
    self.m_workHourAllocationStepReleaseUpdateId = self:_StartUpdate(function()
        if Input.GetKey(Unity.KeyCode.LeftArrow) or Input.GetKey(Unity.KeyCode.RightArrow) then
            return
        end
        self:_StopWorkHourAllocationStepReleaseUpdate()
        self:_OnWorkHourAllocationInputReleased()
    end)
end

SpaceshipScheduleCtrl._StopWorkHourAllocationStepReleaseUpdate = HL.Method() << function(self)
    if self.m_workHourAllocationStepReleaseUpdateId > 0 then
        self.m_workHourAllocationStepReleaseUpdateId =
            self:_RemoveUpdate(self.m_workHourAllocationStepReleaseUpdateId)
    end
end

SpaceshipScheduleCtrl._OnWorkHourAllocationStickInput = HL.Method(HL.Number) << function(self, stickOwner)
    if not self.m_isEditingWorkHourAllocation then
        return
    end
    self:_ReleaseWorkHourAllocationStickOwnerIfNecessary()
    local stickValue = self:_GetWorkHourAllocationStickValue(stickOwner)
    if math.abs(stickValue) <= WORK_HOUR_ALLOCATION_STICK_DEAD_ZONE then
        return
    end
    local isFirstStep = self.m_workHourAllocationStickOwner == WORK_HOUR_ALLOCATION_STICK_OWNER_NONE
    if self.m_workHourAllocationStickOwner == WORK_HOUR_ALLOCATION_STICK_OWNER_NONE then
        self.m_workHourAllocationStickOwner = stickOwner
        self:_StartWorkHourAllocationStickReleaseUpdate()
    end
    if self.m_workHourAllocationStickOwner ~= stickOwner then
        return
    end
    local currentTime = Time.unscaledTime
    if isFirstStep then
        self.m_workHourAllocationStickNextStepTime = currentTime + WORK_HOUR_ALLOCATION_STICK_REPEAT_DELAYS[1]
        self.m_workHourAllocationStickNextStepDelayIndex = 2
    else
        if currentTime < self.m_workHourAllocationStickNextStepTime then
            return
        end
        local delayIndex = self.m_workHourAllocationStickNextStepDelayIndex
        self.m_workHourAllocationStickNextStepTime = currentTime + WORK_HOUR_ALLOCATION_STICK_REPEAT_DELAYS[delayIndex]
        if delayIndex < #WORK_HOUR_ALLOCATION_STICK_REPEAT_DELAYS then
            self.m_workHourAllocationStickNextStepDelayIndex = delayIndex + 1
        end
    end
    self:_ApplyWorkHourAllocationStep(stickOwner == WORK_HOUR_ALLOCATION_STICK_OWNER_A, stickValue > 0)
end

SpaceshipScheduleCtrl._CanEnableAutoSchedule = HL.Method(HL.Any).Return(HL.Boolean) << function(self, room)
    local schedule = room.schedule
    if not schedule then
        return false
    end
    return self:_GetScheduleListCount(schedule.StationedCharListA) > 0
            and self:_GetScheduleListCount(schedule.StationedCharListB) > 0
end

SpaceshipScheduleCtrl._TryDisableInvalidAutoSchedule = HL.Method(HL.Any) << function(self, room)
    local schedule = room.schedule
    if not schedule or not schedule.AutoSchedule then
        self.m_isDisablingInvalidAutoSchedule = false
        return
    end
    if self:_CanEnableAutoSchedule(room) or self.m_isDisablingInvalidAutoSchedule then
        return
    end

    self.m_isDisablingInvalidAutoSchedule = true
    self.m_spaceship:EditSchedule(self.m_roomId, false, schedule.AppliesTeamType,
        schedule.StartTsOffset, schedule.EndTsOffset)
end

SpaceshipScheduleCtrl._GetScheduleListCount = HL.Method(HL.Any).Return(HL.Number) << function(self, list)
    if not list then
        return 0
    end
    return list.Count or #list
end

SpaceshipScheduleCtrl._ReportShiftScheduleStart = HL.Method(HL.String, HL.Any) << function(self, action, schedule)
    local planMember = SpaceshipUtils.cloneScheduleList(schedule.StationedCharListA)
    local planMemberB = SpaceshipUtils.cloneScheduleList(schedule.StationedCharListB)
    for _, charId in ipairs(planMemberB) do
        table.insert(planMember, charId)
    end
    table.sort(planMember)

    local roomType = SpaceshipUtils.getRoomTypeByRoomId(self.m_roomId)
    EventLogManagerInst:GameEvent_ShiftScheduleStart(self.m_roomId, roomType:ToString(), action, planMember)
end

SpaceshipScheduleCtrl._OnClickAutoBtn = HL.Method() << function(self)
    local room = self:_GetRoom()
    if not self:_CanEnableAutoSchedule(room) then
        self:_ShowAutoReminder()
        return
    end

    AudioAdapter.PostEvent("Au_UI_Button_Confirm")
    self:_EnterWorkHourAllocation()
end

SpaceshipScheduleCtrl._OnClickPauseAuto = HL.Method() << function(self)
    local room = self:_GetRoom()
    local schedule = room.schedule
    if not schedule then
        return
    end
    self:_ResetWorkHourAllocationState(false)
    self:_ClearTimeNowRefreshTimer()
    self:_ReportShiftScheduleStart(SHIFT_SCHEDULE_ACTION_STOP, schedule)
    self.m_spaceship:EditSchedule(self.m_roomId, false, schedule.AppliesTeamType, schedule.StartTsOffset, schedule.EndTsOffset)
end

SpaceshipScheduleCtrl._EnterWorkHourAllocation = HL.Method(HL.Opt(HL.Boolean)) << function(self, playTimeReminderAnimation)
    self:_ResetWorkHourAllocationState(true)
    local room = self:_GetRoom()
    if room.schedule then
        self:_UpdateWorkHourAllocation(room.schedule, playTimeReminderAnimation)
    else
        self:_UpdateWorkHourAllocationToDefaultInitial(playTimeReminderAnimation)
    end
    self.m_showEditingTimeReminder = true
    self:_UpdateWorkHourAllocationSliderVisuals()
    self:_UpdateCurrentTimeRangeText()
    self:_UpdateWorkHourAllocationArrow()
    self:_UpdateCurrentRoomCharEffectScheduleInfo(playTimeReminderAnimation)
    self:_UpdateAutoScheduleNodes(room)
    self:_SetWorkHourAllocationNaviTarget()
end

SpaceshipScheduleCtrl._OnClickReturn = HL.Method() << function(self)
    if self.m_isEditingWorkHourAllocation then
        AudioAdapter.PostEvent("Au_UI_Button_Back")
        AudioAdapter.PostEvent("Au_UI_Popup_DetailsPanel_Close")
        self:_CancelWorkHourAllocation()
        return
    end
    PhaseManager:PopPhase(PHASE_ID)
end

SpaceshipScheduleCtrl._ReopenStation = HL.Method() << function(self)
    self:_EnterStation({ roomId = self.m_roomId })
end

SpaceshipScheduleCtrl._CancelWorkHourAllocation = HL.Method() << function(self)
    self:_ResetWorkHourAllocationState(false)
    self:_ClearTimeNowRefreshTimer()
    self:_Refresh(true)
end

SpaceshipScheduleCtrl._OnWorkHourAllocationSliderChanged = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, isStartSlider, playTimeReminderAnimation)
    if not self.m_isEditingWorkHourAllocation then
        return
    end
    if self.m_isUpdatingWorkHourAllocation then
        return
    end
    if isStartSlider ~= nil then
        self:_SetWorkHourAllocationSliderSelected(isStartSlider)
    end
    self:_SnapWorkHourAllocationSliders(isStartSlider)
    self:_ClampWorkHourAllocationSliders(isStartSlider)
    self.m_showEditingTimeReminder = false
    self:_UpdateWorkHourAllocationEditedState()
    self:_UpdateWorkHourAllocationSliderVisuals()
    self:_UpdateCurrentRoomCharEffectScheduleInfo(playTimeReminderAnimation)
end

SpaceshipScheduleCtrl._OnWorkHourAllocationInputReleased = HL.Method() << function(self)
    if not self.m_isEditingWorkHourAllocation then
        return
    end
    if self.m_isUpdatingWorkHourAllocation then
        return
    end
    if self.m_workHourAllocationStickOwner ~= WORK_HOUR_ALLOCATION_STICK_OWNER_NONE then
        return
    end
    if Input.GetKey(Unity.KeyCode.LeftArrow) or Input.GetKey(Unity.KeyCode.RightArrow) then
        return
    end
    self:_StopWorkHourAllocationStickReleaseUpdate()
    self:_StopWorkHourAllocationStepReleaseUpdate()
    self:_UpdateWorkHourAllocationEditedState()
    self.m_showEditingTimeReminder = true
    self:_ClearWorkHourAllocationSliderSelected()
    self:_UpdateCurrentRoomCharEffectScheduleInfo()
    self:_PlayTimeReminderInAnimations()
end

SpaceshipScheduleCtrl._BindWorkHourAllocationSliderPointerUp = HL.Method(HL.Any) << function(self, eventTrigger)
    local EventSystems = CS.UnityEngine.EventSystems
    local entry = EventSystems.EventTrigger.Entry()
    entry.eventID = EventSystems.EventTriggerType.PointerUp
    entry.callback:AddListener(function(_)
        self:_OnWorkHourAllocationInputReleased()
    end)
    eventTrigger.triggers:Add(entry)
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocation = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, schedule, playTimeReminderAnimation)
    local startTsOffset, endTsOffset, appliesTeamType = self:_GetScheduleTimeArgs(schedule)
    self.m_isWorkHourAllocationVisualReversed = appliesTeamType ~= TEAM_TYPE_A
    self.m_initialWorkHourAllocationVisualReversed = self.m_isWorkHourAllocationVisualReversed
    self:_SetWorkHourAllocationTeamATimeRange(startTsOffset, endTsOffset, playTimeReminderAnimation)
    self.m_initialEditingStartTsOffset, self.m_initialEditingEndTsOffset = self:_GetEditingTeamATimeRange()
    self.m_hasEditedWorkHourAllocation = false
    self:_UpdateWorkHourAllocationSliderVisuals()
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationToDefaultInitial = HL.Method(HL.Opt(HL.Boolean)) << function(self, playTimeReminderAnimation)
    local startTsOffset = 0
    local endTsOffset = 12 * Const.SEC_PER_HOUR
    self.m_isWorkHourAllocationVisualReversed = false
    self.m_initialWorkHourAllocationVisualReversed = false
    self:_SetWorkHourAllocationTeamATimeRange(startTsOffset, endTsOffset, playTimeReminderAnimation)
    self.m_initialEditingStartTsOffset = startTsOffset
    self.m_initialEditingEndTsOffset = endTsOffset
    self.m_hasEditedWorkHourAllocation = false
end

SpaceshipScheduleCtrl._GetEditingTeamATimeRange = HL.Method().Return(HL.Number, HL.Number) << function(self)
    local startTsOffset = math.floor(self.view.workHourAllocation.spaceshipScheduleSliderA.slider.value * Const.SEC_PER_MIN + 0.5)
    local endTsOffset = math.floor((WORK_HOUR_ALLOCATION_SLIDER_MAX - self.view.workHourAllocation.spaceshipScheduleSliderB.slider.value) * Const.SEC_PER_MIN + 0.5)
    return startTsOffset, endTsOffset
end

SpaceshipScheduleCtrl._SetWorkHourAllocationTeamATimeRange = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Boolean)) << function(self, aStart, aEnd, playTimeReminderAnimation)
    local daySeconds = Const.SEC_PER_DAY
    aStart = math.max(0, math.min(daySeconds, aStart))
    aEnd = math.max(0, math.min(daySeconds, aEnd))
    if aStart > aEnd then
        aStart, aEnd = aEnd, aStart
    end
    self.m_isUpdatingWorkHourAllocation = true
    self.view.workHourAllocation.spaceshipScheduleSliderA.slider.value = aStart / Const.SEC_PER_MIN
    self.view.workHourAllocation.spaceshipScheduleSliderB.slider.value = WORK_HOUR_ALLOCATION_SLIDER_MAX - aEnd / Const.SEC_PER_MIN
    self.m_isUpdatingWorkHourAllocation = false
    self:_OnWorkHourAllocationSliderChanged(nil, playTimeReminderAnimation)
end

SpaceshipScheduleCtrl._OnClickWorkHourAllocationRevert = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_SPACESHIP_SCHEDULE_REVERT_DEFAULT_CONFIRM,
        onConfirm = function()
            self:_RevertWorkHourAllocationToDefault()
        end,
    })
end

SpaceshipScheduleCtrl._RevertWorkHourAllocationToDefault = HL.Method() << function(self)
    self.m_isWorkHourAllocationVisualReversed = false
    self:_SetWorkHourAllocationTeamATimeRange(0, 12 * Const.SEC_PER_HOUR)
    self:_UpdateWorkHourAllocationEditedState()
    self.m_showEditingTimeReminder = true
    self:_UpdateWorkHourAllocationSliderVisuals()
    self:_UpdateCurrentRoomCharEffectScheduleInfo()
    self:_SetWorkHourAllocationNaviTarget()
end

SpaceshipScheduleCtrl._OnClickWorkHourAllocationReverse = HL.Method() << function(self)
    self:_ReverseWorkHourAllocation()
end

SpaceshipScheduleCtrl._ReverseWorkHourAllocation = HL.Method() << function(self)
    self.m_isWorkHourAllocationVisualReversed = not self.m_isWorkHourAllocationVisualReversed
    self:_UpdateWorkHourAllocationEditedState()
    self.m_showEditingTimeReminder = true
    self:_UpdateWorkHourAllocationSliderVisuals()
    self:_UpdateCurrentRoomCharEffectScheduleInfo()
    self:_ClearWorkHourAllocationNaviTarget()
end

SpaceshipScheduleCtrl._OnClickWorkHourAllocationConfirm = HL.Method() << function(self)
    local hasWorkTimeReminder = self:_HasEditingWorkTimeReminder()
    if hasWorkTimeReminder then
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_SPACESHIP_SCHEDULE_CONFIRM_WORK_TIME_NOT_ENOUGH,
            warningContent = Language.LUA_SPACESHIP_SCHEDULE_CONFIRM_WORK_TIME_NOT_ENOUGH_WARNING,
            onConfirm = function()
                self:_ConfirmWorkHourAllocation()
            end,
        })
        return
    end
    self:_ConfirmWorkHourAllocation()
end

SpaceshipScheduleCtrl._ConfirmWorkHourAllocation = HL.Method() << function(self)
    local startTsOffset, endTsOffset = self:_GetEditingTeamATimeRange()
    local schedule = self:_GetRoom().schedule
    if schedule and not schedule.AutoSchedule then
        self:_ReportShiftScheduleStart(SHIFT_SCHEDULE_ACTION_START, schedule)
    end
    self.m_spaceship:EditSchedule(self.m_roomId, true, self:_GetEditingAppliesTeamType(), startTsOffset, endTsOffset)
end

SpaceshipScheduleCtrl._HasEditingWorkTimeReminder = HL.Method().Return(HL.Boolean) << function(self)
    local room = self:_GetRoom()
    local schedule = room.schedule
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local hasReminderA = self:_HasTeamWorkTimeReminder(room, schedule, TeamType.A, true)
    local hasReminderB = self:_HasTeamWorkTimeReminder(room, schedule, TeamType.B, true)
    return hasReminderA or hasReminderB
end

SpaceshipScheduleCtrl._SnapWorkHourAllocationSliders = HL.Method(HL.Opt(HL.Boolean)) << function(self, isStartSlider)
    local startSlider = self.view.workHourAllocation.spaceshipScheduleSliderA.slider
    local endSlider = self.view.workHourAllocation.spaceshipScheduleSliderB.slider
    self.m_isUpdatingWorkHourAllocation = true
    if isStartSlider ~= false then
        startSlider.value = math.floor(startSlider.value / WORK_HOUR_ALLOCATION_STEP_MINUTES + 0.5)
            * WORK_HOUR_ALLOCATION_STEP_MINUTES
    end
    if isStartSlider ~= true then
        endSlider.value = math.floor(endSlider.value / WORK_HOUR_ALLOCATION_STEP_MINUTES + 0.5)
            * WORK_HOUR_ALLOCATION_STEP_MINUTES
    end
    self.m_isUpdatingWorkHourAllocation = false
end

SpaceshipScheduleCtrl._ClampWorkHourAllocationSliders = HL.Method(HL.Opt(HL.Boolean)) << function(self, isStartSlider)
    local startSlider = self.view.workHourAllocation.spaceshipScheduleSliderA.slider
    local endSlider = self.view.workHourAllocation.spaceshipScheduleSliderB.slider
    local startValue = startSlider.value
    local endValue = WORK_HOUR_ALLOCATION_SLIDER_MAX - endSlider.value
    local duration = endValue - startValue
    if duration >= WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES and duration <= WORK_HOUR_ALLOCATION_MAX_DURATION_MINUTES then
        self.m_hasShownMinWorkHourToast = false
        return
    end
    if not self.m_hasShownMinWorkHourToast then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_SCHEDULE_MIN_WORK_HOUR_TOAST)
        self.m_hasShownMinWorkHourToast = true
    end
    self.m_isUpdatingWorkHourAllocation = true
    if duration < WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES then
        if isStartSlider == true then
            local clampedStartValue = endValue - WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES
            if clampedStartValue < 0 then
                clampedStartValue = 0
                endValue = WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES
                endSlider.value = WORK_HOUR_ALLOCATION_SLIDER_MAX - endValue
            end
            startSlider.value = clampedStartValue
        else
            local clampedEndValue = startValue + WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES
            if clampedEndValue > WORK_HOUR_ALLOCATION_SLIDER_MAX then
                clampedEndValue = WORK_HOUR_ALLOCATION_SLIDER_MAX
                startValue = WORK_HOUR_ALLOCATION_SLIDER_MAX - WORK_HOUR_ALLOCATION_MIN_DURATION_MINUTES
                startSlider.value = startValue
            end
            endSlider.value = WORK_HOUR_ALLOCATION_SLIDER_MAX - clampedEndValue
        end
    else
        if isStartSlider == true then
            startSlider.value = endValue - WORK_HOUR_ALLOCATION_MAX_DURATION_MINUTES
        else
            endSlider.value = WORK_HOUR_ALLOCATION_SLIDER_MAX - (startValue + WORK_HOUR_ALLOCATION_MAX_DURATION_MINUTES)
        end
    end
    self.m_isUpdatingWorkHourAllocation = false
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationEditedState = HL.Method() << function(self)
    local startTsOffset, endTsOffset = self:_GetEditingTeamATimeRange()
    self.m_hasEditedWorkHourAllocation = startTsOffset ~= self.m_initialEditingStartTsOffset
        or endTsOffset ~= self.m_initialEditingEndTsOffset
        or self.m_isWorkHourAllocationVisualReversed ~= self.m_initialWorkHourAllocationVisualReversed
end

SpaceshipScheduleCtrl._GetEditingAppliesTeamType = HL.Method().Return(HL.Number) << function(self)
    return self.m_isWorkHourAllocationVisualReversed and TEAM_TYPE_B or TEAM_TYPE_A
end

SpaceshipScheduleCtrl._SetWorkHourAllocationSliderSelected = HL.Method(HL.Boolean) << function(self, isStartSlider)
    self.m_selectedWorkHourAllocationSlider = isStartSlider and 1 or 2
    self:_ClearWorkHourAllocationNaviTarget()
    self:_UpdateWorkHourAllocationSliderVisuals()
end

SpaceshipScheduleCtrl._ClearWorkHourAllocationSliderSelected = HL.Method() << function(self)
    self.m_selectedWorkHourAllocationSlider = 0
    self:_UpdateWorkHourAllocationSliderVisuals()
end

SpaceshipScheduleCtrl._OnWorkHourAllocationStepInput = HL.Method(HL.Boolean) << function(self, isAdd)
    if not self.m_isEditingWorkHourAllocation then
        return
    end
    if self.m_selectedWorkHourAllocationSlider == 0 then
        self:_SetWorkHourAllocationSliderSelected(true)
    end
    self:_StartWorkHourAllocationStepReleaseUpdate()
    local isStartSlider = self.m_selectedWorkHourAllocationSlider ~= 2
    self:_ApplyWorkHourAllocationStep(isStartSlider, isAdd)
end

SpaceshipScheduleCtrl._ApplyWorkHourAllocationStep = HL.Method(HL.Boolean, HL.Boolean) << function(self, isStartSlider, isAdd)
    if not self.m_isEditingWorkHourAllocation then
        return
    end
    local selectedSlider = isStartSlider and 1 or 2
    if self.m_selectedWorkHourAllocationSlider ~= selectedSlider then
        self:_SetWorkHourAllocationSliderSelected(isStartSlider)
    end
    local slider = isStartSlider and self.view.workHourAllocation.spaceshipScheduleSliderA.slider
        or self.view.workHourAllocation.spaceshipScheduleSliderB.slider
    local delta = isAdd and WORK_HOUR_ALLOCATION_STEP_MINUTES or -WORK_HOUR_ALLOCATION_STEP_MINUTES
    if not isStartSlider then
        delta = -delta
    end
    self.m_showEditingTimeReminder = false
    self.m_isUpdatingWorkHourAllocation = true
    slider.value = slider.value + delta
    self.m_isUpdatingWorkHourAllocation = false
    self:_OnWorkHourAllocationSliderChanged(isStartSlider)
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationSliderVisuals = HL.Method() << function(self)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local activeTeamType = self.m_isWorkHourAllocationVisualReversed and TeamType.B or TeamType.A
    local sideTeamType = self.m_isWorkHourAllocationVisualReversed and TeamType.A or TeamType.B
    local showReminderA = self.m_showEditingTimeReminder
        and self.m_timeReminderShouldShowByTeamType[TeamType.A] == true
    local showReminderB = self.m_showEditingTimeReminder
        and self.m_timeReminderShouldShowByTeamType[TeamType.B] == true
    local showActiveReminder = (activeTeamType == TeamType.A and showReminderA)
        or (activeTeamType == TeamType.B and showReminderB)
    local showSideReminder = (sideTeamType == TeamType.A and showReminderA)
        or (sideTeamType == TeamType.B and showReminderB)
    self:_UpdateWorkHourAllocationGradRed(showActiveReminder)
    self.view.workHourAllocation.redShadowImage.gameObject:SetActive(showReminderA or showReminderB)
    local sliderAIsTeamA = not self.m_isWorkHourAllocationVisualReversed
    self:_UpdateWorkHourAllocationSliderColor()
    local leftTeamText = self.view.workHourAllocation.leftTeamText
    leftTeamText.text = SpaceshipUtils.getScheduleTeamTextByIsTeamA(not sliderAIsTeamA)
    leftTeamText.gameObject:SetActive(self.view.workHourAllocation.spaceshipScheduleSliderA.slider.value ~= 0)
    self:_UpdateWorkHourAllocationSliderVisual(self.view.workHourAllocation.spaceshipScheduleSliderA, sliderAIsTeamA,
        self.m_selectedWorkHourAllocationSlider == 1, showSideReminder)
    self:_UpdateWorkHourAllocationSliderVisual(self.view.workHourAllocation.spaceshipScheduleSliderB, not sliderAIsTeamA,
        self.m_selectedWorkHourAllocationSlider == 2, showSideReminder)
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationGradRed = HL.Method(HL.Boolean) << function(self, showReminder)
    local workHourAllocation = self.view.workHourAllocation
    local gradRed = workHourAllocation.gradRed
    local gradRedRect = gradRed.transform
    local gradRedParentRect = gradRedRect.parent
    local timeAxisRect = workHourAllocation.spaceshipScheduleSliderA.slider.transform
    local startRatio = workHourAllocation.spaceshipScheduleSliderA.slider.value / WORK_HOUR_ALLOCATION_SLIDER_MAX
    local endRatio = (WORK_HOUR_ALLOCATION_SLIDER_MAX - workHourAllocation.spaceshipScheduleSliderB.slider.value)
        / WORK_HOUR_ALLOCATION_SLIDER_MAX
    local timeAxisOriginX = timeAxisRect.localPosition.x - gradRedParentRect.localPosition.x
    local timeAxisLocalStart = timeAxisOriginX + timeAxisRect.rect.xMin + timeAxisRect.rect.width * startRatio
    local timeAxisLocalEnd = timeAxisOriginX + timeAxisRect.rect.xMin + timeAxisRect.rect.width * endRatio
    gradRedRect.offsetMin = CS.UnityEngine.Vector2(timeAxisLocalStart - gradRedParentRect.rect.xMin, gradRedRect.offsetMin.y)
    gradRedRect.offsetMax = CS.UnityEngine.Vector2(timeAxisLocalEnd - gradRedParentRect.rect.xMax, gradRedRect.offsetMax.y)
    gradRed.gameObject:SetActive(showReminder)
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationSliderColor = HL.Method() << function(self)
    local roomColor = self.view.topNodeLuaUIWidget:GetRoomColor()
    local sideColor = self.m_isWorkHourAllocationVisualReversed and roomColor or Color.white
    self.view.workHourAllocation.roomShadowImg.color = SpaceshipUtils.getRoomShadowColor(self.m_roomId)
    self.view.workHourAllocation.sliderBgImg.color = self.m_isWorkHourAllocationVisualReversed and Color.white or roomColor
    self.view.workHourAllocation.spaceshipScheduleSliderA.fill.color = sideColor
    self.view.workHourAllocation.spaceshipScheduleSliderB.fill.color = sideColor
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationSliderVisual = HL.Method(HL.Any, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, node, isTeamA, isSelected, showReminder)
    node.stateController:SetState(isSelected and "Select" or "UnSelect")
    node.stateController:SetState(showReminder and "Red" or "Normal")
    node.textSlider.text = SpaceshipUtils.getScheduleTeamTextByIsTeamA(isTeamA)
end

SpaceshipScheduleCtrl._UpdateAutoNode = HL.Method(HL.Any) << function(self, schedule)
    local startTsOffset, endTsOffset, appliesTeamType = self:_GetScheduleTimeArgs(schedule)
    self:_UpdateAutoNodeSliders(schedule, startTsOffset, endTsOffset, appliesTeamType)
    self:_UpdateAutoNodeArrow()
    self:_UpdateAutoNodeReminderIcon(schedule)
end

SpaceshipScheduleCtrl._GetScheduleTimeArgs = HL.Method(HL.Any).Return(HL.Number, HL.Number, HL.Number) << function(self, schedule)
    if not schedule then
        return 0, 12 * Const.SEC_PER_HOUR, TEAM_TYPE_A
    end
    local startTsOffset = schedule.StartTsOffset
    local endTsOffset = schedule.EndTsOffset
    local appliesTeamType = schedule.AppliesTeamType ~= TEAM_TYPE_NONE and schedule.AppliesTeamType or TEAM_TYPE_A
    if startTsOffset == endTsOffset then
        startTsOffset = 0
        endTsOffset = 12 * Const.SEC_PER_HOUR
        appliesTeamType = TEAM_TYPE_A
    end
    return startTsOffset, endTsOffset, appliesTeamType
end

SpaceshipScheduleCtrl._UpdateAutoNodeSliders = HL.Method(HL.Any, HL.Number, HL.Number, HL.Number) << function(self, schedule, startTsOffset, endTsOffset, appliesTeamType)
    local daySeconds = Const.SEC_PER_DAY
    local beforeSeconds = startTsOffset
    local activeSeconds = endTsOffset - startTsOffset
    local afterSeconds = daySeconds - endTsOffset
    local activeIsTeamA = appliesTeamType == TEAM_TYPE_A
    local sideIsTeamA = not activeIsTeamA
    local room = self:_GetRoom()
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local showReminderA = self:_HasTeamWorkTimeReminder(room, schedule, TeamType.A, false)
    local showReminderB = self:_HasTeamWorkTimeReminder(room, schedule, TeamType.B, false)
    local activeShowReminder = (activeIsTeamA and showReminderA) or (not activeIsTeamA and showReminderB)
    local sideShowReminder = (sideIsTeamA and showReminderA) or (not sideIsTeamA and showReminderB)
    self:_SetAutoSliderNodeState(self.view.autoNode.sliderNode3, self.view.autoNode.image3, self.view.autoNode.redImage3,
        beforeSeconds, sideIsTeamA, sideShowReminder)
    self:_SetAutoSliderNodeState(self.view.autoNode.sliderNode1, self.view.autoNode.image1, self.view.autoNode.redImage1,
        activeSeconds, activeIsTeamA, activeShowReminder)
    self:_SetAutoSliderNodeState(self.view.autoNode.sliderNode2, self.view.autoNode.image2, self.view.autoNode.redImage2,
        afterSeconds, sideIsTeamA, sideShowReminder)
    self.view.autoNode.text1.text = SpaceshipUtils.getScheduleTeamTextByIsTeamA(activeIsTeamA)
    self.view.autoNode.text2.text = SpaceshipUtils.getScheduleTeamTextByIsTeamA(sideIsTeamA)
    self.view.autoNode.text3.text = SpaceshipUtils.getScheduleTeamTextByIsTeamA(sideIsTeamA)
end

SpaceshipScheduleCtrl._GetTeamDisplayTimeRange = HL.Method(HL.Any, HL.Any, HL.Boolean).Return(HL.Number, HL.Number) << function(self, schedule, teamType, useEditingValue)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local startTsOffset, endTsOffset, appliesTeamType
    if useEditingValue then
        startTsOffset, endTsOffset = self:_GetEditingTeamATimeRange()
        appliesTeamType = self:_GetEditingAppliesTeamType()
    else
        startTsOffset, endTsOffset, appliesTeamType = self:_GetScheduleTimeArgs(schedule)
    end
    local isTeamA = teamType == TeamType.A
    local isAppliesTeamA = appliesTeamType == TEAM_TYPE_A
    if isTeamA == isAppliesTeamA then
        return startTsOffset, endTsOffset
    end
    return endTsOffset, startTsOffset + (startTsOffset <= endTsOffset and Const.SEC_PER_DAY or 0)
end

SpaceshipScheduleCtrl._GetDefaultTeamDisplayTimeRange = HL.Method(HL.Any).Return(HL.Number, HL.Number) << function(self, teamType)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if teamType == TeamType.A then
        return 0, 12 * Const.SEC_PER_HOUR
    end
    return 12 * Const.SEC_PER_HOUR, Const.SEC_PER_DAY
end

SpaceshipScheduleCtrl._GetTeamDisplayDuration = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, startTsOffset, endTsOffset)
    local duration = endTsOffset - startTsOffset
    if duration < 0 then
        duration = duration + Const.SEC_PER_DAY
    end
    return duration
end

SpaceshipScheduleCtrl._SetAutoSliderNodeWidth = HL.Method(HL.Any, HL.Number) << function(self, sliderNode, width)
    local show = width > 0
    sliderNode.gameObject:SetActive(show)
    sliderNode.flexibleWidth = show and width or 0
end

SpaceshipScheduleCtrl._SetAutoSliderNodeState = HL.Method(HL.Any, HL.Any, HL.Any, HL.Number, HL.Boolean, HL.Boolean) << function(self, sliderNode, image, redImage, width, isTeamA, showReminder)
    self:_SetAutoSliderNodeWidth(sliderNode, width)
    image.color = isTeamA and self.view.topNodeLuaUIWidget:GetRoomColor() or Color.white
    redImage.gameObject:SetActive(width > 0 and showReminder)
end

SpaceshipScheduleCtrl._UpdateAutoNodeArrow = HL.Method() << function(self)
    self:_UpdateScheduleArrow(self.view.autoNode.arrowImage)
end

SpaceshipScheduleCtrl._UpdateWorkHourAllocationArrow = HL.Method() << function(self)
    self:_UpdateScheduleArrow(self.view.workHourAllocation.arrowImage)
end

SpaceshipScheduleCtrl._UpdateScheduleArrow = HL.Method(HL.Any) << function(self, arrowImage)
    local rectTransform = arrowImage.transform
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds() + Utils.getServerTimeZoneOffsetSeconds()
    local curDate = os.date("!*t", curTime)
    local hourCenterOffset = (curDate.hour + 0.5) * Const.SEC_PER_HOUR
    local ratio = hourCenterOffset / Const.SEC_PER_DAY
    rectTransform.anchorMin = CS.UnityEngine.Vector2(ratio, rectTransform.anchorMin.y)
    rectTransform.anchorMax = CS.UnityEngine.Vector2(ratio, rectTransform.anchorMax.y)
    rectTransform.anchoredPosition = CS.UnityEngine.Vector2(0, rectTransform.anchoredPosition.y)
end

SpaceshipScheduleCtrl._UpdateAutoNodeReminderIcon = HL.Method(HL.Any) << function(self, schedule)
    local room = self:_GetRoom()
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local showReminder = self:_HasTeamWorkTimeReminder(room, schedule, TeamType.A, false)
        or self:_HasTeamWorkTimeReminder(room, schedule, TeamType.B, false)
    self.view.autoNode.decoReminderIcon.gameObject:SetActive(showReminder)
end

SpaceshipScheduleCtrl._HasTeamWorkTimeReminder = HL.Method(HL.Any, HL.Any, HL.Any, HL.Boolean).Return(HL.Boolean) << function(self, room, schedule, teamType, useEditingValue)
    local startTsOffset, endTsOffset = self:_GetTeamDisplayTimeRange(schedule, teamType, useEditingValue)
    local charIdList = self:_GetScheduleTeamCharIdList(schedule, teamType)
    local estimatedWorkSeconds = self:_GetTeamEstimatedWorkSeconds(room, charIdList)
    if estimatedWorkSeconds <= 0 then
        return false
    end
    local displayDuration = self:_GetTeamDisplayDuration(startTsOffset, endTsOffset)
    return displayDuration > estimatedWorkSeconds
end

SpaceshipScheduleCtrl._GetScheduleTeamCharIdList = HL.Method(HL.Any, HL.Any).Return(HL.Table) << function(self, schedule, teamType)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    if not schedule then
        return {}
    end
    local sourceList = teamType == TeamType.A and schedule.StationedCharListA or schedule.StationedCharListB
    return SpaceshipUtils.cloneScheduleList(sourceList)
end

SpaceshipScheduleCtrl._UpdateCurrentTimeRangeText = HL.Method() << function(self)
    local timeNowTxt = self.view.workHourAllocation.timeNowTxt
    timeNowTxt.text = self:_GetCurrentTimeRangeText()
end

SpaceshipScheduleCtrl._GetCurrentTimeRangeText = HL.Method().Return(HL.String) << function(self)
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds() + Utils.getServerTimeZoneOffsetSeconds()
    local curDate = os.date("!*t", curTime)
    local startTsOffset = curDate.hour * Const.SEC_PER_HOUR
    local endTsOffset = startTsOffset + Const.SEC_PER_HOUR
    local timeRangeText = string.format("%s-%s",
        SpaceshipUtils.formatScheduleOffsetTime(startTsOffset),
        SpaceshipUtils.formatScheduleOffsetTime(endTsOffset))
    return string.format(Language.LUA_SPACESHIP_SCHEDULE_CURRENT_TIME_RANGE, Utils.appendUTC(timeRangeText))
end

SpaceshipScheduleCtrl._StartTimeNowRefreshTimer = HL.Method() << function(self)
    self:_ClearTimeNowRefreshTimer()
    local schedule = self:_GetRoom().schedule
    local isAutoSchedule = schedule ~= nil and schedule.AutoSchedule == true
    if not self.m_isEditingWorkHourAllocation and not isAutoSchedule then
        return
    end
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds() + Utils.getServerTimeZoneOffsetSeconds()
    local curDate = os.date("!*t", curTime)
    local passedSecondsInHour = curDate.min * Const.SEC_PER_MIN + curDate.sec
    local delaySeconds = Const.SEC_PER_HOUR - passedSecondsInHour
    if delaySeconds <= 0 then
        delaySeconds = Const.SEC_PER_HOUR
    end
    self.m_timeNowRefreshTimerId = self:_StartTimer(delaySeconds, function()
        self.m_timeNowRefreshTimerId = -1
        if self.m_isEditingWorkHourAllocation then
            self:_UpdateCurrentTimeRangeText()
            self:_UpdateWorkHourAllocationArrow()
            self:_UpdateCurrentRoomCharEffectScheduleInfo()
        else
            local currentSchedule = self:_GetRoom().schedule
            if not currentSchedule or not currentSchedule.AutoSchedule then
                return
            end
            self:_UpdateAutoNodeArrow()
        end
        self:_StartTimeNowRefreshTimer()
    end)
end

SpaceshipScheduleCtrl._ClearTimeNowRefreshTimer = HL.Method() << function(self)
    if self.m_timeNowRefreshTimerId > 0 then
        self.m_timeNowRefreshTimerId = self:_ClearTimer(self.m_timeNowRefreshTimerId)
    end
end

SpaceshipScheduleCtrl._ClearAutoReminderTimer = HL.Method() << function(self)
    if self.m_autoReminderTimerId > 0 then
        self.m_autoReminderTimerId = self:_ClearTimer(self.m_autoReminderTimerId)
    end
end

SpaceshipScheduleCtrl._ShowAutoReminder = HL.Method() << function(self)
    local reminderNode = self.view.btnAuto.reminderNode
    reminderNode.gameObject:SetActive(true)
    self:_ClearAutoReminderTimer()
    self.m_autoReminderTimerId = self:_StartTimer(2, function()
        self.m_autoReminderTimerId = -1
        self:_HideAutoReminder()
    end)
end

SpaceshipScheduleCtrl._HideAutoReminder = HL.Method() << function(self)
    local reminderNode = self.view.btnAuto.reminderNode
    reminderNode.gameObject:SetActive(false)
end

SpaceshipScheduleCtrl._UpdateCharEffectNode = HL.Method(HL.Any, HL.Forward('UIListCache'), HL.Any, HL.Any) << function(self, node, cellCache, room, teamType)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local schedule = room.schedule
    local charIdList = self:_GetScheduleTeamCharIdList(schedule, teamType)
    local isAutoSchedule = schedule ~= nil and schedule.AutoSchedule == true

    node.stateController:SetState(teamType == TeamType.A and "A" or "B")
    self:_UpdateCharEffectWorkState(node, charIdList, teamType, isAutoSchedule, self.m_spaceship)
    self:_BindCharEffectEnterButton(node, charIdList, teamType, self.m_spaceship)
    self:_UpdateCharEffectScheduleInfo(node, room, schedule, teamType, charIdList, isAutoSchedule)
    self:_UpdateCharEffectRoomColor(node, teamType)
    self:_RefreshCharEffectCells(cellCache, room, charIdList, teamType)
end

SpaceshipScheduleCtrl._UpdateCharEffectWorkState = HL.Method(HL.Any, HL.Table, HL.Any, HL.Boolean, HL.Any) << function(self, node, charIdList, teamType, isAutoSchedule, spaceship)
    local isWorkingTeam = spaceship:GetRoomCurrentWorkingTeam(self.m_roomId) == teamType
    local wasRoomColorStateActive = node.roomColorStateImg.gameObject.activeSelf
    if isAutoSchedule then
        node.stateController:SetState(isWorkingTeam and "AutoWork" or "AutoRest")
    elseif #charIdList == 0 then
        node.stateController:SetState("Wait")
    elseif isWorkingTeam then
        node.stateController:SetState("Work")
    else
        node.stateController:SetState("Rest")
    end
    self:_UpdateGroupLoopAnimations(node, teamType, isWorkingTeam and #charIdList > 0)
    self:_UpdateRoomColorStateAnimation(node, teamType, isWorkingTeam, wasRoomColorStateActive)
end

SpaceshipScheduleCtrl._UpdateGroupLoopAnimations = HL.Method(HL.Any, HL.Any, HL.Boolean) << function(self, node, teamType, shouldPlay)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local AnimationState = CS.Beyond.UI.UIConst.AnimationState
    local groupAni1 = node.groupAni1
    local groupAni2 = node.groupAni2
    local groupAniB = node.groupAniB
    local groupBState = node.bRoomColorImg
    local groupAState = node.aRoomColorImg
    groupBState:SetState(teamType == TeamType.B and shouldPlay and "Show" or "NoShow")
    groupAState:SetState(teamType == TeamType.A and shouldPlay and "Show" or "NoShow")
    local shouldPlayGroupA = teamType == TeamType.A and shouldPlay
    if shouldPlayGroupA then
        local wasGroupAni2Active = groupAni2.gameObject.activeSelf
        groupAni2.gameObject:SetActiveIfNecessary(true)
        if groupAni1.curState ~= AnimationState.Loop then
            groupAni1:PlayLoopAnimation()
        end
        if not wasGroupAni2Active or groupAni2.curState ~= AnimationState.Loop then
            groupAni2:PlayLoopAnimation()
        end
    else
        groupAni1:ClearTween(false)
        groupAni1:SampleClipAtPercent(GROUP_A_LOOP_ANIMATION, 0, false)
        groupAni2:ClearTween(false)
        groupAni2.gameObject:SetActive(false)
    end

    local shouldPlayGroupB = teamType == TeamType.B and shouldPlay
    if shouldPlayGroupB then
        if groupAniB.curState ~= AnimationState.Loop then
            groupAniB:PlayLoopAnimation()
        end
    else
        groupAniB:ClearTween(false)
        groupAniB:SampleClipAtPercent(GROUP_B_LOOP_ANIMATION, 0, false)
    end
end

SpaceshipScheduleCtrl._UpdateRoomColorStateAnimation = HL.Method(HL.Any, HL.Any, HL.Boolean, HL.Boolean) << function(self, node, teamType, isWorkingTeam, wasActive)
    if not node.roomColorStateImg.gameObject.activeSelf then
        return
    end

    local animationWrapper = node.roomColorStateImgAnimationWrapper
    
    if isWorkingTeam and self.m_manualSwitchAnimationTeamType == teamType then
        self.m_manualSwitchAnimationTeamType = nil
        animationWrapper:PlayInAnimation()
        return
    end

    local AnimationState = CS.Beyond.UI.UIConst.AnimationState
    local curState = animationWrapper.curState
    if not wasActive or curState ~= AnimationState.In and curState ~= AnimationState.InEasing and curState ~= AnimationState.Loop then
        animationWrapper:PlayLoopAnimation()
    end
end

SpaceshipScheduleCtrl._BindCharEffectEnterButton = HL.Method(HL.Any, HL.Table, HL.Any, HL.Any) << function(self, node, charIdList, teamType, spaceship)
    node.btnEnter.functionBtn.onClick:RemoveAllListeners()
    node.btnEnter.functionBtn.onClick:AddListener(function()
        if #charIdList == 0 then
            return
        end
        local curTime = Time.unscaledTime
        if curTime < self.m_nextStartTeamTime then
            Notify(MessageConst.SHOW_TOAST, Tables.errorCodeTable:GetValue(START_TEAM_CD_ERROR_CODE).text)
            return
        end
        self.m_nextStartTeamTime = curTime + self.view.config.START_TEAM_CD
        self.m_manualSwitchAnimationTeamType = teamType
        spaceship:ManualSwitchCharlist(self.m_roomId, teamType)
    end)
end

SpaceshipScheduleCtrl._UpdateCharEffectScheduleInfo = HL.Method(HL.Any, HL.Any, HL.Any, HL.Any, HL.Table, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, node, room, schedule, teamType, charIdList, isAutoSchedule, playTimeReminderAnimation)
    local estimatedWorkSeconds = self:_GetTeamEstimatedWorkSeconds(room, charIdList)
    node.timeTxt.text = self:_GetEstimatedWorkTimeText(estimatedWorkSeconds)

    local simpleState = "Edit"
    if self.m_isEditingWorkHourAllocation then
        simpleState = self.m_hasEditedWorkHourAllocation and "Adjust" or "Assign"
    elseif isAutoSchedule then
        simpleState = "Assign"
    else
        simpleState = "Edit"
    end
    node.simpleStateController:SetState(simpleState)
    local hasTimeReminder = false
    if schedule then
        local displayStart, displayEnd
        local workStart, workEnd
        if isAutoSchedule then
            workStart, workEnd = self:_GetTeamDisplayTimeRange(schedule, teamType, false)
        elseif self.m_isEditingWorkHourAllocation then
            workStart, workEnd = self:_GetDefaultTeamDisplayTimeRange(teamType)
        end
        if workStart and workEnd then
            node.workTime.text = SpaceshipUtils.formatScheduleTimeRange(workStart, workEnd)
            displayStart, displayEnd = workStart, workEnd
        end
        if self.m_isEditingWorkHourAllocation then
            displayStart, displayEnd = self:_GetTeamDisplayTimeRange(schedule, teamType, true)
            node.timeTxt2.text = SpaceshipUtils.formatScheduleTimeRange(displayStart, displayEnd)
        end
        if displayStart and displayEnd then
            local displayDuration = self:_GetTeamDisplayDuration(displayStart, displayEnd)
            if estimatedWorkSeconds > 0 and displayDuration > estimatedWorkSeconds then
                hasTimeReminder = true
            end
        end
    end
    local showTimeReminder = self.m_isEditingWorkHourAllocation
        and self.m_showEditingTimeReminder and hasTimeReminder
    self:_SetTimeReminderVisible(node, teamType, showTimeReminder, playTimeReminderAnimation)
    node.decoReminderIcon.gameObject:SetActiveIfNecessary(hasTimeReminder and simpleState == "Assign")
end

SpaceshipScheduleCtrl._UpdateCharEffectRoomColor = HL.Method(HL.Any, HL.Any) << function(self, node, teamType)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    
    if teamType == TeamType.A then
        local roomColor = self.view.topNodeLuaUIWidget:GetRoomColor()
        node.roomColorStateImg.color = roomColor
        node.canvasGroup.color = SpaceshipUtils.getRoomDescColor(self.m_roomId)
    end
end

SpaceshipScheduleCtrl._RefreshCharEffectCells = HL.Method(HL.Forward('UIListCache'), HL.Any, HL.Table, HL.Any) << function(self, cellCache, room, charIdList, teamType)
    local maxStationCharNum = room.maxStationCharNum
    local maxLvStationCharNum = room.maxLvStationCount
    local roomType = room.type
    local roomLvTable = SpaceshipUtils.getRoomLvTableByType(roomType)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]
    local context = {
        room = room,
        charIdList = charIdList,
        maxStationCharNum = maxStationCharNum,
        roomLvTable = roomLvTable,
        roomTypeData = roomTypeData,
        roomType = roomType,
        spaceship = self.m_spaceship,
        teamType = teamType,
    }

    cellCache:Refresh(maxLvStationCharNum, function(cell, index)
        self:_UpdateCharEffectCell(cell, index, context)
    end)
end

SpaceshipScheduleCtrl._UpdateCharEffectCell = HL.Method(HL.Any, HL.Number, HL.Table) << function(self, cell, index, context)
    local charId = context.charIdList[index]
    cell.gameObject.name = "Cell-" .. index
    cell.indexTxt.text = index
    if not cell.warnCells then
        cell.warnCells = UIUtils.genCellCache(cell.skillEffectWarnCell)
    end

    local isEmpty = string.isEmpty(charId)
    local isLocked = index > context.maxStationCharNum
    if isEmpty then
        cell.warnCells:Refresh(0)
        if isLocked then
            local needLv
            for k = context.room.lv + 1, context.room.maxLv do
                local roomLvData = context.roomLvTable[k]
                if roomLvData.stationMaxCount >= index then
                    needLv = k
                    break
                end
            end
            cell.lockedTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_UNLOCK_STATION_HINT, context.roomTypeData.name, needLv)
            cell.simpleStateController:SetState("Locked")
        else
            cell.simpleStateController:SetState("Empty")
            cell.emptyNodeButton.onClick:RemoveAllListeners()
            cell.emptyNodeButton.onClick:AddListener(function()
                self:_OpenStationForEditTeam(context.teamType)
            end)
        end
        return
    end

    cell.simpleStateController:SetState("Normal")
    cell.headCell:InitSSCharHeadCell({
        charId = charId,
        targetRoomId = self.m_roomId,
        onClick = function()
            self:_OpenStationForEditTeam(context.teamType)
        end,
    })
    
    cell.headCell.view.friendshipNode.gameObject:SetActive(self.m_roomId == Tables.spaceshipConst.controlCenterRoomId)

    cell.charSkillNode:InitSSCharSkillNode(charId, self.m_roomId, true)
    table.insert(self.m_skillNodesByTeamType[context.teamType], cell.charSkillNode)
    local warnTextList = self:_BuildCharWarnTextList(charId, context.roomType, context.spaceship)
    self:_RefreshCharWarnCells(cell.warnCells, warnTextList)
end

SpaceshipScheduleCtrl._BuildCharWarnTextList = HL.Method(HL.String, HL.Any, HL.Any).Return(HL.Table) << function(self, charId, roomType, spaceship)
    local warnTextList = {}
    
    local char = spaceship.characters:get_Item(charId)
    if not string.isEmpty(char.stationedRoomId) and char.stationedRoomId ~= self.m_roomId then
        local stationedRoomType = SpaceshipUtils.getRoomTypeByRoomId(char.stationedRoomId)
        local data = Tables.spaceshipRoomTypeTable[stationedRoomType]
        table.insert(warnTextList, {
            state = "InOtherRoom",
            text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_LEAVE_ROOM,
            roomColor = SpaceshipUtils.getRoomColor(char.stationedRoomId),
            roomName = data.name
        })
    end
    if self:_GetValidRoomSkillCount(charId, roomType) == 0 then
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
    return warnTextList
end

SpaceshipScheduleCtrl._RefreshCharWarnCells = HL.Method(HL.Forward('UIListCache'), HL.Table) << function(self, warnCells, warnTextList)
    warnCells:Refresh(#warnTextList, function(warnCell, warnIndex)
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

SpaceshipScheduleCtrl._GetValidRoomSkillCount = HL.Method(HL.String, HL.Any).Return(HL.Number) << function(self, charId, roomType)
    
    local char = self.m_spaceship.characters:get_Item(charId)
    local validSkillCount = 0
    local haveData, charSkillData = Tables.spaceshipCharSkillTable:TryGetValue(charId)
    if not haveData then
        return validSkillCount
    end
    for _, v in pairs(charSkillData.skillList) do
        local skillId = v.skillId
        local skillData = Tables.spaceshipSkillTable[skillId]
        if skillData.roomType == roomType and char.skills:ContainsValue(skillId) then
            validSkillCount = validSkillCount + 1
        end
    end
    return validSkillCount
end

SpaceshipScheduleCtrl._GetEstimatedWorkTimeText = HL.Method(HL.Number).Return(HL.String) << function(self, workSeconds)
    local hours = math.floor(workSeconds / Const.SEC_PER_HOUR)
    local minutes = math.floor((workSeconds % Const.SEC_PER_HOUR) / Const.SEC_PER_MIN)
    return string.format(Language.LUA_SPACESHIP_SCHEDULE_ESTIMATED_WORK_TIME, hours, minutes)
end

SpaceshipScheduleCtrl._GetTeamEstimatedWorkSeconds = HL.Method(HL.Any, HL.Table).Return(HL.Number) << function(self, room, charIdList)
    if #charIdList == 0 then
        return 0
    end
    local costRate = self:_GetTeamStaminaCostRatePerSecond(room, charIdList)
    if costRate <= 0 then
        return 0
    end
    return Tables.spaceshipConst.maxPhysicalStrength / costRate
end

SpaceshipScheduleCtrl._GetTeamStaminaCostRatePerSecond = HL.Method(HL.Any, HL.Table).Return(HL.Number) << function(self, room, charIdList)
    local skillReduceRate = 0
    for _, charId in ipairs(charIdList) do
        local char = self.m_spaceship.characters:get_Item(charId)
        for _, skillId in pairs(char.skills) do
            local skillData = Tables.spaceshipSkillTable[skillId]
            if skillData.roomType == room.type
                    and skillData.effectType == GEnums.SpaceshipStationEffectType.RoomPSCostRateReduceByPercent then
                skillReduceRate = skillReduceRate + skillData.parameters[0].valueFloatList[0]
            end
        end
    end
    local costRatePerMinute = Tables.spaceshipConst.basePhysicalStrengthCostRate * (1 - skillReduceRate)
    return costRatePerMinute / Const.SEC_PER_MIN
end

SpaceshipScheduleCtrl._OnClickDeleteTeam = HL.Method(HL.Any) << function(self, teamType)
    local room = self:_GetRoom()
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local teamLabel = teamType == TeamType.A and "A" or "B"

    local roomName = SpaceshipUtils.getFormatCabinSerialNum(self.m_roomId, room.serialNum)
    local content = string.format(Language.LUA_SPACESHIP_SCHEDULE_DELETE_TEAM_CONFIRM, roomName, teamLabel)

    local curTeam = self.m_spaceship:GetRoomCurrentWorkingTeam(self.m_roomId)
    local isWorkingTeam = curTeam == teamType and #self:_GetScheduleTeamCharIdList(room.schedule, teamType) > 0
    local warningContent = nil
    if isWorkingTeam then
        warningContent = Language.LUA_SPACESHIP_SCHEDULE_DELETE_WORKING_TEAM_WARNING
    end

    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        warningContent = warningContent,
        onConfirm = function()
            self.m_reopenStationAfterModifyTeam = true
            self.m_spaceship:ModifyTeam(self.m_roomId, teamType, false)
        end,
    })
end

SpaceshipScheduleCtrl._OnSetRoomStationSucc = HL.Method(HL.Table) << function(self, _)
    self:_Refresh()
end

SpaceshipScheduleCtrl._OnSyncRoomStation = HL.Method(HL.Opt(HL.Table)) << function(self, _)
    if self.m_reopenStationAfterModifyTeam and SpaceshipUtils.isSingleTeamMode(self.m_roomId) then
        self.m_reopenStationAfterModifyTeam = false
        self:_ReopenStation()
        return
    end
    self:_Refresh()
end

SpaceshipScheduleCtrl._OnEditSchedule = HL.Method(HL.Any) << function(self, arg)
    local roomId = type(arg) == "table" and arg[1] or arg
    if roomId ~= self.m_roomId then
        return
    end
    self.m_isDisablingInvalidAutoSchedule = false
    self:_ResetWorkHourAllocationState(false)
    self:_ClearTimeNowRefreshTimer()
    self:_Refresh(true)
end

SpaceshipScheduleCtrl.OnShow = HL.Override() << function(self)
    if self.m_hasShownSchedulePanel then
        local selectedWorkHourAllocationSlider = self.m_selectedWorkHourAllocationSlider
        self:_Refresh(true)
        if self.m_isEditingWorkHourAllocation and selectedWorkHourAllocationSlider ~= 0 then
            self.m_selectedWorkHourAllocationSlider = selectedWorkHourAllocationSlider
            self:_UpdateWorkHourAllocationSliderVisuals()
        end
    else
        
        self.m_hasShownSchedulePanel = true
    end
end

SpaceshipScheduleCtrl.OnClose = HL.Override() << function(self)
    self:_ClearAutoReminderTimer()
    self:_ClearTimeNowRefreshTimer()
end

HL.Commit(SpaceshipScheduleCtrl)
