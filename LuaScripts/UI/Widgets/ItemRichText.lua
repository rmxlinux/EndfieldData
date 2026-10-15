local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ItemRichText = HL.Class('ItemRichText', UIWidgetBase)

local DEFAULT_ITEM_LINK_STYLE = "item.link"



ItemRichText.m_texts = HL.Field(HL.Table)

ItemRichText.m_styleKey = HL.Field(HL.String) << ""

ItemRichText.m_tipsPosType = HL.Field(HL.Any)

ItemRichText.m_clickListeners = HL.Field(HL.Table)

ItemRichText.m_textDataList = HL.Field(HL.Table)

ItemRichText.m_targetTextIndex = HL.Field(HL.Number) << 1

ItemRichText.m_isNavi = HL.Field(HL.Boolean) << false

ItemRichText.m_onExit = HL.Field(HL.Function)

ItemRichText.m_naviBindInited = HL.Field(HL.Boolean) << false

ItemRichText.m_tipTransform = HL.Field(Unity.Transform)

ItemRichText.m_hasItemTags = HL.Field(HL.Boolean) << false

ItemRichText.m_enableNavi = HL.Field(HL.Boolean) << false




ItemRichText._OnFirstTimeInit = HL.Override() << function(self)
end












ItemRichText.InitItemRichText = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()
    self.m_texts = args.texts or {}
    self.m_styleKey = args.styleKey or DEFAULT_ITEM_LINK_STYLE
    self.m_tipsPosType = args.posType or UIConst.UI_TIPS_POS_TYPE.LeftTop
    self.m_tipTransform = args.tipTransform
    self.m_enableNavi = args.enableNavi == true
    self:_ClearClickListeners()
    self.m_hasItemTags = false
    for i = 1, #self.m_texts do
        local entry = self.m_texts[i]
        local uiText = entry.uiText
        if not IsNull(uiText) then
            local resolved, count = ItemRichText._ResolveItemTags(entry.text or "", self.m_styleKey)
            if count > 0 then
                self.m_hasItemTags = true
            end
            uiText:SetAndResolveTextStyle(resolved)
            local func = function(linkId)
                self:_OnClickLink(linkId, uiText)
            end
            uiText.onClickLink:RemoveAllListeners()
            uiText.onClickLink:AddListener(func)
            table.insert(self.m_clickListeners, { uiText = uiText, func = func })
        end
    end

    if args.keyHintText then
        InputManagerInst:SetBindingText(self.view.naviGroup.FocusBindingId, args.keyHintText)
    end
    self.view.naviGroup.onIsFocusedChange:RemoveAllListeners()
    self.view.naviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if isFocused then
            self:EnterNavi()
        else
            self:ExitNavi()
        end
    end)
    self.view.naviGroup.enabled = self.m_hasItemTags and self.m_enableNavi
    self.view.naviGroup:RefreshFocusBindings()
end


ItemRichText.EnterNavi = HL.Method(HL.Opt(HL.Function)) << function(self, onExit)
    if not DeviceInfo.usingController then
        return
    end
    self.m_onExit = onExit
    self:_InitNaviBindings()
    
    self:_BuildTextDataList()
    if #self.m_textDataList <= 0 then
        
        return
    end
    self.m_targetTextIndex = 1
    self.m_textDataList[1].curFocusIndex = 1
    self.m_isNavi = true
    self:_RefreshFocusBox()
end


ItemRichText.ExitNavi = HL.Method() << function(self)
    self.m_isNavi = false
    Notify(MessageConst.HIDE_CONTROLLER_NAVI_TEXT_HINT)
end


