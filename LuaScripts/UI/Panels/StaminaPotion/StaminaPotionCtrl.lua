
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.StaminaPotion















StaminaPotionCtrl = HL.Class('StaminaPotionCtrl', uiCtrl.UICtrl)







StaminaPotionCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_STAMINA_CHANGED] = '_Refresh',
    [MessageConst.ON_DUNGEON_RESTORE_AP] = 'OnDungeonRestoreUp',
}


StaminaPotionCtrl.m_activityId = HL.Field(HL.String) << ''


StaminaPotionCtrl.m_currentStamina = HL.Field(HL.Number) << 0


StaminaPotionCtrl.m_lunchBoxCapacity = HL.Field(HL.Number) << 0


StaminaPotionCtrl.m_fillCount = HL.Field(HL.Number) << 0


StaminaPotionCtrl.m_fullLunchBoxCount = HL.Field(HL.Number) << 0


StaminaPotionCtrl.m_maxFullLunchBoxCount = HL.Field(HL.Number) << 0


StaminaPotionCtrl.m_itemId = HL.Field(HL.String) << ""





StaminaPotionCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    
    self.view.closeBtn.onClick:AddListener(function()
        self.view.animationWrapper:PlayOutAnimation(function()
            self:Close()
        end)
    end)
    self.m_itemId = args

    
    self.view.confirmBtn.onClick:AddListener(function()
        GameInstance.player.activitySystem:FillLunchBox(self.m_fillCount)
    end)

    
    self.m_currentStamina = GameInstance.player.inventory.curStamina
    self.m_lunchBoxCapacity = Tables.dungeonConst.restoreStaminaInAnEmptyLunchBox
    self.m_maxFullLunchBoxCount = Tables.dungeonConst.maxFullLunchBoxCount
    self.m_fillCount = 0

    
    self.view.moneyCell:InitMoneyCell(Tables.dungeonConst.staminaItemId)

    
    self.view.staminaTitleTxt.text = Tables.itemTable[Tables.dungeonConst.fullLunchBoxItemId].name
    self.view.describeTxt.text = Tables.itemTable[Tables.dungeonConst.fullLunchBoxItemId].desc

    
    if DeviceInfo.usingController then
        self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
        self.view.staminaItemNodeSelectableNaviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if isFocused then
                UIUtils.setAsNaviTarget(self.view.nullStaminaItem.itemBigBlack.view.button)
            else
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
        self.view.moneyCellKeyHint.gameObject:SetActive(true)
    end

    
    self:_Refresh()
end




StaminaPotionCtrl._ChangeFillCount = HL.Method(HL.Number) << function(self, curNumber)
    self.m_fillCount = curNumber
    self.view.fillingNumberTxt.text = self.m_fillCount
    self:_RefreshItem()
end



StaminaPotionCtrl._Refresh = HL.Method() << function(self)
    
    self.m_fullLunchBoxCount = Utils.getItemCount(Tables.dungeonConst.fullLunchBoxItemId,false)
    local fullLunchBoxCount = self.m_fullLunchBoxCount
    self.view.carryNumberTxt.text = fullLunchBoxCount

    
    self.m_currentStamina = GameInstance.player.inventory.curStamina
    local staminaEnough = self.m_currentStamina > self.m_lunchBoxCapacity

    
    local state = fullLunchBoxCount >= Tables.dungeonConst.maxFullLunchBoxCount and "Upper" or (staminaEnough and "Normal" or "Insufficient")
    self.view.contentState:SetState(state)


    UIUtils.setItemStorageCountText(self.view.nullStaminaItem.commonStorageNodeNew, self.m_itemId, 0, false)
    self.view.staminaItem.commonStorageNodeNew:InitStorageNode(self.m_currentStamina, self.m_fillCount * self.m_lunchBoxCapacity, false)

    
    local emptyLimit = Utils.getItemCount(self.m_itemId,false)
    local fullLimit = Tables.dungeonConst.maxFullLunchBoxCount - Utils.getItemCount(Tables.dungeonConst.fullLunchBoxItemId,false)
    local staminaLimit = self.m_currentStamina//self.m_lunchBoxCapacity
    self.view.numberSelector:InitNumberSelector(1, 1, math.max(math.min(emptyLimit, fullLimit, staminaLimit), 1) , function(curNumber)
        self:_ChangeFillCount(curNumber)
    end)

    
    self:_RefreshItem()
end



StaminaPotionCtrl._RefreshItem = HL.Method() << function(self)
    
    self.view.nullStaminaItem.itemBigBlack:InitItem({ id = self.m_itemId, count = self.m_fillCount },true)
    self.view.nullStaminaItem.itemBigBlack.view.button.enabled = true
    self.view.nullStaminaItem.itemBigBlack:SetExtraInfo({
        tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightMid,
        tipsPosTransform = self.view.staminaItemNode,
        isSideTips = true,
    })
    UIUtils.setItemStorageCountText(self.view.nullStaminaItem.commonStorageNodeNew, self.m_itemId, self.m_fillCount, false)

    
    self.view.staminaItem.itemBigBlack:InitItem({ id = Tables.dungeonConst.staminaItemId, count = self.m_fillCount * self.m_lunchBoxCapacity },true)
    self.view.staminaItem.itemBigBlack.view.button.enabled = true
    self.view.staminaItem.itemBigBlack:SetExtraInfo({
        tipsPosType = UIConst.UI_TIPS_POS_TYPE.RightMid,
        tipsPosTransform = self.view.staminaItemNode,
        isSideTips = true,
    })
    self.view.staminaItem.commonStorageNodeNew:InitStorageNode(self.m_currentStamina, self.m_fillCount * self.m_lunchBoxCapacity, false)
end




StaminaPotionCtrl.OnDungeonRestoreUp = HL.Method(HL.Any) << function(self,arg)
    
    local costStamina,costEmptyLunchBoxItem,rewardFullLunchBoxItem = unpack(arg)
    local lunchBoxAddCount = Utils.getItemCount(Tables.dungeonConst.fullLunchBoxItemId,false) - self.m_fullLunchBoxCount
    if lunchBoxAddCount > 0 then
        Notify(MessageConst.SHOW_SYSTEM_REWARDS, {
            title = Language.LUA_ACTIVITY_LUNCH_BOX_REWARD_TITLE,
            items = {
                { id = Tables.dungeonConst.fullLunchBoxItemId , count = lunchBoxAddCount }
            },
        })
        self:Close()
    end
end

HL.Commit(StaminaPotionCtrl)
