local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')







CharSkillNodeNew = HL.Class('CharSkillNodeNew', UIWidgetBase)


CharSkillNodeNew.m_skillCells = HL.Field(HL.Forward("UIListCache"))


CharSkillNodeNew.m_lastSelectIndex = HL.Field(HL.Number) << -1



CharSkillNodeNew._OnFirstTimeInit = HL.Override() << function(self)
    self.m_skillCells = UIUtils.genCellCache(self.view.skillCell)
    self.m_lastSelectIndex = -1
    
end












CharSkillNodeNew.InitCharSkillNodeNew = HL.Method(HL.Table) << function(self, arg)
    self:_FirstTimeInit()

    local charInstId = arg.charInstId
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    self.m_skillCells:Refresh(#UIConst.CHAR_INFO_SKILL_SHOW_ORDER, function(cell, luaIndex)
        local skillGroupType = UIConst.CHAR_INFO_SKILL_SHOW_ORDER[luaIndex]
        cell:InitCharInfoSkillButtonNew(charInst, skillGroupType, function()
            Notify(MessageConst.SHOW_CHAR_SKILL_TIP, {
                skillGroupType = skillGroupType,
                charInstId = charInstId,
                transform = arg.tipsNode or cell.view.showTipTransform,
                isSingleChar = arg.isSingleChar,
                hideBtnUpgrade = arg.hideBtnUpgrade,
                tipPosType = arg.tipPosType,

                
                cell = cell,
                enableCloseActionOnController = arg.enableCloseActionOnController,
            })
        end)
    end)
end




CharSkillNodeNew.RefreshSkillSelect = HL.Method(HL.Opt(HL.Number)) << function(self, selectIndex)
    local count = self.m_skillCells:GetCount()
    for i = 1, count do
        local cell = self.m_skillCells:GetItem(i)
        cell:SetSelect(selectIndex == i)
    end
end

HL.Commit(CharSkillNodeNew)
return CharSkillNodeNew

