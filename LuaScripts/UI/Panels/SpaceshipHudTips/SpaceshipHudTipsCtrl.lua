
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipHudTips















SpaceshipHudTipsCtrl = HL.Class('SpaceshipHudTipsCtrl', uiCtrl.UICtrl)







SpaceshipHudTipsCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_CHAR_FRIENDSHIP_CHANGED] = 'OnCharFriendshipChanged',
    [MessageConst.INTERRUPT_MAIN_HUD_ACTION_QUEUE] = 'InterruptMainHudActionQueue',
}



SpaceshipHudTipsCtrl.m_getCellFunc = HL.Field(HL.Function)


SpaceshipHudTipsCtrl.m_charFavDatas = HL.Field(HL.Table)


SpaceshipHudTipsCtrl.m_isFirstTime = HL.Field(HL.Boolean) << true







SpaceshipHudTipsCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_getCellFunc = UIUtils.genCachedCellFunction()
    self.view.friendshipNode.toastList.onUpdateCell:AddListener(function(obj, index)
        self.view.friendshipNode.gameObject:SetActive(true)
        self:_OnUpdateCell(self.m_getCellFunc(obj), LuaIndex(index))
    end)
    self.view.friendshipNode.toastList.onAllToastFinished:AddListener(function()
        self:_OnAllToastFinished()
    end)
    self.view.productNode.button.onClick:AddListener(function()
        self.view.productNode.animation:ClearTween(false)
        self:_Exit()
        PhaseManager:OpenPhase(PhaseId.SpaceshipCollectHintInfo)
    end)
end


SpaceshipHudTipsCtrl.OnLoadingPanelClosed = HL.StaticMethod() << function()
    if not Utils.isInSpaceShip() or UIManager:IsOpen(PANEL_ID) then
        return
    end
    local self = UIManager:Open(PANEL_ID)
    self.view.main.gameObject:SetActive(false)
    LuaSystemManager.mainHudActionQueue:AddRequest("SpaceshipHudTips", function()
        
        if not UIManager:IsOpen(PANEL_ID) then
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
            return
        end
        self:_TryShowFavToast()
    end)
end



SpaceshipHudTipsCtrl.OnCharFriendshipChanged = HL.Method() << function(self)
    LuaSystemManager.mainHudActionQueue:AddRequest("SpaceshipHudTips", function()
        
        if not UIManager:IsOpen(PANEL_ID) then
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
            return
        end
        self:_TryShowFavToast()
    end)
end



SpaceshipHudTipsCtrl._TryShowFavToast = HL.Method() << function(self)
    logger.info("SpaceshipHudTipsCtrl._TryShowFavToast")

    if self.view.friendshipNode.toastList.inAnimation then
        logger.info("self.view.friendshipNode.toastList.inAnimation")
        Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
        return
    end

    self.m_charFavDatas = {}
    for k, v in pairs(GameInstance.player.spaceship.characters) do
        if v.oldFav >= 0 then
            local oldPercent = math.floor(CSPlayerDataUtil.GetFriendshipPercent(v.oldFav) * 100)
            local newPercent = math.floor(CSPlayerDataUtil.GetFriendshipPercent(v.friendship) * 100)
            if newPercent > oldPercent then
                table.insert(self.m_charFavDatas, {
                    charId = k,
                    oldPercent = oldPercent,
                    newPercent = newPercent,
                })
                v.oldFav = -1
            end
        end
    end
    local count = #self.m_charFavDatas
    logger.info("SpaceshipHudTipsCtrl._TryShowFavToast", count, self.m_isFirstTime)

    if self.m_isFirstTime then
        self.view.main.gameObject:SetActive(true)
        if count > 0 then
            self.view.friendshipNode.gameObject:SetActive(true)
            AudioAdapter.PostEvent("Au_UI_Popup_SpaceshipHudTipsPanel_Open")

            self.view.productNode.gameObject:SetActive(false)
            self.view.friendshipNode.toastList:AddToast(count)
        else
            self.view.friendshipNode.gameObject:SetActive(false)
            self.view.friendshipNode.toastList:ClearAllToast()
            self:_TryShowProductHint()
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
        end
    else
        if count > 0 then
            self.view.main.gameObject:SetActive(true)
            self.view.friendshipNode.gameObject:SetActive(true)
            AudioAdapter.PostEvent("Au_UI_Popup_SpaceshipHudTipsPanel_Open")

            self.view.productNode.gameObject:SetActive(false)
            self.view.friendshipNode.toastList:AddToast(count)
        else
            Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
        end
    end
end





SpaceshipHudTipsCtrl._OnUpdateCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    local info = self.m_charFavDatas[index]
    local charData = Tables.characterTable[info.charId]
    cell.nameTxt.text = charData.name
    cell.charIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD, UIConst.UI_CHAR_HEAD_PREFIX .. info.charId)
    cell.newFriendshipTxt.text = string.format(Language.LUA_SPACESHIP_CHAR_FRIENDSHIP_FORMAT, info.newPercent)
    cell.oldFriendshipTxt.text = string.format(Language.LUA_SPACESHIP_CHAR_FRIENDSHIP_FORMAT, info.oldPercent)
end



SpaceshipHudTipsCtrl._OnAllToastFinished = HL.Method() << function(self)
    AudioAdapter.PostEvent("Au_UI_Popup_SpaceshipHudTipsPanel_Close")
    self.view.friendshipNode.animationWrapper:PlayOutAnimation(function()
        self.view.friendshipNode.gameObject:SetActive(false)
        self.view.friendshipNode.toastList:ClearAllToast()
        self:_TryShowProductHint()
    end)
end



SpaceshipHudTipsCtrl._TryShowProductHint = HL.Method() << function(self)
    do
        self.view.main.gameObject:SetActive(false)
        return
    end

    if not self.m_isFirstTime then
        self:_Exit()
        return
    end
    self.m_isFirstTime = false
    if not GameInstance.player.spaceship:HasAnyProductToCollect() then
        logger.info("SpaceshipHudTipsCtrl._TryShowProductHint Fail")
        self:_Exit()
        return
    end
    logger.info("SpaceshipHudTipsCtrl._TryShowProductHint Succ")
    self.view.productNode.gameObject:SetActive(true)
    self.view.productNode.animation:PlayInAnimation(function()
        self:_Exit()
    end)
end



SpaceshipHudTipsCtrl._Exit = HL.Method() << function(self)
    self.view.main.gameObject:SetActive(false)
    Notify(MessageConst.ON_ONE_MAIN_HUD_ACTION_FINISHED, "SpaceshipHudTips")
end



SpaceshipHudTipsCtrl.InterruptMainHudActionQueue = HL.Method() << function(self)
    self.view.productNode.animation:ClearTween(false)
    self.view.main.gameObject:SetActive(false)
end

HL.Commit(SpaceshipHudTipsCtrl)
