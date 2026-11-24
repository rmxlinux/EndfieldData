local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonMask

CommonMaskCtrl = HL.Class('CommonMaskCtrl', uiCtrl.UICtrl)







CommonMaskCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_COMMON_MASK_SHUTDOWN] = 'OnCommonMaskShutDown',
}


















CommonMaskCtrl.m_curMaskData = HL.Field(HL.Any)







CommonMaskCtrl.m_extraData = HL.Field(HL.Table)

CommonMaskCtrl.m_afterEndCallbacks = HL.Field(HL.Table)

CommonMaskCtrl.m_state = HL.Field(HL.Number) << 0

CommonMaskCtrl.m_clearWhenHide = HL.Field(HL.Boolean) << true

CommonMaskCtrl.m_corKey = HL.Field(HL.Thread)

CommonMaskCtrl.m_timeoutTimer = HL.Field(HL.Number) << -1

CommonMaskCtrl.m_logicId = HL.Field(HL.Number) << 0

CommonMaskCtrl.m_showingText = HL.Field(HL.Boolean) << false

CommonMaskCtrl.m_handles = HL.Field(HL.Table)

CommonMaskCtrl.m_entitySyncLoadModeEnabled = HL.Field(HL.Boolean) << false

CommonMaskCtrl.m_burstModeEnabled = HL.Field(HL.Boolean) << false

CommonMaskCtrl.m_playerBlackScreenActive = HL.Field(HL.Boolean) << false

CommonMaskCtrl.m_mainHudBlackScreenActive = HL.Field(HL.Boolean) << false

CommonMaskCtrl.m_customBgGo = HL.Field(HL.Userdata)

CommonMaskCtrl.m_customBgPath = HL.Field(HL.String) << ""

CommonMaskCtrl.m_customBgPrefabKey = HL.Field(HL.Number) << -1

CommonMaskCtrl.OnCommonMaskStart = HL.StaticMethod(HL.Table) << function(arg)
    local ctrl = CommonMaskCtrl.AutoOpen(PANEL_ID, {}, true)
    local commonMaskData
    local handle
    if type(arg) == "table" then
        commonMaskData, handle = unpack(arg)
    else
        commonMaskData = arg
    end

    ctrl:AddCinematicQueueHandle(handle)
    ctrl:TryStartCommonMask(commonMaskData)
end

CommonMaskCtrl.OnCommonMaskEnd = HL.StaticMethod(HL.Table) << function(arg)
    local ctrl = CommonMaskCtrl.AutoOpen(PANEL_ID, {}, true)
    local commonMaskData
    local handle
    if type(arg) == "table" then
        commonMaskData, handle = unpack(arg)
    else
        commonMaskData = arg
    end

    ctrl:AddCinematicQueueHandle(handle)
    ctrl:TryStartCommonMask(commonMaskData)
end



CommonMaskCtrl.OnDisposeLuaEnv = HL.StaticMethod() << function()
    for _, panelId in ipairs({ PanelId.CommonMask, PanelId.CommonMaskLower }) do
        local isOpen, ctrl = UIManager:IsOpen(panelId)
        if isOpen then
            ctrl.m_afterEndCallbacks = {}
            ctrl:_Clear()
        end
    end
end

CommonMaskCtrl.OnCommonMaskShutDown = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    
    self.m_playerBlackScreenActive = false
    local narrative = self.m_curMaskData and self.m_curMaskData.textDataList and self.m_curMaskData.textDataList.Count > 0 and not self.m_curMaskData.forceNotNarrative
    local NarrativeUtils = CS.Beyond.Gameplay.NarrativeUtils
    if narrative then
        NarrativeUtils.SetInNarrativeBlackScreen(false)
    else
        NarrativeUtils.SetInBlackScreen(false)
    end
    Notify(MessageConst.ON_BLACK_SCREEN_OUT)
    self:_SetMainHudState(false)
    self:_ClearAndSolveCallBacks()
    self:_SolveAllAfterEndCallbacks()
    self:Close()
end

CommonMaskCtrl.TryStartCommonMask = HL.Method(CS.Beyond.Gameplay.UICommonMaskData) << function(self, commonMaskData)
    self:_UpdateCurMaskData(commonMaskData)
    self:_Refresh()
end

CommonMaskCtrl.AddCinematicQueueHandle = HL.Method(HL.Any) << function(self, handle)
    if handle and not self.m_handles[handle] then
        self.m_handles[handle] = true
    end
end

CommonMaskCtrl._ClearAllHandles = HL.Method() << function(self)
    for handle, _ in pairs(self.m_handles) do
        handle:Finish()
    end
    self.m_handles = {}
end

CommonMaskCtrl._UpdateTime = HL.Method(CS.Beyond.Gameplay.UICommonMaskData) << function(self, commonMaskData)
    self.m_curMaskData.fadeBeforeTime = math.max(self.m_curMaskData.fadeBeforeTime, commonMaskData.fadeBeforeTime)
    self.m_curMaskData.fadeInTime = math.max(self.m_curMaskData.fadeInTime, commonMaskData.fadeInTime)
    self.m_curMaskData.fadeWaitTime = math.max(self.m_curMaskData.fadeWaitTime, commonMaskData.fadeWaitTime)
    self.m_curMaskData.fadeOutTime = commonMaskData.fadeOutTime
    self.m_curMaskData.fadeAfterTime = commonMaskData.fadeAfterTime

    if self.m_curMaskData.textDataList.Count > 0 then
        self.m_curMaskData.textAfterTime = math.max(self.m_curMaskData.textAfterTime, commonMaskData.textAfterTime)
        self.m_curMaskData.textBeforeTime = math.max(self.m_curMaskData.textBeforeTime, commonMaskData.textBeforeTime)

        
        self.m_curMaskData.fadeWaitTime = 0
    end
