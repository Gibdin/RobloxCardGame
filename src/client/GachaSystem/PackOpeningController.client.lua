-- Main client controller for the gacha pack-opening experience.
-- Sequence per pack open:
--   1. Player clicks "Open" on a pack in the list panel.
--   2. Pack rip frame shown — player clicks 3 times (or presses Skip).
--   3. Roll request sent to server; flash sequence plays.
--   4. Final reveal shown with rarity effects.
--   5. Player dismisses; pack list refreshes.
--   6. If Auto Roll is ON, repeat with the next available pack.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for server remotes
local remotes   = ReplicatedStorage:WaitForChild("GachaRemotes", 30)
if not remotes then
	error("[GachaSystem] GachaRemotes folder not found — is Main.server.lua running?")
end

local rfOpenPack     = remotes:WaitForChild("OpenPack")
local rfGetPacks     = remotes:WaitForChild("GetPacks")
local rfGetPityInfo  = remotes:WaitForChild("GetPityInfo")
local rfGetInventory = remotes:WaitForChild("GetInventory")
local rfGetTeam      = remotes:WaitForChild("GetTeam")
local rfSetTeam      = remotes:WaitForChild("SetTeam")
local rfGetSettings  = remotes:WaitForChild("GetSettings")
local rfSetSettings  = remotes:WaitForChild("SetSettings")
local rfTowerStart     = remotes:WaitForChild("Tower_Start")
local rfTowerNextFloor = remotes:WaitForChild("Tower_NextFloor")
local rfTowerPickBuff  = remotes:WaitForChild("Tower_PickBuff")
local rfTowerGetState  = remotes:WaitForChild("Tower_GetState")
local rfTowerAbandon   = remotes:WaitForChild("Tower_Abandon")
local rfDungeonStart      = remotes:WaitForChild("Dungeon_Start")
local rfDungeonGetState   = remotes:WaitForChild("Dungeon_GetState")
local rfDungeonChooseNode = remotes:WaitForChild("Dungeon_ChooseNode")
local rfDungeonPickBuff   = remotes:WaitForChild("Dungeon_PickEliteBuff")
local rfDungeonBuyItem    = remotes:WaitForChild("Dungeon_BuyItem")
local rfDungeonBuyService = remotes:WaitForChild("Dungeon_BuyService")
local rfDungeonReroll     = remotes:WaitForChild("Dungeon_RerollShop")
local rfDungeonAbandon    = remotes:WaitForChild("Dungeon_Abandon")
local rfDebugQuickSetup   = remotes:WaitForChild("Debug_QuickSetup")
local rfGetMonetizationInfo = remotes:WaitForChild("GetMonetizationInfo")
local rfPromptGemPurchase   = remotes:WaitForChild("PromptGemPurchase")
local rfPromptVIPPurchase   = remotes:WaitForChild("PromptVIPPurchase")
local rfPromptBattlePass    = remotes:WaitForChild("PromptBattlePassPurchase")
local rfBuyPackWithGems     = remotes:WaitForChild("BuyPackWithGems")
local rfClaimVIPDaily       = remotes:WaitForChild("ClaimVIPDaily")
local reVIPGranted          = remotes:WaitForChild("VIPGranted")
local reHubInteract         = remotes:WaitForChild("HubInteract")
local rfGetCosmetics        = remotes:WaitForChild("GetCosmetics")
local rfBuyCosmetic         = remotes:WaitForChild("BuyCosmetic")
local rfEquipCosmetic       = remotes:WaitForChild("EquipCosmetic")
local rfGetQuestState       = remotes:WaitForChild("GetQuestState")
local rfClaimQuest          = remotes:WaitForChild("ClaimQuest")
local rfClaimLoginStreak    = remotes:WaitForChild("ClaimLoginStreak")
local rfGetLeaderboard      = remotes:WaitForChild("GetLeaderboard")
local rfGetPvPOpponents     = remotes:WaitForChild("GetPvPOpponents")
local rfPvPAttack           = remotes:WaitForChild("PvPAttack")
local rfJoinDuelQueue       = remotes:WaitForChild("JoinDuelQueue")
local rfLeaveDuelQueue      = remotes:WaitForChild("LeaveDuelQueue")
local rfGetDuelQueueStatus  = remotes:WaitForChild("GetDuelQueueStatus")
local rfGetRecentDuels      = remotes:WaitForChild("GetRecentDuels")
local rfWatchDuel           = remotes:WaitForChild("WatchDuel")
local reDuelMatched         = remotes:WaitForChild("DuelMatched")

