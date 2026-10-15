local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.EquipFormulaChainSelect

EquipFormulaChainSelectCtrl = HL.Class('EquipFormulaChainSelectCtrl', uiCtrl.UICtrl)



EquipFormulaChainSelectCtrl.m_chainList = HL.Field(HL.Table)

EquipFormulaChainSelectCtrl.m_curFormulaId = HL.Field(HL.String) << ""

EquipFormulaChainSelectCtrl.m_selectedChainId = HL.Field(HL.Int) << 0

EquipFormulaChainSelectCtrl.m_getFormulaChainCell = HL.Field(HL.Function)

EquipFormulaChainSelectCtrl.m_formulaChainCellCache = HL.Field(HL.Forward("UIListCache"))

EquipFormulaChainSelectCtrl.m_selectedCell = HL.Field(HL.Any)

EquipFormulaChainSelectCtrl.m_equipTechSystem = HL.Field(HL.Userdata)

EquipFormulaChainSelectCtrl.m_chainChangeWay = HL.Field(HL.Userdata)

EquipFormulaChainSelectCtrl.m_oldChainId = HL.Field(HL.Int) << 0

EquipFormulaChainSelectCtrl.m_remainState = HL.Field(HL.Table)









EquipFormulaChainSelectCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_EQUIP_FORMULA_CHAIN_CHANGED] = '_OnFormulaChainChanged',
}


EquipFormulaChainSelectCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_curFormulaId = arg.formulaId or ""
    self.m_chainChangeWay = arg.chainChangeWay
    self.m_remainState = arg.remainState
    self.m_equipTechSystem = GameInstance.player.equipTechSystem;

    self:_InitAction()
    self:_InitList()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end






EquipFormulaChainSelectCtrl.OnClose = HL.Override() << function(self)
    self.m_selectedChainId = 0
    self.m_curFormulaId = ""
    self.m_chainChangeWay = nil
    self.m_remainState = nil
    self.m_oldChainId = 0
end

EquipFormulaChainSelectCtrl.ClosePanel = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end

EquipFormulaChainSelectCtrl._InitAction = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:ClosePanel()
    end)

    self.view.closeFullBtn.onClick:AddListener(function()
        self:ClosePanel()
    end)
end

EquipFormulaChainSelectCtrl._InitList = HL.Method() << function(self)
    if not self.m_formulaChainCellCache then
        self.m_formulaChainCellCache = UIUtils.genCellCache(self.view.formulaStateCell)
    end
    self:_RefreshFormulaChainCells()
end

EquipFormulaChainSelectCtrl._RefreshFormulaChainCells = HL.Method() << function(self)
    local __, formulaData = Tables.EquipFormulaTable:TryGetValue(self.m_curFormulaId)
    local compatibleChainIdSet = {}
    if formulaData then
        local level = formulaData.level
        local __, EquipLevelchainData = Tables.EquipFormulaChainTable:TryGetValue(level)
        local formulaChainList = EquipLevelchainData and EquipLevelchainData.chainList or {}
        for _, chainDetail in pairs(formulaChainList) do
            compatibleChainIdSet[chainDetail.chainId] = chainDetail
        end
    end

    local allMaterials = EquipTechUtils.GetCostMaterialList()
    self.m_chainList = allMaterials
    self.m_selectedChainId = EquipTechUtils.GetCurFormulaChainId(self.m_curFormulaId)

    self.m_formulaChainCellCache:Refresh(#allMaterials, function(cell, luaIdx)
        local materialInfo = allMaterials[luaIdx]
        self:_UpdateFormulaCell(cell, materialInfo, compatibleChainIdSet[materialInfo.chainId])

        if materialInfo.chainId == self.m_selectedChainId then
            self:SetNaviTarget(cell.selectable)
        end
    end)
end

