
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonInfoPopup

DungeonAffixInfoPopupCtrl = HL.Class('DungeonAffixInfoPopupCtrl', uiCtrl.UICtrl)






DungeonAffixInfoPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

DungeonAffixInfoPopupCtrl.TryToShow = HL.StaticMethod(HL.Any) << function(args)
    local dungeonId = unpack(args)
    if not DungeonUtils.checkCanPopupInfoPanel(dungeonId) then
        return
    end

    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonInfo", function()
        DungeonAffixInfoPopupCtrl.AutoOpen(PANEL_ID, { dungeonId = dungeonId, closeCb = function()
            Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "DungeonInfo")
        end})
    end, function()
        UIManager:Close(PANEL_ID)
    end)
end

DungeonAffixInfoPopupCtrl.m_dungeonId = HL.Field(HL.String) << ""

DungeonAffixInfoPopupCtrl.m_affixTables = HL.Field(HL.Table)

DungeonAffixInfoPopupCtrl.m_closeCb = HL.Field(HL.Function)

DungeonAffixInfoPopupCtrl.m_dungeonInfoCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonAffixInfoPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.view.mask.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self:BindInputPlayerAction("common_dungeon_info", function()
        self:_OnBtnCloseClick()
    end, self.view.btnClose.groupId)

    self.m_dungeonId = arg.dungeonId
    self.m_closeCb = arg.closeCb
    self.m_affixTables = arg.affixTables
    self.m_dungeonInfoCellCache = UIUtils.genCellCache(self.view.dungeonInfoCell)

    self:_Refresh()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

DungeonAffixInfoPopupCtrl._Refresh = HL.Method() << function(self)
    local dungeonCfg = Tables.dungeonTable[self.m_dungeonId]
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local dungeonTypeCfg = Tables.dungeonTypeTable[gameMechanicCfg.gameCategory]

    self.view.titleText.text = string.isEmpty(dungeonTypeCfg.dungeonInfoTitle) and "TBD" or dungeonTypeCfg.dungeonInfoTitle
    
    local positionText = DungeonUtils.getEntryLocation(dungeonCfg.levelId, true)
    self.view.positionTxt.text = positionText
    self.view.positionNode.gameObject:SetActiveIfNecessary(not string.isEmpty(positionText))

    
    local hasAffix = #self.m_affixTables > 0
    if hasAffix then
        self.m_dungeonInfoCellCache:Refresh(#self.m_affixTables, function(cell, index)
            cell.txt:SetAndResolveTextStyle(self.m_affixTables[index])
        end)
    end
    self.view.featureNode.gameObject:SetActiveIfNecessary(hasAffix)
end

DungeonAffixInfoPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    self:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Close)
    if self.m_closeCb then
        self.m_closeCb()
    end
end

HL.Commit(DungeonAffixInfoPopupCtrl)
