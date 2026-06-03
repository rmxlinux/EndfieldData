local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonTaskTrackCountdown

local Component = {
    countdownTopBig = 1,
    countdownTopLeftSmall = 2,
    countingTopBig = 3,
    countingTopLeftSmall = 4,
}

local countDownTypeTable = {
    [GEnums.GameMechanicCountDownComponentType.TopBig] = {
        countDownType = Component.countdownTopBig,
        countingType = Component.countingTopBig,
        prepareAction = "_TopBigCountdownPrepareAction",
        tickAction = "_TopBigCountdownTickAction",
    },
    [GEnums.GameMechanicCountDownComponentType.TopLeftSmall] = {
        countDownType = Component.countdownTopLeftSmall,
        countingType = Component.countingTopLeftSmall,
        prepareAction = "_TopLeftSmallCountdownPrepareAction",
        tickAction = "_TopLeftSmallCountdownTickAction",
    },
}

local maintainPanelCategoryList = {
    DungeonConst.DUNGEON_CATEGORY.BossRush,
}




























CommonTaskTrackCountdownCtrl = HL.Class('CommonTaskTrackCountdownCtrl', uiCtrl.UICtrl)


CommonTaskTrackCountdownCtrl.m_countDownTickId = HL.Field(HL.Number) << -1


CommonTaskTrackCountdownCtrl.m_isInAlter = HL.Field(HL.Boolean) << false


CommonTaskTrackCountdownCtrl.m_countingTickId = HL.Field(HL.Number) << -1


CommonTaskTrackCountdownCtrl.m_countingFollowTickId = HL.Field(HL.Number) << -1


CommonTaskTrackCountdownCtrl.m_originalAnchoredPos = HL.Field(Vector2)






CommonTaskTrackCountdownCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CLOSE_COMMON_TASK_COUNTDOWN] = "OnCloseCommonTaskCountdown",
    [MessageConst.ON_FINISH_COMMON_TASK_COUNTING] = "OnFinishCommonTaskCounting",

    [MessageConst.ON_DUNGEON_COMPLETE] = "OnDungeonComplete",
    [MessageConst.ON_SUB_GAME_RESET] = "OnSubGameReset",

    
    
}



CommonTaskTrackCountdownCtrl.OnShowCommonTaskCountdown = HL.StaticMethod(HL.Any) << function(args)
    
    local ctrl = CommonTaskTrackCountdownCtrl.AutoOpen(PANEL_ID, args, true)
    ctrl:ShowCountdown(args)
end



CommonTaskTrackCountdownCtrl.OnStartCommonTaskCounting = HL.StaticMethod(HL.Any) << function(args)
    
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

    if self.m_countingFollowTickId > 0 then
        self.m_countingFollowTickId = LuaUpdate:Remove(self.m_countingFollowTickId)
    end
end




CommonTaskTrackCountdownCtrl._ToggleComponentOn = HL.Method(HL.Number) << function(self, component)
    self.view.countdown.gameObject:SetActiveIfNecessary(component == Component.countdownTopBig)
    self.view.countdownTopLeftSmall.gameObject:SetActiveIfNecessary(component == Component.countdownTopLeftSmall)
    self.view.countingTopLeftSmall.gameObject:SetActiveIfNecessary(component == Component.countingTopLeftSmall)
    self.view.counting.gameObject:SetActiveIfNecessary(component == Component.countingTopBig)
end




CommonTaskTrackCountdownCtrl._GetCountingComponentNode = HL.Method(HL.Number).Return(HL.Any) << function(self, componentType)
    if componentType == Component.countingTopLeftSmall then
        return self.view.countingTopLeftSmall
    else
        return self.view.counting
    end
end



CommonTaskTrackCountdownCtrl._IsWorldFreeze = HL.Method().Return(HL.Boolean) << function(self)
    local game = GameWorld.worldInfo.subGame
    return game ~= nil and game.clientPaused
end



