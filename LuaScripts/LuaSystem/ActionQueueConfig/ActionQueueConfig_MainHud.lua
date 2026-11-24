







































































local M = {}


M.tiers = {
    
    { "LoginCheck_ImportantActivity_WaitCinematic", "LoginCheck_ImportantActivity_Top" },
    { "LoginCheck_CashShopOrderSettle" },
    { "LoginCheck_MonthlypassPopup" },
    { "LoginCheck_StartGuide", "LoginCheck_ForceSNS" },

    
    { "LoginCheck_PreventedClearScreenForLevelScripts", "CinematicBlocker" },
    { "Cinematic" },

    
    { "ChapterPanelWithoutMissionHud", "MissionHudCompleteBlocker" },

    
    { "CashShopOrderSettleInterrupt" },
    { "CashShopOrderSettle" },
    { "MonthlyPassPopup" },
    { "LoginCheck_ImportantActivity_Fallback" },
    { "LoginCheck_Reflow" },
    { "LoginCheck_ActivityCheckIn" },
    { "PS5GameIntent" },
    { "DashBarUpgrade" },
    { "FacTechPointGained" },
    { "CenterRewards", "EquipFormulaRewardPopup" },
    { "WorldLevelPreview" },
    { "SettlementToast" },
    { "ImportantReward" },
    { "AdventureLevelUp" },
    { "AfterLevelUpSNS" },
    { "PuzzlePickup", "EndingToast" },
    { "MissionHudResumeInfo" },
    { "CommonPOIUpgradeToast" },
    { "DomainDepotDeliverToast" },
    { "DomainUpgrade" },
    { "AppStoreRatingPopup" },

    
    { "BackupPowerCheck" },
    { "MapRegionToast" },
    { "SpaceshipHudTips" },
    {
        "SNSNormalNotice",
        "GetItemToast",
        "FirstGotItem",
        "UnlockPRTS",
        "DomainUpgradeToast",
        "WeeklyRaidEnter",
        "UnlockMusic",
    },
}


M.types = {
    
    
    LoginCheck_ImportantActivity_WaitCinematic = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
        finishWhenInterrupt = true,
        dropWhenChangeScene = true,
    },

    
    
    
    LoginCheck_ImportantActivity_Top = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
        finishWhenInterrupt = true,
        dropWhenChangeScene = true,
    },

    
    LoginCheck_CashShopOrderSettle = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
        finishWhenInterrupt = true,
    },

    
    LoginCheck_MonthlypassPopup = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
    },

    
    LoginCheck_StartGuide = {
        needWait = false,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
    },

    
    LoginCheck_ForceSNS = {
        needWait = false,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
    },

    
    LoginCheck_PreventedClearScreenForLevelScripts = {
        needWait = false,
        dropWhenChangeScene = true,
        ignoreCinematicInterrupt = true,
        ignoreMainHudInterrupt = true,
    },

    
    CinematicBlocker = {
        needWait = true,
        isCinematic = true,
        dropWhenChangeScene = true,
    },

    
    Cinematic = {
        needWait = true,
        isCinematic = true,
        dropWhenChangeScene = true,
    },

    
    
    ChapterPanelWithoutMissionHud = {
        needWait = true,
        finishWhenInterrupt = true,
        dropWhenChangeScene = true,
    },

    
    
    MissionHudCompleteBlocker = {
        needWait = true,
        finishWhenInterrupt = false,
        dropWhenChangeScene = true,
    },

    
    CashShopOrderSettleInterrupt = {
        needWait = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    CashShopOrderSettle = {
        needWait = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    MonthlyPassPopup = {
        needWait = true,
        finishWhenInterrupt = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    
    LoginCheck_ImportantActivity_Fallback = {
        needWait = true,
        finishWhenInterrupt = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
        ignoreCinematicInterrupt = true,
        dropWhenChangeScene = true,
    },

    
    LoginCheck_Reflow = {
        needWait = true,
        finishWhenInterrupt = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    LoginCheck_ActivityCheckIn = {
        needWait = true,
        finishWhenInterrupt = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    
    PS5GameIntent = {
        needWait = true,
        finishWhenInterrupt = true,
        ignoreCinematicInterrupt = true,
        waitForceGuideEnd = true,
    },

    
    DashBarUpgrade = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        waitForceGuideEnd = true,
    },

    
    FacTechPointGained = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.FacTechPointGainedToast,
    },

    
    CenterRewards = {
        needWait = true,
        preloadPanelId = PanelId.RewardsPopupCenter,
    },

    
    EquipFormulaRewardPopup = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.EquipFormulaRewardPopup,
    },

    
    WorldLevelPreview = {
        needWait = true,
        finishWhenInterrupt = true,
        dropWhenChangeScene = true,
        waitForceGuideEnd = true,
        ignoreMainHudInterrupt = true,
    },

    
    SettlementToast = {
        needWait = true,
        finishWhenInterrupt = true,
    },

    
    ImportantReward = {
        needWait = true,
        ignoreCinematicInterrupt = true,
        preloadPanelId = PanelId.ImportantRewardPopup,
        waitForceGuideEnd = true,
    },

    
    AdventureLevelUp = {
        needWait = true,
        finishWhenInterrupt = false,
        preloadPanelId = PanelId.AdventureLevelUp,
        waitForceGuideEnd = true,
    },

    
    AfterLevelUpSNS = {
        needWait = true,
        dropWhenChangeScene = true,
        ignoreMainHudInterrupt = true,
    },

    
    PuzzlePickup = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.PuzzlePickupToast,
    },

    EndingToast = {
        needWait = true,
        finishWhenInterrupt = true,
    },

    
    MissionHudResumeInfo = {
        needWait = false,
    },

    
    CommonPOIUpgradeToast = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.CommonPOIUpgradeToast,
    },

    
    DomainDepotDeliverToast = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.DomainDepotDeliverToast,
    },

    
    DomainUpgrade = {
        needWait = true,
        finishWhenInterrupt = true,
        preloadPanelId = PanelId.DomainUpgrade,
    },

    
    AppStoreRatingPopup = {
        needWait = false,
        finishWhenInterrupt = true,
    },

    
    BackupPowerCheck = {
        needWait = false,
        ignoreMainHudInterrupt = true,
    },

    
    MapRegionToast = {
        needWait = true,
        finishWhenInterrupt = true,
        dropWhenChangeScene = true,
        preloadPanelId = PanelId.MapRegionToast,
    },

    
    SpaceshipHudTips = {
        needWait = true,
        dropWhenChangeScene = true,
    },

    
    SNSNormalNotice = {
        needWait = false,
        dropWhenChangeScene = true,
    },

    
    GetItemToast = {
        needWait = false,
    },

    
    FirstGotItem = {
        needWait = false,
    },

    UnlockPRTS = {
        needWait = false,
    },

    DomainUpgradeToast = {
        needWait = false,
    },

    WeeklyRaidEnter = {
        needWait = true,
        finishWhenInterrupt = false,
        dropWhenChangeScene = true,
    },

    UnlockMusic = {
        needWait = false,
    },
}

return M
