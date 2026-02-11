local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SearchNewFriendList
















SearchNewFriendListCtrl = HL.Class('SearchNewFriendListCtrl', uiCtrl.UICtrl)


SearchNewFriendListCtrl.m_searchList = HL.Field(HL.Table)


SearchNewFriendListCtrl.m_searchKey = HL.Field(HL.String) << ""






SearchNewFriendListCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SEARCH_FRIEND_END] = 'OnSearchFriendEnd',
    [MessageConst.ON_FRIEND_CELL_INFO_CHANGE] = 'OnCellChange',
}





SearchNewFriendListCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local initArg = FriendUtils.FRIEND_CELL_INIT_CONFIG.NewFriendSearch;
    initArg.onSearchChange = function(str)
        self.view.pasteBtn.gameObject:SetActive(string.isEmpty(str))
    end
    self.view.friendList:InitFriendListCtrl(initArg)

    self.view.btnClose.onClick:RemoveAllListeners()
    self.view.btnClose.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
        
        Notify(MessageConst.ON_FRIEND_NEW_FRIEND_SEARCH_CONTENT_CHANGE, self.view.inputField.text)
    end)
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
            self:_OnSearch()
            self:_EndInput()
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
            self:_OnSearch()
        end,
    })

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self:BindInputPlayerAction("common_back", function()
        if self.view.inputField.isFocused then
            self:_EndInput()
        else
            self:PlayAnimationOutAndClose()
            
            Notify(MessageConst.ON_FRIEND_NEW_FRIEND_SEARCH_CONTENT_CHANGE, self.view.inputField.text)
        end
    end, self.view.textInputBindingGroup.groupId)

    
    self:_Loading()
    self.m_searchKey = arg
    self.view.inputField.text = self.m_searchKey
    GameInstance.player.friendSystem:SearchNewFriend(self.m_searchKey)
end



SearchNewFriendListCtrl._Loading = HL.Method() << function(self)
    self.m_searchList = {}
    self.view.text.text = string.format(Language.LUA_FRIEND_SEARCH_COUNT, self.m_searchKey, #self.m_searchList)
    self.view.friendList:RefreshInfo(self.m_searchList, true, Language.LUA_FRIEND_SEARCHING, true)
end



SearchNewFriendListCtrl._OnSearch = HL.Method() << function(self)
    self.m_searchKey = self.view.inputField.text
    GameInstance.player.friendSystem:SearchNewFriend(self.m_searchKey)
end



SearchNewFriendListCtrl._StartInput = HL.Method() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
        panelId = PANEL_ID,
        isGroup = true,
        id = self.view.textInputBindingGroup.groupId,
        hintPlaceholder = self.view.controllerHintPlaceholder,
        rectTransform = self.view.textInputBindingGroup.transform,
    })
end



SearchNewFriendListCtrl._EndInput = HL.Method() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.textInputBindingGroup.groupId)
    self.view.inputField:DeactivateInputField(true)
    self.view.friendList:NaviToFirstCell()
end



SearchNewFriendListCtrl.OnSearchFriendEnd = HL.Method() << function(self)
    self:_UpdateCache()
    self:_Refresh()
end



SearchNewFriendListCtrl.OnCellChange = HL.Method() << function(self)
    self:_UpdateCache()
    self.view.friendList:RefreshInfoStayPos(self.m_searchList)
end



SearchNewFriendListCtrl._UpdateCache = HL.Method() << function(self)
    self.m_searchList = {}

    local friendSystem = GameInstance.player.friendSystem
    local index = 1
    for _, friendInfo in cs_pairs(friendSystem.newFriendSearchListInfoDic) do
        self.m_searchList[index] = FriendUtils.friendInfo2SortInfo(friendInfo, self.view.friendList.SearchSort)
        index = index + 1
    end
end



SearchNewFriendListCtrl._Refresh = HL.Method() << function(self)
    self.view.text.text = string.format(Language.LUA_FRIEND_SEARCH_COUNT, self.m_searchKey, #self.m_searchList)
    self.view.friendList:RefreshInfo(self.m_searchList, true, Language.LUA_FRIEND_NO_SEARCH_FRIEND)
end



SearchNewFriendListCtrl.OnShow = HL.Override() << function(self)
    if DeviceInfo.inputType ~= DeviceInfo.InputType.Controller then
        return
    end
    InputManagerInst:ToggleGroup(self.view.textInputBindingGroup.groupId, true)
end



SearchNewFriendListCtrl.OnClose = HL.Override() << function(self)
    GameInstance.player.friendSystem:ClearSyncCallback()
end

HL.Commit(SearchNewFriendListCtrl)