end

CommonMaskCtrl._UpdateCurMaskData = HL.Method(CS.Beyond.Gameplay.UICommonMaskData) << function(self, commonMaskData)
    
    local isLoadingOpened, loadingCtrl = UIManager:IsOpen(PanelId.Loading)
    local isTeleLoadingOpened, teleLoadingCtrl = UIManager:IsOpen(PanelId.TeleportLoading)
    local isLoadingPanelClosing = false

    if isLoadingOpened then
        isLoadingPanelClosing = loadingCtrl.m_isClosing
    end

    if isTeleLoadingOpened then
        isLoadingPanelClosing = teleLoadingCtrl.m_isClosing
    end

    if isLoadingPanelClosing then
        commonMaskData.fadeInTime = 0
        logger.info("CommonMaskCtrl _UpdateCurMaskData isLoadingPanelClosing, fade in time 0!!!")
    end
    if not self.m_curMaskData then
        self.m_curMaskData = commonMaskData
        self.m_extraData = {
            fadeInCallbacks = {},
            textEndCallbacks = {},
            callbacks = {},
            debugContextList = {},
        }
        self.m_afterEndCallbacks = {}
    end

    if self.m_curMaskData.canBeOverride then
        if not commonMaskData.fadeInTime or commonMaskData.fadeInTime < 0 then
            commonMaskData.fadeInTime = self.view.config.FADE_TIME
        end

        if not commonMaskData.fadeOutTime or commonMaskData.fadeOutTime < 0 then
            commonMaskData.fadeOutTime = self.view.config.FADE_TIME
        end

        
        if self.m_curMaskData.textDataList.Count <= 0 and commonMaskData.textDataList.Count > 0 then
            local totalTime = 0
            for _, data in pairs(commonMaskData.textDataList) do
                local langKey = data.langKey
                local textBeforeTime = data.textBeforeTime
                local res, rawText = langKey:TryGetText()
                local speed = 1

                local key = langKey.key
                local hasVo, voiceId = Tables.textVoIdTable:TryGetValue(key)
                local calculatedDuration = -1
                if hasVo then
                    local res, duration = VoiceUtils.TryGetVoiceDuration(voiceId)
                    if res then
                        calculatedDuration = duration
                    end
                end

                if BEYOND_DEBUG then
                    if not res then
                        rawText = key
                        logger.error("当前id表里不存在: " .. rawText)
                        speed = 5
                    end
                end

                local minDuration = Tables.cinematicConst.blackScreenTextMinDuration
                if calculatedDuration < 0 then
                    calculatedDuration = UIUtils.getTextShowDuration(rawText, speed)
                end
                local finalTime = math.max(minDuration, calculatedDuration)
                totalTime = totalTime + finalTime + textBeforeTime
            end
            totalTime = totalTime + commonMaskData.textBeforeTime + commonMaskData.textAfterTime
            commonMaskData.fadeWaitTime = totalTime
            self.m_curMaskData.textDataList = commonMaskData.textDataList
            self.m_curMaskData.forceNotNarrative = commonMaskData.forceNotNarrative
        end

        self:_UpdateTime(commonMaskData)
        self.m_curMaskData.fadeType = commonMaskData.fadeType
        self.m_curMaskData.isBlock = commonMaskData.isBlock
        self.m_curMaskData.notHideCursor = commonMaskData.notHideCursor

        self.m_extraData.waitHide = commonMaskData.waitHide
        self.m_extraData.enableTimeOutWhenWaitHide = commonMaskData.enableTimeOutWhenWaitHide
        if self.m_curMaskData.maskType == commonMaskData.maskType and self.m_curMaskData.customMaskType == commonMaskData.customMaskType then
            self.m_curMaskData.customWidgetArgs = commonMaskData.customWidgetArgs
            if self.m_customBgGo and NotNull(self.m_customBgGo) then
                self:_InitCustomBg()
            end
        end
    else
        if commonMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn then
            self.m_extraData.waitHide = self.m_extraData.waitHide or commonMaskData.waitHide
            self.m_extraData.enableTimeOutWhenWaitHide = self.m_extraData.enableTimeOutWhenWaitHide or commonMaskData.enableTimeOutWhenWaitHide
        else
            self.m_extraData.waitHide = false
            self.m_extraData.enableTimeOutWhenWaitHide = false
        end
    end

    
    local fadeInCallback = commonMaskData.fadeInCallback
    local callback = commonMaskData.callback
    local textEndCallback = commonMaskData.textEndCallback
    local afterEndCallback = commonMaskData.afterEndCallback
    if fadeInCallback then
        self:_TryAddCallback(UIConst.COMMON_MASK_STATE.Masking, fadeInCallback)
    end
    if callback then
        self:_TryAddCallback(UIConst.COMMON_MASK_STATE.End, callback)
    end
    if textEndCallback then
        self:_TryAddCallback(UIConst.COMMON_MASK_STATE.ShowTextEnd, textEndCallback)
    end

    if afterEndCallback then
        self:_TryAddAfterEndCallback(afterEndCallback)
    end

    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        if NarrativeUtils.ShouldShowNarrativeDebugNode() then
            self:_AppendDebugContext(commonMaskData.extraData)
            self:_ShowDebugInfo()
        end
    end
