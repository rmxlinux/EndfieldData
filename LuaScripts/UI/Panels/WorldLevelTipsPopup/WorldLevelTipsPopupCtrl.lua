
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WorldLevelTipsPopup




WorldLevelTipsPopupCtrl = HL.Class('WorldLevelTipsPopupCtrl', uiCtrl.UICtrl)







WorldLevelTipsPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





WorldLevelTipsPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local isTipsMode = arg and arg.isTipsMode
    self.view.closeBtn.onClick:RemoveAllListeners()
    self.view.closeBtn.onClick:AddListener(function()
        if isTipsMode then
            self:PlayAnimationOutAndClose()
        else
            self:PlayAnimationOutAndClose()
        end
    end)

    self.view.bg.onClick:RemoveAllListeners()
    self.view.bg.onClick:AddListener(function()
        if isTipsMode then
            self:PlayAnimationOutAndClose()
        else
            self:PlayAnimationOutAndClose()
        end
    end)

    self.view.confirmBtn.onClick:RemoveAllListeners()
    self.view.confirmBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        UIManager:Open(PanelId.WorldLevelPopup, { isUp = not GameInstance.player.adventure.isCurWorldLvMax })
    end)
    self.view.confirmBtn.gameObject:SetActive(not isTipsMode)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end











HL.Commit(WorldLevelTipsPopupCtrl)
