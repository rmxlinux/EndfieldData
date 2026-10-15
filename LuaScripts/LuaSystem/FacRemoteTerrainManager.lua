









local FacRemoteTerrainManager = HL.Class('FacRemoteTerrainManager')

FacRemoteTerrainManager.m_loaded = HL.Field(HL.Boolean) << false

FacRemoteTerrainManager.m_curParams = HL.Field(HL.Table)

FacRemoteTerrainManager.FacRemoteTerrainManager = HL.Constructor() << function(self)
end



FacRemoteTerrainManager.Load = HL.Method(HL.Table) << function(self, terrainParams)
    logger.info("[FacRemoteTerrainManager] Load (STUB)", terrainParams and terrainParams.prefab)
    self.m_curParams = terrainParams
    self.m_loaded = true
    
    
end


FacRemoteTerrainManager.Unload = HL.Method() << function(self)
    logger.info("[FacRemoteTerrainManager] Unload (STUB)")
    self.m_loaded = false
    self.m_curParams = nil
    
end


FacRemoteTerrainManager.GetGroundPlaneTransform = HL.Method().Return(HL.Opt(Transform)) << function(self)
    
    return nil
end

HL.Commit(FacRemoteTerrainManager)
return FacRemoteTerrainManager
