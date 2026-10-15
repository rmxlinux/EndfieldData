
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SocializeVisitTips
local ONE_DAY_SECONDS = 24 * 60 * 60
local FAST_VISIT_DEBUG_LOG = false
local FAST_VISIT_LOG_PREFIX = "[SocializeVisitTips][FastVisit]"

SocializeVisitTipsCtrl = HL.Class('SocializeVisitTipsCtrl', uiCtrl.UICtrl)

SocializeVisitTipsCtrl.m_isInit = HL.Field(HL.Boolean) << false
SocializeVisitTipsCtrl.m_waitingPlayAnimationAfterLoading = HL.Field(HL.Boolean) << false
SocializeVisitTipsCtrl.m_nextFriendRoleId = HL.Field(HL.Number) << 0
SocializeVisitTipsCtrl.m_isSearchingNextFriend = HL.Field(HL.Boolean) << false
SocializeVisitTipsCtrl.m_nextFriendCandidate = HL.Field(HL.Table)

SocializeVisitTipsCtrl.s_pendingVisit = HL.StaticField(HL.Table)





SocializeVisitTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FRIEND_INFO_SYNC] = '_OnFriendInfoSync',
    [MessageConst.ON_FRIEND_SIMPLE_INFO_SYNC] = '_OnFriendSimpleInfoSync',
    [MessageConst.ON_FRIEND_CELL_INFO_CHANGE] = '_RefreshNextFriendState',
    [MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE] = '_RefreshNextFriendState',
    [MessageConst.ON_SPACESHIP_JOIN_FRIEND_INFO_EXCHANGE] = '_OnVisitActionChanged',
    [MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY] = '_OnVisitActionChanged',
    [MessageConst.ON_SPACESHIP_HELP_ROOM] = '_OnVisitActionChanged',
    [MessageConst.ON_SPACESHIP_VISIT_FRIEND] = '_OnSpaceshipVisitFriend',
    [MessageConst.ON_IN_MAIN_HUD_CHANGED] = '_OnInMainHudChanged',
    [MessageConst.ON_UI_PANEL_CLOSED] = '_OnPanelClosed',
}


SocializeVisitTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.m_isInit = InputManagerInst.inChangingInputDevice
    self.view.visitNextFriendNode.clickBtn.onClick:AddListener(function()
        self:_OnVisitNextFriendClick()
    end)
end

SocializeVisitTipsCtrl.OnCellChange = HL.Method() << function(self)
    local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
    if friendInfo and friendInfo.roleId ~= 0 then
        self.view.socializeFriendName:InitSocializeFriendName(friendInfo.roleId)
    end
    self:_LogFastVisit("OnCellChange_RequestSimple", {
        currentRoleId = friendInfo ~= nil and friendInfo.roleId or 0,
    })
    self.m_isSearchingNextFriend = true
    self:_RefreshNextFriendState()
    GameInstance.player.friendSystem:SyncFriendSimpleInfo()
    GameInstance.player.spaceship:GetClueInfo()
end

SocializeVisitTipsCtrl._OnVisitNextFriendClick = HL.Method() << function(self)
    if SocializeVisitTipsCtrl.s_pendingVisit or UIManager:IsShow(PanelId.Loading)
        or not GameWorld.worldInfo.inMainHud then
        return
    end
    if self.m_isSearchingNextFriend or not self:_CanVisitNextFriendCandidate(self.m_nextFriendCandidate) then
        self:_LogFastVisit("Click_Blocked", {
            isSearching = self.m_isSearchingNextFriend,
            candidate = self:_GetFastVisitCandidateLogInfo(self.m_nextFriendCandidate),
        })
        return
    end
    self:_LogFastVisit("Click_VisitFriend", {
        targetRoleId = self.m_nextFriendRoleId,
        candidate = self:_GetFastVisitCandidateLogInfo(self.m_nextFriendCandidate),
    })
    local pending = { roleId = self.m_nextFriendRoleId, player = GameInstance.player }
    SocializeVisitTipsCtrl.s_pendingVisit = pending
    self:_RefreshNextFriendState()
    GameInstance.player.spaceship:VisitFriendSpaceShip(pending.roleId, function()
        SocializeVisitTipsCtrl._FinishPendingVisit(pending)
    end)
