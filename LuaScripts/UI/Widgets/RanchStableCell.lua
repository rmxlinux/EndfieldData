local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local ranchSystem = GameInstance.player.ranchSystem

RanchStableCell = HL.Class('RanchStableCell', UIWidgetBase)

RanchStableCell.m_ranchId = HL.Field(HL.String) << ""
RanchStableCell.m_stableId = HL.Field(HL.String) << ""
RanchStableCell.m_stableCfg = HL.Field(HL.Any)
RanchStableCell.m_stableGroupId = HL.Field(HL.Number) << -1
RanchStableCell.m_hasAnimal = HL.Field(HL.Boolean) << false
RanchStableCell.m_animalData = HL.Field(HL.Userdata)
RanchStableCell.m_animalCfg = HL.Field(HL.Any)
RanchStableCell.m_cor = HL.Field(HL.Thread)
RanchStableCell.m_innSystem = HL.Field(HL.Userdata)
RanchStableCell.m_isInitialized = HL.Field(HL.Boolean) << false
RanchStableCell.m_isHighLevelProdUnlocked = HL.Field(HL.Boolean) << false
RanchStableCell.m_timeStateInitialized = HL.Field(HL.Boolean) << false 
RanchStableCell.m_fullnessAvailable = HL.Field(HL.Boolean) << false
RanchStableCell.m_happinessAvailable = HL.Field(HL.Boolean) << false
RanchStableCell.m_lowProductionFull = HL.Field(HL.Boolean) << false
RanchStableCell.m_highProductionFull = HL.Field(HL.Boolean) << false
RanchStableCell.m_playUnlockCamera = HL.Field(HL.Boolean) << false


RanchStableCell._OnFirstTimeInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.ON_RANCH_ANIMAL_UPDATED, function(arg)
        local stableId = unpack(arg)
        if not self.m_isInitialized or stableId ~= self.m_stableId then
            return
        end
        local _, tipsCtrl = UIManager:IsOpen(PanelId.InnRanchTips)
        if tipsCtrl and tipsCtrl.m_stableId == self.m_stableId then
            tipsCtrl:CloseTips()
        end
        
        self:RefreshRanchStableCell()
    end)

    
    self:RegisterMessage(MessageConst.ON_RANCH_PRODUCT_UPDATED, function()
        if self.m_isInitialized and self.m_hasAnimal and self.gameObject.activeInHierarchy then
            self:_RefreshProductionData()
        end
    end)

    
    self:RegisterMessage(MessageConst.ON_INN_LEVEL_UP, function()
        if self.m_isInitialized then
            self:RefreshRanchStableCell()
        end
    end)
end

RanchStableCell._OnEnable = HL.Override() << function(self)
    if not self.m_isInitialized or not self.m_hasAnimal then
        return
    end
    self:_RefreshProductionData()
    self:_RefreshTimeState(true)
    self:_StartTick()
end

RanchStableCell._OnDisable = HL.Override() << function(self)
    self:_StopTick()
end

RanchStableCell._OnDestroy = HL.Override() << function(self)
    self:_StopTick()
end

RanchStableCell.InitRanchStableCell = HL.Method(HL.Any) << function(self, arg)
    self:_FirstTimeInit()
    self.m_ranchId = arg.ranchId
    self.m_stableId = arg.stableId
    self.m_stableCfg = arg.stableCfg
    self.m_stableGroupId = arg.stableGroupId
    self.m_playUnlockCamera = arg.playUnlockCamera == true
    self.view.stateController:SetState(arg.style)
    self.m_innSystem = GameInstance.player.innSystem
    self.m_isInitialized = true
    self.m_timeStateInitialized = false

    self:RefreshRanchStableCell()
end

