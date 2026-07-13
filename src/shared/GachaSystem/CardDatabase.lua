-- 50-card database.
-- series: array of synergy group names (matches RoleConfig.Synergies keys). Can be empty or have 2 entries.
-- passive: role-passive category label (Drain | Rage | Executioner | Medic | Battery).
-- passive_desc: unique flavour description of this card's personal passive.
-- active: { name, desc } — the card's active ability.

local CardDatabase = {}

CardDatabase.Cards = {

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMMON (14)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 1, name = "Iron Soldier", rarity = "Common",
		attack = 110, hp = 480, mp = 40,
		role = "DPS", passive = "Rage",
		passive_name = "Combat High",
		passive_desc = "After each kill, gains +6% ATK for the rest of battle. Stacks up to 3 times.",
		active = { name = "Iron Charge", desc = "Rushes the frontline enemy for 140% ATK. Deals +10% per active Combat High stack." },
		series = { "Iron Legion" },
	},
	{
		id = 2, name = "Copper Knight", rarity = "Common",
		attack = 75, hp = 660, mp = 35,
		role = "Tank", passive = "Drain",
		passive_name = "Copper Guard",
		passive_desc = "Reduces all incoming damage by 6%.",
		active = { name = "Shield Bash", desc = "Stuns the frontline enemy for 1 turn and deals 80% ATK as damage." },
		series = { "Iron Legion" },
	},
	{
		id = 3, name = "Rusted Golem", rarity = "Common",
		attack = 80, hp = 720, mp = 25,
		role = "Tank", passive = "Drain",
		passive_name = "Scrap Armor",
		passive_desc = "When below 40% HP, gains +15% damage reduction.",
		active = { name = "Slam", desc = "Deals 100% ATK to the frontline enemy and reduces their ATK by 10% for 2 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 4, name = "Forest Sprite", rarity = "Common",
		attack = 65, hp = 420, mp = 85,
		role = "Support", passive = "Medic",
		passive_name = "Bloom",
		passive_desc = "Each round, heals the lowest HP ally for 3% of their Max HP.",
		active = { name = "Mending Roots", desc = "Heals all allies for 10% of their Max HP." },
		series = { "Nature's Call" },
	},
	{
		id = 5, name = "Pebble Golem", rarity = "Common",
		attack = 70, hp = 760, mp = 25,
		role = "Tank", passive = "Drain",
		passive_name = "Rocky Hide",
		passive_desc = "Absorbs up to 60 flat damage per hit before HP is reduced.",
		active = { name = "Boulder Toss", desc = "Hurls a boulder at one enemy for 110% ATK, reducing their ATK by 12% for 2 turns." },
		series = { "Ancient Ones" },
	},
	{
		id = 6, name = "Wind Imp", rarity = "Common",
		attack = 120, hp = 360, mp = 70,
		role = "DPS", passive = "Rage",
		passive_name = "Gusting Blades",
		passive_desc = "Every 4th attack deals double damage.",
		active = { name = "Gust Slash", desc = "Deals 130% ATK. If this kills the target, immediately performs one bonus attack." },
		series = { "Storm Riders" },
	},
	{
		id = 7, name = "River Eel", rarity = "Common",
		attack = 100, hp = 400, mp = 55,
		role = "DPS", passive = "Rage",
		passive_name = "Slick Scales",
		passive_desc = "12% chance to dodge incoming attacks.",
		active = { name = "Electric Current", desc = "Deals 130% ATK with a 30% chance to stun the target for 1 turn." },
		series = { "Abyssal Order" },
	},
	{
		id = 8, name = "Marsh Frog", rarity = "Common",
		attack = 95, hp = 450, mp = 60,
		role = "DPS", passive = "Executioner",
		passive_name = "Toxic Coating",
		passive_desc = "Normal attacks apply a poison dealing 5% ATK per round for 3 rounds.",
		active = { name = "Venom Burst", desc = "Poisons target for 12% ATK/round for 4 rounds. On kill, poison spreads to the next enemy." },
		series = { "Abyssal Order" },
	},
	{
		id = 9, name = "Mud Slime", rarity = "Common",
		attack = 60, hp = 810, mp = 20,
		role = "Tank", passive = "Drain",
		passive_name = "Ooze Regeneration",
		passive_desc = "Heals 2% Max HP at the end of each round.",
		active = { name = "Engulf", desc = "Coats the frontline enemy in mud, reducing their ATK by 15% and slowing them for 2 turns." },
		series = { "Abyssal Order" },
	},
	{
		id = 10, name = "Bone Scout", rarity = "Common",
		attack = 130, hp = 310, mp = 50,
		role = "DPS", passive = "Executioner",
		passive_name = "Hollow Eyes",
		passive_desc = "Deals +15% bonus damage to enemies below 50% HP.",
		active = { name = "Lethal Mark", desc = "Marks one enemy for 2 turns. All allies deal +25% damage to marked targets." },
		series = { "Shadow Covenant" },
	},
	{
		id = 11, name = "Dust Wisp", rarity = "Common",
		attack = 55, hp = 370, mp = 100,
		role = "Support", passive = "Battery",
		passive_name = "Mana Siphon",
		passive_desc = "Each time any ally lands a kill, restore 3 MP to all allies.",
		active = { name = "Void Pulse", desc = "Restores 10 MP to all allies and deals 80% ATK to one enemy." },
		series = { "Void Walkers" },
	},
	{
		id = 12, name = "Cave Bat", rarity = "Common",
		attack = 95, hp = 340, mp = 55,
		role = "DPS", passive = "Executioner",
		passive_name = "Swooping Strike",
		passive_desc = "First attack each battle deals +50% bonus damage.",
		active = { name = "Dive Bomb", desc = "Dives at the lowest HP enemy, dealing 170% ATK." },
		series = {},
	},
	{
		id = 13, name = "Stray Arrow", rarity = "Common",
		attack = 145, hp = 290, mp = 65,
		role = "DPS", passive = "Executioner",
		passive_name = "Piercing Shot",
		passive_desc = "Attacks ignore 15% of the target's defenses.",
		active = { name = "Snipe", desc = "Deals 200% ATK to the enemy with the lowest HP." },
		series = {},
	},
	{
		id = 14, name = "Bog Witch", rarity = "Common",
		attack = 60, hp = 385, mp = 95,
		role = "Support", passive = "Battery",
		passive_name = "Hex Aura",
		passive_desc = "Enemies start each round with -5% ATK (does not stack per cast).",
		active = { name = "Mana Brew", desc = "Restores 15 MP to one ally and curses one enemy, reducing their ATK by 10% for 3 turns." },
		series = {},
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- UNCOMMON (12)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 15, name = "Silver Paladin", rarity = "Uncommon",
		attack = 175, hp = 830, mp = 100,
		role = "Tank", passive = "Drain",
		passive_name = "Holy Barrier",
		passive_desc = "At the start of battle, gains a shield equal to 10% of Max HP.",
		active = { name = "Divine Shield", desc = "Grants all allies a shield equal to 8% of their Max HP lasting 2 turns." },
		series = { "Divine Pantheon" },
	},
	{
		id = 16, name = "Thornvine Druid", rarity = "Uncommon",
		attack = 155, hp = 760, mp = 135,
		role = "Support", passive = "Medic",
		passive_name = "Regrowth",
		passive_desc = "Heals a random ally for 5% of their Max HP each round.",
		active = { name = "Overgrowth", desc = "Heals all allies for 15% Max HP and applies Regeneration (3% HP/round for 3 turns)." },
		series = { "Nature's Call" },
	},
	{
		id = 17, name = "Shadow Rogue", rarity = "Uncommon",
		attack = 250, hp = 500, mp = 120,
		role = "DPS", passive = "Executioner",
		passive_name = "Backstab",
		passive_desc = "First attack on any enemy deals +35% bonus damage.",
		active = { name = "Shadow Step", desc = "Teleports behind the highest ATK enemy and strikes for 220% ATK, ignoring 25% of their defenses." },
		series = { "Shadow Covenant" },
	},
	{
		id = 18, name = "Frost Archer", rarity = "Uncommon",
		attack = 200, hp = 580, mp = 115,
		role = "DPS", passive = "Rage",
		passive_name = "Chill Shot",
		passive_desc = "20% chance on hit to slow the target, reducing their ATK by 8% for 2 turns.",
		active = { name = "Hailstorm", desc = "Fires 3 arrows at different enemies, each dealing 100% ATK." },
		series = { "Storm Riders" },
	},
	{
		id = 19, name = "Storm Drake", rarity = "Uncommon",
		attack = 215, hp = 610, mp = 130,
		role = "DPS", passive = "Executioner",
		passive_name = "Lightning Skin",
		passive_desc = "When struck, 20% chance to retaliate with a lightning bolt dealing 60% ATK to the attacker.",
		active = { name = "Thunderclap", desc = "Deals 180% ATK to one enemy and chains to adjacent enemies for 70% ATK." },
		series = { "Storm Riders" },
	},
	{
		id = 20, name = "Bone Wizard", rarity = "Uncommon",
		attack = 165, hp = 460, mp = 205,
		role = "Support", passive = "Battery",
		passive_name = "Death Siphon",
		passive_desc = "On any ally or enemy death, restores 5 MP to all allies.",
		active = { name = "Bone Surge", desc = "Deals 130% ATK to one enemy and restores 8 MP to the ally with the lowest MP." },
		series = { "Shadow Covenant" },
	},
	{
		id = 21, name = "Iron Bear", rarity = "Uncommon",
		attack = 190, hp = 920, mp = 60,
		role = "Tank", passive = "Drain",
		passive_name = "Berserker Guard",
		passive_desc = "Each time Iron Bear takes damage, gains +3% ATK (max 5 stacks per battle).",
		active = { name = "Iron Maul", desc = "Slams the frontline for 160% ATK, reducing their armor by 15% for 3 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 22, name = "Tide Serpent", rarity = "Uncommon",
		attack = 185, hp = 700, mp = 120,
		role = "Tank", passive = "Drain",
		passive_name = "Hydro Shell",
		passive_desc = "Heals 3% Max HP when taking damage (once per turn maximum).",
		active = { name = "Undertow", desc = "Pulls the backline enemy to the frontline position and deals 130% ATK to them." },
		series = { "Abyssal Order" },
	},
	{
		id = 23, name = "Verdant Fox", rarity = "Uncommon",
		attack = 235, hp = 545, mp = 115,
		role = "DPS", passive = "Executioner",
		passive_name = "Evasion",
		passive_desc = "Dodges the first attack each battle. After dodging, gains +15% ATK for 2 turns.",
		active = { name = "Feral Pounce", desc = "Leaps at the lowest HP enemy for 230% ATK, ignoring 20% of their defenses." },
		series = { "Nature's Call" },
	},
	{
		id = 24, name = "Stone Sentinel", rarity = "Uncommon",
		attack = 145, hp = 1020, mp = 70,
		role = "Tank", passive = "Drain",
		passive_name = "Fortify",
		passive_desc = "Reduces damage taken from critical hits by 50%.",
		active = { name = "Stone Wall", desc = "Taunts all enemies for 1 turn, forcing them to attack the Sentinel. Gains +20% damage reduction while taunted." },
		series = { "Iron Legion" },
	},
	{
		id = 25, name = "Dusk Witch", rarity = "Uncommon",
		attack = 210, hp = 490, mp = 185,
		role = "Support", passive = "Medic",
		passive_name = "Blood Pact",
		passive_desc = "Whenever a Shadow Covenant ally kills an enemy, heals all allies for 4% Max HP.",
		active = { name = "Dark Veil", desc = "Reduces all enemies' ATK by 15% for 3 turns and grants all allies +10% ATK." },
		series = { "Shadow Covenant" },
	},
	{
		id = 26, name = "Sky Shaman", rarity = "Uncommon",
		attack = 150, hp = 520, mp = 175,
		role = "Support", passive = "Battery",
		passive_name = "Storm Blessing",
		passive_desc = "Storm Rider allies gain +5% ATK at the start of each round.",
		active = { name = "Thunderous Rally", desc = "Grants all allies +12% ATK for 3 turns and restores 8 MP to all allies." },
		series = { "Storm Riders" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- RARE (10)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 27, name = "Aether Mage", rarity = "Rare",
		attack = 320, hp = 700, mp = 285,
		role = "Support", passive = "Battery",
		passive_name = "Arcane Surge",
		passive_desc = "Every 3 rounds, the next ability cast by any ally costs 0 MP.",
		active = { name = "Arcane Cascade", desc = "Restores 15 MP to all allies and deals 150% ATK to all enemies." },
		series = {},
	},
	{
		id = 28, name = "Golden Warden", rarity = "Rare",
		attack = 255, hp = 1120, mp = 150,
		role = "Tank", passive = "Drain",
		passive_name = "Shield Wall",
		passive_desc = "Reduces damage taken by 12%. With 3+ Iron Legion members on the team, this increases to 20%.",
		active = { name = "Bulwark", desc = "Creates a barrier that absorbs damage equal to 25% of the Warden's Max HP for all allies for 2 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 29, name = "Crimson Assassin", rarity = "Rare",
		attack = 410, hp = 600, mp = 200,
		role = "DPS", passive = "Executioner",
		passive_name = "Lethal Strike",
		passive_desc = "Critical kills (targets below 30% HP) restore 10% of the Assassin's Max HP.",
		active = { name = "Crimson Lunge", desc = "Strikes the highest ATK enemy for 300% ATK, ignoring all shields." },
		series = { "Shadow Covenant" },
	},
	{
		id = 30, name = "Tempest Falcon", rarity = "Rare",
		attack = 355, hp = 755, mp = 220,
		role = "DPS", passive = "Rage",
		passive_name = "Wind Dash",
		passive_desc = "Every 3 turns, next attack deals double damage and cannot be dodged.",
		active = { name = "Storm Dive", desc = "Dives through all enemies in a line, dealing 200% ATK to each." },
		series = { "Storm Riders" },
	},
	{
		id = 31, name = "Glacial Titan", rarity = "Rare",
		attack = 270, hp = 1320, mp = 120,
		role = "Tank", passive = "Drain",
		passive_name = "Permafrost Aura",
		passive_desc = "At the start of each round, reduces all enemies' ATK by 6%.",
		active = { name = "Glacier Crush", desc = "Deals 180% ATK to all enemies and slows them all for 1 turn." },
		series = { "Ancient Ones" },
	},
	{
		id = 32, name = "Venom Hydra", rarity = "Rare",
		attack = 310, hp = 910, mp = 170,
		role = "DPS", passive = "Executioner",
		passive_name = "Poison Cloud",
		passive_desc = "Passively emits a toxic aura that deals 4% ATK to all enemies at the start of each round.",
		active = { name = "Hydra Strike", desc = "Attacks all enemies simultaneously for 140% ATK and applies Toxic Coating to each." },
		series = { "Abyssal Order" },
	},
	{
		id = 33, name = "Moon Priestess", rarity = "Rare",
		attack = 240, hp = 860, mp = 325,
		role = "Support", passive = "Medic",
		passive_name = "Lunar Blessing",
		passive_desc = "From round 3 onward, heals all allies for 6% Max HP at the start of each round.",
		active = { name = "Moonfall", desc = "Heals all allies for 20% Max HP and grants them +10% ATK for 2 turns." },
		series = { "Divine Pantheon" },
	},
	{
		id = 34, name = "Inferno Drake", rarity = "Rare",
		attack = 375, hp = 800, mp = 200,
		role = "DPS", passive = "Rage",
		passive_name = "Blazing Scales",
		passive_desc = "Each time Inferno Drake takes damage, gains +5% ATK (up to 4 stacks per battle).",
		active = { name = "Inferno Breath", desc = "Breathes fire at all enemies for 160% ATK, applying a burn for 8% ATK/round for 2 rounds." },
		series = { "Storm Riders" },
	},
	{
		id = 35, name = "Forest Ancient", rarity = "Rare",
		attack = 280, hp = 1220, mp = 195,
		role = "Tank", passive = "Drain",
		passive_name = "Nature's Grasp",
		passive_desc = "Once every 3 rounds, roots the frontline enemy at the start of the round, preventing them from attacking for 1 turn.",
		active = { name = "Ancient Vines", desc = "Entangles all enemies, preventing their skills for 1 turn and dealing 120% ATK." },
		series = { "Nature's Call" },
	},
	{
		id = 36, name = "Sacred Ironclad", rarity = "Rare",
		attack = 265, hp = 1080, mp = 140,
		role = "Tank", passive = "Drain",
		passive_name = "Holy Fortitude",
		passive_desc = "Gains +10% damage reduction. If contributing to both Iron Legion AND Divine Pantheon synergies simultaneously, this doubles to +20%.",
		active = { name = "Sacred Vow", desc = "Takes a vow for 2 turns, redirecting 30% of all damage dealt to allies onto itself instead." },
		series = { "Iron Legion", "Divine Pantheon" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- EPIC (7)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 37, name = "Void Sorcerer", rarity = "Epic",
		attack = 590, hp = 910, mp = 510,
		role = "DPS", passive = "Executioner",
		passive_name = "Dimension Rift",
		passive_desc = "Abilities have a 25% chance to instantly recharge on use, allowing an immediate second cast.",
		active = { name = "Void Collapse", desc = "Opens a rift dealing 350% ATK to one enemy and pulls 3 random enemies into a void explosion for 120% ATK each." },
		series = { "Void Walkers" },
	},
	{
		id = 38, name = "Celestial Knight", rarity = "Epic",
		attack = 490, hp = 1550, mp = 300,
		role = "Tank", passive = "Drain",
		passive_name = "Divine Protect",
		passive_desc = "The first time any ally would be reduced to 0 HP, Celestial Knight intercepts and takes the hit instead (once per battle).",
		active = { name = "Holy Wrath", desc = "Deals 280% ATK to all enemies. Heals all allies for 8% Max HP per enemy hit." },
		series = { "Divine Pantheon", "Iron Legion" },
	},
	{
		id = 39, name = "Abyssal Leviathan", rarity = "Epic",
		attack = 630, hp = 1850, mp = 200,
		role = "Tank", passive = "Drain",
		passive_name = "Crushing Depth",
		passive_desc = "Deals +15% bonus damage for each enemy on the field currently below 50% HP.",
		active = { name = "Tidal Crush", desc = "Crashes down on all enemies dealing 220% ATK and reducing their ATK by 20% for 2 turns." },
		series = { "Abyssal Order" },
	},
	{
		id = 40, name = "Phantom Empress", rarity = "Epic",
		attack = 660, hp = 1010, mp = 455,
		role = "DPS", passive = "Executioner",
		passive_name = "Soul Sever",
		passive_desc = "Killing blow restores 15% of the Empress's Max HP and grants +10% ATK for the rest of battle (stacks).",
		active = { name = "Phantom Waltz", desc = "Passes through all enemy lines dealing 300% ATK. Becomes untargetable for 1 turn after casting." },
		series = { "Void Walkers", "Shadow Covenant" },
	},
	{
		id = 41, name = "Storm Colossus", rarity = "Epic",
		attack = 520, hp = 2050, mp = 250,
		role = "Tank", passive = "Drain",
		passive_name = "Thunder Slam",
		passive_desc = "Melee attacks have a 30% chance to stun the target for 1 turn.",
		active = { name = "Tempest Stomp", desc = "Stomps the ground for 240% ATK to all enemies, then creates a lightning field dealing 20% ATK to all enemies each round for 2 turns." },
		series = { "Storm Riders", "Ancient Ones" },
	},
	{
		id = 42, name = "Bloodmoon Vampire", rarity = "Epic",
		attack = 610, hp = 1110, mp = 385,
		role = "DPS", passive = "Rage",
		passive_name = "Life Drain II",
		passive_desc = "Heals for 20% of all damage dealt. On kill, heals for an additional 10% of Max HP.",
		active = { name = "Bloodthirst", desc = "Drains one enemy for 280% ATK and steals 25% of their remaining HP as healing." },
		series = { "Shadow Covenant", "Abyssal Order" },
	},
	{
		id = 43, name = "Ancient Golem King", rarity = "Epic",
		attack = 460, hp = 2560, mp = 150,
		role = "Tank", passive = "Drain",
		passive_name = "Earthen Core",
		passive_desc = "When below 30% HP, gains +30% damage reduction and +25% ATK simultaneously.",
		active = { name = "Seismic Crash", desc = "Leaps and crashes into all enemies for 200% ATK. If Earthen Core is active, deals 350% ATK instead." },
		series = { "Ancient Ones" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- LEGENDARY (4)
	-- ═══════════════════════════════════════════════════════════════════════════

	-- Card identities 44-50 are anime-character parodies (original names/kits
	-- clearly evocative of a popular character's signature technique, never the
	-- real trademarked name/likeness itself — see GameDesign.md's Theme note).
	-- `active.effects` is the real per-card unique kit BattleEngine executes;
	-- `active.name`/`active.desc` remain the display strings shown in UI panels.
	{
		id = 44, name = "The Ever-Rising Fist", rarity = "Legendary",
		attack = 920, hp = 2020, mp = 610,
		role = "DPS", passive = "Rage",
		passive_name = "Never Backs Down",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Limit Breaker",
			desc = "Unleashes a world-shaking barrage on every foe for 400% ATK, growing permanently stronger (+5% ATK) with each cast.",
			effects = {
				{ op = "aoe_damage", mult = 4.0 },
				{ op = "stack_atk_buff", pct = 0.05 },
			},
		},
		series = { "Ancient Ones", "Storm Riders" },
	},
	{
		id = 45, name = "The Hundred-Heal Sage", rarity = "Legendary",
		attack = 790, hp = 2560, mp = 820,
		role = "Support", passive = "Medic",
		passive_name = "Steady Hands",
		passive_desc = "Heals the team's lowest-HP ally at the end of every round (standard Medic passive).",
		active = {
			name = "Century Seal Release",
			desc = "Releases a lifetime of stored vitality — fully restores the lowest HP ally and shields the whole team for 20% Max HP.",
			effects = {
				{ op = "heal_lowest", pct = 1.0 },
				{ op = "shield_all", pct = 0.20 },
			},
		},
		series = { "Divine Pantheon", "Nature's Call" },
	},
	{
		id = 46, name = "The Honored Guy", rarity = "Legendary",
		attack = 1010, hp = 1820, mp = 715,
		role = "DPS", passive = "Executioner",
		passive_name = "Nothing Gets Close",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "Nothing Gets Through",
			desc = "An unblockable, unavoidable strike for 500% true damage — instantly ends any foe already below 25% HP.",
			effects = {
				{ op = "single_true_execute", mult = 5.0, executeThreshold = 0.25 },
			},
		},
		series = { "Void Walkers", "Shadow Covenant" },
	},
	{
		id = 47, name = "Iron Gill, the Tide Warden", rarity = "Legendary",
		attack = 740, hp = 3580, mp = 400,
		role = "Tank", passive = "Drain",
		passive_name = "Living Current",
		passive_desc = "Heals for a share of all damage dealt to this card (standard Drain passive).",
		active = {
			name = "Tidal Guard",
			desc = "A wall of living current — shields the whole team for 15% Max HP and permanently saps 4% ATK from every enemy (stacking to -20%).",
			effects = {
				{ op = "shield_all", pct = 0.15 },
				{ op = "enemy_atk_shred", pct = 0.04, cap = 0.20 },
			},
		},
		series = { "Abyssal Order", "Ancient Ones" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MYTHIC (1)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 48, name = "The Illusion Sovereign", rarity = "Mythic",
		attack = 1520, hp = 4100, mp = 1250,
		role = "DPS", passive = "Rage",
		passive_name = "Every Move Foreseen",
		passive_desc = "Gains a stacking ATK bonus with every attack landed this battle (standard Rage passive).",
		active = {
			name = "Absolute Hypnosis",
			desc = "By the time you realize you've been struck, it already happened a hundred times over — 350% ATK to all enemies, always a critical hit, permanently shredding 6% defense from every foe hit (stacking to -30%).",
			effects = {
				{ op = "aoe_damage", mult = 3.5, guaranteedCrit = true },
				{ op = "enemy_dr_shred", pct = 0.06, cap = 0.30 },
			},
		},
		series = { "Void Walkers" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- GOD (1)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 49, name = "World Cutter", rarity = "God",
		attack = 2600, hp = 8200, mp = 2100,
		role = "DPS", passive = "Executioner",
		passive_name = "No Mercy for the Weak",
		passive_desc = "Deals amplified damage to targets already below 35% HP (standard Executioner passive).",
		active = {
			name = "Domainless Cleave",
			desc = "No domain, no barrier, no defense has ever been enough — 800% true damage to every enemy, permanently cleaving 10% off their Max HP.",
			effects = {
				{ op = "true_damage_all", mult = 8.0 },
				{ op = "maxhp_shred_all", pct = 0.10 },
			},
		},
		series = {},
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SECRET (1)
	-- ═══════════════════════════════════════════════════════════════════════════

	-- Decision (Phase 0 audit): the "???" text and absurd 9999/9999/9999 stats
	-- are an intentional mystery/novelty card, not an unfinished one — keep the
	-- flavor. Phase 3 gives it a real kit: mechanically it quietly out-powers
	-- even the flashy God-tier card (#49), playing into the "unknown, possibly
	-- absurd power" joke the stats already set up — Secret outranks God in
	-- RarityConfig's own order, so this is consistent with the rarity, not
	-- just a gag.
	{
		id = 50, name = "The Nameless One", rarity = "Secret",
		attack = 9999, hp = 9999, mp = 9999,
		role = "DPS", passive = "Rage",
		passive_name = "???",
		passive_desc = "Its true nature is unknown.",
		active = {
			name = "???",
			desc = "Unknown.",
			effects = {
				{ op = "true_damage_all", mult = 10.0 },
				{ op = "maxhp_shred_all", pct = 0.15 },
				{ op = "stack_atk_buff", pct = 0.10 },
			},
		},
		series = {},
	},
}

-- ── Fast lookup tables ────────────────────────────────────────────────────────

CardDatabase._byId     = {}
CardDatabase._byRarity = {}
CardDatabase._bySeries = {}

for _, card in ipairs(CardDatabase.Cards) do
	CardDatabase._byId[card.id] = card

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

function CardDatabase:GetAll()
	return self.Cards
end

return CardDatabase
