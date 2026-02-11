local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MiniMap


















MiniMapCtrl = HL.Class('MiniMapCtrl', uiCtrl.UICtrl)


local DefenseState = CS.Beyond.Gameplay.TowerDefenseSystem.DefenseState








MiniMapCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.MIN_MAP_SHOW] = '_ShowMiniMap',
    [MessageConst.ON_SYSTEM_UNLOCK_CHANGED] = '_OnSystemUnlock',

    
    [MessageConst.ON_TOGGLE_FAC_TOP_VIEW] = '_RefreshMaskState',
    [MessageConst.ON_TOGGLE_PHASE_FORBID] = '_RefreshMaskState',

    [MessageConst.ON_SETTLEMENT_UPGRADE] = '_OnSettlementUpgrade',
}


MiniMapCtrl.m_isControllerInitialized = HL.Field(HL.Boolean) << false





MiniMapCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.mainButton.onClick:AddListener(function()
        if self:_IsInFocusState() then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_FOCUS_MODE_FORBID_OPEN_MAP)
            return
        end
        MapUtils.openMap()
    end)

    self.view.levelMapController.view.gameObject:SetActive(false)

    
    local mapManager = GameInstance.player.mapManager
    mapManager:UpdateAllFacMarkVisibleState()
    mapManager:UpdateAllFacMarkLineData()

    self:_RefreshMaskState()
    self:_InitMapControllerIfNeed()
end



MiniMapCtrl.OnClose = HL.Override() << function(self)
end



MiniMapCtrl.OnShow = HL.Override() << function(self)
    self:_InitMapControllerIfNeed()
    self:_RefreshMaskState()
end




MiniMapCtrl._OnSystemUnlock = HL.Method(HL.Table) << function(self, arg)
    local systemIndex = unpack(arg)
    if systemIndex ~= GEnums.UnlockSystemType.Map:GetHashCode() then
        return
    end
    self:_InitMapControllerIfNeed()
    self:_RefreshMaskState()
end




MiniMapCtrl._ShowMiniMap = HL.Method(HL.Table) << function(self, args)
    local isShow = unpack(args)
    self:_RefreshMiniMapShownState(isShow)
end



MiniMapCtrl._InitMapControllerIfNeed = HL.Method() << function(self)
    local isSystemUnlocked = Utils.isSystemUnlocked(GEnums.UnlockSystemType.Map)
    if isSystemUnlocked and not self.m_isControllerInitialized then
        local viewScale = DataManager.uiLevelMapConfig.miniMapViewScale
        if viewScale > 0 then
            local controllerView = self.view.levelMapController.view
            controllerView.rectTransform.localScale = Vector3.one * viewScale
            local viewSizeWidth, viewSizeHeight = controllerView.levelMapLoader:GetLoaderViewRectWidthAndHeight(false)
            controllerView.levelMapLoader.view.viewRect.sizeDelta = Vector2(viewSizeWidth / viewScale, viewSizeHeight / viewScale)
        end

        self.view.levelMapController.view.gameObject:SetActive(true)
        self.view.levelMapController:InitLevelMapController(MapConst.LEVEL_MAP_CONTROLLER_MODE.FOLLOW_CHARACTER, {
            expectedStaticElements = MapConst.MINI_MAP_EXPECTED_STATIC_ELEMENT_TYPES,
        })
        self.m_isControllerInitialized = true
    end
end





MiniMapCtrl._IsInForbiddenState = HL.Method().Return(HL.Boolean) << function(self)
    return not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Map) or
        PhaseManager:IsPhaseForbidden(PhaseId.Map)
end



MiniMapCtrl._IsInContentHiddenState = HL.Method().Return(HL.Boolean) << function(self)
    return LuaSystemManager.factory.inTopView
end



MiniMapCtrl._IsInFocusState = HL.Method().Return(HL.Boolean) << function(self)
    return Utils.isInFocusMode()
end




