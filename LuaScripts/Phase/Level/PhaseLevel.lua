local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Level
local HGCamera = CS.HG.Rendering.Runtime.HGCamera
local PhaseLevelConfig = require_ex("Phase/Level/PhaseLevelConfig")






















































































PhaseLevel = HL.Class('PhaseLevel', phaseBase.PhaseBase)








PhaseLevel.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.OPEN_LEVEL_PHASE] = { 'OnOpenLevelPhase', false },
    [MessageConst.ON_SCENE_LOAD_START] = { 'onSceneLoadStart', true },
    [MessageConst.ON_SQUAD_INFIGHT_CHANGED] = {'OnSquadInfightChanged', true },

    [MessageConst.ON_EXIT_TRAVEL_MODE] = {'OnExitTravelMode', true },

    [MessageConst.SET_PHASE_LEVEL_TRANSITION_RESERVE_PANELS] = {'SetPhaseLevelTransitionReservePanels', true },

    [MessageConst.RECOVER_PHASE_LEVEL] = {'RecoverPhaseLevel', true },

    
    [MessageConst.ON_ENTER_TOWER_DEFENSE_PREPARING_PHASE ] = { 'OnEnterTowerDefensePreparingPhase', true },
    [MessageConst.ON_LEAVE_TOWER_DEFENSE_PREPARING_PHASE] = { 'OnLeaveTowerDefensePreparingPhase', true },
    [MessageConst.ON_ENTER_TOWER_DEFENSE_DEFENDING_PHASE] = { 'OnEnterTowerDefenseDefendingPhase', true },
    [MessageConst.ON_TOWER_DEFENSE_TRANSIT_FINISHED] = { 'OnTowerDefenseDefendingTransitFinished', true },
    [MessageConst.ON_LEAVE_TOWER_DEFENSE_DEFENDING_PHASE] = { 'OnLeaveTowerDefenseDefendingPhase', true },
    [MessageConst.ON_TOWER_DEFENSE_LEVEL_REWARDS_FINISHED] = { 'OnTowerDefenseDefendingRewardsFinished', true },
    

    
    [MessageConst.ON_START_DOMAIN_DEPOT_DELIVER] = { 'OnStartDomainDepotDeliver', true },
    [MessageConst.ON_FINISH_DOMAIN_DEPOT_DELIVER] = { 'OnFinishDomainDepotDeliver', true },
    

    [MessageConst.GAME_MODE_ENABLE] = { 'OnGameModeEnable', true },

    [MessageConst.SET_FAC_TOP_VIEW_CUSTOM_RANGE] = { 'SetFacTopViewCustomRange', true },

    [MessageConst.FAC_ON_MODIFY_CHAPTER_SCENE] = { 'ForceUpdateMainRegionInfo', true },

    [MessageConst.ON_RESET_BLACKBOX] = { 'OnResetBlackbox', true },
    [MessageConst.FORBID_SYSTEM_CHANGED] = { 'OnForbidSystemChanged', true },

    [MessageConst.FORCE_ENABLE_UI_SCENE_BLUR] = { 'OnForceEnableUISceneBlur', true },

    [MessageConst.TOGGLE_IN_MAIN_HUD_STATE] = { 'OnToggleInMainHudMessageNotified', true },

    [MessageConst.ON_INPUT_DEVICE_TYPE_CHANGED] = { 'OnInputDeviceTypeChanged', true }
}



PhaseLevel.OnOpenLevelPhase = HL.StaticMethod() << function()
    if not PhaseManager:IsOpen(PHASE_ID) then
        PhaseManager:OpenPhaseFast(PHASE_ID) 
        if LuaSystemManager.uiRestoreSystem:HasValidAction() then
            LuaSystemManager.uiRestoreSystem:TryRestore()
        end
    end
end







PhaseLevel.m_updateKey = HL.Field(HL.Number) << -1


PhaseLevel.m_headLabelCtrl = HL.Field(HL.Forward("HeadLabelCtrl"))


PhaseLevel.m_missionTrackerPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseLevel.m_generalTrackerPanel = HL.Field(HL.Forward("PhasePanelItem"))


PhaseLevel.s_forceTransitionBehindFastMode = HL.StaticField(HL.Boolean) << false







PhaseLevel._OnInit = HL.Override() << function(self)
    PhaseLevel.Super._OnInit(self)
    self:_InitInMainHudMessageList()
end




PhaseLevel.onSceneLoadStart = HL.Method(HL.Any) << function(self, arg)
end



PhaseLevel.OpenLevelPanels = HL.Method() << function(self)
    
    UIManager:Open(PanelId.LevelCamera)

    local config = PhaseLevelConfig.GetCurrentConfig()

    for _, panelId in ipairs(config.open) do
        if panelId == PanelId.MissionHud and UIManager:IsShow(PanelId.CommonTaskTrackHud) then
            
            
        else
            if not UIManager:IsOpen(panelId) then
                UIManager:Open(panelId)
            end
        end
    end

    for _, panelId in ipairs(config.preload) do
        UIManager:PreloadPersistentPanelAsset(panelId)
    end

    for _, panelId in ipairs(config.specialPanels) do
        if panelId == PanelId.GeneralTracker then
            self.m_generalTrackerPanel = self:CreatePhasePanelItem(PanelId.GeneralTracker)
        end
        if panelId == PanelId.GeneralTracker then
            local radio = UIManager:AutoOpen(PanelId.Radio)
            radio:Hide()
        end
    end

    
    self.m_headLabelCtrl = UIManager:AutoOpen(PanelId.HeadLabel)

    self:_UpdateFactoryMode(true)
    self:_ShowDomainDepotPackHudPanelIfNeed()

    self:OnGameModeEnable({ GameInstance.mode.modeType, GameInstance.mode })
    self:_RefreshUIForbidState()

    if config.preOpen then
        for _, panelId in ipairs(config.preOpen) do
            if not UIManager:IsOpen(panelId) then
                UIManager:Open(panelId)
                UIManager:Hide(panelId)
            end
        end
    end
