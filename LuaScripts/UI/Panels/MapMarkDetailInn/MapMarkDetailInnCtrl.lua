local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailInn

MapMarkDetailInnCtrl = HL.Class('MapMarkDetailInnCtrl', uiCtrl.UICtrl)







MapMarkDetailInnCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_INN_CUSTOMER_VOLUME_CHANGED] = '_OnCustomerVolumeChanged',
}


MapMarkDetailInnCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)

    local commonArgs = {}
    commonArgs.bigBtnActive = true
    commonArgs.markInstId = arg.markInstId
    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon(commonArgs)

    local innSystem = GameInstance.player.innSystem
    self.view.levelNode.levelTxt.text = tostring(innSystem.innLevel)

    self:_RefreshCustomerVolume()
end

MapMarkDetailInnCtrl._RefreshCustomerVolume = HL.Method() << function(self)
    local innSystem = GameInstance.player.innSystem
    local curVolume = innSystem.customerVolume
    local volumeData = innSystem.customerVolumeData
    local maxVolume = volumeData.maxValue
    local isFull = curVolume >= maxVolume

    local customerVolume = self.view.customerVolume
    customerVolume.fullNode.gameObject:SetActive(isFull)
    customerVolume.normalNode.gameObject:SetActive(not isFull)

    if isFull then
        customerVolume.countDownText:StopCountDown()
        return
    end

    local targetTime = DateTimeUtils.GetCurrentTimestampBySeconds()
    local recoverValue = volumeData.recoverValue
    local recoverInterval = volumeData.recoverInterval
    if recoverInterval > 0 and recoverValue > 0 then
        local ticksNeeded = math.ceil((maxVolume - volumeData.baseValue) / recoverValue)
        local nextTs = volumeData.nextRecoverTime
        if nextTs > 0 then
            targetTime = nextTs + (ticksNeeded - 1) * recoverInterval
        else
            targetTime = targetTime + ticksNeeded * recoverInterval
        end
    end
    customerVolume.countDownText:InitCountDownText(targetTime, nil, UIUtils.getLeftTimeToSecond)
end

MapMarkDetailInnCtrl._OnCustomerVolumeChanged = HL.Method(HL.Any) << function(self, _evtData)
    self:_RefreshCustomerVolume()
end











HL.Commit(MapMarkDetailInnCtrl)