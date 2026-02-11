local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')












DomainTopMoneyTitle = HL.Class('DomainTopMoneyTitle', UIWidgetBase)




DomainTopMoneyTitle.m_moneyId = HL.Field(HL.String) << ""


DomainTopMoneyTitle.m_moneyLimit = HL.Field(HL.Number) << -1


DomainTopMoneyTitle.m_moneyClearRule = HL.Field(GEnums.MoneyClearRuleType)


DomainTopMoneyTitle.m_resetMoneyCountDownCompleteFunc = HL.Field(HL.Function)


DomainTopMoneyTitle.m_timeFormatFunc = HL.Field(HL.Function)







DomainTopMoneyTitle._OnFirstTimeInit = HL.Override() << function(self)
    self.m_resetMoneyCountDownCompleteFunc = function()
        self:_OnCountDownComplete()
    end
    self.m_timeFormatFunc = function(leftTime)
        local curMoney = Utils.getItemCount(self.m_moneyId)
        if curMoney < self.m_moneyLimit then
            self.view.timeNode.gameObject:SetActive(false)
        else
            self.view.timeNode.gameObject:SetActive(true)
        end
        
        self.view.resetMoneyTimeTxt.view.textStateCtrl:SetState(leftTime >= Const.SEC_PER_DAY and "EnoughTime" or "insufficientTime")
        return UIUtils.getShortLeftTime(leftTime)
    end
    self.view.contentNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
end






DomainTopMoneyTitle.InitDomainTopMoneyTitle = HL.Method(HL.String, HL.Opt(HL.Number, GEnums.MoneyClearRuleType))
    << function(self, moneyId, moneyLimit, clearRuleType)
    self:_FirstTimeInit()
    
    self.m_moneyId = moneyId
    if moneyLimit ~= nil then
        self.m_moneyLimit = moneyLimit
        self.m_moneyClearRule = clearRuleType or GEnums.MoneyClearRuleType.Weekly
    else
        local hasMoneyCfg, moneyCfg = Tables.moneyConfigTable:TryGetValue(moneyId)
        if hasMoneyCfg then
            self.m_moneyLimit = moneyCfg.MoneyClearLimit
            self.m_moneyClearRule = moneyCfg.clearRule
        end
    end
    
    self.view.moneyWidget:InitMoneyCell(moneyId, true, false, true, self.m_moneyLimit)
    self:_OnCountDownComplete()
end



DomainTopMoneyTitle._GetTargetTime = HL.Method().Return(HL.Number) << function(self)
    local targetTime = 0
    if self.m_moneyClearRule == GEnums.MoneyClearRuleType.Weekly then
        targetTime = Utils.getNextWeeklyServerRefreshTime()
    elseif self.m_moneyClearRule == GEnums.MoneyClearRuleType.Daily then
        targetTime = Utils.getNextCommonServerRefreshTime()
    elseif self.m_moneyClearRule == GEnums.MoneyClearRuleType.Monthly then
        targetTime = Utils.getNextMonthlyServerRefreshTime()
    end
    return targetTime
end





DomainTopMoneyTitle._OnCountDownComplete = HL.Method() << function(self)
    local targetTime = self:_GetTargetTime()
    self.view.resetMoneyTimeTxt:InitCountDownText(
        targetTime,
        self.m_resetMoneyCountDownCompleteFunc,
        self.m_timeFormatFunc
    )
end




DomainTopMoneyTitle.SetTitleText = HL.Method(HL.String) << function(self, titleText)
    self.view.titleTxt.text = titleText
end


HL.Commit(DomainTopMoneyTitle)
return DomainTopMoneyTitle