EquipFormulaChainSelectCtrl._UpdateFormulaCell = HL.Method(HL.Table, HL.Table, HL.Any) << function(self, cell, materialInfo, chainDetail)
    local chainId = materialInfo.chainId
    local itemId = materialInfo.itemId
    local isCompatible = chainDetail ~= nil
    cell.gameObject.name = itemId

    local formulaCurChainId = EquipTechUtils.GetCurFormulaChainId(self.m_curFormulaId)
    local unlocked = EquipTechUtils.IsFormulaChainUnlock(chainId)
    local isProduceMode = self.m_chainChangeWay == CS.Beyond.SDK.EventLogDefine.EventLogChainChangeWay.Produce

    local costInfo = EquipTechUtils.GetChainCostInfo(chainId)
    if costInfo then
        if not string.isEmpty(costInfo.costGoldId) then
            local count = chainDetail and chainDetail.costGoldNum
            cell.costItemCell1.item:InitItem({ id = costInfo.costGoldId, count = count }, true)
            cell.costItemCell1.stateController:SetState(isProduceMode and "Possess" or "Surplus")

            
            if costInfo.discount and costInfo.discount >= 0 and costInfo.discount < 1 then
                cell.costItemCell1.discountInfoNode.gameObject:SetActive(true)
                local discountPercent = math.floor((1 - (costInfo.discount or 1)) * 100 + 0.5)
                local showDiscountTxt = string.format("-%d", discountPercent)
                cell.costItemCell1.discountNumTxt.text = showDiscountTxt
                cell.costItemCell1.discountNumShadownTxt.text = showDiscountTxt
            else
                cell.costItemCell1.discountInfoNode.gameObject:SetActive(false)
            end

            
            if not isProduceMode and self.m_remainState then
                local remainState = self.m_remainState
                local remaining = math.max(remainState.availByResource[costInfo.costGoldId] or 0, 0)
                local isLack = false
                if count then
                    isLack = remaining < count
                end
                cell.costItemCell1.item:UpdateCountSimple(count, isLack)
                cell.costItemCell1.ownCountTxt.text = UIUtils.setCountColor(tostring(remaining), isLack)
            else
                local ownCount = Utils.getItemCount(costInfo.costGoldId, true, true)
                cell.costItemCell1.ownCountTxt.text = UIUtils.setCountColor(tostring(ownCount))
            end

            cell.costItemCell1.item:SetExtraInfo({
                isSideTips = DeviceInfo.usingController,
                
                onBeforeJump = function()
                    if DeviceInfo.usingController then
                        cell.costItemNaviGroup:ManuallyStopFocus()
                    end
                end,
            })
        end
        if not string.isEmpty(costInfo.costItemId) then
            local count = chainDetail and chainDetail.costItemNum[0]
            cell.costItemCell2.item:InitItem({ id = costInfo.costItemId, count = count }, true)
            cell.costItemCell2.stateController:SetState(isProduceMode and "Possess" or "Surplus")

            
            if not isProduceMode and self.m_remainState then
                local remainState = self.m_remainState
                local remaining = math.max(remainState.availByResource[costInfo.costItemId] or 0, 0)
                local isLack = false
                if count then
                    isLack = remaining < count
                end
                cell.costItemCell2.item:UpdateCountSimple(count, isLack)
                cell.costItemCell2.ownCountTxt.text = UIUtils.setCountColor(tostring(remaining), isLack)
            else
                local ownCount = Utils.getItemCount(costInfo.costItemId, true, true)
                cell.costItemCell2.ownCountTxt.text = UIUtils.setCountColor(tostring(ownCount))
            end

            cell.costItemCell2.item:SetExtraInfo({
                isSideTips = DeviceInfo.usingController,
                
                onBeforeJump = function()
                    if DeviceInfo.usingController then
                        cell.costItemNaviGroup:ManuallyStopFocus()
                    end
                end,
            })
        end
    end

    cell.formulaToggleNode.interactable = isCompatible and unlocked
    cell.formulaToggleNode.onValueChanged:RemoveAllListeners()
    cell.formulaToggleNode.onValueChanged:AddListener(function(isOn)
        if not isOn and self.m_selectedChainId == chainId then
            cell.formulaToggleNode:SetIsOnWithoutNotify(true) 
            return
        end

        if isOn and self.m_selectedChainId ~= chainId then
            if self.m_selectedCell and self.m_selectedCell ~= cell then
                self.m_selectedCell.formulaToggleNode:SetIsOnWithoutNotify(false)
            end
            self.m_selectedChainId = chainId
            self.m_selectedCell = cell
            self:_DoChangeFormulaChain()
        end
    end)

    local isSelected = chainId == formulaCurChainId
    cell.formulaToggleNode:SetIsOnWithoutNotify(isSelected and isCompatible and unlocked)
    if isSelected and isCompatible and unlocked then
        self.m_selectedCell = cell
    end


    local __, fullMaterialInfo = Tables.EquipCostMaterialTable:TryGetValue(itemId)
    local isRecommended = fullMaterialInfo and fullMaterialInfo.isRecommended or false
    local defaultChain = EquipTechUtils.GetDefaultFormulaChain(self.m_curFormulaId)
    local isDefault = defaultChain and defaultChain.chainId == chainId or false
    cell.titleTxt.text = fullMaterialInfo and fullMaterialInfo.scriptName or ""
    cell.recommendNode.gameObject:SetActive(isRecommended)
    cell.initialFormulaNode.gameObject:SetActive(isDefault)

    cell.accessBtn.onClick:RemoveAllListeners()
    cell.accessBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.EquipFormulaChainAccessGuide, { chainId = chainId })
    end)

    
    if not isCompatible then
        cell.stateController:SetState("Incompatible")
    elseif not unlocked then
        cell.stateController:SetState("Lock")
    else
        cell.stateController:SetState("Available")
    end
