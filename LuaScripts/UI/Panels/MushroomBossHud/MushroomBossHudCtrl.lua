local mainHudSubPanelCtrl = require_ex('UI/Panels/Base/MainHudSubPanelCtrl')

local ActionName = {
    SetProgress = 'SetProgress',
    PlayBluff = 'PlayBluff',
    BluffSetProgress = 'BluffSetProgress',
    BurstToOnePercent = 'BurstToOnePercent',
}

local BLUFF_START_PROGRESS = 0.4
local DEFAULT_BLUFF_DURATION = 3
local HEALTH_BAR_DURATION = 0.35
local HEALTH_BAR_TRAIL_DURATION = 0.7


MushroomBossHudCtrl = HL.Class('MushroomBossHudCtrl', mainHudSubPanelCtrl.MainHudSubPanelCtrl)

MushroomBossHudCtrl.s_messages = HL.StaticField(HL.Table) << {}

MushroomBossHudCtrl.m_progress = HL.Field(HL.Number) << 1
MushroomBossHudCtrl.m_curActionStage = HL.Field(HL.String) << ""
MushroomBossHudCtrl.m_bluffDuration = HL.Field(HL.Number) << DEFAULT_BLUFF_DURATION
MushroomBossHudCtrl.m_bluffBarProgress = HL.Field(HL.Number) << 1
MushroomBossHudCtrl.m_progressCoroutine = HL.Field(HL.Thread)

MushroomBossHudCtrl.OnMainHudSubPanelCreate = HL.Override(HL.Opt(HL.Any)) << function(self, arg)
end

MushroomBossHudCtrl.OnMainHudSubPanelAction = HL.Override(HL.String, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, actionName, actionArg)
    if actionName == ActionName.SetProgress then
        self:SetProgress(actionArg)
        self.m_curActionStage = actionName
        return true
    end
    if actionName == ActionName.PlayBluff then
        local validDuration = actionArg > 0 and actionArg < 10
        local duration = validDuration and actionArg or DEFAULT_BLUFF_DURATION
        self:PlayBluff(duration)
        self.m_curActionStage = actionName
        return true
    end
    if actionName == ActionName.BluffSetProgress then
        self:SetBluffProgress(actionArg)
        if self.m_curActionStage ~= ActionName.BurstToOnePercent then
            self.m_curActionStage = actionName
        end
        return true
    end
    if actionName == ActionName.BurstToOnePercent then
        self:PlayBurst()
        self.m_curActionStage = actionName
        return true
    end
    return false
end

MushroomBossHudCtrl.CaptureMainHudSubPanelState = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        action = self.m_curActionStage,
        progress = self.m_progress,
        bluffDuration = self.m_bluffDuration,
        bluffBarProgress = self.m_bluffBarProgress,
    }
end

MushroomBossHudCtrl.RestoreMainHudSubPanelState = HL.Override(HL.Opt(HL.Any)) << function(self, stateArgs)
    if stateArgs == nil then
        return
    end
    self:_StopProgressCoroutine()
    self.m_curActionStage = stateArgs.action or ""
    self.m_progress = math.max(0, math.min(stateArgs.progress or 1, 1))
    if self.m_curActionStage == ActionName.PlayBluff then
        local bluffDuration = stateArgs.bluffDuration
        local validDuration = bluffDuration > 0 and bluffDuration < 10
        self.m_bluffDuration = validDuration and bluffDuration or DEFAULT_BLUFF_DURATION
        self.view.stateController:SetState("Special_Max")
    elseif self.m_curActionStage == ActionName.BluffSetProgress then
        self.view.stateController:SetState("Special_Max")
        self.m_bluffBarProgress = lume.clamp(stateArgs.bluffBarProgress, 0, 1)
        self:_RenderBluffProgress(self.m_bluffBarProgress)
    elseif self.m_curActionStage == ActionName.BurstToOnePercent then
        self.view.stateController:SetState("Special_Empty")
    else
        self.view.stateController:SetState("Common")
    end
    self:_RenderProgress(self.m_progress)
    if self.m_isFollowingMainHudVisible
        and self.m_curActionStage == ActionName.PlayBluff
        and self.m_progress < 1 then
        self:_StartBluffProgressCoroutine()
    end
end

MushroomBossHudCtrl.OnMainHudSubPanelShow = HL.Override() << function(self)
    AudioManager.PostEvent("Au_UI_Event_MushroomHPAppear")
    if self.m_curActionStage == ActionName.PlayBluff and self.m_progress < 1 then
        self:_StartBluffProgressCoroutine()
    end
end

MushroomBossHudCtrl.OnMainHudSubPanelHide = HL.Override() << function(self)
    self:_StopProgressCoroutine()
    self:_RenderProgress(self.m_progress)
    if self.m_curActionStage == ActionName.BluffSetProgress then
        self:_RenderBluffProgress(self.m_bluffBarProgress)
    end
end

MushroomBossHudCtrl.OnMainHudSubPanelClose = HL.Override() << function(self)
    self:_StopProgressCoroutine()
end