local rfGuildCreate         = remotes:WaitForChild("Guild_Create")
local rfGuildJoin           = remotes:WaitForChild("Guild_Join")
local rfGuildLeave          = remotes:WaitForChild("Guild_Leave")
local rfGuildGetMy          = remotes:WaitForChild("Guild_GetMy")
local rfGuildList           = remotes:WaitForChild("Guild_List")
local rfGuildSendChat       = remotes:WaitForChild("Guild_SendChat")
local rfGuildGetChat        = remotes:WaitForChild("Guild_GetChat")
local rfGuildGetWarBoard    = remotes:WaitForChild("Guild_GetWarLeaderboard")
local rfGuildReportMessage  = remotes:WaitForChild("Guild_ReportMessage")
local rfTradePropose        = remotes:WaitForChild("Trade_Propose")
local rfTradeRespond        = remotes:WaitForChild("Trade_Respond")
local rfTradeCancel         = remotes:WaitForChild("Trade_Cancel")
local rfTradeGetIncoming    = remotes:WaitForChild("Trade_GetIncoming")
local rfTradeGetOutgoing    = remotes:WaitForChild("Trade_GetOutgoing")
local rfFriendsGetInServer  = remotes:WaitForChild("Friends_GetInServer")
local rfFriendsGiftPack     = remotes:WaitForChild("Friends_GiftPack")

local rfGetAccountState     = remotes:WaitForChild("GetAccountState")
local rfEquipTitle          = remotes:WaitForChild("EquipTitle")
local rfEquipArtifact       = remotes:WaitForChild("EquipArtifact")
local rfGetPrestigeInfo     = remotes:WaitForChild("GetPrestigeInfo")
local rfDoPrestige          = remotes:WaitForChild("DoPrestige")

-- Shared modules
local gachaShared  = ReplicatedStorage:WaitForChild("GachaSystem")
local RarityConfig = require(gachaShared:WaitForChild("RarityConfig"))
local RoleConfig   = require(gachaShared:WaitForChild("RoleConfig"))
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))
local CombatConfig  = require(gachaShared:WaitForChild("CombatConfig"))
local TowerConfig   = require(gachaShared:WaitForChild("TowerConfig"))
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))
local MonetizationConfig = require(gachaShared:WaitForChild("MonetizationConfig"))
local CosmeticConfig     = require(gachaShared:WaitForChild("CosmeticConfig"))

-- VFX modules
local vfxFolder    = script.Parent.VFX
local VFXConfig    = require(vfxFolder.VFXConfig)
local SoundManager = require(vfxFolder.SoundManager)

-- UI modules
local uiFolder      = script.Parent.UI
local PackOpeningUI = require(uiFolder.PackOpeningUI)
local FlashSequence = require(uiFolder.FlashSequence)
local CardReveal    = require(uiFolder.CardReveal)
local SideMenuUI    = require(uiFolder.SideMenuUI)
local InventoryUI   = require(uiFolder.InventoryUI)
local GlobalTeamBar = require(uiFolder.GlobalTeamBar)
local TeamBuilderUI = require(uiFolder.TeamBuilderUI)
local SettingsUI    = require(uiFolder.SettingsUI)
local ShopStoreUI   = require(uiFolder.ShopStoreUI)
local QuestUI       = require(uiFolder.QuestUI)
local LeaderboardUI = require(uiFolder.LeaderboardUI)
local ArenaUI       = require(uiFolder.ArenaUI)
local SocialUI      = require(uiFolder.SocialUI)

-- Battle modules
local DungeonController = require(script.Parent.DungeonController)
local BattleController  = require(script.Parent.BattleController)
local BattleStats       = require(script.Parent.BattleStats)
local BattleUI          = require(uiFolder.BattleUI)
local ModeSelectUI      = require(uiFolder.ModeSelectUI)
local TowerUI           = require(uiFolder.TowerUI)
local EliteBuffUI       = require(uiFolder.EliteBuffUI)
local RunTeamPanel      = require(uiFolder.RunTeamPanel)
local DungeonMapUI      = require(uiFolder.DungeonMapUI)
local ShopUI            = require(uiFolder.ShopUI)
local FxUtil            = require(uiFolder.FxUtil)

-- Root ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "GachaSystemUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

-- Init VFX
SoundManager:Init(VFXConfig)

