local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local GeneralAbilityType = GEnums.GeneralAbilityType
local AbilityState = CS.Beyond.Gameplay.GeneralAbilitySystem.AbilityState

































GeneralAbilityCell = HL.Class('GeneralAbilityCell', UIWidgetBase)

local ITEM_COUNT_UPDATE_INTERVAL = 0.2


GeneralAbilityCell.m_abilityRuntimeData = HL.Field(CS.Beyond.Gameplay.GeneralAbilitySystem.AbilityRuntimeData)


GeneralAbilityCell.m_stateChangedCallback = HL.Field(HL.Function)


GeneralAbilityCell.m_onValidStateChanged = HL.Field(HL.Function)


GeneralAbilityCell.m_cdUpdateThread = HL.Field(HL.Thread)


GeneralAbilityCell.m_needRefreshCD = HL.Field(HL.Boolean) << false


GeneralAbilityCell.m_isLeft = HL.Field(HL.Boolean) << false


GeneralAbilityCell.m_forceCloseNum = HL.Field(HL.Boolean) << false


GeneralAbilityCell.m_itemUpdateThread = HL.Field(HL.Thread)


GeneralAbilityCell.m_itemId = HL.Field(HL.String) << ""


GeneralAbilityCell.m_itemCount = HL.Field(HL.Number) << -1


GeneralAbilityCell.m_customCDFillImage = HL.Field(HL.Userdata)




GeneralAbilityCell._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_GENERAL_ABILITY_STATE_CHANGE, function(args)
        if self.m_abilityRuntimeData == nil then
            return
        end
        local type, fromState, toState = unpack(args)
        if type ~= self.m_abilityRuntimeData.type then
            return
        end
        self:_OnAbilityStateChanged(fromState, toState)
    end)
end



GeneralAbilityCell._OnDestroy = HL.Override() << function(self)
end







GeneralAbilityCell.InitGeneralAbilityCell = HL.Method(HL.Opt(HL.Number, HL.Boolean, HL.Boolean, HL.Function)) << function(self, abilityType, forceCloseNum, isLeft, onValidStateChanged)
    if abilityType == nil then
        self:_OnEnterLockedState()  
        return
    end
    self.m_isLeft = isLeft
    self.m_forceCloseNum = forceCloseNum
    self:_RefreshUseItem()

    self.m_abilityRuntimeData = GameInstance.player.generalAbilitySystem:GetAbilityRuntimeDataByType(abilityType)
    if self.m_abilityRuntimeData == nil then
        return
    end

    self.m_onValidStateChanged = onValidStateChanged or function()end

    self:_InitCellState(abilityType)
    self:_FirstTimeInit()
    self:_OnAbilityStateChanged(AbilityState.None, self.m_abilityRuntimeData.state)  
end




GeneralAbilityCell._InitCellState = HL.Method(HL.Number) << function(self, abilityType)
    self.m_needRefreshCD = self.view.config.NEED_REFRESH_CD
    self.view.cdNode.gameObject:SetActive(false)

    local success, tableData = Tables.generalAbilityTable:TryGetValue(abilityType)
    if success then
        self.view.icon:LoadSprite(UIConst.UI_SPRITE_GENERAL_ABILITY, tableData.iconId)

        self.m_itemId = tableData.useItem
        local needRefreshItemCount = self.view.config.NEED_SHOW_ITEM_COUNT and not string.isEmpty(self.m_itemId)
        self.view.itemCountNode.gameObject:SetActive(needRefreshItemCount)
        if needRefreshItemCount then
            self:_InitItemCountUpdateThread()
        end
    end
end





GeneralAbilityCell._OnAbilityStateChanged = HL.Method(AbilityState, AbilityState) << function(self, fromState, toState)
    
    if fromState ~= nil then
        if fromState == AbilityState.Locked then
            self:_OnLeaveLockedState()
        elseif fromState == AbilityState.Idle then
            self:_OnLeaveIdleState()
        elseif fromState == AbilityState.InCD then
            self:_OnLeaveInCDState()
        elseif fromState == AbilityState.ForbiddenSelect then
            self:_OnLeaveForbiddenSelectState()
        elseif fromState == AbilityState.ForbiddenUse then
            self:_OnLeaveForbiddenUseState()
        end
    end

    if toState ~= nil then
        if toState == AbilityState.Locked then
            self:_OnEnterLockedState()
        elseif toState == AbilityState.Idle then
            self:_OnEnterIdleState()
            self:_SwitchCellValidState(true, fromState, toState)
        elseif toState == AbilityState.InCD then
            self:_OnEnterInCDState()
            self:_SwitchCellValidState(false, fromState, toState)
        elseif toState == AbilityState.ForbiddenSelect then
            self:_OnEnterForbiddenSelectState()
            self:_SwitchCellValidState(false, fromState, toState)
        elseif toState == AbilityState.ForbiddenUse then
            self:_OnEnterForbiddenUseState()
            self:_SwitchCellValidState(false, fromState, toState)
        end
    end
end






GeneralAbilityCell._SwitchCellValidState = HL.Method(HL.Boolean, AbilityState, AbilityState) << function(
    self, isValid, fromState, toState)
    if self.view.config.NEED_REFRESH_VALID_STATE then
        self.view.normalNodeCanvasGroup.alpha = isValid and 1 or 0.3
    end
    self:_TriggerCellValidStateChanged(isValid, fromState, toState)
end






