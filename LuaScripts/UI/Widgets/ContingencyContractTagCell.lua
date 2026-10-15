local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ContingencyContractTagCell = HL.Class('ContingencyContractTagCell', UIWidgetBase)


ContingencyContractTagCell.m_curIsSelectRemoveState = HL.Field(HL.Boolean) << false




ContingencyContractTagCell._OnFirstTimeInit = HL.Override() << function(self)
    if not string.isEmpty(self.view.config.selectRemoveOutAnimName) then
        self.view.animationWrapper:SampleClipAtPercent(self.view.config.selectRemoveOutAnimName, 1)
        self.m_curIsSelectRemoveState = false
    end
end

ContingencyContractTagCell.InitContingencyContractTagCell = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    local tagInfo = args.tagInfo
    if tagInfo.isEmpty then
        return
    end

    self.gameObject.name = "tagCell_" .. tagInfo.tagId
    tagInfo.tagEffectIndex = -1
    self:_RefreshContent(args)
end



ContingencyContractTagCell._IsTagLockByTag = HL.Method(HL.Table, HL.Table).Return(HL.Boolean) << function(self, tagInfo, tagKeyInfos)
    for _, lockId in pairs(tagInfo.lockIds) do
        local lockInfo = tagKeyInfos[lockId]
        if lume.count(lockInfo.curJoinedKeyTags) <= 0 then
            return true
        end
    end
    return false
end



ContingencyContractTagCell._RefreshContent = HL.Method(HL.Table) << function(self, args)
    local tagInfo = args.tagInfo
    local isOpen = tagInfo.isUnlockByStage

    self.view.ctrlLogicGroup:SetState("JoinedGroup", "NotJoin")
    self.view.ctrlLogicGroup:SetState("ConflictGroup", "NotConflict")
    self.view.ctrlLogicGroup:SetState("PauseGroup", "NotPause")
    self.view.stateController:SetState((tagInfo.hasFirstPassReward and isOpen) and "HasFirstPassReward" or "NoFirstPassReward")
    self.view.tagIcon:LoadSprite(UIConst.UI_SPRITE_CONTINGENCY_CONTRACT_BUFF, tagInfo.icon)

    local btn
    if isOpen then
        self:_RefreshOpenState(tagInfo, args.tagKeyInfos, args.isJoined, args.isSelected, args.isNaviTarget, args.onClickOpened)
        btn = self.view.openedBtn
    else
        self:_RefreshNotOpenState(tagInfo, args.onClickNotOpen)
        btn = self.view.notOpenBtn
    end

    btn.onIsNaviTargetChanged = function(isTarget)
        self:SetControllerDeleteEnabled(isTarget)
        args.onNaviTargetChanged(tagInfo, isTarget, self)
    end

    self:SetScoreUnlocked(args.isScoreUnlocked)
    self:SetPause(args.isPaused == true)
    self:RefreshRedDot(tagInfo, args.activityId, args.outsideRedDot)
end

ContingencyContractTagCell._RefreshOpenState = HL.Method(HL.Table, HL.Table, HL.Boolean, HL.Boolean, HL.Boolean, HL.Function)
        << function(self, tagInfo, tagKeyInfos, isJoined, isSelected, isNaviTarget, onClickOpened)
    self.view.stateController:SetState("Open")
    self:SetJoined(tagInfo, isJoined, isNaviTarget, isSelected)

    self:_RefreshKey(tagInfo, tagKeyInfos, isJoined)
    self:_RefreshLock(tagInfo, tagKeyInfos)

    self.view.openedBtn.onClick:RemoveAllListeners()
    self.view.openedBtn.onClick:AddListener(function()
        onClickOpened(tagInfo, false, self)
    end)

    self.view.controllerDeleteBtn.onClick:RemoveAllListeners()
    self.view.controllerDeleteBtn.onClick:AddListener(function()
        onClickOpened(tagInfo, true, self)
    end)
    self:SetControllerDeleteEnabled(false)
    self:RefreshHoverText(isJoined, isSelected)
end

