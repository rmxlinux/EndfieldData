
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.AdventureStage























AdventureStageCtrl = HL.Class('AdventureStageCtrl', uiCtrl.UICtrl)



AdventureStageCtrl.m_curAdventureStage = HL.Field(HL.Number) << -1


AdventureStageCtrl.m_adventureMaxStage = HL.Field(HL.Number) << -1


AdventureStageCtrl.m_curAdventureStageTaskInfos = HL.Field(HL.Table)


AdventureStageCtrl.m_adventureStageRewardCellCache = HL.Field(HL.Forward("UIListCache"))


AdventureStageCtrl.m_taskCellList = HL.Field(HL.Table)






AdventureStageCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ADVENTURE_TASK_MODIFY] = 'OnAdventureTaskModify',
    [MessageConst.ON_ADVENTURE_BOOK_STAGE_MODIFY] = 'OnAdventureBookStageModify',
    [MessageConst.ON_ADVENTURE_BOOK_SWITCH_SAME_TAB] = 'OnAdventureTabChangedSame',
}





AdventureStageCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_phase = arg.phase
    local adventure = self.view
    adventure.incBtn.onClick:AddListener(function()
        self:_OnIncBtnClick()
    end)
    adventure.decBtn.onClick:AddListener(function()
        self:_OnDecBtnClick()
    end)
    
    adventure.getStageReward.onClick:AddListener(function()
        self:_OnGetStageRewardBtnClick()
    end)

    self.view.rewardListNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
        adventure.controllerFocusHintNode.gameObject:SetActive(not isFocused)
    end)

    self.m_adventureStageRewardCellCache = UIUtils.genCellCache(adventure.itemReward)

    
    self.m_taskCellList = {}
    for i = 1, 6 do
        local cell = self.view.taskGroup["adventureTaskCell"..i]
        table.insert(self.m_taskCellList, cell)
    end
    
    self:_ResetAdventureStage()
    self:_RefreshAdventurePage(true)
end



AdventureStageCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    for luaIndex, cell in pairs(self.m_taskCellList) do
        cell:PlayInAniAndDelayTime(self.view.config.TASK_CELL_SHOW_DELAY_TIME * CSIndex(luaIndex))
    end
end



AdventureStageCtrl._OnIncBtnClick = HL.Method() << function(self)
    self.m_curAdventureStage = self.m_curAdventureStage + 1
    self:_SetStageText(self.m_curAdventureStage)

    self:_RefreshAdventurePage(false)
end



AdventureStageCtrl._OnDecBtnClick = HL.Method() << function(self)
    self.m_curAdventureStage = self.m_curAdventureStage - 1
    self:_SetStageText(self.m_curAdventureStage)

    self:_RefreshAdventurePage(false)
end



AdventureStageCtrl._OnGetStageRewardBtnClick = HL.Method() << function(self)
    GameInstance.player.adventure:TakeAdventureBookStageReward(self.m_curAdventureStage)
end



AdventureStageCtrl._ResetAdventureStage = HL.Method() << function(self)
    local adventureBookData = GameInstance.player.adventure.adventureBookData
    self.m_curAdventureStage = adventureBookData.adventureBookStage
    self.m_adventureMaxStage = adventureBookData.adventureBookStage
    self:_SetStageText(self.m_curAdventureStage)
end




AdventureStageCtrl._RefreshAdventurePage = HL.Method(HL.Boolean) << function(self, isInit)
    self:_RefreshBtnState()
    self:_RefreshAdventureStageOverview()
    self:_RefreshAdventureStageTask(isInit)
end



AdventureStageCtrl._RefreshBtnState = HL.Method() << function(self)
    local adventure = self.view
    adventure.incBtn.gameObject:SetActive(self.m_curAdventureStage < self.m_adventureMaxStage)
    adventure.decBtn.gameObject:SetActive(self.m_curAdventureStage > 1)
end




AdventureStageCtrl._RefreshAdventureStageOverview = HL.Method(HL.Opt(HL.Boolean)) << function(self, isTaskChanged)
    local rewardId = Tables.adventureBookStageRewardTable[self.m_curAdventureStage].rewardId
    local rewardData = Tables.rewardTable[rewardId]
    local adventureBookData = GameInstance.player.adventure.adventureBookData
    local isActualStage = self.m_curAdventureStage == adventureBookData.actualBookStage
    local isComplete = adventureBookData.isCurAdventureBookStateComplete

    local rewards = {}
    for _, itemBundle in pairs(rewardData.itemBundles) do
        local cfg = Utils.tryGetTableCfg(Tables.itemTable, itemBundle.id)
        if cfg then
            table.insert(rewards, {
                id = itemBundle.id,
                count = itemBundle.count,
                forceHidePotentialStar = true,
                
                rarity = -cfg.rarity,
                sortId1 = cfg.sortId1,
                sortId2 = cfg.sortId2,
            })
        end
    end

    table.sort(rewards, Utils.genSortFunction({"rarity", "sortId1", "sortId2", "id"}, true))

    self.m_adventureStageRewardCellCache:Refresh(#rewards, function(cell, luaIndex)
        cell.view.rewardedCover.gameObject:SetActiveIfNecessary(not isActualStage)
        cell:InitItem(rewards[luaIndex], function()
            UIUtils.showItemSideTips(cell)
        end)
        cell:SetExtraInfo({ isSideTips = DeviceInfo.usingController })
    end)

    local adventure = self.view
    adventure.stageComplete.gameObject:SetActiveIfNecessary(isActualStage and isComplete)
    adventure.stageCompleteBg.gameObject:SetActiveIfNecessary(isActualStage and isComplete)
    adventure.stageRewarded.gameObject:SetActiveIfNecessary(not isActualStage)

    
    if not isActualStage then
        
        adventure.overviewState:SetState("Received")
        adventure.ani:SampleToInAnimationBegin()
    else
        if isComplete then
            
            adventure.overviewState:SetState("Receive")
            if isTaskChanged then
                adventure.ani:Play("adventurestagepanel_receive")
            end
        else
            
            adventure.overviewState:SetState("NotReceived")
            adventure.ani:SampleToInAnimationBegin()
        end
    end
