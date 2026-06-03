local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')

PsoCacheCorruptCheckSystem = HL.Class('PsoCacheCorruptCheckSystem', LuaSystemBase.LuaSystemBase)

local PSO_TIME_SCALE_VALUE = 100000 
local CHECK_INTERVAL_SECONDS_VALUE = 90 
local MAX_CHECK_COUNT_VALUE = 10 
local CUSTOM_FLAG0_BIT_VALUE = 1 
local CUSTOM_FLAG1_BIT_VALUE = 2 
local DELTA_THRESHOLD_00_VALUE = 100000 
local ABNORMAL_COUNT_THRESHOLD_00_VALUE = 1 
local DELTA_THRESHOLD_01_VALUE = 80000 
local ABNORMAL_COUNT_THRESHOLD_01_VALUE = 1 
local DELTA_THRESHOLD_10_VALUE = 50000 
local ABNORMAL_COUNT_THRESHOLD_10_VALUE = 2 
local DELTA_THRESHOLD_11_VALUE = 50000 
local ABNORMAL_COUNT_THRESHOLD_11_VALUE = 1 

PsoCacheCorruptCheckSystem.m_enabled = HL.Field(HL.Boolean) << false
PsoCacheCorruptCheckSystem.m_checkTimerId = HL.Field(HL.Number) << -1
PsoCacheCorruptCheckSystem.m_checkCount = HL.Field(HL.Number) << 0
PsoCacheCorruptCheckSystem.m_lastPsoCreationTime = HL.Field(HL.Number) << 0
PsoCacheCorruptCheckSystem.m_abnormalCount = HL.Field(HL.Number) << 0
PsoCacheCorruptCheckSystem.m_abnormalDeltaThreshold = HL.Field(HL.Number) << 0
PsoCacheCorruptCheckSystem.m_abnormalCountThreshold = HL.Field(HL.Number) << 0

PsoCacheCorruptCheckSystem.PsoCacheCorruptCheckSystem = HL.Constructor() << function(self)
end

PsoCacheCorruptCheckSystem.OnInit = HL.Override() << function(self)
    if not self:_EnableCorruptCheck() then
        return
    end

    self.m_enabled = true
    self:_InitDetectParams()
    self.m_checkCount = 0
    self.m_lastPsoCreationTime = self:_GetPsoCreationTime()
    self.m_abnormalCount = 0
    self:_StartNextCheckTimer()
end

PsoCacheCorruptCheckSystem.OnRelease = HL.Override() << function(self)
    self:_ClearCheckTimer()
    self.m_enabled = false
end

PsoCacheCorruptCheckSystem._EnableCorruptCheck = HL.Method().Return(HL.Boolean) << function(self)
    local currentPlatform = CS.UnityEngine.Application.platform
    local isWindows = currentPlatform == CS.UnityEngine.RuntimePlatform.WindowsPlayer
        or currentPlatform == CS.UnityEngine.RuntimePlatform.WindowsEditor
    return isWindows
        and CS.UnityEngine.SystemInfo.graphicsDeviceType == CS.UnityEngine.Rendering.GraphicsDeviceType.Vulkan
        and not CS.Beyond.Cfg.RemoteGameCfg.instance.data.disableCustomFlag0
        and not CS.Beyond.Scripts.Quality.QualityManager.instance:NoMatchDeviceOrZeroScore()
end

PsoCacheCorruptCheckSystem._InitDetectParams = HL.Method() << function(self)
    local remoteData = CS.Beyond.Cfg.RemoteGameCfg.instance.data
    local flagValue = 0
    if remoteData.enableCustomFlag0 then
        flagValue = flagValue + CUSTOM_FLAG0_BIT_VALUE
    end
    if remoteData.enableCustomFlag1 then
        flagValue = flagValue + CUSTOM_FLAG1_BIT_VALUE
    end

    if flagValue == 0 then
        self.m_abnormalDeltaThreshold = DELTA_THRESHOLD_00_VALUE
        self.m_abnormalCountThreshold = ABNORMAL_COUNT_THRESHOLD_00_VALUE
    elseif flagValue == 1 then
        self.m_abnormalDeltaThreshold = DELTA_THRESHOLD_01_VALUE
        self.m_abnormalCountThreshold = ABNORMAL_COUNT_THRESHOLD_01_VALUE
    elseif flagValue == 2 then
        self.m_abnormalDeltaThreshold = DELTA_THRESHOLD_10_VALUE
        self.m_abnormalCountThreshold = ABNORMAL_COUNT_THRESHOLD_10_VALUE
    else
        self.m_abnormalDeltaThreshold = DELTA_THRESHOLD_11_VALUE
        self.m_abnormalCountThreshold = ABNORMAL_COUNT_THRESHOLD_11_VALUE
    end
