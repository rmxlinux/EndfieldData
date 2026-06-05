
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DeathInfo
local PHASE_ID = PhaseId.DeathInfo

local REVIVE_AI_BARK = "bark_battle_defeat"
local NORMAL_REVIVE_BTN_TEXT_KEY = "ui_common_deathinfo_revive"
local DUNGEON_REVIVE_BTN_TEXT_KEY = "ui_dungeon_reward_popup_try_again"





























DeathInfoCtrl = HL.Class('DeathInfoCtrl', uiCtrl.UICtrl)









DeathInfoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ALL_CHARACTER_REVIVE] = '_ExitPanel',
    [MessageConst.ON_DUNGEON_RESTART] = '_ExitPanel',
    [MessageConst.ON_LEAVE_DUNGEON] = 'OnLeaveDungeon',
}


DeathInfoCtrl.s_waitStartCoroutine = HL.StaticField(HL.Thread)





DeathInfoCtrl.ShowDeathInfo = HL.StaticMethod(HL.Any) << function(args)
    local deathInfo, dialogInfo = unpack(args)

    
    
    if Utils.isInSettlementDefense() then
        return
    end
    if WeeklyRaidUtils.IsInWeeklyRaid() or WeeklyRaidUtils.IsInWeeklyRaidIntro() then
        return
    end
    if not string.isEmpty(deathInfo.dungeonId) and DungeonUtils.isDungeonContract(deathInfo.dungeonId) then
        return
    end
    

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
    logger.info("DeathInfoCtrl.ShowDeathInfo: dialogType == " .. tostring(dialogInfo.dialogType))
    if dialogInfo.dialogType == CS.Beyond.Gameplay.DeathDialogSystem.DialogType.None then
        logger.info("DeathInfoCtrl: dialogType == None, 什么也不弹.")
        return
    elseif dialogInfo.dialogType == CS.Beyond.Gameplay.DeathDialogSystem.DialogType.Default then
        PhaseManager:OpenPhase(PHASE_ID, {deathInfo, dialogInfo}, nil, true)
    elseif dialogInfo.dialogType == CS.Beyond.Gameplay.DeathDialogSystem.DialogType.AutoRestart then
        
        PhaseManager:OpenPhase(PHASE_ID, {deathInfo, dialogInfo}, nil, true)
    else
        logger.error("DeathInfoCtrl: 有没实现的dialogType " .. tostring(dialogInfo.dialogType))
        return
    end
end




DeathInfoCtrl.DoRetry = HL.StaticMethod(HL.Any, HL.Any) << function(deathInfo, dialogInfo)
    if dialogInfo.retryBtnCallback then
        dialogInfo.retryBtnCallback()
    elseif not deathInfo.dungeonId then
        
        GameInstance.gameplayNetwork:SendRevive(true)
    else
        local dungeonId = deathInfo.dungeonId
        local dungeonData = Tables.GameMechanicTable[dungeonId]
        local dungeonCategory = nil
        local dungeonCategoryData = nil
        if dungeonData then
            dungeonCategory = dungeonData.gameCategory
        end
        if dungeonCategory then
            dungeonCategoryData = Tables.GameMechanicCategoryTable[dungeonCategory]
        end
        if dungeonCategoryData and dungeonCategoryData.canReChallengeAfterFail then
            GameInstance.dungeonManager.curDungeonLikeSubGame:SendReStart(true)
        end
    end
end




DeathInfoCtrl.DoLeave = HL.StaticMethod(HL.Any, HL.Any) << function(deathInfo, dialogInfo)
    if dialogInfo.leaveBtnCallback then
        dialogInfo.leaveBtnCallback()
    elseif deathInfo.dungeonId then
        GameInstance.dungeonManager:LeaveDungeon()
    end
end






DeathInfoCtrl.m_leaveTick = HL.Field(HL.Number) << -1


DeathInfoCtrl.m_deathInfo = HL.Field(CS.Beyond.Gameplay.DeathInfo)


DeathInfoCtrl.m_dialogInfo = HL.Field(CS.Beyond.Gameplay.DeathDialogSystem.DialogInfo)


DeathInfoCtrl.m_retryCallback = HL.Field(HL.Function)









DeathInfoCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    GameInstance.player.guide:OnOpenDeathInfoPanel()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    local deathInfo, dialogInfo = unpack(arg)
    self.m_deathInfo = deathInfo
    self.m_dialogInfo = dialogInfo

    self:_BindUICallback()

    
    if dialogInfo.dialogType == CS.Beyond.Gameplay.DeathDialogSystem.DialogType.AutoRestart then
        self.view.content.gameObject:SetActive(false)
        local maskData = UIUtils.genDynamicBlackScreenMaskData("DeathInfo", 0.5, 0.5)
        maskData.waitHide = true 
        GameAction.ShowBlackScreen(maskData)
        DeathInfoCtrl.DoRetry(deathInfo, dialogInfo)
        return
    else
        self.view.content.gameObject:SetActive(true)
    end

    self:_SetupUI()
end








DeathInfoCtrl.OnClose = HL.Override() << function(self)
    self:_FinishCountdownCoroutine()
end







DeathInfoCtrl._OnClickRetryBtn = HL.Method() << function(self)
    DeathInfoCtrl.DoRetry(self.m_deathInfo, self.m_dialogInfo)
end



DeathInfoCtrl._OnClickLeaveBtn = HL.Method() << function(self)
    DeathInfoCtrl.DoLeave(self.m_deathInfo, self.m_dialogInfo)
end




