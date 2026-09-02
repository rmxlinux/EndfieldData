local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonRanking
local PHASE_ID = PhaseId.CommonRanking

local IdentityTypeState = {
    Self = "Self",
    Other = "Other",
    NPC = "NPC",
}

local RankingState = {
    Ranking1st = "Ranking1st",
    Ranking2nd = "Ranking2nd",
    Ranking3rd = "Ranking3rd",
    RankingHigh = "RankingHigh",
    RankingNormal = "RankingNormal",
}

local PanelState = {
    Normal = "Nrl",
    Loading = "Loading",
}

local LocateSelfAnim = "activityrankinglistcellplayer_in"

local floorRankValueConverter = function(value)
    return math.floor(value / 1000)
end

CommonRankingCtrl = HL.Class('CommonRankingCtrl', uiCtrl.UICtrl)

CommonRankingCtrl.m_rankListId = HL.Field(HL.String) << ""

CommonRankingCtrl.m_rankRelatedId = HL.Field(HL.String) << ""

CommonRankingCtrl.m_genRankListCellFunc = HL.Field(HL.Function)

CommonRankingCtrl.m_rankInfo = HL.Field(HL.Table)

CommonRankingCtrl.m_selfRankInfo = HL.Field(HL.Table)

CommonRankingCtrl.m_rankInfoReady = HL.Field(HL.Boolean) << false

CommonRankingCtrl.m_roleSimpleInfoReady = HL.Field(HL.Boolean) << false

CommonRankingCtrl.m_scrollToSelfTag = HL.Field(HL.Boolean) << false





CommonRankingCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_COMMON_RANK_DATA_CHANGED] = 'OnCommonRankDataChanged',
    [MessageConst.ON_FRIEND_INFO_SYNC] = "OnFriendInfoSync",
}


CommonRankingCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self:_InitData(arg)
    self:_InitView()
end

CommonRankingCtrl.OnClose = HL.Override() << function(self)
    GameInstance.player.friendSystem:ClearSyncCallback()
end

CommonRankingCtrl.OnCommonRankDataChanged = HL.Method(HL.Table) << function(self, args)
    local uniqueId = unpack(args)
    if uniqueId ~= self.m_rankListId then
        return
    end

    self.m_rankInfoReady = true
    self:_TryRefresh()
end

CommonRankingCtrl.OnFriendInfoSync = HL.Method() << function(self)
    self.m_roleSimpleInfoReady = true
    self:_TryRefresh()
end

CommonRankingCtrl._InitUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnClickBtnClose()
    end)

    self.view.activityRankingScrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_OnUpdateCellRankingCell(go, csIndex)
    end)

    self.view.activityRankingScrollList.onScrollEnd:AddListener(function()
        self:_OnScrollEndRankingScrollList()
    end)

    self.m_genRankListCellFunc = UIUtils.genCachedCellFunction(self.view.activityRankingScrollList)

    if not DeviceInfo.usingController then
        return
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

CommonRankingCtrl._InitData = HL.Method(HL.Table) << function(self, args)
    self.m_rankListId = args.rankListId
    self.m_rankRelatedId = args.rankRelatedId
end

CommonRankingCtrl._InitView = HL.Method() << function(self)
    self.view.main:SetState(PanelState.Loading)

    local commonRankInfoCfg = Tables.commonRankInfoTable[self.m_rankListId]
    self.view.main:SetState(commonRankInfoCfg.rankValueStyleType:ToString())

    GameInstance.player.commonRankSystem:RequestCommonFriendRank(self.m_rankListId)
    GameInstance.player.friendSystem:SyncFriendSimpleInfo()
end

