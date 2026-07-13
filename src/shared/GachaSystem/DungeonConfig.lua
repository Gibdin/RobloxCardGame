-- Dungeon run constants: map generation, XP/leveling, gold economy, elite buff
-- pool, shop item pool, rewards, and enemy scaling. Edit values here to
-- rebalance dungeon runs. The buff pool is shared with the Endless Tower.

local DungeonConfig = {}

-- ── Map generation ────────────────────────────────────────────────────────────
DungeonConfig.Map = {
	Rows = 12,                     -- regular rows; row Rows+1 is the single Boss node
	NodesPerRow = { { n = 2, w = 25 }, { n = 3, w = 50 }, { n = 4, w = 25 } },
	-- Node type weights for rows 2..Rows. Row 1 is always all-Mob.
	TypeWeights = { Mob = 55, Elite = 18, Shop = 15, Rest = 12 },
	EliteMinRow = 4,               -- no elites before this row
	-- Post-pass guarantees (convert random Mob nodes if short).
	MinShops = 2, MinElites = 2, MinRests = 1,
	-- Master on/off switch per node type (set false to fall back to Mob generation).
	EnabledTypes = { Mob = true, Elite = true, Shop = true, Rest = true },
}

-- ── Card XP / leveling (run-scoped) ───────────────────────────────────────────
DungeonConfig.Levels = {
	Cap = 10,
	XpForLevel = function(level) return 100 * level end,  -- XP to go from level L to L+1
	StatPerLevel = 0.08,           -- +ATK and +MaxHP per level above 1
	DeadXpPct = 0.5,               -- cards dead at battle end earn this fraction
}
DungeonConfig.XpAward = {
	Mob   = function(row) return 90 + 18 * row end,
	Elite = function(row) return math.floor((90 + 18 * row) * 1.6) end,
	Boss  = function() return 600 end,
}

-- ── Gold economy ──────────────────────────────────────────────────────────────
DungeonConfig.Gold = {
	Start = 100,
	Mob   = function(row, rng) return 45 + 6 * row + rng:NextInteger(0, 10) end,
	Elite = function(row) return 100 + 8 * row end,
	Boss  = function() return 250 end,
}

-- ── Rest node ─────────────────────────────────────────────────────────────────
DungeonConfig.RestHealPct = 0.35

-- ── HP carryover (shared behavior with tower) ─────────────────────────────────
DungeonConfig.WinHealPct = 0.15
DungeonConfig.RevivePct  = 0.25

-- ── Elite buff pool ───────────────────────────────────────────────────────────
-- Win an elite → 3 seeded offers, pick 1 + a target card. Run-scoped, stacking.
-- Effect keys match RunModifiers.Compute mod names.
DungeonConfig.Buffs = {
	berserk    = { name = "Berserker's Edge",    desc = "+30% ATK",                          effects = { atkMult = 1.30 } },
	titan      = { name = "Titan's Heart",       desc = "+35% Max HP",                       effects = { hpMult = 1.35 } },
	focus      = { name = "Focused Mind",        desc = "+50% MP gain",                      effects = { mpGainMult = 1.50 } },
	vamp       = { name = "Vampiric Touch",      desc = "15% lifesteal",                     effects = { lifestealPct = 0.15 } },
	deadeye    = { name = "Assassin's Eye",      desc = "+15% crit chance",                  effects = { critChanceBonus = 0.15 } },
	thorns     = { name = "Thorned Armor",       desc = "Reflect 20% of damage taken",       effects = { reflectPct = 0.20 } },
	ward       = { name = "Guardian's Blessing", desc = "Take 15% less damage",              effects = { damageTakenMult = 0.85 } },
	overcharge = { name = "Overcharge",          desc = "Active ability effect +40%",        effects = { activePowerMult = 1.40 } },
	execute    = { name = "Executioner's Mark",  desc = "+40% damage vs enemies below 30% HP", effects = { executeBonusPct = 0.40 } },
	regen      = { name = "Living Bark",         desc = "Heal 4% Max HP each round",         effects = { regenPctPerRound = 0.04 } },
}
DungeonConfig.BuffOfferCount = 3

