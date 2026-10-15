local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local MoneyCellConfig = require_ex('UI/Panels/WalletBar/MoneyCellConfig')
local CommonPOIUpgradeToastCtrl = require_ex('UI/Panels/CommonPOIUpgradeToast/CommonPOIUpgradeToastCtrl').CommonPOIUpgradeToastCtrl
local PANEL_ID = PanelId.FacFarmTerminal
local PHASE_ID = PhaseId.FacFarmTerminal
FacFarmTerminalCtrl = HL.Class('FacFarmTerminalCtrl', uiCtrl.UICtrl)

local PageType = {
    Normal = 1,
    Upgrade = 2,
}

local StatusType = {
    AutoSeed = 1,  
    AutoHarvest = 2,  
    CellEnough = 3,  
    AllEnough = 4,  
    None = 5,   
}


local FeatureType = {
    Seed = "autoReclaim",                   
    Harvest = "autoHarvest",                
    Mutation = "enableMutation",            
    Neighbor = "enableNeighborIncrease",    
}

local FARM_TERMINAL_TOAST_ICON_ID = "title_farm_terminal"






FacFarmTerminalCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_FARM_TERMINAL_DATA_CHANGED] = '_OnFarmTerminalDataChanged',
}



























FacFarmTerminalCtrl.m_viewModel = HL.Field(HL.Table)

FacFarmTerminalCtrl.m_descCellCache = HL.Field(HL.Any)

FacFarmTerminalCtrl.m_itemCellCache = HL.Field(HL.Any)

FacFarmTerminalCtrl.m_upgradeEffectContentCells = HL.Field(HL.Table)




FacFarmTerminalCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshUI(true)
end

FacFarmTerminalCtrl.OnShow = HL.Override() << function(self)
    self:_RefreshContentScroll(false)
end









FacFarmTerminalCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_viewModel = { }
    self.m_viewModel.pageType = arg.pageType or arg.PageType or PageType.Normal

    local id = arg.id
    if string.isEmpty(id) then
        logger.error("no id in arg!!!")
        return
    end
    self.m_viewModel.id = id

    local _, cfg = Tables.soilMgrTable:TryGetValue(id)
    if not cfg then
        logger.error("no table cfg for id: " .. id)
        return
    end

    local title = cfg.clientShowName
    self.m_viewModel.title = title

    local levelName = Tables.levelDescTable[cfg.sceneId].showName
    self.m_viewModel.levelName = levelName

    self.m_viewModel.descList = {}
    local descList = cfg.descList
    for _, desc in pairs(descList) do
        if not string.isEmpty(desc) then
            table.insert(self.m_viewModel.descList, desc)
        end
    end

    
    if arg.currLevel then
        self.m_viewModel.currLevel = arg.currLevel
    else
        self.m_viewModel.currLevel = self:_GetFarmTerminalSystem():GetTerminalLevel(id)
    end

    local cfgLevelDataList = cfg.levelList
    local maxLevel = 0
    for _, levelData in pairs(cfgLevelDataList) do
        if levelData.level > maxLevel then
            maxLevel = levelData.level
        end
    end

    self.m_viewModel.maxLevel = maxLevel
    self.m_viewModel.isMaxLevel = maxLevel == self.m_viewModel.currLevel
    self.m_viewModel.nextLevel = self.m_viewModel.isMaxLevel and maxLevel or self.m_viewModel.currLevel + 1

    
    self.m_viewModel.depotItemDataList = {}
    if arg.depotItemDataList then
        self.m_viewModel.depotItemDataList = arg.depotItemDataList
    else
        self.m_viewModel.depotItemDataList = self:_GetDepotItemDataListFromSystem(id)
    end

    
    self.m_viewModel.levelUpMoneyId = cfg.levelUpMoney
    self.m_viewModel.depotCapacity = 0
    for _, levelData in pairs(cfgLevelDataList) do
        if levelData.level == self.m_viewModel.currLevel then
            self.m_viewModel.depotCapacity =  levelData.depotCapacity
        end
        if levelData.level == self.m_viewModel.nextLevel then
            self.m_viewModel.levelUpCost = levelData.levelUpCost
            self.m_viewModel.requiredInnLevel = levelData.unlockInnLevel
        end
    end

    self.m_viewModel.currInnLevel = (GameInstance.player.innSystem and GameInstance.player.innSystem.innLevel) or 0

    
    if arg.statusType then
        self.m_viewModel.statusType = arg.statusType
    else
        self.m_viewModel.statusType = self:_GetStatusType()
    end

    
    local currLevelFeatureDataList = self:_GetLevelFeatureListInCfg(self.m_viewModel.currLevel)
    local nextLevelFeatureDataList = self:_GetLevelFeatureListInCfg(self.m_viewModel.nextLevel)
    self.m_viewModel.currLevelFeatureList = lume.map(currLevelFeatureDataList, function(featureData)
        return featureData.featureData
    end)
    
    local currLevelFeatureTypeList = lume.map(currLevelFeatureDataList, function(featureData)
        return featureData.featureType
    end)
    local nextLevelDiffFeatureDataList = lume.filter(nextLevelFeatureDataList, function(featureData)
        return not lume.find(currLevelFeatureTypeList, featureData.featureType)
    end)
    self.m_viewModel.nextLevelFeatureList = lume.map(nextLevelDiffFeatureDataList, function(featureData)
        return featureData.featureData
    end)

    
    local nextLevelDepotCapacity = 0
    for _, levelData in pairs(cfgLevelDataList) do
        if levelData.level == self.m_viewModel.nextLevel then
            nextLevelDepotCapacity = levelData.depotCapacity
        end
    end
    if nextLevelDepotCapacity - self.m_viewModel.depotCapacity > 0 then
        local depotCapacityDiffDesc = string.format(Language.LUA_FAC_FARM_TERMINAL_FEATURE_DEPOT_CAPACITY_DIFF, nextLevelDepotCapacity - self.m_viewModel.depotCapacity)
        table.insert(self.m_viewModel.nextLevelFeatureList, 1, {
            title = depotCapacityDiffDesc,
            desc = "",
        })
    end

    
