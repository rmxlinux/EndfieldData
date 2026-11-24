local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local CELL_IMPORTANCE = 0
local CELL_CHAPTER = 1
local CELL_MISSION = 2
local CHAPTER_ICON_PATH = "Mission/ChapterIconNew"
local CHAPTER_BG_ICON_PATH = "Mission/ChapterBgIconNew"
local MISSION_ITEM_PREFIX = "MissionListItem_"
local CONTENT_NAMES = {
    [CELL_CHAPTER] = "ChapterCell",
    [CELL_MISSION] = "MissionCellNew",
}


MissionListCell = HL.Class('MissionListCell', UIWidgetBase)

MissionListCell.m_cellType = HL.Field(HL.Number) << -1
MissionListCell.m_contents = HL.Field(HL.Table) << function() return {} end
MissionListCell.m_missionCellCache = HL.Field(HL.Forward("UIListCache"))


MissionListCell.InitMissionListCell = HL.Method(HL.Table, HL.Function) << function(self, viewInfo, refreshMissionCell)
    self.m_cellType = viewInfo.type
    for cellType, nodeName in pairs(CONTENT_NAMES) do
        if cellType ~= viewInfo.type then
            self:tryToggleDynamicNode(self.transform, nodeName, nil, false)
        end
    end
    
    self.view.importanceNode.gameObject:SetActiveIfNecessary(viewInfo.type == CELL_IMPORTANCE)

    if viewInfo.type == CELL_CHAPTER then
        self:_RefreshChapter(viewInfo, refreshMissionCell)
    elseif viewInfo.type == CELL_MISSION then
        refreshMissionCell(self:_GetContent(CELL_MISSION), viewInfo.id, viewInfo.importance)
    elseif viewInfo.type == CELL_IMPORTANCE then
        self:_RefreshImportance(viewInfo)
    else
        logger.critical("MissionListCell: 未知内容类型", viewInfo.type, viewInfo.id)
        return
    end

    
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.transform)
end

MissionListCell._GetContent = HL.Method(HL.Number).Return(HL.Table) << function(self, cellType)
    
    local prefab = cellType == CELL_CHAPTER and self.config.CHAPTER_PREFAB or self.config.MISSION_PREFAB
    local obj = self:tryToggleDynamicNode(self.transform, CONTENT_NAMES[cellType], prefab, true, function(go)
        local content = Utils.wrapLuaNode(go)
        self.m_contents[cellType] = content
        local missionCell = cellType == CELL_CHAPTER and content.missionCell or content
        
        
        missionCell.selectBtn:TryFindNaviGroup()
    end)
    if not self.m_contents[cellType] then
        self.m_contents[cellType] = Utils.wrapLuaNode(obj)
    end
    return self.m_contents[cellType]
end

MissionListCell._GetMissionCellCache = HL.Method(HL.Table).Return(HL.Forward("UIListCache")) << function(self, chapterCell)
    if self.m_missionCellCache then
        return self.m_missionCellCache
    end

    local cache = UIUtils.genCellCache(chapterCell.missionCell)
    
    local items = cache:GetItems()
    local parent = chapterCell.missionCell.transform.parent
    local index = 1
    local child = parent:Find(MISSION_ITEM_PREFIX .. index)
    while child do
        items[index] = Utils.wrapLuaNode(child)
        index = index + 1
        child = parent:Find(MISSION_ITEM_PREFIX .. index)
    end
    self.m_missionCellCache = cache
    return cache
end

