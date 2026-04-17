local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonActivityEntry
local PHASE_ID = PhaseId.DungeonEntry


















DungeonActivityEntryCtrl = HL.Class('DungeonActivityEntryCtrl', uiCtrl.UICtrl)


DungeonActivityEntryCtrl.m_genCells = HL.Field(HL.Forward("UIListCache"))


DungeonActivityEntryCtrl.m_rewardCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonActivityEntryCtrl.m_selectedDungeonId = HL.Field(HL.String) << ""


DungeonActivityEntryCtrl.m_dungeonSeriesId = HL.Field(HL.String) << ""


DungeonActivityEntryCtrl.m_activityId = HL.Field(HL.String) << ""


DungeonActivityEntryCtrl.m_fromDialog = HL.Field(HL.Boolean) << false


DungeonActivityEntryCtrl.m_args = HL.Field(HL.Table)


DungeonActivityEntryCtrl.m_cellRefreshFunc = HL.Field(HL.Function)






DungeonActivityEntryCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SC_MULTI_STAGE_ACTIVITY_GAIN_REWARD] = 'OnGainMultiStageActivityReward',
    
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdated',
    [MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE] = 'OnActivityUpdated',
}





DungeonActivityEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_args = arg

    self.m_fromDialog = arg ~= nil and arg.fromDialog == true

    self.view.btnClose.onClick:RemoveAllListeners()
    self.view.btnClose.onClick:AddListener(function()
        local isOpen = self.m_fromDialog
        if isOpen then
            self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
        else
            PhaseManager:PopPhase(PHASE_ID)
        end
    end)

    self.view.btnEnemyDetails.onClick:RemoveAllListeners()
    self.view.btnEnemyDetails.onClick:AddListener(function()
        Notify(MessageConst.SHOW_INTRO, self.m_selectedDungeonId)
    end)

    self.view.helpBtn.onClick:RemoveAllListeners()
    self.view.helpBtn.onClick:AddListener(function()
        UIManager:Open(PanelId.InstructionBook, "activity_dungeon_actmonster")
    end)

    self.view.rechallengeBtn.onClick:RemoveAllListeners()
    self.view.rechallengeBtn.onClick:AddListener(function()
        self.view.dungeonCommonInfo:_OnBtnDungeonEntryClick()
    end)

    self.view.goToBattleBtn.onClick:RemoveAllListeners()
    self.view.goToBattleBtn.onClick:AddListener(function()
        self.view.dungeonCommonInfo:_OnBtnDungeonEntryClick()
    end)

    self.m_dungeonSeriesId = arg.dungeonSeriesId
    self.m_activityId = arg.activityId
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    if not activity then
        
        self:_StartCoroutine(function()
            coroutine.step()
            coroutine.step()
            coroutine.yield()
            Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_FORBIDDEN)
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU,
                hideCancel = true,
                onConfirm = function()
                    PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
                end
            })
            local isOpen = self.m_fromDialog
            if isOpen then
                self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
            else
                PhaseManager:PopPhase(PHASE_ID)
            end
        end)
        return
    end

    self.m_genCells = UIUtils.genCellCache(self.view.dungeonSurvivalSelectCell)
    self.m_rewardCellCache = UIUtils.genCellCache(self.view.rewardCell)

    local _, achievementData = Tables.activityAchievementDataTable:TryGetValue(self.m_activityId)
    if achievementData ~= nil then
        self.view.dungeonMedalCell:InitCommonMedalNode(achievementData.achievementId)
    end

    
    local success, dungeonSeriesData = Tables.dungeonSeriesTable:TryGetValue(self.m_dungeonSeriesId)
    if not success then
        logger.error("DungeonActivityEntryCtrl.OnCreate 找不到副本系列数据，id=", self.m_dungeonSeriesId)
        return
    end

    self.m_cellRefreshFunc = function(cellView, cellIndex)
        local csIndex = CSIndex(cellIndex)
        local dungeonId = dungeonSeriesData.includeDungeonIds[csIndex]
        local success, dungeonData = Tables.dungeonTable:TryGetValue(dungeonId)
        if success then
            
            
            cellView.stateController:SetState(
                dungeonId == self.m_selectedDungeonId and "Select" or "Unselect"
            )
            
            local stateName = "Lock"

            local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
            local activityDungeonStateCfg = Tables.activityDungeonState:GetValue(dungeonId)
            local _, stageData = activityData.stageDataDict:TryGetValue(activityDungeonStateCfg.activityStage)

            if stageData.Status >= GEnums.ActivityConditionalStageState.Unlocked:GetHashCode() then
                if stageData.Status >= GEnums.ActivityConditionalStageState.Rewarded:GetHashCode() then
                    stateName = "Received"
                else
                    stateName = "Normal"
                end
            end
            cellView.stateController:SetState(stateName)

            local data = Tables.activityDungeonState:GetValue(dungeonId)
            cellView.stateController:SetState(data.showState)
            
            cellView.titleTxt.text = dungeonData.dungeonName
            
            cellView.serialNumberTxt.text = data.lv
            
            
            cellView.redDot:InitRedDot("ActivityDungeonState", {
                activityId = arg.activityId,
                stageId = data.activityStage,
            }, nil, self.view.redDotScrollRect)
        end
    end

    self.m_selectedDungeonId = arg.dungeonId or self:GetDefaultSelectedDungeonId()
    self.m_genCells:Refresh(dungeonSeriesData.includeDungeonIds.Count, self.m_cellRefreshFunc)

    local items = self.m_genCells:GetItems()
    for index, item in pairs(items) do
        item.button.onClick:RemoveAllListeners()
        item.button.onClick:AddListener(function()
            local dungeonId = dungeonSeriesData.includeDungeonIds[CSIndex(index)]
            if dungeonId ~= self.m_selectedDungeonId then
                self.m_selectedDungeonId = dungeonId
                local data = Tables.activityDungeonState:GetValue(dungeonId)
                if data.showState == "SpecialNode" then
                    AudioAdapter.PostEvent("Au_UI_Toast_HighDifficultyHint")
                end
                self.m_genCells:Refresh(dungeonSeriesData.includeDungeonIds.Count, function(cellView, cellIndex)
                    local csIndex = CSIndex(cellIndex)
                    local dungeonId = dungeonSeriesData.includeDungeonIds[csIndex]
                    cellView.selectBg:ClearTween()
                    cellView.stateController:SetState(
                        dungeonId == self.m_selectedDungeonId and "Select" or "Unselect"
                    )
                    if dungeonId ~= self.m_selectedDungeonId then
                        cellView.selectBg:PlayOutAnimation(function()
                            cellView.selectBg.gameObject:SetActive(false)
                        end)
                    end
                end)
                self:UpdateInfo()
            end
        end)
    end
    local enterDungeonCallback
    enterDungeonCallback = function(enterDungeonId)
        LuaSystemManager.uiRestoreSystem:AddRequest(enterDungeonId, function()
            PhaseManager:OpenPhaseFast(PhaseId.DungeonEntry, {
                dungeonId = enterDungeonId,
                activityId = self.m_activityId,
                enterDungeonCallback = enterDungeonCallback })
        end)

        if self.m_fromDialog then
            self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
        end
    end
    self.view.dungeonCommonInfo:InitDungeonCommonInfo({
        enterDungeonCallback = enterDungeonCallback,
    })
    self:UpdateInfo()

    self.view.claimRewardsBtn.onClick:RemoveAllListeners()
    self.view.claimRewardsBtn.onClick:AddListener(function()
        local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
        local activityDungeonStateCfg = Tables.activityDungeonState:GetValue(self.m_selectedDungeonId)
        local _, task = activityData.stageDataDict:TryGetValue(activityDungeonStateCfg.activityStage)
        GameInstance.player.activitySystem:SendReceiveRewardConditionMultiStage(self.m_activityId, task.Id)
    end)

    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    for index, dungeonId in pairs(dungeonSeriesData.includeDungeonIds) do
        if dungeonId == self.m_selectedDungeonId then
            UIUtils.setAsNaviTarget(self.m_genCells:Get(LuaIndex(index)).button)
            break
        end
    end
