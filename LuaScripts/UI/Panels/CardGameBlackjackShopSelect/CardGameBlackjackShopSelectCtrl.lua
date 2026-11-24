local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackShopSelect

CardGameBlackjackShopSelectCtrl = HL.Class('CardGameBlackjackShopSelectCtrl', uiCtrl.UICtrl)







CardGameBlackjackShopSelectCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_MEMBER_INFO_UPDATE] = '_OnPlayRoomMemberInfoUpdate',
    [MessageConst.ON_MULTIPLAYER_PLAY_ROOM_INFO_CHANGED] = '_OnPlayRoomInfoChanged',
}




CardGameBlackjackShopSelectCtrl.m_arg = HL.Field(HL.Table)

CardGameBlackjackShopSelectCtrl.m_itemCells = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopSelectCtrl.m_playerCellCache = HL.Field(HL.Forward("UIListCache"))

CardGameBlackjackShopSelectCtrl.m_naviItemIndex = HL.Field(HL.Number) << 0





CardGameBlackjackShopSelectCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = LuaSystemManager.cardGameBlackjackSystem:BuildShopSelectView() or {}
    self.view.itemScrollListStateCtrl:SetState(self.m_arg.isChooseInitRelic and "ChooseInitRelic" or "Shop")
    self:_InitUI()
    self:_RefreshItemList(self.m_arg.selectedIndex or 0)
    self:_RefreshPlayerList()
    UIUtils.bindHyperlinkPopup(self, "BlackjackRelic", self.view.inputGroup.groupId)
    if not self.m_arg.isChooseInitRelic and not PhaseManager.isRecovering then
        CardGameBlackjackUtils.TriggerPhaseEventForGuide(CS.Beyond.Gameplay.Conditions.OnCardGameBlackjackPhaseEventForGuide.BlackjackPhaseEventTypeForGuide.ShopPhaseStart)
    end
end

CardGameBlackjackShopSelectCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local entry = LuaSystemManager.cardGameBlackjackSystem:GetShopUIChoose()
    local selectedIndex = entry ~= nil and entry.ui.selectedIndex or 0
    local itemCell = self.m_itemCells:Get(selectedIndex > 0 and selectedIndex or 1)
    if itemCell then
        self:SetNaviTarget(itemCell.view.naviDeco)
    end
end



CardGameBlackjackShopSelectCtrl._InitUI = HL.Method() << function(self)
    self.m_itemCells = UIUtils.genCellCache(self.view.itemCell)
    self.m_playerCellCache = UIUtils.genCellCache(self.view.playerCell)
    self.view.playerCell.emojiNode:Clear()
    self.view.emojiPopupBtn.button.onClick:AddListener(function()
        self:OnClickEmojiPopupBtn()
    end)
    local system = LuaSystemManager.cardGameBlackjackSystem
    local emojiArg = {
        roomStrId = system:GetEmojiRoomStrId(),
        onEmojiSent = function()
            self:HideEmojiPopup()
            system:StartEmojiCd()
        end,
        onActiveChanged = function(active)
            if active then
                self:_PrepareEmojiFocusBlock()
            else
                self:SetEmojiCdState(system:IsEmojiInCd())
            end
        end,
    }
    self.view.emojiPopupNode:InitMultiplayerEmojiNode(emojiArg)
    self:HideEmojiPopup()
end

CardGameBlackjackShopSelectCtrl.InitItemCell = HL.Method(HL.Any, HL.Any) << function(self, cell, arg)
    
    if arg.isRelic then
        cell:InitShopItemRelic(arg)
    else
        cell:InitShopItemCardPack(arg)
    end
end

CardGameBlackjackShopSelectCtrl.GetItemCell = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, cellIndex)
    return self.m_itemCells:Get(cellIndex)
end

CardGameBlackjackShopSelectCtrl.GetNaviTargetItemIndex = HL.Method().Return(HL.Number) << function(self)
    return self.m_naviItemIndex
end




CardGameBlackjackShopSelectCtrl.RefreshItemList = HL.Method(HL.Table, HL.Number, HL.Opt(HL.Boolean))
        << function(self, items, selectedIndex, isRefreshShop)
    self.m_arg.items = items
    self:_RefreshItemList(selectedIndex, isRefreshShop)
end



CardGameBlackjackShopSelectCtrl.RefreshItemCell = HL.Method(HL.Number, HL.Table, HL.Boolean)
        << function(self, index, item, isSelected)
    self.m_arg.items[index] = item

    local cell = self.m_itemCells:Get(index)
    if cell == nil then
        return
    end
    self:_BindItemCallbacks(index, item)
    self:InitItemCell(cell, item)
    cell:SetSelectState(isSelected)
    cell:PlayRefreshAni()
    cell:ResetInfoScroll()
end




CardGameBlackjackShopSelectCtrl._RefreshItemList = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, selectedIndex, isRefreshShop)
    local items = self.m_arg.items or {}

    self.m_itemCells:Refresh(#items, function(cell, index)
        local item = items[index]
        cell.gameObject.name = string.format("GuideShopItem_%d", index)
        self:_BindItemCallbacks(index, item)
        self:InitItemCell(cell, item)
        cell:SetSelectState(index == selectedIndex)
        
        if item.isEmpty then
            cell:SetEmptyState(true)
        end
        if isRefreshShop and not item.isPin then
            cell:PlayRefreshAni()
            cell:ResetInfoScroll()
        end
    end)
