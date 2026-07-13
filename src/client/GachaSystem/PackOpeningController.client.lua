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

-- Shared modules
local gachaShared  = ReplicatedStorage:WaitForChild("GachaSystem")
local RarityConfig = require(gachaShared:WaitForChild("RarityConfig"))
local RoleConfig   = require(gachaShared:WaitForChild("RoleConfig"))
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))
local CombatConfig  = require(gachaShared:WaitForChild("CombatConfig"))
local TowerConfig   = require(gachaShared:WaitForChild("TowerConfig"))
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))
local MonetizationConfig = require(gachaShared:WaitForChild("MonetizationConfig"))

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

-- Battle modules
local DungeonController = require(script.Parent.DungeonController)
local BattleController  = require(script.Parent.BattleController)
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

ShopStoreUI:Init(screenGui, CardDatabase, RarityConfig, MonetizationConfig, {
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
})

local storePanel = ShopStoreUI:GetPanel()
refreshStore()

-- Side menu
local function closeAllExcept(except)
	if except~="packs"     then PackOpeningUI:ClosePacksDrawer() end
	if except~="inventory" then InventoryUI:Hide() end
	if except~="team"      then TeamBuilderUI:Hide() end
	if except~="battle"    then DungeonController:Hide() end
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
	store=function()
		if storePanel.Visible then storePanel.Visible=false
		else closeAllExcept("store"); refreshStore(); ShopStoreUI:Show() end
	end,
	settings=function() closeAllExcept("settings"); settingsPanel.Visible=not settingsPanel.Visible end,
	debug=function() closeAllExcept("battle"); DungeonController:DebugQuickStart() end,
})

refreshPacks()
