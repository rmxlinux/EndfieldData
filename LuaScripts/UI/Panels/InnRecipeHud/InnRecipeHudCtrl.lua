local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnRecipeHud

InnRecipeHudCtrl = HL.Class('InnRecipeHudCtrl', uiCtrl.UICtrl)







InnRecipeHudCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.FAC_MAIN_HUD_RIGHT_TOP_LAYER_CHANGED] = '_OnFacMainRightTopLayerChanged',
    [MessageConst.ON_EXIT_FACTORY_MODE] = '_OnExitFactoryMode',
}

InnRecipeHudCtrl.s_enteredZoneIds = HL.StaticField(HL.Table) << {}


InnRecipeHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.recipeBtn.onClick:AddListener(function()
        self:OpenInnRecipeOverview()
    end)

end








InnRecipeHudCtrl.OpenInnRecipeOverview = HL.Method() << function()
    PhaseManager:OpenPhase(PhaseId.InnRecipeOverview, { showIngredient = true })
end

InnRecipeHudCtrl._OnFacMainRightTopLayerChanged = HL.Method(HL.Table) << function(self, args)
    local isTopLayer, facMainRightGroupId = unpack(args)
    local recipeBtn = self.view.recipeBtn
    if isTopLayer then
        recipeBtn.onClick:ChangeBindingPlayerAction("inn_recipe_hud_open_alter")
        InputManagerInst:ChangeParent(true, recipeBtn.groupId, facMainRightGroupId)
    else
        recipeBtn.onClick:ChangeBindingPlayerAction("inn_recipe_hud_open")
        InputManagerInst:ChangeParent(true, recipeBtn.groupId, self.view.inputGroup.groupId)
    end
end

InnRecipeHudCtrl._OnExitFactoryMode = HL.Method() << function(self)
    self:_CloseByWorldEvent()
end

InnRecipeHudCtrl._CloseByWorldEvent = HL.Method() << function(self)
    if self:IsPlayingAnimationOut() or not UIManager:IsShow(self.panelId) then
        self:Close()
        return
    end
    self:PlayAnimationOutAndClose()
end

InnRecipeHudCtrl._CancelCloseAndReplayIn = HL.Method() << function(self)
    self.m_outAnimAsyncActionHelper:ForceClear()
    self.view.luaPanel:RecoverAllInput()
    self.animationWrapper:ClearTween(false)
    self:PlayAnimationIn()
end



InnRecipeHudCtrl._ContainsUniqueId = HL.StaticMethod(HL.Any, HL.Opt(HL.String)).Return(HL.Boolean) << function(ids, uniqueIdStr)
    if ids == nil then
        return false
    end
    for i = 0, ids.Count - 1 do
        if ids[i] == uniqueIdStr then
            return true
        end
    end
    return false
end

InnRecipeHudCtrl.IsConfiguredFactorySafeZone = HL.StaticMethod(HL.Opt(HL.String)).Return(HL.Boolean) << function(uniqueIdStr)
    return InnRecipeHudCtrl._ContainsUniqueId(Tables.innManagementConst.innRecipeHudFunctionAreaIds, uniqueIdStr)
end


InnRecipeHudCtrl.IsConfiguredInnSafeZone = HL.StaticMethod(HL.Opt(HL.String)).Return(HL.Boolean) << function(uniqueIdStr)
    return InnRecipeHudCtrl._ContainsUniqueId(Tables.innManagementConst.innFunctionAreaIds, uniqueIdStr)
end

InnRecipeHudCtrl._IsInAnyZone = HL.StaticMethod(HL.Function).Return(HL.Boolean) << function(predicate)
    for uniqueIdStr in pairs(InnRecipeHudCtrl.s_enteredZoneIds) do
        if predicate(uniqueIdStr) then
            return true
        end
    end
    return false
end

InnRecipeHudCtrl.OnEnterFactorySafeZone = HL.StaticMethod(HL.Table) << function(args)
    local uniqueIdStr = unpack(args)
    local isInnZone = InnRecipeHudCtrl.IsConfiguredInnSafeZone(uniqueIdStr)
    local isHudZone = InnRecipeHudCtrl.IsConfiguredFactorySafeZone(uniqueIdStr)
    if not isInnZone and not isHudZone then
        return
    end
    local wasInInnZone = InnRecipeHudCtrl._IsInAnyZone(InnRecipeHudCtrl.IsConfiguredInnSafeZone)
    InnRecipeHudCtrl.s_enteredZoneIds[uniqueIdStr] = true
    if isInnZone and not wasInInnZone then
        AudioManager.PostEvent("au_int_system_inn_enter_ui")
    end
    if isHudZone then
        InnRecipeHudCtrl._TryAutoOpen()
    end
end

InnRecipeHudCtrl.OnEnterFactoryMode = HL.StaticMethod() << function()
    InnRecipeHudCtrl._TryAutoOpenIfInHudZone()
end

InnRecipeHudCtrl.OnPhaseLevelOnTop = HL.StaticMethod() << function()
    InnRecipeHudCtrl._TryAutoOpenIfInHudZone()
end

InnRecipeHudCtrl._TryAutoOpenIfInHudZone = HL.StaticMethod() << function()
    if not InnRecipeHudCtrl._IsInAnyZone(InnRecipeHudCtrl.IsConfiguredFactorySafeZone) then
        return
    end
    InnRecipeHudCtrl._TryAutoOpen()
end

InnRecipeHudCtrl._TryAutoOpen = HL.StaticMethod() << function()
    if not Utils.isInFactoryMode() then
        return
    end
    if not UIUtils.IsPhaseLevelOnTop() then
        return
    end
    if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.InnManagement) then
        return
    end
    local unlockQuestId = Tables.innManagementConst.innRecipeHudUnlockQuestId
    if not string.isEmpty(unlockQuestId) and not GameInstance.player.mission:IsQuestCompleted(unlockQuestId) then
        return
    end
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen and ctrl:IsPlayingAnimationOut() then
        ctrl:_CancelCloseAndReplayIn()
        return
    end
    UIManager:AutoOpen(PANEL_ID)
end

InnRecipeHudCtrl.OnLeaveFactorySafeZone = HL.StaticMethod(HL.Table) << function(args)
    local uniqueIdStr = unpack(args)
    local isInnZone = InnRecipeHudCtrl.IsConfiguredInnSafeZone(uniqueIdStr)
    local isHudZone = InnRecipeHudCtrl.IsConfiguredFactorySafeZone(uniqueIdStr)
    if not isInnZone and not isHudZone then
        return
    end
    InnRecipeHudCtrl.s_enteredZoneIds[uniqueIdStr] = nil
    if isInnZone and not InnRecipeHudCtrl._IsInAnyZone(InnRecipeHudCtrl.IsConfiguredInnSafeZone) then
        AudioManager.PostEvent("au_int_system_inn_exit_ui")
    end
    if not isHudZone or InnRecipeHudCtrl._IsInAnyZone(InnRecipeHudCtrl.IsConfiguredFactorySafeZone) then
        return
    end
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if isOpen then
        ctrl:_CloseByWorldEvent()
    end
end



HL.Commit(InnRecipeHudCtrl)
