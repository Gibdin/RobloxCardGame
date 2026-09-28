-- Card database: the Jujutsu Kaisen set (26 cards) plus The Nameless One
-- (admin-only). Card rules: AnimeRosterPlan.md §11.
-- series: array of synergy group names (matches RoleConfig.Synergies keys). Can be empty or have 2 entries.
-- stat: { atk, hp } personality modifiers (~0.85-1.15); attack/hp are computed
--   from CombatConfig.CardStats at require time (fixedStats = true opts out).
-- mp: mana cost of the active, in whole points (2-5). +1 mana per swing landed.
-- subrole: Duelist | Skirmisher (DPS), Vanguard | Juggernaut (Tank), Enchanter | Hexer (Support).
-- passive: role-passive category label (Drain | Rage | Executioner | Medic | Battery),
--   or "Trait" when the card has a unique trait instead (see `trait`).
-- trait: unique passive id handled by BattleEngine (numbers in CombatConfig.Traits).
-- passive_name / passive_desc: the passive's name and full description.
-- passive_short: one-line summary of a Trait, shown as its main text.
-- active: { name, short, desc, effects? | alternate? }
--   short: one-line summary shown as the main text (~12 words, kid-readable);
--   desc: the full rules with exact numbers (behind "More info" in the UI);
--   effects: the kit BattleEngine runs; alternate: { {name, effects}, ... }
--   cycles techniques per cast.

local CardDatabase = {}

