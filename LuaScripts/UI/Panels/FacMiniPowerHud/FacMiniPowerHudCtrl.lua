
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacMiniPowerHud















FacMiniPowerHudCtrl = HL.Class('FacMiniPowerHudCtrl', uiCtrl.UICtrl)






FacMiniPowerHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_EXIT_FACTORY_MODE] = 'OnExitFactoryMode',
    [MessageConst.ON_EXIT_BUILDING_MODE] = 'OnExitBuildingMode',
    [MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE] = 'OnInFacMainRegionChange',
    [MessageConst.ON_FAC_BUILDING_PREVIEW_POSITION_ROTATION_CHANGED] = 'OnFacBuildingPreviewPositionRotationChanged',
    [MessageConst.ON_FAC_CHAPTER_RESET] = 'OnFacChapterReset',
}


FacMiniPowerHudCtrl.m_miniPowerContent = HL.Field(HL.Userdata)





FacMiniPowerHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_miniPowerContent = self.view.defaultNode.facMiniPowerContent
    self.m_miniPowerContent:InitFacMiniPowerContent()
    self.m_miniPowerContent.isMonitorPower = true
    self.m_miniPowerContent.gameObject:SetActive(false)

    UIManager:SetTopOrder(PanelId.MainHud) 
end



FacMiniPowerHudCtrl.OnShow = HL.Override() << function(self)
    self.m_miniPowerContent:ToggleCoroutine(true)
end



FacMiniPowerHudCtrl.OnHide = HL.Override() << function(self)
    self.m_miniPowerContent:ToggleCoroutine(false)
end


FacMiniPowerHudCtrl.OnEnterFactoryMode = HL.StaticMethod() << function()
    if FactoryUtils.isInBuildMode() then
        
        return
    end
    local self = UIManager:AutoOpen(PANEL_ID)
    if self.view.defaultNode.animationWrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
        
        self.view.defaultNode.animationWrapper:SampleToOutAnimationEnd()
        if not self:IsShow() then
            self:Show()
        end
    end
    self.view.defaultNode.animationWrapper:PlayInAnimation()
    self:_OnBuildModeChange("")
end



FacMiniPowerHudCtrl.OnExitFactoryMode = HL.Method() << function(self)
    if FactoryUtils.isInBuildMode() then
        return
    end
    self.view.defaultNode.animationWrapper:PlayOutAnimation(function()
        self:Hide()
    end)
end



FacMiniPowerHudCtrl.OnEnterBuildingMode = HL.StaticMethod(HL.String) << function(itemId)
    local self = UIManager:AutoOpen(PANEL_ID)
    self.view.defaultNode.animationWrapper:SampleToInAnimationEnd()
    self.view.defaultNode.animationWrapper:PlayWithTween("fac_mini_bar_enter_fac_mode_change")
    self:_OnBuildModeChange(itemId)
end



FacMiniPowerHudCtrl.OnExitBuildingMode = HL.Method() << function(self)
    if Utils.isInFactoryMode() and self:IsShow() then
        self.view.defaultNode.animationWrapper:SampleToInAnimationEnd()
        self:_OnBuildModeChange("")
    else
        self.view.defaultNode.animationWrapper:PlayWithTween("fac_mini_bar_enter_fac_mode_changeout", function()
            self:Hide()
        end)
    end
end




FacMiniPowerHudCtrl.OnInFacMainRegionChange = HL.Method(HL.Boolean) << function(self, _)
    if not string.isEmpty(self.m_curBuildBuildingItemId) then
        self:_OnBuildModeChange(self.m_curBuildBuildingItemId)
    end
end


FacMiniPowerHudCtrl.m_curBuildBuildingItemId = HL.Field(HL.String) << ''




FacMiniPowerHudCtrl._OnBuildModeChange = HL.Method(HL.String) << function(self, buildingItemId)
    self.m_curBuildBuildingItemId = buildingItemId
    local data = FactoryUtils.getItemBuildingData(buildingItemId)
    local inBuildingMode = FactoryUtils.isInBuildMode()
    local node = self.view.defaultNode

    node.facMiniPowerContent:SwitchFacMiniPowerContent(buildingItemId)

    node.buildPreviewTxt.gameObject:SetActive(inBuildingMode)
    if not inBuildingMode then
        return
    end
    node.buildPreviewTxt.text = string.format(Language.LUA_BUILD_PREVIEW_TITLE, data.name)
end



FacMiniPowerHudCtrl.OnFacBuildingPreviewPositionRotationChanged = HL.Method() << function(self)
    local node = self.view.defaultNode
    if string.isEmpty(self.m_curBuildBuildingItemId) then
        return
    end
    node.facMiniPowerContent:SwitchFacMiniPowerContent(self.m_curBuildBuildingItemId)
end



FacMiniPowerHudCtrl.OnFacChapterReset = HL.Method() << function(self)
    local node = self.view.defaultNode
    node.facMiniPowerContent:ClearMemorizedPowerInfo()
    if string.isEmpty(self.m_curBuildBuildingItemId) then
        return
    end
    node.facMiniPowerContent:SwitchFacMiniPowerContent(self.m_curBuildBuildingItemId)
end

HL.Commit(FacMiniPowerHudCtrl)
