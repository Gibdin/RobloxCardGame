-- Single source of truth for all combat constants: damage formula, mana economy,
-- generic role actives, role passives, role-count bonuses, synergy tier numbers,
-- and client playback timings. Edit values here to rebalance combat.

local CombatConfig = {}

-- ── Card stat formula (AnimeRosterPlan.md §11.8) ─────────────────────────────
-- attack/hp = RoleBase × RarityMult × SubroleMod × the card's own `stat` mod.
-- CardDatabase computes these at require time (rounded to RoundTo); cards with
-- `fixedStats = true` keep their literal attack/hp. Every combat effect is %-based, so this whole
-- table can be rescaled without breaking anything.
CombatConfig.CardStats = {
	RoundTo = 10,  -- every final ATK/HP rounds to the nearest 10
	RoleBase = {
		-- HP was raised 2.5x after sims (2026-09-27): at the old values fights
		-- lasted 2-5 rounds, going first decided even matchups, and cost-4/5
		-- abilities rarely fired. At 2.5x fights run ~6-12 rounds and team
		-- composition decides same-rarity fights.
		DPS     = { atk = 60, hp = 500 },   -- pure damage, fragile
		Tank    = { atk = 30, hp = 1120 },  -- takes a beating
		Support = { atk = 30, hp = 650 },   -- power lives in their %-based effects
	},
	-- ~20% per step: Legendary ~2x a Common, God 3x.
	RarityMult = {
		Common = 1.00, Uncommon = 1.20, Rare = 1.45, Epic = 1.75,
		Legendary = 2.10, Mythic = 2.50, God = 3.00, Secret = 3.50,
	},
	SubroleMod = {
		Duelist    = { atk = 1.10, hp = 0.95 },
		Skirmisher = { atk = 0.90, hp = 1.00 },
		Vanguard   = { atk = 0.90, hp = 1.10 },
		Juggernaut = { atk = 1.20, hp = 0.95 },
		Enchanter  = { atk = 1.00, hp = 1.00 },
		Hexer      = { atk = 1.00, hp = 1.00 },
	},
}

-- ── Core battle ───────────────────────────────────────────────────────────────
CombatConfig.Battle = {
	MaxRounds  = 50,     -- hard cap; on cap, side with higher total HP% wins (tie = player loss)
	VarianceLo = 0.95,   -- damage roll multiplier range
	VarianceHi = 1.05,
	CritChance = 0.05,
	CritMult   = 1.5,
	MaxEvents  = 4000,   -- safety cap on event log length
}

-- ── Mana economy (whole points; card.mp is the ability's mana cost, 2-5) ─────
-- +1 per swing landed; the ability fires the moment mana reaches the cost and
-- does not replace the attack. Fractional gain (mpGainMult items) carries over.
CombatConfig.MP = {
	OnAttack = 1,  -- attacker, per basic-attack swing landed
}

-- ── Generic role actives (fallback) ───────────────────────────────────────────
-- Used by any card without its own `active.effects` in CardDatabase.lua.
-- Legendary+ cards have real per-card unique kits (BattleEngine.lua's
-- runActiveStep); Common-Epic still share these until Phase 9's roster
-- expansion backfills them too.
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
	Battery     = { manaRestore = 1 },                     -- to all living allies when ANY unit dies
}

-- ── Role count bonuses (index = count of that role on the team, max 5) ───────
-- Diminishing after 3. Mirrors RoleConfig.Roles[*].bonuses text.
CombatConfig.RoleBonuses = {
	Tank    = { 0.05, 0.10, 0.15, 0.18, 0.20 },  -- +MaxHP
	DPS     = { 0.05, 0.10, 0.15, 0.18, 0.20 },  -- +ATK
	Support = { 0.05, 0.10, 0.15, 0.18, 0.20 },  -- ability effectiveness (heals/shields/buffs/debuffs cast by Supports)
}

-- ── Role counter cycle: Tank > DPS > Support > Tank ───────────────────────────
-- Always keyed off the ENEMY's role, so pairing roles on your own team never
-- stacks a counter.
CombatConfig.Counters = {
	TankVsDPS       = 0.10,  -- Tanks take 10% less damage from DPS
	DPSVsSupport    = 0.10,  -- DPS deal +10% damage to Supports
	SupportVsTank   = 0.10,  -- Supports deal +10% damage to Tanks
	SupportEffectVsTankFront = 0.10,  -- Support effects +10% while the enemy frontline is a Tank
	HexerAtkDebuffCap = 0.20,  -- total enemy ATK shred can never exceed this
}

-- ── Unique Traits (card.trait) ────────────────────────────────────────────────
CombatConfig.Traits = {
	divergent_fist       = { bonusCurrentHpPct = 0.008 },            -- Itadori: 2nd swing adds % of target's CURRENT HP
	infinity             = {},                                        -- Gojo: first hit taken each round is nullified
	dismantle            = { cleavePct = 0.50 },                      -- Sukuna: basic attacks also hit the next enemy
	adaptation           = { perHit = 0.10, cap = 0.50 },             -- Mahoraga: per-attacker damage reduction
	queen_of_curses      = { shieldPct = 0.30 },                      -- Yuta: survive first lethal hit at 1 HP + shield
	heavenly_restriction = { critBonus = 0.10 },                      -- Toji: stun/ATK-debuff immune, +crit
	thousand_year_plan   = { manaPerEnemyCast = 1 },                  -- Kenjaku
	spirit_manipulation  = { startMana = 1 },                         -- Geto: allies start with mana
	three_cores          = { tankDR = 0.20, gorillaAtk = 0.25 },      -- Panda: odd rounds Tank, even rounds DPS
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
		[4] = { doubleSupportCast = true, revivePct = 0.25 },  -- members revive once per battle at 25% HP
	},
	["Void Walkers"] = {
		[2] = { manaCostReduction = 1 },
		[4] = { manaCostReduction = 1, ignoreDRPct = 0.35 },
	},
	["Ancient Ones"] = {
		[2] = { hpPct = 0.15 },
		[4] = { hpPct = 0.15, noOneShotAboveHpPct = 0.30, drBelowHalf = 0.20 },
	},
	-- JJK factions (AnimeRosterPlan.md §9/§11.7).
	["Best Friends"] = {
		[2] = { atkPct = 0.18 },
	},
	["First Years"] = {
		[2] = { atkPct = 0.08, hpPct = 0.08 },
		[3] = { atkPct = 0.12, hpPct = 0.12, lowHpShieldPct = 0.20, lowHpShieldAt = 0.30 },
	},
}

-- ── Combat drama beats (client playback emphasis; all client-side) ────────────
CombatConfig.Drama = {
	CritShake        = { intensity = 6,  duration = 0.25 },
	KillShake        = { intensity = 10, duration = 0.35 },
	FinalBlowShake   = { intensity = 16, duration = 0.6 },
	KillPause        = 0.45,   -- extra hold after any death event
	FinalBlowPause   = 0.9,    -- hold after the battle-deciding damage event
	FinalBlowPreHold = 0.35,   -- beat of silence BEFORE the final hit lands
	LowHpThreshold   = 0.3,    -- frontliner pulse below this HP ratio
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
	maxhp_shred = 0.40,
	status  = 0.35,
	["end"] = 0.50,
	Speeds  = { 1, 2 },
}

return CombatConfig
