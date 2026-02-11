
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SettlementSwitchRegionPopup











SettlementSwitchRegionPopupCtrl = HL.Class('SettlementSwitchRegionPopupCtrl', uiCtrl.UICtrl)


SettlementSwitchRegionPopupCtrl.m_curDomainId = HL.Field(HL.String) << ""


SettlementSwitchRegionPopupCtrl.m_curSelectDomainId = HL.Field(HL.String) << ""


SettlementSwitchRegionPopupCtrl.m_unlockedDomainIds = HL.Field(HL.Table)


SettlementSwitchRegionPopupCtrl.m_regionCells = HL.Field(HL.Forward("UIListCache"))


SettlementSwitchRegionPopupCtrl.m_curSelectIndex = HL.Field(HL.Number) << 0







SettlementSwitchRegionPopupCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


SettlementSwitchRegionPopupCtrl.m_regionRedDotName = HL.Field(HL.String) << ""




SettlementSwitchRegionPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnCancel.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.SettlementSwitchRegionPopup)
    end)

    if arg == nil or arg.curDomainId == nil or arg.unlockedDomainIds == nil then
        logger.error(ELogChannel.UI, "打开切换区域界面参数错误")
        return
    end

    self.m_curDomainId = arg.curDomainId
    self.m_curSelectDomainId = arg.curDomainId
    self.m_regionRedDotName = arg.regionRedDot or ""
    self.m_unlockedDomainIds = {}
    for i = 1, #arg.unlockedDomainIds do
        if not string.isEmpty(arg.unlockedDomainIds[i]) then
            local _, curDomainData = Tables.domainDataTable:TryGetValue(arg.unlockedDomainIds[i])
            if curDomainData then
                if curDomainData.settlementGroup.Count > 0 then
                    table.insert(self.m_unlockedDomainIds, arg.unlockedDomainIds[i])
                end
            end
        end
    end

    table.sort(self.m_unlockedDomainIds, function(a, b)
        local _, domainDataA = Tables.domainDataTable:TryGetValue(a)
        local _, domainDataB = Tables.domainDataTable:TryGetValue(b)
        return domainDataA.sortId < domainDataB.sortId
    end)

    self.view.btnConfirm.onClick:AddListener(function()
        if arg.onConfirm then
            arg.onConfirm(self.m_curSelectDomainId)
        end
        PhaseManager:PopPhase(PhaseId.SettlementSwitchRegionPopup)
    end)

    self.m_regionCells = UIUtils.genCellCache(self.view.regionTemplate)
    self:_RefreshRegionCells()
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



SettlementSwitchRegionPopupCtrl._RefreshRegionCells = HL.Method() << function(self)
    
    local domainData = Tables.domainDataTable[self.m_curSelectDomainId]
    self.view.curDomainName.text = domainData.domainName
    self.view.decoImage.spriteName = domainData.domainDeco
    self.view.colorBg.color = UIUtils.getColorByString(domainData.domainColor)

    self.m_regionCells:Refresh(#self.m_unlockedDomainIds, function(cell, index)
        local domainId = self.m_unlockedDomainIds[index]
        
        local domainData = Tables.domainDataTable[domainId]
        cell.gameObject.name = "RegionCell_" .. domainId
        cell.selectedState.gameObject:SetActiveIfNecessary(domainId == self.m_curSelectDomainId and not DeviceInfo.usingController)
        cell.currentlyViewNode.gameObject:SetActive(domainId == self.m_curDomainId)
        cell.domainName.text = domainData.domainName
        cell.domainPic.spriteName = domainData.domainPic
        cell.domainIcon.spriteName = domainData.domainIcon

        cell.button.onClick:RemoveAllListeners()
        cell.button.onClick:AddListener(function()
            if domainId ~= self.m_curSelectDomainId then
                self.m_curSelectIndex = index
                self.m_curSelectDomainId = domainId
                self:_RefreshRegionCells()
            end
            AudioManager.PostEvent(domainData.audKeySwitchRegionPopup)
        end)

        if not string.isEmpty(self.m_regionRedDotName) then
            cell.redDot.gameObject:SetActive(true)
            cell.redDot:InitRedDot(self.m_regionRedDotName, domainId)
        else
            cell.redDot.gameObject:SetActive(false)
        end
        if domainId == self.m_curSelectDomainId then
            self.m_curSelectIndex = index
        end
    end)
end



SettlementSwitchRegionPopupCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local firstCell = self.m_regionCells:Get(self.m_curSelectIndex)
    if firstCell then
        InputManagerInst.controllerNaviManager:SetTarget(firstCell.button)
    end
end

HL.Commit(SettlementSwitchRegionPopupCtrl)
