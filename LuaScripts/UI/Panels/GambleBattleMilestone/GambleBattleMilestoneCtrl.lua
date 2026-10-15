local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleMilestone
local PHASE_ID = PhaseId.GambleBattleMilestone

local NodeStatus = {
    Nrl = 1,
    Receive = 2,
    Done = 3,
    WaitOpen = 4,  
}


local LOCK_NODE_DEFAULT_WIDTH = 500

GambleBattleMilestoneCtrl = HL.Class('GambleBattleMilestoneCtrl', uiCtrl.UICtrl)

GambleBattleMilestoneCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_MILESTONE_REWARD_RECEIVED] = '_OnDataChange',
    [MessageConst.ON_RACING_DUNGEON_GET_MILESTONE_REWARD] = '_OnDataChange',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = '_OnDataChange',
    
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnDataChange',
}

GambleBattleMilestoneCtrl.m_activityId = HL.Field(HL.String) << ''

GambleBattleMilestoneCtrl.m_stateName = HL.Field(HL.String) << ''

GambleBattleMilestoneCtrl.m_activityData = HL.Field(HL.Any)

GambleBattleMilestoneCtrl.m_nodes = HL.Field(HL.Table)

GambleBattleMilestoneCtrl.m_getCellFunc = HL.Field(HL.Function)

GambleBattleMilestoneCtrl.m_countdownCor = HL.Field(HL.Thread)

GambleBattleMilestoneCtrl.m_lockNodeLayoutCor = HL.Field(HL.Thread)

GambleBattleMilestoneCtrl.m_scoreAnimLuaUpdateKey = HL.Field(HL.Number) << -1

GambleBattleMilestoneCtrl.m_hasPlayedScoreAnim = HL.Field(HL.Boolean) << false

GambleBattleMilestoneCtrl.m_lockedStageOpenTime = HL.Field(HL.Any)

GambleBattleMilestoneCtrl.m_readNodes = HL.Field(HL.Table)

GambleBattleMilestoneCtrl.m_lockNodeWidth = HL.Field(HL.Number) << LOCK_NODE_DEFAULT_WIDTH


GambleBattleMilestoneCtrl.m_rewardScrollBasePaddingRight = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_totalMilestoneNodeCount = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_sceneContentStartPos = HL.Field(Vector2)


GambleBattleMilestoneCtrl.m_sceneContentStartPosInited = HL.Field(HL.Boolean) << false


GambleBattleMilestoneCtrl.m_sceneContentMaxMoveWidth = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_currRewardScrollableWidth = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_fullRewardScrollableWidth = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_needNaviToFirst = HL.Field(HL.Boolean) << false


GambleBattleMilestoneCtrl.m_naviTargetIndex = HL.Field(HL.Number) << 0


GambleBattleMilestoneCtrl.m_hasLoggedMissingMilestoneCfg = HL.Field(HL.Boolean) << false


GambleBattleMilestoneCtrl.m_needRestoreNaviByMilestoneId = HL.Field(HL.Boolean) << false

GambleBattleMilestoneCtrl.m_restoreNaviMilestoneId = HL.Field(HL.Any)

GambleBattleMilestoneCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId
    if arg.stateName~= nil and not string.isEmpty(arg.stateName) then
        self.m_stateName = arg.stateName
    end

    if self.m_stateName == "GambleBattle" then
        self.animationWrapper:SetAnimationInClip("activitycoinmilestonepanel_newin_part_0")
        self.animationWrapper:SetAnimationInEasingClip("activitycoinmilestonepanel_newin_part_1")
        self.animationWrapper:SetAnimationOutClip("activitycoinmilestonepanel_newout")
    end

    self.m_readNodes = {}
    self.m_needNaviToFirst = true
    self:_InitData()
    self:_BindUI()
    self:_RefreshUI()
end

