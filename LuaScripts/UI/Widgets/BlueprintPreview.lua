local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local LuaNodeCache = require_ex('Common/Utils/LuaNodeCache')
local CommonCache = require_ex('Common/Utils/CommonCache')

















































BlueprintPreview = HL.Class('BlueprintPreview', UIWidgetBase)


local uiSizePerUnit = 128



BlueprintPreview.m_csBP = HL.Field(CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprint)


BlueprintPreview.m_nodeCellCache = HL.Field(LuaNodeCache) 


BlueprintPreview.m_conveyorCellCache = HL.Field(LuaNodeCache) 


BlueprintPreview.m_showingCellDic = HL.Field(HL.Table) 


BlueprintPreview.m_previewHelper = HL.Field(CS.Beyond.UI.BlueprintPreviewHelper)


BlueprintPreview.m_canEdit = HL.Field(HL.Boolean) << false


BlueprintPreview.m_updateId = HL.Field(HL.Number) << -1


BlueprintPreview.m_nextTargetId = HL.Field(HL.Number) << 1


BlueprintPreview.m_id2Cell = HL.Field(HL.Table)


BlueprintPreview.m_bpAbnormalIconHelper = HL.Field(HL.Table)


BlueprintPreview.mouseShow = HL.Field(HL.Boolean) << true











local NodeType = {
    Building = 1,
    Logistic = 2,
    Belt = 3,
    Pipe = 4,
}
local Face2Vector2 = {
    [0] = Vector2(0, 1),
    [1] = Vector2(1, 0),
    [2] = Vector2(0, -1),
    [3] = Vector2(-1, 0),
}
local Face2RotZForConveyor = {
    [0] = 90,
    [1] = 0,
    [2] = -90,
    [3] = 180,
}
local Face2RotZForBuilding = {
    [0] = 360,
    [1] = 270,
    [2] = 180,
    [3] = 90,
}





BlueprintPreview._OnFirstTimeInit = HL.Override() << function(self)
    self.m_nodeCellCache = LuaNodeCache(self.view.nodeCell, self.view.content)
    self.m_conveyorCellCache = LuaNodeCache(self.view.conveyorCell, self.view.content)
    self.m_previewHelper = CS.Beyond.UI.BlueprintPreviewHelper()
    self.view.maskBtn.onClick:AddListener(function()
        self:_OnClick()
    end)
    self:_InitChangeIconNode()

    
    local secondCellObj = CSUtils.CreateObject(self.view.hoverTipsCell.gameObject, self.view.hoverTipsNode)
    secondCellObj.name = "HoverTipsCell2"
    secondCellObj.transform:SetAsLastSibling()
    self.view.hoverTipsCell2 = Utils.wrapLuaNode(secondCellObj)
end


BlueprintPreview.m_widthScale = HL.Field(HL.Number) << 1


BlueprintPreview.m_heightScale = HL.Field(HL.Number) << 1






BlueprintPreview.InitBlueprintPreview = HL.Method(CS.Beyond.Gameplay.RemoteFactory.RemoteFactoryBlueprint, HL.Boolean, HL.Opt(HL.Table)) << function(self, csBP, canEdit, bpAbnormalIconHelper)
    self:_FirstTimeInit()

    self:_HideChangeIconNode(true)
    if self.m_showingCellDic then
        for cell, info in pairs(self.m_showingCellDic) do
            if info.type == NodeType.Building or info.type == NodeType.Logistic then
                self.m_nodeCellCache:Cache(cell)
            elseif info.type == NodeType.Belt or info.type == NodeType.Pipe then
                self.m_conveyorCellCache:Cache(cell)
            end
        end
    end

    self.m_csBP = csBP
    self.m_showingCellDic = {}
    self.m_changedIcons = {}
    self.m_canEdit = canEdit
    self.m_bpAbnormalIconHelper = bpAbnormalIconHelper
    self:_CancelHover()

    
    local range = self.m_csBP.sourceRect
    local bpUISize = Vector2(range.width, range.height) * uiSizePerUnit
    self.view.content.transform.sizeDelta = bpUISize
    local viewSize = self.view.scrollRect.transform.rect.size - Vector2(100, 100) 
    local widthRatio = viewSize.x / bpUISize.x
    local heightRatio = viewSize.y / bpUISize.y
    local scaleValue = math.min(widthRatio, heightRatio, 1)
    scaleValue = math.max(scaleValue, self.view.config.MIN_SCALE)

    self.m_widthScale = scaleValue/widthRatio - 1
    self.m_heightScale = scaleValue/heightRatio - 1

    self.view.content.transform.localScale = Vector3(scaleValue, scaleValue, 1)

    
    local curMaxShowingCount = self.view.scrollRect.transform.rect.size / (uiSizePerUnit * scaleValue)
    local bgWidth, bgHeight
    if curMaxShowingCount.x > range.width then
        bgWidth = math.ceil(curMaxShowingCount.x)
        
        bgWidth = bgWidth + (bgWidth + range.width) % 2
    else
        bgWidth = range.width + 2
    end
    if curMaxShowingCount.y > range.height then
        bgHeight = math.ceil(curMaxShowingCount.y)
        
        bgHeight = bgHeight + (bgHeight + range.height) % 2
    else
        bgHeight = range.height + 2
    end
    self.view.gridImg.transform.sizeDelta = Vector2(bgWidth, bgHeight) * uiSizePerUnit
    self.view.gridImg.transform:SetAsFirstSibling()

    self.m_previewHelper:SetSize(range.width, range.height)
    self.m_nextTargetId = 1
    self.m_id2Cell = {}

    
    for _, entry in pairs(self.m_csBP.buildingNodes) do
        self:_GenPreviewBuilding(entry)
    end

    
    for _, entry in pairs(self.m_csBP.conveyorNodes) do
        self:_GenPreviewConveyor(entry)
    end

    self.view.hoverHint.transform:SetAsLastSibling()
    if DeviceInfo.usingController then
        self.view.controllerMouse.gameObject:SetActive(true)
    else
        self.view.controllerMouse.gameObject:SetActive(false)
    end

    if DeviceInfo.usingController then
        InputManagerInst:SetCustomControllerMouse(self.view.controllerMouse.transform, self:GetUICtrl().uiCamera)
        self.view.changeIconNode.selectableNaviGroup.onIsFocusedChange:AddListener(function(isTarget)
            if not isTarget then
                self:_HideChangeIconNode()
            end
        end)
        self.view.controllerMouse.anchoredPosition = Vector2(self.view.scrollRectRectTransform.rect.size.x * 1/2, self.view.scrollRectRectTransform.rect.size.y * 1/2)
    end
