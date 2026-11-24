local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ITEM_CELL_DISPLAY_COUNT = 3
local PHOTO_COUNT = 3
local PHOTO_SPRITE_PATH = "WonderBuild"

WonderBuildSideInfo = HL.Class('WonderBuildSideInfo', UIWidgetBase)

WonderBuildSideInfo.m_stageId = HL.Field(HL.Number) << 0


WonderBuildSideInfo.m_stageData = HL.Field(HL.Any)
WonderBuildSideInfo.m_wonderProgress = HL.Field(HL.Userdata)

WonderBuildSideInfo.m_isLastStage = HL.Field(HL.Boolean) << false

WonderBuildSideInfo.m_isFirstStage = HL.Field(HL.Boolean) << false

WonderBuildSideInfo.m_hasRepeatReward = HL.Field(HL.Boolean) << false

WonderBuildSideInfo.m_curExp = HL.Field(HL.Number) << -1

WonderBuildSideInfo.m_lastExp = HL.Field(HL.Number) << -1

WonderBuildSideInfo.m_lastTrySubmitTs = HL.Field(HL.Number) << 0

WonderBuildSideInfo.m_animThread = HL.Field(HL.Thread)

WonderBuildSideInfo.m_isStopped = HL.Field(HL.Boolean) << false

WonderBuildSideInfo.m_leftNodeState = HL.Field(HL.String) << ""

WonderBuildSideInfo.m_bottomNodeState = HL.Field(HL.String) << ""

WonderBuildSideInfo.m_isInAccelerateTime = HL.Field(HL.Boolean) << false


WonderBuildSideInfo.m_isAccelerating = HL.Field(HL.Any)

WonderBuildSideInfo.m_itemCellCache = HL.Field(HL.Forward("UIListCache"))

WonderBuildSideInfo.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))

WonderBuildSideInfo.m_rewardCellStates = HL.Field(HL.Table)

WonderBuildSideInfo.m_repeatRewardCellCache = HL.Field(HL.Forward("UIListCache"))

WonderBuildSideInfo.m_repeatReward = HL.Field(HL.Any)

WonderBuildSideInfo.m_progressCellCache = HL.Field(HL.Forward("UIListCache"))

WonderBuildSideInfo.m_progressBarWidth = HL.Field(HL.Number) << 0

WonderBuildSideInfo.m_claimRewardBindingId = HL.Field(HL.Number) << 0


WonderBuildSideInfo._OnFirstTimeInit = HL.Override() << function(self)
    self:_InitButtons()
end

WonderBuildSideInfo.InitWonderBuildSideInfo = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()
    self:CleanUp()
    self:RegisterMessage(MessageConst.ON_WONDER_BUILD_REWARD_CHANGE, function()
        self:_OnRewardChange()
    end)
    self:RegisterMessage(MessageConst.ON_WONDER_BUILD_STAGE_UPGRADE, function()
        self:_OnStageUpgrade()
    end)
    self:RegisterMessage(MessageConst.ON_WONDER_BUILD_ACCELERATE_START, function()
        self:_OnAccelerateTimeChanged()
    end)
    self:RegisterMessage(MessageConst.ON_WONDER_BUILD_ACCELERATE_END, function()
        self:_OnAccelerateTimeChanged()
    end)
    self.m_rewardCellStates = {}

    self.m_stageId = arg.stageId
    self.m_wonderProgress = GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
    self.m_isInAccelerateTime = FactoryUtils.isInWonderBuildAccelerateTime()

    self:_InitStageData()
    self:_InitItemCells()
    if self.m_hasRepeatReward then
        self:_InitRepeatRewardCells()
    else
        self:_InitRewardCells()
    end
    self:_UpdateAll()
    self:_UpdateClaimBindingState()

    if self:_IsCurrentStage() then
        self:_StartCoroutine(function()
            while true do
                coroutine.step()
                self:_UpdateItemCells()
                self:_UpdateRebuildInfo()
                self:_UpdateCountdown()
            end
        end)
    end
end

