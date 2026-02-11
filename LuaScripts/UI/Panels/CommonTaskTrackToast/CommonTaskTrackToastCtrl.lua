
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonTaskTrackToast

local ToastType = {
    Start = "StartToast",
    Fail = "FailToast",
    Finish = "FinishToast",
    Countdown = "CountdownToast",
}
local CountdownToast = "CountdownToast"


local WorldChallengeStartToast = "WorldChallengeStartToast"


















CommonTaskTrackToastCtrl = HL.Class('CommonTaskTrackToastCtrl', uiCtrl.UICtrl)


CommonTaskTrackToastCtrl.m_countDownTickId = HL.Field(HL.Number) << -1


CommonTaskTrackToastCtrl.m_showingToastCor = HL.Field(HL.Thread)







CommonTaskTrackToastCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_SUB_GAME_RESET] = "OnSubGameReset",
}



CommonTaskTrackToastCtrl.OnShowCommonTaskCountdownToast = HL.StaticMethod(HL.Any) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackStartCountdown", function()
        
        local ctrl = CommonTaskTrackToastCtrl.AutoOpen(PANEL_ID, nil, true)
        if ctrl == nil then
            return
        end

        ctrl:ShowCountdownToast(args)
    end)
end



CommonTaskTrackToastCtrl.OnShowCommonTaskStartToast = HL.StaticMethod(HL.Any) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackStartToast", function()
        
        local ctrl = CommonTaskTrackToastCtrl.AutoOpen(PANEL_ID, nil, true)
        if ctrl == nil then
            return
        end

        ctrl:ShowTaskStartToast(args, function()
            Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackStartToast")
            Notify(MessageConst.SHOW_DUNGEON_TOAST, args)
        end)
    end, function()
        UIManager:Close(PANEL_ID)
        Notify(MessageConst.ON_HUD_BTN_VISIBLE_CHANGE, {true})
    end)
end



CommonTaskTrackToastCtrl.OnShowCommonTaskFinishToast = HL.StaticMethod(HL.Any) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackEndToastNW", function()
        
        local ctrl = CommonTaskTrackToastCtrl.AutoOpen(PANEL_ID, nil, true)
        if ctrl == nil then
            return
        end

        ctrl:ShowTaskFinishToast(args, function()
            Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackEndToastNW")
        end)
    end, function()
        UIManager:Close(PANEL_ID)
    end)
end



CommonTaskTrackToastCtrl.OnShowCommonTaskFailToast = HL.StaticMethod(HL.Any) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackEndToastNW", function()
        
        local ctrl = CommonTaskTrackToastCtrl.AutoOpen(PANEL_ID, nil, true)
        if ctrl == nil then
            return
        end

        ctrl:ShowTaskFailToast(args, function()
            Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackEndToastNW")
        end)
    end, function()
        UIManager:Close(PANEL_ID)
    end)
end





CommonTaskTrackToastCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
end



CommonTaskTrackToastCtrl.OnClose = HL.Override() << function(self)
    if self.m_countDownTickId ~= -1 then
        self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
    end

    if self.m_showingToastCor then
        self.m_showingToastCor = self:_ClearCoroutine(self.m_showingToastCor)
    end
end





CommonTaskTrackToastCtrl.ShowCountdownToast = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, args, endFunc)
    self:Notify(MessageConst.ON_HUD_BTN_VISIBLE_CHANGE, {false})

    local countdownDuration, cb = unpack(args)

    local toast = Utils.wrapLuaNode(self:_CreateToastGO(CountdownToast))
    toast.contentTimeStart.gameObject:SetActiveIfNecessary(false)
    toast.contentTimeNumber.gameObject:SetActiveIfNecessary(false)

    local freq = 1
    local tickInterval = 1
    local leftTime = countdownDuration
    self.m_countDownTickId = LuaUpdate:Add("Tick", function(deltaTime)
        if TimeManagerInst.timeScale == 0 then
            return
        end

        tickInterval = tickInterval + deltaTime
        if tickInterval < freq then
            return
        end
        tickInterval = 0

        local showStart = leftTime <= 0
        if showStart then
            if leftTime == 0 then
                AudioAdapter.PostEvent("Au_UI_Toast_TaskTrack_CountdownToast_Start")
            end
        else
            toast.startNumberTxt.text = math.ceil(leftTime)
            AudioAdapter.PostEvent("Au_UI_Toast_TaskTrack_CountdownToast_Number")
        end

        toast.contentTimeStart.gameObject:SetActiveIfNecessary(showStart)
        toast.contentTimeNumber.gameObject:SetActiveIfNecessary(not showStart)
        toast.animationWrapper:SampleToInAnimationEnd()
        toast.animationWrapper:PlayInAnimation()

        
        if leftTime <= -1 then
            if cb ~= nil
                    and not string.isEmpty(GameWorld.worldInfo.curSubGameId) then
                cb()
            end

            if endFunc then
                endFunc()
            end

            toast.animationWrapper:PlayOutAnimation(function()
                self:Close()
            end)
            self.m_countDownTickId = LuaUpdate:Remove(self.m_countDownTickId)
            self:Notify(MessageConst.ON_HUD_BTN_VISIBLE_CHANGE, {true})
        end

        leftTime = leftTime - freq
    end)
