local DomainPOIUtils = {}



DomainPOIUtils.MarkTypeMap = {
    [GEnums.DomainPoiType.KiteStation] = GEnums.MarkType.KiteStation,
    [GEnums.DomainPoiType.DomainShop] = GEnums.MarkType.DomainShop,
    [GEnums.DomainPoiType.DomainDepot] = GEnums.MarkType.DomainDepot,
    [GEnums.DomainPoiType.RecycleBin] = GEnums.MarkType.Recycler,
    [GEnums.DomainPoiType.SewageTreatPlant] = GEnums.MarkType.SewageTreatPlant,
}

DomainPOIUtils.POICanUnlock = {
    [GEnums.DomainPoiType.KiteStation] = function(levelId)
        return GameInstance.player.kiteStationSystem:GetAllCanUnlockKiteStationIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.RecycleBin] = function(levelId)
        return GameInstance.player.recycleBinSystem:GetAllCanUnlockRecycleBinIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.DomainDepot] = function(levelId)
        return GameInstance.player.domainDepotSystem:GetAllCanUnlockDomainDepotIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.DomainShop] = function(levelId)
        return DomainPOIUtils.GetAllCanUpDomainShopChannelIds(levelId, true)
    end,
}

DomainPOIUtils.POICanUpgrade = {
    [GEnums.DomainPoiType.KiteStation] = function(levelId)
        return GameInstance.player.kiteStationSystem:GetAllCanLevelUpKiteStationIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.RecycleBin] = function(levelId)
        return GameInstance.player.recycleBinSystem:GetAllCanLevelUpRecycleBinIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.DomainDepot] = function(levelId)
        return GameInstance.player.domainDepotSystem:GetAllCanUpgradeDomainDepotIdsByLevelId(levelId)
    end,
    [GEnums.DomainPoiType.DomainShop] = function(levelId)
        return DomainPOIUtils.GetAllCanUpDomainShopChannelIds(levelId, false)
    end,
    [GEnums.DomainPoiType.SewageTreatPlant] = function(levelId)
        return FactoryUtils.getSewageTreatPlantCanLevelUpIdListInTargetLevel(levelId)
    end,
}

function DomainPOIUtils.GetAllCanUpDomainShopChannelIds(levelId, isCheckUnlock)
    local channelIds = {}
    
    local level001Id = "map01_lv001"
    if levelId ~= level001Id then
        local hasCfg, cfg = Tables.shopChannelLevelPOIMapTable:TryGetValue(level001Id)
        if not hasCfg then
            return channelIds
        end
        local channelId = cfg.channelPartner
        local _, shopChannelCfg = Tables.shopChannelDevelopmentTable:TryGetValue(channelId)
        local shopGroupData = GameInstance.player.shopSystem:GetShopGroupData(shopChannelCfg.shopGroupId)
        local hasValue, curLv = shopGroupData.domainChannelData.channelLevelMap:TryGetValue(channelId)
        if not hasValue or curLv < 2 then
            return channelIds    
        end
    end
    
    local hasCfg, cfg = Tables.shopChannelLevelPOIMapTable:TryGetValue(levelId)
    if not hasCfg then
        return channelIds
    end
    local channelId = cfg.channelPartner
    
    local info = DomainPOIUtils.GetPoiUpgradeCtrlInfo[GEnums.DomainPoiType.DomainShop](channelId, false)
    
    if (isCheckUnlock and info.curLevel > 0) 
        or (not isCheckUnlock and info.curLevel <= 0)   
    then
        return channelIds
    end
    
    if string.isEmpty(info.upgradeQuestId) then
        info.questState = CS.Beyond.Gameplay.MissionSystem.QuestState.Completed
    else
        info.questState = GameInstance.player.mission:GetQuestState(info.upgradeQuestId)
    end
    if info.questState ~= CS.Beyond.Gameplay.MissionSystem.QuestState.Completed then
        return channelIds
    end
    
    if info.curLevel >= info.maxLevel then
        return channelIds
    end
    
    local _, domainCfg = Tables.domainDataTable:TryGetValue(info.domainId)
    local moneyId = domainCfg.domainGoldItemId
    local curMoneyCount = Utils.getItemCount(moneyId)
    local isMoneyEnough = curMoneyCount >= info.upgradeCostMoney
    if isMoneyEnough then
        table.insert(channelIds, channelId)
    end
    return channelIds
end







DomainPOIUtils.GetRedDotInfoFunc = {
    [GEnums.DomainPoiType.DomainDepot] = "getRedDotInfoDomainDepot",
    [GEnums.DomainPoiType.KiteStation] = "getKiteStationRedDotInfo",
}



function DomainPOIUtils.getRedDotInfoDomainDepot(domainId)
    return {
        redDotName = "DomainDepot",
        redDotArgs = domainId,
    }
end

function DomainPOIUtils.getKiteStationRedDotInfo(domainId)
    
    return {
        redDotName = "KiteStationCollectionReward",
        redDotArgs = "",
    }
