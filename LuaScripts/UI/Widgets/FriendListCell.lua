local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

FriendListCell = HL.Class('FriendListCell', UIWidgetBase)

local DYNAMIC_PACKAGE_CONFIG = {
    LoadingNode = { prefab = "loadingNodePrefab", slot = "loadingNodeSlot", order = 1, refs = {} },
    NoDataNode = { prefab = "noDataNodePrefab", slot = "noDataNodeSlot", order = 2, stateController = true, refs = { "dynamicStateController", "noDataSplitLineHelper" } },
    NonGameUserNode = { prefab = "nonGameUserNodePrefab", slot = "nonGameUserNodeSlot", order = 3, refs = { "psnInfoBtnForNoGameUser", "sonyNameTxt", "playerHeadBtnForNoGameUser" } },
    BlackListBackgroundNode = { prefab = "blackListBackgroundNodePrefab", slot = "blackListBackgroundNodeSlot", order = 3, refs = {} },
    NormalActionNode = { prefab = "normalActionNodePrefab", slot = "normalActionNodeSlot", order = 9, refs = { "shipBtn", "msgBtn", "messageNumText", "shipBtnStateController", "shipHelp", "msgRedDotNumber", "lockMask", "clueExchange" } },
    FriendRequestNode = { prefab = "friendRequestNodePrefab", slot = "friendRequestNodeSlot", order = 10, refs = { "acceptFriendBtn", "notAcceptFriendBtn" } },
    BlackListNode = { prefab = "blackListNodePrefab", slot = "blackListNodeSlot", order = 11, refs = { "removeBlackListBtn", "psnInfoBtnForBlackUser" } },
    CheckDataListNode = { prefab = "checkDataListNodePrefab", slot = "checkDataListNodeSlot", order = 12, refs = {} },
    StrangerNode = { prefab = "strangerNodePrefab", slot = "strangerNodeSlot", order = 13, stateController = true, refs = { "addFriendBtn", "dynamicStateController" } },
    ModeActionNode = { prefab = "modeActionNodePrefab", slot = "modeActionNodeSlot", order = 14, stateController = true, refs = { "chatBtn", "shareBtn", "messageNumNode", "dynamicStateController", "dynamicMessageNumText" } },
    SpaceshipVisitorNode = { prefab = "spaceshipVisitorNodePrefab", slot = "spaceshipVisitorNodeSlot", order = 15, refs = { "spaceshipVisitorBtn", "spreadBtn", "spreadIconRect", "visitorState", "visitorTxt" } },
    SpaceshipClueGiftNode = { prefab = "spaceshipClueGiftNodePrefab", slot = "spaceshipClueGiftNodeSlot", order = 16, refs = { "clueNodes", "clueState", "clueNode", "giftBtn" } },
}

local DYNAMIC_PACKAGE_NAMES = {
    "LoadingNode",
    "NoDataNode",
    "NonGameUserNode",
    "BlackListBackgroundNode",
    "NormalActionNode",
    "FriendRequestNode",
    "BlackListNode",
    "CheckDataListNode",
    "StrangerNode",
    "ModeActionNode",
    "SpaceshipVisitorNode",
    "SpaceshipClueGiftNode",
}

local CONTENT_STATE_PACKAGE = {
    Normal = { "NormalActionNode" },
    FriendRequest = { "FriendRequestNode" },
    BlackList = { "BlackListBackgroundNode", "BlackListNode" },
    Stranger = { "StrangerNode" },
    Stranger_Wait = { "StrangerNode" },
    Stranger_Friend = { "StrangerNode" },
    share = { "ModeActionNode" },
    ChatBtn = { "ModeActionNode" },
    SpaceshipVisitor = { "SpaceshipVisitorNode" },
    SpaceshipClueGift = { "SpaceshipClueGiftNode" },
}

local EMPTY_STATE_PACKAGE = {
    Loading = "LoadingNode",
    NoData = "NoDataNode",
    NoData_Spaceship = "NoDataNode",
    NonGameUser = "NonGameUserNode",
}

FriendListCell.info = HL.Field(HL.Userdata)

FriendListCell.id = HL.Field(HL.Number) << 0

FriendListCell.charInfos = HL.Field(HL.Table)

FriendListCell.charInstanceIdList = HL.Field(HL.Table)

FriendListCell.charCellList = HL.Field(HL.Table)

