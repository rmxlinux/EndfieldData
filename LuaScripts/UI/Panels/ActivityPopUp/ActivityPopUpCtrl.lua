

local commonPopUpCtrl = require_ex('UI/Panels/CommonPopUp/CommonPopUpCtrl')
local PANEL_ID = PanelId.ActivityPopUp

ActivityPopUpCtrl = HL.Class('ActivityPopUpCtrl', commonPopUpCtrl.CommonPopUpCtrl)

ActivityPopUpCtrl._ShowActivityPopUp = HL.Method(HL.Table) << function(self, args)
    local onConfirm = args.onConfirm
    if onConfirm then
        
        args.closeOnConfirm = false
        args.onConfirm = function(...)
            self.view.fullScreenMask.gameObject:SetActive(true)
            self.view.fullScreenMask.enabled = true
            onConfirm(...)
            local isOpen, currentCtrl = UIManager:IsOpen(PANEL_ID)
            if isOpen and currentCtrl == self and self.m_args == args then
                self:_HidePopUp()
            end
        end
    end
    self:_ShowPopUp(args)
end

ActivityPopUpCtrl.ShowActivityPopUp = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = ActivityPopUpCtrl.AutoOpen(PANEL_ID, nil, false)
    UIManager:SetTopOrder(PANEL_ID)
    ctrl:_ShowActivityPopUp(args)
end

ActivityPopUpCtrl.ShowActivityPopUpCS = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = ActivityPopUpCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:_ShowActivityPopUp({
        content = args[1],
        subContent = args[2],
        onConfirm = args[3],
        onCancel = args[4]
    })
end

HL.Commit(ActivityPopUpCtrl)
