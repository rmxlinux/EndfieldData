
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BattleComboSkill

















BattleComboSkillCtrl = HL.Class('BattleComboSkillCtrl', uiCtrl.UICtrl)








BattleComboSkillCtrl.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.ON_COMBO_SKILL_READY] = 'OnComboSkillReady',
    [MessageConst.ON_COMBO_SKILL_REMOVE] = 'OnComboSkillRemove',
    [MessageConst.ON_BATTLE_SQUAD_CHANGED] = 'OnBattleTeamChanged',
    [MessageConst.ON_COMBO_SKILL_CLEAR_ALL] = 'OnComboSkillClearAll',
}

do 
    
    BattleComboSkillCtrl.m_hintList = HL.Field(HL.Table)

    
    BattleComboSkillCtrl.m_charIndexList = HL.Field(HL.Table)

    
    BattleComboSkillCtrl.m_updateKey = HL.Field(HL.Number) << -1
end





BattleComboSkillCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    if self.isDefaultPanel and DeviceInfo.usingTouch then
        self.view.customLayoutElement.onLayoutDataLoaded:AddListener(function()
            local stateName = "RightToLeft"
            if self.view.customLayoutElement.layoutType == CS.Beyond.UI.UICustomLayoutElement.LayoutType.LeftToRight then
                stateName = "LeftToRight"
            end
            self.view.infoNodeStateController:SetState(stateName)
        end)
    end
    self.m_hintList = {}
    for i = 1, Const.BATTLE_SQUAD_MAX_CHAR_NUM do
        local hint = self.view['comboSkillHint' .. i]
        
        hint.transform.localScale = Vector3.zero
        self.m_hintList[i] = hint
        if self.isPCPanel then
            hint.maskNode.gameObject:SetActive(false)
        else
            hint.maskNode.gameObject:SetActive(true)
        end
        
        hint.button.onPressStart:AddListener(function()
            self:_CastComboSkill()
        end)
    end
    self.view.buttonCast.onPressStart:AddListener(function()
        self:_CastComboSkill()
    end)

    self.m_charIndexList = {}
    GameWorld.battle:ReactiveAllPendingComboSkill() 
    self:_CheckUpdate()
end



BattleComboSkillCtrl.OnShow = HL.Override() << function(self)
    self:OnBattleTeamChanged()
    self:_ResortSiblingIndex()
end





BattleComboSkillCtrl.OnClose = HL.Override() << function(self)
    self:_ClearUpdate()
end







BattleComboSkillCtrl._Update = HL.Method(HL.Number) << function(self, deltaTime)
    for i, charIndex in ipairs(self.m_charIndexList) do
        local hint = self.m_hintList[charIndex]
        local available, remainTime, canCast = GameWorld.battle:GetRemainComboSkillPendingTime(CSIndex(charIndex))
        if available then
            hint.fill.fillAmount = remainTime / DataManager.skillSetting.comboSkillPendingInterval
            if canCast then
                hint.content.alpha = 1
            else
                hint.content.alpha = self.view.config.COMBO_HINT_DISABLE_ALPHA
            end
        else
            
            
            self:OnComboSkillRemove({CSIndex(charIndex)})
            
            return
        end
    end
end



BattleComboSkillCtrl._CheckUpdate = HL.Method() << function(self)
    local needUpdate = (#self.m_charIndexList > 0)
    self.view.buttonCast.transform.localScale = needUpdate and Vector3.one or Vector3.zero 
    if not needUpdate then
        self:_ClearUpdate()
        return
    end
    if self.m_updateKey < 0 then
        self.m_updateKey = LuaUpdate:Add("Tick", function(deltaTime)
            self:_Update(deltaTime)
        end)
        self:_Update(0)
    end
end



BattleComboSkillCtrl._ClearUpdate = HL.Method() << function(self)
    if self.m_updateKey > 0 then
        LuaUpdate:Remove(self.m_updateKey)
        self.m_updateKey = -1
    end
end




BattleComboSkillCtrl.OnBattleTeamChanged = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    local slots = GameInstance.player.squadManager.curSquad.slots
    for i = 1, slots.Count do
        local hintItem = self.m_hintList[i]
        
        local character = slots[CSIndex(i)].character
        if character ~= nil then
            local abilityCom = character.abilityCom
            local data = abilityCom.data.skillDataBundle
            
            local comboSkill = abilityCom.activeSkillMap:get_Item(abilityCom.curComboSkill)
            local comboSkillData = comboSkill.data
            hintItem.icon:LoadSprite(UIConst.UI_SPRITE_SKILL_ICON, comboSkillData.iconId)
            hintItem.charHead:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, comboSkillData.comboSkillUISpriteName)
        end
    end
