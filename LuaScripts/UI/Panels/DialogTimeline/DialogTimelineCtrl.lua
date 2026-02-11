local dialogCtrlBase = require_ex('UI/Panels/Dialog/DialogCtrlBase')
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DialogTimeline





































DialogTimelineCtrl = HL.Class('DialogTimelineCtrl', dialogCtrlBase.DialogCtrlBase)


local DIALOG_TEXT_HIDE_DELAY_TIME<const> = 0.2
local DIALOG_BOTTOM_IN_ANIMATION<const> = "dialog_bottom_in"
local DIALOG_BOTTOM_OUT_ANIMATION<const> = "dialog_bottom_out"







DialogTimelineCtrl.s_overrideMessages = HL.StaticField(HL.Table) << {
    [MessageConst.UI_DIALOG_TEXT_STOPPED] = 'OnDialogTextStopped',
    [MessageConst.ON_DIALOG_TIMELINE_START_TRUNK] = 'OnDialogTimelineStartTrunk',
    [MessageConst.ON_DIALOG_TIMELINE_STOP_TRUNK] = 'OnDialogTimelineStopTrunk',
    [MessageConst.ON_DIALOG_TIMELINE_START_LEFT_SUBTITLE] = 'OnDialogTimelineStartLeftSubTitle',
    [MessageConst.ON_LOAD_NEW_DLG_TIMELINE] = 'OnLoadNewDialogTimeline',
    [MessageConst.REFRESH_DIALOG_TIMELINE_CAN_CLICK] = 'RefreshCanClick',
    [MessageConst.SWITCH_DIALOG_CAN_SKIP] = 'OnSwitchDialogCanSkip',
    [MessageConst.DIALOG_SHOW_DEV_WATER_MARK] = 'ShowDevWaterMark',
    [MessageConst.DIALOG_TIMELINE_REFRESH_AUTO_MODE] = 'OnRefreshAutoMode',
}


DialogTimelineCtrl.m_timelineHandle = HL.Field(HL.Userdata)


DialogTimelineCtrl.m_dialogTextStopped = HL.Field(HL.Boolean) << true


DialogTimelineCtrl.m_hasShowedDialogText = HL.Field(HL.Boolean) << false


DialogTimelineCtrl.m_isDialogTextShowing = HL.Field(HL.Boolean) << false


DialogTimelineCtrl.m_canSkip = HL.Field(HL.Boolean) << true


DialogTimelineCtrl.m_showingTrunkId = HL.Field(HL.String) << ""


DialogTimelineCtrl.m_dialogTextHideTimer = HL.Field(HL.Number) << -1


DialogTimelineCtrl.m_fmvNodeMap = HL.Field(HL.Table)



DialogTimelineCtrl.OnPreloadDialogTimelinePanel = HL.StaticMethod(HL.Table) << function(arg)
    local preloadFinishCallback = unpack(arg)
    
    UIManager:PreloadPanelAsset(PANEL_ID, PhaseId.Dialog, function()
        if preloadFinishCallback ~= nil then
            preloadFinishCallback()
        end
    end)
end




DialogTimelineCtrl.OnCreated = HL.Override(HL.Any) << function(self, arg)
    
    self.view.dialogTimelineText:UpdateAlpha(0)

    
    self.view.topLeft.gameObject:SetActive(false)
    self.view.topRight.gameObject:SetActive(false)
    self.view.imageBG.gameObject:SetActive(false)

    self.m_fmvNodeMap = {}
    self.m_dialogTextStopped = true
    self.m_timelineHandle = unpack(arg)
    GameWorld.dialogTimelineManager:BindUIDialogTimelineText(self.m_timelineHandle, self.view.dialogTimelineText)
    GameWorld.dialogTimelineManager:BindSubtitle(self.m_timelineHandle, self.view.subtitlePanel)
end



DialogTimelineCtrl.GetCurDialogId = HL.Override().Return(HL.String) << function(self)
    return GameWorld.dialogTimelineManager.dialogId
end



DialogTimelineCtrl.OnDialogTimelineStartLeftSubTitle = HL.Method() << function(self)
end