RanchStableCell.RefreshRanchStableCell = HL.Method() << function(self)
    self:_StopTick()
    local state
    self.m_hasAnimal = false
    self.m_animalData = nil
    self.m_animalCfg = nil
    self.m_lowProductionFull = false
    self.m_highProductionFull = false
    
    local isUnlock = ranchSystem:IsStableUnlocked(self.m_ranchId, self.m_stableId)
    if not isUnlock then
        
        if self.m_innSystem.innLevel <  self.m_stableCfg.unlockLevel then
            state = "LockLevel"
            self.view.lockNode.lockTxt.text = string.format(Language.LUA_RANCH_INN_LEVEL_LOCK, self.m_stableCfg.unlockLevel)
        else
            state = "LockMoney"
            local buyNode = self.view.buyNode
            buyNode.expendNumTxt.text = self.m_stableCfg.unlockCost
            
            local moneyId = self.m_stableCfg.moneyId
            if string.isEmpty(moneyId) then
                local domainId = Utils.getCurDomainId()
                local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
                moneyId = domainCfg.domainGoldItemId
            end
            local curMoneyCount = Utils.getItemCount(moneyId)
            local isMoneyNotEnough = curMoneyCount < self.m_stableCfg.unlockCost
            local itemData = Tables.itemTable:GetValue(moneyId)
            buyNode.iconCurrency:LoadSprite(UIConst.UI_SPRITE_WALLET, itemData.iconId)
            buyNode.stateController:SetState(isMoneyNotEnough and "MoneyNotEnough" or "MoneyEnough")
            buyNode.buyBtn.onClick:RemoveAllListeners()
            buyNode.buyBtn.onClick:AddListener(function()
                if ranchSystem.isStableUnlocking then
                    return
                end
                if isMoneyNotEnough then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_MONEY_NOT_ENOUGH_TOAST)
                    return
                end
                Notify(MessageConst.SHOW_POP_UP, {
                    content = string.format(Language.LUA_RANCH_STABLE_UNLOCK_CONFIRM_POP_UP, self.m_stableCfg.unlockCost),
                    onConfirm = function()
                        ranchSystem:SendRanchStableUnlock(self.m_ranchId, self.m_stableId, self.m_playUnlockCamera)
                    end
                })
            end)
        end

    else
        
        local hasAnimal, animalData = ranchSystem:GetStableAnimal(self.m_ranchId, self.m_stableId)
        if hasAnimal then
            self.m_hasAnimal = true
            self.m_animalData = animalData
            local _, animalCfg = Tables.innRanchAnimalTable:TryGetValue(animalData.animalId)
            self.m_animalCfg = animalCfg
            local occupiedNode = self.view.availableNode
            state = "Occupied"
            
            occupiedNode.animalNameTxt.text = animalCfg.name
            occupiedNode.iconAnimal:LoadSprite(UIConst.UI_SPRITE_INN_RANCH_ANIMAL, animalCfg.icon)

            
            local _, lowItemCfg = Tables.itemTable:TryGetValue(animalCfg.lowLevelProd)
            local _, highItemCfg = Tables.itemTable:TryGetValue(animalCfg.highLevelProd)
            self.view.productionNormalCell.productionIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, lowItemCfg.iconId)
            self.view.productionHighCell.productionIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, highItemCfg.iconId)
            occupiedNode.subProductionNode.gameObject:SetActive(false)
            occupiedNode.subAdvProductionNode.gameObject:SetActive(false)

            
            local stateNode = occupiedNode.stateNode
            local showTips = function()
                local _, feedManageCtrl = UIManager:IsOpen(PanelId.InnFeedManage)
                Notify(MessageConst.SHOW_ANIMAL_STATE_TIPS, {
                    transform = self.view.transform,
                    ranchId = self.m_ranchId,
                    stableId = self.m_stableId,
                    feedInputGroupId = occupiedNode.feedBtn.groupId,
                    hintPlaceholder = feedManageCtrl.view.controllerHintPlaceholder,
                })
            end
            stateNode.tips.gameObject:SetActive(false)
            stateNode.button.onClick:RemoveAllListeners()
            stateNode.button.onClick:AddListener(showTips)
            self.view.productionNormalCell.button.onClick:RemoveAllListeners()
            self.view.productionNormalCell.button.onClick:AddListener(showTips)
            self.view.productionHighCell.button.onClick:RemoveAllListeners()
            self.view.productionHighCell.button.onClick:AddListener(showTips)

            
            occupiedNode.feedBtn.onClick:RemoveAllListeners()
            occupiedNode.feedBtn.onClick:AddListener(function()
                local _, ranchData = GameInstance.player.ranchSystem:GetRanchData(self.m_ranchId)
                if ranchData then
                    local feedId = ranchData.feed.feedId
                    
                    if(string.isEmpty(feedId)) then
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_ANIMAL_FEED_EMPTY_TOAST)
                        return
                    end
                    
                    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
                    local _, feedCfg = Tables.innRanchFeedTable:TryGetValue(feedId)
                    local isHighLevelFeed = feedCfg.happinessAddSeconds > 0 
                    local _, fullnessCfg = Tables.innRanchStateTable:TryGetValue(GEnums.RanchStatusId.Fullness)
                    local fullnessIsFull = fullnessCfg and self.m_animalData.fullnessExhaustedTs - currentTime >= fullnessCfg.canFeedSeconds
                    local _, happinessCfg = Tables.innRanchStateTable:TryGetValue(GEnums.RanchStatusId.Happiness)
                    local happinessIsFull = happinessCfg and self.m_animalData.happinessExhaustedTs - currentTime >= happinessCfg.canFeedSeconds
                    
                    if not isHighLevelFeed and fullnessIsFull then
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_ANIMAL_FEED_FULL_ALREADY_TOAST)
                        return
                    end
                    if isHighLevelFeed and fullnessIsFull and happinessIsFull then
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_ANIMAL_FEED_HAPPY_ALREADY_TOAST)
                        return
                    end
                    
                    if GameInstance.player.inventory:IsItemFound(feedId) then
                        local feedCount = Utils.getItemCount(feedId, true, true)
                        local consumeCount = isHighLevelFeed and animalCfg.highLevelFoodConsume or animalCfg.lowLevelFoodConsume
                        if feedCount >= consumeCount then
                            ranchSystem:SendRanchAnimalFeed(self.m_ranchId, self.m_stableId)
                            
                            self:_PlayFullStateVx(occupiedNode.stateNode.hungerStateNode.vxStateHunger)
                            if isHighLevelFeed then
                                self:_PlayFullStateVx(occupiedNode.stateNode.happyStateNode.vxStateHappy)
                            end
                            Notify(MessageConst.SHOW_TOAST, string.format(Language.LUA_RANCH_ANIMAL_FEED_SUCCESS_TOAST, feedCfg.name, consumeCount))
                            return
                        end
                    end
                    
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_ANIMAL_FEED_USE_UP_TOAST)
                end
            end)
            occupiedNode.replaceBtn.onClick:RemoveAllListeners()
            occupiedNode.replaceBtn.onClick:AddListener(function()
                
                PhaseManager:OpenPhase(PhaseId.InnRanchAnimalAdd, {
                    ranchId = self.m_ranchId,
                    stableGroupId = self.m_stableGroupId,
                    stableId = self.m_stableId,
                    currentFeedAnimalId = self.m_animalData.animalId,
                })
            end)

            self:_RefreshHighProductionUnlock()
            self:_RefreshTimeState(true)
            self:_RefreshProductionData()
        else
            state = "Free"
            self.view.addNode.addBtn.onClick:RemoveAllListeners()
            self.view.addNode.addBtn.onClick:AddListener(function()
               
               PhaseManager:OpenPhase(PhaseId.InnRanchAnimalAdd, {
                   ranchId = self.m_ranchId,
                   stableGroupId = self.m_stableGroupId,
                   stableId = self.m_stableId,
               })
            end)
        end
    end

    self.view.stateController:SetState(state)
    if self.m_hasAnimal and self.gameObject.activeInHierarchy then
        self:_StartTick()
    end