end

EquipFormulaChainSelectCtrl._DoChangeFormulaChain = HL.Method() << function(self)
    
    self.m_oldChainId = EquipTechUtils.GetCurFormulaChainId(self.m_curFormulaId)
    self.m_equipTechSystem:SetSpecificFormulaChain(self.m_curFormulaId, self.m_selectedChainId)
end


EquipFormulaChainSelectCtrl._OnFormulaChainChanged = HL.Method(HL.Any) << function(self, arg)
    local mode, chainId = unpack(arg)
    local MODE_SINGLE = CS.Proto.EQUIP_FORMULA_CHAIN_MODE.Single:GetHashCode()
    if mode ~= MODE_SINGLE then
        return
    end
    
    if self.m_remainState then
        local remainState = self.m_remainState
        local selfCount = remainState.selfCount or 0
        local _, formulaData = Tables.EquipFormulaTable:TryGetValue(self.m_curFormulaId)
        local oldChainDetail = formulaData and EquipTechUtils.GetLevelChainDetail(formulaData.level, self.m_oldChainId)
        if selfCount > 0 and oldChainDetail then
            local availByResource = remainState.availByResource
            local hasGoldCost = not string.isEmpty(oldChainDetail.costGoldId) and oldChainDetail.costGoldNum > 0
            if hasGoldCost then
                availByResource[oldChainDetail.costGoldId] = (availByResource[oldChainDetail.costGoldId] or 0) + selfCount * oldChainDetail.costGoldNum
            end
            local costItemId = (#oldChainDetail.costItemId > 0) and oldChainDetail.costItemId[0] or nil
            local costItemNum = (#oldChainDetail.costItemNum > 0) and oldChainDetail.costItemNum[0] or 0
            if costItemId ~= nil and costItemNum > 0 then
                availByResource[costItemId] = (availByResource[costItemId] or 0) + selfCount * costItemNum
            end
        end
        remainState.selfCount = 0
        self:_RefreshFormulaChainCells()
    end
    
    if self.m_chainChangeWay == nil then
        return
    end
    EquipTechUtils.GameEventLogFactoryEquipProduceResetScript(
        self.m_curFormulaId,
        self.m_oldChainId,
        chainId,
        self.m_chainChangeWay
    )
end


EquipFormulaChainSelectCtrl.GetRecoverStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return {
        formulaId = self.m_curFormulaId,
        chainChangeWay = self.m_chainChangeWay,
        remainState = self.m_remainState,
    }
end

HL.Commit(EquipFormulaChainSelectCtrl)
