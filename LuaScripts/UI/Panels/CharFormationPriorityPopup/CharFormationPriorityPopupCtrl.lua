local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharFormationPriorityPopup

local INSTRUCTION_TEXT_ID = "char_formation_combo_skill_priority"

CharFormationPriorityPopupCtrl = HL.Class('CharFormationPriorityPopupCtrl', uiCtrl.UICtrl)

CharFormationPriorityPopupCtrl.m_roleCellCache = HL.Field(HL.Forward("UIListCache"))

CharFormationPriorityPopupCtrl.m_hoverTarget = HL.Field(GameObject)

CharFormationPriorityPopupCtrl.m_hoverDropItem = HL.Field(HL.Userdata)

CharFormationPriorityPopupCtrl.m_saveCallback = HL.Field(HL.Function)


CharFormationPriorityPopupCtrl.m_teamCharList = HL.Field(HL.Table)


CharFormationPriorityPopupCtrl.m_preComboSkillCharList = HL.Field(HL.Table)


CharFormationPriorityPopupCtrl.m_comboSkillCharList = HL.Field(HL.Table)


CharFormationPriorityPopupCtrl.m_isInSelectionMode = HL.Field(HL.Boolean) << false
CharFormationPriorityPopupCtrl.m_controllerSelectedCellIndex = HL.Field(HL.Number) << 0
CharFormationPriorityPopupCtrl.m_enterSelectionBindingId = HL.Field(HL.Number) << -1
CharFormationPriorityPopupCtrl.m_confirmBindingId = HL.Field(HL.Number) << -1
CharFormationPriorityPopupCtrl.m_cancelBindingId = HL.Field(HL.Number) << -1






CharFormationPriorityPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CharFormationPriorityPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    arg = arg or {}

    local team = arg.team or {}
    local comboSkillOrder = arg.comboSkillOrder
    self.m_saveCallback = arg.saveCallback

    
    self:_InitBtnBinding()
    self:_InitController()
    self:_SetIntroText()

    
    self.m_teamCharList = {}
    for _, charInfo in ipairs(team) do
        table.insert(self.m_teamCharList, charInfo.charInstId)
    end
    self.m_comboSkillCharList = {}
    self.m_preComboSkillCharList = {}
    if comboSkillOrder and type(comboSkillOrder) == "userdata" then
        for i = 0, comboSkillOrder.Count - 1 do
            local charInstId = comboSkillOrder[i]
            if charInstId then
                table.insert(self.m_comboSkillCharList, charInstId)
                table.insert(self.m_preComboSkillCharList, charInstId)
            end
        end
    end
    self.view.toggle:SetIsOnWithoutNotify(#self.m_comboSkillCharList > 0)

    
    
    local recoverState = arg.recoverState
    if recoverState then
        if recoverState.teamCharList then
            self.m_teamCharList = { table.unpack(recoverState.teamCharList) }
        end
        if recoverState.toggleIsOn ~= nil then
            self.view.toggle:SetIsOnWithoutNotify(recoverState.toggleIsOn)
        end
        if recoverState.comboSkillCharList then
            self.m_comboSkillCharList = { table.unpack(recoverState.comboSkillCharList) }
        end
        if recoverState.preComboSkillCharList then
            self.m_preComboSkillCharList = { table.unpack(recoverState.preComboSkillCharList) }
        end
        arg.recoverState = nil
    end

    self:_UpdateUiState()
    self:_UpdateEnterSelectionBindingState()
    if DeviceInfo.usingController and self.view.toggle.isOn then
        self:_SetNaviTarget()
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end





CharFormationPriorityPopupCtrl.OnClose = HL.Override() << function(self)
    if self.m_isInSelectionMode then
        self:_ExitSelectionMode()
    end
    if self.m_confirmBindingId > 0 then
        InputManagerInst:DeleteBinding(self.m_confirmBindingId)
        self.m_confirmBindingId = -1
    end
    if self.m_cancelBindingId > 0 then
        InputManagerInst:DeleteBinding(self.m_cancelBindingId)
        self.m_cancelBindingId = -1
    end
end

CharFormationPriorityPopupCtrl._UpdateUiState = HL.Method() << function(self)
    self:_RefreshRoleCells()

    self:UpdateDragAreaState()
    self:UpdateBtnState()
end

CharFormationPriorityPopupCtrl._SetIntroText = HL.Method() << function(self)
    local succ, data = Tables.instructionBook:TryGetValue(INSTRUCTION_TEXT_ID)
    if succ then
        self.view.descTxt:SetAndResolveTextStyle(data.content)
    else
        self.view.descTxt.text = ""
    end
end

CharFormationPriorityPopupCtrl.UpdateDragAreaState = HL.Method() << function(self)
    local useCustom = self.view.toggle.isOn
    
    self.view.dragAreaStateController:SetState(useCustom and "Normal" or "Lock")
    if DeviceInfo.usingController then
        self.view.dragAreaStateController:SetState("Controller")
    elseif DeviceInfo.usingKeyboard then
        self.view.dragAreaStateController:SetState("Keyboard")
    elseif DeviceInfo.usingTouch then
        self.view.dragAreaStateController:SetState("Touch")
    end
end

CharFormationPriorityPopupCtrl.UpdateBtnState = HL.Method() << function(self)
    local canEdit = self.view.toggle.isOn
    self.view.recoverBtn.interactable = canEdit
end

CharFormationPriorityPopupCtrl._InitBtnBinding = HL.Method() << function(self)
    self.view.closeButton.onClick:AddListener(function()
        self:_TryClosePanel()
    end)

    self.view.recoverBtn.onClick:AddListener(function()
        self:_ResetComboSkillOrder(true)
        self:_UpdateUiState()
    end)

    self.view.saveBtn.onClick:AddListener(function()
        if self.m_saveCallback and type(self.m_saveCallback) == "function" then
            self.m_saveCallback(self.m_comboSkillCharList)
        end

        UIManager:Close(PANEL_ID)
    end)

    self.view.toggle.onValueChanged:AddListener(function(isOn)
        self:_ResetComboSkillOrder(isOn)
        if not isOn then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_TEAM_COMBO_SKILL_RESET_TOAST)
        end

        self:_UpdateUiState()
        self:_UpdateEnterSelectionBindingState()
        self:_SetNaviTarget()
    end)

    self.view.bgMask.onClick:AddListener(function()
        self:_TryClosePanel()
    end)
