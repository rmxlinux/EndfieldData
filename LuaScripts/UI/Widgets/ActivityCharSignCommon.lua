

local ActivityCheckInBase = require_ex('UI/Widgets/ActivityCheckInBase')



ActivityCharSignCommon = HL.Class('ActivityCharSignCommon', ActivityCheckInBase)




ActivityCharSignCommon.Init = HL.Method(HL.Table) << function(self, args)
    self:_InitAnim({
        startAnimTime = 0.3,
    })
    self:_InitScrollList({
        scrollList = self.view.signScrollList,
        rewardCell = self.view.cell,
    })
    self:_InitActivityInfo({
        activityId = args.activityId,
        isPopup = args.isPopup,
    })
    self:_InitReceiveAll({
        receiveAllBtn = self.view.allReceiveBtn,
        receiveRedDot = self.view.receiveRedDot,
    })
    self:_InitPosition()
    self:_InitController({})
end

HL.Commit(ActivityCharSignCommon)
return ActivityCharSignCommon