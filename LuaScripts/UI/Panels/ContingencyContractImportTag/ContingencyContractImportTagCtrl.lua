local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ContingencyContractImportTag

ContingencyContractImportTagCtrl = HL.Class('ContingencyContractImportTagCtrl', uiCtrl.UICtrl)







ContingencyContractImportTagCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CONTINGENCY_CONTRACT_SET_TAG] = '_OnSetTagSuccess',
}


ContingencyContractImportTagCtrl.m_gameId = HL.Field(HL.String) << ""
ContingencyContractImportTagCtrl.m_title = HL.Field(HL.String) << ""
ContingencyContractImportTagCtrl.m_tagIds = HL.Field(HL.Table)
ContingencyContractImportTagCtrl.m_tagGroupIds = HL.Field(HL.Table)
ContingencyContractImportTagCtrl.m_tagInfos = HL.Field(HL.Table)
ContingencyContractImportTagCtrl.m_importResult = HL.Field(HL.Table)
ContingencyContractImportTagCtrl.m_warningScore1 = HL.Field(HL.Number) << 0
ContingencyContractImportTagCtrl.m_warningScore2 = HL.Field(HL.Number) << 0
ContingencyContractImportTagCtrl.m_smallTagCellCache = HL.Field(HL.Forward("UIListCache"))
ContingencyContractImportTagCtrl.m_tagEffectCellCache = HL.Field(HL.Forward("UIListCache"))
ContingencyContractImportTagCtrl.m_pendingGoto = HL.Field(HL.Boolean) << false
ContingencyContractImportTagCtrl.m_pendingFinalScore = HL.Field(HL.Number) << 0




ContingencyContractImportTagCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local recoverState = arg and arg.recoverState or nil
    self:_InitUI()
    self:_InitData(arg)
    self:_UpdateData()
    self:_RefreshAllUI()
    
    self:TryRecoverPopupState(recoverState and recoverState.popupState)
    if arg then
        arg.recoverState = nil
    end
    self:_SetDefaultNavi()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end











ContingencyContractImportTagCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_gameId = arg and arg.gameId or ""
    self.m_title = arg and arg.title or ""
    self.m_tagIds = arg and arg.tagIds or {}
    self.m_tagGroupIds = arg and arg.tagGroupIds or {}
    self.m_warningScore1, self.m_warningScore2 = ContingencyContractUtils.GetImportWarningScores(self.m_gameId)
end

ContingencyContractImportTagCtrl._UpdateData = HL.Method() << function(self)
    self.m_tagInfos = ContingencyContractUtils.CreateTagBasicInfoWithKeyLockJoinedInfosFilterGroup(
        self.m_gameId, self.m_tagIds, self.m_tagGroupIds)
    
    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(self.m_gameId)
    if ccData then
        for _, tagInfo in pairs(self.m_tagInfos) do
            tagInfo.hasFirstPassReward = not ccData.receivedRewardTagSet:Contains(tagInfo.tagId)
        end
    end
    self.m_importResult = ContingencyContractUtils.BuildImportTagResult(self.m_gameId, self.m_tagInfos)
end



ContingencyContractImportTagCtrl._InitUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.fullScreenCloseBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.view.importBtn.onClick:AddListener(function()
        self:_OnClickImport(false)
    end)
    self.view.importGotoBtn.onClick:AddListener(function()
        self:_OnClickImport(true)
    end)

    self.m_smallTagCellCache = UIUtils.genCellCache(self.view.smallTagCell)
    self.m_tagEffectCellCache = UIUtils.genCellCache(self.view.tagEffectCell)
end

ContingencyContractImportTagCtrl._RefreshAllUI = HL.Method() << function(self)
    self.view.titleTxt.text = self.m_title
    local tagCount = #self.m_tagInfos
    self.m_smallTagCellCache:Refresh(tagCount, function(cell, luaIndex)
        self:_RefreshSmallTagCell(cell, luaIndex)
    end)
    self.m_tagEffectCellCache:Refresh(tagCount, function(cell, luaIndex)
        self:_RefreshTagEffectCell(cell, luaIndex)
    end)
    self:_RefreshImportBtnState()
end

ContingencyContractImportTagCtrl._RefreshImportBtnState = HL.Method() << function(self)
    if self.m_importResult.allJoined then
        self.view.importBtnState:SetState("DisableState")
        self.view.importBtn.enabled = false
        self.view.importGotoBtnState:SetState("Goto")
        self.view.importGotoBtn.enabled = true
    else
        self.view.importBtnState:SetState("NormalState")
        self.view.importBtn.enabled = true
        self.view.importGotoBtnState:SetState("ImportAndGoto")
        self.view.importGotoBtn.enabled = true
    end
