



















local Config = {
    [GEnums.ActivityType.ContingencyContract] = {
        Check = function(activityId)
            local activity = GameInstance.player.activitySystem:GetActivity(activityId)
            
            if not activity or activity.status ~= GEnums.ActivityStatus.InProgress then
                return "Hide"
            end
            
            local currentTime = DateTimeUtils.GetCurrentTimestampBySeconds()
            local isGameplayEnd = activity.gameplayEndTime - currentTime <= 0
            if isGameplayEnd then
                return "Disabled"
            end
            return "Normal"
        end,
    },

}

return Config
