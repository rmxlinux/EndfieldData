local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')










































FacCacheArea = HL.Class('FacCacheArea', UIWidgetBase)


FacCacheArea.m_onInitializeFinished = HL.Field(HL.Function)


FacCacheArea.hasNormalCacheIn = HL.Field(HL.Boolean) << false


FacCacheArea.hasFluidCacheIn = HL.Field(HL.Boolean) << false




FacCacheArea._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_START_UI_DRAG, function(dragHelper)
        self:OnStartUiDrag(dragHelper)
    end)
    self:RegisterMessage(MessageConst.ON_END_UI_DRAG, function(dragHelper)
        self:OnEndUiDrag(dragHelper)
    end)
end



FacCacheArea._OnDestroy = HL.Override() << function(self)
    if self.m_currDragHelper then
        self:_ClearMoveToInCacheSlotBinding()
    end
end




FacCacheArea.InitFacCacheArea = HL.Method(HL.Table) << function(self, areaData)
    self:_FirstTimeInit()
    if areaData == nil then
        return
    end

    self.m_buildingInfo = areaData.buildingInfo
    self.m_inRepositoryChangedCallback = areaData.inChangedCallback or function()end
    self.m_outRepositoryChangedCallback = areaData.outChangedCallback or function()end
    self.m_onInitializeFinished = areaData.onInitializeFinished or function()end
    self.m_onIsInCacheAreaNaviGroup = areaData.onIsInCacheAreaNaviGroup or function(isIn)end
    self.m_inRepositoryList = {}
    self.m_outRepositoryList = {}

    self:_InitAreaRepositoryList(true)
    self:_InitCacheAreaController()
    if self.m_onInitializeFinished ~= nil then
        self.m_onInitializeFinished()
    end
end





FacCacheArea.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_Producer)







FacCacheArea.m_inRepositoryList = HL.Field(HL.Table)


FacCacheArea.m_outRepositoryList = HL.Field(HL.Table)


FacCacheArea.m_inRepositoryChangedCallback = HL.Field(HL.Function)


FacCacheArea.m_outRepositoryChangedCallback = HL.Field(HL.Function)




FacCacheArea._InitAreaRepositoryList = HL.Method(HL.Opt(HL.Boolean)) << function(self, needDelayInit)
    local layoutData = FactoryUtils.getMachineCraftCacheLayoutData(self.m_buildingInfo.nodeId)

    if layoutData == nil then
        return
    end

    local viewRepoList = {
        self.view.inRepositoryList.repository1,
        self.view.inRepositoryList.repository2,
        self.view.outRepositoryList.repository1,
        self.view.outRepositoryList.repository2,
    }
    for _, repo in ipairs(viewRepoList) do
        repo:ClearFluidSlotShaderOnChangeMode()
        repo.gameObject:SetActive(false)
    end

    self.m_inRepositoryList = {}
    self.m_outRepositoryList = {}

    local normalInitRepoList = {
        {
            cache = layoutData.normalIncomeCaches,
            isIn = true,
        },
        {
            cache = layoutData.normalOutcomeCaches,
            isIn = false,
        },
    }

    local fluidInitRepoList = {
        {
            cache = layoutData.fluidIncomeCaches,
            isIn = true,
        },
        {
            cache = layoutData.fluidOutcomeCaches,
            isIn = false,
        },
    }

    self.hasNormalCacheIn = #layoutData.normalIncomeCaches > 0
    self.hasFluidCacheIn = #layoutData.fluidIncomeCaches > 0

    if needDelayInit then
        self:_StartCoroutine(function()
            coroutine.step()
        end)
    end
    for _, initInfo in ipairs(normalInitRepoList) do
        self:_InitAreaRepositoryListByCaches(initInfo.cache, initInfo.isIn, false)
    end

    for _, initInfo in ipairs(fluidInitRepoList) do
        self:_InitAreaRepositoryListByCaches(initInfo.cache, initInfo.isIn, true)
    end
end