FriendListCell.arg = HL.Field(HL.Table)

FriendListCell.m_clueCells = HL.Field(HL.Forward("UIListCache"))

FriendListCell.showCharInfoCallBack = HL.Field(HL.Function)

FriendListCell.searchKey = HL.Field(HL.String) << ""

FriendListCell.m_buildNodeId = HL.Field(HL.Number) << 0


FriendListCell._BindDynamicPackage = HL.Method(HL.String, GameObject) << function(self, packageName, obj)
    local packageView = Utils.wrapLuaNode(obj)
    local config = DYNAMIC_PACKAGE_CONFIG[packageName]
    for _, key in ipairs(config.refs) do
        self.view[key] = packageView[key]
    end

    if packageName == "NormalActionNode" then
        self.view.shipBtn.onClick:RemoveAllListeners()
        self.view.shipBtn.onClick:AddListener(function()
            logger.info("点击好友飞船")
            if self.arg.onShipClick then
                self.arg.onShipClick(self.info.roleId)
            end
        end)
        self.view.msgBtn.onClick:RemoveAllListeners()
        self.view.msgBtn.onClick:AddListener(function()
            logger.info("点击好友消息")
            if self.arg.onMessageClick then
                self.arg.onMessageClick(self.info.roleId)
            end
        end)
    elseif packageName == "NoDataNode" and self.view.noDataSplitLineHelper then
        local targets = self.view.noDataSplitLineHelper.checkTargets
        if targets then
            targets:Clear()
            if self.view.msgBtn then
                targets:Add(self.view.msgBtn.gameObject)
            end
            self.view.noDataSplitLineHelper:Sync()
        end
    elseif packageName == "FriendRequestNode" then
        self.view.acceptFriendBtn.onClick:RemoveAllListeners()
        self.view.acceptFriendBtn.onClick:AddListener(function()
            logger.info("点击acceptFriend")
            if self.arg.onAcceptClick then
                self.arg.onAcceptClick(self.info.roleId)
            end
        end)
        self.view.notAcceptFriendBtn.onClick:RemoveAllListeners()
        self.view.notAcceptFriendBtn.onClick:AddListener(function()
            logger.info("点击notAccept消息")
            if self.arg.onNotAcceptClick then
                self.arg.onNotAcceptClick(self.info.roleId)
            end
        end)
    elseif packageName == "BlackListNode" then
        self.view.removeBlackListBtn.onClick:RemoveAllListeners()
        self.view.removeBlackListBtn.onClick:AddListener(function()
            logger.info("点击Remove消息")
            if self.arg.onRemoveClick then
                self.arg.onRemoveClick(self.info.roleId)
            end
        end)
        self.view.psnInfoBtnForBlackUser.onClick:RemoveAllListeners()
        self.view.psnInfoBtnForBlackUser.onClick:AddListener(function()
            logger.info("点击 psnInfoBtn")
            if self.arg.onPsnInfoClick then
                self.arg.onPsnInfoClick(self.info.psnData.AccountId)
            end
        end)
    elseif packageName == "StrangerNode" then
        self.view.addFriendBtn.onClick:RemoveAllListeners()
        self.view.addFriendBtn.onClick:AddListener(function()
            logger.info("点击Add消息")
            FriendUtils.FRIEND_CELL_INIT_FUNC.onAddClick(self.info.roleId, self.m_buildNodeId)
        end)
    elseif packageName == "ModeActionNode" then
        self.view.chatBtn.onClick:RemoveAllListeners()
        self.view.chatBtn.onClick:AddListener(function()
            logger.info("点击 chatBtn")
            if self.arg.onChatClick then
                self.arg.onChatClick(self.info.roleId)
            end
        end)
    elseif packageName == "SpaceshipVisitorNode" then
        self.view.spreadBtn.onClick:RemoveAllListeners()
        self.view.spreadBtn.onClick:AddListener(function()
            logger.info("点击 spreadBtn")
            if self.arg.onSpaceshipVisitorClick then
                self.arg.onSpaceshipVisitorClick(self.info.roleId, self.view.spreadIconRect)
            end
        end)
    elseif packageName == "SpaceshipClueGiftNode" then
        self.view.giftBtn.onClick:RemoveAllListeners()
        self.view.giftBtn.onClick:AddListener(function()
            logger.info("点击 giftBtn")
            if self.arg.onGiftBtnClick then
                self.arg.onGiftBtnClick(self.info.roleId, function()
                    self:_UpdateClueCells()
                end)
            end
        end)
    elseif packageName == "NonGameUserNode" then
        self.view.psnInfoBtnForNoGameUser.onClick:RemoveAllListeners()
        self.view.psnInfoBtnForNoGameUser.onClick:AddListener(function()
            logger.info("点击 psnInfoBtn")
            if self.arg.onPsnInfoClick then
                self.arg.onPsnInfoClick(self.info.psnData.AccountId)
            end
        end)
    end
