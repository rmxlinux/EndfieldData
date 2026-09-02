local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.TyphoeaArcheryChipSet
local PHASE_ID = PhaseId.TyphoeaArcheryChipSet
local system = GameInstance.player.typhoeaArcherySystem
TyphoeaArcheryChipSetCtrl = HL.Class('TyphoeaArcheryChipSetCtrl', uiCtrl.UICtrl)






TyphoeaArcheryChipSetCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}
TyphoeaArcheryChipSetCtrl.m_dungeonId = HL.Field(HL.String) << ""
TyphoeaArcheryChipSetCtrl.m_isLocked = HL.Field(HL.Boolean) << false
TyphoeaArcheryChipSetCtrl.m_chipCfgs = HL.Field(HL.Table)
TyphoeaArcheryChipSetCtrl.m_genCellFunc = HL.Field(HL.Function)
TyphoeaArcheryChipSetCtrl.m_equippedChipIds = HL.Field(HL.Table)
TyphoeaArcheryChipSetCtrl.m_selectBinding = HL.Field(HL.Any)
TyphoeaArcheryChipSetCtrl.m_unselectBinding = HL.Field(HL.Any)
TyphoeaArcheryChipSetCtrl.m_resetBinding = HL.Field(HL.Any)


TyphoeaArcheryChipSetCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg)
    self:_InitUI()
    self:_RefreshAllUIs()
end

TyphoeaArcheryChipSetCtrl._InitData = HL.Method(HL.Any) << function(self, arg)
    self.m_dungeonId = arg.dungeonId
    self.m_chipCfgs = {}
    self.m_equippedChipIds = {}

    local _, isLocked, chipIds = system:GetDungeonArcheryChipSet(self.m_dungeonId)
    self.m_isLocked = isLocked
    for _, id in pairs(chipIds) do
        table.insert(self.m_equippedChipIds, id)
    end

    if isLocked then
        for _, id in pairs(chipIds) do
            local _, info = Tables.typhoeaArcheryChipTable:TryGetValue(id)
            table.insert(self.m_chipCfgs, {
                info = info,
                isEquipped = true,
                sortId = info.sortId,
            })
        end
    else
        for _, info in pairs(Tables.typhoeaArcheryChipTable) do
            local isEquipped = false
            for _, id in pairs(chipIds) do
                if id == info.chipId then
                    isEquipped = true
                    break
                end
            end
            table.insert(self.m_chipCfgs, {
                info = info,
                isEquipped = isEquipped,
                sortId = info.sortId,
            })
        end
    end

    table.sort(self.m_chipCfgs,Utils.genSortFunction({"sortId"}, true))
end

TyphoeaArcheryChipSetCtrl._InitUI = HL.Method() << function(self)
    self.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    
    self.view.closeArea.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
    end)
    
    self.view.hintIcon.gameObject:SetActive(self.m_isLocked)
    self.view.hintText.text = self.m_isLocked and Language.LUA_TYPHOEA_ARCHERY_CHIP_SET_LOCKED_HINT or Language.LUA_TYPHOEA_ARCHERY_CHIP_SET_NORMAL_HINT
    
    self.view.scrollList.onUpdateCell:AddListener(function(go, csIndex)
        self:_OnUpdateChipCell(go,csIndex)
    end)
    self.m_genCellFunc = UIUtils.genCachedCellFunction(self.view.scrollList)

    
    if DeviceInfo.usingController then
        self.m_selectBinding = self:BindInputPlayerAction("typhoea_training_chip_select")
        self.m_unselectBinding = self:BindInputPlayerAction("typhoea_training_chip_unselect")
        self.m_resetBinding = self:BindInputPlayerAction("typhoea_training_chip_clear", function()
            self:_ResetChips()
        end)
    end
end

TyphoeaArcheryChipSetCtrl._ResetChips = HL.Method() << function(self)
    
    for i=1, #self.m_chipCfgs do
        local cfg = self.m_chipCfgs[i]
        local cell = self.m_genCellFunc(i)
        cfg.isEquipped = false
        cell.stateController:SetState("Inactive")
    end
    InputManagerInst:ToggleBinding( self.m_selectBinding, true)
    InputManagerInst:ToggleBinding( self.m_unselectBinding, false)
    self:_UpdateChipSet()
end

