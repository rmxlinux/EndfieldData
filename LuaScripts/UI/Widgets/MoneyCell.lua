local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local AutoTriggerOnClick = CS.Beyond.Input.ActionOnSetNaviTarget.AutoTriggerOnClick
local MoneyCellConfig = require_ex('UI/Panels/WalletBar/MoneyCellConfig')

MoneyCell = HL.Class('MoneyCell', UIWidgetBase)

local TIPS_SHOW_PADDING_TOP = 100

MoneyCell.m_itemId = HL.Field(HL.String) << ""

MoneyCell.m_itemInstId = HL.Field(HL.Number) << 0

MoneyCell.m_isMoneyType = HL.Field(HL.Boolean) << false

MoneyCell.m_coroutine = HL.Field(HL.Thread)

MoneyCell.m_controllerBindingId = HL.Field(HL.Number) << -1

MoneyCell.m_useItemIcon = HL.Field(HL.Boolean) << false

MoneyCell.m_needNumberLimit = HL.Field(HL.Boolean) << true

MoneyCell.m_customLimitNumber = HL.Field(HL.Number) << -1

MoneyCell.m_rawPreferredWidth = HL.Field(HL.Number) << -1

MoneyCell.m_cellPreferredWidth = HL.Field(HL.Number) << -1

MoneyCell.m_isItemTipsShowing = HL.Field(HL.Boolean) << false

MoneyCell.isSelected = HL.Field(HL.Boolean) << false

MoneyCell.m_cellConfig = HL.Field(HL.Table)

MoneyCell.m_context = HL.Field(HL.Table)

local HOT_AREA_ADJUST_POSITION_X = 10

MoneyCell._OnFirstTimeInit = HL.Override() << function(self)
    local autoCloseArea = self.view.autoCloseArea
    autoCloseArea.tmpSafeArea = self.view.tip.transform
    autoCloseArea.onTriggerAutoClose:RemoveAllListeners()
    autoCloseArea.onTriggerAutoClose:AddListener(function()
        local active = self.view.tip.gameObject.activeSelf
        if active then
            self.view.tip.gameObject:SetActive(false)
        end
    end)

    self.view.button.onClick:AddListener(function()
        self:_OnClickItem()
    end)
    self.view.addBtn.onClick:AddListener(function()
        self:_OnClickAddItem()
    end)
    self.view.button.onIsNaviTargetChanged = function(isTarget, isGroupChanged, isOnNaviTargetEnabledAgain)
        local actionId = (isTarget and DeviceInfo.usingController) and "money_cell_add" or ""
        self.view.addBtn.onClick:ChangeBindingPlayerAction(actionId)
    end

    self.m_rawPreferredWidth = self.view.contentNode.preferredWidth
end

MoneyCell._OnDestroy = HL.Override() << function(self)
    self:_StopTick()
end

MoneyCell._OnEnable = HL.Override() << function(self)
    local cfg = self.m_cellConfig
    if cfg and cfg.needTick then
        self:_StartTick()
    end
end

MoneyCell._OnDisable = HL.Override() << function(self)
    self:_StopTick()
    local cfg = self.m_cellConfig
    if cfg and cfg.onDisable then
        cfg.onDisable(self)
    end
end

MoneyCell.InitMoneyCell = HL.Method(HL.String, HL.Opt(HL.Boolean, HL.Boolean, HL.Boolean, HL.Number, HL.Number, HL.Table))
        << function(self, itemId, useAction, useItemIcon, needNumberLimit, limitNumber, cellPreferredWidth, customConfig)
    self.m_itemId = itemId
    self.m_cellConfig = customConfig or MoneyCellConfig.get(itemId)
    self.m_context = nil

    self:_FirstTimeInit()
    self:_RegisterMessages()

    local cfg = self.m_cellConfig
    if cfg and cfg.iconAtlas then
        self.m_isMoneyType = false
    else
        local itemData = Tables.itemTable:GetValue(self.m_itemId)
        self.m_isMoneyType = GameInstance.player.inventory:IsMoneyType(itemData.type)
    end

    self.m_useItemIcon = useItemIcon == true
    self.m_needNumberLimit = needNumberLimit == true
    self.m_customLimitNumber = limitNumber or -1
    self.m_cellPreferredWidth = cellPreferredWidth or self.m_rawPreferredWidth
    self:_RefreshUI()

    if cfg and cfg.needTick then
        self:_StartTick()
    end

    if cfg and cfg.onInit then
        cfg.onInit(self)
    end

    self:_ClearControllerBinding()
    if useAction then
        self.m_controllerBindingId = InputManagerInst:CreateBindingByActionId("inv_money_add", function()
            self:_OnClickAddItem()
        end, self.view.addBtn.groupId)
        self.view.keyHint.gameObject:SetActiveIfNecessary(useAction)
    else
        self.view.keyHint.gameObject:SetActiveIfNecessary(false)
    end