end







BlueprintPreview._GenPreviewBuilding = HL.Method(CS.Beyond.Gameplay.RemoteFactory.BlueprintBuildingEntry) << function(self, entry)
    local cell = self.m_nodeCellCache:Get()
    local info = {
        id = self:_GetNextTargetId(),
        entry = entry,
    }
    self.m_showingCellDic[cell] = info
    self.m_id2Cell[info.id] = cell

    local templateId = entry.templateId
    local isBuilding, bData = Tables.factoryBuildingTable:TryGetValue(templateId)
    info.type = isBuilding and NodeType.Building or NodeType.Logistic

    if self.m_canEdit then
        local _, iconData = Tables.factoryBlueprintMachineIconTable:TryGetValue(templateId)
        if iconData then
            info.canChangeIcon = iconData.canModify
        else
            info.canChangeIcon = false
        end
    else
        info.canChangeIcon = false
    end
    cell.selectedNode.gameObject:SetActive(false)

    local spatial = entry.spatial
    local gridSize = Vector2(isBuilding and bData.range.width or 1, isBuilding and bData.range.depth or 1)
    local swapSize = spatial.face == 1 or spatial.face == 3
    local swappedGridSize = swapSize and Vector2(gridSize.y, gridSize.x) or gridSize
    local nodeUISize = gridSize * uiSizePerUnit
    cell.transform.sizeDelta = swappedGridSize * uiSizePerUnit 
    local pos = entry.worldSpatial.worldPosition
    cell.transform.anchoredPosition = Vector2(pos.x, pos.z) * uiSizePerUnit
    cell.bg.transform.sizeDelta = nodeUISize
    cell.bg.transform.localEulerAngles = Vector3(0, 0, Face2RotZForBuilding[spatial.face]) 

    local minX = lume.round(pos.x - swappedGridSize.x / 2)
    local minY = lume.round(pos.z - swappedGridSize.y / 2)
    self.m_previewHelper:BatchAddGridValue(minX, minY, swappedGridSize.x, swappedGridSize.y, info.id)

    local bgPath, isDefaultBuilding
    if isBuilding then
        local spBGInfo = FacConst.BLUEPRINT_PREVIEW_SP_BUILDING_BG[bData.type]
        isDefaultBuilding = spBGInfo == nil
        bgPath = spBGInfo and spBGInfo[1] or FacConst.BLUEPRINT_PREVIEW_BUILDING_DEFAULT_BG
    else
        bgPath = string.format(FacConst.BLUEPRINT_PREVIEW_LOGISTIC_BG, templateId)
    end
    cell.bg:LoadSpriteWithOutFormat(bgPath)

    self:_PrepareCellImgCache(cell)

    if isDefaultBuilding then
        self:_GenDefaultBuildingBG(entry, cell, bData)
    else
        cell.waistDeco.gameObject:SetActive(false)
        cell.machineBG.gameObject:SetActive(false)
    end

    if not isBuilding then 
        local _, isLiquid = FactoryUtils.getLogisticData(templateId)
        if isLiquid then
            info.isHighLayer = true
        end
    end
    if not info.isHighLayer then
        
        cell.transform:SetAsFirstSibling()
    end

    self:_UpdateTargetIcon(info.id)
end








