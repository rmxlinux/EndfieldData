PHASE_FILE_PATH = "Phase/%s/Phase%s"
PHASE_GAME_OBJECT_FILE_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Prefabs/%s/%s.prefab"

PHASE_MODEL_FILE_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Prefabs/UIModels/"
PHASE_CHAR_MODEL_FILE_PATH = PHASE_MODEL_FILE_PATH .. "%s_uimodel.prefab"
PHASE_CHAR_ANIMATOR_CONTROLLER_FILE_PATH = PHASE_MODEL_FILE_PATH .. "%s_controller.controller"

EPhaseState = {
    Init = 1,
    TransitionIn = 2,
    Activated = 3,
    Deactivated = 4,
    TransitionBehind = 5,
    TransitionOut = 6,
    WaitRelease = 7,
    TransitionBackToTop = 8,
}

PHASE_CHAR_ITEM_INIT_PARAM_NAME = "init"
PHASE_CHAR_ITEM_FORMATION_PARAM_NAME = "formation"













FORBID_INPUT_DEVICE_CHANGE_PANELS = {
    "Loading",
    "TeleportLoading",
    "CommonMask", 

    "PlayerRename", 
    "DungeonSettlementPopup", 
    "DeathInfo", 
    "DramaticPerformanceBag", 
    "ShopMonthlyPassPopUp", 
    "SDKApplicationMask",   
    "ActivityRewardRegistrationPopup", 

    
    "GachaDropBin",
    "GachaChar",
    "GachaChar",
    "GachaWeaponPreheat",
    "GachaWeapon",
    "GachaWeaponResult",

    
    "SettlementDefenseTransit",
    "SettlementDefenseFinish",
    "SettlementDefenseFinishFail",
}

FORBID_INPUT_DEVICE_CHANGE_PHASES = {
    "GenderSelect",

    
    "GachaChar",
    "GachaLauncher",
    "GachaDropBin",
    "GachaWeaponPreheat",
    "GachaWeapon",
    "GachaWeaponResult",

    
    "ActivityPopup",
}



INPUT_DEVICE_CHANGE_FORCE_CLOSE_PANELS = {
    "ItemTips",
    "WalletBar",
    "CommonTips",
    "Guide", 
}


EXCEPT_CHANGE_DEVICE_CLOSE_PANEL = {
    "CommonMask",
    "SpaceShipCharPoster",
    "InteractOption",
    "CommonWorldUI",
    "FacPowerPoleLinkingLabel",
    "VideoPreloader",
    "SpaceshipHudTips",
    "SpaceshipCabinInfoDisplay",

    
    "CommonTaskTrackHud",
    "CommonTaskTrackCountdown",
    "DungeonCharTutorialStepHud",
}