GambleBattleMilestoneCtrl._BindUI = HL.Method() << function(self)
    self.view.commonTopTitleNode.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)

    local helpInstructionId = self.m_activityId .. "_milestone"
    self.view.commonTopTitleNode.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, {
            id = helpInstructionId,
        })
    end)

    self.m_getCellFunc = UIUtils.genCachedCellFunction(self.view.rewardScroll)
    self.m_rewardScrollBasePaddingRight = self.view.rewardScroll:GetPadding().right
    self.view.rewardScroll.onUpdateCell:RemoveAllListeners()
    self.view.rewardScroll.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateCell(object, LuaIndex(csIndex))
    end)
    self.view.rewardScrollScrollRect.onValueChanged:AddListener(function(normalizedPosition)
        self:_OnRewardScrollValueChanged(normalizedPosition)
    end)

    self.view.btnCommonYellow.onClick:RemoveAllListeners()
    self.view.btnCommonYellow.onClick:AddListener(function()
        self:_TryReceiveAllRewards()
    end)

    if self.view.redDotScrollRect then
        self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
            return self:GetRedDotStateAt(csIndex)
        end
    end

    
    
    local rewardScrollNaviGroup = self.view.rewardScrollScrollRect.naviGroup
    if rewardScrollNaviGroup then
        rewardScrollNaviGroup.onDefaultNaviFailed:RemoveAllListeners()
        rewardScrollNaviGroup.onDefaultNaviFailed:AddListener(function(dir)
            self:_OnRewardScrollNaviFailed(dir)
        end)
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

