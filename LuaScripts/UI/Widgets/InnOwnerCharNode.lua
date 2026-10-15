local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnOwnerCharNode = HL.Class('InnOwnerCharNode', UIWidgetBase)


InnOwnerCharNode._OnFirstTimeInit = HL.Override() << function(self)
    
end

InnOwnerCharNode.InitInnOwnerCharNode = HL.Method() << function(self)
    self:_FirstTimeInit()
    local jsspsiCharId = Tables.innManagementConst.jsspsiCharId
    self.view.headImg:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD, UIConst.UI_CHAR_HEAD_PREFIX .. jsspsiCharId)
    local jsspsiCharInfo = CharInfoUtils.getPlayerCharInfoByTemplateId(jsspsiCharId, GEnums.CharType.Default)
    if jsspsiCharInfo then
        self.view.friendshipNode.view.gameObject:SetActive(true)
        self.view.friendshipNode:InitFriendshipNode(jsspsiCharInfo.instId)
    else
        self.view.friendshipNode.view.gameObject:SetActive(false)
    end
    self.view.friendshipNode.view.button.enabled = false
end

HL.Commit(InnOwnerCharNode)
return InnOwnerCharNode

