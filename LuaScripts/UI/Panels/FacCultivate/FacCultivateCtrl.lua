local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacCultivate

local EOperationType = CS.Beyond.Gameplay.EOperationType
local FertilizeIncreaseType = GEnums.FertilizeIncreaseType

local stopUpdateShow = false
local STEP_INFO_CELL_ANIMATION_INTERVAL = 0.02

FacCultivateCtrl = HL.Class('FacCultivateCtrl', uiCtrl.UICtrl)



FacCultivateCtrl.m_nodeId = HL.Field(HL.Any)

FacCultivateCtrl.m_soilNode = HL.Field(CS.Beyond.Gameplay.FacSoilSystem.SoilNode)

FacCultivateCtrl.m_soilShow = HL.Field(CS.Beyond.Gameplay.SoilShow)

FacCultivateCtrl.m_soilComp = HL.Field(CS.Beyond.Gameplay.Core.IntFacSoilComponent)

FacCultivateCtrl.m_soilCfg = HL.Field(HL.Userdata)

FacCultivateCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_Soil)

FacCultivateCtrl.m_enumMap = HL.Field(HL.Table)

FacCultivateCtrl.m_enumList = HL.Field(HL.Table)

FacCultivateCtrl.m_enumReverseLookup = HL.Field(HL.Table)

FacCultivateCtrl.m_progressImgMap = HL.Field(HL.Table)

FacCultivateCtrl.m_partNodeList = HL.Field(HL.Table)

FacCultivateCtrl.m_stepInfoCellCache = HL.Field(HL.Forward("UIListCache"))

FacCultivateCtrl.m_stepInfoAnimationCoroutine = HL.Field(HL.Thread)

FacCultivateCtrl.m_hasPlayedStepInfoAnimation = HL.Field(HL.Boolean) << false

FacCultivateCtrl.m_showInfo = HL.Field(HL.Boolean) << false

FacCultivateCtrl.m_currentStep = HL.Field(HL.Number) << -1

FacCultivateCtrl.m_doTweenAnim = HL.Field(HL.Any)

FacCultivateCtrl.m_openedInProgress = HL.Field(HL.Boolean) << false

FacCultivateCtrl.m_waitingExitPhase = HL.Field(HL.Boolean) << false

FacCultivateCtrl.s_key = HL.StaticField(HL.Number) << -1

FacCultivateCtrl.m_mutateLabelCellCache = HL.Field(HL.Any)

FacCultivateCtrl.m_naviToItemBindingId = HL.Field(HL.Number) << -1

FacCultivateCtrl.m_cancelNaviItemBindingId = HL.Field(HL.Number) << -1



FacCultivateCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_CROP_STEP_CHANGE] = '_OnStepChange',
    [MessageConst.ON_CROP_OPERATION_FAILED] = '_OnOperationFailed',
    [MessageConst.ON_CROP_OPERATION_FAILED_FORCE_CLOSE] = '_OnOperationFailedForce',
    [MessageConst.ON_CROP_EXTRA_OPERATION_FINISH] = '_OnExtraOperationFinish',
    [MessageConst.On_FERTILIZE_PANEL_DO_OPERATION] = '_OnUpdateIfDoOperation'
}




FacCultivateCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    if CSFactoryUtil.CheckMinaCharOperateNodeBlockByTeammate(self.m_nodeId) then
        
        self.view.mainPanel.gameObject:SetActiveIfNecessary(false)
        self:_SetCancelBtn(false)
        self.view.bottomNode.gameObject:SetActiveIfNecessary(false)
        self:_ClosePanel()
        return
    end
    self:_BindUI()
    local t = self.view.nodeContainer
    local curStep = self.m_soilNode.soilStage
    local maxCnt = self.m_soilCfg.plantingSteps.Count
    for index, key in ipairs(self.m_partNodeList) do
        local i = index - 1
        local curChild = t[key]
        local visible = (i < maxCnt)
        local currentActive = (i == curStep)
        local currentHasDone = (i < curStep)
        local currentNotStart = (i > curStep)
        if curChild ~= nil then
            if i < maxCnt then
                local cfg = self.m_enumMap[self.m_soilCfg.plantingSteps[i].plantingStepType]
                if cfg ~= nil then
                    curChild.icon:LoadSprite(UIConst.UI_SPRITE_CROP, cfg.icon)
                end
            end
            curChild.gameObject:SetActiveIfNecessary(visible)
        end
    end
    self.view.mainPanel.gameObject:SetActiveIfNecessary(not self.m_soilComp.isNatureResourceBusy)
    self:_SetCancelBtn(self.m_soilComp.isNatureResourceBusy)
    self.view.bottomNode.gameObject:SetActiveIfNecessary(self.m_soilComp.isNatureResourceBusy)

    if self.m_soilComp.isNatureResourceBusy then
        self:_PlayDoTweenAnim()
    end

    self:_SetupUI()

    self:_UpdateShow()
    self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_LARGER_UPDATE_INTERVAL)
            self:_UpdateShow()
        end
    end)
