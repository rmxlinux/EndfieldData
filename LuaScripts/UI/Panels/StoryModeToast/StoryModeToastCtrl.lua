
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.StoryModeToast






StoryModeToastCtrl = HL.Class('StoryModeToastCtrl', uiCtrl.UICtrl)







StoryModeToastCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



StoryModeToastCtrl.OnGameModeEnable = HL.StaticMethod(HL.Table) << function(args)
    local modeType = unpack(args)
    if modeType == GEnums.GameModeType.Story then
        UIManager:Close(PANEL_ID)
        UIManager:AutoOpen(PANEL_ID, true)
    end
end



StoryModeToastCtrl.OnGameModeDisable = HL.StaticMethod(HL.Table) << function(args)
    local modeType, mode = unpack(args)
    if modeType == GEnums.GameModeType.Story then
        UIManager:Close(PANEL_ID)
        if mode.showLeaveToast then
            UIManager:AutoOpen(PANEL_ID, false)
        end
    end
end





StoryModeToastCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.txtToast.text = arg and
        Language.LUA_ENTER_STORY_MODE_TOAST or Language.LUA_EXIT_STORY_MODE_TOAST
    self:_StartTimer(self.view.config.SHOW_DURATION, function()
        self:PlayAnimationOutAndClose()
    end)
end

HL.Commit(StoryModeToastCtrl)