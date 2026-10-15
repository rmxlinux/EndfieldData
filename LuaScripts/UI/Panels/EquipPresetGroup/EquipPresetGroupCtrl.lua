local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

local PANEL_ID = PanelId.EquipPresetGroup

local PHASE_ID = PhaseId.EquipPresetGroup




local EQUIP_PRESET_SLOT_INDICES = {1, 0, 2, 3}


local CURRENT_EQUIP_PRESET_ID = 0

local DELETE_EQUIP_NOTIFY_TAG = 1

local DELETE_PRESET_GROUP_NOTIFY_TAG = 2

local PRESET_NAME_ACTION_CREATE = "Create"

local PRESET_NAME_ACTION_RENAME = "Rename"

local PRESET_LIST_ACTION_DELETE = "Delete"

local PRESET_CELL_IN_ANIMATION = "equippresetcell_in"

local PRESET_CELL_SAVE_IN_ANIMATION = "equippresetcell_save_in"

local PRESET_CELL_SAVE_OUT_ANIMATION = "equippresetcell_save_out"

local CURRENT_EQUIP_SAVE_IN_ANIMATION = "currentequipnode_save_in"

local PRESET_SCROLL_MODE_NONE = 0

local PRESET_SCROLL_MODE_VISIBLE = 1

local PRESET_SCROLL_MODE_TOP = 2

local APPLY_CONFIRM_DAILY_KEY = "EQUIP_PRESET_GROUP_APPLY_CONFIRM_DAILY"

local APPLY_CONFIRM_CLIENT_DATA_CATEGORY = "EquipPresetGroup"

local ATTRIBUTE_COMPARE_EPSILON = 0.00001

local MAIN_SUB_ATTRIBUTE_TYPES = { "Main", "Sub" }

local COMPARE_VISUAL_STATE_CLOSED = 0

local COMPARE_VISUAL_STATE_VISIBLE = 1

local COMPARE_VISUAL_STATE_CLOSING = 2

local function _GetFixedEquipCell(view, index)
    return {
        item = view["item" .. index],
        disableMark = view["emptyNode" .. index],
        imageCharMask = view["imageCharMask" .. index],
        imageChar = view["imageChar" .. index],
    }
end






























































































































EquipPresetGroupCtrl = HL.Class('EquipPresetGroupCtrl', uiCtrl.UICtrl)







EquipPresetGroupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_EQUIP_PRESET_GROUP_CHANGED] = '_OnPresetGroupChanged',
    [MessageConst.ON_EQUIP_PRESET_GROUP_APPLIED] = '_OnPresetGroupApplied',
    [MessageConst.ON_CHECK_SENSITIVE_SUCCESS] = '_OnCheckSensitiveSuccess',
    [MessageConst.ON_INPUT_DEVICE_TYPE_CHANGED] = '_OnInputDeviceTypeChanged',
}


EquipPresetGroupCtrl.m_curCharInfo = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_charInfoList = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_curSelectedPresetId = HL.Field(HL.Number) << CURRENT_EQUIP_PRESET_ID


EquipPresetGroupCtrl.m_isInCompare = HL.Field(HL.Boolean) << false


EquipPresetGroupCtrl.m_compareVisualState = HL.Field(HL.Number) << COMPARE_VISUAL_STATE_CLOSED


EquipPresetGroupCtrl.m_compareTransitionId = HL.Field(HL.Number) << 0

EquipPresetGroupCtrl.m_getCharHeadCell = HL.Field(HL.Function)

EquipPresetGroupCtrl.m_currentEquipCells = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_currentEquipInfoList = HL.Field(HL.Table)

EquipPresetGroupCtrl.m_currentEquipSaveAnimation = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_presetGroupList = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_allPresetGroupList = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_filterTags = HL.Field(HL.Table)

EquipPresetGroupCtrl.m_getPresetCell = HL.Field(HL.Function)
EquipPresetGroupCtrl.m_presetListEmptyMode = HL.Field(HL.Boolean) << true
EquipPresetGroupCtrl.m_presetListPlayingIn = HL.Field(HL.Boolean) << false


EquipPresetGroupCtrl.m_itemFocusRows = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_itemFocusContext = HL.Field(HL.Table)

EquipPresetGroupCtrl.m_itemFocusItem = HL.Field(HL.Any)

EquipPresetGroupCtrl.m_sourceFormationCharInstIds = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_pendingPresetNameAction = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_pendingPresetListAction = HL.Field(HL.Table)

EquipPresetGroupCtrl.m_pendingPresetScrollMode =
    HL.Field(HL.Number) << PRESET_SCROLL_MODE_NONE


EquipPresetGroupCtrl.m_pendingApply = HL.Field(HL.Table)


EquipPresetGroupCtrl.m_selectAttrBonusCellCache = HL.Field(HL.Forward("UIListCache"))

EquipPresetGroupCtrl.m_compareAttrBonusCellCache = HL.Field(HL.Forward("UIListCache"))


EquipPresetGroupCtrl.OnCreate = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    
    local recoverState = arg and arg.recoverState or nil
    self.m_filterTags = recoverState and recoverState.filterTags
        and lume.deepCopy(recoverState.filterTags) or {}
    self.m_isInCompare = recoverState and recoverState.isInCompare == true or false
    self:_SetSelectedPresetId(
        recoverState and recoverState.selectedPresetId or CURRENT_EQUIP_PRESET_ID)
    local sourceFormationCharInstIds = recoverState and recoverState.sourceFormationCharInstIds
        or (arg and arg.sourceFormationCharInstIds or nil)
    self.m_sourceFormationCharInstIds = sourceFormationCharInstIds
        and lume.deepCopy(sourceFormationCharInstIds) or nil

    self.m_itemFocusRows = {}

    local detailView = self.view.equipDetailNode
    self.m_selectAttrBonusCellCache = UIUtils.genCellCache(
        detailView.selectDetailsView.weaponAttributeNode.view.mainSubBonusCell)
    self.m_compareAttrBonusCellCache = UIUtils.genCellCache(
        detailView.compareDetailsView.weaponAttributeNode.view.mainSubBonusCell)

    self:_InitCharList(arg)
    self:_InitBtns()
    UIUtils.bindHyperlinkPopup(self, "EquipSuit", self.view.inputGroup.groupId)
    self:_InitCurrentEquipList()
    self:_RefreshCurrentEquipInfo()
    self:_InitPresetList()
    self:_RefreshPresetList(nil, true)
    self:_ResetCreatePresetNameInput()
    self:_RestoreControllerNaviTarget()
    self:_TryShowDeleteEquipNotifyToast()
    RedDotUtils.setEquipPresetGroupNewRead()
    self:_TryRecoverRenamePopUp(recoverState and recoverState.renamePopUpArg)
end

EquipPresetGroupCtrl._TryShowDeleteEquipNotifyToast = HL.Method() << function(self)
    local equipPresetGroupSystem = GameInstance.player.equipPresetGroupSystem
    local notifyTag = equipPresetGroupSystem:GetDeleteEquipNotifyTag()
    local toast
    if notifyTag == DELETE_PRESET_GROUP_NOTIFY_TAG then
        toast = Language.LUA_EQUIP_PRESET_GROUP_EMPTY_DELETED_TOAST
    elseif notifyTag == DELETE_EQUIP_NOTIFY_TAG then
        toast = Language.LUA_EQUIP_PRESET_GROUP_EQUIP_DESTROYED_TOAST
    else
        return
    end

    Notify(MessageConst.SHOW_TOAST, toast)
    equipPresetGroupSystem:SendEquipPresetGroupReadDeleteNotify()
end

EquipPresetGroupCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local renamePopUpArg
    if PhaseManager:GetTopPhaseId() == PHASE_ID then
        local isOpen, commonPopUpCtrl = UIManager:IsOpen(PanelId.CommonPopUp)
        if isOpen and commonPopUpCtrl:IsShow() then
            local popUpArg = commonPopUpCtrl:GetCurPhaseStateArg()
            if popUpArg and popUpArg.content == Language.LUA_EQUIP_PRESET_GROUP_RENAME_TITLE then
                renamePopUpArg = popUpArg
            end
        end
    end
    return {
        recoverState = {
            charInstId = self.m_curCharInfo and self.m_curCharInfo.instId or nil,
            selectedPresetId = self.m_curSelectedPresetId,
            filterTags = lume.deepCopy(self.m_filterTags or {}),
            isInCompare = self.m_isInCompare,
            renamePopUpArg = renamePopUpArg,
            sourceFormationCharInstIds = self.m_sourceFormationCharInstIds
                and lume.deepCopy(self.m_sourceFormationCharInstIds) or nil,
        },
    }
end



EquipPresetGroupCtrl.OnHide = HL.Override() << function(self)
    self.view.equipDetailNode.selectView.inputNaviGroup:ManuallyStopFocus()
    self:_CompleteCurrentEquipSaveInAnimation()
    self.m_compareTransitionId = self.m_compareTransitionId + 1
    local pendingAction = self.m_pendingPresetListAction
    if self:_IsPresetDeleteAnimationPlaying() then
        self:_FinishDeletedPresetListAction(pendingAction)
    else
        self:_CompletePresetCellInAnimations()
    end
    self:_ExitItemFocus()
end
EquipPresetGroupCtrl.OnClose = HL.Override() << function(self)
    self.view.equipDetailNode.selectView.inputNaviGroup:ManuallyStopFocus()
    if self.m_selectAttrBonusCellCache then
        self.m_selectAttrBonusCellCache:ClearAll()
        self.m_selectAttrBonusCellCache = nil
    end
    if self.m_compareAttrBonusCellCache then
        self.m_compareAttrBonusCellCache:ClearAll()
        self.m_compareAttrBonusCellCache = nil
    end
    self:_CompleteCurrentEquipSaveInAnimation()
    self.m_compareTransitionId = self.m_compareTransitionId + 1
    if self.m_pendingPresetListAction then
        self:_ReleasePresetDeleteCell(self.m_pendingPresetListAction)
        self.m_pendingPresetListAction = nil
    end
    self:_CompletePresetCellInAnimations()
    self:_ExitItemFocus()
    self:_ResetCreatePresetNameInput()
end




EquipPresetGroupCtrl._InitBtns = HL.Method() << function(self)
    local detailView = self.view.equipDetailNode
    local selectView = detailView.selectView

    selectView.inputField.characterLimit = UIConst.INPUT_FIELD_NAME_CHARACTER_LIMIT
    selectView.inputField.onValidateCharacterLimit = I18nUtils.GetRealTextByLengthLimit
    selectView.inputField.onGetTextLength = I18nUtils.GetTextRealLength
    selectView.inputField.onIsNaviTargetChanged = function(isTarget, isGroupChanged, isOnNaviTargetEnabledAgain)
        if DeviceInfo.usingController and isTarget and isOnNaviTargetEnabledAgain then
            selectView.inputField:ActivateInputField()
        end
    end
    
    selectView.inputNaviGroup.onIsFocusedChange:AddListener(function(active)
        if active then
            selectView.inputField:ActivateInputField()
        else
            selectView.inputField:DeactivateInputField(false)
        end
    end)
    selectView.editNode.gameObject:SetActive(false)
    selectView.inputField.gameObject:SetActive(false)
    selectView.limitNode.gameObject:SetActive(false)

    selectView.saveBtn.onClick:AddListener(function()
        if self:_IsCurrentEquipSelected() then
            self:_SubmitCreatePresetFromInput()
            return
        end
        self:_OnApplyPresetClicked()
    end)
    selectView.editBtn.onClick:AddListener(function()
        local selectedPreset = self:_GetSelectedPreset()
        if selectedPreset then
            self:_OpenRenamePopup(selectedPreset)
        end
    end)
    detailView.compareButton.onClick:AddListener(function()
        detailView.autoCloseArea.tmpSafeArea = detailView.compareButton.transform
        self:_SetCompare(true)
    end)
    detailView.shrinkButton.onClick:AddListener(function()
        self:_SetCompare(false)
    end)
    detailView.autoCloseArea.onTriggerAutoClose:AddListener(function()
        self:_SetCompare(false)
    end)

    self:_InitCompareScroll()
    self:_InitFilter()
    self.view.topBarNode.quitBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
end