end

ContingencyContractImportTagCtrl._SetDefaultNavi = HL.Method() << function(self)
    local firstCell = self.m_tagEffectCellCache:GetItem(1)
    if firstCell then
        self:SetNaviTarget(firstCell.naviDeco)
    end
end

ContingencyContractImportTagCtrl._OpenGroupTagPopup = HL.Method(HL.Any, HL.Opt(HL.Any)) << function(self, groupId, recoverState)
    UIManager:Open(PanelId.ContingencyContractGroupTag, {
        gameId = self.m_gameId,
        groupId = groupId,
        recoverState = recoverState,
    })
end

ContingencyContractImportTagCtrl.GetRecoverPopupStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local isOpen, groupTagCtrl = UIManager:IsOpen(PanelId.ContingencyContractGroupTag)
    if not isOpen or not groupTagCtrl then
        return
    end
    local popupState = {
        popupType = "GroupTag",
    }
    if HL.TryGet(groupTagCtrl, "GetRecoverStateArg") then
        popupState.recoverState = groupTagCtrl:GetRecoverStateArg()
    end
    return popupState
end

ContingencyContractImportTagCtrl.TryRecoverPopupState = HL.Method(HL.Any) << function(self, popupState)
    if popupState == nil or string.isEmpty(popupState.popupType) then
        return
    end
    if popupState.popupType ~= "GroupTag" then
        return
    end
    local isOpen = UIManager:IsOpen(PanelId.ContingencyContractGroupTag)
    if isOpen then
        return
    end
    local groupRecoverState = popupState.recoverState
    local groupId = groupRecoverState and groupRecoverState.groupId or nil
    if groupId == nil then
        return
    end
    self:_OpenGroupTagPopup(groupId, groupRecoverState)
end

ContingencyContractImportTagCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        gameId = self.m_gameId,
        title = self.m_title,
        tagIds = self.m_tagIds,
        tagGroupIds = self.m_tagGroupIds,
        popupState = self:GetRecoverPopupStateArg(),
    }
end

ContingencyContractImportTagCtrl._GetJoinedStateName = HL.Method(HL.Table).Return(HL.String) << function(self, tagInfo)
    if tagInfo.isJoined then
        return "JoinedState"
    end
    if tagInfo.isConflict then
        return "ConflictState"
    end
    return "NormalState"
end

ContingencyContractImportTagCtrl._ApplyKeyInfoToCell = HL.Method(HL.Any, HL.Table) << function(self, cell, keyInfo)
    cell.keyImg.color = keyInfo.color
    cell.unlockLockColorDeco.color = keyInfo.color
    cell.lockDescTxt.color = keyInfo.color
    cell.lockDescTxt.text = string.format(Language.LUA_CONTINGENCY_CONTRACT_SELECT_UNLOCK_KEY, keyInfo.lockName)
end

ContingencyContractImportTagCtrl._CanViewTagGroup = HL.Method(HL.Any).Return(HL.Boolean) << function(self, tagInfo)
    if not tagInfo.isFromGroup then
        return false
    end
    local groupId = tagInfo.groupId
    if not groupId or groupId == 0 then
        return false
    end
    local hasCfg, ccCfg = Tables.contingencyContractTable:TryGetValue(self.m_gameId)
    if not hasCfg then
        return false
    end
    local hasGroupCfg, groupCfg = ccCfg.contractGroupMap:TryGetValue(groupId)
    if not hasGroupCfg then
        return false
    end
    local tagCount = 0
    for _, _ in pairs(groupCfg.contractMap) do
        tagCount = tagCount + 1
        if tagCount > 1 then
            return true
        end
    end
    return false
end

ContingencyContractImportTagCtrl._RefreshSmallTagCell = HL.Method(HL.Any, HL.Number) << function(self, inCell, luaIndex)
    
    local cell = inCell
    local tagInfo = self.m_tagInfos[luaIndex]
    cell.tagIcon:LoadSprite(UIConst.UI_SPRITE_CONTINGENCY_CONTRACT_BUFF, tagInfo.icon)
    cell.stateController:SetState(self:_GetJoinedStateName(tagInfo))
end

