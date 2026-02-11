
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonMoneyExchange
local PHASE_ID = PhaseId.CommonMoneyExchange









CommonMoneyExchangeCtrl = HL.Class('CommonMoneyExchangeCtrl', uiCtrl.UICtrl)







CommonMoneyExchangeCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_WALLET_CHANGED] = 'Refresh',
    [MessageConst.ON_ITEM_COUNT_CHANGED] = 'Refresh',
    [MessageConst.ON_SHOP_MONEY_EXCHANGE_SUCC] = 'Success',
}



CommonMoneyExchangeCtrl.m_arg = HL.Field(HL.Table)









CommonMoneyExchangeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.mask.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)

    self.view.tipsBtn1.onClick:AddListener(function()
        local sourceId = self.m_arg.sourceId
		local args = {
			itemId = sourceId,
			transform = self.view.tipsBtn1.transform,
            onBeforeJump = function()
                PhaseManager:ExitPhaseFast(PHASE_ID)
            end,
		}
		if DeviceInfo.usingController then
			args.posType = UIConst.UI_TIPS_POS_TYPE.RightMid
			args.isSideTips = true
			args.notPenetrate = false
		end
		Notify(MessageConst.SHOW_ITEM_TIPS, args)
    end)

    self.view.tipsBtn2.onClick:AddListener(function()
        local targetId = self.m_arg.targetId
		local args = {
			itemId = targetId,
			transform = DeviceInfo.usingController and self.view.icon2.transform or self.view.tipsBtn2.transform,
            onBeforeJump = function()
                PhaseManager:ExitPhaseFast(PHASE_ID)
            end,
		}
		if DeviceInfo.usingController then
			args.posType = UIConst.UI_TIPS_POS_TYPE.LeftMid
			args.isSideTips = true
			args.notPenetrate = false
		end
		Notify(MessageConst.SHOW_ITEM_TIPS, args)
    end)
    local b, config = CS.Beyond.Gameplay.ShopSystem.GetExchangeData(arg.sourceId, arg.targetId)
    if not b then
        logger.error("can not find money exchange data")
        return
    end
    self.view.confirmButton.onClick:AddListener(function()
        self:_OnConfirmBtnClick()
    end)
    self.view.gotoRechargeButton.onClick:AddListener(function()
        self:_OnGoToRechargeBtnClick()
    end)

    
    self.view.exchangeNodeSelectableNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        local state = isFocused and CS.Beyond.UI.CustomUIStyle.OverrideValidState.ForceNotValid
            or CS.Beyond.UI.CustomUIStyle.OverrideValidState.None
        self.view.numberSelector.view.addButton.transform:Find("KeyHint"):GetComponent("CustomUIStyle").overrideValidState = state
        self.view.numberSelector.view.reduceButton.transform:Find("KeyHint"):GetComponent("CustomUIStyle").overrideValidState = state
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self:Refresh()
end




CommonMoneyExchangeCtrl.Success = HL.Method(HL.Any) << function(self, msg)
    local items = {}
    local reward = unpack(msg)
    local item = {
        id = reward.TargetMoneyId,
        count = reward.GetTargetMoneyNum,
    }
    table.insert(items, item)

    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        title = Language.LUA_BUY_ITEM_SUCC_TITLE,
        icon = "icon_mail_obtain",
        items = items,
    })
    PhaseManager:PopPhase(PHASE_ID)
end




CommonMoneyExchangeCtrl.Refresh = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local sourceId = self.m_arg.sourceId
    local targetId = self.m_arg.targetId
    local item1 = Tables.itemTable[sourceId]
    local item2 = Tables.itemTable[targetId]
    self.view.nameTxt1.text = item1.name
    self.view.nameTxt2.text = item2.name
    self.view.title.text = string.format(Language.LUA_SHOP_MONEY_EXCHANGE_TITLE, item2.name)
    self.view.icon1:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, item1.iconId)
    self.view.icon2:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, item2.iconId)

    local b, config = CS.Beyond.Gameplay.ShopSystem.GetExchangeData(sourceId, targetId)
    if not b then
        logger.error("can not find money exchange data")
        return
    end
    self.view.costNumTxt1.text = math.floor(config.sourceMoneyMinSwap)

    self.view.costNumTxt2.text = math.floor(config.targetMoneyGet * config.sourceMoneyMinSwap)

    self.view.totalNumTxt1.text = Utils.getItemCount(sourceId)
    self.view.totalNumTxt2.text = Utils.getItemCount(targetId)

    self.view.money1.text = string.format("*%s [%s]", config.sourceMoneyCost, item1.name)
    self.view.money2.text = string.format("*%s [%s]", config.targetMoneyGet, item2.name)
    local max = math.max(1, math.floor(Utils.getItemCount(sourceId) / config.sourceMoneyMinSwap))
    local canExchange = math.floor(Utils.getItemCount(sourceId) / config.sourceMoneyCost) > 0
    local canGotoRecharge = not canExchange and sourceId == Tables.globalConst.originiumItemId
    if canGotoRecharge then
        self.view.gotoRechargeButton.gameObject:SetActive(true)
        self.view.confirmButton.gameObject:SetActive(false)
        self.view.confirmTxt.text = string.format(Language.LUA_COMMON_MONEY_EXCHANGE_GOTO_RECHARGE_CONFIRMTXT)
    else
        self.view.gotoRechargeButton.gameObject:SetActive(false)
        self.view.confirmButton.gameObject:SetActive(true)
        self.view.confirmButton.interactable = canExchange
        if not canExchange then
            self.view.confirmTxt.text = string.format(Language.LUA_SHOP_BUY_MONEY_NOT_ENOUGH, item1.name)
        end
    end
    local curNum = self.view.numberSelector.curNumber
    self.view.numberSelector:InitNumberSelector(curNum, 1, max, function(newNum)
        self.view.costNumTxt1.text = math.floor(newNum * config.sourceMoneyMinSwap)
        self.view.costNumTxt2.text = math.floor((newNum * config.sourceMoneyMinSwap / config.sourceMoneyCost) * config.targetMoneyGet)
        self.view.numberSelector.view.numberText.text = math.floor(newNum )
        if canGotoRecharge then
            self.view.confirmTxt.text = string.format(Language.LUA_COMMON_MONEY_EXCHANGE_GOTO_RECHARGE_CONFIRMTXT)
        else
            self.view.confirmTxt.text = string.format(Language.LUA_SHOP_MONEY_EXCHANGE_TIPS, item1.name .. "×" .. math.floor(newNum * config.sourceMoneyMinSwap), item2.name .. "×" ..
                math.floor((newNum * config.sourceMoneyMinSwap / config.sourceMoneyCost) * config.targetMoneyGet))
        end
    end)

end



CommonMoneyExchangeCtrl._OnConfirmBtnClick = HL.Method() << function(self)
    local ret, error = CS.Beyond.Gameplay.ShopSystem.ExchangeMoney(self.m_arg.sourceId, self.m_arg.targetId, math.floor(tonumber(self.view.costNumTxt1.text)))
    logger.info(tostring(ret))
end



CommonMoneyExchangeCtrl._OnGoToRechargeBtnClick = HL.Method() << function(self)
    PhaseManager:ExitPhaseFast(PHASE_ID)
    CashShopUtils.GotoCashShopRechargeTab()
end








CommonMoneyExchangeCtrl.OnClose = HL.Override() << function(self)
    if self.m_arg ~= nil and self.m_arg.onClose ~= nil then
        self.m_arg.onClose()
    end
end




HL.Commit(CommonMoneyExchangeCtrl)