EquipPresetGroupCtrl._InitFilter = HL.Method() << function(self)
    local equipProduceTagGroups = FilterUtils.generateConfig_EQUIP_PRODUCE()
    local groupType2TagGroup = {}
    for _, tagGroup in ipairs(equipProduceTagGroups) do
        local firstTag = tagGroup.tags and tagGroup.tags[1] or nil
        if firstTag then
            groupType2TagGroup[firstTag.groupType] = tagGroup
        end
    end

    
    local filterArgs = {
        
        tagGroups = {
            groupType2TagGroup.Suit,
            groupType2TagGroup.EquipMainAttrType,
            groupType2TagGroup.EquipExtraAttrType,
        },
        selectedTags = self.m_filterTags,
        onConfirm = function(selectedTags)
            self:_OnFilterConfirm(selectedTags)
        end,
        getResultCount = function(selectedTags)
            return self:_GetPresetFilterResultCount(selectedTags)
        end,
    }
    self.view.presetListNode.filterBtn:InitFilterBtn(filterArgs)
end

EquipPresetGroupCtrl._CheckCanApplyPreset = HL.Method().Return(HL.Boolean) << function(self)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_curCharInfo.instId)
    if not charInst then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
        return false
    end
    if charInst.scope ~= GameInstance.curScope then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
        return false
    end
    if not CharInfoUtils.IsServerDefaultChar(charInst) then
        local toast = charInst.charType == GEnums.CharType.Trial
            and Language.LUA_CHAR_INFO_EQUIP_TRAIL_FORBID
            or Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION
        Notify(MessageConst.SHOW_TOAST, toast)
        return false
    end
    if Utils.isInFight() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_PRESET_GROUP_IN_FIGHT_FORBID_APPLY_TOAST)
        return false
    end
    if not CharInfoUtils.isCharDevAvailable(charInst.instId)
        or Utils.isForbidden(ForbidType.ForbidChangeEquip) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
        return false
    end
    local selectedPreset = self:_GetSelectedPreset()
    if not selectedPreset then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
        return false
    end

    for _, equipInfo in ipairs(selectedPreset.equipInfos) do
        if not equipInfo.isEmpty and charInst.equipTierLimit < equipInfo.itemCfg.rarity then
            local requiredEquipTier = equipInfo.itemCfg.rarity
            local nodeId = CharInfoUtils.getQualifiedEquipBreakNodeIdByEquipTierLimit(requiredEquipTier)
            local charGrowthDict = CharInfoUtils.getCharGrowthData(charInst.templateId)
            local breakDetail = charGrowthDict and charGrowthDict.charBreakCostMap[nodeId] or nil
            local toast = breakDetail
                and Language.LUA_EQUIP_PRESET_GROUP_EQUIP_TIER_LIMIT_TOAST
                or Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION
            Notify(MessageConst.SHOW_TOAST, toast)
            return false
        end
    end
    return true
end


EquipPresetGroupCtrl._OnApplyPresetClicked = HL.Method() << function(self)
    if not self:_CheckCanApplyPreset() then
        return
    end

    local charInstId = self.m_curCharInfo.instId
    local presetId = self.m_curSelectedPresetId
    local selectedPreset = self:_GetSelectedPreset()
    local hasOccupiedEquip, canUseSubstitute = self:_GetApplyOccupationState(selectedPreset, charInstId)
    if hasOccupiedEquip then
        UIManager:Open(PanelId.EquipPresetGroupApplyConfirmPopUp, {
            canUseSubstitute = canUseSubstitute,
            onConfirm = function(useSubstituteTemplate)
                self:_SendApplyPreset(charInstId, presetId, useSubstituteTemplate)
            end,
        })
        return
    end

    local _, hideToday = ClientDataManagerInst:GetBool(
        APPLY_CONFIRM_DAILY_KEY, false, false, APPLY_CONFIRM_CLIENT_DATA_CATEGORY)
    if hideToday then
        self:_SendApplyPreset(charInstId, presetId, false)
        return
    end

    local noRemindToday = false
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_EQUIP_PRESET_GROUP_APPLY_NORMAL_CONFIRM,
        toggle = {
            isOn = false,
            toggleText = Language.LUA_EQUIP_PRESET_GROUP_APPLY_NO_REMIND,
            onValueChanged = function(isOn)
                noRemindToday = isOn
            end,
        },
        onConfirm = function()
            ClientDataManagerInst:SetBool(
                APPLY_CONFIRM_DAILY_KEY, noRemindToday, false,
                APPLY_CONFIRM_CLIENT_DATA_CATEGORY,
                EClientDataTimeValidType.CurrentDayUntil4AM)
            self:_SendApplyPreset(charInstId, presetId, false)
        end,
    })
end


EquipPresetGroupCtrl._GetApplyOccupationState =
    HL.Method(HL.Table, HL.Number).Return(HL.Boolean, HL.Boolean) << function(self, selectedPreset, charInstId)
    local requiredSubstituteCounts = {}
    local hasOccupiedEquip = false
    for _, equipInfo in ipairs(selectedPreset.equipInfos) do
        local equipInstData = not equipInfo.isEmpty and equipInfo.equipInstData or nil
        if equipInstData then
            local templateId = equipInstData.templateId
            requiredSubstituteCounts[templateId] = (requiredSubstituteCounts[templateId] or 0) + 1
            if equipInstData.equippedCharServerId ~= 0
                and equipInstData.equippedCharServerId ~= charInstId then
                hasOccupiedEquip = true
            end
        end
    end
    if not hasOccupiedEquip then
        return false, true
    end

    local depots = GameInstance.player.inventory.valuableDepots
    if not depots:ContainsKey(GEnums.ItemValuableDepotType.Equip) then
        return true, false
    end
    local equipDepot = depots[GEnums.ItemValuableDepotType.Equip]:GetOrFallback(Utils.getCurrentScope())
    if not equipDepot then
        return true, false
    end
    for _, itemBundle in cs_pairs(equipDepot.instItems) do
        local equipInstData = itemBundle.instData
        local requiredCount = requiredSubstituteCounts[equipInstData.templateId]
        if requiredCount and requiredCount > 0 and
            (equipInstData.equippedCharServerId == 0 or equipInstData.equippedCharServerId == charInstId) then
            requiredSubstituteCounts[equipInstData.templateId] = requiredCount - 1
        end
    end
    for _, requiredCount in pairs(requiredSubstituteCounts) do
        if requiredCount > 0 then
            return true, false
        end
    end
    return true, true
end

EquipPresetGroupCtrl._SendApplyPreset =
    HL.Method(HL.Number, HL.Number, HL.Boolean) << function(self, charInstId, presetId, useSubstituteTemplate)
    self.m_pendingApply = {
        charInstId = charInstId,
        presetId = presetId,
    }
    GameInstance.player.equipPresetGroupSystem:SendEquipPresetGroupApply(
        charInstId, presetId, useSubstituteTemplate)
end



EquipPresetGroupCtrl._InitCurrentEquipList = HL.Method() << function(self)
    local currentEquipView = self.view.currentEquipNode
    self.m_currentEquipCells = {}
    for index = 1, #EQUIP_PRESET_SLOT_INDICES do
        self.m_currentEquipCells[index] = _GetFixedEquipCell(currentEquipView, index)
    end
    
    currentEquipView.selectBtn.onClick:AddListener(function()
        self:_SelectPreset(CURRENT_EQUIP_PRESET_ID)
    end)
    currentEquipView.selectBtn.onIsNaviTargetChanged = function(_)
        self:_RefreshItemFocusBindings()
    end
end

EquipPresetGroupCtrl._RefreshCurrentEquipInfo = HL.Method() << function(self)
    self:_CompleteCurrentEquipSaveInAnimation()
    self:_ExitItemFocus()
    local charInstId = self.m_curCharInfo.instId
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local charCfg = Tables.characterTable[self.m_curCharInfo.templateId]
    local currentEquipView = self.view.currentEquipNode
    currentEquipView.charName.text = charCfg.name
    currentEquipView.currentText.text = Language.LUA_EQUIP_PRESET_GROUP_CURRENT_EQUIP_NAME

    local list = {}
    for _, slotIndex in ipairs(EQUIP_PRESET_SLOT_INDICES) do
        local hasEquip, equipInstId = charInst.equipCol:TryGetValue(slotIndex)
        local info = hasEquip and self:_BuildEquipInfo(equipInstId, slotIndex) or nil
        table.insert(list, info or { slotIndex = slotIndex, isEmpty = true })
    end
    
    if self.m_currentEquipInfoList and not self:_IsEquipInfoListSame(self.m_currentEquipInfoList, list) then
        self:_ResetCreatePresetNameInput()
    end
    self.m_currentEquipInfoList = list
    for index, info in ipairs(self.m_currentEquipInfoList) do
        self:_RefreshEquipCell(self.m_currentEquipCells[index], info)
    end
    self:_SetupEquipRowItemFocus(
        currentEquipView, self.m_currentEquipInfoList, CURRENT_EQUIP_PRESET_ID)
    self:_RefreshCardSuitSummary(currentEquipView, self.m_currentEquipInfoList, "Empty")
end


EquipPresetGroupCtrl._BuildEquipInfo = HL.Method(HL.Any, HL.Opt(HL.Any)).Return(HL.Opt(HL.Table)) << function(self, equipInstId, slotIndex)
    local equipInstData = CharInfoUtils.getEquipByInstId(equipInstId)
    if not equipInstData then
        return nil
    end
    local templateId = equipInstData.templateId
    local _, equipCfg = Tables.equipTable:TryGetValue(templateId)
    local itemCfg = Tables.itemTable:GetValue(templateId)
    return {
        slotIndex     = slotIndex,
        equipInstId   = equipInstId,
        equipInstData = equipInstData,
        equipCfg      = equipCfg,
        itemCfg       = itemCfg,
    }
end


EquipPresetGroupCtrl._RefreshEquipCell = HL.Method(HL.Any, HL.Table) << function(self, cell, info)
    if info.isEmpty then
        cell.item.gameObject:SetActive(true)
        cell.item:InitItem(nil)
        cell.item.view.animationNode.gameObject:SetActive(false)
        cell.disableMark.gameObject:SetActive(true)
        cell.imageCharMask.gameObject:SetActive(false)
        return
    end

    cell.item.gameObject:SetActive(true)
    cell.item.view.animationNode.gameObject:SetActive(true)
    cell.item:InitItem({
        id     = info.itemCfg.id,
        instId = info.equipInstId,
        count  = 1,
    }, true)
    cell.disableMark.gameObject:SetActive(false)

    local equippedCharServerId = info.equipInstData.equippedCharServerId
    local isEquipped = equippedCharServerId ~= nil and equippedCharServerId > 0
    
    cell.imageCharMask.gameObject:SetActive(isEquipped)
    if isEquipped then
        local charEntityInfo = CharInfoUtils.getPlayerCharInfoByInstId(equippedCharServerId)
        local charTemplateId = charEntityInfo.templateId
        local spriteName = UIConst.UI_CHAR_HEAD_PREFIX .. charTemplateId
        cell.imageChar:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD, spriteName)
    end
end



EquipPresetGroupCtrl._CanEnterItemFocus = HL.Method(HL.Table).Return(HL.Boolean) << function(self, context)
    return DeviceInfo.usingController
        and context.ownerSelectBtn.gameObject.activeInHierarchy
        and not self.m_isInCompare
        and not context.naviGroup.IsTopLayer
        and #context.entries > 0
        and self.m_curSelectedPresetId == context.ownerPresetId
        and context.ownerSelectBtn.isNaviTarget
end

EquipPresetGroupCtrl._RefreshItemFocusExtraInfo = HL.Method(HL.Table) << function(self, context)
    local extraInfo = {}
    if DeviceInfo.usingController then
        extraInfo = {
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightTop,
            tipsPosTransform = context.tipsAnchorTransform,
            isSideTips = true,
            keyHintGroupIds = { context.itemInputGroup.groupId },
            onBeforeJump = function()
                self:_ExitItemFocus()
            end,
        }
    end
    for _, entry in ipairs(context.entries) do
        entry.item:SetExtraInfo(extraInfo)
        entry.item:SetEnableHoverTips(not DeviceInfo.usingController)
    end
end

EquipPresetGroupCtrl._RefreshItemFocusBinding = HL.Method(HL.Table) << function(self, context)
    local bindingId = context.naviGroup.FocusBindingId
    if bindingId and bindingId > 0 then
        InputManagerInst:ToggleBinding(bindingId, self:_CanEnterItemFocus(context))
    end
end

EquipPresetGroupCtrl._RefreshItemFocusBindings = HL.Method() << function(self)
    for _, context in pairs(self.m_itemFocusRows or {}) do
        self:_RefreshItemFocusBinding(context)
    end
end

