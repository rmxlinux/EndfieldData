local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnOwerSkillNode = HL.Class('InnOwerSkillNode', UIWidgetBase)

InnOwerSkillNode.m_args = HL.Field(HL.Table)


local DUTY_TEXT_MAP = {
    [GEnums.JsspsiDutyType.ServeDish] = {
        name = "LUA_INN_OWNER_SKILL_NAME_SERVE_DISH",
        desc = "LUA_INN_OWNER_SKILL_DESC_SERVE_DISH",
    },
    [GEnums.JsspsiDutyType.ServeDrink] = {
        name = "LUA_INN_OWNER_SKILL_NAME_SERVE_DRINK",
        desc = "LUA_INN_OWNER_SKILL_DESC_SERVE_DRINK",
    },
    [GEnums.JsspsiDutyType.Checkout] = {
        name = "LUA_INN_OWNER_SKILL_NAME_CHECKOUT",
        desc = "LUA_INN_OWNER_SKILL_DESC_CHECKOUT",
    },
}


InnOwerSkillNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.button.onClick:AddListener(function()
        if self.m_args and self.m_args.onClick then
            self.m_args.onClick()
        end
    end)
end





InnOwerSkillNode.InitInnOwerSkillNode = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.m_args = args
    local dutyType = args.jsspsiDutyType

    local iconId = InnConst.INN_AUTO_DUTY_ICON_ID[dutyType]
    if iconId then
        self.view.iconImg:LoadSprite(UIConst.UI_SPRITE_INN_AUTO, iconId)
    end

    
    local textKeys = DUTY_TEXT_MAP[dutyType]
    if textKeys then
        self.view.nameTxt.text = Language[textKeys.name]
        self.view.descTxt.text = Language[textKeys.desc]
    else
        self.view.nameTxt.text = ""
        self.view.descTxt.text = ""
    end

    local inn = GameInstance.player and GameInstance.player.innSystem
    local isUnlock = false
    if inn and inn.jsspsiDutyUnlockInnLevel then
        local has, unlockLevel = inn.jsspsiDutyUnlockInnLevel:TryGetValue(dutyType)
        if has then
            if (inn.innLevel or 0) >= unlockLevel then
                isUnlock = true
            else
                self.view.descTxt.text = string.format(Language.LUA_INN_CHAR_TIPS_SKILL_LOCK, unlockLevel)
            end
        end
    end
    self.view.stateController:SetState(isUnlock and "Unlock" or "Lock")
end


InnOwerSkillNode.SetSelected = HL.Method(HL.Boolean) << function(self, selected)
    if selected then
        self.view.stateController:SetState("Active")
        self.view.stateController:SetState("Select")
    else
        self.view.stateController:SetState("Unlock")
        self.view.stateController:SetState("Unselect")
    end
end

HL.Commit(InnOwerSkillNode)
return InnOwerSkillNode
