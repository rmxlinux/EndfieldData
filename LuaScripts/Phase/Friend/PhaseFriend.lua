local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Friend























PhaseFriend = HL.Class('PhaseFriend', phaseBase.PhaseBase)


PhaseFriend.m_curPanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseFriend.m_curPopupPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseFriend.m_panelItemDic = HL.Field(HL.Table)


PhaseFriend.m_popupPanelItemDic = HL.Field(HL.Table)


PhaseFriend.m_tabPanel = HL.Field(HL.Forward("PhasePanelItem"))






PhaseFriend.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FRIEND_CHAR_QUERY] = { '_OnFriendCharQuery', false },
    [MessageConst.ON_FRIEND_BUSINESS_INFO_CHANGE] = { '_BindControllerHintPlaceHolder', true },
}





PhaseFriend._OnInit = HL.Override() << function(self)
    PhaseFriend.Super._OnInit(self)
end









PhaseFriend.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end





PhaseFriend._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if self.arg == nil then
        self.arg = {}
    end

    self.m_panelItemDic = {}
    self.m_popupPanelItemDic = {}
    self.m_tabPanel = self:CreatePhasePanelItem(PanelId.FriendTab, self.arg)
    
    Notify(MessageConst.ON_CHANGE_FRIEND_TAB, self.arg)

    if self.arg and self.arg.needTab == false then
        if self.m_tabPanel then
            self.m_tabPanel.uiCtrl:Hide()
        end
    end

    self:_BindControllerHintPlaceHolder()
end





PhaseFriend._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFriend._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFriend._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end








PhaseFriend._OnActivated = HL.Override() << function(self)
end



PhaseFriend._OnDeActivated = HL.Override() << function(self)
end





PhaseFriend._OnRefresh = HL.Override() << function(self)
    if self.m_curPopupPanel ~= nil then
        self.m_curPopupPanel.uiCtrl:Close()
    end
    
    if self.arg and (self.arg.panelId or self.m_curPanelItem == nil or self.m_curPanelItem.uiCtrl.panelId ~= self.arg.panelId) then
        Notify(MessageConst.ON_CHANGE_FRIEND_TAB, self.arg)
    elseif self.m_curPanelItem then
        self.m_curPanelItem.uiCtrl:OnPhaseRefresh(self.arg)
    end

    if self.arg and self.arg.needTab == false then
        if self.m_tabPanel then
            self.m_tabPanel.uiCtrl:Hide()
        end
    end
end





PhaseFriend.OpenPopupPanel = HL.Method(HL.Number, HL.Any) << function(self, panelId, args)
    if panelId == nil then
        return
    end

    local panelItem
    if self.m_popupPanelItemDic[panelId] then
        panelItem = self.m_popupPanelItemDic[panelId]
    else
        panelItem = self:CreatePhasePanelItem(panelId, args)
        self.m_popupPanelItemDic[panelId] = panelItem
    end
    panelItem.uiCtrl:Show()
    self.m_curPopupPanel = panelItem
end




PhaseFriend.ClosePopupPanel = HL.Method(HL.Number) << function(self, panelId)
    if self.m_popupPanelItemDic[panelId] then
        self.m_popupPanelItemDic[panelId].uiCtrl:Close()
    end
    if self.m_curPanelItem then
        self.m_curPanelItem.uiCtrl:OnPhaseRefresh(self.arg)
    end
end





PhaseFriend.OnTabChange = HL.Method(HL.Number, HL.Opt(HL.Table)) << function(self, panelId ,arg)
    if panelId == nil then
        return
    end

    if self.m_curPanelItem then
        self.m_curPanelItem.uiCtrl:Hide()
    end

    local panelItem
    if self.m_panelItemDic[panelId] then
        panelItem = self.m_panelItemDic[panelId]
        panelItem.uiCtrl:Show()
        panelItem.uiCtrl:OnPhaseRefresh(arg)
    else
        panelItem = self:CreatePhasePanelItem(panelId, arg)
        self.m_panelItemDic[panelId] = panelItem
    end
    self.m_curPanelItem = panelItem
    self:_BindControllerHintPlaceHolder()
end




PhaseFriend.SetTabBlockState = HL.Method(HL.Boolean) << function(self, isBlock)
    if self.m_tabPanel and self.m_tabPanel.uiCtrl then
        self.m_tabPanel.uiCtrl.view.inputGroup.enabled = not isBlock
    end
end



PhaseFriend._BindControllerHintPlaceHolder = HL.Method() << function(self)
    if not self.m_tabPanel then
        return
    end

    local friendCtrl = self.m_tabPanel.uiCtrl
    if friendCtrl and DeviceInfo.inputType == DeviceInfo.InputType.Controller then
        self.m_curPanelItem.uiCtrl.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
            friendCtrl.view.inputGroup.groupId,
            self.m_curPanelItem.uiCtrl.view.inputGroup.groupId,
        })
    end
end


PhaseFriend.s_mainFriendCharTemplateId = HL.StaticField(HL.String) << ""



PhaseFriend._OnFriendCharQuery = HL.StaticMethod(HL.Table) << function(args)
    local roleId, charData = unpack(args)
    if charData == nil then
        logger.error("PhaseFriend._OnFriendCharQuery: charData is nil for roleId: " .. tostring(roleId))
        return
    end

    local charInstIdList = {}
    local mainCharInfo
    for i = 0, charData.Count - 1 do
        local charInfo = GameInstance.player.charBag:CreateClientFriendCharInfo(charData[i], ScopeUtil.GetCurrentScope())
        if charInfo then
            table.insert(charInstIdList, charInfo.instId)
            if charInfo.templateId == PhaseFriend.s_mainFriendCharTemplateId  then
                mainCharInfo = charInfo
            end
        else
            logger.error("PhaseFriend._OnFriendCharQuery: CreateClientFriendCharInfo failed for roleId: " .. tostring(roleId))
        end
    end

    CharInfoUtils.openCharInfoBestWay({
        initCharInfo = {
            instId = mainCharInfo.instId,
            templateId = mainCharInfo.templateId,
            isTrail = false,
            charInstIdList = charInstIdList,
        },
        onClose = function()
            GameInstance.player.charBag:ClearAllClientCharAndItemData()
        end,
    })
end

HL.Commit(PhaseFriend)

