local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonTaskTrackCountdown

local Component = {
    countdownTopBig = 1,
    countdownTopLeftSmall = 2,
    counting = 3,
}

local countDownTypeTable = {
    [GEnums.GameMechanicCountDownComponentType.TopBig] = {
        name = "countdownTopBig",
        animationWrapper = { "animationWrapper" },
        loopAnim = "tasktrackcountdown_loop",
    },
    [GEnums.GameMechanicCountDownComponentType.TopLeftSmall] = {
        name = "countdownTopLeftSmall",
        animationWrapper = { "countdownTopLeftSmall", "animationWrapper" },
        loopAnim = "tasktrackcountdown_topleft_red",
    },
}



















CommonTaskTrackCountdownCtrl = HL.Class('CommonTaskTrackCountdownCtrl', uiCtrl.UICtrl)


CommonTaskTrackCountdownCtrl.m_countDownTickId = HL.Field(HL.Number) << -1


CommonTaskTrackCountdownCtrl.m_countingTickId = HL.Field(HL.Number) << -1


CommonTaskTrackCountdownCtrl.m_originalAnchoredPos = HL.Field(Vector2)






CommonTaskTrackCountdownCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CLOSE_COMMON_TASK_COUNTDOWN] = "OnCloseCommonTaskCountdown",
    [MessageConst.ON_FINISH_COMMON_TASK_COUNTING] = "OnFinishCommonTaskCounting",

    
    
}



CommonTaskTrackCountdownCtrl.OnShowCommonTaskCountdown = HL.StaticMethod(HL.Any) << function(args)
    local ctrl = CommonTaskTrackCountdownCtrl.AutoOpen(PANEL_ID, args, true)
    ctrl:ShowCountdown(args)
end


CommonTaskTrackCountdownCtrl.OnStartCommonTaskCounting = HL.StaticMethod() << function(args)
    local ctrl = CommonTaskTrackCountdownCtrl.AutoOpen(PANEL_ID, args, true)
    ctrl:StartCounting(args)
end





CommonTaskTrackCountdownCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_originalAnchoredPos = self.view.main.anchoredPosition
end



CommonTaskTrackCountdownCtrl.OnClose = HL.Override() << function(self)
    if self.m_countDownTickId > 0 then
        self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)

    end

    if self.m_countingTickId > 0 then
        self.m_countingTickId = LuaUpdate:Remove(self.m_countingTickId)
    end
end




CommonTaskTrackCountdownCtrl._ToggleComponentOn = HL.Method(HL.Number) << function(self, component)
    self.view.countdownTopBig.gameObject:SetActiveIfNecessary(component == Component.countdownTopBig)
    self.view.countdownTopLeftSmall.gameObject:SetActiveIfNecessary(component == Component.countdownTopLeftSmall)
    self.view.counting.gameObject:SetActiveIfNecessary(component == Component.counting)
end



CommonTaskTrackCountdownCtrl._IsWorldFreeze = HL.Method().Return(HL.Boolean) << function(self)
    local isOpen, ctrl = UIManager:IsOpen(PanelId.CommonPopUp)
    return UIWorldFreezeManager:IsUIWorldFreeze() or isOpen and ctrl.m_timeScaleHandler > 0
end