end



DungeonActivityEntryCtrl.GetDefaultSelectedDungeonId = HL.Method().Return(HL.String) << function(self)
    
        
    
        
    
        
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local dungeonSeriesData = Tables.dungeonSeriesTable:GetValue(self.m_dungeonSeriesId)
    local firstUncompletedDungeonId = ""
    local lastCompletedDungeonId = ""
    for i = 0, dungeonSeriesData.includeDungeonIds.Count - 1 do
        local dungeonId = dungeonSeriesData.includeDungeonIds[i]
        local activityDungeonStateCfg = Tables.activityDungeonState:GetValue(dungeonId)
        local success, stageData = activityData.stageDataDict:TryGetValue(activityDungeonStateCfg.activityStage)
        if success and stageData.Status == GEnums.ActivityConditionalStageState.Completed:GetHashCode() then
            return dungeonId
        end
        if success and stageData.Status == GEnums.ActivityConditionalStageState.Unlocked:GetHashCode() and firstUncompletedDungeonId == "" then
            firstUncompletedDungeonId = dungeonId
        end
        if success and stageData.Status == GEnums.ActivityConditionalStageState.Rewarded:GetHashCode() then
            lastCompletedDungeonId = dungeonId
        end
    end
    if firstUncompletedDungeonId ~= "" then
        return firstUncompletedDungeonId
    end
    return lastCompletedDungeonId
end




DungeonActivityEntryCtrl.OnGainMultiStageActivityReward = HL.Method(HL.Any) << function(self, args)
    local activityId = unpack(args)
    if activityId == self.m_activityId then
        local dungeonSeriesData = Tables.dungeonSeriesTable:GetValue(self.m_dungeonSeriesId)
        self.m_genCells:Refresh(dungeonSeriesData.includeDungeonIds.Count, self.m_cellRefreshFunc)
        self:UpdateInfo()
    end
