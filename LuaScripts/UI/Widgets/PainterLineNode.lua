local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

PainterLineNode = HL.Class('PainterLineNode', UIWidgetBase)

PainterLineNode.fromPointNode = HL.Field(HL.Forward("PainterPointNode"))
PainterLineNode.toPointNode = HL.Field(HL.Forward("PainterPointNode"))


PainterLineNode._OnFirstTimeInit = HL.Override() << function(self)
    
end

PainterLineNode.InitPainterLineNode = HL.Method() << function(self)
    self:_FirstTimeInit()

    
end

PainterLineNode.BindPointNodes = HL.Method(HL.Forward("PainterPointNode"), HL.Forward("PainterPointNode")) << function(self, fromPointNode, toPointNode)
    self.fromPointNode = fromPointNode
    self.toPointNode = toPointNode
end

PainterLineNode.RefreshLength = HL.Method() << function(self)
    if self.fromPointNode and self.toPointNode then
        if self.fromPointNode.pointData.screenPos.z < 0 or self.toPointNode.pointData.screenPos.z < 0 then
            self.rectTransform.sizeDelta = Vector2(0, self.rectTransform.sizeDelta.y)
        else
            local fromPos = self.fromPointNode.rectTransform.anchoredPosition
            local toPos = self.toPointNode.rectTransform.anchoredPosition
            local length = Vector2.Distance(fromPos, toPos)
            self.rectTransform.sizeDelta = Vector2(length, self.rectTransform.sizeDelta.y)
        end
    end
end

PainterLineNode.SetHighlight = HL.Method(HL.Boolean) << function(self, highlight)
    if highlight then
        self.view.stateController:SetState("Highlight")
    else
        self.view.stateController:SetState("Normal")
    end
end

HL.Commit(PainterLineNode)
return PainterLineNode

