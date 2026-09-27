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
	["Iron Legion"] = {
		desc       = "Armored warriors forged from iron and steel. The more the merrier — their unity is their armor.",
		color      = Color3.fromRGB(160, 180, 210),
		maxCount   = 5,
		thresholds = {
			{ count = 2, bonus = "+10% HP; take -8% damage from all sources" },
			{ count = 4, bonus = "Reflect 12% of incoming damage; deal +8% to non-Iron Legion targets" },
			{ count = 5, bonus = "Impenetrable: cannot be one-shot; first lethal hit is survived at 1 HP" },
		},
	},
	["Nature's Call"] = {
		desc       = "Guardians of the ancient forest. Their presence restores life to all who stand beside them.",
		color      = Color3.fromRGB(70, 200, 100),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "All healing effects increased by +25%" },
			{ count = 4, bonus = "Team regenerates 4% Max HP at the start of each round" },
		},
	},
	["Storm Riders"] = {
		desc       = "Beings born of wind and lightning. Speed is their weapon, and the sky is their domain.",
		color      = Color3.fromRGB(100, 170, 255),
		maxCount   = 5,
		thresholds = {
			{ count = 2, bonus = "+10% ATK" },
			{ count = 4, bonus = "+10% ATK; 30% chance each attack chains to a second target for 60% damage" },
			{ count = 5, bonus = "Storm Surge: chain damage = 100%; all Storm Riders gain +25% ATK" },
		},
	},
	["Shadow Covenant"] = {
		desc       = "Bound by shadow and blood oath. They hunt as one — and their prey never sees them coming.",
		color      = Color3.fromRGB(160, 60, 200),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "Executioner bonus damage +20%; kills restore 3% Max HP to the killer" },
			{ count = 4, bonus = "Shadow Mark: first attack each round marks the target — all allies deal +18% damage to marked targets" },
		},
	},
	["Abyssal Order"] = {
		desc       = "Dwellers of the crushing deep. They endure where others would break, and grow stronger as battles drag on.",
		color      = Color3.fromRGB(40, 160, 200),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "+12% lifesteal on all attacks" },
			{ count = 4, bonus = "Tidal Surge: when any member drops below 50% HP, all Abyssal gain +18% ATK and heal 6% Max HP" },
		},
	},
	["Divine Pantheon"] = {
		desc       = "Holy warriors of eternal light. Their faith shields the fallen and turns death into a second chance.",
		color      = Color3.fromRGB(255, 215, 80),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "Support abilities trigger an additional time per cast" },
			{ count = 4, bonus = "Celestial Shield: each member's first death is negated — they revive at 25% HP" },
		},
	},
	["Void Walkers"] = {
		desc       = "Torn from the fabric of reality. Their abilities bend the rules of engagement itself.",
		color      = Color3.fromRGB(140, 60, 220),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "Abilities cost 1 less mana" },
			{ count = 4, bonus = "Abilities cost 1 less mana and ignore 35% of enemy defenses" },
		},
	},
	["Ancient Ones"] = {
		desc       = "Titans who predate civilization. Their bodies are monuments; their will, unbreakable.",
		color      = Color3.fromRGB(200, 140, 60),
		maxCount   = 4,
		thresholds = {
			{ count = 2, bonus = "+15% Max HP for all Ancient Ones members" },
			{ count = 4, bonus = "Titans' Will: cannot be one-shot above 30% HP; take -20% damage below 50% HP" },
		},
	},
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
	"Iron Legion",
	"Storm Riders",
	"Shadow Covenant",
	"Abyssal Order",
	"Divine Pantheon",
	"Void Walkers",
	"Ancient Ones",
	"Nature's Call",
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
