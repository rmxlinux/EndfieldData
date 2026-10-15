
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

ActivityDescriptionPopupCtrl = HL.Class('ActivityDescriptionPopupCtrl', uiCtrl.UICtrl)

ActivityDescriptionPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
}

ActivityDescriptionPopupCtrl.m_phaseList = HL.Field(HL.Any)

ActivityDescriptionPopupCtrl.m_getCalendarCell = HL.Field(HL.Function)

ActivityDescriptionPopupCtrl.m_onClose = HL.Field(HL.Any) << nil

ActivityDescriptionPopupCtrl.m_activityId = HL.Field(HL.String) << ''


ActivityDescriptionPopupCtrl.m_curTab = HL.Field(HL.String) << ''


ActivityDescriptionPopupCtrl.m_timeRefreshCor = HL.Field(HL.Thread)

ActivityDescriptionPopupCtrl.m_curPhaseIndex = HL.Field(HL.Number) << 0

ActivityDescriptionPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local activityId = arg and arg.activityId
    if string.isEmpty(activityId) then
        logger.error('ActivityDescriptionPopup: missing activityId')
        self:Close()
        return
    end
    self.m_onClose = arg.onClose
    self.m_activityId = activityId

    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    local hasData, activityData = Tables.activityTable:TryGetValue(activityId)
    if not hasData or not activity then
        logger.error('ActivityDescriptionPopup: activity not found %s', activityId)
        self:Close()
        return
    end

    self.m_phaseList = self:_CollectStagePhaseList(activityId)

    self.view.btnClose.onClick:AddListener(function() self:_Close() end)
    self.view.maskBtn.onClick:AddListener(function() self:_Close() end)
    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    end

    
    local descContent, title = self:_LoadInstructionContent(activityData.instructionId)
    self.view.descriptionTxt:SetAndResolveTextStyle(descContent)
    

    if activity.endTime == 0 then
        self.view.residentNode.gameObject:SetActive(not ActivityUtils.isActivityRecommended(activityData))
        self.view.titleStateController:SetState('TopTittleNode')
        self.view.mainStateController:SetState('Instruction')
        self.m_curTab = 'Instruction'
    else
        self.view.residentNode.gameObject:SetActive(false)
        self:_SetupTimedLayout(arg.initTab)
    end
end

ActivityDescriptionPopupCtrl.OnClose = HL.Override() << function(self)
    self.m_timeRefreshCor = self:_ClearCoroutine(self.m_timeRefreshCor)
    if self.m_onClose ~= nil then
        self.m_onClose()
    end
end

ActivityDescriptionPopupCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId == self.m_activityId and not GameInstance.player.activitySystem:GetActivity(activityId) then
        self:_Close()
    end
end

ActivityDescriptionPopupCtrl._Close = HL.Method() << function(self)
    if self.view.animationWrapper then
        self.view.animationWrapper:PlayOutAnimation(function()
            self:Close()
        end)
    else
        self:Close()
    end
end

ActivityDescriptionPopupCtrl._LoadInstructionContent = HL.Method(HL.Opt(HL.String)).Return(HL.String, HL.String) << function(self, instructionId)
    if string.isEmpty(instructionId) then
        return ""
    end
    local hasData, data = Tables.instructionBook:TryGetValue(instructionId)
    if not hasData then
        return instructionId
    end
    return data.content, data.title
end