TyphoeaArcheryChipSetCtrl._RefreshAllUIs = HL.Method() << function(self)
    self.view.scrollList:UpdateCount(#self.m_chipCfgs)

    
    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
        self:SetNaviTarget(self.m_genCellFunc(1).button)
        local enableResetBinding = not self.m_isLocked and #self.m_equippedChipIds > 0
        InputManagerInst:ToggleBinding( self.m_resetBinding, enableResetBinding)
    end
end

TyphoeaArcheryChipSetCtrl._OnUpdateChipCell = HL.Method(HL.Any, HL.Number) << function(self, go, csIndex)
    local cell = self.m_genCellFunc(go)
    local index = LuaIndex(csIndex)
    local chipCfg = self.m_chipCfgs[index]
    local info = chipCfg.info
    
    cell.gameObject.name = "chip_" .. info.chipId
    cell.titleTxt.text = info.chipName
    cell.descTxt.text =  info.chipDesc
    local _, itemData = Tables.itemTable:TryGetValue(info.portableDeviceId)
    if itemData then
        cell.itemImg:LoadSprite(UIConst.UI_SPRITE_ITEM, itemData.iconId)
        cell.iconImg:LoadSprite(UIConst.UI_SPRITE_PORTABLE_DEVICE, itemData.iconId)
    end
    
    local chipSelfUnlocked = system:IsChipUnlocked(info.chipId)
    cell.lockedImg.gameObject:SetActive(self.m_isLocked)
    if self.m_isLocked then
        
        cell.stateController:SetState("Active")
        cell.stateController:SetState("Unlocked")
    else
        
        cell.stateController:SetState(chipCfg.isEquipped and "Active" or "Inactive")
        cell.stateController:SetState(chipSelfUnlocked and "Unlocked" or "Lock")
    end
    
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        
        if self.m_isLocked then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_TYPHOEA_ARCHERY_CHIP_UNCHANGEABLE)
            return
        end
        
        if not chipSelfUnlocked then
            return
        end
        
        if not chipCfg.isEquipped and #self.m_equippedChipIds == 2 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_TYPHOEA_ARCHERY_CHIP_SET_COUNT_MAX)
            return
        end
        chipCfg.isEquipped = not chipCfg.isEquipped
        cell.stateController:SetState(chipCfg.isEquipped and "Active" or "Inactive")
        self:_UpdateChipSet()
        
        if chipCfg.isEquipped then
            cell.animationWrapper:PlayInAnimation()
        end
        
        if DeviceInfo.usingController then
            InputManagerInst:ToggleBinding( self.m_selectBinding, not chipCfg.isEquipped)
            InputManagerInst:ToggleBinding( self.m_unselectBinding, chipCfg.isEquipped)
        end
    end)
    
    if DeviceInfo.usingController then
        cell.button.onIsNaviTargetChanged = function(isTarget)
            if isTarget then
                if self.m_isLocked then
                    InputManagerInst:ToggleBinding( self.m_selectBinding, false)
                    InputManagerInst:ToggleBinding( self.m_unselectBinding, true)
                else
                    InputManagerInst:ToggleBinding( self.m_selectBinding, chipSelfUnlocked and not chipCfg.isEquipped)
                    InputManagerInst:ToggleBinding( self.m_unselectBinding, chipSelfUnlocked and chipCfg.isEquipped)
                end
            end
        end
    end
end

TyphoeaArcheryChipSetCtrl._UpdateChipSet= HL.Method() << function(self)
    self.m_equippedChipIds = {}
    for _, cfg in pairs(self.m_chipCfgs) do
        if cfg.isEquipped then
            table.insert(self.m_equippedChipIds, cfg.info.chipId)
        end
    end
    local enableResetBinding = not self.m_isLocked and #self.m_equippedChipIds > 0
    InputManagerInst:ToggleBinding( self.m_resetBinding, enableResetBinding)
    Notify(MessageConst.ON_TYPHOEA_ARCHERY_CHIP_SET_CHANGED, {
        dungeonId = self.m_dungeonId,
        isLocked = self.m_isLocked,
        chipIds = self.m_equippedChipIds,
    })
end

TyphoeaArcheryChipSetCtrl.OnClose = HL.Override() << function(self)
    if self.m_isLocked then
        return
    end
    
    system:UpdateDungeonChipSet(self.m_dungeonId, self.m_equippedChipIds)
end


HL.Commit(TyphoeaArcheryChipSetCtrl)
