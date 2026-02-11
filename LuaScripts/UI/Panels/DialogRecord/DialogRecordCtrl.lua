
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DialogRecord























DialogRecordCtrl = HL.Class('DialogRecordCtrl', uiCtrl.UICtrl)








DialogRecordCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


DialogRecordCtrl.m_getCell = HL.Field(HL.Function)


DialogRecordCtrl.m_voiceHandleId = HL.Field(HL.Number) << -1


DialogRecordCtrl.m_timer = HL.Field(HL.Number) << -1


DialogRecordCtrl.m_cellSizes = HL.Field(HL.Table)


DialogRecordCtrl.m_curPlayingIndex = HL.Field(HL.Number) << -1


DialogRecordCtrl.m_focusInfo = HL.Field(HL.Table)


DialogRecordCtrl.m_playVoiceBindingId = HL.Field(HL.Number) << -1





DialogRecordCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_cellSizes = {}
    self.m_focusInfo = {}
    self.view.btnClose.onClick:AddListener(function()
        self:PlayAnimationOutWithCallback(function()
            self:Notify(MessageConst.HIDE_DIALOG_RECORD)
        end)
    end)

    self.view.backTopButton.onClick:AddListener(function()
        self.view.scrollList:ScrollToIndex(CSIndex(1))
    end)

    self.view.backBottomButton.onClick:AddListener(function()
        self.view.scrollList:ScrollToIndex(CSIndex(self.view.scrollList.count))
    end)

    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)

    
    self.view.scrollList.getCellSize = function(csIndex)
        local luaIndex = LuaIndex(csIndex)
        return self.m_cellSizes[luaIndex]
    end

    if DeviceInfo.usingController then
        self.m_playVoiceBindingId = self:BindInputPlayerAction("dialog_play_log_voice", function()
            self:_ToggleVoicePlay(self.m_focusInfo)
        end)

        InputManagerInst:ToggleBinding(self.m_playVoiceBindingId, false)
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



DialogRecordCtrl._UpdateCellSize = HL.Method() << function(self)
    self.m_cellSizes = {}
    local cell = self.view.cell
    local records = GameWorld.dialogManager.records
    for index = 1, records.Count do
        cell.gameObject:SetActive(true)
        self:_RefreshCell(cell, index)
        table.insert(self.m_cellSizes, cell.transform.rect.height)
    end
    cell.gameObject:SetActive(false)
end







DialogRecordCtrl._RefreshCell = HL.Method(HL.Table, HL.Number, HL.Opt(HL.Boolean)) << function(self, cell, index,
                                                                                               exceptAudio)
    local records = GameWorld.dialogManager.records
    local textId = records[CSIndex(index)]
    local voiceId = DialogUtils.GetTrunkVoiceId(textId)
    local res, duration = VoiceUtils.TryGetVoiceDuration(voiceId)
    local isPlaying = index == self.m_curPlayingIndex
    if not res then
        voiceId = ""
    end

    local hasVoice = not exceptAudio and not string.isEmpty(voiceId)
    local isTrunk, trunkTbData = Tables.dialogTextTable:TryGetValue(textId)
    local isOption, optionTbData = Tables.dialogOptionTable:TryGetValue(textId)
    local trunkNode = cell.trunkNode
    local optionNode = cell.optionNode
    local line = cell.line
    cell.hasVoice = hasVoice

    trunkNode.gameObject:SetActive(isTrunk)
    optionNode.gameObject:SetActive(isOption)
    line.gameObject:SetActive(index > 1 and index == self.view.scrollList.count)
    if isTrunk then
        local actorName = UIUtils.removePattern(trunkTbData.actorName, UIConst.NARRATIVE_ANONYMITY_PATTERN)
        trunkNode.characterNameText:SetAndResolveTextStyle(UIUtils.resolveTextCinematic(actorName))
        trunkNode.text:SetAndResolveTextStyle(UIUtils.resolveTextCinematic(trunkTbData.dialogText))

        trunkNode.playingAudioButton.gameObject:SetActive(false)
        trunkNode.audioButton.gameObject:SetActive(hasVoice)
        trunkNode.audioButtonEx.gameObject:SetActive(hasVoice)

        self:_SetCellIsPlaying(cell, isPlaying)

        trunkNode.audioButton.onClick:RemoveAllListeners()
        trunkNode.audioButtonEx.onClick:RemoveAllListeners()
        trunkNode.playingAudioButton.onClick:RemoveAllListeners()
        if hasVoice then
            trunkNode.audioButton.onClick:AddListener(function()
                self:_RefreshPlayingCell(index)
                self:_TryPlayAudio(voiceId, duration)
            end)

            trunkNode.playingAudioButton.onClick:AddListener(function()
                if self.m_curPlayingIndex == index  then
                    self:_RefreshPlayingCell(-1)
                    self:_StopAudio()
                end
            end)

            trunkNode.audioButtonEx.onClick:AddListener(function() self:_ToggleVoicePlay({index, voiceId, duration}) end)

            trunkNode.trunkButton.onIsNaviTargetChanged = function(isNaviTarget)
                if isNaviTarget and DeviceInfo.usingController then
                    self.m_focusInfo = { index, voiceId, duration }
                    InputManagerInst:ToggleBinding(self.m_playVoiceBindingId, true)
                end
            end
        else
            trunkNode.trunkButton.onIsNaviTargetChanged = function(isNaviTarget)
                if isNaviTarget and DeviceInfo.usingController then
                    self.m_focusInfo = {}
                    InputManagerInst:ToggleBinding(self.m_playVoiceBindingId, false)
                end
            end
        end

        LayoutRebuilder.ForceRebuildLayoutImmediate(trunkNode.characterDialogNode.transform)
        LayoutRebuilder.ForceRebuildLayoutImmediate(trunkNode.transform)
    elseif isOption then
        optionNode.optionButton.onIsNaviTargetChanged = function(isNaviTarget)
            if isNaviTarget and DeviceInfo.usingController then
                self.m_focusInfo = {}
                InputManagerInst:ToggleBinding(self.m_playVoiceBindingId, false)
            end
        end

        optionNode.text:SetAndResolveTextStyle(UIUtils.resolveTextCinematic(optionTbData.optionText))
        LayoutRebuilder.ForceRebuildLayoutImmediate(optionNode.optionNode.transform)
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(cell.transform)
end




