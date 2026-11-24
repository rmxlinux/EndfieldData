
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacRebuildSupplyPort
local MismatchItemReason = CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_WonderSupply.MismatchItemReason

local SMART_ALERT_FUNCTION_NAME_LIST = {
    "_CheckAlertWonderPortInvalidSupplyCondition",
}

FacRebuildSupplyPortCtrl = HL.Class('FacRebuildSupplyPortCtrl', uiCtrl.UICtrl)

FacRebuildSupplyPortCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_START] = '_OnAccelerateTimeChanged',
    [MessageConst.ON_WONDER_BUILD_ACCELERATE_END] = '_OnAccelerateTimeChanged',
}

FacRebuildSupplyPortCtrl.m_nodeId = HL.Field(HL.Any)

FacRebuildSupplyPortCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_WonderSupply)

FacRebuildSupplyPortCtrl.m_isInBlackbox = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_isAccelerating = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_itemCellCache = HL.Field(HL.Forward("UIListCache"))


FacRebuildSupplyPortCtrl.m_stageData = HL.Field(HL.Any)

FacRebuildSupplyPortCtrl.m_lastExp = HL.Field(HL.Number) << -1

FacRebuildSupplyPortCtrl.m_lastTrySubmitTs = HL.Field(HL.Number) << 0

FacRebuildSupplyPortCtrl.m_animThread = HL.Field(HL.Thread)

FacRebuildSupplyPortCtrl.m_isStopped = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_isLastStage = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_isMultiStage = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_hasRepeatReward = HL.Field(HL.Boolean) << false

FacRebuildSupplyPortCtrl.m_progressCellCache = HL.Field(HL.Forward("UIListCache"))

FacRebuildSupplyPortCtrl.m_progressBarWidth = HL.Field(HL.Number) << 0


FacRebuildSupplyPortCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    self.m_isInBlackbox = Utils.isInBlackbox()
    self.m_isAccelerating = not self.m_isInBlackbox and FactoryUtils.isInWonderBuildAccelerateTime()
    local nodeId = self.m_uiInfo.nodeId
    self.m_nodeId = nodeId

    self.view.facCacheBelt:InitFacCacheBelt(self.m_uiInfo, {
        noGroup = true,
    })

    self.view.buildingCommon:InitBuildingCommon(self.m_uiInfo, {
        onStateChanged = function(state)
            self:_OnBuildingStateChanged(state)
        end,
        smartAlertFuncNameList = SMART_ALERT_FUNCTION_NAME_LIST,
        targetCtrlInstance = self,
    })

    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(nodeId)

    self:_InitItemCells()
    self:_UpdateAccelerateState()
    self:_InitRebuildInfo()
    self:_InitCheckBtn()
    self:_InitNaviGroup()
    self:_UpdateCountdown()

    self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdateItemCells()
            self:_UpdateRebuildInfo()
            self:_UpdateCountdown()
        end
    end)

    if DeviceInfo.usingController then
        self:SetNaviTarget(self.view.buildingCommon.view.moveButton)
    end
end

FacRebuildSupplyPortCtrl.OnClose = HL.Override() << function(self)
    if self.m_animThread ~= nil then
        self.m_animThread = self:_ClearCoroutine(self.m_animThread)
    end
    self.view.buildingCommon:ClearSmartAlertUpdate()
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_nodeId)
end

FacRebuildSupplyPortCtrl._OnBuildingStateChanged = HL.Method(HL.Userdata) << function(self, state)
    self:_UpdateRebuildInfo()
end

FacRebuildSupplyPortCtrl._OnAccelerateTimeChanged = HL.Method() << function(self)
    local isAccelerating = not self.m_isInBlackbox and FactoryUtils.isInWonderBuildAccelerateTime()
    if self.m_isAccelerating == isAccelerating then
        return
    end
    self.m_isAccelerating = isAccelerating
    self:_UpdateAccelerateState()
    self:_UpdateStageRemainTime()
end



FacRebuildSupplyPortCtrl._GetWonderProgress = HL.Method().Return(HL.Opt(HL.Userdata)) << function(self)
    return GameInstance.remoteFactoryManager.system.core.progressStatus.wonderProgress
end

