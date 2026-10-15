local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GambleBattleFinalSettlement

GambleBattleFinalSettlementCtrl = HL.Class('GambleBattleFinalSettlementCtrl', uiCtrl.UICtrl)






GambleBattleFinalSettlementCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


GambleBattleFinalSettlementCtrl.m_system = HL.Field(HL.Any)


GambleBattleFinalSettlementCtrl.m_resultCellCache = HL.Field(HL.Forward("UIListCache"))


GambleBattleFinalSettlementCtrl.m_luckyCardCellCache = HL.Field(HL.Forward("UIListCache"))

GambleBattleFinalSettlementCtrl.m_handled = HL.Field(HL.Boolean) << false


local RATE_BASE = 100


local NEW_RECORD_AUDIO_DELAY = 1


GambleBattleFinalSettlementCtrl.ShowGambleBattleFinalSettlement = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonSettlement", function()
        UIManager:Open(PANEL_ID, args)
    end, function()
        if UIManager:IsShow(PANEL_ID) then
            UIManager:Close(PANEL_ID)
        end
    end)
end


GambleBattleFinalSettlementCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_system = GameInstance.player.gambleBattleSystem
    ActivityUtils.playGambleBattleBgm("_finish")
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self.m_handled = false

    self:_BindButtons()
    self:_RefreshTitle()
    self:_RefreshHeader()
    self:_RefreshAchievement()
    self:_RefreshConvert()
    
    self.view.autoExitTxt.gameObject:SetActiveIfNecessary(false)

    self.m_resultCellCache = UIUtils.genCellCache(self.view.resultCell)
    self:UpdateResultCell()
    if self.m_system.isBestScore then
        self:_StartTimer(NEW_RECORD_AUDIO_DELAY, function()
            if self:IsShow() then
                AudioAdapter.PostEvent("Au_UI_Event_NewRecord")
            end
        end, true)
    end
end

GambleBattleFinalSettlementCtrl._BindButtons = HL.Method() << function(self)
    self.view.doneBtn.onClick:RemoveAllListeners()
    self.view.doneBtn.onClick:AddListener(function()
        self:_OnDone()
    end)

    self.view.againBtn.onClick:RemoveAllListeners()
    self.view.againBtn.onClick:AddListener(function()
        self:_OnAgain()
    end)

    self.view.shareBtn.onClick:RemoveAllListeners()
    self.view.shareBtn.onClick:AddListener(function()
        if self.m_handled then
            return
        end
        
        local bottomNode = self.view.shareBtn.transform.parent.gameObject
        bottomNode:SetActive(false)
        local finishTimeNode = self.view.finishTimeTxt.gameObject
        finishTimeNode:SetActive(false)
        Notify(MessageConst.SHOW_COMMON_SHARE_PANEL, {
            type = "ActivityGambleBattle",
            timeStamp = self.view.finishTimeTxt.text,
            showPlayerInfo = true,    
            needEdge = true,          
            onCaptureEnd = function()
                bottomNode:SetActive(true)
                finishTimeNode:SetActive(true)
            end,
            onClose = function()
                bottomNode:SetActive(true)
                finishTimeNode:SetActive(true)
            end,
        })
    end)
end


GambleBattleFinalSettlementCtrl._OnDone = HL.Method() << function(self)
    if self.m_handled then
        return
    end
    self.m_handled = true
    GameInstance.dungeonManager:LeaveDungeon()
end



GambleBattleFinalSettlementCtrl._OnAgain = HL.Method() << function(self)
    if self.m_handled then
        return
    end
    local activity = GameInstance.player.activitySystem:GetActivity(Tables.GambleBattleConst.gambleBattleActivityId)
    if not activity then
        self.m_handled = true
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAMBLE_BATTLE_ACTIVITY_END)
        
        self:_StartTimer(1.5, function()
            GameInstance.dungeonManager:LeaveDungeon()
        end, true)
        return
    end
    local subGame = GameInstance.dungeonManager.curDungeonLikeSubGame
    if not subGame then
        logger.error("GambleBattleFinalSettlementCtrl._OnAgain: curDungeonLikeSubGame is nil")
        return
    end
    self.m_handled = true
    local curStatus = subGame:GetCurrentCompletionStatus()
    subGame:UserSendReStartAtStatus(curStatus, true)
    UIManager:Close(PANEL_ID)
end


GambleBattleFinalSettlementCtrl._RefreshTitle = HL.Method() << function(self)
    local CompleteReason = CS.Proto.GAMBLING_DUNGEON_COMPLETE_REASON
    local reason = self.m_system.dungeonCompleteReason
    if reason == CompleteReason.Leave then
        self.view.titleText.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_TITLE_LEAVE
    elseif reason == CompleteReason.Fail then
        self.view.titleText.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_TITLE_FAIL
    else
        self.view.titleText.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_TITLE_SUCCESS
    end