end

FacFarmTerminalCtrl._GetLevelFeatureListInCfg = HL.Method(HL.Number).Return(HL.Table) <<
function(self, level)
    local featureDataList = {}
    local _, cfg = Tables.soilMgrTable:TryGetValue(self.m_viewModel.id)
    local cfgLevelList = cfg.levelList
    for _, levelData in pairs(cfgLevelList) do
        if levelData.level == level then
            for k, v in pairs(FeatureType) do
                if levelData[v] then
                    local _, featureCfg = Tables.soilMgrFeatureTable:TryGetValue(v)
                    table.insert(featureDataList, {
                        featureType = k,
                        sortId = featureCfg.sortId,
                        featureData = {
                            title = featureCfg.desc1,
                            desc = featureCfg.desc2,
                        }
                    })
                end
            end
        end
    end
    table.sort(featureDataList, function(a, b)
        return a.sortId < b.sortId
    end)
    return featureDataList
end

FacFarmTerminalCtrl._GetFarmTerminalSystem = HL.Method().Return(HL.Userdata) << function(self)
    return GameInstance.player.farmTerminalSystem
end

FacFarmTerminalCtrl._GetDepotItemDataListFromSystem = HL.Method(HL.String).Return(HL.Table) << function(self, id)
    local depotItemDataList = {}
    local csDepotItemDataList = self:_GetFarmTerminalSystem():GetDepotItemDataList(id)
    if csDepotItemDataList == nil then
        return depotItemDataList
    end

    for i = 0, csDepotItemDataList.Count - 1 do
        local itemData = csDepotItemDataList[i]
        table.insert(depotItemDataList, {
            index = itemData.index,
            itemId = itemData.itemId,
            count = itemData.count,
        })
    end
    return depotItemDataList
end