end




BattleComboSkillCtrl.OnComboSkillReady = HL.Method(HL.Table) << function(self, args)
    local charIndex = LuaIndex(unpack(args))

    local index = -1
    for i = 1, #self.m_charIndexList do
        if self.m_charIndexList[i] == charIndex then
            index = i
            break
        end
    end

    local hint = self.m_hintList[charIndex]
    if index == -1 then
        table.insert(self.m_charIndexList, charIndex)
    end
    hint.anim:ClearTween()  
    hint.transform.localScale = Vector3.one
    hint.anim:SampleClip("combo_skill_ui_end", 0.0, true)
    hint.anim:PlayWithTween("combo_skill_ui_start")

    self:_CheckUpdate()
    self:_ResortSiblingIndex()
end




BattleComboSkillCtrl.OnComboSkillRemove = HL.Method(HL.Table) << function(self, args)
    local charIndex = LuaIndex(unpack(args))

    local index = -1
    for i, _ in ipairs(self.m_charIndexList) do
        if self.m_charIndexList[i] == charIndex then
            index = i
            break
        end
    end
    if index < 0 then
        return
    end
    table.remove(self.m_charIndexList, index)
    self.m_hintList[charIndex].anim:PlayWithTween("combo_skill_ui_end", function()
        self.m_hintList[charIndex].transform.localScale = Vector3.zero
        self:_ResortSiblingIndex()
    end)
    self:_CheckUpdate()
end




BattleComboSkillCtrl.OnComboSkillClearAll = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    for _, charIndex in ipairs(self.m_charIndexList) do
        self.m_hintList[charIndex].anim:PlayWithTween("combo_skill_ui_end", function()
            self.m_hintList[charIndex].transform.localScale = Vector3.zero
        end)
    end
    self.m_charIndexList = {}
    self:_CheckUpdate()
end



BattleComboSkillCtrl._CastComboSkill = HL.Method() << function(self)
    if #self.m_charIndexList == 0 then
        return
    end
    if DeviceInfo.usingController
        and CS.Beyond.GameSetting.gamepadCacheEnableUltimateMode2
        and InputManagerInst:GetControllerIndicatorState() then
        
        return
    end
    local charIndex = self.m_charIndexList[1]
    local available, remainTime, canCast = GameWorld.battle:GetRemainComboSkillPendingTime(CSIndex(charIndex))
    if available and canCast then
        GameWorld.battle:CastPendingComboSkill(CSIndex(charIndex))
        table.remove(self.m_charIndexList, 1)
        self.m_hintList[charIndex].anim:PlayWithTween("combo_skill_ui_use", function()
            self.m_hintList[charIndex].transform.localScale = Vector3.zero
            self:_ResortSiblingIndex()
        end)
        self:_CheckUpdate()
    else
        Notify(MessageConst.SHOW_TOAST, Language.LUA_BATTLE_SKILL_COMBO_CAST_FAILED)
    end
end



BattleComboSkillCtrl._ResortSiblingIndex = HL.Method() << function(self)
    if #self.m_charIndexList == 0 then
        return
    end
    if not self.view.infoNode.gameObject.activeInHierarchy then
        
        return
    end
    for i, charIndex in ipairs(self.m_charIndexList) do
        local hint = self.m_hintList[charIndex]
        hint.transform:SetSiblingIndex(CSIndex(i) + 1) 
        if i == 1 then
            hint.content.transform.localScale = Vector3.one * self.view.config.COMBO_HINT_FIRST_SCALE
            hint.mask2Img.gameObject:SetActive(false)
        else
            hint.content.transform.localScale = Vector3.one
            hint.mask2Img.gameObject:SetActive(true)
        end
    end
end

HL.Commit(BattleComboSkillCtrl)