ActivityDescriptionPopupCtrl._SetupTimedLayout = HL.Method(HL.Opt(HL.String)) << function(self, initTab)

    local hasCalendarData = self.m_phaseList ~= nil and #self.m_phaseList > 0
    if hasCalendarData then
        self.view.titleStateController:SetState('TopTittleNodeCalendar')
        self.m_getCalendarCell = UIUtils.genCachedCellFunction(self.view.calendarScrollList)
        self.view.calendarScrollList.onUpdateCell:AddListener(function(obj, csIndex)
            self:_OnUpdateCalendarCell(obj, csIndex)
        end)
        self.view.calendarScrollList:UpdateCount(#self.m_phaseList)
        
        self.m_curPhaseIndex = self:_GetCurPhaseIndex()
        self.m_timeRefreshCor = self:_ClearCoroutine(self.m_timeRefreshCor)
        self.m_timeRefreshCor = self:_StartCoroutine(function()
            while true do
                coroutine.wait(1)
                self:_CheckCalendarTimeCross()
            end
        end)
        self.view.toggleInstruction.onValueChanged:RemoveAllListeners()
        self.view.toggleInstruction.onValueChanged:AddListener(function(isOn)
            if isOn then
                self.m_curTab = 'Instruction'
                self.view.mainStateController:SetState('Instruction')
            end
        end)
        self.view.toggleCalendar.onValueChanged:RemoveAllListeners()
        self.view.toggleCalendar.onValueChanged:AddListener(function(isOn)
            if isOn then
                self.m_curTab = 'Calendar'
                self.view.mainStateController:SetState('Calendar')
            end
        end)

        
        if initTab == 'Calendar' then
            self.m_curTab = 'Calendar'
            self.view.toggleCalendar:SetIsOnWithoutNotify(true)
            self.view.mainStateController:SetState('Calendar')
        else
            self.m_curTab = 'Instruction'
            self.view.toggleInstruction:SetIsOnWithoutNotify(true)
            self.view.mainStateController:SetState('Instruction')
        end
    else
        self.m_curTab = 'Instruction'
        self.view.titleStateController:SetState('TopTittleNode')
        self.view.mainStateController:SetState('Instruction')
    end
end


ActivityDescriptionPopupCtrl.GetRestoreArg = HL.Method().Return(HL.Table) << function(self)
    return {
        activityId = self.m_activityId,
        initTab = self.m_curTab,
    }
end

ActivityDescriptionPopupCtrl._CollectStagePhaseList = HL.Method(HL.String).Return(HL.Table) << function(self, activityId)
    local phaseList = {}
    local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(activityId)
    if not haveCfg then
        return phaseList
    end

    local hasDisplayCfg, displayCfg = Tables.activityAchievementDataTable:TryGetValue(activityId)
    if not hasDisplayCfg or not displayCfg.showCalendar then
        return phaseList
    end

    for _, stageCfg in pairs(multiStageCfg.stageList) do
        if stageCfg.hideInCalendar ~= true then
            table.insert(phaseList, stageCfg)
        end
    end
    table.sort(phaseList, function(a, b)
        return a.sortId < b.sortId
    end)
    return phaseList
end


ActivityDescriptionPopupCtrl._GetStageName = HL.Method(HL.Number).Return(HL.String) << function(self, index)
    if index < 1 or index > 10 then
        return ""
    end
    return Language["LUA_ACTIVITY_STAGE_" .. index]
end

ActivityDescriptionPopupCtrl._OnUpdateCalendarCell = HL.Method(HL.Any, HL.Number) << function(self, obj, csIndex)
    local cell = self.m_getCalendarCell(obj)
    local luaIndex = LuaIndex(csIndex)
    local phase = self.m_phaseList[luaIndex]
    if not phase then
        return
    end
    cell.phaseTxt:SetAndResolveTextStyle(self:_GetStageName(luaIndex))
    cell.descriptionTxt:SetAndResolveTextStyle(phase.phaseDesc)
    local timeId = ActivityUtils.getStageShowTimeId(phase)
    cell.timeText.text = self:_FormatPhaseTimeRange(timeId)
    local opened = self:_IsPhaseOpened(timeId)
    cell.nodeStateController:SetState(opened and 'Normal' or 'Lock')
    if cell.lineNode then
        cell.lineNode.gameObject:SetActive(luaIndex < #self.m_phaseList)
    end
end


ActivityDescriptionPopupCtrl._IsPhaseOpened = HL.Method(HL.String).Return(HL.Boolean) << function(self, timeId)
    if string.isEmpty(timeId) then
        return true
    end
    local openTs = Utils.getTimeIdOpenTimeStamp(timeId)
    return openTs ~= nil and DateTimeUtils.GetCurrentTimestampBySeconds() >= openTs
end


ActivityDescriptionPopupCtrl._GetCurPhaseIndex = HL.Method().Return(HL.Number) << function(self)
    local curIndex = 0
    for i, phase in ipairs(self.m_phaseList) do
        if self:_IsPhaseOpened(ActivityUtils.getStageShowTimeId(phase)) then
            curIndex = i
        end
    end
    return curIndex
end

ActivityDescriptionPopupCtrl._CheckCalendarTimeCross = HL.Method() << function(self)
    local curIndex = self:_GetCurPhaseIndex()
    if curIndex ~= self.m_curPhaseIndex then
        self.m_curPhaseIndex = curIndex
        self.view.calendarScrollList:UpdateShowingCells(function(csIndex, obj)
            self:_OnUpdateCalendarCell(obj, csIndex)
        end)
    end
end

ActivityDescriptionPopupCtrl._FormatPhaseTimeRange = HL.Method(HL.String).Return(HL.String) << function(self, timeId)
    if string.isEmpty(timeId) then
        return ""
    end
    local hasCfg, timeCfg = Tables.timeRangeTable:TryGetValue(timeId)
    if not hasCfg then
        return ""
    end
    local serverAreaTypeIndex = CSIndex(Utils.getServerAreaType():GetHashCode())
    if serverAreaTypeIndex < 0 or serverAreaTypeIndex >= timeCfg.timeRangeList.Count then
        return ""
    end
    local timeRange = timeCfg.timeRangeList[serverAreaTypeIndex]
    local timeZoneSeconds = Utils.getServerTimeZoneOffsetSeconds()
    local openStr = Utils.appendUTC(Utils.timestampToDateMDHM(Utils.timeStr2TimeStamp(timeRange.openTime, timeZoneSeconds)))
    if string.isEmpty(timeRange.closeTime) then
        return openStr
    end
    local closeStr = Utils.appendUTC(Utils.timestampToDateMDHM(Utils.timeStr2TimeStamp(timeRange.closeTime, timeZoneSeconds)))

    
    if timeId == "time_activity_timelimited_inn_stage_2calendar" or timeId == "time_activity_contingency_contract_1_stage_2calendar" then
        closeStr = Language.LUA_ACTIVITY_VESION_END_DESC
    end

    


    return string.format("%s - %s", openStr, closeStr)
end

HL.Commit(ActivityDescriptionPopupCtrl)
