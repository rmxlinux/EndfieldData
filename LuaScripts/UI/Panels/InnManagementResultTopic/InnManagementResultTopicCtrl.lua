local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnManagementResultTopic
local PHASE_ID = PhaseId.InnManagementResultTopic

local FRIENDSHIP_UI_STATE = {
    [1] = "Less",
    [2] = "Little",
    [3] = "Large",
    [4] = "Huge",
}

InnManagementResultTopicCtrl = HL.Class('InnManagementResultTopicCtrl', uiCtrl.UICtrl)

InnManagementResultTopicCtrl.m_resultData = HL.Field(HL.Userdata)
InnManagementResultTopicCtrl.m_hasReward = HL.Field(HL.Boolean) << false
InnManagementResultTopicCtrl.m_isGoingNext = HL.Field(HL.Boolean) << false
InnManagementResultTopicCtrl.m_starCellCache = HL.Field(HL.Forward("UIListCache"))
InnManagementResultTopicCtrl.m_expAnimLuaUpdateKey = HL.Field(HL.Number) << -1
InnManagementResultTopicCtrl.m_firstTime = HL.Field(HL.Boolean) << false






InnManagementResultTopicCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

InnManagementResultTopicCtrl.OnBeforePanelActive = HL.Method(HL.Any) << function(self, arg)
    if self.animationWrapper then
        self.animationWrapper.autoPlay = false
    end
end


InnManagementResultTopicCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_resultData = arg and arg.data
    
    self.m_firstTime = (arg and arg.config and arg.config.firstTime) == true

    if self.animationWrapper then
        self.animationWrapper:SetAnimationInClip(self.m_firstTime and "innmanagementresulttopic_in" or "innmanagementresulttopic_next_in")
        self.animationWrapper:PlayInAnimation()
    end

    self:InitButtonBinding()

    self:SetTopic()
    self:SetTheme()
    self:SetReward()
    self:SetBottom()
    self:_RefreshAwardFocusBinding()
end





InnManagementResultTopicCtrl.OnClose = HL.Override() << function(self)
    if self.m_expAnimLuaUpdateKey > 0 then
        self.m_expAnimLuaUpdateKey = LuaUpdate:Remove(self.m_expAnimLuaUpdateKey)
    end
end




InnManagementResultTopicCtrl.GetTopicId = HL.Method().Return(HL.String) << function(self)
    return self.m_resultData.gameSetting.topicId or ""
end

InnManagementResultTopicCtrl.GetStarData = HL.Method().Return(HL.Number, HL.Number) << function(self)
    local innSystem = GameInstance.player.innSystem
    local topicId = self:GetTopicId()
    local curStar = self.m_resultData.topicStar
    local historyStar = self.m_resultData.oldTopicStar

    return curStar, historyStar
end

InnManagementResultTopicCtrl.SetTopic = HL.Method() << function(self)
    local topicId = self:GetTopicId()
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    local isPrivateChef = hasTopic and topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef
    self.view.mainState:SetState(self.m_resultData.gameSetting.softOpening and "SoftOpening" or (isPrivateChef and "PrivateChef" or "Normal"))
end

InnManagementResultTopicCtrl.SetTheme = HL.Method() << function(self)
    local gameSetting = self.m_resultData.gameSetting
    local isNewRecord = self.m_resultData.isNewRecord
    local topicId = self:GetTopicId()
    local softOpening = gameSetting.softOpening
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    local isPrivateChef = hasTopic and topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef
    local normalResult = not softOpening and not isPrivateChef and hasTopic     

    
    self.view.themeNode.titleTxt.text = Language.LUA_INN_TOPIC_NONE_TITLE
    if not string.isEmpty(topicId) then
        local _, topicData = Tables.InnTopicTable:TryGetValue(topicId)
        if topicData then
            self.view.themeNode.titleTxt.text = topicData.name
        end
    end
    

    
    self.m_starCellCache = self.m_starCellCache or UIUtils.genCellCache(self.view.themeNode.ratingStarCell)
    local curStar, historyStar = self:GetStarData()
    local refreshStarCell = function(cell, luaIndex)
        cell.gameObject.name = string.format("star_%d", luaIndex)

        if luaIndex > curStar then
            cell.stateController:SetState("NoFullStar")
        elseif normalResult and luaIndex > historyStar then
            cell.stateController:SetState("AddStar")
        else
            cell.stateController:SetState("FullStar")
        end

        
        if self.m_firstTime then
            cell.animationWrapper.autoPlay = false
            cell.animationWrapper:ClearTween(false)
            cell.animationWrapper:PlayInAnimation()
        end
    end
    if self.m_firstTime then
        
        self.m_starCellCache:GraduallyRefresh(InnConst.INN_TOPIC_STAR_COUNT, self.view.config.STAR_IN_INTERVAL, refreshStarCell)
    else
        self.m_starCellCache:Refresh(InnConst.INN_TOPIC_STAR_COUNT, refreshStarCell)
    end

    
    self.view.themeNode.newRecordNode.gameObject:SetActive(normalResult and curStar > historyStar)
    
