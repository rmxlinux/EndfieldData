local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PHASE_ID = PhaseId.GambleBattlePreviewHandType













GambleBattlePreviewHandTypeCtrl = HL.Class('GambleBattlePreviewHandTypeCtrl', uiCtrl.UICtrl)


local TAB_TODAY = "today"
local TAB_OTHER = "other"
local CARD_COUNT = 5
local TAB_ANIMATION_IN = "gamblebattlepreviewhandtab_in"
local TAB_ANIMATION_OUT = "gamblebattlepreviewhandtab_out"
local TODAY_LUCKY_ANIMATION_IN = "gamblebattlepreviewhandtodaylucky_in"
local OTHER_LUCKY_ANIMATION_IN = "gamblebattlepreviewhandotherlucky_in"







GambleBattlePreviewHandTypeCtrl.s_messages = HL.StaticField(HL.Table) << {
}


GambleBattlePreviewHandTypeCtrl.m_otherCellCache = HL.Field(HL.Forward("UIListCache"))



GambleBattlePreviewHandTypeCtrl.m_todayHandTypeId = HL.Field(HL.Number) << 0



GambleBattlePreviewHandTypeCtrl.m_isMatchToday = HL.Field(HL.Boolean) << false



GambleBattlePreviewHandTypeCtrl.m_otherHandTypeList = HL.Field(HL.Table)



GambleBattlePreviewHandTypeCtrl.m_showOtherEnhanced = HL.Field(HL.Boolean) << false



GambleBattlePreviewHandTypeCtrl.m_curTab = HL.Field(HL.String) << TAB_TODAY


GambleBattlePreviewHandTypeCtrl.m_otherScrollPositionToRestore = HL.Field(HL.Number) << -1



GambleBattlePreviewHandTypeCtrl.ShowGambleBattlePreviewHandType = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    PhaseManager:OpenPhase(PHASE_ID, args)
end



GambleBattlePreviewHandTypeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.m_otherCellCache = UIUtils.genCellCache(self.view.otherLuckyCell)
    self.m_showOtherEnhanced = false
    self.m_otherScrollPositionToRestore = -1

    
    self:BindInputPlayerAction("gamble_battle_preview_hand_type_tab_prev", function()
        self:_CycleTab()
    end)
    self:BindInputPlayerAction("gamble_battle_preview_hand_type_tab_next", function()
        self:_CycleTab()
    end)

    self:_BindUI()
    self:_BindData()
    if type(arg) == "table" then
        if arg.tab == TAB_TODAY or arg.tab == TAB_OTHER then
            self.m_curTab = arg.tab
        end
        self.m_showOtherEnhanced = arg.showOtherEnhanced == true
        local scrollPosition = arg.otherScrollPosition
        if type(scrollPosition) == "number" and scrollPosition == scrollPosition then
            self.m_otherScrollPositionToRestore = math.max(0, math.min(1, scrollPosition))
        end
    end
    self:_RefreshChangeBtn()
    self:_SelectTab(self.m_curTab, true)
end



GambleBattlePreviewHandTypeCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local scrollPosition = self.m_otherScrollPositionToRestore
    if scrollPosition < 0 then
        local scrollRect = self.view.otherLuckyNode:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        scrollPosition = scrollRect.verticalNormalizedPosition
    end
    return {
        tab = self.m_curTab,
        showOtherEnhanced = self.m_showOtherEnhanced,
        otherScrollPosition = scrollPosition,
    }
end


GambleBattlePreviewHandTypeCtrl._Close = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end


GambleBattlePreviewHandTypeCtrl._BindUI = HL.Method() << function(self)
    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)

    self.view.mainBg.onClick:AddListener(function()
        self:_Close()
    end)

    
    self.view.leftTab.txtName.text = Language.LUA_GAMBLE_BATTLE_PREVIEW_TAB_TODAY
    self.view.rightTab.txtName.text = Language.LUA_GAMBLE_BATTLE_PREVIEW_TAB_OTHER
    self.view.leftTab.normal.onClick:AddListener(function()
        self:_SelectTab(TAB_TODAY)
    end)
    self.view.rightTab.normal.onClick:AddListener(function()
        self:_SelectTab(TAB_OTHER)
    end)

    
    self.view.changeBtn.onClick:AddListener(function()
        self:_OnClickChangeBtn()
    end)
end



