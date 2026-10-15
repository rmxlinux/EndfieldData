local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnItemTag = HL.Class('InnItemTag', UIWidgetBase)

InnItemTag.m_upCache = HL.Field(HL.Forward("UIListCache"))


InnItemTag._OnFirstTimeInit = HL.Override() << function(self)
    
end






InnItemTag.InitInnItemTag = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    local isRare = args.tagId == Tables.innManagementConst.rareTag
    local isCategory, categoryData = Tables.innDishCategoryTable:TryGetValue(args.tagId)
    local isAffix, affixData = Tables.innAffixTable:TryGetValue(args.tagId)
    local stateName
    if isRare then
        stateName = "Rare"
        self.view.rareTxt.text = affixData.name
    elseif isCategory then
        stateName = "Category"
        self.view.typeTxt.text = categoryData.name
        self.view.typeImg:LoadSprite(UIConst.UI_SPRITE_INN_ITEM_TAG, categoryData.iconId)
        self.view.categoryBg.color = UIUtils.getColorByString(categoryData.bgColor)
        self.view.lineImg.color = UIUtils.getColorByString(categoryData.lineColor)
    elseif isAffix then
        stateName = "Affix"
        self.view.affixTxt.text = affixData.name
    else
        logger.error("InnItemTag.InitInnItemTag 未知的tagId:" .. args.tagId)
        return
    end
    self.view.stateController:SetState(stateName)
    self.view.hotImage.gameObject:SetActive(args.isHot == true)
    self.view.arrowImage.gameObject:SetActive(false)
    if args.upCount and args.upCount > 0 then
        self.m_upCache = self.m_upCache or UIUtils.genCellCache(self.view.arrowImage)
        self.m_upCache:Refresh(args.upCount)
    else
        if self.m_upCache then
            self.m_upCache:Refresh(0)
        end
    end
end

HL.Commit(InnItemTag)
return InnItemTag

