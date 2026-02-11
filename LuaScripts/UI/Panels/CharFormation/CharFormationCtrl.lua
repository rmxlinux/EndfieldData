local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharFormation

local BTN_ANIM_NAME = {
    BTN_FORMATION_MIXCONFIRM_IN = "btn_formation_mixconfirm_in",
    BTN_FORMATION_MIXCONFIRM_OUT = "btn_formation_mixconfirm_out",
    BTN_FORMATION_REMOV_IN = "btn_formation_remov_in",
    BTN_FORMATION_REMOV_OUT = "btn_formation_remov_out",
    BTN_EMPTY_IN = "btn_empty_in",
    BTN_EMPTY_OUT = "btn_empty_out",
}

local ActionOnSetNaviTarget = CS.Beyond.Input.ActionOnSetNaviTarget
local CHAR_FORMATION_BLOCK_OBTAIN_WAYS_JUMP = "CharFormationBlockObtainWaysJump"






































































CharFormationCtrl = HL.Class('CharFormationCtrl', uiCtrl.UICtrl)










CharFormationCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.CHANGE_ACTIVE_SQUAD] = '_OnActiveSquadChange',
}


CharFormationCtrl.m_teamCells = HL.Field(HL.Forward("UIListCache"))


CharFormationCtrl.m_curTeamIndex = HL.Field(HL.Number) << -1


CharFormationCtrl.m_teamSet = HL.Field(HL.Number) << -1


CharFormationCtrl.preState = HL.Field(HL.Number) << -1


CharFormationCtrl.state = HL.Field(HL.Number) << -1


CharFormationCtrl.singleState = HL.Field(HL.Number) << -1


CharFormationCtrl.m_index2Char = HL.Field(HL.Table)


CharFormationCtrl.m_singleCharIndex = HL.Field(HL.Number) << -1


CharFormationCtrl.m_singleCharInfo = HL.Field(HL.Table)


CharFormationCtrl.m_genStars = HL.Field(HL.Forward('UIListCache'))


CharFormationCtrl.m_charTagCellCache = HL.Field(HL.Forward('UIListCache'))


CharFormationCtrl.m_empty = HL.Field(HL.Boolean) << false


CharFormationCtrl.m_dungeonId = HL.Field(HL.Any)


CharFormationCtrl.m_enterDungeonCallback = HL.Field(HL.Function)



CharFormationCtrl.m_weekRaidArg = HL.Field(HL.Table)


CharFormationCtrl.m_curSelectTakeItemCount = HL.Field(HL.Number) << 0









CharFormationCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self:_ProcessArgs(args)
    self:_InitController()
    self:_UpdateWeekRaid()
    self.view.bannerMidNode.gameObject:SetActive(false)
end




CharFormationCtrl.OnPhaseRefresh = HL.Override(HL.Any) << function(self, args)
    self:_ProcessArgs(args)
end



CharFormationCtrl.OnShow = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_open")
    
    if self.m_singleCharInfo then
        self:RefreshCharInformation(self.m_singleCharInfo)
    end

    if self.m_isCharInfoNaviGroupFocused then
        self.view.charInfoNaviGroup:ManuallyFocus(false)
        self:_StartCoroutine(function()
            
            coroutine.wait(0.3)
            UIUtils.setAsNaviTarget(self.view.charInformation.charFormationTacticalItem.view.btnItem)
        end)
    end
end



CharFormationCtrl.OnHide = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_close")

    if self.m_isCharInfoNaviGroupFocused then
        self.view.charInfoNaviGroup:ManuallyStopFocus(false)
        Notify(MessageConst.CHAR_INFO_CLOSE_ATTR_TIP)
        Notify(MessageConst.CHAR_INFO_CLOSE_SKILL_TIP)
        Notify(MessageConst.CHAR_INFO_CLOSE_INFO_TIP)
        InputManagerInst:ToggleBinding(self.m_equipTacticalItemBindingId, false)
        self.m_isCharInfoNaviGroupFocused = true
    end
end



CharFormationCtrl.OnClose = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_menu_formation_close")
    AudioAdapter.PostEvent("Au_UI_Menu_CharFormationPanel_Close")

    if not string.isEmpty(self.m_dungeonId) or self.m_weekRaidArg then
        UIManager:ToggleBlockObtainWaysJump(CHAR_FORMATION_BLOCK_OBTAIN_WAYS_JUMP, false)
    end
end







CharFormationCtrl._OnChangeTeamNameClicked = HL.Method() << function(self)
    local team = GameInstance.player.charBag.teamList[CSIndex(self.m_curTeamIndex)]
    local name = team.name
    if string.isEmpty(name) then
        name = Language[string.format("LUA_TEAM_NUM_%d", self.m_curTeamIndex)]
    end
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language.LUA_CHANGE_TEAM_NAME,
        input = true,
        checkInputValid = true,
        inputName = name,
        closeOnConfirm = false,
        onConfirm = function(changedName)
            GameInstance.player.charBag:SetTeamName(CSIndex(self.m_curTeamIndex), changedName)
        end
    })
end




