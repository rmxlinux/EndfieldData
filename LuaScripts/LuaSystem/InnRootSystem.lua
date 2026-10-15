local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
local luaLoader = require_ex('Common/Utils/LuaResourceLoader')



local function _wrapDishModel(go)
    return { gameObject = go }
end












InnRootSystem = HL.Class('InnRootSystem', LuaSystemBase.LuaSystemBase)

InnRootSystem.m_innRoot = HL.Field(GameObject)

InnRootSystem.m_deskHudRoot = HL.Field(GameObject)

InnRootSystem.m_kitchenHudRoot = HL.Field(GameObject)

InnRootSystem.m_dishHudRoot = HL.Field(GameObject)

InnRootSystem.m_dishModelRoot = HL.Field(GameObject)

InnRootSystem.m_heldFoodModelRoot = HL.Field(GameObject)

InnRootSystem.m_purseModelRoot = HL.Field(GameObject)

InnRootSystem.m_guestHudRoot = HL.Field(GameObject)


InnRootSystem.m_resourceLoader = HL.Field(HL.Forward("LuaResourceLoader"))


InnRootSystem.m_dishHudPrefab = HL.Field(HL.Any)

InnRootSystem.m_guestHudPrefab = HL.Field(HL.Any)


InnRootSystem.m_dishHudCache = HL.Field(HL.Forward("UIGoCache"))


InnRootSystem.m_dishModelCaches = HL.Field(HL.Table)

InnRootSystem.m_dishModelInfo = HL.Field(HL.Table)


InnRootSystem.m_heldFoodModelCaches = HL.Field(HL.Table)

InnRootSystem.m_heldFoodModelInfo = HL.Field(HL.Table)


InnRootSystem.m_purseModelCache = HL.Field(HL.Forward("UIGoCache"))

InnRootSystem.m_purseModelInfo = HL.Field(HL.Table)


InnRootSystem.m_guestHudCache = HL.Field(HL.Forward("UIGoCache"))

InnRootSystem.OnInit = HL.Override() << function(self)

end

InnRootSystem.OnRelease = HL.Override() << function(self)
    self:DestroyInnRoot()
end

InnRootSystem.Prepare = HL.Method(HL.Any, HL.Any) << function(self, dishHudPrefab, guestHudPrefab)
    self.m_dishHudPrefab = dishHudPrefab
    self.m_guestHudPrefab = guestHudPrefab
    self.m_resourceLoader = luaLoader.LuaResourceLoader()
end

InnRootSystem.DestroyInnRoot = HL.Method() << function(self)
    if self.m_innRoot then
        GameObject.Destroy(self.m_innRoot)
        self.m_innRoot = nil
    end
    self.m_deskHudRoot = nil
    self.m_kitchenHudRoot = nil
    self.m_dishHudRoot = nil
    self.m_dishModelRoot = nil
    self.m_heldFoodModelRoot = nil
    self.m_purseModelRoot = nil
    self.m_guestHudRoot = nil

    self.m_dishHudCache = nil
    self.m_dishModelCaches = nil
    self.m_dishModelInfo = nil
    self.m_heldFoodModelCaches = nil
    self.m_heldFoodModelInfo = nil
    self.m_purseModelCache = nil
    self.m_purseModelInfo = nil
    self.m_guestHudCache = nil
    self.m_dishHudPrefab = nil
    self.m_guestHudPrefab = nil
    if self.m_resourceLoader then
        self.m_resourceLoader:DisposeAllHandles()
        self.m_resourceLoader = nil
    end
end


InnRootSystem.GetInnRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_innRoot then
        self.m_innRoot = GameObject("InnRoot")
    end
    return self.m_innRoot
end

InnRootSystem.GetDeskHudRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_deskHudRoot then
        self.m_deskHudRoot = GameObject("InnDeskHudRoot")
        self.m_deskHudRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_deskHudRoot
end