GeneralAbilityCell._TriggerCellValidStateChanged = HL.Method(HL.Boolean, AbilityState, AbilityState) << function(
    self, isValid, fromState, toState)
    if self.m_onValidStateChanged ~= nil then
        self.m_onValidStateChanged(isValid, fromState, toState)
    end
end





GeneralAbilityCell._OnEnterIdleState = HL.Method() << function(self)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(false)
    self.view.normalNode.gameObject:SetActiveIfNecessary(true)

    local isTempAbility = GameInstance.player.generalAbilitySystem:IsTempAbility(self.m_abilityRuntimeData.type)
    local abilityColor = isTempAbility and self.view.config.TEMP_NORMAL_COLOR or self.view.config.NORMAL_COLOR
    self.view.normalNodeCanvasGroup.color = abilityColor
end



GeneralAbilityCell._OnLeaveIdleState = HL.Method() << function(self)
end








GeneralAbilityCell._OnEnterForbiddenSelectState = HL.Method() << function(self)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(true)
    self.view.normalNode.gameObject:SetActiveIfNecessary(true)
end



GeneralAbilityCell._OnLeaveForbiddenSelectState = HL.Method() << function(self)
end




GeneralAbilityCell._OnEnterForbiddenUseState = HL.Method() << function(self)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(false)
    self.view.normalNode.gameObject:SetActiveIfNecessary(true)

    
    local isTempAbility = GameInstance.player.generalAbilitySystem:IsTempAbility(self.m_abilityRuntimeData.type)
    local abilityColor = isTempAbility and self.view.config.TEMP_INVALID_COLOR or self.view.config.NORMAL_COLOR
    self.view.normalNodeCanvasGroup.color = abilityColor
end



GeneralAbilityCell._OnLeaveForbiddenUseState = HL.Method() << function(self)
end








GeneralAbilityCell._OnEnterInCDState = HL.Method() << function(self)
    self.view.cdNode.gameObject:SetActive(self.m_needRefreshCD)
    if self.m_customCDFillImage ~= nil then
        self.m_customCDFillImage.gameObject:SetActive(self.m_needRefreshCD)
    end

    self:_RefreshCDTime()
    self.m_cdUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_RefreshCDTime()
        end
    end)
end



GeneralAbilityCell._OnLeaveInCDState = HL.Method() << function(self)
    self.view.cdNode.gameObject:SetActive(false)
    if self.m_customCDFillImage ~= nil then
        self.m_customCDFillImage.gameObject:SetActive(false)
    end

    if self.m_needRefreshCD then
        self.view.cdText.text = string.format("%.1f", self.m_abilityRuntimeData.cd)
    end

    self.m_cdUpdateThread = self:_ClearCoroutine(self.m_cdUpdateThread)
end



GeneralAbilityCell._RefreshCDTime = HL.Method() << function(self)
    local cd, cdTime = self.m_abilityRuntimeData.cd, self.m_abilityRuntimeData.cdTime
    if cd == 0 then
        return
    end

    local fillAmount = (cd - cdTime) / cd
    if self.m_customCDFillImage ~= nil then
        self.m_customCDFillImage.fillAmount = fillAmount
    end

    if self.m_needRefreshCD then
        self.view.cdText.text = string.format("%.1f", cd - cdTime)
    end
end








GeneralAbilityCell._OnEnterLockedState = HL.Method() << function(self)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(false)
    self.view.normalNode.gameObject:SetActiveIfNecessary(false)
end



GeneralAbilityCell._OnLeaveLockedState = HL.Method() << function(self)
    self.view.lockedNode.gameObject:SetActiveIfNecessary(false)
end








GeneralAbilityCell._InitItemCountUpdateThread = HL.Method() << function(self)
    if self.m_itemUpdateThread ~= -1 then
        self.m_itemUpdateThread = self:_ClearCoroutine(self.m_itemUpdateThread)
    end
    self:_RefreshUseItem()
    self.m_itemUpdateThread = self:_StartCoroutine(function()
        while true do
            if self.view.gameObject.activeInHierarchy and self.view.gameObject.activeSelf then
                self:_RefreshUseItem()
            end

            coroutine.wait(ITEM_COUNT_UPDATE_INTERVAL)
        end
    end)
end



GeneralAbilityCell._RefreshUseItem = HL.Method() << function(self)
    if self.view.config.NEED_SHOW_ITEM_COUNT == false then
        self.view.itemCount.gameObject:SetActive(false)
        return
    end

    if string.isEmpty(self.m_itemId) then
        self.view.itemCount.gameObject:SetActive(false)
        return
    end

    if self.m_forceCloseNum then
        self.view.itemCount.gameObject:SetActive(false)
        return
    end

    self.view.itemCount.gameObject:SetActive(true)

    local itemCount = GameInstance.player.inventory:GetItemCountInBag(Utils.getCurrentScope(), self.m_itemId)
    if itemCount == self.m_itemCount then
        return
    end

    self.m_itemCount = itemCount
    self.view.itemCount.text = string.format("%d", itemCount)

    self.view.itemCount.color = itemCount > 0 and self.view.config.NORMAL_COLOR or self.view.config.ITEM_LACK_COUNT_COLOR
end







GeneralAbilityCell.SetCustomCDFillImage = HL.Method(HL.Userdata) << function(self, image)
    self.m_customCDFillImage = image
end



HL.Commit(GeneralAbilityCell)
return GeneralAbilityCell

