local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local TaskState = {
    None = 0,
    Normal = 1,
    Finish = 2,
    Fail = 3,
}

local TRACK_GOAL_CELL_ANIM_DEFAULT = "tasktrackhud_celldefault"
local TRACK_GOAL_CELL_ANIM_FAIL = "tasktrackhud_cellfail"
local TRACK_GOAL_CELL_ANIM_FINISH = "tasktrackhud_cellfinish"
local TRACK_GOAL_CELL_ANIM_UPDATE = "tasktrackhud_cellupdate"

CommonTaskGoalCell = HL.Class('CommonTaskGoalCell', UIWidgetBase)

CommonTaskGoalCell.m_objectiveIndex = HL.Field(HL.Number) << -1

CommonTaskGoalCell.m_taskState = HL.Field(HL.Number) << TaskState.None

CommonTaskGoalCell.m_animationWrapper = HL.Field(CS.Beyond.UI.UIAnimationWrapper)

CommonTaskGoalCell.m_taskKey = HL.Field(HL.String) << ""

CommonTaskGoalCell.m_taskType = HL.Field(CS.Beyond.Gameplay.LevelScriptTaskType)

CommonTaskGoalCell.m_taskTracking = HL.Field(CS.Beyond.Gameplay.Core.LevelScriptTaskTracking)

CommonTaskGoalCell.m_taskTrackingObjective = HL.Field(CS.Beyond.Gameplay.Core.LevelScriptTaskTracking.Objective)

CommonTaskGoalCell.m_commonTrackingSystem = HL.Field(CS.Beyond.Gameplay.CommonTrackingSystem)

CommonTaskGoalCell.m_taskTrackPointId = HL.Field(HL.String) << ""

CommonTaskGoalCell.m_updateDistanceTick = HL.Field(HL.Number) << -1

CommonTaskGoalCell.m_showingCor = HL.Field(HL.Thread)


CommonTaskGoalCell._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_TASK_OBJECTIVE_PROGRESS_CHANGE, function(args)
        self:OnGoalProgressChange(args)
    end)

    self.m_animationWrapper = self.view.animationWrapper
    self.m_commonTrackingSystem = GameInstance.player.commonTrackingSystem
end

CommonTaskGoalCell._OnDestroy = HL.Override() << function(self)
    if self.m_updateDistanceTick > 0 then
        self.m_updateDistanceTick = LuaUpdate:Remove(self.m_updateDistanceTick)
    end

    if self.m_showingCor then
        self.m_showingCor = self:_ClearCoroutine(self.m_showingCor)
    end

    local succ, ctrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
    if succ then
        ctrl.taskGoalShowing = false
    end
end

CommonTaskGoalCell.InitCommonTaskGoalCell = HL.Method(HL.String, HL.Number, CS.Beyond.Gameplay.LevelScriptTaskType)
        << function(self, taskKey, objectiveIndex, taskType)
    self:_FirstTimeInit()

    self.m_taskKey = taskKey
    self.m_taskType = taskType
    self.m_objectiveIndex = objectiveIndex
    self.m_taskState = TaskState.None

    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local trackingTask = trackingMgr:GetTaskByKey(taskKey)
    local csIndex = CSIndex(objectiveIndex)
    local objective = trackingTask.objectives[csIndex]
    local objectiveRaw = trackingTask.objectivesRaw[csIndex]
    self.m_taskTracking = trackingTask
    self.m_taskTrackingObjective = objective
    self.m_taskTrackPointId = objectiveRaw.trackingPointId

    local hasTrackPoint = not string.isEmpty(self.m_taskTrackPointId)
    if self.view.distanceNode then
        self.view.distanceNode.gameObject:SetActiveIfNecessary(hasTrackPoint)
    end

    if hasTrackPoint then
        self.m_updateDistanceTick = LuaUpdate:Remove(self.m_updateDistanceTick)
        self.m_updateDistanceTick = LuaUpdate:Add("TailTick", function()
            self:_UpdateDistance()
        end, true)
    end

    self:_Refresh(true)
end

CommonTaskGoalCell.RefreshStyle = HL.Method() << function(self)
    local subGameId = GameWorld.worldInfo.curSubGameId
    if not subGameId or subGameId == "" then
        return
    end
    local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(subGameId)
    if not success or not subGameData.taskGoalStyle then
        return
    end
    local style = subGameData.taskGoalStyle
    local EGameTaskGoalStyleType = CS.Beyond.Gameplay.Core.EGameTaskGoalStyleType

    self.view.default:SetState(style == EGameTaskGoalStyleType.Normal and "normal" or "custom")

    local spriteName = UIConst.UI_SPRITE_COMMON_TASK_TRACK
    local useCommonIcon = style == EGameTaskGoalStyleType.Normal
        or self.m_taskType == CS.Beyond.Gameplay.LevelScriptTaskType.Custom
    local iconPrefix = useCommonIcon and "common" or subGameData.taskGoalIconName

    local states = {
        {view = self.view.failIcon, suffix = "fail"},
        {view = self.view.unfinishedIcon, suffix = "normal"},
        {view = self.view.finishedIcon, suffix = "succ"}
    }

    for _, stateInfo in ipairs(states) do
        local iconPath = string.format("icon_%s_task_%s", iconPrefix, stateInfo.suffix)
        stateInfo.view:LoadSprite(spriteName, iconPath)
    end
