local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacLiquidCleaner

local InfoState = {
    None = "None",
    Processing = "Processing",
    Finished = "Finished",
    Empty = "Empty",
    Paused = "Paused",
}






































FacLiquidCleanerCtrl = HL.Class('FacLiquidCleanerCtrl', uiCtrl.UICtrl)


FacLiquidCleanerCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FluidConsume)


FacLiquidCleanerCtrl.m_updateThread = HL.Field(HL.Thread)


FacLiquidCleanerCtrl.m_progressInitThread = HL.Field(HL.Thread)


FacLiquidCleanerCtrl.m_progressUpdateThread = HL.Field(HL.Thread)


FacLiquidCleanerCtrl.m_needRefreshProgress = HL.Field(HL.Boolean) << false


FacLiquidCleanerCtrl.m_sewageItemData = HL.Field(HL.Table)


FacLiquidCleanerCtrl.m_validLiquidIds = HL.Field(HL.Table)


FacLiquidCleanerCtrl.m_infoState = HL.Field(HL.String) << ""


FacLiquidCleanerCtrl.m_lastValidItemId = HL.Field(HL.String) << ""


FacLiquidCleanerCtrl.m_isItemDirty = HL.Field(HL.Boolean) << false


FacLiquidCleanerCtrl.m_isPipeBlocked = HL.Field(HL.Boolean) << false






FacLiquidCleanerCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





FacLiquidCleanerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo
    self.m_sewageItemData = {}
    self:_InitCleanerStaticData()

    self.view.inventoryArea:InitInventoryArea({
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end,
        customSetActionMenuArgs = function(actionMenuArgs)
            actionMenuArgs.cacheRepo = self.view.facCacheRepository
        end,
        onStateChange = function(state)
            self:_RefreshNaviGroupSwitcherInfos()
            self:_RefreshChangeState(state)
        end,
        hasFluidInCache = true,
    })

    self.view.facCacheRepository:InitFacCacheRepository({
        cache = self.m_buildingInfo.fluidCache,
        isInCache = true,
        isFluidCache = true,
        cacheIndex = 1,
        slotCount = 1,
        fakeFormulaDataList = FactoryUtils.getBuildingCrafts(self.m_buildingInfo.buildingId)
    })

    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo, {
        useSinglePipe = true,
        stateRefreshCallback = function(pipeInfo)
            self:_OnPipeStateChanged(pipeInfo)
        end
    })

    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo, {
        onStateChanged = function(state)
            self:_RefreshCleanerTargetFormula()
            if state == GEnums.FacBuildingState.Idle then
                self:_ClearCleanerItemData()
            end
        end
    })

    self:_InitFacMachineCrafterController()
    self.view.facCacheRepository.view.repoNaviGroup:NaviToThisGroup()

    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_buildingInfo.nodeId)

    self:_InitCleanerFormulaNode()
    self:_InitCleanerProgressInitThread()
    self:_InitCleanerUpdateThread()
end



FacLiquidCleanerCtrl.OnClose = HL.Override() << function(self)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
end



FacLiquidCleanerCtrl._InitCleanerStaticData = HL.Method() << function(self)
    self.m_validLiquidIds = {}
    local success, tableData = Tables.factoryFluidConsumeTable:TryGetValue(self.m_buildingInfo.buildingId)
    if not success then
        return
    end

    for index = 0, tableData.liquidable.Count - 1 do
        self.m_validLiquidIds[tableData.liquidable[index]] = true
    end
end




FacLiquidCleanerCtrl._InitCleanerUpdateThread = HL.Method() << function(self)
    self:_UpdateAndRefreshAll()
    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            self:_UpdateAndRefreshAll()
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
        end
    end)
end



FacLiquidCleanerCtrl._UpdateAndRefreshAll = HL.Method() << function(self)
    self:_UpdateCleanerCacheItemData()
    self:_RefreshCleanerInfo()
    if self.m_isItemDirty then
        self:_RefreshCleanerTargetFormula()
        self:_RefreshCleanerProgressNode()
        self:_RefreshCleanerTipsVisibleState()
        self.m_isItemDirty = false
    end
end






