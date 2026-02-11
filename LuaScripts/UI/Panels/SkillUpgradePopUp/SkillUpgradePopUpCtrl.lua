local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SkillUpgradePopUp
















SkillUpgradePopUpCtrl = HL.Class('SkillUpgradePopUpCtrl', uiCtrl.UICtrl)








SkillUpgradePopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
}


SkillUpgradePopUpCtrl.m_cells = HL.Field(HL.Forward("UIListCache"))


SkillUpgradePopUpCtrl.m_subDescCellCache = HL.Field(HL.Forward("UIListCache"))


SkillUpgradePopUpCtrl.m_arg = HL.Field(HL.Any)




SkillUpgradePopUpCtrl.OnSkillLevelUpgraded = HL.StaticMethod(HL.Table) << function(arg)
    local ctrl = SkillUpgradePopUpCtrl.AutoOpen(PANEL_ID, arg, true)
    local charInstId, skillGroupId, level = unpack(arg)

    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

    ctrl:ShowSkillUpgrade(charInstId, skillGroupId, level)
end



SkillUpgradePopUpCtrl.OnTalentLevelUpgraded = HL.StaticMethod(HL.Table) << function(arg)
    local charInstId, nodeId = unpack(arg)

    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local talentCfg = CharInfoUtils.getTalentNodeCfg(charInst.templateId, nodeId)

    if (talentCfg.nodeType == GEnums.TalentNodeType.CharBreak) or (talentCfg.nodeType == GEnums.TalentNodeType.EquipBreak) then
        return
    end

    local ctrl = SkillUpgradePopUpCtrl.AutoOpen(PANEL_ID, arg, true)
    ctrl:ShowTalentUpgrade(charInstId, nodeId)
end





SkillUpgradePopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    local charInstId, nodeId = unpack(arg)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    Utils.triggerVoice("chrup_skill", charInst.templateId)

    self.m_arg = arg

    self.view.btnClose.onClick:RemoveAllListeners()
    self.view.btnClose.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    UIUtils.bindHyperlinkPopup(self, "SkillUpgradePopUp", self.view.inputGroup.groupId)

    self.m_subDescCellCache = UIUtils.genCellCache(self.view.skillUpgradeNode.cell)
    self:_ResetPopUpPanel()
end

 
 
SkillUpgradePopUpCtrl.OnShow = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_btn_skill_levelup_popup")
end



SkillUpgradePopUpCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.ON_CLOSE_SKILL_UPGRADE_POPUP, self.m_arg)
end






SkillUpgradePopUpCtrl.ShowSkillUpgrade = HL.Method(HL.Int, HL.String, HL.Number) << function(self, charInstId, skillGroupId, curSkillLv)
    AudioAdapter.PostEvent("Au_UI_Popup_SkillUpgradePopUpPanel_Open")

    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local skillGroupCfg = CharInfoUtils.getSkillGroupCfg(charInst.templateId, skillGroupId)
    local skillUpgradeNode = self.view.skillUpgradeNode

    skillUpgradeNode.gameObject:SetActive(true)
    skillUpgradeNode.levelBefore.text = curSkillLv - 1
    skillUpgradeNode.levelCur.text = curSkillLv
    skillUpgradeNode.polygonBefore:InitElitePolygon(curSkillLv - 1 - UIConst.CHAR_MAX_SKILL_NORMAL_LV)
    skillUpgradeNode.polygonCur:InitElitePolygon(curSkillLv - UIConst.CHAR_MAX_SKILL_NORMAL_LV)

    local isElite = curSkillLv - 1 >= UIConst.CHAR_MAX_SKILL_NORMAL_LV
    skillUpgradeNode.polygonBefore.view.gameObject:SetActive(isElite)
    skillUpgradeNode.polygonCur.view.gameObject:SetActive(isElite)
    skillUpgradeNode.levelBefore.gameObject:SetActive(not isElite)
    skillUpgradeNode.levelCur.gameObject:SetActive(not isElite)
    skillUpgradeNode.levelDeco.gameObject:SetActive(not isElite)
    skillUpgradeNode.levelDeco2.gameObject:SetActive(not isElite)



    skillUpgradeNode.name.text = skillGroupCfg.name
    skillUpgradeNode.btnSkill:InitCharInfoSkillButtonNew(charInst, skillGroupCfg.skillGroupType)
    skillUpgradeNode.btnSkill.view.rank.gameObject:SetActive(false)
    skillUpgradeNode.btnSkill.view.eliteNode.gameObject:SetActive(false)


    local skillDescNameList, skillDescList = CharInfoUtils.getSkillGroupSubDescList(charInst.templateId, skillGroupId, curSkillLv)
    self.m_subDescCellCache:Refresh(#skillDescNameList, function(cell, index)
        if skillDescNameList[index] == nil then
            cell.gameObject:SetActive(false)
            return
        end

        local subDescName = skillDescNameList[index]
        local subDesc = skillDescList[index]
        cell.image.enabled = index % 2 ~= 0

        cell.subDescName.text = subDescName
        cell.subDesc.text = subDesc
    end)
end





