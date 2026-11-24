
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BigLogo

BigLogoCtrl = HL.Class('BigLogoCtrl', uiCtrl.UICtrl)






BigLogoCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SHOW_BIG_LOGO] = '_OnShowBigLogo',
    [MessageConst.ON_LOAD_NEW_CUTSCENE] = '_OnLoadNewCutscene',
    [MessageConst.ON_LOAD_NEW_DLG_TIMELINE] = '_OnLoadNewDialogTimeline',
}

BigLogoCtrl.m_timelineHandle = HL.Field(HL.Userdata)

BigLogoCtrl.m_onCanvasChangedClosure = HL.Field(HL.Function)

BigLogoCtrl.m_fitTopViewportAspectRatio = HL.Field(HL.Number) << 0
BigLogoCtrl.m_fitBottomViewportAspectRatio = HL.Field(HL.Number) << 0
BigLogoCtrl.m_fitTopUsePCCoordinates = HL.Field(HL.Boolean) << false
BigLogoCtrl.m_fitBottomUsePCCoordinates = HL.Field(HL.Boolean) << false
BigLogoCtrl.m_fitTopOriginalScale = HL.Field(Vector3) << function()
    return Vector3.one
end
BigLogoCtrl.m_fitBottomOriginalScale = HL.Field(Vector3) << function()
    return Vector3.one
end



BigLogoCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_timelineHandle = unpack(args)
end

BigLogoCtrl.OnClose = HL.Override() << function(self)
    if self.m_onCanvasChangedClosure then
        UIManager.m_uiCanvasScaleHelper.onCanvasChanged:RemoveListener(self.m_onCanvasChangedClosure)
        self.m_onCanvasChangedClosure = nil
    end
end




BigLogoCtrl._OnShowBigLogo = HL.Method(HL.Table) << function(self, args)
    local playParam = unpack(args)
    local sprite = playParam.sprite
    local useStretchImage = playParam.useStretchImage
    local showOnTop = playParam.showOnTop
    local hideBackground = playParam.hideBackground
    local useOriginalImage = playParam.useOriginalImage
    local useFitImage = playParam.useFitImage
    local fitViewportAspectRatio = playParam.fitViewportAspectRatio or 0
    local usePCFitImageCoordinates = playParam.usePCFitImageCoordinates

    self.view.bg.gameObject:SetActive(not hideBackground)

    if playParam.useStyle then
        local styleNode = self.view.bigLogoPanel:GetStyleNode(playParam.styleId)
        if styleNode ~= nil then
            if NotNull(styleNode.originImage) then
                styleNode.originImage.sprite = playParam.styleOriginSprite
            end
            if NotNull(styleNode.styleImage) then
                styleNode.styleImage.sprite = playParam.styleSprite
            end
        end
        self.view.styleImg.sprite = sprite
    elseif useOriginalImage then
        self.view.originImageNode.sprite = sprite
    elseif useStretchImage then
        local imageAspectRatio = sprite.rect.width / sprite.rect.height
        if showOnTop then
            if math.abs(self.view.stretchImageTopAspectRatioFitter.aspectRatio - imageAspectRatio) > 0.01 then
                self.view.stretchImageTopAspectRatioFitter.aspectRatio = imageAspectRatio
            end
            self.view.stretchImageTop.sprite = sprite
        else
            if math.abs(self.view.stretchImageBottomAspectRatioFitter.aspectRatio - imageAspectRatio) > 0.01 then
                self.view.stretchImageBottomAspectRatioFitter.aspectRatio = imageAspectRatio
            end
            self.view.stretchImageBottom.sprite = sprite
        end
    elseif useFitImage then
        if showOnTop then
            self.view.fitImageTop.sprite = sprite
            self.view.fitImageTop.transform.anchoredPosition = Vector2.zero
            self.m_fitTopViewportAspectRatio = fitViewportAspectRatio
            self.m_fitTopOriginalScale = self:_UpdateFitImageCoordinateMode(self.view.fitNodeTop.transform,
                usePCFitImageCoordinates, self.m_fitTopUsePCCoordinates, self.m_fitTopOriginalScale)
            self.m_fitTopUsePCCoordinates = usePCFitImageCoordinates
        else
            self.view.fitImageBottom.sprite = sprite
            self.view.fitImageBottom.transform.anchoredPosition = Vector2.zero
            self.m_fitBottomViewportAspectRatio = fitViewportAspectRatio
            self.m_fitBottomOriginalScale = self:_UpdateFitImageCoordinateMode(self.view.fitNodeBottom.transform,
                usePCFitImageCoordinates, self.m_fitBottomUsePCCoordinates, self.m_fitBottomOriginalScale)
            self.m_fitBottomUsePCCoordinates = usePCFitImageCoordinates
        end

        self:_RefreshFitImageSize()

        if self.m_onCanvasChangedClosure == nil then
            self.m_onCanvasChangedClosure = function() self:_RefreshFitImageSize() end
            UIManager.m_uiCanvasScaleHelper.onCanvasChanged:AddListener(self.m_onCanvasChangedClosure)
        end
    else
        self.view.nameImg.sprite = sprite
    end
