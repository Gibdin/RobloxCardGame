-- Manages player card collections, awakening progress, and pack counts.
-- Persists to DataStore on leave; loads on join. PityService snapshot is
-- embedded in the same blob so only one DataStore key is needed per player.

local DataStoreService = game:GetService("DataStoreService")
local PityService      = require(script.Parent.PityService)
local BannerService    = require(script.Parent.BannerService)

local InventoryService = {}

-- Falls back to nil in unpublished Studio sessions; all ops become in-memory only.
local store
pcall(function()
	store = DataStoreService:GetDataStore("GachaInventory_v2")
end)

local MAX_AWAKENING = 10

-- { [userId] = { cards={[id]=true}, awakening={[id]=N}, packs={[type]=N}, pity={...} } }
local cache = {}

local function blankSettings()
	return {
		masterVolume = 1,
		screenShake  = true,
		lowHpWarning = true,
		uiScale      = 1,
	}
end

local function blank()
	return {
		cards     = {},
		awakening = {},
		packs     = { StandardPack = 3 },   -- starter packs for new players
		pity      = { totalRolls = 0 },
		team      = {},
		tower     = { bestFloor = 0 },
		dungeon   = { deepestRow = 0, runsCompleted = 0, bossKills = 0 },
		settings  = blankSettings(),
		gems      = 0,
		vip       = { owned = false, lastDailyClaim = "" },
		battlePass = { premium = false },
		bannerPulls = {},
		processedReceipts = {},   -- [receiptId] = true; makes ProcessReceipt idempotent
		cosmetics = { owned = { none = true }, equipped = "none" },
	}
end

-- Self-healing fallback: normally every player is loaded via PlayerAdded (or
-- the already-in-game loop) before anything touches their data, but if that
-- was ever somehow missed — e.g. a race between a player joining and this
-- script finishing its startup work — lazy-loading here means a request just
-- pays a one-time DataStore round trip instead of hard-erroring.
local function get(userId)
	if not cache[userId] then
		InventoryService:Load(userId)
	end
	return cache[userId]
end

-- ── Persistence ─────────────────────────────────────────────────────────────

function InventoryService:Load(userId)
	local d
	if store then
		local ok, saved = pcall(function() return store:GetAsync("u_" .. userId) end)
		d = (ok and saved) or blank()
	else
		d = blank()
	end
	-- Ensure all sub-tables exist for older save formats.
	d.cards     = d.cards     or {}
	d.awakening = d.awakening or {}
	d.packs     = d.packs     or { StandardPack = 3 }
	d.pity      = d.pity      or { totalRolls = 0 }
	d.team      = d.team      or {}
	d.tower     = d.tower     or { bestFloor = 0 }
	d.dungeon   = d.dungeon   or { deepestRow = 0, runsCompleted = 0, bossKills = 0 }
	d.settings  = d.settings  or blankSettings()
	d.gems      = d.gems      or 0
	d.vip       = d.vip       or { owned = false, lastDailyClaim = "" }
	d.battlePass = d.battlePass or { premium = false }
	d.bannerPulls = d.bannerPulls or {}
	d.processedReceipts = d.processedReceipts or {}
	d.cosmetics = d.cosmetics or { owned = { none = true }, equipped = "none" }

	cache[userId] = d
	PityService:Inject(userId, d.pity)
	BannerService:Inject(userId, d.bannerPulls)
end

local SAVE_RETRIES     = 3
local SAVE_RETRY_DELAY = 1  -- seconds between retries

function InventoryService:Save(userId)
	if not store then return end
	local d = get(userId)
	if not d then return end
	d.pity = PityService:Snapshot(userId)
	d.bannerPulls = BannerService:Snapshot(userId)

	for attempt = 1, SAVE_RETRIES do
		local ok = pcall(function() store:SetAsync("u_" .. userId, d) end)
		if ok then return end
		if attempt < SAVE_RETRIES then task.wait(SAVE_RETRY_DELAY) end
	end
	warn(("[InventoryService] Failed to save data for user %d after %d attempts"):format(userId, SAVE_RETRIES))
end

function InventoryService:Cleanup(userId)
	self:Save(userId)
	cache[userId] = nil
end

-- ── Card ownership ───────────────────────────────────────────────────────────

function InventoryService:OwnsCard(userId, cardId)
	return get(userId).cards[tostring(cardId)] == true
end

function InventoryService:AddCard(userId, cardId)
	get(userId).cards[tostring(cardId)] = true
end