end

MoneyCell.SetContext = HL.Method(HL.Opt(HL.Table)) << function(self, context)
    self.m_context = context
end

MoneyCell.SetItemInstId = HL.Method(HL.Number) << function(self, instId)
    self.m_itemInstId = instId
end

MoneyCell.SetAddBtnKeyHintText = HL.Method(HL.String) << function(self, keyHintText)
    self.view.addBtn.customBindingViewLabelText = keyHintText
end

MoneyCell._RegisterMessages = HL.Method() << function(self)
    MessageManager:UnregisterAll(self)

    local cfg = self.m_cellConfig
    if cfg and cfg.refreshMessages then
        for msgId, handler in pairs(cfg.refreshMessages) do
            self:RegisterMessage(msgId, function(evtData)
                handler(self, evtData)
            end)
        end
        return
    end

    if cfg and cfg.skipDefaultRefresh then
        return
    end

    self:RegisterMessage(MessageConst.ON_WALLET_CHANGED, function(evtData)
        local id, amount, opAmount = unpack(evtData)
        if id == self.m_itemId then
            self:_UpdateCount()
        end
    end)

    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function(evtData)
        if not self.m_isMoneyType then
            if string.isEmpty(self.m_itemId) then
                return
            end
            local itemId2DiffCount = unpack(evtData)
            if itemId2DiffCount:ContainsKey(self.m_itemId) then
                self:_UpdateCount()
            end
        end
    end)
end

MoneyCell._RefreshUI = HL.Method() << function(self)
    local cfg = self.m_cellConfig
    if cfg and cfg.iconAtlas then
        self.view.icon:LoadSprite(cfg.iconAtlas, cfg.iconId)
    else
        local itemData = Tables.itemTable:GetValue(self.m_itemId)
        self.view.icon:LoadSprite(self.m_useItemIcon and UIConst.UI_SPRITE_ITEM or UIConst.UI_SPRITE_WALLET, itemData.iconId)
    end

    local showAddBtn = self:_ShouldShowAddButton()
    self.view.addBtn.gameObject:SetActive(showAddBtn)
    if showAddBtn then
        self:_StartCoroutine(function()
            coroutine.step()
            coroutine.step()
            self.view.hotArea.sizeDelta = Vector2( -(self.view.addBtn.transform.rect.width + HOT_AREA_ADJUST_POSITION_X), self.view.hotArea.sizeDelta.y)
        end)
    end
    if self.m_cellPreferredWidth > 0 then
        self.view.contentNode.preferredWidth = self.m_cellPreferredWidth
    end
    self:_UpdateCount()
end

