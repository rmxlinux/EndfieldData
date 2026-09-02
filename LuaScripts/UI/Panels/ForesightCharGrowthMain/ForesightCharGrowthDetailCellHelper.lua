





local CellHelper = {}

local s_btnHintInteractableCache = setmetatable({}, { __mode = "k" })

local function _ensureBtnInteractableForHint(btn)
    if s_btnHintInteractableCache[btn] == nil then
        s_btnHintInteractableCache[btn] = btn.interactable
    end
    btn.interactable = true
end

local function _restoreBtnInteractableFromHint(btn)
    local cached = s_btnHintInteractableCache[btn]
    if cached == nil then
        return
    end
    btn.interactable = cached
    s_btnHintInteractableCache[btn] = nil
end

function CellHelper.SetUiText(txt, value)
    if not txt then
        return
    end
    value = value or ""
    if txt.text ~= nil then
        txt.text = value
    elseif txt.SetText then
        txt:SetText(value)
    end
end

function CellHelper.SetNodeActive(node, visible)
    if not node or not node.gameObject then
        return
    end
    node.gameObject:SetActive(visible == true)
end

function CellHelper.SetBindingTextIfChanged(bindingId, text)
    if not bindingId or bindingId <= 0 or string.isEmpty(text) then
        return
    end
    
    if InputManagerInst:GetBindingText(bindingId) ~= text then
        InputManagerInst:SetBindingText(bindingId, text)
    end
end

function CellHelper.BindClick(btn, bind, handler, hintText)
    if not btn or not btn.onClick then
        return
    end
    btn.onClick:RemoveAllListeners()
    if bind and handler then
        btn.onClick:AddListener(handler)
        if hintText and btn.onClick.bindingId and btn.onClick.bindingId > 0 then
            CellHelper.SetBindingTextIfChanged(btn.onClick.bindingId, hintText)
        end
    end
end

function CellHelper.ToggleBtnBinding(btn, enabled, hintText)
    if not btn or not btn.onClick or not btn.onClick.bindingId or btn.onClick.bindingId <= 0 then
        return
    end
    
    if enabled then
        _ensureBtnInteractableForHint(btn)
    else
        _restoreBtnInteractableFromHint(btn)
    end
    InputManagerInst:ToggleBinding(btn.onClick.bindingId, enabled == true)
    if enabled and hintText then
        CellHelper.SetBindingTextIfChanged(btn.onClick.bindingId, hintText)
    end
end


function CellHelper.GetItemButton(itemWidget)
    return itemWidget and itemWidget.view and itemWidget.view.button
end

function CellHelper.ToggleItemBtnBinding(itemWidget, enabled, hintText)
    local btn = CellHelper.GetItemButton(itemWidget)
    if not btn then
        return
    end
    
    CellHelper.ToggleBtnBinding(btn, enabled, hintText)
    local hoverGroupId = btn.hoverBindingGroupId
    if hoverGroupId and hoverGroupId > 0 then
        InputManagerInst:ToggleGroup(hoverGroupId, enabled == true)
    end
end

function CellHelper.SetWeaponIconAndName(cell, weaponId, isForesightWeapon, displayWeaponRefineLv, isDisplayWeaponOwned)
    if string.isEmpty(weaponId) then
        return
    end
    local iconId, name
    if isForesightWeapon then
        local okForesight, foresightCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        if okForesight then
            iconId = foresightCfg.iconId
            name = foresightCfg.name
        end
    else
        local okItem, itemCfg = Tables.itemTable:TryGetValue(weaponId)
        local okWeapon, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponId)
        iconId = okItem and itemCfg.iconId
        name = (okItem and itemCfg.name) or (okWeapon and weaponCfg.name)
    end
    if cell.weaponImg and iconId then
        cell.weaponImg:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, iconId)
    end
    if cell.nameTxt then
        CellHelper.SetUiText(cell.nameTxt, name or "")
    end
    local showPotential = isDisplayWeaponOwned == true
    if cell.simplePotentialStar and cell.simplePotentialStar.gameObject then
        cell.simplePotentialStar.gameObject:SetActive(showPotential)
        if showPotential and cell.simplePotentialStar.InitWeaponSimplePotentialStar then
            cell.simplePotentialStar:InitWeaponSimplePotentialStar(displayWeaponRefineLv or 0)
        end
    end
end


function CellHelper.ApplyGrowthLabelState(cell, growthLabelState, isDisplayWeaponOwned, curLevel)
    local labelState = isDisplayWeaponOwned and "Owned" or "NotOwn"
    if cell.growthLabelNode and cell.growthLabelNode.SetState then
        cell.growthLabelNode:SetState(labelState)
    end
    if cell.lvNumTxt then
        CellHelper.SetUiText(cell.lvNumTxt, isDisplayWeaponOwned and string.format("%d", curLevel or 1) or "")
    end
end

function CellHelper.SetWeaponLineImgRarity(cell, weaponId, isForesightWeapon)
    if not cell.lineImg or string.isEmpty(weaponId) then
        return
    end
    local ok, itemCfg = Tables.itemTable:TryGetValue(weaponId)
    local rarity = ok and itemCfg.rarity
    if not rarity and isForesightWeapon then
        ok, itemCfg = Tables.foresightWeaponTable:TryGetValue(weaponId)
        rarity = ok and itemCfg.rarity
    end
    if rarity then
        UIUtils.setItemRarityImage(cell.lineImg, rarity)
    end
end

return CellHelper
