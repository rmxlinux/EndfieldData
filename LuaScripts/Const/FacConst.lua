




FACTORY_BUILDING_UI_MAP = {
    [GEnums.FacBuildingType.Hub] = { "FacHUB", false },
    [GEnums.FacBuildingType.SubHub] = { "FacHUB", false },
    [GEnums.FacBuildingType.PowerStation] = { "FacPowerStation", false },
    [GEnums.FacBuildingType.PowerPole] = { "FacPowerPole", false },
    [GEnums.FacBuildingType.MachineCrafter] = { "FacMachineCrafter", false },
    [GEnums.FacBuildingType.Loader] = { "FacLoader", false },
    [GEnums.FacBuildingType.Unloader] = { "FacUnloader", false },
    [GEnums.FacBuildingType.Miner] = { "FacMiner", false },
    [GEnums.FacBuildingType.Storager] = { "FacStorage", false },
    [GEnums.FacBuildingType.Soil] = { "FacCultivate", false },
    [GEnums.FacBuildingType.TravelPole] = { "FacTravelPole", false },
    [GEnums.FacBuildingType.PowerTerminal] = { "FacPowerTerminal", false },
    [GEnums.FacBuildingType.PowerPort] = { "FacPowerTerminal", false },
    [GEnums.FacBuildingType.PowerGate] = { "FacPowerGate", false },
    [GEnums.FacBuildingType.PowerDiffuser] = { "FacPowerDiffuser", false },
    [GEnums.FacBuildingType.Battle] = { "FacBattle", false },
    [GEnums.FacBuildingType.FluidPumpIn] = { "FacPump", false },
    [GEnums.FacBuildingType.FluidContainer] = { "FacLiquidStorager", false },
    [GEnums.FacBuildingType.FluidPumpOut] = { "FacDumper", false },
    [GEnums.FacBuildingType.FluidReaction] = { "FacMixPool", false },
    [GEnums.FacBuildingType.FluidSpray] = { "FacSquirter", false },
    [GEnums.FacBuildingType.FluidConsume] = { "FacLiquidCleaner", false },
    [GEnums.FacBuildingType.UdPipeLoader] = { "FacUndergroundPipe", false },
    [GEnums.FacBuildingType.UdPipeUnloader] = { "FacUndergroundPipe", false },
    [GEnums.FacBuildingType.DepositBeacon] = { "FacInventoryStation", false },
    [GEnums.FacBuildingType.Sign] = { "FacMarker", false },
    [GEnums.FacBuildingType.BusStart] = { "FacHongsBusSource", false },
    [GEnums.FacBuildingType.BusFree] = { "FacHongsBusSource", false },
}










FACTORY_NON_BUILDING_UI_MAP = {
    ["grid_belt_01"] = "FacBelt",
    ["log_connector"] = "FacConnector",
    ["log_converger"] = "FacConverger",
    ["log_splitter"] = "FacSplitter",
    ["log_pipe_01"] = "FacPipe",
    ["log_pipe_connector"] = "FacPipeConnector",
    ["log_pipe_splitter"] = "FacPipeSplitter",
    ["log_pipe_converger"] = "FacPipeConverger",
    ["log_conditioner"] = "FacConditionerSelect",
    ["log_pipe_conditioner"] = "FacConditionerSelect"
}




local RectFace = FacCoreNS.RectFace

LogisticNearCargoInfos = {
    {
        index = 1,
        gridOffset = FacCoreNS.Vector2IntData(0, -1),
        validInFace = RectFace.Down,
        validOutFace = RectFace.Top,
    },
    {
        index = 2,
        gridOffset = FacCoreNS.Vector2IntData(-1, 0),
        validInFace = RectFace.Left,
        validOutFace = RectFace.Right,
    },
    {
        index = 3,
        gridOffset = FacCoreNS.Vector2IntData(0, 1),
        validInFace = RectFace.Top,
        validOutFace = RectFace.Down,
    },
    {
        index = 4,
        gridOffset = FacCoreNS.Vector2IntData(1, 0),
        validInFace = RectFace.Right,
        validOutFace = RectFace.Left,
    },
}

FactoryLogisticDeviceType = {
    Router = 1,
    Connector = 2,
}

FAC_BUILD_MODE = {
    Normal = 1,
    Building = 2,
    Logistic = 3,
    Belt = 4,
    Blueprint = 5,
}

