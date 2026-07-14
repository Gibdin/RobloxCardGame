-- Single source of truth for all monetization constants: Gem packages, the VIP
-- Game Pass, direct Gem->pack pricing, the Battle Pass skeleton, and rotating
-- banners. Edit values here to rebalance monetization.
--
-- IMPORTANT: every `productId`/`passId` below is a placeholder (0) because this
-- place is not yet published to Roblox — Developer Products and Game Passes
-- can only be created once it is. After publishing, create each product/pass
-- in the Creator Dashboard (create.roblox.com -> your experience -> Monetization)
-- and paste the real numeric IDs in here. MonetizationService treats id == 0 as
-- "not configured yet" and will refuse to prompt a purchase for it, so nothing
-- breaks in the meantime — the buttons will just show as not-yet-available.

local MonetizationConfig = {}

-- ── Gem packages (consumable Developer Products) ─────────────────────────────
-- gems = base amount granted; bonus = extra gems included in that tier's price
-- (shown separately in the UI as "+bonus" so the value scaling is legible).
MonetizationConfig.GemProducts = {
	{ id = "gems_small",  productId = 0, priceRobux = 99,   gems = 100,  bonus = 0    },
	{ id = "gems_medium", productId = 0, priceRobux = 499,  gems = 550,  bonus = 50   },
	{ id = "gems_large",  productId = 0, priceRobux = 999,  gems = 1200, bonus = 200  },
	{ id = "gems_mega",   productId = 0, priceRobux = 4999, gems = 6500, bonus = 1500 },
}

-- ── VIP Game Pass (one-time, permanent) ───────────────────────────────────────
MonetizationConfig.VIP = {
	passId     = 0,
	priceRobux = 799,
	benefits = {
		"Daily bonus pack (claim once per day)",
		"2x Auto-Roll speed",
		"Gold VIP name color",
	},
	dailyBonusPack = "StandardPack",
}

-- ── Direct pack purchase pricing (spent from the player's Gem balance) ────────
MonetizationConfig.PackGemCost = {
	StandardPack = 80,
	RarePack     = 200,
	EventPack    = 320,
}

-- ── Battle Pass (skeleton only — reward content + the real XP feed are later
-- roadmap phases; this just establishes the purchasable-season shape) ─────────
MonetizationConfig.BattlePass = {
	productId  = 0,      -- one-time dev product that unlocks the premium track for the season
	priceRobux = 799,
	maxTier    = 30,
	xpPerTier  = 1000,
}

-- ── Rotating limited-time banners ──────────────────────────────────────────────
-- A banner biases card selection toward `featuredCardId` (within its own
-- rarity pool, via CardService:GetRandomOfRarityWeighted) whenever the base
-- rarity roll lands on that card's rarity or higher. `guaranteeAfter` pulls on
-- THIS banner without obtaining the featured card forces the next pull to be
-- the featured card outright (rarity included) — a standard gacha "hard pity
-- on the rate-up unit." One entry per existing Legendary+ card (44-50, all
-- already-built roster — Phase 9 is about cadence, not new cards); which one
-- is "active" is now computed automatically from BannerRotation below rather
-- than a hand-flipped flag (see BannerService:GetActiveBanner).
MonetizationConfig.Banners = {
	{ id = "banner_launch",      name = "Launch Banner",              featuredCardId = 44, rateMult = 4, guaranteeAfter = 50  },
	{ id = "banner_sage",        name = "Hundred-Heal Sage Banner",    featuredCardId = 45, rateMult = 4, guaranteeAfter = 50  },
	{ id = "banner_honored",     name = "The Honored Guy Banner",      featuredCardId = 46, rateMult = 4, guaranteeAfter = 50  },
	{ id = "banner_tidewarden",  name = "Tide Warden Banner",          featuredCardId = 47, rateMult = 4, guaranteeAfter = 50  },
	{ id = "banner_illusion",    name = "Illusion Sovereign Banner",   featuredCardId = 48, rateMult = 4, guaranteeAfter = 80  },
	{ id = "banner_worldcutter", name = "World Cutter Banner",         featuredCardId = 49, rateMult = 4, guaranteeAfter = 150 },
	{ id = "banner_nameless",    name = "The Nameless Banner",         featuredCardId = 50, rateMult = 4, guaranteeAfter = 250 },
}

-- Automatic weekly rotation cadence. Which banner is live in any given week
-- is purely a function of real time (RotationEpoch anchors week 0), so the
-- schedule is always already decided arbitrarily far in advance — nobody
-- needs to remember to flip a flag, and DebugService:PreviewBannerRotation
-- can print the upcoming N weeks to verify it in Studio without waiting.
MonetizationConfig.BannerRotation = {
	RotationEpoch = 1751328000, -- fixed anchor timestamp for week 0 (2025-07-01T00:00:00Z)
	DurationDays  = 7,
	Order = {
		"banner_launch", "banner_sage", "banner_honored", "banner_tidewarden",
		"banner_illusion", "banner_worldcutter", "banner_nameless",
	},
}

return MonetizationConfig