end


FriendListCell._RestoreDynamicPackageOrders = HL.Method() << function(self)
    for _, packageName in ipairs(DYNAMIC_PACKAGE_NAMES) do
        local config = DYNAMIC_PACKAGE_CONFIG[packageName]
        self.view[config.slot]:SetSiblingIndex(config.order)
    end
end

FriendListCell._ToggleDynamicPackage = HL.Method(HL.String, HL.Boolean).Return(HL.Opt(GameObject)) << function(self, packageName, active)
    local config = DYNAMIC_PACKAGE_CONFIG[packageName]
    local parent = self.view[config.slot]
    local prefab = LuaSystemManager.friendListCellPrefabSystem[config.prefab]
    local obj = self:tryToggleDynamicNode(parent, packageName, prefab, active)
    if obj and active then
        self:_BindDynamicPackage(packageName, obj)
    end
    return obj
end

FriendListCell._ResetDynamicPackages = HL.Method() << function(self)
    self:_RestoreDynamicPackageOrders()
    for _, packageName in ipairs(DYNAMIC_PACKAGE_NAMES) do
        self:_ToggleDynamicPackage(packageName, false)
    end
end

FriendListCell._SetEmptyState = HL.Method(HL.String) << function(self, stateName)
    self:_ResetDynamicPackages()
    self.view.emptyStateCtrl:SetState(stateName)
    local packageName = EMPTY_STATE_PACKAGE[stateName]
    if packageName then
        local packageView = self:_ToggleDynamicPackage(packageName, true)
        if DYNAMIC_PACKAGE_CONFIG[packageName].stateController and packageView and self.view.dynamicStateController then
            self.view.dynamicStateController:SetState(stateName)
        end
    end
end

FriendListCell._SetContentState = HL.Method(HL.String) << function(self, stateName)
    self.view.stateController:SetState(stateName)
    local packageNames = CONTENT_STATE_PACKAGE[stateName]
    if packageNames then
        for _, packageName in ipairs(packageNames) do
            local packageView = self:_ToggleDynamicPackage(packageName, true)
            if DYNAMIC_PACKAGE_CONFIG[packageName].stateController and packageView and self.view.dynamicStateController then
                self.view.dynamicStateController:SetState(stateName)
            end
        end
    end
end

FriendListCell._SetMessageNumText = HL.Method(HL.String) << function(self, text)
    if self.view.messageNumText then
        self.view.messageNumText.text = text
    end
    if self.view.dynamicMessageNumText then
        self.view.dynamicMessageNumText.text = text
    end
end


FriendListCell._OnFirstTimeInit = HL.Override() << function(self)
    self.showCharInfoCallBack = function()
        
        
        self:_OnCharInfoClick(1)
    end

    self.view.headBtn.onClick:RemoveAllListeners()
    self.view.headBtn.onClick:AddListener(function()
        logger.info("点击好友头像")
        if self.arg.onPlayerClick then
            local seasonTag = self.view.commonPlayerHead.view.seasonTag
            local levelTag = self.view.commonPlayerHead.view.levelTag
            local recordTipsTransform = seasonTag.gameObject.activeInHierarchy and seasonTag.transform
                or levelTag.gameObject.activeInHierarchy and levelTag.transform
                or self.view.headRectTransform
            self.arg.onPlayerClick(self.view.headRectTransform, self.info.roleId, self.showCharInfoCallBack, nil, recordTipsTransform)
        end
    end)
    self:RegisterMessage(MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE, function()
        if self.arg and self.arg.stateName == "SpaceshipClueGift" then
            return
        end
        self:_RefreshFriendCellInfo()
    end)
    self:RegisterMessage(MessageConst.ON_FRIEND_INFO_SYNC, function()
        if not self.arg or self.arg.stateName ~= "SpaceshipClueGift" or self.id == 0 then
            return
        end

        local success, info = GameInstance.player.friendSystem:TryGetFriendInfo(self.id)
        if not success then
            return
        end

        self.info = info
        self:_RefreshFriendCellInfo()
    end)
