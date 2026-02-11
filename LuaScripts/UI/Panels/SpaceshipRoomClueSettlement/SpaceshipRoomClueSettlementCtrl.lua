local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipRoomClueSettlement
local PHASE_ID = PhaseId.SpaceshipRoomClueSettlement

























SpaceshipRoomClueSettlementCtrl = HL.Class('SpaceshipRoomClueSettlementCtrl', uiCtrl.UICtrl)







SpaceshipRoomClueSettlementCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}


SpaceshipRoomClueSettlementCtrl.m_getFriendCell = HL.Field(HL.Function)


SpaceshipRoomClueSettlementCtrl.m_requestHandle = HL.Field(HL.Number) << -1


SpaceshipRoomClueSettlementCtrl.m_requestTime = HL.Field(HL.Number) << 1


SpaceshipRoomClueSettlementCtrl.m_requestIds = HL.Field(HL.Table)


SpaceshipRoomClueSettlementCtrl.m_requestLuaIndex = HL.Field(HL.Number) << 1


SpaceshipRoomClueSettlementCtrl.m_showFriendIds = HL.Field(HL.Table)


SpaceshipRoomClueSettlementCtrl.m_showListInfo = HL.Field(HL.Table)


SpaceshipRoomClueSettlementCtrl.m_creditCount = HL.Field(HL.Number) << -1


SpaceshipRoomClueSettlementCtrl.m_infoCount = HL.Field(HL.Number) << -1


SpaceshipRoomClueSettlementCtrl.m_friendJumpInAction = HL.Field(HL.Number) << -1


SpaceshipRoomClueSettlementCtrl.m_friendJumpOutAction = HL.Field(HL.Number) << -1


SpaceshipRoomClueSettlementCtrl.m_inFriendGroup = HL.Field(HL.Boolean) << false


SpaceshipRoomClueSettlementCtrl.m_csIndex2Cell = HL.Field(HL.Table)


local RequestBatchNum = 10



SpaceshipRoomClueSettlementCtrl.ShowSpaceshipClueSettlement = HL.StaticMethod(HL.Opt(HL.Table)) << function(args)
    Notify(MessageConst.ON_PUSH_SPACESHIP_GUEST_ROOM_MAIN_PANEL, {SpaceshipConst.GUEST_ROOM_CLUE_PANEL_TYPE.Settlement})
end





SpaceshipRoomClueSettlementCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })

    self.view.confirmBtn.enabled = true
    self.view.confirmBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PHASE_ID)
        Notify(MessageConst.ON_POP_SPACESHIP_GUEST_ROOM_MAIN_PANEL)
    end)

    self.m_getFriendCell = UIUtils.genCachedCellFunction(self.view.scrollList)

    self.view.scrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_UpdateScrollCell(self.m_getFriendCell(obj), csIndex)
    end)

    self.view.stateNode:SetState("Loading")

    self.m_creditCount = 0
    self.m_infoCount = 0
    local success, data = GameInstance.player.spaceship:GetClueSettleClueInfo()
    if success then
        local haveExtraCredit, extraCredit = data.extraRewardMap:TryGetValue(Tables.spaceshipConst.creditItemId)
        if haveExtraCredit then
            self.m_creditCount = self.m_creditCount + extraCredit
        end
        local haveExtraInfo, extraInfo = data.extraRewardMap:TryGetValue(Tables.spaceshipConst.infoTokenItemId)
        if haveExtraInfo then
            self.m_infoCount = self.m_infoCount + extraInfo
        end
    end


    self.m_showFriendIds = {}
    
    if success then
        for k, v in pairs(data.friendRoleIds) do
            table.insert(self.m_showFriendIds, v)
        end
    end


    self.m_friendJumpInAction = self:BindInputPlayerAction("spaceship_clue_schedule_friend_focus", function()
        if not self.m_inFriendGroup then
            local res = self.view.scrollList:GetShowRange()
            for csIndex = res.x, res.y do
                local cell = self.m_csIndex2Cell[csIndex]
                if cell ~= nil and cell.canJump then
                    self.view.scrollListSelectableNaviGroup:ManuallyFocus()
                    InputManagerInst.controllerNaviManager:SetTarget(cell.contactFriendCell1.view.button)
                    self.m_inFriendGroup = true
                    self.view.confirmBtn.enabled = false
                    self.view.confirmKeyHint.gameObject:SetActive(false)
                    InputManagerInst:ToggleBinding(self.m_friendJumpInAction, false)
                    InputManagerInst:ToggleBinding(self.m_friendJumpOutAction, true)
                    break
                end
            end
        end
    end)

    self.m_friendJumpOutAction = self:BindInputPlayerAction("spaceship_clue_schedule_friend_unfocus", function()
        if self.m_inFriendGroup then
            self.view.scrollListSelectableNaviGroup:ManuallyStopFocus()
            self.view.confirmBtn.enabled = true
            self.view.confirmKeyHint.gameObject:SetActive(true)
            self.m_inFriendGroup = false
            InputManagerInst:ToggleBinding(self.m_friendJumpInAction, true)
            InputManagerInst:ToggleBinding(self.m_friendJumpOutAction, false)
            if DeviceInfo.usingController then
                AudioAdapter.PostEvent("Au_UI_Button_Back")
            end
        end
    end, self.view.scrollListInputBindingGroupMonoTarget.groupId)

    InputManagerInst:ToggleBinding(self.m_friendJumpInAction, false)
    InputManagerInst:ToggleBinding(self.m_friendJumpOutAction, false)


    if #self.m_showFriendIds > 0 then
        self:_HandleFriendInfo()
    else
        self.view.stateNode:SetState("Empty")
        local hasValue, roomInfo = GameInstance.player.spaceship:TryGetRoom(Tables.spaceshipConst.guestRoomClueExtensionId)
        if hasValue and roomInfo then
            local roomLevel = roomInfo.lv
            local levelTable = SpaceshipUtils.getRoomLvTableByType(roomInfo.type)
            self.view.topPeopleNumTxt.text = levelTable[roomLevel].maxCalcRoleCount
            self.view.clueAwardNumTxt.text = string.format(Language.LUA_SPACESHIP_CLUE_EXTRA_REWARD_PER_PERSON, levelTable[roomLevel].extraInfoPerRole)
            self.view.creditAwardNumTxt.text = string.format(Language.LUA_SPACESHIP_CLUE_EXTRA_REWARD_PER_PERSON, levelTable[roomLevel].extraCreditPerRole)
        else
            self.view.topPeopleNumTxt.text = 0
            self.view.clueAwardNumTxt.text = string.format(Language.LUA_SPACESHIP_CLUE_EXTRA_REWARD_PER_PERSON, 0)
            self.view.creditAwardNumTxt.text = string.format(Language.LUA_SPACESHIP_CLUE_EXTRA_REWARD_PER_PERSON, 0)
        end
    end
