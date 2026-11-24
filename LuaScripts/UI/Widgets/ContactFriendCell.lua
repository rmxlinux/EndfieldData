local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ContactFriendCell = HL.Class('ContactFriendCell', UIWidgetBase)

ContactFriendCell.m_friendInfo = HL.Field(HL.Any)

ContactFriendCell.m_roleId = HL.Field(HL.Any)

ContactFriendCell.m_hideRedDot = HL.Field(HL.Boolean) << false


local FriendState = {
    Online = "Online",
    Offline = "Offline",
}

local DEFAULT_CHAT_BG_ICON = "business_card_topic_normal_2"

ContactFriendCell.InitContactFriendCell = HL.Method(HL.Number, HL.Any, HL.Number,HL.Function, HL.Opt(HL.Function)) << function(
    self, roleId, friendInfo, csIndex, onClickFun, headClickFun)
    self.m_roleId = roleId
    if not friendInfo or not friendInfo.init then
        self:InitEmptyFriendCell(roleId, csIndex, onClickFun)
        logger.info("[ContactFriendCell] 未找到好友数据 " .. roleId)
        return
    end

    self.view.noDataState.gameObject:SetActive(false)


    self.m_friendInfo = friendInfo
    self.view.playerHead.gameObject:SetActive(true)
    self.view.playerHead:UpdateHideSignature(true)
    self.view.playerHead:InitCommonPlayerHeadByRoleId(roleId, headClickFun)
    self.view.pcIcon.gameObject:SetActive(false)
    self.view.psIcon.gameObject:SetActive(not string.isEmpty(friendInfo.psName) and FriendUtils.isPsnPlatform())

    self:UpdateThemeBg()
    self:UpdateRedDot()
    self:UpdateOnlineInfo()
    self:UpdateTileTxt()

    self.view.button.onClick:RemoveAllListeners()
    self.view.button.onClick:AddListener(function()
        if onClickFun ~= nil then
            onClickFun(csIndex)
        end
    end)
end



ContactFriendCell.InitContactFriendCellByDisplayInfo = HL.Method(HL.Table) << function(self, displayInfo)
    self.m_roleId = 0
    self.m_friendInfo = nil

    self.view.noDataState.gameObject:SetActive(false)
    self.view.playerHead.gameObject:SetActive(true)
    self.view.playerHead:UpdateHideSignature(true)
    self.view.playerHead:InitCommonPlayerHead(displayInfo.avatarIcon, displayInfo.avatarFrameIcon, false,
            displayInfo.adventureLevel, displayInfo.nickname, displayInfo.signature, displayInfo.psName)
    self.view.pcIcon.gameObject:SetActive(false)
    self.view.psIcon.gameObject:SetActive(false)
    self.view.tileTxt.text = displayInfo.nickname
    self:UpdateThemeBgByTopicId(displayInfo.cardTopicId)

    self.view.onlineState.gameObject:SetActive(false)
    self.view.offlineTimeTxt.text = ""
    self.view.onlineTimeTxt.text = ""
    self.view.redDotLayout.gameObject:SetActive(false)
    
    self.view.button.onClick:RemoveAllListeners()
end

ContactFriendCell.InitLoadingFriendCell = HL.Method(HL.Number, HL.Number, HL.Function) << function(self, roleId, csIndex, onClickFun)
    self.view.noDataState.gameObject:SetActive(true)
    self.view.noDataBgDecoMask.gameObject:SetActive(true)
    self.view.noDataDeco01.gameObject:SetActive(true)
    self.view.noDataText.text = Language.LUA_SPACESHIP_SETTLEMENT_LOADING_TEXT

    self.view.playerHead.gameObject:SetActive(false)
    self.view.pcIcon.gameObject:SetActive(false)
    self.view.psIcon.gameObject:SetActive(false)
    self.view.themeBgImg.gameObject:SetActive(false)

    self.view.onlineState.gameObject:SetActive(false)
    self.view.offlineTimeTxt.text = ""
    self.view.onlineTimeTxt.text = ""
    self.view.tileTxt.text = ""

    self.view.button.onClick:RemoveAllListeners()
    self.view.button.onClick:AddListener(function()
        if onClickFun ~= nil then
            onClickFun(csIndex)
        end
    end)
    self.view.redDotLayout.gameObject:SetActive(false)
end


