local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.AdventureDungeon

local SeriesTableFilterItem = {
    [GEnums.DungeonCategoryType.BasicResource] = {},
    [GEnums.DungeonCategoryType.CharResource] = {},
    [GEnums.DungeonCategoryType.BossRush] = {},
    [GEnums.DungeonCategoryType.SpecialResource] = {},
}

local IsSeriesTableFiltered = false

local TabDataList = {
    {
        type = GEnums.DungeonCategoryType.CharResource,
        tabName = "ui_AdventureDungeonPanel_title_charmaterial",
        imgPath = "deco_adventure_d_material",
    },
    {
        type = GEnums.DungeonCategoryType.BasicResource,
        tabName = "ui_AdventureDungeonPanel_title_basematerial",
        imgPath = "deco_adventure_d_currency",
    },
    {
        type = GEnums.DungeonCategoryType.BossRush,
        tabName = "ui_AdventureDungeonPanel_title_boss",
        imgPath = "deco_adventure_d_leaderchallenge",
    },
    {
        type = GEnums.DungeonCategoryType.SpecialResource,
        tabName = "ui_AdventureDungeonPanel_title_specialResource",
        imgPath = "deco_adventure_d_challengethis",
    },
}
















































AdventureDungeonCtrl = HL.Class('AdventureDungeonCtrl', uiCtrl.UICtrl)







AdventureDungeonCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_SCENE_GRADE_CHANGE_NOTIFY] = '_OnSceneGradeChangeNotify',
    [MessageConst.ON_CHANGE_ADVENTURE_DUNGEON_TAB] = '_OnChangeTab',
    [MessageConst.ON_PHASE_ADVENTURE_BOOK_BEHIND] = '_OnPhaseBehind',
    [MessageConst.ON_BLOCK_KEYBOARD_EVENT_PANEL_ORDER_CHANGED] = '_OnBlockKeyboardEventPanelOrderChanged',
}




AdventureDungeonCtrl.m_genTabCells = HL.Field(HL.Forward("UIListCache"))


AdventureDungeonCtrl.m_genCategoryCells = HL.Field(HL.Function)


AdventureDungeonCtrl.m_genSingleCategoryCells = HL.Field(HL.Function)


AdventureDungeonCtrl.m_curTabIndex = HL.Field(HL.Number) << 1


AdventureDungeonCtrl.m_dungeonCategoryInfos = HL.Field(HL.Table)


AdventureDungeonCtrl.m_forbidResetTabIndex = HL.Field(HL.Boolean) << false


AdventureDungeonCtrl.m_onGotoDungeon = HL.Field(HL.Function)


AdventureDungeonCtrl.m_useDungeonList = HL.Field(HL.Boolean) << true


AdventureDungeonCtrl.m_naviOnLeft = HL.Field(HL.Boolean) << true



AdventureDungeonCtrl.m_dropdownDomainIds = HL.Field(HL.Table)


AdventureDungeonCtrl.m_filterdInfos = HL.Field(HL.Table)



AdventureDungeonCtrl.m_currSelectDropdownIndex = HL.Field(HL.Number) << 0


AdventureDungeonCtrl.m_needResetSingleListTarget = HL.Field(HL.Boolean) << false







AdventureDungeonCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_phase = arg.phase
    self:_InitShortCut()
    self:_InitData()
    self:_UpdateData()
    self:_InitUI()
    self:_RefreshAllUI()
end



AdventureDungeonCtrl.OnClose = HL.Override() << function(self)
    
    if self.m_curTabIndex > 0 and self.m_curTabIndex <= self.m_genTabCells:GetCount() then
        self:_ReadTabRedDot(self.m_curTabIndex)
    end
end




AdventureDungeonCtrl._OnChangeTab = HL.Method(HL.Any) << function(self, arg)
    local dungeonTab = arg
    local index = 1
    for _, categoryInfo in pairs(self.m_dungeonCategoryInfos) do
        if categoryInfo.tabJumpName == dungeonTab then
            break
        end
        index = index + 1
    end
    if index > #self.m_dungeonCategoryInfos then
        logger.error(ELogChannel.UI, "[AdventureDungeonCtrl._OnChangeTab] 跳转到指定dungeonTab失败，可能是没解锁或配置错，tabName:" .. dungeonTab)
        index = 1
    end
    self.m_curTabIndex = math.min(index, #self.m_dungeonCategoryInfos)
    local cell = self.m_genTabCells:Get(self.m_curTabIndex)
    cell.toggle:SetIsOnWithoutNotify(true)
    self:_OnClickTabToggle(self.m_curTabIndex, true)
end



AdventureDungeonCtrl._OnBlockKeyboardEventPanelOrderChanged = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end
    
    
    local _, bookCtrl = UIManager:IsOpen(PanelId.AdventureBook)
    if bookCtrl then
        local isEnabled = InputManagerInst:IsGroupEnabled(bookCtrl.view.inputGroup.groupId)
        if isEnabled then
            InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, not self.m_naviOnLeft)
            InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, self.m_naviOnLeft)
        else
            InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, false)
            InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, false)
        end
    end
end




