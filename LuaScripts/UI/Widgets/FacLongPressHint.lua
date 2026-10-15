local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local pressHintDelay = 0.2
local pressDuration = 0.5

FacLongPressHint = HL.Class('FacLongPressHint', UIWidgetBase)

FacLongPressHint.m_pressHintCor = HL.Field(HL.Thread)


FacLongPressHint._OnFirstTimeInit = HL.Override() << function(self)
end

FacLongPressHint.InitLongPressHint = HL.Method() << function(self)
    self:_FirstTimeInit()
    self:StopLongPressHint()
end

FacLongPressHint.StartLongPressHint = HL.Method(HL.Boolean, RectTransform, Vector4)
        << function(self, isLongPressToDragHint, canvasRectTransform, padding)
    self:StopLongPressHint()
    self.m_pressHintCor = self:_StartCoroutine(function()
        local targetTime = Time.unscaledTime + pressHintDelay
        repeat
            coroutine.step()
            if Input.touchCount > 1 then
                
                self:StopLongPressHint()
                return
            end
        until Time.unscaledTime >= targetTime

        self.view.longPressToDragHint.gameObject:SetActive(isLongPressToDragHint)
        self.gameObject:SetActive(true)

        local canvasRect = canvasRectTransform.rect
        local ratio = canvasRect.width / Screen.width
        local pos = (InputManager.mousePosition * ratio):XY()
        pos.x = lume.clamp(pos.x, padding.z, canvasRect.width - padding.w)
        pos.y = lume.clamp(pos.y, padding.y, canvasRect.height - padding.x)
        self.rectTransform.anchoredPosition = pos

        self.view.image.fillAmount = 0
        self.view.image:DOFillAmount(1, pressDuration - pressHintDelay):OnComplete(function()
            if isLongPressToDragHint then
                self.view.animationWrapper:PlayOutAnimation()
            else
                self:StopLongPressHint()
            end
        end)

        targetTime = Time.unscaledTime + pressDuration - pressHintDelay
        repeat
            coroutine.step()
            if Input.touchCount > 1 then
                
                self:StopLongPressHint()
                return
            end
        until Time.unscaledTime >= targetTime
    end)
end

FacLongPressHint.StopLongPressHint = HL.Method() << function(self)
    self.m_pressHintCor = self:_ClearCoroutine(self.m_pressHintCor)
    self.gameObject:SetActive(false)
    self.view.image:DOKill()
end

HL.Commit(FacLongPressHint)
return FacLongPressHint

