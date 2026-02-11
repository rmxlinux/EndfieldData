local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonPopUp



EToggleStyle = {
    Square = "Square",    
    Circle = "Circle"   
}
























CommonPopUpCtrl = HL.Class('CommonPopUpCtrl', uiCtrl.UICtrl)








CommonPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STAMINA_CHANGED] = "OnStaminaChanged",
    [MessageConst.HIDE_POP_UP] = '_HidePopUp',
}


CommonPopUpCtrl.m_getItemCell = HL.Field(HL.Function)


CommonPopUpCtrl.m_getCharIconCell = HL.Field(HL.Function)


CommonPopUpCtrl.m_timeScaleHandler = HL.Field(HL.Number) << 0






CommonPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.confirmButton.onClick:AddListener(function()
        self:_OnClickConfirm()
    end)
    self.view.cancelButton.onClick:AddListener(function()
        self:_OnClickCancel()
    end)

    self.m_getItemCell = UIUtils.genCachedCellFunction(self.view.itemScrollList)
    self.view.itemScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateItemCell(self.m_getItemCell(obj), LuaIndex(csIndex))
    end)

    self.m_getCharIconCell = UIUtils.genCachedCellFunction(self.view.charIconScrollList)
    self.view.charIconScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCharIconCell(self.m_getCharIconCell(obj), LuaIndex(csIndex))
    end)

    self.view.inputField.characterLimit =  UIConst.INPUT_FIELD_CHARACTER_LIMIT
    self.view.inputFieldMore.characterLimit =  UIConst.INPUT_FIELD_CHARACTER_LIMIT
    self.view.inputField.onValidateCharacterLimit = I18nUtils.GetRealTextByLengthLimit
    self.view.inputFieldMore.onValidateCharacterLimit = I18nUtils.GetRealTextByLengthLimit
    self.view.inputField.onGetTextLength = I18nUtils.GetTextRealLength
    self.view.inputFieldMore.onGetTextLength = I18nUtils.GetTextRealLength

    self.view.itemScrollListSelectableNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)

    UIUtils.initSearchInput(self.view.inputField, {
        onInputFocused = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                panelId = PANEL_ID,
                isGroup = true,
                id = self.view.inputFieldInputBindingGroupMonoTarget.groupId,
                hintPlaceholder = self.view.controllerHintPlaceholder,
                rectTransform = self.view.inputField.transform,
            })
        end,
        onInputEndEdit = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.inputFieldInputBindingGroupMonoTarget.groupId)
            self.view.inputField:DeactivateInputField(true)
        end,
        onInputValueChanged = function(inputText)
            self:_OnInputFieldValueChanged(inputText)
        end
    })

    UIUtils.initSearchInput(self.view.inputFieldMore, {
        onInputFocused = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                panelId = PANEL_ID,
                isGroup = true,
                id = self.view.inputFieldMoreInputBindingGroupMonoTarget.groupId,
                hintPlaceholder = self.view.controllerHintPlaceholder,
                rectTransform = self.view.inputFieldMore.transform,
            })
        end,
        onInputEndEdit = function()
            if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
                return
            end
            Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.inputFieldMoreInputBindingGroupMonoTarget.groupId)
            self.view.inputFieldMore:DeactivateInputField(true)
        end,
        onInputValueChanged = function(inputText)
            self:_OnInputFieldValueChanged(inputText)
        end
    })

end



CommonPopUpCtrl.OnHide = HL.Override() << function(self)
    self:_TryProcessInterruptMessage(false)
    self:_ResumeWorld()
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "commonPopUp", isInMainHud = true })
    self.m_args = nil
end



CommonPopUpCtrl.OnClose = HL.Override() << function(self)
    self:_TryProcessInterruptMessage(false)
    self:_ResumeWorld()
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "commonPopUp", isInMainHud = true })
    self.m_args = nil
end



