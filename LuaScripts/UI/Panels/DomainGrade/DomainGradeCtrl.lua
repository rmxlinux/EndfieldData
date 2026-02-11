
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainGrade
local PHASE_ID = PhaseId.DomainGrade

local DEFAULT_DOMAIN = "domain_1"


local UNOPENED_LV = 99999
















DomainGradeCtrl = HL.Class('DomainGradeCtrl', uiCtrl.UICtrl)


DomainGradeCtrl.m_domainId = HL.Field(HL.String) << ""


DomainGradeCtrl.m_domainLevelData = HL.Field(HL.Table)


DomainGradeCtrl.m_genGradeListCellFunc = HL.Field(HL.Function)


DomainGradeCtrl.m_defaultNaviIndex = HL.Field(HL.Number) << 1






DomainGradeCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_DOMAIN_DEVELOPMENT_LEVEL_REWARD_GET] = 'OnDomainDevelopmentLevelRewardGet',
}





DomainGradeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local domainId
    if arg then
        local value
        if type(arg) == "string" then
            value = arg
        elseif type(arg) == "table" then
            value = arg.domainId
        end
        if string.isEmpty(value) then
            domainId = DEFAULT_DOMAIN
        else
            domainId = value
        end
    else
        domainId = DEFAULT_DOMAIN
    end
    self.m_domainId = domainId

    self.m_genGradeListCellFunc = UIUtils.genCachedCellFunction(self.view.listScrollView)

    self.view.listScrollView.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_UpdateGradeListCell(gameObject, csIndex)
    end)

    
    if self.view.redDotScrollRect then
        self.view.redDotScrollRect.getRedDotStateAt = function(csIndex)
            return self:GetRedDotStateAt(csIndex)
        end
    end

    self.view.backBtn.onClick:AddListener(function()
        self:_OnClickBtnBack()
    end)

    self.view.historyBtn.onClick:AddListener(function()
        self:_OnClickHistoryBtn()
    end)

    self:_UpdateMoneyCell()

    self:_UpdateContentList(true)

    self:_UpdateDomainDevLv()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end



DomainGradeCtrl._OnClickBtnBack = HL.Method() << function(self)
    PhaseManager:PopPhase(PHASE_ID)
end



DomainGradeCtrl._OnClickHistoryBtn = HL.Method() << function(self)
    UIManager:Open(PanelId.DomainGradeSourceInstruction, self.m_domainId)
end





DomainGradeCtrl._UpdateGradeListCell = HL.Method(GameObject, HL.Number) << function(self, gameObject, csIndex)
    
    local cell = self.m_genGradeListCellFunc(gameObject)
    local luaIndex = LuaIndex(csIndex)

    cell:InitDomainGradeListCell(self.m_domainId, self.m_domainLevelData[luaIndex])
end



DomainGradeCtrl._UpdateMoneyCell = HL.Method() << function(self)
    local dataSucc, domainDevData = GameInstance.player.domainDevelopmentSystem.domainDevDataDic:TryGetValue(self.m_domainId)
    if not dataSucc then
        logger.error("DomainGradeCtrl._UpdateMoneyCell cant find domainDevData: ", self.m_domainId)
        return
    end

    local goldItemId = domainDevData.domainDataCfg.domainGoldItemId
    local maxCount = domainDevData.curLevelData.moneyLimit
    self.view.domainTopMoneyTitle:InitDomainTopMoneyTitle(goldItemId, maxCount)
end