end





CommonTaskTrackToastCtrl.ShowTaskStartToast = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, args, endFunc)
    self:_RefreshToast(ToastType.Start, args, endFunc)
    AudioAdapter.PostEvent("Au_UI_Toast_TaskTrack_TaskStartToast_Open")
end





CommonTaskTrackToastCtrl.ShowTaskFinishToast = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, args, endFunc)
    self:_RefreshToast(ToastType.Finish, args, endFunc)
    AudioAdapter.PostEvent("Au_UI_Toast_TaskTrack_TaskFinishToast_Open")
end





CommonTaskTrackToastCtrl.ShowTaskFailToast = HL.Method(HL.Any, HL.Opt(HL.Function)) << function(self, args, endFunc)
    self:_RefreshToast(ToastType.Fail, args, endFunc)
    AudioAdapter.PostEvent("Au_UI_Toast_TaskTrack_TaskFailToast_Open")
end



CommonTaskTrackToastCtrl.OnSubGameReset = HL.Method() << function(self)
    self:Close()
end






CommonTaskTrackToastCtrl._RefreshToast = HL.Method(HL.String, HL.Any, HL.Opt(HL.Function))
        << function(self, toastType, args, endFunc)
    self:Notify(MessageConst.ON_HUD_BTN_VISIBLE_CHANGE, {false})

    local instId = unpack(args)
    local taskTitle = ""
    local taskDesc = ""
    local hasTableData, gameMechanicData = Tables.gameMechanicTable:TryGetValue(instId)
    local hasSubGameData, subGameData = DataManager.subGameInstDataTable:TryGetValue(instId)
    if not hasSubGameData or not hasTableData then
        logger.error("未找到s%玩法实例数据/配置数据", instId)
        return
    end

    if toastType == ToastType.Start then
        taskTitle = gameMechanicData.gameName
        taskDesc = gameMechanicData.desc
        if not subGameData.showDesc then
            taskDesc = ""
        end
    elseif toastType == ToastType.Finish then
        local success, successInfoText = subGameData.successInfo:TryGetText()
        if success then
            taskTitle = successInfoText
        else
            taskTitle = Language.LUA_COMMON_TASK_TRACK_TOAST_SUCC_DESC
        end
    elseif toastType == ToastType.Fail then
        local success, failInfoText = subGameData.failInfo:TryGetText()
        if success then
            taskTitle = failInfoText
        else
            taskTitle = Language.LUA_COMMON_TASK_TRACK_TOAST_FAIL_DESC
        end
    end

    local toastNode = self:_CreateToastWidget(toastType, instId)
    local hasGameCategory, gameCategoryCfg = Tables.gameMechanicCategoryTable:TryGetValue(gameMechanicData.gameCategory)
    local toastIcon = hasGameCategory and gameCategoryCfg.toastIcon or ""
    if not string.isEmpty(toastIcon) then
        toastNode.middleIcon:LoadSprite(UIConst.UI_SPRITE_COMMON_TASK_TRACK, toastIcon)
    end
    toastNode.titleTxt.text = taskTitle
    toastNode.descTxt.text = taskDesc

    self.m_showingToastCor = self:_StartCoroutine(function()
        local inAnimLength = toastNode.animationWrapper:GetInClipLength()
        toastNode.animationWrapper:PlayInAnimation()
        coroutine.wait(inAnimLength)

        local outAnimLength = toastNode.animationWrapper:GetOutClipLength()
        toastNode.animationWrapper:PlayOutAnimation()
        coroutine.wait(outAnimLength)

        self:Close()
        self:Notify(MessageConst.ON_HUD_BTN_VISIBLE_CHANGE, {true})
        if endFunc then
            endFunc()
        end
    end)
end




CommonTaskTrackToastCtrl._CreateToastGO = HL.Method(HL.String).Return(GameObject) << function(self, name)
    local path = string.format(UIConst.UI_COMMON_TASK_TRACK_TOAST_WIDGETS_PATH, name)
    local goAsset = self:LoadGameObject(path)
    local go = CSUtils.CreateObject(goAsset, self.view.main)
    go.transform.anchoredPosition = Vector2.zero
    go.transform.localScale = Vector3.one
    go.transform.localRotation = Quaternion.identity
    go.name = name
    return go
end





CommonTaskTrackToastCtrl._CreateToastWidget = HL.Method(HL.String, HL.String).Return(HL.Any)
        << function(self, toastType, instId)
    
    
    local toastGOName = toastType
    local gameMechCfg = Tables.gameMechanicTable[instId]
    local gameCategoryCfg = Tables.gameMechanicCategoryTable[gameMechCfg.gameCategory]
    if toastType == ToastType.Start then
        toastGOName = gameCategoryCfg.startToastType
    end

    if string.isEmpty(toastGOName) then
        toastGOName = WorldChallengeStartToast
    end

    local toastGO = self:_CreateToastGO(toastGOName)
    return Utils.wrapLuaNode(toastGO)
end

HL.Commit(CommonTaskTrackToastCtrl)
