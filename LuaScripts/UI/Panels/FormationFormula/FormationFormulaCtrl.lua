local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FormationFormula

FormationFormulaCtrl = HL.Class('FormationFormulaCtrl', uiCtrl.UICtrl)







FormationFormulaCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

FormationFormulaCtrl.m_getCell = HL.Field(HL.Function)

FormationFormulaCtrl.m_formationGenGroupData = HL.Field(HL.Table)

FormationFormulaCtrl.m_formationEffectGroupData = HL.Field(HL.Table)

FormationFormulaCtrl.m_formationShowGroupData = HL.Field(HL.Table)

FormationFormulaCtrl.m_buildingId = HL.Field(HL.String) << ""

FormationFormulaCtrl.m_selectedFormation = HL.Field(HL.Table)

FormationFormulaCtrl.m_effectForamtion = HL.Field(HL.Table)

FormationFormulaCtrl.m_genTab = HL.Field(HL.Boolean) << true

FormationFormulaCtrl.m_nodeHandler = HL.Field(HL.Any)

FormationFormulaCtrl.m_currFocusCellGroup = HL.Field(HL.Userdata)


FormationFormulaCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingId = arg.buildingId
    self.m_selectedFormation = arg.selectedFormation
    self.m_effectForamtion = arg.effectForamtion
    self.m_nodeHandler = arg.nodeHandler
    if arg.genTab ~= nil then
        self.m_genTab = arg.genTab
    end

    CS.Beyond.Gameplay.Conditions.OnFormulaPanelOpen.Trigger(self.m_buildingId, false)

    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateModeCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)
    self.view.scrollList.getCellSize = function(csIndex)
        return self:_GetModeCellSize(LuaIndex(csIndex))
    end
    self.view.scrollList.getCellName = function(csIndex)
        return "FormationGroup_" .. LuaIndex(csIndex)
    end
    self.view.closeBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.closeFullBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.view.formationGenTab.onClick:AddListener(function()
        if not self.m_genTab then
            self.m_genTab = true
            self:_RefreshList()
        end
    end)
    self.view.formationEffectTab.onClick:AddListener(function()
        if self.m_genTab then
            self.m_genTab = false
            self:_RefreshList()
        end
    end)
    UIUtils.bindInputPlayerAction("fac_formation_formula_tab_pre", function()
        self.m_genTab = not self.m_genTab
        self:_RefreshList()
        AudioAdapter.PostEvent("Au_UI_Toggle_Tab_On")
    end, self.view.inputGroup.groupId)
    UIUtils.bindInputPlayerAction("fac_formation_formula_tab_next", function()
        self.m_genTab = not self.m_genTab
        self:_RefreshList()
        AudioAdapter.PostEvent("Au_UI_Toggle_Tab_On")
    end, self.view.inputGroup.groupId)
    self:_InitGroupData()
    self:_RefreshList()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

FormationFormulaCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        if self.m_currFocusCellGroup ~= nil then
            self.m_currFocusCellGroup:ManuallyStopFocus()
        end
    end
end

FormationFormulaCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        buildingId = self.m_buildingId,
        selectedFormation = lume.deepCopy(self.m_selectedFormation),
        effectForamtion = lume.deepCopy(self.m_effectForamtion),
        genTab = self.m_genTab,
    }
end

FormationFormulaCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if string.isEmpty(self.m_buildingId) then
        return
    end
    CS.Beyond.Gameplay.Conditions.OnFormulaPanelOpen.Trigger(self.m_buildingId, true)
end








