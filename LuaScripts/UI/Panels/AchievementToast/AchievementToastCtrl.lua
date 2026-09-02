
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.AchievementToast

AchievementToastCtrl = HL.Class('AchievementToastCtrl', uiCtrl.UICtrl)






AchievementToastCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

AchievementToastCtrl.RequestAchievementToasts = HL.StaticMethod(HL.Any) << function(arg)
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Achievement) then
        return
    end
    if arg == nil then
        return
    end
    local bundles = unpack(arg)
    UIManager:PreloadPersistentPanelAsset(PANEL_ID, function()
        local ctrl = AchievementToastCtrl.AutoOpen(PANEL_ID, nil, false)
        ctrl:_RequestToasts(bundles)
    end)
end

AchievementToastCtrl.EnableAchievementToastByLoading = HL.StaticMethod() << function()
    AchievementToastCtrl._EnableByKey(UIConst.ACHIEVEMENT_TOAST_DISABLE_KEY.Loading)
end

AchievementToastCtrl.DisableAchievementToastByLoading = HL.StaticMethod() << function()
    AchievementToastCtrl._DisableByKey(UIConst.ACHIEVEMENT_TOAST_DISABLE_KEY.Loading)
end

AchievementToastCtrl.EnableAchievementToast = HL.StaticMethod(HL.Any) << function(arg)
    AchievementToastCtrl._EnableByKey(arg)
end

AchievementToastCtrl.DisableAchievementToast = HL.StaticMethod(HL.Any) << function(arg)
    AchievementToastCtrl._DisableByKey(arg)
end

AchievementToastCtrl._EnableByKey = HL.StaticMethod(HL.String) << function(key)
    if string.isEmpty(key) then
        logger.error("Achievement disable status is setting without key, pls check.")
        return
    end
    AchievementToastCtrl.s_disableByKey[key] = nil
end

AchievementToastCtrl._DisableByKey = HL.StaticMethod(HL.String) << function(key)
    if string.isEmpty(key) then
        logger.error("Achievement disable status is setting without key, pls check.")
        return
    end
    AchievementToastCtrl.s_disableByKey[key] = true
end

AchievementToastCtrl._CheckIsDisable = HL.StaticMethod().Return(HL.Boolean) << function()
    for key, flag in pairs(AchievementToastCtrl.s_disableByKey) do
        if flag == true then
            return true
        end
    end
    return false
end

AchievementToastCtrl.m_updateKey = HL.Field(HL.Number) << -1

AchievementToastCtrl.m_requestQueue = HL.Field(HL.Forward("Queue"))

AchievementToastCtrl.m_showTween = HL.Field(HL.Any) << nil

AchievementToastCtrl.m_achievementToastTimer = HL.Field(HL.Number) << 0

AchievementToastCtrl.s_disableByKey = HL.StaticField(HL.Table) << {}

AchievementToastCtrl.m_currentToast = HL.Field(HL.Any) << nil

AchievementToastCtrl.m_shownNonPlatedToastLevels = HL.Field(HL.Table) << function() return {} end


AchievementToastCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local switchBuilder = CS.Beyond.UI.UIAnimationSwitchTween.Builder()
    local tweenOptions = CS.Beyond.UI.UISwitchTween.Options()
    tweenOptions.onShown = function()
        self:_OnToastShown()
    end
    tweenOptions.onHiden = function()
        self:_OnToastHidden()
    end
    switchBuilder.animWrapper = self.animationWrapper
    switchBuilder.dontDisableGameObject = true
    self.m_showTween = switchBuilder:Build()
    self.m_showTween:Reset(false)
    self.m_showTween:SetOptions(tweenOptions)
    self.m_requestQueue = require_ex("Common/Utils/DataStructure/Queue")()
    self.m_updateKey = LuaUpdate:Add("Tick", function()
        self:_Update()
    end, true)
end





AchievementToastCtrl.OnClose = HL.Override() << function(self)
    if self.m_achievementToastTimer > 0 then
        self:_ClearTimer(self.m_achievementToastTimer)
    end
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
    self.m_showTween:Clear()
    self.m_showTween = nil
end




AchievementToastCtrl._RequestToasts = HL.Method(HL.Any) << function(self, bundles)
    if bundles == nil then
        return
    end
    for _, bundle in pairs(bundles) do
        if bundle ~= nil and not string.isEmpty(bundle.achievementId) then
            local steps = self:_ExpandToastSteps(bundle)
            for _, step in ipairs(steps) do
                if not self:_IsDuplicateToast(step) then
                    self.m_requestQueue:Push(step)
                end
            end
        end
    end
