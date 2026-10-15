local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnResultStarTips

InnResultStarTipsCtrl = HL.Class('InnResultStarTipsCtrl', uiCtrl.UICtrl)







InnResultStarTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

InnResultStarTipsCtrl.m_resultData = HL.Field(HL.Userdata)

InnResultStarTipsCtrl.m_scoreCellCache = HL.Field(HL.Forward("UIListCache"))


InnResultStarTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    
    
    self.view.autoCloseArea.onTriggerAutoClose:RemoveAllListeners()
    self.view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        
        self:PlayAnimationOutAndClose()
    end)

    if arg and arg.resultData then
        self:_RefreshScoreCells(arg.resultData)

        
        if arg.transform then
            local posType = arg.posType or UIConst.UI_TIPS_POS_TYPE.MidTop
            UIUtils.updateTipsPosition(self.view.content, arg.transform, self.view.rectTransform, self.uiCamera, posType)
        end
    end
end


InnResultStarTipsCtrl._GetStarRequiredScores = HL.Method(HL.Userdata).Return(HL.Opt(HL.Userdata)) << function(self, resultData)
    local topicId = resultData.gameSetting.topicId or ""
    if string.isEmpty(topicId) then
        local innSystem = GameInstance.player.innSystem
        local hasLevel, levelData = Tables.innLevelTable:TryGetValue(innSystem.innLevel)
        if hasLevel then
            return levelData.noTopicStarRequiredScore
        end
        return nil
    end

    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if hasTopic then
        return topicData.starRequiredScore
    end
    return nil
end


InnResultStarTipsCtrl._RefreshScoreCells = HL.Method(HL.Userdata) << function(self, resultData)
    self.m_resultData = resultData

    local scores = self:_GetStarRequiredScores(resultData)
    if scores == nil or scores.Count <= 0 then
        return
    end

    local score = resultData.totalScore
    
    local curTier = 0
    for i = 1, scores.Count do
        if score >= scores[CSIndex(i)] then
            curTier = i
        end
    end

    self.m_scoreCellCache = UIUtils.genCellCache(self.view.scoreCell)
    self.m_scoreCellCache:Refresh(scores.Count, function(cell, luaIndex)
        
        cell.scoreNumTxt.text = scores[CSIndex(luaIndex)]
        cell.starNumTxt.text = luaIndex

        local state = (luaIndex % 2 == 1) and "Bg" or "NoBg"
        if luaIndex == curTier then
            state = "Current"
        end
        cell.stateController:SetState(state)
    end)

    
    local isFullStar = curTier >= scores.Count
    if isFullStar then
        self.view.textState:SetState("MaxText")
    else
        self.view.titleTxt.text = string.format(Language.LUA_RESULT_STAR_TIPS_TITLE, scores[CSIndex(curTier + 1)] - score, curTier + 1)
        self.view.textState:SetState("NorText")
    end
end











HL.Commit(InnResultStarTipsCtrl)