WonderBuildSideInfo.CleanUp = HL.Method() << function(self)
    MessageManager:UnregisterAll(self)
    self.m_messageCache = {}
    CoroutineManager:ClearAllCoroutine(self)
    self.m_stageId = 0
    self.m_stageData = nil
    self.m_wonderProgress = nil
    self.m_animThread = nil
    self.m_lastExp = -1
    self.m_lastTrySubmitTs = 0
    self.m_curExp = -1
    self.m_isStopped = false
    self.m_leftNodeState = ""
    self.m_bottomNodeState = ""
    self.m_isAccelerating = nil
end

WonderBuildSideInfo._OnDestroy = HL.Override() << function(self)
    self:CleanUp()
end



WonderBuildSideInfo._InitButtons = HL.Method() << function(self)
    self.view.backBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_WONDER_BUILD_SIDE_INFO_BACK)
    end)

    self.view.prevStageBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_WONDER_BUILD_SIDE_INFO_PREV_STAGE, self.m_stageId)
    end)

    self.view.nextStageBtn.onClick:AddListener(function()
        Notify(MessageConst.ON_WONDER_BUILD_SIDE_INFO_NEXT_STAGE, self.m_stageId)
    end)

    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "instru_wonder_build_1")
    end)

    self.view.pickRepeatRewardBtn.onClick:AddListener(function()
        self:_OnClickPickRepeatReward()
    end)

    self.view.jumpMissionBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.Mission, {
            autoSelect = Tables.wonderStageTable[self.m_stageId].upgradeMission
        })
    end)

    self.m_claimRewardBindingId = InputManagerInst:CreateBindingByActionId("wonderbuild_claim_reward", function()
        self:_TakeReward()
    end, self.view.inputGroup.groupId)

    self.view.rewardSelectNaviGroup.getDefaultSelectableFunc = function()
        if self.m_hasRepeatReward then
            return self.view.repeatReward.view.button
        else
            if self.m_rewardCellCache then
                local firstCell = self.m_rewardCellCache:GetItem(1)
                if firstCell then
                    return firstCell.item1.view.button
                end
            end
        end
        return nil
    end
end





WonderBuildSideInfo._InitStageData = HL.Method() << function(self)
    local success, stageData = Tables.wonderStageTable:TryGetValue(self.m_stageId)
    if not success then
        logger.error("WonderBuildSideInfo: stageId %d not found in wonderStageTable", self.m_stageId)
        return
    end
    self.m_stageData = stageData
    self.view.stageTitleText.text = self.m_stageData.stageName
    self:_InitPhotos()
    self.m_isLastStage = not Tables.wonderStageTable:ContainsKey(self.m_stageId + 1)
    self.m_isFirstStage = not Tables.wonderStageTable:ContainsKey(self.m_stageId - 1)
    if self.m_isFirstStage then
        self.view.prevBtnState:SetState("Disabled")
        self.view.prevStageBtn.interactable = false
        self.view.prevRedDot.gameObject:SetActive(false)
    else
        self.view.prevBtnState:SetState("Normal")
        self.view.prevStageBtn.interactable = true
        self.view.prevRedDot:InitRedDot("WonderBuildStagePrev", self.m_stageId)
    end
    if self.m_isLastStage or self:_IsCurrentStage() then
        self.view.nextBtnState:SetState("Disabled")
        self.view.nextStageBtn.interactable = false
        self.view.nextRedDot.gameObject:SetActive(false)
    else
        self.view.nextBtnState:SetState("Normal")
        self.view.nextStageBtn.interactable = true
        self.view.nextRedDot:InitRedDot("WonderBuildStageNext", self.m_stageId)
    end
    self.view.prevBtnState.gameObject:SetActive(self.m_wonderProgress.stage ~= 1)
    self.view.nextBtnState.gameObject:SetActive(self.m_wonderProgress.stage ~= 1)

    local isCurrentStage = self:_IsCurrentStage()

    if isCurrentStage then
        self.m_curExp = self.m_wonderProgress.curExp
    elseif self.m_stageId < self.m_wonderProgress.stage then
        self.m_curExp = self.m_stageData.levelExp
    else
        self.m_curExp = 0
    end

    self.m_hasRepeatReward = false
    local rewards = stageData.wonderRewards
    if rewards ~= nil then
        for i = 0, rewards.length - 1 do
            if rewards[i].repeatedReward then
                self.m_hasRepeatReward = true
                break
            end
        end
    end
    
    self.view.repeatRewardRedDot:InitRedDot("WonderBuildRewardUnclaimed", self.m_stageId)
