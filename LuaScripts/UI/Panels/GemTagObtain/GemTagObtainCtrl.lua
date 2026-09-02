local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PhaseForesightCharGrowth = require_ex('Phase/ForesightCharGrowth/PhaseForesightCharGrowth').PhaseForesightCharGrowth
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget
local UIStateControllerType = typeof(CS.Beyond.UI.UIState.UIStateController)

local NO_REMIND_CATEGORY = "ForesightCharGrowth"


local DEFAULT_TEXT_COPY = {
    titleLangKey = "LUA_GEM_TAG_OBTAIN_TITLE",
    selectMethodLangKey = "LUA_GEM_TAG_OBTAIN_SELECT_METHOD",
    optionOneLangKey = "LUA_GEM_TAG_OBTAIN_OPTION_ADD_WISHLIST_AND_GO",
    optionTwoLangKey = "LUA_GEM_TAG_OBTAIN_OPTION_GO_ONLY",
    toggleLangKey = "LUA_GEM_TAG_OBTAIN_NO_REMIND_TOGGLE",
}

local function SetUiText(txt, value)
    if not txt then
        return
    end
    value = value or ""
    if txt.SetText then
        txt:SetText(value)
    elseif txt.text ~= nil then
        txt.text = value
    end
end

local function ResolveLangText(langKey)
    if string.isEmpty(langKey) then
        return ""
    end
    return Language[langKey] or ""
end

local function BuildTextCopy(argCopy)
    local copy = {}
    for fieldName, defaultLangKey in pairs(DEFAULT_TEXT_COPY) do
        local langKey = argCopy and argCopy[fieldName]
        if string.isEmpty(langKey) then
            langKey = defaultLangKey
        end
        copy[fieldName] = langKey
    end
    return copy
end



local function GetOptionStateCtrl(optionNode)
    if not optionNode or not optionNode.gameObject then
        return nil
    end
    return optionNode.gameObject:GetComponent(UIStateControllerType)
end

GemTagObtainCtrl = HL.Class('GemTagObtainCtrl', uiCtrl.UICtrl)

GemTagObtainCtrl.m_weaponId = HL.Field(HL.String) << ""
GemTagObtainCtrl.m_addToWishlist = HL.Field(HL.Boolean) << true
GemTagObtainCtrl.m_noRemindChecked = HL.Field(HL.Boolean) << false
GemTagObtainCtrl.m_pendingWishlistAdd = HL.Field(HL.Boolean) << false
GemTagObtainCtrl.m_pendingJumpAfterWishlistAdd = HL.Field(HL.Boolean) << false
GemTagObtainCtrl.m_textCopy = HL.Field(HL.Table)
GemTagObtainCtrl.m_foresightGoToLog = HL.Field(HL.Table)

GemTagObtainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WEAPON_GEM_WISH_LIST_CHANGED] = 'OnWeaponGemWishListChanged',
}

GemTagObtainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_weaponId = arg and arg.weaponId or ""
    if arg and arg.addToWishlist ~= nil then
        self.m_addToWishlist = arg.addToWishlist
    end
    if arg and arg.noRemindChecked ~= nil then
        self.m_noRemindChecked = arg.noRemindChecked
    end
    self.m_textCopy = BuildTextCopy(arg and arg.textCopy)
    self.m_foresightGoToLog = arg and arg.foresightGoToLog or nil
    self.m_pendingWishlistAdd = false
    self.m_pendingJumpAfterWishlistAdd = false

    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.btnCancel.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.btnAward.onClick:AddListener(function()
        self:_OnConfirm()
    end)
    self.view.partOneBtn.onClick:AddListener(function()
        self:_SelectAddToWishlist(true)
    end)
    self.view.partTwoBtn.onClick:AddListener(function()
        self:_SelectAddToWishlist(false)
    end)

    self:BindInputPlayerAction("common_cancel", function()
        self:_Close()
    end)
    self:_InitOptionControllerNavi()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:_ValidateOptionStateCtrl()
end

GemTagObtainCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshCopyText()
    self:_SyncNoRemindToggle()
    self:_RefreshSelection()
end

GemTagObtainCtrl.OnAnimationInFinished = HL.Override() << function(self)
    self:_InitController()
end

GemTagObtainCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        weaponId = self.m_weaponId,
        addToWishlist = self.m_addToWishlist,
        noRemindChecked = self.m_noRemindChecked,
        textCopy = self.m_textCopy,
        foresightGoToLog = self.m_foresightGoToLog,
    }
end

GemTagObtainCtrl.OnWeaponGemWishListChanged = HL.Method() << function(self)
    if not self.m_pendingWishlistAdd then
        return
    end
    self.m_pendingWishlistAdd = false
    if GameInstance.player.inventory.weaponGemWishList:Contains(self.m_weaponId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GEM_TAG_OBTAIN_ADD_SUCCESS)
        if self.m_pendingJumpAfterWishlistAdd then
            self.m_pendingJumpAfterWishlistAdd = false
            self:_JumpToDungeon()
        end
        return
    end
    self.m_pendingJumpAfterWishlistAdd = false
    self:_ShowWishlistFullConfirm()
end



