
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.ActivityCenter
















PhaseActivityCenter = HL.Class('PhaseActivityCenter', phaseBase.PhaseBase)

local ROOT_PANEL_ID = PanelId.ActivityCenter






PhaseActivityCenter.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SHOW_ACTIVITY_PANEL] = { 'ShowActivity', true },
    [MessageConst.SHOW_ACTIVITY_PANEL_FROM_NAVI] = { 'ShowActivityFromNavi', true },
    [MessageConst.ON_TOGGLE_ACTIVITY_INSTRUCTION] = { 'OnToggleActivityInstruction', true },
}


PhaseActivityCenter.m_activitySystem = HL.Field(HL.Userdata)


PhaseActivityCenter.m_activityPanelId = HL.Field(HL.Number) << -1


PhaseActivityCenter.m_activityInstructionId = HL.Field(HL.String) << ""






PhaseActivityCenter._OnInit = HL.Override() << function(self)
    PhaseActivityCenter.Super._OnInit(self)
    self.m_activitySystem = GameInstance.player.activitySystem
end






PhaseActivityCenter.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn and not fastMode then
        local activityId
        if self.arg.gotoCenter and self.arg.activityId then
            
            activityId = self.arg.activityId
        else
            
            local allActivities = {}
            local activities = GameInstance.player.activitySystem:GetAllActivities()
            for _, activity in cs_pairs(activities) do
                local _, activityData = Tables.activityTable:TryGetValue(activity.id)
                if activityData then
                    table.insert(allActivities, {
                        id = activity.id,
                        sortId = -activityData.sortId,
                        completed = activity.isCompleted and 1 or 0,
                    })
                end
            end
            table.sort(allActivities, Utils.genSortFunction({"completed","sortId", "id"}, true))
            activityId = allActivities[1].id
        end

        if activityId and Tables.activityTable:TryGetValue(activityId) then
            local panelId = Tables.activityTable[activityId].panelId
            UIManager:PreloadPanelAsset(PanelId[panelId], PHASE_ID)
        end
    elseif transitionType == PhaseConst.EPhaseState.TransitionBackToTop then
        Notify(MessageConst.ON_ACTIVITY_PREPARE_TRANSITION_BACK_TO_TOP)
    end
    if transitionType == PhaseConst.EPhaseState.TransitionBehind then
        if self.m_delayShowActivityCo and self.m_delayShowActivityArg then
            self:ShowActivity(self.m_delayShowActivityArg)
        end
    end
    self:_ClearCoroutine(self.m_delayShowActivityCo)
end





PhaseActivityCenter._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    
    if not string.isEmpty(self.arg.instructionId) then
        self.m_activityInstructionId = self.arg.instructionId
        UIManager:Open(PanelId.InstructionBook, {
            id = self.arg.instructionId,
            onClose = function()
                self.m_activityInstructionId = ""
            end
        })
        self.arg.instructionId = nil
    end
    if self.arg.reminderArg ~= nil then
        UIManager:Open(PanelId.ActivityStartReminderPopup, self.arg.reminderArg)
        self.arg.reminderArg = nil
    end
end





PhaseActivityCenter._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    
    local curArg = self:GetCurStateArg()
    if curArg and curArg.activityId then
        local activityId = curArg.activityId
        local _, activityData = Tables.activityTable:TryGetValue(activityId)
        if activityData and not string.isEmpty(activityData.bgm) then
            AudioManager.PostEvent(activityData.bgm)
        end
    end
end



PhaseActivityCenter._OnDestroy = HL.Override() << function(self)
    PhaseActivityCenter.Super._OnDestroy(self)
    AudioManager.PostEvent("au_music_meta_ui_stop")
end



PhaseActivityCenter.m_firstTimeShowActivity = HL.Field(HL.Boolean) << true