-- Init UI modules
PackOpeningUI:Init(screenGui, RarityConfig, VFXConfig, SoundManager)
FlashSequence:Init(screenGui, RarityConfig, CardDatabase, VFXConfig, SoundManager)
CardReveal:Init(screenGui, RarityConfig, VFXConfig, SoundManager)
GlobalTeamBar:Init(screenGui, CardDatabase, rfSetTeam, RoleConfig)
InventoryUI:Init(screenGui, CardDatabase, RarityConfig, RoleConfig, rfGetInventory, GlobalTeamBar)
TeamBuilderUI:Init(screenGui, CardDatabase, RarityConfig, RoleConfig, rfGetInventory, rfGetTeam, rfSetTeam)
GlobalTeamBar:SetOnSynergyHover(function(synName)
	if synName then InventoryUI:HighlightSynergy(synName)
	else InventoryUI:ClearHighlight() end
end)
GlobalTeamBar:SetOnSynergyClick(function(synName)
	InventoryUI:NavigateToSynergy(synName)
end)

-- Forward ref: openPack is defined below, but the OPEN NOW bridge needs a
-- stable closure to hand DungeonController now.
local openPackRef

DungeonController:Init(screenGui, {
	remotes = {
		towerStart = rfTowerStart,
		towerNextFloor = rfTowerNextFloor,
		towerPickBuff = rfTowerPickBuff,
		towerGetState = rfTowerGetState,
		towerAbandon = rfTowerAbandon,
		dungeonStart = rfDungeonStart,
		dungeonGetState = rfDungeonGetState,
		dungeonChooseNode = rfDungeonChooseNode,
		dungeonPickBuff = rfDungeonPickBuff,
		dungeonBuyItem = rfDungeonBuyItem,
		dungeonBuyService = rfDungeonBuyService,
		dungeonReroll = rfDungeonReroll,
		dungeonAbandon = rfDungeonAbandon,
		debugQuickSetup = rfDebugQuickSetup,
		getInventory = rfGetInventory,
	},
	CardDatabase = CardDatabase,
	RarityConfig = RarityConfig,
	RoleConfig = RoleConfig,
	CombatConfig = CombatConfig,
	TowerConfig = TowerConfig,
	DungeonConfig = DungeonConfig,
	VFXConfig = VFXConfig,
	SoundManager = SoundManager,
	onRewardsGranted = function()
		local ok, packs = pcall(function() return rfGetPacks:InvokeServer() end)
		if ok and packs then PackOpeningUI:UpdatePackList(packs) end
	end,
	onOpenPackNow = function(packType)
		if openPackRef then openPackRef(packType) end
	end,
}, {
	ModeSelectUI = ModeSelectUI,
	TowerUI = TowerUI,
	EliteBuffUI = EliteBuffUI,
	RunTeamPanel = RunTeamPanel,
	BattleUI = BattleUI,
	BattleController = BattleController,
	DungeonMapUI = DungeonMapUI,
	ShopUI = ShopUI,
})

-- State
local isOpening       = false
local autoRollEnabled = false

local function refreshPacks()
	local ok, packs = pcall(function() return rfGetPacks:InvokeServer() end)
	if ok and packs then
		PackOpeningUI:UpdatePackList(packs)
	end
end

local function openPack(packType)
	if isOpening then return end
	isOpening = true

	-- First pack: player manually rips. Auto Roll button appears after this.
	local skipped = PackOpeningUI:ShowPackRip(packType)
	PackOpeningUI:HidePackRip()
	PackOpeningUI:ShowAutoRollButton()

	local currentPackType = packType
	local currentSkipped  = skipped

	while true do
		-- Fire server roll request
		local response
		task.spawn(function()
			local ok, res = pcall(function()
				return rfOpenPack:InvokeServer(currentPackType)
			end)
			response = ok and res or { success = false, error = tostring(res) }
		end)

		local waited = 0
		while not response and waited < 10 do
			task.wait(0.05); waited = waited + 0.05
		end

		if not response or not response.success then
			warn("[GachaSystem] OpenPack failed:", response and response.error or "timeout")
			break
		end

		local result = response.result

		-- Flash: skip only if player pressed Skip on the manual rip; auto roll always plays flash
		if not currentSkipped then
			FlashSequence:Play(result.card, result.rarity)
		end

		CardReveal:Show(result)

		-- Watcher: auto-dismiss as soon as auto roll is on and card has shown >= 1.5s.
		-- Handles the case where the player enables auto roll mid-reveal.
		local revealTime = tick()
		local watchActive = true
		task.spawn(function()
			while watchActive do
				task.wait(0.1)
				if not watchActive then break end
				if autoRollEnabled then
					local remaining = math.max(0, 1.5 - (tick() - revealTime))
					if remaining > 0 then task.wait(remaining) end
					if watchActive and autoRollEnabled then
						CardReveal:TriggerDismiss()
					end
					break
				end
			end
		end)

		CardReveal:WaitForDismiss()
		watchActive = false

		if not autoRollEnabled then break end

		-- Find the next pack to open
		task.wait(0.5)
		local ok2, packs = pcall(function() return rfGetPacks:InvokeServer() end)
		local nextPack = nil
		if ok2 and packs then
			for pt, count in pairs(packs) do
				if count > 0 then nextPack = pt; break end
			end
		end

		if not nextPack then break end

		currentPackType = nextPack
		currentSkipped  = false  -- auto roll never skips the flash
	end

	isOpening = false
	autoRollEnabled = false
	PackOpeningUI:HideAutoRollButton()
	refreshPacks()
