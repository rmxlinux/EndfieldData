










LuaSystemManager = HL.Class('LuaSystemManager')




LuaSystemManager.inited = HL.Field(HL.Boolean) << false

LuaSystemManager.factory = HL.Field(HL.Forward('FacLuaSystem'))

LuaSystemManager.factoryInteract = HL.Field(HL.Forward('FacInteractSystem'))

LuaSystemManager.factoryHud = HL.Field(HL.Forward('FacHudLuaSystem'))

LuaSystemManager.mainHudActionQueue = HL.Field(HL.Forward('MainHudActionQueueSystem'))

LuaSystemManager.audioEventSystem = HL.Field(HL.Forward('AudioEventLuaSystem'))

LuaSystemManager.commonIntTriggerSystem = HL.Field(HL.Forward('CommonIntTriggerSystem'))

LuaSystemManager.gachaSystem = HL.Field(HL.Forward('GachaSystem'))

LuaSystemManager.levelWorldUISystem = HL.Field(HL.Forward('LevelWorldUISystem'))

LuaSystemManager.commonTaskTrackSystem = HL.Field(HL.Forward('CommonTaskTrackSystem'))

LuaSystemManager.itemPrefabSystem = HL.Field(HL.Forward('ItemPrefabSystem'))

LuaSystemManager.friendListCellPrefabSystem = HL.Field(HL.Forward('FriendListCellPrefabSystem'))

LuaSystemManager.mapResourceSystem = HL.Field(HL.Forward('MapResourceSystem'))

LuaSystemManager.cinematicSystem = HL.Field(HL.Forward('CinematicSystem'))

LuaSystemManager.radioSystem = HL.Field(HL.Forward('RadioSystem'))

LuaSystemManager.uiRestoreSystem = HL.Field(HL.Forward('UIRestoreSystem'))

LuaSystemManager.appStoreSystem = HL.Field(HL.Forward('AppStoreSystem'))

LuaSystemManager.charInfoSystem = HL.Field(HL.Forward('CharInfoSystem'))

LuaSystemManager.inputDeviceChangeSystem = HL.Field(HL.Forward('InputDeviceChangeSystem'))

LuaSystemManager.shopTradeGoodsCellPrefabSystem = HL.Field(HL.Forward('ShopTradeGoodsCellPrefabSystem'))

LuaSystemManager.cashShopItemPrefabSystem = HL.Field(HL.Forward('CashShopItemPrefabSystem'))

LuaSystemManager.innNpcSystem = HL.Field(HL.Forward('InnNpcSystem'))

LuaSystemManager.innRadioSystem = HL.Field(HL.Forward('InnRadioSystem'))

LuaSystemManager.innRootSystem = HL.Field(HL.Forward('InnRootSystem'))



LuaSystemManager.InitSystems = HL.Method() << function(self)
    logger.info("LuaSystemManager.InitSystems")

    self.inited = true
    self.factory = self:_AddSystem("FacLuaSystem")
    self.factoryInteract = self:_AddSystem("FacInteractSystem")
    self.factoryHud = self:_AddSystem("FacHudLuaSystem")
    self.audioEventSystem = self:_AddSystem("AudioEventLuaSystem")
    self.commonIntTriggerSystem = self:_AddSystem("CommonIntTriggerSystem")
    self.mainHudActionQueue = self:_AddSystem("MainHudActionQueueSystem")
    self.gachaSystem = self:_AddSystem("GachaSystem")
    self.levelWorldUISystem = self:_AddSystem("LevelWorldUISystem")
    self.commonTaskTrackSystem = self:_AddSystem("CommonTaskTrackSystem")
    self.itemPrefabSystem = self:_AddSystem("ItemPrefabSystem")
    self.friendListCellPrefabSystem = self:_AddSystem("FriendListCellPrefabSystem")
    self.mapResourceSystem = self:_AddSystem("MapResourceSystem")
    self.cinematicSystem = self:_AddSystem("CinematicSystem")
    self.radioSystem = self:_AddSystem("RadioSystem")
    self.uiRestoreSystem = self:_AddSystem("UIRestoreSystem")
    self.appStoreSystem = self:_AddSystem("AppStoreSystem")
    self.charInfoSystem = self:_AddSystem("CharInfoSystem")
    self.inputDeviceChangeSystem = self:_AddSystem("InputDeviceChangeSystem")
    self.shopTradeGoodsCellPrefabSystem = self:_AddSystem("ShopTradeGoodsCellPrefabSystem")
    self.cashShopItemPrefabSystem = self:_AddSystem("CashShopItemPrefabSystem")
    self.innNpcSystem = self:_AddSystem("InnNpcSystem")
    self.innRadioSystem = self:_AddSystem("InnRadioSystem")
    self.innRootSystem = self:_AddSystem("InnRootSystem")

    
    
    
    CS.Beyond.UI.BattleControllerInputController.Create()
end

LuaSystemManager.LuaSystemManager = HL.Constructor() << function(self)
    Register(MessageConst.ON_GAME_MAINSTATE_ENTER, function(arg)
        self:InitSystems()
    end, self)

    self.m_systemList = {}
end

LuaSystemManager.m_systemList = HL.Field(HL.Table)

LuaSystemManager._AddSystem = HL.Method(HL.String).Return(HL.Forward('LuaSystemBase')) << function(self, systemName)
    local class = require_ex("LuaSystem/" .. systemName)
    local system = class()
    table.insert(self.m_systemList, system)
    system:OnInit()
    return system
end

LuaSystemManager.ReleaseSystems = HL.Method() << function(self)
    logger.info("LuaSystemManager.ReleaseSystems")
    for k = #self.m_systemList, 1, -1 do
        local v = self.m_systemList[k]
        v:OnRelease()
        v:Clear()
    end
    self.m_systemList = {}
    self.inited = false
end

HL.Commit(LuaSystemManager)
return LuaSystemManager