FacRebuildSupplyPortCtrl._GetCurrentStage = HL.Method().Return(HL.Number) << function(self)
    if self.m_isInBlackbox then
        local curLevel = GameWorld.worldInfo and GameWorld.worldInfo.curLevel
        local levelData = curLevel and curLevel.levelData
        local blackboxData = levelData and levelData.blackbox
        local wonderData = blackboxData and blackboxData.wonder
        return wonderData and wonderData.wonderStage or 0
    end

    local wonderProgress = self:_GetWonderProgress()
    return wonderProgress and wonderProgress.stage or 0
end





FacRebuildSupplyPortCtrl._InitRebuildInfo = HL.Method() << function(self)
    local currentStage = self:_GetCurrentStage()
    local success, stageData = Tables.wonderStageTable:TryGetValue(currentStage)
    if not success then
        return
    end

    self.view.rebuildingTitleTxt.text = stageData.stageName
    self:_UpdateRebuildInfo()
end

FacRebuildSupplyPortCtrl._UpdateRebuildInfo = HL.Method() << function(self)
    if self.m_stageData == nil then
        return
    end

    if self.m_isInBlackbox then
        self.view.rebuildingNumTxt.text = "0/1"
        self.view.progressBar.progressImg.fillAmount = 0
        self.view.leftNodeState:SetState("Progress")
        self:_UpdateProgressImage(0)
        self.view.bottomNode:SetState("Time")
        self.view.countdownTxt.text = Language.LUA_FAC_REBUILD_SUPPLY_BLACKBOX_NO_PAYMENT
        self.view.countdownProgress.fillAmount = 0
        self.view.stateController:SetState("Normal")
        self.view.boostRemainTimeNode.gameObject:SetActive(false)
        return
    end

    local wonderProgress = self:_GetWonderProgress()
    if wonderProgress == nil then
        return
    end

    local curExp = wonderProgress.curExp
    local levelExp = self.m_stageData.levelExp
    local isComplete = curExp >= levelExp

    if curExp == 0 then
        self.view.rebuildingNumTxt.text = string.format("%d/%d", curExp, levelExp)
    else
        self.view.rebuildingNumTxt.text = string.format("<color=#feff0f>%d</color>/%d", curExp, levelExp)
    end

    local ratio = 0
    if levelExp > 0 then
        ratio = math.min(curExp / levelExp, 1)
    end

    if self.m_isMultiStage then
        self:_UpdateMultiStageProgress(wonderProgress, curExp)
    else
        self.view.progressBar.progressImg.fillAmount = ratio
    end

    if isComplete then
        if self.view.leftNodeState.currentStateName == "Progress" then
            if self.view.gameObject.activeInHierarchy then
                AudioManager.PostEvent("Au_UI_Toast_RebuildComplete")
            end
        end
        self.view.leftNodeState:SetState("Complete", false)
    else
        self.view.leftNodeState:SetState("Progress", false)
    end

    self:_UpdateProgressImage(ratio)
    self:_UpdateBottomNode(wonderProgress, isComplete)
    self:_UpdateRebuildState(wonderProgress)
    self:_UpdateStageRemainTime()
    self:_UpdateProgressBarState()
end

FacRebuildSupplyPortCtrl._CheckIsStopped = HL.Method().Return(HL.Boolean) << function(self)
    local wonderProgress = self:_GetWonderProgress()
    if wonderProgress == nil or self.m_stageData == nil then
        return true
    end

    if not self.m_isLastStage then
        local curExp = wonderProgress.curExp
        local levelExp = self.m_stageData.levelExp
        if curExp < levelExp then
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
            local count = wonderProgress:GetRepeatedRewardCount(reward.index)
            if count < reward.accuCntLimit then
                return false
            end
        end
    end

    return true
end

FacRebuildSupplyPortCtrl._UpdateBottomNode = HL.Method(HL.Userdata, HL.Boolean) << function(self, wonderProgress, isComplete)
    self.m_isStopped = self:_CheckIsStopped()

    if self.m_isStopped then
        if not self.m_isLastStage then
            self.view.bottomNode:SetState("BuildDone", false)
        else
            self.view.bottomNode:SetState("Pause", false)
        end
        return
    end

    self:_DetectSubmitResult(wonderProgress)
    if self.m_animThread == nil then
        self.view.bottomNode:SetState("Time", false)
    end
end