CommonPopUpCtrl.OnStaminaChanged = HL.Method() << function(self)
    self:_RefreshCostStaminaInfo()
end



CommonPopUpCtrl._FreezeWorld = HL.Method() << function(self)
    self:_ResumeWorld()
    self.m_timeScaleHandler = TimeManagerInst:StartChangeTimeScale(0, CS.Beyond.TimeManager.ChangeTimeScaleReason.UIPanel)

    if self.m_args.pauseGame == true then
        GameWorld.worldInfo:TryPauseSubGame(GEnums.GameTimeFreezeReason.UI)
    end
end



CommonPopUpCtrl._ResumeWorld = HL.Method() << function(self)
    if self.m_timeScaleHandler > 0 then
        TimeManagerInst:StopChangeTimeScale(self.m_timeScaleHandler)
        self.m_timeScaleHandler = 0

        if self.m_args.pauseGame == true then
            GameWorld.worldInfo:TryResumeSubGame(GEnums.GameTimeFreezeReason.UI)
        end
    end
end



CommonPopUpCtrl.ShowPopUp = HL.StaticMethod(HL.Table) << function(args)
    
    local ctrl = CommonPopUpCtrl.AutoOpen(PANEL_ID, nil, false)
    UIManager:SetTopOrder(PANEL_ID)
    ctrl:_ShowPopUp(args)
end



CommonPopUpCtrl.ShowPopUpCS = HL.StaticMethod(HL.Table) << function(args)
    
    local ctrl = CommonPopUpCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:_ShowPopUp({
        content = args[1],
        subContent = args[2],
        onConfirm = args[3],
        onCancel = args[4]
    })
end



CommonPopUpCtrl._HidePopUp = HL.Method() << function(self)
    self:PlayAnimationOutAndHide()
end
















































CommonPopUpCtrl.m_args = HL.Field(HL.Table)