end

InnManagementResultTopicCtrl.SetReward = HL.Method() << function(self)
    local gameSetting = self.m_resultData.gameSetting
    local topicId = self:GetTopicId()
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    self.m_hasReward = false
    if gameSetting.softOpening then
        self.view.awardsStateController:SetState("Empty")
        return
    end


    
    self.view.awardsStateController:SetState("OnlyIncomeReward")
    local totalRevenue = self.m_resultData.totalBaseMoney + self.m_resultData.totalTipMoney
    local domainCoupon = self.m_resultData.rewardCoupon
    local rewardList = {}
    if totalRevenue > 0 then
        table.insert(rewardList, {id = Tables.innManagementConst.gamePlayToken, num = totalRevenue})
    end
    if domainCoupon > 0 then
        table.insert(rewardList, {id = Tables.innManagementConst.domainCouponId, num = domainCoupon})
    end

    self.m_hasReward = #rewardList > 0

    if #rewardList <= 0 then
        self.view.awardsStateController:SetState("Empty")
        return
    end

    local revenueRewardCellCache = UIUtils.genCellCache(self.view.awardsGetNode.revenueRewardCell)
    revenueRewardCellCache:Refresh(#rewardList, function(cell, luaIndex)
        local reward = rewardList[luaIndex]
        cell.gameObject.name = reward.id
        cell.item:InitItem({ id = reward.id, count = reward.num}, true)
        cell.item:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
    end)

    
    

    
    local curStar, historyStar = self:GetStarData()
    if curStar <= historyStar or not hasTopic then
        return
    end

    local tbRewardList = self:GetNewStarReward()
    local topicStarRewardCache = UIUtils.genCellCache(self.view.awardsGetNode.topicRewardCell)
    topicStarRewardCache:Refresh(#tbRewardList, function(cell, luaIndex)
        local reward = tbRewardList[luaIndex]
        cell.gameObject.name = reward.id
        cell.item:InitItem({ id = reward.id, count = reward.num }, true)
        cell.item:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
    end)

    if #tbRewardList > 0 then
        self.view.awardsStateController:SetState("FullReward")
    end

    
end

InnManagementResultTopicCtrl.GetNewStarReward = HL.Method().Return(HL.Table) << function(self)
    local curStar, historyStar = self:GetStarData()
    local topicId = self:GetTopicId()

    local _, topicData = Tables.InnTopicTable:TryGetValue(topicId)
    if not topicData then
        return {}
    end

    if curStar <= historyStar then
        return {}
    end

    local rewards = {}
    local starsRewardId = topicData.starsRewardId
    local starsRewardCount = (starsRewardId and starsRewardId.Count) or 0
    for star = historyStar + 1, curStar do
        local csIndex = CSIndex(star)
        if csIndex >= 0 and csIndex < starsRewardCount then
            local rewardId = starsRewardId[csIndex]
            if not string.isEmpty(rewardId) then
                local hasReward, rewardData = Tables.rewardTable:TryGetValue(rewardId)
                if hasReward and rewardData and rewardData.itemBundles then
                    local itemBundles = rewardData.itemBundles
                    for i = 0, #itemBundles - 1 do
                        rewards[itemBundles[i].id] = (rewards[itemBundles[i].id] or 0) + itemBundles[i].count
                    end
                end
            end
        end
    end

    local rewardList = {}
    for itemId, count in pairs(rewards) do
        local hasItem, itemData = Tables.itemTable:TryGetValue(itemId)
        table.insert(rewardList, {
            id = itemId,
            num = count,
            rarity = hasItem and itemData.rarity or 0,
            sortId1 = hasItem and itemData.sortId1 or 0,
            sortId2 = hasItem and itemData.sortId2 or 0,
        })
    end
    table.sort(rewardList, Utils.genSortFunction({ "rarity", "sortId1", "sortId2", "id" }))
    return rewardList