ContingencyContractTagCell._RefreshNotOpenState = HL.Method(HL.Table, HL.Function) << function(self, tagInfo, onClickNotOpen)
    local canPreview = tagInfo.canPreview
    self.view.stateController:SetState(canPreview and "NotOpenButPreview" or "NotOpen")
    self.view.stateController:SetState("NotKey")
    self.view.lockNode.stateController:SetState("NoLock")
    self.view.ctrlLogicGroup:SetState("LockGroup", "NotLock")
    self:SetControllerDeleteEnabled(false)

    self.view.notOpenBtn.onClick:RemoveAllListeners()
    self.view.notOpenBtn.onClick:AddListener(function()
        onClickNotOpen(tagInfo, self)
    end)
    InputManagerInst:SetBindingText(self.view.notOpenBtn.hoverConfirmBindingId, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NAVI_DETAIL)
end

ContingencyContractTagCell._RefreshKey = HL.Method(HL.Table, HL.Table, HL.Boolean) << function(self, tagInfo, tagKeyInfos, isJoined)
    if string.isEmpty(tagInfo.keyId) then
        self.view.ctrlLogicGroup:SetState("KeyGroup", "NotKey")
        return
    end

    local keyInfo = tagKeyInfos[tagInfo.keyId]
    self.view.ctrlLogicGroup:SetState("KeyGroup", "IsKey")
    keyInfo.color.a = self.view.keyNode.color.a
    self.view.keyNode.color = keyInfo.color
    keyInfo.color.a = 1
end

ContingencyContractTagCell._RefreshLock = HL.Method(HL.Table, HL.Table) << function(self, tagInfo, tagKeyInfos)
    local lockNode = self.view.lockNode
    if not self:_IsTagLockByTag(tagInfo, tagKeyInfos) then
        lockNode.stateController:SetState("NoLock")
        self.view.ctrlLogicGroup:SetState("LockGroup", "NotLock")
        return
    end

    local lockCount = #tagInfo.lockIds
    local lockId = tagInfo.lockIds[1]
    local keyInfo = tagKeyInfos[lockId]
    lockNode.lock1.color = keyInfo.color
    lockNode.lock1Unlock.color = keyInfo.color
    if lockCount == 1 then
        lockNode.stateController:SetState("SingleLock")
        self.view.ctrlLogicGroup:SetState("LockGroup", "IsLock")
        return
    end

    lockNode.stateController:SetState("DoubleLock1")
    lockNode.stateController:SetState("DoubleLock2")
    self.view.ctrlLogicGroup:SetState("LockGroup", "IsLock")
    lockId = tagInfo.lockIds[2]
    keyInfo = tagKeyInfos[lockId]
    lockNode.lock2.color = keyInfo.color
    lockNode.lock2Unlock.color = keyInfo.color
end

ContingencyContractTagCell.RefreshHoverText = HL.Method(HL.Boolean, HL.Boolean) << function(self, isJoined, isSelected)
    if isJoined then
        if isSelected then
            InputManagerInst:SetBindingText(self.view.openedBtn.hoverConfirmBindingId, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NAVI_CANCEL)
        else
            InputManagerInst:SetBindingText(self.view.openedBtn.hoverConfirmBindingId, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NAVI_DETAIL)
        end
    else
        InputManagerInst:SetBindingText(self.view.openedBtn.hoverConfirmBindingId, Language.LUA_CONTINGENCY_CONTRACT_SELECT_TAG_NAVI_SET_JOIN)
    end
end

ContingencyContractTagCell.RefreshRedDot = HL.Method(HL.Table, HL.String, HL.Any) << function(self, tagInfo, activityId, outsideRedDot)
    self.view.redDot.gameObject:SetActive(true)
    self.view.redDot:InitRedDot("ContingencyContractTag", {
        activityId = activityId,
        stageId = tagInfo.unlockStage,
        tagId = tagInfo.tagId
    }, nil, outsideRedDot)
end

ContingencyContractTagCell.SetJoined = HL.Method(HL.Table, HL.Boolean, HL.Boolean, HL.Boolean) << function(self, tagInfo, isJoined, isNaviTarget, isSelected)
    self.view.ctrlLogicGroup:SetState("JoinedGroup", isJoined and "Joined" or "NotJoin")
    self:SetControllerDeleteEnabled(isNaviTarget and isJoined)
    self:UpdateSelectRemoveNode(isSelected, isJoined)
    self:RefreshHoverText(isJoined, isSelected)
