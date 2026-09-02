local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

ActivityCharGiftPopUpCtrl = HL.Class('ActivityCharGiftPopUpCtrl', uiCtrl.UICtrl)

ActivityCharGiftPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdate',
}

ActivityCharGiftPopUpCtrl.m_activityId = HL.Field(HL.String) << ""
ActivityCharGiftPopUpCtrl.m_jumpId = HL.Field(HL.String) << ""
ActivityCharGiftPopUpCtrl.m_previewCharId = HL.Field(HL.String) << ""
ActivityCharGiftPopUpCtrl.m_closeCallback = HL.Field(HL.Function)

ActivityCharGiftPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    args = args or {}
    self.m_activityId = args.activityId or ""
    self.m_closeCallback = args.closeCallback or function()
        self:Close()
    end

    self.view.btnClose.onClick:AddListener(function()
        self:_Close()
    end)

    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local succ, activityData = Tables.activityTable:TryGetValue(self.m_activityId)
    if not succ then
        logger.critical("ActivityCharGiftPopUpCtrl: activity config not found", self.m_activityId)
        return
    end

    self.m_jumpId = activityData.detailJumpId
    self.m_previewCharId = self:_GetPreviewCharId()
    self:_InitShowCharBtn(self.m_previewCharId)
    args.jumpBtnCallBack = function()
        self:_OnClickGotoActivity()
    end
    self.view.activityCommonInfo:InitActivityCommonInfo(args)
end

ActivityCharGiftPopUpCtrl.OnActivityUpdate = HL.Method(HL.Table) << function(self, args)
    local id = unpack(args)
    if id == self.m_activityId and not GameInstance.player.activitySystem:GetActivity(id) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_FORBIDDEN)
        self:_Close()
    end
end

ActivityCharGiftPopUpCtrl._Close = HL.Method(HL.Opt(HL.Function)) << function(self, onClosed)
    if self:IsPlayingAnimationOut() then
        return
    end
    ActivityUtils.recordPopup(self.m_activityId) 
    self:PlayAnimationOutWithCallback(function()
        self.m_closeCallback()
        if onClosed then
            onClosed()
        end
    end)
end

ActivityCharGiftPopUpCtrl._GetPreviewCharId = HL.Method().Return(HL.String) << function(self)
    local succ, configData = Tables.activityCharacterGiftConfigTable:TryGetValue(self.m_activityId)
    if configData then
        return configData.characterId
    end
    return ""
end

ActivityCharGiftPopUpCtrl._OpenCharacterPreview = HL.Method(HL.String) << function(self, charId)
    if string.isEmpty(charId) then
        logger.error("ActivityCharGiftPopUpCtrl: characterId is empty", self.m_activityId)
        return
    end
    CharInfoUtils.openCharInfoBestWay({
        initCharInfoCreator = function()
            local previewCharInfo = GameInstance.player.charBag:CreateClientInitialGachaPoolChar(charId)
            local perfectCharInfo = GameInstance.player.charBag:CreateClientPerfectGachaPoolCharInfo(charId)
            return {
                instId = previewCharInfo.instId,
                templateId = previewCharInfo.templateId,
                charInstIdList = { previewCharInfo.instId },
                maxCharInstIdList = { perfectCharInfo.instId },
                isShowPreview = true,
            }
        end,
        onClose = function()
            GameInstance.player.charBag:ClearAllClientCharAndItemData()
        end,
    })
end

ActivityCharGiftPopUpCtrl._OnClickGotoActivity = HL.Method() << function(self)
     local jumpId = self.m_jumpId
    if string.isEmpty(jumpId) then
        logger.error("ActivityCharGiftPopUpCtrl: jumpId is empty", self.m_activityId)
        return
    end
    self:_Close(function()
        Utils.jumpToSystem(jumpId)
    end)
end

ActivityCharGiftPopUpCtrl._InitShowCharBtn = HL.Method(HL.String) << function(self,characterId)
    if string.isEmpty(characterId) then
        logger.error("ActivityCharacterGiftCtrl: characterId is empty", self.m_activityId)
        return
    end
    local node = self.view.showCharInfoBtn1
    if node then
        if node.button then
            self.view.showCharInfoBtn1.button.onClick:RemoveAllListeners()
            self.view.showCharInfoBtn1.button.onClick:AddListener(function()
                self:_OpenCharacterPreview(characterId)
            end)
        end

        local charCfg = Tables.characterTable[characterId]
        if node.nameTxt then
            node.nameTxt.text = charCfg.name
        end
        if node.professionIcon then
            node.professionIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION, CharInfoUtils.getCharProfessionIconName(charCfg.profession))
        end
        if node.starGroup then
            node.starGroup:InitStarGroup(charCfg.rarity)
        end
        if node.headIcon then
            node.headIcon:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD, UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. charCfg.charId)
        end
    end
end

HL.Commit(ActivityCharGiftPopUpCtrl)
