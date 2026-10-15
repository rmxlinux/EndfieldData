INN_FOOD_MODEL_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Prefabs/Inn/%s.prefab"
INN_FOOD_ATTACHMENT_MODEL_PATH = "Assets/Beyond/DynamicAssets/Gameplay/Prefabs/NPCAttachment/%s.prefab"
INN_NPC_FOOD_ATTACHMENT_FOLDER = "NPCAttachment"

INN_DESK_HUD_MOUNT_KEY = "inn_desk_HUD"


INN_DESK_FOOD_MOUNT_KEY = "inn_desk_food"
INN_DESK_DISH_MOUNT_KEY_FMT = "inn_desk_dish%d"
INN_DESK_DRINK_MOUNT_KEY_FMT = "inn_desk_drink%d"

INN_DESK_PURSE_MOUNT_KEY = "inn_desk_purse"
INN_PURSE_MODEL_ID = "P_item_inn_purse"

INN_SPECIAL_GUEST_EFFECT_ID = "P_fxint_s_lv010_caishenmao_01"

INN_FOOD_APPEAR_EFFECT_ID = "P_fxint_s_map02_bowl_burst_2501"
INN_SERVING_COUNTER_INTERACT_EFFECT_ID = "P_fxint_s_map02_bowl_loop_2501"

INN_MATCH_EMOJI_ICON_ID = {
    [CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel.Unsatisfied] = "icon_inn_food_dissatisfied",
    [CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel.Normal] = "icon_inn_food_ordinary",
    [CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel.Perfect] = "icon_inn_food_satisfaction",
}









INN_FOOD_TRAY_MODE = {
    Normal = 1,
    PickUpDish = 2,
    PutBackDish = 3,
    Drink = 4,
    PutBackDrink = 5,
}

INN_AUTO_DUTY_ICON_ID = {
    [GEnums.JsspsiDutyType.ServeDish] = "icon_assist_foodup",
    [GEnums.JsspsiDutyType.ServeDrink] = "icon_assist_drink",
    [GEnums.JsspsiDutyType.Checkout] = "icon_assist_cashier",
}

INN_TOPIC_EMPTY_CONFIG = {
    bgId = "bg_inn_topic_default",
    iconId = "icon_inn_topic_default",
    color = "CBCBCB",
}


INN_TOPIC_STAR_COUNT = 5


INN_SHOP_GROUP_ID = "shop_inn_management"


INN_STORAGE_WAY_EDITABLE_SHOP = {
    ["shop_inn_management_1"] = true,
    ["shop_inn_management_2"] = true,
}


INN_MANUAL_REFRESH_SHOP = "shop_inn_management_1"