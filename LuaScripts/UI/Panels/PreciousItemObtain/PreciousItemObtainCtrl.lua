local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget




PreciousItemObtainCtrl = HL.Class('PreciousItemObtainCtrl', uiCtrl.UICtrl)

PreciousItemObtainCtrl.m_itemId = HL.Field(HL.String) << ""
PreciousItemObtainCtrl.m_foresightGoToLog = HL.Field(HL.Table)
PreciousItemObtainCtrl.m_title = HL.Field(HL.String) << ""
PreciousItemObtainCtrl.m_obtainWayList = HL.Field(HL.Table)
PreciousItemObtainCtrl.m_cellCache = HL.Field(HL.Forward("UIListCache"))
PreciousItemObtainCtrl.m_selectedIndex = HL.Field(HL.Number) << 0
PreciousItemObtainCtrl.s_messages = HL.StaticField(HL.Table) << {}

PreciousItemObtainCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_itemId = arg and arg.itemId or ""
    self.m_foresightGoToLog = arg and arg.foresightGoToLog or nil
    self.m_title = arg and arg.title or Language.LUA_PRECIOUS_ITEM_OBTAIN_TITLE
    self.m_selectedIndex = arg and arg.selectedObtainWayIndex or 0
    self.view.titleText.text = self.m_title
    self.m_cellCache = UIUtils.genCellCache(self.view.reminderItemCell)

    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)
    self.view.mask.onClick:AddListener(function()
        self:_Close()
    end)

    self:BindInputPlayerAction("common_cancel", function()
        self:_Close()
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

PreciousItemObtainCtrl.OnShow = HL.Override() << function(self)
    self:_Refresh()
    if DeviceInfo.usingController then
        self:_InitController()
    end
end

PreciousItemObtainCtrl.OnHide = HL.Override() << function(self)
    if self.view.reminderScrollList then
        self.view.reminderScrollList.controllerScrollEnabled = false
    end
end

PreciousItemObtainCtrl.GetCurPhaseStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return {
        itemId = self.m_itemId,
        title = self.m_title,
        selectedObtainWayIndex = self.m_selectedIndex,
    }
end



PreciousItemObtainCtrl._Close = HL.Method() << function(self)
    self:PlayAnimationOutAndClose()
end

PreciousItemObtainCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    if self.view.reminderScrollList then
        self.view.reminderScrollList.controllerScrollEnabled = true
    end
    self:_FocusCell(self:_ResolveFocusIndex())
end

PreciousItemObtainCtrl._ResolveFocusIndex = HL.Method().Return(HL.Number) << function(self)
    local count = #self.m_obtainWayList
    if count == 0 then
        return 0
    end
    if self.m_selectedIndex > 0 and self.m_selectedIndex <= count then
        return self.m_selectedIndex
    end
    for index, info in ipairs(self.m_obtainWayList) do
        if info.canJump then
            return index
        end
    end
    return 1
end

PreciousItemObtainCtrl._FocusCell = HL.Method(HL.Number) << function(self, index)
    if index <= 0 then
        return
    end
    local cell = self.m_cellCache:Get(index)
    local naviTarget = cell and cell.inputBindingGroupNaviDecorator
    if not naviTarget then
        return
    end
    self.m_selectedIndex = index
    self:_ScrollCellIntoView(naviTarget)
    self:SetNaviTarget(naviTarget)
    self:_UpdateConfirmBinding()
end

PreciousItemObtainCtrl._ScrollCellIntoView = HL.Method(HL.Any) << function(self, naviTarget)
    if not self.view.reminderScrollList or not naviTarget then
        return
    end
    local scrollRect = self.view.reminderScrollList:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
    if scrollRect then
        scrollRect:ScrollToNaviTarget(naviTarget)
    end
end

PreciousItemObtainCtrl._UpdateConfirmBinding = HL.Method() << function(self)
    local cell = self.m_cellCache:Get(self.m_selectedIndex)
    local btnGoto = cell and cell.btnGoto
    if not btnGoto then
        return
    end
    local bindingId = btnGoto.onClick.bindingId
    if bindingId <= 0 then
        return
    end
    local info = self.m_obtainWayList[self.m_selectedIndex]
    self:_ApplyGotoControllerHint(btnGoto, info ~= nil and info.canJump)
end

PreciousItemObtainCtrl._ApplyGotoControllerHint = HL.Method(HL.Any, HL.Boolean) << function(self, btnGoto, canJump)
    if not DeviceInfo.usingController or not btnGoto then
        return
    end
    local bindingId = btnGoto.onClick.bindingId
    if bindingId <= 0 then
        return
    end
    InputManagerInst:ToggleBinding(bindingId, canJump)
    if canJump then
        InputManagerInst:SetBindingText(bindingId, I18nUtils.GetText("rewardshow_region_go"))
    end
    Notify(MessageConst.REFRESH_CONTROLLER_HINT)
end

PreciousItemObtainCtrl._Refresh = HL.Method() << function(self)
    self.m_obtainWayList = self:_BuildObtainWayList(self.m_itemId)
    self.m_cellCache:Refresh(#self.m_obtainWayList, function(cell, index)
        self:_RefreshCell(cell, self.m_obtainWayList[index], index)
    end)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.m_cellCache.m_parent)