FAC_LINK_WIRE_TOAST_TYPE = {
    Start = 1,
    Cancel = 2,
    Success = 3,
    Failed = 4,
    TooFar = 5,
    LinkAlready = 6,
    FailedSourceNoPowerPole = 7,
    FailedSourceNoPowerDiffuser = 8,
    PowerNotEnough = 9,
    UdpipeStart = 10,
    UdpipeLoader2Loader = 11,
    UdpipeUnloader2Unloader = 12,
}

FAC_SAMPLE_TYPE = {
    Belt = 1,
    Pipe = 2,
}

SP_BUILDING_TYPES = {
    GEnums.FacBuildingType.Hub,
}

FAC_HUB_CRAFT_MAX_INCOME_NUM = 3
FAC_PROCESSOR_CRAFT_MAX_INCOME_NUM = 3
FAC_MANUAL_CRAFT_MAX_INCOME_NUM = 3
FAC_BUILDING_CHARACTER_MAX_NUM = 3
FAC_PROCESSOR_GEM_MAX_SOLT_NUM = 3
FAC_CHARACTER_MAX_SOLT_NUM = 3

BUILDING_SIZE_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/building_size_indicator.prefab"
BELT_START_PREVIEW_MARK_PREFAB_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/belt_start_preview_mark.prefab"
PIPE_PREVIEW_MARK_PREFAB_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/pipe_build_mark.prefab"

BUILDING_INTERACT_PIPE_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/fac_interact_indicator_pipe.prefab"
BUILDING_INTERACT_BOX_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/fac_interact_indicator_box.prefab"
BUILDING_INTERACT_BUILDING_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/fac_interact_indicator_building.prefab"
BUILDING_INTERACT_NORMAL_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/fac_interact_indicator_normal.prefab"
BUILDING_INTERACT_HOVER_INDICATOR_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Factory/Common/fac_interact_indicator_hover.prefab"

local powerPoleRangeEffect_1 = "Assets/Beyond/DynamicAssets/Gameplay/Effects/Prefabs/P_fxfac_interactive_boundary_electric_01.prefab"
local powerPoleRangeEffect_2 = "Assets/Beyond/DynamicAssets/Gameplay/Effects/Prefabs/P_fxfac_interactive_boundary_electric_02.prefab"
POLE_RANGE_EFFECT_MAP = {
    ["power_diffuser_1"] = powerPoleRangeEffect_1,
    ["power_diffuser_2"] = powerPoleRangeEffect_1,
    ["power_pole_2"] = powerPoleRangeEffect_2,
    ["power_pole_3"] = powerPoleRangeEffect_2,
}

FLUID_SPRAY_RANGE_EFFECT = "Assets/Beyond/DynamicAssets/Gameplay/Effects/Prefabs/P_interactive_sprinkler_01_range_5x4.prefab"
BATTLE_BUILDING_RANGE_EFFECT = "Assets/Beyond/DynamicAssets/Gameplay/Effects/Prefabs/P_interactive_boundary_weapontower_01.prefab"

AUTO_EXIT_FACTORY_DIST = 3

FAC_PROC_TYPE = {
    ExpCard = 1,
    Equip = 2,
    Gem = 3,
    GemRecast = 4,
}

FAC_BUILDING_STATE_TO_SPRITE = {
    [GEnums.FacBuildingState.Closed] = "icon_ui_power_pole_machine_state_4",
    [GEnums.FacBuildingState.Unknown] = "icon_ui_power_pole_machine_state_4",
    [GEnums.FacBuildingState.Idle] = "icon_ui_power_pole_machine_state_5",
    [GEnums.FacBuildingState.Normal] = "icon_ui_power_pole_machine_state_6",
    [GEnums.FacBuildingState.Blocked] = "icon_ui_power_pole_machine_state_2",
    [GEnums.FacBuildingState.NoPower] = "icon_ui_power_pole_machine_state_3",
    [GEnums.FacBuildingState.NotInPowerNet] = "icon_ui_power_pole_machine_state_1",
    [GEnums.FacBuildingState.Fixable] = "icon_ui_power_pole_machine_state_7",
}