end

GambleBattleFinalSettlementCtrl._RefreshHeader = HL.Method() << function(self)
    if self.m_system.finishTimeStamp and self.m_system.finishTimeStamp > 0 then
        self.view.finishTimeTxt.text = I18nUtils.CombineStringWithLanguageSpilt("", Utils.appendUTC(Utils.timestampToDateYMDHM(self.m_system.finishTimeStamp)))
    else
        self.view.finishTimeTxt.text = ""
    end
    local totalRound = Tables.GambleBattleConst.dungeonContinuousChallengeTimes
    local curRound = self.m_system.gamblingDungeonRoundIndex + 1
    
    if self.m_system.dungeonCompleteReason == CS.Proto.GAMBLING_DUNGEON_COMPLETE_REASON.Success then
        curRound = 1
        local records = self.m_system.gamblingDungeonHistoryRecords
        for i = 0, records.Count - 1 do
            curRound = math.max(curRound, records[i].RoundIndex + 1)
        end
    end
    self.view.progressTxt.text = string.format(Language.LUA_GAMBLE_BATTLE_SUB_SETTLEMENT_PROGRESS, curRound, totalRound)
    self.view.curRewardNum.text = self.m_system.gamblingDungeonTotalPoint 
    self.view.newRecordNode.gameObject:SetActive(self.m_system.isBestScore)
end


GambleBattleFinalSettlementCtrl._RefreshAchievement = HL.Method() << function(self)
    local handTypeData = self:_FindTodayHandTypeData()
    if not handTypeData then
        self.view.achievedHandType.text = ""
        self.view.achievedNum.text = 0
        if self.m_luckyCardCellCache then
            self.m_luckyCardCellCache:Refresh(0, function() end)
        end
        return
    end

    self.view.achievedHandType.text = self:_GetHandTypeName(handTypeData)
    self.view.achievedNum.text = self:_CalcAchieveCount()

    self.m_luckyCardCellCache = self.m_luckyCardCellCache or UIUtils.genCellCache(self.view.gambleBattleCardCell)
    self.m_luckyCardCellCache:Refresh(handTypeData.showNumber.Count, function(cell, luaIndex)
        cell.numberImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/icon_" .. handTypeData.showNumber[luaIndex - 1])
        cell.typeImg:LoadSprite(UIConst.GAMBLE_BATTLE_SPRITE_FOLDER .. "/" .. handTypeData.showIcon[luaIndex - 1])
    end)
end

GambleBattleFinalSettlementCtrl._RefreshConvert = HL.Method() << function(self)
    local convertLimit = tonumber(Tables.GambleBattleConst.convertLimitNum) or 0
    self.view.convertLimitNum.text = I18nUtils.CombineStringWithLanguageSpilt("", tostring(self.m_system.maxPoint or ""))
    self.view.convertNumTxt.text = self.m_system.realPoint == 0 and "-"
        or string.format("+%s", self.m_system.realPoint)

    local activityId = Tables.GambleBattleConst.gambleBattleActivityId
    local activity = GameInstance.player.activitySystem:GetActivity(activityId)
    
    self.view.progressNumTxt.transform:Find("NowImage").gameObject:SetActive(activity ~= nil)
    if not activity then
        self.view.progressNumTxt.text = "-/-"
        self.view.convertMaxNode.gameObject:SetActive(false)
        self.view.sliderImg.fillAmount = 0
        local limitColor = UIUtils.getColorByString("AAAAAA")
        self.view.limitText.color = limitColor
        self.view.convertLimitNum.color = limitColor
        self.view.convertNumTxt.text = "-"
        return
    end
    
    local curMilestoneScore = GameInstance.player.activitySystem:GetActivityMilestoneCurrentScore(activityId)

    
    local curMilestoneMaxScore = 0
    local _, milestoneData = Tables.activityConditionalMultiStageMilestoneTable:TryGetValue(activityId)
    if milestoneData then
        for _, mileStone in pairs(milestoneData.mileStones) do
            if Utils.isCurTimeInTimeIdRange(mileStone.timeId) and mileStone.score > curMilestoneMaxScore then
                curMilestoneMaxScore = mileStone.score
            end
        end
    end

    self.view.progressNumTxt.text = string.format("%s/%s", curMilestoneScore, curMilestoneMaxScore)
    if curMilestoneMaxScore > 0 then
        self.view.sliderImg.fillAmount = math.min(curMilestoneScore / curMilestoneMaxScore, 1)
    else
        self.view.sliderImg.fillAmount = 0
    end
    local isConvertMax = curMilestoneScore >= curMilestoneMaxScore
    self.view.convertMaxNode.gameObject:SetActive(isConvertMax)
    
    local isSingleConvertMax = self.m_system.realPoint >= convertLimit
    local limitColor = UIUtils.getColorByString(isSingleConvertMax and "FF0000" or "AAAAAA")
    self.view.limitText.color = limitColor
    self.view.convertLimitNum.color = limitColor