BlueprintPreview._SetEdgeImgs = HL.Method(HL.Table, HL.Table, HL.String, HL.String) << function(self, edgeImgs, info, format, formatAlter)
    local count = info.count
    if count > 0 then
        local size = info.size
        if count == size then
            edgeImgs[info.edgeFace] = string.format(format, count)
        else
            edgeImgs[info.edgeFace] = string.format(formatAlter, size, count)
        end
    end
end






BlueprintPreview._GenDefaultBuildingBG = HL.Method(CS.Beyond.Gameplay.RemoteFactory.BlueprintBuildingEntry, HL.Table, HL.Any) << function(self, entry, cell, bData)
    local isBigBuilding = bData.range.width >= 3 and bData.range.depth >= 3 and (bData.range.width * bData.range.depth >= 9)

    local edgeImgs = {}

    
    local inPorts = self:_GenDefaultBuildingPort(bData.inputPorts, true, bData.range.width, bData.range.depth)
    local outPorts = self:_GenDefaultBuildingPort(bData.outputPorts, false, bData.range.width, bData.range.depth)

    
    self:_SetEdgeImgs(edgeImgs, inPorts.belt, FacConst.BLUEPRINT_PREVIEW_BELT_PORT_IN, FacConst.BLUEPRINT_PREVIEW_BELT_PORT_IN_ALTER)
    self:_SetEdgeImgs(edgeImgs, outPorts.belt, FacConst.BLUEPRINT_PREVIEW_BELT_PORT_OUT, FacConst.BLUEPRINT_PREVIEW_BELT_PORT_OUT_ALTER)

    
    local formulaMode = entry:GetFormulaMode()
    if not formulaMode or formulaMode == FacConst.FAC_FORMULA_MODE_MAP.LIQUID then
        self:_SetEdgeImgs(edgeImgs, inPorts.pipe, FacConst.BLUEPRINT_PREVIEW_PIPE_PORT_IN, FacConst.BLUEPRINT_PREVIEW_PIPE_PORT_IN_ALTER)
        self:_SetEdgeImgs(edgeImgs, outPorts.pipe, FacConst.BLUEPRINT_PREVIEW_PIPE_PORT_OUT, FacConst.BLUEPRINT_PREVIEW_PIPE_PORT_OUT_ALTER)
    end

    local needWaist = true
    for face = 0, 3 do
        local imgPath = edgeImgs[face]
        local img
        if not imgPath then
            if face == 0 or face == 2 then
                
                img = cell.m_imgCache:Get()
                img:LoadSpriteWithOutFormat(isBigBuilding and FacConst.BLUEPRINT_PREVIEW_BUILDING_DEFAULT_EDGE_BIG or FacConst.BLUEPRINT_PREVIEW_BUILDING_DEFAULT_EDGE_SMALL)
                img.transform.sizeDelta = Vector2(bData.range.width * uiSizePerUnit, isBigBuilding and 140 or 40) 
                img.type = CS.UnityEngine.UI.Image.Type.Sliced
            end
        else
            img = cell.m_imgCache:Get()
            img:LoadSpriteWithOutFormat(imgPath)
            img:SetNativeSizeIgnoreRefScale()
            img.type = CS.UnityEngine.UI.Image.Type.Simple
        end
        if img then
            
            if face == 0 then
                img.transform.anchoredPosition = Vector2(bData.range.width / 2, bData.range.depth) * uiSizePerUnit
                img.transform.localEulerAngles = Vector3(0, 0, 0)
            elseif face == 1 then
                img.transform.anchoredPosition = Vector2(bData.range.width, bData.range.depth / 2) * uiSizePerUnit
                img.transform.localEulerAngles = Vector3(0, 0, 270)
                needWaist = false
            elseif face == 2 then
                img.transform.anchoredPosition = Vector2(bData.range.width / 2, 0) * uiSizePerUnit
                img.transform.localEulerAngles = Vector3(0, 0, 180)
            elseif face == 3 then
                img.transform.anchoredPosition = Vector2(0, bData.range.depth / 2) * uiSizePerUnit
                img.transform.localEulerAngles = Vector3(0, 0, 90)
                needWaist = false
            end
            table.insert(cell.m_showingImgs, img)
        end
    end
    cell.waistDeco.gameObject:SetActive(needWaist) 
    if isBigBuilding then
        cell.machineBG:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON_BIG, bData.iconOnPanel)
        cell.machineBG.transform.localEulerAngles = Vector3(0, 0, -cell.bg.transform.localEulerAngles.z)
        cell.machineBG.gameObject:SetActive(true)
    else
        cell.machineBG.gameObject:SetActive(false)
    end
end