ContactFriendCell.InitEmptyFriendCell = HL.Method(HL.Number, HL.Number, HL.Function) << function(self, roleId, csIndex, onClickFun)
    self.view.noDataState.gameObject:SetActive(true)
    self.view.noDataBgDecoMask.gameObject:SetActive(true)
    self.view.noDataDeco01.gameObject:SetActive(true)
    self.view.noDataText.text = Language.ui_friend_account_deactivated

    self.view.playerHead.gameObject:SetActive(false)
    self.view.pcIcon.gameObject:SetActive(false)
    self.view.psIcon.gameObject:SetActive(false)
    self.view.themeBgImg.gameObject:SetActive(false)

    self.view.onlineState.gameObject:SetActive(false)
    self.view.offlineTimeTxt.text = ""
    self.view.onlineTimeTxt.text = ""
    self.view.tileTxt.text = ""

    self.view.button.onClick:RemoveAllListeners()
    self.view.button.onClick:AddListener(function()
        if onClickFun ~= nil then
            onClickFun(csIndex)
        end
    end)
    self.view.redDotLayout.gameObject:SetActive(false)
end

ContactFriendCell.UpdateOnlineInfo = HL.Method() << function(self)
    self.view.onlineState.gameObject:SetActive(true)
    local friendInfo = self.m_friendInfo
    if friendInfo.playerOnlineState == CS.Beyond.Gameplay.PlayerOnlineState.Online then
        self.view.onlineTimeTxt.text = Language.LUA_FRIEND_ONLINE
        self.view.onlineState:SetState(FriendState.Online)
    elseif friendInfo.lastDateTime ~= 0 then
        self.view.onlineState:SetState(FriendState.Offline)
        local curServerTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        self.view.offlineTimeTxt.text = string.format(Language.LUA_FRIEND_LAST_ONLINE_TIME, UIUtils.getLeftTime(curServerTime - friendInfo.lastDateTime))
    else
        self.view.offlineTimeTxt.text = ""
        self.view.onlineTimeTxt.text = ""
    end
end


ContactFriendCell.UpdateTileTxt = HL.Method() << function(self)
    local friendInfo = self.m_friendInfo
    if not friendInfo then
        return
    end
    local nameStr = ""
    if friendInfo.remakeName and not string.isEmpty(friendInfo.remakeName) then
        nameStr = string.format(Language.LUA_FRIEND_REMAKE_NAME, friendInfo.remakeName, friendInfo.name, friendInfo.shortId)
    else
        nameStr = string.format(Language.LUA_FRIEND_NAME, friendInfo.name, friendInfo.shortId)
    end
    self.view.tileTxt.text = nameStr
end

ContactFriendCell.UpdateThemeBg = HL.Method() << function(self)
    self:UpdateThemeBgByTopicId(self.m_friendInfo.businessCardTopicId)
end

ContactFriendCell.UpdateThemeBgByTopicId = HL.Method(HL.Any) << function(self, businessCardTopicId)
    self.view.themeBgImg.gameObject:SetActive(true)
    if string.isEmpty(businessCardTopicId) then
        self.view.themeBgImg:LoadSprite(UIConst.UI_BUSINESS_CARD_FRIEND_CHAT_ICON_PATH, DEFAULT_CHAT_BG_ICON)
        return
    end

    local success, topicCfg = Tables.businessCardTopicTable:TryGetValue(businessCardTopicId)
    if success then
        self.view.themeBgImg:LoadSprite(UIConst.UI_BUSINESS_CARD_FRIEND_CHAT_ICON_PATH, topicCfg.id)
    else
        logger.error("未找到名片主题配置 " .. businessCardTopicId)
    end
end


ContactFriendCell.SetHideRedDot = HL.Method(HL.Boolean) << function(self, hide)
    self.m_hideRedDot = hide
end

ContactFriendCell.UpdateRedDot = HL.Method() << function(self)
    if self.m_hideRedDot then
        self.view.redDotLayout.gameObject:SetActive(false)
        return
    end

    local chatInfo = GameInstance.player.friendChatSystem:GetChatInfo(self.m_roleId)
    if chatInfo and chatInfo.unReadNum > 0 then
        self.view.redDotLayout.gameObject:SetActive(true)
        self.view.redDotTxt.text = chatInfo.unReadNum > 99 and "99+" or tostring(chatInfo.unReadNum)
    else
        self.view.redDotLayout.gameObject:SetActive(false)
    end
end

HL.Commit(ContactFriendCell)
return ContactFriendCell