end

PsoCacheCorruptCheckSystem._GetPsoCreationTime = HL.Method().Return(HL.Number) << function(self)
    return CS.UnityEngine.Graphics.GetTotalPsoCreationTimeInCPUCycles() / PSO_TIME_SCALE_VALUE
end

PsoCacheCorruptCheckSystem._StartNextCheckTimer = HL.Method() << function(self)
    self:_ClearCheckTimer()
    self.m_checkTimerId = self:_StartTimer(CHECK_INTERVAL_SECONDS_VALUE, function()
        self.m_checkTimerId = -1
        self:_CheckPsoCreationTimeDelta()
    end, true)
end

PsoCacheCorruptCheckSystem._ClearCheckTimer = HL.Method() << function(self)
    if self.m_checkTimerId > 0 then
        self.m_checkTimerId = self:_ClearTimer(self.m_checkTimerId)
    end
end

PsoCacheCorruptCheckSystem._CheckPsoCreationTimeDelta = HL.Method() << function(self)
    if not self.m_enabled then
        return
    end

    self.m_checkCount = self.m_checkCount + 1
    local currT = self:_GetPsoCreationTime()
    local delta = currT - self.m_lastPsoCreationTime
    self.m_lastPsoCreationTime = currT
    if delta > self.m_abnormalDeltaThreshold then
        self.m_abnormalCount = self.m_abnormalCount + 1
        if self.m_abnormalCount >= self.m_abnormalCountThreshold then
            self.m_enabled = false
            self:_TryRepairPsoCache()
            return
        end
    end

    if self.m_checkCount >= MAX_CHECK_COUNT_VALUE then
        self.m_enabled = false
        return
    end

    self:_StartNextCheckTimer()
end

PsoCacheCorruptCheckSystem._TryRepairPsoCache = HL.Method() << function(self)
    local deleted = self:_TryDeletePsoCacheFile()
    if deleted then
        CS.Beyond.Rendering.ShaderWarmupManager.MarkNeedShaderWarmUp(CS.Beyond.Rendering.ShaderWarmupManager.WarmUpReason.RemoteCtrlRetry)
    end
end

PsoCacheCorruptCheckSystem._TryDeletePsoCacheFile = HL.Method().Return(HL.Boolean) << function(self)
    local cacheFilePath = CS.System.IO.Path.Combine(
        CS.UnityEngine.Application.persistentDataPath,
        CS.Beyond.Rendering.ShaderWarmupManager.s_vulkanCacheFileName)
    if not CS.System.IO.File.Exists(cacheFilePath) then
        return false
    end

    local success, errorMsg = pcall(function()
        CS.System.IO.File.Delete(cacheFilePath)
    end)
    if not success then
        logger.error(ELogChannel.HGRP, string.format(
            "PsoCacheCorruptCheckSystem delete cache failed, path:%s, error:%s",
            tostring(cacheFilePath),
            tostring(errorMsg)))
        return false
    end

    if CS.System.IO.File.Exists(cacheFilePath) then
        logger.error(ELogChannel.HGRP,
            "PsoCacheCorruptCheckSystem delete cache failed, file still exists: " .. tostring(cacheFilePath))
        return false
    end

    logger.error(ELogChannel.HGRP,
        "PsoCacheCorruptCheckSystem deleted cache : " .. tostring(cacheFilePath))
    return true
end

HL.Commit(PsoCacheCorruptCheckSystem)
return PsoCacheCorruptCheckSystem