end





WonderBuildSideInfo._InitPhotos = HL.Method() << function(self)
    local photos = self.m_stageData.completePic
    for i = 1, PHOTO_COUNT do
        local photo = self.view["decoPhoto0" .. i]
        local photoName = photos ~= nil and i <= photos.length and photos[i - 1] or nil
        local hasPhoto = not string.isEmpty(photoName)
        photo.gameObject:SetActive(hasPhoto)
        if hasPhoto then
            photo:LoadSprite(PHOTO_SPRITE_PATH, photoName)
        else
            photo.sprite = nil
        end
    end
end





WonderBuildSideInfo._GetWonderProgress = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    return GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
end

WonderBuildSideInfo._IsCurrentStage = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_stageId > 0 and self.m_wonderProgress.stage == self.m_stageId
end





WonderBuildSideInfo._UpdateAll = HL.Method() << function(self)
    self:_UpdateRebuildInfo()
    self:_UpdateItemCells()
    if self.m_hasRepeatReward then
        self:_UpdateRepeatRewardCells()
    else
        self:_UpdateRewardCells()
    end
    self:_UpdateCountdown()
end





WonderBuildSideInfo._UpdateRebuildInfo = HL.Method() << function(self)
    if self.m_stageData == nil then
        return
    end

    local isCurrentStage = self:_IsCurrentStage()

    if isCurrentStage then
        self.m_curExp = self.m_wonderProgress.curExp
    end

    local levelExp = self.m_stageData.levelExp
    local isComplete = self.m_curExp >= levelExp

    self.view.curExpTxt.text = tostring(self.m_curExp)
    self.view.totalExpTxt.text = string.format("/%d", levelExp)

    local ratio = 0
    if levelExp > 0 then
        ratio = math.min(self.m_curExp / levelExp, 1)
    end

    if self.m_hasRepeatReward then
        self.view.progressBar.progressImg.fillAmount = ratio
        self:_UpdateProgressBarState(isComplete)
    else
        self:_UpdateMultiStageProgress()
    end

    local leftNodeState
    if self.m_hasRepeatReward then
        leftNodeState = "OngoingMaintain"
    elseif not isCurrentStage then
        leftNodeState = "Completed"
        if self.gameObject.activeInHierarchy then
            AudioManager.PostEvent("Au_UI_Toast_RebuildComplete")
        end
    elseif isComplete then
        leftNodeState = "ConstructionCompleted"
    else
        leftNodeState = "Build"
    end
    if self.m_leftNodeState ~= leftNodeState then
        if self.m_leftNodeState == "Build" and leftNodeState == "ConstructionCompleted" then
            if self.gameObject.activeInHierarchy then
                AudioManager.PostEvent("Au_UI_Event_RebuildPointComplete")
            end
        end
        self.m_leftNodeState = leftNodeState
        self.view.leftNode:SetState(leftNodeState)
    end
    
    self:_UpdateProgressImage(ratio)

    if isCurrentStage then
        self:_UpdateBottomNode(isComplete)
    end
    self:_UpdateRebuildState()
    self:_UpdateAccelerateState(isCurrentStage and not isComplete and self.m_isInAccelerateTime)
    self:_UpdateStageRemainTime()
end





WonderBuildSideInfo._CheckIsStopped = HL.Method().Return(HL.Boolean) << function(self)
    if not self:_IsCurrentStage() then
        return true
    end

    if not self.m_isLastStage then
        local levelExp = self.m_stageData.levelExp
        if self.m_curExp < levelExp then
            return false
        else
            return true
        end
    end

    local rewards = self.m_stageData.wonderRewards
    if rewards == nil then
        return true
    end
    for i = 0, rewards.length - 1 do
        local reward = rewards[i]
        if reward.repeatedReward and reward.accuCntLimit > 0 then
            local count = self.m_wonderProgress:GetRepeatedRewardCount(reward.index)
            if count < reward.accuCntLimit then
                return false
            end
        end
    end

    return true
end

