local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.Formula





















FormulaCtrl = HL.Class('FormulaCtrl', uiCtrl.UICtrl)

local ALPHA_BELONGING_CANVAS_GROUP_CLOSE = 0.3
local ALPHA_BELONGING_CANVAS_GROUP_OPEN = 1.0

local MAX_SHOW_ITEM_COUNT = 2








FormulaCtrl.s_messages = HL.StaticField(HL.Table) << {
}


FormulaCtrl.m_getCell = HL.Field(HL.Function)


FormulaCtrl.m_crafts = HL.Field(HL.Table)


FormulaCtrl.m_highlightFormulaIdList = HL.Field(HL.Table)


FormulaCtrl.m_blockFormulaIdList = HL.Field(HL.Table)


FormulaCtrl.m_readFormulaIds = HL.Field(HL.Table)


FormulaCtrl.m_isMachineCrafterFormula = HL.Field(HL.Boolean) << false


FormulaCtrl.m_belongingCanvasGroup = HL.Field(HL.Userdata)


FormulaCtrl.m_extraFormulaSpeed = HL.Field(HL.Number) << 1


FormulaCtrl.m_currFocusCellGroup = HL.Field(HL.Userdata)





FormulaCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
    self.view.closeBtn.onClick:AddListener(function()
        self:_CloseSelf()
    end)
    self.view.closeFullBtn.onClick:AddListener(function()
        self:_CloseSelf()
    end)
end




FormulaCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        if self.m_currFocusCellGroup ~= nil then
            self.m_currFocusCellGroup:ManuallyStopFocus()
        end
    end
end



FormulaCtrl.ShowFormula = HL.StaticMethod(HL.Table) << function(args)
    if args == nil then
        return
    end

    local buildingId = args.buildingId
    local nodeId = args.nodeId
    local extraSpeed = args.extraSpeed or 1
    local self = UIManager:AutoOpen(PANEL_ID)
    UIManager:SetTopOrder(PANEL_ID)
    self.m_belongingCanvasGroup = args.belongingCanvasGroup  
    self.m_highlightFormulaIdList = args.highlightFormulaIdList or {}
    self.m_blockFormulaIdList = args.blockFormulaIdList or {}
    self.m_isMachineCrafterFormula = args.isMachineCrafterFormula
    self.m_extraFormulaSpeed = extraSpeed
    self:_InitFormula(buildingId, nodeId)
end





FormulaCtrl._InitFormula = HL.Method(HL.String, HL.Number) << function(self, buildingId, nodeId)
    self.m_readFormulaIds = {}
    local success, buildingTableData = Tables.factoryBuildingTable:TryGetValue(buildingId)
    if success then
        self.view.buildingNameTxt.text = buildingTableData.name
    end
    self:_ShowFormula(nodeId)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end




