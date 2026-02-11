local SocialBuildingSource = CS.Beyond.Gameplay.Factory.SocialBuildingSource

local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailSocialBuilding


















MapMarkDetailSocialBuildingCtrl = HL.Class('MapMarkDetailSocialBuildingCtrl', uiCtrl.UICtrl)






MapMarkDetailSocialBuildingCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FAC_SOCIAL_BUILDING_RECEIVED] = "_OnFacSocialBuildingReceived",
    [MessageConst.ON_FAC_RECEIVED_SOCIAL_BUILDING_DATA_UPDATED] = "_OnFacReceivedSocialBuildingDataUpdated",
}


MapMarkDetailSocialBuildingCtrl.m_existing = HL.Field(HL.Boolean) << false


MapMarkDetailSocialBuildingCtrl.m_markRuntimeData = HL.Field(HL.Userdata)


MapMarkDetailSocialBuildingCtrl.m_nodeId = HL.Field(HL.Number) << -1


MapMarkDetailSocialBuildingCtrl.m_social = HL.Field(CS.Beyond.Gameplay.RemoteFactory.ServerChapterInfo.ComponentHandler.Payload_Social)


MapMarkDetailSocialBuildingCtrl.m_isOthersSocialBuilding = HL.Field(HL.Boolean) << false


MapMarkDetailSocialBuildingCtrl.m_ownerId = HL.Field(HL.Number) << -1





MapMarkDetailSocialBuildingCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local markInstId = arg.markInstId
    local commonArgs = {
        markInstId = markInstId,
        bigBtnActive = true,
    }

    local _, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(markInstId)
    self.m_markRuntimeData = markRuntimeData
    local nodeId = markRuntimeData.nodeId
    self.m_existing = nodeId ~= nil
    if self.m_existing then
        
        self.m_nodeId = nodeId
        local social, source = FactoryUtils.getSocialBuildingDetails(nodeId, self.m_markRuntimeData.chapterId)
        self.m_social = social
        self.m_isOthersSocialBuilding = source == SocialBuildingSource.Others
        self.m_ownerId = source == SocialBuildingSource.Mine and GameInstance.player.roleId or social.ownerId
    else
        
        self.m_isOthersSocialBuilding = true
        self.m_ownerId = markRuntimeData.ownerId
        
        commonArgs.bigBtnCallback = function()
            self:_ReceiveSocialBuilding()
        end
        commonArgs.bigBtnText = Language.LUA_MAP_MARK_DETAIL_SOCIAL_BUILDING_RECEIVE_BTN_TEXT
        commonArgs.bigBtnIconName = UIConst.MAP_DETAIL_BTN_ICON_NAME.TELEPORT
    end

    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon(commonArgs)
end



MapMarkDetailSocialBuildingCtrl.OnShow = HL.Override() << function(self)
    self:_UpdateView()
end



MapMarkDetailSocialBuildingCtrl._UpdateView = HL.Method() << function(self)
    local active = self.m_isOthersSocialBuilding
    self.view.receiveSocialBuildingTips.gameObject:SetActive(false)
    self.view.sourceNode.gameObject:SetActive(false)
    self.view.stabilityNode.gameObject:SetActive(active)

    if active then
        self:_UpdateSocialBuildingView()
    end
end



MapMarkDetailSocialBuildingCtrl._UpdateSocialBuildingView = HL.Method() << function(self)
    
    local ownerId = self.m_ownerId
    if self.m_existing and self.m_social.preset then
        
        local success, npcData = Tables.factorySocialBuildingNpcTable:TryGetValue(ownerId)
        if not success then
            logger.error("[MapMarkDetail] SocialBuilding: Npc data not found, npcId: " .. tostring(ownerId))
            return
        end

        self.view.sourceNode.gameObject:SetActive(true)
        self.view.npcCell.gameObject:SetActive(true)
        self.view.contactFriendCell.gameObject:SetActive(false)

        self.view.npcCell.playerHead:InitCommonPlayerHead(npcData.avatarPath, npcData.avatarFramePath,
            false, 0, npcData.name, nil)
    else
        
        GameInstance.player.friendSystem:SyncSocialFriendInfo({ ownerId }, function()
            if self.m_isClosed then
                return
            end
            local success, ownerInfo = GameInstance.player.friendSystem:TryGetFriendInfo(ownerId)
            if not success then
                logger.info("[MapMarkDetail] SocialBuilding: Owner info not found, roleId: " .. tostring(ownerId))
                return 
            end

            self.view.sourceNode.gameObject:SetActive(true)
            self.view.npcCell.gameObject:SetActive(false)
            self.view.contactFriendCell.gameObject:SetActive(true)

            self.view.contactFriendCell:InitContactFriendCell(ownerId, ownerInfo, 0, nil)
            local onClickAvatar = FriendUtils.FRIEND_CELL_HEAD_FUNC.BUSINESS_CARD_PHASE(ownerId).action
            self.view.contactFriendCell.view.playerHead:SetClick(onClickAvatar)
        end)
    end

    if self.m_existing then
        
        self.view.stabilityTitleText.text = Language.LUA_MAP_MARK_DETAIL_SOCIAL_BUILDING_STABILITY_TITLE
        local stabilityValue = FactoryUtils.getSocialBuildingStability(self.m_nodeId, self.m_markRuntimeData.chapterId)
        self.view.stabilityValueText.text = string.format("%.0f%%", stabilityValue * 100)
    else
        
        local remoteFactorySystem = GameInstance.player.remoteFactory
        self.view.stabilityTitleText.text = Language.LUA_MAP_MARK_DETAIL_SOCIAL_BUILDING_RECEPTION_TITLE
        local buildingCount = remoteFactorySystem.receivedSocialBuildingCount
        local buildingMaxCount = remoteFactorySystem.receivedSocialBuildingMaxCount
        local isBuildingReceivable = buildingCount < buildingMaxCount
        local receptionValueTextFormat = isBuildingReceivable
            and "%s/%s"
            or Language.LUA_MAP_MARK_DETAIL_SOCIAL_BUILDING_RECEPTION_VALUE_LIMIT
        self.view.stabilityValueText.text = string.format(receptionValueTextFormat, buildingCount, buildingMaxCount)
        self.view.receiveSocialBuildingTips.gameObject:SetActive(not isBuildingReceivable)
    end