FacCacheArea._InitAreaRepositoryListByCaches = HL.Method(HL.Table, HL.Boolean, HL.Boolean) << function(self, caches, isIn, isFluid)
    local repoList = isIn and self.m_inRepositoryList or self.m_outRepositoryList
    local viewRepoList = isIn and self.view.inRepositoryList or self.view.outRepositoryList
    local lockFormulaId = FactoryUtils.getMachineCraftLockFormulaId(self.m_buildingInfo.nodeId)

    for cacheIndex, cache in ipairs(caches) do
        local viewRepoName = string.format("repository%d", #repoList + 1)
        local repo = viewRepoList[viewRepoName]
        if repo ~= nil then
            repo:InitFacCacheRepository({
                cache = self.m_buildingInfo:GetCache(cacheIndex, isIn, isFluid),
                isInCache = isIn,
                isFluidCache = isFluid,
                cacheIndex = cacheIndex,
                slotCount = cache.slotCount,
                formulaId = self.m_buildingInfo.formulaId,
                lastFormulaId = self.m_buildingInfo.lastFormulaId,
                lockFormulaId = lockFormulaId,
                cacheChangedCallback = isIn and self.m_inRepositoryChangedCallback or self.m_outRepositoryChangedCallback,
                producerInfo = self.m_buildingInfo,
                forceUpdateOutRepoWithFormula = true,
            })
            repo.gameObject:SetActive(true)

            table.insert(repoList, repo)
        end
    end
end





FacCacheArea._GetAreaRepositoryItemCount = HL.Method(HL.Table, HL.Boolean).Return(HL.Number) << function(self, crafts, isIn)
    if crafts == nil then
        return 0
    end

    
    local result = 0
    for _, craftInfo in pairs(crafts) do
        local itemInfoList = isIn and craftInfo.incomes or craftInfo.outcomes
        if itemInfoList ~= nil then
            local count = 0
            for _, itemInfo in pairs(itemInfoList) do
                if itemInfo ~= nil and not string.isEmpty(itemInfo.id) then
                    count = count + 1
                end
            end
            if count > result then
                result = count
            end
            if result > 0 and result ~= count then
                logger.error("FacCacheArea: 当前机器配方格式不一致")
                break
            end
        end
    end

    return result
end





FacCacheArea._GetAreaRepositorySlotGroup = HL.Method(HL.Boolean, HL.Table).Return(HL.Table) << function(self, isFluid, repoList)
    local slotGroup = {}
    if repoList == nil then
        return slotGroup
    end

    for _, repo in ipairs(repoList) do
        if isFluid == repo:GetIsFluidCache() then
            table.insert(slotGroup, repo:GetRepositorySlotList())
        end
    end

    return slotGroup
end










FacCacheArea.ChangedFormula = HL.Method(HL.String, HL.String) << function(self, formulaId, lastFormulaId)
    for _, repo in pairs(self.m_inRepositoryList) do
        repo:UpdateRepositoryFormula(formulaId, lastFormulaId)
    end
    for _, repo in pairs(self.m_outRepositoryList) do
        repo:UpdateRepositoryFormula(formulaId, lastFormulaId)
    end
end







FacCacheArea.m_moveConfirmBindingId = HL.Field(HL.Number) << -1


FacCacheArea.m_moveCancelBindingId = HL.Field(HL.Number) << -1


FacCacheArea.m_currDragHelper = HL.Field(HL.Any)


FacCacheArea.m_currMoveSourceItem = HL.Field(HL.Userdata)


FacCacheArea.m_onIsInCacheAreaNaviGroup = HL.Field(HL.Function)



FacCacheArea._InitCacheAreaController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.m_moveConfirmBindingId = UIUtils.bindInputPlayerAction("fac_move_to_in_cache_slot_confirm", function()
        self:_OnNaviTargetMoveToSelectedSlotConfirm()
        self:_ClearMoveToInCacheSlotBinding()
    end, self.view.inputGroup.groupId)
    self.m_moveCancelBindingId = UIUtils.bindInputPlayerAction("common_cancel", function()
        self:_ClearMoveToInCacheSlotBinding()
    end, self.view.inputGroup.groupId)

    InputManagerInst:ToggleBinding(self.m_moveConfirmBindingId, false)
    InputManagerInst:ToggleBinding(self.m_moveCancelBindingId, false)

    self.view.inRepositoryList.inRepoNaviGroup.onIsTopLayerChanged:RemoveAllListeners()
    self.view.inRepositoryList.inRepoNaviGroup.onIsTopLayerChanged:AddListener(function(isTop)
        if self.m_onIsInCacheAreaNaviGroup ~= nil then
            self.m_onIsInCacheAreaNaviGroup(isTop or self.view.outRepositoryList.outRepoNaviGroup.IsTopLayer)
        end
    end)
    self.view.inRepositoryList.inRepoNaviGroup.getDefaultSelectableFunc = function()
        local repo = self.m_inRepositoryList[#self.m_inRepositoryList]
        return repo:GetFirstSlotNaviTarget()
    end
    self.view.outRepositoryList.outRepoNaviGroup.onIsTopLayerChanged:RemoveAllListeners()
    self.view.outRepositoryList.outRepoNaviGroup.onIsTopLayerChanged:AddListener(function(isTop)
        if self.m_onIsInCacheAreaNaviGroup ~= nil then
            self.m_onIsInCacheAreaNaviGroup(isTop or self.view.inRepositoryList.inRepoNaviGroup.IsTopLayer)
        end
    end)
end



FacCacheArea._ClearMoveToInCacheSlotBinding = HL.Method() << function(self)
    self.m_currDragHelper = nil
    self:_RefreshSlotButtonState(true)
    if self.m_currMoveSourceItem ~= nil then
        self.m_currMoveSourceItem:SetSelected(false)
        UIUtils.setAsNaviTarget(self.m_currMoveSourceItem.view.button)
    end
    for _, repo in ipairs(self.m_inRepositoryList) do
        repo:SetSlotListBtnEnabled(true)
    end
    self.view.inRepositoryList.inRepoNaviGroup.enablePartner = true
    InputManagerInst:ToggleBinding(self.m_moveConfirmBindingId, false)
    InputManagerInst:ToggleBinding(self.m_moveCancelBindingId, false)
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.inputGroup.groupId)
    Notify(MessageConst.FAC_ON_MOVE_HIDE_CONTROLLER_MODE_HINT)
end



FacCacheArea._OnNaviTargetMoveToSelectedSlotConfirm = HL.Method() << function(self)
    for _, repo in ipairs(self.m_inRepositoryList) do
        local slotList = repo:GetRepositorySlotList()
        for _, slot in ipairs(slotList) do
            if slot:IsNaviTarget() then
                slot:TryDropItem(self.m_currDragHelper, false)
                return
            end
        end
    end
end




FacCacheArea._RefreshSlotButtonState = HL.Method(HL.Boolean) << function(self, active)
    local inSlotGroupList = self:_GetAreaRepositorySlotGroup(false, self.m_inRepositoryList)
    for _, slotGroup in ipairs(inSlotGroupList) do
        for _, slot in ipairs(slotGroup) do
            slot:SetSlotBtnHoverBindingEnabled(active)
        end
    end
end








FacCacheArea.RefreshCacheArea = HL.Method() << function(self)
    
    self:_InitAreaRepositoryList()
end




FacCacheArea.RefreshAreaBlockState = HL.Method(HL.Boolean) << function(self, isBlocked)
    self.view.decoArrowAnimation.gameObject:SetActive(not isBlocked)
    self.view.blockNode.gameObject:SetActive(isBlocked)
end



FacCacheArea.GainAreaOutItems = HL.Method() << function(self)
    local core = GameInstance.player.remoteFactory.core
    core:Message_OpMoveAllCacheOutItemToBag(Utils.getCurrentChapterId(), self.m_buildingInfo.nodeId)
end



FacCacheArea.GetAreaInRepositoryNormalSlotGroup = HL.Method().Return(HL.Table) << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.inRepositoryList.rectTransform)
    return self:_GetAreaRepositorySlotGroup(false, self.m_inRepositoryList)
