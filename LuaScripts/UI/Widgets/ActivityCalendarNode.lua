local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityCalendarNode = HL.Class('ActivityCalendarNode', UIWidgetBase)

ActivityCalendarNode.m_progressNodeCache = HL.Field(HL.Forward("UIListCache"))

ActivityCalendarNode.m_cor = HL.Field(HL.Thread)

ActivityCalendarNode.m_activityId = HL.Field(HL.String) << ""

ActivityCalendarNode.m_nextOpenTime = HL.Field(HL.Number) << -1


ActivityCalendarNode._OnFirstTimeInit = HL.Override() << function(self)
    
end

ActivityCalendarNode.InitActivityCalendarNode = HL.Method(HL.String) << function(self, activityId)
    self:_FirstTimeInit()

    self.m_progressNodeCache = self.m_progressNodeCache or UIUtils.genCellCache(self.view.activityProgressCell)

    activityId = activityId or ""
    self.m_activityId = activityId
    local haveCfg, multiStageCfg = Tables.activityConditionalMultiStageTable:TryGetValue(activityId)
    if not haveCfg then
        self.m_nextOpenTime = -1
        self.m_cor = self:_ClearCoroutine(self.m_cor)
        self.view.timeTxt.text = ""
        self.m_progressNodeCache:Refresh(0)
        return
    end

    local stages = {}
    for stageId, stageCfg in pairs(multiStageCfg.stageList) do
        if stageCfg.hideInCalendar ~= true then
            table.insert(stages, { stageId = stageId, cfg = stageCfg })
        end
    end
    table.sort(stages, function(a, b) return a.cfg.sortId < b.cfg.sortId end)

    local count = #stages
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local openFlags = {}
    local nextOpenTime = nil        
    for i = 1, count do
        local openTime = Utils.getTimeIdOpenTimeStamp(ActivityUtils.getStageShowTimeId(stages[i].cfg))
        local isOpen = openTime ~= nil and curTime >= openTime
        openFlags[i] = isOpen
        if not isOpen and nextOpenTime == nil then
            nextOpenTime = openTime
        end
    end

    self.m_nextOpenTime = nextOpenTime or -1

    self.m_progressNodeCache:Refresh(math.max(count - 1, 0), function(cell, luaIndex)
        cell:InitActivityProgressCell(openFlags[luaIndex], openFlags[luaIndex + 1])
    end)

    
    self:_UpdateTimeText()
    self.m_cor = self:_ClearCoroutine(self.m_cor)
    if nextOpenTime ~= nil then
        self.m_cor = self:_StartCoroutine(function()
            while true do
                coroutine.wait(1)
                self:_UpdateTimeText()
            end
        end)
    end

    
    if DeviceInfo.usingController then
        self.view.calendarIconButton.gameObject:SetActive(false)
    else
        self.view.calendarIconButton.onClick:RemoveAllListeners()
        self.view.calendarIconButton.onClick:AddListener(function()
            ActivityUtils.openDescriptionPopup(activityId, "Calendar") 
        end) 
        self.view.calendarIconButton.gameObject:SetActive(true)
    end
end


ActivityCalendarNode._UpdateTimeText = HL.Method() << function(self)
    if self.m_nextOpenTime < 0 then
        self.view.timeTxt.text = Language.LUA_ACTIVITY_NO_NEXT_PHASE
        self.m_cor = self:_ClearCoroutine(self.m_cor)
        return
    end
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local leftTime = self.m_nextOpenTime - curTime
    if leftTime <= 0 then
        
        self:InitActivityCalendarNode(self.m_activityId)
        return
    end
    self.view.timeTxt.text = string.format(Language.LUA_ACTIVITY_NEXT_PHASE_TEXT, UIUtils.getLeftTime(leftTime))
end

HL.Commit(ActivityCalendarNode)
return ActivityCalendarNode

