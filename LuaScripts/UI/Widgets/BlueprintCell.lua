local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')







BlueprintCell = HL.Class('BlueprintCell', UIWidgetBase)




BlueprintCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.button.onClick:AddListener(function()
        self.m_onClick()
    end)
end


BlueprintCell.m_onClick = HL.Field(HL.Function)


BlueprintCell.m_showStatus = HL.Field(HL.Boolean) << false




BlueprintCell.InitBlueprintCell = HL.Method(HL.Table) << function(self, arg)
    local inst = arg.inst
    local onClick = arg.onClick
    self.m_showStatus = arg.showStatus
    self:_FirstTimeInit()

    self.m_onClick = onClick

    local bpInfo = inst.csInst.info
    self.view.icon:InitBlueprintIcon(bpInfo.icon.icon, bpInfo.icon.baseColor)

    self.view.nameTxt.text = bpInfo.name
    self.view.delMark.gameObject:SetActive(inst.isDel == true)
    self.view.redDot:InitRedDot("SingleBlueprint", inst.id)
    self.view.gameObject.name = "BP_"..inst.csInst.param:ToString()

    local reviewStatus = inst.csInst.reviewStatus
    if inst.csInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Sys or inst.csInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Gift then
        reviewStatus = CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.Approved
    end
    self:RefreshCellState(reviewStatus)
end




BlueprintCell.RefreshCellState = HL.Method(HL.Any) << function(self, reviewStatus)
    if self.m_showStatus then
        if reviewStatus == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.Approved then
            self.view.inAuditNode.gameObject:SetActive(false)
            self.view.canShareNode.gameObject:SetActive(true)
        elseif reviewStatus == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.InProgress then
            self.view.inAuditNode.gameObject:SetActive(true)
            self.view.canShareNode.gameObject:SetActive(false)
        else
            self.view.inAuditNode.gameObject:SetActive(false)
            self.view.canShareNode.gameObject:SetActive(false)
        end
    else
        self.view.inAuditNode.gameObject:SetActive(false)
        self.view.canShareNode.gameObject:SetActive(false)
    end
end


HL.Commit(BlueprintCell)
return BlueprintCell
