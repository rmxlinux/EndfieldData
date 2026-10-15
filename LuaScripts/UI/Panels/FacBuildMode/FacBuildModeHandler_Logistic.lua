




local buildingHandler = require_ex('UI/Panels/FacBuildMode/FacBuildModeHandler_Building')

local KeyHints = {
    logistic = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_cancel_alter",
    },
    logisticInTopView = {
        "fac_rotate_device",
        "fac_build_confirm",
        "fac_build_continuous_confirm",
        "fac_build_cancel_alter",
    },
}


FacBuildModeHandler_Logistic = HL.Class('FacBuildModeHandler_Logistic', buildingHandler.FacBuildModeHandler_Building)

FacBuildModeHandler_Logistic.FacBuildModeHandler_Logistic = HL.Constructor(HL.Forward('FacBuildModeCtrl')) << function(self, host)
    FacBuildModeHandler_Logistic.SuperConstructor(self, host)
end

FacBuildModeHandler_Logistic.OnEnter = HL.Override(HL.Table) << function(self, args)
    
    self.m_args = args
    local host = self.m_host
    local provider = self.m_provider

    local itemId = args.itemId
    local itemData = Tables.itemTable[itemId]
    local logisticId = Tables.factoryItem2LogisticIdTable[itemId].logisticId

    local initWorldPos
    do
        local pointerPos
        if args.initMousePos then
            pointerPos = Vector3(args.initMousePos.x, args.initMousePos.y, 0)
        else
            pointerPos = host:_InDragMode() and Vector3(Screen.width / 2, Screen.height / 2, 0) or host:_GetCurPointerPressPos()
        end
        local camRay = CameraManager.mainCamera:ScreenPointToRay(pointerPos)
        local _, worldPos = provider:SampleGroundPoint(camRay)
        initWorldPos = worldPos
    end

    
    provider:BeginPlace(logisticId, initWorldPos, (args.initDir or 0) * 90, true)
    local mode = GameInstance.remoteFactoryManager.interact.buildingMode
    mode.onPlaceBuilding = mode.onPlaceBuilding - host.m_onPlaceFinish
    mode.onPlaceBuilding = mode.onPlaceBuilding + host.m_onPlaceFinish

    host.m_buildingNodeId = nil
    host.m_buildingId = logisticId
    host.m_itemData = itemData

    local keyHint = LuaSystemManager.factory.inTopView and KeyHints.logisticInTopView or KeyHints.logistic
    if not self:CanRotate() then
        
        local tmp = {}
        for _, v in ipairs(keyHint) do
            if v ~= "fac_rotate_device" then
                table.insert(tmp, v)
            end
        end
        keyHint = tmp
    end
    host:_RefreshKeyHint(keyHint)

    local logisticData = FactoryUtils.getLogisticData(logisticId)
    host:_SetCamState(logisticData.buildCamState)
end

FacBuildModeHandler_Logistic.OnPostEnter = HL.Override() << function(self)
    
end

FacBuildModeHandler_Logistic.GetEnterMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_ENTER_LOGISTIC_MODE
end

FacBuildModeHandler_Logistic.GetExitMessage = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    return MessageConst.ON_EXIT_LOGISTIC_MODE
end

FacBuildModeHandler_Logistic.OnConfirm = HL.Override() << function(self)
    if not self:_ConfirmCommon() then
        return
    end
    if not self.m_host:_EnableContinueBuild() then
        self:_ExitSelf()
    end
end

FacBuildModeHandler_Logistic.CanRotate = HL.Override().Return(HL.Boolean) << function(self)
    if FacConst.FAC_VALVE_NODE_IDS[self.m_host.m_buildingId] then
        return false
    end
    return true
end

FacBuildModeHandler_Logistic.CanStayOutOfMainRegion = HL.Override().Return(HL.Boolean) << function(self)
    local logisticData, isLiquid = FactoryUtils.getLogisticData(self.m_host.m_buildingId)
    return isLiquid == true
end


HL.Commit(FacBuildModeHandler_Logistic)
