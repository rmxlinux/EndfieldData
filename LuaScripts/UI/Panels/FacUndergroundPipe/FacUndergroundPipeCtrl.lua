
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacUndergroundPipe



































FacUndergroundPipeCtrl = HL.Class('FacUndergroundPipeCtrl', uiCtrl.UICtrl)

local UDPIPE_CONTROLLER_STATE_MAP = {
    ["udpipe_loader_1"] = "NormalEntrance",
    ["udpipe_loader_2"] = "AdvancedEntrance",
    ["udpipe_unloader_1"] = "NormalOutlet",
    ["udpipe_unloader_2"] = "AdvancedOutlet",
}


FacUndergroundPipeCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo)


FacUndergroundPipeCtrl.m_curConnectNode = HL.Field(HL.Table)


FacUndergroundPipeCtrl.m_templateId = HL.Field(HL.String) << ""


FacUndergroundPipeCtrl.m_updateThread = HL.Field(HL.Thread)


FacUndergroundPipeCtrl.m_dropHelper = HL.Field(HL.Forward('UIDropHelper'))


FacUndergroundPipeCtrl.m_capacityCount = HL.Field(HL.Number) << 0


FacUndergroundPipeCtrl.m_lastItemId = HL.Field(HL.String) << ""






FacUndergroundPipeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_START_UI_DRAG] = '_OnStartUiDrag',
    [MessageConst.ON_END_UI_DRAG] = '_OnEndUiDrag',
    [MessageConst.ON_PORT_BLOCK_STATE_CHANGE] = '_OnPortBlockStateChange',
}





FacUndergroundPipeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo
    self.m_templateId = self.m_buildingInfo.nodeHandler.templateId

    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo)
    self.view.mainUIController:SetState(UDPIPE_CONTROLLER_STATE_MAP[self.m_templateId])
    self.m_curConnectNode = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[self.m_templateId] and self.view.exportInfo or self.view.entranceInfo
    self.m_curConnectNode.viewMapBtn.onClick:AddListener(function()
        self:_OnClickViewMapBtn()
    end)
    self.m_curConnectNode.disconnectBtn.onClick:AddListener(function()
        self:_OnClickDisconnectBtn()
    end)
    self:_UpdateUdPipeConnectNode()

    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo, {
        useSinglePipe = FacConst.UDPIPE_PORT_LAYOUT_STATE_MAP[self.m_templateId],
    })
    self.view.inventoryArea:InitInventoryArea({
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end,
        onStateChange = function()
            self:_RefreshNaviGroupSwitcherInfos()
        end
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
    self:_TryChangeConnectionInterested(true)
end



FacUndergroundPipeCtrl.OnClose = HL.Override() << function(self)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
    self:_TryChangeConnectionInterested(false)
end



FacUndergroundPipeCtrl._OnClickViewMapBtn = HL.Method() << function(self)
    local connect = self.m_buildingInfo.udPipe.connectComponent
    if connect == nil then
        return
    end
    local success, mapInstId = GameInstance.player.mapManager:GetFacMarkInstIdByNodeId(connect.belongNode.belongChapter.chapterId, connect.belongNode.nodeId)
    if success then
        MapUtils.openMap(mapInstId)
    end
end



FacUndergroundPipeCtrl._OnClickDisconnectBtn = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_UDPIPE_DISCONNECTION_TIPS,
        onConfirm = function()
            local connect = self.m_buildingInfo.udPipe.connectComponent
            if connect == nil then
                return
            end
            local isLoader = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[self.m_templateId]
            local fromId = isLoader and self.m_buildingInfo.udPipe.componentId or connect.componentId
            local toId = isLoader and connect.componentId or self.m_buildingInfo.udPipe.componentId
            GameInstance.player.remoteFactory.core:Message_OpDelUpPipeConnection(self.m_buildingInfo.chapterId, fromId, toId, function()
                self.m_buildingInfo:Update()
                self:_UpdateUdPipeConnectNode()
                self:_TryChangeConnectionInterested(false)

                if DeviceInfo.usingController then
                    self.m_curConnectNode.btnNaviGroup:ManuallyStopFocus()
                end
            end)
        end
    })
end




FacUndergroundPipeCtrl._TryChangeConnectionInterested = HL.Method(HL.Boolean) << function(self, register)
    local connect = self.m_buildingInfo.udPipe.connectComponent
    local isLoader = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[self.m_templateId]
    if isLoader and connect ~= nil then
        local nodeId = connect.belongNode.nodeId
        if register then
            GameInstance.remoteFactoryManager:RegisterInterestedUnitId(nodeId)
        else
            GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(nodeId)
        end
    end
end