EquipPresetGroupCtrl._RefreshControllerHints = HL.Method() << function(self)
    local groupIds = { self.view.inputGroup.groupId }
    local addedGroupIds = { [self.view.inputGroup.groupId] = true }
    for _, context in pairs(self.m_itemFocusRows or {}) do
        local focusBindingGroup = context.focusBindingGroup
        if context.ownerSelectBtn.gameObject.activeInHierarchy
            and focusBindingGroup and not addedGroupIds[focusBindingGroup.groupId] then
            table.insert(groupIds, focusBindingGroup.groupId)
            addedGroupIds[focusBindingGroup.groupId] = true
        end
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder(groupIds, nil, function(infoList)
        if not self:_IsCurrentEquipSelected() or #self:_GetCurrentEquipInstIds() > 0 then
            return
        end
        local saveBtn = self.view.equipDetailNode.selectView.saveBtn
        for i = #infoList, 1, -1 do
            if infoList[i].hintView == saveBtn then
                table.remove(infoList, i)
            end
        end
    end)
end

EquipPresetGroupCtrl._SetupEquipRowItemFocus =
    HL.Method(HL.Table, HL.Table, HL.Number) << function(self, rowView, equipInfos, ownerPresetId)
    local naviGroup = rowView.itemNaviGroup
    
    naviGroup.useFocusHighlight = true
    naviGroup.focusHighlightNormalFrame = true
    naviGroup.focusOverrideHighlightRect = naviGroup.transform
    local tipsAnchorCell = _GetFixedEquipCell(rowView, #equipInfos)
    local entries = {}
    for index, info in ipairs(equipInfos) do
        local equipCell = _GetFixedEquipCell(rowView, index)
        local button = equipCell.item.view.button
        local isValid = not info.isEmpty and info.equipInstId ~= nil
        button.enableControllerNavi = true
        button:ChangeActionOnSetNaviTarget(CS.Beyond.Input.ActionOnSetNaviTarget.None)
        button.onIsNaviTargetChanged = nil
        
        InputManagerInst:DeleteInGroup(button.hoverBindingGroupId)
        if isValid then
            table.insert(entries, {
                item = equipCell.item,
                button = button,
            })
        else
            button.onIsNaviTargetChanged = function(isTarget)
                if isTarget and naviGroup.IsTopLayer then
                    self:_HideItemFocusTips()
                end
            end
        end
    end

    local context = {
        naviGroup = naviGroup,
        itemInputGroup = rowView.itemInputGroup,
        tipsAnchorTransform = tipsAnchorCell.item.transform,
        focusBindingGroup = rowView.inputGroup or self.view.presetListNode.scrollInputGroup,
        ownerSelectBtn = rowView.selectBtn,
        ownerPresetId = ownerPresetId,
        entries = entries,
    }
    self.m_itemFocusRows[naviGroup] = context

    naviGroup:ClearLastFocusNaviTarget()
    naviGroup:SetFocusBindingText(InputManagerInst:GetActionText("show_item_tips"))
    naviGroup.canFocusFun = function()
        return self:_CanEnterItemFocus(context)
    end
    naviGroup.getDefaultSelectableFunc = function()
        return entries[1] and entries[1].button or nil
    end
    naviGroup.onIsFocusedChange:RemoveAllListeners()
    naviGroup.onIsFocusedChange:AddListener(function(focused)
        if focused then
            self.m_itemFocusContext = context
            self.view.controllerHintPlaceholder.gameObject:SetActive(false)
        elseif self.m_itemFocusContext == context then
            self:_HideItemFocusTips()
            self.m_itemFocusContext = nil
            self.view.controllerHintPlaceholder.gameObject:SetActive(true)
        end
        self:_RefreshItemFocusBindings()
    end)

    self:_RefreshItemFocusExtraInfo(context)
    for _, entry in ipairs(entries) do
        entry.button.onIsNaviTargetChanged = function(isTarget)
            if isTarget and naviGroup.IsTopLayer then
                self:_ShowItemFocusTips(context, entry.item)
            end
        end
    end
    self:_RefreshItemFocusBinding(context)
end

EquipPresetGroupCtrl._ShowItemFocusTips = HL.Method(HL.Table, HL.Any) << function(self, context, item)
    if not DeviceInfo.usingController or not context.naviGroup.IsTopLayer then
        return
    end
    if self.m_itemFocusItem == item and item.showingTips then
        return
    end
    self:_HideItemFocusTips()
    self.m_itemFocusContext = context
    self.m_itemFocusItem = item
    item:ShowTips()
end

EquipPresetGroupCtrl._HideItemFocusTips = HL.Method() << function(self)
    local item = self.m_itemFocusItem
    self.m_itemFocusItem = nil
    if item and item.showingTips then
        Notify(MessageConst.HIDE_ITEM_TIPS)
        item:_OnTipsClosed()
    end
end

EquipPresetGroupCtrl._ExitItemFocus = HL.Method() << function(self)
    local context = self.m_itemFocusContext
    if context and context.naviGroup and context.naviGroup.IsTopLayer then
        context.naviGroup:ManuallyStopFocus()
    end
    self:_HideItemFocusTips()
    self.m_itemFocusContext = nil
    if self.view and self.view.controllerHintPlaceholder then
        self.view.controllerHintPlaceholder.gameObject:SetActive(true)
    end
end








EquipPresetGroupCtrl._GetEquipInstIdsFromInfos = HL.Method(HL.Opt(HL.Table)).Return(HL.Table) << function(self, infoList)
    local ids = {}
    if infoList then
        for _, info in ipairs(infoList) do
            if not info.isEmpty and info.equipInstId then
                table.insert(ids, info.equipInstId)
            end
        end
    end
    return ids
end


EquipPresetGroupCtrl._GetCurrentEquipInstIds = HL.Method().Return(HL.Table) << function(self)
    return self:_GetEquipInstIdsFromInfos(self.m_currentEquipInfoList)
end


EquipPresetGroupCtrl._GetSelectedEquipInstIds = HL.Method().Return(HL.Table) << function(self)
    if self:_IsCurrentEquipSelected() then
        return self:_GetCurrentEquipInstIds()
    end
    local selectedPreset = self:_GetSelectedPreset()
    local presetInfos = selectedPreset and selectedPreset.equipInfos or nil
    return self:_GetEquipInstIdsFromInfos(presetInfos)
end



EquipPresetGroupCtrl._GetEquipListSuitInfoList = HL.Method(HL.Table).Return(HL.Table) << function(self, equipInstIds)
    local suitCountMap = {}
    for _, equipInstId in ipairs(equipInstIds) do
        local equipInstData = CharInfoUtils.getEquipByInstId(equipInstId)
        if equipInstData then
            local _, equipCfg = Tables.equipTable:TryGetValue(equipInstData.templateId)
            local suitId = equipCfg and equipCfg.suitID or nil
            if suitId and not string.isEmpty(suitId) then
                suitCountMap[suitId] = (suitCountMap[suitId] or 0) + 1
            end
        end
    end

    local suitInfoList = {}
    for suitId, suitCount in pairs(suitCountMap) do
        table.insert(suitInfoList, { suitId = suitId, suitCount = suitCount })
    end
    suitInfoList = lume.sort(suitInfoList, function(a, b)
        return a.suitCount > b.suitCount
    end)
    return suitInfoList
end



EquipPresetGroupCtrl._RefreshCardSuitSummary =
    HL.Method(HL.Table, HL.Table, HL.String) << function(self, view, equipInfos, emptyState)
    local equipInstIds = self:_GetEquipInstIdsFromInfos(equipInfos)
    if #equipInstIds == 0 then
        view.contentStateController:SetState(emptyState)
        return
    end

    local enabledSuitCfg
    for _, suitInfo in ipairs(self:_GetEquipListSuitInfoList(equipInstIds)) do
        local _, totalSuitCfg = Tables.equipSuitTable:TryGetValue(suitInfo.suitId)
        local firstSuitCfg = totalSuitCfg and totalSuitCfg.list[0] or nil
        if firstSuitCfg and suitInfo.suitCount >= firstSuitCfg.equipCnt then
            enabledSuitCfg = firstSuitCfg
            break
        end
    end

    if enabledSuitCfg then
        view.contentStateController:SetState("Normal")
        view.suitName.text = enabledSuitCfg.suitName
        view.suitLogo:LoadSprite(
            UIConst.UI_SPRITE_EQUIPMENT_LOGO_BIG_WHITE,
            enabledSuitCfg.suitLogoName)
        local hasSelectedLogo = self.loader:CheckExists(UIUtils.getSpritePath(
            UIConst.UI_SPRITE_EQUIPMENT_LOGO_BIG, enabledSuitCfg.suitLogoName))
        view.suitLogoSelected:LoadSprite(
            hasSelectedLogo and UIConst.UI_SPRITE_EQUIPMENT_LOGO_BIG or UIConst.UI_SPRITE_EQUIPMENT_LOGO_BIG_WHITE,
            enabledSuitCfg.suitLogoName)
    else
        view.contentStateController:SetState("NoEquipSuit")
    end
end



EquipPresetGroupCtrl._BuildGroupViewData = HL.Method(HL.Table, HL.String).Return(HL.Table) << function(self, equipInstIds, name)
    local defShowInfo, mainAttrShowInfos, extraAttrShowInfos = CharInfoUtils.getEquipListAttributeShowInfos(equipInstIds)
    return {
        name               = name,
        defShowInfo        = defShowInfo,
        mainAttrShowInfos  = mainAttrShowInfos,
        extraAttrShowInfos = extraAttrShowInfos,
        suitInfoList       = self:_GetEquipListSuitInfoList(equipInstIds),
    }
end


EquipPresetGroupCtrl._MergeMainSubAttributeShowInfos =
    HL.Method(HL.Table).Return(HL.Table) << function(self, attrShowInfos)
    local charCfg = Tables.characterTable[self.m_curCharInfo.templateId]
    local targetTypes = { Main = charCfg.mainAttrType, Sub = charCfg.subAttrType }
    local fixedModifier = GEnums.ModifierType.BaseAddition
    local result, fixedInfos, sourceInfos = {}, {}, {}
    for _, info in ipairs(attrShowInfos) do
        if info.attrModifier == fixedModifier and targetTypes[info.attributeType] then
            sourceInfos[info.attributeType] = info
        else
            table.insert(result, info)
            if info.attrModifier == fixedModifier then
                fixedInfos[info.attributeType] = info
            end
        end
    end
    for _, sourceType in ipairs(MAIN_SUB_ATTRIBUTE_TYPES) do
        local sourceInfo = sourceInfos[sourceType]
        if sourceInfo and math.abs(sourceInfo.attributeValue) > ATTRIBUTE_COMPARE_EPSILON then
            local targetType = targetTypes[sourceType]
            local targetInfo = fixedInfos[targetType]
            if not targetInfo then
                targetInfo = AttributeUtils.generateAttributeShowInfo(targetType, 0, {
                    attrModifier = fixedModifier, forceShow = true,
                })
                fixedInfos[targetType] = targetInfo
                table.insert(result, targetInfo)
            end
            targetInfo.attributeValue = targetInfo.attributeValue + sourceInfo.attributeValue
            targetInfo.mainSubBonuses = targetInfo.mainSubBonuses or {}
            targetInfo.mainSubBonuses[sourceType] = sourceInfo.attributeValue
        end
    end
    for index, info in ipairs(result) do
        if info.mainSubBonuses then
            local mergedInfo = AttributeUtils.generateAttributeShowInfo(info.attributeType, info.attributeValue, {
                attrModifier = fixedModifier, forceShow = true,
            })
            mergedInfo.mainSubBonuses = info.mainSubBonuses
            result[index] = mergedInfo
        end
    end
    return result
end



EquipPresetGroupCtrl._AlignAttributeShowInfoLists =
    HL.Method(HL.Table, HL.Table).Return(HL.Table, HL.Table) << function(self, leftList, rightList)
    local comboInfoMap = {}
    for _, info in ipairs(leftList) do
        local modifierType = info.attrModifier or GEnums.ModifierType.None
        comboInfoMap[info.attributeType] = comboInfoMap[info.attributeType] or {}
        comboInfoMap[info.attributeType][modifierType] = {
            leftInfo = info,
        }
    end
    for _, info in ipairs(rightList) do
        local modifierType = info.attrModifier or GEnums.ModifierType.None
        comboInfoMap[info.attributeType] = comboInfoMap[info.attributeType] or {}
        local comboInfo = comboInfoMap[info.attributeType][modifierType]
        if comboInfo then
            comboInfo.rightInfo = info
        else
            comboInfoMap[info.attributeType][modifierType] = {
                rightInfo = info,
            }
        end
    end

    local comboInfoList = {}
    for attributeType, modifierInfoMap in pairs(comboInfoMap) do
        for modifierType, comboInfo in pairs(modifierInfoMap) do
            local zeroCfg = {
                attrModifier = modifierType,
                forceShow = true,
            }
            comboInfo.leftInfo = comboInfo.leftInfo
                or AttributeUtils.generateAttributeShowInfo(attributeType, 0, zeroCfg)
            comboInfo.rightInfo = comboInfo.rightInfo
                or AttributeUtils.generateAttributeShowInfo(attributeType, 0, zeroCfg)
            local leftBonuses = comboInfo.leftInfo.mainSubBonuses or {}
            local rightBonuses = comboInfo.rightInfo.mainSubBonuses or {}
            local bonusTypes = {}
            for _, sourceType in ipairs(MAIN_SUB_ATTRIBUTE_TYPES) do
                if leftBonuses[sourceType] or rightBonuses[sourceType] then
                    table.insert(bonusTypes, sourceType)
                end
            end
            comboInfo.leftInfo.mainSubBonusTypes = bonusTypes
            comboInfo.rightInfo.mainSubBonusTypes = bonusTypes
            table.insert(comboInfoList, comboInfo)
        end
    end
    table.sort(comboInfoList, function(a, b)
        return a.leftInfo.sortOrder < b.leftInfo.sortOrder
    end)

    local alignedLeftList = {}
    local alignedRightList = {}
    for _, comboInfo in ipairs(comboInfoList) do
        table.insert(alignedLeftList, comboInfo.leftInfo)
        table.insert(alignedRightList, comboInfo.rightInfo)
    end
    return alignedLeftList, alignedRightList
end


EquipPresetGroupCtrl._AlignCompareGroupViewData =
    HL.Method(HL.Table, HL.Table) << function(self, leftData, rightData)
    if leftData.defShowInfo and not rightData.defShowInfo then
        rightData.defShowInfo = AttributeUtils.generateEmptyAttributeShowInfo(
            leftData.defShowInfo.attributeType)
    elseif rightData.defShowInfo and not leftData.defShowInfo then
        leftData.defShowInfo = AttributeUtils.generateEmptyAttributeShowInfo(
            rightData.defShowInfo.attributeType)
    end

    leftData.mainAttrShowInfos, rightData.mainAttrShowInfos =
        self:_AlignAttributeShowInfoLists(leftData.mainAttrShowInfos, rightData.mainAttrShowInfos)
    leftData.extraAttrShowInfos, rightData.extraAttrShowInfos =
        self:_AlignAttributeShowInfoLists(leftData.extraAttrShowInfos, rightData.extraAttrShowInfos)
    leftData.showZeroAttributes = true
    rightData.showZeroAttributes = true
end



EquipPresetGroupCtrl._RefreshGroupCompareArrow =
    HL.Method(HL.Table, HL.Table, HL.Table) << function(self, cell, fromAttrInfo, toAttrInfo)
    local diff = toAttrInfo.modifiedValue - fromAttrInfo.modifiedValue
    local isIncrease = diff > ATTRIBUTE_COMPARE_EPSILON
    local isDecrease = diff < -ATTRIBUTE_COMPARE_EPSILON
    cell.upArrow.gameObject:SetActive(isIncrease)
    cell.downArrow.gameObject:SetActive(isDecrease)
    cell.arrowNode.gameObject:SetActive(isIncrease or isDecrease)
end


EquipPresetGroupCtrl._RefreshMainSubBonusCell =
    HL.Method(HL.Table, HL.String, HL.Number) << function(self, cell, sourceType, value)
    local info = AttributeUtils.generateAttributeShowInfo(sourceType, value, {
        attrModifier = GEnums.ModifierType.BaseAddition,
        forceShow = true,
        forceShowPercent = UIConst.ATTRIBUTE_GENERATE_FORCE_PERCENT.NO_PERCENT,
    })
    local hasValue = math.abs(value) > ATTRIBUTE_COMPARE_EPSILON
    cell.attributeText.text = sourceType == "Main"
        and Language.LUA_EQUIP_PRESET_GROUP_MAIN_ATTR_BONUS
        or Language.LUA_EQUIP_PRESET_GROUP_SUB_ATTR_BONUS
    cell.attributeText.maxVisibleCharacters = hasValue and 99999 or 0
    cell.fromValue.text = ""
    if hasValue then
        cell.fromValue.text = info.modifiedValue > 0
            and string.format(Language.LUA_WEAPON_EXHIBIT_UPGRADE_ADD_FORMAT, info.showValue)
            or info.showValue
    end
    cell.circleNode.gameObject:SetActive(hasValue)
    cell.arrowNode.gameObject:SetActive(false)
    cell.toValue.gameObject:SetActive(false)
    cell.toValueDeco.gameObject:SetActive(false)
end

EquipPresetGroupCtrl._RefreshGroupAttrNode =
    HL.Method(HL.Userdata, HL.Table, HL.Table, HL.Forward("UIListCache")) << function(
        self, weaponAttributeNode, data, compareData, bonusCellCache)
    weaponAttributeNode:_FirstTimeInit()
    local showZeroAttributes = data.showZeroAttributes == true
    local orderedRows, bonusRows = {}, {}

    weaponAttributeNode.m_mainAttributeCellCache:Refresh(data.defShowInfo and 1 or 0, function(cell, index)
        weaponAttributeNode:_RefreshAttributeCell(cell, data.defShowInfo, true)
        self:_RefreshGroupCompareArrow(cell, compareData.defShowInfo, data.defShowInfo)
        table.insert(orderedRows, { cell = cell })
    end)

    weaponAttributeNode.m_subAttributeCellCache:Refresh(#data.mainAttrShowInfos, function(cell, index)
        local attrShowInfo = data.mainAttrShowInfos[index]
        cell.gameObject:SetActive(showZeroAttributes or math.abs(attrShowInfo.attributeValue) > ATTRIBUTE_COMPARE_EPSILON)
        weaponAttributeNode:_RefreshAttributeCell(cell, attrShowInfo, true)
        self:_RefreshGroupCompareArrow(cell, compareData.mainAttrShowInfos[index], attrShowInfo)
        table.insert(orderedRows, { cell = cell })
        for _, sourceType in ipairs(attrShowInfo.mainSubBonusTypes or {}) do
            local row = {
                sourceType = sourceType,
                value = (attrShowInfo.mainSubBonuses or {})[sourceType] or 0,
            }
            table.insert(orderedRows, row)
            table.insert(bonusRows, row)
        end
    end)

    weaponAttributeNode.m_extraAttributeCellCache:Refresh(#data.extraAttrShowInfos, function(cell, index)
        local attrShowInfo = data.extraAttrShowInfos[index]
        cell.gameObject:SetActive(showZeroAttributes or math.abs(attrShowInfo.attributeValue) > ATTRIBUTE_COMPARE_EPSILON)
        weaponAttributeNode:_RefreshAttributeCell(cell, attrShowInfo, true)
        table.insert(orderedRows, { cell = cell })
    end)
    bonusCellCache:Refresh(#bonusRows, function(cell, index)
        local row = bonusRows[index]
        self:_RefreshMainSubBonusCell(cell, row.sourceType, row.value)
        row.cell = cell
    end)
    
    for index, row in ipairs(orderedRows) do
        row.cell.transform:SetSiblingIndex(index)
    end
end



EquipPresetGroupCtrl._RefreshGroupSuitNode = HL.Method(HL.Userdata, HL.Table) << function(self, equipSuitNode, data)
    equipSuitNode:_FirstTimeInit()
    equipSuitNode.view.equipEmptySuitNode.gameObject:SetActive(false)

    local enabledSuitCfg, enabledSuitCount
    for _, suitInfo in ipairs(data.suitInfoList) do
        local _, totalSuitCfg = Tables.equipSuitTable:TryGetValue(suitInfo.suitId)
        local firstSuitCfg = totalSuitCfg and totalSuitCfg.list[0] or nil
        if firstSuitCfg and suitInfo.suitCount >= firstSuitCfg.equipCnt then
            enabledSuitCfg = firstSuitCfg
            enabledSuitCount = suitInfo.suitCount
            break
        end
    end
    local hasEnabledSuit = enabledSuitCfg ~= nil

    equipSuitNode.view.charEmptySuitNode.gameObject:SetActive(not hasEnabledSuit)
    equipSuitNode.view.suitGroupNode.gameObject:SetActive(hasEnabledSuit)
    equipSuitNode.view.suitTitle.gameObject:SetActive(hasEnabledSuit)
    if not hasEnabledSuit then
        return
    end

    equipSuitNode.view.suitName.text = enabledSuitCfg.suitName
    equipSuitNode.view.suitLogo:LoadSprite(equipSuitNode:_GetLogoFolder(), enabledSuitCfg.suitLogoName)
    equipSuitNode.view.suitNum.text = string.format(Language.LUA_CHAR_INFO_SUIT_EQUIP_NUM_FORMAT, enabledSuitCount, enabledSuitCfg.equipCnt)
    equipSuitNode.m_suitDescCellCache:Refresh(1, function(cell, index)
        cell.wearingNumTxt.text = string.format(Language.LUA_CHAR_INFO_SUIT_EQUIP_NUM_FORMAT, enabledSuitCount, enabledSuitCfg.equipCnt)
        local skillDesc = CharInfoUtils.getSkillDesc(enabledSuitCfg.skillID, enabledSuitCfg.skillLv)
        cell.desc:SetAndResolveTextStyle(skillDesc)
        cell.desc.color = equipSuitNode.view.config.TEXT_COLOR_ENABLE
    end)
end



EquipPresetGroupCtrl._RefreshGroupView =
    HL.Method(HL.Table, HL.Table, HL.Table, HL.Forward("UIListCache"), HL.Opt(HL.Table)) << function(
        self, groupInfoView, groupDetailsView, data, bonusCellCache, compareData)
    if groupInfoView.name then
        groupInfoView.name.text = data.name
    end
    if groupDetailsView.weaponAttributeNode then
        self:_RefreshGroupAttrNode(groupDetailsView.weaponAttributeNode, data, compareData or data, bonusCellCache)
    end
    if groupDetailsView.equipSuitNode then
        self:_RefreshGroupSuitNode(groupDetailsView.equipSuitNode, data)
    end
end


EquipPresetGroupCtrl._RefreshSelectedGroupInfo = HL.Method() << function(self)
    local equipInstIds = self:_GetSelectedEquipInstIds()
    local selectedPreset = self:_GetSelectedPreset()
    local name = self:_IsCurrentEquipSelected() and Language.LUA_EQUIP_PRESET_GROUP_CURRENT_EQUIP_NAME
        or (selectedPreset and selectedPreset.name or "")
    local data = self:_BuildGroupViewData(equipInstIds, name)
    local detailView = self.view.equipDetailNode
    self:_RefreshGroupView(detailView.selectView, detailView.selectDetailsView, data, self.m_selectAttrBonusCellCache)
    self:_RefreshDetailActionState()
end


EquipPresetGroupCtrl._PlaySelectedGroupRefreshAnimation = HL.Method() << function(self)
    local animationWrapper = self.view.equipDetailNode.selectView.animationWrapper
    animationWrapper:ClearTween(false)
    animationWrapper:PlayInAnimation()
end

EquipPresetGroupCtrl._CanCreatePresetGroup = HL.Method().Return(HL.Boolean) << function(self)
    local presetCount = self.m_allPresetGroupList and #self.m_allPresetGroupList or 0
    return presetCount < Tables.globalConst.totalEquipPresetGroupCount
end

EquipPresetGroupCtrl._GetDefaultCreatePresetName = HL.Method().Return(HL.String) << function(self)
    local nextIndex = (self.m_allPresetGroupList and #self.m_allPresetGroupList or 0) + 1
    return string.format(Language.LUA_EQUIP_PRESET_GROUP_DEFAULT_NAME_FORMAT, nextIndex)
end

EquipPresetGroupCtrl._ResetCreatePresetNameInput = HL.Method() << function(self)
    local inputField = self.view.equipDetailNode.selectView.inputField
    local defaultName = self:_GetDefaultCreatePresetName()
    inputField.placeholder.text = defaultName
    inputField.text = defaultName
end

EquipPresetGroupCtrl._RefreshDetailActionState = HL.Method() << function(self)
    local selectView = self.view.equipDetailNode.selectView
    local isCurrentEquipSelected = self:_IsCurrentEquipSelected()
    local hasCurrentEquip = #self:_GetCurrentEquipInstIds() > 0
    local hasPresetCapacity = self:_CanCreatePresetGroup()
    local canCreatePreset = isCurrentEquipSelected and hasCurrentEquip and hasPresetCapacity
        and Utils.isInMainScope()

    if not canCreatePreset then
        selectView.inputNaviGroup:ManuallyStopFocus()
    end
    selectView.editNode.gameObject:SetActive(canCreatePreset)
    selectView.inputField.gameObject:SetActive(canCreatePreset)
    selectView.limitNode.gameObject:SetActive(
        isCurrentEquipSelected and hasCurrentEquip and not hasPresetCapacity)
    selectView.editBtn.gameObject:SetActive(not isCurrentEquipSelected)
    
    local inputField = selectView.inputField
    local defaultName = self:_GetDefaultCreatePresetName()
    if inputField.text == inputField.placeholder.text then
        inputField.text = defaultName
    end
    inputField.placeholder.text = defaultName
    local actionState = isCurrentEquipSelected
        and (hasCurrentEquip and "SaveBtnState" or "DisableState")
        or "ApplyBtnState"
    selectView.actionStateController:SetState(actionState)
    Notify(MessageConst.REFRESH_CONTROLLER_HINT)
    selectView.saveBtn.interactable = not isCurrentEquipSelected or canCreatePreset
end





EquipPresetGroupCtrl._InitCompareScroll = HL.Method() << function(self)
    self.view.equipDetailNode.sharedScrollRect:StopMovement()
    self:_RefreshCompareScrollInput()
end

EquipPresetGroupCtrl._RefreshCompareScrollInput = HL.Method() << function(self)
    self.view.equipDetailNode.sharedScrollRect.controllerScrollEnabled =
        self.m_isInCompare and DeviceInfo.usingController
end


EquipPresetGroupCtrl._SetCompare = HL.Method(HL.Boolean) << function(self, isInCompare)
    if self.m_isInCompare == isInCompare then
        return
    end
    if isInCompare and self:_IsCurrentEquipSelected() then
        return
    end
    self:_ExitItemFocus()
    self.m_isInCompare = isInCompare
    if self.m_isInCompare then
        self:_RefreshCompareInfo()
    else
        
        self:_RefreshSelectedGroupInfo()
    end
    self:_RefreshCompareState()
end

EquipPresetGroupCtrl._ApplyCompareClosedState = HL.Method() << function(self)
    local detailView = self.view.equipDetailNode
    self.view.compareStateController:SetState("Close")
    self.m_compareVisualState = COMPARE_VISUAL_STATE_CLOSED
    detailView.shrinkButton.interactable = true
    detailView.compareButton.gameObject:SetActive(not self:_IsCurrentEquipSelected())
    self:_RefreshItemFocusBindings()
end

EquipPresetGroupCtrl._TryCompleteCompareClose = HL.Method(HL.Number) << function(self, transitionId)
    if transitionId ~= self.m_compareTransitionId or self.m_isInCompare then
        return
    end
    self:_ApplyCompareClosedState()
end

EquipPresetGroupCtrl._PlayCompareInAnimations = HL.Method() << function(self)
    local detailView = self.view.equipDetailNode
    self.m_compareTransitionId = self.m_compareTransitionId + 1
    self.view.compareStateController:SetState("Expend")
    detailView.shrinkButton.interactable = true
    
    if self.m_compareVisualState ~= COMPARE_VISUAL_STATE_VISIBLE then
        if self.m_compareVisualState == COMPARE_VISUAL_STATE_CLOSING then
            detailView.compareView.animationWrapper:ClearTween(false)
            detailView.compareContentAnimation:ClearTween(false)
            self.view.bgMaskAnimation:ClearTween(false)
        end
        detailView.compareView.animationWrapper:PlayInAnimation()
        detailView.compareContentAnimation:PlayInAnimation()
        self.view.bgMaskAnimation:PlayInAnimation()
    end
    self.m_compareVisualState = COMPARE_VISUAL_STATE_VISIBLE
end

EquipPresetGroupCtrl._PlayCompareOutAnimations = HL.Method() << function(self)
    local detailView = self.view.equipDetailNode
    self.m_compareVisualState = COMPARE_VISUAL_STATE_CLOSING
    self.m_compareTransitionId = self.m_compareTransitionId + 1
    local transitionId = self.m_compareTransitionId
    local pendingAnimationCount = 3
    detailView.shrinkButton.interactable = false
    local function onOutAnimationComplete()
        pendingAnimationCount = pendingAnimationCount - 1
        if pendingAnimationCount == 0 then
            self:_TryCompleteCompareClose(transitionId)
        end
    end
    detailView.compareView.animationWrapper:PlayOutAnimation(onOutAnimationComplete)
    detailView.compareContentAnimation:PlayOutAnimation(onOutAnimationComplete)
    self.view.bgMaskAnimation:PlayOutAnimation(onOutAnimationComplete)
    self:_RefreshItemFocusBindings()
end

EquipPresetGroupCtrl._RefreshCompareActionInput = HL.Method() << function(self)
    local canEdit = not (DeviceInfo.usingController and self.m_isInCompare)
    InputManagerInst:ToggleGroup(self.view.charListNode.charList.naviBindingGroupId, canEdit)
    self.view.equipDetailNode.selectView.editBtn.interactable = canEdit
    self.view.presetListNode.scrollList:UpdateShowingCells(function(_, object)
        local cell = self.m_getPresetCell(object)
        if cell and cell.presetId then
            cell.deleteBtn.gameObject:SetActive(canEdit)
            cell.topBtn.gameObject:SetActive(canEdit)
            cell.renameBtn.interactable = canEdit
        end
    end)
end

EquipPresetGroupCtrl._RefreshCompareState = HL.Method() << function(self)
    self:_RefreshCompareActionInput()
    local canCompare = not self:_IsCurrentEquipSelected()
    local isCompareExpanded = canCompare and self.m_isInCompare
    local detailView = self.view.equipDetailNode
    detailView.autoCloseArea.enabled = isCompareExpanded
    detailView.sharedScrollRect:StopMovement()

    if isCompareExpanded then
        self:_PlayCompareInAnimations()
        self:_RefreshCompareScrollInput()
        self:_RefreshItemFocusBindings()
        return
    end

    self:_RefreshCompareScrollInput()
    if self.m_compareVisualState == COMPARE_VISUAL_STATE_VISIBLE then
        self:_PlayCompareOutAnimations()
        return
    elseif self.m_compareVisualState == COMPARE_VISUAL_STATE_CLOSING then
        return
    end

    self:_ApplyCompareClosedState()
end



EquipPresetGroupCtrl._RefreshCompareInfo = HL.Method() << function(self)
    local leftData = self:_BuildGroupViewData(
        self:_GetCurrentEquipInstIds(), Language.LUA_EQUIP_PRESET_GROUP_CURRENT_EQUIP_NAME)
    local selectedPreset = self:_GetSelectedPreset()
    local rightData = self:_BuildGroupViewData(
        self:_GetSelectedEquipInstIds(), selectedPreset and selectedPreset.name or "")
    leftData.mainAttrShowInfos = self:_MergeMainSubAttributeShowInfos(leftData.mainAttrShowInfos)
    rightData.mainAttrShowInfos = self:_MergeMainSubAttributeShowInfos(rightData.mainAttrShowInfos)
    self:_AlignCompareGroupViewData(leftData, rightData)

    local detailView = self.view.equipDetailNode
    self:_RefreshGroupView(detailView.compareView, detailView.compareDetailsView, leftData, self.m_compareAttrBonusCellCache)
    self:_RefreshGroupView(detailView.selectView, detailView.selectDetailsView, rightData, self.m_selectAttrBonusCellCache, leftData)
end






EquipPresetGroupCtrl._InitPresetList = HL.Method() << function(self)
    local list = self.view.presetListNode.scrollList
    self.m_getPresetCell = UIUtils.genCachedCellFunction(list)
    list.onUpdateCell:AddListener(function(object, csIndex)
        local cell = self.m_getPresetCell(object)
        cell.csIndex = csIndex
        cell.transform.sizeDelta = CS.UnityEngine.Vector2(list.cellWidth, list.cellHeight)
        
        cell.selectionStateController.enabled = false
        self:_RefreshPresetCell(cell, LuaIndex(csIndex))
        cell.selectionStateController.enabled = true
        if cell.presetId then
            self:_BindPresetRowNavigation(cell.selectBtn, LuaIndex(csIndex))
        end
        if not self.m_presetListPlayingIn then
            cell.animationWrapper:ClearTween(false)
            cell.animationWrapper:SampleClipAtPercent(PRESET_CELL_SAVE_IN_ANIMATION, 1, false)
            cell.animationWrapper:SampleClipAtPercent(PRESET_CELL_IN_ANIMATION, 1, false)
        end
        self:_RefreshItemFocusBindings()
        self:_RefreshControllerHints()
    end)
    list.onGraduallyShowFinish:AddListener(function()
        self.m_presetListPlayingIn = false
    end)
    self:_BindPresetRowNavigation(self.view.currentEquipNode.selectBtn, 0)
    self:_SetPresetListEmptyMode(false)
    self:_RefreshPresetListScrollInput()
end

EquipPresetGroupCtrl._SetPresetListEmptyMode = HL.Method(HL.Boolean) << function(self, isEmpty)
    if self.m_presetListEmptyMode == isEmpty then
        return
    end
    local view = self.view.presetListNode
    local list, content = view.scrollList, view.container
    local Vector2 = CS.UnityEngine.Vector2
    view.scrollRect:StopMovement()
    view.scrollRect:KillScrollTween()
    list:UpdateCount(0, false, false, false, true)
    list.enabled = false

    
    content.anchorMin = Vector2(0, isEmpty and 0 or 1)
    content.anchorMax = Vector2(1, 1)
    content.pivot = Vector2(0.5, 1)
    content.sizeDelta = Vector2.zero
    content.anchoredPosition = Vector2.zero
    view.filterEmptyNode.gameObject:SetActive(isEmpty)
    view.presetLayout.enabled = true
    view.containerLayout.enabled = true
    view.containerFitter.enabled = not isEmpty
    LayoutRebuilder.ForceRebuildLayoutImmediate(content)
    self.m_presetListEmptyMode = isEmpty
    if isEmpty then
        return
    end

    
    local topPadding = content.rect.height - view.containerLayout.padding.bottom
    view.containerFitter.enabled = false
    view.containerLayout.enabled = false
    view.presetLayout.enabled = false
    for _, rect in ipairs({ self.view.currentEquipNode.transform, view.presetNode }) do
        rect.anchorMin = Vector2(0, 1)
        rect.anchorMax = Vector2(1, 1)
        rect.sizeDelta = Vector2(0, rect.sizeDelta.y)
        rect.anchoredPosition = Vector2(0, rect.anchoredPosition.y)
    end
    content.anchorMin = Vector2(0, 1)
    content.anchorMax = Vector2(0, 1)
    content.pivot = Vector2(0, 1)
    content.sizeDelta = Vector2(view.scrollRect.viewport.rect.width, content.rect.height)
    list:SetPaddingTop(topPadding)
    list.enabled = true
end

EquipPresetGroupCtrl._GetPresetRowNaviTarget =
    HL.Method(HL.Number).Return(HL.Opt(HL.Userdata)) << function(self, index)
    if index == 0 then
        return self.view.currentEquipNode.selectBtn
    end
    if self.m_presetListEmptyMode or index < 1 or index > #self.m_presetGroupList then
        return nil
    end
    local cell = self.m_getPresetCell(index)
    if not cell or not cell.gameObject.activeInHierarchy then
        self:_CompletePresetCellInAnimations()
        self.view.presetListNode.scrollList:ScrollToIndex(CSIndex(index), true)
        cell = self.m_getPresetCell(index)
    end
    return cell and cell.selectBtn or nil
end

EquipPresetGroupCtrl._BindPresetRowNavigation =
    HL.Method(HL.Userdata, HL.Number) << function(self, button, index)
    button.customNaviTargetInDirFunc = function(dir)
        local direction = CS.UnityEngine.UI.NaviDirection
        local targetIndex
        if dir == direction.Up then
            targetIndex = index - 1
        elseif dir == direction.Down then
            targetIndex = index + 1
        else
            return nil
        end
        if self:_IsPresetDeleteAnimationPlaying() or targetIndex < 0 then
            return button
        end
        return self:_GetPresetRowNaviTarget(targetIndex) or button
    end
end

EquipPresetGroupCtrl._GetPresetCellAnimationWrapper =
    HL.Method(HL.Table).Return(HL.Opt(CS.Beyond.UI.UIAnimationWrapper)) << function(self, cell)
    return cell.animationWrapper
end


EquipPresetGroupCtrl._CompletePresetCellInAnimations = HL.Method() << function(self)
    if not self.m_getPresetCell then
        return
    end
    self.m_presetListPlayingIn = false
    local list = self.view.presetListNode.scrollList
    list:SkipGraduallyShow()
    list:UpdateShowingCells(function(_, object)
        local cell = self.m_getPresetCell(object)
        local animationWrapper = self:_GetPresetCellAnimationWrapper(cell)
        if animationWrapper then
            animationWrapper:ClearTween(false)
            animationWrapper:SampleClipAtPercent(PRESET_CELL_SAVE_IN_ANIMATION, 1, false)
            animationWrapper:SampleClipAtPercent(PRESET_CELL_IN_ANIMATION, 1, false)
        end
    end)
end

EquipPresetGroupCtrl._FindPresetCellById =
    HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, presetId)
    for index, data in ipairs(self.m_presetGroupList or {}) do
        if data.presetId == presetId then
            local cell = self.m_getPresetCell(index)
            if cell and cell.presetId == presetId then
                return cell
            end
            return
        end
    end
end

EquipPresetGroupCtrl._HasServerPresetGroup = HL.Method(HL.Number).Return(HL.Boolean) << function(self, presetId)
    local groups = GameInstance.player.equipPresetGroupSystem.equipPresetGroups
    for index = 0, groups.Count - 1 do
        if groups[index].presetId == presetId then
            return true
        end
    end
    return false
end

EquipPresetGroupCtrl._FindCreatedPresetId =
    HL.Method(HL.Table).Return(HL.Opt(HL.Number)) << function(self, pendingAction)
    local existingPresetIdMap = pendingAction.existingPresetIdMap
    if not existingPresetIdMap then
        return
    end

    local firstCreatedPresetId
    local groups = GameInstance.player.equipPresetGroupSystem.equipPresetGroups
    for index = 0, groups.Count - 1 do
        local group = groups[index]
        if not existingPresetIdMap[group.presetId] then
            firstCreatedPresetId = firstCreatedPresetId or group.presetId
            if group.name == pendingAction.name then
                return group.presetId
            end
        end
    end
    return firstCreatedPresetId
end

EquipPresetGroupCtrl._IsPresetDeleteAnimationPlaying = HL.Method().Return(HL.Boolean) << function(self)
    local pendingAction = self.m_pendingPresetListAction
    return pendingAction ~= nil
        and pendingAction.actionType == PRESET_LIST_ACTION_DELETE
        and pendingAction.isAnimating == true
end


EquipPresetGroupCtrl._CompleteCurrentEquipSaveInAnimation = HL.Method() << function(self)
    local playing = self.m_currentEquipSaveAnimation
    if not playing then
        return
    end
    self.m_currentEquipSaveAnimation = nil

    local currentEquipView = self.view.currentEquipNode
    local animationWrapper = currentEquipView.saveAnimationWrapper
    local slgBgAnimationWrapper = currentEquipView.slgBgAnimationWrapper

    animationWrapper:ClearTween(false)
    animationWrapper:SampleClipAtPercent(CURRENT_EQUIP_SAVE_IN_ANIMATION, 1, false)

    
    
    slgBgAnimationWrapper:ClearTween(false)
    slgBgAnimationWrapper:SampleToInAnimationEnd()
    currentEquipView.selectionStateController:SetState(
        self:_IsCurrentEquipSelected() and "SelectColor" or "NorColor")
    slgBgAnimationWrapper.autoPlay = playing.slgBgAutoPlay
end

EquipPresetGroupCtrl._PlayCurrentEquipSaveInAnimation = HL.Method() << function(self)
    self:_CompleteCurrentEquipSaveInAnimation()

    local currentEquipView = self.view.currentEquipNode
    local animationWrapper = currentEquipView.saveAnimationWrapper
    local slgBgAnimationWrapper = currentEquipView.slgBgAnimationWrapper
    self.m_currentEquipSaveAnimation = {
        slgBgAutoPlay = slgBgAnimationWrapper.autoPlay,
    }

    
    slgBgAnimationWrapper.autoPlay = false
    slgBgAnimationWrapper:ClearTween(false)
    animationWrapper:ClearTween(false)
    animationWrapper:Play(CURRENT_EQUIP_SAVE_IN_ANIMATION, function()
        self:_CompleteCurrentEquipSaveInAnimation()
    end)
    AudioAdapter.PostEvent("Au_UI_Toast_EquipSaveMotion")
    slgBgAnimationWrapper.gameObject:SetActive(true)
end

EquipPresetGroupCtrl._PlayPresetCellSaveInAnimation = HL.Method(HL.Number) << function(self, presetId)
    local cell = self:_FindPresetCellById(presetId)
    local animationWrapper = cell and self:_GetPresetCellAnimationWrapper(cell) or nil
    if not animationWrapper then
        return
    end
    animationWrapper:ClearTween(false)
    animationWrapper:Play(PRESET_CELL_SAVE_IN_ANIMATION)
    AudioAdapter.PostEvent("Au_UI_Toast_EquipSaveMotion")
end

EquipPresetGroupCtrl._ReleasePresetDeleteCell = HL.Method(HL.Table) << function(self, pendingAction)
    local csIndex = pendingAction.cellIndex
    if csIndex == nil then
        return
    end
    local cell = self.m_getPresetCell(LuaIndex(csIndex))
    if cell then
        cell.animationWrapper:ClearTween(false)
        cell.animationWrapper:SampleClipAtPercent(PRESET_CELL_SAVE_OUT_ANIMATION, 0, false)
        self.view.presetListNode.scrollList:SetCellCanCache(csIndex, true)
    end
    pendingAction.cellIndex = nil
end

EquipPresetGroupCtrl._FinishDeletedPresetListAction = HL.Method(HL.Table) << function(self, pendingAction)
    if self.m_pendingPresetListAction ~= pendingAction then
        return
    end
    self:_ReleasePresetDeleteCell(pendingAction)
    self.m_pendingPresetListAction = nil
    self.m_pendingPresetScrollMode = PRESET_SCROLL_MODE_NONE
    if self.m_curSelectedPresetId == pendingAction.presetId then
        self:_SetSelectedPresetId(
            pendingAction.fallbackPresetId or CURRENT_EQUIP_PRESET_ID)
    end
    self:_RefreshPresetList()
    self:_RestoreControllerNaviTarget()
end

EquipPresetGroupCtrl._PlayPresetCellSaveOutAnimation = HL.Method(HL.Table) << function(self, pendingAction)
    self:_CompletePresetCellInAnimations()
    local cell = self:_FindPresetCellById(pendingAction.presetId)
    local animationWrapper = cell and self:_GetPresetCellAnimationWrapper(cell) or nil
    if not animationWrapper then
        self:_FinishDeletedPresetListAction(pendingAction)
        return
    end

    pendingAction.cellIndex = cell.csIndex
    self.view.presetListNode.scrollList:SetCellCanCache(cell.csIndex, false)
    animationWrapper:ClearTween(false)
    animationWrapper:Play(PRESET_CELL_SAVE_OUT_ANIMATION, function()
        self:_FinishDeletedPresetListAction(pendingAction)
    end)
end

EquipPresetGroupCtrl._RefreshPresetListScrollInput = HL.Method() << function(self)
    
    self.view.presetListNode.scrollRect.disableScroll = DeviceInfo.usingController
end

EquipPresetGroupCtrl._OnInputDeviceTypeChanged = HL.Method(HL.Table) << function(self, _)
    self:_ExitItemFocus()
    self:_RefreshPresetListScrollInput()
    self:_RefreshCompareScrollInput()
    self:_RefreshCompareActionInput()
    for _, context in pairs(self.m_itemFocusRows or {}) do
        self:_RefreshItemFocusExtraInfo(context)
    end
    self:_RefreshItemFocusBindings()
    self:_RefreshControllerHints()
end

EquipPresetGroupCtrl._ConsumePendingPresetListSelection =
    HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local pendingAction = self.m_pendingPresetListAction
    if not pendingAction or pendingAction.isAnimating then
        return
    end

    if pendingAction.actionType == PRESET_NAME_ACTION_CREATE then
        local createdPresetId = self:_FindCreatedPresetId(pendingAction)
        if not createdPresetId then
            return
        end
        self.m_pendingPresetListAction = nil
        pendingAction.presetId = createdPresetId
        self:_SetSelectedPresetId(createdPresetId)
        Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_PRESET_GROUP_SAVE_SUCCESS_TOAST)
    elseif pendingAction.actionType == PRESET_LIST_ACTION_DELETE then
        if not pendingAction.presetId or self:_HasServerPresetGroup(pendingAction.presetId) then
            return
        end
        pendingAction.isAnimating = true
    else
        return
    end
    return pendingAction
