-- Account-level meta progression: a level/XP curve fed by cumulative wins
-- across Dungeon/Tower/Duels, unlocking cosmetic titles and a small
-- compounding account-wide stat perk. Edit values here to rebalance pacing.

local AccountConfig = {}

-- Cumulative XP required to REACH each level (index = level). Level 1 is
-- free (index 1 = 0 XP). The last entry is the effective level cap.
AccountConfig.LevelXP = {
	0, 200, 600, 1400, 2800, 5000, 8000, 12000, 18000, 26000,
	36000, 50000, 68000, 90000, 120000,
}

-- Small compounding ATK/HP bonus per account level, applied account-wide to
-- EVERY battle (Dungeon/Tower/PvP/Duel) via AccountService:GetStatMods.
-- Deliberately tiny (~4.5% total at max level) — this is a "nice to have
-- while grinding," not a power system; card collection and Prestige
-- artifacts are the real progression levers.
AccountConfig.StatPerLevel = 0.003

-- Cosmetic title unlocks, shown/equippable from the Quests panel's PROGRESS tab.
AccountConfig.Titles = {
	{ level = 2,  title = "Novice Tamer" },
	{ level = 4,  title = "Card Collector" },
	{ level = 6,  title = "Seasoned Duelist" },
	{ level = 8,  title = "Veteran Tactician" },
	{ level = 10, title = "Elite Summoner" },
	{ level = 12, title = "Grandmaster" },
	{ level = 15, title = "Legend" },
}

-- Account XP granted per win, credited via AccountService:AddXp. Deliberately
-- NOT fed by async PvP wins — mirrors GuildConfig's Phase 7 precedent that an
-- async attack on an offline snapshot doesn't count as a "live" win.
AccountConfig.XPPerPvEWin  = 40  -- Dungeon boss clear / Tower boss floor
AccountConfig.XPPerDuelWin = 60  -- live PvP duel win

return AccountConfig
