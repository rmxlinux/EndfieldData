local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')









DungeonCommonSelectionCell = HL.Class('DungeonCommonSelectionCell', UIWidgetBase)


DungeonCommonSelectionCell.m_dungeonId = HL.Field(HL.String) << ""


DungeonCommonSelectionCell.m_clickFunc = HL.Field(HL.Function)


DungeonCommonSelectionCell.m_styleNode = HL.Field(HL.Any)

local UIState = {
    Lock = "Lock",
    Unlock = "Unlock",
    Complete = "Complete",
    Raid = "Raid",

    UnlockChar = "UnlockChar",
    UnlockRed = "UnlockRed",
    UnlockYellow = "UnlockYellow",
    UnlockGreen = "UnlockGreen",
    LockRed = "LockRed",
    LockYellow = "LockYellow",
    LockGreen = "LockGreen",

    Select = "Select",
    Unselect = "Unselect",
}





DungeonCommonSelectionCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.clickBtn.onClick:AddListener(function()
        if self.m_clickFunc then
            self.m_clickFunc()
        end
    end)
end





DungeonCommonSelectionCell.InitDungeonCommonSelectionCell = HL.Method(HL.String, HL.Function)
        << function(self, dungeonId, clickFunc)
    self:_FirstTimeInit()

    self.m_dungeonId = dungeonId
    self.m_clickFunc = clickFunc

    local dungeonCfg = Tables.dungeonTable[dungeonId]
    self.view.levelDescTxt.text = dungeonCfg.dungeonLevelDesc
    if not string.isEmpty(dungeonCfg.relatedCharId) then
        self.view.charNameTxt.text = dungeonCfg.dungeonLevelDesc
        self.view.charImg:LoadSprite(UIConst.UI_SPRITE_SQUARE_CHAR_HEAD,
                                     UIConst.UI_CHAR_HEAD_SQUARE_PREFIX..CSCharUtils.GetCharTemplateId(dungeonCfg.relatedCharId))
    end

    self:_UpdateState()

    self.view.redDot:InitRedDot("DungeonReadNormal", {dungeonId}, nil, self:GetUICtrl().view.redDotScrollRect)

    
    local inRelief = DungeonUtils.isDungeonCostStamina(dungeonId) and ActivityUtils.hasStaminaReduceCount()
    self.view.reliefTab.gameObject:SetActive(inRelief)
end




DungeonCommonSelectionCell.SetSelected = HL.Method(HL.Boolean) << function(self, isOn)
    
    
    self:_UpdateState(isOn)

    
    if isOn then
        GameInstance.player.subGameSys:SendSubGameListRead({ self.m_dungeonId })
    end
end




DungeonCommonSelectionCell._UpdateState = HL.Method(HL.Opt(HL.Boolean)) << function(self, isOn)
    
    local dungeonId = self.m_dungeonId
    local isRaid = Tables.dungeonRaidTable:TryGetValue(dungeonId)

    local dungeonCfg = Tables.dungeonTable[dungeonId]
    local isUnlock = DungeonUtils.isDungeonUnlock(dungeonId)
    local isComplete
    local isNormalComplete = isRaid and DungeonUtils.isDungeonPassed(dungeonId)

    if isRaid then
        isComplete = DungeonUtils.isDungeonPassed(Tables.dungeonRaidTable[dungeonId].RelatedLevel) and DungeonUtils.isDungeonPassed(dungeonId)
    else
        isComplete = DungeonUtils.isDungeonPassed(dungeonId)
    end


    local state1
    if isComplete then
        state1 = UIState.Complete
    elseif isNormalComplete then
        state1 = UIState.Raid
    elseif isUnlock then
        state1 = UIState.Unlock
    else
        state1 = UIState.Lock
    end
    self.view.stateController:SetState(state1)

    local hasHunterMode = not string.isEmpty(dungeonCfg.hunterModeRewardId)
    local hasCustomRewardId = not string.isEmpty(dungeonCfg.customRewardId)
    local hasCharInfo = not string.isEmpty(dungeonCfg.relatedCharId)
    local state2
    if isUnlock then
        if hasCharInfo then
            state2 = UIState.UnlockChar
        elseif hasHunterMode then
            state2 = UIState.UnlockRed
        elseif hasCustomRewardId then
            state2 = UIState.UnlockYellow
        else
            state2 = UIState.UnlockGreen
        end
    else
        if hasHunterMode then
            state2 = UIState.LockRed
        elseif hasCustomRewardId then
            state2 = UIState.LockYellow
        else
            state2 = UIState.LockGreen
        end
    end
    self.view.stateController:SetState(state2)

    local state3 = isOn and "Select" or "Unselect"
    self.view.stateController:SetState(state3)
end

HL.Commit(DungeonCommonSelectionCell)
return DungeonCommonSelectionCell