end

PreciousItemObtainCtrl._RefreshCell = HL.Method(HL.Any, HL.Table, HL.Number) << function(self, cell, info, index)
    if cell.titleTxt then
        cell.titleTxt.text = info.title or ""
    end
    if cell.conditionTxt then
        cell.conditionTxt.text = info.conditionText or ""
    end
    if cell.iconImg then
        if not string.isEmpty(info.iconPath) then
            cell.iconImg:LoadSpriteWithOutFormat(info.iconPath)
        elseif info.iconFolder and info.iconId then
            cell.iconImg:LoadSprite(info.iconFolder, info.iconId)
        end
    end

    local canJump = info.canJump
    if cell.rightBg then
        cell.rightBg.gameObject:SetActive(canJump)
    end
    if cell.decoPoint then
        cell.decoPoint.gameObject:SetActive(canJump)
    end

    local btnGoto = cell.btnGoto
    if btnGoto then
        local iconTrans = btnGoto.transform:Find("Root/Icon")
        if iconTrans then
            iconTrans.gameObject:SetActive(canJump)
        end

        if cell.btnGotoStateController then
            cell.btnGotoStateController:SetState(canJump and "WhiteState" or "DisableState")
        end
        if cell.btnGotoTxt then
            cell.btnGotoTxt.text = canJump
                and Language.LUA_PRECIOUS_ITEM_OBTAIN_BTN_GOTO
                or Language.LUA_PRECIOUS_ITEM_OBTAIN_BTN_UNAVAILABLE
        end
        
        btnGoto.customBindingViewLabelText = ""
        btnGoto.hintTextId = ""
        btnGoto:ChangeActionOnSetNaviTarget(canJump and ActionOnSetNaviTarget.PressConfirmTriggerOnClick or ActionOnSetNaviTarget.None)

        btnGoto.interactable = canJump or DeviceInfo.usingController
        if btnGoto.targetGraphic then
            btnGoto.targetGraphic.raycastTarget = canJump
        end
        btnGoto.onClick:RemoveAllListeners()
        if canJump and info.phaseId then
            btnGoto.onClick:AddListener(function()
                self:_OnClickGoto(info)
            end)
        end
        if DeviceInfo.usingController then
            local bindingId = btnGoto.onClick.bindingId
            if bindingId > 0 then
                InputManagerInst:ToggleBinding(bindingId, false)
            end
        end
    end

    if cell.inputBindingGroupNaviDecorator then
        cell.inputBindingGroupNaviDecorator.enabled = true
        cell.inputBindingGroupNaviDecorator.onGroupSetAsNaviTarget:RemoveAllListeners()
        cell.inputBindingGroupNaviDecorator.onGroupSetAsNaviTarget:AddListener(function(isTarget)
            if not isTarget then
                return
            end
            self.m_selectedIndex = index
            self:_UpdateConfirmBinding()
        end)
    end
end

PreciousItemObtainCtrl._OnClickGoto = HL.Method(HL.Table) << function(self, info)
    if UIManager:ShouldBlockObtainWaysPhaseJump(info.phaseId) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED)
        return
    end
    if info.blockJumpToast and not string.isEmpty(info.blockJumpToast) then
        Notify(MessageConst.SHOW_TOAST, info.blockJumpToast)
        return
    end
    local log = self.m_foresightGoToLog
    if log and log.charId then
        local itemIdList = info.phaseArgs and info.phaseArgs.activityId or ""
        EventLogManagerInst:GameEvent_CultiOverviewGoTo(
            log.charId, PhaseManager:GetPhaseName(info.phaseId), itemIdList or "",
            log.charStatus, log.sourceBlock, false,"")
    end
    PhaseManager:GoToPhase(info.phaseId, info.phaseArgs)
    self:Close()