end

ContingencyContractTagCell.SetPause = HL.Method(HL.Boolean) << function(self, isPaused)
    self.view.ctrlLogicGroup:SetState("PauseGroup", isPaused and "IsPause" or "NotPause")
end

ContingencyContractTagCell.SetControllerDeleteEnabled = HL.Method(HL.Boolean) << function(self, isEnabled)
    self.view.controllerDeleteBtn.enabled = isEnabled
end

ContingencyContractTagCell.SetScoreUnlocked = HL.Method(HL.Boolean) << function(self, isUnlocked)
    self.view.openedBtn.enabled = isUnlocked
    self.view.notOpenBtn.enabled = isUnlocked
end

ContingencyContractTagCell.SetConflict = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isConflict, isJoinedConflict)
    self.view.ctrlLogicGroup:SetState("ConflictGroup", isConflict and "IsConflict" or "NotConflict")
    if self.view.arrowNode and isJoinedConflict ~= nil then
        self.view.arrowNode.stateController:SetState(isJoinedConflict and "Joined" or "NotJoined")
    end
end

ContingencyContractTagCell.SetArrowNode = HL.Method(HL.Any) << function(self, arrowNode)
    self.view.arrowNode = arrowNode
end

ContingencyContractTagCell.PlaySelectRemoveOut = HL.Method() << function(self)
    if self.m_curIsSelectRemoveState then
        if not string.isEmpty(self.view.config.selectRemoveOutAnimName) then
            self.view.animationWrapper:ClearTween()
            self.view.animationWrapper:Play(self.view.config.selectRemoveOutAnimName)
            self.m_curIsSelectRemoveState = false
        end
    end
end

ContingencyContractTagCell.UpdateSelectRemoveNode = HL.Method(HL.Boolean, HL.Boolean) << function(self, isSelected, isJoined)
    if not isSelected then
        self:PlaySelectRemoveOut()
        return
    end

    if self.m_curIsSelectRemoveState ~= isJoined then
        local aniName = isJoined and self.view.config.selectRemoveInAnimName or self.view.config.selectRemoveOutAnimName
        if not string.isEmpty(aniName) then
            self.view.animationWrapper:Play(aniName)
            self.m_curIsSelectRemoveState = true
        end
    end
end

ContingencyContractTagCell.IsLockActive = HL.Method(HL.Number).Return(HL.Boolean) << function(self, lockIndex)
    local lockNode = self.view.lockNode
    local targetLock = lockNode["lock" .. lockIndex]
    return targetLock.gameObject.activeSelf
end

ContingencyContractTagCell.ChangeLock = HL.Method(HL.Table, HL.Number, HL.Boolean) << function(self, tagInfo, lockIndex, isLock)
    local lockCount = #tagInfo.lockIds
    local lockNode = self.view.lockNode
    if isLock then
        if lockCount == 1 then
            lockNode.stateController:SetState("SingleLock")
        else
            lockNode.stateController:SetState("DoubleLock" .. lockIndex)
        end
        self.view.ctrlLogicGroup:SetState("LockGroup", "IsLock")
        return
    end

    if lockCount == 1 then
        lockNode.stateController:SetState("SingleLockUnlock")
        self.view.ctrlLogicGroup:SetState("LockGroup", "NotLock")
        if not string.isEmpty(self.view.config.lockToUnlockAllAnimName) then
            self.view.animationWrapper:Play(self.view.config.lockToUnlockAllAnimName)
        end
    else
        lockNode.stateController:SetState("DoubleLockUnlock" .. lockIndex)
        if tagInfo.useKeyCount == lockCount then
            lockNode.stateController:SetState("DoubleLockUnlockAll")
            self.view.ctrlLogicGroup:SetState("LockGroup", "NotLock")
            if not string.isEmpty(self.view.config.lockToUnlockAllAnimName) then
                self.view.animationWrapper:Play(self.view.config.lockToUnlockAllAnimName)
            end
        else
            if not string.isEmpty(self.view.config.lockToUnlockPartialAnimName) then
                self.view.animationWrapper:Play(self.view.config.lockToUnlockPartialAnimName)
            end
        end
    end
end


HL.Commit(ContingencyContractTagCell)
return ContingencyContractTagCell