end



CardGameBlackjackShopSelectCtrl._BindItemCallbacks = HL.Method(HL.Number, HL.Table) << function(self, index, item)
    local system = LuaSystemManager.cardGameBlackjackSystem
    item.onClickItem = function(isSelect)
        
        if isSelect == true then
            self.m_naviItemIndex = index
        elseif isSelect == false and self.m_naviItemIndex == index then
            self.m_naviItemIndex = 0
        end
        system:OnShopItemSelect(index, isSelect)
    end
    item.onClickBuy = function()
        system:OnShopItemBuy(index)
    end
    item.onClickRefresh = function()
        system:OnShopItemRefresh(index)
    end
    item.onClickPin = function()
        system:OnShopItemPin(index)
    end
end





CardGameBlackjackShopSelectCtrl.RefreshPlayerState = HL.Method(HL.Number, HL.String) << function(self, seatIndex, state)
    local playerInfo = self.m_arg.playerInfos and self.m_arg.playerInfos[seatIndex] or nil
    if playerInfo ~= nil then
        playerInfo.state = state
    end
    local cell = self.m_playerCellCache:Get(seatIndex)
    if cell ~= nil then
        cell.stateController:SetState(state)
    end
end

CardGameBlackjackShopSelectCtrl._RefreshPlayerList = HL.Method() << function(self)
    local playerInfos = self.m_arg.playerInfos or {}
    self.m_playerCellCache:Refresh(#playerInfos, function(cell, index)
        local playerInfo = playerInfos[index]
        
        cell.stateController:SetState(playerInfo.state)
        cell.emojiNode:Clear()
        CardGameUtils.InitCommonPlayerHead(cell.playerHead, playerInfo)
        self:_RefreshPlayerFlag(cell, playerInfo)
        
        cell.stateController:SetState(FriendUtils.isPsnPlatform() and "IsPS" or "NoPS")
    end)
end

CardGameBlackjackShopSelectCtrl._RefreshPlayerFlag = HL.Method(HL.Any, HL.Table) << function(self, cell, playerInfo)
    if playerInfo.isSelf then
        cell.stateController:SetState("SelfFlag")
    elseif CardGameUtils.IsMemberShowAI(playerInfo.memberId) then
        cell.stateController:SetState("AiFlag")
    else
        cell.stateController:SetState("NoFlag")
    end
end

CardGameBlackjackShopSelectCtrl._OnPlayRoomMemberInfoUpdate = HL.Method(HL.Table) << function(self, arg)
    local memberId = unpack(arg)
    for index, playerInfo in ipairs(self.m_arg.playerInfos or {}) do
        if playerInfo.memberId == memberId then
            self:_RefreshPlayerFlag(self.m_playerCellCache:Get(index), playerInfo)
            return
        end
    end
end


CardGameBlackjackShopSelectCtrl._OnPlayRoomInfoChanged = HL.Method() << function(self)
    for index, playerInfo in ipairs(self.m_arg.playerInfos or {}) do
        self:_RefreshPlayerFlag(self.m_playerCellCache:Get(index), playerInfo)
    end
end



CardGameBlackjackShopSelectCtrl.OnClickEmojiPopupBtn = HL.Method() << function(self)
    if LuaSystemManager.cardGameBlackjackSystem:IsEmojiInCd() then
        return
    end

    local isShow = self.view.emojiPopupNode.gameObject.activeSelf
    if isShow then
        self:HideEmojiPopup()
    else
        self:ShowEmojiPopup()
    end
end

CardGameBlackjackShopSelectCtrl.ShowEmojiPopup = HL.Method() << function(self)
    self.view.emojiPopupNode:SetEmojiNodeActive(true)
    self.view.emojiPopupBtn.nodeState:SetState("Click")
end

CardGameBlackjackShopSelectCtrl.HideEmojiPopup = HL.Method() << function(self)
    self.view.emojiPopupNode:SetEmojiNodeActive(false)
    self.view.emojiPopupBtn.nodeState:SetState("Normal")
end




CardGameBlackjackShopSelectCtrl._PrepareEmojiFocusBlock = HL.Method() << function(self)
    local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if not isOpen then
        return
    end
    self.view.emojiPopupNode.view.selectableNaviGroup.focusPanelSortingOrder = shopMainCtrl:GetSortingOrder() + 5
    self.view.controllerHintPlaceholder = shopMainCtrl.view.controllerHintPlaceholder
end

CardGameBlackjackShopSelectCtrl.SetEmojiCdState = HL.Method(HL.Boolean) << function(self, inCd)
    self.view.emojiPopupBtn.nodeState:SetState(inCd and "Time" or "Normal")
    self.view.emojiPopupBtn.button.interactable = not inCd
end

CardGameBlackjackShopSelectCtrl.RefreshEmojiCd = HL.Method(HL.Number) << function(self, cdTime)
    self.view.emojiPopupBtn.numTxt.text = string.format("%ds", math.ceil(cdTime))
end


CardGameBlackjackShopSelectCtrl.PlayEmojiBySeatIndex = HL.Method(HL.Number, HL.String, HL.Opt(HL.String))
    << function(self, seatIndex, emojiId, charId)
    local cell = self.m_playerCellCache:Get(seatIndex)
    if not cell then
        return
    end
    cell.emojiNode:Init(emojiId)
    cell.emojiNode:Play(charId)
end


HL.Commit(CardGameBlackjackShopSelectCtrl)