function InventoryService:GetCardIds(userId)
	local ids = {}
	for k in pairs(get(userId).cards) do
		table.insert(ids, tonumber(k))
	end
	return ids
end

-- ── Awakening ────────────────────────────────────────────────────────────────

function InventoryService:GetAwakening(userId, cardId)
	return get(userId).awakening[tostring(cardId)] or 0
end

-- Adds `amount` awakening progress (capped at MAX_AWAKENING).
-- Returns the new awakening level.
function InventoryService:AddAwakening(userId, cardId, amount)
	local d   = get(userId)
	local key = tostring(cardId)
	d.awakening[key] = math.min((d.awakening[key] or 0) + (amount or 1), MAX_AWAKENING)
	return d.awakening[key]
end

-- ── Pack inventory ───────────────────────────────────────────────────────────

function InventoryService:GetPackCount(userId, packType)
	return get(userId).packs[packType] or 0
end

function InventoryService:HasPack(userId, packType)
	return self:GetPackCount(userId, packType) > 0
end

-- Returns false if the player has none; true on success.
function InventoryService:RemovePack(userId, packType)
	local d = get(userId)
	if (d.packs[packType] or 0) <= 0 then return false end
	d.packs[packType] = d.packs[packType] - 1
	return true
end

function InventoryService:AddPack(userId, packType, amount)
	local d = get(userId)
	d.packs[packType] = (d.packs[packType] or 0) + (amount or 1)
end

function InventoryService:GetPacks(userId)
	return get(userId).packs
end

-- Returns the first pack type with count > 0, or nil.
function InventoryService:GetNextAvailablePack(userId)
	for packType, count in pairs(get(userId).packs) do
		if count > 0 then return packType end
	end
	return nil
end

-- ── Tower progress ───────────────────────────────────────────────────────────

function InventoryService:GetBestFloor(userId)
	local d = get(userId)
	return d and d.tower.bestFloor or 0
end

-- Max-only write: never lowers the recorded best.
function InventoryService:SetBestFloor(userId, floor)
	local d = get(userId)
	if d and type(floor) == "number" and floor > d.tower.bestFloor then
		d.tower.bestFloor = floor
	end
end

-- ── Dungeon career stats ─────────────────────────────────────────────────────

function InventoryService:GetDungeonStats(userId)
	local d = get(userId)
	return d and d.dungeon or { deepestRow = 0, runsCompleted = 0, bossKills = 0 }
end

-- Records a finished (or abandoned) run. deepestRow is max-only; every run
-- end counts toward runsCompleted; completed=true also counts a boss kill.
function InventoryService:RecordDungeonResult(userId, info)
	local d = get(userId)
	if not d then return end
	if type(info.deepestRow) == "number" and info.deepestRow > d.dungeon.deepestRow then
		d.dungeon.deepestRow = info.deepestRow
	end
	d.dungeon.runsCompleted = d.dungeon.runsCompleted + 1
	if info.completed then
		d.dungeon.bossKills = d.dungeon.bossKills + 1
	end
end

-- ── Settings (client-side prefs, persisted so they survive relog) ────────────

function InventoryService:GetSettings(userId)
	local d = get(userId)
	return d and d.settings or blankSettings()
end

-- Merges only known keys with basic type/range validation; ignores the rest.
function InventoryService:SetSettings(userId, settingsTable)
	if type(settingsTable) ~= "table" then return end
	local d = get(userId)
	if not d then return end
	local s = d.settings

	if type(settingsTable.masterVolume) == "number" then
		s.masterVolume = math.clamp(settingsTable.masterVolume, 0, 1)
	end
	if type(settingsTable.screenShake) == "boolean" then
		s.screenShake = settingsTable.screenShake
	end
	if type(settingsTable.lowHpWarning) == "boolean" then
		s.lowHpWarning = settingsTable.lowHpWarning
	end
	if type(settingsTable.uiScale) == "number" then
		s.uiScale = math.clamp(settingsTable.uiScale, 0.75, 1.25)
	end
end

-- ── Gems (premium currency) ───────────────────────────────────────────────────

function InventoryService:GetGems(userId)
	local d = get(userId)
	return d and d.gems or 0
end

function InventoryService:AddGems(userId, amount)
	local d = get(userId)
	if not d or type(amount) ~= "number" or amount <= 0 then return end
	d.gems = d.gems + amount
end

-- Returns false if the player can't afford it; true and deducts otherwise.
function InventoryService:SpendGems(userId, amount)
	local d = get(userId)
	if not d or type(amount) ~= "number" or amount <= 0 then return false end
	if d.gems < amount then return false end
	d.gems = d.gems - amount
	return true
