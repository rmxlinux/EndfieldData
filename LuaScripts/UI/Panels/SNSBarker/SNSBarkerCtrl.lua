
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SNSBarker

local NaviDirection = CS.UnityEngine.UI.NaviDirection

local ChatTypeFilter = {
    [GEnums.SNSChatType.Normal] = {
        
        nameLangKey = "LUA_BARKER_FILTER_CHAT_TYPE_TAG_NPC",
        order = 2,
    },
    [GEnums.SNSChatType.Group] = {
        
        nameLangKey = "LUA_BARKER_FILTER_CHAT_TYPE_TAG_GROUP",
        order = 3,
    },
    [GEnums.SNSChatType.Char] = {
        
        nameLangKey = "LUA_BARKER_FILTER_CHAT_TYPE_TAG_CHAR",
        order = 1,
    },
}

SNSBarkerCtrl = HL.Class('SNSBarkerCtrl', uiCtrl.UICtrl)

SNSBarkerCtrl.m_getContactNpcCellFunc = HL.Field(HL.Function)

SNSBarkerCtrl.m_curSelectedSubDialogCell = HL.Field(HL.Forward("SNSSubDialogCell"))

SNSBarkerCtrl.m_curSelectedSubDialogId = HL.Field(HL.String) << ""

SNSBarkerCtrl.m_curSelectedChatId = HL.Field(HL.String) << ""

SNSBarkerCtrl.m_chatVOs = HL.Field(HL.Table)

SNSBarkerCtrl.m_chatFoldOutStates = HL.Field(HL.Table)

SNSBarkerCtrl.m_cachedSelectedTags = HL.Field(HL.Table)

SNSBarkerCtrl.m_filterArgs = HL.Field(HL.Table)





SNSBarkerCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


SNSBarkerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_getContactNpcCellFunc = UIUtils.genCachedCellFunction(self.view.contactNpcScrollList)

    self.view.contactNpcScrollList.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateContactNpcCell(gameObject, csIndex)
    end)

    self.view.btnCommonFilter.button.onClick:AddListener(function()
        self:_OnBtnFilterClick()
    end)

    self:_InitData(arg)
    self:_InitFilterArgs()

    self:_RefreshFilterBtnState()
    self:_GenContactNpcVOs(self.m_cachedSelectedTags)
    self:_RefreshContactNpcList()
    self:_RefreshContent()
    
    self:_InitController()
end








SNSBarkerCtrl.OnClickContactNpcCell = HL.Method(HL.Number) << function(self, csIndex)
    local chatVO = self.m_chatVOs[LuaIndex(csIndex)]
    self.m_curSelectedChatId = chatVO and chatVO.chatId or ""

    
    
    
    self:_SetNpcCellFoldOut(csIndex, not self.m_chatFoldOutStates[chatVO.chatId], DeviceInfo.usingController)

    if DeviceInfo.usingController then
        
        local cell = self.m_getContactNpcCellFunc(LuaIndex(csIndex))
        
        local subCell = cell.m_subDialogCellCache:Get(1)
        self:SetNaviTarget(subCell.view.button)

        self:_ToggleSubCellNavi(true)
    end
end

SNSBarkerCtrl._SetNpcCellFoldOut = HL.Method(HL.Number, HL.Boolean, HL.Boolean) << function(self, csIndex, isFoldOut, fastMode)
    local luaIndex = LuaIndex(csIndex)
    local chatId = self.m_chatVOs[luaIndex].chatId
    
    self.m_chatFoldOutStates[chatId] = isFoldOut
    self.view.contactNpcScrollList:ToggleByState(csIndex, isFoldOut, fastMode)

    
    local cell = self.m_getContactNpcCellFunc(luaIndex)
    if cell then
        cell:SetFoldOut(isFoldOut)
    end
end