end



FacCultivateCtrl.OnHide = HL.Override() << function(self)
    self:_FinishStepInfoCellAnimation()
end

FacCultivateCtrl.OnClose = HL.Override() << function(self)
    self:_KillTween()
    self:_ClearCellCaches()
end






FacCultivateCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    local nodeId = self.m_uiInfo.nodeId
    self.m_nodeId = nodeId
    self.m_soilNode = GameInstance.player.facSoilSystem:GetSoilNodeInCurrentRegion(nodeId)
    self.m_soilShow = GameInstance.player.facSoilSystem:GetSoilShow(nodeId)
    local _, cfg = Tables.plantingDataTable:TryGetValue(self.m_uiInfo.buildingId)
    self.m_soilCfg = cfg
    self.m_soilComp = self.m_soilShow.facSoilComponent
	self.m_openedInProgress = self.m_soilComp.isNatureResourceBusy

    self.m_enumMap = {
        [GEnums.PlantingStepType.Reclaim] = {
            icon = "icon_fac_plant_1"
        },
        [GEnums.PlantingStepType.Water] = {
            icon = "icon_fac_plant_2"
        },
        [GEnums.PlantingStepType.Grow] = {
            icon = "icon_fac_plant_3"
        },
        [GEnums.PlantingStepType.Harvest] = {
            icon = "icon_fac_plant_4"
        },
    }

    self.m_progressImgMap = {
        [GEnums.PlantingStepType.Reclaim] = {
            icon = "deco_bg_fac_cultivate_1"
        },
        [GEnums.PlantingStepType.Water] = {
            icon = "deco_bg_fac_cultivate_2"
        },
        [GEnums.PlantingStepType.Grow] = {
            icon = "deco_bg_fac_cultivate_3"
        },
        [GEnums.PlantingStepType.Harvest] = {
            icon = "deco_bg_fac_cultivate_4"
        },
        [EOperationType.Fertilize] = {
            icon = "deco_bg_fac_cultivate_5"
        },
    }
    self.m_partNodeList = {
        [1] = "part1",
        [2] = "part2",
        [3] = "part3",
        [4] = "part4",
        [5] = "part5",
        [6] = "part6",
        [7] = "part7",
        [8] = "part8",
    }
    self.m_enumList = {
        [1] = GEnums.PlantingStepType.Reclaim,
        [2] = GEnums.PlantingStepType.Water,
        [3] = GEnums.PlantingStepType.Grow,
        [4] = GEnums.PlantingStepType.Harvest,
    }

    
    self.m_enumReverseLookup = {}
    for k, v in pairs(self.m_enumList) do
        self.m_enumReverseLookup[v] = k
    end
end


FacCultivateCtrl._BindUI = HL.Method() << function(self)
    self.view.btnCommonYellow.onClick:AddListener(function()
        self:_UpdateProgressNode()
        self:_DoOperation()
    end)
    self.view.closeInfoBtn.onClick:AddListener(function()
        AudioAdapter.PostEvent("Au_UI_Toast_Common_Small_Close")     
        self:_SetInfoVisible(false)
    end)
    self.view.itemContent.onClick:AddListener(function()
        self:_KillTween()
        self.m_soilShow:DoInterrupt()
    end)
    self.view.buildingCommon:InitBuildingCommon(self.m_uiInfo, {
        onStateChanged = function(state)
        end
    })
    if not GameInstance.player.facTechTreeSystem:NodeIsLocked("tech_jinlong_4_vaporizer_1") then
        self.view.buildingCommon.isModeEnvRelated = true
    end
    self.view.showStepInfoBtn.onClick:AddListener(function()
        AudioAdapter.PostEvent("Au_UI_Toast_Common_Small_Open")     
        self:_SetInfoVisible(true)
    end)
    
    self.m_stepInfoCellCache = UIUtils.genCellCache(self.view.stepInfoCell)
    if DeviceInfo.usingController then
        self.view.closeContentInfoBtn.onClick:AddListener(function()
            AudioAdapter.PostEvent("Au_UI_Toast_Common_Small_Close") 
            self:_SetInfoVisible(false)
        end)
        self.view.doubleClickCloseBtn.onClick:AddListener(function()
            AudioAdapter.PostEvent("Au_UI_Toast_Common_Small_Close") 
            self:_SetInfoVisible(false)
        end)
        self.view.itemPlantNode.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
        self.m_naviToItemBindingId = UIUtils.bindInputPlayerAction("fac_cultivate_item", function()
            self:SetNaviTarget(self.view.item.view.button)
            InputManagerInst:ToggleBinding(self.m_naviToItemBindingId, false)
            InputManagerInst:ToggleBinding(self.m_cancelNaviItemBindingId, true)
            InputManagerInst:ToggleGroup(self.view.buttonNodeGroup.groupId, false)
        end, self.view.inputGroup.groupId)
        self.m_cancelNaviItemBindingId = UIUtils.bindInputPlayerAction("common_cancel", function()
            self:ClearNaviTarget()
            InputManagerInst:ToggleBinding(self.m_naviToItemBindingId, true)
            InputManagerInst:ToggleBinding(self.m_cancelNaviItemBindingId, false)
            InputManagerInst:ToggleGroup(self.view.buttonNodeGroup.groupId, true)
        end, self.view.inputGroup.groupId)
        InputManagerInst:ToggleBinding(self.m_naviToItemBindingId, true)
        InputManagerInst:ToggleBinding(self.m_cancelNaviItemBindingId, false)
        InputManagerInst:ToggleGroup(self.view.buttonNodeGroup.groupId, true)
    end

    
    self.view.facProgressNode:InitFacProgressNode(1, 1)

    self.m_mutateLabelCellCache = UIUtils.genCellCache(self.view.soilNode.tybeState)
