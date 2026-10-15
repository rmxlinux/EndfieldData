














local MoneyCellConfig = {}


local _resolved = nil

local function ensureResolved()
    if _resolved then return end
    _resolved = {
        [Tables.globalConst.apItemId] = {
            getDisplayText = function()
                local cur = GameInstance.player.inventory.curStamina
                local max = GameInstance.player.inventory.maxStamina
                return cur, max
            end,
            showAddBtn = true,
            needTick = true,
            onInit = function(cell)
                cell.view.tip:InitStaminaTips()
            end,
            onDisable = function(cell)
                cell.view.tip.gameObject:SetActive(false)
            end,
            refreshMessages = {
                [MessageConst.ON_STAMINA_CHANGED] = function(cell, _evtData)
                    cell:_UpdateCount()
                    local cur = GameInstance.player.inventory.curStamina
                    local max = GameInstance.player.inventory.maxStamina
                    if cur >= max then
                        cell.view.tip.gameObject:SetActiveIfNecessary(false)
                    end
                end,
            },
            onClickItem = function(cell)
                local ctx = cell.m_context
                if ctx and ctx.showItemTips then
                    cell:_OnClickItem2ShowItemTips()
                elseif DeviceInfo.usingController then
                    local closeFun = ctx and ctx.closeFun or nil
                    PhaseManager:OpenPhase(PhaseId.StaminaPopUp, { closeFun = closeFun })
                    if ctx and ctx.clickFun then
                        ctx.clickFun()
                    end
                else
                    local curStamina = GameInstance.player.inventory.curStamina
                    local maxStamina = GameInstance.player.inventory.maxStamina
                    if curStamina >= maxStamina then
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_STAMINA_FULL_HINT)
                    else
                        local active = cell.view.tip.gameObject.activeSelf
                        cell.view.tip.gameObject:SetActive(not active)
                    end
                end
                AudioAdapter.PostEvent("au_ui_btn_ap_info")
            end,
            onClickAddItem = function(cell)
                PhaseManager:OpenPhase(PhaseId.StaminaPopUp)
                local ctx = cell.m_context
                if ctx and ctx.clickFun then
                    ctx.clickFun()
                end
            end,
        },

        [Tables.globalConst.diamondItemId] = {
            showAddBtn = true,
            onClickAddItem = function(cell)
                PhaseManager:OpenPhase(PhaseId.CommonMoneyExchange, {
                    sourceId = Tables.globalConst.originiumItemId,
                    targetId = Tables.globalConst.diamondItemId,
                    onClose = function()
                        local ctrl = cell:GetUICtrl()
                        if DeviceInfo.usingController and not ctrl.m_isClosed and ctrl.view.contentNaviGroup then
                            ctrl.view.contentNaviGroup:ManuallyFocus()
                        end
                    end,
                })
            end,
        },

        [Tables.globalConst.originiumItemId] = {
            showAddBtn = function()
                return not UIManager:IsShow(PanelId.ShopRecharge)
            end,
            addBtnKeyHintText = function()
                return Language.key_hint_cashshop_originium_buy
            end,
            onClickAddItem = function(cell)
                CashShopUtils.GotoCashShopRechargeTab()
            end,
        },

        [Tables.globalConst.gachaWeaponItemId] = {
            showAddBtn = true,
            onClickAddItem = function(cell)
                PhaseManager:OpenPhase(PhaseId.CommonMoneyExchange, {
                    sourceId = Tables.globalConst.originiumItemId,
                    targetId = Tables.globalConst.gachaWeaponItemId,
                    onClose = function()
                        if DeviceInfo.usingController then
                            local naviGroup = cell:GetUICtrl().view.contentNaviGroup
                            if naviGroup then
                                naviGroup:ManuallyFocus()
                            end
                        end
                    end,
                })
            end,
        },

        ["inn_star_display"] = {
            iconAtlas = UIConst.UI_SPRITE_INN_ICON,
            iconId = "icon_inn_totalstar",
            skipDefaultRefresh = true,
            getDisplayText = function()
                local innSystem = GameInstance.player.innSystem
                local currentStar = 0
                local maxStar = 0
                for topicId, topicData in pairs(Tables.innTopicTable) do
                    if topicData.starRequiredScore and topicData.topicType ~= GEnums.InnTopicType.PrivateChef then
                        currentStar = currentStar + (innSystem.starRecord:GetValue(CS.Beyond.Cfg.Tables.innManagementTopicIdToNum:GetValue(topicId)) or 0)
                        maxStar = maxStar + topicData.starRequiredScore.Count
                    end
                end
                return currentStar, maxStar
            end,
            onClickItem = function(cell)
                if UIManager:IsOpen(PanelId.InnStaminaTips) then
                    UIManager:Close(PanelId.InnStaminaTips)
                end
                if cell.isSelected then
                    cell:SetSelected(false)
                    return
                end
                cell:SetSelected(true)
                UIManager:Open(PanelId.InnStaminaTips, {
                    transform = cell.view.transform,
                    isStarRating = true,
                    onClose = function()
                        cell:SetSelected(false)
                    end,
                })
            end,
        },

        ["inn_customer_volume_display"] = {
            iconAtlas = UIConst.UI_SPRITE_INN_ICON,
            iconId = "icon_inn_customerrecover",
            needTick = true,
            getDisplayText = function()
                local innSystem = GameInstance.player.innSystem
                local curLevel = innSystem.innLevel
                local hasLevel, levelData = Tables.innLevelTable:TryGetValue(curLevel)
                local maxVolume = (hasLevel and levelData) and levelData.customerVolume or 0
                return innSystem.customerVolume, maxVolume
            end,
            refreshMessages = {
                [MessageConst.ON_INN_CUSTOMER_VOLUME_CHANGED] = function(cell, _evtData)
                    cell:_UpdateCount()
                end,
            },
            onClickItem = function(cell)
                if UIManager:IsOpen(PanelId.InnStaminaTips) then
                    UIManager:Close(PanelId.InnStaminaTips)
                end
                if cell.isSelected then
                    cell:SetSelected(false)
                    return
                end
                cell:SetSelected(true)
                UIManager:Open(PanelId.InnStaminaTips, {
                    transform = cell.view.transform,
                    onClose = function()
                        cell:SetSelected(false)
                    end,
                })
            end,
        },
    }
end



function MoneyCellConfig.get(itemId)
    ensureResolved()
    return _resolved[itemId]
end

return MoneyCellConfig