-- ── Shop item pool ────────────────────────────────────────────────────────────
-- Bought at shop nodes, equipped to one team card. Run-scoped.
DungeonConfig.MaxItemsPerCard = 2
DungeonConfig.Items = {
	rusty_sword     = { name = "Rusty Sword",      desc = "+12% ATK",                        price = 90,  effects = { atkMult = 1.12 } },
	iron_shield     = { name = "Iron Shield",      desc = "+15% Max HP",                     price = 90,  effects = { hpMult = 1.15 } },
	gold_chalice    = { name = "Golden Chalice",   desc = "+30% XP gained by this card",     price = 100, effects = { xpGainMult = 1.30 } },
	mana_crystal    = { name = "Mana Crystal",     desc = "+25% MP gain",                    price = 110, effects = { mpGainMult = 1.25 } },
	lucky_coin      = { name = "Lucky Coin",       desc = "+8% crit chance",                 price = 120, effects = { critChanceBonus = 0.08 } },
	spiked_plate    = { name = "Spiked Plate",     desc = "Reflect 10% of damage taken",     price = 120, effects = { reflectPct = 0.10 } },
	vamp_fang       = { name = "Vampire Fang",     desc = "8% lifesteal",                    price = 130, effects = { lifestealPct = 0.08 } },
	war_banner      = { name = "Berserker Banner", desc = "+20% ATK while below 50% HP",     price = 140, effects = { lowHpAtkBonus = 0.20 } },
	heal_charm      = { name = "Healing Charm",    desc = "Heal 3% Max HP each round",       price = 150, effects = { regenPctPerRound = 0.03 } },
	giants_gauntlet = { name = "Giant's Gauntlet", desc = "+20% ATK",                        price = 170, effects = { atkMult = 1.20 } },
	dragon_scale    = { name = "Dragon Scale",     desc = "+25% Max HP",                     price = 170, effects = { hpMult = 1.25 } },
	phoenix_feather = { name = "Phoenix Feather",  desc = "Revive once at 30% HP",           price = 220, effects = { reviveOnce = true } },
}

-- ── Shop layout ───────────────────────────────────────────────────────────────
DungeonConfig.Shop = {
	OfferCount = 4,
	RerollBase = 25, RerollStep = 15,   -- 25g, then 40g, 55g, ...
	Services = {
		potion = { name = "Potion",     desc = "Heal one card 40% Max HP",  price = 40, healPct = 0.40, target = "one" },
		tonic  = { name = "Team Tonic", desc = "Heal all cards 20% Max HP", price = 90, healPct = 0.20, target = "all" },
	},
}

-- ── Rewards (packs granted immediately when earned) ───────────────────────────
DungeonConfig.Rewards = {
	ElitePacks = { StandardPack = 1 },
	BossPacks  = { RarePack = 2 },
}

-- ── Bonus loot: rare surprise drop on Mob/Elite wins (Boss always pays) ───────
DungeonConfig.BonusLoot = {
	Chance  = 0.12,
	Weights = { goldJackpot = 50, freeItem = 30, bonusPack = 20 },
	GoldJackpot = { MultLo = 2, MultHi = 3 },   -- × the node's normal gold award
	BonusPack   = { StandardPack = 1 },
}

-- ── Map-node previews (baked at run start; shown before committing a node) ────
DungeonConfig.Preview = {
	-- Which battle node types reveal the actual enemy cards in the tooltip.
	ShowCardsFor = { Elite = true, Boss = true },
	DangerStars = function(kind, row)
		if kind == "Boss" then return 5 end
		local stars = (row <= 3 and 1) or (row <= 6 and 2) or (row <= 9 and 3) or 4
		if kind == "Elite" then stars = math.min(5, stars + 1) end
		return stars
	end,
	RewardHint = function(kind, row)
		if kind == "Mob" then
			return "~" .. (45 + 6 * row + 5) .. "g + XP"
		elseif kind == "Elite" then
			return "Pack + Blessing + " .. (100 + 8 * row) .. "g"
		elseif kind == "Boss" then
			return "2x Rare Pack + 250g"
		elseif kind == "Rest" then
			return "Heal team 35% HP"
		elseif kind == "Shop" then
			return "Buy items & heals"
		end
		return ""
	end,
}

-- ── Enemy scaling ─────────────────────────────────────────────────────────────
DungeonConfig.Enemies = {
	TeamSize = function(row)
		if row <= 3 then return 3
		elseif row <= 7 then return 4
		else return 5 end
	end,
	RarityBands = {
		{ maxRow = 4,  pool = { Common = 0.6, Uncommon = 0.4 } },
		{ maxRow = 8,  pool = { Uncommon = 0.3, Rare = 0.4, Epic = 0.3 } },
		{ maxRow = math.huge, pool = { Rare = 0.3, Epic = 0.4, Legendary = 0.3 } },
	},
	MobMult   = function(row) return 0.70 + 0.06 * row end,
	EliteMult = 1.25,   -- times the mob multiplier for that row
	-- Boss: one high-rarity centerpiece plus Legendary adds.
	Boss = {
		CenterpieceRarities = { "Mythic", "God" },
		CenterpieceMult = 1.3,
		AddRarity = "Legendary",
		AddCount = 2,
		AddMult = 1.0,
	},
}

return DungeonConfig
