local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.GachaOptional
















GachaOptionalCtrl = HL.Class('GachaOptionalCtrl', uiCtrl.UICtrl)


local csGachaSystem = GameInstance.player.gacha






GachaOptionalCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED] = 'OnGachaPoolRoleDataChanged',
}



GachaOptionalCtrl.m_info = HL.Field(HL.Table)


GachaOptionalCtrl.m_optionalCellListCache = HL.Field(HL.Forward("UIListCache"))


GachaOptionalCtrl.m_waitResult = HL.Field(HL.Boolean) << false


GachaOptionalCtrl.m_curSelectIndex = HL.Field(HL.Number) << 0







GachaOptionalCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitUI()
    self:_InitData(arg)
    self:_UpdateData()
    self:_RefreshAllUI()
end



GachaOptionalCtrl.OnShow = HL.Override() << function(self)
    local cell = self.m_optionalCellListCache:Get(self.m_curSelectIndex)
    if cell then
        InputManagerInst.controllerNaviManager:SetTarget(cell.naviDeco)
    end
end






GachaOptionalCtrl._InitData = HL.Method(HL.Table) << function(self, arg)
    self.m_info = arg
    
    local charInfos = {}
    
    local charBag = GameInstance.player.charBag
    self.m_info.charInfos = charInfos
    for _, charId in pairs(self.m_info.charIds) do
        
        local bagCharInfo = charBag:GetCharInfoByTemplateId(charId, GEnums.CharType.Default)
        local isOwned = bagCharInfo ~= nil
        local potentialLevel = 0
        local isPotentialMax = false
        if isOwned then
            potentialLevel = bagCharInfo.potentialLevel
            isPotentialMax = potentialLevel >= UIConst.CHAR_MAX_POTENTIAL
        end
        
        local charCfg = Tables.characterTable[charId]
        
        local info = {
            charId = charId,
            name = charCfg.name,
            engName = charCfg.engName,
            professionIcon = CharInfoUtils.getCharProfessionIconName(charCfg.profession),
            
            isOwned = isOwned,
            potentialLevel = potentialLevel,
            isPotentialMax = isPotentialMax,
            
            selectImg = string.format("gachapool_role_selected_%s", charId),
            selectGlassImg = string.format("gachapool_role_glass_%s", charId),
            unselectImg = string.format("gachapool_role_unselected_%s", charId),
            
            instId = "",
        }
        table.insert(charInfos, info)
    end
end



GachaOptionalCtrl._UpdateData = HL.Method() << function(self)
    self.m_curSelectIndex = 1
end





GachaOptionalCtrl._InitUI = HL.Method() << function(self)
    self.view.btnBack.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self.view.inviteBtn.onClick:AddListener(function()
        local charInfo = self.m_info.charInfos[self.m_curSelectIndex]
        local charId = charInfo.charId
        local content = string.format(Language.LUA_GACHA_STANDARD_CHOICE_PACK_CONFIRM_INVITE, charInfo.name)
        Notify(MessageConst.SHOW_POP_UP, {
            content = content,
            onConfirm = function()
                csGachaSystem:SendSelectChoicePackReq(self.m_info.poolId, charId)
                self.m_waitResult = true
            end,
        })
    end)
    self.m_optionalCellListCache = UIUtils.genCellCache(self.view.optionalCell)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end



GachaOptionalCtrl._RefreshAllUI = HL.Method() << function(self)
    self.m_optionalCellListCache:Refresh(#self.m_info.charInfos, function(cell, luaIndex)
        self:_RefreshOptionalCell(cell, luaIndex)
    end)
    self.view.remainInvitableNumTxt.text = self.m_info.remainChoicePackProgress
    self.view.invitableStateCtrl:SetState(self.m_info.remainChoicePackProgress <= 0 and "Invitable" or "NotInvitable")
end





