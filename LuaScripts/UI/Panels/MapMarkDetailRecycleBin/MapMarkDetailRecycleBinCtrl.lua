local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailRecycleBin











MapMarkDetailRecycleBinCtrl = HL.Class('MapMarkDetailRecycleBinCtrl', uiCtrl.UICtrl)


MapMarkDetailRecycleBinCtrl.m_rewardItemCache = HL.Field(HL.Forward('UIListCache'))


MapMarkDetailRecycleBinCtrl.m_markInstId = HL.Field(HL.String) << ""


MapMarkDetailRecycleBinCtrl.m_recycleBinData = HL.Field(CS.Beyond.Gameplay.RecycleBinData)


MapMarkDetailRecycleBinCtrl.m_recyclingCor = HL.Field(HL.Thread)






MapMarkDetailRecycleBinCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}





MapMarkDetailRecycleBinCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_rewardItemCache = UIUtils.genCellCache(self.view.item)
    self.m_markInstId = arg.markInstId

    self:_InitRecycleBinInfo()
    self:_InitController()
end







MapMarkDetailRecycleBinCtrl.OnClose = HL.Override() << function(self)
    if self.m_recyclingCor then
        self.m_recyclingCor = self:_ClearCoroutine(self.m_recyclingCor)
    end
end



MapMarkDetailRecycleBinCtrl._InitRecycleBinInfo = HL.Method() << function(self)
    local markInstId = self.m_markInstId
    local getRuntimeDataSuccess, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(markInstId)
    if not getRuntimeDataSuccess then
        logger.error("地图详情页获取实例数据失败" .. self.m_instId)
        return
    end

    local detail = markRuntimeData.detail
    local recycleBinId = detail.systemInstId

    local recycleBinCfg = Tables.recycleBinTable[recycleBinId]
    local isUnlock, recycleBinData = GameInstance.player.recycleBinSystem.recycleBins:TryGetValue(recycleBinId)
    local curLv = isUnlock and recycleBinData.lv or 0
    local levelData = recycleBinCfg.levelData
    local descRawText = isUnlock and levelData[curLv].desc or recycleBinCfg.unlockDesc

    self.view.mapMarkDetailCommonStateController:SetState(isUnlock and "Unlocked" or "Locked")
    self.m_recycleBinData = recycleBinData

    if isUnlock then
        local isMaxLv = recycleBinData.isMaxLv
        self.view.lvStateNode:SetState(isMaxLv and "Max" or "Nrl")
        self.view.lvNumTxt.text = curLv

        local rewardId = levelData[curLv].rewardId
        local rewardBundles = UIUtils.getRewardItems(rewardId)
        
        self.m_rewardItemCache:Refresh(#rewardBundles, function(cell, luaIndex)
            self.view.mapMarkDetailCommon:InitDetailItem(cell, rewardBundles[luaIndex], {
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftMid,
                tipsPosTransform = self.view.scrollView,
            })
        end)

        self:_UpdateCanPickUp()
        self.m_recyclingCor = self:_StartCoroutine(function()
            while true do
                coroutine.wait(UIConst.COMMON_UI_TIME_UPDATE_INTERVAL)
                self:_UpdateCanPickUp()
            end
        end)
    end

    local commonArgs = {}
    commonArgs.bigBtnActive = true
    commonArgs.markInstId = self.m_markInstId
    commonArgs.descText = descRawText
    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon(commonArgs)
end



MapMarkDetailRecycleBinCtrl._UpdateCanPickUp = HL.Method() << function(self)
    if not self.m_recycleBinData then
        return
    end

    local cd = self.m_recycleBinData:GetCoolDownBySeconds()
    local canPick = cd <= 0
    self.view.canPickNode.gameObject:SetActive(canPick)
    self.view.recyclingNode.gameObject:SetActive(not canPick)

    if not canPick then
        self.view.timeTxt.text = UIUtils.getLeftTimeToSecond(cd)
    end
end



MapMarkDetailRecycleBinCtrl._InitController = HL.Method() << function(self)
    if DeviceInfo.usingController then
        self.view.rewardList.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
    end
end

HL.Commit(MapMarkDetailRecycleBinCtrl)