end



FacCacheArea.GetAreaOutRepositoryNormalSlotGroup = HL.Method().Return(HL.Table) << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.outRepositoryList.rectTransform)
    return self:_GetAreaRepositorySlotGroup(false, self.m_outRepositoryList)
end



FacCacheArea.GetAreaInRepositoryFluidSlotGroup = HL.Method().Return(HL.Table) << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.inRepositoryList.rectTransform)
    return self:_GetAreaRepositorySlotGroup(true, self.m_inRepositoryList)
end





FacCacheArea.PlayArrowAnimation = HL.Method(HL.String, HL.Opt(HL.Function)) << function(self, animationName, callback)
    self.view.decoArrowAnimation:PlayWithTween(animationName, callback)
end






FacCacheArea.DropItemToArea = HL.Method(HL.Forward('UIDragHelper'), HL.Boolean, HL.Opt(CS.Proto.ITEM_MOVE_MODE)) << function(self, dragHelper, isFluid, mode)
    for _, repo in ipairs(self.m_inRepositoryList) do
        if isFluid == repo:GetIsFluidCache() then
            if repo:TryDropItemToRepository(dragHelper, mode) == true then
                return
            end
        end
    end
end




FacCacheArea.GetDropToComponentId = HL.Method(HL.Forward('UIDragHelper')).Return(HL.Opt(HL.Number)) << function(self, dragHelper)
    for _, repo in ipairs(self.m_inRepositoryList) do
        for index = 1, repo.m_slotList:GetCount() do
            local cacheSlot = repo.m_slotList:GetItem(index)
            if cacheSlot:CanDrop(dragHelper) then
                return cacheSlot.m_cache.componentId
            end
        end
    end
    return nil
