local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnTopicEntry = HL.Class('InnTopicEntry', UIWidgetBase)

InnTopicEntry.m_innItemTagCache = HL.Field(HL.Forward("UIListCache"))


InnTopicEntry._OnFirstTimeInit = HL.Override() << function(self)
    self.m_innItemTagCache = self.m_innItemTagCache or UIUtils.genCellCache(self.view.innItemTagBig)
end







InnTopicEntry.InitInnTopicEntry = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.view.detailTip.gameObject:SetActiveIfNecessary(args.showDetailTip == true)

    self.view.btnNormal.onClick:RemoveAllListeners()
    self.view.btnLock.onClick:RemoveAllListeners()
    if args.onClick then
        self.view.btnLock.onClick:AddListener(function() args.onClick() end)
        self.view.btnNormal.onClick:AddListener(function() args.onClick() end)
    end

    self.view.goBtn.onClick:RemoveAllListeners()
    if args.onGoToClick then
        self.view.goBtn.onClick:AddListener(function() args.onGoToClick() end)
    end

    local topicId = args.topicId
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local innLevel = (innSystem and innSystem.innLevel) or 0
    local innConst = Tables.innManagementConst

    if not topicId or string.isEmpty(topicId) then
        self.view.stateController:SetState("Normal")
        self.view.themeNameTxt.text = Language.LUA_INN_TOPIC_NONE_TITLE

        local fashionUnlockLevel = (innConst and innConst.fashionUnlockLevel) or 0
        if innLevel < fashionUnlockLevel then
            self.view.popularText.text = Language.LUA_INN_TOPIC_ENTRY_FASHION_LOCKED
            
            self.m_innItemTagCache:Refresh(0)
        else
            self.view.popularText.text = Language.LUA_INN_TOPIC_ENTRY_FASHION_PREFIX
            self:_RefreshHotItemTags(innSystem and innSystem.dailyCategoryIds,
                innSystem and innSystem.dailyAffixIds)
        end

        self.view.ratingStarLayoutNode.gameObject:SetActiveIfNecessary(false)
        self.view.bgTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, InnConst.INN_TOPIC_EMPTY_CONFIG.bgId)
        self.view.iconTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, InnConst.INN_TOPIC_EMPTY_CONFIG.iconId)
        return
    end

    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if not hasTopic or not topicData then
        return
    end
    local isPrivateChef = topicData.topicType == GEnums.InnTopicType.PrivateChef

    self.view.bgTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, topicData.bgId)
    self.view.iconTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, topicData.iconId)
    self.view.themeNameTxt.text = topicData.name

    local unlockLevel = topicData.unlockLevel or 0
    if innLevel < unlockLevel then
        self.view.stateController:SetState("Locked")
        self.view.lockText.text = string.format(Language.LUA_INN_TOPIC_ENTRY_LOCK_TEXT, unlockLevel)
        self.view.lockNameText.text = isPrivateChef and topicData.name or Language.LUA_INN_TOPIC_ENTRY_LOCK_NAME
    else
        self.view.stateController:SetState("Normal")
    end

    if isPrivateChef then
        self.view.popularText.text = Language.LUA_INN_TOPIC_ENTRY_FASHION_PREFIX
        self:_RefreshHotItemTags(innSystem and innSystem.privateChefDailyCategoryIds,
            innSystem and innSystem.privateChefDailyAffixIds)
        self.view.ratingStarLayoutNode.gameObject:SetActiveIfNecessary(false)
    else
        local hotCategoryCount = (topicData.hotCategory and topicData.hotCategory.Count) or 0
        local hotAffixCount = (topicData.hotAffix and topicData.hotAffix.Count) or 0
        if hotCategoryCount == 0 and hotAffixCount == 0 then
            self.view.popularText.text = Language.LUA_INN_TOPIC_ENTRY_HOT_NONE
        else
            self.view.popularText.text = Language.LUA_INN_TOPIC_ENTRY_HOT_PREFIX
        end
        self:_RefreshHotItemTags(topicData.hotCategory, topicData.hotAffix)
    
        local totalStars = (topicData.starRequiredScore and topicData.starRequiredScore.Count) or 0
        local currentStars = (innSystem and innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId))) or 0
        self.view.ratingStarLayoutNode.gameObject:SetActiveIfNecessary(true)
        self.view.ratingStarLayoutNode:InitInnRatingStarLayoutNode(totalStars, currentStars)
    end
end

InnTopicEntry.SetSelected = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, select, playAnim)
    self.view.stateController:SetState(select and "Select" or "NoSelect")
    if select and playAnim then
        self.view.selectNode:PlayInAnimation()
    end
end






InnTopicEntry._RefreshHotItemTags = HL.Method(HL.Opt(HL.Any, HL.Any)) << function(self, categoryIds, affixIds)
    local categoryCount = (categoryIds and categoryIds.Count) or 0
    local affixCount = (affixIds and affixIds.Count) or 0
    
    local tagArgsList = {}
    for i = 0, categoryCount - 1 do
        tagArgsList[#tagArgsList + 1] = {
            tagId = categoryIds[i],
            isHot = false,
            upCount = 0,
        }
    end
    for i = 0, affixCount - 1 do
        tagArgsList[#tagArgsList + 1] = {
            tagId = affixIds[i],
            isHot = false,
            upCount = 0,
        }
    end
    self.m_innItemTagCache:Refresh(#tagArgsList, function(cell, index)
        cell:InitInnItemTag(tagArgsList[index])
    end)
end

HL.Commit(InnTopicEntry)
return InnTopicEntry