end

-- ── VIP Game Pass ─────────────────────────────────────────────────────────────

function InventoryService:IsVIP(userId)
	local d = get(userId)
	return d and d.vip.owned or false
end

function InventoryService:SetVIP(userId, owned)
	local d = get(userId)
	if not d then return end
	d.vip.owned = owned
end

-- Returns true and marks the claim if the player hasn't claimed their VIP
-- daily bonus pack yet today; false if already claimed (or not VIP).
function InventoryService:ClaimVIPDaily(userId)
	local d = get(userId)
	if not d or not d.vip.owned then return false end
	local today = os.date("!%Y-%m-%d")
	if d.vip.lastDailyClaim == today then return false end
	d.vip.lastDailyClaim = today
	return true
end

-- ── Battle Pass (skeleton — reward content/XP feed land in later phases) ─────

function InventoryService:GetBattlePass(userId)
	local d = get(userId)
	return d and d.battlePass or { premium = false }
end

function InventoryService:SetBattlePassPremium(userId, owned)
	local d = get(userId)
	if not d then return end
	d.battlePass.premium = owned
end

-- ── Cosmetics (Gem-purchased, never touches gacha odds) ──────────────────────

function InventoryService:GetCosmetics(userId)
	local d = get(userId)
	return d and d.cosmetics or { owned = { none = true }, equipped = "none" }
end

function InventoryService:OwnsCosmetic(userId, cosmeticId)
	local d = get(userId)
	return d and d.cosmetics.owned[cosmeticId] == true
end

function InventoryService:AddCosmetic(userId, cosmeticId)
	local d = get(userId)
	if not d then return end
	d.cosmetics.owned[cosmeticId] = true
end

-- Returns false if the player doesn't own it; true and equips otherwise.
function InventoryService:EquipCosmetic(userId, cosmeticId)
	local d = get(userId)
	if not d or not d.cosmetics.owned[cosmeticId] then return false end
	d.cosmetics.equipped = cosmeticId
	return true
end

-- ── Idempotent purchase granting ─────────────────────────────────────────────
-- Safe to call whether the player is currently in-server (uses the live cache
-- + an immediate save) or has already left (falls back to a DataStore
-- UpdateAsync so a delayed MarketplaceService receipt never loses a paid
-- purchase). `applyFn(data)` mutates the save blob in place. Returns true once
-- the purchase is durably recorded (whether newly granted or already granted
-- on a prior call with the same receiptId).
function InventoryService:GrantPurchase(userId, receiptId, applyFn)
	local d = get(userId)
	if d then
		if d.processedReceipts[receiptId] then return true end
		applyFn(d)
		d.processedReceipts[receiptId] = true
		self:Save(userId)
		return true
	end

	if not store then return false end
	local ok, result = pcall(function()
		return store:UpdateAsync("u_" .. userId, function(old)
			old = old or blank()
			old.processedReceipts = old.processedReceipts or {}
			if old.processedReceipts[receiptId] then return old end
			applyFn(old)
			old.processedReceipts[receiptId] = true
			return old
		end)
	end)
	return ok and result ~= nil
end

-- Full data snapshot sent to the client.
function InventoryService:GetFullData(userId)
	return {
		cardIds   = self:GetCardIds(userId),
		awakening = get(userId).awakening,
		packs     = get(userId).packs,
		team      = self:GetTeam(userId),
		tower     = get(userId).tower,
		dungeon   = get(userId).dungeon,
		settings  = get(userId).settings,
		gems      = get(userId).gems,
		vip       = get(userId).vip,
		battlePass = get(userId).battlePass,
		cosmetics = get(userId).cosmetics,
	}
end

-- Returns team as a 5-element array; false = empty slot.
function InventoryService:GetTeam(userId)
	local t = get(userId).team or {}
	local result = {}
	for i = 1, 5 do
		local v = t[i]
		result[i] = (type(v) == "number" and v > 0) and v or false
	end
	return result
end

-- Validates each slot against the player's owned cards before saving.
function InventoryService:SetTeam(userId, teamTable)
	if type(teamTable) ~= "table" then return end
	local d = get(userId)
	local validated = {}
	for i = 1, 5 do
		local id = teamTable[i]
		if type(id) == "number" and id > 0 and self:OwnsCard(userId, id) then
			validated[i] = id
		else
			validated[i] = false
		end
	end
	d.team = validated
end

return InventoryService
