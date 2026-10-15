local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailInnRanch
local ranchSystem = GameInstance.player.ranchSystem
local REWARD_SORT_FUNC = Utils.genSortFunction({ "rarity", "sortId1", "sortId2", "itemId" }, false)

MapMarkDetailInnRanchCtrl = HL.Class('MapMarkDetailInnRanchCtrl', uiCtrl.UICtrl)







MapMarkDetailInnRanchCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_RANCH_PRODUCT_UPDATED] = "_OnRanchProductUpdated",
    [MessageConst.ON_RANCH_HARVEST_SUCC] = "_OnHarvestSuccess",
}

MapMarkDetailInnRanchCtrl.m_markInstId = HL.Field(HL.String) << ""
MapMarkDetailInnRanchCtrl.m_ranchId = HL.Field(HL.String) << ""
MapMarkDetailInnRanchCtrl.m_domainName = HL.Field(HL.String) << ""
MapMarkDetailInnRanchCtrl.m_rewardItems = HL.Field(HL.Table)
MapMarkDetailInnRanchCtrl.m_rewardCells = HL.Field(HL.Forward("UIListCache"))
MapMarkDetailInnRanchCtrl.m_rewardNaviGroup = HL.Field(CS.Beyond.UI.UISelectableNaviGroup)
MapMarkDetailInnRanchCtrl.m_onBeforeItemJump = HL.Field(HL.Function)


MapMarkDetailInnRanchCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshRewardItems()
end

MapMarkDetailInnRanchCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_markInstId = arg.markInstId
    local _, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(self.m_markInstId)
    self.m_ranchId = markRuntimeData.detail.ranchId
    self.m_domainName = Tables.domainDataTable:GetValue(Tables.innManagementConst.domainId).domainName
    self.m_rewardItems = {}
end

MapMarkDetailInnRanchCtrl._InitUI = HL.Method() << function(self)
    local commonArgs = {
        markInstId = self.m_markInstId,
    }
    local forbidMapTp = Utils.isForbiddenMapTeleport()
    self.view.forbidTeleportTips.gameObject:SetActive(forbidMapTp)
    if not forbidMapTp then
        commonArgs.bigBtnActive = true
        commonArgs.bigBtnText = Language["ui_mapmarkdetail_button_teleport"]
        commonArgs.bigBtnIconName = UIConst.MAP_DETAIL_BTN_ICON_NAME.TELEPORT
        commonArgs.bigBtnCallback = function()
            GameWorld.dialogManager:SkipCurrentDialog(true)
            self:_Teleport()
        end
    end
    self.view.detailCommon:InitMapMarkDetailCommon(commonArgs)

    self.view.storeBtn.onClick:AddListener(function()
        self:_OnStoreBtnClick()
    end)

    local rewardCell = Utils.wrapLuaNode(self.view.rewardLayout)
    self.m_rewardCells = UIUtils.genCellCache(rewardCell.itemReward)

    self.m_rewardNaviGroup = self.view.ranchProductionLayout.parent.gameObject:GetComponent("UISelectableNaviGroup")
    self.m_rewardNaviGroup.getDefaultSelectableFunc = function()
        local item = self.m_rewardCells:GetItem(1)
        return item and item.view.button
    end
    self.m_rewardNaviGroup.canFocusFun = function()
        return self.m_rewardCells:GetCount() > 0
    end
    self.m_onBeforeItemJump = function()
        self.m_rewardNaviGroup:ManuallyStopFocus()
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder(
        { self.view.inputGroup.groupId },
        nil,
        function(infoList)
            if InputManagerInst.controllerNaviManager:IsLayerInStack(self.m_rewardNaviGroup) then
                lume.clear(infoList)
            end
        end)
end

