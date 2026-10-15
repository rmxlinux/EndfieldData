local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.InnStaminaTips

InnStaminaTipsCtrl = HL.Class('InnStaminaTipsCtrl', uiCtrl.UICtrl)

InnStaminaTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_CUSTOMER_VOLUME_CHANGED] = '_OnCustomerVolumeChanged',
    
    [MessageConst.ON_WALLET_BAR_LOSE_FOCUS] = '_OnWalletBarLoseFocus',
}

InnStaminaTipsCtrl.m_coroutine = HL.Field(HL.Thread)
InnStaminaTipsCtrl.m_targetTransform = HL.Field(HL.Userdata)
InnStaminaTipsCtrl.m_isStamina = HL.Field(HL.Boolean) << false
InnStaminaTipsCtrl.m_onClose = HL.Field(HL.Function)

InnStaminaTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.backButton.onClick:AddListener(function()
        self:Close()
    end)
    self.m_targetTransform = arg and arg.transform or nil
    self.m_isStamina = not (arg and arg.isStarRating)
    self.m_onClose = arg and arg.onClose or nil
    self.view.mainStateController:SetState(self.m_isStamina and "Stamina" or "StarRating")
    UIManager:SetTopOrder(PANEL_ID)
    if self.m_isStamina then
        self:_RefreshStamina()
        self:_StartTick()
    end
    self:_RefreshPosition()
end

InnStaminaTipsCtrl._RefreshStamina = HL.Method() << function(self)
    local innSystem = GameInstance.player.innSystem
    local curVolume = innSystem.customerVolume
    local volumeData = innSystem.customerVolumeData
    local maxVolume = volumeData.maxValue
    local recoverValue = volumeData.recoverValue
    local recoverInterval = volumeData.recoverInterval
    local isFull = curVolume >= maxVolume

    self.view.detailsContentNode:SetState(isFull and "Complete" or "Normal")
    local recoverPerHour = math.floor(recoverValue * (Const.SEC_PER_HOUR / recoverInterval))
    self.view.recoverValueTxt.text = string.format(Language.LUA_INN_STAMINA_RECOVER_RATE_PER_HOUR, recoverPerHour)

    if not isFull and recoverInterval > 0 then
        local remaining = maxVolume - volumeData.baseValue
        local ticksNeeded = math.ceil(remaining / recoverValue)
        local nextTs = volumeData.nextRecoverTime
        local fullRecoverSec = ticksNeeded * recoverInterval
        if nextTs > 0 then
            local curTime = DateTimeUtils.GetCurrentTimestampBySeconds()
            local fullRecoverTs = nextTs + (ticksNeeded - 1) * recoverInterval
            fullRecoverSec = math.max(0, fullRecoverTs - curTime)
        end
        self.view.fullRemainTimeTxt.text = UIUtils.getLeftTimeToSecond(fullRecoverSec)
    end
end

InnStaminaTipsCtrl._RefreshPosition = HL.Method() << function(self)
    if IsNull(self.m_targetTransform) then
        return
    end
    local contentRect = self.view.contentNode
    local canvasRect = self.view.rectTransform
    LayoutRebuilder.ForceRebuildLayoutImmediate(contentRect)

    local targetScreenRect = UIUtils.getTransformScreenRect(self.m_targetTransform, self.uiCamera)
    local canvasSize = canvasRect.rect.size
    local screenW = Screen.width
    local screenH = Screen.height
    local xRatio = screenW / canvasSize.x
    local yRatio = screenH / canvasSize.y

    local pivot = contentRect.pivot
    local w = contentRect.rect.width * xRatio
    local h = contentRect.rect.height * yRatio

    local targetBRX = targetScreenRect.xMax
    local targetBRY = screenH - targetScreenRect.yMax

    local pivotScreenX = targetBRX - (1 - pivot.x) * w
    local pivotScreenY = targetBRY - (1 - pivot.y) * h

    pivotScreenX = lume.clamp(pivotScreenX, pivot.x * w, screenW - (1 - pivot.x) * w) 
    pivotScreenY = lume.clamp(pivotScreenY, pivot.y * h, screenH - (1 - pivot.y) * h) 

    local zDepth = self.uiCamera:WorldToScreenPoint(contentRect.position).z
    local worldPos = self.uiCamera:ScreenToWorldPoint(Vector3(pivotScreenX, pivotScreenY, zDepth))
    contentRect.position = Vector3(worldPos.x, worldPos.y, worldPos.z)
end

InnStaminaTipsCtrl._StartTick = HL.Method() << function(self)
    self:_StopTick()
    self.m_coroutine = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.COMMON_UI_TIME_UPDATE_INTERVAL)
            self:_RefreshStamina()
        end
    end)
end

InnStaminaTipsCtrl._StopTick = HL.Method() << function(self)
    if self.m_coroutine then
        self:_ClearCoroutine(self.m_coroutine)
        self.m_coroutine = nil
    end
end

InnStaminaTipsCtrl._OnCustomerVolumeChanged = HL.Method(HL.Any) << function(self, _evtData)
    if self.m_isStamina then
        self:_RefreshStamina()
    end
end

InnStaminaTipsCtrl._OnWalletBarLoseFocus = HL.Method() << function(self)
    self:Close()
end

InnStaminaTipsCtrl.OnClose = HL.Override() << function(self)
    self:_StopTick()
    self.m_targetTransform = nil
    if self.m_onClose then
        self.m_onClose()
        self.m_onClose = nil
    end
end

HL.Commit(InnStaminaTipsCtrl)
