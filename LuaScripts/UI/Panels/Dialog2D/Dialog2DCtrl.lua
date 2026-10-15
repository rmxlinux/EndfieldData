
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local Canvas = CS.UnityEngine.Canvas
local PANEL_ID = PanelId.Dialog2D
local PHASE_ID = PhaseId.Dialog2D
local OLD_CONTENT_KEEP_VISIBLE_LINE_COUNT = 2.5
local SELECTED_OPTION_RICH_ID = "2ddlg.option"
Dialog2DCtrl = HL.Class('Dialog2DCtrl', uiCtrl.UICtrl)

Dialog2DCtrl.m_trunkNodeData = HL.Field(CS.Beyond.Gameplay.DTTrunkNodeData)

Dialog2DCtrl.m_trunkOptionData = HL.Field(HL.Userdata)

Dialog2DCtrl.m_getOptionCell = HL.Field(HL.Function)

Dialog2DCtrl.m_optionAnimToken = HL.Field(HL.Number) << 0

Dialog2DCtrl.m_oldContentText = HL.Field(HL.String) << ""

Dialog2DCtrl.m_newContentText = HL.Field(HL.String) << ""

Dialog2DCtrl.m_pendingSelectedOptionText = HL.Field(HL.String) << ""



Dialog2DCtrl.m_canSkip = HL.Field(HL.Boolean) << true



Dialog2DCtrl.m_optionCount = HL.Field(HL.Number) << 0










Dialog2DCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_PLAY_DIALOG_TRUNK] = 'OnPlayDialogTrunk',
    [MessageConst.ON_SHOW_DIALOG_OPTION] = 'OnShowDialogOption',
    [MessageConst.ON_PLAY_DIALOG_2D_CONTENT] = 'OnPlayDialog2DContent',
    [MessageConst.SWITCH_DIALOG_CAN_SKIP] = 'OnSwitchDialogCanSkip',
}

Dialog2DCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.m_oldContentText = ''
    self.m_newContentText = ''
    self.m_pendingSelectedOptionText = ''

    self.m_getOptionCell = UIUtils.genCachedCellFunction(self.view.optionScrollList)
    self.view.optionScrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateOptionCell(object, LuaIndex(csIndex))
    end)

    
    self.view.skipBtn.onClick:RemoveAllListeners()
    self.view.skipBtn.onClick:AddListener(function()
        self:OnBtnSkipClick()
    end)

    self.view.leftDetailNode.gameObject:SetActive(false)

    self:_RefreshCanSkip()
end



Dialog2DCtrl.OnPlayDialogTrunk = HL.Method(HL.Table) << function(self, data)
    local trunkNodeData, fastMode, npcId, npcGroupId = unpack(data)
    self:SetTrunk(trunkNodeData)
end

Dialog2DCtrl.OnShowDialogOption = HL.Method(HL.Table) << function(self, data)
    local options = unpack(data)
    self:SetTrunkOption(options)
end

Dialog2DCtrl.OnPlayDialog2DContent = HL.Method(HL.Table) << function(self, data)
    local trunkId = unpack(data)
    self:Set2DContentText(trunkId)
end



Dialog2DCtrl.OnClose = HL.Override() << function(self)
    self.view.skipBtn.onClick:RemoveAllListeners()
    Dialog2DCtrl.Super.OnClose(self)
end

Dialog2DCtrl.SetTrunk = HL.Method(HL.Userdata) << function(self, trunkNodeData)
    self.m_trunkNodeData = trunkNodeData
    local trunkId = trunkNodeData.overrideTrunkId
    if string.isEmpty(trunkId) then
        trunkId = trunkNodeData.trunkId
    end

    local res, trunkTbData = Tables.dialogTextTable:TryGetValue(trunkId)
    if not res then
        return
    end

    self.view.leftDetailNode.gameObject:SetActive(true)

    local name = trunkTbData.actorName
    local nameTitle = trunkTbData.hint
    local dialogText = trunkTbData.dialogText

    local richNameTitle = UIUtils.resolveTextCinematic(nameTitle)
    richNameTitle = UIUtils.removePattern(richNameTitle, UIConst.NARRATIVE_ANONYMITY_PATTERN)
    self.view.nameTitleTxt:SetAndResolveTextStyle(richNameTitle)

    local richName = UIUtils.resolveTextCinematic(name)
    local isNameFullyWrappedByBraces = string.match(richName, "^%b{}$") ~= nil
    if isNameFullyWrappedByBraces then
        richName = ""
    else
        richName = UIUtils.removePattern(richName, UIConst.NARRATIVE_ANONYMITY_PATTERN)
    end
    self.view.nameTxt:SetAndResolveTextStyle(richName)

    local text = UIUtils.resolveNarrativeTextWithEntryLinks(dialogText)
    self.view.dialogTxt:SetText(text)
    self.view.dialogTxt:Play()

    self:_RefreshCanSkip()