FacRebuildSupplyPortCtrl._DetectSubmitResult = HL.Method(HL.Userdata) << function(self, wonderProgress)
    local curExp = wonderProgress.curExp
    local curTs = wonderProgress.lastTrySubmitTs

    if self.m_lastExp < 0 then
        self.m_lastExp = curExp
        self.m_lastTrySubmitTs = curTs
        return
    end

    local tsChanged = curTs ~= self.m_lastTrySubmitTs
    local expChanged = curExp ~= self.m_lastExp

    self.m_lastExp = curExp
    self.m_lastTrySubmitTs = curTs

    if not tsChanged then
        return
    end

    if expChanged then
        self:_PlayAnimState("PayDone")
    else
        self:_PlayAnimState("Fail")
    end
end

local ANIM_STATE_DURATION = 2

FacRebuildSupplyPortCtrl._PlayAnimState = HL.Method(HL.String) << function(self, stateName)
    if self.m_animThread ~= nil then
        self.m_animThread = self:_ClearCoroutine(self.m_animThread)
    end

    self.view.bottomNode:SetState(stateName)
    if self.view.gameObject.activeInHierarchy then
        if stateName == "PayDone" then
            AudioManager.PostEvent("Au_UI_Event_RebuildSupplySuccess")
        elseif stateName == "Fail" then
            AudioManager.PostEvent("Au_UI_Event_RebuildSupplyStop")
        end
    end
    self.m_animThread = self:_StartCoroutine(function()
        coroutine.wait(ANIM_STATE_DURATION)
        if not self.m_isStopped then
            self.view.bottomNode:SetState("Time")
            if self.view.gameObject.activeInHierarchy then
                AudioManager.PostEvent("Au_UI_Event_RebuildCountStart")
            end
        end
        self.m_animThread = nil
    end)
end

FacRebuildSupplyPortCtrl._UpdateCountdown = HL.Method() << function(self)
    if self.m_isInBlackbox or self.m_isStopped or self.m_stageData == nil then
        return
    end

    local wonderProgress = self:_GetWonderProgress()
    if wonderProgress == nil then
        return
    end

    local lastTs = wonderProgress.lastTrySubmitTs
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

FacRebuildSupplyPortCtrl._UpdateRebuildState = HL.Method(HL.Userdata) << function(self, wonderProgress)
    local submitTimes = wonderProgress.submitTimes
    local constData = Tables.wonderBuildConst
    local isNonFinalStageComplete = not self.m_isLastStage and wonderProgress.curExp >= self.m_stageData.levelExp
    local isSlow = not isNonFinalStageComplete and
        submitTimes >= constData.slowRebuildLowerBound and submitTimes < constData.slowRebuildUpperBound and not self.m_isStopped
    local isStagnation = not isNonFinalStageComplete and submitTimes <= 0 and not self.m_isStopped

    local rebuildState = "Normal"
    if isStagnation then
        rebuildState = "Stagnation"
    elseif isSlow then
        rebuildState = "Slow"
    end
    self.view.stateController:SetState(rebuildState)
end





FacRebuildSupplyPortCtrl._InitCheckBtn = HL.Method() << function(self)
    self.view.checkBtn.onClick:AddListener(function()
        self:_OnClickCheck()
    end)

    if self.m_isInBlackbox then
        self.view.redDot.gameObject:SetActive(false)
    else
        self.view.redDot:InitRedDot("WonderBuild")
    end

end

FacRebuildSupplyPortCtrl._UpdateAccelerateState = HL.Method() << function(self)
    self.view.stateController:SetState(self.m_isAccelerating and "SpeedUp" or "NoSpeed")
    if self.m_stageData == nil then
        return
    end

    local expGet = self.m_stageData.expCostItemsGet
    local tipLanguage = Language.LUA_FAC_REBUILD_SUPPLY_TIPS
    if self.m_isAccelerating then
        expGet = expGet + self.m_stageData.extraExpCostItemsGet
        tipLanguage = Language.LUA_FAC_REBUILD_SUPPLY_ACCELERATE_TIPS
    end
    self.view.tipsTxtText.text = string.format(tipLanguage, expGet)
end