MissionListCell._RefreshChapter = HL.Method(HL.Table, HL.Function) << function(self, viewInfo, refreshMissionCell)
    local chapterCell = self:_GetContent(CELL_CHAPTER)
    chapterCell.newChapterTag.gameObject:SetActiveIfNecessary(viewInfo.showNewChapterTag == true)
    local chapterInfo = GameInstance.player.mission:GetChapterInfo(viewInfo.id)
    if not chapterInfo then
        logger.critical("MissionListCell: 章节显示数据缺失", viewInfo.id)
        return
    end

    self:_RefreshChapterTitle(chapterCell, chapterInfo)
    local cache = self:_GetMissionCellCache(chapterCell)
    cache:Refresh(#viewInfo.missionList, function(missionCell, index)
        missionCell.gameObject.name = MISSION_ITEM_PREFIX .. index
        local mission = viewInfo.missionList[index]
        refreshMissionCell(missionCell, mission.id, mission.importance)
    end)
end

MissionListCell._RefreshChapterTitle = HL.Method(HL.Table, HL.Any) << function(self, chapterCell, chapterInfo)
    local isMainChapter = chapterInfo.type == CS.Beyond.Gameplay.ChapterType.Main
    chapterCell.titleNode1.gameObject:SetActiveIfNecessary(isMainChapter)
    chapterCell.titleNode2.gameObject:SetActiveIfNecessary(not isMainChapter)
    if not isMainChapter then
        chapterCell.titleTxt:SetAndResolveTextStyle(chapterInfo.episodeName:GetText())
        return
    end

    chapterCell.episodeName:SetAndResolveTextStyle(chapterInfo.episodeName:GetText())
    local chapterNumTxt = chapterInfo.chapterNum:GetText()
    local episodeNumTxt = chapterInfo.episodeNum:GetText()
    local separator = ""
    if not string.isEmpty(chapterNumTxt) and not string.isEmpty(episodeNumTxt) then
        separator = " - "
    end
    chapterCell.chapterNumAndEpisodeNum:SetAndResolveTextStyle(chapterNumTxt .. separator .. episodeNumTxt)

    local chapterConfig = UIConst.CHAPTER_ICON_CONFIGS[chapterInfo.type]
    
    self:_RefreshChapterIcon(chapterCell.icon, CHAPTER_ICON_PATH, chapterInfo.icon, chapterConfig.icon)
    
    self:_RefreshChapterIcon(chapterCell.bgIcon, CHAPTER_BG_ICON_PATH, chapterInfo.bgIcon, chapterConfig.bgIcon)
end

MissionListCell._RefreshChapterIcon = HL.Method(CS.Beyond.UI.UIImage, HL.String, HL.Opt(HL.String, HL.String))
        << function(self, image, path, icon, fallbackIcon)
    local iconName = not string.isEmpty(icon) and icon or fallbackIcon
    local active = not string.isEmpty(iconName)
    image.gameObject:SetActiveIfNecessary(active)
    if active then
        image:LoadSprite(path, iconName)
    else
        image.sprite = nil
    end
end

MissionListCell._RefreshImportance = HL.Method(HL.Table) << function(self, viewInfo)
    self.view.importanceLayout.gameObject:SetActiveIfNecessary(not viewInfo.isFirstImportance)
    local targetState = "Vital"
    if viewInfo.importance == GEnums.MissionImportance.Mid then
        targetState = "Secondary"
    elseif viewInfo.importance == GEnums.MissionImportance.Low then
        targetState = "Normal"
    end
    self.view.importanceNodeStateController:SetState(targetState)
end


MissionListCell.GetMissionCell = HL.Method(HL.Opt(HL.Number)).Return(HL.Opt(HL.Table)) << function(self, subIndex)
    local content = self.m_contents[self.m_cellType]
    if not content or not content.gameObject.activeSelf then
        return nil
    end
    if self.m_cellType == CELL_CHAPTER then
        return self.m_missionCellCache and self.m_missionCellCache:GetItem(subIndex) or nil
    end
    return content
end

MissionListCell._OnDisable = HL.Override() << function(self)
    
    if self.gameObject.activeSelf then
        return
    end
    for _, nodeName in pairs(CONTENT_NAMES) do
        self:tryToggleDynamicNode(self.transform, nodeName, nil, false)
    end
end

HL.Commit(MissionListCell)
return MissionListCell