end

local BlackBoxGuideNeedClosePanel = {
    PanelId.DungeonInfoPopup, 
    PanelId.BlackBoxTargetAndReward, 
    PanelId.CommonPopUp, 
    PanelId.FacUnloaderSelect, 
    PanelId.RewardsPopUpForBlackBox, 
    PanelId.Formula, 
    PanelId.CommonShare, 
    PanelId.ControllerSideMenu, 
}



PhaseLevel.RecoverPhaseLevel = HL.Method() << function(self)
    if PhaseManager.m_transCor then
        
        
        
        
        local key = CS.Beyond.Network.NetworkMask.instance:AddMask("PhaseLevel.RecoverPhaseLevel")
        CoroutineManager:StartCoroutine(function()
            while true do
                coroutine.step()
                if not PhaseManager.m_transCor then
                    CS.Beyond.Network.NetworkMask.instance:RemoveMask(key)
                    self:RecoverPhaseLevel()
                    return
                end
            end
        end)
        return
    end
    if PhaseManager:GetTopPhaseId() ~= PHASE_ID then
        GameWorld.dialogManager:Clear()
        PhaseManager:ExitPhaseFastTo(PhaseId.Level, true)
    end
    
    for _, panelId in pairs(BlackBoxGuideNeedClosePanel) do
        if UIManager:IsOpen(panelId) then
            UIManager:Close(panelId)
        end
    end
end





PhaseLevel.m_lastLevelIdNum = HL.Field(HL.Number) << -1


PhaseLevel.m_lastInFacMainRegion = HL.Field(HL.Boolean) << false


PhaseLevel.mainRegionPanelIndex = HL.Field(HL.Number) << -1 


PhaseLevel.mainRegionLocalRect = HL.Field(CS.UnityEngine.Rect)


PhaseLevel.mainRegionLocalRectWithMovePadding = HL.Field(CS.UnityEngine.Rect)


PhaseLevel.customFacTopViewRangeInWorld = HL.Field(CS.UnityEngine.Rect)





PhaseLevel.SetFacTopViewCustomRange = HL.Method(HL.Table) << function(self, args)
    local customRangeRect = args[1]
    if customRangeRect.width == 0 or customRangeRect.height == 0 then
        self.customFacTopViewRangeInWorld = nil
        return
    end
    self.customFacTopViewRangeInWorld = customRangeRect
end



PhaseLevel.ForceUpdateMainRegionInfo = HL.Method() << function(self)
    logger.info("PhaseLevel.ForceUpdateMainRegionInfo")
    local inMainRegion, panelIndex = Utils.isInFacMainRegionAndGetIndex()
    self:_UpdateCurMainRegionInfo(panelIndex)
end



PhaseLevel.OnExitTravelMode = HL.Method() << function(self)
    local inMainRegion, panelIndex = Utils.isInFacMainRegionAndGetIndex()
    if self.m_lastInFacMainRegion == inMainRegion and (not inMainRegion or self.mainRegionPanelIndex == panelIndex) then
        return
    end
    self:_UpdateCurMainRegionInfo(panelIndex)
    self:_TryAutoToggleFacMode(inMainRegion)
end


PhaseLevel.m_enterFacMainRegionCamState = HL.Field(HL.Any)


PhaseLevel.m_waitInitFacMode = HL.Field(HL.Boolean) << true




