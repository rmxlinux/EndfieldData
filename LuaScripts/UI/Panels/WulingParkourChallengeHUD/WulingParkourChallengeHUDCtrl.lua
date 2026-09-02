local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WulingParkourChallengeHUD








WulingParkourChallengeHUDCtrl = HL.Class('WulingParkourChallengeHUDCtrl', uiCtrl.UICtrl)







WulingParkourChallengeHUDCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.CLOSE_PARKOUR_HUD] = "OnCloseParkourHud",
}


WulingParkourChallengeHUDCtrl.OnOpenParkourHud = HL.StaticMethod() << function()
    TimerManager:StartTimer(0, function()  
        WulingParkourChallengeHUDCtrl.AutoOpen(PANEL_ID, nil, true)
    end)
end



WulingParkourChallengeHUDCtrl.OnCloseParkourHud = HL.Method() << function(self)
    self:Close()
end





WulingParkourChallengeHUDCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:OnUpdateParkourCollectedNumber(true)
end


WulingParkourChallengeHUDCtrl.OnUpdateParkourCollectedCount = HL.StaticMethod() << function()
    local succ, ctrl = UIManager:IsOpen(PANEL_ID)
    if succ then
        ctrl:OnUpdateParkourCollectedNumber(false)
    end
end




WulingParkourChallengeHUDCtrl.OnUpdateParkourCollectedNumber = HL.Method(HL.Boolean) << function(self, isInit)
    local count = GameInstance.player.parkourSystem.currentCollectedCount
    local bubbleMax = 0
    local subGameId = GameWorld.worldInfo.curSubGameId
    local succ, uiCfg = Tables.ParkourUiTable:TryGetValue(subGameId)
    if succ then
        bubbleMax = uiCfg.bubbleMaxNumber
    end
    self.view.collectedNumberTxt.text = string.format(Language.LUA_ACTIVITY_PARKOUR_MAIN_PANEL_LEVEL_BUBBLE_NUMBER, count, bubbleMax)
    if count >= bubbleMax then
        self.view.balloonNodeController:SetState("Collected")
    else
        self.view.balloonNodeController:SetState("NotFull")
    end
    if not isInit then
        self.view.balloonProgressNodeaAnim:PlayWithTween("parkourchallengehud_balloon_get")
    end
end


HL.Commit(WulingParkourChallengeHUDCtrl)
