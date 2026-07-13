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

-- Live duel arena (Phase 6) — the zone reserved in Phase 2 is now a real
-- interactive point, built additively (same position/color) rather than as
-- a retrofit of buildReservedZone.
HubConfig.DuelArena = {
	id = "arena", name = "DUEL ARENA",
	position = Vector3.new(90, 0, 0), radius = 20,
	color = Color3.fromRGB(140, 40, 40),
	promptText = "Enter the Duel Arena", action = "OpenArena",
}

-- Guild hall (Phase 7) — the zone reserved in Phase 2 is now a real
-- interactive point, same position/color, built the same way Phase 6 turned
-- the arena's reserved zone into a real platform.
HubConfig.GuildHall = {
	id = "guild", name = "GUILD HALL",
	position = Vector3.new(-90, 0, 0), radius = 20,
	color = Color3.fromRGB(40, 80, 140),
	promptText = "Enter the Guild Hall", action = "OpenSocial",
}

-- Reserved zones for future phases — none currently pending.
HubConfig.ReservedZones = {}

-- Spawn points around the plaza edge, away from the altar/stalls/reserved zones.
HubConfig.SpawnPoints = {
	Vector3.new(0, 1, 50),
	Vector3.new(45, 1, -30),
	Vector3.new(-45, 1, -30),
	Vector3.new(0, 1, -50),
}

return HubConfig