end

Dialog2DCtrl.SetTrunkOption = HL.Method(HL.Userdata) << function(self, optionData)
    self.m_trunkOptionData = optionData
    self.m_optionAnimToken = self.m_optionAnimToken + 1
    local token = self.m_optionAnimToken
    local count = optionData.Count
    self.m_optionCount = count
    if count > 0 then
        self.view.optionScrollList.gameObject:SetActive(true)
        self.view.optionScrollList:UpdateCount(count)
        if self:IsShow() then
            self:_EnableDialogControllerOption()
        end
    else
        self:_DisableDialogControllerOption()
        self:_PlayAllOptionOut(token)
    end
end

Dialog2DCtrl._PlayAllOptionOut = HL.Method(HL.Number) << function(self, token)
    local scrollList = self.view.optionScrollList
    local animationWrappers = {}
    for i = 1, scrollList.count do
        local object = scrollList:Get(CSIndex(i))
        if object then
            local cell = self.m_getOptionCell(object)
            local animationWrapper = cell and cell.view and cell.view.animationWrapper or nil
            if animationWrapper then
                table.insert(animationWrappers, animationWrapper)
            end
        end
    end

    local remaining = #animationWrappers
    if remaining <= 0 then
        if token == self.m_optionAnimToken then
            scrollList:UpdateCount(0)
        end
        return
    end

    local onOutDone = function()
        remaining = remaining - 1
        if remaining == 0 and token == self.m_optionAnimToken then
            scrollList:UpdateCount(0)
        end
    end

    for _, animationWrapper in ipairs(animationWrappers) do
        animationWrapper:PlayOutAnimation(onOutDone)
    end
end

Dialog2DCtrl._OnUpdateOptionCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, luaIndex)
    local optionData = self.m_trunkOptionData
    if not optionData or luaIndex <= 0 or luaIndex > optionData.Count then
        return
    end

    local cell = self.m_getOptionCell(object)
    if not cell then
        return
    end

    local option = optionData[CSIndex(luaIndex)]
    local data = {
        optionId = option.optionId,
        index = luaIndex,
        text = option.optionText or "",
        iconType = option.iconType,
        icon = option.optionIcon,
        color = option.useExOptionColor and option.optionIconColor or nil,
        setGreyed = option.setGreyed,
    }
    cell:InitDialogOptionCell(data, function() self:OnOptionClick(luaIndex, option) end)
    cell.view.animationWrapper:PlayInAnimation()
end

Dialog2DCtrl.OnOptionClick = HL.Method(HL.Number, HL.Any) << function(self, index, data)
    self.m_pendingSelectedOptionText = data and data.optionText or ""
    GameWorld.dialogManager:SelectIndex(CSIndex(index))
end

Dialog2DCtrl._AppendNewContentToOldContent = HL.Method() << function(self)
    if string.isEmpty(self.m_newContentText) then
        return
    end

    if string.isEmpty(self.m_oldContentText) or string.endWith(self.m_oldContentText, "\n") then
        self.m_oldContentText = self.m_oldContentText .. self.m_newContentText
    else
        self.m_oldContentText = self.m_oldContentText .. "\n" .. self.m_newContentText
    end
end

Dialog2DCtrl._GetSelectedOptionLine = HL.Method().Return(HL.String) << function(self)
    local optionText = self.m_pendingSelectedOptionText
    if string.isEmpty(optionText) then
        return ""
    end

    return "<@" .. SELECTED_OPTION_RICH_ID .. ">" .. Language.LUA_DIALOG_2D_SELECTED_OPTION_PREFIX .. optionText .. "</>"
end

Dialog2DCtrl._BuildNewContentText = HL.Method(HL.String).Return(HL.String) << function(self, dialog2dText)
    local selectedOptionLine = self:_GetSelectedOptionLine()
    self.m_pendingSelectedOptionText = ""
    if string.isEmpty(selectedOptionLine) then
        return dialog2dText
    end

    if string.isEmpty(dialog2dText) then
        return selectedOptionLine
    end

    return selectedOptionLine .. "\n" .. dialog2dText
end

