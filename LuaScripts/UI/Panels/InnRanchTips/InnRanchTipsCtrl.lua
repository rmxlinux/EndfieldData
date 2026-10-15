local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRanchTips
local ranchSystem = GameInstance.player.ranchSystem
local TIPS_TICK_INTERVAL = 1
local TIPS_ARROW_EDGE_OFFSET = 4

InnRanchTipsCtrl = HL.Class('InnRanchTipsCtrl', uiCtrl.UICtrl)

InnRanchTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
}

InnRanchTipsCtrl.m_ranchId = HL.Field(HL.String) << ""
InnRanchTipsCtrl.m_stableId = HL.Field(HL.String) << ""
InnRanchTipsCtrl.m_targetTransform = HL.Field(HL.Userdata)
InnRanchTipsCtrl.m_coroutine = HL.Field(HL.Thread)
InnRanchTipsCtrl.m_controllerInputGroupId = HL.Field(HL.Number) << -1
InnRanchTipsCtrl.m_feedInputGroupId = HL.Field(HL.Number) << -1
InnRanchTipsCtrl.m_feedInputParentGroupId = HL.Field(HL.Number) << -1
InnRanchTipsCtrl.m_closeBindingId = HL.Field(HL.Number) << -1


InnRanchTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_controllerInputGroupId = self:CreateInputGroup()
    self.view.happyInfo.infoText.text = Language.LUA_RANCH_TIPS_HAPPINESS
    self.view.foodInfo.infoText.text = Language.LUA_RANCH_TIPS_FULLNESS
    self.view.descNode1.text = Language.LUA_RANCH_TIPS_FULLNESS_DESC
    self.view.descNode2.text = Language.LUA_RANCH_TIPS_HAPPINESS_DESC
    self.view.productionNode1.productNumTitle.text = Language.LUA_RANCH_TIPS_PRODUCED
    self.view.productionNode1.productSpeedTitle.text = Language.LUA_RANCH_TIPS_PRODUCT_RATE
    self.view.productionNode2.productNumTitle.text = Language.LUA_RANCH_TIPS_PRODUCED
    self.view.productionNode2.productSpeedTitle.text = Language.LUA_RANCH_TIPS_PRODUCT_RATE

    self.view.autoCloseArea.onTriggerAutoClose:AddListener(function()
        self:_ClearOnClose()
    end)
end

InnRanchTipsCtrl.ShowTips = HL.StaticMethod(HL.Table) << function(args)
    local self = UIManager:AutoOpen(PANEL_ID)
    self:_ShowTips(args)
end

InnRanchTipsCtrl._OpenControllerMode = HL.Method(HL.Table) << function(self, args)
    self.m_feedInputGroupId = args.feedInputGroupId
    self.m_feedInputParentGroupId = InputManagerInst:GetGroupParentId(true, self.m_feedInputGroupId)
    
    InputManagerInst:ChangeParent(true, self.m_feedInputGroupId, self.m_controllerInputGroupId)
    self.m_closeBindingId = self:BindInputPlayerAction("common_cancel", function()
        self:CloseTips()
    end, self.m_controllerInputGroupId)

    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
        panelId = PANEL_ID,
        isGroup = true,
        id = self.m_controllerInputGroupId,
        hintPlaceholder = args.hintPlaceholder,
        rectTransform = args.transform,
        noHighlight = true,
        onClose = function()
            self:_ClearControllerMode()
        end,
    })
end

InnRanchTipsCtrl._ClearControllerMode = HL.Method() << function(self)
    if self.m_closeBindingId > 0 then
        self.m_closeBindingId = self:DeleteInputBinding(self.m_closeBindingId)
    end
    
    if self.m_feedInputGroupId > 0 then
        InputManagerInst:ChangeParent(true, self.m_feedInputGroupId, self.m_feedInputParentGroupId)
    end
    self.m_feedInputGroupId = -1
    self.m_feedInputParentGroupId = -1
end