CharFormationCtrl._OnCharInfoClicked = HL.Method(HL.Table) << function(self, charInfo)
    local isShowFixed, isShowTrail = CharInfoUtils.getLockedFormationCharTipsShow(charInfo)
    CharInfoUtils.openCharInfoBestWay({
        initCharInfo = {
            instId = charInfo.charInstId,
            templateId = charInfo.charId,
            isSingleChar = true,
            isTrail = true,
            isShowFixed = isShowFixed,
            isShowTrail = isShowTrail,
        },
        forceSkipIn = true,
    })
end



CharFormationCtrl._OnBtnMixConfirmClicked = HL.Method() << function(self)
    self:Notify(MessageConst.ON_CHAR_FORMATION_LIST_CONFIRM, self.m_curTeamIndex)
end



CharFormationCtrl._OnBtnConfirmClicked = HL.Method() << function(self)
    if Utils.isCurSquadAllDead() then
        
        Notify(MessageConst.SHOW_TOAST, Language.LUA_GAME_MODE_FORBID_FACTORY_WATCH)
        return
    end

    if self.m_phase then
        local success, toast = self.m_phase:_CheckTeamCanFight()
        if not success then
            Notify(MessageConst.SHOW_TOAST, toast)
            return
        end
    end

    if self.state == UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet then
        self:Notify(MessageConst.ON_CHAR_FORMATION_TEAM_SET)
    end

    if self.m_dungeonId then
        if self.m_isFormationLocked then
            local charInfos = {}
            for _, charInfo in ipairs(self.m_lockedTeamData.chars) do
                table.insert(charInfos, CharInfoUtils.getPlayerCharInfoByInstId(charInfo.charInstId))
            end
            local selectedCharCount = #charInfos

            if selectedCharCount == 0 then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_TEAM_FORMATION_EMPTY_TIPS)
                return
            end

            local showConfirmTips = false
            if selectedCharCount < self.m_lockedTeamData.maxTeamMemberCount then
                local _, selectableCharCount = CharInfoUtils.getCharInfoListWithLockedTeamData(self.m_lockedTeamData)
                if selectableCharCount > selectedCharCount then
                    showConfirmTips = true
                end
            end

            if showConfirmTips then
                self:Notify(MessageConst.SHOW_POP_UP, {
                    content = Language.LUA_TEAM_FORMATION_CHAR_NOT_FULL_TIPS,
                    onConfirm = function()
                        self:_EnterDungeon(self.m_dungeonId, charInfos)
                    end
                })
            else
                self:_EnterDungeon(self.m_dungeonId, charInfos)
            end
        else
            self:_EnterDungeon(self.m_dungeonId)
        end
    end

    if self.m_weekRaidArg then
        local gameId = string.isEmpty(GameInstance.player.weekRaidSystem.guideGameId) and GameInstance.player.weekRaidSystem.gameId or GameInstance.player.weekRaidSystem.guideGameId
        if GameInstance.player.weekRaidSystem:ReqStartWeekRaid(gameId,
                                                               Tables.weekRaidConst.takeItemId,
                                                               self.m_curSelectTakeItemCount) then
            
            
            GameWorld.dialogManager:Next(0)
            
            if self.m_enterDungeonCallback then
                self.m_enterDungeonCallback()
            end
        end
    end

    if self.m_dungeonId then
        AudioAdapter.PostEvent("au_ui_btn_start_dungeon")
    else
        
        AudioAdapter.PostEvent("au_ui_g_confirm_button")
    end
end







CharFormationCtrl.InitSelectTeam = HL.Method() << function(self)
    local curTeamIndex = GameInstance.player.charBag.curTeamIndex
    self.m_teamSet = LuaIndex(curTeamIndex)
    self:_SetTeamSelect(self.m_teamSet)

    
    self.view.infoNoe.gameObject:SetActive(not self.m_isFormationLocked)
end



CharFormationCtrl.UpdateTeamSet = HL.Method() << function(self)
    self.m_teamSet = LuaIndex(GameInstance.player.charBag.curTeamIndex)
    if self.m_curTeamIndex == self.m_teamSet then
        self:SetState(UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet)
    else
        self:SetState(UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet)
    end
end




CharFormationCtrl.SetSingleCharIndex = HL.Method(HL.Number) << function(self, index)
    self.m_singleCharIndex = index
    local charInfo = self.m_index2Char[index]
    self:RefreshCharInformation(charInfo)
end




CharFormationCtrl.RefreshTeamCharInfo = HL.Method(HL.Table) << function(self, team)
    local index = 1
    if team ~= nil then
        for _, teamChar in pairs(team.slots) do
            self:UpdateChar(index, teamChar)
            index = index + 1
        end
    end

    for i = index, Const.BATTLE_SQUAD_MAX_CHAR_NUM do
        self:UpdateChar(i, nil)
    end
    self:_UpdateSlotConfirmBinding()
end





CharFormationCtrl.UpdateChar = HL.Method(HL.Number, HL.Table) << function(self, index, charInfo)
    self:Notify(MessageConst.ON_CHAR_FORMATION_REFRESH_SLOT, { index, charInfo })
    self.m_index2Char[index] = charInfo
end




