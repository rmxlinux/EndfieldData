
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DeathInfo
local PHASE_ID = PhaseId.DeathInfo

local REVIVE_AI_BARK = "bark_battle_defeat"
local NORMAL_REVIVE_BTN_TEXT_KEY = "ui_common_deathinfo_revive"
local DUNGEON_REVIVE_BTN_TEXT_KEY = "ui_dungeon_reward_popup_try_again"
local DisplayMode = CS.Beyond.Gameplay.Core.DeathPerformance.CommonDeathPanelDisplayMode




DeathInfoCtrl = HL.Class('DeathInfoCtrl', uiCtrl.UICtrl)




DeathInfoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ALL_CHARACTER_REVIVE] = '_ExitPanel',
    [MessageConst.ON_DUNGEON_RESTART] = '_ExitPanel',
    [MessageConst.ON_LEAVE_DUNGEON] = 'OnLeaveDungeon',
    [MessageConst.ON_DUNGEON_FAIL_LEAVE_TO_ENTRY_PANEL] = 'OnDungeonFailLeaveToEntryPanel',
}

DeathInfoCtrl.s_waitStartCoroutine = HL.StaticField(HL.Thread)



DeathInfoCtrl.ShowDeathInfo = HL.StaticMethod(HL.Any) << function(args)
    local deathInfo, dialogInfo = unpack(args)
    EventLogManagerInst:GameEvent_TeamDead(dialogInfo.displayMode:GetHashCode())

    if not string.isEmpty(GameInstance.player.systemActionConflictManager.curProcessingSystemAction) then
        if DeathInfoCtrl.s_waitStartCoroutine == nil then
            DeathInfoCtrl.s_waitStartCoroutine = CoroutineManager:StartCoroutine(function()
                while true do
                    coroutine.step()
                    if string.isEmpty(GameInstance.player.systemActionConflictManager.curProcessingSystemAction) then
                        CoroutineManager:ClearCoroutine(DeathInfoCtrl.s_waitStartCoroutine)
                        DeathInfoCtrl.s_waitStartCoroutine = nil
                        DeathInfoCtrl.DoShowDeathInfo(deathInfo, dialogInfo)
                        break
                    end
                end
            end)
        end
    else
        DeathInfoCtrl.DoShowDeathInfo(deathInfo, dialogInfo)
    end
end

DeathInfoCtrl.DoShowDeathInfo = HL.StaticMethod(HL.Any, HL.Any) << function(deathInfo, dialogInfo)
    PhaseManager:OpenPhase(PHASE_ID, {deathInfo, dialogInfo}, nil, true)
end

DeathInfoCtrl.DoRetry = HL.StaticMethod(HL.Any, HL.Any) << function(deathInfo, dialogInfo)
    if dialogInfo.retryBtnCallback then
        dialogInfo.retryBtnCallback()
    end
end

DeathInfoCtrl.DoLeave = HL.StaticMethod(HL.Any, HL.Any) << function(deathInfo, dialogInfo)
    if dialogInfo.leaveBtnCallback then
        dialogInfo.leaveBtnCallback()
    end
end





DeathInfoCtrl.m_leaveTick = HL.Field(HL.Number) << -1

DeathInfoCtrl.m_deathInfo = HL.Field(CS.Beyond.Gameplay.Core.DeathPerformance.DeathInfo)

DeathInfoCtrl.m_dialogInfo = HL.Field(CS.Beyond.Gameplay.Core.DeathPerformance.DialogInfo)

DeathInfoCtrl.m_starCells = HL.Field(HL.Any) << nil





DeathInfoCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    GameInstance.player.guide:OnOpenDeathInfoPanel()

    local deathInfo, dialogInfo = unpack(arg)
    self.m_deathInfo = deathInfo
    self.m_dialogInfo = dialogInfo

    self:_BindUICallback()
    self.view.content.gameObject:SetActive(true)
    self:_SetupUI()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

DeathInfoCtrl.OnClose = HL.Override() << function(self)
    self:_FinishCountdownCoroutine()
    if self.m_dialogInfo and self.m_dialogInfo.onPanelClosed then
        self.m_dialogInfo.onPanelClosed()
        self.m_dialogInfo.onPanelClosed = nil
    end
end





