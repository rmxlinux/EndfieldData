local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacPendingSubmitPopup

local CELL_GRADUALLY_SHOW_INTERVAL = 0.06

FacPendingSubmitPopupCtrl = HL.Class('FacPendingSubmitPopupCtrl', uiCtrl.UICtrl)







FacPendingSubmitPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.FAC_ON_PENDING_NODE_CHANGED] = 'FacOnPendingNodeChanged',
    [MessageConst.FAC_ON_PENDING_NODE_SLOT_SUBMIT_ITEM_CHANGED] = 'FacOnPendingNodeChanged',
}

FacPendingSubmitPopupCtrl.m_slotId = HL.Field(HL.Number) << -1

FacPendingSubmitPopupCtrl.m_lackMaterialState = HL.Field(HL.String) << ""

FacPendingSubmitPopupCtrl.m_buildingInfos = HL.Field(HL.Table)

FacPendingSubmitPopupCtrl.m_materialInfos = HL.Field(HL.Table)

FacPendingSubmitPopupCtrl.m_buildingCacheList = HL.Field(HL.Forward('UIListCache'))

FacPendingSubmitPopupCtrl.m_materialCacheList = HL.Field(HL.Forward('UIListCache'))


FacPendingSubmitPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_slotId = arg.slotId
    self.m_lackMaterialState = arg.state

    self.view.closeButton.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.bgBlack.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.submitBtn.onClick:AddListener(function()
        if self:IsPlayingAnimationIn() then
            return
        end
        local sys = GameInstance.remoteFactoryManager.system
        sys:SubmitItemToPendingData(Utils.getCurrentChapterId(), self.m_slotId, function()
            self:FacOnPendingNodeChanged()
        end)
    end)

    self.m_buildingCacheList = UIUtils.genCellCache(self.view.buildingCell)
    self.m_materialCacheList = UIUtils.genCellCache(self.view.materialCell)

    self:RefreshList()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end








FacPendingSubmitPopupCtrl.RefreshList = HL.Method() << function(self)
    local slotInfo = GameInstance.remoteFactoryManager.currentChapterInfo:GetPendingPlaceSlot(self.m_slotId)
    local infoMap = {}

    slotInfo:FillTotalCostItems({}) 
    for _, v in pairs(slotInfo.totalCostItems) do
        local id, count = v.Item1, v.Item2
        infoMap[id] = {
            needCount = count,
            submitCount = 0,
        }
    end
    for _, v in pairs(slotInfo.submittedItems) do
        local id, count = v.Item1, v.Item2
        local info = infoMap[id]
        info.submitCount = count
    end
    self.m_buildingInfos = {}
    self.m_materialInfos = {}
    local materialMap = {}
    for itemId, v in pairs(infoMap) do
        local lackCount = v.needCount - v.submitCount
        if lackCount > 0 then
            local hasCount = Utils.getItemCount(itemId, true, true)
            if hasCount > 0 then
                local data = Tables.itemTable[itemId]
                table.insert(self.m_buildingInfos, {
                    id = itemId,
                    lack = lackCount,
                    has = hasCount,
                    sortId1 = data.sortId1,
                    sortId2 = data.sortId2,
                })
            end
            local craftCount = lackCount - hasCount
            if craftCount > 0 then
                local buildingId = FactoryUtils.getItemBuildingId(itemId)
                local craftData = Tables.factoryHubCraftTable:GetValue(buildingId)
                for index = 1, FacConst.FAC_HUB_CRAFT_MAX_INCOME_NUM do
                    if craftData.ingredients.length >= index then
                        local itemBundle = craftData.ingredients[CSIndex(index)]
                        if materialMap[itemBundle.id] == nil then
                            materialMap[itemBundle.id] = itemBundle.count * craftCount
                        else
                            materialMap[itemBundle.id] = materialMap[itemBundle.id] + itemBundle.count * craftCount
                        end
                    end
                end
            end
        end
    end
    for itemId, lackCount in pairs(materialMap) do
        local hasCount = Utils.getItemCount(itemId, true, true)
        local data = Tables.itemTable[itemId]
        table.insert(self.m_materialInfos, {
            id = itemId,
            lack = lackCount,
            has = hasCount,
            sortId1 = data.sortId1,
            sortId2 = data.sortId2,
        })
    end
    local sortFunction = Utils.genSortFunction({ "sortId1", "sortId2", "id" })
    table.sort(self.m_buildingInfos, sortFunction)
    table.sort(self.m_materialInfos, sortFunction)

    local buildingListCount = #self.m_buildingInfos
    if buildingListCount > 0 then
        self.view.buildingNode.gameObject:SetActiveIfNecessary(true)
        self.m_buildingCacheList:GraduallyRefresh(buildingListCount, CELL_GRADUALLY_SHOW_INTERVAL, function(cell, index)
            self:_OnUpdateItemCell(cell, self.m_buildingInfos[index])
        end)
    else
        self.view.buildingNode.gameObject:SetActiveIfNecessary(false)
    end
    local materialListCount = #self.m_materialInfos
    if materialListCount > 0 then
        self.view.materialNode.gameObject:SetActiveIfNecessary(true)
        self.m_materialCacheList:GraduallyRefresh(materialListCount, CELL_GRADUALLY_SHOW_INTERVAL, function(cell, index)
            self:_OnUpdateItemCell(cell, self.m_materialInfos[index])
        end)
    else
        self.view.materialNode.gameObject:SetActiveIfNecessary(false)
    end
    self.view.main:SetState(self.m_lackMaterialState)
    Notify(MessageConst.REFRESH_CONTROLLER_HINT)
end

FacPendingSubmitPopupCtrl._OnUpdateItemCell = HL.Method(HL.Table, HL.Table) << function(self, cell, info)
    cell.item:InitItem({ id = info.id, count = info.lack }, true)
    if DeviceInfo.usingController then
        cell.item:SetExtraInfo({ isSideTips = true })
    end
    cell.storageNode:InitStorageNode(info.has, info.lack, true)
end

FacPendingSubmitPopupCtrl.m_isExiting = HL.Field(HL.Boolean) << false

FacPendingSubmitPopupCtrl.GetRecoverStateArg = HL.Method().Return(HL.Table) << function(self)
    return {
        slotId = self.m_slotId,
        state = self.m_lackMaterialState,
    }
end

FacPendingSubmitPopupCtrl.FacOnPendingNodeChanged = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local slotInfo = GameInstance.remoteFactoryManager.currentChapterInfo:GetPendingPlaceSlot(self.m_slotId)
    if slotInfo then
        
        self.m_lackMaterialState = "CantSubmit"
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

HL.Commit(FacPendingSubmitPopupCtrl)