end

PreciousItemObtainCtrl._BuildObtainWayList = HL.Method(HL.String).Return(HL.Table) << function(self, itemId)
    if string.isEmpty(itemId) then
        return {}
    end
    local ok, itemCfg = Tables.itemTable:TryGetValue(itemId)
    if not ok then
        return {}
    end

    local list = {}
    local sortIndex = 0
    local obtainWayIds = itemCfg.obtainWayIds
    local obtainWayId
    local obtainWayCfg
    local item
    if obtainWayIds then
        for i = 0, obtainWayIds.Count - 1 do
            obtainWayId = obtainWayIds[i]
            _, obtainWayCfg = Tables.systemJumpTable:TryGetValue(obtainWayId)
            if obtainWayCfg then
                sortIndex = sortIndex + 1
                item = self:_ResolveObtainWayItem(itemId, obtainWayId, obtainWayCfg, sortIndex)
                if item then
                    table.insert(list, item)
                end
            end
        end
    end

    if #list == 0 and itemCfg.noObtainWayId and itemCfg.noObtainWayId.Count > 0 then
        local find, showNoObtainWayId = self:_FindShowNoObtainWayId(itemCfg)
        if find then
            local noObtainItem = self:_BuildNoObtainWayItem(itemId, showNoObtainWayId)
            if noObtainItem then
                table.insert(list, noObtainItem)
            end
        end
        return list
    end

    
    if self.m_foresightGoToLog then
        local _, settingCfg = Tables.foresightGrowthConfigTable:TryGetValue("ObtainSetting")
        local idList = settingCfg and settingCfg.stringList
        if idList then
            local order = {}
            for i = 0, idList.Count - 1, 2 do
                order[idList[i]] = i
            end
            for _, item in ipairs(list) do
                item.sortOrder = order[item.obtainWayId] or 9999
            end
        end
    end
    table.sort(list, function(a, b)
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        return a.sortIndex < b.sortIndex
    end)
    return list
end





PreciousItemObtainCtrl._RewardContainsItem = HL.Method(HL.String, HL.String).Return(HL.Boolean) << function(self, rewardId, itemId)
    if string.isEmpty(rewardId) then
        return false
    end
    for _, bundle in ipairs(UIUtils.getRewardItems(rewardId)) do
        if bundle.id == itemId then
            return true
        end
    end
    return false
end

PreciousItemObtainCtrl._CanShowObtainWay = HL.Method(HL.String, HL.Any).Return(HL.Boolean) << function(self, obtainWayId, obtainWayCfg)
    local showSucc, showCondition = Tables.obtainWayShowCondTable:TryGetValue(obtainWayId)
    if showSucc and not ItemObtainWaysUtils.CheckObtainWayCondition(showCondition) then
        return false
    end
    return Utils.isSystemUnlocked(obtainWayCfg.bindSystem)
end

PreciousItemObtainCtrl._BuildPhaseJump = HL.Method(HL.Any, HL.String).Return(HL.Any, HL.Any, HL.String) << function(self, obtainWayCfg, itemId)
    local phaseId = PhaseId[obtainWayCfg.phaseId]
    local phaseArgs = Utils.buildSystemJumpPhaseArgsWithItem(obtainWayCfg, itemId)
    local blockJumpToast = ""
    if phaseId ~= nil and not PhaseManager:CheckCanOpenPhase(phaseId, phaseArgs) then
        if obtainWayCfg.bindSystem == GEnums.UnlockSystemType.Map then
            blockJumpToast = Language.LUA_OBTAIN_WAYS_MAP_JUMP_BLOCKED
        else
            blockJumpToast = Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED
        end
    end
    return phaseId, phaseArgs, blockJumpToast
end

PreciousItemObtainCtrl._ApplyBrowsableResult = HL.Method(HL.Table, HL.String, HL.Any, HL.Any, HL.String).Return(HL.Table) << function(self, result, conditionText, phaseId, phaseArgs, blockJumpToast)
    result.conditionText = conditionText
    result.canJump = true
    result.sortOrder = 0
    result.phaseId = phaseId
    result.phaseArgs = phaseArgs
    result.blockJumpToast = blockJumpToast
    return result
end