DeathInfoCtrl._OnClickRetryBtn = HL.Method() << function(self)
    DeathInfoCtrl.DoRetry(self.m_deathInfo, self.m_dialogInfo)
end

DeathInfoCtrl._OnClickLeaveBtn = HL.Method() << function(self)
    DeathInfoCtrl.DoLeave(self.m_deathInfo, self.m_dialogInfo)
end

DeathInfoCtrl._ExitPanel = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if PhaseManager:IsOpen(PHASE_ID) then
        PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
        GameAction.PostAIBarkEvent(REVIVE_AI_BARK)
    end
end

DeathInfoCtrl.OnLeaveDungeon = HL.Method(HL.Table) << function(self, args)
    GameAction.PostAIBarkEvent(REVIVE_AI_BARK)
end


DeathInfoCtrl.OnDungeonFailLeaveToEntryPanel = HL.Method(HL.Any) << function(self, args)
    local dungeonId = unpack(args)
    self:_FinishCountdownCoroutine()
    PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
    DungeonUtils.onDungeonLeaveToEntryPanel(dungeonId)
end





DeathInfoCtrl._FinishCountdownCoroutine = HL.Method() << function(self)
    if self.m_leaveTick >= 0 then
        LuaUpdate:Remove(self.m_leaveTick)
        self.m_leaveTick = -1
    end
end

DeathInfoCtrl._BindUICallback = HL.Method() << function(self)
    self.view.retryBattleBtn.onClick:AddListener(function()
        self:_OnClickRetryBtn()
    end)

    self.view.exitDungeonBtn.onClick:AddListener(function()
        self:_OnClickLeaveBtn()
    end)
end

DeathInfoCtrl._SetupActionButtons = HL.Method() << function(self)
    local dialogInfo = self.m_dialogInfo

    self.view.retryBattleBtn.gameObject:SetActive(dialogInfo.retryBtnCallback ~= nil)
    self.view.exitDungeonBtn.gameObject:SetActive(dialogInfo.leaveBtnCallback ~= nil)

    if dialogInfo.retryBtnCallback ~= nil then
        local onlyRetry = dialogInfo.leaveBtnCallback == nil
        self.view.retryBattleBtn.onClick:ChangeBindingPlayerAction(onlyRetry and "dungeon_fail_confirm" or "dungeon_fail_retry")
    end

    local showCountdown = (dialogInfo.displayMode == DisplayMode.DungeonFail and self:_ShouldShowLeaveCountdown())
        or dialogInfo.displayMode == DisplayMode.Parkour
    if showCountdown then
        self.view.countdownText.gameObject:SetActive(true)
        self.m_leaveTick = DungeonUtils.startSubGameLeaveTick(function(leftTime)
            self.view.countdownText:SetAndResolveTextStyle(leftTime .. Language.LUA_LEAVE_DUNGEON_TEXT)
        end)
    else
        self.view.countdownText.gameObject:SetActive(false)
    end
end



DeathInfoCtrl._ShouldShowLeaveCountdown = HL.Method().Return(HL.Boolean) << function(self)
    local dungeonId = self.m_deathInfo.dungeonId
    if not dungeonId then
        return false
    end
    local game = GameInstance.dungeonManager.curDungeonLikeSubGame
    if game == nil or game.id ~= dungeonId then
        return false
    end
    return game.state == CS.Beyond.Gameplay.Core.ISubGame.SubGameState.Failed
        and game.rawLeaveTimestamp ~= 0
end



