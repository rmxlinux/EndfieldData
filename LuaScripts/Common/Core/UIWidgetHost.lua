

local EmptyTable = {}

local function GetMember(object, memberName)
    if type(object) == "table" then
        return object[memberName]
    end
    return HL.TryGet(object, memberName)
end

UIWidgetHost = HL.Class("UIWidgetHost")

UIWidgetHost.m_ctrl = HL.Field(HL.Userdata) 

UIWidgetHost.m_container = HL.Field(HL.Userdata) 

UIWidgetHost.m_args = HL.Field(HL.Table) 

UIWidgetHost.m_currentWidget = HL.Field(HL.Any)

UIWidgetHost.m_currentPath = HL.Field(HL.String) << ""

UIWidgetHost.m_loadingVersion = HL.Field(HL.Number) << 0


UIWidgetHost.UIWidgetHost = HL.Constructor(HL.Userdata, HL.Userdata, HL.Table) << function(self, ctrl, container, args)
    self.m_ctrl = ctrl
    self.m_container = container

    self.m_args = args or EmptyTable
end

UIWidgetHost.SetCtrl = HL.Method(HL.Userdata) << function(self, ctrl)
    self.m_ctrl = ctrl
end


UIWidgetHost.GetCurrentPath = HL.Method().Return(HL.String) << function(self)
    return self.m_currentPath
end


UIWidgetHost.GetCurrentWidget = HL.Method().Return(HL.Opt(HL.Any)) << function(self)
    return self.m_currentWidget
end

UIWidgetHost.ExtractHotSwitchRuntimeState = HL.Method().Return(HL.Opt(HL.Table)) << function(self)
    local state

    local widget = self.m_currentWidget
    if widget and NotNull(widget.gameObject) then
        state = {
            path = self.m_currentPath,
            widgetObject = widget.gameObject,
        }
        local extract = GetMember(widget, "ExtractHotSwitchRuntimeState")
        if extract then
            state.widgetState = extract(widget)
        end
    end

    self.m_ctrl = nil
    self.m_currentWidget = nil
    self.m_currentPath = ""
    self.m_loadingVersion = self.m_loadingVersion + 1

    return state
end

UIWidgetHost.RestoreHotSwitchRuntimeState = HL.Method(HL.Opt(HL.Table)) << function(self, state)
    if not state then
        return
    end

    self.m_currentPath = state.path

    local widgetObject = state.widgetObject
    local widgetComponent = widgetObject:GetComponent("LuaUIWidget")
    local widget = widgetComponent and widgetComponent.table
        and widgetComponent.table[1]
        or Utils.wrapLuaNode(widgetObject)
    self.m_currentWidget = widget

    local restore = GetMember(widget, "RestoreHotSwitchRuntimeState")
    if restore then
        restore(widget, state.widgetState)
    end
end


UIWidgetHost.Load = HL.Method(HL.String).Return(HL.Any) << function(self, widgetPath)
    if widgetPath == self.m_currentPath and self.m_currentWidget then
        return self.m_currentWidget
    end

    self:Unload()

    local prefab = self.m_ctrl:LoadGameObject(widgetPath)
    if not prefab then
        logger.error("[UIWidgetHost] Failed to load prefab: " .. widgetPath)
        return nil
    end

    self.m_currentPath = widgetPath

    local gameObject = CSUtils.CreateObject(prefab, self.m_container)
    local widget = Utils.wrapLuaNode(gameObject)
    self.m_currentWidget = widget

    return widget
end


UIWidgetHost.LoadAsync = HL.Method(HL.String, HL.Function) << function(self, widgetPath, callback)
    if widgetPath == self.m_currentPath and self.m_currentWidget then
        if callback then
            callback(self.m_currentWidget)
        end
        return
    end

    self:Unload()

    self.m_currentPath = widgetPath

    local loadingVersion = self.m_loadingVersion
    self.m_ctrl:LoadGameObjectAsync(widgetPath, function(prefab)
        if loadingVersion ~= self.m_loadingVersion then
            return
        end
        if not prefab then
            logger.error("[UIWidgetHost] Failed to async load prefab: " .. widgetPath)
            self.m_currentPath = ""
            return
        end

        local gameObject = CSUtils.CreateObject(prefab, self.m_container)
        local widget = Utils.wrapLuaNode(gameObject)
        self.m_currentWidget = widget

        if callback then
            callback(widget)
        end
    end)
end


UIWidgetHost.Unload = HL.Method() << function(self)
    self.m_loadingVersion = self.m_loadingVersion + 1

    if self.m_currentWidget then
        if NotNull(self.m_currentWidget.gameObject) then
            GameObject.Destroy(self.m_currentWidget.gameObject)
        end
        self.m_currentWidget = nil
    end

    self.m_currentPath = ""
end

HL.Commit(UIWidgetHost)
return UIWidgetHost
