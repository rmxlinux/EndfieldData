

local Config = {
    NormalItem = {
        msgs = {
            MessageConst.ON_READ_NEW_ITEM,
        },
        readLike = true,
        needArg = true,
        Check = function(id)
            return GameInstance.player.inventory:IsNewItem(id), UIConst.RED_DOT_TYPE.New
        end,
    },
    InstItem = {
        msgs = {
            MessageConst.ON_READ_NEW_INST_ITEM,
        },
        readLike = true,
        needArg = true,
        Check = function(info)
            return GameInstance.player.inventory:IsNewItem(info.id, info.instId), UIConst.RED_DOT_TYPE.New
        end,
    },
    ValuableDepotItem = {
        msgs = {
            MessageConst.ON_READ_NEW_ITEM,
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_VALUABLE_DEPOT_IMPORT_ITEM_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            if RedDotUtils.isNewObtainedImportantValuableDepotItem(id) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return GameInstance.player.inventory:IsNewItem(id), UIConst.RED_DOT_TYPE.New
        end,
    },
    BlocShopDiscountShopItem = {
        msgs = {
            MessageConst.ON_BUY_ITEM_SUCC,
            MessageConst.ON_SYNC_ALL_BLOC,
        },
        readLike = false,
        needArg = true,
        Check = function(blocId)
            return RedDotUtils.hasBlocShopDiscountShopItem(blocId)
        end
    },
    WeaponEmptyGem = {
        msgs = {
            MessageConst.ON_GEM_DETACH,
            MessageConst.ON_GEM_ATTACH,
        },
        readLike = true,
        needArg = true,
        Check = function(weaponInstId)
            local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
            if weaponInst.attachedGemInstId > 0 then
                return false
            end
            return RedDotUtils.hasGemNotEquipped()
        end
    },
    WeaponCanUpgrade = {
        msgs = {
            MessageConst.ON_WEAPON_GAIN_EXP,
            MessageConst.ON_WEAPON_BREAKTHROUGH,
        },
        readLike = true,
        needArg = true,
        Check = function(weaponInstId)
            return WeaponUtils.canWeaponBreakthrough(weaponInstId) or WeaponUtils.canWeaponUpgrade(weaponInstId)
        end
    },
    Formula = {
        msgs = {
            MessageConst.ON_ADD_NEW_UNREAD_FORMULA,
            MessageConst.ON_READ_FORMULA,
        },
        readLike = true,
        needArg = true,
        Check = function(formulaId)
            return GameInstance.player.remoteFactory.core:IsFormulaUnread(formulaId), UIConst.RED_DOT_TYPE.New
        end,
    },
    BuildingFormula = {
        sons = {
            Formula = false,
        },
        readLike = false,
        needArg = true,
        Check = function(arg)
            local buildingId = arg.buildingId
            local modeName = arg.modeName
            local core = GameInstance.player.remoteFactory.core
            local bData = Tables.factoryBuildingTable:GetValue(buildingId)
            local bType = bData.type
            if bType == GEnums.FacBuildingType.MachineCrafter or bType == GEnums.FacBuildingType.FluidReaction then
                
                local machineCrafterData = FactoryUtils.getMachineCraftGroupData(buildingId, modeName)
                for _, craftId in pairs(machineCrafterData.craftList) do
                    if core:IsFormulaUnread(craftId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
    },

    TechTree = {
        msgs = {
            MessageConst.ON_UNLOCK_FAC_TECH_PACKAGE,
            MessageConst.ON_UNHIDDEN_FAC_TECH_PACKAGE,
            MessageConst.ON_CHANGE_SPACESHIP_DOMAIN_ID,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local levelId = GameWorld.worldInfo.curLevelId
            if string.isEmpty(levelId) then
                logger.warn("RedDotConfig->TechTree Check->levelId is None")
                return false
            end
            local _, levelBasicInfo = DataManager.levelBasicInfoTable:TryGetValue(levelId)
            local isInSpaceShip = Utils.isInSpaceShip()
            local domainId = isInSpaceShip and GameInstance.player.inventory.spaceshipDomainId or levelBasicInfo.domainName
            local hasDomain, domainCfg = Tables.domainDataTable:TryGetValue(domainId)
            if not hasDomain then
                return false
            end
            local facTechPackageId = domainCfg.facTechPackageId
            local techTreeSystem = GameInstance.player.facTechTreeSystem

            if techTreeSystem:PackageIsHidden(facTechPackageId) then
                return false
            end

            if techTreeSystem:PackageIsLocked(facTechPackageId) then
                return false
            end

            local packageCfg = Tables.facSTTGroupTable[facTechPackageId]

            for _, layerId in pairs(packageCfg.layerIds) do
                local groupState = RedDotManager:GetRedDotState("TechTreeLayer", layerId)
                if groupState then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            for _, techId in pairs(packageCfg.techIds) do
                local groupState = RedDotManager:GetRedDotState("TechTreeNode", techId)
                if groupState then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            local blackboxEntryState = RedDotManager:GetRedDotState("BlackboxEntry", facTechPackageId)
            if blackboxEntryState then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end,
        sons = {
            TechTreeNode = false,
            TechTreeLayer = false,
            BlackboxEntry = false,
        }
    },
    TechTreeLayer = {
        msgs = {
            MessageConst.FAC_ON_REFRESH_TECH_TREE_UI,
            MessageConst.ON_ITEM_COUNT_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(layerId)
            local techTreeSystem = GameInstance.player.facTechTreeSystem
            if not techTreeSystem:LayerIsLocked(layerId) then
                return false
            end

            local layerCfg = Tables.facSTTLayerTable[layerId]
            local isEnough = true
            for _, costItem in pairs(layerCfg.costItems) do
                local ownCount = Utils.getItemCount(costItem.costItemId)
                local costCount = costItem.costItemCount
                if ownCount < costCount then
                    isEnough = false
                    break
                end
            end

            return isEnough, UIConst.RED_DOT_TYPE.Normal
        end
    },
    TechTreeNode = {
        msgs = {
            MessageConst.FAC_ON_REFRESH_TECH_TREE_UI,
            MessageConst.ON_ITEM_COUNT_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(techId)
            local techTreeSystem = GameInstance.player.facTechTreeSystem
            local nodeData = Tables.facSTTNodeTable:GetValue(techId)

            if not techTreeSystem:NodeIsLocked(techId) then
                return false
            end

            if techTreeSystem:PreNodeIsLocked(techId) then
                return false
            end

            if techTreeSystem:LayerIsLocked(nodeData.layer) then
                return false
            end

            local isMatchCondition = true
            if nodeData.conditions.Count > 0 then
                for i = 1, nodeData.conditions.Count do
                    if not techTreeSystem:GetConditionIsCompleted(techId,
                        nodeData.conditions[CSIndex(i)].conditionId) then
                        isMatchCondition = false
                        break
                    end
                end
            end

            if not isMatchCondition then
                return false
            end

            local isEnough = Utils.getItemCount(Tables.facSTTGroupTable[nodeData.groupId].costPointType)
                >= nodeData.costPointCount
            if not isEnough then
                return false
            end

            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },

    BlackboxPreDependencies = {
        readLike = true,
        needArg = true,
        Check = function(blackboxIds)
            for _, blackboxId in pairs(blackboxIds) do
                if not GameInstance.dungeonManager:IsDungeonPassed(blackboxId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            BlackboxSelectionCellPassed = false,
        }
    },
    BlackboxSelectionCellPassed = {
        msgs = {
        },
        readLike = true,
        needArg = true,
        Check = function(blackboxId)
            if not GameInstance.dungeonManager:IsDungeonPassed(blackboxId) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end
    },
    BlackboxEntry = {
        readLike = false,
        needArg = true,
        Check = function(packageId)
            local packageCfg = Tables.facSTTGroupTable[packageId]
            for _, blackboxId in pairs(packageCfg.blackboxIds) do
                local hasReadDotState = RedDotManager:GetRedDotState("BlackboxSelectionCellRead", blackboxId)
                if hasReadDotState then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            BlackboxSelectionCellRead = false,
        },
    },
    BlackboxSelectionCellRead = {
        msgs = {
            MessageConst.ON_BLACKBOX_ACTIVE,
            MessageConst.ON_BLACKBOX_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(blackboxId)
            local dungeonMgr = GameInstance.dungeonManager
            if not dungeonMgr:IsDungeonActive(blackboxId) then
                return false
            end

            if dungeonMgr:IsBlackboxRead(blackboxId) then
                return false
            end

            return true, UIConst.RED_DOT_TYPE.New
        end
    },

    SingleBlueprint = {
        msgs = {
            MessageConst.FAC_ON_READ_BLUEPRINT,
        },
        readLike = true,
        needArg = true,
        Check = function(id)
            local isNew
            local t = type(id)
            if t == "number" then
                isNew = GameInstance.player.remoteFactory.blueprint:IsNewMyBlueprint(id)
            elseif t == "string" then
                isNew = GameInstance.player.remoteFactory.blueprint:IsNewSysBlueprint(id)
            else
                isNew = GameInstance.player.remoteFactory.blueprint:IsNewGiftBlueprint(id)
            end
            if isNew then
                return true, UIConst.RED_DOT_TYPE.New
            else
                return false
            end
        end,
    },

    SingleMail = {
        msgs = {
            MessageConst.ON_ALL_MAIL_INITED,
            MessageConst.ON_READ_MAIL,
            MessageConst.ON_GET_MAIL_ATTACHMENT,
            MessageConst.ON_GET_NEW_MAILS,
        },
        readLike = true,
        needArg = true,
        Check = function(mailId)
            local mailSys = GameInstance.player.mail
            if not mailSys:IsAllMailInited() then
                return false
            end
            local mail = mailSys.mails[mailId]
            if mail.isExpired then
                return false
            end
            if not mail.isRead then
                return true, UIConst.RED_DOT_TYPE.New
            end
            if not mail.collected then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
    },
    MailTab = {
        sons = {
            SingleMail = false,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local mailSys = GameInstance.player.mail
            if not mailSys:IsAllMailInited() then
                return false
            end
            for _, mail in pairs(mailSys.mails) do
                if (not mail.isExpired) and (not mail.collected or not mail.isRead) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
    },
    MailTabGetAllBtn = {
        sons = {
            SingleMail = false,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local mailSys = GameInstance.player.mail
            if not mailSys:IsAllMailInited() then
                return false
            end
            for _, mail in pairs(mailSys.mails) do
                if (not mail.isExpired) and (not mail.collected) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
    },
    Mail = {
        sons = {
            SingleMail = false,
            LostAndFoundBtn = false,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local hasRedDot = GameInstance.player.mail:HasNewMail() or not GameInstance.player.inventory.lostAndFound:IsEmpty()
            return hasRedDot, UIConst.RED_DOT_TYPE.Normal
        end,
    },
    LostAndFoundBtn = {
        msgs = {
            MessageConst.ON_GET_LOST_AND_FOUND,
            MessageConst.ON_ADD_LOST_AND_FOUND,
        },
        Check = function()
            return not GameInstance.player.inventory.lostAndFound:IsEmpty(), UIConst.RED_DOT_TYPE.Normal
        end,
        needArg = false,
        readLike = false,
    },

    
    Gacha = {
        msgs = {
            MessageConst.ON_GACHA_POOL_INFO_CHANGED,
            MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED,
            MessageConst.ON_ACTIVITY_GACHA_BEGINNER_STAGE_MODIFY,
            MessageConst.ON_GACHA_POOL_NEW_OPENED_READ,
        },
        needArg = false,
        Check = function()
            return RedDotUtils.hasGachaRedDot()
        end,
        readLike = false,
        sons = {
            GachaSinglePool = false,
        }
    },

    GachaSinglePool = {
        msgs = {
            MessageConst.ON_GACHA_POOL_INFO_CHANGED,
            MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED,
            MessageConst.ON_ACTIVITY_GACHA_BEGINNER_STAGE_MODIFY,
            MessageConst.ON_GACHA_POOL_NEW_OPENED_READ,
        },
        needArg = true,
        Check = function(poolId)
            return RedDotUtils.hasGachaSinglePoolRedDot(poolId)
        end,
        readLike = false,
    },
    

    
    PRTSReading = {
        msgs = {
            MessageConst.ON_PRTS_TERMINAL_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(uniqId)
            return not GameInstance.player.prts.prtsTerminalContentSet:Contains(uniqId), UIConst.RED_DOT_TYPE.Normal
        end
    },

    PRTSWatch = {
        readLike = false,
        needArg = false,
        Check = function()
            
            local prtsSys = GameInstance.player.prts
            for id, _ in pairs(Tables.prtsInvestigate) do
                if not prtsSys:IsInvestigateFinished(id) and prtsSys:IsInvestigateCanFinish(id) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            if unreadSet.Count > 0 then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            PRTSDocument = false,
            PRTSText = false,
            PRTSMultimedia = false,
            PRTSInvestigateTab = false,
        },
    },

    PRTSDocument = {
        readLike = false,
        needArg = false,
        Check = function()
            local unlockSet = GameInstance.player.prts.prtsUnlockSet
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            for _, unreadId in pairs(unreadSet) do
                if unlockSet:Contains(unreadId) and Tables.prtsDocument:ContainsKey(unreadId) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false
        },
    },
    PRTSText = {
        readLike = false,
        needArg = false,
        Check = function()
            local unlockSet = GameInstance.player.prts.prtsUnlockSet
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            for _, unreadId in pairs(unreadSet) do
                if unlockSet:Contains(unreadId) and Tables.prtsRecord:ContainsKey(unreadId) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false
        },
    },
    PRTSStoryCollCategory = {
        readLike = false,
        needArg = true,
        Check = function(categoryId)
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            local prtsSystem = GameInstance.player.prts
            for _, unreadId in pairs(unreadSet) do
                local id = prtsSystem:GetCategoryIdByPrtsId(unreadId)
                if categoryId == id then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false
        },
    },
    PRTSMultimedia = {
        readLike = false,
        needArg = false,
        Check = function()
            local unlockSet = GameInstance.player.prts.prtsUnlockSet
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            for _, unreadId in pairs(unreadSet) do
                if unlockSet:Contains(unreadId) and Tables.prtsMultimedia:ContainsKey(unreadId) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false
        },
    },
    PRTSFirstLv = {
        readLike = false,
        needArg = true,
        Check = function(firstLvId)
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            for _, unreadId in pairs(unreadSet) do
                local _, prtsData = Tables.prtsAllItem:TryGetValue(unreadId)
                if prtsData and prtsData.firstLvId == firstLvId then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false
        },
    },
    PRTSItem = {
        msgs = {
            MessageConst.ON_UNREAD_PRTS,
            MessageConst.ON_READ_PRTS,
        },
        readLike = false,
        needArg = true,
        Check = function(prtsId)
            local unlockSet = GameInstance.player.prts.prtsUnlockSet
            local unreadSet = GameInstance.player.prts.prtsUnReadSet
            if unlockSet:Contains(prtsId) and unreadSet:Contains(prtsId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end,
    },
    PRTSInvestigateTab = {
        readLike = true,
        needArg = false,
        Check = function()
            
            local prtsSys = GameInstance.player.prts
            local hasUnread = false
            for investId, _ in pairs(Tables.prtsInvestigate) do
                local cfg = Utils.tryGetTableCfg(Tables.prtsInvestigate, investId)
                if cfg then
                    local isFinished = prtsSys:IsInvestigateFinished(investId)
                    if isFinished then
                        if not hasUnread then
                            for _, collId in pairs(cfg.collectionIdList) do
                                if prtsSys:IsPrtsUnread(collId) then
                                    hasUnread = true
                                    break ;
                                end
                            end
                            if not hasUnread and RedDotUtils.hasPrtsNoteRedDot(cfg) then
                                hasUnread = true
                            end
                        end
                    else
                        local unlockCount = 0
                        for _, collId in pairs(cfg.collectionIdList) do
                            unlockCount = prtsSys:IsPrtsUnlocked(collId) and unlockCount + 1 or unlockCount
                            if prtsSys:IsPrtsUnread(collId) then
                                hasUnread = true
                            end
                        end
                        
                        if unlockCount >= cfg.collectionIdList.Count then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                        
                        if not hasUnread and RedDotUtils.hasPrtsNoteRedDot(cfg) then
                            hasUnread = true
                        end
                    end
                end
            end
            
            if hasUnread then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end,
        sons = {
            PRTSInvestigate = false,
        },
    },
    PRTSInvestigate = {
        msgs = {
            MessageConst.ON_INVESTIGATE_FINISHED,
            MessageConst.ON_READ_PRTS_NOTE_BATCH,
            MessageConst.ON_READ_PRTS,
        },
        readLike = true,
        needArg = true,
        Check = function(investId)
            local cfg = Utils.tryGetTableCfg(Tables.prtsInvestigate, investId)
            if not cfg then
                return false
            end
            
            local prtsSys = GameInstance.player.prts
            local isFinished = prtsSys:IsInvestigateFinished(investId)
            if isFinished then
                for _, collId in pairs(cfg.collectionIdList) do
                    if prtsSys:IsPrtsUnread(collId) then
                        return true, UIConst.RED_DOT_TYPE.New
                    end
                end
                if RedDotUtils.hasPrtsNoteRedDot(cfg) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            else
                local unlockCount = 0
                local hasUnread = false
                for _, collId in pairs(cfg.collectionIdList) do
                    unlockCount = prtsSys:IsPrtsUnlocked(collId) and unlockCount + 1 or unlockCount
                    if prtsSys:IsPrtsUnread(collId) then
                        hasUnread = true
                    end
                end
                
                if unlockCount >= cfg.collectionIdList.Count then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
                
                if hasUnread then
                    return true, UIConst.RED_DOT_TYPE.New
                end
                
                if RedDotUtils.hasPrtsNoteRedDot(cfg) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            PRTSItem = false,
        },
    },
    PRTSNote = {
        msgs = {
            MessageConst.ON_READ_PRTS_NOTE_BATCH,
            MessageConst.ON_UNREAD_PRTS_NOTE_BATCH,
        },
        readLike = true,
        needArg = true,
        Check = function(noteId)
            local prtsSys = GameInstance.player.prts
            if prtsSys:IsNoteUnread(noteId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end,
    },
    

    AllCharInfo = {
        msgs = {
            MessageConst.SHOW_FOCUS_MODE_TOAST,
            MessageConst.GAME_MODE_ENABLE,
            MessageConst.ENTER_FOCUS_MODE_READY,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local isFullLockedTeam = CharInfoUtils.IsFullLockedTeam()
            if isFullLockedTeam then
                return false
            end
            if not Utils.isInMainScope() then
                return false
            end
            
            local charBag = GameInstance.player.charBag
            if charBag.newCharListSet.Count > 0 then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            for charInstId, charInfo in pairs(charBag.charInfos) do
                if charInfo.charType == GEnums.CharType.Default and
                    RedDotManager:GetRedDotState("CharInfoPotential", charInstId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            CharNew = false,
            CharInfoPotential = false,
        },
    },
    CharInfo = {
        msgs = {
            MessageConst.ON_SYSTEM_UNLOCK_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

            if RedDotManager:GetRedDotState("CharNew", charInst.templateId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            if RedDotManager:GetRedDotState("CharInfoPotential", charInstId) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            CharNew = false,
            CharInfoPotential = false,
        },
    },
    CharNew = {
        msgs = {
            MessageConst.ON_CHAR_NEW_TAG_CHANGED,
        },
        readLike = true,
        needArg = true,
        Check = function(templateId)
            local res = GameInstance.player.charBag:CheckCharIsNew(templateId)
            return res, UIConst.RED_DOT_TYPE.New
        end,
    },
    CharBreak = {
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

            
            for nodeId, nodeData in pairs(Tables.charBreakNodeTable) do
                if nodeData.talentNodeType == GEnums.TalentNodeType.CharBreak then
                    if nodeData.breakStage == charInst.breakStage + 1 and
                        nodeData.equipTierLimit <= charInst.equipTierLimit then
                        local _, breakStageData = Tables.charBreakStageTable:TryGetValue(nodeData.breakStage)
                        if breakStageData and breakStageData.minCharLevel <= charInst.level and
                            CharInfoUtils.isCharBreakCostEnough(charInst.templateId, nodeId) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                elseif nodeData.talentNodeType == GEnums.TalentNodeType.EquipBreak then
                    if nodeData.breakStage == charInst.breakStage and
                        nodeId ~= charInst.talentInfo.latestBreakNode and
                        CharInfoUtils.isCharBreakCostEnough(charInst.templateId, nodeId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end

            
            local talentState = RedDotManager:GetRedDotState("CharTalent", charInstId)
            if talentState then
                return talentState, UIConst.RED_DOT_TYPE.Normal
            end

            
            local skillState = RedDotManager:GetRedDotState("CharSkill", charInstId)
            if skillState then
                return skillState, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end,
        sons = {
            CharBreakNode = false,
            EquipBreakNode = false,
            CharAttrNode = false,
            PassiveSkillNode = false,
            ShipSkillNode = false,
            CharSkillNode = false,
        },
    },
    CharTalent = {
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            local charGrowthData = CharInfoUtils.getCharGrowthData(charInst.templateId)
            if charGrowthData then
                
                local passiveSkillNodeTable = {} 
                
                local shipSkillNodeIndexTable = {} 
                for nodeId, nodeData in pairs(charGrowthData.talentNodeMap) do
                    if nodeData.nodeType == GEnums.TalentNodeType.Attr then
                        if not charInst.talentInfo.attributeNodes:Contains(nodeId) and
                            CSPlayerDataUtil.GetCharFriendship(charInstId) >= nodeData.attributeNodeInfo.favorability and
                            charInst.breakStage >= nodeData.attributeNodeInfo.breakStage and
                            CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeId) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    elseif nodeData.nodeType == GEnums.TalentNodeType.PassiveSkill then
                        local index = nodeData.passiveSkillNodeInfo.index
                        local data = passiveSkillNodeTable[index]
                        if not data then
                            data = {}
                            passiveSkillNodeTable[index] = data
                        end
                        data[nodeData.passiveSkillNodeInfo.level] = nodeData
                    elseif nodeData.nodeType == GEnums.TalentNodeType.FactorySkill then
                        local index = nodeData.factorySkillNodeInfo.index
                        local data = shipSkillNodeIndexTable[index]
                        if not data then
                            data = {}
                            shipSkillNodeIndexTable[index] = data
                        end
                        data[nodeData.factorySkillNodeInfo.level] = nodeData
                    end
                end
                for _, nodeDataTable in pairs(passiveSkillNodeTable) do
                    local maxLv = #nodeDataTable
                    for i = maxLv, 1, -1 do
                        local nodeData = nodeDataTable[i]
                        if charInst.talentInfo.latestPassiveSkillNodes:Contains(nodeData.nodeId) then
                            break
                        end
                        local preNodeData = nodeDataTable[i - 1]
                        if charInst.breakStage >= nodeData.passiveSkillNodeInfo.breakStage and
                            (preNodeData == nil or charInst.talentInfo.latestPassiveSkillNodes:Contains(preNodeData.nodeId)) and
                            CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeData.nodeId) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                end
                for _, nodeDataTable in pairs(shipSkillNodeIndexTable) do
                    local maxLv = #nodeDataTable
                    for i = maxLv, 1, -1 do
                        local nodeData = nodeDataTable[i]
                        if charInst.talentInfo.latestFactorySkillNodes:Contains(nodeData.nodeId) then
                            break
                        end
                        local preNodeData = nodeDataTable[i - 1]
                        if charInst.breakStage >= nodeData.factorySkillNodeInfo.breakStage and
                            (preNodeData == nil or charInst.talentInfo.latestFactorySkillNodes:Contains(preNodeData.nodeId)) and
                            CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeData.nodeId) then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                end
            end
            return false
        end,
        sons = {
            CharAttrNode = false,
            PassiveSkillNode = false,
            ShipSkillNode = false,
        },
    },
    CharSkill = {
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            for _, skillGroupLevelInfo in pairs(charInst.skillGroupLevelInfoList) do
                if skillGroupLevelInfo.level < skillGroupLevelInfo.maxLevel then
                    if CharInfoUtils.isSkillGroupLevelUpCostEnough(charInst.templateId, skillGroupLevelInfo.skillGroupId, skillGroupLevelInfo.level + 1) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
        sons = {
            CharSkillNode = false,
        },
    },
    CharBreakNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_CHAR_LEVEL_UP,
            MessageConst.ON_CHAR_TALENT_UPGRADE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, nodeId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local isActive, isLock = CharInfoUtils.getCharBreakNodeStatus(charInstId, nodeId)
            if isActive or isLock then
                return false
            end
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if charInst.charType == GEnums.CharType.Trial then
                return false
            end
            if not CharInfoUtils.isCharBreakCostEnough(charInst.templateId, nodeId) then
                return false
            end
            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },
    EquipBreakNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_CHAR_LEVEL_UP,
            MessageConst.ON_CHAR_TALENT_UPGRADE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, nodeId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local isActive, isLock = CharInfoUtils.getEquipBreakNodeStatus(charInstId, nodeId)
            if isActive or isLock then
                return false
            end
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if charInst.charType == GEnums.CharType.Trial then
                return false
            end
            if not CharInfoUtils.isCharBreakCostEnough(charInst.templateId, nodeId) then
                return false
            end
            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },
    CharAttrNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_CHAR_TALENT_UPGRADE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, nodeId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local isActive, isLock = CharInfoUtils.getAttributeNodeStatus(charInstId, nodeId)
            if isActive or isLock then
                return false
            end
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if charInst.charType == GEnums.CharType.Trial then
                return false
            end
            if not CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeId) then
                return false
            end
            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },
    PassiveSkillNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_CHAR_TALENT_UPGRADE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, nodeId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local isActive, isLock = CharInfoUtils.getPassiveSkillNodeStatus(charInstId, nodeId)
            if isActive or isLock then
                return false
            end
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if charInst.charType == GEnums.CharType.Trial then
                return false
            end
            if not CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeId) then
                return false
            end
            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },
    ShipSkillNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_CHAR_TALENT_UPGRADE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, nodeId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local isActive, isLock = CharInfoUtils.getShipSkillNodeStatus(charInstId, nodeId)
            if isActive or isLock then
                return false
            end
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if charInst.charType == GEnums.CharType.Trial then
                return false
            end
            if not CharInfoUtils.isCharTalentCostEnough(charInst.templateId, nodeId) then
                return false
            end
            return true, UIConst.RED_DOT_TYPE.Normal
        end
    },
    CharSkillNode = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_WALLET_CHANGED,
            MessageConst.ON_SKILL_UPGRADE_SUCCESS,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, skillGroupId = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

            
            local skillGroupLevelInfo = CharInfoUtils.getCharSkillLevelInfo(charInst, skillGroupId)
            if skillGroupLevelInfo.level < skillGroupLevelInfo.maxLevel then
                if CharInfoUtils.isSkillGroupLevelUpCostEnough(charInst.templateId, skillGroupId, skillGroupLevelInfo.level + 1) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            return false
        end
    },
    EquipTab = {
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            for slotIndex, _ in pairs(UIConst.EQUIP_PART_TYPE_2_CELL_CONFIG) do
                local groupState = RedDotManager:GetRedDotState("Equip", { charInstId, slotIndex })
                if groupState then
                    return groupState, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            Equip = false,
        },
    },
    Equip = {
        msgs = {
            MessageConst.ON_EQUIP_DEPOT_CHANGED,
            MessageConst.ON_PUT_ON_EQUIP,
            MessageConst.ON_PUT_OFF_EQUIP,
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_TACTICAL_ITEM_CHANGE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId, equipSlotIndex = unpack(args)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local equipCellCfg = UIConst.EQUIP_PART_TYPE_2_CELL_CONFIG[equipSlotIndex]
            if not equipCellCfg then
                return false
            end
            
            local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)

            if equipCellCfg.isTacticalItem then
                if not string.isEmpty(charInst.tacticalItemId) then
                    return false
                end
                for _, itemEquipData in pairs(Tables.equipItemTable) do
                    if GameInstance.player.inventory:IsItemFound(itemEquipData.itemId) and
                        Utils.getBagItemCount(itemEquipData.itemId) > 0 then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            else
                local isEquipped, equipInstId = charInst.equipCol:TryGetValue(equipCellCfg.equipIndex)
                if isEquipped and equipInstId > 0 then
                    return false
                end
                local equipDepot = GameInstance.player.inventory.valuableDepots[GEnums.ItemValuableDepotType.Equip]:GetOrFallback(Utils.getCurrentScope())
                if not equipDepot then
                    return false
                end
                for _, itemBundle in pairs(equipDepot.instItems) do
                    if itemBundle.instData.equippedCharServerId == 0 then
                        local templateId = itemBundle.instData.templateId
                        local _, equipCfg = Tables.equipTable:TryGetValue(templateId)
                        if equipCfg and equipCfg.partType == equipCellCfg.slotPartType then
                            local _, itemData = Tables.itemTable:TryGetValue(templateId)
                            if itemData and itemData.rarity <= charInst.equipTierLimit then
                                return true, UIConst.RED_DOT_TYPE.Normal
                            end
                        end
                    end
                end
            end
            return false
        end,
    },
    WatchBtn = {
        readLike = false,
        needArg = false,
        sons = {
        },
    },
    WatchBtnList = {
        readLike = false,
        needArg = true,
        Check = function(redDots)
            for i = 1, #redDots do
                if RedDotManager:GetRedDotState(redDots[i]) then
                    return true
                end
            end
            return false
        end,
    },
    InventoryBtn = {
        readLike = false,
        needArg = false,
        sons = {
            
            ManualCraftBtn = true,
        },
    },

    ShopSeeGoodsInfo = {
        msgs = {
            MessageConst.ON_SHOP_GOODS_SEE_GOODS_INFO_CHANGE,
        },
        readLike = false,
        needArg = true,
        Check = function(info)
            return GameInstance.player.shopSystem:IsNewGoodsId(info.goodsId), UIConst.RED_DOT_TYPE.New
        end,
    },

    ManualCraftBtn = {
        readLike = false,
        needArg = false,
        Check = function()
            if Utils.isInBlackbox() or Utils.isInWeekRaid() then
                return false
            end
            local isUnlocked = Utils.isSystemUnlocked(GEnums.UnlockSystemType.ProductManual)
            if isUnlocked and GameInstance.player.facManualCraft.unreadFormulaIds.Count > 0 then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            ManualCraftType = false,
            ManualCraftRewardEntry = true,
        },
    },
    ManualCraftType = {
        readLike = false,
        needArg = true,
        Check = function(formulaType)
            local blackboxData = GameWorld.worldInfo.curLevel.levelData.blackbox
            if blackboxData then
                return false, UIConst.RED_DOT_TYPE.Normal
            end
            if GameInstance.player.facManualCraft:ExistUnreadFormulaByType(formulaType) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            ManualCraftItem = false,
        },
    },
    ManualCraftItem = {
        msgs = {
            MessageConst.ON_UNREAD_MANUAL_CRAFT,
            MessageConst.ON_READ_MANUAL_CRAFT,
        },
        readLike = false,
        needArg = true,
        Check = function(formulaId)
            local blackboxData = GameWorld.worldInfo.curLevel.levelData.blackbox
            if blackboxData then
                return false, UIConst.RED_DOT_TYPE.Normal
            end
            if not GameInstance.player.facManualCraft:IsCraftRead(formulaId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end,
    },

    ManualCraftRewardItem = {
        msgs = {
            MessageConst.ON_UNREAD_MANUAL_CRAFT_REWARD,
            MessageConst.ON_READ_MANUAL_CRAFT_REWARD,
        },
        readLike = false,
        needArg = true,
        Check = function(arg)
            local blackboxData = GameWorld.worldInfo.curLevel.levelData.blackbox
            if blackboxData then
                return false, UIConst.RED_DOT_TYPE.Normal
            end
            if arg.rewardId then
                if GameInstance.player.facManualCraft:CheckHaveReadReward(arg.rewardId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
                return false
            else
                if GameInstance.player.facManualCraft:CheckHaveReadRewardByItem(arg.itemId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
                return false
            end
        end,
    },

    ManualCraftReward = {
        readLike = false,
        needArg = true,
        penetrateLevel = UIConst.RED_DOT_TYPE.Normal,
        Check = function(arg)
            local blackboxData = GameWorld.worldInfo.curLevel.levelData.blackbox
            if blackboxData then
                return false, UIConst.RED_DOT_TYPE.Normal
            end
            if GameInstance.player.facManualCraft:CheckHaveRewardByItemNoGet(arg.itemId) > 0 then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            ManualCraftRewardItem = false,
        },
    },
    ManualCraftRewardEntry = {
        msgs = {
            MessageConst.ON_SYSTEM_UNLOCK_CHANGED,
        },
        readLike = false,
        needArg = false,
        penetrateLevel = UIConst.RED_DOT_TYPE.Normal,
        Check = function()
            if Utils.isInBlackbox() or Utils.isInWeekRaid() then
                return false
            end
            if Utils.isSystemUnlocked(GEnums.UnlockSystemType.ProductManual) and GameInstance.player.facManualCraft:CheckRewardRedDot() then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            ManualCraftReward = false,
        },
    },

    Announcement = {
        msgs = {
            MessageConst.ON_ANNOUNCEMENT_RED_DOT_CHANGED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            return GameInstance.player.announcement:HasNewAnnouncement()
        end,
    },
    
    FacBuildModeMenuItem = {
        readLike = true,
        needArg = true,
        Check = function(id)
            local _, hasSaved = ClientDataManagerInst:GetBool(FacConst.FAC_BUILD_LIST_REDDOT_DATA_CATEGORY .. id, false, false, FacConst.FAC_BUILD_LIST_REDDOT_DATA_CATEGORY)
            if not hasSaved then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false, UIConst.RED_DOT_TYPE.Normal
        end,
    },
    FacBuildModeMenuLogisticTab = {
        msgs = {
            MessageConst.ON_SYSTEM_UNLOCK_CHANGED,
            MessageConst.ON_IN_FAC_MAIN_REGION_CHANGE,
        },
        sons = {
            FacBuildModeMenuItem = false,
        },
        readLike = false,
        needArg = false,
        Check = function()
            if not Utils.isInFacMainRegion() then
                return false
            end
            for id, _ in pairs(Tables.factoryGridConnecterTable) do
                if Utils.isSystemUnlocked(FacConst.LOGISTIC_UNLOCK_SYSTEM_MAP[id]) then
                    if RedDotManager:GetRedDotState("FacBuildModeMenuItem", id) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            for id, _ in pairs(Tables.factoryGridRouterTable) do
                if Utils.isSystemUnlocked(FacConst.LOGISTIC_UNLOCK_SYSTEM_MAP[id]) then
                    if RedDotManager:GetRedDotState("FacBuildModeMenuItem", id) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
    },

    SNSNormalDialogSubCell = {
        msgs = {
            MessageConst.ON_READ_SNS_DIALOG,
        },
        needArg = true,
        readLike = true,
        Check = function(dialogId)
            local dialogHasRead = GameInstance.player.sns:DialogHasRead(dialogId)
            if not dialogHasRead then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end,
    },
    SNSMissionDialogCell = {
        msgs = {
            MessageConst.ON_READ_SNS_DIALOG,
        },
        needArg = true,
        readLike = true,
        Check = function(dialogId)
            local dialogHasRead = GameInstance.player.sns:DialogHasRead(dialogId)
            if not dialogHasRead then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end,
    },
    SNSContactNpcCellTopic = {
        msgs = {
            MessageConst.ON_READ_SNS_DIALOG,
        },
        needArg = true,
        readLike = true,
        Check = function(chatId)
            local showingTopicDialogInfos = SNSUtils.getShowingTopicDialogInfos(chatId)
            for _, info in ipairs(showingTopicDialogInfos) do
                local topicDialogId = info.dialogId
                local dialogHasRead = GameInstance.player.sns:DialogHasRead(topicDialogId)
                if not dialogHasRead then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            return false
        end,
    },
    SNSContactNpcCell = {
        sons = {
            SNSNormalDialogSubCell = false,
        },
        needArg = true,
        readLike = true,
        Check = function(chatId)

            local succ, chatInfo = GameInstance.player.sns.chatInfoDic:TryGetValue(chatId)
            if not succ then
                return false
            end

            for _, dialogId in pairs(chatInfo.dialogIds) do
                local dialogCfg = Tables.sNSDialogTable[dialogId]
                if string.isEmpty(dialogCfg.topicId) then
                    local redDotState = RedDotManager:GetRedDotState("SNSNormalDialogSubCell", dialogId)
                    if redDotState then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end

            return false
        end,
    },
    SNSBarkerTabCell = {
        sons = {
            SNSContactNpcCellTopic = false,
            SNSContactNpcCell = false,
        },
        msgs = {
            MessageConst.ON_SNS_BARKER_TAB_READ_STATE_CHANGE,
        },
        needArg = false,
        readLike = true,
        Check = function()
            local succ, read = ClientDataManagerInst:GetBool(SNSUtils.NORMAL_TAB_READ, false, false, SNSUtils.SNS_CATEGORY)
            if succ and read then
                return false
            end

            local chatInfoDic = GameInstance.player.sns.chatInfoDic
            for chatId, chatInfo in pairs(chatInfoDic) do
                local topicRedDotState = RedDotManager:GetRedDotState("SNSContactNpcCellTopic", chatId)
                if topicRedDotState then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end

                local hasRedDot = RedDotManager:GetRedDotState("SNSContactNpcCell", chatId)
                if hasRedDot then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            return false
        end
    },
    SNSMissionTabCell = {
        sons = {
            SNSMissionDialogCell = false,
        },
        msgs = {
            MessageConst.ON_SNS_MISSION_TAB_READ_STATE_CHANGE,
        },
        needArg = false,
        readLike = true,
        Check = function()
            local succ, read = ClientDataManagerInst:GetBool(SNSUtils.MISSION_TAB_READ, false, false, SNSUtils.SNS_CATEGORY)
            if succ and read then
                return false
            end

            local missionRelatedSNSDialogIds = GameInstance.player.sns.missionRelatedSNSDialogIds
            for _, dialogId in pairs(missionRelatedSNSDialogIds) do
                local hasRedDot = RedDotManager:GetRedDotState("SNSMissionDialogCell", dialogId)
                if hasRedDot then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end
    },
    SNSHudEntry = {
        sons = {
            SNSBarkerTabCell = false,
            SNSMissionTabCell = false,
            FriendChatUnRead = false,
        },
        needArg = false,
        readLike = false,
        Check = function()
            local hasRedDot = RedDotManager:GetRedDotState("FriendChatUnRead")
            if hasRedDot then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            hasRedDot = RedDotManager:GetRedDotState("SNSMissionTabCell")
            if hasRedDot then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            hasRedDot = RedDotManager:GetRedDotState("SNSBarkerTabCell")
            if hasRedDot then
                return true, UIConst.RED_DOT_TYPE.Normal
            end

            return false
        end
    },

    CharInfoPotential = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(charInstId)
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            
            local charInfo = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            local hasValue
            
            local characterPotentialList
            hasValue, characterPotentialList = Tables.characterPotentialTable:TryGetValue(charInfo.templateId)
            if not hasValue or charInfo.potentialLevel >= #characterPotentialList.potentialUnlockBundle then
                return false
            end
            local potentialData = characterPotentialList.potentialUnlockBundle[charInfo.potentialLevel]
            local itemId = potentialData.itemIds[0]
            local itemCount = Utils.getItemCount(itemId)
            local needCount = potentialData.itemCnts[0]
            if itemCount >= needCount then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },

    CharInfoPotentialSkill = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local charInstId = args.charInstId
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local potentialLevel = args.potentialLevel
            
            local charInfo = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if not charInfo or charInfo.charType == GEnums.CharType.Trial or potentialLevel ~= charInfo.potentialLevel + 1 then
                return false
            end
            local _, characterPotentialList = Tables.characterPotentialTable:TryGetValue(charInfo.templateId)
            if not characterPotentialList or potentialLevel > #characterPotentialList.potentialUnlockBundle then
                return false
            end
            local potentialData = characterPotentialList.potentialUnlockBundle[CSIndex(potentialLevel)]
            local itemId = potentialData.itemIds[0]
            local itemCount = Utils.getItemCount(itemId)
            local needCount = potentialData.itemCnts[0]
            if itemCount >= needCount then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },

    CharInfoPotentialPicture = {
        msgs = {
            MessageConst.ON_CHAR_POTENTIAL_PICTURE_READ,
            MessageConst.ON_CHAR_POTENTIAL_PICTURE_UNREAD,
        },
        readLike = true,
        needArg = true,
        Check = function(args)
            local charInstId = args.charInstId
            if not CharInfoUtils.isCharDevAvailable(charInstId) then
                return false
            end
            local potentialLevel = args.potentialLevel
            
            local charInfo = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
            if not charInfo or charInfo.charType == GEnums.CharType.Trial or potentialLevel > charInfo.potentialLevel then
                return false
            end
            local _, characterPotentialList = Tables.characterPotentialTable:TryGetValue(charInfo.templateId)
            if not characterPotentialList or potentialLevel > #characterPotentialList.potentialUnlockBundle then
                return false
            end
            local pictureId = args.pictureId
            if string.isEmpty(pictureId) then
                local potentialData = characterPotentialList.potentialUnlockBundle[CSIndex(potentialLevel)]
                for _, itemId in pairs(potentialData.unlockCharPictureItemList) do
                    local _, pictureId = Tables.pictureItemTable:TryGetValue(itemId)
                    if pictureId and not GameInstance.player.charBag:IsCharPotentialPictureRead(pictureId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            else
                if not GameInstance.player.charBag:IsCharPotentialPictureRead(pictureId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            return false
        end,
    },

    EquipTech = {
        msgs = {
            MessageConst.ON_SYSTEM_UNLOCK_CHANGED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            if Utils.isInBlackbox() then
                return false
            end
            if RedDotManager:GetRedDotState("EquipProducer", nil) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            EquipFormula = false,
        }
    },

    EquipProducer = {
        msgs = {
            MessageConst.ON_SYSTEM_UNLOCK_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(isSuit)
            if Utils.isInBlackbox() then
                return false
            end

            for packId, _ in pairs(Tables.equipPackFormulaTable) do
                local _, packData = Tables.equipPackTable:TryGetValue(packId)
                if packData and (isSuit == nil or packData.isSuit == isSuit) then
                    if RedDotManager:GetRedDotState("EquipPack", packId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
        sons = {
            EquipFormula = false,
        }
    },

    EquipPack = {
        readLike = false,
        needArg = true,
        Check = function(packId)
            if Utils.isInBlackbox() then
                return false
            end
            
            local equipTechSystem = GameInstance.player.equipTechSystem
            if not equipTechSystem:IsEquipPackUnlocked(packId) then
                return false
            end
            local _, packDataList = Tables.equipPackFormulaTable:TryGetValue(packId)
            if not packDataList then
                return false
            end
            local isPackNew = true
            local hasNew = false
            local isUnread = false
            for _, packFormulaData in pairs(packDataList.itemList) do
                local formulaId = packFormulaData.formulaId
                if not isUnread and equipTechSystem:IsFormulaUnread(formulaId) then
                    isUnread = true
                end
                local _, formulaData = Tables.equipFormulaTable:TryGetValue(formulaId)
                if formulaData and formulaData.isNew then
                    local isVersionNewRead = equipTechSystem:IsNewVersionFormulaRead(formulaId)
                    if not isVersionNewRead then
                        hasNew = true
                    end
                else
                    isPackNew = false
                end
            end
            if hasNew then
                if isPackNew then
                    return true, EquipTechConst.EQUIP_PRODUCE_PACK_RED_DOT_TYPE.AllNew
                else
                    return true, EquipTechConst.EQUIP_PRODUCE_PACK_RED_DOT_TYPE.PartialNew
                end
            elseif isUnread then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            EquipFormula = false,
        }
    },

    EquipFormula = {
        msgs = {
            MessageConst.ON_EQUIP_FORMULA_UNREAD,
            MessageConst.ON_EQUIP_FORMULA_READ,
            MessageConst.ON_NEW_VERSION_EQUIP_FORMULA_READ,
            MessageConst.ON_NEW_VERSION_EQUIP_FORMULA_UNREAD,
        },
        readLike = true,
        needArg = true,
        Check = function(formulaId)
            if Utils.isInBlackbox() then
                return false
            end
            local _, formulaData = Tables.equipFormulaTable:TryGetValue(formulaId)
            if formulaData and formulaData.isNew and not GameInstance.player.equipTechSystem:IsNewVersionFormulaRead(formulaId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return GameInstance.player.equipTechSystem:IsFormulaUnread(formulaId), UIConst.RED_DOT_TYPE.Normal
        end
    },

    CharInfoProfile = {
        readLike = false,
        needArg = true,
        sons = {
            CharVoice = true,
            CharDoc = true,
        }
    },
    CharInfoDungeon = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = true,
        Check = function(charTemplateId)
            local dungeonId
            local success, _ = pcall(function()
                dungeonId = Tables.CharId2DungeonIdTable[charTemplateId]
            end)
            if success then
                return RedDotManager:GetRedDotState("DungeonReadNormal", { dungeonId })
            else
                return false
            end
        end,
        needArg = true,
    },

    CharVoice = {
        readLike = false,
        needArg = true,
        Check = function(charTemplateId)
            local hasValue
            
            local charData
            hasValue, charData = Tables.characterTable:TryGetValue(charTemplateId)
            if hasValue then
                for _, voiceData in pairs(charData.profileVoice) do
                    if GameInstance.player.charBag:IsCharVoiceUnread(voiceData.id) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
        sons = {
            CharVoiceEntry = false
        }
    },

    CharVoiceEntry = {
        msgs = {
            MessageConst.ON_CHAR_VOICE_READ,
            MessageConst.ON_CHAR_VOICE_UNREAD,
            MessageConst.ON_CHAR_VOICE_LOCKED,
            MessageConst.ON_CHAR_VOICE_UNLOCKED,
        },
        readLike = true,
        needArg = true,
        Check = function(charVoiceId)
            return GameInstance.player.charBag:IsCharVoiceUnread(charVoiceId), UIConst.RED_DOT_TYPE.New
        end
    },

    CharDoc = {
        readLike = false,
        needArg = true,
        Check = function(charTemplateId)
            local hasValue
            
            local charData
            hasValue, charData = Tables.characterTable:TryGetValue(charTemplateId)
            if hasValue then
                for _, recordData in pairs(charData.profileRecord) do
                    if GameInstance.player.charBag:IsCharDocUnread(recordData.id) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end,
        sons = {
            CharDocEntry = false
        }
    },

    CharDocEntry = {
        msgs = {
            MessageConst.ON_CHAR_DOC_READ,
            MessageConst.ON_CHAR_DOC_UNREAD,
            MessageConst.ON_CHAR_DOC_LOCKED,
            MessageConst.ON_CHAR_DOC_UNLOCKED,
        },
        readLike = true,
        needArg = true,
        Check = function(charDocId)
            return GameInstance.player.charBag:IsCharDocUnread(charDocId), UIConst.RED_DOT_TYPE.New
        end
    },

    

    AdventureBook = {
        readLike = false,
        needArg = false,
        sons = {
            AdventureBookTabDaily = true,
            AdventureBookTabStage = true,
            AdventureBookTabDungeon = true,
            AdventureBookTabWeekRaid = true,
        },
    },

    AdventureBookTabStage = {
        msgs = {
            MessageConst.ON_ADVENTURE_TASK_MODIFY,
            MessageConst.ON_ADVENTURE_BOOK_STAGE_MODIFY,
        },
        readLike = false,
        needArg = false,
        Check = AdventureBookUtils.CheckRedDotAdventureBookTabStage
    },

    AdventureBookTabStageTaskCell = {
        msgs = {
            MessageConst.ON_ADVENTURE_TASK_MODIFY,
            MessageConst.ON_ADVENTURE_BOOK_STAGE_MODIFY,
        },
        readLike = true,
        needArg = true,
        Check = function(taskId)
            return GameInstance.player.adventure:IsTaskComplete(taskId)
        end
    },

    AdventureBookTabDaily = {
        msgs = {
            MessageConst.ON_ADVENTURE_TASK_MODIFY,
            MessageConst.ON_DAILY_ACTIVATION_MODIFY,
        },
        readLike = false,
        needArg = false,
        Check = AdventureBookUtils.CheckRedDotAdventureBookTabDaily
    },

    AdventureBookTabDailyTaskCell = {
        msgs = {
            MessageConst.ON_ADVENTURE_TASK_MODIFY,
            MessageConst.ON_DAILY_ACTIVATION_MODIFY,
        },
        readLike = false,
        needArg = true,
        Check = function(taskId)
            
            local curActivation = GameInstance.player.adventure.adventureBookData.dailyActivation
            local maxActivation = 0
            for _, cfg in pairs(Tables.dailyActivationRewardTable) do
                if cfg.activation > maxActivation then
                    maxActivation = cfg.activation
                end
            end
            if curActivation >= maxActivation then
                return false
            end
            
            local taskDic = GameInstance.player.adventure.adventureBookData.adventureTasks
            local csTask = taskDic:get_Item(taskId)
            return csTask.isComplete
        end
    },

    AdventureBookTabDungeon = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = false,
        needArg = false,
        Check = AdventureBookUtils.CheckRedDotAdventureBookTabDungeon
    },

    AdventureDungeonTab = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(ids)
            for _, id in pairs(ids) do
                if GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true
                end
            end
            return false
        end
    },

    AdventureDungeonCell = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(ids)
            for _, id in pairs(ids) do
                if GameInstance.player.subGameSys:IsGameUnlocked(id) and
                    GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end
    },

    AdventureBookTabTrain = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = false,
        needArg = false,
        Check = AdventureBookUtils.CheckRedDotAdventureBookTabTrain
    },

    AdventureBookTabBlackbox = {
        msgs = {
            MessageConst.ON_BLACKBOX_ACTIVE,
            MessageConst.ON_BLACKBOX_READ,
        },
        readLike = false,
        needArg = false,
        Check = AdventureBookUtils.CheckRedDotAdventureBookTabBlackbox
    },

    DungeonRead = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(dungeonIds)
            for _, id in pairs(dungeonIds) do
                if DungeonUtils.isDungeonUnlock(id) and
                    GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end
    },

    
    DungeonReadNormal = {
        msgs = {
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(dungeonIds)
            for _, id in pairs(dungeonIds) do
                if DungeonUtils.isDungeonUnlock(id) and
                    GameInstance.player.subGameSys:IsGameUnread(id) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end
    },

    AdventureBlackboxCell = {
        msgs = {
            MessageConst.ON_BLACKBOX_ACTIVE,
            MessageConst.ON_BLACKBOX_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(blackboxIds)
            local dungeonMgr = GameInstance.dungeonManager
            
            for _, blackboxId in ipairs(blackboxIds) do
                if dungeonMgr:IsDungeonUnlocked(blackboxId) and not dungeonMgr:IsBlackboxRead(blackboxId) then
                    return true
                end
            end

            return false
        end
    },

    AdventureBookTabActivity = {
        readLike = false,
        needArg = false,
        Check = function()
            return AdventureBookUtils.CheckRedDotAdventureBookTabActivity()
        end
    },

    AdventureBookTabWeekRaid = {
        sons = {
            WeekRaidBattlePass = true,
        },
        readLike = false,
    },

    

    RecycleBinCanPickUp = {
        msgs = {
            MessageConst.ON_RECYCLE_BIN_CAN_PICK_UP,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local pickUpList = GameInstance.player.recycleBinSystem.canPickUpInstIds
            return pickUpList.Count > 0, UIConst.RED_DOT_TYPE.Normal
        end
    },

    SettlementDefenseTerminal = {
        msgs = {
            MessageConst.ON_TOWER_DEFENSE_LEVEL_UNLOCKED,
            MessageConst.ON_TOWER_DEFENSE_LEVEL_COMPLETED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            if not Utils.isSettlementDefenseGuideCompleted() then
                return false
            end
            local dangerSettlementIds = GameInstance.player.towerDefenseSystem.dangerSettlementIds
            return dangerSettlementIds.Count > 0, UIConst.RED_DOT_TYPE.Normal
        end,
    },

    
    CheckIn = {
        readLike = false,
        needArg = false,
        Check = RedDotUtils.hasCheckInRewardsNotCollected,
        msgs = {
            MessageConst.ON_ACTIVITY_UPDATED
        }
    },

    
    CheckInTab = {
        readLike = false,
        needArg = true,
        Check = RedDotUtils.hasCheckInRewardsNotCollectedInRange,
        msgs = {
            MessageConst.ON_CHECK_IN_UPDATED
        },
    },

    MapUnreadLevel = {
        msgs = {
            MessageConst.ON_READ_LEVEL,
        },
        readLike = true,
        needArg = false,
        Check = function(levelId)
            return not GameInstance.player.mapManager:IsLevelRead(levelId), UIConst.RED_DOT_TYPE.Normal
        end
    },

    

    MapRemind = {
        readLike = false,
        needArg = false,
        sons = {
            MapImportantMatters = true,
            MapCollectionTips = true,
        },
    },

    MapImportantMatters = {
        readLike = false,
        needArg = false,
    },

    MapCollectionTips = {
        readLike = false,
        needArg = false
    },

    
    CommonMapRemind = {
        msgs = {
            MessageConst.ON_MAP_REMIND_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            return MapUtils.mapRemindRedDotCheck(args)
        end,
    },

    CommonMapRemindReadLike = {
        msgs = {
            MessageConst.ON_MAP_REMIND_UPDATE,
        },
        readLike = true,
        needArg = true,
        Check = function(args)
            return MapUtils.mapRemindRedDotCheck(args)
        end,
    },

    

    
    Wiki = {
        readLike = false,
        needArg = false,
        Check = function()
            if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Wiki) then
                return false
            end
            for _, categoryData in pairs(Tables.wikiCategoryTable) do
                local isUnread = RedDotManager:GetRedDotState("WikiCategory", categoryData.categoryId)
                if isUnread then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            WikiCategory = false,
        }
    },

    WikiCategory = {
        readLike = false,
        needArg = true,
        Check = function(categoryId)
            if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Wiki) then
                return false
            end
            local _, wikiGroupData = Tables.wikiGroupTable:TryGetValue(categoryId)
            if not wikiGroupData then
                return false
            end
            for _, groupData in pairs(wikiGroupData.list) do
                local isUnread = RedDotManager:GetRedDotState("WikiGroup", groupData.groupId)
                if isUnread then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            WikiGroup = false
        }
    },

    WikiGroup = {
        readLike = false,
        needArg = true,
        Check = function(groupId)
            if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Wiki) then
                return false
            end
            local _, wikiEntryList = Tables.wikiEntryTable:TryGetValue(groupId)
            if not wikiEntryList then
                return false
            end
            for _, wikiEntryId in pairs(wikiEntryList.list) do
                if WikiUtils.isWikiEntryUnread(wikiEntryId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            WikiEntry = false,
        },
    },
    WikiEntry = {
        msgs = {
            MessageConst.ON_WIKI_ENTRY_UNLOCKED,
            MessageConst.ON_WIKI_ENTRY_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(entryId)
            if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Wiki) then
                return false
            end
            return WikiUtils.isWikiEntryUnread(entryId), UIConst.RED_DOT_TYPE.New
        end
    },
    WikiGuideEntry = {
        msgs = {
            MessageConst.ON_WIKI_ENTRY_UNLOCKED,
            MessageConst.ON_WIKI_ENTRY_READ,
        },
        readLike = true,
        needArg = true,
        Check = function(entryId)
            if not Utils.isSystemUnlocked(GEnums.UnlockSystemType.Wiki) then
                return false
            end
            return WikiUtils.isWikiEntryUnread(entryId), UIConst.RED_DOT_TYPE.Normal
        end
    },
    WikiLimitedGuide = {
        msgs = {
            MessageConst.ON_LIMITED_GUIDE_WIKI_ENTRY_READ_STATE_CHANGE,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local guideLimitedCtrl = require_ex('UI/Panels/GuideLimited/GuideLimitedCtrl')
            return not string.isEmpty(guideLimitedCtrl.GuideLimitedCtrl.s_waitReadGuideWikiEntry), UIConst.RED_DOT_TYPE.Normal
        end
    },
    

    
    Friend = {
        sons = {
            NewFriendRequest = true,
        },
        readLike = false,
    },

    NewFriendRequest = {
        msgs = {
            MessageConst.ON_FRIEND_REQUEST_CHANGE,
        },
        readLike = false,
        needArg = false,
        Check = function()
            return GameInstance.player.friendSystem:NeedFriendRequestRedDot(), UIConst.RED_DOT_TYPE.Normal
        end
    },

    FriendChatUnRead = {
        Check = function()
            local chatPanelShow = false
            local res, ctrl = UIManager:IsOpen(PanelId.SNSFriend)
            if res then
                chatPanelShow = ctrl:IsShow()
            end

            for index, roleId in pairs(GameInstance.player.friendChatSystem.luaShowValidRoleIds) do
                if GameInstance.player.friendChatSystem.luaShowRoleId ~= roleId or not chatPanelShow then
                    local chatInfo = GameInstance.player.friendChatSystem:GetChatInfo(roleId)
                    if chatInfo then
                        if chatInfo.unReadNum > 0 then
                            return true, UIConst.RED_DOT_TYPE.Normal
                        end
                    end
                end
            end
            return false
        end,
        needArg = false,
        readLike = false,
        msgs = {
            MessageConst.FRIEND_CHAT_MSG_READ,
        },
    },

    NewBusinessCard = {
        msgs = {
            MessageConst.ON_BUSINESS_CARD_UNLOCK,
            MessageConst.ON_BUSINESS_CARD_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return GameInstance.player.friendSystem:IsBusinessCardUnlock(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.BusinessCardTopic, id) and
                not GameInstance.player.friendSystem:IsBusinessCardReadRedDot(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.BusinessCardTopic, id), UIConst.RED_DOT_TYPE.Normal
        end
    },

    NewAvatar = {
        msgs = {
            MessageConst.ON_AVATAR_UNLOCK,
            MessageConst.ON_AVATAR_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return GameInstance.player.friendSystem:IsBusinessCardUnlock(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.Avatar, id) and
                not GameInstance.player.friendSystem:IsBusinessCardReadRedDot(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.Avatar, id), UIConst.RED_DOT_TYPE.Normal
        end
    },

    NewAvatarFrame = {
        msgs = {
            MessageConst.ON_AVATAR_FRAME_UNLOCK,
            MessageConst.ON_AVATAR_FRAME_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return GameInstance.player.friendSystem:IsBusinessCardUnlock(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.AvatarFrame, id) and
                not GameInstance.player.friendSystem:IsBusinessCardReadRedDot(CS.Beyond.Gameplay.FriendBusinessCardUnlockType.AvatarFrame, id), UIConst.RED_DOT_TYPE.Normal
        end
    },

    BusinessCard = {
        sons = {
            NewBusinessCard = true,
            NewAvatar = true,
            NewAvatarFrame = true,
        },
        readLike = false,
    },

    NewAvatarInfo = {
        sons = {
            NewAvatar = true,
            NewAvatarFrame = true,
        },
        readLike = false,
    },

    

    

    
    SettlementMainTab = {
        msgs = {
            MessageConst.ON_SETTLEMENT_MODIFY,
        },
        readLike = false,
        needArg = true,
        Check = function(arg)
            local stlId
            if type(arg) == "string" then
                stlId = arg
            else
                stlId = unpack(arg)
            end
            return RedDotUtils.hasSettlementCanUpgradeRedDot(stlId), UIConst.RED_DOT_TYPE.Normal
        end,
    },
    

    
    
    DomainGradeReward = {
        msgs = {
            MessageConst.ON_DOMAIN_DEVELOPMENT_EXP_CHANGE,
            MessageConst.ON_DOMAIN_DEVELOPMENT_LEVEL_REWARD_GET,
        },
        readLike = false,
        needArg = true,
        Check = function(domainId)
            return RedDotUtils.hasSingleDomainGradeRedDot(domainId)
        end,
    },
    
    DomainSingleMap = {
        msgs = {
            MessageConst.ON_SETTLEMENT_MODIFY,
            MessageConst.ON_PACK_ITEM_END,
            MessageConst.ON_SELECT_BUYER_END,
            MessageConst.ON_DOMAIN_DEVELOPMENT_EXP_CHANGE,
            MessageConst.ON_DOMAIN_DEVELOPMENT_LEVEL_REWARD_GET,
        },
        readLike = false,
        needArg = true,
        Check = function(domainId)
            return RedDotUtils.hasSingleDomainDevelopmentRedDot(domainId)
        end,
    },
    
    DomainOtherMap = {
        msgs = {
            MessageConst.ON_SETTLEMENT_MODIFY,
            MessageConst.ON_PACK_ITEM_END,
            MessageConst.ON_SELECT_BUYER_END,
            MessageConst.ON_DOMAIN_DEVELOPMENT_EXP_CHANGE,
            MessageConst.ON_DOMAIN_DEVELOPMENT_LEVEL_REWARD_GET,
            MessageConst.ON_DOMAIN_DEPOT_DELIVERY_REWARD,
        },
        readLike = false,
        needArg = true,
        Check = function(domainId)
            for checkDomainId, _ in cs_pairs(GameInstance.player.domainDevelopmentSystem.domainDevDataDic) do
                if checkDomainId ~= domainId and RedDotUtils.hasSingleDomainDevelopmentRedDot(checkDomainId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
    },
    
    DomainEntry = {
        msgs = {
            MessageConst.ON_SETTLEMENT_MODIFY,
            MessageConst.ON_PACK_ITEM_END,
            MessageConst.ON_SELECT_BUYER_END,
            MessageConst.ON_DOMAIN_DEVELOPMENT_EXP_CHANGE,
            MessageConst.ON_DOMAIN_DEVELOPMENT_LEVEL_REWARD_GET,
            MessageConst.ON_KITE_STATION_COLLECTION_REWARD,
        },
        sons = {
        },
        readLike = false,
        needArg = false,
        Check = function()
            for checkDomainId, _ in cs_pairs(GameInstance.player.domainDevelopmentSystem.domainDevDataDic) do
                if RedDotUtils.hasSingleDomainDevelopmentRedDot(checkDomainId) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
    },
    

    KiteStationCollectionReward = {
        msgs = {
            MessageConst.ON_KITE_STATION_COLLECTION_REWARD
        },
        readLike = false,
        needArg = true,
        Check = function(stationId)
            return GameInstance.player.kiteStationSystem:CheckKiteStationCollectionReward(stationId), UIConst.RED_DOT_TYPE.Normal
        end,
    },

    

    
    AchievementMain = {
        readLike = false,
        needArg = false,
        Check = function()
            for _, achievementData in pairs(Tables.achievementTable) do
                if achievementData ~= nil and GameInstance.player.achievementSystem:IsAchievementUnread(achievementData.achieveId) then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end,
        sons = {
            AchievementGroup = false,
        },
    },
    AchievementCategory = {
        readLike = false,
        needArg = true,
        Check = function(categoryId)
            local suc, categoryData = Tables.achievementTypeTable:TryGetValue(categoryId)
            if not suc then
                return false
            end
            for _, achievementData in pairs(Tables.achievementTable) do
                if achievementData ~= nil then
                    for i, groupData in pairs(categoryData.achievementGroupData) do
                        if achievementData.groupId == groupData.groupId
                            and GameInstance.player.achievementSystem:IsAchievementUnread(achievementData.achieveId) then
                            return true, UIConst.RED_DOT_TYPE.New
                        end
                    end
                end
            end
            return false
        end,
        sons = {
            AchievementItem = false,
        },
    },
    AchievementGroup = {
        readLike = false,
        needArg = true,
        Check = function(groupId)
            for _, achievementData in pairs(Tables.achievementTable) do
                if achievementData ~= nil then
                    if achievementData.groupId == groupId
                        and GameInstance.player.achievementSystem:IsAchievementUnread(achievementData.achieveId) then
                        return true, UIConst.RED_DOT_TYPE.New
                    end
                end
            end
            return false
        end,
        sons = {
            AchievementItem = false,
        },
    },
    AchievementItem = {
        msgs = {
            MessageConst.ON_UNREAD_ACHIEVEMENT,
            MessageConst.ON_READ_ACHIEVEMENT,
        },
        readLike = true,
        needArg = true,
        Check = function(achievementId)
            return GameInstance.player.achievementSystem:IsAchievementUnread(achievementId), UIConst.RED_DOT_TYPE.New
        end,
    },
    

    
    WeekRaid = {
        sons = {
            WeekRaidBattlePass = true,
            WeekRaidDelegate = false,
        },
        readLike = false,
    },
    WeekRaidBattlePass = {
        msgs = {
            MessageConst.ON_WEEK_RAID_BATTLE_PASS_UPDATE,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local isAnyReceivable = GameInstance.player.weekRaidSystem:IsAnyBattlePassRewardReceivable()
            return isAnyReceivable, UIConst.RED_DOT_TYPE.Normal
        end,
    },
    WeekRaidBattlePassRefresh = {
        msgs = {
            MessageConst.ON_WEEK_RAID_BATTLE_PASS_UPDATE,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local mapMarkInstIds = GameInstance.player.weekRaidSystem:GetWeekRaidEntryMapMarkInstIds()
            if mapMarkInstIds.Count == 0 then
                return false
            end
            local isAnyReceivable = GameInstance.player.weekRaidSystem:IsAnyBattlePassRewardReceivable()
            if not isAnyReceivable then
                return false
            end
            local nextRefreshTime = Utils.getNextWeeklyServerRefreshTime()
            local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
            local deltaTime = nextRefreshTime - currentTime
            local notify = deltaTime <= Tables.weekRaidConst.weekRaidBattlePassRefreshMapRemindTime
            return notify, UIConst.RED_DOT_TYPE.Normal
        end,
    },
    WeekRaidDelegate = {
        msgs = {
            MessageConst.ON_QUEST_STATE_CHANGE,
            MessageConst.ON_QUEST_OBJECTIVE_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            
            if args == nil then
                local isAnyCompleted = GameInstance.player.weekRaidSystem:IsAnyMissionCompleted()
                return isAnyCompleted, UIConst.RED_DOT_TYPE.Normal
            end

            
            
            if args and args.missionId ~= nil then
                local isCompleted = GameInstance.player.weekRaidSystem:IsMissionCompleted(args.missionId)
                if isCompleted then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
                

                return false
            end

            
            if args and args.missionType ~= nil then
                local delegateList = WeeklyRaidUtils.TabConfig[args.missionType].getDelegate()
                local isAnyCompleted = GameInstance.player.weekRaidSystem:IsAnyMissionCompleted(delegateList)
                return isAnyCompleted, UIConst.RED_DOT_TYPE.Normal
            end

            return false, UIConst.RED_DOT_TYPE.Normal
        end,
    },
    

    
    ActivityCenter = {
        msgs = {
            MessageConst.ON_ACTIVITY_CENTER_CLOSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local activities = GameInstance.player.activitySystem:GetAllActivities()
            for _, activity in cs_pairs(activities) do
                
                local redDotName = ActivityUtils.getActivityRedDotName(activity.id)
                if redDotName and RedDotManager:GetRedDotState(redDotName, activity.id) then
                    return true
                end
            end
            return false
        end,
        sons = ActivityConst.ACTIVITY_COMMON_SONS,
    },
    ActivityTableMore = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(moreActivityData)
            for i = 1, #moreActivityData do
                local activityData = moreActivityData[i]
                if not activityData then
                    return false
                end
                local redDotName = ActivityUtils.getActivityRedDotName(activityData.id)
                if redDotName and RedDotManager:GetRedDotState(redDotName, activityData.id) then
                    return true
                end
            end
            return false
        end,
        sons = ActivityConst.ACTIVITY_COMMON_SONS,
    },
    ActivityIntroMission = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = true,
        needArg = true,
        Check = function(id)
            return ActivityUtils.isNewIntroMissionActivity(id)
        end,
    },
    ActivityBasic = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return ActivityUtils.checkActivityRedDot(id)
        end
    },
    ActivityBaseMultiStage = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_LEVEL_REWARD_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return RedDotUtils.hasActivityBaseMultiStageRedDot(id)
        end
    },
    ActivityGachaBeginner = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED,
            MessageConst.ON_LEVEL_REWARD_UPDATE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            return RedDotUtils.hasActivityGachaBeginnerRedDot(id)
        end
    },
    ActivityGachaBeginnerJumpPoolBtn = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_GACHA_POOL_ROLE_DATA_CHANGED,
            MessageConst.ON_LEVEL_REWARD_UPDATE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            if RedDotUtils.hasGachaBeginnerTicketNotUesRedDot() then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return RedDotUtils.hasGachaStarterCumulateRedDot(Tables.charGachaConst.beginnerGachaActivityPoolId)
        end
    },
    ActivityBaseMultiStageReward = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_LEVEL_REWARD_UPDATE,
        },
        readLike = true,
        needArg = true,
        Check = function(canReceive)
            return canReceive
        end
    },
    ActivityGuideWulingStage = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_READ_ACTIVITY_CONDITION_STAGE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = true,
        needArg = true,
        Check = function(args)
            local activityId, stageId = unpack(args)
            
            local newConditionalStageText = "new_activity_conditional_stage_key_"
            local success, isNew = ClientDataManagerInst:GetBool(newConditionalStageText .. stageId, false)
            if not success or isNew then
                ClientDataManagerInst:SetBool(newConditionalStageText .. stageId, false, false, EClientDataTimeValidType.Permanent)
                return true, UIConst.RED_DOT_TYPE.New
            end

            
            local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
            if not activityData then
                return false
            end
            local suc, stageData = activityData.stageDataDict:TryGetValue(stageId)

            
            
            if suc and stageData.Status == 2 then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },
    ActivityCheckIn = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_CHECK_IN,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            local activity = GameInstance.player.activitySystem:GetActivity(id)
            if activity and activity.loginDays ~= activity.rewardDays.Count then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return ActivityUtils.checkActivityRedDot(id)
        end
    },
    ActivityCheckInReward = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_CHECK_IN,
        },
        readLike = true,
        needArg = true,
        Check = function(canReceive)
            return canReceive
        end
    },
    ActivityGlobalEffect = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_ACTIVITY_NEW_DAY,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            local suc,type = ActivityUtils.checkActivityRedDot(id)
            if suc then
                return suc, type
            elseif ActivityUtils.isNewActivityDay(id) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },
    ActivityNormalChallenge = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_READ_GAME_ENTRANCE_SERIES,
            MessageConst.ON_SUB_GAME_READ,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        sons = {
            ActivityNormalChallengeSeries = false,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            
            
            local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
            if not activityData then
                return false
            end
            
            if ActivityUtils.hasIntroMissionAndComplete(activityId) then
                local _, activitySeriesCfg = Tables.activityGameEntranceSeriesTable:TryGetValue(activityId)
                for seriesId, seriesCfg in pairs(activitySeriesCfg.seriesMap) do
                    local hasRedDot = RedDotUtils.hasActivityNormalChallengeSeriesRedDot(seriesId)
                    if hasRedDot then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    ActivityNormalChallengeSeries = {
        msgs = {
            MessageConst.ON_READ_GAME_ENTRANCE_SERIES,
            MessageConst.ON_SUB_GAME_READ,
        },
        readLike = false,
        needArg = true,
        Check = function(seriesId)
            return RedDotUtils.hasActivityNormalChallengeSeriesRedDot(seriesId)
        end
    },
    ActivityNormalChallengeGotoDetailBtn = {
        msgs = {
            MessageConst.ON_READ_GAME_ENTRANCE_SERIES,
            MessageConst.ON_SUB_GAME_READ,
        },
        sons = {
            ActivityNormalChallengeSeries = false,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            
            
            local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
            if not activityData or not activityData.isUnlocked then
                return false
            end
            
            local _, activitySeriesCfg = Tables.activityGameEntranceSeriesTable:TryGetValue(activityId)
            for seriesId, seriesCfg in pairs(activitySeriesCfg.seriesMap) do
                local hasRedDot = RedDotUtils.hasActivityNormalChallengeSeriesRedDot(seriesId)
                if hasRedDot then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            
            return false
        end
    },
    ActivityCharacterGuideLine = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        sons = {
            ActivityCharacterGuideLineBtnDetail = true,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    ActivityCharacterGuideLineBtnDetail = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            return ActivityUtils.isNewUnlockCharacterGuideLine(activityId)
        end
    },
    ActivityCharTrial = {
        msgs = {
            MessageConst.ON_CHARACTER_TRIAL_INFO_CHANGE,
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = true,
        needArg = true,
        Check = function(activityId)
            local activityData = GameInstance.player.activitySystem:GetActivity(activityId)
            if not activityData or not activityData.isUnlocked then
                return false
            end

            for dungeonId, trialData in pairs(Tables.activityCharTrial) do
                if trialData.activityId == activityId then
                    local trialStatus = GameInstance.player.activitySystem:CheckCharacterTrial(activityId, dungeonId)
                    if trialStatus == CS.Beyond.Gameplay.ActivitySystem.CharacterTrialStatus.CanGetReward then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    ActivityCharTrialGetReward = {
        Check = function(args)
            local trialStatus = GameInstance.player.activitySystem:CheckCharacterTrial(args.activityId, args.dungeonId)
            if trialStatus == CS.Beyond.Gameplay.ActivitySystem.CharacterTrialStatus.CanGetReward then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,

        readLike = true,
        needArg = true,

        msgs = {
            MessageConst.ON_CHARACTER_TRIAL_INFO_CHANGE,
        },
    },
    ActivityHighDifficulty = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_HIGH_DIFFICULTY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
            MessageConst.ACTIVITY_HIGH_DIFFICULTY_NEW_TASK_SET_FALSE,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            local activity = GameInstance.player.activitySystem:GetActivity(id)
            if not activity then
                return false
            end
            
            if GameInstance.player.highDifficultySystem:IsHighDifficultyUnlocked() and ActivityUtils.hasIntroMissionAndComplete(id) then
                local seriesIds = GameInstance.player.highDifficultySystem:GetAllUnlockSeriesIds()
                for i = 1,seriesIds.Count do
                    local seriesId = seriesIds[CSIndex(i)]
                    if HighDifficultyUtils.isNewHighDifficultySeries(seriesId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            
            for stageId, stageData in pairs(activity.stageDataDict) do
                local unlocked = stageData.Status ~= GEnums.ActivityConditionalStageState.Locked:GetHashCode()
                if unlocked and RedDotManager:GetRedDotState("ActivityHighDifficultyTask", {id, stageId}) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return ActivityUtils.checkActivityRedDot(id)
        end
    },
    ActivityHighDifficultyDetailBtn = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_HIGH_DIFFICULTY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            
            if GameInstance.player.highDifficultySystem:IsHighDifficultyUnlocked() and ActivityUtils.hasIntroMissionAndComplete(id) then
                local seriesIds = GameInstance.player.highDifficultySystem:GetAllUnlockSeriesIds()
                for i = 1,seriesIds.Count do
                    local seriesId = seriesIds[CSIndex(i)]
                    if HighDifficultyUtils.isNewHighDifficultySeries(seriesId) then
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return false
        end
    },
    ActivityHighDifficultyTask = {
        msgs = {
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local activityId, stageId = unpack(args)
            
            local activity = GameInstance.player.activitySystem:GetActivity(activityId)
            for id, stageData in cs_pairs(activity.stageDataDict) do
                if id == stageId and stageData.Status == GEnums.ActivityConditionalStageState.Completed:GetHashCode() then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end

            
            if HighDifficultyUtils.isNewHighDifficultyTask(activityId, stageId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end
    },
    ActivityHighDifficultyTaskSeries = {
        msgs = {
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
            MessageConst.ACTIVITY_HIGH_DIFFICULTY_NEW_TASK_SET_FALSE,
        },
        readLike = false,
        needArg = true,
        Check = function(args)
            local activityId = args[1]
            local tasks = args[2]
            for _,stageData in ipairs(tasks) do
                if RedDotManager:GetRedDotState("ActivityHighDifficultyTask", {activityId, stageData.stageId}) then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end
    },
    HighDifficultyMainHudGotoBtn = {
        msgs = {
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local activityId = HighDifficultyUtils.getHighDifficultyActivityId()
            
            local activity = GameInstance.player.activitySystem:GetActivity(activityId)
            for stageId,_ in pairs(activity.stageDataDict) do
                local value, typ = RedDotManager:GetRedDotState("ActivityHighDifficultyTask", {activityId, stageId})
                if value and typ == UIConst.RED_DOT_TYPE.Normal then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end
    },
    HighDifficultyMainHudCell = {
        msgs = {
            MessageConst.ON_HIGH_DIFFICULTY_NEW_RED_DOT_SET_FALSE,
        },
        readLike = true,
        needArg = true,
        Check = function(seriesId)
            if HighDifficultyUtils.isNewHighDifficultySeries(seriesId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end
    },
    ActivityConditionalMultiStage = {
        msgs = {
            MessageConst.ON_READ_ACTIVITY_CONDITION_STAGE,
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            
            local activityData = GameInstance.player.activitySystem:GetActivity(id)
            if not activityData then
                return false
            end
            
            if activityData.status == GEnums.ActivityStatus.InProgress then
                
                for stageId, stageData in cs_pairs(activityData.stageDataDict) do
                    local status = GEnums.ActivityConditionalStageState.__CastFrom(stageData.Status)
                    if status == GEnums.ActivityConditionalStageState.Completed then
                        
                        return true, UIConst.RED_DOT_TYPE.Normal
                    elseif status == GEnums.ActivityConditionalStageState.Unlocked
                        and ActivityUtils.isNewActivityConditionalStage(stageId) then
                        
                        return true, UIConst.RED_DOT_TYPE.Normal
                    end
                end
            end
            return ActivityUtils.checkActivityRedDot(id)
        end
    },
    ActivityDaily = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_ACTIVITY_NEW_DAY,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            local activity = GameInstance.player.activitySystem:GetActivity(id)
            if not activity then
                return false
            end
            local suc,type = ActivityUtils.checkActivityRedDot(id)
            if suc then
                return suc, type
            elseif ActivityUtils.isNewActivityDay(activity.id, Tables.activityConst.WebReflowRedDotDays) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },
    ActivitySpringFest = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_ACTIVITY_NEW_DAY,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            local suc,type = ActivityUtils.checkActivityRedDot(id)
            if suc then
                return suc, type
            elseif ActivityUtils.isNewActivityDay(id,Tables.activityConst.SpringFestivalRedDotDays) then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end
    },
    ActivityItemSubmission = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            

            
            return ActivityUtils.checkActivityRedDot(id)
        end
    },
    ActivityVersionGuide = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            
            local activityData = Tables.ActivityVersionGuideStageTable[id]
            if not activityData then
                return false
            end

            local hasNormal = false
            local hasNew = false

            
            local stageListCount = activityData.stageList.Count
            for i = 1, stageListCount do
                local stageData = activityData.stageList[CSIndex(i)]
                local stageId = stageData.stageId
                local hasRedDot, redDotType = RedDotManager:GetRedDotState("ActivityGuideWulingStage", { id, stageId })

                if hasRedDot then
                    if redDotType == UIConst.RED_DOT_TYPE.Normal then
                        hasNormal = true
                    elseif redDotType == UIConst.RED_DOT_TYPE.New then
                        hasNew = true
                    end
                end
            end

            local defHas, defType = ActivityUtils.checkActivityRedDot(id)
            if defHas then
                if defType == UIConst.RED_DOT_TYPE.Normal then
                    hasNormal = true
                elseif defType == UIConst.RED_DOT_TYPE.New then
                    hasNew = true
                end
            end

            
            if hasNormal then
                return true, UIConst.RED_DOT_TYPE.Normal
            elseif hasNew then
                return true, UIConst.RED_DOT_TYPE.New
            end

            return false
        end
    },
    ActivityRandomReward = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(id)
            

            
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    ActivityRewardOverview = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    ActivityWeeklyTask = {
        msgs = {
            MessageConst.ON_ACTIVITY_NEW_RED_DOT_SET_FALSE,
            MessageConst.ON_ACTIVITY_UPDATED,
            MessageConst.ON_CONDITIONAL_MULTI_STAGE_UPDATE,
        },
        readLike = false,
        needArg = true,
        Check = function(activityId)
            local activity = GameInstance.player.activitySystem:GetActivity(activityId)
            local maxScore = 0
            for mileStoneId, received in pairs(activity.mileStoneInfo) do
                local success, info = Tables.activityWeeklyTaskMileStoneTable[activityId].mileStones:TryGetValue(mileStoneId)
                if success and activity.score >= info.score and not received then
                    return true
                end
                maxScore = math.max(maxScore, info.score)
            end

            if activity.score < maxScore then
                for _, task in pairs(activity.taskInfo) do
                    if task.Item1 == GEnums.ActivityConditionalStageState.Completed:GetHashCode() then
                        return true
                    end
                end
            end
            
            return ActivityUtils.checkActivityRedDot(activityId)
        end
    },
    
    

    
    DomainDepot = {
        readLike = false,
        needArg = true,
        Check = function(domainId)
            if RedDotManager:GetRedDotState("DomainDepotInstList", domainId) then
                return true
            end
            if RedDotManager:GetRedDotState("DomainDepotMyOrder") then
                return true
            end
            return false
        end,
        sons = {
            DomainDepotInstList = false,
            DomainDepotMyOrder = false,
        }
    },
    DomainDepotInstList = {
        readLike = false,
        needArg = true,
        Check = function(domainId)
            local allDepotIdList = GameInstance.player.domainDepotSystem:GetDomainDepotIdListByDomainId(domainId)
            if allDepotIdList == nil then
                return false
            end
            for index = 0, allDepotIdList.Count - 1 do
                local depotId = allDepotIdList[index]
                if DomainDepotUtils.IsDomainDepotDeliverInTradingState(depotId) then
                    return true
                end
            end
            return false
        end,
        sons = {
            DomainDepotInstCell = false,
        }
    },
    DomainDepotInstCell = {
        readLike = false,
        needArg = true,
        msgs = {
            MessageConst.ON_PACK_ITEM_END,
            MessageConst.ON_SELECT_BUYER_END,
        },
        Check = function(depotId)
            return DomainDepotUtils.IsDomainDepotDeliverInTradingState(depotId)
        end
    },
    DomainDepotMyOrder = {
        msgs = {
            MessageConst.ON_DOMAIN_DEPOT_DELIVERY_REWARD
        },
        readLike = false,
        needArg = false,
        Check = function()
            for _, info in cs_pairs(GameInstance.player.domainDepotSystem.myDelegateDeliverList) do
                if info.packageProgress == GEnums.DomainDepotPackageProgress.SendPackageTimeout or
                    info.packageProgress == GEnums.DomainDepotPackageProgress.WaitingRecvFinalPayment then
                    return true
                end
            end
            return false
        end
    },
    

    
    BattlePass = {
        readLike = false,
        msgs = {
            MessageConst.ON_DOMAIN_DEPOT_DELIVERY_REWARD
        },
        needArg = false,
        Check = function()
            if not BattlePassUtils.CheckBattlePassSeasonValid() then
                return false
            end
            local bpSystem = GameInstance.player.battlePassSystem
            local seasonRedDot = bpSystem:IsSeasonUnread(bpSystem.seasonData.seasonId)
            if seasonRedDot then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            local planRedDot = BattlePassUtils.CheckHasAvailBpPlanReward()
            local taskRedDot = false
            for labelId, labelInfo in pairs(bpSystem.taskData.taskLabels) do
                local hasRedDot = BattlePassUtils.CheckLabelRedDot(labelId)
                if hasRedDot then
                    taskRedDot = true
                    break
                end
            end
            if planRedDot or taskRedDot then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
        sons = {
            BattlePassPlan = false,
            BattlePassTask = false,
        }
    },
    BattlePassPlan = {
        readLike = false,
        msgs = {
            MessageConst.ON_BATTLE_PASS_LEVEL_UPDATE,
            MessageConst.ON_BATTLE_PASS_TRACK_UPDATE,
        },
        needArg = false,
        Check = function()
            if BattlePassUtils.CheckHasAvailBpPlanReward() then
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
    },
    BattlePassTask = {
        readLike = false,
        msgs = {
        },
        needArg = false,
        Check = function()
            local bpSystem = GameInstance.player.battlePassSystem
            for labelId, labelInfo in pairs(bpSystem.taskData.taskLabels) do
                local hasLabelRedDot, labelRedDotType = BattlePassUtils.CheckLabelRedDot(labelId)
                if hasLabelRedDot then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end,
        sons = {
            BattlePassTaskLabel = false
        }
    },
    BattlePassTaskLabel = {
        readLike = false,
        msgs = {
        },
        needArg = true,
        Check = function(labelId)
            return BattlePassUtils.CheckLabelRedDot(labelId)
        end,
        sons = {
            BattlePassTaskItem = false,
        }
    },
    BattlePassTaskItem = {
        readLike = false,
        msgs = {
            MessageConst.ON_BATTLE_PASS_TASK_UPDATE,
            MessageConst.ON_BATTLE_PASS_TASK_BASIC_INFO_UPDATE,
            MessageConst.ON_BATTLE_PASS_TASK_READ_UPDATE,
        },
        needArg = true,
        Check = function(taskId)
            if BattlePassUtils.CheckTaskUnread(taskId) then
                return true, UIConst.RED_DOT_TYPE.New
            end
            return false
        end
    },
    

    

    CashShop = {
        readLike = false,
        needArg = false,
        sons = {
            CashShopCreditShopGetCredit = true,
        },
    },

    CashShopNewCashGoods = {
        readLike = false,
        msgs = {
            MessageConst.ON_READ_CASH_SHOP_GOODS,
        },
        needArg = true,
        Check = function(goodsIds)
            return CashShopUtils.CheckCashShopNewCashGoodsRedDot(goodsIds)
        end
    },

    CashShopToken = {
        readLike = false,
        msgs = {
            MessageConst.ON_SHOP_GOODS_SEE_GOODS_INFO_CHANGE,
        },
        needArg = true,
        Check = function(goodsIds)
            for _, goodsId in ipairs(goodsIds) do
                local isNew = GameInstance.player.shopSystem:IsNewGoodsId(goodsId)
                if isNew then
                    return true, UIConst.RED_DOT_TYPE.New
                end
            end
            return false
        end
    },

    CashShopTokenNormal = {
        readLike = false,
        msgs = {
            MessageConst.ON_SHOP_GOODS_SEE_GOODS_INFO_CHANGE,
        },
        needArg = true,
        Check = function(goodsIds)
            for _, goodsId in ipairs(goodsIds) do
                local isNew = GameInstance.player.shopSystem:IsNewGoodsId(goodsId)
                if isNew then
                    return true
                end
            end
            return false
        end
    },

    CashShopCreditShopGetCredit = {
        readLike = false,
        msgs = {
            MessageConst.ON_SPACESHIP_GUEST_ROOM_RECV_VISIT_LIST_REWARD,
            MessageConst.ON_SPACESHIP_RECV_QUERY_VISIT_INFO,
        },
        needArg = false,
        Check = function()
            return CashShopUtils.CheckSpaceshipCreditShopGetCreditRedDot()
        end
    },

    

    
    SSControlCenter = {
        readLike = false,
        msgs = {
            MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY,
            MessageConst.ON_SPACESHIP_GROW_CABIN_MODIFY,
            MessageConst.ON_SPACESHIP_GROW_CABIN_BREED,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_SYNC,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_COLLECT,
            MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION,
            MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE,
        },
        needArg = true,
        Check = function()
            local rooms = GameInstance.player.spaceship.rooms
            local beHelpedCreditLeft, _ = GameInstance.player.spaceship:GetCabinAssistedTime(Tables.spaceshipConst.controlCenterRoomId)
            for id, roomInfo in pairs(rooms) do
                if roomInfo.type == GEnums.SpaceshipRoomType.GrowCabin then
                    if RedDotManager:GetRedDotState("SSGrowCabin", id) then
                        return true
                    end
                elseif roomInfo.type == GEnums.SpaceshipRoomType.ManufacturingStation then
                    if RedDotManager:GetRedDotState("SSManufacturingStation", id) then
                        return true
                    end
                elseif roomInfo.type == GEnums.SpaceshipRoomType.GuestRoomClueExtension then
                    if RedDotManager:GetRedDotState("SSGuestRoomClue") then
                        return true
                    end
                elseif beHelpedCreditLeft > 0 then
                    return true
                end
            end
            return false
        end,
        sons = {
            SSGrowCabin = false,
            SSManufacturingStation = false,
            SSGuestRoomClue = false,
        }
    },


    SSControlCenterRoot = {
        readLike = false,
        msgs = {
            MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY,
            MessageConst.ON_SPACESHIP_GROW_CABIN_MODIFY,
            MessageConst.ON_SPACESHIP_GROW_CABIN_BREED,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_SYNC,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_COLLECT,
            MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION,
            MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE,
        },
        needArg = true,
        Check = function(roomIndex)
            local state = true
            for id, index in pairs(roomIndex) do
                local succ, roomInfo = GameInstance.player.spaceship:TryGetRoom(id)
                if succ then
                    if roomInfo.type == GEnums.SpaceshipRoomType.GrowCabin then
                        if not RedDotManager:GetRedDotState("SSGrowCabin", id) then
                            return false
                        end
                    elseif roomInfo.type == GEnums.SpaceshipRoomType.ManufacturingStation then
                        if not RedDotManager:GetRedDotState("SSManufacturingStation", id) then
                            return false
                        end
                    elseif roomInfo.type == GEnums.SpaceshipRoomType.GuestRoomClueExtension then
                        if not RedDotManager:GetRedDotState("SSGuestRoomClue") then
                            return false
                        end
                    end
                end
            end
            return state
        end,
        sons = {
            SSGrowCabin = false,
            SSManufacturingStation = false,
            SSGuestRoomClue = false,
        }
    },

    SSGrowCabin = {
        readLike = false,
        needArg = true,
        Check = function(roomId)
            return GameInstance.player.spaceship:HasGrowCabinProduct(roomId)
        end,
        msgs = {
            MessageConst.ON_SPACESHIP_GROW_CABIN_MODIFY,
            MessageConst.ON_SPACESHIP_GROW_CABIN_BREED,
        },
    },

    SSManufacturingStation = {
        readLike = false,
        needArg = true,
        Check = function(roomId)
            local beHelpedCreditLeft, _ = GameInstance.player.spaceship:GetCabinAssistedTime(roomId)
            local hasProduct = GameInstance.player.spaceship:HasProductToCollect(roomId)
            return hasProduct or beHelpedCreditLeft > 0
        end,
        msgs = {
            MessageConst.ON_SPACESHIP_ASSIST_DATA_MODIFY,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_SYNC,
            MessageConst.ON_SPACESHIP_MANUFACTURING_STATION_COLLECT,
        },
    },

    SSGuestRoomClue = {
        readLike = false,
        needArg = true,
        Check = function()
            local spaceship = GameInstance.player.spaceship
            local clueData = GameInstance.player.spaceship:GetClueData()
            return spaceship:IsGuestRoomClueCannotAutoRecv()
                or spaceship:HasGuestRoomClueCanCollect()
                or spaceship:IsGuestRoomClueWaitForExchange()
                or (clueData and clueData.dailyClueIndex ~= 0)
        end,
        msgs = {
            MessageConst.SPACESHIP_ON_SYNC_ROOM_STATION,
            MessageConst.ON_SPACESHIP_CLUE_INFO_CHANGE,
        },
    },
    

    
    ValuableDepotInMainHud = {
        msgs = {
            MessageConst.ON_VALUABLE_DEPOT_CHANGED,
            MessageConst.ON_ITEM_LOCKED_STATE_CHANGED,
            MessageConst.ON_VALUABLE_DEPOT_IMPORT_ITEM_CHANGED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            local hasRedDot, redDotType = RedDotManager:GetRedDotState("ValuableDepot")
            if hasRedDot and redDotType == UIConst.RED_DOT_TYPE.Normal then
                
                return true, UIConst.RED_DOT_TYPE.Normal
            end
            return false
        end,
    },

    ValuableDepot = {
        msgs = {},
        readLike = false,
        needArg = false,
        sons = {
            ValuableDepotTabCommercialItem = true,
        },
        Check = function()
            local types = GameInstance.player.inventory:GetValuableDepotTypes()
            for i = 1, types.Count do
                local suc, value = RedDotManager:GetRedDotState("ValuableDepotTabCommon", types[CSIndex(i)])
                if suc and value then
                    return true, UIConst.RED_DOT_TYPE.Normal
                end
            end
            return false
        end
    },

    ValuableDepotTabCommon = {
        msgs = {
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_VALUABLE_DEPOT_IMPORT_ITEM_CHANGED,
        },
        readLike = false,
        needArg = true,
        Check = function(type)
            return RedDotUtils.isValuableDepotTabHasNewObtainedImportantItem(type)
        end,
    },

    ValuableDepotTabCommercialItem = {
        msgs = {
            MessageConst.ON_VALUABLE_DEPOT_CHANGED,
            MessageConst.ON_ITEM_LOCKED_STATE_CHANGED,
            MessageConst.ON_ITEM_COUNT_CHANGED,
            MessageConst.ON_VALUABLE_DEPOT_IMPORT_ITEM_CHANGED,
        },
        readLike = false,
        needArg = false,
        Check = function()
            return RedDotUtils.hasValuableDepotTabCommercialItemRedDot()
        end,
    },
    

    
    
    GameSettingAccount = {
        sons = {
            GameSettingAccountCustomerService = true,
        },
        readLike = false,
    },
    
    GameSettingAccountCustomerService = {
        msgs = {
            MessageConst.ON_QUERY_UNREAD_MSG,
        },
        readLike = false,
        needArg = false,
        Check = function()
            return CS.Beyond.Gameplay.AnnouncementSystem.HasUnreadMsg()
        end
    },
    
}

return Config
