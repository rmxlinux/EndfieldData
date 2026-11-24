local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameBlackjackShopChangeCard
local POKER_CELL_MAX = 7

CardGameBlackjackShopChangeCardCtrl = HL.Class('CardGameBlackjackShopChangeCardCtrl', uiCtrl.UICtrl)







CardGameBlackjackShopChangeCardCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CardGameBlackjackShopChangeCardCtrl.m_arg = HL.Field(HL.Table)
CardGameBlackjackShopChangeCardCtrl.m_pokerCellList = HL.Field(HL.Table)
CardGameBlackjackShopChangeCardCtrl.m_changeTypeCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackShopChangeCardCtrl.curSelectTypeIndex = HL.Field(HL.Number) << 1
CardGameBlackjackShopChangeCardCtrl.curSelectPokerIndex = HL.Field(HL.Number) << 0




CardGameBlackjackShopChangeCardCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = LuaSystemManager.cardGameBlackjackSystem:BuildChangeCardView() or {}
    self.curSelectTypeIndex = self.m_arg.selectedEffectIndex or 1
    self.curSelectPokerIndex = self.m_arg.selectedCardIndex or 0
    self:_InitUI()
    if self.m_arg.changeTypeInfos ~= nil then
        self:RefreshAllUI(self.m_arg)
    end
end

CardGameBlackjackShopChangeCardCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local cell = self.m_pokerCellList[1]
    if cell and cell.gameObject.activeSelf then
        self:SetNaviTarget(cell.naviDeco)
    end
end

CardGameBlackjackShopChangeCardCtrl._InitUI = HL.Method() << function(self)
    self.m_pokerCellList = {}
    for i = 1, POKER_CELL_MAX do
        self.m_pokerCellList[i] = self.view.pokerList["pokerCell_" .. i]
    end
    self.m_changeTypeCellCache = UIUtils.genCellCache(self.view.changeTypeCell)
    if DeviceInfo.usingController then
        local preActionId = self.view.tabKeyHintPre.actionId
        local nextActionId = self.view.tabKeyHintNext.actionId
        self:BindInputPlayerAction(preActionId, function()
            self:_SwitchSelectChangeType(-1)
        end, self.view.inputGroup.groupId)
        self:BindInputPlayerAction(nextActionId, function()
            self:_SwitchSelectChangeType(1)
        end, self.view.inputGroup.groupId)
    end
end

CardGameBlackjackShopChangeCardCtrl.RefreshAllUI = HL.Method(HL.Any) << function(self, arg)
    self.m_changeTypeCellCache:Refresh(#arg.changeTypeInfos, function(cell, index)
        self:RefreshChangeTypeCellBasicInfo(cell, arg.changeTypeInfos[index], index)
    end)
    local pokerCount = #arg.pokerInfo
    if pokerCount > POKER_CELL_MAX then
        logger.error(string.format("CardGameBlackjackShopChangeCardCtrl.RefreshAllUI: pokerInfo count=%d exceeds max %d, extra ignored", pokerCount, POKER_CELL_MAX))
        pokerCount = POKER_CELL_MAX
    end
    self.view.pokerList.pokerCellLayer_2.gameObject:SetActive(pokerCount > 4)
    for i = 1, POKER_CELL_MAX do
        local cell = self.m_pokerCellList[i]
        local isShow = i <= pokerCount
        cell.gameObject:SetActive(isShow)
        if isShow then
            self:RefreshPokerCell(cell, arg.pokerInfo[i], i)
        end
    end
    self:RefreshInfoNode(arg.changeTypeInfos[self.curSelectTypeIndex])
    CardGameBlackjackUtils.SetCardDeckSuitCountTxt(self.view.cardDeckSuitCountTxt)
end



CardGameBlackjackShopChangeCardCtrl.RefreshPokerCell = HL.Method(HL.Any, HL.Any, HL.Number) << function(self, cell, arg, cellIndex)
    cell.poker:SetCardSuitRankStyle(arg.suit, arg.rank, arg.style)
    CardGameBlackjackUtils.SetPokerCellSelectState(cell, cellIndex == self.curSelectPokerIndex, false)
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        if self.curSelectPokerIndex == cellIndex then
            
            self.curSelectPokerIndex = 0
            CardGameBlackjackUtils.SetPokerCellSelectState(cell, false, true)
            LuaSystemManager.cardGameBlackjackSystem:_OnChangeCardSelectCard(0)
            return
        end
        
        local oldCell = self.m_pokerCellList[self.curSelectPokerIndex]
        if oldCell then
            CardGameBlackjackUtils.SetPokerCellSelectState(oldCell, false, true)
        end
        self.curSelectPokerIndex = cellIndex
        CardGameBlackjackUtils.SetPokerCellSelectState(cell, true, true)
        LuaSystemManager.cardGameBlackjackSystem:_OnChangeCardSelectCard(cellIndex)
    end)
end




CardGameBlackjackShopChangeCardCtrl.RefreshInfoNode = HL.Method(HL.Any) << function(self, arg)
    local infoNode = self.view.infoNode
    infoNode.changeTypeIcon:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_CHANGE, arg.icon)
    infoNode.changeTypeNameTxt.text = arg.name
    infoNode.changeTypeDescTxt.text = arg.desc
end

CardGameBlackjackShopChangeCardCtrl.RefreshChangeTypeCellBasicInfo = HL.Method(HL.Any, HL.Any, HL.Number) << function(self, cell, arg, cellIndex)
    cell.iconImg1:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_CHANGE, arg.icon)
    cell.iconImg2:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_CHANGE, arg.icon)
    cell.nameTxt1.text = arg.name
    cell.nameTxt2.text = arg.name
    cell.stateController:SetState(cellIndex == self.curSelectTypeIndex and "Select" or "Unselect")
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self:_SelectChangeType(cellIndex)
    end)
end


CardGameBlackjackShopChangeCardCtrl._SwitchSelectChangeType = HL.Method(HL.Number) << function(self, offset)
    local count = self.m_changeTypeCellCache:GetCount()
    if count <= 0 then
        return
    end
    local newIndex = (CSIndex(self.curSelectTypeIndex) + offset) % count + 1
    self:_SelectChangeType(newIndex)
end


CardGameBlackjackShopChangeCardCtrl._SelectChangeType = HL.Method(HL.Number) << function(self, cellIndex)
    if self.curSelectTypeIndex == cellIndex then
        return
    end
    local arg = self.m_arg.changeTypeInfos[cellIndex]
    if not arg then
        return
    end
    local oldCell = self.m_changeTypeCellCache:Get(self.curSelectTypeIndex)
    if oldCell then
        oldCell.stateController:SetState("Unselect")
    end
    self.curSelectTypeIndex = cellIndex
    local cell = self.m_changeTypeCellCache:Get(cellIndex)
    if cell then
        cell.stateController:SetState("Select")
    end
    self:RefreshInfoNode(arg)
    LuaSystemManager.cardGameBlackjackSystem:_OnChangeCardSelectEffect(cellIndex)
end


HL.Commit(CardGameBlackjackShopChangeCardCtrl)
