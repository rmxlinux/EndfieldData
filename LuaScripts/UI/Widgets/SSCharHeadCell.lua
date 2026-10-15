local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

SSCharHeadCell = HL.Class('SSCharHeadCell', UIWidgetBase)


SSCharHeadCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.infoButton.onClick:AddListener(function()
        self:ShowTips()
    end)

    self.view.button.onIsNaviTargetChanged = function(isTarget)
        if isTarget then
            Notify(MessageConst.ON_SPACESHIP_HEAD_NAVI_TARGET_CHANGE, self)
        end
    end
    self.view.button.onClick:AddListener(function()
        self:_OnClick()
    end)

    if self.view.config.SHOW_TIPS_ON_HOVER_DELAY >= 0 then
        self.view.button.onHoverChange:AddListener(function(isEnter)
            self.m_hoverTipsTimerId = self:_ClearTimer(self.m_hoverTipsTimerId)
            if isEnter then
                self.m_hoverTipsTimerId = self:_StartTimer(self.view.config.SHOW_TIPS_ON_HOVER_DELAY, function()
                    self:ShowTips(nil, nil, true)
                end)
            else
                Notify(MessageConst.HIDE_SPACESHIP_CHAR_TIPS, {
                    key = self.transform,
                    isHover = true,
                })
            end
        end)
    end

    self.view.chooseNode.gameObject:SetActive(false)

    self.m_skillCells = UIUtils.genCellCache(self.view.skillCell)
    self.m_groupABTxt = self.view.groupNode.transform:Find("ABTxt"):GetComponent("UIText")

    self:RegisterMessage(MessageConst.HIDE_SPACESHIP_CHAR_TIPS_DONE, function()
        self:SetSelectState(false)
    end)
end

SSCharHeadCell.m_hoverTipsTimerId = HL.Field(HL.Number) << -1

SSCharHeadCell.ShowTips = HL.Method(HL.Opt(HL.Any, HL.Any, HL.Boolean)) << function(self, posType, padding, isHover)
    Notify(MessageConst.SHOW_SPACESHIP_CHAR_TIPS, {
        key = self.transform,
        isHover = isHover,
        charId = self.m_charId,
        targetRoomId = self.m_args.targetRoomId,
        tmpSafeArea = self.transform,
        transform = self.m_tipsPositionTrans or self.transform,
        posType = posType or self.m_args.posType,
        padding = padding or self.m_args.padding,
        blockOtherInput = true
    })
    self:SetSelectState(true)
end


SSCharHeadCell.m_charId = HL.Field(HL.String) << ''

SSCharHeadCell.m_args = HL.Field(HL.Table)

SSCharHeadCell.m_tipsPositionTrans = HL.Field(CS.UnityEngine.Transform)

SSCharHeadCell.m_skillCells = HL.Field(HL.Forward('UIListCache'))

SSCharHeadCell.m_groupABTxt = HL.Field(HL.Any)









SSCharHeadCell.InitSSCharHeadCell = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.m_args = args

    local charId = args.charId
    self.m_charId = charId
    self.m_tipsPositionTrans = args.tipsPositionTrans
    SpaceshipUtils.updateSSCharInfos(self.view, charId, args.targetRoomId, nil, args.disableFunc)
    local spaceship = GameInstance.player.spaceship
    if args.hideStaminaNode and not spaceship.isViewingFriend then
        self.view.staminaNode.gameObject:SetActive(false)
    end

    if args.showBufTag and self.view.buffNode ~= nil then
        self.view.buffNode.gameObject:SetActive(true)
    elseif self.view.buffNode ~= nil then
        self.view.buffNode.gameObject:SetActive(false)
    end

    local succ, char = spaceship.characters:TryGetValue(charId)
    if succ then
        local roomType = SpaceshipUtils.getRoomTypeByRoomId(args.targetRoomId)
        local skillCount = char.skills.Count
        local indexList = char:GetSkillIndexList()
        self.m_skillCells:Refresh(skillCount, function(cell, index)
            local skillId = char.skills[indexList[CSIndex(index)]]
            local skillData = Tables.spaceshipSkillTable[skillId]
            cell.icon:LoadSprite(UIConst.UI_SPRITE_SS_SKILL_ICON, skillData.icon)
            cell.inactive.gameObject:SetActive(skillData.roomType ~= roomType)
        end)
    end

    if args.showGiftInfo ~= nil and args.showGiftInfo > 0 then
        self.view.giftNode.gameObject:SetActive(true)
    else
        self.view.giftNode.gameObject:SetActive(false)
    end
    self:_UpdateGroupNode(args, char)
end

SSCharHeadCell._UpdateGroupNode = HL.Method(HL.Table, HL.Opt(HL.Any)) << function(self, args, char)
    self:_SetGroupTeamType(char)
end

SSCharHeadCell._SetGroupTeamType = HL.Method(HL.Opt(HL.Any)) << function(self, char)
    local TeamType = CS.Proto.SpaceshipCharTeamType
    local roomId = char.stationedRoomId
    local scheduleEnabled = SpaceshipUtils.isScheduleUnlocked()
        and SpaceshipUtils.isRoomScheduleSupported(roomId)
        and not SpaceshipUtils.isSingleTeamMode(roomId)
    local teamType = char.teamType
    self.m_groupABTxt.color = not string.isEmpty(roomId) and SpaceshipUtils.getRoomColor(roomId) or Color.white
    if not scheduleEnabled then
        teamType = nil
    end
    if teamType == TeamType.A then
        self.view.groupNode:SetState("A")
    elseif teamType == TeamType.B then
        self.view.groupNode:SetState("B")
    else
        self.view.groupNode:SetState("Single")
    end
end

SSCharHeadCell._OnClick = HL.Method() << function(self)
    if self.m_args.onClick then
        self.m_args.onClick()
    end
end


SSCharHeadCell.SetChooseState = HL.Method(HL.Any) << function(self, state)
    if not state then
        self.view.chooseNode.gameObject:SetActive(false)
        return
    end
    self.view.chooseNode.gameObject:SetActive(true)
    if state == true then
        self.view.chooseIcon.gameObject:SetActive(true)
        self.view.chooseIndexTxt.gameObject:SetActive(false)
    else 
        self.view.chooseIcon.gameObject:SetActive(false)
        self.view.chooseIndexTxt.gameObject:SetActive(true)
        self.view.chooseIndexTxt.text = state
    end
end

SSCharHeadCell.SetSelectState = HL.Method(HL.Boolean) << function(self, state)
    self.view.selectNode.gameObject:SetActive(state)
end


SSCharHeadCell.UpdateSSCharPreStamina = HL.Method(HL.Any) << function(self, preAddStamina)
    SpaceshipUtils.updateSSCharPreStamina(self.view.staminaNode, self.m_charId, preAddStamina)
end

HL.Commit(SSCharHeadCell)
return SSCharHeadCell
