local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GameSetting
local HGUtils = CS.HG.Rendering.Runtime.HGUtils
local GameSettingSetter = CS.Beyond.Scripts.Entry.GameSettingSetter
local GameSettingHelper = CS.Beyond.Gameplay.GameSettingHelper
local GameSetting = CS.Beyond.GameSetting
local GameSettingVideoQuality = CS.Beyond.GameSetting.GameSettingVideoQuality
local GameSettingSubQualityOptionState = CS.Beyond.Gameplay.GameSettingSubQualityOptionState
local QualityManager = CS.Beyond.Scripts.Quality.QualityManager
local QualityManagerInst = QualityManager.instance 
local DeviceControllerType = CS.Beyond.DeviceInfo.ControllerType 
local InputDeviceFlags = CS.Beyond.Input.InputDeviceFlags 
local KeyboardKeyCode = CS.Beyond.Input.KeyboardKeyCode 
local GamepadKeyCode = CS.Beyond.Input.GamepadKeyCode 
local QUALITY_SETTING_ID = GameSetting.ID_VIDEO_QUALITY
local STANDARD_HORIZONTAL_RESOLUTION = CS.Beyond.UI.UIConst.STANDARD_HORIZONTAL_RESOLUTION
local STANDARD_VERTICAL_RESOLUTION = CS.Beyond.UI.UIConst.STANDARD_VERTICAL_RESOLUTION































































































































































































































GameSettingCtrl = HL.Class('GameSettingCtrl', uiCtrl.UICtrl)

local KEYICON_PATH = "Assets/Beyond/InitialAssets/UI/Sprites/KeyIcon/"
local VIDEO_TAB_ID = "gameSetting_video"

local SETTING_ICON_SPRITE_NAME_FORMAT = "icon_settings_%s"

local INITIAL_TAB_INDEX = 1

local CUSTOM_QUALITY_SETTING_INDEX = 1

local VOLUME_COEFFICIENT = 10.0

local PADDING_CANVAS_MIN_WIDTH = 1920

local MB = 1024 * 1024

local LANGUAGE_TEXT_POP_UP_CONTENT_TEXT_ID = "ui_set_gamesetting_switch_lang_black"
local LANGUAGE_AUDIO_POP_UP_CONTENT_TEXT_ID = "ui_set_gamesetting_switch_voice_black"
local LANGUAGE_POP_UP_WARNING_TEXT_ID = "ui_set_gamesetting_switch_lang_red"
local QUALITY_POP_UP_CONTENT_TEXT_ID = "ui_set_gamesetting_switch_graphic"
local QUALITY_POP_UP_MOBILE_CONTENT_TEXT_ID = "ui_set_gamesetting_switch_graphic_black"
local QUALITY_POP_UP_MOBILE_WARNING_TEXT_ID = "ui_set_gamesetting_switch_graphic_red"

local DROPDOWN_FULL_SCREEN_RESOLUTION_TEXT_ID = "LUA_GAME_SETTING_FULL_SCREEN_RESOLUTION"
local DROPDOWN_WINDOWED_RESOLUTION_TEXT_ID = "LUA_GAME_SETTING_WINDOWED_RESOLUTION"
local DROPDOWN_MAIN_QUALITY_DEFAULT_TEXT_ID = "LUA_GAME_SETTING_DEFAULT_MAIN_QUALITY"


local DROPDOWN_OPTION_STATE_NORMAL = "Normal" 
local DROPDOWN_OPTION_STATE_WARNING = "Warning" 
local DROPDOWN_OPTION_STATE_DISABLED = "Disabled" 
local DROPDOWN_OPTION_STATE_HIDDEN = "Hidden" 


local SubQualityOptionStateToDropdownOptionState = {
    [GameSettingSubQualityOptionState.Normal] = DROPDOWN_OPTION_STATE_NORMAL,
    [GameSettingSubQualityOptionState.Warning] = DROPDOWN_OPTION_STATE_WARNING,
    [GameSettingSubQualityOptionState.Disabled] = DROPDOWN_OPTION_STATE_DISABLED,
    [GameSettingSubQualityOptionState.Hidden] = DROPDOWN_OPTION_STATE_HIDDEN,
}

local LANGUAGE_TAB_ID = "gameSetting_language"
local KEY_HINT_TAB_ID = "gameSetting_key_hint"
local GAMEPAD_TAB_ID = "gameSetting_gamepad"

local GAMEPAD_ACTION_DROPDOWN_SETTINGS = {
    "gamepad_sprint_jump",
    "gamepad_skill_combo",
}

local ITEM_TYPE_LIST = {
    GEnums.SettingItemType.Toggle,
    GEnums.SettingItemType.Dropdown,
    GEnums.SettingItemType.Slider,
    GEnums.SettingItemType.Button,
    GEnums.SettingItemType.Key,
}


local KEY_ACTION_STATE = {
    None = 0,
    Dirty = 1 << 0, 
    Warning = 1 << 1, 
}
local KEY_ACTION_STATE_BITS = 2
local KEY_ACTION_STATE_MASK = (1 << KEY_ACTION_STATE_BITS) - 1
local KEY_ACTION_STATE_MAX_LEVEL = KEY_ACTION_STATE_MASK
local function HasKeyActionState(value, target)
    return (value & target) == target
end


GameSettingCtrl.m_settingChanged = HL.Field(HL.Boolean) << false


GameSettingCtrl.m_tabIndex = HL.Field(HL.Number) << -1


GameSettingCtrl.m_tabCells = HL.Field(HL.Forward('UIListCache'))


GameSettingCtrl.m_tabDataList = HL.Field(HL.Table)


GameSettingCtrl.m_itemCells = HL.Field(HL.Forward('UIListCache'))


GameSettingCtrl.m_itemCacheMap = HL.Field(HL.Table)


GameSettingCtrl.m_itemDataMap = HL.Field(HL.Table)


GameSettingCtrl.m_itemDataList = HL.Field(HL.Table)


GameSettingCtrl.m_itemCellMap = HL.Field(HL.Table)  


GameSettingCtrl.m_currentDeviceNode = HL.Field(HL.Table)


GameSettingCtrl.m_contentHeight = HL.Field(HL.Number) << -1


GameSettingCtrl.m_itemCellHeight = HL.Field(HL.Number) << -1


GameSettingCtrl.m_itemCellHeightWithoutTitle = HL.Field(HL.Number) << -1


GameSettingCtrl.m_originalPadding = HL.Field(HL.Number) << -1


GameSettingCtrl.m_originalAudioSlide = HL.Field(HL.String) << ""


GameSettingCtrl.m_sliderValueDataMap = HL.Field(HL.Table)  


GameSettingCtrl.m_keyActionScope2ItemDataList = HL.Field(HL.Table) 


GameSettingCtrl.m_keyActionStateMap = HL.Field(HL.Table) 




GameSettingCtrl.m_qualitySubSettingDataMap = HL.Field(HL.Table)  







GameSettingCtrl.m_notchPaddingViewTick = HL.Field(HL.Number) << -1


GameSettingCtrl.m_notchPaddingViewTime = HL.Field(HL.Number) << -1


GameSettingCtrl.m_rootCanvasHelper = HL.Field(HL.Userdata)


GameSettingCtrl.m_worldRootCanvasHelper = HL.Field(HL.Userdata)


GameSettingCtrl.m_rootCanvasWidth = HL.Field(HL.Number) << -1


GameSettingCtrl.m_rootCanvasHeight = HL.Field(HL.Number) << -1


GameSettingCtrl.m_isNotchPaddingChanged = HL.Field(HL.Boolean) << false








GameSettingCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_TRY_CHANGE_INPUT_DEVICE_TYPE] = "_OnTryChangeInputDeviceType",
    [MessageConst.ON_CONTROLLER_TYPE_CHANGED] = "_OnControllerTypeChanged",
    [MessageConst.ON_CLOSE_CUSTOMER_SERVICE] = "_OnCloseCustomerService",
    [MessageConst.GAME_SETTING_VOICE_RESOURCE_STATE_CHANGED] = "_OnVoiceResourceStateChanged",
}





GameSettingCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnCloseBtnClick()
    end)
    self.view.resetBtn.onClick:AddListener(function()
        self:_OnResetBtnClick()
    end)
    self.view.saveBtn.onClick:AddListener(function()
        self:_OnSaveBtnClick()
    end)

    self.view.deviceModeToggle:InitCommonToggle(function(isOn)
        self:_SwitchDeviceMode(isOn)
    end, true, true)
    self.view.deviceModeBattleBtn.onClick:AddListener(function()
        self.view.deviceModeToggle:SetValue(true)
    end)
    self.view.deviceModeFactoryBtn.onClick:AddListener(function()
        self.view.deviceModeToggle:SetValue(false)
    end)

    self.m_tabCells = UIUtils.genCellCache(self.view.tabs.tabCell)
    self.m_itemCells = UIUtils.genCellCache(self.view.settingItemCell)

    self.m_itemCellHeight = self.view.settingItemCell.transform.rect.height
    self.m_itemCellHeightWithoutTitle = self.m_itemCellHeight - self.view.settingItemCell.titleNode.rect.height

    self.m_originalPadding = self.view.sourceItem.dropDownSetting.dropDownListMask.padding.w
    self.m_originalAudioSlide = self.view.sourceItem.sliderSetting.slider.audioSlide

    self.m_tabDataList = {}
    self.m_itemDataList = {}
    self.m_itemDataMap = {}
    self.m_itemCellMap = {}
    self.m_sliderValueDataMap = {}
    self.m_keyActionScope2ItemDataList = {}
    self.m_keyActionStateMap = {}
    self.m_qualitySubSettingDataMap = {}
    self.m_itemCacheMap = {}

    self.m_rootCanvasHelper = UIManager.m_uiCanvasScaleHelper
    self.m_worldRootCanvasHelper = UIManager.m_worldUICanvasScaleHelper
    self.m_rootCanvasWidth = UIManager.uiCanvasRect.rect.width
    self.m_rootCanvasHeight = UIManager.uiCanvasRect.rect.height
    self.m_isNotchPaddingChanged = false
    self.m_settingChanged = false
    self.view.mobileNotchPaddingNode.gameObject:SetActive(false)

    
    GameSetting.InitAvailableScreenResolutionList()

    
    self:_InitLoad()

    self:_BuildSettingDataList()
    self:_InitSettingTabList()

    
    if not GameInstance.isInGameplay then
        InputManagerInst.needProcessTryChange = true
        logger.important(CS.Beyond.EnableLogType.DevOnly, "[InputDevice] 设置界面关闭直接切换设备")

        local LoginManagerInst = CS.Beyond.LoginManager.instance
        if LoginManagerInst then
            
            LoginManagerInst:ToggleLoginBindingGroup(false)
        end
    end

    self:_InitController()

    
    self:_QueryUnreadMsg()

end



GameSettingCtrl.OnClose = HL.Override() << function(self)
    self:_SliderClearNotchPaddingTick()
    self:_SliderTryApplyAllNotchPadding()

    
    if not GameInstance.isInGameplay then
        InputManagerInst.needProcessTryChange = false
        logger.important(CS.Beyond.EnableLogType.DevOnly, "[InputDevice] 设置界面开启直接切换设备")

        local LoginManagerInst = CS.Beyond.LoginManager.instance
        if LoginManagerInst then
            
            LoginManagerInst:ToggleLoginBindingGroup(true)
        end
    end

    
    local isAnyDirty = self:_IsAnyKeyActionStateDirty()
    if isAnyDirty then
        self:_KeyClearPendingActions()
    end

    if self.m_settingChanged then
        Notify(MessageConst.ON_GAME_SETTING_CHANGED)
        GameInstance.player.gameSettingSystem:SaveSetting()
    end
end



GameSettingCtrl._OnCloseBtnClick = HL.Method() << function(self)
    local callback = function()
        self.m_phase:CloseSelf()
    end
    if self:_CheckLeaveCurrentSettingTab(callback) then
        callback()
    end
end



GameSettingCtrl._OnResetBtnClick = HL.Method() << function(self)
    self:_KeyResetActions()
end



GameSettingCtrl._OnSaveBtnClick = HL.Method() << function(self)
    self:_KeySaveActions()
end



GameSettingCtrl._BuildSettingDataList = HL.Method() << function(self)
    local tabDataMap = Tables.settingTabTable
    if tabDataMap == nil then
        return
    end

    for tabId, tabData in pairs(tabDataMap) do
        if self:_IsSettingTabValid(tabId, tabData.validateFunction) then
            if tabData.tabItems ~= nil then
                table.insert(self.m_tabDataList, tabData)
            end
        end
    end

    table.sort(self.m_tabDataList, function(dataA, dataB)
        return dataA.tabSortOrder < dataB.tabSortOrder
    end)

    for tabIndex, tabData in ipairs(self.m_tabDataList) do
        self.m_itemDataList[tabIndex] = self:_BuildSettingTabData(tabData)
    end
end




