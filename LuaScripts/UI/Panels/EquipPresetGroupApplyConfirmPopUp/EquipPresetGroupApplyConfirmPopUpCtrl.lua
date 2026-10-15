local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget
local UIStateControllerType = typeof(CS.Beyond.UI.UIState.UIStateController)

local OPTION_NONE = 0
local OPTION_DIRECT = 1
local OPTION_SUBSTITUTE = 2

local function GetOptionStateCtrl(optionNode)
    if not optionNode or not optionNode.gameObject then
        return nil
    end
    return optionNode.gameObject:GetComponent(UIStateControllerType)
end

EquipPresetGroupApplyConfirmPopUpCtrl = HL.Class(
    'EquipPresetGroupApplyConfirmPopUpCtrl', uiCtrl.UICtrl)

EquipPresetGroupApplyConfirmPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {}

EquipPresetGroupApplyConfirmPopUpCtrl.m_selectedOption = HL.Field(HL.Number) << OPTION_NONE

EquipPresetGroupApplyConfirmPopUpCtrl.m_canUseSubstitute = HL.Field(HL.Boolean) << false

EquipPresetGroupApplyConfirmPopUpCtrl.m_onConfirm = HL.Field(HL.Function)

EquipPresetGroupApplyConfirmPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_selectedOption = OPTION_NONE
    self.m_canUseSubstitute = arg and arg.canUseSubstitute == true or false
    self.m_onConfirm = arg and arg.onConfirm or nil

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
        self.view.inputGroup.groupId,
    })

    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.btnCancel.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.mask.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.btnAward.onClick:AddListener(function()
        self:_OnConfirm()
    end)
    self.view.partOneBtn.onClick:AddListener(function()
        self:_SelectOption(OPTION_DIRECT)
    end)
    self.view.partTwoBtn.onClick:AddListener(function()
        self:_SelectOption(OPTION_SUBSTITUTE)
    end)
    self.view.partOneBtn.onIsNaviTargetChanged = function(isTarget)
        if DeviceInfo.usingController and isTarget then
            self:_SelectOption(OPTION_DIRECT)
        end
    end
    self.view.partTwoBtn.onIsNaviTargetChanged = function(isTarget)
        if DeviceInfo.usingController and isTarget then
            self:_SelectOption(OPTION_SUBSTITUTE)
        end
    end
    self.view.partOneBtn:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
    self.view.partTwoBtn:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
    self:_RefreshText()
    self:_RefreshSelection()
    if not GetOptionStateCtrl(self.view.partOneNode)
        or not GetOptionStateCtrl(self.view.partTwoNode) then
        logger.error(
            "EquipPresetGroupApplyConfirmPopUpCtrl: option node missing UIStateController")
    end
end

EquipPresetGroupApplyConfirmPopUpCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshText()
    self:_RefreshSelection()
end

EquipPresetGroupApplyConfirmPopUpCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if DeviceInfo.usingController then
        self:_SelectOption(OPTION_DIRECT)
        self:SetNaviTarget(self.view.partOneBtn)
    end
end

EquipPresetGroupApplyConfirmPopUpCtrl._RefreshText = HL.Method() << function(self)
    self.view.titleText.text = Language.LUA_EQUIP_PRESET_GROUP_APPLY_TITLE
    self.view.selectMethodText.text = Language.LUA_EQUIP_PRESET_GROUP_APPLY_OCCUPIED_WARNING
    self.view.partOneText.text = Language.LUA_EQUIP_PRESET_GROUP_APPLY_DIRECT
    self.view.partTwoText.text = self.m_canUseSubstitute
        and Language.LUA_EQUIP_PRESET_GROUP_APPLY_SUBSTITUTE
        or Language.LUA_EQUIP_PRESET_GROUP_APPLY_SUBSTITUTE_UNAVAILABLE
end

EquipPresetGroupApplyConfirmPopUpCtrl._RefreshSelection = HL.Method() << function(self)
    local partOneStateCtrl = GetOptionStateCtrl(self.view.partOneNode)
    local partTwoStateCtrl = GetOptionStateCtrl(self.view.partTwoNode)
    if partOneStateCtrl then
        partOneStateCtrl:SetState(self.m_selectedOption == OPTION_DIRECT and "Select" or "Unselect")
    end
    if partTwoStateCtrl then
        partTwoStateCtrl:SetState(not self.m_canUseSubstitute and "Disable"
            or (self.m_selectedOption == OPTION_SUBSTITUTE and "Select" or "Unselect"))
    end

    self.view.partTwoBtn.interactable = self.m_canUseSubstitute

    local hasSelection = self.m_selectedOption ~= OPTION_NONE
    self.view.btnAward.interactable = hasSelection
    self.view.btnAward.text = hasSelection
        and Language.LUA_EQUIP_PRESET_GROUP_APPLY_CONFIRM
        or Language.LUA_EQUIP_PRESET_GROUP_APPLY_NOT_SELECTED
end

EquipPresetGroupApplyConfirmPopUpCtrl._SelectOption = HL.Method(HL.Number) << function(self, option)
    if option == OPTION_SUBSTITUTE and not self.m_canUseSubstitute then
        return
    end
    self.m_selectedOption = option
    self:_RefreshSelection()
end

EquipPresetGroupApplyConfirmPopUpCtrl._OnConfirm = HL.Method() << function(self)
    if self.m_selectedOption == OPTION_NONE then
        return
    end

    self.view.btnAward.interactable = false
    local onConfirm = self.m_onConfirm
    self.m_onConfirm = nil
    local useSubstituteTemplate = self.m_selectedOption == OPTION_SUBSTITUTE
    self:PlayAnimationOutAndClose()
    if onConfirm then
        onConfirm(useSubstituteTemplate)
    end
end

EquipPresetGroupApplyConfirmPopUpCtrl._Close = HL.Method() << function(self)
    self.m_onConfirm = nil
    self:PlayAnimationOutAndClose()
end

HL.Commit(EquipPresetGroupApplyConfirmPopUpCtrl)
