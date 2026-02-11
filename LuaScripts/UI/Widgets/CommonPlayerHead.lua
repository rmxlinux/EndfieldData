local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')














CommonPlayerHead = HL.Class('CommonPlayerHead', UIWidgetBase)


CommonPlayerHead.m_onClick = HL.Field(HL.Function)


CommonPlayerHead.m_canClick = HL.Field(HL.Boolean) << false


CommonPlayerHead.m_roleId = HL.Field(HL.Number) << 0


CommonPlayerHead.m_hideSignature = HL.Field(HL.Any) << nil


CommonPlayerHead.m_hideLevelTxt = HL.Field(HL.Any) << nil




CommonPlayerHead._OnFirstTimeInit = HL.Override() << function(self)
    self.view.playerHeadBtn.onClick:RemoveAllListeners()
    self.view.playerHeadBtn.onClick:AddListener(function()
        if self.m_canClick then
            if self.m_onClick then
                self.m_onClick()
            else
                if GameInstance.player.friendSystem.friendInfoDic:ContainsKey(self.m_roleId) then
                    
                    FriendUtils.FRIEND_CELL_INIT_FUNC.onCommonFriendPlayerClick(self.view.tipRectTransform, self.m_roleId)
                else
                    FriendUtils.FRIEND_CELL_INIT_FUNC.onCommonStrangerPlayerClick(self.view.tipRectTransform, self.m_roleId)
                end
            end
        end
    end)
end






CommonPlayerHead.InitCommonPlayerHeadByRoleId = HL.Method(HL.Number, HL.Any, HL.Opt(HL.String)) << function(self, roleId, click, searchKey)
    self:_FirstTimeInit()
    self.m_roleId = roleId
    local success, playerInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)

    if success then
        local nameStr = ""
        local avatarPath = ""
        local avatarFramePath = ""

        local remarkName = playerInfo.remakeName
        local name = playerInfo.name

        if searchKey and not string.isEmpty(searchKey) then
            remarkName = FriendUtils.simpleIgnoreCaseReplace(remarkName, searchKey, Language.LUA_FRIEND_NAME_SEARCH)
            name = FriendUtils.simpleIgnoreCaseReplace(name, searchKey, Language.LUA_FRIEND_NAME_SEARCH)
        end

        if remarkName and not string.isEmpty(remarkName) then
            nameStr = string.format(Language.LUA_FRIEND_REMAKE_NAME, remarkName, name, playerInfo.shortId)
        else
            nameStr = string.format(Language.LUA_FRIEND_NAME, name, playerInfo.shortId)
        end


        if playerInfo.userAvatarId then
            avatarPath = Tables.userAvatarTable:GetValue(playerInfo.userAvatarId).icon
        end
        if playerInfo.userAvatarFrameId then
            avatarFramePath = Tables.userAvatarTableFrame:GetValue(playerInfo.userAvatarFrameId).icon
        end

        local signature = playerInfo.signature
        if self.m_hideSignature or GameInstance.player.friendSystem.isCommunicationRestricted then
            signature = nil
        end
        self:InitCommonPlayerHead(avatarPath, avatarFramePath, click, playerInfo.adventureLevel, nameStr, signature, playerInfo.psName)
    else
        self:InitCommonPlayerHead("", "", false, 0, Language.LUA_FRIEND_NOT_EXIST, "", "")
        logger.info(CS.Beyond.ELogChannel.Friend,"获取玩家信息失败，roleId: " .. roleId)
        return
    end
end




CommonPlayerHead.UpdateHideSignature = HL.Method(HL.Any) << function(self, hideSignature)
    self.m_hideSignature = hideSignature
end





CommonPlayerHead.UpdateHideLevelTxt = HL.Method(HL.Any) << function(self, hideLevelTxt)
    self.m_hideLevelTxt = hideLevelTxt
end










CommonPlayerHead.InitCommonPlayerHead = HL.Method(HL.String, HL.String, HL.Any, HL.Opt(HL.Number, HL.String, HL.String, HL.String)) << function(self, avatarPath, avatarFramePath, click, adventureLevel, name, signature, psName)
    self:_FirstTimeInit()

    if name == nil then
        self.view.nameText.gameObject:SetActiveIfNecessary(false)
    else
        self.view.nameText.gameObject:SetActiveIfNecessary(true)
        self.view.nameText.text = name
    end

    if signature == nil or string.isEmpty(signature) or GameInstance.player.friendSystem.isCommunicationRestricted then
        self.view.signatureTxt.gameObject:SetActiveIfNecessary(false)
    else
        self.view.signatureTxt.gameObject:SetActiveIfNecessary(true)
        self.view.signatureTxt.text = signature
    end

    if FriendUtils.isPsnPlatform() then
        self.view.pcNode.gameObject:SetActiveIfNecessary(string.isEmpty(psName))
        self.view.psRoot.gameObject:SetActiveIfNecessary(not string.isEmpty(psName))
        self.view.psNameTxt.text = psName
    else
        self.view.pcNode.gameObject:SetActiveIfNecessary(false)
        self.view.psRoot.gameObject:SetActiveIfNecessary(false)
    end

    self:SetClick(click)

    if self.m_hideLevelTxt then
        adventureLevel = ""
    end
    self.view.levelTxt.text = adventureLevel

    if avatarPath and not string.isEmpty(avatarPath) then
        self.view.playerHead:LoadSprite(avatarPath)
        self.view.playerHead.gameObject:SetActiveIfNecessary(true)
    else
        self.view.playerHead.gameObject:SetActiveIfNecessary(false)
    end
    if avatarFramePath and not string.isEmpty(avatarFramePath) then
        self.view.headFrameImg:LoadSprite(UIConst.UI_SPRITE_HEAD_FRAME, avatarFramePath)
        self.view.headFrameImg.gameObject:SetActiveIfNecessary(true)
    else
        self.view.headFrameImg.gameObject:SetActiveIfNecessary(false)
    end
end




CommonPlayerHead.SetClick = HL.Method(HL.Any) << function(self, click)
    if type(click) == 'function' then
        self.m_onClick = click
        self.m_canClick = true
    elseif type(click) == 'boolean' then
        self.m_onClick = nil
        self.m_canClick = click
    else
        self.m_onClick = nil
        self.m_canClick = false
    end
    self.view.playerHeadBtn.enabled = self.m_canClick
end



CommonPlayerHead.OnClick = HL.Method() << function(self)
    if self.m_canClick and self.m_onClick then
        self.m_onClick()
    end
end

HL.Commit(CommonPlayerHead)
return CommonPlayerHead

