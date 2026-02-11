local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FriendRoleDisplay


local charCount = 4











FriendRoleDisplayCtrl = HL.Class('FriendRoleDisplayCtrl', uiCtrl.UICtrl)


FriendRoleDisplayCtrl.m_genDisplayCells = HL.Field(HL.Forward("UIListCache"))


FriendRoleDisplayCtrl.m_charInfo = HL.Field(HL.Table)


FriendRoleDisplayCtrl.m_index = HL.Field(HL.Number) << 1


FriendRoleDisplayCtrl.m_selectCharInsIdList = HL.Field(HL.Table)






FriendRoleDisplayCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FRIEND_BUSINESS_INFO_CHANGE] = 'OnChange',
}



FriendRoleDisplayCtrl.OnChange = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end





FriendRoleDisplayCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        Notify(MessageConst.HIDE_COMMON_HOVER_TIP)
    end)

    self.view.applyBtn.onClick:RemoveAllListeners()
    self.view.applyBtn.onClick:AddListener(function()

        local array = {}
        for _,insId in ipairs(self.m_selectCharInsIdList) do
            table.insert(array, insId.instId)
        end
        GameInstance.player.friendSystem:DisplayCharModify(array)
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    
    local info = {
        selectNum = charCount,
    }

    self.m_selectCharInsIdList = {}

    self.view.charList:InitCharFormationList(info, nil , true)
    self.view.charList:SetUpdateCellFunc(nil, function(select, cellIndex, charItem, charItemList, charInfoList)
        self:_CharListChangeSelectIndex(select, cellIndex, charItem, charItemList, charInfoList)
    end)

    for i = 0, GameInstance.player.friendSystem.SelfInfo.charInfos.Count - 1 do
        local charInfo = GameInstance.player.friendSystem.SelfInfo.charInfos[i]
        table.insert(self.m_selectCharInsIdList, { instId = charInfo.instId })
    end
    self.view.charList:UpdateCharItems(CharInfoUtils.getAllCharInfoList())
    self.view.charList:ShowSelectChars(self.m_selectCharInsIdList)

    self.m_genDisplayCells = UIUtils.genCellCache(self.view.charHeadCell)
    self.m_genDisplayCells:Refresh(charCount, function(cell, luaIndex)
        self:_RefreshDisplayCells(cell, luaIndex)
    end)
end





FriendRoleDisplayCtrl._RefreshDisplayCells = HL.Method(HL.Table, HL.Number) << function(self, cell, luaIndex)
    cell.roleState:SetState(luaIndex <= #self.m_selectCharInsIdList and 'role' or 'add')
    
    cell.roleNunTxt.text = string.format('%02d', luaIndex)
    if luaIndex <= #self.m_selectCharInsIdList then
        local instId = self.m_selectCharInsIdList[luaIndex].instId
        local charInfo = CharInfoUtils.getPlayerCharInfoByInstId(instId)
        local charData = CharInfoUtils.getCharTableData(charInfo.templateId)
        local item = {
            instId = instId,
            templateId = charInfo.templateId,
            level = charInfo.level,
            ownTime = charInfo.ownTime,
            rarity = charData.rarity,
            slotIndex = Const.BATTLE_SQUAD_MAX_CHAR_NUM + 1,
            slotReverseIndex = -1,
        }
        cell.charHeadCell:InitCharFormationHeadCell(item, nil, true)
    end
end








FriendRoleDisplayCtrl._CharListChangeSelectIndex = HL.Method(HL.Boolean, HL.Number, HL.Table, HL.Table, HL.Table) << function(self, select, cellIndex, charItem, charItemList, charInfoList)
    self.m_selectCharInsIdList = {}
    for index, item in ipairs(charItemList) do
        table.insert(self.m_selectCharInsIdList, { instId = item.instId })
    end
    self.m_genDisplayCells:Refresh(charCount, function(cell, luaIndex)
        self:_RefreshDisplayCells(cell, luaIndex)
    end)
end











HL.Commit(FriendRoleDisplayCtrl)
