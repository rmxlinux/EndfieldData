
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.EquipEnhanceResult





EquipEnhanceResultCtrl = HL.Class('EquipEnhanceResultCtrl', uiCtrl.UICtrl)







EquipEnhanceResultCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}












EquipEnhanceResultCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    local args = arg

    self:_InitController()

    self.view.btnClose.onClick:AddListener(function()
        self:Close()
        if args.closeCallback then
            args.closeCallback()
        end
    end)


    self.view.stateCtrl:SetState(args.isSuccessful and "success" or "fail")
    AudioAdapter.PostEvent(args.isSuccessful and "Au_UI_Popup_EquipForgSuccess_Open" or "Au_UI_Popup_EquipForgFail_Open")
    self.view.equipItem:InitEquipItem({
        equipInstId = args.equipInstId,
    })

    local equipInstData = EquipTechUtils.getEquipInstData(args.equipInstId)
    local itemData = Tables.itemTable[equipInstData.templateId]
    self.view.txtEquipName.text = itemData.name

    self.view.equipEnhanceLevelNode:InitEquipEnhanceLevelNode({
        equipInstId = args.equipInstId,
        attrIndex = args.attrShowInfo.enhancedAttrIndex,
    })
    self.view.txtAttrName.text = args.attrShowInfo.showName
    self.view.txtAttrValueBefore.text = EquipTechUtils.getAttrShowValueText(args.attrShowInfo)
    if args.isSuccessful then
        self.view.txtAttrValueAfter.text = args.nextLevelAttrShowValue
    end
    self:_StartTimer(self.view.config.REWARD_AUDIO_DELAY_TIME, function()
        AudioAdapter.PostEvent("Au_UI_Popup_RewardsItem_Open")
    end)
end



EquipEnhanceResultCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end



HL.Commit(EquipEnhanceResultCtrl)