end

InnManagementResultTopicCtrl.SetBottom = HL.Method() << function(self)
    
    local innSystem = GameInstance.player.innSystem
    local innLevel = innSystem.innLevel
    local innExp = innSystem.innExp
    local __, nextLevelData = Tables.InnLevelTable:TryGetValue(innLevel + 1)
    local requiredExp = nextLevelData and nextLevelData.exp or 0
    local addExp = self.m_resultData.addExp or 0

    self.view.bottomNode.levelTxt.text = string.format("%d", innLevel)
    if requiredExp > 0 then       
        local currentExp = math.min(innExp, requiredExp)
        local __, curLevelData = Tables.InnLevelTable:TryGetValue(innLevel)

        if curLevelData then
            currentExp = currentExp - curLevelData.exp
            requiredExp = requiredExp - curLevelData.exp
        end
        self.view.bottomNode.businessExpText.text = Language.LUA_INN_RESULT_EXP_PROGRESS
        if self.m_firstTime then
            
            local originExp = math.max(currentExp - addExp, 0)
            self.view.bottomNode.expNumberTxt.text = string.format("%d<color=#7a7a7a>/%d</color>", originExp, requiredExp)
            self.view.bottomNode.expProgress.fillAmount = originExp / requiredExp

            
            self:_StartExpAnim(originExp, currentExp, requiredExp)
        else
            
            self.view.bottomNode.expNumberTxt.text = string.format("%d<color=#7a7a7a>/%d</color>", currentExp, requiredExp)
            self.view.bottomNode.expProgress.fillAmount = currentExp / requiredExp
        end
    else
        self.view.bottomNode.expNumberTxt.text = string.format("<color=#7a7a7a>-/-</color>")
        self.view.bottomNode.expProgress.fillAmount = 1
        self.view.bottomNode.businessExpText.text = Language.LUA_INN_RESULT_EXP_FULL
    end
    


    
    local curStar = self:GetStarData()
    local jsspsiCharId = Tables.innManagementConst.jsspsiCharId
    local friendshipAddTier, addValue = InnUtils.getFriendshipAddTier(curStar)
    local hasChar, charData = Tables.characterTable:TryGetValue(jsspsiCharId)
    local name = hasChar and charData.name or ""
    local jsspsiCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(jsspsiCharId, GEnums.CharType.Default)
    local friendshipState = FRIENDSHIP_UI_STATE[friendshipAddTier] or FRIENDSHIP_UI_STATE[1]
    local isMax = self.m_resultData.jsspsiFavorabilityBefore >= CSPlayerDataUtil.maxFriendship
    if isMax then
        friendshipState = "Max"
    end

    if jsspsiCharInfo and not self.m_resultData.gameSetting.softOpening then      
        self.view.bottomNode.charNode.gameObject:SetActive(true)

        local curFriendshipValue = self.m_resultData.jsspsiFavorabilityAfter
        local preFriendshipValue = self.m_resultData.jsspsiFavorabilityBefore
        local curPercent = CharInfoUtils.getCharRelationShowValue(curFriendshipValue)
        local prePercent = CharInfoUtils.getCharRelationShowValue(preFriendshipValue)
        local showChange = math.abs(curPercent - prePercent) > 0.01

        self.view.bottomNode.kitchenCharNode:InitInnOwnerCharNode()
        self.view.bottomNode.charTxt.text = name
        self.view.bottomNode.confidenceNode:SetState(friendshipState)
        self.view.bottomNode.upgradeState:SetState(isMax and "Max" or "Normal")
        self.view.bottomNode.friendshipNumState:SetState(isMax and "Max" or (showChange and "ShowNumber" or "HideNumber"))

        
        if showChange or isMax then
            self.view.bottomNode.preFriendshipTxt.text = string.format("%.0f%%", CharInfoUtils.getCharRelationShowValue(preFriendshipValue))
            self.view.bottomNode.curFriendshipTxt.text = string.format("%.0f%%", CharInfoUtils.getCharRelationShowValue(curFriendshipValue))
        end
    else
        self.view.bottomNode.charNode.gameObject:SetActive(false)
    end
    