SNSBarkerCtrl._FoldAllNpcCells = HL.Method() << function(self)
    self.m_chatFoldOutStates = {}
    self.view.contactNpcScrollList:FoldAll(false)
    for luaIndex = 1, #self.m_chatVOs do
        
        local cell = self.m_getContactNpcCellFunc(luaIndex)
        if cell then
            cell:SetFoldOut(false)
        end
    end
end

SNSBarkerCtrl.OnClickDialogCell = HL.Method(HL.String, HL.String, HL.Forward("SNSSubDialogCell"))
        << function(self, chatId, dialogId, subDialogCell)
    if #self.m_chatVOs == 0 then
        
        return
    end

    if self.m_curSelectedSubDialogId == dialogId then
        return
    end
    self.m_curSelectedSubDialogId = dialogId
    self.m_curSelectedChatId = chatId

    if self.m_curSelectedSubDialogCell then
        self.m_curSelectedSubDialogCell:SetSelected(false)
    end
    subDialogCell:SetSelected(true)
    self.m_curSelectedSubDialogCell = subDialogCell

    self:_RefreshContent()
end

SNSBarkerCtrl._InitData = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    self.m_chatFoldOutStates = {}
    local dialogId = arg and arg.dialogId
    if not string.isEmpty(dialogId) and Tables.sNSDialogTable:ContainsKey(dialogId) then
        self.m_curSelectedSubDialogId = dialogId
        self.m_curSelectedChatId = Tables.sNSDialogTable[dialogId].chatId
    end

    if string.isEmpty(self.m_curSelectedChatId) then
        self.m_curSelectedChatId = arg and arg.selectedChatId or ""
    end

    self.m_cachedSelectedTags = arg and arg.selectedTags and lume.deepCopy(arg.selectedTags) or {}
end