GachaOptionalCtrl._RefreshOptionalCell = HL.Method(HL.Any, HL.Number) << function(self, _cell, luaIndex)
    local charInfo = self.m_info.charInfos[luaIndex]
    
    local cell = _cell
    cell.selectStateCtrl:SetState(luaIndex == self.m_curSelectIndex and "Selected" or "Unselected")
    cell.naviDeco.onIsNaviTargetChanged = function(active)
        if active then
            self:_OnClickOptionalCell(luaIndex)
        end
    end
    cell.naviDeco.hideNaviHint = true
    
    local selectNode = cell.selectedNode
    selectNode.englishNameTxt.text = charInfo.engName
    selectNode.nameTxt.text = charInfo.name
    if charInfo.isPotentialMax then
        selectNode.ownedStateCtrl:SetState("FullPotential")
    else
        selectNode.ownedStateCtrl:SetState(charInfo.isOwned and "Owned" or "NotOwned")
    end
    selectNode.potentialStar:InitCharPotentialStarByLevel(charInfo.potentialLevel, false)
    selectNode.professionIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, charInfo.professionIcon)
    selectNode.roleSelectedImg:LoadSprite(UIConst.UI_SPRITE_GACHA_POOL, charInfo.selectImg)
    selectNode.roleGlassImg:LoadSprite(UIConst.UI_SPRITE_GACHA_POOL, charInfo.selectGlassImg)
    selectNode.starGroup:InitStarGroup(UIConst.CHAR_MAX_RARITY)
    
    selectNode.previewBtn.onClick:RemoveAllListeners()
    selectNode.previewBtn.onClick:AddListener(function()
        local ids = self.m_info.charIds
        
        local charInstIdList = {}
        for _, id in ipairs(ids) do
            local info = GameInstance.player.charBag:CreateClientInitialGachaPoolChar(id)
            table.insert(charInstIdList, info.instId)
        end
        
        local maxCharInstIdList = {}
        for _, id in ipairs(ids) do
            local info = GameInstance.player.charBag:CreateClientPerfectGachaPoolCharInfo(id)
            table.insert(maxCharInstIdList, info.instId)
        end
        CharInfoUtils.openCharInfoBestWay({
            initCharInfo = {
                instId = charInstIdList[luaIndex],
                templateId = charInfo.charId,
                charInstIdList = charInstIdList,
                maxCharInstIdList = maxCharInstIdList,
                isShowPreview = true,
            },
            onClose = function()
                GameInstance.player.charBag:ClearAllClientCharAndItemData()
            end,
        })
    end)
    

    
    local unselectNode = cell.unselectedNode
    
    unselectNode.roleUnselectedImg:LoadSprite(UIConst.UI_SPRITE_GACHA_POOL, charInfo.unselectImg)
    unselectNode.nameTxt.text = charInfo.name
    unselectNode.ownedStateCtrl:SetState(charInfo.isOwned and "Owned" or "NotOwned")
    unselectNode.potentialStar:InitCharPotentialStarByLevel(charInfo.potentialLevel, false)
    
    unselectNode.btn.onClick:RemoveAllListeners()
    unselectNode.btn.onClick:AddListener(function()
        self:_OnClickOptionalCell(luaIndex)
    end)
    
end





GachaOptionalCtrl.OnGachaPoolRoleDataChanged = HL.Method() << function(self)
    if self.m_waitResult then
        self:Close()
        if self.m_info.onSuccess then
            self.m_info.onSuccess()
        end
    end
end




GachaOptionalCtrl._OnClickOptionalCell = HL.Method(HL.Number) << function(self, luaIndex)
    if self.m_curSelectIndex ~= luaIndex then
        local oldIndex = self.m_curSelectIndex
        self.m_curSelectIndex = luaIndex
        
        local cell = self.m_optionalCellListCache:Get(luaIndex)
        if cell then
            cell.selectStateCtrl:SetState("Selected")
        end
        
        local oldCell = self.m_optionalCellListCache:Get(oldIndex)
        if oldCell then
            oldCell.selectStateCtrl:SetState("Unselected")
        end
    end
end


HL.Commit(GachaOptionalCtrl)
