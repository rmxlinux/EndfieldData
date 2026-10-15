local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

FacBatchSelectFrame = HL.Class('FacBatchSelectFrame', UIWidgetBase)

FacBatchSelectFrame.m_uiCamera = HL.Field(CS.UnityEngine.Camera)
FacBatchSelectFrame.m_coordinateRoot = HL.Field(CS.UnityEngine.RectTransform)


FacBatchSelectFrame._OnFirstTimeInit = HL.Override() << function(self)
end

FacBatchSelectFrame.InitFacBatchSelectFrame = HL.Method(CS.UnityEngine.Camera, CS.UnityEngine.RectTransform)
        << function(self, uiCamera, coordinateRoot)
    self:_FirstTimeInit()
    self.m_uiCamera = uiCamera
    self.m_coordinateRoot = coordinateRoot
    self.gameObject:SetActive(false)
end

FacBatchSelectFrame.Begin = HL.Method(HL.Boolean) << function(self, reverse)
    self.gameObject:SetActive(true)
    self.view.stateController:SetState(reverse and "Reverse" or "Normal")
end

FacBatchSelectFrame.UpdateFrame = HL.Method(HL.Table) << function(self, model)
    local uiPosA = UIUtils.objectPosToUI(model.worldMin, self.m_uiCamera, self.m_coordinateRoot)
    local uiPosB = UIUtils.objectPosToUI(model.worldMax, self.m_uiCamera, self.m_coordinateRoot)
    self.rectTransform.anchoredPosition = Vector2(math.min(uiPosA.x, uiPosB.x), math.max(uiPosA.y, uiPosB.y))
    self.rectTransform.sizeDelta = Vector2(math.abs(uiPosB.x - uiPosA.x), math.abs(uiPosB.y - uiPosA.y))

    local startUIPos = UIUtils.objectPosToUI(model.dragStartWorldPos, self.m_uiCamera, self.m_coordinateRoot)
    local endUIPos = UIUtils.objectPosToUI(model.dragEndWorldPos, self.m_uiCamera, self.m_coordinateRoot)
    local iconPosState
    if startUIPos.x <= endUIPos.x then
        iconPosState = startUIPos.y >= endUIPos.y and "LeftTop" or "LeftBottom"
    else
        iconPosState = startUIPos.y >= endUIPos.y and "RightTop" or "RightBottom"
    end
    self.view.stateController:SetState(iconPosState)
end

FacBatchSelectFrame.End = HL.Method() << function(self)
    self.gameObject:SetActive(false)
end

FacBatchSelectFrame.Cancel = HL.Method() << function(self)
    self.gameObject:SetActive(false)
end

HL.Commit(FacBatchSelectFrame)
return FacBatchSelectFrame

