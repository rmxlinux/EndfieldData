
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

    local _, calData = Tables.activityCalendarTable:TryGetValue(activityId)
    self.m_phaseList = calData and calData.phaseList or nil

    self.view.btnClose.onClick:AddListener(function() self:_Close() end)
    self.view.maskBtn.onClick:AddListener(function() self:_Close() end)
    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    end

    
    local descContent, title = self:_LoadInstructionContent(activityData.instructionId)
    self.view.descriptionTxt:SetAndResolveTextStyle(descContent)
    

    if activity.endTime == 0 then
        self.view.residentNode.gameObject:SetActive(not activityData.isRecommend)
        self.view.titleStateController:SetState('TopTittleNode')
        self.view.mainStateController:SetState('Instruction')
        self.m_curTab = 'Instruction'
    else
        self.view.residentNode.gameObject:SetActive(false)
        self:_SetupTimedLayout(arg.initTab)
    end
end

ActivityDescriptionPopupCtrl.OnClose = HL.Override() << function(self)
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

    local hasCalendarData = self.m_phaseList ~= nil and self.m_phaseList.Count > 0
    if hasCalendarData then
        self.view.titleStateController:SetState('TopTittleNodeCalendar')
        self.m_getCalendarCell = UIUtils.genCachedCellFunction(self.view.calendarScrollList)
        self.view.calendarScrollList.onUpdateCell:AddListener(function(obj, csIndex)
            self:_OnUpdateCalendarCell(obj, csIndex)
        end)
        self.view.calendarScrollList:UpdateCount(self.m_phaseList.Count)
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

ActivityDescriptionPopupCtrl._OnUpdateCalendarCell = HL.Method(HL.Any, HL.Number) << function(self, obj, csIndex)
    local cell = self.m_getCalendarCell(obj)
    local luaIndex = LuaIndex(csIndex)
    local phase = self.m_phaseList[CSIndex(luaIndex)]
    if not phase then
        return
    end
    cell.phaseTxt:SetAndResolveTextStyle(phase.phaseName)
    cell.descriptionTxt:SetAndResolveTextStyle(phase.phaseDesc)
    cell.timeText.text = self:_FormatPhaseTimeRange(phase.timeId)
    local unlocked = Utils.isCurTimeInTimeIdRange(phase.timeId)
    cell.nodeStateController:SetState(unlocked and 'Normal' or 'Lock')
    if cell.lineNode then
        cell.lineNode.gameObject:SetActive(luaIndex < self.m_phaseList.Count)
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
    return string.format("%s - %s", openStr, closeStr)
end

HL.Commit(ActivityDescriptionPopupCtrl)
