local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.FacTechTree

local DEFAULT_FAC_TECH_PACKAGE_ID = "tech_group_tundra"















PhaseFacTechTree = HL.Class('PhaseFacTechTree', phaseBase.PhaseBase)


PhaseFacTechTree.m_currentPanelItem = HL.Field(HL.Forward("PhasePanelItem"))






PhaseFacTechTree.s_messages = HL.StaticField(HL.Table) << {
    
    [MessageConst.FAC_TECH_TREE_OPEN_PACKAGE_PANEL] = { 'OpenPackagePanel', true },
    [MessageConst.FAC_TECH_TREE_OPEN_TREE_PANEL] = { 'OpenTreePanel', true },
}





PhaseFacTechTree._OnInit = HL.Override() << function(self)
    PhaseFacTechTree.Super._OnInit(self)
end








PhaseFacTechTree._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local facTechTreeSystem = GameInstance.player.facTechTreeSystem

    if self.arg then
        
        local techId = self.arg.techId
        local packageId = self.arg.packageId
        local layerId = self.arg.layerId

        if not string.isEmpty(techId) then
            
            local techCfg = Tables.facSTTNodeTable[techId]
            self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, {
                techId = techId,
                packageId = techCfg.groupId
            })
            return
        end

        if not string.isEmpty(layerId) then
            local layerCfg = Tables.facSTTLayerTable[layerId]
            self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, {
                layerId = layerId,
                packageId = layerCfg.groupId
            })
            return
        end

        if not string.isEmpty(packageId) then
            self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, {
                packageId = packageId
            })
            return
        end
    else
        
        local success, levelBasicInfo = DataManager.levelBasicInfoTable:TryGetValue(GameWorld.worldInfo.curLevelId)
        if not success then
            self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechPackage)
            return
        end

        local isInSpaceShip = Utils.isInSpaceShip()
        local domainId = isInSpaceShip and GameInstance.player.inventory.spaceshipDomainId or levelBasicInfo.domainName
        local hasDomain = not string.isEmpty(domainId)
        local facTechPackageId = hasDomain and Tables.domainDataTable[domainId].facTechPackageId or DEFAULT_FAC_TECH_PACKAGE_ID

        if facTechTreeSystem:PackageIsLocked(facTechPackageId) or facTechTreeSystem:PackageIsHidden(facTechPackageId) then
            facTechPackageId = DEFAULT_FAC_TECH_PACKAGE_ID
        end

        if facTechPackageId ~= DEFAULT_FAC_TECH_PACKAGE_ID then
            self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, { packageId = facTechPackageId })
        else
            if facTechTreeSystem:PackageIsLocked(DEFAULT_FAC_TECH_PACKAGE_ID) then
                self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechPackage)
            else
                self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, { packageId = DEFAULT_FAC_TECH_PACKAGE_ID })
            end
        end
    end
end





PhaseFacTechTree._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFacTechTree._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end





PhaseFacTechTree._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode,
                                                                                                     args)
end








PhaseFacTechTree._OnActivated = HL.Override() << function(self)
end



PhaseFacTechTree._OnDeActivated = HL.Override() << function(self)
end



PhaseFacTechTree._OnDestroy = HL.Override() << function(self)
    PhaseFacTechTree.Super._OnDestroy(self)
end





PhaseFacTechTree._OnRefresh = HL.Override() << function(self)
    if self.arg == nil or string.isEmpty(self.arg.techId) or self.m_currentPanelItem.uiCtrl.AutoSelect == nil then
        return
    end

    self.m_currentPanelItem.uiCtrl:AutoSelect(self.arg.techId)
end




PhaseFacTechTree.OpenTreePanel = HL.Method(HL.Any) << function(self, args)
    local arg = unpack(args)

    self:RemovePhasePanelItem(self.m_currentPanelItem)
    self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechTree, { packageId = arg })
end




PhaseFacTechTree.OpenPackagePanel = HL.Method(HL.Table) << function(self, args)
    self:RemovePhasePanelItem(self.m_currentPanelItem)
    self.m_currentPanelItem = self:CreatePhasePanelItem(PanelId.FacTechPackage, args)
end

HL.Commit(PhaseFacTechTree)

