local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
HeadLabelCtrl = HL.Class('HeadLabelCtrl', uiCtrl.UICtrl)

HeadLabelCtrl.s_messages = HL.StaticField(HL.Table) << {}


HeadLabelCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_CreateWorldObjectRoot(false )
    self.view.csHeadLabelCtrl:OnCreate(self.m_worldRoot)
end

HeadLabelCtrl.OnClose = HL.Override() << function(self)
    self.view.csHeadLabelCtrl:OnClose()
end

HeadLabelCtrl.OnHide = HL.Override() << function(self)
    self.view.csHeadLabelCtrl:OnHide()
    self.view.csHeadLabelCtrl.enabled = false
    
    self.m_worldRoot.transform.position = Vector3(10000, 10000, 10000)
end

HeadLabelCtrl.OnShow = HL.Override() << function(self)
    self.view.csHeadLabelCtrl:OnShow()
    self.m_worldRoot.transform.position = Vector3.zero
    self.view.csHeadLabelCtrl.enabled = true
end

HL.Commit(HeadLabelCtrl)
