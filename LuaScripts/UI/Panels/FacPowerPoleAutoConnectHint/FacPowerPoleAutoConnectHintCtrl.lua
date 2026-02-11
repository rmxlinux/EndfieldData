
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacPowerPoleAutoConnectHint

FacPowerPoleAutoConnectHintCtrl = HL.Class('FacPowerPoleAutoConnectHintCtrl', uiCtrl.UICtrl)


FacPowerPoleAutoConnectHintCtrl.m_trackerPool = HL.Field(HL.Table)

FacPowerPoleAutoConnectHintCtrl.m_inBuildingMode = HL.Field(HL.Boolean) << false






FacPowerPoleAutoConnectHintCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


FacPowerPoleAutoConnectHintCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_trackerPool = {}
    self.view.tracker.gameObject:SetActive(false)
end

FacPowerPoleAutoConnectHintCtrl.OnEnterBuildingMode = HL.StaticMethod(HL.Opt(HL.Any)) << function()
    local ctrl = FacPowerPoleAutoConnectHintCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl.m_inBuildingMode = true
end


FacPowerPoleAutoConnectHintCtrl.OnExitBuildingMode = HL.StaticMethod() << function()
    local ctrl = FacPowerPoleAutoConnectHintCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl.m_inBuildingMode = false
    ctrl:ClearAllHints()
end


FacPowerPoleAutoConnectHintCtrl.OnBuild = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = FacPowerPoleAutoConnectHintCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:OnBuildModeUpdated(args.buildingTypeId, args.position)
end


FacPowerPoleAutoConnectHintCtrl.OnMove = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = FacPowerPoleAutoConnectHintCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:OnMoveModeUpdated(args.buildingTypeId, args.position, args.nodeId)
end



FacPowerPoleAutoConnectHintCtrl._UpdateTrackers = HL.Method() << function(self)
    local buildingMode = GameInstance.remoteFactoryManager.interact.currentBuildingMode
    if not buildingMode then
        return
    end
    local infos = buildingMode.autoConnectCandidateList
    if not infos then
        return
    end
    for i = 0, infos.Count - 1 do
        local info = infos[i]
        local screenPos, isInside = UIUtils.objectPosToUI(info.Item3, self.uiCamera)
        local uiPos, uiAngle, isOutBound = UIUtils.mapScreenPosToEllipseEdge(screenPos, self.view.config.ELLIPSE_X_RADIUS, self.view.config.ELLIPSE_Y_RADIUS)
        local trackKey = i + 1
        if not self.m_trackerPool[trackKey] then
            self.m_trackerPool[trackKey] = self:_CreateNewTracker()
        end
        local item = self.m_trackerPool[trackKey]
        item.obj:SetActive(true)
        item.tracker:UpdatePosition(uiPos, uiAngle, isOutBound)
        item.tracker:UpdateDistance(info.Item4)
        item.tracker:UpdateNodeType(info.Item1.nodeType)
        item.tracker:UpdateStatus(info.Item5)
    end
    for i = infos.Count + 1, #self.m_trackerPool do
        self.m_trackerPool[i].obj:SetActive(false)
    end
end





FacPowerPoleAutoConnectHintCtrl.OnBuildModeUpdated = HL.Method(HL.String, Vector3) << function(self, buildingTypeId, position)
    if not self.m_inBuildingMode then
        return
    end
    self:_UpdateTrackers()
end






FacPowerPoleAutoConnectHintCtrl.OnMoveModeUpdated = HL.Method(HL.String, Vector3, HL.Any) << function(self, buildingTypeId, position, nodeId)
    if not self.m_inBuildingMode then
        return
    end
    self:_UpdateTrackers()
end


FacPowerPoleAutoConnectHintCtrl.ClearAllHints = HL.Method() << function(self)
    for i, v in ipairs(self.m_trackerPool) do
        v.obj:SetActive(false)
    end
end


FacPowerPoleAutoConnectHintCtrl._CreateNewTracker = HL.Method().Return(HL.Table) << function(self)
    local obj = CSUtils.CreateObject(self.view.tracker.gameObject, self.view.main.transform)
    obj:SetActive(true)
    local item = {}
    item.obj = obj
    item.tracker = obj:GetComponent(typeof(CS.Beyond.UI.UIPowerPoleAutoConnectTracker))
    return item
end

HL.Commit(FacPowerPoleAutoConnectHintCtrl)