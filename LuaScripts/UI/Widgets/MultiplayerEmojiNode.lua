local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local TAB_STATE_NORMAL = "Normal"
local TAB_STATE_SELECT = "Select"
local NAVI_DIRECTION = CS.UnityEngine.UI.NaviDirection


MultiplayerEmojiNode = HL.Class('MultiplayerEmojiNode', UIWidgetBase)

MultiplayerEmojiNode.m_roomStrId = HL.Field(HL.String) << ""
MultiplayerEmojiNode.m_onEmojiSent = HL.Field(HL.Function)
MultiplayerEmojiNode.m_onActiveChanged = HL.Field(HL.Function)
MultiplayerEmojiNode.m_tabList = HL.Field(HL.Table)
MultiplayerEmojiNode.m_emojiList = HL.Field(HL.Table)
MultiplayerEmojiNode.m_selectedTabId = HL.Field(HL.String) << ""
MultiplayerEmojiNode.m_getTabCell = HL.Field(HL.Function)
MultiplayerEmojiNode.m_getEmojiCell = HL.Field(HL.Function)
MultiplayerEmojiNode.m_onEmojiClick = HL.Field(HL.Function)

MultiplayerEmojiNode._OnFirstTimeInit = HL.Override() << function(self)
    self:_RefreshBlockRaycastMask()
    self:RegisterMessage(MessageConst.ON_UI_CANVAS_SIZE_CHANGED, function()
        if self.gameObject.activeInHierarchy then
            self:_RefreshBlockRaycastMask()
        end
    end)

    self.view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        self:SetEmojiNodeActive(false)
    end)

    self.m_onEmojiClick = function(emojiId)
        self:_OnEmojiClick(emojiId)
    end

    self.m_getTabCell = UIUtils.genCachedCellFunction(self.view.tabScrollList)
    self.view.tabScrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateTabCell(self.m_getTabCell(object), LuaIndex(csIndex))
    end)

    self.m_getEmojiCell = UIUtils.genCachedCellFunction(self.view.emojiScrollList)
    self.view.emojiScrollList.onUpdateCell:AddListener(function(object, csIndex)
        self:_OnUpdateEmojiCell(self.m_getEmojiCell(object), LuaIndex(csIndex))
    end)

    self.view.selectableNaviGroup.getDefaultSelectableFunc = function()
        self.view.emojiScrollList:ScrollToIndex(0, true)
        return self.m_getEmojiCell(1).view.clickBtn
    end
    self.view.selectableNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            self:SetEmojiNodeActive(false)
        end
    end)

    self:_BuildTabList()
    if self.m_tabList and #self.m_tabList > 0 then
        self:_SelectTab(self.m_tabList[1].emojiTabId, true)
    else
        self.view.tabScrollList:UpdateCount(0)
        self.view.emojiScrollList:UpdateCount(0)
    end
end




MultiplayerEmojiNode.InitMultiplayerEmojiNode = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    args = args or {}
    self.m_roomStrId = args.roomStrId or ""
    self.m_onEmojiSent = args.onEmojiSent
    self.m_onActiveChanged = args.onActiveChanged
    self:_FirstTimeInit()
end

MultiplayerEmojiNode.GetRecoverState = HL.Method().Return(HL.Table) << function(self)
    return {
        isOpen = self.gameObject.activeSelf
            and self.view.animationWrapper.curState ~= CS.Beyond.UI.UIConst.AnimationState.Out,
        selectedTabId = self.m_selectedTabId,
    }
end

MultiplayerEmojiNode.RecoverState = HL.Method(HL.Opt(HL.Table)) << function(self, recoverState)
    if recoverState == nil then
        return
    end
    for _, tab in ipairs(self.m_tabList) do
        if tab.emojiTabId == recoverState.selectedTabId then
            self:_SelectTab(tab.emojiTabId)
            break
        end
    end
    if recoverState.isOpen then
        self:SetEmojiNodeActive(true)
        self.view.animationWrapper:SkipInAnimation()
    end
end

