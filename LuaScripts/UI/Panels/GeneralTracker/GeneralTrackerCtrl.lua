local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

local PLAY_ANIM_IN_SIGNAL = 1  

GeneralTrackerCtrl = HL.Class('GeneralTrackerCtrl', uiCtrl.UICtrl)







GeneralTrackerCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.REFRESH_MISSION_TRACK_ALPHA] = '_RefreshMissionTrackAlpha',
    [MessageConst.ON_TRACK_MISSION_CHANGE] = '_OnTrackMissionChange',
    [MessageConst.ON_MISSION_STATE_CHANGE] = '_OnMissionStateChange',
    [MessageConst.ON_QUEST_STATE_CHANGE] = '_OnQuestStateChange',
    [MessageConst.ON_QUEST_OBJECTIVE_UPDATE] = '_OnQuestObjectiveUpdate',
}

GeneralTrackerCtrl.s_missionShowTime = HL.StaticField(HL.Number) << 0

GeneralTrackerCtrl.s_missionTrackerSignal = HL.StaticField(HL.Number) << 0

GeneralTrackerCtrl.m_onShowSignal = HL.Field(HL.Number) << 0

GeneralTrackerCtrl.OnShowMissionTracker = HL.StaticMethod() << function()
    GeneralTrackerCtrl.s_missionTrackerSignal = PLAY_ANIM_IN_SIGNAL
    GeneralTrackerCtrl.s_missionShowTime = 0
end

GeneralTrackerCtrl.m_trackerTickHandler = HL.Field(HL.Any)


GeneralTrackerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.generalTrackerComp:Init(
        self.view.config.ELLIPSE_X_RADIUS,
        self.view.config.ELLIPSE_Y_RADIUS,
        self.view.config.ALPHA_IN_FIGHT,
        self.view.config.ALPHA_TIME_OUT,
        self.view.config.MISSION_TRACKER_TIME_OUT_VALUE
    )
end

GeneralTrackerCtrl.OnShow = HL.Override() << function(self)
    GeneralTrackerCtrl.s_missionShowTime = 0
    self.m_onShowSignal = PLAY_ANIM_IN_SIGNAL
    self:_TickTrackers() 
    self.m_trackerTickHandler = LuaUpdate:Add("TailTick", function()
        self:_TickTrackers()
    end)
end

GeneralTrackerCtrl.OnHide = HL.Override() << function(self)
    LuaUpdate:Remove(self.m_trackerTickHandler)
    self.m_trackerTickHandler = nil
end

GeneralTrackerCtrl.OnClose = HL.Override() << function(self)
    LuaUpdate:Remove(self.m_trackerTickHandler)
    self.m_trackerTickHandler = nil
end

GeneralTrackerCtrl._ResetMissionShowTime = HL.StaticMethod() << function()
    GeneralTrackerCtrl.s_missionShowTime = 0
end

GeneralTrackerCtrl._OnTrackMissionChange = HL.Method() << function(self)
    GeneralTrackerCtrl._ResetMissionShowTime()
end

GeneralTrackerCtrl._RefreshMissionTrackAlpha = HL.Method() << function(self)
    GeneralTrackerCtrl._ResetMissionShowTime()
end

GeneralTrackerCtrl._OnMissionStateChange = HL.Method(HL.Any) << function(self, arg)
    GeneralTrackerCtrl._ResetMissionShowTime()
end

GeneralTrackerCtrl._OnQuestStateChange = HL.Method(HL.Any) << function(self, arg)
    GeneralTrackerCtrl._ResetMissionShowTime()
end

GeneralTrackerCtrl._OnQuestObjectiveUpdate = HL.Method(HL.Any) << function(self, arg)
    GeneralTrackerCtrl._ResetMissionShowTime()
end

GeneralTrackerCtrl._TickTrackers = HL.Method() << function(self)
    local missionHudOpen = UIManager:IsOpen(PanelId.MissionHud) or UIManager:IsOpen(PanelId.WeeklyRaidTaskTrackHud)
    GeneralTrackerCtrl.s_missionShowTime = GeneralTrackerCtrl.s_missionShowTime + Time.deltaTime

    self.view.generalTrackerComp:UpdateTrackers(
        missionHudOpen,
        GeneralTrackerCtrl.s_missionShowTime,
        GeneralTrackerCtrl.s_missionTrackerSignal,
        self.m_onShowSignal
    )

    GeneralTrackerCtrl.s_missionTrackerSignal = 0
    self.m_onShowSignal = 0
end

GeneralTrackerCtrl.PlayAnimationOutWithCallback = HL.Override(HL.Opt(HL.Function)) << function(self, action)
    self.view.generalTrackerComp:PlayAnimationOut()
    GeneralTrackerCtrl.Super.PlayAnimationOutWithCallback(self, action)
end

HL.Commit(GeneralTrackerCtrl)
