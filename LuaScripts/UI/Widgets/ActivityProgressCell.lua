local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityProgressCell = HL.Class('ActivityProgressCell', UIWidgetBase)


ActivityProgressCell._OnFirstTimeInit = HL.Override() << function(self)
    
end

ActivityProgressCell.InitActivityProgressCell = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isLeftActive, isRightActive)
    self:_FirstTimeInit()

    self.view.stateController:SetState(isLeftActive and "LeftActive" or "LeftLock")
    if isRightActive == nil then
        self.view.stateController:SetState("HideRight")
        return
    end
    self.view.stateController:SetState("ShowRight")
    self.view.stateController:SetState(isRightActive and "RightActive" or "RightLock")
end

HL.Commit(ActivityProgressCell)
return ActivityProgressCell

