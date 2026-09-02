
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SocializeVisitTips

SocializeVisitTipsCtrl = HL.Class('SocializeVisitTipsCtrl', uiCtrl.UICtrl)

SocializeVisitTipsCtrl.m_isInit = HL.Field(HL.Boolean) << false
SocializeVisitTipsCtrl.m_waitingPlayAnimationAfterLoading = HL.Field(HL.Boolean) << false





SocializeVisitTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SPACESHIP_VISIT_FRIEND] = '_OnSpaceshipVisitFriend',
    [MessageConst.ON_IN_MAIN_HUD_CHANGED] = '_OnInMainHudChanged',
}


SocializeVisitTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.m_isInit = InputManagerInst.inChangingInputDevice
end

SocializeVisitTipsCtrl.OnCellChange = HL.Method() << function(self)
    local friendInfo = GameInstance.player.spaceship:GetFriendRoleInfo()
    if friendInfo and friendInfo.roleId ~= 0 then
        self.view.socializeFriendName:InitSocializeFriendName(friendInfo.roleId)
    end
end

SocializeVisitTipsCtrl._OnSpaceshipVisitFriend = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local isSelf = false
    if arg then
        isSelf = unpack(arg)
    end
    if isSelf then
        return
    end
    
    self.m_isInit = false
    self.m_waitingPlayAnimationAfterLoading = true
    self:OnCellChange()
end

SocializeVisitTipsCtrl._OnInMainHudChanged = HL.Method(HL.Any) << function(self, arg)
    local inMainHud = unpack(arg)
    if not self.m_waitingPlayAnimationAfterLoading or not inMainHud then
        return
    end
    self:_PlayVisitTipsAnimation()
end

SocializeVisitTipsCtrl._PlayVisitTipsAnimation = HL.Method() << function(self)
    self.view.animationWrapper:ClearTween()
    if self.m_isInit and not self.m_waitingPlayAnimationAfterLoading then
        self.view.animationWrapper:PlayWithTween("socializevisittips_in_part_2")
        AudioManager.PostEvent("Au_UI_Toast_FriendVisitSide_Open")
    else
        self.view.animationWrapper:PlayWithTween("socializevisittips_in_part_1", function()
            self.m_isInit = true
        end)
        AudioManager.PostEvent("Au_UI_Toast_FriendVisitMain_Open")
    end
    self.m_waitingPlayAnimationAfterLoading = false
end

SocializeVisitTipsCtrl.OnShow = HL.Override() << function(self)
    self:OnCellChange()
    if UIManager:IsShow(PanelId.Loading) then
        self.m_waitingPlayAnimationAfterLoading = true
        return
    end
    self:_PlayVisitTipsAnimation()
end
HL.Commit(SocializeVisitTipsCtrl)