InnRootSystem.GetKitchenHudRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_kitchenHudRoot then
        self.m_kitchenHudRoot = GameObject("InnKitchenHudRoot")
        self.m_kitchenHudRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_kitchenHudRoot
end

InnRootSystem.GetDishHudRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_dishHudRoot then
        self.m_dishHudRoot = GameObject("InnDishHudRoot")
        self.m_dishHudRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_dishHudRoot
end

InnRootSystem.GetDishModelRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_dishModelRoot then
        self.m_dishModelRoot = GameObject("InnDishModelRoot")
        self.m_dishModelRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_dishModelRoot
end

InnRootSystem.GetHeldFoodModelRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_heldFoodModelRoot then
        self.m_heldFoodModelRoot = GameObject("InnHeldFoodModelRoot")
        self.m_heldFoodModelRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_heldFoodModelRoot
end

InnRootSystem.GetPurseModelRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_purseModelRoot then
        self.m_purseModelRoot = GameObject("InnPurseModelRoot")
        self.m_purseModelRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_purseModelRoot
end

InnRootSystem.GetGuestHudRoot = HL.Method().Return(GameObject) << function(self)
    if not self.m_guestHudRoot then
        self.m_guestHudRoot = GameObject("InnGuestHudRoot")
        self.m_guestHudRoot.transform:SetParent(self:GetInnRoot().transform, false)
    end
    return self.m_guestHudRoot
end

InnRootSystem.GetDishHud = HL.Method().Return(HL.Any) << function(self)
    if not self.m_dishHudCache then
        self.m_dishHudCache = UIUtils.genGoCache(self.m_dishHudPrefab, Utils.wrapLuaNode, self:GetDishHudRoot())
    end
    return self.m_dishHudCache:Get()
end

InnRootSystem.ReturnDishHud = HL.Method(HL.Any) << function(self, hud)
    if hud and self.m_dishHudCache then
        self.m_dishHudCache:Recycle(hud)
    end
end

InnRootSystem.GetDishModel = HL.Method(HL.String).Return(GameObject) << function(self, itemId)
    self.m_dishModelCaches = self.m_dishModelCaches or {}
    self.m_dishModelInfo = self.m_dishModelInfo or {}

    local modelId
    local hasDish, dish = Tables.innDishTable:TryGetValue(itemId)
    if hasDish and dish then
        modelId = dish.modelId
    else
        local hasDrink, drink = Tables.innDrinkTable:TryGetValue(itemId)
        if hasDrink and drink then
            modelId = drink.modelId
        end
    end
    if not modelId or modelId == "" then
        logger.error(string.format("菜品模型加载失败，itemId：%s 未找到对应的 modelId（InnDishTable/InnDrinkTable）", itemId))
        return nil
    end

    local cache = self.m_dishModelCaches[modelId]
    if not cache then
        local path = string.format(InnConst.INN_FOOD_MODEL_PATH, modelId)
        local prefab = self.m_resourceLoader:LoadGameObject(path)
        if not prefab then
            logger.error(string.format("菜品模型加载失败，itemId：%s，modelId：%s，path：%s", itemId, modelId, path))
            return nil
        end
        cache = UIUtils.genGoCache(prefab, _wrapDishModel, self:GetDishModelRoot())
        self.m_dishModelCaches[modelId] = cache
    end

    local wrapper = cache:Get()
    local go = wrapper.gameObject
    self.m_dishModelInfo[go] = { wrapper = wrapper, modelId = modelId }
    return go
end

InnRootSystem.ReturnDishModel = HL.Method(GameObject) << function(self, model)
    if not model or not self.m_dishModelInfo then
        return
    end
    local info = self.m_dishModelInfo[model]
    if not info then
        return
    end
    local cache = self.m_dishModelCaches and self.m_dishModelCaches[info.modelId]
    if cache then
        cache:Recycle(info.wrapper)
    end
end