end




DomainPOIUtils.CheckCanOpenPOIFunc = {
    [GEnums.DomainPoiType.DomainShop] = "checkCanOpenDomainShop",
    [GEnums.DomainPoiType.DomainDepot] = "checkCanOpenDomainDepot",
    [GEnums.DomainPoiType.KiteStation] = "checkCanOpenKiteStation",
}



function DomainPOIUtils.checkCanOpenDomainShop(domainId)
    local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    local shopGroupId = domainCfg.domainShopGroupId
    local shopGroupData = GameInstance.player.shopSystem:GetShopGroupData(shopGroupId)
    return shopGroupData.domainChannelData and shopGroupData.domainChannelData.channelLevelMap.Count > 0
end



function DomainPOIUtils.checkCanOpenDomainDepot(domainId)
    for domainDepotId, domainDepotCfg in pairs(Tables.domainDepotTable) do
        if domainDepotCfg.domainId == domainId then
            local domainDepotData = GameInstance.player.domainDepotSystem:GetDomainDepotDataById(domainDepotId)
            if domainDepotData and domainDepotData.level > 0 then
                return true
            end
        end
    end
    return false
end



function DomainPOIUtils.checkCanOpenKiteStation(domainId)
    for kiteStationId, kiteStationCfg in pairs(Tables.kiteStationLevelTable) do
        if kiteStationCfg.domainId == domainId then
            local kiteStationData = GameInstance.player.kiteStationSystem:GetKiteStationDataByInstId(kiteStationId)
            if kiteStationData and kiteStationData.level > 0 then
                return true
            end
        end
    end
    return false
end


























function DomainPOIUtils.getUpgradeCtrlArgsTemplate()
    
    return {
        
        domainId = "",  
        levelId = "",   
        titleName = "", 
        descList = {},
        
        upgradeQuestId = "",
        upgradeQuestDesc = "",
        upgradeCostMoney = 0,
        
        curLevel = 0,
        targetLevel = 0,
        maxLevel = 0,
        isFinalMaxLevel = false, 
        
        contentInfoList = {}    
    }
end




