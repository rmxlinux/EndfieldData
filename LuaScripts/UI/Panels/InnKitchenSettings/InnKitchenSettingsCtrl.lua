local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnKitchenSettings
local PHASE_ID = PhaseId.InnKitchenSettings


InnKitchenSettingsCtrl = HL.Class('InnKitchenSettingsCtrl', uiCtrl.UICtrl)

local DUTY_TOAST_KEY_MAP = {
    [GEnums.JsspsiDutyType.ServeDish]  = { open = "LUA_INN_OWNER_SKILL_OPEN_TOAST_SERVE_DISH",  close = "LUA_INN_OWNER_SKILL_CLOSE_TOAST_SERVE_DISH" },
    [GEnums.JsspsiDutyType.ServeDrink] = { open = "LUA_INN_OWNER_SKILL_OPEN_TOAST_SERVE_DRINK", close = "LUA_INN_OWNER_SKILL_CLOSE_TOAST_SERVE_DRINK" },
    [GEnums.JsspsiDutyType.Checkout]   = { open = "LUA_INN_OWNER_SKILL_OPEN_TOAST_CHECKOUT",   close = "LUA_INN_OWNER_SKILL_CLOSE_TOAST_CHECKOUT" },
}







InnKitchenSettingsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_TOPIC_SETTING_CHANGED] = '_OnTopicSettingChanged',
    [MessageConst.ON_INN_KITCHEN_CHAR_SELECTION_SAVED] = '_OnKitchenCharSelectionSaved',
    [MessageConst.ON_INN_DAILY_FASHION_CHANGED] = '_OnInnDailyFashionChanged',
}

InnKitchenSettingsCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)

InnKitchenSettingsCtrl.m_topicId = HL.Field(HL.String) << ""


InnKitchenSettingsCtrl.m_kitchenUnlockLevels = HL.Field(HL.Table)


InnKitchenSettingsCtrl.m_dutyRows = HL.Field(HL.Table)

InnKitchenSettingsCtrl.m_kitchenCellCache = HL.Field(HL.Forward('UIListCache'))

InnKitchenSettingsCtrl.m_skillCellCache = HL.Field(HL.Forward('UIListCache'))



InnKitchenSettingsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player and GameInstance.player.innSystem
    self.m_topicId = (arg and arg.topicId) or ""

    if self.m_innSystem then
        self.m_innSystem:TryAutoFillKitchenSettings(self.m_topicId)
        self.m_innSystem:TryAutoFillAutoDuty(self.m_topicId)
        self:_FillMissingUnlockedAutoDuty()
    end

    self.m_kitchenUnlockLevels = self:_BuildKitchenUnlockLevels()
    self.m_dutyRows = self:_BuildDutyRows()

    self:_InitTopNode()
    self:_InitCommonPromptNode()
    self:_InitTopicNodes()
    self:_InitOwnerNode()
    self:_InitKitchenList()

    self:_RefreshOwnerSkillList()
    self:_RefreshCommonPrompt()
    self:_RefreshKitchenList(true)

    self:InitController()
end