PreciousItemObtainCtrl._GetObtainIcon = HL.Method(HL.Any).Return(HL.Any, HL.Any, HL.Any) << function(self, obtainWayCfg)
    if self.m_foresightGoToLog and obtainWayCfg and not string.isEmpty(obtainWayCfg.id) then
        local ok, settingCfg = Tables.foresightGrowthConfigTable:TryGetValue("ObtainSetting")
        local idList = settingCfg and settingCfg.stringList
        if idList then
            for i = 0, idList.Count - 1, 2 do
                if idList[i] == obtainWayCfg.id then
                    local iconPath = idList[i + 1]
                    if not string.isEmpty(iconPath) then
                        if string.sub(iconPath, -4) ~= ".png" then
                            iconPath = iconPath .. ".png"
                        end
                        return nil, nil, iconPath
                    end
                end
            end
        end
    end
    if obtainWayCfg and obtainWayCfg.iconId then
        return UIConst.UI_SPRITE_ITEM_TIPS, obtainWayCfg.iconId, nil
    end
    return nil, nil, nil
end

PreciousItemObtainCtrl._ResolveActivityObtainWay = HL.Method(HL.String, HL.String, HL.Any).Return(HL.Opt(HL.Table)) << function(self, itemId, obtainWayId, obtainWayCfg)
    if not self:_CanShowObtainWay(obtainWayId, obtainWayCfg) then
        return nil
    end

    local itemName = Tables.itemTable:GetValue(itemId).name
    local result = {
        title = obtainWayCfg.desc,
        conditionText = string.format(Language.LUA_PRECIOUS_ITEM_OBTAIN_ACTIVITY_EMPTY, itemName),
        canJump = false,
        sortOrder = 1,
    }

    local candidates = {}
    for _, activity in cs_pairs(GameInstance.player.activitySystem:GetAllActivities()) do
        local ok, activityCfg = Tables.activityTable:TryGetValue(activity.id)
        if not ok or not self:_RewardContainsItem(activityCfg.rewardId, itemId) then
            goto continue
        end
        if activity:GetCompleteSortId() ~= 0 then
            goto continue
        end
        local isTimed = (activity.endTime and activity.endTime > 0) or activityCfg.isRecommend
        table.insert(candidates, {
            id = activity.id,
            groupOrder = isTimed and 0 or 1,
            sortId = -(activityCfg.sortId or 0),
        })
        ::continue::
    end
    table.sort(candidates, Utils.genSortFunction({ "groupOrder", "sortId", "id" }, true))
    local targetActivityId = candidates[1] and candidates[1].id or ""

    if string.isEmpty(targetActivityId) then
        return result
    end

    local phaseId = PhaseId.ActivityCenter
    local phaseArgs = { activityId = targetActivityId, gotoCenter = true }
    local blockJumpToast = ""
    if not PhaseManager:CheckCanOpenPhase(phaseId, phaseArgs) then
        blockJumpToast = Language.LUA_OBTAIN_WAYS_JUMP_BLOCKED
    end
    return self:_ApplyBrowsableResult(result, Language.LUA_PRECIOUS_ITEM_OBTAIN_ACTIVITY_HAS_REWARD, phaseId, phaseArgs, blockJumpToast)
end