end






FacCultivateCtrl._SetupUI = HL.Method() << function(self)
    
    local stepInfoCount = #self.m_enumList
    if FactoryUtils.checkSoilCanMutate(self.m_nodeId) then
        stepInfoCount = stepInfoCount + 2
    end
    self.m_stepInfoCellCache:Refresh(stepInfoCount, function(cell, index)
        self:_OnUpdateStepCell(cell, index)
    end)
    self:_SetInfoVisible(false)
    self:_UpdateProgressNode()
    self:_SetupNameAndDesc()
end


FacCultivateCtrl._UpdateShow = HL.Method() << function(self)
    
    if self.m_nodeId == nil then
        self:_ExitAnyWay()
        return
    end
    if CSFactoryUtil.CheckMinaCharOperateNodeBlockByTeammate(self.m_nodeId) then
        self:_ExitAnyWay()
        return
    end
	
    if self.m_openedInProgress and not self.m_soilComp.isNatureResourceBusy then
        self:_ExitAnyWay()
        return
    end
    
    if stopUpdateShow then
        return
    end
    local t = self.view.nodeContainer
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]

    
    self.view.facProgressNode:UpdateProgress(1 - self.m_soilShow:GetProgress())
    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow then
        self.view.countTimeText.text = self.m_soilShow:GetRemainTimeString()
    end
    if curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Grow and curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Harvest then
        self.view.textNode.gameObject:SetActiveIfNecessary(false)
        self.view.textNodeYellow.gameObject:SetActiveIfNecessary(true)
    else
        self.view.textNode.gameObject:SetActiveIfNecessary(true)
        self.view.textNodeYellow.gameObject:SetActiveIfNecessary(false)
    end

    
    self:_SetupReward()

    
    self:_SetupMutateAndNeighbor()

    
    if curStep == self.m_currentStep then
        return
    end

    
    self.m_currentStep = curStep
    local maxCnt = self.m_soilCfg.plantingSteps.Count
    for index, key in ipairs(self.m_partNodeList) do
        local i = index - 1;
        local curChild = t[key]
        local visible = (i < maxCnt)
        local currentActive = (i == curStep)
        local currentHasDone = (i < curStep)
        local currentNotStart = (i > curStep)
        if curChild ~= nil then
            if i < maxCnt then
                local cfg = self.m_enumMap[self.m_soilCfg.plantingSteps[i].plantingStepType]
                if cfg ~= nil then
                    curChild.bgLine1.gameObject:SetActiveIfNecessary(currentActive)
                    curChild.bgLine2.gameObject:SetActiveIfNecessary(currentActive)
                    curChild.bgBlock1.gameObject:SetActiveIfNecessary(currentNotStart)
                    curChild.bgBlock2.gameObject:SetActiveIfNecessary(currentHasDone)
                    curChild.line1.gameObject:SetActiveIfNecessary((currentActive) or (currentHasDone))
                    curChild.line2.gameObject:SetActiveIfNecessary(currentHasDone)
                    curChild.dotLine1.gameObject:SetActiveIfNecessary(currentNotStart)
                    curChild.dotLine2.gameObject:SetActiveIfNecessary(currentNotStart or currentActive)
                    if currentNotStart then
                        curChild.icon.color = self.view.config.COLOR_ICON_INACTIVE;
                    end
                end
            end
            curChild.gameObject:SetActiveIfNecessary(visible)
        end
    end
    
    local hasFound, curStepConstCfg = Tables.plantingStepConstTable:TryGetValue(curStepCfg.plantingStepType)
    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow then
        self.view.mainBtnText.text = Language.LUA_FAC_FERTILIZATION_FERTILIZE_BTN
        Notify(MessageConst.REFRESH_CONTROLLER_HINT)
    else
        self.view.mainBtnText.text = curStepConstCfg.btnText
        Notify(MessageConst.REFRESH_CONTROLLER_HINT)
    end

    
    local isFertilizeUnlock = self.m_soilNode.system:IsFertilizeSystemUnlock()
    if LuaSystemManager.factory.inTopView then
        
        self.view.btnCommonYellow.gameObject:SetActiveIfNecessary(true)
        self.view.btnCommonYellow.interactable = false
        self.view.mainBtnText.text = Language.LUA_FAC_SOIL_OPERATION_NOT_ALLOWED_IN_TOP_VIEW
        Notify(MessageConst.REFRESH_CONTROLLER_HINT)
    else
        if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow then
            self.view.mainBtnText.text = Language.LUA_FAC_FERTILIZATION_FERTILIZE_BTN
            Notify(MessageConst.REFRESH_CONTROLLER_HINT)
        else
            self.view.mainBtnText.text = curStepConstCfg.btnText
            Notify(MessageConst.REFRESH_CONTROLLER_HINT)
        end

        
        local hideBtnCommonYellow = curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow and
            (not self.m_soilNode:CanFertilize() or
                (not isFertilizeUnlock))
        self.view.btnCommonYellow.gameObject:SetActiveIfNecessary(not hideBtnCommonYellow)
        self.view.btnCommonYellow.interactable = not hideBtnCommonYellow
    end

    
    if curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Grow and curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Harvest then
        self.view.curStepIconYellow:LoadSprite(UIConst.UI_SPRITE_CROP, self.m_enumMap[curStepCfg.plantingStepType].icon)
        self.view.hintTextYellow.text = curStepConstCfg.hintText
    else
        self.view.curStepIcon:LoadSprite(UIConst.UI_SPRITE_CROP, self.m_enumMap[curStepCfg.plantingStepType].icon)
        self.view.hintText.text = curStepConstCfg.hintText
    end
    if curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Grow then
        self.view.countTimeText.text = "--:--:--"
    end

    
    self:_UpdateFertilizeState(isFertilizeUnlock, curStepCfg)

    
    self:_RefreshBtn()