end



SpaceshipRoomClueSettlementCtrl._HandleFriendInfo = HL.Method() << function(self)
    self.m_requestIds = {}

    for _, roleId in pairs(self.m_showFriendIds) do
        local success, friendInfo = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
        if not success or not friendInfo.init then
            table.insert(self.m_requestIds, roleId)
        end
    end

    local ids = self:_GetNextPageNotInitIds()
    if #ids > 0 then
        GameInstance.player.friendSystem:SyncSocialFriendInfo(ids, function()
            self.m_requestHandle = LuaUpdate:Add("Tick", function(deltaTime)
                self:_RequestTick(deltaTime)
            end)
            self:UpdateScrollListInfo()
        end)
    else
        self:UpdateScrollListInfo()
    end
end



SpaceshipRoomClueSettlementCtrl.UpdateScrollListInfo = HL.Method() << function(self)
    self.view.stateNode:SetState("Normal")

    self:_UpdateShowListInfo()
    self.m_csIndex2Cell = {}
    self.view.scrollList:UpdateCount(#self.m_showListInfo)

    InputManagerInst:ToggleBinding(self.m_friendJumpInAction, true)
    InputManagerInst:ToggleBinding(self.m_friendJumpOutAction, false)
end



SpaceshipRoomClueSettlementCtrl._GetNextPageNotInitIds = HL.Method().Return(HL.Table) << function(self)
    local ids = {}
    for i = 1, RequestBatchNum do
        if self.m_requestLuaIndex <= #self.m_requestIds then
            table.insert(ids, self.m_requestIds[self.m_requestLuaIndex])
            self.m_requestLuaIndex = self.m_requestLuaIndex + 1
        end
    end

    return ids
end




SpaceshipRoomClueSettlementCtrl._RequestTick = HL.Method(HL.Number) << function(self, deltaTime)
    self.m_requestTime = self.m_requestTime + deltaTime
    if self.m_requestTime < 1 then
        return
    end
    self.m_requestTime = 0

    local ids = self:_GetNextPageNotInitIds()
    if #ids == 0 then
        if self.m_requestHandle > 0 then
            self.m_requestHandle = LuaUpdate:Remove(self.m_requestHandle)
        end
        return
    end
    GameInstance.player.friendSystem:SyncSocialFriendInfo(ids)
end



SpaceshipRoomClueSettlementCtrl._UpdateShowListInfo = HL.Method() << function(self)
    self.m_showListInfo = {}

    local titleNodeAward = {
        type = "titleNodeAward",
    }
    table.insert(self.m_showListInfo, titleNodeAward)

    local awardNode = {
        type = "awardNode",
    }
    table.insert(self.m_showListInfo, awardNode)

    local titleNodeFriend = {
        type = "titleNodeFriend",
    }
    table.insert(self.m_showListInfo, titleNodeFriend)

    local showControllerTip = true
    for i = 1, #self.m_showFriendIds do
        if i % 2 == 0 then
            local FriendCells = {
                type = "FriendCells",
                roleNum = 2,
                roleId1 = self.m_showFriendIds[i - 1],
                roleId2 = self.m_showFriendIds[i],
                showControllerTip = showControllerTip,
            }
            showControllerTip = false
            table.insert(self.m_showListInfo, FriendCells)
        end
    end
    if #self.m_showFriendIds % 2 == 1 then
        local FriendCells = {
            type = "FriendCells",
            roleNum = 1,
            roleId1 = self.m_showFriendIds[#self.m_showFriendIds],
            roleId2 = 0,
            showControllerTip = showControllerTip,
        }
        table.insert(self.m_showListInfo, FriendCells)
    end
end





SpaceshipRoomClueSettlementCtrl._UpdateScrollCell = HL.Method(HL.Any, HL.Number) << function(self, cell, csIndex)
    local luaIndex = LuaIndex(csIndex)
    local m_showInfo = self.m_showListInfo[luaIndex]
    self.m_csIndex2Cell[csIndex] = cell
    cell.canJump = false
    cell.titleNodeAward.gameObject:SetActive(false)
    cell.awardNode.gameObject:SetActive(false)
    cell.titleNodeFriend.gameObject:SetActive(false)
    cell.friendCells.gameObject:SetActive(false)
    cell.contactFriendCell1.gameObject:SetActive(false)
    cell.contactFriendCell2.gameObject:SetActive(false)

    if m_showInfo.type == "FriendCells" then
        cell.friendCells.gameObject:SetActive(true)
        cell.keyHint.gameObject:SetActive(m_showInfo.showControllerTip)
        if m_showInfo.roleNum == 2 then
            self:_UpdateFriendCell(cell, csIndex, 1, m_showInfo)
            self:_UpdateFriendCell(cell, csIndex, 2, m_showInfo)
        elseif m_showInfo.roleNum == 1 then
            self:_UpdateFriendCell(cell, csIndex, 1, m_showInfo)
        end
    elseif m_showInfo.type == "titleNodeAward" then
        cell.titleNodeAward.gameObject:SetActive(true)
    elseif m_showInfo.type == "awardNode" then
        cell.awardNode.gameObject:SetActive(true)
        cell.clueAwardNumTxt.text = self.m_infoCount
        cell.creditAwardNumTxt.text = self.m_creditCount
        cell.warningNode.gameObject:SetActive(false)     
    elseif m_showInfo.type == "titleNodeFriend" then
        cell.titleNodeFriend.gameObject:SetActive(true)
    end

    LayoutRebuilder.ForceRebuildLayoutImmediate(cell.rectTransform)
    self.view.scrollList:NotifyCellSizeChange(csIndex, cell.rectTransform.sizeDelta.y)
end







SpaceshipRoomClueSettlementCtrl._UpdateFriendCell = HL.Method(HL.Any, HL.Number, HL.Number, HL.Any) << function(self, cell, csIndex, sortNum, showInfo)
    cell.canJump = true
    local friendCell = nil
    local roleId = nil
    if sortNum == 1 then
        cell.contactFriendCell1.gameObject:SetActive(true)
        friendCell = cell.contactFriendCell1
        roleId = showInfo.roleId1
    elseif sortNum == 2 then
        cell.contactFriendCell2.gameObject:SetActive(true)
        friendCell = cell.contactFriendCell2
        roleId = showInfo.roleId2
    end
    if not friendCell then
        return
    end

    local haveData = false
    local friendInfo = nil
    local success, info = GameInstance.player.friendSystem:TryGetFriendInfo(roleId)
    if success and info.init then
        haveData = true
        friendInfo = info
    end

    if haveData and friendInfo.init then
        local clickFun = function(clickIndex)
            if GameInstance.player.friendSystem:PlayerInBlackList(roleId) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_CLUE_FRIEND_IN_BLACK_LIST)
                return
            end
            FriendUtils.FRIEND_CELL_HEAD_FUNC.BUSINESS_CARD(roleId).action()
        end

        friendCell:InitContactFriendCell(roleId, friendInfo, csIndex, clickFun, clickFun)
    else
        local clickFun = function(clickIndex)
            if GameInstance.player.friendSystem:PlayerInBlackList(roleId) then
                Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_CLUE_FRIEND_IN_BLACK_LIST)
                return
            end
        end

        friendCell:InitEmptyFriendCell(roleId, csIndex, clickFun)
    end
end



SpaceshipRoomClueSettlementCtrl.OnClose = HL.Override() << function(self)
    if self.m_requestHandle > 0 then
        self.m_requestHandle = LuaUpdate:Remove(self.m_requestHandle)
    end
    GameInstance.player.friendSystem:ClearSyncCallback()
end


HL.Commit(SpaceshipRoomClueSettlementCtrl)