end

openPackRef = openPack

PackOpeningUI:SetOpenCallback(function(packType) openPack(packType) end)

PackOpeningUI:SetAutoRollCallback(function(enabled)
	autoRollEnabled = enabled
end)

-- Settings: master volume / screen shake / low-HP warning / UI scale, all
-- persisted server-side via GetSettings/SetSettings so they survive relog.
local rootUIScale = Instance.new("UIScale")
rootUIScale.Parent = screenGui

local settingsSaveDebounce = nil
local function applySettings(s)
	SoundManager:SetMasterVolume(s.masterVolume)
	FxUtil.SetShakeEnabled(s.screenShake)
	BattleUI:SetLowHpWarningEnabled(s.lowHpWarning)
	rootUIScale.Scale = s.uiScale
end

SettingsUI:Init(screenGui, {
	onChange = function(s)
		applySettings(s)
		if settingsSaveDebounce then task.cancel(settingsSaveDebounce) end
		settingsSaveDebounce = task.delay(1, function()
			pcall(function() rfSetSettings:InvokeServer(s) end)
		end)
	end,
})

task.spawn(function()
	local ok, loaded = pcall(function() return rfGetSettings:InvokeServer() end)
	if ok and loaded then
		SettingsUI:SetSettings(loaded)
		applySettings(SettingsUI:GetSettings())
	end
end)

local settingsPanel = SettingsUI:GetPanel()

-- Store: Gems, VIP, Battle Pass (skeleton), and the active rate-up banner.
-- Purchase prompts are always initiated server-side (product/pass ids come
-- from server config, never from client input) via PromptGemPurchase/
-- PromptVIPPurchase/PromptBattlePassPurchase; MarketplaceService still shows
-- the confirmation UI on this client either way.
local MarketplaceService = game:GetService("MarketplaceService")

local function refreshStore()
	task.spawn(function()
		local ok, storeInfo = pcall(function() return rfGetMonetizationInfo:InvokeServer() end)
		if ok and storeInfo then
			ShopStoreUI:Refresh(storeInfo)
			PackOpeningUI:UpdateGems(storeInfo.gems)
		end
	end)
	task.spawn(function()
		local ok, cosmeticsInfo = pcall(function() return rfGetCosmetics:InvokeServer() end)
		if ok and cosmeticsInfo then ShopStoreUI:RefreshCosmetics(cosmeticsInfo) end
	end)
end

-- Gems are consumable Developer Products with no server->client ownership
-- signal, so this client-only event (safe per Roblox docs — it's only used
-- to know the prompt closed, never to grant anything) triggers a refresh
-- shortly after, by which point ProcessReceipt has usually finished.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
	if userId == player.UserId then task.delay(1, refreshStore) end
end)

-- VIP ownership is NOT tracked client-side (PromptGamePassPurchaseFinished is
-- documented as server-only for reliable values) — the server fires this
-- RemoteEvent once it has durably recorded the grant instead.
reVIPGranted.OnClientEvent:Connect(refreshStore)

-- Mirrors openPack's reveal presentation (flash + reveal) for a direct
-- Gems-purchased pull, without touching the owned-pack rip/auto-roll state
-- machine above — a banner pull isn't an owned pack, just a summon.
local function pullBanner()
	if isOpening then return end
	local ok, storeInfo = pcall(function() return rfGetMonetizationInfo:InvokeServer() end)
	local banner = ok and storeInfo and storeInfo.banner
	if not banner then return end

	isOpening = true
	local response
	task.spawn(function()
		local ok2, res = pcall(function() return rfBuyPackWithGems:InvokeServer("EventPack", banner.id) end)
		response = ok2 and res or { success = false, error = tostring(res) }
	end)
	local waited = 0
	while not response and waited < 10 do task.wait(0.05); waited = waited + 0.05 end

	if not response or not response.success then
		warn("[GachaSystem] Banner pull failed:", response and response.error or "timeout")
		isOpening = false
		return
	end

	FlashSequence:Play(response.result.card, response.result.rarity)
	CardReveal:Show(response.result)
	CardReveal:WaitForDismiss()

	isOpening = false
	refreshPacks()
	refreshStore()