CharFormationCtrl.SetState = HL.Method(HL.Number) << function(self, state)
    local needRefresh = self.state ~= state
    
    local isTeamFullLocked = self.m_lockedTeamData and
                             not self.m_lockedTeamData.hasReplaceable and
                             self.m_lockedTeamData.lockedTeamMemberCount == self.m_lockedTeamData.maxTeamMemberCount
    local showFormation = state == UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or
                          state == UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet
    self.view.btnFormation.gameObject:SetActive(showFormation and not isTeamFullLocked)
    
    local showMixConfirm = state == UIConst.UI_CHAR_FORMATION_STATE.CharChange
    self.view.btnMixConfirm.gameObject:SetActive(showMixConfirm)

    
    local isDungeon = self.m_dungeonId or self.m_weekRaidArg
    self.view.btnMixInFight.gameObject:SetActive(showMixConfirm and self.m_curTeamIndex ~= self.m_teamSet and not isDungeon)

    
    if self.m_dungeonId then
        self.view.btnConfirm.text = DungeonUtils.getEntryText(self.m_dungeonId) 
        self.view.btnConfirm.interactable = true
    elseif self.m_weekRaidArg then
        self.view.btnConfirm.text = Language.LUA_CHAR_FORMATION_ENTER_DUNGEON 
        self.view.btnConfirm.interactable = true
    else
        if self.m_curTeamIndex ~= self.m_teamSet then
            self.view.btnConfirm.text = Language.LUA_CHAR_FORMATION_TEAM_CONFIRM 
            self.view.btnConfirm.interactable = true
        else
            self.view.btnConfirm.text = Language.LUA_CHAR_FORMATION_TEAM_CONFIRMED 
            self.view.btnConfirm.interactable = false
        end
    end
    self.view.btnConfirm.gameObject:SetActive(showFormation)
    
    local showSingle = state == UIConst.UI_CHAR_FORMATION_STATE.SingleChar
    self.view.btnSoloConfirm.gameObject:SetActive(showSingle)
    local singleState = UIConst.UI_CHAR_FORMATION_SINGLE_STATE.None
    if needRefresh then
        if showSingle then
            singleState = UIConst.UI_CHAR_FORMATION_SINGLE_STATE.Current
            if self.m_isFormationLocked and self.m_singleCharIndex <= self.m_lockedTeamData.lockedTeamMemberCount then
                singleState = UIConst.UI_CHAR_FORMATION_SINGLE_STATE.CurrentLocked
            end
        else
            singleState = UIConst.UI_CHAR_FORMATION_SINGLE_STATE.None
        end
    end

    self:_PlayBtnMultiAnim(state)
    self:RefreshSingleBtns(singleState, self.m_singleCharInfo)

    local leftRightVisible = state == UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or state == UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet
    self:_RefreshLeftRightBtns(leftRightVisible and not self.m_lockedTeamData)

    
    local back = state == UIConst.UI_CHAR_FORMATION_STATE.CharChange or state == UIConst.UI_CHAR_FORMATION_STATE.SingleChar
    self.view.btnClose.gameObject:SetActive(not back)
    self.view.btnBack.gameObject:SetActive(back)

    
    self.view.btnBackTouch.gameObject:SetActive(showMixConfirm)

    self.preState = self.state
    self.state = state
end





CharFormationCtrl.RefreshSingleBtns = HL.Method(HL.Number, HL.Table) << function(self, singleState, charInfo)
    self:_PlayBtnSingleAnim(singleState)

    self.singleState = singleState

    if singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.None then
        self.view.btnSoloConfirm.gameObject:SetActive(false)
        self.view.btnRemove.gameObject:SetActive(false)
        self.view.btnCannotReplace.gameObject:SetActive(false)
        return
    end

    local showRemove = singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.Current
    local otherDead = singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherDead
    local currentLocked = singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.CurrentLocked
    local interactable = singleState ~= UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherInTeam and
                         singleState ~= UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherInTeamLocked and
                         singleState ~= UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherUnavailable and
                         not otherDead
    local text
    if otherDead then
        text = Language.ui_bat_action_exit
    elseif interactable then
        text = Language.LUA_CHAR_FORMATION_SINGLE_CONFIRM
    else
        text = Language.LUA_CHAR_FORMATION_SINGLE_CONFIRMED
    end
    self.view.btnSoloConfirm.interactable = interactable
    self.view.btnSoloConfirm.text = text
    self.view.btnSoloConfirm.gameObject:SetActive(not showRemove and not currentLocked)
    self.view.btnRemove.gameObject:SetActive(showRemove)
    self.view.btnCannotReplace.gameObject:SetActive(currentLocked)
    if currentLocked then
        local isFixed = charInfo and charInfo.isLocked and not charInfo.isReplaceable
        self.view.txtCannotReplace.text = isFixed and Language.LUA_TEAM_FORMATION_CHAR_CANNOT_CHANGE or Language.LUA_TEAM_FORMATION_CHAR_CANNOT_LEAVE
    end
end




