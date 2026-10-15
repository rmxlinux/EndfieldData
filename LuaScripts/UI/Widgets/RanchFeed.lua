local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

RanchFeed = HL.Class('RanchFeed', UIWidgetBase)
RanchFeed.m_ranchId = HL.Field(HL.String) << ""
RanchFeed.m_feedData = HL.Field(HL.Userdata)
RanchFeed.m_lastAutoFeed = HL.Field(HL.Boolean) << false


RanchFeed._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_ITEM_COUNT_CHANGED, function(evtData)
        if not self.m_feedData then
            return
        end
        local feedId = self.m_feedData.feedId
        if string.isEmpty(feedId) then
            return
        end
        local itemId2DiffCount = unpack(evtData)
        if itemId2DiffCount:ContainsKey(feedId) then
            self:_RefreshAllUIs()
        end
    end)
end

RanchFeed.InitRanchFeed = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()

    self.m_ranchId = arg.ranchId
    local _, ranchData = GameInstance.player.ranchSystem:GetRanchData(self.m_ranchId)
    if ranchData then
        self.m_feedData = ranchData.feed
    end
    self.m_lastAutoFeed = self.m_feedData and self.m_feedData.autoFeed or false

    
    self:RegisterMessage(MessageConst.ON_RANCH_FEED_UPDATED, function()
        local autoFeed = self.m_feedData and self.m_feedData.autoFeed or false
        if autoFeed and not self.m_lastAutoFeed then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_AUTO_FEED_UNLOCK_SUCCESS_TOAST)
        end
        self.m_lastAutoFeed = autoFeed
        self:_RefreshAllUIs()
    end)
    self:RegisterMessage(MessageConst.ON_RANCH_ANIMAL_UPDATED, function()
        self:_RefreshAllUIs()
    end)

    self:_InitUI()
    self:_RefreshAllUIs()
end

RanchFeed._InitUI = HL.Method() << function(self)
    local autoFeedNode = self.view.autoFeed
    local feedItemNode = self.view.feedItem

    
    local moneyId = Tables.ranchConst.unlockAutoMoneyId
    if string.isEmpty(moneyId) then
        local domainId = Utils.getCurDomainId()
        local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
        moneyId = domainCfg.domainGoldItemId
    end
    local itemData = Tables.itemTable:GetValue(moneyId)
    autoFeedNode.iconCurrency:LoadSprite(UIConst.UI_SPRITE_WALLET, itemData.iconId)
    autoFeedNode.autoFeedBtn.onClick:AddListener(function()
        
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_RANCH_AUTO_FEED_UNLOCK_CONFIRM_POP_UP,
            onConfirm = function()
                local isMoneyNotEnough = self:_CheckMoneyIsEnough()
                if isMoneyNotEnough then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_MONEY_NOT_ENOUGH_TOAST)
                else
                    GameInstance.player.ranchSystem:SendRanchAutoFeedUnlock(self.m_ranchId)
                end
        end})
    end)

    
    
    feedItemNode.addFeedBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.FacFertilization, {
            pageType = 2,
            nodeId = self.m_ranchId,
            originalFeedId = self.m_feedData.feedId,
        })
    end)
    feedItemNode.replaceBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.FacFertilization, {
            pageType = 2,
            nodeId = self.m_ranchId,
            originalFeedId = self.m_feedData.feedId,
        })
    end)
end

RanchFeed._RefreshAllUIs = HL.Method() << function(self)
    local autoFeedNode = self.view.autoFeed
    local feedItemNode = self.view.feedItem
    local feedId = self.m_feedData.feedId
    local hasFeed = not string.isEmpty(feedId)
    local remainCount = 0
    
    if GameInstance.player.inventory:IsItemFound(feedId) then
        remainCount = Utils.getItemCount(feedId, true, true)
    end

    
    if hasFeed then
        local _, feedCfg = Tables.innRanchFeedTable:TryGetValue(feedId)
        
        local feedState = remainCount > 0 and "Normal" or "UseUp"
        if self.m_feedData.autoFeed then
            feedState = "Normal"
        end
        feedItemNode.stateController:SetState(feedState)
        feedItemNode.addNumTxt.text = remainCount
        local itemData = Tables.itemTable:GetValue(feedId)
        feedItemNode.iconFeed:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, itemData.iconId)
        
        feedItemNode.consumeNumTxt.text = 1
    else
        feedItemNode.stateController:SetState("Null")
    end

    
    if self.m_feedData.autoFeed then
        autoFeedNode.stateController:SetState("Unlock")
        autoFeedNode.stateController:SetState(hasFeed and (remainCount>0 and "InUse" or "UseUp") or "NoFeed")
    else
        local isMoneyNotEnough = self:_CheckMoneyIsEnough()
        autoFeedNode.stateController:SetState(isMoneyNotEnough and "LockMoneyNotEnough" or "Lock")
        autoFeedNode.expendNumTxt.text = Tables.ranchConst.unlockAutoMoneyCost
    end
end

RanchFeed._CheckMoneyIsEnough = HL.Method().Return(HL.Boolean) << function(self)
    local moneyId = Tables.ranchConst.unlockAutoMoneyId
     if string.isEmpty(moneyId) then
         local domainId = Utils.getCurDomainId()
         local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
         moneyId = domainCfg.domainGoldItemId
     end
     local curMoneyCount = Utils.getItemCount(moneyId)
     local isMoneyNotEnough = curMoneyCount < Tables.ranchConst.unlockAutoMoneyCost
     return isMoneyNotEnough
end

HL.Commit(RanchFeed)
return RanchFeed

