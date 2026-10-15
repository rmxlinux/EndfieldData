local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnManagementResultDetail
local PHASE_ID = PhaseId.InnManagementResultDetail

InnManagementResultDetailCtrl = HL.Class('InnManagementResultDetailCtrl', uiCtrl.UICtrl)

InnManagementResultDetailCtrl.m_resultData = HL.Field(HL.Userdata)
InnManagementResultDetailCtrl.m_dishCellCache = HL.Field(HL.Forward("UIListCache"))
InnManagementResultDetailCtrl.m_drinkCellCache = HL.Field(HL.Forward("UIListCache"))
InnManagementResultDetailCtrl.m_isGoingNext = HL.Field(HL.Boolean) << false
InnManagementResultDetailCtrl.m_firstTime = HL.Field(HL.Boolean) << true

InnManagementResultDetailCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_RESULT_PANEL_GO_BACK] = "OnBackFromTopciPanel",
}

local HALF_DISH_OR_DRINK_COUNT = 4



InnManagementResultDetailCtrl.ShowPanel = HL.StaticMethod(HL.Any) << function(arg)
    arg = unpack(arg) or arg

    UIManager:Close(PanelId.InstructionBook)

    GameAction.PostMusicEvent("au_music_map02_lv010_innmanagement_finish", CS.Beyond.Gameplay.Audio.AudioMusicSystem.EMusicEventPreAction.NORMAL)
    PhaseManager:OpenPhase(PHASE_ID, arg, nil, true)
end


InnManagementResultDetailCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_resultData = arg
    self:_PlayFirstInAnimation()

    self:InitButtonBinding()

    self:SetInAnimationText()
    self:SetTheme()
    self:SetChar()
    self:SetMess()
    self:_ScheduleScoreScroll()

    local dishNaviGroup = self.view.messNode.dishNaviGroup
    if dishNaviGroup then
        dishNaviGroup.canFocusFun = function()
            return (self.m_dishCellCache and self.m_dishCellCache:GetCount() > 0)
                or (self.m_drinkCellCache and self.m_drinkCellCache:GetCount() > 0)
        end
    end

    local charNaviGroup = self.view.charNode.charNaviGroup
    if charNaviGroup then
        charNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_INN_CHAR_TIPS)
            end
        end)
    end
end

InnManagementResultDetailCtrl._PlayFirstInAnimation = HL.Method() << function(self)
    local wrapper = self.animationWrapper
    if not wrapper then
        return
    end
    wrapper:ClearTween(false)
    wrapper:SetAnimationInClip("innmanagementresultdetail_in")
    wrapper:PlayInAnimation(function()
        wrapper:SetAnimationInClip("innmanagementresultdetail_next_in")
    end)
    AudioAdapter.PostEvent("Au_UI_Popup_InnOperateComplete_pt1")
end

InnManagementResultDetailCtrl.OnClose = HL.Override() << function(self)
    self.m_resultData = nil
end

InnManagementResultDetailCtrl._ScheduleScoreScroll = HL.Method() << function(self)
    local delay = self.view.config.SCORE_SCROLL_START_TIME
    self:_StartTimer(delay, function()
        self:_TryPlayScoreScroll()
    end, true)
end

InnManagementResultDetailCtrl._TryPlayScoreScroll = HL.Method() << function(self)
    if self.m_isGoingNext or not self.m_resultData then
        return
    end
    self:_PlayNumberScroll(self.view.messNode.overallScoreShadowTxt, self.m_resultData.totalScore)
    self:_PlayNumberScroll(self.view.messNode.overallScoreNumTxt, self.m_resultData.totalScore)
end

InnManagementResultDetailCtrl._BindCharNaviTargetTips = HL.Method(HL.Userdata, HL.Table, CS.Beyond.UI.UIState.UIStateController) << function(self, button, tipsArgs, stateCtrl)
    button.onIsNaviTargetChanged = function(isTarget, isGroupChanged, isOnNaviTargetEnabledAgain)
        if isOnNaviTargetEnabledAgain then return end
        if isTarget then
            self:_OpenCharTips(stateCtrl, tipsArgs)
        end
    end
end

