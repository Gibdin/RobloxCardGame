-- Layout constants for the procedurally-built hub world. Edit values here to
-- rebalance/reshape the hub — HubService reads this and (re)builds Workspace
-- to match on every server start, so the world is fully reproducible from
-- code (Workspace itself is not version-controlled; the .rbxl is gitignored).

local HubConfig = {}

HubConfig.PlazaRadius = 60
HubConfig.PlazaColor  = Color3.fromRGB(120, 110, 130)
HubConfig.PlazaMaterial = Enum.Material.Slate

-- Central altar — the physical pack-opening interaction point.
HubConfig.Altar = {
	position     = Vector3.new(0, 0, 0),
	daisRadius   = 8,
	daisHeight   = 1,
	pillarHeight = 10,
	color        = Color3.fromRGB(120, 70, 200),
	promptText   = "Open Packs",
	action       = "OpenAltar",
}

-- Vendor stalls, evenly spaced around the plaza at `standRadius` studs from
-- the altar. Each opens a client UI panel via the HubInteract RemoteEvent.
HubConfig.StandRadius = 34
HubConfig.Vendors = {
	{ id = "gems",  name = "Gem Merchant",   angleDeg = 0,   color = Color3.fromRGB(120, 220, 255), action = "OpenStore",     promptText = "Visit Gem Merchant" },
	{ id = "cards", name = "Card Keeper",    angleDeg = 120, color = Color3.fromRGB(70, 180, 110),  action = "OpenInventory", promptText = "Visit Card Keeper" },
	{ id = "battle",name = "Battle Herald",  angleDeg = 240, color = Color3.fromRGB(200, 70, 70),   action = "OpenBattle",    promptText = "Speak to Battle Herald" },
}

-- Reserved zones for later phases (Phase 6 PvP arena, Phase 7 guild hall) —
-- built now as marked, empty plots so those phases are additive, not retrofits.
HubConfig.ReservedZones = {
	{ id = "arena", name = "PVP ARENA",  position = Vector3.new(90, 0, 0),  radius = 20, color = Color3.fromRGB(140, 40, 40),  label = "PVP ARENA \226\128\148 COMING SOON" },
	{ id = "guild", name = "GUILD HALL", position = Vector3.new(-90, 0, 0), radius = 20, color = Color3.fromRGB(40, 80, 140), label = "GUILD HALL \226\128\148 COMING SOON" },
}

-- Spawn points around the plaza edge, away from the altar/stalls/reserved zones.
HubConfig.SpawnPoints = {
	Vector3.new(0, 1, 50),
	Vector3.new(45, 1, -30),
	Vector3.new(-45, 1, -30),
	Vector3.new(0, 1, -50),
}

return HubConfig