CharFormationCtrl.RefreshEmpty = HL.Method(HL.Boolean) << function(self, empty)
    if self.m_empty == empty then
        return
    end

    self.view.btnFomationNode.gameObject:SetActive(not empty)
    self.view.btnMixConfirmNode.gameObject:SetActive(not empty)
    self.view.btnRemovNode.gameObject:SetActive(not empty)
    self.view.btnNode:ClearTween()
    if empty then
        self.view.emptyNode.gameObject:SetActive(empty)
        self.view.btnNode:PlayWithTween(BTN_ANIM_NAME.BTN_EMPTY_IN)
    else
        self.view.btnNode:PlayWithTween(BTN_ANIM_NAME.BTN_EMPTY_OUT, function()
            self.view.emptyNode.gameObject:SetActive(empty)
        end)
    end

    self.m_empty = empty
end




CharFormationCtrl.RefreshTeamName = HL.Method(HL.Opt(HL.String)) << function(self, name)
    if string.isEmpty(name) and not self.m_isFormationLocked then
        local team = GameInstance.player.charBag.teamList[CSIndex(self.m_curTeamIndex)]
        name = team.name
    end

    if string.isEmpty(name) or self.m_isFormationLocked then
        name = Language[string.format("LUA_TEAM_NUM_%d", self.m_curTeamIndex)]
    end

    self.view.textName.text = name
end





CharFormationCtrl.RefreshCharInformation = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, charInfo, selectTable)
    local needRefresh = false
    if self.m_singleCharInfo and charInfo and self.m_singleCharInfo.charInstId ~= charInfo.charInstId then
        needRefresh = true
    end

    self.m_singleCharInfo = charInfo
    if charInfo then
        self:_SetSlotCharInfo(self.view.charInformation, charInfo)

        self.view.charInformation.charSkillNode:InitCharSkillNodeNew({
            charInstId = charInfo.charInstId,
            isSingleChar = true,
            hideBtnUpgrade = true,
            tipsNode = self.view.charInformation.skillTipsNode,
            tipPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        })
        self.view.charInformation.charPassiveSkillNode:InitCharPassiveSkillNode({
            charInstId = charInfo.charInstId,
            isSingleChar = true,
            hideBtnUpgrade = true,
            tipsNode = self.view.charInformation.passiveSkillTipsNode,
            tipPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        })

        
        local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInfo.charInstId)
        local dungeonId = self.m_dungeonId

        
        local tacticalItemArgs = {
            itemId = charInst.tacticalItemId,
            isLocked = charInfo.isTrail,
            isForbidden = not string.isEmpty(dungeonId) and
                UIUtils.isItemTypeForbidden(dungeonId, GEnums.ItemType.TacticalItem),
            isClickable = true,
            charTemplateId = charInfo.charId,
            charInstId = charInfo.charInstId,
            tipNode = self.view.charInformation.tacticalItemTipsNode,
            tipPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
        }
        self.view.charInformation.charFormationTacticalItem:InitCharFormationTacticalItem(tacticalItemArgs)
        local canChangeItem = self.view.charInformation.charFormationTacticalItem:CanChangeItem()
        InputManagerInst:ToggleBinding(self.m_equipTacticalItemBindingId, canChangeItem)

        self.view.charInformation.gameObject:SetActive(true)
        if needRefresh then
            self.view.charInformation.animationWrapper:PlayInAnimation()
        end
        self.view.charInfoNaviGroup.getDefaultSelectableFunc = function()
            return self.view.charInformation.charSkillNode.m_skillCells:GetItem(1).view.button
        end
    else
        if self.view.charInformation.gameObject.activeSelf then
            self.view.charInformation.animationWrapper:PlayOutAnimation(function()
                self.view.charInformation.gameObject:SetActive(false)
            end)
        end
        InputManagerInst:ToggleBinding(self.m_equipTacticalItemBindingId, false)
    end

    local starNum = 0
    local tagNum = 0
    local charCfg
    if charInfo then
        local characterTable = Tables.characterTable
        charCfg = characterTable:GetValue(charInfo.charId)
        starNum = charCfg.rarity
        tagNum = charCfg.charBattleTagIds and #charCfg.charBattleTagIds or 0
    end
    self.m_genStars:Refresh(starNum)
    self.m_charTagCellCache:Refresh(tagNum, function(cell, index)
        local _, tagName = Tables.charBattleTagTable:TryGetValue(charCfg.charBattleTagIds[CSIndex(index)])
        if tagName then
            cell.tagTxt.text = tagName
        end
    end)
end








CharFormationCtrl._ProcessArgs = HL.Method(HL.Table) << function(self, args)
    self.m_dungeonId = args.dungeonId
    self.m_weekRaidArg = args.weekRaidArg
    self.m_index2Char = {}
    self.m_teamSet = LuaIndex(GameInstance.player.charBag.curTeamIndex)
    self.m_isFormationLocked = args.lockedTeamData ~= nil
    self.m_lockedTeamData = args.lockedTeamData
    self.m_enterDungeonCallback = args.enterDungeonCallback

    self:_Init()
end



