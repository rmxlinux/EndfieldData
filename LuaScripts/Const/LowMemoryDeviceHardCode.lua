
local LowMemoryDeviceHardCode = {}

function LowMemoryDeviceHardCode.Apply()
    local isIOS = CS.Beyond.DeviceInfo.isIOS
    local memoryMB = CS.UnityEngine.SystemInfo.systemMemorySize
    local deviceModel = CS.UnityEngine.SystemInfo.deviceModel or ""

    local isIPad = string.find(string.lower(deviceModel or ""), "ipad", 1, true) ~= nil
    local is3GDevice = memoryMB < 3073

    if not (isIOS and isIPad and is3GDevice) then
        logger.info(CS.Beyond.ELogChannel.Quality, "ios 3g Full Extreme return")
        return
    end

    local RMF = CS.Beyond.Resource.ResourceManagerFlag
    local AnimMemQ = CS.Beyond.Gameplay.Core.AnimationQualityManager.MemoryQuality
    local NpcAnimMgr = CS.Beyond.Gameplay.View.NpcAnimationAssetManager
    local BudgetType = CS.Beyond.Resource.ESmartLRUBudgetType

    local pipeline = CS.HG.Rendering.Runtime.HGRenderPipeline.currentPipeline
    assert(pipeline ~= nil, "请在渲染管线初始化后执行")
    local RenderSP = pipeline.settingParameters

    
    RenderSP.textureStreamingEnable:Override(true)
    RenderSP.textureStreamingBudget:Override(150)
    RenderSP.textureStreamingBudget:MarkFeatureDirty()

    
    local function SetAnimBudget(config)
        config.budgetType = BudgetType.TimeOrMemoryOut
        config.memoryBudgetMB = 5
        config.lifetimeBudgetSecond = 10
        config:MarkDirty()
    end

    SetAnimBudget(NpcAnimMgr.s_assetBudgetConfig)
    SetAnimBudget(AnimMemQ.s_actorAssetBudgetConfig)

    
    
    CS.Beyond.Audio.AudioAdapter.SetAudioMemoryBudget(15 * 1024 * 1024, 10)

    RMF.s_enableUnloadLocker = false
    RMF.s_unloadBudgetFloatingCoefficient = 0.05
    RMF.s_unloadMaxFloatingBudget = 20
    RMF.s_bundleFrameDelayToUnload_NormalMode = 30
    RMF.s_bundleFrameDelayToUnload_BusyMode = 30
    RMF.s_bundleFrameDelayToUnload_BurstMode = 120
    RMF.s_maxUnloadOpNum_Normal = 3
    RMF.s_maxUnloadOpNum_BusyMode = 10

    CS.Beyond.Resource.Runtime.PreloadLoadSetting.s_preloadManagerUnloadKeepTime = 1

    local CinematicMgr = CS.Beyond.Gameplay.Core.CinematicTimelineManagerBase
    xlua.private_accessible(CinematicMgr)
    CinematicMgr.s_maxConcurrentPreloadCount = 1

    CS.Beyond.Gameplay.Core.EntityManager.s_resourceCacheSec = 3

    local TerrainQuality = CS.Beyond.Gameplay.Streaming.HGTerrainQuality
    TerrainQuality.ChangeTier(2)
    TerrainQuality.ChangeEnableHalfVTSize(true)
    TerrainQuality.ChangeEnableHalfAtlasSize(true)

    RenderSP.reflectionProbeOctTextureSize:Override(128)
    CS.UnityEngine.QualitySettings.streamingMipmapsMaxLevelReduction = 3

    
    local TexGroup = CS.UnityEngine.HGTextureGroupSettings
    for group = 1, 18 do
        if group ~= 14 then
            TexGroup.SetSkippedMipsAt(group, 1)
        end
    end

    logger.info(CS.Beyond.ELogChannel.Quality, "ios 3g Full Extreme")
end


Register(MessageConst.ON_PRELOAD_START, LowMemoryDeviceHardCode.Apply)
Register(MessageConst.ON_GAME_SETTING_CHANGED, LowMemoryDeviceHardCode.Apply)

return LowMemoryDeviceHardCode