DeathInfoCtrl._SetupUI = HL.Method() << function(self)
    local deathInfo = self.m_deathInfo
    local dialogInfo = self.m_dialogInfo

    self.view.tipNode02.gameObject:SetActive(false)
    self.view.scrollViewTipsList.gameObject:SetActive(true)
    self.view.timeLimitExceededNode.gameObject:SetActive(false)
    self.view.taskGoalsNode.gameObject:SetActive(false)

    
    self.view.trainingTips.gameObject:SetActive(false)
    local _, trainingStd = Tables.recommendTraining:TryGetValue(deathInfo.enemyLv)
    if trainingStd then
        local checkTypeInOrder = {}
        for _, trainingTypeInfo in pairs(Cfg.Tables.trainingTypeInfoTable) do
            checkTypeInOrder[trainingTypeInfo.priority] = trainingTypeInfo
        end
        for priority = 1, #checkTypeInOrder do
            if self:_TryShowTrainingTip(trainingStd, checkTypeInOrder[priority], deathInfo) then
                break
            end
        end
    end

    self:_SetupActionButtons()

    local mode = dialogInfo.displayMode
    if mode == DisplayMode.Miasma then
        self:_ShowMiasmaTips()
        self.view.titleTxt.text = Language.ui_msc_miasma_died_title
    elseif mode == DisplayMode.Parkour then
        self.view.reviveBtnText.text = I18nUtils.GetText(DUNGEON_REVIVE_BTN_TEXT_KEY)
        self:_ShowParkourMode()
    elseif mode == DisplayMode.DungeonFail then
        self.view.reviveBtnText.text = I18nUtils.GetText(DUNGEON_REVIVE_BTN_TEXT_KEY)
        local dungeonId = deathInfo.dungeonId
        if DungeonUtils.isDungeonArchery(dungeonId) then
            self:_ShowTyphoeaArcheryMode()
        end
        if not self:_TryShowDungeonTips(dungeonId) then
            if not self:_TryShowEnemyTips(deathInfo) then
                self:_ShowCommonTips()
            end
        end
    else
        self.view.reviveBtnText.text = I18nUtils.GetText(NORMAL_REVIVE_BTN_TEXT_KEY)
        if not self:_TryShowEnemyTips(deathInfo) then
            self:_ShowCommonTips()
        end
    end
end

DeathInfoCtrl._ShowTyphoeaArcheryMode = HL.Method() << function(self)
    self.view.taskGoalsNode.gameObject:SetActive(true)
    self.view.scrollViewTipsList.gameObject:SetActive(true)
    self.view.trainingTips.gameObject:SetActive(false)
    self.view.exitDungeonBtn.gameObject:SetActive(true)

    local params = {}
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_deathInfo.dungeonId)
    
    if success and subGameData.extraTasks.Count > 1 then
        local extraTasks = trackingMgr.extraTasks
        for i = 0, extraTasks.Count - 1 do
            table.insert(params, {
                taskKey = extraTasks[i].taskKey,
                objectiveIndex = 1,
                taskType = CS.Beyond.Gameplay.LevelScriptTaskType.Extra,
                forceFail = true,
            })
        end
    else
        local mainTask = trackingMgr.mainTask
        if mainTask then
            local goalCount = mainTask.objectives.Length
            for i = 1, goalCount do
                table.insert(params, {
                    taskKey = mainTask.taskKey,
                    objectiveIndex = i,
                    taskType = CS.Beyond.Gameplay.LevelScriptTaskType.Main,
                    forceFail = true,
                })
            end
        end
    end

    DungeonUtils.initGameSettlementTaskInfoNode(self.view, params)
    self.view.tasksTitleTxt.text = Language["ui_archery_train_end_target"]
end

DeathInfoCtrl._ShowParkourMode = HL.Method() << function(self)
    self.view.timeLimitExceededNode.gameObject:SetActive(true)
    self.view.taskGoalsNode.gameObject:SetActive(true)
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.scrollViewTipsList.gameObject:SetActive(false)
    self.view.trainingTips.gameObject:SetActive(false)
    self.view.exitDungeonBtn.gameObject:SetActive(true)
    self.m_starCells = UIUtils.genCellCache(self.view.commonTaskGoalCell)
    local trackingMgr = GameWorld.levelScriptTaskTrackingManager
    local extraTasks = trackingMgr.extraTasks

    self.m_starCells:Refresh(extraTasks.Count, function(cell, luaIndex)
        local taskKey = extraTasks[CSIndex(luaIndex)].taskKey
        cell:InitCommonTaskGoalCell(taskKey, 1, CS.Beyond.Gameplay.LevelScriptTaskType.Extra)
    end)
end

DeathInfoCtrl._ShowMiasmaTips = HL.Method() << function(self)
    if not self:_TryRandomShowTwoTips(Tables.miasmaDeathTips, 0) then
        self:_ShowCommonTips()
    end
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.commonTipsHeader.gameObject:SetActive(true)
end

