local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnCharTips

InnCharTipsCtrl = HL.Class('InnCharTipsCtrl', uiCtrl.UICtrl)







InnCharTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.HIDE_INN_CHAR_TIPS] = 'HideInnCharTips',
}

InnCharTipsCtrl.m_args = HL.Field(HL.Table)

InnCharTipsCtrl.m_isSideTips = HL.Field(HL.Boolean) << false


InnCharTipsCtrl.m_pendingOpenArgs = HL.Field(HL.Table)

InnCharTipsCtrl.m_ownerSkillCache = HL.Field(HL.Forward('UIListCache'))
InnCharTipsCtrl.m_conditionCellCache = HL.Field(HL.Forward('UIListCache'))
InnCharTipsCtrl.m_tagCellCache = HL.Field(HL.Forward('UIListCache'))












InnCharTipsCtrl.ShowInnCharTips = HL.StaticMethod(HL.Table) << function(args)
    local isOpen, baseCtrl = UIManager:IsOpen(PANEL_ID)
    
    local ctrl = baseCtrl
    if isOpen and ctrl then
        if ctrl:IsPlayingAnimationOut() then
            ctrl:_TriggerOnClose()
            ctrl.m_pendingOpenArgs = args
            return
        end
        
        ctrl:_ApplyArgs(args)
        ctrl:PlayAnimationIn()
        return
    end
    UIManager:AutoOpen(PANEL_ID, args)
end


InnCharTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.main.onTriggerAutoClose:AddListener(function()
        
        if self.m_isSideTips then 
            return 
        end
        self:_TriggerOnClose()
        self:PlayAnimationOutAndClose()
    end)

    self:_ApplyArgs(arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnCharTipsCtrl.OnClose = HL.Override() << function(self)
    self:_TriggerOnClose()
    
    if self.m_pendingOpenArgs then
        local args = self.m_pendingOpenArgs
        self.m_pendingOpenArgs = nil
        UIManager:AutoOpen(PANEL_ID, args)
    end
end

InnCharTipsCtrl.HideInnCharTips = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if not self.m_isSideTips then 
        return 
    end
    if self:IsPlayingAnimationOut() then 
        return 
    end
    self:_TriggerOnClose()
    self:PlayAnimationOutAndClose()
end

InnCharTipsCtrl._TriggerOnClose = HL.Method() << function(self)
    if self.m_args and self.m_args.onClose then
        local onClose = self.m_args.onClose
        self.m_args.onClose = nil
        onClose()
    end
end



InnCharTipsCtrl._ApplyArgs = HL.Method(HL.Any) << function(self, arg)
    self:_TriggerOnClose()
    self.m_args = arg or {}

    local charId = self.m_args.charId
    local innConst = Tables.innManagementConst
    local isOwner = charId == innConst.jsspsiCharId

    
    if not string.isEmpty(charId) then
        self.view.charImg:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE,
            UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. charId)
        local hasChar, charData = Tables.characterTable:TryGetValue(charId)
        if hasChar and charData then
            self.view.charNameTxt.text = charData.name
        end
    end

    self.view.stateController:SetState(isOwner and "Owner" or "Chef")

    if isOwner then
        self:_RefreshOwner()
    else
        self:_RefreshChef()
    end

    UIUtils.updateTipsPosition(self.view.main.transform, self.m_args.transform,
        self.view.rectTransform, self.uiCamera, self.m_args.posType)

    self.m_isSideTips = (self.m_args.isSideTips == true)
    self:ChangeCurPanelBlockSetting(not self.m_isSideTips)
    self.view.main:ChangeEnableCloseActionOnController(not self.m_isSideTips)
end


