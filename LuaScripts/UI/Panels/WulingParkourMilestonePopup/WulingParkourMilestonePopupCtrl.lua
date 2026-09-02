local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WulingParkourMilestonePopup
local PHASE_ID = PhaseId.WulingParkourMilestonePopup
local MILESTONE_CELL_IN_DELAY = 0.06
WulingParkourMilestonePopupCtrl = HL.Class('WulingParkourMilestonePopupCtrl', uiCtrl.UICtrl)






WulingParkourMilestonePopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_MILESTONE_REWARD_RECEIVED] = '_OnMilestoneUpdate',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnMilestoneUpdate',
}

WulingParkourMilestonePopupCtrl.m_activityId = HL.Field(HL.String) << ''
WulingParkourMilestonePopupCtrl.m_milestoneConfig = HL.Field(HL.Table)
WulingParkourMilestonePopupCtrl.m_milestoneScore = HL.Field(HL.Number) << 0
WulingParkourMilestonePopupCtrl.m_milestoneLevel = HL.Field(HL.Number) << 0
WulingParkourMilestonePopupCtrl.m_milestoneCellCache = HL.Field(HL.Any)
WulingParkourMilestonePopupCtrl.m_milestoneBarDotCache = HL.Field(HL.Any)
WulingParkourMilestonePopupCtrl.m_milestoneRewardCacheTable = HL.Field(HL.Table)
WulingParkourMilestonePopupCtrl.m_milestoneCells = HL.Field(HL.Table)
WulingParkourMilestonePopupCtrl.m_milestoneBarNodes = HL.Field(HL.Table)
WulingParkourMilestonePopupCtrl.m_hasWaitToReceiveMilestones = HL.Field(HL.Boolean) << false


WulingParkourMilestonePopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs(true)
end

WulingParkourMilestonePopupCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId
    self.m_milestoneScore = GameInstance.player.activitySystem:GetActivityMilestoneCurrentScore(self.m_activityId)
    self.m_milestoneConfig, self.m_milestoneLevel = ActivityUtils.getActivityMilestoneInfo(self.m_activityId)
end

WulingParkourMilestonePopupCtrl._InitUI = HL.Method() << function(self)
    
    self.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    
    self.m_milestoneCellCache = UIUtils.genCellCache(self.view.milestoneCell)
    self.m_milestoneBarDotCache = UIUtils.genCellCache(self.view.barDotNode)
    self.m_milestoneRewardCacheTable = {}
end

WulingParkourMilestonePopupCtrl._UpdateData = HL.Method() << function(self)
    self.m_milestoneScore = GameInstance.player.activitySystem:GetActivityMilestoneCurrentScore(self.m_activityId)
    self.m_milestoneConfig, self.m_milestoneLevel = ActivityUtils.getActivityMilestoneInfo(self.m_activityId)
end

