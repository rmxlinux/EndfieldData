local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

CardGameEffectReportNode = HL.Class('CardGameEffectReportNode', UIWidgetBase)


CardGameEffectReportNode.m_EffectCellsCache = HL.Field(HL.Forward("UIListCache"))


CardGameEffectReportNode.m_shownInfo = HL.Field(HL.Table)
CardGameEffectReportNode.m_shownRelicInfo = HL.Field(HL.Table)




CardGameEffectReportNode._OnFirstTimeInit = HL.Override() << function(self)
    self.m_EffectCellsCache = UIUtils.genCellCache(self.view.reportEffectCell)
    
    self:RegisterMessage(MessageConst.CARD_GAME_BLACKJACK_SHOW_EFFECT_REPORT, function()
        self:TryShowReport()
    end, true)
    self:RegisterMessage(MessageConst.CARD_GAME_BLACKJACK_UPDATE_EFFECT_REPORT, function()
        self:_OnUpdateEffectReport()
    end, true)
    self:RegisterMessage(MessageConst.CARD_GAME_BLACKJACK_HIDE_EFFECT_REPORT, function()
        self:HideReport()
    end, true)
end

CardGameEffectReportNode.InitCardGameEffectReport = HL.Method() << function(self)
    self:_FirstTimeInit()
    self:TryShowReport()
end

CardGameEffectReportNode._OnUpdateEffectReport = HL.Method() << function(self)
    local info = LuaSystemManager.cardGameBlackjackSystem:GetEffectReportInfo()
    if info == nil then
        return
    end
    if info.relicInfo ~= nil then
        self:_RefreshEffectList(info.relicInfo.effectList)
    elseif info.pickCardInfo ~= nil then
        self:_RefreshEffectList(info.pickCardInfo.effectList)
    end
end




CardGameEffectReportNode.TryShowReport = HL.Method() << function(self)
    local info = LuaSystemManager.cardGameBlackjackSystem:GetEffectReportInfo()
    if info == nil then
        self:HideReport()
        return
    end

    local pickCardInfo = info.pickCardInfo
    local relicInfo = info.relicInfo
    if pickCardInfo == nil and relicInfo == nil then
        self:HideReport()
        return
    end

    
    local needShow = not self.view.gameObject.activeSelf
    if needShow then
        self.view.gameObject:SetActive(true)
    end

    local isRebuilt = info ~= self.m_shownInfo
    local isRelicChanged = relicInfo ~= nil and relicInfo ~= self.m_shownRelicInfo
    self.m_shownInfo = info
    self.m_shownRelicInfo = relicInfo
    if isRebuilt then
        
        self.view.animationWrapper:ClearTween(false)
        self.view.animationWrapper:PlayInAnimation()
    elseif isRelicChanged then
        local relicInfoAniWrapper = self.view.reportInfoNode.relicInfoAniWrapper
        relicInfoAniWrapper:ClearTween(false)
        relicInfoAniWrapper:PlayInAnimation()
    end

    self:_RefreshPickCardUI(pickCardInfo)
    if relicInfo ~= nil then
        self.view.reportInfoNode.stateController:SetState("RelicInfo")
        self:_RefreshRelicUI(relicInfo)
        self:_RefreshEffectList(relicInfo.effectList)
    else
        local state
        if pickCardInfo.isStopPick then
            state = "StopCard"
        elseif pickCardInfo.isFirstTurn then
            state = "PickCardFirstTurn"
        else
            state = "PickCard"
        end
        self.view.reportInfoNode.stateController:SetState(state)
        
        self:_RefreshEffectList(pickCardInfo.effectList)
    end
end

CardGameEffectReportNode._RefreshPickCardUI = HL.Method(HL.Opt(HL.Table)) << function(self, pickCardInfo)
    local reportSeatIndexNode = self.view.reportSeatIndexNode
    if pickCardInfo == nil then
        reportSeatIndexNode.gameObject:SetActive(false)
        return
    end
    reportSeatIndexNode.gameObject:SetActive(true)
    reportSeatIndexNode.stateController:SetState(pickCardInfo.isSelf and "Self" or "Other")
    reportSeatIndexNode.reportSeatIndexTxt.text = string.format(Language.LUA_CARD_GAME_SHOW_CARD_REPORT_SEAT_TEXT, pickCardInfo.seatIndex)
    reportSeatIndexNode.seatIndexIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, pickCardInfo.seatIndex))
end

CardGameEffectReportNode._RefreshRelicUI = HL.Method(HL.Table) << function(self, relicInfo)
    local reportInfoNode = self.view.reportInfoNode
    reportInfoNode.relicIcon:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC, relicInfo.relicIcon)
    reportInfoNode.relicNameTxt.text = relicInfo.relicName
end

CardGameEffectReportNode.HideReport = HL.Method() << function(self)
    self.m_shownInfo = nil
    self.m_shownRelicInfo = nil
    self.view.animationWrapper:PlayOutAnimation(function()
        self.view.gameObject:SetActive(false)
    end)
end



CardGameEffectReportNode.ClearEffectList = HL.Method() << function(self)
    self.m_EffectCellsCache:Refresh(0)
end

CardGameEffectReportNode._RefreshEffectList = HL.Method(HL.Opt(HL.Table)) << function(self, effectList)
    effectList = effectList or {}
    local count = #effectList
    self.m_EffectCellsCache:Refresh(#effectList, function(cell, index)
        local info = effectList[index]
        cell.effectIcon:LoadSprite(UIConst.UI_SPRITE_CARD_GAME_RELIC, info.effectIcon)
        cell.effectTxt.text = info.effectDesc
        cell.animationWrapper:ClearTween(false)
        if count ~= index then
            cell.animationWrapper:SampleToInAnimationEnd()
        else
            cell.animationWrapper:SampleToInAnimationBegin()
        end
    end)
    local lastCell = self.m_EffectCellsCache:Get(#effectList)
    if lastCell == nil then
        return
    end
    local scrollRect = self.view.reportEffectListNode
    
    LayoutRebuilder.ForceRebuildLayoutImmediate(scrollRect.content)
    scrollRect:AutoScrollToRectTransform(lastCell.transform, true)
    lastCell.animationWrapper:PlayInAnimation()
end


HL.Commit(CardGameEffectReportNode)
return CardGameEffectReportNode
