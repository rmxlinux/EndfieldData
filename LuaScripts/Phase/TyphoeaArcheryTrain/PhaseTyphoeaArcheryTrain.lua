
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.TyphoeaArcheryTrain
local PHASE_ID_CHIP_SET = PhaseId.TyphoeaArcheryChipSet

PhaseTyphoeaArcheryTrain = HL.Class('PhaseTyphoeaArcheryTrain', phaseBase.PhaseBase)





PhaseTyphoeaArcheryTrain.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SHOW_TYPHOEA_ARCHERY_TRAIN_PANEL] = { 'ShowTyphoeaArcheryTrainPanel', false},
}

PhaseTyphoeaArcheryTrain.m_curPanelItem = HL.Field(HL.Forward("PhasePanelItem"))
PhaseTyphoeaArcheryTrain.m_panelItemDic = HL.Field(HL.Table)
PhaseTyphoeaArcheryTrain.m_trainPanel = HL.Field(HL.Forward("PhasePanelItem"))
PhaseTyphoeaArcheryTrain.m_selectedDungeonId = HL.Field(HL.String) << ""

PhaseTyphoeaArcheryTrain.ShowTyphoeaArcheryTrainPanel = HL.StaticMethod() << function()
    
    PhaseManager:OpenPhase(PHASE_ID)
end


PhaseTyphoeaArcheryTrain._OnInit = HL.Override() << function(self)
    PhaseTyphoeaArcheryTrain.Super._OnInit(self)
end



PhaseTyphoeaArcheryTrain.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseTyphoeaArcheryTrain._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.m_panelItemDic = {}
    local arg = self.arg or {}
    arg.phase = self
    self.m_trainPanel = self:CreatePhasePanelItem(PanelId.TyphoeaArcheryTrain, arg)
    self:_BindControllerHintPlaceHolder()
end

PhaseTyphoeaArcheryTrain._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseTyphoeaArcheryTrain._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseTyphoeaArcheryTrain._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end






PhaseTyphoeaArcheryTrain._OnActivated = HL.Override() << function(self)
end

PhaseTyphoeaArcheryTrain._OnDeActivated = HL.Override() << function(self)
end

PhaseTyphoeaArcheryTrain._OnDestroy = HL.Override() << function(self)
    PhaseTyphoeaArcheryTrain.Super._OnDestroy(self)
end


PhaseTyphoeaArcheryTrain.OnTabChange = HL.Method(HL.Table) << function(self, arg) 
    if arg.panelId == nil then
        return
    end

    if self.m_curPanelItem then
        local preUiCtrl = self.m_curPanelItem.uiCtrl
        if self.m_curPanelItem.uiCtrl.panelId == arg.panelId then
            return
        else
            InputManagerInst.controllerNaviManager:SetTarget(nil)
        end
        local curUiAnimationWrapper = self.m_curPanelItem.uiCtrl.view.animationWrapper
        if curUiAnimationWrapper then
            
            local curUiInputGroup = self.m_curPanelItem.uiCtrl.view.inputGroup
            curUiInputGroup.enabled = false
            curUiAnimationWrapper:ClearTween(false)
            curUiAnimationWrapper:PlayOutAnimation(function()
                preUiCtrl:Hide()
                self:_OpenTab(arg)
                self:_BindControllerHintPlaceHolder()
            end)
        else
            preUiCtrl:Hide()
            self:_OpenTab(arg)
            self:_BindControllerHintPlaceHolder()
        end
    else
        self:_OpenTab(arg)
        self:_BindControllerHintPlaceHolder()
    end
end

PhaseTyphoeaArcheryTrain.UpdateSelectedDungeonId = HL.Method(HL.String) << function(self, dungeonId)
    self.m_selectedDungeonId = dungeonId
end

PhaseTyphoeaArcheryTrain.EnterDungeon = HL.Method(HL.String) << function(self, dungeonId)
    local hasSubGameInstData, subGameData = DataManager.subGameInstDataTable:TryGetValue(dungeonId)
    if not hasSubGameInstData then
        logger.error("JumpToDungeon失败,没有对应的subGameData,subGameId:", dungeonId)
        return
    end

    local teamId = subGameData.teamConfigId
    local lockedTeamData = CharInfoUtils.getLockedFormationData(teamId, true)

    local charInfos = {}
    if lockedTeamData then
        for _, charInfo in ipairs(lockedTeamData.chars) do
            table.insert(charInfos, CharInfoUtils.getPlayerCharInfoByInstId(charInfo.charInstId))
        end
    end

    if GameInstance.dungeonManager:TryReqEnterDungeon(dungeonId, charInfos) then
        LuaSystemManager.uiRestoreSystem:AddRequest(dungeonId)
        
    end
    GameInstance.player.charBag:ClearAllClientCharAndItemData()
end

PhaseTyphoeaArcheryTrain.ConfigureChip = HL.Method(HL.String) << function(self, dungeonId)
    PhaseManager:OpenPhase(PHASE_ID_CHIP_SET, {
        dungeonId = dungeonId
    })
end

PhaseTyphoeaArcheryTrain.OpenEnemyDetailsPopup = HL.Method(HL.String) << function(self, dungeonId)
    local dungeonCfg = Tables.dungeonTable[dungeonId]
    local popupArg = {
        title = Language.LUA_TYPHOEA_ARCHERY_TARGET_TITLE, 
        enemyListTitle = Language.LUA_TYPHOEA_ARCHERY_TARGET_LIST_TITLE, 
        enemyInfoTitle = Language.LUA_TYPHOEA_ARCHERY_TARGET_INFO_TITLE, 
        abilityTitle = Language.LUA_TYPHOEA_ARCHERY_TARGET_INFO, 
        enemyIds = dungeonCfg.enemyIds,
        hideLevelTextNode = true,
        hideDamageTakenInfo = true,
        isBackBtnStyle = false,
    }
    UIManager:AutoOpen(PanelId.CommonEnemyPopup, popupArg)
end

PhaseTyphoeaArcheryTrain._OpenTab = HL.Method(HL.Table) << function(self, arg) 
    local panelId = arg.panelId
    local panelItem
    if self.m_panelItemDic[panelId] then
        panelItem = self.m_panelItemDic[panelId]
        panelItem.uiCtrl:Show()
    else
        local tabArg = self.arg or {}
        tabArg.phase = self
        tabArg.dungeonId = arg.dungeonId
        panelItem = self:CreatePhasePanelItem(panelId, tabArg)
        self.m_panelItemDic[panelId] = panelItem
    end
    local animationWrapper = panelItem.uiCtrl.view.animationWrapper
    if animationWrapper then
        animationWrapper:ClearTween(false)
        animationWrapper:PlayInAnimation()
    end
    self.m_curPanelItem = panelItem
end

PhaseTyphoeaArcheryTrain._BindControllerHintPlaceHolder = HL.Method() << function(self)
    if not self.m_trainPanel or not self.m_curPanelItem then
        return
    end
    local trainCtrl = self.m_trainPanel.uiCtrl
    if trainCtrl then
        trainCtrl.view.controllerHintPlaceholder:InitControllerHintPlaceholder({
            trainCtrl.view.inputGroup.groupId,
            self.m_curPanelItem.uiCtrl.view.inputGroup.groupId,
        })
    end
end

PhaseTyphoeaArcheryTrain.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = self.arg and lume.copy(self.arg) or {}
    arg.panelId = self.m_curPanelItem.uiCtrl.panelId
    arg.dungeonId = self.m_selectedDungeonId
    arg.phase = nil
    return arg
end





HL.Commit(PhaseTyphoeaArcheryTrain)

