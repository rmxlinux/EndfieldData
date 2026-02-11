
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BattlePassWeaponCase





















BattlePassWeaponCaseCtrl = HL.Class('BattlePassWeaponCaseCtrl', uiCtrl.UICtrl)

local CellStateName = {
    Normal = 'Normal',
    Selected = 'Selected',
}






BattlePassWeaponCaseCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SC_OPEN_USABLE_ITEM_CHEST] = '_OnOpenChest',
}








BattlePassWeaponCaseCtrl.m_arg = HL.Field(HL.Table)


BattlePassWeaponCaseCtrl.m_selectedRewardId = HL.Field(HL.Any)


BattlePassWeaponCaseCtrl.m_selectedCell = HL.Field(HL.Table)


BattlePassWeaponCaseCtrl.m_chestData = HL.Field(HL.Userdata)


BattlePassWeaponCaseCtrl.isAutoOpenWhenGet = HL.Field(HL.Boolean) << false


BattlePassWeaponCaseCtrl.m_isPreview = HL.Field(HL.Boolean) << false


BattlePassWeaponCaseCtrl.m_itemCellCache = HL.Field(HL.Forward("UIListCache"))



BattlePassWeaponCaseCtrl.OpenBPWeaponCase = HL.StaticMethod(HL.Any) << function(arg)
    local itemId, isPreview, isAutoOpenWhenGet, subTitle = unpack(arg)
    local luaArg = {
        itemId = itemId,
        isPreview = isPreview,
        isAutoOpenWhenGet = isAutoOpenWhenGet,
        subTitle = subTitle
    }
    UIManager:Open(PanelId.BattlePassWeaponCase, luaArg)
end





BattlePassWeaponCaseCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self.isAutoOpenWhenGet = self.m_arg.isAutoOpenWhenGet == true
    self.m_isPreview = self.m_arg.isPreview == true
    self.view.txtDesc.text = Language.LUA_BATTLEPASS_WEAPON_CHEST_TITLE
    local hint = arg.subTitle
    if string.isEmpty(hint) then
        hint = self.isAutoOpenWhenGet and Language.LUA_BATTLEPASS_WEAPON_CHEST_SUBTITLE or ""
    end
    self.view.txtHint.text = hint
    self.view.txtHint.gameObject:SetActive(not string.isEmpty(hint))
    self.view.titleTxt.text = self.m_isPreview and
        Language.LUA_BATTLEPASS_WEAPON_CHEST_TITLE_LEFT_PREVIEW or Language.LUA_BATTLEPASS_WEAPON_CHEST_TITLE_LEFT
    self.view.desc3Text.gameObject:SetActive(not self.m_isPreview)
    self.m_itemCellCache = UIUtils.genCellCache(self.view.weaponCell)
    self:_InitAction()
    self:_InitController()
    self:_Refresh()
    self.view.scrollRect.normalizedPosition = 0
end



BattlePassWeaponCaseCtrl._InitAction = HL.Method() << function(self)
    self.view.btnBack.onClick:AddListener(function()
        self:_CloseWithConfirm()
    end)
    self.view.btnMore.gameObject:SetActive(self.m_isPreview)
    self.view.btnMore.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.btnCancel.gameObject:SetActive(not self.m_isPreview)
    self.view.btnCancel.onClick:AddListener(function()
        self:_CloseWithConfirm()
    end)
    self.view.btnConfirm.onClick:AddListener(function()
        if self.m_selectedRewardId then
            local itemId = UIUtils.getRewardFirstItem(self.m_selectedRewardId).id
            Notify(MessageConst.SHOW_POP_UP, {
                content = Language.LUA_BATTLEPASS_WEAPON_CHEST_CONFIRM_TITLE,
                subContent = string.format(Language.LUA_BATTLEPASS_WEAPON_CHEST_CONFIRM_CONTENT_FORMAT, Tables.itemTable[itemId].name),
                onConfirm = function()
                    GameInstance.player.inventory:OpenUsableItemChest(self.m_chestData.id, 1, {self.m_selectedRewardId })
                end,
            })
        end
    end)
    self:_UpdateBtns()
end



BattlePassWeaponCaseCtrl._CloseWithConfirm = HL.Method() << function(self)
    if self.isAutoOpenWhenGet then
        Notify(MessageConst.SHOW_POP_UP, {
            content = Language.LUA_BATTLEPASS_WEAPON_CHEST_CANCEL_TITLE,
            subContent = Language.LUA_BATTLEPASS_WEAPON_CHEST_CANCEL_CONTENT,
            onConfirm = function()
                self:PlayAnimationOutAndClose()
            end,
        })
    else
        self:PlayAnimationOutAndClose()
    end
end



BattlePassWeaponCaseCtrl._UpdateBtns = HL.Method() << function(self)
    local isSelected = self.m_selectedRewardId ~= nil
    self.view.btnConfirm.gameObject:SetActive(not self.m_isPreview and isSelected)
    self.view.emptyNode.gameObject:SetActive(not self.m_isPreview and not isSelected)
end



