local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacLiquidStorager





























FacLiquidStoragerCtrl = HL.Class('FacLiquidStoragerCtrl', uiCtrl.UICtrl)


FacLiquidStoragerCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FluidContainer)


FacLiquidStoragerCtrl.m_updateThread = HL.Field(HL.Thread)


FacLiquidStoragerCtrl.m_dropHelper = HL.Field(HL.Forward('UIDropHelper'))


FacLiquidStoragerCtrl.m_capacityCount = HL.Field(HL.Number) << 0


FacLiquidStoragerCtrl.m_lastItemId = HL.Field(HL.String) << ""


FacLiquidStoragerCtrl.m_itemCountZero = HL.Field(HL.Boolean) << false







FacLiquidStoragerCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_START_UI_DRAG] = '_OnStartUiDrag',
    [MessageConst.ON_END_UI_DRAG] = '_OnEndUiDrag',
}





FacLiquidStoragerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo
    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo)

    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo, {
        useSinglePipe = true,
    })

    self.view.inventoryArea:InitInventoryArea({
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end,
        onStateChange = function()
            self:_RefreshNaviGroupSwitcherInfos()
        end,
        hasFluidInCache = true,
    })

    self:_InitLiquidStoragerUpdateThread()
    self:_InitFacMachineCrafterController()

    self.view.liquidItemSlot.view.facLiquidBg:InitFacLiquidBg()
    self.view.liquidItemSlot.view.liquidNaviGroup:NaviToThisGroup()
    self.view.liquidItemSlot.item.view.button.onIsNaviTargetChanged = function(active)
        if active then
            self:_TryDisableHoverBindingOnEmptyItem()
        end
    end

    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_buildingInfo.nodeId)
end



FacLiquidStoragerCtrl.OnClose = HL.Override() << function(self)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
end






FacLiquidStoragerCtrl._InitLiquidStoragerUpdateThread = HL.Method() << function(self)
    self:_RefreshLiquidStoragerBasicContent()
    self:_RefreshLiquidStoragerContainerCount()
    self:_RefreshLiquidItemSlot(true)
    self:_RefreshLiquidBg()

    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_RefreshLiquidStoragerContainerCount()
            self:_RefreshLiquidItemSlot(false)
            self:_RefreshLiquidBg()
        end
    end)
end



FacLiquidStoragerCtrl._RefreshLiquidStoragerBasicContent = HL.Method() << function(self)
    local success, storagerData = Tables.factoryFluidContainerTable:TryGetValue(self.m_buildingInfo.nodeHandler.templateId)
    if not success then
        return
    end

    self.m_capacityCount = storagerData.capacity
    self.view.totalText.text = string.format("%d", self.m_capacityCount)
end



FacLiquidStoragerCtrl._RefreshLiquidStoragerContainerCount = HL.Method() << function(self)
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    self.view.currentText.text = string.format("%d", itemCount)

    local isFull = itemCount == self.m_capacityCount
    local countColor = isFull and self.view.config.CONTAINER_FULL_COUNT_COLOR or self.view.config.NORMAL_COUNT_COLOR
    local itemView = self.view.liquidItemSlot.view.item.view
    self.view.numberNode.color = countColor
    itemView.count.color = countColor
end




