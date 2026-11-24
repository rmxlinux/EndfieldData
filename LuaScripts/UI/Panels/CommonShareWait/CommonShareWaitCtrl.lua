local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

CommonShareWaitCtrl = HL.Class('CommonShareWaitCtrl', uiCtrl.UICtrl)

CommonShareWaitCtrl.s_messages = HL.StaticField(HL.Table) << {}

CommonShareWaitCtrl.m_maskKey = HL.Field(HL.Number) << -1


CommonShareWaitCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:UpdateProgress(arg.progress, arg.title, arg.info)
    self.m_maskKey = CS.Beyond.Network.NetworkMask.instance:AddMask("CommonShareWait", math.huge, math.huge)
end


CommonShareWaitCtrl.UpdateProgress = HL.Method(HL.Number, HL.String, HL.String) << function(self, progress, title, info)
    self.view.progressBar.value = progress
    self.view.titleText.text = title
    self.view.infoText.text = info
    self.view.infoText.gameObject:SetActiveIfNecessary(info ~= "")
end


CommonShareWaitCtrl.OnClose = HL.Override() << function(self)
    CS.Beyond.Network.NetworkMask.instance:RemoveMask(self.m_maskKey)
end

HL.Commit(CommonShareWaitCtrl)