WonderBuildSideInfo._SetBottomNodeState = HL.Method(HL.String) << function(self, stateName)
    if self.m_bottomNodeState == stateName then
        return
    end
    self.m_bottomNodeState = stateName
    self.view.bottomNode:SetState(stateName)
end

WonderBuildSideInfo._UpdateBottomNode = HL.Method(HL.Boolean) << function(self, isComplete)
    self.m_isStopped = self:_CheckIsStopped()

    if self.m_isStopped then
        self:_SetBottomNodeState("UpperLimit")
        return
    end

    self:_DetectSubmitResult()
    if self.m_animThread == nil then
        self:_SetBottomNodeState("AutoPay")
    end
end

WonderBuildSideInfo._DetectSubmitResult = HL.Method() << function(self)
    local curTs = self.m_wonderProgress.lastTrySubmitTs

    if self.m_lastExp < 0 then
        self.m_lastExp = self.m_curExp
        self.m_lastTrySubmitTs = curTs
        return
    end

    local tsChanged = curTs ~= self.m_lastTrySubmitTs
    local expChanged = self.m_curExp ~= self.m_lastExp

    self.m_lastExp = self.m_curExp
    self.m_lastTrySubmitTs = curTs

    if not tsChanged then
        return
    end

    if not expChanged then
        self:_PlayAnimState("Insufficient")
    else
        self:_PlayAnimState("AutoPayFinish")
    end
end

local ANIM_STATE_DURATION = 2

WonderBuildSideInfo._PlayAnimState = HL.Method(HL.String) << function(self, stateName)
    if self.m_animThread ~= nil then
        self.m_animThread = self:_ClearCoroutine(self.m_animThread)
    end

    self:_SetBottomNodeState(stateName)
    if stateName == "AutoPayFinish" then
        if self.gameObject.activeInHierarchy then
            AudioManager.PostEvent("Au_UI_Event_RebuildSupplySuccess")
        end
    elseif stateName == "Insufficient" then
        if self.gameObject.activeInHierarchy then
            AudioManager.PostEvent("Au_UI_Event_RebuildSupplyStop")
        end
    end
    self.m_animThread = self:_StartCoroutine(function()
        coroutine.wait(ANIM_STATE_DURATION)
        if not self.m_isStopped then
            self:_SetBottomNodeState("AutoPay")
            if self.gameObject.activeInHierarchy then
                AudioManager.PostEvent("Au_UI_Event_RebuildCountStart")
            end
        end
        self.m_animThread = nil
    end)
end





WonderBuildSideInfo._UpdateCountdown = HL.Method() << function(self)
    if self.m_isStopped or self.m_stageData == nil then
        return
    end

    if not self:_IsCurrentStage() then
        return
    end

    local lastTs = self.m_wonderProgress.lastTrySubmitTs
    if lastTs <= 0 then
        return
    end

    local interval = Tables.wonderBuildConst.costItemsInterval
    local nextTs = lastTs + interval
    local curTime = DateTimeUtils.GetCurrentTimestampByMilliseconds()/1000
    local remain = math.max(nextTs - curTime, 0)

    self.view.countdownTxt.text = string.format(Language.LUA_FAC_REBUILD_SUPPLY_COUNTDOWN, UIUtils.getLeftTimeToSecond(remain))

    local fillRatio = 0
    if interval > 0 then
        fillRatio = 1 - remain / interval
    end
    self.view.countdownProgress.fillAmount = lume.clamp(fillRatio, 0, 1)
end





WonderBuildSideInfo._UpdateRebuildState = HL.Method() << function(self)
    local submitTimes = self.m_wonderProgress.submitTimes
    local constData = Tables.wonderBuildConst
    local isNonFinalStageComplete = not self.m_isLastStage and self.m_curExp >= self.m_stageData.levelExp
    local isCurrentStage = self:_IsCurrentStage()
    local isSlow = isCurrentStage and not isNonFinalStageComplete and
        submitTimes >= constData.slowRebuildLowerBound and submitTimes < constData.slowRebuildUpperBound and not self.m_isStopped
    local isStopped = isCurrentStage and not isNonFinalStageComplete and submitTimes <= 0 and not self.m_isStopped
    local rebuildState = "Normal"
    if isStopped then
        rebuildState = "Stagnation"
    elseif isSlow then
        rebuildState = "Slow"
    end
    self.view.stateController:SetState(rebuildState)
