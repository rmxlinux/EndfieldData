
local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SnapshotControllerEditSticker

SnapshotControllerEditStickerCtrl = HL.Class('SnapshotControllerEditStickerCtrl', uiCtrl.UICtrl)






SnapshotControllerEditStickerCtrl.s_messages = HL.StaticField(HL.Table) << {
    
}



SnapshotControllerEditStickerCtrl.m_OnExitEdit = HL.Field(HL.Function)





SnapshotControllerEditStickerCtrl.m_snapshotCtrl = HL.Field(HL.Any)





SnapshotControllerEditStickerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_snapshotCtrl = arg.ctrl
    self.m_OnExitEdit = arg.onExitEdit
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({self.view.inputGroup.groupId})
    
    self:BindInputPlayerAction("snapshot_controller_move_sticker_only_show", function()
        
    end)
    self:BindInputPlayerAction("snapshot_controller_exit_sticker_edit", function()
        if self.m_OnExitEdit then
            self.m_OnExitEdit()
        end
    end)
    self:BindInputPlayerAction("snapshot_controller_confirm_sticker_edit", function()
        if self.m_OnExitEdit then
            self.m_OnExitEdit()
        end
    end)
    
    self:BindInputPlayerAction("snapshot_controller_sticker_rotate_cw", function()
        self.m_snapshotCtrl:_OnStickerHoldRotateCwStart()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_rotate_cw_end", function()
        self.m_snapshotCtrl:_OnStickerHoldRotateCwEnd()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_rotate_ccw", function()
        self.m_snapshotCtrl:_OnStickerHoldRotateCcwStart()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_rotate_ccw_end", function()
        self.m_snapshotCtrl:_OnStickerHoldRotateCcwEnd()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_scale_down", function()
        self.m_snapshotCtrl:_OnStickerHoldScaleDownStart()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_scale_down_end", function()
        self.m_snapshotCtrl:_OnStickerHoldScaleDownEnd()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_scale_up", function()
        self.m_snapshotCtrl:_OnStickerHoldScaleUpStart()
    end)
    self:BindInputPlayerAction("snapshot_controller_sticker_scale_up_end", function()
        self.m_snapshotCtrl:_OnStickerHoldScaleUpEnd()
    end)
    
    self:BindInputPlayerAction("snapshot_controller_switch_to_next_sticker", function()
        AudioAdapter.PostEvent("Au_UI_Button_Common")
        self.m_snapshotCtrl:_OnSwitchToNextSticker()
    end)
    
    
    self:BindInputPlayerAction("snapshot_controller_copy_current_sticker", function()
        AudioAdapter.PostEvent("Au_UI_Button_Common")
        self.m_snapshotCtrl:_OnClickCopyEditingSticker()
    end)
    self:BindInputPlayerAction("snapshot_controller_delete_current_sticker", function()
        AudioAdapter.PostEvent("Au_UI_Button_Delete")
        self.m_snapshotCtrl:_OnClickDeleteEditingSticker()
    end)
end


HL.Commit(SnapshotControllerEditStickerCtrl)