DomainPOIUtils.GetPoiUpgradeCtrlInfo = {
    [GEnums.DomainPoiType.DomainShop] = function(channelId, needContentInfo)
        local info = DomainPOIUtils.getUpgradeCtrlArgsTemplate()
        
        local _, shopChannelCfg = Tables.shopChannelDevelopmentTable:TryGetValue(channelId)
        local shopGroupId = shopChannelCfg.shopGroupId
        local _, shopGroupDomainCfg = Tables.shopGroupDomainTable:TryGetValue(shopGroupId)
        local domainId = shopGroupDomainCfg.domainId
        local _, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
        
        local _, shopGroupCfg = Tables.shopGroupTable:TryGetValue(shopGroupId)
        local commonShopId, randomShopId
        for _, shopId in pairs(shopGroupCfg.shopIds) do
            local _, shopCfg = Tables.shopTable:TryGetValue(shopId)
            if shopCfg.shopRefreshType == GEnums.ShopRefreshType.None then
                commonShopId = shopId
            elseif shopCfg.shopRefreshType == GEnums.ShopRefreshType.RefreshRandom then
                randomShopId = shopId
            end
        end
        local _, commonShopCfg = Tables.shopTable:TryGetValue(commonShopId)
        local _, randomShopCfg = Tables.shopTable:TryGetValue(randomShopId)
        
        local shopSystem = GameInstance.player.shopSystem
        local shopGroupData = shopSystem:GetShopGroupData(shopGroupId)
        local channelData = shopGroupData.domainChannelData
        local hasValue, curLv = channelData.channelLevelMap:TryGetValue(channelId)
        if not hasValue then
            curLv = 0
        end
        local nextLv = curLv + 1
        local maxLv = DomainPOIUtils.GetDomainShopChannelMaxLevel(channelId)

        local _, nextLvChannelCfg = shopChannelCfg.channelLevelMap:TryGetValue(nextLv)
        local costMoney = 0
        if nextLv <= maxLv and nextLvChannelCfg then
            for i = 0, #nextLvChannelCfg.costItemIdList - 1 do
                if nextLvChannelCfg.costItemIdList[i] == domainCfg.domainGoldItemId then
                    costMoney = nextLvChannelCfg.costItemNumList[i]
                    break
                end
            end
        end
        
        info.domainId = domainId
        info.levelId = shopChannelCfg.levelId
        info.titleName = shopChannelCfg.channelName
        local _, curLvChannelCfg = shopChannelCfg.channelLevelMap:TryGetValue(curLv)
        if curLvChannelCfg and not string.isEmpty(curLvChannelCfg.channelDesc) then
            table.insert(info.descList, curLvChannelCfg.channelDesc)
        end
        if nextLvChannelCfg and not string.isEmpty(nextLvChannelCfg.upgradeDesc) and curLv < maxLv then
            table.insert(info.descList, nextLvChannelCfg.upgradeDesc)
        end
        
        info.upgradeQuestId = Tables.shopDomainConst.domainShopUnlockQuestId
        info.upgradeQuestDesc = Language.LUA_DOMAIN_SHOP_UNLOCK_QUEST_DESC
        info.upgradeCostMoney = costMoney
        
        info.curLevel = curLv
        info.targetLevel = nextLv
        info.maxLevel = maxLv
        if curLvChannelCfg then
            info.isFinalMaxLevel = curLvChannelCfg.isFinalMaxLevel
        else
            info.isFinalMaxLevel = false
        end
        
        info.domainShopChannelId = channelId
        info.domainShopGroupId = shopGroupId
        if not needContentInfo then
            return info
        end
        
        
        if info.curLevel >= info.maxLevel then
            return info
        end
        
        local randomGoodsUnlockLv = shopSystem:GetChannelUnlockRandomGoodsLevel(randomShopId, channelId)
        
        local newlyCommonGoods = {}
        local newlyRandomGoods = {}
        for i = 0, #nextLvChannelCfg.newGoodsList - 1 do
            local newGoodsId = nextLvChannelCfg.newGoodsList[i]
            
            local _, goodsCfg = Tables.shopGoodsTable:TryGetValue(newGoodsId)
            local itemBundleCfg = UIUtils.getRewardFirstItem(goodsCfg.rewardId)
            local itemBundle = {
                id = itemBundleCfg.id,
            }
            if lume.find(commonShopCfg.shopGoodsIds, newGoodsId) then
                table.insert(newlyCommonGoods, itemBundle)
            else
                table.insert(newlyRandomGoods, itemBundle)
            end
        end
        
        if #newlyCommonGoods > 0 then
            DomainPOIUtils.insertContentCommonTitle(
                info,
                UIConst.UI_SPRITE_SHOP_TRADE_MARKET_ICON_SMALL .. "/" .. commonShopCfg.iconId,
                commonShopCfg.shopName
            )
            DomainPOIUtils.insertContentItemList(info, nil, newlyCommonGoods)
        end
        
        
        local needShowNewLimit = false
        if #newlyRandomGoods > 0 then
            local randomShopData = shopSystem:GetShopData(randomShopId)
            local curRandomShopGoodsCount = randomShopData.goodList.Count
            local curDomainRandomShopIsUnlock = shopSystem:CheckShopUnlocked(randomShopId) and curRandomShopGoodsCount > 0
            if not curDomainRandomShopIsUnlock and nextLv == randomGoodsUnlockLv then
                
                
                DomainPOIUtils.insertContentCommonTitle(
                    info,
                    UIConst.UI_SPRITE_SHOP_TRADE_MARKET_ICON_SMALL .. "/" .. randomShopCfg.iconId,
                    randomShopCfg.shopName
                )
                DomainPOIUtils.insertContentTextImgText(info, Language.LUA_DOMAIN_SHOP_UPGRADE_RANDOM_SHOP_OPEN_TITLE, {
                    {
                        text2 = Language.LUA_DOMAIN_SHOP_UPGRADE_RANDOM_SHOP_OPEN_DESC,
                        fontSizeLevel = 2,
                    }
                }, 2)
                DomainPOIUtils.insertContentItemList(info, nil, newlyRandomGoods)
            elseif curDomainRandomShopIsUnlock then
                
                DomainPOIUtils.insertContentCommonTitle(
                    info,
                    UIConst.UI_SPRITE_SHOP_TRADE_MARKET_ICON_SMALL .. "/" .. randomShopCfg.iconId,
                    randomShopCfg.shopName
                )
                DomainPOIUtils.insertContentItemList(info, nil, newlyRandomGoods)
                needShowNewLimit = true
            end
        else
            
            needShowNewLimit = true
            local isAddLimit = nextLvChannelCfg.randGoodsBaseLimitUp > 0
            local isAddLimitUp = nextLvChannelCfg.randGoodsDailyAddLimitUp > 0
            if isAddLimit or isAddLimitUp then
                DomainPOIUtils.insertContentCommonTitle(
                    info,
                    UIConst.UI_SPRITE_SHOP_TRADE_MARKET_ICON_SMALL .. "/" .. randomShopCfg.iconId,
                    randomShopCfg.shopName
                )
            end
        end
        
        if needShowNewLimit then
            local curBaseLimit = channelData.buyRandomGoodsLimitCount
            local curDailyAddLimit = channelData.buyRandomGoodsLimitUpCount
            local iconPath = UIConst.UI_SPRITE_COMMON .. "/deco_common_arrow"
            local isAddLimit = nextLvChannelCfg.randGoodsBaseLimitUp > 0
            local isAddLimitUp = nextLvChannelCfg.randGoodsDailyAddLimitUp > 0
            if isAddLimit then
                local newlyBaseLimit = nextLvChannelCfg.randGoodsBaseLimitUp + curBaseLimit
                DomainPOIUtils.insertContentTextImgText(info, Language.LUA_DOMAIN_SHOP_UPGRADE_BASE_LIMIT, {
                    {
                        text1 = curBaseLimit,
                        icon = iconPath,
                        text2 = newlyBaseLimit,
                    }
                }, 2)
            end
            if isAddLimitUp then
                local newlyDailyAddLimit = nextLvChannelCfg.randGoodsDailyAddLimitUp + curDailyAddLimit
                DomainPOIUtils.insertContentTextImgText(info, Language.LUA_DOMAIN_SHOP_UPGRADE_ADD_LIMIT, {
                    {
                        text1 = curDailyAddLimit,
                        icon = iconPath,
                        text2 = newlyDailyAddLimit,
                    }
                }, 2)
            end
        end
        
        
        return info
    end,
}