FacRebuildSupplyPortCtrl._UpdateStageRemainTime = HL.Method() << function(self)
    local showRemainTime = not self.m_isInBlackbox and self.m_stageData ~= nil
        and self:_GetWonderProgress().curExp < self.m_stageData.levelExp
    self.view.boostRemainTimeNode.gameObject:SetActive(showRemainTime)
    if not showRemainTime then
        return
    end

    local estimatedRemainTime = FactoryUtils.getCurWonderBuildStageEstimatedRemainTime(self.m_isAccelerating)
    if self.m_isStopped then
        estimatedRemainTime = -1
    end
    local remainTimeText = estimatedRemainTime < 0 and "--:--" or UIUtils.getShortLeftTime(estimatedRemainTime)
    local language = self.m_hasRepeatReward and Language.LUA_FAC_REBUILD_SUPPLY_REPEAT_REWARD_REMAIN_TIME
        or Language.LUA_FAC_REBUILD_SUPPLY_STAGE_REMAIN_TIME
    self.view.remainTimeTxt.text = string.format(language, remainTimeText)
end

FacRebuildSupplyPortCtrl._OnClickCheck = HL.Method() << function(self)
    if self.m_isInBlackbox then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_REBUILD_SUPPLY_BLACKBOX_CHECK_UNAVAILABLE)
        return
    end
    PhaseManager:GoToPhase(PhaseId.WonderBuild, { domainId = Utils.getCurDomainId() })
end



FacRebuildSupplyPortCtrl._InitProgressBar = HL.Method() << function(self)
    self.m_progressBarWidth = self.view.progressBar.rectTransform.rect.width

    if self.m_isInBlackbox then
        self.m_isMultiStage = false
        self.view.leftNodeState:SetState("SingleStage")
        return
    end

    local rewards = self.m_stageData.wonderRewards
    local rewardCount = (rewards ~= nil) and rewards.length or 0
    self.m_isMultiStage = rewardCount > 1

    if self.m_isMultiStage then
        self.view.leftNodeState:SetState("MultiStage")
        self.m_progressCellCache = UIUtils.genCellCache(self.view.progressCell)
        self.m_progressCellCache:Refresh(rewardCount, function(cell, index)
            cell.progressImg.fillAmount = 0
            cell.stateController:SetState("Nrl")
            if index > 1 then
                cell.leftNode.gameObject:SetActive(false)
            end
        end)
    else
        self.view.leftNodeState:SetState("SingleStage")
    end
end

FacRebuildSupplyPortCtrl._UpdateMultiStageProgress = HL.Method(HL.Userdata, HL.Number) << function(self, wonderProgress, curExp)
    if self.m_progressCellCache == nil or self.m_stageData == nil then
        return
    end

    local rewards = self.m_stageData.wonderRewards
    if rewards == nil then
        return
    end

    local rewardCount = rewards.length

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

        if curExp >= segEnd then
            cell.progressImg.fillAmount = 1
        elseif curExp <= segStart then
            cell.progressImg.fillAmount = 0
        else
            cell.progressImg.fillAmount = (curExp - segStart) / segRange
        end

        local reached = curExp >= segEnd
        if reached then
            cell.stateController:SetState("Receive")
        else
            cell.stateController:SetState("Nrl")
        end
    end)
end

FacRebuildSupplyPortCtrl._UpdateProgressImage = HL.Method(HL.Number) << function(self, ratio)
    local width = self.m_progressBarWidth * ratio
    local sizeDelta = self.view.progressImage.sizeDelta
    sizeDelta.x = width
    self.view.progressImage.sizeDelta = sizeDelta
end



FacRebuildSupplyPortCtrl._UpdateProgressBarState = HL.Method() << function(self)
    if self.m_isMultiStage then
        return
    end

    local wonderProgress = self:_GetWonderProgress()
    if wonderProgress == nil then
        return
    end
    if self.m_stageData == nil then
        return
    end

    local curExp = wonderProgress.curExp
    local hasClaimableReward = false
    local rewards = self.m_stageData.wonderRewards
    if rewards ~= nil then
        for i = 0, rewards.length - 1 do
            local reward = rewards[i]
            if curExp >= reward.wonderExp and not wonderProgress:IsRewardClaimedByResIndex(reward.index) then
                hasClaimableReward = true
                break
            end
        end
    end

    local isComplete = curExp >= self.m_stageData.levelExp
    if isComplete then
        self.view.progressBar.stateController:SetState(hasClaimableReward and "LeftReceive" or "LeftNrl")
    else
        self.view.progressBar.stateController:SetState(hasClaimableReward and "Receive" or "Nrl")
    end
end





FacRebuildSupplyPortCtrl._InitNaviGroup = HL.Method() << function(self)
    self.view.itemSelectNaviGroup.getDefaultSelectableFunc = function()
        local cell = self.m_itemCellCache:Get(1)
        if cell then
            return cell.item.view.button
        end
        return nil
    end
