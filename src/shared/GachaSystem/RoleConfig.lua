-- Role definitions and synergy groups.
-- role bonuses scale with the number of that role in the active team.
-- Synergies key off card.series array entries.
-- Thresholds are ordered; highest satisfied threshold is active.

local RoleConfig = {}

RoleConfig.Roles = {
	Tank = {
		icon        = "🛡",
		color       = Color3.fromRGB(60, 130, 220),
		passive     = "Drain",
		passiveDesc = "Heals for a percentage of all damage dealt to this card.",
		bonusLabel  = "Max HP",
		bonuses     = { "+5% Max HP", "+10% Max HP", "+15% Max HP", "+18% Max HP", "+20% Max HP" },
	},
	DPS = {
		icon     = "⚔",
		color    = Color3.fromRGB(220, 60, 60),
		passives = {
			Rage        = "Gains cumulative ATK bonus after each successful attack this battle.",
			Executioner = "Deals amplified damage to targets below 35% HP.",
		},
		bonusLabel = "ATK",
		bonuses    = { "+5% ATK", "+10% ATK", "+15% ATK", "+18% ATK", "+20% ATK" },
	},
	Support = {
		icon     = "✚",
		color    = Color3.fromRGB(60, 200, 120),
		passives = {
			Medic   = "Heals the lowest HP ally after each round.",
			Battery = "Restores 1 mana to allies whenever any unit on the field dies.",
		},
		bonusLabel = "Effectiveness",
		bonuses    = { "+5% Ability Effectiveness", "+10% Ability Effectiveness", "+15% Ability Effectiveness", "+18% Ability Effectiveness", "+20% Ability Effectiveness" },
	},
}

-- ── Subroles (two per role; AnimeRosterPlan.md §11.3) ─────────────────────────
RoleConfig.Subroles = {
	Duelist    = { role = "DPS",     desc = "Single-target damage." },
	Skirmisher = { role = "DPS",     desc = "Area damage that hits the whole enemy row." },
	Vanguard   = { role = "Tank",    desc = "Protects the team with shields and soaks damage." },
	Juggernaut = { role = "Tank",    desc = "Crowd control: stuns and disrupts enemies." },
	Enchanter  = { role = "Support", desc = "Aids allies with heals, ATK buffs and mana." },
	Hexer      = { role = "Support", desc = "Weakens enemies with debuffs and mana drain." },
}

-- ── Role counter cycle text (numbers in CombatConfig.Counters) ────────────────
RoleConfig.Counters = {
	{ from = "Tank",    to = "DPS",     text = "Tanks take 10% less damage from DPS" },
	{ from = "DPS",     to = "Support", text = "DPS deal 10% more damage to Supports" },
	{ from = "Support", to = "Tank",    text = "Supports deal 10% more to Tanks; their effects are 10% stronger vs a Tank frontline" },
}

-- ── Synergy groups ────────────────────────────────────────────────────────────
-- thresholds: ordered ascending; a tier is active when team count >= threshold.count.
-- maxCount: how many members exist in the card set (informs pip display).
-- color: used for synergy badge and pip fill color.

RoleConfig.Synergies = {
	["Best Friends"] = {
		desc       = "Two sorcerers who share one very specific taste in people. Together, their fists hit harder.",
		color      = Color3.fromRGB(240, 120, 60),
		maxCount   = 2,
		thresholds = {
			{ count = 2, bonus = "+18% ATK for both members" },
		},
	},
	["First Years"] = {
		desc       = "The newest class at the jujutsu school. They cover for each other when things go wrong.",
		color      = Color3.fromRGB(90, 110, 230),
		maxCount   = 3,
		thresholds = {
			{ count = 2, bonus = "+8% ATK and +8% Max HP for members" },
			{ count = 3, bonus = "+12% ATK and +12% Max HP; the first member to drop below 30% HP gets a 20% Max HP shield" },
		},
	},
}

-- Display order for synergy list panels.
RoleConfig.SynergyOrder = {
	"First Years",
	"Best Friends",
}

-- Passive type chip colors used in card detail views.
RoleConfig.PassiveColor = {
	Drain       = Color3.fromRGB(60,  130, 220),
	Rage        = Color3.fromRGB(220,  60,  60),
	Executioner = Color3.fromRGB(220, 130,  40),
	Medic       = Color3.fromRGB(60,  200, 120),
	Battery     = Color3.fromRGB(60,  180, 200),
	Trait       = Color3.fromRGB(230, 180,  60),
}

return RoleConfig