DomainPOIUtils.contentTypeEnum = {
    CommonTitle = 1,
    ItemList = 2,
    TextImgText = 3,
    RewardList = 4,
    TitleWithText = 5,
    SewageTreatInfo = 6,
}

function DomainPOIUtils.insertContentCommonTitle(upgradeCtrlArgs, titleIcon, titleName, isNew)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.CommonTitle,
        icon = titleIcon,
        titleName = titleName,
        isNew = isNew,
    }
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end

function DomainPOIUtils.insertContentItemList(upgradeCtrlArgs, title, itemBundleList)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.ItemList,
        title = title,
        itemBundleList = itemBundleList,
    }
    if itemBundleList ~= nil and #itemBundleList > 0 then
        info.useNaviGroup = true
    end
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end



function DomainPOIUtils.insertContentTextImgText(upgradeCtrlArgs, title, contentList, indentLevel, noDeco)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.TextImgText,
        title = title,
        contentList = contentList,
        indentLevel = indentLevel,
        noDeco = noDeco,
    }
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end

function DomainPOIUtils.insertContentRewardList(upgradeCtrlArgs, itemBundleList, tagStateName, hasArrow)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.RewardList,
        itemBundleList = itemBundleList,
        tagStateName = tagStateName,
        hasArrow = hasArrow,
    }
    if itemBundleList ~= nil and #itemBundleList > 0 then
        info.useNaviGroup = true
    end
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end

function DomainPOIUtils.insertContentTitleWithText(upgradeCtrlArgs, title, contentText)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.TitleWithText,
        title = title,
        contentText = contentText,
    }
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end

function DomainPOIUtils.insertContentSewageTreatInfo(upgradeCtrlArgs, isImporter, isMaxLv, currCount, nextCount)
    local info = {
        contentType = DomainPOIUtils.contentTypeEnum.SewageTreatInfo,
        isImporter = isImporter,
        isMaxLv = isMaxLv,
        currCount = currCount,
        nextCount = nextCount,
    }
    table.insert(upgradeCtrlArgs.contentInfoList, info)
end






function DomainPOIUtils.GetDomainMaxLevel(domainId)
    local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    if not hasCfg then
        logger.error("domain表数据缺失！domain id：", domainId)
        return 0
    end
    return DomainPOIUtils._CommonGetListMaxLevelFunc(domainCfg.domainDevelopmentLevel)
end

function DomainPOIUtils.GetKiteStationMaxLevel(kiteStationId)
    return GameInstance.player.kiteStationSystem:GetKiteStationMaxLevel(kiteStationId)
end

function DomainPOIUtils.GetSettlementMaxLevel(stlId)
    local _, stlCfg = Tables.settlementBasicDataTable:TryGetValue(stlId)
    if not stlCfg then
        logger.error("据点表数据缺失！据点id：", stlId)
        return 0
    end
    return DomainPOIUtils._CommonGetMapMaxLevelFunc(stlCfg.settlementLevelMap)
end

function DomainPOIUtils.GetDomainShopChannelMaxLevel(channelId)
    local _, shopChannelCfg = Tables.shopChannelDevelopmentTable:TryGetValue(channelId)
    if not shopChannelCfg then
        logger.error("地区商店渠道表数据缺失！渠道id：", channelId)
        return 0
    end
    return DomainPOIUtils._CommonGetMapMaxLevelFunc(shopChannelCfg.channelLevelMap)
end

function DomainPOIUtils.GetDomainDepotMaxLevel(depotId)
    local success, levelCfg = Tables.domainDepotLevelTable:TryGetValue(depotId)
    if not success then
        logger.error("地区仓库等级表数据缺失！仓库id：", depotId)
        return 0
    end
    return DomainPOIUtils._CommonGetMapMaxLevelFunc(levelCfg.levelList)
end



function DomainPOIUtils._CommonGetListMaxLevelFunc(levelCfgList)
    local nowMaxLv = 0
    local listLength = levelCfgList.Count
    for i = listLength, 1, -1 do
        local levelCfg = levelCfgList[CSIndex(i)]
        if Utils.isCurTimeInTimeIdRange(levelCfg.timeId, true) then
            nowMaxLv = listLength
            break
        end
    end
    return nowMaxLv