GameSettingCtrl._BuildSettingTabData = HL.Method(HL.Userdata).Return(HL.Table) << function(self, tabData)
    local itemDataList = {}
    for itemId, itemData in pairs(tabData.tabItems) do
        if self:_IsSettingItemValid(itemData.settingId, itemData.validateFunction) then
            table.insert(itemDataList, itemData)
            self.m_itemDataMap[itemId] = itemData
        end
    end

    if tabData.tabId == VIDEO_TAB_ID then
        
        self:_InsertSubQualityItemDataList(itemDataList)
    elseif tabData.tabId == KEY_HINT_TAB_ID then
        
        lume.clear(self.m_keyActionScope2ItemDataList)
        self:_InitKeyActionScopeMap(itemDataList)
    end

    table.sort(itemDataList, function(dataA, dataB)
        return dataA.settingSortOrder < dataB.settingSortOrder
    end)

    return itemDataList
end





GameSettingCtrl._GetCachedItem = HL.Method(HL.Userdata, HL.Userdata).Return(HL.Table) << function(self, transform, itemType)
    if self.m_itemCacheMap[transform] == nil then
        self.m_itemCacheMap[transform] = {}
    end
    local cachedItem = self.m_itemCacheMap[transform]
    local sourceNode = self.view.sourceItem

    if cachedItem[itemType] == nil then
        local sourceItem
        if itemType == GEnums.SettingItemType.Dropdown then
            sourceItem = sourceNode.dropDownSetting
        elseif itemType == GEnums.SettingItemType.Slider then
            sourceItem = sourceNode.sliderSetting
        elseif itemType == GEnums.SettingItemType.Button then
            sourceItem = sourceNode.buttonSetting
        elseif itemType == GEnums.SettingItemType.Toggle then
            sourceItem = sourceNode.toggleSetting
        elseif itemType == GEnums.SettingItemType.Key then
            sourceItem = sourceNode.keySetting
        end
        local object = CSUtils.CreateObject(sourceItem.gameObject, transform)
        cachedItem[itemType] = Utils.wrapLuaNode(object)
    end

    local item = cachedItem[itemType]
    for _, type in pairs(ITEM_TYPE_LIST) do
        if type ~= itemType then
            if cachedItem[type] ~= nil then
                cachedItem[type].gameObject:SetActive(false)
            end
        end
    end
    item.gameObject:SetActive(true)
    item.rectTransform.anchoredPosition = Vector2.zero

    return item
end







GameSettingCtrl._IsSettingTabValid = HL.Method(HL.String, HL.String)
                                       .Return(HL.Boolean)
    << function(self, settingTabId, validateFunction)
    if not GameSetting.IsSettingTabValid(settingTabId) then
        return false
    end
    if string.isEmpty(validateFunction) then
        return true
    end
    validateFunction = self[self:_GetSettingFunctionName(validateFunction)]
    if validateFunction == nil then
        logger.error(ELogChannel.GameSetting, "Setting tab validate function not found, settingTabId: " .. tostring(settingTabId))
        return false
    end
    local success, result = xpcall(validateFunction, debug.traceback, self, settingTabId)
    if not success then
        logger.error(ELogChannel.GameSetting, "Setting tab validate function error, message: " .. tostring(result))
        return false
    end
    return result
end




GameSettingCtrl._InitSettingTabList = HL.Method() << function(self)
    self.m_tabCells:Refresh(#self.m_tabDataList, function(tabCell, tabIndex)
        self:_RefreshSettingTabCell(tabCell, tabIndex)
    end)
    self:_RefreshSettingTab(INITIAL_TAB_INDEX, true)
end





GameSettingCtrl._RefreshSettingTabCell = HL.Method(HL.Table, HL.Number) << function(self, tabCell, tabIndex)
    local tabData = self.m_tabDataList[tabIndex]
    if tabData == nil then
        return
    end

    tabCell.gameObject.name = string.format("GameSettingTab_%s", tabData.tabId)

    
    local spriteName = string.format(SETTING_ICON_SPRITE_NAME_FORMAT, tabData.tabIcon)
    UIUtils.setTabIcons(tabCell,UIConst.UI_SPRITE_GAME_SETTING,spriteName)

    
    tabCell.toggle.isOn = tabIndex == INITIAL_TAB_INDEX
    tabCell.toggle.checkIsValueValid = function(isOn)
        if not isOn then
            return true
        end
        return self:_ValidateClickSettingTab(tabCell)
    end
    tabCell.toggle.onValueChanged:RemoveAllListeners()
    tabCell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn then
            self:_OnSettingTabClicked(tabIndex)
        end
    end)

    
    if string.isEmpty(tabData.tabRedDot) then
        tabCell.redDot.gameObject:SetActive(false)
    else
        tabCell.redDot.gameObject:SetActive(true)
        tabCell.redDot:InitRedDot(tabData.tabRedDot)
    end
end




GameSettingCtrl._ValidateClickSettingTab = HL.Method(HL.Table).Return(HL.Boolean) << function(self, tabCell)
    
    local callback = function()
        tabCell.toggle.isOn = true
    end
    return self:_CheckLeaveCurrentSettingTab(callback)
end




GameSettingCtrl._OnSettingTabClicked = HL.Method(HL.Number) << function(self, tabIndex)
    self:_RefreshSettingTab(tabIndex, true)
    self.view.animationWrapper:PlayWithTween("gamesetting_change")
    self:_SliderClearNotchPaddingTick()
end




GameSettingCtrl._CheckLeaveCurrentSettingTab = HL.Method(HL.Function).Return(HL.Boolean) << function(self, callback)
    local tabData = self.m_tabDataList[self.m_tabIndex]
    local leaveFunctionName = self:_GetSettingFunctionName(tabData.tabLeaveFunction)
    if string.isEmpty(leaveFunctionName) then
        return true
    end

    local leaveFunction = self[leaveFunctionName]
    local success, result = xpcall(leaveFunction, debug.traceback, self, tabData.tabId, callback)
    if not success then
        logger.error(ELogChannel.GameSetting, "Setting tab leave function error, message: " .. tostring(result))
        return false
    end
    return result
end





GameSettingCtrl._LeaveSettingTab_KeyHint = HL.Method(HL.String, HL.Function)
                                             .Return(HL.Boolean)
    << function(self, settingTabId, callback)
    local stateLevel = self:_GetKeyActionStateLevel()
    local content
    local warningContent
    
    if HasKeyActionState(stateLevel, KEY_ACTION_STATE.Warning) then
        
        content = Language.LUA_GAME_SETTING_KEY_LEAVE_CONFIRM_CANNOT_SAVE
        warningContent = Language.LUA_GAME_SETTING_KEY_LEAVE_CONFIRM_WARNING
    elseif HasKeyActionState(stateLevel, KEY_ACTION_STATE.Dirty) then
        
        content = Language.LUA_GAME_SETTING_KEY_LEAVE_CONFIRM_NOT_SAVE
    end
    if not content then
        return true 
    end

    Notify(MessageConst.SHOW_POP_UP, {
        content = content,
        warningContent = warningContent,
        onConfirm = function()
            
            self:_KeyClearPendingActions()
            
            callback()
        end,
    })
    return false 
end






GameSettingCtrl._RefreshSettingTab = HL.Method(HL.Number, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, tabIndex, init, rebuildData)
    local tabData = self.m_tabDataList[tabIndex]
    if tabData == nil then
        return
    end
    if rebuildData then
        self.m_itemDataList[tabIndex] = self:_BuildSettingTabData(tabData)
    end
    local itemDataList = self.m_itemDataList[tabIndex]
    if itemDataList == nil then
        return
    end

    self.m_tabIndex = tabIndex

    
    self.view.tabTitleTxt.text = tabData.tabText

    
    self:_RefreshLoad()

    
    self:_RefreshDeviceNode(init)

    
    self.m_contentHeight = 0
    if self.view.deviceNode.gameObject.activeInHierarchy then
        self.m_contentHeight = self.m_contentHeight + self.view.deviceNode.rect.height
    end
    self.m_itemCellMap = {}
    self.m_qualitySubSettingDataMap = {}
    self.m_itemCells:Refresh(#itemDataList, function(itemCell, itemIndex)
        self:_RefreshSettingItemCell(itemCell, itemIndex, tabIndex)
    end)

    UIUtils.setSizeDeltaY(self.view.viewContent, self.m_contentHeight)

    
    local isKeyHintTab = tabData.tabId == KEY_HINT_TAB_ID
    self.view.bottomNode.gameObject:SetActive(isKeyHintTab)
    if isKeyHintTab then
        local isAnyDirty = self:_IsAnyKeyActionStateDirty()
        self.view.saveBtn.interactable = isAnyDirty
        local saveBtnStateName = isAnyDirty and "NormalState" or "DisableState"
        self.view.saveBtnStateCtrl:SetState(saveBtnStateName)
    end

    
    if init then
        self:_SetSettingItemControllerNaviTarget()
        self.view.scrollView:ScrollTo(Vector2(0, 0), true)
    end
end




GameSettingCtrl._RefreshCurrentSettingTab = HL.Method(HL.Opt(HL.Boolean)) << function(self, rebuildData)
    self:_RefreshSettingTab(self.m_tabIndex, false, rebuildData)
end




GameSettingCtrl._ValidateAccount = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not GameInstance.player.gameSettingSystem.forbiddenAccountPage 
        and not UIUtils.inDungeonOrFocusMode() 
end




GameSettingCtrl._ValidateController = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not UIUtils.inDungeonOrFocusMode() 
end




GameSettingCtrl._ValidateKeyHint = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not UIUtils.inDungeonOrFocusMode() 
end




GameSettingCtrl._ValidateGamepad = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    if UIUtils.inDungeonOrFocusMode() then
        return false 
    end
    if DeviceInfo.isMobile then
        return DeviceInfo.usingController 
    end
    return true
end




GameSettingCtrl._ValidateLanguage = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not CS.Beyond.GlobalOptions.instance.auditing 
end




GameSettingCtrl._ValidateOther = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not UIUtils.inDungeonOrFocusMode() 
end









GameSettingCtrl._RefreshDeviceNode = HL.Method(HL.Boolean) << function(self, init)
    local tabData = self.m_tabDataList[self.m_tabIndex]
    local showDeviceNode = tabData.tabId == GAMEPAD_TAB_ID
    self.view.deviceNode.gameObject:SetActive(showDeviceNode)
    if not showDeviceNode then
        return
    end

    local controllerType = DeviceInfo.controllerType
    local isPSController = UNITY_PS5 
        or controllerType == DeviceControllerType.PS4 or controllerType == DeviceControllerType.PS5
    local isXboxController = not isPSController 
    self.view.psDeviceNode.gameObject:SetActive(isPSController)
    self.view.xboxDeviceNode.gameObject:SetActive(isXboxController)
    if isPSController then
        self.m_currentDeviceNode = self.view.psDeviceNode
        local layoutStateName = InputManager.isNonSupportPsController and "NoTouchpad" or "Touchpad"
        self.view.psDeviceNode.stateCtrl:SetState(layoutStateName)
    elseif isXboxController then
        self.m_currentDeviceNode = self.view.xboxDeviceNode
    end

    if init then
        self.view.deviceModeToggle:SetValue(true, true)
    end
    self:_SwitchDeviceMode(self.view.deviceModeToggle.toggle.isOn)
end




GameSettingCtrl._SwitchDeviceMode = HL.Method(HL.Boolean) << function(self, isOn)
    self:_ApplyGamepadSettingsToDevice()
    local deviceMode = isOn and "Battle" or "Factory"
    self.m_currentDeviceNode.stateCtrl:SetState(deviceMode)
end



GameSettingCtrl._ApplyGamepadSettingsToDevice = HL.Method() << function(self)
    self:_ApplyGamepadActionSettingsToDevice()
    self:_ApplyGamepadEnableUltimateMode2SettingToDevice()
end



GameSettingCtrl._ApplyGamepadActionSettingsToDevice = HL.Method() << function(self)
    for i = 1, #GAMEPAD_ACTION_DROPDOWN_SETTINGS do
        local settingId = GAMEPAD_ACTION_DROPDOWN_SETTINGS[i]
        local optionGroupData = Tables.gamepadSettingOptionTable:GetValue(settingId)
        local optionIndex = self:_DropdownGetIndexGamepadSetting(settingId)
        local optionData = optionGroupData.options[optionIndex - 1]
        local actionKeys = optionData.actionKeys
        for j = 0, actionKeys.Count - 1 do
            local actionKeyData = actionKeys[j]
            local keyHintText = self.m_currentDeviceNode["keyHintText_" .. actionKeyData.actionKey]
            if keyHintText then
                if string.isEmpty(actionKeyData.actionKeyHintTextId) then
                    keyHintText.text = nil
                else
                    keyHintText.text = Language[actionKeyData.actionKeyHintTextId]
                end
            end
        end
    end

    
    
    local indicatorActionInfo = InputManagerInst:GetPlayerActionInfo("common_indicator_start")
    local indicatorKeyIconPath = InputManager.GetKeyIconPath(indicatorActionInfo.primaryGamepadInput, false, true)
    self.m_currentDeviceNode.indicatorKeyIcon01:LoadSpriteWithOutFormat(indicatorKeyIconPath)
    self.m_currentDeviceNode.indicatorKeyIcon02:LoadSpriteWithOutFormat(indicatorKeyIconPath)
    self.m_currentDeviceNode.indicatorKeyIcon03:LoadSpriteWithOutFormat(indicatorKeyIconPath)
    self.m_currentDeviceNode.indicatorKeyIcon04:LoadSpriteWithOutFormat(indicatorKeyIconPath)