InnRootSystem.GetHeldFoodModel = HL.Method(HL.String).Return(GameObject) << function(self, itemId)
    self.m_heldFoodModelCaches = self.m_heldFoodModelCaches or {}
    self.m_heldFoodModelInfo = self.m_heldFoodModelInfo or {}

    local modelId
    local hasDish, dish = Tables.innDishTable:TryGetValue(itemId)
    if hasDish and dish then
        modelId = dish.attachmentModelId
    else
        local hasDrink, drink = Tables.innDrinkTable:TryGetValue(itemId)
        if hasDrink and drink then
            modelId = drink.attachmentModelId
        end
    end
    if not modelId or modelId == "" then
        logger.error(string.format("手持挂件模型加载失败，itemId：%s 未找到对应的 attachmentModelId（InnDishTable/InnDrinkTable）", itemId))
        return nil
    end

    local cache = self.m_heldFoodModelCaches[modelId]
    if not cache then
        local path = string.format(InnConst.INN_FOOD_ATTACHMENT_MODEL_PATH, modelId)
        local prefab = self.m_resourceLoader:LoadGameObject(path)
        if not prefab then
            logger.error(string.format("手持挂件模型加载失败，itemId：%s，attachmentModelId：%s，path：%s", itemId, modelId, path))
            return nil
        end
        cache = UIUtils.genGoCache(prefab, _wrapDishModel, self:GetHeldFoodModelRoot())
        self.m_heldFoodModelCaches[modelId] = cache
    end

    local wrapper = cache:Get()
    local go = wrapper.gameObject
    self.m_heldFoodModelInfo[go] = { wrapper = wrapper, modelId = modelId }
    return go
end

InnRootSystem.ReturnHeldFoodModel = HL.Method(GameObject) << function(self, model)
    if not model or not self.m_heldFoodModelInfo then
        return
    end
    local info = self.m_heldFoodModelInfo[model]
    if not info then
        return
    end
    self.m_heldFoodModelInfo[model] = nil
    if IsNull(model) then
        return
    end
    
    model.transform:SetParent(self:GetHeldFoodModelRoot().transform, false)
    local cache = self.m_heldFoodModelCaches and self.m_heldFoodModelCaches[info.modelId]
    if cache then
        cache:Recycle(info.wrapper)
    end
end


InnRootSystem.GetPurseModel = HL.Method().Return(GameObject) << function(self)
    self.m_purseModelInfo = self.m_purseModelInfo or {}

    if not self.m_purseModelCache then
        local path = string.format(InnConst.INN_FOOD_MODEL_PATH, InnConst.INN_PURSE_MODEL_ID)
        local prefab = self.m_resourceLoader:LoadGameObject(path)
        if not prefab then
            logger.error(string.format("钱包模型加载失败，modelId：%s，path：%s", InnConst.INN_PURSE_MODEL_ID, path))
            return nil
        end
        self.m_purseModelCache = UIUtils.genGoCache(prefab, _wrapDishModel, self:GetPurseModelRoot())
    end

    local wrapper = self.m_purseModelCache:Get()
    local go = wrapper.gameObject
    self.m_purseModelInfo[go] = wrapper
    return go
end

InnRootSystem.ReturnPurseModel = HL.Method(GameObject) << function(self, model)
    if not model or not self.m_purseModelInfo then
        return
    end
    local wrapper = self.m_purseModelInfo[model]
    if not wrapper then
        return
    end
    if self.m_purseModelCache then
        self.m_purseModelCache:Recycle(wrapper)
    end
    self.m_purseModelInfo[model] = nil
end


InnRootSystem.GetGuestHud = HL.Method().Return(HL.Any) << function(self)
    if not self.m_guestHudCache then
        self.m_guestHudCache = UIUtils.genGoCache(self.m_guestHudPrefab, Utils.wrapLuaNode, self:GetGuestHudRoot())
    end
    return self.m_guestHudCache:Get()
end

InnRootSystem.ReturnGuestHud = HL.Method(HL.Any) << function(self, hud)
    if hud and self.m_guestHudCache then
        self.m_guestHudCache:Recycle(hud)
    end
end

HL.Commit(InnRootSystem)
return InnRootSystem