end


function DomainPOIUtils._CommonGetMapMaxLevelFunc(levelCfgMap)
    local maxLv = 0
    for level, levelCfg in pairs(levelCfgMap) do
        if Utils.isCurTimeInTimeIdRange(levelCfg.timeId, true) then
            maxLv = math.max(maxLv, level)
        end
    end
    return maxLv
end












DomainPOIUtils.GetPOILevelNewVersionInfoFunc = {
    [GEnums.DomainPoiType.Settlement] = "getSettlementLevelNewVersionInfo",
    [GEnums.DomainPoiType.DomainShop] = "getDomainShopLevelNewVersionInfo",
    [GEnums.DomainPoiType.KiteStation] = "getKiteStationLevelNewVersionInfo",
    [GEnums.DomainPoiType.DomainDepot] = "getDomainDepotLevelNewVersionInfo",
}














function DomainPOIUtils.getSettlementLevelNewVersionInfo(levelId, startVersionData, endVersionData)
    local _, stlMapCfg = Tables.settlementLevelPOIMapTable:TryGetValue(levelId)
    if not stlMapCfg then
        return nil
    end
    local stlId = stlMapCfg.settlementId
    
    local settlementSystem = GameInstance.player.settlementSystem
    
    local stlData = settlementSystem:GetUnlockSettlementData(stlId)
    if not stlData then
        return nil  
    end
    local _, stlCfg = Tables.settlementBasicDataTable:TryGetValue(stlId)
    if not stlCfg then
        logger.error("据点数据缺失，据点id：", stlId)
    end
    
    local curMaxLv = DomainPOIUtils.GetSettlementMaxLevel(stlId)
    if curMaxLv <= 0 then
        return nil
    end
    local hasMaxLvDiff = false
    for checkLv = curMaxLv, 1, -1 do
        local checkVersion = stlCfg.settlementLevelMap[checkLv].versionStart
        local checkVersionData = DomainPOIUtils._GetVersionData(checkVersion)
        if checkVersionData.versionValue < startVersionData.versionValue then
            break   
        elseif checkVersionData.versionValue <= endVersionData.versionValue then
            curMaxLv = checkLv
            hasMaxLvDiff = true
            break
        end
    end
    
    local rewardList = {}
    local itemIdSet = {}    
    local curStlLv = stlData.level
    for checkLv = 1, curStlLv do
        local itemMap = stlCfg.settlementLevelMap[checkLv].settlementTradeItemMap
        for _, stlItemCfg in pairs(itemMap) do
            if string.isEmpty(stlItemCfg.activityId) then   
                local checkVersionData = DomainPOIUtils._GetVersionData(stlItemCfg.versionStart)
                local canShow = startVersionData.versionValue <= checkVersionData.versionValue and checkVersionData.versionValue <= endVersionData.versionValue
                if canShow then
                    local itemId = stlItemCfg.itemId
                    local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
                    if not itemIdSet[itemId] and itemCfg then
                        itemIdSet[itemId] = true
                        table.insert(rewardList, {
                            id = itemId,
                            count = 1,
                            
                            rarity = itemCfg.rarity,
                            sortId1 = itemCfg.sortId1,
                            sortId2 = itemCfg.sortId2,
                        })
                    end
                end
            end
        end
    end
    table.sort(rewardList, Utils.genSortFunction({ "rarity", "sortId1", "sortId2", "id" }))
    
    if #rewardList <= 0 and not hasMaxLvDiff then
        return nil 
    end
    
    local info = {
        levelPoiName = stlCfg.settlementName,
        poiCurVersionMaxLv = hasMaxLvDiff and curMaxLv or -1,
        rewardList = rewardList
    }
    return info
end

function DomainPOIUtils.getDomainShopLevelNewVersionInfo(levelId, startVersionData, endVersionData)
    local _, channelMapCfg = Tables.shopChannelLevelPOIMapTable:TryGetValue(levelId)
    if not channelMapCfg then
        return nil
    end
    local channelId = channelMapCfg.channelPartner
    local _, channelCfg = Tables.shopChannelDevelopmentTable:TryGetValue(channelId)
    if not channelCfg then
        return nil
    end
    local shopGroupId = channelCfg.shopGroupId
    
    local shopGroupData = GameInstance.player.shopSystem:GetShopGroupData(shopGroupId)
    if not shopGroupData.domainChannelData then
        return nil
    end
    local hasValue, curLevel = shopGroupData.domainChannelData.channelLevelMap:TryGetValue(channelId)
    if not hasValue or curLevel <= 0 then
        return nil
    end
    
    local curMaxLv = DomainPOIUtils.GetDomainShopChannelMaxLevel(channelId)
    local hasMaxLvDiff = false
    for checkLv = curMaxLv, 1, -1 do
        local checkVersion = channelCfg.channelLevelMap[checkLv].versionStart
        local checkVersionData = DomainPOIUtils._GetVersionData(checkVersion)
        if checkVersionData.versionValue < startVersionData.versionValue then
            break   
        elseif checkVersionData.versionValue <= endVersionData.versionValue then
            curMaxLv = checkLv
            hasMaxLvDiff = true
            break
        end
    end
    if not hasMaxLvDiff then
        return nil
    end
    
    local info = {
        levelPoiName = channelCfg.channelName,
        poiCurVersionMaxLv = curMaxLv,
    }
    return info