end

FriendListCell.SetLoadingState = HL.Method() << function(self)
    self:_SetEmptyState("Loading")
end

FriendListCell.RefreshFriendListCell = HL.Method(HL.Number, HL.Table, HL.String) << function(self, id, arg, searchKey)
    self:_ResetDynamicPackages()
    self.info = nil
    self.id = id
    self.arg = arg
    self.searchKey = searchKey
    self:_FirstTimeInit()
    
    local stateName = arg.stateName
    self.view.emptyStateCtrl:SetState("Normal")
    if stateName == "Stranger" then
        if GameInstance.player.friendSystem.friendInfoDic:ContainsKey(id) then
            stateName = stateName .. "_Friend"
        elseif GameInstance.player.friendSystem:ContainWaitAcceptRequestID(id) then
            stateName = stateName .. "_Wait"
        end
    end
    self:_SetContentState(stateName)
    if self.view.psnInfoBtnForBlackUser then
        self.view.psnInfoBtnForBlackUser.gameObject:SetActiveIfNecessary(false)
    end

    local showInfo = nil
    if stateName == "SpaceshipVisitor" then
        local success, info = GameInstance.player.friendSystem:TryGetFriendInfo(self.id)
        if success and info.init then
            showInfo = info
        else
            logger.info("未找到好友数据 " .. self.id)
            self:_SetEmptyState("NoData")
            return
        end
    else
        local success, info = GameInstance.player.friendSystem:GetDictInfo(arg.infoDicIndex):TryGetValue(self.id)
        if not success then
            logger.info("未找到好友数据 " .. self.id)
            local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
            if GameInstance.player.spaceship.isViewingFriend and friendInfo and friendInfo.roleId == self.id then
                self:_SetEmptyState("NoData_Spaceship")
            else
                self:_SetEmptyState("NoData")
            end
            return
        end
        showInfo = info
    end

    if showInfo.init == false then
        logger.error("好友数据未初始化 " .. self.id)
    end

    self.info = showInfo
    self:_RefreshFriendCellInfo()
    
    if FriendUtils.isPsnPlatform() and self.info.lastLoginType ~= CS.Proto.HG_THIRD_ACCOUNT_TYPE.AccountTypePsn then
        self.view.commonPlayerHead.view.pcNode.gameObject:SetActiveIfNecessary(true)
        self.view.commonPlayerHead.view.psRoot.gameObject:SetActiveIfNecessary(false)
    end
    if self.view.msgBtn and self.view.msgBtn.gameObject.activeSelf then
        self.view.msgBtn.gameObject:SetActive(GameInstance.player.friendSystem:PlayerInBlackList(self.info.roleId) == false)
    end
end

FriendListCell.RefreshFriendListCellByPsnId = HL.Method(HL.String, HL.Table, HL.String) << function(self, id, arg, searchKey)
    self:_ResetDynamicPackages()
    self.info = nil
    self.arg = arg
    self.searchKey = searchKey
    
    local stateName = arg.stateName
    self.view.emptyStateCtrl:SetState("Normal")

    local success, info = GameInstance.player.friendSystem:GetPsnDictByIndex(self.arg.infoDicIndex):TryGetValue(id)

    if not success then
        logger.error(CS.Beyond.ELogChannel.Friend, "未找到好友数据 " .. id)
        self:_SetEmptyState("NoData")
        return
    end
    self.id = info.roleId
    self:_FirstTimeInit()
    
    if stateName == "Normal" then
        
        if info.roleId == 0 then
            self:_UpdateUnRegisterPlayer(info)
            return
        end
        
        
        if GameInstance.player.friendSystem.blackListInfoDic:ContainsKey(info.roleId) then
            stateName = "BlackList"
        elseif GameInstance.player.friendSystem:ContainWaitAcceptRequestID(info.roleId) then
            stateName = "Stranger_Wait"
        elseif not GameInstance.player.friendSystem.friendInfoDic:ContainsKey(info.roleId) then
            stateName = "Stranger"
        end
    elseif stateName == "BlackList" and info.roleId == 0 then
        self:_UpdateUnRegisterPlayer(info)
        self.view.playerHeadBtnForNoGameUser.enabled = false
        if self.view.psnInfoBtnForBlackUser then
            self.view.psnInfoBtnForBlackUser.gameObject:SetActiveIfNecessary(false)
        end
        self.view.psnInfoBtnForNoGameUser.gameObject:SetActiveIfNecessary(false)
        return
    end
    self:_SetContentState(stateName)
    if self.view.addFriendBtn then
        self.view.addFriendBtn.onClick:ChangeBindingPlayerAction("friend_add_psn")
    end
    if self.view.psnInfoBtnForBlackUser then
        self.view.psnInfoBtnForBlackUser.gameObject:SetActiveIfNecessary(false)
    end
    self.info = info
    self:_RefreshFriendCellInfo()
    if stateName == "BlackList" then
        
        self.view.removeBlackListBtn.gameObject:SetActiveIfNecessary(false)
    end
    if self.view.msgBtn and self.view.msgBtn.gameObject.activeSelf then
        self.view.msgBtn.gameObject:SetActive(not GameInstance.player.spaceship.isViewingFriend)
    end
