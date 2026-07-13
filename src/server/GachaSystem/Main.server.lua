-- GachaSystem server entry point.
-- Creates RemoteFunction/Event instances and wires up service calls.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services         = script.Parent.Services
local InventoryService = require(Services.InventoryService)
local PackService      = require(Services.PackService)
local PityService      = require(Services.PityService)
local TowerService     = require(Services.TowerService)
local DungeonService   = require(Services.DungeonService)
local DebugService     = require(Services.DebugService)

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
local rfGetSettings  = RF("GetSettings")
local rfSetSettings  = RF("SetSettings")
RE("AutoRollToggled")   -- client fires this; no server handler needed (state is client-only)

local rfTowerStart     = RF("Tower_Start")
local rfTowerNextFloor = RF("Tower_NextFloor")
local rfTowerPickBuff  = RF("Tower_PickBuff")
local rfTowerGetState  = RF("Tower_GetState")
local rfTowerAbandon   = RF("Tower_Abandon")

local rfDungeonStart       = RF("Dungeon_Start")
local rfDungeonGetState    = RF("Dungeon_GetState")
local rfDungeonChooseNode  = RF("Dungeon_ChooseNode")
local rfDungeonPickBuff    = RF("Dungeon_PickEliteBuff")
local rfDungeonBuyItem     = RF("Dungeon_BuyItem")
local rfDungeonBuyService  = RF("Dungeon_BuyService")
local rfDungeonReroll      = RF("Dungeon_RerollShop")
local rfDungeonAbandon     = RF("Dungeon_Abandon")

local rfDebugQuickSetup = RF("Debug_QuickSetup")

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

rfGetSettings.OnServerInvoke = function(player)
	return InventoryService:GetSettings(player.UserId)
end

rfSetSettings.OnServerInvoke = function(player, settingsTable)
	if type(settingsTable) ~= "table" then return { success = false } end
	InventoryService:SetSettings(player.UserId, settingsTable)
	return { success = true }
end

rfTowerStart.OnServerInvoke = function(player)
	return TowerService:Start(player.UserId)
end

rfTowerNextFloor.OnServerInvoke = function(player)
	return TowerService:NextFloor(player.UserId)
end

rfTowerPickBuff.OnServerInvoke = function(player, choiceIndex, targetCardId)
	return TowerService:PickBuff(player.UserId, choiceIndex, targetCardId)
end

rfTowerGetState.OnServerInvoke = function(player)
	return TowerService:GetState(player.UserId)
end

rfTowerAbandon.OnServerInvoke = function(player)
	return TowerService:Abandon(player.UserId)
end

rfDungeonStart.OnServerInvoke = function(player)
	return DungeonService:Start(player.UserId)
end

rfDungeonGetState.OnServerInvoke = function(player)
	return DungeonService:GetState(player.UserId)
end

rfDungeonChooseNode.OnServerInvoke = function(player, nodeId)
	return DungeonService:ChooseNode(player.UserId, nodeId)
end

rfDungeonPickBuff.OnServerInvoke = function(player, choiceIndex, targetCardId)
	return DungeonService:PickEliteBuff(player.UserId, choiceIndex, targetCardId)
end

rfDungeonBuyItem.OnServerInvoke = function(player, offerIndex, targetCardId)
	return DungeonService:BuyItem(player.UserId, offerIndex, targetCardId)
end

rfDungeonBuyService.OnServerInvoke = function(player, serviceId, targetCardId)
	return DungeonService:BuyService(player.UserId, serviceId, targetCardId)
end

rfDungeonReroll.OnServerInvoke = function(player)
	return DungeonService:RerollShop(player.UserId)
end

rfDungeonAbandon.OnServerInvoke = function(player)
	return DungeonService:Abandon(player.UserId)
end

rfDebugQuickSetup.OnServerInvoke = function(player)
	return DebugService:QuickSetup(player.UserId)
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	InventoryService:Load(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	TowerService:Cleanup(player.UserId)
	DungeonService:Cleanup(player.UserId)
	InventoryService:Cleanup(player.UserId)
	PityService:Cleanup(player.UserId)
end)

-- Handle players already in-game when this script starts (Studio play-test).
for _, player in ipairs(Players:GetPlayers()) do
	InventoryService:Load(player.UserId)
end

-- ── Autosave ──────────────────────────────────────────────────────────────────
-- Leave-triggered saves alone aren't enough to survive a non-graceful shutdown;
-- this periodic pass plus BindToClose below bound worst-case data loss to one
-- autosave interval instead of "however long the player has been connected."

local AUTOSAVE_INTERVAL = 120 -- seconds

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			InventoryService:Save(player.UserId)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		InventoryService:Save(player.UserId)
	end
end)