InnRanchTipsCtrl._CloseControllerMode = HL.Method() << function(self)
    if self.m_feedInputGroupId < 0 then
        return
    end

    local feedInputGroupId = self.m_feedInputGroupId
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.m_controllerInputGroupId)
    if self.m_feedInputGroupId == feedInputGroupId then
        self:_ClearControllerMode()
    end
end

InnRanchTipsCtrl._ShowTips = HL.Method(HL.Table) << function(self, args)
    if args.transform == self.m_targetTransform then
        if not DeviceInfo.usingController then
            self.view.autoCloseArea:CloseSelf()
        end
        return
    end

    self:_CloseControllerMode()
    self.m_ranchId = args.ranchId
    self.m_stableId = args.stableId
    self.m_targetTransform = args.transform

    UIManager:SetTopOrder(PANEL_ID)
    self.view.autoCloseArea:OpenSelf()
    if DeviceInfo.usingController then
        self:_OpenControllerMode(args)
    end
    self:_Refresh(true)
    self:_StartTick()
end

InnRanchTipsCtrl._Refresh = HL.Method(HL.Opt(HL.Boolean)) << function(self, refreshStatic)
    local hasAnimal, animalData = ranchSystem:GetStableAnimal(self.m_ranchId, self.m_stableId)
    if not hasAnimal then
        self:CloseTips()
        return
    end

    local _, animalCfg = Tables.innRanchAnimalTable:TryGetValue(animalData.animalId)
    local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local happinessLeftSec = math.max(0, animalData.happinessExhaustedTs - currentTime)
    local fullnessLeftSec = math.max(0, animalData.fullnessExhaustedTs - currentTime)
    local happinessAvailable = happinessLeftSec > 0
    local fullnessAvailable = fullnessLeftSec > 0

    self.view.happyInfo.timeText.text = string.format("%s", UIUtils.getLeftTimeToSecond(happinessLeftSec, true))
    self.view.foodInfo.timeText.text = string.format("%s",  UIUtils.getLeftTimeToSecond(fullnessLeftSec, true))
    local showHighLevelInfo = InnUtils.isRanchHighProductionUnLock()
    self.view.happyInfo.gameObject:SetActive(showHighLevelInfo)
    self.view.descNode2.gameObject:SetActive(showHighLevelInfo)
    self.view.productionNode2.gameObject:SetActive(showHighLevelInfo)

    local periodSec = Const.SEC_PER_HOUR

    local refreshProductNode = function(node, itemId, productCount, isHighLevel)
        local _, itemCfg = Tables.itemTable:TryGetValue(itemId)
        if refreshStatic then
            node.productIcon:LoadSprite(UIConst.UI_SPRITE_ITEM, itemCfg.iconId)
            node.productName.text = itemCfg.name
            UIUtils.setItemRarityImage(node.decoQuality, itemCfg.rarity)
        end

        local productMaxCount = isHighLevel and animalCfg.highLevelProdMaxCount or animalCfg.lowLevelProdMaxCount
        local isFull = productCount >= productMaxCount
        
        local productionState = "TimeCount"
        if isFull then
            productionState = "UpperLimit"
        elseif isHighLevel and not happinessAvailable then
            productionState = "Happy"
        elseif not fullnessAvailable then
            productionState = "Hunger"
        end
        local productYieldRate = isHighLevel and animalCfg.highYieldRate or animalCfg.lowYieldRate
        local yieldRate = productionState == "TimeCount" and productYieldRate or 0
        node.productionStateNode:SetState(productionState)

        
        
        local accumulatedSecs = isHighLevel and animalData.advanceSecs or animalData.ordinarySecs
        local progressTime = currentTime 
        if isFull then
            progressTime = animalData.lastUpdateTs 
        else
            progressTime = math.min(progressTime, animalData.fullnessExhaustedTs) 
            if isHighLevel then
                progressTime = math.min(progressTime, animalData.happinessExhaustedTs) 
            end
        end
        
        local elapsedSinceLastUpdate = math.max(0, progressTime - animalData.lastUpdateTs)
        local cycleElapsedSec = (math.max(0, accumulatedSecs) + elapsedSinceLastUpdate) % periodSec
        local remainingSec = periodSec - cycleElapsedSec
        local productionProgress = cycleElapsedSec / periodSec
        node.timeCountText.text = UIUtils.getLeftTimeToSecond(remainingSec)
        node.slider.fillAmount = productionProgress

        node.productNumText.text = string.format("%d/%d",  productCount, productMaxCount)
        node.productSpeedText.text = string.format(Language.LUA_RANCH_ANIMAL_PRODUCT_RATE, yieldRate)
        node.productNumState:SetState(isFull and "Full" or "Normal")
        node.productSpeedState:SetState(yieldRate == 0 and "Null" or "Normal")
    end

    refreshProductNode(self.view.productionNode1, animalCfg.lowLevelProd, animalData.lowLevelProdCount, false)
    if showHighLevelInfo then
        refreshProductNode(self.view.productionNode2, animalCfg.highLevelProd, animalData.highLevelProdCount, true)
    end

    UIUtils.updateTipsPosition(self.view.content, self.m_targetTransform, self.view.rectTransform, self.uiCamera,
                               UIConst.UI_TIPS_POS_TYPE.AdaptiveRightTop)
    self:_RefreshArrowPosition()
