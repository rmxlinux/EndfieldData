local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattlePreviewCombinations


GambleBattlePreviewCombinationsCtrl = HL.Class('GambleBattlePreviewCombinationsCtrl', uiCtrl.UICtrl)







GambleBattlePreviewCombinationsCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


GambleBattlePreviewCombinationsCtrl.m_otherLuckyCellCache = HL.Field(HL.Forward("UIListCache"))


GambleBattlePreviewCombinationsCtrl.m_todayHandTypeId = HL.Field(HL.Number) << 0


GambleBattlePreviewCombinationsCtrl.m_isMatchHandType = HL.Field(HL.Boolean) << false


GambleBattlePreviewCombinationsCtrl.m_allHandTypeList = HL.Field(HL.Table)



GambleBattlePreviewCombinationsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    arg = arg or {}

    self.view.btnClose.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.m_otherLuckyCellCache = UIUtils.genCellCache(self.view.otherLuckyCell)

    self.m_todayHandTypeId = 1
    if arg.todayHandTypeId ~= nil then
        self.m_todayHandTypeId =  arg.todayHandTypeId
    end

    self.m_isMatchHandType = arg.isMatchHandType == true

    self:_CollectAllHandTypeList()
    self:_RefreshTodayLuckyCell()
    self:_RefreshOtherLuckyCells()
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.todayluckyCell.rectTransform.parent)
end


GambleBattlePreviewCombinationsCtrl._CollectAllHandTypeList = HL.Method() << function(self)
    self.m_allHandTypeList = {}
    for handTypeId, handTypeData in pairs(Tables.gambleBattleHandTypeTable) do
        table.insert(self.m_allHandTypeList, {
            handTypeId = handTypeId,
            handTypeData = handTypeData,
        })
    end
    table.sort(self.m_allHandTypeList, Utils.genSortFunction({ "handTypeId" }, true))
end


GambleBattlePreviewCombinationsCtrl._RefreshTodayLuckyCell = HL.Method() << function(self)
    local cell = self.view.todayluckyCell
    local handTypeInfo = self:_FindHandTypeInfo(self.m_todayHandTypeId)
    if not handTypeInfo then
        cell.gameObject:SetActive(false)
        return
    end

    cell.gameObject:SetActive(true)
    local handTypeData = handTypeInfo.handTypeData
    cell.combinationNameText.text = self:_GetHandTypeName(handTypeData)
    cell.rateNumText.text = self:_FormatHandTypeBenefit(handTypeData.handTypeBenefit)
    cell.combinationDescText.text = handTypeData.desc

    cell.stateController:SetState(self.m_isMatchHandType and "Completed" or "NotAchieved")
    local cardLuaIndex2Cell = {}
    cardLuaIndex2Cell[1] = cell.gambleBattleCard01
    cardLuaIndex2Cell[2] = cell.gambleBattleCard02
    cardLuaIndex2Cell[3] = cell.gambleBattleCard03
    cardLuaIndex2Cell[4] = cell.gambleBattleCard04
    for i = 1, 4 do
        local card = cardLuaIndex2Cell[i]
        if handTypeData.showNumber.Count >= i then
            card.gameObject:SetActive(true)
            card.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER.."/icon_"..handTypeData.showNumber[i-1])
            card.typeImg:LoadSprite("Activity/ActivityGambleBattle/"..handTypeData.showIcon[i-1])
        else
            card.gameObject:SetActive(false)
        end
    end
end

GambleBattlePreviewCombinationsCtrl._RefreshOtherLuckyCells = HL.Method() << function(self)
    local otherHandTypeList = {}
    for _, handTypeInfo in ipairs(self.m_allHandTypeList) do
        if handTypeInfo.handTypeId ~= self.m_todayHandTypeId then
            table.insert(otherHandTypeList, handTypeInfo)
        end
    end

    local rowCount = math.ceil(#otherHandTypeList / 2)
    self.m_otherLuckyCellCache:Refresh(rowCount, function(cell, luaIndex)
        local leftIndex = luaIndex * 2 - 1
        local rightIndex = luaIndex * 2
        local leftHandTypeInfo = otherHandTypeList[leftIndex]
        local rightHandTypeInfo = otherHandTypeList[rightIndex]

        cell.otherTitleNode.gameObject:SetActive(luaIndex == 1)
        self:_UpdateOtherSideCell(cell, "left", leftHandTypeInfo)
        self:_UpdateOtherSideCell(cell, "right", rightHandTypeInfo)
    end)
end


GambleBattlePreviewCombinationsCtrl._UpdateOtherSideCell = HL.Method(HL.Any, HL.String, HL.Opt(HL.Table)) << function(self, cell, side, handTypeInfo)
    local sideNode = cell[side .. "Node"]
    if not sideNode then
        return
    end

    if not handTypeInfo then
        sideNode.gameObject:SetActive(false)
        return
    end

    sideNode.gameObject:SetActive(true)
    local nameText = cell[side .. "CombinationNameText"]
    local rateText = cell[side .. "RateNumText"]
    local descText = cell[side .. "DescText"]
    local handTypeData = handTypeInfo.handTypeData
    nameText.text = self:_GetHandTypeName(handTypeData)
    rateText.text = self:_FormatHandTypeBenefit(handTypeData.handTypeBenefit)
    descText.text = handTypeData.desc

    local cardLuaIndex2Cell = {}
    cardLuaIndex2Cell[1] = cell[side .. "Card01Cell"]
    cardLuaIndex2Cell[2] = cell[side .. "Card02Cell"]
    cardLuaIndex2Cell[3] = cell[side .. "Card03Cell"]
    cardLuaIndex2Cell[4] = cell[side .. "Card04Cell"]
    for i = 1, 4 do
        local card = cardLuaIndex2Cell[i]
        if handTypeData.showNumber.Count >= i then
            card.gameObject:SetActive(true)
            card.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER.."/icon_"..handTypeData.showNumber[i-1])
            card.typeImg:LoadSprite("Activity/ActivityGambleBattle/"..handTypeData.showIcon[i-1])
        else
            card.gameObject:SetActive(false)
        end
    end
end


GambleBattlePreviewCombinationsCtrl._FindHandTypeInfo = HL.Method(HL.Number).Return(HL.Any) << function(self, handTypeId)
    for _, handTypeInfo in ipairs(self.m_allHandTypeList) do
        if handTypeInfo.handTypeId == handTypeId then
            return handTypeInfo
        end
    end
    return nil
end

GambleBattlePreviewCombinationsCtrl._GetHandTypeName = HL.Method(HL.Any).Return(HL.String) << function(self, handTypeData)
    local handTypeName = handTypeData.handTypeName
    if type(handTypeName) == "string" then
        return handTypeName
    end
    if handTypeName and handTypeName.GetText then
        return handTypeName:GetText()
    end
    return ""
end


GambleBattlePreviewCombinationsCtrl._FormatHandTypeBenefit = HL.Method(HL.Number).Return(HL.String) << function(self, handTypeBenefit)
    return string.format("%.1f", handTypeBenefit / 100)
end

HL.Commit(GambleBattlePreviewCombinationsCtrl)
