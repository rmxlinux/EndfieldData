local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')











ActivityCommonInfo = HL.Class('ActivityCommonInfo', UIWidgetBase)


ActivityCommonInfo.m_tagCells = HL.Field(HL.Any)


ActivityCommonInfo.m_activityId = HL.Field(HL.String) << ""


ActivityCommonInfo.m_rewardCells = HL.Field(HL.Any)




ActivityCommonInfo._OnFirstTimeInit = HL.Override() << function(self)
    
end




ActivityCommonInfo.InitActivityCommonInfo = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()
    self.m_activityId = args.activityId
    local activitySystem = GameInstance.player.activitySystem

    local _, activityData = Tables.activityTable:TryGetValue(self.m_activityId)
    local activity = activitySystem:GetActivity(self.m_activityId)
    if not activityData or not activity then
        logger.error('Activity not found: %s', self.m_activityId)
        self.view.gameObject:SetActive(false)
        return
    end

    
    self.view.infoNode.txtName.text = activityData.name
    self.view.infoNode.detailsTxt.text = activityData.desc
    if activity.endTime == 0 then
        self.view.infoNode.countDownText.text = Language.LUA_ACTIVITY_PERMANENT_TEXT
    else
        self.view.infoNode.countDownWidget:InitCountDownText(activity.endTime)
    end

    
    local tagIds = activityData.tagIds
    self.m_tagCells = UIUtils.genCellCache(self.view.tagCell)
    self.m_tagCells:Refresh(#tagIds, function(cell, index)
        local csIndex = CSIndex(index)
        local _,tagInfo = Tables.activityTagTable:TryGetValue(tagIds[csIndex])
        cell.tagTxt.text = tagInfo.name
    end)

    
    self.m_rewardCells = UIUtils.genCellCache(self.view.rewardItem)
    if self.view.config.SHOW_REWARDS then
        self:UpdateRewardInfo()
    end

    
    self.view.infoNode.descriptionBtn.onClick:AddListener(function()
        ActivityUtils.GameEventLogActivityVisit(self.m_activityId, "descriptionButton", "visit_description")
        local instructionId = activityData.instructionId
        UIManager:Open(PanelId.InstructionBook, instructionId)
    end)

    
    local state
    if not self.view.config.SHOW_BUTTONS then
        state = "None"
    elseif not activity.isUnlocked then
        state = "Reminder"
    elseif activity.status == GEnums.ActivityStatus.IntroMission then
        state = "IntroMission"
    else
        state = "Detail"
    end
    self.view.gotoNode.stateController:SetState(state)
    if state == "Reminder" then
        self.view.gotoNode.reminderJumpBtn.onClick:AddListener(function()
            ActivityUtils.GameEventLogActivityVisit(self.m_activityId, "unlockReminderButton", "visit_unlock_reminder")
            UIManager:Open(PanelId.ActivityStartReminderPopup,{
                activityId = self.m_activityId,
            })
        end)
    elseif state == "Detail" then
        if activityData.detailJumpId then
            self.view.gotoNode.btnDetail.onClick:AddListener(function()
                ActivityUtils.GameEventLogActivityVisit(self.m_activityId, "gotoActivityHudButton", "visit_activity")
                local normalJump = Tables.systemJumpTable:TryGetValue(activityData.detailJumpId)
                
                if normalJump then
                    Utils.jumpToSystem(activityData.detailJumpId)
                else
                    
                    local webJump, webJumpInfo = Tables.activityWebTable:TryGetValue(activityData.id)
                    if webJump then
                        CS.Beyond.SDK.SDKUtils.OpenHGWebPortalSDK(webJumpInfo.jumpId,"",function()
                            if webJumpInfo.disableAudio then
                                CS.Beyond.Gameplay.Audio.Utils.AudioControlUtil.Webview.SetMute(false)
                            end
                        end)
                        if webJumpInfo.disableAudio then
                            CS.Beyond.Gameplay.Audio.Utils.AudioControlUtil.Webview.SetMute(true)
                        end
                    end
                end
            end)
        end
    elseif state == "IntroMission" then
        self.view.gotoNode.btnIntroMissionlRedDot:InitRedDot("ActivityIntroMission", self.m_activityId)
        self.view.gotoNode.btnIntroMission.onClick:AddListener(function()
            ActivityUtils.GameEventLogActivityVisit(self.m_activityId, "IntroMissionButton", "visit_intro_mission")
            local success = Tables.systemJumpTable:TryGetValue(activityData.introMissionJumpId)
            if success then
                Utils.jumpToSystem(activityData.introMissionJumpId)
                ActivityUtils.setFalseIntroMissionActivity(self.m_activityId)
            else
                logger.error("no such jumpId")
            end
        end)
    end

    
    if DeviceInfo.usingController then
        self.view.gotoNode.scrollViewRewards.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
    end

    
    self:RegisterMessage(MessageConst.ON_ACTIVITY_UPDATED, function(updateArgs)
        local id = unpack(updateArgs)
        if id == self.m_activityId and GameInstance.player.activitySystem:GetActivity(id) then
            self:_Refresh()
        end
    end)
end


ActivityCommonInfo.m_rewardId = HL.Field(HL.String) << ""



ActivityCommonInfo._Refresh = HL.Method() << function(self)
    
    self:UpdateRewardInfo(self.m_rewardId)
end




ActivityCommonInfo.UpdateRewardInfo = HL.Method(HL.Opt(HL.String)) << function(self, rewardId)
    local _, activityData = Tables.activityTable:TryGetValue(self.m_activityId)
    if not rewardId then
        rewardId = activityData.rewardId
    end

    if rewardId and not string.isEmpty(rewardId) then
        self.m_rewardId = rewardId
        local rewardBundles = UIUtils.getRewardItems(rewardId)
        self.m_rewardCells:Refresh(#rewardBundles, function(cell, index)
            cell:InitItem(rewardBundles[index], function()
                cell:ShowTips()
            end)
            cell:SetExtraInfo({
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
                tipsPosTransform = self.view.scrollViewRewards,
                isSideTips = true,
            })
            cell.view.countNode.gameObject:SetActive(activityData.showRewardCnt)
        end)
    end

    
    local activity = GameInstance.player.activitySystem:GetActivity(self.m_activityId)
    local receiveAll = activity and activity.receiveAllReward
    self.view.gotoNode.receiveAllNode.gameObject:SetActive(receiveAll)
    self.view.gotoNode.notReceiveAllNode.gameObject:SetActive(not receiveAll)
end




ActivityCommonInfo.UpdateDescTxt = HL.Method(HL.String) << function(self, desc)
    self.view.infoNode.detailsTxt.text = desc
end


HL.Commit(ActivityCommonInfo)
return ActivityCommonInfo

