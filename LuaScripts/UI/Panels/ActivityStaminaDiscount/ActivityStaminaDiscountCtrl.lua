local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityStaminaDiscount






ActivityStaminaDiscountCtrl = HL.Class('ActivityStaminaDiscountCtrl', uiCtrl.UICtrl)







ActivityStaminaDiscountCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_NEW_DAY] = 'Refresh',
}


ActivityStaminaDiscountCtrl.m_activityId = HL.Field(HL.String) << ''





ActivityStaminaDiscountCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    
    ActivityUtils.setFalseNewActivityDay(self.m_activityId)

    
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    self:Refresh()

    
    self.view.activityCommonInfo.view.gotoNode.btnDetailRedDot:InitRedDot("ActivityGlobalEffect", self.m_activityId)
end



ActivityStaminaDiscountCtrl.Refresh = HL.Method() << function(self)
    local useCount = GameInstance.player.activitySystem.staminaReduceUsedCount
    local totalCount = GameInstance.player.activitySystem.staminaTotalCount
    local staminaDiscount = GameInstance.player.activitySystem.staminaDiscount
    self.view.detailsYellowTxt.text = string.format(Language.LUA_ACTIVITY_STAMINA_DISCOUNT_YELLOW_HINT, totalCount, staminaDiscount)
    if totalCount - useCount == 0 then
        self.view.surplusStaminaLayoutState:SetState("UseUp")
    else
        self.view.surplusStaminaLayoutState:SetState("Normal")
        self.view.staminaNumberTxt.text = string.format(" %d/%d",totalCount - useCount,totalCount)
    end
end
HL.Commit(ActivityStaminaDiscountCtrl)