CharFormationCtrl._Init = HL.Method() << function(self)
    if self.m_dungeonId then
        local succ, dungeonCfg = Tables.dungeonTable:TryGetValue(self.m_dungeonId)
        if succ then
            if not string.isEmpty(dungeonCfg.dungeonName) then
                self.view.titleTxt.text = dungeonCfg.dungeonName
            end
            local featureInfos = DungeonUtils.getListByStr(dungeonCfg.featureDesc)
            local hasFeature = #featureInfos > 0
            self.view.dungeonInfoBtn.onClick:RemoveAllListeners()
            self.view.dungeonInfoBtn.onClick:AddListener(function()
                UIManager:AutoOpen(PanelId.DungeonInfoPopup, { dungeonId = self.m_dungeonId })
            end)
            self.view.dungeonInfoBtn.gameObject:SetActive(hasFeature)
        else
            self.view.dungeonInfoBtn.gameObject:SetActive(false)
            self.view.titleTxt.gameObject:SetActive(false)
        end
    elseif self.m_weekRaidArg ~= nil then
        local cfg = Tables.weekRaidTable:GetValue(GameInstance.player.weekRaidSystem.gameId)
        self.view.titleTxt.text = cfg.raidTopic
        self.view.titleDeco:LoadSprite(UIConst.UI_SPRITE_CHAR_FORMATION_ICON, cfg.icon)
        self.view.dungeonInfoBtn.gameObject:SetActive(false)
    else
        self.view.dungeonInfoBtn.gameObject:SetActive(false)
    end

    
    self.view.btnClose.onClick:RemoveAllListeners()
    self.view.btnClose.onClick:AddListener(function()
        local isOpen, phase = PhaseManager:IsOpen(PhaseId.Dialog)
        if isOpen then
            Notify(MessageConst.DIALOG_CLOSE_UI, { PANEL_ID, PhaseId.CharFormation, 0 })
        else
            self.m_phase:OnCommonBackClicked()
        end
    end)
    self:BindInputPlayerAction("common_close_team_panel", function()
        PhaseManager:PopPhase(PhaseId.CharFormation)
    end)

    self.view.btnBack.onClick:RemoveAllListeners()
    self.view.btnBack.onClick:AddListener(function()
        self.m_phase:OnCommonBackClicked()
    end)

    
    self.view.btnRename.onClick:RemoveAllListeners()
    self.view.btnRename.onClick:AddListener(function()
        self:_OnChangeTeamNameClicked()
    end)

    
    self.view.btnFormation.onClick:RemoveAllListeners()
    self.view.btnFormation.onClick:AddListener(function()
        self:_OnEnterMultiSelect()
    end)

    
    self.view.btnMixConfirm.onClick:RemoveAllListeners()
    self.view.btnMixConfirm.onClick:AddListener(function()
        self:_OnBtnMixConfirmClicked()
    end)

    
    self.view.btnMixInFight.onClick:AddListener(function()
        self.m_phase:SetMemberAndActiveTeam()
    end)

    
    self.view.btnConfirm.onClick:RemoveAllListeners()
    self.view.btnConfirm.onClick:AddListener(function()
        self:_OnBtnConfirmClicked()
    end)

    
    self.view.btnSoloConfirm.onClick:RemoveAllListeners()
    self.view.btnSoloConfirm.onClick:AddListener(function()
        self:Notify(MessageConst.ON_CHAR_FORMATION_CONFIRM_SINGLE_CHAR, self.m_curTeamIndex)
    end)

    
    self.view.btnRemove.onClick:RemoveAllListeners()
    self.view.btnRemove.onClick:AddListener(function()
        self:Notify(MessageConst.ON_CHAR_FORMATION_UNEQUIP_INDEX)
    end)

    self.view.buttonRight.onClick:RemoveAllListeners()
    self.view.buttonRight.onClick:AddListener(function()
        self:_SetTeamSelect(self.m_curTeamIndex + 1)
    end)

    self.view.buttonLeft.onClick:RemoveAllListeners()
    self.view.buttonLeft.onClick:AddListener(function()
        self:_SetTeamSelect(self.m_curTeamIndex - 1)
    end)

    self.view.charInformation.btnCultivation.onClick:RemoveAllListeners()
    self.view.charInformation.btnCultivation.onClick:AddListener(function()
        self:_OnCharInfoClicked(self.m_singleCharInfo)
    end)

    self.m_teamCells = self.m_teamCells or UIUtils.genCellCache(self.view.team)
    local totalSquadNum = Tables.globalConst.totalSquadNum
    self.m_teamCells:Refresh(totalSquadNum, function(cell, luaIndex)
        local data = {
            index = luaIndex
        }
        cell:InitTeamCell(data, function()
            self:_SetTeamSelect(luaIndex)
        end)
        cell.gameObject:SetActive(true)
    end)

    self.m_genStars = self.m_genStars or UIUtils.genCellCache(self.view.charInformation.starIcon)
    self.m_charTagCellCache = self.m_charTagCellCache or UIUtils.genCellCache(self.view.charInformation.tagCell)

    
    

    self.view.charInformation.gameObject:SetActive(false)
    self.view.emptyNode.gameObject:SetActive(false)
    self.view.btnCannotReplace.gameObject:SetActive(false)

    self.view.trialOperators.gameObject:SetActive(self.m_lockedTeamData and self.m_lockedTeamData.shouldShowTrailTips)

    if not string.isEmpty(self.m_dungeonId) or self.m_weekRaidArg then
        UIManager:ToggleBlockObtainWaysJump(CHAR_FORMATION_BLOCK_OBTAIN_WAYS_JUMP, true)
    end
end




