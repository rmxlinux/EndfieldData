local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')






BusinessCardPersonalInfoNode = HL.Class('BusinessCardPersonalInfoNode', UIWidgetBase)


BusinessCardPersonalInfoNode.m_id = HL.Field(HL.Number) << 0


BusinessCardPersonalInfoNode.m_preview = HL.Field(HL.Boolean) << false




BusinessCardPersonalInfoNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.btnOther.onClick:RemoveAllListeners()
    self.view.btnOther.onClick:AddListener(function()
        if self.m_id == GameInstance.player.roleId then
            FriendUtils.FRIEND_CELL_INIT_FUNC.onSelfClick(self.view.tipRect, self.m_id)
        elseif GameInstance.player.friendSystem.friendInfoDic:ContainsKey(self.m_id) then
            
            FriendUtils.FRIEND_CELL_INIT_FUNC.onBusinessCardFriendPlayerClick(self.view.tipRect, self.m_id)
        else
            FriendUtils.FRIEND_CELL_INIT_FUNC.onBusinessCardStrangerPlayerClick(self.view.tipRect, self.m_id)
        end
    end)

    self.view.playerUidTxtButton.onClick:RemoveAllListeners()
    self.view.playerUidTxtButton.onClick:AddListener(function()
        Unity.GUIUtility.systemCopyBuffer = self.view.playerUidTxt.text
        Notify(MessageConst.SHOW_TOAST, Language.LUA_COPY_UID_SUCCESS)
    end)
end





BusinessCardPersonalInfoNode.InitBusinessCardPersonalInfoNodeByRoleId = HL.Method(HL.Number, HL.Boolean) << function(self, roleId, preview)
    self:_FirstTimeInit()

    self.m_preview = preview
    self.m_id = roleId
    if self.m_id == GameInstance.player.roleId then
        self.view.redDot:InitRedDot("NewAvatarInfo")
    else
        self.view.redDot.gameObject:SetActiveIfNecessary(false)
    end

    local success, playerInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
    if not success then
        logger.error("获取玩家信息失败，roleId: " .. roleId)
        return
    end

    local click = not preview and function()
        
        UIManager:Open(PanelId.FriendHeadSelectedPopUp)
    end or false

    self.view.commonPlayerHead:InitCommonPlayerHeadByRoleId(roleId, click)

    

    local stateName = string.isEmpty(playerInfo.remakeName) and "NoRemarks" or "Remarks"
    local name = string.format(Language.LUA_FRIEND_NAME, playerInfo.name, playerInfo.shortId)
    self.view.nameTxt.text = name
    self.view.remarkTxt.text = playerInfo.remakeName

    if FriendUtils.isPsnPlatform() then
        stateName = stateName .. (string.isEmpty(playerInfo.psName) and "NoPsAccount" or "Ps")
        self.view.layoutName:SetState(stateName)
        self.view.psNameTxt.text = playerInfo.psName
    else
        self.view.psNameRoot.gameObject:SetActiveIfNecessary(false)
        self.view.psNameTxt.gameObject:SetActiveIfNecessary(false)
        if not string.isEmpty(playerInfo.remakeName) then
            self.view.layoutName:SetState(stateName)
        else
            self.view.layoutName:SetState(stateName)
        end
    end

    self.view.playerUidTxt.text = playerInfo.platformRoleId
    self.view.timeText.text = os.date(Language.LUA_BUSINESS_CARD_TIME, playerInfo.createTime)
end

HL.Commit(BusinessCardPersonalInfoNode)
return BusinessCardPersonalInfoNode