AdventureDungeonCtrl._InitUI = HL.Method() << function(self)
    
    self.m_genTabCells = UIUtils.genCellCache(self.view.tabTogCell)
    
    self.m_genCategoryCells = UIUtils.genCachedCellFunction(self.view.dungeonCategoryList)
    self.view.dungeonCategoryList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_genCategoryCells(obj)
        self:_UpdateDungeonCategory(cell, LuaIndex(csIndex))
    end)
    self.view.dungeonCategoryListNaviGroup.getDefaultSelectableFunc = function()
        local firstCell = self.m_genCategoryCells(1)
        if firstCell ~= nil then
            return firstCell.view.naviDecorator
        end
    end
    
    self.m_genSingleCategoryCells = UIUtils.genCachedCellFunction(self.view.singleCategoryNode.singleCategoryList)
    self.view.singleCategoryNode.singleCategoryList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_genSingleCategoryCells(obj)
        self:_UpdateSingleDungeonCell(cell, LuaIndex(csIndex))
    end)
    self.view.singleCategoryNode.naviGroup.getDefaultSelectableFunc = function()
        local firstCell = self.m_genSingleCategoryCells(1)
        if firstCell ~= nil then
            return firstCell.view.naviDecorator
        end
    end
    
    if self.view.singleCategoryListReddot then
        self.view.singleCategoryListReddot.getRedDotStateAt = function(csIndex)
            return self:GetRedDotStateAt(csIndex)
        end
    end
end



AdventureDungeonCtrl._InitData = HL.Method() << function(self)
    
    if not IsSeriesTableFiltered then
        IsSeriesTableFiltered = true
        for _, item in pairs(Tables.dungeonSeriesTable) do
            local category = item.dungeonCategory
            if SeriesTableFilterItem[category] then
                table.insert(SeriesTableFilterItem[category], item)
            end
        end
    end
    
    self.m_onGotoDungeon = function()
        self.m_forbidResetTabIndex = true
    end
    
    self:_HandleStaminaDiscount()
end



AdventureDungeonCtrl.OnShow = HL.Override() << function(self)
    self.m_forbidResetTabIndex = false

    if DeviceInfo.usingController then
        local cell = self.m_genTabCells:Get(self.m_curTabIndex)
        if cell then
            self.m_naviOnLeft = true
            InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, not self.m_naviOnLeft)
            InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, self.m_naviOnLeft)
            InputManagerInst.controllerNaviManager:SetTarget(cell.toggle)
        end
    end

    if not string.isEmpty(self.m_phase.m_dungeonTab) then
        local dungeonTab = self.m_phase.m_dungeonTab
        self.m_phase.m_dungeonTab = ""
        self:_OnChangeTab(dungeonTab)
    end

    Notify(MessageConst.HIDE_ITEM_TIPS)
end



AdventureDungeonCtrl.OnHide = HL.Override() << function(self)
    if self.m_forbidResetTabIndex then
        return
    end
    local count = self.m_genTabCells:GetCount()
    if count > 0 then
        local cell = self.m_genTabCells:Get(1)
        cell.toggle.isOn = true
    end
end



AdventureDungeonCtrl._OnPhaseBehind = HL.Method() << function(self)
    if self.view.gameObject.activeSelf then
        self.m_forbidResetTabIndex = true
    end
end



AdventureDungeonCtrl._UpdateData = HL.Method() << function(self)
    self.m_dungeonCategoryInfos = { }
    for _, v in pairs(TabDataList) do
        self:_InitDataCommonDungeon(v.type, v.tabName, v.imgPath)
    end
    self:_InitDataMonsterSpawnPoint()
    
    self.m_curTabIndex = math.min(self.m_curTabIndex, #self.m_dungeonCategoryInfos)
end



AdventureDungeonCtrl._RefreshAllUI = HL.Method() << function(self)
    self.m_genTabCells:Refresh(#self.m_dungeonCategoryInfos, function(cell, luaIndex)
        self:_RefreshUITabCell(cell, luaIndex)
    end)
    self:_OnClickTabToggle(self.m_curTabIndex, true)
    local cell = self.m_genTabCells:Get(1)
    if cell then
        InputManagerInst.controllerNaviManager:SetTarget(cell.toggle)
    end
end




AdventureDungeonCtrl._OnSceneGradeChangeNotify = HL.Method(HL.Table) << function(self, args)
    self:_UpdateData()
    self:_RefreshAllUI()
end



AdventureDungeonCtrl._InitShortCut = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self:BindInputPlayerAction("adventure_dungeon_right", function()
        logger.info("adventure_dungeon_right")
        self.m_naviOnLeft = false
        InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, true)
        InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, false)
        if self.m_useDungeonList then
            self.view.dungeonCategoryListNaviGroup:NaviToThisGroup(true)
        else
            self.view.singleCategoryNode.naviGroup:NaviToThisGroup(true)
        end
    end, self.view.tabTogMonoTarget.groupId)
    self:BindInputPlayerAction("adventure_dungeon_right_hint", function()
        logger.info("adventure_dungeon_right")
        self.m_naviOnLeft = false
        InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, true)
        InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, false)
        if self.m_useDungeonList then
            self.view.dungeonCategoryListNaviGroup:NaviToThisGroup(true)
        else
            self.view.singleCategoryNode.naviGroup:NaviToThisGroup(true)
        end
    end, self.view.tabTogMonoTarget.groupId)

    self:BindInputPlayerAction("adventure_dungeon_left", function()
        logger.info("adventure_dungeon_left")
        self.m_naviOnLeft = true
        InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, false)
        InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, true)
        self.view.tabNaviGroup:NaviToThisGroup()
    end, self.view.slideNodeMonoTarget.groupId)
    self:BindInputPlayerAction("adventure_dungeon_left_hint", function()
        logger.info("adventure_dungeon_left")
        self.m_naviOnLeft = true
        InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, false)
        InputManagerInst:ToggleGroup(self.view.tabTogMonoTarget.groupId, true)
        self.view.tabNaviGroup:NaviToThisGroup()
    end, self.view.slideNodeMonoTarget.groupId)

    InputManagerInst:ToggleGroup(self.view.slideNodeMonoTarget.groupId, false)
