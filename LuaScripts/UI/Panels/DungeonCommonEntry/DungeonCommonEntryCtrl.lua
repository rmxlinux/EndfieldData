
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonCommonEntry
local PHASE_ID = PhaseId.DungeonEntry

local CustomGenDungeonSeriesTabInfoFunc = {
    [DungeonConst.DUNGEON_CATEGORY.CharTutorial] = '_GenDungeonCharTutorialTabInfos',
    [DungeonConst.DUNGEON_CATEGORY.HighDifficulty] = '_GenDungeonHighDifficultyTabInfos',
}

local CustomFindFirstSelectDungeonFunc = {
    [DungeonConst.DUNGEON_CATEGORY.CharTutorial] = '_FindFirstSelectCharTutorial',
    [DungeonConst.DUNGEON_CATEGORY.Train] = '_FindFirstSelectTrain',
}




































DungeonCommonEntryCtrl = HL.Class('DungeonCommonEntryCtrl', uiCtrl.UICtrl)


DungeonCommonEntryCtrl.m_dungeonSeriesId = HL.Field(HL.String) << ""


DungeonCommonEntryCtrl.m_curTabIndex = HL.Field(HL.Number) << 1


DungeonCommonEntryCtrl.m_curSelectedDungeonId = HL.Field(HL.String) << ""


DungeonCommonEntryCtrl.m_dungeonTabCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonCommonEntryCtrl.m_dungeonTabGroupCellCache = HL.Field(HL.Forward("UIListCache"))



DungeonCommonEntryCtrl.m_isUseGroup = HL.Field(HL.Boolean) << false


DungeonCommonEntryCtrl.m_tabGroups = HL.Field(HL.Table)


DungeonCommonEntryCtrl.m_curSelectedCell = HL.Field(HL.Any)


DungeonCommonEntryCtrl.m_tabDungeonIds = HL.Field(HL.Table)


DungeonCommonEntryCtrl.m_haveHardMode = HL.Field(HL.Boolean) << false


DungeonCommonEntryCtrl.m_fromDialog = HL.Field(HL.Boolean) << false


DungeonCommonEntryCtrl.m_arg = HL.Field(HL.Table)






DungeonCommonEntryCtrl.s_messages = HL.StaticField(HL.Table) << {
}





DungeonCommonEntryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_arg = arg
    self.m_curTabIndex = 1
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.m_fromDialog = arg.fromDialog or false
    self.m_dungeonSeriesId = arg.dungeonSeriesId
    
    if not string.isEmpty(arg.dungeonId) then
        self.m_curSelectedDungeonId = arg.dungeonId
    end

    if lume.find(DungeonConst.UI_RESTORE_DUNGEON_CATEGORY, Tables.dungeonSeriesTable[self.m_dungeonSeriesId].gameCategory) ~= nil then
        if self.m_arg.enterDungeonCallback == nil then
            self.m_arg.enterDungeonCallback = function(enterDungeonId)
                LuaSystemManager.uiRestoreSystem:AddRequest(enterDungeonId, function()
                    PhaseManager:OpenPhaseFast(PhaseId.DungeonEntry, { dungeonId = enterDungeonId })
                end)
            end
        end
    end

    self.m_dungeonTabCellCache = UIUtils.genCellCache(self.view.dungeonSelectionCell)
    self.m_dungeonTabGroupCellCache = UIUtils.genCellCache(self.view.dungeonSelectionGroupCell)

    self:_InitDungeonSeriesInfo()
    self:_InitDungeonTabs()
    self:_RefreshCommonInfo(true)

    self:_InitController()

    CS.Beyond.Gameplay.Conditions.OnDungeonCommonEntryPanelOpen.Trigger(self.m_dungeonSeriesId, false)
end



DungeonCommonEntryCtrl.OnAnimationInFinished = HL.Override() << function(self)
    CS.Beyond.Gameplay.Conditions.OnDungeonCommonEntryPanelOpen.Trigger(self.m_dungeonSeriesId, true)

    if not DeviceInfo.usingController then
        return
    end

    if self.m_dungeonTabCellCache:GetCount() > 1 or self.m_dungeonTabGroupCellCache:GetCount() > 1 then
        if InputManagerInst.controllerNaviManager:IsLayerInStack(self.view.selectableNaviGroup) then
            self.view.selectableNaviGroup:SetLayerSelectedTarget(self.m_curSelectedCell.view.clickBtn)
        else
            UIUtils.setAsNaviTarget(self.m_curSelectedCell.view.clickBtn)
        end
    end
end










