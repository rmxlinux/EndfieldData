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
    local cfg = Tables.systemJumpTable[shopJumpId]
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
        self.shopText.text = shopCfg.name
    end
    
    self.view.redDot:InitRedDot("ActivityCommonShopEntry", self.m_activityId)
end

ActivityCommonShopEntry._RefreshUI = HL.Method() << function(self)
    local showUI = self:_CheckLifecycleState()
    self.view.gameObject:SetActive(showUI)
end

HL.Commit(ActivityCommonShopEntry)
return ActivityCommonShopEntry

