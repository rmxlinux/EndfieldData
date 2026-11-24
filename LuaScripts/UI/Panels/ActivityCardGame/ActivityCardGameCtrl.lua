
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ActivityCardGame

ActivityCardGameCtrl = HL.Class('ActivityCardGameCtrl', uiCtrl.UICtrl)

ActivityCardGameCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_ALL_GAMES_CLOSED] = '_OnAllGamesClosed',
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnActivityUpdated',
}


ActivityCardGameCtrl.m_activityId = HL.Field(HL.String) << ''
ActivityCardGameCtrl.m_hasNewGame = HL.Field(HL.Boolean) << false

ActivityCardGameCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_activityId = args.activityId
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
    local gotoNode = self.view.activityCommonInfo.view.gotoNode
    gotoNode.btnDetailRedDot:InitRedDot("MultiplayerNewGameEntry", nil, function(_, active)
        
        self.m_hasNewGame = active
        self:_RefreshRenewTips()
    end)
    MultiplayerUtils.initAchievementMedals(self.view)
    local _, activityJumpCfg = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    
    local hasTaskJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.taskJumpId)
    if self.view.activityTaskEntry then
        if hasTaskJump then
            self.view.activityTaskEntry:InitActivityTaskEntry({activityId = self.m_activityId})
        else
            self.view.activityTaskEntry.gameObject:SetActive(false)
        end
    end
    
    local hasShopJump = activityJumpCfg and not string.isEmpty(activityJumpCfg.shopJumpId)
    if self.view.activityShopEntry then
        if hasShopJump then
            self.view.activityShopEntry:InitActivityShopEntry({activityId = self.m_activityId})
        else
            self.view.activityShopEntry.gameObject:SetActive(false)
        end
    end
end


ActivityCardGameCtrl._RefreshRenewTips = HL.Method() << function(self)
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    self.view.activityCommonInfo.view.gotoNode.renewTips.gameObject:SetActive(self.m_hasNewGame and activity ~= nil and activity.isUnlocked)
end

ActivityCardGameCtrl._OnActivityUpdated = HL.Method(HL.Any) << function(self, args)
    local activityId = unpack(args)
    if activityId == self.m_activityId then
        self:_RefreshRenewTips()
    end
end

ActivityCardGameCtrl.OnShow = HL.Override() << function(self)
    MultiplayerUtils.checkAllGamesClosed()
end

ActivityCardGameCtrl._OnAllGamesClosed = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    MultiplayerUtils.checkAllGamesClosed()
end

HL.Commit(ActivityCardGameCtrl)
