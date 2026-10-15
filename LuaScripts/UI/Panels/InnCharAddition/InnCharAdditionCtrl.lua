local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnCharAddition
local PHASE_ID = PhaseId.InnCharAddition

local SkillType = GEnums.InnManagementSkillType

InnCharAdditionCtrl = HL.Class('InnCharAdditionCtrl', uiCtrl.UICtrl)

InnCharAdditionCtrl.s_messages = HL.StaticField(HL.Table) << {
}

InnCharAdditionCtrl.m_innSystem = HL.Field(CS.Beyond.Gameplay.InnSystem)
InnCharAdditionCtrl.m_groupCache = HL.Field(HL.Forward("UIListCache"))
InnCharAdditionCtrl.m_groupData = HL.Field(HL.Table)

InnCharAdditionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_innSystem = GameInstance.player.innSystem

    self.view.btnClose.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.m_groupCache = UIUtils.genCellCache(self.view.skillGroupCell)

    self:_BuildGroupData()
    self:_Refresh()
end

InnCharAdditionCtrl._BuildGroupData = HL.Method() << function(self)
    local curInnLevel = self.m_innSystem.innLevel or 0

    local hobbySkills = {}
    local charTypeSkills = {}

    for _, skill in pairs(Tables.innSkillTable) do
        if skill.skillType == SkillType.CategorySpeedUp or skill.skillType == SkillType.RareRateBonus then
            hobbySkills[#hobbySkills + 1] = skill
        elseif skill.skillType == SkillType.AffixBonus then
            charTypeSkills[#charTypeSkills + 1] = skill
        end
    end

    local function sortSkills(a, b)
        if a.sortId ~= b.sortId then
            return a.sortId < b.sortId
        end
        return a.id < b.id
    end
    table.sort(hobbySkills, sortSkills)
    table.sort(charTypeSkills, sortSkills)

    local charTypeUnlockLevel = math.maxinteger
    for _, skill in ipairs(charTypeSkills) do
        local lvl = skill.unlockLevel or 0
        if lvl < charTypeUnlockLevel then
            charTypeUnlockLevel = lvl
        end
    end

    self.m_groupData = {
        {
            titleState = "HobbyState",
            groupType = "hobby",
            skills = hobbySkills,
            isLocked = false,
            unlockLevel = 0,
        },
        {
            titleState = "CharTypeState",
            groupType = "charType",
            skills = charTypeSkills,
            isLocked = curInnLevel < charTypeUnlockLevel,
            unlockLevel = charTypeUnlockLevel,
        },
    }
end

InnCharAdditionCtrl._Refresh = HL.Method() << function(self)
    self.m_groupCache:Refresh(#self.m_groupData, function(groupCell, groupIndex)
        local group = self.m_groupData[groupIndex]
        groupCell.titleNode:SetState(group.titleState)

        local cellCache = groupCell._innerCache
        if not cellCache then
            cellCache = UIUtils.genCellCache(groupCell.additionDetailsCell)
            groupCell._innerCache = cellCache
        end

        if group.isLocked then
            cellCache:Refresh(1, function(cell)
                cell.stateController:SetState("LockState")
                cell.lockTxt.text = string.format(Language.LUA_INN_CHAR_TIPS_SKILL_LOCK, group.unlockLevel)
            end)
        else
            cellCache:Refresh(#group.skills, function(cell, index)
                self:_RefreshSkillCell(cell, group.skills[index], group.groupType)
            end)
        end
    end)
end

InnCharAdditionCtrl._RefreshSkillCell = HL.Method(HL.Any, HL.Any, HL.String) << function(self, cell, skill, groupType)
    cell.stateController:SetState("NormalState")

    local params = skill.parameters
    local param0 = (params and params.Count > 0) and Utils.getDynamicParamStringValue(params[0]) or ""
    local param1 = (params and params.Count > 1) and Utils.getDynamicParamStringValue(params[1]) or ""

    if groupType == "hobby" then
        local hasTag, tagData = Tables.tagDataTable:TryGetValue(param0)
        cell.hobbyTagCell.nameTxt.text = tagData.tagName
        cell.charTypeIcon.view.gameObject:SetActive(false)
    else
        cell.charTypeIcon.view.gameObject:SetActive(true)
        cell.charTypeIcon:InitCharTypeIcon(param0)
        local _, charTypeData = Tables.charTypeTable:TryGetValue(param0)
        if charTypeData then
            cell.charTypeTxt.text = charTypeData.name
        end
        cell.hobbyTagCell.gameObject:SetActive(false)
    end

    cell.innItemTag:InitInnItemTag({
        tagId = param1,
        isHot = false,
        upCount = 1,
    })
    cell.detailsTxt.text = string.format(Language.LUA_INN_CHAR_ADDITION_SKILL_DESC, skill.name, skill.desc)
end

HL.Commit(InnCharAdditionCtrl)