PhaseActivityCenter.ShowActivity = HL.Method(HL.Any) << function(self, arg)
    local activityId = arg.activityId
    local controllerHintPlaceholder = arg.controllerHintPlaceholder
    local groupId = arg.groupId
    local leftNaviGroup = arg.naviGroup
    local getReturnTargetFunc = arg.getReturnTargetFunc

    local _, activityData = Tables.activityTable:TryGetValue(activityId)
    local activity = self.m_activitySystem:GetActivity(activityId)
    if not activityData or not activity then
        logger.error('Activity not found: %s', activityId)
        return
    end
    local targetPanelId = PanelId[activityData.panelId]
    
    if activityId == "activity_checkin_tangtang" then
        targetPanelId = PanelId.ActivityFreeMonthlyPass
    end
    if not targetPanelId then
        logger.error('Activity type not supported:', targetPanelId)
        return
    end
    self:RemovePhasePanelItemById(self.m_activityPanelId)
    self.m_activityPanelId = targetPanelId
    
    controllerHintPlaceholder:InitControllerHintPlaceholder({})

    local panel = self:CreatePhasePanelItem(self.m_activityPanelId, {
        activityId = activityId,
        panelId = activityData.panelId,
    })
    UIManager:SetTopOrder(ROOT_PANEL_ID)

    
    if panel.uiCtrl.view.bg and not string.isEmpty(activityData.bgImg) then
        local path = UIConst.UI_SPRITE_ACTIVITY
        local name = activityData.bgImg
        panel.uiCtrl.view.bg:LoadSprite(path,name)
    end

    
    local _, activityData = Tables.activityTable:TryGetValue(activityId)
    if activityData and not string.isEmpty(activityData.bgm) then
        AudioManager.PostEvent(activityData.bgm)
    else
        if not arg.isInit then
            
            AudioManager.PostEvent("au_music_meta_ui_stop")
        end
    end

    
    if DeviceInfo.usingController then
        
        panel.uiCtrl:BindInputPlayerAction("common_back", function()
            UIUtils.setAsNaviTarget(getReturnTargetFunc())
        end, panel.uiCtrl.view.inputGroup.groupId)

        
        controllerHintPlaceholder:InitControllerHintPlaceholder({groupId , panel.uiCtrl.view.inputGroup.groupId })
        self.m_firstTimeShowActivity = false

        
        leftNaviGroup.onIsTopLayerChanged:AddListener(function(active)
            arg.btnClose.enabled = active
        end)

        
        leftNaviGroup.onDefaultNaviFailed:RemoveAllListeners()
        leftNaviGroup.onDefaultNaviFailed:AddListener(function(dir)
            Notify(MessageConst.ON_ACTIVITY_NAVI_FAILED, dir)
        end)

        
        local rightNaviGroup, forbidCommonNavi = unpack(ActivityUtils.getNaviConfig(panel, activityData.type))
        if rightNaviGroup then
            if not forbidCommonNavi then
                
                leftNaviGroup:TryChangeNaviPartnerOnRight(rightNaviGroup, true)
            else
                
                leftNaviGroup.onDefaultNaviFailed:AddListener(function(dir)
                    if dir == Unity.UI.NaviDirection.Right and panel.uiCtrl and panel.uiCtrl.OnActivityCenterNaviFailed then
                        panel.uiCtrl:OnActivityCenterNaviFailed()
                    end
                end)
            end
            
            rightNaviGroup.onDefaultNaviFailed:RemoveAllListeners()
            rightNaviGroup.onDefaultNaviFailed:AddListener(function(dir)
                if dir == Unity.UI.NaviDirection.Left then
                    UIUtils.setAsNaviTarget(getReturnTargetFunc())
                end
            end)
        end
    end
end


PhaseActivityCenter.m_delayShowActivityCo = HL.Field(HL.Thread)

PhaseActivityCenter.m_delayShowActivityArg = HL.Field(HL.Table)




PhaseActivityCenter.ShowActivityFromNavi = HL.Method(HL.Table) << function(self, arg)
    self.m_delayShowActivityArg = arg
    self:_ClearCoroutine(self.m_delayShowActivityCo)
    self.m_delayShowActivityCo = self:_StartCoroutine(function()
        local panelItem = self:_GetPanelPhaseItem(self.m_activityPanelId)
        if panelItem then
            panelItem.uiCtrl.view.luaPanel:BlockAllInput()
        end
        coroutine.wait(arg.delay)
        if panelItem then
            panelItem.uiCtrl.view.luaPanel:RecoverAllInput()
        end
        self:ShowActivity(arg)
        self.m_delayShowActivityCo = nil
        self.m_delayShowActivityArg = nil
    end)
end




PhaseActivityCenter.OnToggleActivityInstruction = HL.Method(HL.Any) << function(self, args)
    if args.isShown then
        self.m_activityInstructionId = args.instructionId
    else
        self.m_activityInstructionId = ""
    end
end



PhaseActivityCenter.GetCurStateArg = HL.Override().Return(HL.Opt(HL.Any)) << function(self)
    local arg = self.arg and lume.deepCopy(self.arg) or {}
    arg.activityId = self.m_panel2Item[PanelId.ActivityCenter].uiCtrl.m_activityId
    arg.gotoCenter = true
    arg.instructionId = self.m_activityInstructionId

    local isOpen, popupCtrl = UIManager:IsOpen(PanelId.ActivityStartReminderPopup)
    if isOpen then
        arg.reminderArg = popupCtrl.arg
    end

    return arg
end


HL.Commit(PhaseActivityCenter)