end



GameSettingCtrl._ApplyGamepadEnableUltimateMode2SettingToDevice = HL.Method() << function(self)
    local enableUltimateMode2 = self:_ToggleGetEnableUltimateMode2(GameSetting.ID_GAMEPAD_ENABLE_ULTIMATE_MODE_2)
    self.m_currentDeviceNode.useUltimateMode2StateCtrl:SetState(enableUltimateMode2 and "Enabled" or "Disabled")
end










GameSettingCtrl._IsSettingItemValid = HL.Method(HL.String, HL.String)
                                        .Return(HL.Boolean)
    << function(self, settingId, validateFunction)
    if not GameSetting.IsSettingItemValid(settingId) then
        return false
    end
    if string.isEmpty(validateFunction) then
        return true
    end
    validateFunction = self[self:_GetSettingFunctionName(validateFunction)]
    if validateFunction == nil then
        logger.error(ELogChannel.GameSetting, "Setting item validate function not found, settingId: " .. tostring(settingId))
        return false
    end
    local success, result = xpcall(validateFunction, debug.traceback, self, settingId)
    if not success then
        logger.error(ELogChannel.GameSetting, "Setting item validate function error, message: " .. tostring(result))
        return false
    end
    return result
end






GameSettingCtrl._RefreshSettingItemCell = HL.Method(HL.Table, HL.Number, HL.Number) << function(self, itemCell, itemIndex, tabIndex)
    local itemDataList = self.m_itemDataList[tabIndex]
    if itemDataList == nil then
        return
    end

    local itemData = itemDataList[itemIndex]
    if itemData == nil then
        return
    end

    local itemType = itemData.settingItemType

    itemCell.gameObject.name = string.format("GameSettingItem_%s", itemData.settingId)
    itemCell.settingItemText.text = itemData.settingText

    
    itemCell.naviDecorator.onIsNaviTargetChanged = itemIndex == 1 and function(isTarget)
        if isTarget then
            self.view.scrollView:ScrollTo(Vector2(0, 0), false)
        end
    end or nil

    
    local showTitle = not string.isEmpty(itemData.settingGroupTitle)
    itemCell.titleNode.gameObject:SetActive(showTitle)
    if showTitle then
        itemCell.itemTitleText.text = itemData.settingGroupTitle
        itemCell.itemTitleKey.gameObject:SetActive(itemType == GEnums.SettingItemType.Key)
    end

    
    if string.isEmpty(itemData.settingRedDot) then
        itemCell.redDot.gameObject:SetActive(false)
    else
        itemCell.redDot.gameObject:SetActive(true)
        itemCell.redDot:InitRedDot(itemData.settingRedDot)
    end

    local item = self:_GetCachedItem(itemCell.cacheTransform, itemType)

    
    if GameSettingHelper.IsQualitySubSetting(itemData.settingId) then
        self.m_qualitySubSettingDataMap[itemData.settingId] = {
            itemCell = item,
            itemData = itemData,
        }
    end

    if itemType == GEnums.SettingItemType.Dropdown then
        self:_InitDropdownSettingItem(item, itemData, itemCell)
    elseif itemType == GEnums.SettingItemType.Slider then
        self:_InitSliderSettingItem(item, itemData, itemCell)
    elseif itemType == GEnums.SettingItemType.Button then
        self:_InitButtonSettingItem(item, itemData)
    elseif itemType == GEnums.SettingItemType.Toggle then
        self:_InitToggleSettingItem(item, itemData)
    elseif itemType == GEnums.SettingItemType.Key then
        self:_InitKeySettingItem(item, itemData)
    end

    
    local cellHeight = showTitle and self.m_itemCellHeight or self.m_itemCellHeightWithoutTitle
    UIUtils.setSizeDeltaY(itemCell.rectTransform, cellHeight)
    
    if itemIndex > 1 then
        
        if showTitle then
            cellHeight = cellHeight + self.view.config.SETTING_ITEM_TITLE_PADDING_TOP
        end
        
        self.m_contentHeight = self.m_contentHeight + self.view.config.SETTING_ITEM_VERTICAL_SPACE
    end
    
    self.m_contentHeight = self.m_contentHeight + cellHeight
    
    local position = itemCell.rectTransform.anchoredPosition
    itemCell.rectTransform.anchoredPosition = Vector2(
        position.x,
        -self.m_contentHeight
    )

    self.m_itemCellMap[itemData.settingId] = item
end






