
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BlockGlitchTransition









BlockGlitchTransitionCtrl = HL.Class('BlockGlitchTransitionCtrl', uiCtrl.UICtrl)






BlockGlitchTransitionCtrl.s_messages = HL.StaticField(HL.Table) << {
}



BlockGlitchTransitionCtrl.s_renderTexture = HL.StaticField(HL.Userdata)



BlockGlitchTransitionCtrl.PrepareBlockGlitchTransition = HL.StaticMethod() << function()
    BlockGlitchTransitionCtrl._ReleaseRT()
    BlockGlitchTransitionCtrl.s_renderTexture = ScreenCaptureUtils.GetScreenCapture(math.floor(Screen.width), math.floor(Screen.height))
end


BlockGlitchTransitionCtrl._ReleaseRT = HL.StaticMethod() << function()
    if BlockGlitchTransitionCtrl.s_renderTexture then
        RTManager.ReleaseRenderTexture(BlockGlitchTransitionCtrl.s_renderTexture)
        BlockGlitchTransitionCtrl.s_renderTexture = nil
    end
end


BlockGlitchTransitionCtrl.ShowBlockGlitchTransition = HL.StaticMethod() << function()
    if not BlockGlitchTransitionCtrl.s_renderTexture then
        logger.error("No BlockGlitchTransitionCtrl.s_renderTexture")
        return
    end

    local ctrl = BlockGlitchTransitionCtrl.AutoOpen(PANEL_ID)
    AudioAdapter.PostEvent("Au_UI_Event_SquareMosaic_Glitch")

    ctrl:Play()
end





BlockGlitchTransitionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
end



BlockGlitchTransitionCtrl.OnShow = HL.Override() << function(self)
    UIUtils.changeAlpha(self.view.rawImage, 0)
end



BlockGlitchTransitionCtrl.Play = HL.Method() << function(self)
    self.view.rawImage.texture = BlockGlitchTransitionCtrl.s_renderTexture
    UIUtils.changeAlpha(self.view.rawImage, 1)
    local wrapper = self.animationWrapper
    wrapper:PlayWithTween(self.view.config.ANIMATION_IN, function()
        self:Hide()
        BlockGlitchTransitionCtrl._ReleaseRT()
    end)
end

HL.Commit(BlockGlitchTransitionCtrl)
