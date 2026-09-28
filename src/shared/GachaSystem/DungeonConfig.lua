-- Dungeon run constants (the JJK "Shibuya Incident" run): map generation,
-- XP/leveling, gold and Gem economy, theme names, elite buff
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
	-- Ability power (BattleEngine's activePowerMult, already scaling both the
	-- generic role active AND every per-card unique active step) grows in
	-- tiers rather than every level, so a level-up doesn't just make a card
	-- hit harder passively (StatPerLevel) but occasionally makes its ACTIVE
	-- meaningfully stronger too. A first prototype pass — tune freely.
	AbilityTierSize    = 5,    -- a tier is reached every N levels (levels 5-9 = tier 1, 10 = tier 2)
	AbilityPowerPerTier = 0.15, -- +15% active power per tier reached
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

-- ── Gems (the persistent currency that buys packs) ────────────────────────────
-- Granted the moment a battle is won, so they're kept even if the run ends in
-- defeat. A full clear is worth roughly one Standard Pack (80 Gems) on top of
-- the Special Grade/boss pack drops. AnimeRosterPlan.md §11.11.
DungeonConfig.Gems = {
	Mob   = function(row) return 3 + math.floor(row / 3) end,
	Elite = function() return 10 end,
	Boss  = function() return 40 end,
}

-- ── Theme: the Shibuya Incident (JJK) ─────────────────────────────────────────
-- Player-facing names for the run and its node types. Internal type keys
-- (Mob/Elite/Shop/Rest/Boss) stay unchanged.
DungeonConfig.Theme = {
	Title    = "SHIBUYA INCIDENT",
	Subtitle = "Clear the cursed station. Reach the Domain.",
	NodeName = {
		Mob   = "Cursed Spirits",
		Elite = "Special Grade",
		Shop  = "Cursed Tool Dealer",
		Rest  = "Infirmary",
		Boss  = "Domain Expansion",
	},
}

-- ── Rest node ─────────────────────────────────────────────────────────────────
DungeonConfig.RestHealPct = 0.35

-- ── HP carryover (shared behavior with tower) ─────────────────────────────────
DungeonConfig.WinHealPct = 0.25
DungeonConfig.RevivePct  = 0.25

-- ── Elite buff pool ───────────────────────────────────────────────────────────
-- Win an elite → 3 seeded offers, pick 1 + a target card. Run-scoped, stacking.
-- Effect keys match RunModifiers.Compute mod names.
DungeonConfig.Buffs = {
	berserk    = { name = "Vow of Fury",           desc = "Big ATK boost",                        effects = { atkMult = 1.30 } },
	titan      = { name = "Vow of Endurance",      desc = "Big Max HP boost",                     effects = { hpMult = 1.35 } },
	focus      = { name = "Cursed Energy Surge",   desc = "Fills mana much faster",               effects = { mpGainMult = 1.50 } },
	vamp       = { name = "Blood Manipulation",    desc = "Heals from the damage it deals",       effects = { lifestealPct = 0.15 } },
	deadeye    = { name = "Six Eyes Glimpse",      desc = "Lands many more crits",                effects = { critChanceBonus = 0.15 } },
	thorns     = { name = "Curse Backlash",        desc = "Hurts enemies that hit it",            effects = { reflectPct = 0.20 } },
	ward       = { name = "Simple Domain",         desc = "Takes less damage",                    effects = { damageTakenMult = 0.85 } },
	overcharge = { name = "Domain Amplification",  desc = "Much stronger ability",                effects = { activePowerMult = 1.40 } },
	execute    = { name = "Executioner's Sword",   desc = "Finishes off weakened enemies",        effects = { executeBonusPct = 0.40 } },
	regen      = { name = "Reverse Cursed Energy", desc = "Heals a little every round",           effects = { regenPctPerRound = 0.04 } },
}
DungeonConfig.BuffOfferCount = 3