end

CommonMaskCtrl._TryAddAfterEndCallback = HL.Method(HL.Any) << function(self, afterEndCallback)
    table.insert(self.m_afterEndCallbacks, afterEndCallback)
end

CommonMaskCtrl._TryAddCallback = HL.Method(HL.Number, HL.Any) << function(self, state, callback)
    if not self.m_extraData.callbacks[state] then
        self.m_extraData.callbacks[state] = {}
    end
    table.insert(self.m_extraData.callbacks[state], callback)
end

CommonMaskCtrl._AppendDebugContext = HL.Method(HL.Opt(HL.Any)) << function(self, extraData)
    if not self.m_extraData then
        return
    end

    if not self.m_extraData.debugContextList then
        self.m_extraData.debugContextList = {}
    end

    self.m_extraData.extraData = extraData

    local sourceText = "nil"
    local desc = "nil"
    if extraData then
        if extraData.sourceType then
            sourceText = extraData.sourceType:ToString()
        end
        desc = extraData.desc or ""
    end

    table.insert(self.m_extraData.debugContextList, {
        sourceText = sourceText,
        desc = desc,
    })
end

CommonMaskCtrl._Refresh = HL.Method() << function(self)
    if self.m_state == UIConst.COMMON_MASK_STATE.None then
        self:_StartCommonMask()
    elseif self.m_state == UIConst.COMMON_MASK_STATE.Masking or self.m_state == UIConst.COMMON_MASK_STATE.ShowTextEnd then
        
        if not self.m_extraData or not self.m_extraData.waitHide then
            self.m_curMaskData.fadeType = UIConst.UI_COMMON_MASK_FADE_TYPE.FadeOut
            self:_StartCommonMask()
        else
            self:_SolveCallbacks()
        end
    else
        self:_SolveCallbacks()
    end
end

CommonMaskCtrl._CheckNewCommonMask = HL.Method().Return(HL.Boolean) << function(self)
    if self.m_state == UIConst.COMMON_MASK_STATE.None then
        return true
    end
end

CommonMaskCtrl._SwitchState = HL.Method(HL.Number) << function(self, newState)
    local oldState = self.m_state
    self.m_state = newState

    local newState = self.m_state
    logger.info(string.format("CommonMask _SwitchState oldState : %s, newState: %s", oldState, newState))
    if self.m_state == UIConst.COMMON_MASK_STATE.End then
        self.m_state = UIConst.COMMON_MASK_STATE.None
        self:_ClearAndSolveCallBacks()
    else
        self:_SolveCallbacks()
    end

end


CommonMaskCtrl._InvokeCallbacks = HL.Method(HL.Table) << function(self, callbacks)
    for _, callback in pairs(callbacks) do
        if callback then
            local succ, log = xpcall(callback, debug.traceback)
            if not succ then
                logger.critical("CommonMaskCtrl callback fail", self.panelCfg.name, "state:", self.m_state, "\n" .. tostring(log))
            end
        end
    end
end

CommonMaskCtrl._SolveAllAfterEndCallbacks = HL.Method() << function(self)
    if not self.m_afterEndCallbacks then
        logger.info("CommonMaskCtrl _SolveAllAfterEndCallbacks no afterEndCallbacks")
        return
    end
    self:_InvokeCallbacks(self.m_afterEndCallbacks)
    self.m_afterEndCallbacks = {}
end

