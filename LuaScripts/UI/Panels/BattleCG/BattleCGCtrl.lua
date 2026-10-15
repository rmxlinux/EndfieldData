



























local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.BattleCG

local PlayerStatus = CS.CriWare.CriMana.Player.Status

BattleCGCtrl = HL.Class('BattleCGCtrl', uiCtrl.UICtrl)

BattleCGCtrl.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.ON_BATTLE_SQUAD_CHANGED] = 'OnBattleSquadChanged',
    [MessageConst.PLAY_BATTLE_CG]          = 'OnPlayBattleCG',
    [MessageConst.STOP_BATTLE_CG]          = 'OnStopBattleCG',
    [MessageConst.ON_APPLICATION_PAUSE]    = 'OnApplicationPause',
    [MessageConst.ON_RESET_LEVEL]          = 'OnResetLevel',
}

do
    BattleCGCtrl.m_slots = HL.Field(HL.Table)
    BattleCGCtrl.m_playing = HL.Field(HL.Any)
    BattleCGCtrl.m_keepActiveCo = HL.Field(HL.Thread)
end

BattleCGCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_slots = {}
    self.view.gameObject:SetActive(true)
    self.m_keepActiveCo = self:_StartCoroutine(function()
        while true do
            if not self.view.gameObject.activeSelf then
                self.view.gameObject:SetActive(true)
            end
            coroutine.step()
        end
    end)
    if self.view.image and self.view.image.gameObject then
        self.view.image.gameObject:SetActive(false)
    end
    self:_SyncCurrentSquad()
end

BattleCGCtrl.OnClose = HL.Override() << function(self)
    if self.m_keepActiveCo then
        self:_ClearCoroutine(self.m_keepActiveCo)
        self.m_keepActiveCo = nil
    end
    self:_DisposeAllSlots()
end

BattleCGCtrl.OnBattleSquadChanged = HL.Method() << function(self)
    self:_SyncCurrentSquad()
end

BattleCGCtrl._SyncCurrentSquad = HL.Method() << function(self)
    local squad = GameInstance.player and GameInstance.player.squadManager and GameInstance.player.squadManager.curSquad
    if squad == nil then
        return
    end

    local curIds = {}
    local slots = squad.slots
    for i = 1, slots.Count do
        local slot = slots[CSIndex(i)]
        local entity = slot and slot.character
        if entity ~= nil and entity.templateData ~= nil then
            local id = entity.templateData.id
            if id and id ~= "" then
                curIds[id] = entity
            end
        end
    end

    for charId, _ in pairs(self.m_slots) do
        if curIds[charId] == nil then
            self:_RemoveCharacter(charId)
        end
    end

    for charId, entity in pairs(curIds) do
        if self.m_slots[charId] == nil then
            self:_AddCharacter(charId, entity)
        end
    end
end

BattleCGCtrl._AddCharacter = HL.Method(HL.String, HL.Userdata) << function(self, charId, entity)
    local cgIdMap = entity.abilityCom and entity.abilityCom.data and entity.abilityCom.data.preloadBattleCgIds
    if cgIdMap == nil or cgIdMap.Count == 0 then
        return
    end

    local entry = {}
    self.m_slots[charId] = entry

    local enumerator = cgIdMap:GetEnumerator()
    while enumerator:MoveNext() do
        local kv = enumerator.Current
        local cgId = kv.Key
        if cgId and cgId ~= "" then
            self:_PreloadOne(charId, cgId, entry)
        end
    end
    enumerator:Dispose()
end

BattleCGCtrl._PreloadOne = HL.Method(HL.String, HL.String, HL.Table) << function(self, charId, cgId, entry)
    local path = self:_ResolvePath(cgId)
    if path == nil or path == "" then
        logger.error(string.format("[BattleCG] _PreloadOne: video not found, charId=%s, cgId=%s", charId, cgId))
        return
    end

    local slot = self:_InstantiateSlot()
    if slot == nil then
        return
    end
    slot.path = path
    slot.status = "preparing"
    self:_StartPrepare(slot)

    entry[cgId] = slot
end