InnKitchenSettingsCtrl._BuildKitchenUnlockLevels = HL.Method().Return(HL.Table) << function(self)
    local result = {}
    local innConst = Tables.innManagementConst
    local initN = (innConst and innConst.initKitchenNum) or 0
    for i = 1, initN do
        result[i] = 0
    end

    local kitchenExps = {}
    for _, expData in pairs(Tables.innExpansionTable) do
        if expData and (expData.addKitchenNum or 0) > 0 then
            kitchenExps[#kitchenExps + 1] = expData
        end
    end
    table.sort(kitchenExps, function(a, b)
        local la, lb = a.unlockLevel or 0, b.unlockLevel or 0
        if la ~= lb then
            return la < lb
        end
        return (a.id or "") < (b.id or "")
    end)

    for _, expData in ipairs(kitchenExps) do
        for _ = 1, (expData.addKitchenNum or 0) do
            result[#result + 1] = expData.unlockLevel or 0
        end
    end

    return result
end


InnKitchenSettingsCtrl._BuildDutyRows = HL.Method().Return(HL.Table) << function(self)
    local rows = {}
    if self.m_innSystem and self.m_innSystem.jsspsiDutyUnlockInnLevel then
        for dutyType, unlockLevel in pairs(self.m_innSystem.jsspsiDutyUnlockInnLevel) do
            rows[#rows + 1] = { dutyType = dutyType, unlockLevel = unlockLevel }
        end
        table.sort(rows, function(a, b)
            if a.unlockLevel ~= b.unlockLevel then
                return a.unlockLevel < b.unlockLevel
            end
            return a.dutyType < b.dutyType
        end)
    end
    return rows
end



InnKitchenSettingsCtrl._BuildPendingCharCountByKitchen = HL.Method().Return(HL.Table) << function(self)
    local map = {}
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    local settings = pending and pending.kitchenSettings
    if settings and settings.Count and settings.Count > 0 then
        for i = 0, settings.Count - 1 do
            local ks = settings[i]
            if ks and ks.id then
                map[ks.id] = (ks.charIds and ks.charIds.Count) or 0
            end
        end
    end
    return map
end




InnKitchenSettingsCtrl._BuildPendingCharIdsForKitchen = HL.Method(HL.Number).Return(HL.Table) << function(self, kitchenId)
    local list = {}
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    local settings = pending and pending.kitchenSettings
    if not settings or not settings.Count or settings.Count == 0 then
        return list
    end
    local idToStr = CS.Beyond.Cfg.Tables.charIdToStr
    for i = 0, settings.Count - 1 do
        local ks = settings[i]
        if ks and ks.id == kitchenId and ks.charIds then
            for j = 0, ks.charIds.Count - 1 do
                local hasStr, charStr = idToStr:TryGetValue(ks.charIds[j])
                if hasStr and not string.isEmpty(charStr) then
                    list[#list + 1] = charStr
                end
            end
            break
        end
    end
    return list
end





InnKitchenSettingsCtrl._InitTopNode = HL.Method() << function(self)
    self.view.topNode.btnBack.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
end

InnKitchenSettingsCtrl._InitCommonPromptNode = HL.Method() << function(self)
    self.view.btnCommon.onClick:AddListener(function()
        if self:_ShouldSkipPlayAnimationOut() then
            return
        end
        self:PlayAnimationOutWithCallback(function()
            if self.m_isClosed then
                return
            end
            PhaseManager:OpenPhase(PhaseId.InnMenuSettings, {
                topicId = self.m_topicId,
            }, nil, true)
        end)
    end)
end

InnKitchenSettingsCtrl._InitTopicNodes = HL.Method() << function(self)
    self.view.topicDetailNode:InitInnTopicDetailNode({
        topicId = self.m_topicId,
        showRatingStar = true,
    })
    self.view.innTopicCell:InitInnTopicBar(self.m_topicId or "")
    self.view.clearBtn.onClick:AddListener(function()
        self:_OnClearBtnClicked()
    end)
end

InnKitchenSettingsCtrl._OnClearBtnClicked = HL.Method() << function(self)
    if not self.m_innSystem then
        return
    end
    
    
    if self.m_innSystem.topicSettings:ContainsKey(self.m_topicId) then
        self.m_innSystem:SendTopicSettingClear(self.m_topicId)
        return
    end
    self:_ClearPendingSetting()
    self:_RefreshAll(true)
end

InnKitchenSettingsCtrl._OnTopicSettingChanged = HL.Method(HL.Any) << function(self, eventArgs)
    local topicKey = unpack(eventArgs)
    if not self.m_innSystem or topicKey ~= self.m_topicId then
        return
    end
    local isCleared = not self.m_innSystem.topicSettings:ContainsKey(topicKey)
    if isCleared then
        self:_ClearPendingSetting()
    end
    self:_RefreshAll(true)
end

InnKitchenSettingsCtrl._OnKitchenCharSelectionSaved = HL.Method(HL.Any) << function(self, _kitchenId)
    self:_RefreshCommonPrompt()
    self:_RefreshKitchenList()
end

InnKitchenSettingsCtrl._OnInnDailyFashionChanged = HL.Method() << function(self)
    if not self:IsShow() or not InnUtils.isTopicUsingDailyFashion(self.m_topicId) then
        return
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_INN_DAILY_FASHION_REFRESHED_POPUP,
        hideCancel = true,
        onConfirm = function()
            InnUtils.exitToTopicSelectionOrLevel()
        end,
    })
end

InnKitchenSettingsCtrl._ClearPendingSetting = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if pending then
        pending.kitchenSettings:Clear()
        pending.menuItems:Clear()
        if pending.autoDuty then
            pending.autoDuty:Clear()
        end
    end
    self:_FillMissingUnlockedAutoDuty()
    Notify(MessageConst.SHOW_TOAST, Language.LUA_INN_TOPIC_SETTING_CLEAR_TOAST)
end

InnKitchenSettingsCtrl._RefreshAll = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAim)
    self:_RefreshOwnerSkillList()
    self:_RefreshCommonPrompt()
    self:_RefreshKitchenList()
    if playAim then
        self:PlayAnimationIn()
    end
end

InnKitchenSettingsCtrl._InitOwnerNode = HL.Method() << function(self)
    self.view.ownerNode.charNode:InitInnOwnerCharNode()
    self.view.ownerNode.buffNode:InitInnOwnerBuffNode(true)

    self.view.ownerNode.tipsBtn.onClick:AddListener(function()
        Notify(MessageConst.OPEN_INN_CHAR_TIPS, {
            charId = (Tables.innManagementConst and Tables.innManagementConst.jsspsiCharId) or "",
            transform = self.view.ownerNode.tipsBtn.transform,
            posType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        })
    end)

    self.m_skillCellCache = UIUtils.genCellCache(self.view.ownerNode.innOwerSkillNode)
end

InnKitchenSettingsCtrl._InitKitchenList = HL.Method() << function(self)
    self.m_kitchenCellCache = UIUtils.genCellCache(self.view.kitchenCell)
end





InnKitchenSettingsCtrl._FillMissingUnlockedAutoDuty = HL.Method() << function(self)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if not pending or not pending.autoDuty then
        return
    end
    local unlockMap = self.m_innSystem.jsspsiDutyUnlockInnLevel
    if not unlockMap then
        return
    end
    local innLevel = self.m_innSystem.innLevel or 0
    for dutyType, unlockLevel in pairs(unlockMap) do
        if innLevel >= (unlockLevel or 0) and not pending.autoDuty:ContainsKey(dutyType) then
            pending.autoDuty[dutyType] = true
        end
    end
end

InnKitchenSettingsCtrl._RefreshOwnerSkillList = HL.Method() << function(self)
    if not self.m_skillCellCache then
        return
    end
    local rows = self.m_dutyRows or {}
    self.m_skillCellCache:Refresh(#rows, function(cell, index)
        local row = rows[index]
        if not row then
            return
        end
        cell:InitInnOwerSkillNode({
            jsspsiDutyType = row.dutyType,
            onClick = function()
                self:_OnOwnerSkillClicked(cell, row)
            end,
        })
        self:_ApplyOwnerSkillSelectedState(cell, row)
    end)
end

InnKitchenSettingsCtrl._ApplyOwnerSkillSelectedState = HL.Method(HL.Any, HL.Table) << function(self, cell, row)    
    local isUnlocked = self:_IsDutyUnlocked(row)
    if DeviceInfo.usingController then
        cell.view.button.enabled = isUnlocked        
    end
    if not isUnlocked then
        return
    end
    local isSelected = self:_IsDutySelected(row.dutyType)
    cell:SetSelected(isSelected)
    self:_UpdateSkillCellHintText(cell, isSelected)
end

InnKitchenSettingsCtrl._IsDutyUnlocked = HL.Method(HL.Table).Return(HL.Boolean) << function(self, row)
    local innLevel = (self.m_innSystem and self.m_innSystem.innLevel) or 0
    return innLevel >= (row.unlockLevel or 0)
end

InnKitchenSettingsCtrl._HasAnyUnlockedDuty = HL.Method().Return(HL.Boolean) << function(self)
    local rows = self.m_dutyRows or {}
    for _, row in ipairs(rows) do
        if self:_IsDutyUnlocked(row) then
            return true
        end
    end
    return false
end

InnKitchenSettingsCtrl._IsDutySelected = HL.Method(HL.Any).Return(HL.Boolean) << function(self, dutyType)
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if not pending or not pending.autoDuty then
        return false
    end
    local has, val = pending.autoDuty:TryGetValue(dutyType)
    return has and val or false
end

InnKitchenSettingsCtrl._OnOwnerSkillClicked = HL.Method(HL.Any, HL.Table) << function(self, cell, row)
    if not self:_IsDutyUnlocked(row) then
        Notify(MessageConst.SHOW_TOAST,
            string.format(Language.LUA_INN_CHAR_TIPS_SKILL_LOCK, row.unlockLevel or 0))
        return
    end
    local pending = self.m_innSystem and self.m_innSystem.gameSetting
    if not pending or not pending.autoDuty then
        return
    end
    local newSelected = not self:_IsDutySelected(row.dutyType)
    pending.autoDuty[row.dutyType] = newSelected
    cell:SetSelected(newSelected)
    self:_UpdateSkillCellHintText(cell, newSelected)

    local toastKeys = DUTY_TOAST_KEY_MAP[row.dutyType]
    if toastKeys then
        Notify(MessageConst.SHOW_TOAST, Language[newSelected and toastKeys.open or toastKeys.close])
    end
end





InnKitchenSettingsCtrl._RefreshCommonPrompt = HL.Method() << function(self)
    local kitchenNum = (self.m_innSystem and self.m_innSystem.kitchenNum) or 0
    local countMap = self:_BuildPendingCharCountByKitchen()
    local allEmpty = true
    for i = 1, kitchenNum do
        if (countMap[i] or 0) > 0 then
            allEmpty = false
            break
        end
    end
    self.view.commonPrompt.gameObject:SetActiveIfNecessary(allEmpty)
    self.view.btnCommon.gameObject:SetActiveIfNecessary(not allEmpty)
end





InnKitchenSettingsCtrl._RefreshKitchenList = HL.Method(HL.Opt(HL.Boolean)) << function(self, gradually)
    if not self.m_kitchenCellCache or not self.m_innSystem then
        return
    end
    local kitchenMaxNum = self.m_innSystem.kitchenMaxNum or 0
    local refreshCell = function(cell, index)
        self:_RefreshKitchenCell(cell, index)
    end
    if gradually then
        self.m_kitchenCellCache:GraduallyRefresh(kitchenMaxNum, self.view.config.KITCHEN_CELL_REFRESH_INTERVAL, function(cell, index)
            refreshCell(cell, index)
            if index == 1 then
                self:SetNaviTarget(cell.button)
            end
        end)
    else
        self.m_kitchenCellCache:Refresh(kitchenMaxNum, refreshCell)
    end
end


InnKitchenSettingsCtrl._RefreshKitchenCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    if not cell then
        return
    end
    local kitchenNum = (self.m_innSystem and self.m_innSystem.kitchenNum) or 0
    local isUnlocked = index <= kitchenNum

    cell.gameObject.name = "Kitchen" .. index
    cell.nameTxt.text = Language['LUA_INN_KITCHEN_NAME_' .. index] or ""

    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        if not isUnlocked then
            Notify(MessageConst.SHOW_TOAST,
                Language.LUA_INN_KITCHEN_LOCKED_TOAST)
            return
        end
        PhaseManager:OpenPhase(PhaseId.InnKitchenCharSelection, {
            kitchenId = index,
            topicId = self.m_topicId,
        })
    end)

    if not isUnlocked then
        cell.simpleStateController:SetState("Lock")
        local levels = self.m_kitchenUnlockLevels or {}
        local unlockLevel = levels[index] or 0
        cell.lockTxt.text = string.format(Language.LUA_INN_KITCHEN_SETTINGS_LOCK, unlockLevel)
        
        cell._categoryTagCache = cell._categoryTagCache or UIUtils.genCellCache(cell.innItemTagCategory)
        cell._affixTagCache = cell._affixTagCache or UIUtils.genCellCache(cell.innItemTagAffix)
        cell._kitchenCharCache = cell._kitchenCharCache or UIUtils.genCellCache(cell.kitchenCharCell)
        cell._categoryTagCache:Refresh(0)
        cell._affixTagCache:Refresh(0)
        cell._kitchenCharCache:Refresh(0)
        return
    end

    local charIds = self:_BuildPendingCharIdsForKitchen(index)
    cell.simpleStateController:SetState(#charIds > 0 and "Char" or "Unlock")

    
    cell._categoryTagCache = cell._categoryTagCache or UIUtils.genCellCache(cell.innItemTagCategory)
    cell._affixTagCache = cell._affixTagCache or UIUtils.genCellCache(cell.innItemTagAffix)
    local catRows, affRows = InnUtils.buildSkillTagRowsFromCharIds(charIds, self.m_topicId)
    cell._categoryTagCache:Refresh(#catRows, function(tagCell, tagIndex)
        tagCell:InitInnItemTag(catRows[tagIndex].args)
    end)
    cell._affixTagCache:Refresh(#affRows, function(tagCell, tagIndex)
        tagCell:InitInnItemTag(affRows[tagIndex].args)
    end)
    cell.tags:SetState(#catRows >= 3 and "Left" or "Center")

    
    cell._kitchenCharCache = cell._kitchenCharCache or UIUtils.genCellCache(cell.kitchenCharCell)
    local maxSlot = (self.m_innSystem and self.m_innSystem.kitchenCharSlotMaxNum) or 0
    local unlockedSlot = (self.m_innSystem and self.m_innSystem.kitchenCharSlotNum) or 0
    cell._kitchenCharCache:Refresh(maxSlot, function(slotCell, slotIndex)
        self:_RefreshKitchenCharSlot(slotCell, slotIndex, unlockedSlot, charIds)
    end)
end

InnKitchenSettingsCtrl._RefreshKitchenCharSlot = HL.Method(HL.Any, HL.Number, HL.Number, HL.Table) << function(self, slotCell, slotIndex, unlockedSlot, charIds)
    if not slotCell or not slotCell.stateController then
        return
    end
    if slotIndex > unlockedSlot then
        slotCell.stateController:SetState("Lock")
        return
    end
    local charId = charIds[slotIndex]
    if charId and not string.isEmpty(charId) then
        slotCell.stateController:SetState("Char")
        if slotCell.charImg then
            slotCell.charImg:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE,
                UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. charId)
        end
        if slotCell.nameTxt then
            local hasTag, tagData = Tables.characterTagTable:TryGetValue(charId)
            slotCell.nameTxt.text = (hasTag and tagData and tagData.innNickname) or ""
        end
    else
        slotCell.stateController:SetState("Blank")
    end
end





InnKitchenSettingsCtrl.InitController = HL.Method() << function(self)
    
    local hasUnlockedDuty = self:_HasAnyUnlockedDuty()
    local skillNaviGroup = self.view.ownerNode.skillNodeNaviGroup
    skillNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.view.ownerNode.controllerFocusHintNode.gameObject:SetActiveIfNecessary(hasUnlockedDuty and not isFocused)
    end)
    if not hasUnlockedDuty and skillNaviGroup.FocusBindingId > 0 then
        InputManagerInst:ToggleBinding(skillNaviGroup.FocusBindingId, false)
    end
    self.view.ownerNode.controllerFocusHintNode.gameObject:SetActiveIfNecessary(hasUnlockedDuty)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnKitchenSettingsCtrl._UpdateSkillCellHintText = HL.Method(HL.Any, HL.Boolean) << function(self, cell, isSelected)
    if not cell then
        return
    end
    InputManagerInst:SetBindingText(cell.view.button.hoverConfirmBindingId, isSelected and Language.key_hint_owner_skill_unselect or Language.key_hint_owner_skill_select)
end



HL.Commit(InnKitchenSettingsCtrl)
