local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local json = require("Common/Tools/json")
local PANEL_ID = PanelId.CommonShare
local waterMarkScale = 0.074




















CommonShareCtrl = HL.Class('CommonShareCtrl', uiCtrl.UICtrl)

local CLEAR_PANEL_ON_SHUTTER = {
    PanelId.Radio,
    PanelId.CommonToast,
    PanelId.LevelToast,
    PanelId.GuideLimited,
    PanelId.Marquee,
}


CommonShareCtrl.m_showPlayerInfo = HL.Field(HL.Boolean) << true


CommonShareCtrl.m_arg = HL.Field(HL.Any) << nil


CommonShareCtrl.m_isSaved = HL.Field(HL.Boolean) << false


CommonShareCtrl.m_isInfoSaved = HL.Field(HL.Boolean) << false


CommonShareCtrl.m_onClose = HL.Field(HL.Function)


CommonShareCtrl.m_type = HL.Field(HL.String) << ""


CommonShareCtrl.m_channelIdList = HL.Field(HL.Table) << nil


CommonShareCtrl.m_clickSaveBtn = HL.Field(HL.Boolean) << false






CommonShareCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SHARE_END] = 'OnShareEnd',
}



CommonShareCtrl.ScreenCaptureAndShare = HL.StaticMethod(HL.Any) << function(arg)
    if arg == nil then
        logger.error("CommonShareCtrl.ScreenCaptureAndShare: arg is nil")
        return
    end

    
    
    
    
    
    
    
    
    
    

    local this = UIManager:Open(PANEL_ID, arg)
    
    logger.info("CommonShareCtrl.ScreenCaptureAndShare: Sharing screen capture")
    if arg and not arg.rt then
        for _, id in pairs(CLEAR_PANEL_ON_SHUTTER) do
            UIManager:HideWithKey(id, "CommonShare")
        end
        CoroutineManager:StartCoroutine(function()
            
            local rt = CS.Beyond.UI.ScreenCaptureUtils.GetScreenCapture()
            arg.rt = rt

            
            local realScale = math.floor(Screen.height * waterMarkScale) / Screen.height
            waterMarkScale = realScale
            
            coroutine.waitForRenderDone()
            coroutine.step()
            local scale = waterMarkScale + 1
            local ratio = 1
            if this.view.rectTransform.rect.height > 0 then
                ratio = this.view.rectTransform.rect.width / this.view.rectTransform.rect.height
                this.view.hideRoot.aspectRatio = ratio
                LayoutRebuilder.ForceRebuildLayoutImmediate(this.view.hideRoot.transform)
            end
            local photoRealHeight = this.view.photoImgWithWaterMark.rectTransform.rect.width / ratio
            local offset = photoRealHeight * waterMarkScale / 2
            this.view.photoImgWithWaterMark.rectTransform.offsetMin = Vector2(this.view.photoImgWithWaterMark.rectTransform.offsetMin.x, -offset)
            this.view.photoImgWithWaterMark.rectTransform.offsetMax = Vector2(this.view.photoImgWithWaterMark.rectTransform.offsetMax.x, offset)
            this.view.bottomNodeWaterMarkForCamera.rectTransform.sizeDelta = Vector2(0, math.floor(this.view.rectTransform.rect.height * waterMarkScale + 3))
            this.view.bottomNodeWaterMarkUIForPos.rectTransform.sizeDelta = Vector2(0, photoRealHeight * waterMarkScale)
            coroutine.step()
            coroutine.step()
            local waterRt = CS.Beyond.UI.ScreenCaptureUtils.GetWaterMarkRT(scale, rt)
            arg.waterRt = waterRt
            coroutine.waitForRenderDone()
            coroutine.step()
            coroutine.step()
            for _, id in pairs(CLEAR_PANEL_ON_SHUTTER) do
                UIManager:ShowWithKey(id, "CommonShare")
            end
            this:OnCaptureEnd()
            this.animationWrapper:PlayInAnimation()
        end)
    else
        logger.error("CommonShareCtrl.ScreenCaptureAndShare: arg.rt is not nil, must be nil")
    end
end





CommonShareCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    
    
    
    
    self.view.stateController:SetState(arg.needEdge == false and "HideAll" or "Hide")
    self:_StartCoroutine(function()
        coroutine.step()
        coroutine.step()
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputBindingGroupMonoTarget.groupId })
    end)
    self.m_arg = arg
    self.m_onClose = arg.onClose
    self.m_type = arg.type
    self.view.copyBtn.onClick:RemoveAllListeners()
    self.view.copyBtn.onClick:AddListener(function()
        logger.info("CommonShareCtrl.OnCreate: Copy button clicked")
        if self.m_type == "Blueprint" then
            Unity.GUIUtility.systemCopyBuffer = string.format(Language.LUA_BLUEPRINT_SHARE_COPY_TIPS, arg.codeId)
        else
            Unity.GUIUtility.systemCopyBuffer = arg.codeId
        end
        EventLogManagerInst:GameEvent_CommonShareAction(self.m_type, self.m_channelIdList, "copy","")
        Notify(MessageConst.SHOW_TOAST, Language.LUA_SHARE_COPY_TIP)
    end)

    self.view.closeBtn.onClick:RemoveAllListeners()
    self.view.closeBtn.onClick:AddListener(function()
        if self.m_arg.isCloseFast then
            self:Close()
        else
            self:PlayAnimationOutAndClose()
        end
    end)

    if arg.showPlayerInfoToggle ~= false then
        self.view.playerInfoToggle.onValueChanged:RemoveAllListeners()
        self.view.playerInfoToggle.onValueChanged:AddListener(function(isOn)
            self.m_showPlayerInfo = isOn
            self:_ChangePlayerInfo()
        end)
        self.view.playerInfoToggle.gameObject:SetActiveIfNecessary(true)
    else
        self.view.playerInfoToggle.gameObject:SetActiveIfNecessary(false)
    end

    self.view.saveBtn.onClick:RemoveAllListeners()
    self.view.saveBtn.onClick:AddListener(function()
        logger.info("CommonShareCtrl.OnCreate: Save button clicked")
        EventLogManagerInst:GameEvent_CommonShareAction(self.m_type, self.m_channelIdList, "save","")
        if self.m_type == "PhotoShot" then
            EventLogManagerInst:GameEvent_Snapshot(3)
        end
        if self.m_showPlayerInfo and self.m_isInfoSaved then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_COMMON_SHARE_SAVED)
            return
        end
        if not self.m_showPlayerInfo and self.m_isSaved then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_COMMON_SHARE_SAVED)
            return
        end
        local currentPlatform = CS.UnityEngine.Application.platform
        local savePath = ""
        local isMob = DeviceInfo.isMobile
        local fileName = isMob and "ENDFIELD_SHARE_TEMP.png" or string.format("ENDFIELD_SHARE_%s.png", CS.Beyond.DateTimeUtils.GetCurrentTimestampBySeconds())
        if UNITY_STANDALONE_WIN or UNITY_EDITOR_WIN then
            savePath = CS.System.IO.Path.Combine(CS.System.Environment.GetFolderPath(CS.System.Environment.SpecialFolder.MyPictures),"ENDFIELD", fileName)
        else
            savePath = isMob and CS.System.IO.Path.Combine(CS.UnityEngine.Application.temporaryCachePath, fileName) or CS.System.IO.Path.Combine(CS.UnityEngine.Application.persistentDataPath, fileName)
        end

        local isSave = 0
        
        isSave = CS.Beyond.UI.ScreenCaptureUtils.SaveScreenCapture(self.m_showPlayerInfo and self.m_arg.waterRt or self.m_arg.rt, savePath)
        if not UNITY_EDITOR and currentPlatform == CS.UnityEngine.RuntimePlatform.PS5 then
            
            CS.Beyond.PS5ContentManager.instance:ExportContentFromFile(savePath, fileName)
            
            return
        end

        
        if isSave == CS.Beyond.UI.ScreenCaptureUtils.SaveErrorCode.None then
            if self.m_showPlayerInfo then
                self.m_isInfoSaved = true
            else
                self.m_isSaved = true
            end
            
            if isMob then
                local dataStr = Json.encode({
                    shareChannel = 0, 
                    imgPath = savePath,
                    title = self.m_type == "Blueprint" and string.format(Language.LUA_SHARE_BLUEPRINT_TITLE, self.m_arg.codeId) or Language.LUA_SHARE_PHOTO_TITLE,
                    desc = self.m_type == "Blueprint" and string.format(Language.LUA_SHARE_BLUEPRINT_DESC, self.m_arg.codeId) or Language.LUA_SHARE_PHOTO_DESC,
                    extraData = "{}",
                })
                CS.U8.SDK.U8SDKInterface.Instance:SetData(CS.Beyond.SDK.SDKDataType.SET_DATA_SHARE, dataStr)
                self.m_clickSaveBtn = true
                
                
            elseif currentPlatform == CS.UnityEngine.RuntimePlatform.WindowsPlayer or currentPlatform == CS.UnityEngine.RuntimePlatform.WindowsEditor then
                Notify(MessageConst.SHOW_TOAST, {Language.LUA_COMMON_SHARE_SAVE_SUCCESS .. savePath, 4})
            else
                Notify(MessageConst.SHOW_TOAST, Language.LUA_COMMON_SHARE_SAVE_SUCCESS .. savePath)
            end
            logger.info(Language.LUA_SHARE_SAVE_SUCCESS .. savePath)
        elseif isSave == CS.Beyond.UI.ScreenCaptureUtils.SaveErrorCode.NoSpace then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_COMMON_SHARE_SAVE_NO_SPACE)
            logger.info(Language.LUA_COMMON_SHARE_SAVE_NO_SPACE)
        elseif isSave == CS.Beyond.UI.ScreenCaptureUtils.SaveErrorCode.PermissionDenied then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_COMMON_SHARE_SAVE_PERMISSION_DENIED)
            logger.info(Language.LUA_COMMON_SHARE_SAVE_PERMISSION_DENIED)
        end
    end)

    if arg == nil then
        logger.error("CommonShareCtrl.OnCreate: arg is nil")
        return
    end

    self.m_showPlayerInfo = arg.showPlayerInfo == nil and true or arg.showPlayerInfo
    self:_ChangePlayerInfo()

    
    self:_UpdateWaterInfo()