DungeonCommonEntryCtrl._InitDungeonSeriesInfo = HL.Method() << function(self)
    
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    self.view.titleTxt.text = dungeonSeriesCfg.name
    
    self.view.dungeonBG:LoadSprite(UIConst.UI_SPRITE_DUNGEON, dungeonSeriesCfg.dungeonPicPath)
    
    self:_InitRaid()
    
    self:_InitAchievement()
end



DungeonCommonEntryCtrl._InitRaid = HL.Method() << function(self)
    
    
    self.m_haveHardMode = Tables.dungeonRaidTable:TryGetValue(Tables.dungeonSeriesTable[self.m_dungeonSeriesId].includeDungeonIds[0])
    if self.m_haveHardMode then
        local dungeonInfos = HighDifficultyUtils.GetSeriesInfo(self.m_dungeonSeriesId)
        self.m_curSelectedDungeonId = ""

        
        for index, dungeonInfo in ipairs(dungeonInfos) do
            if not dungeonInfo.raidUnlocked then
                self.m_curSelectedDungeonId = dungeonInfo.normalId
                break
            end
        end

        
        if string.isEmpty(self.m_curSelectedDungeonId) then
            for index, dungeonInfo in ipairs(dungeonInfos) do
                
                if not dungeonInfo.raidPassed or index == #dungeonInfos then
                    self.m_curSelectedDungeonId = dungeonInfo.raidId
                    break
                end
            end
        end

        
        local info = self.view.dungeonCommonInfo
        info.view.hardModeNode.gameObject:SetActive(true)
        self:_RefreshHardTog(self.m_curSelectedDungeonId)
        self.view.dungeonCommonInfo.view.hardTog.onValueChanged:AddListener(function(isOn)
            self.m_curSelectedDungeonId = Tables.dungeonRaidTable[self.m_curSelectedDungeonId].RelatedLevel
            info:RefreshDungeonCommonInfo(self.m_curSelectedDungeonId)
            info.view.hardTogStateController:SetState(isOn and "On" or "Off")
            if isOn then
                AudioAdapter.PostEvent("Au_UI_Toast_HighDifficultyHint")
            end
        end)
    end
end


DungeonCommonEntryCtrl.m_manuallyTog = HL.Field(HL.Boolean) << true



DungeonCommonEntryCtrl._InitAchievement = HL.Method() << function(self)
    local achievementId
    local hasCfg, dungeonCfg = Tables.dungeonTable:TryGetValue(self.m_curSelectedDungeonId)
    local needShowAchievement = false
    if hasCfg then
        needShowAchievement = dungeonCfg.dungeonCategory ~= "dungeon_challenge"
    end
    if needShowAchievement then
        if Tables.HighDifficultyGameIdToSeriesIdTable:TryGetValue(self.m_curSelectedDungeonId) then
            
            local highDifficultySeriesId = Tables.HighDifficultyGameIdToSeriesIdTable[self.m_curSelectedDungeonId].seriesId
            achievementId = Tables.HighDifficultySeriesTable[highDifficultySeriesId].achieveId
        else
             
        end
    end

    if achievementId then
        self.view.dungeonMedalCell:InitCommonMedalNode(achievementId)
        self.view.etchedSealNode.gameObject:SetActive(true)
    end
end



DungeonCommonEntryCtrl._InitDungeonTabs = HL.Method() << function(self)
    
    self:_GenDungeonTabInfos()

    local haveGroup, tabGroups = DungeonUtils.groupDungeonsByCondition(self.m_tabDungeonIds)
    self.m_isUseGroup = haveGroup
    self.m_tabGroups = tabGroups

    
    self:_FindFirstSelectDungeonTab()

    self.view.dungeonSelectionNode.gameObject:SetActive(not haveGroup)
    self.view.dungeonSelectionGroupNode.gameObject:SetActive(haveGroup)
    if haveGroup then  
        local isUsingController = (DeviceInfo.inputType == DeviceInfo.InputType.Controller)
        self.m_dungeonTabGroupCellCache:Refresh(#self.m_tabGroups, function(cell, luaIndex)
            local tabGroup = self.m_tabGroups[luaIndex]
            cell:InitDungeonCommonSelectionGroupCell(tabGroup, function(selectCell, selectDungeonId)
                self:_OnDungeonTabClick(selectCell, selectDungeonId)
            end)
            cell.gameObject.name = "DungeonGroup-"..luaIndex
            local found = cell:TryGetSubCell(self.m_curSelectedDungeonId)
            if found ~= nil then
                self.m_curSelectedCell = found
                self.m_curSelectedCell:SetSelected(true)
                cell:SetToggle(true)
            else
                cell:SetToggle(false or isUsingController)
            end
        end)
    else  
        local tabCount = #self.m_tabDungeonIds
        local dungeonCfg = Tables.dungeonTable[self.m_tabDungeonIds[tabCount]]
        local charRelated = not string.isEmpty(dungeonCfg.relatedCharId)
        local showSelectionNode = charRelated or tabCount > 1
        if showSelectionNode then
            self.m_dungeonTabCellCache:Refresh(tabCount, function(cell, luaIndex)
                local dungeonId = self.m_tabDungeonIds[luaIndex]
                self:_UpdateTabCell(cell, dungeonId, luaIndex)
            end)
            self.m_curSelectedCell:SetSelected(true)
            LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.dungeonSelectionNode.transform)
            self.view.dungeonSelectionNode:AutoScrollToRectTransform(self.m_curSelectedCell.gameObject.transform, true)
        end
        self.view.dungeonSelectionNode.gameObject:SetActiveIfNecessary(showSelectionNode)
    end