ItemRichText.RefreshNavi = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local prevTextIndex = self.m_targetTextIndex
    local prevData = self.m_textDataList[prevTextIndex]
    local prevFocus = prevData and prevData.curFocusIndex or 1
    self:_BuildTextDataList()
    if #self.m_textDataList <= 0 then
        self:ExitNavi()
        return
    end
    self.m_targetTextIndex = math.max(1, math.min(prevTextIndex, #self.m_textDataList))
    local cur = self.m_textDataList[self.m_targetTextIndex]
    cur.curFocusIndex = math.max(1, math.min(prevFocus, #cur.linkDataList))
    self:_RefreshFocusBox()
end

ItemRichText.MoveNaviRight = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local textData = self.m_textDataList[self.m_targetTextIndex]
    local nextIndex = textData.curFocusIndex + 1
    if nextIndex <= #textData.linkDataList then
        textData.curFocusIndex = nextIndex
        self:_OnFocusMoved()
    elseif self.m_targetTextIndex < #self.m_textDataList then
        
        self.m_targetTextIndex = self.m_targetTextIndex + 1
        self.m_textDataList[self.m_targetTextIndex].curFocusIndex = 1
        self:_OnFocusMoved()
    else
        self:_RequestExit("right")
    end
end

ItemRichText.MoveNaviLeft = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local textData = self.m_textDataList[self.m_targetTextIndex]
    local nextIndex = textData.curFocusIndex - 1
    if nextIndex >= 1 then
        textData.curFocusIndex = nextIndex
        self:_OnFocusMoved()
    elseif self.m_targetTextIndex > 1 then
        
        self.m_targetTextIndex = self.m_targetTextIndex - 1
        local prev = self.m_textDataList[self.m_targetTextIndex]
        prev.curFocusIndex = #prev.linkDataList
        self:_OnFocusMoved()
    else
        self:_RequestExit("left")
    end
end

ItemRichText.MoveNaviDown = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local textData = self.m_textDataList[self.m_targetTextIndex]
    local nextIndex = HyperTextNaviHelper.GetNextLinkIndexDown(textData)
    if nextIndex > 0 then
        textData.curFocusIndex = nextIndex
        self:_OnFocusMoved()
    elseif self.m_targetTextIndex < #self.m_textDataList then
        self.m_targetTextIndex = self.m_targetTextIndex + 1
        self.m_textDataList[self.m_targetTextIndex].curFocusIndex = 1
        self:_OnFocusMoved()
    else
        self:_RequestExit("down")
    end
end

ItemRichText.MoveNaviUp = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local textData = self.m_textDataList[self.m_targetTextIndex]
    local nextIndex = HyperTextNaviHelper.GetNextLinkIndexUp(textData)
    if nextIndex > 0 then
        textData.curFocusIndex = nextIndex
        self:_OnFocusMoved()
    elseif self.m_targetTextIndex > 1 then
        self.m_targetTextIndex = self.m_targetTextIndex - 1
        local prev = self.m_textDataList[self.m_targetTextIndex]
        prev.curFocusIndex = #prev.linkDataList
        self:_OnFocusMoved()
    else
        self:_RequestExit("up")
    end
end






ItemRichText._ResolveItemTags = HL.StaticMethod(HL.String, HL.String).Return(HL.String, HL.Number) << function(rawText, styleKey)
    local result, count = string.gsub(rawText, "<itemId=([^>]+)>", function(itemId)
        local success, itemData = Tables.itemTable:TryGetValue(itemId)
        if not success then
            logger.error("[ItemRichText] invalid itemId in <item> tag: " .. tostring(itemId))
            return nil 
        end
        return string.format('<link="%s%s"><image="ItemIcon/%s" scale=1.25><@%s>%s</></link>',
            UIConst.UI_TEXT_ITEM_LINK_PREFIX, itemId, itemData.iconId, styleKey, itemData.name)
    end)
    return result, count
end

ItemRichText._ResolveItemIdFromLink = HL.StaticMethod(HL.String).Return(HL.Opt(HL.String)) << function(linkId)
    if not string.startWith(linkId, UIConst.UI_TEXT_ITEM_LINK_PREFIX) then
        return nil
    end
    return string.sub(linkId, #UIConst.UI_TEXT_ITEM_LINK_PREFIX + 1)
end

ItemRichText._ClearClickListeners = HL.Method() << function(self)
    if self.m_clickListeners then
        for _, listener in ipairs(self.m_clickListeners) do
            if not IsNull(listener.uiText) then
                listener.uiText.onClickLink:RemoveListener(listener.func)
            end
        end
    end
    self.m_clickListeners = {}
end


ItemRichText._BuildTextDataList = HL.Method() << function(self)
    local list = {}
    if self.m_texts then
        for i = 1, #self.m_texts do
            local uiText = self.m_texts[i].uiText
            if not IsNull(uiText) then
                uiText:ForceMeshUpdate()
                local textData = HyperTextNaviHelper.WrapHyperTextData(uiText)
                if #textData.linkDataList > 0 then
                    table.insert(list, textData)
                end
            end
        end
    end
    self.m_textDataList = list
end

ItemRichText._OnFocusMoved = HL.Method() << function(self)
    self:_RefreshFocusBox()
    AudioManager.PostEvent("Au_UI_Hover_ControllerSelect")
end

ItemRichText._OnClickLink = HL.Method(HL.String, CS.Beyond.UI.UIText) << function(self, linkId, uiText)
    local itemId = ItemRichText._ResolveItemIdFromLink(linkId)
    if itemId then
        self:_ShowItemTips(itemId, uiText)
    end
end

ItemRichText._ShowItemTips = HL.Method(HL.String, CS.Beyond.UI.UIText) << function(self, itemId, uiText)
    Notify(MessageConst.SHOW_ITEM_TIPS, {
        transform = self.m_tipTransform or uiText.transform,
        itemId = itemId,
        posType = self.m_tipsPosType,
        isSideTips = DeviceInfo.usingController,
        onBeforeJump = function()
            if DeviceInfo.usingController then
                self.view.naviGroup:ManuallyStopFocus()
            end
        end,
    })
end


ItemRichText._RefreshFocusBox = HL.Method() << function(self)
    if not self.m_isNavi then
        return
    end
    local textData = self.m_textDataList[self.m_targetTextIndex]
    if not textData then
        Notify(MessageConst.HIDE_CONTROLLER_NAVI_TEXT_HINT)
        return
    end
    local focusIndex = textData.curFocusIndex
    if focusIndex > 0 and focusIndex <= #textData.linkDataList then
        local linkData = textData.linkDataList[focusIndex]
        Notify(MessageConst.SHOW_CONTROLLER_NAVI_TEXT_HINT, {
            uiText = textData.uiText,
            startCharIndex = linkData.startCharIndex,
            endCharIndex = linkData.endCharIndex,
        })
        local itemId = ItemRichText._ResolveItemIdFromLink(linkData.linkId)
        self:_ShowItemTips(itemId, textData.uiText)
    else
        Notify(MessageConst.HIDE_CONTROLLER_NAVI_TEXT_HINT)
    end
end

ItemRichText._InitNaviBindings = HL.Method() << function(self)
    if self.m_naviBindInited then
        return
    end
    self.m_naviBindInited = true
    self:BindInputPlayerAction("common_navigation_4_dir_up_no_hint", function()
        self:MoveNaviUp()
    end)
    self:BindInputPlayerAction("common_navigation_4_dir_down", function()
        self:MoveNaviDown()
    end)
    self:BindInputPlayerAction("common_navigation_4_dir_left", function()
        self:MoveNaviLeft()
    end)
    self:BindInputPlayerAction("common_navigation_4_dir_right", function()
        self:MoveNaviRight()
    end)
end

ItemRichText._RequestExit = HL.Method(HL.String) << function(self, direction)
    if self.m_onExit then
        self.m_onExit(direction)
    end
end



ItemRichText._OnDisable = HL.Override() << function(self)
    if self.m_isNavi then
        self:ExitNavi()
    end
end

ItemRichText._OnDestroy = HL.Override() << function(self)
    if self.m_isNavi then
        self:ExitNavi()
    end
    self:_ClearClickListeners()
end

HL.Commit(ItemRichText)
return ItemRichText