FAC_TOP_VIEW_BUILDING_STATE_TO_SPRITE = {
    [GEnums.FacBuildingState.Closed] = "icon_building_state_4",
    [GEnums.FacBuildingState.Unknown] = "icon_building_state_4",
    [GEnums.FacBuildingState.Idle] = "icon_building_state_5",
    [GEnums.FacBuildingState.Blocked] = "icon_building_state_2",
    [GEnums.FacBuildingState.NoPower] = "icon_building_state_3",
    [GEnums.FacBuildingState.NotInPowerNet] = "icon_building_state_1",
    [GEnums.FacBuildingState.BusDisconnect] = "icon_building_state_7",
    [GEnums.FacBuildingState.PortDisconnect] = "icon_building_state_8",
}

CRAFT_PROGRESS_MULTIPLIER = CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryUtil.craftProgressMultiplier

HUB_DATA_ID = "sp_hub_1"
BELT_ITEM_ID = "item_log_belt_01"
BELT_ID = "grid_belt_01"

PIPE_ITEM_ID = "item_log_pipe_01"
PIPE_ID = "log_pipe_01"




















CAN_BLOCK_CPTS = {
    [GEnums.FCComponentPos.Collector:GetHashCode()] = "collector",
    [GEnums.FCComponentPos.Producer:GetHashCode()] = "producer",
}

HAVE_PORT_CPTS = {
    [GEnums.FCComponentPos.Cache:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheIn1:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheIn2:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheIn3:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheIn4:GetHashCode()] = "cache",

    [GEnums.FCComponentPos.CacheOut1:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheOut2:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheOut3:GetHashCode()] = "cache",
    [GEnums.FCComponentPos.CacheOut4:GetHashCode()] = "cache",

    [GEnums.FCComponentPos.BusLoader:GetHashCode()] = "busLoader",

    [GEnums.FCComponentPos.Selector:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector1:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector2:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector3:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector4:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector5:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector6:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector7:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector8:GetHashCode()] = "selector",
    [GEnums.FCComponentPos.Selector9:GetHashCode()] = "selector",
}

BUILDING_PORT_IS_INPUT_INFOS = {
    [GEnums.FCComponentPos.BusLoader] = true,

    [GEnums.FCComponentPos.Selector1] = false,
    [GEnums.FCComponentPos.Selector2] = false,
    [GEnums.FCComponentPos.Selector3] = false,
    [GEnums.FCComponentPos.Selector4] = false,
    [GEnums.FCComponentPos.Selector5] = false,
    [GEnums.FCComponentPos.Selector6] = false,

    [GEnums.FCComponentPos.Cache] = true,
    [GEnums.FCComponentPos.CacheIn1] = true,
    [GEnums.FCComponentPos.CacheIn2] = true,
    [GEnums.FCComponentPos.CacheIn3] = true,
    [GEnums.FCComponentPos.CacheIn4] = true,

    [GEnums.FCComponentPos.CacheOut1] = false,
    [GEnums.FCComponentPos.CacheOut2] = false,
    [GEnums.FCComponentPos.CacheOut3] = false,
    [GEnums.FCComponentPos.CacheOut4] = false,
}


SP_BUILDING_IDS = {
    [GEnums.FacBuildingType.Hub] = "sp_hub_1",
}

LOGISTIC_UNLOCK_SYSTEM_MAP = {
    ["log_connector"] = GEnums.UnlockSystemType.FacBridge,
    ["log_converger"] = GEnums.UnlockSystemType.FacMerger,
    ["log_splitter"] = GEnums.UnlockSystemType.FacSplitter,
    ["log_conditioner"] = GEnums.UnlockSystemType.FacValve,

    ["log_pipe_connector"] = GEnums.UnlockSystemType.FacPipeConnector,
    ["log_pipe_converger"] = GEnums.UnlockSystemType.FacPipeConverger,
    ["log_pipe_splitter"] = GEnums.UnlockSystemType.FacPipeSplitter,
    ["log_pipe_conditioner"] = GEnums.UnlockSystemType.FacPipeValve,
}

FACTORY_DATA_TAB_INDEX = {
    DayData = 1,
    PowerData = 2,
    ProductData = 3,
}