end


InnManagementResultTopicCtrl._StartExpAnim = HL.Method(HL.Number, HL.Number, HL.Number) << function(self, originExp, finalExp, requiredExp)
    local curve = self.view.config.EXP_CURVE
    local start_time = self.view.config.EXP_START_TIME
    local time = self.view.config.EXP_TIME
    local end_time = time + start_time
    
    local start_value = originExp / requiredExp
    local end_value = finalExp / requiredExp
    local timeCnt = 0
    
    local progressAniPlayed = false
    
    self.m_expAnimLuaUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        timeCnt = timeCnt + deltaTime
        if timeCnt >= start_time and not progressAniPlayed then
            progressAniPlayed = true
            self.view.bottomNode.progressNodeAni:ClearTween(false)
            self.view.bottomNode.progressNodeAni:PlayInAnimation()
        end
        if timeCnt < start_time then
            self.view.bottomNode.expNumberTxt.text = string.format("%d<color=#7a7a7a>/%d</color>", originExp, requiredExp)
            self.view.bottomNode.expProgress.fillAmount = start_value
        elseif start_time <= timeCnt and timeCnt < end_time then
            local normalizedX = (timeCnt - start_time) / time
            local normalizedY = curve:Evaluate(normalizedX)
            local value = start_value + (end_value - start_value) * normalizedY
            self.view.bottomNode.expProgress.fillAmount = value
            local exp = originExp + (finalExp - originExp) * normalizedY
            exp = lume.round(exp)
            self.view.bottomNode.expNumberTxt.text = string.format("%d<color=#7a7a7a>/%d</color>", exp, requiredExp)
        else
            self.view.bottomNode.expProgress.fillAmount = end_value
            self.view.bottomNode.expNumberTxt.text = string.format("%d<color=#7a7a7a>/%d</color>", finalExp, requiredExp)
        end
    end)
end

InnManagementResultTopicCtrl.InitButtonBinding = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    self.view.bottomNode.btnFinish.onClick:AddListener(function()
        self:GoToNext()
    end)

    self.view.btnBack.onClick:AddListener(function()
        self.animationWrapper:SetAnimationOutClip("innmanagementresulttopic_next_out")
        PhaseManager:PopPhase(PHASE_ID, function()
            Notify(MessageConst.ON_INN_RESULT_PANEL_GO_BACK)
        end)
    end)

    local awardsNaviGroup = self.view.awardsGetNode.gameObject:GetComponent("UISelectableNaviGroup")
    if awardsNaviGroup then
        awardsNaviGroup.canFocusFun = function()
            return self.m_hasReward
        end
    end
end

InnManagementResultTopicCtrl._RefreshAwardFocusBinding = HL.Method() << function(self)
    local awardsNaviGroup = self.view.awardsGetNode.gameObject:GetComponent("UISelectableNaviGroup")
    if not awardsNaviGroup or awardsNaviGroup.FocusBindingId <= 0 then
        return
    end
    InputManagerInst:ToggleBinding(awardsNaviGroup.FocusBindingId, self.m_hasReward)
end

InnManagementResultTopicCtrl.GoToNext = HL.Method() << function(self)
    if self.m_isGoingNext or not PhaseManager:CanPopPhase(PHASE_ID) then
        return
    end
    self.m_isGoingNext = true
    local unsettled = self.m_resultData.unsettled
    if PhaseManager:IsOpen(PhaseId.InnManagementResultDetail) then
        PhaseManager:ExitPhaseFast(PhaseId.InnManagementResultDetail)
    end
    Notify(MessageConst.ON_INN_RESULT_PANEL_CLOSE)
    if unsettled then
        local opened = InnUtils.startGame(function()
            PhaseManager:ExitPhaseFast(PHASE_ID)
        end, InnUtils.takePendingTopicSelectionArg())
        if not opened then
            PhaseManager:PopPhase(PHASE_ID)
        end
        return
    end
    PhaseManager:PopPhase(PHASE_ID, function()
        GameWorld.eventManager:RaiseLevelEvent(GameLevelEvent.ON_INN_RESULT_PANEL_CLOSE)
    end)
end

HL.Commit(InnManagementResultTopicCtrl)
