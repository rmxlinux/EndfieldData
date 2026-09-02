
local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.ReadingPopUp

PhaseReadingPopUp = HL.Class('PhaseReadingPopUp', phaseBase.PhaseBase)





PhaseReadingPopUp.s_messages = HL.StaticField(HL.Table) << {
    [MessageConst.SHOW_READING_POP_PANEL] = { 'OnShowReadingPopPanel', false },
    [MessageConst.SHOW_READING_POP_PANEL_BY_HANDLE] = { 'OnShowReadingPopPanelByHandle', false },
}

PhaseReadingPopUp.m_panelIdByBgType = HL.Field(HL.Table)


PhaseReadingPopUp._OnInit = HL.Override() << function(self)
    PhaseReadingPopUp.Super._OnInit(self)
    self.m_panelIdByBgType = {
        [GEnums.ReadingPopBasePlateType.Paper] = PanelId.ReadingPopUpPaper,
        [GEnums.ReadingPopBasePlateType.Elec] = PanelId.ReadingPopUpElec,
        [GEnums.ReadingPopBasePlateType.Simple] = PanelId.ReadingPopUp,
        [GEnums.ReadingPopBasePlateType.OldPaper] = PanelId.ReadingPopUpOldPaper,
    }
end




PhaseReadingPopUp.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
end

PhaseReadingPopUp._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local data, callback = unpack(self.arg)
    local handle = nil
    local id, overrideRadioId
    if type(data) ~= "string" then
        handle = data
        id = handle.data.readingPopupId
    else
        id = data
    end
    
    local readingPopId, richContentId, radioId = ""
    local radioTitle = ""
    local bgType = GEnums.ReadingPopBasePlateType.Simple
    local iconType = GEnums.ReadingPopBlocType.None
    
    local isReadingPopId, readingPopCfg = Tables.readingPopUpTable:TryGetValue(id)
    if isReadingPopId then
        readingPopId = id
        bgType = readingPopCfg.bgType
        iconType = readingPopCfg.iconType
        radioTitle = readingPopCfg.title
        
        id = readingPopCfg.contentId
        overrideRadioId = readingPopCfg.overrideRadioId
    end
    
    if Tables.richContentTable:TryGetValue(id) then
        richContentId = id
        if not isReadingPopId then
            bgType = GEnums.ReadingPopBasePlateType.Paper   
        end
    elseif Tables.radioTable:TryGetValue(id) then
        radioId = id
        if not isReadingPopId then
            bgType = GEnums.ReadingPopBasePlateType.Elec    
        end
    else
        logger.error("【ReadingPopUp】 id不存在：" .. id)
    end
    
    local panelArgs = {
        handle = handle,
        closeCallback = callback,
        
        readingPopId = readingPopId,
        richContentId = richContentId,
        radioId = radioId,
        radioTitle = radioTitle,
        overrideRadioId = overrideRadioId,
        
        iconType = iconType,
        bgType = bgType,
    }
    
    local panelId = self.m_panelIdByBgType[bgType]
    if panelId == nil then
        logger.error("【ReadingPopUp】 bgType未配置Panel：" .. tostring(bgType))
        return
    end
    self:CreatePhasePanelItem(panelId, panelArgs)
end

PhaseReadingPopUp._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseReadingPopUp._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end

PhaseReadingPopUp._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end






PhaseReadingPopUp._OnActivated = HL.Override() << function(self)
end

PhaseReadingPopUp._OnDeActivated = HL.Override() << function(self)
end

PhaseReadingPopUp._OnDestroy = HL.Override() << function(self)
    PhaseReadingPopUp.Super._OnDestroy(self)
end

PhaseReadingPopUp.OnShowReadingPopPanel = HL.StaticMethod(HL.Table) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg, nil, true)
end

PhaseReadingPopUp.OnShowReadingPopPanelByHandle = HL.StaticMethod(HL.Table) << function(arg)
    PhaseManager:OpenPhase(PHASE_ID, arg, nil, true)
end




HL.Commit(PhaseReadingPopUp)