NOT_SHOW_IN_POWER_POLE_FC_NODE_TYPES = {
    [GEnums.FCNodeType.Invalid:GetHashCode()] = true,
    [GEnums.FCNodeType.Hub:GetHashCode()] = true,
    [GEnums.FCNodeType.SubHub:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerPole:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerDiffuser:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerGate:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerSave:GetHashCode()] = true,
    [GEnums.FCNodeType.Inventory:GetHashCode()] = true,
    [GEnums.FCNodeType.Bus:GetHashCode()] = true,
    [GEnums.FCNodeType.BusUnloader:GetHashCode()] = true,
    [GEnums.FCNodeType.BusLoader:GetHashCode()] = true,
    [GEnums.FCNodeType.BoxConveyor:GetHashCode()] = true,
    [GEnums.FCNodeType.BoxBridge:GetHashCode()] = true,
    [GEnums.FCNodeType.BoxRouterM1:GetHashCode()] = true,
    [GEnums.FCNodeType.BurnPower:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerPort:GetHashCode()] = true,
    [GEnums.FCNodeType.PowerTerminal:GetHashCode()] = true,
    [GEnums.FCNodeType.FluidConveyor:GetHashCode()] = true,
    [GEnums.FCNodeType.FluidRepeater:GetHashCode()] = true,
    [GEnums.FCNodeType.FluidRouterM1:GetHashCode()] = true,
    [GEnums.FCNodeType.FluidBridge:GetHashCode()] = true,
    [GEnums.FCNodeType.Soil:GetHashCode()] = true,
}

BUILDING_PANEL_AUTO_CLOSE_RANGE = 6

QuickBarItemType = {
    Building = 1,
    Belt = 2,
    Logistic = 3,
}

FAC_FORMULA_MODE_MAP = {
    NORMAL = "normal",
    LIQUID = "liquid",
}

FAC_TOP_VIEW_BASIC_ACTION_IDS = {
    "fac_top_view_move",
    "fac_top_view_zoom",
}
FAC_TOP_VIEW_BASIC_ACTION_IDS_FOR_CONTROLLER = {
    "fac_top_view_ct_move",
    "fac_top_view_ct_scale_cam",
}

FAC_TOP_VIEW_MOVE_PADDING = 3

FAC_LOGISTIC_SPEED_OVERRIDE = 0.001
FAC_PIPE_LOGISTIC_SPEED_OVERRIDE = 0.001

BattleBuildingChargingMode = {
    Battery = 1,
    PowerNet = 2,
    Overload = 3,
    Closed = 4,
    Shared = 5,
}

BATCH_DEL_HINT_COUNT = 5

HUB_ITEM_PRODUCTIVITY_SHOWING_TYPES = {
    GEnums.ItemShowingType.Ore,
    GEnums.ItemShowingType.Plant,
    GEnums.ItemShowingType.Product,
    GEnums.ItemShowingType.Usable,
}

FLUID_LOGISTIC_ITEMS = {
    ["item_log_pipe_01"] = true,
    ["item_log_pipe_repeater"] = true,
    ["item_log_pipe_connector"] = true,
    ["item_log_pipe_splitter"] = true,
    ["item_log_pipe_converger"] = true,
    ["item_log_pipe_conditioner"] = true,
}

SMARTALERT_TRASNFORM_OFFSET = {
    [GEnums.FacSmartAlertType.NormalInputSingleBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.NormalInputMultiBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.FluidInputSingleBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.FluidInputMultiBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.NormalOutputMultiBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.FluidOutputMultiBlocked] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.InputCacheFull] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.OutputCacheFullWithoutBelt] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.OutputCacheFullWithBelt] = { x = -110, y = -14 },
    [GEnums.FacSmartAlertType.OutputCacheFullWithoutPipe] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.OutputCacheFullWithPipe] = { x = -160, y = -74 },
    [GEnums.FacSmartAlertType.InputInvalidFormula] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.NormalInputEmpty] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.FluidInputEmpty] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.CanBeOpened] = { x = -173, y = -14 },
    [GEnums.FacSmartAlertType.NoPowerWithoutDiffuser] = { x = -173, y = -14 },
    [GEnums.FacSmartAlertType.NoPowerWithDiffuser] = { x = -173, y = -14 },
    [GEnums.FacSmartAlertType.NoPower] = { x = -173, y = -14 },
    [GEnums.FacSmartAlertType.LiquidTypeCannotDumped] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.DiffTypeLiquidCannotDumped] = { x = 0, y = -14 },
    [GEnums.FacSmartAlertType.DiffTypeLiquidCannotSprayed] = { x = 0, y = -14 },
}

MAIN_REGION_CAM_STATE = "Factory/CCS_Fac_Region"

FAC_BLUEPRINT_DEFAULT_ICON = "blueprint_default_icon"


DEFAULT_BUILDING_SELECT_EFFECT_OFFSET = 0.5

BUILDING_SELECT_EFFECT_OFFSET = {
    [GEnums.FacBuildingType.BusStart] = 2,
    [GEnums.FacBuildingType.BusFree] = 2,
}

