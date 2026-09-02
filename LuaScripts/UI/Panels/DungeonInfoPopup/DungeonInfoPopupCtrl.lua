
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonInfoPopup

DungeonInfoPopupCtrl = HL.Class('DungeonInfoPopupCtrl', uiCtrl.UICtrl)






DungeonInfoPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

DungeonInfoPopupCtrl.m_params = HL.Field(HL.Table)

DungeonInfoPopupCtrl.m_closeCb = HL.Field(HL.Function)

DungeonInfoPopupCtrl.m_dungeonInfoCellCache = HL.Field(HL.Forward("UIListCache"))


DungeonInfoPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self.view.mask.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)

    self:BindInputPlayerAction("common_dungeon_info", function()
        self:_OnBtnCloseClick()
    end, self.view.btnClose.groupId)

    self.m_params = arg.dungeonId and DungeonUtils.getInfoPopupParams(arg.dungeonId) or arg
    self.m_closeCb = arg.closeCb
    self.m_dungeonInfoCellCache = UIUtils.genCellCache(self.view.dungeonInfoCell)

    self:_Refresh()

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

DungeonInfoPopupCtrl._Refresh = HL.Method() << function(self)
    self.view.titleText.text = self.m_params.titleText
    self.view.positionTxt.text = self.m_params.positionText
    self.view.positionNode.gameObject:SetActiveIfNecessary(not string.isEmpty(self.m_params.positionText))

    local featureInfos = self.m_params.featureInfos
    local hasFeature = #featureInfos > 0
    if hasFeature then
        self.m_dungeonInfoCellCache:Refresh(#featureInfos, function(cell, index)
            cell.txt:SetAndResolveTextStyle(featureInfos[index])
        end)
    end
    self.view.featureNode.gameObject:SetActiveIfNecessary(hasFeature)
end

DungeonInfoPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    self:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Close)
    if self.m_closeCb then
        self.m_closeCb()
    end
end

HL.Commit(DungeonInfoPopupCtrl)
