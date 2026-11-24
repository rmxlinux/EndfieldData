local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailActivityCardGame

MapMarkDetailActivityCardGameCtrl = HL.Class('MapMarkDetailActivityCardGameCtrl', uiCtrl.UICtrl)







MapMarkDetailActivityCardGameCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


MapMarkDetailActivityCardGameCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local commonArgs = {}
    commonArgs.bigBtnActive = true
    commonArgs.markInstId = arg.markInstId
    self.view.detailCommon:InitMapMarkDetailCommon(commonArgs)
end

HL.Commit(MapMarkDetailActivityCardGameCtrl)
