-- GachaSystem server entry point.
-- Creates RemoteFunction/Event instances and wires up service calls.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services         = script.Parent.Services
local InventoryService = require(Services.InventoryService)
local PackService      = require(Services.PackService)
local PityService      = require(Services.PityService)

-- ── Remote setup ─────────────────────────────────────────────────────────────

local remotes = Instance.new("Folder")
remotes.Name  = "GachaRemotes"
remotes.Parent = ReplicatedStorage

local function RF(name)
	local r = Instance.new("RemoteFunction")
	r.Name  = name; r.Parent = remotes
	return r
end

local function RE(name)
	local r = Instance.new("RemoteEvent")
	r.Name  = name; r.Parent = remotes
	return r
end

local rfOpenPack     = RF("OpenPack")
local rfGetInventory = RF("GetInventory")
local rfGetPacks     = RF("GetPacks")
local rfGetPityInfo  = RF("GetPityInfo")
local rfGetTeam      = RF("GetTeam")
local rfSetTeam      = RF("SetTeam")
RE("AutoRollToggled")   -- client fires this; no server handler needed (state is client-only)

-- ── Remote handlers ──────────────────────────────────────────────────────────

rfOpenPack.OnServerInvoke = function(player, packType)
	-- Validate packType is a string to prevent injection.
	if type(packType) ~= "string" then
		return { success = false, error = "Invalid request." }
	end

	local result, err = PackService:OpenPack(player.UserId, packType)
	if err then
		return { success = false, error = err }
	end
	return { success = true, result = result }
end

rfGetInventory.OnServerInvoke = function(player)
	return InventoryService:GetFullData(player.UserId)
end

rfGetPacks.OnServerInvoke = function(player)
	return InventoryService:GetPacks(player.UserId)
end

rfGetPityInfo.OnServerInvoke = function(player)
	return PityService:GetInfo(player.UserId)
end

rfGetTeam.OnServerInvoke = function(player)
	return InventoryService:GetTeam(player.UserId)
end

rfSetTeam.OnServerInvoke = function(player, teamTable)
	if type(teamTable) ~= "table" then return { success = false } end
	InventoryService:SetTeam(player.UserId, teamTable)
	return { success = true }
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	InventoryService:Load(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	InventoryService:Cleanup(player.UserId)
	PityService:Cleanup(player.UserId)
end)

-- Handle players already in-game when this script starts (Studio play-test).
for _, player in ipairs(Players:GetPlayers()) do
	InventoryService:Load(player.UserId)
end
