local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleExplain

GambleBattleExplainCtrl = HL.Class('GambleBattleExplainCtrl', uiCtrl.UICtrl)


GambleBattleExplainCtrl.m_enemyCells = HL.Field(HL.Forward("UIListCache"))


GambleBattleExplainCtrl.m_system = HL.Field(HL.Any)


GambleBattleExplainCtrl.m_gameId = HL.Field(HL.Any) << nil


GambleBattleExplainCtrl.m_close = HL.Field(HL.Boolean) << false

local PUNISH_POINT_11 = 11
local PUNISH_POINT_22 = 22






GambleBattleExplainCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

GambleBattleExplainCtrl.ShowGambleBattleExplain = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    UIManager:Open(PANEL_ID, args)
end

GambleBattleExplainCtrl.OnClose = HL.Override() << function(self)
    if self.m_gameId ~= nil then
        GameInstance.player.subGameSys:SendPrepareFinished(self.m_gameId)
    end
end


GambleBattleExplainCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    local gameId, time = unpack(args or {})
    self.m_gameId = gameId
    self.m_system = GameInstance.player.gambleBattleSystem

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local closeFunc = function()
        if self.m_close then
            return
        end
        self.m_close = true
        self.animationWrapper:PlayOutAnimation(function()
            UIManager:Close(PANEL_ID)
        end)
    end

    self.view.closeMaskBtn.onClick:RemoveAllListeners()
    self.view.closeMaskBtn.onClick:AddListener(closeFunc)
    self.view.closeButton.onClick:RemoveAllListeners()
    self.view.closeButton.onClick:AddListener(closeFunc)

    if self.m_system.curHandCards.Count == 0 then
        logger.error("敌人相关信息有效的数量为0，请检查配置")
        return
    end

    local pointNumber = 0
    for i = 1, self.m_system.curHandCards.Count do
        local cardName = self.m_system.curHandCards[i - 1]
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
        if hasCard then
            pointNumber = pointNumber + cardData.cardPoint
        end
    end

    if pointNumber >= PUNISH_POINT_22 then
        self.m_system.deBuffMonsterLevel = Tables.gambleBattleConst.secondDebuffMonsterLv
        self.m_system.deBuffTime = Tables.gambleBattleConst.secondDebuffTime
    elseif pointNumber >= PUNISH_POINT_11 then
        self.m_system.deBuffMonsterLevel = Tables.gambleBattleConst.firstDebuffMonsterLv
        self.m_system.deBuffTime = Tables.gambleBattleConst.firstDebuffTime
    else
        self.m_system.deBuffMonsterLevel = 0
        self.m_system.deBuffTime = 0
    end

    local monsterShowLevel = 0
    self.m_enemyCells = UIUtils.genCellCache(self.view.gambleBattleMainListCell)
    self.m_enemyCells:Refresh(self.m_system.curHandCards.Count, function(cell, luaIndex)
        local csIndex = CSIndex(luaIndex)
        local cardName = self.m_system.curHandCards[csIndex]
        local hasCard, cardData = Tables.GambleBattleCardTable:TryGetValue(cardName)
        if not hasCard or cardData.enemyIdList.Count == 0 then
            cell.stateController:SetState("Empty")
            return
        end

        local cardPoint = cardData.cardPoint
        local enemyId = cardData.enemyIdList[0]
        local enemyCount = cardData.enemyCountList[0]
        local enemyInfo = UIUtils.getEnemyInfoByIdAndLevel(enemyId, cardData.enemyLevel[0])
        local level = enemyInfo.level + self.m_system.deBuffMonsterLevel
        if level > monsterShowLevel then
            monsterShowLevel = level
        end

        local suitType = "tong"
        if cardData.suits == 1 then
            suitType = "tiao"
        elseif cardData.suits == 2 then
            suitType = "wan"
        end

        cell.stateController:SetState("Normal")
        cell.nameTxt.text = string.format(Language.LUA_GAMBLE_BATTLE_ENEMY_SHOW_NAME_AND_COUNT, enemyInfo.name, enemyCount)
        cell.lvTxt.text = level
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_MONSTER_ICON_BIG, enemyInfo.templateId)
        cell.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. cardPoint)
        cell.typeImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. suitType)
        cell.rightTopImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. suitType .. "_" .. cardPoint)
    end)

    if self.m_system.deBuffTime > 0 or self.m_system.deBuffMonsterLevel > 0 then
        self.view.tipsLayoutNode.gameObject:SetActive(true)
        self.view.tipsTxt.gameObject:SetActive(true)
        local challengeTime = math.max((time or 0) - self.m_system.deBuffTime, 0)
        self.view.tipsTxt.text = string.format(Language.LUA_SIMULATION_TRAINING_PRE_ATTACK_TIP, monsterShowLevel,
            math.floor(challengeTime / 60), challengeTime % 60)
    else
        self.view.tipsLayoutNode.gameObject:SetActive(false)
        self.view.tipsTxt.gameObject:SetActive(false)
    end
end











HL.Commit(GambleBattleExplainCtrl)
