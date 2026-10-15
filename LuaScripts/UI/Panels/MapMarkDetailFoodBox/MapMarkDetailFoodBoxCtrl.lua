local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailFoodBox

local ItemBundleListType = CS.System.Collections.Generic.List(CS.Beyond.Cfg.ItemBundle)

MapMarkDetailFoodBoxCtrl = HL.Class('MapMarkDetailFoodBoxCtrl', uiCtrl.UICtrl)

local MAX_LEVEL = 4





























MapMarkDetailFoodBoxCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DOODAD_GROUP_DATA_CHANGE] = '_OnDoodadGroupDataChange',
}



MapMarkDetailFoodBoxCtrl.m_markInstId = HL.Field(HL.String) << ""


MapMarkDetailFoodBoxCtrl.m_viewModel = HL.Field(HL.Table)

MapMarkDetailFoodBoxCtrl.m_rewardItemCache = HL.Field(HL.Forward("UIListCache"))










MapMarkDetailFoodBoxCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    if not self:_InitData(arg) then
        logger.error("MapMarkDetailFoodBoxCtrl _InitData false")
        
    end
    self:_InitUI()
    self:_RefreshUI()
end












MapMarkDetailFoodBoxCtrl._InitData = HL.Method(HL.Any).Return(HL.Boolean) << function(self, arg)
    self.m_viewModel = {
        markInstId = self.m_markInstId,
        title = InnUtils.getFoodBoxTitle(""),
        foodBoxLevel = 0,
        isMaxLevel = false,
        rewardItems = {},
        hasReward = false,
    }

    if arg == nil or string.isEmpty(arg.markInstId) then
        logger.error("[MapMarkDetailFoodBoxCtrl] no markInstId in arg")
        return false
    end

    self.m_markInstId = arg.markInstId
    self.m_viewModel.markInstId = self.m_markInstId

    local doodadGroupData =
        GameInstance.player.doodadSystem:GetDoodadSystemDataByMarkInst(self.m_markInstId)
    if doodadGroupData == nil then
        logger.error("[MapMarkDetailFoodBoxCtrl] failed to get doodad group data: ", self.m_markInstId)
        return false
    end

    self.m_viewModel.foodBoxLevel =
        GameInstance.player.farmTerminalSystem:GetFoodBoxLevel(self.m_markInstId)
    self.m_viewModel.isMaxLevel = self.m_viewModel.foodBoxLevel >= MAX_LEVEL
    local rewardItems = self:_GetRewardItems()
    self.m_viewModel.rewardItems = rewardItems
    self.m_viewModel.hasReward = #rewardItems > 0
    self.m_viewModel.title = InnUtils.getFoodBoxTitle(self.m_markInstId)
    return true
end

MapMarkDetailFoodBoxCtrl._InitUI = HL.Method() << function(self)
    local commonArgs = {}
    commonArgs.markInstId = self.m_markInstId
    commonArgs.bigBtnActive = true
    commonArgs.titleText = self.m_viewModel.title
    self.view.detailCommon:InitMapMarkDetailCommon(commonArgs)

    self.m_rewardItemCache = UIUtils.genCellCache(self.view.detailCommon.view.singleDifficulty.rewardCell.itemReward)
end





MapMarkDetailFoodBoxCtrl._RefreshLevelState = HL.Method() << function(self)
    self.view.detailCommon.view.currentLevelNumTxt.text = tostring(self.m_viewModel.foodBoxLevel)
    self.view.detailCommon.view.levelStateNode:SetState(self.m_viewModel.isMaxLevel and "Max" or "Normal")
end

MapMarkDetailFoodBoxCtrl._RefreshRewardList = HL.Method() << function(self)
    
    local displayRewardItems = {}
    for _, rewardItem in ipairs(self.m_viewModel.rewardItems) do
        if rewardItem.hasGuaranteed then
            table.insert(displayRewardItems, {
                id = rewardItem.itemId,
                count = rewardItem.guaranteedCount,
                typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.Regular,
            })
        end
        if rewardItem.hasProbability then
            table.insert(displayRewardItems, {
                id = rewardItem.itemId,
                
                typeTag = DungeonConst.DUNGEON_REWARD_TAG_STATE.Random,
            })
        end
    end

    
    self.m_rewardItemCache:Refresh(#displayRewardItems, function(cell, index)
        cell:InitItem(displayRewardItems[index], true)
        cell:SetExtraInfo({
            tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
            tipsPosTransform = self.view.singleDifficulty.transform,
            isSideTips = true,
        })
        cell.view.rewardedCover.gameObject:SetActive(false)
    end)
end









MapMarkDetailFoodBoxCtrl._OnDoodadGroupDataChange = HL.Method(HL.Any) << function(self, arg)
    local markInstId = unpack(arg)
    if markInstId ~= self.m_markInstId then
        return
    end
    if self:_InitData({ markInstId = markInstId }) then
        self:_RefreshUI()
    end
end









MapMarkDetailFoodBoxCtrl._RefreshUI = HL.Method() << function(self)
    self:_RefreshLevelState()
    self:_RefreshRewardList()
end


MapMarkDetailFoodBoxCtrl._GetRewardItems = HL.Method().Return(HL.Table) << function(self)
    local guaranteedBundles = GameInstance.player.farmTerminalSystem:GetFoodBoxDropItems(self.m_markInstId, false)
    logger.info("[MapMarkDetailFoodBoxCtrl] guaranteedBundles count: ", guaranteedBundles.Count)
    local allBundles = GameInstance.player.farmTerminalSystem:GetFoodBoxDropItems(self.m_markInstId, true)
    logger.info("[MapMarkDetailFoodBoxCtrl] allBundles count: ", allBundles.Count)

    local guaranteedCountByItemId = {}
    local guaranteedItemIds = {}
    for i = 0, guaranteedBundles.Count - 1 do
        local bundle = guaranteedBundles[i]
        if guaranteedCountByItemId[bundle.id] == nil then
            guaranteedCountByItemId[bundle.id] = 0
            table.insert(guaranteedItemIds, bundle.id)
        end
        guaranteedCountByItemId[bundle.id] = guaranteedCountByItemId[bundle.id] + bundle.count
    end

    local randomCountByItemId = {}
    local randomItemIds = {}
    for i = 0, allBundles.Count - 1 do
        local bundle = allBundles[i]
        if guaranteedCountByItemId[bundle.id] == nil then
            if randomCountByItemId[bundle.id] == nil then
                randomCountByItemId[bundle.id] = 0
                table.insert(randomItemIds, bundle.id)
            end
            randomCountByItemId[bundle.id] = randomCountByItemId[bundle.id] + bundle.count
        end
    end

    
    local rewardItems = {}
    for _, itemId in ipairs(guaranteedItemIds) do
        table.insert(rewardItems, {
            itemId = itemId,
            guaranteedCount = guaranteedCountByItemId[itemId],
            probabilityCount = 0,
            hasGuaranteed = true,
            hasProbability = false,
        })
    end
    for _, itemId in ipairs(randomItemIds) do
        table.insert(rewardItems, {
            itemId = itemId,
            guaranteedCount = 0,
            probabilityCount = randomCountByItemId[itemId],
            hasGuaranteed = false,
            hasProbability = true,
        })
    end
    return rewardItems
end



HL.Commit(MapMarkDetailFoodBoxCtrl)
