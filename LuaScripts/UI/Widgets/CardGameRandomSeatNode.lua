local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local CardGameAnimQueue = require_ex('LuaSystem/CardGame/CardGameAnimQueue')

local MAX_SEAT_COUNT = 4




CardGameRandomSeatNode = HL.Class('CardGameRandomSeatNode', UIWidgetBase)



CardGameRandomSeatNode.m_seatIndexList = HL.Field(HL.Table)
CardGameRandomSeatNode.m_animQueue = HL.Field(CardGameAnimQueue)
CardGameRandomSeatNode.m_onPlayEnd = HL.Field(HL.Function)
CardGameRandomSeatNode.m_isPlaying = HL.Field(HL.Boolean) << false

CardGameRandomSeatNode.m_playId = HL.Field(HL.Number) << 0
CardGameRandomSeatNode.m_rotateTimerId = HL.Field(HL.Number) << -1




CardGameRandomSeatNode._OnFirstTimeInit = HL.Override() << function(self)
    self.m_animQueue = CardGameAnimQueue()
end


CardGameRandomSeatNode.InitCardGameRandomSeatNode = HL.Method(HL.Table) << function(self, seatIndexList)
    self:_FirstTimeInit()
    self:Stop(false)
    self.m_seatIndexList = seatIndexList
    local activeSet = {}
    for _, seatIndex in ipairs(seatIndexList) do
        activeSet[seatIndex] = true
    end
    for seatIndex = 1, MAX_SEAT_COUNT do
        self:_GetSeatNode(seatIndex).gameObject:SetActive(activeSet[seatIndex] == true)
    end
end




CardGameRandomSeatNode.SetSeatPlayer = HL.Method(HL.Number, HL.Table) << function(self, seatIndex, playerInfo)
    local basicInfoNode = self:_GetSeatNode(seatIndex).basicInfoNode
    local displayInfo = playerInfo.displayInfo
    basicInfoNode.stateController:SetState(playerInfo.isSelf and "Self" or displayInfo.isAI and "Ai" or "None")
    basicInfoNode.seatIcon:LoadSprite(string.format(UIConst.UI_SPRITE_CARD_GAME_SEAT_INDEX_ICON_FMT, playerInfo.seatIndex))
    
    local playerCell = basicInfoNode.multiplayerPlayerCell
    CardGameUtils.InitMultiplayerPlayerCellBasic(playerCell, displayInfo)
    playerCell.view.playerHead:SetClick(false)
    CardGameUtils.SyncPlayerHeadTargetGraphic(playerCell.view.playerHead)
end


CardGameRandomSeatNode.Play = HL.Method(HL.Number, HL.Opt(HL.Function)) << function(self, finalSeatIndex, onPlayEnd)
    self:Stop(false)
    local finalPos = lume.find(self.m_seatIndexList, finalSeatIndex)
    if finalPos == nil then
        logger.error("CardGameRandomSeatNode.Play: finalSeatIndex 不在启用座位里: " .. tostring(finalSeatIndex))
        finalPos = 1
    end
    self.m_isPlaying = true
    self.m_onPlayEnd = onPlayEnd
    self:_ResetToStart()
    self.gameObject:SetActive(true)

    local view = self.view
    local centerNode = view.centerNode
    local finalSeatNode = self:_GetSeatNode(self.m_seatIndexList[finalPos])
    self:_EnqueueAnim(function(finish)
        view.animationWrapper:PlayInAnimation(finish)
    end)
    self:_EnqueueAnim(function(finish)
        centerNode.stateController:SetState("PointRandom")
        centerNode.pointNormalAniWrapper:PlayLoopAnimation()
        self:_PlayRotate(finalPos, finish)
    end)
    self:_EnqueueAnim(function(finish)
        centerNode.pointNormalAniWrapper:ClearTween(false)
        centerNode.stateController:SetState("PointTo" .. self.m_seatIndexList[finalPos])
        finalSeatNode.animationWrapper:PlayInAnimation(finish)
    end)
    self:_EnqueueAnim(function(finish)
        view.animationWrapper:PlayOutAnimation(finish)
    end)
    self:_EnqueueAnim(function(finish)
        finish()
        self:_End(true)
    end)