PhaseLevel._UpdateFactoryMode = HL.Method(HL.Opt(HL.Boolean)) << function(self, isInit)
    local inMainRegion, panelIndex = Utils.isInFacMainRegionAndGetIndex()
    local curLevelIdNum = GameWorld.worldInfo.curLevelIdNum
    if isInit then
        self.m_waitInitFacMode = false

        self:_UpdateCurMainRegionInfo(panelIndex)

        
        local enterFactoryModeOnSceneLoaded = false
        local bData = GameWorld.worldInfo.curLevel.levelData.blackbox
        if bData then
            enterFactoryModeOnSceneLoaded = bData.basic.enterFactoryModeOnSceneLoaded
        end

        local inFacMode
        local inMainWorld = not UIUtils.inDungeon() and not Utils.isInSpaceShip()
        if LuaSystemManager.factory.lastMapIsDungeon and inMainWorld and LuaSystemManager.factory.inFacModeBeforeEnterDungeon ~= nil then
            
            inFacMode = LuaSystemManager.factory.inFacModeBeforeEnterDungeon
            LuaSystemManager.factory.inFacModeBeforeEnterDungeon = nil
        else
            inFacMode = inMainRegion or enterFactoryModeOnSceneLoaded
        end
        LuaSystemManager.factory:ClearAndSetFactoryMode(inFacMode, true)

        self.m_lastLevelIdNum = curLevelIdNum
        self.m_lastInFacMainRegion = inMainRegion
        GameWorld.worldInfo.inFacMainRegion = inMainRegion

        
        
        
        UIManager:AutoOpen(PanelId.FacMiniPowerHud)

        if inMainRegion then
            Notify(MessageConst.ON_ENTER_FAC_MAIN_REGION, panelIndex)
            Notify(MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE, inMainRegion)

            
            GameAction.SetInSafeZone(0, true) 

            self.m_enterFacMainRegionCamState = FactoryUtils.enterFacCamera(FacConst.MAIN_REGION_CAM_STATE)
        else
            Notify(MessageConst.ON_EXIT_FAC_MAIN_REGION)
            UIManager:Hide(PanelId.FacMiniPowerHud)
        end

        
        local otherPanels = GameWorld.worldInfo.inFactoryMode and Const.BATTLE_MODE_ONLY_PANELS or Const.FACTORY_MODE_ONLY_PANELS
        for _, panelId in pairs(otherPanels) do
            UIManager:PreloadPanelAsset(panelId, PHASE_ID)
        end

        UIManager:PreloadPersistentPanelAsset(PanelId.FacMachineCrafter)  
        return
    end

    if self.m_waitInitFacMode then
        return
    end

    self:_UpdatePlayerPosFacInfo()

    if self.m_lastInFacMainRegion ~= inMainRegion or self.mainRegionPanelIndex ~= panelIndex or self.m_lastLevelIdNum ~= curLevelIdNum then
        self.m_lastLevelIdNum = curLevelIdNum
        self.m_lastInFacMainRegion = inMainRegion
        self:_UpdateCurMainRegionInfo(panelIndex)

        
        if not GameWorld.gameMechManager.travelPoleBrain.inFastTravelMode and not Utils.isSwitchModeDisabled() then
            self:_TryAutoToggleFacMode(inMainRegion)
        end
        if inMainRegion then
            Notify(MessageConst.ON_ENTER_FAC_MAIN_REGION, panelIndex)
            if not self.m_enterFacMainRegionCamState then
                self.m_enterFacMainRegionCamState = FactoryUtils.enterFacCamera(FacConst.MAIN_REGION_CAM_STATE)
            end
        else
            Notify(MessageConst.ON_EXIT_FAC_MAIN_REGION)
            if self.m_enterFacMainRegionCamState then
                self.m_enterFacMainRegionCamState = FactoryUtils.exitFacCamera(self.m_enterFacMainRegionCamState)
            end
        end
        
        GameAction.SetInSafeZone(0, inMainRegion)

        Notify(MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE, inMainRegion)

        
        GameWorld.worldInfo.inFacMainRegion = inMainRegion
    end
end




PhaseLevel._UpdateCurMainRegionInfo = HL.Method(HL.Opt(HL.Number)) << function(self, panelIndex)
    if panelIndex and panelIndex >= 0 then
        self.mainRegionPanelIndex = panelIndex
        self.mainRegionLocalRect = GameInstance.remoteFactoryManager:GetMainRegionLocalRect(panelIndex, 0)
        local padding = Vector2(FacConst.FAC_TOP_VIEW_MOVE_PADDING, FacConst.FAC_TOP_VIEW_MOVE_PADDING)
        self.mainRegionLocalRectWithMovePadding = Unity.Rect(self.mainRegionLocalRect.min + padding, self.mainRegionLocalRect.size - padding * 2)
    else
        self.mainRegionPanelIndex = -1
        self.mainRegionLocalRect = nil
        self.mainRegionLocalRectWithMovePadding = nil
    end
end




PhaseLevel._TryAutoToggleFacMode = HL.Method(HL.Boolean) << function(self, inMainRegion)
    if inMainRegion then
        if FactoryUtils.canPlayerEnterFacMode() then
            
            LuaSystemManager.factory:AddFactoryModeRequest({ true, "Player" })
        end
    else
        
        if not FactoryUtils.isInBuildMode() then
            LuaSystemManager.factory:RemoveFactoryModeRequest("Player" )
        end
    end
end



PhaseLevel.OnSquadInfightChanged = HL.Method(HL.Opt(HL.Any)) << function(self)
    local inFight = Utils.isInFight()
    if inFight then
        LuaSystemManager.factory:AddFactoryModeRequest({ false, "InFight" })
    else
        LuaSystemManager.factory:RemoveFactoryModeRequest("InFight")
    end
end


PhaseLevel.isPlayerOutOfRangeManual = HL.Field(HL.Boolean) << false



PhaseLevel._UpdatePlayerPosFacInfo = HL.Method() << function(self)
    local succ, outOfRangeManual = GameInstance.remoteFactoryManager:TrySampleCurrentSceneGridStatusWithPlayerPosition()
    if succ then
        if outOfRangeManual ~= self.isPlayerOutOfRangeManual then
            self.isPlayerOutOfRangeManual = outOfRangeManual
            



            local disableSwitchMode = GameInstance.player.forbidSystem:IsForbidden(ForbidType.DisableSwitchMode)
            if outOfRangeManual and not disableSwitchMode then
                if FactoryUtils.isInBuildMode() then
                    Notify(MessageConst.FAC_BUILD_EXIT_CUR_MODE, true)
                end
                LuaSystemManager.factory:ClearAndSetFactoryMode(false, true)
            end
            Notify(MessageConst.FAC_ON_PLAYER_POS_INFO_CHANGED)
        end
    end
end








PhaseLevel._AddRegisters = HL.Method() << function(self)
    self.m_updateKey = LuaUpdate:Add("Tick", function()
        self:_Update()
    end, true)
end



PhaseLevel._ClearRegisters = HL.Method() << function(self)
    self.m_updateKey = LuaUpdate:Remove(self.m_updateKey)
end



PhaseLevel._Update = HL.Method() << function(self)
    self:_UpdateFactoryMode()
end









PhaseLevel._OnActivated = HL.Override() << function(self)
    self:_AddRegisters()
    GameWorld.ppEffectLoader:ResumeTick()
    self:_OnInternalInMainHudStateChanged(true)
end