DeathInfoCtrl._ExitPanel = HL.Method(HL.Opt(HL.Any)) << function(self, args)
    if PhaseManager:IsOpen(PHASE_ID) then
        if self.m_dialogInfo.dialogType == CS.Beyond.Gameplay.DeathDialogSystem.DialogType.AutoRestart then
            local fadeOutData = CS.Beyond.Gameplay.UICommonMaskData()
            fadeOutData.fadeType = UIConst.UI_COMMON_MASK_FADE_TYPE.FadeOut
            fadeOutData.fadeOutTime = 0.5
            GameAction.ShowBlackScreen(fadeOutData)
        end

        PhaseManager:ExitPhaseFast(PHASE_ID)
        GameAction.PostAIBarkEvent(REVIVE_AI_BARK)
    end
end




DeathInfoCtrl.OnLeaveDungeon = HL.Method(HL.Table) << function(self, args)
    
    GameAction.PostAIBarkEvent(REVIVE_AI_BARK)
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
    self.view.exitDungeonBtn.gameObject:SetActive(false)
    self.view.countdownText.gameObject:SetActive(false)

    if self.m_dialogInfo.leaveBtnCallback or self.m_deathInfo.dungeonId then
        self.view.exitDungeonBtn.gameObject:SetActive(true)
    end

    if self.m_dialogInfo.retryBtnCallback then
        self.view.retryBattleBtn.gameObject:SetActive(true)
    end

    if self.m_dialogInfo.triggerLeaveBtnTimestamp ~= 0 then
        self.view.countdownText.gameObject:SetActive(true)
        self.m_leaveTick = LuaUpdate:Add("LateTick", function(deltaTime)
            local leftTime = self.m_dialogInfo.triggerLeaveBtnTimestamp - DateTimeUtils.GetCurrentTimestampBySeconds()
            if leftTime >= 0 then
                self.view.countdownText:SetAndResolveTextStyle(leftTime .. Language.LUA_LEAVE_DUNGEON_TEXT)
            else
                self:_OnClickLeaveBtn()
            end
        end)
    elseif self.m_deathInfo.dungeonId then
        local _, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_deathInfo.dungeonId)
        local mechanicsType = subGameData and subGameData.gameMechanicsType
        if mechanicsType ~= GEnums.GameMechanicsType.DungeonChar
            and mechanicsType ~= GEnums.GameMechanicsType.DungeonStory then
            self.view.countdownText.gameObject:SetActive(true)
            self.m_leaveTick = DungeonUtils.startSubGameLeaveTick(function(leftTime)
                self.view.countdownText:SetAndResolveTextStyle(leftTime .. Language.LUA_LEAVE_DUNGEON_TEXT)
            end)
        end
    end
end







DeathInfoCtrl._SetupUI = HL.Method() << function(self)
    
    self.view.tipNode02.gameObject:SetActive(false)

    
    self.view.trainingTips.gameObject:SetActive(false)
    local _, trainingStd = Tables.recommendTraining:TryGetValue(self.m_deathInfo.enemyLv)
    if trainingStd then
        
        local checkTypeInOrder = {}
        for _, trainingTypeInfo in pairs(Cfg.Tables.trainingTypeInfoTable) do
            checkTypeInOrder[trainingTypeInfo.priority] = trainingTypeInfo
        end
        
        for priority = 1, #checkTypeInOrder do
            if self:_TryShowTrainingTip(trainingStd, checkTypeInOrder[priority], self.m_deathInfo) then
                break
            end
        end
    end

    self:_SetupActionButtons()

    if self:_TryShowInDungeonMode(self.m_deathInfo) then
        return
    end

    if self:_TryShowInEnemyMode(self.m_deathInfo) then
        return
    end

    
    self:_TryRandomShowTwoTips(Tables.commonDeathTips, 0)
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.commonTipsHeader.gameObject:SetActive(true)
end




DeathInfoCtrl._TryShowInDungeonMode = HL.Method(CS.Beyond.Gameplay.DeathInfo).Return(HL.Boolean) << function(self, deathInfo)
    
    local dungeonId = deathInfo.dungeonId
    if not dungeonId then
        self.view.reviveBtnText.text = I18nUtils.GetText(NORMAL_REVIVE_BTN_TEXT_KEY)
        return false
    end
    
    self.view.reviveBtnText.text = I18nUtils.GetText(DUNGEON_REVIVE_BTN_TEXT_KEY)
    local dungeonData = Tables.GameMechanicTable[dungeonId]
    local dungeonCategory = nil
    local dungeonCategoryData = nil
    if dungeonData then
        dungeonCategory = dungeonData.gameCategory
    end
    if dungeonCategory then
        dungeonCategoryData = Tables.GameMechanicCategoryTable[dungeonCategory]
    end
    if self.m_dialogInfo.retryBtnCallback or (dungeonCategoryData and dungeonCategoryData.canReChallengeAfterFail) then
        self.view.retryBattleBtn.gameObject:SetActive(true)
    else
        self.view.retryBattleBtn.gameObject:SetActive(false)
    end

    
    local _, tipGroupBean = Tables.dungeonDeathTips:TryGetValue(dungeonId)
    if not tipGroupBean then
        return false;
    end
    if not self:_TryRandomShowTwoTips(tipGroupBean.tipContents, -1) then
        return false
    end
    self.view.enemyTipsHeader.gameObject:SetActive(false)
    self.view.commonTipsHeader.gameObject:SetActive(true)
    return true
end




DeathInfoCtrl._TryShowInEnemyMode = HL.Method(CS.Beyond.Gameplay.DeathInfo).Return(HL.Boolean) << function(self, deathInfo)
    
    if not deathInfo.enemyId or deathInfo.enemyLv < 0 then
        return false
    end

    
    local _, tipGroupBean = Tables.enemyRelatedDeathTips:TryGetValue(deathInfo.enemyId)
    if not tipGroupBean then
        return false;
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