MultiplayerEmojiNode.SetEmojiNodeActive = HL.Method(HL.Boolean) << function(self, active)
    local animationWrapper = self.view.animationWrapper
    local isClosing = animationWrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out
    if self.gameObject.activeSelf == active and not isClosing then
        return
    end

    if active then
        
        if not self.gameObject.activeSelf and self.m_onActiveChanged ~= nil then
            self.m_onActiveChanged(true)
        end

        
        animationWrapper:ClearTween(false)
        
        MultiplayerUtils.setRedDotRead("MultiplayerEmojiTab", self.m_selectedTabId)
        self.gameObject:SetActiveIfNecessary(true)
        animationWrapper:PlayInAnimation()
        self.view.emojiScrollList:UpdateCount(#self.m_emojiList, true)
        if DeviceInfo.usingController then
            self.view.selectableNaviGroup:ManuallyFocus()
        end
    elseif not isClosing then
        animationWrapper:PlayOutAnimation(function()
            self:_HideEmojiNode()
        end)
    end
end

MultiplayerEmojiNode._HideEmojiNode = HL.Method() << function(self)
    self.gameObject:SetActiveIfNecessary(false)
    self.view.selectableNaviGroup:ManuallyStopFocus()
    if self.m_onActiveChanged ~= nil then
        self.m_onActiveChanged(false)
    end
end

MultiplayerEmojiNode._OnEnable = HL.Override() << function(self)
    if not self.m_isFirstTimeInit then
        self:_RefreshBlockRaycastMask()
    end
end

MultiplayerEmojiNode._RefreshBlockRaycastMask = HL.Method() << function(self)
    local maskRect = self.view.blockRaycastMask
    local canvas = maskRect:GetComponentInParent(typeof(Unity.Canvas), true).rootCanvas
    local uiCamera
    if canvas.renderMode ~= Unity.RenderMode.ScreenSpaceOverlay then
        uiCamera = canvas.worldCamera
    end
    
    local screenCorners = {
        Vector2.zero, Vector2(Screen.width, 0),
        Vector2(0, Screen.height), Vector2(Screen.width, Screen.height),
    }
    local minPos = Vector2(math.huge, math.huge)
    local maxPos = Vector2(-math.huge, -math.huge)
    for _, screenPos in ipairs(screenCorners) do
        local localPos = UIUtils.screenPointToUI(screenPos, uiCamera, maskRect.parent)
        minPos = Vector2.Min(minPos, localPos)
        maxPos = Vector2.Max(maxPos, localPos)
    end
    local center = (minPos + maxPos) * 0.5
    maskRect.sizeDelta = maxPos - minPos
    maskRect.localPosition = Vector3(center.x, center.y, 0)
end

MultiplayerEmojiNode._OnDisable = HL.Override() << function(self)
    
    if self.gameObject.activeSelf then
        self.view.animationWrapper:ClearTween(false)
        self:_HideEmojiNode()
    end
end

MultiplayerEmojiNode._BuildTabList = HL.Method() << function(self)
    local tabs = {}
    for _, data in pairs(Tables.multiplayerEmojiTabTable) do
        table.insert(tabs, data)
    end
    table.sort(tabs, function(a, b)
        return (a.sortId or 0) < (b.sortId or 0)
    end)
    self.m_tabList = tabs
end

MultiplayerEmojiNode._SelectTab = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, tabId, force)
    if not force and tabId == self.m_selectedTabId then
        return
    end

    self.m_selectedTabId = tabId
    self.view.tabScrollList:UpdateCount(#self.m_tabList)
    self:_RefreshEmojiList()
end

MultiplayerEmojiNode._RefreshEmojiList = HL.Method() << function(self)
    local list = {}
    local found, tabData = Tables.multiplayerEmojiTabTable:TryGetValue(self.m_selectedTabId)
    if found and tabData ~= nil and tabData.emojiIds ~= nil then
        for i = 0, tabData.emojiIds.Count - 1 do
            local emojiId = tabData.emojiIds[i]
            if not string.isEmpty(emojiId) then
                local infoFound, info = Tables.multiplayerEmojiInfoTable:TryGetValue(emojiId)
                if infoFound and info ~= nil then
                    table.insert(list, info)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.sortId or 0) < (b.sortId or 0)
    end)
    self.m_emojiList = list
    self.view.emojiScrollList:UpdateCount(#list)
end

MultiplayerEmojiNode._OnUpdateTabCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local data = self.m_tabList[luaIndex]
    if data == nil then
        return
    end

    if cell.tabTxt then
        cell.tabTxt.text = data.emojiTabName or ""
    end
    cell.nodeState:SetState(data.emojiTabId == self.m_selectedTabId and TAB_STATE_SELECT or TAB_STATE_NORMAL)
    cell.redDot:InitRedDot("MultiplayerEmojiTab", data.emojiTabId)
    cell.clickBtn.onClick:RemoveAllListeners()
    cell.clickBtn.onClick:AddListener(function()
        MultiplayerUtils.setRedDotRead("MultiplayerEmojiTab", data.emojiTabId)
        self:_SelectTab(data.emojiTabId)
    end)
end

MultiplayerEmojiNode._OnUpdateEmojiCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local info = self.m_emojiList[luaIndex]
    if info == nil then
        return
    end

    cell:Init(info.emojiId)
    local currentIndex = luaIndex
    local currentButton = cell.view.clickBtn
    
    currentButton.customNaviTargetInDirFunc = function(dir)
        return self:_GetEmojiNaviTarget(currentIndex, currentButton, dir)
    end
    cell:EnableClick(self.m_onEmojiClick)
end

MultiplayerEmojiNode._GetEmojiNaviTarget = HL.Method(HL.Number, CS.Beyond.UI.UIButton, HL.Any)
        .Return(HL.Any) << function(self, currentIndex, currentButton, dir)
    local countPerLine = self.view.emojiScrollList.countPerLine
    local targetIndex = currentIndex
    local columnIndex = (currentIndex - 1) % countPerLine
    if dir == NAVI_DIRECTION.Left then
        if columnIndex > 0 then
            targetIndex = currentIndex - 1
        end
    elseif dir == NAVI_DIRECTION.Right then
        if columnIndex < countPerLine - 1 and currentIndex < #self.m_emojiList then
            targetIndex = currentIndex + 1
        end
    elseif dir == NAVI_DIRECTION.Up then
        if currentIndex > countPerLine then
            targetIndex = currentIndex - countPerLine
        end
    elseif dir == NAVI_DIRECTION.Down then
        if currentIndex + countPerLine <= #self.m_emojiList then
            targetIndex = currentIndex + countPerLine
        end
    end
    if targetIndex == currentIndex then
        return currentButton
    end

    return self.m_getEmojiCell(targetIndex).view.clickBtn
end

MultiplayerEmojiNode._OnEmojiClick = HL.Method(HL.String) << function(self, emojiId)
    if self.view.animationWrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
        return
    end

    
    if string.isEmpty(self.m_roomStrId) then
        return
    end
    GameInstance.player.multiplayerGameCenterSystem:SendEmoji(self.m_roomStrId, emojiId)
    self:SetEmojiNodeActive(false)
    if self.m_onEmojiSent ~= nil then
        self.m_onEmojiSent()
    end
end

HL.Commit(MultiplayerEmojiNode)
return MultiplayerEmojiNode