CharFormationCtrl._SetTeamSelect = HL.Method(HL.Number) << function(self, index)

    local totalSquadNum = Tables.globalConst.totalSquadNum
    if index > totalSquadNum then
        index = index - totalSquadNum
    elseif index <= 0 then
        index = index + totalSquadNum
    end

    if self.m_curTeamIndex ~= index then
        local oldCell = self.m_teamCells:GetItem(self.m_curTeamIndex)
        if oldCell then
            oldCell:SetSelect(false)
        end
        self.m_curTeamIndex = index
        local newCell = self.m_teamCells:GetItem(self.m_curTeamIndex)
        newCell:SetSelect(true)
        self:Notify(MessageConst.ON_CHAR_FORMATION_SELECT_TEAM_CHANGE, self.m_curTeamIndex)
        self:RefreshTeamName()
    end

    if self.m_curTeamIndex == self.m_teamSet then
        self:SetState(UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet)
    else
        self:SetState(UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet)
    end

    self:RefreshTeamName()
end





CharFormationCtrl._SetSlotCharInfo = HL.Method(HL.Table, HL.Table) << function(self, slot, info)
    local characterTable = Tables.characterTable
    local data = characterTable:GetValue(info.charId)
    local instId = info.charInstId
    local charInfo = nil

    if instId and instId > 0 then
        charInfo = CharInfoUtils.getPlayerCharInfoByInstId(instId)
    end
    
    if charInfo then
        slot.textLv.text = string.format("%02d", charInfo.level)
    end
    
    slot.textName.text = data.name
    
    slot.charElementIcon:InitCharTypeIcon(data.charTypeId)
    
    local proSpriteName = CharInfoUtils.getCharProfessionIconName(data.profession, true)
    slot.imagePro:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, proSpriteName)
    
    local isFixed, isTrail = CharInfoUtils.getLockedFormationCharTipsShow(info)
    slot.tryoutTips.gameObject:SetActive(isTrail)
    slot.fixedTips.gameObject:SetActive(isFixed)
end




CharFormationCtrl._PlayBtnSingleAnim = HL.Method(HL.Number) << function(self, singleState)
    if singleState == self.singleState then
        return
    end

    local name

    local charInfo = self.m_index2Char[self.m_singleCharIndex]

    if self.singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.None then
        
        if singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.Current and charInfo then
            name = BTN_ANIM_NAME.BTN_FORMATION_REMOV_IN
            
        else
            name = BTN_ANIM_NAME.BTN_EMPTY_IN
        end
    else
        if singleState == UIConst.UI_CHAR_FORMATION_SINGLE_STATE.Current then
            name = BTN_ANIM_NAME.BTN_FORMATION_REMOV_IN
        else
            name = BTN_ANIM_NAME.BTN_EMPTY_OUT
        end
    end

    if not string.isEmpty(name) then
        self.view.btnNode:PlayWithTween(name)
    end

end




CharFormationCtrl._RefreshLeftRightBtns = HL.Method(HL.Boolean) << function(self, visible)
    self.view.midNodeAnim:ClearTween(false)
    if visible then
        self.view.buttonLeft.gameObject:SetActive(true)
        self.view.buttonRight.gameObject:SetActive(true)
        self.view.midNodeAnim:PlayInAnimation()
    else
        self.view.midNodeAnim:PlayOutAnimation(function()
            self.view.buttonLeft.gameObject:SetActive(false)
            self.view.buttonRight.gameObject:SetActive(false)
        end)
    end

end




CharFormationCtrl._PlayBtnMultiAnim = HL.Method(HL.Number) << function(self, state)
    if state == self.state then
        return
    end

    local name

    
    if state == UIConst.UI_CHAR_FORMATION_STATE.CharChange then
        name = BTN_ANIM_NAME.BTN_FORMATION_MIXCONFIRM_IN
        
    elseif self.state == UIConst.UI_CHAR_FORMATION_STATE.CharChange then
        name = BTN_ANIM_NAME.BTN_FORMATION_MIXCONFIRM_OUT
    end

    if not string.isEmpty(name) then
        self.view.btnNode:PlayWithTween(name)
    end
end




CharFormationCtrl._OnActiveSquadChange = HL.Method(HL.Table) << function(self, args)
    local curTeamIndex = unpack(args)
    self:UpdateTeamSet()
    self:_StartCoroutine(function()
        self.view.bannerMidNode.gameObject:SetActive(true)
        self.view.bannerMidNode.numTxt.text = string.format("0%d", LuaIndex(curTeamIndex))
        coroutine.wait(self.view.config.SQUAD_CHANGED_TIPS_TIME)
        self.view.bannerMidNode.gameObject:SetActive(false)
    end)
end





CharFormationCtrl._EnterDungeon = HL.Method(HL.String, HL.Opt(HL.Table)) << function(self, dungeonId, charInfos)
    local entered = false
    if charInfos then
        entered = GameInstance.dungeonManager:TryReqEnterDungeon(dungeonId, charInfos)
    else
        entered = GameInstance.dungeonManager:TryReqEnterDungeon(dungeonId)
    end
    if entered then
        
        self:Notify(MessageConst.DIALOG_CLOSE_UI, { nil, nil, 0 })
        if self.m_enterDungeonCallback then
            self.m_enterDungeonCallback(dungeonId)
        end
        Utils.reportPlacementEvent(GEnums.ClientPlacementEventType.DungeonBattleFirst)
    end
