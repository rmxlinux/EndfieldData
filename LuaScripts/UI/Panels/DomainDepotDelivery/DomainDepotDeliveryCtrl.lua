local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainDepotDelivery
local REFRESH_INTERVAL = 5

DomainDepotDeliveryCtrl = HL.Class('DomainDepotDeliveryCtrl', uiCtrl.UICtrl)

DomainDepotDeliveryCtrl.m_getCellFunc = HL.Field(HL.Function)

DomainDepotDeliveryCtrl.m_isSyncingPeerInfo = HL.Field(HL.Boolean) << false

DomainDepotDeliveryCtrl.m_filterDomainIdList = HL.Field(HL.String) << ""

DomainDepotDeliveryCtrl.m_domainDropDownInfo = HL.Field(HL.Table)

DomainDepotDeliveryCtrl.m_curDomainIndex = HL.Field(HL.Number) << 1

DomainDepotDeliveryCtrl.m_resumeState = HL.Field(HL.Table)

DomainDepotDeliveryCtrl.m_nextRefreshTimestamp = HL.Field(HL.Number) << 0





DomainDepotDeliveryCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DOMAIN_DEPOT_DELIVERY_SYNC] = 'OnSync',
    [MessageConst.ON_DOMAIN_DEPOT_DAILY_REFRESHED] = '_RefreshDailyCount',
}


DomainDepotDeliveryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local inited = false
    self.m_resumeState = arg and arg.resumeState or nil
    
    if not self.m_resumeState then
        GameInstance.player.domainDepotSystem.remoteDelegateDeliverList:Clear()
    end
    self.view.refreshBtn.onClick:RemoveAllListeners()
    self.view.refreshBtn.onClick:AddListener(function()
        self:_OnRefreshBtnClick()
    end)

    
    if self.m_resumeState and self.m_resumeState.filterDomainId ~= nil then
        self.m_filterDomainIdList = self.m_resumeState.filterDomainId
    end



    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:RemoveAllListeners()
    self.view.scrollList.onUpdateCell:AddListener(function(object, index)
        local cell = self.m_getCellFunc(object)
        cell:InitDomainDepotDeliveryCell(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList[index])
    end)

    
    self:_RefreshDailyCount()
    self.view.times2Txt.text = Tables.domainDepotConst.dailyTakeDelegateCount

    self.view.tipsButton.onClick:RemoveAllListeners()
    self.view.tipsButton.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "domain_depot_delivery")
    end)

    self.m_domainDropDownInfo = {
        [1] = {
            domainId = "",
            name = Language.LUA_DOMAIN_DEPOT_DELIVERY_FILTER_ALL,
            icon = "domain_all",
        }
    }
    local curDomainId = Utils.getCurDomainId()
    for domainId, domainData in pairs(Tables.domainDataTable) do
        if GameInstance.player.domainDevelopmentSystem.domainDevDataDic:ContainsKey(domainId) and DomainDepotUtils.IsDeliverUnlocked(domainId) then
            table.insert(self.m_domainDropDownInfo, {
                domainId = domainId,
                name = domainData.domainName,
                icon = domainData.domainIcon,
            })
            if domainId == curDomainId and (self.m_resumeState == nil or self.m_resumeState.filterDomainId == nil) then
                self.m_curDomainIndex = #self.m_domainDropDownInfo
                self.m_filterDomainIdList = domainId
            end
        end

    end

    if self.m_resumeState and self.m_resumeState.filterDomainId ~= nil then
        for index, info in ipairs(self.m_domainDropDownInfo) do
            if info.domainId == self.m_filterDomainIdList then
                self.m_curDomainIndex = index
                break
            end
        end

    end

    self.view.dropDownListUp:Init(function(index, option, isSelected)
        local info = self.m_domainDropDownInfo[LuaIndex(index)]
        option:SetText(info.name)
        option.icon:LoadSprite(UIConst.UI_SPRITE_DOMAIN_ICON, "icon_depot_filter_" .. info.icon)
    end, function(index)
        if inited then 
            local domainIndex = LuaIndex(index)
            self.m_curDomainIndex = domainIndex
            self.m_filterDomainIdList = self.m_domainDropDownInfo[domainIndex].domainId
            self:_OnRefreshBtnClick()
        end
    end)
    self.view.dropDownListUp.onValidateSelectCell = function(oldIndex, newIndex)
        if inited and DateTimeUtils.GetCurrentTimestampBySeconds() < self.m_nextRefreshTimestamp then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_DOMAIN_DEPOT_DELIVERY_REFRESH_TOO_FREQUENT)
            return false
        end
        return true
    end
    self.view.dropDownListUp:Refresh(#self.m_domainDropDownInfo, CSIndex(self.m_curDomainIndex))

    self.view.dropDownListUp.captionIcon:LoadSprite(UIConst.UI_SPRITE_DOMAIN_ICON, "icon_depot_filter_" .. self.m_domainDropDownInfo[self.m_curDomainIndex].icon)

    if self.m_resumeState then
        self.m_nextRefreshTimestamp = self.m_resumeState.nextRefreshTimestamp
        self:_RefreshCountdown()
        self:OnSync()
    else
        
        self:_OnRefreshBtnClick()
    end

    inited = true
end


DomainDepotDeliveryCtrl.GetCurStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        resumeState = {
            filterDomainId = self.m_filterDomainIdList,
            nextRefreshTimestamp = self.m_nextRefreshTimestamp,
        }
    }