FacFarmTerminalCtrl._GetLevelDataInCfg = HL.Method(HL.Number).Return(HL.Opt(HL.Any)) << function(self, level)
    local _, cfg = Tables.soilMgrTable:TryGetValue(self.m_viewModel.id)
    for _, levelData in pairs(cfg.levelList) do
        if levelData.level == level then
            return levelData
        end
    end
    return nil
end

FacFarmTerminalCtrl._GetStatusType = HL.Method().Return(HL.Number) << function(self)
    if self.m_viewModel.currLevel == 0 then
        return StatusType.None
    end

    if self.m_viewModel.depotCapacity > 0 and
        #self.m_viewModel.depotItemDataList >= self.m_viewModel.depotCapacity then
        local itemLimit = Tables.factorySoilConst.SoilMgrDepotItemLimit
        for _, itemData in ipairs(self.m_viewModel.depotItemDataList) do
            if itemData.count < itemLimit then
                return StatusType.CellEnough
            end
        end
        return StatusType.AllEnough
    end

    local levelData = self:_GetLevelDataInCfg(self.m_viewModel.currLevel)
    if levelData and levelData[FeatureType.Harvest] then
        return StatusType.AutoHarvest
    end
    return StatusType.AutoSeed
end

FacFarmTerminalCtrl._InitUI = HL.Method() << function(self)
    self.view.domainTopMoneyTitle.view.closeBtn.onClick:AddListener(function()
        self:_OnBackBtnClick()
    end)
    self.view.operateGroup.upgradeSmallBtn.button.onClick:AddListener(function()
        self:_OnGotoUpgradeBtnClick()
    end)
    self.view.operateGroup.storeBtn.onClick:AddListener(function()
        self:_OnSaveBtnClick()
    end)
    self.view.operateGroup.upgradeBtn.onClick:AddListener(function()
        self:_OnUpgradeBtnClick()
    end)
    self.view.operateGroup.unlockBtn.onClick:AddListener(function()
        self:_OnUpgradeBtnClick()
    end)
    self.m_descCellCache = UIUtils.genCellCache(self.view.descTxtCell)
    self.m_itemCellCache = UIUtils.genCellCache(self.view.contentParent.cropLayout.itemCell)
    self.m_upgradeEffectContentCells = {}

    self.view.domainTopMoneyTitle.view.walletBarPlaceholder:InitWalletBarPlaceholder({ self.m_viewModel.levelUpMoneyId }, false, false)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end