end









CharFormationCtrl.OpenCharList = HL.Method(HL.Number, HL.Opt(HL.Int)) << function(self, mode, charInstId)
    if self.state == UIConst.UI_CHAR_FORMATION_STATE.CharChange then
        return
    end

    self.m_charListSingleCharInstId = charInstId or self.m_charListSingleCharInstId
    self.m_charListMode = mode

    local maxCharTeamMemberCount = self.m_lockedTeamData and
                                   self.m_lockedTeamData.maxTeamMemberCount or
                                   GameInstance.player.charBag.maxCharTeamMemberCount
    
    local info = {
        selectNum = math.min(Const.BATTLE_SQUAD_MAX_CHAR_NUM, maxCharTeamMemberCount),
        mode = self.m_charListMode,
        selectedCharInfo = self.m_singleCharInfo,
        lockedTeamData = self.m_lockedTeamData,
    }
    UIUtils.PlayAnimationAndToggleActive(self.view.charList.view.animationWrapper, true)
    self.view.charList:InitCharFormationList(info, function(charList)
        self.m_tmpCharItems = charList
    end)
    self.view.charList:SetUpdateCellFunc(nil, function(select, cellIndex, charItem, charItemList, charInfoList)
        self:_CharListChangeSelectIndex(select, cellIndex, charItem, charItemList, charInfoList)
    end)
    self:_RefreshCharList()
    self.view.charList:ShowSelectChars(self:_GetShowSelectChars())
    self:_ActiveTeamInfo(false)
end



CharFormationCtrl.CloseCharList = HL.Method() << function(self)
    UIUtils.PlayAnimationAndToggleActive(self.view.charList.view.animationWrapper, false)
    self:_ActiveTeamInfo(true)
end




CharFormationCtrl._ActiveTeamInfo = HL.Method(HL.Boolean) << function(self, active)
    self.view.charTittleNode.gameObject:SetActive(active)
    self.view.infoNoe.gameObject:SetActive(active and not self.m_isFormationLocked)
end





CharFormationCtrl.SetCharListMode = HL.Method(HL.Number, HL.Opt(HL.Number)) << function(self, mode, charInstId)
    self.view.charList:SetMode(mode, charInstId)
    self.m_charListMode = mode
end



CharFormationCtrl.GetCharListEmpty = HL.Method().Return(HL.Boolean) << function(self)
    return self.view.charList:GetEmpty()
end



CharFormationCtrl.GetCurCharList = HL.Method().Return(HL.Table) << function(self)
    
    local charList = {}
    local index2Id = {}
    for cellIndex, index in pairs(self.view.charList.cell2Select) do
        index2Id[index] = self.m_tmpCharItems[cellIndex]
    end
    local realIndex = 1
    for i = 1, Const.BATTLE_SQUAD_MAX_CHAR_NUM do
        if index2Id[i] then
            charList[realIndex] = index2Id[i]
            realIndex = realIndex + 1
        end
    end
    return charList
end


CharFormationCtrl.m_charListMode = HL.Field(HL.Number) << 0


CharFormationCtrl.m_charListSingleCharInstId = HL.Field(HL.Int) << 0


CharFormationCtrl.m_tmpCharItems = HL.Field(HL.Table) 



CharFormationCtrl._OnEnterMultiSelect = HL.Method() << function(self)
    self:OpenCharList(UIConst.CharListMode.MultiSelect)
    self:SetState(UIConst.UI_CHAR_FORMATION_STATE.CharChange)
    self:Notify(MessageConst.ON_CHAR_FORMATION_ENTER_MULTI_SELECT)
end



CharFormationCtrl._RefreshCharList = HL.Method() << function(self)
    if self.m_lockedTeamData then
        self.m_tmpCharItems = CharInfoUtils.getCharInfoListWithLockedTeamData(self.m_lockedTeamData)
    else
        self.m_tmpCharItems = CharInfoUtils.getCharInfoList(CSIndex(self.m_curTeamIndex))
    end
    self.view.charList:UpdateCharItems(self.m_tmpCharItems)
end








CharFormationCtrl._CharListChangeSelectIndex = HL.Method(HL.Boolean, HL.Number, HL.Table, HL.Table, HL.Table) << function
(self, select, cellIndex, charItem, charItemList, charInfoList)
    if self.m_charListMode == UIConst.UIConst.CharListMode.MultiSelect then
        self:Notify(MessageConst.ON_CHAR_FORMATION_LIST_MULTI_SELECT, { charItemList, charInfoList })
    else
        self:Notify(MessageConst.ON_CHAR_FORMATION_LIST_SINGLE_SELECT, { cellIndex, charItem })
    end
end



CharFormationCtrl._GetShowSelectChars = HL.Method().Return(HL.Table) << function(self)
    local showSelectChars = {}
    for i = 1, #self.m_tmpCharItems do
        local charItem = self.m_tmpCharItems[i]
        if charItem.slotIndex and charItem.slotIndex <= Const.BATTLE_SQUAD_MAX_CHAR_NUM then
            table.insert(showSelectChars, charItem)
        end
    end

    table.sort(showSelectChars, Utils.genSortFunction({ "slotIndex" }, true))
    return showSelectChars