CardDatabase.Cards = {

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ADMIN (1): never enters packs, enemy pools or reveals (adminOnly).
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 50, name = "The Nameless One", rarity = "Secret",
		attack = 9999, hp = 9999, mp = 5, fixedStats = true, adminOnly = true,
		role = "DPS", passive = "Rage",
		passive_name = "???",
		passive_desc = "Its true nature is unknown.",
		active = {
			name = "???",
			short = "Unknown.",
			desc = "Unknown.",
			effects = {
				{ op = "true_damage_all", mult = 10.0 },
				{ op = "maxhp_shred_all", pct = 0.15 },
				{ op = "stack_atk_buff", pct = 0.10 },
			},
		},
		series = {},
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- JUJUTSU KAISEN (26) — AnimeRosterPlan.md §11.7
	-- Parody-style names; every card has a real kit. Traits: Epic+ plus Panda.
	-- ═══════════════════════════════════════════════════════════════════════════

	-- ── Secret ──
	{
		id = 74, name = "The Eight-Handled Wheel", rarity = "Secret",
		stat = { atk = 1.00, hp = 1.15 }, mp = 4,
		role = "Tank", subrole = "Juggernaut", passive = "Trait", trait = "adaptation",
		passive_name = "Adaptation",
		passive_short = "Takes less damage from anyone who keeps hitting it.",
		passive_desc = "Each hit from the same enemy makes that enemy's later hits on it deal 10% less (up to 50%).",
		active = {
			name = "Sword of Extermination",
			short = "A huge true-damage slash on whoever hit it most, plus a stun.",
			desc = "350% ATK true damage to the enemy that has hit this card the most, and stuns it for 1 turn.",
			effects = {
				{ op = "single_damage", target = "mostAdapted", mult = 3.5, trueDamage = true, stunTurns = 1 },
			},
		},
		series = {},
	},

	-- ── God ──
	{
		id = 49, name = "World Cutter", rarity = "God",
		stat = { atk = 1.15, hp = 1.00 }, mp = 5,
		role = "DPS", subrole = "Skirmisher", passive = "Trait", trait = "dismantle",
		passive_name = "Dismantle",
		passive_short = "Every attack also slashes the next enemy.",
		passive_desc = "Every basic attack also slashes the next enemy in line for 50% ATK.",
		active = {
			name = "Malevolent Shrine",
			short = "Slashes every enemy, then keeps cutting them for 3 rounds.",
			desc = "300% ATK true damage to every enemy, then the Shrine keeps cleaving: 80% ATK true damage to every enemy at the start of each of the next 3 rounds.",
			effects = {
				{ op = "true_damage_all", mult = 3.0 },
				{ op = "dot_all", mult = 0.8, rounds = 3, trueDamage = true, name = "Cleave" },
			},
		},
		series = {},
	},
	{
		id = 46, name = "The Honored One", rarity = "God",
		stat = { atk = 1.05, hp = 1.10 }, mp = 5,
		role = "DPS", subrole = "Skirmisher", passive = "Trait", trait = "infinity",
		passive_name = "Infinity",
		passive_short = "Blocks the first hit he takes each round.",
		passive_desc = "The first hit this card takes each round deals no damage.",
		active = {
			name = "Unlimited Void / Hollow Purple",
			short = "Alternates: freeze every enemy, then blast them with Hollow Purple.",
			desc = "Alternates. Unlimited Void: stuns every enemy for 2 turns and hits them all for 150%. Hollow Purple: 600% ATK true damage to the frontline enemy and 200% to every other enemy.",
			alternate = {
				{ name = "Unlimited Void", effects = {
					{ op = "stun", target = "all", turns = 2 },
					{ op = "aoe_damage", mult = 1.5 },
				} },
				{ name = "Hollow Purple", effects = {
					{ op = "single_damage", mult = 6.0, trueDamage = true },
					{ op = "aoe_damage", mult = 2.0, excludeFront = true },
				} },
			},
		},
		series = {},
	},

	-- ── Legendary ──
	{
		id = 51, name = "The Cursed Vessel", rarity = "Legendary",
		stat = { atk = 0.95, hp = 1.10 }, mp = 2,
		role = "DPS", subrole = "Duelist", passive = "Trait", trait = "divergent_fist",
		passive_name = "Divergent Fist",
		passive_short = "Hits twice every turn.",
		passive_desc = "The first attack each turn strikes twice. The second swing deals the first swing's damage + 0.8% of the target's current HP. Both swings give mana.",
		active = {
			name = "Black Flash",
			short = "Adds up his last two hits into one huge punch. It can chain!",
			desc = "Hits for the last two swings combined + 5% of the target's missing HP. Chains: 35% chance to strike again (then 20%, 10%, 5%), each new Black Flash adding up the previous two hits.",
			effects = {
				{ op = "black_flash", missingHpPct = 0.05, repeatChances = { 0.35, 0.20, 0.10, 0.05 } },
			},
		},
		series = { "First Years", "Best Friends" },
	},
	{
		id = 52, name = "Rika's Beloved", rarity = "Legendary",
		stat = { atk = 1.05, hp = 1.00 }, mp = 4,
		role = "DPS", subrole = "Skirmisher", passive = "Trait", trait = "queen_of_curses",
		passive_name = "Queen of Curses",
		passive_short = "Survives one killing blow and gains a shield.",
		passive_desc = "The first time this card would die, it survives at 1 HP and gains a shield worth 30% of its Max HP.",
		active = {
			name = "Copy",
			short = "Copies an ally's last ability, then Rika hits every enemy.",
			desc = "Uses the last ability an ally cast this battle, then Rika hits every enemy for 150%. If no ally has cast yet: Pure Love, 350% to every enemy.",
			effects = {
				{ op = "copy_ally", fallback = { { op = "aoe_damage", mult = 3.5 } } },
				{ op = "aoe_damage", mult = 1.5 },
			},
		},
		series = {},
	},

	-- ── Epic ──
	{
		id = 53, name = "The Sorcerer Killer", rarity = "Epic",
		stat = { atk = 1.00, hp = 0.90 }, mp = 3,
		role = "DPS", subrole = "Duelist", passive = "Trait", trait = "heavenly_restriction",
		passive_name = "Heavenly Restriction",
		passive_short = "Can't be stunned or weakened, and crits more.",
		passive_desc = "Can't be stunned, ignores enemy ATK debuffs, and has +10% crit chance.",
		active = {
			name = "Inverted Spear of Heaven",
			short = "Hunts the weakest enemy, pierces shields and erases its mana.",
			desc = "280% ATK to the lowest-HP enemy, ignoring shields, and nullifies its technique (wipes all its mana).",
			effects = {
				{ op = "single_damage", target = "lowest", mult = 2.8, ignoreShield = true, drainTargetMana = true },
			},
		},
		series = {},
	},
	{
		id = 54, name = "The Stitched-Brow Schemer", rarity = "Epic",
		stat = { atk = 1.00, hp = 1.05 }, mp = 4,
		role = "Support", subrole = "Hexer", passive = "Trait", trait = "thousand_year_plan",
		passive_name = "Thousand-Year Plan",
		passive_short = "Gains mana whenever the enemy uses an ability.",
		passive_desc = "Gains 1 mana whenever an enemy casts an ability.",
		active = {
			name = "Maximum Uzumaki",
			short = "Hits every enemy. Gets stronger each time they use abilities.",
			desc = "100% ATK to every enemy, +15% for every ability the enemy team has cast this battle (up to +150%), and shreds 5% of their defense (stacking to 20%).",
			effects = {
				{ op = "aoe_damage", mult = 1.0, perEnemyCastBonus = 0.15, bonusCap = 1.5 },
				{ op = "enemy_dr_shred", pct = 0.05, cap = 0.20 },
			},
		},
		series = {},
	},
	{
		id = 55, name = "The Curse Collector", rarity = "Epic",
		stat = { atk = 1.00, hp = 1.00 }, mp = 4,
		role = "Support", subrole = "Enchanter", passive = "Trait", trait = "spirit_manipulation",
		passive_name = "Cursed Spirit Manipulation",
		passive_short = "The whole team starts the battle with 1 mana.",
		passive_desc = "All allies start the battle with 1 mana.",
		active = {
			name = "Curse Release",
			short = "Gives allies mana, then unleashes a random cursed spirit.",
			desc = "Gives every other ally 1 mana, then releases a random cursed spirit: Rainbow Dragon (220% to the frontline, ignoring shields), Smallpox Deity (stuns the frontline 2 turns), Mouth Curse (enemy ATK -6%) or Fly Swarm (60% to every enemy).",
			effects = {
				{ op = "grant_mana", amount = 1, excludeSelf = true },
				{ op = "random", options = {
					{ name = "Rainbow Dragon", effects = { { op = "single_damage", mult = 2.2, ignoreShield = true } } },
					{ name = "Smallpox Deity", effects = { { op = "stun", target = "front", turns = 2 } } },
					{ name = "Mouth Curse", effects = { { op = "enemy_atk_shred", pct = 0.06, cap = 0.18 } } },
					{ name = "Fly Swarm", effects = { { op = "aoe_damage", mult = 0.6 } } },
				} },
			},
		},
		series = {},
	},

	-- ── Rare ──
	{
		id = 56, name = "The Soul Sculptor", rarity = "Rare",
		stat = { atk = 1.00, hp = 0.95 }, mp = 4,
		role = "DPS", subrole = "Skirmisher", passive = "Executioner",
		passive_name = "Soul Predator",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "Idle Transfiguration",
			short = "Hits every enemy and permanently shrinks their Max HP.",
			desc = "90% ATK true damage to every enemy, and permanently reshapes their souls: -6% Max HP (stacks).",
			effects = {
				{ op = "true_damage_all", mult = 0.9 },
				{ op = "maxhp_shred_all", pct = 0.06 },
			},
		},
		series = {},
	},
	{
		id = 57, name = "Volcano Head", rarity = "Rare",
		stat = { atk = 1.10, hp = 0.85 }, mp = 4,
		role = "DPS", subrole = "Skirmisher", passive = "Rage",
		passive_name = "Short Fuse",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Maximum: Meteor",
			short = "Hits every enemy and sets them on fire for 3 rounds.",
			desc = "110% ATK to every enemy and sets them ablaze: 30% ATK burn at the start of each of the next 3 rounds.",
			effects = {
				{ op = "aoe_damage", mult = 1.1 },
				{ op = "dot_all", mult = 0.3, rounds = 3, name = "Burn" },
			},
		},
		series = {},
	},
	{
		id = 58, name = "The Cursed-Tool Prodigy", rarity = "Rare",
		stat = { atk = 1.05, hp = 1.05 }, mp = 3,
		role = "DPS", subrole = "Duelist", passive = "Rage",
		passive_name = "Weapon Master",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Split Soul Katana",
			short = "A big slash that deals extra damage to high-HP enemies.",
			desc = "Cuts the soul, not the body: 150% ATK + 10% of the target's Max HP to the frontline enemy.",
			effects = {
				{ op = "single_damage", mult = 1.5, targetMaxHpPct = 0.10 },
			},
		},
		series = {},
	},
	{
		id = 59, name = "The Boogie-Woogie Brother", rarity = "Rare",
		stat = { atk = 1.05, hp = 1.00 }, mp = 3,
		role = "Tank", subrole = "Juggernaut", passive = "Drain",
		passive_name = "Brotherly Grit",
		passive_desc = "Heals for a share of all damage dealt to this card (standard Drain passive).",
		active = {
			name = "Boogie Woogie",
			short = "Swaps the enemy's front and back units, then punches the new front.",
			desc = "Claps to swap the enemy frontline with their backline unit, dragging their most fragile member forward, then hits it for 120%.",
			effects = {
				{ op = "swap_front_back" },
				{ op = "single_damage", mult = 1.2 },
			},
		},
		series = { "Best Friends" },
	},
	{
		id = 60, name = "The Overtime Salaryman", rarity = "Rare",
		stat = { atk = 1.00, hp = 1.00 }, mp = 3,
		role = "Tank", subrole = "Vanguard", passive = "Drain",
		passive_name = "Overtime",
		passive_desc = "Heals for a share of all damage dealt to this card (standard Drain passive).",
		active = {
			name = "Ratio 7:3",
			short = "A guaranteed crit plus team shields. Doubles after round 6.",
			desc = "A guaranteed-crit 150% ATK strike on the frontline enemy, then shields every ally for 10% of their Max HP. Overtime: from round 6, both are doubled.",
			effects = {
				{ op = "single_damage", mult = 1.5, guaranteedCrit = true, overtimeRound = 6, overtimeMult = 2 },
				{ op = "shield_all", pct = 0.10, overtimeRound = 6, overtimeMult = 2 },
			},
		},
		series = {},
	},

	-- ── Uncommon ──
	{
		id = 61, name = "The Star-Mass Wanderer", rarity = "Uncommon",
		stat = { atk = 1.10, hp = 0.95 }, mp = 4,
		role = "DPS", subrole = "Duelist", passive = "Rage",
		passive_name = "Star Rage",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Bonbaye",
			short = "A heavy punch that grows with her own Max HP.",
			desc = "Adds mass to the punch: 150% ATK + 20% of this card's own Max HP to the frontline enemy.",
			effects = {
				{ op = "single_damage", mult = 1.5, selfMaxHpPct = 0.20 },
			},
		},
		series = {},
	},
	{
		id = 62, name = "The Jackpot Gambler", rarity = "Uncommon",
		stat = { atk = 0.95, hp = 1.10 }, mp = 3,
		role = "DPS", subrole = "Duelist", passive = "Rage",
		passive_name = "Hot Streak",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Idle Death Gamble",
			short = "Hits, and a 1-in-3 JACKPOT fully heals and casts again!",
			desc = "120% ATK to the frontline enemy. 1-in-3 JACKPOT: fully heals, +10% ATK permanently, and Fever refills mana so it casts again right away.",
			effects = {
				{ op = "jackpot", mult = 1.2, chance = 1 / 3, atkPct = 0.10, refillMana = true },
			},
		},
		series = {},
	},
	{
		id = 63, name = "The Projection Sprinter", rarity = "Uncommon",
		stat = { atk = 1.00, hp = 0.90 }, mp = 2,
		role = "DPS", subrole = "Duelist", passive = "Executioner",
		passive_name = "Frame Perfect",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "24 Frames",
			short = "Freezes the front enemy. Frozen enemies shatter for double damage.",
			desc = "140% ATK to the frontline enemy and freezes it for 1 turn. Hitting an already frozen or stunned target shatters it for +100% damage.",
			effects = {
				{ op = "single_damage", mult = 1.4, bonusVsStunned = 1.0, stunTurns = 1 },
			},
		},
		series = {},
	},
	{
		id = 64, name = "The Cursed Corpse Bear", rarity = "Uncommon",
		stat = { atk = 1.00, hp = 1.05 }, mp = 3,
		role = "Tank", subrole = "Juggernaut", passive = "Trait", trait = "three_cores",
		passive_name = "Three Cores",
		passive_short = "Switches between Tank and Gorilla form every round.",
		passive_desc = "Odd rounds: Tank form (-20% damage taken). Even rounds: Gorilla form (+25% ATK, counts as DPS for counters).",
		active = {
			name = "Drumming Beat",
			short = "Tank form: stun and shield. Gorilla form: a double punch.",
			desc = "Changes with his form. Tank form: stuns the frontline enemy for 1 turn and shields Panda for 20% Max HP. Gorilla form: two 110% hits that ignore shields.",
			effects = {
				{ op = "by_form",
					Tank = { { op = "stun", target = "front", turns = 1 }, { op = "shield_self", pct = 0.20 } },
					DPS  = { { op = "single_damage", mult = 1.1, ignoreShield = true, hits = 2 } },
				},
			},
		},
		series = {},
	},
	{
		id = 65, name = "The Reverse-Cursed Medic", rarity = "Uncommon",
		stat = { atk = 0.80, hp = 1.00 }, mp = 3,
		role = "Support", subrole = "Enchanter", passive = "Medic",
		passive_name = "Night Shift",
		passive_desc = "Heals the team's lowest-HP ally at the end of every round (standard Medic passive).",
		active = {
			name = "Reverse Cursed Technique",
			short = "A big heal on the weakest ally, a small heal for all, and removes stuns.",
			desc = "Heals the most injured ally for 40% of their Max HP, heals every ally for 8%, and cleanses stuns and silences from the team.",
			effects = {
				{ op = "heal_lowest", pct = 0.40 },
				{ op = "heal_all", pct = 0.08 },
				{ op = "cleanse" },
			},
		},
		series = {},
	},
	{
		id = 66, name = "The Onigiri Speaker", rarity = "Uncommon",
		stat = { atk = 1.00, hp = 0.95 }, mp = 4,
		role = "Support", subrole = "Hexer", passive = "Battery",
		passive_name = "Salmon Roe",
		passive_desc = "Restores 1 mana to allies whenever any unit dies (standard Battery passive).",
		active = {
			name = "Cursed Speech: Don't Move",
			short = "Stuns every enemy, but costs some of his own HP.",
			desc = "Stuns every enemy for 1 turn, but the backlash costs this card 15% of its Max HP.",
			effects = {
				{ op = "stun", target = "all", turns = 1 },
				{ op = "self_cost", pctMax = 0.15 },
			},
		},
		series = {},
	},

	-- ── Common ──
	{
		id = 67, name = "The Straw Doll Striker", rarity = "Common",
		stat = { atk = 1.00, hp = 0.95 }, mp = 3,
		role = "DPS", subrole = "Duelist", passive = "Executioner",
		passive_name = "Hairpin",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "Resonance",
			short = "Nails the front enemy. Every nail hurts again on each cast.",
			desc = "Hammers a nail into the frontline enemy (100% ATK), then every enemy with nails takes 40% ATK true damage per nail. Nails stay all battle.",
			effects = {
				{ op = "nail_resonance", mult = 1.0, perNail = 0.4 },
			},
		},
		series = { "First Years" },
	},
	{
		id = 68, name = "The Shadow Summoner", rarity = "Common",
		stat = { atk = 1.00, hp = 1.05 }, mp = 3,
		role = "DPS", subrole = "Skirmisher", passive = "Rage",
		passive_name = "Ten Shadows",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Ten Shadows",
			short = "Summons a random shikigami to attack, stun or shield.",
			desc = "Summons a random shikigami: Divine Dogs (70% to every enemy), Nue (120% to the frontline + 1-turn stun), Max Elephant (50% to every enemy, enemy ATK -5%) or Rabbit Escape (shields every ally for 6%).",
			effects = {
				{ op = "random", options = {
					{ name = "Divine Dogs", effects = { { op = "aoe_damage", mult = 0.7 } } },
					{ name = "Nue", effects = { { op = "single_damage", mult = 1.2, stunTurns = 1 } } },
					{ name = "Max Elephant", effects = { { op = "aoe_damage", mult = 0.5 }, { op = "enemy_atk_shred", pct = 0.05, cap = 0.15 } } },
					{ name = "Rabbit Escape", effects = { { op = "shield_all", pct = 0.06 } } },
				} },
			},
		},
		series = { "First Years" },
	},
	{
		id = 69, name = "The Blood Brother", rarity = "Common",
		stat = { atk = 1.00, hp = 1.05 }, mp = 3,
		role = "DPS", subrole = "Skirmisher", passive = "Rage",
		passive_name = "Eldest Brother",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Supernova",
			short = "Spends his own HP to blast every enemy.",
			desc = "Pays 10% of current HP in blood to hit every enemy for 90% ATK and shred 3% of their defense (stacking to 12%).",
			effects = {
				{ op = "self_cost", pctCurrent = 0.10 },
				{ op = "aoe_damage", mult = 0.9 },
				{ op = "enemy_dr_shred", pct = 0.03, cap = 0.12 },
			},
		},
		series = {},
	},
	{
		id = 70, name = "The Revolver Heiress", rarity = "Common",
		stat = { atk = 1.05, hp = 0.85 }, mp = 2,
		role = "DPS", subrole = "Duelist", passive = "Executioner",
		passive_name = "Sharpshooter",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "Final Bullet",
			short = "Snipes the weakest enemy. Reloads instantly on a kill.",
			desc = "160% ATK to the lowest-HP enemy. If it kills, instantly reloads (+2 mana).",
			effects = {
				{ op = "single_damage", target = "lowest", mult = 1.6, onKillMana = 2 },
			},
		},
		series = {},
	},
	{
		id = 71, name = "The Puppet Pilot", rarity = "Common",
		stat = { atk = 1.00, hp = 1.00 }, mp = 3,
		role = "Tank", subrole = "Vanguard", passive = "Drain",
		passive_name = "Heavy Armor",
		passive_desc = "Heals for a share of all damage dealt to this card (standard Drain passive).",
		active = {
			name = "Absolute Guard / Ultra Cannon",
			short = "Alternates: shield the whole team, then fire a big cannon.",
			desc = "Alternates. Absolute Guard: shields every ally for 10% of their Max HP. Ultra Cannon: 250% ATK to the frontline enemy.",
			alternate = {
				{ name = "Absolute Guard", effects = { { op = "shield_all", pct = 0.10 } } },
				{ name = "Ultra Cannon", effects = { { op = "single_damage", mult = 2.5 } } },
			},
		},
		series = {},
	},
	{
		id = 72, name = "The Solo Songstress", rarity = "Common",
		stat = { atk = 0.90, hp = 1.00 }, mp = 3,
		role = "Support", subrole = "Enchanter", passive = "Medic",
		passive_name = "Encore",
		passive_desc = "Heals the team's lowest-HP ally at the end of every round (standard Medic passive).",
		active = {
			name = "Solo Forbidden Area",
			short = "Speeds up the ally closest to casting and boosts team ATK.",
			desc = "Gives the ally closest to casting +1 mana, and every ally +4% ATK (stacking to 16%).",
			effects = {
				{ op = "grant_mana", target = "closest", amount = 1 },
				{ op = "team_atk_buff", pct = 0.04, cap = 0.16 },
			},
		},
		series = {},
	},
	{
		id = 73, name = "The Courtroom Judge", rarity = "Common",
		stat = { atk = 1.00, hp = 1.00 }, mp = 3,
		role = "Support", subrole = "Hexer", passive = "Battery",
		passive_name = "Objection",
		passive_desc = "Restores 1 mana to allies whenever any unit dies (standard Battery passive).",
		active = {
			name = "Judgeman: Confiscation",
			short = "Takes the front enemy's mana and blocks it for 2 turns.",
			desc = "Confiscates the frontline enemy's technique: wipes all its mana, and it can't gain mana for 2 turns.",
			effects = {
				{ op = "silence", turns = 2 },
			},
		},
		series = {},
	},
}