SNSBarkerCtrl._RefreshContactNpcListAfterFilter = HL.Method() << function(self)
    self.m_chatFoldOutStates = {}
    local hasResult = #self.m_chatVOs > 0
    self.view.contactNpcScrollList.gameObject:SetActive(hasResult)
    self.view.nonResult.gameObject:SetActive(not hasResult)
    if hasResult then
        self.view.contactNpcScrollList:UpdateCount(#self.m_chatVOs, true)
        self:_FoldAllNpcCells()
        self:_RefreshNaviTarget()
    end
end

SNSBarkerCtrl._RefreshContactNpcList = HL.Method() << function(self)
    local nonSelectSubDialog = string.isEmpty(self.m_curSelectedSubDialogId)
    local selectedChatId = self.m_curSelectedChatId
    local hasSelectedChat = not string.isEmpty(selectedChatId)
    local targetNpcCSIndex

    if not nonSelectSubDialog then
        local dialogCfg = Tables.sNSDialogTable[self.m_curSelectedSubDialogId]
        local chatId = dialogCfg.chatId

        for luaIndex, chatVO in ipairs(self.m_chatVOs) do
            if chatVO.chatId == chatId then
                targetNpcCSIndex = CSIndex(luaIndex)
                break
            end
        end
    elseif hasSelectedChat then
        for luaIndex, chatVO in ipairs(self.m_chatVOs) do
            if chatVO.chatId == selectedChatId then
                targetNpcCSIndex = CSIndex(luaIndex)
                break
            end
        end
    end

    local shouldRecoverNpcCell = not nonSelectSubDialog
            or (not DeviceInfo.usingController and hasSelectedChat and targetNpcCSIndex ~= nil)

    
    if targetNpcCSIndex == nil then
        targetNpcCSIndex = 0
        self.m_curSelectedSubDialogId = ""
        self.m_curSelectedChatId = ""
        shouldRecoverNpcCell = false
    end

    local hasResult = #self.m_chatVOs > 0
    if hasResult then
        self.view.contactNpcScrollList:UpdateCount(#self.m_chatVOs)
    end
    
    
    
    
    self:_StartCoroutine(function()
        coroutine.step()
        if hasResult then
            self:_FoldAllNpcCells()
        end
        coroutine.step()
        if self.m_isClosed then
            return
        end
        self.view.contactNpcScrollList.gameObject:SetActive(hasResult)
        self.view.nonResult.gameObject:SetActive(not hasResult)
        if hasResult and targetNpcCSIndex ~= nil then
            self:_TryRecoverScrollToNpcCell(targetNpcCSIndex)
        end

        if hasResult and shouldRecoverNpcCell then
            self:_SetNpcCellFoldOut(targetNpcCSIndex, true, true)
        end

        coroutine.step()
        self:_RefreshNaviTarget()
    end)
end

SNSBarkerCtrl._OnUpdateContactNpcCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local npcVO = self.m_chatVOs[LuaIndex(csIndex)]
    
    local content = self.m_getContactNpcCellFunc(go)
    local isFoldOut = self.m_chatFoldOutStates[npcVO.chatId] == true
    content:InitSNSContactNpcCell(npcVO, isFoldOut, function()
        self:OnClickContactNpcCell(csIndex)
    end, function(cell, chatId, dialogId, luaIndex)
        self:_RefreshSubCell(cell, chatId, dialogId, luaIndex)
    end)

    if DeviceInfo.usingController then
        content.view.foldOut.onIsNaviTargetChanged = function(isTarget, isGroupChange)
            self:_OnIsNaviTargetChangedNpcCell(csIndex, isTarget, isGroupChange)
        end

        content.view.foldOut.enableControllerNavi = self.m_curFocusSubCellLuaIndex < 0
    end

    
    local foldoutComponent = go:GetComponent(typeof(CS.Beyond.UI.UIFoldoutComponent))
    foldoutComponent:Refresh(csIndex)
    self.view.contactNpcScrollList:ToggleByState(csIndex, isFoldOut, true)
end

SNSBarkerCtrl._RefreshSubCell = HL.Method(HL.Forward("SNSSubDialogCell"), HL.String, HL.String, HL.Number)
        << function(self, cell, chatId, dialogId, luaIndex)
    cell:InitSNSSubDialogCell(chatId, dialogId,
                              function(chatId, dialogId, dialogCell)
                                  self:OnClickDialogCell(chatId, dialogId,
                                                         dialogCell)
                              end)
    cell:SetSelected(self.m_curSelectedSubDialogId == dialogId, true)
    if self.m_curSelectedSubDialogId == dialogId then
        self.m_curSelectedSubDialogCell = cell
    end

    if DeviceInfo.usingController then
        cell.view.button.onIsNaviTargetChanged = function(isTarget, isGroupChange)
            self:_OnIsNaviTargetChangedSubCell(luaIndex, isTarget, isGroupChange)
        end
    end
end

SNSBarkerCtrl._GenContactNpcVOs = HL.Method(HL.Table) << function(self, selectedTags)
    local sns = GameInstance.player.sns
    local chatVOs = {}
    for chatId, chatInfo in pairs(sns.chatInfoDic) do
        local chatCfg = Tables.sNSChatTable[chatId]

        local chatTypeMatch = false
        local hasChatTypeTag = false
        for _, tag in ipairs(selectedTags) do
            if tag.chatType ~= nil then
                hasChatTypeTag = true
            end
            if hasChatTypeTag then
                chatTypeMatch = chatTypeMatch or chatCfg.chatType == tag.chatType
            end
        end
        if not hasChatTypeTag then
            chatTypeMatch = true
        end

        local dialogIds = {}
        
        if chatTypeMatch then
            local sortId1 = 0 
            local sortId2 = 0 
            
            for _, dialogId in pairs(chatInfo.dialogIds) do
                local readMatch = false
                local hasReadTag = false
                local isRead = sns:DialogHasRead(dialogId)
                if not isRead then
                    sortId1 = 1
                end

                local isEnd = sns:DialogHasEnd(dialogId)
                if not isEnd then
                    sortId2 = 1
                end
                for _, tag in ipairs(selectedTags) do
                    if tag.endState ~= nil then
                        hasReadTag = true
                    end
                    if hasReadTag then
                        readMatch = readMatch or isEnd == tag.endState
                    end
                end
                if not hasReadTag then
                    readMatch = true
                end

                if readMatch then
                    table.insert(dialogIds, dialogId)
                end
            end

            local hasTopic = false
            
            if chatInfo.hasTopic then
                local readMatch = false
                local hasReadTag = false
                local isEnd = chatInfo.allTopicFinished
                for _, tag in ipairs(selectedTags) do
                    if tag.endState ~= nil then
                        hasReadTag = true
                    end

                    if hasReadTag then
                        readMatch = readMatch or isEnd == tag.endState
                    end
                end
                if not hasReadTag then
                    readMatch = true
                end

                if readMatch then
                    hasTopic = true
                end

                if chatInfo.hasTopicUnread then
                    sortId1 = 1
                end
                if not isEnd then
                    sortId2 = 1
                end
            end

            if hasTopic or #dialogIds > 0 then
                table.insert(chatVOs, {
                    chatId = chatId,
                    timestamp = chatInfo.latestDialogTs,
                    sortId1 = sortId1,
                    sortId2 = sortId2,
                    dialogIds = dialogIds,
                    hasTopic = hasTopic,
                })
            end
        end
    end

    table.sort(chatVOs, Utils.genSortFunction({ "sortId1", "sortId2" , "timestamp" }))
    self.m_chatVOs = chatVOs
end

SNSBarkerCtrl._RefreshContent = HL.Method() << function(self)
    local hasSelect = not string.isEmpty(self.m_curSelectedSubDialogId)
    if hasSelect then
        local dialogId = self.m_curSelectedSubDialogId
        local chatId = Tables.sNSDialogTable[dialogId].chatId
        GameInstance.player.sns:ReadDialog(dialogId)
        self.view.snsDialogContentCore:InitSNSDialogContentCore(chatId, dialogId)
    end
    self.view.nonSelected.gameObject:SetActive(not hasSelect)
    self.view.selected.gameObject:SetActive(hasSelect)
end

SNSBarkerCtrl._InitFilterArgs = HL.Method() << function(self)
    local filterArgs = {}
    filterArgs.tagGroups = {}

    local chatTypeFilter = {}
    chatTypeFilter.title = Language.LUA_BARKER_FILTER_CHAT_TYPE_TITLE
    chatTypeFilter.tags = {}
    for chatType, chatTypeFilterCfg in pairs(ChatTypeFilter) do
        table.insert(chatTypeFilter.tags, {
            chatType = chatType,
            name = Language[chatTypeFilterCfg.nameLangKey],
            order = chatTypeFilterCfg.order,
        })
    end
    table.sort(chatTypeFilter.tags, Utils.genSortFunction({ "order"}, true))
    table.insert(filterArgs.tagGroups, chatTypeFilter)

    local dialogReadFilter = {}
    dialogReadFilter.title = Language.LUA_COMMON_FILTER_END_STATE_TITLE
    dialogReadFilter.tags = { { name = Language.LUA_COMMON_FILTER_END_STATE_NO, endState = false },
                              { name = Language.LUA_COMMON_FILTER_END_STATE_YES, endState = true } }
    table.insert(filterArgs.tagGroups, dialogReadFilter)

    filterArgs.onConfirm = function(selectedTags)
        self:_OnFilterConfirm(selectedTags)
    end

    self.m_filterArgs = filterArgs
end

SNSBarkerCtrl._RefreshFilterBtnState = HL.Method() << function(self)
    local hasFilter = #self.m_cachedSelectedTags > 0
    self.view.btnCommonFilter.normalNode.gameObject:SetActiveIfNecessary(not hasFilter)
    self.view.btnCommonFilter.existNode.gameObject:SetActiveIfNecessary(hasFilter)
end

SNSBarkerCtrl._TryRecoverScrollToNpcCell = HL.Method(HL.Number) << function(self, targetNpcCSIndex)
    local targetNpcLuaIndex = LuaIndex(targetNpcCSIndex)
    self:_StartCoroutine(function()
        for _ = 1, 3 do
            if self.m_isClosed then
                return
            end
            self.view.contactNpcScrollList:ScrollToIndex(targetNpcCSIndex, true)
            coroutine.step()
            if self.m_getContactNpcCellFunc(targetNpcLuaIndex) ~= nil then
                return
            end
        end
    end)
end

SNSBarkerCtrl._IsFilterChange = HL.Method(HL.Table).Return(HL.Boolean) << function(self, selectedTags)
    if #self.m_cachedSelectedTags ~= #selectedTags then
        return true
    end

    if #selectedTags == 0 then
        return false
    end

    local changed = false
    for _, selectedTag in ipairs(selectedTags) do
        local hasSameTag = false
        for _, cachedSelectedTag in ipairs(self.m_cachedSelectedTags) do
            if FilterUtils.isSameTagInfo(cachedSelectedTag, selectedTag) then
                hasSameTag = true
                break
            end
        end
        if not hasSameTag then
            changed = true
            break
        end
    end

    return changed
end

SNSBarkerCtrl._OnFilterConfirm = HL.Method(HL.Table) << function(self, selectedTags)
    selectedTags = selectedTags or {}
    if not self:_IsFilterChange(selectedTags) then
        return
    end
    self.m_cachedSelectedTags = lume.deepCopy(selectedTags)
    self.m_curSelectedSubDialogId = ""
    self.m_curSelectedChatId = ""

    self:_RefreshFilterBtnState()
    self.view.snsDialogContentCore:ClearAsyncHandler()

    self:_GenContactNpcVOs(self.m_cachedSelectedTags)
    
    self:_RefreshContactNpcListAfterFilter()
    self:_RefreshContent()
    
    self:_ManuallyResetControllerState()
end

SNSBarkerCtrl._OnBtnFilterClick = HL.Method() << function(self)
    self.m_filterArgs.selectedTags = self.m_cachedSelectedTags
    self:Notify(MessageConst.SHOW_COMMON_FILTER, self.m_filterArgs)
end

SNSBarkerCtrl.GetRecoverStateArg = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    local selectedChatId = self.m_curSelectedChatId
    if string.isEmpty(selectedChatId) and not string.isEmpty(self.m_curSelectedSubDialogId) then
        selectedChatId = Tables.sNSDialogTable[self.m_curSelectedSubDialogId].chatId
    end

    return {
        dialogId = self.m_curSelectedSubDialogId,
        selectedChatId = selectedChatId,
        selectedTags = lume.deepCopy(self.m_cachedSelectedTags),
    }
end

SNSBarkerCtrl.GetPanelType = HL.Method().Return(HL.Number) << function(self)
    return SNSUtils.PanelType.FullScreenPanel
end

SNSBarkerCtrl._IsDialogInCurrentList = HL.Method(HL.String).Return(HL.Boolean) << function(self, dialogId)
    local dialogCfg = Tables.sNSDialogTable[dialogId]
    local chatId = dialogCfg.chatId
    local isTopic = not string.isEmpty(dialogCfg.topicId)

    for _, chatVO in ipairs(self.m_chatVOs) do
        if chatVO.chatId == chatId then
            if isTopic then
                return chatVO.hasTopic
            end
            for _, id in ipairs(chatVO.dialogIds) do
                if id == dialogId then
                    return true
                end
            end
            return false
        end
    end
    return false
end

SNSBarkerCtrl.OnRefresh = HL.Method(HL.String) << function(self, dialogId)
    local selectedTags = self:_IsDialogInCurrentList(dialogId) and self.m_cachedSelectedTags or {}
    self:_InitData({ dialogId = dialogId, selectedTags = selectedTags })
    self:_InitFilterArgs()

    self:_RefreshFilterBtnState()
    self:_GenContactNpcVOs(self.m_cachedSelectedTags)
    self:_RefreshContactNpcList()
    self:_RefreshContent()
end



SNSBarkerCtrl.m_curFocusNpcCellCSIndex = HL.Field(HL.Number) << -1

SNSBarkerCtrl.m_curFocusSubCellLuaIndex = HL.Field(HL.Number) << -1

SNSBarkerCtrl.m_focusSubCellReturnToNpcCellBindId = HL.Field(HL.Number) << -1

SNSBarkerCtrl.m_loseSubCellFocusFlag = HL.Field(HL.Boolean) << false

SNSBarkerCtrl.m_returnToNpcCellBindActionFlag = HL.Field(HL.Boolean) << false

SNSBarkerCtrl._RefreshNaviTarget = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local nonSelectSubDialog = string.isEmpty(self.m_curSelectedSubDialogId)
    local targetNpcCSIndex

    if nonSelectSubDialog then
        local focusIndex = 0
        if not string.isEmpty(self.m_curSelectedChatId) then
            for luaIndex, chatVO in ipairs(self.m_chatVOs) do
                if chatVO.chatId == self.m_curSelectedChatId then
                    focusIndex = CSIndex(luaIndex)
                    break
                end
            end
        end
        self.m_curFocusNpcCellCSIndex = focusIndex
        self.m_curFocusSubCellLuaIndex = -1
    else
        local dialogCfg = Tables.sNSDialogTable[self.m_curSelectedSubDialogId]
        local isTopic = not string.isEmpty(dialogCfg.topicId)
        local chatId = dialogCfg.chatId
        local chatCfg = Tables.sNSChatTable[chatId]

        for luaIndex, chatVO in ipairs(self.m_chatVOs) do
            if chatVO.chatId == chatId then
                targetNpcCSIndex = CSIndex(luaIndex)
                break
            end
        end

        
        if targetNpcCSIndex == nil then
            targetNpcCSIndex = 0
            self.m_curFocusSubCellLuaIndex = -1
        else
            if isTopic or chatCfg.isSettlementChannel then
                self.m_curFocusSubCellLuaIndex = 1
            else
                
                
                
                local targetNpcCellLuaIndex = LuaIndex(targetNpcCSIndex)
                
                local npcCell = self.m_getContactNpcCellFunc(targetNpcCellLuaIndex)
                local dialogCount = #self.m_chatVOs[targetNpcCellLuaIndex].dialogIds
                local chatInfo = GameInstance.player.sns.chatInfoDic:get_Item(chatId)
                local startIndex = chatInfo.hasTopic and 2 or 1
                local targetSubCellLuaIndex = startIndex
                for i = startIndex, dialogCount do
                    
                    local subDialogCell = npcCell.m_subDialogCellCache:Get(i)
                    if subDialogCell.m_dialogId == self.m_curSelectedSubDialogId then
                        targetSubCellLuaIndex = i
                        break
                    end
                end
                self.m_curFocusSubCellLuaIndex = targetSubCellLuaIndex
            end
        end

        self.m_curFocusNpcCellCSIndex = targetNpcCSIndex
    end

    
    local cell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
    if cell then
        if nonSelectSubDialog then
            self:SetNaviTarget(cell.view.foldOut)
        else
            
            local subCell = cell.m_subDialogCellCache:Get(self.m_curFocusSubCellLuaIndex)
            self:SetNaviTarget(subCell.view.button)
        end
    else
        self:ClearNaviTarget()
    end
end

SNSBarkerCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    local scrollRect = self.view.contactNpcScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    scrollRect.naviGroup.onDefaultNaviFailed:AddListener(function(dir)
        self:_OnContactListNaviFailed(dir)
    end)

    self.m_focusSubCellReturnToNpcCellBindId = self:BindInputPlayerAction("common_back", function()
        self.m_returnToNpcCellBindActionFlag = true

        
        local cell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
        self:SetNaviTarget(cell.view.foldOut)

        self:_ToggleSubCellNavi(false)

        
    end)

    
    
    InputManagerInst:ToggleBinding(self.m_focusSubCellReturnToNpcCellBindId, not string.isEmpty(self.m_curSelectedSubDialogId))
end

SNSBarkerCtrl._OnContactListNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    if not DeviceInfo.usingController or self.m_curFocusSubCellLuaIndex >= 0 then
        return
    end
    local count = #self.m_chatVOs
    if count <= 1 then
        return
    end

    local currentIndex = self.m_curFocusNpcCellCSIndex
    local targetIndex
    if dir == NaviDirection.Up and currentIndex == 0 then
        targetIndex = count - 1
    elseif dir == NaviDirection.Down and currentIndex == count - 1 then
        targetIndex = 0
    else
        return
    end

    
    local currentCell = self.m_getContactNpcCellFunc(LuaIndex(currentIndex))
    local currentTarget = currentCell and currentCell.view.foldOut
    if not currentTarget or not currentTarget.enableControllerNavi or not currentTarget:IsActive()
            or not currentTarget:IsInteractable() or InputManagerInst.controllerNaviManager.curTarget ~= currentTarget then
        return
    end

    self.view.contactNpcScrollList:ScrollToIndex(targetIndex, true)
    local targetCell = self.m_getContactNpcCellFunc(LuaIndex(targetIndex))
    local target = targetCell and targetCell.view.foldOut
    if target and target.enableControllerNavi and target:IsActive() and target:IsInteractable() then
        self:SetNaviTarget(target)
    end
end

SNSBarkerCtrl._OnSubContentDefaultNaviFailed = HL.Method(CS.UnityEngine.UI.NaviDirection) << function(self, dir)
    if dir == NaviDirection.Left or dir == NaviDirection.Right then
        return
    end

    local offset
    if dir == NaviDirection.Up then
        offset = -1
    elseif dir == NaviDirection.Down then
        offset = 1
    end

    if offset == nil then
        logger.error("[sns] SNSBarkerCtrl._OnSubContentDefaultNaviFailed error, offset is nil")
        return
    end

    local nextFocusCellCSIndex = self.m_curFocusNpcCellCSIndex + offset
    
    local nexNpcCell = self.m_getContactNpcCellFunc(LuaIndex(nextFocusCellCSIndex))
    if nexNpcCell == nil then
        return
    end

    self:_SetNpcCellFoldOut(self.m_curFocusNpcCellCSIndex, false, true)
    self:_SetNpcCellFoldOut(nextFocusCellCSIndex, true, true)

    
    local preCell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))

    
    local firstSubCell = preCell.m_subDialogCellCache:Get(1)
    self:SetNaviTarget(firstSubCell.view.button)

    self.m_curFocusNpcCellCSIndex = nextFocusCellCSIndex