end

EquipPresetGroupCtrl._ScrollSelectedPresetIntoView =
    HL.Method(HL.Number) << function(self, scrollMode)
    if scrollMode == PRESET_SCROLL_MODE_NONE or self:_IsCurrentEquipSelected() then
        return
    end
    local view = self.view.presetListNode
    if scrollMode == PRESET_SCROLL_MODE_TOP then
        self:_CompletePresetCellInAnimations()
        view.scrollList:ScrollToIndex(0, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Top)
        view.scrollRect.verticalNormalizedPosition = 1
        return
    end
    for index, data in ipairs(self.m_presetGroupList) do
        if data.presetId == self.m_curSelectedPresetId then
            local target = self:_GetPresetRowNaviTarget(index)
            if target then
                view.scrollRect:AutoScrollToRectTransform(target.transform, true)
            end
            return
        end
    end
end



EquipPresetGroupCtrl._OnPresetGroupChanged = HL.Method() << function(self)
    if self:_IsPresetDeleteAnimationPlaying() then
        return
    end

    self:_RefreshCurrentEquipInfo()
    local resolvedAction = self:_ConsumePendingPresetListSelection()
    if resolvedAction and resolvedAction.actionType == PRESET_LIST_ACTION_DELETE then
        self:_PlayPresetCellSaveOutAnimation(resolvedAction)
        return
    end

    local shouldConsumeScrollMode = resolvedAction ~= nil
        or self.m_pendingPresetListAction == nil
    local scrollMode = shouldConsumeScrollMode
        and self.m_pendingPresetScrollMode or PRESET_SCROLL_MODE_NONE
    if shouldConsumeScrollMode then
        self.m_pendingPresetScrollMode = PRESET_SCROLL_MODE_NONE
    end
    self:_RefreshPresetList()
    self:_ScrollSelectedPresetIntoView(scrollMode)
    if resolvedAction and resolvedAction.actionType == PRESET_NAME_ACTION_CREATE then
        self:_ResetCreatePresetNameInput()
        self:_PlayPresetCellSaveInAnimation(resolvedAction.presetId)
    end
    self:_RestoreControllerNaviTarget()
