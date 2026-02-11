local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonIntro










CommonIntroCtrl = HL.Class('CommonIntroCtrl', uiCtrl.UICtrl)






CommonIntroCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CommonIntroCtrl.m_pageIndex = HL.Field(HL.Number) << -1


CommonIntroCtrl.m_pageInfos = HL.Field(HL.Userdata)





CommonIntroCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnBack.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end




CommonIntroCtrl._ShowIntro = HL.Method(HL.String) << function(self, args)
    self.m_pageInfos = Tables.introTable:GetValue(args).dataArray

    self.view.pageController:InitPageController(#self.m_pageInfos, function(pageIndex)
        self:_OnMovePage(pageIndex)
    end)
end




CommonIntroCtrl._OnMovePage = HL.Method(HL.Number) << function(self, pageIndex)
    self.m_pageIndex = pageIndex

    local pageInfo = self.m_pageInfos[CSIndex(pageIndex)]
    self.view.panel:LoadSprite(pageInfo.imagePath)
    self.view.titleTxt1:SetAndResolveTextStyle(pageInfo.title)
    self.view.titleTxt2:SetAndResolveTextStyle(pageInfo.desc)

    self:PlayAnimation("racingdungeonentrypop_switch")
end



CommonIntroCtrl.ShowIntro = HL.StaticMethod(HL.String) << function(args)
    local valid = CommonIntroCtrl._CheckArgs(args)
    if not valid then
        logger.error("[CommonIntro] ShowIntro: Invalid args: " .. tostring(args))
        return
    end

    
    local ctrl = CommonIntroCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:_ShowIntro(args)
end



CommonIntroCtrl._CheckArgs = HL.StaticMethod(HL.String).Return(HL.Boolean) << function(args)
    local valid = Tables.introTable:ContainsKey(args)
    return valid
end

HL.Commit(CommonIntroCtrl)