end

CharFormationPriorityPopupCtrl._ShowCloseConfirm = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_TEAM_COMBO_SKILL_SAVE_CONFIRM,
        onConfirm = function()
            self:PlayAnimationOutAndClose()
        end,
    })
end

CharFormationPriorityPopupCtrl._TryClosePanel = HL.Method().Return(HL.Boolean) << function(self)
    if #self.m_comboSkillCharList ~= #self.m_preComboSkillCharList then
        self:_ShowCloseConfirm()
        return false
    end

    for i = 1, #self.m_comboSkillCharList do
        if self.m_comboSkillCharList[i] ~= self.m_preComboSkillCharList[i] then
            self:_ShowCloseConfirm()
            return false
        end
    end

    self:PlayAnimationOutAndClose()
    return true
end

CharFormationPriorityPopupCtrl._ResetComboSkillOrder = HL.Method(HL.Boolean) << function(self, init)
    if init then
        self.m_comboSkillCharList = { table.unpack(self.m_teamCharList) }
    else
        self.m_comboSkillCharList = {}
    end
end

CharFormationPriorityPopupCtrl.GetCurList = HL.Method().Return(HL.Table) << function(self)
    if self.view.toggle.isOn then
        return self.m_comboSkillCharList
    else
        return self.m_teamCharList
    end    
end

CharFormationPriorityPopupCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        toggleIsOn = self.view.toggle.isOn,
        teamCharList = { table.unpack(self.m_teamCharList) },
        comboSkillCharList = { table.unpack(self.m_comboSkillCharList) },
        preComboSkillCharList = { table.unpack(self.m_preComboSkillCharList) },
    }
end


CharFormationPriorityPopupCtrl._RefreshRoleCells = HL.Method() << function(self)
    self.m_roleCellCache = self.m_roleCellCache or UIUtils.genCellCache(self.view.itemRoleCell)
    local curList = self:GetCurList()
    self.m_roleCellCache:Refresh(#curList, function(cell, index)
        local charInstId = curList[index]
        self:SetRoleHead(cell, charInstId, index)
        self:_InitCellDragDrop(cell, index)

        cell.roleBtn.onIsNaviTargetChanged = function(isNaviTarget)
            if not self.m_isInSelectionMode then
                return
            end

            self:_SetSelectionModeRoleState(cell, index, isNaviTarget)
        end
        
        local isInteractable = self.view.toggle.isOn
        cell.hoverNode.interactable = isInteractable
    end)
end