GambleBattleMilestoneCtrl._InitData = HL.Method() << function(self)
    self.m_activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)

    
    
    local haveCfg, milestoneCfg = Tables.activityCommonUIMilestoneTable:TryGetValue(self.m_activityId)
    if not haveCfg then
        self.m_nodes = {}
        self.m_totalMilestoneNodeCount = 0
        return
    end

    local milestoneScore = ActivityUtils.GetRacingDungeonMilestoneCurrScore(self.m_activityId)

    local nodes = {}
    
    local unconfiguredNodes = {}
    local totalNodeCount = 0
    local haveLockedNode = false  
    for _, nodeData in pairs(milestoneCfg.milestoneMap) do
        totalNodeCount = totalNodeCount + 1
        local milestoneId = nodeData.milestoneId
        local unlockStageId = nodeData.unlockStageId
        local _, stageData = self.m_activityData.stageDataDict:TryGetValue(unlockStageId)
        local stageStatus = stageData and GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
        if stageStatus and stageStatus ~= GEnums.ActivityConditionalStageState.Locked then
            local haveScore, completeScore, rewardId =
                ActivityUtils.TryGetConditionalMultiStageMilestone(self.m_activityId, milestoneId)
            local status = NodeStatus.Nrl
            if ActivityUtils.IsActivityCoinMilestoneReceived(self.m_activityId, milestoneId) then
                status = NodeStatus.Done
            elseif haveScore and milestoneScore >= completeScore then
                status = NodeStatus.Receive
            end
            local node = {
                milestoneId = milestoneId,
                completeScore = completeScore,
                maxScore = nodeData.maxScore,
                rewardId = rewardId,
                isBig = nodeData.isBig,
                status = status,
            }
            table.insert(haveScore and nodes or unconfiguredNodes, node)
        end
        if stageStatus == GEnums.ActivityConditionalStageState.Locked then
            haveLockedNode = true
            if not self.m_lockedStageOpenTime then
                self.m_lockedStageOpenTime = stageData.OpenTimeTs
            end
        end
    end

    table.sort(nodes, function(a, b) return a.completeScore < b.completeScore end)
    if #unconfiguredNodes > 0 then
        if not self.m_hasLoggedMissingMilestoneCfg then
            self.m_hasLoggedMissingMilestoneCfg = true
            logger.error(string.format(
                "[GambleBattleMilestone] activity %s has %d milestone node(s) missing in activityConditionalMultiStageMilestoneTable",
                self.m_activityId, #unconfiguredNodes))
        end
        table.sort(unconfiguredNodes, function(a, b) return a.milestoneId < b.milestoneId end)
        for _, node in ipairs(unconfiguredNodes) do
            table.insert(nodes, node)
        end
    end
    if haveLockedNode then
        table.insert(nodes, {
            status = NodeStatus.WaitOpen,
        })
    end
    self.m_nodes = nodes
    self.m_totalMilestoneNodeCount = totalNodeCount
end

GambleBattleMilestoneCtrl._CalcInitialTargetIndex = HL.Method().Return(HL.Number) << function(self)
    local firstNormalIndex = 0
    local lastDoneIndex = 0
    for i, node in ipairs(self.m_nodes) do
        if node.status == NodeStatus.Receive then
            return i
        elseif node.status == NodeStatus.Nrl and firstNormalIndex <= 0 then
            firstNormalIndex = i
        elseif node.status == NodeStatus.Done then
            lastDoneIndex = i
        end
    end

    if firstNormalIndex > 0 then
        return firstNormalIndex
    end
    return lastDoneIndex
end

GambleBattleMilestoneCtrl._TryGetCurNaviMilestoneId = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    if not DeviceInfo.usingController then
        return nil
    end

    local getMilestoneIdByTarget = function(target)
        if target == nil then
            return nil
        end
        for index, node in ipairs(self.m_nodes) do
            if node.status ~= NodeStatus.WaitOpen then
                local cellObj = self.view.rewardScroll:Get(CSIndex(index))
                if cellObj ~= nil then
                    local cell = self.m_getCellFunc(cellObj)
                    if cell ~= nil and cell.inputBindingGroupNaviDecorator == target then
                        return node.milestoneId
                    end
                end
            end
        end
        return nil
    end

    local curTarget = InputManagerInst.controllerNaviManager.curTarget
    local curTargetMilestoneId = getMilestoneIdByTarget(curTarget)
    if curTargetMilestoneId ~= nil then
        return curTargetMilestoneId
    end

    if not InputManagerInst.controllerNaviManager:IsPanelScopeTop(self.panelId) then
        local rewardScrollNaviGroup = self.view.rewardScroll.gameObject:GetComponent("UISelectableNaviGroup")
        return rewardScrollNaviGroup ~= nil and getMilestoneIdByTarget(rewardScrollNaviGroup.LayerSelectedTarget) or nil
    end

    return nil
end

GambleBattleMilestoneCtrl._HasWaitOpenNode = HL.Method().Return(HL.Boolean) << function(self)
    local nodeCount = #self.m_nodes
    return nodeCount > 0 and self.m_nodes[nodeCount].status == NodeStatus.WaitOpen
end

GambleBattleMilestoneCtrl._GetLastNavigableLuaIndex = HL.Method().Return(HL.Number) << function(self)
    local lastIndex = #self.m_nodes
    if self:_HasWaitOpenNode() then
        lastIndex = lastIndex - 1
    end
    return lastIndex
end

GambleBattleMilestoneCtrl._TrySetNaviToRewardCell = HL.Method(HL.Number).Return(HL.Boolean) << function(self, luaIndex)
    if luaIndex < 1 or luaIndex > #self.m_nodes then
        return false
    end

    local node = self.m_nodes[luaIndex]
    if not node or node.status == NodeStatus.WaitOpen then
        return false
    end

    local csIndex = CSIndex(luaIndex)
    local cellObj = self.view.rewardScroll:Get(csIndex)
    if cellObj == nil then
        self.view.rewardScroll:ScrollToIndex(csIndex, true)
        cellObj = self.view.rewardScroll:Get(csIndex)
    end
    if cellObj == nil then
        return false
    end

    local cell = self.m_getCellFunc(cellObj)
    if cell == nil or cell.inputBindingGroupNaviDecorator == nil then
        return false
    end

    self:SetNaviTarget(cell.inputBindingGroupNaviDecorator)
    return true
end



GambleBattleMilestoneCtrl._OnRewardScrollNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    local lastNavigable = self:_GetLastNavigableLuaIndex()
    local currentCsIndex = self.view.rewardScroll:GetNaviManagerTargetIndex()
    local currentLuaIndex = currentCsIndex >= 0 and LuaIndex(currentCsIndex) or 0

    if dir == CS.UnityEngine.UI.NaviDirection.Left and currentLuaIndex == 1 and lastNavigable > 0 then
        self:_TrySetNaviToRewardCell(lastNavigable)
        return
    end
    if dir == CS.UnityEngine.UI.NaviDirection.Right and currentLuaIndex == lastNavigable and lastNavigable > 0 then
        self:_TrySetNaviToRewardCell(1)
        return
    end

    self.view.rewardScroll:ListWrapNavigate(dir)
end

GambleBattleMilestoneCtrl._RefreshLockNodeLayout = HL.Method() << function(self)
    local nodeCount = #self.m_nodes
    local hasWaitOpenNode = self:_HasWaitOpenNode()
    local scrollRect = self.view.rewardScroll:GetComponent(typeof(CS.UnityEngine.UI.ScrollRect))
    
    
    local cellW = self.view.cell.rectTransform.rect.width
    local padding = self.view.rewardScroll:GetPadding()
    local basePaddingRight = self.m_rewardScrollBasePaddingRight
    local extraPaddingRight = 0
    if hasWaitOpenNode then
        
        local viewportW = self.view.rewardScroll.gameObject:GetComponent("RectTransform").rect.width
        local spaceX = self.view.rewardScroll.space.x
        local otherCount = nodeCount - 1
        local otherWidth = cellW * otherCount + spaceX * math.max(0, otherCount)
        local available = viewportW - padding.left - basePaddingRight - otherWidth
        if available >= LOCK_NODE_DEFAULT_WIDTH then
            
            self.m_lockNodeWidth = available
            scrollRect.horizontal = false
        else
            
            self.m_lockNodeWidth = LOCK_NODE_DEFAULT_WIDTH
            scrollRect.horizontal = true
        end
        extraPaddingRight = math.max(0, self.m_lockNodeWidth - cellW)
    else
        
        self.m_lockNodeWidth = LOCK_NODE_DEFAULT_WIDTH
        scrollRect.horizontal = true
    end
    self.view.rewardScroll:SetPaddingRight(basePaddingRight + extraPaddingRight)
end

GambleBattleMilestoneCtrl._ScheduleDeferredLockNodeLayoutRefresh = HL.Method() << function(self)
    if self.m_lockNodeLayoutCor then
        self.m_lockNodeLayoutCor = self:_ClearCoroutine(self.m_lockNodeLayoutCor)
    end

    if not self:_HasWaitOpenNode() then
        return
    end

    self.m_lockNodeLayoutCor = self:_StartCoroutine(function()
        coroutine.step()
        self.m_lockNodeLayoutCor = nil
        if IsNull(self.view.gameObject) then
            return
        end

        local oldLockWidth = self.m_lockNodeWidth
        local oldPaddingRight = self.view.rewardScroll:GetPadding().right
        self:_RefreshLockNodeLayout()
        
        if self.m_lockNodeWidth ~= oldLockWidth or self.view.rewardScroll:GetPadding().right ~= oldPaddingRight then
            self:_RefreshRewardScroll(#self.m_nodes)
        end
        self:_RefreshShowingWaitOpenNodeLayout()
        self:_RefreshSceneContentPosition()
    end)
end



GambleBattleMilestoneCtrl._RefreshRewardScroll = HL.Method(HL.Number, HL.Opt(HL.Number)) << function(self, nodeCount, naviLuaIndex)
    if naviLuaIndex and naviLuaIndex > 0 then
        self.view.rewardScroll:UpdateCount(nodeCount, CSIndex(naviLuaIndex), false, false, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Center)
    else
        self.view.rewardScroll:UpdateCount(nodeCount, false, false, false, true)
    end
end

GambleBattleMilestoneCtrl._RefreshUI = HL.Method() << function(self)
    
    local nodeCount = #self.m_nodes
    local hasWaitOpenNode = self:_HasWaitOpenNode()

    
    if self.m_needNaviToFirst then
        self.m_naviTargetIndex = self:_CalcInitialTargetIndex()
    end

    
    self:_RefreshLockNodeLayout()

    
    
    local naviLuaIndex
    if self.m_needNaviToFirst and self.m_naviTargetIndex > 0 then
        naviLuaIndex = self.m_naviTargetIndex
    end
    self:_RefreshRewardScroll(nodeCount, naviLuaIndex)
    self:_ScheduleDeferredLockNodeLayoutRefresh()
    self:_RefreshSceneContentPosition()

    local currScore = ActivityUtils.GetRacingDungeonMilestoneCurrScore(self.m_activityId)
    if currScore == nil then
        currScore = 0
    end
    local maxScore = ActivityUtils.GetRacingDungeonMilestoneMaxScore(self.m_activityId)
    if not self.m_hasPlayedScoreAnim then
        self:_StartScoreAnim(currScore, maxScore)
    else
        self:_StopScoreAnim()
        self:_SetScoreText(currScore, maxScore)
    end

    local hasReceivable = false
    for _, node in ipairs(self.m_nodes) do
        if node.status == NodeStatus.Receive then
            hasReceivable = true
            break
        end
    end
    self.view.btnCommonYellow.gameObject:SetActive(hasReceivable)
    self.view.disBtn.gameObject:SetActive(not hasReceivable)

    if self.m_countdownCor then
        self.m_countdownCor = self:_ClearCoroutine(self.m_countdownCor)
    end

    local countdownNode = self.view.countdownNode
    local countdownText = countdownNode.timeText
    local endTime = self.m_activityData.endTime
    local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local leftSec = endTime - curTime
    if leftSec < 0 then leftSec = 0 end
    countdownText.text = string.format(Language.LUA_ACTIVITY_RACING_DUNGEON_MILESTONE_PANEL_COUNTDOWN_TEXT, UIUtils.getLeftTime(leftSec))
    if leftSec > 0 or hasWaitOpenNode then
        self.m_countdownCor = self:_StartCoroutine(function()
            while true do
                coroutine.wait(60)
                local remaining = endTime - DateTimeUtils.GetCurrentTimestampBySeconds()
                if remaining < 0 then remaining = 0 end
                countdownText.text = string.format(Language.LUA_ACTIVITY_RACING_DUNGEON_MILESTONE_PANEL_COUNTDOWN_TEXT, UIUtils.getLeftTime(remaining))
                if hasWaitOpenNode then
                    self:_UpdateShowingWaitOpenNodeCountdown()
                end
                if remaining <= 0 and not hasWaitOpenNode then
                    break
                end
                if hasWaitOpenNode then
                    local stageRemaining = self.m_lockedStageOpenTime - DateTimeUtils.GetCurrentTimestampBySeconds()
                    if stageRemaining <= 0 and remaining <= 0 then
                        break
                    end
                end
            end
        end)
    end
end

GambleBattleMilestoneCtrl._RefreshWaitOpenNodeCountdown = HL.Method(HL.Any) << function(self, cell)
    if self.m_lockedStageOpenTime then
        local remaining = self.m_lockedStageOpenTime - DateTimeUtils.GetCurrentTimestampBySeconds()
        if remaining < 0 then remaining = 0 end
        cell.lockNode.timeNumTxt.text = UIUtils.getLeftTime(remaining)
    else
        cell.lockNode.timeNumTxt.text = "--"
    end
end

GambleBattleMilestoneCtrl._RefreshShowingWaitOpenNodeLayout = HL.Method() << function(self)
    local waitOpenIndex = #self.m_nodes
    if waitOpenIndex <= 0 or self.m_nodes[waitOpenIndex].status ~= NodeStatus.WaitOpen then
        return
    end

    self.view.rewardScroll:UpdateShowingCells(function(csIndex, obj)
        if LuaIndex(csIndex) ~= waitOpenIndex then
            return
        end

        local cell = self.m_getCellFunc(obj)
        local lockRect = cell.lockNode.rectTransform
        lockRect.sizeDelta = Vector2(self.m_lockNodeWidth, lockRect.sizeDelta.y)
        self:_RefreshWaitOpenNodeCountdown(cell)
    end)
end

GambleBattleMilestoneCtrl._UpdateShowingWaitOpenNodeCountdown = HL.Method() << function(self)
    local waitOpenIndex = #self.m_nodes
    if waitOpenIndex <= 0 or self.m_nodes[waitOpenIndex].status ~= NodeStatus.WaitOpen then
        return
    end

    self.view.rewardScroll:UpdateShowingCells(function(csIndex, obj)
        if LuaIndex(csIndex) ~= waitOpenIndex then
            return
        end

        local cell = self.m_getCellFunc(obj)
        self:_RefreshWaitOpenNodeCountdown(cell)
    end)
end



GambleBattleMilestoneCtrl._OnRewardScrollValueChanged = HL.Method(Vector2) << function(self, normalizedPosition)
    self:_RefreshSceneContentPosition()
end




GambleBattleMilestoneCtrl._RefreshSceneContentPosition = HL.Method() << function(self)
    if not self.m_sceneContentStartPosInited then
        return
    end

    local progress = 0
    if self.m_fullRewardScrollableWidth > 0 then
        
        
        local currScrollDistance = self.view.rewardScrollScrollRect.horizontalNormalizedPosition * self.m_currRewardScrollableWidth
        progress = math.max(0, math.min(currScrollDistance / self.m_fullRewardScrollableWidth, 1))
    end

    self.view.sceneContentNode.transform.anchoredPosition = Vector2(
        self.m_sceneContentStartPos.x - self.m_sceneContentMaxMoveWidth * progress,
        self.m_sceneContentStartPos.y)
end

GambleBattleMilestoneCtrl._CalcNodeProgressFillAmount = HL.Method(HL.Number, HL.Number).Return(HL.Number) << function(self, currScore, index)
    local node = self.m_nodes[index]
    if not node or node.status == NodeStatus.WaitOpen or not node.completeScore then
        return 0
    end

    local prevScore = 0
    if index > 1 then
        prevScore = self.m_nodes[index - 1].completeScore or 0
    end
    local range = node.completeScore - prevScore
    if range <= 0 then
        return 1
    end

    local progress = math.max(0, math.min(currScore - prevScore, range))
    return progress / range
end

GambleBattleMilestoneCtrl._GetMilestoneProgressTargetInfo = HL.Method(HL.Number).Return(HL.Number, HL.Number) << function(self, currScore)
    local lastNormalIndex = 0
    for index, node in ipairs(self.m_nodes) do
        if node.status ~= NodeStatus.WaitOpen and node.completeScore then
            lastNormalIndex = index
            if currScore <= node.completeScore then
                return index, self:_CalcNodeProgressFillAmount(currScore, index)
            end
        end
    end

    if lastNormalIndex > 0 then
        return lastNormalIndex, 1
    end
    return 0, 0
end


GambleBattleMilestoneCtrl._OnUpdateCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, index)
    local cell = self.m_getCellFunc(object)
    local node = self.m_nodes[index]
    if not node then
        return
    end

    local currScore = ActivityUtils.GetRacingDungeonMilestoneCurrScore(self.m_activityId)

    
    local isFirst = index == 1
    local isLast = index == #self.m_nodes
    cell.decoLeft.gameObject:SetActive(isFirst)
    cell.decoRight.gameObject:SetActive(isLast)

    local decoColor = UIUtils.getColorByString("FFDE00", 255)
    if self.m_stateName == "GambleBattle" then
        decoColor = UIUtils.getColorByString("5DB6AF", 255)
    end

    
    if node.status == NodeStatus.WaitOpen then
        cell.rewardStateNode.gameObject:SetActive(false)
        cell.lockNode.gameObject:SetActive(true)
        cell.progressNode:SetState("Lock")
        
        cell.inputBindingGroupNaviDecorator.enabled = false
        
        local lockRect = cell.lockNode.rectTransform
        lockRect.sizeDelta = Vector2(self.m_lockNodeWidth, lockRect.sizeDelta.y)
        self:_RefreshWaitOpenNodeCountdown(cell)

        local progressBG = cell.lockNode.transform:Find("ProgressBG"):GetComponent("UIImage")
        local lastNormalNode = self.m_nodes[#self.m_nodes - 1]
        if lastNormalNode and lastNormalNode.completeScore and currScore > lastNormalNode.completeScore then
            cell.progressImg.fillAmount = 1
            progressBG.color = decoColor
        else
            cell.progressImg.fillAmount = 0
            progressBG.color = UIUtils.getColorByString("FFFFFF", 46)
        end
        return
    end

    
    cell.rewardStateNode.gameObject:SetActive(true)
    cell.lockNode.gameObject:SetActive(false)
    
    cell.inputBindingGroupNaviDecorator.enabled = true

    
    cell.progressImg.fillAmount = self:_CalcNodeProgressFillAmount(currScore, index)
    
    local isScoreReached = node.completeScore ~= nil and currScore >= node.completeScore
    
    if isScoreReached then
        cell.progressNode:SetState("Receive")
    else
        cell.progressNode:SetState("Nrl")
    end
    cell.rewardTxt.text = node.completeScore and tostring(node.completeScore) or "--"
    local decoColor = isScoreReached
        and decoColor
        or UIUtils.getColorByString("FFFFFF", 0.18 * 255)
    if isFirst then
        cell.decoLeft.color = decoColor
    end
    if isLast then
        cell.decoRight.color = decoColor
    end

    
    local rewardItems = node.rewardId and UIUtils.getRewardItems(node.rewardId) or {}
    if #rewardItems >= 1 then
        cell.itemReward01.gameObject:SetActive(true)
        cell.itemReward01:InitItem(rewardItems[1], function()
            cell.itemReward01:ShowTips()
        end)
        if DeviceInfo.usingController then
            cell.itemReward01:SetExtraInfo({
                isSideTips = true,
            })
        end
    else
        cell.itemReward01.gameObject:SetActive(false)
    end
    if #rewardItems >= 2 then
        cell.itemReward02.gameObject:SetActive(true)
        cell.itemReward02:InitItem(rewardItems[2], function()
            cell.itemReward02:ShowTips()
        end)
        if DeviceInfo.usingController then
            cell.itemReward02:SetExtraInfo({
                isSideTips = true,
            })
        end
    else
        cell.itemReward02.gameObject:SetActive(false)
    end

    local stateStr = "Nrl"
    if node.status == NodeStatus.Receive then
        stateStr = "Receive"
    elseif node.status == NodeStatus.Done then
        stateStr = "Done"
    end
    cell.rewardStateNode.stateController:SetState(stateStr)
    
    cell.rewardStateNode.stateController:SetState(node.isBig and "Big" or "Small")

    cell.rewardStateNode.receiveBtn.onClick:RemoveAllListeners()
    if node.status == NodeStatus.Receive then
        
        cell.rewardStateNode.receiveBtn.onClick:AddListener(function()
            self:_TryReceiveAllRewards()
        end)
    end

    local redDotArgs = {
        activityId = self.m_activityId,
        milestoneId = node.milestoneId,
    }
    cell.itemReward01.view.redDot:InitRedDot("ActivityRacingDungeonSingleMilestone", redDotArgs, nil, self.view.redDotScrollRect)
    

    self.m_readNodes[node.milestoneId] = true

    
    if self.m_needNaviToFirst and index == self.m_naviTargetIndex then
        self.m_needNaviToFirst = false
        self:SetNaviTarget(cell.inputBindingGroupNaviDecorator)
    end
    if self.m_needRestoreNaviByMilestoneId and node.milestoneId == self.m_restoreNaviMilestoneId then
        self.m_needRestoreNaviByMilestoneId = false
        self.m_restoreNaviMilestoneId = nil
        self:SetNaviTarget(cell.inputBindingGroupNaviDecorator)
    end
end

GambleBattleMilestoneCtrl._SetScoreText = HL.Method(HL.Number, HL.Number) << function(self, score, maxScore)
    self.view.integralNumTxt.text = score
    self.view.maxScoreTxt.text = maxScore
end

GambleBattleMilestoneCtrl._StopScoreAnim = HL.Method() << function(self)
    if self.m_scoreAnimLuaUpdateKey > 0 then
        self.m_scoreAnimLuaUpdateKey = LuaUpdate:Remove(self.m_scoreAnimLuaUpdateKey)
    end
end

GambleBattleMilestoneCtrl._StartScoreAnim = HL.Method(HL.Number, HL.Number) << function(self, currScore, maxScore)
    self:_StopScoreAnim()
    self.m_hasPlayedScoreAnim = true

    local curve = self.view.config.SCORE_CURVE
    local startTime = self.view.config.SCORE_START_TIME
    local duration = self.view.config.SCORE_TIME
    local endTime = startTime + duration
    local timeCount = 0
    self:_SetScoreText(0, maxScore)

    if duration <= 0 then
        self:_SetScoreText(currScore, maxScore)
        return
    end

    self.m_scoreAnimLuaUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        timeCount = timeCount + deltaTime
        if timeCount < startTime then
            self:_SetScoreText(0, maxScore)
        elseif timeCount < endTime then
            local normalizedX = (timeCount - startTime) / duration
            local normalizedY = curve:Evaluate(normalizedX)
            self:_SetScoreText(lume.round(currScore * normalizedY), maxScore)
        else
            self:_SetScoreText(currScore, maxScore)
            self:_StopScoreAnim()
        end
    end)
end

GambleBattleMilestoneCtrl.OnClose = HL.Override() << function(self)
    self.view.rewardScroll:SetPaddingRight(self.m_rewardScrollBasePaddingRight)
    if self.m_countdownCor then
        self.m_countdownCor = self:_ClearCoroutine(self.m_countdownCor)
    end
    if self.m_lockNodeLayoutCor then
        self.m_lockNodeLayoutCor = self:_ClearCoroutine(self.m_lockNodeLayoutCor)
    end
    self:_StopScoreAnim()
    self:_UpdateReadInfo()
end

GambleBattleMilestoneCtrl._UpdateReadInfo = HL.Method() << function(self)
    for milestoneId, _ in pairs(self.m_readNodes) do
        ActivityUtils.setCommonUIMilestoneNodeRead(self.m_activityId, milestoneId)
    end
end

GambleBattleMilestoneCtrl._TryReceiveAllRewards = HL.Method() << function(self)
    local hasReceivable = false
    for _, node in ipairs(self.m_nodes) do
        if node.status == NodeStatus.Receive then
            hasReceivable = true
            break
        end
    end
    if hasReceivable then
        GameInstance.player.activitySystem:SendReceiveRewardAllMilestones(self.m_activityId)
    end
end

GambleBattleMilestoneCtrl._OnDataChange = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= self.m_activityId then
        return
    end
    
    if not GameInstance.player.activitySystem:GetActivity(self.m_activityId) then
        PhaseManager:PopPhase(PHASE_ID)
        return
    end
    local restoreNaviMilestoneId = self:_TryGetCurNaviMilestoneId()
    self.m_needRestoreNaviByMilestoneId = restoreNaviMilestoneId ~= nil
    self.m_restoreNaviMilestoneId = restoreNaviMilestoneId

    self:_InitData()
    self:_RefreshUI()
end

GambleBattleMilestoneCtrl.GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, index)
    local luaIndex = LuaIndex(index)
    if luaIndex < 1 or luaIndex > #self.m_nodes then
        return 0  
    end

    local node = self.m_nodes[luaIndex]
    local redDotArgs = {
        activityId = self.m_activityId,
        milestoneId = node.milestoneId,
    }

    local hasRedDot, redDotType, expireTs = RedDotManager:GetRedDotState(
        "ActivityRacingDungeonSingleMilestone", redDotArgs)
    if hasRedDot then
        return redDotType or UIConst.RED_DOT_TYPE.Normal
    else
        return 0  
    end
end

HL.Commit(GambleBattleMilestoneCtrl)
