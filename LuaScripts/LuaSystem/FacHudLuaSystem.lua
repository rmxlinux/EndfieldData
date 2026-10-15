local LuaSystemBase = require_ex('LuaSystem/LuaSystemBase')
FacHudLuaSystem = HL.Class('FacHudLuaSystem', LuaSystemBase.LuaSystemBase)



local FAC_HUD_CONFIGS = {
    ["domain_1"] = {
        [PanelId.FacTopHud] = {
            power = {
                prefabPath = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/FacMiniPowerContent.prefab",
                luaClass = "FacMiniPowerContent",
                loadCondition = function()
                    return Utils.isInFactoryMode()
                end,
            },
        },
        [PanelId.FacTopView] = {
            quickBar = {
                prefabPath = "Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Factory/Widgets/FacQuickBarOverview.prefab",
            },
        },
    },
} 

FAC_HUD_CONFIGS["domain_2"] = FAC_HUD_CONFIGS["domain_1"]

FacHudLuaSystem.FacHudLuaSystem = HL.Constructor() << function(self)

end


FacHudLuaSystem.GetFacHudConfig = HL.Method().Return(HL.Table) << function(self)
    local domainId = FactoryUtils.getCurAndAutoTransferBlackBoxToDomainId()
    local facHudConfig = FAC_HUD_CONFIGS[domainId]
    if not facHudConfig then
        logger.error("[FacHud] Config not found for domain " .. tostring(domainId))
        return nil
    end
    return facHudConfig
end

FacHudLuaSystem.GetFacHudPanelConfig = HL.Method(HL.Number).Return(HL.Table) << function(self, panelId)
    local facHudConfig = self:GetFacHudConfig()
    local facHudPanelConfig = facHudConfig and facHudConfig[panelId]
    if not facHudPanelConfig then
        logger.error("[FacHud] Panel config not found for panel " .. tostring(panelId))
        return nil
    end
    return facHudPanelConfig
end

HL.Commit(FacHudLuaSystem)
return FacHudLuaSystem