end


FacCultivateCtrl._SetupReward = HL.Method() << function(self)
    local hasDisplayItem, showItemId = self.m_soilNode:TryGetHarvestDisplayItemId()
    if not hasDisplayItem then
        logger.error(ELogChannel.Factory, "[FacCultivateCtrl] failed to select harvest display item",
            "nodeId:", self.m_nodeId)
        self.view.item:InitItem(nil, true)
        return
    end
    local showItemNum = 0
    local curStepCfg = self.m_soilCfg.plantingSteps[self.m_soilNode.soilStage]
    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Harvest then
        local hasFound, harvestItemCount = self.m_soilNode:TryGetHarvestItemCount(showItemId)
        if not hasFound then
            logger.error(ELogChannel.Factory, "[FacCultivateCtrl] harvest item is missing from server snapshot",
                "nodeId:", self.m_nodeId, "itemId:", showItemId)
            showItemNum = 0
        elseif harvestItemCount < 0 then
            logger.error(ELogChannel.Factory, "[FacCultivateCtrl] harvest item count from server is negative",
                "nodeId:", self.m_nodeId, "itemId:", showItemId, "count:", harvestItemCount)
            showItemNum = 0
        else
            showItemNum = harvestItemCount
        end
    else
        local hasFound, estimatedItemCount = self.m_soilNode:TryGetEstimatedHarvestItemCount(showItemId)
        if not hasFound then
            logger.error(ELogChannel.Factory, "[FacCultivateCtrl] failed to estimate harvest item count",
                "nodeId:", self.m_nodeId, "itemId:", showItemId)
        end
        showItemNum = estimatedItemCount
    end
    self.view.item:InitItem({
        id = showItemId,
        count = showItemNum
    }, true)
end


FacCultivateCtrl._SetupNameAndDesc = HL.Method() << function(self)
    local facValid, curFacCfg = Tables.factoryBuildingTable:TryGetValue(self.m_soilCfg.id)
    self.view.soilItemDescText.text = curFacCfg.desc
    local data = UIUtils.getSoilRewardFirstItem(self.m_soilCfg.rewardId)
    local itemCfg = Tables.itemTable:GetValue(data.id)
    if itemCfg ~= nil then
        self.view.soilItemNameDescText.text = itemCfg.name
    end
