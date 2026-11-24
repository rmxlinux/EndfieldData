

CardGameCard = HL.Class('CardGameCard')

CardGameCard.uid = HL.Field(HL.Number) << 0
CardGameCard.faceUp = HL.Field(HL.Boolean) << false
CardGameCard.go = HL.Field(GameObject)
CardGameCard.transform = HL.Field(Transform)
CardGameCard.regionId = HL.Field(HL.String) << ""
CardGameCard.indexInRegion = HL.Field(HL.Number) << 0
CardGameCard.selected = HL.Field(HL.Boolean) << false
CardGameCard.focused = HL.Field(HL.Boolean) << false
CardGameCard.pendingSelected = HL.Field(HL.Boolean) << false

CardGameCard.m_visual = HL.Field(CS.Beyond.UI.CardGamePokerVisual)
CardGameCard.m_entityRenderHelper = HL.Field(CS.Beyond.Gameplay.View.EntityRenderHelper)

CardGameCard.CardGameCard = HL.Constructor(HL.Number, GameObject) << function(self, uid, go)
    self.uid = uid
    self:BindGameObject(go)
end




CardGameCard.BindGameObject = HL.Method(GameObject) << function(self, go)
    if IsNull(go) then
        error("CardGameCard.BindGameObject: go is null, uid=" .. tostring(self.uid))
    end
    self.go = go
    self.transform = go.transform
    self.m_visual = go:GetComponent(typeof(CS.Beyond.UI.CardGamePokerVisual))
    self.m_entityRenderHelper = go:GetComponent(typeof(CS.Beyond.Gameplay.View.EntityRenderHelper))
    self.selected = false
    self.focused = false
    self.pendingSelected = false
    self.m_visual:SetInteractionState(false, false, false)
end


CardGameCard.SetCardData = HL.Method(HL.Number, HL.Number) << function(self, suit, rank)
    self.m_visual:SetCardData(suit, rank)
end



CardGameCard.SetCardStyle = HL.Method(HL.String) << function(self, style)
    self.m_visual:SetCardStyle(style)
end



CardGameCard.SetPokerData = HL.Method(HL.Number, HL.Number, HL.String) << function(self, suit, rank, style)
    self.m_visual:SetPokerData(suit, rank, style)
end


CardGameCard.SetFace = HL.Method(HL.Boolean) << function(self, faceUp)
    self.faceUp = faceUp
    self.m_visual:SetFace(faceUp)
end



CardGameCard.SetInteractionState = HL.Method(HL.Boolean, HL.Boolean, HL.Opt(HL.Boolean)) << function(self, selected, focused, pendingSelected)
    self.selected = selected
    self.focused = focused
    self.pendingSelected = pendingSelected == true
    self.m_visual:SetInteractionState(selected, focused, self.pendingSelected)
end

CardGameCard.GetCardRenderer = HL.Method().Return(CS.UnityEngine.MeshRenderer) << function(self)
    return self.m_visual.cardRenderer
end


CardGameCard.SetInteractionSortingOrder = HL.Method(HL.Number) << function(self, sortingOrder)
    self.m_visual:SetInteractionSortingOrder(sortingOrder)
end


CardGameCard.ApplyPose = HL.Method(HL.Table) << function(self, pose)
    if not pose then
        return
    end
    self.m_visual:ApplyPoseLcs(pose.root, pose.localPosition, pose.localEulerAngles, pose.localScale, self.faceUp)
end


CardGameCard.PlayMoveToPose = HL.Method(HL.Table, HL.Opt(HL.Function, HL.Boolean, HL.Number))
        << function(self, pose, onComplete, useLift, duration)
    local finish = function()
        if onComplete then
            onComplete()
        end
    end
    local durationOverride = duration or -1
    if useLift == false then
        self.m_visual:PlayMoveScaleAnimLcs(pose.root, pose.localPosition,
                pose.localEulerAngles, pose.localScale, finish, durationOverride)
    else
        self.m_visual:PlayMoveLiftScaleAnimLcs(pose.root, pose.localPosition,
                pose.localEulerAngles, pose.localScale, finish, durationOverride)
    end
end


CardGameCard.PlayMoveFlipToPose = HL.Method(HL.Table, HL.Boolean,
        HL.Opt(HL.Function, HL.Boolean, HL.Number))
        << function(self, pose, finalFaceUp, onComplete, useLift, duration)
    self.faceUp = finalFaceUp

    local finish = function()
        if onComplete then
            onComplete()
        end
    end
    local durationOverride = duration or -1
    if useLift == false then
        self.m_visual:PlayMoveFlipAnimLcs(pose.root, pose.localPosition,
                pose.localEulerAngles, pose.localScale, finalFaceUp, finish, durationOverride)
    else
        self.m_visual:PlayMoveFlipLiftAnimLcs(pose.root, pose.localPosition,
                pose.localEulerAngles, pose.localScale, finalFaceUp, finish, durationOverride)
    end
end


CardGameCard.PlayRotate = HL.Method(HL.Any, HL.Opt(HL.Function, HL.Number))
        << function(self, euler, onComplete, duration)
    local finish = function()
        if onComplete then
            onComplete()
        end
    end
    self.m_visual:PlayRotateAnim(euler, finish, duration or -1)
end


CardGameCard.KillAnim = HL.Method(HL.Opt(HL.Boolean, HL.Boolean)) << function(self, complete, applyEndPose)
    self.m_visual:KillAnim(complete == true, applyEndPose == true)
end



CardGameCard.PlayVfx = HL.Method(HL.String) << function(self, vfxName)
    if IsNull(self.m_entityRenderHelper) then
        return
    end
    self.m_entityRenderHelper:ReFindRenderersInChildren()
    self.m_entityRenderHelper:Play(vfxName)
end


CardGameCard.ResetVfx = HL.Method() << function(self)
    if IsNull(self.m_entityRenderHelper) then
        return
    end
    self.m_entityRenderHelper:Reset()
end


CardGameCard.GetVfxStartTime = HL.Method(HL.String).Return(HL.Number) << function(self, vfxName)
    if IsNull(self.m_entityRenderHelper) then
        return -1
    end
    return self.m_entityRenderHelper:GetStartTime(vfxName)
end

HL.Commit(CardGameCard)
return CardGameCard