end

RanchStableCell._RefreshStateVx = HL.Method(HL.Boolean, HL.Boolean) << function(self, fullnessAvailable, happinessAvailable)
    local availableNode = self.view.availableNode
    availableNode.vxHappy.gameObject:SetActive(fullnessAvailable)
    availableNode.vxHunger.gameObject:SetActive(not fullnessAvailable)
    local fullAndHappy = fullnessAvailable
    if InnUtils.isRanchHighProductionUnLock() then
        fullAndHappy = happinessAvailable and fullnessAvailable
    end
    availableNode.decoVxHappy01.gameObject:SetActive(fullAndHappy) 
    availableNode.decoVxHappy02.gameObject:SetActive(not happinessAvailable)
end

RanchStableCell._PlayFullStateVx = HL.Method(CS.Beyond.UI.UIAnimationWrapper) << function(self, vx)
    vx.gameObject:SetActive(true)
    vx:PlayInAnimation(function()
        vx.gameObject:SetActive(false)
    end)
end

RanchStableCell._RefreshHighProductionUnlock = HL.Method() << function(self)
    self.m_isHighLevelProdUnlocked = InnUtils.isRanchHighProductionUnLock()
    self.view.availableNode.stateNode.happyStateNode.gameObject:SetActive(self.m_isHighLevelProdUnlocked)
    self.view.productionHighCell.gameObject:SetActive(self.m_isHighLevelProdUnlocked)