BUILDING_SELECT_EFFECT_USE_CONE_NODE_IDS = {
    ["log_pipe_conditioner"] = true,
}

FAC_BUS_TECH_TREE_NODE_IDS = {
    ["domain_1"] = "tech_tundra_2_field_1",
    ["domain_2"] = "tech_jinlong_1_log_hongs_bus_1",
}

BLUEPRINT_PREVIEW_BELT_IMGS = {
    normal = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_belt_grid.png",
    corner1 = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_belt_corner_1.png",
    corner2 = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_belt_corner_2.png",
}
BLUEPRINT_PREVIEW_PIPE_IMGS = {
    normal = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_pipe_grid.png",
    corner1 = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_pipe_corner_1.png",
    corner2 = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/icon_pipe_corner_2.png",
}
BLUEPRINT_PREVIEW_CORNER_DIC = {
    
    [0] = { [3] = { true, 180 },    [1] = { false, 270 }, },
    [1] = { [0] = { true, 90 },     [2] = { false, 180 }, },
    [2] = { [1] = { true, 0 },      [3] = { false, 90 }, },
    [3] = { [2] = { true, 270 },    [0] = { false, 0 }, },
}
BLUEPRINT_PREVIEW_BUILDING_DEFAULT_BG = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_machine_default.png"
BLUEPRINT_PREVIEW_SP_BUILDING_BG = {
    [GEnums.FacBuildingType.PowerPole] = { "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_machine_power.png" },
    [GEnums.FacBuildingType.PowerDiffuser] = { "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_machine_power.png" },
    [GEnums.FacBuildingType.Loader] = { "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_machine_loader.png" },
    [GEnums.FacBuildingType.Unloader] = { "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_machine_unloader.png" },
}
BLUEPRINT_PREVIEW_LOGISTIC_BG = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/bg_logistic_%s.png"
BLUEPRINT_PREVIEW_BELT_PORT_IN = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/port_in_%d.png"
BLUEPRINT_PREVIEW_BELT_PORT_OUT = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/port_out_%d.png"
BLUEPRINT_PREVIEW_PIPE_PORT_IN = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/pipe_port_in_%d.png"
BLUEPRINT_PREVIEW_PIPE_PORT_OUT = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/pipe_port_out_%d.png"
BLUEPRINT_PREVIEW_BELT_PORT_IN_ALTER = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/port_in_%d_%d.png" 
BLUEPRINT_PREVIEW_BELT_PORT_OUT_ALTER = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/port_out_%d_%d.png" 
BLUEPRINT_PREVIEW_PIPE_PORT_IN_ALTER = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/pipe_port_in_%d_%d.png" 
BLUEPRINT_PREVIEW_PIPE_PORT_OUT_ALTER = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/pipe_port_out_%d_%d.png" 
BLUEPRINT_PREVIEW_BUILDING_DEFAULT_EDGE_SMALL = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/deco_edge_small.png"
BLUEPRINT_PREVIEW_BUILDING_DEFAULT_EDGE_BIG = "Assets/Beyond/DynamicAssets/Gameplay/UI/Sprites/Blueprint/deco_edge_big.png"

BLUEPRINT_DEFAULT_ICON_BG_COLOR_ID = 101

UDPIPE_PORT_LAYOUT_STATE_MAP = {
    ["udpipe_loader_1"] = true,
    ["udpipe_loader_2"] = false,
    ["udpipe_unloader_1"] = true,
    ["udpipe_unloader_2"] = false,
}

UDPIPE_PORT_LOAD_TYPE_MAP = {
    ["udpipe_loader_1"] = true,
    ["udpipe_loader_2"] = true,
    ["udpipe_unloader_1"] = false,
    ["udpipe_unloader_2"] = false,
}

SIGN_BUILDING_EXTRA_SETTING_PANEL = {
    ["marker_1"] = true,
}

SIGN_BUILDING_BAN_IN_TOPVIEW = {
    ["item_port_marker_1"] = true,
}

SOCIAL_ICON_MAX_COUNT = 3

FAC_TOP_VIEW_STATE_ONLY_BUILDING_IDS = {
    ["log_hongs_bus"] = true,
    ["log_hongs_bus_source"] = true,
}

FAC_TOP_VIEW_IGNORE_STATE_BUILDING_IDS = {
    ["loader_1"] = true,
    ["unloader_1"] = true,
}