DomainGradeCtrl._UpdateContentList = HL.Method(HL.Boolean) << function(self, isInit)
    local domainDevSys = GameInstance.player.domainDevelopmentSystem
    local dataSucc, domainDevData = domainDevSys.domainDevDataDic:TryGetValue(self.m_domainId)
    if not dataSucc then
        logger.error("DomainGradeCtrl._UpdateContentList cant find domainDevData: ", self.m_domainId)
        return
    end

    
    local domainDevCfg = domainDevData.domainDataCfg
    local domainLevelData = domainDevCfg.domainDevelopmentLevel
    local curMaxLv = domainLevelData.Count
    local isFinalMaxLv = domainLevelData[curMaxLv - 1].isFinalMaxLevel


    local curLv = domainDevData.lv
    local minNotGetRewardLevel = 0  
    self.m_domainLevelData = {}
    for level = 1, curMaxLv do
        local canGet = level <= curLv and not domainDevSys:IsLevelRewarded(self.m_domainId, level)
        if minNotGetRewardLevel <= 0 and canGet then
            minNotGetRewardLevel = level
        end
        table.insert(self.m_domainLevelData, {
            lv = level,
        })
    end
    
    if not isFinalMaxLv then
        table.insert(self.m_domainLevelData, {
            lv = UNOPENED_LV,
            isUnopenedLevel = true,
        })
    end

    table.sort(self.m_domainLevelData, Utils.genSortFunction({ "lv" }, false))

    local cellIndex = minNotGetRewardLevel <= 0 and curMaxLv - curLv + 1 or curMaxLv - minNotGetRewardLevel + 1
    if not isFinalMaxLv then
        cellIndex = cellIndex + 1   
    end
    if isInit then
        self.view.listScrollView:UpdateCount(#self.m_domainLevelData, CSIndex(cellIndex))
    else
        self.view.listScrollView:UpdateCount(#self.m_domainLevelData, false)
    end
    self.m_defaultNaviIndex = cellIndex
    
    self:_StartCoroutine(function()
        coroutine.step()
        if DeviceInfo.usingController then
            local cell = self.m_genGradeListCellFunc(self.m_defaultNaviIndex)
            if cell then
                InputManagerInst.controllerNaviManager:SetTarget(cell.view.naviDeco)
            end
        else
            
            if self.m_defaultNaviIndex ~= self.view.listScrollView.count then
                local y = self.view.listScrollRect.verticalNormalizedPosition
                
                local container = self.view.listScrollRect.content
                self.view.listScrollRect.verticalNormalizedPosition = y - 100 / container.rect.y
            end
        end
    end)
end



DomainGradeCtrl._UpdateDomainDevLv = HL.Method() << function(self)
    local dataSucc, domainDevData = GameInstance.player.domainDevelopmentSystem.domainDevDataDic:TryGetValue(self.m_domainId)
    if not dataSucc then
        logger.error("DomainGradeCtrl._UpdateDomainDevLv cant find domainDevData: ", self.m_domainId)
        return
    end

    local curLv = domainDevData.lv
    self.view.lvTxt.text = curLv

    local curLevelUpExp = domainDevData.curLevelData.levelUpExp
    local curExp = domainDevData.exp
    local isMaxLv = curLevelUpExp < 0

    self.view.nowNumberTxt.text = curExp
    self.view.fullNumberTxt.text = isMaxLv and "/-" or string.format("/%d", curLevelUpExp)
    self.view.slider.value = isMaxLv and 1 or curExp / curLevelUpExp
    
    local domainCfg = Tables.domainDataTable[self.m_domainId]
    local colorStr = domainCfg.domainGradeTitleColor
    
    local color = UIUtils.getColorByString(colorStr)
    color.a = self.view.colorImg1.color.a
    self.view.colorImg1.color = color
    
    color.a = self.view.colorImg2.color.a
    self.view.colorImg2.color = color
    
    color.a = self.view.sliderFillImg.color.a
    self.view.sliderFillImg.color = color
    
    color.a = self.view.nowNumberTxt.color.a
    self.view.nowNumberTxt.color = color
    
    color.a = self.view.lvTxt.color.a
    self.view.lvTxt.color = color
end




DomainGradeCtrl.OnDomainDevelopmentLevelRewardGet = HL.Method(HL.Any) << function(self, args)
    local changedLevels = unpack(args)
    local rewards = {}
    
    for i = 0, changedLevels.Count - 1 do
        local level = changedLevels[i]
        local domainDevelopmentLevelCfg = Tables.domainDataTable[self.m_domainId].domainDevelopmentLevel[level - 1]
        local rewardId = domainDevelopmentLevelCfg.rewardId
        local succ, rewardTableData = Tables.rewardTable:TryGetValue(rewardId)
        if succ then
            local itemBundles = rewardTableData.itemBundles
            for i = 0, itemBundles.Count - 1 do
                table.insert(rewards, itemBundles[i])
            end
        end
    end

    self:Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
        title = Language.LUA_DOMAIN_DEV_GET_LEVEL_REWARD_TITLE,
        items = rewards,
    })

    self:_UpdateContentList(true)
end




DomainGradeCtrl.GetRedDotStateAt = HL.Method(HL.Number).Return(HL.Number) << function(self, index)
    local luaIndex = LuaIndex(index)
    if luaIndex < 1 or luaIndex > #self.m_domainLevelData then
        return 0  
    end

    local levelData = self.m_domainLevelData[luaIndex]
    if not levelData or levelData.isUnopenedLevel then
        return 0  
    end

    local level = levelData.lv

    
    local domainHasRedDot, domainRedDotType = RedDotManager:GetRedDotState("DomainGradeReward", self.m_domainId)

    
    if not domainHasRedDot then
        return 0  
    end

    
    local domainDevSys = GameInstance.player.domainDevelopmentSystem

    
    local dataSucc, domainDevData = domainDevSys.domainDevDataDic:TryGetValue(self.m_domainId)
    if not dataSucc then
        return 0  
    end

    local curLv = domainDevData.lv

    
    local reachedLevel = level <= curLv
    local isRewarded = domainDevSys:IsLevelRewarded(self.m_domainId, level)
    local hasReward = level > 1  

    if reachedLevel and not isRewarded and hasReward then
        return domainRedDotType or UIConst.RED_DOT_TYPE.Normal
    end

    return 0  
end

HL.Commit(DomainGradeCtrl)
