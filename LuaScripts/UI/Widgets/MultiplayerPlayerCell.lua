local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local DEFAULT_CHAT_BG_ICON = "business_card_topic_normal_2"


MultiplayerPlayerCell = HL.Class('MultiplayerPlayerCell', UIWidgetBase)

MultiplayerPlayerCell.InitMultiplayerPlayerCell = HL.Method(HL.Number, HL.Any, HL.Opt(HL.Function, HL.Function)) << function(self, roleId, friendInfo, clickFunc, headClickFun)
    self.view.playerHead.gameObject:SetActive(true)
    self.view.playerHead:UpdateHideSignature(true)
    self.view.playerHead:UpdateHidePlatformNode(true)
    self.view.playerHead:UpdateHideLevelTxt(false)
    self.view.playerHead:InitCommonPlayerHeadByRoleId(roleId, headClickFun)
    self:_UpdatePlatformInfo(FriendUtils.isPsnPlatform(), friendInfo.psName)
    self:_UpdateSeasonTowerTag(friendInfo)

    if friendInfo.remakeName and not string.isEmpty(friendInfo.remakeName) then
        self.view.tileTxt.text = string.format(Language.LUA_FRIEND_REMAKE_NAME, friendInfo.remakeName, friendInfo.name, friendInfo.shortId)
    else
        self.view.tileTxt.text = string.format(Language.LUA_FRIEND_NAME, friendInfo.name, friendInfo.shortId)
    end
    self:_UpdateThemeBg(friendInfo.businessCardTopicId)
    self.view.button.onClick:RemoveAllListeners()
    if clickFunc then
        self.view.button.onClick:AddListener(clickFunc)
    end
end


MultiplayerPlayerCell.InitMultiplayerPlayerCellByDisplayInfo = HL.Method(HL.Table) << function(self, displayInfo)
    self.view.playerHead.gameObject:SetActive(true)
    self.view.playerHead:UpdateHideSignature(true)
    self.view.playerHead:UpdateHidePlatformNode(true)
    self.view.playerHead:UpdateHideLevelTxt(true)
    self.view.playerHead:InitCommonPlayerHead(displayInfo.avatarIcon, displayInfo.avatarFrameIcon, false,
            displayInfo.adventureLevel, displayInfo.nickname, displayInfo.signature, displayInfo.psName)
    self:_UpdatePlatformInfo(false)
    self:_UpdateSeasonTowerTag(nil)
    self.view.tileTxt.text = displayInfo.nickname
    self:_UpdateThemeBg(displayInfo.cardTopicId)
    self.view.button.onClick:RemoveAllListeners()
end


MultiplayerPlayerCell._UpdatePlatformInfo = HL.Method(HL.Boolean, HL.Opt(HL.String)) << function(self, showPlatform, psName)
    local hasPsName = not string.isEmpty(psName)
    local showPsName = showPlatform and hasPsName
    local showPcIcon = showPlatform and not hasPsName
    self.view.bgSonyNameImage.gameObject:SetActive(showPsName)
    self.view.sonyNameTxt.text = showPsName and psName or ""
    self.view.psIconNode.gameObject:SetActive(showPcIcon)
    self.view.pcIcon.gameObject:SetActive(showPcIcon)
    
    self.view.psIcon.gameObject:SetActive(false)
end

MultiplayerPlayerCell._UpdateSeasonTowerTag = HL.Method(HL.Any) << function(self, friendInfo)
    local displayRecord = FriendUtils.getSeasonTowerDisplayRecord(friendInfo)
    local rank = displayRecord and displayRecord.rank or 0
    local rankName = displayRecord and FriendUtils.SEASON_TOWER_RANK_NAMES[rank]
    local seasonTowerTagSmall = self.view.seasonTowerTagSmall
    seasonTowerTagSmall.gameObject:SetActiveIfNecessary(rankName ~= nil)
    if rankName then
        seasonTowerTagSmall:SetState(rankName)
    end
end

MultiplayerPlayerCell._UpdateThemeBg = HL.Method(HL.Any) << function(self, businessCardTopicId)
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

HL.Commit(MultiplayerPlayerCell)
return MultiplayerPlayerCell