DialogTimelineCtrl.OnDialogTimelineStartTrunk = HL.Method(HL.Table) << function(self, arg)
    if not self.m_hasShowedDialogText then
        self.view.dialogTimelineText:UpdateAlpha(1)
        
        self.view.topLeft.gameObject:SetActive(true)
        self.view.topRight.gameObject:SetActive(true)
        self.view.imageBG.gameObject:SetActive(true)
        self.m_hasShowedDialogText = true
    end
    self.m_dialogTextStopped = false
    self.m_showingTrunkId = unpack(arg)
    self:_TryShowDialogTextWithAnimation()
    self:_TrySetWaitNode(false)
    self:_RefreshCanSkip()
end



DialogTimelineCtrl._TryShowDialogTextWithAnimation = HL.Method() << function(self)
    if self.m_dialogTextHideTimer > 0 then
        self.m_dialogTextHideTimer = self:_ClearTimer(self.m_dialogTextHideTimer)
    end

    if not self.m_isDialogTextShowing then
        self.m_isDialogTextShowing = true
        self:PlayAnimation(DIALOG_BOTTOM_IN_ANIMATION)
    end
end




DialogTimelineCtrl.OnDialogTimelineStopTrunk = HL.Method(HL.Table) << function(self, arg)
    local trunkId = unpack(arg)
    if self.m_showingTrunkId ~= trunkId then
        return
    end

    self.m_showingTrunkId = ""
    self:_TryHideDialogTextWithAnimation()
end




DialogTimelineCtrl.OnSwitchDialogCanSkip = HL.Method(HL.Table) << function(self, arg)
    self:_RefreshCanSkip()
end



DialogTimelineCtrl._RefreshCanSkip = HL.Override() << function(self)
    self.m_canSkip = GameWorld.dialogManager.canSkip
    self.view.buttonSkip.gameObject:SetActive(self.m_canSkip)
end




DialogTimelineCtrl._TryHideDialogTextWithAnimation = HL.Method() << function(self)
    
    if self.m_dialogTextHideTimer < 0 then
        self.m_dialogTextHideTimer = self:_StartTimer(DIALOG_TEXT_HIDE_DELAY_TIME, function()
            if not self:IsPlayingAnimationOut() then
                self.m_isDialogTextShowing = false
                self:PlayAnimation(DIALOG_BOTTOM_OUT_ANIMATION)
            end
        end)
    end
end




DialogTimelineCtrl.OnLoadNewDialogTimeline = HL.Method(HL.Any) << function(self, arg)
    self.m_timelineHandle = unpack(arg)
end



DialogTimelineCtrl.OnDialogShow = HL.Override() << function(self)
    DialogTimelineCtrl.Super.OnDialogShow(self)
    self:_RefreshAutoMode(GameWorld.dialogTimelineManager.autoMode)
    self:_RefreshCanSkip()
    local dialogTimelineManager = GameWorld.dialogTimelineManager

    local hasMask = dialogTimelineManager:BindDialogMask(self.view.mask)
    self.view.mask.gameObject:SetActive(hasMask)
    dialogTimelineManager:BindLeftSubtitle(self.m_timelineHandle, self.view.leftSubtitlePanel)
    dialogTimelineManager:BindPostProcessEffect(self.m_timelineHandle, self.view.postProcessEffect)

    for fmvId, fmvPath in pairs(self.m_timelineHandle.loadedPanelFmv) do
        local node = self:GetLoadedFMVNode(fmvId, fmvPath)
        node:StartAutoKeepAspectRatio()
        node:SetUserTimeCorrectionThreshold(0)
        dialogTimelineManager:BindPanelFMVNode(self.m_timelineHandle, fmvId, node.view.movieController)
    end

    if self.m_timelineHandle.loadedPanelFmv.Count > 0 then
        self.view.fmvGroup.gameObject:SetActive(true)
    else
        self.view.fmvGroup.gameObject:SetActive(false)
    end
end





