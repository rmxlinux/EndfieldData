local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ActivityCharGiftPopUp = HL.Class('ActivityCharGiftPopUp', UIWidgetBase)

ActivityCharGiftPopUp.m_activityId = HL.Field(HL.String) << ""
ActivityCharGiftPopUp.m_jumpId = HL.Field(HL.String) << ""
ActivityCharGiftPopUp.m_previewCharId = HL.Field(HL.String) << ""
ActivityCharGiftPopUp.m_onClose = HL.Field(HL.Function)
ActivityCharGiftPopUp.m_onGotoActivity = HL.Field(HL.Function)

ActivityCharGiftPopUp.Init = HL.Method(HL.Table) << function(self, args)
    self.m_activityId = args.activityId or ""
    self.m_onClose = args.onClose
    self.m_onGotoActivity = args.onGotoActivity

    self.view.btnClose.onClick:RemoveAllListeners()
    self.view.btnClose.onClick:AddListener(function()
        self.m_onClose()
    end)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    local _, activityData = Tables.activityTable:TryGetValue(self.m_activityId)

    local _, configData = Tables.activityCharacterGiftConfigTable:TryGetValue(self.m_activityId)

    self.m_jumpId = activityData.detailJumpId
    self.m_previewCharId = configData.characterId
    self:_InitShowCharBtn(self.m_previewCharId)

    local activityInfoArgs = args.activityInfoArgs or {
        activityId = self.m_activityId,
    }
    activityInfoArgs.jumpBtnCallBack = function()
        self:_OnClickGotoActivity()
    end
    self.view.activityCommonInfo:InitActivityCommonInfo(activityInfoArgs)
end

ActivityCharGiftPopUp.StartCloseAnimation = HL.Method(HL.Function) << function(self, onComplete)
    self.view.btnClose.gameObject:SetActive(false)
    self.view.animationWrapper:PlayOutAnimation(onComplete)
end

ActivityCharGiftPopUp._OpenCharacterPreview = HL.Method(HL.String) << function(self, charId)
    if string.isEmpty(charId) then
        logger.error("ActivityCharGiftPopUp: characterId is empty", self.m_activityId)
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

ActivityCharGiftPopUp._OnClickGotoActivity = HL.Method() << function(self)
    if string.isEmpty(self.m_jumpId) then
        logger.error("ActivityCharGiftPopUp: jumpId is empty", self.m_activityId)
        return
    end
    if not self.m_onGotoActivity then
        logger.error("ActivityCharGiftPopUp: onGotoActivity is nil", self.m_activityId)
        return
    end
    self.m_onGotoActivity(self.m_jumpId)
end

ActivityCharGiftPopUp._InitShowCharBtn = HL.Method(HL.String) << function(self, characterId)
    if string.isEmpty(characterId) then
        logger.error("ActivityCharGiftPopUp: characterId is empty", self.m_activityId)
        return
    end

    local node = self.view.showCharInfoBtn1
    if node then
        if node.button then
            node.button.onClick:RemoveAllListeners()
            node.button.onClick:AddListener(function()
                self:_OpenCharacterPreview(characterId)
            end)
        end

        local charCfg = Tables.characterTable[characterId]
        if node.nameTxt then
            node.nameTxt.text = charCfg.name
        end
        if node.professionIcon then
            node.professionIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_PROFESSION,
                CharInfoUtils.getCharProfessionIconName(charCfg.profession))
        end
        if node.starGroup then
            node.starGroup:InitStarGroup(charCfg.rarity)
        end
        if node.headIcon then
            node.headIcon:LoadSprite(UIConst.UI_SPRITE_ROUND_CHAR_HEAD,
                UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. charCfg.charId)
        end
    end
end

HL.Commit(ActivityCharGiftPopUp)
return ActivityCharGiftPopUp