FacLiquidCleanerCtrl._UpdateCleanerCacheItemData = HL.Method() << function(self)
    local consumeItemId = self.m_buildingInfo.consumeItemId
    if not consumeItemId then
        return
    end
    self.m_sewageItemData.id = consumeItemId
    self.m_sewageItemData.count = 0
    local getResult, cnt = self.m_buildingInfo.fluidCache.items:TryGetValue(self.m_sewageItemData.id)
    if getResult then
        self.m_sewageItemData.count = cnt
    end
    if self.m_lastValidItemId ~= self.m_sewageItemData.id then
        self.m_isItemDirty = true
    end
    self.m_lastValidItemId = self.m_sewageItemData.id
end




FacLiquidCleanerCtrl._OnPipeStateChanged = HL.Method(HL.Table) << function(self, pipeInfo)
    if pipeInfo == nil then
        return
    end

    self.m_isPipeBlocked = pipeInfo.isBlock
    self:_RefreshCleanerTipsVisibleState()
end



FacLiquidCleanerCtrl._RefreshCleanerTipsVisibleState = HL.Method() << function(self)
    local cacheItemId = self:_GetCleanerCacheItemData()
    local needShowTips = self.m_isPipeBlocked and string.isEmpty(self.m_buildingInfo.consumeItemId) and not self.m_validLiquidIds[cacheItemId]
    UIUtils.PlayAnimationAndToggleActive(self.view.tipsTextNode.animationWrapper, needShowTips)
end



FacLiquidCleanerCtrl._ClearCleanerItemData = HL.Method() << function(self)
    self.m_lastValidItemId = ""
    self.m_sewageItemData = {
        id = "",
        count = 0,
    }
    self.m_isItemDirty = true
end



FacLiquidCleanerCtrl._GetCleanerCacheItemData = HL.Method().Return(HL.String, HL.Number) << function(self)
    for itemId, itemCount in pairs(self.m_buildingInfo.fluidCache.items) do
        return itemId, itemCount
    end
    return "", 0
end








FacLiquidCleanerCtrl._RefreshCleanerInfo = HL.Method() << function(self)
    local state = InfoState.None
    if string.isEmpty(self.m_sewageItemData.id) then
        local cacheItemId, cacheItemCount = self:_GetCleanerCacheItemData()
        
        local isValidItem = self.m_validLiquidIds[cacheItemId]
        if isValidItem then
            state = cacheItemCount > 0 and InfoState.Paused or InfoState.Empty
        else
            state = InfoState.Paused
        end
    else
        if self.m_sewageItemData.count == 0 then
            state = InfoState.Finished
        else
            state = self.view.buildingCommon.lastState == GEnums.FacBuildingState.Normal and
                InfoState.Processing or
                InfoState.Paused
        end
    end
    if state == self.m_infoState then
        return
    end

    self.view.infoController:SetState(state)
    self.m_infoState = state
end








FacLiquidCleanerCtrl._InitCleanerFormulaNode = HL.Method() << function(self)
    self.view.formulaNode:InitFormulaNode(self.m_buildingInfo)
    self:_RefreshCleanerTargetFormula()
end



FacLiquidCleanerCtrl._RefreshCleanerTargetFormula = HL.Method() << function(self)
    local targetCraftInfo = FactoryUtils.getBuildingProcessingCraft(self.m_buildingInfo)
    if self.view.buildingCommon.lastState ~= GEnums.FacBuildingState.Normal then
        targetCraftInfo = nil
    end
    self.view.formulaNode:RefreshDisplayFormula(targetCraftInfo)
    self.view.facCacheRepository:UpdateRepositoryFormula(targetCraftInfo ~= nil and targetCraftInfo.craftId or "")
end








FacLiquidCleanerCtrl._InitCleanerProgressInitThread = HL.Method() << function(self)
    self:_UpdateCleanerProgressInitializedState()
    self.m_progressInitThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdateCleanerProgressInitializedState()
        end
    end)
end



FacLiquidCleanerCtrl._InitCleanerProgressUpdateThread = HL.Method() << function(self)
    self:_RefreshCleanerProgress()
    self.m_progressUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_RefreshCleanerProgress()
        end
    end)
end



FacLiquidCleanerCtrl._UpdateCleanerProgressInitializedState = HL.Method() << function(self)
    if self.m_buildingInfo.fluidConsume.progressIncrPerMS == 0 then
        
        
        self.view.facProgressNode:InitFacProgressNode(0, 0)
        return
    end

    self:_RefreshCleanerProgressNode()

    self:_InitCleanerProgressUpdateThread()
    self.m_progressInitThread = self:_ClearCoroutine(self.m_progressInitThread)