InnManagementResultDetailCtrl._OpenCharTips = HL.Method(CS.Beyond.UI.UIState.UIStateController, HL.Table) << function(self, stateCtrl, tipsArgs)
    tipsArgs.onClose = function()
        if NotNull(stateCtrl) then
            stateCtrl:SetState("Unselect")
        end
    end
    Notify(MessageConst.OPEN_INN_CHAR_TIPS, tipsArgs)
    stateCtrl:SetState("Select")
end

InnManagementResultDetailCtrl._PrepareNumberScroll = HL.Method(HL.Userdata).Return(HL.Userdata) << function(self, node)
    local go = node.gameObject
    local tween = go:GetComponent(typeof(CS.Beyond.UI.UINumberScrollTween))
    local uiText = tween.bindingUIText or go:GetComponent(typeof(CS.Beyond.UI.UIText))
    tween.bindingUIText = uiText
    uiText.text = "0"
    return tween
end

InnManagementResultDetailCtrl._PlayNumberScroll = HL.Method(HL.Userdata, HL.Any) << function(self, node, score)
    local tween = self:_PrepareNumberScroll(node)
    tween.tweenToText = tostring(score)
end

InnManagementResultDetailCtrl.SetInAnimationText = HL.Method() << function(self)
    local text = self.m_resultData.unsettled and Language.LUA_INN_LAST_RESULT_IN_ANI_TITLE or Language.LUA_INN_RESULT_IN_ANI_TITLE
    if self.view.titleShadowText then
        self.view.titleShadowText.text = text
    end
    if self.view.titleText then
        self.view.titleText.text = text
    end
end

InnManagementResultDetailCtrl.SetTheme = HL.Method() << function(self)
    local gameSetting = self.m_resultData.gameSetting
    local topicId = gameSetting.topicId

    self.view.themeNode.themeTxt.text = Language.LUA_INN_TOPIC_NONE_TITLE
    if not string.isEmpty(topicId) then
        local _, topicData = Tables.innTopicTable:TryGetValue(topicId)
        if topicData then
            self.view.themeNode.themeTxt.text = topicData.name
            self.view.themeNode.themeImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, topicData.iconId)
        end
    end
end

InnManagementResultDetailCtrl.SetChar = HL.Method() << function(self)
    
    
    

    

    
    
    
    
    
    
    
    
    

    self.view.charNode.kitchenCharNode:InitInnOwnerCharNode()
    self.view.charNode.qualityAttriNode:InitInnOwnerBuffNode()
    self.view.charNode.mainCharHeadButton.onClick:AddListener(function()
        self:_OpenCharTips(self.view.charNode.kitchenCharNodeStateController, {
            charId = (Tables.innManagementConst and Tables.innManagementConst.jsspsiCharId) or "",
            transform = self.view.charNode.kitchenCharNode.transform,
            posType = UIConst.UI_TIPS_POS_TYPE.RightTopOrLeftTop,
            isSideTips = DeviceInfo.usingController,
        })
    end)

    self:_BindCharNaviTargetTips(self.view.charNode.mainCharHeadButton, {
        charId = (Tables.innManagementConst and Tables.innManagementConst.jsspsiCharId) or "",
        transform = self.view.charNode.kitchenCharNode.transform,
        posType = UIConst.UI_TIPS_POS_TYPE.RightTopOrLeftTop,
        isSideTips = DeviceInfo.usingController,
    }, self.view.charNode.kitchenCharNodeStateController)
    


    
    local gameSetting = self.m_resultData.gameSetting
    local kitchenSettings = gameSetting.kitchenSettings
    
    local sortedKitchenSettings = {}
    for csIndex = 0, kitchenSettings.Count - 1 do
        sortedKitchenSettings[#sortedKitchenSettings + 1] = kitchenSettings[csIndex]
    end
    table.sort(sortedKitchenSettings, function(a, b)
        return a.id < b.id
    end)
    local kitchenCache = UIUtils.genCellCache(self.view.charNode.kitchenResult)
    kitchenCache:Refresh(#sortedKitchenSettings, function(kitchenCell, luaIndex)
        local kitchen = sortedKitchenSettings[luaIndex]    
        local kitchenId = kitchen.id
        local found, count = self.m_resultData.kitchensDishCount:TryGetValue(kitchenId)
        kitchenCell.cookingTimesTxt.text = tostring(found and count or 0)

        kitchenCell.gameObject.name = string.format("kitchen_%d", kitchenId)


        local charIds = kitchen and kitchen.charIds
        
        local isMvpKitchen = false
        for charCsIndex = 0, (charIds and charIds.Count or 0) - 1 do
            if charIds[charCsIndex] == self.m_resultData.mvpCharId then
                isMvpKitchen = true
                break
            end
        end
        kitchenCell.stateController:SetState(isMvpKitchen and "Max" or "Normal")
        local charCache = UIUtils.genCellCache(kitchenCell.charNode)
        charCache:Refresh((charIds and charIds.Count) or 0, function(charCell, charLuaIndex)
            local csIndex = CSIndex(charLuaIndex)
            local charNumId = charIds[csIndex]
            local hasStr, charStr = CS.Beyond.Cfg.Tables.charIdToStr:TryGetValue(charNumId)
            if not hasStr then
                charStr = Tables.innManagementConst.jsspsiCharId    
            else
                charCell.gameObject.name = charStr
                charCell.charImage:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. charStr)
                charCell.stateController:SetState(charNumId == self.m_resultData.mvpCharId and "Hot" or "Normal")
                charCell.charImageButton.onClick:AddListener(function()
                    self:_OpenCharTips(charCell.stateController, {
                        charId = charStr,
                        kitchenId = kitchenId,
                        transform = charCell.charImage.transform,
                        posType = UIConst.UI_TIPS_POS_TYPE.RightTopOrLeftTop,
                        isSideTips = DeviceInfo.usingController,
                    })
                end)
                
                self:_BindCharNaviTargetTips(charCell.charImageButton, {
                    charId = charStr,
                    kitchenId = kitchenId,
                    transform = charCell.charImage.transform,
                    posType = UIConst.UI_TIPS_POS_TYPE.RightTopOrLeftTop,
                    isSideTips = DeviceInfo.usingController,
                }, charCell.stateController)
            end
        end)
    end)
    
