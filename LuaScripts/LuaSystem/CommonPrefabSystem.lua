local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local luaLoader = require_ex('Common/Utils/LuaResourceLoader')
local COMMON_PREFAB_CONFIG = require_ex('Const/CommonPrefabConfig')

local UNLOAD_DELAY_FRAMES = 10

CommonPrefabSystem = HL.Class('CommonPrefabSystem', LuaSystemBase.LuaSystemBase)

CommonPrefabSystem.m_resourceLoader = HL.Field(HL.Forward("LuaResourceLoader"))
CommonPrefabSystem.m_resources = HL.Field(HL.Table)
CommonPrefabSystem.m_pendingUnloadFrames = HL.Field(HL.Table)
CommonPrefabSystem.m_unloadUpdateKey = HL.Field(HL.Number) << -1

CommonPrefabSystem.CommonPrefabSystem = HL.Constructor() << function(self)
end


CommonPrefabSystem.OnInit = HL.Override() << function(self)
    self.m_resources = {}
    self.m_pendingUnloadFrames = {}
end



CommonPrefabSystem.LoadPrefab = HL.Method(HL.String, HL.Opt(HL.Any)).Return(HL.Opt(GameObject)) << function(self, key, owner)
    local config = COMMON_PREFAB_CONFIG[key]
    
    if not config then
        error("CommonPrefabSystem: unknown prefab key " .. tostring(key))
    end
    if not config.dontUnload and owner == nil then
        error("CommonPrefabSystem: owner is required for " .. key)
    end

    local resource = self.m_resources[key]
    if not resource then
        if not self.m_resourceLoader then
            self.m_resourceLoader = luaLoader.LuaResourceLoader()
        end
        local prefab, handleKey = self.m_resourceLoader:LoadGameObject(config.path)
        if not prefab then
            if handleKey and handleKey ~= -1 then
                self.m_resourceLoader:DisposeHandleByKey(handleKey)
            end
            logger.error("CommonPrefabSystem: failed to load prefab", key, config.path)
            return nil
        end
        resource = { prefab = prefab, handleKey = handleKey }
        if not config.dontUnload then
            resource.owners = {}
        end
        self.m_resources[key] = resource
    end

    if not config.dontUnload then
        resource.owners[owner] = true
        if self.m_pendingUnloadFrames[key] then
            self.m_pendingUnloadFrames[key] = nil
            if not next(self.m_pendingUnloadFrames) then
                self.m_unloadUpdateKey = LuaUpdate:Remove(self.m_unloadUpdateKey)
            end
        end
    end
    return resource.prefab
end


CommonPrefabSystem.Release = HL.Method(HL.Any) << function(self, owner)
    for key, resource in pairs(self.m_resources) do
        if not COMMON_PREFAB_CONFIG[key].dontUnload and resource.owners[owner] then
            resource.owners[owner] = nil
            if not next(resource.owners) then
                self.m_pendingUnloadFrames[key] = Time.frameCount + UNLOAD_DELAY_FRAMES
            end
        end
    end
    if next(self.m_pendingUnloadFrames) and self.m_unloadUpdateKey == -1 then
        self.m_unloadUpdateKey = LuaUpdate:Add("Tick", function()
            self:_UpdateUnload()
        end)
    end
end


CommonPrefabSystem._UpdateUnload = HL.Method() << function(self)
    local nextUnloadKey
    local nextUnloadFrame
    for key, unloadFrame in pairs(self.m_pendingUnloadFrames) do
        if unloadFrame <= Time.frameCount and (not nextUnloadFrame or unloadFrame < nextUnloadFrame) then
            nextUnloadKey = key
            nextUnloadFrame = unloadFrame
        end
    end
    if nextUnloadKey then
        self.m_resourceLoader:DisposeHandleByKey(self.m_resources[nextUnloadKey].handleKey)
        self.m_resources[nextUnloadKey] = nil
        self.m_pendingUnloadFrames[nextUnloadKey] = nil
    end
    if not next(self.m_pendingUnloadFrames) then
        self.m_unloadUpdateKey = LuaUpdate:Remove(self.m_unloadUpdateKey)
    end
end


CommonPrefabSystem.OnRelease = HL.Override() << function(self)
    self.m_unloadUpdateKey = LuaUpdate:Remove(self.m_unloadUpdateKey)
    for key, resource in pairs(self.m_resources) do
        if not COMMON_PREFAB_CONFIG[key].dontUnload and not next(resource.owners) then
            self.m_resourceLoader:DisposeHandleByKey(resource.handleKey)
            self.m_resources[key] = nil
        end
    end
    for key, resource in pairs(self.m_resources) do
        local config = COMMON_PREFAB_CONFIG[key]
        if not config.dontUnload then
            local owners = {}
            for owner in pairs(resource.owners) do
                table.insert(owners, tostring(owner))
            end
            logger.error("CommonPrefabSystem 资源泄露", key, config.path, "ownerCount", #owners, "owners", table.concat(owners, ", "))
        end
    end
    if self.m_resourceLoader then
        self.m_resourceLoader:DisposeAllHandles()
        self.m_resourceLoader = nil
    end
    self.m_resources = {}
    self.m_pendingUnloadFrames = {}
end

HL.Commit(CommonPrefabSystem)
return CommonPrefabSystem
