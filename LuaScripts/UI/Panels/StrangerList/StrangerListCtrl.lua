local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.StrangerList















StrangerListCtrl = HL.Class('StrangerListCtrl', uiCtrl.UICtrl)







StrangerListCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STRANGER_LIST_INFO_SYNC] = 'OnSync',
    [MessageConst.ON_FRIEND_CELL_INFO_CHANGE] = 'OnCellChange',
    [MessageConst.ON_FRIEND_NEW_FRIEND_SEARCH_CONTENT_CHANGE] = 'OnSearchChange',
}


StrangerListCtrl.m_strangerList = HL.Field(HL.Table)





StrangerListCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)

    local initArg = FriendUtils.FRIEND_CELL_INIT_CONFIG.Stranger;
    initArg.onSearchChange = function(str)
        self.view.pasteBtn.gameObject:SetActive(string.isEmpty(str))
    end
    self.view.friendList:InitFriendListCtrl(initArg)

    GameInstance.player.friendSystem.strangerLisListInfoDic:Clear()
    GameInstance.player.friendSystem:SwitchNewStranger()
    self:_UpdateCache()

    self.view.pasteBtn.onClick:RemoveAllListeners()
    self.view.pasteBtn.onClick:AddListener(function()
        if Unity.GUIUtility.systemCopyBuffer:match("^%d+$") ~= nil then
            self.view.inputField.text = Unity.GUIUtility.systemCopyBuffer
        else
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FRIEND_TOAST_NOT_UID)
        end
    end)

    UIUtils.initSearchInput(self.view.inputField, {
        clearBtn = self.view.clearBtn,
        searchBtn = self.view.searchBtn,
        onInputValueChanged = function(str)
            self.view.friendList:OnChangeInputField(str)
        end,
        onInputSubmit = function()
            if string.isEmpty(self.view.inputField.text) then
                Notify(MessageConst.SHOW_TOAST, Language.CS_FRIEND_SEARCH_KEY_EMPTY)
                return
            end
            UIManager:AutoOpen(PanelId.SearchNewFriendList, self.view.inputField.text)
        end,
        onInputFocused = function()
            self:_StartInput()
        end,
        onInputEndEdit = function()
            self:_EndInput()
        end,
        onClearClick = function()
            self.view.inputField.text = ""
        end,
        onSearchClick = function()
            if string.isEmpty(self.view.inputField.text) then
                Notify(MessageConst.SHOW_TOAST, Language.CS_FRIEND_SEARCH_KEY_EMPTY)
                return
            end
            UIManager:AutoOpen(PanelId.SearchNewFriendList, self.view.inputField.text)
        end,
    })

    self.view.countDownText.gameObject:SetActive(false)
    self.view.switchBtn.onClick:RemoveAllListeners()
    self.view.switchBtn.onClick:AddListener(function()
        GameInstance.player.friendSystem:SwitchNewStranger()
        self.view.switchBtn.gameObject:SetActive(false)
        self.view.switchTimeBtn.gameObject:SetActive(true)
        self.view.countDownText.gameObject:SetActive(true)
        self.view.rootUIState:SetState('ActiveState')
        self.view.countDownText:InitCountDownText(DateTimeUtils.GetCurrentTimestampBySeconds() + 10, function()
            self.view.switchBtn.gameObject:SetActive(true)
            self.view.switchTimeBtn.gameObject:SetActive(false)
            self.view.countDownText.gameObject:SetActive(false)
            self.view.rootUIState:SetState('NormalState')
        end, UIUtils.getSecondsLeftTime)
    end)
    self.view.switchBtn.gameObject:SetActive(false)
    self.view.switchTimeBtn.gameObject:SetActive(true)
    self.view.countDownText.gameObject:SetActive(true)
    self.view.rootUIState:SetState('ActiveState')
    self.view.countDownText:InitCountDownText(DateTimeUtils.GetCurrentTimestampBySeconds() + 10, function()
        self.view.switchBtn.gameObject:SetActive(true)
        self.view.switchTimeBtn.gameObject:SetActive(false)
        self.view.countDownText.gameObject:SetActive(false)
        self.view.rootUIState:SetState('NormalState')
    end, UIUtils.getSecondsLeftTime)
    self:_Refresh(true)
end



StrangerListCtrl._StartInput = HL.Method() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
        panelId = PANEL_ID,
        isGroup = true,
        id = self.view.textInputBindingGroup.groupId,
        hintPlaceholder = self.view.controllerHintPlaceholder,
        rectTransform = self.view.whiteSelectNode,
    })
    self.m_phase:SetTabBlockState(true)
end



StrangerListCtrl._EndInput = HL.Method() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.textInputBindingGroup.groupId)
    self.view.inputField:DeactivateInputField(true)
    self.view.friendList:NaviToFirstCell()
    self.m_phase:SetTabBlockState(false)
end



StrangerListCtrl._UpdateCache = HL.Method() << function(self)
    self.m_strangerList = {}

    local friendSystem = GameInstance.player.friendSystem
    local index = 1
    for _, friendInfo in cs_pairs(friendSystem.strangerLisListInfoDic) do
        self.m_strangerList[index] = FriendUtils.friendInfo2SortInfo(friendInfo, self.view.friendList.SearchSort)
        index = index + 1
    end
end





StrangerListCtrl._Refresh = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, loading, stayPos)
    loading = loading or false

    if stayPos then
        self.view.friendList:RefreshInfoStayPos(self.m_strangerList)
    else
        self.view.friendList:RefreshInfo(self.m_strangerList, false, Language.LUA_ADD_FRIEND_EMPTY_TIP, loading)
    end

end



StrangerListCtrl.OnCellChange = HL.Method() << function(self)
    self:_UpdateCache()
    self:_Refresh(false, true)
end



StrangerListCtrl.OnSync = HL.Method() << function(self)
    self:_UpdateCache()
    self:_Refresh(false, false)
end




StrangerListCtrl.OnSearchChange = HL.Method(HL.String) << function(self, str)
    self.view.inputField.text = str
end




StrangerListCtrl.OnPhaseRefresh = HL.Override(HL.Opt(HL.Any)) << function(self, args)
    self:_UpdateCache()
    self:_Refresh()
end





StrangerListCtrl.OnShow = HL.Override() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    InputManagerInst:ToggleGroup(self.view.textInputBindingGroup.groupId, true)
end



StrangerListCtrl.OnClose = HL.Override() << function(self)
    GameInstance.player.friendSystem:ClearSyncCallback()
end




HL.Commit(StrangerListCtrl)
