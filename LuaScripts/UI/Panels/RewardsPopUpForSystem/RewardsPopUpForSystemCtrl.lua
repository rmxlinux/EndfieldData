
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.RewardsPopUpForSystem





















RewardsPopUpForSystemCtrl = HL.Class('RewardsPopUpForSystemCtrl', uiCtrl.UICtrl)






RewardsPopUpForSystemCtrl.s_messages = HL.StaticField(HL.Table) << {
}



RewardsPopUpForSystemCtrl.m_args = HL.Field(HL.Table)


RewardsPopUpForSystemCtrl.m_items = HL.Field(HL.Table)






RewardsPopUpForSystemCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.closeBtn.onClick:AddListener(function()
        if UIManager:IsShow(PanelId.ItemTips) then
            return
        end
        self:_OnClickClose()
    end)
    self.view.fullMask.onClick:AddListener(function()
        if UIManager:IsShow(PanelId.ItemTips) then
            return
        end
        self:_OnClickClose()
    end)
    self.view.skipBtn.onClick:AddListener(function()
        self:_OnClickSkip()
    end)

    local getItemCells = UIUtils.genCachedCellFunction(self.view.rewardsScrollList)
    self.view.rewardsScrollList.onUpdateCell:AddListener(function(object, csIndex)
        local cell = getItemCells(object)
        self:_OnUpdateCell(cell, LuaIndex(csIndex))
    end)
    self.view.rewardsScrollList.onGraduallyShowFinish:AddListener(function()
        self.view.skipBtn.gameObject:SetActive(false)
        self.view.controllerHintPlaceholder.gameObject:SetActive(true)
        local firstItemGo = self.view.rewardsScrollList:Get(0)
        if firstItemGo then
            self.view.focusItemKeyHint.gameObject:SetActive(true)
            self.view.focusItemKeyHint.transform.position = firstItemGo.transform.position
            local keyHintPos = self.view.focusItemKeyHint.transform.localPosition
            keyHintPos.x = keyHintPos.x - 50
            keyHintPos.y = keyHintPos.y - 90
            self.view.focusItemKeyHint.transform.localPosition = keyHintPos
        end
    end)

    self.view.naviGroup.getDefaultSelectableFunc = function()
        local cell = getItemCells(1)
        return cell and cell.view.button or nil
    end
    self.view.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})

    
    
    if NotNull(self.view.emptyNaviDecorator) then
        UIUtils.setAsNaviTarget(self.view.emptyNaviDecorator)
        self.view.emptyNaviDecorator.hideNaviHint = true
    end
end



RewardsPopUpForSystemCtrl.OnShow = HL.Override() << function(self)
    
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "systemRewards", isInMainHud = false })
end



RewardsPopUpForSystemCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "systemRewards", isInMainHud = true })
end



RewardsPopUpForSystemCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.TOGGLE_IN_MAIN_HUD_STATE, { key = "systemRewards", isInMainHud = true })
end































RewardsPopUpForSystemCtrl.ShowSystemRewards = HL.StaticMethod(HL.Table) << function(args)
    if RewardsPopUpForSystemCtrl._TryShowCharRewards(args) then
        return
    end
    Notify(MessageConst.HIDE_ITEM_TIPS)
    if UIManager:IsOpen(PANEL_ID) then
        UIManager:SetTopOrder(PANEL_ID) 
    end
    
    local self = UIManager:AutoOpen(PANEL_ID, nil, false)
    self:_ShowRewards(args)
end



RewardsPopUpForSystemCtrl.CSShowSystemRewards = HL.StaticMethod(HL.Table) << function(args)
    local title, items, inputChars, onComplete = unpack(args)
    local newArgs = {
        title = title,
        items = items,
        chars = inputChars,
        onComplete = onComplete
    }
    RewardsPopUpForSystemCtrl.ShowSystemRewards(newArgs)
end