end


FacCultivateCtrl._UpdateProgressNode = HL.Method() << function(self)
    
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]
    local hasFound, stepConstCfg = Tables.plantingStepConstTable:TryGetValue(curStepCfg.plantingStepType)
    local imgType = (curStepCfg.plantingStepType ~= GEnums.PlantingStepType.Grow) and curStepCfg.plantingStepType or EOperationType.Fertilize
    self.view.progressImg:LoadSprite(UIConst.UI_SPRITE_CROP, self.m_progressImgMap[imgType].icon)
    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow then
        self.view.bottomProgressText.text = Language.LUA_FAC_FERTILIZATION_PROGRESS
    else
        self.view.bottomProgressText.text = stepConstCfg.progressText
    end
end


FacCultivateCtrl._SetupMutateAndNeighbor = HL.Method() << function(self)
    
    local canMutate = FactoryUtils.checkSoilCanMutate(self.m_nodeId)
    if not canMutate or self.m_showInfo then
        self.view.soilNode.gameObject:SetActive(false)
        return
    end

    
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]
    
    
    
    
    

    self.view.soilNode.gameObject:SetActive(true)

    local mutateData = FactoryUtils.getSoilMutateData(self.m_nodeId)
    local neighborData = FactoryUtils.getSoilNeighborData(self.m_nodeId)

    
    self.m_mutateLabelCellCache:Refresh(2, function(cell, index)
        
        cell = cell
        
        local stateCtrl = cell.stateController
        if index == 1 then
            stateCtrl:SetState(mutateData.complete and "LeftClose" or "LeftOpen")
        end
        if index == 2 then
            stateCtrl:SetState(neighborData.complete and "RightClose" or "RightOpen")
            
            
            
        end
    end)

    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Harvest
       or curStepCfg.plantingStepType == GEnums.PlantingStepType.Water then
        self.view.soilNode.scheduleState.gameObject:SetActive(false)
        return
    end

    
    
    local progressStateCtrl = self.view.soilNode.scheduleState 
    local progressTimeTxt = self.view.soilNode.timeTxt         
    local progressImage = self.view.soilNode.fgBar             
    local progressHintTxt = self.view.soilNode.soilTxt         
    if not mutateData.start then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Red")
        progressTimeTxt.text = "--:--:--"
        progressImage.fillAmount = mutateData.progress
        progressHintTxt.text = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_1
    elseif not mutateData.complete and mutateData.inProgress then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Green")
        progressTimeTxt.text = UIUtils.getRemainingText(mutateData.time)
        progressImage.fillAmount = mutateData.progress
        progressHintTxt.text = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_2
    elseif not mutateData.complete and not mutateData.inProgress then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Red")
        progressTimeTxt.text = "--:--:--"
        progressImage.fillAmount = mutateData.progress
        progressHintTxt.text = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_3
    elseif not neighborData.start then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Red")
        progressTimeTxt.text = "--:--:--"
        progressImage.fillAmount = neighborData.progress
        progressHintTxt.text = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_5
    elseif not neighborData.complete and neighborData.inProgress then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Green")
        progressTimeTxt.text = UIUtils.getRemainingText(neighborData.time)
        progressImage.fillAmount = neighborData.progress
        local format = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_6
        progressHintTxt.text = string.format(format,
            neighborData.count,
            neighborData.count,
            math.floor(Tables.factorySoilConst.SoilIncreaseProducePerSoil * 100 + 0.5))
    elseif not neighborData.complete and not neighborData.inProgress then
        
        progressStateCtrl.gameObject:SetActive(true)
        progressStateCtrl:SetState("Red")
        progressTimeTxt.text = "--:--:--"
        progressImage.fillAmount = neighborData.progress
        progressHintTxt.text = Language.LUA_FAC_CULTIVATE_MUTATE_PROGRESS_HINT_7
    else
        
        progressStateCtrl.gameObject:SetActive(false)
    end
end


FacCultivateCtrl._UpdateFertilizeState = HL.Method(HL.Boolean, HL.Any) << function(self, isFertilizeUnlock, curStepCfg)
    if isFertilizeUnlock then    
        if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow or curStepCfg.plantingStepType == GEnums.PlantingStepType.Harvest then
            self:_UpdateFertilizeIfUnlock()
        else
            self.view.righNodeState:SetState("Normal")
        end
    else
        self.view.righNodeState:SetState("Normal")
    end
end