DialogRecordCtrl._ToggleVoicePlay = HL.Method(HL.Table) << function(self, info)
    if next(info) == nil then
        return
    end

    local index, voiceId, duration = unpack(info)
    if self.m_curPlayingIndex == index then
        self:_RefreshPlayingCell(-1)
        self:_StopAudio()
    else
        self:_RefreshPlayingCell(index)
        self:_TryPlayAudio(voiceId, duration)
    end
end





DialogRecordCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, object, index)
    local cell = self.m_getCell(object)
    self:_RefreshCell(cell, index)
end




DialogRecordCtrl._GetCellByIndex = HL.Method(HL.Number).Return(HL.Any) << function(self, luaIndex)
    local cell
    if luaIndex > 0 then
        local object = self.view.scrollList:Get(CSIndex(luaIndex))
        if object then
            cell = self.m_getCell(object)
        end
    end
    return cell
end





DialogRecordCtrl._SetCellIsPlaying = HL.Method(HL.Any, HL.Boolean) << function(self, cell, isPlaying)
    if not cell then
        return
    end
    local trunkNode = cell.trunkNode
    local hasVoice = cell.hasVoice
    if hasVoice then
        trunkNode.audioButton.gameObject:SetActive(not isPlaying)
        trunkNode.playingAudioButton.gameObject:SetActive(isPlaying)
        trunkNode.playingAudioBG.gameObject:SetActive(isPlaying)
        if isPlaying then
            trunkNode.text.color = self.view.config.TRUNK_TEXT_PLAYING_COLOR
        else
            trunkNode.text.color = self.view.config.TRUNK_TEXT_DEFAULT_COLOR
        end
    else
        trunkNode.audioButton.gameObject:SetActive(false)
    end
end




DialogRecordCtrl._RefreshPlayingCell = HL.Method(HL.Number) << function(self, newIndex)
    if self.m_curPlayingIndex == newIndex then
        return
    end

    local oldCell = self:_GetCellByIndex(self.m_curPlayingIndex)
    self:_SetCellIsPlaying(oldCell, false)
    local newCell = self:_GetCellByIndex(newIndex)
    self:_SetCellIsPlaying(newCell, true)

    self.m_curPlayingIndex = newIndex
end





DialogRecordCtrl._TryPlayAudio = HL.Method(HL.String, HL.Number) << function(self, voiceId, duration)
    GameWorld.dialogManager:TryStopCurVoice()
    self:_StopAudio()
    self.m_voiceHandleId = VoiceManager:SpeakNarrative(voiceId, nil, CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig.DEFAULT_CONFIG)
    self.m_timer = self:_StartTimer(duration, function()
        self:_RefreshPlayingCell(-1)
        self:_StopAudio()
    end)
end



DialogRecordCtrl._StopAudio = HL.Method() << function(self)
    if self.m_voiceHandleId > 0 then
        VoiceManager:StopVoice(self.m_voiceHandleId)
    end
    self.m_voiceHandleId = -1

    if self.m_timer > 0 then
        self:_ClearTimer(self.m_timer)
    end
    self.m_timer = -1
end




DialogRecordCtrl.OnShow = HL.Override() << function(self)
    local count = GameWorld.dialogManager.records.Count
    self:_UpdateCellSize()
    self.view.scrollList:UpdateCount(count)
    self.view.scrollList:ScrollToIndex(CSIndex(self.view.scrollList.count), true)
    self.view.scrollListNaviGroup:ManuallyFocus()
end




DialogRecordCtrl.OnClose = HL.Override() << function(self)
    self:_StopAudio()
    self.view.scrollListNaviGroup:ManuallyStopFocus()
end



DialogRecordCtrl._Update = HL.Method() << function(self)
    local firstCellShowing = self.view.scrollList:IsCellShowing(CSIndex(1))
    local lastCellShowing = self.view.scrollList:IsCellShowing(CSIndex(self.view.scrollList.count))
    self.view.backTopButton.gameObject:SetActive(not firstCellShowing)
    self.view.backBottomButton.gameObject:SetActive(not lastCellShowing)
end



DialogRecordCtrl.OnHide = HL.Override() << function(self)
    self:_RefreshPlayingCell(-1)
    self:_StopAudio()
end


HL.Commit(DialogRecordCtrl)