-- ── Shop item pool ────────────────────────────────────────────────────────────
-- Bought at shop nodes, equipped to one team card. Run-scoped.
DungeonConfig.MaxItemsPerCard = 2
DungeonConfig.Items = {
	rusty_sword     = { name = "Slaughter Demon",        desc = "ATK boost",                        price = 90,  effects = { atkMult = 1.12 } },
	iron_shield     = { name = "Barrier Talisman",       desc = "Max HP boost",                     price = 90,  effects = { hpMult = 1.15 } },
	gold_chalice    = { name = "Sorcerer's Notebook",    desc = "Learns faster (more XP)",          price = 100, effects = { xpGainMult = 1.30 } },
	mana_crystal    = { name = "Cursed Energy Vial",     desc = "Fills mana faster",                price = 110, effects = { mpGainMult = 1.25 } },
	lucky_coin      = { name = "Jackpot Token",          desc = "Lands more crits",                 price = 120, effects = { critChanceBonus = 0.08 } },
	spiked_plate    = { name = "Straw Doll",             desc = "Hurts enemies that hit it",        price = 120, effects = { reflectPct = 0.10 } },
	vamp_fang       = { name = "Blood Vial",             desc = "Heals from the damage it deals",   price = 130, effects = { lifestealPct = 0.08 } },
	war_banner      = { name = "Brotherly Bond",         desc = "Hits harder when hurt",            price = 140, effects = { lowHpAtkBonus = 0.20 } },
	heal_charm      = { name = "Healing Talisman",       desc = "Heals a little every round",       price = 150, effects = { regenPctPerRound = 0.03 } },
	giants_gauntlet = { name = "Playful Cloud",          desc = "Big ATK boost",                    price = 170, effects = { atkMult = 1.20 } },
	dragon_scale    = { name = "Heavenly Armor",         desc = "Big Max HP boost",                 price = 170, effects = { hpMult = 1.25 } },
	phoenix_feather = { name = "Sukuna's Finger",        desc = "Comes back once after being knocked out", price = 220, effects = { reviveOnce = true } },
}

-- ── Shop layout ───────────────────────────────────────────────────────────────
DungeonConfig.Shop = {
	OfferCount = 4,
	RerollBase = 25, RerollStep = 15,   -- 25g, then 40g, 55g, ...
	Services = {
		potion = { name = "Medic's Kit",      desc = "Big heal for one card",  price = 40, healPct = 0.40, target = "one" },
		tonic  = { name = "Shoko's Treatment", desc = "Heals the whole team",   price = 90, healPct = 0.20, target = "all" },
	},
}

-- ── Rewards (packs granted immediately when earned) ───────────────────────────
DungeonConfig.Rewards = {
	ElitePacks = { StandardPack = 1 },
	BossPacks  = { RarePack = 2 },
}

-- ── Bonus loot: rare surprise drop on Mob/Elite wins (Boss always pays) ───────
DungeonConfig.BonusLoot = {
	Chance  = 0.15,
	Weights = { goldJackpot = 40, gemJackpot = 25, freeItem = 20, bonusPack = 15 },
	GoldJackpot = { MultLo = 2, MultHi = 3 },   -- × the node's normal gold award
	GemJackpot  = { Lo = 15, Hi = 30 },         -- flat Gems (pack currency)
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
			return "Gems + gold + XP"
		elseif kind == "Elite" then
			return "Pack + Binding Vow + Gems"
		elseif kind == "Boss" then
			return "2 Rare Packs + lots of Gems"
		elseif kind == "Rest" then
			return "Heals your whole team"
		elseif kind == "Shop" then
			return "Cursed tools & heals"
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
		-- Tuned 2026-09-28 by simulated runs (AnimeRosterPlan.md §11.11): a
		-- starter team should get deep and sometimes clear; rarity still matters.
		{ maxRow = 4,  pool = { Common = 0.7, Uncommon = 0.3 } },
		{ maxRow = 8,  pool = { Common = 0.2, Uncommon = 0.4, Rare = 0.3, Epic = 0.1 } },
		{ maxRow = math.huge, pool = { Uncommon = 0.2, Rare = 0.4, Epic = 0.3, Legendary = 0.1 } },
	},
	MobMult   = function(row) return 0.60 + 0.045 * row end,
	EliteMult = 1.25,   -- times the mob multiplier for that row
	-- Boss: one high-rarity centerpiece plus Legendary adds.
	Boss = {
		CenterpieceRarities = { "God", "God", "Secret" },  -- Sukuna/Gojo, or a rare Mahoraga
		CenterpieceMult = 1.0,
		AddRarity = "Epic",
		AddCount = 2,
		AddMult = 1.0,
	},
}

return DungeonConfig