CommonPopUpCtrl._ShowPopUp = HL.Method(HL.Table) << function(self, args)
    Notify(MessageConst.HIDE_ITEM_TIPS)

    self.view.inputField.characterLimit = args.characterLimit or UIConst.INPUT_FIELD_CHARACTER_LIMIT
    self.view.inputFieldMore.characterLimit = args.characterLimit or UIConst.INPUT_FIELD_CHARACTER_LIMIT

    self.m_args = args

    self.view.contentText:SetAndResolveTextStyle(args.content)

    if args.subContent then
        self.view.subText:SetAndResolveTextStyle(args.subContent)
        self.view.subText.gameObject:SetActiveIfNecessary(true)
    else
        self.view.subText.gameObject:SetActiveIfNecessary(false)
    end

    if args.warningContent then
        self.view.warningNode.warningText:SetAndResolveTextStyle(args.warningContent)
        self.view.warningNode.gameObject:SetActive(true)
    else
        self.view.warningNode.gameObject:SetActive(false)
    end


    if args.secondWarningContent then
        self.view.secondWarningNode.warningText:SetAndResolveTextStyle(args.secondWarningContent)
        self.view.secondWarningNode.gameObject:SetActive(true)
    else
        self.view.secondWarningNode.gameObject:SetActive(false)
    end

    self.view.confirmButton.text = args.confirmText or Language.LUA_CONFIRM
    self.view.cancelButton.text = args.cancelText or Language.LUA_CANCEL

    local hideCancel = args.hideCancel == true
    self.view.cancelButton.gameObject:SetActive(not hideCancel)
    self.view.oneBtnBg.gameObject:SetActive(hideCancel)
    self.view.twoBtnBg.gameObject:SetActive(not hideCancel)
    self.view.blurWithUI.gameObject:SetActive(not args.hideBlur)

    if self.m_args.items then
        self.view.itemScrollList.gameObject:SetActive(true)
        self.view.itemScrollList:UpdateCount(#self.m_args.items)
    else
        self.view.itemScrollList.gameObject:SetActive(false)
    end

    if self.m_args.charIcons then
        self.view.charIconScrollList.gameObject:SetActiveIfNecessary(true)
        self.view.charIconScrollList:UpdateCount(#self.m_args.charIcons)
    else
        self.view.charIconScrollList.gameObject:SetActiveIfNecessary(false)
    end

    if self.m_args.input then
        self.view.inputField.text = self.m_args.inputName or ""
        self.view.textInput.gameObject:SetActive(true)
        self.view.inputField.gameObject:SetActive(true)
        self.view.inputField.placeholder.text = self.m_args.inputPlaceholder or ""
        self.view.inputFieldMore.gameObject:SetActive(false)
        self.view.inputHintText.gameObject:SetActive(self.m_args.checkInputValid == true)
        if self.m_args.inputPaste then
            self.view.pasteBtn.gameObject:SetActive(true)
            self.view.pasteBtn.onClick:AddListener(function()
                local targetText = CS.UnityEngine.GUIUtility.systemCopyBuffer
                if self.m_args.pasteFunc then
                   targetText = self.m_args.pasteFunc(targetText)
                end
                self.view.inputField.text = I18nUtils.GetRealTextByLengthLimit(targetText, self.view.inputField.characterLimit)
            end)
        else
            self.view.pasteBtn.gameObject:SetActive(false)
        end
    elseif self.m_args.inputMore then
        self.view.inputFieldMore.text = self.m_args.inputName or ""
        self.view.textInput.gameObject:SetActive(true)
        self.view.inputField.gameObject:SetActive(false)
        self.view.inputFieldMore.placeholder.text = self.m_args.inputPlaceholder or ""
        self.view.inputFieldMore.gameObject:SetActive(true)
        self.view.inputHintText.gameObject:SetActive(self.m_args.checkInputValid == true)
        if self.m_args.inputPaste then
            self.view.pasteBtn.gameObject:SetActive(true)
            self.view.pasteBtn.onClick:AddListener(function()
                if self.m_args.pasteFunc then
                    self.view.inputFieldMore.text = self.m_args.pasteFunc(CS.UnityEngine.GUIUtility.systemCopyBuffer)
                else
                    self.view.inputFieldMore.text = CS.UnityEngine.GUIUtility.systemCopyBuffer
                end
            end)
        else
            self.view.pasteBtn.gameObject:SetActive(false)
        end
    else
        self.view.textInput.gameObject:SetActive(false)
        self.view.pasteBtn.gameObject:SetActive(false)
    end
    self.view.confirmButton.interactable = true

    self.view.equipNode.gameObject:SetActive(self.m_args.equipInstId ~= nil)
    if self.m_args.equipInstId then
        self.view.equipItem:InitEquipItem({
            equipInstId = self.m_args.equipInstId,
            itemInteractable = true,
        })
    end

    self.view.weaponNode.gameObject:SetActive(self.m_args.weaponInstId ~= nil)
    if self.m_args.weaponInstId then
        local weaponInst = CharInfoUtils.getWeaponByInstId(self.m_args.weaponInstId)
        if weaponInst then
            local itemInfo = {
                id = weaponInst.templateId,
                instId = weaponInst.instId,
            }
            self.view.listCellWeapon.item:InitItem(itemInfo, true)
            WeaponUtils.refreshListCellWeaponAddOn(self.view.listCellWeapon, itemInfo)
        end
    end

    if self.m_args.freezeWorld then
        self:_FreezeWorld()
    end

    if self.m_args.toggleInMainHud then
        Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "commonPopUp", isInMainHud = false })
    end

    if self.m_args.toggle ~= nil then
        
        self.view.toggle.toggle.onValueChanged:RemoveAllListeners()
        self.view.toggle.toggle.onValueChanged:AddListener(function(isOn)
            local onValueChanged = self.m_args.toggle.onValueChanged
            if onValueChanged ~= nil then
                onValueChanged(isOn)
            end
        end)
        
        local styleType = self.m_args.toggle.styleType or EToggleStyle.Square
        self:_SetToggleStyle(styleType)
        
        self.view.toggle.gameObject:SetActive(true)
        
        self.view.toggle.toggleText.text = self.m_args.toggle.toggleText
        self.view.toggle.toggle.isOn = self.m_args.toggle.isOn
    else
        
        self.view.toggle.gameObject:SetActive(false)
    end

    local costItems = self.m_args.costItems
    local costNode = self.view.costItemNode
    local costRootNode = self.view.costItemRootNode
    if costItems ~= nil then
        






        local arrowIndex = self.m_args.convertArrowIndex
        costRootNode.gameObject:SetActive(true)
        if not costNode.m_cache then
            costNode.m_cache = UIUtils.genCellCache(costNode.costItemCell)
        end
        costNode.m_cache:Refresh(#costItems, function(cell, index)
            local info = costItems[index]
            cell.item:InitItem(info, function()
                UIUtils.showItemSideTips(cell.item)
            end)
            cell.item:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
            if arrowIndex and index > arrowIndex then
                cell.ownCountTxt.text = UIUtils.getNumString(info.ownCount)
            else
                local isEnough = info.ownCount >= info.count
                cell.item.view.count.text = UIUtils.setCountColor(cell.item.view.count.text, not isEnough)
                cell.ownCountTxt.text = UIUtils.setCountColor(UIUtils.getNumString(info.ownCount), not isEnough)
            end
            cell.transform:SetSiblingIndex(CSIndex(index))
        end)
        if arrowIndex then
            costNode.convertArrow.gameObject:SetActive(true)
            costNode.convertArrow.transform:SetSiblingIndex(arrowIndex)
        else
            costNode.convertArrow.gameObject:SetActive(false)
        end
    else
        costRootNode.gameObject:SetActive(false)
    end

    if self.m_args.staminaInfo then
        self:_RefreshCostStaminaInfo()
        self.view.walletBarPlaceholder:InitWalletBarPlaceholder(UIConst.REGION_MAP_STAMINA_IDS, false, false, true)
    else
        Notify(MessageConst.HIDE_WALLET_BAR, PANEL_ID)
    end
    self.view.staminaNode.gameObject:SetActive(self.m_args.staminaInfo ~= nil)

    if self.m_args.moneyInfo then
        self.view.walletBarPlaceholder:InitWalletBarPlaceholder(
            self.m_args.moneyInfo.moneyIds,
            self.m_args.moneyInfo.useItemIcon,
            self.m_args.moneyInfo.showLimit)
    end

    
    if self.m_args.showGameSettingBtn then
        self.view.setNode.gameObject:SetActive(true)
        self.view.setBtn.onClick:RemoveAllListeners()
        self.view.setBtn.onClick:AddListener(function()
            self:PlayAnimationOutWithCallback(function()
                self:Hide()
                PhaseManager:OpenPhaseFast(PhaseId.GameSetting)
            end)
        end)
    else
        self.view.setNode.gameObject:SetActive(false)
    end

    self:_TryProcessInterruptMessage(true)

    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end





