local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainVersionInfoPopup

local domainSystem = GameInstance.player.domainDevelopmentSystem














DomainVersionInfoPopupCtrl = HL.Class('DomainVersionInfoPopupCtrl', uiCtrl.UICtrl)







DomainVersionInfoPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



DomainVersionInfoPopupCtrl.m_info = HL.Field(HL.Table)







DomainVersionInfoPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    
    local domainId
    local gmForceShowVersion
    if type(arg) == "string" then
        domainId = arg
    else
        domainId = arg.domainId
        gmForceShowVersion = arg.gmForceShowVersion
    end
    if string.isEmpty(domainId) then
        logger.error("参数错误！domainId为空")
        return
    end
    self.m_info = DomainPOIUtils.tryGetDomainNewVersionInfo(domainId, gmForceShowVersion)
    if self.m_info == nil then
        logger.error("info为空!!")
        return
    end
    
    self:_RefreshAllUI()
end





DomainVersionInfoPopupCtrl._InitUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.baseplateCloseBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    
    local contentParent = self.view.content
    contentParent.versionLevelTitleCell.gameObject:SetActive(false)
    contentParent.versionPOITitleCell.gameObject:SetActive(false)
    contentParent.versionTextCell.gameObject:SetActive(false)
    contentParent.versionRewardListCell.gameObject:SetActive(false)
end



DomainVersionInfoPopupCtrl._RefreshAllUI = HL.Method() << function(self)
    self:_RefreshBasicUI()
    self:_RefreshVersionContentUI()
end



DomainVersionInfoPopupCtrl._RefreshBasicUI = HL.Method() << function(self)
    local info = self.m_info
    self.view.subTitleDomainIcon:LoadSprite(UIConst.UI_SPRITE_SETTLEMENT, info.domainIcon)
    self.view.subTitleTxt.text = string.format(Language.LUA_DOMAIN_VERSION_DEVELOPMENT_MAX_LEVEL_DIFF, info.domainName, info.domainCurMaxLv)
end



DomainVersionInfoPopupCtrl._RefreshVersionContentUI = HL.Method() << function(self)
    
    for _, poiVersionInfo in pairs(self.m_info.poiVersionInfoList) do
        self:_RefreshVersionPOITitleCell(poiVersionInfo)    
        for _, levelVersionInfo in pairs(poiVersionInfo.levelVersionInfoList) do
            self:_RefreshVersionLevelTitleCell(levelVersionInfo)
            self:_RefreshVersionTextCell(levelVersionInfo)
            if levelVersionInfo.rewardList then
                self:_RefreshVersionRewardListCell(levelVersionInfo)
            end
        end
    end
end





DomainVersionInfoPopupCtrl._RefreshVersionPOITitleCell = HL.Method(HL.Table) << function(self, info)
    local contentParent = self.view.content
    
    local cell = DomainVersionInfoPopupCtrl._GenCacheContent(contentParent.versionPOITitleCell.gameObject, contentParent.gameObject)
    cell.titleIcon:LoadSprite(UIConst.UI_SPRITE_DOMAIN, info.poiIcon)
    cell.titleTxt.text = info.poiName
end




DomainVersionInfoPopupCtrl._RefreshVersionLevelTitleCell = HL.Method(HL.Table) << function(self, info)
    local contentParent = self.view.content
    
    local cell = DomainVersionInfoPopupCtrl._GenCacheContent(contentParent.versionLevelTitleCell.gameObject, contentParent.gameObject)
    cell.poiNameTxt.text = info.levelPoiName
    cell.levelNameTxt.text = info.levelName
end




DomainVersionInfoPopupCtrl._RefreshVersionTextCell = HL.Method(HL.Table) << function(self, info)
    local contentParent = self.view.content
    
    local cell = DomainVersionInfoPopupCtrl._GenCacheContent(contentParent.versionTextCell.gameObject, contentParent.gameObject)
    cell.descTxt.text = string.format(Language.LUA_DOMAIN_VERSION_POI_MAX_LEVEL_DIFF, info.poiCurVersionMaxLv)
end




DomainVersionInfoPopupCtrl._RefreshVersionRewardListCell = HL.Method(HL.Table) << function(self, info)
    local contentParent = self.view.content
    
    local cell = DomainVersionInfoPopupCtrl._GenCacheContent(contentParent.versionRewardListCell.gameObject, contentParent.gameObject)
    cell.descTxt.text = Language.LUA_DOMAIN_VERSION_SHOP_NEW_TRADE_ITEM
    info.rewardCellCached = UIUtils.genCellCache(cell.rewardItemCell)
    
    info.rewardCellCached:Refresh(#info.rewardList, function(rewardCell, luaIndex)
        local itemBundle = info.rewardList[luaIndex]
        rewardCell:InitItem(itemBundle, true)
        rewardCell.view.count.gameObject:SetActive(false)
    end)
end








DomainVersionInfoPopupCtrl._GenCacheContent = HL.StaticMethod(GameObject, GameObject).Return(HL.Table) << function(templateObj, parent)
    local child = UIUtils.addChild(parent, templateObj, true)
    child.gameObject:SetActive(true)
    return Utils.wrapLuaNode(child)
end


HL.Commit(DomainVersionInfoPopupCtrl)
