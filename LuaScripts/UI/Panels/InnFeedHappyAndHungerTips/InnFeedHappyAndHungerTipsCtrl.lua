local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnFeedHappyAndHungerTips
local ranchSystem = GameInstance.player.ranchSystem

InnFeedHappyAndHungerTipsCtrl = HL.Class('InnFeedHappyAndHungerTipsCtrl', uiCtrl.UICtrl)


local TIPS_TICK_INTERVAL = 1







InnFeedHappyAndHungerTipsCtrl.s_messages = HL.StaticField(HL.Table) << {

}

InnFeedHappyAndHungerTipsCtrl.m_targetTransform = HL.Field(HL.Userdata)
InnFeedHappyAndHungerTipsCtrl.m_fullnessExhaustedTs = HL.Field(HL.Number) << 0
InnFeedHappyAndHungerTipsCtrl.m_happinessExhaustedTs = HL.Field(HL.Number) << 0
InnFeedHappyAndHungerTipsCtrl.m_coroutine = HL.Field(HL.Thread)









InnFeedHappyAndHungerTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        self:_ClearOnClose()
    end)
end

InnFeedHappyAndHungerTipsCtrl.ShowTips = HL.StaticMethod(HL.Table) << function(args)
    local self = UIManager:AutoOpen(PANEL_ID)
    self:_ShowTips(args)
end

InnFeedHappyAndHungerTipsCtrl._ShowTips = HL.Method(HL.Table) << function(self, args)
    
    if args.transform == self.m_targetTransform then
        
        if not DeviceInfo.usingController then
            self.view.autoCloseArea:CloseSelf()
        end
        return
    end

    self.m_targetTransform = args.transform
    self.m_happinessExhaustedTs = args.happinessExhaustedTs or 0
    self.m_fullnessExhaustedTs = args.fullnessExhaustedTs or 0

    UIManager:SetTopOrder(PANEL_ID)
    self.view.autoCloseArea:OpenSelf()
    self:_RefreshTexts()
    self:_RefreshPosition()
    self:_StartTick()
end


InnFeedHappyAndHungerTipsCtrl._RefreshTexts = HL.Method() << function(self)
    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local happyLeftSec = math.max(0, self.m_happinessExhaustedTs - currentTime)
    local hungerLeftSec = math.max(0, self.m_fullnessExhaustedTs - currentTime)
    self.view.happyTimeTxt:SetAndResolveTextStyle(UIUtils.getLeftTimeToSecond(happyLeftSec, true))
    self.view.hungerTimeTxt:SetAndResolveTextStyle(UIUtils.getLeftTimeToSecond(hungerLeftSec, true))
end

InnFeedHappyAndHungerTipsCtrl._RefreshPosition = HL.Method() << function(self)
    UIUtils.updateTipsPosition(self.view.content, self.m_targetTransform, self.view.rectTransform, self.uiCamera, UIConst.UI_TIPS_POS_TYPE.MidBottom)
end

InnFeedHappyAndHungerTipsCtrl._StartTick = HL.Method() << function(self)
    if self.m_coroutine then
        self:_ClearCoroutine(self.m_coroutine)
        self.m_coroutine = nil
    end
    self.m_coroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(TIPS_TICK_INTERVAL)
            self:_RefreshTexts()
        end
    end)
end

InnFeedHappyAndHungerTipsCtrl._ClearOnClose = HL.Method() << function(self)
    if self.m_coroutine then
        self:_ClearCoroutine(self.m_coroutine)
        self.m_coroutine = nil
    end
    self.m_targetTransform = nil
end

InnFeedHappyAndHungerTipsCtrl.CloseTips = HL.Method() << function(self)
    if self.view.autoCloseArea.toggleObj.activeSelf then
        self.view.autoCloseArea:CloseSelf()
    end
end

InnFeedHappyAndHungerTipsCtrl.OnHide = HL.Override() << function(self)
    self:_ClearOnClose()
end
InnFeedHappyAndHungerTipsCtrl.OnClose = HL.Override() << function(self)
    self:_ClearOnClose()
end

HL.Commit(InnFeedHappyAndHungerTipsCtrl)