end



MapMarkDetailSocialBuildingCtrl._ReceiveSocialBuilding = HL.Method() << function(self)
    
    local remoteFactorySystem = GameInstance.player.remoteFactory
    local buildingCount = remoteFactorySystem.receivedSocialBuildingCount
    local buildingMaxCount = remoteFactorySystem.receivedSocialBuildingMaxCount
    local isBuildingReceivable = buildingCount < buildingMaxCount
    if isBuildingReceivable then
        
        self:_SendReceiveSocialBuilding()
    else
        
        UIManager:Open(PanelId.BuildingSharePop, {
            onClickReplace = function(buildingLevelId, buildingNodeId, buildingOwnerId)
                self:_SendReceiveSocialBuilding(buildingLevelId, buildingNodeId, buildingOwnerId)
            end
        })
    end
end






MapMarkDetailSocialBuildingCtrl._SendReceiveSocialBuilding = HL.Method(HL.Opt(HL.String, HL.Number, HL.Number))
    << function(self, buildingLevelId, buildingNodeId, buildingOwnerId)
    local markRuntimeData = self.m_markRuntimeData
    local chatRoleId = markRuntimeData.chatRoleId
    local chatMsgIndex = markRuntimeData.chatMsgIndex
    if buildingLevelId and buildingNodeId and buildingOwnerId then
        GameInstance.player.friendChatSystem:SendReceiveSocialBuilding(chatRoleId, chatMsgIndex, buildingLevelId, buildingNodeId, buildingOwnerId)
    else
        GameInstance.player.friendChatSystem:SendReceiveSocialBuilding(chatRoleId, chatMsgIndex)
    end
end



MapMarkDetailSocialBuildingCtrl._OnFacSocialBuildingReceived = HL.Method() << function(self)
    Notify(MessageConst.SHOW_TOAST, Language.LUA_FRIEND_RECEIVE_SOCIAL_BUILDING_SUCCESS)
end




MapMarkDetailSocialBuildingCtrl._OnFacReceivedSocialBuildingDataUpdated = HL.Method(HL.Table) << function(self, args)
    
    
    

    if self.m_existing then
        return 
    end

    local markRuntimeData = self.m_markRuntimeData
    local ownerId = markRuntimeData.ownerId
    local levelId = markRuntimeData.levelId
    local ownerNodeId = markRuntimeData.ownerNodeId
    local received, socialBuildingInfo = GameInstance.player.remoteFactory:IsSocialBuildingReceived(ownerId, levelId, ownerNodeId)
    if not received then
        return 
    end

    
    local chapterId = socialBuildingInfo.chapterId
    local nodeId = socialBuildingInfo.nodeId
    local success, markInstId = GameInstance.player.mapManager:GetFacMarkInstIdByNodeId(chapterId, nodeId)
    if not success then
        logger.error("[SocialBuilding] Fac mark inst id not found, nodeId: " .. tostring(nodeId))
        return
    end

    
    GameInstance.player.mapManager:RemoveSocialBuildingMarks()
    MapUtils.openMap(markInstId, levelId)
end



MapMarkDetailSocialBuildingCtrl.OnClose = HL.Override() << function(self)
    GameInstance.player.friendSystem:ClearSyncCallback()
end

HL.Commit(MapMarkDetailSocialBuildingCtrl)
