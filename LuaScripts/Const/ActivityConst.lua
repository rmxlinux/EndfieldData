local ActivityType = GEnums.ActivityType
ACTIVITY_TABLE = {
    [ActivityType.Basic] = {
        redDot = "ActivityBasic",
    },
    [ActivityType.LevelRewards] = {
        redDot = "ActivityBaseMultiStage",
    },
    [ActivityType.BeginnerGachaPool] = {
        redDot = "ActivityGachaBeginner",
    },
    [ActivityType.Checkin] = {
        redDot = "ActivityCheckIn",
    },
    [ActivityType.GlobalEffect] = {
        redDot = "ActivityGlobalEffect",
    },
    [ActivityType.NormalChallenge] = {
        redDot = "ActivityNormalChallenge",
    },
    [ActivityType.CharacterTrial] = {
        redDot = "ActivityCharTrial",
    },
    [ActivityType.HighDifficultyChallenge] = {
        redDot = "ActivityHighDifficulty",
    },
    [ActivityType.PhotoTaking] = {
        redDot = "ActivityConditionalMultiStage",
    },
    [ActivityType.CharacterGuideLine] = {
        redDot = "ActivityCharacterGuideLine",
    },
    [ActivityType.CharacterGuideLine] = {
        redDot = "ActivityCharacterGuideLine",
    },
    [ActivityType.ItemSubmission] = {
        redDot = "ActivityItemSubmission",
    },
    [ActivityType.VersionGuide] = {
        redDot = "ActivityVersionGuide",
    },
    [ActivityType.RandomReward] = {
        redDot = "ActivityRandomReward",
    },
    [ActivityType.RewardOverview] = {
        redDot = "ActivityRewardOverview",
    },
    [ActivityType.WeeklyTask] = {
        redDot = "ActivityWeeklyTask",
    },
    
}
ACTIVITY_COMMON_SONS = {
    ActivityBasic = false,
    ActivityBaseMultiStage = false,
    ActivityGachaBeginner = false,
    ActivityCheckIn = false,
    ActivityGlobalEffect = false,
    ActivityNormalChallenge = false,
    ActivityHighDifficulty = false,
    ActivityConditionalMultiStage = false,
    ActivityCharacterGuideLine = false,
    ActivityItemSubmission = false,
    ActivityVersionGuide = false,
    ActivityRandomReward = false,
    ActivityRewardOverview = false,
    ActivityWeeklyTask = false,
    ActivityDaily = false,
    
}
ACTIVITY_REMINDER_DRAW_MODE = {
    All = 1,
    NoComplete = 2,
}
