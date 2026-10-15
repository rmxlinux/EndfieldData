local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnTopicDetailNode = HL.Class('InnTopicDetailNode', UIWidgetBase)

InnTopicDetailNode.m_args = HL.Field(HL.Table)

InnTopicDetailNode.m_requireTxtCache = HL.Field(HL.Forward("UIListCache"))

InnTopicDetailNode.m_categoryTagCache = HL.Field(HL.Forward("UIListCache"))

InnTopicDetailNode.m_affixTagCache = HL.Field(HL.Forward("UIListCache"))


InnTopicDetailNode._OnFirstTimeInit = HL.Override() << function(self)
    self.m_requireTxtCache = self.m_requireTxtCache or UIUtils.genCellCache(self.view.requireTxt)
    self.m_categoryTagCache = self.m_categoryTagCache or UIUtils.genCellCache(self.view.categoryTag)
    self.m_affixTagCache = self.m_affixTagCache or UIUtils.genCellCache(self.view.affixTag)
end







InnTopicDetailNode.InitInnTopicDetailNode = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.m_args = args
    local topicId = args.topicId
    local topicData
    if not topicId or string.isEmpty(topicId) then
        topicId = ""
        self:_RefreshNoTopic()
    else
        local hasTopic
        hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
        if not hasTopic or not topicData then
            return
        end
        if topicData.topicType == GEnums.InnTopicType.PrivateChef then
            self:_RefreshPrivateChefTopic(topicData)
        else
            self:_RefreshTopic(topicData)
        end
    end
    self.view.tipsInfoTxt.text = string.format(Language.LUA_INN_TOPIC_TIPS_INFO, Tables.innManagementConst.topicHotCategoryTipRate * 100)
    self:_RefreshRatingStar(topicId, topicData)
    self:_RefreshHistoryMaxScore(topicId)
end


InnTopicDetailNode._RefreshRatingStar = HL.Method(HL.String, HL.Opt(HL.Userdata)) << function(self, topicId, topicData)
    local isNormalTopic = topicData ~= nil and topicData.topicType ~= GEnums.InnTopicType.PrivateChef
    local showRatingStar = (self.m_args.showRatingStar == true) and isNormalTopic
    self.view.innRatingStarLayoutNode.gameObject:SetActiveIfNecessary(showRatingStar)
    if not showRatingStar then
        return
    end
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local totalStars = (topicData.starRequiredScore and topicData.starRequiredScore.Count) or 0
    local currentStars = (innSystem and innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId))) or 0
    self.view.innRatingStarLayoutNode:InitInnRatingStarLayoutNode(totalStars, currentStars)
end

InnTopicDetailNode._RefreshHistoryMaxScore = HL.Method(HL.String) << function(self, topicId)
    local hasHistoryMaxScore, historyMaxScore = false, 0
    if self.m_args.showHistoryMaxScore == true then
        hasHistoryMaxScore, historyMaxScore = GameInstance.player.innSystem.historyMaxScore:TryGetValue(topicId)
    end
    self.view.historyMaxScoreNode.gameObject:SetActiveIfNecessary(hasHistoryMaxScore)
    if hasHistoryMaxScore then
        self.view.historyMaxScoreTxt.text = tostring(historyMaxScore)
    end
end

InnTopicDetailNode._RefreshExtraDesc = HL.Method(HL.Opt(HL.String)) << function(self, extraDesc)
    local hasExtraDesc = not string.isEmpty(extraDesc)
    self.view.extraDescTxt.gameObject:SetActiveIfNecessary(hasExtraDesc)
    if hasExtraDesc then
        self.view.extraDescTxt:SetAndResolveTextStyle(extraDesc)
    end
end

InnTopicDetailNode._RefreshTopic = HL.Method(HL.Userdata) << function(self, topicData)
    self.view.stateController:SetState("Topic")

    self.view.topicTxt.text = topicData.name
    self.view.descTxt:SetAndResolveTextStyle(string.format(topicData.desc, Tables.innManagementConst.topicHotCategoryTipRate * 100, Tables.innManagementConst.topicHotAffixTipRate * 100))

    self.view.bonusTitle.gameObject:SetActiveIfNecessary(not string.isEmpty(topicData.objectiveDesc))
    self.view.bonusTxt:SetAndResolveTextStyle(topicData.objectiveDesc)

    self:_RefreshExtraDesc(topicData.extraDesc)

    self:_RefreshRequirement(topicData)

    local hotCategoryCount = (topicData.hotCategory and topicData.hotCategory.Count) or 0
    local hotAffixCount = (topicData.hotAffix and topicData.hotAffix.Count) or 0
    self:_RefreshHotTagNode(self.view.hotCategoryNode, self.m_categoryTagCache, topicData.hotCategory,
        hotCategoryCount, hotAffixCount)
    self:_RefreshHotTagNode(self.view.hotAffixNode, self.m_affixTagCache, topicData.hotAffix,
        hotAffixCount, hotCategoryCount)