end


EquipPresetGroupCtrl._OnPresetGroupApplied = HL.Method(HL.Table) << function(self, args)
    local charInstId, presetId = unpack(args)
    local pendingApply = self.m_pendingApply
    local isExpectedApply = pendingApply
        and pendingApply.charInstId == charInstId
        and pendingApply.presetId == presetId
    if isExpectedApply then
        self.m_pendingApply = nil
    end

    self:_RefreshCurrentEquipInfo()
    
    if self.m_curCharInfo.instId == charInstId then
        self:_ResetCreatePresetNameInput()
    end
    if isExpectedApply and self.m_curCharInfo.instId == charInstId then
        self:_SetSelectedPresetId(CURRENT_EQUIP_PRESET_ID)
        self:_RefreshPresetList(true)
        self:_PlayCurrentEquipSaveInAnimation()
        self:_RestoreControllerNaviTarget()
    else
        self:_RefreshPresetList()
    end

    if isExpectedApply then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_PRESET_GROUP_APPLY_SUCCESS_TOAST)
    end
end


EquipPresetGroupCtrl._GetActivatedSuitIdMap = HL.Method(HL.Table).Return(HL.Table) << function(self, presetData)
    local activatedSuitIdMap = {}
    local equipInstIds = self:_GetEquipInstIdsFromInfos(presetData.equipInfos)
    for _, suitInfo in ipairs(self:_GetEquipListSuitInfoList(equipInstIds)) do
        local _, totalSuitCfg = Tables.equipSuitTable:TryGetValue(suitInfo.suitId)
        local firstSuitCfg = totalSuitCfg and totalSuitCfg.list[0] or nil
        if firstSuitCfg and suitInfo.suitCount >= firstSuitCfg.equipCnt then
            activatedSuitIdMap[suitInfo.suitId] = true
        end
    end
    return activatedSuitIdMap
