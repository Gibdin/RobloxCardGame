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
		passiveDesc = "Heals a little whenever it takes damage.",
		bonusLabel  = "Max HP",
		bonuses     = { "Max HP ★", "Max HP ★★", "Max HP ★★★", "Max HP ★★★★", "Max HP ★★★★★" },
	},
	DPS = {
		icon     = "⚔",
		color    = Color3.fromRGB(220, 60, 60),
		passives = {
			Rage        = "Gets stronger with every hit it lands.",
			Executioner = "Hits harder against enemies on low HP.",
		},
		bonusLabel = "ATK",
		bonuses    = { "ATK ★", "ATK ★★", "ATK ★★★", "ATK ★★★★", "ATK ★★★★★" },
	},
	Support = {
		icon     = "✚",
		color    = Color3.fromRGB(60, 200, 120),
		passives = {
			Medic   = "Heals the weakest ally at the end of every round.",
			Battery = "Gives the team mana whenever anyone is knocked out.",
		},
		bonusLabel = "Effectiveness",
		bonuses    = { "Ability power ★", "Ability power ★★", "Ability power ★★★", "Ability power ★★★★", "Ability power ★★★★★" },
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
	{ from = "Tank",    to = "DPS",     text = "Tanks take less damage from DPS" },
	{ from = "DPS",     to = "Support", text = "DPS deal extra damage to Supports" },
	{ from = "Support", to = "Tank",    text = "Supports are stronger against Tanks" },
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
			{ count = 2, bonus = "Both members hit much harder." },
		},
	},
	["First Years"] = {
		desc       = "The newest class at the jujutsu school. They cover for each other when things go wrong.",
		color      = Color3.fromRGB(90, 110, 230),
		maxCount   = 3,
		thresholds = {
			{ count = 2, bonus = "Members get stronger and tougher." },
			{ count = 3, bonus = "Even stronger and tougher, and the first member in danger gets a shield." },
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
