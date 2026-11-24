local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local FLIP_MAX_ANGLE = 90
local FACE_FLIP_MAX_ANGLE = 180

CardGame2DPoker = HL.Class('CardGame2DPoker', UIWidgetBase)


CardGame2DPoker.uid = HL.Field(HL.Number) << 0
CardGame2DPoker.faceUp = HL.Field(HL.Boolean) << false
CardGame2DPoker.m_moveAniUpdateKey = HL.Field(HL.Number) << -1
CardGame2DPoker.m_rotateAniUpdateKey = HL.Field(HL.Number) << -1




CardGame2DPoker._OnFirstTimeInit = HL.Override() << function(self)
end

CardGame2DPoker.InitCardGame2DPoker = HL.Method(HL.Number) << function(self, uid)
    self:_FirstTimeInit()
    self.uid = uid
end

CardGame2DPoker._OnDestroy = HL.Override() << function(self)
    self:ClearAni()
end




CardGame2DPoker.SetCardSuitRankStyle = HL.Method(HL.Number, HL.Number, HL.String) << function(self, suit, rank, style)
    self.view.pokerVisual:SetPokerData(suit, rank, style)
end



CardGame2DPoker.SetCardSuitRank = HL.Method(HL.Number, HL.Number) << function(self, suit, rank)
    self.view.pokerVisual:SetRankAndSuit(suit, rank)
end


CardGame2DPoker.SetCardStyle = HL.Method(HL.String) << function(self, style)
    self.view.pokerVisual:SetCardStyle(style)
end


CardGame2DPoker.SetFace = HL.Method(HL.Boolean) << function(self, faceUp)
    self.faceUp = faceUp
    self.view.rotateAniRoot.localEulerAngles = Vector3(0, faceUp and 0 or 180, 0)
    self.view.cardFaceImg.gameObject:SetActive(faceUp)
    
end


CardGame2DPoker.SetPokerContentVisible = HL.Method(HL.Boolean) << function(self, visible)
    self.view.visualRoot.gameObject:SetActive(visible)
end

CardGame2DPoker.GetHandoffRectTransform = HL.Method().Return(RectTransform) << function(self)
    return self.view.rectTransform
end


CardGame2DPoker.GetHandoffPositionRectTransform = HL.Method().Return(RectTransform) << function(self)
    return self.view.visualRoot
end





CardGame2DPoker.ClearAni = HL.Method() << function(self)
    self:ClearMoveAni()
    self:ClearRotateAni()
end

CardGame2DPoker.ClearMoveAni = HL.Method() << function(self)
    self.m_moveAniUpdateKey = LuaUpdate:Remove(self.m_moveAniUpdateKey)
end

CardGame2DPoker.ClearRotateAni = HL.Method() << function(self)
    self.m_rotateAniUpdateKey = LuaUpdate:Remove(self.m_rotateAniUpdateKey)
end



CardGame2DPoker.PlayPokerChangeFlipAni = HL.Method(HL.Number, HL.Number, HL.String, HL.Opt(HL.Function))
    << function(self, suit, rank, style, onPlayEnd)
    
    
    
    
    
    self:ClearRotateAni()

    local duration = self.config.CARD_FLIP_ANI_TIME
    local curve = self.config.CARD_CHANGE_FLIP_ANI_CURVE

    local elapsed = 0
    local halfApplied = false
    self:_SetPokerFlipYAngle(curve:Evaluate(0))
    self.m_rotateAniUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        elapsed = elapsed + deltaTime
        local normalizedTime = math.min(elapsed / duration, 1)
        self:_SetPokerFlipYAngle(curve:Evaluate(normalizedTime))
        if not halfApplied and normalizedTime >= 0.5 then
            halfApplied = true
            self:SetCardSuitRankStyle(suit, rank, style)
        end
        if normalizedTime >= 1 then
            self:ClearRotateAni()
            if onPlayEnd then
                onPlayEnd()
            end
        end
    end)
end



CardGame2DPoker.PlayPokerFaceFlipAni = HL.Method(HL.Boolean, HL.Opt(HL.Function)) << function(self, upToDown, onPlayEnd)
    
    
    
    
    self:ClearRotateAni()
    self:SetFace(upToDown)

    local duration = self.config.CARD_FLIP_ANI_TIME
    local curve = self.config.CARD_FACE_FLIP_ANI_CURVE
    local startY = upToDown and 0 or 180
    local rotateSign = upToDown and 1 or -1

    local elapsed = 0
    local halfApplied = false
    self.view.rotateAniRoot.localEulerAngles = Vector3(0, startY + rotateSign * curve:Evaluate(0) * FACE_FLIP_MAX_ANGLE, 0)
    self.m_rotateAniUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        elapsed = elapsed + deltaTime
        local normalizedTime = math.min(elapsed / duration, 1)
        local y = startY + rotateSign * curve:Evaluate(normalizedTime) * FACE_FLIP_MAX_ANGLE
        self.view.rotateAniRoot.localEulerAngles = Vector3(0, y, 0)
        if not halfApplied and normalizedTime >= 0.5 then
            halfApplied = true
            local faceUp = not upToDown
            self.faceUp = faceUp
            self.view.cardFaceImg.gameObject:SetActive(faceUp)
        end
        if normalizedTime >= 1 then
            self:ClearRotateAni()
            if onPlayEnd then
                onPlayEnd()
            end
        end
    end)
end

CardGame2DPoker._SetPokerFlipYAngle = HL.Method(HL.Number) << function(self, normalizedAngle)
    self.view.rotateAniRoot.localEulerAngles = Vector3(0, normalizedAngle * FLIP_MAX_ANGLE, 0)
end




CardGame2DPoker.PlayMovePokerRootTo = HL.Method(RectTransform, Vector2, HL.Opt(HL.Function)) << function(self, target, targetPos, onPlayEnd)
    
    
    self:ClearMoveAni()

    local duration = self.config.CARD_MOVE_ANI_TIME
    local aniRootTrans = self.view.moveAniRoot.transform
    local startRootPos = aniRootTrans.position

    local elapsed = 0
    self.m_moveAniUpdateKey = LuaUpdate:Add("Tick", function(deltaTime)
        elapsed = elapsed + deltaTime
        local normalizedTime = math.min(elapsed / duration, 1)
        if IsNull(target) then
            return
        end
        local endRootPos = target:TransformPoint(Vector3(targetPos.x, targetPos.y, 0))
        aniRootTrans.position = Vector3.Lerp(startRootPos, endRootPos, normalizedTime)
        if normalizedTime >= 1 then
            self:ClearMoveAni()
            if onPlayEnd then
                onPlayEnd()
            end
        end
    end)
end

CardGame2DPoker.SetPokerMoveRootPos = HL.Method(RectTransform, Vector2) << function(self, target, targetPos)
    self:ClearMoveAni()
    self.view.moveAniRoot.position = target:TransformPoint(Vector3(targetPos.x, targetPos.y, 0))
end




HL.Commit(CardGame2DPoker)
return CardGame2DPoker

