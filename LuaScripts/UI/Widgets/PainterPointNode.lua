local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')




PainterPointNodeState = {
    Hide = -1,
    Normal = 0,
    Ready = 1,
    Activated = 2,
}


PainterPointNodeSelectState = {
    UnSelectable = -1,
    Normal = 0,
    Highlight = 1,
    Selected = 2,
}

PainterPointNode = HL.Class('PainterPointNode', UIWidgetBase)

PainterPointNode.pointData = HL.Field(HL.Any)

PainterPointNode.connectNum = HL.Field(HL.Number) << 0
PainterPointNode.isMicro = HL.Field(HL.Boolean) << false

PainterPointNode.state = HL.Field(HL.Int) << 0

PainterPointNode.selectState = HL.Field(HL.Int) << 0

PainterPointNode.linkedNextPointNode = HL.Field(PainterPointNode)
PainterPointNode.linkedPrevPointNode = HL.Field(PainterPointNode)


PainterPointNode._OnFirstTimeInit = HL.Override() << function(self)

end

PainterPointNode.InitPainterPointNode = HL.Method(HL.Any) << function(self, data)
    self:_FirstTimeInit()

    
    self.pointData = data
    self.connectNum = 0
    if self.pointData.nextId > 0 then
        self.connectNum = self.connectNum+1
    end
    if self.pointData.index > 0 then
        self.connectNum = self.connectNum+1
    end
    if self.connectNum == 0 then
        self.isMicro = true
    end
    self:RefreshPosition()
    self.view.gameObject:SetActive(not self.pointData.invalid)
    self.view.lineNode.gameObject:SetActive(false)
end

PainterPointNode.LinkToNextNode = HL.Method(PainterPointNode, HL.Boolean) << function(self, nextNode, isInit)
    self.linkedNextPointNode = nextNode
    if not nextNode.pointData.invalid then
        self.view.lineNode.gameObject:SetActive(true)
        self.view.lineNode:BindPointNodes(self, nextNode)
    end
    self:RefreshArrow()
    self:RefreshPosition()
end

PainterPointNode.LinkToPrevNode = HL.Method(PainterPointNode, HL.Boolean) << function(self, prevNode, isInit)
    self.linkedPrevPointNode = prevNode
    self:RefreshArrow()
    self:RefreshPosition()
end

PainterPointNode.SetState = HL.Method(HL.Int) << function(self, state)
    self.state = state
    self.view.gameObject:SetActive(state ~= PainterPointNodeState.Hide)
    if state == PainterPointNodeState.Normal then
        self.view.stateController:SetState("Normal")
        self.view.lineNode:SetHighlight(false)
    elseif state == PainterPointNodeState.Ready then
        self.view.stateController:SetState("Ready")
        self.view.lineNode:SetHighlight(true)
    elseif state == PainterPointNodeState.Hide then

    elseif state == PainterPointNodeState.Activated then
        self.view.stateController:SetState("Activated")
    end
end

PainterPointNode.SetSelectState = HL.Method(HL.Int) << function(self, state)
    self.selectState = state
    self.view.canvasGroup.alpha = 1
    if state == PainterPointNodeSelectState.Normal then
        self.view.stateController:SetState("SelectNormal")
    elseif state == PainterPointNodeSelectState.Highlight then
        self.view.stateController:SetState("Highlight")
    elseif state == PainterPointNodeSelectState.Selected then
        self.view.stateController:SetState("Selected")
    elseif state == PainterPointNodeSelectState.UnSelectable then
        self.view.canvasGroup.alpha = 0.5
    end
end

PainterPointNode.RefreshArrow = HL.Method() << function(self)
    if self.linkedNextPointNode then
        if self.linkedNextPointNode.pointData.invalid then
            self.view.stateController:SetState("FirstInvalid")
        else
            self.view.stateController:SetState("FirstValid")
        end
        if self.linkedPrevPointNode then
            self.view.rectArrow.gameObject:SetActive(true)
            if self.linkedPrevPointNode.pointData.invalid then
                self.view.stateController:SetState("SecondInvalid")
            else
                self.view.stateController:SetState("SecondValid")
            end
        end
    else
        self.view.rectArrow.gameObject:SetActive(false)
        if self.linkedPrevPointNode.pointData.invalid then
            self.view.stateController:SetState("FirstInvalid")
        else
            self.view.stateController:SetState("FirstValid")
        end
    end
end

PainterPointNode.RefreshPosition = HL.Method() << function(self)
    if self.pointData.invalid then
        return
    end
    
    local rectTransform = self.rectTransform
    rectTransform.anchoredPosition = UIUtils.screenPointToUI(self.pointData.screenPos:XY(), CameraManager.uiCamera, self.view.transform.parent)
end

PainterPointNode.RefreshLineNode = HL.Method() << function(self)
    if self.pointData.invalid then
        return
    end
    
    local rectTransform = self.rectTransform
    if self.linkedNextPointNode then
        local dirToNext = self.linkedNextPointNode.pointData.screenPos - self.pointData.screenPos
        local angle = math.atan(dirToNext.y, dirToNext.x)*180/math.pi+90
        rectTransform.localRotation = Quaternion.Euler(0, 0, angle)
        if not self.linkedNextPointNode.pointData.invalid then
            self.view.lineNode:RefreshLength()
        end
        if self.linkedPrevPointNode then
            local dirToPrev = self.linkedPrevPointNode.pointData.screenPos - self.pointData.screenPos
            self.view.rectArrow.localRotation = Quaternion.Euler(0, 0, math.atan(dirToPrev.y, dirToPrev.x)*180/math.pi+90-angle)
        end
    elseif self.linkedPrevPointNode then
        local dirToNext = self.linkedPrevPointNode.pointData.screenPos - self.pointData.screenPos
        rectTransform.localRotation = Quaternion.Euler(0, 0, math.atan(dirToNext.y, dirToNext.x)*180/math.pi+90)
    else

    end
end

HL.Commit(PainterPointNode)
return PainterPointNode

