-- Manages player card collections, awakening progress, and pack counts.
-- Persists to DataStore on leave; loads on join. PityService snapshot is
-- embedded in the same blob so only one DataStore key is needed per player.

local DataStoreService = game:GetService("DataStoreService")
local PityService      = require(script.Parent.PityService)

local InventoryService = {}

-- Falls back to nil in unpublished Studio sessions; all ops become in-memory only.
local store
pcall(function()
	store = DataStoreService:GetDataStore("GachaInventory_v2")
end)

local MAX_AWAKENING = 10

-- { [userId] = { cards={[id]=true}, awakening={[id]=N}, packs={[type]=N}, pity={...} } }
local cache = {}

local function blank()
	return {
		cards     = {},
		awakening = {},
		packs     = { StandardPack = 3 },   -- starter packs for new players
		pity      = { totalRolls = 0 },
		team      = {},
		tower     = { bestFloor = 0 },
	}
end

local function get(userId)
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

	cache[userId] = d
	PityService:Inject(userId, d.pity)
end

function InventoryService:Save(userId)
	if not store then return end
	local d = get(userId)
	if not d then return end
	d.pity = PityService:Snapshot(userId)
	pcall(function() store:SetAsync("u_" .. userId, d) end)
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

-- Full data snapshot sent to the client.
function InventoryService:GetFullData(userId)
	return {
		cardIds   = self:GetCardIds(userId),
		awakening = get(userId).awakening,
		packs     = get(userId).packs,
		team      = self:GetTeam(userId),
		tower     = get(userId).tower,
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