FacCultivateCtrl._UpdateFertilizeIfUnlock = HL.Method() << function(self)
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]

    
    if self.m_soilNode:CanFertilize() then 
        self.view.righNodeState:SetState("Fertilization")
    else    
        if self.m_soilNode.fertilizeCount == 0 then 
            self.view.righNodeState:SetState("Normal")
        else
            self.view.righNodeState:SetState("FertilizationDone")
        end
    end

    
    local fertilizeData = FactoryUtils.getSoilFertilizaDataBySoilNode(self.m_soilNode)
    
    local foundAccelerate = lume.match(fertilizeData, function(data)
        return data.type == "Accelerate"
    end)
    local accelerateText = foundAccelerate and foundAccelerate.desc or ""
    local foundIncrease = lume.match(fertilizeData, function(data)
        return data.type == "Increase"
    end)
    local increaseText = foundIncrease and foundIncrease.desc or ""
    if string.isEmpty(accelerateText) and string.isEmpty(increaseText) then
        
        self.view.righNodeState:SetState("Normal")
    elseif not string.isEmpty(accelerateText) and string.isEmpty(increaseText) then
        
        self.view.righNodeState:SetState("AccelerateGrowth")
        self.view.textNodeLuaReference.accelerate.accelerateTxt.text = accelerateText
    elseif string.isEmpty(accelerateText) and not string.isEmpty(increaseText) then
        
        self.view.righNodeState:SetState("Increase")
        
        self.view.textNodeLuaReference.accelerate.accelerateTxt.text = increaseText
    elseif not string.isEmpty(accelerateText) and not string.isEmpty(increaseText) then
        self.view.righNodeState:SetState("Both")
        self.view.textNodeLuaReference.accelerate.accelerateTxt.text = accelerateText
        self.view.textNodeLuaReference.increase.increaseTxt.text = increaseText
    end
    
    self.view.textNodeLuaReference.accelerate.textLayout.gameObject:SetActive(false)
    self.view.textNodeLuaReference.increase.textLayout.gameObject:SetActive(false)
    if not string.isEmpty(increaseText) then
        local increaseDataList = foundIncrease.increaseDataList
        local count = #increaseDataList
        if count > 1 then
            local increaseDataFertilize = lume.match(increaseDataList, function(data)
                return data.increaseType == "Fertilize"
            end)
            local increaseDataNeighbor = lume.match(increaseDataList, function(data)
                return data.increaseType == "Neighbor"
            end)
            local increaseDataFertilizeText = increaseDataFertilize and increaseDataFertilize.descRight or ""
            local increaseDataNeighborText = increaseDataNeighbor and increaseDataNeighbor.descRight or ""
            
            
            local useTextLayout
            if string.isEmpty(accelerateText) and not string.isEmpty(increaseText) then
                useTextLayout = self.view.textNodeLuaReference.accelerate.textLayout
            else
                useTextLayout = self.view.textNodeLuaReference.increase.textLayout
            end
            useTextLayout.gameObject:SetActive(true)
            useTextLayout.text1Node.muckNumTxt.text = increaseDataFertilizeText
            useTextLayout.text2Node.borderNumTxt.text = increaseDataNeighborText
        end
    end
end






FacCultivateCtrl._RefreshBtn = HL.Method() << function(self)
    
    
    
    
    
    
    
    
    
    
    
    self:_SetCancelBtn(self.m_soilComp.isNatureResourceBusy)
end


FacCultivateCtrl._SetInfoVisible = HL.Method(HL.Boolean) << function(self, infoVisible)
    if not infoVisible then
        self:_FinishStepInfoCellAnimation()
    end
    self.m_showInfo = infoVisible
    self.view.closeInfoBtn.gameObject:SetActiveIfNecessary(infoVisible)
    self.view.stepContainer.gameObject:SetActiveIfNecessary(not infoVisible)
    local showSoilNode = not infoVisible and FactoryUtils.checkSoilCanMutate(self.m_nodeId)
    self.view.soilNode.gameObject:SetActiveIfNecessary(showSoilNode)
    self.view.stepInfoContainer.gameObject:SetActiveIfNecessary(infoVisible)
    if infoVisible then
        LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.stepInfoListContainer)
        LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.stepInfoContainer)
        self:_PlayStepInfoCellAnimation()
    end
    if DeviceInfo.usingController then
        if infoVisible then
            InputManagerInst:ToggleGroup(self.view.contentInfoStateInputBindingGroupMonoTarget.groupId,true)
            Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, {
                panelId = PANEL_ID,
                isGroup = true,
                id = self.view.contentInfoStateInputBindingGroupMonoTarget.groupId,
                hintPlaceholder = self.view.controllerHintPlaceholder,
                rectTransform = self.view.stepInfoContainer,
                noHighlight = true,
            })
        else
            Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.contentInfoStateInputBindingGroupMonoTarget.groupId)
        end
        self.view.controllerHintPlaceholder.gameObject:SetActive(not infoVisible)
    end
end