end

RanchStableCell._RefreshProductionData = HL.Method() << function(self)
    if not self.m_hasAnimal or not self.m_animalData or not self.m_animalCfg then
        return
    end

    local animalData = self.m_animalData
    local lowLevelProdMaxCount = self.m_animalCfg.lowLevelProdMaxCount
    local lowCount = animalData.lowLevelProdCount
    local normalCell = self.view.productionNormalCell
    normalCell.productNumText.text = string.format("%d/%d", lowCount, lowLevelProdMaxCount)
    self.m_lowProductionFull = lowCount >= lowLevelProdMaxCount

    local highLevelProdMaxCount = self.m_animalCfg.highLevelProdMaxCount
    local highCount = animalData.highLevelProdCount
    local highCell = self.view.productionHighCell
    highCell.productNumText.text = string.format("%d/%d", highCount, highLevelProdMaxCount)
    self.m_highProductionFull = highCount >= highLevelProdMaxCount

    self:_RefreshProductionProgress(DateTimeUtils.GetCurrentTimestampBySeconds())
    self:_RefreshProductionState()
end

RanchStableCell._RefreshProductionProgress = HL.Method(HL.Number) << function(self, currentTime)
    if not self.m_hasAnimal or not self.m_animalData or not self.m_animalCfg then
        return
    end

    local animalData = self.m_animalData
    local periodSec = Const.SEC_PER_HOUR
    local refreshProgress = function(cell, accumulatedSecs, productCount, productMaxCount, isHighLevel)
        local progressTime = currentTime
        if productCount >= productMaxCount then
            progressTime = animalData.lastUpdateTs
        else
            progressTime = math.min(progressTime, animalData.fullnessExhaustedTs)
            if isHighLevel then
                progressTime = math.min(progressTime, animalData.happinessExhaustedTs)
            end
        end
        local elapsedSinceLastUpdate = math.max(0, progressTime - animalData.lastUpdateTs)
        local cycleElapsedSec = (math.max(0, accumulatedSecs) + elapsedSinceLastUpdate) % periodSec
        cell.numSlider.value = cycleElapsedSec / periodSec
    end

    refreshProgress(self.view.productionNormalCell, animalData.ordinarySecs, animalData.lowLevelProdCount,
                    self.m_animalCfg.lowLevelProdMaxCount, false)
    if self.m_isHighLevelProdUnlocked then
        refreshProgress(self.view.productionHighCell, animalData.advanceSecs, animalData.highLevelProdCount,
                        self.m_animalCfg.highLevelProdMaxCount, true)
    end
