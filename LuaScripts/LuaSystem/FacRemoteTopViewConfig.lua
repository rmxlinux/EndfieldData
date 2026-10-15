





local TopViewExitTrigger = {
    Teleport      = "Teleport",        
    FullPartyDead = "FullPartyDead",   
    Deport        = "Deport",          
    OutOfBoundary = "OutOfBoundary",   
}

local FacRemoteTopViewConfig = {
    TopViewExitTrigger = TopViewExitTrigger,

    
    coreFactory = {
        displayName = "Core Factory",  
    },

    
    
    
    
    
    
    testMap02CoreRegion = {
        displayName     = "Core Region Remote (Map02 core, hardcoded)",
        factoryRelocate = {
            mapId     = nil,                         
            regionMin = Vector3(-1220, 266.0, 36),   
            regionMax = Vector3(-1180, 266.0, 76),   
        },
    },
}

function FacRemoteTopViewConfig.Get(configKey)
    return FacRemoteTopViewConfig[configKey]
end

return FacRemoteTopViewConfig
