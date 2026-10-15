local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnMoneyHUD = HL.Class('InnMoneyHUD', UIWidgetBase)

InnMoneyHUD.m_deskId = HL.Field(HL.Number) << 0

InnMoneyHUD.m_hideTimerId = HL.Field(HL.Number) << -1





InnMoneyHUD._OnFirstTimeInit = HL.Override() << function(self)
    self:RegisterMessage(MessageConst.ON_INN_DESK_CHECK_OUT, function(args)
        local deskId, baseMoney, tipMoney = unpack(args)
        if deskId == self.m_deskId then
            self:_Show(baseMoney or 0, tipMoney or 0)
        end
    end)
end

InnMoneyHUD._OnDestroy = HL.Override() << function(self)
    self.m_hideTimerId = self:_ClearTimer(self.m_hideTimerId)
    if self.view.animationWrapper then
        self.view.animationWrapper:ClearTween(false)
    end
end

InnMoneyHUD.InitInnMoneyHUD = HL.Method(HL.Opt(HL.Table)) << function(self, args)
    self:_FirstTimeInit()

    args = args or {}
    self.m_deskId = args.deskId or 0

    self:_SetActiveState(false)
end

InnMoneyHUD._Show = HL.Method(HL.Number, HL.Number) << function(self, baseMoney, tipMoney)
    if self.view.baseNode then
        self.view.baseNode.gameObject:SetActiveIfNecessary(baseMoney > 0)
    end
    if self.view.baseNumTxt then
        self.view.baseNumTxt.text = string.format("+%d", baseMoney)
    end

    if self.view.tipNode then
        self.view.tipNode.gameObject:SetActiveIfNecessary(tipMoney > 0)
    end
    if self.view.tipNumTxt then
        self.view.tipNumTxt.text = string.format("+%d", tipMoney)
    end

    self:_SetActiveState(true)
    if self.view.animationWrapper then
        self.view.animationWrapper:ClearTween(false)
        self.view.animationWrapper:PlayInAnimation()
    end

    self.m_hideTimerId = self:_ClearTimer(self.m_hideTimerId)
    self.m_hideTimerId = self:_StartTimer(self.view.config.STAY_TIME, function()
        self.m_hideTimerId = -1
        self:_Hide()
    end)
end

InnMoneyHUD._Hide = HL.Method() << function(self)
    local animationWrapper = self.view.animationWrapper
    if animationWrapper == nil then
        self:_SetActiveState(false)
        return
    end
    animationWrapper:PlayOutAnimation(function()
        self:_SetActiveState(false)
    end)
end



InnMoneyHUD._SetActiveState = HL.Method(HL.Boolean) << function(self, isActive)
    if self.view.worldUIFollowAndFaceCamera then
        self.view.worldUIFollowAndFaceCamera.enabled = isActive
    end
    if self.view.canvas then
        self.view.canvas.enabled = isActive
    end
end

HL.Commit(InnMoneyHUD)
return InnMoneyHUD