MapMarkDetailInnRanchCtrl._CollectRewardItems = HL.Method().Return(HL.Table) << function(self)
    local rewardItems = {}
    local rewardItemMap = {}
    local _, ranchData = ranchSystem:GetRanchData(self.m_ranchId)

    for _, stableData in cs_pairs(ranchData.stableData) do
        if not string.isEmpty(stableData.animalId) then
            local animalCfg = Tables.innRanchAnimalTable:GetValue(stableData.animalId)
            for productIndex = 1, 2 do
                local itemId = productIndex == 1 and animalCfg.lowLevelProd or animalCfg.highLevelProd
                local itemCount = productIndex == 1 and stableData.lowLevelProdCount or stableData.highLevelProdCount
                if itemCount > 0 then
                    local rewardItem = rewardItemMap[itemId]
                    if rewardItem then
                        rewardItem.itemCount = rewardItem.itemCount + itemCount
                    else
                        local itemCfg = Tables.itemTable:GetValue(itemId)
                        rewardItem = {
                            itemId = itemId,
                            itemCount = itemCount,
                            rarity = itemCfg.rarity,
                            sortId1 = itemCfg.sortId1,
                            sortId2 = itemCfg.sortId2,
                        }
                        rewardItemMap[itemId] = rewardItem
                        table.insert(rewardItems, rewardItem)
                    end
                end
            end
        end
    end

    table.sort(rewardItems, REWARD_SORT_FUNC)
    return rewardItems
end

MapMarkDetailInnRanchCtrl._RefreshRewardItems = HL.Method() << function(self)
    self.m_rewardItems = self:_CollectRewardItems()
    local hasReward = #self.m_rewardItems > 0
    if not hasReward and self.m_rewardNaviGroup.IsTopLayer then
        self.m_rewardNaviGroup:ManuallyStopFocus()
    end

    self.view.ranchProductionNode.gameObject:SetActive(hasReward)
    self.view.ranchEmptyProductionNode.gameObject:SetActive(not hasReward)
    self.view.rewardKeyHint.gameObject:SetActive(hasReward)
    self.m_rewardCells:Refresh(#self.m_rewardItems, function(cell, index)
        self:_UpdateRewardCell(cell, index)
    end)
    InputManagerInst:ToggleBinding(self.m_rewardNaviGroup.FocusBindingId,
                                   hasReward and not self.m_rewardNaviGroup.IsTopLayer)
end

MapMarkDetailInnRanchCtrl._UpdateRewardCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local rewardItem = self.m_rewardItems[index]
    local item = cell
    local shouldShowTips = item.showingTips or (DeviceInfo.usingController and item.view.button.isNaviTarget)
    if item.showingTips then
        Notify(MessageConst.HIDE_ITEM_TIPS)
        item:_OnTipsClosed()
    end
    item:InitItem({
        id = rewardItem.itemId,
        count = rewardItem.itemCount,
    }, true)
    item:SetExtraInfo({
        tipsPosTransform = self.view.ranchProductionLayout.parent,
        tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        isSideTips = true,
        onBeforeJump = self.m_onBeforeItemJump,
    })
    if shouldShowTips then
        item:ShowTips()
    end
end

MapMarkDetailInnRanchCtrl._OnStoreBtnClick = HL.Method() << function(self)
    if #self.m_rewardItems == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_RANCH_HARVEST_EMPTY_TOAST)
        return
    end
    ranchSystem:SendRanchProductTake(self.m_ranchId)
end

MapMarkDetailInnRanchCtrl._Teleport = HL.Method() << function(self)
    local getRuntimeDataSuccess, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(self.m_markInstId)
    if getRuntimeDataSuccess == false then
        logger.error("地图详情页获取实例数据失败" .. self.m_markInstId)
        return
    end
    local teleportValidationId = markRuntimeData.detail.teleportValidationId
    if string.isEmpty(teleportValidationId) then
        logger.error("牧场标记缺少teleportValidationId" .. self.m_markInstId)
        return
    end
    Utils.teleportToEntity(teleportValidationId)
end

MapMarkDetailInnRanchCtrl._OnHarvestSuccess = HL.Method(HL.Any) << function(self, arg)
    local _, items = unpack(arg)
    Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        items = items,
    })
    Notify(MessageConst.SHOW_TOAST,
           string.format(Language.LUA_RANCH_HARVEST_SUCCESS_TOAST, self.m_domainName))
end

MapMarkDetailInnRanchCtrl._OnRanchProductUpdated = HL.Method() << function(self)
    self:_RefreshRewardItems()
end

HL.Commit(MapMarkDetailInnRanchCtrl)