MushroomBossHudCtrl.SetProgress = HL.Method(HL.Number) << function(self, progress)
    local targetProgress = math.max(0, math.min(progress, 1))
    if targetProgress == self.m_progress and self.m_curActionStage == ActionName.SetProgress then
        return
    end

    local previousProgress = self.m_progress
    local startProgress = self.view.healthBar1.fillAmount
    local startTrailProgress = self.view.healthBar2.fillAmount
    self:_StopProgressCoroutine()
    self.view.stateController:SetState("Common")
    
    self.m_progress = targetProgress
    if targetProgress >= previousProgress or not self.m_isFollowingMainHudVisible then
        self:_RenderProgress(targetProgress)
        return
    end

    self.m_progressCoroutine = self:_StartCoroutine(function()
        local elapsed = 0
        local totalDuration = HEALTH_BAR_DURATION + HEALTH_BAR_TRAIL_DURATION
        while elapsed < totalDuration do
            coroutine.step()
            elapsed = math.min(elapsed + Time.deltaTime, totalDuration)
            local ratio = math.min(elapsed / HEALTH_BAR_DURATION, 1)
            local trailRatio = math.max(elapsed - HEALTH_BAR_DURATION, 0) / HEALTH_BAR_TRAIL_DURATION
            self:_RenderProgress(
                startProgress + (targetProgress - startProgress) * ratio,
                startTrailProgress + (targetProgress - startTrailProgress) * trailRatio)
        end
        self:_RenderProgress(targetProgress)
        self.m_progressCoroutine = nil
    end)
end


MushroomBossHudCtrl.SetBluffProgress = HL.Method(HL.Number) << function(self, progress)
    local targetProgress = math.max(0, math.min(progress, 1))
    local isBurstEmpty = self.m_curActionStage == ActionName.BurstToOnePercent
    local startProgress = isBurstEmpty and self.view.specialEmptyBar.fillAmount or self.view.specialMaxBar.fillAmount
    self:_StopProgressCoroutine()
    if not isBurstEmpty then
        self.view.stateController:SetState("Special_Max", false)
    end
    
    self.m_bluffBarProgress = targetProgress
    if startProgress == targetProgress then
        self:_RenderBluffProgress(targetProgress)
        return
    end

    self.m_progressCoroutine = self:_StartCoroutine(function()
        local elapsed = 0
        while elapsed < HEALTH_BAR_TRAIL_DURATION do
            coroutine.step()
            elapsed = math.min(elapsed + Time.deltaTime, HEALTH_BAR_TRAIL_DURATION)
            self:_RenderBluffProgress(startProgress + (targetProgress - startProgress) * (elapsed / HEALTH_BAR_TRAIL_DURATION))
        end
        self:_RenderBluffProgress(targetProgress)
        self.m_progressCoroutine = nil
    end)
end

MushroomBossHudCtrl.PlayBluff = HL.Method(HL.Number) << function(self, duration)
    self:_StopProgressCoroutine()
    self.m_bluffDuration = duration
    self.view.specialMaxBar.fillAmount = 1
    self.view.specialMaxBar_glow.fillAmount = 1
    self.view.stateController:SetState("Special_Max")
    self:_ApplyProgress(BLUFF_START_PROGRESS)
    if self.m_isFollowingMainHudVisible then
        self:_StartBluffProgressCoroutine()
    end
    
end

MushroomBossHudCtrl._StartBluffProgressCoroutine = HL.Method() << function(self)
    self:_StopProgressCoroutine()

    local startProgress = math.max(BLUFF_START_PROGRESS, math.min(self.m_progress, 1))
    self:_ApplyProgress(startProgress)
    if startProgress >= 1 then
        return
    end

    local remainingRatio = (1 - startProgress) / (1 - BLUFF_START_PROGRESS)
    local remainingDuration = self.m_bluffDuration * remainingRatio
    self.m_progressCoroutine = self:_StartCoroutine(function()
        local elapsed = 0
        while elapsed < remainingDuration do
            coroutine.step()
            elapsed = math.min(elapsed + Time.deltaTime, remainingDuration)
            local ratio = elapsed / remainingDuration
            self:_ApplyProgress(startProgress + (1 - startProgress) * ratio)
        end
        self:_ApplyProgress(1)
        self.m_progressCoroutine = nil
    end)
end


MushroomBossHudCtrl.PlayBurst = HL.Method() << function(self)
    
    self:_StopProgressCoroutine()
    self.view.stateController:SetState("Special_Empty")
    self:_ApplyProgress(0.01)
end

MushroomBossHudCtrl._StopProgressCoroutine = HL.Method() << function(self)
    self.m_progressCoroutine = self:_ClearCoroutine(self.m_progressCoroutine)
end

MushroomBossHudCtrl._ApplyProgress = HL.Method(HL.Number) << function(self, progress)
    self.m_progress = math.max(0, math.min(progress, 1))
    self:_RenderProgress(self.m_progress)
end

MushroomBossHudCtrl._RenderProgress = HL.Method(HL.Number, HL.Opt(HL.Number)) << function(self, progress, trailProgress)
    local displayProgress = math.max(0, math.min(progress, 1))
    self.view.healthBar1.fillAmount = displayProgress
    self.view.healthBar2.fillAmount = trailProgress or displayProgress
    self.view.percentTxt.text = string.format('%d%%', math.floor(displayProgress * 100 + 0.5))

    local tearsState = "100Percent"
    if displayProgress <= 0.4 then
        tearsState = "40Percent"
    elseif displayProgress <= 0.6 then
        tearsState = "60Percent"
    elseif displayProgress <= 0.8 then
        tearsState = "80Percent"
    end
    self.view.tearsGroupState:SetState(tearsState, false)
end


MushroomBossHudCtrl._RenderBluffProgress = HL.Method(HL.Number) << function(self, progress)
    if self.m_curActionStage == ActionName.BurstToOnePercent then
        self.view.specialEmptyBar.fillAmount = progress
    else
        self.view.specialMaxBar.fillAmount = progress
        self.view.specialMaxBar_glow.fillAmount = progress
    end
end

HL.Commit(MushroomBossHudCtrl)
