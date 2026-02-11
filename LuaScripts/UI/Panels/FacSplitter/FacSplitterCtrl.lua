local routerCtrl = require_ex('UI/Panels/FacRouter/FacRouterCtrl')
local PANEL_ID = PanelId.FacSplitter



FacSplitterCtrl = HL.Class('FacSplitterCtrl', routerCtrl.FacRouterCtrl)







FacSplitterCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



FacSplitterCtrl._InitRouterPortData = HL.Override() << function(self)
    self.m_isSinglePortIn = true

    self.m_inBindingAnimMap = {
        {
            decoAnimWrapper = self.view.arrowDecoAnimationIn1,
            decoAnimName = "facconnector_arrow",
            conveyorAnimWrapper = self.view.conveyorAnimationIn1,
            conveyorAnimName = "facconvergerarrow_loop",
        }
    }
    self.m_outBindingAnimMap = {
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut1,
            decoAnimName = "facconnector_arrow",
            conveyorAnimWrapper = self.view.conveyorAnimationOut1,
            conveyorAnimName = "facconvergerarrow_rightloop",
        },
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut2,
            decoAnimName = "facconnector_arrow",
            conveyorAnimWrapper = self.view.conveyorAnimationOut2,
            conveyorAnimName = "facconvergerarrow_rightloop",
        },
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut3,
            decoAnimName = "facconnector_arrow",
            conveyorAnimWrapper = self.view.conveyorAnimationOut3,
            conveyorAnimName = "facconvergerarrow_rightloop",
        }
    }

    self.m_inItemAnimMap = {
        {
            animationNode = self.view.itemAnimationIn1,
            animationName = "connector_item_changed",
        }
    }
    self.m_outItemAnimMap = {
        {
            animationNode = self.view.itemAnimationOut1,
            animationName = "splitter_itemleft_changed",
        },
        {
            animationNode = self.view.itemAnimationOut2,
            animationName = "connector_itemright_changed",
        },
        {
            animationNode = self.view.itemAnimationOut3,
            animationName = "connector_itemrightdown_changed",
        }
    }

    self.m_initialNaviTarget = self.view.itemLogistics2
end

HL.Commit(FacSplitterCtrl)