RewardsPopUpForSystemCtrl._TryShowCharRewards = HL.StaticMethod(HL.Any).Return(HL.Boolean) << function(args)
    if not args.chars then
        return false
    end
    
    local chars
    if type(args.chars) == "table" then
        chars = args.chars
    else
        
        chars = {}
        for _, v in pairs(args.chars) do
            
            local msg = v
            local info = {
                charId = msg.CharTemplateId,
                isNew = not msg.IsConverted,
            }
            info.rarity = Tables.characterTable[info.charId].rarity
            info.items = {}
            if not string.isEmpty(msg.ConvertedItemId) then
                table.insert(info.items, { id = msg.ConvertedItemId, count = 1 })
            end
            if not string.isEmpty(msg.ConvertedRewardId) then
                UIUtils.getRewardItems(msg.ConvertedRewardId, info.items)
            end
            table.insert(chars, info)
        end
    end
    
    
    
    
    
    
    local items = RewardsPopUpForSystemCtrl._TryConvertCSItemsLuaToTable(args.items)
    local finalItems = {}
    local hasCharItem = false
    
    local initWeaponIds = {}
    for _, charInfo in pairs(chars) do
        local _, charPresetCfg = Tables.gachaPoolCharPresetTable:TryGetValue(charInfo.charId)
        table.insert(initWeaponIds, charPresetCfg.initialWeaponId)
    end
    
    local itemCount = #items
    for i = itemCount, 1, -1 do
        local itemInfo = items[i]
        local itemCfg = Tables.itemTable[itemInfo.id]
        if itemCfg.type == GEnums.ItemType.Char then
            
            hasCharItem = true
        elseif lume.find(Tables.charGachaConst.CharConvertItemFilterListClientShow, itemInfo.id) or itemCfg.type == GEnums.ItemType.CharPotentialUp then
            
            table.insert(finalItems, itemInfo)
            table.remove(items, i)
        elseif lume.find(initWeaponIds, itemInfo.id) then
            
            table.remove(items, i)
        end
    end
    
    if not hasCharItem then
        for _, charInfo in pairs(chars) do
            local itemId = charInfo.charId
            local itemData = Tables.itemTable[itemId]
            local itemInfo = {
                id = itemId,
                count = 1,
                sortId1 = itemData.sortId1,
                sortId2 = itemData.sortId2,
                rarity = itemData.rarity,
            }
            table.insert(items, itemInfo)
        end
    end
    table.sort(items, Utils.genSortFunction("rarity", "sortId1", "sortId2", "id"))
    
    args.chars = nil
    args.items = finalItems
    
    
    local charRewardsArg = {
        items = items,
        closeFast = true,
        onComplete = function()
            
            PhaseManager:OpenPhaseFast(PhaseId.GachaChar, {
                chars = chars,
                onComplete = function()
                    
                    if #finalItems > 0 then
                        RewardsPopUpForSystemCtrl.ShowSystemRewards(args)
                    end
                end
            })
        end
    }
    RewardsPopUpForSystemCtrl.ShowSystemRewards(charRewardsArg)
    return true
end



RewardsPopUpForSystemCtrl._TryConvertCSItemsLuaToTable = HL.StaticMethod(HL.Any).Return(HL.Table) << function(csItems)
    if type(csItems) == "table" then
        return csItems
    else
        
        
        local items = {}
        for _, v in pairs(csItems) do
            table.insert(items, { id = v.id, count = v.count })
        end
        return items
    end
end




