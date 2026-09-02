local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

ArcheryChipSet = HL.Class('ArcheryChipSet', UIWidgetBase)


ArcheryChipSet._OnFirstTimeInit = HL.Override() << function(self)
    
end

ArcheryChipSet.InitArcheryChipSet = HL.Method(HL.Boolean,HL.Any, HL.Boolean) << function(self, isLocked, chipIds, csIndex)
    self:_FirstTimeInit()
    for i=1, self.view.config.chipSlotCount  do
        local slotName = string.format("chipSlotNode%d", i)
        local index = csIndex and CSIndex(i) or i
        local chipId
        if csIndex and index >= chipIds.Count then
            chipId = nil
        else
            chipId = chipIds[index]
        end

        local state = "UnLock"
        if chipId then
            local _ , chipInfo = Tables.typhoeaArcheryChipTable:TryGetValue(chipId)
            local _, itemData = Tables.itemTable:TryGetValue(chipInfo.portableDeviceId)
            if isLocked then
                state = "Lock"
            end
            self.view[slotName].icon:LoadSprite(UIConst.UI_SPRITE_ITEM, itemData.iconId)
        else
            self.view[slotName].icon:LoadSprite(UIConst.UI_SPRITE_TYPHOEA_ARCHERY, self.view.config.emptySprite)
        end
        self.view[slotName].stateController:SetState(state)
    end
end

HL.Commit(ArcheryChipSet)
return ArcheryChipSet

