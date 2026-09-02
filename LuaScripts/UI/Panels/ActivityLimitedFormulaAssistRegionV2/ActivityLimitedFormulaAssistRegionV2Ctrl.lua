local activityLimitedFormulaAssistRegionCtrl = require_ex('UI/Panels/ActivityLimitedFormulaAssistRegion/ActivityLimitedFormulaAssistRegionCtrl')
local PANEL_ID = PanelId.ActivityLimitedFormulaAssistRegionV2

ActivityLimitedFormulaAssistRegionV2Ctrl = HL.Class('ActivityLimitedFormulaAssistRegionV2Ctrl', activityLimitedFormulaAssistRegionCtrl.ActivityLimitedFormulaAssistRegionCtrl)

local ACHIEVEMENT_ID = "achv_event_formula"
local START_STAGE_INDEX = 1
local FINAL_STAGE_INDEX = 3

local STAGE_STATE_TO_POINT_STATE_MAP = {
    [GEnums.ActivityConditionalStageState.Locked] = "None",
    [GEnums.ActivityConditionalStageState.Unlocked] = "Doing",
    [GEnums.ActivityConditionalStageState.Completed] = "Done",
    [GEnums.ActivityConditionalStageState.Rewarded] = "Done",
}

HL.Commit(ActivityLimitedFormulaAssistRegionV2Ctrl)
