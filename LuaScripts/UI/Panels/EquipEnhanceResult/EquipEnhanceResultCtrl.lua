
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.EquipEnhanceResult

EquipEnhanceResultCtrl = HL.Class('EquipEnhanceResultCtrl', uiCtrl.UICtrl)






EquipEnhanceResultCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

EquipEnhanceResultCtrl.m_returnedIngredientInstIds = HL.Field(HL.Table)

EquipEnhanceResultCtrl.m_returnedItemEntries = HL.Field(HL.Table)

EquipEnhanceResultCtrl.m_getReturnEquipItemCell = HL.Field(HL.Function)

EquipEnhanceResultCtrl.m_enhanceMode = HL.Field(HL.String) << "own" 













EquipEnhanceResultCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    local args = arg

    self:_InitController()

    self.view.btnClose.onClick:AddListener(function()
        self:Close()
        if args.closeCallback then
            args.closeCallback()
        end
    end)

    self.m_enhanceMode = args and args.enhanceMode or "own"


    self.view.stateCtrl:SetState(args.isSuccessful and "success" or "fail")
    AudioAdapter.PostEvent(args.isSuccessful and "Au_UI_Popup_EquipForgSuccess_Open" or "Au_UI_Popup_EquipForgFail_Open")
    self.view.equipItem:InitEquipItem({
        equipInstId = args.equipInstId,
    })

    local equipInstData = EquipTechUtils.getEquipInstData(args.equipInstId)
    local itemData = Tables.itemTable[equipInstData.templateId]
    self.view.txtEquipName.text = itemData.name

    self.view.equipEnhanceLevelNode:InitEquipEnhanceLevelNode({
        equipInstId = args.equipInstId,
        attrIndex = args.attrShowInfo.enhancedAttrIndex,
    })
    self.view.txtAttrName.text = args.attrShowInfo.showName
    self.view.txtAttrValueBefore.text = EquipTechUtils.getAttrShowValueText(args.attrShowInfo)
    if args.isSuccessful then
        self.view.txtAttrValueAfter.text = args.nextLevelAttrShowValue
    else
        local delta = args.enhanceFailCountDelta
        if delta and delta > 0 then
            self.view.failNumberTxt.text = string.format("+%d", delta)
        end
    end
    self:_RefreshReturnedIngredientList(args.returnedIngredientInstIds, args.returnedItemEntries)
    self:_StartTimer(self.view.config.REWARD_AUDIO_DELAY_TIME, function()
        AudioAdapter.PostEvent("Au_UI_Popup_RewardsItem_Open")
    end)
end

EquipEnhanceResultCtrl._RefreshReturnedIngredientList = HL.Method(HL.Opt(HL.Table, HL.Table)) << function(self, returnedInstIds, returnedItemEntries)
    self.m_returnedIngredientInstIds = returnedInstIds or {}
    self.m_returnedItemEntries = returnedItemEntries or {}
    local node = self.view.returnEquipNode
    local count = #self.m_returnedIngredientInstIds + #self.m_returnedItemEntries
    if count == 0 then
        node.gameObject:SetActive(false)
        return
    end
    node.gameObject:SetActive(true)
    self.m_getReturnEquipItemCell = self.m_getReturnEquipItemCell or UIUtils.genCachedCellFunction(node.rewardsScrollList)
    node.rewardsScrollList.onUpdateCell:RemoveAllListeners()
    node.rewardsScrollList.onUpdateCell:AddListener(function(object, csIndex)
        local cell = self.m_getReturnEquipItemCell(object)
        self:_OnUpdateReturnEquipItemCell(cell, LuaIndex(csIndex))
    end)
    node.rewardsScrollList:UpdateCount(count)

    if count < node.rewardsScrollList.countPerLine then
        local pos = node.keyHint.anchoredPosition
        pos.x = node.rewardsScrollList:Get(0).transform.anchoredPosition.x
        node.keyHint.anchoredPosition = pos
    end
    node.titleText.text = self.m_enhanceMode == "own" and Language.LUA_EQUIP_ENHANCE_EQUIP_MODE_RETURN or Language.LUA_EQUIP_ENHANCE_WAITING_MODE_RETURN
end

EquipEnhanceResultCtrl._OnUpdateReturnEquipItemCell = HL.Method(HL.Forward("Item"), HL.Number) << function(self, cell, index)
    
    local itemEntryCount = #self.m_returnedItemEntries
    if itemEntryCount > 0 and index <= itemEntryCount then
        local entry = self.m_returnedItemEntries[index]
        cell.gameObject.name = tostring(entry.id)
        cell:InitItem({ id = entry.id, count = entry.count }, true)
        cell:SetExtraInfo({
            isSideTips = DeviceInfo.usingController,
        })
        return
    end
    
    local instIdx = index - itemEntryCount
    local instId = self.m_returnedIngredientInstIds[instIdx]
    local equipInst = CharInfoUtils.getEquipByInstId(instId)
    if not equipInst then
        return
    end
    cell.gameObject.name = tostring(instId)
    cell:InitItem({ id = equipInst.templateId, instId = instId }, true)
    cell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
end

EquipEnhanceResultCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end



HL.Commit(EquipEnhanceResultCtrl)