GameSettingCtrl._InitDropdownSettingItem = HL.Method(HL.Table, HL.Any, HL.Table) << function(self, itemCell, itemData, originalCell)
    local settingId = itemData.settingId

    local optionTextList = {}
    local optionStateList

    itemCell.dropdown:ClearComponent()
    itemCell.dropdown:Init(function(csIndex, option, isSelected)
        local index = LuaIndex(csIndex)
        option:SetText(optionTextList[index])
        option:SetState(optionStateList and optionStateList[index] or DROPDOWN_OPTION_STATE_NORMAL)
    end, function(csIndex)
        if GameSettingHelper.IsQualitySubSetting(settingId) then
            local index = self:_DropdownGetQualitySubSettingOptionIndex(settingId)
            if index ~= LuaIndex(csIndex) then
                self:_DropdownSetQualitySubSettingOptionIndex(settingId, LuaIndex(csIndex))
                self.m_settingChanged = true
            end
        else
            local selectFunction = self:_GetSettingFunctionName(itemData.dropdownOptionSelectFunction)
            local getFunction = self:_GetSettingFunctionName(itemData.dropdownOptionGetFunction)
            if not string.isEmpty(selectFunction) then
                local index = -1
                if string.isEmpty(getFunction) then
                    index = self:_DropdownGetOptionIndex(settingId)
                else
                    index = self[getFunction](self, settingId)
                end
                if index ~= LuaIndex(csIndex) then
                    self[selectFunction](self, settingId, LuaIndex(csIndex))
                    self.m_settingChanged = true
                end
            end
        end
    end)
    itemCell.dropdown.onToggleOptList:AddListener(function(active)
        if active then
            self:_DropdownAdjustExpandDirection(itemCell, originalCell)
            itemCell.dropdown:ScrollToSelected()
        end
    end)
    itemCell.dropdown.onValidateSelectCell = function(csFromIndex, csToIndex)
        local valid = true
        local validateSelectFunction = self:_GetSettingFunctionName(itemData.dropdownOptionValidateSelectFunction)
        if not string.isEmpty(validateSelectFunction) then
            valid = self[validateSelectFunction](self, itemData, LuaIndex(csFromIndex), LuaIndex(csToIndex))
        end
        return valid
    end

    
    local isGamepad = itemData.settingTabId == GAMEPAD_TAB_ID
    itemCell.sizeStateCtrl:SetState(isGamepad and "Large" or "Normal")

    local initIndex = 1
    if GameSettingHelper.IsQualitySubSetting(settingId) then
        initIndex = self:_DropdownGetQualitySubSettingOptionIndex(settingId)
    else
        local getFunction = self:_GetSettingFunctionName(itemData.dropdownOptionGetFunction)
        initIndex = string.isEmpty(getFunction) and self:_DropdownGetOptionIndex(settingId) or self[getFunction](self, settingId)
    end
    self:_StartCoroutine(function()
        coroutine.step()
        
        if GameSettingHelper.IsQualitySubSetting(settingId) then
            optionTextList = itemData.optionTextList
            optionStateList = itemData.optionStateList
        else
            if string.isEmpty(itemData.dropdownOptionTextListGetFunction) then
                local optionTextData = itemData.dropdownOptionTextList
                if optionTextData ~= nil then
                    for i = 0, optionTextData.length - 1 do
                        if not string.isEmpty(optionTextData[i]) then
                            local text = optionTextData[i]
                            table.insert(optionTextList, text)
                        end
                    end
                end
            else
                local textListGetFunctionName = self:_GetSettingFunctionName(itemData.dropdownOptionTextListGetFunction)
                if not string.isEmpty(textListGetFunctionName) then
                    optionTextList, optionStateList = self[textListGetFunctionName](self, itemData)
                end
            end
        end

        itemCell.dropdown:Refresh(#optionTextList, CSIndex(initIndex), false)
    end)
end






GameSettingCtrl._InitSliderSettingItem = HL.Method(HL.Table, HL.Any, HL.Table) << function(self, itemCell, itemData, originalCell)
    local settingId = itemData.settingId

    local getFunctionName = self:_GetSettingFunctionName(itemData.sliderValueGetFunction)
    local setFunctionName = self:_GetSettingFunctionName(itemData.sliderValueSetFunction)
    local maxValueGetFunctionName = itemData.sliderMaxValueGetFunction
    local iconOnClickFunction = itemData.sliderIconOnClickFunction

    local iconListLength = itemData.sliderIconList and #itemData.sliderIconList or 0
    itemCell.sliderIconNode.gameObject:SetActive(iconListLength > 0)
    itemCell.sliderFillArea.gameObject:SetActive(itemData.sliderUseFill)

    itemCell.slider:ClearComponent()
    itemCell.sliderIconButton.onClick:RemoveAllListeners()
    itemCell.slider.audioSlide = ""
    itemCell.slider.wholeNumbers = itemData.sliderWholeNumbers
    itemCell.slider.minValue = itemData.sliderMinValue
    itemCell.slider.snapStep = true
    itemCell.slider.stepValue = itemData.sliderStepValue
    if string.isEmpty(maxValueGetFunctionName) then
        itemCell.slider.maxValue = itemData.sliderMaxValue
    else
        maxValueGetFunctionName = self:_GetSettingFunctionName(maxValueGetFunctionName)
        local maxValue = self[maxValueGetFunctionName](self, settingId)
        if itemData.sliderMinValue >= maxValue then
            originalCell.gameObject:SetActive(false)
            return
        end
        itemCell.slider.maxValue = maxValue
    end
    
    local wholeNumbersText = itemCell.slider.minValue < 0 or itemCell.slider.maxValue > 1

    self.m_sliderValueDataMap[settingId] = {
        minValue = itemData.sliderMinValue,
        maxValue = itemData.sliderMaxValue
    }

    itemCell.slider.onValueChanged:AddListener(function(value)
        if not string.isEmpty(setFunctionName) then
            local currValue
            if string.isEmpty(getFunctionName) then
                currValue = self:_SliderGetValue(settingId)
            else
                currValue = self[getFunctionName](self, settingId)
            end
            if value ~= currValue then
                self.m_settingChanged = true
            end
            self[setFunctionName](self, settingId, value)
            self:_SliderRecordValue(settingId, value)
        end

        if iconListLength > 0 then
            local icon = self:_SliderGetIcon(value, itemData.sliderIconList, itemData.sliderIconRangeList)
            if icon ~= nil then
                itemCell.sliderIcon.sprite = icon
                itemCell.sliderIcon.gameObject:SetActive(true)
            else
                itemCell.sliderIcon.gameObject:SetActive(false)
            end
        end

        self:_SliderRefreshText(itemCell, value, wholeNumbersText)
    end)

    if not string.isEmpty(getFunctionName) then
        local initValue = self[getFunctionName](self, settingId)
        itemCell.slider:SetValueWithoutNotify(initValue, false)
        self:_SliderRefreshText(itemCell, initValue, wholeNumbersText)
        self:_SliderRecordValue(settingId, initValue)

        if itemCell.slider.value == 0.0 then
            
            itemCell.slider.onValueChanged:Invoke(initValue)
        end
    end

    if not string.isEmpty(iconOnClickFunction) and iconListLength > 0 then
        iconOnClickFunction = self:_GetSettingFunctionName(iconOnClickFunction)
        itemCell.sliderIconButton.onClick:AddListener(function()
            self[iconOnClickFunction](self, settingId)
        end)
    end

    itemCell.slider.audioSlide = self.m_originalAudioSlide  
end





GameSettingCtrl._InitButtonSettingItem = HL.Method(HL.Table, HL.Any) << function(self, itemCell, itemData)
    local getStateFunction = itemData.buttonGetStateFunction
    if string.isEmpty(getStateFunction) then
        itemCell.buttonText.text = itemData.buttonText
        itemCell.buttonIcon.gameObject:SetActive(true)
        itemCell.stateCtrl:SetState("NormalState")
    else
        getStateFunction = self[self:_GetSettingFunctionName(getStateFunction)]
        local success, result = xpcall(getStateFunction, debug.traceback, self, itemData)
        if success then
            itemCell.buttonText.text = result.currentText
            if string.isEmpty(result.currentIcon) then
                itemCell.buttonIcon.gameObject:SetActive(false)
            else
                itemCell.buttonIcon.gameObject:SetActive(true)
            end
            itemCell.stateCtrl:SetState(result.currentState)
        else
            logger.error(ELogChannel.GameSetting, "Setting item button get state function error, message: " .. tostring(result))
        end
    end

    local clickFunctionName = self:_GetSettingFunctionName(itemData.buttonOnClickFunction)
    if not string.isEmpty(clickFunctionName) then
        itemCell.button.onClick:RemoveAllListeners()
        itemCell.button.onClick:AddListener(function()
            self[clickFunctionName](self)
        end)
    end
end





GameSettingCtrl._InitToggleSettingItem = HL.Method(HL.Table, HL.Any) << function(self, itemCell, itemData)
    local settingId = itemData.settingId

    local getFunctionName
    local setFunctionName

    local initialValue = false
    if GameSettingHelper.IsQualitySubSetting(settingId) then
        initialValue = self:_ToggleGetQualitySubSettingValue(settingId)
    else
        getFunctionName = self:_GetSettingFunctionName(itemData.toggleValueGetFunction)
        setFunctionName = self:_GetSettingFunctionName(itemData.toggleValueSetFunction)

        if not string.isEmpty(getFunctionName) then
            initialValue = self[getFunctionName](self, settingId)
        end
    end

    itemCell.toggle:InitCommonToggle(function(isOn)
        if GameSettingHelper.IsQualitySubSetting(settingId) then
            initialValue = self:_ToggleSetQualitySubSettingValue(settingId, isOn)
            self.m_settingChanged = true
        else
            if not string.isEmpty(setFunctionName) then
                self[setFunctionName](self, settingId, isOn)
                self.m_settingChanged = true
            end
        end
    end, initialValue, true)
end





GameSettingCtrl._InitKeySettingItem = HL.Method(HL.Table, HL.Userdata) << function(self, itemCell, itemData)
    
    
    
    
    local useActionIds2 = itemData.keyActionIds2.Count > 0
    local actionIds2 = useActionIds2 and itemData.keyActionIds2 or itemData.keyActionIds1

    
    local fallbackSecondary = useActionIds2

    local isSet1 = self:_InitKeySettingItem_KeyAction(itemCell.keyAction1, true,
        itemData, itemData.keyActionIds1, nil, itemData.keyIcon1, itemData.keyIsMutable1, itemData.keyIsLongPress1, fallbackSecondary)
    local isSet2 = self:_InitKeySettingItem_KeyAction(itemCell.keyAction2, useActionIds2,
        itemData, actionIds2, nil, itemData.keyIcon2, itemData.keyIsMutable2, itemData.keyIsLongPress2, fallbackSecondary)

    
    local allUnset = not isSet1 and not isSet2
    
    if allUnset then
        itemCell.keyAction1.stateCtrl:SetState("Warning")
        self:_AddKeyActionState(itemData.settingId, KEY_ACTION_STATE.Warning, true)
        itemCell.keyAction2.stateCtrl:SetState("Warning")
        self:_AddKeyActionState(itemData.settingId, KEY_ACTION_STATE.Warning, false)
    else
        self:_RemoveKeyActionState(itemData.settingId, KEY_ACTION_STATE.Warning, true)
        self:_RemoveKeyActionState(itemData.settingId, KEY_ACTION_STATE.Warning, false)
    end
end












GameSettingCtrl._InitKeySettingItem_KeyAction = HL.Method(HL.Table, HL.Boolean, HL.Userdata, HL.Userdata, HL.Any, HL.Any, HL.Boolean, HL.Boolean, HL.Boolean)
                                                  .Return(HL.Boolean)
    << function(self, view, isPrimary, itemData, actionIds, modifyIconPath, iconPath, isMutable, isLongPress, fallbackSecondary)
    local isSet = false 

    local stateName

    view.button.onClick:RemoveAllListeners()
    view.button.onHoverChange:RemoveAllListeners()
    view.delBtn.onClick:RemoveAllListeners()
    view.delBtn.gameObject:SetActive(false)

    local actionId = actionIds.Count > 0 and actionIds[0] or nil
    if actionId then
        
        local actionInfo = InputManagerInst:GetPlayerActionInfo(actionId) 
        if isPrimary then
            
            modifyIconPath = InputManager.GetKeyIconPath(actionInfo.primaryKeyboardInput, true, isLongPress, true)
            iconPath = InputManager.GetKeyIconPath(actionInfo.primaryKeyboardInput, false, isLongPress, true)
            if fallbackSecondary and string.isEmpty(iconPath) then
                modifyIconPath = InputManager.GetKeyIconPath(actionInfo.secondaryKeyboardInput, true, isLongPress, true)
                iconPath = InputManager.GetKeyIconPath(actionInfo.secondaryKeyboardInput, false, isLongPress, true)
            end
        elseif actionInfo.needSecond then
            
            modifyIconPath = InputManager.GetKeyIconPath(actionInfo.secondaryKeyboardInput, true, isLongPress, true)
            iconPath = InputManager.GetKeyIconPath(actionInfo.secondaryKeyboardInput, false, isLongPress, true)
        end

        if isMutable then
            
            view.button.onClick:AddListener(function()
                self:_KeyShowKeyCodePopup(itemData, actionIds, isPrimary)
            end)
            if string.isEmpty(iconPath) then
                stateName = "Empty" 
            else
                isSet = true
                stateName = "Normal" 
                view.button.onHoverChange:AddListener(function(isHover)
                    view.delBtn.gameObject:SetActive(isHover)
                end)
                view.delBtn.onClick:AddListener(function()
                    if self:_KeyDeleteActions(itemData, actionIds, isPrimary) then
                        self:_RefreshCurrentSettingTab()
                        AudioAdapter.PostEvent("Au_UI_Toast_SetShortcutError") 
                    end
                end)
            end
        else
            
            if not string.isEmpty(iconPath) then
                isSet = true
            end
            stateName = "Locked" 
        end
    else
        
        
        if not string.isEmpty(iconPath) then
            isSet = true
            iconPath = KEYICON_PATH .. iconPath .. ".png"
        end
        stateName = "Locked" 
    end

    view.text.text = nil

    if string.isEmpty(iconPath) then
        view.modifyIcon.gameObject:SetActive(false)
        view.icon.gameObject:SetActive(false)
    else
        local showModifyIcon = not string.isEmpty(modifyIconPath)
        view.modifyIcon.gameObject:SetActive(showModifyIcon)
        if showModifyIcon then
            view.modifyIcon:LoadSpriteWithOutFormat(modifyIconPath)
        end
        local showIcon = not string.isEmpty(iconPath)
        view.icon.gameObject:SetActive(showIcon)
        if showIcon then
            view.icon:LoadSpriteWithOutFormat(iconPath)
        end
    end

    view.stateCtrl:SetState(stateName)

    return isSet
end




GameSettingCtrl._GetSettingFunctionName = HL.Method(HL.String).Return(HL.String) << function(self, functionName)
    if not string.isEmpty(functionName) then
        functionName = "_" .. functionName
    end

    return functionName
end




GameSettingCtrl._ValidateVideoNotchPadding = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    local currentRatio = self.m_rootCanvasWidth / self.m_rootCanvasHeight
    local standardRatio = STANDARD_HORIZONTAL_RESOLUTION / STANDARD_VERTICAL_RESOLUTION
    if currentRatio > standardRatio then
        return true 
    end
    local safeArea = Screen.safeArea
    if safeArea.x > 0 or safeArea.y > 0 then
        return true 
    end
    if CS.Beyond.UI.UIConst.IsPadDevice() then
        return true 
    end
    return false
end




GameSettingCtrl._ValidateQualitySubSetting = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return GameSettingHelper.IsQualitySubSettingValid(settingId)
end





GameSettingCtrl._ValidateVideoQualityMainSetting = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not UNITY_PS5
end





GameSettingCtrl._ValidatePSVideoQualityMainSetting = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return UNITY_PS5
end




GameSettingCtrl._ValidateHudLayout = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    if DeviceInfo.usingController then
        return false 
    end
    return true
end




GameSettingCtrl._ValidateLanguageTextChangeSetting = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    
    return not UIManager:IsOpen(PanelId.CommonTaskTrackHud)
end




GameSettingCtrl._ValidateBackgroundMusic = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return CS.Beyond.GlobalOptions.instance.auditing 
end




GameSettingCtrl._ValidateWebView = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not GameInstance.player.gameSettingSystem.forbiddenWebView
end




GameSettingCtrl._ValidateCDK = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return not CS.Beyond.GlobalOptions.instance.auditing 
        and not GameInstance.player.gameSettingSystem.forbiddenCDK 
end










GameSettingCtrl._DropdownAdjustExpandDirection = HL.Method(HL.Any, HL.Any) << function(self, cell, originalCell)
    
    originalCell.rectTransform:SetSiblingIndex(originalCell.rectTransform.parent.childCount - 1)

    
    local viewRect = self.view.scrollView.transform
    local cellRect = cell.rectTransform
    local listRect = cell.dropDownListRectTransform
    local listMask = cell.dropDownListMask
    
    local cellRectMax = cellRect.rect.max
    local cellRectMaxWorldPos = cellRect:TransformPoint(Vector3(cellRectMax.x, cellRectMax.y, 0))
    local cellRectMaxLocalPos = viewRect:InverseTransformPoint(cellRectMaxWorldPos)
    local isInUpperHalf = (cellRectMaxLocalPos.y - listRect.rect.height) >= viewRect.rect.yMin
    
    listRect.pivot = isInUpperHalf and Vector2(0.5, 1.0) or Vector2(0.5, 0)
    listRect.anchorMin = isInUpperHalf and Vector2(0, 1.0) or Vector2(0, 0)
    listRect.anchorMax = isInUpperHalf and Vector2(1.0, 1.0) or Vector2(1.0, 0)
    listRect.anchoredPosition = Vector2.zero
    
    local maskPadding = listMask.padding
    maskPadding.w = isInUpperHalf and self.m_originalPadding or 0
    maskPadding.y = isInUpperHalf and 0 or self.m_originalPadding
    listMask.padding = maskPadding
    cell.topMask.gameObject:SetActive(not isInUpperHalf)
    cell.bottomMask.gameObject:SetActive(isInUpperHalf)
    
    cell.layoutStateCtrl:SetState(isInUpperHalf and "Downward" or "Upward")
end




GameSettingCtrl._DropdownGetOptionIndex = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    local success, value = GameSetting.GameSettingGetInt(settingId)
    if success then
        return value
    end

    logger.error("GameSetting: 在打开界面时尝试获取一个尚未存在的设置项数值", settingId)
    return 1
end






GameSettingCtrl._DropdownGetIndexVideoResolution = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    local resolutionList = GameSetting.availableScreenResolutionList
    local currentResolution = GameSetting.videoResolution
    for i = 0, resolutionList.Count - 1 do
        local resolution = resolutionList[i]
        if resolution.height <= currentResolution.height and resolution.width <= currentResolution.width then
            return i + 1
        end
    end

    return 1
end




GameSettingCtrl._DropdownGetVideoMainQualityTextList = HL.Method(HL.Any).Return(HL.Table, HL.Table) << function(self, itemData)
    local qualityTextList = {}
    local qualityStateList = {}
    local optionTextData = itemData.dropdownOptionTextList
    if optionTextData ~= nil then
        local defaultQualityIndex = GameSettingHelper.GetDefaultVideoQualityIndex()  
        for i = 0, optionTextData.length - 1 do
            if not string.isEmpty(optionTextData[i]) then
                local text = optionTextData[i]
                local state = DROPDOWN_OPTION_STATE_NORMAL
                if i == defaultQualityIndex then
                    table.insert(qualityTextList, string.format(Language[DROPDOWN_MAIN_QUALITY_DEFAULT_TEXT_ID], text))
                else
                    table.insert(qualityTextList, text)
                    if i > 0 then
                        local isValid = GameSettingHelper.IsValidQualityIndex(i)
                        if not isValid then
                            state = DROPDOWN_OPTION_STATE_DISABLED 
                        else
                            local isRecommended = i >= defaultQualityIndex
                            if not isRecommended then
                                state = DROPDOWN_OPTION_STATE_WARNING 
                            end
                        end
                    end
                end
                table.insert(qualityStateList, state)
            end
        end
    end
    return qualityTextList, qualityStateList
end




GameSettingCtrl._DropdownGetPSVideoMainQualityTextList = HL.Method(HL.Any).Return(HL.Table, HL.Table) << function(self, itemData)
    local qualityTextList = {}
    local qualityStateList = {}
    local optionTextData = itemData.dropdownOptionTextList
    if optionTextData ~= nil then
        local defaultQualityIndex = GameSettingHelper.GetDefaultVideoQualityIndex()  
        
        for i = 1, optionTextData.length - 1 do
            if not string.isEmpty(optionTextData[i]) then
                local text = optionTextData[i]
                local state = DROPDOWN_OPTION_STATE_NORMAL
                if i == defaultQualityIndex then
                    table.insert(qualityTextList, string.format(Language[DROPDOWN_MAIN_QUALITY_DEFAULT_TEXT_ID], text))
                else
                    local isValid = GameSettingHelper.IsValidQualityIndex(i)
                    if isValid then
                        table.insert(qualityTextList, text)
                        local isRecommended = i >= defaultQualityIndex
                        if not isRecommended then
                            state = DROPDOWN_OPTION_STATE_WARNING 
                        end
                        table.insert(qualityStateList, state)
                    end
                end
            end
        end
    end
    return qualityTextList, qualityStateList
end




GameSettingCtrl._DropdownGetVideoResolutionTextList = HL.Method(HL.Any).Return(HL.Table) << function(self, itemData)
    local resolutionList = GameSetting.availableScreenResolutionList
    local resolutionTextList = {}
    for i = 0, resolutionList.Count - 1 do
        local resolution = resolutionList[i]
        if resolution.isFullScreen then
            table.insert(resolutionTextList, string.format(Language[DROPDOWN_FULL_SCREEN_RESOLUTION_TEXT_ID], resolution.width, resolution.height))
        else
            table.insert(resolutionTextList, string.format(Language[DROPDOWN_WINDOWED_RESOLUTION_TEXT_ID], resolution.width, resolution.height))
        end
    end
    return resolutionTextList
end





GameSettingCtrl._DropdownOnSelectVideoResolution = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    local listIndex = index - 1
    local resolutionList = GameSetting.availableScreenResolutionList
    if listIndex < 0 or listIndex >= resolutionList.Count then
        return
    end

    local resolution = resolutionList[listIndex]
    if resolution.width <= 0 or resolution.height <= 0 then
        return
    end

    GameSettingSetter.graphicsResolution:Set(resolution.width, resolution.height)

    
    self:_RefreshLoad(true)
end





GameSettingCtrl._DropdownOnSelectLanguageText = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    local lastIndex = CSIndex(self:_DropdownGetIndexLanguageText(settingId))
    local dropdown = self.m_itemCellMap[settingId].dropdown
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language[LANGUAGE_TEXT_POP_UP_CONTENT_TEXT_ID],
        freezeWorld = true,
        hideBlur = true,
        onConfirm = function()
            local lang = CS.Beyond.I18n.I18nUtils.GetLangByIndex(CSIndex(index))
            GameSettingSetter.languageText:Set(lang:GetHashCode())
        end,
        onCancel = function()
            if dropdown ~= nil then
                dropdown:SetSelected(lastIndex, false, false)
            end
        end
    })