PhaseLevel._OnDeActivated = HL.Override() << function(self)
    self:_ClearRegisters()
    GameWorld.ppEffectLoader:PauseTick()
    if GameWorld.worldInfo.inMainHud then
        self:_OnInternalInMainHudStateChanged(false)
    end
    Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = self, enabled = true})
end



PhaseLevel._OnDestroy = HL.Override() << function(self)
    if self.m_hidePanelKey > 0 then
        self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)
    end
    self:_ClearRegisters()
    self:_ClearInMainHudMessageList()

    if self.m_enterFacMainRegionCamState then
        self.m_enterFacMainRegionCamState = FactoryUtils.exitFacCamera(self.m_enterFacMainRegionCamState)
    end

    local inDungeon = UIUtils.inDungeon()
    LuaSystemManager.factory.lastMapIsDungeon = inDungeon
    if not inDungeon then
        
        LuaSystemManager.factory.inFacModeBeforeEnterDungeon = LuaSystemManager.factory:GetFactoryModeOfRequest("Player")
    end

    Notify(MessageConst.ON_PHASE_LEVEL_DESTROYED)
end





PhaseLevel._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = self, enabled = false})
    if DeviceInfo.isMobile then
        Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = "MobileController", enabled = DeviceInfo.usingController})
    end

    self:OpenLevelPanels()

    
    self:PerformLoginCheck()

    logger.info("ON_PHASE_LEVEL_ON_TOP")
    Notify(MessageConst.ON_PHASE_LEVEL_ON_TOP)

    
    if not LuaSystemManager.uiRestoreSystem:HasValidAction() then
        CS.Beyond.Gameplay.Conditions.OnEnterMainHud.Trigger()
    end
    
    self:TryRestoreTowerDefense()
    
    if not Utils.isInDungeon() then
        Notify(MessageConst.ON_WORLD_LEVEL_CHANGED, {GameInstance.player.adventure.currentMaxWorldLevel - 1, GameInstance.player.adventure.currentMaxWorldLevel, false})
    end
end


PhaseLevel.m_hidePanelKey = HL.Field(HL.Number) << -1





PhaseLevel._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = self, enabled = false})

    self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)

    logger.info("ON_PHASE_LEVEL_ON_TOP")
    Notify(MessageConst.ON_PHASE_LEVEL_ON_TOP)
    CS.Beyond.Gameplay.Conditions.OnEnterMainHud.Trigger()
    
    GameInstance.remoteFactoryManager:ForceCullingExecute()

    self:_OnInternalInMainHudStateChanged(true)
end



PhaseLevel.m_transitionReservePanelIds = HL.Field(HL.Table)




PhaseLevel.SetPhaseLevelTransitionReservePanels = HL.Method(HL.Table) << function(self, ids)
    
    
    
    self.m_transitionReservePanelIds = ids
end





PhaseLevel._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local usingBT = UIUtils.usingBlockTransition()
    if args.anotherPhaseId == PhaseId.CharInfo or args.anotherPhaseId == PhaseId.CharFormation then
        
        
    elseif fastMode or usingBT or PhaseLevel.s_forceTransitionBehindFastMode then
        self.m_hidePanelKey = UIManager:ClearScreen(self.m_transitionReservePanelIds)
    else
        self.m_inTransition = true
        UIManager:ClearScreenWithOutAnimation(function(key)
            self.m_hidePanelKey = key
            if self.m_completeOnDestroy and self.m_hidePanelKey > 0 then
                self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)
            end
            self.m_inTransition = false
        end, self.m_transitionReservePanelIds)
    end
    self.m_transitionReservePanelIds = nil

    self:_OnInternalInMainHudStateChanged(false)

    
    GameInstance.playerController.commandController:ConsumeAllCommand()

    logger.info("ON_PHASE_LEVEL_NOT_ON_TOP")
    Notify(MessageConst.ON_PHASE_LEVEL_NOT_ON_TOP)
end





PhaseLevel._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self:_OnInternalInMainHudStateChanged(false)

    
    GameInstance.playerController.commandController:ConsumeAllCommand()

    logger.info("ON_PHASE_LEVEL_NOT_ON_TOP")
    Notify(MessageConst.ON_PHASE_LEVEL_NOT_ON_TOP)
end





local defenseExpectedPanels = {
    PanelId.MainHud,
    PanelId.Joystick,
    PanelId.LevelCamera,
    PanelId.FacHudBottomMask,
    PanelId.FacBuildMode,
    PanelId.FacDestroyMode,
    PanelId.FacBuildingInteract,
    PanelId.CommonItemToast,
    PanelId.CommonNewToast,
    PanelId.CommonHudToast,
    PanelId.Radio,
    PanelId.CommonTaskTrackHud,
    PanelId.FacTopViewBuildingInfo,
    PanelId.InteractOption,
    PanelId.GuideLimited,
    PanelId.AIBark,
    PanelId.SettlementDefenseTransit,
    PanelId.MissionHud,
    PanelId.HeadBar,
}

local defenseFinishExpectedPanels = {
    PanelId.Joystick,
    PanelId.LevelCamera,
    PanelId.CommonTaskTrackHud,
}

local DEFENSE_TASK_TRACK_HUD_OFFSET = Vector2(0, -120)
local DEFENSE_CLEAR_DELAY_TIMER = 1.5


PhaseLevel.m_defensePrepareCtrl = HL.Field(HL.Forward("SettlementDefensePrepareHudCtrl"))


PhaseLevel.m_defenseTrackerCtrl = HL.Field(HL.Forward("SettlementDefenseTrackerCtrl"))