end



DungeonCommonEntryCtrl._GenDungeonTabInfos = HL.Method() << function(self)
    self.m_tabDungeonIds = {}
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    local funcName = CustomGenDungeonSeriesTabInfoFunc[dungeonSeriesCfg.gameCategory]
    if funcName then
        self[funcName](self)
    else
        for _, dungeonId in pairs(dungeonSeriesCfg.includeDungeonIds) do
            table.insert(self.m_tabDungeonIds, dungeonId)
        end
    end
end



DungeonCommonEntryCtrl._GenDungeonCharTutorialTabInfos = HL.Method() << function(self)
    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    for _, dungeonId in pairs(dungeonSeriesCfg.includeDungeonIds) do
        
        
        local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
        if isUnlock then
            table.insert(self.m_tabDungeonIds, dungeonId)
        end
    end

    table.sort(self.m_tabDungeonIds, function(a, b)
        local aPass = DungeonUtils.isDungeonPassed(a)
        local bPass = DungeonUtils.isDungeonPassed(b)
        if aPass and bPass or not aPass and not bPass then
            return Tables.dungeonTable[a].sortId < Tables.dungeonTable[b].sortId
        end

        return not aPass and bPass
    end)
end



DungeonCommonEntryCtrl._GenDungeonHighDifficultyTabInfos = HL.Method() << function(self)
    if not self.m_haveHardMode then
        return
    end

    
    local seriesInfo = HighDifficultyUtils.GetSeriesInfo(self.m_dungeonSeriesId)
    for _, dungeonInfo in ipairs(seriesInfo) do
        table.insert(self.m_tabDungeonIds, dungeonInfo.normalId)
    end
end



DungeonCommonEntryCtrl._FindFirstSelectDungeonTab = HL.Method() << function(self)
    
    if not string.isEmpty(self.m_curSelectedDungeonId) then
        return
    end

    local dungeonSeriesCfg = Tables.dungeonSeriesTable[self.m_dungeonSeriesId]
    
    
    local funcName = CustomFindFirstSelectDungeonFunc[dungeonSeriesCfg.gameCategory]
    if funcName then
        self[funcName](self)
    end

    if string.isEmpty(self.m_curSelectedDungeonId) then
        
        
        for luaIndex = #self.m_tabDungeonIds, 1, -1 do
            local dungeonId = self.m_tabDungeonIds[luaIndex]
            local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
            if isUnlock then
                self.m_curSelectedDungeonId = dungeonId
                break
            end
        end
    end

    
    if string.isEmpty(self.m_curSelectedDungeonId) then
        self.m_curSelectedDungeonId = self.m_tabDungeonIds[1]
    end
end



DungeonCommonEntryCtrl._FindFirstSelectCharTutorial = HL.Method() << function(self)
    
    if string.isEmpty(self.m_curSelectedDungeonId) then
        self.m_curSelectedDungeonId = self.m_tabDungeonIds[1]
    end
end



DungeonCommonEntryCtrl._FindFirstSelectTrain = HL.Method() << function(self)
    
    for _, tab in ipairs(self.m_tabGroups) do
        for _, dungeonId in ipairs(tab) do
            local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
            local isComplete = DungeonUtils.isDungeonPassed(dungeonId)
            if isUnlock and not isComplete then
                self.m_curSelectedDungeonId = dungeonId
                return
            end
        end
    end
    
    for i = #self.m_tabGroups, 1, -1 do
        local tab = self.m_tabGroups[i]
        for j = #tab, 1, -1 do
            local dungeonId = tab[j]
            local isComplete = DungeonUtils.isDungeonPassed(dungeonId)
            if isComplete then
                self.m_curSelectedDungeonId = dungeonId
                return
            end
        end
    end
    
    if #self.m_tabGroups >= 1 and #(self.m_tabGroups[1]) >= 1 then
        self.m_curSelectedDungeonId = self.m_tabGroups[1][1]
    end