FormationFormulaCtrl._RefreshList = HL.Method() << function(self)
    self.m_formationShowGroupData = self.m_genTab and self.m_formationGenGroupData or self.m_formationEffectGroupData
    
    
    self.view.scrollList:UpdateCount(#self.m_formationShowGroupData, false, true)
    if self.m_genTab then
        self.view.genAnimationNode:PlayInAnimation()
        self.view.effectAnimationNode:PlayOutAnimation()
    else
        self.view.genAnimationNode:PlayOutAnimation()
        self.view.effectAnimationNode:PlayInAnimation()
    end
end

FormationFormulaCtrl._GetModeCellSize = HL.Method(HL.Number).Return(HL.Number) << function(self, groupIndex)
    local formationGroupData = self.m_formationShowGroupData[groupIndex]
    local cellsCount = formationGroupData.cellCount
    local groupCell = self.view.formationGroupCell
    groupCell.cellsCtrl:SetState(formationGroupData.groupState)
    local formulaCellLayout = groupCell.modeCellsGridLayout
    local rows = math.ceil(cellsCount / 2)
    local gridHeight = formulaCellLayout.padding.vertical
    if rows > 0 then
        gridHeight = gridHeight + rows * formulaCellLayout.cellSize.y + (rows - 1) * formulaCellLayout.spacing.y
    end
    local basicHeight = groupCell.verticalLayoutGroup.spacing + groupCell.verticalLayoutGroup.padding.vertical
    return basicHeight + groupCell.titleNodeLayoutElement.preferredHeight + gridHeight
end

FormationFormulaCtrl._OnUpdateModeCell = HL.Method(HL.Table, HL.Number) << function(self, formationGroupCell, groupIndex)
    local formationGroupInfo = self.m_formationShowGroupData[groupIndex]
    formationGroupCell.cellsCtrl:SetState(formationGroupInfo.groupState)
    formationGroupCell.nameTxt.text = formationGroupInfo.titleName
    if string.isEmpty(formationGroupInfo.titleIcon) then
        formationGroupCell.iconImg.gameObject:SetActiveIfNecessary(false)
    else
        formationGroupCell.iconImg.gameObject:SetActiveIfNecessary(true)
        formationGroupCell.iconImg:LoadSprite(UIConst.UI_SPRITE_FAC_ENVIRONMENT_ICON, formationGroupInfo.titleIcon)
    end
    if formationGroupInfo.curLevel and formationGroupInfo.curLevel > 0 then
        formationGroupCell.currentLevel.gameObject:SetActiveIfNecessary(true)
        formationGroupCell.levelText.text = string.format(Language.LUA_FAC_FORMATION_FORMULA_EFFECT_GROUP_CUR_LEVEL, formationGroupInfo.curLevel)
    else
        formationGroupCell.currentLevel.gameObject:SetActiveIfNecessary(false)
    end

    if formationGroupCell.formationCells == nil then
        formationGroupCell.formationCells = UIUtils.genCellCache(formationGroupCell.formationCell)
    end

    formationGroupCell.formationCells:Refresh(formationGroupInfo.cellCount, function(cell, index)
        cell.stateController:SetState(formationGroupInfo.cellState)
        cell.craftContent.enabled = formationGroupInfo.cellState ~= "Superimpose"
        local cellInfo = formationGroupInfo.cellList[index]
        if formationGroupInfo.cellState == "FormationGen" then
            cell.gameObject.name = "FormationGen_" .. cellInfo.formationId
            cell.stateController:SetState(cellInfo.selected > 0 and "Normal" or "Select")
            local genCfg = Tables.factoryFormationTable:GetValue(cellInfo.formationId)
            local genName = string.format(Language.LUA_FAC_FORMATION_BASE_NAME_FORMAT, genCfg.attrName)
            cell.craftDescTxt.text = string.format(Language.LUA_FAC_FORMATION_FORMULA_GEN_CELL_TITLE, genName)
            cell.formationGenNode.magicName.text = genCfg.attrName
            cell.formationGenNode.magicIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, genCfg.icon)
            cell.formationGenNode.needNum.text = I18nUtils.CombineStringWithLanguageSpilt(cellInfo.needNum, Language["ui_fac_common_minute_speed"])
            cell.formationGenNode.activatorItem:InitItem({id = cellInfo.activatorItemId}, true)
            cell.formationGenNode.activatorItem:SetEnableHoverTips(not DeviceInfo.usingController)
            if DeviceInfo.usingController then
                local tipsPosType = index % 2 == 0 and UIConst.UI_TIPS_POS_TYPE.LeftMid or UIConst.UI_TIPS_POS_TYPE.RightMid
                cell.formationGenNode.activatorItem:SetExtraInfo({
                    tipsPosType = tipsPosType,
                    tipsPosTransform = cell.transform,
                    isSideTips = true,
                })
            end
        elseif formationGroupInfo.cellState == "Superimpose" then
            cell.gameObject.name = "Superimpose_" .. cellInfo.add .. (cellInfo.levelUp and "_levelUp" or "")
            cell.stateController:SetState("Normal")
            local leftCfg = Tables.factoryFormationTable:GetValue(cellInfo.left)
            local rightCfg = Tables.factoryFormationTable:GetValue(cellInfo.right)
            local addCfg = Tables.factoryFormationTable:GetValue(cellInfo.add)
            local addName = string.format(Language.LUA_FAC_FORMATION_BASE_NAME_FORMAT, addCfg.attrName)
            local titleFormat = cellInfo.levelUp and Language.LUA_FAC_FORMATION_FORMULA_LEVELUP_CELL_TITLE or Language.LUA_FAC_FORMATION_FORMULA_ADD_CELL_TITLE
            cell.craftDescTxt.text = string.format(titleFormat, addName)
            cell.superimposeNode.magicLeft:LoadSprite(UIConst.UI_SPRITE_ITEM, leftCfg.icon)
            cell.superimposeNode.magicRight:LoadSprite(UIConst.UI_SPRITE_ITEM, rightCfg.icon)
            cell.superimposeNode.magicAdd:LoadSprite(UIConst.UI_SPRITE_ITEM, addCfg.icon)
            cell.superimposeNode.levelUp.gameObject:SetActiveIfNecessary(cellInfo.levelUp)
        elseif formationGroupInfo.cellState == "ItemConvert" then
            cell.gameObject.name = "ItemConvert_" .. cellInfo.toItemId .. "_lv" .. cellInfo.level
            cell.stateController:SetState(cellInfo.level ~= formationGroupInfo.curLevel and "Normal" or "Select")
            local itemName = UIUtils.getItemName(cellInfo.toItemId)
            cell.craftDescTxt.text = string.format(Language.LUA_FAC_FORMATION_FORMULA_EFFECT_CELL_TITLE, itemName)
            cell.formationIcon:LoadSprite(UIConst.UI_SPRITE_FAC_ENVIRONMENT_ICON, cellInfo.titleIcon)
            local formationLevelCfg = Tables.factoryFormationLevelTable:GetValue(cellInfo.formationId)
            local levelName = formationLevelCfg.levels[cellInfo.level].name
            cell.formationName.text = levelName
            cell.itemConvertNode.fromItem:InitItem({id = cellInfo.fromItemId}, true)
            cell.itemConvertNode.toItem:InitItem({id = cellInfo.toItemId, byProductProb = math.floor(cellInfo.transChance / 100)}, true)
            cell.itemConvertNode.fromItem:SetEnableHoverTips(not DeviceInfo.usingController)
            cell.itemConvertNode.toItem:SetEnableHoverTips(not DeviceInfo.usingController)
            local effectInterval = Tables.factoryConst.facFormationEffectInterval * 0.001
            cell.itemConvertNode.time.text = string.format(Language["LUA_CRAFT_CELL_STANDARD_TIME"], FactoryUtils.getCraftTimeStr(effectInterval))
            if DeviceInfo.usingController then
                local tipsPosType = index % 2 == 0 and UIConst.UI_TIPS_POS_TYPE.LeftMid or UIConst.UI_TIPS_POS_TYPE.RightMid
                cell.itemConvertNode.fromItem:SetExtraInfo({
                    tipsPosType = tipsPosType,
                    tipsPosTransform = cell.transform,
                    isSideTips = true,
                })
                cell.itemConvertNode.toItem:SetExtraInfo({
                    tipsPosType = tipsPosType,
                    tipsPosTransform = cell.transform,
                    isSideTips = true,
                })
            end
            local pinId = FactoryUtils.composeFormationPinId(cellInfo.formationId, cellInfo.toItemId, cellInfo.level)
            cell.pinBtn:InitPinBtn(pinId, GEnums.FCPinPosition.Formula:GetHashCode())
        end

        if DeviceInfo.usingController then
            if not cell.m_focusListenerInited then
                cell.m_focusListenerInited = true
                cell.craftContent.onIsFocusedChange:AddListener(function(isFocused)
                    if not isFocused then
                        Notify(MessageConst.HIDE_ITEM_TIPS)
                    end
                    if isFocused then
                        self.m_currFocusCellGroup = cell.craftContent
                    else
                        self.m_currFocusCellGroup = nil
                    end
                end)
            end
            if groupIndex == 1 and index == 1 then
                self:SetNaviTarget(cell.inputGroupDecorator)
            end
        end
        end)
