-- Cosmetic-only Gem purchases — the first monetization surface that never
-- touches gacha odds. Trails use only native Color/Transparency/Width
-- sequences (no Texture id) so there's no placeholder-asset problem to solve
-- later: a colored Trail renders correctly with zero external assets.

local CosmeticConfig = {}

CosmeticConfig.Trails = {
	{ id = "none",   name = "None",         gemCost = 0,   color1 = nil, color2 = nil },
	{ id = "ember",  name = "Ember Trail",  gemCost = 150, color1 = Color3.fromRGB(255, 150, 60),  color2 = Color3.fromRGB(140, 30, 10) },
	{ id = "frost",  name = "Frost Trail",  gemCost = 150, color1 = Color3.fromRGB(160, 220, 255), color2 = Color3.fromRGB(40, 90, 160) },
	{ id = "arcane", name = "Arcane Trail", gemCost = 250, color1 = Color3.fromRGB(200, 100, 255), color2 = Color3.fromRGB(60, 20, 120) },
	{ id = "gold",   name = "Gilded Trail", gemCost = 400, color1 = Color3.fromRGB(255, 230, 150), color2 = Color3.fromRGB(200, 150, 30) },
}

return CosmeticConfig
