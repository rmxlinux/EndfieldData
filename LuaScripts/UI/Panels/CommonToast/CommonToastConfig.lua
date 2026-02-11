
function processItemOverflow(text, paramList, codeId)
    local chapterId = paramList[0]
    local succ, data = Tables.domainDataTable:TryGetValue(chapterId)
    return string.format(text, succ and data.storageName or Language.LUA_BLACK_BOX_DEPOT_NAME)
end

function processUGCBanned(text, paramList, codeId)
    local endTime = paramList[1]
    return os.date(text, endTime)
end

function processFacNodeLimit(text, paramList, codeId)
    local curNum = tonumber(paramList[0])
    local limitNum = tonumber(paramList[1])
    return string.format(text, curNum, limitNum)
end

local cfg = {
    [CS.Proto.CODE.ErrItemBagBagOverflowToFactoryDepot] = processItemOverflow,
    [CS.Proto.CODE.ErrItemBagDestroyOverflowItems] = processItemOverflow,

    [CS.Proto.CODE.ErrUgcpunishedBanChangeName] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanChangeSignature] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanChangeRemark] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanChangeTeamName] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanEditBluePrint] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanShare] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanFriendRequest] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanMapMark] = processUGCBanned,
    [CS.Proto.CODE.ErrUgcpunishedBanMapMarkEdit] = processUGCBanned,

    [CS.Proto.CODE.ErrFactoryPlaceLimitNodeAll] = processFacNodeLimit,
    [CS.Proto.CODE.ErrFactoryPlaceBuildingLimit] = processFacNodeLimit,
    [CS.Proto.CODE.ErrFactoryPlaceFluidRouterLimit] = processFacNodeLimit,
    [CS.Proto.CODE.ErrFactoryPlaceFluidConveyorLimit] = processFacNodeLimit,
}
return cfg
