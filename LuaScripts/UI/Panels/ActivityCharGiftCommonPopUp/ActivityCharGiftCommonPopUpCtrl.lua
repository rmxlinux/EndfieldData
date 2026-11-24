local uiCtrl = require_ex('UI/Panels/Base/UICtrl')

ActivityCharGiftCommonPopUpCtrl = HL.Class('ActivityCharGiftCommonPopUpCtrl', uiCtrl.UICtrl)

ActivityCharGiftCommonPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_ACTIVITY_UPDATED] = 'OnActivityUpdate',
}

ActivityCharGiftCommonPopUpCtrl.m_activityId = HL.Field(HL.String) << ""
ActivityCharGiftCommonPopUpCtrl.m_closeCallback = HL.Field(HL.Function)
ActivityCharGiftCommonPopUpCtrl.m_characterGiftPrefab = HL.Field(HL.Any)
ActivityCharGiftCommonPopUpCtrl.m_characterGiftWidget = HL.Field(HL.Any)
ActivityCharGiftCommonPopUpCtrl.m_closing = HL.Field(HL.Boolean) << false
ActivityCharGiftCommonPopUpCtrl.m_waitingForClose = HL.Field(HL.Boolean) << false
ActivityCharGiftCommonPopUpCtrl.m_waitingCloseCallback = HL.Field(HL.Function)

ActivityCharGiftCommonPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    args = args or {}
    self.m_activityId = args.activityId or ""
    self.m_closing = false
    self.m_waitingForClose = false
    self.m_waitingCloseCallback = nil
    self.m_closeCallback = args.closeCallback or function()
        self:Close()
    end

    local hasConfig, configData = Tables.activityCharacterGiftConfigTable:TryGetValue(self.m_activityId)

    local prefabName = configData.popupPanelWidgetName

    local path = string.format(UIConst.UI_ACTIVITY_CHARACTER_GIFT_PREFAB_PATH, prefabName)
    local prefab = self:LoadGameObject(path)

    self.m_characterGiftPrefab = CSUtils.CreateObject(prefab, self.view.main)

    local widget = Utils.wrapLuaNode(self.m_characterGiftPrefab)

    self.m_characterGiftWidget = widget
    self.m_characterGiftWidget:Init({
        activityId = self.m_activityId,
        activityInfoArgs = args,
        onClose = function()
            self:_Close()
        end,
        onGotoActivity = function(jumpId)
            self:_Close(function()
                Utils.jumpToSystem(jumpId)
            end)
        end,
    })
end

ActivityCharGiftCommonPopUpCtrl.OnActivityUpdate = HL.Method(HL.Table) << function(self, args)
    local id = unpack(args)
    if id == self.m_activityId and not GameInstance.player.activitySystem:GetActivity(id) then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_ACTIVITY_FORBIDDEN)
        self:_Close()
    end
end

ActivityCharGiftCommonPopUpCtrl._Close = HL.Method(HL.Opt(HL.Function)) << function(self, onClosed)
    if self.m_closing or self.m_waitingForClose then
        return
    end

    if not self:IsShow() then
        self.m_waitingForClose = true
        self.m_waitingCloseCallback = onClosed
        return
    end

    self.m_closing = true
    ActivityUtils.recordPopup(self.m_activityId) 

    if UIManager:IsOpen(PanelId.RewardsPopUpForSystem) then
        UIManager:Close(PanelId.RewardsPopUpForSystem)
    end
    Notify(MessageConst.HIDE_ITEM_TIPS)

    local closeCallback = self.m_closeCallback
    self.m_characterGiftWidget:StartCloseAnimation(function()
        closeCallback()
        if onClosed then
            onClosed()
        end
    end)
end

ActivityCharGiftCommonPopUpCtrl.OnShow = HL.Override() << function(self)
    if not self.m_waitingForClose then
        return
    end

    local onClosed = self.m_waitingCloseCallback
    self.m_waitingForClose = false
    self.m_waitingCloseCallback = nil
    self:_Close(onClosed)
end

HL.Commit(ActivityCharGiftCommonPopUpCtrl)
