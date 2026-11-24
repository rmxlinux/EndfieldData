local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


MultiplayerGameInfoNode = HL.Class('MultiplayerGameInfoNode', UIWidgetBase)


MultiplayerGameInfoNode.InitMultiplayerGameInfoNode = HL.Method(HL.Table) << function(self, args)
    args = args or {}
    local gameId = args.gameId or ""
    local data = nil

    if not string.isEmpty(gameId) then
        local found, gameData = Tables.multiplayerGameCenterTable:TryGetValue(gameId)
        if found then
            data = gameData
        else
            logger.error("[MultiplayerGameInfoNode] multiplayerGameCenterTable 查不到 gameId", gameId)
        end
    end

    self.view.gameNameTxt.text = data and data.gameName or ""
    self.view.gameDescTxt.text = data and data.gameDesc or ""
    self.view.gamePlayerNumTxt.text = data and tostring(data.roomMaxPlayerNum) or ""
    self.view.gameAvailableTimeTxt.text = data and MultiplayerUtils.getGameAvailableTimeText(data.availableTimeId) or ""
    if data then
        self.view.gameIconImg:LoadSprite(UIConst.UI_SPRITE_MULTIPLAYER, data.gameIntroIconName)
    end
end

HL.Commit(MultiplayerGameInfoNode)
return MultiplayerGameInfoNode