end



CommonShareCtrl.OnCaptureEnd = HL.Method() << function(self)
    if self.m_arg.onCaptureEnd then
        self.m_arg.onCaptureEnd()
    end

    self.view.photoImg.texture = self.m_arg.rt
    self.view.photoImgWithWaterMark.texture = self.m_arg.waterRt

    self.view.stateController:SetState("Show")
    if self.m_arg.type then
        self.view.stateController:SetState(self.m_arg.type)
    end
    self:_ChangePlayerInfo()
    
    self:_OnFadeInEnd()
end



CommonShareCtrl._UpdateWaterInfo = HL.Method() << function(self)
    self.view.bottomNodeWaterMarkUIForPos:InitBottomNodeWaterMarkUI(self.m_arg)
    self.view.bottomNodeWaterMarkForCamera:InitBottomNodeWaterMarkUI(self.m_arg)
end



CommonShareCtrl._ChangePlayerInfo = HL.Method() << function(self)
    if self.m_arg.rt == nil then
        return
    end
    if self.m_showPlayerInfo then
        self.view.photoImg.gameObject:SetActiveIfNecessary(false)
        self.view.photoImgWithWaterMark.gameObject:SetActiveIfNecessary(true)
        self.view.copyBtn.gameObject:SetActiveIfNecessary(true)
    else
        self.view.photoImg.gameObject:SetActiveIfNecessary(true)
        self.view.photoImgWithWaterMark.gameObject:SetActiveIfNecessary(false)
        self.view.copyBtn.gameObject:SetActiveIfNecessary(false)
    end
end