end




AdventureStageCtrl._RefreshAdventureStageTask = HL.Method(HL.Boolean) << function(self, isInit)
    local taskIds = Tables.adventureBookStageRewardTable[self.m_curAdventureStage].taskIds
    local adventure = GameInstance.player.adventure

    local taskInfos = {}
    for _, taskId in pairs(taskIds) do
        local taskInfo = {}
        local taskData = Tables.adventureTaskTable[taskId]
        local value = AdventureBookUtils.GetTaskCurrProgress(taskData)
        local maxProgress = AdventureBookUtils.GetTaskMaxProgress(taskData)
        local isComplete = adventure:IsTaskComplete(taskId)
        if not isComplete then
            isComplete = value >= maxProgress
        end
        local isRewarded = adventure:IsTaskRewarded(taskId)
        taskInfo.taskId = taskId
        taskInfo.isComplete = isComplete
        taskInfo.isRewarded = isRewarded
        taskInfo.sortId = -taskData.sortId

        taskInfo.completeSortId = isComplete and 0 or 1
        taskInfo.rewardSortId = isRewarded and 1 or 0

        table.insert(taskInfos, taskInfo)
    end
    table.sort(taskInfos, Utils.genSortFunction({"rewardSortId", "completeSortId", "sortId" }, true))

    self.m_curAdventureStageTaskInfos = taskInfos

    for luaIndex, cell in pairs(self.m_taskCellList) do
        local info = self.m_curAdventureStageTaskInfos[luaIndex]
        if isInit then
            cell:InitAdventureTaskCell(info)
        else
            cell:InitAdventureTaskCell(info, self.view.config.TASK_CELL_SHOW_DELAY_TIME * CSIndex(luaIndex))
        end
    end
end




AdventureStageCtrl.OnAdventureTaskModify = HL.Method(HL.Any) << function(self, args)
    local rewardedTaskIds = unpack(args)
    local rewardedIds = {}
    for _, rewardedTaskId in pairs(rewardedTaskIds) do
        local taskData = Tables.AdventureTaskTable[rewardedTaskId]
        if taskData.taskType ~= GEnums.AdventureTaskType.AdventureBook then
            return
        end
        table.insert(rewardedIds, taskData.rewardId)
    end
    self:_ShowRewardPopup(Language.LUA_ADVENTURE_BOOK_TASK_REWARD_TITLE_DESC, rewardedIds)

    self:_RefreshAdventureStageOverview(true)
    self:_RefreshAdventureStageTask(false)
end




AdventureStageCtrl.OnAdventureBookStageModify = HL.Method(HL.Any) << function(self, args)
    local preBookStage = unpack(args)
    local bookStageData = Tables.adventureBookStageRewardTable[preBookStage]
    self:_ShowRewardPopup(Language.LUA_ADVENTURE_BOOK_STAGE_REWARD_TITLE_DESC, {bookStageData.rewardId})

    local adventureBookData = GameInstance.player.adventure.adventureBookData
    self.m_curAdventureStage = adventureBookData.adventureBookStage
    self.m_adventureMaxStage = adventureBookData.adventureBookStage
    self:_SetStageText(self.m_curAdventureStage)
    self:_RefreshAdventurePage(false)
end




AdventureStageCtrl.OnAdventureTabChangedSame = HL.Method(HL.Number) << function(self, panelId)
    if panelId == PANEL_ID then
        self.view.taskGroup.selectableNaviGroup:NaviToThisGroup()
    end
end





AdventureStageCtrl._ShowRewardPopup = HL.Method(HL.String, HL.Table) << function(self, title, rewardedIds)
    if #rewardedIds < 1 then
        return
    end

    
    local rewardData = Tables.RewardTable[rewardedIds[1]]
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        title = title,
        items = rewardData.itemBundles,
    })
end




AdventureStageCtrl._SetStageText = HL.Method(HL.Number) << function(self, number)
    if number < 10 then
        self.view.stageTxtLeft.text = "0"
        self.view.stageTxtLeftBg.text = "0"
        self.view.stageTxtRight.text = number
        self.view.stageTxtRightBg.text = number
    else
        local left = number // 10
        local right = number % 10
        self.view.stageTxtLeft.text = left
        self.view.stageTxtLeftBg.text = left
        self.view.stageTxtRight.text = right
        self.view.stageTxtRightBg.text = right
    end
end

HL.Commit(AdventureStageCtrl)