end




GameSettingCtrl._DropdownGetIndexLanguageText = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    local languageText = LuaIndex(CS.Beyond.I18n.I18nUtils.GetLangShowOrder(GameSetting.languageText))
    return languageText
end




GameSettingCtrl._DropdownGetLanguageTextTextList = HL.Method(HL.Any).Return(HL.Table) << function(self, itemData)
    local textList = {}
    local typeList = {}
    for i = 0, GEnums.EnvLang.MAX:GetHashCode() - 1 do
        local langType = Utils.intToEnum(typeof(GEnums.EnvLang), i)
        table.insert(typeList, langType)
    end
    table.sort(typeList, function(left, right)
        return CS.Beyond.I18n.I18nUtils.GetLangShowOrder(left) < CS.Beyond.I18n.I18nUtils.GetLangShowOrder(right)
    end)

    for i = 1, #typeList do
        local textKey = "UI_LOGIN_ROOT_LANGUAGE_" .. typeList[i]:ToString()
        local text = CS.Beyond.I18n.I18nUtils.GetText(textKey)
        table.insert(textList, text)
    end
    return textList
end




GameSettingCtrl._DropdownGetLanguageAudioTextList = HL.Method(HL.Any).Return(HL.Table) << function(self, itemData)
    local configTextList = itemData.dropdownOptionTextList
    local optionTextList = {}
    for i = 0, configTextList.Count - 1 do
        local optionText = configTextList[i]
        if string.isEmpty(optionText) then
            break
        end
        local languageAudio = Utils.intToEnum(typeof(GameSetting.GameSettingLanguageAudio), i + 1)
        local vfsBlockType = GameSettingHelper.ToVFSBlockType(languageAudio)
        local isDownloaded = GameInstance.resPrefManager:GetResourcePreferred(vfsBlockType)
        if not isDownloaded then
            
            local resourceSize = GameInstance.resPrefManager:GetResourceSize(vfsBlockType)
            optionText = string.format("%1$s (%2$.2fMB)", optionText, resourceSize / MB)
        end
        table.insert(optionTextList, optionText)
    end
    return optionTextList
end






GameSettingCtrl._DropdownOnValidateSelectLanguageAudio = HL.Method(HL.Userdata, HL.Number, HL.Number)
                                                           .Return(HL.Boolean)
    << function(self, itemData, fromIndex, toIndex)
    local languageAudio = Utils.intToEnum(typeof(GameSetting.GameSettingLanguageAudio), toIndex)
    local vfsBlockType = GameSettingHelper.ToVFSBlockType(languageAudio)
    local isDownloaded = GameInstance.resPrefManager:GetResourcePreferred(vfsBlockType)
    if isDownloaded then
        return true 
    end

    
    local languageName = itemData.dropdownOptionTextList[CSIndex(toIndex)]
    local resourceSize = GameInstance.resPrefManager:GetResourceSize(vfsBlockType)
    Notify(MessageConst.SHOW_POP_UP, {
        content = string.format(Language.LUA_GAME_SETTING_VOICE_DOWNLOAD_POP_UP_CONTENT, languageName, resourceSize / MB),
        onConfirm = function()
            GameInstance.resPrefManager:SetVocResDownload(vfsBlockType)
            GameSettingSetter.languageAudio:Set(languageAudio)
            GameInstance.instance:ReturnToLogin()
        end
    })
    return false
end





GameSettingCtrl._DropdownOnSelectLanguageAudio = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameSettingSetter.languageAudio:Set(index)
end





GameSettingCtrl._DropdownOnSelectAudioSuiteMode = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameSettingSetter.audioSuiteMode:Set(index)
end





GameSettingCtrl._DropdownOnSelectControllerAutoLockTarget = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameSettingSetter.controllerAutoLockTarget:Set(index)
end





GameSettingCtrl._DropdownOnSelectComboSkillCameraAlpha = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameSettingSetter.comboSkillCameraAlpha:Set(index)
end




GameSettingCtrl._DropdownGetGamepadSettingTextList = HL.Method(HL.Any).Return(HL.Table) << function(self, itemData)
    local textList = {}
    local settingId = itemData.settingId
    local existed, optionGroupData = Tables.gamepadSettingOptionTable:TryGetValue(settingId)
    if not existed then
        logger.error("[GameSetting] Gamepad setting options not found, settingId: " .. tostring(settingId))
        return textList
    end

    
    local formatArgs = {}
    local options = optionGroupData.options
    for i = 0, options.Count - 1 do
        local optionData = options[i]
        
        lume.clear(formatArgs)
        local optionTextFormatKeys = optionData.optionTextFormatKeys
        for j = 0, optionTextFormatKeys.Count - 1 do
            local keyStr = string.lower(optionTextFormatKeys[j])
            table.insert(formatArgs, InputManager.GetGamepadKeyIconPath(keyStr, false, false))
        end
        
        local success, optionText = xpcall(string.format, debug.traceback, optionGroupData.optionText, unpack(formatArgs))
        if not success then
            logger.error("[GameSetting] Get gamepad setting option text failed, settingId: " .. tostring(settingId)
                .. ", optionIndex: " .. tostring(optionData.optionIndex))
            optionText = ""
        end
        textList[optionData.optionIndex] = optionText
    end
    return textList
end




GameSettingCtrl._DropdownGetIndexGamepadSetting = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return GameInstance.player.gameSettingSystem:GetDropdownValue(settingId)
end





GameSettingCtrl._DropdownOnSelectGamepadSetting = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameInstance.player.gameSettingSystem:SetDropdownValue(settingId, index)
    self:_RefreshCurrentSettingTab()
end











GameSettingCtrl._SliderRefreshText = HL.Method(HL.Any, HL.Number, HL.Boolean) << function(self, sliderItemCell, value, wholeNumbersText)
    local valueText = ""
    if wholeNumbersText then
        valueText = string.format("%d", math.floor(value + 0.5))
    else
        valueText = string.format("%.1f", value)
    end
    sliderItemCell.sliderValueText.text = valueText
end




GameSettingCtrl._SliderGetValue = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    local success, value = GameSetting.GameSettingGetFloat(settingId)
    if success then
        return value
    end

    logger.error("GameSetting: 在打开界面时尝试获取一个尚未存在的设置项数值", settingId)
    return 0
end






GameSettingCtrl._SliderGetIcon = HL.Method(HL.Number, HL.Any, HL.Any).Return(HL.Any) << function(self, value, iconList, rangeList)
    local listLength = math.min(#iconList, #rangeList)
    if listLength == 0 then
        return nil
    end

    for i = 0, listLength - 1 do
        if value <= rangeList[i] then
            return self:LoadSprite(UIConst.UI_SPRITE_GAME_SETTING, iconList[i])
        end
    end

    return self:LoadSprite(UIConst.UI_SPRITE_GAME_SETTING, iconList[listLength - 1])
end





GameSettingCtrl._SliderRecordValue = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local sliderValueData = self.m_sliderValueDataMap[settingId]
    if sliderValueData == nil then
        return
    end

    sliderValueData.currValue = value
    if value > sliderValueData.minValue then
        sliderValueData.lastValidValue = value
    end
end




GameSettingCtrl._SliderOnAudioIconClicked = HL.Method(HL.String) << function(self, settingId)
    local valueData = self.m_sliderValueDataMap[settingId]
    if valueData == nil then
        return
    end
    local slider = self.m_itemCellMap[settingId].slider
    if valueData.currValue > valueData.minValue then
        slider.value = valueData.minValue
    else
        local nextValue = valueData.lastValidValue == nil and valueData.maxValue or valueData.lastValidValue
        slider.value = nextValue
    end
end






GameSettingCtrl._SliderGetMaxNotchPadding = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    local settingData = self.m_itemDataMap[settingId]
    local originalMaxValue = settingData.sliderMaxValue
    local maxValue = math.min(originalMaxValue, (self.m_rootCanvasWidth - STANDARD_HORIZONTAL_RESOLUTION) / 2)
    maxValue = math.max(maxValue, GameSettingHelper.GetGameSettingDefaultCanvasPadding(self.m_rootCanvasWidth, STANDARD_HORIZONTAL_RESOLUTION))

    return maxValue
end




GameSettingCtrl._SliderGetGlobalVolume = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return VOLUME_COEFFICIENT * self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetVoiceVolume = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return VOLUME_COEFFICIENT * self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetMusicVolume = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return VOLUME_COEFFICIENT * self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetSfxVolume = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return VOLUME_COEFFICIENT * self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetCameraSpeedX = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetCameraSpeedY = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetCameraTopViewSpeed = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetWalkRunRatio = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return self:_SliderGetValue(settingId)
end




GameSettingCtrl._SliderGetNotchPadding = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return GameSettingHelper.GetGameSettingCanvasPaddingFromNotchPadding(self:_SliderGetValue(settingId), self.m_rootCanvasWidth)
end





GameSettingCtrl._SliderSetGlobalVolume = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local systemValue = value / VOLUME_COEFFICIENT
    GameSettingSetter.audioGlobalVolume:Set(systemValue)
end





GameSettingCtrl._SliderSetVoiceVolume = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local systemValue = value / VOLUME_COEFFICIENT
    GameSettingSetter.audioVoiceVolume:Set(systemValue)
end





GameSettingCtrl._SliderSetMusicVolume = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local systemValue = value / VOLUME_COEFFICIENT
    GameSettingSetter.audioMusicVolume:Set(systemValue)
end





GameSettingCtrl._SliderSetSfxVolume = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local systemValue = value / VOLUME_COEFFICIENT
    GameSettingSetter.audioSfxVolume:Set(systemValue)
end





GameSettingCtrl._SliderSetCameraSpeedX = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    GameSettingSetter.controllerCameraSpeedX:Set(value)
end





GameSettingCtrl._SliderSetCameraSpeedY = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    GameSettingSetter.controllerCameraSpeedY:Set(value)
end





GameSettingCtrl._SliderSetCameraTopViewSpeed = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    GameSettingSetter.controllerCameraTopViewSpeed:Set(value)
end





GameSettingCtrl._SliderSetWalkRunRatio = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    GameSettingSetter.controllerWalkRunRatio:Set(value)
end





GameSettingCtrl._SliderSetNotchPadding = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    local setValue = GameSettingHelper.GetGameSettingNotchPaddingFromCanvasPadding(value, self.m_rootCanvasWidth)
    GameSettingSetter.graphicsNotchPadding:Set(setValue)
    self.m_isNotchPaddingChanged = true
    self.view.notchAdapter:ApplyNewNotch()

    if self.m_notchPaddingViewTick < 0 then
        UIUtils.PlayAnimationAndToggleActive(self.view.mobileNotchPaddingNode.animationWrapper, true)
        self.m_notchPaddingViewTick = LuaUpdate:Add("Tick", function(deltaTime)
            self.m_notchPaddingViewTime = self.m_notchPaddingViewTime + deltaTime

            if self.m_notchPaddingViewTime >= self.view.config.NOTCH_VIEW_DURATION then
                self:_SliderClearNotchPaddingTick()
            end
        end)
    end
    self.m_notchPaddingViewTime = 0
end



GameSettingCtrl._SliderClearNotchPaddingTick = HL.Method() << function(self)
    if self.m_notchPaddingViewTick < 0 then
        return
    end
    UIUtils.PlayAnimationAndToggleActive(self.view.mobileNotchPaddingNode.animationWrapper, false)
    self.m_notchPaddingViewTick = LuaUpdate:Remove(self.m_notchPaddingViewTick)
end



GameSettingCtrl._SliderTryApplyAllNotchPadding = HL.Method() << function(self)
    if not self.m_isNotchPaddingChanged then
        return
    end
    
    if self.m_rootCanvasHelper ~= nil and self.m_rootCanvasHelper.onCanvasChanged ~= nil then
        self.m_rootCanvasHelper:ForceCanvasUpdate()
    end
    if self.m_worldRootCanvasHelper ~= nil and self.m_worldRootCanvasHelper.onCanvasChanged ~= nil then
        self.m_worldRootCanvasHelper:ForceCanvasUpdate()
    end
end




GameSettingCtrl._SliderOnGlobalVolumeIconClicked = HL.Method(HL.String) << function(self, settingId)
    self:_SliderOnAudioIconClicked(settingId)
end




GameSettingCtrl._SliderOnVoiceVolumeIconClicked = HL.Method(HL.String) << function(self, settingId)
    self:_SliderOnAudioIconClicked(settingId)
end




GameSettingCtrl._SliderOnMusicVolumeIconClicked = HL.Method(HL.String) << function(self, settingId)
    self:_SliderOnAudioIconClicked(settingId)
end




GameSettingCtrl._SliderOnSfxVolumeIconClicked = HL.Method(HL.String) << function(self, settingId)
    self:_SliderOnAudioIconClicked(settingId)
end

















GameSettingCtrl._ButtonOnAccountCenterClick = HL.Method() << function(self)
    CSUtils.OpenAccountCenter()
end




GameSettingCtrl._ButtonOnGiftCodeClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGiftCode()
end



GameSettingCtrl._ButtonOnCustomerServiceCenterClick = HL.Method() << function(self)
    CS.Beyond.Gameplay.AnnouncementSystem.OpenCustomService()
end




GameSettingCtrl._ButtonOnGameProtocolServiceClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.SERVICE)
end