end

WonderBuildSideInfo._UpdateAccelerateState = HL.Method(HL.Boolean) << function(self, isAccelerating)
    if self.m_isAccelerating == isAccelerating then
        return
    end
    self.m_isAccelerating = isAccelerating
    self.view.stateController:SetState(isAccelerating and "SpeedUp" or "NoSpeed")
end

WonderBuildSideInfo._UpdateStageRemainTime = HL.Method() << function(self)
    local showRemainTime = self:_IsCurrentStage() and self.m_curExp < self.m_stageData.levelExp
    
    self.view.boostRemainTimeTxt.transform.parent.gameObject:SetActive(showRemainTime)
    if not showRemainTime then
        return
    end

    local estimatedRemainTime = FactoryUtils.getCurWonderBuildStageEstimatedRemainTime(self.m_isInAccelerateTime)
    if self.m_isStopped then
        estimatedRemainTime = -1
    end
    local remainTimeText = estimatedRemainTime < 0 and "--:--" or UIUtils.getShortLeftTime(estimatedRemainTime)
    local language = self.m_hasRepeatReward and Language.LUA_FAC_REBUILD_SUPPLY_REPEAT_REWARD_REMAIN_TIME
        or Language.LUA_FAC_REBUILD_SUPPLY_STAGE_REMAIN_TIME
    self.view.boostRemainTimeTxt.text = string.format(language, remainTimeText)
end





WonderBuildSideInfo._InitTipsTxt = HL.Method() << function(self)
    if self.m_stageData == nil then
        return
    end
    local expGet = self.m_stageData.expCostItemsGet
    self.view.noSpeedTipTxt.text = string.format(Language.LUA_FAC_REBUILD_SUPPLY_TIPS, expGet)
    self.view.speedTipsTxt.text = string.format(Language.LUA_FAC_REBUILD_SUPPLY_ACCELERATE_TIPS,
        expGet + self.m_stageData.extraExpCostItemsGet)
end





WonderBuildSideInfo._InitProgressBar = HL.Method() << function(self)
    local rewards = self.m_stageData.wonderRewards
    local rewardCount = (rewards ~= nil) and rewards.length or 0

    if not self.m_hasRepeatReward then
        if self.m_progressCellCache == nil then
            self.m_progressCellCache = UIUtils.genCellCache(self.view.progressCell)
        end
        self.m_progressCellCache:Refresh(rewardCount, function(cell, index)
            cell.progressImg.fillAmount = 0
            cell.stateController:SetState("Nrl")
            if index > 1 then
                cell.leftNode.gameObject:SetActive(false)
            end
        end)
    end
end

WonderBuildSideInfo._UpdateMultiStageProgress = HL.Method() << function(self)
    if self.m_progressCellCache == nil or self.m_stageData == nil then
        return
    end

    local rewards = self.m_stageData.wonderRewards
    if rewards == nil then
        return
    end

    local rewardCount = rewards.length
    local hasNewlyReachedSegment = false

    self.m_progressCellCache:Update(function(cell, index)
        local csIndex = index - 1
        if csIndex >= rewardCount then
            return
        end

        local reward = rewards[csIndex]
        local segEnd = reward.wonderExp
        local segStart = 0
        if csIndex > 0 then
            segStart = rewards[csIndex - 1].wonderExp
        end

        local segRange = segEnd - segStart
        if segRange <= 0 then
            cell.progressImg.fillAmount = 1
            return
        end

        if self.m_curExp >= segEnd then
            cell.progressImg.fillAmount = 1
        elseif self.m_curExp <= segStart then
            cell.progressImg.fillAmount = 0
        else
            cell.progressImg.fillAmount = (self.m_curExp - segStart) / segRange
        end

        local reached = self.m_curExp >= segEnd
        if reached then
            if cell.stateController.currentStateName ~= "Receive" and self.m_lastExp >= 0 then
                hasNewlyReachedSegment = true
            end
            cell.stateController:SetState("Receive")
        else
            cell.stateController:SetState("Nrl")
        end
    end)
    if hasNewlyReachedSegment and self.m_curExp < self.m_stageData.levelExp then
        if self.gameObject.activeInHierarchy then
            AudioManager.PostEvent("Au_UI_Event_RebuildPointStart")
        end
    end