end





EquipPresetGroupCtrl._IsPresetPassFilter =
    HL.Method(HL.Table, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, presetData, selectedTags)
    if not selectedTags or not next(selectedTags) then
        return true
    end

    local suitTags = {}
    local equipTags = {}
    for _, tagInfo in ipairs(selectedTags) do
        if tagInfo.groupType == "Suit" then
            table.insert(suitTags, tagInfo)
        else
            table.insert(equipTags, tagInfo)
        end
    end

    if #suitTags > 0 then
        local activatedSuitIdMap = self:_GetActivatedSuitIdMap(presetData)
        local hasActivatedSuit = next(activatedSuitIdMap) ~= nil
        local isSuitPass = false
        for _, tagInfo in ipairs(suitTags) do
            if (tagInfo.param == "" and not hasActivatedSuit) or activatedSuitIdMap[tagInfo.param] then
                isSuitPass = true
                break
            end
        end
        if not isSuitPass then
            return false
        end
    end

    if #equipTags == 0 then
        return true
    end
    for _, equipInfo in ipairs(presetData.equipInfos) do
        if not equipInfo.isEmpty and equipInfo.equipCfg then
            
            local filterItemInfo = {
                equipData = equipInfo.equipCfg,
            }
            if FilterUtils.checkIfPassFilter(filterItemInfo, equipTags) then
                return true
            end
        end
    end
    return false