GameSettingCtrl._ButtonOnGameProtocolServiceOverseaClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.OVERSEA_SERVICE)
end




GameSettingCtrl._ButtonOnGameProtocolPrivacyClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.PRIVACY)
end




GameSettingCtrl._ButtonOnGameProtocolPrivacyOverseaClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.OVERSEA_PRIVACY)
end




GameSettingCtrl._ButtonOnGameProtocolChildrenPrivacyClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.CHILDREN_PRIVACY)
end




GameSettingCtrl._ButtonOnGameProtocolPersonalInfoCollectionClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.PERSONAL_INFO_COLLECTION)
end




GameSettingCtrl._ButtonOnGameProtocolThirdPartySharedInfoClick = HL.Method() << function(self)
    CS.Beyond.SDK.SDKAccountUtils.OpenGameProtocol(CS.Beyond.SDK.SDKGameProtocolType.THIRD_PARTY_SHARED_INFO)
end




GameSettingCtrl._ButtonOnDeleteAccountClick = HL.Method() << function(self)
    GameInstance.player.gameSettingSystem:OpenDeleteAccount()
end



GameSettingCtrl._ButtonOnHudLayoutClick = HL.Method() << function(self)
    UIManager:Open(PanelId.HudLayout)
end



GameSettingCtrl._ButtonOnGetUnstuckClick = HL.Method() << function(self)
    if GameInstance.player.forbidSystem:IsForbidden(ForbidType.ForbidMapTeleport) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SYSTEM_FORBIDDEN)
        return
    end
    GameInstance.player.gameSettingSystem:RequestGetUnstuck()
end



GameSettingCtrl._ButtonOnAudioManageClick = HL.Method() << function(self)
    UIManager:Open(PanelId.GameSettingVoiceManagePopup)
end









GameSettingCtrl._ToggleGetValue = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    local success, value = GameSetting.GameSettingGetBool(settingId)
    if success then
        return value
    end

    logger.error("GameSetting: 在打开界面时尝试获取一个尚未存在的设置项数值", settingId)
    return false
end






GameSettingCtrl._ToggleGetSuspendUnfocused = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetBackgroundMusic = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetAudioController = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetAudioSpatial = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetCameraReverseX = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetCameraReverseY = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetEnableCameraFar = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetEnableAutoAttackTouch = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetEnableAutoAttackGamepad = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetAutoSprint = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetMotion = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetTriggerEffect = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetShowSmartAlert = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return self:_ToggleGetValue(settingId)
end




GameSettingCtrl._ToggleGetEnableUltimateMode2 = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return GameInstance.player.gameSettingSystem:GetToggleValue(settingId)
end




GameSettingCtrl._ToggleGetPSNOnly = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return GameInstance.player.friendSystem.isPSNOnly
end





GameSettingCtrl._ToggleSetSuspendUnfocused = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.audioSuspendUnfocused:Set(value)
end





GameSettingCtrl._ToggleSetBackgroundMusic = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.audioBackgroundMusic:Set(value)
end





GameSettingCtrl._ToggleSetAudioController = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.audioController:Set(value)
end





GameSettingCtrl._ToggleSetAudioSpatial = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.audioSpatial:Set(value)
end





GameSettingCtrl._ToggleSetCameraReverseX = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.controllerCameraReverseX:Set(value)
end





GameSettingCtrl._ToggleSetCameraReverseY = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.controllerCameraReverseY:Set(value)
end





GameSettingCtrl._ToggleSetEnableCameraFar = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.enableCameraFar:Set(value)
end





GameSettingCtrl._ToggleSetEnableAutoAttackTouch = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.enableAutoAttackTouch:Set(value)
end





GameSettingCtrl._ToggleSetEnableAutoAttackGamepad = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.enableAutoAttackGamepad:Set(value)
end





GameSettingCtrl._ToggleSetAutoSprint = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.controllerAutoSprint:Set(value)
end





GameSettingCtrl._ToggleSetMotion = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.controllerMotion:Set(value)
end





GameSettingCtrl._ToggleSetTriggerEffect = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.controllerTriggerEffect:Set(value)
end





GameSettingCtrl._ToggleSetShowSmartAlert = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameSettingSetter.otherShowSmartAlert:Set(value)
end





GameSettingCtrl._ToggleSetEnableUltimateMode2 = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameInstance.player.gameSettingSystem:SetToggleValue(settingId, value)
    self:_ApplyGamepadEnableUltimateMode2SettingToDevice()
end





GameSettingCtrl._ToggleSetPSNOnly = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    GameInstance.player.friendSystem:SetPsnOnly(value)
end











GameSettingCtrl._KeyShowKeyCodePopup = HL.Method(HL.Userdata, HL.Userdata, HL.Boolean)
    << function(self, itemData, actionIds, isPrimary)
    UIManager:Open(PanelId.GameSettingKeycodePopup, {
        settingItemData = itemData,
        isPrimary = isPrimary,
        onKeyCodeInput = function(keyCode)
            
            local actionId = actionIds[0]
            local currKeyCode = InputManagerInst:GetActionKeyboardKeyCode(actionId, false, isPrimary)
            if keyCode == currKeyCode then
                return true 
            end
            
            local conflict, conflictItemDataList = self:_KeyCheckSettingConflict(itemData, actionIds, keyCode)
            
            if conflict then
                local conflictTextBuilder = {}
                for i, conflictItemData in ipairs(conflictItemDataList) do
                    local itemName = string.format(Language.LUA_GAME_SETTING_KEY_NAME, conflictItemData.settingText)
                    table.insert(conflictTextBuilder, itemName)
                end
                local conflictText = table.concat(conflictTextBuilder)
                Notify(MessageConst.SHOW_POP_UP, {
                    content = string.format(Language.LUA_GAME_SETTING_KEY_CONFLICT, conflictText, conflictText),
                    onConfirm = function()
                        
                        UIManager:Close(PanelId.GameSettingKeycodePopup)
                        
                        for i, conflictItemData in ipairs(conflictItemDataList) do
                            self:_KeyCheckActionsConflictAndDelete(conflictItemData,
                                actionIds, conflictItemData.keyActionIds1, keyCode, true)
                            self:_KeyCheckActionsConflictAndDelete(conflictItemData,
                                actionIds, conflictItemData.keyActionIds2, keyCode, true)
                        end
                        
                        if self:_KeyChangeActions(itemData, actionIds, keyCode, isPrimary) then
                            self:_RefreshCurrentSettingTab()
                            AudioAdapter.PostEvent("Au_UI_Toast_SetShortcutError") 
                        end
                    end,
                })
                return false 
            end
            
            if self:_KeyChangeActions(itemData, actionIds, keyCode, isPrimary) then
                self:_RefreshCurrentSettingTab()
            end
            return true 
        end
    })
end







GameSettingCtrl._KeyCheckSettingConflict = HL.Method(HL.Userdata, HL.Userdata, CS.Beyond.Input.KeyboardKeyCode)
                                             .Return(HL.Boolean, HL.Opt(HL.Any))
    << function(self, itemData, actionIds, keyCode)
    local conflict = false 
    local conflictItemDataList = {} 
    local checkedItemDataMap = {}
    
    local scopes = itemData.keyActionScopes
    for i = 0, scopes.Count - 1 do
        local scope = scopes[i]
        local scopeItemDataList = self.m_keyActionScope2ItemDataList[scope] 
        
        for j, scopeItemData in ipairs(scopeItemDataList) do
            if itemData.settingId == scopeItemData.settingId or checkedItemDataMap[scopeItemData] then
                
            else
                
                if self:_KeyCheckActionsConflictAndDelete(nil, actionIds, scopeItemData.keyActionIds1, keyCode, false)
                    or self:_KeyCheckActionsConflictAndDelete(nil, actionIds, scopeItemData.keyActionIds2, keyCode, false) then
                    conflict = true
                    table.insert(conflictItemDataList, scopeItemData)
                    checkedItemDataMap[scopeItemData] = true
                end
            end
        end
    end
    return conflict, conflictItemDataList
end













GameSettingCtrl._KeyCheckActionsConflictAndDelete = HL.Method(HL.Userdata, HL.Userdata, HL.Userdata, CS.Beyond.Input.KeyboardKeyCode, HL.Boolean)
                                                      .Return(HL.Boolean)
    << function(self, itemData, srcActionIds, checkActionIds, keyCode, delete)
    local anyConflict = false 
    local checkActionId = checkActionIds.Count > 0 and checkActionIds[0] or nil
    if checkActionId then
        if lume.find(srcActionIds, checkActionId) then
            return false 
        end
        
        local conflict, isPrimary = InputManagerInst:CheckActionKeyCodeConflict(checkActionId, keyCode)
        if conflict then
            if not delete then
                return true 
            end
            anyConflict = true
            self:_KeyDeleteActions(itemData, checkActionIds, isPrimary)
        end
    end
    return anyConflict
end






GameSettingCtrl._KeyDeleteActions = HL.Method(HL.Userdata, HL.Userdata, HL.Boolean).Return(HL.Boolean)
    << function(self, itemData, actionIds, isPrimary)
    return self:_KeyChangeActions(itemData, actionIds, KeyboardKeyCode.None, isPrimary)
end







GameSettingCtrl._KeyChangeActions = HL.Method(HL.Userdata, HL.Userdata, HL.Userdata, HL.Boolean).Return(HL.Boolean)
    << function(self, itemData, actionIds, keyCode, isPrimary)
    local actionId = actionIds[0]
    local currKeyCode = InputManagerInst:GetActionKeyboardKeyCode(actionId, false, isPrimary)
    if currKeyCode == keyCode then
        return false 
    end

    
    GameInstance.player.gameSettingSystem:SetKeySetting(itemData.settingId, keyCode, isPrimary)
    
    self:_SetKeyActionState(itemData.settingId, KEY_ACTION_STATE.Dirty, isPrimary)
    return true 
end