end

SocializeVisitTipsCtrl._FinishPendingVisit = HL.StaticMethod(HL.Table) << function(pending)
    if SocializeVisitTipsCtrl.s_pendingVisit ~= pending then
        return
    end
    SocializeVisitTipsCtrl.s_pendingVisit = nil
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl:_RefreshNextFriendState()
    end
end

SocializeVisitTipsCtrl._TryFinishPendingVisit = HL.Method() << function(self)
    local pending = SocializeVisitTipsCtrl.s_pendingVisit
    if not pending then
        return
    end
    if pending.player ~= GameInstance.player then
        SocializeVisitTipsCtrl._FinishPendingVisit(pending)
        return
    end
    local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
    if GameWorld.worldInfo.inMainHud and not UIManager:IsShow(PanelId.Loading)
        and friendInfo and friendInfo.roleId == pending.roleId then
        SocializeVisitTipsCtrl._FinishPendingVisit(pending)
    end
end

SocializeVisitTipsCtrl._RefreshNextFriendState = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if SocializeVisitTipsCtrl.s_pendingVisit or self.m_isSearchingNextFriend then
        self.m_nextFriendCandidate = nil
        self.m_nextFriendRoleId = 0
        self:_RefreshNextFriendActionState(nil)
        self.view.visitNextFriendNode.clickBtn.enabled = false
        self.view.visitNextFriendNode.stateController:SetState("Searching")
        self:_LogFastVisit("RefreshState_Searching")
        return
    end

    local nextFriendCandidate = self:_GetNextFriendCandidate()
    if not self:_CanVisitNextFriendCandidate(nextFriendCandidate) then
        nextFriendCandidate = nil
    end
    self.m_nextFriendCandidate = nextFriendCandidate
    self.m_nextFriendRoleId = self.m_nextFriendCandidate ~= nil and self.m_nextFriendCandidate.roleId or 0
    local canVisitNextFriend = self:_CanVisitNextFriendCandidate(self.m_nextFriendCandidate)
    self.view.visitNextFriendNode.clickBtn.enabled = canVisitNextFriend
    self:_RefreshNextFriendActionState(self.m_nextFriendCandidate)
    self.view.visitNextFriendNode.stateController:SetState(canVisitNextFriend and "FastVisit" or "Empty")
    self:_LogFastVisit("RefreshState_Result", {
        state = canVisitNextFriend and "FastVisit" or "Empty",
        candidate = self:_GetFastVisitCandidateLogInfo(self.m_nextFriendCandidate),
    })
end

SocializeVisitTipsCtrl._OnFriendSimpleInfoSync = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:_LogFastVisit("FriendSimpleSynced")
    self.m_isSearchingNextFriend = false
    self:_RefreshNextFriendState()
end

SocializeVisitTipsCtrl._OnFriendInfoSync = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    if self.m_isSearchingNextFriend then
        self:_LogFastVisit("FriendInfoSynced_SearchFallback")
        self.m_isSearchingNextFriend = false
    end
    self:_RefreshNextFriendState()
end

SocializeVisitTipsCtrl._OnSpaceshipVisitFriend = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local isSelf = false
    if arg then
        isSelf = unpack(arg)
    end
    if isSelf then
        return
    end
    
    self.m_isInit = false
    self.m_waitingPlayAnimationAfterLoading = true
    self:OnCellChange()
end

SocializeVisitTipsCtrl._OnInMainHudChanged = HL.Method(HL.Any) << function(self, arg)
    local inMainHud = unpack(arg)
    if inMainHud then
        self:_TryFinishPendingVisit()
    end
    if not self.m_waitingPlayAnimationAfterLoading or not inMainHud then
        return
    end
    self:_PlayVisitTipsAnimation()
end

SocializeVisitTipsCtrl._OnPanelClosed = HL.Method(HL.String) << function(self, panelName)
    if panelName == "Loading" then
        self:_TryFinishPendingVisit()
    end
end

