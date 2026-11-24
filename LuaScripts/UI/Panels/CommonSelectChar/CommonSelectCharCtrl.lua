local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonSelectChar

CommonSelectCharCtrl = HL.Class('CommonSelectCharCtrl', uiCtrl.UICtrl)







CommonSelectCharCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}













CommonSelectCharCtrl.m_args = HL.Field(HL.Table)


CommonSelectCharCtrl.m_selectedCharInfo = HL.Field(HL.Table)


CommonSelectCharCtrl.m_defaultCharInstId = HL.Field(HL.Number) << 0


CommonSelectCharCtrl.m_filteredCharList = HL.Field(HL.Table)

CommonSelectCharCtrl.m_genStars = HL.Field(HL.Forward("UIListCache"))


CommonSelectCharCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_ProcessArgs(arg)
    self:_InitStaticNodes()
    self:_InitAction()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    self:_InitCharList()
end

CommonSelectCharCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
    self:_ProcessArgs(arg)
    self:_InitStaticNodes()
    self:_InitCharList()
end

CommonSelectCharCtrl.OnShow = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_open")
end

CommonSelectCharCtrl.OnHide = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_close")
end

CommonSelectCharCtrl.OnClose = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_close")
    if self.m_args.onCloseCallback then
        self.m_args.onCloseCallback()
    end
end



CommonSelectCharCtrl._ProcessArgs = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    
    self.m_args = arg or {}
    self.m_selectedCharInfo = nil
    self.m_defaultCharInstId = 0
    self.m_filteredCharList = {}
end

CommonSelectCharCtrl._InitStaticNodes = HL.Method() << function(self)
    local charInformation = self.view.charInformation
    
    charInformation.charSkillNode.gameObject:SetActive(false)
    charInformation.charPassiveSkillNode.gameObject:SetActive(false)
    charInformation.charFormationTacticalItem.gameObject:SetActive(false)
    charInformation.btnCultivation.gameObject:SetActive(false)
    charInformation.tagLayout.gameObject:SetActive(false)
    charInformation.tacticalItemTipsNode.gameObject:SetActive(false)
    charInformation.skillTipsNode.gameObject:SetActive(false)
    charInformation.passiveSkillTipsNode.gameObject:SetActive(false)
    charInformation.controllerFocusHintNode.gameObject:SetActive(false)

    self.m_genStars = self.m_genStars or UIUtils.genCellCache(charInformation.starIcon)

    local titleText = self.m_args.titleText
    self.view.titleTxt.gameObject:SetActive(not string.isEmpty(titleText))
    if not string.isEmpty(titleText) then
        self.view.titleTxt.text = titleText
    end

    local titleTxt02Text = self.m_args.titleTxt02Text
    self.view.titleTxt02.gameObject:SetActive(not string.isEmpty(titleTxt02Text))
    if not string.isEmpty(titleTxt02Text) then
        self.view.titleTxt02.text = titleTxt02Text
    end

    if not string.isEmpty(self.m_args.setupBtnText) then
        self.view.setupBtn.text = self.m_args.setupBtnText
    end
end

CommonSelectCharCtrl._InitAction = HL.Method() << function(self)
    self.view.setupBtn.onClick:AddListener(function()
        if not self.m_selectedCharInfo then
            return
        end
        self.m_args.setupBtnCallback(self.m_selectedCharInfo)
    end)

    self.view.btnBack.onClick:AddListener(function()
        self.m_phase:CloseSelf()
    end)
end