PreciousItemObtainCtrl._ResolveBattlePassObtainWay = HL.Method(HL.String, HL.String, HL.Any).Return(HL.Opt(HL.Table)) << function(self, itemId, obtainWayId, obtainWayCfg)
    if not self:_CanShowObtainWay(obtainWayId, obtainWayCfg) then
        return nil
    end
    if not BattlePassUtils.CheckBattlePassSeasonValid() then
        return nil
    end

    local result = {
        title = obtainWayCfg.desc,
        conditionText = Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_ALL_CLAIMED,
        canJump = false,
        sortOrder = 1,
    }

    local bpSystem = GameInstance.player.battlePassSystem
    local okSeason, seasonData = Tables.battlePassSeasonTable:TryGetValue(bpSystem.seasonData.seasonId)
    if not okSeason then
        return nil
    end
    local okGroup, levelGroup = Tables.battlePassLevelTable:TryGetValue(seasonData.levelGroupId)
    if not okGroup then
        return nil
    end
    local okOverride, overrideGroup = Tables.battlePassOverrideLevelTable:TryGetValue(seasonData.ovrLvRewardGroupId)

    local entries = {}
    for level, levelData in pairs(levelGroup.levelInfos) do
        local originiumRewardId = levelData.originiumRewardId
        local payRewardId = levelData.payRewardId
        if okOverride then
            local hasOverrideLevel, overrideLevelData = overrideGroup.levelInfos:TryGetValue(level)
            if hasOverrideLevel then
                originiumRewardId = overrideLevelData.originiumRewardId
                payRewardId = overrideLevelData.payRewardId
            end
        end
        if self:_RewardContainsItem(originiumRewardId, itemId) then
            table.insert(entries, { level = level, trackType = GEnums.BPTrackType.ORIGINIUM })
        end
        if self:_RewardContainsItem(payRewardId, itemId) then
            table.insert(entries, { level = level, trackType = GEnums.BPTrackType.PAY })
        end
    end
    if #entries == 0 then
        return nil
    end
    table.sort(entries, Utils.genSortFunction({ "level" }, true))

    local phaseId, phaseArgs, blockJumpToast = self:_BuildPhaseJump(obtainWayCfg, itemId)
    if phaseId == nil then
        return nil
    end

    local curLevel = bpSystem.levelData.currLevel
    local originiumActive = BattlePassUtils.CheckOriginiumTrackActive()
    local payActive = BattlePassUtils.CheckPayTrackActive()
    local originiumName = BattlePassUtils.GetOriginiumTrackInfo().name
    local payName = BattlePassUtils.GetPayTrackInfo().name

    local ungainedEntries = {}
    for _, entry in ipairs(entries) do
        if not BattlePassUtils.CheckIsRewardGained(entry.trackType, entry.level) then
            table.insert(ungainedEntries, entry)
        end
    end
    if #ungainedEntries == 0 then
        return result
    end

    local firstOriginium, firstPay
    for _, entry in ipairs(ungainedEntries) do
        if not firstOriginium and entry.trackType == GEnums.BPTrackType.ORIGINIUM then
            firstOriginium = entry
        end
        if not firstPay and entry.trackType == GEnums.BPTrackType.PAY then
            firstPay = entry
        end
    end

    
    if not originiumActive then
        return self:_ApplyBrowsableResult(result, string.format(Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_UNLOCK_TRACK, originiumName), phaseId, phaseArgs, blockJumpToast)
    end

    
    local focusEntry = firstOriginium or firstPay
    if focusEntry and curLevel < focusEntry.level then
        return self:_ApplyBrowsableResult(result, string.format(Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_NEXT_REWARD, focusEntry.level), phaseId, phaseArgs, blockJumpToast)
    end

    
    if firstOriginium then
        return self:_ApplyBrowsableResult(result, Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_CAN_CLAIM, phaseId, phaseArgs, blockJumpToast)
    end

    
    if not payActive then
        return self:_ApplyBrowsableResult(result, string.format(Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_UNLOCK_TRACK, payName), phaseId, phaseArgs, blockJumpToast)
    end

    
    if firstPay then
        return self:_ApplyBrowsableResult(result, Language.LUA_PRECIOUS_ITEM_OBTAIN_BP_CAN_CLAIM, phaseId, phaseArgs, blockJumpToast)
    end

    return result
end

PreciousItemObtainCtrl._ResolveShopObtainWay = HL.Method(HL.String, HL.String, HL.Any).Return(HL.Opt(HL.Table)) << function(self, itemId, obtainWayId, obtainWayCfg)
    if not self:_CanShowObtainWay(obtainWayId, obtainWayCfg) then
        return nil
    end

    local result = {
        title = obtainWayCfg.desc,
        conditionText = Language.LUA_PRECIOUS_ITEM_OBTAIN_SHOP_SOLD_OUT,
        canJump = false,
        sortOrder = 1,
    }

    local phaseId, phaseArgs, blockJumpToast = self:_BuildPhaseJump(obtainWayCfg, itemId)
    if phaseId == nil then
        return nil
    end

    local shopId = phaseArgs and phaseArgs.shopId
    local goodsId = phaseArgs and phaseArgs.goodsId
    local shopSystem = GameInstance.player.shopSystem
    local totalRemain = 0
    local hasUnlimited = false

    if not string.isEmpty(goodsId) then
        local remain = shopSystem:GetRemainCountByGoodsId(shopId, goodsId)
        if remain == -1 then
            hasUnlimited = true
        elseif remain > 0 then
            totalRemain = totalRemain + remain
        end
    elseif not string.isEmpty(shopId) then
        local shopData = shopSystem:GetShopData(shopId)
        if shopData then
            local goodList = shopData:GetOpenGoodList()
            for i = 0, goodList.Count - 1 do
                local goodsData = goodList[i]
                local goodsTableData = Tables.shopGoodsTable[goodsData.goodsTemplateId]
                if goodsTableData and self:_RewardContainsItem(goodsTableData.rewardId, itemId) then
                    local remain = shopSystem:GetRemainCountByGoodsId(shopId, goodsData.goodsId)
                    if remain == -1 then
                        hasUnlimited = true
                        break
                    elseif remain > 0 then
                        totalRemain = totalRemain + remain
                    end
                end
            end
        end
    end

    if hasUnlimited or totalRemain > 0 then
        result.conditionText = hasUnlimited
            and Language.LUA_PRECIOUS_ITEM_OBTAIN_SHOP_REMAIN_UNLIMITED
            or string.format(Language.LUA_PRECIOUS_ITEM_OBTAIN_SHOP_REMAIN, totalRemain)
        result.canJump = true
        result.sortOrder = 0
        result.phaseId = phaseId
        result.phaseArgs = phaseArgs
        result.blockJumpToast = blockJumpToast
    end
    return result