end

FriendListCell._UpdateUnRegisterPlayer = HL.Method(HL.Any) << function(self, info)
    
    self:_SetEmptyState("NonGameUser")
    self.view.sonyNameTxt.text = info.psName
    self.info = info
    
    self.view.commonPlayerHead.view.levelTag.gameObject:SetActiveIfNecessary(false)
    self.view.commonPlayerHead.view.seasonTag.gameObject:SetActiveIfNecessary(false)
    self.view.commonPlayerHead.view.lineImage.gameObject:SetActiveIfNecessary(false)
    self.view.playerHeadBtnForNoGameUser.enabled = true
    self.view.playerHeadBtnForNoGameUser.onClick:RemoveAllListeners()
    self.view.playerHeadBtnForNoGameUser.onClick:AddListener(function()
        
        if GameInstance.player.friendSystem.psnBlackListFriendList:ContainsKey(self.info.psnData.AccountId) then
            return
        end

        local args = {
            transform = self.view.headRectTransform,
            cellHeight = FriendUtils.CELL_HEIGHT,
            actions = {
                [1] = {
                    text = Language.LUA_FRIEND_TIP_PSN_INFO,
                    action = function()
                        FriendUtils.FRIEND_CELL_INIT_FUNC.onPsnInfoClick(self.info.psnData.AccountId)
                    end
                }
            }
        }
        Notify(MessageConst.SHOW_NAVI_TARGET_ACTION_MENU, args)
    end)
end