-- ── Stats from the formula (CombatConfig.CardStats) ───────────────────────────
-- attack/hp = RoleBase × RarityMult × SubroleMod × card.stat. Cards marked
-- fixedStats keep their literal numbers (The Nameless One admin card).

local CardStats = require(script.Parent:WaitForChild("CombatConfig")).CardStats

for _, card in ipairs(CardDatabase.Cards) do
	if not card.fixedStats then
		local base = CardStats.RoleBase[card.role]
		local rar  = CardStats.RarityMult[card.rarity] or 1
		local sub  = CardStats.SubroleMod[card.subrole] or { atk = 1, hp = 1 }
		local own  = card.stat or {}
		local step = CardStats.RoundTo
		card.attack = math.max(step, math.floor(base.atk * rar * sub.atk * (own.atk or 1) / step + 0.5) * step)
		card.hp     = math.max(step, math.floor(base.hp * rar * sub.hp * (own.hp or 1) / step + 0.5) * step)
	end
end

-- ── Fast lookup tables ────────────────────────────────────────────────────────

CardDatabase._byId     = {}
CardDatabase._byRarity = {}
CardDatabase._bySeries = {}

-- adminOnly cards (The Nameless One) resolve by id but never enter any
-- random pool: packs, enemy teams, reveal animations and GetAll all skip them.
CardDatabase._pool     = {}

for _, card in ipairs(CardDatabase.Cards) do
	CardDatabase._byId[card.id] = card
	if card.adminOnly then continue end
	table.insert(CardDatabase._pool, card)

	if not CardDatabase._byRarity[card.rarity] then
		CardDatabase._byRarity[card.rarity] = {}
	end
	table.insert(CardDatabase._byRarity[card.rarity], card)

	for _, syn in ipairs(card.series) do
		if not CardDatabase._bySeries[syn] then
			CardDatabase._bySeries[syn] = {}
		end
		table.insert(CardDatabase._bySeries[syn], card)
	end
end

function CardDatabase:GetById(id)
	return self._byId[id]
end

function CardDatabase:GetByRarity(rarity)
	return self._byRarity[rarity] or {}
end

function CardDatabase:GetBySeries(synName)
	return self._bySeries[synName] or {}
end

function CardDatabase:GetRandomOfRarity(rarity)
	local pool = self:GetByRarity(rarity)
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

-- Every obtainable card (excludes adminOnly). Use CardDatabase.Cards for the raw list.
function CardDatabase:GetAll()
	return self._pool
end

return CardDatabase