SocializeVisitTipsCtrl._PlayVisitTipsAnimation = HL.Method() << function(self)
    self.view.animationWrapper:ClearTween()
    if self.m_isInit and not self.m_waitingPlayAnimationAfterLoading then
        self.view.animationWrapper:PlayWithTween("socializevisittips_in_part_2")
        AudioManager.PostEvent("Au_UI_Toast_FriendVisitSide_Open")
    else
        self.view.animationWrapper:PlayWithTween("socializevisittips_in_part_1", function()
            self.m_isInit = true
        end)
        AudioManager.PostEvent("Au_UI_Toast_FriendVisitMain_Open")
    end
    self.m_waitingPlayAnimationAfterLoading = false
end

SocializeVisitTipsCtrl._OnVisitActionChanged = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    
    self:_LogFastVisit("VisitActionChanged_RequestSimple")
    self.m_isSearchingNextFriend = true
    self:_RefreshNextFriendState()
    GameInstance.player.friendSystem:SyncFriendSimpleInfo()
    GameInstance.player.spaceship:GetClueInfo()
end

SocializeVisitTipsCtrl._LogFastVisit = HL.Method(HL.String, HL.Opt(HL.Table)) << function(self, stage, data)
    if not FAST_VISIT_DEBUG_LOG then
        return
    end
    logger.info(FAST_VISIT_LOG_PREFIX, stage, data)
end

SocializeVisitTipsCtrl._GetFastVisitCandidateLogInfo = HL.Method(HL.Opt(HL.Table)).Return(HL.Table) << function(self, candidate)
    if candidate == nil then
        return { isNil = true }
    end
    return {
        roleId = candidate.roleId,
        canExchange = candidate.canExchange,
        canHelp = candidate.canHelp,
        clueFlag = candidate.clueFlag,
        joinedExchange = candidate.joinedExchange,
        helpFlag = tostring(candidate.helpFlag),
        helpedBySelf = candidate.helpedBySelf,
        canHelpRemainingRoom = candidate.canHelpRemainingRoom,
        helpRoomTypeCount = candidate.helpRoomTypeCount,
        totalActionScore = candidate.totalActionScore,
        totalRoomScore = candidate.totalRoomScore,
        activeScore = candidate.activeScore,
        adventureLevel = candidate.adventureLevel,
    }
end

SocializeVisitTipsCtrl._CanVisitNextFriendCandidate = HL.Method(HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, candidate)
    return candidate ~= nil and (candidate.canExchange or candidate.canHelpRemainingRoom)
end

SocializeVisitTipsCtrl._RefreshNextFriendActionState = HL.Method(HL.Opt(HL.Table)) << function(self, candidate)
    if candidate == nil then
        self.view.visitNextFriendNode.clueExchange.gameObject:SetActiveIfNecessary(false)
        self.view.visitNextFriendNode.productionAssistance.gameObject:SetActiveIfNecessary(false)
        return
    end

    local showClueExchange = candidate.clueFlag or candidate.joinedExchange
    self.view.visitNextFriendNode.clueExchange.gameObject:SetActiveIfNecessary(showClueExchange)
    if showClueExchange then
        self.view.visitNextFriendNode.clueExchange:SetState(candidate.joinedExchange and "CompleteState" or "IncompleteState")
    end

    local showProductionAssistance = candidate.helpFlag ~= CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.Invalid
    self.view.visitNextFriendNode.productionAssistance.gameObject:SetActiveIfNecessary(showProductionAssistance)
    if showProductionAssistance then
        local productionAssistanceState = candidate.helpFlag ~= CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.CanHelp
            and "CompleteState" or "IncompleteState"
        self.view.visitNextFriendNode.productionAssistance:SetState(productionAssistanceState)
        if productionAssistanceState == "IncompleteState" and not candidate.canHelp then
            self:_LogFastVisit("RefreshActionState_ShowHelpButCanHelpFalse", {
                candidate = self:_GetFastVisitCandidateLogInfo(candidate),
            })
        end
    end
end