CommonShareCtrl._OnFadeInEnd = HL.Method() << function(self)
    


    
    self.view.succHintNode.gameObject:SetActiveIfNecessary(self.m_arg.success == true)

    if self.m_arg.showPlayerInfo == nil then
        self.view.playerInfoToggle.isOn = true
    else
        self.view.playerInfoToggle.isOn = self.m_arg.showPlayerInfo
    end

    local genTabCells = UIUtils.genCellCache(self.view.shareCell)

    local sdkInfo = {}
    self.m_channelIdList = {}
    local canShare = DeviceInfo.isMobile
    if canShare then
        local list = {}
        if CS.Beyond.SDK.SDKConsts.IsOverseaVersion() then
            
            list = Tables.overseaShareTable:GetValue(CS.Beyond.GameSetting.languageText).shareChannelIdList
        else
            
            list = Tables.shareTable:GetValue(CS.Beyond.SDK.SDKConsts.IsBilibiliVersion() and 1 or 0).shareChannelIdList
        end

        for i = 0, list.Count - 1 do
            
            local success, cfg = Tables.shareChannelTable:TryGetValue(list[i])

            if success and list[i] ~= 0 and (GameInstance.player.friendSystem.ShareControl & (1 << list[i])) == 0 then
                table.insert(sdkInfo, {
                    icon = cfg.icon,
                    id = cfg.shareChannelId,
                    sort = cfg.sort,
                })
            end
        end

        table.sort(sdkInfo, function(a, b)
            return a.sort < b.sort
        end)

        genTabCells:Refresh(#sdkInfo, function(cell, luaIndex)
            local info = sdkInfo[luaIndex]
            cell.gameObject.name = "ShareCell_" .. luaIndex
            
            local fileName = "ENDFIELD_SHARE_TEMP.png"
            cell.shareImg:LoadSprite(UIConst.UI_SPRITE_SHARE_ICON, info.icon)
            cell.shareBtn.onClick:RemoveAllListeners()
            cell.shareBtn.onClick:AddListener(function()
                local savePath = CS.System.IO.Path.Combine(CS.UnityEngine.Application.temporaryCachePath, fileName)
                CS.Beyond.UI.ScreenCaptureUtils.SaveScreenCapture(self.m_showPlayerInfo and self.m_arg.waterRt or self.m_arg.rt, savePath)
                local dataStr = Json.encode({
                    shareChannel = info.id,
                    imgPath = savePath,
                    title = self.m_type == "Blueprint" and string.format(Language.LUA_SHARE_BLUEPRINT_TITLE, self.m_arg.codeId) or Language.LUA_SHARE_PHOTO_TITLE,
                    desc = self.m_type == "Blueprint" and string.format(Language.LUA_SHARE_BLUEPRINT_DESC, self.m_arg.codeId) or Language.LUA_SHARE_PHOTO_DESC,
                    extraData = "{}",
                })
                CS.U8.SDK.U8SDKInterface.Instance:SetData(CS.Beyond.SDK.SDKDataType.SET_DATA_SHARE, dataStr)
                if self.m_type == "PhotoShot" then
                    EventLogManagerInst:GameEvent_Snapshot(4)
                end
            end)
        end)
        self.view.shareMaxLayout.gameObject:SetActiveIfNecessary(#sdkInfo > 0)
        for _, info in ipairs(sdkInfo) do
            table.insert(self.m_channelIdList, info.id)
        end
    else
        self.view.shareMaxLayout.gameObject:SetActiveIfNecessary(false)
    end
    EventLogManagerInst:GameEvent_CommonShareStart(self.m_type, self.m_channelIdList, "")
end



CommonShareCtrl.OnShareEnd = HL.Method() << function(self, args)
    local code = unpack(args)
    if self.m_clickSaveBtn then
        self.m_clickSaveBtn = false
        logger.info("CommonShareCtrl.OnShareEnd: Share ended with code " .. tostring(code))
        Notify(MessageConst.SHOW_TOAST, code == 0 and Language.LUA_COMMON_SHARE_SAVE_SUCCESS or Language.LUA_COMMON_SHARE_SAVE_PERMISSION_DENIED)
        EventLogManagerInst:GameEvent_CommonShareEnd(self.m_type, self.m_channelIdList, tostring(code), "")
        return
    end
    logger.info("CommonShareCtrl.OnShareEnd: Share ended with code " .. tostring(code))
    Notify(MessageConst.SHOW_TOAST, code == 0 and Language.LUA_COMMON_SHARE_SUCCESS or Language.LUA_COMMON_SHARE_FAIL)
    EventLogManagerInst:GameEvent_CommonShareEnd(self.m_type, self.m_channelIdList, tostring(code), "")
end



CommonShareCtrl.OnShow = HL.Override() << function(self)
    UIManager:Hide(PanelId.UIDPanel)
end



CommonShareCtrl.OnClose = HL.Override() << function(self)
    UIManager:Show(PanelId.UIDPanel)
    if self.m_arg and self.m_arg.rt then
        
        CS.Beyond.UI.ScreenCaptureUtils.Release()
    end
    if self.m_onClose then
        self.m_onClose()
    end
end




HL.Commit(CommonShareCtrl)