FacLiquidStoragerCtrl._RefreshLiquidItemSlot = HL.Method(HL.Boolean) << function(self, firstInit)
    local itemId = self.m_buildingInfo.fluidContainer.holdItemId
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    local isEmpty = string.isEmpty(itemId)
    local itemSlot = self.view.liquidItemSlot

    if self.m_lastItemId ~= itemId or firstInit then
        self.m_lastItemId = itemId
        if isEmpty then
            itemSlot:InitItemSlot()
        else
            itemSlot:InitItemSlot({
                id = itemId,
                count = itemCount,
            }, function()
                self:_OnClickItemSlot(itemSlot)
            end)
            itemSlot.gameObject.name = "Item_" .. itemId
            itemSlot.item.view.button.clickHintTextId = "virtual_mouse_hint_item_tips"
        end
        itemSlot.view.dragItem.enabled = false  

        self.m_dropHelper = UIUtils.initUIDropHelper(self.view.liquidItemSlot.view.dropItem, {
            acceptTypes = UIConst.FACTORY_LIQUID_STORAGER_DROP_ACCEPT_INFO,
            onDropItem = function(eventData, dragHelper)
                if self:_ShouldAcceptDrop(dragHelper) then
                    self:_OnDropItem(dragHelper)
                end
            end,
            isDropArea = true,
        })
        self:_TryDisableHoverBindingOnEmptyItem()
    end

    local countZero = (itemCount == 0)
    if self.m_itemCountZero ~= countZero or firstInit then
        if not countZero then
            itemSlot.item.actionMenuArgs = {}
            itemSlot.item.customChangeActionMenuFunc = function(actionMenuInfos)
                table.insert(actionMenuInfos, 1, {
                    text = Language.LUA_ITEM_ACTION_CACHE_SELECT_DUMP_LIQUID,
                    action = function()
                        Notify(MessageConst.ON_NAVI_INVENTORY_SELECT_FLUID, {
                            componentId = self.m_buildingInfo.fluidContainer.componentId,
                            fluidId = itemId,
                            sourceItem = itemSlot.item
                        })
                    end
                })
                table.insert(actionMenuInfos, 1, {
                    text = Language.LUA_ITEM_ACTION_CACHE_SELECT_FILL_LIQUID,
                    action = function()
                        Notify(MessageConst.ON_NAVI_INVENTORY_SELECT_FLUID, {
                            componentId = self.m_buildingInfo.fluidContainer.componentId,
                            fluidId = "",
                            sourceItem = itemSlot.item
                        })
                    end
                })
            end
            local selectFillLiquidId = itemSlot.item:AddHoverBinding("common_quick_drop", function()
                Notify(MessageConst.ON_NAVI_INVENTORY_SELECT_FLUID, {
                    componentId = self.m_buildingInfo.fluidContainer.componentId,
                    fluidId = "",
                    sourceItem = itemSlot.item
                })
            end)
            InputManagerInst:SetBindingText(selectFillLiquidId, Language.LUA_ITEM_ACTION_CACHE_SELECT_FILL_LIQUID)
            InputManagerInst:SetBindingText(itemSlot.item.view.button.hoverConfirmBindingId, Language["key_hint_item_open_action_menu"])
        else
            local fakeGrayBinding = itemSlot.item:AddHoverBinding("common_quick_drop", function() end)
            InputManagerInst:SetBindingText(fakeGrayBinding, Language.LUA_ITEM_ACTION_CACHE_SELECT_FILL_LIQUID)
            InputManagerInst:ForceBindingKeyhintToGray(fakeGrayBinding, true)
        end
        self.m_itemCountZero = countZero
    end

    itemSlot.item:UpdateCountSimple(itemCount)
end




FacLiquidStoragerCtrl._OnClickItemSlot = HL.Method(HL.Forward('ItemSlot')) << function(self, itemSlot)
    if DeviceInfo.usingController then
        itemSlot.item:ShowActionMenu()
        return
    end

    itemSlot.item:SetSelected(true)
    itemSlot.item:ShowTips(nil, function()
        itemSlot.item:SetSelected(false)
    end)
end



FacLiquidStoragerCtrl._TryDisableHoverBindingOnEmptyItem = HL.Method() << function(self)
    local itemId = self.m_buildingInfo.fluidContainer.holdItemId
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    if string.isEmpty(itemId) or itemCount == 0 then
        InputManagerInst:ToggleBinding(self.view.liquidItemSlot.item.view.button.hoverConfirmBindingId, false)
    end
end




FacLiquidStoragerCtrl._RefreshLiquidItemSlotDropHintText = HL.Method(HL.String) << function(self, itemId)
    local isEmptyBottle, isFullBottle = self:_IsEmptyBottleDrop(itemId), self:_IsFullBottleDrop(itemId)
    if not isEmptyBottle and not isFullBottle then
        return
    end

    local text = isEmptyBottle and Language.LUA_ITEM_ACTION_FILL_LIQUID or Language.LUA_ITEM_ACTION_DUMP_LIQUID
    self.view.liquidItemSlot.view.dropHintText.text = text
end





FacLiquidStoragerCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
    if cell == nil or itemBundle == nil then
        return
    end

    
    local itemId = itemBundle.id
    local isEmptyBottle, isFullBottle = self:_IsEmptyBottleDrop(itemId), self:_IsFullBottleDrop(itemId)
    local isBottle = isEmptyBottle or isFullBottle
    local isEmpty = string.isEmpty(itemBundle.id)
    cell.view.forbiddenMask.gameObject:SetActiveIfNecessary(not isBottle and not isEmpty)
    cell.view.dragItem.enabled = isBottle
    cell.view.dropItem.enabled = isBottle or isEmpty

    if isBottle then
        cell.item.customChangeActionMenuFunc = function(actionMenuInfos)
            local dropAction = {}
            if isEmptyBottle then
                dropAction.text = Language.LUA_ITEM_ACTION_FILL_LIQUID
            else
                dropAction.text = Language.LUA_ITEM_ACTION_DUMP_LIQUID
            end
            dropAction.action = function()
                local dragHelper = cell.item.actionMenuArgs.dragHelper
                if self:_ShouldAcceptDrop(dragHelper) then
                    self:_OnDropItem(dragHelper)
                end
            end
            table.insert(actionMenuInfos, 1, dropAction)
        end
    end
