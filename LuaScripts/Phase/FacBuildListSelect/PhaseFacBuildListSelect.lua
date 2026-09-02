local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.FacBuildListSelect
PhaseFacBuildListSelect = HL.Class('PhaseFacBuildListSelect', phaseBase.PhaseBase)

local ReservePanelIds = {  
    PanelId.FacQuickBar,
    PanelId.FacHudBottomMask,
}





PhaseFacBuildListSelect.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.OPEN_FAC_BUILD_MODE_SELECT] = { '_OnOpenFacBuildModeSelect', false },
}


PhaseFacBuildListSelect.m_radioTagHandle = HL.Field(HL.Any)

PhaseFacBuildListSelect.m_hidePanelKey = HL.Field(HL.Number) << -1

PhaseFacBuildListSelect.m_resolvedOnlyCraftNode = HL.Field(HL.Any)

PhaseFacBuildListSelect.m_resolvedBluePrintData = HL.Field(HL.Table)



PhaseFacBuildListSelect._OnInit = HL.Override() << function(self)
    PhaseFacBuildListSelect.Super._OnInit(self)
    
    self:_ApplyResolvedArg(self.arg, false)
    
    self.m_radioTagHandle = GameInstance.player.globalTagsSystem:AddGlobalTag(CS.Beyond.Gameplay.GlobalTagDefine.notStopRadioTags)
end



PhaseFacBuildListSelect._ApplyResolvedArg = HL.Method(HL.Any, HL.Boolean) << function(self, incomingArg, isRefresh)
    local arg = incomingArg and lume.deepCopy(incomingArg) or {}
    if arg.onlyCraftNode ~= nil or arg.bluePrintData ~= nil then
        
    elseif isRefresh then
        
        arg.onlyCraftNode = self.m_resolvedOnlyCraftNode
        arg.bluePrintData = self.m_resolvedBluePrintData
    else
        
        local topPhaseId = PhaseManager:GetTopPhaseId()
        if topPhaseId ~= PhaseId.FacMachine and topPhaseId ~= PhaseId.Inventory then
            arg.onlyCraftNode = true
        end
    end
    self.arg = arg
    self.m_resolvedOnlyCraftNode = arg.onlyCraftNode
    self.m_resolvedBluePrintData = arg.bluePrintData
end




PhaseFacBuildListSelect.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        if anotherPhaseId == PhaseId.Level then
            Notify(MessageConst.SET_PHASE_LEVEL_TRANSITION_RESERVE_PANELS, ReservePanelIds)
        end
    end
end

PhaseFacBuildListSelect._IsOnlyCraftNode = HL.Method().Return(HL.Boolean) << function(self)
    local arg = self.arg
    return arg ~= nil and (arg.onlyCraftNode or arg.bluePrintData ~= nil)
end

PhaseFacBuildListSelect._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if not self:_IsOnlyCraftNode() then
        self.m_hidePanelKey = UIManager:ClearScreen({ PanelId.FacBuildListSelect })
    end
end

PhaseFacBuildListSelect._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseFacBuildListSelect._DoPhaseTransitionOutAfterItems = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)
end


PhaseFacBuildListSelect._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseFacBuildListSelect._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args) end






PhaseFacBuildListSelect._OnActivated = HL.Override() << function(self)
    if not self.m_radioTagHandle then
        self.m_radioTagHandle = GameInstance.player.globalTagsSystem:AddGlobalTag(CS.Beyond.Gameplay.GlobalTagDefine.notStopRadioTags)
    end
end

PhaseFacBuildListSelect._OnDeActivated = HL.Override() << function(self)
    if self.m_radioTagHandle then
        
        
        TimerManager:StartFrameTimer(2, function()
            self.m_radioTagHandle:RemoveTag()
            self.m_radioTagHandle = nil
        end)
    end
end

PhaseFacBuildListSelect._OnDestroy = HL.Override() << function(self)
    PhaseFacBuildListSelect.Super._OnDestroy(self)
end



PhaseFacBuildListSelect._OnRefresh = HL.Override() << function(self)
    
    self:_ApplyResolvedArg(self.arg, true)
    PhaseFacBuildListSelect.Super._OnRefresh(self)
end

PhaseFacBuildListSelect.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = self.arg and lume.deepCopy(self.arg) or {}
    local item = self.m_panel2Item[PanelId.FacBuildListSelect]
    if item and item.uiCtrl then
        arg.recoverState = item.uiCtrl:GetRecoverStateArg()
    end
    return arg
end

PhaseFacBuildListSelect._OnOpenFacBuildModeSelect = HL.StaticMethod(HL.Opt(HL.Any)) << function(arg)
    
    PhaseManager:GoToPhase(PHASE_ID, arg)
end

HL.Commit(PhaseFacBuildListSelect)