GambleBattlePreviewHandTypeCtrl._BindData = HL.Method() << function(self)
    
    local system = GameInstance.player.gambleBattleSystem
    self.m_todayHandTypeId = system.bonusHandType
    
    local effectiveHandTypeId = system.handType
    self.m_isMatchToday = system.isMatchHandType == true

    
    local achievedOtherId = 0
    if effectiveHandTypeId ~= 0
        and not self.m_isMatchToday
        and effectiveHandTypeId ~= self.m_todayHandTypeId then
        achievedOtherId = effectiveHandTypeId
    end

    
    for handTypeId, handTypeData in pairs(Tables.gambleBattleHandTypeTable) do
        self:_ReportHandTypeConfigErrors(handTypeId, handTypeData)
    end
    
    local luckyPoolSet = self:_CollectLuckyPool()
    self.m_otherHandTypeList = self:_BuildOtherList(self.m_todayHandTypeId, achievedOtherId, luckyPoolSet)

    
    if achievedOtherId ~= 0 then
        self.m_curTab = TAB_OTHER
    else
        self.m_curTab = TAB_TODAY
    end
end





GambleBattlePreviewHandTypeCtrl._ReportHandTypeConfigErrors = HL.Method(HL.Number, HL.Any) << function(self, handTypeId, data)
    local numberCount = data.showNumber.Count
    local iconCount = data.showIcon.Count
    if numberCount ~= iconCount or numberCount > CARD_COUNT or iconCount > CARD_COUNT then
        logger.error("GambleBattlePreviewHandType: card counts must match and be <= 5",
            handTypeId, numberCount, iconCount)
    end
    for _, fieldName in ipairs({ "handTypeBuffId", "handTypeBuffPlusId" }) do
        for _, buffId in pairs(data[fieldName]) do
            if not Tables.gambleBattleEnemyBuffTable:ContainsKey(buffId) then
                logger.error("GambleBattlePreviewHandType: missing Buff reference", handTypeId, fieldName, buffId)
            end
        end
    end
end




GambleBattlePreviewHandTypeCtrl._CollectLuckyPool = HL.Method().Return(HL.Table) << function(self)
    local luckyPoolSet = {}
    for _, handTypeId in pairs(Tables.gambleBattleConst.handTypePool) do
        if not Tables.gambleBattleHandTypeTable:ContainsKey(handTypeId) then
            logger.error("GambleBattlePreviewHandType: handTypePool references missing handTypeId", handTypeId)
        end
        luckyPoolSet[handTypeId] = true
    end
    return luckyPoolSet
end







GambleBattlePreviewHandTypeCtrl._BuildOtherList = HL.Method(HL.Number, HL.Number, HL.Table).Return(HL.Table)
    << function(self, todayHandTypeId, achievedOtherId, luckyPoolSet)
    
    local otherHandTypeList = {}
    for handTypeId, handTypeData in pairs(Tables.gambleBattleHandTypeTable) do
        if handTypeId ~= todayHandTypeId then
            table.insert(otherHandTypeList, {
                handTypeId = handTypeId,
                handTypeData = handTypeData,
                isAchieved = handTypeId == achievedOtherId,
                canBeLucky = luckyPoolSet[handTypeId] == true,
            })
        end
    end

    table.sort(otherHandTypeList, function(a, b)
        
        if a.isAchieved ~= b.isAchieved then
            return a.isAchieved
        end
        
        if a.handTypeData.priority ~= b.handTypeData.priority then
            return a.handTypeData.priority > b.handTypeData.priority
        end
        return a.handTypeId < b.handTypeId
    end)
    return otherHandTypeList
end



GambleBattlePreviewHandTypeCtrl._CycleTab = HL.Method() << function(self)
    local nextTab = self.m_curTab == TAB_TODAY and TAB_OTHER or TAB_TODAY
    self:_SelectTab(nextTab)
end


GambleBattlePreviewHandTypeCtrl._SelectTab = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, tab, isReset)
    if not isReset and self.m_curTab ~= tab then
        AudioAdapter.PostEvent("Au_UI_Toggle_Tab_On")
    end
    self.m_curTab = tab
    local isToday = tab == TAB_TODAY

    
    self.view.tabTipText.text = isToday
        and Language.LUA_GAMBLE_BATTLE_PREVIEW_TIP_TODAY
        or Language.LUA_GAMBLE_BATTLE_PREVIEW_TIP_OTHER

    self:_RefreshTabVisual(isReset)

    self.view.todayLuckyNode.gameObject:SetActive(isToday)
    self.view.otherLuckyNode.gameObject:SetActive(not isToday)
    self.view.enhanceTips.gameObject:SetActive(false)
    self.view.changeBtn.gameObject:SetActive(not isToday)

    if isToday then
        self:_RefreshTodayLuckyCell()
    else
        self:_RefreshOtherLuckyCells()
    end

    self.view.reminderNodeAnim:Play(isToday and TODAY_LUCKY_ANIMATION_IN or OTHER_LUCKY_ANIMATION_IN)
