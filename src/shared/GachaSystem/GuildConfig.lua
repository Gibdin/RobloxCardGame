-- Guild progression curve, member caps, and chat/name validation limits.
-- Edit values here to rebalance guild XP pacing and buffs.

local GuildConfig = {}

GuildConfig.MaxMembers    = 20
GuildConfig.MinNameLength = 3
GuildConfig.MaxNameLength = 24
GuildConfig.MaxChatLength = 200

-- Per-guild in-memory ring buffer size — chat is NOT persisted to DataStore
-- (MVP scope; cheap and avoids write-spam), so history resets per server and
-- doesn't cross server boundaries. Fine for a guild's "current conversation."
GuildConfig.MaxChatLog = 50

-- Cumulative XP required to REACH each level (index = level). Level 1 is free
-- (index 1 = 0 XP). The last entry is the effective level cap.
GuildConfig.LevelXP = {
	0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 75000,
}

-- Gem-reward bonus per guild level (see GuildService:GetGuildBuffMultiplier),
-- applied to a member's async-PvP win rewards as the first real guild-wide
-- buff. Capped at the highest defined level in LevelXP.
GuildConfig.BuffPerLevel = 0.02 -- +2% Gems per level

-- Guild XP granted per win, credited via GuildService:ContributeXP.
GuildConfig.XPPerPvEWin  = 10  -- Dungeon boss clear / Tower milestone
GuildConfig.XPPerDuelWin = 25  -- live PvP duel win (also feeds GuildWarScore)

return GuildConfig