BlueprintPreview._GenDefaultBuildingPort = HL.Method(HL.Any, HL.Boolean, HL.Number, HL.Number).Return(HL.Table) << function(self, portsData, isInput, width, depth)
    local ports = {
        belt = { count = 0, edgeFace = -1, minPos = math.maxinteger, maxPos = math.mininteger },
        pipe = { count = 0, edgeFace = -1, minPos = math.maxinteger, maxPos = math.mininteger },
    }
    for _, v in pairs(portsData) do
        local info = v.isPipe and ports.pipe or ports.belt
        info.count = info.count + 1
        local portPosIsOnX = (v.trans.rotation.y / 90) % 2 == 0
        local portPos = portPosIsOnX and v.trans.position.x or v.trans.position.z
        info.minPos = math.min(portPos, info.minPos)
        info.maxPos = math.max(portPos, info.maxPos)
        info.edgeFace = (v.trans.rotation.y / 90 + (isInput and 2 or 0)) % 4
    end
    for _, info in pairs(ports) do
        if info.count > 0 then
            info.size = info.maxPos - info.minPos + 1
            
            local buildingSize = info.edgeFace % 2 == 0 and width or depth
            if (buildingSize - info.size) % 2 == 1 then
                info.size = info.size + 1
            end
        end
    end
    return ports
end









BlueprintPreview._GenPreviewConveyor = HL.Method(CS.Beyond.Gameplay.RemoteFactory.BlueprintConveyorEntry) << function(self, entry)
    

    local cell = self.m_conveyorCellCache:Get()
    local info = {
        id = self:_GetNextTargetId(),
        entry = entry,
        canChangeIcon = false,
    }
    self.m_showingCellDic[cell] = info
    self.m_id2Cell[info.id] = cell

    local templateId = entry.templateId
    local isBelt = templateId == FacConst.BELT_ID
    info.type = isBelt and NodeType.Belt or NodeType.Pipe
    info.segInfos = self:_GetConveyorSegmentInfos(entry)
    info.isHighLayer = not isBelt

    if isBelt then
        
        cell.transform:SetAsFirstSibling()
    end

    local imgs = isBelt and FacConst.BLUEPRINT_PREVIEW_BELT_IMGS or FacConst.BLUEPRINT_PREVIEW_PIPE_IMGS
    self:_PrepareCellImgCache(cell)
    for k, v in ipairs(info.segInfos) do
        
        local img = cell.m_imgCache:Get()
        if UNITY_EDITOR then
            img.gameObject.name = "Seg_" .. k
        end
        table.insert(cell.m_showingImgs, img)
        if v.length then
            
            img:LoadSpriteWithOutFormat(imgs.normal)
            local centerGridPos = v.startPoint + Vector2(0.5, 0.5) + (v.length - 1) / 2 * Face2Vector2[v.startFace]
            img.transform.anchoredPosition = centerGridPos * uiSizePerUnit
            img.transform.sizeDelta = Vector2(v.length, 1) * uiSizePerUnit
            img.transform.localEulerAngles = Vector3(0, 0, Face2RotZForConveyor[v.startFace])

            local endPoint = v.startPoint + (v.length - 1) * Face2Vector2[v.startFace]
            local minX = math.min(v.startPoint.x, endPoint.x)
            local minY = math.min(v.startPoint.y, endPoint.y)
            local sizeX = math.abs(v.startPoint.x - endPoint.x) + 1
            local sizeY = math.abs(v.startPoint.y - endPoint.y) + 1
            self.m_previewHelper:BatchAddGridValue(minX, minY, sizeX, sizeY, info.id)
        else
            
            local imgInfo = FacConst.BLUEPRINT_PREVIEW_CORNER_DIC[v.startFace][v.endFace]
            img:LoadSpriteWithOutFormat(imgInfo[1] and imgs.corner1 or imgs.corner2)
            local centerGridPos = v.startPoint + Vector2(0.5, 0.5)
            img.transform.anchoredPosition = centerGridPos * uiSizePerUnit
            img.transform.sizeDelta = Vector2(uiSizePerUnit, uiSizePerUnit)
            img.transform.localEulerAngles = Vector3(0, 0, imgInfo[2])

            self.m_previewHelper:AddGridValue(v.startPoint.x, v.startPoint.y, info.id)
        end
        
    end
end




BlueprintPreview._GetConveyorSegmentInfos = HL.Method(CS.Beyond.Gameplay.RemoteFactory.BlueprintConveyorEntry).Return(HL.Table) << function(self, entry)
    
    local spatialInfo = entry.spatial
    local gridPath = spatialInfo.gridPath
    local segInfos = {}
    local curStartPoint = Vector2(gridPath.startPoint.x, gridPath.startPoint.y)
    local curStartFace = spatialInfo.startFace
    for _, vector in pairs(gridPath.segments) do
        local length = vector.length
        if vector.face ~= curStartFace then
            
            local cornerInfo = {
                startPoint = curStartPoint,
                startFace = curStartFace,
                endFace = vector.face,
            }
            curStartFace = cornerInfo.endFace
            curStartPoint = curStartPoint + Face2Vector2[cornerInfo.endFace]
            table.insert(segInfos, cornerInfo)
            length = length - 1
        end

        if length > 0 then
            
            local straightInfo = {
                startPoint = curStartPoint,
                startFace = curStartFace,
                length = length,
            }
            table.insert(segInfos, straightInfo)
            curStartPoint = curStartPoint + straightInfo.length * Face2Vector2[curStartFace]
        end
    end
    return segInfos
end







