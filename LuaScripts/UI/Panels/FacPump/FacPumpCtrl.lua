local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacPump



























FacPumpCtrl = HL.Class('FacPumpCtrl', uiCtrl.UICtrl)

local NORMAL_DESC_TEXT_ID = "ui_fac_liquid_pump_last"
local EMPTY_DESC_TEXT_ID = "ui_fac_liquid_pump_noliquid"
local EMPTY_ITEM_NAME_TEXT_ID = "ui_fac_liquid_pump_noleft"


FacPumpCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FluidPumpIn)


FacPumpCtrl.m_sourceInfo = HL.Field(CS.Beyond.Gameplay.Factory.FactoryUtil.FluidContainerInfo)


FacPumpCtrl.m_sourceContainer = HL.Field(HL.Userdata)


FacPumpCtrl.m_lastSourceItemCount = HL.Field(HL.Number) << -1


FacPumpCtrl.m_updateThread = HL.Field(HL.Thread)


FacPumpCtrl.m_progressInitThread = HL.Field(HL.Thread)


FacPumpCtrl.m_progressUpdateThread = HL.Field(HL.Thread)


FacPumpCtrl.m_needRefreshProgress = HL.Field(HL.Boolean) << false







FacPumpCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





FacPumpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo

    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo, {
        onStateChanged = function(state)
            self:_RefreshPumpTargetFormula()
            self:_RefreshChangeState(state)
        end
    })

    self.view.facCacheRepository:InitFacCacheRepository({
        cache = self.m_buildingInfo.pumpCache,
        isInCache = false,
        isFluidCache = true,
        cacheIndex = 1,
        slotCount = 1,
        fakeFormulaDataList = FactoryUtils.getBuildingCrafts(self.m_buildingInfo.buildingId),
        cacheChangedCallback = function()
            self:_RefreshPumpTargetFormula()
        end,
        outRepoCanDrop = true,
    })

    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo, {
        useSinglePipe = true,
    })

    self.view.formulaNode:InitFormulaNode(self.m_buildingInfo)
    self:_RefreshPumpTargetFormula()

    self.view.inventoryArea:InitInventoryArea({
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end,
        customSetActionMenuArgs = function(actionMenuArgs)
            actionMenuArgs.cacheRepo = self.view.facCacheRepository
        end,
        onStateChange = function()
            self:_RefreshNaviGroupSwitcherInfos()
        end,
        hasFluidInCache = true,
    })

    self:_InitFacMachineCrafterController()
    self.view.facCacheRepository.view.repoNaviGroup:NaviToThisGroup()

    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_buildingInfo.nodeId)

    self:_InitPumpSourceContainer()
    self:_InitPumpUpdateThread()
    self:_InitPumpProgressInitThread()
end



FacPumpCtrl.OnClose = HL.Override() << function(self)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
end



FacPumpCtrl._InitPumpSourceContainer = HL.Method() << function(self)
    local sourceNodeId = self.m_buildingInfo.fluidPumpIn.sourceNodeId
    local sourceInfo = CSFactoryUtil.GetFluidContainerInfo(sourceNodeId)
    self.m_sourceInfo = sourceInfo

    local sourceHandler = CSFactoryUtil.GetNodeHandlerByNodeId(sourceNodeId)
    if sourceHandler ~= nil then
        local component = FactoryUtils.getBuildingComponentHandlerAtPos(sourceHandler, GEnums.FCComponentPos.FluidContainer)
        if component ~= nil then
            self.m_sourceContainer = component.fluidContainer  
        end
    end

    self:_RefreshPumpSourceContainerBasicContent()
end






FacPumpCtrl._InitPumpUpdateThread = HL.Method() << function(self)
    self:_RefreshPumpSourceContainerItemCount()
    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_RefreshPumpSourceContainerItemCount()
        end
    end)
end



FacPumpCtrl._RefreshPumpSourceContainerBasicContent = HL.Method() << function(self)
    if self.m_sourceInfo == nil then
        return
    end

    
    self.view.sourceNameText.text = self.m_sourceInfo.name
    self.view.descText.text = self.m_sourceInfo.itemCount > 0 and Language[NORMAL_DESC_TEXT_ID] or Language[EMPTY_DESC_TEXT_ID]

    local sourceItemId = self.m_sourceInfo.itemId
    local success, sourceItemData = Tables.itemTable:TryGetValue(sourceItemId)
    if success and self.m_sourceInfo.itemCount > 0 then
        
        self.view.itemNameText.text = sourceItemData.name
    else
        self.view.itemNameText.text = Language[EMPTY_ITEM_NAME_TEXT_ID]
    end

    
    local isInfinite = self.m_sourceInfo.isInfinite
    self.view.normalCountNode.gameObject:SetActive(not isInfinite)
    self.view.infiniteCountNode.gameObject:SetActive(isInfinite)
end