WulingParkourMilestonePopupCtrl._RefreshAllUIs = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    
    self.view.lvTxt.text = self.m_milestoneLevel
    self.view.bubbleText.text = self.m_milestoneScore
    
    self.m_hasWaitToReceiveMilestones = false
    self.m_milestoneCells = {}
    self.m_milestoneBarNodes = {}
    local milestoneCount = #self.m_milestoneConfig
    self.m_milestoneCellCache:Refresh(milestoneCount, function(cell,index)
        self:_RefreshMilestoneCell(cell,index, isInit)
        if isInit then
            self:_StartCoroutine(function()
                coroutine.wait(MILESTONE_CELL_IN_DELAY * index)
                cell.gameObject:SetActive(true)
            end)
        end
    end, isInit)
    self.m_milestoneBarDotCache:Refresh(#self.m_milestoneConfig, function(cell,index)
        self:_RefreshBarDot(cell, index, isInit)
    end)

    
    local firstLevelScore = self.m_milestoneConfig[1].score
    local lastLevelScore = self.m_milestoneConfig[#self.m_milestoneConfig].score
    local leftLength = self.view.barHorLayout.padding.left
    local spacingLength = self.view.barHorLayout.spacing
    local totalLength = leftLength + spacingLength * (#self.m_milestoneConfig-1)
    local occupiedLength = 0
    if self.m_milestoneLevel == 0 then
        occupiedLength = leftLength * (self.m_milestoneScore/firstLevelScore)
    elseif self.m_milestoneLevel == #self.m_milestoneConfig then
        occupiedLength = totalLength
    else
        local latestLevelScore = self.m_milestoneConfig[self.m_milestoneLevel].score
        local nextLevelScore = self.m_milestoneConfig[self.m_milestoneLevel+1].score
        occupiedLength = leftLength + (self.m_milestoneLevel-1) * spacingLength + (self.m_milestoneScore - latestLevelScore)/(nextLevelScore - latestLevelScore) * spacingLength
    end
    self.view.barBgRectTransform:SetSizeWithCurrentAnchors(0, totalLength)
    self.view.barRectTransform:SetSizeWithCurrentAnchors(0, totalLength)
    self.view.barImage.fillAmount = occupiedLength/totalLength

    
    self.view.receiveAllNode.button.gameObject:SetActive(self.m_hasWaitToReceiveMilestones)
    if self.m_hasWaitToReceiveMilestones then
        self.view.receiveAllNode.stateController:SetState("NormalState")
        self.view.receiveAllNode.button.onClick:RemoveAllListeners()
        self.view.receiveAllNode.button.onClick:AddListener(function()
            GameInstance.player.activitySystem:SendReceiveRewardAllMilestones(self.m_activityId)
        end)
    end

    
    if DeviceInfo.usingController then
        if isInit then
            self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
            self:SetNaviTarget(self.m_milestoneLevel > 0 and self.m_milestoneCells[self.m_milestoneLevel].naviDecorator or self.m_milestoneCells[1].naviDecorator)
        end
        
        InputManagerInst:ToggleGroup(self.view.receiveAllNode.inputGroup.groupId, self.m_hasWaitToReceiveMilestones)
        self.view.receiveAllNode.keyHint.gameObject:SetActive(self.m_hasWaitToReceiveMilestones)
    end
end

WulingParkourMilestonePopupCtrl._RefreshMilestoneCell = HL.Method(HL.Any, HL.Number, HL.Opt(HL.Boolean)) << function(self, cell, index, isInit)
    
    self.m_milestoneCells[index] = cell
    local config = self.m_milestoneConfig[index]
    local milestoneId = config.milestoneId
    cell.lvNumTxt.text = index

    
    local isCompleted = self.m_milestoneScore >= config.score
    local isReceived = GameInstance.player.activitySystem:IsActivityMilestoneReceived(self.m_activityId, milestoneId)
    local toReceive = isCompleted and not isReceived
    cell.stateController:SetState(index == self.m_milestoneLevel and "Now" or "Pre") 
    cell.stateController:SetState(toReceive and "Receive" or "Normal") 
    if toReceive then
        self.m_hasWaitToReceiveMilestones = true
    end

    
    local rewardCache = self.m_milestoneRewardCacheTable[index] or UIUtils.genCellCache(cell.itemSmall)
    self.m_milestoneRewardCacheTable[index] = rewardCache
    local rewardBundles = UIUtils.getRewardItems(config.rewardId)
    rewardCache:Refresh(#rewardBundles, function(innerCell, innerIndex)
        innerCell.view.simpleStateController:SetState("Normal")
        innerCell.view.getNode.gameObject:SetActive(isReceived)
        local reward = {
            id = rewardBundles[innerIndex].id,
            count = rewardBundles[innerIndex].count,
            forceHidePotentialStar = true,
        }
        innerCell:InitItem(reward, function()
            innerCell:ShowTips()
        end)
        innerCell:SetExtraInfo({
            tipsPosTransform = innerCell.view.content,
            isSideTips = true,
        })
    end)

    
    if isInit then
        cell.receiveBtn.onClick:AddListener(function()
            GameInstance.player.activitySystem:SendReceiveRewardMilestone(self.m_activityId, milestoneId)
        end)
    end

    
    local redDotArgs = {
        activityId = self.m_activityId,
        milestoneId = milestoneId,
    }
    cell.redDot:InitRedDot("ActivityParkourSingleMilestone", redDotArgs)

end

WulingParkourMilestonePopupCtrl._RefreshBarDot = HL.Method(HL.Any, HL.Number, HL.Opt(HL.Boolean)) << function(self, cell, index, isInit)
    
    self.m_milestoneBarNodes[index] = cell
    local config = self.m_milestoneConfig[index]
    cell.numTxt.text = config.score

    
    local isCompleted = self.m_milestoneScore >= config.score
    cell.stateController:SetState(isCompleted and "Complete" or "Incomplete")
end

WulingParkourMilestonePopupCtrl._OnMilestoneUpdate = HL.Method(HL.Any) << function(self, arg)
    local activity = unpack(arg)
    if activity ~= self.m_activityId then
        return
    end
    
    if not GameInstance.player.activitySystem:GetActivity(self.m_activityId) then
        return
    end
    self:_UpdateData()
    self:_RefreshAllUIs()
end

HL.Commit(WulingParkourMilestonePopupCtrl)