end


GambleBattlePreviewHandTypeCtrl._RefreshTabVisual = HL.Method(HL.Opt(HL.Boolean)) << function(self, isReset)
    local isToday = self.m_curTab == TAB_TODAY
    self.view.leftTab.selected.gameObject:SetActive(isToday)
    self.view.leftTab.normal.gameObject:SetActive(not isToday)
    self.view.rightTab.selected.gameObject:SetActive(not isToday)
    self.view.rightTab.normal.gameObject:SetActive(isToday)
    if isReset then
        local selectedTab = isToday and self.view.leftTab or self.view.rightTab
        selectedTab.animationWrapper:Play(TAB_ANIMATION_IN)
    else
        self.view.leftTab.animationWrapper:Play(isToday and TAB_ANIMATION_IN or TAB_ANIMATION_OUT)
        self.view.rightTab.animationWrapper:Play(isToday and TAB_ANIMATION_OUT or TAB_ANIMATION_IN)
    end
end



GambleBattlePreviewHandTypeCtrl._RefreshTodayLuckyCell = HL.Method() << function(self)
    local cell = self.view.todayluckyCell
    local handTypeData = self:_FindHandTypeData(self.m_todayHandTypeId)
    if not handTypeData then
        cell.gameObject:SetActive(false)
        return
    end

    cell.gameObject:SetActive(true)
    cell.combinationNameText.text = handTypeData.handTypeName
    cell.combinationDescText.text = handTypeData.desc
    cell.rateNumText.text = self:_FormatBenefit(handTypeData.bonusBenefit)
    cell.enhanceTitle:SetAndResolveTextStyle(self:_GetEnhanceTitle(handTypeData, self.m_isMatchToday))
    cell.enhanceDesc:SetAndResolveTextStyle(self:_GetEnemyBenefitDesc(handTypeData, true))
    cell.stateController:SetState(self.m_isMatchToday and "Completed" or "NotAchieved")
    if self.m_isMatchToday then
        AudioAdapter.PostEvent("Au_UI_Event_GambleMeetCondition_Yellow")
    end
    self.view.enhanceTips.gameObject:SetActive(self.m_isMatchToday)
    self:_FillCards(cell, handTypeData)

    LayoutRebuilder.ForceRebuildLayoutImmediate(cell.rectTransform)
end


GambleBattlePreviewHandTypeCtrl._RefreshOtherLuckyCells = HL.Method() << function(self)
    self.m_otherCellCache:Refresh(#self.m_otherHandTypeList, function(cell, luaIndex)
        self:_UpdateOtherCell(cell, self.m_otherHandTypeList[luaIndex])
    end)
    if self.m_otherScrollPositionToRestore >= 0 then
        local scrollRect = self.view.otherLuckyNode:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        LayoutRebuilder.ForceRebuildLayoutImmediate(scrollRect.transform)
        scrollRect:StopMovement()
        scrollRect.verticalNormalizedPosition = self.m_otherScrollPositionToRestore
        self.m_otherScrollPositionToRestore = -1
    end
end



GambleBattlePreviewHandTypeCtrl._UpdateOtherCell = HL.Method(HL.Any, HL.Table) << function(self, cell, info)
    local handTypeData = info.handTypeData
    cell.combinationNameText.text = handTypeData.handTypeName

    
    if self.m_showOtherEnhanced and not info.canBeLucky then
        cell.stateController:SetState("EmptyState")
        cell.leftDescText.text = Language.LUA_GAMBLE_BATTLE_PREVIEW_CAN_NOT_BE_LUCKY
        cell.leftRateNumText.text = ""
        cell.enhanceTitle.gameObject:SetActive(false)
        cell.enhanceDesc.gameObject:SetActive(false)
        self:_SetCardsActive(cell, false)
        return
    end

    cell.enhanceTitle.gameObject:SetActive(true)
    cell.enhanceDesc.gameObject:SetActive(true)
    
    local isBaseEffectAchieved = not self.m_showOtherEnhanced and info.isAchieved
    cell.enhanceTitle:SetAndResolveTextStyle(self:_GetEnhanceTitle(handTypeData, isBaseEffectAchieved))
    cell.leftDescText.text = handTypeData.desc

    
    local benefit = self.m_showOtherEnhanced and handTypeData.bonusBenefit or handTypeData.handTypeBenefit
    cell.leftRateNumText.text = self:_FormatBenefit(benefit)
    cell.enhanceDesc:SetAndResolveTextStyle(self:_GetEnemyBenefitDesc(handTypeData, self.m_showOtherEnhanced))
    cell.stateController:SetState(isBaseEffectAchieved and "Completed" or "NotAchieved")

    self:_FillCards(cell, handTypeData)
