-- Card database: 48 placeholder cards (ids 1-50) + the JJK pillar (26 cards,
-- ids 46/49 reworked in place + 51-74). Card rules: AnimeRosterPlan.md §11.
-- series: array of synergy group names (matches RoleConfig.Synergies keys). Can be empty or have 2 entries.
-- stat: { atk, hp } personality modifiers (~0.85-1.15); attack/hp are computed
--   from CombatConfig.CardStats at require time (fixedStats = true opts out).
-- mp: mana cost of the active, in whole points (2-5). +1 mana per swing landed.
-- subrole: Duelist | Skirmisher (DPS), Vanguard | Juggernaut (Tank), Enchanter | Hexer (Support).
-- passive: role-passive category label (Drain | Rage | Executioner | Medic | Battery),
--   or "Trait" when the card has a unique trait instead (see `trait`).
-- trait: unique passive id handled by BattleEngine (numbers in CombatConfig.Traits).
-- passive_desc: unique flavour description of this card's personal passive.
-- active: { name, desc, effects? } — the card's active ability; `effects` is
--   the real kit BattleEngine runs (cards without it use the generic role active).

local CardDatabase = {}

CardDatabase.Cards = {

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMMON (14)
	-- ═══════════════════════════════════════════════════════════════════════════

	{
		id = 1, name = "Iron Soldier", rarity = "Common",
		stat = { atk = 0.97, hp = 1.15 }, mp = 3,
		role = "DPS", passive = "Rage",
		passive_name = "Combat High",
		passive_desc = "After each kill, gains +6% ATK for the rest of battle. Stacks up to 3 times.",
		active = { name = "Iron Charge", desc = "Rushes the frontline enemy for 140% ATK. Deals +10% per active Combat High stack." },
		series = { "Iron Legion" },
	},
	{
		id = 2, name = "Copper Knight", rarity = "Common",
		stat = { atk = 1.05, hp = 0.89 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Copper Guard",
		passive_desc = "Reduces all incoming damage by 6%.",
		active = { name = "Shield Bash", desc = "Stuns the frontline enemy for 1 turn and deals 80% ATK as damage." },
		series = { "Iron Legion" },
	},
	{
		id = 3, name = "Rusted Golem", rarity = "Common",
		stat = { atk = 1.12, hp = 0.98 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Scrap Armor",
		passive_desc = "When below 40% HP, gains +15% damage reduction.",
		active = { name = "Slam", desc = "Deals 100% ATK to the frontline enemy and reduces their ATK by 10% for 2 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 4, name = "Forest Sprite", rarity = "Common",
		stat = { atk = 1.08, hp = 1.07 }, mp = 4,
		role = "Support", passive = "Medic",
		passive_name = "Bloom",
		passive_desc = "Each round, heals the lowest HP ally for 3% of their Max HP.",
		active = { name = "Mending Roots", desc = "Heals all allies for 10% of their Max HP." },
		series = { "Nature's Call" },
	},
	{
		id = 5, name = "Pebble Golem", rarity = "Common",
		stat = { atk = 0.98, hp = 1.03 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Rocky Hide",
		passive_desc = "Absorbs up to 60 flat damage per hit before HP is reduced.",
		active = { name = "Boulder Toss", desc = "Hurls a boulder at one enemy for 110% ATK, reducing their ATK by 12% for 2 turns." },
		series = { "Ancient Ones" },
	},
	{
		id = 6, name = "Wind Imp", rarity = "Common",
		stat = { atk = 1.06, hp = 0.96 }, mp = 4,
		role = "DPS", passive = "Rage",
		passive_name = "Gusting Blades",
		passive_desc = "Every 4th attack deals double damage.",
		active = { name = "Gust Slash", desc = "Deals 130% ATK. If this kills the target, immediately performs one bonus attack." },
		series = { "Storm Riders" },
	},
	{
		id = 7, name = "River Eel", rarity = "Common",
		stat = { atk = 0.88, hp = 1.06 }, mp = 3,
		role = "DPS", passive = "Rage",
		passive_name = "Slick Scales",
		passive_desc = "12% chance to dodge incoming attacks.",
		active = { name = "Electric Current", desc = "Deals 130% ATK with a 30% chance to stun the target for 1 turn." },
		series = { "Abyssal Order" },
	},
	{
		id = 8, name = "Marsh Frog", rarity = "Common",
		stat = { atk = 0.85, hp = 1.15 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Toxic Coating",
		passive_desc = "Normal attacks apply a poison dealing 5% ATK per round for 3 rounds.",
		active = { name = "Venom Burst", desc = "Poisons target for 12% ATK/round for 4 rounds. On kill, poison spreads to the next enemy." },
		series = { "Abyssal Order" },
	},
	{
		id = 9, name = "Mud Slime", rarity = "Common",
		stat = { atk = 0.85, hp = 1.10 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Ooze Regeneration",
		passive_desc = "Heals 2% Max HP at the end of each round.",
		active = { name = "Engulf", desc = "Coats the frontline enemy in mud, reducing their ATK by 15% and slowing them for 2 turns." },
		series = { "Abyssal Order" },
	},
	{
		id = 10, name = "Bone Scout", rarity = "Common",
		stat = { atk = 1.14, hp = 0.85 }, mp = 3,
		role = "DPS", passive = "Executioner",
		passive_name = "Hollow Eyes",
		passive_desc = "Deals +15% bonus damage to enemies below 50% HP.",
		active = { name = "Lethal Mark", desc = "Marks one enemy for 2 turns. All allies deal +25% damage to marked targets." },
		series = { "Shadow Covenant" },
	},
	{
		id = 11, name = "Dust Wisp", rarity = "Common",
		stat = { atk = 0.92, hp = 0.94 }, mp = 4,
		role = "Support", passive = "Battery",
		passive_name = "Mana Siphon",
		passive_desc = "Each time any ally lands a kill, restore 3 MP to all allies.",
		active = { name = "Void Pulse", desc = "Restores 10 MP to all allies and deals 80% ATK to one enemy." },
		series = { "Void Walkers" },
	},
	{
		id = 12, name = "Cave Bat", rarity = "Common",
		stat = { atk = 0.85, hp = 0.90 }, mp = 3,
		role = "DPS", passive = "Executioner",
		passive_name = "Swooping Strike",
		passive_desc = "First attack each battle deals +50% bonus damage.",
		active = { name = "Dive Bomb", desc = "Dives at the lowest HP enemy, dealing 170% ATK." },
		series = {},
	},
	{
		id = 13, name = "Stray Arrow", rarity = "Common",
		stat = { atk = 1.15, hp = 0.85 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Piercing Shot",
		passive_desc = "Attacks ignore 15% of the target's defenses.",
		active = { name = "Snipe", desc = "Deals 200% ATK to the enemy with the lowest HP." },
		series = {},
	},
	{
		id = 14, name = "Bog Witch", rarity = "Common",
		stat = { atk = 1.00, hp = 0.98 }, mp = 4,
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
		stat = { atk = 1.01, hp = 0.96 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Holy Barrier",
		passive_desc = "At the start of battle, gains a shield equal to 10% of Max HP.",
		active = { name = "Divine Shield", desc = "Grants all allies a shield equal to 8% of their Max HP lasting 2 turns." },
		series = { "Divine Pantheon" },
	},
	{
		id = 16, name = "Thornvine Druid", rarity = "Uncommon",
		stat = { atk = 0.91, hp = 1.15 }, mp = 4,
		role = "Support", passive = "Medic",
		passive_name = "Regrowth",
		passive_desc = "Heals a random ally for 5% of their Max HP each round.",
		active = { name = "Overgrowth", desc = "Heals all allies for 15% Max HP and applies Regeneration (3% HP/round for 3 turns)." },
		series = { "Nature's Call" },
	},
	{
		id = 17, name = "Shadow Rogue", rarity = "Uncommon",
		stat = { atk = 1.11, hp = 0.89 }, mp = 3,
		role = "DPS", passive = "Executioner",
		passive_name = "Backstab",
		passive_desc = "First attack on any enemy deals +35% bonus damage.",
		active = { name = "Shadow Step", desc = "Teleports behind the highest ATK enemy and strikes for 220% ATK, ignoring 25% of their defenses." },
		series = { "Shadow Covenant" },
	},
	{
		id = 18, name = "Frost Archer", rarity = "Uncommon",
		stat = { atk = 0.89, hp = 1.04 }, mp = 3,
		role = "DPS", passive = "Rage",
		passive_name = "Chill Shot",
		passive_desc = "20% chance on hit to slow the target, reducing their ATK by 8% for 2 turns.",
		active = { name = "Hailstorm", desc = "Fires 3 arrows at different enemies, each dealing 100% ATK." },
		series = { "Storm Riders" },
	},
	{
		id = 19, name = "Storm Drake", rarity = "Uncommon",
		stat = { atk = 0.96, hp = 1.09 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Lightning Skin",
		passive_desc = "When struck, 20% chance to retaliate with a lightning bolt dealing 60% ATK to the attacker.",
		active = { name = "Thunderclap", desc = "Deals 180% ATK to one enemy and chains to adjacent enemies for 70% ATK." },
		series = { "Storm Riders" },
	},
	{
		id = 20, name = "Bone Wizard", rarity = "Uncommon",
		stat = { atk = 0.97, hp = 0.85 }, mp = 4,
		role = "Support", passive = "Battery",
		passive_name = "Death Siphon",
		passive_desc = "On any ally or enemy death, restores 5 MP to all allies.",
		active = { name = "Bone Surge", desc = "Deals 130% ATK to one enemy and restores 8 MP to the ally with the lowest MP." },
		series = { "Shadow Covenant" },
	},
	{
		id = 21, name = "Iron Bear", rarity = "Uncommon",
		stat = { atk = 1.09, hp = 1.06 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Berserker Guard",
		passive_desc = "Each time Iron Bear takes damage, gains +3% ATK (max 5 stacks per battle).",
		active = { name = "Iron Maul", desc = "Slams the frontline for 160% ATK, reducing their armor by 15% for 3 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 22, name = "Tide Serpent", rarity = "Uncommon",
		stat = { atk = 1.06, hp = 0.85 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Hydro Shell",
		passive_desc = "Heals 3% Max HP when taking damage (once per turn maximum).",
		active = { name = "Undertow", desc = "Pulls the backline enemy to the frontline position and deals 130% ATK to them." },
		series = { "Abyssal Order" },
	},
	{
		id = 23, name = "Verdant Fox", rarity = "Uncommon",
		stat = { atk = 1.04, hp = 0.98 }, mp = 3,
		role = "DPS", passive = "Executioner",
		passive_name = "Evasion",
		passive_desc = "Dodges the first attack each battle. After dodging, gains +15% ATK for 2 turns.",
		active = { name = "Feral Pounce", desc = "Leaps at the lowest HP enemy for 230% ATK, ignoring 20% of their defenses." },
		series = { "Nature's Call" },
	},
	{
		id = 24, name = "Stone Sentinel", rarity = "Uncommon",
		stat = { atk = 0.85, hp = 1.15 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Fortify",
		passive_desc = "Reduces damage taken from critical hits by 50%.",
		active = { name = "Stone Wall", desc = "Taunts all enemies for 1 turn, forcing them to attack the Sentinel. Gains +20% damage reduction while taunted." },
		series = { "Iron Legion" },
	},
	{
		id = 25, name = "Dusk Witch", rarity = "Uncommon",
		stat = { atk = 1.15, hp = 0.88 }, mp = 4,
		role = "Support", passive = "Medic",
		passive_name = "Blood Pact",
		passive_desc = "Whenever a Shadow Covenant ally kills an enemy, heals all allies for 4% Max HP.",
		active = { name = "Dark Veil", desc = "Reduces all enemies' ATK by 15% for 3 turns and grants all allies +10% ATK." },
		series = { "Shadow Covenant" },
	},
	{
		id = 26, name = "Sky Shaman", rarity = "Uncommon",
		stat = { atk = 0.88, hp = 0.93 }, mp = 4,
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
		stat = { atk = 1.14, hp = 0.90 }, mp = 4,
		role = "Support", passive = "Battery",
		passive_name = "Arcane Surge",
		passive_desc = "Every 3 rounds, the next ability cast by any ally costs 0 MP.",
		active = { name = "Arcane Cascade", desc = "Restores 15 MP to all allies and deals 150% ATK to all enemies." },
		series = {},
	},
	{
		id = 28, name = "Golden Warden", rarity = "Rare",
		stat = { atk = 0.95, hp = 0.95 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Shield Wall",
		passive_desc = "Reduces damage taken by 12%. With 3+ Iron Legion members on the team, this increases to 20%.",
		active = { name = "Bulwark", desc = "Creates a barrier that absorbs damage equal to 25% of the Warden's Max HP for all allies for 2 turns." },
		series = { "Iron Legion" },
	},
	{
		id = 29, name = "Crimson Assassin", rarity = "Rare",
		stat = { atk = 1.13, hp = 0.85 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Lethal Strike",
		passive_desc = "Critical kills (targets below 30% HP) restore 10% of the Assassin's Max HP.",
		active = { name = "Crimson Lunge", desc = "Strikes the highest ATK enemy for 300% ATK, ignoring all shields." },
		series = { "Shadow Covenant" },
	},
	{
		id = 30, name = "Tempest Falcon", rarity = "Rare",
		stat = { atk = 0.98, hp = 0.99 }, mp = 4,
		role = "DPS", passive = "Rage",
		passive_name = "Wind Dash",
		passive_desc = "Every 3 turns, next attack deals double damage and cannot be dodged.",
		active = { name = "Storm Dive", desc = "Dives through all enemies in a line, dealing 200% ATK to each." },
		series = { "Storm Riders" },
	},
	{
		id = 31, name = "Glacial Titan", rarity = "Rare",
		stat = { atk = 1.01, hp = 1.11 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Permafrost Aura",
		passive_desc = "At the start of each round, reduces all enemies' ATK by 6%.",
		active = { name = "Glacier Crush", desc = "Deals 180% ATK to all enemies and slows them all for 1 turn." },
		series = { "Ancient Ones" },
	},
	{
		id = 32, name = "Venom Hydra", rarity = "Rare",
		stat = { atk = 0.86, hp = 1.15 }, mp = 3,
		role = "DPS", passive = "Executioner",
		passive_name = "Poison Cloud",
		passive_desc = "Passively emits a toxic aura that deals 4% ATK to all enemies at the start of each round.",
		active = { name = "Hydra Strike", desc = "Attacks all enemies simultaneously for 140% ATK and applies Toxic Coating to each." },
		series = { "Abyssal Order" },
	},
	{
		id = 33, name = "Moon Priestess", rarity = "Rare",
		stat = { atk = 0.86, hp = 1.10 }, mp = 4,
		role = "Support", passive = "Medic",
		passive_name = "Lunar Blessing",
		passive_desc = "From round 3 onward, heals all allies for 6% Max HP at the start of each round.",
		active = { name = "Moonfall", desc = "Heals all allies for 20% Max HP and grants them +10% ATK for 2 turns." },
		series = { "Divine Pantheon" },
	},
	{
		id = 34, name = "Inferno Drake", rarity = "Rare",
		stat = { atk = 1.03, hp = 1.04 }, mp = 4,
		role = "DPS", passive = "Rage",
		passive_name = "Blazing Scales",
		passive_desc = "Each time Inferno Drake takes damage, gains +5% ATK (up to 4 stacks per battle).",
		active = { name = "Inferno Breath", desc = "Breathes fire at all enemies for 160% ATK, applying a burn for 8% ATK/round for 2 rounds." },
		series = { "Storm Riders" },
	},
	{
		id = 35, name = "Forest Ancient", rarity = "Rare",
		stat = { atk = 1.05, hp = 1.03 }, mp = 3,
		role = "Tank", passive = "Drain",
		passive_name = "Nature's Grasp",
		passive_desc = "Once every 3 rounds, roots the frontline enemy at the start of the round, preventing them from attacking for 1 turn.",
		active = { name = "Ancient Vines", desc = "Entangles all enemies, preventing their skills for 1 turn and dealing 120% ATK." },
		series = { "Nature's Call" },
	},
	{
		id = 36, name = "Sacred Ironclad", rarity = "Rare",
		stat = { atk = 0.99, hp = 0.91 }, mp = 3,
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
		stat = { atk = 0.95, hp = 0.90 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Dimension Rift",
		passive_desc = "Abilities have a 25% chance to instantly recharge on use, allowing an immediate second cast.",
		active = { name = "Void Collapse", desc = "Opens a rift dealing 350% ATK to one enemy and pulls 3 random enemies into a void explosion for 120% ATK each." },
		series = { "Void Walkers" },
	},
	{
		id = 38, name = "Celestial Knight", rarity = "Epic",
		stat = { atk = 0.93, hp = 0.85 }, mp = 4,
		role = "Tank", passive = "Drain",
		passive_name = "Divine Protect",
		passive_desc = "The first time any ally would be reduced to 0 HP, Celestial Knight intercepts and takes the hit instead (once per battle).",
		active = { name = "Holy Wrath", desc = "Deals 280% ATK to all enemies. Heals all allies for 8% Max HP per enemy hit." },
		series = { "Divine Pantheon", "Iron Legion" },
	},
	{
		id = 39, name = "Abyssal Leviathan", rarity = "Epic",
		stat = { atk = 1.15, hp = 0.92 }, mp = 4,
		role = "Tank", passive = "Drain",
		passive_name = "Crushing Depth",
		passive_desc = "Deals +15% bonus damage for each enemy on the field currently below 50% HP.",
		active = { name = "Tidal Crush", desc = "Crashes down on all enemies dealing 220% ATK and reducing their ATK by 20% for 2 turns." },
		series = { "Abyssal Order" },
	},
	{
		id = 40, name = "Phantom Empress", rarity = "Epic",
		stat = { atk = 1.06, hp = 1.00 }, mp = 4,
		role = "DPS", passive = "Executioner",
		passive_name = "Soul Sever",
		passive_desc = "Killing blow restores 15% of the Empress's Max HP and grants +10% ATK for the rest of battle (stacks).",
		active = { name = "Phantom Waltz", desc = "Passes through all enemy lines dealing 300% ATK. Becomes untargetable for 1 turn after casting." },
		series = { "Void Walkers", "Shadow Covenant" },
	},
	{
		id = 41, name = "Storm Colossus", rarity = "Epic",
		stat = { atk = 0.99, hp = 1.02 }, mp = 4,
		role = "Tank", passive = "Drain",
		passive_name = "Thunder Slam",
		passive_desc = "Melee attacks have a 30% chance to stun the target for 1 turn.",
		active = { name = "Tempest Stomp", desc = "Stomps the ground for 240% ATK to all enemies, then creates a lightning field dealing 20% ATK to all enemies each round for 2 turns." },
		series = { "Storm Riders", "Ancient Ones" },
	},
	{
		id = 42, name = "Bloodmoon Vampire", rarity = "Epic",
		stat = { atk = 0.98, hp = 1.10 }, mp = 4,
		role = "DPS", passive = "Rage",
		passive_name = "Life Drain II",
		passive_desc = "Heals for 20% of all damage dealt. On kill, heals for an additional 10% of Max HP.",
		active = { name = "Bloodthirst", desc = "Drains one enemy for 280% ATK and steals 25% of their remaining HP as healing." },
		series = { "Shadow Covenant", "Abyssal Order" },
	},
	{
		id = 43, name = "Ancient Golem King", rarity = "Epic",
		stat = { atk = 0.88, hp = 1.15 }, mp = 4,
		role = "Tank", passive = "Drain",
		passive_name = "Earthen Core",
		passive_desc = "When below 30% HP, gains +30% damage reduction and +25% ATK simultaneously.",
		active = { name = "Seismic Crash", desc = "Leaps and crashes into all enemies for 200% ATK. If Earthen Core is active, deals 350% ATK instead." },
		series = { "Ancient Ones" },
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- LEGENDARY (3)
	-- ═══════════════════════════════════════════════════════════════════════════

	-- Card identities 44-50 are anime-character parodies (original names/kits
	-- clearly evocative of a popular character's signature technique, never the
	-- real trademarked name/likeness itself — see GameDesign.md's Theme note).
	-- `active.effects` is the real per-card unique kit BattleEngine executes;
	-- `active.name`/`active.desc` remain the display strings shown in UI panels.
	{
		id = 44, name = "The Ever-Rising Fist", rarity = "Legendary",
		stat = { atk = 1.00, hp = 1.00 }, mp = 4,
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
		stat = { atk = 1.00, hp = 1.00 }, mp = 4,
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
		id = 47, name = "Iron Gill, the Tide Warden", rarity = "Legendary",
		stat = { atk = 1.00, hp = 1.00 }, mp = 4,
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
		stat = { atk = 1.00, hp = 1.00 }, mp = 4,
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
		attack = 9999, hp = 9999, mp = 5, fixedStats = true, adminOnly = true,
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
		passive_desc = "Each hit from the same enemy makes that enemy's later hits on it deal 10% less (up to 50%).",
		active = {
			name = "Sword of Extermination",
			desc = "Deals 400% ATK true damage to the frontline enemy and stuns it for 1 turn.",
			effects = {
				{ op = "single_damage", mult = 4.0, trueDamage = true },
				{ op = "stun", target = "front", turns = 1 },
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
		passive_desc = "Every basic attack also slashes the next enemy in line for 50% ATK.",
		active = {
			name = "Malevolent Shrine",
			desc = "Deals 600% ATK true damage to every enemy and permanently cuts 10% off their Max HP.",
			effects = {
				{ op = "true_damage_all", mult = 6.0 },
				{ op = "maxhp_shred_all", pct = 0.10 },
			},
		},
		series = {},
	},
	{
		id = 46, name = "The Honored One", rarity = "God",
		stat = { atk = 1.05, hp = 1.10 }, mp = 5,
		role = "DPS", subrole = "Skirmisher", passive = "Trait", trait = "infinity",
		passive_name = "Infinity",
		passive_desc = "The first hit this card takes each round deals no damage.",
		active = {
			name = "Hollow Purple",
			desc = "Deals 500% ATK to every enemy and stuns them all for 1 turn.",
			effects = {
				{ op = "aoe_damage", mult = 5.0 },
				{ op = "stun", target = "all", turns = 1 },
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
		passive_desc = "The first attack each turn strikes twice. The second swing deals the first swing's damage + 0.8% of the target's current HP. Both swings give mana.",
		active = {
			name = "Black Flash",
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
		passive_desc = "The first time this card would die, it survives at 1 HP and gains a shield worth 30% of its Max HP.",
		active = {
			name = "Pure Love",
			desc = "Deals 350% ATK to every enemy.",
			effects = {
				{ op = "aoe_damage", mult = 3.5 },
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
		passive_desc = "Can't be stunned, ignores enemy ATK debuffs, and has +10% crit chance.",
		active = {
			name = "Inverted Spear",
			desc = "Deals 300% ATK to the lowest-HP enemy, ignoring shields.",
			effects = {
				{ op = "single_damage", target = "lowest", mult = 3.0, ignoreShield = true },
			},
		},
		series = {},
	},
	{
		id = 54, name = "The Stitched-Brow Schemer", rarity = "Epic",
		stat = { atk = 1.00, hp = 1.05 }, mp = 4,
		role = "Support", subrole = "Hexer", passive = "Trait", trait = "thousand_year_plan",
		passive_name = "Thousand-Year Plan",
		passive_desc = "Gains 1 mana whenever an enemy casts an ability.",
		active = {
			name = "Maximum Uzumaki",
			desc = "Deals 150% ATK to every enemy and shreds 5% of their defense (stacking to 20%).",
			effects = {
				{ op = "aoe_damage", mult = 1.5 },
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
		passive_desc = "All allies start the battle with 1 mana.",
		active = {
			name = "Spirit Swarm",
			desc = "Gives every other ally 1 mana and +6% ATK (stacking to 18%).",
			effects = {
				{ op = "grant_mana", amount = 1, excludeSelf = true },
				{ op = "team_atk_buff", pct = 0.06, cap = 0.18 },
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
			desc = "Reshapes souls: 120% ATK true damage to every enemy.",
			effects = {
				{ op = "true_damage_all", mult = 1.2 },
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
			desc = "Drops a meteor on the enemy team: 160% ATK to every enemy.",
			effects = {
				{ op = "aoe_damage", mult = 1.6 },
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
			desc = "Deals 250% ATK to the frontline enemy.",
			effects = {
				{ op = "single_damage", mult = 2.5 },
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
			desc = "A clap that scrambles the battlefield: 120% ATK to the frontline enemy and stuns it for 1 turn.",
			effects = {
				{ op = "single_damage", mult = 1.2 },
				{ op = "stun", target = "front", turns = 1 },
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
			desc = "A guaranteed critical 150% ATK strike on the frontline enemy, then shields every ally for 10% of their Max HP.",
			effects = {
				{ op = "single_damage", mult = 1.5, guaranteedCrit = true },
				{ op = "shield_all", pct = 0.10 },
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
			desc = "A mass-loaded punch: 280% ATK to the frontline enemy.",
			effects = {
				{ op = "single_damage", mult = 2.8 },
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
			desc = "120% ATK to the frontline enemy. 1-in-3 jackpot: fully heals and gains +10% ATK permanently.",
			effects = {
				{ op = "jackpot", mult = 1.2, chance = 1 / 3, atkPct = 0.10 },
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
			desc = "140% ATK to the frontline enemy and freezes (stuns) it for 1 turn.",
			effects = {
				{ op = "single_damage", mult = 1.4 },
				{ op = "stun", target = "front", turns = 1 },
			},
		},
		series = {},
	},
	{
		id = 64, name = "The Cursed Corpse Bear", rarity = "Uncommon",
		stat = { atk = 1.00, hp = 1.05 }, mp = 3,
		role = "Tank", subrole = "Juggernaut", passive = "Trait", trait = "three_cores",
		passive_name = "Three Cores",
		passive_desc = "Odd rounds: Tank form (-20% damage taken). Even rounds: Gorilla form (+25% ATK, counts as DPS for counters).",
		active = {
			name = "Drumming Beat",
			desc = "150% ATK to the frontline enemy and stuns it for 1 turn.",
			effects = {
				{ op = "single_damage", mult = 1.5 },
				{ op = "stun", target = "front", turns = 1 },
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
			desc = "Heals every ally for 14% of their Max HP.",
			effects = {
				{ op = "heal_all", pct = 0.14 },
			},
		},
		series = {},
	},
	{
		id = 66, name = "The Onigiri Speaker", rarity = "Uncommon",
		stat = { atk = 1.00, hp = 0.95 }, mp = 3,
		role = "Support", subrole = "Hexer", passive = "Battery",
		passive_name = "Salmon Roe",
		passive_desc = "Restores 1 mana to allies whenever any unit dies (standard Battery passive).",
		active = {
			name = "Cursed Speech: Don't Move",
			desc = "Stuns the frontline enemy for 1 turn and cuts enemy ATK by 4% (stacking to 12%).",
			effects = {
				{ op = "stun", target = "front", turns = 1 },
				{ op = "enemy_atk_shred", pct = 0.04, cap = 0.12 },
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
			desc = "Strikes the soul through a straw doll: 150% ATK true damage to the frontline enemy.",
			effects = {
				{ op = "single_damage", mult = 1.5, trueDamage = true },
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
			name = "Divine Dogs",
			desc = "Shadow hounds maul the enemy team: 70% ATK to every enemy.",
			effects = {
				{ op = "aoe_damage", mult = 0.7 },
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
			desc = "60% ATK to every enemy and shreds 3% of their defense (stacking to 12%).",
			effects = {
				{ op = "aoe_damage", mult = 0.6 },
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
			desc = "160% ATK to the lowest-HP enemy.",
			effects = {
				{ op = "single_damage", target = "lowest", mult = 1.6 },
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
			name = "Absolute Guard",
			desc = "Shields every ally for 8% of their Max HP.",
			effects = {
				{ op = "shield_all", pct = 0.08 },
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
			desc = "Every ally gains +4% ATK (stacking to 16%).",
			effects = {
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
			name = "Confiscation",
			desc = "Drains 2 mana from the frontline enemy.",
			effects = {
				{ op = "drain_mana", target = "front", amount = 2 },
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
