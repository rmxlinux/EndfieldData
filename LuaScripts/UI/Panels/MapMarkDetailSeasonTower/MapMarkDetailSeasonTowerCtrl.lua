
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailSeasonTower

MapMarkDetailSeasonTowerCtrl = HL.Class('MapMarkDetailSeasonTowerCtrl', uiCtrl.UICtrl)






MapMarkDetailSeasonTowerCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SEASON_TOWER_NEW] = '_RefreshSeasonText',
    
}


MapMarkDetailSeasonTowerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local markInstId = arg.markInstId
    local commonArgs = {
        markInstId = markInstId,
        leftBtnActive = true, 
        leftBtnText = Language["ui_mapmarkdetail_button_info"],
        leftBtnIconName = UIConst.MAP_DETAIL_BTN_ICON_NAME.DETAIL,
        leftBtnCallback = function()
            PhaseManager:GoToPhase(PhaseId.SeasonTowerMainHud)
        end,
        rightBtnActive = true, 
    }

    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon(commonArgs)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    self:_RefreshSeasonText()
end


MapMarkDetailSeasonTowerCtrl._RefreshSeasonText = HL.Method() << function(self)
    local system = GameInstance.player.seasonTowerSystem

    if system.currentSeasonId <= 0 or system.currentWeekId <= 0 then
        self.view.countDownText:StopCountDown()
        self.view.countDownText.view.text.text = Language.LUA_SEASON_TOWER_NO_SEASON
        return
    end

    self.view.countDownText:InitCountDownText(system.seasonRecord.endTime, nil, function(leftTime)
        return string.format(Language.LUA_SEASON_TOWER_REMAIN_SEASON_TIME, UIUtils.getLeftTime(leftTime))
    end)
end











HL.Commit(MapMarkDetailSeasonTowerCtrl)