end








AdventureDungeonCtrl._InitDataCommonDungeon = HL.Method(HL.Any, HL.String, HL.String)
    << function(self, categoryType, tabName, tabImg)
    
    local isCategoryUnlocked = GameInstance.player.adventure:IsAdventureDungeonFirCategoryUnlock(categoryType)

    if not isCategoryUnlocked then
        return
    end
    
    local tableDataList = SeriesTableFilterItem[categoryType]
    if (#tableDataList <= 0) then
        return
    end
    
    local newCategoryInfo = {
        tabName = tabName,
        tabImgPath = tabImg,
        tabJumpName = categoryType:ToString(),
        dungeonInfosList = {},
        subGameIds = {},
        showRelief = false,
    }
    
    local tempTable = {}    
    for _, tableData in pairs(tableDataList) do
        local isUnlocked = GameInstance.player.adventure:IsAdventureDungeonCategoryTypeUnlocked(tableData.id, tableData.dungeonCategory)

        if isUnlocked then
            local category2ndType = tableData.dungeonCategory2nd
            local infosBundle = tempTable[category2ndType]
            if not infosBundle then
                local cfgExist, category2ndTypeCfg = Tables.DungeonCategory2ndTable:TryGetValue(category2ndType)
                infosBundle = {
                    category2ndType = category2ndType:GetHashCode(),
                    name = cfgExist and category2ndTypeCfg.name or "",
                    infos = {},
                }
                tempTable[tableData.dungeonCategory2nd] = infosBundle
            end
            
            local info = self:_HandleAndCreateSeriesInfo(tableData, newCategoryInfo)
            if info then
                
                table.insert(infosBundle.infos, info)
            end
            if info.costStamina then
                newCategoryInfo.showRelief = true
            end
        end
    end
    
    for _, v in pairs(tempTable) do
        table.sort(v.infos, Utils.genSortFunction({ "sortId" }, true))
        table.insert(newCategoryInfo.dungeonInfosList, v)
    end
    table.sort(newCategoryInfo.dungeonInfosList, Utils.genSortFunction({ "category2ndType" }, true))
    
    table.insert(self.m_dungeonCategoryInfos, newCategoryInfo)
end





AdventureDungeonCtrl._HandleAndCreateSeriesInfo = HL.Method(HL.Any,  HL.Table).Return(HL.Table)
    << function(self, seriesCfg, categoryInfo)
    
    local hasCfg, dungeonTypeCfg = Tables.dungeonTypeTable:TryGetValue(seriesCfg.gameCategory)
    if hasCfg then
        local dungeonCategory = seriesCfg.dungeonCategory
        local seriesId = seriesCfg.id
        local isActive = (
            (dungeonCategory == GEnums.DungeonCategoryType.CharResource or
            dungeonCategory == GEnums.DungeonCategoryType.BasicResource or
            dungeonCategory == GEnums.DungeonCategoryType.SpecialResource or
            dungeonCategory == GEnums.DungeonCategoryType.BossRush) and
            (GameInstance.dungeonManager:IsDungeonInteractiveActive(seriesId) or
            dungeonCategory == GEnums.DungeonCategoryType.BossRush)
        )
        local info = {
            seriesId = seriesId,
            sortId = seriesCfg.sortId,
            mapMarkType = dungeonTypeCfg.mapMarkType,
            dungeonImg = self:_GetDungeonImg(seriesCfg.includeDungeonIds),
            dungeonRoleImg = seriesCfg.dungeonRoleImg,
            dungeonName = seriesCfg.name,
            dungeonCategory = dungeonCategory,
            staminaTxt = "",
            isActive = isActive,
            rewardInfos = self:_ProcessDungeonSeriesRewards(seriesId,
                (dungeonCategory == GEnums.DungeonCategoryType.CharResource or
                    dungeonCategory == GEnums.DungeonCategoryType.BasicResource)), 
            subGameIds = {},
            onGotoDungeon = self.m_onGotoDungeon,
            costStamina = false,
        }
        
        local minStaminaCost = math.maxinteger
        local maxStaminaCost = math.mininteger
        for _, subGameId in pairs(seriesCfg.includeDungeonIds) do
            table.insert(info.subGameIds, subGameId)
            table.insert(categoryInfo.subGameIds, subGameId)
            local cfg = Utils.tryGetTableCfg(Tables.gameMechanicTable, subGameId)
            local isUnlocked = GameInstance.dungeonManager:IsDungeonUnlocked(subGameId)
            if cfg and isUnlocked then
                minStaminaCost = ActivityUtils.getRealStaminaCost(math.min(minStaminaCost, cfg.costStamina))
                maxStaminaCost = ActivityUtils.getRealStaminaCost(math.max(maxStaminaCost, cfg.costStamina))
                if cfg.costStamina > 0 then
                    info.costStamina = true
                end
            end
        end
        
        local count = #info.subGameIds
        if count <= 0 or maxStaminaCost <= 0 then
            info.staminaTxt = ""
        elseif count == 1 then
            info.staminaTxt = tostring(maxStaminaCost)
            info.staminaMin = maxStaminaCost
            info.staminaMax = maxStaminaCost
        else
            info.staminaMin = minStaminaCost
            info.staminaMax = maxStaminaCost
            if info.staminaMin ~= info.staminaMax then
                info.staminaTxt = info.staminaMin .. "~" .. info.staminaMax
            else
                info.staminaTxt = info.staminaMin
            end
        end
        
        if dungeonCategory == GEnums.DungeonCategoryType.BossRush then
            self:_ProcessDungeonBossInfo(seriesId, info)
        end
        if dungeonCategory == GEnums.DungeonCategoryType.SpecialResource then
            self:_ProcessDungeonBossInfo(seriesId, info)
            info.dungeonImg = seriesCfg.dungeonImg
        end
        
        return info
    end
    
    return nil
end



AdventureDungeonCtrl._InitDataMonsterSpawnPoint = HL.Method() << function(self)
    
    local newCategoryInfo = {
        tabName = "ui_AdventureDungeonPanel_title_enemyspawner",
        tabImgPath = "deco_adventure_d_brushingmonsters",
        tabJumpName = "EnemySpawner",
        dungeonInfosList = {},
        subGameIds = {},
        showRelief = GameInstance.player.worldEnergyPointSystem.isFull,
    }
    
    local infosBundle = {
        category2ndType = GEnums.DungeonCategory2ndType.None:GetHashCode(),
        name = "", 
        infos = {},
    }
    table.insert(newCategoryInfo.dungeonInfosList, infosBundle)
    
    self.m_dropdownDomainIds = { "All" }
    
    for groupId, tableData in pairs(Tables.worldEnergyPointGroupTable) do
        local id = GameInstance.player.worldEnergyPointSystem:GetCurSubGameId(groupId)
        local canShow = false
        if GameInstance.player.subGameSys:IsGameMapMarkUnlock(groupId, GEnums.MarkType.EnemySpawner) and
            GameInstance.player.subGameSys:IsGameUnlocked(id) and
            AdventureBookUtils.CheckEnemySpawnerCanOpenMap(groupId) then
            canShow = true
        end
        if canShow and id ~= nil then
            local hasCfg, gameCfg = Tables.gameMechanicTable:TryGetValue(id)
            if hasCfg then
                local info = {
                    seriesId = groupId,
                    gameGroupId = groupId,
                    sortId = groupId,
                    mapMarkType = GEnums.MarkType.EnemySpawner,
                    dungeonRoleImg = tableData.icon,
                    dungeonName = gameCfg.gameName,
                    staminaTxt = gameCfg.costStamina == 0 and
                        "" or tostring(ActivityUtils.getRealStaminaCost(gameCfg.costStamina)),
                    isActive = true,
                    rewardInfos = AdventureDungeonCtrl._ProcessMonsterSpawnRewards(groupId, id),
                    subGameIds = { id },
                    onGotoDungeon = self.m_onGotoDungeon,
                }
                local gemRandId = tableData.gemRandId
                local _, domainId = Tables.GemItemDomainTable:TryGetValue(gemRandId)
                info.domainId = domainId
                table.insert(infosBundle.infos, info)
                table.insert(newCategoryInfo.subGameIds, id)
                
                if (lume.find(self.m_dropdownDomainIds, domainId)) == nil then
                    table.insert(self.m_dropdownDomainIds, domainId)
                end
            else
                logger.error("[Game Mechanic Table] missing, id = " .. id)
            end
        end
    end
    
    if #newCategoryInfo.subGameIds <= 0 then
        return  
    end
    table.sort(infosBundle.infos, Utils.genSortFunction({ "sortId" }, true))
    table.insert(self.m_dungeonCategoryInfos, newCategoryInfo)
end







AdventureDungeonCtrl._RefreshUITabCell = HL.Method(HL.Table, HL.Number) << function(self, cell, luaIndex)
    local tabInfo = self.m_dungeonCategoryInfos[luaIndex]

    cell.gameObject.name = luaIndex

    cell.tabNameTxt.text = Language[tabInfo.tabName]
    cell.tabImg:LoadSprite(UIConst.UI_SPRITE_ADVENTURE, tabInfo.tabImgPath)
    cell.toggle.isOn = luaIndex == self.m_curTabIndex
    
    cell.toggle.onValueChanged:RemoveAllListeners()
    cell.toggle.onValueChanged:AddListener(function(isOn)
        if isOn and self.m_curTabIndex ~= luaIndex then
            self:_OnClickTabToggle(luaIndex)
        end
    end)
    
    cell.toggle.onHoverChange:RemoveAllListeners()
    cell.toggle.onHoverChange:AddListener(function(isHover)
        if cell.toggle.isOn then
            return
        end
        if isHover then
            cell.aniWrap:Play("adventuredungeontabtogcell_hover")
        else
            cell.aniWrap:Play("adventuredungeontabtogcell_normal")
        end
    end)
    
    cell.toggle.onIsNaviTargetChanged = function(isTarget, isGroupChanged)
        if isTarget then
            cell.toggle.isOn = true
        end
    end
    
    cell.redDot:InitRedDot("AdventureDungeonTab", tabInfo.subGameIds)
    
    cell.reliefTab.gameObject:SetActive(ActivityUtils.hasStaminaReduceCount() and tabInfo.showRelief)
end





AdventureDungeonCtrl._OnClickTabToggle = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, luaIndex, isInit)
    local count = #self.m_dungeonCategoryInfos
    if count < luaIndex or luaIndex < 1 then
        return
    end
    self.view.reliefNode.gameObject:SetActive((ActivityUtils.hasStaminaReduceCount() and self.m_dungeonCategoryInfos[luaIndex].showRelief))
    local preIndex = self.m_curTabIndex
    if (preIndex ~= luaIndex) then
        
        self:_ReadTabRedDot(preIndex)
    end
    
    if DeviceInfo.usingController and self.m_curTabIndex ~= luaIndex then
        AudioAdapter.PostEvent("Au_UI_Toggle_Common_On")
    end
    self.m_curTabIndex = luaIndex
    local dungeonInfosList = self.m_dungeonCategoryInfos[luaIndex].dungeonInfosList
    local listCount = #dungeonInfosList
    
    if listCount > 1 then
        self.view.dungeonCategoryList.gameObject:SetActiveIfNecessary(true)
        self.view.singleCategoryNode.gameObject:SetActiveIfNecessary(false)
        
        self.view.dungeonCategoryList:UpdateCount(listCount, true)
        self.m_useDungeonList = true
    elseif listCount == 1 then
        local singleCategoryNode = self.view.singleCategoryNode
        singleCategoryNode.gameObject:SetActiveIfNecessary(true)
        self.view.dungeonCategoryList.gameObject:SetActiveIfNecessary(false)
        
        local infosBundle = dungeonInfosList[1]
        infosBundle.hasRead = true
        local category2ndType = GEnums.DungeonCategory2ndType.__CastFrom(infosBundle.category2ndType)
        if (category2ndType == GEnums.DungeonCategory2ndType.None) then
            singleCategoryNode.titleState:SetState("HideTitle")
        else
            singleCategoryNode.titleState:SetState("ShowTitle")
            singleCategoryNode.titleTxt.text = infosBundle.name
        end
        self.m_filterdInfos = infosBundle.infos
        local cellCount = #infosBundle.infos
        self.view.singleCategoryNode.singleCategoryList:UpdateCount(cellCount, true)
        self.m_useDungeonList = false
    end
    
    if listCount > 0 then
        local infoBundle = dungeonInfosList[1]
        if string.isEmpty(infoBundle.name) then
            self.view.titleBgMask.gameObject:SetActiveIfNecessary(true)
        else
            self.view.titleBgMask.gameObject:SetActiveIfNecessary(false)
        end
    else
        self.view.titleBgMask.gameObject:SetActiveIfNecessary(true)
    end
    
    if self.m_dungeonCategoryInfos[luaIndex].tabJumpName == "EnemySpawner" then
        self.view.siltationPoint.gameObject:SetActive(true)
        self.view.dropDown:ClearComponent()
        self.view.dropDown:Init(
            
            function(csIndex, option, _)
                local domainId = self.m_dropdownDomainIds[csIndex + 1]
                local textId = "LUA_ADVENTURE_DUNGEON_ENEMY_SPAWNER_DROPNDOWN_" .. tostring(domainId)
                option:SetText(Language[textId])
            end,
            
            function(csIndex)
                logger.info("[adventure] dropdown csIndex: " .. tostring(csIndex))
                if csIndex == self.m_currSelectDropdownIndex then
                    return
                end
                self.m_currSelectDropdownIndex = csIndex
                self.view.singleCategoryNode.singleCategoryList:ScrollToIndex(0, true)
                local infos = self.m_dungeonCategoryInfos[self.m_curTabIndex].dungeonInfosList[1].infos
                local selectDomainId = self.m_dropdownDomainIds[csIndex + 1]
                local filtered = lume.filter(infos, function(x)
                    if selectDomainId == "All" then
                        return true
                    end
                    return x.domainId == selectDomainId
                end)
                self.m_filterdInfos = filtered
                self.m_needResetSingleListTarget = true
                self.view.singleCategoryNode.singleCategoryList:UpdateCount(#filtered)
            end
        )
        self.m_currSelectDropdownIndex = 0
        self.view.dropDown:Refresh(#self.m_dropdownDomainIds, 0, false)
    else
        self.view.siltationPoint.gameObject:SetActive(false)
    end
    
    if not isInit then
        local aniWrapper = self.animationWrapper
        aniWrapper:Play("adventuredungeonnode_change")
    end
end




AdventureDungeonCtrl._ReadTabRedDot = HL.Method(HL.Number) << function(self, luaIndex)
    if luaIndex <= 0 or luaIndex > #self.m_dungeonCategoryInfos then
        return
    end
    
    local subGameIds = {}
    local categoryInfo = self.m_dungeonCategoryInfos[luaIndex]
    for _, infosBundle in pairs(categoryInfo.dungeonInfosList) do
        if infosBundle.hasRead then
            for _, info in pairs(infosBundle.infos) do
                if info.hasRead then
                    for _, id in pairs(info.subGameIds) do
                        table.insert(subGameIds, id)
                    end
                end
            end
        end
    end
    if (#subGameIds) > 0 then
        GameInstance.player.subGameSys:SendSubGameListRead(subGameIds)
    end
end







AdventureDungeonCtrl._UpdateDungeonCategory = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local infosBundle = self.m_dungeonCategoryInfos[self.m_curTabIndex].dungeonInfosList[luaIndex]
    cell:InitDungeonCategoryCell(infosBundle)
end





AdventureDungeonCtrl._UpdateSingleDungeonCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local cellInfo = nil
    if self.m_filterdInfos ~= nil then
        cellInfo = self.m_filterdInfos[luaIndex]
    else
        local infosBundle = self.m_dungeonCategoryInfos[self.m_curTabIndex].dungeonInfosList[1]
        cellInfo = infosBundle.infos[luaIndex]
    end

    cell:InitAdventureDungeonCell(cellInfo)
    cellInfo.hasRead = true

    if self.m_needResetSingleListTarget and luaIndex == 1 then
        self.m_needResetSingleListTarget = false
        UIUtils.setAsNaviTarget(cell.view.naviDecorator)
    end
end





AdventureDungeonCtrl._ProcessDungeonSeriesRewards = HL.Method(HL.String, HL.Boolean).Return(HL.Table) << function(self, seriesId, checkUnlocked)
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[seriesId]
    if not dungeonSeriesCfg then
        return {}
    end
    
    local rewardList = {}
    if dungeonSeriesCfg.dungeonCategory == GEnums.DungeonCategoryType.Challenge then
        for _, v in pairs(dungeonSeriesCfg.includeDungeonIds) do
            self:_ProcessDungeonRewardsNoMerge(v, rewardList)
        end
    elseif dungeonSeriesCfg.dungeonCategory == GEnums.DungeonCategoryType.BossRush or
        dungeonSeriesCfg.dungeonCategory == GEnums.DungeonCategoryType.SpecialResource then
        local dungeonIds = {}
        for _, v in pairs(dungeonSeriesCfg.includeDungeonIds) do
            table.insert(dungeonIds, v)
        end
        self:_ProcessDungeonRewardsBoss(dungeonIds, rewardList)
    else
        local rewards = {}
        for _, v in pairs(dungeonSeriesCfg.includeDungeonIds) do
            self:_ProcessDungeonRewards(v, rewards, checkUnlocked)
        end
        for _, v in pairs(rewards) do
            table.insert(rewardList, v)
        end
    end
    table.sort(rewardList, Utils.genSortFunction({ "gainedSortId", "rewardTypeSortId", "rarity", "type" }))
    return rewardList
end






AdventureDungeonCtrl._ProcessDungeonRewards = HL.Method(HL.String, HL.Table, HL.Boolean) << function(self, dungeonId, rewards, checkUnlocked)
    if checkUnlocked and not GameInstance.dungeonManager:IsDungeonUnlocked(dungeonId) then
        logger.info("[dungeon] 跳过了" .. tostring(dungeonId))
        return
    end

    local gameMechanicCfg = Tables.gameMechanicTable[dungeonId]

    local hasFirstReward = not string.isEmpty(gameMechanicCfg.firstPassRewardId)
    local hasRecycleReward = not string.isEmpty(gameMechanicCfg.rewardId)
    local hasExtraReward = not string.isEmpty(gameMechanicCfg.extraRewardId)

    
    if hasFirstReward then
        local succ, rewardsCfg = Tables.rewardTable:TryGetValue(gameMechanicCfg.firstPassRewardId)
        if succ then
            for _, itemBundle in pairs(rewardsCfg.itemBundles) do
                local itemId = itemBundle.id
                local reward = rewards[itemId]
                if not reward then
                    local itemCfg = Tables.itemTable[itemId]
                    reward = {
                        id = itemId,
                        rarity = itemCfg.rarity,
                        type = itemCfg.type:ToInt(),
                        
                        gainedSortId = 1,
                        rewardTypeSortId = 3,
                        gained = false,
                    }
                    rewards[itemId] = reward
                end
            end
        end
    end

    
    if hasRecycleReward then
        local hasCfg, rewardsCfg = Tables.rewardTable:TryGetValue(gameMechanicCfg.rewardId)
        if hasCfg then
            for _, itemBundle in pairs(rewardsCfg.itemBundles) do
                local itemId = itemBundle.id
                local reward = rewards[itemId]
                if not reward then
                    local itemCfg = Tables.itemTable[itemId]
                    reward = {
                        id = itemId,
                        rarity = itemCfg.rarity,
                        type = itemCfg.type:ToInt(),
                        
                        gainedSortId = 1,
                        rewardTypeSortId = 1,
                        gained = false,
                    }
                    rewards[itemId] = reward
                end
            end
        end
    end

    
    if hasExtraReward then
        local rewardsCfg = Tables.rewardTable[gameMechanicCfg.extraRewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local itemId = itemBundle.id
            local reward = rewards[itemId]
            if not reward then
                local itemCfg = Tables.itemTable[itemId]
                reward = {
                    id = itemId,
                    rarity = itemCfg.rarity,
                    type = itemCfg.type:ToInt(),
                    
                    gainedSortId = 1,
                    rewardTypeSortId = 2,
                    gained = false,
                }
                rewards[itemId] = reward
            end
        end
    end
end





AdventureDungeonCtrl._ProcessDungeonRewardsNoMerge = HL.Method(HL.String, HL.Table) << function(self, dungeonId, rewards)
    local dungeonMgr = GameInstance.dungeonManager
    local gameMechanicCfg = Tables.gameMechanicTable[dungeonId]

    local hasFirstReward = not string.isEmpty(gameMechanicCfg.firstPassRewardId)
    local hasRecycleReward = not string.isEmpty(gameMechanicCfg.rewardId)
    local hasExtraReward = not string.isEmpty(gameMechanicCfg.extraRewardId)

    
    if hasFirstReward then
        local firstRewardGained = dungeonMgr:IsDungeonFirstPassRewardGained(dungeonId)
        local hideFirstReward = firstRewardGained and hasRecycleReward
        if not hideFirstReward then
            local rewardsCfg = Tables.rewardTable[gameMechanicCfg.firstPassRewardId]
            for _, itemBundle in pairs(rewardsCfg.itemBundles) do
                local itemCfg = Tables.itemTable[itemBundle.id]
                local reward = {
                    id = itemBundle.id,
                    rarity = itemCfg.rarity,
                    type = itemCfg.type:ToInt(),
                    
                    isFirst = true,
                    isExtra = false,
                    gainedSortId = firstRewardGained and 1 or 2,
                    rewardTypeSortId = 3,
                    gained = firstRewardGained,
                }
                table.insert(rewards, reward)
            end
        end
    end

    
    if hasRecycleReward then
        local rewardsCfg = Tables.rewardTable[gameMechanicCfg.rewardId]
        for _, itemBundle in pairs(rewardsCfg.itemBundles) do
            local itemCfg = Tables.itemTable[itemBundle.id]
            local reward = {
                id = itemBundle.id,
                rarity = itemCfg.rarity,
                type = itemCfg.type:ToInt(),
                
                isFirst = false,
                isExtra = false,
                gainedSortId = 1,
                rewardTypeSortId = 1,
                gained = false,
            }
            table.insert(rewards, reward)
        end
    end

    
    if hasExtraReward then
        local extraRewardGained = dungeonMgr:IsDungeonExtraRewardGained(dungeonId)
        local hideExtraReward = extraRewardGained and hasRecycleReward
        if not hideExtraReward then
            local rewardsCfg = Tables.rewardTable[gameMechanicCfg.extraRewardId]
            for _, itemBundle in pairs(rewardsCfg.itemBundles) do
                local itemCfg = Tables.itemTable[itemBundle.id]
                local reward = {
                    id = itemBundle.id,
                    rarity = itemCfg.rarity,
                    type = itemCfg.type:ToInt(),
                    
                    isFirst = false,
                    isExtra = true,
                    gainedSortId = extraRewardGained and 1 or 2,
                    rewardTypeSortId = 2,
                    gained = extraRewardGained,
                }
                table.insert(rewards, reward)
            end
        end
    end
end






AdventureDungeonCtrl._ProcessDungeonRewardsBoss = HL.Method(HL.Table, HL.Table) << function(self, dungeonIds, rewards)
    local dungeonMgr = GameInstance.dungeonManager
    
    local lastUnlockedDungeonId = ""
    for _, dungeonId in ipairs(dungeonIds) do
        if dungeonMgr:IsDungeonUnlocked(dungeonId) then
            lastUnlockedDungeonId = dungeonId
        end
    end
    if (lastUnlockedDungeonId == "") then
        return
    end

    local gameMechanicCfg = Tables.gameMechanicTable[lastUnlockedDungeonId]
    local dungeonCfg = Tables.dungeonTable[lastUnlockedDungeonId]

    local hasFirstReward = not string.isEmpty(gameMechanicCfg.firstPassRewardId)
    local hasHunterReward = not string.isEmpty(gameMechanicCfg.hunterModeRewardId)
    local isHunterModeUnlocked = DungeonUtils.isHunterModeUnlocked()

    
    if hasFirstReward then
        local firstRewardGained = dungeonMgr:IsDungeonFirstPassRewardGained(lastUnlockedDungeonId)

        local notShow = isHunterModeUnlocked and hasHunterReward and firstRewardGained
        if not notShow then
            local rewardsCfg = Tables.rewardTable[gameMechanicCfg.firstPassRewardId]
            for _, itemBundle in pairs(rewardsCfg.itemBundles) do
                local itemCfg = Tables.itemTable[itemBundle.id]
                local reward = {
                    id = itemBundle.id,
                    rarity = itemCfg.rarity,
                    type = itemCfg.type:ToInt(),
                    
                    isFirst = true,
                    isExtra = false,
                    gainedSortId = firstRewardGained and 1 or 2,
                    rewardTypeSortId = 3,
                    gained = firstRewardGained,
                }
                table.insert(rewards, reward)
            end
        end
    end

    
    if hasHunterReward then
        local rewardCfg = Tables.rewardTable[dungeonCfg.hunterModeRewardId]
        
        for _, itemBundle in pairs(rewardCfg.itemBundles) do
            local itemCfg = Tables.itemTable[itemBundle.id]
            local reward = {
                id = itemCfg.id,
                rarity = itemCfg.rarity,
                type = itemCfg.type:ToInt(),
                
                isFirst = false,
                isExtra = false,
                gainedSortId = 1,
                rewardTypeSortId = 1,
                gained = false,
            }
            table.insert(rewards, reward)
        end

        
        for _, itemBundle in pairs(rewardCfg.probItemBundles) do
            local itemId = itemBundle.id
            local succ, itemCfg = Tables.itemTable:TryGetValue(itemId)
            if succ then
                local reward = {
                    id = itemCfg.id,
                    rarity = itemCfg.rarity,
                    type = itemCfg.type:ToInt(),
                    
                    isFirst = false,
                    isExtra = false,
                    gainedSortId = 1,
                    rewardTypeSortId = 1,
                    gained = false,
                }
                table.insert(rewards, reward)
            end
        end
    end
end





AdventureDungeonCtrl._ProcessDungeonBossInfo = HL.Method(HL.String, HL.Table) << function(self, seriesId, info)
    local dungeonSeriesData = Tables.DungeonSeriesTable[seriesId]
    
    local lastUnlockedDungeonId = ""
    for _, dungeonId in pairs(dungeonSeriesData.includeDungeonIds) do
        if GameInstance.dungeonManager:IsDungeonUnlocked(dungeonId) then
            lastUnlockedDungeonId = dungeonId
        end
    end
    if lastUnlockedDungeonId == "" then
        return
    end

    info.isHunterMode = DungeonUtils.isDungeonHasHunterMode(lastUnlockedDungeonId) and
        DungeonUtils.isHunterModeUnlocked()
    local dungeonData = Tables.DungeonTable[lastUnlockedDungeonId]
    if info.isHunterMode then
        info.staminaTxt = tostring(ActivityUtils.getRealStaminaCost(dungeonData.hunterModeCostStamina))
        if dungeonData.hunterModeCostStamina > 0 then
            info.costStamina = true
        end
    end
end





AdventureDungeonCtrl._GetDungeonImg = HL.Method(HL.Any).Return(HL.Opt(HL.String)) << function(self, dungeonIds)
    local ret = nil
    for _, dungeonId in pairs(dungeonIds) do
        local unlocked = GameInstance.dungeonManager:IsDungeonUnlocked(dungeonId)
        if unlocked then
            local _, dungeonCfg = Tables.DungeonTable:TryGetValue(dungeonId)
            if dungeonCfg then
                ret = dungeonCfg.dungeonImg
            end
        end
    end
    return ret
end




AdventureDungeonCtrl._ProcessMonsterSpawnRewards = HL.StaticMethod(HL.String, HL.String).Return(HL.Table) << function(groupId, gameId)
    local rewards = {}
    local rewardList = {}

    local isFull = GameInstance.player.worldEnergyPointSystem.isFull
    
    local wepGroupCfg = Tables.worldEnergyPointGroupTable[groupId]
    local wepCfg = Tables.worldEnergyPointTable[gameId]
    local firstRewardGained = GameInstance.player.worldEnergyPointSystem:IsGameGroupFirstPassRewardGained(groupId)
    if not firstRewardGained or not isFull then
        local firstPartRewards = {}
        local rewardCfg = Tables.rewardTable[wepGroupCfg.firstPassRewardId]
        for _, itemBundle in pairs(rewardCfg.itemBundles) do
            local reward = AdventureDungeonCtrl._GenRewardInfo(DungeonConst.DUNGEON_REWARD_TAG_STATE.First, -1, firstRewardGained,
                itemBundle.id, itemBundle.count)
            table.insert(firstPartRewards, reward)
        end
        table.sort(firstPartRewards, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
        for _, item in pairs(firstPartRewards) do
            item.isFirst = true,
            table.insert(rewardList, item)
        end
    end
    
    if isFull then
        local secondPartRewards = {}
        for i = 0, wepCfg.probGemItemIds.Count - 1 do
            local itemId = wepCfg.probGemItemIds[i]
            local reward = AdventureDungeonCtrl._GenRewardInfo(DungeonConst.DUNGEON_REWARD_TAG_STATE.Random, -3, false, itemId)
            table.insert(secondPartRewards, reward)
        end
        table.sort(secondPartRewards, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))

        for _, item in pairs(secondPartRewards) do
            item.isFirst = false,
            table.insert(rewardList, item)
        end
    end
    
    return rewardList
end







AdventureDungeonCtrl._GenRewardInfo = HL.StaticMethod(HL.String, HL.Number, HL.Boolean, HL.String, HL.Opt(HL.Number)).Return(HL.Table)
    << function(tagState, rewardTypeSortId, gained, itemId, itemCount)
    local itemCfg = Tables.itemTable[itemId]
    return {
        id = itemId,
        count = itemCount,
        gained = gained,
        tagState = tagState,

        gainedSortId = gained and 0 or 1,
        rewardTypeSortId = rewardTypeSortId,
        sortId1 = itemCfg.sortId1,
        sortId2 = itemCfg.sortId2,
    }
end





AdventureDungeonCtrl.m_discount = HL.Field(HL.Number) << 0



AdventureDungeonCtrl._HandleStaminaDiscount = HL.Method() << function(self)
    local totalCount = GameInstance.player.activitySystem.staminaTotalCount
    local useCount = GameInstance.player.activitySystem.staminaReduceUsedCount
    self.m_discount = GameInstance.player.activitySystem.staminaDiscount

    
    self.view.blackNum.gameObject:SetActive(ActivityUtils.hasStaminaReduceCount())
    self.view.blackNum.text = totalCount - useCount
    self.view.redNum.gameObject:SetActive(not ActivityUtils.hasStaminaReduceCount())
    self.view.redNum.text = totalCount - useCount
    self.view.numTxt.text = string.format("/%d", totalCount)
end






AdventureDungeonCtrl.GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, csIndex)
    local luaIndex = LuaIndex(csIndex)
    local cellInfo = nil
    if self.m_filterdInfos ~= nil then
        cellInfo = self.m_filterdInfos[luaIndex]
    else
        local infosBundle = self.m_dungeonCategoryInfos[self.m_curTabIndex].dungeonInfosList[1]
        cellInfo = infosBundle.infos[luaIndex]
    end

    if cellInfo == nil then
        return 0
    end

    local subGameIds = cellInfo.subGameIds
    local hasRedDot, redDotType = RedDotManager:GetRedDotState(
        "AdventureDungeonCell", subGameIds)
    if hasRedDot then
        return redDotType or UIConst.RED_DOT_TYPE.Normal
    else
        return 0  
    end
end

HL.Commit(AdventureDungeonCtrl)