FacUndergroundPipeCtrl._OnPortBlockStateChange = HL.Method(HL.Table) << function(self, args)
    local buildingNodeId = unpack(args)
    local connect = self.m_buildingInfo.udPipe.connectComponent
    local isLoader = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[self.m_templateId]
    if isLoader and connect == nil then
        return
    end

    local nodeId = isLoader and connect.belongNode.nodeId or self.m_buildingInfo.nodeId
    if buildingNodeId == nodeId then
        self:_UpdateUdPipeConnectNode()
    end
end



FacUndergroundPipeCtrl._UpdateUdPipeConnectNode = HL.Method() << function(self)
    local connect = self.m_buildingInfo.udPipe.connectComponent
    local isLoader = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[self.m_templateId]
    if connect == nil then
        self.m_curConnectNode.nodeController:SetState("DisconnectState")
        self.view.buildingCommon.view.disconnectStateNode.gameObject:SetActiveIfNecessary(true)
        self.view.buildingCommon.view.stateNode.gameObject:SetActiveIfNecessary(false)
        self.view.buildingCommon.view.disconnectStateText.text = isLoader and Language["ui_fac_common_noconnect_out_info"] or Language["ui_fac_common_noconnect_in_info"]
        self.view.buildingCommon.view.controllerSideMenuBtn:InitControllerSideMenuBtn()
        return
    end

    self.view.buildingCommon.view.disconnectStateNode.gameObject:SetActiveIfNecessary(false)
    self.view.buildingCommon.view.stateNode.gameObject:SetActiveIfNecessary(true)
    self.view.buildingCommon.view.controllerSideMenuBtn:InitControllerSideMenuBtn({
        extraBtnInfos = {
            {
                textId = "ui_fac_udpipe_map_button",
                priority = 3.1,
                action = function()
                    self:_OnClickViewMapBtn()
                end
            },
            {
                textId = "ui_fac_udpipe_disconnect_button",
                priority = 3.2,
                action = function()
                    self:_OnClickDisconnectBtn()
                end
            },
        }
    })
    local bdata = Tables.factoryBuildingTable:GetValue(connect.belongNode.templateId)
    self.m_curConnectNode.titleText.text = bdata.name
    self.m_curConnectNode.btnNaviGroup:SetFocusBindingText(bdata.name)

    local srcAdvanced = not FacConst.UDPIPE_PORT_LAYOUT_STATE_MAP[self.m_templateId]
    local dstAdvanced = not FacConst.UDPIPE_PORT_LAYOUT_STATE_MAP[connect.belongNode.templateId]
    local dstState = isLoader and
        FactoryUtils.getBuildingStateType(connect.belongNode.nodeId) or
        FactoryUtils.getBuildingStateType(self.m_buildingInfo.nodeId)
    if dstState == GEnums.FacBuildingState.Blocked then
        self.m_curConnectNode.nodeController:SetState("BlockState")
    elseif srcAdvanced ~= dstAdvanced then
        self.m_curConnectNode.nodeController:SetState("FlowRateLimitState")
    else
        self.m_curConnectNode.nodeController:SetState("InOperationState")
    end
end



FacUndergroundPipeCtrl._UpdateConnectPassSpeed = HL.Method() << function(self)
    local connect = self.m_buildingInfo.udPipe.connectComponent
    if connect ~= nil then
        self.m_curConnectNode.speedTxt.text = tostring(self.m_buildingInfo.udPipe.lastRoundPassCount)
    end
end



FacUndergroundPipeCtrl._InitLiquidStoragerUpdateThread = HL.Method() << function(self)
    self:_RefreshLiquidStoragerBasicContent()
    self:_RefreshLiquidStoragerContainerCount()
    self:_RefreshLiquidItemSlot(true)
    self:_RefreshLiquidBg()
    self:_UpdateConnectPassSpeed()

    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_RefreshLiquidStoragerContainerCount()
            self:_RefreshLiquidItemSlot(false)
            self:_RefreshLiquidBg()
            self:_UpdateConnectPassSpeed()
        end
    end)
end



FacUndergroundPipeCtrl._RefreshLiquidStoragerBasicContent = HL.Method() << function(self)
    local success, storagerData = Tables.factoryUndergroundPipeTable:TryGetValue(self.m_buildingInfo.nodeHandler.templateId)
    if not success then
        return
    end

    self.m_capacityCount = storagerData.capacity
    
end



FacUndergroundPipeCtrl._RefreshLiquidStoragerContainerCount = HL.Method() << function(self)
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    

    local isFull = itemCount == self.m_capacityCount
    local countColor = isFull and self.view.config.CONTAINER_FULL_COUNT_COLOR or self.view.config.NORMAL_COUNT_COLOR
    local itemView = self.view.liquidItemSlot.view.item.view
    
    itemView.count.color = countColor
end




