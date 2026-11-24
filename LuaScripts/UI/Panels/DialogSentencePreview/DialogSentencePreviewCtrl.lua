local dialogCtrl = require_ex('UI/Panels/Dialog/DialogCtrl')
local PANEL_ID = PanelId.DialogSentencePreview
local VoiceI18n = CS.Beyond.Gameplay.Audio.VoiceI18n
local NarrativeVoiceConfig = CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig


DialogSentencePreviewCtrl = HL.Class('DialogSentencePreviewCtrl', dialogCtrl.DialogCtrl)

DialogSentencePreviewCtrl.m_sentence = HL.Field(HL.Table)
DialogSentencePreviewCtrl.m_voiceHandle = HL.Field(HL.Number) << 0
DialogSentencePreviewCtrl.m_clearScreenKey = HL.Field(HL.Number) << -1

DialogSentencePreviewCtrl.Play = HL.StaticMethod(HL.String).Return(HL.Boolean) << function(sentenceId)
    if not BEYOND_DEBUG_COMMAND then
        return false
    end
    if string.isEmpty(sentenceId) then
        Notify(MessageConst.SHOW_TOAST, "用法：PlayDialogSentence <台词 key>")
        return false
    end

    local dialogManager = GameWorld.dialogManager
    if dialogManager == nil or GameInstance.player == nil then
        Notify(MessageConst.SHOW_TOAST, "请进入游戏后再校对单句对话")
        return false
    end
    if dialogManager.isPlaying or dialogManager.isPreparing
        or GameWorld.narrativeManager.inNarrative
        or GameWorld.cutsceneManager.isMainTimelinePlaying
        or GameWorld.dialogTimelineManager.isMainTimelinePlaying
        or PhaseManager:IsOpen(PhaseId.Dialog) then
        Notify(MessageConst.SHOW_TOAST, "正式演出进行中，暂不能校对单句对话")
        return false
    end

    local found, data = Tables.dialogTextTable:TryGetValue(sentenceId)
    if not found then
        Notify(MessageConst.SHOW_TOAST, "找不到台词 key：" .. sentenceId)
        return false
    end

    if UIManager:IsOpen(PanelId.Dialog) then
        Notify(MessageConst.SHOW_TOAST, "对话界面正在使用中，暂不能校对单句对话")
        return false
    end

    local sentence = {
        id = sentenceId,
        text = UIUtils.resolveNarrativeTextWithEntryLinks(data.dialogText),
        speakerName = UIUtils.resolveTextCinematic(data.actorName),
        voiceId = data.audioOverride,
    }
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl:SetSentence(sentence)
    else
        UIManager:Open(PANEL_ID, sentence)
    end
    return true
end

DialogSentencePreviewCtrl.OnCreated = HL.Override(HL.Any) << function(self, sentence)
    self.m_isUIHidden = false
    self:SetGlossaryPopUpEnable(false)
    self.view.buttonSkip.onClick:RemoveAllListeners()
    self.view.buttonAuto.onClick:RemoveAllListeners()
    self.view.buttonHide.onClick:RemoveAllListeners()
    self.view.buttonLog.onClick:RemoveAllListeners()
    
    for _, dialogText in ipairs({ self.view.textTalk, self.view.textTalkCenter }) do
        dialogText.uiText.onClickLink:RemoveAllListeners()
        dialogText.uiText.onClickLink:AddListener(function()
            self:Close()
        end)
    end
    self:BindInputPlayerAction("dialog_skip", function()
        self:Close()
    end)

    self.m_clearScreenKey = UIManager:ClearScreen({ PANEL_ID })
    self:SetSentence(sentence)
end

DialogSentencePreviewCtrl.SetSentence = HL.Method(HL.Table) << function(self, sentence)
    self:_StopVoice()
    self.m_sentence = sentence
    self:RefreshText()
    self:_PlayVoice()
end