CommonSelectCharCtrl._InitCharList = HL.Method() << function(self)
    local charItems = self.m_args.charItems or {}
    self:_PinSelectedCharItem(charItems)

    self.view.charList:InitCharFormationList({
        selectNum = 1,
        mode = UIConst.CharListMode.Single,
        selectedCharInfo = self.m_args.selectedCharInfo,
        lockedTeamData = self.m_args.lockedTeamData,
        selectStyle = self.m_args.selectStyle,
    }, function(filteredList)
        self:_OnCharListChanged(filteredList)
    end, self.m_args.ignoreDead)

    self.view.charList:SetUpdateCellFunc(nil, function(select, cellIndex, charItem)
        self:_OnSelectChanged(charItem)
    end)

    self.view.charList:UpdateCharItems(charItems)

    
    local initialCharItem = self:_GetInitialCharItem()
    self.m_defaultCharInstId = initialCharItem and initialCharItem.instId or 0
    self.view.charList:SetMode(UIConst.CharListMode.Single, initialCharItem and initialCharItem.instId or nil)
    if initialCharItem then
        self:_OnSelectChanged(initialCharItem)
    else
        self:_RefreshSetupBtnState()
    end
end




CommonSelectCharCtrl._PinSelectedCharItem = HL.Method(HL.Table) << function(self, charItems)
    local selectedCharInfo = self.m_args.selectedCharInfo
    if selectedCharInfo == nil then
        return
    end
    for _, charItem in ipairs(charItems) do
        if charItem.instId == selectedCharInfo.charInstId then
            charItem.slotIndex = 1
            charItem.slotReverseIndex = Const.BATTLE_SQUAD_MAX_CHAR_NUM - 1
            return
        end
    end
end

CommonSelectCharCtrl._GetInitialCharItem = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local selectedCharInfo = self.m_args.selectedCharInfo
    if selectedCharInfo then
        for _, charItem in ipairs(self.m_filteredCharList) do
            if charItem.instId == selectedCharInfo.charInstId then
                return charItem
            end
        end
    end
    return self.m_filteredCharList[1]
end

CommonSelectCharCtrl._OnSelectChanged = HL.Method(HL.Table) << function(self, charItem)
    
    local charInfo = {
        charInstId = charItem.instId,
        charId = charItem.templateId,
        isLocked = charItem.isLocked,
        isTrail = charItem.isTrail,
        isReplaceable = charItem.isReplaceable,
    }
    self.m_selectedCharInfo = charInfo

    self.m_phase:ShowChar(charInfo)
    self:_RefreshCharInformation(charInfo)
    self:_RefreshSetupBtnState()
end


CommonSelectCharCtrl._OnCharListChanged = HL.Method(HL.Table) << function(self, filteredList)
    self.m_filteredCharList = filteredList
    if #filteredList > 0 then
        return
    end

    self.m_selectedCharInfo = nil
    self.m_phase:ClearChar()
    self:_RefreshCharInformation(nil)
    self:_RefreshSetupBtnState()
end

CommonSelectCharCtrl._RefreshSetupBtnState = HL.Method() << function(self)
    local canSetup = self.m_selectedCharInfo ~= nil
        and self.m_selectedCharInfo.charInstId ~= self.m_defaultCharInstId
    self.view.setupBtnState:SetState(canSetup and "NormalState" or "DisableState")
    self.view.setupBtn.interactable = canSetup
end





CommonSelectCharCtrl._RefreshCharInformation = HL.Method(HL.Opt(HL.Table)) << function(self, charInfo)
    local charInformation = self.view.charInformation
    if not charInfo then
        charInformation.gameObject:SetActive(false)
        self.m_genStars:Refresh(0)
        return
    end

    local charData = Tables.characterTable:GetValue(charInfo.charId)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInfo.charInstId)

    if charInst then
        charInformation.textLv.text = string.format("%02d", charInst.level)
    end
    charInformation.textName.text = charData.name
    charInformation.charElementIcon:InitCharTypeIcon(charData.charTypeId)
    local proSpriteName = CharInfoUtils.getCharProfessionIconName(charData.profession, true)
    charInformation.imagePro:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, proSpriteName)

    local isFixed, isTrail = CharInfoUtils.getLockedFormationCharTipsShow(charInfo)
    charInformation.fixedTips.gameObject:SetActive(isFixed)
    charInformation.tryoutTips.gameObject:SetActive(isTrail)

    self.m_genStars:Refresh(charData.rarity)

    charInformation.gameObject:SetActive(true)
end



HL.Commit(CommonSelectCharCtrl)