PhaseLevel.m_defenseInGamePanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseLevel.m_defenseTrackerPanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseLevel.m_defenseMiniMapPanelItem = HL.Field(HL.Forward("PhasePanelItem"))


PhaseLevel.m_defenseInGameClearScreenKey = HL.Field(HL.Number) << -1


PhaseLevel.m_defenseFinishClearScreenKey = HL.Field(HL.Number) << -1


PhaseLevel.m_defenseClearTimer = HL.Field(HL.Number) << -1


PhaseLevel.m_defenseMainCharEffect = HL.Field(HL.Userdata)



PhaseLevel.TryRestoreTowerDefense = HL.Method() << function(self)
    if GameInstance.player.towerDefenseSystem.hudState == CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.Preparing then
        UIManager:Close(PanelId.MissionHud)
        self:OnEnterTowerDefensePreparingPhase()
    end
    if GameInstance.player.towerDefenseSystem.hudState == CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.Defending then
        UIManager:Close(PanelId.MissionHud)
        self:OnEnterTowerDefenseDefendingPhase(true)
        self:OnTowerDefenseDefendingTransitFinished()
    end
end



PhaseLevel.OnEnterTowerDefensePreparingPhase = HL.Method() << function(self)
    GameInstance.player.towerDefenseSystem.hudState = CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.Preparing
    LuaSystemManager.factory:AddFactoryModeRequest({ true, "TowerDefensePrepare" })
    self.m_defensePrepareCtrl = UIManager:AutoOpen(PanelId.SettlementDefensePrepareHud)
    self.m_defenseTrackerCtrl = UIManager:AutoOpen(PanelId.SettlementDefenseTracker)
end




PhaseLevel.OnLeaveTowerDefensePreparingPhase = HL.Method(HL.Any) << function(self, args)
    GameInstance.player.towerDefenseSystem.hudState = CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.None
    LuaSystemManager.factory:RemoveFactoryModeRequest("TowerDefensePrepare")
    local onLeavingArea, startLeave = unpack(args)
    if self.m_defensePrepareCtrl:IsShow() then
        self.m_defensePrepareCtrl:CloseDefensePrepareHud(onLeavingArea, startLeave)
    else
        self.m_defensePrepareCtrl:Close()
    end
    self.m_defensePrepareCtrl = nil
    self.m_defenseTrackerCtrl:Close()
    self.m_defenseTrackerCtrl = nil
end




PhaseLevel.OnEnterTowerDefenseDefendingPhase = HL.Method(HL.Opt(HL.Boolean)) << function(self, isRestore)
    self.m_defenseInGameClearScreenKey = UIManager:ClearScreen(lume.concat(defenseExpectedPanels, Const.BATTLE_MODE_ONLY_PANELS))
    GameInstance.player.towerDefenseSystem.systemInDefense = true

    local isOpen, taskTrackHudCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
    if isOpen and not isRestore then
        taskTrackHudCtrl:AddPositionOffset(DEFENSE_TASK_TRACK_HUD_OFFSET, false)  
    end
end



PhaseLevel.OnTowerDefenseDefendingTransitFinished = HL.Method() << function(self)
    GameInstance.player.towerDefenseSystem.hudState = CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.Defending
    self.m_defenseInGamePanelItem = self:CreatePhasePanelItem(PanelId.SettlementDefenseInGameHud)
    self.m_defenseTrackerPanelItem = self:CreatePhasePanelItem(PanelId.SettlementDefenseTracker)
    self.m_defenseMiniMapPanelItem = self:CreatePhasePanelItem(PanelId.SettlementDefenseMiniMap)

    AudioManager.PostAudioCue("au_cue_music_base_mode_defense_main_start")
end



PhaseLevel.OnLeaveTowerDefenseDefendingPhase = HL.Method() << function(self)
    GameInstance.player.towerDefenseSystem.hudState = CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.WaitingFinished
    local waitCloseItemList = {
        self.m_defenseInGamePanelItem,
        self.m_defenseTrackerPanelItem,
        self.m_defenseMiniMapPanelItem,
    }

    if PhaseManager:GetTopPhaseId() ~= PHASE_ID then
        PhaseManager:ExitPhaseFastTo(PHASE_ID)
    end

    self.m_defenseFinishClearScreenKey = UIManager:ClearScreen(defenseFinishExpectedPanels)

    local waitCount = #waitCloseItemList
    for _, item in ipairs(waitCloseItemList) do
        item.uiCtrl:PlayAnimationOutWithCallback(function()
            self:RemovePhasePanelItem(item)
            waitCount = waitCount - 1
            if waitCount == 0 then
                if PhaseManager:GetTopPhaseId() ~= PHASE_ID then
                    PhaseManager:ExitPhaseFastTo(PHASE_ID)
                end
                self.m_defenseClearTimer = TimerManager:StartTimer(DEFENSE_CLEAR_DELAY_TIMER, function()
                    TimerManager:ClearTimer(self.m_defenseClearTimer)
                    GameInstance.player.towerDefenseSystem.hudState = CS.Beyond.Gameplay.TowerDefenseSystem.HUDState.None
                    Notify(MessageConst.ON_TOWER_DEFENSE_LEVEL_HUD_CLEARED)
                end)
            end
        end)
    end

    local isOpen, taskTrackHudCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
    if isOpen then
        taskTrackHudCtrl:ClearPositionOffset()  
    end

    if self.m_defenseMainCharEffect then
        self.m_defenseMainCharEffect:Finish()
        self.m_defenseMainCharEffect = nil
    end
end