end

function DomainPOIUtils.getKiteStationLevelNewVersionInfo(levelId, startVersionData, endVersionData)
    
    local kiteStationLevelCfg
    for _, cfg in pairs(Tables.kiteStationLevelTable) do
        if cfg.levelId == levelId then
            kiteStationLevelCfg = cfg
            break
        end
    end
    if not kiteStationLevelCfg then
        return nil
    end
    if GameInstance.player.kiteStationSystem:IsKiteStationUnlocked(kiteStationLevelCfg.kiteStation) == false then
        return nil
    end
    
    local curMaxLv = DomainPOIUtils.GetKiteStationMaxLevel(kiteStationLevelCfg.kiteStation)
    local hasMaxLvDiff = false
    for checkLv = curMaxLv, 1, -1 do
        local checkVersion = kiteStationLevelCfg.list[checkLv].versionStart
        local checkVersionData = DomainPOIUtils._GetVersionData(checkVersion)
        if checkVersionData.versionValue < startVersionData.versionValue then
            break   
        elseif checkVersionData.versionValue <= endVersionData.versionValue then
            curMaxLv = checkLv
            hasMaxLvDiff = true
            break
        end
    end
    if not hasMaxLvDiff then
        return nil
    end
    
    local info = {
        levelPoiName = kiteStationLevelCfg.list[curMaxLv].name,
        poiCurVersionMaxLv = curMaxLv,
    }
    return info
end

function DomainPOIUtils.getDomainDepotLevelNewVersionInfo(levelId, startVersionData, endVersionData)
    local levelDepotId, levelDepotName
    for depotId, depotCfg in pairs(Tables.domainDepotTable) do
        if depotCfg.refLevelId == levelId then
            levelDepotId = depotId
            levelDepotName = depotCfg.depotName
            break
        end
    end
    if not levelDepotId then
        return nil
    end
    local levelSuccess, domainDepotLevelList = Tables.domainDepotLevelTable:TryGetValue(levelDepotId)
    if not levelSuccess then
        return nil
    end
    local depotInfo = DomainDepotUtils.GetDepotInfo(levelDepotId)
    if depotInfo == nil or depotInfo.currLevel == 0 then
        return nil
    end
    domainDepotLevelList = domainDepotLevelList.levelList
    local curMaxLv = DomainPOIUtils.GetDomainDepotMaxLevel(levelDepotId)
    local hasMaxLvDiff = false
    for checkLv = curMaxLv, 1, -1 do
        local checkVersion = domainDepotLevelList[checkLv].versionStart
        local checkVersionData = DomainPOIUtils._GetVersionData(checkVersion)
        if checkVersionData.versionValue < startVersionData.versionValue then
            break   
        elseif checkVersionData.versionValue <= endVersionData.versionValue then
            curMaxLv = checkLv
            hasMaxLvDiff = true
            break
        end
    end
    if not hasMaxLvDiff then
        return nil
    end
    return {
        levelPoiName = levelDepotName,
        poiCurVersionMaxLv = curMaxLv,
    }
end







function DomainPOIUtils.DomainMaxLevelHasVersionDiff(domainId, gmForceRecordVersion, gmForceNowVersion)
    
    local hasVersion, recordVersion = GameInstance.player.domainDevelopmentSystem:TryReadVersion(
        domainId,
        CS.Proto.DOMAIN_DEVELOPMENT_READ_VERSION_TYPE.DomainDevSystem
    )
    
    if gmForceRecordVersion then
        hasVersion = true
        recordVersion = gmForceRecordVersion
    end
    
    if not hasVersion then
        return false
    end
    local recordVersionData = DomainPOIUtils._GetVersionData(recordVersion)
    
    local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    if not hasCfg then
        logger.error("domain表数据缺失！domain id：", domainId)
        return false
    end
    local nowMaxLv = DomainPOIUtils.GetDomainMaxLevel(domainId) 
    local nowMaxLvCfg = domainCfg.domainDevelopmentLevel[CSIndex(nowMaxLv)]
    local endVersion = nowMaxLvCfg.versionStart
    
    if gmForceNowVersion then
        endVersion = gmForceNowVersion
    end
    
    local endVersionData = DomainPOIUtils._GetVersionData(endVersion)
    
    if not gmForceNowVersion then
        if endVersionData.major ~= CS.Beyond.GlobalOptions.instance.branchVersionMajor or
            endVersionData.minor ~= CS.Beyond.GlobalOptions.instance.branchVersionMinor
        then
            return false
        end
    end

    
    
    if recordVersionData.versionValue >= endVersionData.versionValue then
        return false
    end
    
    local startVersionData = recordVersionData
    if startVersionData.major ~= endVersionData.major or startVersionData.minor ~= endVersionData.minor then
        
        startVersionData.major = endVersionData.major
        startVersionData.minor = endVersionData.minor
        startVersionData.phase = 0
    else
        
        startVersionData.phase = startVersionData.phase + 1
    end
    DomainPOIUtils._CalculateVersionValue(startVersionData)    
    
    return startVersionData, endVersionData
    