FacUndergroundPipeCtrl._RefreshLiquidItemSlot = HL.Method(HL.Boolean) << function(self, firstInit)
    local itemId = self.m_buildingInfo.fluidContainer.holdItemId
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    local isEmpty = string.isEmpty(itemId)
    local itemSlot = self.view.liquidItemSlot

    if self.m_lastItemId == itemId and not firstInit then
        itemSlot.item:UpdateCountSimple(itemCount)
        if itemCount > 0 then
            itemSlot.item.actionMenuArgs = {}
            itemSlot.item.customChangeActionMenuFunc = function(actionMenuInfos)
                table.insert(actionMenuInfos, {
                    text = Language.LUA_ITEM_ACTION_CACHE_SELECT_FILL_LIQUID,
                    action = function()
                        Notify(MessageConst.ON_NAVI_INVENTORY_SELECT_FLUID, {
                            componentId = self.m_buildingInfo.fluidContainer.componentId,
                            fluidId = "",
                            sourceItem = itemSlot.item
                        })
                    end
                })
                table.insert(actionMenuInfos, {
                    text = Language.LUA_ITEM_ACTION_CACHE_SELECT_DUMP_LIQUID,
                    action = function()
                        Notify(MessageConst.ON_NAVI_INVENTORY_SELECT_FLUID, {
                            componentId = self.m_buildingInfo.fluidContainer.componentId,
                            fluidId = itemId,
                            sourceItem = itemSlot.item
                        })
                    end
                })
            end
            InputManagerInst:SetBindingText(itemSlot.item.view.button.hoverConfirmBindingId, Language["key_hint_item_open_action_menu"])
        end
        return
    end
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




FacUndergroundPipeCtrl._OnClickItemSlot = HL.Method(HL.Forward('ItemSlot')) << function(self, itemSlot)
    if DeviceInfo.usingController then
        itemSlot.item:ShowActionMenu()
        return
    end

    itemSlot.item:SetSelected(true)
    itemSlot.item:ShowTips(nil, function()
        itemSlot.item:SetSelected(false)
    end)
end



FacUndergroundPipeCtrl._TryDisableHoverBindingOnEmptyItem = HL.Method() << function(self)
    local itemId = self.m_buildingInfo.fluidContainer.holdItemId
    local itemCount = self.m_buildingInfo.fluidContainer.holdItemCount
    if string.isEmpty(itemId) or itemCount == 0 then
        InputManagerInst:ToggleBinding(self.view.liquidItemSlot.item.view.button.hoverConfirmBindingId, false)
    end
end



FacUndergroundPipeCtrl._RefreshLiquidBg = HL.Method() << function(self)
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





FacUndergroundPipeCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
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




FacUndergroundPipeCtrl._IsEmptyBottleDrop = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    return Tables.emptyBottleTable:ContainsKey(itemId)
end




FacUndergroundPipeCtrl._IsFullBottleDrop = HL.Method(HL.String).Return(HL.Boolean) << function(self, itemId)
    return Tables.fullBottleTable:ContainsKey(itemId)
end




FacUndergroundPipeCtrl._ShouldAcceptDrop = HL.Method(HL.Forward('UIDragHelper')).Return(HL.Boolean) << function(self, dragHelper)
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




FacUndergroundPipeCtrl._OnDropItem = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
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




FacUndergroundPipeCtrl._OnStartUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    if dragHelper == nil then
        return
    end

    if self:_ShouldAcceptDrop(dragHelper) then
        self.view.liquidItemSlot.view.dropItem.enabled = true
        self.view.liquidItemSlot.view.dropHintImg.gameObject:SetActiveIfNecessary(true)
        local isEmptyBottle, isFullBottle = self:_IsEmptyBottleDrop(dragHelper.info.itemId), self:_IsFullBottleDrop(dragHelper.info.itemId)
        if isEmptyBottle or isFullBottle then
            self.view.liquidItemSlot.view.dropHintText.text = isEmptyBottle and Language["ui_fac_pipe_common_fill"] or Language["ui_fac_pipe_common_dump"]
        end
    else
        self.view.liquidItemSlot.view.dropItem.enabled = false
    end
end




FacUndergroundPipeCtrl._OnEndUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    if dragHelper == nil then
        return
    end

    self.view.liquidItemSlot.view.dropItem.enabled = false
    if self:_ShouldAcceptDrop(dragHelper) then
        self.view.liquidItemSlot.view.dropHintImg.gameObject:SetActiveIfNecessary(false)
    end
end












FacUndergroundPipeCtrl.m_naviGroupSwitcher = HL.Field(HL.Forward('NaviGroupSwitcher'))



FacUndergroundPipeCtrl._InitFacMachineCrafterController = HL.Method() << function(self)
    local NaviGroupSwitcher = require_ex("Common/Utils/UI/NaviGroupSwitcher").NaviGroupSwitcher
    self.m_naviGroupSwitcher = NaviGroupSwitcher(self.view.inputGroup.groupId, nil, true)

    self:_RefreshNaviGroupSwitcherInfos()
end



FacUndergroundPipeCtrl._RefreshNaviGroupSwitcherInfos = HL.Method() << function(self)
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



HL.Commit(FacUndergroundPipeCtrl)