FacFarmTerminalCtrl._RefreshUI = HL.Method(HL.Opt(HL.Boolean)) << function(self, resetContentPosition)
    self:_RefreshDepotFocusBinding()

    local titleNodeStateCtrl = self.view.titleNode.stateCtrl
    if self.m_viewModel.currLevel == 0 then     
        titleNodeStateCtrl:SetState("Lock")
    elseif self.m_viewModel.isMaxLevel then     
        titleNodeStateCtrl:SetState("Max")
    else                                        
        titleNodeStateCtrl:SetState("Upgrade")
    end
    if self.m_viewModel.pageType == PageType.Normal then
        
        titleNodeStateCtrl:SetState("Normal")
    end

    local titleNode = self.view.titleNode
    titleNode.mapNameTxt.text = self.m_viewModel.levelName
    titleNode.titleTxt.text = self.m_viewModel.title
    titleNode.curLvTxt.text = tostring(self.m_viewModel.currLevel)
    titleNode.maxLvTxt.text = tostring(self.m_viewModel.maxLevel)

    self.m_descCellCache:Refresh(#self.m_viewModel.descList, function(cell, index)
        cell.txt:SetAndResolveTextStyle(self.m_viewModel.descList[index])
    end)

    local contentTitleNode = self.view.contentTitleNode
    contentTitleNode.gameObject:SetActive(self.m_viewModel.pageType == PageType.Normal and self.m_viewModel.depotCapacity > 0
        or self.m_viewModel.pageType == PageType.Upgrade)
    contentTitleNode.curLvTxt.text = tostring(self.m_viewModel.currLevel)
    contentTitleNode.targetLvTxt.text = tostring(self.m_viewModel.nextLevel)
    contentTitleNode.shopInfoTitleTxt.text = self.m_viewModel.pageType == PageType.Normal
        and Language.LUA_FAC_FARM_TERMINAL_CONTENT_TITLE_NORMAL
        or Language.LUA_FAC_FARM_TERMINAL_CONTENT_TITLE_UPGRADE

    local contentParent = self.view.contentParent
    contentParent.cropLayout.gameObject:SetActive(self.m_viewModel.pageType == PageType.Normal and self.m_viewModel.depotCapacity > 0)

    
    self:_RefreshDepotItem()

    
    self:_RefreshUpgradeEffectContent()

    
    local terminalStatusStateCtrl = contentParent.cropLayout.descState
    terminalStatusStateCtrl.gameObject:SetActive(self.m_viewModel.statusType ~= StatusType.None)
    if self.m_viewModel.statusType == StatusType.AutoSeed then
        terminalStatusStateCtrl:SetState("Seedlings")
    elseif self.m_viewModel.statusType == StatusType.AutoHarvest then
        terminalStatusStateCtrl:SetState("Harvest")
    elseif self.m_viewModel.statusType == StatusType.CellEnough then
        terminalStatusStateCtrl:SetState("NoStored")
    elseif self.m_viewModel.statusType == StatusType.AllEnough then
        terminalStatusStateCtrl:SetState("Full")
    end

    
    self:_RefreshBottomButtons()
    
    self:_StartCoroutine(function()
        coroutine.step()
        self:_RefreshContentScroll(resetContentPosition == true)
    end)
end

FacFarmTerminalCtrl._RefreshContentScroll = HL.Method(HL.Boolean) << function(self, resetPosition)
    local scroll = self.view.contentScrollRect
    local content = scroll.content
    local oldPosition = content.anchoredPosition
    scroll:StopMovement()
    scroll:KillScrollTween()
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.mainNode.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(content)

    local overflowHeight = content.rect.height - scroll.viewport.rect.height
    local canScroll = overflowHeight > 1
    scroll.enabled = canScroll
    local hintState = CS.Beyond.UI.CustomUIStyle.OverrideValidState
    self.view.contentScrollHint.overrideValidState = canScroll and hintState.None or hintState.ForceNotValid
    
    local offsetY = canScroll and not resetPosition and math.max(0, math.min(oldPosition.y, overflowHeight)) or 0
    content.anchoredPosition = Vector2(0, offsetY)
end

FacFarmTerminalCtrl._RefreshDepotFocusBinding = HL.Method() << function(self)
    
    local naviGroup = self.view.contentParent.cropLayout.storeLayout
    local canFocus = self.m_viewModel.pageType == PageType.Normal and #self.m_viewModel.depotItemDataList > 0
    if not canFocus and naviGroup.IsTopLayer then
        naviGroup:ManuallyStopFocus()
    end
    InputManagerInst:ToggleBinding(naviGroup.FocusBindingId, canFocus and not naviGroup.IsTopLayer)
end

FacFarmTerminalCtrl._RefreshDepotItem = HL.Method() << function(self)
    if self.m_viewModel.pageType ~= PageType.Normal then
        return
    end
    self.m_itemCellCache:Refresh(self.m_viewModel.depotCapacity, function(cell, index)
        
        cell = cell
        local itemData = self.m_viewModel.depotItemDataList[index]
        if itemData then
            cell.itemSmall.gameObject:SetActive(true)
            cell.bgEmpty.gameObject:SetActive(false)
            cell.itemSmall:InitItem({ id = itemData.itemId, count = itemData.count }, true)
            cell.itemSmall:SetExtraInfo({
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                tipsPosTransform = self.view.contentParent.cropLayout.transform,
                isSideTips = true,
            })
        else
            cell.itemSmall.gameObject:SetActive(false)
            cell.bgEmpty.gameObject:SetActive(true)
        end
    end)