end

InnTopicDetailNode._RefreshRequirement = HL.Method(HL.Userdata) << function(self, topicData)
    local requirementList = topicData.requirementList
    local requirementCount = (requirementList and requirementList.Count) or 0
    local texts = {}
    self.m_requireTxtCache:Refresh(requirementCount > 0 and 1 or 0, function(cell, index)
        cell.text:SetAndResolveTextStyle(topicData.requirementDesc or "")
        texts[#texts + 1] = {
            text = topicData.requirementDesc or "",
            uiText = cell.text,
        }
    end)
    self.view.itemRichText:InitItemRichText({
        texts = texts,
        posType = self.m_args.itemTipsPosType or UIConst.UI_TIPS_POS_TYPE.RightTop,
        tipTransform = self.view.requireNode.transform,
        keyHintText = Language.ui_innkitchensettings_requirenode_titletext,
        enableNavi = true,
    })
    self.view.requireTitle.gameObject:SetActiveIfNecessary(requirementCount > 0)
end





InnTopicDetailNode._RefreshHotTagNode = HL.Method(HL.Userdata, HL.Forward("UIListCache"), HL.Any, HL.Number, HL.Number)
    << function(self, node, tagCache, tagList, selfCount, otherCount)
    if selfCount == 0 and otherCount == 0 then
        node.gameObject:SetActiveIfNecessary(true)
        node:SetState("None")
        tagCache:Refresh(0)
        self.view.tipsInfoNode.gameObject:SetActiveIfNecessary(false)
        return
    end
    if selfCount == 0 then
        node.gameObject:SetActiveIfNecessary(false)
        tagCache:Refresh(0)
        return
    end
    node.gameObject:SetActiveIfNecessary(true)
    node:SetState("Label")
    tagCache:Refresh(selfCount, function(cell, index)
        cell:InitInnItemTag({
            tagId = tagList[index - 1],
            isHot = false,
            upCount = 0,
        })
    end)
end

InnTopicDetailNode._RefreshNoTopic = HL.Method() << function(self)
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local innLevel = (innSystem and innSystem.innLevel) or 0
    local innConst = Tables.innManagementConst
    local fashionUnlockLevel = (innConst and innConst.fashionUnlockLevel) or 0

    self.view.topicTxt.text = Language.LUA_INN_TOPIC_NONE_TITLE
    self.view.descTxt:SetAndResolveTextStyle(Language.LUA_INN_TOPIC_NONE_DESC)

    self:_RefreshExtraDesc(nil)

    if innLevel < fashionUnlockLevel then
        self.view.stateController:SetState("PopularLocked")
        self.view.popularLockedTxt:SetAndResolveTextStyle(string.format(Language.LUA_INN_TOPIC_DETAIL_POPULAR_LOCKED, fashionUnlockLevel))
        return
    end

    self.view.stateController:SetState("Popular")

    self.view.popularCountDownText:InitCountDownText(Utils.getNextCommonServerRefreshTime(), function()
        self:InitInnTopicDetailNode(self.m_args)
    end)

    local hotCategoryCount = innSystem.dailyCategoryIds.Count
    local hotAffixCount = innSystem.dailyAffixIds.Count
    self:_RefreshHotTagNode(self.view.hotCategoryNode, self.m_categoryTagCache, innSystem.dailyCategoryIds,
    hotCategoryCount, hotAffixCount)
    self:_RefreshHotTagNode(self.view.hotAffixNode, self.m_affixTagCache, innSystem.dailyAffixIds,
    hotAffixCount, hotCategoryCount)
end

InnTopicDetailNode._RefreshPrivateChefTopic = HL.Method(HL.Userdata) << function(self, topicData)
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    self.view.stateController:SetState("PrivateChef")

    self.view.topicTxt.text = topicData.name
    self.view.descTxt:SetAndResolveTextStyle(topicData.desc)

    self:_RefreshExtraDesc(topicData.extraDesc)

    self.view.popularCountDownText:InitCountDownText(Utils.getNextCommonServerRefreshTime(), function()
        self:InitInnTopicDetailNode(self.m_args)
    end)

    self:_RefreshRequirement(topicData)

    local hotCategoryCount = innSystem.privateChefDailyCategoryIds.Count
    local hotAffixCount = innSystem.privateChefDailyAffixIds.Count
    self:_RefreshHotTagNode(self.view.hotCategoryNode, self.m_categoryTagCache, innSystem.privateChefDailyCategoryIds,
        hotCategoryCount, hotAffixCount)
    self:_RefreshHotTagNode(self.view.hotAffixNode, self.m_affixTagCache, innSystem.privateChefDailyAffixIds,
        hotAffixCount, hotCategoryCount)
end

HL.Commit(InnTopicDetailNode)
return InnTopicDetailNode
