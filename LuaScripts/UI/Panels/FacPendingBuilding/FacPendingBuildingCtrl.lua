
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacPendingBuilding

FacPendingBuildingCtrl = HL.Class('FacPendingBuildingCtrl', uiCtrl.UICtrl)

local LACK_MATERIAL_STATE = {
    ALL_CAN_SUBMIT = "AllSubmit",   
    SOME_CAN_SUBMIT = "SomeSubmit", 
    CANT_SUBMIT = "CantSubmit",      
    NO_LACK = "NoLack",             
}






FacPendingBuildingCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.FAC_ON_PENDING_NODE_CHANGED] = 'FacOnPendingNodeChanged',
    [MessageConst.FAC_ON_PENDING_NODE_SLOT_SUBMIT_ITEM_CHANGED] = 'FacOnPendingNodeChanged',
}


FacPendingBuildingCtrl.m_slotId = HL.Field(HL.Number) << -1

FacPendingBuildingCtrl.m_getCell = HL.Field(HL.Function)

FacPendingBuildingCtrl.m_infos = HL.Field(HL.Table)

FacPendingBuildingCtrl.m_lackBuildingMap = HL.Field(HL.Table)

FacPendingBuildingCtrl.m_lackMaterialState = HL.Field(HL.String) << ""

FacPendingBuildingCtrl.m_hasItemCanSubmit = HL.Field(HL.Boolean) << false



FacPendingBuildingCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.closeButton.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.FacMachine)
    end)

    self.m_slotId = arg.slotId

    self.view.cancelBtn.onClick:AddListener(function()
        self:_OnClickCancel()
    end)
    self.view.craftBtn.onClick:AddListener(function()
        self:_OnClickCraft()
    end)
    self.view.submitBtn.onClick:AddListener(function()
        self:_OnClickSubmit()
    end)

    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)

    self.view.name.text = FactoryUtils.getPendingSlotName(self.m_slotId)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.mainInputBindingGroupMonoTarget.groupId})
    self.view.decoTextImg:LoadSprite(UIConst.UI_SPRITE_BLUEPRINT, string.format("deco_facbuilding_text_0%d", self.m_slotId))

    self:RefreshList()

    if DeviceInfo.usingController then
        self.view.listNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
    end
end




FacPendingBuildingCtrl.RefreshList = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipGradually)
    local slotInfo = GameInstance.remoteFactoryManager.currentChapterInfo:GetPendingPlaceSlot(self.m_slotId)
    local infoMap = {}

    self.m_hasItemCanSubmit = false
    slotInfo:FillTotalCostItems({}) 
    for _, v in pairs(slotInfo.totalCostItems) do
        local id, count = v.Item1, v.Item2
        local data = Tables.itemTable[id]
        infoMap[id] = {
            id = id,
            needCount = count,
            submitCount = 0,
            sortId = 1,
            sortId1 = data.sortId1,
            sortId2 = data.sortId2,
        }
    end
    for _, v in pairs(slotInfo.submittedItems) do
        local id, count = v.Item1, v.Item2
        local info = infoMap[id]
        info.submitCount = count
        info.isCompleted = count >= info.needCount
        info.sortId = info.isCompleted and 0 or 1
    end
    self.m_infos = {}
    self.m_lackBuildingMap = {}
    for _, v in pairs(infoMap) do
        table.insert(self.m_infos, v)
        if not v.isCompleted then
            local hasCount = Utils.getItemCount(v.id, true, true)
            local lackCount = v.needCount - v.submitCount - hasCount
            if hasCount > 0 then
                self.m_hasItemCanSubmit = true
            end
            if lackCount > 0 then
                local buildingId = FactoryUtils.getItemBuildingId(v.id)
                self.m_lackBuildingMap[buildingId] = lackCount
            end
        end
    end
    self:_CheckMaterialLackState()
    table.sort(self.m_infos, Utils.genSortFunction({ "sortId", "sortId1", "sortId2", "id" }))

    self.view.scrollList:UpdateCount(#self.m_infos, true, false, false, skipGradually == true)
    self.view.bottomNode:SetState(self.m_lackMaterialState)
    
    Notify(MessageConst.REFRESH_CONTROLLER_HINT)
end

FacPendingBuildingCtrl._CheckMaterialLackState = HL.Method() << function(self)
    if next(self.m_lackBuildingMap) == nil then
        self.m_lackMaterialState = LACK_MATERIAL_STATE.NO_LACK
        return
    end
    
    local enoughAll = true
    local enoughOne = false
    local thisMaterialEnough = true
    local allCostMap = {}
    for buildingId, lackCount in pairs(self.m_lackBuildingMap) do
        thisMaterialEnough = true
        local craftData = Tables.factoryHubCraftTable:GetValue(buildingId)
        for index = 1, FacConst.FAC_HUB_CRAFT_MAX_INCOME_NUM do
            if craftData.ingredients.length >= index then
                local itemBundle = craftData.ingredients[CSIndex(index)]
                local hasCount = Utils.getItemCount(itemBundle.id, true, true)
                if hasCount < itemBundle.count then
                    thisMaterialEnough = false
                    enoughAll = false
                elseif hasCount < itemBundle.count * lackCount + (allCostMap[itemBundle.id] or 0) then
                    enoughAll = false
                end
                if allCostMap[itemBundle.id] then
                    allCostMap[itemBundle.id] = allCostMap[itemBundle.id] + itemBundle.count * lackCount
                else
                    allCostMap[itemBundle.id] = itemBundle.count * lackCount
                end
            end
        end
        if thisMaterialEnough then
            enoughOne = true
        end
        if (self.m_hasItemCanSubmit or enoughOne) and not enoughAll then
            self.m_lackMaterialState = LACK_MATERIAL_STATE.SOME_CAN_SUBMIT
            return
        end
    end

    if enoughAll then
        self.m_lackMaterialState = LACK_MATERIAL_STATE.ALL_CAN_SUBMIT
        return
    end

    if not enoughOne then
        self.m_lackMaterialState = LACK_MATERIAL_STATE.CANT_SUBMIT
        return
    end
end

FacPendingBuildingCtrl._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    local info = self.m_infos[index]
    cell.stateController:SetState(info.isCompleted and "Complete" or "Normal")
    cell.item:InitItem({ id = info.id }, true)
    if DeviceInfo.usingController then
        cell.item:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
            tipsPosTransform = cell.controllerHintNode,
            isSideTips = true,
        })
    end
    local ownCount = Utils.getItemCount(info.id, true, true)
    cell.ownCountTxt.text = UIUtils.setCountColor(ownCount, (info.needCount - info.submitCount) > ownCount)
    cell.submitCountTxt.text = string.format("%d/%d", info.submitCount, info.needCount)
    cell.progressBar.fillAmount = info.submitCount / info.needCount