SocializeVisitTipsCtrl._GetNextFriendCandidate = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local friendSystem = GameInstance.player.friendSystem
    local spaceship = GameInstance.player.spaceship
    local clueRemainCount = friendSystem.currentClueShareCount
    local helpRemainCount = friendSystem.currentShipVisitorHelpCount
    if clueRemainCount <= 0 and helpRemainCount <= 0 then
        self:_LogFastVisit("GetCandidate_NoRemainCount", {
            clueRemainCount = clueRemainCount,
            helpRemainCount = helpRemainCount,
        })
        return nil
    end

    local currentRoleId = 0
    local currentFriendInfo = spaceship:GetFriendRoleInfo()
    if currentFriendInfo ~= nil then
        currentRoleId = currentFriendInfo.roleId
    end
    self:_LogFastVisit("GetCandidate_Start", {
        currentRoleId = currentRoleId,
        clueRemainCount = clueRemainCount,
        helpRemainCount = helpRemainCount,
    })

    local bothCandidates = {}
    local exchangeCandidates = {}
    local helpCandidates = {}
    local fallbackCandidates = {}
    
    for _, friendInfo in cs_pairs(friendSystem.friendInfoDic) do
        if friendInfo.roleId ~= currentRoleId and friendInfo.guestRoomUnlock then
            local candidate = self:_BuildVisitCandidate(friendInfo, clueRemainCount, helpRemainCount)
            if candidate ~= nil then
                if candidate.canExchange and candidate.canHelp then
                    table.insert(bothCandidates, candidate)
                end
                if candidate.canExchange then
                    table.insert(exchangeCandidates, candidate)
                end
                if candidate.canHelp then
                    table.insert(helpCandidates, candidate)
                end
                if candidate.totalRoomScore > 0 then
                    table.insert(fallbackCandidates, candidate)
                end
            end
        end
    end

    
    local candidate = self:_SelectCandidate(bothCandidates, { "helpRoomTypeCount", "activeScore", "adventureLevel" })
    if candidate ~= nil then
        self:_LogFastVisit("GetCandidate_SelectBoth", {
            candidate = self:_GetFastVisitCandidateLogInfo(candidate),
            bothCount = #bothCandidates,
            exchangeCount = #exchangeCandidates,
            helpCount = #helpCandidates,
            fallbackCount = #fallbackCandidates,
        })
        return candidate
    end

    
    if clueRemainCount > 0 then
        candidate = self:_SelectCandidate(exchangeCandidates, { "totalRoomScore", "activeScore", "adventureLevel" })
        if candidate ~= nil then
            self:_LogFastVisit("GetCandidate_SelectExchange", {
                candidate = self:_GetFastVisitCandidateLogInfo(candidate),
                exchangeCount = #exchangeCandidates,
            })
        end
    end
    if candidate == nil and helpRemainCount > 0 then
        candidate = self:_SelectCandidate(helpCandidates, { "totalRoomScore", "activeScore", "adventureLevel" })
        if candidate ~= nil then
            self:_LogFastVisit("GetCandidate_SelectHelp", {
                candidate = self:_GetFastVisitCandidateLogInfo(candidate),
                helpCount = #helpCandidates,
            })
        end
    end
    if candidate ~= nil then
        return candidate
    end

    
    candidate = self:_SelectCandidate(fallbackCandidates, { "totalRoomScore", "activeScore", "adventureLevel" })
    self:_LogFastVisit("GetCandidate_SelectFallback", {
        candidate = self:_GetFastVisitCandidateLogInfo(candidate),
        fallbackCount = #fallbackCandidates,
    })
    return candidate
end