end

InnManagementResultDetailCtrl.SetMess = HL.Method() << function(self)
    local gameSetting = self.m_resultData.gameSetting
    local topicId = gameSetting.topicId
    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    local isPrivateChef = hasTopic and topicData and topicData.topicType == GEnums.InnTopicType.PrivateChef
    local innSystem = GameInstance.player.innSystem
    local innLevel = innSystem.innLevel
    self.view.messNode.topicStateController:SetState((not hasTopic) and "NoTopic" or (isPrivateChef and "PrivateChef" or "Topic"))

    
    local revenueRankRange, kpiRankRange = nil, nil
    local topicRatio = nil
    if self.m_resultData.isTeachingMode then
        revenueRankRange = Tables.innManagementConst.teachingProfitScoreRankPoint
        kpiRankRange = Tables.innManagementConst.teachingKPIScoreRankPoint
    elseif not hasTopic then
        local _, levelData = Tables.innLevelTable:TryGetValue(innLevel)
        if levelData then
            revenueRankRange = levelData.profitScoreRankPoint
            kpiRankRange = levelData.KPIScoreRankPoint
        end
    else
        if topicData then
            topicRatio = topicData.topicObjectiveScoreFactor
            revenueRankRange = topicData.topicProfitScoreRankPoint
            kpiRankRange = topicData.topicKPIScoreRankPoint
        end
    end
    

    
    if hasTopic then
        self.view.messNode.topicScoreTxtText.text = ""

        local _, topicData = Tables.innTopicTable:TryGetValue(topicId)
        if topicData then
            local conditionId = topicData.objectiveConditionId
            local _, progress = self.m_resultData.conditionState:TryGetValue(conditionId)
            self.view.messNode.conditionDescTxt.text = topicData.objectiveDesc
            self.view.messNode.conditionProgessTxt.text = string.format("%d/%d", progress and progress.value or 0, topicData.oProgressToCompare)
            self.view.messNode.conditionComplete.gameObject:SetActive(progress and progress.flag or false)

            self.view.messNode.topicScoreTxtText.text = (progress and progress.flag and topicRatio ~= nil) and string.format("x%s", tostring(topicRatio)) or "-"
        else
            self.view.messNode.conditionDescTxt.text = ""
            self.view.messNode.conditionProgessTxt.text = ""
            self.view.messNode.conditionComplete.gameObject:SetActive(false)
        end
    end
    

    
    self:_PrepareNumberScroll(self.view.messNode.overallScoreShadowTxt)
    self:_PrepareNumberScroll(self.view.messNode.overallScoreNumTxt)
    self.view.messNode.newRecordNode.gameObject:SetActive(self.m_resultData.isNewRecord)
    self.view.ratingStarLayoutNode:InitInnRatingStarLayoutNode(InnConst.INN_TOPIC_STAR_COUNT, self.m_resultData.topicStar)
    

    
    local totalRevenue = self.m_resultData.totalBaseMoney + self.m_resultData.totalTipMoney
    self.view.messNode.revenueScoreTxt.text = self.m_resultData.moneyScore
    self.view.messNode.revenueTotalTxt.text = totalRevenue
    self.view.messNode.revenueBaseNumTxt.text = self.m_resultData.totalBaseMoney
    self.view.messNode.revenueTipNumTxt.text = self.m_resultData.totalTipMoney

    self:SetDishAndDrink()

    local rankState = self:GetRankState(self.m_resultData.moneyScore, revenueRankRange)
    self.view.messNode.revenueRankState:SetState(rankState)
    


    

    self.view.messNode.kpiComboNumTxt.text = self.m_resultData.maxComboCount
    self.view.messNode.kpiHighestNumTxt.text = self.m_resultData.rareDishCount
    self.view.messNode.kpiReceptionNumTxt.text = self.m_resultData.perfectSpecialGuestServed
    self.view.messNode.kpiHotNumTxt.text = self.m_resultData.rushCount
    self.view.messNode.kpiScoreTxt.text = self.m_resultData.kpiScore

    self.view.messNode.tablesNumTxt.text = self.m_resultData.totalGuestServed
    self.view.messNode.customNumTxt.text = self.m_resultData.successNormalGuestServed
    self.view.messNode.specialCustomNumTxt.text = self.m_resultData.notFailedSpecialGuestServed

    local rankState = self:GetRankState(self.m_resultData.kpiScore, kpiRankRange)
    self.view.messNode.kpiRankState:SetState(rankState)
    

    self:_RefreshSpecialGuestAndRushState(hasTopic, topicData, innLevel)
