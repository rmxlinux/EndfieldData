local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnOwnerBuffNode = HL.Class('InnOwnerBuffNode', UIWidgetBase)


InnOwnerBuffNode._OnFirstTimeInit = HL.Override() << function(self)
    
end


InnOwnerBuffNode.InitInnOwnerBuffNode = HL.Method(HL.Opt(HL.Boolean)) << function(self, mergeDesc)
    self:_FirstTimeInit()

    local innConst = Tables.innManagementConst
    local jsspsiCharId = innConst.jsspsiCharId
    local jsspsiCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(jsspsiCharId, GEnums.CharType.Default)

    self.view.qualityNumTxt.gameObject:SetActiveIfNecessary(not mergeDesc)

    if jsspsiCharInfo then
        
        self.view.stateController:SetState("Unlock")

        local friendship = CSPlayerDataUtil.GetCharFriendship(jsspsiCharId)
        local stage, rate
        if friendship >= innConst.jsspsiThidStageFavorability then
            stage = 3
            rate = innConst.jsspsiThirdStageSkillParam
        elseif friendship >= innConst.jsspsiSecondStageFavorability then
            stage = 2
            rate = innConst.jsspsiSecondStageSkillParam
        else
            stage = 1
            rate = innConst.jsspsiFirstStageSkillParam
        end

        local numTxt = string.format("%.0f%%", (rate or 0) * 100)
        self.view.qualityLvTxt.text = UIUtils.intToRoman(stage)
        if mergeDesc then
            self.view.qualityDescTxt.text = Language.LUA_INN_OWNER_BUFF_DESC_ACTIVE .. " " .. numTxt
            self.view.qualityNumTxt.text = ""
        else
            self.view.qualityDescTxt.text = Language.LUA_INN_OWNER_BUFF_DESC_ACTIVE
            self.view.qualityNumTxt.text = numTxt
        end
    else
        
        self.view.stateController:SetState("Lock")

        local charName = ""
        local hasChar, charData = Tables.characterTable:TryGetValue(jsspsiCharId)
        if hasChar and charData then
            charName = charData.name
        end
        self.view.qualityDescTxt.text = string.format(Language.LUA_INN_OWNER_BUFF_DESC_INACTIVE, charName)
        self.view.qualityNumTxt.text = ""
    end
end

HL.Commit(InnOwnerBuffNode)
return InnOwnerBuffNode