end


AchievementToastCtrl._ExpandToastSteps = HL.Method(HL.Any).Return(HL.Table) << function(self, bundle)
    local achievementData = Tables.achievementTable[bundle.achievementId]
    if achievementData == nil then
        return { bundle }
    end

    local steps = {}
    local initLevel = achievementData.initLevel
    local startLevel = bundle.fromLevel
    local endLevel = bundle.toLevel
    local midStepPlated = not bundle.isPlating and bundle.isPlated or false

    local needObtainStep = startLevel < initLevel
    if needObtainStep and endLevel >= initLevel then
        local step = self:_MakeStep(bundle.achievementId, startLevel, initLevel, false, midStepPlated)
        table.insert(steps, step)
        startLevel = initLevel
    end

    for level = startLevel + 1, endLevel do
        local step = self:_MakeStep(bundle.achievementId, level - 1, level, false, midStepPlated)
        table.insert(steps, step)
    end

    if bundle.isPlating then
        local preStep = self:_MakeStep(bundle.achievementId, 0, endLevel, false, false)
        preStep.isPlatingPreStep = true
        preStep.fromObtainTs = bundle.fromObtainTs
        table.insert(steps, preStep)
        table.insert(steps, self:_MakeStep(bundle.achievementId, endLevel, endLevel, true, true))
    end

    if #steps == 0 then
        return { bundle }
    end
    return steps
end

AchievementToastCtrl._MakeStep = HL.Method(HL.String, HL.Number, HL.Number, HL.Boolean, HL.Boolean).Return(HL.Table) << function(self, achievementId, fromLevel, toLevel, isPlating, isPlated)
    return {
        achievementId = achievementId,
        fromLevel = fromLevel,
        toLevel = toLevel,
        isPlating = isPlating,
        isPlated = isPlated,
    }
end

AchievementToastCtrl._HasShownNonPlatedToast = HL.Method(HL.Any).Return(HL.Boolean) << function(self, achieveBundle)
    local shownLevels = self.m_shownNonPlatedToastLevels[achieveBundle.achievementId]
    return shownLevels ~= nil and shownLevels[achieveBundle.toLevel] == true
end

AchievementToastCtrl._MarkNonPlatedToastShown = HL.Method(HL.Any) << function(self, achieveBundle)
    local achievementId = achieveBundle.achievementId
    local shownLevels = self.m_shownNonPlatedToastLevels[achievementId]
    if shownLevels == nil then
        shownLevels = {}
        self.m_shownNonPlatedToastLevels[achievementId] = shownLevels
    end
    shownLevels[achieveBundle.toLevel] = true
end

AchievementToastCtrl._IsDuplicateToast = HL.Method(HL.Any).Return(HL.Boolean) << function(self, step)
    if self:_IsStepMatch(self.m_currentToast, step) then
        return true
    end
    for i = self.m_requestQueue.m_head, self.m_requestQueue.m_tail do
        if self:_IsStepMatch(self.m_requestQueue.m_data[i], step) then
            return true
        end
    end
    return false
end

AchievementToastCtrl._IsStepMatch = HL.Method(HL.Any, HL.Any).Return(HL.Boolean) << function(self, a, b)
    return a ~= nil and b ~= nil
        and a.achievementId == b.achievementId
        and a.toLevel == b.toLevel
        and a.isPlating == b.isPlating
end

AchievementToastCtrl._Update = HL.Method() << function(self)
    if AchievementToastCtrl._CheckIsDisable() then
        return
    end
    if self.m_achievementToastTimer > 0 or self.m_requestQueue:Count() <= 0 then
        return
    end
    local bundle = self.m_requestQueue:Pop()
    while not self:_ShowToast(bundle) and self.m_requestQueue:Count() > 0 do
        bundle = self.m_requestQueue:Pop()
    end
end