end

FormationFormulaCtrl._InitGroupData = HL.Method() << function(self)
    
    local inBlackbox = Utils.isInBlackbox()
    local unlockedByPredefined = {}
    if inBlackbox then
        local nodeHandler = self.m_nodeHandler
        local predefinedParam = nodeHandler and nodeHandler.predefinedParam
        local formationStake = predefinedParam and predefinedParam.formationStake
        local predefinedFormationIds = formationStake and formationStake.selectableFormationIds
        if predefinedFormationIds ~= nil then
            for index = 0, predefinedFormationIds.Count - 1 do
                unlockedByPredefined[predefinedFormationIds[index]] = true
            end
        end
    end
    local function isFormationUnlocked(formationId)
        if inBlackbox then
            return unlockedByPredefined[formationId] == true
        end
        return FactoryUtils.isFormationUnlockTechUnlocked(formationId)
    end

    local baseSortMap = {}
    self.m_formationGenGroupData = {}
    self.m_formationGenGroupData[1] = {
        titleIcon = "",
        titleName = Language.LUA_FAC_FORMATION_FORMULA_GEN_GROUP_TITLE,
        groupState = "Normal",
        cellState = "FormationGen",
        cellList = {},
        cellCount = 0,
    }
    local formationStakeCfg = Tables.factoryFormationStakeTable:GetValue(self.m_buildingId)
    local selectableFormationIds = formationStakeCfg.selectableFormationIds
    for i = 0, selectableFormationIds.Count - 1 do
        baseSortMap[selectableFormationIds[i]] = i + 1
        if isFormationUnlocked(selectableFormationIds[i]) then
            table.insert(self.m_formationGenGroupData[1].cellList, {
                activatorItemId = formationStakeCfg.consumeItem,
                needNum = formationStakeCfg.consumeRate,
                formationId = selectableFormationIds[i],
                selected = self.m_selectedFormation[selectableFormationIds[i]] and 0 or 1,
                sort = i + 1
            })
            self.m_formationGenGroupData[1].cellCount = self.m_formationGenGroupData[1].cellCount + 1
        end
    end

    self.m_formationGenGroupData[2] = {
        titleIcon = "",
        titleName = Language.LUA_FAC_FORMATION_FORMULA_ADD_GROUP_TITLE,
        groupState = "Normal",
        cellState = "Superimpose",
        cellList = {},
        cellCount = 0,
    }
    self.m_formationEffectGroupData = {}
    local formationEffectMap = {}
    for _, formationTransData in pairs(Tables.factoryFormationTransTable) do
        for _, transData in pairs(formationTransData.list) do
            if formationEffectMap[transData.formationId] == nil then
                formationEffectMap[transData.formationId] = {
                    maxLevel = 0,
                    transItemList = {},
                    count = 0,
                    icon = transData.titleIcon
                }
            end
            formationEffectMap[transData.formationId].maxLevel = math.max(formationEffectMap[transData.formationId].maxLevel, transData.level)
            local sort = transData.level
            if self.m_effectForamtion[transData.formationId] and self.m_effectForamtion[transData.formationId] == transData.level then
                sort = sort + 1000
            end
            table.insert(formationEffectMap[transData.formationId].transItemList, {
                formationId = transData.formationId,
                fromItemId = transData.fromItemId,
                level = transData.level,
                titleIcon = transData.titleIcon,
                toItemId = transData.toItemId,
                transChance = transData.transChance,
                sort = sort
            })
            formationEffectMap[transData.formationId].count = formationEffectMap[transData.formationId].count + 1
        end
    end
    for id, data in pairs(formationEffectMap) do
        if isFormationUnlocked(id) then
            table.sort(data.transItemList, Utils.genSortFunction({ "sort", "toItemId" }))
            local formationCfg = Tables.factoryFormationTable:GetValue(id)
            local sort = baseSortMap[id] or 100
            if self.m_effectForamtion[id] then
                sort = sort - 1000
            end
            table.insert(self.m_formationEffectGroupData, {
                titleIcon = data.icon,
                titleName = string.format(Language.LUA_FAC_FORMATION_BASE_NAME_FORMAT, formationCfg.attrName),
                groupState = "Title",
                cellState = "ItemConvert",
                cellList = data.transItemList,
                cellCount = data.count,
                curLevel = self.m_effectForamtion[id] or 0,
                sort = sort
            })
            if data.maxLevel > 0 then
                table.insert(self.m_formationGenGroupData[2].cellList, {
                    left = id,
                    right = id,
                    add = id,
                    levelUp = true,
                    sort = baseSortMap[id] or 100
                })
                self.m_formationGenGroupData[2].cellCount = self.m_formationGenGroupData[2].cellCount + 1
            end
        end
    end
    for _, formationCombineData in pairs(Tables.factoryFormationCombinationTable) do
        if formationCombineData.sourceFormationIds.Count >= 2 and isFormationUnlocked(formationCombineData.targetFormationId) then
            local sort = -1
            if baseSortMap[formationCombineData.sourceFormationIds[0]] then
                sort = math.max(sort, baseSortMap[formationCombineData.sourceFormationIds[0]] + 0.5)
            end
            if baseSortMap[formationCombineData.sourceFormationIds[1]] then
                sort = math.max(sort, baseSortMap[formationCombineData.sourceFormationIds[1]] + 0.5)
            end
            if sort > 0 then
                table.insert(self.m_formationGenGroupData[2].cellList, {
                    left = formationCombineData.sourceFormationIds[0],
                    right = formationCombineData.sourceFormationIds[1],
                    add = formationCombineData.targetFormationId,
                    levelUp = false,
                    sort = sort,
                })
                self.m_formationGenGroupData[2].cellCount = self.m_formationGenGroupData[2].cellCount + 1
            end
        end
    end

    table.sort(self.m_formationGenGroupData[1].cellList, Utils.genSortFunction({ "selected", "sort" }, true))
    table.sort(self.m_formationGenGroupData[2].cellList, Utils.genSortFunction({ "sort" }, true))
    table.sort(self.m_formationEffectGroupData, Utils.genSortFunction({ "sort" }, true))
end

HL.Commit(FormationFormulaCtrl)