BattleCGCtrl._RemoveCharacter = HL.Method(HL.String) << function(self, charId)
    local entry = self.m_slots[charId]
    if entry == nil then
        return
    end
    for cgId, slot in pairs(entry) do
        self:_DisposeSlot(slot)
    end
    self.m_slots[charId] = nil
end

BattleCGCtrl._DisposeAllSlots = HL.Method() << function(self)
    if self.m_slots ~= nil then
        for charId, _ in pairs(self.m_slots) do
            self:_RemoveCharacter(charId)
        end
    end
    self.m_slots = {}
    self.m_playing = nil
end

BattleCGCtrl.OnPlayBattleCG = HL.Method(HL.Table) << function(self, args)
    local charId, cgId, fullPath = unpack(args)
    if not charId or not cgId then
        logger.error("[BattleCG] OnPlayBattleCG: invalid args")
        return
    end

    local slot = self.m_slots[charId] and self.m_slots[charId][cgId]
    if slot == nil then
        self:_TryAddCharacterById(charId)
        slot = self.m_slots[charId] and self.m_slots[charId][cgId]
    end
    if slot == nil then
        logger.error(string.format(
            "[BattleCG] OnPlayBattleCG: slot not preloaded, charId=%s, cgId=%s, fallback",
            charId, cgId))
        if fullPath == nil or fullPath == "" then
            return
        end
        slot = self:_InstantiateSlot()
        if slot == nil then
            return
        end
        slot.path = fullPath
        slot.status = "stopped"
        local entry = self.m_slots[charId]
        if entry == nil then
            entry = {}
            self.m_slots[charId] = entry
        end
        entry[cgId] = slot
    end

    if self.m_playing ~= nil and self.m_playing ~= slot then
        self:_ForceStopCurrent()
    end

    self.m_playing = slot
    self:_SetSlotVisible(slot, true)
    self:_PlaySlot(slot)
end

BattleCGCtrl.OnStopBattleCG = HL.Method(HL.Table) << function(self, args)
    if self.m_playing == nil then
        return
    end
    self:_ForceStopCurrent()
end

BattleCGCtrl._ForceStopCurrent = HL.Method() << function(self)
    local slot = self.m_playing
    self.m_playing = nil
    if slot == nil then
        return
    end
    self:_SetSlotVisible(slot, false)
    slot.status = "preparing"
    self:_StartPrepare(slot)
end

BattleCGCtrl._StartPrepare = HL.Method(HL.Table) << function(self, slot)
    if slot.movieController == nil or slot.path == nil or slot.path == "" then
        return
    end
    local mc = slot.movieController
    if mc.player == nil then
        mc:PlayerManualInitialize()
    end
    mc.player.statusChangeCallback = function(status) self:_OnSlotStatusChange(slot, status) end

    local Status = PlayerStatus
    local cur = mc.player.status
    if cur == Status.Stop or cur == Status.StopProcessing then
        if slot._prepareCo then
            self:_ClearCoroutine(slot._prepareCo)
            slot._prepareCo = nil
        end
        slot._prepareCo = self:_StartCoroutine(function()
            local guard = 0
            while mc.player.status == Status.StopProcessing and guard < 120 do
                coroutine.step()
                guard = guard + 1
            end
            slot._prepareCo = nil
            mc.player:SetFile(nil, slot.path)
            mc.player:Prepare()
        end)
    else
        mc.player:Stop()
        if slot._prepareCo then
            self:_ClearCoroutine(slot._prepareCo)
            slot._prepareCo = nil
        end
        slot._prepareCo = self:_StartCoroutine(function()
            local guard = 0
            while mc.player.status ~= Status.Stop and guard < 240 do
                coroutine.step()
                guard = guard + 1
            end
            slot._prepareCo = nil
            mc.player:SetFile(nil, slot.path)
            mc.player:Prepare()
        end)
    end
end

BattleCGCtrl._PlaySlot = HL.Method(HL.Table) << function(self, slot)
    if slot.movieController == nil then
        return
    end
    local mc = slot.movieController
    if slot.status == "ready" then
        mc:Play()
        slot.status = "playing"
        return
    end
    if slot.status == "preparing" then
        slot._pendingPlay = true
        return
    end
    if mc.player == nil then
        mc:PlayerManualInitialize()
    end
    mc.player.statusChangeCallback = function(status) self:_OnSlotStatusChange(slot, status) end
    mc.player:SetFile(nil, slot.path)
    mc.player:Start()
    slot.status = "playing"