DialogSentencePreviewCtrl.RefreshText = HL.Method() << function(self)
    local view = self.view
    local sentence = self.m_sentence
    local name = sentence.speakerName
    local singleTrunk = string.isEmpty(name) or string.match(name, "^%b{}$") ~= nil

    self:SetCtrlButtonVisible(false)
    view.optionList.gameObject:SetActive(false)
    view.radioNode.gameObject:SetActive(false)
    view.topTrunkNode.gameObject:SetActive(false)
    view.bgBlack.gameObject:SetActive(false)
    view.bgSprite.gameObject:SetActive(false)
    view.noteKeyHintNode.gameObject:SetActive(false)
    view.bottomMask.gameObject:SetActive(true)
    view.imageBG.gameObject:SetActive(true)
    view.bottomLayout.gameObject:SetActive(not singleTrunk)
    view.textTalkCenterNode.gameObject:SetActive(singleTrunk)
    view.bottomLayout.alpha = 1
    view.textTalkCenterNode.alpha = 1
    view.waitNode.gameObject:SetActive(not singleTrunk)
    view.centerWaitNode.gameObject:SetActive(singleTrunk)

    if singleTrunk then
        view.textTalkCenter:SetText(sentence.text)
        view.textTalkCenter:SeekToEnd()
    else
        name = UIUtils.removePattern(name, UIConst.NARRATIVE_ANONYMITY_PATTERN)
        view.textName:SetAndResolveTextStyle(name)
        view.textName.gameObject:SetActive(true)
        view.textTalk:SetText(sentence.text)
        view.textTalk:SeekToEnd()
    end
end

DialogSentencePreviewCtrl._PlayVoice = HL.Method() << function(self)
    local voiceId = self.m_sentence.voiceId
    if string.isEmpty(voiceId) then
        self:_NotifyMissingVoice()
        return
    end
    local found, voiceData = VoiceUtils.TryGetVoiceData(voiceId)
    if not found then
        self:_NotifyMissingVoice()
        return
    end
    
    local hasCustomLanguage = VoiceI18n.TryGetSpeakerCustomLang(voiceData.speakerChannel)
    if not hasCustomLanguage and not VoiceUtils.TryGetVoiceDuration(voiceId) then
        self:_NotifyMissingVoice()
        return
    end

    self.m_voiceHandle = VoiceManager:SpeakNarrative(voiceId, nil, NarrativeVoiceConfig.DEFAULT_CONFIG)
    if self.m_voiceHandle == 0 then
        self:_NotifyMissingVoice()
    end
end

DialogSentencePreviewCtrl._NotifyMissingVoice = HL.Method() << function(self)
    Notify(MessageConst.SHOW_TOAST, "当前配音缺失或无法播放，保留文本供校对：" .. self.m_sentence.id)
end

DialogSentencePreviewCtrl._StopVoice = HL.Method() << function(self)
    if self.m_voiceHandle ~= 0 then
        VoiceManager:StopVoice(self.m_voiceHandle)
        self.m_voiceHandle = 0
    end
end

DialogSentencePreviewCtrl.OnClose = HL.Override() << function(self)
    self:_StopVoice()
    if self.m_clearScreenKey > 0 then
        self.m_clearScreenKey = UIManager:RecoverScreen(self.m_clearScreenKey)
    end
    self.m_sentence = nil
    DialogSentencePreviewCtrl.Super.OnClose(self)
end

DialogSentencePreviewCtrl.OnShow = HL.Override() << function(self)
    self:RefreshText()
    self.view.debugNode.gameObject:SetActive(false)
end

DialogSentencePreviewCtrl.OnBtnNextClick = HL.Override() << function(self)
    self:Close()
end

DialogSentencePreviewCtrl._OnFormalDialogStart = HL.Method(HL.Opt(HL.Any)) << function(self, _)
    self:Close()
end

HL.Commit(DialogSentencePreviewCtrl)


DialogSentencePreviewCtrl.s_overrideMessages = {
    [MessageConst.ON_TOGGLE_HUD_FADE] = '_OnToggleHudFade',
    [MessageConst.ON_PREPARE_NARRATIVE] = '_OnFormalDialogStart',
    [MessageConst.ON_DIALOG_START] = '_OnFormalDialogStart',
}