end

InnRanchTipsCtrl._RefreshArrowPosition = HL.Method() << function(self)
    if not self.m_targetTransform then
        return
    end
    local arrow = self.view.decoArrow.transform
    local content = self.view.content
    
    local targetScreenRect = UIUtils.getTransformScreenRect(self.m_targetTransform, self.uiCamera)
    local targetScreenPos = Vector2(targetScreenRect.center.x, Screen.height - targetScreenRect.center.y)
    local targetPos, valid = UIUtils.screenPointToUI(targetScreenPos, self.uiCamera, content)
    if not valid then
        return
    end

    
    local contentRect = content.rect
    local pointLeft = targetPos.x <= contentRect.center.x
    local arrowScale = arrow.localScale
    arrowScale.x = math.abs(arrowScale.x) * (pointLeft and 1 or -1)
    arrow.localScale = arrowScale
    local arrowX = pointLeft and contentRect.xMin - TIPS_ARROW_EDGE_OFFSET
            or contentRect.xMax + TIPS_ARROW_EDGE_OFFSET
    
    local halfArrowHeight = arrow.rect.height * math.abs(arrow.lossyScale.y / content.lossyScale.y) / 2
    local padding = math.min(halfArrowHeight, contentRect.height / 2)
    local arrowY = lume.clamp(targetPos.y, contentRect.yMin + padding, contentRect.yMax - padding)
    arrow.position = content:TransformPoint(Vector3(arrowX, arrowY, 0))
end

InnRanchTipsCtrl._StartTick = HL.Method() << function(self)
    self.m_coroutine = self:_ClearCoroutine(self.m_coroutine)
    self.m_coroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(TIPS_TICK_INTERVAL)
            self:_Refresh()
        end
    end)
end

InnRanchTipsCtrl._ClearOnClose = HL.Method() << function(self)
    self:_CloseControllerMode()
    self.m_coroutine = self:_ClearCoroutine(self.m_coroutine)
    self.m_targetTransform = nil
    self.m_ranchId = ""
    self.m_stableId = ""
end

InnRanchTipsCtrl.CloseTips = HL.Method() << function(self)
    if self.view.autoCloseArea.toggleObj.activeSelf then
        self.view.autoCloseArea:CloseSelf()
    end
end

InnRanchTipsCtrl.OnHide = HL.Override() << function(self)
    self:_ClearOnClose()
end

InnRanchTipsCtrl.OnClose = HL.Override() << function(self)
    self:_ClearOnClose()
end

HL.Commit(InnRanchTipsCtrl)