FacCultivateCtrl._DoOperation = HL.Method() << function(self)
    if self.m_soilComp.isNatureResourceBusy then
        
        self:_ExitAnyWay()
        return
    end
    local curStep = self.m_soilNode.soilStage
    local stepType = self.m_soilCfg.plantingSteps[curStep].plantingStepType
    if stepType == GEnums.PlantingStepType.Grow then
        if not self.m_soilNode:CanFertilize() then  
            self:_ExitAnyWay()
            return
            
        end
    end

    if not self.m_soilShow:DoOperation(false) then
        return
    end
    
    if self.m_isClosed or self.m_waitingExitPhase then
        return
    end

    if stepType ~= GEnums.PlantingStepType.Grow then
        self.view.mainPanel.gameObject:SetActiveIfNecessary(false)
        self:_SetCancelBtn(true)
        self.view.bottomNode.gameObject:SetActiveIfNecessary(true)
        self:_PlayDoTweenAnim()
    end
end


FacCultivateCtrl._OnStepChange = HL.Method(HL.Table) << function(self, args)
    local nodeId = unpack(args)
    if self.m_soilComp.soilNodeId ~= nodeId then
        return
    end
    self:_KillTween()
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]
    
    local hasFound, stepConstCfg = Tables.plantingStepConstTable:TryGetValue(curStepCfg.plantingStepType)
    
    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Harvest then
        return
    end

    self:_ExitAnyWay()
end



FacCultivateCtrl.ExtractHotSwitchRuntimeState = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    self:_KillTween()
    self:_ClearCellCaches()
    return nil
end


FacCultivateCtrl._KillTween = HL.Method() << function(self)
    if self.m_doTweenAnim then
        self.m_doTweenAnim:Kill()
    end
    self.m_doTweenAnim = nil
end


FacCultivateCtrl._SetCancelBtn = HL.Method(HL.Boolean) << function(self, showBtn)
    self.view.itemContent.gameObject:SetActiveIfNecessary(showBtn)
end


FacCultivateCtrl._OnOperationFailed = HL.Method(HL.Any) << function(self, arg)
    local nodeId = unpack(arg)
    if self.m_nodeId == nodeId then
        self:_ExitAnyWay()
    end
end


FacCultivateCtrl._OnExtraOperationFinish = HL.Method(HL.Any) << function(self, arg)
    local nodeId = unpack(arg)
    if self.m_nodeId == nodeId then
        self:_ExitAnyWay()
    end
end


FacCultivateCtrl._OnOperationFailedForce = HL.Method(HL.Any) << function(self, arg)
    self:_ExitAnyWay()
end


FacCultivateCtrl._ExitAnyWay = HL.Method() << function(self)
    self:_KillTween()
    if self.view.bottomNode.gameObject.activeInHierarchy then   
        self.view.progressAnim:PlayOutAnimation(function()
            self:_ClosePanel()
        end)
    else    
        self.view.contentAnim:PlayOutAnimation(function()
            self:_ClosePanel()
        end)
    end
end


FacCultivateCtrl._ClosePanel = HL.Method() << function(self)
    
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, self.view.contentInfoStateInputBindingGroupMonoTarget.groupId)
    local isOpen, sideMenuCtrl = UIManager:IsOpen(PanelId.ControllerSideMenu)
    if isOpen then
        sideMenuCtrl:PlayAnimationOutAndClose()
    end
    if not PhaseManager:IsOpen(PhaseId.FacMachine) then
        UIManager:Close(PANEL_ID)
        return
    end
    if not PhaseManager:CheckIsInTransition() then
        PhaseManager:ExitPhaseFast(PhaseId.FacMachine)
        return
    end
    if self.m_waitingExitPhase then
        return
    end
    self.m_waitingExitPhase = true
    self:_StartCoroutine(function()
        coroutine.waitCondition(function()
            return self.m_isClosed or not PhaseManager:CheckIsInTransition()
        end)
        self.m_waitingExitPhase = false
        if self.m_isClosed then
            return
        end
        if PhaseManager:IsOpen(PhaseId.FacMachine) then
            PhaseManager:ExitPhaseFast(PhaseId.FacMachine)
        else
            UIManager:Close(PANEL_ID)
        end
    end)
end


FacCultivateCtrl._OnUpdateIfDoOperation = HL.Method() << function(self)
    
    
    
    
    self:_ClosePanel()
end


