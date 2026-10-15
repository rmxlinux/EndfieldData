local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleDrawToast

GambleBattleDrawToastCtrl = HL.Class('GambleBattleDrawToastCtrl', uiCtrl.UICtrl)







GambleBattleDrawToastCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


GambleBattleDrawToastCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_StartTimer(2, function()      
        self:PlayAnimationOutAndClose()
    end)
end

HL.Commit(GambleBattleDrawToastCtrl)