end

ShopStoreUI:Init(screenGui, CardDatabase, RarityConfig, MonetizationConfig, CosmeticConfig, {
	onBuyGems = function(configId)
		pcall(function() rfPromptGemPurchase:InvokeServer(configId) end)
	end,
	onBuyVIP = function()
		pcall(function() rfPromptVIPPurchase:InvokeServer() end)
	end,
	onBuyBattlePass = function()
		pcall(function() rfPromptBattlePass:InvokeServer() end)
	end,
	onClaimVIPDaily = function()
		task.spawn(function()
			local ok, res = pcall(function() return rfClaimVIPDaily:InvokeServer() end)
			if ok and res and res.success then
				PackOpeningUI:UpdatePackList(res.packs)
			end
		end)
	end,
	onPullBanner = function()
		task.spawn(pullBanner)
	end,
	onBuyCosmetic = function(cosmeticId)
		task.spawn(function()
			local ok, res = pcall(function() return rfBuyCosmetic:InvokeServer(cosmeticId) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] BuyCosmetic failed:", ok and res and res.error or "request failed")
			end
			refreshStore()
		end)
	end,
	onEquipCosmetic = function(cosmeticId)
		task.spawn(function()
			pcall(function() rfEquipCosmetic:InvokeServer(cosmeticId) end)
			refreshStore()
		end)
	end,
})

local storePanel = ShopStoreUI:GetPanel()
refreshStore()

-- Quests: daily/weekly/login-streak + Battle Pass tier display.
local function refreshQuests()
	task.spawn(function()
		local ok, questState = pcall(function() return rfGetQuestState:InvokeServer() end)
		if ok and questState then QuestUI:Refresh(questState) end
	end)
end

-- Account progression (Phase 8): level/titles/artifacts + Tower Prestige,
-- shown under QuestUI's PROGRESS tab. One combined refresh, same reasoning
-- as SocialUI's refreshSocial — none of these calls are hot/high-volume.
local function refreshAccount()
	task.spawn(function()
		local acctOk, account = pcall(function() return rfGetAccountState:InvokeServer() end)
		local prestOk, prestige = pcall(function() return rfGetPrestigeInfo:InvokeServer() end)
		QuestUI:RefreshAccount({
			account = acctOk and account or {},
			prestige = prestOk and prestige or {},
		})
	end)
end

QuestUI:Init(screenGui, MonetizationConfig, {
	onClaimQuest = function(scope, questId)
		task.spawn(function()
			local ok, res = pcall(function() return rfClaimQuest:InvokeServer(scope, questId) end)
			if ok and res and res.success then
				PackOpeningUI:UpdatePackList(res.packs)
				PackOpeningUI:UpdateGems(res.gems)
			elseif not (ok and res and res.success) then
				warn("[GachaSystem] ClaimQuest failed:", ok and res and res.error or "request failed")
			end
			refreshQuests()
		end)
	end,
	onClaimStreak = function()
		task.spawn(function()
			local ok, res = pcall(function() return rfClaimLoginStreak:InvokeServer() end)
			if ok and res and res.success then
				PackOpeningUI:UpdatePackList(res.packs)
				PackOpeningUI:UpdateGems(res.gems)
			elseif not (ok and res and res.success) then
				warn("[GachaSystem] ClaimLoginStreak failed:", ok and res and res.error or "request failed")
			end
			refreshQuests()
		end)
	end,
	onEquipTitle = function(title)
		task.spawn(function()
			local ok, res = pcall(function() return rfEquipTitle:InvokeServer(title) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] EquipTitle failed:", ok and res and res.error or "request failed")
			end
			refreshAccount()
		end)
	end,
	onEquipArtifact = function(artifactId)
		task.spawn(function()
			local ok, res = pcall(function() return rfEquipArtifact:InvokeServer(artifactId) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] EquipArtifact failed:", ok and res and res.error or "request failed")
			end
			refreshAccount()
		end)
	end,
	onPrestige = function()
		task.spawn(function()
			local ok, res = pcall(function() return rfDoPrestige:InvokeServer() end)
			if ok and res and res.success then
				refreshQuests()
			else
				warn("[GachaSystem] Prestige failed:", ok and res and res.error or "request failed")
			end
			refreshAccount()
		end)
	end,
})

