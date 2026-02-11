local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.Wiki









WikiCtrl = HL.Class('WikiCtrl', uiCtrl.UICtrl)









WikiCtrl.s_messages = HL.StaticField(HL.Table) << {
}



local WIKI_CATEGORY_TO_Node_NAME = {
    [WikiConst.EWikiCategoryType.Weapon] = "btnWeapon",
    [WikiConst.EWikiCategoryType.Equip] = "btnEquip",
    [WikiConst.EWikiCategoryType.Item] = "btnItem",
    [WikiConst.EWikiCategoryType.Monster] = "btnMonster",
    [WikiConst.EWikiCategoryType.Building] = "btnBuilding",
    [WikiConst.EWikiCategoryType.Tutorial] = "btnTutorial",
}




WikiCtrl.m_selectedNodeAnim = HL.Field(HL.Userdata)






WikiCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local spriteNumberTable = {}
    for i = 1, 6 do
        spriteNumberTable[i] = self.view["imgNumber0" .. i].sprite
    end

    for categoryId, categoryData in pairs(Tables.wikiCategoryTable) do
        local nodeName = WIKI_CATEGORY_TO_Node_NAME[categoryId]
        if nodeName ~= nil then
            local node = self.view[nodeName]
            if node then
                node.btn.transform:SetSiblingIndex(categoryData.categoryPriority - 1)
                node.imgNumber.sprite = spriteNumberTable[categoryData.categoryPriority]
                node.btn.onClick:AddListener(function()
                    if WikiUtils.isWikiCategoryUnlocked(categoryId) then
                        self.m_phase:OpenCategory(categoryId)
                    else
                        Notify(MessageConst.SHOW_TOAST, Language.LUA_WIKI_CATEGORY_LOCKED)
                    end
                end)
                node.btn.onHoverChange:AddListener(function(isHover)
                    if self.m_selectedNodeAnim then
                        UIUtils.PlayAnimationAndToggleActive(self.m_selectedNodeAnim, false)
                    end
                    if isHover then
                        self.m_selectedNodeAnim = node.selectNodeAnim
                        if self.m_selectedNodeAnim then
                            UIUtils.PlayAnimationAndToggleActive(self.m_selectedNodeAnim, true)
                        end
                    end
                end)
                node.redDot:InitRedDot("WikiCategory", categoryId)

                if categoryData.categoryPriority == 1 then
                    self.m_firstCategoryBtn = node.btn
                end
            end
        end
    end

    self:_InitController()

    AudioManager.PostEvent("au_ui_menu_wiki_open")
end



WikiCtrl.OnClose = HL.Override() << function(self)
    AudioManager.PostEvent("au_ui_menu_wiki_close")
end



WikiCtrl.OnShow = HL.Override() << function(self)
    if self.m_phase then
        self.m_phase:ActiveMainSceneItem(true)
        self.m_phase:PlayDecoAnim("wiki_uideco_in")
    end
    
    
    self:_StartCoroutine(function()
        coroutine.step()
        if self:IsShow() then
            AudioAdapter.PostEvent("Au_UI_Menu_WikiPanel_Open")
        end
    end)
end



WikiCtrl._OnPhaseItemBind = HL.Override() << function(self)
    self.view.topNode:InitWikiTop({
        phase = self.m_phase,
        panelId = PANEL_ID,
        forceShowCloseBtn = true,
    })
    self.m_phase:ActiveMainSceneItem(true)
    self.m_phase:PlayDecoAnim("wiki_uideco_in")
end






WikiCtrl.m_firstCategoryBtn = HL.Field(HL.Userdata)



WikiCtrl._InitController = HL.Method() << function(self)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    if self.m_firstCategoryBtn then
        InputManagerInst.controllerNaviManager:SetTarget(self.m_firstCategoryBtn)
    end
end



HL.Commit(WikiCtrl)