end

SNSBarkerCtrl._ToggleSubCellNavi = HL.Method(HL.Boolean) << function(self, isOn)
    
    local phase = self.m_phase
    phase:ToggleBasicPanelCloseBtn(not isOn)

    InputManagerInst:ToggleBinding(self.m_focusSubCellReturnToNpcCellBindId, isOn)
end

SNSBarkerCtrl.ReturnToFocusCell = HL.Method() << function(self)
    
    local cell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
    if self.m_curFocusSubCellLuaIndex > 0 then
        
        local subCell = cell.m_subDialogCellCache:Get(self.m_curFocusSubCellLuaIndex)
        self:SetNaviTarget(subCell.view.button)
    else
        self:SetNaviTarget(cell.view.foldOut)
    end
end

SNSBarkerCtrl._OnIsNaviTargetChangedNpcCell = HL.Method(HL.Number, HL.Boolean, HL.Boolean) << function(self, csIndex, isTarget, isGroupChange)
    if not isTarget then
        return
    end
    

    local preFocusNpcCellCSIndex = self.m_curFocusNpcCellCSIndex
    self.m_curFocusNpcCellCSIndex = csIndex

    if not self.m_loseSubCellFocusFlag then
        return
    end
    

    if preFocusNpcCellCSIndex ~= csIndex then
        
        self:_SetNpcCellFoldOut(preFocusNpcCellCSIndex, false, true)
        self:_SetNpcCellFoldOut(csIndex, true, true)
        
        local npcCell = self.m_getContactNpcCellFunc(LuaIndex(csIndex))
        
        if npcCell then
            
            local subCell = npcCell.m_subDialogCellCache:Get(1)
            self:SetNaviTarget(subCell.view.button)
        end
    else
        
        if self.m_returnToNpcCellBindActionFlag then
            
            self:_SetNpcCellFoldOut(preFocusNpcCellCSIndex, false, true)
            self.m_returnToNpcCellBindActionFlag = false
        else
            
            local nextNpcCellCSIndex = preFocusNpcCellCSIndex - 1
            if nextNpcCellCSIndex >= 0 then
                self:_SetNpcCellFoldOut(preFocusNpcCellCSIndex, false, true)
                self:_SetNpcCellFoldOut(nextNpcCellCSIndex, true, true)
                
                local npcCell = self.m_getContactNpcCellFunc(LuaIndex(nextNpcCellCSIndex))
                
                if npcCell then
                    
                    local subCellCache = npcCell.m_subDialogCellCache
                    
                    local subCell = subCellCache:Get(subCellCache:GetCount())
                    self:SetNaviTarget(subCell.view.button)

                    
                    self.m_curFocusNpcCellCSIndex = nextNpcCellCSIndex
                end
            else
                
                
                local npcCell = self.m_getContactNpcCellFunc(LuaIndex(preFocusNpcCellCSIndex))
                if npcCell then
                    
                    local subCell = npcCell.m_subDialogCellCache:Get(1)
                    self:SetNaviTarget(subCell.view.button)
                end
            end
        end
    end
    self.m_loseSubCellFocusFlag = false

    
    
    
    
    
