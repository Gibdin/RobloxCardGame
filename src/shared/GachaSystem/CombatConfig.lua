-- Single source of truth for all combat constants: damage formula, MP economy,
-- generic role actives, role passives, role-count bonuses, synergy tier numbers,
-- and client playback timings. Edit values here to rebalance combat.

local CombatConfig = {}

-- ── Core battle ───────────────────────────────────────────────────────────────
CombatConfig.Battle = {
	MaxRounds  = 50,     -- hard cap; on cap, side with higher total HP% wins (tie = player loss)
	VarianceLo = 0.95,   -- damage roll multiplier range
	VarianceHi = 1.05,
	CritChance = 0.05,
	CritMult   = 1.5,
	MaxEvents  = 4000,   -- safety cap on event log length
}

-- ── MP economy (fractions of the unit's own max MP) ──────────────────────────
CombatConfig.MP = {
	RoundGain     = 0.20,  -- every living unit, at round end
	OnAttack      = 0.15,  -- attacker, per basic attack landed
	OnDamaged     = 0.10,  -- defender, per hit taken
	CastThreshold = 1.0,   -- actives auto-cast at round start when mp >= threshold * maxMp
}

-- ── Generic role actives (v1 — per-card unique actives come later) ───────────
CombatConfig.Actives = {
	DPS     = { atkMult   = 2.00 },  -- 200% ATK hit on frontline enemy
	Support = { healPct   = 0.12 },  -- heal ALL living allies 12% of their MaxHP
	Tank    = { shieldPct = 0.25 },  -- self shield = 25% own MaxHP (absorb pool, persists until broken)
}

-- ── Role passives ─────────────────────────────────────────────────────────────
CombatConfig.Passives = {
	Drain       = { healPctOfDamageTaken = 0.15 },
	Rage        = { atkPerStack = 0.06, maxStacks = 5 },   -- stack per successful basic attack
	Executioner = { hpThreshold = 0.35, bonusDamage = 0.30 },
	Medic       = { healPctLowestAlly = 0.04 },            -- round end
	Battery     = { mpRestorePct = 0.15 },                 -- to all living allies when ANY unit dies
}

-- ── Role count bonuses (index = count, capped at 3; mirrors RoleConfig text) ──
CombatConfig.RoleBonuses = {
	Tank    = { 0.06, 0.12, 0.20 },  -- +MaxHP
	DPS     = { 0.06, 0.12, 0.20 },  -- +ATK
	Support = { 0.08, 0.16, 0.25 },  -- ability effectiveness (heals/shields/MP restores cast by Supports)
}

-- ── Synergies (numbers extracted from RoleConfig threshold text) ──────────────
-- Keyed by series name, then by threshold count. A team gets the highest
-- satisfied tier; effect tables are NOT cumulative — each tier restates its numbers.
CombatConfig.Synergies = {
	["Iron Legion"] = {
		[2] = { hpPct = 0.10, damageReduction = 0.08 },
		[4] = { hpPct = 0.10, damageReduction = 0.08, reflectPct = 0.12, bonusDamagePct = 0.08 },
		[5] = { hpPct = 0.10, damageReduction = 0.08, reflectPct = 0.12, bonusDamagePct = 0.08, surviveLethal = true },
	},
	["Nature's Call"] = {
		[2] = { healingBonus = 0.25 },
		[4] = { healingBonus = 0.25, regenPct = 0.04 },
	},
	["Storm Riders"] = {
		-- "attack speed / cannot miss" has no meaning in a round-based engine; reinterpreted as +ATK.
		[2] = { atkPct = 0.10 },
		[4] = { atkPct = 0.10, chainChance = 0.30, chainPct = 0.60 },
		[5] = { atkPct = 0.25, chainChance = 0.30, chainPct = 1.00 },
	},
	["Shadow Covenant"] = {
		[2] = { execBonusAdd = 0.20, killHealPct = 0.03 },
		[4] = { execBonusAdd = 0.20, killHealPct = 0.03, markBonus = 0.18 },
	},
	["Abyssal Order"] = {
		[2] = { lifestealPct = 0.12 },
		[4] = { lifestealPct = 0.12, tidalAtkPct = 0.18, tidalHealPct = 0.06 },
	},
	["Divine Pantheon"] = {
		[2] = { doubleSupportCast = true },
		[4] = { doubleSupportCast = true, reviveStub = true },  -- revive-at-25% is stubbed in v1
	},
	["Void Walkers"] = {
		-- "-1 MP cost" reinterpreted for the cast-at-full-MP model as a lower threshold.
		[2] = { castThreshold = 0.90 },
		[4] = { castThreshold = 0.90, ignoreDRPct = 0.35 },
	},
	["Ancient Ones"] = {
		[2] = { hpPct = 0.15 },
		[4] = { hpPct = 0.15, noOneShotAboveHpPct = 0.30, drBelowHalf = 0.20 },
	},
}

-- ── Client playback timing (seconds at 1x speed) ──────────────────────────────
CombatConfig.Playback = {
	round   = 0.50,
	attack  = 0.45,
	damage  = 0.25,
	heal    = 0.25,
	mp      = 0.05,
	cast    = 0.70,
	shield  = 0.25,
	death   = 0.80,
	advance = 0.60,
	synergy = 0.60,
	["end"] = 0.50,
	Speeds  = { 1, 2 },
}

return CombatConfig
