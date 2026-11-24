local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local FormationZoneTypes = CS.Beyond.Gameplay.Factory.FormationZoneTypes
local FormationZoneRuntimeState = CS.Beyond.Gameplay.RemoteFactory.FormationZone.FormationZoneRuntimeState

local STATE_NORMAL = "Nrl"
local STATE_WARN = "Warn"
local STATE_NOT_SELECT = "NotSelect"
local STATE_EMPTY = "Empty"
local STATE_LOCK = "Lock"

FacMagicNode = HL.Class('FacMagicNode', UIWidgetBase)

FacMagicNode.m_changeBtnCallback = HL.Field(HL.Function)


FacMagicNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.changeBtn.onClick:RemoveAllListeners()
    self.view.changeBtn.onClick:AddListener(function()
        if self.m_changeBtnCallback then
            self.m_changeBtnCallback()
        end
    end)
    self.view.button.onClick:AddListener(function()
        if self.m_changeBtnCallback then
            self.m_changeBtnCallback()
        end
    end)
end

FacMagicNode.InitFacMagicNode = HL.Method() << function(self)
    self:InitFacMagicNodeByEmpty()
end

FacMagicNode.InitFacMagicNodeByEmpty = HL.Method() << function(self)
    self:_FirstTimeInit()

    self.view.stateController:SetState(STATE_EMPTY)
    self.view.formationLvTag.gameObject:SetActiveIfNecessary(false)
    self.view.titleText.text = ""
end

FacMagicNode.InitFacMagicNodeByTableId = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, tableId, useBigIcon)
    self:_InitFacMagicNodeByTableIdAndState(tableId, STATE_NORMAL, useBigIcon)
end

FacMagicNode.InitFacMagicNodeByWarnTableId = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, tableId, useBigIcon)
    self:_InitFacMagicNodeByTableIdAndState(tableId, STATE_WARN, useBigIcon)
end

FacMagicNode.InitFacMagicNodeByLockTableId = HL.Method(HL.String, HL.Opt(HL.Boolean)) << function(self, tableId, useBigIcon)
    self:_InitFacMagicNodeByTableIdAndState(tableId, STATE_LOCK, useBigIcon)
end

FacMagicNode.InitFacMagicNodeByNotSelect = HL.Method() << function(self)
    self:_FirstTimeInit()

    self.view.stateController:SetState(STATE_NOT_SELECT)
    self.view.formationLvTag.gameObject:SetActiveIfNecessary(false)
    self.view.titleText.text = ""
end

FacMagicNode._InitFacMagicNodeByTableIdAndState = HL.Method(HL.String, HL.String, HL.Opt(HL.Boolean)) << function(self, tableId, stateName, useBigIcon)
    self:_FirstTimeInit()

    if string.isEmpty(tableId) then
        self:InitFacMagicNodeByEmpty()
        return
    end

    local hasCfg, cfg = Tables.factoryFormationTable:TryGetValue(tableId)
    if not hasCfg then
        logger.error("FacMagicNode._InitFacMagicNodeByTableIdAndState failed, missing FactoryFormationTable cfg:", tableId)
        self:InitFacMagicNodeByEmpty()
        return
    end

    self.view.stateController:SetState(stateName)
    self.view.formationLvTag.gameObject:SetActiveIfNecessary(false)
    self.view.magicImg:LoadSprite(useBigIcon and UIConst.UI_SPRITE_ITEM_BIG or UIConst.UI_SPRITE_ITEM, cfg.icon)
    self.view.titleText.text = cfg.name
end

FacMagicNode.InitFacMagicNodeByInst = HL.Method(HL.Any, HL.Opt(HL.Boolean)) << function(self, inst, useBigIcon)
    self:_FirstTimeInit()

    if inst == nil then
        self:InitFacMagicNodeByEmpty()
        return
    end

    local formationId = inst.formationId
    local stateName = STATE_NORMAL
    if inst.slot ~= nil then
        local slot = inst.slot
        if slot.selectedType == FormationZoneTypes.NONE then
            self:InitFacMagicNodeByNotSelect()
            return
        end
        formationId = FactoryUtils.FORMATION_ID_BY_ZONE_TYPE[slot.selectedType]
        if not slot.countsForLevel or slot.stakeState ~= GEnums.FacBuildingState.Normal then
            stateName = STATE_WARN
        end
    elseif inst.runtimeState ~= nil and inst.runtimeState ~= FormationZoneRuntimeState.NORMAL then
        stateName = STATE_WARN
    end

    if string.isEmpty(formationId) then
        self:InitFacMagicNodeByEmpty()
        return
    end

    self:_InitFacMagicNodeByTableIdAndState(formationId, stateName, useBigIcon)
    if inst.level ~= nil then
        local levelCfg = Tables.factoryFormationLevelTable:GetValue(formationId).levels[inst.level]
        self.view.titleText.text = levelCfg.name
        self:ForceRefreshFormationLevel(inst.level)
    end
end

FacMagicNode.SetFacMagicNodeButtonCallbacks = HL.Method(HL.Function) << function(self, changeBtnCallback)
    self:_FirstTimeInit()

    self.m_changeBtnCallback = changeBtnCallback
end

FacMagicNode.SetTitleTextVisible = HL.Method(HL.Boolean) << function(self, visible)
    self:_FirstTimeInit()

    self.view.titleText.gameObject:SetActiveIfNecessary(visible)
end

FacMagicNode.ForceRefreshFormationLevel = HL.Method(HL.Number) << function(self, level)
    self:_FirstTimeInit()

    self.view.formationLvTag.gameObject:SetActiveIfNecessary(true)
    self.view.lvTxt.text = string.format(Language.LUA_FAC_FORMATION_LEVEL_FORMAT, tostring(level))
end

HL.Commit(FacMagicNode)
return FacMagicNode

