
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailTyphoeaArchery

MapMarkDetailTyphoeaArcheryCtrl = HL.Class('MapMarkDetailTyphoeaArcheryCtrl', uiCtrl.UICtrl)






MapMarkDetailTyphoeaArcheryCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


MapMarkDetailTyphoeaArcheryCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.mapMarkDetailCommon.gameObject:SetActive(true)
    local markInstId = arg.markInstId

    local commonArgs = {}
    commonArgs.markInstId = markInstId
    commonArgs.leftBtnActive = false
    commonArgs.rightBtnActive = false
    commonArgs.bigBtnActive = true
    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon(commonArgs)

    local typhoeaArcherySystem = GameInstance.player.typhoeaArcherySystem
    local archeryData = typhoeaArcherySystem.archeryData
    local curLevel = archeryData.lv
    local maxLevel = archeryData.maxLv

    
    if curLevel == 0 then
        self.view.mapMarkDetailCommon.view.lvStateNode.gameObject:SetActive(false)
    else
        self.view.mapMarkDetailCommon.view.lvStateNode.gameObject:SetActive(true)
        self.view.mapMarkDetailCommon.view.lvStateNode:SetState(curLevel==maxLevel and "Max" or "Nrl")
        self.view.mapMarkDetailCommon.view.lvNumTxt.text = curLevel
    end

    
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
end


HL.Commit(MapMarkDetailTyphoeaArcheryCtrl)
