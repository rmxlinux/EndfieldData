local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')






































VideoPlayer = HL.Class('VideoPlayer', UIWidgetBase)

local PlayerStatus = CS.CriWare.CriMana.Player.Status



VideoPlayer.m_preparingVideo = HL.Field(HL.Any) << nil


VideoPlayer.m_preparedVideo = HL.Field(HL.Any) << nil


VideoPlayer.m_stateChangeListener = HL.Field(HL.Table)


VideoPlayer.m_videoVolume = HL.Field(HL.Number) << 0


VideoPlayer.preloadStartTime = HL.Field(HL.Number) << -1


VideoPlayer.preloadKeepForever = HL.Field(HL.Boolean) << false


VideoPlayer.m_manualUpdateCor = HL.Field(HL.Thread)


VideoPlayer.m_onCanvasChangedClosure = HL.Field(HL.Function)




VideoPlayer._OnCreate = HL.Override() << function(self)
    self.m_stateChangeListener = {}
end



VideoPlayer._OnDestroy = HL.Override() << function(self)
    self:StopAutoKeepAspectRatio()
end



VideoPlayer._OnEnable = HL.Override() << function(self)
    self:_StopManualUpdate()

    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        self:_StartDisplayDebugInfo()
    end
end



VideoPlayer._OnDisable = HL.Override() << function(self)
    if self.m_preparingVideo then
        self:_StartManualUpdate()
    end

    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        self:_StopDisplayDebugInfo()
    end
end



VideoPlayer._StartManualUpdate = HL.Method() << function(self)
    if not self.m_manualUpdateCor then
        self.m_manualUpdateCor = self:_StartCoroutine(function() return self:_ManualUpdate() end)
    end
end



VideoPlayer._StopManualUpdate = HL.Method() << function(self)
    if self.m_manualUpdateCor then
        self:_ClearCoroutine(self.m_manualUpdateCor)
        self.m_manualUpdateCor = nil
    end
end




VideoPlayer._ManualUpdate = HL.Method() << function(self)
    while not self.gameObject.activeInHierarchy do
        self.view.movieController:PlayerManualUpdate()
        coroutine.step()
    end
end





VideoPlayer.SetVideoVolume = HL.Method(HL.Number) << function(self, volume)
    self.m_videoVolume = volume
end




VideoPlayer._LoadAndPlayVideo = HL.Method(HL.String) << function(self, path)
    self.view.movieController.player:SetFile(nil, path)
    self.view.movieController.player:Start()
end





VideoPlayer.PreloadVideo = HL.Method(HL.String, HL.Opt(HL.Function)) << function(self, path, onPlayerReady)
    if self.m_preparingVideo == path or self.m_preparedVideo == path then
        return
    end

    if self.view.movieController.player == nil then
        
        self.view.movieController:PlayerManualInitialize()
    end

    if self.view.movieController.player.statusChangeCallback == nil then
        
        self.view.movieController.player.statusChangeCallback = function(status) self:OnPlayerStateChange(status) end
    end

    self:_ClearStateChangeListener()
    self:_AddStateChangeListener(PlayerStatus.Ready, function()
        
        if onPlayerReady then
            onPlayerReady(self.view.movieController)
        end
        self.m_preparedVideo = path
        self.m_preparingVideo = nil
        self:_StopManualUpdate()
    end)

    
    
    
    
    
    
    


    self.m_preparingVideo = path
    self.preloadStartTime = Time.unscaledTime
    self.view.movieController.player:SetFile(nil, path);
    self.view.movieController.player:Prepare()
    self.view.canvasGroup.alpha = 0.0

    if not self.gameObject.activeInHierarchy then
        self:_StartManualUpdate()
    end
end





VideoPlayer.StartAutoKeepAspectRatio = HL.Method(HL.Opt(HL.Boolean)) << function(self, disableSafeZone)
    if self.m_onCanvasChangedClosure then
        return
    end

    if disableSafeZone == nil then
        disableSafeZone = false
    end

    self:SetVideoImageOffset(disableSafeZone)
    self.m_onCanvasChangedClosure = function() self:SetVideoImageOffset(disableSafeZone) end
    UIManager.m_uiCanvasScaleHelper.onCanvasChanged:AddListener(self.m_onCanvasChangedClosure)
end



VideoPlayer.StopAutoKeepAspectRatio = HL.Method() << function(self)
    if self.m_onCanvasChangedClosure then
        UIManager.m_uiCanvasScaleHelper.onCanvasChanged:RemoveListener(self.m_onCanvasChangedClosure)
        self.m_onCanvasChangedClosure = nil
    end
end




VideoPlayer.SetUserTimeCorrectionThreshold = HL.Method(HL.Int) << function(self, threshold)
    if threshold ~= nil and threshold >= 0 then
        self.view.movieController.player:SetUserTimeCorrectionThreshold(threshold)
    end
end








