local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')
local PANEL_ID = PanelId.CardGameBlackjackOpenCardPack
local POKER_CELL_POPUP_IN_ANI_NAME = "pokercell_cardpopup_in"

local PERFORM_BLOCK_KEY = "CardGameBlackjackOpenCardPack.Perform"

CardGameBlackjackOpenCardPackCtrl = HL.Class('CardGameBlackjackOpenCardPackCtrl', uiCtrl.UICtrl)







CardGameBlackjackOpenCardPackCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


CardGameBlackjackOpenCardPackCtrl.m_arg = HL.Field(HL.Table)
CardGameBlackjackOpenCardPackCtrl.m_pokerCellCache = HL.Field(HL.Forward("UIListCache"))
CardGameBlackjackOpenCardPackCtrl.curSelectPokerIndexSet = HL.Field(HL.Table)
CardGameBlackjackOpenCardPackCtrl.m_animQueue = HL.Field(CardGameAnimQueue)
CardGameBlackjackOpenCardPackCtrl.m_isPerformBlocking = HL.Field(HL.Boolean) << false




CardGameBlackjackOpenCardPackCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = LuaSystemManager.cardGameBlackjackSystem:BuildGainCardView() or {}
    if UNITY_EDITOR then
        if arg ~= nil then
            self.m_arg = arg
        end
    end
    self:_InitUI()
    local selectedIndexes = self.m_arg.selectedIndexes or {}
    for i = 1, #selectedIndexes do
        self.curSelectPokerIndexSet[selectedIndexes[i]] = true
    end
    if self.m_arg.pokerInfo ~= nil then
        self:RefreshAllUI(self.m_arg)
    end
    self:_HideShopMain()
    self:PlayPokerCellAni()
end



CardGameBlackjackOpenCardPackCtrl.OnClose = HL.Override() << function(self)
    if self.m_animQueue then
        self.m_animQueue:Clear(true, false)
    end
    
    self:_SetPerformBlock(false)
end

CardGameBlackjackOpenCardPackCtrl._InitUI = HL.Method() << function(self)
    self.m_pokerCellCache = UIUtils.genCellCache(self.view.pokerCell)
    self.curSelectPokerIndexSet = {}
    self.m_animQueue = CardGameAnimQueue()
end

CardGameBlackjackOpenCardPackCtrl.RefreshAllUI = HL.Method(HL.Any) << function(self, arg)
    self.m_pokerCellCache:Refresh(#arg.pokerInfo, function(cell, index)
        self:RefreshPokerCell(cell, arg.pokerInfo[index], index)
    end)
    self.view.descTxt.text = arg.desc
    if not string.isEmpty(arg.cardPackIcon) then
        self.view.cardPackImg:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_CARD_PACK, arg.cardPackIcon)
    end
end

CardGameBlackjackOpenCardPackCtrl.RefreshPokerCell = HL.Method(HL.Any, HL.Any, HL.Number) << function(self, cell, arg, cellIndex)
    cell.poker:SetCardSuitRankStyle(arg.suit, arg.rank, arg.style)
    CardGameBlackjackUtils.SetPokerCellSelectState(cell, self.curSelectPokerIndexSet[cellIndex] == true, false)
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        if self.curSelectPokerIndexSet[cellIndex] == true then
            
            self.curSelectPokerIndexSet[cellIndex] = nil
            CardGameBlackjackUtils.SetPokerCellSelectState(cell, false, true)
            LuaSystemManager.cardGameBlackjackSystem:_OnGainCardSelectCard(cellIndex, false)
            return
        end
        
        if self.m_arg.maxSelectNum <= 1 then
            for oldIndex in pairs(self.curSelectPokerIndexSet) do
                self.curSelectPokerIndexSet[oldIndex] = nil
                local oldCell = self.m_pokerCellCache:Get(oldIndex)
                if oldCell then
                    CardGameBlackjackUtils.SetPokerCellSelectState(oldCell, false, true)
                end
                LuaSystemManager.cardGameBlackjackSystem:_OnGainCardSelectCard(oldIndex, false)
            end
        end
        
        self.curSelectPokerIndexSet[cellIndex] = true
        CardGameBlackjackUtils.SetPokerCellSelectState(cell, true, true)
        LuaSystemManager.cardGameBlackjackSystem:_OnGainCardSelectCard(cellIndex, true)
    end)
end




CardGameBlackjackOpenCardPackCtrl._HideShopMain = HL.Method() << function(self)
    self:_SetPerformBlock(true)
    local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if not isOpen or shopMainCtrl.animationWrapper == nil then
        return
    end
    shopMainCtrl.animationWrapper:SampleToOutAnimationEnd()
end


CardGameBlackjackOpenCardPackCtrl._RestoreShopMain = HL.Method() << function(self)
    local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if not isOpen or shopMainCtrl.animationWrapper == nil or shopMainCtrl:IsPlayingAnimationOut() then
        return
    end
    shopMainCtrl.animationWrapper:SampleToInAnimationEnd()
end


