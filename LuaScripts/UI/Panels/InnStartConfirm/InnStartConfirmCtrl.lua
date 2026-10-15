local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnStartConfirm

InnStartConfirmCtrl = HL.Class('InnStartConfirmCtrl', uiCtrl.UICtrl)

InnStartConfirmCtrl.m_items = HL.Field(HL.Table) << function() return {} end
InnStartConfirmCtrl.m_getCell = HL.Field(HL.Function)







InnStartConfirmCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}












InnStartConfirmCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.detailsTxt:SetAndResolveTextStyle(arg.titleTxt)
    self.view.confirmButton.onClick:AddListener(function()
        self:PlayAnimationOutWithCallback(function()
            self:Close()
            arg.onConfirm()
        end)
    end)
    self.view.cancelButton.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)

    self.m_getCell = UIUtils.genCachedCellFunction(self.view.scrollList)
    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCell(obj), LuaIndex(csIndex))
    end)

    self:_RefreshScrollList(arg.items)
end


InnStartConfirmCtrl._RefreshScrollList = HL.Method(HL.Opt(HL.Table)) << function(self, items)
    self.m_items = items or {}
    self.view.scrollList:UpdateCount(#self.m_items)
end

InnStartConfirmCtrl._OnUpdateCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    local item = self.m_items[index]
    if not item then
        return
    end

    cell.itemBlack:InitItem({ id = item.id }, true)
    cell.itemBlack:SetExtraInfo({
        isSideTips = true,
        onBeforeJump = function()
            self:Close()
        end,
    })
    cell.numTxt.text = UIUtils.setCountColorByCustomColor(tostring(item.count), item.count == 0, "FF455B")
    cell.makeTxt.text = item.isDrink and Language.LUA_INN_START_CONFIRM_STOCK
        or Language.LUA_INN_START_CONFIRM_CRAFTABLE
end











HL.Commit(InnStartConfirmCtrl)
