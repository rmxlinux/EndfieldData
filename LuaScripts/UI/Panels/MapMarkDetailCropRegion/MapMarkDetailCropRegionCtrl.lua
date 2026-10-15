local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailCropRegion
local CELL_ENTER_ANIMATION_NAME = "mapdetailcropregion_cell_in"

MapMarkDetailCropRegionCtrl = HL.Class('MapMarkDetailCropRegionCtrl', uiCtrl.UICtrl)

MapMarkDetailCropRegionCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}

MapMarkDetailCropRegionCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local markInstId = arg.markInstId
    local _, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(markInstId)

    self.view.mapMarkDetailCommon:InitMapMarkDetailCommon({ markInstId = markInstId, bigBtnActive = true })

    local cropItems = markRuntimeData:GetRegionCropItems()
    if cropItems.Count > 0 then
        local cellCache = UIUtils.genCellCache(self.view.cropItemCell)

        local refreshItems = {}
        for itemId, count in cs_pairs(cropItems) do
            local itemCfg = Tables.itemTable[itemId]
            table.insert(refreshItems, {
                id = itemId,
                count = count,
                rarity = itemCfg.rarity,
                sortId1 = itemCfg.sortId1,
                sortId2 = itemCfg.sortId2,
                name = itemCfg.name
            })
        end
        table.sort(refreshItems, Utils.genSortFunction({"rarity", "sortId1", "sortId2"}))

        cellCache:Refresh(#refreshItems, function(cell, luaIndex)
            local refreshItemData = refreshItems[luaIndex]
            self.view.mapMarkDetailCommon:InitDetailItem(cell.item, refreshItemData, {
                tipsPosType = UIConst.UI_TIPS_POS_TYPE.LeftTop,
                tipsPosTransform = self.view.scrollView,
            })
            cell.nameTxt.text = refreshItemData.name

            cell.animationWrapper:ClearTween(false)
            cell.animationWrapper:SampleClipAtPercent(CELL_ENTER_ANIMATION_NAME, 0)
            self:_StartTimer(luaIndex * self.view.config.CELL_DELAY_ANIM_IN_TIME, function()
                cell.animationWrapper:Play(CELL_ENTER_ANIMATION_NAME)
            end)
        end)
    else
        self.view.contentController:SetState("Empty")
    end

    if DeviceInfo.usingController then
        local scrollRect = self.view.scrollView:GetComponent(typeof(CS.Beyond.UI.UIScrollRect))
        local naviGroup = scrollRect.naviGroup
        naviGroup.onIsFocusedChange:AddListener(function(isFocused)
            if not isFocused then
                scrollRect:KillScrollTween()
                scrollRect:StopMovement()
                scrollRect.verticalNormalizedPosition = 1
                naviGroup:ClearLastFocusNaviTarget()
                Notify(MessageConst.HIDE_ITEM_TIPS)
            end
        end)
    end
end

HL.Commit(MapMarkDetailCropRegionCtrl)
