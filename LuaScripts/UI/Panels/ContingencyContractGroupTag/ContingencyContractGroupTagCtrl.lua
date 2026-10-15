local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ContingencyContractGroupTag

ContingencyContractGroupTagCtrl = HL.Class('ContingencyContractGroupTagCtrl', uiCtrl.UICtrl)







ContingencyContractGroupTagCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


ContingencyContractGroupTagCtrl.m_gameId = HL.Field(HL.String) << ""

ContingencyContractGroupTagCtrl.m_groupId = HL.Field(HL.Any)

ContingencyContractGroupTagCtrl.m_tagInfos = HL.Field(HL.Table)

ContingencyContractGroupTagCtrl.m_tagEffectCellCache = HL.Field(HL.Forward("UIListCache"))




ContingencyContractGroupTagCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local recoverState = arg and arg.recoverState or nil
    self:_InitUI()
    self:_InitData(arg, recoverState)
    self:_UpdateData()
    self:_RefreshAllUI()
    if arg then
        arg.recoverState = nil
    end
end









ContingencyContractGroupTagCtrl._InitData = HL.Method(HL.Any, HL.Opt(HL.Any)) << function(self, arg, recoverState)
    local data = recoverState or arg
    self.m_gameId = data and data.gameId or ""
    self.m_groupId = data and data.groupId or nil
end

ContingencyContractGroupTagCtrl._UpdateData = HL.Method() << function(self)
    self.m_tagInfos = ContingencyContractUtils.CreateTagBasicInfoWithKeyLockInfosByGroup(self.m_gameId, self.m_groupId)
    
    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(self.m_gameId)
    if ccData then
        for _, tagInfo in pairs(self.m_tagInfos) do
            tagInfo.hasFirstPassReward = not ccData.receivedRewardTagSet:Contains(tagInfo.tagId)
        end
    end
end



ContingencyContractGroupTagCtrl._InitUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.fullScreenCloseBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.m_tagEffectCellCache = UIUtils.genCellCache(self.view.tagEffectCell)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

ContingencyContractGroupTagCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        gameId = self.m_gameId,
        groupId = self.m_groupId,
    }
end

ContingencyContractGroupTagCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        gameId = self.m_gameId,
        groupId = self.m_groupId,
        recoverState = self:GetRecoverStateArg(),
    }
end

ContingencyContractGroupTagCtrl._RefreshAllUI = HL.Method() << function(self)
    local tagName = #self.m_tagInfos > 0 and self.m_tagInfos[1].tagName or ""
    self.view.titleText.text = string.format(Language.LUA_CONTINGENCY_CONTRACT_TAG_GROUP_TITLE_FORMAT, tagName)
    self.m_tagEffectCellCache:Refresh(#self.m_tagInfos, function(cell, luaIndex)
        self:_RefreshTagEffectCell(cell, luaIndex)
    end)
end

ContingencyContractGroupTagCtrl._RefreshTagEffectCell = HL.Method(HL.Any, HL.Number) << function(self, inCell, luaIndex)
    
    local cell = inCell
    local tagInfo = self.m_tagInfos[luaIndex]
    
    cell.levelTxt.text = tagInfo.level
    cell.tagNameTxt.text = tagInfo.tagFullName
    cell.descTxt.text = tagInfo.desc
    cell.stateController:SetState("Level" .. tagInfo.level)
    cell.rewardIcon.gameObject:SetActive(tagInfo.hasFirstPassReward)
    cell.tagIcon:LoadSprite(UIConst.UI_SPRITE_CONTINGENCY_CONTRACT_BUFF, tagInfo.icon)
    
    local keyInfo = tagInfo.keyInfo
    if keyInfo then
        cell.keyNode.gameObject:SetActive(true)
        cell.unlockLockNode.gameObject:SetActive(true)
        cell.keyImg.color = keyInfo.color
        cell.unlockLockColorDeco.color = keyInfo.color
        cell.lockDescTxt.color = keyInfo.color
        cell.lockDescTxt.text = string.format(Language.LUA_CONTINGENCY_CONTRACT_SELECT_UNLOCK_KEY, keyInfo.lockName)
    else
        cell.keyNode.gameObject:SetActive(false)
        cell.unlockLockNode.gameObject:SetActive(false)
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

    
    
    local ccSystem = GameInstance.player.contingencyContractSystem
    local ccData = ccSystem:GetCcGameData(self.m_gameId)
    local isJoined = ccData ~= nil and ccData.curSelectTagSet:Contains(tagInfo.tagId)
    cell.isJoinedNode.gameObject:SetActive(isJoined)
end





HL.Commit(ContingencyContractGroupTagCtrl)
