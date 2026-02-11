local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')





WikiSearchGroupTutorials = HL.Class('WikiSearchGroupTutorials', UIWidgetBase)


WikiSearchGroupTutorials.m_tutorialCache = HL.Field(HL.Forward("UIListCache"))




WikiSearchGroupTutorials._OnFirstTimeInit = HL.Override() << function(self)
    self.m_tutorialCache = UIUtils.genCellCache(self.view.wikiTutorialTab)
end






WikiSearchGroupTutorials.InitWikiSearchGroupTutorials = HL.Method(HL.Table, HL.Function, HL.Opt(HL.Boolean)) << function(
    self, wikiSearchResult, onItemClicked, isFirstClicked)
    self:_FirstTimeInit()

    self.m_tutorialCache:GraduallyRefresh(#wikiSearchResult.categoryResult, self.config.GRADUALLY_SHOW_TIME, function(cell, luaIndex)
        local entryShowData = wikiSearchResult.categoryResult[luaIndex]
        cell:InitWikiTutorialTab(entryShowData, function()
            if onItemClicked then
                onItemClicked(cell, entryShowData)
            end
        end)
        local entryId = entryShowData.wikiEntryData.id
        cell.view.redDot:InitRedDot("WikiGuideEntry", entryId)

        if isFirstClicked and luaIndex == 1 then
            if onItemClicked then
                onItemClicked(cell, entryShowData)
                if WikiUtils.isWikiEntryUnread(entryId) then
                    GameInstance.player.wikiSystem:MarkWikiEntryRead({ entryId })
                end
            end
            InputManagerInst.controllerNaviManager:SetTarget(cell.view.btn)
        end
    end)
end

HL.Commit(WikiSearchGroupTutorials)
return WikiSearchGroupTutorials

