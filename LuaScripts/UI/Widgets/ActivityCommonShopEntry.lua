local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityCommonShopEntry = HL.Class('ActivityCommonShopEntry', UIWidgetBase)
ActivityCommonShopEntry.m_activityId = HL.Field(HL.String) << ""


ActivityCommonShopEntry._OnFirstTimeInit = HL.Override() << function(self)
    
    self:RegisterMessage(MessageConst.ON_ACTIVITY_UPDATED, function(updateArgs)
        local id = unpack(updateArgs)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_RefreshUI()
        end
    end)
    
    self:RegisterMessage(MessageConst.ON_BUY_ITEM_SUCC, function()
        if GameInstance.player.activitySystem:GetActivity(self.m_activityId) then
            self:_RefreshUI()
        end
    end)
end

ActivityCommonShopEntry.InitActivityShopEntry = HL.Method(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId

    self:_FirstTimeInit()
    self:_InitUI()
    self:_RefreshUI()
end

ActivityCommonShopEntry._CheckLifecycleState = HL.Method().Return(HL.Boolean) << function(self)
    
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if activity and activity.status == GEnums.ActivityStatus.InProgress then
        return true
    end
    return false
end

ActivityCommonShopEntry._InitUI = HL.Method() << function(self)
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    local shopJumpId = activityJumpCfg.shopJumpId
    local _, cfg = Tables.systemJumpTable:TryGetValue(shopJumpId)
    if not cfg then
        logger.error("ActivityCommonShopEntry: shopJumpId不存在")
        return
    end
    local phaseArgs = Json.decode(cfg.phaseArgs)
    local _, shopCfg = Tables.shopTable:TryGetValue(phaseArgs.shopGroupId)

    
    self.view.button.onClick:AddListener(function()
        Utils.jumpToSystem(shopJumpId)
    end)
    
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if activityData then
        self.view.countDownWidget:InitCountDownText(activityData.endTime)
    end
    
    if shopCfg then
        self.view.shopText.text = shopCfg.name
    end
    
    self.view.redDot:InitRedDot("ActivityCommonShopEntry", self.m_activityId)
end

ActivityCommonShopEntry._RefreshUI = HL.Method() << function(self)
    local showUI = self:_CheckLifecycleState()
    self.view.gameObject:SetActive(showUI)
    if not showUI then
        return
    end
    self:_RefreshFinishState()
end

ActivityCommonShopEntry._RefreshFinishState = HL.Method() << function(self)
    if not self.view.stateController then
        return
    end
    local _, shopGroupId = Tables.activityId2ShopGroupId:TryGetValue(self.m_activityId)
    local isFinish = shopGroupId and self.view.config.CAN_SWITCH_FINISH_STATE and ActivityUtils.isShopGroupAllGoodsSoldOut(shopGroupId)
    self.view.stateController:SetState(isFinish and "Finish" or "Normal")
end

HL.Commit(ActivityCommonShopEntry)
return ActivityCommonShopEntry