end



function DomainPOIUtils._GetVersionData(versionStr)
    local versionData = {
        isValid = false,
        major = 1,
        minor = 0,
        phase = 0,
        versionValue = 0,
    }
    if type(versionStr) == "string" and not string.isEmpty(versionStr) then
        local major, minor, phase = string.match(versionStr, "^v(%d+)d(%d+)d(%d+)$")
        if major == nil then
            major, minor = string.match(versionStr, "^v(%d+)d(%d+)$")
            phase = "0"
        end
        if major ~= nil and minor ~= nil and phase ~= nil then
            versionData.major = tonumber(major) or versionData.major
            versionData.minor = tonumber(minor) or versionData.minor
            versionData.phase = tonumber(phase) or versionData.phase
            versionData.isValid = true
        end
    end
    DomainPOIUtils._CalculateVersionValue(versionData)
    return versionData
end

function DomainPOIUtils._CalculateVersionValue(versionData)
    versionData.versionValue = versionData.major * 10000 + versionData.minor * 100 + versionData.phase
end

function DomainPOIUtils.tryGetDomainNewVersionInfo(domainId, startVersionData, endVersionData)
    local hasCfg, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
    if not hasCfg then
        logger.error("domain表数据缺失！domain id：", domainId)
        return nil
    end
    local curMaxLv = DomainPOIUtils.GetDomainMaxLevel(domainId)
    for checkLv = curMaxLv, 1, -1 do
        local checkVersion = domainCfg.domainDevelopmentLevel[CSIndex(checkLv)].versionStart
        local checkVersionData = DomainPOIUtils._GetVersionData(checkVersion)
        if checkVersionData.versionValue < startVersionData.versionValue then
            break   
        elseif checkVersionData.versionValue <= endVersionData.versionValue then
            curMaxLv = checkLv
            break
        end
    end
    
    local domainVersionDiffInfo = {
        domainId = domainId,
        domainIcon = domainCfg.domainIcon,
        domainName = domainCfg.domainName,
        
        startVersionData = startVersionData,
        endVersionData = endVersionData,
        domainCurMaxLv = curMaxLv,
        poiVersionInfoList = {},
    }
    
    local poiVersionInfoList = domainVersionDiffInfo.poiVersionInfoList
    
    local poiVersionInfo = DomainPOIUtils.tryGetPOINewVersionInfo(GEnums.DomainPoiType.Settlement, domainCfg, startVersionData, endVersionData)
    if poiVersionInfo then
        table.insert(poiVersionInfoList, poiVersionInfo)
    end
    
    for _, poiType in pairs(domainCfg.domainPoiTypeGroup) do
        poiVersionInfo = DomainPOIUtils.tryGetPOINewVersionInfo(poiType, domainCfg, startVersionData, endVersionData)
        if poiVersionInfo then
            table.insert(poiVersionInfoList, poiVersionInfo)
        end
    end
    return domainVersionDiffInfo
end

function DomainPOIUtils.tryGetPOINewVersionInfo(poiType, domainCfg, startVersionData, endVersionData)
    
    local hasCfg, poiCfg = Tables.domainPoiTable:TryGetValue(poiType)
    if not hasCfg then
        return nil
    end
    
    local levelVersionInfoList = {}
    for _, levelId in pairs(domainCfg.levelGroup) do
        local levelName = Tables.levelDescTable[levelId].showName
        local funcName = DomainPOIUtils.GetPOILevelNewVersionInfoFunc[poiType]
        if not string.isEmpty(funcName) then
            local levelVersionInfo = DomainPOIUtils[funcName](levelId, startVersionData, endVersionData)
            if levelVersionInfo then
                levelVersionInfo.levelName = levelName
                table.insert(levelVersionInfoList, levelVersionInfo)
            end
        end
    end
    
    if #levelVersionInfoList > 0 then
        
        local poiVersionInfo = {
            poiType = poiType,
            poiName = poiCfg.name,
            poiIcon = poiCfg.noBackgroundIcon,
            levelVersionInfoList = levelVersionInfoList,
        }
        return poiVersionInfo
    else
        return nil
    end
end