CharFormationPriorityPopupCtrl._InitCellDragDrop = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    cell.roleCellState:SetState("Normal")

    
    
    local dragItem = cell.dragItem
    local dropItem = cell.dropItem
    if not dragItem or not dropItem then
        return
    end

    
    dragItem:ClearEvents()
    dropItem:ClearEvents()

    
    dragItem.luaTable = { index = index, formationPriority = true }
    dropItem.luaTable = { index = index, formationPriority = true }
    dragItem.enabled = self.view.toggle.isOn

    dragItem.onBeginDragEvent:AddListener(function(eventData)
        self:_ClearDragState()
    end)

    dragItem.onEndDragEvent:AddListener(function(eventData)
        self:_ClearDragState()
    end)

    dragItem.onDragEvent:AddListener(function(eventData)
        self:_OnDraging(eventData)
    end)

    dragItem.onUpdateDragObject:AddListener(function(dragObj, sourceObj)
        local luaNode = Utils.wrapLuaNode(dragObj)
        local curList = self:GetCurList()
        self:SetRoleHead(luaNode, curList[index])
    end)

    dropItem.onDropEvent:AddListener(function(eventData)
        self:_OnDropOnCell(index, eventData)
    end)
end

CharFormationPriorityPopupCtrl.SetRoleHead = HL.Method(HL.Any, HL.Number, HL.Opt(HL.Number)) << function(self, cell, charInstId, index)
    local skillIcon = CharInfoUtils.getSkillGroupDisplayIcon(charInstId, GEnums.SkillGroupType.ComboSkill)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local charId = charInst.templateId
    cell.gameObject.name = charId
    cell.skillImg:LoadSprite(UIConst.UI_SPRITE_SKILL_ICON, skillIcon)
    cell.charHeadImg:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. charId)
    if index then
        cell.slotNumTxt.gameObject:SetActive(true)
        cell.bgSlot.gameObject:SetActive(true)
        cell.slotNumTxt.text = tostring(index)
    else
        cell.bgSlot.gameObject:SetActive(false)
        cell.slotNumTxt.gameObject:SetActive(false)
    end
end


CharFormationPriorityPopupCtrl._OnDraging = HL.Method(HL.Any) << function(self, eventData)
    local hoverObj = eventData.pointerEnter

    if self.m_hoverTarget ~= hoverObj then
        local dropItem = nil
        if NotNull(hoverObj) then 
            dropItem = hoverObj:GetComponentInParent(typeof(CS.Beyond.UI.UIDropItem))
            if dropItem ~= self.m_hoverDropItem then
                self:_ClearDragState()
            end
        end
        
        self.m_hoverTarget = hoverObj

        if dropItem and dropItem.luaTable and dropItem.luaTable.formationPriority then
            self.m_hoverDropItem = dropItem
            dropItem:ToggleHighlight(true)
        end
    end
end


CharFormationPriorityPopupCtrl._OnDropOnCell = HL.Method(HL.Number, CS.UnityEngine.EventSystems.PointerEventData) << function(self, targetIndex, eventData)
    if not self.view.toggle.isOn then
        return
    end

    if IsNull(eventData.pointerDrag) then
        return
    end
    local dragItem = eventData.pointerDrag:GetComponent(typeof(CS.Beyond.UI.UIDragItem))
    if dragItem and dragItem.inDragging and dragItem.luaTable then
        local fromIndex = dragItem.luaTable.index
        if fromIndex and fromIndex ~= targetIndex then
            
            self:_DoSwap(fromIndex, targetIndex)
        end
    end
end

CharFormationPriorityPopupCtrl._ClearDragState = HL.Method() << function(self)
    self.m_hoverTarget = nil

    if self.m_hoverDropItem then
        self.m_hoverDropItem:ToggleHighlight(false)
    end
    self.m_hoverDropItem = nil
end

CharFormationPriorityPopupCtrl._DoSwap = HL.Method(HL.Number, HL.Number) << function(self, fromIndex, toIndex)
    if fromIndex and toIndex and fromIndex ~= toIndex then
        self.m_comboSkillCharList[fromIndex], self.m_comboSkillCharList[toIndex] = self.m_comboSkillCharList[toIndex], self.m_comboSkillCharList[fromIndex]
        self:_UpdateUiState()

        AudioAdapter.PostEvent("Au_UI_Button_Equip")
    end
end



CharFormationPriorityPopupCtrl._SetNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    if not self.view.toggle.isOn then
        self:ClearNaviTarget()
        return
    end
    local firstCell = self.m_roleCellCache and self.m_roleCellCache:GetItem(1)
    if firstCell and firstCell.roleBtn then
        self:SetNaviTarget(firstCell.roleBtn)
    end