MoneyCell._UpdateCount = HL.Method() << function(self)
    local cfg = self.m_cellConfig
    if cfg and cfg.getDisplayText then
        local cur, max = cfg.getDisplayText()
        if max ~= nil then
            self.view.text.text = string.format(Language.LUA_FORWARD_SLASH, cur, max)
        else
            self.view.text.text = tostring(cur)
        end
        return
    end

    if self.m_needNumberLimit then
        local numberLimit = nil
        if self.m_customLimitNumber > 0 then
            numberLimit = self.m_customLimitNumber
        else
            local succ, moneyCfg = Tables.MoneyConfigTable:TryGetValue(self.m_itemId)
            if succ then
                numberLimit = moneyCfg.MoneyClearLimit
            end
        end
        if numberLimit ~= nil then
            local itemCountStr = UIUtils.getNumString(GameInstance.player.inventory:GetItemCount(Utils.getCurrentScope(), Utils.getCurrentChapterId(), self.m_itemId))
            local numberLimitStr = UIUtils.getNumString(numberLimit)
            self.view.text.text = string.format("%s<color=#A7A7A7>/%s</color>", itemCountStr, numberLimitStr)
        else
            self.view.text.text = tonumber(GameInstance.player.inventory:GetItemCount(Utils.getCurrentScope(), Utils.getCurrentChapterId(), self.m_itemId))
        end
    else
        self.view.text.text = tonumber(GameInstance.player.inventory:GetItemCount(Utils.getCurrentScope(), Utils.getCurrentChapterId(), self.m_itemId))
    end
end

MoneyCell._ShouldShowAddButton = HL.Method().Return(HL.Boolean) << function(self)
    local cfg = self.m_cellConfig
    if cfg then
        local show = cfg.showAddBtn
        if type(show) == "function" then
            return show()
        end
        return show == true
    end
    return false
end

MoneyCell.SetSelected = HL.Method(HL.Boolean) << function(self, selected)
    self.isSelected = selected
    if NotNull(self.view.selected) then
        self.view.selected.gameObject:SetActive(selected)
    end
end

MoneyCell._OnClickItem = HL.Method() << function(self)
    local cfg = self.m_cellConfig
    if cfg and cfg.onClickItem then
        cfg.onClickItem(self)
        return
    end

    if not DeviceInfo.usingController and self.m_isItemTipsShowing then
        Notify(MessageConst.HIDE_ITEM_TIPS)
        return
    end
    self:SetSelected(true)
    self:_OnClickItem2ShowItemTips()
end

MoneyCell._OnClickItem2ShowItemTips = HL.Method() << function(self)
    if UIManager:IsShow(PanelId.RewardsPopUpForSystem) then
        return
    end
    if DeviceInfo.usingController and self.m_isItemTipsShowing then
        return
    end
    self.m_isItemTipsShowing = true
    local usingSideTips = DeviceInfo.usingController and self.view.button.actionOnSetNaviTarget == AutoTriggerOnClick
    Notify(MessageConst.SHOW_ITEM_TIPS, {
        transform = self.view.transform,
        safeArea = self.view.transform,
        posType = UIConst.UI_TIPS_POS_TYPE.MidBottom,
        itemId = self.m_itemId,
        instId = self.m_itemInstId,
        isSideTips = usingSideTips,
        keyHintGroupIds = { self.view.inputBindingGroupMonoTarget.groupId },
        padding = { top = TIPS_SHOW_PADDING_TOP },
        onClose = function()
            self.m_isItemTipsShowing = false
            self:SetSelected(false)
        end
    })
end

MoneyCell._OnClickAddItem = HL.Method() << function(self)
    local cfg = self.m_cellConfig
    if cfg and cfg.onClickAddItem then
        cfg.onClickAddItem(self)
        Notify(MessageConst.HIDE_ITEM_TIPS)
        return
    end
    Notify(MessageConst.HIDE_ITEM_TIPS)
end

MoneyCell._StartTick = HL.Method() << function(self)
    if self.m_coroutine then
        self.m_coroutine = self:_ClearCoroutine(self.m_coroutine)
    end
    self:_UpdateCount()
    local cfg = self.m_cellConfig
    local interval = (cfg and cfg.tickInterval) or UIConst.COMMON_UI_TIME_UPDATE_INTERVAL
    self.m_coroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(interval)
            self:_UpdateCount()
        end
    end)
end

MoneyCell._StopTick = HL.Method() << function(self)
    if self.m_coroutine then
        self.m_coroutine = self:_ClearCoroutine(self.m_coroutine)
    end
end

MoneyCell._ClearControllerBinding = HL.Method() << function(self)
    if self.m_controllerBindingId == -1 then
        return
    end

    InputManagerInst:DeleteBinding(self.m_controllerBindingId)
    self.m_controllerBindingId = -1
end

HL.Commit(MoneyCell)
return MoneyCell