ContingencyContractImportTagCtrl._RefreshTagEffectCell = HL.Method(HL.Any, HL.Number) << function(self, inCell, luaIndex)
    
    local cell = inCell
    local tagInfo = self.m_tagInfos[luaIndex]
    
    cell.levelTxt.text = tagInfo.level
    cell.tagNameTxt.text = tagInfo.tagFullName
    cell.descTxt.text = tagInfo.desc
    cell.stateController:SetState("Level" .. tagInfo.level)
    cell.rewardIcon.gameObject:SetActive(tagInfo.hasFirstPassReward)
    cell.tagIcon:LoadSprite(UIConst.UI_SPRITE_CONTINGENCY_CONTRACT_BUFF, tagInfo.icon)
    
    cell.joinedStateNode:SetState(self:_GetJoinedStateName(tagInfo))
    
    local canViewGroup = self:_CanViewTagGroup(tagInfo)
    local keyInfo = tagInfo.keyInfo
    if canViewGroup then
        cell.extraMsgStateCtrl:SetState("ViewGroupState")
        cell.viewGroupBtn.gameObject:SetActive(true)
        cell.viewGroupBtn.onClick:RemoveAllListeners()
        cell.viewGroupBtn.onClick:AddListener(function()
            self:_OpenGroupTagPopup(tagInfo.groupId)
        end)
        if keyInfo then
            self:_ApplyKeyInfoToCell(cell, keyInfo)
            cell.keyNode.gameObject:SetActive(true)
        else
            cell.keyNode.gameObject:SetActive(false)
        end
    elseif keyInfo then
        cell.viewGroupBtn.gameObject:SetActive(false)
        cell.extraMsgStateCtrl:SetState("KeyState")
        self:_ApplyKeyInfoToCell(cell, keyInfo)
        cell.keyNode.gameObject:SetActive(true)
    else
        cell.extraMsgStateCtrl:SetState("NormalState")
        cell.keyNode.gameObject:SetActive(false)
    end
    
    local lockCount = #tagInfo.lockInfos
    if lockCount > 0 then
        cell.lockNode1.gameObject:SetActive(true)
        local lockInfo = tagInfo.lockInfos[1]
        cell.lockImg1.color = lockInfo.color
        if lockCount == 1 then
            cell.lockNode2.gameObject:SetActive(false)
        else
            cell.lockNode2.gameObject:SetActive(true)
            lockInfo = tagInfo.lockInfos[2]
            cell.lockImg2.color = lockInfo.color
        end
    else
        cell.lockNode1.gameObject:SetActive(false)
        cell.lockNode2.gameObject:SetActive(false)
    end
    
    cell.button.onClick:RemoveAllListeners()
    cell.deleteCellBtn.onClick:RemoveAllListeners()
    cell.deleteCellBtn.gameObject:SetActive(false)
end



ContingencyContractImportTagCtrl._GotoSelectTagAndClose = HL.Method() << function(self)
    PhaseManager:OpenPhase(PhaseId.ContingencySelectTag, {
        gameId = self.m_gameId,
    })
    self:PlayAnimationOutAndClose()
end

ContingencyContractImportTagCtrl._OnClickImport = HL.Method(HL.Boolean) << function(self, gotoAfter)
    ContingencyContractUtils.TryImportTagConfirmation(self.m_gameId, self.m_importResult, {
        warningScore1 = self.m_warningScore1,
        warningScore2 = self.m_warningScore2,
    }, {
        gotoAfter = gotoAfter,
        onSend = function(mergedIds, finalScore)
            self:_DoSendSetTag(gotoAfter, mergedIds, finalScore)
        end,
        onGotoSelectTag = function()
            self:_GotoSelectTagAndClose()
        end,
    })
end

ContingencyContractImportTagCtrl._DoSendSetTag = HL.Method(HL.Boolean, HL.Table, HL.Number) << function(self, gotoAfter, mergedIds, finalScore)
    self.m_pendingGoto = gotoAfter
    self.m_pendingFinalScore = finalScore
    
    local ccSystem = GameInstance.player.contingencyContractSystem
    ccSystem:SendSetTag(self.m_gameId, mergedIds)
end

ContingencyContractImportTagCtrl._OnSetTagSuccess = HL.Method(HL.Any) << function(self, arg)
    local gameId = unpack(arg)
    if gameId ~= self.m_gameId then
        return
    end

    local gotoAfter = self.m_pendingGoto
    local finalScore = self.m_pendingFinalScore
    self.m_pendingGoto = false

    Notify(MessageConst.SHOW_TOAST, string.format(
        Language.LUA_CONTINGENCY_CONTRACT_IMPORT_TAG_SUCCESS_TOAST, self.m_title, finalScore))

    if gotoAfter then
        self:_GotoSelectTagAndClose()
        return
    end

    self:_UpdateData()
    self:_RefreshAllUI()
    Notify(MessageConst.REFRESH_CONTROLLER_HINT)
end





HL.Commit(ContingencyContractImportTagCtrl)
