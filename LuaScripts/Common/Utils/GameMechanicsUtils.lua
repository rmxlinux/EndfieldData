local GameMechanicsUtils = {}


function GameMechanicsUtils.isCurGameCanSwitchLanguage()
    local gameIdValid, gameMechanicData = Tables.gameMechanicTable:TryGetValue(GameWorld.worldInfo.curSubGameId)
    if not gameIdValid then
        return true
    end

    local gameCategoryValid, gameMechanicCategoryData = Tables.gameMechanicCategoryTable:TryGetValue(gameMechanicData.gameCategory)
    if not gameCategoryValid then
        return true
    end


    return gameMechanicCategoryData.canSwitchLanguage
end


function GameMechanicsUtils.tryGetGameMechanicCfg(gameMechanicId)
    return Tables.gameMechanicTable:TryGetValue(gameMechanicId)
end

function GameMechanicsUtils.tryGetGameMechanicCategoryCfg(gameMechanicId)
    local succ, gameMechanicCfg = GameMechanicsUtils.tryGetGameMechanicCfg(gameMechanicId)
    if not succ then
        return false, nil
    end
    return Tables.gameMechanicCategoryTable:TryGetValue(gameMechanicCfg.gameCategory)
end



_G.GameMechanicsUtils = GameMechanicsUtils
return GameMechanicsUtils