
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DebugInputRecord

local AutoTestBridge = CS.Beyond.Scripts.GmCommands.AutoTestBridge
local Color = CS.UnityEngine.Color

local COLOR_SELECTED = Color(1, 1, 0, 1)
local COLOR_DEFAULT = Color(1, 1, 1, 180 / 255)

DebugInputRecordCtrl = HL.Class('DebugInputRecordCtrl', uiCtrl.UICtrl)






DebugInputRecordCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

DebugInputRecordCtrl.m_lateTickKey = HL.Field(HL.Number) << -1

DebugInputRecordCtrl.m_getCell = HL.Field(HL.Function)

DebugInputRecordCtrl.m_lastCount = HL.Field(HL.Number) << 0

DebugInputRecordCtrl.m_isRecordMode = HL.Field(HL.Boolean) << false

DebugInputRecordCtrl.m_selectStart = HL.Field(HL.Number) << 1

DebugInputRecordCtrl.m_selectEnd = HL.Field(HL.Number) << 1

DebugInputRecordCtrl.m_tapCount = HL.Field(HL.Number) << 0


DebugInputRecordCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_getCell = UIUtils.genCachedCellFunction(self.view.recordList)
    self.view.recordList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getCell(obj)
        local index = LuaIndex(csIndex)
        self:_SetupCell(cell)
        self:_RefreshCell(cell, index)
    end)

    self.view.btnRecord.onClick:AddListener(function()
        self:_OnBtnRecordClicked()
    end)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClicked()
    end)

    self.view.btnClose.gameObject:SetActive(false)
    self.view.textBtnRecord.text = "保存"

    self.m_lateTickKey = LuaUpdate:Add("LateTick", function(deltaTime)
        self:_Update()
    end)
end

DebugInputRecordCtrl.OnClose = HL.Override() << function(self)
    if self.m_lateTickKey ~= -1 then
        LuaUpdate:Remove(self.m_lateTickKey)
        self.m_lateTickKey = -1
    end
end

DebugInputRecordCtrl._Update = HL.Method() << function(self)
    if not self.m_isRecordMode then
        local historyCount = InputManagerInst.inputRecordHistory.Count
        local totalCount = 1 + historyCount
        if totalCount > InputManager.INPUT_RECORD_NUM then
            totalCount = InputManager.INPUT_RECORD_NUM
        end

        if totalCount ~= self.m_lastCount then
            self.m_lastCount = totalCount
            self.view.recordList:UpdateCount(totalCount)
        end
    end

    self.view.recordList:UpdateShowingCells(function(csIndex, obj)
        self:_RefreshCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
end

DebugInputRecordCtrl._SetupCell = HL.Method(HL.Any) << function(self, cell)
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:_OnItemClicked(cell._index)
    end)
end

DebugInputRecordCtrl._RefreshCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    cell._index = index

    if index == 1 then
        local current = InputManagerInst.currentPressHistory
        cell.numTxt.text = tostring(current.frameCount)
        cell.nameTxt.text = current:GetShowingString()
    else
        local historyIndex = InputManagerInst.inputRecordHistory.Count - (index - 2)
        local record = InputManagerInst.inputRecordHistory[CSIndex(historyIndex)]
        if record then
            cell.numTxt.text = tostring(record.frameCount)
            cell.nameTxt.text = record:GetShowingString()
        end
    end

    cell.button.interactable = self.m_isRecordMode

    if self.m_isRecordMode and index >= self.m_selectStart and index <= self.m_selectEnd then
        cell.blur.color = COLOR_SELECTED
    else
        cell.blur.color = COLOR_DEFAULT
    end
end

DebugInputRecordCtrl._OnBtnRecordClicked = HL.Method() << function(self)
    if not self.m_isRecordMode then
        self:_EnterRecordMode()
    else
        self:_SaveRecord()
        self:_ExitRecordMode()
    end
end

DebugInputRecordCtrl._OnBtnCloseClicked = HL.Method() << function(self)
    self:_ExitRecordMode()
end

DebugInputRecordCtrl._OnItemClicked = HL.Method(HL.Number) << function(self, index)
    if not self.m_isRecordMode then
        return
    end
    if self.m_tapCount == 0 or self.m_tapCount == 2 then
        self.m_selectStart = index
        self.m_selectEnd = index
        self.m_tapCount = 1
    else
        local a = math.min(self.m_selectStart, index)
        local b = math.max(self.m_selectStart, index)
        self.m_selectStart = a
        self.m_selectEnd = b
        self.m_tapCount = 2
    end
end

DebugInputRecordCtrl._EnterRecordMode = HL.Method() << function(self)
    self.m_isRecordMode = true
    self.m_selectStart = 1
    self.m_selectEnd = self.m_lastCount
    self.m_tapCount = 0
    self.view.textBtnRecord.text = "确认"
    self.view.btnClose.gameObject:SetActive(true)
    InputManagerInst:SetInputRecordEnabled(false)
end

DebugInputRecordCtrl._ExitRecordMode = HL.Method() << function(self)
    self.m_isRecordMode = false
    self.m_tapCount = 0
    self.view.textBtnRecord.text = "保存"
    self.view.btnClose.gameObject:SetActive(false)
    InputManagerInst:SetInputRecordEnabled(true)
end

DebugInputRecordCtrl._SaveRecord = HL.Method() << function(self)
    local historyCount = InputManagerInst.inputRecordHistory.Count
    if historyCount == 0 then
        return
    end

    local effectiveStart = math.max(self.m_selectStart, 2)
    local effectiveEnd = self.m_selectEnd
    if effectiveStart > effectiveEnd then
        return
    end

    local csStartIndex = historyCount - effectiveEnd + 1
    local csEndIndex = historyCount - effectiveStart + 1

    if csStartIndex < 0 then csStartIndex = 0 end
    if csEndIndex >= historyCount then csEndIndex = historyCount - 1 end

    local fileName = os.date("%Y%m%d%H%M%S")
    local success = AutoTestBridge.SaveInputRecord(csStartIndex, csEndIndex, fileName)
    if success then
        Notify(MessageConst.SHOW_TOAST, "已保存: " .. fileName)
    end
end

DebugInputRecordCtrl.OnToggleDebugInputRecord = HL.StaticMethod(HL.Table) << function(arg)
    local show = arg and arg[1]
    local isShowing = UIManager:IsShow(PANEL_ID)
    if isShowing and not show then
        UIManager:Close(PANEL_ID)
    elseif not isShowing and show then
        UIManager:AutoOpen(PANEL_ID, arg)
    end
end

HL.Commit(DebugInputRecordCtrl)
