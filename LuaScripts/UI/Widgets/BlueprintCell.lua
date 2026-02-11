local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')





BlueprintCell = HL.Class('BlueprintCell', UIWidgetBase)




BlueprintCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.button.onClick:AddListener(function()
        self.m_onClick()
    end)
end


BlueprintCell.m_onClick = HL.Field(HL.Function)




BlueprintCell.InitBlueprintCell = HL.Method(HL.Table) << function(self, arg)
    local inst = arg.inst
    local onClick = arg.onClick
    local showStatus = arg.showStatus
    self:_FirstTimeInit()

    self.m_onClick = onClick

    local bpInfo = inst.csInst.info
    self.view.icon:InitBlueprintIcon(bpInfo.icon.icon, bpInfo.icon.baseColor)

    self.view.nameTxt.text = bpInfo.name
    self.view.delMark.gameObject:SetActive(inst.isDel == true)
    self.view.redDot:InitRedDot("SingleBlueprint", inst.id)
    self.view.gameObject.name = "BP_"..inst.csInst.param:ToString()

    if showStatus then
        local csInst = inst.csInst
        if csInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Sys or csInst.sourceType == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintSourceType.Gift then
            csInst.reviewStatus = CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.Approved
        end
        if csInst.reviewStatus == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.Approved then
            self.view.inAuditNode.gameObject:SetActive(false)
            self.view.canShareNode.gameObject:SetActive(true)
        elseif  csInst.reviewStatus == CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprintReviewStatus.InProgress then
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
