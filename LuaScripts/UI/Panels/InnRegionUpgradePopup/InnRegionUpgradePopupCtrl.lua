local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRegionUpgradePopup

InnRegionUpgradePopupCtrl = HL.Class('InnRegionUpgradePopupCtrl', uiCtrl.UICtrl)

InnRegionUpgradePopupCtrl.s_messages = HL.StaticField(HL.Table) << {}

InnRegionUpgradePopupCtrl.m_buildCells = HL.Field(HL.Forward('UIListCache'))


InnRegionUpgradePopupCtrl.m_onClose = HL.Field(HL.Function)

InnRegionUpgradePopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local onClose = arg and arg.onClose
    self.m_onClose = onClose

    self.view.clickBtn.onClick:AddListener(function()
        if onClose then
            onClose()
        end
        self:PlayAnimationOutAndClose()
    end)

    if arg == nil then
        return
    end

    self.view.nameTxt.text = arg.name or ""
    self.view.descTxt.text = arg.desc or ""

    local buildInfoList = arg.buildInfoList or {}
    self.m_buildCells = UIUtils.genCellCache(self.view.itemListCell)
    self.m_buildCells:Refresh(#buildInfoList, function(cell, index)
        local info = buildInfoList[index]
        cell.funcTxt.text = info.name or ""
        cell.num1Txt.text = tostring(info.oldValue or 0)
        cell.num2Txt.text = tostring(info.newValue or 0)
    end)
end

HL.Commit(InnRegionUpgradePopupCtrl)
