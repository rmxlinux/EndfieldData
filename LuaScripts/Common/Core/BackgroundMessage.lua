

BackgroundMessage = HL.Class('BackgroundMessage')




BackgroundMessage.s_messages = HL.StaticField(HL.Table) << {
    
    ['AIBark'] = {
        
        [MessageConst.SHOW_AI_BARK] = 'ShowAIBark',
        
        [MessageConst.ON_IN_MAIN_HUD_CHANGED] = 'OnInMainHudChanged',
    },
    
    ['BattleAction'] = {
        
        [MessageConst.ON_CHANGE_THROW_MODE] = 'OnChangeThrowMode',
        
        [MessageConst.SHOW_WATER_DRONE_AIM] = 'EnterWaterDroneMode',
        
        [MessageConst.HIDE_WATER_DRONE_AIM] = 'ExitWaterDroneMode',
    },
    
    ['BlockGlitchTransition'] = {
        
        [MessageConst.PREPARE_BLOCK_GLITCH_TRANSITION] = 'PrepareBlockGlitchTransition',
        
        [MessageConst.SHOW_BLOCK_GLITCH_TRANSITION] = 'ShowBlockGlitchTransition',
    },
    
    ['BlueprintsUnlockHint'] = {
        
        [MessageConst.SHOW_BLUEPRINTS_UNLOCK_HINT] = 'ShowBlueprintsUnlockHint',
    },
    
    ['BoxGame'] = {
        
        [MessageConst.SHOW_BOX_GAME_PANEL] = 'ShowPanel',
    },
    
    ['CG'] = {
        
        [MessageConst.PLAY_CG] = "OnPlayVideo",
    },
    
    ['Dialog'] = {
        [MessageConst.ON_PRELOAD_DIALOG_PANEL] = 'OnPreloadDialogPanel',
    },
    
    ['DialogTimeline']={
        [MessageConst.ON_PRELOAD_DIALOG_TIMELINE_PANEL] = 'OnPreloadDialogTimelinePanel',
    },
    
    ['CharJoinToast'] = {
        
        [MessageConst.ON_CHAR_JOIN_BY_MAINLINE] = 'ShowCharJoinToast',
    },
    
    ['NaviTargetActionMenu'] = {
        
        [MessageConst.SHOW_NAVI_TARGET_ACTION_MENU] = 'ShowNaviTargetActionMenu',
    },
    
    ['CommonHudToast'] = {
        
        [MessageConst.ON_PHASE_LEVEL_ON_TOP] = 'OnEnterMainHud',
        
        [MessageConst.ON_GET_NEW_MAILS] = 'OnShowMailToast',
        
        [MessageConst.SHOW_SPECIAL_TOAST] = 'OnShowSpecialToast',
    },

    
    ['CommonItemToast'] = {
        
        [MessageConst.TOGGLE_COMMON_ITEM_TOAST] = 'ToggleCommonItemToast',
        
        [MessageConst.ON_PHASE_LEVEL_ON_TOP] = 'OnEnableCommonToast',
        
        [MessageConst.ON_PHASE_LEVEL_NOT_ON_TOP] = 'OnDisableCommonToast',
        
        [MessageConst.ON_ENABLE_COMMON_TOAST] = 'OnEnableCommonToast',
        
        [MessageConst.ON_DISABLE_COMMON_TOAST] = 'OnDisableCommonToast',
    },
    
    ['AdventureLevelUp'] = {
        
        [MessageConst.ON_ADVENTURE_EXP_CHANGE_FOR_TOAST] = "OnShowAdventureLevelUp",
    },
    
    ['CommonMask'] = {
        
        [MessageConst.ON_COMMON_MASK_HIGH_START] = 'OnCommonMaskStart',
        
        [MessageConst.ON_COMMON_MASK_END] = 'OnCommonMaskEnd',
    },
    
    ['CommonMaskLower'] = {
        
        [MessageConst.ON_COMMON_MASK_LOW_START] = 'OnCommonMaskLowerStart',
        
        [MessageConst.ON_COMMON_MASK_LOW_END] = 'OnCommonMaskLowerEnd',
    },
    
    ['CommonPopUp'] = {
        
        [MessageConst.SHOW_POP_UP] = 'ShowPopUp',
        [MessageConst.SHOW_POP_UP_CS] = 'ShowPopUpCS',
    },
    
    ['WeekRaidLeaveConfirm'] = {
        
        [MessageConst.SHOW_WEEK_RAID_LEAVE_CONFIRM] = 'ShowPopUp',
    },
    
    ['WeeklyRaidEnter'] = {
        
        [MessageConst.ON_WEEKLY_RAID_ENTER] = 'ShowWeeklyRaidEnter',
    },
    
    ['RaidMain'] = {
        
        [MessageConst.ON_WEEKLY_RAID_QUIT] = 'OnWeeklyRaidQuit',
        
        [MessageConst.ON_PHASE_LEVEL_ON_TOP] = 'OnPhaseLevelOnTop',
    },
    
    ['CommonToast'] = {
        
        [MessageConst.SHOW_TOAST] = 'OnShowToast',
        
        [MessageConst.SHOW_SYSTEM_TOAST] = 'OnShowSystemToast',
    },
    
    ['DungeonCommonToast'] = {
        
        [MessageConst.SHOW_DUNGEON_TOAST] = 'TryShow',
        
        [MessageConst.ON_SCENE_COLLECTION_MODIFY] = 'OnSceneCollectionModify',
    },
    
    ['CashShopToast'] = {
        
        [MessageConst.SHOW_CASH_SHOP_TOAST] = 'OnShowToast',
    },
    
    ['WorldLevelPreview'] = {
        
        [MessageConst.ON_WORLD_LEVEL_CHANGED] = 'ShowPreview',
    },
    
    ['FriendVisit'] = {
        
        [MessageConst.ON_FRIEND_VISIT_SPACESHIP] = 'OpenFriendVisit',
    },
    
    ['FriendList'] = {
        
        [MessageConst.ON_OPEN_VISIT_FRIEND_LIST] = 'OpenVisitFriendList',
    },
    
    ['FriendBusinessCardPreview'] = {
        
        [MessageConst.ON_OPEN_BUSINESS_CARD_PREVIEW] = 'TryStartBusinessCardPreview',
    },
    
    ['ControllerHint'] = {
        
        [MessageConst.SHOW_CONTROLLER_HINT] = 'ShowControllerHint',
        [MessageConst.TOGGLE_CONTROLLER_HINT] = 'ToggleControllerHint',
    },
    
    ['Debug'] = {
        
        [MessageConst.ON_LUA_INIT_FINISHED] = 'OnLuaInitFinished',
        
        [MessageConst.SET_DEBUG_PANEL_BLOCK_INPUT] = 'SetDebugPanelBlockInput',
    },
    
    ['DebugBlur'] = {
        
        [MessageConst.SHOW_DEBUG_BLUR] = "ShowDebugBlur",
    },
    
    ['DebugPhase'] = {
        
        [MessageConst.SHOW_DEBUG_PHASE] = 'ShowDebugPhase',
    },
    
    ['DebugText'] = {
        
        [MessageConst.UPDATE_DEBUG_TEXT] = 'UpdateDebugText',
    },
    
    ['DungeonSettlementPopup'] = {
        
        [MessageConst.ON_DUNGEON_COMPLETE] = "OnDungeonComplete",
        
        [MessageConst.ON_SHOW_DUNGEON_RESULT] = "OnShowDungeonResult",
    },
    
    ['DungeonCustomReward'] = {
        
        [MessageConst.TRY_START_SETTLEMENT] = "TryStartSettlement",
    },
    
    ['DungeonInfoPopup'] = {
        
        [MessageConst.ON_DUNGEON_GAME_INIT] = "TryToShow",
    },
    
    ['DungeonCharTutorialStepHud'] = {
        
        [MessageConst.OPEN_CHAR_TUTORIAL_STEP_HUD] = "OpenCharTutorialStepHud",
    },

    
    ['BlackBoxDiffBtn'] = {
        
        [MessageConst.ON_OPEN_SUB_GAME_TRACKINGS] = "OnOpenSubGameTrackings",
        
        [MessageConst.ON_CLOSE_SUB_GAME_TRACKINGS] = "OnCloseSubGameTrackings",
    },

    
    ['CommonTaskTrackHud'] = {
        
        [MessageConst.ON_OPEN_SUB_GAME_TRACKINGS] = "OnOpenSubGameTrackings",
        
        [MessageConst.ON_CLOSE_SUB_GAME_TRACKINGS] = "OnCloseSubGameTrack",
        
        [MessageConst.ON_OPEN_SCRIPT_CUSTOM_TASK_TRACKING] = "OnOpenLevelScriptCustomTask",
        
        [MessageConst.ON_CLOSE_SCRIPT_CUSTOM_TASK_TRACKING] = "OnCloseLevelScriptCustomTask",
        
        [MessageConst.ON_DEACTIVATE_COMMON_TASK_TRACK_HUD] = "OnDeactivateCommonTaskTrackHud",
    },

    
    ['CommonTaskTrackToast'] = {
        
        [MessageConst.ON_SHOW_COMMON_TASK_COUNTDOWN_TOAST] = "OnShowCommonTaskCountdownToast",
        
        [MessageConst.ON_SHOW_COMMON_TASK_TOAST_START] = "OnShowCommonTaskStartToast",
        
        [MessageConst.ON_SHOW_COMMON_TASK_TOAST_FINISH] = "OnShowCommonTaskFinishToast",
        
        [MessageConst.ON_SHOW_COMMON_TASK_TOAST_FAIL] = "OnShowCommonTaskFailToast",
    },
    
    ['CommonTaskTrackCountdown'] = {
        
        [MessageConst.ON_SHOW_COMMON_TASK_COUNTDOWN] = "OnShowCommonTaskCountdown",
        
        [MessageConst.ON_START_COMMON_TASK_COUNTING] = 'OnStartCommonTaskCounting',
    },

    
    ['FriendlyTips'] = {
        
        [MessageConst.ON_OPEN_FRIENDLY_TIPS] = '_OnOpenFriendlyTips',
    },
    ['EndingToast'] = {
        
        [MessageConst.SHOW_MISSION_END_GAME_PANEL] = '_OnShowEndingToast',
    },
    
    ['FacBuildMode'] = {
        
        [MessageConst.FAC_ENTER_BUILDING_MODE] = 'EnterBuildingMode',
        
        [MessageConst.FAC_ENTER_BELT_MODE] = 'EnterBeltMode',
        
        [MessageConst.FAC_ENTER_LOGISTIC_MODE] = 'EnterLogisticMode',
        
        [MessageConst.FAC_ENTER_BLUEPRINT_MODE] = 'EnterBlueprintMode',


        
        [MessageConst.FAC_BUILD_EXIT_CUR_MODE] = 'ExitCurMode',
        
        [MessageConst.FAC_BUILD_EXIT_CUR_MODE_FOR_CS] = 'ExitCurModeForCS',

        
        [MessageConst.ON_SQUAD_INFIGHT_CHANGED] = 'ExitCurModeForCS',
        
        [MessageConst.ON_PREPARE_NARRATIVE] = 'ExitCurModeForCS',
        
        [MessageConst.ON_SCENE_LOAD_START] = 'ExitCurModeForCS',
        
        [MessageConst.ALL_CHARACTER_DEAD] = 'ExitCurModeForCS',
        
        [MessageConst.ON_TELEPORT_SQUAD] = 'ExitCurModeForCS',
        
        [MessageConst.PLAY_CG] = 'ExitCurModeForCS',
        
        [MessageConst.ON_PLAY_CUTSCENE] = 'ExitCurModeForCS',
        
        [MessageConst.ON_DIALOG_START] = 'ExitCurModeForCS',
        
        [MessageConst.ALL_CHARACTER_DEAD] = 'ExitCurModeForCS',
        
        [MessageConst.ON_REPATRIATE] = 'ExitCurModeForCS',


        
        [MessageConst.FAC_SET_ENABLE_CONFIRM_BUILD] = 'SetEnableConfirmBuild',
        
        [MessageConst.FAC_SET_ENABLE_EXIT_BUILD_MODE] = 'SetEnableExitBuildMode',
    },
    
    ['FacDestroyMode'] = {
        
        [MessageConst.FAC_ENTER_DESTROY_MODE] = 'EnterMode',

        
        [MessageConst.FAC_EXIT_DESTROY_MODE] = 'ExitMode',
        
        [MessageConst.FAC_EXIT_DESTROY_MODE_FOR_CS] = 'ExitModeForCS',
        
        [MessageConst.ALL_CHARACTER_DEAD] = 'ExitModeForCS',
        
        [MessageConst.ON_REPATRIATE] = 'ExitModeForCS',

    },
    
    ['ManualCraft'] = {
        
        [MessageConst.ON_GET_NEW_MANUAL_FORMULA] = 'OnGetNewManualFormula',
        [MessageConst.ON_UNLOCK_MANUAL_CRAFT] = 'OnUnlockManualCraft',

    },

    
    ['FacMiniPowerHud'] = {
        
        [MessageConst.ON_ENTER_FACTORY_MODE] = 'OnEnterFactoryMode',
        
        [MessageConst.ON_ENTER_BUILDING_MODE] = 'OnEnterBuildingMode',
    },
    
    ['FacPowerPoleLinkingLabel'] = {
        
        [MessageConst.SHOW_POWER_POLE_LINKING_LABEL] = 'ShowLabel',
        
        [MessageConst.HIDE_POWER_POLE_LINKING_LABEL] = 'HideLabel',
    },
    
    ['FacPowerPoleTravelHint'] = {
        
        [MessageConst.ON_ENTER_BUILDING_MODE] = 'OnEnterBuildingMode',
        
        [MessageConst.ON_EXIT_BUILDING_MODE] = 'OnExitBuildingMode',
        
        [MessageConst.ON_BUILD_POWER_POLE_TRAVEL_HINT] = 'OnBuild',
        
        [MessageConst.ON_MOVE_POWER_POLE_TRAVEL_HINT] = 'OnMove',
    },
    
    ['FacPowerPoleAutoConnectHint'] = {
        
        [MessageConst.ON_ENTER_BUILDING_MODE] = 'OnEnterBuildingMode',
        
        [MessageConst.ON_EXIT_BUILDING_MODE] = 'OnExitBuildingMode',
        
        [MessageConst.ON_BUILD_POWER_POLE_TRAVEL_HINT] = 'OnBuild',
        
        [MessageConst.ON_MOVE_POWER_POLE_TRAVEL_HINT] = 'OnMove',
    },

    
    ['FacQuickBar'] = {
        
        [MessageConst.SHOW_FAC_QUICK_BAR] = 'ShowFacQuickBar',
    },
    
    ['FacRegionUnlockPopup'] = {
        
        [MessageConst.FAC_ON_REGION_UNLOCKED] = 'OnRegionUnlocked',
    },
    
    ['FacTechTreePopUp'] = {
        
        [MessageConst.SHOW_TECH_TREE_POP_UP] = 'ShowPopUp',
    },
    
    ['FacTopView'] = {
        
        [MessageConst.ON_TOGGLE_FAC_TOP_VIEW] = 'OnToggleFacTopView',
    },
    
    ['FacUnloaderSelect'] = {
        
        [MessageConst.FAC_SHOW_UNLOADER_SELECT] = 'ShowUnloaderSelect',
    },
    
    ['FakeControllerSmallMenu'] = {
        
        [MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU] = 'ShowAsControllerSmallMenu',
    },
    
    ['Formula'] = {
        
        [MessageConst.FAC_SHOW_FORMULA] = 'ShowFormula',
    },
    
    ['GeneralTracker'] = {
        
        [MessageConst.SHOW_MISSION_TRACKER] = 'OnShowMissionTracker',
    },
    
    ['Guide'] = {
        
        [MessageConst.SHOW_GUIDE_STEP] = 'ShowGuideStep',
        
        [MessageConst.SHOW_GUIDE_EMPTY_MASK] = 'ShowGuideEmptyMask',
    },
    
    ['GuideLimited'] = {
        
        [MessageConst.SHOW_LIMITED_GUIDE] = 'OnShowLimitedGuide',
        [MessageConst.ON_WIKI_ENTRY_READ] = 'OnWikiEntryRead',
    },
    
    ['GuideMedia'] = {
        
        [MessageConst.SHOW_GUIDE_MEDIA] = 'ShowGuideMedia',
    },
    
    ['HeadLabel'] = {
        
        [MessageConst.PRE_LEVEL_START] = '_OnLevelPreStart',
        
        [MessageConst.ON_ADD_HEAD_LABEL] = '_OnAddHeadLabel',
        
        [MessageConst.ON_REMOVE_HEAD_LABEL] = '_OnRemoveHeadLabel',
        
        [MessageConst.ON_ENV_TALK_CHANGED] = '_OnEnvTalkChanged',
        
        [MessageConst.ON_HEAD_LABEL_STATE_CHANGED] = '_OnStateChanged',
        
        [MessageConst.ON_HEAD_LABEL_GIFT_CHANGED] = '_OnGiftChanged',
    },
    
    ['ItemTips'] = {
        
        [MessageConst.SHOW_ITEM_TIPS] = 'ShowItemTips',
    },
    ['WikiGuideTips'] = {
        
        [MessageConst.SHOW_WIKI_REF_TIPS] = 'ShowTips'
    },
    
    ['HyperlinkTips'] = {
        
        [MessageConst.SHOW_HYPERLINK_TIPS] = 'ShowHyperlinkTips',
        [MessageConst.HIDE_HYPERLINK_TIPS] = 'HideHyperlinkTips',
    },
    
    ['HyperlinkPopup'] = {
        
        [MessageConst.CS_SHOW_HYPERLINK_POPUP] = 'ShowHyperlinkPopupSingle',
        [MessageConst.SHOW_HYPERLINK_POPUP_BY_GROUP_ID] = 'ShowHyperlinkPopupByGroupId',
    },
    
    ['LeadingCharacter'] = {
        
        [MessageConst.ON_OPEN_LEADING_CHARACTER] = 'OnOpen',
    },
    
    ['LevelToast'] = {
        
        [MessageConst.SHOW_LEVEL_COLLECTION_TOAST] = 'OnShowLevelCollectionToast',
        
        [MessageConst.SHOW_LEVEL_COLLECTION_TOAST_SIMPLE] = 'OnShowLevelCollectionToastSimple',
    },
    
    ['Loading'] = {
        
        [MessageConst.OPEN_LOADING_PANEL] = 'OpenLoadingPanel',
    },
    
    ['TeleportLoading'] = {
        
        [MessageConst.OPEN_TELEPORT_LOADING_PANEL] = 'OpenTeleportLoadingPanel',
    },
    
    ['LuaConsole'] = {
        
        [MessageConst.ON_LUA_INIT_FINISHED] = 'Init',
        
        [MessageConst.TOGGLE_LUA_CONSOLE] = 'ToggleSelf',
        
        [MessageConst.DEV_ONLY_TOGGLE_PANEL] = 'DevOnlyTogglePanel',
        
        [MessageConst.ON_DISPOSE_LUA_ENV] = 'OnDisposeLuaEnv',
        
        [MessageConst.ON_LUA_DEBUG_SOCKET_MESSAGE] = 'OnLuaDebugSocketMessage',
        
        [MessageConst.SYNC_CLIENT_REMOTE_TASK] = 'SyncClientRemoteTask',
    },
    
    ['MainHud'] = {
        
        [MessageConst.CLEAR_SCREEN_ON] = '_OnClearScreenOn',
        
        [MessageConst.CLEAR_SCREEN_OFF] = '_OnClearScreenOff',
        
        [MessageConst.CLEAR_SCREEN_ON_EXCEPT_SOME_PANEL] = '_OnClearScreenOnExceptSomePanel',
        
        [MessageConst.CLEAR_SCREEN_OFF_EXCEPT_SOME_PANEL] = '_OnClearScreenOffExceptSomePanel',
    },
    
    ['Map'] = {
        
        [MessageConst.SELECT_MAP_MARK] = 'OnSelectMark',
    },
    
    ['MissionCompletePop'] = {
        
        [MessageConst.ON_CHAPTER_START] = 'OnChapterStart',
        
        [MessageConst.ON_CHAPTER_COMPLETED] = 'OnChapterCompleted',
        
        [MessageConst.ON_SHOW_CHAPTER_PANEL_DIRECT] = 'OnShowPanelDirectly',
    },

    
    ['MissionHud'] = {
        [MessageConst.ON_HUD_COMPLETE_ORDER_ENQUEUE] = 'OnMissionCompleteOrderEnqueue',
    },
    ['MissionHudMini'] = {
        [MessageConst.ON_TOGGLE_FAC_TOP_VIEW] = 'OnFacTopViewChanged',
    },
    
    ['PRTSStoryCollDetail'] = {
        
        [MessageConst.SHOW_PRTS_STORY_COLL_DETAIL] = 'ShowSelf',
    },
    
    ['PRTSInvestigateDetail'] = {
        
        [MessageConst.SHOW_PRTS_INVEST_DETAIL] = 'ShowSelf',
    },
    
    ['Puzzle'] = {
        
        [MessageConst.OPEN_PUZZLE_PANEL] = 'OpenPuzzlePanel',
    },
    ['PuzzlePickupToast'] = {
        
        [MessageConst.ON_BLOCK_PICKUP] = 'OnBlockPickup',
    },
    
    ['Reading'] = {
        
        [MessageConst.ON_OPEN_PRTS_READING_PANEL] = 'OnOpenReadingPhase',
    },
    
    ['RemoteComm'] = {
        
        
    },
    
    ['RepairInteractive'] = {
        
        [MessageConst.SHOW_REPAIR_INTERACTIVE] = 'ShowRepairInteractive',
        
        [MessageConst.SHOW_REPAIR_INTERACTIVE_BY_MINIGAME] = 'ShowRepairInteractiveByMinigame',
        
        [MessageConst.FORCE_CLOSE_REPAIR_INTERACTIVE] = 'ForceCloseRepairInteractive',
    },
    
    ['InteractOption'] = {
        
        [MessageConst.FAC_TOGGLE_SUB_BUILDING_OPT_USE_INDEX_NAME_FOR_GUIDE] = 'FacToggleSubBuildingOptUseIndexNameForGuide',
    },
    
    ['RewardsPopupCenter'] = {
        
        [MessageConst.SHOW_REWARDS_POPUP_CENTER] = 'ShowRewardsPopupCenter',
        
        [MessageConst.SHOW_REWARDS_POPUP_CENTER_BY_REWARD_ID] = 'ShowRewardsPopupCenterByRewardId',
    },
    
    ['RewardsPopUpForBlackBox'] = {
        
        [MessageConst.ON_SHOW_BLACKBOX_RESULT] = 'OnShowBlackboxResult',
    },
    
    ['RewardsPopUpForCraft'] = {
        
        [MessageConst.SHOW_CRAFT_REWARDS] = 'ShowCraftRewards',
    },
    
    ['RewardsPopUpForSystem'] = {
        
        [MessageConst.SHOW_SYSTEM_REWARDS] = 'ShowSystemRewards',
        
        [MessageConst.CS_SHOW_SYSTEM_REWARDS] = 'CSShowSystemRewards',
    },
    
    ['RaidUpgradePopup'] = {
        
        [MessageConst.ON_WEEK_RAID_TECH_MODIFY] = 'OnRaidTechModify',
    },
    
    ['SDKApplicationMask'] = {
        
        [MessageConst.ON_START_WEB_APPLICATION] = 'OnStartWebApplication',
    },
    
    ['Sketch'] = {
        
        [MessageConst.SHOW_SKETCH_PANEL] = 'TryOpenSketch',
    },
    
    ['SkillUpgradePopUp'] = {
        
        [MessageConst.ON_SKILL_UPGRADE_SUCCESS] = 'OnSkillLevelUpgraded',
        [MessageConst.ON_CHAR_TALENT_UPGRADE] = 'OnTalentLevelUpgraded',

    },
    
    ['SubmitCollection'] = {
        
        [MessageConst.SHOW_SUBMIT_ETHER] = 'ShowSubmitEther',
    },
    
    ['CharacterSummon'] = {
        
        [MessageConst.SHOW_CHARACTER_SUMMON] = 'ShowCharacterSummon',
    },

    
    ['SpaceshipVisitor'] = {
        
        [MessageConst.SHOW_SPACESHIP_VISITOR] = 'ShowSpaceshipVisitor',
    },
    
    ['SpaceshipRoomClueSchedule'] = {
        
        [MessageConst.SHOW_SPACESHIP_CLUE_SCHEDULE] = 'ShowSpaceshipClueSchedule',
    },
    
    ['SpaceshipRoomClueSettlement'] = {
        
        [MessageConst.SHOW_SPACESHIP_CLUE_SETTLEMENT] = 'ShowSpaceshipClueSettlement',
    },
    
    ['SpaceshipRoomClueGift'] = {
        
        [MessageConst.SHOW_SPACESHIP_CLUE_GIFT] = 'ShowSpaceshipClueGift',
    },

    
    ['SubmitItem'] = {
        
        [MessageConst.SHOW_SUBMIT_PANEL] = 'ShowPanel',
    },
    
    ['SubmitItemInteractive'] = {
        
        [MessageConst.SHOW_SUBMIT_INTERACTIVE_PANEL] = 'ShowPanel',
    },
    
    ['TransparentBlockInput'] = {
        
        [MessageConst.SHOW_BLOCK_INPUT_PANEL] = 'OnShowBlockInputPanel',
    },
    
    ['UIDPanel'] = {
        
        [MessageConst.ENTER_MAIN_GAME] = 'OnEnterMainGame',
    },
    
    ['WaterMarkGrid'] = {
        
        [MessageConst.ENTER_MAIN_GAME] = 'OnEnterMainGame',
    },
    
    ['UpgradePopUp'] = {
        
        [MessageConst.SHOW_LEVEL_UP_POPUP] = "ShowLevelUpPopUp",
        
        [MessageConst.SHOW_BREAK_POPUP] = "ShowBreakPopUp",
    },
    
    ['WalletBar'] = {
        
        [MessageConst.SHOW_WALLET_BAR] = 'ShowWalletBar',
    },
    
    ['SNSBarkerSide'] = {
        
        [MessageConst.ON_SNS_FORCE_DIALOG_PANEL_OPEN] = 'OnForceDialogPanelOpen',
        
        [MessageConst.INTERRUPT_FORCE_SNS] = "InterruptForceSNS"
    },
    
    ['SNSNoticeForceToast'] = {
        
        [MessageConst.ON_SHOW_SNS_NEW_DIALOG_TOAST] = 'OnShowSNSNewDialogToast',
    },
    
    ['SortPopOut'] = {
        
        [MessageConst.SHOW_SORT_POP_OUT] = '_ShowSelf',
    },
    
    ['RecycleBinScanUI'] = {
        
        [MessageConst.ON_ADD_RECYCLE_BIN] = '_OnAddRecycleBinUI',
        [MessageConst.ON_REMOVE_RECYCLE_BIN] = '_OnRemoveRecycleBinUI',
        [MessageConst.ON_UPDATE_RECYCLE_BIN] = '_OnUpdateRecycleBinUI',
    },
    
    ['FacCultivate'] = {
        
        [MessageConst.ON_OPEN_CROP] = '_OnOpenCrop',
    },
    
    ['FacFertilization'] = {
        
        [MessageConst.ON_OPEN_FERTILIZATION] = '_OnOpenFertilization',
    },
    
    ['DoodadMineCoreScanUI'] = {
        
        [MessageConst.ON_ADD_DOODAD_MINE_CORE] = '_OnAddDoodadMineCoreUI',
        [MessageConst.ON_REMOVE_DOODAD_MINE_CORE] = '_OnRemoveDoodadMineCoreUI',
        [MessageConst.ON_UPDATE_DOODAD_MINE_CORE] = '_OnUpdateDoodadMineCoreUI',
    },
    
    ['DoodadPlantCoreScanUI'] = {
        
        [MessageConst.ON_ADD_DOODAD_PLANT_CORE] = '_OnAddDoodadPlantCoreUI',
        [MessageConst.ON_REMOVE_DOODAD_PLANT_CORE] = '_OnRemoveDoodadPlantCoreUI',
        [MessageConst.ON_UPDATE_DOODAD_PLANT_CORE] = '_OnUpdateDoodadPlantCoreUI',
        [MessageConst.ON_REFRESH_DOODAD_PLANT_CORE] = '_OnRefreshDoodadPlantCoreUI',
    },
    
    ['SettlementCommonToast'] = {
        
        [MessageConst.SHOW_SETTLEMENT_UNLOCK_TOAST] = '_OnShowLink',
        
        [MessageConst.SHOW_SETTLEMENT_UPGRADE_TOAST] = '_OnShowUpgrade',
    },
    
    ['CommonWorldUI'] = {
        
        [MessageConst.ADD_COMMON_WORLD_UI] = '_OnAddWorldUI',
        
        [MessageConst.REMOVE_COMMON_WORLD_UI] = '_OnRemoveWorldUI',
    },
    
    ['CommonHoverTip'] = {
        
        [MessageConst.SHOW_COMMON_HOVER_TIP] = '_OnShowTip',
    },
    
    ['FacTopViewLowerCfg'] = {
        [MessageConst.ON_TOGGLE_FAC_TOP_VIEW] = 'OnToggleFacTopView',
    },
    
    ['ControllerNaviTarget'] = {
        [MessageConst.ON_INPUT_DEVICE_TYPE_CHANGED] = 'OnInputDeviceTypeChanged',
        [MessageConst.ON_OPEN_INIT_PANELS] = 'OnInputDeviceTypeChanged',
    },
    
    ['ControllerNaviTextTarget'] = {
        [MessageConst.SHOW_CONTROLLER_NAVI_TEXT_HINT] = 'ShowHint',
        [MessageConst.HIDE_CONTROLLER_NAVI_TEXT_HINT] = 'HideHint',
    },
    
    ['SettlementDefenseTerminal'] = {
        
        [MessageConst.SHOW_TOWER_DEFENSE_TERMINAL_PANEL] = 'ShowTerminalPanel',
    },
    
    ['BombAim'] = {
        [MessageConst.SHOW_BOMB_AIM] = '_OnShowBombAim',
    },
    ['SpaceshipCharTips'] = {
        
        [MessageConst.SHOW_SPACESHIP_CHAR_TIPS] = 'ShowTips',
    },
    
    ['CommonPicture'] = {
        [MessageConst.SHOW_COMMON_PICTURE] = '_OnShowPicture',
    },
    
    ['CommonVideo'] = {
        [MessageConst.SHOW_COMMON_VIDEO] = '_OnShowVideo',
    },
    
    ['CharFormationSkillTips'] = {
        [MessageConst.SHOW_CHAR_SKILL_TIP] = 'ShowCharSkillTip',
    },
    
    ['LiquidPool'] = {
        
        [MessageConst.SHOW_LIQUID_POOL] = 'ShowLiquidPool',
    },
    
    ['CommonFilter'] = {
        
        [MessageConst.SHOW_COMMON_FILTER] = 'ShowCommonFilter',
    },
    
    ['SettlementDefenseTransit'] = {
        
        [MessageConst.ON_ENTER_TOWER_DEFENSE_DEFENDING_PHASE] = 'OnEnterTowerDefenseDefendingPhase',
    },
    
    ['SettlementDefenseFinish'] = {
        
        [MessageConst.ON_TOWER_DEFENSE_LEVEL_FINISHED] = 'OnTowerDefenseLevelFinished',
        
        [MessageConst.ON_TOWER_DEFENSE_LEVEL_HUD_CLEARED] = 'OnTowerDefenseLevelCleared',
        
        [MessageConst.ON_TOWER_DEFENSE_LEVEL_UNLOCKED] = "OnTowerDefenseLevelUnlocked"
    },
    
    ['SettlementDefenseFinishFail'] = {
        
        [MessageConst.ON_TOWER_DEFENSE_LEVEL_FINISHED] = 'OnTowerDefenseLevelFinished',
        
        [MessageConst.ON_TOWER_DEFENSE_LEVEL_HUD_CLEARED] = 'OnTowerDefenseLevelCleared',
    },
    
    ['CharInfoTips'] = {
        
        
        [MessageConst.SHOW_CHAR_TACTICAL_ITEM_TIP] = 'ShowCharTacticalItemTips',
    },
    
    ['SpaceshipHudTips'] = {
        [MessageConst.ON_LOADING_PANEL_CLOSED] = 'OnLoadingPanelClosed',
        [MessageConst.ON_TELEPORT_LOADING_PANEL_CLOSED] = 'OnLoadingPanelClosed',
    },
    
    ['SpaceshipCabinInfoDisplay'] = {
        [MessageConst.SS_REGISTER_STATUS_BAR] = 'RegisterStatusBar',
        [MessageConst.SS_REGISTER_CHAR_INFO_PANEL] = 'RegisterCharInfoPanel',
    },
    
    ['RacingDungeonToast'] = {
        
        
        [MessageConst.SHOW_RACING_DUNGEON_TOAST] = 'OnShowToast',
        [MessageConst.ON_ENTER_RACING_DUNGEON] = 'OnEnterRacingDungeon',
    },
    
    ['RacingDungeonFinished'] = {
        
        
        [MessageConst.ON_RACING_DUNGEON_TLEMENT] = 'OnFinish',
    },
    
    ['RacingDungeonMapToast'] = {
        
        
        [MessageConst.SHOW_RACING_DUNGEON_MAP_TOAST] = 'OnShowToast',
    },
    
    ['RacingGoalToast'] = {
        
        
        [MessageConst.SHOW_RACING_DUNGEON_ACHIEVEMENT_TOAST] = 'OnShowToast',
    },
    
    ['MapRegionToast'] = {
        
        
        [MessageConst.SHOW_MAP_REGION_TOAST] = 'RequestShowMapRegionToast',
        
        [MessageConst.ON_LOADING_PANEL_OPENED] = 'ClearAllMapRegionToast',
        
        [MessageConst.ON_TELEPORT_LOADING_PANEL_OPENED] = 'ClearAllMapRegionToast',
    },
    
    ['DeathInfo'] = {
        
        
        [MessageConst.SHOW_DEATH_INFO] = 'ShowDeathInfo',
    },
    
    ['ImportantRewardPopup'] = {
        
        [MessageConst.ON_GET_IMPORTANT_REWARD_ITEM] = 'OnGetImportantRewardItem',
    },
    
    ['RaceModuleRank'] = {
        
        [MessageConst.SHOW_RACE_MODULE_RANK_UI] = 'ShowRaceModuleRankUI',
        [MessageConst.CLOSE_RACE_MODULE_RANK_UI] = 'CloseRaceModuleRankUI',
    },
    
    ['PlayerRename'] = {
        
        [MessageConst.SET_PLAYER_NAME_START] = 'OnSetPlayerNameStart',
    },
    
    ['FacTechPointGainedToast'] = {
        
        [MessageConst.ON_FAC_TECH_POINT_GAINED] = 'OnFacTechPointGained',
    },
    
    ['CharacterFootBarUpgrade'] = {
        
        [MessageConst.ON_DASH_COUNT_MAX_CHANGED] = 'OnDashCountMaxChanged',
    },
    
    ['CharInfoAttributeHint'] = {
        
        [MessageConst.CHAR_INFO_SHOW_FC_ATTR_HINT] = 'CharInfoShowFCAttrHint',
        
        [MessageConst.CHAR_INFO_SHOW_SC_ATTR_HINT] = 'CharInfoShowSCAttrHint',
    },
    
    ['LiquidPoolScanUI'] = {
        
        [MessageConst.ON_ADD_LIQUID_POOL] = '_OnAddLiquidPoolUI',
        [MessageConst.ON_REMOVE_LIQUID_POOL] = '_OnRemoveLiquidPoolUI',
    },
    
    ['Marquee'] = {
        
        [MessageConst.ON_MARQUEE_START] = 'OnMarqueeStart',
    },
    ['CommonBottomToast'] = {
        [MessageConst.SHOW_BOTTOM_TOAST] = 'OnShowToast',
        [MessageConst.CLOSE_BOTTOM_TOAST] = 'OnCloseToast',
    },
    
    ['CommonBlockMask'] = {
        
        [MessageConst.ADD_COMMON_BLOCK_MASK] = 'AddCommonBlockMask',
    },
    
    ['CommonTitleTips'] = {
        
        [MessageConst.SHOW_COMMON_TITLE_TIPS] = 'ShowTitleTips',
        
        [MessageConst.HIDE_COMMON_TITLE_TIPS] = 'HideTitleTips',
    },
    
    ["WeeklyRaidSettlement"] = {
        
        [MessageConst.ON_WEEK_RAID_SETTLEMENT] = 'OnWeekRaidSettlement',
    },
    
    ['GuideSlideScreen'] = {
        [MessageConst.SHOW_GUIDE_SLIDE_SCREEN_PANEL] = 'ShowGuideSlideScreenPanel',
    },
    
    ['GameSetting'] = {
        
        [MessageConst.ON_LOGIN_CLICK_SETTING_BTN] = 'OpenGameSettingPhase',
        
        [MessageConst.ON_SYSTEM_DISPLAY_SIZE_CHANGED] = 'OnSystemDisplaySizeChanged',
    },
    
    ['ItemDragHelper'] = {
        
        [MessageConst.SHOW_ITEM_DRAG_HELPER] = 'ShowItemDragHelper',
    },
    
    ['InputFieldBg'] = {
        
        [MessageConst.ON_SHOW_INPUT_FIELD_BG] = 'OnInputFieldBgInit',
    },
    
    ['DomainUpgrade'] = {
        
        [MessageConst.ON_DOMAIN_DEVELOPMENT_EXP_CHANGE] = "ShowUpgrade",
    },
    
    ['GenderChange'] = {
        
        [MessageConst.GENDER_CHANGE_START] = "OnGenderChangeStart",
    },
    
    ['WaterDroneAim'] = {
        [MessageConst.SHOW_WATER_DRONE_AIM] = 'OnShowWaterDroneAim',
    },
    
    ['WaterDroneBag'] = {
        [MessageConst.SHOW_WATER_DRONE_BAG] = 'OnShowWaterDroneBag',
    },
    
    ['SmallEnergyPointScanUI'] = {
        
        [MessageConst.ON_ADD_SMALL_ENERGY_POINT_UI] = 'OnAddSmallEnergyPointUI',
        
        [MessageConst.ON_REMOVE_SMALL_ENERGY_POINT_UI] = 'OnRemoveSmallEnergyPointUI',
    },
    
    ['DramaticPerformanceBag'] = {
        [MessageConst.SHOW_DRAMATIC_PERFORMANCE_BAG] = 'ShowBag',
    },
    
    ['DramaticPerformanceEmpty'] = {
        [MessageConst.OPEN_DRAMATIC_PERFORMANCE_EMPTY_UI] = 'ExecuteShow',
        [MessageConst.CLOSE_DRAMATIC_PERFORMANCE_EMPTY_UI] = 'ExecuteClose',
    },
    
    ['SpaceShipCharPoster'] = {
        
        [MessageConst.ON_SPACESHIP_LEVEL_START] = 'OpenSpaceshipCharPoster',
        
        [MessageConst.ON_SWITCH_LANGUAGE] = 'OpenSpaceshipCharPoster',
    },
    ['Snapshot'] = {
        
        [MessageConst.ON_SHOW_SNAPSHOT] = 'ShowSnapshot',
    },
    
    ['SpaceshipCollectionBooth'] = {
        
        [MessageConst.OPEN_SPACESHIP_SHOWCASE_PANEL] = 'OpenSpaceshipShowcasePanel',
    },
    
    ['ShopTrade'] = {
        
        [MessageConst.OPEN_DOMAIN_FRIEND_SHOP] = 'OpenDomainFriendShop',
        
        [MessageConst.OPEN_DOMAIN_SHOP] = 'OpenDomainShop',
    },
    
    ['SpaceshipControlCenter'] = {
        
        [MessageConst.OPEN_SPACESHIP_CONTROL_CENTER] = 'OpenControlCenter',
    },
    ['SSReceptionRoomWeaponPoster'] = {
        [MessageConst.ON_INT_SS_WEAPON_POSTER] = "OpenReceptionRoomPosterPanel",
    },
    ['SSReceptionRoomCharPoster'] = {
        [MessageConst.ON_INT_SS_CHAR_POSTER] = "OpenReceptionRoomPosterPanel",
    },
    
    ['DebugInputRecord'] = {
        
        [MessageConst.TOGGLE_DEBUG_INPUT_RECORD] = 'OnToggleDebugInputRecord',
    },
    
    ['CommonPOIUpgradeToast'] = {
        
        [MessageConst.ON_COMMON_POI_UNLOCKED] = 'OnCommonPOIUnlocked',
        
        [MessageConst.ON_COMMON_POI_LEVEL_UP] = 'OnCommonPOILevelUp',
    },
    
    ['RecycleBinNoticeToast'] = {
        
        [MessageConst.ON_RECYCLE_BIN_UPGRADE_AND_COLLECTED] = 'OnRecycleBinUpgradeAndCollected',
    },
    
    ["VideoPreloader"] = {
        [MessageConst.PRELOAD_FMV_IN_CINEMATIC] = "OnPreloadVideo",
    },
    ["EquipFormulaRewardPopup"] = {
        
        [MessageConst.SHOW_REWARD_EQUIP_FORMULA] = "ShowRewardEquipFormula",
    },
    ['KiteStation'] = {
        
        [MessageConst.ON_SHOW_KITESTATION] = 'ShowKiteStation',
    },
    ['SpaceshipRoomUpgrade'] = {
        [MessageConst.ON_INT_SPACESHIP_ROOM] = "OnIntSSRoom",
        [MessageConst.SPACESHIP_ON_ROOM_DECONSTRUCT] = "OnRoomDeconstruct",
    },
    
    ["CommonShare"] = {
        [MessageConst.SHOW_COMMON_SHARE_PANEL] = "ScreenCaptureAndShare",
    },
    
    ["TemporaryEmptyFreezeWorld"] = {
        
        [MessageConst.OPEN_FREEZE_WORLD_PANEL] = "OpenFreezeWorldPanel",
        
        [MessageConst.CLOSE_FREEZE_WORLD_PANEL] = "CloseFreezeWorldPanel",
        
        [MessageConst.ON_APPLICATION_PAUSE] = "OnApplicationPause",
    },
    
    ["CommonIntro"] = {
        
        [MessageConst.SHOW_INTRO] = "ShowIntro",
    },
    
    ["AchievementToast"] = {
        
        [MessageConst.ON_ACHIEVEMENT_UPDATE] = "RequestAchievementToasts",
        
        [MessageConst.ON_ENABLE_ACHIEVEMENT_TOAST] = "EnableAchievementToast",
        
        [MessageConst.ON_DISABLE_ACHIEVEMENT_TOAST] = "DisableAchievementToast",
        
        [MessageConst.ON_LOADING_PANEL_CLOSED] = "EnableAchievementToastByLoading",
        
        [MessageConst.ON_LOADING_PANEL_OPENED] = "DisableAchievementToastByLoading",
        
        [MessageConst.ON_TELEPORT_LOADING_PANEL_CLOSED] = "EnableAchievementToastByLoading",
        
        [MessageConst.ON_TELEPORT_LOADING_PANEL_OPENED] = "DisableAchievementToastByLoading",
    },
    
    ["AchievementList"] = {
        
        [MessageConst.SHOW_ACHIEVEMENT] = "ShowAchievement",
    },
    
    ["AchievementMain"] = {
        
        [MessageConst.OPEN_ACHIEVEMENT_MAIN_PANEL] = "OpenAchievementMainPanel",
    },
    
    ["FocusModeToast"] = {
        
        [MessageConst.SHOW_FOCUS_MODE_TOAST] = "ShowToast",
    },
    ["StoryModeToast"] = {
        [MessageConst.GAME_MODE_ENABLE] = "OnGameModeEnable",
        [MessageConst.GAME_MODE_DISABLE] = "OnGameModeDisable",
    },
    ["SpaceshipReceptionDisplay"] = {
        [MessageConst.ON_INT_SS_SCREEN_POSTER] = "OnIntScreen",
        
        [MessageConst.ON_CONFIRM_GENDER] = 'ResetPicture',
    },
    ["InputDeviceChangePopup"] = {
        [MessageConst.SHOW_INPUT_DEVICE_CHANGE_POPUP] = "OnShowInputDeviceChangePopup",
    },
    
    ["WorldEnergyPointCustomReward"] = {
        
        [MessageConst.WORLD_ENERGY_POINT_TRY_START_SETTLEMENT] = "TryStartSettlement"
    },
    
    ["WorldEnergyPointSettlement"] = {
        
        [MessageConst.ON_SHOW_WORLD_ENERGY_POINT_RESULT] = "OnShowWorldEnergyPointResult"
    },
    
    ['CommonProgress'] = {
        
        [MessageConst.ON_OPEN_PROGRESS] = '_OnProgressOpen',
    },
    
    ['HudLayout'] = {
        
        [MessageConst.ON_SCREEN_SIZE_CHANGED] = "OnScreenSizeChanged",
    },
    
    ['QuickMenu'] = {
        
        [MessageConst.TOGGLE_QUICK_MENU_RELEASE_CLOSE] = "OnToggleReleaseClose",
    },
    
    ['CommonBlackOut'] = {
        
        [MessageConst.START_COMMON_BLACK_OUT] = "StartCommonBlackOut",
    },
    
    ['BattlePassWeaponCase'] = {
        
        [MessageConst.OPEN_BP_WEAPON_CASE] = "OpenBPWeaponCase",
    },
    
    ['ShopMonthlyPass'] = {
        
        [MessageConst.ON_SYNC_MONTHLY_CARD_DATA] = "OnSyncMonthlyCardData",
    },
    ['CommonTips'] = {
        [MessageConst.SHOW_COMMON_TIPS] = 'ShowCommonTips',
    },
    
    ['DomainDepotDeliverToast'] = {
        
        [MessageConst.ON_START_DOMAIN_DEPOT_DELIVER] = "ShowDeliverRecvToast",
        
        [MessageConst.ON_FINISH_DOMAIN_DEPOT_DELIVER] = "ShowDeliverSendToast",
        
        [MessageConst.ON_CLEAR_DOMAIN_DEPOT_DELIVERING_INST] = "ClearDeliverToast",
    },
    ['ValuableDepot'] = {
        
        [MessageConst.ON_ITEM_COUNT_CHANGED] = 'OnItemCountChanged',
    },
    ['FacUnlockFormulaToast'] = {
        
        [MessageConst.SHOW_FORMULA_TOAST] = 'OnShowFormulaToast',
    },
}

HL.Commit(BackgroundMessage)
