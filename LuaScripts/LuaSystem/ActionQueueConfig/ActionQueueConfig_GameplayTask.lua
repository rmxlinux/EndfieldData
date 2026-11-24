


























local M = {}


M.tiers = {
    
    { "DungeonInfo", "SeasonTowerEnemyBuffPopup" },

    
    { "TrackCountdown" },

    
    {
        "TrackStartCountdown",
        "TrackHud",
        "CoinActivityIntro",
        "TrackStartToast",
        "TrackStateFinish",
        "TrackStateChange",
        "TrackHudShowEndEffect",
        "TrackEndToast",
    },

    { "ContingencyContractHudTimer" },

    
    { "SeasonTowerRankUp" },
    {
        "DungeonSettlement",
        "TyphoeaArcherySettlementPopup",
        "ContingencyContractSettlement",
        "DeathInfo",
    },

    
    {
        "BlackboxDiff",
        "ContingencyContractHud",
        "CoinActivityBuffToast",
        "CoinTaskFinishToast",
    },
}


M.types = {
    
    DungeonInfo = {
        needWait = true,
    },

    
    SeasonTowerEnemyBuffPopup = {
        needWait = true,
    },

    
    TrackCountdown = {
        needWait = false,
    },

    
    TrackStartCountdown = {
        needWait = false,
    },

    
    TrackHud = {
        needWait = false,
    },

    CoinActivityIntro = {
        needWait = true,
    },

    
    TrackStartToast = {
        needWait = true,
    },

    
    TrackStateFinish = {
        needWait = true,
    },

    
    TrackStateChange = {
        needWait = false,
    },

    
    TrackHudShowEndEffect = {
        needWait = true,
    },

    
    TrackEndToast = {
        needWait = true,
    },

    
    ContingencyContractHudTimer = {
        needWait = false,
    },

    
    SeasonTowerRankUp = {
        needWait = true,
    },

    
    DungeonSettlement = {
        needWait = false,
    },

    
    TyphoeaArcherySettlementPopup = {
        needWait = false,
    },

    
    ContingencyContractSettlement = {
        needWait = false,
    },

    
    DeathInfo = {
        needWait = false,
    },

    
    BlackboxDiff = {
        needWait = false,
    },

    
    ContingencyContractHud = {
        needWait = false,
    },

    
    CoinActivityBuffToast = {
        needWait = false,
    },

    
    CoinTaskFinishToast = {
        needWait = false,
    },
}

return M
