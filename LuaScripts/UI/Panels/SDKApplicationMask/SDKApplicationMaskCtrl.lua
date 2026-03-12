local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SDKApplicationMask













SDKApplicationMaskCtrl = HL.Class('SDKApplicationMaskCtrl', uiCtrl.UICtrl)

local Configs = {
    
    ["gacha_char"] = {
        audioOnOpen = "Au_UI_Popup_Common_Large_Open",
        audioOnClose = "Au_UI_Popup_Common_Large_Close",
    },
    
    ["gacha_weapon"] = {
        audioOnOpen = "Au_UI_Popup_Common_Large_Open",
        audioOnClose = "Au_UI_Popup_Common_Large_Close",
    },
    
    ["sk_toolkit"] = {
        audioOnOpen = "Au_UI_Menu_Common_Large_Open",
        audioOnClose = "Au_UI_Menu_Common_Large_Close",
    },
}






SDKApplicationMaskCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_OPEN_WEB_APPLICATION] = 'OnOpenWebApplication',
    [MessageConst.ON_CLOSE_WEB_APPLICATION] = 'OnCloseWebApplication',
}


SDKApplicationMaskCtrl.m_curOpenedWebNameDic = HL.Field(HL.Table)


SDKApplicationMaskCtrl.m_hideCursor = HL.Field(HL.Boolean) << false





SDKApplicationMaskCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_curOpenedWebNameDic = {}
end



SDKApplicationMaskCtrl.OnShow = HL.Override() << function(self)
    GameInstance.audioManager:SetIsWebviewOpened(true)
    InputManagerInst.disableChangeInputDeviceCheck = true
    if DeviceInfo.usingController then
        InputManagerInst:ToggleForceShowRealCursor(true)
        self.m_hideCursor = true
    end
end



SDKApplicationMaskCtrl.OnHide = HL.Override() << function(self)
    if self.m_hideCursor then
        InputManagerInst:ToggleForceShowRealCursor(false)
        self.m_hideCursor = false
    end
    InputManagerInst.disableChangeInputDeviceCheck = false
    GameInstance.audioManager:SetIsWebviewOpened(false)
    Notify(MessageConst.ON_SDK_MASK_HIDE)
end



SDKApplicationMaskCtrl.OnStartWebApplication = HL.StaticMethod(HL.Table) << function(args)
    local key = unpack(args)
    local self = UIManager:AutoOpen(PANEL_ID)
    
    local phaseId = PhaseManager:GetTopPhaseId()
    EventLogManagerInst:GameEvent_UISwitch(PhaseManager:GetPhaseName(phaseId), "web_" .. key, true)
    EventLogManagerInst.curTopUIPhaseName = "web_" .. key
    self.m_curOpenedWebNameDic[key] = true
end




SDKApplicationMaskCtrl.OnOpenWebApplication = HL.Method(HL.Table) << function(self, args)
    local key = unpack(args)
    self:_PlayAudioOnOpen(key)
end




SDKApplicationMaskCtrl.OnCloseWebApplication = HL.Method(HL.Table) << function(self, args)
    local key = unpack(args)
    self.m_curOpenedWebNameDic[key] = nil
    self:_PlayAudioOnClose(key)
    if not next(self.m_curOpenedWebNameDic) then
        self:Hide()
        
        local phaseId = PhaseManager:GetTopPhaseId()
        EventLogManagerInst:GameEvent_UISwitch("web_" .. key, PhaseManager:GetPhaseName(phaseId), false)
        EventLogManagerInst.curTopUIPhaseName = PhaseManager:GetPhaseName(phaseId)
    end
end




SDKApplicationMaskCtrl._PlayAudioOnOpen = HL.Method(HL.String) << function(self, key)
    local config = Configs[key]
    if not config then
        return
    end
    AudioAdapter.PostEvent(config.audioOnOpen)
end




SDKApplicationMaskCtrl._PlayAudioOnClose = HL.Method(HL.String) << function(self, key)
    local config = Configs[key]
    if not config then
        return
    end
    AudioAdapter.PostEvent("Au_UI_Button_Close")
    AudioAdapter.PostEvent(config.audioOnClose)
end

HL.Commit(SDKApplicationMaskCtrl)