PhaseLevel.OnTowerDefenseDefendingRewardsFinished = HL.Method() << function(self)
    self.m_defenseInGameClearScreenKey = UIManager:RecoverScreen(self.m_defenseInGameClearScreenKey)
    self.m_defenseFinishClearScreenKey = UIManager:RecoverScreen(self.m_defenseFinishClearScreenKey)
    if Utils.needMissionHud() then
        UIManager:AutoOpen(PanelId.MissionHud)
    end
end








PhaseLevel._ShowDomainDepotPackHudPanelIfNeed = HL.Method() << function(self)
    if GameInstance.player.domainDepotSystem:IsDomainDepotDeliveringCargo() then
        self:_ShowDomainDepotPackHudPanel(false)
    end
end




PhaseLevel._ShowDomainDepotPackHudPanel = HL.Method(HL.Boolean) << function(self, needShowAllInfo)
    UIManager:AutoOpen(PanelId.DomainDepotPackHud, { needShowAllInfo = needShowAllInfo })
end



PhaseLevel._HideDomainDepotPackHudPanel = HL.Method() << function(self)
    UIManager:Close(PanelId.DomainDepotPackHud)
end



PhaseLevel._RefreshDomainDepotPackHudOnGameModeChange = HL.Method() << function(self)
    local isOpen = UIManager:IsOpen(PanelId.DomainDepotPackHud)
    if not isOpen then
        return
    end
    local needShow = GameInstance.mode.modeType == GEnums.GameModeType.Default
    if needShow then
        local isShow = UIManager:IsShow(PanelId.DomainDepotPackHud)
        if not isShow then
            UIManager:Show(PanelId.DomainDepotPackHud)
        end
    else
        local isHide = UIManager:IsHide(PanelId.DomainDepotPackHud)
        if not isHide then
            UIManager:Hide(PanelId.DomainDepotPackHud)
        end
    end
end



PhaseLevel.OnStartDomainDepotDeliver = HL.Method() << function(self)
    self:_ShowDomainDepotPackHudPanel(false)
end




PhaseLevel.OnFinishDomainDepotDeliver = HL.Method(HL.Any) << function(self, args)
    local selfComplete = unpack(args)  
    self:_HideDomainDepotPackHudPanel()
end






local GameModeHideUIKey = "GameMode"




PhaseLevel.OnGameModeEnable = HL.Method(HL.Table) << function(self, args)
    logger.info("PhaseLevel.OnGameModeEnable", args)
    local modeType, mode = unpack(args)
    if mode.hideSquadIcon then
        UIManager:HideWithKey(PanelId.SquadIcon, GameModeHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.SquadIcon, GameModeHideUIKey)
    end

    if mode.forbidAttack then
        UIManager:HideWithKey(PanelId.BattleAction, GameModeHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.BattleAction, GameModeHideUIKey)
    end
    Notify(MessageConst.TOGGLE_FORBID_ATTACK, { GameModeHideUIKey, mode.forbidAttack })

    if mode.hideMissionHud then
        UIManager:HideWithKey(PanelId.MissionHud, GameModeHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.MissionHud, GameModeHideUIKey)
    end

    if mode.hideSNSHud then
        UIManager:HideWithKey(PanelId.SNSHud, GameModeHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.SNSHud, GameModeHideUIKey)
    end

    self:_RefreshDomainDepotPackHudOnGameModeChange()

    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidSprint, GameModeHideUIKey, mode.forbidSprint)
    GameInstance.player.forbidSystem:SetForbid(ForbidType.ForbidLockTarget, GameModeHideUIKey, mode.forbidLockTarget)
end





local ForbidSystemHideUIKey = "PhaseLevelForbid"




PhaseLevel.OnForbidSystemChanged = HL.Method(HL.Table) << function(self, args)
    local forbidType, isForbidden = unpack(args)
    if forbidType == ForbidType.HideSquadIcon then
        if isForbidden then
            UIManager:HideWithKey(PanelId.SquadIcon, ForbidSystemHideUIKey)
        else
            UIManager:ShowWithKey(PanelId.SquadIcon, ForbidSystemHideUIKey)
        end
    end
    if forbidType == ForbidType.ForbidAttack then
        if isForbidden then
            UIManager:HideWithKey(PanelId.BattleAction, ForbidSystemHideUIKey)
        else
            UIManager:ShowWithKey(PanelId.BattleAction, ForbidSystemHideUIKey)
        end
    end
end



PhaseLevel._RefreshUIForbidState = HL.Method() << function(self)
    
    local forbidSys = GameInstance.player.forbidSystem
    
    if forbidSys:IsForbidden(ForbidType.HideSquadIcon) then
        UIManager:HideWithKey(PanelId.SquadIcon, ForbidSystemHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.SquadIcon, ForbidSystemHideUIKey)
    end
    
    if forbidSys:IsForbidden(ForbidType.ForbidAttack) then
        UIManager:HideWithKey(PanelId.BattleAction, ForbidSystemHideUIKey)
    else
        UIManager:ShowWithKey(PanelId.BattleAction, ForbidSystemHideUIKey)
    end
end





local INTERNAL_OUT_MAIN_HUD_KEY = "otherPhase"


PhaseLevel.m_inMainHudMessageConfig = HL.Field(HL.Table)


PhaseLevel.m_inMainHudMessageDataList = HL.Field(HL.Table)


PhaseLevel.m_outMainHudKeyList = HL.Field(HL.Table)