FacPumpCtrl._RefreshPumpSourceContainerItemCount = HL.Method() << function(self)
    if self.m_sourceContainer == nil or self.m_sourceInfo == nil then
        return
    end

    if self.m_sourceInfo.isInfinite then
        return 
    end

    local holdItem = self.m_sourceContainer.holdItem
    local currentCount = holdItem == nil and 0 or holdItem.count
    local maxCount = self.m_sourceInfo.maxAmount

    
    self.view.itemCountNode.currentCountText.text = string.format("%d", currentCount)
    self.view.itemCountNode.maxCountText.text = string.format("%d", maxCount)
    self.view.itemCountNodeShadow.currentCountText.text = string.format("%d", currentCount)
    self.view.itemCountNodeShadow.maxCountText.text = string.format("%d", maxCount)

    if self.m_lastSourceItemCount > 0 and currentCount == 0 then
        
        self.view.descText.text = Language[EMPTY_DESC_TEXT_ID]
        self.view.itemNameText.text = Language[EMPTY_ITEM_NAME_TEXT_ID]

        
        self:_StopPumpProgressRefresh()
    end

    self.m_lastSourceItemCount = currentCount
end



FacPumpCtrl._RefreshPumpTargetFormula = HL.Method() << function(self)
    local targetCraftInfo = FactoryUtils.getBuildingProcessingCraft(self.m_buildingInfo)
    if self.view.buildingCommon.lastState ~= GEnums.FacBuildingState.Normal then
        targetCraftInfo = nil
    end
    self.view.formulaNode:RefreshDisplayFormula(targetCraftInfo)
    self.view.facCacheRepository:UpdateRepositoryFormula(targetCraftInfo ~= nil and targetCraftInfo.craftId or "")
end




FacPumpCtrl._RefreshChangeState = HL.Method(HL.Userdata) << function(self, state)
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








FacPumpCtrl._InitPumpProgressInitThread = HL.Method() << function(self)
    self:_UpdatePumpProgressInitializedState()
    self.m_progressInitThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdatePumpProgressInitializedState()
        end
    end)
end



FacPumpCtrl._InitPumpProgressUpdateThread = HL.Method() << function(self)
    self:_RefreshPumpProgress()
    self.m_progressUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_RefreshPumpProgress()
        end
    end)
end



FacPumpCtrl._UpdatePumpProgressInitializedState = HL.Method() << function(self)
    if self.m_buildingInfo.fluidPumpIn.progressIncrPerMS == 0 then
        
        
        self.view.facProgressNode:InitFacProgressNode(0, 0)
        return
    end

    local holdItem = self.m_sourceContainer.holdItem
    local currentCount = holdItem == nil and 0 or holdItem.count
    if currentCount == 0 then
        self:_StopPumpProgressRefresh()
    else
        local totalProgress = self.m_buildingInfo.totalProgress
        local time = totalProgress / (self.m_buildingInfo.fluidPumpIn.progressIncrPerMS * 1000)
        self.view.facProgressNode:InitFacProgressNode(time, totalProgress)
        self.m_needRefreshProgress = true

        self:_InitPumpProgressUpdateThread()
    end

    local pumpingItem = self.m_buildingInfo.fluidPumpIn.itemRoundId
    self.view.facCacheRepository:UpdateRepositoryFormula(pumpingItem or "")

    self.m_progressInitThread = self:_ClearCoroutine(self.m_progressInitThread)
end



FacPumpCtrl._RefreshPumpProgress = HL.Method() << function(self)
    if not self.m_needRefreshProgress then
        return
    end

    self.view.facProgressNode:UpdateProgress(self.m_buildingInfo.fluidPumpIn.currentProgress)
end



FacPumpCtrl._StopPumpProgressRefresh = HL.Method() << function(self)
    self.view.facProgressNode:InitFacProgressNode(0, 0)
    self.m_needRefreshProgress = false
end










FacPumpCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
    if cell == nil or itemBundle == nil then
        return
    end

    
    local isEmptyBottle = Tables.emptyBottleTable:ContainsKey(itemBundle.id)
    local isEmpty = string.isEmpty(itemBundle.id)
    cell.view.forbiddenMask.gameObject:SetActiveIfNecessary(not isEmptyBottle and not isEmpty)
    cell.view.dragItem.enabled = isEmptyBottle
    cell.view.dropItem.enabled = isEmptyBottle or isEmpty
end







FacPumpCtrl.m_naviGroupSwitcher = HL.Field(HL.Forward('NaviGroupSwitcher'))



FacPumpCtrl._InitFacMachineCrafterController = HL.Method() << function(self)
    local NaviGroupSwitcher = require_ex("Common/Utils/UI/NaviGroupSwitcher").NaviGroupSwitcher
    self.m_naviGroupSwitcher = NaviGroupSwitcher(self.view.inputGroup.groupId, nil, true)

    self:_RefreshNaviGroupSwitcherInfos()
end



FacPumpCtrl._RefreshNaviGroupSwitcherInfos = HL.Method() << function(self)
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




HL.Commit(FacPumpCtrl)