CardGameBlackjackOpenCardPackCtrl._SetPerformBlock = HL.Method(HL.Boolean) << function(self, isBlock)
    if self.m_isPerformBlocking == isBlock then
        return
    end
    self.m_isPerformBlocking = isBlock
    LuaSystemManager.inputDeviceChangeSystem:SetForbidInputDeviceChange(PERFORM_BLOCK_KEY, isBlock)
    local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
    if isBlock then
        self.view.luaPanel:BlockAllInput(PERFORM_BLOCK_KEY)
        if isOpen then
            shopMainCtrl.view.luaPanel:BlockAllInput(PERFORM_BLOCK_KEY)
        end
    else
        self.view.luaPanel:RecoverAllInput(PERFORM_BLOCK_KEY)
        if isOpen then
            shopMainCtrl.view.luaPanel:RecoverAllInput(PERFORM_BLOCK_KEY)
        end
    end
end


CardGameBlackjackOpenCardPackCtrl.PlayPokerCellAni = HL.Method() << function(self)
    local queue = self.m_animQueue
    local config = self.view.config
    self:_MovePokerCellAniRootToListCenter()
    queue:Enqueue(function(finish)
        self:_WaitAni(config.START_CELL_ANI_TIME, finish)
    end)
    queue:Enqueue(function(finish)
        self:_PlayPokerCellPopupInAni(finish)
    end)
    queue:Enqueue(function(finish)
        self:_PlayPokerCellMoveAni(config.CELL_MOVE_ANI_TIME, config.CELL_MOVE_ANI_CURVE, finish)
    end)
    
    queue:EnqueueOnlyInterruptAction(function()
        self:_RestoreShopMain()
    end)
    queue:Enqueue(function(finish)
        local isOpen, shopMainCtrl = UIManager:IsOpen(PanelId.CardGameBlackjackShopMain)
        if not isOpen or shopMainCtrl.animationWrapper == nil then
            finish()
            return
        end
        shopMainCtrl.animationWrapper:PlayInAnimation(finish)
    end)
    queue:EnqueueFinallyAction(function()
        self:_SetPerformBlock(false)
        local cell = self.m_pokerCellCache:Get(1)
        if cell then
            self:SetNaviTarget(cell.naviDeco)
        end
    end)
end



CardGameBlackjackOpenCardPackCtrl._MovePokerCellAniRootToListCenter = HL.Method() << function(self)
    local pokerList = self.view.pokerList
    LayoutRebuilder.ForceRebuildLayoutImmediate(pokerList)
    local listCenter = pokerList.rect.center
    local centerWorldPos = pokerList:TransformPoint(listCenter.x, listCenter.y, 0)
    local cache = self.m_pokerCellCache
    for i = 1, cache:GetCount() do
        local cell = cache:Get(i)
        local aniRoot = cell.aniRoot
        if cell.temp_aniRootRestPos == nil then
            cell.temp_aniRootRestPos = aniRoot.localPosition
        end
        local localPos = aniRoot.parent:InverseTransformPoint(centerWorldPos)
        aniRoot.localPosition = Vector3(localPos.x, localPos.y, 0)
        
        cell.animationWrapper:SampleClipAtPercent(POKER_CELL_POPUP_IN_ANI_NAME, 0)
    end
end

CardGameBlackjackOpenCardPackCtrl._WaitAni = HL.Method(HL.Number, HL.Function) << function(self, duration, nextFn)
    if duration <= 0 then
        nextFn()
        return
    end
    local elapsed = 0
    local updateKey = -1
    updateKey = self:_StartUpdate(function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < duration then
            return
        end
        self:_RemoveUpdate(updateKey)
        nextFn()
    end)
end


CardGameBlackjackOpenCardPackCtrl._PlayPokerCellPopupInAni = HL.Method(HL.Function) << function(self, finish)
    local cache = self.m_pokerCellCache
    local count = cache:GetCount()
    if count <= 0 then
        finish()
        return
    end
    for i = 1, count do
        cache:Get(i).animationWrapper:Play(POKER_CELL_POPUP_IN_ANI_NAME, i == 1 and finish or nil)
    end
end


CardGameBlackjackOpenCardPackCtrl._PlayPokerCellMoveAni = HL.Method(HL.Number, CS.UnityEngine.AnimationCurve, HL.Function)
        << function(self, duration, curve, finish)
    local cache = self.m_pokerCellCache
    local items = {}
    for i = 1, cache:GetCount() do
        local aniRoot = cache:Get(i).aniRoot
        items[i] = {
            aniRoot = aniRoot,
            startPos = aniRoot.localPosition,
        }
    end
    local function applyRatio(ratio)
        for i = 1, #items do
            local item = items[i]
            local startPos = item.startPos
            local k = 1 - ratio
            item.aniRoot.localPosition = Vector3(startPos.x * k, startPos.y * k, 0)
        end
    end
    if duration <= 0 or #items <= 0 then
        applyRatio(1)
        finish()
        return
    end
    local elapsed = 0
    local updateKey = -1
    updateKey = self:_StartUpdate(function(deltaTime)
        elapsed = elapsed + deltaTime
        local t = math.min(elapsed / duration, 1)
        if t >= 1 then
            self:_RemoveUpdate(updateKey)
            applyRatio(1)
            finish()
            return
        end
        applyRatio(curve:Evaluate(t))
    end)
end


HL.Commit(CardGameBlackjackOpenCardPackCtrl)