end







CharFormationCtrl.m_isFormationLocked = HL.Field(HL.Boolean) << false


CharFormationCtrl.m_lockedTeamData = HL.Field(HL.Table)






CharFormationCtrl.m_equipTacticalItemBindingId = HL.Field(HL.Number) << -1


CharFormationCtrl.m_isCharInfoNaviGroupFocused = HL.Field(HL.Boolean) << false


CharFormationCtrl.m_slotConfirmBindingId = HL.Field(HL.Number) << -1



CharFormationCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    self:BindInputPlayerAction("char_formation_slot_next", function()
        self:Notify(MessageConst.ON_CHAR_FORMATION_CHANGE_HOVER_INDEX, true)
        self:_UpdateSlotConfirmBinding()
    end, self.view.slotInputBindingGroup.groupId)
    self:BindInputPlayerAction("char_formation_slot_previous", function()
        self:Notify(MessageConst.ON_CHAR_FORMATION_CHANGE_HOVER_INDEX, false)
        self:_UpdateSlotConfirmBinding()
    end, self.view.slotInputBindingGroup.groupId)
    self.m_slotConfirmBindingId = self:BindInputPlayerAction("char_formation_slot_confirm", function()
        self:Notify(MessageConst.ON_CHAR_FORMATION_CONFIRM_HOVER)
    end, self.view.slotInputBindingGroup.groupId)
    self.m_equipTacticalItemBindingId = self:BindInputPlayerAction("char_formation_equip_tactical_item", function()
        self.view.charInformation.charFormationTacticalItem:GoToCharInfoEquipPage()
    end)
    InputManagerInst:ToggleBinding(self.m_equipTacticalItemBindingId, false)
    self.view.charInfoNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        self.m_isCharInfoNaviGroupFocused = isFocused
        if not isFocused then
            Notify(MessageConst.CHAR_INFO_CLOSE_ATTR_TIP)
            Notify(MessageConst.CHAR_INFO_CLOSE_SKILL_TIP)
            Notify(MessageConst.CHAR_INFO_CLOSE_INFO_TIP)
        end
        self.view.charInformation.controllerFocusHintNode.gameObject:SetActive(not isFocused)
    end)
end



CharFormationCtrl._UpdateSlotConfirmBinding = HL.Method() << function(self)
    local isLocked = false
    local isEmpty = false
    if self.m_phase then
        local slot = self.m_phase:GetCurNaviSlot()
        if slot then
            isLocked = slot.isLocked
            isEmpty = slot.empty
        end
    end
    InputManagerInst:ForceBindingKeyhintToGray(self.m_slotConfirmBindingId, isLocked)
    InputManagerInst:SetBindingText(self.m_slotConfirmBindingId, (isEmpty or isLocked) and
         Language.key_hint_char_formation_slot_confirm_no_char or Language.key_hint_char_formation_slot_confirm)
end







CharFormationCtrl._UpdateWeekRaid = HL.Method() << function(self)
    local isWeekRaid = self.m_weekRaidArg ~= nil
    
    local success, maxCount = GameInstance.player.weekRaidSystem.techTypeValue:TryGetValue(GEnums.WeekRaidTechType.BombLimit)
    self.view.carryingExplosives.gameObject:SetActive(isWeekRaid and success and maxCount > 0)

    if isWeekRaid then
        CS.Beyond.Gameplay.Conditions.OnWeekRaidIntroCharFormationOpen.Trigger()
        self.view.carryingExplosives.addBtn.onClick:RemoveAllListeners()
        self.view.carryingExplosives.addBtn.onClick:AddListener(function()
            self:_AdjustSelectTakeItemCount()
        end)
        self:_UpdateTakeItemInfo()
    end
end



CharFormationCtrl._AdjustSelectTakeItemCount = HL.Method() << function(self)
    local maxCount = GameInstance.player.weekRaidSystem.techTypeValue[GEnums.WeekRaidTechType.BombLimit]
    UIManager:Open(PanelId.CommonItemNumSelect,{
        id = Tables.weekRaidConst.takeItemId,
        count = self.m_curSelectTakeItemCount,
        maxCount = math.min(Utils.getItemCount(Tables.weekRaidConst.takeItemId, false, true), maxCount),
        showItemInfoBtn = true,
        useSlider = true,
        onComplete = function(num)
            if num ~= nil then
                self.m_curSelectTakeItemCount = num
            end
            self:_UpdateTakeItemInfo()
        end
    })
end



CharFormationCtrl._UpdateTakeItemInfo = HL.Method() << function(self)
    if self.m_curSelectTakeItemCount <= 0 then
        self.view.carryingExplosives.itemBigBlack.gameObject:SetActiveIfNecessary(false)
    else
        self.view.carryingExplosives.itemBigBlack.gameObject:SetActiveIfNecessary(true)
        self.view.carryingExplosives.itemBigBlack:InitItem({
            id = Tables.weekRaidConst.takeItemId,
            count = self.m_curSelectTakeItemCount,
        },function()
            self:_AdjustSelectTakeItemCount()
        end)
    end
end



HL.Commit(CharFormationCtrl)