end

BigLogoCtrl._RefreshFitImageSize = HL.Method() << function(self)
    local screenWidth = self.view.fitImageMain.transform.rect.width
    local screenHeight = self.view.fitImageMain.transform.rect.height
    self:_RefreshFitImageLayer(self.view.fitImageTop, self.view.fitNodeTop.transform,
        self.m_fitTopViewportAspectRatio, self.m_fitTopUsePCCoordinates, screenWidth, screenHeight)
    self:_RefreshFitImageLayer(self.view.fitImageBottom, self.view.fitNodeBottom.transform,
        self.m_fitBottomViewportAspectRatio, self.m_fitBottomUsePCCoordinates, screenWidth, screenHeight)
end

BigLogoCtrl._UpdateFitImageCoordinateMode = HL.Method(CS.UnityEngine.RectTransform, HL.Boolean, HL.Boolean, Vector3)
    .Return(Vector3) << function(self, fitNode, usePCCoordinates, usedPCCoordinates, originalScale)
    if usePCCoordinates == usedPCCoordinates then
        return originalScale
    end
    if usePCCoordinates then
        return fitNode.localScale
    end
    fitNode.localScale = originalScale
    return originalScale
end

BigLogoCtrl._RefreshFitImageLayer = HL.Method(CS.Beyond.UI.UIImage, CS.UnityEngine.RectTransform,
    HL.Number, HL.Boolean, HL.Number, HL.Number) << function(self, image, fitNode, viewportAspectRatio,
    usePCFitImageCoordinates, screenWidth, screenHeight)
    local sprite = image.sprite
    if not NotNull(sprite) then
        return
    end

    local w = sprite.rect.width
    local h = sprite.rect.height
    local viewportWidth = viewportAspectRatio > 0 and viewportAspectRatio or w
    local viewportHeight = viewportAspectRatio > 0 and 1 or h

    local offsetMin, offsetMax = NarrativeUtils.GetFitImageOffset(screenWidth, screenHeight,
        viewportWidth, viewportHeight)
    fitNode.offsetMin = offsetMin
    fitNode.offsetMax = offsetMax

    local fittedWidth = screenWidth + offsetMax.x - offsetMin.x
    local fittedHeight = screenHeight + offsetMax.y - offsetMin.y
    if usePCFitImageCoordinates and screenWidth > 0 and screenHeight > 0 then
        
        local uiConst = CS.Beyond.UI.UIConst
        local fitScale = math.min(
            screenWidth / (uiConst.STANDARD_HORIZONTAL_RESOLUTION * uiConst.PC_REFERENCE_RESOLUTION_SCALE),
            screenHeight / (uiConst.STANDARD_VERTICAL_RESOLUTION * uiConst.PC_REFERENCE_RESOLUTION_SCALE))
        fittedWidth = fittedWidth / fitScale
        fittedHeight = fittedHeight / fitScale
        fitNode.sizeDelta = Vector2(fittedWidth - screenWidth, fittedHeight - screenHeight)
        fitNode.localScale = Vector3(fitScale, fitScale, 1)
    end
    local imageHeight = fittedWidth * h / w
    image.transform.sizeDelta = Vector2(0, imageHeight - fittedHeight)
end

BigLogoCtrl._OnLoadNewCutscene = HL.Method(HL.Any) << function(self, args)
    self.view.bigLogoMain.gameObject:SetActive(false)
    self.view.stretchImageMain.gameObject:SetActive(false)
    self.view.bigLogoPanel:ClearStyleNodes()

    local cinematicMgr = GameWorld.cutsceneManager
    cinematicMgr:BindBigLogo(self.m_timelineHandle, self.view.bigLogoPanel)
end

BigLogoCtrl._OnLoadNewDialogTimeline = HL.Method(HL.Any) << function(self, args)
    self.view.bigLogoMain.gameObject:SetActive(false)
    self.view.stretchImageMain.gameObject:SetActive(false)
    self.view.bigLogoPanel:ClearStyleNodes()

    local dialogTimelineManager = GameWorld.dialogTimelineManager
    dialogTimelineManager:BindBigLogo(self.m_timelineHandle, self.view.bigLogoPanel)
end



HL.Commit(BigLogoCtrl)