CommonTaskTrackCountdownCtrl._TopBigCountdownPrepareAction = HL.Method() << function(self)
    local node = self.view.countdown
    node.stateController:SetState("Normal")
end



CommonTaskTrackCountdownCtrl._TopLeftSmallCountdownPrepareAction = HL.Method() << function(self)
    local node = self.view.countdownTopLeftSmall
    node.stateController:SetState("Normal")
end






CommonTaskTrackCountdownCtrl._TopBigCountdownTickAction = HL.Method(HL.Number, HL.Number, HL.Boolean)
        << function(self, leftTime, duration, needAlterAudio)
    local node = self.view.countdown
    node.countDownTxt.text = UIUtils.getLeftTimeToSecond(math.max(0, leftTime))
    node.fill.fillAmount = leftTime / duration

    if not self.m_isInAlter and leftTime <= self.view.config.COUNTDOWN_ALERT_TIME_THRESHOLD then
        self.m_isInAlter = true
        node.stateController:SetState("Alert")
        self.animationWrapper:Play("tasktrackcountdown_loop")
    end

    if needAlterAudio then
        AudioAdapter.PostEvent("Au_UI_Toast_TickDown_OS")
    end
end






CommonTaskTrackCountdownCtrl._TopLeftSmallCountdownTickAction = HL.Method(HL.Number, HL.Number, HL.Boolean)
        << function(self, leftTime, duration, needAlterAudio)
    local node = self.view.countdownTopLeftSmall
    node.countDownTxt.text = UIUtils.getLeftTimeToSecond(math.max(0, leftTime))

    if not self.m_isInAlter and leftTime <= self.view.config.COUNTDOWN_ALERT_TIME_THRESHOLD then
        self.m_isInAlter = true
        node.stateController:SetState("Alert")
        node.animationWrapper:Play("tasktrackcountdown_topleft_red")
    end

    if needAlterAudio then
        AudioAdapter.PostEvent("Au_UI_Toast_DungeonNormalTick_OS")
    end

    local success, mainHudCtrl = UIManager:IsOpen(PanelId.MainHud)
    if success then
        mainHudCtrl.view.topLeftBtns.topLeftBtnFollowerPositionNode.gameObject:SetActiveIfNecessary(true)
        local targetPos = mainHudCtrl.view.topLeftBtns.topLeftBtnFollowerPositionNode.anchoredPosition
        node.transform.anchoredPosition = targetPos
    end
end




CommonTaskTrackCountdownCtrl.ShowCountdown = HL.Method(HL.Any) << function(self, arg)
    local countDownType, countdownDurationMilli, expireTimestampMilli, cb = unpack(arg)
    local countDownCfg = countDownTypeTable[countDownType]
    self:_ToggleComponentOn(countDownCfg.countDownType)
    self[countDownCfg.prepareAction](self)

    local countdownDuration = countdownDurationMilli / 1000
    local lastLeftTime = countdownDuration
    self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
    self.m_countDownTickId = LuaUpdate:Add("Tick", function(deltaTime)
        local game = GameWorld.worldInfo.subGame
        if game == nil or game.waitingSrvResume then
            return
        end

        local leftTime = game:GetRealEndGameTimestampForLua() - DateTimeUtils.GetCurrentTimestampBySeconds()
        if leftTime > lastLeftTime then
            
            
            leftTime = lastLeftTime
        end

        local needAlterAudio = leftTime <= self.view.config.COUNTDOWN_ALERT_TIME_THRESHOLD and lastLeftTime ~= leftTime
        lastLeftTime = leftTime
        self[countDownCfg.tickAction](self, leftTime, countdownDuration, needAlterAudio)

        if leftTime <= 0 then
            if cb then
                cb()
            end

            
            
            
            self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
        end
    end)

end




