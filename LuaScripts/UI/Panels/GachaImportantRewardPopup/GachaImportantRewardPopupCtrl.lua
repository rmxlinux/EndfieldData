
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GachaImportantRewardPopup








GachaImportantRewardPopupCtrl = HL.Class('GachaImportantRewardPopupCtrl', uiCtrl.UICtrl)







GachaImportantRewardPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



GachaImportantRewardPopupCtrl.m_info = HL.Field(HL.Table)














GachaImportantRewardPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self.m_info = arg
    self:_RefreshAllUI()
end



GachaImportantRewardPopupCtrl.OnClose = HL.Override() << function(self)
    local onComplete = self.m_info.onComplete
    self.m_info = nil
    if onComplete then
        onComplete()
    end
end





GachaImportantRewardPopupCtrl._InitUI = HL.Method() << function(self)
    self.view.maskBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



GachaImportantRewardPopupCtrl._RefreshAllUI = HL.Method() << function(self)
    local itemId = self.m_info.itemId
    self.view.itemIcon:InitItemIcon(itemId, true)
    local itemData = Tables.itemTable[itemId]
    self.view.itemNameTxt.text = itemData.name
    self.view.descTxt:SetAndResolveTextStyle(Language.LUA_GACHA_GOT_TESTIMONIAL_IMPORTANT_DESC)

    self.view.tipsBtn.onClick:RemoveAllListeners()
    self.view.tipsBtn.onClick:AddListener(function()
        Notify(MessageConst.SHOW_ITEM_TIPS, {
            transform = self.view.tipsBtn.transform,
            itemId = itemId,
        })
    end)
end





HL.Commit(GachaImportantRewardPopupCtrl)