SkillUpgradePopUpCtrl.ShowTalentUpgrade = HL.Method(HL.Number, HL.String) << function(self, charInstId, nodeId)
    AudioAdapter.PostEvent("Au_UI_Popup_TalentUpgradePopUpPanel_Open")

    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local talentCfg = CharInfoUtils.getTalentNodeCfg(charInst.templateId, nodeId)

    if talentCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
        self:_ShowPassiveSkillUpgrade(charInstId, nodeId)
    elseif talentCfg.nodeType == GEnums.TalentNodeType.Attr then
        self:_ShowAttributeUpgrade(charInstId, nodeId)
    elseif talentCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
        self:_ShowShipSkillUpgrade(charInstId, nodeId)
    end
end





SkillUpgradePopUpCtrl._ShowShipSkillUpgrade = HL.Method(HL.Number, HL.String) << function(self, charInstId, nodeId)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

    local curNodeCfg = CharInfoUtils.getTalentNodeCfg(charInst.templateId, nodeId)
    local curSkillInfo = curNodeCfg.factorySkillNodeInfo

    local beforeNodeCfg = CharInfoUtils.getShipSkillTalentNodeByIndex(charInst.templateId, curSkillInfo.index, curSkillInfo.level - 1)
    local hasSkillBefore = beforeNodeCfg ~= nil

    local skillId = CharInfoUtils.getShipSkillIdByTalentNodeId(charInst.templateId, nodeId)
    local shipSkillCfgCur = Tables.spaceshipSkillTable[skillId]

    local shipSkillNode = self.view.shipSkillNode
    shipSkillNode.gameObject:SetActive(true)
    shipSkillNode.beforeNode.gameObject:SetActive(hasSkillBefore)
    shipSkillNode.curNode.gameObject:SetActive(true)

    if hasSkillBefore then
        local shipSkillCfgBefore = Tables.spaceshipSkillTable[CharInfoUtils.getShipSkillIdByTalentNodeId(charInst.templateId, beforeNodeCfg.nodeId)]
        shipSkillNode.shipSkillPostfixBefore.text = shipSkillCfgBefore.skillNamePostfix
    end
    

    shipSkillNode.shipSkillPostfixCur.text = shipSkillCfgCur.skillNamePostfix

    local shipSkillId = CharInfoUtils.getShipSkillIdByTalentNodeId(charInst.templateId, nodeId)
    local curSkillCfg = CharInfoUtils.getShipSkillCfg(shipSkillId)
    shipSkillNode.name.text = curSkillCfg.talentName
    shipSkillNode.desc.text = curSkillCfg.desc
    shipSkillNode.icon:LoadSprite(UIConst.UI_SPRITE_SS_SKILL_ICON, curSkillCfg.icon)
end





SkillUpgradePopUpCtrl._ShowPassiveSkillUpgrade = HL.Method(HL.Number, HL.String) << function(self, charInstId, nodeId)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

    local curNodeCfg = CharInfoUtils.getTalentNodeCfg(charInst.templateId, nodeId)
    local curSkillInfo = curNodeCfg.passiveSkillNodeInfo

    local beforeNodeCfg = CharInfoUtils.getPassiveSkillTalentNodeByIndex(charInst.templateId, curSkillInfo.index, curSkillInfo.level - 1)
    local hasSkillBefore = beforeNodeCfg ~= nil

    local passiveSkillNode = self.view.passiveSkillNode
    passiveSkillNode.gameObject:SetActive(true)
    passiveSkillNode.beforeNode.gameObject:SetActive(hasSkillBefore)
    passiveSkillNode.curNode.gameObject:SetActive(true)

    if hasSkillBefore then
        local beforeSkillInfo = beforeNodeCfg.passiveSkillNodeInfo
        passiveSkillNode.stageGroupBefore:InitStageLevelCellGroup(beforeSkillInfo.level)
    end

    passiveSkillNode.stageGroupCur:InitStageLevelCellGroup(curSkillInfo.level)

    passiveSkillNode.name.text = curSkillInfo.name
    local nodeDesc = CS.Beyond.Gameplay.TalentUtil.GetTalentNodeDescription(charInst.templateId, curNodeCfg.nodeId)
    passiveSkillNode.desc:SetAndResolveTextStyle(nodeDesc)
    passiveSkillNode.icon:LoadSprite(UIConst.UI_SPRITE_SKILL_ICON, curSkillInfo.iconId)
end





SkillUpgradePopUpCtrl._ShowAttributeUpgrade = HL.Method(HL.Number, HL.String) << function(self, charInstId, nodeId)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local nodeCfg = CharInfoUtils.getTalentNodeCfg(charInst.templateId, nodeId)
    local attrNodeInfo = nodeCfg.attributeNodeInfo
    local attrType = attrNodeInfo.attributeModifier.attrType
    local attrKey = Const.ATTRIBUTE_TYPE_2_ATTRIBUTE_DATA_KEY[attrType]

    local attributeNode = self.view.attributeNode
    attributeNode.gameObject:SetActive(true)
    attributeNode.icon:LoadSprite(UIConst.UI_SPRITE_ATTRIBUTE_ICON, UIConst.UI_ATTRIBUTE_ICON_PREFIX .. attrKey)
    attributeNode.name.text = attrNodeInfo.title
    attributeNode.desc.text = attrNodeInfo.desc
end




SkillUpgradePopUpCtrl._ResetPopUpPanel = HL.Method() << function(self)
    self.view.skillUpgradeNode.gameObject:SetActive(false)
    
    self.view.passiveSkillNode.gameObject:SetActive(false)
    self.view.attributeNode.gameObject:SetActive(false)
    self.view.shipSkillNode.gameObject:SetActive(false)
end

HL.Commit(SkillUpgradePopUpCtrl)