CommonTaskTrackCountdownCtrl.ShowCountdown = HL.Method(HL.Any) << function(self, arg)
    local countDownType, countdownDurationMilli, expireTimestampMilli, cb = unpack(arg)
    
    local countDownTypeName = countDownTypeTable[countDownType].name
    local animationWrapper = self.view
    for _, i in ipairs(countDownTypeTable[countDownType].animationWrapper) do
        animationWrapper = animationWrapper[i]
    end
    local loopAnim = countDownTypeTable[countDownType].loopAnim

    self:_ToggleComponentOn(Component[countDownTypeName])
    local countdownNode = self.view[countDownTypeName]
    local countdownDuration = countdownDurationMilli / 1000
    local lastLeftTime = countdownDuration

    local isInAlert = false
    countdownNode.colorState:SetState("Normal")
    self.m_countDownTickId = LuaUpdate:Add("Tick", function(deltaTime)
        local game = GameWorld.worldInfo.subGame
        if game == nil or game.waitingSrvResume then
            return
        end

        local leftTime = game:GetRealEndGameTimestampForLua() - DateTimeUtils.GetCurrentTimestampBySeconds()
        if leftTime > lastLeftTime then
            
            
            leftTime = lastLeftTime
        end
        lastLeftTime = leftTime
        countdownNode.countDownTxt.text = UIUtils.getLeftTimeToSecond(math.max(0, leftTime))

        
        if countdownNode.fill then
            countdownNode.fill.fillAmount = leftTime / countdownDuration
        end

        
        if not isInAlert and leftTime <= self.view.config.COUNTDOWN_ALERT_TIME_THRESHOLD then
            isInAlert = true
            countdownNode.colorState:SetState("Alert")
            
            animationWrapper:Play(loopAnim)
            AudioAdapter.PostEvent("Au_UI_Toast_DungeonNormalTick")
        end

        
        if countDownType == GEnums.GameMechanicCountDownComponentType.TopLeftSmall then
            local success, mainHudCtrl = UIManager:IsOpen(PanelId.MainHud)
            if success then
                self.view.countdownTopLeftSmall.rectTransform.anchoredPosition = mainHudCtrl.view.topLeftBtns.topLeftBtnFollowerPositionNode.anchoredPosition
            end
        end
        

        if leftTime <= 0 then
            if cb then
                cb()
            end

            
            
            
            self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
        end
    end)
end




CommonTaskTrackCountdownCtrl.StartCounting = HL.Method(HL.Any) << function(self, arg)
    self:_ToggleComponentOn(Component.counting)

    arg = arg or { DateTimeUtils.GetCurrentTimestampByMilliseconds() }
    local startCountingTimestampMilli = unpack(arg)
    
    local curCounting = (DateTimeUtils.GetCurrentTimestampByMilliseconds() - startCountingTimestampMilli) / 1000
    self.view.counting.countingTxt.text = UIUtils.getLeftTimeToSecond(curCounting)

    local tickInterval = 0
    self.m_countDownTickId = LuaUpdate:Add("Tick", function(deltaTime)
        if self:_IsWorldFreeze() then
            return
        end

        tickInterval = tickInterval + deltaTime
        if tickInterval < UIConst.COMMON_UI_TIME_UPDATE_INTERVAL then
            return
        end

        tickInterval = 0
        curCounting = curCounting + UIConst.COMMON_UI_TIME_UPDATE_INTERVAL
        self.view.counting.countingTxt.text = UIUtils.getLeftTimeToSecond(curCounting)
    end)
end



CommonTaskTrackCountdownCtrl.OnCloseCommonTaskCountdown = HL.Method() << function(self)
    self:Close()
end



CommonTaskTrackCountdownCtrl.OnFinishCommonTaskCounting = HL.Method() << function(self)
    self:Close()
end






CommonTaskTrackCountdownCtrl.OnAddHeadBar = HL.Method(HL.Table) << function(self, args)
    local succ, ctrl = UIManager:IsOpen(PanelId.BattleBossInfo)
    if not succ then
        return
    end

    local targetAbilitySystem = unpack(args)
    if targetAbilitySystem and targetAbilitySystem.showBigHeadBar then
        if targetAbilitySystem.alive then
            self:_StartCoroutine(function()
                coroutine.step()
                local active, pos = ctrl:GetFollowPointPosition()
                if active then
                    DOTween.To(function()
                        return self.view.main.position
                    end, function(value)
                        self.view.main.position = value
                    end, pos, self.view.config.COUNTDOWN_TWEEN_TO_TARGET_DURATION)
                end
            end)
        else
            DOTween.To(function()
                return self.view.main.anchoredPosition
            end, function(value)
                self.view.main.anchoredPosition = value
            end, self.m_originalAnchoredPos, self.view.config.COUNTDOWN_TWEEN_TO_TARGET_DURATION)
        end
    end
end




CommonTaskTrackCountdownCtrl.OnRemoveHeadBar = HL.Method(HL.Table) << function(self, args)
    local targetAbilitySystem = unpack(args)
    if targetAbilitySystem and targetAbilitySystem.showBigHeadBar then
        DOTween.To(function()
            return self.view.main.anchoredPosition
        end, function(value)
            self.view.main.anchoredPosition = value
        end, self.m_originalAnchoredPos, self.view.config.COUNTDOWN_TWEEN_TO_TARGET_DURATION)
    end
end



HL.Commit(CommonTaskTrackCountdownCtrl)
