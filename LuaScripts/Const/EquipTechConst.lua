local EquipTechConst = {

    
    EEquipEnhanceSuccessProb = {
        None = 1,  
        Normal = 2,  
        High = 3,  
    },

    EQUIP_PRODUCE_SORT_OPTION = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "minWearLv", "rarity", "sortId1", "sortId2", "id" }
        },
    },

    EQUIP_PRODUCE_PACK_SORT_OPTION = {
        {
            name = Language.LUA_EQUIP_PRODUCE_PACK_SORT_OPTION_MATERIAL,
            keys = { "costMatSortId", "sortId" }
        },
        {
            name = Language.LUA_EQUIP_PRODUCE_PACK_SORT_OPTION_QUALITY,
            keys = { "sortId" }
        },
    },

    EQUIP_ENHANCE_SORT_OPTION = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "equipEnhanceLevel", "equipEnhanceTotalFailedTimes", "equippedCharInstId", "sortId1", "sortId2", "id" }
        },
    },

    EQUIP_ENHANCE_MATERIALS_SORT_OPTION = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "equipEnhanceSuccessProb", "equipEnhanceLevelReverse", "equipEnhanceTotalFailedTimesReverse", "equippedCharInstIdReverse", "sortId1", "sortId2", "id" }
        },
    },

    EQUIP_PRODUCE_PACK_RED_DOT_TYPE = {
        AllNew = 103,
        PartialNew = 104,
    }
}


_G.EquipTechConst = EquipTechConst
return EquipTechConst