end


GambleBattlePreviewHandTypeCtrl._OnClickChangeBtn = HL.Method() << function(self)
    self.m_showOtherEnhanced = not self.m_showOtherEnhanced
    self:_RefreshChangeBtn()
    
    self:_RefreshOtherLuckyCells()
end


GambleBattlePreviewHandTypeCtrl._RefreshChangeBtn = HL.Method() << function(self)
    local text = self.m_showOtherEnhanced
        and Language.LUA_GAMBLE_BATTLE_PREVIEW_VIEW_INITIAL
        or Language.LUA_GAMBLE_BATTLE_PREVIEW_VIEW_ENHANCE
    self.view.changeBtn.text = text
    
    self.view.changeBtn.customBindingViewLabelText = text
end





GambleBattlePreviewHandTypeCtrl._FindHandTypeData = HL.Method(HL.Number).Return(HL.Any) << function(self, handTypeId)
    if handTypeId == 0 then
        return nil
    end
    local ok, data = Tables.gambleBattleHandTypeTable:TryGetValue(handTypeId)
    if not ok then
        logger.error("GambleBattlePreviewHandType: missing handTypeId", handTypeId)
        return nil
    end
    return data
end



GambleBattlePreviewHandTypeCtrl._FormatBenefit = HL.Method(HL.Number).Return(HL.String) << function(self, benefit)
    local v = benefit / 100
    if v == math.floor(v) then
        return tostring(math.floor(v))
    end
    return string.format("%.1f", v)
end






GambleBattlePreviewHandTypeCtrl._GetEnhanceTitle = HL.Method(HL.Any, HL.Boolean).Return(HL.String) << function(self, handTypeData, isOn)
    if handTypeData.isEffectAllMonster then
        return isOn
            and Language.LUA_GAMBLE_BATTLE_PREVIEW_DEBUFF_NSTRUCTION_ALL_ENEMY_ON
            or Language.LUA_GAMBLE_BATTLE_PREVIEW_DEBUFF_NSTRUCTION_ALL_ENEMY_OFF
    end
    return isOn
        and Language.LUA_GAMBLE_BATTLE_PREVIEW_DEBUFF_NSTRUCTION_GROUP_ENEMY_ON
        or Language.LUA_GAMBLE_BATTLE_PREVIEW_DEBUFF_NSTRUCTION_GROUP_ENEMY_OFF
end






GambleBattlePreviewHandTypeCtrl._GetEnemyBenefitDesc = HL.Method(HL.Any, HL.Boolean).Return(HL.String) << function(self, handTypeData, useEnhanced)
    local buffIds = useEnhanced and handTypeData.handTypeBuffPlusId or handTypeData.handTypeBuffId
    local parts = {}
    if buffIds then
        for _, buffId in pairs(buffIds) do
            local ok, buffData = Tables.gambleBattleEnemyBuffTable:TryGetValue(buffId)
            if ok and buffData.desc and buffData.desc ~= "" then
                table.insert(parts, buffData.desc)
            end
        end
    end
    return table.concat(parts, "")
end



GambleBattlePreviewHandTypeCtrl._GetCards = HL.Method(HL.Any).Return(HL.Table) << function(self, cell)
    return { cell.card01, cell.card02, cell.card03, cell.card04, cell.card05 }
end




GambleBattlePreviewHandTypeCtrl._FillCards = HL.Method(HL.Any, HL.Any) << function(self, cell, handTypeData)
    local cards = self:_GetCards(cell)
    
    local count = math.min(handTypeData.showNumber.Count, handTypeData.showIcon.Count)
    for i = 1, CARD_COUNT do
        local card = cards[i]
        if card then
            local visible = count >= i
            card.gameObject:SetActive(visible)
            if visible then
                card.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. handTypeData.showNumber[i - 1])
                card.typeImg:LoadSprite("Activity/ActivityGambleBattle/" .. handTypeData.showIcon[i - 1])
            end
        end
    end
end


GambleBattlePreviewHandTypeCtrl._SetCardsActive = HL.Method(HL.Any, HL.Boolean) << function(self, cell, active)
    local cards = self:_GetCards(cell)
    for i = 1, CARD_COUNT do
        if cards[i] then
            cards[i].gameObject:SetActive(active)
        end
    end
end


HL.Commit(GambleBattlePreviewHandTypeCtrl)
