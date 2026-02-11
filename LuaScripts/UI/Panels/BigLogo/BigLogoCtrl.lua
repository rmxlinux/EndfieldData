
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BigLogo








BigLogoCtrl = HL.Class('BigLogoCtrl', uiCtrl.UICtrl)







BigLogoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SHOW_BIG_LOGO] = '_OnShowBigLogo',
    [MessageConst.ON_LOAD_NEW_CUTSCENE] = '_OnLoadNewCutscene',
    [MessageConst.ON_LOAD_NEW_DLG_TIMELINE] = '_OnLoadNewDialogTimeline',
}


BigLogoCtrl.m_timelineHandle = HL.Field(HL.Userdata)






BigLogoCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_timelineHandle = unpack(args)
end







BigLogoCtrl._OnShowBigLogo = HL.Method(HL.Table) << function(self, args)
    local sprite, useStretchImage, showOnTop, hideBackground, useOriginalImage = unpack(args)

    self.view.bg.gameObject:SetActive(not hideBackground)

    if useOriginalImage then
        self.view.originImageNode.sprite = sprite
    elseif useStretchImage then
        if showOnTop then
            self.view.stretchImageTop.sprite = sprite
        else
            self.view.stretchImageBottom.sprite = sprite
        end
    else
        self.view.nameImg.sprite = sprite
    end

end




BigLogoCtrl._OnLoadNewCutscene = HL.Method(HL.Any) << function(self, args)
    self.view.bigLogoMain.gameObject:SetActive(false)
    self.view.stretchImageMain.gameObject:SetActive(false)

    local cinematicMgr = GameWorld.cutsceneManager
    cinematicMgr:BindBigLogo(self.m_timelineHandle, self.view.bigLogoPanel)
end




BigLogoCtrl._OnLoadNewDialogTimeline = HL.Method(HL.Any) << function(self, args)
    self.view.bigLogoMain.gameObject:SetActive(false)
    self.view.stretchImageMain.gameObject:SetActive(false)

    local dialogTimelineManager = GameWorld.dialogTimelineManager
    dialogTimelineManager:BindBigLogo(self.m_timelineHandle, self.view.bigLogoPanel)
end



HL.Commit(BigLogoCtrl)