end


CommonTaskGoalCell.OnGoalProgressChange = HL.Method(HL.Any) << function(self, args)
    local taskType, taskKey, csIndex = unpack(args)
    if self.m_taskType ~= taskType or self.m_objectiveIndex ~= LuaIndex(csIndex) or self.m_taskKey ~= taskKey then
        return
    end

    self:_Refresh(false)
end

CommonTaskGoalCell.TrySetStateFail = HL.Method() << function(self)
    if self.m_taskState ~= TaskState.Finish then
        self:_CustomPlayAnimation(TRACK_GOAL_CELL_ANIM_FAIL)
    end
end


CommonTaskGoalCell.ForceSetFail = HL.Method() << function(self)
    self.m_taskState = TaskState.Fail
    self.view.default:SetState("statefail")
    if self.m_animationWrapper then
        self.m_animationWrapper:SampleClipAtPercent(TRACK_GOAL_CELL_ANIM_FAIL, 1)
    end
end



CommonTaskGoalCell.InitCommonTaskGoalCellStatic = HL.Method(HL.String, HL.Number, CS.Beyond.Gameplay.LevelScriptTaskType)
        << function(self, taskKey, objectiveIndex, taskType)
    self:InitCommonTaskGoalCell(taskKey, objectiveIndex, taskType)
    if not self.m_animationWrapper then
        return
    end
    if self.m_taskState == TaskState.Finish then
        self.m_animationWrapper:SampleClipAtPercent(TRACK_GOAL_CELL_ANIM_FINISH, 1)
    elseif self.m_taskState == TaskState.Fail then
        self.m_animationWrapper:SampleClipAtPercent(TRACK_GOAL_CELL_ANIM_FAIL, 1)
    end
end

CommonTaskGoalCell._Refresh = HL.Method(HL.Boolean) << function(self, isInit)
    if not self.m_taskTrackingObjective then
        return
    end
    local isCompleted = self.m_taskTrackingObjective.isCompleted
    local isFail = self.m_taskTrackingObjective.inFailStyle
    
    local success, descText, progressText = self.m_taskTracking:TryGetValueObjectiveDescription(self.m_taskTrackingObjective)
    if success then
        local descTextI18nResolveGender = UIUtils.resolveTextGender(descText)
        local failText = descTextI18nResolveGender
        if isFail then
            failText = (string.format("<s>%s</s>", descTextI18nResolveGender))
        end
        self.view.goalTxt:SetAndResolveTextStyle(failText)
        self.view.progressTxt:SetAndResolveTextStyle(progressText)
    else
        self.view.goalTxt.text = ""
        self.view.progressTxt.text = ""
    end
    
    if isInit then
        self.m_animationWrapper:SampleClipAtPercent(TRACK_GOAL_CELL_ANIM_DEFAULT, 1)
        self:RefreshStyle()
    end

    local nowState = "statenormal"
    if isCompleted then
        nowState = "statesucc"

    elseif isFail then
        nowState = "statefail"
    end
    self.view.default:SetState(nowState)
    local preState = self.m_taskState
    self.m_taskState = isCompleted and TaskState.Finish or (isFail and TaskState.Fail or TaskState.Normal)
    if preState ~= self.m_taskState then
        if self.m_taskState == TaskState.Finish then
            AudioAdapter.PostEvent("Au_UI_Mission_Step_Complete")
            self:_CustomPlayAnimation(TRACK_GOAL_CELL_ANIM_FINISH)
        elseif self.m_taskState == TaskState.Fail then
            self.m_animationWrapper:Play(TRACK_GOAL_CELL_ANIM_FAIL)
        elseif self.m_taskState == TaskState.Normal then
            self.m_animationWrapper:Play(TRACK_GOAL_CELL_ANIM_DEFAULT)
        end
    elseif not isInit and self.m_taskState == TaskState.Normal then
        AudioAdapter.PostEvent("Au_UI_Mission_BattleTinyStep_Complete")
        self.m_animationWrapper:Play(TRACK_GOAL_CELL_ANIM_UPDATE)
    end
end

CommonTaskGoalCell._UpdateDistance = HL.Method() << function(self)
    if IsNull(self.view.gameObject) then
        logger.error("[CommonTaskGoalCell] _UdpateDistance but go is destroyed")
        return
    end

    local succ, isOutGuidingArea, distance = self.m_commonTrackingSystem:GetTrackingPointInfo(self.m_taskTrackPointId)
    self.view.distanceTxt.text = isOutGuidingArea and string.format("%.0f m", distance) or Language.IN_OBJECTIVE_AREA_TIPS
    self.view.distanceNode.gameObject:SetActiveIfNecessary(succ)
end

CommonTaskGoalCell._CustomPlayAnimation = HL.Method(HL.String) << function(self, anim)
    local succ, ctrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
    if succ then
        ctrl.taskGoalShowing = true
        self.m_animationWrapper:Play(anim)
        self.m_showingCor = self:_ClearCoroutine(self.m_showingCor)
        self.m_showingCor = self:_StartCoroutine(function()
            local clipLength = self.m_animationWrapper:GetClipLength(anim)
            coroutine.wait(clipLength)
            ctrl.taskGoalShowing = false
        end)
    end
end

HL.Commit(CommonTaskGoalCell)
return CommonTaskGoalCell
