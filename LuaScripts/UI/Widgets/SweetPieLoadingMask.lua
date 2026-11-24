local StringListType = CS.System.Collections.Generic.List(CS.System.String)

local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


SweetPieLoadingMask = HL.Class('SweetPieLoadingMask', UIWidgetBase)


SweetPieLoadingMask.s_lastSequenceIndex = HL.StaticField(HL.Number) << 0
SweetPieLoadingMask.s_lastFrameIndex = HL.StaticField(HL.Number) << 0
SweetPieLoadingMask.m_sequenceIndex = HL.Field(HL.Number) << 0
SweetPieLoadingMask.m_useScreenshot = HL.Field(HL.Boolean) << false


SweetPieLoadingMask._OnCreate = HL.Override() << function(self)
    self:InitSweetPieLoadingMask()
end

SweetPieLoadingMask._OnEnable = HL.Override() << function(self)
    self:_SetSceneBlurEnabled(self.m_useScreenshot)
end

SweetPieLoadingMask._OnDisable = HL.Override() << function(self)
    self:_SavePlaybackState()
    self:_SetSceneBlurEnabled(false)
end

SweetPieLoadingMask._OnDestroy = HL.Override() << function(self)
    
    self:_SetSceneBlurEnabled(false)
    self.view.loadingMaskSequence:ReleaseSequence()
end



SweetPieLoadingMask.InitSweetPieLoadingMask = HL.Method(HL.Opt(HL.String)) << function(self, argsJson)
    local args
    if not string.isEmpty(argsJson) then
        local success, decodedArgs = pcall(Json.decode, argsJson)
        if success and type(decodedArgs) == "table"
            and (decodedArgs.sequenceIndex == nil or type(decodedArgs.sequenceIndex) == "number")
            and (decodedArgs.resumeLastPlayback == nil or type(decodedArgs.resumeLastPlayback) == "boolean")
            and (decodedArgs.useScreenshot == nil or type(decodedArgs.useScreenshot) == "boolean") then
            args = decodedArgs
        else
            logger.error("SweetPieLoadingMask invalid custom args, use default playback", argsJson)
        end
    end
    local sequenceIndex = 0
    local resumeLastPlayback = false
    local useScreenshot = false
    if args then
        sequenceIndex = args.sequenceIndex or 0
        resumeLastPlayback = args.resumeLastPlayback or false
        useScreenshot = args.useScreenshot or false
    end
    local frameIndex = 0
    if resumeLastPlayback and SweetPieLoadingMask.s_lastSequenceIndex > 0 then
        sequenceIndex = SweetPieLoadingMask.s_lastSequenceIndex
        frameIndex = SweetPieLoadingMask.s_lastFrameIndex
    end

    local sequences = self.config.LOADING_SEQUENCES
    if sequenceIndex ~= 0 and not sequences["sequence" .. sequenceIndex] then
        logger.error("SweetPieLoadingMask invalid sequence index, use random sequence", sequenceIndex)
        sequenceIndex = 0
        frameIndex = 0
    end
    if sequenceIndex == 0 then
        local sequenceKey = lume.randomchoice(lume.keys(sequences))
        sequenceIndex = tonumber(string.match(sequenceKey, "^sequence(%d+)$"))
    end
    local sequence = sequences["sequence" .. sequenceIndex]
    local picNames = string.split(sequence.picNames, ",")
    local spritePaths = StringListType()
    for _, picName in ipairs(picNames) do
        spritePaths:Add(UIUtils.getSpritePath(UIConst.UI_SPRITE_DIALOG_BG, picName))
    end
    local sequenceImage = self.view.loadingMaskSequence
    sequenceImage.maxCachedFrameCount = 2
    self.m_sequenceIndex = sequenceIndex
    sequenceImage:LoadSequence(spritePaths, 1 / sequence.frameDuration, frameIndex)

    self.m_useScreenshot = useScreenshot
    self:_SetSceneBlurEnabled(useScreenshot and self.gameObject.activeInHierarchy)
    self.view.sceneBlur.gameObject:SetActive(useScreenshot)
    local staticBlurBgPath = self.config.STATIC_BLUR_BG_PATH
    local showStaticBlur = not useScreenshot and not string.isEmpty(staticBlurBgPath)
    if showStaticBlur then
        self.view.staticBlur.texture = self.loader:LoadTexture(staticBlurBgPath)
    end
    self.view.staticBlur.gameObject:SetActive(showStaticBlur)
end

SweetPieLoadingMask._SavePlaybackState = HL.Method() << function(self)
    if self.m_sequenceIndex == 0 then
        return
    end
    SweetPieLoadingMask.s_lastSequenceIndex = self.m_sequenceIndex
    SweetPieLoadingMask.s_lastFrameIndex = self.view.loadingMaskSequence.currentFrameIndex
end


SweetPieLoadingMask._SetSceneBlurEnabled = HL.Method(HL.Boolean) << function(self, enabled)
    
    Notify(MessageConst.FORCE_ENABLE_UI_SCENE_BLUR, { key = self, enabled = enabled or nil })
end

HL.Commit(SweetPieLoadingMask)
return SweetPieLoadingMask