Dialog2DCtrl.Set2DContentText = HL.Method(HL.String) << function(self, trunkId)
    
    local res, dialog2dTextData = Tables.dialog2DTextTable:TryGetValue(trunkId)
    if not res then
        return
    end

    local dialog2dTextTitle = dialog2dTextData.dialog2dTitle
    if not string.isEmpty(dialog2dTextTitle) then
        self.view.contentTitleTxt.text = dialog2dTextTitle
    end

    local dialog2dText = dialog2dTextData.dialog2dText

    self:_AppendNewContentToOldContent()

    self.view.oldContentTxt.gameObject:SetActive(not string.isEmpty(self.m_oldContentText))
    local oldContentText = UIUtils.resolveNarrativeTextWithEntryLinks(self.m_oldContentText)
    self.view.oldContentTxt:SetAndResolveTextStyle(oldContentText)

    self.m_newContentText = dialog2dText
    local newContentText = UIUtils.resolveNarrativeTextWithEntryLinks(self:_BuildNewContentText(self.m_newContentText))
    self.view.newContentTxt:SetAndResolveTextStyle(newContentText)

    self.view.newContentAnim:PlayInAnimation()
    self.view.lineAnim:PlayInAnimation()

    self:_AutoScrollContent()
    self:_RefreshCanSkip()
end

Dialog2DCtrl._AutoScrollContent = HL.Method() << function(self)
    self:_TryAutoScrollContent()
end

Dialog2DCtrl._RefreshContentTextLayout = HL.Method() << function(self)
    local scrollView = self.view.contentScrollRect
    if scrollView == nil or scrollView.content == nil then
        return
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(scrollView.content)
    Canvas.ForceUpdateCanvases()
    self.view.oldContentTxt:ForceMeshUpdate()
    self.view.newContentTxt:ForceMeshUpdate()
    scrollView:ClampContentToBounds()
end

Dialog2DCtrl._TryAutoScrollContent = HL.Method() << function(self)
    local scrollView = self.view.contentScrollRect
    if scrollView == nil or scrollView.content == nil or scrollView.viewport == nil or not scrollView.vertical then
        return
    end

    self:_RefreshContentTextLayout()

    local oldText = self.view.oldContentTxt
    local textInfo = oldText.textInfo
    if textInfo == nil or textInfo.lineCount <= 0 then
        return
    end

    local contentRect = scrollView.content
    local viewportRect = scrollView.viewport
    local contentHeight = contentRect.rect.height
    local viewportHeight = viewportRect.rect.height
    if contentHeight <= viewportHeight then
        return
    end

    local lastLineInfo = textInfo.lineInfo[textInfo.lineCount - 1]
    local oldTextRect = oldText.rectTransform
    local lineTopWorldPos = oldTextRect:TransformPoint(Vector3(0, lastLineInfo.ascender, 0))
    local lineBottomWorldPos = oldTextRect:TransformPoint(Vector3(0, lastLineInfo.descender, 0))
    local lineTopInContentY = contentRect:InverseTransformPoint(lineTopWorldPos).y
    local oldTextBottomInContentY = contentRect:InverseTransformPoint(lineBottomWorldPos).y
    local lineHeight = lineTopInContentY - oldTextBottomInContentY
    if lineHeight <= 0 then
        return
    end

    local targetTopInContentY = oldTextBottomInContentY + lineHeight * OLD_CONTENT_KEEP_VISIBLE_LINE_COUNT

    local contentTopLocalY = contentHeight * (1 - contentRect.pivot.y)
    local targetPosY = contentTopLocalY - targetTopInContentY
    local maxScrollY = contentHeight - viewportHeight
    targetPosY = math.max(0, math.min(targetPosY, maxScrollY))

    scrollView:ScrollTo(Vector2(contentRect.anchoredPosition.x, targetPosY), false)
end








Dialog2DCtrl._EnableDialogControllerOption = HL.Method() << function(self)
    if not DeviceInfo.usingController or self.m_optionCount <= 0 then
        return
    end
    self.view.optionNaviGroup:ManuallyFocus()
end


Dialog2DCtrl._DisableDialogControllerOption = HL.Method() << function(self)
    if not DeviceInfo.usingController or self.m_optionCount > 0 then
        return
    end
    self.view.optionNaviGroup:ManuallyStopFocus()
end


Dialog2DCtrl.OnShow = HL.Override() << function(self)
    if self.m_optionCount > 0 then
        self:_EnableDialogControllerOption()
    end
end






Dialog2DCtrl.OnSwitchDialogCanSkip = HL.Method(HL.Table) << function(self, arg)
    self:_RefreshCanSkip()
end


Dialog2DCtrl._RefreshCanSkip = HL.Method() << function(self)
    self.m_canSkip = GameWorld.dialogManager.canSkip
    self.view.skipBtn.gameObject:SetActive(self.m_canSkip)
end


Dialog2DCtrl.OnBtnSkipClick = HL.Method() << function(self)
    self:Notify(MessageConst.OPEN_DIALOG_SKIP_POP_UP)
end



HL.Commit(Dialog2DCtrl)