FriendListCell._RefreshFriendCellInfo = HL.Method() << function(self)
    if not self.info then
        return
    end
    self.charInfos = {}

    self.view.commonPlayerHead:UpdateHideSignature(self.arg.hideSignature)

    local hasValue, _ = GameInstance.player.spaceship:TryGetRoom(Tables.spaceshipConst.guestRoomId)
    local showShipBtn = self.view.shipBtn and hasValue and self.view.shipBtn.gameObject.activeSelf or false
    if self.view.shipBtn then
        self.view.shipBtn.gameObject:SetActiveIfNecessary(showShipBtn)
    end

    local onPlayerHeadClick = self.arg.onPlayerClick and function()
        if self.arg.stateName == "SpaceshipClueGift" then
            if self.arg.onPlayerClick then
                self.arg.onPlayerClick(self.info.roleId)
            end
            return
        end

        
        local isBlack = GameInstance.player.friendSystem.blackListInfoDic:ContainsKey(self.info.roleId)
        if isBlack then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FRIEND_IN_BLACK_LIST)
            return
        end
        local isStranger = not GameInstance.player.friendSystem.friendInfoDic:ContainsKey(self.info.roleId)

        local seasonTag = self.view.commonPlayerHead.view.seasonTag
        local levelTag = self.view.commonPlayerHead.view.levelTag
        local recordTipsTransform = seasonTag.gameObject.activeInHierarchy and seasonTag.transform
            or levelTag.gameObject.activeInHierarchy and levelTag.transform
            or self.view.headRectTransform

        if isStranger then
            FriendUtils.FRIEND_CELL_INIT_FUNC.onStrangerPlayerClick(self.view.headRectTransform, self.info.roleId, self.showCharInfoCallBack, nil, recordTipsTransform)
        else
            local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
            local lshowShipBtn = friendInfo ~= nil and friendInfo.roleId ~= self.info.roleId and showShipBtn and self.info.guestRoomUnlock
            FriendUtils.FRIEND_CELL_INIT_FUNC.onFriendPlayerClick(self.view.headRectTransform, self.info.roleId, self.showCharInfoCallBack, lshowShipBtn, recordTipsTransform)
        end
    end or false

    self.view.commonPlayerHead:InitCommonPlayerHeadByRoleId(self.info.roleId, onPlayerHeadClick, self.searchKey, false)

    if self.arg.showVisitorTimeText then
        self.view.visitorState.gameObject:SetActive(true)
        self.view.onlineState.gameObject:SetActive(false)
        self.view.visitorTxt.text = self.arg.showVisitorTimeText
    else
        if self.view.visitorState then
            self.view.visitorState.gameObject:SetActive(false)
        end
        self.view.onlineState.gameObject:SetActive(true)
    end

    self.view.onlineState:SetState(self.info.playerOnlineState:ToString())
    if self.info.playerOnlineState == CS.Beyond.Gameplay.PlayerOnlineState.Online then
        self.view.onlineTimeTxt.text = Language.LUA_FRIEND_ONLINE
    elseif self.info.lastDateTime ~= 0 then
        self.view.onlineTimeTxt.text = string.format(Language.LUA_FRIEND_LAST_ONLINE_TIME, UIUtils.getLeftTime(DateTimeUtils.GetCurrentTimestampBySeconds() - self.info.lastDateTime))
    else
        self.view.onlineTimeTxt.text = ""
    end

    self.charCellList = {}
    self.charInstanceIdList = {}
    for i = 1, FriendUtils.FriendShowCharsCount do
        local state = self.view.charInfoGroup["charCellRoot" .. i]
        local cell = self.view.charInfoGroup["charHeadCell" .. i]
        
        cell.view.glowAll.gameObject:SetActive(false)
        if i <= self.info.charInfos.Count and self.info.charInfos[CSIndex(i)] then
            local item = self.info.charInfos[CSIndex(i)]
            local charConfig = Tables.characterTable:GetValue(item.templateId)
            self.charInfos[i] = {
                templateId = item.templateId,
                instId = item.instId,
                level = item.level,
                ownTime = 0,
                rarity = charConfig.rarity,
                potentialLevel = item.potentialLevel,
                noHpBar = true,
                
                singleSelect = false,
                selectIndex = -1,
            }
            self.charInstanceIdList[i] = item.instId
            state:SetState("Normal")
            cell:InitCharFormationHeadCell(self.charInfos[i], function()
                self:_OnCharInfoClick(i)
            end)
            cell:SetMaxPotentialGlow(self.charInfos[i].potentialLevel, self.charInfos[i].rarity)
        else
            self.charInfos[i] = {}
            state:SetState("NoChar")
        end
    end

    local chatInfo = GameInstance.player.friendChatSystem:GetChatInfo(self.info.roleId)
    if chatInfo then
        if chatInfo.unReadNum > 0 then
            if self.view.messageNumNode then
                self.view.messageNumNode.gameObject:SetActive(true)
            end
            if self.view.msgRedDotNumber then
                self.view.msgRedDotNumber.gameObject:SetActive(true)
            end
            
            self:_SetMessageNumText(chatInfo.unReadNum > 99 and "99+" or tostring(chatInfo.unReadNum))
        else
            if self.view.messageNumNode then
                self.view.messageNumNode.gameObject:SetActive(false)
            end
            if self.view.msgRedDotNumber then
                self.view.msgRedDotNumber.gameObject:SetActive(false)
            end
        end
    else
        if self.view.messageNumNode then
            self.view.messageNumNode.gameObject:SetActive(false)
        end
        if self.view.msgRedDotNumber then
            self.view.msgRedDotNumber.gameObject:SetActive(false)
        end
    end

    
    if self.view.shipBtn and self.view.shipBtn.gameObject.activeSelf then
        local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
        if friendInfo and friendInfo.roleId == self.info.roleId then
            self.view.shipBtn.enabled = false
            self.view.shipBtnStateController:SetState("CurState")
            self.view.lockMask.gameObject:SetActive(false)
        elseif not self.info.guestRoomUnlock then
            self.view.shipBtn.enabled = false
            self.view.lockMask.gameObject:SetActive(true)
            self.view.shipBtnStateController:SetState("LockState")
        else
            self.view.shipBtn.enabled = true
            self.view.shipBtnStateController:SetState("NormalState")
            self.view.lockMask.gameObject:SetActive(false)
        end
        local isCurrent = self.info.helpFlag ~= CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.CanHelp and "CompleteState" or "IncompleteState"
        self.view.shipHelp.gameObject:SetActiveIfNecessary(self.info.helpFlag ~= CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.Invalid)
        self.view.shipHelp:SetState(isCurrent)

        local isJoin = GameInstance.player.spaceship:CheckIsJoinFriendClueExchange(self.info.roleId)
        isCurrent = isJoin and "CompleteState" or "IncompleteState"
        self.view.clueExchange.gameObject:SetActiveIfNecessary(self.info.clueFlag or isJoin)
        self.view.clueExchange:SetState(isCurrent)
    end

    if self.info.businessCardTopicId ~= nil then
        local success, topicCfg = Tables.businessCardTopicTable:TryGetValue(self.info.businessCardTopicId)
        if success then
            self.view.themeImg:LoadSprite(UIConst.UI_BUSINESS_CARD_ICON_PATH, topicCfg.id)
            self.view.themeImagePair.color = UIUtils.getColorByString(topicCfg.color)
        else
            logger.error("未找到名片主题配置 " .. self.info.businessCardTopicId)
        end
    else
        logger.error("好友名片主题ID为空 " .. self.info.roleId)
    end

    if self.arg.stateName == "SpaceshipClueGift" then
        self:_UpdateClueCells()
    end

    
    self.view.commonPlayerHead:UpdateActivityState()
