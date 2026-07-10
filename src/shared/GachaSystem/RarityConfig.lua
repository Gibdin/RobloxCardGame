-- Single source of truth for all rarity weights, colors, pity thresholds,
-- and pack definitions. Edit values here to rebalance the system.

local RarityConfig = {}

-- order: lower = more common. Used for comparisons and pity enforcement.
RarityConfig.Rarities = {
	Common    = { weight = 45,   order = 1, color = Color3.fromRGB(180, 180, 180), glowColor = Color3.fromRGB(220, 220, 220) },
	Uncommon  = { weight = 25,   order = 2, color = Color3.fromRGB(80,  200, 80),  glowColor = Color3.fromRGB(120, 240, 120) },
	Rare      = { weight = 15,   order = 3, color = Color3.fromRGB(80,  130, 255), glowColor = Color3.fromRGB(130, 180, 255) },
	Epic      = { weight = 8,    order = 4, color = Color3.fromRGB(160, 60,  220), glowColor = Color3.fromRGB(200, 100, 255) },
	Legendary = { weight = 4,    order = 5, color = Color3.fromRGB(255, 165, 0),   glowColor = Color3.fromRGB(255, 215, 80)  },
	Mythic    = { weight = 2,    order = 6, color = Color3.fromRGB(255, 50,  50),  glowColor = Color3.fromRGB(255, 120, 120) },
	God       = { weight = 0.8,  order = 7, color = Color3.fromRGB(255, 215, 0),   glowColor = Color3.fromRGB(255, 255, 160) },
	Secret    = { weight = 0.2,  order = 8, color = Color3.fromRGB(0,   240, 255), glowColor = Color3.fromRGB(160, 255, 255) },
}

-- Ordered list — index matches rarity.order for safe iteration.
RarityConfig.RarityOrder = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "God", "Secret",
}

-- Hard-pity: after N total rolls since last reset, the next roll is guaranteed
-- at least the listed rarity. Thresholds are evaluated lowest-first; the highest
-- matching one wins.
RarityConfig.PityThresholds = {
	{ rolls = 10,  minRarity = "Rare"      },
	{ rolls = 30,  minRarity = "Epic"      },
	{ rolls = 75,  minRarity = "Legendary" },
	{ rolls = 150, minRarity = "Mythic"    },
	{ rolls = 400, minRarity = "God"       },
}

-- Pack definitions. multipliers scale the base weight of specific rarities.
-- Unlisted rarities keep their base weight.
RarityConfig.PackTypes = {
	StandardPack = {
		displayName  = "Standard Pack",
		description  = "Base odds across all rarities.",
		multipliers  = {},
	},
	RarePack = {
		displayName  = "Rare Pack",
		description  = "Boosted Rare and Epic rates.",
		multipliers  = { Rare = 1.5, Epic = 1.3, Legendary = 1.2 },
	},
	EventPack = {
		displayName  = "Event Pack",
		description  = "Massively boosted Epic+ rates.",
		multipliers  = { Epic = 2.0, Legendary = 1.8, Mythic = 1.5, God = 1.3, Secret = 1.3 },
	},
}

-- Flash-sequence timing and fakeout settings.
RarityConfig.FlashConfig = {
	MinFlashes       = 8,
	MaxFlashes       = 15,
	BaseInterval     = 0.08,   -- seconds for the first flash
	SlowdownFactor   = 1.25,   -- each flash interval is multiplied by this
	FakeoutChance    = 0.40,   -- probability the penultimate flash is a decoy
	FakeoutDropTiers = 2,      -- decoy shows this many tiers BELOW the real result
}

-- Visual effects triggered on the final card reveal.
RarityConfig.EffectConfig = {
	ScreenShake = {
		Epic      = { intensity = 0.4, duration = 0.5 },
		Legendary = { intensity = 0.8, duration = 0.8 },
		Mythic    = { intensity = 1.3, duration = 1.0 },
		God       = { intensity = 2.0, duration = 1.5 },
		Secret    = { intensity = 3.0, duration = 2.0 },
	},
	GlowRarities     = { "Legendary", "Mythic", "God", "Secret" },
	ParticleRarities = { "God", "Secret" },
}

-- Returns the numeric order of a rarity name (1–8).
function RarityConfig:GetOrder(rarity)
	return (self.Rarities[rarity] or {}).order or 1
end

-- Returns the rarity name at position i in RarityOrder (clamped).
function RarityConfig:ByOrder(i)
	return self.RarityOrder[math.clamp(i, 1, #self.RarityOrder)]
end

-- True if rarityA is strictly lower tier than rarityB.
function RarityConfig:IsLower(rarityA, rarityB)
	return self:GetOrder(rarityA) < self:GetOrder(rarityB)
end

return RarityConfig