end


CardGameRandomSeatNode.Stop = HL.Method(HL.Boolean) << function(self, isTriggerPlayEnd)
    if self.m_animQueue then
        self.m_animQueue:Clear(false, false)
    end
    self:_End(isTriggerPlayEnd)
end

CardGameRandomSeatNode.IsPlaying = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isPlaying
end



CardGameRandomSeatNode._GetSeatNode = HL.Method(HL.Number).Return(HL.Any) << function(self, seatIndex)
    return self.view["seatNode" .. seatIndex]
end


CardGameRandomSeatNode._EnqueueAnim = HL.Method(HL.Function) << function(self, action)
    local playId = self.m_playId
    self.m_animQueue:Enqueue(function(finish)
        action(function()
            if playId == self.m_playId then
                finish()
            end
        end)
    end)
end


CardGameRandomSeatNode._ResetToStart = HL.Method() << function(self)
    for _, seatIndex in ipairs(self.m_seatIndexList) do
        local seatNode = self:_GetSeatNode(seatIndex)
        seatNode.stateController:SetState("NotTarget")
        seatNode.animationWrapper:SampleToInAnimationBegin()
    end
    self.view.centerNode.stateController:SetState("PointTo4")
    self.view.animationWrapper:SampleToInAnimationBegin()
end


CardGameRandomSeatNode._PlayRotate = HL.Method(HL.Number, HL.Function) << function(self, finalPos, onDone)
    local config = self.view.config
    local seatCount = #self.m_seatIndexList
    local curPos = math.random(1, seatCount)
    local stepCount = (finalPos - curPos) % seatCount
    while stepCount < config.ROTATE_MIN_STEP_COUNT do
        stepCount = stepCount + seatCount
    end

    
    local intervals = {}
    local weightSum = 0
    for i = 1, stepCount do
        local progress = stepCount > 1 and (i - 1) / (stepCount - 1) or 0
        intervals[i] = 1 + (config.ROTATE_SLOW_RATIO - 1) * progress
        weightSum = weightSum + intervals[i]
    end
    for i = 1, stepCount do
        intervals[i] = config.ROTATE_DURATION * intervals[i] / weightSum
    end

    self:_SetCurTarget(curPos)
    local stepIndex = 0
    local playId = self.m_playId
    local playNextStep
    playNextStep = function()
        
        if playId ~= self.m_playId then
            return
        end
        self.m_rotateTimerId = -1
        if stepIndex >= stepCount then
            onDone()
            return
        end
        stepIndex = stepIndex + 1
        self.m_rotateTimerId = self:_StartTimer(intervals[stepIndex], function()
            curPos = curPos % seatCount + 1
            self:_SetCurTarget(curPos)
            playNextStep()
        end, true)
    end
    playNextStep()
end

CardGameRandomSeatNode._SetCurTarget = HL.Method(HL.Number) << function(self, targetPos)
    for pos, seatIndex in ipairs(self.m_seatIndexList) do
        self:_GetSeatNode(seatIndex).stateController:SetState(pos == targetPos and "CurTarget" or "NotTarget")
    end
end


CardGameRandomSeatNode._End = HL.Method(HL.Boolean) << function(self, isTriggerPlayEnd)
    self.m_playId = self.m_playId + 1
    if self.m_rotateTimerId >= 0 then
        self.m_rotateTimerId = self:_ClearTimer(self.m_rotateTimerId)
    end
    if self.m_isPlaying then
        local view = self.view
        view.animationWrapper:ClearTween(false)
        view.centerNode.pointNormalAniWrapper:ClearTween(false)
        for _, seatIndex in ipairs(self.m_seatIndexList) do
            self:_GetSeatNode(seatIndex).animationWrapper:ClearTween(false)
        end
    end
    self.m_isPlaying = false
    if not self.m_isDestroyed then
        self.gameObject:SetActive(false)
    end
    local onPlayEnd = self.m_onPlayEnd
    self.m_onPlayEnd = nil
    if isTriggerPlayEnd and onPlayEnd then
        onPlayEnd()
    end
end


HL.Commit(CardGameRandomSeatNode)
return CardGameRandomSeatNode
