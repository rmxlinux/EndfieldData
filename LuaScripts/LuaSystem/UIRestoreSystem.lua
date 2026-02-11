local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')










UIRestoreSystem = HL.Class('UIRestoreSystem', LuaSystemBase.LuaSystemBase)








UIRestoreSystem.m_restoreRequestMap = HL.Field(HL.Table)


UIRestoreSystem.m_restoreRestoreData = HL.Field(HL.Table)



UIRestoreSystem.UIRestoreSystem = HL.Constructor() << function(self)
    self:RegisterMessage(MessageConst.ON_LEAVE_DUNGEON, function(args)
        local dungeonId = unpack(args)
        self:_OnLeaveDungeon(dungeonId)
    end)
    self.m_restoreRequestMap = {}
end










UIRestoreSystem.AddRequest = HL.Method(HL.String, HL.Function, HL.Opt(HL.Function)) << function(self, dungeonId, action, checkFunc)
    local restoreData = {
        dungeonId = dungeonId,
        action = action,
        checkFunc = checkFunc or function() return self:_DefaultCheck() end,
    }
    self.m_restoreRequestMap[dungeonId] = restoreData
end



UIRestoreSystem.TryRestore = HL.Method() << function(self)
    if self.m_restoreRestoreData then
        local restoreData = self.m_restoreRestoreData
        self.m_restoreRestoreData = nil
        if restoreData.checkFunc() then
            restoreData.action()
        end
    end
end



UIRestoreSystem.HasValidAction = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_restoreRestoreData and self.m_restoreRestoreData.checkFunc() then
        return true
    end
    return false
end




UIRestoreSystem._OnLeaveDungeon = HL.Method(HL.String) << function(self, dungeonId)
    
    local request = self.m_restoreRequestMap[dungeonId]
    self.m_restoreRestoreData = request
    self.m_restoreRequestMap = {}
end



UIRestoreSystem._DefaultCheck = HL.Method().Return(HL.Boolean) << function(self)
    local modeType = GameInstance.mode.modeType
    
    
    return modeType == GEnums.GameModeType.Default or
            modeType == GEnums.GameModeType.SpaceShip
end

HL.Commit(UIRestoreSystem)
return UIRestoreSystem