PhaseLevel._InitInMainHudMessageList = HL.Method() << function(self)
    
    
    self.m_inMainHudMessageConfig = {
        ["loading"] = { 
            inMessage = MessageConst.ON_LOADING_PANEL_CLOSED,
            outMessage = MessageConst.ON_LOADING_PANEL_OPENED,
            earlyCheckPanelId = PanelId.Loading
        },
        ["teleport"] = { 
            inMessage = MessageConst.ON_TELEPORT_LOADING_PANEL_CLOSED,
            outMessage = MessageConst.ON_TELEPORT_LOADING_PANEL_OPENED,
            earlyCheckPanelId = PanelId.TeleportLoading
        },
        ["blackScreen"] = { 
            inMessage = MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_END,
            outMessage = MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_BEGIN,
            earlyCheckPanelId = PanelId.CommonMask
        },
        ["blockedReward"] = { 
            inMessage = MessageConst.ON_EXIT_BLOCKED_REWARD_POP_UP_PANEL,
            outMessage = MessageConst.ON_ENTER_BLOCKED_REWARD_POP_UP_PANEL,
        },
        ["dungeonSettlement"] = { 
            inMessage = MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED,
            outMessage = MessageConst.ON_DUNGEON_SETTLEMENT_OPENED,
        },
        ["forceSNS"] = { 
            inMessage = MessageConst.ON_SNS_FORCE_DIALOG_END,
            outMessage = MessageConst.ON_SNS_FORCE_DIALOG_START,
        },
    }

    self.m_inMainHudMessageDataList = {}
    self.m_outMainHudKeyList = {}

    for index, configInfo in pairs(self.m_inMainHudMessageConfig) do
        local inKey = MessageManager:Register(configInfo.inMessage, function()
            self:_OnInMainHudMessageNotified(index, true)
        end, self)

        local outKey = MessageManager:Register(configInfo.outMessage, function()
            self:_OnInMainHudMessageNotified(index, false)
        end, self)

        self.m_inMainHudMessageDataList[index] = {
            inKey = inKey,
            outKey = outKey,
        }

        
        
        
        if configInfo.earlyCheckPanelId ~= nil and UIManager:IsShow(configInfo.earlyCheckPanelId) then
            self:_OnInMainHudMessageNotified(index, false)
        end
    end
end



PhaseLevel._ClearInMainHudMessageList = HL.Method() << function(self)
    for _, info in ipairs(self.m_inMainHudMessageDataList) do
        MessageManager:Unregister(info.inKey)
        MessageManager:Unregister(info.outKey)
    end
    self.m_inMainHudMessageConfig = {}
    self.m_inMainHudMessageDataList = {}
    self.m_outMainHudKeyList = {}
end



PhaseLevel._GetIsOutMainHud = HL.Method().Return(HL.Boolean) << function(self)
    return next(self.m_outMainHudKeyList) ~= nil
end




PhaseLevel.OnToggleInMainHudMessageNotified = HL.Method(HL.Table) << function(self, args)
    local key, isInMainHud
    if lume.isarray(args) then
        key, isInMainHud = unpack(args)
    else
        key, isInMainHud = args.key, args.isInMainHud
    end

    self:_OnInMainHudMessageNotified(key, isInMainHud)
end





PhaseLevel._OnInMainHudMessageNotified = HL.Method(HL.String, HL.Boolean) << function(self, key, isInMainHud)
    if isInMainHud then
        self.m_outMainHudKeyList[key] = nil
    else
        self.m_outMainHudKeyList[key] = true
    end

    self:_OnInMainHudStateChanged()
    logger.important(CS.Beyond.EnableLogType.DevOnly, "当前有其他行为导致是否处于MainHud状态发生改变, 来源", key, ", isIn", isInMainHud, ", 当前是否MainHud", GameWorld.worldInfo.inMainHud)
end




PhaseLevel._OnInternalInMainHudStateChanged = HL.Method(HL.Boolean) << function(self, isIn)
    if isIn then
        self.m_outMainHudKeyList[INTERNAL_OUT_MAIN_HUD_KEY] = nil
    else
        self.m_outMainHudKeyList[INTERNAL_OUT_MAIN_HUD_KEY] = true
    end

    self:_OnInMainHudStateChanged()
    logger.important(CS.Beyond.EnableLogType.DevOnly, "当前因为打开了其他Phase导致是否处于MainHud状态发生改变, isIn", isIn, ", 当前是否MainHud", GameWorld.worldInfo.inMainHud)
end



PhaseLevel._OnInMainHudStateChanged = HL.Method() << function(self)
    GameWorld.worldInfo.inMainHud = not self:_GetIsOutMainHud()
end






PhaseLevel.OnResetBlackbox = HL.Method() << function(self)
    if FactoryUtils.isInTopView() then
        LuaSystemManager.factory:ToggleTopView(false, true)
    end
    self:_UpdateFactoryMode(true)
end




PhaseLevel.m_forceEnableUISceneBlurKeys = HL.Field(HL.Table)




PhaseLevel._SetUISceneBlurEnabled = HL.Method(HL.Boolean) << function(self, enabled)
    local hgCamera = HGCamera.GetOrCreate(GameInstance.cameraManager.mainCamera)
    hgCamera:SetEnableUpdatingSceneFrostedGlass(enabled)
end




PhaseLevel.OnForceEnableUISceneBlur = HL.Method(HL.Table) << function(self, args)
    if not args.key then
        return
    end
    self.m_forceEnableUISceneBlurKeys = self.m_forceEnableUISceneBlurKeys or {}
    self.m_forceEnableUISceneBlurKeys[args.key] = args.enabled
    local shouldEnable = false
    for _, enabled in pairs(self.m_forceEnableUISceneBlurKeys) do
        if enabled then
            shouldEnable = true
            break
        end
    end
    self:_SetUISceneBlurEnabled(shouldEnable)
end