end





FacRebuildSupplyPortCtrl._InitItemCells = HL.Method() << function(self)
    local currentStage = self:_GetCurrentStage()
    local success, stageData = Tables.wonderStageTable:TryGetValue(currentStage)
    if not success then
        return
    end
    self.m_stageData = stageData
    self.m_isLastStage = not Tables.wonderStageTable:ContainsKey(currentStage + 1)
    self.m_hasRepeatReward = false
    local rewards = stageData.wonderRewards
    if rewards ~= nil then
        for index = 0, rewards.length - 1 do
            if rewards[index].repeatedReward then
                self.m_hasRepeatReward = true
                break
            end
        end
    end
    self:_InitProgressBar()

    local itemIds = stageData.expCostItemIds
    local itemCnts = stageData.expCostItemCnt
    local itemCount = itemIds.length
    local CELL_COUNT = 3

    self.m_itemCellCache = UIUtils.genCellCache(self.view.itemCell)
    self.m_itemCellCache:Refresh(CELL_COUNT, function(cell, index)
        cell.gameObject.name = string.format("Require_%d", index)
        local csIndex = index - 1
        if csIndex < itemCount then
            local itemId = itemIds[csIndex]
            local needCnt = itemCnts[csIndex]
            cell.item:InitItem({ id = itemId, count = needCnt }, true)
            cell.item:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
            local itemData = Tables.itemTable:GetValue(itemId)
            if itemData then
                cell.nameTxt.text = itemData.name
            end
            cell.stateController:SetState("Nrl")
        else
            cell.stateController:SetState("Empty")
        end
    end)

    self:_UpdateItemCells()
end

FacRebuildSupplyPortCtrl._UpdateItemCells = HL.Method() << function(self)
    if self.m_itemCellCache == nil or self.m_stageData == nil then
        return
    end

    local wonderProgress
    local blackboxDepot
    if self.m_isInBlackbox then
        local factoryDepot = GameInstance.player.inventory.factoryDepot
        local depotInChapter = factoryDepot:GetOrFallback(Utils.getCurrentScope())
        blackboxDepot = depotInChapter[Utils.getCurrentChapterId()]
    else
        wonderProgress = self:_GetWonderProgress()
        if wonderProgress == nil then
            return
        end
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
        local currentCnt
        if self.m_isInBlackbox then
            currentCnt = blackboxDepot and blackboxDepot:GetCount(itemId) or 0
        else
            currentCnt = wonderProgress:GetWonderItemCount(itemId)
        end
        local isLack = currentCnt < needCnt

        if isLack then
            cell.payNumTxt.text = string.format("%d/<color=#FF8080>%d</color>", needCnt, currentCnt)
        else
            cell.payNumTxt.text = string.format("%d/%d", needCnt, currentCnt)
        end
    end)
end





FacRebuildSupplyPortCtrl._CheckAlertWonderPortInvalidSupplyCondition = HL.Method(HL.Userdata)
    .Return(HL.Boolean, HL.Opt(HL.Table)) << function(self, state)
    if self.m_stageData == nil then
        return false
    end

    local inPortList = FactoryUtils.getBuildingPortState(self.m_nodeId, false)
    if inPortList == nil then
        return false
    end

    local mismatchData = self.m_uiInfo.blockedMismatchItems
    local inBeltList = self.view.facCacheBelt.m_inBeltList

    for i = 0, mismatchData.Count - 1 do
        local beltCell = inBeltList and inBeltList:GetItem(mismatchData[i].portIndex+1) or nil
        local alertType
        if mismatchData[i].reason == MismatchItemReason.ItemIdMismatch then
            alertType = GEnums.FacSmartAlertType.WonderPortInvalidSupply
        elseif mismatchData[i].reason == MismatchItemReason.ItemIsFull then
            alertType = GEnums.FacSmartAlertType.WonderPortUpLimit
        end
        local checkOpen = DeviceInfo.usingController and
            self:GetSortingOrder() >= UIManager:CurBlockKeyboardEventPanelOrder()
        local alertInfo = {
            condition = alertType,
            targetTransform = beltCell.transform,
            defaultOpen = checkOpen,
        }
        return true, alertInfo
    end
    return false
end



HL.Commit(FacRebuildSupplyPortCtrl)
