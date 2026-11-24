local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


MultiplayerEmojiCell = HL.Class('MultiplayerEmojiCell', UIWidgetBase)

MultiplayerEmojiCell.m_emojiId = HL.Field(HL.String) << ""
MultiplayerEmojiCell.m_hideTimerId = HL.Field(HL.Number) << -1
MultiplayerEmojiCell.m_onClick = HL.Field(HL.Function)
MultiplayerEmojiCell.m_voiceHandleId = HL.Field(HL.Number) << -1
MultiplayerEmojiCell.m_isPlaying = HL.Field(HL.Boolean) << false
MultiplayerEmojiCell.m_emojiPrefabObject = HL.Field(CS.UnityEngine.GameObject)
MultiplayerEmojiCell.m_emojiPrefabHandle = HL.Field(HL.Number) << -1


MultiplayerEmojiCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.clickBtn.onClick:RemoveAllListeners()
    self.view.clickBtn.onClick:AddListener(function()
        if self.m_onClick ~= nil then
            self.m_onClick(self.m_emojiId)
        end
    end)
end

MultiplayerEmojiCell.Init = HL.Method(HL.String) << function(self, emojiId)
    self:_FirstTimeInit()
    self:_HideEmojiPrefab()

    local animationWrapper = self.view.animationWrapper
    animationWrapper:ClearTween(false)
    animationWrapper:SampleToInAnimationEnd()
    self.m_isPlaying = false
    self:_ClearHideTimer()
    self:_StopVoice()
    self.m_onClick = nil
    self.view.clickBtn.gameObject:SetActiveIfNecessary(false)

    local found, info = Tables.multiplayerEmojiInfoTable:TryGetValue(emojiId)
    if not found or info == nil then
        self:Clear()
        logger.error("[MultiplayerEmojiCell] multiplayerEmojiInfoTable 查不到 emojiId", emojiId)
        return
    end

    self.m_emojiId = emojiId
    self.view.emojiTxt.text = info.emojiDesc or ""
    self.view.emojiImg:LoadSprite(UIConst.UI_SPRITE_MULTIPLAYER_EMOJI, info.emojiIcon or "")
    self.view.stateController:SetState(string.isEmpty(info.emojiDesc) and MultiplayerConst.EEmojiState.NoText
        or MultiplayerConst.EEmojiState.Text)
    self.gameObject:SetActiveIfNecessary(true)
end

MultiplayerEmojiCell.EnableClick = HL.Method(HL.Function) << function(self, onClick)
    self:_FirstTimeInit()
    self.m_onClick = onClick
    self.view.clickBtn.gameObject:SetActiveIfNecessary(true)
end

MultiplayerEmojiCell.Play = HL.Method(HL.Opt(HL.String, HL.Number)) << function(self, charId, duration)
    self:_StopVoice()
    if string.isEmpty(self.m_emojiId) then
        return
    end

    self:_ClearHideTimer()
    self.m_isPlaying = true
    self.gameObject:SetActiveIfNecessary(true)
    local animationWrapper = self.view.animationWrapper
    animationWrapper:ClearTween(false)
    animationWrapper:PlayInAnimation()
    self:_PlayEmojiPrefab()
    self:_TryPlayVoice(charId)

    
    local timerId
    timerId = self:_StartTimer(duration or MultiplayerConst.EMOJI_SHOW_DURATION, function()
        if self.m_hideTimerId ~= timerId then
            return
        end
        self.m_hideTimerId = -1
        animationWrapper:PlayOutAnimation(function()
            self:Clear()
        end)
    end, true)
    self.m_hideTimerId = timerId
end

MultiplayerEmojiCell.Clear = HL.Method() << function(self)
    self.m_isPlaying = false
    self.view.animationWrapper:ClearTween(false)
    self:_ClearHideTimer()
    self:_StopVoice()
    self:_HideEmojiPrefab()
    self.m_emojiId = ""
    self.m_onClick = nil
    self.view.clickBtn.gameObject:SetActiveIfNecessary(false)
    self.gameObject:SetActiveIfNecessary(false)