GemTagObtainCtrl._RefreshCopyText = HL.Method() << function(self)
    local textCopy = self.m_textCopy or DEFAULT_TEXT_COPY
    SetUiText(self.view.titleText, ResolveLangText(textCopy.titleLangKey))
    SetUiText(self.view.selectMethodText, ResolveLangText(textCopy.selectMethodLangKey))
    SetUiText(self.view.partOneText, ResolveLangText(textCopy.optionOneLangKey))
    SetUiText(self.view.partTwoText, ResolveLangText(textCopy.optionTwoLangKey))
    SetUiText(self.view.toggleText, ResolveLangText(textCopy.toggleLangKey))
end

GemTagObtainCtrl._Close = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end

GemTagObtainCtrl._OnConfirm = HL.Method() << function(self)
    self:_ApplyNoRemindFlagIfNeeded()
    if not self.m_addToWishlist or GameInstance.player.inventory.weaponGemWishList:Contains(self.m_weaponId) then
        self:_JumpToDungeon()
        return
    end
    if PhaseForesightCharGrowth.IsWeaponGemWishListFull() then
        self:_ShowWishlistFullConfirm()
        return
    end
    self.m_pendingJumpAfterWishlistAdd = true
    self:_SendAddToWishlistRequest()
end

GemTagObtainCtrl._SelectAddToWishlist = HL.Method(HL.Boolean) << function(self, addToWishlist)
    if self.m_addToWishlist == addToWishlist then
        return
    end
    self.m_addToWishlist = addToWishlist
    self:_RefreshSelection()
end

GemTagObtainCtrl._ValidateOptionStateCtrl = HL.Method() << function(self)
    if not GetOptionStateCtrl(self.view.partOneNode)
        or not GetOptionStateCtrl(self.view.partTwoNode) then
        logger.error(
            "GemTagObtainCtrl: partOneNode/partTwoNode missing UIStateController, check GemTagObtainPanel prefab")
    end
end

GemTagObtainCtrl._RefreshSelection = HL.Method() << function(self)
    local partOneStateCtrl = GetOptionStateCtrl(self.view.partOneNode)
    local partTwoStateCtrl = GetOptionStateCtrl(self.view.partTwoNode)
    if not partOneStateCtrl or not partTwoStateCtrl then
        return
    end
    partOneStateCtrl:SetState(self.m_addToWishlist and "Select" or "Unselect")
    partTwoStateCtrl:SetState(self.m_addToWishlist and "Unselect" or "Select")
end

GemTagObtainCtrl._SyncNoRemindToggle = HL.Method() << function(self)
    local toggle = self.view.toggle
    toggle.onValueChanged:RemoveAllListeners()
    toggle.isOn = self.m_noRemindChecked
    toggle.onValueChanged:AddListener(function(isOn)
        self.m_noRemindChecked = isOn
    end)
end

GemTagObtainCtrl._InitOptionControllerNavi = HL.Method() << function(self)
    self.view.partOneBtn:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
    self.view.partTwoBtn:ChangeActionOnSetNaviTarget(ActionOnSetNaviTarget.None)
    self.view.partOneBtn.onIsNaviTargetChanged = function(active)
        if active then
            self:_SelectAddToWishlist(true)
        end
    end
    self.view.partTwoBtn.onIsNaviTargetChanged = function(active)
        if active then
            self:_SelectAddToWishlist(false)
        end
    end
end

GemTagObtainCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    local target = self.m_addToWishlist and self.view.partOneBtn or self.view.partTwoBtn
    self:SetNaviTarget(target)
end

GemTagObtainCtrl._SendAddToWishlistRequest = HL.Method() << function(self)
    PhaseForesightCharGrowth.RequestAddWeaponToGemWishList(self.m_weaponId)
    self.m_pendingWishlistAdd = true
end

GemTagObtainCtrl._ShowWishlistFullConfirm = HL.Method() << function(self)
    self.m_pendingWishlistAdd = false
    self.m_pendingJumpAfterWishlistAdd = false
    local log = self.m_foresightGoToLog
    if log and log.charId then
        EventLogManagerInst:GameEvent_CultiOverviewGoTo(
            log.charId, PhaseManager:GetPhaseName(PhaseId.Map), log.itemIdList or "",
            log.charStatus, log.sourceBlock, true,"")
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_GEM_TAG_OBTAIN_WISHLIST_FULL_CONFIRM,
        onConfirm = function()
            self:_Close()
            PhaseManager:OpenPhase(PhaseId.GemWishlist)
        end,
        onCancel = function()
            self:_Close()
        end,
    })
end

GemTagObtainCtrl._JumpToDungeon = HL.Method().Return(HL.Boolean) << function(self)
    local log = self.m_foresightGoToLog
    if log and log.charId then
        EventLogManagerInst:GameEvent_CultiOverviewGoTo(
            log.charId, PhaseManager:GetPhaseName(PhaseId.Map), log.itemIdList or "",
            log.charStatus, log.sourceBlock, false,"")
    end
    self:_Close()
    return PhaseForesightCharGrowth.Get():JumpToBestGemEnergyPoint(self.m_weaponId)
end



GemTagObtainCtrl._ApplyNoRemindFlagIfNeeded = HL.Method() << function(self)
    if self.m_noRemindChecked then
        local choice = 2
        if self.m_addToWishlist then
            choice = 1
        end
        ClientDataManagerInst:SetInt(
            "WeaponAddWishChoice", choice, false,
            NO_REMIND_CATEGORY, EClientDataTimeValidType.CurrentDayUntil4AM)
    end
end


HL.Commit(GemTagObtainCtrl)