end

CharFormationPriorityPopupCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.m_enterSelectionBindingId = self:BindInputPlayerAction("char_formation_change_combo_index", function()
        self:_EnterSelectionMode()
    end)
    
    InputManagerInst:ToggleBinding(self.m_enterSelectionBindingId, false)

    self.m_confirmBindingId = InputManagerInst:CreateBindingByActionId("char_formation_do_change_combo_index", function()
        self:_ConfirmSelection()
    end, self.view.roleInputGroup.groupId)

    self.m_cancelBindingId = InputManagerInst:CreateBindingByActionId("char_formation_stop_change_combo_index", function()
        self:_ExitSelectionMode()
    end, self.view.roleInputGroup.groupId)

    InputManagerInst:ToggleBinding(self.m_confirmBindingId, false)
    InputManagerInst:ToggleBinding(self.m_cancelBindingId, false)
end


CharFormationPriorityPopupCtrl._UpdateEnterSelectionBindingState = HL.Method() << function(self)
    if self.m_enterSelectionBindingId > 0 then
        InputManagerInst:ToggleBinding(self.m_enterSelectionBindingId, self.view.toggle.isOn)
    end
end

CharFormationPriorityPopupCtrl._EnterSelectionMode = HL.Method() << function(self)
    if self.m_isInSelectionMode then
        return
    end
    if not self.view.toggle.isOn then
        return
    end

    local selectedIndex = self:_GetCurrentNaviCellIndex()
    if selectedIndex <= 0 then
        return
    end

    self.m_controllerSelectedCellIndex = selectedIndex
    self.m_isInSelectionMode = true

    local cell = self.m_roleCellCache:GetItem(selectedIndex)
    if cell then
        self:_SetSelectionModeRoleState(cell, selectedIndex, true)
    end

    
    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
        panelId = PANEL_ID,
        isGroup = true,
        id = self.view.roleInputGroup.groupId,
        rectTransform = self.view.roleNaviGroup.transform,
        noHighlight = true,
        useNormalFrame = true,
        hintPlaceholder = self.view.controllerHintPlaceholder,
    })

    InputManagerInst:ToggleBinding(self.m_enterSelectionBindingId, false)
    InputManagerInst:ToggleBinding(self.m_confirmBindingId, true)
    InputManagerInst:ToggleBinding(self.m_cancelBindingId, true)
end

CharFormationPriorityPopupCtrl._ExitSelectionMode = HL.Method() << function(self)
    if not self.m_isInSelectionMode then
        return
    end

    local cell = self.m_roleCellCache:GetItem(self.m_controllerSelectedCellIndex)
    if cell then
        cell.roleCellState:SetState("Normal")
        cell.roleCellState:SetState("Mask")
    end

    
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.roleInputGroup.groupId)

    InputManagerInst:ToggleBinding(self.m_confirmBindingId, false)
    InputManagerInst:ToggleBinding(self.m_cancelBindingId, false)
    self:_UpdateEnterSelectionBindingState()

    self.m_controllerSelectedCellIndex = 0
    self.m_isInSelectionMode = false

    self:_UpdateUiState()
end

CharFormationPriorityPopupCtrl._ConfirmSelection = HL.Method() << function(self)
    local sourceIndex = self.m_controllerSelectedCellIndex
    if sourceIndex <= 0 then
        self:_ExitSelectionMode()
        return
    end

    local curIndex = self:_GetCurrentNaviCellIndex()

    self:_DoSwap(sourceIndex, curIndex)

    self:_ExitSelectionMode()
    self:_UpdateUiState()
end

CharFormationPriorityPopupCtrl._GetCurrentNaviCellIndex = HL.Method().Return(HL.Number) << function(self)
    local count = self.m_roleCellCache:GetCount()
    for i = 1, count do
        local cell = self.m_roleCellCache:GetItem(i)
        if cell and cell.roleBtn and cell.roleBtn.isNaviTarget then
            return i
        end
    end
    return 0
end

CharFormationPriorityPopupCtrl._SetSelectionModeRoleState = HL.Method(HL.Any, HL.Number, HL.Boolean) << function(self, cell, index, isTargeting)
    if not cell then
        return
    end

    cell.roleCellState:SetState("Normal")

    if self.m_controllerSelectedCellIndex == index then
        cell.roleCellState:SetState("Mask")
        cell.roleCellState:SetState("Selected")
    end

    if isTargeting then
        cell.roleCellState:SetState("Arrow")
    end
end



HL.Commit(CharFormationPriorityPopupCtrl)
