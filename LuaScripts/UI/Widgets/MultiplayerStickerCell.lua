local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

MultiplayerStickerCell = HL.Class('MultiplayerStickerCell', UIWidgetBase)




MultiplayerStickerCell._OnFirstTimeInit = HL.Override() << function(self)
    
end

MultiplayerStickerCell.InitMultiplayerStickerCell = HL.Method() << function(self)
    self:_FirstTimeInit()

    
end

HL.Commit(MultiplayerStickerCell)
return MultiplayerStickerCell