end



FacCacheArea.InitAreaNaviTarget = HL.Method() << function(self)
    if #self.m_inRepositoryList > 0 then
        self.m_inRepositoryList[#self.m_inRepositoryList]:SetFirstSlotToNaviTarget()
    end
end




FacCacheArea.CheckRepoNaviTargetTopLayer = HL.Method(HL.Boolean).Return(HL.Boolean) << function(self, isIn)
    if isIn then
        return self.view.inRepositoryList.inRepoNaviGroup.IsTopLayer
    else
        return self.view.outRepositoryList.outRepoNaviGroup.IsTopLayer
    end
    return false
end




FacCacheArea.AddNaviGroupSwitchInfo = HL.Method(HL.Table) << function(self, naviGroupInfos)
    table.insert(naviGroupInfos, {
        naviGroup = self.view.inRepositoryList.inRepoNaviGroup,
        subGroups = { self.view.outRepositoryList.outRepoNaviGroup },
        text = Language.LUA_INV_NAVI_SWITCH_TO_MACHINE,
        forceDefault = true,
    })
end






FacCacheArea.NaviTargetMoveToInCacheSlot = HL.Method(HL.Forward('Item'), HL.Forward('UIDragHelper'), HL.Boolean) << function(self, sourceItem, dragHelper, isFluid)
    local slotCount = 0
    for _, repo in ipairs(self.m_inRepositoryList) do
        if isFluid == repo:GetIsFluidCache() then
            local slotList = repo:GetRepositorySlotList()
            slotCount = slotCount + #slotList
        end
    end

    if slotCount > 1 then
        
        self.m_currDragHelper = dragHelper
        self.m_currMoveSourceItem = sourceItem
        InputManagerInst:ToggleBinding(self.m_moveConfirmBindingId, true)
        InputManagerInst:ToggleBinding(self.m_moveCancelBindingId, true)
        local ctrl = self:GetUICtrl()
        Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
            panelId = ctrl.panelId,
            isGroup = true,
            id = self.view.inputGroup.groupId,
            hintPlaceholder = ctrl.view.controllerHintPlaceholder,
            noHighlight = true,
            rectTransform = self.view.rectTransform,
        })

        for _, repo in ipairs(self.m_inRepositoryList) do
            if isFluid ~= repo:GetIsFluidCache() then
                repo:SetSlotListBtnEnabled(false)
            end
        end
        self.view.inRepositoryList.inRepoNaviGroup:NaviToThisGroup(true)
        self.view.inRepositoryList.inRepoNaviGroup.enablePartner = false
        self.m_currMoveSourceItem:SetSelected(true)
        self:_RefreshSlotButtonState(false)

        local textId = isFluid and "LUA_ITEM_ACTION_CACHE_AREA_SELECT_LIQUID_SLOT" or "LUA_ITEM_ACTION_CACHE_AREA_SELECT_NORMAL_SLOT"
        Notify(MessageConst.FAC_ON_MOVE_SHOW_CONTROLLER_MODE_HINT, Language[textId])
    else
        
        self:DropItemToArea(dragHelper, isFluid)
    end
end









FacCacheArea.OnStartUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    if not DeviceInfo.usingTouch then
        return
    end

    local fromBag = dragHelper.source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.ItemBag
    local fromDepot = dragHelper.source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.FactoryDepot
    if not fromBag and not fromDepot then
        return
    end

    local args = {
        isLeft = false,
        actions = {}
    }

    local realIndex = 0
    for _, repo in ipairs(self.m_inRepositoryList) do
        for k = 1, repo.m_slotList:GetCount() do
            local cacheSlot = repo.m_slotList:GetItem(k)
            realIndex = realIndex + 1
            if cacheSlot:CanDrop(dragHelper) then
                table.insert(args.actions, {
                    text = Language["LUA_MOBILE_ITEM_DRAG_GRID_TO_FAC_SLOT_" .. realIndex],
                    icon = "icon_common_move_to_machine",
                    action = function()
                        if self.m_isDestroyed then
                            return
                        end
                        cacheSlot:_OnDropItem(dragHelper)
                        dragHelper.uiDragItem:OnEndDrag(nil)
                    end
                })
            end
        end
    end
    if #args.actions == 0 then
        return
    end
    Notify(MessageConst.SHOW_ITEM_DRAG_HELPER, args)
end




FacCacheArea.OnEndUiDrag = HL.Method(HL.Forward('UIDragHelper')) << function(self, dragHelper)
    Notify(MessageConst.HIDE_ITEM_DRAG_HELPER)
end




HL.Commit(FacCacheArea)
return FacCacheArea