CommonRankingCtrl._RefreshData = HL.Method() << function(self)
    self.m_rankInfo = {}
    self.m_selfRankInfo = {}

    local succ, commonRankInfoCfg = Tables.commonRankInfoTable:TryGetValue(self.m_rankListId)
    if succ then
        local rankList = GameInstance.player.commonRankSystem:GetFriendRankList(self.m_rankListId)
        if rankList then
            for i = 0, rankList.Count - 1 do
                local friendRankInfo = rankList[i]
                local friendSucc, _ = GameInstance.player.friendSystem:TryGetFriendInfo(friendRankInfo.roleId)
                if friendSucc then
                    table.insert(self.m_rankInfo, {
                        roleId = friendRankInfo.roleId,
                        rankValue = friendRankInfo.value,
                        style = commonRankInfoCfg.rankValueStyleType,
                    })
                end
            end
        end

        local npcSucc, npcRankInfoData = Tables.commonNPCRankInfoTable:TryGetValue(self.m_rankRelatedId)
        if npcSucc and npcRankInfoData.npcList then
            for i = 0, npcRankInfoData.npcList.Count - 1 do
                local npcInfo = npcRankInfoData.npcList[i]
                table.insert(self.m_rankInfo, {
                    headIcon = npcInfo.headIcon,
                    npcName = npcInfo.name,
                    npcTopicId = npcInfo.topicId,
                    rankValue = npcInfo.rankValue,
                    style = commonRankInfoCfg.rankValueStyleType,
                })
            end
        end
    else
        logger.warn("没有通用排行榜数据：", self.m_rankListId)
    end

    table.sort(self.m_rankInfo, Utils.genSortFunction({ "rankValue" }, commonRankInfoCfg.isIncremental))

    local selfInfo = GameInstance.player.friendSystem.SelfInfo
    for luaIndex, rankInfo in ipairs(self.m_rankInfo) do
        if rankInfo.roleId == selfInfo.roleId then
            self.m_selfRankInfo.rankLuaIndex = luaIndex
            self.m_selfRankInfo.rankValue = rankInfo.rankValue
        end
    end
end