end

FacFarmTerminalCtrl._RefreshUpgradeEffectContent = HL.Method() << function(self)
    self:_ClearUpgradeEffectContent()
    if self.m_viewModel.pageType ~= PageType.Upgrade then
        return
    end

    local currLevelFeatureList = self.m_viewModel.currLevelFeatureList or {}
    self:_AddUpgradeEffectTitle(Language.LUA_FAC_FARM_TERMINAL_CURRENT_FEATURE_TITLE, "Normal")
    self:_AddUpgradeEffectDescList(currLevelFeatureList, 0)

    local nextLevelFeatureList = self.m_viewModel.nextLevelFeatureList or {}
    if self.m_viewModel.isMaxLevel or #nextLevelFeatureList <= 0 then
        return
    end

    self:_AddUpgradeEffectTitle(Language.LUA_FAC_FARM_TERMINAL_NEXT_FEATURE_TITLE, "New")
    self:_AddUpgradeEffectDescList(nextLevelFeatureList, #currLevelFeatureList)
end

FacFarmTerminalCtrl._AddUpgradeEffectTitle = HL.Method(HL.String, HL.String) << function(self, title, state)
    
    local cell = self:_GenUpgradeEffectContent(self.view.contentParent.poiUpgradeContentCommonTitle.gameObject)
    cell.titleTxt.text = title
    cell.stateController:SetState(state)

    
    if state == "Normal" then
        if self.m_viewModel.isMaxLevel then
            cell.titleTxt.color = UIUtils.getColorByString("fff800")
        else
            cell.titleTxt.color = UIUtils.getColorByString("FFFFFF")
        end
    elseif state == "New" then
        
        cell.titleTxt.color = UIUtils.getColorByString("fff800")
        cell.titleIconImg.color = UIUtils.getColorByString("fff800")
    end
end

FacFarmTerminalCtrl._AddUpgradeEffectDescList = HL.Method(HL.Table, HL.Number) << function(self, featureList, startIndex)
    
    featureList = featureList
    for index, featureData in ipairs(featureList) do
        
        local cell = self:_GenUpgradeEffectContent(self.view.contentParent.poiUpgradeContentTextImgText.gameObject)
        cell.gameObject.name = "POIUpgradeContentTextImgText" .. (startIndex + index)
        cell.titleTxt:SetAndResolveTextStyle(featureData.title)
        if string.isEmpty(featureData.desc) then
            cell.contentCell.gameObject:SetActive(false)
        else
            cell.contentCell.gameObject:SetActive(true)
            cell.contentCell.txtFontSizeStateCtrl:SetState("FontLevel2")
            cell.contentCell.iconImg.gameObject:SetActive(false)
            cell.contentCell.txt1.gameObject:SetActive(false)
            cell.contentCell.txt2:SetAndResolveTextStyle(featureData.desc)
        end
    end
end

FacFarmTerminalCtrl._GenUpgradeEffectContent = HL.Method(HL.Userdata).Return(HL.Table) << function(self, templateObj)
    if not self.m_upgradeEffectContentCells then
        self.m_upgradeEffectContentCells = {}
    end

    local child = UIUtils.addChild(self.view.contentParent.gameObject, templateObj, true)
    child.gameObject:SetActive(true)
    local cell = Utils.wrapLuaNode(child)
    table.insert(self.m_upgradeEffectContentCells, cell)
    return cell
end

FacFarmTerminalCtrl._ClearUpgradeEffectContent = HL.Method() << function(self)
    if not self.m_upgradeEffectContentCells then
        self.m_upgradeEffectContentCells = {}
        return
    end

    for _, cell in ipairs(self.m_upgradeEffectContentCells) do
        if cell and cell.gameObject and not IsNull(cell.gameObject) then
            CS.UnityEngine.GameObject.Destroy(cell.gameObject)
        end
    end
    self.m_upgradeEffectContentCells = {}
end

FacFarmTerminalCtrl._RefreshBottomButtons = HL.Method() << function(self)
    local operateGroup = self.view.operateGroup
    
    operateGroup.consumeInfoNode.gameObject:SetActive(false)
    operateGroup.upgradeSmallBtn.gameObject:SetActive(false)
    operateGroup.storeBtn.gameObject:SetActive(false)
    operateGroup.promptState.gameObject:SetActive(false)
    operateGroup.warning.gameObject:SetActive(false)
    operateGroup.consumeInfoNode.gameObject:SetActive(false)
    operateGroup.upgradeBtn.gameObject:SetActive(false)
    operateGroup.unlockBtn.gameObject:SetActive(false)

    if self.m_viewModel.pageType == PageType.Normal then
        operateGroup.upgradeSmallBtn.gameObject:SetActive(true)
        operateGroup.storeBtn.gameObject:SetActive(true)
        
        operateGroup.storeBtn.interactable = self.m_viewModel.depotCapacity > 0
    else
        local curMoneyCount = Utils.getItemCount(self.m_viewModel.levelUpMoneyId)
        local moneyEnough = curMoneyCount >= self.m_viewModel.levelUpCost
        local innLevel = self.m_viewModel.currInnLevel
        local requiredInnLevel = self.m_viewModel.requiredInnLevel
        local innLevelEnough = innLevel >= requiredInnLevel
        local moneyItemData = Utils.tryGetTableCfg(Tables.itemTable, self.m_viewModel.levelUpMoneyId)
        if self.m_viewModel.isMaxLevel then
            operateGroup.promptState.gameObject:SetActive(true)
        elseif not innLevelEnough then
            operateGroup.warning.gameObject:SetActive(true)
            operateGroup.warning.promptTxt.text = string.format(Language.LUA_FAC_FARM_TERMINAL_UPGRADE_LOCK_INN_LEVEL, requiredInnLevel)
        elseif not moneyEnough then
            operateGroup.warning.gameObject:SetActive(true)
            operateGroup.warning.promptTxt.text = string.format(Language.LUA_FAC_FARM_TERMINAL_UPGRADE_LOCK_MONEY, moneyItemData and moneyItemData.name or self.m_viewModel.levelUpMoneyId)
            operateGroup.consumeInfoNode.gameObject:SetActive(true)
        else
            operateGroup.consumeInfoNode.gameObject:SetActive(true)
            if self.m_viewModel.currLevel == 0 then
                operateGroup.unlockBtn.gameObject:SetActive(true)
            else
                operateGroup.upgradeBtn.gameObject:SetActive(true)
            end
        end
        
        self:_SetMoneyIcon(operateGroup.consumeInfoNode.consumeMoneyImg, self.m_viewModel.levelUpMoneyId)
        operateGroup.consumeInfoNode.moneyConsumeTxt.text = tostring(self.m_viewModel.levelUpCost)
    end
end


FacFarmTerminalCtrl._SetMoneyIcon = HL.Method(HL.Any, HL.Any) << function(self, image, id)
    local cfg = MoneyCellConfig.get(id)
    if cfg then
        image:LoadSprite(cfg.iconAtlas, cfg.iconId)
    else
        local itemData = Tables.itemTable:GetValue(id)
        image:LoadSprite(UIConst.UI_SPRITE_WALLET, itemData.iconId)
    end
end





FacFarmTerminalCtrl._OnBackBtnClick = HL.Method() << function(self)
    PhaseManager:PopPhase(PhaseId.FacFarmTerminal)
end

FacFarmTerminalCtrl._OnFarmTerminalDataChanged = HL.Method(HL.Any) << function(self, arg)
    local id = unpack(arg)
    if not string.isEmpty(id) and id ~= self.m_viewModel.id then
        return
    end

    self:_InitData({
        id = self.m_viewModel.id,
        pageType = self.m_viewModel.pageType,
    })
    self:_RefreshUI()
end

FacFarmTerminalCtrl._OnGotoUpgradeBtnClick = HL.Method() << function(self)
    self.m_viewModel.pageType = PageType.Upgrade
    self:_RefreshUI(true)
end

FacFarmTerminalCtrl._OnSaveBtnClick = HL.Method() << function(self)
    if #self.m_viewModel.depotItemDataList == 0 then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_FARM_TERMINAL_SAVE_ON_EMPTY)
        return
    end

    self:_GetFarmTerminalSystem():SendTransportDepotToFactory(self.m_viewModel.id)
end

FacFarmTerminalCtrl._OnUpgradeBtnClick = HL.Method() << function(self)
    self:_GetFarmTerminalSystem():SendLevelUp(self.m_viewModel.id)
end





FacFarmTerminalCtrl.OpenNormalPage = HL.StaticMethod(HL.Any) << function(arg)
    local id = unpack(arg)
    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 1,
        id = id
    })