end



FacLiquidStoragerCtrl._RefreshLiquidBg = HL.Method() << function(self)
    local itemSlot = self.view.liquidItemSlot

    local count = 0
    local height = 0
    if not string.isEmpty(self.m_buildingInfo.fluidContainer.holdItemId) then
        count = self.m_buildingInfo.fluidContainer.holdItemCount
        local maxCount = self.m_capacityCount
        if maxCount > 0 then
            height = count / maxCount
        end
    end

    itemSlot.view.facLiquidBg:RefreshLiquidHeight(height)
end









FacLiquidStoragerCtrl._OnStartUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    if dragHelper == nil then
        return
    end

    if self:_ShouldAcceptDrop(dragHelper) then
        self.view.liquidItemSlot.view.dropItem.enabled = true
        self.view.liquidItemSlot.view.dropHintImg.gameObject:SetActiveIfNecessary(true)
        self:_RefreshLiquidItemSlotDropHintText(dragHelper.info.itemId)
    else
        self.view.liquidItemSlot.view.dropItem.enabled = false
    end
end




FacLiquidStoragerCtrl._OnEndUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    if dragHelper == nil then
        return
    end

    self.view.liquidItemSlot.view.dropItem.enabled = false
    if self:_ShouldAcceptDrop(dragHelper) then
        self.view.liquidItemSlot.view.dropHintImg.gameObject:SetActiveIfNecessary(false)
    end
end




FacLiquidStoragerCtrl._IsEmptyBottleDrop = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    return Tables.emptyBottleTable:ContainsKey(itemId)
end




FacLiquidStoragerCtrl._IsFullBottleDrop = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    return Tables.fullBottleTable:ContainsKey(itemId)
end




FacLiquidStoragerCtrl._ShouldAcceptDrop = HL.Method(HL.Forward('UIDragHelper')).Return(HL.Boolean) << function(self, dragHelper)
    if not self.m_dropHelper:Accept(dragHelper) then
        return false
    end

    local itemId = dragHelper.info.itemId
    local isEmptyBottle, isFullBottle = self:_IsEmptyBottleDrop(itemId), self:_IsFullBottleDrop(itemId)
    if not isEmptyBottle and not isFullBottle then
        return false
    end

    
    if isEmptyBottle and string.isEmpty(self.m_buildingInfo.fluidContainer.holdItemId) then
        return false
    end

    return true
end




FacLiquidStoragerCtrl._OnDropItem = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    local source = dragHelper.source
    local dragInfo = dragHelper.info
    local core = GameInstance.player.remoteFactory.core
    local componentId = self.m_buildingInfo.fluidContainer.componentId
    if source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.ItemBag then
        core:Message_OpFillingFluidComWithBag(Utils.getCurrentChapterId(), componentId, dragInfo.csIndex)
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.FactoryDepot then
        core:Message_OpFillingFluidComWithDepot(Utils.getCurrentChapterId(), componentId, dragInfo.itemId)
    end
end







FacLiquidStoragerCtrl.m_naviGroupSwitcher = HL.Field(HL.Forward('NaviGroupSwitcher'))



FacLiquidStoragerCtrl._InitFacMachineCrafterController = HL.Method() << function(self)
    local NaviGroupSwitcher = require_ex("Common/Utils/UI/NaviGroupSwitcher").NaviGroupSwitcher
    self.m_naviGroupSwitcher = NaviGroupSwitcher(self.view.inputGroup.groupId, nil, true)

    self:_RefreshNaviGroupSwitcherInfos()
end



FacLiquidStoragerCtrl._RefreshNaviGroupSwitcherInfos = HL.Method() << function(self)
    if self.m_naviGroupSwitcher == nil then
        return
    end

    local naviGroupInfos = {
        {
            naviGroup = self.view.liquidItemSlot.view.liquidNaviGroup,
            text = Language.LUA_INV_NAVI_SWITCH_TO_MACHINE
        }
    }
    self.view.inventoryArea:AddNaviGroupSwitchInfo(naviGroupInfos)
    self.m_naviGroupSwitcher:ChangeGroupInfos(naviGroupInfos)
end



HL.Commit(FacLiquidStoragerCtrl)
