











FacBuildModeHandler = HL.Class('FacBuildModeHandler')

FacBuildModeHandler.m_host = HL.Field(HL.Forward('FacBuildModeCtrl'))

FacBuildModeHandler.m_args = HL.Field(HL.Table)






FacBuildModeHandler.m_provider = HL.Field(HL.Userdata)


FacBuildModeHandler.m_placementResult = HL.Field(HL.Table) << function() return {} end

FacBuildModeHandler.FacBuildModeHandler = HL.Constructor(HL.Forward('FacBuildModeCtrl')) << function(self, host)
    self.m_host = host
end






FacBuildModeHandler.OnEnter = HL.Virtual(HL.Table) << function(self, args)
    self.m_args = args
end


FacBuildModeHandler.OnPostEnter = HL.Virtual() << function(self)
end


FacBuildModeHandler.OnEnterRefreshNodes = HL.Virtual() << function(self)
end



FacBuildModeHandler.OnExit = HL.Virtual(HL.Table) << function(self, ctx)
end


FacBuildModeHandler.OnRequestExit = HL.Virtual(HL.Number, HL.Opt(HL.Boolean)).Return(HL.Boolean) << function(self, reason, skipAnim)
    return false
end


FacBuildModeHandler.GetEnterMessage = HL.Virtual().Return(HL.Opt(HL.Any)) << function(self)
    return nil
end

FacBuildModeHandler.GetEnterMessageArg = HL.Virtual().Return(HL.Opt(HL.Any)) << function(self)
    return nil
end

FacBuildModeHandler.GetExitMessage = HL.Virtual().Return(HL.Opt(HL.Any)) << function(self)
    return nil
end












FacBuildModeHandler.OnTick = HL.Virtual(HL.Table) << function(self, ctx)
    if ctx.sampleOk then
        self.m_provider:UpdatePreview(ctx.pointerWorldPos)
    end
end


FacBuildModeHandler.OnTickLocked = HL.Virtual() << function(self)
end


FacBuildModeHandler.OnPostTick = HL.Virtual(HL.Table) << function(self, ctx)
end



FacBuildModeHandler.EvaluatePlacement = HL.Virtual().Return(HL.Opt(HL.Table)) << function(self)
    local r = self:_ResetPlacementResult()
    r.valid = self.m_provider:IsPlacementValid()
    return r
end


FacBuildModeHandler.GetDragFollowInfo = HL.Virtual().Return(HL.Opt(HL.Table)) << function(self)
    local ok, pos = self.m_provider:TryGetPreviewPose()
    if not ok then
        return nil
    end
    local size = self.m_provider:GetPlacementWorldSize()
    local r = self.m_dragFollowInfo
    r.worldPos = pos
    r.worldSize = Vector3(size.x, 0, size.z) 
    return r
end

FacBuildModeHandler.m_dragFollowInfo = HL.Field(HL.Table) << function() return {} end







FacBuildModeHandler.OnPressScreen = HL.Virtual(HL.Table) << function(self, ctx)
    self.m_host:TryBeginDragOnPreview(ctx)
end


FacBuildModeHandler.GetDragHitInfo = HL.Virtual(Vector3).Return(HL.Opt(HL.Table)) << function(self, worldPos)
    local ok, pos = self.m_provider:TryGetPreviewPose()
    if not ok then
        return nil
    end
    local size = self.m_provider:GetPlacementWorldSize()
    local r = self.m_dragHitInfo
    r.centerPos = pos
    r.sizeXZ = Vector2(size.x, size.z)
    return r
end

FacBuildModeHandler.m_dragHitInfo = HL.Field(HL.Table) << function() return {} end


FacBuildModeHandler.OnDragRelease = HL.Virtual(Vector3) << function(self, worldPos)
    self.m_provider:EndTrace(worldPos)
end


FacBuildModeHandler.OnReleaseScreen = HL.Virtual(Vector3) << function(self, worldPos)
end


FacBuildModeHandler.OnTouchClickScreen = HL.Virtual() << function(self)
end







FacBuildModeHandler.OnConfirm = HL.Virtual() << function(self)
    self:_ConfirmCommon()
end

FacBuildModeHandler.CanRotate = HL.Virtual().Return(HL.Boolean) << function(self)
    return true
end

FacBuildModeHandler.OnRotate = HL.Virtual() << function(self)
    self.m_provider:SetRotation(self.m_provider:GetRotation() + 90)
end

FacBuildModeHandler.CanDelete = HL.Virtual().Return(HL.Boolean) << function(self)
    return false
end

FacBuildModeHandler.OnDelete = HL.Virtual() << function(self)
end


FacBuildModeHandler.CanStayOutOfMainRegion = HL.Virtual().Return(HL.Boolean) << function(self)
    return false
end







FacBuildModeHandler.GetAutoMoveCamSize = HL.Virtual().Return(Vector2) << function(self)
    return Vector2.one
end


FacBuildModeHandler.GetRecoverState = HL.Virtual().Return(HL.Opt(HL.Table)) << function(self)
    return nil
end


FacBuildModeHandler.GetDebugPosInfo = HL.Virtual().Return(HL.Opt(HL.Table)) << function(self)
    return nil
end


FacBuildModeHandler.OnBackendPlaceFinish = HL.Virtual() << function(self)
end


FacBuildModeHandler.OnConveyorLocalCheckFailed = HL.Virtual(HL.Table) << function(self, args)
end


FacBuildModeHandler.OnHideToggleChanged = HL.Virtual(HL.Boolean) << function(self, isOn)
end


FacBuildModeHandler.OnBuildingBatchMoved = HL.Virtual() << function(self)
end







FacBuildModeHandler._ConfirmCommon = HL.Method().Return(HL.Boolean) << function(self)
    local host = self.m_host
    host:TickOnce()
    if not host.m_curBuildIsValid then
        Notify(MessageConst.SHOW_TOAST, host.view.errorHintText.text)
        AudioAdapter.PostEvent("au_ui_fac_unbuildable")
        return false
    end
    local ok, worldPos = host:SamplePointerWorldPos()
    if ok then
        self.m_provider:Submit(worldPos)
    end
    return true
end


FacBuildModeHandler._ResetPlacementResult = HL.Method().Return(HL.Table) << function(self)
    local r = self.m_placementResult
    r.valid = false
    r.errorHint = nil
    r.actionHint = nil
    r.actionColor = nil
    r.warningHint = nil
    r.normalHint = nil
    r.actionHintIsStatic = nil
    return r
end




HL.Commit(FacBuildModeHandler)