end

SNSBarkerCtrl._OnIsNaviTargetChangedSubCell = HL.Method(HL.Number, HL.Boolean, HL.Boolean) << function(self, luaIndex, isTarget, isGroupChange)
    if isTarget then
        self.m_curFocusSubCellLuaIndex = luaIndex
        self.m_loseSubCellFocusFlag = false
    elseif not isGroupChange then
        self.m_curFocusSubCellLuaIndex = -1
        self.m_loseSubCellFocusFlag = true
    end

    
    
    
    
    
end

SNSBarkerCtrl._ManuallyResetControllerState = HL.Method() << function(self)
    self:_ToggleSubCellNavi(false)
    self.view.snsDialogContentCore:ToggleContentCoreFocusable(false)
end

SNSBarkerCtrl.TryContinueDialog = HL.Method() << function(self)
    self:_RefreshContent()
end

SNSBarkerCtrl.OnSwitchOn = HL.Method(HL.Boolean) << function(self, isOn)
    if not isOn then
        self.view.snsDialogContentCore:ClearAsyncHandler()
        return
    end

    ClientDataManagerInst:SetBool(SNSUtils.NORMAL_TAB_READ, true, false, SNSUtils.SNS_CATEGORY)
    Notify(MessageConst.ON_SNS_BARKER_TAB_READ_STATE_CHANGE)

    if not DeviceInfo.usingController then
        return
    end

    if self.m_curFocusNpcCellCSIndex < 0 then
        
        return
    end

    
    local npcCell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
    
    local subCell
    subCell = npcCell and npcCell.m_subDialogCellCache:Get(self.m_curFocusSubCellLuaIndex)

    if subCell then
        self:SetNaviTarget(subCell.view.button)
    elseif npcCell then
        self:SetNaviTarget(npcCell.view.foldOut)
    else
        self:ClearNaviTarget()
    end
    
    local phase = self.m_phase
    phase:ToggleBasicPanelCloseBtn(subCell == nil)
end



HL.Commit(SNSBarkerCtrl)