InnCharTipsCtrl._RefreshOwner = HL.Method() << function(self)
    local innConst = Tables.innManagementConst
    local inn = GameInstance.player and GameInstance.player.innSystem
    local jsspsiCharId = innConst.jsspsiCharId

    local jsspsiCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(jsspsiCharId, GEnums.CharType.Default)
    local friendship = jsspsiCharInfo and CSPlayerDataUtil.GetCharFriendship(jsspsiCharId) or 0

    if jsspsiCharInfo then
        self.view.friendshipNode.view.gameObject:SetActive(true)
        self.view.friendshipNode:InitFriendshipNode(jsspsiCharInfo.instId)
    else
        self.view.friendshipNode.view.gameObject:SetActive(flase)
    end

    
    self.view.innOwnerBuffNode:InitInnOwnerBuffNode()

    
    local dutyRows = {}
    if inn and inn.jsspsiDutyUnlockInnLevel then
        for dutyType, unlockLevel in pairs(inn.jsspsiDutyUnlockInnLevel) do
            dutyRows[#dutyRows + 1] = { dutyType = dutyType, unlockLevel = unlockLevel }
        end
        table.sort(dutyRows, function(a, b)
            if a.unlockLevel ~= b.unlockLevel then
                return a.unlockLevel < b.unlockLevel
            end
            return a.dutyType < b.dutyType
        end)
    end
    self.m_ownerSkillCache = self.m_ownerSkillCache or UIUtils.genCellCache(self.view.ownerSkillNode)
    self.m_ownerSkillCache:Refresh(#dutyRows, function(cell, index)
        cell:InitInnOwerSkillNode({
            jsspsiDutyType = dutyRows[index].dutyType,
            onClick = nil,
        })
    end)

    
    local lockedStages = {}
    if not jsspsiCharInfo then
        lockedStages = { 1, 2, 3 }
    elseif friendship < innConst.jsspsiSecondStageFavorability then
        lockedStages = { 2, 3 }
    elseif friendship < innConst.jsspsiThidStageFavorability then
        lockedStages = { 3 }
    end

    local jsspsiName = ""
    local hasJsspsi, jsspsiCharData = Tables.characterTable:TryGetValue(jsspsiCharId)
    if hasJsspsi and jsspsiCharData then
        jsspsiName = jsspsiCharData.name
    end

    
    local stageParam = {
        [1] = innConst.jsspsiFirstStageSkillParam,
        [2] = innConst.jsspsiSecondStageSkillParam,
        [3] = innConst.jsspsiThirdStageSkillParam,
    }
    local stageBeforeParam = {
        [1] = nil,
        [2] = innConst.jsspsiFirstStageSkillParam,
        [3] = innConst.jsspsiSecondStageSkillParam,
    }
    local stageFavorability = {
        [2] = innConst.jsspsiSecondStageFavorability,
        [3] = innConst.jsspsiThidStageFavorability,
    }
    local function formatPercent(rate)
        return string.format("%.0f%%", (rate or 0) * 100)
    end

    self.m_conditionCellCache = self.m_conditionCellCache or UIUtils.genCellCache(self.view.charConditionCell)
    self.m_conditionCellCache:Refresh(#lockedStages, function(cell, index)
        local stage = lockedStages[index]
        cell.descTxt.text = Language.LUA_INN_OWNER_BUFF_DESC_ACTIVE
        if stage == 1 then
            cell.conditionTxt.text = string.format(Language.LUA_INN_OWNER_BUFF_DESC_INACTIVE, jsspsiName)
            cell.beforeTxt.text = ""
            cell.arrowNode.gameObject:SetActive(false)
        else
            local showPct = CharInfoUtils.getCharRelationShowValue(stageFavorability[stage] or 0)
            cell.conditionTxt.text = string.format(Language.LUA_INN_OWNER_CONDITION_FAVORABILITY, jsspsiName, showPct)
            cell.beforeTxt.text = formatPercent(stageBeforeParam[stage])
            cell.arrowNode.gameObject:SetActive(true)
        end
        cell.afterTxt.text = formatPercent(stageParam[stage])
        if cell.levelNumTxt then
            cell.levelNumTxt.text = string.format(Language.LUA_INN_OWNER_CONDITION_LEVEL, UIUtils.intToRoman(stage))
        end
    end)

    self.view.greenImage.gameObject:SetActive(#lockedStages == 0)
end


InnCharTipsCtrl._RefreshChef = HL.Method() << function(self)
    local charId = self.m_args.charId
    local kitchenId = self.m_args.kitchenId
    local inn = GameInstance.player and GameInstance.player.innSystem
    local curInnLevel = (inn and inn.innLevel) or 0

    
    if kitchenId == nil then
        self.view.roomName.text = Language.LUA_INN_CHAR_TIPS_NO_KITCHEN
    else
        self.view.roomName.text = Language['LUA_INN_KITCHEN_NAME_' .. kitchenId] or ""
    end

    local skills = InnUtils.getCharInnSkills(charId, true)
    local SkillType = GEnums.InnManagementSkillType

    self.m_tagCellCache = self.m_tagCellCache or UIUtils.genCellCache(self.view.tagNode)
    self.m_tagCellCache:Refresh(#skills, function(cell, index)
        local skill = skills[index]
        local unlockLevel = skill.unlockLevel or 0
        local isLocked = curInnLevel < unlockLevel
        if isLocked then
            cell.stateController:SetState("Lock")
            cell.detailsTxt.text = string.format(Language.LUA_INN_CHAR_TIPS_SKILL_LOCK, unlockLevel)
            return
        end

        local params = skill.parameters
        local param0 = (params and params.Count > 0) and Utils.getDynamicParamStringValue(params[0]) or ""
        local param1 = (params and params.Count > 1) and Utils.getDynamicParamStringValue(params[1]) or ""

        if skill.skillType == SkillType.CategorySpeedUp or skill.skillType == SkillType.RareRateBonus then
            cell.stateController:SetState("Hobby")
            local hasTag, tagData = Tables.tagDataTable:TryGetValue(param0)
            cell.hobbyTxt.text = (hasTag and tagData) and tagData.tagName or ""
            cell.innItemTagCategory:InitInnItemTag({
                tagId = param1,
                isHot = false,
                upCount = 1,
            })
        elseif skill.skillType == SkillType.AffixBonus then
            cell.stateController:SetState("Skill")
            cell.charTypeIcon:InitCharTypeIcon(param0)
            cell.innItemTagAffix:InitInnItemTag({
                tagId = param1,
                isHot = false,
                upCount = 1,
            })
        end
        cell.detailsTxt.text = skill.desc or ""
    end)
end






HL.Commit(InnCharTipsCtrl)
