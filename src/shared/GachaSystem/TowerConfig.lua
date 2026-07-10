-- Endless Tower constants: enemy scaling, XP awards, buff-pick cadence,
-- milestone pack rewards. Edit values here to rebalance the tower.

local TowerConfig = {}

-- ── Enemy generation per floor ────────────────────────────────────────────────
-- Team size grows with floor; rarity pool widens by floor band.
TowerConfig.Enemies = {
	TeamSize = function(floor)
		if floor <= 3 then return 3
		elseif floor <= 9 then return 4
		else return 5 end
	end,
	-- Weighted rarity pools by floor band (first matching band wins).
	RarityBands = {
		{ maxFloor = 6,  pool = { Common = 0.75, Uncommon = 0.25 } },
		{ maxFloor = 13, pool = { Uncommon = 0.65, Rare = 0.30, Epic = 0.05 } },
		{ maxFloor = 20, pool = { Rare = 0.45, Epic = 0.40, Legendary = 0.15 } },
		{ maxFloor = math.huge, pool = { Epic = 0.40, Legendary = 0.45, Mythic = 0.15 } },
	},
	BossEvery = 5,        -- every Nth floor is a boss floor
	BossMult  = 1.15,     -- extra stat multiplier on boss floors
}

-- Stat multiplier applied to enemy ATK/HP: linear early, exponential late so
-- every run eventually ends.
function TowerConfig.StatMult(floor)
	local mult = 0.7 + 0.04 * floor
	if floor > 25 then
		mult = mult * (1.05 ^ (floor - 25))
	end
	return mult
end

-- ── Player progression ────────────────────────────────────────────────────────
TowerConfig.XpPerFloor = function(floor)
	return 80 + 25 * floor
end
TowerConfig.BuffPickEvery = 5   -- offer an elite-buff pick every Nth floor cleared

-- ── HP carryover (shared behavior with dungeon) ───────────────────────────────
TowerConfig.WinHealPct    = 0.15  -- survivors heal this fraction of MaxHP after a win
TowerConfig.RevivePct     = 0.25  -- dead cards revive at this fraction after a WON battle

-- ── Milestone pack rewards (granted immediately, once per run) ────────────────
-- After the listed floors, every `RepeatEvery` floors grants `RepeatPacks`.
TowerConfig.Milestones = {
	[5]  = { StandardPack = 1 },
	[10] = { StandardPack = 2 },
	[15] = { RarePack = 1 },
	[20] = { RarePack = 2 },
}
TowerConfig.RepeatEvery = 10       -- floors 30, 40, 50, ...
TowerConfig.RepeatPacks = { RarePack = 1 }

return TowerConfig