DeathInfoCtrl._TryShowDungeonTips = HL.Method(HL.String).Return(HL.Boolean) << function(self, dungeonId)
    local _, tipGroupBean = Tables.dungeonDeathTips:TryGetValue(dungeonId)
    if not tipGroupBean then
        return false
    end
    if not self:_TryRandomShowTwoTips(tipGroupBean.tipContents, -1) then
        return false
    end
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.commonTipsHeader.gameObject:SetActive(true)
    return true
end

DeathInfoCtrl._TryShowEnemyTips = HL.Method(CS.Beyond.Gameplay.Core.DeathPerformance.DeathInfo).Return(HL.Boolean) << function(self, deathInfo)
    if not deathInfo.enemyId or deathInfo.enemyLv < 0 then
        return false
    end
    local _, tipGroupBean = Tables.enemyRelatedDeathTips:TryGetValue(deathInfo.enemyId)
    if not tipGroupBean then
        return false
    end
    if not self:_TryRandomShowTwoTips(tipGroupBean.tipContents, -1) then
        return false
    end
    local enemyInfo = UIUtils.getEnemyInfoByIdAndLevel(deathInfo.enemyId, deathInfo.enemyLv)
    self.view.enemyTipsHeader.gameObject:SetActive(true)
    self.view.commonTipsHeader.gameObject:SetActive(false)
    self.view.enemyAvatar:LoadSprite(UIConst.UI_SPRITE_MONSTER_ICON_BIG, enemyInfo.templateId)
    self.view.enemyNameText.text = enemyInfo.name
    return true
end

DeathInfoCtrl._ShowCommonTips = HL.Method() << function(self)
    self:_TryRandomShowTwoTips(Tables.commonDeathTips, 0)
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.commonTipsHeader.gameObject:SetActive(true)
end

DeathInfoCtrl._TryRandomShowTwoTips = HL.Method(HL.Userdata, HL.Number).Return(HL.Boolean) << function(self, tipGroup, indexOffset)
    if not tipGroup or #tipGroup == 0 then
        return false
    end
    local tipIndex1 = math.random(#tipGroup)
    self.view.tipText01:SetAndResolveTextStyle(tipGroup[tipIndex1 + indexOffset])
    if #tipGroup == 1 then
        return true
    end
    self.view.tipNode02.gameObject:SetActive(true)
    local tipIndex2 = math.random(#tipGroup - 1)
    if tipIndex2 >= tipIndex1 then
        tipIndex2 = tipIndex2 + 1
    end
    self.view.tipText02:SetAndResolveTextStyle(tipGroup[tipIndex2 + indexOffset])
    return true
end

DeathInfoCtrl._TryGetRandomTrainingTip = HL.Method(HL.String).Return(HL.String) << function(self, trainingType)
    local trainingTipGroupWrapper = Tables.trainingDeathTips[trainingType]
    if not trainingTipGroupWrapper then
        return nil
    end
    local tipGroup = trainingTipGroupWrapper.tipContents
    if not tipGroup or #tipGroup == 0 then
        return nil
    end
    local tipIndex = CSIndex(math.random(#tipGroup))
    return tipGroup[tipIndex]
end

DeathInfoCtrl._TryShowTrainingTip = HL.Method(HL.Userdata, HL.Userdata, HL.Userdata).Return(HL.Boolean) << function(self, trainingStd, trainingTypeInfo, deathInfo)
    local trainingType = trainingTypeInfo.trainingType
    if not trainingStd[trainingType] or trainingStd[trainingType] <= 0 then
        return false
    end
    local trainingStdOfType = trainingStd[trainingType]
    if not trainingStdOfType or trainingStdOfType <= 0 then
        return false
    end
    local degree = deathInfo[trainingType] / trainingStdOfType
    if degree >= trainingTypeInfo.trainingThresholdFactor then
        return false
    end
    local candidateTip = self:_TryGetRandomTrainingTip(trainingType)
    if not candidateTip then
        return false
    end
    self.view.trainingTips.gameObject:SetActive(true)
    self.view.trainingTipText:SetAndResolveTextStyle(candidateTip)
    self.view.trainingProgressBarLabel.text = trainingTypeInfo.progressBarLabel
    self.view.trainingProgress.fillAmount = degree
    return true
end



HL.Commit(DeathInfoCtrl)