BlueprintPreview.m_iconCells = HL.Field(HL.Forward('UIListCache'))


BlueprintPreview.m_changedIcons = HL.Field(HL.Table) 


BlueprintPreview.m_curIconIndex = HL.Field(HL.Number) << -1


BlueprintPreview.m_iconInfos = HL.Field(HL.Table)


BlueprintPreview.m_curChangeIconTargetId = HL.Field(HL.Number) << -1




BlueprintPreview._InitChangeIconNode = HL.Method() << function(self)
    local node = self.view.changeIconNode
    self.m_iconCells = UIUtils.genCellCache(node.iconCell)
    node.autoCloseArea.onTriggerAutoClose:AddListener(function()
        self:_HideChangeIconNode()
    end)
end




BlueprintPreview._ShowChangeIconNode = HL.Method(HL.Number) << function(self, targetId)
    if self.m_curChangeIconTargetId == targetId then
        self:_HideChangeIconNode()
        return
    end

    local node = self.view.changeIconNode
    node.gameObject:SetActive(true)
    node.animationWrapper:ClearTween(false)
    node.animationWrapper:PlayInAnimation()

    self.m_curChangeIconTargetId = targetId

    local cell = self.m_id2Cell[targetId]
    local info = self.m_showingCellDic[cell]
    local templateId = info.entry.templateId
    local bData = Tables.factoryBuildingTable[templateId]
    node.titleTxt.text = string.format(Language.LUA_FAC_BLUEPRINT_CHANGE_MACHINE_ICON_TITLE, bData.name)

    
    local iconMap = {
        [""] = { 
            itemId = "",
            icon = bData.iconOnPanel,
            sortId1 = math.maxinteger,
        },
    }
    local _, curItemId = self:_GetTargetIconInfo(targetId)
    if not string.isEmpty(curItemId) then
        
        local itemData = Tables.itemTable[curItemId]
        iconMap[curItemId] = {
            itemId = curItemId,
            icon = itemData.iconId,
            sortId1 = itemData.sortId1,
            sortId2 = itemData.sortId2,
            rarity = itemData.rarity,
        }
    end
    local _, formulaCpt = info.entry.info:TryGetValue(GEnums.FCComponentPos.FormulaMan)
    local currentMode
    if formulaCpt and not string.isEmpty(formulaCpt.currentMode) then
        currentMode = formulaCpt.currentMode
    end
    local craftInfos = FactoryUtils.getBuildingCrafts(templateId, nil, nil, currentMode)
    for _, cInfo in ipairs(craftInfos) do
        if cInfo.outcomes then
            for _, v in ipairs(cInfo.outcomes) do
                local itemId = v.id
                if not iconMap[itemId] then
                    local itemData = Tables.itemTable[itemId]
                    iconMap[itemId] = {
                        itemId = itemId,
                        icon = itemData.iconId,
                        sortId1 = itemData.sortId1,
                        sortId2 = itemData.sortId2,
                        rarity = itemData.rarity,
                    }
                end
            end
        end
    end
    self.m_iconInfos = {}
    for _, v in pairs(iconMap) do
        table.insert(self.m_iconInfos, v)
    end
    table.sort(self.m_iconInfos, Utils.genSortFunction({ "sortId1", "sortId2", "itemId" }))

    local selectedCell = nil

    self.m_iconCells:Refresh(#self.m_iconInfos, function(iconCell, index)
        local iconInfo = self.m_iconInfos[index]
        if string.isEmpty(iconInfo.itemId) then
            
            
            iconCell.icon:InitItemIcon("item_gold")
            iconCell.icon.view.icon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON, iconInfo.icon)
            iconCell.rarityLine.gameObject:SetActive(false)
            iconCell.rarityLight.gameObject:SetActive(false)
        else
            iconCell.icon:InitItemIcon(iconInfo.itemId)
            iconCell.rarityLine.gameObject:SetActive(true)
            iconCell.rarityLight.gameObject:SetActive(true)
            local color = UIUtils.getItemRarityColor(iconInfo.rarity)
            iconCell.rarityLine.color = color
            iconCell.rarityLight.color = color
        end
        iconCell.button.onClick:RemoveAllListeners()
        iconCell.button.onClick:AddListener(function()
            self:_OnClickIcon(index)
        end)
        local isSelected = iconInfo.itemId == curItemId
        if isSelected then
            self.m_curIconIndex = index 
            selectedCell = iconCell
        end
        iconCell.stateController:SetState(isSelected and "Selected" or "Normal")
    end)
    cell.selectedNode.gameObject:SetActive(true)

    local panelCtrl = self:GetUICtrl()
    UIUtils.updateTipsPosition(self.view.changeIconNode.transform, cell.transform, panelCtrl.view.transform, panelCtrl.uiCamera,
            UIConst.UI_TIPS_POS_TYPE.RightTop, {
                top = self.view.config.CHANGE_ICON_NODE_PADDING_VER.x,
                bottom = self.view.config.CHANGE_ICON_NODE_PADDING_VER.y,
                left = self.view.config.CHANGE_ICON_NODE_PADDING_HOR.x,
                right = self.view.config.CHANGE_ICON_NODE_PADDING_HOR.y,
            })
    node.autoCloseArea.tmpSafeArea = cell.transform


    if DeviceInfo.usingController then
        node.selectableNaviGroup:ManuallyFocus()
        if selectedCell then
            self.mouseShow = false
            self.view.leftBottomNode.gameObject:SetActive(false)
            self:_CancelHover()
            UIUtils.setAsNaviTarget(selectedCell.button)
        end
    end
