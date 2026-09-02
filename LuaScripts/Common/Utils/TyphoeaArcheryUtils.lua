local TyphoeaArcheryUtils = {}


local archeryNewDayRead = "arhcery_new_day_read"
function TyphoeaArcheryUtils.isNewDayRead()
    return ClientDataManagerInst:GetBool(archeryNewDayRead, false)
end
function TyphoeaArcheryUtils.setNewDayRead()
    if TyphoeaArcheryUtils.isNewDayRead() then
        return
    end
    ClientDataManagerInst:SetBool(archeryNewDayRead, true, false, EClientDataTimeValidType.CurrentDayUntil4AM)
    Notify(MessageConst.ON_TYPHOEA_ARCHERY_NEW_DAY_READ)
end


local archeryNoTipToday = "arhcery_no_tip"
function TyphoeaArcheryUtils.isNoTipToday(tiptype)
    local id = archeryNoTipToday .. tiptype
    return ClientDataManagerInst:GetBool(id, false)
end
function TyphoeaArcheryUtils.setNoTipToday(tiptype)
    if TyphoeaArcheryUtils.isNoTipToday(tiptype) then
        return
    end
    local id = archeryNoTipToday .. tiptype
    ClientDataManagerInst:SetBool(id, true, false, EClientDataTimeValidType.CurrentDayUntil4AM)
end


function TyphoeaArcheryUtils.getGameIdsByPoiLevel(level, tableData, levelOnly)
    local previewSimGameInfos = {}
    if levelOnly then
        for _, info in pairs(tableData) do
            if info.unlockLevel == level then
                table.insert(previewSimGameInfos, info)
            end
        end
    else
        for _, info in pairs(tableData) do
            if info.unlockLevel <= level then
                table.insert(previewSimGameInfos, info)
            end
        end
    end
    table.sort(previewSimGameInfos,Utils.genSortFunction({"unlockLevel", "sortId"}, true))
    return previewSimGameInfos
end


_G.TyphoeaArcheryUtils = TyphoeaArcheryUtils
return TyphoeaArcheryUtils