end

RanchStableCell._RefreshProductionState = HL.Method() << function(self)
    if not self.m_hasAnimal then
        return
    end

    local normalCell = self.view.productionNormalCell
    
    local normalStopped = self.m_lowProductionFull or not self.m_fullnessAvailable
    if not normalStopped then
        normalCell.stateController:SetState("StateProduct")
    else
         normalCell.stateController:SetState("StateStop")
         if self.m_lowProductionFull then
             normalCell.stateController:SetState("Full")
         end
    end

    if not self.m_isHighLevelProdUnlocked then
        return
    end

    local highCell = self.view.productionHighCell
    local highStopped = self.m_highProductionFull or not self.m_fullnessAvailable or not self.m_happinessAvailable
    if not highStopped then
        highCell.stateController:SetState("StateProduct")
    else
         highCell.stateController:SetState("StateStop")
         if self.m_highProductionFull then
            highCell.stateController:SetState("Full")
         end
    end
end

RanchStableCell._RefreshTimeState = HL.Method(HL.Opt(HL.Boolean)) << function(self, forceRefreshState)
    if not self.m_hasAnimal or not self.m_animalData then
        return
    end

    local animalData = self.m_animalData
    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local fullnessAvailable = currentTime < animalData.fullnessExhaustedTs
    local happinessAvailable = currentTime < animalData.happinessExhaustedTs

    local stateNode = self.view.availableNode.stateNode
    stateNode.happyStateNode.happyBar.fillAmount = math.max(0, animalData.happinessExhaustedTs - currentTime) / 86400
    stateNode.hungerStateNode.hungerBar.fillAmount = math.max(0, animalData.fullnessExhaustedTs - currentTime) / 86400

    local stateChanged = forceRefreshState or not self.m_timeStateInitialized
            or fullnessAvailable ~= self.m_fullnessAvailable
            or happinessAvailable ~= self.m_happinessAvailable

    if stateChanged and self.m_timeStateInitialized 
        and fullnessAvailable and (not self.m_isHighLevelProdUnlocked or happinessAvailable) 
        and (not self.m_fullnessAvailable or (self.m_isHighLevelProdUnlocked and not self.m_happinessAvailable)) then 
        AudioManager.PostEvent("Au_UI_Toast_FarmStartWork")
    end
    self.m_fullnessAvailable = fullnessAvailable
    self.m_happinessAvailable = happinessAvailable
    self.m_timeStateInitialized = true
    self:_RefreshProductionProgress(currentTime)
    if not stateChanged then
        return
    end

    stateNode.hungerStateNode.stateController:SetState(fullnessAvailable and "Normal" or "Null")
    if self.m_isHighLevelProdUnlocked then
        stateNode.happyStateNode.stateController:SetState(happinessAvailable and "Normal" or "Null")
    end
    self:_RefreshStateVx(fullnessAvailable, happinessAvailable)
    
    self:_RefreshProductionState()
end

RanchStableCell._StartTick = HL.Method() << function(self)
    self:_StopTick()
    if not self.m_isInitialized or not self.m_hasAnimal or not self.gameObject.activeInHierarchy then
        return
    end
    self.m_cor = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.COMMON_UI_TIME_UPDATE_INTERVAL)
            self:_RefreshTimeState()
        end
    end)
end

RanchStableCell._StopTick = HL.Method() << function(self)
    if self.m_cor then
        self.m_cor = self:_ClearCoroutine(self.m_cor)
    end
end

HL.Commit(RanchStableCell)
return RanchStableCell