FacCultivateCtrl._PlayDoTweenAnim = HL.Method() << function(self)
    local curStep = self.m_soilNode.soilStage
    local curStepCfg = self.m_soilCfg.plantingSteps[curStep]
    local progress = self.m_soilShow:GetProgress()
    self.view.barMask.sizeDelta = Vector2(-(1 - progress) * self.view.bar.rect.size.x,self.view.barMask.sizeDelta.y)
    self:_UpdateShow()  

    local stepNum = CSIndex(self.m_enumReverseLookup[curStepCfg.plantingStepType])
    local totalTime = 0
    local plantingSteps = self.m_soilCfg.plantingSteps

    if curStepCfg.plantingStepType == GEnums.PlantingStepType.Grow and Tables.fertilizeDataTable[self.m_soilNode.fertilizeId] then
        totalTime = Tables.fertilizeDataTable[self.m_soilNode.fertilizeId].fertilizeTime
    else
        totalTime = plantingSteps[stepNum].plantingStepParameter.valueIntList[0]
    end

    if self.view.barMask.gameObject.activeSelf then
        self.m_doTweenAnim = self.view.barMask:DOSizeDelta(
            Vector2(0, self.view.barMask.rect.size.y),
            totalTime * (1 - progress)
        ):SetEase(1)
    end
end


FacCultivateCtrl._PlayStepInfoCellAnimation = HL.Method() << function(self)
    if self.m_hasPlayedStepInfoAnimation or not self.m_stepInfoCellCache then
        return
    end
    self.m_hasPlayedStepInfoAnimation = true

    local count = self.m_stepInfoCellCache:GetCount()
    self.m_stepInfoCellCache:Update(function(cell)
        cell.animationWrapper:SampleToInAnimationBegin()
    end)
    self.m_stepInfoAnimationCoroutine = self:_StartCoroutine(function()
        for index = 1, count do
            if index > 1 then
                coroutine.wait(STEP_INFO_CELL_ANIMATION_INTERVAL)
            end
            local cell = self.m_stepInfoCellCache:GetItem(index)
            cell.animationWrapper:PlayInAnimation()
        end
        self.m_stepInfoAnimationCoroutine = nil
    end)
end


FacCultivateCtrl._FinishStepInfoCellAnimation = HL.Method() << function(self)
    if self.m_stepInfoAnimationCoroutine then
        self.m_stepInfoAnimationCoroutine = self:_ClearCoroutine(self.m_stepInfoAnimationCoroutine)
    end
    if not self.m_hasPlayedStepInfoAnimation or not self.m_stepInfoCellCache then
        return
    end
    self.m_stepInfoCellCache:Update(function(cell)
        cell.animationWrapper:ClearTween(false)
        cell.animationWrapper:SampleToInAnimationEnd()
    end)
end


FacCultivateCtrl._ClearCellCaches = HL.Method() << function(self)
    self:_FinishStepInfoCellAnimation()
    if self.m_stepInfoCellCache then
        self.m_stepInfoCellCache:Refresh(0)
        self.m_stepInfoCellCache:ClearAll()
        self.m_stepInfoCellCache = nil
    end
    if self.m_mutateLabelCellCache then
        self.m_mutateLabelCellCache:Refresh(0)
        self.m_mutateLabelCellCache:ClearAll()
        self.m_mutateLabelCellCache = nil
    end
end


FacCultivateCtrl._OnUpdateStepCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    
    local uiStateCtrl = cell.animationNode
    if index <= #self.m_enumList then
        uiStateCtrl:SetState("Normal")
        local curEnum = self.m_enumList[index]
        local hasFound, curStepConstCfg = Tables.plantingStepConstTable:TryGetValue(curEnum)
        local showCfg = self.m_enumMap[curEnum]
        cell.icon:LoadSprite(UIConst.UI_SPRITE_CROP, showCfg.icon)
        cell.text.text = curStepConstCfg.stepDescription
    else
        
        uiStateCtrl:SetState("Desc")
        local extraIndex = index - #self.m_enumList
        local text = extraIndex == 1
            and Language.LUA_FAC_CULTIVATE_TIPS_MUTATE
            or Language.LUA_FAC_CULTIVATE_TIPS_NEIGHBOR
        cell.descTxt.text = text
    end
    cell.blackBG.gameObject:SetActiveIfNecessary(index % 2 == 0)
end


FacCultivateCtrl._OnOpenCrop = HL.StaticMethod(HL.Any) << function(arg)
    local unpackNodeId, cb = unpack(arg)
    if CSFactoryUtil.CheckMinaCharOperateNodeBlockByTeammate(unpackNodeId) then
        return
    end
    if PhaseManager:IsOpen(PhaseId.FacMachine) then
        return
    end
    if UIManager:IsOpen(PANEL_ID) then
        return
    end

    if PhaseManager:IsOpen(PhaseId.FacFertilization) then
        PhaseManager:ExitPhaseFast(PhaseId.FacFertilization)
    end

    Notify(MessageConst.FAC_OPEN_BUILDING_PANEL, {
        nodeId = unpackNodeId,
        failCb = cb,
    })
end






HL.Commit(FacCultivateCtrl)