CommonMaskCtrl._SolveCallbacks = HL.Method() << function(self)
    if not self.m_extraData or not self.m_extraData.callbacks then
        logger.info("CommonMaskCtrl _SolveCallbacks no callbacks")
        return
    end

    local flushTable = {}
    local executeCbs = {}
    for state, callbacks in pairs(self.m_extraData.callbacks) do
        if callbacks then
            
            if state <= self.m_state or self.m_state == UIConst.COMMON_MASK_STATE.None then
                for _, callback in pairs(callbacks) do
                    if callback then
                        table.insert(executeCbs, callback)
                    end
                end
                table.insert(flushTable, state)
            end
        end
    end

    
    for _, state in pairs(flushTable) do
        self.m_extraData.callbacks[state] = nil
    end

    logger.info("CommonMaskCtrl _SolveCallbacks do callbacks, num: %d", #executeCbs)

    
    self:_InvokeCallbacks(executeCbs)
end

CommonMaskCtrl._UnloadCustomBg = HL.Method() << function(self)
    if self.m_customBgGo and NotNull(self.m_customBgGo) then
        
        self.m_customBgGo:SetActive(false)
        GameObject.DestroyImmediate(self.m_customBgGo)
    end
    self.m_customBgGo = nil
    if self.m_customBgPrefabKey >= 0 then
        self.loader:DisposeHandleByKey(self.m_customBgPrefabKey)
        self.m_customBgPrefabKey = -1
    end
    self.m_customBgPath = ""
end

CommonMaskCtrl._InitCustomBg = HL.Method() << function(self)
    local data = self.m_curMaskData
    if data.maskType ~= UIConst.UI_COMMON_MASK_TYPE.Custom or data.fadeType ~= UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn or string.isEmpty(data.customWidgetArgs) then
        return
    end
    local cfg = UIConst.UI_CUSTOM_LOADING_CONFIG[data.customMaskType]
    if cfg and cfg.init then
        local luaWidget = self.m_customBgGo:GetComponent("LuaUIWidget")
        cfg.init(luaWidget.table[1], data.customWidgetArgs)
    end
end

CommonMaskCtrl._RefreshMaskType = HL.Method().Return(HL.Any) << function(self)
    local maskType = self.m_curMaskData.maskType
    local maskCanvas
    local maskWhite = maskType == UIConst.UI_COMMON_MASK_TYPE.WhiteScreen
    local maskAlphaBlock = maskType == UIConst.UI_COMMON_MASK_TYPE.AlphaBlock
    local maskSweetPie = maskType == UIConst.UI_COMMON_MASK_TYPE.SweetPieMask
    local maskBlack = (not maskWhite) and (not maskAlphaBlock) and (not maskSweetPie)
    local customBgCfg = maskType == UIConst.UI_COMMON_MASK_TYPE.Custom and UIConst.UI_CUSTOM_LOADING_CONFIG[self.m_curMaskData.customMaskType]

    if maskWhite then
        maskCanvas = self.view.maskWhite
    elseif maskAlphaBlock then
        maskCanvas = self.view.maskAlphaBlock
    elseif maskSweetPie then
        maskCanvas = self.view.miBingMask
    else
        maskCanvas = self.view.mask
    end

    if customBgCfg then
        self.view.customBg.gameObject:SetActive(true)
        local hasSprite = not string.isEmpty(customBgCfg.sprite)
        self.view.customBg.enabled = hasSprite
        if hasSprite then
            self.view.customBg:LoadSprite(UIConst.UI_LOADING_BG, customBgCfg.sprite)
        end
        maskCanvas = self.view.customBgCanvasGroup
        if self.m_customBgPath ~= customBgCfg.prefab then
            self:_UnloadCustomBg()
            local prefab
            if not string.isEmpty(customBgCfg.prefab) and self.loader:CheckExists(customBgCfg.prefab) then
                prefab, self.m_customBgPrefabKey = self.loader:LoadGameObject(customBgCfg.prefab)
            end
            if prefab then
                self.m_customBgGo = CSUtils.CreateObject(prefab, self.view.customBg.gameObject)
                self.m_customBgPath = customBgCfg.prefab
                Utils.wrapLuaNode(self.m_customBgGo)
                self:_InitCustomBg()
            end
        end
    else
        self:_UnloadCustomBg()
        self.view.customBg.gameObject:SetActive(false)
    end

    self.view.mask.gameObject:SetActive(maskBlack)
    self.view.maskWhite.gameObject:SetActive(maskWhite)
    self.view.maskAlphaBlock.gameObject:SetActive(maskAlphaBlock)
    if self.view.miBingMask then
        self.view.miBingMask.gameObject:SetActive(maskSweetPie)
    end
    self.view.text.gameObject:SetActive(false)
    self.view.textWhite.gameObject:SetActive(false)
    return maskCanvas
end

CommonMaskCtrl._RefreshTextCor = HL.Method() << function(self)
    if self.m_showingText then
        return
    end

    self.m_showingText = true

    local textBeforeTime = self.m_curMaskData.textBeforeTime
    local textAfterTime = self.m_curMaskData.textAfterTime
    local textDataList = self.m_curMaskData.textDataList

    if textBeforeTime > 0 then
        coroutine.wait(textBeforeTime)
    end

    for _, data in pairs(textDataList) do
        local langKey = data.langKey
        local singleTextBeforeTime = data.textBeforeTime
        if singleTextBeforeTime > 0 then
            self.view.text:DOFade(0, self.view.config.TEXT_FADE_IN_TIME)
            coroutine.wait(singleTextBeforeTime)
        end

        local res, rawText = langKey:TryGetText()
        local speed = 1

        local key = langKey.key
        local calculatedDuration = -1

        if key ~= nil then
            local hasVo, voiceId = Tables.textVoIdTable:TryGetValue(key)
            if hasVo then
                local res, duration = VoiceUtils.TryGetVoiceDuration(voiceId)
                if res then
                    calculatedDuration = duration
                    VoiceManager:SpeakNarrative(voiceId, nil, CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig.DEFAULT_CONFIG)
                end
            end
        end

        if BEYOND_DEBUG then
            if data.useCustomText then
                rawText = string.format("<color=red>[Dev Only] Debug Custom Text:</color> %s", data.customText)
                calculatedDuration = Tables.cinematicConst.blackScreenTextMinDuration
            else
                if not res then
                    rawText = key
                    logger.error("当前id表里不存在: " .. rawText)
                    speed = 5
                end
            end
        end

        local minDuration = Tables.cinematicConst.blackScreenTextMinDuration
        if calculatedDuration < 0 then
            calculatedDuration = UIUtils.getTextShowDuration(rawText, speed)
        end
        local finalTime = math.max(minDuration, calculatedDuration)
        finalTime = finalTime + textBeforeTime

        self.view.text.text = rawText
        self.view.textWhite.text = rawText
        self.view.text.gameObject:SetActive(true)
        self.view.textWhite.gameObject:SetActive(true)
        UIUtils.changeAlpha(self.view.text, 0)
        self.view.text:DOFade(1, self.view.config.TEXT_FADE_IN_TIME)
        coroutine.wait(finalTime)
    end

    if textAfterTime > 0 then
        self.view.text:DOFade(0, self.view.config.TEXT_FADE_IN_TIME)
        coroutine.wait(textAfterTime)
    end

    
    self.m_curMaskData.textDataList = {}
    self.m_showingText = false
end

CommonMaskCtrl._DoMaskFade = HL.StaticMethod(Unity.CanvasGroup, HL.Number, HL.Number, HL.Opt(Unity.AnimationCurve)) <<
    function(maskCanvas, alpha, duration, curve)
        if maskCanvas then
            local tween = maskCanvas:DOFade(alpha, duration)
            if curve then
                tween:SetEase(curve)
            end
        end
    end


CommonMaskCtrl._DoMaskTransition = HL.Method(Unity.CanvasGroup, HL.Boolean, HL.Number, HL.Opt(Unity.AnimationCurve)).Return(HL.Number) <<
    function(self, maskCanvas, fadeIn, duration, curve)
        if self.m_curMaskData.maskType == UIConst.UI_COMMON_MASK_TYPE.SweetPieMask then
            local wrapper = self.view.miBingMaskAnimation
            local clip = fadeIn and wrapper.animationIn or wrapper.animationOut
            local clipLength = wrapper:GetClipLength(clip.name)
            wrapper:ClearTween(false)
            if duration <= 0 then
                wrapper:SampleClip(clip.name, clipLength, false)
                return 0
            end

            if fadeIn then
                wrapper:PlayInAnimation(nil, false)
            else
                wrapper:PlayOutAnimation()
            end
            return clipLength
        end

        local alpha = fadeIn and 1 or 0
        if duration > 0 then
            CommonMaskCtrl._DoMaskFade(maskCanvas, alpha, duration, curve)
            return duration
        end
        maskCanvas.alpha = alpha
        return 0
    end

CommonMaskCtrl._CheckSync = HL.Method().Return(HL.Boolean) << function(self)
    if not self.m_curMaskData then
        return true
    end

    local fadeIn = self.m_curMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn
    local fadeOut = self.m_curMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeOut
    
    if self.m_curMaskData.waitHide and fadeIn then
        return false
    end

    local noText = not self.m_curMaskData.textDataList or self.m_curMaskData.textDataList.Count <= 0

    if fadeIn and noText then
        if self.m_curMaskData.fadeInTime + self.m_curMaskData.fadeOutTime + self.m_curMaskData.fadeBeforeTime + self
            .m_curMaskData.fadeAfterTime + self.m_curMaskData.fadeWaitTime <= 0 then
            return true
        end
    end

    if fadeOut and noText then
        if self.m_curMaskData.fadeOutTime + self.m_curMaskData.fadeWaitTime + self.m_curMaskData.fadeAfterTime <= 0 then
            return true
        end
    end

    return false

end

CommonMaskCtrl._DoCommonMaskSync = HL.Method() << function(self)
    logger.info("CommonMaskCtrl _DoCommonMaskSync")
    local logicId = self.m_logicId
    local fadeIn = self.m_curMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn
    local maskCanvas = self:_RefreshMaskType()
    if fadeIn then
        self:_UpdatePlayerState(true)
        self:_SetMainHudState(true)
        
        if logicId ~= self.m_logicId then
            return
        end
        self:_SwitchState(UIConst.COMMON_MASK_STATE.WaitFade)

        
        self:_DoMaskTransition(maskCanvas, true, 0)
        if logicId ~= self.m_logicId then
            return
        end
        self:_SwitchState(UIConst.COMMON_MASK_STATE.FadingIn)

        
        if logicId ~= self.m_logicId then
            return
        end
        self:_SetCommonMaskFrameTagState(true)
        self:_SwitchState(UIConst.COMMON_MASK_STATE.Masking)
    end

    
    if not fadeIn or not self.m_extraData or not self.m_extraData.waitHide then
        self:_SetCommonMaskFrameTagState(false)
        NarrativeUtils.UnMuteAudioBlackScreen(self.m_curMaskData.layerType)
        
        self:_DoMaskTransition(maskCanvas, false, 0)
        if logicId ~= self.m_logicId then
            return
        end
        self:_SwitchState(UIConst.COMMON_MASK_STATE.FadingOut)

        
        if logicId ~= self.m_logicId then
            return
        end
        self:_SwitchState(UIConst.COMMON_MASK_STATE.WaitEnd)

        
        self:_UpdatePlayerState(false)
        if logicId ~= self.m_logicId then
            self:_SetMainHudState(false)
            self:Hide()
            return
        end

        
        self.m_clearWhenHide = false
        self:Hide()
        self:_SwitchState(UIConst.COMMON_MASK_STATE.End)
        self.m_clearWhenHide = true
        self:_SetMainHudState(false)
        self:_SolveAllAfterEndCallbacks()
    end
end

CommonMaskCtrl._ClearTimeoutTimer = HL.Method() << function(self)
    if self.m_timeoutTimer > 0 then
        self:_ClearTimer(self.m_timeoutTimer)
    end
    self.m_timeoutTimer = -1
end

CommonMaskCtrl._UpdatePlayerState = HL.Virtual(HL.Boolean) << function(self, inBlackScreen)
    self.m_playerBlackScreenActive = inBlackScreen
    local narrative = self.m_curMaskData and self.m_curMaskData.textDataList and self.m_curMaskData.textDataList.Count > 0 and not self.m_curMaskData.forceNotNarrative
    local NarrativeUtils = CS.Beyond.Gameplay.NarrativeUtils
    if narrative then
        NarrativeUtils.SetInNarrativeBlackScreen(inBlackScreen)
    else
        NarrativeUtils.SetInBlackScreen(inBlackScreen)
    end

    local message = inBlackScreen and MessageConst.ON_BLACK_SCREEN_IN or MessageConst.ON_BLACK_SCREEN_OUT
    Notify(message)
end

CommonMaskCtrl._SetMainHudState = HL.Method(HL.Boolean) << function(self, inBlackScreen)
    self.m_mainHudBlackScreenActive = inBlackScreen
    if inBlackScreen then
        Notify(MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_BEGIN)
    else
        Notify(MessageConst.NOTIFY_MAIN_HUD_BLACK_SCREEN_END)
    end
end

CommonMaskCtrl._ClearForForcedClose = HL.Method() << function(self)
    local releaseMainHudBlackScreen = self.m_mainHudBlackScreenActive
    if self.m_playerBlackScreenActive then
        self:_UpdatePlayerState(false)
    end

    self:_Clear()

    if releaseMainHudBlackScreen then
        self:_SetMainHudState(false)
    end
end

CommonMaskCtrl._SetCommonMaskFrameTagState = HL.Method(HL.Boolean) << function(self, inBlackScreen)
    if BEYOND_DEBUG_COMMAND then
        GameWorld.narrativeManager:SetCommonMaskFrameTagState(inBlackScreen)
    end
end

CommonMaskCtrl._SetBurstMode = HL.Method(HL.Boolean) << function(self, enable)
    if enable == self.m_burstModeEnabled then
        return
    end

    GameInstance.SetBurstMode(enable, GameInstance.EBurstModeReason.CommonMask)
    logger.important(CS.Beyond.EnableLogType.LevelLoader, string.format("CommonMask SetBurstMode %s", enable))
    self.m_burstModeEnabled = enable
end

CommonMaskCtrl._SetEntitySyncLoadMode = HL.Method(HL.Boolean) << function(self, enable)
    if enable == self.m_entitySyncLoadModeEnabled then
        return
    end
    logger.important(CS.Beyond.EnableLogType.LevelLoader, string.format("CommonMask SetEntitySyncLoadMode %s", enable))
    GameWorld.narrativeManager:SetEntitySyncLoadModeByCommonMask(enable)
    self.m_entitySyncLoadModeEnabled = enable
end

CommonMaskCtrl._DoCommonMaskASync = HL.Method() << function(self)
    local fadeIn = self.m_curMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn
    if fadeIn then
        self:_UpdatePlayerState(true)
        self:_SetMainHudState(true)
    end
    local fadeInTime = self.m_curMaskData.fadeInTime
    local maskCanvas = self:_RefreshMaskType()
    self.m_corKey = self:_StartCoroutine(function()
        local curve = self.m_curMaskData.curve

        local corKey = self.m_corKey
        logger.info("CommonMaskCtrl _DoCommonMaskASync" .. tostring(corKey))

        if fadeIn then
            
            local fadeBeforeTime = self.m_curMaskData.fadeBeforeTime

            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            self:_SwitchState(UIConst.COMMON_MASK_STATE.WaitFade)
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end

            if fadeBeforeTime > 0 then
                coroutine.wait(fadeBeforeTime)
            end

            
            fadeInTime = self.m_curMaskData.fadeInTime
            local transitionDuration = self:_DoMaskTransition(maskCanvas, true, fadeInTime, curve)

            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            self:_SwitchState(UIConst.COMMON_MASK_STATE.FadingIn)
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            if transitionDuration > 0 then
                coroutine.wait(transitionDuration)
            end

            

            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            self:_SetCommonMaskFrameTagState(true)
            self:_SwitchState(UIConst.COMMON_MASK_STATE.Masking)
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end

            local textDataList = self.m_curMaskData.textDataList
            if textDataList and textDataList.Count > 0 then
                self:_RefreshTextCor()
                self:_SwitchState(UIConst.COMMON_MASK_STATE.ShowTextEnd)
            end

            
            if self.m_extraData and self.m_extraData.waitHide then
                self:_ClearTween()

                
                local maskType = self.m_curMaskData.maskType
                local maskWhite = maskType == UIConst.UI_COMMON_MASK_TYPE.WhiteScreen
                local maskBlack = maskType == UIConst.UI_COMMON_MASK_TYPE.BlackScreen
                local maskSweetPie = maskType == UIConst.UI_COMMON_MASK_TYPE.SweetPieMask
                if maskWhite or maskBlack or maskSweetPie then
                    self:_SetBurstMode(true)
                    if self.m_curMaskData.enableEntitySyncLoadMode then
                        self:_SetEntitySyncLoadMode(true)
                    end
                end

                if self.m_extraData.enableTimeOutWhenWaitHide then
                    
                    self:_ClearTimeoutTimer()
                    local fadeWaitTime = self.m_curMaskData and self.m_curMaskData.fadeWaitTime or 0
                    if not self.m_isClosed then
                        self.m_timeoutTimer = self:_StartTimer(fadeWaitTime + UIConst.COMMON_MASK_WAIT_HIDE_TIME_OUT_TIME, function()
                            self:_ClearTimeoutTimer()
                            if self:IsShow() then
                                local errorInfo = "BlackScreen timeout shutdown"
                                if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
                                    if self.m_extraData and self.m_extraData.extraData then
                                        errorInfo = errorInfo .. ": " .. self.m_extraData.extraData.sourceType:ToString()
                                        errorInfo = errorInfo .. ", " .. self.m_extraData.extraData.desc
                                    end

                                    if NarrativeUtils.ShouldShowNarrativeDebugNode() then
                                        Notify(MessageConst.SHOW_TOAST, string.format("DEBUG黑屏超时: %s", errorInfo))
                                    end
                                end
                                NarrativeUtils.SetInBlackScreen(false)
                                self:_SetMainHudState(false)
                                self:Close()
                                logger.error(errorInfo)
                            end
                        end)
                    end
                end
                return
            end
        end

        
        self:_ClearTimeoutTimer()
        local fadeWaitTime = self.m_curMaskData and self.m_curMaskData.fadeWaitTime or 0
        if not self.m_isClosed then
            self.m_timeoutTimer = self:_StartTimer(fadeWaitTime + UIConst.COMMON_MASK_TIME_OUT_TIME, function()
                self:_ClearTimeoutTimer()
                if self:IsShow() then
                    local errorInfo = "BlackScreen timeout shutdown"
                    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
                        if self.m_extraData and self.m_extraData.extraData then
                            errorInfo = errorInfo .. ": " .. self.m_extraData.extraData.sourceType:ToString()
                            errorInfo = errorInfo .. ", " .. self.m_extraData.extraData.desc
                            if NarrativeUtils.ShouldShowNarrativeDebugNode() then
                                Notify(MessageConst.SHOW_TOAST, string.format("DEBUG黑屏超时: %s", errorInfo))
                            end
                        end
                    end
                    self:_SetMainHudState(false)
                    self:Close()
                    logger.error(errorInfo)
                end
            end)
        end

        
        if not fadeIn or not self.m_extraData or not self.m_extraData.waitHide then
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            
            local textDataList = self.m_curMaskData.textDataList
            if textDataList and textDataList.Count > 0 then
                self:_RefreshTextCor()
                self:_SwitchState(UIConst.COMMON_MASK_STATE.ShowTextEnd)
            end

            
            self.m_showingText = false

            local fadeWaitTime = self.m_curMaskData and self.m_curMaskData.fadeWaitTime or 0
            if fadeWaitTime > 0 then
                coroutine.wait(fadeWaitTime)
            end

            
            if self.m_extraData and self.m_extraData.waitHide then
                self:_ClearTween()
                return
            end

            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            
            self:_SetBurstMode(false)
            self:_SetEntitySyncLoadMode(false)

            
            local maskCanvas = self:_RefreshMaskType()
            local fadeOutTime = self.m_curMaskData and self.m_curMaskData.fadeOutTime or 0
            self:_SetCommonMaskFrameTagState(false)
            NarrativeUtils.UnMuteAudioBlackScreen(self.m_curMaskData.layerType, fadeOutTime);
            local transitionDuration = self:_DoMaskTransition(maskCanvas, false, fadeOutTime, curve)

            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            self:_SwitchState(UIConst.COMMON_MASK_STATE.FadingOut)
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            if transitionDuration > 0 then
                coroutine.wait(transitionDuration)
            end


            
            local fadeAfterTime = self.m_curMaskData and self.m_curMaskData.fadeAfterTime or 0
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            self:_SwitchState(UIConst.COMMON_MASK_STATE.WaitEnd)
            if CoroutineManager:IsCorCleared(corKey) then
                return
            end
            if fadeAfterTime > 0 then
                coroutine.wait(fadeAfterTime)
            end

            self:_UpdatePlayerState(false)
            

            if CoroutineManager:IsCorCleared(corKey) then
                self:Hide()
                return
            end
            
            self.m_clearWhenHide = false
            self:Hide()
            self:_SwitchState(UIConst.COMMON_MASK_STATE.End)
            self:_ClearTimeoutTimer()
            self.m_clearWhenHide = true
            self:_SetMainHudState(false)
            self:_SolveAllAfterEndCallbacks()
        end
    end)
end

CommonMaskCtrl._StartCommonMask = HL.Method() << function(self)
    if self.m_curMaskData then
        self:ChangeCurPanelBlockSetting(self.m_curMaskData.isBlock)
        self:ChangePanelCfg("realMouseMode",
            self.m_curMaskData.notHideCursor and Types.EPanelMouseMode.NeedShow or Types.EPanelMouseMode.ForceHide)
        self:_ClearTween()
        local maskCanvas = self:_RefreshMaskType()
        local fadeIn = self.m_curMaskData.fadeType == UIConst.UI_COMMON_MASK_FADE_TYPE.FadeIn
        local fadeInTime = self.m_curMaskData.fadeInTime
        local fadeOutTime = self.m_curMaskData.fadeOutTime
        
        if self.m_curMaskData.maskType == UIConst.UI_COMMON_MASK_TYPE.SweetPieMask then
            local wrapper = self.view.miBingMaskAnimation
            local clip = fadeIn and wrapper.animationIn or wrapper.animationOut
            local clipLength = wrapper:GetClipLength(clip.name)
            
            local sampleEnd = fadeIn and fadeInTime <= 0
            wrapper:SampleClip(clip.name, sampleEnd and clipLength or 0, false)
        elseif fadeIn then
            if fadeInTime <= 0 then
                maskCanvas.alpha = 1
            else
                maskCanvas.alpha = 0
            end
        else
            if fadeOutTime <= 0 then
                maskCanvas.alpha = 0
            else
                maskCanvas.alpha = 1
            end
            maskCanvas.alpha = 1
        end

        if self:_CheckSync() then
            self.m_logicId = self.m_logicId + 1
            self:_DoCommonMaskSync()
        else
            self:_DoCommonMaskASync()
        end
    end

    self:_ShowDebugInfo()

end

CommonMaskCtrl._ShowDebugInfo = HL.Method() << function(self)
    self.view.extraNode.gameObject:SetActive(false)
    if BEYOND_DEBUG or BEYOND_DEBUG_COMMAND then
        if NarrativeUtils.ShouldShowNarrativeDebugNode() then
            if self.m_extraData and self.m_extraData.extraData then
                local sourceText = ""
                local sourceDesc = ""
                local layerText = self.panelCfg and self.panelCfg.name == "CommonMaskLower" and "Low" or "High"
                local debugContextList = self.m_extraData.debugContextList
                if debugContextList and #debugContextList > 0 then
                    local latestIndex = #debugContextList
                    local lines = { string.format("<color=#FF5555>%s</color>", layerText) }
                    local maxDisplayCount = 3
                    local startIndex = math.max(1, latestIndex - maxDisplayCount + 1)
                    if startIndex > 1 then
                        table.insert(lines, string.format("<size=80%%><color=#888888>... %d earlier calls omitted</color></size>", startIndex - 1))
                    end
                    for index = startIndex, latestIndex do
                        local data = debugContextList[index]
                        if index == latestIndex then
                            table.insert(lines, string.format("<color=#FFD166>[LAST %02d] %s</color>", index, data.desc))
                        else
                            table.insert(lines, string.format("[%02d] %s", index, data.desc))
                        end
                    end
                    sourceDesc = table.concat(lines, "\n")
                else
                    sourceDesc = string.format("<color=#FF5555>%s</color>\n%s", layerText, self.m_extraData.extraData.desc or "")
                end
                self.view.extraNode.gameObject:SetActive(true)
                self.view.extraNode.sourceText.text = sourceText
                self.view.extraNode.sourceDesc.text = sourceDesc
            end
        end
    end
end

CommonMaskCtrl._Clear = HL.Method() << function(self)
    logger.info("CommonMaskCtrl _Clear")
    self:_SetBurstMode(false)
    self:_SetEntitySyncLoadMode(false)
    self:_ClearTween()
    self:_SetCommonMaskFrameTagState(false)
    self.m_showingText = false
    if self.m_curMaskData then
        NarrativeUtils.UnMuteAudioBlackScreen(self.m_curMaskData.layerType)
        self.m_curMaskData:DisposeByLua()
    else
        NarrativeUtils.UnMuteAudioBlackScreen(UIConst.UI_COMMON_MASK_LAYER_TYPE.Low)
        NarrativeUtils.UnMuteAudioBlackScreen(UIConst.UI_COMMON_MASK_LAYER_TYPE.High)
    end
    self.m_curMaskData = nil
    self.m_extraData = nil
    self.m_state = UIConst.COMMON_MASK_STATE.None
    self:_UnloadCustomBg()
    self:_ClearTimeoutTimer()
    self:_ClearAllHandles()
end

CommonMaskCtrl._ClearAndSolveCallBacks = HL.Method() << function(self)
    if not self.m_extraData or not self.m_extraData.callbacks then
        self:_Clear()
        return
    end

    local executeCbs = {}
    for state, callbacks in pairs(self.m_extraData.callbacks) do
        if callbacks then
            for _, callback in pairs(callbacks) do
                if callback then
                    table.insert(executeCbs, callback)
                end
            end
        end
    end

    self:_Clear()

    self:_InvokeCallbacks(executeCbs)
end

CommonMaskCtrl._ClearTween = HL.Method() << function(self)
    self.view.mask:DOKill()
    self.view.maskWhite:DOKill()
    self.view.text:DOKill()
    
    if self.view.miBingMaskAnimation then
        self.view.miBingMaskAnimation:ClearTween(false)
    end
    self.m_showingText = false
    local corKey = self.m_corKey
    if self.m_corKey then
        self.m_corKey = self:_ClearCoroutine(self.m_corKey)
    end
    logger.info("CommonMaskCtrl _ClearTween Finish" .. tostring(corKey))
end

CommonMaskCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_handles = {}
end

CommonMaskCtrl.OnHide = HL.Override() << function(self)
    if self.m_clearWhenHide then
        self:_Clear()
    end
    self:_ClearTimeoutTimer()
end

CommonMaskCtrl.OnClose = HL.Override() << function(self)
    self:_ClearForForcedClose()
end

HL.Commit(CommonMaskCtrl)