end

PreciousItemObtainCtrl._ResolveGenericObtainWay = HL.Method(HL.String, HL.String, HL.Any).Return(HL.Opt(HL.Table)) << function(self, itemId, obtainWayId, obtainWayCfg)
    if not self:_CanShowObtainWay(obtainWayId, obtainWayCfg) then
        return nil
    end

    local phaseId, phaseArgs, blockJumpToast = self:_BuildPhaseJump(obtainWayCfg, itemId)
    if phaseId == nil then
        return nil
    end

    return self:_ApplyBrowsableResult({
        title = obtainWayCfg.desc,
        conditionText = "",
        canJump = false,
        sortOrder = 1,
    }, "", phaseId, phaseArgs, blockJumpToast)
end

PreciousItemObtainCtrl._ResolveObtainWayItem = HL.Method(HL.String, HL.String, HL.Any, HL.Number).Return(HL.Opt(HL.Table)) << function(self, itemId, obtainWayId, obtainWayCfg, sortIndex)
    local phaseId = PhaseId[obtainWayCfg.phaseId]
    local item
    if obtainWayId == "item_obtain_activity" then
        item = self:_ResolveActivityObtainWay(itemId, obtainWayId, obtainWayCfg)
    elseif phaseId == PhaseId.BattlePass then
        item = self:_ResolveBattlePassObtainWay(itemId, obtainWayId, obtainWayCfg)
    elseif string.find(obtainWayId, "item_obtain_shop", 1, true) == 1 then
        item = self:_ResolveShopObtainWay(itemId, obtainWayId, obtainWayCfg)
    else
        item = self:_ResolveGenericObtainWay(itemId, obtainWayId, obtainWayCfg)
    end
    if not item then
        return nil
    end
    item.obtainWayId = obtainWayId
    item.sortIndex = sortIndex
    item.iconFolder, item.iconId, item.iconPath = self:_GetObtainIcon(obtainWayCfg)
    return item
end

PreciousItemObtainCtrl._FindShowNoObtainWayId = HL.Method(HL.Any).Return(HL.Boolean, HL.String) << function(self, itemCfg)
    if itemCfg == nil or itemCfg.noObtainWayId == nil or itemCfg.noObtainWayId.Count == 0 then
        return false, ""
    end

    for csIndex = 0, itemCfg.noObtainWayId.Count - 1 do
        local conditionId = itemCfg.noObtainWayConditionId[csIndex]
        if csIndex >= itemCfg.noObtainWayConditionId.Count or not ItemObtainWaysUtils.CheckObtainWayCondition(conditionId) then
            return true, itemCfg.noObtainWayId[csIndex]
        end
    end

    return false, ""
end

PreciousItemObtainCtrl._BuildNoObtainWayItem = HL.Method(HL.String, HL.String).Return(HL.Opt(HL.Table)) << function(self, itemId, noObtainWayId)
    local _, obtainWayCfg = Tables.systemJumpTable:TryGetValue(noObtainWayId)
    if not obtainWayCfg then
        return nil
    end
    local iconFolder, iconId, iconPath = self:_GetObtainIcon(obtainWayCfg)
    return {
        title = obtainWayCfg.desc,
        conditionText = "",
        canJump = false,
        sortOrder = 1,
        sortIndex = 0,
        obtainWayId = noObtainWayId,
        iconFolder = iconFolder,
        iconId = iconId,
        iconPath = iconPath,
    }
end



HL.Commit(PreciousItemObtainCtrl)