end

WonderBuildSideInfo._UpdateProgressImage = HL.Method(HL.Number) << function(self, ratio)
    self.m_progressBarWidth = self.view.progressBar.rectTransform.rect.width
    local width = self.m_progressBarWidth * ratio
    local sizeDelta = self.view.progressImage.sizeDelta
    sizeDelta.x = width
    self.view.progressImage.sizeDelta = sizeDelta
end

WonderBuildSideInfo._UpdateProgressBarState = HL.Method(HL.Boolean) << function(self, isComplete)
    local hasClaimableReward = false
    local rewards = self.m_stageData.wonderRewards
    if rewards ~= nil then
        for i = 0, rewards.length - 1 do
            local reward = rewards[i]
            if self.m_curExp >= reward.wonderExp and not self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index) then
                hasClaimableReward = true
                break
            end
        end
    end

    if isComplete then
        self.view.progressBar.stateController:SetState(hasClaimableReward and "LeftReceive" or "LeftNrl")
    else
        self.view.progressBar.stateController:SetState(hasClaimableReward and "Receive" or "Nrl")
    end
end





WonderBuildSideInfo._GetItemTipsExtraInfo = HL.Method(HL.Boolean).Return(HL.Table) << function(self, isReward)
    local extraInfo = {
        isSideTips = DeviceInfo.usingController,
        tipsPosTransform = self.view.tipAnchor,
    }
    if isReward then
        extraInfo.onBeforeJump = function()
            self.view.rewardNaviGroup:ManuallyStopFocus(false)
        end
    end
    return extraInfo
end

WonderBuildSideInfo._InitItemCells = HL.Method() << function(self)
    self:_InitProgressBar()
    self:_InitTipsTxt()

    local itemIds = self.m_stageData.expCostItemIds
    local itemCnts = self.m_stageData.expCostItemCnt
    local itemCount = itemIds.length

    if self.m_itemCellCache == nil then
        self.m_itemCellCache = UIUtils.genCellCache(self.view.itemCell)
    end
    self.m_itemCellCache:Refresh(ITEM_CELL_DISPLAY_COUNT, function(cell, index)
        cell.gameObject.name = string.format("Require_%d", index)
        local csIndex = index - 1
        if csIndex < itemCount then
            local itemId = itemIds[csIndex]
            local needCnt = itemCnts[csIndex]
            cell.item:InitItem({ id = itemId, count = needCnt }, true)
            cell.item.isWonderBuild = true
            cell.item:SetExtraInfo(self:_GetItemTipsExtraInfo(false))
            cell.stateController:SetState("Activate")
        else
            cell.stateController:SetState("Null")
        end
    end)
end

WonderBuildSideInfo._UpdateItemCells = HL.Method() << function(self)
    if self.m_itemCellCache == nil or self.m_stageData == nil then
        return
    end

    if not self:_IsCurrentStage() then
        return
    end
    local itemIds = self.m_stageData.expCostItemIds
    local itemCnts = self.m_stageData.expCostItemCnt

    local itemCount = itemIds.length

    self.m_itemCellCache:Update(function(cell, index)
        local csIndex = index - 1
        if csIndex >= itemCount then
            return
        end
        local itemId = itemIds[csIndex]
        local needCnt = itemCnts[csIndex]
        local currentCnt = self.m_wonderProgress:GetWonderItemCount(itemId)

        cell.payNumTxt.text = tostring(needCnt)
        cell.inventoryNumTxt.text = tostring(currentCnt)
        cell.inventoryNumTxt.color = currentCnt >= needCnt and self.view.config.NORMAL_COLOR or self.view.config.LACK_COLOR
    end)
end