end

FacFarmTerminalCtrl.OpenUpgradePage = HL.StaticMethod(HL.Any) << function(arg)
    local id = unpack(arg)
    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 2,
        id = id
    })
end

FacFarmTerminalCtrl.OnShowUpgradeToast = HL.StaticMethod(HL.Any) << function(arg)
    if arg == nil then
        return
    end

    local id, preLv, lv = unpack(arg)
    local _, cfg = Tables.soilMgrTable:TryGetValue(id)
    if not cfg then
        logger.error("[FacFarmTerminalCtrl] no table cfg for id: ", id)
        return
    end

    local isUnlock = preLv == 0 and lv == 1
    local title = isUnlock
        and string.format(Language.LUA_FAC_FARM_TERMINAL_UPGRADE_TOAST_UNLOCK_TITLE, cfg.clientShowName)
        or string.format(Language.LUA_FAC_FARM_TERMINAL_UPGRADE_TOAST_LEVEL_UP_TITLE, cfg.clientShowName)
    local desc = isUnlock
        and Language.LUA_FAC_FARM_TERMINAL_UPGRADE_TOAST_UNLOCK_DESC
        or Language.LUA_FAC_FARM_TERMINAL_UPGRADE_TOAST_LEVEL_UP_DESC

    CommonPOIUpgradeToastCtrl.OpenCustomToast({
        instId = id,
        preLv = preLv,
        lv = lv,
        title = title,
        descList = { desc },
        iconAtlas = UIConst.UI_SPRITE_COMMON_POI_UPGRADE_TOAST,
        iconId = FARM_TERMINAL_TOAST_ICON_ID,
    })