FormulaCtrl._ShowFormula = HL.Method(HL.Number) << function(self, nodeId)
    local crafts = FactoryUtils.getBuildingCraftsWithNodeId(nodeId)
    if crafts == nil or not next(crafts) then
        return
    end

    self.m_crafts = crafts
    
    local highlightIndex = 1
    local index = 1
    repeat
        local craftInfo = self.m_crafts[index]
        local isHighlighted = self:_IsFormulaHighlighted(craftInfo.craftId)
        if isHighlighted and highlightIndex ~= index then
            local temp = self.m_crafts[highlightIndex]
            self.m_crafts[highlightIndex] = craftInfo
            self.m_crafts[index] = temp
            highlightIndex = highlightIndex + 1
        end
        index = index + 1
    until index > #self.m_crafts
    self.view.scrollList:UpdateCount(#crafts)
end




FormulaCtrl._IsFormulaHighlighted = HL.Method(HL.String).Return(HL.Boolean) << function(self, formulaId)
    for _, highlightId in pairs(self.m_highlightFormulaIdList) do
        if formulaId == highlightId then
            return true
        end
    end
    return false
end




FormulaCtrl._IsFormulaBlocked = HL.Method(HL.String).Return(HL.Boolean) << function(self, formulaId)
    for _, blockId in pairs(self.m_blockFormulaIdList) do
        if formulaId == blockId then
            return true
        end
    end
    return false
end





FormulaCtrl._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    local craftInfo = self.m_crafts[index]
    local formulaCell = cell.formulaCell
    local isSpecialFormula = string.isEmpty(craftInfo.craftId) or not Tables.factoryMachineCraftTable:ContainsKey(craftInfo.craftId)

    
    craftInfo.time = craftInfo.time * self.m_extraFormulaSpeed
    formulaCell.time.text = string.format(Language["LUA_CRAFT_CELL_STANDARD_TIME"], FactoryUtils.getCraftTimeStr(craftInfo.time, true))

    
    local descSuccess, formulaTableData = Tables.factoryMachineCraftTable:TryGetValue(craftInfo.craftId)
    if descSuccess then
        formulaCell.craftDescTxt.text = formulaTableData.formulaDesc
    end
    formulaCell.craftDescTxt.gameObject:SetActive(descSuccess)
    formulaCell.titleIcon.gameObject:SetActive(descSuccess)

    
    local isHighlighted = self:_IsFormulaHighlighted(craftInfo.craftId)
    local isBlocked = self:_IsFormulaBlocked(craftInfo.craftId)
    formulaCell.normalNode.gameObject:SetActive(not isHighlighted)
    formulaCell.selectNode.gameObject:SetActive(isHighlighted)
    formulaCell.noPinNormalNode.gameObject:SetActive(not isHighlighted)
    formulaCell.noPinSelectNode.gameObject:SetActive(isHighlighted)
    formulaCell.normalBgNode.gameObject:SetActive(not isSpecialFormula)
    formulaCell.noPinBgNode.gameObject:SetActive(isSpecialFormula)
    if isHighlighted then
        formulaCell.selectTitleNode.gameObject:SetActive(not isBlocked)
        formulaCell.blockTitleNode.gameObject:SetActive(isBlocked)
    else
        formulaCell.selectTitleNode.gameObject:SetActive(false)
        formulaCell.blockTitleNode.gameObject:SetActive(false)
    end
    local color = isHighlighted and self.view.config.HIGHLIGHT_CELL_TIME_COLOR or self.view.config.NORMAL_CELL_TIME_COLOR
    formulaCell.timeNode.color = color

    
    if cell.incomeCells == nil then
        cell.incomeCells = UIUtils.genCellCache(formulaCell.incomeItem)
    end
    local incomeCells = cell.incomeCells
    incomeCells:Refresh(math.max(#craftInfo.incomes, MAX_SHOW_ITEM_COUNT), function(incomeCell, incomeIndex)
        local showItem = incomeIndex <= #craftInfo.incomes
        if showItem then
            local bundle = craftInfo.incomes[incomeIndex]
            incomeCell.item:InitItem(bundle, true)
            incomeCell.item:SetEnableHoverTips(not DeviceInfo.usingController)
            incomeCell.item.gameObject.name = "Item_" .. bundle.id
            incomeCell.gameObject.name = "Income_" .. bundle.id
            if DeviceInfo.usingController then
                local tipsPosType = index % 2 == 0 and UIConst.UI_TIPS_POS_TYPE.LeftMid or UIConst.UI_TIPS_POS_TYPE.RightMid
                incomeCell.item:SetExtraInfo({
                    tipsPosType = tipsPosType,
                    tipsPosTransform = formulaCell.controllerHintNode,
                    isSideTips = true,
                })
            end
        end
        incomeCell.item.gameObject:SetActive(showItem)
        incomeCell.emptyNode.gameObject:SetActive(not showItem)
        incomeCell.emptyNode.color = isHighlighted and self.view.config.HIGHLIGHT_CELL_EMPTY_COLOR or self.view.config.NORMAL_CELL_EMPTY_COLOR
    end)
    
    
    if craftInfo.outcomes then
        if cell.outcomeCells == nil then
            cell.outcomeCells = UIUtils.genCellCache(formulaCell.outcomeItem)
        end
        local outcomeCells = cell.outcomeCells
        outcomeCells:Refresh(math.max(#craftInfo.outcomes, MAX_SHOW_ITEM_COUNT), function(outcomeCell, outcomeIndex)
            local showItem = outcomeIndex <= #craftInfo.outcomes
            if showItem then
                local bundle = craftInfo.outcomes[outcomeIndex]
                outcomeCell.item:InitItem(bundle, true)
                outcomeCell.item:SetEnableHoverTips(not DeviceInfo.usingController)
                outcomeCell.item.gameObject.name = "Item_" .. bundle.id
                outcomeCell.gameObject.name = "Outcome_" .. bundle.id
                if DeviceInfo.usingController then
                    local tipsPosType = index % 2 == 0 and UIConst.UI_TIPS_POS_TYPE.LeftMid or UIConst.UI_TIPS_POS_TYPE.RightMid
                    outcomeCell.item:SetExtraInfo({
                        tipsPosType = tipsPosType,
                        tipsPosTransform = formulaCell.controllerHintNode,
                        isSideTips = true,
                    })
                end
            end
            outcomeCell.item.gameObject:SetActive(showItem)
            outcomeCell.emptyNode.gameObject:SetActive(not showItem)
            outcomeCell.emptyNode.color = isHighlighted and self.view.config.HIGHLIGHT_CELL_EMPTY_COLOR or self.view.config.NORMAL_CELL_EMPTY_COLOR
        end)
        formulaCell.outcomeItems.gameObject:SetActive(true)
    else
        formulaCell.outcomeItems.gameObject:SetActive(false)
    end
    if craftInfo.outcomeText then
        formulaCell.outcomePower.gameObject:SetActive(true)
        formulaCell.powerText.text = craftInfo.outcomeText
    else
        formulaCell.outcomePower.gameObject:SetActive(false)
    end
    formulaCell.outcomeFinish.gameObject:SetActive(craftInfo.useFinish)

    
    if not isSpecialFormula then
        formulaCell.pinBtn:InitPinBtn(craftInfo.craftId, GEnums.FCPinPosition.Formula:GetHashCode())
    end
    formulaCell.pinBtn.view.gameObject:SetActive(not isSpecialFormula)
    formulaCell.invalidPinBtn.gameObject:SetActive(isSpecialFormula)

    
    self.m_readFormulaIds[craftInfo.craftId] = true
    if Utils.isInBlackbox() then
        cell.redDot.gameObject:SetActive(false)  
    else
        cell.redDot:InitRedDot("Formula", craftInfo.craftId)
        local hasRedDot = RedDotUtils.hasCraftRedDot(craftInfo.craftId)
        cell.redDot.gameObject:SetActive(hasRedDot)
    end

    cell.gameObject.name = craftInfo.craftId

    
    if DeviceInfo.usingController then
        formulaCell.contentNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
            if isFocused then
                self.m_currFocusCellGroup = formulaCell.contentNaviGroup
            else
                self.m_currFocusCellGroup = nil
            end
        end)
        if index == 1 then
            UIUtils.setAsNaviTarget(formulaCell.inputGroupDecorator)
        end
    end
end



FormulaCtrl._ReadFormulas = HL.Method() << function(self)
    if not self.m_isMachineCrafterFormula then
        return
    end

    if not next(self.m_readFormulaIds) then
        return
    end

    local formulaIds = {}
    for k, _ in pairs(self.m_readFormulaIds) do
        table.insert(formulaIds, k)
    end
    self.m_readFormulaIds = {}

    GameInstance.player.remoteFactory.core:ReadFormula(formulaIds)
end



FormulaCtrl._CloseSelf = HL.Method() << function(self)
    self:_ReadFormulas()
    self:PlayAnimationOutWithCallback(function()
        self:Close()
    end)
end

HL.Commit(FormulaCtrl)
