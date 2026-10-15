local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnTopicBar = HL.Class('InnTopicBar', UIWidgetBase)


InnTopicBar._OnFirstTimeInit = HL.Override() << function(self)
end

InnTopicBar.InitInnTopicBar = HL.Method(HL.String) << function(self, topicId)
    self:_FirstTimeInit()

    local hasTopic, topicData = Tables.innTopicTable:TryGetValue(topicId)
    if not hasTopic or not topicData then
        topicData = InnConst.INN_TOPIC_EMPTY_CONFIG
    end

    self.view.bgTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, topicData.bgId)
    self.view.iconTopicImg:LoadSprite(UIConst.UI_SPRITE_INN_TOPIC, topicData.iconId)
    self.view.colorGroup.color = UIUtils.getColorByString(topicData.color)
end

HL.Commit(InnTopicBar)
return InnTopicBar