end







FacFarmTerminalCtrl._TestOpen = HL.Method() << function(self)
    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 1,
        id = "soil_mgr_1",
        currLevel = 1,
        depotItemDataList = {
            { itemId = "item_ticketgacha_special_single", count = 10 },
            { itemId = "item_ticketgacha_special_ten", count = 20 },
        },
        statusType = 1,
    })

    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 2,
        id = "soil_mgr_1",
        currLevel = 1,
    })

    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 1,
        id = "soil_mgr_map02_lv010_1",
    })

    PhaseManager:OpenPhase(PhaseId.FacFarmTerminal, {
        PageType = 2,
        id = "soil_mgr_1",
    })
end

FacFarmTerminalCtrl._LogFeatureList = HL.Method() << function(self)
    local getFeatureListStr = function(featureList)
        local featureStrList = {}
        for _, featureData in ipairs(featureList or {}) do
            table.insert(featureStrList, string.format("{title=%s, desc=%s}", featureData.title or "", featureData.desc or ""))
        end
        return table.concat(featureStrList, ",\n")
    end
    local currLevelFeatureStr = getFeatureListStr(self.m_viewModel.currLevelFeatureList)
    local nextLevelFeatureStr = getFeatureListStr(self.m_viewModel.nextLevelFeatureList)
    logger.info(string.format("[FacFarmTerminal] currLevelFeatureList: %s, nextLevelFeatureList: %s", currLevelFeatureStr, nextLevelFeatureStr))
end






HL.Commit(FacFarmTerminalCtrl)
