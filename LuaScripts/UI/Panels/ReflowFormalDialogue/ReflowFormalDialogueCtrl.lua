local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ReflowFormalDialogue

local REFLOW_POPUP_DIALOG_TRUNK_ID = "dlg_map02_lv009_15001_001"

ReflowFormalDialogueCtrl = HL.Class('ReflowFormalDialogueCtrl', uiCtrl.UICtrl)






ReflowFormalDialogueCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

ReflowFormalDialogueCtrl.m_activityId = HL.Field(HL.String) << ""

ReflowFormalDialogueCtrl.m_closeCallback = HL.Field(HL.Function)

ReflowFormalDialogueCtrl.m_voiceHandleId = HL.Field(HL.Number) << -1


ReflowFormalDialogueCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_activityId = arg.activityId
    self.m_closeCallback = arg.closeCallback
    local _, table = Tables.activityReflowTable:TryGetValue(self.m_activityId)
    local cfg = table.reflowCfg
    
    self.view.roleImg:LoadSprite(string.format("%s/%s", UIConst.UI_SPRITE_CHAR_REMOTE_ICON_700, cfg.popupRoleIcon))
    self.view.nameTxt.text = cfg.popupRoleName
    self.view.descTxt.text = cfg.popupDesc
    
    self.view.bgMask.onClick:AddListener(function()
        self:_StopVoice()
        if self.m_closeCallback then
            self.m_closeCallback()
        else
            self:PlayAnimationOutAndClose()
        end
        
        ActivityUtils.GameEventLogActivityDialogEnd(self.m_activityId)
    end)

    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
    end
    self:_TryPlayVoice()
    
    ActivityUtils.GameEventLogActivityDialogStart(self.m_activityId)
end

ReflowFormalDialogueCtrl.OnClose = HL.Override() << function(self)
    self:_StopVoice()
end

ReflowFormalDialogueCtrl._TryPlayVoice = HL.Method() << function(self)
    local voiceId = DialogUtils.GetTrunkVoiceId(REFLOW_POPUP_DIALOG_TRUNK_ID)
    if string.isEmpty(voiceId) then
        logger.error("ReflowFormalDialogue: no audioOverride for trunkId=" .. REFLOW_POPUP_DIALOG_TRUNK_ID)
        return
    end
    local res, _ = VoiceUtils.TryGetVoiceDuration(voiceId)
    if not res then
        logger.error("ReflowFormalDialogue: TryGetVoiceDuration failed, voiceId=" .. voiceId)
        return
    end
    self.m_voiceHandleId = VoiceManager:SpeakNarrative(voiceId, CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig.DEFAULT_CONFIG)
end

ReflowFormalDialogueCtrl._StopVoice = HL.Method() << function(self)
    if self.m_voiceHandleId > 0 then
        VoiceManager:StopVoice(self.m_voiceHandleId)
        self.m_voiceHandleId = -1
    end
end

HL.Commit(ReflowFormalDialogueCtrl)