end

FriendListCell._UpdateClueCells = HL.Method() << function(self)
    self.m_clueCells = self.m_clueCells or UIUtils.genCellCache(self.view.clueNode)

    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local clueDict = {}
    for key, value in pairs(self.info.hostClueStatus) do
        if value == 0 or value > curTime then
            clueDict[key] = true
        end
    end

    self.m_clueCells:Refresh(7, function(cell, luaIndex)
        if self.arg.selectedClueId == luaIndex then
            if clueDict[luaIndex] == true then
                
                cell.stateController:SetState("Select01")
            else
                cell.stateController:SetState("Select02")
            end
        else
            if clueDict[luaIndex] == true then
                cell.stateController:SetState("NotNeed")
            else
                cell.stateController:SetState("Need")
            end
        end

        cell.clueNumTxt.text = luaIndex
    end)
end

FriendListCell._OnCharInfoClick = HL.Method(HL.Number) << function(self, cellIndex)
    if GameInstance.player.friendSystem:PlayerInBlackList(self.info.roleId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FRIEND_IN_BLACK_LIST)
        return
    end
    local templateIdList = {}
    for _, v in pairs(self.charInfos) do
        table.insert(templateIdList, v.templateId)
    end
    FriendUtils.openFriendCharInfo(self.info.roleId, self.info.charInfos[CSIndex(cellIndex)].templateId, templateIdList)
end

FriendListCell._OnEnable = HL.Override() << function(self)
    if not self.info then
        return
    end
    local chatInfo = GameInstance.player.friendChatSystem:GetChatInfo(self.info.roleId)
    if chatInfo then
        if chatInfo.unReadNum > 0 then
            if self.view.messageNumNode then
                self.view.messageNumNode.gameObject:SetActive(true)
            end
            if self.view.msgRedDotNumber then
                self.view.msgRedDotNumber.gameObject:SetActive(true)
            end
            
            self:_SetMessageNumText(chatInfo.unReadNum > 99 and "99+" or tostring(chatInfo.unReadNum))
        else
            if self.view.messageNumNode then
                self.view.messageNumNode.gameObject:SetActive(false)
            end
            if self.view.msgRedDotNumber then
                self.view.msgRedDotNumber.gameObject:SetActive(false)
            end
        end
    else
        if self.view.messageNumNode then
            self.view.messageNumNode.gameObject:SetActive(false)
        end
        if self.view.msgRedDotNumber then
            self.view.msgRedDotNumber.gameObject:SetActive(false)
        end
    end
end

HL.Commit(FriendListCell)
return FriendListCell

