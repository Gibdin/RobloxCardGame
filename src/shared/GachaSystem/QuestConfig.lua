-- Daily/weekly quest pools and the login-streak reward calendar. Rewards are
-- always persistent currency (Gems/packs) — never gold, which is intentionally
-- run-scoped and never persists (see DungeonService). Edit values here to
-- rebalance retention rewards; QuestService reads this, nothing is hardcoded
-- in the service itself.

local QuestConfig = {}

-- `type` must match a QuestService:RecordProgress event key (see the require
-- sites in PackService/DungeonService/TowerService for the exact list).
QuestConfig.DailyCount = 3
QuestConfig.DailyPool = {
	{ id = "d_open_2_packs",   desc = "Open 2 packs",          type = "pack_open",   target = 2,  reward = { gems = 40 } },
	{ id = "d_open_4_packs",   desc = "Open 4 packs",          type = "pack_open",   target = 4,  reward = { gems = 80 } },
	{ id = "d_win_2_battles",  desc = "Win 2 battles",         type = "battle_win",  target = 2,  reward = { gems = 50 } },
	{ id = "d_win_4_battles",  desc = "Win 4 battles",         type = "battle_win",  target = 4,  reward = { gems = 90 } },
	{ id = "d_clear_3_nodes",  desc = "Clear 3 dungeon nodes", type = "dungeon_node",target = 3,  reward = { gems = 45 } },
	{ id = "d_clear_3_floors", desc = "Clear 3 tower floors",  type = "tower_floor", target = 3,  reward = { gems = 45 } },
	{ id = "d_win_2_duels",    desc = "Win 2 Arena duels",     type = "pvp_win",     target = 2,  reward = { gems = 45 } },
}

QuestConfig.WeeklyCount = 3
QuestConfig.WeeklyPool = {
	{ id = "w_open_10_packs",  desc = "Open 10 packs",          type = "pack_open",   target = 10, reward = { gems = 150, packs = { StandardPack = 1 } } },
	{ id = "w_win_15_battles", desc = "Win 15 battles",         type = "battle_win",  target = 15, reward = { gems = 200, packs = { StandardPack = 1 } } },
	{ id = "w_clear_boss",     desc = "Defeat a Dungeon boss",  type = "dungeon_boss",target = 1,  reward = { gems = 120, packs = { RarePack = 1 } } },
	{ id = "w_tower_20",       desc = "Clear 20 tower floors",  type = "tower_floor", target = 20, reward = { gems = 180, packs = { RarePack = 1 } } },
	{ id = "w_win_10_duels",   desc = "Win 10 Arena duels",     type = "pvp_win",     target = 10, reward = { gems = 150, packs = { StandardPack = 1 } } },
}

-- 7-day repeating cycle; day index = ((streak - 1) % 7) + 1.
QuestConfig.LoginStreak = {
	{ day = 1, reward = { gems = 25 } },
	{ day = 2, reward = { packs = { StandardPack = 1 } } },
	{ day = 3, reward = { gems = 50 } },
	{ day = 4, reward = { packs = { StandardPack = 1 } } },
	{ day = 5, reward = { gems = 75 } },
	{ day = 6, reward = { packs = { RarePack = 1 } } },
	{ day = 7, reward = { gems = 150, packs = { RarePack = 1 } } },
}

-- Battle Pass XP granted per tracked event (in addition to quest-claim XP,
-- which equals the Gem value of the quest's reward for simplicity).
QuestConfig.BattlePassXp = {
	pack_open    = 5,
	battle_win   = 10,
	dungeon_node = 8,
	dungeon_boss = 50,
	tower_floor  = 8,
	pvp_win      = 12,
}

return QuestConfig
