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




UIRestoreSystem.AddRequest = HL.Method(HL.String, HL.Opt(HL.Function)) << function(self, dungeonId, checkFunc)
    local restoreData = {
        dungeonId = dungeonId,
        phaseArgs = {},
        checkFunc = checkFunc or function() return self:_DefaultCheck() end,
    }
    local phaseArgs = PhaseManager:CollectCurPhaseArgs()
    for _, v in ipairs(phaseArgs) do
        if not UIConst.UI_RESTORE_PHASE_BLACKLIST[v.name] then
            table.insert(restoreData.phaseArgs, v)
        end
    end
    self.m_restoreRequestMap[dungeonId] = restoreData
end

UIRestoreSystem.RemoveRequest = HL.Method(HL.String) << function(self, dungeonId)
    self.m_restoreRequestMap[dungeonId] = nil
    if self.m_restoreRestoreData and self.m_restoreRestoreData.dungeonId == dungeonId then
        self.m_restoreRestoreData = nil
    end
end

UIRestoreSystem.ModifyRequest = HL.Method(HL.String, HL.String) << function(self, dungeonId, newDungeonId)
    local restoreData = self.m_restoreRequestMap[dungeonId]
    if restoreData then
        restoreData.dungeonId = newDungeonId
        for _, v in ipairs(restoreData.phaseArgs) do
            if v.arg and v.arg.dungeonId then
                v.arg.dungeonId = newDungeonId
            end
        end
        self.m_restoreRequestMap[dungeonId] = nil
        self.m_restoreRequestMap[newDungeonId] = restoreData
    end
end

UIRestoreSystem.GetRestoreData = HL.Method(HL.String) << function(self, dungeonId)
    return self.m_restoreRequestMap[dungeonId]
end

UIRestoreSystem.RemovePhaseFromRequest = HL.Method(HL.String, HL.Number) << function(self, dungeonId, phaseId)
    local restoreData = self.m_restoreRequestMap[dungeonId]
    if restoreData then
        for i, v in ipairs(restoreData.phaseArgs) do
            if v.id == phaseId then
                table.remove(restoreData.phaseArgs, i)
                break
            end
        end
    end
end

UIRestoreSystem.TryRestore = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_restoreRestoreData then
        local restoreData = self.m_restoreRestoreData
        self.m_restoreRestoreData = nil
        if restoreData.checkFunc() then
            PhaseManager:RecoverPhaseByArgs(restoreData.phaseArgs)

            
            
            GameInstance.player.forbidSystem:SetPhaseForbid("CharFormation", "MainCharInAir", false, nil)
            return true
        end
    end
    return false
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
    self.m_restoreRequestMap[dungeonId] = nil
end

UIRestoreSystem._DefaultCheck = HL.Method().Return(HL.Boolean) << function(self)
    local modeType = GameInstance.mode.modeType
    
    
    return modeType == GEnums.GameModeType.Default or
            modeType == GEnums.GameModeType.SpaceShip
end

HL.Commit(UIRestoreSystem)
return UIRestoreSystem