end



FacLiquidCleanerCtrl._RefreshCleanerProgressNode = HL.Method() << function(self)
    if string.isEmpty(self.m_lastValidItemId) or self.m_buildingInfo.fluidConsume.progressIncrPerMS == 0 then
        self:_StopCleanerProgressRefresh()
    else
        local totalProgress = self.m_buildingInfo.totalProgress
        local time = totalProgress / (self.m_buildingInfo.fluidConsume.progressIncrPerMS * 1000)
        self.view.facProgressNode:InitFacProgressNode(time, totalProgress)
        self.m_needRefreshProgress = true
    end
end



FacLiquidCleanerCtrl._RefreshCleanerProgress = HL.Method() << function(self)
    if not self.m_needRefreshProgress then
        return
    end

    self.view.facProgressNode:UpdateProgress(self.m_buildingInfo.fluidConsume.currentProgress)
end



FacLiquidCleanerCtrl._StopCleanerProgressRefresh = HL.Method() << function(self)
    self.view.facProgressNode:InitFacProgressNode(0, 0)
    self.m_needRefreshProgress = false
end




FacLiquidCleanerCtrl._RefreshChangeState = HL.Method(HL.Userdata) << function(self, state)
    local stateText
    if state == GEnums.FacBuildingState.NoPower then
        stateText = Language.LUA_FAC_CRAFTER_STATE_NOPOWER_TIPS
    elseif state == GEnums.FacBuildingState.NotInPowerNet then
        stateText = Language.LUA_FAC_CRAFTER_STATE_NOTINPOWERNET_TIPS
    elseif state == GEnums.FacBuildingState.Closed then
        stateText = Language.LUA_FAC_CRAFTER_STATE_CLOSE_TIPS
    end

    self.view.facProgressNode.gameObject:SetActiveIfNecessary(stateText == nil)

    if stateText == nil then
        self.view.facStateNode.animationWrapper:PlayOutAnimation(function()
            self.view.facStateNode.gameObject:SetActiveIfNecessary(false)
        end)
    else
        self.view.facStateNode.gameObject:SetActiveIfNecessary(true)
        self.view.facStateNode.stateTxt.text = stateText
    end
end










FacLiquidCleanerCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
    if cell == nil or itemBundle == nil then
        return
    end

    
    local itemId = itemBundle.id
    local isEmptyBottle = Tables.emptyBottleTable:ContainsKey(itemId)
    local isFullBottle = Tables.fullBottleTable:ContainsKey(itemId)
    local isBottle = isEmptyBottle or isFullBottle
    local isEmpty = string.isEmpty(itemBundle.id)
    local needMask = not isBottle and not isEmpty
    if isFullBottle then
        local fullBottleData = Tables.fullBottleTable[itemId]
        local liquidItemId = fullBottleData.liquidId
        needMask = needMask or not self.m_validLiquidIds[liquidItemId]
    end
    cell.view.forbiddenMask.gameObject:SetActiveIfNecessary(needMask)
    cell.view.dragItem.enabled = not needMask and not isEmpty
    cell.view.dropItem.enabled = not needMask
end







FacLiquidCleanerCtrl.m_naviGroupSwitcher = HL.Field(HL.Forward('NaviGroupSwitcher'))



FacLiquidCleanerCtrl._InitFacMachineCrafterController = HL.Method() << function(self)
    local NaviGroupSwitcher = require_ex("Common/Utils/UI/NaviGroupSwitcher").NaviGroupSwitcher
    self.m_naviGroupSwitcher = NaviGroupSwitcher(self.view.inputGroup.groupId, nil, true)

    self:_RefreshNaviGroupSwitcherInfos()
end



FacLiquidCleanerCtrl._RefreshNaviGroupSwitcherInfos = HL.Method() << function(self)
    if self.m_naviGroupSwitcher == nil then
        return
    end

    local naviGroupInfos = {
        {
            naviGroup = self.view.facCacheRepository.view.repoNaviGroup,
            text = Language.LUA_INV_NAVI_SWITCH_TO_MACHINE
        }
    }
    self.view.inventoryArea:AddNaviGroupSwitchInfo(naviGroupInfos)
    self.m_naviGroupSwitcher:ChangeGroupInfos(naviGroupInfos)
end



HL.Commit(FacLiquidCleanerCtrl)