MiniMapCtrl._RefreshMiniMapShownState = HL.Method(HL.Boolean) << function(self, isShow)
    local isMapUnlocked = Utils.isSystemUnlocked(GEnums.UnlockSystemType.Map)
    self.view.main.gameObject:SetActiveIfNecessary(isMapUnlocked and isShow)
end




MiniMapCtrl._RefreshMaskState = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    self.view.settlementDefenseNode.gameObject:SetActive(false)
    if self:_IsInForbiddenState() then
        self.view.stateController:SetState("Forbidden")
        return
    end

    if self:_IsInContentHiddenState() then
        self.view.stateController:SetState("ContentHidden")
        return
    end

    self.view.stateController:SetState("Normal")

    if not self:_IsInFocusState() then
        self:_StartSettlementDefenseNotice()
    else
        self:_ClearCoroutine(self.m_settlementDefenseNoticeCo)
    end
end







MiniMapCtrl.m_settlementDefenseNoticeCo = HL.Field(HL.Thread)


MiniMapCtrl.m_settlementDefenseNoticeNoWait = HL.Field(HL.Boolean) << false



MiniMapCtrl._StartSettlementDefenseNotice = HL.Method() << function(self)
    self:_ClearCoroutine(self.m_settlementDefenseNoticeCo)
    if not Utils.isSettlementDefenseGuideCompleted() then
        return
    end
    self.m_settlementDefenseNoticeCo = self:_StartCoroutine(function()
        if not self.m_settlementDefenseNoticeNoWait then
            coroutine.wait(Tables.globalConst.settlementDefenseMiniMapNoticeInterval)
        end
        self.m_settlementDefenseNoticeNoWait = false
        local isInDanger = false
        local towerDefenseSystem = GameInstance.player.towerDefenseSystem
        local _, domainData = Tables.domainDataTable:TryGetValue(Utils.getCurDomainId())
        if domainData then
            local inDangerSettlementId
            for i = 1, #domainData.settlementGroup do
                local settlementId = domainData.settlementGroup[CSIndex(i)]
                if towerDefenseSystem:GetSettlementDefenseState(settlementId) == DefenseState.Danger then
                    isInDanger = true
                    inDangerSettlementId = settlementId
                    break
                end
            end
            if isInDanger then
                local _, settlementData = Tables.settlementBasicDataTable:TryGetValue(inDangerSettlementId)
                self.view.settlementDefenseNode.hintTxt.text = string.format(Language.LUA_MINI_MAP_SETTLEMENT_DEFENSE_NOTICE_FORMAT, settlementData.settlementName)
                self.view.settlementDefenseNode.gameObject:SetActive(true)
                coroutine.wait(self.view.config.SETTLEMENT_DEFENCE_NOTICE_TIME)
                self.view.settlementDefenseNode.gameObject:SetActive(false)
            else
                self.view.settlementDefenseNode.gameObject:SetActive(false)
            end
        end
    end)
end




MiniMapCtrl._OnSettlementUpgrade = HL.Method(HL.Table) << function(self, args)
    local settlementId = unpack(args)
    local level = GameInstance.player.settlementSystem:GetSettlementLevel(settlementId)
    
    local isNewLevelUnlocked = false
    
    local groupDataList = GameInstance.player.towerDefenseSystem:GetDefenseGroupDataList(settlementId)
    if groupDataList then
        for i = 1, groupDataList.Count do
            local groupData = groupDataList[CSIndex(i)]
            if groupData.normalLevel and groupData.normalLevel.isUnlocked then
                local _, levelData = Tables.towerDefenseTable:TryGetValue(groupData.normalLevel.levelId)
                if levelData and levelData.settlementLevel == level then
                    isNewLevelUnlocked = true
                    break
                end
            end
        end
    end
    if isNewLevelUnlocked then
        self.m_settlementDefenseNoticeNoWait = true
        if self:IsShow() and self.view.stateController.curStateName == "Normal" then
            self:_StartSettlementDefenseNotice()
        end
    end
end




HL.Commit(MiniMapCtrl)
