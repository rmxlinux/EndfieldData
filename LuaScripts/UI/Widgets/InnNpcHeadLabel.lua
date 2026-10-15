local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

local MATCH_LEVEL = CS.Beyond.Gameplay.InnSystem.InnRequirementMatchLevel
local GUEST_TYPE_SPECIAL = CS.Proto.INN_MANAGEMENT_GUEST_TYPE.GuestTypeSpecial

local EMOJI_NAME_HAPPY = "emoji_newhappy"
local EMOJI_NAME_SAD = "emoji_newsad"
local EMOJI_NAME_SATISFIED = "emoji_newsatisfied"

InnNpcHeadLabel = HL.Class('InnNpcHeadLabel', UIWidgetBase)


InnNpcHeadLabel._OnFirstTimeInit = HL.Override() << function(self)
    
end





InnNpcHeadLabel.InitInnNpcHeadLabel = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    if args.text and args.text ~= "" then
        self.view.bubble.gameObject:SetActive(true)
        self.view.emoji.gameObject:SetActive(false)
        self.view.bubbleText.text = args.text
        return
    end

    if args.guestId and args.guestId > 0 then
        self.view.bubble.gameObject:SetActive(false)
        self.view.emoji.gameObject:SetActive(true)

        local guest = self:_GetGuest(args.guestId)
        local emojiName = self:_PickEmojiName(guest)
        self:_ApplyEmojiChild(emojiName)
    end
    self.view.bubbleNodeAnimationWrapper:PlayInAnimation()
end

InnNpcHeadLabel._GetGuest = HL.Method(HL.Number).Return(HL.Opt(HL.Userdata)) << function(self, guestId)
    local innSystem = GameInstance.player and GameInstance.player.innSystem or nil
    if not innSystem then
        return nil
    end
    local gs = innSystem.gameState
    if not gs or not gs.guestStates then
        return nil
    end
    local has, guest = gs.guestStates:TryGetValue(guestId)
    if not has or not guest then
        return nil
    end
    return guest
end



InnNpcHeadLabel._PickEmojiName = HL.Method(HL.Opt(HL.Userdata)).Return(HL.String) << function(self, guest)
    if not guest then
        return EMOJI_NAME_SATISFIED
    end
    local matches = guest.matches
    if not matches or matches.Count == 0 then
        return EMOJI_NAME_SATISFIED
    end

    if guest.guestType == GUEST_TYPE_SPECIAL then
        local allPerfect = true
        local allUnsatisfied = true
        for i = 0, matches.Count - 1 do
            local lv = matches[i]
            if lv ~= MATCH_LEVEL.Perfect then
                allPerfect = false
            end
            if lv ~= MATCH_LEVEL.Unsatisfied then
                allUnsatisfied = false
            end
        end
        if allPerfect then
            return EMOJI_NAME_HAPPY
        end
        if allUnsatisfied then
            return EMOJI_NAME_SAD
        end
        return EMOJI_NAME_SATISFIED
    end

    for i = 0, matches.Count - 1 do
        if matches[i] ~= MATCH_LEVEL.Normal then
            return EMOJI_NAME_SAD
        end
    end
    return EMOJI_NAME_SATISFIED
end

InnNpcHeadLabel._ApplyEmojiChild = HL.Method(HL.String) << function(self, emojiName)
    self.view.emoji.gameObject:SetAllChildrenActiveIfNecessary(false)
    local child = self.view.emoji:Find(emojiName)
    if child then
        child.gameObject:SetActive(true)
    end
end

HL.Commit(InnNpcHeadLabel)
return InnNpcHeadLabel

