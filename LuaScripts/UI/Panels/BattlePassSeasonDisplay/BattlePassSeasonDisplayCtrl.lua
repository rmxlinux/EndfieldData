
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BattlePassSeasonDisplay







BattlePassSeasonDisplayCtrl = HL.Class('BattlePassSeasonDisplayCtrl', uiCtrl.UICtrl)







BattlePassSeasonDisplayCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


BattlePassSeasonDisplayCtrl.m_isVideoReady = HL.Field(HL.Boolean) << false


BattlePassSeasonDisplayCtrl.m_videoDelayTimer = HL.Field(HL.Number) << 0





BattlePassSeasonDisplayCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    local curServerTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local leftSec = GameInstance.player.battlePassSystem.seasonData.closeTime - curServerTime
    local videoExist, videoPath = BattlePassUtils.GetBattlePassIntroVideoPath()
    leftSec = math.max(leftSec, 0)
    self.view.seasonEndReminderText.text = string.format(Language.LUA_BATTLEPASS_NEW_SEASON_PANEL_SEASON_END_TIME, UIUtils.getShortLeftTime(leftSec))
    self.view.maskBtn.onClick:AddListener(function()
        if not videoExist then
            logger.error(ELogChannel.UI, "BP赛季武器视频不存在")
            self:Close()
            if arg ~= nil and arg.onClose ~= nil then
                arg.onClose()
            end
            return
        end
        if not self.m_isVideoReady then
            return
        end
        self.m_videoDelayTimer = TimerManager:StartTimer(self.view.config.VIDEO_PLAY_DELAY, function()
            self.view.videoPlayer:PlayVideo(videoPath)
            self.view.videoPlayer.view.canvasGroup.alpha = 1.0
            AudioAdapter.PostEvent("au_music_cs_battlepass")
            TimerManager:ClearTimer(self.m_videoDelayTimer)
            self.m_videoDelayTimer = 0
        end)
        self:PlayAnimationOutWithCallback(function()
            self:Close()
            if arg ~= nil and arg.onClose ~= nil then
                arg.onClose()
            end
        end)
    end)
    self.view.agreementTxt.text = BattlePassUtils.GetSeasonData().name

    self.m_isVideoReady = false
    self.view.videoPlayer:PreloadVideo(videoPath, function()
        self.m_isVideoReady = true
    end)
end








BattlePassSeasonDisplayCtrl.OnClose = HL.Override() << function(self)
    TimerManager:ClearTimer(self.m_videoDelayTimer)
    self.m_videoDelayTimer = 0
    self.view.videoPlayer:StopVideo(true)
end




HL.Commit(BattlePassSeasonDisplayCtrl)
