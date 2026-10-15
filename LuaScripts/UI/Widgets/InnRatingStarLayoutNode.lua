local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

InnRatingStarLayoutNode = HL.Class('InnRatingStarLayoutNode', UIWidgetBase)

InnRatingStarLayoutNode.m_ratingStarCellCache = HL.Field(HL.Forward("UIListCache"))


InnRatingStarLayoutNode._OnFirstTimeInit = HL.Override() << function(self)
    self.m_ratingStarCellCache = self.m_ratingStarCellCache or UIUtils.genCellCache(self.view.ratingStarCell)
end

InnRatingStarLayoutNode.InitInnRatingStarLayoutNode = HL.Method(HL.Number, HL.Number)
    << function(self, totalNum, currentNum)
    self:_FirstTimeInit()

    self.m_ratingStarCellCache:Refresh(totalNum, function(cell, index)
        cell.stateController:SetState(index <= currentNum and "Full" or "Empty")
    end)
end

HL.Commit(InnRatingStarLayoutNode)
return InnRatingStarLayoutNode