end

DomainDepotDeliveryCtrl._OnRefreshBtnClick = HL.Method() << function(self)
    self.m_nextRefreshTimestamp = REFRESH_INTERVAL + DateTimeUtils.GetCurrentTimestampBySeconds()
    GameInstance.player.domainDepotSystem:SendSyncDomainDepotDeliverDelegate(self.m_filterDomainIdList)
    self:_RefreshCountdown()
end


DomainDepotDeliveryCtrl._RefreshCountdown = HL.Method() << function(self)
    if self.m_nextRefreshTimestamp <= DateTimeUtils.GetCurrentTimestampBySeconds() then
        self.m_nextRefreshTimestamp = 0
        self.view.refreshBtn.gameObject:SetActive(true)
        self.view.countTimeNode.gameObject:SetActive(false)
        return
    end
    self.view.refreshBtn.gameObject:SetActive(false)
    self.view.countTimeNode.gameObject:SetActive(true)
    self.view.countDownText:InitCountDownText(self.m_nextRefreshTimestamp, function()
        self.m_nextRefreshTimestamp = 0
        self.view.refreshBtn.gameObject:SetActive(true)
        self.view.countTimeNode.gameObject:SetActive(false)
    end, function(sec)
        return UIUtils.getSecondsLeftTime(sec) .. Language.LUA_DOMAIN_DEPOT_DELIVERY_REFRESH_COUNTDOWN
    end)
end

DomainDepotDeliveryCtrl._RefreshDeliveryList = HL.Method(HL.Function) << function(self, onComplete)
    if self.m_isSyncingPeerInfo then
        return
    end
    self.m_isSyncingPeerInfo = true
    local deliverList = GameInstance.player.domainDepotSystem.remoteDelegateDeliverList
    DomainDepotUtils.SyncMissingDeliveryPeerInfos(deliverList, function()
        self.m_isSyncingPeerInfo = false
        onComplete()
    end)
end


DomainDepotDeliveryCtrl._RefreshDailyCount = HL.Method() << function(self)
    self.view.times1Txt.text = GameInstance.player.domainDepotSystem.dailyTakeDelegateCount
    self.view.times1Txt.color = GameInstance.player.domainDepotSystem.dailyTakeDelegateCount == 3 and self.view.config.FULL_COLOR or self.view.config.NORMAL_COLOR
    for i = 1, Tables.domainDepotConst.dailyTakeDelegateCount do
        self.view['state' .. i]:SetState(GameInstance.player.domainDepotSystem.dailyTakeDelegateCount == 3 and "red" or i <= GameInstance.player.domainDepotSystem.dailyTakeDelegateCount and "have" or "use")
    end
end

DomainDepotDeliveryCtrl.OnSync = HL.Method() << function(self)
    self:_RefreshDailyCount()
    self:_RefreshDeliveryList(function()
        self.view.scrollList:UpdateCount(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count)
        self.view.selectableNaviGroup:NaviToThisGroup()
        self.view.emptyNode.gameObject:SetActive(GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count == 0)
    end)
end

DomainDepotDeliveryCtrl.OnShow = HL.Override() << function(self)
    if GameInstance.player.domainDepotSystem.remoteDelegateDeliverList.Count ~= 0 then
        self:OnSync()
    else
        self:_RefreshDailyCount()
    end
end


DomainDepotDeliveryCtrl.OnHide = HL.Override() << function(self)
    self.view.scrollList:UpdateShowingCells(function(csIndex, obj)
        local cell = self.m_getCellFunc(obj)
        cell.view.animationWrapper:PlayOutAnimation()
    end)
end




HL.Commit(DomainDepotDeliveryCtrl)
