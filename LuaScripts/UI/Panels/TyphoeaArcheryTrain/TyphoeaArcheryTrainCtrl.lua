
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaArcheryTrain
local PHASE_ID = PhaseId.TyphoeaArcheryTrain
local system = GameInstance.player.typhoeaArcherySystem

local SIMULATE_TRAIN_PANEL_ID = PanelId.TyphoeaArcherySimulateTrain
local DAILY_TRAIN_PANEL_ID = PanelId.TyphoeaArcheryDailyTrain
TyphoeaArcheryTrainCtrl = HL.Class('TyphoeaArcheryTrainCtrl', uiCtrl.UICtrl)






TyphoeaArcheryTrainCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_TYPHOEA_ARCHERY_SIMULATION_TRAINING_REWARD] = '_UpdateTabState', 
    [MessageConst.ON_TYPHOEA_ARCHERY_DAILY_TRAINING_REWARD] = '_UpdateTabState', 
    [MessageConst.ON_TYPHOEA_ARCHERY_ENTER_NEW_DAY] = '_UpdateTabState', 
    [MessageConst.ON_ACTIVITY_UPDATED] = '_OnLimitedActivityEnd', 
}

TyphoeaArcheryTrainCtrl.m_curPanelId = HL.Field(HL.Number) << -1
TyphoeaArcheryTrainCtrl.m_tabInfos = HL.Field(HL.Table)
TyphoeaArcheryTrainCtrl.m_tabCount = HL.Field(HL.Number) << 2
TyphoeaArcheryTrainCtrl.m_recoverArg = HL.Field(HL.Any)



TyphoeaArcheryTrainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_InitTabs()
end

TyphoeaArcheryTrainCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_recoverArg = arg
end

TyphoeaArcheryTrainCtrl._InitUI = HL.Method() << function(self)
    self.view.commonTopTitleNode.btnClose.onClick:AddListener(function()
        system:OnExitShootingRangeResetAffix() 
        PhaseManager:PopPhase(PHASE_ID)
    end)
    
    local activityId = Tables.typhoeaArcheryConst.shootingRangeLimitedActivityId
    self.view.rewardTaskNode:InitActivityTaskEntry({activityId = activityId})
end

TyphoeaArcheryTrainCtrl._InitTabs = HL.Method() << function(self)
    
    self.m_tabInfos = {
        [SIMULATE_TRAIN_PANEL_ID] = {
            tabCell = self.view.simulateTrainTab,
            redDot = "TyphoeaArcheryTabSimulateTrain",
            checkCurrentUnlockedAllCompletedFunc = function()
                
                local archeryData = system.archeryData
                local lv = archeryData.lv
                for gameId,gameData in pairs(Tables.typhoeaArcherySimulateTrainTable) do
                    if gameData.unlockLevel <= lv and not system:IsSimulateTrainCompleted(gameId) then
                        return false
                    end
                end
                return true
            end,
            checkRealAllCompletedFunc = function()
                
                for gameId,gameData in pairs(Tables.typhoeaArcherySimulateTrainTable) do
                    if not system:IsSimulateTrainCompleted(gameId) then
                        return false
                    end
                end
                return true
            end,
        },
        [DAILY_TRAIN_PANEL_ID] = {
            tabCell = self.view.dailyTrainTab,
            redDot = "TyphoeaArcheryTabDailyTrain",
            checkCurrentUnlockedAllCompletedFunc = function()
                
                local archeryData = system.archeryData
                local totalStar = archeryData.lv * archeryData.perLevelStarCount
                return archeryData.dailyStarCount == totalStar
            end,
            checkRealAllCompletedFunc = function()
                
                local archeryData = system.archeryData
                local totalStar = archeryData.maxLv * archeryData.perLevelStarCount
                return archeryData.dailyStarCount == totalStar
            end,
        },
    }

    
    local found = false
    if self.m_recoverArg and self.m_recoverArg.panelId then
        self.m_curPanelId = self.m_recoverArg.panelId
        found = true
    end
    for panelId, data in pairs(self.m_tabInfos) do
        
        local realCompleted = data.checkRealAllCompletedFunc()
        data.tabCell.stateController:SetState(realCompleted and "Finish" or "UnFinish")
        
        local allUnlockedCompleted = data.checkCurrentUnlockedAllCompletedFunc()
        if not found and not allUnlockedCompleted then
            found = true
            self.m_curPanelId = panelId
        end
    end
    if not found then
        
        self.m_curPanelId = DAILY_TRAIN_PANEL_ID
    end


    
    for panelId,info in pairs(self.m_tabInfos) do
        if not string.isEmpty(info.redDot) then
            if info.redDotArg then
                info.tabCell.redDot:InitRedDot(info.redDot, info.redDotArg)
            else
                info.tabCell.redDot:InitRedDot(info.redDot)
            end
        end
        
        info.tabCell.toggle.isOn = panelId == self.m_curPanelId
        info.tabCell.toggle.onValueChanged:AddListener(function(isOn)
            
            if isOn then
                self:_OnTabClick(panelId)
            end
        end)
    end

    self:_OnTabClick(self.m_curPanelId, true)
end


TyphoeaArcheryTrainCtrl._OnTabClick = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, panelId, isInit)
    if panelId == self.m_curPanelId and not isInit then
        return
    end
    
    self.m_curPanelId = panelId
    self.m_phase:OnTabChange({panelId = panelId, dungeonId = self.m_recoverArg and self.m_recoverArg.dungeonId or nil})
    if self.m_recoverArg then
        self.m_recoverArg = nil
    end
end

TyphoeaArcheryTrainCtrl._UpdateTabState = HL.Method() << function(self)
    
    for _,data in pairs(self.m_tabInfos) do
        data.tabCell.stateController:SetState(data.checkRealAllCompletedFunc() and "Finish" or "UnFinish")
    end
end

TyphoeaArcheryTrainCtrl._OnLimitedActivityEnd = HL.Method(HL.Any) << function(self, arg)
    local activityId = unpack(arg)
    if activityId ~= Tables.typhoeaArcheryConst.shootingRangeLimitedActivityId then
        return
    end

    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    
    if not activity then
        Notify(MessageConst.SHOW_ACTIVITY_POP_UP, {
            content = Language.LUA_TYPHOEA_ARCHERY_LIMITED_ACTIVITY_END_POP_UP, 
            hideCancel = true,
            onConfirm = function()
                self.view.rewardTaskNode.gameObject:SetActive(false)
                PhaseManager:ExitPhaseFastTo(PHASE_ID)
        end
        })
    end
end


HL.Commit(TyphoeaArcheryTrainCtrl)
