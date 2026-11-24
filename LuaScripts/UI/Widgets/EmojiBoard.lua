local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

EmojiBoard = HL.Class('EmojiBoard', UIWidgetBase)


EmojiBoard._OnFirstTimeInit = HL.Override() << function(self)
    
end

EmojiBoard.InitEmojiBoard = HL.Method() << function(self)
    self:_FirstTimeInit()

    
end

HL.Commit(EmojiBoard)
return EmojiBoard

