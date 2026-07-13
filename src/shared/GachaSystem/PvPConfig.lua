-- Async PvP constants: starting rating, trophy gain/loss, and diminishing
-- daily win rewards (prevents farming the same easy opponent repeatedly).
-- Uses a trophy system rather than symmetric Elo — the defender is an
-- offline snapshot with no agency, so only the attacker's rating moves
-- (standard pattern in async-PvP mobile games, avoids "sniped while offline"
-- rating loss).

local PvPConfig = {}

PvPConfig.StartingRating = 1000
PvPConfig.MinRating      = 0
PvPConfig.WinTrophies    = 20
PvPConfig.LoseTrophies   = -10

-- Opponent pool size shown in ArenaUI (top-N by rating, excluding self — see
-- GameDesign.md's Phase 5 note on same-tier matchmaking being deferred).
PvPConfig.OpponentPoolSize = 20

-- Diminishing Gem reward per win today, keyed by "wins so far today
-- (before this win) fall below `upTo`". Evaluated in order; first match wins.
PvPConfig.DailyRewardTiers = {
	{ upTo = 5,   gems = 15 },
	{ upTo = 15,  gems = 8 },
	{ upTo = 999, gems = 3 },
}

return PvPConfig