end







DungeonCommonEntryCtrl._UpdateTabCell = HL.Method(HL.Any, HL.String, HL.Number) << function(self, cell, dungeonId,
                                                                                            luaIndex)
    cell:InitDungeonCommonSelectionCell(dungeonId, function()
        self.m_curTabIndex = luaIndex
        if self.m_haveHardMode then
            local normalId = dungeonId
            local raidId = Tables.dungeonRaidTable[normalId].RelatedLevel
            local isRaid = DungeonUtils.isDungeonUnlock(raidId)
            self:_OnDungeonTabClick(cell, isRaid and raidId or normalId)
        else
            self:_OnDungeonTabClick(cell, dungeonId)
        end
    end)
    cell.gameObject.name = dungeonId
    if self.m_curSelectedDungeonId == dungeonId then
        self.m_curSelectedCell = cell
    elseif self.m_haveHardMode and dungeonId == Tables.dungeonRaidTable[self.m_curSelectedDungeonId].RelatedLevel then
        self.m_curSelectedCell = cell
    end
end



DungeonCommonEntryCtrl._GenCustomArgs = HL.Method().Return(HL.Table) << function(self)
    return self.m_arg
end



DungeonCommonEntryCtrl._OnBtnCloseClick = HL.Method() << function(self)
    local isOpen = self.m_fromDialog
    if isOpen then
        self:Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PHASE_ID, 1 })
    else
        PhaseManager:PopPhase(PHASE_ID)
    end
end





DungeonCommonEntryCtrl._OnDungeonTabClick = HL.Method(HL.Any, HL.String)
        << function(self, cell, dungeonId)
    if self.m_curSelectedDungeonId == dungeonId then
        return
    end

    if self.m_haveHardMode then
        self:_RefreshHardTog(dungeonId)
    end

    local preCell = self.m_curSelectedCell
    self.m_curSelectedCell = cell
    self.m_curSelectedDungeonId = dungeonId

    preCell:SetSelected(false)
    cell:SetSelected(true)

    self:_RefreshCommonInfo(false)
end




DungeonCommonEntryCtrl._RefreshHardTog = HL.Method(HL.String) << function(self, dungeonId)
    local info = self.view.dungeonCommonInfo

    if GameInstance.dungeonManager:IsDungeonUnlocked(Tables.dungeonRaidTable[dungeonId].RelatedLevel) then
        info.view.hardModeNode:SetState("Enabled")
        info.view.hardTog.isOn = true
        AudioAdapter.PostEvent("Au_UI_Toast_HighDifficultyHint")
        self:_StartCoroutine(function()
            info.view.hardTogStateController:SetState("On")
        end)
    else
        info.view.hardModeNode:SetState("Disabled")
        info.view.fakeHardTogBtn.onClick:RemoveAllListeners()
        info.view.fakeHardTogBtn.onClick:AddListener(function()
            Notify(MessageConst.SHOW_TOAST,Language.LUA_DUNGEON_HARD_MODE_CANT_TOG)
        end)
        info.view.hardTog.isOn = false
        self:_StartCoroutine(function()
            info.view.hardTogStateController:SetState("Off")
        end)
    end

end




DungeonCommonEntryCtrl._RefreshCommonInfo = HL.Method(HL.Boolean) << function(self, isInit)
    if isInit then
        self.view.dungeonCommonInfo:InitDungeonCommonInfo(self:_GenCustomArgs())
    end
    self.view.dungeonCommonInfo:RefreshDungeonCommonInfo(self.m_curSelectedDungeonId)
    local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(self.m_curSelectedDungeonId)
    if succ then
        local path = dungeonCfg.dungeonPicPath
        self.view.dungeonBG:LoadSprite(UIConst.UI_SPRITE_DUNGEON, path)
        self.view.maskImg:LoadSprite(UIConst.UI_SPRITE_DUNGEON, path.."_bg")
    end
end



DungeonCommonEntryCtrl._InitController = HL.Method() << function(self)
    if not DeviceInfo.usingController then
        return
    end

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end

HL.Commit(DungeonCommonEntryCtrl)
