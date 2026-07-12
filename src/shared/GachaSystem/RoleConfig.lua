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
		bonuses     = { "+6% Max HP", "+12% Max HP", "+20% Max HP" },
	},
	DPS = {
		icon     = "⚔",
		color    = Color3.fromRGB(220, 60, 60),
		passives = {
			Rage        = "Gains cumulative ATK bonus after each successful attack this battle.",
			Executioner = "Deals amplified damage to targets below 35% HP.",
		},
		bonusLabel = "ATK",
		bonuses    = { "+6% ATK", "+12% ATK", "+20% ATK" },
	},
	Support = {
		icon     = "✚",
		color    = Color3.fromRGB(60, 200, 120),
		passives = {
			Medic   = "Heals the lowest HP ally after each round.",
			Battery = "Restores MP to allies whenever any unit on the field dies.",
		},
		bonusLabel = "Effectiveness",
		bonuses    = { "+8% Ability Effectiveness", "+16% Ability Effectiveness", "+25% Ability Effectiveness" },
	},
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
			{ count = 2, bonus = "+10% attack speed; first attack each round cannot miss" },
			{ count = 4, bonus = "30% chance each attack chains to a second target for 60% damage" },
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
			{ count = 2, bonus = "All abilities cost −1 MP to activate" },
			{ count = 4, bonus = "Reality Fracture: abilities ignore 35% of enemy defenses" },
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
}

-- Passive type chip colors used in card detail views.
RoleConfig.PassiveColor = {
	Drain       = Color3.fromRGB(60,  130, 220),
	Rage        = Color3.fromRGB(220,  60,  60),
	Executioner = Color3.fromRGB(220, 130,  40),
	Medic       = Color3.fromRGB(60,  200, 120),
	Battery     = Color3.fromRGB(60,  180, 200),
}

return RoleConfig