DialogTimelineCtrl.OnBtnNextClick = HL.Override() << function(self)
    if GameWorld.dialogTimelineManager.canClick then
        if self:CheckTextPlaying() then
            self.view.textTalk:SeekToEnd()
            self:_TrySetWaitNode(true)
        else
            GameWorld.dialogTimelineManager:Next()
        end
    end
end



DialogTimelineCtrl.OnBtnAutoClick = HL.Override() << function(self)
    local auto = not GameWorld.dialogTimelineManager.autoMode
    GameWorld.dialogTimelineManager:SetAutoMode(auto)
end



DialogTimelineCtrl.OnBtnLogClick = HL.Override() << function(self)
    self:Notify(MessageConst.OPEN_DIALOG_TIMELINE_RECORD)
end



DialogTimelineCtrl._GetCurrentAutoMode = HL.Override().Return(HL.Boolean) << function(self)
    return GameWorld.dialogTimelineManager.autoMode
end





DialogTimelineCtrl.OnOptionClick = HL.Override(HL.Number, HL.Any) << function(self, index, data)
    GameWorld.dialogTimelineManager:SelectIndex(CSIndex(index))
end



DialogTimelineCtrl.OnBtnSkipClick = HL.Override() << function(self)
    self:Notify(MessageConst.OPEN_DIALOG_TIMELINE_SKIP_POP_UP)
end




DialogTimelineCtrl.OnDialogTextStopped = HL.Override() << function(self)
    self.m_dialogTextStopped = true
    self:_TrySetWaitNode(GameWorld.dialogTimelineManager.canClick)
end




DialogTimelineCtrl.RefreshCanClick = HL.Method(HL.Table) << function(self, _)
    self:_TrySetWaitNode(self.m_dialogTextStopped)
end




DialogTimelineCtrl._TrySetWaitNode = HL.Override(HL.Boolean) << function(self, active)
    self.view.waitNode.gameObject:SetActive(active)
    self.view.centerWaitNode.gameObject:SetActive(active)
end



DialogTimelineCtrl.OnClose = HL.Override() << function(self)
    if self.m_dialogTextHideTimer > 0 then
        self.m_dialogTextHideTimer = self:_ClearTimer(self.m_dialogTextHideTimer)
    end
    self:ClearFMV()

    DialogTimelineCtrl.Super.OnClose(self)
end






DialogTimelineCtrl.StopFMV = HL.Method(HL.String) << function(self, fmvId)
    local fmvNode = self.m_fmvNodeMap[fmvId]
    if not fmvNode then
        return
    end

    fmvNode:StopVideo(true)

    fmvNode.gameObject:SetActive(false)
    self.m_fmvNodeMap[fmvId] = nil
    if next(self.m_fmvNodeMap) == nil then
        self.view.fmvGroup.gameObject:SetActive(false)
    end
end




DialogTimelineCtrl.OnStopFMV = HL.Method(HL.Table) << function(self, arg)
    local fmvId = unpack(arg)
    self:StopFMV(fmvId)
end



DialogTimelineCtrl.ClearFMV = HL.Method() << function(self)
    lume.each(lume.keys(self.m_fmvNodeMap), function(fmvId) self:StopFMV(fmvId) end)
end





DialogTimelineCtrl.GetLoadedFMVNode = HL.Method(HL.String, HL.String).Return(HL.Any) << function(self, fmvId, fmvPath)
    if self.m_fmvNodeMap[fmvId] then
        return self.m_fmvNodeMap[fmvId]
    end

    local isOpen, preloader = UIManager:IsOpen(PanelId.VideoPreloader)

    local node = nil
    if isOpen then
        node = preloader:MovePreloadedVideoNode(fmvId, self.view.fmvGroup)
    end

    if node == nil then
        local rawNode = UIUtils.addChild(self.view.fmvGroup, self.view.fmvTemplate)
        node = Utils.wrapLuaNode(rawNode)
        node.gameObject:SetActive(true)
        node:PreloadVideo(fmvPath)
        logger.error("FMV node not preloaded!!! gen new node for fmvId: ", fmvId)
    end

    self.m_fmvNodeMap[fmvId] = node
    return node
end


HL.Commit(DialogTimelineCtrl)
