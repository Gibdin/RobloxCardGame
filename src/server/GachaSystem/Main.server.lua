-- GachaSystem server entry point.
-- Creates RemoteFunction/Event instances and wires up service calls.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services         = script.Parent.Services
local InventoryService = require(Services.InventoryService)
local PackService      = require(Services.PackService)
local PityService      = require(Services.PityService)
local BannerService    = require(Services.BannerService)
local TowerService     = require(Services.TowerService)
local DungeonService   = require(Services.DungeonService)
local DebugService     = require(Services.DebugService)
local MonetizationService = require(Services.MonetizationService)
local HubService       = require(Services.HubService)
local CosmeticService  = require(Services.CosmeticService)
local QuestService     = require(Services.QuestService)
local LeaderboardService = require(Services.LeaderboardService)

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("MonetizationConfig"))
local CosmeticConfig     = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CosmeticConfig"))

-- ── Player lifecycle ──────────────────────────────────────────────────────────
-- Connected as early as possible, before any heavier synchronous startup work
-- below (building the hub world, etc.) — InventoryService:get() also
-- self-heals via a lazy-load fallback if a player is ever somehow missed here,
-- but minimizing that race window in the first place is the real fix.

Players.PlayerAdded:Connect(function(player)
	InventoryService:Load(player.UserId)
	MonetizationService:SyncVIPOwnership(player)
	CosmeticService:WatchPlayer(player)
	QuestService:EnsureFresh(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	TowerService:Cleanup(player.UserId)
	DungeonService:Cleanup(player.UserId)
	InventoryService:Cleanup(player.UserId)
	PityService:Cleanup(player.UserId)
	BannerService:Cleanup(player.UserId)
end)

-- Handle players already in-game when this script starts (Studio play-test).
for _, player in ipairs(Players:GetPlayers()) do
	InventoryService:Load(player.UserId)
	MonetizationService:SyncVIPOwnership(player)
	CosmeticService:WatchPlayer(player)
	QuestService:EnsureFresh(player.UserId)
end

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

local rfGetMonetizationInfo  = RF("GetMonetizationInfo")
local rfPromptGemPurchase    = RF("PromptGemPurchase")
local rfPromptVIPPurchase    = RF("PromptVIPPurchase")
local rfPromptBattlePass     = RF("PromptBattlePassPurchase")
local rfBuyPackWithGems      = RF("BuyPackWithGems")
local rfClaimVIPDaily        = RF("ClaimVIPDaily")
local reVIPGranted           = RE("VIPGranted")
local reHubInteract          = RE("HubInteract")
local rfGetCosmetics         = RF("GetCosmetics")
local rfBuyCosmetic          = RF("BuyCosmetic")
local rfEquipCosmetic        = RF("EquipCosmetic")

local rfGetQuestState        = RF("GetQuestState")
local rfClaimQuest           = RF("ClaimQuest")
local rfClaimLoginStreak     = RF("ClaimLoginStreak")
local rfGetLeaderboard       = RF("GetLeaderboard")

MonetizationService:SetVIPGrantedCallback(function(player)
	reVIPGranted:FireClient(player)
end)

-- ── World ─────────────────────────────────────────────────────────────────────
-- Workspace is not version-controlled (the .rbxl is gitignored), so the hub is
-- built procedurally here on every server start rather than hand-authored in
-- Studio — the only way it's reproducible from a fresh clone.
HubService:Build()

-- ── Remote handlers ──────────────────────────────────────────────────────────

rfOpenPack.OnServerInvoke = function(player, packType, bannerId)
	-- Validate packType is a string to prevent injection.
	if type(packType) ~= "string" then
		return { success = false, error = "Invalid request." }
	end
	if bannerId ~= nil and type(bannerId) ~= "string" then
		return { success = false, error = "Invalid request." }
	end

	local result, err = PackService:OpenPack(player.UserId, packType, bannerId)
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

-- ── Monetization ──────────────────────────────────────────────────────────────

rfGetMonetizationInfo.OnServerInvoke = function(player)
	local banner = BannerService:GetActiveBanner()
	local bannerInfo = nil
	if banner then
		bannerInfo = {
			id             = banner.id,
			name           = banner.name,
			featuredCardId = banner.featuredCardId,
			rateMult       = banner.rateMult,
			guaranteeAfter = banner.guaranteeAfter,
			pulls          = BannerService:GetPulls(player.UserId, banner.id),
		}
	end

	return {
		gems        = InventoryService:GetGems(player.UserId),
		vip         = InventoryService:IsVIP(player.UserId),
		battlePass  = InventoryService:GetBattlePass(player.UserId),
		gemProducts = MonetizationConfig.GemProducts,
		vipConfig   = MonetizationConfig.VIP,
		battlePassConfig = MonetizationConfig.BattlePass,
		packGemCost = MonetizationConfig.PackGemCost,
		banner      = bannerInfo,
	}
end

rfPromptGemPurchase.OnServerInvoke = function(player, gemProductConfigId)
	if type(gemProductConfigId) ~= "string" then return { success = false } end
	return { success = MonetizationService:PromptGemPurchase(player, gemProductConfigId) }
end

rfPromptVIPPurchase.OnServerInvoke = function(player)
	return { success = MonetizationService:PromptVIPPurchase(player) }
end

rfPromptBattlePass.OnServerInvoke = function(player)
	return { success = MonetizationService:PromptBattlePassPurchase(player) }
end

rfBuyPackWithGems.OnServerInvoke = function(player, packType, bannerId)
	if type(packType) ~= "string" then
		return { success = false, error = "Invalid request." }
	end
	if bannerId ~= nil and type(bannerId) ~= "string" then
		return { success = false, error = "Invalid request." }
	end

	local result, err = PackService:BuyAndOpenWithGems(player.UserId, packType, bannerId)
	if err then
		return { success = false, error = err }
	end
	return { success = true, result = result, gems = InventoryService:GetGems(player.UserId) }
end

rfClaimVIPDaily.OnServerInvoke = function(player)
	local ok = InventoryService:ClaimVIPDaily(player.UserId)
	if ok then
		InventoryService:AddPack(player.UserId, MonetizationConfig.VIP.dailyBonusPack, 1)
	end
	return { success = ok, packs = InventoryService:GetPacks(player.UserId) }
end

rfGetCosmetics.OnServerInvoke = function(player)
	return {
		trails   = CosmeticConfig.Trails,
		owned    = InventoryService:GetCosmetics(player.UserId).owned,
		equipped = InventoryService:GetCosmetics(player.UserId).equipped,
	}
end

rfBuyCosmetic.OnServerInvoke = function(player, cosmeticId)
	if type(cosmeticId) ~= "string" then return { success = false } end
	local ok, err = CosmeticService:BuyCosmetic(player.UserId, cosmeticId)
	return { success = ok, error = err, gems = InventoryService:GetGems(player.UserId) }
end

rfEquipCosmetic.OnServerInvoke = function(player, cosmeticId)
	if type(cosmeticId) ~= "string" then return { success = false } end
	local ok = CosmeticService:EquipCosmetic(player.UserId, cosmeticId, player)
	return { success = ok }
end

-- ── Quests & Leaderboards ─────────────────────────────────────────────────────

rfGetQuestState.OnServerInvoke = function(player)
	return QuestService:GetState(player.UserId)
end

rfClaimQuest.OnServerInvoke = function(player, scope, questId)
	if type(scope) ~= "string" or type(questId) ~= "string" then
		return { success = false, error = "Invalid request." }
	end
	local ok, err = QuestService:ClaimQuest(player.UserId, scope, questId)
	return { success = ok, error = err, gems = InventoryService:GetGems(player.UserId), packs = InventoryService:GetPacks(player.UserId) }
end

rfClaimLoginStreak.OnServerInvoke = function(player)
	local ok, err = QuestService:ClaimLoginStreak(player.UserId)
	return { success = ok, error = err, gems = InventoryService:GetGems(player.UserId), packs = InventoryService:GetPacks(player.UserId) }
end

rfGetLeaderboard.OnServerInvoke = function(player, board)
	if type(board) ~= "string" then return { top = {}, mine = nil } end
	return {
		top  = LeaderboardService:GetTopN(board, 20),
		mine = LeaderboardService:GetPlayerScore(board, player.UserId),
	}
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