end




DungeonActivityEntryCtrl.OnActivityUpdated = HL.Method(HL.Any) << function(self, args)
    local id = unpack(args)
    if id ~= self.m_activityId then
        return
    end
    local activity = GameInstance.player.activitySystem:GetActivity(id)
    if not activity then
        GameInstance.player.guide:OnActivityDisabled()
        UIManager:Close(PanelId.ActivityStartReminderPopup)
        UIManager:Close(PanelId.InstructionBook)
        UIManager:Close(PanelId.CommonIntro)
        UIManager:Close(PanelId.ItemTips)
        UIManager:Close(PanelId.CommonEnemyPopup)
        UIManager:Close(PanelId.CommonRewardDetailsPopup)
        Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_FORBIDDEN)
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_ACTIVITY_MODIFY_QUIT_TO_MENU,
            hideCancel = true,
            onConfirm = function()
                PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
            end
        })
        local isOpen = self.m_fromDialog
        if isOpen then
            self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
        else
            PhaseManager:PopPhase(PHASE_ID)
        end
    else
        local dungeonSeriesData = Tables.dungeonSeriesTable:GetValue(self.m_dungeonSeriesId)
        self.m_genCells:Refresh(dungeonSeriesData.includeDungeonIds.Count, self.m_cellRefreshFunc)
        self:UpdateInfo()
    end
end



DungeonActivityEntryCtrl.OnNewDay = HL.Method() << function(self)
    local dungeonSeriesData = Tables.dungeonSeriesTable:GetValue(self.m_dungeonSeriesId)
    self.m_genCells:Refresh(dungeonSeriesData.includeDungeonIds.Count, self.m_cellRefreshFunc)
    self:UpdateInfo()
end



DungeonActivityEntryCtrl.UpdateInfo = HL.Method() << function(self)
    local _, dungeonCfg = Tables.dungeonTable:TryGetValue(self.m_selectedDungeonId)
    local activityData = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local activityDungeonStateCfg = Tables.activityDungeonState:GetValue(self.m_selectedDungeonId)
    local success, stageData = activityData.stageDataDict:TryGetValue(activityDungeonStateCfg.activityStage)
    local stageCfg = Tables.activityConditionalMultiStageTable:GetValue(self.m_activityId)

    self.view.dungeonBGImage:LoadSprite(UIConst.UI_SPRITE_DUNGEON, dungeonCfg.dungeonPicPath)
    self.view.maskImg:LoadSprite(UIConst.UI_SPRITE_DUNGEON, dungeonCfg.dungeonPicPath .. "_bg")

    if success and stageData.Status == GEnums.ActivityConditionalStageState.Locked:GetHashCode() then
        self.view.lockNode.gameObject:SetActiveIfNecessary(true)
        local hour = stageCfg.stageList[activityDungeonStateCfg.activityStage].timeOffset
        local unlockTime = activityData.startTime + hour * Const.SEC_PER_HOUR
        self.view.dungeonCommonInfo.gameObject:SetActive(false)
        
        local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
        local deltaTime = unlockTime - curTime
        if deltaTime > 0 then
            self.view.timeTxt.text = UIUtils.getLeftTime(deltaTime)
            return
        end
        if not GameInstance.player.activitySystem:HasUncompletedNonTimeConditions(activityDungeonStateCfg.activityStage) then
            self.view.timeTxt.text = UIUtils.getLeftTime(0)
            return
        end
    end
    self.view.lockNode.gameObject:SetActiveIfNecessary(false)

    self.view.claimRewardsBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Completed:GetHashCode())
    self.view.goToBattleBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Unlocked:GetHashCode())
    self.view.rechallengeBtn.gameObject:SetActive(stageData.Status == GEnums.ActivityConditionalStageState.Rewarded:GetHashCode())

    
    self.view.dungeonCommonInfo:RefreshDungeonActivityCommonInfo(self.m_selectedDungeonId, self.m_activityId)
    self.view.dungeonCommonInfo.gameObject:SetActive(true)
    self.view.dungeonCommonInfo.view.btnDungeonEntry.gameObject:SetActive(false)
    
    self.view.rewardNode.gameObject:SetActive(true)
    ActivityUtils.setFalseNewActivityConditionalStage(activityDungeonStateCfg.activityStage)
end





DungeonActivityEntryCtrl.GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, index)
    local luaIndex = LuaIndex(index)

    local dungeonSeriesData = Tables.dungeonSeriesTable:GetValue(self.m_dungeonSeriesId)
    local dungeonId = dungeonSeriesData.includeDungeonIds[index]
    local data = Tables.activityDungeonState:GetValue(dungeonId)

    local hasRedDot, redDotType, expireTs = RedDotManager:GetRedDotState("ActivityDungeonState", {
        activityId = self.m_activityId,
        stageId = data.activityStage,
    })
    if hasRedDot then
        return redDotType or UIConst.RED_DOT_TYPE.Normal
    else
        return 0  
    end
end











HL.Commit(DungeonActivityEntryCtrl)
