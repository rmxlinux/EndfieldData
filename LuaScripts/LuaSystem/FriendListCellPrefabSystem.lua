local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local luaLoader = require_ex('Common/Utils/LuaResourceLoader')

FriendListCellPrefabSystem = HL.Class('FriendListCellPrefabSystem', LuaSystemBase.LuaSystemBase)

FriendListCellPrefabSystem.m_resourceLoader = HL.Field(HL.Forward("LuaResourceLoader"))

FriendListCellPrefabSystem.loadingNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.noDataNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.nonGameUserNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.blackListBackgroundNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.normalActionNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.friendRequestNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.blackListNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.checkDataListNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.strangerNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.modeActionNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.spaceshipVisitorNodePrefab = HL.Field(HL.Any)
FriendListCellPrefabSystem.spaceshipClueGiftNodePrefab = HL.Field(HL.Any)

FriendListCellPrefabSystem.FriendListCellPrefabSystem = HL.Constructor() << function(self)
end

FriendListCellPrefabSystem.OnInit = HL.Override() << function(self)
    self.m_resourceLoader = luaLoader.LuaResourceLoader()
    local prefabRoot = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Friend/FriendList/Dynamic/"
    self.loadingNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellLoadingNode.prefab")
    self.noDataNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellNoDataNode.prefab")
    self.nonGameUserNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellNonGameUserNode.prefab")
    self.blackListBackgroundNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellBlackListBackgroundNode.prefab")
    self.normalActionNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellNormalActionNode.prefab")
    self.friendRequestNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellFriendRequestNode.prefab")
    self.blackListNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellBlackListNode.prefab")
    self.checkDataListNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellCheckDataListNode.prefab")
    self.strangerNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellStrangerNode.prefab")
    self.modeActionNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellModeActionNode.prefab")
    self.spaceshipVisitorNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellSpaceshipVisitorNode.prefab")
    self.spaceshipClueGiftNodePrefab = self.m_resourceLoader:LoadGameObject(prefabRoot .. "FriendListCellSpaceshipClueGiftNode.prefab")
end

FriendListCellPrefabSystem.OnRelease = HL.Override() << function(self)
    self.loadingNodePrefab = nil
    self.noDataNodePrefab = nil
    self.nonGameUserNodePrefab = nil
    self.blackListBackgroundNodePrefab = nil
    self.normalActionNodePrefab = nil
    self.friendRequestNodePrefab = nil
    self.blackListNodePrefab = nil
    self.checkDataListNodePrefab = nil
    self.strangerNodePrefab = nil
    self.modeActionNodePrefab = nil
    self.spaceshipVisitorNodePrefab = nil
    self.spaceshipClueGiftNodePrefab = nil
    self.m_resourceLoader:DisposeAllHandles()
end

HL.Commit(FriendListCellPrefabSystem)
return FriendListCellPrefabSystem