VideoPlayer.PlayVideo = HL.Method(HL.String, HL.Opt(HL.Function, HL.Function)).Return(HL.Boolean) <<
function(self, path, onPlayStart, onPlayEnd)
    if not self.gameObject.activeInHierarchy then
        logger.error("Set GameObject Active Before Play Video !!", path)
        return false
    end

    if self.view.movieController.player.statusChangeCallback == nil then
        
        self.view.movieController.player.statusChangeCallback = function(status) self:OnPlayerStateChange(status) end
    end

    if self.m_preparedVideo == path then
        self:_AddStateChangeListener(PlayerStatus.Playing, onPlayStart)
        self:_AddStateChangeListener(PlayerStatus.PlayEnd, onPlayEnd)
        self:_TriggerPlay()
        return true
    elseif self.m_preparingVideo == path then
        
        self:_AddStateChangeListener(PlayerStatus.Ready, function() self:_TriggerPlay() end)
        self:_AddStateChangeListener(PlayerStatus.Playing, onPlayStart)
        self:_AddStateChangeListener(PlayerStatus.PlayEnd, onPlayEnd)
        return false
    else
        self:_ClearStateChangeListener()
        self:_AddStateChangeListener(PlayerStatus.Playing, onPlayStart)
        self:_AddStateChangeListener(PlayerStatus.PlayEnd, onPlayEnd)
        self:_LoadAndPlayVideo(path)
        return false
    end
end





VideoPlayer.SetVideoImageOffset = HL.Method(HL.Boolean) << function(self, noSafeZone)
    if noSafeZone == nil then
        noSafeZone = false
    end

    local player = self.view.movieController.player
    if player == nil then
        return
    end

    local movieInfo = player.movieInfo
    if movieInfo then
        local screenWidth = self.view.image.transform.rect.width
        local screenHeight = self.view.image.transform.rect.height
        local w = movieInfo.dispWidth
        local h = movieInfo.dispHeight

        local offsetMin, offsetMax = FMVUtils.GetSuitableFMVImageOffset(screenWidth, screenHeight, w, h, noSafeZone)
        self.view.movieController.transform.offsetMin = offsetMin
        self.view.movieController.transform.offsetMax = offsetMax
    end
end




VideoPlayer.StopVideo = HL.Method(HL.Opt(HL.Boolean)) << function(self, dispose)
    self:_StopManualUpdate()
    self:_ClearStateChangeListener()
    self.view.movieController:Stop()
    self.m_preparedVideo = nil
    self.m_preparingVideo = nil

    if dispose == true then
        self:Dispose()
    end
end



VideoPlayer.Dispose = HL.Method() << function(self)
    
    self:StopAutoKeepAspectRatio()
    self.view.movieController:RenderTargetManualFinalize()
    self.view.movieController:PlayerManualFinalize()
end



VideoPlayer._TriggerPlay = HL.Method() << function(self)
    self.m_preparedVideo = nil
    self.view.canvasGroup.alpha = 1.0
    self.view.movieController.player:SetVolume(self.m_videoVolume)
    self.view.movieController:Play()
end




VideoPlayer.OnPlayerStateChange = HL.Method(HL.Any) << function(self, state)
    local listenerList = self.m_stateChangeListener[state]
    if listenerList then
        for _, listener in ipairs(listenerList) do
            listener(state, self.view.movieController)
        end
    end
    self.m_stateChangeListener[state] = nil
end





VideoPlayer._AddStateChangeListener = HL.Method(HL.Any, HL.Function) << function(self, state, listener)
    if listener == nil then
        return
    end

    local listenerList = self.m_stateChangeListener[state]
    if not listenerList then
        listenerList = {}
        self.m_stateChangeListener[state] = listenerList
    end
    table.insert(listenerList, listener)
end






VideoPlayer._ClearStateChangeListener = HL.Method() << function(self)
    self.m_stateChangeListener = {}
end


if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
    
    VideoPlayer.m_debugCor = HL.Field(HL.Thread)

    
    
    VideoPlayer._StartDisplayDebugInfo = HL.Method() << function(self)
        if DISABLE_VIDEO_DEBUG_INFO then
            return
        end

        self.view.videoDebugNode.gameObject:SetActive(true)
        if self.m_debugCor == nil then
            self.m_debugCor = self:_StartCoroutine(function()
                while true do
                    if self.view.movieController.player then
                        local info = VideoPlayer.GetDebugInfoStrFromPlayer(self.view.movieController.player)
                        self.view.videoDebugNode.debugText.text = info
                    end
                    coroutine.step()
                end
            end)
        end
    end

    
    
    VideoPlayer._StopDisplayDebugInfo = HL.Method() << function(self)
        if self.m_debugCor then
            self:_ClearCoroutine(self.m_debugCor)
            self.m_debugCor = nil
        end
        self.view.videoDebugNode.gameObject:SetActive(false)
    end

    
    
    VideoPlayer.GetDebugInfoStrFromPlayer = HL.StaticMethod(HL.Userdata).Return(HL.String) << function(player)
        if player == nil then
            return "Player is nil"
        end

        local movieInfo = player.movieInfo
        local frameInfo = player.frameInfo

        if movieInfo == nil or frameInfo == nil then
            return "MovieInfo or FrameInfo is Not Available"
        end

        local frameNo = frameInfo.frameNo
        local totalFrame = movieInfo.totalFrames
        local frameRate = movieInfo.framerateN / movieInfo.framerateD
        local width = movieInfo.dispWidth
        local height = movieInfo.dispHeight
        local time = frameInfo.time / frameInfo.tunit

        local formatterStr = "FProgress: %d/%d,\nFrameRate: %.2f,\nResolution: %dx%d,\nTime: %.2f \n"
        local info = string.format(formatterStr,
            frameNo, totalFrame,
            frameRate,
            width, height,
            time
        )

        return info
    end
end


HL.Commit(VideoPlayer)
return VideoPlayer