GameSettingCtrl._KeyResetActions = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_GAME_SETTING_KEY_RESET_ALL_ACTIONS,
        onConfirm = function()
            
            GameInstance.player.gameSettingSystem:ResetAllKeySettings(InputDeviceFlags.Keyboard)
            
            GameInstance.player.gameSettingSystem:SaveSetting()
            
            self:_ClearAllKeyActionStates()
            self:_RefreshCurrentSettingTab()
        end,
    })
end



GameSettingCtrl._KeySaveActions = HL.Method() << function(self)
    local stateLevel = self:_GetKeyActionStateLevel()
    
    if HasKeyActionState(stateLevel, KEY_ACTION_STATE.Warning) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAME_SETTING_KEY_SAVE_FAILED_WARNING)
    elseif HasKeyActionState(stateLevel, KEY_ACTION_STATE.Dirty) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAME_SETTING_KEY_SAVE_SUCCESS)
        
        GameInstance.player.gameSettingSystem:SaveSetting()
        
        self:_ClearAllKeyActionStates()
        self:_RefreshCurrentSettingTab()
    end
end



GameSettingCtrl._KeyClearPendingActions = HL.Method() << function(self)
    
    GameInstance.player.gameSettingSystem:ClearAllPendingKeySettings()
    
    self:_ClearAllKeyActionStates()
end










GameSettingCtrl._InitKeyActionScopeMap = HL.Method(HL.Table) << function(self, itemDataList)
    for i, itemData in ipairs(itemDataList) do
        local scopes = itemData.keyActionScopes
        if scopes.Count == 0 then
            logger.error("[GameSetting] The action should belong to at least one scope, id: " .. tostring(itemData.settingId))
        else
            for j = 0, scopes.Count - 1 do
                local scope = scopes[j]
                local scopeItemDataList = self.m_keyActionScope2ItemDataList[scope]
                if scopeItemDataList == nil then
                    scopeItemDataList = {}
                    self.m_keyActionScope2ItemDataList[scope] = scopeItemDataList
                end
                table.insert(scopeItemDataList, itemData)
            end
        end
    end
end

local function PackKeyActionState(primaryState, secondaryState)
    return (primaryState & KEY_ACTION_STATE_MASK) + ((secondaryState & KEY_ACTION_STATE_MASK) << KEY_ACTION_STATE_BITS)
end

local function UnpackKeyActionState(state)
    return (state & KEY_ACTION_STATE_MASK), ((state >> KEY_ACTION_STATE_BITS) & KEY_ACTION_STATE_MASK)
end




GameSettingCtrl._GetKeyActionState = HL.Method(HL.String)
                                       .Return(HL.Number, HL.Opt(HL.Number))
    << function(self, settingId)
    local state = self.m_keyActionStateMap[settingId]
    if state == nil then
        return KEY_ACTION_STATE.None, KEY_ACTION_STATE.None
    end
    local primaryState, secondaryState = UnpackKeyActionState(state)
    return primaryState, secondaryState
end






GameSettingCtrl._SetKeyActionState = HL.Method(HL.String, HL.Number, HL.Boolean)
    << function(self, settingId, newState, isPrimary)
    local primaryState, secondaryState = self:_GetKeyActionState(settingId)
    if isPrimary then
        primaryState = newState
    else
        secondaryState = newState
    end
    self.m_keyActionStateMap[settingId] = PackKeyActionState(primaryState, secondaryState)
end






GameSettingCtrl._AddKeyActionState = HL.Method(HL.String, HL.Number, HL.Boolean)
    << function(self, settingId, state, isPrimary)
    local primaryState, secondaryState = self:_GetKeyActionState(settingId)
    if isPrimary then
        primaryState = primaryState | state
    else
        secondaryState = secondaryState | state
    end
    self.m_keyActionStateMap[settingId] = PackKeyActionState(primaryState, secondaryState)
end






GameSettingCtrl._RemoveKeyActionState = HL.Method(HL.String, HL.Number, HL.Boolean)
    << function(self, settingId, state, isPrimary)
    local primaryState, secondaryState = self:_GetKeyActionState(settingId)
    if isPrimary then
        if not HasKeyActionState(primaryState, state) then
            return
        end
        primaryState = primaryState & ~state
    else
        if not HasKeyActionState(secondaryState, state) then
            return
        end
        secondaryState = secondaryState & ~state
    end
    self.m_keyActionStateMap[settingId] = PackKeyActionState(primaryState, secondaryState)
end



GameSettingCtrl._GetKeyActionStateLevel = HL.Method().Return(HL.Number) << function(self)
    local stateLevel = KEY_ACTION_STATE.None
    for settingId, state in pairs(self.m_keyActionStateMap) do
        local primaryState, secondaryState = UnpackKeyActionState(state)
        stateLevel = stateLevel | primaryState | secondaryState
        if stateLevel == KEY_ACTION_STATE_MAX_LEVEL then
            break
        end
    end
    return stateLevel
end



GameSettingCtrl._IsAnyKeyActionStateDirty = HL.Method().Return(HL.Boolean) << function(self)
    local stateLevel = self:_GetKeyActionStateLevel()
    return stateLevel ~= KEY_ACTION_STATE.None
end



GameSettingCtrl._ClearAllKeyActionStates = HL.Method() << function(self)
    lume.clear(self.m_keyActionStateMap)
end









GameSettingCtrl._InsertSubQualityItemDataList = HL.Method(HL.Table) << function(self, itemDataList)
    
    local originalCount = #itemDataList
    for settingId, subQualityData in pairs(Tables.qualitySubSettingTable) do
        if self:_IsSettingItemValid(settingId, "ValidateQualitySubSetting") then
            local itemData = {}
            itemData.settingId = settingId
            itemData.settingGroupTitle = subQualityData.settingGroupTitle
            local configSuccess, itemConfig = GameSettingHelper.GetQualitySubSettingConfigBySettingId(settingId)
            if configSuccess then
                local itemTypeSuccess, settingItemType = GameSettingHelper.GetQualitySubSettingItemTypeBySettingId(settingId)
                if itemTypeSuccess then
                    itemData.settingItemType = settingItemType

                    if settingItemType == GEnums.SettingItemType.Dropdown then
                        self:_DropdownBuildQualitySubSettingItemData(itemData, itemConfig)
                    elseif settingItemType == GEnums.SettingItemType.Toggle then
                        self:_ToggleBuildQualitySubSettingItemData(itemData, itemConfig)
                    elseif settingItemType == GEnums.SettingItemType.Slider then
                        self:_SliderBuildQualitySubSettingItemData(itemData, itemConfig)
                    end

                    itemData.settingText = subQualityData.settingText
                    itemData.settingSortOrder = originalCount + 1 + subQualityData.settingSortOrder
                    itemData.refreshViewOnValueChanged = itemConfig.refreshViewOnValueChanged
                    itemData.ignoreMainChange = itemConfig.ignoreMainChange

                    table.insert(itemDataList, itemData)
                end
            else
                logger.error("画质子项没有在Config中配置", settingId)
            end
        end
    end
end





GameSettingCtrl._DropdownBuildQualitySubSettingItemData = HL.Method(HL.Table, HL.Userdata) << function(self, itemData, itemConfig)
    local settingId = itemData.settingId
    itemData.dropdownOptionValidateSelectFunction = "DropdownValidateSetQualitySubSettingOptionIndex"
    local optionGroupConfig = itemConfig:DropdownGetOptionGroupConfig(QualityManagerInst.device.m_platform)
    local optionTextList = {}  
    local optionStateList = {}
    for index = 0, optionGroupConfig.optionList.Count - 1 do
        local optionConfig = optionGroupConfig.optionList[index]
        local optionId = optionConfig.optionId
        local tableData = Tables.qualitySubSettingOptionTable[optionId]
        table.insert(optionTextList, tableData.optionText)
        local state = DROPDOWN_OPTION_STATE_NORMAL
        local isValid = GameSettingHelper.IsQualitySubSettingTierValid(settingId, index)
        if not isValid then
            state = SubQualityOptionStateToDropdownOptionState[optionGroupConfig.stateOnNotValid] 
        else
            local isRecommended = GameSettingHelper.IsQualitySubSettingTierRecommended(settingId, index)
            if not isRecommended then
                state = SubQualityOptionStateToDropdownOptionState[optionGroupConfig.stateOnNotRecommended] 
            end
        end
        table.insert(optionStateList, state)
    end
    
    local tierCount = GameSettingHelper.GetQualitySubSettingCountBySettingId(settingId)
    if tierCount ~= #optionTextList then
        if tierCount > #optionTextList then
            logger.error("画质子项配置选项数量与ComponentTierCount不一致，可能导致越界或设置效果不一致等问题", itemConfig.qualityComponentType)
        else
            optionTextList = lume.slice(optionTextList, #optionTextList - tierCount + 1, #optionTextList)
            optionStateList = lume.slice(optionStateList, #optionStateList - tierCount + 1, #optionStateList)
        end
    end
    itemData.optionTextList = optionTextList
    itemData.optionStateList = optionStateList
end






GameSettingCtrl._DropdownOnValidateSelectVideoQuality = HL.Method(HL.Userdata, HL.Number, HL.Number)
                                                          .Return(HL.Boolean)
    << function(self, itemData, fromIndex, toIndex)
    local csToIndex = CSIndex(toIndex)

    
    if csToIndex == 0 then
        return true
    end

    
    local isValid = GameSettingHelper.IsValidQualityIndex(csToIndex)
    if not isValid then
        return false
    end

    
    local csDefaultIndex = GameSettingHelper.GetDefaultVideoQualityIndex()
    local isRecommended = csToIndex >= csDefaultIndex
    if not isRecommended then
        UIManager:Open(PanelId.GameSettingWarningPopUp, {
            content = string.format(Language.LUA_GAME_SETTING_QUALITY_SELECT_CONFIRM, itemData.settingText),
            warningContent = Language.LUA_GAME_SETTING_QUALITY_SELECT_CONFIRM_WARNING,
            onForceConfirm = function()
                local itemCell = self.m_itemCellMap[itemData.settingId]
                itemCell.dropdown:SetSelected(csToIndex, false, true)
            end,
        })
        return false
    end

    return true
end






GameSettingCtrl._DropdownOnValidateSelectPSVideoQuality = HL.Method(HL.Userdata, HL.Number, HL.Number)
                                                            .Return(HL.Boolean)
    << function(self, itemData, fromIndex, toIndex)
    
    return self:_DropdownOnValidateSelectVideoQuality(itemData, fromIndex + 1, toIndex + 1)
end





GameSettingCtrl._DropdownOnSelectPSVideoQuality = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    local lastIndex = self:_DropdownGetIndexPSVideoQuality(settingId)
    local dropdown = self.m_itemCellMap[settingId].dropdown
    
    self:_DoSelectVideoQuality(index + 1, lastIndex + 1, dropdown)
end





GameSettingCtrl._DropdownOnSelectVideoQuality = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    local lastIndex = self:_DropdownGetIndexVideoQuality(settingId)
    local dropdown = self.m_itemCellMap[settingId].dropdown

    if index == CUSTOM_QUALITY_SETTING_INDEX then
        GameSettingHelper.SetQualityCustomState(true)
    else
        self:_DoSelectVideoQuality(index, lastIndex, dropdown)
    end
end






GameSettingCtrl._DoSelectVideoQuality = HL.Method(HL.Number, HL.Number, HL.Userdata) << function(self, index, lastIndex, dropdown)
    local qualityIndex = index - 1 
    if GameSettingHelper.IsValidQualityIndex(qualityIndex) then
        
        
        
        GameSettingHelper.SetQualityCustomState(false)
        GameSettingSetter.graphicsQuality:Set(qualityIndex, true)
        self:_UpdateAndRefreshQualitySubSettingsState() 

        
        self:_RefreshLoad(true)

        
        local needRestart = QualityManagerInst:NeedRestart()
        if needRestart then
            self:_ShowRebootTips()
        end
    else
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language[QUALITY_POP_UP_CONTENT_TEXT_ID],
            freezeWorld = true,
            hideBlur = true,
            hideCancel = true,
            onConfirm = function()
                if dropdown ~= nil then
                    dropdown:SetSelected(CSIndex(lastIndex), false, false)
                end
            end
        })
    end
end




GameSettingCtrl._DropdownGetIndexVideoQuality = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    if GameSettingHelper.GetQualityCustomState() then
        return CUSTOM_QUALITY_SETTING_INDEX
    else
        return GameSettingHelper.GetQualityIndex() + 1
    end
end




GameSettingCtrl._DropdownGetIndexPSVideoQuality = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return GameSettingHelper.GetQualityIndex()
end



GameSettingCtrl._UpdateAndRefreshQualitySubSettingsState = HL.Method() << function(self)
    for settingId, subSettingData in pairs(self.m_qualitySubSettingDataMap) do
        if not subSettingData.itemData.ignoreMainChange then
            GameSetting.RemoveGameSettingSaveValue(settingId)

            local itemCell = subSettingData.itemCell
            local itemType = subSettingData.itemData.settingItemType
            if itemType == GEnums.SettingItemType.Dropdown then
                local index = self:_DropdownGetQualitySubSettingOptionIndex(settingId)
                itemCell.dropdown:SetSelected(CSIndex(index), false, false)
            elseif itemType == GEnums.SettingItemType.Toggle then
                local value = self:_ToggleGetQualitySubSettingValue(settingId)
                itemCell.toggle:SetValue(value, true)
            elseif itemType == GEnums.SettingItemType.Slider then
                local value = self:_SliderGetQualitySubSettingValue(settingId)
                itemCell.slider:SetValueWithoutNotify(value)
            end
        end
    end