RewardsPopUpForSystemCtrl._ShowRewards = HL.Method(HL.Table) << function(self, args)
    self.m_args = args

    if not string.isEmpty(args.title) then
        self.view.titleTxt.text = args.title
    else
        self.view.titleTxt.text = Language.LUA_DEFAULT_SYSTEM_REWARD_POP_UP_TITLE
    end
    if args.subTitle then
        self.view.subTitleTxt.text = args.subTitle
        self.view.subTitleTxt.gameObject:SetActive(true)
    else
        self.view.subTitleTxt.gameObject:SetActive(false)
    end

    if args.icon then
        self.view.rewardsTypeIcon:LoadSprite(UIConst.UI_SPRITE_REWARDS, args.icon)
    else
        self.view.rewardsTypeIcon:LoadSprite(UIConst.UI_SPRITE_REWARDS, "icon_common_rewards")
    end

    local items = RewardsPopUpForSystemCtrl._TryConvertCSItemsLuaToTable(args.items)
    local count = #items
    
    for k = 1, count do
        local v = items[k]
        if type(v) ~= "table" then
            v = { id = v.id, count = v.count }
            items[k] = v
        end
        local iData = Tables.itemTable[v.id]
        v.sortId1 = iData.sortId1
        v.sortId2 = iData.sortId2
        v.rarity = iData.rarity
    end
    table.sort(items, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))

    self.m_items = items
    
    self.view.rewardsScrollList.gameObject:SetActive(false)
    self.view.rewardsScrollList:UpdateCount(count, true)

    self.view.skipBtn.gameObject:SetActive(true)
end



RewardsPopUpForSystemCtrl._OnClickSkip = HL.Method() << function(self)
    self.view.luaPanel.animationWrapper:SkipInAnimation()
    self.view.rewardsScrollList:SkipGraduallyShow()
end



RewardsPopUpForSystemCtrl._OnClickClose = HL.Method() << function(self)
    if self.m_args.closeFast then
        local onComplete = self.m_args.onComplete
        self:_ClearData()
        self:Hide()
        if onComplete then
            onComplete()
        end
    else
        self:PlayAnimationOutWithCallback(function()
            local onComplete = self.m_args.onComplete
            self:_ClearData()
            self:Hide()
            if onComplete then
                onComplete()
            end
        end)
    end
end



RewardsPopUpForSystemCtrl._ClearData = HL.Method() << function(self)
    self.m_args.onComplete = nil
    self.m_args = nil
    self.m_items = nil
end





RewardsPopUpForSystemCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local itemBundle = self.m_items[index]
    cell:InitItem(itemBundle, true)
    cell:SetExtraInfo({
        isSideTips = DeviceInfo.usingController,
    })
    
    if DeviceInfo.usingController then
        cell:SetEnableHoverTips(false)
    end
    if cell.view.extraCornerNode ~= nil then
        cell.view.extraCornerNode.gameObject:SetActive(itemBundle.isExtra and true or false)
    end
    if cell.view.friendBoostTips ~= nil then
        cell.view.friendBoostTips.gameObject:SetActive(itemBundle.needShowHelp and true or false)
    end
    if cell.view.doubleNode ~= nil then
        cell.view.doubleNode.gameObject:SetActive(itemBundle.isDouble == true)
    end
    UIUtils.setRewardItemRarityGlow(cell, UIUtils.getItemRarity(itemBundle.id))
    local isFullBottle, bottleData = Tables.fullBottleTable:TryGetValue(itemBundle.id)
    if isFullBottle then
        cell.view.name.text = string.format(Language.LUA_REWARD_FULL_BOTTLE_FORMAT, Tables.itemTable[bottleData.emptyBottleId].name, Tables.itemTable[bottleData.liquidId].name)
    end
end



RewardsPopUpForSystemCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, false)
    Notify(MessageConst.ON_ENTER_BLOCKED_REWARD_POP_UP_PANEL)

    self.view.focusItemKeyHint.gameObject:SetActive(false)
    self.view.controllerHintPlaceholder.gameObject:SetActive(false)
end


RewardsPopUpForSystemCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)
    Notify(MessageConst.ON_EXIT_BLOCKED_REWARD_POP_UP_PANEL)
end


RewardsPopUpForSystemCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)
    Notify(MessageConst.ON_EXIT_BLOCKED_REWARD_POP_UP_PANEL)
end





RewardsPopUpForSystemCtrl.OnSortingOrderChange = HL.Override(HL.Number, HL.Boolean) << function(self, order, isInit)
    RewardsPopUpForSystemCtrl.Super.OnSortingOrderChange(self, order, isInit)
    Notify(MessageConst.REFRESH_CONTROLLER_HINT_ORDER)
end

HL.Commit(RewardsPopUpForSystemCtrl)