WonderBuildSideInfo._InitRewardCells = HL.Method() << function(self)
    local rewards = self.m_stageData.wonderRewards

    local nonRepeatRewards = {}
    for i = 0, rewards.length - 1 do
        local reward = rewards[i]
        if not reward.repeatedReward then
            table.insert(nonRepeatRewards, reward)
        end
    end

    if #nonRepeatRewards == 0 then
        return
    end

    if self.m_rewardCellCache == nil then
        self.m_rewardCellCache = UIUtils.genCellCache(self.view.rewardCell)
    end
    self.m_rewardCellCache:Refresh(#nonRepeatRewards, function(cell, index)
        local reward = nonRepeatRewards[index]
        local rewardItems = UIUtils.getRewardItems(reward.rewardID)
        local hasReward1 = rewardItems and #rewardItems >= 1
        local hasReward2 = rewardItems and #rewardItems >= 2
        cell.item1.gameObject:SetActive(hasReward1)
        cell.item2.gameObject:SetActive(hasReward2)

        if hasReward1 then
            cell.item1:InitItem(rewardItems[1], function()
                local reached = self.m_curExp >= reward.wonderExp
                if reached and not self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index) then
                    self:_TakeReward()
                else
                    cell.item1:ShowTips()
                end
            end)
            cell.item1:SetExtraInfo(self:_GetItemTipsExtraInfo(true))
            cell.redDot1:InitRedDot("WonderBuildRewardUnclaimed", self.m_stageId)
        end
        if hasReward2 then
            cell.item2:InitItem(rewardItems[2], function()
                local reached = self.m_curExp >= reward.wonderExp
                if reached and not self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index) then
                    self:_TakeReward()
                else
                    cell.item2:ShowTips()
                end
            end)
            cell.item2:SetExtraInfo(self:_GetItemTipsExtraInfo(true))
            cell.redDot2:InitRedDot("WonderBuildRewardUnclaimed", self.m_stageId)
        end
    end)
end

WonderBuildSideInfo._UpdateRewardCells = HL.Method() << function(self)
    if self.m_rewardCellCache == nil or self.m_stageData == nil then
        return
    end

    local rewards = self.m_stageData.wonderRewards

    local nonRepeatRewards = {}
    for i = 0, rewards.length - 1 do
        local reward = rewards[i]
        if not reward.repeatedReward then
            table.insert(nonRepeatRewards, reward)
        end
    end


    self.m_rewardCellCache:Update(function(cell, index)
        if index > #nonRepeatRewards then
            return
        end
        local reward = nonRepeatRewards[index]
        local reached = self.m_curExp >= reward.wonderExp
        local claimed = self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index)

        local previousState = self.m_rewardCellStates[index]
        local state = claimed and "Received" or reached and "Completed" or "InProgress"
        self.m_rewardCellStates[index] = state
        cell.stateController:SetState(state)
        cell.receivedNode.gameObject:SetActive(claimed)
        if previousState ~= nil and previousState ~= "Received" and state == "Received" then
            cell.receiveAnim:PlayInAnimation()
        end

        cell.lineImage.fillAmount = reached and 1 or 0
    end)
end





WonderBuildSideInfo._InitRepeatRewardCells = HL.Method() << function(self)
    local rewards = self.m_stageData.wonderRewards

    
    local repeatReward = nil
    for i = 0, rewards.length - 1 do
        if rewards[i].repeatedReward then
            repeatReward = rewards[i]
            break
        end
    end

    if repeatReward == nil then
        return
    end

    self.m_repeatReward = repeatReward

    local rewardItems = UIUtils.getRewardItems(repeatReward.rewardID)
    if rewardItems and #rewardItems >= 1 then
        self.view.repeatReward:InitItem(rewardItems[1], true)
        self.view.repeatReward:SetExtraInfo(self:_GetItemTipsExtraInfo(true))
    end

    if self.m_repeatRewardCellCache == nil then
        self.m_repeatRewardCellCache = UIUtils.genCellCache(self.view.repeatRewardCell)
    end
    self:_UpdateRepeatRewardCells()
end

