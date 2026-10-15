local FriendListCell = require_ex('UI/Widgets/FriendListCell')

ClueGiftFriendListCell = HL.Class('ClueGiftFriendListCell', FriendListCell)


ClueGiftFriendListCell._OnFirstTimeInit = HL.Override() << function(self)
    ClueGiftFriendListCell.Super._OnFirstTimeInit(self)

    self.view.onlineState.gameObject:SetActiveIfNecessary(false)
    self.view.newOnlineState.transform.parent.parent.parent.gameObject:SetActiveIfNecessary(true)
    self.view.onlineState = self.view.newOnlineState
    self.view.onlineTimeTxt = self.view.newOnlineTimeTxt
end

ClueGiftFriendListCell.InitClueGiftFriendListCell = HL.Method() << function(self)
    self:_FirstTimeInit()
end

HL.Commit(ClueGiftFriendListCell)
return ClueGiftFriendListCell