function DomainPOIUtils.resolveOpenSettlementArgs(args)
    local domainId
    local defaultStlId
    if args and type(args) == "string" then
        
        local hasCfg, levelCfg = DataManager.levelBasicInfoTable:TryGetValue(args)
        if hasCfg then
            domainId = levelCfg.domainName
            local _, cfg = Tables.settlementLevelPOIMapTable:TryGetValue(args)
            if cfg then
                defaultStlId = cfg.settlementId
            end
        else
            domainId = args
        end
    elseif type(args) == "table" and not string.isEmpty(args.domainId) then
        domainId = args.domainId
    else
        domainId = ScopeUtil.GetCurrentChapterIdAsStr()
    end
    
    return domainId, defaultStlId
end





function DomainPOIUtils.getSettlementTradeActivityInfo()
    
    local activitySys = GameInstance.player.activitySystem
    local info = {
        
        hasActivity = false,
        activityId = "",
        openTime = 0,
        closeTime = 0,
        activityMoneyId = "",
        activityColor = Color.white,
        
        domainActivityInfos = {},
    }

    
    local idList = activitySys:GetActivityOfCertainType(GEnums.ActivityType.LimitedFormula)
    if idList.Count <= 0 then
        return info
    end
    
    local activityId = idList[0]
    info.activityId = activityId
    local _, activityCfg = Tables.activityTable:TryGetValue(activityId)
    
    
    local activityData = activitySys:GetActivity(activityId)
    if activityData.status ~= GEnums.ActivityStatus.InProgress and
        activityData.status ~= GEnums.ActivityStatus.Completed then
        return info
    end
    
    local _, limitedFormulaCfg = Tables.activityLimitedFormulaTable:TryGetValue(activityId)
    local finalStageId = limitedFormulaCfg.endStageId
    local isFinalStage = ActivityUtils.isFinalStageMultiConditionStageActivity(activityData, finalStageId)
    if isFinalStage then
        return info
    end
    

    
    info.hasActivity = true
    info.activityColor = UIUtils.getColorByString(activityCfg.themeColor)
    info.openTime = activityData.startTime
    info.closeTime = activityData.endTime
    info.activityMoneyId = limitedFormulaCfg.moneyId
    

    
    
    local _, limitedFormulaStlCfg = Tables.activityLimitedFormulaSettlementTable:TryGetValue(activityId)
    for stlId, tradeItemDict in pairs(limitedFormulaStlCfg.settlementList) do
        local stlData = GameInstance.player.settlementSystem:GetUnlockSettlementData(stlId)
        if stlData then
            local _, stlCfg = Tables.settlementBasicDataTable:TryGetValue(stlId)
            local hasCanCraftItem = false
            
            local domainId = stlCfg.domainId
            local actDomainInfo = info.domainActivityInfos[domainId]
            if not actDomainInfo then
                actDomainInfo = {}
            end
            
            local actStlInfo = actDomainInfo[stlId]
            if not actStlInfo then
                actStlInfo = {}
            end
            
            for itemId, tradeItemInfo in pairs(tradeItemDict.tradeList) do
                
                local isHide = not GameInstance.player.inventory:IsItemFound(itemId)
                if not isHide then
                    hasCanCraftItem = true
                    actStlInfo[itemId] = tradeItemInfo.moneyCount
                end
            end
            
            if hasCanCraftItem then
                info.domainActivityInfos[domainId] = actDomainInfo
                actDomainInfo[stlId] = actStlInfo
            end
        end
    end
    

    return info
end



function DomainPOIUtils.getSettlementMoneyActivityEffectInfo(stlId)
    local totalEffect = 0
    local activityId = ""
    
    local globalEffectSys = GameInstance.player.globalEffectSystem
    local effects = globalEffectSys:GetGlobalEffectByType(GEnums.GlobalEffectType.AddSettlementActivityBuff)
    if effects then
        
        for effectId, effectInfo in cs_pairs(effects) do
            local _, effectCfg = Tables.globalEffectTable:TryGetValue(effectId)
            if effectCfg then
                if effectCfg.dps[0].valueStringList == nil or effectCfg.dps[0].valueStringList.Count <= 0 then
                    logger.error("effectCfg.dps[0].valueStringList为空！effectId：", effectId)
                else
                    if effectCfg.dps[0].valueStringList[0] == stlId then
                        if effectCfg.dps[1].valueFloatList == nil or effectCfg.dps[1].valueFloatList.Count <= 0 then
                            logger.error("effectCfg.dps[1].valueFloatList为空！effectId：", effectId)
                        elseif effectCfg.dps[2].valueStringList == nil or effectCfg.dps[2].valueStringList.Count <= 0 then
                            logger.error("effectCfg.dps[2].valueStringList为空！effectId：", effectId)
                        else
                            totalEffect = totalEffect + effectCfg.dps[1].valueFloatList[0]
                            activityId = effectCfg.dps[2].valueStringList[0]
                        end
                    end
                end
            end
        end
    end
    return math.floor(totalEffect * 100), activityId
end




_G.DomainPOIUtils = DomainPOIUtils
return DomainPOIUtils