end






FacPendingBuildingCtrl._OnClickCraft = HL.Method() << function(self)
    local deviceList = {}
    for _, info in ipairs(self.m_infos) do
        if not info.isCompleted then
            local buildingId = FactoryUtils.getItemBuildingId(info.id)
            local isEnough = info.needCount - info.submitCount <= 0 or Utils.getItemCount(info.id, true, true) >= info.needCount - info.submitCount
            if not isEnough then
                table.insert(deviceList, {
                    id = buildingId,
                    count = info.needCount - info.submitCount
                })
            end
        end
    end
    Notify(MessageConst.OPEN_FAC_BUILD_MODE_SELECT, { onlyCraftNode = true, bluePrintData = deviceList })
end

FacPendingBuildingCtrl._OnClickSubmit = HL.Method() << function(self)
    if self:IsPlayingAnimationIn() then
        return
    end
    if self.m_lackMaterialState == LACK_MATERIAL_STATE.NO_LACK then
        local sys = GameInstance.remoteFactoryManager.system
        sys:SubmitItemToPendingData(Utils.getCurrentChapterId(), self.m_slotId, function()
            self:FacOnPendingNodeChanged()
        end)
    else
        self:_CheckMaterialLackState()
        self.view.bottomNode:SetState(self.m_lackMaterialState)
        Notify(MessageConst.REFRESH_CONTROLLER_HINT)
        UIManager:AutoOpen(PanelId.FacPendingSubmitPopup, {
            slotId = self.m_slotId,
            state = self.m_lackMaterialState,
        })
    end
end

FacPendingBuildingCtrl._OnClickCancel = HL.Method() << function(self)
    local sys = GameInstance.remoteFactoryManager.system
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_FAC_BLUEPRINT_CONFIRM_CANCEL_PENDING,
        warningContent = Language.LUA_FAC_BLUEPRINT_CONFIRM_CANCEL_PENDING_HINT,
        onConfirm = function()
            sys:CancelBatchPending(Utils.getCurrentChapterId(), self.m_slotId,
            function()
                AudioAdapter.PostEvent("Au_UI_Event_Blueprint_YellowShadow_Close")
                if PhaseManager:GetTopPhaseId() == PhaseId.FacMachine then
                    PhaseManager:PopPhase(PhaseId.FacMachine)
                end
            end)
        end
    })
end



FacPendingBuildingCtrl.m_isExiting = HL.Field(HL.Boolean) << false

FacPendingBuildingCtrl.FacOnPendingNodeChanged = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local slotInfo = GameInstance.remoteFactoryManager.currentChapterInfo:GetPendingPlaceSlot(self.m_slotId)
    if slotInfo then
        
        self:RefreshList()
    else
        if not self.m_isExiting then
            self.m_isExiting = true
            
            if not PhaseManager:IsInPhaseTransition() then
                if PhaseManager:GetTopPhaseId() == PhaseId.FacMachine then
                    PhaseManager:PopPhase(PhaseId.FacMachine)
                else
                    PhaseManager:ExitPhaseFast(PhaseId.FacMachine)
                end
            end
            
            AudioAdapter.PostEvent("Au_UI_Event_Blueprint_BuildingBuild")
        end
    end
end



HL.Commit(FacPendingBuildingCtrl)
