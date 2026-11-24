UISceneManager = HL.Class("UISceneManager")

local SCENE_POSITIONS = {
    Vector3(-300, 300, -300),
    Vector3(-300, 300, -600),
    Vector3(-300, 300, -900),
    Vector3(-600, 300, -300),
    Vector3(-600, 300, -600),
    Vector3(-600, 300, -900),
    Vector3(-900, 300, -300),
    Vector3(-900, 300, -600),
}



UISceneManager.m_stack = HL.Field(HL.Table)
UISceneManager.m_registry = HL.Field(HL.Table)
UISceneManager.m_positionOccupied = HL.Field(HL.Table)






UISceneManager.UISceneManager = HL.Constructor() << function(self)
    self.m_stack = {}
    self.m_registry = {}
    self.m_positionOccupied = {}
end










UISceneManager.Register = HL.Method(HL.String, HL.Userdata, HL.Opt(HL.Table)) << function(self, id, sceneRoot, opts)
    opts = opts or {}

    local posIndex, position = self:_AllocatePosition(opts.position)
    local useUIModelLayer = true
    if opts.useUIModelLayer ~= nil then
        useUIModelLayer = opts.useUIModelLayer
    end

    local entry = {
        id = id,
        sceneRoot = sceneRoot,
        position = position,
        posIndex = posIndex,
        cullingName = opts.cullingName or id,
        isActive = false,
        hasCullingMask = false,
        onActivate = opts.onActivate,
        onDeactivate = opts.onDeactivate,
        useUIModelLayer = useUIModelLayer,
        skipSetActive = opts.skipSetActive == true,
    }
    self.m_registry[id] = entry

    sceneRoot.transform.position = position

    local curTop = self:_GetTopEntry()
    if curTop then
        self:_DoDeactivate(curTop)
    end

    table.insert(self.m_stack, id)

    if not entry.skipSetActive then
        entry.sceneRoot:SetActive(true)
    end
    entry.isActive = true
    self:_RefreshCullingMask()
end


UISceneManager.Unregister = HL.Method(HL.String) << function(self, id)
    local entry = self.m_registry[id]
    if not entry then
        return
    end

    self:_ReleasePosition(entry.posIndex)

    local wasTop = (self:_GetTopId() == id)
    self:_RemoveFromStack(id)
    self.m_registry[id] = nil
    self:_SetCullingMask(entry, false)
    self:_RefreshCullingMask()

    if wasTop then
        local newTop = self:_GetTopEntry()
        if newTop then
            self:_DoActivate(newTop)
        end
    end
end



UISceneManager.Activate = HL.Method(HL.String) << function(self, id)
    local entry = self.m_registry[id]
    if not entry then
        return
    end
    self:_DoActivate(entry)
end


UISceneManager.Deactivate = HL.Method(HL.String) << function(self, id)
    local entry = self.m_registry[id]
    if not entry then
        return
    end
    self:_DoDeactivate(entry)
end

UISceneManager.IsActive = HL.Method(HL.String).Return(HL.Boolean) << function(self, id)
    local entry = self.m_registry[id]
    if not entry then
        return false
    end
    return entry.isActive
end

UISceneManager.GetTopSceneId = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    return self:_GetTopId()
end

UISceneManager.Dispose = HL.Method() << function(self)
    self.m_stack = {}
    self.m_registry = {}
    self.m_positionOccupied = {}
end






UISceneManager._DoActivate = HL.Method(HL.Table) << function(self, entry)
    if not entry.isActive then
        if not entry.skipSetActive then
            entry.sceneRoot:SetActive(true)
        end
        entry.isActive = true
    end

    self:_RefreshCullingMask()

    if entry.onActivate then
        entry.onActivate()
    end
end

UISceneManager._DoDeactivate = HL.Method(HL.Table) << function(self, entry)
    if not entry.isActive then
        return
    end

    if entry.onDeactivate then
        entry.onDeactivate()
    end

    entry.isActive = false
    self:_RefreshCullingMask()
    if not entry.skipSetActive then
        entry.sceneRoot:SetActive(false)
    end
end

UISceneManager._GetCullingOwner = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    for i = #self.m_stack, 1, -1 do
        local entry = self.m_registry[self.m_stack[i]]
        if entry and entry.isActive then
            return entry.useUIModelLayer and entry or nil
        end
    end
    return nil
end

UISceneManager._RefreshCullingMask = HL.Method() << function(self)
    local owner = self:_GetCullingOwner()
    for _, entry in pairs(self.m_registry) do
        if entry ~= owner then
            self:_SetCullingMask(entry, false)
        end
    end
    if owner then
        self:_SetCullingMask(owner, true)
    end
end

UISceneManager._SetCullingMask = HL.Method(HL.Table, HL.Boolean) << function(self, entry, enable)
    if entry.hasCullingMask == enable then
        return
    end
    entry.hasCullingMask = enable
    CameraManager:EnableUIModelCullingMask(enable, entry.cullingName)
end

UISceneManager._AllocatePosition = HL.Method(HL.Opt(HL.Userdata)).Return(HL.Number, HL.Userdata) << function(self, specifiedPos)
    if specifiedPos then
        local idx = #SCENE_POSITIONS + 1
        self.m_positionOccupied[idx] = true
        return idx, specifiedPos
    end

    for i, pos in ipairs(SCENE_POSITIONS) do
        if not self.m_positionOccupied[i] then
            self.m_positionOccupied[i] = true
            return i, pos
        end
    end

    local fallbackIdx = #SCENE_POSITIONS + 1
    while self.m_positionOccupied[fallbackIdx] do
        fallbackIdx = fallbackIdx + 1
    end
    self.m_positionOccupied[fallbackIdx] = true
    local offset = fallbackIdx - #SCENE_POSITIONS
    return fallbackIdx, Vector3(-300, 300, -300 - offset * 300)
end

UISceneManager._ReleasePosition = HL.Method(HL.Number) << function(self, posIndex)
    self.m_positionOccupied[posIndex] = nil
end

UISceneManager._GetTopId = HL.Method().Return(HL.Opt(HL.String)) << function(self)
    local count = #self.m_stack
    if count == 0 then
        return nil
    end
    return self.m_stack[count]
end

UISceneManager._GetTopEntry = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local topId = self:_GetTopId()
    if not topId then
        return nil
    end
    return self.m_registry[topId]
end

UISceneManager._RemoveFromStack = HL.Method(HL.String) << function(self, id)
    for i = #self.m_stack, 1, -1 do
        if self.m_stack[i] == id then
            table.remove(self.m_stack, i)
            return
        end
    end
end



HL.Commit(UISceneManager)
return UISceneManager