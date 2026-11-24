local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')


MultiplayerMatchPlayCell = HL.Class('MultiplayerMatchPlayCell', UIWidgetBase)


local NODE_STATE_NORMAL = "Normal"
local NODE_STATE_SELECT = "Select"
local NODE_STATE_LOCK = "Lock"

MultiplayerMatchPlayCell.m_args = HL.Field(HL.Table)
MultiplayerMatchPlayCell.m_gameId = HL.Field(HL.String) << ""


MultiplayerMatchPlayCell._OnFirstTimeInit = HL.Override() << function(self)
    self.view.clickBtn.onClick:RemoveAllListeners()
    self.view.clickBtn.onClick:AddListener(function()
        
        self.m_args.onClick(self.m_gameId)
    end)
end


MultiplayerMatchPlayCell.InitMultiplayerMatchPlayCell = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()
    self.m_args = args
    self.m_gameId = args.gameId
    self.gameObject.name = self.m_gameId
    self.view.redDot:InitRedDot("MultiplayerNewGame", self.m_gameId)

    
    self:SetSelected(false)

    
    local data = Tables.multiplayerGameCenterTable[self.m_gameId]
    self.view.gameNameTxt.text = data.gameName
    self.view.gamePlayerNumTxt.text = tostring(data.roomMaxPlayerNum)
    self.view.playImg:LoadSprite(UIConst.UI_SPRITE_MULTIPLAYER, data.gameSelectCardImgName)
    self.view.gameAvailableTimeTxt.text = MultiplayerUtils.getGameAvailableTimeText(data.availableTimeId)
    self:RefreshAvailableTime()
end


MultiplayerMatchPlayCell.RefreshAvailableTime = HL.Method() << function(self)
    self.view.availableTimeTxt.text = ""
    local gameCenter = GameInstance.player.multiplayerGameCenterSystem
    if not gameCenter:IsGameVisible(self.m_gameId) or gameCenter:IsGameTimeAvailable(self.m_gameId) then
        return
    end
    local data = Tables.multiplayerGameCenterTable[self.m_gameId]
    local openTimestamp = Utils.getTimeIdOpenTimeStamp(data.availableTimeId)
    if openTimestamp == nil then
        return
    end
    local leftSeconds = openTimestamp - DateTimeUtils.GetCurrentTimestampBySeconds()
    self.view.availableTimeTxt.text = string.format(Language.LUA_MULTIPLAYER_GAME_OPEN_COUNTDOWN, UIUtils.getShortLeftTime(leftSeconds))
end


MultiplayerMatchPlayCell.SetSelected = HL.Method(HL.Boolean) << function(self, selected)
    if not GameInstance.player.multiplayerGameCenterSystem:IsGameAvailable(self.m_gameId) then
        self.view.nodeState:SetState(NODE_STATE_LOCK)
        return
    end
    self.view.nodeState:SetState(selected and NODE_STATE_SELECT or NODE_STATE_NORMAL)
end

HL.Commit(MultiplayerMatchPlayCell)
return MultiplayerMatchPlayCell