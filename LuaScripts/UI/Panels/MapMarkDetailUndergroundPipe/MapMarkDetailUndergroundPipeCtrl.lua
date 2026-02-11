
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailUndergroundPipe






MapMarkDetailUndergroundPipeCtrl = HL.Class('MapMarkDetailUndergroundPipeCtrl', uiCtrl.UICtrl)







MapMarkDetailUndergroundPipeCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


MapMarkDetailUndergroundPipeCtrl.m_markInstId = HL.Field(HL.String) << ""


MapMarkDetailUndergroundPipeCtrl.m_connectHandler = HL.Field(HL.Any)





MapMarkDetailUndergroundPipeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_markInstId = arg.markInstId

    local commonArgs = {}
    commonArgs.bigBtnActive = true
    commonArgs.markInstId = self.m_markInstId
    self.view.detailCommon:InitMapMarkDetailCommon(commonArgs)

    local getRuntimeDataSuccess, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(self.m_markInstId)

    if getRuntimeDataSuccess then
        local nodeHandler = FactoryUtils.getBuildingNodeHandler(markRuntimeData.nodeId)
        local component = FactoryUtils.getBuildingComponentHandlerAtPos(nodeHandler, GEnums.FCComponentPos.FluidUdPipe)
        local isLoader = FacConst.UDPIPE_PORT_LOAD_TYPE_MAP[nodeHandler.templateId]
        self.m_connectHandler = component.udPipe.connectComponent
        if self.m_connectHandler == nil then
            self.view.stateController:SetState(isLoader and "DisconnectOutlet" or "DisconnectEntrance")
        else
            local isDstAdvanced = not FacConst.UDPIPE_PORT_LAYOUT_STATE_MAP[self.m_connectHandler.belongNode.templateId]
            if isDstAdvanced then
                self.view.stateController:SetState(isLoader and "ConnectedAdvancedOutlet" or "ConnectedAdvancedEntrance")
            else
                self.view.stateController:SetState(isLoader and "ConnectedOutlet" or "ConnectedEntrance")
            end
        end

        self.view.navigationBtn.onClick:AddListener(function()
            if self.m_connectHandler == nil then
                return
            end
            local success, mapInstId = GameInstance.player.mapManager:GetFacMarkInstIdByNodeId(self.m_connectHandler.belongNode.belongChapter.chapterId, self.m_connectHandler.belongNode.nodeId)
            if success then
                MapUtils.openMap(mapInstId)
            end
        end)
    end
end

HL.Commit(MapMarkDetailUndergroundPipeCtrl)
