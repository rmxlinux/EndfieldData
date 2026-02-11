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
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "sortId" }
        },
    },

    EQUIP_ENHANCE_SORT_OPTION = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "equipEnhanceLevel", "sortId1", "sortId2", "id" }
        },
    },

    EQUIP_ENHANCE_MATERIALS_SORT_OPTION = {
        {
            name = Language.LUA_DEPOT_SORT_OPTION_DEFAULT,
            keys = { "equipEnhanceSuccessProb", "equipEnhanceLevelReverse", "sortId1", "sortId2", "id" }
        },
    },

    EQUIP_PRODUCE_PACK_RED_DOT_TYPE = {
        AllNew = 3,
        PartialNew = 4,
    }
}


_G.EquipTechConst = EquipTechConst
return EquipTechConst
