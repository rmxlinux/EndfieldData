





_G.__enableHotfixLua__ = true

_G.__enableHotfixLua2__ = true

_G.__enableHotfixLua3__ = true

_G.__enableHotfixLua4__ = true


local oldInventoryCtrl = require_ex('UI/Panels/Inventory/InventoryCtrl')
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
InventoryCtrl = HL.Class('InventoryCtrl', uiCtrl.UICtrl)


InventoryCtrl._RefreshDepot = HL.Method() << function(self)
    self.m_depotInited = false
end


InventoryCtrl._OnRefreshPhaseLevel = HL.Method() << function(self)
    self:_RefreshWeekRaidStyle()
    self:_RefreshDepot()
end


InventoryCtrl._RefreshWeekRaidStyle = HL.Method() << function(self)
    local inWeekRaid = Utils.isInWeekRaid()
    self.m_weekRaidConvertRate = inWeekRaid and GameInstance.player.weekRaidSystem.ItemValueRate or nil
    if inWeekRaid then
        self.view.stateController:SetState("NoDepot")
        self.view.stateController:SetState("WeekRaid")

        self.view.weekRaidTitleBar.btnClose.onClick:RemoveAllListeners()
        self.view.weekRaidTitleBar.btnClose.onClick:AddListener(function()
            self:_OnClickClose()
        end)
        self.view.weekRaidTitleBar.helpBtn.onClick:RemoveAllListeners()
        self.view.weekRaidTitleBar.helpBtn.onClick:AddListener(function()
            UIManager:Open(PanelId.InstructionBook, "week_raid_item_bag")
        end)
    else
        self.view.stateController:SetState("NotWeekRaid")
    end

    local walletBarPlaceholder = self.view.walletBarPlaceholder
    walletBarPlaceholder.gameObject:SetActiveIfNecessary(not inWeekRaid)
    if not inWeekRaid then
        walletBarPlaceholder:InitWalletBarPlaceholder(JsonConst.INVENTORY_MONEY_IDS)
    end

    local blur = self.m_weekRaidBlur
    if inWeekRaid and not blur then
        local blurRootGo = GameObject("blur")
        blurRootGo:SetActive(false)
        blurRootGo.transform:SetParent(self.view.transform, false)
        blur = blurRootGo:AddComponent(typeof(CS.Beyond.UI.FullScreenSceneBlurMarker))
        blur.useWhiteBlur = false
        self.m_weekRaidBlur = blur
    end
    if blur then
        blur.gameObject:SetActiveIfNecessary(inWeekRaid)
    end

    self:_UpdateMouseHint()
    self.view.itemBag:_UpdateCount()
    self:_RefreshDepot()
end

HL.Commit(InventoryCtrl)


InventoryCtrl.s_messages[MessageConst.ON_REFRESH_PHASE_LEVEL] = '_OnRefreshPhaseLevel'