FAC_VALVE_NODE_INT_TYPES = {
    [GEnums.FCNodeType.BoxValve:GetHashCode()] = true,
    [GEnums.FCNodeType.FluidValve:GetHashCode()] = true,
}

FAC_VALVE_NODE_IDS = {
    ["log_conditioner"] = true,
    ["log_pipe_conditioner"] = true,
}

FAC_TOP_VIEW_AUTO_MOVE_CAM_SPD = 11

DOMAIN_SORT_GROUP = {
    Normal = 4,           
    Unsuitable = 3,       
    ModeUnsupported = 2,  
    Unsupported = 1,      
}

FAC_BUILDING_STATE_TO_PREFAB_PATH = {
    [GEnums.FacBuildingState.Closed] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateStopped.prefab",
    [GEnums.FacBuildingState.Idle] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateNoCraft.prefab",
    [GEnums.FacBuildingState.Normal] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateNormal.prefab",
    [GEnums.FacBuildingState.Blocked] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateBlock.prefab",
    [GEnums.FacBuildingState.NoPower] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateNoPower.prefab",
    [GEnums.FacBuildingState.NotInPowerNet] = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/BuildingStateNotLinked.prefab",
}

FAC_BUILDING_NORMAL_STATE_CUSTOM_TEXT_ID = {
    [GEnums.FacBuildingType.Miner] = "ui_fac_common_produce_mining",                    
    [GEnums.FacBuildingType.FluidPumpIn] = "ui_fac_common_produce_mining",              
    [GEnums.FacBuildingType.PowerStation] = "ui_fac_common_produce_power",              
    [GEnums.FacBuildingType.PowerDiffuser] = "ui_fac_common_running",                   
    [GEnums.FacBuildingType.PowerPole] = "ui_fac_common_running",                       
    [GEnums.FacBuildingType.TravelPole] = "ui_fac_common_running",                      
    [GEnums.FacBuildingType.Storager] = "ui_fac_common_running",                        
    [GEnums.FacBuildingType.FluidContainer] = "ui_fac_common_running",                  
    [GEnums.FacBuildingType.Loader] = "ui_fac_common_running",                          
    [GEnums.FacBuildingType.Unloader] = "ui_fac_common_running",                        
    [GEnums.FacBuildingType.DepositBeacon] = "ui_fac_common_running",                   
    [GEnums.FacBuildingType.Sign] = "ui_fac_common_running",                            
    [GEnums.FacBuildingType.BusStart] = "ui_fac_common_running",                        
    [GEnums.FacBuildingType.BusFree] = "ui_fac_common_running",                         
    [GEnums.FacBuildingType.UdPipeLoader] = "ui_fac_common_running",                    
    [GEnums.FacBuildingType.UdPipeUnloader] = "ui_fac_common_running",                  
    [GEnums.FacBuildingType.FluidSpray] = "ui_fac_common_running_squirter",             
    [GEnums.FacBuildingType.FluidConsume] = "ui_fac_common_running_cleaner",            
    [GEnums.FacBuildingType.FluidPumpOut] = "ui_fac_common_running_dumper",             
    [GEnums.FacBuildingType.Battle] = "ui_fac_battle_building_on_alert",                
}

FAC_NON_BUILDING_NORMAL_STATE_CUSTOM_TEXT_ID = {
    ["item_log_belt_01"] = "ui_fac_common_running",
    ["item_log_connector"] = "ui_fac_common_running",
    ["item_log_converger"] = "ui_fac_common_running",
    ["item_log_splitter"] = "ui_fac_common_running",
    ["item_log_pipe_01"] = "ui_fac_common_running",
    ["item_log_pipe_connector"] = "ui_fac_common_running",
    ["item_log_pipe_splitter"] = "ui_fac_common_running",
    ["item_log_pipe_converger"] = "ui_fac_common_running",
    ["item_log_conditioner"] = "ui_fac_common_running",
    ["item_log_pipe_conditioner"] = "ui_fac_common_running",
}

FAC_SMARTALERT_PREFAB_PATH = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/MachineSmartAlertNode.prefab"

FAC_BUILD_LIST_REDDOT_DATA_CATEGORY = "FacBuildListRedDot"

FocusStateTable = {
    None = 0,
    Focused = 1,
    UnFocused = 2,
}

FAC_BLUEPRINT_IMPORT_INPUTFIELD_MAX_LENGTH = 40
