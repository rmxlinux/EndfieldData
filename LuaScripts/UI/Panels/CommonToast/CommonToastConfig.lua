
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

function processFacOpDismantleBuildingOtherChapter(text, paramList, codeId)
    local chapterName
    local chapterId = paramList[0]
    if chapterId == "spaceship" then
        chapterName = Language.LUA_SPACESHIP_NAME
    else
        local success, domainData = Tables.domainDataTable:TryGetValue(chapterId)
        chapterName = success and domainData.domainName or ""
    end
    return string.format(text, chapterName)
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

    
    [CS.Proto.CODE.ErrFactoryOpDismantleBuildingOtherChapter] = processFacOpDismantleBuildingOtherChapter,
}
return cfg
