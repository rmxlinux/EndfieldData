local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DomainDepotInstList








DomainDepotInstListCtrl = HL.Class('DomainDepotInstListCtrl', uiCtrl.UICtrl)






DomainDepotInstListCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


DomainDepotInstListCtrl.m_instCellGetFunc = HL.Field(HL.Function)


DomainDepotInstListCtrl.m_instIdList = HL.Field(HL.Table)





DomainDepotInstListCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_instCellGetFunc = UIUtils.genCachedCellFunction(self.view.instList)

    self.view.instList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateInstCell(self.m_instCellGetFunc(obj), LuaIndex(csIndex))
    end)

    self.view.domainMoneyDeco:LoadSprite(UIConst.UI_SPRITE_DOMAIN_DEPOT_BG_MONEY_ICON, Tables.domainDataTable[arg.domainId].domainGoldItemId)

    self.view.depotLimitNumTxt.text = tostring(Utils.getDepotItemStackLimitCount(arg.domainId))

    local domainDepotSystem = GameInstance.player.domainDepotSystem
    local allDepotIdList = domainDepotSystem:GetDomainDepotIdListByDomainId(arg.domainId)
    local depotIdDataList = {}
    for index = 0, allDepotIdList.Count - 1 do
        local depotId = allDepotIdList[index]
        local runtimeData = domainDepotSystem:GetDomainDepotDataById(depotId)
        if runtimeData.level > 0 then  
            local tableConfig = Tables.domainDepotTable[depotId]
            table.insert(depotIdDataList, {
                depotId = depotId,
                sortId = tableConfig.sortId,
            })
        end
    end
    table.sort(depotIdDataList, Utils.genSortFunction({ "sortId" }, true))

    self.m_instIdList = {}
    for _, idData in ipairs(depotIdDataList) do
        table.insert(self.m_instIdList, idData.depotId)
    end

    self.view.instList:UpdateCount(#self.m_instIdList, true)
end



DomainDepotInstListCtrl.OnShow = HL.Override() << function(self)
    local firstCell = self.m_instCellGetFunc(1)
    UIUtils.setAsNaviTargetInSilentModeIfNecessary(self.view.selectableNaviGroup, firstCell.view.confirmBtn)
end





DomainDepotInstListCtrl._OnUpdateInstCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    cell:InitDomainDepotInstCell(self.m_instIdList[index])

    if index == 1 then
        UIUtils.setAsNaviTarget(cell.view.confirmBtn)
    end
end

HL.Commit(DomainDepotInstListCtrl)