local questPanel = QuestUI:GetPanel()
refreshQuests()
refreshAccount()

-- Leaderboards: fetched on-demand per tab (no need to keep all boards fresh
-- while the panel is closed).
LeaderboardUI:Init(screenGui, {
	onRequestBoard = function(boardId)
		task.spawn(function()
			local ok, data = pcall(function() return rfGetLeaderboard:InvokeServer(boardId) end)
			if ok and data then LeaderboardUI:Refresh(boardId, data) end
		end)
	end,
})

local leaderboardPanel = LeaderboardUI:GetPanel()

-- Arena: async PvP. Attacking hides the opponent list, plays the fight
-- through the same BattleController/BattleUI already used for Dungeon/Tower
-- (no DungeonController involvement needed — PvP isn't a "run"), then shows a
-- result screen before returning to a refreshed opponent list.
local function refreshArena()
	task.spawn(function()
		local ok, data = pcall(function() return rfGetPvPOpponents:InvokeServer() end)
		if ok and data then ArenaUI:Refresh(data) end
	end)
end

local function attackOpponent(opponentUserId)
	if BattleController:IsPlaying() then return end
	ArenaUI:Hide()

	local ok, res = pcall(function() return rfPvPAttack:InvokeServer(opponentUserId) end)
	if not (ok and res and res.success) then
		warn("[GachaSystem] PvPAttack failed:", ok and res and res.error or "request failed")
		ArenaUI:Show()
		refreshArena()
		return
	end

	local result = res.result
	BattleController:Play(result.battle, "ARENA DUEL")

	local closeCb = function()
		BattleUI:Hide()
		PackOpeningUI:UpdateGems(res.gems)
		ArenaUI:Show()
		refreshArena()
	end

	local deltaText = (result.ratingDelta >= 0 and "+" or "") .. result.ratingDelta .. " Rating"
	BattleUI:ShowResult({
		victory = result.victory,
		title = result.victory and "VICTORY" or "DEFEAT",
		summary = BattleStats.Fold(result.battle),
		lines = {
			deltaText .. " (now " .. result.ratingAfter .. ")",
			result.gemsAwarded > 0 and ("+" .. result.gemsAwarded .. " Gems") or nil,
		},
		buttons = { { text = "CLOSE", color = Color3.fromRGB(70, 170, 90), cb = closeCb } },
	})
end

-- Live Duel queue + spectating (Phase 6). Matchmaking/resolution both happen
-- server-side; DuelMatched is a push notification so a match found while the
-- Arena panel is closed still pops the fight up (genuinely "live"). One known
-- limitation: if the player is mid-Dungeon/Tower-battle at the exact moment
-- they're matched, BattleController:IsPlaying() blocks that playback — the
-- duel still resolved correctly server-side (rating/rewards applied), it's
-- just not shown; acceptable rare edge case for a shared single BattleUI.
local duelQueued = false

local function refreshDuelQueueStatus()
	task.spawn(function()
		local ok, status = pcall(function() return rfGetDuelQueueStatus:InvokeServer() end)
		if ok and status then
			duelQueued = status.queued
			ArenaUI:RefreshQueueStatus(status)
		end
	end)
end

local function toggleDuelQueue()
	task.spawn(function()
		if duelQueued then
			pcall(function() rfLeaveDuelQueue:InvokeServer() end)
		else
			local ok, res = pcall(function() return rfJoinDuelQueue:InvokeServer() end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] JoinDuelQueue failed:", ok and res and res.error or "request failed")
			end
		end
		refreshDuelQueueStatus()
	end)
end

local function refreshSpectate()
	task.spawn(function()
		local ok, duels = pcall(function() return rfGetRecentDuels:InvokeServer() end)
		if ok and duels then ArenaUI:RefreshSpectate(duels) end
	end)
end

local function watchDuel(duelId)
	if BattleController:IsPlaying() then return end
	task.spawn(function()
		local ok, res = pcall(function() return rfWatchDuel:InvokeServer(duelId) end)
		if not (ok and res and res.success) then
			warn("[GachaSystem] WatchDuel failed:", ok and res and res.error or "request failed")
			return
		end
		ArenaUI:Hide()
		BattleController:Play(res.battle, "SPECTATING: " .. res.nameA .. " vs " .. res.nameB)
		BattleUI:ShowResult({
			victory = true,
			title = "DUEL REPLAY COMPLETE",
			summary = BattleStats.Fold(res.battle),
			lines = { "You were spectating a past duel." },
			buttons = { { text = "CLOSE", color = Color3.fromRGB(70, 170, 90), cb = function()
				BattleUI:Hide()
				ArenaUI:Show()
			end } },
		})
	end)
end

ArenaUI:Init(screenGui, {
	onAttack = function(opponentUserId)
		task.spawn(function() attackOpponent(opponentUserId) end)
	end,
	onToggleQueue = toggleDuelQueue,
	onWatch = watchDuel,
})

local arenaPanel = ArenaUI:GetPanel()

reDuelMatched.OnClientEvent:Connect(function(payload)
	if BattleController:IsPlaying() then return end
	ArenaUI:Hide()
	BattleController:Play(payload.battle, "LIVE DUEL vs " .. payload.opponentName)

	local deltaText = (payload.ratingDelta >= 0 and "+" or "") .. payload.ratingDelta .. " Rating"
	BattleUI:ShowResult({
		victory = payload.victory,
		title = payload.victory and "VICTORY" or "DEFEAT",
		summary = BattleStats.Fold(payload.battle),
		lines = { deltaText .. " (now " .. payload.ratingAfter .. ")" },
		buttons = { { text = "CLOSE", color = Color3.fromRGB(70, 170, 90), cb = function()
			BattleUI:Hide()
			duelQueued = false
			ArenaUI:Show()
			refreshDuelQueueStatus()
		end } },
	})
end)

-- Keep the wait-time display live while the Arena panel is open — cheap,
-- and the only thing that needs to be "live" here (matching itself is
-- pushed via DuelMatched above, not polled).
task.spawn(function()
	while true do
		task.wait(2)
		if arenaPanel.Visible then
			refreshDuelQueueStatus()
		end
	end
end)

-- Social: guilds, trading, friends (Phase 7). One combined refresh pulls
-- everything the panel needs; simpler than per-tab fetch-on-demand since none
-- of these calls touch DataStore write volume that would matter at this scale.
local function refreshSocial()
	task.spawn(function()
		local myGuildOk, myGuild = pcall(function() return rfGuildGetMy:InvokeServer() end)
		local listOk, guildList = pcall(function() return rfGuildList:InvokeServer() end)
		local chatOk, chat = pcall(function() return rfGuildGetChat:InvokeServer() end)
		local inOk, incoming = pcall(function() return rfTradeGetIncoming:InvokeServer() end)
		local outOk, outgoing = pcall(function() return rfTradeGetOutgoing:InvokeServer() end)
		local friendsOk, friends = pcall(function() return rfFriendsGetInServer:InvokeServer() end)

		SocialUI:Refresh({
			guild = myGuildOk and myGuild or nil,
			guildList = listOk and guildList or {},
			chat = chatOk and chat or {},
			incomingOffers = inOk and incoming or {},
			outgoingOffers = outOk and outgoing or {},
			friends = friendsOk and friends or {},
		})
	end)
end

SocialUI:Init(screenGui, {
	onCreateGuild = function(name)
		task.spawn(function()
			local ok, res = pcall(function() return rfGuildCreate:InvokeServer(name) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] CreateGuild failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
		end)
	end,
	onJoinGuild = function(guildId)
		task.spawn(function()
			local ok, res = pcall(function() return rfGuildJoin:InvokeServer(guildId) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] JoinGuild failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
		end)
	end,
	onLeaveGuild = function()
		task.spawn(function()
			pcall(function() rfGuildLeave:InvokeServer() end)
			refreshSocial()
		end)
	end,
	onSendChat = function(text)
		task.spawn(function()
			local ok, res = pcall(function() return rfGuildSendChat:InvokeServer(text) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] SendChat failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
		end)
	end,
	onProposeTrade = function(toUserId, offerCardId, requestCardId)
		task.spawn(function()
			local ok, res = pcall(function() return rfTradePropose:InvokeServer(toUserId, offerCardId, requestCardId) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] ProposeTrade failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
		end)
	end,
	onRespondTrade = function(offerId, accept)
		task.spawn(function()
			local ok, res = pcall(function() return rfTradeRespond:InvokeServer(offerId, accept) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] RespondToTrade failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
			refreshPacks()
		end)
	end,
	onCancelTrade = function(offerId)
		task.spawn(function()
			pcall(function() return rfTradeCancel:InvokeServer(offerId) end)
			refreshSocial()
		end)
	end,
	onGiftPack = function(toUserId)
		task.spawn(function()
			local ok, res = pcall(function() return rfFriendsGiftPack:InvokeServer(toUserId) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] GiftPack failed:", ok and res and res.error or "request failed")
			end
			refreshSocial()
		end)
	end,
	onReportMessage = function(targetUserId, text)
		task.spawn(function()
			local ok, res = pcall(function() return rfGuildReportMessage:InvokeServer(targetUserId, text) end)
			if not (ok and res and res.success) then
				warn("[GachaSystem] ReportMessage failed:", ok and res and res.error or "request failed")
			end
		end)
	end,
})

local socialPanel = SocialUI:GetPanel()

-- Keep guild chat reasonably fresh while the Social panel is open (no push
-- event for chat — polling is simplest given chat is in-memory/per-server).
task.spawn(function()
	while true do
		task.wait(4)
		if socialPanel.Visible then
			refreshSocial()
		end
	end
end)

-- Side menu
local function closeAllExcept(except)
	if except~="packs"     then PackOpeningUI:ClosePacksDrawer() end
	if except~="inventory" then InventoryUI:Hide() end
	if except~="team"      then TeamBuilderUI:Hide() end
	if except~="battle"    then DungeonController:Hide() end
	if except~="arena"     then arenaPanel.Visible=false end
	if except~="quests"    then questPanel.Visible=false end
	if except~="rankings"  then leaderboardPanel.Visible=false end
	if except~="social"    then socialPanel.Visible=false end
	if except~="store"     then storePanel.Visible=false end
	if except~="settings"  then settingsPanel.Visible=false end
end
SideMenuUI:Init(screenGui,{
	packs=function() closeAllExcept("packs"); PackOpeningUI:TogglePacksDrawer() end,
	inventory=function()
		if InventoryUI:GetPanel().Visible then InventoryUI:Hide()
		else closeAllExcept("inventory"); InventoryUI:Show() end
	end,
	team=function()
		if TeamBuilderUI:GetPanel().Visible then TeamBuilderUI:Hide()
		else closeAllExcept("team"); TeamBuilderUI:Show() end
	end,
	battle=function() closeAllExcept("battle"); DungeonController:Toggle() end,
	arena=function()
		if arenaPanel.Visible then arenaPanel.Visible=false
		else
			closeAllExcept("arena")
			refreshArena(); refreshDuelQueueStatus(); refreshSpectate()
			ArenaUI:Show()
		end
	end,
	quests=function()
		if questPanel.Visible then questPanel.Visible=false
		else closeAllExcept("quests"); refreshQuests(); refreshAccount(); QuestUI:Show() end
	end,
	rankings=function()
		if leaderboardPanel.Visible then leaderboardPanel.Visible=false
		else closeAllExcept("rankings"); LeaderboardUI:ShowBoard(LeaderboardUI:GetActiveBoard()); LeaderboardUI:Show() end
	end,
	social=function()
		if socialPanel.Visible then socialPanel.Visible=false
		else closeAllExcept("social"); refreshSocial(); SocialUI:Show() end
	end,
	store=function()
		if storePanel.Visible then storePanel.Visible=false
		else closeAllExcept("store"); refreshStore(); ShopStoreUI:Show() end
	end,
	settings=function() closeAllExcept("settings"); settingsPanel.Visible=not settingsPanel.Visible end,
	debug=function() closeAllExcept("battle"); DungeonController:DebugQuickStart() end,
})

-- Hub world interactions (ProximityPrompts on the altar/vendor stalls) route
-- through the same panels as the side menu — the hub is just an alternate
-- entry point into UI that already exists, not a separate system.
local hubActions = {
	OpenAltar = function() closeAllExcept("packs"); PackOpeningUI:TogglePacksDrawer() end,
	OpenStore = function() closeAllExcept("store"); refreshStore(); ShopStoreUI:Show() end,
	OpenInventory = function() closeAllExcept("inventory"); InventoryUI:Show() end,
	OpenBattle = function() closeAllExcept("battle"); DungeonController:Toggle() end,
	OpenArena = function()
		closeAllExcept("arena")
		refreshArena(); refreshDuelQueueStatus(); refreshSpectate()
		ArenaUI:Show()
	end,
	OpenSocial = function()
		closeAllExcept("social")
		refreshSocial()
		SocialUI:Show()
	end,
}
reHubInteract.OnClientEvent:Connect(function(action)
	local fn = hubActions[action]
	if fn then fn() end
end)

refreshPacks()