CommonPopUpCtrl._OnUpdateItemCell = HL.Method(HL.Forward("Item"), HL.Number) << function(self, cell, index)
    cell:InitItem(self.m_args.items[index], true)
    cell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
    if DeviceInfo.usingController then
        cell:SetEnableHoverTips(false)
    end
    if self.m_args.noShowItemCount then
        cell.view.countNode.gameObject:SetActiveIfNecessary(false)
    end
    if self.m_args.showItemName then
        cell.view.name.gameObject:SetActiveIfNecessary(true)
    end
    if self.m_args.itemNames and index <= #self.m_args.itemNames then
        cell.view.name.text = self.m_args.itemNames[index]
    end
    if self.m_args.got then
        cell.view.getNode.gameObject:SetActiveIfNecessary(true)
    end
end





CommonPopUpCtrl._OnUpdateCharIconCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    cell.headIcon.spriteName = UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. self.m_args.charIcons[index]
end



CommonPopUpCtrl._OnClickConfirm = HL.Method() << function(self)
    local args = self.m_args
    local text = args.inputMore and self.view.inputFieldMore.text or self.view.inputField.text
    local function onConfirm()
        if args.onConfirm then
            if args.input then
                args.onConfirm(text)
            else
                args.onConfirm(text)
            end
        end
    end
    if self.m_args.closeOnConfirm == false then
        onConfirm()
    else
        self:PlayAnimationOutWithCallback(function()
            self:Hide()
            onConfirm()
        end)
    end
