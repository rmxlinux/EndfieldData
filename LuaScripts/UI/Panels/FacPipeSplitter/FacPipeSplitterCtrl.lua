local pipeRouterCtrl = require_ex('UI/Panels/FacPipeRouter/FacPipeRouterCtrl')
local PANEL_ID = PanelId.FacPipeSplitter



FacPipeSplitterCtrl = HL.Class('FacPipeSplitterCtrl', pipeRouterCtrl.FacPipeRouterCtrl)








FacPipeSplitterCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



FacPipeSplitterCtrl._InitRouterPortData = HL.Override() << function(self)
    self.m_isSinglePortIn = true

    self.m_inBindingAnimMap = {
        {
            decoAnimWrapper = self.view.arrowDecoAnimationIn1,
            decoAnimName = "facconnector_arrow",
            conveyorAnimWrapper = self.view.conveyorAnimationIn1,
            conveyorAnimName = "facpipeconnector_arrow",
        }
    }
    self.m_outBindingAnimMap = {
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut1,
            decoAnimName = "facconnector_arrow02",
            conveyorAnimWrapper = self.view.conveyorAnimationOut1,
            conveyorAnimName = "facpipeconnector_arrow03",
        },
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut2,
            decoAnimName = "facconnector_arrow01",
            conveyorAnimWrapper = self.view.conveyorAnimationOut2,
            conveyorAnimName = "facpipeconnector_arrow02",
        },
        {
            decoAnimWrapper = self.view.arrowDecoAnimationOut3,
            decoAnimName = "facconnector_arrow03",
            conveyorAnimWrapper = self.view.conveyorAnimationOut3,
            conveyorAnimName = "facpipeconnector_arrow02",
        }
    }

    self.m_inItemAnimMap = {
        {
            animationNode = self.view.itemAnimationIn1,
            animationName = "connector_facpipe_changed_3",
        }
    }
    self.m_outItemAnimMap = {
        {
            animationNode = self.view.itemAnimationOut1,
            animationName = "connector_facpipe_changed_5",
        },
        {
            animationNode = self.view.itemAnimationOut2,
            animationName = "connector_facpipe_changed_2",
        },
        {
            animationNode = self.view.itemAnimationOut3,
            animationName = "connector_facpipe_changed_1",
        }
    }

    self.m_initialNaviTarget = self.view.itemLogistics2
end

HL.Commit(FacPipeSplitterCtrl)