end

EquipPresetGroupCtrl._ApplyPresetFilter = HL.Method(HL.Opt(HL.Table)) << function(self, selectedTags)
    if not selectedTags or not next(selectedTags) then
        self.m_presetGroupList = self.m_allPresetGroupList
        return
    end

    local filteredList = {}
    for _, presetData in ipairs(self.m_allPresetGroupList) do
        if self:_IsPresetPassFilter(presetData, selectedTags) then
            table.insert(filteredList, presetData)
        end
    end
    self.m_presetGroupList = filteredList
end

EquipPresetGroupCtrl._GetPresetFilterResultCount =
    HL.Method(HL.Table).Return(HL.Number) << function(self, selectedTags)
    local resultCount = 0
    for _, presetData in ipairs(self.m_allPresetGroupList or {}) do
        if self:_IsPresetPassFilter(presetData, selectedTags) then
            resultCount = resultCount + 1
        end
    end
    return resultCount
end


EquipPresetGroupCtrl._OnFilterConfirm = HL.Method(HL.Opt(HL.Table)) << function(self, selectedTags)
    if self:_IsPresetDeleteAnimationPlaying() then
        return
    end
    self.m_filterTags = selectedTags and lume.deepCopy(selectedTags) or {}
    self:_ApplyPresetFilter(self.m_filterTags)
    self:_RefreshPresetListView()
    self:_RestoreControllerNaviTarget()
end



EquipPresetGroupCtrl._RefreshPresetListView =
    HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, resetToTop, playCellIn)
    self:_CompleteCurrentEquipSaveInAnimation()
    self:_ExitItemFocus()
    self:_CompletePresetCellInAnimations()
    local hasFilter = self.m_filterTags and next(self.m_filterTags) ~= nil

    
    local isCurrentEquipSelected = self:_IsCurrentEquipSelected()
    if not isCurrentEquipSelected and not self:_FindPresetById(self.m_curSelectedPresetId) then
        self:_SetSelectedPresetId(CURRENT_EQUIP_PRESET_ID)
        isCurrentEquipSelected = true
    end

    self.view.currentEquipNode.selectionStateController:SetState(
        isCurrentEquipSelected and "SelectColor" or "NorColor", false)
    self:_RefreshCompareState()

    local totalCount = Tables.globalConst.totalEquipPresetGroupCount
    self.view.presetListNode.setNumText.text = string.format("%d/%d", #self.m_allPresetGroupList, totalCount)

    local displayCount = hasFilter
        and #self.m_presetGroupList
        or math.max(#self.m_presetGroupList, totalCount)
    self:_SetPresetListEmptyMode(hasFilter and displayCount == 0)
    if not self.m_presetListEmptyMode then
        self.m_presetListPlayingIn = playCellIn == true
        self.view.presetListNode.scrollList:UpdateCount(
            displayCount, resetToTop == true, false, false, not self.m_presetListPlayingIn)
    end
    self.view.presetListNode.scrollRect:ClampContentToBounds()
    self:_RefreshItemFocusBindings()
    self:_RefreshControllerHints()
    if resetToTop then
        self.view.presetListNode.scrollRect.verticalNormalizedPosition = 1
    end

    self:_RefreshSelectedGroupInfo()
    if self.m_isInCompare then
        self:_RefreshCompareInfo()
    end
end



EquipPresetGroupCtrl._RefreshPresetList =
    HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, resetToTop, playCellIn)
    local allList = {}
    local groups = GameInstance.player.equipPresetGroupSystem.equipPresetGroups
    for i = 0, groups.Count - 1 do
        local group = groups[i]
        local equipInfos = {}
        for _, slotIndex in ipairs(EQUIP_PRESET_SLOT_INDICES) do
            local hasEquip, equipInstId = group.equips:TryGetValue(slotIndex)
            local info = hasEquip and self:_BuildEquipInfo(equipInstId, slotIndex) or nil
            table.insert(equipInfos, info or { slotIndex = slotIndex, isEmpty = true })
        end

        table.insert(allList, {
            index      = LuaIndex(i),
            name       = group.name,
            presetId   = group.presetId,
            equipInfos = equipInfos,
        })
    end
    self.m_allPresetGroupList = allList
    self:_ApplyPresetFilter(self.m_filterTags)
    self:_RefreshPresetListView(resetToTop, playCellIn)
end


EquipPresetGroupCtrl._IsEquipInfoListSame =
    HL.Method(HL.Table, HL.Table).Return(HL.Boolean) << function(self, leftInfos, rightInfos)
    for index, slotIndex in ipairs(EQUIP_PRESET_SLOT_INDICES) do
        local leftInfo = leftInfos[index]
        local rightInfo = rightInfos[index]
        if not leftInfo or not rightInfo
            or leftInfo.slotIndex ~= slotIndex or rightInfo.slotIndex ~= slotIndex then
            return false
        end

        local leftEquipInstId = not leftInfo.isEmpty and leftInfo.equipInstId or nil
        local rightEquipInstId = not rightInfo.isEmpty and rightInfo.equipInstId or nil
        if leftEquipInstId ~= rightEquipInstId then
            return false
        end
    end
    return true
end

EquipPresetGroupCtrl._HasDuplicateCurrentEquipPreset = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_currentEquipInfoList then
        return false
    end
    for _, presetData in ipairs(self.m_allPresetGroupList or {}) do
        if self:_IsEquipInfoListSame(self.m_currentEquipInfoList, presetData.equipInfos) then
            return true
        end
    end
    return false
end

EquipPresetGroupCtrl._RequestPresetNameSensitiveCheck = HL.Method(HL.Table) << function(self, pendingAction)
    self.m_pendingPresetNameAction = pendingAction
    GameInstance.player.wikiSystem:CheckSensitive(pendingAction.name)
end

EquipPresetGroupCtrl._SubmitPresetNameAction = HL.Method(HL.Table) << function(self, pendingAction)
    if self.m_pendingPresetListAction then
        return
    end
    if pendingAction.actionType == PRESET_NAME_ACTION_CREATE then
        if not Utils.isInMainScope() then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
            return
        end
        local existingPresetIdMap = {}
        for _, presetData in ipairs(self.m_allPresetGroupList or {}) do
            existingPresetIdMap[presetData.presetId] = true
        end
        self.m_pendingPresetListAction = {
            actionType = PRESET_NAME_ACTION_CREATE,
            name = pendingAction.name,
            existingPresetIdMap = existingPresetIdMap,
        }
        local listAction = self.m_pendingPresetListAction
        self.m_pendingPresetScrollMode = PRESET_SCROLL_MODE_VISIBLE
        GameInstance.player.equipPresetGroupSystem:SendEquipPresetGroupCreate(
            pendingAction.charInstId, pendingAction.name, function(errorCode)
                if self.m_isClosed or self.m_pendingPresetListAction ~= listAction then
                    return
                end
                self.m_pendingPresetListAction = nil
                self.m_pendingPresetScrollMode = PRESET_SCROLL_MODE_NONE
            end)
    elseif pendingAction.actionType == PRESET_NAME_ACTION_RENAME then
        GameInstance.player.equipPresetGroupSystem:SendEquipPresetGroupRename(
            pendingAction.presetId, pendingAction.name)
    end
end

EquipPresetGroupCtrl._OnCheckSensitiveSuccess = HL.Method() << function(self)
    local pendingAction = self.m_pendingPresetNameAction
    if not pendingAction then
        return
    end
    self.m_pendingPresetNameAction = nil
    if pendingAction.actionType == PRESET_NAME_ACTION_RENAME then
        UIManager:Close(PanelId.CommonPopUp)
    end
    self:_SubmitPresetNameAction(pendingAction)
end

EquipPresetGroupCtrl._RequestCreatePreset = HL.Method(HL.Table) << function(self, pendingAction)
    if not self:_HasDuplicateCurrentEquipPreset() then
        self:_RequestPresetNameSensitiveCheck(pendingAction)
        return
    end

    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_EQUIP_PRESET_GROUP_DUPLICATE_SAVE_CONFIRM,
        onConfirm = function()
            self:_RequestPresetNameSensitiveCheck(pendingAction)
        end,
    })
end

EquipPresetGroupCtrl._SubmitCreatePresetFromInput = HL.Method() << function(self)
    if not self:_CanCreatePresetGroup() or not self.m_curCharInfo then
        return
    end
    if not Utils.isInMainScope() then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_INVALID_SYSTEM_COMMON_DESCRIPTION)
        return
    end

    local inputName = self.view.equipDetailNode.selectView.inputField.text
    local name = string.trim(inputName)
    if string.isEmpty(name) then
        name = self:_GetDefaultCreatePresetName()
    end
    self:_RequestCreatePreset({
        actionType = PRESET_NAME_ACTION_CREATE,
        name = name,
        charInstId = self.m_curCharInfo.instId,
    })
end

EquipPresetGroupCtrl._OpenRenamePopup = HL.Method(HL.Table) << function(self, presetData)
    local characterLimit = UIConst.INPUT_FIELD_NAME_CHARACTER_LIMIT
    local inputHintText = string.format(Language.LUA_EQUIP_PRESET_GROUP_NAME_LIMIT_FORMAT,
        math.floor(characterLimit / 2), characterLimit)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_EQUIP_PRESET_GROUP_RENAME_TITLE,
        input = true,
        inputName = presetData.name,
        renamePresetId = presetData.presetId,
        characterLimit = characterLimit,
        inputHintText = inputHintText,
        checkInputValid = function(inputText)
            
            return not string.isEmpty(inputText), 'normal'
        end,
        closeOnConfirm = false,
        onConfirm = function(newName)
            self:_OnRenameConfirm(presetData.presetId, newName)
        end,
    })
end

EquipPresetGroupCtrl._OnRenameConfirm = HL.Method(HL.Number, HL.String) << function(self, presetId, newName)
    self:_RequestPresetNameSensitiveCheck({
        actionType = PRESET_NAME_ACTION_RENAME,
        name = newName,
        presetId = presetId,
    })
end

EquipPresetGroupCtrl._TryRecoverRenamePopUp = HL.Method(HL.Opt(HL.Table)) << function(self, popUpArg)
    if not popUpArg or PhaseManager:GetTopPhaseId() ~= PHASE_ID then
        return
    end
    if not self:_FindPresetById(popUpArg.renamePresetId) then
        return
    end
    if UIManager:IsShow(PanelId.CommonPopUp) then
        return
    end
    popUpArg.onConfirm = function(newName)
        self:_OnRenameConfirm(popUpArg.renamePresetId, newName)
    end
    Notify(MessageConst.SHOW_POP_UP, popUpArg)
end

