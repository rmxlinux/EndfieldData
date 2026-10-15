local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnKitchenAdditionDetails

InnKitchenAdditionDetailsCtrl = HL.Class('InnKitchenAdditionDetailsCtrl', uiCtrl.UICtrl)

InnKitchenAdditionDetailsCtrl.m_kitchenId = HL.Field(HL.Number) << 0

InnKitchenAdditionDetailsCtrl.m_probCellCache = HL.Field(HL.Forward('UIListCache'))

InnKitchenAdditionDetailsCtrl.m_tagDetailCellCache = HL.Field(HL.Forward('UIListCache'))







InnKitchenAdditionDetailsCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


InnKitchenAdditionDetailsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_kitchenId = (arg and arg.kitchenId) or 0
    self.m_probCellCache = UIUtils.genCellCache(self.view.probCell)
    self.m_tagDetailCellCache = UIUtils.genCellCache(self.view.tagAddItionDetailsCell)

    self:_InitAction()
    self:_RefreshRareProb()
    self:_RefreshKitchenTagDetails()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end

InnKitchenAdditionDetailsCtrl._InitAction = HL.Method() << function(self)
    local topNode = self.view.commonTopTitleNode
    if topNode and topNode.closeButton then
        topNode.closeButton.onClick:AddListener(function()
            self:PlayAnimationOutAndClose()
        end)
    end
    self.view.blackBgImage.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
end

InnKitchenAdditionDetailsCtrl._RefreshRareProb = HL.Method() << function(self)
    local total, details = InnUtils.getKitchenRareRate(self.m_kitchenId, true)
    if self.view.rareProbNumTxt then
        self.view.rareProbNumTxt.text = string.format("%.0f%%", (total or 0) * 100)
    end
    details = details or {}
    self.m_probCellCache:Refresh(#details, function(cell, index)
        local row = details[index]
        if not row then
            return
        end
        if cell.probTypeTxt then
            cell.probTypeTxt.text = row.title or ""
        end
        if cell.probDetailTxt then
            cell.probDetailTxt.text = row.desc or ""
        end
    end)
end



InnKitchenAdditionDetailsCtrl._BuildKitchenTagDetailTexts = HL.Method(HL.Table).Return(HL.Table) << function(self, mergedRows)
    local kitchenSetting = InnUtils.findKitchenSetting(self.m_kitchenId)
    local charIds = InnUtils.kitchenCharStringIds(kitchenSetting)
    local tagToText = InnUtils.collectInnSkillDetailTextByTagFromCharIds(charIds)

    local out = {}
    for i, row in ipairs(mergedRows) do
        out[i] = tagToText[row.tagId] or ""
    end
    return out
end

InnKitchenAdditionDetailsCtrl._RefreshKitchenTagDetails = HL.Method() << function(self)
    local innSystem = GameInstance.player and GameInstance.player.innSystem
    local topicId = (innSystem and innSystem.gameSetting and innSystem.gameSetting.topicId) or ""
    local catRows, affRows = InnUtils.getKitchenSkillTagRows(self.m_kitchenId, topicId)
    local merged = lume.concat(catRows, affRows)
    local detailTexts = self:_BuildKitchenTagDetailTexts(merged)

    self.m_tagDetailCellCache:Refresh(#merged, function(cell, index)
        local row = merged[index]
        if not row then
            return
        end
        if cell.innItemTagBig and cell.innItemTagBig.InitInnItemTag then
            cell.innItemTagBig:InitInnItemTag(row.args)
        end
        if cell.detailsTxt then
            cell.detailsTxt.text = detailTexts[index] or ""
        end
        local bg = (index % 2 == 1) and "SingularBg" or "EvenBg"
        cell.stateController:SetState(bg)
    end)
end

HL.Commit(InnKitchenAdditionDetailsCtrl)
