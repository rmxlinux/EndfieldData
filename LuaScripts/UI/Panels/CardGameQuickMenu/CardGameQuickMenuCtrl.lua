local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CardGameQuickMenu
local STICK_DEAD_ZONE = 0.5
local SEAT_COUNT = 4
local CANCEL_ACTION_ID = "cardgame_blackjack_quick_menu_cancel"

local DIRECTION_STICK_ANGLE = {
    [1] = 180,
    [2] = 270,
    [3] = 0,
    [4] = 90,
}










CardGameQuickMenuCtrl = HL.Class('CardGameQuickMenuCtrl', uiCtrl.UICtrl)







CardGameQuickMenuCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CHANGE_INPUT_DEVICE_TYPE_FINISHED] = '_OnChangeInputDeviceType',
}


CardGameQuickMenuCtrl.m_seats = HL.Field(HL.Table)
CardGameQuickMenuCtrl.m_onConfirm = HL.Field(HL.Function)
CardGameQuickMenuCtrl.m_onClose = HL.Field(HL.Function)
CardGameQuickMenuCtrl.m_curSelDirection = HL.Field(HL.Number) << 0





CardGameQuickMenuCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitData(arg or {})
    self:_InitUI()
end

CardGameQuickMenuCtrl.OnClose = HL.Override() << function(self)
    local onClose = self.m_onClose
    self.m_onClose = nil
    self.m_onConfirm = nil
    if onClose then
        onClose()
    end
end


CardGameQuickMenuCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        self:PlayAnimationOutAndClose()
    end
end

CardGameQuickMenuCtrl._InitData = HL.Method(HL.Table) << function(self, arg)
    self.m_seats = arg.seats or {}
    self.m_onConfirm = arg.onConfirm
    self.m_onClose = arg.onClose
    self.m_curSelDirection = 0
end

CardGameQuickMenuCtrl._InitUI = HL.Method() << function(self)
    self:BindInputPlayerAction(CANCEL_ACTION_ID, function()
        
        self:PlayAnimationOutAndClose()
    end)
    self:_RefreshSeats()
    self.view.stateController:SetState("WaitSelect")
    self.view.curSelectSeatTxt.text = ""
    self:_StartUpdate(function(deltaTime)
        self:_TickQuickMenu()
    end)
end

CardGameQuickMenuCtrl._OnChangeInputDeviceType = HL.Method(HL.Any) << function(self, arg)
    if not DeviceInfo.usingController then
        self:Close()
    end
end



CardGameQuickMenuCtrl._RefreshSeats = HL.Method() << function(self)
    for direction = 1, SEAT_COUNT do
        local seatNode = self.view["seatNode_" .. direction]
        local seat = self.m_seats[direction]
        local isEmpty = self:_IsSeatEmpty(direction)
        seatNode.stateController:SetState(isEmpty and "Empty" or "Normal")
        seatNode.commonPlayerHead.gameObject:SetActive(not isEmpty)
        if not isEmpty then
            CardGameUtils.InitCommonPlayerHead(seatNode.commonPlayerHead, seat.playerInfo)
        end
    end
end

CardGameQuickMenuCtrl._TickQuickMenu = HL.Method() << function(self)
    
    
    
    local stickValue = InputManagerInst:GetGamepadStickValue(false)
    if stickValue.magnitude < STICK_DEAD_ZONE then
        
        if self.m_curSelDirection ~= 0 then
            local direction = self.m_curSelDirection
            if self:_IsSeatEmpty(direction) then
                self.m_curSelDirection = 0
                self.view.stateController:SetState("WaitSelect")
                return
            end
            local onConfirm = self.m_onConfirm
            if onConfirm then
                self:Close()
                onConfirm(direction)
            end
        end
        return
    end

    local angle = 180 * (math.acos(Vector2.Dot(stickValue.normalized, Vector2(0, 1))) / math.pi)
    if stickValue.x < 0 then
        angle = 360 - angle
    end

    local direction = self:_GetDirectionByStickAngle(angle)
    if direction ~= self.m_curSelDirection then
        self.m_curSelDirection = direction
        if self:_IsSeatEmpty(direction) then
            self.view.stateController:SetState("Empty")
            AudioAdapter.PostEvent("Au_UI_Hover_DisableGeneralAbility")
        else
            self.view.stateController:SetState("Select")
            self.view.curSelectSeatTxt.text = CardGameUtils.GetPlayerDisplayName(self.m_seats[direction].playerInfo)
            AudioAdapter.PostEvent("au_ui_hover_dial")
        end
        self.view.selectLightNode.transform.localEulerAngles = Vector3(0, 0, -DIRECTION_STICK_ANGLE[direction])
    end
    self.view.selectArrow.localEulerAngles = Vector3(0, 0, -angle)
end

CardGameQuickMenuCtrl._GetDirectionByStickAngle = HL.Method(HL.Number).Return(HL.Number) << function(self, angle)
    local sector = math.floor((angle + 45) % 360 / 90)
    if sector == 0 then
        return 3
    elseif sector == 1 then
        return 4
    elseif sector == 2 then
        return 1
    end
    return 2
end



CardGameQuickMenuCtrl._IsSeatEmpty = HL.Method(HL.Number).Return(HL.Boolean) << function(self, direction)
    local seat = self.m_seats[direction]
    return seat == nil or seat.isEmpty == true or seat.playerInfo == nil
end


HL.Commit(CardGameQuickMenuCtrl)
