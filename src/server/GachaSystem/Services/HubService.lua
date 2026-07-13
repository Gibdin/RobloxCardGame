-- Procedurally builds the hub world into Workspace on server start. Workspace
-- itself is not version-controlled (the .rbxl is gitignored) — this is the
-- only way the hub is reproducible from a fresh clone/Rojo sync, so treat
-- HubConfig.lua as the single source of truth and this file as the builder,
-- the same way every other system in this project is config-driven.
--
-- Interactions (altar, vendor stalls) are ProximityPrompts whose Triggered
-- handler fires a RemoteEvent telling that specific player's client which UI
-- panel to open — the client already owns all of that UI (PackOpeningUI,
-- ShopStoreUI, InventoryUI, DungeonController), so the hub only needs to
-- trigger it, never duplicate it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("HubConfig"))

local HubService = {}

-- Lazily resolved so Build() (called before Main.server.lua creates remotes)
-- never has to wait on a folder that doesn't exist yet at require-time.
local reHubInteract
local function getHubInteractEvent()
	if not reHubInteract then
		reHubInteract = ReplicatedStorage:WaitForChild("GachaRemotes"):WaitForChild("HubInteract")
	end
	return reHubInteract
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "CanCollide" then p[k] = v end
	end
	return p
end

local function billboardLabel(parent, text, color, size)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = size or UDim2.new(0, 200, 0, 50)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = bb
	return bb
end

local function addPrompt(parent, promptText, action, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText or "Interact"
	prompt.ObjectText = promptText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent

	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(function()
			getHubInteractEvent():FireClient(player, action)
		end)
		if not ok then
			warn("[HubService] Failed to fire HubInteract for", action, ":", err)
		end
	end)

	return prompt
end

-- ── Builders ──────────────────────────────────────────────────────────────────

local function buildPlaza(root)
	local plaza = part({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, HubConfig.PlazaRadius * 2, HubConfig.PlazaRadius * 2),
		CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = HubConfig.PlazaColor,
		Material = HubConfig.PlazaMaterial,
		Parent = root,
	})
	return plaza
end

local function buildAltar(root)
	local cfg = HubConfig.Altar
	local altarFolder = Instance.new("Folder")
	altarFolder.Name = "Altar"
	altarFolder.Parent = root

	local dais = part({
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(cfg.daisHeight, cfg.daisRadius * 2, cfg.daisRadius * 2),
		CFrame = CFrame.new(cfg.position + Vector3.new(0, cfg.daisHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 36, 46),
		Material = Enum.Material.Marble,
		Parent = altarFolder,
	})

	local pillar = part({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(cfg.pillarHeight, 3, 3),
		CFrame = CFrame.new(cfg.position + Vector3.new(0, cfg.daisHeight + cfg.pillarHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = cfg.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = altarFolder,
	})

	local light = Instance.new("PointLight")
	light.Color = cfg.color
	light.Range = 30
	light.Brightness = 3
	light.Parent = pillar

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(cfg.color)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Transparency = NumberSequence.new(0.2, 1)
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 12
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = pillar

	billboardLabel(pillar, "SUMMONING ALTAR", cfg.color, UDim2.new(0, 240, 0, 40))

	addPrompt(dais, cfg.promptText, cfg.action, "Summon")
end

local function buildVendor(root, vendorCfg)
	local angle = math.rad(vendorCfg.angleDeg)
	local pos = HubConfig.Altar.position + Vector3.new(
		math.sin(angle) * HubConfig.StandRadius, 0, math.cos(angle) * HubConfig.StandRadius)
	local facing = CFrame.lookAt(pos, HubConfig.Altar.position)

	local folder = Instance.new("Folder")
	folder.Name = "Vendor_" .. vendorCfg.id
	folder.Parent = root

	local base = part({
		Name = "Base",
		Size = Vector3.new(8, 1, 6),
		CFrame = facing * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(50, 46, 40),
		Material = Enum.Material.Wood,
		Parent = folder,
	})

	-- CFrame.lookAt(pos, altar) makes local -Z point toward the altar, so the
	-- counter (what an approaching player should reach first) sits at -Z and
	-- the back wall (behind the stall) sits at +Z.
	local wall = part({
		Name = "BackWall",
		Size = Vector3.new(8, 7, 0.6),
		CFrame = facing * CFrame.new(0, 4, 2.7),
		Color = vendorCfg.color,
		Material = Enum.Material.Fabric,
		Parent = folder,
	})

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(7, 3, 1.5),
		CFrame = facing * CFrame.new(0, 2.5, -1.5),
		Color = Color3.fromRGB(60, 54, 46),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	billboardLabel(wall, vendorCfg.name, vendorCfg.color, UDim2.new(0, 220, 0, 40))
	addPrompt(counter, vendorCfg.promptText, vendorCfg.action, "Talk")
end

local function buildReservedZone(root, zoneCfg)
	local marker = part({
		Name = "Zone_" .. zoneCfg.id,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, zoneCfg.radius * 2, zoneCfg.radius * 2),
		CFrame = CFrame.new(zoneCfg.position + Vector3.new(0, -0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zoneCfg.color,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		Parent = root,
	})
	billboardLabel(marker, zoneCfg.label, zoneCfg.color, UDim2.new(0, 260, 0, 50))
end

local function buildSpawns(root)
	for i, pos in ipairs(HubConfig.SpawnPoints) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = pos
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Color = HubConfig.PlazaColor
		spawn.Material = HubConfig.PlazaMaterial
		spawn.Parent = root
	end
end

local function setAtmosphere()
	-- Daytime ClockTime keeps the sun high enough that flat horizontal
	-- surfaces (the plaza floor) actually catch direct light instead of the
	-- near-total shadow a low dusk/night sun casts on them at a grazing
	-- angle (verified in-Studio: dusk left the floor pure black while
	-- vertical stall walls stayed lit). The moody purple tone comes from the
	-- atmosphere/fog color instead of the time of day.
	Lighting.Ambient = Color3.fromRGB(90, 82, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 92, 120)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogColor = Color3.fromRGB(70, 60, 95)
	Lighting.FogEnd = 900

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Color = Color3.fromRGB(160, 140, 190)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
end

-- Idempotent: safe to call on every server start. Removes the default
-- baseplate/spawn (a fresh-Studio-template placeholder, not hand-authored
-- content) and any previously-built Hub folder before rebuilding.
function HubService:Build()
	local oldHub = Workspace:FindFirstChild("Hub")
	if oldHub then oldHub:Destroy() end

	local defaultBaseplate = Workspace:FindFirstChild("Baseplate")
	if defaultBaseplate then defaultBaseplate:Destroy() end

	local defaultSpawn = Workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn then defaultSpawn:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "Hub"
	root.Parent = Workspace

	buildPlaza(root)
	buildAltar(root)
	for _, vendorCfg in ipairs(HubConfig.Vendors) do
		buildVendor(root, vendorCfg)
	end
	for _, zoneCfg in ipairs(HubConfig.ReservedZones) do
		buildReservedZone(root, zoneCfg)
	end
	buildSpawns(root)
	setAtmosphere()
end

return HubService