SocializeVisitTipsCtrl._BuildVisitCandidate = HL.Method(HL.Any, HL.Number, HL.Number).Return(HL.Opt(HL.Table)) << function(self, friendInfo, clueRemainCount, helpRemainCount)
    local roleId = friendInfo.roleId
    local joinedExchange = GameInstance.player.spaceship:CheckIsJoinFriendClueExchange(roleId)
    local canExchange = clueRemainCount > 0 and friendInfo.clueFlag
    local helpRoomTypeCount, helpedBySelf = self:_GetRemainingHelpRoomTypeCount(friendInfo, roleId)
    local canHelpRemainingRoom = helpRemainCount > 0 and helpRoomTypeCount > 0
        and friendInfo.helpFlag ~= CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.Invalid
    local canHelp = canHelpRemainingRoom and not helpedBySelf
        and friendInfo.helpFlag == CS.Proto.FRIEND_SPACESHIP_HELP_STATUS.CanHelp
    local totalActionScore = (canExchange and 1 or 0) + (canHelp and helpRoomTypeCount or 0)
    local totalRoomScore = (canExchange and 1 or 0) + (canHelpRemainingRoom and helpRoomTypeCount or 0)
    
    if totalRoomScore <= 0 then
        return nil
    end

    return {
        roleId = roleId,
        canExchange = canExchange,
        canHelp = canHelp,
        clueFlag = friendInfo.clueFlag,
        joinedExchange = joinedExchange,
        helpFlag = friendInfo.helpFlag,
        helpedBySelf = helpedBySelf,
        canHelpRemainingRoom = canHelpRemainingRoom,
        helpRoomTypeCount = helpRoomTypeCount,
        totalActionScore = totalActionScore,
        totalRoomScore = totalRoomScore,
        activeScore = self:_GetFriendActiveScore(friendInfo),
        adventureLevel = friendInfo.adventureLevel,
    }
end

SocializeVisitTipsCtrl._GetRemainingHelpRoomTypeCount = HL.Method(HL.Any, HL.Number).Return(HL.Number, HL.Boolean) << function(self, friendInfo, roleId)
    
    local helpedBySelf = false
    local helpRecords = GameInstance.player.spaceship:GetHelpOthersRecord(CS.Beyond.Gameplay.SpaceshipEnums.SpaceshipDataType.Self)
    if helpRecords ~= nil then
        for _, record in cs_pairs(helpRecords) do
            if record.Target == roleId or tostring(record.Target) == tostring(roleId) then
                helpedBySelf = true
                break
            end
        end
    end

    local remainingRoomTypeCount = 0
    if friendInfo.roomHelpCounts ~= nil then
        for _, helpCount in cs_pairs(friendInfo.roomHelpCounts) do
            if helpCount > 0 then
                remainingRoomTypeCount = remainingRoomTypeCount + 1
            end
        end
    end
    return remainingRoomTypeCount, helpedBySelf
end

SocializeVisitTipsCtrl._GetFriendActiveScore = HL.Method(HL.Any).Return(HL.Number) << function(self, friendInfo)
    if friendInfo.playerOnlineState == CS.Beyond.Gameplay.PlayerOnlineState.Online then
        return 3
    end
    local lastDateTime = friendInfo.lastDateTime
    if lastDateTime ~= 0 and DateTimeUtils.GetCurrentTimestampBySeconds() - lastDateTime < ONE_DAY_SECONDS then
        return 2
    end
    return 1
end

SocializeVisitTipsCtrl._SelectCandidate = HL.Method(HL.Table, HL.Table).Return(HL.Opt(HL.Table)) << function(self, candidates, sortKeys)
    if #candidates == 0 then
        return nil
    end

    table.sort(candidates, function(a, b)
        for _, key in ipairs(sortKeys) do
            if a[key] ~= b[key] then
                return a[key] > b[key]
            end
        end
        return false
    end)

    local bestCandidate = candidates[1]
    local bestCandidates = {}
    
    for _, candidate in ipairs(candidates) do
        if self:_IsSameCandidateSort(candidate, bestCandidate, sortKeys) then
            table.insert(bestCandidates, candidate)
        end
    end
    return bestCandidates[math.random(#bestCandidates)]
end

SocializeVisitTipsCtrl._IsSameCandidateSort = HL.Method(HL.Table, HL.Table, HL.Table).Return(HL.Boolean) << function(self, candidate, otherCandidate, sortKeys)
    for _, key in ipairs(sortKeys) do
        if candidate[key] ~= otherCandidate[key] then
            return false
        end
    end
    return true
end

SocializeVisitTipsCtrl.OnShow = HL.Override() << function(self)
    self:_TryFinishPendingVisit()
    self:OnCellChange()
    if UIManager:IsShow(PanelId.Loading) then
        self.m_waitingPlayAnimationAfterLoading = true
        return
    end
    self:_PlayVisitTipsAnimation()
end
HL.Commit(SocializeVisitTipsCtrl)
