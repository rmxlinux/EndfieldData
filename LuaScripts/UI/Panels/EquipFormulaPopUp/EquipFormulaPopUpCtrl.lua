local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.EquipFormulaPopUp

EquipFormulaPopUpCtrl = HL.Class('EquipFormulaPopUpCtrl', uiCtrl.UICtrl)



EquipFormulaPopUpCtrl.m_formulaId = HL.Field(HL.String) << ""

EquipFormulaPopUpCtrl.m_newChainId = HL.Field(HL.Int) << 0

EquipFormulaPopUpCtrl.m_onConfirm = HL.Field(HL.Function)









EquipFormulaPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


EquipFormulaPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    arg = arg or {}
    self.m_formulaId = arg.formulaId or ""
    self.m_newChainId = arg.chainId or 0
    self.m_onConfirm = arg.confirm

    self:_InitAction()
    self:_RefreshContent()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

EquipFormulaPopUpCtrl.OnClose = HL.Override() << function(self)
    self.m_formulaId = ""
    self.m_newChainId = 0
    self.m_onConfirm = nil
end

EquipFormulaPopUpCtrl.ClosePanel = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end

EquipFormulaPopUpCtrl._InitAction = HL.Method() << function(self)
    self.view.confirmButton.onClick:AddListener(function()
        if self.m_onConfirm then
            self.m_onConfirm(self.m_formulaId, self.m_newChainId)
        end
        self:ClosePanel()
    end)
    self.view.cancelButton.onClick:AddListener(function()
        self:ClosePanel()
    end)
    
    
    
end

EquipFormulaPopUpCtrl._RefreshContent = HL.Method() << function(self)
    local formulaId = self.m_formulaId
    local _, formulaData = Tables.EquipFormulaTable:TryGetValue(formulaId)
    if not formulaData then
        return
    end

    
    local _, itemData = Tables.itemTable:TryGetValue(formulaData.outcomeEquipId)
    local equipName = itemData and itemData.name or ""
    self.view.switchFormulaTxt.text = string.format(Language.LUA_EQUIP_ENHANCE_QUICK_CHANGE_FORMULA_CHAIN, equipName)

    
    local level = formulaData.level
    local curChainId = EquipTechUtils.GetCurFormulaChainId(formulaId)
    self:_RefreshFormulaNode(self.view.formulaNodeA, level, curChainId)
    self:_RefreshFormulaNode(self.view.formulaNodeB, level, self.m_newChainId)
end


EquipFormulaPopUpCtrl._RefreshFormulaNode = HL.Method(HL.Any, HL.Number, HL.Int) << function(self, node, level, chainId)
    local chainData = EquipTechUtils.GetLevelChainDetail(level, chainId)
    if not chainData then
        node.costItemCell1.gameObject:SetActive(false)
        node.costItemCell2.gameObject:SetActive(false)
        node.formulaTxt.text = ""
        return
    end

    local costInfo = EquipTechUtils.GetChainCostInfo(chainId)
    local hasGoldCost = not string.isEmpty(chainData.costGoldId) and chainData.costGoldNum > 0
    local costItemId = (#chainData.costItemId > 0) and chainData.costItemId[0] or nil
    local costItemNum = (#chainData.costItemNum > 0) and chainData.costItemNum[0] or 0
    local hasMatCost = costItemId ~= nil and costItemNum > 0

    
    local scriptName = ""
    if costItemId then
        local _, matInfo = Tables.EquipCostMaterialTable:TryGetValue(costItemId)
        scriptName = matInfo and matInfo.scriptName or ""
    end
    node.formulaTxt.text = scriptName

    
    node.costItemCell1.gameObject:SetActive(hasGoldCost)
    if hasGoldCost then
        node.costItemCell1.item:InitItem({ id = chainData.costGoldId, count = chainData.costGoldNum }, true)
        node.costItemCell1.item:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
        if DeviceInfo.usingController then
            node.costItemCell1.item:SetEnableHoverTips(false)
        end
        local discount = costInfo and costInfo.discount
        if discount and discount >= 0 and discount < 1 then
            node.costItemCell1.discountInfoNode.gameObject:SetActive(true)
            local showDiscountTxt = string.format("-%d", math.floor((1 - discount) * 100 + 0.5))
            node.costItemCell1.discountNumTxt.text = showDiscountTxt
            node.costItemCell1.discountNumShadownTxt.text = showDiscountTxt
        else
            node.costItemCell1.discountInfoNode.gameObject:SetActive(false)
        end
        local ownCount = Utils.getItemCount(chainData.costGoldId, true, true)
        node.costItemCell1.ownCountTxt.text = UIUtils.setCountColor(tostring(ownCount))
    end

    
    node.costItemCell2.gameObject:SetActive(hasMatCost)
    if hasMatCost then
        node.costItemCell2.item:InitItem({ id = costItemId, count = costItemNum }, true)
        node.costItemCell2.item:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
        if DeviceInfo.usingController then
            node.costItemCell2.item:SetEnableHoverTips(false)
        end
        node.costItemCell2.discountInfoNode.gameObject:SetActive(false)
        local ownCount = Utils.getItemCount(costItemId, true, true)
        node.costItemCell2.ownCountTxt.text = UIUtils.setCountColor(tostring(ownCount))
    end
end

HL.Commit(EquipFormulaPopUpCtrl)