CommonRankingCtrl._RefreshView = HL.Method() << function(self)
    self.view.main:SetState(PanelState.Normal)
    self.view.activityRankingScrollList:UpdateCount(#self.m_rankInfo)
    self:_RefreshSelfInfo()
end

CommonRankingCtrl._TryRefresh = HL.Method() << function(self)
    if not self.m_rankInfoReady then
        return
    end

    if not self.m_roleSimpleInfoReady then
        return
    end

    self:_RefreshData()
    self:_RefreshView()

    if not DeviceInfo.usingController then
        return
    end

    local cell = self.m_genRankListCellFunc(1)
    self:SetNaviTarget(cell.inputBindingGroupNaviDecorator)
end

CommonRankingCtrl._OnClickBtnClose = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end

CommonRankingCtrl._OnUpdateCellRankingCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_genRankListCellFunc(go)
    local luaIndex = LuaIndex(csIndex)
    local rankInfo = self.m_rankInfo[luaIndex]

    local identityTypeState = IdentityTypeState.Other
    local rankValueState = self:_GetRankingStateByRanking(luaIndex)
    local topicId = ""
    local isPlayer = not string.isEmpty(rankInfo.roleId)
    if isPlayer then
        local _, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(rankInfo.roleId)
        local isSelf = friendInfo.roleType == CS.Beyond.Gameplay.RoleType.Self
        if friendInfo.playerOnlineState == CS.Beyond.Gameplay.PlayerOnlineState.Online then
            cell.onlineTimeTxt.text = Language.LUA_FRIEND_ONLINE
        elseif friendInfo.lastDateTime ~= 0 then
            local passTime = DateTimeUtils.GetCurrentTimestampBySeconds() - friendInfo.lastDateTime
            cell.onlineTimeTxt.text = string.format(Language.LUA_FRIEND_LAST_ONLINE_TIME, UIUtils.getLeftTime(passTime))
        else
            cell.onlineTimeTxt.text = ""
        end

        topicId = friendInfo.businessCardTopicId
        identityTypeState = isSelf and IdentityTypeState.Self or IdentityTypeState.Other
        cell.onlineState:SetState(friendInfo.playerOnlineState:ToString())
        cell.commonPlayerHead:InitCommonPlayerHeadByRoleId(rankInfo.roleId, function()
            FriendUtils.FRIEND_CELL_HEAD_FUNC.BUSINESS_CARD_PHASE(rankInfo.roleId).action()
        end)
    else
        local avatarPath = string.format("%s/%s", UIConst.UI_SPRITE_CHAR_REMOTE_ICON, rankInfo.headIcon)
        topicId = rankInfo.npcTopicId
        identityTypeState = IdentityTypeState.NPC
        cell.commonPlayerHead:UpdateHideLevelTxt(true)
        cell.commonPlayerHead:UpdateHidePlatformNode(true)
        cell.commonPlayerHead:InitCommonPlayerHead(avatarPath, "", false, 0, rankInfo.npcName)
    end

    cell.timeTxt.text = UIUtils.getLeftTimeToSecond(floorRankValueConverter(rankInfo.rankValue or 0))
    cell.rankingTxt.text = luaIndex
    cell.stateController:SetState(identityTypeState)
    cell.stateController:SetState(rankValueState)
    cell.stateController:SetState(rankInfo.style:ToString())

    local success, topicCfg = Tables.businessCardTopicTable:TryGetValue(topicId)
    if success then
        cell.themeImg:LoadSprite(UIConst.UI_BUSINESS_CARD_ICON_PATH, topicCfg.id)
    else
        logger.error("未找到名片主题配置:", topicId)
    end
end

CommonRankingCtrl._GetRankingStateByRanking = HL.Method(HL.Number).Return(HL.String) << function(self, ranking)
    local rankingState = RankingState.RankingNormal
    if ranking == 1 then
        rankingState = RankingState.Ranking1st
    elseif ranking == 2 then
        rankingState = RankingState.Ranking2nd
    elseif ranking == 3 then
        rankingState = RankingState.Ranking3rd
    elseif ranking < 10 then
        rankingState = RankingState.RankingHigh
    end
    return rankingState
end

CommonRankingCtrl._RefreshSelfInfo = HL.Method() << function(self)
    local selfInfo = GameInstance.player.friendSystem.SelfInfo
    local selfNode = self.view.activityRankingSelfCell
    selfNode.commonPlayerHead:InitCommonPlayerHeadByRoleId(selfInfo.roleId, false)

    selfNode.onlineState:SetState(CS.Beyond.Gameplay.PlayerOnlineState.Online:ToString())
    selfNode.onlineTimeTxt.text = Language.LUA_FRIEND_ONLINE

    local selfRankLuaIndex = self.m_selfRankInfo.rankLuaIndex
    selfNode.rankingTxt.text = selfRankLuaIndex or "-"
    selfNode.timeTxt.text = self.m_selfRankInfo.rankValue and
            UIUtils.getLeftTimeToSecond(floorRankValueConverter(self.m_selfRankInfo.rankValue)) or "--:--"

    selfNode.stateController:SetState(IdentityTypeState.Self)
    local rankValueState = selfRankLuaIndex and self:_GetRankingStateByRanking(selfRankLuaIndex) or RankingState.RankingNormal
    selfNode.stateController:SetState(rankValueState)

    local commonRankInfoCfg = Tables.commonRankInfoTable[self.m_rankListId]
    selfNode.stateController:SetState(commonRankInfoCfg.rankValueStyleType:ToString())

    local success, topicCfg = Tables.businessCardTopicTable:TryGetValue(selfInfo.businessCardTopicId)
    if success then
        selfNode.themeImg:LoadSprite(UIConst.UI_BUSINESS_CARD_ICON_PATH, topicCfg.id)
    else
        logger.error("未找到名片主题配置:", selfInfo.businessCardTopicId)
    end

    selfNode.jumpBtn.onClick:RemoveAllListeners()
    selfNode.jumpBtn.onClick:AddListener(function()
        self:_OnClickSelfJumpBtn()
    end)
end

CommonRankingCtrl._OnClickSelfJumpBtn = HL.Method() << function(self)
    if not self.m_selfRankInfo.rankLuaIndex then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_RANKING_JUMP_TO_SELF_FAIL)
        return
    end

    local luaIndex = self.m_selfRankInfo.rankLuaIndex
    local fastMode = DeviceInfo.usingController
    self.m_scrollToSelfTag = not fastMode
    self.view.activityRankingScrollList:ScrollToIndex(CSIndex(luaIndex), fastMode)

    if fastMode then
        local cell = self.m_genRankListCellFunc(luaIndex)
        self:SetNaviTarget(cell.inputBindingGroupNaviDecorator)
        self:_PlayLocateSelfAnim()
    end
end

CommonRankingCtrl._OnScrollEndRankingScrollList = HL.Method() << function(self)
    if not self.m_scrollToSelfTag then
        return
    end
    self.m_scrollToSelfTag = false

    self:_PlayLocateSelfAnim()
end

CommonRankingCtrl._PlayLocateSelfAnim = HL.Method() << function(self)
    local luaIndex = self.m_selfRankInfo.rankLuaIndex
    local rankCell = self.m_genRankListCellFunc(luaIndex)
    if not rankCell then
        logger.error("CommonRankingCtrl._PlayLocateSelfAnim cant get rankCell, rankIndex:", luaIndex)
        return
    end
    rankCell.animationWrapper:Play(LocateSelfAnim)
end

HL.Commit(CommonRankingCtrl)