end





BlueprintPreview._OnClickIcon = HL.Method(HL.Number) << function(self, index)
    if index == self.m_curIconIndex then
        return
    end

    local oldCell = self.m_iconCells:Get(self.m_curIconIndex)
    oldCell.stateController:SetState("Normal")
    self.m_curIconIndex = index
    local newCell = self.m_iconCells:Get(self.m_curIconIndex)
    newCell.stateController:SetState("Selected")

    self.m_changedIcons[self.m_curChangeIconTargetId] = self.m_iconInfos[index].itemId
    self:_UpdateTargetIcon(self.m_curChangeIconTargetId)
end




BlueprintPreview._HideChangeIconNode = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipAni)
    local node = self.view.changeIconNode
    if not skipAni then
        if node.animationWrapper.curState == CS.Beyond.UI.UIConst.AnimationState.Out then
            
            return
        end
    end

    if skipAni then
        node.animationWrapper:ClearTween(false)
        node.gameObject:SetActive(false)
    else
        UIUtils.PlayAnimationAndToggleActive(node.animationWrapper, false)
    end
    self.mouseShow = true
    self.view.leftBottomNode.gameObject:SetActive(true)
    if self.m_curChangeIconTargetId > 0 then
        local cell = self.m_id2Cell[self.m_curChangeIconTargetId]
        self.m_curChangeIconTargetId = -1
        cell.selectedNode.gameObject:SetActive(false)
    end
end




BlueprintPreview._GetTargetIconInfo = HL.Method(HL.Number).Return(HL.Opt(HL.String, HL.String, HL.Number)) << function(self, targetId)
    local itemId = self.m_changedIcons[targetId]
    local cell = self.m_id2Cell[targetId]
    local info = self.m_showingCellDic[cell]
    if not itemId then
        itemId = info.entry.productIcon
    end
    if string.isEmpty(itemId) then
        
        if info.type == NodeType.Building then
            local data = Tables.factoryBuildingTable[info.entry.templateId]
            return data.iconOnPanel, ""
        end
        return 
    end
    local itemData = Tables.itemTable[itemId]
    return itemData.iconId, itemId, itemData.rarity
end




BlueprintPreview._UpdateTargetIcon = HL.Method(HL.Number) << function(self, targetId)
    local cell = self.m_id2Cell[targetId]
    local info = self.m_showingCellDic[cell]
    local icon, itemId, rarity = self:_GetTargetIconInfo(targetId)
    local node = cell.iconNode
    node.machineIcon.gameObject:SetActive(false)
    node.emptyNode.gameObject:SetActive(false)
    node.itemNode.gameObject:SetActive(false)
    if icon == nil then
        node.emptyNode.gameObject:SetActive(true)
    elseif string.isEmpty(itemId) then
        node.machineIcon.gameObject:SetActive(true)
        node.machineIcon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON, icon)
    else
        node.itemNode.gameObject:SetActive(true)
        node.itemIcon:InitItemIcon(itemId)
        local color = UIUtils.getItemRarityColor(rarity)
        node.rarityIcon.color = color
        local isAbnormal
        if Utils.isInBlackbox() then
            isAbnormal = false
        else
            isAbnormal = self.m_bpAbnormalIconHelper and self.m_bpAbnormalIconHelper.IsAbnormal(info.entry.templateId, itemId)
        end
        node.abnormalNode.gameObject:SetActive(isAbnormal)
    end
    node.changeHint.gameObject:SetActive(info.canChangeIcon)
end



BlueprintPreview.ApplyIconChanges = HL.Method() << function(self)
    for targetId, itemId in pairs(self.m_changedIcons) do
        local cell = self.m_id2Cell[targetId]
        local info = self.m_showingCellDic[cell]
        info.entry.productIcon = itemId
    end
end



BlueprintPreview.GetChangedIcons = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if not self:HasIconChanged() then
        return
    end
    local dic = {}
    for targetId, newIcon in pairs(self.m_changedIcons) do
        local cell = self.m_id2Cell[targetId]
        local info = self.m_showingCellDic[cell]
        dic[info.entry.nodeId] = newIcon
    end
    return dic
end



BlueprintPreview.HasIconChanged = HL.Method().Return(HL.Boolean) << function(self)
    return next(self.m_changedIcons) ~= nil
end







BlueprintPreview.m_curHoverTargetId = HL.Field(HL.Any)


BlueprintPreview.m_curHoverTargetId2 = HL.Field(HL.Any)




