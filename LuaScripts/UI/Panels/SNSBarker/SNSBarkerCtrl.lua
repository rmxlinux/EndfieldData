
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


SNSBarkerCtrl.m_chatVOs = HL.Field(HL.Table)


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

    self:_GenContactNpcVOs({})
    self:_RefreshContactNpcList()

    self:_RefreshContent()
    self:_RefreshNaviTarget()
    self:_InitController()
end











SNSBarkerCtrl.OnClickContactNpcCell = HL.Method(HL.Number) << function(self, csIndex)
    
    
    
    self.view.contactNpcScrollList:Toggle(csIndex, DeviceInfo.usingController)

    if DeviceInfo.usingController then
        
        local cell = self.m_getContactNpcCellFunc(LuaIndex(csIndex))
        
        local subCell = cell.m_subDialogCellCache:Get(1)
        UIUtils.setAsNaviTarget(subCell.view.button)

        self:_ToggleSubCellNavi(true)
    end
end






SNSBarkerCtrl.OnClickDialogCell = HL.Method(HL.String, HL.String, HL.Forward("SNSSubDialogCell"))
        << function(self, chatId, dialogId, subDialogCell)
    if self.m_curSelectedSubDialogId == dialogId then
        return
    end
    self.m_curSelectedSubDialogId = dialogId

    if self.m_curSelectedSubDialogCell then
        self.m_curSelectedSubDialogCell:SetSelected(false)
    end
    subDialogCell:SetSelected(true)
    self.m_curSelectedSubDialogCell = subDialogCell

    self:_RefreshContent()
end




SNSBarkerCtrl._InitData = HL.Method(HL.Opt(HL.Table)) << function(self, arg)
    local dialogId = arg and arg.dialogId
    if not string.isEmpty(dialogId) and Tables.sNSDialogTable:ContainsKey(dialogId) then
        self.m_curSelectedSubDialogId = dialogId
    end
end