end


MultiplayerEmojiCell._PlayEmojiPrefab = HL.Method() << function(self)
    self:_HideEmojiPrefab()
    local prefabName = MultiplayerConst.EMOJI_PREFAB_LUT[self.m_emojiId]
    if self.m_emojiPrefabObject and self.m_emojiPrefabObject.name ~= prefabName then
        self:_DestroyEmojiPrefab()
    end
    if string.isEmpty(prefabName) then
        return
    end

    if not self.m_emojiPrefabObject then
        local path = string.format(UIConst.UI_MULTIPLAYER_WIDGETS_PREFAB_PATH, "Emoji/" .. prefabName)
        local prefab, handle = self.loader:LoadGameObject(path)
        self.m_emojiPrefabHandle = handle
        if not prefab then
            self:_DestroyEmojiPrefab()
            logger.error("[MultiplayerEmojiCell] 加载表情 prefab 失败", self.m_emojiId, path)
            return
        end
        
        self.m_emojiPrefabObject = CSUtils.CreateObject(prefab, self.view.emojiPrefabRoot)
        self.m_emojiPrefabObject.name = prefabName
        self.m_emojiPrefabObject:SetActive(false)
    end

    
    self.view.emojiImg.enabled = false
    self.m_emojiPrefabObject:SetActive(true)
end

MultiplayerEmojiCell._HideEmojiPrefab = HL.Method() << function(self)
    if self.m_emojiPrefabObject then
        self.m_emojiPrefabObject:SetActive(false)
    end
    self.view.emojiImg.enabled = true
end

MultiplayerEmojiCell._DestroyEmojiPrefab = HL.Method() << function(self)
    if self.m_emojiPrefabObject then
        self.m_emojiPrefabObject:SetActive(false)
        GameObject.Destroy(self.m_emojiPrefabObject)
        self.m_emojiPrefabObject = nil
    end
    if self.m_emojiPrefabHandle >= 0 then
        self.loader:DisposeHandleByKey(self.m_emojiPrefabHandle)
        self.m_emojiPrefabHandle = -1
    end
end

MultiplayerEmojiCell._TryPlayVoice = HL.Method(HL.Opt(HL.String)) << function(self, charId)
    if string.isEmpty(charId) then
        return
    end

    local interjectionIds = Tables.multiplayerEmojiInfoTable[self.m_emojiId].interjectionIds
    if interjectionIds.Count == 0 then
        return
    end

    
    local wwiseId = string.match(charId, "^chr_%d+_(.+)$")
    if string.isEmpty(wwiseId) then
        return
    end
    local interjectionId = interjectionIds[math.random(0, interjectionIds.Count - 1)]
    local voiceId = string.format("au_dlg_commvo_%s_%s", wwiseId, interjectionId)
    local found = VoiceUtils.TryGetVoiceDuration(voiceId)
    if not found then
        return
    end
    self.m_voiceHandleId = VoiceManager:SpeakNarrative(voiceId, CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig.DEFAULT_CONFIG)
end

MultiplayerEmojiCell._StopVoice = HL.Method() << function(self)
    if self.m_voiceHandleId > 0 then
        VoiceManager:StopVoice(self.m_voiceHandleId)
        self.m_voiceHandleId = -1
    end
end

MultiplayerEmojiCell._OnDestroy = HL.Override() << function(self)
    self:_StopVoice()
    self:_DestroyEmojiPrefab()
end

MultiplayerEmojiCell._ClearHideTimer = HL.Method() << function(self)
    if self.m_hideTimerId >= 0 then
        self.m_hideTimerId = self:_ClearTimer(self.m_hideTimerId)
    end
end

MultiplayerEmojiCell._OnDisable = HL.Override() << function(self)
    self:_StopVoice()
    
    if self.m_isPlaying then
        self:Clear()
    end
end

HL.Commit(MultiplayerEmojiCell)
return MultiplayerEmojiCell
