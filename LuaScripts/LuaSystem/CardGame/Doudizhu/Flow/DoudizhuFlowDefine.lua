






local STATE = {
    
    Inactive = "Inactive",

    
    Entering = "Entering",

    
    WaitingStart = "WaitingStart",

    
    Dealing = "Dealing",

    
    
    Bidding = "Bidding",

    
    Playing = "Playing",

    
    Settling = "Settling",

    
    Recovering = "Recovering",

    
    Leaving = "Leaving",
}

local TRIGGER = {
    Reset = "Reset",

    EnterRoom = "EnterRoom",
    RoomReady = "RoomReady",
    LeaveRoom = "LeaveRoom",

    
    Deal = "Deal",
    BidTurn = "BidTurn",
    BidResult = "BidResult",
    Bottom = "Bottom",
    PlayTurn = "PlayTurn",
    PlayAction = "PlayAction",
    Pass = "Pass",
    Settle = "Settle",
    FullSync = "FullSync",

    RecoveryRequired = "RecoveryRequired",
    SnapshotApplied = "SnapshotApplied",
}

return {
    State = STATE,
    Trigger = TRIGGER,
}
