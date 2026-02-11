local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
local PUZZLE_NOTICE_TIPS_SHOW = "puzzle_notice_tips_show"

local HINT_TEXT_POOL = {
    "ui_msc_puzzle_hint_1",
    "ui_msc_puzzle_hint_2",
    "ui_msc_puzzle_hint_3",
}










PuzzleNoticeTips = HL.Class('PuzzleNoticeTips', UIWidgetBase)


PuzzleNoticeTips.m_onNoticeBtnClick = HL.Field(HL.Function)


PuzzleNoticeTips.m_noticeClicked = HL.Field(HL.Boolean) << false




PuzzleNoticeTips._OnFirstTimeInit = HL.Override() << function(self)
    self.view.noticeBtn.onClick:AddListener(function()
        self:_OnNoticeBtnClick()
    end)
end



PuzzleNoticeTips._OnNoticeBtnClick = HL.Method() << function(self)
    self.m_noticeClicked = true

    if self.m_onNoticeBtnClick then
        self.m_onNoticeBtnClick()
    end

    self:ShowTips()
end




PuzzleNoticeTips.InitPuzzleNoticeTips = HL.Method(HL.Function) << function(self, onClick)
    self:_FirstTimeInit()
    self.m_onNoticeBtnClick = onClick

    
    local curEndminCharTemplateId = CS.Beyond.Gameplay.CharUtils.curEndminCharTemplateId
    self.view.charIcon:LoadSprite(UIConst.UI_SPRITE_CHAR_HEAD_RECTANGLE,
                                  UIConst.UI_CHAR_HEAD_SQUARE_PREFIX .. curEndminCharTemplateId)

    self:Reset()
end



PuzzleNoticeTips.ShowTips = HL.Method() << function(self)
    local hintKey = lume.randomchoice(HINT_TEXT_POOL)
    self.view.tipsTxt.text = Language[hintKey]
    self.view.animationWrapper:Play(PUZZLE_NOTICE_TIPS_SHOW)
    self:ToggleNoticeBtnInteractable(false)
end



PuzzleNoticeTips.Reset = HL.Method() << function(self)
    self.m_noticeClicked = false
    self.view.animationWrapper:SampleClip(PUZZLE_NOTICE_TIPS_SHOW, 0)
    self:ToggleNoticeBtnInteractable(true)
end




PuzzleNoticeTips.ToggleNoticeBtnInteractable = HL.Method(HL.Boolean) << function(self, isOn)
    self.view.noticeBtn.gameObject:SetActive(isOn and not self.m_noticeClicked)
end

HL.Commit(PuzzleNoticeTips)
return PuzzleNoticeTips