end

InnManagementResultDetailCtrl._RefreshSpecialGuestAndRushState = HL.Method(HL.Boolean, HL.Any, HL.Number) << function(self, hasTopic, topicData, innLevel)
    local specialGuestLimit = 0
    local hasLevelData, levelData = Tables.innLevelTable:TryGetValue(innLevel)
    if hasLevelData and levelData then
        specialGuestLimit = levelData.specialGuestLimit
    end
    if hasTopic and topicData and topicData.overrideSpecialGuestLimit > 0 then
        specialGuestLimit = topicData.overrideSpecialGuestLimit
    end
    self.view.messNode.topicStateController:SetState(specialGuestLimit > 0 and "HasSpecialGuest" or "NoSpecialGuest")

    local rushUnlockLevel = Tables.innManagementConst.rushUnlockLevel
    self.view.messNode.topicStateController:SetState(innLevel >= rushUnlockLevel and "HasHotRush" or "NoHotRush")
end


InnManagementResultDetailCtrl.GetRankState = HL.Method(HL.Number, HL.Any).Return(HL.String) << function(self, score, range)
    if range == nil or range.Count < 2 then
        return "Rank03"
    end

    if score < range[0] then
        return "Rank03"
    elseif score < range[1] then
        return "Rank02"
    else
        return "Rank01"
    end
end