end


GambleBattleFinalSettlementCtrl.UpdateResultCell = HL.Method() << function(self)
    local totalRound = Tables.GambleBattleConst.dungeonContinuousChallengeTimes

    local round2Record = {}
    local maxScoce = 0
    local maxLuaIndex = 0
    local records = self.m_system.gamblingDungeonHistoryRecords
    if records then
        for i = 1, records.Count do
            local record = records[i - 1]
            local luaIndex = record.RoundIndex + 1
            local score = record.AddAwardValue
            if score > maxScoce then
                maxScoce = score
                maxLuaIndex = luaIndex
            end
            round2Record[luaIndex] = record
        end
    end

    
    local CompleteReason = CS.Proto.GAMBLING_DUNGEON_COMPLETE_REASON
    local reason = self.m_system.dungeonCompleteReason
    local isInterrupted = reason == CompleteReason.Leave or reason == CompleteReason.Fail
    local firstUnchallengedLuaIndex = nil
    for i = 1, totalRound do
        if not round2Record[i] then
            firstUnchallengedLuaIndex = i
            break
        end
    end

    self.m_resultCellCache:Refresh(totalRound, function(cell, luaIndex)
        cell.countTitleTxt.text = string.format(Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_ROUND, luaIndex)

        local record = round2Record[luaIndex]
        if not record then
            cell.unchallengedNode.gameObject:SetActive(true)
            if isInterrupted and luaIndex == firstUnchallengedLuaIndex then
                cell.unchallengedNode.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_ROUND_INTERRUPTED
            else
                cell.unchallengedNode.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_ROUND_UNCHALLENGED
            end
            cell.numFinalText.gameObject:SetActive(false)
            cell.numBonusTxt.gameObject:SetActive(false)
            cell.numRateTxt.gameObject:SetActive(false)
            cell.numGainTxt.gameObject:SetActive(false)
            
            cell.maxNode.gameObject:SetActive(false)
            return
        end

        cell.unchallengedNode.gameObject:SetActive(false)
        cell.numFinalText.gameObject:SetActive(true)
        cell.numBonusTxt.gameObject:SetActive(true)
        cell.numRateTxt.gameObject:SetActive(true)
        cell.numGainTxt.gameObject:SetActive(true)

        cell.numFinalText.text = record.CardPoint 
        if record.HandTypeManification > RATE_BASE then 
            cell.numBonusTxt.text = string.format("×%.1f", record.HandTypeManification / RATE_BASE)
        else
            cell.numBonusTxt.text = Language.LUA_GAMBLE_BATTLE_FINAL_SETTLEMENT_NO_BONUS
        end
        cell.numRateTxt.text = string.format("×%.1f", record.AwardManification / RATE_BASE) 
        cell.numGainTxt.text = string.format("+%s", record.AddAwardValue) 
        cell.maxNode.gameObject:SetActive(record.CardPoint >= 20)
    end)
end


GambleBattleFinalSettlementCtrl._FindTodayHandTypeData = HL.Method().Return(HL.Any) << function(self)
    local todayHandTypeId = self.m_system.bonusHandType
    if not todayHandTypeId or todayHandTypeId == 0 then
        return nil
    end
    local ok, handTypeData = Tables.gambleBattleHandTypeTable:TryGetValue(todayHandTypeId)
    if ok then
        return handTypeData
    end
    return nil
end

GambleBattleFinalSettlementCtrl._GetHandTypeName = HL.Method(HL.Any).Return(HL.String) << function(self, handTypeData)
    local handTypeName = handTypeData.handTypeName
    if type(handTypeName) == "string" then
        return handTypeName
    end
    if handTypeName and handTypeName.GetText then
        return handTypeName:GetText()
    end
    return ""
end

GambleBattleFinalSettlementCtrl._CalcAchieveCount = HL.Method().Return(HL.Number) << function(self)
    local count = 0
    local records = self.m_system.gamblingDungeonHistoryRecords
    if records then
        for i = 1, records.Count do
            if records[i - 1].IsMatchBonus == true then
                count = count + 1
            end
        end
    end
    return count
end





GambleBattleFinalSettlementCtrl.OnClose = HL.Override() << function(self)
    
    GameInstance.player.gambleBattleSystem:SetPendingSettlement(false)
end

HL.Commit(GambleBattleFinalSettlementCtrl)