CommonTaskTrackCountdownCtrl.StartCounting = HL.Method(HL.Any) << function(self, arg)
    local countDownType, startCountingTimestampMilli, startFreezeOffset = unpack(arg)
    local countDownCfg = countDownTypeTable[countDownType]
    self:_ToggleComponentOn(countDownCfg.countingType)
    local countingNode = self:_GetCountingComponentNode(countDownCfg.countingType)

    local startTs = startCountingTimestampMilli
    local lastCounting = 0
    self.m_countingTickId = LuaUpdate:Remove(self.m_countingTickId)
    self.m_countingTickId = LuaUpdate:Add("Tick", function(deltaTime)
        if self:_IsWorldFreeze() then
            return
        end

        local game = GameWorld.worldInfo.subGame
        if game == nil or game.waitingSrvResume then
            return
        end

        local curTs = DateTimeUtils.GetCurrentTimestampByMilliseconds()
        local succ, curFreezeTime = GameWorld.worldInfo.subGame.freezeTimeLut:TryGetValue(GEnums.GameInstTimeFreezeKey.ChallengeTime)
        local freezeOffset = (succ and curFreezeTime or startFreezeOffset) - startFreezeOffset
        local curDuration = curTs - startTs - freezeOffset
        
        curDuration = curDuration < 0 and 0 or curDuration
        
        if curDuration < lastCounting then
            return
        end

        lastCounting = curDuration
        countingNode.countingTxt.text = UIUtils.getLeftTimeToSecond(math.floor(curDuration / 1000))
    end)

    self.m_countingFollowTickId = LuaUpdate:Remove(self.m_countingFollowTickId)
    self.m_countingFollowTickId = LuaUpdate:Add("Tick", function(deltaTime)
        
        if countDownType == GEnums.GameMechanicCountDownComponentType.TopLeftSmall then
            local success, mainHudCtrl = UIManager:IsOpen(PanelId.MainHud)
            if success then
                mainHudCtrl.view.topLeftBtns.topLeftBtnFollowerPositionNode.gameObject:SetActiveIfNecessary(true)
                local targetPos = mainHudCtrl.view.topLeftBtns.topLeftBtnFollowerPositionNode.anchoredPosition
                countingNode.transform.anchoredPosition = targetPos
            end
        end
    end)
end




CommonTaskTrackCountdownCtrl.OnCloseCommonTaskCountdown = HL.Method() << function(self)
    self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
    if self:_MaintainPanel() then
        return
    end
    self:Close()
end



CommonTaskTrackCountdownCtrl.OnFinishCommonTaskCounting = HL.Method() << function(self)
    self.m_countingTickId = LuaUpdate:Remove(self.m_countingTickId)
    if self:_MaintainPanel() then
        return
    end
    self:Close()
end



CommonTaskTrackCountdownCtrl._MaintainPanel = HL.Method().Return(HL.Boolean) << function(self)
    local subGameId = GameWorld.worldInfo.curSubGameId
    if string.isEmpty(subGameId) then
        return false
    end

    local succ, gameMechanicsCfg = Tables.gameMechanicTable:TryGetValue(subGameId)
    if not succ then
        return false
    end

    return lume.find(maintainPanelCategoryList, gameMechanicsCfg.gameCategory) ~= nil
end




CommonTaskTrackCountdownCtrl.OnDungeonComplete = HL.Method(HL.Table) << function(self, args)
    local subGameId = GameWorld.worldInfo.curSubGameId
    if string.isEmpty(subGameId) then
        return
    end

    local succ, subGameData = DataManager.subGameInstDataTable:TryGetValue(subGameId)
    if not succ then
        return
    end

    local countDownType = subGameData.countDownType
    local countDownCfg = countDownTypeTable[countDownType]
    local countingNode = self:_GetCountingComponentNode(countDownCfg.countingType)

    
    local isNewTimeRecord, curGameTimeRecord = unpack(args)
    countingNode.countingTxt.text = UIUtils.getLeftTimeToSecond(math.floor(curGameTimeRecord / 1000))
end



CommonTaskTrackCountdownCtrl.OnSubGameReset = HL.Method() << function(self)
    self:Hide()
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