end




GameSettingCtrl._DropdownGetQualitySubSettingOptionIndex = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return GameSettingHelper.GetQualitySubSettingTierBySettingId(settingId)
end






GameSettingCtrl._DropdownValidateSetQualitySubSettingOptionIndex = HL.Method(HL.Table, HL.Number, HL.Number)
                                                                     .Return(HL.Boolean)
    << function(self, itemData, fromIndex, toIndex)
    local csToIndex = CSIndex(toIndex)
    local optionState = itemData.optionStateList[toIndex]
    if optionState == DROPDOWN_OPTION_STATE_NORMAL then
        return true 
    end

    
    if optionState == DROPDOWN_OPTION_STATE_WARNING then
        UIManager:Open(PanelId.GameSettingWarningPopUp, {
            content = string.format(Language.LUA_GAME_SETTING_QUALITY_SELECT_CONFIRM, itemData.settingText),
            warningContent = Language.LUA_GAME_SETTING_QUALITY_SELECT_CONFIRM_WARNING,
            onForceConfirm = function()
                local itemCell = self.m_itemCellMap[itemData.settingId]
                itemCell.dropdown:SetSelected(csToIndex, false, true)
            end,
        })
    end

    return false
end





GameSettingCtrl._DropdownSetQualitySubSettingOptionIndex = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    self:_SetQualitySubSettingTier(settingId, index)
end





GameSettingCtrl._DropdownOnSelectCameraImpulseLevel = HL.Method(HL.String, HL.Number) << function(self, settingId, index)
    GameSettingSetter.cameraImpulseLevel:Set(index)
end





GameSettingCtrl._ToggleBuildQualitySubSettingItemData = HL.Method(HL.Table, HL.Userdata) << function(self, itemData, itemConfig)

end




GameSettingCtrl._ToggleGetQualitySubSettingValue = HL.Method(HL.String).Return(HL.Boolean) << function(self, settingId)
    return GameSettingHelper.GetQualitySubSettingTierBySettingId(settingId) > 0
end





GameSettingCtrl._ToggleSetQualitySubSettingValue = HL.Method(HL.String, HL.Boolean) << function(self, settingId, value)
    local toggleTier = value and 1 or 0
    self:_SetQualitySubSettingTier(settingId, toggleTier)
end





GameSettingCtrl._SliderBuildQualitySubSettingItemData = HL.Method(HL.Table, HL.Userdata) << function(self, itemData, itemConfig)
    local settingId = itemData.settingId

    itemData.sliderValueGetFunction = "SliderGetQualitySubSettingValue"
    itemData.sliderValueSetFunction = "SliderSetQualitySubSettingValue"

    local sliderMinValue, sliderMaxValue = GameSettingHelper.GetQualitySubSettingCountBySettingId(settingId)
    itemData.sliderMinValue = sliderMinValue
    itemData.sliderMaxValue = sliderMaxValue
    itemData.sliderWholeNumbers = itemConfig.sliderWholeNumbers
    itemData.sliderStepValue = itemConfig.sliderStepValue
end




GameSettingCtrl._SliderGetQualitySubSettingValue = HL.Method(HL.String).Return(HL.Number) << function(self, settingId)
    return GameSettingHelper.GetQualitySubSettingTierBySettingId(settingId)
end





GameSettingCtrl._SliderSetQualitySubSettingValue = HL.Method(HL.String, HL.Number) << function(self, settingId, value)
    self:_SetQualitySubSettingTier(settingId, value)
end





GameSettingCtrl._SetQualitySubSettingTier = HL.Method(HL.String, HL.Any) << function(self, settingId, tier)
    
    local qualitySubSettingData = self.m_qualitySubSettingDataMap[settingId]
    if qualitySubSettingData == nil then
        logger.error("[GameSetting] QualitySubSetting not found, settingId: " .. tostring(settingId))
        return
    end

    local itemData = qualitySubSettingData.itemData
    if not itemData.ignoreMainChange then
        local qualityCell = self.m_itemCellMap[QUALITY_SETTING_ID]
        if qualityCell ~= nil and qualityCell.dropdown ~= nil then
            qualityCell.dropdown:SetSelected(0, false, false)
            GameSettingHelper.SetQualityCustomState(true)
        end
    end
    
    GameSettingHelper.SetQualitySubSettingTierBySettingId(settingId, tier)
    self:_OnQualitySubSettingTierChanged(itemData)
end




GameSettingCtrl._OnQualitySubSettingTierChanged = HL.Method(HL.Table) << function(self, itemData)
    
    if itemData.refreshViewOnValueChanged then
        self:_RefreshCurrentSettingTab(true)
    end

    
    local needRestart = QualityManagerInst:NeedRestart()
    if needRestart then
        self:_ShowRebootTips()
    end

    
    self:_RefreshLoad(true)
end



GameSettingCtrl._ShowRebootTips = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language[QUALITY_POP_UP_MOBILE_CONTENT_TEXT_ID],
        warningContent = Language[QUALITY_POP_UP_MOBILE_WARNING_TEXT_ID],
        freezeWorld = true,
        hideBlur = true,
        hideCancel = true,
    })
end








GameSettingCtrl._InitLoad = HL.Method() << function(self)
    self:_InitQualityLoad()
    self:_InitMemoryLoad()
end



GameSettingCtrl._InitQualityLoad = HL.Method() << function(self)
    local qualityConfig = GameInstance.dataManager.gameSettingSubQualityConfig
    local qualityLoadConfig = qualityConfig:GetQualityLoadConfig(QualityManagerInst.defaultTier)
    
    local maxQualityLoad = GameSettingHelper.CalculateDefaultQualityLoad() / qualityLoadConfig.defaultLoadRatio
    local args = {
        maxProgress = maxQualityLoad,
        currentProgressGetter = GameSettingHelper.CalculateCurrentQualityLoad,
        progressConfigs = {
            { threshold = 1.0, stateName = "High", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_CRITICAL },
            { threshold = 0.8, stateName = "High", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_EX_HIGH },
            { threshold = 0.6, stateName = "Medium", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_HIGH },
            { threshold = 0.4, stateName = "Low", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_MEDIUM },
            { threshold = 0.2, stateName = "Low", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_LOW },
            { threshold = 0.0, stateName = "Low", stateText = Language.LUA_GAME_SETTING_QUALITY_LOAD_EX_LOW },
        }, 
        onCurrentProgressChanged = function(previousProgress, currentProgress)
            
            local oldRatio = math.max(0, previousProgress / maxQualityLoad)
            local newRatio = math.max(0, currentProgress / maxQualityLoad)
            if oldRatio > 0 and newRatio > 0 then
                GameSetting.GameSettingSendEventLog("quality_load", oldRatio, newRatio)
            end
        end,
    } 
    self.view.qualityLoadBar:InitGameSettingLoadBar(args)
end



GameSettingCtrl._InitMemoryLoad = HL.Method() << function(self)
    local args = {
        maxProgress = HGUtils.GetVRAMUsageWarningThreshold(),
        currentProgressGetter = HGUtils.GetEstimatedVRAMUsage,
        progressConfigs = {
            { threshold = 1.0, stateName = "High", stateText = Language.LUA_GAME_SETTING_MEMORY_LOAD_HIGH },
            { threshold = 0.8, stateName = "Medium", stateText = Language.LUA_GAME_SETTING_MEMORY_LOAD_MEDIUM },
            { threshold = 0.0, stateName = "Low", stateText = Language.LUA_GAME_SETTING_MEMORY_LOAD_LOW },
        }, 
    } 
    self.view.memoryLoadBar:InitGameSettingLoadBar(args)
end




GameSettingCtrl._RefreshLoad = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAnim)
    local tabData = self.m_tabDataList[self.m_tabIndex]
    local show = tabData.tabId == VIDEO_TAB_ID
    self.view.loadNode.gameObject:SetActive(show)
    if not show then
        return
    end

    self:_RefreshQualityLoad(playAnim)
    self:_RefreshMemoryLoad(playAnim)
end




GameSettingCtrl._RefreshQualityLoad = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAnim)
    local show = DeviceInfo.isPC or DeviceInfo.isMobile
    self.view.qualityLoadBar.gameObject:SetActive(show)
    if not show then
        return
    end

    playAnim = playAnim == true
    self.view.qualityLoadBar:Refresh(playAnim, self.view.config.QUALITY_LOAD_BAR_TWEEN_DURATION)
end




GameSettingCtrl._RefreshMemoryLoad = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAnim)
    local show = DeviceInfo.isPC
    self.view.memoryLoadBar.gameObject:SetActive(show)
    if not show then
        return
    end

    playAnim = playAnim == true
    self.view.memoryLoadBar:Refresh(playAnim, self.view.config.QUALITY_LOAD_BAR_TWEEN_DURATION)
end








GameSettingCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



GameSettingCtrl._SetSettingItemControllerNaviTarget = HL.Method() << function(self)
    local itemDataList = self.m_itemDataList[self.m_tabIndex]
    if itemDataList == nil then
        return
    end

    InputManagerInst.controllerNaviManager:SetTarget(nil)

    local itemCount = #itemDataList
    if itemCount > 0 then
        local firstCell = self.m_itemCells:Get(1)
        InputManagerInst.controllerNaviManager:SetTarget(firstCell.naviDecorator)
    end
end




GameSettingCtrl._OnTryChangeInputDeviceType = HL.Method(HL.Any) << function(self, args)
    if GameInstance.isInGameplay then
        return 
    end
    
    Notify(MessageConst.SHOW_TOAST, Language.LUA_INPUT_DEVICE_CHANGE_FORBIDDEN)
end




GameSettingCtrl._OnControllerTypeChanged = HL.Method(HL.Any) << function(self, args)
    local controllerType = DeviceInfo.controllerType
    if controllerType == DeviceControllerType.None then
        return 
    end
    local tabData = self.m_tabDataList[self.m_tabIndex]
    local isGamepadTab = tabData.tabId == GAMEPAD_TAB_ID
    if not isGamepadTab then
        return 
    end
    self:_RefreshCurrentSettingTab() 
end








GameSettingCtrl._QueryUnreadMsg = HL.Method() << function(self)
    if UNITY_PS5 then
        return 
    end
    CS.Beyond.Gameplay.AnnouncementSystem.QueryUnreadMsg()
end



GameSettingCtrl._OnCloseCustomerService = HL.Method() << function(self)
    
    self:_QueryUnreadMsg()
end



GameSettingCtrl._OnVoiceResourceStateChanged = HL.Method() << function(self)
    
    local tabData = self.m_tabDataList[self.m_tabIndex]
    if tabData.tabId ~= LANGUAGE_TAB_ID then
        return
    end
    self:_RefreshCurrentSettingTab(true)
end





GameSettingCtrl.OpenGameSettingPhase = HL.StaticMethod() << function()
    PhaseManager:OpenPhase(PhaseId.GameSetting)
end


GameSettingCtrl.OnSystemDisplaySizeChanged = HL.StaticMethod() << function()
    CoroutineManager:StartCoroutine(function()
        coroutine.waitForRenderDone()

        if CS.Beyond.GameSetting.IsSettingNotSet(CS.Beyond.GameSetting.GetCurVideoNotchPaddingId()) then
            local defaultPadding = CS.Beyond.Gameplay.GameSettingHelper.GetGameSettingDefaultNotchPadding(
                UIManager.uiCanvasRect.rect.width,
                STANDARD_HORIZONTAL_RESOLUTION
            )
            CS.Beyond.Scripts.Entry.GameSettingSetter.graphicsNotchPadding:Set(defaultPadding)
        else
            CS.Beyond.Scripts.Entry.GameSettingSetter.graphicsNotchPadding:Set(CS.Beyond.GameSetting.videoNotchPadding)
        end

        if PhaseManager:IsOpen(PhaseId.GameSetting) then
            PhaseManager:ExitPhaseFast(PhaseId.GameSetting)
        end

        local rootCanvasHelper = UIManager.m_uiCanvasScaleHelper
        local worldRootCanvasHelper = UIManager.m_worldUICanvasScaleHelper
        if rootCanvasHelper ~= nil and rootCanvasHelper.onCanvasChanged ~= nil then
            rootCanvasHelper:ForceCanvasUpdate()
        end
        if worldRootCanvasHelper ~= nil and worldRootCanvasHelper.onCanvasChanged ~= nil then
            worldRootCanvasHelper:ForceCanvasUpdate()
        end

        Notify(MessageConst.ON_SCREEN_SIZE_CHANGED)
    end)
end

HL.Commit(GameSettingCtrl)