BlueprintPreview._UpdateHoverPos = HL.Method() << function(self)
    if not DeviceInfo.usingController and not self.view.maskBtnArea.pointerInArea then
        
        if self.m_curHoverTargetId then
            self:_CancelHover()
        end
        return
    end
    if DeviceInfo.usingController then
        if not self.mouseShow then
            self.view.controllerMouse.gameObject:SetActive(false)
            return
        end
        self.view.controllerMouse.gameObject:SetActive(true)
        local stickValue = InputManagerInst:GetGamepadStickValue(true)
        local moveDelta = stickValue * self.view.config.CONTROLLER_MOVE_SPEED * Time.deltaTime
        local targetPosition = self.view.controllerMouse.anchoredPosition + moveDelta
        local targetNormalizedPosition = self.view.scrollRect.normalizedPosition
        if targetPosition.x <= self.view.config.CONTROLLER_PADDING and self.m_widthScale > 0 then
            targetNormalizedPosition.x = lume.clamp(self.view.scrollRect.normalizedPosition.x - self.view.config.CONTROLLER_ROLL_SPEED * Time.deltaTime / self.m_widthScale,0,1)
        elseif targetPosition.x >= self.view.scrollRectRectTransform.rect.size.x - self.view.config.CONTROLLER_PADDING and self.m_widthScale > 0 then
            targetNormalizedPosition.x = lume.clamp(self.view.scrollRect.normalizedPosition.x + self.view.config.CONTROLLER_ROLL_SPEED * Time.deltaTime / self.m_widthScale,0,1)
        end
        if targetPosition.y <= self.view.config.CONTROLLER_PADDING and self.m_heightScale > 0 then
            targetNormalizedPosition.y = lume.clamp(self.view.scrollRect.normalizedPosition.y - self.view.config.CONTROLLER_ROLL_SPEED * Time.deltaTime / self.m_heightScale,0,1)
        elseif targetPosition.y >= self.view.scrollRectRectTransform.rect.size.y - self.view.config.CONTROLLER_PADDING and self.m_heightScale > 0 then
            targetNormalizedPosition.y = lume.clamp(self.view.scrollRect.normalizedPosition.y + self.view.config.CONTROLLER_ROLL_SPEED * Time.deltaTime / self.m_heightScale,0,1)
        end
        self.view.scrollRect.normalizedPosition = targetNormalizedPosition

        if stickValue ~= Vector2.zero then
            targetPosition.x = lume.clamp(targetPosition.x,self.view.config.CONTROLLER_PADDING,self.view.scrollRectRectTransform.rect.size.x - self.view.config.CONTROLLER_PADDING)
            targetPosition.y = lume.clamp(targetPosition.y,self.view.config.CONTROLLER_PADDING,self.view.scrollRectRectTransform.rect.size.y - self.view.config.CONTROLLER_PADDING)
            self.view.controllerMouse.anchoredPosition = targetPosition
        end
    end

    
    local mousePos = InputManager.mousePosition:XY() 
    local rect = CSUtils.RectTransformToScreenRect(self.view.content.transform, self:GetUICtrl().uiCamera) 
    local relativePos = mousePos - rect.min
    local gridScreenSize = rect.width / self.m_csBP.sourceRect.width
    local gridPos = relativePos / gridScreenSize
    gridPos = Vector2(math.floor(gridPos.x), math.floor(gridPos.y))
    local id1, id2 = self.m_previewHelper:GetGridValue(gridPos.x, gridPos.y)
    if id1 == 0 then
        
        if self.m_curHoverTargetId then
            self:_CancelHover()
        end
        self.view.controllerEditBtn.interactable = false
        return
    end

    
    local cell1 = self.m_id2Cell[id1]
    local info1 = self.m_showingCellDic[cell1]
    local isConveyor = info1.type == NodeType.Belt or info1.type == NodeType.Pipe
    if not isConveyor and id1 == self.m_curHoverTargetId and id2 == self.m_curHoverTargetId2 then
        
        return
    end

    self.view.controllerEditBtn.interactable = info1.canChangeIcon

    self.m_curHoverTargetId = id1
    if id2 == 0 then
        self.m_curHoverTargetId2 = nil
    else
        local cell2 = self.m_id2Cell[id2]
        local info2 = self.m_showingCellDic[cell2]
        if info2.isHighLayer then
            self.m_curHoverTargetId = id2
            self.m_curHoverTargetId2 = id1
            isConveyor = info2.type == NodeType.Belt or info2.type == NodeType.Pipe
            cell1, info1 = cell2, info2
        else
            self.m_curHoverTargetId2 = id2
        end
    end
    self:_UpdateHoverTips()

    self.view.hoverHint.gameObject:SetActive(true)
    self.view.hoverTipsNode.gameObject:SetActive(true)

    if isConveyor then
        self.view.hoverHint.transform.sizeDelta = Vector2(uiSizePerUnit, uiSizePerUnit)
        self.view.hoverHint.transform.anchoredPosition = Vector2(math.floor(gridPos.x) + 0.5, math.floor(gridPos.y) + 0.5) * uiSizePerUnit
    else
        self.view.hoverHint.transform.sizeDelta = cell1.transform.sizeDelta
        self.view.hoverHint.transform.anchoredPosition = cell1.transform.anchoredPosition
    end
