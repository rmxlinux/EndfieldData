local GameSetting = CS.Beyond.GameSetting
local GameSettingHelper = CS.Beyond.Gameplay.GameSettingHelper

local autoCalcOrderUICtrl = require_ex('UI/Panels/Base/AutoCalcOrderUICtrl')
local PANEL_ID = PanelId.WalletBar



















WalletBarCtrl = HL.Class('WalletBarCtrl', autoCalcOrderUICtrl.AutoCalcOrderUICtrl)








WalletBarCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.HIDE_WALLET_BAR] = 'HideWalletBar',
    [MessageConst.HIDE_WALLET_BAR_FORCE] = 'HideWalletBarForce',
    [MessageConst.SHOW_WALLET_BAR_FORCE] = 'ShowWalletBarForce',

    [MessageConst.PLAY_WALLET_BAR_OUT_ANIM] = 'PlayOutAnim',

    [MessageConst.ON_BLOCK_KEYBOARD_EVENT_PANEL_ORDER_CHANGED] = 'PanelOrderChanged',

    [MessageConst.ON_SCREEN_SIZE_CHANGED] = '_OnScreenSizeChanged',
}


WalletBarCtrl.m_moneyCells = HL.Field(HL.Forward('UIListCache'))


WalletBarCtrl.m_defaultPaddingTop = HL.Field(HL.Number) << -1


WalletBarCtrl.m_defaultPaddingRight = HL.Field(HL.Number) << -1


WalletBarCtrl.m_baseNotchPaddingPixel = HL.Field(HL.Number) << -1


WalletBarCtrl.m_deltaNotchPaddingPixel = HL.Field(HL.Number) << -1





WalletBarCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_moneyCells = UIUtils.genCellCache(self.view.moneyCell)
    self.m_attachedPanels = {}

    local padding = self.view.contentLayout.padding
    self.m_defaultPaddingTop = padding.top
    self.m_defaultPaddingRight = padding.right

    self.view.contentNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
        if not isFocused then
            Notify(MessageConst.HIDE_ITEM_TIPS)
        end
    end)
    self.view.contentNaviGroup.getDefaultSelectableFunc = function()
        local cell = self.m_moneyCells:GetItem(self.m_moneyCells:GetCount())
        return cell.view.button
    end
end



WalletBarCtrl.OnShow = HL.Override() << function(self)
    
    local notchPadding = GameSetting.videoCachedNotchPadding
    self.m_baseNotchPaddingPixel = GameSettingHelper.GetGameSettingCanvasPaddingFromNotchPadding(notchPadding, UIManager.uiCanvasRect.rect.width)
    self.m_deltaNotchPaddingPixel = 0

    self.view.contentNaviGroup:ManuallyRefreshRelatedBindingGroups()
end



WalletBarCtrl.OnHide = HL.Override() << function(self)
    if self.m_curArgs == nil then
        self.view.contentNaviGroup:ManuallyStopFocus()
        self.view.contentNaviGroup:ClearLastFocusNaviTarget()
    end
    self.view.contentNaviGroup:ManuallyRefreshRelatedBindingGroups()
    Notify(MessageConst.HIDE_ITEM_TIPS)
end




WalletBarCtrl.OnAnimationInFinished = HL.Override() << function(self)
    if DeviceInfo.usingController and self.view.contentNaviGroup.IsTopLayer then
        local target = self.view.contentNaviGroup.LayerSelectedTarget
        if target then
            
            target.onClick:Invoke(nil)
        end
    end
end













WalletBarCtrl.ShowWalletBar = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = WalletBarCtrl.AutoOpen(PANEL_ID, nil, true)
    ctrl:_AttachToPanel(args)
end




WalletBarCtrl.HideWalletBar = HL.Method(HL.Number) << function(self, panelId)
    self:_CustomHide(panelId)
end



WalletBarCtrl.HideWalletBarForce = HL.Method() << function(self)
    self:Hide()
end



WalletBarCtrl.ShowWalletBarForce = HL.Method() << function(self)
    self:Show()
end





WalletBarCtrl.CustomSetPanelOrder = HL.Override(HL.Opt(HL.Number, HL.Table)) << function(self, maxOrder, args)
    self:SetSortingOrder(maxOrder, false)
    self:UpdateInputGroupState()
    if self.m_curArgs ~= args then
        self.m_curArgs = args
        self:_RefreshContent()
    end
    if self:IsShow(true) then
        
    else
        self:Show()
    end
end



WalletBarCtrl.StopFocus = HL.Method() << function(self)
    self.view.contentNaviGroup:ManuallyStopFocus()
end



WalletBarCtrl._RefreshContent = HL.Method() << function(self)
    if not self.m_curArgs then
        return
    end

    local padding = self.view.contentLayout.padding
    padding.right = lume.round((self.m_curArgs.paddingRight or self.m_defaultPaddingRight) + self.m_deltaNotchPaddingPixel)
    padding.top = lume.round(self.m_curArgs.paddingTop or self.m_defaultPaddingTop)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.contentLayout.transform)

    local staminaCloseFun
    if self.m_curArgs.focusAfterCLick == true then
        staminaCloseFun = function()
            self.view.contentNaviGroup:ManuallyStopFocus()
        end
    end

    local staminaClickFunc
    if self.m_curArgs.closeCommonPopupAfterClickStamina == true then
        staminaClickFunc = function()
            Notify(MessageConst.HIDE_POP_UP)
        end
    end

    local moneyIds = self.m_curArgs.moneyIds
    local cellPreferredWidths = self.m_curArgs.cellPreferredWidths or {}
    if moneyIds ~= nil then
        
        self.m_moneyCells:Refresh(#moneyIds, function(cell, index)
            local itemId = moneyIds[index]
            local cellPreferredWidth = cellPreferredWidths[itemId]
            cell:InitMoneyCell(itemId, self.m_curArgs.useMoneyCellAction, self.m_curArgs.useItemIcon, self.m_curArgs.showLimit, nil, cellPreferredWidth)
            if cell:IsStamina() then
                cell:SetStaminaCloseFun(staminaCloseFun)
                cell:SetStaminaClickFun(staminaClickFunc)
                
                
                cell:SetStaminaShowItemTips(#moneyIds > 1 and DeviceInfo.usingController)
            end
            
            if cell:IsOriginium() then
                cell:SetAddBtnKeyHintText(Language.key_hint_cashshop_originium_buy)
            else
                cell:SetAddBtnKeyHintText(Language.key_hint_money_cell_add)
            end
        end)

        self.view.contentNaviGroup.focusHighlightNormalFrame = #moneyIds > 1
    end
end



WalletBarCtrl._OnScreenSizeChanged = HL.Method() << function(self)
    
    
    local notchPadding = GameSetting.videoCachedNotchPadding
    local notchPaddingPixel = GameSettingHelper.GetGameSettingCanvasPaddingFromNotchPadding(notchPadding, UIManager.uiCanvasRect.rect.width)
    local deltaPaddingPixel = notchPaddingPixel - self.m_baseNotchPaddingPixel
    if self.m_deltaNotchPaddingPixel == deltaPaddingPixel then
        return
    end

    self.m_deltaNotchPaddingPixel = deltaPaddingPixel
    self:_RefreshContent()
end

HL.Commit(WalletBarCtrl)