SNSBarkerCtrl._RefreshContactNpcList = HL.Method() << function(self)
    local nonSelectSubDialog = string.isEmpty(self.m_curSelectedSubDialogId)
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

        
        if targetNpcCSIndex == nil then
            targetNpcCSIndex = 0
            self.m_curSelectedSubDialogId = ""
        end
    end

    local hasResult = #self.m_chatVOs > 0
    if hasResult then
        self.view.contactNpcScrollList:UpdateCount(#self.m_chatVOs, targetNpcCSIndex)
        self.view.contactNpcScrollList:FoldAll(false)
    end
    self.view.contactNpcScrollList.gameObject:SetActive(hasResult)
    self.view.nonResult.gameObject:SetActive(not hasResult)

    if not nonSelectSubDialog then
        self.view.contactNpcScrollList:Toggle(targetNpcCSIndex, true)
        
        local npcCell = self.m_getContactNpcCellFunc(LuaIndex(targetNpcCSIndex))
        npcCell:ToggleFoldOut()
    end
end





SNSBarkerCtrl._OnUpdateContactNpcCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local npcVO = self.m_chatVOs[LuaIndex(csIndex)]
    
    local content = self.m_getContactNpcCellFunc(go)
    content:InitSNSContactNpcCell(npcVO, false, function()
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




SNSBarkerCtrl._OnFilterConfirm = HL.Method(HL.Table) << function(self, selectedTags)
    selectedTags = selectedTags or {}
    self.m_cachedSelectedTags = selectedTags
    self.m_curSelectedSubDialogId = ""

    local hasFilter = #selectedTags > 0
    self.view.btnCommonFilter.normalNode.gameObject:SetActiveIfNecessary(not hasFilter)
    self.view.btnCommonFilter.existNode.gameObject:SetActiveIfNecessary(hasFilter)
    self.view.snsDialogContentCore:ClearAsyncHandler()

    self:_GenContactNpcVOs(selectedTags)
    self:_RefreshContactNpcList()
    self:_RefreshContent()

    self:_ManuallyResetControllerState()
    self:_RefreshNaviTarget()
end



SNSBarkerCtrl._OnBtnFilterClick = HL.Method() << function(self)
    self.m_filterArgs.selectedTags = self.m_cachedSelectedTags
    self:Notify(MessageConst.SHOW_COMMON_FILTER, self.m_filterArgs)
end



SNSBarkerCtrl.GetPanelType = HL.Method().Return(HL.Number) << function(self)
    return SNSUtils.PanelType.FullScreenPanel
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
        self.m_curFocusNpcCellCSIndex = 0
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
            UIUtils.setAsNaviTarget(cell.view.foldOut)
        else
            
            local subCell = cell.m_subDialogCellCache:Get(self.m_curFocusSubCellLuaIndex)
            UIUtils.setAsNaviTarget(subCell.view.button)
        end
    else
        UIUtils.setAsNaviTarget(nil)
    end
end



SNSBarkerCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.m_focusSubCellReturnToNpcCellBindId = self:BindInputPlayerAction("common_back", function()
        self.m_returnToNpcCellBindActionFlag = true

        
        local cell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
        UIUtils.setAsNaviTarget(cell.view.foldOut)

        self:_ToggleSubCellNavi(false)

        
    end)

    
    
    InputManagerInst:ToggleBinding(self.m_focusSubCellReturnToNpcCellBindId, not string.isEmpty(self.m_curSelectedSubDialogId))
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

    self.view.contactNpcScrollList:Toggle(self.m_curFocusNpcCellCSIndex, true)
    self.view.contactNpcScrollList:Toggle(nextFocusCellCSIndex, true)

    
    local preCell = self.m_getContactNpcCellFunc(LuaIndex(self.m_curFocusNpcCellCSIndex))
    preCell:ToggleFoldOut()

    
    local curCell = self.m_getContactNpcCellFunc(LuaIndex(nextFocusCellCSIndex))
    curCell:ToggleFoldOut()

    
    local firstSubCell = preCell.m_subDialogCellCache:Get(1)
    UIUtils.setAsNaviTarget(firstSubCell.view.button)

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
        UIUtils.setAsNaviTarget(subCell.view.button)
    else
        UIUtils.setAsNaviTarget(cell.view.foldOut)
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
        
        self.view.contactNpcScrollList:Toggle(preFocusNpcCellCSIndex, true)
        self.view.contactNpcScrollList:Toggle(csIndex, true)
        
        local preCell = self.m_getContactNpcCellFunc(LuaIndex(preFocusNpcCellCSIndex))
        preCell:ToggleFoldOut()

        
        local npcCell = self.m_getContactNpcCellFunc(LuaIndex(csIndex))
        npcCell:ToggleFoldOut()
        
        local subCell = npcCell.m_subDialogCellCache:Get(1)
        UIUtils.setAsNaviTarget(subCell.view.button)
    else
        
        if self.m_returnToNpcCellBindActionFlag then
            
            self.view.contactNpcScrollList:Toggle(preFocusNpcCellCSIndex, true)
            
            local preCell = self.m_getContactNpcCellFunc(LuaIndex(preFocusNpcCellCSIndex))
            preCell:ToggleFoldOut()
            self.m_returnToNpcCellBindActionFlag = false
        else
            
            local nextNpcCellCSIndex = preFocusNpcCellCSIndex - 1
            if nextNpcCellCSIndex >= 0 then
                self.view.contactNpcScrollList:Toggle(preFocusNpcCellCSIndex, true)
                self.view.contactNpcScrollList:Toggle(nextNpcCellCSIndex, true)
                
                local preCell = self.m_getContactNpcCellFunc(LuaIndex(preFocusNpcCellCSIndex))
                preCell:ToggleFoldOut()

                
                local npcCell = self.m_getContactNpcCellFunc(LuaIndex(nextNpcCellCSIndex))
                npcCell:ToggleFoldOut()
                
                local subCellCache = npcCell.m_subDialogCellCache
                
                local subCell = subCellCache:Get(subCellCache:GetCount())
                UIUtils.setAsNaviTarget(subCell.view.button)

                
                self.m_curFocusNpcCellCSIndex = nextNpcCellCSIndex
            else
                
                
                local npcCell = self.m_getContactNpcCellFunc(LuaIndex(preFocusNpcCellCSIndex))
                
                local subCell = npcCell.m_subDialogCellCache:Get(1)
                UIUtils.setAsNaviTarget(subCell.view.button)
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

    ClientDataManagerInst:SetBool(SNSUtils.NORMAL_TAB_READ, true, false, SNSUtils.SNS_CATEGORY, true)
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
        UIUtils.setAsNaviTarget(subCell.view.button)
    elseif npcCell then
        UIUtils.setAsNaviTarget(npcCell.view.foldOut)
    else
        UIUtils.setAsNaviTarget(nil)
    end
    
    local phase = self.m_phase
    phase:ToggleBasicPanelCloseBtn(subCell == nil)
end



HL.Commit(SNSBarkerCtrl)