end

BattleCGCtrl._OnSlotStatusChange = HL.Method(HL.Table, HL.Any) << function(self, slot, status)
    if status == PlayerStatus.Ready then
        slot.status = "ready"
        if slot._pendingPlay then
            slot._pendingPlay = nil
            if slot.movieController then
                slot.movieController:Play()
                slot.status = "playing"
            end
        end
    elseif status == PlayerStatus.PlayEnd then
        if self.m_playing ~= slot then
            return
        end
        self.m_playing = nil
        self:_SetSlotVisible(slot, false)
        slot.status = "preparing"
        self:_StartPrepare(slot)
    end
end

BattleCGCtrl.OnApplicationPause = HL.Method(HL.Any) << function(self, arg)
    local isPause = unpack(arg)
    if isPause == nil then
        isPause = false
    end
    if self.m_playing ~= nil and self.m_playing.movieController then
        self.m_playing.movieController:Pause(isPause)
    end
end

BattleCGCtrl.OnResetLevel = HL.Method() << function(self)
    if self.m_playing ~= nil then
        self:_ForceStopCurrent()
    end
end

BattleCGCtrl._InstantiateSlot = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    if self.view.image == nil then
        logger.error("[BattleCG] view.image not bound on prefab")
        return nil
    end
    local templateGo = self.view.image.gameObject
    local parent = templateGo.transform.parent
    local go = CSUtils.CreateObject(templateGo, parent)
    if go == nil then
        return nil
    end
    go:SetActive(true)
    local cg = go:GetComponent(typeof(CS.UnityEngine.CanvasGroup))
    if cg == nil or cg:Equals(nil) then
        cg = go:AddComponent(typeof(CS.UnityEngine.CanvasGroup))
    end
    cg.alpha = 0
    local mc = go:GetComponentInChildren(typeof(CS.CriWare.CriManaMovieControllerForUI), true)
    if mc == nil then
        logger.error("[BattleCG] CriManaMovieControllerForUI not found on cloned slot")
        GameObject.Destroy(go)
        return nil
    end
    return {
        go              = go,
        movieController = mc,
        canvasGroup     = cg,
        path            = "",
        status          = "stopped",
    }
end

BattleCGCtrl._TryAddCharacterById = HL.Method(HL.String) << function(self, charId)
    local squad = GameInstance.player and GameInstance.player.squadManager and GameInstance.player.squadManager.curSquad
    if squad == nil then
        return
    end
    local slots = squad.slots
    for i = 1, slots.Count do
        local slot = slots[CSIndex(i)]
        local entity = slot and slot.character
        if entity ~= nil and entity.templateData ~= nil and entity.templateData.id == charId then
            self:_AddCharacter(charId, entity)
            return
        end
    end
end

BattleCGCtrl._SetSlotVisible = HL.Method(HL.Table, HL.Boolean) << function(self, slot, visible)
    if slot == nil or slot.canvasGroup == nil then
        return
    end
    slot.canvasGroup.alpha = visible and 1 or 0
end

BattleCGCtrl._DisposeSlot = HL.Method(HL.Table) << function(self, slot)
    if slot == nil then
        return
    end
    if self.m_playing == slot then
        self.m_playing = nil
    end
    if slot._prepareCo then
        self:_ClearCoroutine(slot._prepareCo)
        slot._prepareCo = nil
    end
    if slot.movieController then
        slot.movieController:Stop()
        slot.movieController:RenderTargetManualFinalize()
        slot.movieController:PlayerManualFinalize()
    end
    if slot.go ~= nil then
        GameObject.Destroy(slot.go)
        slot.go = nil
    end
end

BattleCGCtrl._ResolvePath = HL.Method(HL.String).Return(HL.String) << function(self, cgId)
    return CS.Beyond.Gameplay.View.BattleCG.ResolvePath(cgId) or ""
end

HL.Commit(BattleCGCtrl)