WonderBuildSideInfo._UpdateRepeatRewardCells = HL.Method() << function(self)
    if self.m_repeatRewardCellCache == nil or self.m_repeatReward == nil then
        return
    end

    local unclaimedCount = self.m_wonderProgress:GetRepeatedRewardCount(self.m_repeatReward.index)
    local rewardItems = UIUtils.getRewardItems(self.m_repeatReward.rewardID)
    self.view.repeatRewardNumTxt.text = string.format("%d/%d", unclaimedCount, self.m_repeatReward.accuCntLimit)
    self.view.repeatRewardNumShadowTxt.text = string.format("%d/%d", unclaimedCount, self.m_repeatReward.accuCntLimit)

    self.m_repeatRewardCellCache:Refresh(self.m_repeatReward.accuCntLimit, function(cell, index)
        if index <= unclaimedCount then
            if rewardItems and #rewardItems >= 1 then
                cell.item:InitItem(rewardItems[1], true)
                cell.item:SetExtraInfo(self:_GetItemTipsExtraInfo(true))
            end
            cell.stateController:SetState("Activate")
        else
            cell.stateController:SetState("Null")
        end
    end)

    if unclaimedCount > 0 then
        self.view.repeatRewardState:SetState("NormalState")
    else
        self.view.repeatRewardState:SetState("DisableState")
    end
end

WonderBuildSideInfo._OnClickPickRepeatReward = HL.Method() << function(self)
    self:_TakeReward()
end

WonderBuildSideInfo._TriggerTakeRewardCondition = HL.Method() << function(self)
    local condition = CS.Beyond.Gameplay.Conditions.OnWonderBuildTakeReward
    if not condition.needCheck or self.m_stageData == nil or self.m_wonderProgress == nil then
        return
    end

    local rewards = self.m_stageData.wonderRewards
    if rewards == nil then
        return
    end

    for i = 0, rewards.length - 1 do
        local reward = rewards[i]
        local canTakeReward
        if reward.repeatedReward then
            canTakeReward = self.m_wonderProgress:GetRepeatedRewardCount(reward.index) > 0
        else
            canTakeReward = self.m_curExp >= reward.wonderExp
                and not self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index)
        end

        if canTakeReward then
            local rewardItems = UIUtils.getRewardItems(reward.rewardID)
            for _, rewardItem in ipairs(rewardItems) do
                condition.Trigger(rewardItem.id)
            end
        end
    end
end

WonderBuildSideInfo._TakeReward = HL.Method() << function(self)
    self:_TriggerTakeRewardCondition()
    GameInstance.remoteFactoryManager.system.core:Message_WonderTakeReward(self.m_stageId)
end

WonderBuildSideInfo._UpdateClaimBindingState = HL.Method() << function(self)
    if self.m_claimRewardBindingId <= 0 then
        return
    end

    local hasClaimable = false
    local rewards = self.m_stageData.wonderRewards
    if rewards ~= nil then
        for i = 0, rewards.length - 1 do
            local reward = rewards[i]
            if reward.repeatedReward then
                local unclaimedCount = self.m_wonderProgress:GetRepeatedRewardCount(reward.index)
                if unclaimedCount > 0 then
                    hasClaimable = true
                    break
                end
            else
                local reached = self.m_curExp >= reward.wonderExp
                local claimed = self.m_wonderProgress:IsRewardClaimedByResIndex(reward.index)
                if reached and not claimed then
                    hasClaimable = true
                    break
                end
            end
        end
    end

    InputManagerInst:ToggleBinding(self.m_claimRewardBindingId, hasClaimable)
end





WonderBuildSideInfo._OnAccelerateTimeChanged = HL.Method() << function(self)
    if not self:_IsCurrentStage() then
        return
    end
    self.m_isInAccelerateTime = FactoryUtils.isInWonderBuildAccelerateTime()
    self:_UpdateRebuildInfo()
end

WonderBuildSideInfo._OnRewardChange = HL.Method() << function(self)
    self:_UpdateRebuildInfo()
    if self.m_hasRepeatReward then
        self:_UpdateRepeatRewardCells()
        self.view.repeatProgressAnim:PlayInAnimation()
    else
        self:_UpdateRewardCells()
    end
    self:_UpdateClaimBindingState()
end

WonderBuildSideInfo._OnStageUpgrade = HL.Method() << function(self)
    if not self:_IsCurrentStage() then
        return
    end
    self:_UpdateAll()
end



HL.Commit(WonderBuildSideInfo)
return WonderBuildSideInfo