AchievementToastCtrl._ShowToast = HL.Method(HL.Any).Return(HL.Boolean) << function(self, achieveBundle)
    local isPlatingPreStep = type(achieveBundle) == "table" and achieveBundle.isPlatingPreStep
    local hasShownNonPlatedToast = isPlatingPreStep and self:_HasShownNonPlatedToast(achieveBundle)
    local fromObtainTs = isPlatingPreStep and achieveBundle.fromObtainTs or 0
    
    local shouldSkipPlatingPreStep = isPlatingPreStep
        and (fromObtainTs > 0 or hasShownNonPlatedToast)
    if shouldSkipPlatingPreStep then
        return false
    end
    self.m_showTween:Reset(false)
    local achievementData = Tables.achievementTable[achieveBundle.achievementId]
    if achievementData == nil then
        return false
    end
    self.m_currentToast = achieveBundle
    local isPlated = achieveBundle.isPlated
    local duration = self.m_requestQueue:Count() > 0 and self.view.config.SHORT_TOAST_DURATION or self.view.config.NORMAL_TOAST_DURATION
    self.m_showTween.isShow = true
    self:_RenderToast(achieveBundle, achievementData, isPlated)
    if not achieveBundle.isPlating and not isPlated then
        self:_MarkNonPlatedToastShown(achieveBundle)
    end
    self.m_achievementToastTimer = TimerManager:StartTimer(duration, function()
        self:_HideToast()
    end)
    return true
end

AchievementToastCtrl._RenderToast = HL.Method(HL.Any, HL.Any, HL.Boolean) << function(self, achieveBundle, achievementData, isPlated)
    local isRare = achievementData.applyRareEffect and achieveBundle.toLevel > Tables.achievementConst.levelDisplayEffect
    self.view.toMedal:InitMedal({
        achievementId = achieveBundle.achievementId,
        level = achieveBundle.toLevel,
        isPlated = isPlated,
        isRare = achievementData.applyRareEffect
    })
    self.view.name.text = achievementData.name
    self.view.stateCtrl:SetState(isRare and "IsQualify" or "NoQualify")
    self:_ResetUpgradeAnim()
    if achieveBundle.fromLevel <= 0 or (achieveBundle.toLevel == achievementData.initLevel and not achieveBundle.isPlating) then
        self.view.fromMedal:InitMedal(nil)
        self.view.title.text = I18nUtils.GetText("ui_achv_toast_obtain")
    else
        local upgradeAnimName = ''
        self.view.fromMedal:InitMedal({
            achievementId = achieveBundle.achievementId,
            level = achieveBundle.fromLevel,
            isPlated = not achieveBundle.isPlating and isPlated,
            isRare = achievementData.applyRareEffect
        })
        if achieveBundle.isPlating then
            if achieveBundle.toLevel == UIConst.ACHIEVEMENT_MEDAL_UPGRADE_LEVEL.Silver then
                upgradeAnimName = self.view.config.UPGRADE_PLATING_SILVER_ANIM_NAME
            elseif achieveBundle.toLevel == UIConst.ACHIEVEMENT_MEDAL_UPGRADE_LEVEL.Gold then
                upgradeAnimName = self.view.config.UPGRADE_PLATING_GOLD_ANIM_NAME
            end
            self.view.title.text = I18nUtils.GetText("ui_achv_toast_plating")
        else
            if achieveBundle.toLevel == UIConst.ACHIEVEMENT_MEDAL_UPGRADE_LEVEL.Silver then
                upgradeAnimName = self.view.config.UPGRADE_SILVER_ANIM_NAME
            elseif achieveBundle.toLevel == UIConst.ACHIEVEMENT_MEDAL_UPGRADE_LEVEL.Gold then
                upgradeAnimName = self.view.config.UPGRADE_GOLD_ANIM_NAME
            end
            self.view.title.text = I18nUtils.GetText("ui_achv_toast_evolute")
        end
        self:_PlayUpgradeAnim(upgradeAnimName)
    end
end

AchievementToastCtrl._ResetUpgradeAnim = HL.Method() << function(self)
    if not string.isEmpty(self.view.config.UPGRADE_RESET_SAMPLE_ANIM_NAME) then
        self.view.animationNode:SampleClipAtPercent(self.view.config.UPGRADE_RESET_SAMPLE_ANIM_NAME, 0)
    else
        self.view.animationNode:ClearTween()
    end
end

AchievementToastCtrl._PlayUpgradeAnim = HL.Method(HL.String) << function(self, animName)
    if not string.isEmpty(animName) then
        self.view.animationNode:PlayWithTween(animName)
    end
end

AchievementToastCtrl._HideToast = HL.Method(HL.Opt(HL.Boolean)) << function(self, fastMode)
    self.m_showTween.isShow = false
end

AchievementToastCtrl._OnToastEnd = HL.Method() << function(self)
    self:_ClearTimer(self.m_achievementToastTimer)
    self.m_achievementToastTimer = 0
    self.m_currentToast = nil
end

AchievementToastCtrl._OnToastShown = HL.Method() << function(self)
    
end

AchievementToastCtrl._OnToastHidden = HL.Method() << function(self)
    self:_OnToastEnd()
end

HL.Commit(AchievementToastCtrl)