end



CommonPopUpCtrl._OnClickCancel = HL.Method() << function(self)
    local onCancel = self.m_args.onCancel
    self:PlayAnimationOutWithCallback(function()
        self:Hide()
        if onCancel then
            onCancel()
        end
    end)
end




CommonPopUpCtrl._OnInputFieldValueChanged = HL.Method(HL.String) << function(self, inputText)
    if type(self.m_args.checkInputValid) and self.m_args.checkInputValid == true then
        local inputStateName = 'max'
        local isValid = true
        if string.isEmpty(inputText) then
            inputStateName = 'empty'
            isValid = false
        elseif not UIUtils.checkInputValid(self.m_args.inputMore and self.view.inputFieldMore.text or self.view.inputField.text) then
            inputStateName = 'error'
            isValid = false
        end
        self.view.confirmButton.interactable = isValid
        self.view.textInputStateController:SetState(inputStateName)
    elseif type(self.m_args.checkInputValid) == 'function' then
        local isValid,inputStateName = self.m_args.checkInputValid(self.m_args.inputMore and self.view.inputFieldMore.text or self.view.inputField.text)
        self.view.confirmButton.interactable = isValid
        self.view.textInputStateController:SetState(inputStateName)
    end
end



CommonPopUpCtrl._RefreshCostStaminaInfo = HL.Method() << function(self)
    if not self.m_args then
        return
    end

    if not self.m_args.staminaInfo then
        return
    end

    UIUtils.updateStaminaNode(self.view.staminaNode, self.m_args.staminaInfo)
end




CommonPopUpCtrl._SetToggleStyle = HL.Method(HL.String) << function(self, styleType)
    
    if self.view.toggle.square then
        self.view.toggle.square.gameObject:SetActive(false)
    end
    if self.view.toggle.circle then
        self.view.toggle.circle.gameObject:SetActive(false)
    end

    
    if styleType == EToggleStyle.Square and self.view.toggle.square then
        self.view.toggle.square.gameObject:SetActive(true)
        if self.view.toggle.checkmark then
            self.view.toggle.toggle.graphic = self.view.toggle.checkmark
            self.view.toggle.toggle.targetGraphic = self.view.toggle.square
        end
    elseif styleType == EToggleStyle.Circle and self.view.toggle.circle then
        self.view.toggle.circle.gameObject:SetActive(true)
        if self.view.toggle.dotmark then
            self.view.toggle.toggle.graphic = self.view.toggle.dotmark
            self.view.toggle.toggle.targetGraphic = self.view.toggle.circle
        end
    end
end





CommonPopUpCtrl._TryProcessInterruptMessage = HL.Method(HL.Boolean) << function(self, register)
    local interrupt = self.m_args and self.m_args.interrupt
    if not interrupt then
        return
    end

    local groupKey = "CommonPopupInterruptMessage"
    for _, message in ipairs(interrupt.interruptMessage) do
        if register then
            MessageManager:Register(message, function()
                
                if interrupt.onInterrupt then
                    interrupt.onInterrupt()
                end
                self:Hide()
            end, groupKey)
        else
            MessageManager:UnregisterAll(groupKey)
        end
    end
end

HL.Commit(CommonPopUpCtrl)