EquipPresetGroupCtrl._RefreshPresetCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    
    if index > #self.m_presetGroupList then
        cell.presetId = nil
        cell.selectBtn.interactable = false
        cell.renameBtn.interactable = false
        cell.index.text = string.format("%02d", index)
        cell.contentStateController:SetState("Empty")
        cell.selectionStateController:SetState("Empty")
        cell.name.text = ""
        cell.suitName.text = ""
        local emptyEquipInfos = {}
        for equipIndex, slotIndex in ipairs(EQUIP_PRESET_SLOT_INDICES) do
            local emptyInfo = {
                slotIndex = slotIndex,
                isEmpty = true,
            }
            table.insert(emptyEquipInfos, emptyInfo)
            self:_RefreshEquipCell(_GetFixedEquipCell(cell, equipIndex), emptyInfo)
        end
        self:_SetupEquipRowItemFocus(cell, emptyEquipInfos, -1)
        self:_ResetPresetCellInteractions(cell)
        return
    end

    local data = self.m_presetGroupList[index]
    cell.presetId = data.presetId
    cell.selectBtn.interactable = true
    local canEdit = not (DeviceInfo.usingController and self.m_isInCompare)
    cell.deleteBtn.gameObject:SetActive(canEdit)
    cell.topBtn.gameObject:SetActive(canEdit)
    cell.renameBtn.interactable = canEdit
    cell.inputGroup.enabled = not DeviceInfo.usingController or cell.selectBtn.isNaviTarget
    cell.selectBtn.onIsNaviTargetChanged = function(isTarget)
        if DeviceInfo.usingController then
            cell.inputGroup.enabled = isTarget
        end
        self:_RefreshItemFocusBindings()
    end
    cell.index.text = string.format("%02d", data.index)
    cell.name.text = data.name

    cell.selectBtn.onClick:RemoveAllListeners()
    cell.selectBtn.onClick:AddListener(function()
        self:_SelectPreset(data.presetId)
    end)

    for equipIndex, info in ipairs(data.equipInfos) do
        self:_RefreshEquipCell(_GetFixedEquipCell(cell, equipIndex), info)
    end
    self:_SetupEquipRowItemFocus(cell, data.equipInfos, data.presetId)
    
    self:_RefreshCardSuitSummary(cell, data.equipInfos, "NoEquipSuit")

    
    local isSelected = data.presetId == self.m_curSelectedPresetId
    
    cell.selectionStateController:SetState(isSelected and "SelectColor" or "NormalColor")

    cell.deleteBtn.onClick:RemoveAllListeners()
    cell.deleteBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_EQUIP_PRESET_GROUP_DELETE_CONFIRM,
            onConfirm = function()
                if self.m_pendingPresetListAction then
                    return
                end
                local fallbackPreset = self.m_presetGroupList[index + 1]
                    or self.m_presetGroupList[index - 1]
                self.m_pendingPresetListAction = {
                    actionType = PRESET_LIST_ACTION_DELETE,
                    presetId = data.presetId,
                    fallbackPresetId = fallbackPreset
                        and fallbackPreset.presetId or CURRENT_EQUIP_PRESET_ID,
                }
                GameInstance.player.equipPresetGroupSystem:SendEquipPresetGroupDelete(data.presetId)
            end,
        })
    end)

    cell.topBtn.onClick:RemoveAllListeners()
    cell.topBtn.onClick:AddListener(function()
        if self.m_pendingPresetListAction then
            return
        end
        if data.index == 1 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_PRESET_GROUP_ALREADY_PINNED_TOAST)
            return
        end
        if data.presetId == self.m_curSelectedPresetId then
            self.m_pendingPresetScrollMode = PRESET_SCROLL_MODE_TOP
        end
        GameInstance.player.equipPresetGroupSystem:SendEquipPresetGroupPinToTop(data.presetId)
        Notify(MessageConst.SHOW_TOAST, Language.LUA_EQUIP_PRESET_GROUP_PIN_SUCCESS_TOAST)
    end)

    cell.renameBtn.onClick:RemoveAllListeners()
    cell.renameBtn.onClick:AddListener(function()
        if self.m_pendingPresetListAction then
            return
        end
        self:_OpenRenamePopup(data)
    end)
end




EquipPresetGroupCtrl._ResetPresetCellInteractions = HL.Method(HL.Table) << function(self, cell)
    cell.inputGroup.enabled = false
    cell.selectBtn.onIsNaviTargetChanged = nil
    cell.selectBtn.customNaviTargetInDirFunc = nil
    cell.selectBtn.onClick:RemoveAllListeners()
    cell.deleteBtn.onClick:RemoveAllListeners()
    cell.topBtn.onClick:RemoveAllListeners()
    cell.renameBtn.onClick:RemoveAllListeners()
    local context = self.m_itemFocusRows[cell.itemNaviGroup]
    if context then
        self:_RefreshItemFocusBinding(context)
    end
end


EquipPresetGroupCtrl._FindPresetById = HL.Method(HL.Number).Return(HL.Opt(HL.Table)) << function(self, presetId)
    for _, data in ipairs(self.m_presetGroupList) do
        if data.presetId == presetId then
            return data
        end
    end
    return nil
end


EquipPresetGroupCtrl._IsCurrentEquipSelected = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_curSelectedPresetId == CURRENT_EQUIP_PRESET_ID
end


EquipPresetGroupCtrl._GetSelectedPreset = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if self:_IsCurrentEquipSelected() then
        return nil
    end
    return self:_FindPresetById(self.m_curSelectedPresetId)
end

EquipPresetGroupCtrl._GetSelectedPresetNaviTarget =
    HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    if self:_IsCurrentEquipSelected() then
        return self.view.currentEquipNode.selectBtn
    end

    for index, data in ipairs(self.m_presetGroupList or {}) do
        if data.presetId == self.m_curSelectedPresetId then
            return self:_GetPresetRowNaviTarget(index)
        end
    end

    return self.view.currentEquipNode.selectBtn
end

EquipPresetGroupCtrl._RestoreControllerNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local target = self:_GetSelectedPresetNaviTarget()
    if target then
        self:SetNaviTarget(target)
    end
end


EquipPresetGroupCtrl._SetSelectedPresetId = HL.Method(HL.Number) << function(self, presetId)
    self.m_curSelectedPresetId = presetId
    if self:_IsCurrentEquipSelected() then
        self.m_isInCompare = false
    end
end


EquipPresetGroupCtrl._RefreshPresetSelection =
    HL.Method(HL.Number, HL.Boolean) << function(self, presetId, isSelected)
    if presetId == CURRENT_EQUIP_PRESET_ID then
        self.view.currentEquipNode.selectionStateController:SetState(
            isSelected and "SelectColor" or "NorColor", false)
        return
    end

    local cell = self:_FindPresetCellById(presetId)
    if cell then
        cell.selectionStateController:SetState(isSelected and "SelectColor" or "NormalColor", false)
    end
end


EquipPresetGroupCtrl._SelectPreset = HL.Method(HL.Number) << function(self, presetId)
    if self:_IsPresetDeleteAnimationPlaying()
        or self.m_curSelectedPresetId == presetId then
        return
    end

    local oldPresetId = self.m_curSelectedPresetId
    self:_CompleteCurrentEquipSaveInAnimation()
    self:_ExitItemFocus()
    self:_SetSelectedPresetId(presetId)

    self:_RefreshPresetSelection(oldPresetId, false)
    self:_RefreshPresetSelection(presetId, true)

    self:_RefreshCompareState()
    self:_RefreshItemFocusBindings()
    self:_RefreshControllerHints()
    self:_RefreshSelectedGroupInfo()
    if self.m_isInCompare then
        self:_RefreshCompareInfo()
    end
    self:_PlaySelectedGroupRefreshAnimation()
end





EquipPresetGroupCtrl._SelectChar = HL.Method(HL.Table) << function(self, charInfo)
    for k, info in ipairs(self.m_charInfoList) do
        if info.instId == charInfo.instId then
            self.m_curCharInfo = info
            return
        end
    end
    self.m_curCharInfo = self.m_charInfoList[1]
end

EquipPresetGroupCtrl._PrioritizeSourceFormationChars = HL.Method() << function(self)
    if not self.m_sourceFormationCharInstIds or #self.m_sourceFormationCharInstIds == 0 then
        return
    end

    local charInfoByInstId = {}
    for _, charInfo in ipairs(self.m_charInfoList) do
        charInfoByInstId[charInfo.instId] = charInfo
    end

    local reorderedList = {}
    local insertedInstIds = {}
    for _, charInstId in ipairs(self.m_sourceFormationCharInstIds) do
        local charInfo = charInfoByInstId[charInstId]
        if charInfo and not insertedInstIds[charInstId] then
            table.insert(reorderedList, charInfo)
            insertedInstIds[charInstId] = true
        end
    end
    for _, charInfo in ipairs(self.m_charInfoList) do
        if not insertedInstIds[charInfo.instId] then
            table.insert(reorderedList, charInfo)
        end
    end
    self.m_charInfoList = reorderedList
end

EquipPresetGroupCtrl._InitCharList = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    self.m_getCharHeadCell = UIUtils.genCachedCellFunction(self.view.charListNode.charList)
    self.view.charListNode.charList.onUpdateCell:AddListener(function(object, csIndex)
        self:_RefreshSmallCharHeadCell(object, csIndex)
    end)
    self.view.charListNode.charList.onSelectedCell:AddListener(function(_, csIndex)
        self:_OnSelectCharIndex(csIndex)
    end)
    self.view.charListNode.charList.getCurSelectedIndex = function()
        if self.m_curCharInfo then
            for k, info in ipairs(self.m_charInfoList) do
                if info.instId == self.m_curCharInfo.instId then
                    return CSIndex(k)
                end
            end
        end
        return -1
    end

    if Utils.isInMainScope() then
        self.m_charInfoList = CharInfoUtils.getCharInfoList()
    else
        self.m_charInfoList = CharInfoUtils.getCurScopeCharInfoList()
    end
    self:_PrioritizeSourceFormationChars()

    local recoverState = arg and arg.recoverState or nil
    local initCharInfo = arg and arg.initCharInfo or CharInfoUtils.getLeaderCharInfo()
    local initCharInstId = recoverState and recoverState.charInstId
        or (initCharInfo and initCharInfo.instId or nil)
    local charFound = false
    local initCharIndex = 1
    for index, charInfo in ipairs(self.m_charInfoList) do
        if charInfo.instId == initCharInstId then
            self:_SelectChar(charInfo)
            initCharIndex = index
            charFound = true
            break
        end
    end
    if not charFound then
        self:_SelectChar(self.m_charInfoList[1])
    end
    self.view.charListNode.charList:UpdateCount(#self.m_charInfoList)
    self.view.charListNode.charList:ScrollToIndex(CSIndex(initCharIndex), true)
end

EquipPresetGroupCtrl._OnSelectCharIndex = HL.Method(HL.Number) << function(self, csIndex)
    if self:_IsPresetDeleteAnimationPlaying() then
        return
    end
    local charInfo = self.m_charInfoList[LuaIndex(csIndex)]
    if not charInfo then
        return
    end

    local isCharChanged = not self.m_curCharInfo or self.m_curCharInfo.instId ~= charInfo.instId
    self:_SelectChar(charInfo)
    self.view.charListNode.charList:UpdateCount(#self.m_charInfoList)
    self.view.charListNode.charList:ScrollToIndex(csIndex)
    self:_SetSelectedPresetId(CURRENT_EQUIP_PRESET_ID)
    self:_RefreshCurrentEquipInfo()
    self:_RefreshPresetListView(true)
    if isCharChanged then
        self:_PlaySelectedGroupRefreshAnimation()
        self:_ResetCreatePresetNameInput()
    end
    self:_RestoreControllerNaviTarget()
end

EquipPresetGroupCtrl._RefreshSmallCharHeadCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, csIndex)
    local charInfo = self.m_charInfoList[LuaIndex(csIndex)]
    local templateId = charInfo.templateId
    local instId = charInfo.instId
    local charHeadCell = self.m_getCharHeadCell(object)
    local isSameInstId = charInfo.instId == self.m_curCharInfo.instId
    local isInSlot = CharInfoUtils.checkIsCardInSlot(instId)

    charHeadCell.tryoutTips.gameObject:SetActive(charInfo.isShowTrail)
    charHeadCell.fixedTips.gameObject:SetActive(charInfo.isShowFixed)
    charHeadCell.previewTips.gameObject:SetActive(charInfo.isShowPreview)

    charHeadCell.redDot:InitRedDot("")
    charHeadCell.charInfo = charInfo
    charHeadCell.bgSelected.gameObject:SetActive(isSameInstId)
    charHeadCell.charImage:LoadSprite(CharInfoUtils.getCharHeadSpriteName(templateId))
    charHeadCell.formationMark.gameObject:SetActive(isInSlot)
    charHeadCell.button.onClick:RemoveAllListeners()
    charHeadCell.button.onClick:AddListener(function()
        self:_OnSelectCharIndex(csIndex)
    end)
end







HL.Commit(EquipPresetGroupCtrl)