BattlePassWeaponCaseCtrl._Refresh = HL.Method() << function(self)
    local _, itemChestData = Tables.usableItemChestTable:TryGetValue(self.m_arg.itemId)
    self.m_chestData = itemChestData
    if not itemChestData then
        self.m_itemCellCache:Refresh(0)
        return
    end
    local itemCount = #itemChestData.rewardIdList
    
    self.m_itemCellCache:Refresh(itemCount, function(cell, index)
        local rewardId = itemChestData.rewardIdList[CSIndex(index)]
        local weaponId = UIUtils.getRewardFirstItem(rewardId).id
        cell.nodeState:SetState(CellStateName.Normal)
        cell.btnConfirm.onClick:RemoveAllListeners()
        cell.btnConfirm.onClick:AddListener(function()
            if self.m_isPreview and not DeviceInfo.usingController then
                self:_PreviewWeapon(weaponId)
                return
            end
            self:_OnWeaponCellClicked(cell, rewardId)
        end)
        cell.btnDetail.onClick:RemoveAllListeners()
        cell.btnDetail.onClick:AddListener(function()
            self:_PreviewWeapon(weaponId)
        end)
        local _, itemData = Tables.itemTable:TryGetValue(weaponId)
        if itemData then
            cell.weaponImg:LoadSprite(UIConst.UI_SPRITE_GACHA_WEAPON, itemData.iconId)
            cell.nameTxt.text = itemData.name
            local stateName = self:_GetCellRarityStateName(itemData.rarity)
            cell.selectedNode:SetState(stateName)
            cell.unselectedNode:SetState(stateName)
            cell.numTxt.text = tostring(Utils.getItemCount(weaponId))
            cell.starGroup:InitStarGroup(itemData.rarity)
        end

        if DeviceInfo.usingController then
            cell.btnDetailInputGroup.enabled = false
            if not self.m_isPreview then
                InputManagerInst:SetBindingText(cell.btnConfirm.hoverConfirmBindingId, Language.LUA_BATTLEPASS_WEAPON_SELECT)
            else
                InputManagerInst:SetBindingText(cell.btnConfirm.hoverConfirmBindingId, "")
            end

            cell.btnConfirm.onIsNaviTargetChanged = function(isTarget)
                cell.btnDetailInputGroup.enabled = isTarget
            end

            if index == 1 then
                UIUtils.setAsNaviTarget(cell.btnConfirm)
            end
        end
    end)
end





BattlePassWeaponCaseCtrl._OnWeaponCellClicked = HL.Method(HL.Table, HL.Any) << function(self, cell, rewardId)
    if cell == self.m_selectedCell then
        if DeviceInfo.usingController then
            return
        end
        self.m_selectedCell.nodeState:SetState(CellStateName.Normal)
        self.m_selectedCell = nil
        self.m_selectedRewardId = nil
        self:_UpdateBtns()
        return
    end
    if self.m_selectedCell then
        self.m_selectedCell.nodeState:SetState(CellStateName.Normal)
    end
    cell.nodeState:SetState(CellStateName.Selected)
    self.m_selectedCell = cell
    self.m_selectedRewardId = rewardId
    self:_UpdateBtns()
end




BattlePassWeaponCaseCtrl._PreviewWeapon = HL.Method(HL.String) << function(self, weaponId)
    local weaponGroupData = {
        title = Language.LUA_BATTLEPASS_WEAPON_CHEST_TITLE,
        weaponIds = {},
    }
    for _, rewardId in pairs(self.m_chestData.rewardIdList) do
        local weaponId = UIUtils.getRewardFirstItem(rewardId).id
        table.insert(weaponGroupData.weaponIds, weaponId)
    end

    
    local showWeaponPreviewArgs = {
        weaponId = weaponId,
        weaponGroups = { weaponGroupData },
    }
    WikiUtils.showWeaponPreview(showWeaponPreviewArgs)
end




BattlePassWeaponCaseCtrl._GetCellRarityStateName = HL.Method(HL.Number).Return(HL.String) << function(self, rarity)
    local stateName = ''
    if rarity <= 4 then
        stateName = 'Low'
    elseif rarity == 5 then
        stateName = 'Mid'
    else
        stateName = 'High'
    end
    return stateName
end




BattlePassWeaponCaseCtrl._OnOpenChest = HL.Method(HL.Table) << function(self, args)
    local openCount = args[1]
    if openCount == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_USABLE_ITEM_CHEST_OPEN_FAILED)
        return
    end
    self:Close()
    local rewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(CS.Beyond.GEnums.RewardSourceType.ItemCase)
    local items = {}
    local chars = nil
    if rewardPack and rewardPack.rewardSourceType == CS.Beyond.GEnums.RewardSourceType.ItemCase then
        for _, itemBundle in pairs(rewardPack.itemBundleList) do
            local _, itemData = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemData then
                local putInside = false
                for i = 1, #items do
                    if items[i].id == itemData.id and itemBundle.instId == 0 then
                        items[i].count = items[i].count + itemBundle.count
                        putInside = true
                        break
                    end
                end

                if not putInside then
                    table.insert(items, {id = itemBundle.id,
                                         count = itemBundle.count,
                                         instData = itemBundle.instData,
                                         instId = itemBundle.instId,
                                         rarity = itemData.rarity,
                                         type = itemData.type:ToInt()})
                end
            end
        end
        table.sort(items, Utils.genSortFunction({"rarity", "type", "id"}, false))
        
        chars = rewardPack.chars
    end
    local rewardPanelArgs = {}
    rewardPanelArgs.items = items
    rewardPanelArgs.chars = chars
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, rewardPanelArgs)
end



BattlePassWeaponCaseCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

HL.Commit(BattlePassWeaponCaseCtrl)
