local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnCharHeadCell = HL.Class('InnCharHeadCell', UIWidgetBase)

InnCharHeadCell.m_args = HL.Field(HL.Table)

InnCharHeadCell.m_skillCategoryTagCache = HL.Field(HL.Forward('UIListCache'))

InnCharHeadCell.m_skillAffixTagCache = HL.Field(HL.Forward('UIListCache'))


InnCharHeadCell._OnFirstTimeInit = HL.Override() << function(self)
    self.m_skillCategoryTagCache = UIUtils.genCellCache(self.view.innItemTagSmall)
    self.m_skillAffixTagCache = UIUtils.genCellCache(self.view.innItemTagBig)

    self.view.button.onClick:AddListener(function()
        if self.m_args and self.m_args.onClick then
            self.m_args.onClick()
        end
    end)

    self.view.infoButton.onClick:AddListener(function()
        if self.m_args and self.m_args.onTipsClick then
            self.m_args.onTipsClick()
        end
    end)
end









InnCharHeadCell.InitInnCharHeadCell = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    self.m_args = args
    local charId = args.charId
    local charData = Tables.characterTable[charId]
    self.view.gameObject.name = charId

    
    local spriteName = UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. charId
    self.view.charIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE, spriteName)

    
    if charData then
        self.view.charTypeIcon:InitCharTypeIcon(charData.charTypeId)
    end

    
    local stateName
    if args.isCurrentKitchen == true then
        stateName = "Current"
        self.view.roomName.text = Language.LUA_INN_KITCHEN_CHAR_HEAD_STATE_CURRENT
    elseif args.kitchenId == nil then
        stateName = "None"
        self.view.roomName.text = Language.LUA_INN_KITCHEN_CHAR_HEAD_STATE_NONE
    else
        stateName = "Other"
        self.view.roomName.text = Language['LUA_INN_KITCHEN_NAME_' .. args.kitchenId] or ""
    end
    self.view.kitchenNode:SetState(stateName)

    
    local topicId = ""
    local inn = GameInstance.player and GameInstance.player.innSystem
    if inn and inn.gameSetting and inn.gameSetting.topicId then
        topicId = inn.gameSetting.topicId
    end
    local skills = InnUtils.getCharInnSkills(charId)
    local categoryTagArgs = {}
    local affixTagArgs = {}
    for _, skill in ipairs(skills) do
        local type, tagId = InnUtils.classifyInnSkillTag(skill)
        if tagId then
            if type == "category" then
                categoryTagArgs[#categoryTagArgs + 1] = {
                    tagId = tagId,
                    isHot = false,
                    upCount = 0,
                }
            elseif type == "affix" then
                affixTagArgs[#affixTagArgs + 1] = {
                    tagId = tagId,
                    isHot = false,
                    upCount = 0,
                }
            end
        end
    end
    self.m_skillCategoryTagCache:Refresh(#categoryTagArgs, function(cell, index)
        cell:InitInnItemTag(categoryTagArgs[index])
    end)
    self.m_skillAffixTagCache:Refresh(#affixTagArgs, function(cell, index)
        cell:InitInnItemTag(affixTagArgs[index])
    end)
    self.view.affixBgBlank.gameObject:SetActive(#affixTagArgs == 0)

    
    if args.selectedIndex ~= nil then
        self.view.chooseNode.gameObject:SetActive(true)
        self.view.chooseIndexTxt.text = tostring(args.selectedIndex)
    else
        self.view.chooseNode.gameObject:SetActive(false)
    end
end

HL.Commit(InnCharHeadCell)
return InnCharHeadCell