end



BlueprintPreview._CancelHover = HL.Method() << function(self)
    self.m_curHoverTargetId = nil
    self.m_curHoverTargetId2 = nil
    self.view.hoverHint.gameObject:SetActive(false)
    self.view.hoverTipsNode.gameObject:SetActive(false)
end



BlueprintPreview._OnClick = HL.Method() << function(self)
    if not self.m_canEdit then
        return
    end

    self:_UpdateHoverPos()

    if self.m_curHoverTargetId then
        local info = self.m_showingCellDic[self.m_id2Cell[self.m_curHoverTargetId]]
        if not info.canChangeIcon then
            return
        end
        self:_ShowChangeIconNode(self.m_curHoverTargetId)
        
    end
    if self.m_curHoverTargetId2 then
        
    end
end



BlueprintPreview._UpdateHoverTips = HL.Method() << function(self)
    self:_UpdateSingleHoverTips(self.view.hoverTipsCell, self.m_curHoverTargetId)
    self:_UpdateSingleHoverTips(self.view.hoverTipsCell2, self.m_curHoverTargetId2)
end





BlueprintPreview._UpdateSingleHoverTips = HL.Method(HL.Table, HL.Any) << function(self, cell, targetId)
    if not targetId then
        cell.m_curTargetId = nil
        cell.gameObject.gameObject:SetActive(false)
        return
    end
    local oriActive = cell.gameObject.activeInHierarchy
    cell.gameObject.gameObject:SetActive(true)
    if cell.m_curTargetId == targetId then
        if not oriActive then
            AudioAdapter.PostEvent("Au_UI_Popup_CommonHoverTipPanel_Open")
        end
        return
    end
    cell.m_curTargetId = targetId
    AudioAdapter.PostEvent("Au_UI_Popup_CommonHoverTipPanel_Open")

    local nodeCell = self.m_id2Cell[targetId]
    local info = self.m_showingCellDic[nodeCell]
    local templateId = info.entry.templateId
    local icon, name, itemId
    if info.type == NodeType.Building then
        local data = Tables.factoryBuildingTable[templateId]
        icon = data.iconOnPanel
        name = data.name
        itemId = FactoryUtils.getBuildingItemId(templateId)
    elseif info.type == NodeType.Logistic then
        local data = FactoryUtils.getLogisticData(templateId)
        icon = data.iconOnPanel
        name = data.name
        itemId = data.itemId
    elseif info.type == NodeType.Belt then
        local data = Tables.factoryGridBeltTable[templateId]
        icon = data.beltData.iconOnPanel
        name = data.beltData.name
        itemId = data.beltData.itemId
    elseif info.type == NodeType.Pipe then
        local data = Tables.factoryLiquidPipeTable[templateId]
        icon = data.pipeData.iconOnPanel
        name = data.pipeData.name
        itemId = data.pipeData.itemId
    end

    cell.icon:LoadSprite(UIConst.UI_SPRITE_FAC_BUILDING_PANEL_ICON, icon)
    cell.nameTxt.text = name
    local itemData = Tables.itemTable[itemId]
    cell.rarityLine.color = UIUtils.getItemRarityColor(itemData.rarity)
end









BlueprintPreview._OnEnable = HL.Override() << function(self)
    if self.m_updateId < 0 then
        self.m_updateId = LuaUpdate:Add("TailTick", function()
            self:_UpdateHoverPos()
        end)
    end
end



BlueprintPreview._OnDisable = HL.Override() << function(self)
    if self.m_updateId then
        self.m_updateId = LuaUpdate:Remove(self.m_updateId)
    end
end



BlueprintPreview._OnDestroy = HL.Override() << function(self)
    if self.m_updateId then
        self.m_updateId = LuaUpdate:Remove(self.m_updateId)
    end
end



BlueprintPreview._GetNextTargetId = HL.Method().Return(HL.Number) << function(self)
    local id = self.m_nextTargetId
    self.m_nextTargetId = self.m_nextTargetId + 1
    return id
end




BlueprintPreview._PrepareCellImgCache = HL.Method(HL.Any) << function(self, cell)
    if not cell.m_imgCache then
        cell.m_imgCache = CommonCache(function()
            local obj = CSUtils.CreateObject(cell.image.gameObject, cell.image.transform.parent)
            return obj.gameObject:GetComponent("UIImage")
        end, function(img)
            img.gameObject:SetActive(true)
        end, function(img)
            img.gameObject:SetActive(false)
        end)
        cell.m_imgCache:Cache(cell.image) 
        cell.m_showingImgs = {}
    else
        for _, img in ipairs(cell.m_showingImgs) do
            cell.m_imgCache:Cache(img)
        end
        cell.m_showingImgs = {}
    end
end




HL.Commit(BlueprintPreview)
return BlueprintPreview