InnManagementResultDetailCtrl.SetDishAndDrink = HL.Method() << function(self)
    
    local sortedDish = {}
    local dishCount = 0
    for dishId, count in cs_pairs(self.m_resultData.soldDishCount) do
        local hasItem, itemData = Tables.itemTable:TryGetValue(dishId)
        local rarity = hasItem and itemData.rarity or 0
        sortedDish[#sortedDish + 1] = { id = dishId, rarity = rarity, count = count }
        dishCount = dishCount + count
    end
    table.sort(sortedDish, function(a, b)
        if a.rarity ~= b.rarity then return a.rarity > b.rarity end
        return a.count > b.count
    end)

    local sortedDrink = {}
    local drinkCount = 0
    for drinkId, count in cs_pairs(self.m_resultData.soldDrinkCount) do
        local hasItem, itemData = Tables.itemTable:TryGetValue(drinkId)
        local rarity = hasItem and itemData.rarity or 0
        sortedDrink[#sortedDrink + 1] = { id = drinkId, rarity = rarity, count = count }
        drinkCount = drinkCount + count
    end
    table.sort(sortedDrink, function(a, b)
        if a.rarity ~= b.rarity then return a.rarity > b.rarity end
        return a.count > b.count
    end)
    
    
    self.view.messNode.dishCount.text = dishCount
    self.view.messNode.drinkCount.text = drinkCount

    self.view.messNode.topicStateController:SetState((#sortedDish > HALF_DISH_OR_DRINK_COUNT or #sortedDrink > HALF_DISH_OR_DRINK_COUNT) and "Item8" or "Item4")

    if not self.m_dishCellCache then
        self.m_dishCellCache = UIUtils.genCellCache(self.view.messNode.dishCell)
    end
    if not self.m_drinkCellCache then
        self.m_drinkCellCache = UIUtils.genCellCache(self.view.messNode.drinkCell)
    end

    self.m_dishCellCache:Refresh(#sortedDish, function(cell, index)
        local data = sortedDish[index]
        cell.view.gameObject.name = data.id
        cell:InitItem({ id = data.id, count = data.count }, true)
        cell:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightMid,
            tipsPosTransform = self.view.messNode.dishAndDrinkRect.transform,
            isSideTips = DeviceInfo.usingController,
        })
    end)
    self.m_drinkCellCache:Refresh(#sortedDrink, function(cell, index)
        local data = sortedDrink[index]
        cell.view.gameObject.name = data.id
        cell:InitItem({ id = data.id, count = data.count }, true)
        cell:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightMid,
            tipsPosTransform = self.view.messNode.dishAndDrinkRect.transform,
            isSideTips = DeviceInfo.usingController,
        })
    end)

    self:_RefreshDishFocusBinding()
end

InnManagementResultDetailCtrl._RefreshDishFocusBinding = HL.Method() << function(self)
    local naviGroup = self.view.messNode.dishNaviGroup
    if not naviGroup or naviGroup.FocusBindingId <= 0 then
        return
    end
    local hasItems = (self.m_dishCellCache and self.m_dishCellCache:GetCount() > 0)
        or (self.m_drinkCellCache and self.m_drinkCellCache:GetCount() > 0)
    InputManagerInst:ToggleBinding(naviGroup.FocusBindingId, hasItems)
end

InnManagementResultDetailCtrl.InitButtonBinding = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    self.view.messNode.nextButton.onClick:AddListener(function()
        self:GoToNext()
    end)

    self.view.shareBtn.onClick:AddListener(function()
        self.view.mainState:SetState("Share")

        Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
            type = "Inn",
            onCaptureEnd  = function()
                self.view.mainState:SetState("Noshare")
            end,
            onClose = function()
                self.view.mainState:SetState("Noshare")
            end,
        })
    end)

    self.view.messNode.searchButton.onClick:AddListener(function()
        UIManager:AutoOpen(PanelId.InnResultStarTips, {
            resultData = self.m_resultData,
            transform = self.view.ratingStarLayoutNode.rectTransform,
        })
    end)
end

InnManagementResultDetailCtrl.GoToNext = HL.Method() << function(self)
    if self.m_isGoingNext then
        return
    end
    self.m_isGoingNext = true
    self:PlayAnimationOutWithCallback(function()
        PhaseManager:OpenPhase(PhaseId.InnManagementResultTopic, { data = self.m_resultData, config = { firstTime = self.m_firstTime }}, nil, true)
    end)
end

InnManagementResultDetailCtrl.OnBackFromTopciPanel = HL.Method() << function(self)
    self.m_firstTime = false
    self.m_isGoingNext = false
    self:_RefreshDishFocusBinding()
end


HL.Commit(InnManagementResultDetailCtrl)
