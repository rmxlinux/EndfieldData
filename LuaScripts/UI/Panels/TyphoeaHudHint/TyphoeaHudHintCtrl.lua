local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaHudHint

TyphoeaHudHintCtrl = HL.Class('TyphoeaHudHintCtrl', uiCtrl.UICtrl)






TyphoeaHudHintCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


TyphoeaHudHintCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.view.hudCtrl:OnCreate()
end

TyphoeaHudHintCtrl.InitHint = HL.Method(HL.Table) << function(self, arg)
    
    
end

TyphoeaHudHintCtrl.OnShow = HL.Override() << function(self)
    
    self.view.hudCtrl:OnShow()
end
TyphoeaHudHintCtrl.OnHide = HL.Override() << function(self)
    
    self.view.hudCtrl:OnHide()
end

TyphoeaHudHintCtrl.OnClose = HL.Override() << function(self)
    self.view.hudCtrl:OnClose()
end

TyphoeaHudHintCtrl.OnMarkTargetActiveChanged = HL.StaticMethod(HL.Table) << function(args)
    local isOpen = unpack(args)
    local curOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        if not curOpen then
            ctrl = UIManager:Open(PANEL_ID)
        end
        ctrl:Show()
    else
        
    end
end

HL.Commit(TyphoeaHudHintCtrl)