PhaseLevel.OnInputDeviceTypeChanged = HL.Method(HL.Table) << function(self, args)
    if DeviceInfo.isMobile then
        Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = "MobileController", enabled = DeviceInfo.usingController})
    end
end







PhaseLevel.s_LoginCheckFinishedInfo = HL.StaticField(HL.Table)

local Name_LoginCheck_CashShopOrderSettle = "LoginCheck_CashShopOrderSettle"
local Name_LoginCheck_MonthlypassPopup = "LoginCheck_MonthlypassPopup"
local Name_LoginCheck_StartGuide = "LoginCheck_StartGuide"
local Name_LoginCheck_ForceSNS = "LoginCheck_ForceSNS"
local Name_LoginCheck_ActivityCheckIn = "LoginCheck_ActivityCheckIn"



PhaseLevel.PerformLoginCheck = HL.Method() << function(self)
    logger.important(CS.Beyond.EnableLogType.MainHudActionQueue, "PhaseLevel.PerformLoginCheck")

    
    if not PhaseLevel.s_LoginCheckFinishedInfo then
        logger.important(CS.Beyond.EnableLogType.MainHudActionQueue, "Init PhaseLevel.s_LoginCheckFinishedInfo")
        PhaseLevel.s_LoginCheckFinishedInfo = {}
        LuaSystemManager.mainHudActionQueue:ToggleActionPlayIgnoreMainHud(Name_LoginCheck_CashShopOrderSettle, true)
        LuaSystemManager.mainHudActionQueue:ToggleActionPlayIgnoreMainHud(Name_LoginCheck_MonthlypassPopup, true)
        LuaSystemManager.mainHudActionQueue:ToggleActionPlayIgnoreMainHud(Name_LoginCheck_StartGuide, true)
        LuaSystemManager.mainHudActionQueue:ToggleActionPlayIgnoreMainHud(Name_LoginCheck_ForceSNS, true)
    end

    
    GameInstance.player.cashShopSystem.isRemindOrderChecked = true
    if not PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_CashShopOrderSettle] and CashShopUtils.haveRemainOrders()
            and GameInstance.player.mission:IsMissionCompleted("e0m0")  then
        PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_CashShopOrderSettle] = true 
        LuaSystemManager.mainHudActionQueue:AddRequest(Name_LoginCheck_CashShopOrderSettle, function(_)
            CashShopUtils.tryShowRemainOrderList(function()
                Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, Name_LoginCheck_CashShopOrderSettle)
            end)
        end, nil, true)
    end

    
    if not PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_MonthlypassPopup] and not Utils.isInDungeon() then
        PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_MonthlypassPopup] = true
        local needShowTimeStamps = GameInstance.player.monthlyPassSystem:GetNeedShowDailyPopupTimestamps()
        if needShowTimeStamps.Count > 0 then
            local needShowTimeStampsTable = {}
            for _, ts in pairs(needShowTimeStamps) do
                table.insert(needShowTimeStampsTable, ts)
            end
            LuaSystemManager.mainHudActionQueue:AddRequest(Name_LoginCheck_MonthlypassPopup, function(_)
                local ret = PhaseManager:OpenPhaseFast(PhaseId.ShopMonthlyPassPopUp, {
                    ShowTimeStamps = needShowTimeStampsTable,
                    EndCallback = function()
                        Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, Name_LoginCheck_MonthlypassPopup)
                    end
                })
                if not ret then
                    logger.error("LoginCheck时打开PhaseId.ShopMonthlyPassPopUp失败!")
                    Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, Name_LoginCheck_MonthlypassPopup)
                end
            end, nil, true)
        end
    end

    
    if not PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_StartGuide] then
        PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_StartGuide] = true
        LuaSystemManager.mainHudActionQueue:AddRequest(Name_LoginCheck_StartGuide, function(_)
            GameInstance.player.guide:TryCheckAndStartGuideGroup()
        end, nil, true)
    end

    
    if not PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_ForceSNS] then
        PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_ForceSNS] = true
        LuaSystemManager.mainHudActionQueue:AddRequest(Name_LoginCheck_ForceSNS, function(_)
            GameInstance.player.sns:TryCheckAndStartSNSForceDialog()
        end, nil, true)
    end

    
    self:_PerformLoginActivityCheck()

    logger.important(CS.Beyond.EnableLogType.MainHudActionQueue, "PhaseLevel.PerformLoginCheck END")
end



PhaseLevel._PerformLoginActivityCheck = HL.Method() << function(self)
    
    if UNITY_EDITOR and BEYOND_DEBUG and CS.Beyond.DebugDefines.disableCheckInLoginCheck then
        return
    end
    
    if Utils.isInDungeon() or Utils.isInFocusMode() then
        return
    end

    
    if PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_ActivityCheckIn] then
        return
    end
    PhaseLevel.s_LoginCheckFinishedInfo[Name_LoginCheck_ActivityCheckIn] = true

    
    if not PhaseManager:IsPhaseUnlocked(PhaseId.ActivityPopup) then
        return
    end
    
    if #ActivityUtils.getPopUpIds() == 0 then
        return
    end

    
    LuaSystemManager.mainHudActionQueue:AddRequest(Name_LoginCheck_ActivityCheckIn, function(_)
        local success = PhaseManager:OpenPhaseFast(PhaseId.ActivityPopup, {
            closeCallback = function()
                Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, Name_LoginCheck_ActivityCheckIn)
            end
        })
        if not success then
            logger.error("PhaseLevel.PerformActivityCheck 时打开 PhaseId.ActivityPopup 失败!")
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, Name_LoginCheck_ActivityCheckIn)
        end
    end, nil, true)
end




HL.Commit(PhaseLevel)
