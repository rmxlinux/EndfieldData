local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WulingParkourChallengeResult

local ANIM_SUCCESS = "wulingparkourchallengeresult_success"
local ANIM_FAIL = "wulingparkourchallengeresult_fail"
local ANIM_OUT = "wulingparkourchallengeresult_out"


local ANIM_STAR_CELL_IN = "parkourchallengehud_balloon_starcell"

local AUDIO_COMPLETE_OPEN = "Au_UI_Popup_Parkour_Complete_Open"
local AUDIO_TIMEOUT_OPEN = "Au_UI_Popup_ParkourTimeOut_Open"
local AUDIO_COMPLETE_CLOSE = "Au_UI_Popup_Parkour_Complete_Close"
local AUDIO_STAR_LEVEL = "Au_UI_Toast_ParkourLevel"


local SHOW_DURATION = 2


local Phase = {
    Normal = 1,
    Fail = 2,
    CompleteMainGoal = 3,
    CompleteAllGoal = 4,
}

WulingParkourChallengeResultCtrl = HL.Class('WulingParkourChallengeResultCtrl', uiCtrl.UICtrl)






WulingParkourChallengeResultCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

WulingParkourChallengeResultCtrl.m_starCells = HL.Field(HL.Any) << nil

WulingParkourChallengeResultCtrl.m_starCount = HL.Field(HL.Number) << -1

WulingParkourChallengeResultCtrl.m_showToastCor = HL.Field(HL.Thread)

WulingParkourChallengeResultCtrl.OnShowParkourStarResultToast = HL.StaticMethod(HL.Any) << function(args)
    local subGame = GameWorld.worldInfo.subGame
    if not subGame then
        return
    end
    
    local starCount = unpack(args)
    local passTimeMs = subGame.passTimeMs
    LuaSystemManager.commonTaskTrackSystem:AddRequest("TrackEndToast", function()
        UIManager:Open(PANEL_ID, {
            starNum = starCount,
            curGameTimeRecord = passTimeMs })      
    end, function()
        UIManager:Close(PANEL_ID)
    end)
end


WulingParkourChallengeResultCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.ON_ONE_COMMON_TASK_PANEL_FINISH, "TrackEndToast")
    if self.m_starCount == -1 then
        GameInstance.player.parkourSystem:ShowParkourDeathPanel()
    end
end



WulingParkourChallengeResultCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    if arg.starNum then
        self.m_starCount = arg.starNum
    end

    local passTime = 0
    if arg.curGameTimeRecord then
        passTime = arg.curGameTimeRecord
    end

    self.view.timeTxt.text = passTime and UIUtils.getLeftTimeToSecond(math.floor(passTime / 1000)) or "--:--"

    local subGameId = GameWorld.worldInfo.curSubGameId or ""
    local phase
    if self.m_starCount == -1 then
        phase = Phase.Fail
    else
        
        local extraTaskCount = 0
        local success, subGameData = DataManager.subGameInstDataTable:TryGetValue(subGameId)
        if success and subGameData.extraTasks then
            extraTaskCount = subGameData.extraTasks.Count
        end
        if self.m_starCount >= extraTaskCount then
            phase = Phase.CompleteAllGoal
        else
            phase = Phase.CompleteMainGoal
        end
    end
    Notify(MessageConst.ON_SUB_GAME_FINISH_STATE_CHANGE, { subGameId, phase })

    local isSuccess = self.m_starCount ~= -1
    if not isSuccess then
        self.view.mainStateController:SetState("Failed")
    else
        self.view.mainStateController:SetState("Completed")
        self.m_starCells = UIUtils.genCellCache(self.view.starCell)
        self.m_starCells:Refresh(3, function(cell, luaIndex)
            if luaIndex <= self.m_starCount then
                cell.stateController:SetState("Achieved")
            else
                cell.stateController:SetState("Unachieved")
            end
            
            cell.gameObject:SetActive(false)
         end)
    end

    
    self.m_showToastCor = self:_StartCoroutine(function()
        local wrapper = self.animationWrapper

        local inAnimName = isSuccess and ANIM_SUCCESS or ANIM_FAIL
        local inAnimLength = wrapper:GetClipLength(inAnimName)
        AudioAdapter.PostEvent(isSuccess and AUDIO_COMPLETE_OPEN or AUDIO_TIMEOUT_OPEN)
        wrapper:Play(inAnimName)
        coroutine.wait(inAnimLength)

        if isSuccess then
            self:_PlayStarCellsInAnim()
        end

        coroutine.wait(SHOW_DURATION)

        local outAnimLength = wrapper:GetClipLength(ANIM_OUT)
        AudioAdapter.PostEvent(AUDIO_COMPLETE_CLOSE)
        wrapper:Play(ANIM_OUT)
        coroutine.wait(outAnimLength)

        self:Close()
    end)
end




WulingParkourChallengeResultCtrl._PlayStarCellsInAnim = HL.Method() << function(self)
    if not self.m_starCells then
        return
    end
    local count = self.m_starCells:GetCount()
    for index = 1, count do
        local cell = self.m_starCells:GetItem(index)
        if cell then
            cell.gameObject:SetActive(true)
            
            if index <= self.m_starCount then
                AudioAdapter.PostEvent(AUDIO_STAR_LEVEL)
            end
            cell.animationWrapper:Play(ANIM_STAR_CELL_IN)
        end
        coroutine.wait(self.view.config.START_ANIM_IN_INTERVAL_TIME)
    end
end


HL.Commit(WulingParkourChallengeResultCtrl)
